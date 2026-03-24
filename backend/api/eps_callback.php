<?php
// This is the endpoint EPS redirects to after payment.
// It can handle GET or POST depending on your config, but we'll focus on the redirect first.

require_once '../config/database.php';
require_once 'eps_helper.php';

$merchantTxnId = $_GET['merchantTransactionId'] ?? $_POST['merchantTransactionId'] ?? null;
$status = $_GET['status'] ?? $_GET['type'] ?? 'unknown'; // EPS might send status in query string too

try {
    if ($merchantTxnId) {
        // We trigger verification regardless of what EPS says in the redirect URL for security
        verifyAndProcessEpsPayment($pdo, $merchantTxnId);
    }
    
    // After processing, redirect back to the app using a custom scheme or a success page
    // For now, let's just show a simple success message that the mobile app WebView will catch.
    ?>
    <!DOCTYPE html>
    <html>
    <head>
        <title>Payment Status</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { font-family: sans-serif; text-align: center; padding: 50px; background: #f4f7f6; }
            .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: inline-block; }
            h2 { color: #2d3436; }
            .btn { background: #00b894; color: white; padding: 10px 20px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="card">
            <?php if ($status === 'success' || $status === 'Successful'): ?>
                <h2>✅ Payment Successful!</h2>
                <p>Your subscription is being activated. You can now close this window.</p>
            <?php else: ?>
                <h2>❌ Payment Failed or Cancelled</h2>
                <p>Status: <?php echo htmlspecialchars($status); ?></p>
            <?php endif; ?>
            <p>Redirecting you back to the app...</p>
        </div>
        <script>
            // This allows the Flutter WebView to detect completion
            setTimeout(() => {
                window.location.href = "pharmacypos://payment_status?status=<?php echo $status; ?>&txn=<?php echo $merchantTxnId; ?>";
            }, 2000);
        </script>
    </body>
    </html>
    <?php

} catch (Exception $e) {
    echo "Error processing payment: " . $e->getMessage();
}
?>
