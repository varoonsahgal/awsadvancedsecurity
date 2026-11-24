#!/usr/bin/env bash
# Lab 5.1 "Burned Keys" — environment setup
# Creates a deliberately over-trusted CI user, a deploy role it can assume,
# a "loot" bucket with fake data, and an access key that gets "leaked".
# Run from CloudShell in the skyfortress-dev account (or any sandbox), us-east-1.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
ACCT=$(aws sts get-caller-identity --query Account --output text)
USER=nimbus-build-bot
ROLE=nimbus-deploy-role
BUCKET="skyfortress-d5-loot-${ACCT}"
WORKDIR="${HOME}/skyfortress-d5-lab1"
mkdir -p "${WORKDIR}/leaked"

echo "[*] Account ${ACCT} · region ${REGION}"

echo "[*] Creating loot bucket ${BUCKET}"
if [ "${REGION}" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "${BUCKET}" >/dev/null
else
  aws s3api create-bucket --bucket "${BUCKET}" --create-bucket-configuration LocationConstraint="${REGION}" >/dev/null
fi
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
printf 'employee_id,name,salary_credits\n1001,Ada Starfield,420000\n1002,Lin Comet,385000\n1003,Raj Nebula,401000\n' > "${WORKDIR}/payroll.csv"
aws s3 cp "${WORKDIR}/payroll.csv" "s3://${BUCKET}/finance/payroll-2026-q4.csv" >/dev/null

echo "[*] Creating IAM user ${USER}"
aws iam create-user --user-name "${USER}" --tags Key=owner,Value=platform-team Key=lab,Value=skyfortress-d5 >/dev/null
cat > "${WORKDIR}/user-policy.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    { "Sid": "Recon", "Effect": "Allow",
      "Action": ["sts:GetCallerIdentity", "s3:ListAllMyBuckets", "iam:ListRoles", "iam:ListUsers"],
      "Resource": "*" },
    { "Sid": "ReadLoot", "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject"],
      "Resource": ["arn:aws:s3:::${BUCKET}", "arn:aws:s3:::${BUCKET}/*"] },
    { "Sid": "AssumeDeploy", "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${ACCT}:role/${ROLE}" }
  ]
}
JSON
aws iam put-user-policy --user-name "${USER}" --policy-name build-bot-inline --policy-document "file://${WORKDIR}/user-policy.json"

echo "[*] Creating role ${ROLE}"
cat > "${WORKDIR}/trust.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "arn:aws:iam::${ACCT}:user/${USER}" },
    "Action": "sts:AssumeRole"
  }]
}
JSON
sleep 10   # IAM eventual consistency: the user must exist before it can be a principal
aws iam create-role --role-name "${ROLE}" --assume-role-policy-document "file://${WORKDIR}/trust.json" \
  --max-session-duration 43200 --tags Key=lab,Value=skyfortress-d5 >/dev/null
cat > "${WORKDIR}/role-policy.json" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["ssm:PutParameter", "ssm:GetParameter", "ssm:DescribeParameters", "ssm:AddTagsToResource",
                 "ec2:DescribeInstances", "ec2:DescribeRegions", "s3:ListAllMyBuckets", "sts:GetCallerIdentity"],
      "Resource": "*" }
  ]
}
JSON
aws iam put-role-policy --role-name "${ROLE}" --policy-name deploy-inline --policy-document "file://${WORKDIR}/role-policy.json"

echo "[*] Minting the access key that is about to have a very bad day"
aws iam create-access-key --user-name "${USER}" > "${WORKDIR}/key.json"
AK=$(jq -r .AccessKey.AccessKeyId "${WORKDIR}/key.json")
SK=$(jq -r .AccessKey.SecretAccessKey "${WORKDIR}/key.json")
rm -f "${WORKDIR}/key.json"

# Simulate the classic mistake: a .env file committed to a public repo.
cat > "${WORKDIR}/leaked/.env" <<ENV
# nimbus-build-bot — DO NOT COMMIT (narrator: it was committed)
AWS_ACCESS_KEY_ID=${AK}
AWS_SECRET_ACCESS_KEY=${SK}
AWS_DEFAULT_REGION=${REGION}
ENV
echo "${BUCKET}" > "${WORKDIR}/bucket.txt"

echo
echo "[+] Setup complete. Leaked credentials written to ${WORKDIR}/leaked/.env"
echo "[+] Leaked key id: ${AK}   (write this down — it's your first IOC)"
echo "[>] Wait ~15s for IAM to propagate, then run: ./attacker.sh"
