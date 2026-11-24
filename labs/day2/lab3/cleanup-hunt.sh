#!/usr/bin/env bash
# Lab 2.3 cleanup — run with skyfortress-PROD credentials.
set -uo pipefail
aws iam delete-role-policy --role-name nimbus-ops-hunt-role --policy-name ops-read
aws iam delete-role --role-name nimbus-ops-hunt-role
for s in prod/payments/gateway-key prod/cargo/route-planner-token prod/hr/payroll-api; do
  aws secretsmanager delete-secret --secret-id "$s" --force-delete-without-recovery --region us-east-1 >/dev/null && echo "deleted $s"
done
