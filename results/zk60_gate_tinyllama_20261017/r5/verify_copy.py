#!/usr/bin/env python3
"""Verify the gate's R5 copy against the native lane's frozen manifest:
every listed file present with its digest, no unlisted file (outside
target dirs), and the tree digest reproduced if its formula is one of the
obvious ones.   python3 verify_copy.py <manifest.json> <root> [<out.json>]"""
import hashlib, json, os, sys
man = json.load(open(sys.argv[1])); root = sys.argv[2]
bad, missing = [], []
for p, d in sorted(man["files"].items()):
    f = os.path.join(root, p)
    if not os.path.exists(f):
        missing.append(p); continue
    if hashlib.sha256(open(f, "rb").read()).hexdigest() != d:
        bad.append(p)
on_disk = set()
for dp, dn, fn in os.walk(root):
    dn[:] = [x for x in dn if not x.startswith("target")]
    for n in fn:
        on_disk.add(os.path.relpath(os.path.join(dp, n), root))
extra = sorted(on_disk - set(man["files"]))
lines = "".join(f"{d}  {p}\n" for p, d in sorted(man["files"].items()))
cands = {
    "sha256 of '<digest>  <path>\\n' lines sorted by path": hashlib.sha256(lines.encode()).hexdigest(),
    "sha256 of '<path>  <digest>\\n'": hashlib.sha256("".join(f"{p}  {d}\n" for p, d in sorted(man["files"].items())).encode()).hexdigest(),
    "sha256 of json.dumps(files, sort_keys=True)": hashlib.sha256(json.dumps(man["files"], sort_keys=True).encode()).hexdigest(),
}
tree = [k for k, v in cands.items() if v == man["tree_sha256"]]
out = {"manifest": sys.argv[1], "root": root, "listed": len(man["files"]), "digest_mismatch": bad,
       "missing": missing, "unlisted": extra, "tree_sha256_declared": man["tree_sha256"],
       "tree_sha256_formula_reproduced": tree, "ok": not bad and not missing and not extra}
if len(sys.argv) > 3:
    json.dump(out, open(sys.argv[3], "w"), indent=1, sort_keys=True)
print(json.dumps({k: (v if not isinstance(v, list) or len(v) < 6 else f"{len(v)} items") for k, v in out.items()}, indent=1))
sys.exit(0 if out["ok"] else 1)
