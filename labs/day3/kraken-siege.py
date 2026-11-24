#!/usr/bin/env python3
"""
kraken-siege.py - Operation Skyfortress, Lab 3.2 "Shields Up"
A BENIGN attack simulator. It will ONLY target an API Gateway execute-api URL in your own
account (guard below). Stdlib only - runs in CloudShell with python3.

  python3 kraken-siege.py https://abc123.execute-api.us-east-1.amazonaws.com/prod

Phases: control, sqli, traversal, http-library bots, credential stuffing, AI-scraper flood.
If every defence holds, the Kraken concedes and drops a flag.
"""
import base64, json, random, string, sys, time, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor

BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
SCRAPER = "Mozilla/5.0 (compatible; KrakenScraper/1.0; +https://kraken.example/bot)"
LIBRARY = "python-requests/2.32.3"
CONCEDE = "fWRlbGlhZl9zYWhfZWdlaXNfZWh0e1lLUwo="

def req(base, path, ua=BROWSER, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(base + path, data=data, method=method,
                               headers={"User-Agent": ua, "Content-Type": "application/json", "Accept": "*/*"})
    try:
        with urllib.request.urlopen(r, timeout=8) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0

def banner(t): print("\n\033[95m== " + t + " ==\033[0m")
def verdict(name, ok, detail):
    print(("  \033[92m[HELD]\033[0m " if ok else "  \033[91m[BREACHED]\033[0m ") + name + " - " + detail)
    return ok

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    base = sys.argv[1].rstrip("/")
    host = urllib.parse.urlparse(base).hostname or ""
    if not host.endswith(".execute-api.us-east-1.amazonaws.com"):
        sys.exit("Refusing: target must be your own *.execute-api.us-east-1.amazonaws.com stage URL.")
    results = []

    banner("Phase 0 - control (a real customer must still get in)")
    c = req(base, "/")
    results.append(verdict("control", c == 200, "GET / as a browser -> %s (want 200)" % c))

    banner("Phase 1 - SQL injection")
    payloads = ["' OR '1'='1", "1 UNION SELECT username,password FROM crew--", "1; DROP TABLE cargo;--",
                "1' AND SLEEP(5)--", "' OR 1=1 LIMIT 1 -- -"]
    codes = [req(base, "/search?q=" + urllib.parse.quote(p)) for p in payloads]
    results.append(verdict("sqli", all(x == 403 for x in codes), "codes %s (want all 403)" % codes))

    banner("Phase 2 - path traversal / LFI")
    payloads = ["../../../../etc/passwd", "..%2f..%2f..%2fetc%2fshadow", "....//....//proc/self/environ", "/etc/passwd"]
    codes = [req(base, "/files?path=" + p) for p in payloads]
    results.append(verdict("traversal", all(x == 403 for x in codes), "codes %s (want all 403)" % codes))

    banner("Phase 3 - HTTP-library bots")
    codes = [req(base, "/search?q=cargo", ua=LIBRARY) for _ in range(10)]
    results.append(verdict("http-library", sum(x == 403 for x in codes) >= 8, "codes %s (want >=8 x 403)" % codes))

    banner("Phase 4 - credential stuffing on /login (runs up to 120s)")
    blocked, sent, t0 = 0, 0, time.time()
    while time.time() - t0 < 120 and blocked < 15:
        user = random.choice(["captain", "nav", "admin", "quartermaster"]) + str(random.randint(1, 999))
        pw = "".join(random.choices(string.ascii_letters + string.digits, k=12))
        code = req(base, "/login", method="POST", body={"username": user, "password": pw})
        sent += 1
        blocked += code in (403, 429)
        print("\r  attempts=%d blocked=%d last=%s   " % (sent, blocked, code), end="", flush=True)
        time.sleep(0.4)
    print()
    results.append(verdict("credential-stuffing", blocked >= 15, "%d of %d attempts blocked" % (blocked, sent)))

    banner("Phase 5 - AI scraper swarm (runs up to 120s)")
    got429, sent, t0 = 0, 0, time.time()
    with ThreadPoolExecutor(max_workers=6) as pool:
        while time.time() - t0 < 120 and got429 < 30:
            codes = list(pool.map(lambda _: req(base, "/search?q=" + random.choice(["fuel", "crew", "routes"]), ua=SCRAPER), range(6)))
            sent += len(codes)
            got429 += sum(x == 429 for x in codes)
            print("\r  requests=%d http429=%d last=%s   " % (sent, got429, codes[-1]), end="", flush=True)
            time.sleep(0.25)
    print()
    results.append(verdict("scraper-flood", got429 >= 30, "%d x 429 custom responses (want >=30)" % got429))

    banner("Siege report")
    if all(results):
        print("  Kraken: ...the shields held. All of them. I'll be back with more tentacles.")
        print("  >> " + base64.b64decode(CONCEDE).decode().strip()[::-1])
    else:
        print("  Kraken: hehehe - %d of %d defences breached. Check WAF sampled requests and try again."
              % (results.count(False), len(results)))

if __name__ == "__main__":
    main()
