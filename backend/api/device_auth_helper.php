<?php
/**
 * Shared JWT auth + JSON body helpers for device management endpoints.
 */
require_once __DIR__ . '/JWT/vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

require_once __DIR__ . '/config.php';

/**
 * @return array{0: object, 1: PDO} [$decoded, $pdo]
 */
function device_auth_require_jwt(): array
{
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authHeader = '';
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
    } elseif (isset($headers['authorization'])) {
        $authHeader = $headers['authorization'];
    } elseif (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $authHeader = $_SERVER['HTTP_AUTHORIZATION'];
    }

    if (!$authHeader || !preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
        http_response_code(401);
        echo json_encode(['error' => 'Unauthorized. Missing or invalid token.']);
        exit;
    }

    global $pdo;
    try {
        $decoded = JWT::decode($matches[1], new Key(JWT_SECRET, 'HS256'));
    } catch (Exception $e) {
        http_response_code(401);
        echo json_encode(['error' => 'Unauthorized. Expired or forged token.']);
        exit;
    }

    return [$decoded, $pdo];
}

/**
 * Read JSON body as associative array.
 */
function device_auth_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

/**
 * Hardware UID from JSON body (required for device-scoped actions).
 */
function device_auth_require_hardware_uid(array $body): string
{
    $uid = isset($body['hardware_uid']) ? trim((string)$body['hardware_uid']) : '';
    if ($uid === '') {
        http_response_code(400);
        echo json_encode(['error' => 'hardware_uid is required.']);
        exit;
    }
    return $uid;
}
