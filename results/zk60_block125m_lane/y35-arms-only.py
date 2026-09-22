#!/usr/bin/env python3
"""Stage 35's arms-only proof.

Stage 34's condition on `argument.rs` was that NOTHING in it moves
(`x34-arm-immutability.py`, which counts removed and added lines and expects
zero of each). Stage 35 deliberately rewrites two arms, so its condition is
the next one down: **every changed line of
`hashline/src/private_block/argument.rs` lies inside the `SC_DZC` arm or the
`SC_SZC` arm** — no other arm of `define`, and nothing outside `define`.

The script states that as a measurement. It

  * locates the two arms in the BASE version of the file and in the TIP
    version, by finding the arm head (`SC_DZC => {` / `SC_SZC => {`) and
    matching braces to its close;
  * reads the unified diff at zero context and, for every hunk, checks that
    the lines it REMOVES lie inside one of the two arms of the base file and
    that the lines it ADDS lie inside one of the two arms of the tip file;
  * prints every hunk with its verdict, and fails if any hunk falls outside.

A hunk that only adds lines still has a position in the base file, and the
script checks that position lies strictly inside an arm, so an insertion
between two arms cannot pass.

Usage:  python3 results/zk60_block125m_lane/y35-arms-only.py <base> [tip]
"""
import re
import subprocess
import sys

REPO = "/home/victor/wt-zk60-block125m"
FILE = "hashline/src/private_block/argument.rs"
ARMS = ("SC_DZC", "SC_SZC")


def run(*args):
    return subprocess.run(["git", "--no-pager", "-C", REPO, *args], capture_output=True, text=True, check=True).stdout


def arm_spans(text):
    """{arm name: (first line, last line)}, 1-based inclusive"""
    lines = text.splitlines()
    out = {}
    for name in ARMS:
        head = f"{name} => {{"
        start = next(i for i, l in enumerate(lines) if l.strip() == head)
        depth = 0
        for i in range(start, len(lines)):
            depth += lines[i].count("{") - lines[i].count("}")
            if depth == 0:
                out[name] = (start + 1, i + 1)
                break
        else:
            raise SystemExit(f"the {name} arm does not close")
    return out


def inside(spans, lo, hi):
    """is the whole range [lo, hi] inside one arm?"""
    return any(a <= lo and hi <= b for a, b in spans.values())


def main():
    base = sys.argv[1]
    tip = sys.argv[2] if len(sys.argv) > 2 else "HEAD"
    old, new = run("show", f"{base}:{FILE}"), run("show", f"{tip}:{FILE}")
    sold, snew = arm_spans(old), arm_spans(new)
    print(f"base {base}  tip {tip}  file {FILE}")
    for name in ARMS:
        print(f"  {name}: base lines {sold[name][0]}..{sold[name][1]}, tip lines {snew[name][0]}..{snew[name][1]}")
    diff = run("diff", "-U0", base, tip, "--", FILE)
    hunks = re.findall(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", diff, re.M)
    if not hunks:
        print("the diff is empty: no line of argument.rs moved")
        return 0
    bad = 0
    for a, an, b, bn in hunks:
        a, b = int(a), int(b)
        an = 1 if an is None or an == "" else int(an)
        bn = 1 if bn is None or bn == "" else int(bn)
        # a zero-length side sits BETWEEN base line a and a+1 (git's
        # convention), so the position to test is a and a+1 both inside
        olo, ohi = (a, a + an - 1) if an else (a, a + 1)
        nlo, nhi = (b, b + bn - 1) if bn else (b, b + 1)
        ok = inside(sold, olo, ohi) and inside(snew, nlo, nhi)
        bad += not ok
        print(f"  hunk -{a},{an} +{b},{bn}: base {olo}..{ohi}, tip {nlo}..{nhi} — {'inside an arm' if ok else 'OUTSIDE THE TWO ARMS'}")
    removed = sum(1 for l in diff.splitlines() if l.startswith("-") and not l.startswith("---"))
    added = sum(1 for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++"))
    print(f"{len(hunks)} hunks, {removed} removed lines, {added} added lines, {bad} hunks outside the two arms")
    print("VERDICT:", "every changed line of argument.rs is inside the SC_DZC or the SC_SZC arm" if not bad else "a change falls outside the two arms — READ THE LIST ABOVE")
    return 0 if not bad else 1


if __name__ == "__main__":
    sys.exit(main())
