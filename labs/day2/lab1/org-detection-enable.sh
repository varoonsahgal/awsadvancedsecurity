#!/usr/bin/env bash
# Lab 2.1 · Light the Beacons — wire up org-wide detection.
# Run from CloudShell in us-east-1 with MANAGEMENT-account credentials.
#
#   ./org-detection-enable.sh <security-tooling-account-id>
#
# In a real org the security-tooling account is a dedicated "Audit"/"Security" account.
# In the Skyfortress sandbox, skyfortress-dev doubles as security tooling.
set -euo pipefail

SEC_ACCT="${1:?usage: $0 <security-tooling-account-id>}"
REGION="${AWS_REGION:-us-east-1}"

echo "==> Trusting security services at the Organizations level"
for sp in guardduty.amazonaws.com securityhub.amazonaws.com cloudtrail.amazonaws.com; do
  aws organizations enable-aws-service-access --service-principal "$sp"
  echo "    trusted: $sp"
done

echo "==> Delegating GuardDuty administration to $SEC_ACCT ($REGION)"
aws guardduty enable-organization-admin-account --admin-account-id "$SEC_ACCT" --region "$REGION" \
  || echo "    (already delegated? check: aws guardduty list-organization-admin-accounts)"

echo "==> Delegating Security Hub administration to $SEC_ACCT ($REGION)"
aws securityhub enable-organization-admin-account --admin-account-id "$SEC_ACCT" --region "$REGION" \
  || echo "    (already delegated? check: aws securityhub list-organization-admin-accounts)"

echo
echo "Delegated admins now:"
aws organizations list-delegated-administrators \
  --query 'DelegatedAdministrators[].{Id:Id,Name:Name}' --output table
aws organizations list-delegated-services-for-account --account-id "$SEC_ACCT" \
  --query 'DelegatedServices[].ServicePrincipal' --output table

cat <<EOF

Next: switch to the security-tooling account ($SEC_ACCT) and run
  ./org-guardduty-config.sh
EOF
