# GameDay kit — "Kraken Rising"

Friday-afternoon capstone for Operation Skyfortress. Student page: [`gameday.html`](../../gameday.html).

| File | Purpose |
|------|---------|
| `kraken-gameday.yaml` | CloudFormation: VPC + dispatch EC2 (SSM-managed) + Resolver query logging + cargo/artifacts/evidence buckets + the GameDay IAM identities + the `CaptureVolatile` SSM document |
| `kraken-replay.sh` | **Facilitator only.** Seeds data, then replays the Kraken intrusion with real API calls against *your own* stack (custom user agent on every call). `reentry` mode = Inject 4 |
| `gameday-check.sh` | Verifies the account's state for the Contain / Recover / Harden challenges and prints flags |
| `teardown.sh` | Removes everything, including resources created outside CloudFormation |
| `seed/` | Pre-incident cargo manifests and chatbot knowledge-base docs |

```bash
aws cloudformation deploy --stack-name kraken-gameday --template-file kraken-gameday.yaml \
  --capabilities CAPABILITY_NAMED_IAM --region us-east-1
./kraken-replay.sh          # facilitator, ≥15 min before kickoff
./gameday-check.sh all      # teams
./teardown.sh               # everyone, at 17:00
```

**Safety:** sandbox accounts only. No malware and no external targets. The "C2" is `*.kraken.example.com`
(IANA-reserved, never resolves). The backdoored trust policy is limited to a non-existent organization,
and the open SSH rule sits on an instance with no key pair. **Cost:** under $0.50 for the afternoon.

**Rules of engagement:** reading or decoding the flag strings in these files instead of solving the
challenges costs −500 points.
