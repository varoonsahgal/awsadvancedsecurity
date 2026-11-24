#!/usr/bin/env bash
# Runs ON THE FORENSIC WORKSTATION (via SSM). Mounts every non-root evidence
# volume read-only under /evidence/<device> and prints a quick triage.
#
# XFS gotcha: a volume restored from a snapshot of an instance launched from
# the SAME AMI as the workstation has the SAME filesystem UUID as our own root.
# Without `nouuid` the mount fails. `norecovery` stops XFS from replaying the
# journal — replaying would WRITE to the evidence. (ext4 equivalent: ro,noload)
set -uo pipefail
ROOTDEV=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
mkdir -p /evidence
for disk in $(lsblk -dno NAME | grep -v "^${ROOTDEV}$" | grep nvme); do
  for part in $(lsblk -lno NAME "/dev/${disk}" | tail -n +1); do
    fstype=$(lsblk -no FSTYPE "/dev/${part}" | head -1)
    [ -z "$fstype" ] && continue
    mp="/evidence/${part}"; mkdir -p "$mp"
    case "$fstype" in
      xfs)  opts="ro,norecovery,nouuid" ;;
      ext4) opts="ro,noload" ;;
      *)    opts="ro" ;;
    esac
    blockdev --setro "/dev/${part}"
    if mount -o "$opts" "/dev/${part}" "$mp" 2>/dev/null; then
      echo "[+] /dev/${part} ($fstype) mounted read-only at $mp"
    fi
  done
done
echo; echo "== triage =="
for mp in /evidence/*; do
  mountpoint -q "$mp" || continue
  echo "--- $mp"
  ls -la "$mp"/etc/cron.d 2>/dev/null
  find "$mp"/usr/local/bin "$mp"/tmp -maxdepth 1 -name '.*' -type f 2>/dev/null
  find "$mp"/home "$mp"/root -name authorized_keys -exec grep -H . {} \; 2>/dev/null
  ls -la "$mp"/*.lime 2>/dev/null
done
