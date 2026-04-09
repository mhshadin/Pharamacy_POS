<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/device_auth_helper.php';

[$decoded, $pdo] = device_auth_require_jwt();

try {
    $stmt = $pdo->prepare('
        SELECT u.is_active, s.valid_until, s.status AS sub_status
        FROM users u
        LEFT JOIN subscribers s ON u.pharmacy_id = s.pharmacy_id
        WHERE u.id = ?
    ');
    $stmt->execute([$decoded->sub]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        http_response_code(404);
        echo json_encode(['error' => 'User not found.']);
        exit;
    }

    echo json_encode([
        'is_active'   => (int)$row['is_active'],
        'valid_until' => $row['valid_until'],
        'sub_status'  => $row['sub_status'],
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Server error.']);
}
?>
