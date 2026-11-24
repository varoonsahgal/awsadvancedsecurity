# Runbook — Compromised AWS credentials

**Owner:** Nimbus Interstellar SecOps · **Severity default:** High · **Last tested:** GameDay, Day 5

> Rule zero: **don't tip off the attacker** until you're ready to cut every path. Revoke **everything** in one coordinated move.

## 0. Declare and assemble (T+0 → T+10 min)
- [ ] Open an incident case (AWS Security Incident Response case or your ticketing tool). Record the case ID.
- [ ] Assign roles: Incident Commander, Ops lead (hands on keyboard), Comms, Scribe.
- [ ] Get into the **IR role** in the affected account. Use break-glass only if your normal path is compromised.
- [ ] If the scope is large or it looks like a nation-state/ransomware crew, **engage AWS CIRT** through the Security Incident Response service.

## 1. Identify the credential and its type
| Prefix | Type | Survives key deactivation? |
|---|---|---|
| `AKIA…` | IAM user long-term key | — |
| `ASIA…` | STS temporary credentials (role session, GetSessionToken, federation) | **YES** — valid until expiry (up to 12 h for role sessions, 36 h for GetSessionToken) |
| Identity Center portal session | Workforce SSO | Revoke from the Identity Center console; existing role sessions still need revocation |

## 2. Scope the blast radius (in parallel with step 3 prep)
```bash
# Everything the key did (CloudTrail event history covers 90 days, management events, per Region)
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIA... \
  --max-results 50 --query 'Events[].[EventTime,EventName,EventSource]' --output table

# Did it mint temporary credentials? Find the ASIA keys it was issued, then pivot on those.
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole \
  --query 'Events[].CloudTrailEvent' --output text | jq -r 'select(.userIdentity.accessKeyId=="AKIA...") | .responseElements.credentials.accessKeyId'
```
- [ ] For org-wide scope, query the **org trail with Athena** or **Security Lake** (CloudTrail Lake closed to new customers on May 31, 2026) — event history is per account/Region.
- [ ] Open the principal in **Amazon Detective** for the behavior graph (new geolocations, new APIs, new ASNs).
- [ ] Look for **persistence**: `CreateUser`, `CreateAccessKey`, `CreateLoginProfile`, `UpdateAssumeRolePolicy`, `CreateRole`, `AttachRolePolicy`, `PutRolePolicy`, `CreateFunction`, `PutParameter`, `ImportKeyPair`, `AuthorizeSecurityGroupIngress`, new OIDC/SAML providers, Identity Center user/permission-set changes.
- [ ] Look for **defense evasion**: `StopLogging`, `DeleteTrail`, `PutEventSelectors`, `UpdateDetector`, `CreateFilter` (GuardDuty suppression), `DeleteFlowLogs`, `DisableSecurityHub`.

## 3. Contain — all at once
```bash
# a) Deactivate (not delete — you need it for the investigation) the long-term key
aws iam update-access-key --user-name USER --access-key-id AKIA... --status Inactive

# b) Kill temporary creds issued by the user (GetSessionToken/federation) and any role it pivoted into
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq --arg t "$NOW" '.Statement[0].Condition.DateLessThan["aws:TokenIssueTime"]=$t' revoke-older-sessions.json > /tmp/revoke.json
aws iam put-user-policy --user-name USER --policy-name AWSRevokeOlderSessions --policy-document file:///tmp/revoke.json
aws iam put-role-policy --role-name ROLE --policy-name AWSRevokeOlderSessions --policy-document file:///tmp/revoke.json
```
- [ ] Re-test with the stolen credentials (lab: `kraken-retry.sh`) — expect `AccessDenied` on everything except `sts:GetCallerIdentity` (it can never be denied).
- [ ] For a multi-account spread: attach a **quarantine SCP** to the affected accounts/OU that denies the compromised principal ARNs (or all non-IR principals).

## 4. Eradicate
- [ ] Remove every persistence mechanism found in step 2.
- [ ] Rotate any secret the principal could read (Secrets Manager, SSM SecureString, Lambda env vars, CI variables).
- [ ] Replace long-term keys with roles + OIDC federation (GitHub Actions, GitLab, etc.).

## 5. Recover & improve
- [ ] Re-enable anything the attacker disabled; confirm with a test finding.
- [ ] Add an SCP so the evasion technique used is impossible next time.
- [ ] Write a detection for the earliest signal you missed.
- [ ] Blameless retro within 5 business days. Track MTTD / MTTC / MTTR.
