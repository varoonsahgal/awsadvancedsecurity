#!/usr/bin/env python3
"""
Operation Skyfortress - Lab 1.4 "Least-Privilege Robot".

Runs IAM Access Analyzer *custom policy checks* against policy files and fails the build
if a change would grant new access, grant a critical action, or make a resource public.

File naming convention (keeps the robot simple):
  *.identity.json  -> identity policy (attached to a role/user)
  *.bucket.json    -> S3 bucket policy (resource policy)

Checks performed:
  identity -> check-no-new-access    (vs reference/baseline-identity.json)
           -> check-access-not-granted (CRITICAL_ACTIONS)
  bucket   -> check-no-public-access  (resource type AWS::S3::Bucket)

Usage:
  python3 check_policies.py policies/              # every policy in a folder
  python3 check_policies.py policies/a.json b.json # specific files (e.g. the PR diff)

Each check costs a fraction of a cent (see Access Analyzer pricing). Needs
access-analyzer:CheckNoNewAccess, CheckAccessNotGranted, CheckNoPublicAccess.
"""
import json
import os
import pathlib
import sys

import boto3

HERE = pathlib.Path(__file__).resolve().parent
BASELINE = HERE / "reference" / "baseline-identity.json"

# Actions that should never appear in an application role without a human security review.
CRITICAL_ACTIONS = [
    "iam:PassRole",
    "iam:CreateAccessKey",
    "iam:PutRolePolicy",
    "iam:AttachRolePolicy",
    "s3:DeleteBucket",
    "s3:PutBucketPolicy",
    "kms:ScheduleKeyDeletion",
    "kms:PutKeyPolicy",
]

aa = boto3.client("accessanalyzer", region_name=os.environ.get("AWS_REGION", "us-east-1"))


def load(path: pathlib.Path) -> str:
    # Round-trip through json to fail fast on malformed files and normalise whitespace.
    return json.dumps(json.loads(path.read_text()))


def reasons(resp) -> str:
    out = []
    for r in resp.get("reasons", []):
        stmt = r.get("statementId") or f"statement #{r.get('statementIndex')}"
        out.append(f"{stmt}: {r.get('description', '').strip()}")
    return "; ".join(out) or resp.get("message", "")


def check_identity(doc: str, baseline: str):
    results = []
    r = aa.check_no_new_access(
        newPolicyDocument=doc, existingPolicyDocument=baseline, policyType="IDENTITY_POLICY"
    )
    results.append(("no-new-access", r["result"], reasons(r)))
    r = aa.check_access_not_granted(
        policyDocument=doc, access=[{"actions": CRITICAL_ACTIONS}], policyType="IDENTITY_POLICY"
    )
    results.append(("access-not-granted", r["result"], reasons(r)))
    return results


def check_bucket(doc: str):
    r = aa.check_no_public_access(policyDocument=doc, resourceType="AWS::S3::Bucket")
    return [("no-public-access", r["result"], reasons(r))]


def main(argv):
    targets = []
    for a in argv or [str(HERE / "policies")]:
        p = pathlib.Path(a)
        targets += sorted(p.glob("*.json")) if p.is_dir() else [p]

    baseline = load(BASELINE)
    rows, failed = [], []
    for path in targets:
        doc = load(path)
        if path.name.endswith(".identity.json"):
            checks = check_identity(doc, baseline)
        elif path.name.endswith(".bucket.json"):
            checks = check_bucket(doc)
        else:
            print(f"skip {path.name} (unknown policy kind)")
            continue
        verdict = "FAIL" if any(c[1] == "FAIL" for c in checks) else "PASS"
        if verdict == "FAIL":
            failed.append(path.name)
        for name, result, why in checks:
            rows.append((path.name, name, result, why))
            icon = "✅" if result == "PASS" else "❌"
            print(f"{icon} {path.name:<28} {name:<20} {result}  {why[:110]}")

    # Pretty summary for GitHub Actions ($GITHUB_STEP_SUMMARY shows on the run page).
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as fh:
            fh.write("## 🤖 Least-Privilege Robot\n\n| File | Check | Result | Why |\n|---|---|---|---|\n")
            for f, n, r, w in rows:
                fh.write(f"| `{f}` | {n} | {'✅' if r == 'PASS' else '❌'} {r} | {w.replace('|', '/')} |\n")

    print()
    if failed:
        print(f"🚫 Robot says NO: {len(failed)} policy file(s) failed -> {', '.join(failed)}")
        return 1
    print("🟢 Robot approves. Ship it.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
