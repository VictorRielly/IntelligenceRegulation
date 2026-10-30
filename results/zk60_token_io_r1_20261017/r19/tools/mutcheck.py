#!/usr/bin/env python3
"""Token round 19: was a mutant killed for the named reason?

usage: mutcheck.py LOG EXIT_FILE TESTS REASONS
  TESTS    comma-separated full test names; EVERY one must be reported FAILED in LOG
  REASONS  '|'-separated substrings; EVERY one must appear in LOG (the killing assertion's message)
Prints one JSON line; exit 0 = killed as named (compiled, exit 101, each test FAILED, each reason present).
A compile error also exits 101 under cargo test, so "compiled" (no `error[`/`error:` line, a `running N tests` line)
is checked first: a mutant that does not compile is NOT a kill.
"""
import json, re, sys
log, exit_file, tests, reasons = sys.argv[1], sys.argv[2], sys.argv[3].split(","), sys.argv[4].split("|")
text = open(log, errors="replace").read()
rc = open(exit_file).read().strip()
# a compile error is `error[E…]` or cargo's "could not compile"; cargo's own "error: test failed, to rerun pass `--lib`"
# after a failing test is NOT one (10:32 fix: the first form of this check counted it and misjudged fix1-revert)
compiled = (re.search(r"^running \d+ tests?$", text, re.M) is not None and re.search(r"^error\[E\d+\]", text, re.M) is None
            and "error: could not compile" not in text)
failed = {t: re.search(r"^test " + re.escape(t) + r" \.\.\. FAILED$", text, re.M) is not None for t in tests}
found = {r: r in text for r in reasons}
ok = compiled and rc == "101" and all(failed.values()) and all(found.values())
print(json.dumps({"log": log, "exit": rc, "compiled": compiled, "failed": failed, "reasons": found, "killed_as_named": ok}))
sys.exit(0 if ok else 1)
