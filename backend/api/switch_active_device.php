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
$targetDeviceId = isset($body['target_device_id']) ? trim((string)$body['target_device_id']) : '';

if ($targetDeviceId === '') {
    http_response_code(400);
    echo json_encode(['error' => 'target_device_id is required.']);
    exit;
}

try {
    $pdo->beginTransaction();

    $stmtCur = $pdo->prepare('
        SELECT id, is_active_seller FROM devices
        WHERE pharmacy_id = ? AND hardware_uid = ?
        LIMIT 1
    ');
    $stmtCur->execute([$pharmacyId, $hardwareUid]);
    $current = $stmtCur->fetch(PDO::FETCH_ASSOC);

    if (!$current) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Device not registered for this pharmacy.']);
        exit;
    }

    if ((int)$current['is_active_seller'] !== 1) {
        $pdo->rollBack();
        http_response_code(403);
        echo json_encode(['error' => 'Only the active selling device can transfer selling to another phone.']);
        exit;
    }

    $stmtTgt = $pdo->prepare('
        SELECT id FROM devices
        WHERE id = ? AND pharmacy_id = ?
        LIMIT 1
    ');
    $stmtTgt->execute([$targetDeviceId, $pharmacyId]);
    $target = $stmtTgt->fetch(PDO::FETCH_ASSOC);

    if (!$target) {
        $pdo->rollBack();
        http_response_code(404);
        echo json_encode(['error' => 'Target device not found.']);
        exit;
    }

    if ($target['id'] === $current['id']) {
        $pdo->commit();
        http_response_code(200);
        echo json_encode(['message' => 'This device is already the active seller.', 'is_active_seller' => true]);
        exit;
    }

    $pdo->prepare('
        UPDATE devices SET is_active_seller = 0, updated_at = NOW()
        WHERE pharmacy_id = ?
    ')->execute([$pharmacyId]);

    $pdo->prepare('
        UPDATE devices
        SET is_active_seller = 1,
            activated_at = NOW(),
            updated_at = NOW()
        WHERE id = ? AND pharmacy_id = ?
    ')->execute([$targetDeviceId, $pharmacyId]);

    $pdo->commit();

    http_response_code(200);
    echo json_encode([
        'message' => 'Active selling device updated.',
        'active_device_id' => $targetDeviceId,
    ]);
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    error_log('switch_active_device: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}
