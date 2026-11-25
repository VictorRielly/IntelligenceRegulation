#!/usr/bin/env python3
"""Build check before merging agy/lean-l69-hooks-zk (co-coordinator, 2026-11-25). Same method as
results/zk60_lean_l68c_merge_20261124/run_check.py: an independent rebuild from source, in a private copy, of every module of
the honest-prover family (the 26 merged on Nov 24, one of which this branch modifies, and the 15 this branch adds), the full root
build, and an axiom audit of the top theorems. Nothing under .agy-worktrees is touched, and the main checkout's build products
are not relied on for those modules (they are deleted from the private copy and rebuilt).

usage: run_check.py prepare <commit>   export <commit>:formal into the scratch directory, clone the main checkout's formal/.lake
                                       beside it (APFS clone, `cp -c`), delete the family's and the root's build products from
                                       the clone, write AxiomsL69.lean, print the source scan
       run_check.py launch <label>     one detached guarded job (class build) that runs `leaf`; writes raw/<label>.*
       run_check.py leaf               (what the guard runs) one "=== STEP" line pair per step
       run_check.py summary <label>    reads raw/<label>.log

Steps of `leaf`: (1) probe: `lake build ZK60Formal.Statements` must be a no-op within 900 s (otherwise the cloned cache is not
valid and the job stops instead of rebuilding Mathlib); (2) `lake build ZK60Formal`; (3) every module of the family has an
.olean written after this job began; (4) `lake env lean AxiomsL69.lean`.

PASS RULE, written before the first run:
  - steps 1, 2 and 4 exit 0; no line of the root build's output is an error;
  - step 3 finds every module of the family;
  - the axiom report of every listed name is present and names only propext, Classical.choice, Quot.sound (so no sorryAx);
  - no warning of the root build contains the word sorry.
Other warnings that name a file of the family are counted and their first lines printed; they do not fail the check. (The
Nov 24 check required none. The author disclosed before this run that three of the new modules give unused-variable,
unused-tactic and unused-simp-argument linter warnings, so the rule is changed here, in advance, and the count is reported.)
The check says nothing about whether the definitions mean what the documents say; that is a read, not a build.
"""
import io
import os
import re
import subprocess
import sys
import tarfile
import time
from pathlib import Path

REPO = "/Users/victorrielly/IntelligenceRegulation"
HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = REPO + "/scripts/zk60_resource_guard.py"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
SCR = Path("/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/lean-l69")
F = SCR / "formal"
FAM = re.compile(r"^(HonestShield\w*|RunShieldOpenShell)$")
TOPS = ["shdP_honest_productionReadyL", "shdP_honest_productionReadyL_okPre", "shdP_honest_productionReadyL_concrete",
        "shdP_honestRun_hcover", "shdP_honestRun_parts", "shdP_honest_productionReadyL_complete", "shdP_zkProgWitness"]
ALLOWED = {"propext", "Classical.choice", "Quot.sound"}
SCAN = ["sorry", "admit", "axiom", "native_decide", "unsafe", "implemented_by", "opaque", "maxHeartbeats", "maxRecDepth"]


def family():
    return sorted(p.stem for p in (F / "ZK60Formal").glob("*.lean") if FAM.match(p.stem))


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
            if p.is_file() and (FAM.match(p.name.split(".")[0]) or p.parent == base):
                p.unlink()
                removed += 1
    mods = family()
    (F / "AxiomsL69.lean").write_text("import ZK60Formal\n" + "".join(f"#print axioms ZK60.HonestShield.{t}\n" for t in TOPS))
    print(f"exported {commit} formal/ to {SCR}; {len(mods)} modules in the family; removed {removed} build products of them and of the root")
    root = (F / "ZK60Formal.lean").read_text()
    print("root imports of the family:", sum(1 for m in mods if f"import ZK60Formal.{m}\n" in root), "of", len(mods))
    # source scan: whole-word hits outside line comments, per token, over the family's sources (doc comments are not stripped)
    hits = {t: [] for t in SCAN}
    lines = 0
    for m in mods:
        for n, l in enumerate((F / "ZK60Formal" / (m + ".lean")).read_text().split("\n"), 1):
            lines += 1
            code = l.split("--")[0]
            for t in SCAN:
                if re.search(r"(?<![\w.'])" + t + r"(?![\w'])", code):
                    hits[t].append(f"{m}:{n}")
    print(f"source scan over {len(mods)} files, {lines} lines:", {t: len(v) for t, v in hits.items()})
    for t, v in hits.items():
        if v:
            print(f"    {t}: first {v[:6]}")


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
    mods = family()
    fresh = [m for m in mods if (F / ".lake/build/lib/lean/ZK60Formal" / (m + ".olean")).exists()
             and (F / ".lake/build/lib/lean/ZK60Formal" / (m + ".olean")).stat().st_mtime >= t0]
    print(f"=== STEP oleans START\nfresh oleans {len(fresh)} of {len(mods)}; missing or old: {sorted(set(mods) - set(fresh))}\n=== STEP oleans EXIT {0 if len(fresh) == len(mods) else 1}", flush=True)
    if len(fresh) != len(mods):
        bad += 1
    if step("axioms", [LAKE, "-d", str(F), "env", "lean", str(F / "AxiomsL69.lean")]) != 0:
        bad += 1
    return 1 if bad else 0


def launch(label):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        assert not p.exists(), f"{p} exists: labels are not reused"
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    (RAW / (label + ".status_pre.txt")).write_text(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n" + st)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "build", "--label", "lean-l69-merge-" + label, "--need-gib", "24",
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
            rows = body.split("\n")
            errs = [l for l in rows if re.search(r"\berror\b", l) and not l.startswith("===")]
            sorry = [l for l in rows if "warning" in l and "sorry" in l]
            warn = [l for l in rows if l.startswith("warning") and re.search(r"HonestShield|RunShieldOpenShell", l)]
            kinds = {}
            for j, l in enumerate(rows):
                if l.startswith("warning") and re.search(r"HonestShield|RunShieldOpenShell", l):
                    tag = re.search(r"linter\.\w+", " ".join(rows[j:j + 6]))
                    kinds[tag.group(0) if tag else "no linter tag in the next lines"] = kinds.get(tag.group(0) if tag else "no linter tag in the next lines", 0) + 1
            files = sorted({m.group(1) for l in warn for m in [re.search(r"ZK60Formal/(\w+)\.lean", l)] if m})
            built = len(re.findall(r"Built ZK60Formal\.(?:HonestShield\w*|RunShieldOpenShell)\b", body))
            print(f"root build: exit {rc}; error lines {len(errs)}; warnings with the word sorry {len(sorry)}; "
                  f"other warnings naming the family's files {len(warn)} in {len(files)} files; 'Built' lines for the family {built}")
            print("    warning kinds:", kinds, "files:", files)
            for l in (errs + sorry)[:8] + warn[:4]:
                print("    " + l[:200])
            ok &= rc == "0" and not errs and not sorry
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
