# Day 5 lab files: Kraken Rising

Run everything from **AWS CloudShell in us-east-1** unless noted. Every lab has a `cleanup.sh`.

| Folder | Lab | What's inside |
|---|---|---|
| `lab1-burned-keys/` | 5.1 Burned Keys | `setup.sh` (vulnerable user/role, leaked key), `attacker.sh` (simulated Kraken), `kraken-retry.sh` (tests the stolen creds), `revoke-older-sessions.json`, `cleanup.sh` |
| `lab2-digital-autopsy/` | 5.2 Digital Autopsy | `autopsy.yaml` (victim and forensic workstation, isolated subnet, SSM endpoints, Object Lock evidence bucket), `deploy.sh`, `ssm-run.sh`, `forensic-mount.sh`, `chain-of-custody.json`, `cleanup.sh` |
| `lab3-autopilot/` | 5.3 Autopilot Defense | `autopilot.yaml` (EventBridge, Step Functions, Lambda, SNS), `playbook.asl.json` (readable copy of the state machine), `fire.sh`, `approve.sh`, `launch-decoy.sh`, `cleanup.sh` |
| `boss/` | The Kraken's Last Stand | `setup.sh` (attack simulation in the **dev member account**), `protect-security-tooling.scp.json`, `verify.py`, `cleanup.sh` |
| `runbooks/` | Take-home | `credential-compromise.md`, `ec2-compromise.md` |

```bash
git clone <this repo> && cd <repo>/labs/day5 && chmod +x */*.sh
```

Approximate cost if you clean up the same day: **under $1**. Lab 5.2 is the most expensive part (about $0.10/hr).
