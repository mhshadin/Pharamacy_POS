<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

// Import config (This gives us $pdo, the constants, and generate_uuid_v4)
require_once __DIR__ . '/config.php';

// Authenticate the User using the JWT Bearer Token
$headers = getallheaders();
$authHeader = isset($headers['Authorization']) ? $headers['Authorization'] : '';

if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized. Missing or invalid token.']);
    exit;
}

$jwt = $matches[1];

try {
    $decoded = JWT::decode($jwt, new Key(JWT_SECRET, 'HS256'));
    $userId = $decoded->sub;
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized. Expired or forged token.']);
    exit;
}

$inputData = json_decode(file_get_contents('php://input'), true);

if (empty($inputData['new_password'])) {
    http_response_code(400);
    echo json_encode(['error' => 'New password is required.']);
    exit;
}

$newPassword = $inputData['new_password'];

if (strlen($newPassword) < 8) {
    http_response_code(400);
    echo json_encode(['error' => 'Password must be at least 8 characters long.']);
    exit;
}

try {
    $passwordHash = password_hash($newPassword, PASSWORD_BCRYPT);

    $stmt = $pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?');
    $stmt->execute([$passwordHash, $userId]);

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'User not found.']);
        exit;
    }

    http_response_code(200);
    echo json_encode(['message' => 'Password set successfully. You can now log in using your email and this password.']);

} catch (Exception $e) {
    error_log("Set Password Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error while updating password.']);
}