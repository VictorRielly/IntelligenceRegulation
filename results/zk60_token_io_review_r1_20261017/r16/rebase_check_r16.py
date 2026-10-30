#!/usr/bin/env python3
"""Reviewer's independent rebase check (token round 16).

For each native file the token tree touches, compare the token lane's delta
over native at r15 (frozen-r15 vs native R12b) with its delta at r16
(frozen-r16 vs native R13), as multisets of added / removed lines. Lines in
the r16 delta that were not in the r15 delta are the round's new native
edits (or conflict resolutions); lines of the r15 delta lost at r16 are
token edits dropped by the rebase. Also: every native R13 change (R12b ->
R13) must be present in the token tree: R13's added lines that are absent
from r16 are reported. Writes rebase_check_r16.json.
"""
import collections, difflib, json, os

R = "/home/victor/IntelligenceRegulation"
LANE = f"{R}/results/zk60_token_io_r1_20261017"
F15, F16 = f"{LANE}/frozen-r15", f"{LANE}/frozen-r16"
N12, N13 = f"{R}/results/zk60_1b_native_20261017/r12b/frozen-tree", f"{R}/results/zk60_1b_native_20261017/r13/frozen-tree"
tc = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tree_check_r16.json")))


def lines(p):
    try:
        return open(p, encoding="utf-8").read().splitlines()
    except FileNotFoundError:
        return []


def delta(a, b):
    plus, minus = collections.Counter(), collections.Counter()
    for l in difflib.ndiff(a, b):
        if l.startswith("+ "):
            plus[l[2:].strip()] += 1
        elif l.startswith("- "):
            minus[l[2:].strip()] += 1
    return plus, minus


def fast_delta(a, b):
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    plus, minus = collections.Counter(), collections.Counter()
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op in ("replace", "delete"):
            for l in a[i1:i2]:
                minus[l.strip()] += 1
        if op in ("replace", "insert"):
            for l in b[j1:j2]:
                plus[l.strip()] += 1
    return plus, minus


out = {}
for p in tc["token_native_differ"]:
    t15, n12, t16, n13 = (lines(os.path.join(x, p)) for x in (F15, N12, F16, N13))
    p15, m15 = fast_delta(n12, t15)
    p16, m16 = fast_delta(n13, t16)
    pr, mr = fast_delta(n12, n13)
    new_plus = p16 - p15
    lost_plus = p15 - p16
    new_minus = m16 - m15
    lost_minus = m15 - m16
    # R13's own additions missing from the token tree
    t16c = collections.Counter(l.strip() for l in t16)
    r13_missing = [l for l, c in pr.items() if l and t16c[l] < c]
    out[p] = {
        "r15_delta": [sum(p15.values()), sum(m15.values())],
        "r16_delta": [sum(p16.values()), sum(m16.values())],
        "new_plus": sorted(l for l in new_plus.elements() if l),
        "lost_plus": sorted(l for l in lost_plus.elements() if l),
        "new_minus": sorted(l for l in new_minus.elements() if l),
        "lost_minus": sorted(l for l in lost_minus.elements() if l),
        "r13_additions_missing_in_token": r13_missing,
    }
json.dump(out, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "rebase_check_r16.json"), "w"), indent=1)
for p, v in out.items():
    print(f"== {p}: r15 delta +{v['r15_delta'][0]}/-{v['r15_delta'][1]}, r16 delta +{v['r16_delta'][0]}/-{v['r16_delta'][1]}; "
          f"new+ {len(v['new_plus'])} lost+ {len(v['lost_plus'])} new- {len(v['new_minus'])} lost- {len(v['lost_minus'])} R13-missing {len(v['r13_additions_missing_in_token'])}")
