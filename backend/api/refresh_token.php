<?php
// backend/api/refresh_token.php
// Refactored to use persistent database-backed refresh tokens

ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/JWT/vendor/autoload.php';
use \Firebase\JWT\JWT;

// Import config (This gives us $pdo, the constants, generate_uuid_v4, and JWT_SECRET)
require_once __DIR__ . '/config.php';

$inputData = json_decode(file_get_contents('php://input'), true);
$refreshToken = isset($inputData['refresh_token']) ? trim($inputData['refresh_token']) : null;

// Debug logging
$log_file = __DIR__ . '/debug_refresh.log';
$timestamp = date('Y-m-d H:i:s');
$received = $refreshToken ? substr($refreshToken, 0, 10) . "..." : "EMPTY";
file_put_contents($log_file, "[$timestamp] Received token: $received\n", FILE_APPEND);

if (!$refreshToken) {
    file_put_contents($log_file, "[$timestamp] Error: Token missing in JSON body\n", FILE_APPEND);
    http_response_code(400);
    echo json_encode(['error' => 'Refresh token is required.']);
    exit;
}

try {
    $tokenHash = hash('sha256', $refreshToken);

    // 1. Validate token from database
    $stmt = $pdo->prepare('
        SELECT rt.*, u.id as user_id, u.pharmacy_id, u.role, u.is_active, u.full_name, u.avatar_url,
               u.email, u.phone_number,
               s.valid_until, s.status as sub_status, sp.name as plan_name, sp.trial_days
        FROM refresh_tokens rt
        JOIN users u ON rt.user_id = u.id
        LEFT JOIN subscribers s ON u.pharmacy_id = s.pharmacy_id
        LEFT JOIN subscription_plans sp ON s.plan_id = sp.id
        WHERE rt.token_hash = ? AND rt.revoked = 0 AND rt.expires_at > NOW()
    ');
    $stmt->execute([$tokenHash]);
    $data = $stmt->fetch();

    if (!$data) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid, revoked, or expired refresh token.']);
        exit;
    }

    if ($data['is_active'] == 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account disabled.']);
        exit;
    }

    // 2. Refresh Token Rotation (Generate a new refresh token)
    $newRefreshToken = bin2hex(random_bytes(32));
    $newRefreshTokenHash = hash('sha256', $newRefreshToken);
    $newRefreshTokenExpiry = date('Y-m-d H:i:s', time() + (60 * 60 * 24 * 30)); // 30 days

    $pdo->beginTransaction();
    try {
        // Revoke the old token
        $pdo->prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?')
            ->execute([$data['id']]);

        // Insert new token
        $stmtRT = $pdo->prepare('INSERT INTO refresh_tokens (id, user_id, hardware_uid, token_hash, expires_at) VALUES (?, ?, ?, ?, ?)');
        $stmtRT->execute([
            generate_uuid_v4(),
            $data['user_id'],
            $data['hardware_uid'],
            $newRefreshTokenHash,
            $newRefreshTokenExpiry
        ]);
        $pdo->commit();
    } catch (Exception $eE) {
        $pdo->rollBack();
        throw $eE;
    }

    // 3. Generate a fresh Access Token (JWT)
    $issuedAt = time();
    $subExpiryTimestamp = strtotime($data['valid_until']);
    $jwtExpiry = $issuedAt + (60 * 60 * 24); // 24 hours expiry for JWT

    $jwtPayload = [
        'iat' => $issuedAt,
        'iss' => 'pharmapos_license_server',
        'exp' => $jwtExpiry,
        'sub' => $data['user_id'],
        'pharmacy_id' => $data['pharmacy_id'],
        'role' => $data['role'],
        'sub_expires_at' => $subExpiryTimestamp,
        'sub_status' => $data['sub_status']
    ];

    $licenseToken = JWT::encode($jwtPayload, JWT_SECRET, 'HS256');

    http_response_code(200);
    echo json_encode([
        'message' => 'Token refreshed',
        'license_token' => $licenseToken,
        'refresh_token' => $newRefreshToken, // Return the NEW refresh token for rotation
        'subscription' => [
            'status' => $data['sub_status'],
            'valid_until' => $data['valid_until'],
            'plan_name' => $data['plan_name'],
            'total_plan_days' => (int)($data['trial_days'] ?? 0) > 0
                ? (int)$data['trial_days']
                : ($data['sub_status'] === null ? 0 : 30)
        ],
        'user' => [
            'id' => $data['user_id'],
            'pharmacy_id' => $data['pharmacy_id'],
            'role' => $data['role'],
            'email' => $data['email'],
            'name' => $data['full_name'],
            'avatar' => $data['avatar_url'],
            'phone_number' => $data['phone_number'],
            'is_active' => (int)$data['is_active']
        ]
    ]);

} catch (Exception $e) {
    error_log("Refresh API Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error during refresh.']);
}
?>