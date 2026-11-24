#!/usr/bin/env python3
"""Build check before merging agy/lean-l68c (co-coordinator, 2026-11-24): an independent rebuild of the branch's 26 new Lean
modules from source, the full root build, and an axiom audit of the top theorems. Nothing under .agy-worktrees is touched and the
main checkout's build products are not relied on for the 26 modules (they are deleted from the private copy and rebuilt).

usage: run_check.py prepare <commit>   export <commit>:formal into the scratch directory, clone the main checkout's formal/.lake
                                       beside it (APFS clone, `cp -c`), delete the 26 modules' and the root's build products
                                       from the clone, write AxiomsL68c.lean
       run_check.py launch <label>     one detached guarded job (class build) that runs `leaf`; writes raw/<label>.*
       run_check.py leaf               (what the guard runs) one "=== STEP" line pair per step
       run_check.py summary <label>    reads raw/<label>.log

Steps of `leaf`: (1) probe: `lake build ZK60Formal.Statements` must be a no-op within 900 s (otherwise the cloned cache is not
valid and the job stops instead of rebuilding Mathlib); (2) `lake build ZK60Formal` (the root now imports the 26 modules);
(3) every one of the 26 modules has an .olean written after this job began; (4) `lake env lean AxiomsL68c.lean`.
Pass: steps 1, 2, 4 exit 0; no line of the root build's output is an error; no warning names one of the 26 files; step 3 finds
26 of 26; the axiom report of every listed theorem names only propext, Classical.choice, Quot.sound.
"""
import os
import re
import subprocess
import sys
import tarfile
import io
import time
from pathlib import Path

REPO = "/Users/victorrielly/IntelligenceRegulation"
HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = REPO + "/scripts/zk60_resource_guard.py"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
SCR = Path("/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/lean-l68c")
F = SCR / "formal"
NEW = re.compile(r"^(HonestShield\w*|RunShieldOpenShell)$")
TOPS = ["shdP_honest_productionReadyL", "shdP_honest_productionReadyL_okPre", "shdP_honest_productionReadyL_concrete",
        "shdP_honestRun_hcover", "shdP_honestRun_parts"]
ALLOWED = {"propext", "Classical.choice", "Quot.sound"}


def new_modules():
    return sorted(p.stem for p in (F / "ZK60Formal").glob("*.lean") if NEW.match(p.stem))


def prepare(commit):
    assert not SCR.exists(), f"{SCR} exists"
    SCR.mkdir(parents=True)
    data = subprocess.run(["git", "archive", commit, "formal"], cwd=REPO, capture_output=True, check=True).stdout
    tarfile.open(fileobj=io.BytesIO(data)).extractall(SCR)
    (SCR / "commit.txt").write_text(commit + "\n")
    subprocess.run(["cp", "-c", "-R", "-p", REPO + "/formal/.lake", str(F / ".lake")], check=True)
    removed = 0
    for sub in ("lib/lean", "ir"):
        base = F / ".lake" / "build" / sub
        for p in list((base / "ZK60Formal").glob("*")) + list(base.glob("ZK60Formal.*")):
            if p.is_file() and (NEW.match(p.name.split(".")[0]) or p.parent == base):
                p.unlink()
                removed += 1
    mods = new_modules()
    (F / "AxiomsL68c.lean").write_text("import ZK60Formal\n" + "".join(f"#print axioms ZK60.HonestShield.{t}\n" for t in TOPS))
    print(f"exported {commit} formal/ to {SCR}; {len(mods)} new modules; removed {removed} build products of them and of the root")
    root = (F / "ZK60Formal.lean").read_text()
    print("root imports of the new modules:", sum(1 for m in mods if f"import ZK60Formal.{m}\n" in root), "of", len(mods))


