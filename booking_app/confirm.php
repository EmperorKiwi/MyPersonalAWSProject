<?php
require_once("db_config.php");
require_once("metrics.php");   // CloudWatch metrics helper

// ----- Validate input (PHP 5.6+ compatible — no ?? operator) -----
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: index.php");
    exit;
}

$start_time = microtime(true);

$name       = trim(isset($_POST['name'])       ? $_POST['name']       : '');
$email      = trim(isset($_POST['email'])      ? $_POST['email']      : '');
$service_id = (int)(isset($_POST['service_id']) ? $_POST['service_id'] : 0);
$appt_date  = isset($_POST['appt_date'])       ? $_POST['appt_date']  : '';
$appt_time  = isset($_POST['appt_time'])       ? $_POST['appt_time']  : '';
$notes      = trim(isset($_POST['notes'])      ? $_POST['notes']      : '');

if (!$name || !$email || !$service_id || !$appt_date || !$appt_time) {
    pushMetric("BookingErrors", 1);  // becomes mp_BookingErrors
    die("<h1>Error</h1><p>All required fields must be filled in. <a href='index.php'>Go back</a></p>");
}

// ----- Insert into DB using prepared statement (SQL injection safe) -----
$stmt = $conn->prepare(
    "INSERT INTO appointments (name, email, service_id, appt_date, appt_time, notes, created_at)
     VALUES (?, ?, ?, ?, ?, ?, NOW())"
);
$stmt->bind_param("ssisss", $name, $email, $service_id, $appt_date, $appt_time, $notes);

if (!$stmt->execute()) {
    pushMetric("BookingErrors", 1);
    die("<h1>Booking Failed</h1><p>" . htmlspecialchars($stmt->error) . "</p>");
}

$booking_id = $stmt->insert_id;
$stmt->close();

// Calculate booking latency
$latency_ms = (microtime(true) - $start_time) * 1000;
$server_id = getenv('SERVER_ID') ? getenv('SERVER_ID') : 'Unknown';

// Push metrics — names will be auto-prefixed with mp_
pushMetricsBatch(array(
    array('name' => 'BookingsCreated', 'value' => 1,           'unit' => 'Count'),
    array('name' => 'BookingValue',    'value' => 1,           'unit' => 'Count'),
    array('name' => 'BookingLatency',  'value' => $latency_ms, 'unit' => 'Milliseconds'),
));

// ----- Fetch service name for display -----
$svc_stmt = $conn->prepare("SELECT name, image_filename FROM services WHERE id = ?");
$svc_stmt->bind_param("i", $service_id);
$svc_stmt->execute();
$service = $svc_stmt->get_result()->fetch_assoc();
$svc_stmt->close();

$img_src = $s3_bucket_url
    ? $s3_bucket_url . "/services/" . $service['image_filename']
    : "images/" . $service['image_filename'];
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Booking Confirmed - Group 3</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: Arial, sans-serif; }
        body { background: #f4f6fb; color: #222; }
        header { background: #1F3864; color: white; padding: 18px 30px; }
        .container { max-width: 700px; margin: 40px auto; padding: 0 20px; }
        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); text-align: center; }
        .check { font-size: 64px; color: #28a745; margin-bottom: 20px; }
        h1 { color: #1F3864; margin-bottom: 10px; }
        .booking-id { background: #e8f4ea; padding: 8px 16px; display: inline-block; border-radius: 20px; color: #28a745; font-weight: bold; margin: 16px 0; }
        .details { text-align: left; background: #f4f6fb; padding: 20px; border-radius: 6px; margin: 20px 0; }
        .details dl { display: grid; grid-template-columns: 120px 1fr; gap: 10px; }
        .details dt { font-weight: bold; color: #1F3864; }
        img.service-img { width: 180px; height: 120px; object-fit: cover; border-radius: 6px; margin: 20px 0; }
        .btn { display: inline-block; background: #1F3864; color: white; padding: 12px 24px; border-radius: 4px; text-decoration: none; margin-top: 20px; font-weight: bold; }
        .btn:hover { background: #2E5FA3; }
        footer { text-align: center; padding: 20px; color: #888; font-size: 12px; margin-top: 40px; }
    </style>
</head>
<body>
<header><h1>Booking Confirmed</h1></header>

<div class="container">
    <div class="card">
        <div class="check">&check;</div>
        <h1>Thank you, <?php echo htmlspecialchars($name); ?>!</h1>
        <p>Your booking has been successfully recorded.</p>
        <div class="booking-id">Booking Ref: #<?php echo $booking_id; ?></div>

        <img src="<?php echo htmlspecialchars($img_src); ?>" alt="Service" class="service-img"
             onerror="this.style.display='none'">

        <div class="details">
            <dl>
                <dt>Service:</dt>        <dd><?php echo htmlspecialchars($service['name']); ?></dd>
                <dt>Date:</dt>           <dd><?php echo htmlspecialchars($appt_date); ?></dd>
                <dt>Time:</dt>           <dd><?php echo htmlspecialchars($appt_time); ?></dd>
                <dt>Email:</dt>          <dd><?php echo htmlspecialchars($email); ?></dd>
                <?php if ($notes): ?>
                <dt>Notes:</dt>          <dd><?php echo nl2br(htmlspecialchars($notes)); ?></dd>
                <?php endif; ?>
            </dl>
        </div>

        <a href="index.php" class="btn">Book Another</a>
        <a href="admin.php" class="btn" style="background:#6c757d;">View All Bookings</a>
    </div>
</div>

<footer>
    Group 3 - Campus Resource Manager | Served by: <strong><?php echo htmlspecialchars($server_id); ?></strong>
</footer>
</body>
</html>
<?php $conn->close(); ?>
