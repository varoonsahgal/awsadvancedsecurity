#!/usr/bin/env python3
"""
Crypto Dojo — the Kraken's dead drop.

Owlsley intercepted a Kraken courier and forced it to seal one secret with YOUR dojo key.
The courier used a random encryption context and then... forgot to tell anyone what it was.

This script writes vault.bin (a raw KMS ciphertext) and prints NOTHING about the context.
Your job: recover the context the honest way (hint: who writes down every KMS request?)
and decrypt vault.bin with `aws kms decrypt --encryption-context ...`.

No peeking at the bytes below — the Kraken won't be this polite.
"""
import base64, os, secrets, sys
import boto3

_SEALED = "eWFzUUlFRF5PUl51Q1l1XkJPdUFPU1c="
WORDS = ["nebula", "quasar", "pulsar", "comet", "aurora", "zenith", "orbit", "nova", "vector", "photon"]


def _r(s):
    return bytes(b ^ 0x2A for b in base64.b64decode(s))


def main():
    key = sys.argv[1] if len(sys.argv) > 1 else "alias/skyfortress-dojo"
    kms = boto3.client("kms", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    ctx = {
        "mission": "skyfortress",
        "vault": f"cargo-bay-{secrets.randbelow(900) + 100}",
        "courier": secrets.choice(WORDS),
    }
    blob = kms.encrypt(KeyId=key, Plaintext=_r(_SEALED), EncryptionContext=ctx)["CiphertextBlob"]
    with open("vault.bin", "wb") as f:
        f.write(blob)
    del ctx
    print("vault.bin written. The courier has forgotten the encryption context. Good luck, operator.")
    print("(CloudTrail event history can take ~5 minutes to show new events.)")


if __name__ == "__main__":
    main()
