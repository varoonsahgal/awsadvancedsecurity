#!/usr/bin/env bash
# Operation Skyfortress — Lab 0: bootstrap a sandbox AWS Organization.
# Run in AWS CloudShell (us-east-1) as an admin of a FRESH, DEDICATED management account.
#   ./bootstrap-org.sh you@example.com
# Member-account emails use plus-addressing: you+sky-dev@example.com, you+sky-prod@example.com
set -euo pipefail

EMAIL="${1:?usage: $0 base-email@example.com}"
LOCAL="${EMAIL%@*}"; DOMAIN="${EMAIL#*@}"
REGION="${AWS_REGION:-us-east-1}"
OPTIONAL_ACCOUNTS="${OPTIONAL_ACCOUNTS:-false}"   # set true to also create security-tooling, log-archive, forensics

say() { printf '\n\033[1;36m▶ %s\033[0m\n' "$*"; }

say "Checking identity"
aws sts get-caller-identity --output table

say "Creating organization (ALL features) — ignored if it already exists"
aws organizations create-organization --feature-set ALL >/dev/null 2>&1 || echo "  (organization already exists)"
ROOT_ID=$(aws organizations list-roots --query 'Roots[0].Id' --output text)
echo "  root: $ROOT_ID"

say "Enabling policy types: SCP, RCP, declarative (EC2)"
for T in SERVICE_CONTROL_POLICY RESOURCE_CONTROL_POLICY DECLARATIVE_POLICY_EC2; do
  aws organizations enable-policy-type --root-id "$ROOT_ID" --policy-type "$T" >/dev/null 2>&1 \
    && echo "  enabled $T" || echo "  $T already enabled (or unavailable)"
done

ou() { # get-or-create OU under root
  local name="$1" id
  id=$(aws organizations list-organizational-units-for-parent --parent-id "$ROOT_ID" \
        --query "OrganizationalUnits[?Name=='$name'].Id | [0]" --output text)
  if [[ "$id" == "None" || -z "$id" ]]; then
    id=$(aws organizations create-organizational-unit --parent-id "$ROOT_ID" --name "$name" \
          --query 'OrganizationalUnit.Id' --output text)
  fi
  echo "$id"
}

say "Creating OUs"
OU_SEC=$(ou Security); OU_WL=$(ou Workloads); OU_SBX=$(ou Sandbox); OU_FOR=$(ou Forensics)
echo "  Security=$OU_SEC Workloads=$OU_WL Sandbox=$OU_SBX Forensics=$OU_FOR"

account() { # name ou-id email-suffix
  local name="$1" ou="$2" suffix="$3" existing req status acct
  existing=$(aws organizations list-accounts --query "Accounts[?Name=='$name'].Id | [0]" --output text)
  if [[ "$existing" != "None" && -n "$existing" ]]; then echo "  $name exists: $existing" >&2; echo "$existing"; return; fi
  req=$(aws organizations create-account --email "${LOCAL}+${suffix}@${DOMAIN}" --account-name "$name" \
          --query 'CreateAccountStatus.Id' --output text)
  echo "  creating $name ($req)…" >&2
  while :; do
    status=$(aws organizations describe-create-account-status --create-account-request-id "$req" \
              --query 'CreateAccountStatus.State' --output text)
    [[ "$status" == "SUCCEEDED" ]] && break
    [[ "$status" == "FAILED" ]] && { aws organizations describe-create-account-status --create-account-request-id "$req" >&2; exit 1; }
    sleep 10
  done
  acct=$(aws organizations describe-create-account-status --create-account-request-id "$req" \
          --query 'CreateAccountStatus.AccountId' --output text)
  aws organizations move-account --account-id "$acct" --source-parent-id "$ROOT_ID" --destination-parent-id "$ou"
  echo "$acct"
}

say "Creating member accounts (2–4 min each)"
DEV=$(account skyfortress-dev "$OU_SBX" sky-dev)
PROD=$(account skyfortress-prod "$OU_WL" sky-prod)
if [[ "$OPTIONAL_ACCOUNTS" == "true" ]]; then
  TOOL=$(account security-tooling "$OU_SEC" sky-sec)
  LOGS=$(account log-archive "$OU_SEC" sky-logs)
  FOR=$(account forensics "$OU_FOR" sky-forensics)
fi

say "Creating SkyfortressAdmin role in the management account (backs the sky-mgmt profile)"
MGMT=$(aws sts get-caller-identity --query Account --output text)
if ! aws iam get-role --role-name SkyfortressAdmin >/dev/null 2>&1; then
  aws iam create-role --role-name SkyfortressAdmin --max-session-duration 43200 \
    --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"AWS\":\"arn:aws:iam::${MGMT}:root\"},\"Action\":\"sts:AssumeRole\"}]}" \
    --tags Key=project,Value=skyfortress >/dev/null
  aws iam attach-role-policy --role-name SkyfortressAdmin --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
  echo "  created (IAM is eventually consistent: give it ~15s before using sky-mgmt)"
else
  echo "  already exists"
fi

say "Writing CloudShell profiles to ~/.aws/config"
mkdir -p ~/.aws
add_profile() {
  local p="$1" a="$2"
  if ! grep -q "^\[profile $p\]" ~/.aws/config 2>/dev/null; then
    cat >> ~/.aws/config <<CFG

[profile $p]
role_arn = arn:aws:iam::$a:role/OrganizationAccountAccessRole
credential_source = EcsContainer
region = $REGION
CFG
  fi
}
if ! grep -q "^\[profile sky-mgmt\]" ~/.aws/config 2>/dev/null; then
  cat >> ~/.aws/config <<CFG

[profile sky-mgmt]
role_arn = arn:aws:iam::$MGMT:role/SkyfortressAdmin
credential_source = EcsContainer
region = $REGION
CFG
fi
add_profile sky-dev "$DEV"
add_profile sky-prod "$PROD"
if [[ "$OPTIONAL_ACCOUNTS" == "true" ]]; then add_profile sky-sec "$TOOL"; add_profile sky-logs "$LOGS"; add_profile sky-forensics "$FOR"; fi

cat > ~/.skyfortress.env <<ENV
export SKY_ROOT_ID=$ROOT_ID
export SKY_OU_SECURITY=$OU_SEC
export SKY_OU_WORKLOADS=$OU_WL
export SKY_OU_SANDBOX=$OU_SBX
export SKY_OU_FORENSICS=$OU_FOR
export SKY_DEV=$DEV
export SKY_PROD=$PROD
export SKY_MGMT=$MGMT
export AWS_REGION=$REGION
ENV
grep -q skyfortress.env ~/.bashrc || echo 'source ~/.skyfortress.env' >> ~/.bashrc

say "Done. Run: source ~/.skyfortress.env && ./verify.sh"
