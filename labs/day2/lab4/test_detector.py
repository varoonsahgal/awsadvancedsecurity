#!/usr/bin/env python3
"""Unit tests for detector.classify(). Every false positive you ever see should become a file in tests/events/.

    python3 test_detector.py

When every test passes, the tripwire hands you a flag.
"""
import glob
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from detector import classify  # noqa: E402

EXPECTED = {
    "01-root-login.json": "ROOT_LOGIN",
    "02-stop-logging.json": "TRAIL_TAMPER",
    "03-public-policy.json": "PUBLIC_BUCKET",
    "04-org-scoped-policy.json": None,        # Principal "*" but locked to our org -> not public
    "05-createkey-other-user.json": "KEY_FOR_OTHER_USER",
    "06-createkey-self.json": None,           # a user rotating its own key is normal
    "07-guardduty-high.json": "GD_HIGH",
    "08-guardduty-low.json": None,            # severity 2 -> dashboard, not pager
}
CIPHER = "309ceb79249c57b2b548e5b61636b5e506a98b748b72c10d6b91"

here = os.path.dirname(os.path.abspath(__file__))
results, failures = [], 0
for path in sorted(glob.glob(os.path.join(here, "tests", "events", "*.json"))):
    name = os.path.basename(path)
    got = classify(json.load(open(path)))
    want = EXPECTED.get(name, "??")
    ok = got == want
    failures += not ok
    results.append(got)
    print(f"{'PASS' if ok else 'FAIL'}  {name:32s} got={str(got):20s} want={want}")

print()
if failures:
    print(f"{failures} test(s) failing. The Kraken thanks you for the blind spot. 🐙")
    sys.exit(1)

key = hashlib.sha256("|".join(str(r) for r in results).encode()).digest()
flag = bytes(a ^ b for a, b in zip(bytes.fromhex(CIPHER), key)).decode()
print(f"All tripwires armed. 🦉  Flag: {flag}")
