#!/usr/bin/env python3
"""Round 9: check a failing-first cargo test log against the EXPECTED failing set.

usage: r9_expect.py LOG EXPECTED_NAME [EXPECTED_NAME ...]

Reads the `test <path> ... ok|FAILED|ignored` lines of a cargo test log (one
test binary: `--lib` with a filter). Exit 0 only if the tests that FAILED are
exactly the expected ones (each named by its last path segment), at least one
test passed, and every expected name ran. Prints one JSON line either way.
"""
import json
import re
import sys


def main():
    log, want = sys.argv[1], set(sys.argv[2:])
    ran, failed, passed = set(), set(), set()
    for line in open(log, errors="replace"):
        m = re.match(r"^test (\S+) \.\.\. (ok|FAILED|ignored)\s*$", line.rstrip("\n"))
        if not m:
            continue
        name = m.group(1).rsplit("::", 1)[-1]
        ran.add(name)
        if m.group(2) == "FAILED":
            failed.add(name)
        elif m.group(2) == "ok":
            passed.add(name)
    ok = failed == want and want <= ran and len(passed) > 0
    print(json.dumps({"event": "expect-failing", "ok": ok, "failed": sorted(failed), "expected": sorted(want),
                      "unexpected_failures": sorted(failed - want), "expected_but_not_failed": sorted(want - failed),
                      "passed": len(passed), "ran": len(ran)}))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
