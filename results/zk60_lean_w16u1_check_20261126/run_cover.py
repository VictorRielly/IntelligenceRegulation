#!/usr/bin/env python3
"""Build check of the covering module formal/ZK60Formal/BlockW16U1Cover.lean (co-coordinator, 2026-11-26): the two facts of
the independent read of the installed-profile single-block step (W16U1_READ_20261126.md, M2 and M3) as one new file. Same
private copy as run_check.py (scratchpad/lean-w16u1/formal, the merged tree with the 17 root imports, built by `root1`).

usage: run_cover.py prepare            (writes the axioms file and appends the one import line to the copy's root file)
       run_cover.py launch <label>     (detached, guarded, class build; writes raw/<label>.*; a label is never reused)
       run_cover.py leaf               (what the guard runs)
       run_cover.py summary <label>

Steps of `leaf`: (1) `lake build ZK60Formal.BlockW16U1Cover`; (2) the module's .olean was written after this job began;
(3) `lake build ZK60Formal` with the import line appended to the root; (4) `lake env lean AxiomsW16U1Cover.lean`, which
imports the root alone and prints the axioms of the three names below.

PASS RULE, written before the recorded run: steps 1 and 3 exit 0 with no line that starts with "error" and no warning that
holds the word "sorry"; step 1 builds this module and no other; step 2 holds; step 3 rebuilds neither this module nor any of
the 17 modules of the family (the root alone); step 4 exits 0 and gives exactly three reports, one per name, each naming no
axiom outside propext, Classical.choice, Quot.sound. In addition the source text of the file holds none of `sorry`, `axiom `,
`native_decide`, `implemented_by`, `unsafe ` outside its header comment. Then the file and the one import line are committed
byte-identical to the copy that was built. A failed recorded run is not repeated to get a pass.

WHAT A PASS MEANS: the file compiles and its three statements rest on the standard axioms. It is not a read by someone who
did not write it, and it says nothing about the run level (item 6 of the port list): the record in the file is a
satisfiability witness with placeholder fields, as its header says.
"""
import os
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = "/Users/victorrielly/IntelligenceRegulation"
HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
GUARD = REPO + "/scripts/zk60_resource_guard.py"
LAKE = "/Users/victorrielly/.elan/toolchains/leanprover--lean4---v4.34.1/bin/lake"
F = Path("/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/lean-w16u1/formal")
MOD = "BlockW16U1Cover"
NS = "ZK60.Exec.Block.Join.W16U1.Cover."
NAMES = [NS + "cov_layR_c0", NS + "cov_isShieldW16", NS + "cov_block_knowledge_w16r2_shieldU1"]
LINE = f"import ZK60Formal.{MOD}\n"
STD = {"propext", "Classical.choice", "Quot.sound"}
FAM = re.compile(r"ZK60Formal\.(BlockW16U1\w*|BlockDefineW16Shield|BlockInstW16Shield|RunShapeShieldU1)\b")


def code_text():
    """the module's text after its header comment"""
    t = (F / "ZK60Formal" / (MOD + ".lean")).read_text()
    assert t.startswith("/-") and "-/" in t
    return t.split("-/", 1)[1]


def prepare():
    root = F / "ZK60Formal.lean"
    t = root.read_text()
    assert t.endswith("import ZK60Formal.BlockW16U1Done\n") and LINE not in t, "the root of the copy is not as root1 left it"
    root.write_text(t + LINE)
    (F / "AxiomsW16U1Cover.lean").write_text("import ZK60Formal\n" + "".join(f"#print axioms {n}\n" for n in NAMES))
    # the products of the development compile go, so that the recorded run builds the module itself
    gone = []
    for sub in ("lib/lean", "ir"):
        for p in list((F / ".lake" / "build" / sub / "ZK60Formal").glob(MOD + ".*")):
            p.unlink()
            gone.append(p.name)
    print("root import appended; axioms file written; imports in the root:", (t + LINE).count("\nimport ") + 1, "| removed products:", sorted(gone))


