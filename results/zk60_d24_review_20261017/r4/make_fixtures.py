"""Review round 4: malicious run directories and exports for the r4 CLI.
Writes only under ops/zkp-mvp/trained-1b-review-r4-scratch/review_out/stack2/."""
import json, os, shutil, subprocess, sys
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r4-scratch/review_out/stack2"
run, exp = f"{S}/run", f"{S}/rev-stack2"
def fresh_run(name):
    d = f"{S}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(run, d, symlinks=True)
    return d
def fresh_export(name):
    d = f"{S}/{name}"
    shutil.rmtree(d, ignore_errors=True)
    shutil.copytree(exp, d, symlinks=True)
    return d
def sparse(path, n):
    if os.path.lexists(path):
        os.remove(path)
    with open(path, "wb") as f:
        f.truncate(n)
seg0 = lambda d: f"{d}/segment-000.bin"
seg1 = lambda d: f"{d}/segment-001.bin"
n0 = os.path.getsize(seg0(run))
# --- segment side
d = fresh_run("run-dos"); os.remove(seg0(d)); os.symlink("/dev/zero", seg0(d))
d = fresh_run("run-sparse"); sparse(seg0(d), 512 << 20)
d = fresh_run("run-fifo"); os.remove(seg0(d)); os.mkfifo(seg0(d))
d = fresh_run("run-short"); os.truncate(seg0(d), n0 - 1)
d = fresh_run("run-long1"); os.truncate(seg0(d), n0 + 1)
d = fresh_run("run-dir"); os.remove(seg0(d)); os.mkdir(seg0(d))
d = fresh_run("run-fifo1"); os.remove(seg1(d)); os.mkfifo(seg1(d))
d = fresh_run("run-hardlink"); os.remove(seg0(d)); os.link(seg0(run), seg0(d))
d = fresh_run("run-symlink-honest"); os.remove(seg0(d)); os.symlink(seg0(run), seg0(d))
d = fresh_run("run-devnull"); os.remove(seg0(d)); os.symlink("/dev/null", seg0(d))
# --- export side (layer_01/wq.bin unless said)
d = fresh_export("exp-arr-zero"); p = f"{d}/layer_01/wq.bin"; os.remove(p); os.symlink("/dev/zero", p)
d = fresh_export("exp-arr-fifo"); p = f"{d}/layer_01/wq.bin"; os.remove(p); os.mkfifo(p)
d = fresh_export("exp-arr-big"); sparse(f"{d}/layer_00/wq.bin", 300 << 20)
# every array of both layers a sparse 255 MiB regular file (under the 256 MiB
# per-array bound, over each array's true length)
d = fresh_export("exp-fat")
names = []
for l in ("layer_00", "layer_01"):
    m = json.load(open(f"{d}/{l}/manifest.json"))
    for a, spec in m["arrays"].items():
        sparse(f"{d}/{l}/{spec['file']}", 255 << 20)
        names.append(f"{l}/{spec['file']}")
print("fixtures written:", sorted(x for x in os.listdir(S)))
print("exp-fat sparse arrays:", len(names))
# (added 20:28 UTC) exp-fat40: every array 40 MiB sparse, so 22 concurrent
# reads (~0.86 GiB) fit under a 1.5 GiB cap and the peak can be measured
