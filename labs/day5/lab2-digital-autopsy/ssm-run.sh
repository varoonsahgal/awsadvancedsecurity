#!/usr/bin/env bash
# Run a shell command on an instance through SSM Run Command and print its output.
#   usage: ./ssm-run.sh <instance-id> '<command>' [timeout-seconds]
# Output is captured from the invocation (first 24,000 chars — SSM's inline limit).
set -euo pipefail
IID="$1"; CMD="$2"; TO="${3:-600}"
PARAMS=$(jq -cn --arg c "$CMD" --arg t "$TO" '{commands:[$c], executionTimeout:[$t]}')
CID=$(aws ssm send-command --instance-ids "$IID" --document-name AWS-RunShellScript \
  --comment "skyfortress IR ${CASE:-lab}" --parameters "$PARAMS" \
  --query Command.CommandId --output text)
echo "[*] command $CID on $IID — waiting…" >&2
aws ssm wait command-executed --command-id "$CID" --instance-id "$IID" 2>/dev/null || true
aws ssm get-command-invocation --command-id "$CID" --instance-id "$IID" \
  --query '[Status, StandardOutputContent, StandardErrorContent]' --output text
