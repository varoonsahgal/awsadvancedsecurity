#!/usr/bin/env bash
# Lab 5.1 cleanup — removes everything setup.sh and attacker.sh created.
set -uo pipefail
WORKDIR="${HOME}/skyfortress-d5-lab1"
BUCKET=$(cat "${WORKDIR}/bucket.txt" 2>/dev/null || echo "")
USER=nimbus-build-bot; ROLE=nimbus-deploy-role

for k in $(aws iam list-access-keys --user-name $USER --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do
  aws iam delete-access-key --user-name $USER --access-key-id "$k"; done
for p in $(aws iam list-user-policies --user-name $USER --query PolicyNames --output text 2>/dev/null); do
  aws iam delete-user-policy --user-name $USER --policy-name "$p"; done
for p in $(aws iam list-attached-user-policies --user-name $USER --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do
  aws iam detach-user-policy --user-name $USER --policy-arn "$p"; done
aws iam delete-user --user-name $USER 2>/dev/null && echo "[-] user deleted"

for p in $(aws iam list-role-policies --role-name $ROLE --query PolicyNames --output text 2>/dev/null); do
  aws iam delete-role-policy --role-name $ROLE --policy-name "$p"; done
aws iam delete-role --role-name $ROLE 2>/dev/null && echo "[-] role deleted"

aws ssm delete-parameter --name /nimbus/ops/sync-token 2>/dev/null && echo "[-] parameter deleted"
[ -n "$BUCKET" ] && aws s3 rb "s3://${BUCKET}" --force >/dev/null 2>&1 && echo "[-] bucket deleted"
rm -rf "${WORKDIR}" "${HOME}/.kraken"
echo "[+] Lab 5.1 cleaned up."
