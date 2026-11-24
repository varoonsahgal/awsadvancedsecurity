# Day 2 · Eyes in the Sky — lab support files

Everything here is meant to be run from **AWS CloudShell in us-east-1**, inside the Skyfortress
sandbox organization you built in Lab 0. Never run these against production accounts.

| Folder | Lab | What's inside |
|---|---|---|
| `lab1/` | 2.1 Light the Beacons | delegated-admin + GuardDuty org config scripts, org-trail bucket policy, advanced event selectors, beacon test |
| `lab2/` | 2.2 Summon the Kraken | Stratus Red Team installer, `kraken-chain.py` S3 smash-and-grab, findings triage, cleanup |
| `lab3/` | 2.3 Hunt the Deep | hunt seeder, Athena DDL for the org trail, two hunt packs (raw CloudTrail + Security Lake OCSF), Athena CLI runner |
| `lab4/` | 2.4 Tripwires as Code | EventBridge patterns, Lambda detector (with TODOs), unit tests + test events, Terraform, Security Hub automation rules |
| `boss/` | The 3 A.M. Backdoor | persistence planter + cleanup |

Conventions (from Lab 0): no `--profile` = management account; `sky-dev` = security tooling / delegated admin; `sky-prod` = workloads. `source ~/.skyfortress.env` gives `$SKY_DEV` and `$SKY_PROD`. Stratus Red Team is installed by Lab 0 (`install-tools.sh`); `lab2/install-stratus.sh` is a fallback.
Make scripts executable once: `chmod +x labs/day2/**/*.sh`.
