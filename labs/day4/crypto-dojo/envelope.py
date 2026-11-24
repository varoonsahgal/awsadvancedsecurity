#!/usr/bin/env python3
"""
Crypto Dojo — envelope encryption by hand.

  python3 envelope.py encrypt  --key alias/skyfortress-dojo --in secret.txt --out secret.env.json \
          --ctx project=skyfortress --ctx vault=cargo-bay-7
  python3 envelope.py decrypt  --in secret.env.json --ctx project=skyfortress --ctx vault=cargo-bay-7

What happens:
  1. KMS GenerateDataKey returns a fresh 256-bit data key twice: plaintext + encrypted under your KMS key.
     The encryption context (EC) is cryptographically bound to the encrypted data key as AAD.
  2. We encrypt the payload locally with AES-256-GCM using the plaintext data key, and ALSO bind the EC
     as GCM associated data, so tampering with either the ciphertext or the context fails closed.
  3. We throw the plaintext data key away and store only {encrypted data key, nonce, ciphertext, ec}.
  4. Decrypt = KMS Decrypt(encrypted data key, EC) -> plaintext data key -> AES-GCM open.
     Wrong EC? KMS refuses with InvalidCiphertextException. That refusal is logged in CloudTrail.
"""
import argparse, base64, json, os, sys

import boto3
from botocore.exceptions import ClientError
from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def parse_ctx(pairs):
    ctx = {}
    for p in pairs or []:
        k, _, v = p.partition("=")
        if not k or not v:
            sys.exit(f"bad --ctx '{p}', expected key=value")
        ctx[k] = v
    return ctx


def aad(ctx):
    # Canonical, order-independent serialization of the context for AES-GCM AAD.
    return json.dumps(ctx, sort_keys=True, separators=(",", ":")).encode()


def encrypt(args, kms):
    ctx = parse_ctx(args.ctx)
    resp = kms.generate_data_key(KeyId=args.key, KeySpec="AES_256", EncryptionContext=ctx)
    data_key, wrapped = resp["Plaintext"], resp["CiphertextBlob"]
    nonce = os.urandom(12)
    with open(args.infile, "rb") as f:
        ct = AESGCM(data_key).encrypt(nonce, f.read(), aad(ctx))
    del data_key  # best effort: never persist the plaintext data key
    envelope = {
        "v": 1,
        "kms_key_id": resp["KeyId"],
        "wrapped_key": base64.b64encode(wrapped).decode(),
        "nonce": base64.b64encode(nonce).decode(),
        "ciphertext": base64.b64encode(ct).decode(),
        "ec_keys": sorted(ctx),  # store only the KEYS; the caller must supply the values
    }
    with open(args.outfile, "w") as f:
        json.dump(envelope, f, indent=2)
    print(f"sealed {args.infile} -> {args.outfile} under {resp['KeyId']}")
    print(f"encryption context keys: {sorted(ctx)}  (values are NOT stored — you must remember them)")


def decrypt(args, kms):
    ctx = parse_ctx(args.ctx)
    with open(args.infile) as f:
        env = json.load(f)
    try:
        resp = kms.decrypt(CiphertextBlob=base64.b64decode(env["wrapped_key"]), EncryptionContext=ctx)
    except ClientError as e:
        sys.exit(f"KMS said no: {e.response['Error']['Code']} — wrong key, wrong context, or no permission.")
    pt = AESGCM(resp["Plaintext"]).decrypt(base64.b64decode(env["nonce"]), base64.b64decode(env["ciphertext"]), aad(ctx))
    sys.stdout.write(pt.decode(errors="replace"))
    if not pt.endswith(b"\n"):
        print()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["encrypt", "decrypt"])
    ap.add_argument("--key", default="alias/skyfortress-dojo")
    ap.add_argument("--in", dest="infile", required=True)
    ap.add_argument("--out", dest="outfile", default="sealed.env.json")
    ap.add_argument("--ctx", action="append", help="encryption context pair key=value (repeatable)")
    ap.add_argument("--region", default=os.environ.get("AWS_REGION", "us-east-1"))
    args = ap.parse_args()
    kms = boto3.client("kms", region_name=args.region)
    encrypt(args, kms) if args.mode == "encrypt" else decrypt(args, kms)


if __name__ == "__main__":
    main()
