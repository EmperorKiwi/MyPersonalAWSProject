<?php
/*
 * Group 3 - CloudWatch Metrics Helper v2 (PHP 5.6+ compatible)
 *
 * CHANGES from v1:
 *   - All metric names auto-prefixed with "mp_" (e.g. mp_BookingsCreated)
 *   - Synchronous push (no background &) so metrics actually reach CloudWatch
 *   - Added stderr capture so AWS errors land in the log
 *
 * Usage in confirm.php:
 *   require_once("metrics.php");
 *   pushMetric("BookingsCreated", 1);   // becomes mp_BookingsCreated in CloudWatch
 *   pushMetric("BookingErrors", 1);
 */

define('CW_NAMESPACE',     'MyProject/Application');
define('CW_REGION',        'us-east-1');
define('CW_LOG_FILE',      '/var/log/app/metrics.log');
define('CW_METRIC_PREFIX', 'mp_');

/**
 * Locate the AWS CLI binary. Returns absolute path or false.
 */
function findAwsBinary() {
    $candidates = array(
        '/usr/local/bin/aws',
        '/usr/bin/aws',
        '/opt/aws/bin/aws',
    );
    foreach ($candidates as $path) {
        if (is_executable($path)) return $path;
    }
    $found = trim(shell_exec('which aws 2>/dev/null'));
    return $found ? $found : false;
}

function metricsLog($line) {
    @file_put_contents(CW_LOG_FILE, date('c') . ' ' . $line . "\n", FILE_APPEND);
}

/**
 * Push a single CloudWatch metric. SYNCHRONOUS — guarantees the call completes.
 */
function pushMetric($metricName, $value = 1, $unit = 'Count') {
    if (!function_exists('exec')) {
        metricsLog("ERROR: exec() disabled");
        return false;
    }

    $aws = findAwsBinary();
    if (!$aws) {
        metricsLog("ERROR: aws CLI not found");
        return false;
    }

    $prefixedName = (strpos($metricName, CW_METRIC_PREFIX) === 0)
        ? $metricName
        : CW_METRIC_PREFIX . $metricName;

    $cmd = sprintf(
        "%s cloudwatch put-metric-data --namespace %s --metric-name %s --value %f --unit %s --region %s 2>&1",
        escapeshellarg($aws),
        escapeshellarg(CW_NAMESPACE),
        escapeshellarg($prefixedName),
        (float)$value,
        escapeshellarg($unit),
        escapeshellarg(CW_REGION)
    );

    $output = array();
    $exit_code = 0;
    @exec($cmd, $output, $exit_code);

    $output_str = implode(' | ', $output);
    if ($exit_code === 0) {
        metricsLog("OK push: $prefixedName=$value");
        return true;
    } else {
        metricsLog("FAIL push: $prefixedName=$value (exit=$exit_code) $output_str");
        return false;
    }
}

/**
 * Push multiple metrics in a single API call (more efficient).
 */
function pushMetricsBatch($metrics) {
    if (!function_exists('exec') || empty($metrics)) return false;

    $aws = findAwsBinary();
    if (!$aws) return false;

    $data_parts = array();
    foreach ($metrics as $m) {
        $name  = isset($m['name'])  ? $m['name']  : 'Unknown';
        $val   = (float)(isset($m['value']) ? $m['value'] : 1);
        $unit  = isset($m['unit'])  ? $m['unit']  : 'Count';

        $prefixedName = (strpos($name, CW_METRIC_PREFIX) === 0)
            ? $name
            : CW_METRIC_PREFIX . $name;

        $data_parts[] = sprintf('MetricName=%s,Value=%f,Unit=%s', $prefixedName, $val, $unit);
    }
    $metric_data = implode(' ', $data_parts);

    $cmd = sprintf(
        "%s cloudwatch put-metric-data --namespace %s --metric-data %s --region %s 2>&1",
        escapeshellarg($aws),
        escapeshellarg(CW_NAMESPACE),
        $metric_data,
        escapeshellarg(CW_REGION)
    );

    $output = array();
    $exit_code = 0;
    @exec($cmd, $output, $exit_code);

    $output_str = implode(' | ', $output);
    if ($exit_code === 0) {
        metricsLog("OK batch: " . count($metrics) . " metrics");
        return true;
    } else {
        metricsLog("FAIL batch: " . count($metrics) . " metrics (exit=$exit_code) $output_str");
        return false;
    }
}
