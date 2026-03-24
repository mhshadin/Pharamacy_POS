<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: application/json');

require_once __DIR__ . '/vendor/autoload.php';
use \Firebase\JWT\JWT;
use \Firebase\JWT\Key;

require_once __DIR__ . '/config.php';

// Create pharmacy_settings table if it doesn't exist
try {
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS pharmacy_settings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            pharmacy_id VARCHAR(255) NOT NULL,
            setting_key VARCHAR(100) NOT NULL,
            setting_value TEXT,
            UNIQUE KEY unique_pharmacy_setting (pharmacy_id, setting_key)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
} catch (Exception $e) {
    error_log("Failed to create pharmacy_settings table: " . $e->getMessage());
}

// Authenticate via JWT Bearer Token
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
    $userId      = $decoded->sub;
    $pharmacyId  = $decoded->pharmacy_id;
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized. Expired or forged token.']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

// ──────────────────────────────────────────────
// GET  → return the stored admin PIN for this pharmacy
// ──────────────────────────────────────────────
if ($method === 'GET') {
    try {
        $stmt = $pdo->prepare(
            "SELECT setting_value FROM pharmacy_settings
             WHERE pharmacy_id = ? AND setting_key = 'admin_pin'
             LIMIT 1"
        );
        $stmt->execute([$pharmacyId]);
        $row = $stmt->fetch();

        $pin = $row ? $row['setting_value'] : '12345';

        http_response_code(200);
        echo json_encode(['admin_pin' => $pin]);
    } catch (Exception $e) {
        error_log("Admin PIN GET Error: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Server error retrieving PIN.']);
    }
    exit;
}

// ──────────────────────────────────────────────
// POST → update the admin PIN for this pharmacy
// ──────────────────────────────────────────────
if ($method === 'POST') {
    $inputData = json_decode(file_get_contents('php://input'), true);

    if (empty($inputData['new_pin'])) {
        http_response_code(400);
        echo json_encode(['error' => 'new_pin is required.']);
        exit;
    }

    $newPin = trim($inputData['new_pin']);

    if (strlen($newPin) < 4) {
        http_response_code(400);
        echo json_encode(['error' => 'PIN must be at least 4 characters.']);
        exit;
    }

    try {
        // Upsert: insert if not exists, update if exists
        $stmt = $pdo->prepare(
            "INSERT INTO pharmacy_settings (pharmacy_id, setting_key, setting_value)
             VALUES (?, 'admin_pin', ?)
             ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)"
        );
        $stmt->execute([$pharmacyId, $newPin]);

        http_response_code(200);
        echo json_encode(['message' => 'Admin PIN updated successfully.']);
    } catch (Exception $e) {
        error_log("Admin PIN POST Error: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(['error' => 'Server error updating PIN.']);
    }
    exit;
}

// Method not allowed
http_response_code(405);
echo json_encode(['error' => 'Method not allowed. Use GET or POST.']);
