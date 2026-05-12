# Group 3 - Campus Resource Manager v4 — Complete Deployment Bundle

This is the consolidated, fully-tested bundle that wraps every fix discovered during D2 development. Use this for a fresh deployment or to update an existing stack.

## What's New in v4

| Fix | Where |
|---|---|
| **All metrics auto-prefixed `mp_`** | `metrics.php` |
| **Synchronous metric push** (so they actually appear in CloudWatch) | `metrics.php` |
| **Apache timezone warning eliminated** | `deploy.sh` step 2 |
| **PHP 5.6+ compatible syntax** (no `??`, no short echo `<?=`) | All `.php` files |
| **Database created with `utf8mb4_general_ci` collation** (avoids MySQL 8 charset error) | `deploy.sh` step 5 |
| **DirectoryIndex prefers index.php** | `deploy.sh` step 3 |
| **Placeholder index.html removed** | `deploy.sh` step 6 |
| **Booking latency tracking** | `confirm.php` (new metric `mp_BookingLatency`) |
| **SNS email subscription script** | `setup_sns.sh` |
| **All 4 alarms refer to `mp_*` metrics** | `setup_sns.sh` |

## Bundle Contents

```
MyProject_v4/
├── booking_app/
│   ├── db_config.php       # DB config with charset fix (PHP 5.6+ safe)
│   ├── index.php           # Booking form
│   ├── confirm.php         # Form handler — emits mp_* metrics on every booking
│   ├── admin.php           # Admin dashboard
│   ├── health.php          # ELB health-check endpoint
│   ├── metrics.php         # CloudWatch helper (mp_ prefix, synchronous push)
│   └── images/             # 6 service images for S3
├── sql_scripts/
│   ├── schema.sql          # CREATE TABLE for services, appointments
│   └── insert_data.sql     # 6 services + 6 sample bookings
├── scripts/
│   ├── deploy.sh           # Run on each EC2 — full bootstrap
│   ├── remote_deploy.sh    # Run from local — deploys to both EC2s
│   ├── setup_sns.sh        # Run from local — creates SNS topic + 4 alarms
│   └── load_test.sh        # Generates ~70 metric events for dashboard screenshots
└── README.md               # This file
```

---

## Full Deployment Steps

### Prerequisites

- AWS Academy lab session active
- CloudFormation stack already deployed (MyProject_v1.yaml)
- LabRole manually attached to both EC2 instances
- `MyProject_Key.pem` downloaded
- AWS CLI installed locally with Academy credentials configured (`aws configure`)
- Email address ready for SNS notifications

### Step 1: Get Stack Output Values

From **CloudFormation → your stack → Outputs tab**, copy:

- `WebServer1PublicIP`
- `WebServer2PublicIP`
- `RDSEndpoint`
- `StaticBucketName` (note: in your stack this is `myproject-static-<account-id>`)
- `ApplicationURL` (the ELB DNS)

### Step 2: Verify RDS DB Parameter Group

The custom parameter group `myproject-mysql8-params` should already be applied (set in v3 template). Verify:

1. RDS Console → Parameter groups → `myproject-mysql8-params` exists
2. RDS Console → Databases → `myproject-rds` → Configuration tab → DB parameter group should be `myproject-mysql8-params`

If not applied, attach it manually and reboot RDS (~2 min).

### Step 3: Deploy Application to Both EC2s

#### Option A: One-Command Remote Deploy (Recommended)

1. Unzip the bundle:
```bash
unzip MyProject_v4.zip
cd MyProject_v4
```

2. Edit `scripts/remote_deploy.sh` — fill in 6 values:
```bash
nano scripts/remote_deploy.sh
```
```bash
KEY_FILE="../MyProject_Key.pem"
WEBSERVER1_IP="3.95.xx.xx"
WEBSERVER2_IP="54.123.xx.xx"
RDS_ENDPOINT="myproject-rds.xxx.us-east-1.rds.amazonaws.com"
DB_PASSWORD="YourActualPassword"
S3_BUCKET="myproject-static-178389051981"
```

3. Run:
```bash
chmod +x scripts/remote_deploy.sh
./scripts/remote_deploy.sh
```

This uploads files to both EC2s, runs `deploy.sh` on each, and uploads images to S3 — all in one command.