def leaf():
    env = dict(os.environ, LEAN_NUM_THREADS="4", PYTHONDONTWRITEBYTECODE="1")
    t0 = time.time()
    bad = 0

    def step(name, argv, timeout=None):
        print(f"=== STEP {name} START {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} argv {' '.join(argv[1:])}", flush=True)
        try:
            rc = subprocess.run(argv, env=env, stdin=subprocess.DEVNULL, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            rc = 124
        print(f"=== STEP {name} EXIT {rc} {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}", flush=True)
        return rc

    if step("probe", [LAKE, "-d", str(F), "build", "ZK60Formal.Statements"], timeout=900) != 0:
        print("=== STOP: the cloned cache is not valid for this copy (probe did not finish as a no-op)", flush=True)
        return 1
    if step("root", [LAKE, "-d", str(F), "build", "ZK60Formal"]) != 0:
        bad += 1
    mods = new_modules()
    fresh = [m for m in mods if (F / ".lake/build/lib/lean/ZK60Formal" / (m + ".olean")).exists()
             and (F / ".lake/build/lib/lean/ZK60Formal" / (m + ".olean")).stat().st_mtime >= t0]
    print(f"=== STEP oleans START\nfresh oleans {len(fresh)} of {len(mods)}; missing or old: {sorted(set(mods) - set(fresh))}\n=== STEP oleans EXIT {0 if len(fresh) == len(mods) else 1}", flush=True)
    if len(fresh) != len(mods):
        bad += 1
    if step("axioms", [LAKE, "-d", str(F), "env", "lean", str(F / "AxiomsL68c.lean")]) != 0:
        bad += 1
    return 1 if bad else 0


def launch(label):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        p.unlink(missing_ok=True)
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    (RAW / (label + ".status_pre.txt")).write_text(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n" + st)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "build", "--label", "lean-l68c-merge-" + label, "--need-gib", "24",
           "--cap-gib", "64", "--max-secs", "14400", "--wait-secs", "21600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", sys.executable, "-B", str(Path(__file__).resolve()), "leaf"]
    env = dict(os.environ)
    env.pop("ZK60_GUARD_POLL_SECS", None)
    p = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=open(RAW / (label + ".runner.txt"), "w"),
                         stderr=subprocess.STDOUT, start_new_session=True)
    print("launched", label, "pid", p.pid, "commit", (SCR / "commit.txt").read_text().strip())


def summary(label):
    log = (RAW / (label + ".log")).read_text(errors="replace")
    done = RAW / (label + ".done")
    print("done marker:", done.read_text().strip() if done.exists() else "absent (still running)")
    parts = re.split(r"^=== STEP (\S+) START[^\n]*\n", log, flags=re.M)
    ok = True
    seen = {}
    for i in range(1, len(parts), 2):
        name, body = parts[i], parts[i + 1]
        ex = re.search(r"^=== STEP \S+ EXIT (-?\d+)", body, re.M)
        rc = ex.group(1) if ex else "?"
        seen[name] = rc
        if name == "root":
            errs = [l for l in body.split("\n") if re.search(r"\berror\b", l) and not l.startswith("===")]
            warn = [l for l in body.split("\n") if "warning" in l and re.search(r"HonestShield|RunShieldOpenShell", l)]
            built = len(re.findall(r"Built ZK60Formal\.(?:HonestShield\w*|RunShieldOpenShell)\b", body))
            print(f"root build: exit {rc}; error lines {len(errs)}; warnings naming the new files {len(warn)}; 'Built' lines for new modules {built}")
            for l in (errs + warn)[:8]:
                print("    " + l[:200])
            ok &= rc == "0" and not errs and not warn
        elif name == "axioms":
            reps = re.findall(r"'([^']+)' depends on axioms: \[([^\]]*)\]", body.replace("\n", " "))
            none = re.findall(r"'([^']+)' does not depend on any axioms", body)
            other = sorted({a.strip() for _, ax in reps for a in ax.split(",") if a.strip()} - ALLOWED)
            print(f"axioms: exit {rc}; reports {len(reps) + len(none)} of {len(TOPS)}; axioms outside the three standard ones: {other or 'none'}")
            for n, ax in reps:
                print(f"    {n.split('.')[-1]}: {', '.join(a.strip() for a in ax.split(','))}")
            ok &= rc == "0" and len(reps) + len(none) == len(TOPS) and not other
        else:
            line = next((l for l in body.split("\n") if l.startswith("fresh oleans")), "")
            print(f"{name}: exit {rc} {line}")
            ok &= rc == "0"
    print("CHECK:", "GREEN" if ok and done.exists() and done.read_text().strip() == "0" and set(seen) >= {"probe", "root", "oleans", "axioms"} else "NOT GREEN (or unfinished)")


if __name__ == "__main__":
    if sys.argv[1] == "prepare":
        prepare(sys.argv[2])
    elif sys.argv[1] == "launch":
        launch(sys.argv[2])
    elif sys.argv[1] == "leaf":
        sys.exit(leaf())
    else:
        summary(sys.argv[2])
