#!/usr/bin/env bash
# Lab 5.3 — fire a realistic GuardDuty-shaped event at EventBridge.
#   ./fire.sh [instance-id] [severity]
# EventBridge reserves the "aws." source prefix, so lab events use source
# "skyfortress.test" — the rule matches both that AND aws.guardduty.
set -euo pipefail
STACK=skyfortress-d5-autopilot
IID="${1:-$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='DecoyInstanceId'].OutputValue" --output text)}"
SEV="${2:-8}"
ACCT=$(aws sts get-caller-identity --query Account --output text)
DETAIL=$(jq -cn --arg iid "$IID" --argjson sev "$SEV" --arg acct "$ACCT" '{
  schemaVersion: "2.0", accountId: $acct, region: "us-east-1",
  id: ("skyfortress-" + (now|tostring)), type: "Backdoor:EC2/C&CActivity.B!DNS",
  severity: $sev, title: "EC2 instance is querying a domain associated with a known C&C server",
  resource: { resourceType: "Instance", instanceDetails: { instanceId: $iid } },
  service: { action: { actionType: "DNS_REQUEST", dnsRequestAction: { domain: "beacon.kraken-collective.invalid" } },
             count: 1, archived: false }
}')
ENTRY=$(jq -cn --arg d "$DETAIL" '[{Source:"skyfortress.test", DetailType:"GuardDuty Finding", Detail:$d}]')
aws events put-events --entries "$ENTRY"
echo "[+] Event sent for $IID (severity $SEV). Watch: Step Functions console → skyfortress-ec2-compromise-playbook"