#### Option B: Manual SSH Per-Instance

If `remote_deploy.sh` doesn't work (e.g., on Windows without Git Bash), do it manually for each server:

```bash
# Upload to WebServer1
chmod 400 MyProject_Key.pem
scp -i MyProject_Key.pem -r booking_app ec2-user@<WS1_IP>:/tmp/
scp -i MyProject_Key.pem sql_scripts/*.sql ec2-user@<WS1_IP>:/tmp/
scp -i MyProject_Key.pem scripts/deploy.sh ec2-user@<WS1_IP>:/tmp/

# SSH and run
ssh -i MyProject_Key.pem ec2-user@<WS1_IP>
chmod +x /tmp/deploy.sh
sudo /tmp/deploy.sh "<RDS_ENDPOINT>" "<DB_PASSWORD>" "<S3_BUCKET>" WebServer1
```

Repeat for WebServer2 with `WebServer2` as the last arg.

### Step 4: Upload Service Images to S3

If `remote_deploy.sh` did this for you, skip. Otherwise:

```bash
aws s3 cp booking_app/images/ s3://myproject-static-178389051981/services/ --recursive
```

Or via Console: S3 → bucket → create folder `services` → upload all 6 PNGs.

### Step 5: Make S3 Images Public

S3 Console → bucket → **Permissions** tab:

1. **Block public access** → Edit → uncheck "Block all public access" → Save
2. **Bucket policy** → Edit → paste (replace bucket name):

```json
{
    "Version": "2012-10-17",
    "Statement": [{
        "Sid": "AllowPublicReadServices",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::myproject-static-178389051981/services/*"
    }]
}
```

### Step 6: Fix ELB Health Check Path

EC2 → Target Groups → `MyProject-TG` → Health checks → Edit:
- **Path:** `/health.php` (NOT `/health`)
- Save

Wait 30 seconds → Targets tab → both should be **healthy**.

### Step 7: Set Up SNS + Alarms

```bash
chmod +x scripts/setup_sns.sh
./scripts/setup_sns.sh your.email@bcu.ac.uk
```

This script:

1. Creates SNS topic `MyProject_Alarms` if missing
2. Subscribes your email — **CHECK YOUR INBOX** for the AWS confirmation email and click the confirm link
3. After you press Enter to confirm you've subscribed, sends a test message
4. Creates 4 CloudWatch alarms tied to the topic:
   - `MyProject_HighCPU` — EC2 CPU > 80%
   - `MyProject_HighDBConnections` — RDS connections > 80
   - `MyProject_HighBookingErrors` — `mp_BookingErrors` > 5/min
   - `MyProject_NoBookingsActivity` — no bookings in 30 minutes (app health)

### Step 8: Test End-to-End

Open the ELB URL in your browser:
```
http://myproject-alb-xxx.us-east-1.elb.amazonaws.com/
```

You should see:
- Booking form with 6 service cards (images from S3)
- Footer alternating between `WebServer1` and `WebServer2` on refresh
- Submitting a booking → confirmation page → admin shows the new booking

### Step 9: Generate Metrics Data for Dashboard Screenshots

```bash
ssh -i MyProject_Key.pem ec2-user@<WS1_IP>
sudo bash /tmp/load_test.sh   # if uploaded earlier
# OR
scp -i MyProject_Key.pem scripts/load_test.sh ec2-user@<WS1_IP>:/tmp/
ssh -i MyProject_Key.pem ec2-user@<WS1_IP> 'sudo bash /tmp/load_test.sh'
```

This pushes ~70 events (`mp_BookingsCreated`, `mp_BookingErrors`, `mp_BookingValue`, `mp_RequestsHandled`, `mp_BookingLatency`) over 2 minutes.

Wait 2 minutes, then check **CloudWatch → Metrics → Custom namespaces → MyProject/Application**. All 5 metrics should have data points.

### Step 10: Trigger Test Alarm (for SNS email screenshot)

To prove the SNS email pipeline works for your D2 report:

```bash
# Force 6 booking errors quickly (threshold is >5/min)
for i in {1..6}; do
    aws cloudwatch put-metric-data \
        --namespace 'MyProject/Application' \
        --metric-name 'mp_BookingErrors' \
        --value 1 \
        --unit Count \
        --region us-east-1
    sleep 5
done
```

