<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/device_auth_helper.php';

[$_jwt_decoded, $pdo] = device_auth_require_jwt();

$data = json_decode(file_get_contents("php://input"));

if (empty($data->pharmacy_id) || empty($data->plan_id) || empty($data->coupon_code)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "pharmacy_id, plan_id, and coupon_code are required."]);
    exit;
}

try {
    $pdo->beginTransaction();

    // 1. Validate Pharmacy & Plan
    $planStmt = $pdo->prepare("SELECT * FROM subscription_plans WHERE id = ?");
    $planStmt->execute([$data->plan_id]);
    $plan = $planStmt->fetch(PDO::FETCH_ASSOC);

    if (!$plan) {
        throw new Exception("Invalid Plan ID.");
    }

    // 2. Validate Coupon
    $couponCode = trim($data->coupon_code);
    $couponStmt = $pdo->prepare("SELECT * FROM coupons WHERE code = ? FOR UPDATE");
    $couponStmt->execute([$couponCode]);
    $coupon = $couponStmt->fetch(PDO::FETCH_ASSOC);

    if (!$coupon) {
        throw new Exception("Invalid coupon code.");
    }

    if (!empty($coupon['expires_at'])) {
        $expiresAt = new DateTime($coupon['expires_at']);
        $now = new DateTime();
        if ($now > $expiresAt) {
            throw new Exception("This coupon has expired.");
        }
    }

    if (!empty($coupon['max_uses']) && $coupon['used_count'] >= $coupon['max_uses']) {
        throw new Exception("This coupon has reached its maximum usage limit.");
    }

    // 3. Ensure it's a Free Days coupon
    if ($coupon['free_days'] <= 0) {
        throw new Exception("This coupon does not provide free days and cannot be applied directly via this endpoint.");
    }

    $freeDays = (int)$coupon['free_days'];

    // 4. Update Coupon uses
    $updateCoupon = $pdo->prepare("UPDATE coupons SET used_count = used_count + 1 WHERE id = ?");
    $updateCoupon->execute([$coupon['id']]);

    // 5. Log as a 0 amount "payment" just for tracking
    $paymentId = generate_uuid_v4();
    $merchantTxnId = "FREE-" . time() . "-" . substr(uniqid(), -5);

    $logStmt = $pdo->prepare("INSERT INTO payments (id, pharmacy_id, plan_id, amount, merchant_transaction_id, payment_status, coupon_id, payment_date) VALUES (?, ?, ?, 0.00, ?, 'completed', ?, NOW())");
    $logStmt->execute([
        $paymentId,
        $data->pharmacy_id,
        $data->plan_id,
        $merchantTxnId,
        $coupon['id']
    ]);

    // 6. Apply to subscriber
    $updateSub = $pdo->prepare("UPDATE subscribers SET plan_id = ?, is_paid = 1, status = 'active', valid_until = DATE_ADD(IFNULL(valid_until, NOW()), INTERVAL ? DAY), renewed_at = NOW(), payment_ref = ?, coupon_id = ? WHERE pharmacy_id = ?");
    $updateSub->execute([
        $data->plan_id, 
        $freeDays, 
        $merchantTxnId, 
        $coupon['id'], 
        $data->pharmacy_id
    ]);

    $unlockUser = $pdo->prepare("UPDATE users SET is_active = 1 WHERE pharmacy_id = ?");
    $unlockUser->execute([$data->pharmacy_id]);

    $pdo->commit();

    echo json_encode([
        "status" => "success",
        "message" => "Coupon successfully applied. $freeDays free days added.",
        "free_days" => $freeDays
    ]);

} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
