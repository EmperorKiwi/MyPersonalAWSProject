<?php
/*
 * ELB Target Group health check endpoint.
 * Returns HTTP 200 + JSON when the server AND database are reachable.
 * Configured as HealthCheckPath: /health.php in the ELB TargetGroup.
 */
header('Content-Type: application/json');

require_once("db_config.php");

// Test DB connectivity
$db_ok = false;
try {
    $result = $conn->query("SELECT 1");
    $db_ok = ($result !== false);
} catch (Exception $e) {
    $db_ok = false;
}

$conn->close();

if ($db_ok) {
    http_response_code(200);
    echo json_encode([
        "status"    => "healthy",
        "server_id" => $server_id,
        "db"        => "connected",
        "timestamp" => date("c")
    ]);
} else {
    http_response_code(503);
    echo json_encode([
        "status"    => "unhealthy",
        "server_id" => $server_id,
        "db"        => "disconnected",
        "timestamp" => date("c")
    ]);
}
