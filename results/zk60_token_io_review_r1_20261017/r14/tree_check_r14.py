#!/usr/bin/env python3
"""Reviewer tree check for token round 14 (read-only on the lane's trees).

Checks: (1) frozen-r14 and my scratch copy against manifest_final_r14.sha256
(file for file, no extras apart from build output); (2) the manifest's own list
sha256; (3) frozen-r14 vs frozen-r13 change list (independent of the lane's
r14A_vs_frozen_r13.txt); (4) native files vs native R12b frozen tree.
Writes r14/tree_check_r14.json next to this script.
"""
import hashlib, json, os, sys

R = "/home/victor/IntelligenceRegulation"
LANE = f"{R}/results/zk60_token_io_r1_20261017"
F14 = f"{LANE}/frozen-r14"
F13 = f"{LANE}/frozen-r13"
SC = f"{R}/ops/zkp-mvp/token-io-review-r14-scratch"
NAT = f"{R}/results/zk60_1b_native_20261017/r12b/frozen-tree"
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
mpath = f"{LANE}/manifest_final_r14.sha256"
m14 = manifest(mpath)
res["manifest_files"] = len(m14)
res["manifest_list_sha256"] = sha(mpath)
res["frozen_r14_vs_manifest"] = cmp(m14, walk(F14))
res["scratch_vs_manifest"] = cmp(m14, walk(SC))
m13 = manifest(f"{LANE}/manifest_final_r13.sha256")
res["r13_manifest_list_sha256"] = sha(f"{LANE}/manifest_final_r13.sha256")
ch = sorted(p for p in m14 if p in m13 and m13[p] != m14[p])
add = sorted(p for p in m14 if p not in m13)
rem = sorted(p for p in m13 if p not in m14)
res["r14_vs_r13"] = {"changed": ch, "added": add, "removed": rem}
# native: which files of the token tree that exist in native R12b differ
nat = walk(NAT)
same, diff = 0, []
for p, d in m14.items():
    if p in nat:
        if nat[p] == d:
            same += 1
        else:
            diff.append(p)
res["native_r12b_files"] = len(nat)
res["token_files_in_native_equal"] = same
res["token_files_in_native_differ"] = sorted(diff)
# which of those native-differing files changed in r14
res["native_differ_changed_in_r14"] = sorted(set(diff) & set(ch))
json.dump(res, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "tree_check_r14.json"), "w"), indent=1)
print(json.dumps({k: (v if not isinstance(v, dict) else {kk: len(vv) for kk, vv in v.items()}) for k, v in res.items()
                  if k not in ("token_files_in_native_differ", "native_differ_changed_in_r14")}, indent=1))
print("native differ:", len(diff), "of which changed in r14:", res["native_differ_changed_in_r14"])
print("r14 vs r13 changed:", ch, "added:", add)
