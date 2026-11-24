#!/usr/bin/env bash
# Lab 2.1 · step 3 — configure GuardDuty for the whole org from the DELEGATED ADMIN account.
# Run with skyfortress-dev (security tooling) credentials, e.g.  AWS_PROFILE=sky-dev ./org-guardduty-config.sh
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"

DID=$(aws guardduty list-detectors --region "$REGION" --query 'DetectorIds[0]' --output text)
if [[ "$DID" == "None" || -z "$DID" ]]; then
  echo "==> No detector yet in the admin account — creating one"
  DID=$(aws guardduty create-detector --enable --region "$REGION" --query DetectorId --output text)
fi
echo "==> Admin detector: $DID"

# ALL = enable for existing AND future members. NEW = only accounts that join later.
cat > /tmp/gd-features.json <<'JSON'
[
  {"Name": "S3_DATA_EVENTS", "AutoEnable": "ALL"},
  {"Name": "EBS_MALWARE_PROTECTION", "AutoEnable": "ALL"},
  {"Name": "RUNTIME_MONITORING", "AutoEnable": "ALL",
   "AdditionalConfiguration": [
     {"Name": "EC2_AGENT_MANAGEMENT", "AutoEnable": "ALL"},
     {"Name": "ECS_FARGATE_AGENT_MANAGEMENT", "AutoEnable": "ALL"},
     {"Name": "EKS_ADDON_MANAGEMENT", "AutoEnable": "ALL"}
   ]}
]
JSON

aws guardduty update-organization-configuration --region "$REGION" \
  --detector-id "$DID" \
  --auto-enable-organization-members ALL \
  --features file:///tmp/gd-features.json

echo "==> Org configuration now:"
aws guardduty describe-organization-configuration --region "$REGION" --detector-id "$DID" \
  --query '{AutoEnable:AutoEnableOrganizationMembers,Features:Features[].{Name:Name,Auto:AutoEnable}}' --output json

echo "==> Member accounts (may take a few minutes to show 'Enabled'):"
aws guardduty list-members --region "$REGION" --detector-id "$DID" \
  --query 'Members[].{Account:AccountId,Status:RelationshipStatus}' --output table

cat <<'EOF'

NOTE: the management account is NOT auto-enrolled. Add it explicitly:
  aws guardduty create-members --detector-id <DID> \
      --account-details AccountId=<MGMT_ACCOUNT_ID>,Email=<mgmt-root-email>
EOF
