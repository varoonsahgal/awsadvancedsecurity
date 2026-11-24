#!/usr/bin/env bash
# Lab 5.2 cleanup. Object Lock (GOVERNANCE) protects evidence for 1 day —
# deleting it early requires s3:BypassGovernanceRetention, which is exactly
# the point: in real life, nobody should hold that permission casually.
set -uo pipefail
source "${HOME}/skyfortress-d5-lab2.env" 2>/dev/null || true
REGION="${AWS_REGION:-us-east-1}"

echo "[*] Deleting evidence volumes + snapshots tagged ir-case=${CASE:-IR-2026-1204-007}"
for v in $(aws ec2 describe-volumes --filters "Name=tag:ir-case,Values=${CASE:-IR-2026-1204-007}" --query 'Volumes[].VolumeId' --output text); do
  aws ec2 detach-volume --volume-id "$v" --force >/dev/null 2>&1; aws ec2 wait volume-available --volume-ids "$v"
  aws ec2 delete-volume --volume-id "$v" && echo "  [-] $v"; done
for s in $(aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:ir-case,Values=${CASE:-IR-2026-1204-007}" --query 'Snapshots[].SnapshotId' --output text); do
  aws ec2 delete-snapshot --snapshot-id "$s" && echo "  [-] $s"; done

if [ -n "${VICTIM:-}" ]; then
  aws ec2 modify-instance-attribute --instance-id "$VICTIM" --no-disable-api-termination 2>/dev/null
fi

if [ -n "${EVIDENCE_BUCKET:-}" ]; then
  echo "[*] Emptying ${EVIDENCE_BUCKET} (bypassing governance retention)"
  aws s3api list-object-versions --bucket "$EVIDENCE_BUCKET" --output json \
    --query '{Objects: [Versions[], DeleteMarkers[]][] | [].{Key:Key,VersionId:VersionId}}' > /tmp/d5-del.json
  if [ "$(jq '.Objects | length' /tmp/d5-del.json)" -gt 0 ]; then
    aws s3api delete-objects --bucket "$EVIDENCE_BUCKET" --delete file:///tmp/d5-del.json --bypass-governance-retention >/dev/null
  fi
fi
aws cloudformation delete-stack --stack-name skyfortress-d5-autopsy --region "$REGION"
aws cloudformation wait stack-delete-complete --stack-name skyfortress-d5-autopsy --region "$REGION" && echo "[+] stack deleted"
rm -f "${HOME}/skyfortress-d5-lab2.env"
