#!/usr/bin/env python3
"""
Lab 4.4 — local Cedar harness. Replays the tool calls an agent would make through YOUR policies.

  pip install --user cedarpy
  python3 test_policies.py                       # uses policies.cedar + scenarios.json
  python3 test_policies.py --policies my.cedar --explain

Every scenario must match its expected decision. Get them all and the refund tool coughs up a
confirmation code (the flag). This is exactly the decision an AgentCore Policy engine makes at the
Gateway — before the tool ever runs and regardless of what the model was tricked into wanting.
"""
import argparse, base64, json, sys

try:
    from cedarpy import is_authorized, Decision
except ImportError:
    sys.exit("cedarpy missing: pip install --user cedarpy")

_F = "eWFzUUlPTktYdVlLU1l1REV1QVhLQU9EdVlLU1l1RV1X"


def _r(s):
    return bytes(b ^ 0x2A for b in base64.b64decode(s)).decode()


def request(sc):
    return {
        "principal": f'Nimbus::User::"{sc["principal"]}"',
        "action": f'Nimbus::Action::"{sc["tool"]}"',
        "resource": 'Nimbus::Gateway::"refund-gateway"',
        "context": {"input": sc["input"], "day_of_week": sc["day"]},
    }


def evaluate(policies, entities, scenarios, explain=False):
    passed = 0
    print(f"{'ID':<4} {'EXPECT':<6} {'GOT':<6}  SCENARIO")
    print("-" * 78)
    for sc in scenarios:
        res = is_authorized(request(sc), policies, entities)
        got = "Allow" if res.decision == Decision.Allow else "Deny"
        ok = got == sc["expect"]
        passed += ok
        mark = "\033[32m✓\033[0m" if ok else "\033[31m✗\033[0m"
        print(f"{sc['id']:<4} {sc['expect']:<6} {got:<6} {mark} {sc['why']}")
        if explain or not ok:
            d = res.diagnostics
            reasons = list(getattr(d, "reasons", []) or [])
            errors = list(getattr(d, "errors", []) or [])
            if reasons:
                print(f"       determining policies: {reasons}")
            if errors:
                print(f"       evaluation errors (policy skipped → fail closed): {errors}")
    return passed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--policies", default="policies.cedar")
    ap.add_argument("--entities", default="entities.json")
    ap.add_argument("--scenarios", default="scenarios.json")
    ap.add_argument("--explain", action="store_true")
    a = ap.parse_args()
    policies = open(a.policies).read()
    entities = json.load(open(a.entities))
    scenarios = json.load(open(a.scenarios))
    passed = evaluate(policies, entities, scenarios, a.explain)
    print("-" * 78)
    print(f"{passed}/{len(scenarios)} scenarios behave correctly")
    if passed == len(scenarios):
        print(f"\n💳 RefundTool: refund S03 processed. confirmation code = {_r(_F)}")
        print("🦉 Owlsley: 'The agent is on a leash. A short one.'")
    else:
        print("🐙 The Kraken is still shopping with your refund tool. Keep tightening.")
        sys.exit(1)


if __name__ == "__main__":
    main()
