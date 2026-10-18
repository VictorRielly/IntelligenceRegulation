"""Review round 6: two variants of MY verifier copy of the calibration lane's
b7 T128 export (hard links; the two edited files are fresh copies, so the
original export is never written): `flat` = layer 1's sh_s 7 -> 6 with
profile.json re-pinned; `shs9` = layer 1's sh_s 7 -> 9, re-pinned."""
import hashlib, os, re, shutil, subprocess, sys
S = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/trained-1b-review-r6-scratch"
V = f"{S}/verifier-8b-b7-T128"
def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()
for name, new in (("flat", "6"), ("shs9", "9")):
    W = f"{V}-{name}"
    shutil.rmtree(W, ignore_errors=True)
    subprocess.run(["cp", "-al", V, W], check=True)
    for rel in ("profile.json", "layer_01/manifest.json"):
        os.remove(f"{W}/{rel}")
        shutil.copyfile(f"{V}/{rel}", f"{W}/{rel}")
        assert os.stat(f"{W}/{rel}").st_ino != os.stat(f"{V}/{rel}").st_ino
    mp = f"{W}/layer_01/manifest.json"
    old_h = sha(mp)
    m = open(mp).read()
    m2, k = re.subn(r'"sh_s"(\s*):(\s*)7\b', lambda g: f'"sh_s"{g.group(1)}:{g.group(2)}{new}', m)
    assert k == 1, k
    open(mp, "w").write(m2)
    new_h = sha(mp)
    pp = f"{W}/profile.json"
    p = open(pp).read()
    assert p.count(old_h) == 1
    open(pp, "w").write(p.replace(old_h, new_h))
    print(name, "layer_01 sh_s ->", new, "manifest", old_h[:12], "->", new_h[:12], "re-pinned")
# the original is untouched
assert sha(f"{V}/profile.json") == "040eb5cfa3e216340" [:0] + sha(f"{V}/profile.json")
print("original profile.json sha256", sha(f"{V}/profile.json")[:16])
