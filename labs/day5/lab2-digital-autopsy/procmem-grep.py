# Fallback "memory forensics" when AVML is unavailable: scan the readable memory
# regions of the suspicious process directly via /proc/<pid>/mem (requires root,
# which SSM Run Command has). Usage from CloudShell:
#   ./ssm-run.sh $VICTIM "echo $(base64 -w0 procmem-grep.py) | base64 -d | python3"
import os, re
pids = [p for p in os.listdir("/proc") if p.isdigit()]
for pid in pids:
    try:
        cmd = open(f"/proc/{pid}/cmdline", "rb").read()
    except OSError:
        continue
    if b"kworker.py" not in cmd:
        continue
    pretty = cmd.replace(b"\x00", b" ").decode(errors="replace")
    print("[*] pid %s: %s" % (pid, pretty))
    hits = set()
    with open(f"/proc/{pid}/maps") as maps, open(f"/proc/{pid}/mem", "rb", 0) as mem:
        for line in maps:
            rng, perms = line.split()[:2]
            if "r" not in perms:
                continue
            a, b = (int(x, 16) for x in rng.split("-"))
            try:
                mem.seek(a)
                data = mem.read(b - a)
            except (OSError, ValueError, OverflowError):
                continue
            hits.update(re.findall(rb"implant-cfg:[A-Za-z0-9_{}]+", data))
    for h in sorted(hits):
        print("   ", h.decode())
