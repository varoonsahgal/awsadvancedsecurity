#!/usr/bin/env bash
# Lab 3.3 - creates the Nimbus "citadel vault" bucket and plants the cargo manifest.
# Prints the bucket name only. Don't peek at the manifest - steal it like the Kraken would.
set -euo pipefail
ACCT=$(aws sts get-caller-identity --query Account --output text)
B="skyfortress-citadel-vault-$ACCT"
aws s3api create-bucket --bucket "$B" --region us-east-1 >/dev/null 2>&1 || true
aws s3api put-public-access-block --bucket "$B" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
{ echo "NIMBUS INTERSTELLAR - CITADEL VAULT - CLASSIFIED CARGO MANIFEST"; echo "route: LEO-7 -> Lagrange-2";
  echo "auth: $(echo 'fXNlbG9yX2RvcF90b25fZXJhX3NlbG9yX2Vkb257WUtTCg==' | base64 -d | rev)"; } \
  | aws s3 cp - "s3://$B/manifest.txt" --quiet
echo "$B"
