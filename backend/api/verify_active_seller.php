<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);
header('Content-Type: application/json');

set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

require_once __DIR__ . '/device_auth_helper.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed.']);
    exit;
}

[$decoded, $pdo] = device_auth_require_jwt();
$pharmacyId = $decoded->pharmacy_id;

$body = device_auth_json_body();
$hardwareUid = device_auth_require_hardware_uid($body);

try {
    $stmt = $pdo->prepare('
        SELECT is_active_seller FROM devices
        WHERE pharmacy_id = ? AND hardware_uid = ?
        LIMIT 1
    ');
    $stmt->execute([$pharmacyId, $hardwareUid]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(['error' => 'Device not registered.', 'is_active_seller' => false]);
        exit;
    }

    $isActive = (int)$row['is_active_seller'] === 1;

    http_response_code(200);
    echo json_encode(['is_active_seller' => $isActive]);
} catch (Exception $e) {
    error_log('verify_active_seller: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}
