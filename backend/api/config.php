<?php
// backend/api/config.php

// 1. CREDENTIALS
define('WEB_CLIENT_ID', '1044506320101-d2u82o19cks959l14qv082j1jss1cuoh.apps.googleusercontent.com');
define('JWT_SECRET', 'YOUR_SUPER_LONG_RANDOM_SECRET_KEY_DO_NOT_SHARE');

define('DB_HOST', 'localhost');
define('DB_NAME', 'digitalbay_pharmapos');
define('DB_USER', 'digitalbay');
define('DB_PASS', 'Dbbd@0166');

// 2. CENTRALIZED DATABASE CONNECTION
try {
    $pdo = new PDO("mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4", DB_USER, DB_PASS);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database connection failed. Check config.php.']);
    exit;
}

// 3. CENTRALIZED HELPER FUNCTIONS
if (!function_exists('generate_uuid_v4')) {
    function generate_uuid_v4() {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}
?>
