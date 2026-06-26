import json
import os
import random
import time
import urllib.error
import urllib.request

BASE_URL = os.getenv("COMMAND_URL", "http://command-api:8080").rstrip("/")
DELAY_MS = int(os.getenv("LOADGEN_DELAY_MS", "750"))
BURST = int(os.getenv("LOADGEN_BURST", "1"))
TIMEOUT = float(os.getenv("LOADGEN_TIMEOUT_SECONDS", "5"))

COMMANDS = [
    ("status", "GET", "/api/status", None, 2),
    ("cargo", "GET", "/api/cargo", None, 2),
    ("credits", "GET", "/api/credits/authorize", None, 2),
    ("credits-fail", "GET", "/api/credits/fail", None, 1),
    ("not-found", "GET", "/api/wormhole/missing-sector", None, 1),
    ("orbit", "GET", "/api/orbit/recommend", None, 3),
    (
        "mission",
        "POST",
        "/api/missions",
        {"commander": "autopilot", "destination": "M42", "priority": 3},
        5,
    ),
]


def call(name, method, path, body):
    payload = json.dumps(body).encode() if body else None
    request = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=payload,
        method=method,
        headers={"content-type": "application/json"},
    )
    started = time.time()
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            response.read()
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
    except Exception as exc:
        print(json.dumps({"event": "loadgen.error", "target": name, "error": str(exc)}), flush=True)
        return
    latency_ms = int((time.time() - started) * 1000)
    print(json.dumps({"event": "loadgen.request", "target": name, "status": status, "latency_ms": latency_ms}), flush=True)


def main():
    weighted = []
    for command in COMMANDS:
        weighted.extend([command] * command[4])
    print(json.dumps({"event": "loadgen.start", "base_url": BASE_URL, "delay_ms": DELAY_MS, "burst": BURST}), flush=True)
    while True:
        for _ in range(BURST):
            name, method, path, body, _weight = random.choice(weighted)
            call(name, method, path, body)
        time.sleep(max(DELAY_MS, 0) / 1000)


if __name__ == "__main__":
    main()
