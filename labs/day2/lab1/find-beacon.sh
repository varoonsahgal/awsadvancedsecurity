#!/usr/bin/env bash
# Lab 2.1 · pull today's org-trail logs for one account and show S3 DATA events.
# Run with MANAGEMENT-account credentials (the org trail bucket lives there).
#   ./find-beacon.sh <org-trail-bucket> <account-id> [region]
set -euo pipefail
B="${1:?usage: $0 <org-trail-bucket> <account-id> [region]}"
ACCT="${2:?account id required}"
REGION="${3:-us-east-1}"
ORG=$(aws organizations describe-organization --query Organization.Id --output text)
DAY=$(date -u +%Y/%m/%d)
DEST="./trail-logs/$ACCT/$DAY"
mkdir -p "$DEST"

echo "==> syncing s3://$B/AWSLogs/$ORG/$ACCT/CloudTrail/$REGION/$DAY/"
aws s3 sync "s3://$B/AWSLogs/$ORG/$ACCT/CloudTrail/$REGION/$DAY/" "$DEST" --quiet
COUNT=$(find "$DEST" -name '*.json.gz' | wc -l | tr -d ' ')
echo "==> $COUNT log files"
[[ "$COUNT" == "0" ]] && { echo "No files yet — CloudTrail delivers every ~5 min. Try again shortly."; exit 0; }

echo
printf 'eventTime\teventName\terrorCode\tkey\tuserAgent\n'
find "$DEST" -name '*.json.gz' -print0 | xargs -0 zcat | jq -r '
  .Records[]
  | select(.eventCategory == "Data" and .eventSource == "s3.amazonaws.com")
  | [.eventTime, .eventName, (.errorCode // "-"), (.requestParameters.key // "-"), .userAgent]
  | @tsv' | sort
