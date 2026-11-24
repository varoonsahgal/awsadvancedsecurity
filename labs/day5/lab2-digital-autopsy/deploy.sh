#!/usr/bin/env bash
# Lab 5.2 — deploy the autopsy stack and export handy variables to ~/skyfortress-d5-lab2.env
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
STACK=skyfortress-d5-autopsy
PL=$(aws ec2 describe-managed-prefix-lists --region "$REGION" \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.s3" \
  --query 'PrefixLists[0].PrefixListId' --output text)
echo "[*] S3 prefix list: $PL"
aws cloudformation deploy --region "$REGION" --stack-name "$STACK" \
  --template-file "$(dirname "$0")/autopsy.yaml" \
  --parameter-overrides S3PrefixListId="$PL" \
  --capabilities CAPABILITY_IAM

out() { aws cloudformation describe-stacks --region "$REGION" --stack-name "$STACK" \
  --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
cat > "${HOME}/skyfortress-d5-lab2.env" <<ENV
export VICTIM=$(out VictimInstanceId)
export FORENSIC=$(out ForensicInstanceId)
export FLUSH_SG=$(out FlushSgId)
export ISOLATION_SG=$(out IsolationSgId)
export EVIDENCE_BUCKET=$(out EvidenceBucket)
export AZ=$(out AvailabilityZone)
export CASE=IR-2026-1204-007
ENV
cat "${HOME}/skyfortress-d5-lab2.env"
echo "[+] Run: source ~/skyfortress-d5-lab2.env   (then give user-data ~3 minutes to finish)"
