# Force CPU alarm
aws cloudwatch set-alarm-state \
    --alarm-name 'MyProject_HighCPU' \
    --state-value ALARM \
    --state-reason 'D2 test - high CPU simulation' \
    --region us-east-1

# Force booking errors alarm
aws cloudwatch set-alarm-state \
    --alarm-name 'MyProject_HighBookingErrors' \
    --state-value ALARM \
    --state-reason 'D2 test - error rate simulation' \
    --region us-east-1

# Force DB connections alarm
aws cloudwatch set-alarm-state \
    --alarm-name 'MyProject_HighDBConnections' \
    --state-value ALARM \
    --state-reason 'D2 test - DB load simulation' \
    --region us-east-1