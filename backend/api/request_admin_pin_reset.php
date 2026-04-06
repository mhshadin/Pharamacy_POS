<?php
// backend/api/request_admin_pin_reset.php

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
require_once __DIR__ . '/mail_helper.php';

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

function json_ok_generic()
{
    // Prevent account enumeration: always generic success.
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'If an account exists for this email, an OTP has been sent.'
    ]);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['success' => false, 'error' => 'Method not allowed. Use POST.']);
        exit;
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $email = isset($input['email']) ? trim((string)$input['email']) : '';

    if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
        // Still return generic to avoid enumeration, but treat as ok.
        json_ok_generic();
    }

    // Find user by email
    $stmt = $pdo->prepare("SELECT id, pharmacy_id, is_active FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        json_ok_generic();
    }
    if ((int)$user['is_active'] === 0) {
        json_ok_generic();
    }

    ensure_admin_pin_reset_table($pdo);

    $userId = (string)$user['id'];
    $pharmacyId = (string)$user['pharmacy_id'];

    // Invalidate previous unused tokens
    $pdo->prepare("UPDATE admin_pin_reset_tokens SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL")
        ->execute([$userId]);

    // Generate OTP (6 digits)
    $otp = (string)random_int(100000, 999999);
    $minutesValid = 10;
    $expiresAt = (new DateTimeImmutable('now'))->add(new DateInterval('PT' . $minutesValid . 'M'))->format('Y-m-d H:i:s');

    $otpHash = password_hash($otp, PASSWORD_BCRYPT);

    $insert = $pdo->prepare("
        INSERT INTO admin_pin_reset_tokens (user_id, pharmacy_id, otp_hash, expires_at)
        VALUES (?, ?, ?, ?)
    ");
    $insert->execute([$userId, $pharmacyId, $otpHash, $expiresAt]);

    // Send email (PHPMailer)
    send_admin_pin_otp_email_or_fail($email, $otp, $minutesValid);

    json_ok_generic();
} catch (Throwable $e) {
    error_log("request_admin_pin_reset error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'Server error.']);
    exit;
}

