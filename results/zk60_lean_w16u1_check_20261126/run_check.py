#!/usr/bin/env python3
"""Build check of agy/lean-w16r2-shield (co-coordinator, written 2026-11-25 for a run on 2026-11-26). Same method as
results/zk60_lean_l69_merge_20261125/run_check.py: an independent build from source, in a private copy, of the 17 Lean modules
the branch adds (the single-block statements for the installed profile, W16R2 with the export_u1 shape), and an axiom audit
of the six theorems the author names. Nothing under .agy-worktrees is touched.

What differs from the L69 check: the root file ZK60Formal.lean of this branch does NOT import the new modules, so a root build
does not reach them. The check therefore builds the one module that imports all the others (BlockW16U1Done) by name. When the
author adds the root imports, the remaining check is the root build alone.

usage: run_check.py prepare <commit>   export <commit>:formal into the scratch directory; clone, beside it, the build products
                                       of my own full build of the merged tree of Nov 25 (scratchpad/lean-l69/formal/.lake,
                                       guard run 4d7436f61c9f; APFS clone, `cp -c`); compare the two source trees; write
                                       AxiomsW16U1.lean; print the source scan
       run_check.py launch <label>     one detached guarded job (class build) that runs `leaf`; writes raw/<label>.*
       run_check.py leaf               (what the guard runs) one "=== STEP" line pair per step
       run_check.py summary <label>    reads raw/<label>.log

Steps of `leaf`: (1) probe: `lake build ZK60Formal` (the root, which does not import the new modules) must exit 0 within
900 s (otherwise the cloned products are not valid for this copy and the job stops instead of rebuilding the tree);
(2) `lake build ZK60Formal.BlockW16U1Done`; (3) every one of the 17 modules has an .olean written after this job began;
(4) `lake env lean AxiomsW16U1.lean`.

PASS RULE, written before the first run:
  - `prepare` finds exactly 17 new modules, and the only differences between this source tree and the one built on Nov 25
    are added files;
  - steps 1, 2 and 4 exit 0; no line of step 2's output is an error;
  - step 3 finds all 17 modules;
  - the axiom report of each of the six names is present and names only propext, Classical.choice, Quot.sound (so no sorryAx);
  - no warning of step 2 contains the word sorry.
Other warnings that name one of the 17 files are counted and their first lines printed; they do not fail the check (the rule
of the L69 check). The number of modules the probe rebuilt is reported; none is expected.
A wrong name in AxiomsW16U1.lean (an "unknown constant" error) is an error of this harness, not a result about the branch: it
is corrected and step 4 alone is repeated under a new label, and the record says so.
The check says nothing about whether the definitions mean what the documents say; that is a read, not a build.

ROOT STEP, added 2026-11-26 after `check1` and before its own run (the author had not answered the request for the root
imports; the coordinator adds them as a covering step):
       run_check.py prepare-root         append the 17 import lines (dependency order) to the scratch copy's ZK60Formal.lean,
                                         which must not have any of them yet; write AxiomsW16U1Root.lean, which imports ONLY
                                         the root; record the time in root_t0.txt
       run_check.py launch <label> leaf-root
       run_check.py summary-root <label>
Steps of `leaf-root`: (1) `lake build ZK60Formal`; (2) `lake env lean AxiomsW16U1Root.lean`.
PASS RULE of the root step, written before its run: both steps exit 0; no error line and no warning with the word sorry in
step 1; none of the 17 modules is rebuilt in step 1 (their products of `check1` stand; a rebuild would mean the sources
changed); the root's own .olean is newer than root_t0.txt; the six axiom reports are present through the root import alone
and name only the three standard axioms. The line appended to the repository's root file must then be byte-identical to the
17 lines of the scratch copy.
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
SP = Path("/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad")
SCR = SP / "lean-w16u1"
F = SCR / "formal"
BASE = SP / "lean-l69" / "formal"
FAMSRC = r"(BlockW16U1\w*|BlockDefineW16Shield|BlockInstW16Shield|RunShapeShieldU1)"
FAM = re.compile("^" + FAMSRC + "$")
TOP = "BlockW16U1Done"
TOPS = ["ZK60.RunShape.ShieldU1.shieldU1_circuitIff", "ZK60.RunShape.ShieldU1.shieldU1_circuitIff_policy",
        "ZK60.RunShape.ShieldU1.shieldU1_run_exists", "ZK60.Exec.Block.block_knowledge_alg_w16r2_shield_lk26",
        "ZK60.Exec.Block.block_knowledge_define_alg_w16r2_shieldU1",
        "ZK60.Exec.Block.Join.W16U1.block_knowledge_w16r2_shieldU1"]
ALLOWED = {"propext", "Classical.choice", "Quot.sound"}
SCAN = ["sorry", "admit", "axiom", "native_decide", "unsafe", "implemented_by", "opaque", "maxHeartbeats", "maxRecDepth"]


def family():
    return sorted(p.stem for p in (F / "ZK60Formal").glob("*.lean") if FAM.match(p.stem))


def sources(root):
    out = {}
    for p in root.rglob("*"):
        rel = p.relative_to(root)
        if p.is_file() and rel.parts[0] != ".lake" and not rel.name.startswith("Axioms"):
            out[str(rel)] = p.read_bytes()
    return out


def prepare(commit):
    assert not SCR.exists(), f"{SCR} exists"
    SCR.mkdir(parents=True)
    data = subprocess.run(["git", "archive", commit, "formal"], cwd=REPO, capture_output=True, check=True).stdout
    tarfile.open(fileobj=io.BytesIO(data)).extractall(SCR)
    (SCR / "commit.txt").write_text(commit + "\n")
    subprocess.run(["cp", "-c", "-R", "-p", str(BASE / ".lake"), str(F / ".lake")], check=True)
    removed = 0
    for sub in ("lib/lean", "ir"):
        for p in list((F / ".lake" / "build" / sub / "ZK60Formal").glob("*")):
            if p.is_file() and FAM.match(p.name.split(".")[0]):
                p.unlink()
                removed += 1
    mods = family()
    (F / "AxiomsW16U1.lean").write_text(f"import ZK60Formal.{TOP}\n" + "".join(f"#print axioms {t}\n" for t in TOPS))
    print(f"exported {commit} formal/ to {SCR}; {len(mods)} modules in the family; removed {removed} build products of them from the clone")
    a, b = sources(BASE), sources(F)
    added = sorted(set(b) - set(a))
    gone = sorted(set(a) - set(b))
    changed = sorted(k for k in set(a) & set(b) if a[k] != b[k])
    print(f"against the tree built on Nov 25 ({(BASE.parent / 'commit.txt').read_text().strip()[:9]}): added {len(added)}, removed {len(gone)}, changed {len(changed)}")
    print("    added:", [x.split("/")[-1] for x in added])
    if gone or changed:
        print("    removed:", gone[:10], "changed:", changed[:10])
    root = (F / "ZK60Formal.lean").read_text()
    print("root imports of the family:", sum(1 for m in mods if f"import ZK60Formal.{m}\n" in root), "of", len(mods))
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
    print("PREPARE:", "ok" if len(mods) == 17 and not gone and not changed else "NOT ok")


def leaf(only_axioms=False):
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

    if not only_axioms:
        if step("probe", [LAKE, "-d", str(F), "build", "ZK60Formal"], timeout=900) != 0:
            print("=== STOP: the cloned products are not valid for this copy (the root build did not finish within 900 s)", flush=True)
            return 1
        if step("family", [LAKE, "-d", str(F), "build", "ZK60Formal." + TOP]) != 0:
            bad += 1
        mods = family()
        lib = F / ".lake/build/lib/lean/ZK60Formal"
        fresh = [m for m in mods if (lib / (m + ".olean")).exists() and (lib / (m + ".olean")).stat().st_mtime >= t0]
        print(f"=== STEP oleans START\nfresh oleans {len(fresh)} of {len(mods)}; missing or old: {sorted(set(mods) - set(fresh))}\n=== STEP oleans EXIT {0 if len(fresh) == len(mods) == 17 else 1}", flush=True)
        if not len(fresh) == len(mods) == 17:
            bad += 1
    if step("axioms", [LAKE, "-d", str(F), "env", "lean", str(F / "AxiomsW16U1.lean")]) != 0:
        bad += 1
    return 1 if bad else 0


ROOT_ORDER = ["RunShapeShieldU1", "BlockInstW16Shield", "BlockDefineW16Shield", "BlockW16U1Base", "BlockW16U1TabBase",
              "BlockW16U1TabForm", "BlockW16U1Help", "BlockW16U1HostTzc", "BlockW16U1HostDzc", "BlockW16U1HostQkv",
              "BlockW16U1HostSzc", "BlockW16U1HostFzc", "BlockW16U1Hosts", "BlockW16U1LookBase", "BlockW16U1LookCov",
              "BlockW16U1LookRel", "BlockW16U1Done"]
ROOT_LINES = "".join(f"import ZK60Formal.{m}\n" for m in ROOT_ORDER)


def prepare_root():
    assert sorted(ROOT_ORDER) == family() and len(ROOT_ORDER) == 17
    rp = F / "ZK60Formal.lean"
    root = rp.read_text()
    assert root.endswith("\n") and not any(f"import ZK60Formal.{m}\n" in root for m in ROOT_ORDER)
    # each module is listed after everything of the family it imports
    seen = set()
    for m in ROOT_ORDER:
        deps = re.findall(r"^import ZK60Formal\.(\w+)$", (F / "ZK60Formal" / (m + ".lean")).read_text(), flags=re.M)
        assert all(d in seen for d in deps if FAM.match(d)), (m, deps)
        seen.add(m)
    (SCR / "root_t0.txt").write_text(str(time.time()) + "\n")
    rp.write_text(root + ROOT_LINES)
    (F / "AxiomsW16U1Root.lean").write_text("import ZK60Formal\n" + "".join(f"#print axioms {t}\n" for t in TOPS))
    print("appended 17 import lines to the scratch root; it now has", (root + ROOT_LINES).count("\nimport ") + 1, "import lines")


def leaf_root():
    env = dict(os.environ, LEAN_NUM_THREADS="4", PYTHONDONTWRITEBYTECODE="1")
    bad = 0
    for name, argv in (("root", [LAKE, "-d", str(F), "build", "ZK60Formal"]),
                       ("axioms", [LAKE, "-d", str(F), "env", "lean", str(F / "AxiomsW16U1Root.lean")])):
        print(f"=== STEP {name} START {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} argv {' '.join(argv[1:])}", flush=True)
        rc = subprocess.run(argv, env=env, stdin=subprocess.DEVNULL).returncode
        print(f"=== STEP {name} EXIT {rc} {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}", flush=True)
        bad += rc != 0
    return 1 if bad else 0


def summary_root(label):
    log = (RAW / (label + ".log")).read_text(errors="replace")
    done = RAW / (label + ".done")
    fin = done.exists() and done.read_text().strip() == "0"
    root = log.split("=== STEP root START")[1].split("=== STEP root EXIT")[0]
    rc_root = re.search(r"^=== STEP root EXIT (-?\d+)", log, re.M).group(1)
    ax = log.split("=== STEP axioms START")[1]
    rc_ax = re.search(r"^=== STEP axioms EXIT (-?\d+)", log, re.M).group(1)
    rows = root.split("\n")
    errs = [l for l in rows if re.search(r"\berror\b", l)]
    sorry = [l for l in rows if "warning" in l and "sorry" in l]
    fam_built = re.findall(r"Built ZK60Formal\.(?:" + FAMSRC[1:-1] + r")\b", root)
    all_built = re.findall(r"Built (ZK60Formal[.\w]*)", root)
    t0 = float((SCR / "root_t0.txt").read_text())
    ol = F / ".lake/build/lib/lean/ZK60Formal.olean"
    fresh = ol.exists() and ol.stat().st_mtime >= t0
    reps = re.findall(r"'([^']+)' depends on axioms: \[([^\]]*)\]", ax.replace("\n", " "))
    other = sorted({a.strip() for _, x in reps for a in x.split(",") if a.strip()} - ALLOWED)
    names = sorted(n for n, _ in reps)
    print(f"root build: exit {rc_root}; error lines {len(errs)}; warnings with the word sorry {len(sorry)}; modules built {all_built}; "
          f"of the 17 rebuilt {len(fam_built)}; root .olean newer than the import edit: {fresh}")
    print(f"axioms through the root import alone: exit {rc_ax}; reports {len(reps)} of {len(TOPS)}; outside the three standard axioms: {other or 'none'}")
    ok = (fin and rc_root == "0" and rc_ax == "0" and not errs and not sorry and not fam_built and fresh
          and names == sorted(TOPS) and not other)
    print("ROOT STEP:", "GREEN" if ok else "NOT GREEN (or unfinished)")


def launch(label, mode="leaf"):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        assert not p.exists(), f"{p} exists: labels are not reused"
    st = subprocess.run([sys.executable, "-B", GUARD, "status"], capture_output=True, text=True).stdout
    (RAW / (label + ".status_pre.txt")).write_text(time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()) + "\n" + st)
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "build", "--label", "lean-w16u1-check-" + label, "--need-gib", "24",
           "--cap-gib", "64", "--max-secs", "14400", "--wait-secs", "21600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", sys.executable, "-B", str(Path(__file__).resolve()), mode]
    env = dict(os.environ)
    env.pop("ZK60_GUARD_POLL_SECS", None)
    p = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=open(RAW / (label + ".runner.txt"), "w"),
                         stderr=subprocess.STDOUT, start_new_session=True)
    print("launched", label, mode, "pid", p.pid, "commit", (SCR / "commit.txt").read_text().strip())


def summary(label, need=("probe", "family", "oleans", "axioms")):
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
        rows = body.split("\n")
        if name == "probe":
            built = len(re.findall(r"Built ZK60Formal\b", body))
            errs = [l for l in rows if re.search(r"\berror\b", l) and not l.startswith("===")]
            print(f"probe (root build): exit {rc}; modules rebuilt {built}; error lines {len(errs)}")
            ok &= rc == "0" and not errs
        elif name == "family":
            errs = [l for l in rows if re.search(r"\berror\b", l) and not l.startswith("===")]
            sorry = [l for l in rows if "warning" in l and "sorry" in l]
            warn = [j for j, l in enumerate(rows) if l.startswith("warning") and re.search(FAMSRC, l)]
            kinds = {}
            for j in warn:
                tag = re.search(r"linter\.\w+", " ".join(rows[j:j + 6]))
                k = tag.group(0) if tag else "no linter tag in the next lines"
                kinds[k] = kinds.get(k, 0) + 1
            files = sorted({m.group(1) for j in warn for m in [re.search(r"ZK60Formal/(\w+)\.lean", rows[j])] if m})
            built = sorted(set(re.findall(r"Built ZK60Formal\.(" + FAMSRC[1:-1] + r")\b", body)))
            other = len(re.findall(r"Built ZK60Formal\b", body)) - len(re.findall(r"Built ZK60Formal\.(?:" + FAMSRC[1:-1] + r")\b", body))
            print(f"family build: exit {rc}; error lines {len(errs)}; warnings with the word sorry {len(sorry)}; other warnings "
                  f"naming the 17 files {len(warn)} in {len(files)} files; 'Built' lines for the 17: {len(built)}; for other modules: {other}")
            print("    warning kinds:", kinds, "files:", files)
            for l in (errs + sorry)[:8] + [rows[j] for j in warn[:4]]:
                print("    " + l[:200])
            ok &= rc == "0" and not errs and not sorry
        elif name == "axioms":
            reps = re.findall(r"'([^']+)' depends on axioms: \[([^\]]*)\]", body.replace("\n", " "))
            none = re.findall(r"'([^']+)' does not depend on any axioms", body)
            other = sorted({a.strip() for _, ax in reps for a in ax.split(",") if a.strip()} - ALLOWED)
            unknown = [l for l in rows if "unknown" in l.lower()]
            print(f"axioms: exit {rc}; reports {len(reps) + len(none)} of {len(TOPS)}; axioms outside the three standard ones: {other or 'none'}; 'unknown' lines {len(unknown)}")
            for n, ax in reps:
                print(f"    {n.split('.')[-1]}: {', '.join(a.strip() for a in ax.split(','))}")
            for n in none:
                print(f"    {n.split('.')[-1]}: no axioms")
            for l in unknown[:6]:
                print("    " + l[:200])
            ok &= rc == "0" and len(reps) + len(none) == len(TOPS) and not other
        else:
            line = next((l for l in rows if l.startswith("fresh oleans")), "")
            print(f"{name}: exit {rc} {line}")
            ok &= rc == "0"
    fin = done.exists() and done.read_text().strip() == "0"
    print("CHECK:", "GREEN" if ok and fin and set(seen) >= set(need) else "NOT GREEN (or unfinished)", "| steps seen:", seen)


if __name__ == "__main__":
    if sys.argv[1] == "prepare":
        prepare(sys.argv[2])
    elif sys.argv[1] == "launch":
        launch(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "leaf")
    elif sys.argv[1] == "leaf":
        sys.exit(leaf())
    elif sys.argv[1] == "leaf-axioms":
        sys.exit(leaf(only_axioms=True))
    elif sys.argv[1] == "prepare-root":
        prepare_root()
    elif sys.argv[1] == "leaf-root":
        sys.exit(leaf_root())
    elif sys.argv[1] == "summary-root":
        summary_root(sys.argv[2])
    else:
        summary(sys.argv[2], tuple(sys.argv[3].split(",")) if len(sys.argv) > 3 else ("probe", "family", "oleans", "axioms"))
