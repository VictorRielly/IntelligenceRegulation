#!/usr/bin/env python3
"""Reviewer tree check for token round 16 (read-only on the lane's trees).

(1) frozen-r16 and my scratch copy against manifest_final_r16.sha256 (file for
file, no extras apart from build output); (2) the manifest list sha256;
(3) frozen-r16 vs frozen-r15 change list (independent of the lane's
r16A_vs_frozen_r15.txt); (4) native R13 frozen tree (bb9eb212...) re-hashed
against its own manifest_frozen.json; (5) the token tree's native files vs
native R13: equal / differ, and token-only files; (6) the native files R13
changed or added relative to R12b, and whether the token tree took R13's bytes.
Writes r16/tree_check_r16.json next to this script.
Usage: tree_check_r16.py [--no-scratch]
"""
import hashlib, json, os, sys

R = "/home/victor/IntelligenceRegulation"
LANE = f"{R}/results/zk60_token_io_r1_20261017"
F16 = f"{LANE}/frozen-r16"
F15 = f"{LANE}/frozen-r15"
SC = f"{R}/ops/zkp-mvp/token-io-review-r16-scratch"
NAT13 = f"{R}/results/zk60_1b_native_20261017/r13/frozen-tree"
NAT13_MAN = f"{R}/results/zk60_1b_native_20261017/r13/manifest_frozen.json"
NAT12B = f"{R}/results/zk60_1b_native_20261017/r12b/frozen-tree"
SKIP_DIRS = {"target", ".git"}


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def manifest(path):
    out = {}
    for line in open(path):
        line = line.rstrip("\n")
        if not line:
            continue
        d, p = line.split("  ", 1)
        out[p] = d
    return out


def walk(root):
    out = {}
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for fn in fns:
            full = os.path.join(dp, fn)
            if os.path.islink(full):
                out[os.path.relpath(full, root)] = "SYMLINK"
                continue
            out[os.path.relpath(full, root)] = sha(full)
    return out


def cmp(man, tree):
    changed = sorted(p for p in man if p in tree and tree[p] != man[p])
    missing = sorted(p for p in man if p not in tree)
    extra = sorted(p for p in tree if p not in man)
    return {"changed": changed, "missing": missing, "extra": extra}


res = {}
mpath = f"{LANE}/manifest_final_r16.sha256"
m16 = manifest(mpath)
res["manifest_files"] = len(m16)
res["manifest_list_sha256"] = sha(mpath)
res["frozen_r16_vs_manifest"] = cmp(m16, walk(F16))
if "--no-scratch" not in sys.argv:
    res["scratch_vs_manifest"] = cmp(m16, walk(SC))
m15 = manifest(f"{LANE}/manifest_final_r15.sha256")
ch = sorted(p for p in m16 if p in m15 and m15[p] != m16[p])
add = sorted(p for p in m16 if p not in m15)
rem = sorted(p for p in m15 if p not in m16)
res["r16_vs_r15"] = {"changed": ch, "added": add, "removed": rem}
# native R13 against its own manifest
n13m = json.load(open(NAT13_MAN))
n13 = walk(NAT13)
res["native_r13_tree_sha256_claimed"] = n13m["tree_sha256"]
res["native_r13_vs_its_manifest"] = cmp(n13m["files"], n13)
# token tree vs native R13
same, differ, token_only = [], [], []
for p, d in m16.items():
    if p in n13:
        (same if n13[p] == d else differ).append(p)
    else:
        token_only.append(p)
res["native_r13_files"] = len(n13)
res["token_native_equal"] = len(same)
res["token_native_differ"] = sorted(differ)
res["token_only"] = sorted(token_only)
res["native_r13_absent_from_token"] = sorted(p for p in n13 if p not in m16)
# R12b -> R13 native changes, and whether the token tree took R13's bytes
n12b = walk(NAT12B)
r13_changed = sorted(p for p in n13 if p not in n12b or n12b[p] != n13[p])
res["native_r12b_to_r13_changed_or_added"] = len(r13_changed)
res["r13_changed_token_equal_r13"] = sorted(p for p in r13_changed if m16.get(p) == n13[p])
res["r13_changed_token_differs"] = sorted(p for p in r13_changed if p in m16 and m16[p] != n13[p])
res["r13_changed_absent_in_token"] = sorted(p for p in r13_changed if p not in m16)
# token files equal to native R12b but not R13 (stale native bytes)
res["token_equal_r12b_not_r13"] = sorted(p for p in m16 if p in n12b and p in n13 and m16[p] == n12b[p] != n13[p])
json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tree_check_r16.json"), "w"), indent=1)
summary = {}
for k, v in res.items():
    if isinstance(v, dict):
        summary[k] = {kk: len(vv) for kk, vv in v.items()}
    elif isinstance(v, list):
        summary[k] = len(v)
    else:
        summary[k] = v
print(json.dumps(summary, indent=1))
print("token differs from native R13:", res["token_native_differ"])
print("R13-changed files where token differs:", res["r13_changed_token_differs"])
print("token == R12b but != R13:", res["token_equal_r12b_not_r13"])
print("native R13 absent from token:", res["native_r13_absent_from_token"])
