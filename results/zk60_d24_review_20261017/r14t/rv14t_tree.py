"""D24 review R14-tier: re-hash the candidate tree against FINAL_SOURCE.json,
diff it against the F1/F2 base tree, and confirm the patch is the whole delta."""
import difflib
import hashlib
import json
import sys
from pathlib import Path

SOL = Path("/Users/victorrielly/IntelligenceRegulation/results/zk60_sol_20261031")
TIER = SOL / "r14-security-tier"
BASE = SOL / "r14-followup/source-tree"
TREE = TIER / "source-tree"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def files(root):
    return {str(p.relative_to(root)): p for p in root.rglob("*") if p.is_file()}


pin = json.loads((TIER / "FINAL_SOURCE.json").read_text())
tree = files(TREE)
base = files(BASE)
pinned = pin["files"]
mismatch = [k for k, v in pinned.items() if k not in tree or sha(tree[k]) != v]
extra = sorted(set(tree) - set(pinned))
changed = sorted(k for k in set(tree) & set(base) if sha(tree[k]) != sha(base[k]))
added = sorted(set(tree) - set(base))
removed = sorted(set(base) - set(tree))
# Rebuild a unified diff of code files and compare its touched-file set with the patch
patch = (TIER / "FINAL_SECURITY_TIER.patch").read_text()
patch_files = sorted({line[6:].strip() for line in patch.splitlines() if line.startswith("+++ b/")})
code_delta = sorted(f for f in changed + added if f.startswith("hashline/") and not f.startswith("hashline/target"))
# Per-file: does applying the patch's +/- lines reproduce the tree? Check by
# regenerating a diff and comparing the set of +/- lines per file.
def plusminus(text):
    out = {}
    cur = None
    for line in text.splitlines():
        if line.startswith("+++ b/"):
            cur = line[6:].strip(); out[cur] = ([], [])
        elif line.startswith("--- "):
            continue
        elif cur and line.startswith("+"):
            out[cur][0].append(line[1:])
        elif cur and line.startswith("-"):
            out[cur][1].append(line[1:])
    return out
pm = plusminus(patch)
line_mismatch = []
for f in code_delta:
    a = base[f].read_text().splitlines() if f in base else []
    b = tree[f].read_text().splitlines()
    plus = [l[1:] for l in difflib.unified_diff(a, b, lineterm="", n=0) if l.startswith("+") and not l.startswith("+++")]
    minus = [l[1:] for l in difflib.unified_diff(a, b, lineterm="", n=0) if l.startswith("-") and not l.startswith("---")]
    got = pm.get(f, ([], []))
    if sorted(plus) != sorted(got[0]) or sorted(minus) != sorted(got[1]):
        line_mismatch.append(f)
res = {"pinned": len(pinned), "tree_files": len(tree), "pin_mismatches": mismatch, "extra_unpinned": extra,
       "base_files": len(base), "changed_vs_base": changed, "added_vs_base": added, "removed_vs_base": removed,
       "patch_files": patch_files, "code_delta_equals_patch_files": code_delta == patch_files,
       "patch_line_mismatches": line_mismatch}
json.dump(res, open(sys.argv[1], "w"), indent=1)
print(json.dumps(res, indent=1))
