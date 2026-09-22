#!/usr/bin/env python3
"""STAGE 36's PRODUCTION-IDENTITY PROOF.

The integrator's condition: *"Every line you add to `zkp-core` and to
`protocol.rs` must be inside `#[cfg(any(test, feature = "test-observers"))]`
(or `#[cfg(test)]` for core's own tests) — the production build without the
feature must compile byte-for-byte the same code paths."*

This script checks that mechanically. For each watched file it takes the
diff between two commits and requires every added or changed line to be
either

  * inside a `#[cfg(test)]` or `#[cfg(any(test, feature = "test-observers"))]`
    item (the attribute, the item it gates, and any comment block directly
    above the attribute), or
  * a comment or a blank line, which compiles to nothing at all,

and requires that NO line was deleted outside such a region. A file that
adds one unguarded statement fails, and the script prints it.

  python3 results/zk60_block125m_lane/z36-cfg-gate-proof.py <base> <head>

Manifests are checked separately, by rule rather than by gate: the feature
may appear in zkp-core's `[features]` and in hashline's `[dev-dependencies]`
and nowhere else.
"""
import re
import subprocess
import sys

ROOT = "/home/victor/wt-zk60-block125m"

# the source files the condition is about
WATCHED = [
    "zkp-core/src/rng.rs",
    "zkp-core/src/transcript.rs",
    "hashline/src/private_block/protocol.rs",
]

GATES = ('#[cfg(test)]', '#[cfg(any(test, feature = "test-observers"))]')


def git(*args):
    return subprocess.run(["git", "--no-pager", "-C", ROOT, *args],
                          capture_output=True, text=True, check=True).stdout


def gated_ranges(text):
    """Line ranges (1-based, inclusive) of every cfg-gated region."""
    lines = text.split("\n")
    out = []
    for i, line in enumerate(lines):
        if line.strip() not in GATES:
            continue
        start = i + 1  # 1-based
        # extend upward over a contiguous comment block
        j = i - 1
        while j >= 0 and (lines[j].lstrip().startswith("//") or lines[j].strip() == ""):
            start = j + 1
            j -= 1
        # the item the attribute gates: to its matching closing brace, or to
        # the end of the statement if it does not open a block
        k = i + 1
        while k < len(lines) and (lines[k].lstrip().startswith("#[") or lines[k].lstrip().startswith("///") or lines[k].strip() == ""):
            k += 1
        depth = 0
        opened = False
        end = k
        while k < len(lines):
            code = re.sub(r'"(\\.|[^"\\])*"', '""', lines[k])
            code = re.sub(r"//.*$", "", code)
            depth += code.count("{") - code.count("}")
            if "{" in code:
                opened = True
            end = k
            if opened and depth <= 0:
                break
            if not opened and code.rstrip().endswith(";"):
                break
            k += 1
        out.append((start, end + 1))
    return out


def in_gate(n, ranges):
    return any(a <= n <= b for a, b in ranges)


def check(path, base, head):
    new = git("show", f"{head}:{path}")
    ranges = gated_ranges(new)
    diff = git("diff", "-U0", base, head, "--", path).split("\n")
    added, removed, newline = [], [], 0
    for line in diff:
        m = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            newline = int(m.group(1))
            continue
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            added.append((newline, line[1:]))
            newline += 1
        elif line.startswith("-"):
            removed.append(line[1:])
    bad_add = [(n, t) for n, t in added
               if not in_gate(n, ranges) and t.strip() != "" and not t.lstrip().startswith("//")]
    bad_del = [t for t in removed if t.strip() != "" and not t.lstrip().startswith("//")]
    comments = [(n, t) for n, t in added if not in_gate(n, ranges) and (t.strip() == "" or t.lstrip().startswith("//"))]
    print(f"{path}")
    print(f"    {len(added):4d} added lines, {len(removed):4d} deleted")
    print(f"    {len([1 for n, _ in added if in_gate(n, ranges)]):4d} inside a cfg gate")
    print(f"    {len(comments):4d} comment or blank lines outside any gate (compile to nothing)")
    print(f"    {len(bad_add):4d} CODE lines outside a gate, {len(bad_del):4d} code lines deleted")
    for n, t in bad_add:
        print(f"        FAIL +{n}: {t}")
    for t in bad_del:
        print(f"        FAIL -: {t}")
    return not bad_add and not bad_del


def manifests(head):
    ok = True
    core = git("show", f"{head}:zkp-core/Cargo.toml")
    hl = git("show", f"{head}:hashline/Cargo.toml")
    feat = [i for i, l in enumerate(core.split("\n")) if l.startswith("test-observers")]
    print("zkp-core/Cargo.toml")
    sections, cur = {}, None
    for l in core.split("\n"):
        if l.startswith("["):
            cur = l.strip()
        elif "test-observers" in l and not l.lstrip().startswith("#"):
            sections.setdefault(cur, []).append(l)
    print(f"    the feature appears in: {list(sections)}")
    if list(sections) != ["[features]"]:
        print("        FAIL: `test-observers` is named outside [features]")
        ok = False
    if len(feat) != 1:
        print("        FAIL: the feature is not declared exactly once")
        ok = False
    if "default" in core and re.search(r"^default\s*=", core, re.M):
        print("        FAIL: zkp-core declares a default feature set")
        ok = False
    print("hashline/Cargo.toml")
    sections, cur = {}, None
    for l in hl.split("\n"):
        if l.startswith("["):
            cur = l.strip()
        elif "test-observers" in l and not l.lstrip().startswith("#"):
            sections.setdefault(cur, []).append(l)
    print(f"    the feature appears in: {list(sections)}")
    if list(sections) != ["[dev-dependencies]"]:
        print("        FAIL: the feature is switched on outside [dev-dependencies]")
        ok = False
    return ok


def main():
    base, head = sys.argv[1], sys.argv[2]
    print(f"STAGE 36 cfg-gate proof: {base} -> {head}\n")
    ok = all([check(p, base, head) for p in WATCHED])
    print()
    ok = manifests(head) and ok
    print()
    print("RESULT:", "every added line is inside a cfg gate or is a comment, and nothing was deleted" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
