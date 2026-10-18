"""Review round 5: verifier-copy fixtures (no seq_*) for the R5b CLI.
Writes only under ops/zkp-mvp/trained-1b-review-r5-scratch/review_out/stack2/."""
import json, os, shutil
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r5-scratch/review_out/stack2"
src = f"{S}/rev-stack2"
def copy_export(name, with_seq):
    d = f"{S}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(src, d, symlinks=True, ignore=None if with_seq else shutil.ignore_patterns("seq_*"))
    return d
def sparse(p, n):
    if os.path.lexists(p):
        os.remove(p)
    with open(p, "wb") as f:
        f.truncate(n)
def fat(d, n):
    k = 0
    for l in ("layer_00", "layer_01"):
        m = json.load(open(f"{d}/{l}/manifest.json"))
        for a, spec in m["arrays"].items():
            sparse(f"{d}/{l}/{spec['file']}", n); k += 1
    return k
v = copy_export("rev-stack2-v", False)
for name, with_seq in (("exp-fat-v", False), ("exp-fat-p", True), ("exp-fat40-v", False)):
    d = copy_export(name, with_seq)
    fat(d, (40 << 20) if "40" in name else (255 << 20))
d = copy_export("exp-arr-zero-v", False); p = f"{d}/layer_01/wq.bin"; os.remove(p); os.symlink("/dev/zero", p)
d = copy_export("exp-arr-fifo-v", False); p = f"{d}/layer_01/wq.bin"; os.remove(p); os.mkfifo(p)
d = copy_export("exp-arr-big-v", False); sparse(f"{d}/layer_00/wq.bin", 300 << 20)
d = copy_export("exp-profile-fifo-v", False); os.remove(f"{d}/profile.json"); os.mkfifo(f"{d}/profile.json")
d = copy_export("exp-manifest-zero-v", False); p = f"{d}/layer_00/manifest.json"; os.remove(p); os.symlink("/dev/zero", p)
# a misdeclared shape: wk declared [384, 384] instead of [128, 384] (same dtype)
d = copy_export("exp-misdeclared-v", False)
mp = f"{d}/layer_00/manifest.json"
m = open(mp).read()
m2 = m.replace('"wk": {"file": "wk.bin", "dtype": "int8", "shape": [128, 384]', '"wk": {"file": "wk.bin", "dtype": "int8", "shape": [384, 384]')
assert m2 != m, "wk entry not found"
open(mp, "w").write(m2)
# expected.bin as a FIFO in a copy of the honest run (the policy read)
r = f"{S}/run-expected-fifo"
shutil.rmtree(r, ignore_errors=True); shutil.copytree(f"{S}/run", r, symlinks=True)
os.remove(f"{r}/statement/expected.bin"); os.mkfifo(f"{r}/statement/expected.bin")
print(sorted(os.listdir(S)))
# (applied after the run above, 00:17 UTC) exp-misdeclared-v/profile.json:
# the layers' manifest_sha256 entries stripped, so the misdeclared wk shape
# reaches the array reader's pre-read dtype/shape check
