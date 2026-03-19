<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;

// Import config (This gives us $pdo, the constants, and generate_uuid_v4)
require_once __DIR__ . '/config.php';

$inputData = json_decode(file_get_contents('php://input'), true);

if (empty($inputData['email']) || empty($inputData['password']) || empty($inputData['full_name']) || empty($inputData['business_name'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Email, password, full name, and business name are required.']);
    exit;
}

if (strlen($inputData['password']) < 8) {
    http_response_code(400);
    echo json_encode(['error' => 'Password must be at least 8 characters long.']);
    exit;
}

if (!filter_var($inputData['email'], FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid email format.']);
    exit;
}

$email = trim($inputData['email']);
$password = $inputData['password'];
$fullName = trim($inputData['full_name']);
$businessName = trim($inputData['business_name']);
$hardwareUid = isset($inputData['hardware_uid']) ? $inputData['hardware_uid'] : 'unknown_device';

try {
    $stmt = $pdo->prepare('SELECT id FROM users WHERE email = ?');
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        http_response_code(409);
        echo json_encode(['error' => 'An account with this email already exists.']);
        exit;
    }

    $passwordHash = password_hash($password, PASSWORD_BCRYPT);

    $pdo->beginTransaction();

    $pharmacyId = generate_uuid_v4();
    $userId = generate_uuid_v4();
    $subId = generate_uuid_v4();
    $deviceId = generate_uuid_v4();
    
    $trialExpiry = date('Y-m-d H:i:s', strtotime('+14 days'));

    $pdo->prepare('INSERT INTO pharmacies (id, business_name, owner_name, contact_phone, contact_email, account_status) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$pharmacyId, $businessName, $fullName, 'PENDING', $email, 'trial']);

    $pdo->prepare('INSERT INTO users (id, pharmacy_id, role, email, auth_provider, oauth_uid, password_hash, full_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        ->execute([$userId, $pharmacyId, 'owner', $email, 'local', null, $passwordHash, $fullName]);

    $pdo->prepare('INSERT INTO subscriptions (id, pharmacy_id, plan_name, billing_cycle, valid_until, status) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$subId, $pharmacyId, 'Trial', 'monthly', $trialExpiry, 'active']);

    $pdo->prepare('INSERT INTO devices (id, pharmacy_id, hardware_uid, device_name, last_login_at) VALUES (?, ?, ?, ?, NOW())')
        ->execute([$deviceId, $pharmacyId, $hardwareUid, 'POS Device']);

    $pdo->commit();

    $issuedAt = time();
    $subExpiryTimestamp = strtotime($trialExpiry); 
    $jwtExpiry = $issuedAt + (60 * 60 * 24 * 30); 

    $jwtPayload = [
        'iat'  => $issuedAt,
        'iss'  => 'pharmapos_license_server',
        'exp'  => $jwtExpiry, 
        'sub'  => $userId,
        'pharmacy_id' => $pharmacyId,
        'role' => 'owner',
        'sub_expires_at' => $subExpiryTimestamp,
        'sub_status' => 'active'
    ];

    $licenseToken = JWT::encode($jwtPayload, JWT_SECRET, 'HS256');

    http_response_code(201);
    echo json_encode([
        'message' => 'Account created successfully',
        'license_token' => $licenseToken,
        'subscription' => [
            'status' => 'active',
            'valid_until' => $trialExpiry
        ],
        'user' => [
            'id' => $userId,
            'role' => 'owner',
            'name' => $fullName,
            'avatar' => null
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("Registration Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error while creating the account.']);
}