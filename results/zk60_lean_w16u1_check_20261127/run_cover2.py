#!/usr/bin/env python3
"""Build check of the corrected covering module formal/ZK60Formal/BlockW16U1Cover.lean (co-coordinator, 2026-11-27).

The correction: the witness record's opening dimensions are the ones the Rust verifier computes for the W16R2 profiles
(280 opened columns, vectors of 2^14 + 280 words, 2^15 encoded columns, paths of 15 entries) and no longer R13's
(256, 2^14 + 256, 2^16, 16), with which no core was accepted at the record; one new statement, cov_paths_agree. Found by the
parameter read results/zk60_claude_review_20261116/W16R2_PARAMS_READ_20261127.md (finding F1).

This file reuses the runner of 2026-11-26 (../zk60_lean_w16u1_check_20261126/run_cover.py: the same private copy of the
tree, the same four steps, the same guarded launch) with two differences: the axioms file names four statements, and the
logs go to this directory's raw/.

usage: run_cover2.py prepare            (copy still equals the repository except the module; writes the axioms file;
                                         removes the module's build products so that the recorded run builds it)
       run_cover2.py launch <label>     (detached, guarded, class build; a label is never reused)
       run_cover2.py summary <label>
       run_cover2.py land               (after a GREEN summary: copies the built module into the repository, byte-identical)

PASS RULE, written before the recorded run: that of run_cover.py, word for word (steps 1 and 3 exit 0 with no line that
starts with "error" and no warning that holds the word "sorry"; step 1 builds this module and no other; the module's
.olean was written after the job began; step 3 rebuilds neither this module nor any module of the family; step 4 exits 0;
none of `sorry`, `axiom `, `native_decide`, `implemented_by`, `unsafe ` in the module's code), with FOUR axiom reports
instead of three, one per name below, each naming no axiom outside propext, Classical.choice, Quot.sound. A failed recorded
run is not repeated to get a pass.

WHAT A PASS MEANS: the corrected file compiles and its four statements rest on the standard axioms. It does not mean that
an accepting core exists at the record (that is not proved anywhere), and it says nothing about the run level (item 6 of
the port list).
"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OLD = HERE.parent / "zk60_lean_w16u1_check_20261126" / "run_cover.py"
spec = importlib.util.spec_from_file_location("run_cover", OLD)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.RAW = HERE / "raw"
m.NAMES = [m.NS + n for n in ("cov_layR_c0", "cov_isShieldW16", "cov_block_knowledge_w16r2_shieldU1", "cov_paths_agree")]
REPO_F = Path(m.REPO) / "formal"
MODF = "ZK60Formal/" + m.MOD + ".lean"


def differing():
    a = sorted(p.name for p in (m.F / "ZK60Formal").glob("*.lean"))
    b = sorted(p.name for p in (REPO_F / "ZK60Formal").glob("*.lean"))
    assert a == b, "the copy and the repository hold different sets of modules"
    return [n for n in a if (m.F / "ZK60Formal" / n).read_bytes() != (REPO_F / "ZK60Formal" / n).read_bytes()]


def prepare():
    assert (m.F / "ZK60Formal.lean").read_bytes() == (REPO_F / "ZK60Formal.lean").read_bytes(), "root files differ"
    assert (m.F / "ZK60Formal.lean").read_text().endswith(m.LINE)
    d = differing()
    assert d == [m.MOD + ".lean"], f"the copy must differ from the repository in the module alone: {d}"
    assert "cov_paths_agree" in m.code_text() and "covDimW16" in m.code_text()
    (m.F / "AxiomsW16U1Cover.lean").write_text("import ZK60Formal\n" + "".join(f"#print axioms {n}\n" for n in m.NAMES))
    gone = []
    for sub in ("lib/lean", "ir"):
        for p in list((m.F / ".lake" / "build" / sub / "ZK60Formal").glob(m.MOD + ".*")):
            p.unlink()
            gone.append(p.name)
    print("axioms file written for", len(m.NAMES), "names | removed products:", sorted(gone))


def land():
    src = m.F / MODF
    (REPO_F / MODF).write_bytes(src.read_bytes())
    assert differing() == []
    print("landed", MODF, "bytes", len(src.read_bytes()))


if __name__ == "__main__":
    if sys.argv[1] == "prepare":
        prepare()
    elif sys.argv[1] == "launch":
        m.launch(sys.argv[2])
    elif sys.argv[1] == "summary":
        m.summary(sys.argv[2])
    elif sys.argv[1] == "land":
        land()
