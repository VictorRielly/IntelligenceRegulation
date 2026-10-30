#!/usr/bin/env python3
"""Token round 19b: a Python mirror of the planned R19-2 checks, run on a tree BEFORE the Rust tests exist, to predict
what they find on the real path (read only).

usage: mirror19b.py HASHLINE_DIR

  1. the module graph (round 19's mirror, r19/tools/mirror_follower.py's functions, unchanged);
  2. the TAIL check: in every file a census scan cuts (the graph's files plus the scans' extra files), every top-level
     item after the first "\\n#[cfg(test)]\\nmod tests {" must carry `#[cfg(test)]` among its outer attributes;
  3. the INCLUDE check: an `include!` (any path prefix, `r#include` too) in a graph file's production text outside a
     `#[cfg(test)]` inline module;
  4. every .rs file under src/private_block/ that is NOT in the graph (the optional directory check's list).
"""
import os, sys
ROOT = sys.argv[1]
MIRROR = "/home/victor/IntelligenceRegulation/results/zk60_token_io_r1_20261017/r19/tools/mirror_follower.py"
code = open(MIRROR).read().split("\nfiles, edges = graph(")[0]
ns = {}
argv = sys.argv
sys.argv = [MIRROR, ROOT]
exec(compile(code, MIRROR, "exec"), ns)
sys.argv = argv
lex, graph, prod, src = ns["lex"], ns["graph"], ns["prod"], ns["src"]
CUT = "\n#[cfg(test)]\nmod tests {"


def tail_items(text):
    k = text.find(CUT)
    if k < 0:
        return []
    t = lex(text[k + 1:])
    P = lambda i, ch: 0 <= i < len(t) and t[i][0] == 'Punct' and t[i][1] == ch
    items, i = [], 0
    while i < len(t):
        start, test, attrs = i, False, []
        while P(i, '#') and P(i + 1, '['):
            d, j = 0, i + 1
            while True:
                if P(j, '['): d += 1
                elif P(j, ']'):
                    d -= 1
                    if d == 0: break
                j += 1
            body = [x[:2] for x in t[i + 2:j]]
            attrs.append(body)
            if body == [('Ident', 'cfg'), ('Punct', '('), ('Ident', 'test'), ('Punct', ')')]: test = True
            i = j + 1
        first = t[i] if i < len(t) else None
        d = 0
        while i < len(t):
            if t[i][0] == 'Punct' and t[i][1] in '([{': d += 1
            elif t[i][0] == 'Punct' and t[i][1] in ')]':
                d -= 1
            elif P(i, '}'):
                d -= 1
                if d == 0:
                    i += 1
                    if P(i, ';'): i += 1
                    break
            elif P(i, ';') and d == 0:
                i += 1
                break
            i += 1
        items.append((t[start][2] + text[:k + 1].count("\n"), test, first[:2] if first else None))
    return items


def includes(text):
    t = lex(text)
    P = lambda i, ch: 0 <= i < len(t) and t[i][0] == 'Punct' and t[i][1] == ch
    out, stack, pending = [], [], None
    for i, tok in enumerate(t):
        if P(i, '{'):
            outer = any(s for s in stack)
            if pending is not None and pending[0] == i:
                stack.append(pending[1] or outer)
            else:
                stack.append(outer)
            pending = None
            continue
        if P(i, '}'):
            stack.pop(); continue
        if tok[0] == 'Ident' and tok[1] == 'mod' and P(i + 2, '{'):
            # was it #[cfg(test)]? walk back over attributes as decls() does
            b, test = i, False
            if b > 0 and t[b - 1][:2] == ('Ident', 'pub'): b -= 1
            while P(b - 1, ']'):
                k = ns["match_back"](t, b - 1, '[', ']')
                if [x[:2] for x in t[k + 1:b - 1]] == [('Ident', 'cfg'), ('Punct', '('), ('Ident', 'test'), ('Punct', ')')]: test = True
                b = k - 1
            pending = (i + 2, test)
        if tok[0] == 'Ident' and tok[1] in ('include', 'r#include') and P(i + 1, '!'):
            out.append((tok[2], any(s for s in stack)))
    return out


files, edges = graph(["src/private_block.rs", "src/private_seam.rs"])
print(len(files), "files;", len(edges), "edges")
extra = ["src/private_block/run_capture.rs", "src/private_block/run_statement_file.rs", "src/private_block/plane_index.rs",
         "src/private_block/boundary.rs", "../zkp-core/src/rng.rs", "src/private_block/hash_domain.rs"]
bad = 0
for f in [x for x, _ in files] + extra:
    text = src(f)
    for line, test, first in tail_items(text):
        if not test:
            bad += 1
            print("TAIL-NON-TEST", f, line, first)
    n = len(tail_items(text))
    if n > 1:
        print("TAIL", f, n, "items, all #[cfg(test)]" if all(x[1] for x in tail_items(text)) else "")
for f, _ in files:
    for line, in_test in includes(prod(src(f))):
        print("INCLUDE", f, line, "in a #[cfg(test)] module" if in_test else "PRODUCTION")
print("tail non-test items:", bad)
gf = set(f for f, _ in files)
allrs = []
for d, _, fs in os.walk(os.path.join(ROOT, "src/private_block")):
    for x in fs:
        if x.endswith(".rs"):
            allrs.append(os.path.relpath(os.path.join(d, x), ROOT))
off = sorted(x for x in allrs if x not in gf)
print(len(allrs), ".rs under src/private_block;", len(off), "not in the graph")
for x in off:
    print("OFFGRAPH", x)
