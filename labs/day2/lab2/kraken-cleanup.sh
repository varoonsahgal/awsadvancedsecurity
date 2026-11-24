#!/usr/bin/env bash
# Lab 2.2 cleanup — run with skyfortress-PROD credentials.
set -uo pipefail
export PATH="$HOME/bin:$PATH"
ACCT=$(aws sts get-caller-identity --query Account --output text)
B="nimbus-cargo-manifests-$ACCT"

echo "==> Stratus: cleaning up every technique it warmed up or detonated"
stratus cleanup --all || true

echo "==> Emptying and deleting s3://$B"
aws s3 rm "s3://$B" --recursive --quiet || true
aws s3api delete-bucket --bucket "$B" || true

echo "==> Status"
stratus status 2>/dev/null | grep -Ev 'COLD' || true
echo "Done. Archive the lab findings in GuardDuty (delegated admin) when you've finished your write-up."
