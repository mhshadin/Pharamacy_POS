<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;

// Import config (This gives us $pdo, the constants, and generate_uuid_v4)
require_once __DIR__ . '/config.php';

$inputData = json_decode(file_get_contents('php://input'), true);

if (!isset($inputData['idToken']) || empty($inputData['idToken'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing idToken.']);
    exit;
}

$idToken = $inputData['idToken'];
$hardwareUid = isset($inputData['hardware_uid']) ? $inputData['hardware_uid'] : 'unknown_device';

// Verify Token with Google
$client = new Google_Client(['client_id' => WEB_CLIENT_ID]);
try {
    $payload = $client->verifyIdToken($idToken);
    if (!$payload) throw new Exception("Verification failed.");
} catch (Exception $e) {
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
               s.valid_until, s.status as sub_status
        FROM users u
        LEFT JOIN subscriptions s ON u.pharmacy_id = s.pharmacy_id
        WHERE u.oauth_uid = ? OR u.email = ?
    ');
    $stmt->execute([$oauth_uid, $email]);
    $user = $stmt->fetch();

    $pdo->beginTransaction();

    if (!$user) {
        $pharmacyId = generate_uuid_v4();
        $userId = generate_uuid_v4();
        $subId = generate_uuid_v4();
        $trialExpiry = date('Y-m-d H:i:s', strtotime('+14 days'));

        $pdo->prepare('INSERT INTO pharmacies (id, business_name, owner_name, contact_phone, contact_email, account_status) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([$pharmacyId, $full_name . "'s Pharmacy", $full_name, 'PENDING', $email, 'trial']);

        $pdo->prepare('INSERT INTO users (id, pharmacy_id, role, email, auth_provider, oauth_uid, full_name, avatar_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
            ->execute([$userId, $pharmacyId, 'owner', $email, 'google', $oauth_uid, $full_name, $avatar_url]);

        $pdo->prepare('INSERT INTO subscriptions (id, pharmacy_id, plan_name, billing_cycle, valid_until, status) VALUES (?, ?, ?, ?, ?, ?)')
            ->execute([$subId, $pharmacyId, 'Trial', 'monthly', $trialExpiry, 'active']);

        $user = [
            'id' => $userId,
            'pharmacy_id' => $pharmacyId,
            'role' => 'owner',
            'is_active' => 1,
            'valid_until' => $trialExpiry,
            'sub_status' => 'active'
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

    $stmtDevice = $pdo->prepare('SELECT id FROM devices WHERE hardware_uid = ? AND pharmacy_id = ?');
    $stmtDevice->execute([$hardwareUid, $user['pharmacy_id']]);
    if (!$stmtDevice->fetch()) {
        $deviceId = generate_uuid_v4();
        $pdo->prepare('INSERT INTO devices (id, pharmacy_id, hardware_uid, device_name, last_login_at) VALUES (?, ?, ?, ?, NOW())')
            ->execute([$deviceId, $user['pharmacy_id'], $hardwareUid, 'POS Device']);
    } else {
        $pdo->prepare('UPDATE devices SET last_login_at = NOW() WHERE hardware_uid = ? AND pharmacy_id = ?')
            ->execute([$hardwareUid, $user['pharmacy_id']]);
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
        'iat'  => $issuedAt,
        'iss'  => 'pharmapos_license_server',
        'exp'  => $jwtExpiry, 
        'sub'  => $user['id'],
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
            'valid_until' => $user['valid_until']
        ],
        'user' => [
            'id' => $user['id'],
            'role' => $user['role'],
            'name' => $full_name,
            'avatar' => $avatar_url
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("Login Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}