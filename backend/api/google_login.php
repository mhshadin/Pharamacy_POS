<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/JWT/vendor/autoload.php';
use \Firebase\JWT\JWT;

// Import config (This gives us $pdo, the constants, and generate_uuid_v4)
require_once __DIR__ . '/config.php';

// Debug logging helper
function debug_log($message)
{
    $log_file = __DIR__ . '/debug_google.log';
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($log_file, "[$timestamp] $message\n", FILE_APPEND);
}

debug_log("--- NEW LOGIN ATTEMPT ---");

$inputData = json_decode(file_get_contents('php://input'), true);

if (!isset($inputData['idToken']) || empty($inputData['idToken'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing idToken.']);
    exit;
}

$idToken = $inputData['idToken'];
$hardwareUid = isset($inputData['hardware_uid']) ? $inputData['hardware_uid'] : 'unknown_device';

// Verify Token with Google
// Accept ID tokens issued for both mobile/web sign-in and Windows desktop PKCE.
$allowedClientIds = array_filter([
    defined('WEB_CLIENT_ID') ? WEB_CLIENT_ID : null,
    defined('DESKTOP_CLIENT_ID') ? DESKTOP_CLIENT_ID : null,
]);
debug_log("Verifying ID Token with allowed Client IDs: " . implode(', ', $allowedClientIds));

$payload = false;
try {
    foreach ($allowedClientIds as $audienceClientId) {
        $client = new Google_Client(['client_id' => $audienceClientId]);
        $payload = $client->verifyIdToken($idToken);
        if ($payload) {
            break;
        }
    }

    if (!$payload) {
        debug_log("Verification failed: verifyIdToken returned false");
        throw new Exception("Verification failed.");
    }
    debug_log("Verification successful for email: " . $payload['email']);
} catch (Exception $e) {
    debug_log("Verification Error: " . $e->getMessage());
    http_response_code(401);
    echo json_encode(['error' => 'Invalid Google Token.']);
    exit;
}

$oauth_uid = $payload['sub'];
$email = $payload['email'];
$full_name = isset($payload['name']) ? $payload['name'] : 'Unknown User';
$avatar_url = isset($payload['picture']) ? $payload['picture'] : null;

try {
    $stmt = $pdo->prepare('
        SELECT u.id, u.pharmacy_id, u.role, u.is_active, u.auth_provider, 
               s.valid_until, s.status as sub_status, sp.name as plan_name
        FROM users u
        LEFT JOIN subscribers s ON u.pharmacy_id = s.pharmacy_id
        LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
        WHERE u.oauth_uid = ? OR u.email = ?
    ');
    $stmt->execute([$oauth_uid, $email]);
    $user = $stmt->fetch();

    $pdo->beginTransaction();

    if (!$user) {
        // 1. Fetch Default "Trial" Plan
        $stmtPlan = $pdo->prepare('SELECT id, trial_days FROM subscription_plans WHERE name = ? LIMIT 1');
        $stmtPlan->execute(['Trial']);
        $plan = $stmtPlan->fetch();

        if (!$plan) {
            $planId = generate_uuid_v4();
            $trialDays = 14;
            $pdo->prepare('INSERT INTO subscription_plans (id, name, price, billing_cycle, trial_days) VALUES (?, ?, ?, ?, ?)')
                ->execute([$planId, 'Trial', 0.00, 'monthly', $trialDays]);
        } else {
            $planId = $plan['id'];
            $trialDays = $plan['trial_days'];
        }

        $expiryDate = date('Y-m-d H:i:s', strtotime("+$trialDays days"));

        $userId = generate_uuid_v4();
        $pharmacyId = generate_uuid_v4();
        $subId = generate_uuid_v4();

        $pdo->prepare('INSERT INTO pharmacies (id, business_name, owner_name, contact_phone, contact_email, account_status) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([$pharmacyId, $full_name . "'s Pharmacy", $full_name, 'PENDING', $email, 'active']);

        $pdo->prepare('INSERT INTO users (id, pharmacy_id, role, email, auth_provider, oauth_uid, full_name, avatar_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
            ->execute([$userId, $pharmacyId, 'owner', $email, 'google', $oauth_uid, $full_name, $avatar_url]);

        $pdo->prepare('INSERT INTO subscribers (id, pharmacy_id, plan_id, valid_until, status) VALUES (?, ?, ?, ?, ?)')
            ->execute([$subId, $pharmacyId, $planId, $expiryDate, 'active']);

        $user = [
            'id' => $userId,
            'pharmacy_id' => $pharmacyId,
            'role' => 'owner',
            'is_active' => 1,
            'valid_until' => $expiryDate,
            'sub_status' => 'active',
            'plan_name' => 'Trial'
        ];
    } else {
        if ($user['auth_provider'] !== 'google') {
            $pdo->prepare('UPDATE users SET auth_provider = ?, oauth_uid = ?, full_name = ?, avatar_url = ? WHERE id = ?')
                ->execute(['google', $oauth_uid, $full_name, $avatar_url, $user['id']]);
        } else {
            $pdo->prepare('UPDATE users SET full_name = ?, avatar_url = ? WHERE id = ?')
                ->execute([$full_name, $avatar_url, $user['id']]);
        }
    }

    // Check if device exists (globally by hardware_uid)
    $stmtDevice = $pdo->prepare('SELECT id, pharmacy_id FROM devices WHERE hardware_uid = ?');
    $stmtDevice->execute([$hardwareUid]);
    $device = $stmtDevice->fetch();

    if (!$device) {
        $deviceId = generate_uuid_v4();
        $pdo->prepare('INSERT INTO devices (id, pharmacy_id, hardware_uid, device_name, last_login_at) VALUES (?, ?, ?, ?, NOW())')
            ->execute([$deviceId, $user['pharmacy_id'], $hardwareUid, 'POS Device']);
    } else {
        // --- MULTI-ACCOUNT RESTRICTION ---
        // If device exists, check if it belongs to a different pharmacy
        if ($device['pharmacy_id'] !== $user['pharmacy_id']) {
            http_response_code(403);
            echo json_encode(['error' => 'DEVICE_ALREADY_REGISTERED']);
            $pdo->rollBack();
            exit;
        }

        // Update last_login_at
        $pdo->prepare('UPDATE devices SET last_login_at = NOW() WHERE hardware_uid = ?')
            ->execute([$hardwareUid]);
    }

    $pdo->commit();

    if ($user['is_active'] == 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account disabled.']);
        exit;
    }

    $issuedAt = time();
    $subExpiryTimestamp = strtotime($user['valid_until']);
    $jwtExpiry = $issuedAt + (60 * 60 * 24 * 30);

    $jwtPayload = [
        'iat' => $issuedAt,
        'iss' => 'pharmapos_license_server',
        'exp' => $jwtExpiry,
        'sub' => $user['id'],
        'pharmacy_id' => $user['pharmacy_id'],
        'role' => $user['role'],
        'sub_expires_at' => $subExpiryTimestamp,
        'sub_status' => $user['sub_status']
    ];

    $licenseToken = JWT::encode($jwtPayload, JWT_SECRET, 'HS256');

    http_response_code(200);
    echo json_encode([
        'message' => 'License granted',
        'license_token' => $licenseToken,
        'subscription' => [
            'status' => $user['sub_status'],
            'valid_until' => $user['valid_until'],
            'plan_name' => $user['plan_name']
        ],
        'user' => [
            'id' => $user['id'],
            'role' => $user['role'],
            'email' => $email,
            'name' => $full_name,
            'avatar' => $avatar_url
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction())
        $pdo->rollBack();
    error_log("Login Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'error' => 'Server error.',
        'debug_msg' => $e->getMessage() // TEMPORARY for diagnosis
    ]);
}