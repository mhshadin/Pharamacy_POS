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
$deviceModel = isset($inputData['device_model']) ? trim((string)$inputData['device_model']) : '';
$deviceDisplayName = isset($inputData['device_display_name']) ? trim((string)$inputData['device_display_name']) : '';
if ($deviceDisplayName === '') {
    $deviceDisplayName = 'POS Device';
}

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
        SELECT u.id, u.pharmacy_id, u.role, u.is_active, u.auth_provider, u.full_name, u.avatar_url, u.phone_number,
               s.valid_until, s.status as sub_status, sp.name as plan_name, sp.billing_cycle, sp.trial_days
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

        $pdo->prepare('INSERT INTO subscribers (id, pharmacy_id, plan_id, valid_until, renewed_at, status) VALUES (?, ?, ?, ?, NOW(), ?)')
            ->execute([$subId, $pharmacyId, $planId, $expiryDate, 'active']);

        $user = [
            'id' => $userId,
            'pharmacy_id' => $pharmacyId,
            'role' => 'owner',
            'is_active' => 1,
            'full_name' => $full_name,
            'avatar_url' => $avatar_url,
            'phone_number' => null,
            'valid_until' => $expiryDate,
            'sub_status' => 'active',
            'plan_name' => 'Trial',
            'billing_cycle' => 'monthly',
            'trial_days' => $trialDays
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
        $countStmt = $pdo->prepare('SELECT COUNT(*) AS total_devices FROM devices WHERE pharmacy_id = ?');
        $countStmt->execute([$user['pharmacy_id']]);
        $deviceCount = (int)$countStmt->fetch()['total_devices'];
        $isActiveSeller = $deviceCount === 0 ? 1 : 0;
        $pdo->prepare('INSERT INTO devices (id, pharmacy_id, hardware_uid, device_name, device_model, device_display_name, last_login_at, is_active_seller, activated_at) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?)')
            ->execute([
                $deviceId,
                $user['pharmacy_id'],
                $hardwareUid,
                'POS Device',
                $deviceModel !== '' ? $deviceModel : null,
                $deviceDisplayName,
                $isActiveSeller,
                $isActiveSeller === 1 ? date('Y-m-d H:i:s') : null
            ]);
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
        $pdo->prepare('UPDATE devices SET last_login_at = NOW(), device_model = ?, device_display_name = ? WHERE hardware_uid = ?')
            ->execute([$deviceModel !== '' ? $deviceModel : null, $deviceDisplayName, $hardwareUid]);
    }

    $cntActive = $pdo->prepare('SELECT COUNT(*) AS c FROM devices WHERE pharmacy_id = ? AND is_active_seller = 1');
    $cntActive->execute([$user['pharmacy_id']]);
    if ((int)$cntActive->fetch()['c'] === 0) {
        $pdo->prepare('
            UPDATE devices
            SET is_active_seller = 1, activated_at = COALESCE(activated_at, NOW())
            WHERE pharmacy_id = ?
            ORDER BY COALESCE(last_login_at, \'1970-01-01\') ASC, id ASC
            LIMIT 1
        ')->execute([$user['pharmacy_id']]);
    }

    $pdo->commit();

    $isActiveSeller = false;
    $stSeller = $pdo->prepare('SELECT is_active_seller FROM devices WHERE hardware_uid = ? AND pharmacy_id = ? LIMIT 1');
    $stSeller->execute([$hardwareUid, $user['pharmacy_id']]);
    $sellerRow = $stSeller->fetch();
    if ($sellerRow) {
        $isActiveSeller = ((int)$sellerRow['is_active_seller'] === 1);
    }

    if ($user['is_active'] == 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account disabled.']);
        exit;
    }

    // Revoke old refresh tokens for this user+device, then issue a fresh one.
    $pdo->prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ? AND hardware_uid = ? AND revoked = 0')
        ->execute([$user['id'], $hardwareUid]);

    $refreshToken = bin2hex(random_bytes(32));
    $refreshTokenHash = hash('sha256', $refreshToken);
    $refreshTokenExpiry = date('Y-m-d H:i:s', time() + (60 * 60 * 24 * 30));
    $pdo->prepare('INSERT INTO refresh_tokens (id, user_id, hardware_uid, token_hash, expires_at) VALUES (?, ?, ?, ?, ?)')
        ->execute([generate_uuid_v4(), $user['id'], $hardwareUid, $refreshTokenHash, $refreshTokenExpiry]);

    $issuedAt = time();
    $subValidUntil = $user['valid_until'] ?? null;
    $subExpiryTimestamp = $subValidUntil ? strtotime($subValidUntil) : null;
    $effectiveSubStatus = $user['sub_status'] ?? 'expired';
    if (!empty($subValidUntil) && strtotime($subValidUntil) < time()) {
        $effectiveSubStatus = 'expired';
    }
    $jwtExpiry = $issuedAt + (60 * 60 * 24 * 30);

    $jwtPayload = [
        'iat' => $issuedAt,
        'iss' => 'pharmapos_license_server',
        'exp' => $jwtExpiry,
        'sub' => $user['id'],
        'pharmacy_id' => $user['pharmacy_id'],
        'role' => $user['role'],
        'sub_expires_at' => $subExpiryTimestamp,
        'sub_status' => $effectiveSubStatus
    ];

    $licenseToken = JWT::encode($jwtPayload, JWT_SECRET, 'HS256');

    $planDays = 0;
    $billingCycle = isset($user['billing_cycle']) ? strtolower((string)$user['billing_cycle']) : '';
    if ($billingCycle === 'yearly') {
        $planDays = 365;
    } elseif ($billingCycle === 'monthly') {
        $planDays = 30;
    }
    $trialDays = isset($user['trial_days']) ? (int)$user['trial_days'] : 0;
    if ($trialDays > 0) {
        $planDays = $trialDays;
    }

    http_response_code(200);
    echo json_encode([
        'message' => 'License granted',
        'license_token' => $licenseToken,
        'refresh_token' => $refreshToken,
        'subscription' => [
            'status' => $effectiveSubStatus,
            'valid_until' => $user['valid_until'],
            'plan_name' => $user['plan_name'],
            'total_plan_days' => $planDays
        ],
        'user' => [
            'id' => $user['id'],
            'pharmacy_id' => $user['pharmacy_id'],
            'role' => $user['role'],
            'email' => $email,
            'name' => $user['full_name'] ?? $full_name,
            'avatar' => $user['avatar_url'] ?? $avatar_url,
            'phone_number' => $user['phone_number'],
            'is_active' => (int)$user['is_active']
        ],
        'device' => [
            'hardware_uid' => $hardwareUid,
            'is_active_seller' => $isActiveSeller,
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