"""Reviewer tree checks for token round 13 (R-C2).

1. scratch copy (and frozen copy) == manifest_final_r13.sha256 file for file; list sha256 recomputed.
2. native R12b frozen tree == its manifest_frozen.json (tree hash recomputed).
3. every R12b file vs the token tree: equal / differs / missing; R12b-absent token files listed.
4. for every differing file, a unified diff is written to r13/native_diffs/ for reading.

Usage: python3 tree_check_r13.py
"""
import difflib
import hashlib
import json
import os

REPO = "/home/victor/IntelligenceRegulation"
TOK = f"{REPO}/results/zk60_token_io_r1_20261017"
FROZEN = f"{TOK}/frozen-r13"
SCRATCH = f"{REPO}/ops/zkp-mvp/token-io-review-r13-scratch"
MAN = f"{TOK}/manifest_final_r13.sha256"
R12B = f"{REPO}/results/zk60_1b_native_20261017/r12b/frozen-tree"
R12B_MAN = f"{REPO}/results/zk60_1b_native_20261017/r12b/manifest_frozen.json"
OUT = f"{REPO}/results/zk60_token_io_review_r1_20261017/r13"


def walk(root):
    files = {}
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if not d.startswith("target") and d != ".git"]
        for f in fns:
            p = os.path.join(dp, f)
            rp = os.path.relpath(p, root)
            if os.path.islink(p):
                files[rp] = "SYMLINK"
                continue
            with open(p, "rb") as fh:
                files[rp] = hashlib.sha256(fh.read()).hexdigest()
    return files


def read_manifest(path):
    want = {}
    raw = open(path, "rb").read()
    for line in raw.decode().splitlines():
        if not line.strip():
            continue
        h, p = line.split("  ", 1)
        want[p] = h
    return want, hashlib.sha256(raw).hexdigest()


report = {}
want, list_sha = read_manifest(MAN)
report["manifest_list_sha256"] = list_sha
report["manifest_count"] = len(want)
for name, root in (("frozen", FROZEN), ("scratch", SCRATCH)):
    got = walk(root)
    report[name] = {
        "found": len(got),
        "extra": sorted(set(got) - set(want)),
        "missing": sorted(set(want) - set(got)),
        "differ": sorted(k for k in set(got) & set(want) if got[k] != want[k]),
    }

m = json.load(open(R12B_MAN))
r12b_files = m["files"]
r12b_got = walk(R12B)
lines = "".join(f"{k}  {r12b_files[k]}\n" for k in sorted(r12b_files))
lines1 = "".join(f"{k} {r12b_files[k]}\n" for k in sorted(r12b_files))
report["r12b"] = {
    "manifest_count": len(r12b_files),
    "found": len(r12b_got),
    "tree_sha256_manifest": m["tree_sha256"],
    "tree_sha256_recomputed": [hashlib.sha256(lines.encode()).hexdigest(),
                               hashlib.sha256(lines1.encode()).hexdigest()],
    "differ_from_manifest": sorted(k for k in r12b_files if r12b_got.get(k) != r12b_files[k]),
    "extra": sorted(set(r12b_got) - set(r12b_files)),
}

equal, differ, missing = [], [], []
for k in sorted(r12b_files):
    if k not in want:
        missing.append(k)
    elif want[k] == r12b_files[k]:
        equal.append(k)
    else:
        differ.append(k)
token_only = sorted(set(want) - set(r12b_files))
report["native_vs_token"] = {
    "r12b_files": len(r12b_files),
    "equal": len(equal),
    "differ": differ,
    "missing_in_token": missing,
    "token_only_count": len(token_only),
    "token_only": token_only,
}
os.makedirs(f"{OUT}/native_diffs", exist_ok=True)
for k in differ:
    a = open(os.path.join(R12B, k), encoding="utf-8").read().splitlines(keepends=True)
    b = open(os.path.join(FROZEN, k), encoding="utf-8").read().splitlines(keepends=True)
    d = "".join(difflib.unified_diff(a, b, f"r12b/{k}", f"token-r13/{k}", n=2))
    added = sum(1 for l in d.splitlines() if l.startswith("+") and not l.startswith("+++"))
    removed = sum(1 for l in d.splitlines() if l.startswith("-") and not l.startswith("---"))
    report["native_vs_token"].setdefault("diffstat", {})[k] = {"added": added, "removed": removed}
    with open(f"{OUT}/native_diffs/{k.replace('/', '__')}.diff", "w") as fh:
        fh.write(d)
json.dump(report, open(f"{OUT}/tree_check_r13.json", "w"), indent=1)
print(json.dumps({k: (v if k != "native_vs_token" else {kk: vv for kk, vv in v.items() if kk != "token_only"})
                  for k, v in report.items()}, indent=1))
