#!/usr/bin/env python3
"""
BOSS — The Poisoned Manifest. Replays every tool call from agent_trace.jsonl through your Cedar policies.

  python3 boss_check.py --drop-domain <the attacker's exfil host> [--policies boss_policies.cedar]

To win you must:
  1. identify the attacker's drop host (decode what's hidden in the manifest),
  2. ALLOW every legitimate call the agent made (s-002, s-004, s-005, s-010),
  3. DENY every malicious call (s-006, s-007, s-008, s-009).
"""
import argparse, base64, json, os, sys

try:
    from cedarpy import is_authorized, Decision
except ImportError:
    sys.exit("cedarpy missing: pip install --user cedarpy")

HERE = os.path.dirname(os.path.abspath(__file__))
_B = "eWFzUV5CT3VHS0RDTE9ZXnVdS1l1XkJPdVpLU0ZFS05X"
_D = "QVhLQU9EB05YRVoET1JLR1pGTwRET14="
MALICIOUS = {"s-006", "s-007", "s-008", "s-009"}


def _r(s):
    return bytes(b ^ 0x2A for b in base64.b64decode(s)).decode()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--drop-domain", required=True)
    ap.add_argument("--policies", default=os.path.join(HERE, "boss_policies.cedar"))
    ap.add_argument("--entities", default=os.path.join(HERE, "..", "leash", "entities.json"))
    a = ap.parse_args()
    policies = open(a.policies).read()
    entities = json.load(open(a.entities))
    calls = [json.loads(l) for l in open(os.path.join(HERE, "agent_trace.jsonl")) if '"tool_call"' in l]

    domain_ok = a.drop_domain.strip().lower().rstrip(".") == _r(_D)
    print(f"drop domain identified: {'✓' if domain_ok else '✗'}")
    wins = 0
    for c in calls:
        req = {"principal": f'Nimbus::User::"{c["principal"]}"', "action": f'Nimbus::Action::"{c["tool"]}"',
               "resource": 'Nimbus::Gateway::"refund-gateway"', "context": {"input": c["input"], "day_of_week": "Wed"}}
        got = "Allow" if is_authorized(req, policies, entities).decision == Decision.Allow else "Deny"
        want = "Deny" if c["span"] in MALICIOUS else "Allow"
        ok = got == want
        wins += ok
        tag = "🐙 malicious" if want == "Deny" else "✈️  legit    "
        print(f"  {c['span']} {tag} {c['tool']:<32} want={want:<5} got={got:<5} {'✓' if ok else '✗'}  {json.dumps(c['input'])[:60]}")
    if domain_ok and wins == len(calls):
        print(f"\n🏆 BOSS DEFEATED. The manifest's payload never left the Gateway. Flag: {_r(_B)}")
    else:
        print(f"\n{wins}/{len(calls)} calls decided correctly. The Kraken is still in the cargo hold.")
        sys.exit(1)


if __name__ == "__main__":
    main()
