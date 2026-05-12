#!/bin/bash
# ==============================================================================
# Group 3 - Metrics Load Test (mp_ prefix) - FIXED
# ==============================================================================
# Generates ~70 mixed metrics with the mp_ prefix to populate the dashboard
# for D2 report screenshots.
#
# Usage on either EC2:
#   sudo ./load_test.sh
# ==============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "════════════════════════════════════════════════════════════"
echo "  Group 3 - Metrics Load Test (mp_ prefix)"
echo "════════════════════════════════════════════════════════════"
echo ""

# ─── Determine SERVER_ID with multiple fallbacks ──────────────────────────────
SERVER_ID=""

# Try .env file
if [ -f /var/www/app/.env ]; then
    SERVER_ID=$(grep "^SERVER_ID=" /var/www/app/.env 2>/dev/null | cut -d= -f2 | tr -d '\r\n ' || echo "")
fi

# Fallback: try EC2 metadata public hostname (token-based IMDSv2)
if [ -z "$SERVER_ID" ]; then
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
            http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "")
        if [ -n "$INSTANCE_ID" ]; then
            SERVER_ID="EC2-${INSTANCE_ID:0:8}"
        fi
    fi
fi

# Final fallback
if [ -z "$SERVER_ID" ]; then
    SERVER_ID="LoadTestRunner"
    echo -e "${YELLOW}⚠ SERVER_ID not found — using fallback: $SERVER_ID${NC}"
fi

echo "Using SERVER_ID: $SERVER_ID"
echo ""

# ─── 30 successful bookings ──────────────────────────────────────────────────
echo "Pushing 30 successful bookings (mp_BookingsCreated)..."
for i in {1..30}; do
    aws cloudwatch put-metric-data \
        --namespace 'MyProject/Application' \
        --metric-name 'mp_BookingsCreated' \
        --value 1 \
        --unit Count \
        --region us-east-1 2>&1 | grep -v "^$" || true
    
    if [ $((i % 5)) -eq 0 ]; then
        aws cloudwatch put-metric-data \
            --namespace 'MyProject/Application' \
            --metric-name 'mp_BookingValue' \
            --value $((RANDOM % 50 + 10)) \
            --unit Count \
            --region us-east-1 2>&1 | grep -v "^$" || true
    fi
    sleep 1
done
echo -e "${GREEN}✓${NC} Bookings sent"
echo ""

# ─── 5 booking errors ─────────────────────────────────────────────────────────
echo "Pushing 5 booking errors (mp_BookingErrors)..."
for i in {1..5}; do
    aws cloudwatch put-metric-data \
        --namespace 'MyProject/Application' \
        --metric-name 'mp_BookingErrors' \
        --value 1 \
        --unit Count \
        --region us-east-1 2>&1 | grep -v "^$" || true
    sleep 2
done
echo -e "${GREEN}✓${NC} Errors sent"
echo ""

# ─── Server-tagged requests ──────────────────────────────────────────────────
echo "Pushing 20 server-tagged requests (mp_RequestsHandled, Server=$SERVER_ID)..."
for i in {1..20}; do
    aws cloudwatch put-metric-data \
        --namespace 'MyProject/Application' \
        --metric-name 'mp_RequestsHandled' \
        --value 1 \
        --unit Count \
        --dimensions "Server=$SERVER_ID" \
        --region us-east-1 2>&1 | grep -v "^$" || true
    sleep 1
done
echo -e "${GREEN}✓${NC} Server-tagged requests sent"
echo ""

# ─── Latency simulation ──────────────────────────────────────────────────────
echo "Pushing 15 latency measurements (mp_BookingLatency)..."
for i in {1..15}; do
    LATENCY=$((RANDOM % 200 + 50))
    aws cloudwatch put-metric-data \
        --namespace 'MyProject/Application' \
        --metric-name 'mp_BookingLatency' \
        --value $LATENCY \
        --unit Milliseconds \
        --region us-east-1 2>&1 | grep -v "^$" || true
    sleep 1
done
echo -e "${GREEN}✓${NC} Latency samples sent"
echo ""

echo "════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Load test complete!${NC}"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "  Wait 1-2 minutes, then check CloudWatch:"
echo "    Custom namespaces → MyProject/Application →"
echo "      • mp_BookingsCreated  (~30 events)"
echo "      • mp_BookingErrors    (~5 events)"
echo "      • mp_BookingValue     (~6 events)"
echo "      • mp_RequestsHandled  (~20 events with Server=$SERVER_ID)"
echo "      • mp_BookingLatency   (~15 samples in ms)"
echo ""
