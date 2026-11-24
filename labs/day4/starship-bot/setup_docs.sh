#!/usr/bin/env bash
# Lab 4.3 — create the Nimbus knowledge-base bucket and upload the (clean) docs.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ACCT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="nimbus-kb-${ACCT}-$(openssl rand -hex 3)"
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3 cp docs/shipping-policy.md  "s3://$BUCKET/kb/shipping-policy.md"  >/dev/null
aws s3 cp docs/cargo-faq.md        "s3://$BUCKET/kb/cargo-faq.md"        >/dev/null
echo "$BUCKET" > .kb_bucket
echo "knowledge base ready: s3://$BUCKET/kb/"
echo "run:  export DOCS_BUCKET=$BUCKET"
