#!/usr/bin/env bash
# Run one Athena query from the CLI and print results as a table.
#   ./run-athena.sh "SELECT ..."                 (query string)
#   ./run-athena.sh -f hunt.sql                  (first statement in a file)
# Needs an S3 location for results: export ATHENA_OUT=s3://<bucket>/athena-results/
set -euo pipefail
OUT="${ATHENA_OUT:?export ATHENA_OUT=s3://<bucket>/athena-results/}"
if [[ "${1:-}" == "-f" ]]; then Q=$(awk 'BEGIN{RS=";"} NR==1' "$2"); else Q="$1"; fi

QID=$(aws athena start-query-execution --query-string "$Q" \
  --result-configuration "OutputLocation=$OUT" --query QueryExecutionId --output text)
while :; do
  S=$(aws athena get-query-execution --query-execution-id "$QID" --query 'QueryExecution.Status.State' --output text)
  [[ "$S" == "SUCCEEDED" || "$S" == "FAILED" || "$S" == "CANCELLED" ]] && break
  sleep 2
done
if [[ "$S" != "SUCCEEDED" ]]; then
  aws athena get-query-execution --query-execution-id "$QID" --query 'QueryExecution.Status.StateChangeReason' --output text
  exit 1
fi
SCANNED=$(aws athena get-query-execution --query-execution-id "$QID" --query 'QueryExecution.Statistics.DataScannedInBytes' --output text)
aws athena get-query-results --query-execution-id "$QID" \
  | jq -r '.ResultSet.Rows[] | [.Data[].VarCharValue // ""] | @tsv' | column -t -s $'\t'
echo "-- scanned ${SCANNED} bytes"
