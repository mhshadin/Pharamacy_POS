<?php
// backend/api/reset_admin_pin_with_otp.php

header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

ini_set('display_errors', 0);
ini_set('html_errors', 0);
error_reporting(E_ALL);

set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

require_once __DIR__ . '/config.php';

function ensure_admin_pin_reset_table(PDO $pdo)
{
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS admin_pin_reset_tokens (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id VARCHAR(36) NOT NULL,
            pharmacy_id VARCHAR(36) NOT NULL,
            otp_hash VARCHAR(255) NOT NULL,
            expires_at DATETIME NOT NULL,
            used_at DATETIME NULL,
            created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_user_expires_used (user_id, expires_at, used_at),
            INDEX idx_pharmacy (pharmacy_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ");
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['success' => false, 'error' => 'Method not allowed. Use POST.']);
        exit;
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $email = isset($input['email']) ? trim((string)$input['email']) : '';
    $otp = isset($input['otp']) ? trim((string)$input['otp']) : '';
    $newPin = isset($input['new_pin']) ? trim((string)$input['new_pin']) : '';

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'A valid email is required.']);
        exit;
    }
    if (!preg_match('/^\d{6}$/', $otp)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'OTP must be 6 digits.']);
        exit;
    }
    if ($newPin === '' || strlen($newPin) < 4) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'PIN must be at least 4 characters.']);
        exit;
    }

    $stmt = $pdo->prepare("SELECT id, pharmacy_id, is_active FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user || (int)$user['is_active'] === 0) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid OTP or expired.']);
        exit;
    }

    ensure_admin_pin_reset_table($pdo);

    $userId = (string)$user['id'];
    $pharmacyId = (string)$user['pharmacy_id'];

    $tokenStmt = $pdo->prepare("
        SELECT id, otp_hash, expires_at, used_at
        FROM admin_pin_reset_tokens
        WHERE user_id = ? AND used_at IS NULL AND expires_at > NOW()
        ORDER BY id DESC
        LIMIT 1
    ");
    $tokenStmt->execute([$userId]);
    $token = $tokenStmt->fetch(PDO::FETCH_ASSOC);

    if (!$token) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid OTP or expired.']);
        exit;
    }

    if (!password_verify($otp, (string)$token['otp_hash'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Invalid OTP or expired.']);
        exit;
    }

    $pdo->beginTransaction();

    // Mark token used
    $pdo->prepare("UPDATE admin_pin_reset_tokens SET used_at = NOW() WHERE id = ?")
        ->execute([(int)$token['id']]);

    // Upsert admin_pin in pharmacy_settings
    $upsert = $pdo->prepare("
        INSERT INTO pharmacy_settings (pharmacy_id, setting_key, setting_value)
        VALUES (?, 'admin_pin', ?)
        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)
    ");
    $upsert->execute([$pharmacyId, $newPin]);

    // Keep legacy users.pin_code in sync (and also matches current schema)
    $pdo->prepare("UPDATE users SET pin_code = ? WHERE id = ? AND pharmacy_id = ?")
        ->execute([$newPin, $userId, $pharmacyId]);

    $pdo->commit();

    http_response_code(200);
    echo json_encode(['success' => true, 'message' => 'Admin PIN updated successfully.']);
    exit;
} catch (Throwable $e) {
    if ($pdo && $pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log("reset_admin_pin_with_otp error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Server error.']);
    exit;
}

