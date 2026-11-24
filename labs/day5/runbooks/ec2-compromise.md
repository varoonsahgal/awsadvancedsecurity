# Runbook — Compromised EC2 instance

> Order of volatility: **memory → network state → processes → disk → logs**. Collect the most volatile first, but **never** do it in a way that lets the attacker watch you work.

## Preserve the scene (do NOT reboot, stop, or terminate)
- [ ] `aws ec2 modify-instance-attribute --instance-id i-… --disable-api-termination`
- [ ] Set `InstanceInitiatedShutdownBehavior` to `stop`, so a shutdown from inside stops the instance instead of terminating it.
- [ ] Tag: `ir-case=<id>`, `ir-status=contained`.
- [ ] If in an Auto Scaling group: `aws autoscaling detach-instances --should-decrement-desired-capacity false` (otherwise the ASG may replace and terminate it), or put it in Standby.
- [ ] If behind a load balancer: deregister from target groups.

## Isolate without tipping off
1. Apply an **allow-all** security group first (all traffic, `0.0.0.0/0` in and out). This makes existing connections **untracked**.
2. Then swap to the **quarantine** SG (no ingress; egress only to the SSM interface endpoints). Untracked flows drop immediately. Tracked flows would have survived the swap.
3. Optional belt and braces: a NACL deny on the subnet (stateless, immediate, but it affects the whole subnet).
4. Remove or replace the instance profile only **after** you've captured what the role could do, because the attacker can see that change through IMDS. Revoke the role's sessions with the TokenIssueTime deny.

## Collect
- [ ] **Memory:** attach an empty evidence EBS volume, run AVML or LiME through SSM Run Command, write the image to the evidence volume, then `sha256sum` it.
- [ ] **Disk:** `aws ec2 create-snapshots --instance-specification InstanceId=i-…` (crash-consistent, all volumes) and tag the snapshots.
- [ ] **Metadata:** `describe-instances` JSON, console output and screenshot (`get-console-output`, `get-console-screenshot`), VPC Flow Logs, GuardDuty findings, CloudTrail for the instance role's sessions.
- [ ] Record every item in the chain-of-custody log (who, what, when in UTC, hash, where it's stored). Use an evidence bucket with Object Lock.

## Analyze (in the forensic account, in an isolated subnet)
- [ ] Create volumes from the snapshots in the forensic workstation's AZ and attach them.
- [ ] Mount read-only: XFS `ro,norecovery,nouuid`; ext4 `ro,noload`. `blockdev --setro` first.
- [ ] Check persistence: cron, systemd units, `authorized_keys`, rc scripts, `/etc/ld.so.preload`, new users, shell profiles.
- [ ] Build a timeline with `stat`. mtime can be forged with `touch -d`; ctime can't be set from userland.
- [ ] Memory: `strings`/`grep -a` for quick wins; Volatility 3 with matching Linux symbols for process, network and module analysis.

## Recover
- [ ] Rebuild from a known-good AMI or pipeline. Never "clean" the compromised host.
- [ ] Fix the root cause (vulnerable package, exposed port, leaked key, IMDSv1).
- [ ] Keep evidence for as long as legal requires, then expire it on purpose.
