#!/usr/bin/env bash
# =============================================================================
#  teardown.sh — remove EVERYTHING the Kraken GameDay created (stack + the
#  things the replay and the teams added outside CloudFormation).
#    ./teardown.sh          (asks for confirmation)
#    KRAKEN_YES=1 ./teardown.sh
# =============================================================================
set -uo pipefail
STACK="${STACK:-kraken-gameday}"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
export AWS_DEFAULT_REGION="$REGION"
out() { aws cloudformation describe-stacks --stack-name "$STACK" --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text 2>/dev/null; }

CARGO=$(out CargoBucket); ARTIFACTS=$(out ArtifactsBucket); EVID=$(out EvidenceBucket)
IID=$(out InstanceId); VPC=$(out VpcId); CASE=$(out CaseId)
[[ -n "$CARGO" && "$CARGO" != "None" ]] || { echo "Stack $STACK not found in $REGION — nothing to do."; exit 0; }
echo "About to destroy stack '$STACK' in $(aws sts get-caller-identity --query Account --output text)/$REGION, its buckets (ALL versions) and Case=$CASE snapshots."
[[ "${KRAKEN_YES:-}" == "1" ]] || { read -r -p "Type DESTROY to continue: " a; [[ "$a" == "DESTROY" ]] || exit 1; }

empty_bucket() {
  local b="$1"; [[ -z "$b" || "$b" == "None" ]] && return
  echo "· emptying s3://$b (all versions)"
  aws s3api delete-bucket-policy --bucket "$b" 2>/dev/null || true
  while :; do
    local batch v dm
    v=$(aws s3api list-object-versions --bucket "$b" --max-items 500 --query 'Versions[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)
    dm=$(aws s3api list-object-versions --bucket "$b" --max-items 500 --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output json 2>/dev/null)
    batch=$(jq -n --argjson v "${v:-null}" --argjson d "${dm:-null}" '{Objects: (($v // []) + ($d // [])), Quiet: true}')
    [[ $(jq '.Objects | length' <<<"$batch") == 0 ]] && break
    aws s3api delete-objects --bucket "$b" --delete "$batch" >/dev/null
  done
}

echo "· removing access keys and non-CloudFormation policies from GameDay identities"
for u in ci-deployer svc-telemetry; do
  for k in $(aws iam list-access-keys --user-name "$u" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null); do aws iam delete-access-key --user-name "$u" --access-key-id "$k"; done
  for p in $(aws iam list-attached-user-policies --user-name "$u" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do aws iam detach-user-policy --user-name "$u" --policy-arn "$p"; done
  aws iam delete-login-profile --user-name "$u" 2>/dev/null || true
done
for r in nimbus-ci-deploy-role nimbus-telemetry-reader; do
  for p in $(aws iam list-role-policies --role-name "$r" --query 'PolicyNames[]' --output text 2>/dev/null); do
    case "$p" in ci-deploy-everything|read-cargo) ;; *) aws iam delete-role-policy --role-name "$r" --policy-name "$p";; esac
  done
  for p in $(aws iam list-attached-role-policies --role-name "$r" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null); do aws iam detach-role-policy --role-name "$r" --policy-arn "$p"; done
done

empty_bucket "$CARGO"; empty_bucket "$ARTIFACTS"; empty_bucket "$EVID"

echo "· terminating the dispatch instance"
aws ec2 terminate-instances --instance-ids "$IID" >/dev/null 2>&1 && aws ec2 wait instance-terminated --instance-ids "$IID"

echo "· deleting team-created security groups in $VPC"
for g in $(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text); do
  owner=$(aws ec2 describe-security-groups --group-ids "$g" --query "SecurityGroups[0].Tags[?Key=='aws:cloudformation:stack-name'].Value | [0]" --output text)
  [[ "$owner" == "$STACK" ]] || aws ec2 delete-security-group --group-id "$g" 2>/dev/null || true
done

echo "· deleting forensic snapshots tagged Case=$CASE"
for s in $(aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:Case,Values=$CASE" --query 'Snapshots[].SnapshotId' --output text); do aws ec2 delete-snapshot --snapshot-id "$s"; done

echo "· deleting CloudFormation stack $STACK"
aws cloudformation delete-stack --stack-name "$STACK"
aws cloudformation wait stack-delete-complete --stack-name "$STACK" && echo "✔ stack deleted" || {
  echo "✘ stack delete did not complete — check: aws cloudformation describe-stack-events --stack-name $STACK"; exit 1; }

rm -rf "$HOME/.kraken"
echo
echo "Left in place on purpose (review & delete if you want):"
echo "  - EventBridge rules / SNS topics your team created in Act IV"
echo "  - Any Organizations SCP/RCP you attached"
echo "  - CloudTrail/Security Lake data about the GameDay (it's evidence — and it's yours)"
echo "✔ The Kraken has been returned to the deep."
