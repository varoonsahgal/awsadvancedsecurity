"""Skyfortress tripwire detector — Lab 2.4 · Tripwires as Code.

EventBridge rules (patterns/*.json) do the cheap, coarse filtering.
This Lambda does the part patterns can't: inspect policy documents, compare
fields to each other, and decide whether a human must be woken up.

classify(event) -> rule id (str) or None
handler(event, ctx) -> publishes to SNS when classify() says so

Run the unit tests locally:   python3 test_detector.py
"""
import json
import os

RULES = {
    "ROOT_LOGIN": ("CRITICAL", "Root user console sign-in", "T1078.004"),
    "TRAIL_TAMPER": ("CRITICAL", "CloudTrail logging tampered with", "T1562.008"),
    "PUBLIC_BUCKET": ("HIGH", "S3 bucket made public", "T1530"),
    "KEY_FOR_OTHER_USER": ("HIGH", "Access key minted for another principal", "T1098.001"),
    "GD_HIGH": ("HIGH", "GuardDuty high-severity finding", "—"),
}

TRAIL_TAMPER_APIS = {"StopLogging", "DeleteTrail", "UpdateTrail", "PutEventSelectors", "PutInsightSelectors"}


def _is_public_statement(stmt):
    """TODO(student): return True when an Allow statement grants access to everyone
    with NO Condition block. Principal can be "*" or {"AWS": "*"} or {"AWS": ["*", ...]}."""
    return False  # <-- replace me


def _public_bucket(detail):
    """TODO(student): return True for
       * PutBucketPolicy whose requestParameters.bucketPolicy has any public statement
       * DeleteBucketPublicAccessBlock (always worth a look)"""
    return False  # <-- replace me


def _key_for_other_user(detail):
    """TODO(student): return True for CreateAccessKey / CreateLoginProfile / UpdateLoginProfile when the
    target user (requestParameters.userName) is NOT the caller. An IAM user creating a key for
    itself is normal; anything else (another user, or a role session doing it) is suspicious."""
    return False  # <-- replace me


def classify(event):
    dt = event.get("detail-type", "")
    src = event.get("source", "")
    d = event.get("detail", {}) or {}

    if dt == "AWS Console Sign In via CloudTrail" and d.get("userIdentity", {}).get("type") == "Root":
        return "ROOT_LOGIN"

    if dt == "GuardDuty Finding":
        return "GD_HIGH" if float(d.get("severity", 0)) >= 7 else None

    if dt != "AWS API Call via CloudTrail" or d.get("errorCode"):
        return None  # failed calls are for hunting, not paging

    if src == "aws.cloudtrail" and d.get("eventName") in TRAIL_TAMPER_APIS:
        return "TRAIL_TAMPER"
    if src == "aws.s3" and _public_bucket(d):
        return "PUBLIC_BUCKET"
    if src == "aws.iam" and _key_for_other_user(d):
        return "KEY_FOR_OTHER_USER"
    return None


def describe(rule, event):
    sev, title, attack = RULES[rule]
    d = event.get("detail", {}) or {}
    who = (d.get("userIdentity") or {}).get("arn", "n/a")
    return {
        "rule": rule, "severity": sev, "title": title, "attack": attack,
        "account": event.get("account"), "region": event.get("region"), "time": event.get("time"),
        "who": who, "what": d.get("eventName") or d.get("type"),
        "source_ip": d.get("sourceIPAddress"), "user_agent": d.get("userAgent"),
        "runbook": f"https://wiki.nimbus.example/runbooks/{rule.lower()}",
    }


def handler(event, _ctx):
    rule = classify(event)
    if not rule:
        return {"alert": False}
    alert = describe(rule, event)
    topic = os.environ.get("SNS_TOPIC_ARN")
    if topic:
        import boto3
        boto3.client("sns").publish(
            TopicArn=topic,
            Subject=f"[{alert['severity']}] {alert['title']}"[:100],
            Message=json.dumps(alert, indent=2),
        )
    print(json.dumps(alert))
    return {"alert": True, **alert}