def leaf():
    env = dict(os.environ, LEAN_NUM_THREADS="4", PYTHONDONTWRITEBYTECODE="1")
    t0 = time.time()
    bad = 0

    def step(name, argv):
        print(f"=== STEP {name} START {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())} argv {' '.join(argv[1:])}", flush=True)
        rc = subprocess.run(argv, env=env, stdin=subprocess.DEVNULL).returncode
        print(f"=== STEP {name} EXIT {rc} {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}", flush=True)
        return rc

    bad += step("module", [LAKE, "-d", str(F), "build", "ZK60Formal." + MOD]) != 0
    ol = F / ".lake/build/lib/lean/ZK60Formal" / (MOD + ".olean")
    fresh = ol.exists() and ol.stat().st_mtime >= t0
    print(f"=== STEP olean START\nmodule .olean written after the job began: {fresh}\n=== STEP olean EXIT {0 if fresh else 1}", flush=True)
    bad += not fresh
    bad += step("root", [LAKE, "-d", str(F), "build", "ZK60Formal"]) != 0
    bad += step("axioms", [LAKE, "-d", str(F), "env", "lean", str(F / "AxiomsW16U1Cover.lean")]) != 0
    return 1 if bad else 0


def launch(label):
    RAW.mkdir(parents=True, exist_ok=True)
    log, gj, done = RAW / (label + ".log"), RAW / (label + ".guard.json"), RAW / (label + ".done")
    for p in (log, gj, done):
        assert not p.exists(), f"{p} exists: labels are not reused"
    assert (F / "ZK60Formal.lean").read_text().endswith(LINE), "run prepare first"
    cmd = [sys.executable, "-B", GUARD, "run", "--class", "build", "--label", "lean-w16u1-check-" + label, "--need-gib", "24",
           "--cap-gib", "64", "--max-secs", "7200", "--wait-secs", "21600", "--log", str(log), "--done", str(done),
           "--result-json", str(gj), "--", sys.executable, "-B", str(Path(__file__).resolve()), "leaf"]
    env = dict(os.environ)
    env.pop("ZK60_GUARD_POLL_SECS", None)
    p = subprocess.Popen(cmd, env=env, stdin=subprocess.DEVNULL, stdout=open(RAW / (label + ".runner.txt"), "w"),
                         stderr=subprocess.STDOUT, start_new_session=True)
    print("launched", label, "pid", p.pid)


def summary(label):
    log = (RAW / (label + ".log")).read_text(errors="replace")
    done = RAW / (label + ".done")
    print("done marker:", done.read_text().strip() if done.exists() else "absent (still running)")
    parts = re.split(r"^=== STEP (\S+) START[^\n]*\n", log, flags=re.M)
    body = {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}
    rc = {k: (re.search(r"^=== STEP \S+ EXIT (-?\d+)", v, re.M) or [None, "?"])[1] for k, v in body.items()}
    ok = set(body) == {"module", "olean", "root", "axioms"}
    for k in ("module", "root"):
        b = body.get(k, "")
        errs = [l for l in b.split("\n") if l.startswith("error")]
        sorry = [l for l in b.split("\n") if "warning" in l and "sorry" in l]
        built = re.findall(r"Built (\S+)", b)
        fam = [m for m in built if FAM.search(m)]
        print(f"{k}: exit {rc.get(k)}; error lines {len(errs)}; warnings with the word sorry {len(sorry)}; modules built {built}")
        good = rc.get(k) == "0" and not errs and not sorry
        if k == "module":
            good &= built == ["ZK60Formal." + MOD]
        else:
            good &= not fam
        ok &= good
    print(f"olean: exit {rc.get('olean')}")
    ok &= rc.get("olean") == "0"
    ax = body.get("axioms", "").replace("\n", " ")
    reps = dict(re.findall(r"'([^']+)' depends on axioms: \[([^\]]*)\]", ax))
    other = sorted({a.strip() for v in reps.values() for a in v.split(",")} - STD)
    print(f"axioms through the root import alone: exit {rc.get('axioms')}; reports {len(reps)} of {len(NAMES)}; outside the three standard axioms: {other or 'none'}")
    ok &= rc.get("axioms") == "0" and sorted(reps) == sorted(NAMES) and not other
    code = code_text()
    banned = [w for w in ("sorry", "axiom ", "native_decide", "implemented_by", "unsafe ") if w in code]
    print("banned words in the module's code:", banned or "none")
    ok &= not banned
    print("COVER CHECK:", "GREEN" if ok and done.exists() and done.read_text().strip() == "0" else "NOT GREEN (or unfinished)")


if __name__ == "__main__":
    if sys.argv[1] == "prepare":
        prepare()
    elif sys.argv[1] == "launch":
        launch(sys.argv[2])
    elif sys.argv[1] == "leaf":
        sys.exit(leaf())
    else:
        summary(sys.argv[2])
