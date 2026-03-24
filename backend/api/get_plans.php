<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/config.php';

try {
    // Fetch all active plans
    $query = "SELECT id, name, price, description, billing_cycle, trial_days FROM subscription_plans ORDER BY price ASC";
    $stmt = $pdo->prepare($query);
    $stmt->execute();

    $plans = [];
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $plans[] = [
            "id" => $row['id'],
            "name" => $row['name'],
            "price" => (float)$row['price'],
            "description" => $row['description'],
            "billing_cycle" => $row['billing_cycle'],
            "trial_days" => (int)$row['trial_days']
        ];
    }

    echo json_encode([
        "status" => "success",
        "data" => $plans
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
