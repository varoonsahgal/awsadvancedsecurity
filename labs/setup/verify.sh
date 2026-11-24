#!/usr/bin/env bash
# Lab 0 verification. Prints your first flag when everything is in place.
set -uo pipefail
source ~/.skyfortress.env 2>/dev/null || true
ok=0; bad=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  ✅ $1"; ok=$((ok+1)); else echo "  ❌ $1"; bad=$((bad+1)); fi; }
echo "▶ Skyfortress pre-flight"
check "Organization with ALL features" "[[ \$(aws organizations describe-organization --query Organization.FeatureSet --output text) == ALL ]]"
check "SCP policy type enabled" "aws organizations list-roots --query \"Roots[0].PolicyTypes[?Type=='SERVICE_CONTROL_POLICY' && Status=='ENABLED']\" --output text | grep -q ENABLED"
check "RCP policy type enabled" "aws organizations list-roots --query \"Roots[0].PolicyTypes[?Type=='RESOURCE_CONTROL_POLICY' && Status=='ENABLED']\" --output text | grep -q ENABLED"
check "sky-mgmt profile works" "aws sts get-caller-identity --profile sky-mgmt"
check "Can assume into skyfortress-dev" "aws sts get-caller-identity --profile sky-dev"
check "Can assume into skyfortress-prod" "aws sts get-caller-identity --profile sky-prod"
check "Budget exists (management)" "aws budgets describe-budget --account-id \$(aws sts get-caller-identity --query Account --output text) --budget-name skyfortress-25"
check "terraform on PATH" "command -v terraform"
check "kubectl on PATH" "command -v kubectl"
check "jq on PATH" "command -v jq"
echo
if [[ $bad -eq 0 ]]; then
  echo "🎉 All $ok checks passed. Your fortress foundations are laid."
  echo "   Flag: $(echo 'U0tZe2ZvcnRyZXNzX2ZvdW5kYXRpb25zX2xhaWR9' | base64 -d)"
else
  echo "⚠️  $bad check(s) failed — see setup.html troubleshooting."
fi
