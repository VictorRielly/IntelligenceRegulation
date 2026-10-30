#!/usr/bin/env python3
"""Token round 15: tally a cargo test log — the `test result:` lines (passed / failed / ignored, binaries) and the
round-15 tests' own `... ok` lines. usage: tally_suite.py LOG"""
import re, sys

text = open(sys.argv[1], errors="replace").read()
res = re.findall(r"test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored", text)
p = sum(int(r[1]) for r in res)
f = sum(int(r[2]) for r in res)
i = sum(int(r[3]) for r in res)
oks = len(re.findall(r" \.\.\. ok$", text, re.M))
print(f"binaries {len(res)}: {p} passed, {f} failed, {i} ignored; ok-lines {oks}")
for name in sorted(set(re.findall(r"^test (\S*r15_\S*) \.\.\. (\w+)", text, re.M))):
    print("  ", name[0], name[1])
fails = re.findall(r"^test (\S+) \.\.\. FAILED", text, re.M)
if fails:
    print("FAILED:", fails)
