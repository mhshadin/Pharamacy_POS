<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Return current server time in UTC
$server_time = date('Y-m-d H:i:s');
$timestamp = time();

echo json_encode([
    "success" => true,
    "server_time" => $server_time,
    "timestamp" => $timestamp,
    "timezone" => date_default_timezone_get()
]);
?>
