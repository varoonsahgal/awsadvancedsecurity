#!/usr/bin/env bash
# Lab 5.1 — the attacker comes back. Run this after each containment action
# to see which of the stolen credentials still work.
WORKDIR="${HOME}/skyfortress-d5-lab1"
export AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null AWS_DEFAULT_REGION=us-east-1
unset AWS_PROFILE AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_AUTHORIZATION_TOKEN

try() { if out=$("$@" 2>&1); then echo "   ✅ WORKS   → $out" | head -c 160; echo; else echo "   ⛔ DENIED  → $(echo "$out" | grep -o 'An error occurred ([A-Za-z]*)' | head -1)"; fi; }

echo "🐙 Long-term key (AKIA…) from the leaked .env:"
(
  set -a; source "${WORKDIR}/leaked/.env"; set +a; unset AWS_SESSION_TOKEN
  try aws sts get-caller-identity --query Arn --output text
  try aws s3api list-buckets --query 'length(Buckets)' --output text
)
echo "🐙 Stolen role session (ASIA…) from ~/.kraken/session.json:"
(
  export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "${HOME}/.kraken/session.json")
  export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "${HOME}/.kraken/session.json")
  export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "${HOME}/.kraken/session.json")
  try aws sts get-caller-identity --query Arn --output text
  try aws ssm get-parameter --name /nimbus/ops/sync-token --query Parameter.Name --output text
)
echo "(note: sts:GetCallerIdentity can never be denied by policy — watch the SECOND call in each block)"
