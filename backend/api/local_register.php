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
$deviceModel = isset($inputData['device_model']) ? trim((string)$inputData['device_model']) : '';
$deviceDisplayName = isset($inputData['device_display_name']) ? trim((string)$inputData['device_display_name']) : '';
if ($deviceDisplayName === '') {
    $deviceDisplayName = 'POS Device';
}

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
    $subscriberId = generate_uuid_v4();
    $deviceId = generate_uuid_v4();
    
    // 1. Fetch Default "Trial" Plan
    $stmtPlan = $pdo->prepare('SELECT id, trial_days FROM subscription_plans WHERE name = ? LIMIT 1');
    $stmtPlan->execute(['Trial']);
    $plan = $stmtPlan->fetch();
    
    if (!$plan) {
        // Fallback if Trial plan is not seeded yet
        $planId = generate_uuid_v4();
        $trialDays = 14;
        $pdo->prepare('INSERT INTO subscription_plans (id, name, price, billing_cycle, trial_days) VALUES (?, ?, ?, ?, ?)')
            ->execute([$planId, 'Trial', 0.00, 'monthly', $trialDays]);
    } else {
        $planId = $plan['id'];
        $trialDays = $plan['trial_days'];
    }

    // 2. Handle Coupon Code
    $couponId = null;
    $extraDays = 0;
    if (!empty($inputData['coupon_code'])) {
        $stmtCoupon = $pdo->prepare('SELECT id, free_days, max_uses, used_count FROM coupons WHERE code = ? AND (expires_at IS NULL OR expires_at > NOW())');
        $stmtCoupon->execute([$inputData['coupon_code']]);
        $coupon = $stmtCoupon->fetch();
        
        if ($coupon && ($coupon['max_uses'] === null || $coupon['used_count'] < $coupon['max_uses'])) {
            $couponId = $coupon['id'];
            $extraDays = (int)$coupon['free_days'];
            // Increment used count
            $pdo->prepare('UPDATE coupons SET used_count = used_count + 1 WHERE id = ?')->execute([$couponId]);
        }
    }

    $totalDays = $trialDays + $extraDays;
    $expiryDate = date('Y-m-d H:i:s', strtotime("+$totalDays days"));

    $pdo->prepare('INSERT INTO pharmacies (id, business_name, owner_name, contact_phone, contact_email, account_status) VALUES (?, ?, ?, ?, ?, ?)')
        ->execute([$pharmacyId, $businessName, $fullName, 'PENDING', $email, 'active']);

    $pdo->prepare('INSERT INTO users (id, pharmacy_id, role, email, auth_provider, oauth_uid, password_hash, full_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
        ->execute([$userId, $pharmacyId, 'owner', $email, 'local', null, $passwordHash, $fullName]);

    $pdo->prepare('INSERT INTO subscribers (id, pharmacy_id, plan_id, valid_until, renewed_at, status, coupon_id) VALUES (?, ?, ?, ?, NOW(), ?, ?)')
        ->execute([$subscriberId, $pharmacyId, $planId, $expiryDate, 'active', $couponId]);

    $pdo->prepare('INSERT INTO devices (id, pharmacy_id, hardware_uid, device_name, device_model, device_display_name, last_login_at, is_active_seller, activated_at) VALUES (?, ?, ?, ?, ?, ?, NOW(), 1, NOW())')
        ->execute([$deviceId, $pharmacyId, $hardwareUid, 'POS Device', $deviceModel !== '' ? $deviceModel : null, $deviceDisplayName]);

    $pdo->commit();

    $issuedAt = time();
    $subExpiryTimestamp = strtotime($expiryDate); 
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
            'valid_until' => $expiryDate,
            'plan_name' => 'Trial',
            'total_plan_days' => $totalDays,
            'coupon_applied' => $couponId ? true : false
        ],
        'user' => [
            'id' => $userId,
            'pharmacy_id' => $pharmacyId,
            'role' => 'owner',
            'name' => $fullName,
            'avatar' => null,
            'is_active' => 1
        ],
        'device' => [
            'hardware_uid' => $hardwareUid,
            'is_active_seller' => true,
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("Registration Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error while creating the account.']);
}