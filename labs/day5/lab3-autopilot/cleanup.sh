#!/usr/bin/env bash
# Lab 5.3 cleanup
set -uo pipefail
STACK=skyfortress-d5-autopilot
IID=$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='DecoyInstanceId'].OutputValue" --output text 2>/dev/null)
[ -n "$IID" ] && aws ec2 modify-instance-attribute --instance-id "$IID" --no-disable-api-termination 2>/dev/null
for s in $(aws ec2 describe-snapshots --owner-ids self --filters Name=tag:ir-evidence,Values=true --query 'Snapshots[].SnapshotId' --output text); do
  aws ec2 delete-snapshot --snapshot-id "$s" && echo "[-] $s"; done
aws ssm delete-parameter --name /skyfortress/d5/pending-approval 2>/dev/null
# Running executions keep waiting for a token — stop them so nothing lingers
SM=$(aws cloudformation describe-stacks --stack-name $STACK --query "Stacks[0].Outputs[?OutputKey=='StateMachineArn'].OutputValue" --output text 2>/dev/null)
for e in $(aws stepfunctions list-executions --state-machine-arn "$SM" --status-filter RUNNING --query 'executions[].executionArn' --output text 2>/dev/null); do
  aws stepfunctions stop-execution --execution-arn "$e" >/dev/null && echo "[-] stopped $e"; done
aws cloudformation delete-stack --stack-name $STACK
aws cloudformation wait stack-delete-complete --stack-name $STACK && echo "[+] stack deleted"
