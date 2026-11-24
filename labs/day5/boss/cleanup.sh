#!/usr/bin/env bash
# BOSS cleanup. Member-account resources use $DEV_PROFILE (default: dev).
# Detach/delete the SCP yourself from the management account if you created one:
#   aws organizations detach-policy --policy-id p-xxxx --target-id <dev-account-id>
#   aws organizations delete-policy --policy-id p-xxxx
set -uo pipefail
export AWS_PROFILE="${DEV_PROFILE:-dev}"
ACCT=$(aws sts get-caller-identity --query Account --output text)

for k in $(aws iam list-access-keys --user-name svc-telemetry --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
  aws iam delete-access-key --user-name svc-telemetry --access-key-id "$k"; done
aws iam detach-user-policy --user-name svc-telemetry --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null
aws iam delete-user --user-name svc-telemetry 2>/dev/null
aws iam detach-role-policy --role-name AWSSupportDiagnostics-Helper --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null
aws iam delete-role --role-name AWSSupportDiagnostics-Helper 2>/dev/null
for p in $(aws iam list-role-policies --role-name nimbus-ci-deployer --query PolicyNames --output text 2>/dev/null); do
  aws iam delete-role-policy --role-name nimbus-ci-deployer --policy-name "$p"; done
aws iam detach-role-policy --role-name nimbus-ci-deployer --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null
aws iam delete-role --role-name nimbus-ci-deployer 2>/dev/null && echo "[-] CI role deleted"

DET=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty delete-filter --detector-id "$DET" --filter-name noise-reduction-ec2 2>/dev/null
aws cloudtrail delete-trail --name nimbus-dev-audit 2>/dev/null && echo "[-] trail deleted"
aws s3 rb "s3://skyfortress-d5-boss-trail-${ACCT}" --force >/dev/null 2>&1 && echo "[-] trail bucket deleted"
rm -f ~/.kraken/ci-session.json ~/.kraken/boss-user.json
echo "[+] Boss arena cleaned. (GuardDuty left enabled — it's your friend.)"
