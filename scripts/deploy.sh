#!/bin/bash
# ==============================================================================
# Group 3 - Campus Resource Manager - All-in-One Deploy Script (v4)
# ==============================================================================
# Run this on each EC2 instance to deploy the application from scratch.
# Handles every fix we discovered during testing:
#   - PHP installation (php-mysqlnd for RDS connectivity)
#   - Apache welcome page removal
#   - DirectoryIndex priority (index.php first, not index.html)
#   - PHP timezone warning fix
#   - Database creation with utf8mb4_general_ci collation (fixes MySQL 8 charset)
#   - Schema and seed data load (idempotent)
#   - Metrics log directory and permissions
#   - .env file with all required variables
#   - PHP syntax verification
#   - End-to-end smoke tests
#
# Usage:
#   sudo ./deploy.sh <RDS_ENDPOINT> <DB_PASSWORD> <S3_BUCKET> <SERVER_ID>
#
# Example:
#   sudo ./deploy.sh myproject-rds.xxx.rds.amazonaws.com MyPass123 myproject-static-178389051981 WebServer1
# ==============================================================================

set -e

if [ "$#" -ne 4 ]; then
    echo "Usage: sudo ./deploy.sh <RDS_ENDPOINT> <DB_PASSWORD> <S3_BUCKET> <SERVER_ID>"
    echo "Example: sudo ./deploy.sh myproject-rds.xxx MyPass myproject-static-12345 WebServer1"
    exit 1
fi

RDS_ENDPOINT="$1"
DB_PASSWORD="$2"
S3_BUCKET="$3"
SERVER_ID="$4"
DB_USER="admin"
DB_NAME="myprojectdb"
AWS_REGION="${AWS_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Group 3 - Campus Resource Manager v4 — Deployment"
echo "════════════════════════════════════════════════════════════"
echo "  RDS:       $RDS_ENDPOINT"
echo "  S3:        $S3_BUCKET"
echo "  Server ID: $SERVER_ID"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Install packages ──────────────────────────────────────────────────
log "Step 1/9: Installing packages..."
dnf update -y > /dev/null 2>&1 || warn "Some package updates failed"
dnf remove -y php-mysql 2>/dev/null || true
dnf install -y httpd php php-cli php-mysqlnd php-mbstring php-json mariadb105 awscli unzip 2>&1 | tail -3
ok "Packages installed"

if php -m | grep -qi "mysqli"; then
    ok "mysqli loaded ($(php -r 'echo mysqli_get_client_info();'))"
else
    err "mysqli not loaded"
    exit 1
fi

# ── Step 2: PHP timezone fix (eliminates Apache log warnings) ─────────────────
log "Step 2/9: Setting PHP timezone..."
echo 'date.timezone = "UTC"' > /etc/php.d/01-timezone.ini
ok "Timezone set to UTC"

# ── Step 3: Apache configuration ─────────────────────────────────────────────
log "Step 3/9: Configuring Apache..."
systemctl enable httpd > /dev/null 2>&1
systemctl start httpd
rm -f /etc/httpd/conf.d/welcome.conf
echo "DirectoryIndex index.php index.html" > /etc/httpd/conf.d/dir.conf
ok "Apache running, DirectoryIndex prefers index.php"

# ── Step 4: Test RDS connectivity ─────────────────────────────────────────────
log "Step 4/9: Testing RDS connectivity..."
if ! timeout 10 mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" -e "SELECT VERSION();" > /tmp/mysql_test.log 2>&1; then
    err "Cannot connect to RDS"
    cat /tmp/mysql_test.log
    err "Verify: RDS endpoint correct, password correct, RDS SG allows 3306 from EC2 SG"
    exit 1