Within 1-2 minutes:
- `MyProject_HighBookingErrors` transitions to **ALARM** state
- Email arrives in your inbox

---

## Troubleshooting

### "Database Connection Failed"
- Custom DB Parameter Group not applied → see Step 2
- RDS still rebooting after parameter change → wait 5 min and retry

### Site shows placeholder "MyProject Cloud Application"
- `index.html` from CloudFormation UserData wasn't deleted → rerun `deploy.sh`
- DirectoryIndex priority wrong → `deploy.sh` step 3 sets this

### Images return 403
- S3 bucket policy missing → Step 5
- Block Public Access still on → uncheck in Permissions tab

### ELB Target Group shows Unhealthy
- Health check path is `/health` instead of `/health.php` → Step 6

### Custom metrics not appearing in CloudWatch
- Old code used background `&` execution that got killed → v4 uses synchronous push
- Apache user can't reach AWS CLI → `metrics.php` uses absolute paths
- Check `/var/log/app/metrics.log` on the EC2 — should see `OK push:` lines after each booking
- LabRole not attached → EC2 → Actions → Security → Modify IAM Role → LabRole

### No SNS email received
- Subscription not confirmed — check inbox for "AWS Notifications" subject; click "Confirm subscription"
- Spam folder — AWS emails sometimes land there
- Region mismatch — SNS topic and alarms must be in the same region (us-east-1)
- Verify in Console: SNS → Topics → MyProject_Alarms → Subscriptions → status must be "Confirmed", not "PendingConfirmation"

---

## D2 Report Screenshot Checklist

After all steps complete, capture these screenshots:

| # | Screenshot | Where to Find It |
|---|---|---|
| 1 | Booking app homepage with 6 service cards | ELB URL |
| 2 | Booking confirmation page | After submitting form |
| 3 | Admin dashboard with bookings table | `<ELB>/admin.php` |
| 4 | Footer showing WebServer1, then WebServer2 (refresh) | Index page |
| 5 | EC2 console — both instances Running across 2 AZs | EC2 → Instances |
| 6 | Target Group both Healthy | EC2 → Target Groups → MyProject-TG |
| 7 | RDS Multi-AZ = Yes | RDS → Databases → myproject-rds |
| 8 | S3 bucket with /services/ folder | S3 → bucket → services/ |
| 9 | Custom metrics namespace populated with `mp_*` | CloudWatch → Metrics → Custom → MyProject/Application |
| 10 | Graph of `mp_BookingsCreated` over time | CloudWatch → Metrics → click metric → graph |
| 11 | Graph of `mp_RequestsHandled` filtered by Server dimension | Shows both WebServer1 and WebServer2 |
| 12 | All 4 alarms in CloudWatch | CloudWatch → Alarms |
| 13 | `MyProject_HighBookingErrors` in ALARM state | After Step 10 |
| 14 | SNS email in your inbox | Your email client |
| 15 | SNS topic with confirmed subscription | SNS → Topics → MyProject_Alarms |

---


### Why metric names have `mp_` prefix

Document this in your report — it shows AWS knowledge:

> *"All custom metrics emitted by the application are prefixed with `mp_` (e.g. `mp_BookingsCreated`, `mp_BookingErrors`). This namespacing prevents collision with metrics from other groups sharing the AWS Academy environment, and makes it trivial to filter them in CloudWatch dashboard widgets. Note that CloudWatch does not support metric deletion via API — older un-prefixed test metrics from earlier development iterations remain visible in the full history view but are filtered out by searching for the prefix."*

### Why metrics push is synchronous

> *"The metrics helper pushes data points synchronously rather than via background processes. Asynchronous (`&`) execution adds ~0ms latency but Apache occasionally kills background processes when the request finishes — sometimes before AWS CLI completes the API call. We accepted the ~200ms latency cost in exchange for guaranteed metric delivery."*

### Why we use SNS for alerting

> *"CloudWatch Alarms are wired to an SNS topic (`MyProject_Alarms`) with email subscription. SNS provides durable, fan-out notification: the same alarm could trigger multiple endpoints (email, SMS, Lambda, webhook) without changing the alarm configuration. In production, the SNS topic would also have a Lambda subscriber forwarding to a paging system like PagerDuty for on-call rotation."*
