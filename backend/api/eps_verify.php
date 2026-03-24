<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';
require_once 'eps_helper.php';

$data = json_decode(file_get_contents("php://input"));

if (empty($data->merchant_transaction_id)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "merchant_transaction_id is required."]);
    exit;
}

try {
    $result = verifyAndProcessEpsPayment($pdo, $data->merchant_transaction_id);
    
    echo json_encode($result);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
