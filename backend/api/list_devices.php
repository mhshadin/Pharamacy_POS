<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);
header('Content-Type: application/json');

set_error_handler(function ($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

require_once __DIR__ . '/device_auth_helper.php';

[$decoded, $pdo] = device_auth_require_jwt();
$pharmacyId = $decoded->pharmacy_id;

$body = device_auth_json_body();
$hardwareUid = isset($body['hardware_uid']) ? trim((string)$body['hardware_uid']) : '';

try {
    $stmt = $pdo->prepare('
        SELECT id, hardware_uid, device_name, device_model, device_display_name,
               last_login_at, is_active_seller, activated_at
        FROM devices
        WHERE pharmacy_id = ?
        ORDER BY last_login_at DESC
    ');
    $stmt->execute([$pharmacyId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    $devices = [];
    foreach ($rows as $row) {
        $devices[] = [
            'id' => $row['id'],
            'hardware_uid' => $row['hardware_uid'],
            'device_name' => $row['device_name'],
            'device_model' => $row['device_model'],
            'device_display_name' => $row['device_display_name'] ?? $row['device_name'] ?? 'POS Device',
            'last_login_at' => $row['last_login_at'],
            'is_active_seller' => (int)$row['is_active_seller'] === 1,
            'activated_at' => $row['activated_at'],
            'is_current_device' => $hardwareUid !== '' && $row['hardware_uid'] === $hardwareUid,
        ];
    }

    http_response_code(200);
    echo json_encode(['devices' => $devices]);
} catch (Exception $e) {
    error_log('list_devices: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}
