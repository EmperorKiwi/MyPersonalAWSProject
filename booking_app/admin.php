<?php require_once("db_config.php"); ?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Admin - All Bookings | Group 3</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: Arial, sans-serif; }
        body { background: #f4f6fb; }
        header { background: #1F3864; color: white; padding: 18px 30px; }
        nav { background: #2E5FA3; padding: 10px 30px; }
        nav a { color: white; text-decoration: none; margin-right: 20px; font-weight: bold; }
        .container { max-width: 1200px; margin: 30px auto; padding: 0 20px; }
        h2 { color: #1F3864; margin-bottom: 16px; }
        .stats { display: flex; gap: 16px; margin-bottom: 30px; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; flex: 1; box-shadow: 0 2px 6px rgba(0,0,0,0.08); }
        .stat-card .num { font-size: 32px; color: #1F3864; font-weight: bold; }
        .stat-card .label { color: #666; font-size: 13px; text-transform: uppercase; }
        table { width: 100%; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 6px rgba(0,0,0,0.08); }
        th { background: #1F3864; color: white; padding: 12px; text-align: left; font-size: 14px; }
        td { padding: 12px; border-bottom: 1px solid #e0e6ef; font-size: 14px; }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #f8faff; }
        .badge { display: inline-block; background: #e8f4ea; color: #28a745; padding: 3px 10px; border-radius: 12px; font-size: 12px; font-weight: bold; }
        footer { text-align: center; padding: 20px; color: #888; font-size: 12px; margin-top: 40px; border-top: 1px solid #e0e6ef; }
        .empty { text-align: center; padding: 40px; color: #888; }
    </style>
</head>
<body>

<header>
    <h1>👤 Admin Dashboard</h1>
    <p style="opacity:0.85; font-size:14px;">Group 3 - Campus Resource Manager</p>
</header>

<nav>
    <a href="index.php">← Back to Booking</a>
    <a href="admin.php">📋 All Bookings</a>
</nav>

<div class="container">

    <?php
    $total       = $conn->query("SELECT COUNT(*) AS c FROM appointments")->fetch_assoc()['c'];
    $today_count = $conn->query("SELECT COUNT(*) AS c FROM appointments WHERE DATE(created_at)=CURDATE()")->fetch_assoc()['c'];
    $upcoming    = $conn->query("SELECT COUNT(*) AS c FROM appointments WHERE appt_date >= CURDATE()")->fetch_assoc()['c'];
    ?>

    <div class="stats">
        <div class="stat-card"><div class="num"><?php echo $total; ?></div><div class="label">Total Bookings</div></div>
        <div class="stat-card"><div class="num"><?php echo $today_count; ?></div><div class="label">Booked Today</div></div>
        <div class="stat-card"><div class="num"><?php echo $upcoming; ?></div><div class="label">Upcoming</div></div>
    </div>

    <h2>All Bookings</h2>
    <table>
        <thead>
            <tr>
                <th>#</th><th>Name</th><th>Email</th><th>Service</th>
                <th>Date</th><th>Time</th><th>Submitted</th>
            </tr>
        </thead>
        <tbody>
            <?php
            $sql = "SELECT a.id, a.name, a.email, s.name AS service, a.appt_date, a.appt_time, a.created_at
                    FROM appointments a
                    LEFT JOIN services s ON a.service_id = s.id
                    ORDER BY a.created_at DESC";
            $result = $conn->query($sql);
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $service_name = isset($row['service']) ? $row['service'] : 'N/A';
                    echo '<tr>';
                    echo '<td><span class="badge">#' . (int)$row['id'] . '</span></td>';
                    echo '<td>' . htmlspecialchars($row['name']) . '</td>';
                    echo '<td>' . htmlspecialchars($row['email']) . '</td>';
                    echo '<td>' . htmlspecialchars($service_name) . '</td>';
                    echo '<td>' . htmlspecialchars($row['appt_date']) . '</td>';
                    echo '<td>' . htmlspecialchars($row['appt_time']) . '</td>';
                    echo '<td style="color:#888;font-size:12px;">' . htmlspecialchars($row['created_at']) . '</td>';
                    echo '</tr>';
                }
            } else {
                echo '<tr><td colspan="7" class="empty">No bookings yet. Be the first to book!</td></tr>';
            }
            ?>
        </tbody>
    </table>

</div>

<footer>
    Group 3 - Campus Resource Manager | Admin View | Served by: <strong><?php echo htmlspecialchars($server_id); ?></strong>
</footer>

</body>
</html>
<?php $conn->close(); ?>
