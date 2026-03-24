<?php
function verifyAndProcessEpsPayment($pdo, $merchantTxnId) {
    // 1. Fetch Payment Log
    $stmt = $pdo->prepare("SELECT * FROM payments WHERE merchant_transaction_id = ?");
    $stmt->execute([$merchantTxnId]);
    $payment = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$payment) {
        throw new Exception("Payment record not found for Transaction ID: $merchantTxnId");
    }

    if ($payment['payment_status'] === 'completed') {
        return ["status" => "success", "message" => "Payment already processed."];
    }

    // 2. Fetch EPS Settings
    $settingsStmt = $pdo->prepare("SELECT * FROM eps_settings LIMIT 1");
    $settingsStmt->execute();
    $eps = $settingsStmt->fetch(PDO::FETCH_ASSOC);

    if (!$eps) {
        throw new Exception("EPS credentials not found.");
    }

    $env = $eps['environment'];
    $baseUrl = ($env === 'production') ? $eps['production_api_base_url'] : $eps['sandbox_api_base_url'];
    $username = ($env === 'production') ? $eps['production_username'] : $eps['sandbox_username'];
    $password = ($env === 'production') ? $eps['production_password'] : $eps['sandbox_password'];
    $hashKey = ($env === 'production') ? $eps['production_hash_key'] : $eps['sandbox_hash_key'];

    // 3. Authenticate with EPS for Verification
    $authHash = hash_hmac('sha512', $username, mb_convert_encoding($hashKey, 'UTF-8'), true);
    $authHash = base64_encode($authHash);

    $authCh = curl_init("$baseUrl/Auth/GetToken");
    curl_setopt($authCh, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($authCh, CURLOPT_POST, true);
    curl_setopt($authCh, CURLOPT_HTTPHEADER, ["Content-Type: application/json", "x-hash: $authHash"]);
    curl_setopt($authCh, CURLOPT_POSTFIELDS, json_encode(["userName" => $username, "password" => $password]));
    curl_setopt($authCh, CURLOPT_SSL_VERIFYPEER, false);
    $authRes = json_decode(curl_exec($authCh), true);
    curl_close($authCh);

    if (empty($authRes['token'])) {
        throw new Exception("Failed to authenticate with EPS for verification.");
    }

    $token = $authRes['token'];

    // 4. Check Transaction Status
    $verifyHash = hash_hmac('sha512', $merchantTxnId, mb_convert_encoding($hashKey, 'UTF-8'), true);
    $verifyHash = base64_encode($verifyHash);

    $verifyCh = curl_init("$baseUrl/EPSEngine/CheckMerchantTransactionStatus");
    curl_setopt($verifyCh, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($verifyCh, CURLOPT_POST, true);
    curl_setopt($verifyCh, CURLOPT_HTTPHEADER, [
        "Content-Type: application/json",
        "Authorization: Bearer $token",
        "x-hash: $verifyHash"
    ]);
    curl_setopt($verifyCh, CURLOPT_POSTFIELDS, json_encode(["merchantTransactionId" => $merchantTxnId]));
    curl_setopt($verifyCh, CURLOPT_SSL_VERIFYPEER, false);
    $verifyRes = json_decode(curl_exec($verifyCh), true);
    curl_close($verifyCh);

    // EPS Response fields (Status can be 'Successful', 'Failed', etc.)
    $epsStatus = $verifyRes['Status'] ?? 'Unknown';
    $epsTxnId = $verifyRes['EPSTransactionId'] ?? null;

    if ($epsStatus === 'Successful') {
        $pdo->beginTransaction();
        try {
            // Update Payment log
            $updatePay = $pdo->prepare("UPDATE payments SET payment_status = 'completed', eps_transaction_id = ?, payment_date = NOW() WHERE merchant_transaction_id = ?");
            $updatePay->execute([$epsTxnId, $merchantTxnId]);

            // Fetch Plan Details to get duration
            $planStmt = $pdo->prepare("SELECT * FROM subscription_plans WHERE id = ?");
            $planStmt->execute([$payment['plan_id']]);
            $plan = $planStmt->fetch(PDO::FETCH_ASSOC);
            
            $duration = $plan['trial_days'] ?: 30; // Default to 30 if not trial
            if ($plan['billing_cycle'] === 'yearly') $duration = 365;

            // Update Subscriber record
            $updateSub = $pdo->prepare("UPDATE subscribers SET plan_id = ?, is_paid = 1, status = 'active', valid_until = DATE_ADD(NOW(), INTERVAL ? DAY), payment_ref = ? WHERE pharmacy_id = ?");
            $updateSub->execute([$payment['plan_id'], $duration, $merchantTxnId, $payment['pharmacy_id']]);

            $pdo->commit();
            return ["status" => "success", "message" => "Payment verified and subscription activated."];
        } catch (Exception $e) {
            $pdo->rollBack();
            throw $e;
        }
    } else {
        // Update payment status to matched EPS status if not successful
        $statusMap = ['Failed' => 'failed', 'Canceled' => 'cancelled'];
        $mappedStatus = $statusMap[$epsStatus] ?? 'failed';
        $updatePay = $pdo->prepare("UPDATE payments SET payment_status = ? WHERE merchant_transaction_id = ?");
        $updatePay->execute([$mappedStatus, $merchantTxnId]);
        
        return ["status" => "error", "message" => "Payment status is: $epsStatus"];
    }
}
?>
