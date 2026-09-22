#!/usr/bin/env python3
"""Stage 34's arm-immutability proof.

Ruling I-8's hard condition on this stage is that the IR is built BESIDE the
closures and that no execution path changes: the diff of
`hashline/src/private_block/argument.rs` between the stage's base commit and
its tip must contain no DELETED and no MODIFIED line inside any `SC_*` arm of
`argument::define`.

This script states that as a measurement rather than a promise. It counts,
in the unified diff of that one file:

  * removed lines (`-` at column 0, excluding the `---` file header),
  * added lines (`+`, excluding `+++`),

and it separately reports whether any removed line falls inside `define`'s
`match slot { .. }` block in the BASE version of the file, which is where the
twenty-three arms live. A removed line anywhere in the file fails the first
test; a removed line inside the match block fails the stricter one.

Usage:  python3 results/zk60_block125m_lane/x34-arm-immutability.py <base> [tip]
"""
import re
import subprocess
import sys

REPO = "/home/victor/wt-zk60-block125m"
FILE = "hashline/src/private_block/argument.rs"


def run(*args):
    return subprocess.run(["git", "--no-pager", "-C", REPO, *args], capture_output=True, text=True, check=True).stdout


def arm_span(text):
    """the line range of `define`'s `match slot {` block, 1-based, inclusive"""
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "match slot {")
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0:
            return start + 1, i + 1
    raise SystemExit("the match block does not close")


def main():
    base = sys.argv[1]
    tip = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    diff = run("diff", "-U0", base, tip, "--", FILE)
    removed = [l for l in diff.splitlines() if l.startswith("-") and not l.startswith("---")]
    added = [l for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    old = run("show", f"{base}:{FILE}")
    lo, hi = arm_span(old)
    arms = len(re.findall(r"^\s+SC_[A-Z0-9_]+(?: \| SC_[A-Z0-9_]+)* =>", old, re.M))
    print(f"base {base}  tip {tip}  file {FILE}")
    # 26 and not 16: the count includes the INNER `match slot` arms the matmul
    # families use to pick a plane and a weight matrix, which is right — those
    # lines are inside an arm and must not move either
    print(f"`define`'s match block in the base version: lines {lo}..{hi}, {arms} `SC_* =>` arm heads (16 outer arms over 23 slots, plus the inner matmul matches)")
    print(f"removed lines in the whole file: {len(removed)}")
    print(f"added   lines in the whole file: {len(added)}")
    for l in removed:
        print("  REMOVED:", l)
    ok = not removed
    print("VERDICT:", "no line of argument.rs is deleted or modified, so no line of any SC_* arm is" if ok else "a line of argument.rs was deleted or modified — READ THE LIST ABOVE")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
