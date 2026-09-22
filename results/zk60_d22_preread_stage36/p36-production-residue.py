#!/usr/bin/env python3
"""THE PRODUCTION RESIDUE: an independent re-derivation of stage 36's
production-identity claim, by a different method from the lane's script.

The lane's `z36-cfg-gate-proof.py` classifies the DIFF's added lines.  This
program never looks at the diff.  It takes each file WHOLE at both commits,
deletes every `#[cfg(test)]` / `#[cfg(any(test, feature = "test-observers"))]`
item together with the attribute that gates it, deletes comments and blank
lines, and compares what is left -- line by line, and by digest.

If the two residues are equal then the delta cannot have changed, moved,
reordered or deleted a single line of production code: a strictly stronger
statement than "every ADDED line is inside a gate", because it also covers
lines that were not added.

Brace tracking ignores braces inside string literals, char literals, line
comments and block comments; the walk asserts depth 0 at end of file, so a
mis-parse cannot pass silently.
"""
import hashlib
import re
import subprocess
import sys

WT = "/home/victor/wt-zk60-block125m-review"
GATES = (
    '#[cfg(test)]',
    '#[cfg(any(test, feature = "test-observers"))]',
)
FILES = [
    "zkp-core/src/rng.rs",
    "zkp-core/src/transcript.rs",
    "hashline/src/private_block/protocol.rs",
    "hashline/src/private_block.rs",   # pinned, moved, NOT covered by the lane's script
]


def text(commit, path):
    r = subprocess.run(["git", "--no-pager", "-C", WT, "show", f"{commit}:{path}"],
                       capture_output=True)
    if r.returncode != 0:
        raise SystemExit(f"no blob {commit}:{path}")
    return r.stdout.decode()


def strip_line(line, in_block):
    """Return (code_only_text, in_block_after, is_comment_only)."""
    out = []
    i = 0
    n = len(line)
    saw_code = False
    while i < n:
        if in_block:
            j = line.find("*/", i)
            if j < 0:
                return "".join(out), True, not saw_code
            i = j + 2
            in_block = False
            continue
        c = line[i]
        if c == '/' and i + 1 < n and line[i + 1] == '/':
            break
        if c == '/' and i + 1 < n and line[i + 1] == '*':
            in_block = True
            i += 2
            continue
        if c == 'r' and i + 1 < n and line[i + 1] in '"#':
            m = re.match(r'r(#*)"', line[i:])
            if m:
                hashes = m.group(1)
                end = line.find('"' + hashes, i + len(m.group(0)))
                saw_code = True
                if end < 0:
                    return "".join(out), in_block, False
                i = end + 1 + len(hashes)
                continue
        if c == '"':
            i += 1
            while i < n:
                if line[i] == '\\':
                    i += 2
                    continue
                if line[i] == '"':
                    i += 1
                    break
                i += 1
            saw_code = True
            continue
        if c == "'":
            m = re.match(r"'(\\.|[^\\'])'", line[i:])
            if m:
                i += len(m.group(0))
                saw_code = True
                continue
        if not c.isspace():
            saw_code = True
        out.append(c)
        i += 1
    return "".join(out), in_block, not saw_code


def analyse(src, path):
    lines = src.split("\n")
    code, comment_only, in_block = [], [], False
    for ln in lines:
        c, in_block, conly = strip_line(ln, in_block)
        code.append(c)
        comment_only.append(conly and ln.strip() != "")
    gated = [False] * len(lines)
    i = 0
    while i < len(lines):
        t = lines[i].strip()
        if t in GATES:
            # the attribute, any further attributes/doc comments, then the item
            start = i
            j = i + 1
            while j < len(lines) and (lines[j].strip().startswith("#[")
                                      or lines[j].strip().startswith("//")
                                      or lines[j].strip() == ""):
                j += 1
            if j >= len(lines):
                raise SystemExit(f"{path}: a gate at line {i+1} gates nothing")
            # find the end of the gated item
            depth = 0
            opened = False
            k = j
            while k < len(lines):
                for ch in code[k]:
                    if ch == "{":
                        depth += 1
                        opened = True
                    elif ch == "}":
                        depth -= 1
                if opened and depth == 0:
                    break
                if not opened and code[k].rstrip().endswith(";"):
                    break
                k += 1
            if k >= len(lines):
                raise SystemExit(f"{path}: unterminated gated item at line {j+1}")
            for m in range(start, k + 1):
                gated[m] = True
            i = k + 1
            continue
        i += 1
    # sanity: the whole file's braces balance under our stripping
    depth = 0
    for c in code:
        depth += c.count("{") - c.count("}")
    if depth != 0:
        raise SystemExit(f"{path}: brace walk ended at depth {depth}; the parse is not trustworthy")
    residue = [(k + 1, lines[k]) for k in range(len(lines))
               if not gated[k] and not comment_only[k] and lines[k].strip() != ""]
    return lines, gated, comment_only, residue


def digest(residue):
    return hashlib.sha256("\n".join(t for _, t in residue).encode()).hexdigest()


ok = True
for path in FILES:
    pre_src, post_src = text("fee1a8d", path), text("29cba9a", path)
    pl, pg, pc, pres = analyse(pre_src, path + "@fee1a8d")
    ql, qg, qc, qres = analyse(post_src, path + "@29cba9a")
    dp, dq = digest(pres), digest(qres)
    same = [t for _, t in pres] == [t for _, t in qres]
    print(f"{path}")
    print(f"   lines            {len(pl):>6} -> {len(ql):>6}   ({len(ql)-len(pl):+d})")
    print(f"   gated lines      {sum(pg):>6} -> {sum(qg):>6}")
    print(f"   comment/blank    {sum(pc):>6} -> {sum(qc):>6}")
    print(f"   PRODUCTION lines {len(pres):>6} -> {len(qres):>6}")
    print(f"   residue sha256   {dp[:16]} -> {dq[:16]}   {'IDENTICAL' if same else '*** DIFFERS ***'}")
    if not same:
        ok = False
        import difflib
        for d in list(difflib.unified_diff([t for _, t in pres], [t for _, t in qres],
                                           "pre", "post", lineterm="", n=1))[:40]:
            print("      ", d)
    print()

print("VERDICT:", "every watched file's production residue is byte-identical across the delta"
      if ok else "A PRODUCTION LINE MOVED")
sys.exit(0 if ok else 1)
