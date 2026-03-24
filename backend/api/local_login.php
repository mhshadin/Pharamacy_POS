<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;

// Import config (This gives us $pdo, the constants, and generate_uuid_v4)
require_once __DIR__ . '/config.php';

$inputData = json_decode(file_get_contents('php://input'), true);

if (!isset($inputData['email']) || !isset($inputData['password'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Email and password are required.']);
    exit;
}

$email = trim($inputData['email']);
$password = $inputData['password'];
$hardwareUid = isset($inputData['hardware_uid']) ? $inputData['hardware_uid'] : 'unknown_device';

try {
    $stmt = $pdo->prepare('
        SELECT u.id, u.pharmacy_id, u.role, u.is_active, u.auth_provider, u.password_hash, u.full_name, u.avatar_url,
               s.valid_until, s.status as sub_status, sp.name as plan_name
        FROM users u
        LEFT JOIN subscribers s ON u.pharmacy_id = s.pharmacy_id
        LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
        WHERE u.email = ?
    ');
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid email or password.']);
        exit;
    }

    if (empty($user['password_hash'])) {
        http_response_code(400);
        echo json_encode(['error' => "You signed up with Google but haven't set a password yet. Please log in with Google first, then set a password in your profile settings."]);
        exit;
    }

    if (!password_verify($password, $user['password_hash'])) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid email or password.']);
        exit;
    }

    if ($user['is_active'] == 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account disabled.']);
        exit;
    }

    $pdo->beginTransaction();
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
            'valid_until' => $user['valid_until'],
            'plan_name' => $user['plan_name']
        ],
        'user' => [
            'id' => $user['id'],
            'role' => $user['role'],
            'email' => $email,
            'name' => $user['full_name'],
            'avatar' => $user['avatar_url']
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("Login Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}