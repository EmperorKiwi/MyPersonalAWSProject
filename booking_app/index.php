<?php require_once("db_config.php"); ?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Group 3 - Campus Resource Manager</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: Arial, sans-serif; }
        body { background: #f4f6fb; color: #222; }
        header { background: #1F3864; color: white; padding: 18px 30px; }
        header h1 { font-size: 22px; }
        header p { font-size: 14px; opacity: 0.85; }
        nav { background: #2E5FA3; padding: 10px 30px; }
        nav a { color: white; text-decoration: none; margin-right: 20px; font-weight: bold; }
        nav a:hover { text-decoration: underline; }
        .container { max-width: 900px; margin: 30px auto; padding: 0 20px; }
        h2 { color: #1F3864; margin-bottom: 16px; }
        .services { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 30px; }
        .service-card { background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 6px rgba(0,0,0,0.08); transition: transform 0.2s; }
        .service-card:hover { transform: translateY(-3px); }
        .service-card img { width: 100%; height: 140px; object-fit: cover; background: #e0e6ef; }
        .service-card .info { padding: 12px; }
        .service-card h3 { color: #1F3864; font-size: 16px; margin-bottom: 4px; }
        .service-card p { color: #666; font-size: 13px; }
        form { background: white; padding: 24px; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.08); }
        .field { margin-bottom: 16px; }
        label { display: block; font-weight: bold; margin-bottom: 6px; color: #1F3864; }
        input, select, textarea { width: 100%; padding: 10px; border: 1px solid #ccd4e0; border-radius: 4px; font-size: 14px; }
        input:focus, select:focus { border-color: #2E5FA3; outline: none; }
        .row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
        button { background: #1F3864; color: white; padding: 12px 28px; border: none; border-radius: 4px; font-size: 15px; cursor: pointer; font-weight: bold; }
        button:hover { background: #2E5FA3; }
        footer { text-align: center; padding: 20px; color: #888; font-size: 12px; margin-top: 40px; border-top: 1px solid #e0e6ef; }
        .badge { display: inline-block; background: #28a745; color: white; padding: 2px 8px; border-radius: 12px; font-size: 11px; margin-left: 8px; }
    </style>
</head>
<body>

<header>
    <h1>🎓 Campus Resource Manager</h1>
    <p>Group 3 - CMP6210 Cloud Computing Project</p>
</header>

<nav>
    <a href="index.php">📅 Book a Resource</a>
    <a href="admin.php">👤 Admin View</a>
</nav>

<div class="container">

    <h2>Available Resources</h2>
    <div class="services">
        <?php
        $service_query = $conn->query("SELECT * FROM services ORDER BY id");
        while ($svc = $service_query->fetch_assoc()) {
            // Build image URL - S3 on AWS, local fallback for dev
            $img_src = $s3_bucket_url
                ? "{$s3_bucket_url}/services/{$svc['image_filename']}"
                : "images/{$svc['image_filename']}";
            echo '<div class="service-card">';
            echo '<img src="' . htmlspecialchars($img_src) . '" alt="' . htmlspecialchars($svc['name']) . '">';
            echo '<div class="info">';
            echo '<h3>' . htmlspecialchars($svc['name']) . '</h3>';
            echo '<p>' . htmlspecialchars($svc['description']) . '</p>';
            echo '</div></div>';
        }
        ?>
    </div>

    <h2>📅 Make a Booking</h2>
    <form action="confirm.php" method="POST">
        <div class="row">
            <div class="field">
                <label for="name">Your Name</label>
                <input type="text" id="name" name="name" required maxlength="100" placeholder="e.g. John Smith">
            </div>
            <div class="field">
                <label for="email">Email Address</label>
                <input type="email" id="email" name="email" required maxlength="150" placeholder="e.g. john@bcu.ac.uk">
            </div>
        </div>

        <div class="field">
            <label for="service_id">Resource / Service</label>
            <select id="service_id" name="service_id" required>
                <option value="">-- Select a resource --</option>
                <?php
                $svcs = $conn->query("SELECT id, name FROM services ORDER BY name");
                while ($s = $svcs->fetch_assoc()) {
                    echo '<option value="' . (int)$s['id'] . '">' . htmlspecialchars($s['name']) . '</option>';
                }
                ?>
            </select>
        </div>

        <div class="row">
            <div class="field">
                <label for="appt_date">Date</label>
                <input type="date" id="appt_date" name="appt_date" required min="<?php echo date("Y-m-d"); ?>">
            </div>
            <div class="field">
                <label for="appt_time">Time</label>
                <input type="time" id="appt_time" name="appt_time" required>
            </div>
        </div>

        <div class="field">
            <label for="notes">Notes (optional)</label>
            <textarea id="notes" name="notes" rows="3" maxlength="500" placeholder="Any additional information..."></textarea>
        </div>

        <button type="submit">Submit Booking →</button>
    </form>
</div>

<footer>
    Group 3 - Campus Resource Manager | Served by: <strong><?php echo htmlspecialchars($server_id); ?></strong>
    <span class="badge">HA via ELB</span>
</footer>

</body>
</html>
<?php $conn->close(); ?>
