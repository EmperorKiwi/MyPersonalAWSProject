#!/bin/bash
# ==============================================================================
# Group 3 - Remote Deployment Orchestrator (v4)
# ==============================================================================
# Run from your LOCAL machine (Ubuntu/Mac with AWS CLI configured).
# Deploys the entire app to BOTH EC2 instances + uploads images to S3.
#
# Usage:
#   1. Edit the CONFIG section below
#   2. chmod +x remote_deploy.sh
#   3. ./remote_deploy.sh
# ==============================================================================

set -e

# ┌──────────────────────────────────────────────────────────────────────────┐
# │  EDIT THESE VALUES                                                        │
# └──────────────────────────────────────────────────────────────────────────┘

KEY_FILE="./MyProject_Key.pem"
WEBSERVER1_IP="X.X.X.X"
WEBSERVER2_IP="Y.Y.Y.Y"
RDS_ENDPOINT="myproject-rds.xxx.us-east-1.rds.amazonaws.com"
DB_PASSWORD="YourPasswordHere"
S3_BUCKET="myproject-static-178389051981"

# ┌──────────────────────────────────────────────────────────────────────────┐
# │  Don't edit below                                                         │
# └──────────────────────────────────────────────────────────────────────────┘

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}==>${NC} $1"; }
ok()  { echo -e "${GREEN}✓${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }

if [ ! -f "$KEY_FILE" ]; then
    err "Key file not found at $KEY_FILE"
    exit 1
fi

if [ ! -d "booking_app" ] || [ ! -f "scripts/deploy.sh" ]; then
    err "Run this from the MyProject_v4 folder"
    exit 1
fi

chmod 400 "$KEY_FILE" 2>/dev/null || true

deploy_to_server() {
    local IP=$1
    local NAME=$2

    log "Deploying to $NAME at $IP..."

    log "  Uploading booking_app/..."
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no -r booking_app ec2-user@$IP:/tmp/ > /dev/null

    log "  Uploading sql_scripts/..."
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no sql_scripts/*.sql ec2-user@$IP:/tmp/ > /dev/null

    log "  Uploading deploy.sh..."
    scp -i "$KEY_FILE" -o StrictHostKeyChecking=no scripts/deploy.sh ec2-user@$IP:/tmp/ > /dev/null

    log "  Running deploy on $NAME..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$IP \
        "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh '$RDS_ENDPOINT' '$DB_PASSWORD' '$S3_BUCKET' '$NAME'"

    ok "$NAME deployed"
    echo ""
}

upload_images_to_s3() {
    log "Uploading service images to S3..."
    if command -v aws &> /dev/null; then
        aws s3 cp booking_app/images/ "s3://${S3_BUCKET}/services/" --recursive
        ok "Images uploaded to s3://${S3_BUCKET}/services/"
    else
        err "AWS CLI not installed locally — upload images manually via S3 Console"
    fi
    echo ""
}

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Group 3 - Remote Deployment Orchestrator (v4)"
echo "════════════════════════════════════════════════════════════"
echo ""

upload_images_to_s3
deploy_to_server "$WEBSERVER1_IP" "WebServer1"
deploy_to_server "$WEBSERVER2_IP" "WebServer2"

echo "════════════════════════════════════════════════════════════"
ok "Both servers deployed!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Test direct:"
echo "    http://$WEBSERVER1_IP/  (footer: WebServer1)"
echo "    http://$WEBSERVER2_IP/  (footer: WebServer2)"
echo ""
echo "  Test via ELB (refresh to see footer alternate):"
echo "    Use ELB DNS from CloudFormation outputs"
echo ""
echo "  Next: run setup_sns.sh to wire up email alerts"
echo "    ./scripts/setup_sns.sh your.email@bcu.ac.uk"
echo ""
