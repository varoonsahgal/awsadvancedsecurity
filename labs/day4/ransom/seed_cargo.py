#!/usr/bin/env python3
"""
Ransom in the Clouds — create Nimbus's cargo bucket and fill it with precious data.

  python3 seed_cargo.py                 # creates nimbus-cargo-<account>-<rand> in us-east-1
  python3 seed_cargo.py --no-lock       # same, but WITHOUT Object Lock (to feel the pain first)
  python3 seed_cargo.py --legacy-ssec   # simulate a pre-April-2026 bucket that still ALLOWS SSE-C

Since April 2026, S3 blocks SSE-C on new general purpose buckets by default
(BlockedEncryptionTypes = SSE-C). Buckets created before that, or explicitly re-enabled, still allow it.
--legacy-ssec sets BlockedEncryptionTypes to NONE so you can reproduce the real attack on a lab bucket.

The bucket has versioning on. With Object Lock (default), every object version is protected
for 1 day in GOVERNANCE mode — admins with s3:BypassGovernanceRetention can still clean up
after class, which is why we use GOVERNANCE here and not COMPLIANCE.
"""
import argparse, base64, os, secrets
import boto3

_ROSTER = "eWFzUVxPWFlDRURZdUhPS151WEtEWUVHVw=="


def _r(s):
    return bytes(b ^ 0x2A for b in base64.b64decode(s)).decode()


CARGO = {
    "manifests/route-77-jupiter.csv": "container,contents,mass_kg\nNX-0001,ion thrusters,1200\nNX-0002,coffee (critical),80\n",
    "manifests/route-12-titan.csv": "container,contents,mass_kg\nTX-0441,cryo pods,3100\nTX-0442,spare owls,12\n",
    "finance/q3-ledger.csv": "month,revenue_credits\nJul,4800000\nAug,5100000\nSep,5550000\n",
    "crew/crew-roster.txt": None,  # filled below
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-lock", action="store_true")
    ap.add_argument("--legacy-ssec", action="store_true",
                    help="allow SSE-C on this bucket (simulates a bucket created before the April 2026 default)")
    ap.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    a = ap.parse_args()
    acct = boto3.client("sts").get_caller_identity()["Account"]
    s3 = boto3.client("s3", region_name=a.region)
    name = f"nimbus-cargo-{acct}-{secrets.token_hex(3)}"
    kw = {"Bucket": name}
    if a.region != "us-east-1":
        kw["CreateBucketConfiguration"] = {"LocationConstraint": a.region}
    if not a.no_lock:
        kw["ObjectLockEnabledForBucket"] = True  # also turns on versioning
    s3.create_bucket(**kw)
    s3.put_bucket_versioning(Bucket=name, VersioningConfiguration={"Status": "Enabled"})
    s3.put_public_access_block(Bucket=name, PublicAccessBlockConfiguration={
        "BlockPublicAcls": True, "IgnorePublicAcls": True, "BlockPublicPolicy": True, "RestrictPublicBuckets": True})
    if not a.no_lock:
        s3.put_object_lock_configuration(Bucket=name, ObjectLockConfiguration={
            "ObjectLockEnabled": "Enabled",
            "Rule": {"DefaultRetention": {"Mode": "GOVERNANCE", "Days": 1}}})
    ssec = "BLOCKED (2026 platform default)"
    if a.legacy_ssec:
        try:
            s3.put_bucket_encryption(Bucket=name, ServerSideEncryptionConfiguration={"Rules": [{
                "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
                "BlockedEncryptionTypes": {"EncryptionType": ["NONE"]}}]})
            ssec = "ALLOWED (legacy simulation)"
        except Exception as e:  # older boto3 may not know BlockedEncryptionTypes
            ssec = f"UNKNOWN — could not unblock SSE-C ({type(e).__name__}); run: pip3 install --user -U boto3"
    CARGO["crew/crew-roster.txt"] = (
        "NIMBUS INTERSTELLAR — CREW ROSTER (CONFIDENTIAL)\n"
        "captain: R. Okonkwo\nfirst officer: L. Haversham\nsecurity: Owlsley (owl)\n"
        f"bridge recovery phrase: {_r(_ROSTER)}\n")
    for k, body in CARGO.items():
        s3.put_object(Bucket=name, Key=k, Body=body.encode(), ServerSideEncryption="AES256")
    with open(".cargo_bucket", "w") as f:
        f.write(name)
    print(f"bucket: {name}   object lock: {'GOVERNANCE 1 day' if not a.no_lock else 'OFF'}   SSE-C: {ssec}")
    print("saved bucket name to .cargo_bucket — export BUCKET=$(cat .cargo_bucket)")


if __name__ == "__main__":
    main()
