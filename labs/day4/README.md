# Day 4 lab files — Vaults & Thinking Machines

Run everything from CloudShell in **us-east-1**, from the course repo root.

```bash
pip3 install --user boto3 cryptography cedarpy
```

| Folder | Lab | What's inside |
|---|---|---|
| `crypto-dojo/` | 4.1 Crypto Dojo | `envelope.py` (envelope encryption with KMS + AES-GCM), `vault_drop.py` (the Kraken's dead drop), `key-policy.json`, `trust-policy.json`, `release-manifest.json` |
| `ransom/` | 4.2 Ransom in the Clouds | `seed_cargo.py` (lab buckets), `kraken_ransom.py` (SSE-C ransomware simulator — only touches `nimbus-cargo-*` buckets), `rcp-deny-ssec.json`, `bucket-policy-deny-ssec.json` |
| `starship-bot/` | 4.3 Jailbreak the Starship AI | `starship_bot.py` (deliberately vulnerable Bedrock bot with `--hardened` mode), `setup_docs.sh`, `docs/`, `payloads/`, `guardrail.json` |
| `leash/` | 4.4 Leash the Agent | `policies.cedar` (starter), `entities.json`, `scenarios.json`, `test_policies.py` (local Cedar harness) |
| `boss/` | Boss: The Poisoned Manifest | `cargo_manifest_NX-7781.txt`, `agent_trace.jsonl`, `boss_policies.cedar`, `boss_check.py` |

Safety: these labs create real AWS resources. Use only the sandbox accounts from Lab 0 and run each lab's cleanup block.
