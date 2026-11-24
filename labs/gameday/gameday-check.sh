#!/usr/bin/env bash
# =============================================================================
#  gameday-check.sh — Operation Skyfortress GameDay verifier
#
#  Verifies the *state* of your environment and, when a challenge is solved,
#  prints its flag. Usage:
#     ./gameday-check.sh contain      # Act II  · Cut the Tentacle
#     ./gameday-check.sh quarantine   # Act II  · Capture, then Quarantine
#     ./gameday-check.sh doors        # Act II  · Slam the Backdoors
#     ./gameday-check.sh restore      # Act III · Restore the Manifests
#     ./gameday-check.sh guardrail    # Act IV  · Never Again: SSE-C
#     ./gameday-check.sh detect       # Act IV  · Detect It Next Time
#     ./gameday-check.sh final        # Final   · The Root Cause
#     ./gameday-check.sh all          # status board (no flags)
#
#  Rules of engagement: reading or decoding this file's flag strings instead
#  of solving the challenge is a -500 point penalty. The Kraken respects style.
# =============================================================================
set -uo pipefail
STACK="${STACK:-kraken-gameday}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AWS_DEFAULT_REGION="$REGION"
G=$'\e[38;5;84m'; R=$'\e[38;5;204m'; Y=$'\e[38;5;221m'; Z=$'\e[0m'
pass() { printf '  %s✔%s %s\n' "$G" "$Z" "$*"; }
fail() { printf '  %s✘%s %s\n' "$R" "$Z" "$*"; OK=0; }
flag() { [[ $OK == 1 ]] && { printf '\n  %s🚩 %s%s\n\n' "$Y" "$(printf '%s' "$1" | base64 -d)" "$Z"; } || printf '\n  %sNot yet. Fix the ✘ items and run again.%s\n\n' "$R" "$Z"; }
out() { aws cloudformation describe-stacks --stack-name "$STACK" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
active_keys() { aws iam list-access-keys --user-name "$1" --query "length(AccessKeyMetadata[?Status=='Active'])" --output text 2>/dev/null || echo 0; }

CARGO=$(out CargoBucket); EVID=$(out EvidenceBucket); IID=$(out InstanceId); SG=$(out DispatchSecurityGroupId); CASE=$(out CaseId)
[[ -n "$CARGO" && "$CARGO" != "None" ]] || { echo "Stack $STACK not found in $REGION"; exit 1; }

check_contain() {
  echo "Act II · Cut the Tentacle"
  [[ $(active_keys ci-deployer) == 0 ]] && pass "ci-deployer has no active access keys" || fail "ci-deployer still has an ACTIVE access key"
  local found=0
  for p in $(aws iam list-role-policies --role-name nimbus-ci-deploy-role --query 'PolicyNames[]' --output text); do
    aws iam get-role-policy --role-name nimbus-ci-deploy-role --policy-name "$p" --output json | grep -q "aws:TokenIssueTime" && found=1
  done
  [[ $found == 1 ]] && pass "nimbus-ci-deploy-role sessions revoked (aws:TokenIssueTime deny present)" || fail "stolen CI-role session tokens are still valid — revoke active sessions"
}

check_quarantine() {
  echo "Act II · Capture, then Quarantine"
  local n; n=$(aws s3api list-objects-v2 --bucket "$EVID" --prefix "evidence/" --query 'KeyCount' --output text 2>/dev/null)
  [[ "${n:-0}" != "None" && "${n:-0}" -ge 1 ]] && pass "volatile evidence present in s3://$EVID/evidence/" || fail "no evidence captured (run the CaptureVolatile SSM document BEFORE isolating)"
  local sgs; sgs=$(aws ec2 describe-instances --instance-ids "$IID" --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text)
  local open=0
  for g in $sgs; do
    local i e
    i=$(aws ec2 describe-security-groups --group-ids "$g" --query 'length(SecurityGroups[0].IpPermissions)' --output text)
    e=$(aws ec2 describe-security-groups --group-ids "$g" --query 'length(SecurityGroups[0].IpPermissionsEgress)' --output text)
    [[ "$i" != 0 || "$e" != 0 ]] && open=1
  done
  [[ $open == 0 ]] && pass "instance is network-isolated (no ingress/egress rules on attached SGs)" || fail "instance still has ingress or egress rules on: $sgs"
  local vol snaps
  vol=$(aws ec2 describe-instances --instance-ids "$IID" --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' --output text)
  snaps=$(aws ec2 describe-snapshots --owner-ids self --filters "Name=volume-id,Values=$vol" "Name=tag:Case,Values=$CASE" --query 'length(Snapshots)' --output text)
  [[ "${snaps:-0}" -ge 1 ]] && pass "forensic snapshot of $vol tagged Case=$CASE" || fail "no EBS snapshot of $vol tagged Case=$CASE"
}

check_doors() {
  echo "Act II · Slam the Backdoors"
  [[ $(active_keys svc-telemetry) == 0 ]] && pass "svc-telemetry has no active keys" || fail "svc-telemetry still has an attacker-minted ACTIVE key"
  local bad
  bad=$(aws iam get-role --role-name nimbus-telemetry-reader --query 'Role.AssumeRolePolicyDocument' --output json \
        | jq '[.Statement[] | select((.Principal=="*") or (.Principal.AWS? == "*") or ((.Principal.AWS? // []) | tostring | test("\\*")))] | length')
  [[ "$bad" == 0 ]] && pass "nimbus-telemetry-reader trust policy no longer trusts Principal \"*\"" || fail "nimbus-telemetry-reader still trusts Principal \"*\""
  local world
  world=$(aws ec2 describe-security-groups --group-ids "$SG" --query "length(SecurityGroups[0].IpPermissions[?IpRanges[?CidrIp=='0.0.0.0/0']])" --output text)
  [[ "$world" == 0 ]] && pass "no 0.0.0.0/0 ingress on nimbus-dispatch-sg" || fail "nimbus-dispatch-sg still allows 0.0.0.0/0 inbound"
}

check_restore() {
  echo "Act III · Restore the Manifests"
  for f in "$DIR"/seed/manifests/*.json; do
    local k want got
    k="manifests/$(basename "$f")"; want=$(shasum -a 256 "$f" | cut -d' ' -f1)
    got=$(aws s3 cp "s3://$CARGO/$k" - 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
    [[ "$want" == "$got" ]] && pass "$k restored to its pre-incident content" || fail "$k is still locked/corrupt (current version ≠ original)"
  done
}

check_guardrail() {
  echo "Act IV · Never Again: SSE-C"
  local pol; pol=$(aws s3api get-bucket-policy --bucket "$CARGO" --query Policy --output text 2>/dev/null || echo "")
  local haspol=0; grep -q "x-amz-server-side-encryption-customer-algorithm" <<<"$pol" && grep -q '"Deny"' <<<"$pol" && haspol=1
  local tmp key err; tmp=$(mktemp); key=$(mktemp); openssl rand 32 > "$key"; echo "guardrail probe" > "$tmp"
  if aws s3 cp "$tmp" "s3://$CARGO/guardrail-probe.txt" --sse-c AES256 --sse-c-key "fileb://$key" --only-show-errors 2>"$tmp.err"; then
    aws s3 rm "s3://$CARGO/guardrail-probe.txt" --only-show-errors
    fail "an SSE-C write to the cargo bucket SUCCEEDED — the Kraken could do it again"
  else
    err=$(cat "$tmp.err")
    if [[ $haspol == 1 ]] || grep -q "AccessDenied" <<<"$err"; then pass "SSE-C write was denied by an explicit guardrail"; else
      fail "SSE-C write failed but not by your guardrail (${err:0:90}…). Add an explicit Deny anyway — belt AND braces."; fi
  fi
  rm -f "$tmp" "$tmp.err" "$key"
}

check_detect() {
  echo "Act IV · Detect It Next Time"
  local hit=0
  for r in $(aws events list-rules --query 'Rules[?State==`ENABLED`].Name' --output text); do
    local pat t
    pat=$(aws events describe-rule --name "$r" --query EventPattern --output text 2>/dev/null)
    if grep -Eq "UpdateAssumeRolePolicy|CreateAccessKey" <<<"$pat"; then
      t=$(aws events list-targets-by-rule --rule "$r" --query 'length(Targets)' --output text)
      [[ "$t" -ge 1 ]] && { hit=1; pass "rule '$r' detects IAM persistence and has $t target(s)"; }
    fi
  done
  [[ $hit == 1 ]] || fail "no ENABLED EventBridge rule with a target matches UpdateAssumeRolePolicy or CreateAccessKey"
}

case "${1:-all}" in
  contain)    OK=1; check_contain;    flag U0tZe3Nlc3Npb25zX3Jldm9rZWRfdGVudGFjbGVfY3V0fQ== ;;
  quarantine) OK=1; check_quarantine; flag U0tZe2NhcHR1cmVfdGhlbl9xdWFyYW50aW5lfQ== ;;
  doors)      OK=1; check_doors;      flag U0tZe2tleXNfcm90YXRlZF9kb29yc19jbG9zZWR9 ;;
  restore)    OK=1; check_restore;    flag U0tZe3ZlcnNpb25pbmdfc2F2ZXNfdGhlX2RheX0= ;;
  guardrail)  OK=1; check_guardrail;  flag U0tZe2Rlbnlfc3NlX2NfZm9yZXZlcn0= ;;
  detect)     OK=1; check_detect;     flag U0tZe2RldGVjdGlvbl9hc19jb2RlX2Z0d30= ;;
  final)
    OK=1; check_contain; check_quarantine; check_doors; check_restore; check_guardrail; check_detect
    if [[ $OK == 1 ]]; then
      echo; read -r -p "  Patient zero — which IAM principal's credentials gave the Kraken its first foothold? " pz
      read -r -p "  Initial access vector — (a) phishing (b) leaked access key in a CI build log (c) exposed EC2 SSH (d) malicious npm package? " iv
      pz=$(tr '[:upper:]' '[:lower:]' <<<"$pz" | tr -d ' '); iv=$(tr '[:upper:]' '[:lower:]' <<<"$iv" | tr -d ' ')
      [[ "$pz" == "ci-deployer" && "$iv" == "b" ]] || { fail "root cause not quite right — go back to CloudTrail: who called AssumeRole first?"; }
    fi
    flag U0tZe2xlYWtlZF9rZXlzX3Npbmtfc2hpcHN9 ;;
  all) OK=1; check_contain; check_quarantine; check_doors; check_restore; check_guardrail; check_detect
       [[ $OK == 1 ]] && echo "${G}All systems green. Run: ./gameday-check.sh final${Z}" || echo "${R}Work remains.${Z}" ;;
  *) sed -n '2,20p' "$0"; exit 1 ;;
esac
