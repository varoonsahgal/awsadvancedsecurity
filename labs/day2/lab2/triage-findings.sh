#!/usr/bin/env bash
# Lab 2.2 · list active GuardDuty findings, highest severity first.
# Run in the DELEGATED ADMIN account (sky-dev) to see every member account.
#   ./triage-findings.sh            # all active findings
#   ./triage-findings.sh AttackSequence   # only types containing this string
set -euo pipefail
FILTER="${1:-}"
REGION="${AWS_REGION:-us-east-1}"
DID=$(aws guardduty list-detectors --region "$REGION" --query 'DetectorIds[0]' --output text)

IDS=$(aws guardduty list-findings --region "$REGION" --detector-id "$DID" \
  --finding-criteria '{"Criterion":{"service.archived":{"Eq":["false"]}}}' \
  --sort-criteria AttributeName=severity,OrderBy=DESC \
  --max-results 50 --query 'FindingIds' --output text)

[[ -z "$IDS" ]] && { echo "No active findings yet. GuardDuty typically needs 5-20 min after activity."; exit 0; }

# shellcheck disable=SC2086
aws guardduty get-findings --region "$REGION" --detector-id "$DID" --finding-ids $IDS \
  | jq -r --arg f "$FILTER" '
      .Findings
      | map(select(.Type | contains($f)))
      | sort_by(-.Severity)[]
      | [ (.Severity|tostring), .Type, .AccountId, .Resource.ResourceType, .UpdatedAt, .Id ]
      | @tsv' \
  | column -t -s $'\t'
