"""Run actual two-process ENet regression. Usage: python3 tools/test_network.py /path/to/Godot"""
import json
from pathlib import Path
import subprocess
import sys
import time

project = Path(__file__).resolve().parent.parent
executable = sys.argv[1] if len(sys.argv) > 1 else "godot"

def pair(script, port, scenario=None):
    base = [executable, "--headless", "--path", str(project), "--script", script, "--"]
    extra = [scenario] if scenario else []
    host = subprocess.Popen(base + ["host", str(port)] + extra, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    guest = None
    try:
        time.sleep(0.6)
        guest = subprocess.Popen(base + ["guest", str(port)] + extra, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        ho = host.communicate(timeout=20)[0]
        go = guest.communicate(timeout=20)[0]
        if host.returncode or guest.returncode or "SCRIPT ERROR" in ho + go:
            raise RuntimeError(ho + go)
        return ho, go
    finally:
        for process in [host, guest]:
            if process and process.poll() is None:
                process.kill()
                process.wait()

ho, go = pair("res://tests/duel_peer.gd", 24573)
def snapshot(output):
    return json.loads(next(line.split(" ", 2)[2] for line in output.splitlines() if line.startswith("DUEL_RESULT")))
assert snapshot(ho) == snapshot(go), "final snapshots diverged"
print("PASS: full duel, identical final snapshots, invalid sender/revision rejected")
for scenario, port in [("reject", 24574), ("disconnect", 24575)]:
    ho, go = pair("res://tests/duel_failures.gd", port, scenario)
    assert "PASS network" in ho and "PASS network" in go, ho + go
    print("PASS: " + scenario)
