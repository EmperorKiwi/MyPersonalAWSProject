<?php
/*
 * Group 3 - Campus Resource Manager
 * Database configuration (MySQL 8 / RDS hardened)
 *
 * Loads creds from /var/www/app/.env on EC2, falls back to localhost for XAMPP.
 * Uses mysqli_init + options to set charset BEFORE connect, which is the
 * only reliable way to fix "Server sent charset unknown" with MySQL 8 + AL2023.
 */

// ───────────────────────────────────────────────────────────────────────────
// 1. Load .env file (written by deploy.sh on EC2)
// ───────────────────────────────────────────────────────────────────────────
$env_file = "/var/www/app/.env";
if (file_exists($env_file)) {
    foreach (file($env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        if (strpos($line, '=') === false)   continue;
        list($name, $value) = array_map('trim', explode('=', $line, 2));
        // Strip quotes if present
        $value = trim($value, "\"'");
        putenv("$name=$value");
        $_ENV[$name] = $value;
    }
}

// ───────────────────────────────────────────────────────────────────────────
// 2. Resolve credentials with fallbacks for local XAMPP development
// ───────────────────────────────────────────────────────────────────────────
$host       = getenv('DB_HOST')     ?: 'localhost';
$user       = getenv('DB_USER')     ?: 'root';
$pass       = getenv('DB_PASSWORD') ?: '';
$db         = getenv('DB_NAME')     ?: 'myprojectdb';
$server_id  = getenv('SERVER_ID')   ?: 'Local';

$s3_bucket_url = getenv('S3_BUCKET')
    ? "https://" . getenv('S3_BUCKET') . ".s3." . (getenv('AWS_REGION') ?: 'us-east-1') . ".amazonaws.com"
    : "";

// ───────────────────────────────────────────────────────────────────────────
// 3. Connect with charset set BEFORE handshake (fixes MySQL 8 charset error)
// ───────────────────────────────────────────────────────────────────────────
$conn = mysqli_init();

if (!$conn) {
    die("<h1>Database Init Failed</h1><p>Could not initialise mysqli.</p>");
}

// CRITICAL: set charset before real_connect so the handshake uses utf8mb4
$conn->options(MYSQLI_OPT_CONNECT_TIMEOUT, 10);
$conn->options(MYSQLI_INIT_COMMAND, "SET NAMES utf8mb4");

if (!@$conn->real_connect($host, $user, $pass, $db, 3306)) {
    $err = mysqli_connect_error() ?: "Unknown error";
    http_response_code(500);
    die(
        "<!DOCTYPE html><html><head><title>DB Error</title>" .
        "<style>body{font-family:Arial;max-width:800px;margin:40px auto;padding:0 20px;}" .
        "h1{color:#c00;}pre{background:#f4f4f4;padding:12px;border-radius:4px;}</style></head><body>" .
        "<h1>Database Connection Failed</h1>" .
        "<p><strong>Error:</strong> " . htmlspecialchars($err) . "</p>" .
        "<p><strong>Host:</strong> " . htmlspecialchars($host) . "</p>" .
        "<p><strong>Database:</strong> " . htmlspecialchars($db) . "</p>" .
        "<p><strong>User:</strong> " . htmlspecialchars($user) . "</p>" .
        "<p><strong>Server ID:</strong> " . htmlspecialchars($server_id) . "</p>" .
        "<hr><p>Troubleshooting:</p><ul>" .
        "<li>Check that the database '<code>$db</code>' exists on RDS</li>" .
        "<li>Check that the EC2 security group can reach RDS on port 3306</li>" .
        "<li>Check that <code>/var/www/app/.env</code> has the correct credentials</li>" .
        "</ul></body></html>"
    );
}

// Belt and braces: set the charset on the live connection too
$conn->set_charset("utf8mb4");
?>
