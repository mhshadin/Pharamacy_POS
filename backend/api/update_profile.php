<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

require_once __DIR__ . '/config.php';

// Authenticate via JWT Bearer token
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

if (empty($inputData['full_name'])) {
    http_response_code(400);
    echo json_encode(['error' => 'full_name is required.']);
    exit;
}

$fullName = trim($inputData['full_name']);

if (strlen($fullName) < 1 || strlen($fullName) > 100) {
    http_response_code(400);
    echo json_encode(['error' => 'Name must be between 1 and 100 characters.']);
    exit;
}

// avatar_url is optional — only update if explicitly provided (even if empty string to clear it)
$updateAvatar = array_key_exists('avatar_url', $inputData);
$avatarUrl = $updateAvatar ? ($inputData['avatar_url'] ?: null) : null;

try {
    if ($updateAvatar) {
        $stmt = $pdo->prepare('UPDATE users SET full_name = ?, avatar_url = ? WHERE id = ?');
        $stmt->execute([$fullName, $avatarUrl, $userId]);
    } else {
        $stmt = $pdo->prepare('UPDATE users SET full_name = ? WHERE id = ?');
        $stmt->execute([$fullName, $userId]);
    }

    if ($stmt->rowCount() === 0) {
        http_response_code(404);
        echo json_encode(['error' => 'User not found.']);
        exit;
    }

    // Return the updated user record
    $stmtUser = $pdo->prepare('SELECT id, email, role, full_name, avatar_url FROM users WHERE id = ?');
    $stmtUser->execute([$userId]);
    $user = $stmtUser->fetch(PDO::FETCH_ASSOC);

    http_response_code(200);
    echo json_encode([
        'message' => 'Profile updated successfully.',
        'user' => [
            'id'     => $user['id'],
            'name'   => $user['full_name'],
            'email'  => $user['email'],
            'role'   => $user['role'],
            'avatar' => $user['avatar_url'],
        ]
    ]);

} catch (Exception $e) {
    error_log("Update Profile Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error while updating profile.']);
}
