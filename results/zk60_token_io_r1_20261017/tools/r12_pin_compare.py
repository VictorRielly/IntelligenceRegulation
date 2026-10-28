#!/usr/bin/env python3
"""Compare the six approved next-token pins: the approval record's value, the
round-11 binary's (native R8) and the R12 rebase probe's. Writes
logs/r12-pin-check.json and prints one line per pin; exit 1 if a run printed
no profile line."""
import glob
import json
import os
import sys

R = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017"
L = R + "/logs"


def profile_line(path):
    for line in open(path, errors="replace"):
        line = line.strip()
        if line.startswith('{"event":"profile"'):
            return json.loads(line)
    return None


rows = []
bad = False
for rec in sorted(glob.glob(R + "/approvals/token_profile_approval_*.json")):
    name = os.path.basename(rec)[len("token_profile_approval_"):-len(".json")]
    j = json.load(open(rec))
    old = profile_line(f"{L}/r12-pin-old-{name}.log")
    new = profile_line(f"{L}/r12-pin-new-{name}.log")
    if old is None or new is None:
        bad = True
        print(f"{name}: a profile run printed no profile line")
        continue
    for pin, key in (("expect_statement", "trained_statement_identity"), ("expect_token_profile", "token_profile_digest")):
        approved, o, n = j["pins"][pin], old[key], new[key]
        rows.append({"record": name, "pin": pin, "approved": approved, "native_r8_r11_binary": o, "native_r12_probe": n, "r8_equals_approved": o == approved, "moved_under_r12": n != o})
        print(f"{name} {pin}: approved {approved[:16]}  r8 {o[:16]} ({'=' if o == approved else 'DIFFERS'})  r12 {n[:16]} ({'unchanged' if n == o else 'MOVED'})")
json.dump({"rows": rows, "moved": [r for r in rows if r["moved_under_r12"]]}, open(L + "/r12-pin-check.json", "w"), indent=1)
sys.exit(1 if bad else 0)
