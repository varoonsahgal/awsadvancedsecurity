#!/usr/bin/env python3
"""BOSS FIGHT · The 3 A.M. Backdoor — the instructor (or you, eyes closed) runs this ONCE.

    AWS_PROFILE=sky-prod python3 boss-plant.py

It simulates a night-shift intrusion inside YOUR sandbox account:
  * a maintenance role is assumed under two different session names
  * one session does legitimate-looking platform work
  * the other plants a persistence mechanism and tests it
Safety net: every user created here is capped by a permissions boundary that only
allows sts:GetCallerIdentity and s3:ListAllMyBuckets. Real attackers won't be so kind.
Run boss-cleanup.sh when the fight is over.
"""
import base64
import json
import time

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

_d = lambda s: base64.b64decode(s[::-1]).decode()
iam = boto3.client("iam")
sts = boto3.client("sts")
acct = sts.get_caller_identity()["Account"]
ROLE = "nimbus-maintenance"
BOUNDARY = "skyfortress-boss-boundary"
boundary_arn = f"arn:aws:iam::{acct}:policy/{BOUNDARY}"

# ---------------------------------------------------------------- stage the stage
try:
    iam.create_policy(PolicyName=BOUNDARY, Description="Skyfortress boss-fight safety net", PolicyDocument=json.dumps({
        "Version": "2012-10-17",
        "Statement": [{"Effect": "Allow", "Action": ["sts:GetCallerIdentity", "s3:ListAllMyBuckets"], "Resource": "*"}]}))
except iam.exceptions.EntityAlreadyExistsException:
    pass
try:
    iam.create_role(RoleName=ROLE, Description="Nightly platform maintenance", AssumeRolePolicyDocument=json.dumps({
        "Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"AWS": f"arn:aws:iam::{acct}:root"},
                                                "Action": "sts:AssumeRole"}]}))
except iam.exceptions.EntityAlreadyExistsException:
    pass
iam.put_role_policy(RoleName=ROLE, PolicyName="maintenance", PolicyDocument=json.dumps({
    "Version": "2012-10-17",
    "Statement": [
        {"Effect": "Allow", "Action": "iam:CreateUser",
         "Resource": f"arn:aws:iam::{acct}:user/orbital-*",
         "Condition": {"StringEquals": {"iam:PermissionsBoundary": boundary_arn}}},
        {"Effect": "Allow", "Action": ["iam:TagUser", "iam:PutUserPolicy", "iam:AttachUserPolicy",
                                       "iam:CreateAccessKey", "iam:GetUser"],
         "Resource": f"arn:aws:iam::{acct}:user/orbital-*"},
        {"Effect": "Allow", "Action": ["iam:ListUsers", "ec2:DescribeInstances", "s3:ListAllMyBuckets"],
         "Resource": "*"}]}))
print("stage set. waiting for IAM to settle...")
time.sleep(12)


def as_session(name):
    for _ in range(10):
        try:
            c = sts.assume_role(RoleArn=f"arn:aws:iam::{acct}:role/{ROLE}", RoleSessionName=name)["Credentials"]
            return boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"],
                                 aws_session_token=c["SessionToken"])
        except ClientError:
            time.sleep(5)
    raise SystemExit("could not assume role; re-run in a minute")


# ---------------------------------------------------------------- the decoy: legit platform work
legit = as_session("platform_bootstrap").client("iam")
decoy = _d("yVGZhVmctknc0VWblxWZ01CbhRXaiJ3b")
try:
    legit.create_user(UserName=decoy, PermissionsBoundary=boundary_arn,
                      Tags=[{"Key": "owner", "Value": "platform-team"}, {"Key": "ticket", "Value": "PLAT-2231"}])
except legit.exceptions.EntityAlreadyExistsException:
    pass
legit.attach_user_policy(UserName=decoy, PolicyArn="arn:aws:iam::aws:policy/ReadOnlyAccess")
legit.list_users()

# ---------------------------------------------------------------- the backdoor
evil = as_session("maint_0300")
eiam = evil.client("iam")
user, pol = _d("jZ3ctknc0VWblxWZ01CbhRXaiJ3b"), _d("=knc0VWblxWZUlHbu9EZhVmU")
eiam.list_users()
try:
    eiam.create_user(UserName=user, PermissionsBoundary=boundary_arn,
                     Tags=[{"Key": "owner", "Value": "platform-team"}])  # blending in
except eiam.exceptions.EntityAlreadyExistsException:
    pass
eiam.put_user_policy(UserName=user, PolicyName=pol, PolicyDocument=json.dumps({
    "Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Action": "*", "Resource": "*"}]}))
key = eiam.create_access_key(UserName=user)["AccessKey"]
print("persistence planted. testing the implant...")
time.sleep(15)

implant = boto3.Session(aws_access_key_id=key["AccessKeyId"], aws_secret_access_key=key["SecretAccessKey"])
cfg = Config(user_agent="kraken-implant/3.0 (+https://example.invalid/abyss)")
for _ in range(10):
    try:
        implant.client("sts", config=cfg).get_caller_identity()
        implant.client("s3", config=cfg).list_buckets()
        break
    except ClientError:
        time.sleep(5)

print("""
🐙  The backdoor is in. The clock reads 03:00 somewhere.
Defenders: you get logs and nothing else. Who? What? When? How does it get in again?
""")