fi
MYSQL_VERSION=$(mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" -sN -e "SELECT VERSION();" 2>/dev/null)
ok "Connected to RDS — MySQL $MYSQL_VERSION"

# ── Step 5: Initialise database ───────────────────────────────────────────────
log "Step 5/9: Initialising database..."

if [ "$SERVER_ID" = "WebServer1" ]; then
    # Create DB with utf8mb4_general_ci (PHP-compatible)
    mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" << SQL_EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
ALTER DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
SQL_EOF
    ok "Database created/verified"

    # Apply schema
    if [ -f /tmp/schema.sql ]; then
        mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/schema.sql
        ok "Schema applied"
    elif [ -f /tmp/sql_scripts/schema.sql ]; then
        mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/sql_scripts/schema.sql
        ok "Schema applied"
    fi

    # Insert seed data only if empty
    SVC_COUNT=$(mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM services;" 2>/dev/null || echo "0")
    if [ "$SVC_COUNT" = "0" ]; then
        if [ -f /tmp/insert_data.sql ]; then
            mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/insert_data.sql
            ok "Seed data inserted"
        elif [ -f /tmp/sql_scripts/insert_data.sql ]; then
            mysql -h "$RDS_ENDPOINT" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < /tmp/sql_scripts/insert_data.sql
            ok "Seed data inserted"
        fi
    else
        ok "Tables already populated ($SVC_COUNT services)"
    fi
else
    log "  Skipping DB init (only WebServer1 handles this)"
fi

# ── Step 6: Deploy application files ──────────────────────────────────────────
log "Step 6/9: Deploying application files..."

APP_SOURCE=""
if [ -d /tmp/booking_app ]; then
    APP_SOURCE="/tmp/booking_app"
elif [ -d /tmp/MyProject_v4/booking_app ]; then
    APP_SOURCE="/tmp/MyProject_v4/booking_app"
else
    err "Cannot find booking_app/ folder in /tmp/"
    err "Upload it: scp -i key.pem -r booking_app ec2-user@<ip>:/tmp/"
    exit 1
fi

# Wipe old/placeholder files
rm -f /var/www/html/index.html
rm -f /var/www/html/*.php

# Copy fresh
cp -f "$APP_SOURCE"/*.php /var/www/html/
mkdir -p /var/www/html/images
if [ -d "$APP_SOURCE/images" ]; then
    cp -rf "$APP_SOURCE/images/"* /var/www/html/images/
fi
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
ok "Application files deployed"

# Verify PHP syntax
for f in /var/www/html/*.php; do
    if ! php -l "$f" > /dev/null 2>&1; then
        err "PHP syntax error in $f:"
        php -l "$f"
        exit 1
    fi
done
ok "All PHP files pass syntax check"

# ── Step 7: Create .env and metrics log ───────────────────────────────────────
log "Step 7/9: Writing .env and setting up metrics log..."

mkdir -p /var/www/app
cat > /var/www/app/.env << ENV_EOF
DB_HOST=$RDS_ENDPOINT
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
AWS_REGION=$AWS_REGION
S3_BUCKET=$S3_BUCKET
SERVER_ID=$SERVER_ID
ENV_EOF
chmod 640 /var/www/app/.env
chown apache:apache /var/www/app/.env

mkdir -p /var/log/app
touch /var/log/app/metrics.log
chown apache:apache /var/log/app/metrics.log
chmod 664 /var/log/app/metrics.log
ok ".env and metrics log ready"

# ── Step 8: Restart Apache ────────────────────────────────────────────────────
log "Step 8/9: Restarting Apache..."
systemctl restart httpd
sleep 2

if systemctl is-active --quiet httpd; then
    ok "Apache restarted"
else
    err "Apache failed to restart"
    exit 1
fi

# ── Step 9: Smoke tests ───────────────────────────────────────────────────────
log "Step 9/9: Running smoke tests..."

INDEX_OK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/index.php)
HEALTH_OK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health.php)
ADMIN_OK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/admin.php)

if [ "$INDEX_OK" = "200" ];  then ok "index.php  → HTTP $INDEX_OK";  else err "index.php  → HTTP $INDEX_OK"; fi
if [ "$HEALTH_OK" = "200" ]; then ok "health.php → HTTP $HEALTH_OK"; else err "health.php → HTTP $HEALTH_OK"; fi
if [ "$ADMIN_OK" = "200" ];  then ok "admin.php  → HTTP $ADMIN_OK";  else err "admin.php  → HTTP $ADMIN_OK"; fi

# Test metric push capability
log "Testing CloudWatch metric push..."
TEST_PUSH=$(sudo -u apache /usr/bin/aws cloudwatch put-metric-data \
    --namespace 'MyProject/Application' \
    --metric-name 'mp_DeploymentTest' \
    --value 1 \
    --unit Count \
    --region us-east-1 2>&1)

if [ $? -eq 0 ]; then
    ok "CloudWatch metrics: working (test metric mp_DeploymentTest pushed)"
else
    warn "CloudWatch metrics push failed: $TEST_PUSH"
    warn "Check that LabRole is attached to this EC2 instance"
fi

PUBLIC_DNS=$(curl -s --max-time 3 http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null || echo "<your-ec2-ip>")

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✓ Deployment complete!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Test URLs:"
echo "    Home:    http://$PUBLIC_DNS/"
echo "    Admin:   http://$PUBLIC_DNS/admin.php"
echo "    Health:  http://$PUBLIC_DNS/health.php"
echo ""
echo "  Logs:"
echo "    Apache errors: /var/log/httpd/error_log"
echo "    Metrics:       /var/log/app/metrics.log"
echo ""
echo "════════════════════════════════════════════════════════════"
