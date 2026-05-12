#!/bin/bash
# ==============================================================================
# Group 3 - SNS Topic + Email Subscription + CloudWatch Alarms Setup
# ==============================================================================
# Run this from your LOCAL machine (Ubuntu/Mac with AWS CLI configured).
#
# This script:
#   1. Creates SNS topic "MyProject_Alarms" if it doesn't exist
#   2. Subscribes your email to the topic (you'll get a confirmation email)
#   3. Re-creates the four CloudWatch alarms pointing at mp_* metrics
#   4. Sends a test message via SNS so you confirm the pipeline works
#
# Usage:
#   chmod +x setup_sns.sh
#   ./setup_sns.sh <YOUR_EMAIL>
#
# Example:
#   ./setup_sns.sh student@bcu.ac.uk
# ==============================================================================

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./setup_sns.sh <YOUR_EMAIL>"
    echo "Example: ./setup_sns.sh student@bcu.ac.uk"
    exit 1
fi

EMAIL="$1"
REGION="${AWS_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}==>${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

if ! command -v aws &> /dev/null; then
    echo "AWS CLI not installed. Install with: sudo apt install -y awscli"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI not configured. Run: aws configure"
    echo "Get keys from AWS Academy → AWS Details → AWS CLI → Show"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TOPIC_NAME="MyProject_Alarms"
TOPIC_ARN="arn:aws:sns:${REGION}:${ACCOUNT_ID}:${TOPIC_NAME}"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Group 3 - SNS + CloudWatch Alarms Setup"
echo "════════════════════════════════════════════════════════════"
echo "  Email:     $EMAIL"
echo "  Region:    $REGION"
echo "  Account:   $ACCOUNT_ID"
echo "════════════════════════════════════════════════════════════"
echo ""

# ── Step 1: Create or verify SNS topic ────────────────────────────────────────
log "Step 1/4: Creating SNS topic..."

EXISTING=$(aws sns list-topics --region "$REGION" --query "Topics[?TopicArn=='$TOPIC_ARN'].TopicArn" --output text)

if [ -n "$EXISTING" ]; then
    ok "Topic already exists: $TOPIC_ARN"
else
    aws sns create-topic --name "$TOPIC_NAME" --region "$REGION" > /dev/null
    ok "Created topic: $TOPIC_ARN"
fi

# ── Step 2: Subscribe email ───────────────────────────────────────────────────
log "Step 2/4: Subscribing $EMAIL to topic..."

# Check if email is already subscribed (and confirmed)
EXISTING_SUB=$(aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" \
    --query "Subscriptions[?Endpoint=='$EMAIL'].SubscriptionArn" \
    --output text)

if [ -n "$EXISTING_SUB" ] && [ "$EXISTING_SUB" != "PendingConfirmation" ]; then
    ok "Email already subscribed and confirmed: $EXISTING_SUB"
elif [ "$EXISTING_SUB" = "PendingConfirmation" ]; then
    warn "Email subscription pending — check your inbox for the confirmation email!"
    warn "Click the 'Confirm subscription' link in that email"
else
    aws sns subscribe \
        --topic-arn "$TOPIC_ARN" \
        --protocol email \
        --notification-endpoint "$EMAIL" \
        --region "$REGION" > /dev/null
    ok "Subscription request sent to $EMAIL"
    warn "IMPORTANT: Check your inbox NOW for the AWS confirmation email"
    warn "Click 'Confirm subscription' before proceeding to step 3"
    echo ""
    read -p "Press Enter once you have confirmed the email subscription..."
fi

# ── Step 3: Send test message ─────────────────────────────────────────────────
log "Step 3/4: Sending test SNS message..."

aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --subject "MyProject SNS Test Notification" \
    --message "This is a test message from the MyProject deployment script. If you received this, your SNS pipeline is working correctly." \
    --region "$REGION" > /dev/null

ok "Test message sent — check your inbox"
echo ""

# ── Step 4: Create / update CloudWatch alarms ─────────────────────────────────
log "Step 4/4: Creating CloudWatch alarms with mp_* metric names..."

# Alarm 1: High CPU
aws cloudwatch put-metric-alarm \
    --alarm-name "MyProject_HighCPU" \
    --alarm-description "Average EC2 CPU > 80% for 5 minutes" \
    --namespace "AWS/EC2" \
    --metric-name "CPUUtilization" \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions "$TOPIC_ARN" \
    --ok-actions "$TOPIC_ARN" \
    --region "$REGION"
ok "MyProject_HighCPU"

# Alarm 2: High DB connections
aws cloudwatch put-metric-alarm \
    --alarm-name "MyProject_HighDBConnections" \
    --alarm-description "RDS connections > 80" \
    --namespace "AWS/RDS" \
    --metric-name "DatabaseConnections" \
    --statistic Average \
    --period 300 \
    --evaluation-periods 2 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold \
    --alarm-actions "$TOPIC_ARN" \
    --region "$REGION"
ok "MyProject_HighDBConnections"

# Alarm 3: High booking error rate (uses mp_BookingErrors custom metric)
aws cloudwatch put-metric-alarm \
    --alarm-name "MyProject_HighBookingErrors" \
    --alarm-description "App-level booking errors > 5/minute" \
    --namespace "MyProject/Application" \
    --metric-name "mp_BookingErrors" \
    --statistic Sum \
    --period 60 \
    --evaluation-periods 2 \
    --threshold 5 \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    --alarm-actions "$TOPIC_ARN" \
    --region "$REGION"
ok "MyProject_HighBookingErrors (uses mp_BookingErrors)"

# Alarm 4: No bookings in last 30 minutes (catches dead application)
aws cloudwatch put-metric-alarm \
    --alarm-name "MyProject_NoBookingsActivity" \
    --alarm-description "No mp_BookingsCreated events in 30 minutes — app may be dead" \
    --namespace "MyProject/Application" \
    --metric-name "mp_BookingsCreated" \
    --statistic Sum \
    --period 1800 \
    --evaluation-periods 1 \
    --threshold 0 \
    --comparison-operator LessThanOrEqualToThreshold \
    --treat-missing-data breaching \
    --alarm-actions "$TOPIC_ARN" \
    --region "$REGION"
ok "MyProject_NoBookingsActivity (app health watchdog)"

echo ""
echo "════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✓ SNS and Alarms Setup Complete${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Topic ARN: $TOPIC_ARN"
echo ""
echo "  Verify in AWS Console:"
echo "    SNS → Topics → MyProject_Alarms (subscription must be 'Confirmed')"
echo "    CloudWatch → Alarms → 4 alarms listed (MyProject_*)"
echo ""
echo "  To trigger a test alarm:"
echo "    Push 6 booking errors quickly to the metric:"
echo "    for i in {1..6}; do aws cloudwatch put-metric-data \\"
echo "      --namespace 'MyProject/Application' --metric-name mp_BookingErrors \\"
echo "      --value 1 --unit Count --region us-east-1; done"
echo ""
echo "  MyProject_HighBookingErrors will transition to ALARM within 1-2 minutes,"
echo "  and you'll receive an email."
echo ""
