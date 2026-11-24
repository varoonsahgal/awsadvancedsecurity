#!/usr/bin/env python3
"""BOSS verifier — "The Kraken's Last Stand".

    python3 verify.py --profile sky-dev            # member-account checks use this profile
                                               # org/SCP checks use your default (management) creds
Every check must pass. No partial credit from the Kraken.
"""
import argparse, json, os, sys
import boto3
from botocore.exceptions import ClientError

p = argparse.ArgumentParser()
p.add_argument("--profile", default=None, help="profile for the skyfortress-dev member account")
p.add_argument("--region", default="us-east-1")
a = p.parse_args()

dev = boto3.Session(profile_name=a.profile, region_name=a.region)
mgmt = boto3.Session(region_name=a.region)
acct = dev.client("sts").get_caller_identity()["Account"]
iam, gd, ct = dev.client("iam"), dev.client("guardduty"), dev.client("cloudtrail")
results = []

def check(name, fn):
    try:
        ok, detail = fn()
    except Exception as e:  # noqa: BLE001
        ok, detail = False, f"{type(e).__name__}: {e}"
    results.append(ok)
    print(("  ✅ " if ok else "  ❌ ") + name + (f"  — {detail}" if detail else ""))

def stolen_session_dead():
    path = os.path.expanduser("~/.kraken/ci-session.json")
    c = json.load(open(path))["Credentials"]
    s = boto3.Session(aws_access_key_id=c["AccessKeyId"], aws_secret_access_key=c["SecretAccessKey"],
                      aws_session_token=c["SessionToken"], region_name=a.region)
    try:
        s.client("iam").list_roles(MaxItems=1)
        return False, "stolen CI session can STILL call IAM"
    except ClientError as e:
        code = e.response["Error"]["Code"]
        if code == "ExpiredToken":
            # Waiting out the clock is not containment. Prove you actually revoked it.
            try:
                names = iam.list_role_policies(RoleName="nimbus-ci-deployer")["PolicyNames"]
                docs = [json.dumps(iam.get_role_policy(RoleName="nimbus-ci-deployer", PolicyName=n)["PolicyDocument"]) for n in names]
                if not any("aws:TokenIssueTime" in d for d in docs):
                    return False, "session merely EXPIRED - no TokenIssueTime revocation on nimbus-ci-deployer"
            except ClientError as e2:
                if e2.response["Error"]["Code"] != "NoSuchEntity":
                    raise
        return code in ("AccessDenied", "ExpiredToken", "InvalidClientTokenId"), code

def gone(kind, name):
    def f():
        try:
            (iam.get_user(UserName=name) if kind == "user" else iam.get_role(RoleName=name))
            return False, f"{kind} {name} still exists"
        except ClientError as e:
            return e.response["Error"]["Code"] == "NoSuchEntity", ""
    return f

def detector_ok():
    det = gd.list_detectors()["DetectorIds"][0]
    status = gd.get_detector(DetectorId=det)["Status"]
    filters = gd.list_filters(DetectorId=det).get("FilterNames", [])
    bad = [f for f in filters if gd.get_filter(DetectorId=det, FilterName=f)["Action"] == "ARCHIVE"
           and f == "noise-reduction-ec2"]
    return status == "ENABLED" and not bad, f"status={status} suspicious_filters={bad}"

def trail_ok():
    st = ct.get_trail_status(Name="nimbus-dev-audit")
    return st["IsLogging"], f"IsLogging={st['IsLogging']}"

def scp_ok():
    org = mgmt.client("organizations")
    targets, node = [acct], acct
    while True:
        parents = org.list_parents(ChildId=node)["Parents"]
        if not parents:
            break
        node = parents[0]["Id"]
        targets.append(node)
        if parents[0]["Type"] == "ROOT":
            break
    need = {"guardduty:UpdateDetector", "guardduty:CreateFilter", "cloudtrail:StopLogging"}
    for t in targets:
        for pol in org.list_policies_for_target(TargetId=t, Filter="SERVICE_CONTROL_POLICY")["Policies"]:
            doc = json.loads(org.describe_policy(PolicyId=pol["Id"])["Policy"]["Content"])
            stmts = doc["Statement"] if isinstance(doc["Statement"], list) else [doc["Statement"]]
            denied = set()
            for s in stmts:
                if s.get("Effect") == "Deny":
                    acts = s.get("Action", [])
                    denied |= set([acts] if isinstance(acts, str) else acts)
            if need <= denied:
                return True, f"{pol['Name']} attached to {t}"
    return False, "no SCP denying " + ", ".join(sorted(need)) + " applies to this account"

print(f"\n\U0001F419  Verifying the Kraken's defeat in account {acct}\n")
check("Stolen CI session (gha-run-48151623) is useless", stolen_session_dead)
check("Backdoor user svc-telemetry removed", gone("user", "svc-telemetry"))
check("Backdoor role AWSSupportDiagnostics-Helper removed", gone("role", "AWSSupportDiagnostics-Helper"))
check("GuardDuty enabled, suppression rule removed", detector_ok)
check("Audit trail nimbus-dev-audit logging again", trail_ok)
check("Guardrail SCP protects detection + audit tooling", scp_ok)

if all(results):
    k = b"tentacle"
    blob = bytes.fromhex("272e370f150b093a1f170f1f040d331618000b04123c180a1a0c091c151e")
    print("\n\U0001F389  THE KRAKEN IS DEFEATED.  Flag: " + bytes(c ^ k[i % len(k)] for i, c in enumerate(blob)).decode())
    sys.exit(0)
print(f"\n\U0001F419  {results.count(False)} tentacle(s) still twitching. Keep going.")
sys.exit(1)
