#!/usr/bin/env python3
"""Lab 2.1 · Light the Beacons — prove your S3 data events actually work.

Run in CloudShell with skyfortress-PROD credentials:
    AWS_PROFILE=sky-prod python3 beacon-ping.py

It creates (if needed) the crown-jewels bucket, writes and reads a harmless object,
then knocks on a secret key that does not exist. Only a correctly configured
data-event selector will record that knock. Find it in the org trail to get the flag.
"""
import base64
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

_d = lambda s: base64.b64decode(s[::-1]).decode()
SECRET_KEY = "beacons/" + _d("==Qfz52bjFWZi9VZoR3X0h2Zpx2XzRnblZXZfFGdhR2eZt0U")

acct = boto3.client("sts").get_caller_identity()["Account"]
bucket = f"skyfortress-crown-jewels-{acct}"
s3 = boto3.client("s3", region_name="us-east-1", config=Config(user_agent_extra="Owlsley-Beacon/1.0"))

try:
    s3.head_bucket(Bucket=bucket)
except ClientError:
    print(f"creating {bucket}")
    s3.create_bucket(Bucket=bucket)
    s3.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration={k: True for k in
            ["BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets"]},
    )

s3.put_object(Bucket=bucket, Key="beacons/hello-from-owlsley.txt", Body=b"hoot hoot - data events are live\n")
s3.get_object(Bucket=bucket, Key="beacons/hello-from-owlsley.txt")["Body"].read()
print("PutObject + GetObject sent")

try:
    s3.get_object(Bucket=bucket, Key=SECRET_KEY)
except ClientError as e:
    print(f"secret beacon sent ({e.response['Error']['Code']} is expected)")

print(f"""
Beacons lit in s3://{bucket}
Org-trail delivery takes ~5-15 minutes. Then run (with MANAGEMENT creds):
    ./find-beacon.sh <org-trail-bucket> {acct}
""")
