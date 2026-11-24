#!/usr/bin/env bash
# Creates a $25/month cost budget with 50/80/100% email alerts in the CURRENT account.
# Usage: ./budget.sh you@example.com [profile]
set -euo pipefail
EMAIL="${1:?usage: $0 email [profile]}"; PROFILE="${2:-}"
P=(); [[ -n "$PROFILE" ]] && P=(--profile "$PROFILE")
ACCT=$(aws sts get-caller-identity "${P[@]}" --query Account --output text)
NOTIFS=$(for t in 50 80 100; do printf '{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":%s,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"%s"}]},' "$t" "$EMAIL"; done)
aws budgets create-budget "${P[@]}" --account-id "$ACCT" \
  --budget '{"BudgetName":"skyfortress-25","BudgetLimit":{"Amount":"25","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
  --notifications-with-subscribers "[${NOTIFS%,}]"
echo "Budget skyfortress-25 created in $ACCT → alerts to $EMAIL"
