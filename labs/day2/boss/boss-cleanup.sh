#!/usr/bin/env bash
# Boss-fight cleanup — run with skyfortress-PROD credentials.
set -uo pipefail
ACCT=$(aws sts get-caller-identity --query Account --output text)
for U in $(aws iam list-users --query "Users[?starts_with(UserName, 'orbital-telemetry')].UserName" --output text); do
  for K in $(aws iam list-access-keys --user-name "$U" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
    aws iam delete-access-key --user-name "$U" --access-key-id "$K"
  done
  for P in $(aws iam list-user-policies --user-name "$U" --query 'PolicyNames' --output text); do
    aws iam delete-user-policy --user-name "$U" --policy-name "$P"
  done
  for A in $(aws iam list-attached-user-policies --user-name "$U" --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-user-policy --user-name "$U" --policy-arn "$A"
  done
  aws iam delete-user-permissions-boundary --user-name "$U" 2>/dev/null
  aws iam delete-user --user-name "$U" && echo "deleted user $U"
done
aws iam delete-role-policy --role-name nimbus-maintenance --policy-name maintenance 2>/dev/null
aws iam delete-role --role-name nimbus-maintenance 2>/dev/null && echo "deleted role nimbus-maintenance"
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCT:policy/skyfortress-boss-boundary" 2>/dev/null && echo "deleted boundary policy"
