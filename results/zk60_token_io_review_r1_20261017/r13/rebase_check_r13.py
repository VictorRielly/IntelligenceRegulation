"""Independent three-way check of the token lane's R8 -> R12b rebase (round 13).

Sides:  n8  = native R8 frozen tree        (results/zk60_1b_native_20261017/r8/frozen-tree)
        n12 = native R12b frozen tree       (results/zk60_1b_native_20261017/r12b/frozen-tree)
        t8  = token tree on R8 (rebase src) (ops/zkp-mvp/token-io, read-only; mtimes reported)
        t13 = token frozen-r13              (results/zk60_token_io_r1_20261017/frozen-r13)

For every path: classify, and for paths both sides changed, run `diff3 -m t8 n8 n12` myself
and diff the result against t13 (the residue = conflict resolutions + round-13 edits).
Writes r13/rebase_check_r13.json and r13/rebase_residue/*.diff.
"""
import difflib
import hashlib
import json
import os
import subprocess

REPO = "/home/victor/IntelligenceRegulation"
N8 = f"{REPO}/results/zk60_1b_native_20261017/r8/frozen-tree"
N12 = f"{REPO}/results/zk60_1b_native_20261017/r12b/frozen-tree"
T8 = f"{REPO}/ops/zkp-mvp/token-io"
T13 = f"{REPO}/results/zk60_token_io_r1_20261017/frozen-r13"
OUT = f"{REPO}/results/zk60_token_io_review_r1_20261017/r13"
SKIP_TOP = ("target",)


def walk(root):
    files = {}
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if not d.startswith("target") and d != ".git"]
        for f in fns:
            p = os.path.join(dp, f)
            rp = os.path.relpath(p, root)
            files[rp] = p
    return files


def h(p):
    if p is None:
        return None
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


n8, n12, t8, t13 = walk(N8), walk(N12), walk(T8), walk(T13)
# the native trees' own scope: files present in either native tree
native = sorted(set(n8) | set(n12))
res = {"classes": {}, "residue": {}, "t8_newest_mtime_utc": None}
import datetime
newest = max(os.path.getmtime(p) for p in t8.values())
res["t8_newest_mtime_utc"] = datetime.datetime.utcfromtimestamp(newest).isoformat() + "Z"
res["t8_files"] = len(t8)
os.makedirs(f"{OUT}/rebase_residue", exist_ok=True)
for k in native:
    a8, a12, b8, b13 = h(n8.get(k)), h(n12.get(k)), h(t8.get(k)), h(t13.get(k))
    native_changed = a8 != a12
    token_changed = b8 != a8
    if not native_changed and not token_changed:
        cls = "untouched" if b13 == a12 else "UNEXPECTED_untouched_but_t13_differs"
    elif native_changed and not token_changed:
        cls = "native_only" if b13 == a12 else "native_only_BUT_t13_differs"
    elif token_changed and not native_changed:
        cls = "token_only_change" if b13 == b8 else "token_only_change_t13_moved"
    else:
        cls = "both_changed"
    res["classes"].setdefault(cls, []).append(k)
    if cls in ("both_changed", "native_only_BUT_t13_differs", "token_only_change_t13_moved",
               "UNEXPECTED_untouched_but_t13_differs"):
        if cls == "both_changed" and all(x is not None for x in (t8.get(k), n8.get(k), n12.get(k))):
            merged = subprocess.run(["diff3", "-m", t8[k], n8[k], n12[k]], capture_output=True, text=True)
            base_text = merged.stdout
            base_label = "my-diff3-merge"
            conflicts = base_text.count("<<<<<<<")
        elif cls == "token_only_change_t13_moved":
            base_text = open(t8[k]).read()
            base_label = "t8"
            conflicts = None
        else:
            base_text = open(n12[k]).read()
            base_label = "n12"
            conflicts = None
        t13_text = open(t13[k]).read() if k in t13 else ""
        d = "".join(difflib.unified_diff(base_text.splitlines(keepends=True), t13_text.splitlines(keepends=True),
                                         f"{base_label}/{k}", f"t13/{k}", n=1))
        add = [l for l in d.splitlines() if l.startswith("+") and not l.startswith("+++")]
        rem = [l for l in d.splitlines() if l.startswith("-") and not l.startswith("---")]
        res["residue"][k] = {"class": cls, "vs": base_label, "my_diff3_conflicts": conflicts,
                             "residue_added": len(add), "residue_removed": len(rem)}
        with open(f"{OUT}/rebase_residue/{k.replace('/', '__')}.diff", "w") as fh:
            fh.write(d)
# token-only files: not in either native tree
tok_only = sorted(set(t13) - set(native))
res["token_only_files_t13"] = len(tok_only)
res["token_only_new_since_t8"] = sorted(set(tok_only) - set(t8))
res["token_only_changed_since_t8"] = sorted(k for k in tok_only if k in t8 and h(t8[k]) != h(t13[k]))
res["counts"] = {k: len(v) for k, v in res["classes"].items()}
json.dump(res, open(f"{OUT}/rebase_check_r13.json", "w"), indent=1)
print(json.dumps({k: v for k, v in res.items() if k != "classes"}, indent=1))
print(json.dumps({k: v for k, v in res["classes"].items() if k not in ("untouched",)}, indent=1))
