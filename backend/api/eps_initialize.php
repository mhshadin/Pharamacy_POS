<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once __DIR__ . '/config.php';
// Helper to generate UUID v4
function generate_uuid_v4() {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
}

// Helper function for EPS HMAC-SHA512 Hash
function generateEpsHash($data, $hashKey) {
    if (!$hashKey) return "";
    $keyBytes = mb_convert_encoding($hashKey, 'UTF-8');
    $hash = hash_hmac('sha512', $data, $keyBytes, true);
    return base64_encode($hash);
}

// Helper to make CURL requests
function makeCurlRequest($url, $method, $headers, $body = null) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    if ($body) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false); // For testing, in production set to true
    
    $result = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'code' => $httpCode,
        'data' => json_decode($result, true),
        'raw' => $result
    ];
}

$data = json_decode(file_get_contents("php://input"));

if (empty($data->pharmacy_id) || empty($data->plan_id) || empty($data->platform)) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Incomplete data. pharmacy_id, plan_id, and platform are required."]);
    exit;
}

try {
    // 1. Fetch EPS Settings
    $settingsStmt = $pdo->prepare("SELECT * FROM eps_settings LIMIT 1");
    $settingsStmt->execute();
    $eps = $settingsStmt->fetch(PDO::FETCH_ASSOC);

    if (!$eps) {
        throw new Exception("EPS credentials not configured in database.");
    }

    $env = $eps['environment'];
    $baseUrl = ($env === 'production') ? $eps['production_api_base_url'] : $eps['sandbox_api_base_url'];
    $username = ($env === 'production') ? $eps['production_username'] : $eps['sandbox_username'];
    $password = ($env === 'production') ? $eps['production_password'] : $eps['sandbox_password'];
    $merchantId = ($env === 'production') ? $eps['production_merchant_id'] : $eps['sandbox_merchant_id'];
    $storeId = ($env === 'production') ? $eps['production_store_id'] : $eps['sandbox_store_id'];
    $hashKey = ($env === 'production') ? $eps['production_hash_key'] : $eps['sandbox_hash_key'];

    // 2. Validate Pharmacy & Plan
    $planStmt = $pdo->prepare("SELECT * FROM subscription_plans WHERE id = ?");
    $planStmt->execute([$data->plan_id]);
    $plan = $planStmt->fetch(PDO::FETCH_ASSOC);

    if (!$plan) {
        throw new Exception("Invalid Plan ID.");
    }

    $finalAmount = (float)$plan['price'];

    // 3. Handle Coupon (if provided)
    if (!empty($data->coupon_code)) {
        $couponStmt = $pdo->prepare("SELECT * FROM coupons WHERE code = ? AND (expires_at IS NULL OR expires_at > NOW()) AND (max_uses IS NULL OR used_count < max_uses)");
        $couponStmt->execute([$data->coupon_code]);
        $coupon = $couponStmt->fetch(PDO::FETCH_ASSOC);
        
        if ($coupon) {
            if ($coupon['discount_percent'] > 0) {
                $finalAmount = $finalAmount - ($finalAmount * ($coupon['discount_percent'] / 100));
            }
        }
    }

    // 4. Get EPS Token
    $authHash = generateEpsHash($username, $hashKey);
    $authResponse = makeCurlRequest(
        "$baseUrl/Auth/GetToken",
        "POST",
        ["Content-Type: application/json", "x-hash: $authHash"],
        ["userName" => $username, "password" => $password]
    );

    if ($authResponse['code'] != 200 || empty($authResponse['data']['token'])) {
        throw new Exception("EPS Authentication failed: " . ($authResponse['data']['message'] ?? 'Unknown error'));
    }

    $token = $authResponse['data']['token'];
    $merchantTxnId = "TXN-" . time() . "-" . substr(uniqid(), -5);

    // 5. Initialize EPS Payment
    $initHash = generateEpsHash($merchantTxnId, $hashKey);
    $platformId = ($data->platform === 'android') ? 2 : 3;

    $initPayload = [
        "merchantTransactionId" => $merchantTxnId,
        "transactionTypeId" => $platformId,
        "totalAmount" => round($finalAmount, 2),
        "successUrl" => $eps['success_url'],
        "failUrl" => $eps['fail_url'],
        "cancelUrl" => $eps['cancel_url'],
        "merchantId" => $merchantId,
        "storeId" => $storeId,
        "ValueA" => $data->pharmacy_id,
        "ValueB" => $data->plan_id,
        "ValueC" => $data->coupon_code ?? ""
    ];

    $initResponse = makeCurlRequest(
        "$baseUrl/EPSEngine/InitializeEPS",
        "POST",
        [
            "Content-Type: application/json", 
            "Authorization: Bearer $token",
            "x-hash: $initHash"
        ],
        $initPayload
    );

    if ($initResponse['code'] != 200 || empty($initResponse['data']['RedirectURL'])) {
        throw new Exception("EPS Initialization failed: " . ($initResponse['data']['message'] ?? 'Unknown error'));
    }

    // 6. Log Pending Payment
    $paymentId = generate_uuid_v4(); 
    $logStmt = $pdo->prepare("INSERT INTO payments (id, pharmacy_id, plan_id, amount, merchant_transaction_id, payment_status) VALUES (?, ?, ?, ?, ?, 'pending')");
    $logStmt->execute([
        $paymentId,
        $data->pharmacy_id,
        $data->plan_id,
        $finalAmount,
        $merchantTxnId
    ]);

    echo json_encode([
        "status" => "success",
        "redirect_url" => $initResponse['data']['RedirectURL'],
        "merchant_transaction_id" => $merchantTxnId
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => $e->getMessage()
    ]);
}
?>
