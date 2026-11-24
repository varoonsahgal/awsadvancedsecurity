#!/usr/bin/env bash
# Lab 5.3 — the human in the loop.   ./approve.sh yes|no
# Reads the pending task token and resumes the paused execution.
set -euo pipefail
DECISION="${1:?usage: ./approve.sh yes|no}"
P=$(aws ssm get-parameter --name /skyfortress/d5/pending-approval --query Parameter.Value --output text)
TOKEN=$(echo "$P" | jq -r .taskToken); CASE=$(echo "$P" | jq -r .caseId)
ME=$(aws sts get-caller-identity --query Arn --output text)
APPROVED=$([ "$DECISION" = "yes" ] && echo true || echo false)
OUT=$(jq -cn --argjson a "$APPROVED" --arg who "$ME" '{approved:$a, approver:$who}')
aws stepfunctions send-task-success --task-token "$TOKEN" --task-output "$OUT"
aws ssm delete-parameter --name /skyfortress/d5/pending-approval
echo "[+] Case $CASE: decision '$DECISION' recorded by $ME"
