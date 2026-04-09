<?php
ini_set('display_errors', 0);
ini_set('html_errors', 0);
error_reporting(E_ALL);
header('Content-Type: application/json');

// Convert warnings/notices to exceptions so we can return JSON errors.
set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

require_once __DIR__ . '/JWT/vendor/autoload.php';
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
$deviceModel = isset($inputData['device_model']) ? trim((string)$inputData['device_model']) : '';
$deviceDisplayName = isset($inputData['device_display_name']) ? trim((string)$inputData['device_display_name']) : '';
if ($deviceDisplayName === '') {
    $deviceDisplayName = 'POS Device';
}

try {
    $stmt = $pdo->prepare('
        SELECT u.id, u.pharmacy_id, u.role, u.is_active, u.auth_provider, u.password_hash, u.full_name, u.avatar_url, u.phone_number,
               s.valid_until, s.status as sub_status, sp.name as plan_name, sp.billing_cycle, sp.trial_days
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
    $stmtDevice = $pdo->prepare('SELECT id, pharmacy_id FROM devices WHERE hardware_uid = ? LIMIT 1');
    $stmtDevice->execute([$hardwareUid]);
    $existingDevice = $stmtDevice->fetch();
    if (!$existingDevice) {
        $countStmt = $pdo->prepare('SELECT COUNT(*) AS total_devices FROM devices WHERE pharmacy_id = ?');
        $countStmt->execute([$user['pharmacy_id']]);
        $deviceCount = (int)$countStmt->fetch()['total_devices'];
        $isActiveSeller = $deviceCount === 0 ? 1 : 0;
        $deviceId = generate_uuid_v4();
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
        if ($existingDevice['pharmacy_id'] !== $user['pharmacy_id']) {
            $pdo->rollBack();
            http_response_code(403);
            echo json_encode(['error' => 'DEVICE_ALREADY_REGISTERED']);
            exit;
        }
        $pdo->prepare('UPDATE devices SET last_login_at = NOW(), device_model = ?, device_display_name = ? WHERE hardware_uid = ? AND pharmacy_id = ?')
            ->execute([
                $deviceModel !== '' ? $deviceModel : null,
                $deviceDisplayName,
                $hardwareUid,
                $user['pharmacy_id']
            ]);
    }

    // If no active seller (data issue), activate earliest device by login time — not necessarily this login.
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

    $issuedAt = time();
    $validUntil = $user['valid_until'] ?? null;
    $subExpiryTimestamp = $validUntil ? strtotime($validUntil) : null;
    $effectiveSubStatus = $user['sub_status'] ?? 'expired';
    if (!empty($validUntil) && strtotime($validUntil) < time()) {
        $effectiveSubStatus = 'expired';
    }
    $jwtExpiry = $issuedAt + (60 * 60 * 24 * 30);

    $jwtPayload = [
        'iat'  => $issuedAt,
        'iss'  => 'pharmapos_license_server',
        'exp'  => $jwtExpiry, 
        'sub'  => $user['id'],
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
            'name' => $user['full_name'],
            'avatar' => $user['avatar_url'],
            'phone_number' => $user['phone_number'],
            'is_active' => (int)$user['is_active']
        ],
        'device' => [
            'hardware_uid' => $hardwareUid,
            'is_active_seller' => $isActiveSeller,
        ]
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    error_log("Login Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}