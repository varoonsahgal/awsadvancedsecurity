#!/usr/bin/env python3
"""Lab 2.3 · Hunt the Deep — seed realistic noise plus ONE malicious session.

    AWS_PROFILE=sky-prod python3 seed-hunt.py

Creates (in the current account):
  * role  nimbus-ops-hunt-role   (assumable by this account only, read-mostly)
  * three Secrets Manager secrets under prod/
Then assumes the role as six different sessions. Five are boring humans and robots.
One is not. Your job is to find it using ONLY logs.
"""
import base64
import json
import random
import time

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

_d = lambda s: base64.b64decode(s[::-1]).decode()
REGION = "us-east-1"
ROLE = "nimbus-ops-hunt-role"

sts = boto3.client("sts")
iam = boto3.client("iam")
sm = boto3.client("secretsmanager", region_name=REGION)
acct = sts.get_caller_identity()["Account"]

# ---------------------------------------------------------------- role
trust = {"Version": "2012-10-17", "Statement": [{"Effect": "Allow",
         "Principal": {"AWS": f"arn:aws:iam::{acct}:root"}, "Action": ["sts:AssumeRole", "sts:TagSession"]}]}
perms = {"Version": "2012-10-17", "Statement": [
    {"Effect": "Allow", "Action": ["ec2:Describe*", "s3:ListAllMyBuckets", "secretsmanager:ListSecrets",
                                   "sts:GetCallerIdentity"], "Resource": "*"},
    {"Effect": "Allow", "Action": "secretsmanager:GetSecretValue",
     "Resource": f"arn:aws:secretsmanager:{REGION}:{acct}:secret:prod/*"}]}
try:
    iam.create_role(RoleName=ROLE, AssumeRolePolicyDocument=json.dumps(trust),
                    Description="Skyfortress Lab 2.3 hunt role", MaxSessionDuration=3600,
                    Tags=[{"Key": "lab", "Value": "skyfortress-d2"}])
    print(f"created role {ROLE}")
except iam.exceptions.EntityAlreadyExistsException:
    print(f"role {ROLE} exists")
iam.put_role_policy(RoleName=ROLE, PolicyName="ops-read", PolicyDocument=json.dumps(perms))
role_arn = f"arn:aws:iam::{acct}:role/{ROLE}"

# ---------------------------------------------------------------- secrets
secrets = {
    "prod/payments/gateway-key": _d("==QfzV2bk9lbltWYyt2XlhGdfVmcvZWZi9VZt9VZ0FGdvJ3eZt0U"),
    "prod/cargo/route-planner-token": "SKY{decoy_wrong_secret_keep_hunting}",
    "prod/hr/payroll-api": "SKY{so_close_but_no_kraken}",
}
for name, value in secrets.items():
    try:
        sm.create_secret(Name=name, SecretString=value, Tags=[{"Key": "lab", "Value": "skyfortress-d2"}])
        print(f"created secret {name}")
    except sm.exceptions.ResourceExistsException:
        sm.put_secret_value(SecretId=name, SecretString=value)

# ---------------------------------------------------------------- sessions
def session(name, ua=None, retries=8):
    for i in range(retries):
        try:
            c = sts.assume_role(RoleArn=role_arn, RoleSessionName=name)["Credentials"]
            return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"],
                                 aws_session_token=c["SessionToken"]), Config(user_agent=ua) if ua else Config()
        except ClientError:
            time.sleep(5)  # IAM is eventually consistent
    raise SystemExit("could not assume role — wait 30s and re-run")

print("generating background noise...")
for who in ["alice-ops", "bob-ops", "ci-deployer", "cargo-dashboard", "sre-oncall"]:
    s, cfg = session(who)
    ec2 = s.client("ec2", region_name=REGION, config=cfg)
    for _ in range(random.randint(3, 6)):
        ec2.describe_instances()
        ec2.describe_vpcs()
    s.client("s3", config=cfg).list_buckets()
    if who == "ci-deployer":
        for _ in range(4):
            s.client("secretsmanager", region_name=REGION, config=cfg).get_secret_value(
                SecretId="prod/cargo/route-planner-token")
    time.sleep(1)

print("...and something else is moving in the deep.")
evil_name = _d("y9GdpRWdh91bnJXYj9FdmlGazRHanlmb")
s, cfg = session(evil_name, ua="Mozilla/5.0 (X11; Kali Linux x86_64) KrakenCollective/6.6.6")
s.client("sts", config=cfg).get_caller_identity()
smx = s.client("secretsmanager", region_name=REGION, config=cfg)
smx.list_secrets()
smx.get_secret_value(SecretId="prod/payments/gateway-key")
iamx = s.client("iam", config=cfg)
for op in (iamx.list_users, iamx.list_roles, iamx.get_account_authorization_details):
    try:
        op()
    except ClientError:
        pass  # AccessDenied is the point
for r in ["us-west-2", "eu-west-1", "ap-southeast-1", "sa-east-1"]:
    s.client("ec2", region_name=r, config=cfg).describe_instances()
s.client("s3", config=cfg).list_buckets()

print("""
Seeded. CloudTrail delivers to the org trail in ~5-15 minutes
(Security Lake adds a few more minutes of normalization).
Now: hunt. Do NOT read this script's decoding lines — that's cheating the Kraken.
""")
