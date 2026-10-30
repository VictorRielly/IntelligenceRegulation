"""Audit and package S4 isolated evidence; does not authorize native layout work."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
R13 = HERE.parent / "r13"


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write(name, obj):
    (HERE / name).write_text(json.dumps(obj, indent=2) + "\n")


def result(stem):
    lines = (HERE / (stem + ".log")).read_text().splitlines()
    objs = [json.loads(line) for line in lines if line.startswith("{")]
    assert len(objs) == 1, (stem, len(objs))
    return objs[0]


def main():
    utc = datetime.now(timezone.utc).isoformat()
    required = [
        "s4-native-role-build", "s4-native-role-census",
        "s4-algebra-build-2", "s4-algebra-run-2",
        "s4-pcs-lift-build-1", "s4-pcs-lift-run-1",
        "s4-cfs-lift-build-4", "s4-cfs-lift-run-4",
        "s4-scalar-build-1", "s4-scalar-run-1",
    ]
    gates = {}
    for stem in required:
        assert (HERE / (stem + ".done")).read_text().strip() == "0", stem
        guard = json.loads((HERE / (stem + ".guard.json")).read_text())
        assert guard["exit"] == 0 and guard["child_rc"] == 0, stem
        assert not guard["guard_killed"] and not guard["refused"] and not guard["guard_error"], stem
        gates[stem] = {k: guard[k] for k in ["exit", "child_wall_seconds", "peak_rss_gib", "enforcement"]}
    for stem in ["cfs_lift", "scalar_split"]:
        assert (HERE / (stem + ".rs")).stat().st_mtime_ns <= (HERE / (stem + ".bin")).stat().st_mtime_ns

    frozen = json.loads((R13 / "manifest_frozen.json").read_text())
    assert frozen["count"] == len(frozen["files"]) == 269
    checks = {}
    for tree in ["frozen-tree", "working-tree"]:
        for rel, expected in frozen["files"].items():
            assert sha(R13 / tree / rel) == expected, (tree, rel)
        checks[tree] = {"manifest_files_unchanged": 269, "tree_sha256": frozen["tree_sha256"]}
    # This walk is deliberately restricted to the small frozen source tree.
    actual = {str(p.relative_to(R13 / "frozen-tree")) for p in (R13 / "frozen-tree").rglob("*") if p.is_file()}
    assert actual == set(frozen["files"])

    library = json.loads((HERE / "PCS_LIBRARY_PIN.json").read_text())
    assert sha(Path(library["path"])) == library["sha256"]
    algebra = result("s4-algebra-run-2")
    pcs = result("s4-pcs-lift-run-1")
    cfs = result("s4-cfs-lift-run-4")
    scalar = result("s4-scalar-run-1")
    assert algebra["lift_and_mask_identities"] == 148 and algebra["coordinate_degree_checks"] == 22
    assert cfs["honest_cfs_pcs_microproofs"] == 24 and cfs["emitted_bad_microproofs_rejected"] == 192
    assert cfs["zero_lift_honest_functionals"] == 24 and cfs["zero_lift_bad_functionals_rejected"] == 48
    assert scalar["native_scalar_piece_equivalences"] == 104 and scalar["true_axis_words_mapped_bijectively"] == 12288
    count = json.loads((HERE / "COUNT.json").read_text())
    assert count["native_baselines_reproduced"] == 4

    review = json.loads((HERE / "DESIGN_REVIEW_REQUEST.json").read_text())
    paper = json.loads((HERE / "PAPER.json").read_text())
    paper["status"] = "S4 construction/count and isolated validation complete; independent design check required before native layout work"
    paper["construction_B_batched_zero_lift"]["zero_functional_adapter"] = review["primary_design"]["zero_case"]
    paper["native_cfs_component_evidence"] = cfs
    paper["native_scalar_piece_evidence"] = scalar
    paper["design_review_packet"] = "DESIGN_REVIEW_REQUEST.json"
    paper["experimental_independent_mask_alternative"] = {
        "status": "isolated experiment only; differs from coordinated whole-functional scaling condition; independent design/privacy review required",
        "formula": review["alternative_for_review_only"]["masked_extension"],
        "finding": review["alternative_for_review_only"]["zero_case"],
    }
    paper["next_validation"] = [
        "Coordinator routes the independent soundness/privacy design check requested in DESIGN_REVIEW_REQUEST.json; native layout implementation remains held under the explicit 06:35 coordination instruction.",
        "After resolving the design check, replace proposed slot/claim counts with a native census; validate all M coefficient budgets, physical terminals, hash/domain and wire registrations before relying on a new profile.",
        "After an explicit new profile, compare all19 native trace sites/output with R13, then full T128 native prove/verify/fresh/tamper and endpoint-piece attacks. Microproofs do not establish those gates.",
        "Measure split live buffers/RSS; plan T256 proofs for the 5090 desktop under appropriate admission, not by reducing laptop declarations.",
    ]
    write("PAPER.json", paper)

    sources = ["hashline/src/private_block/argument.rs", "hashline/src/zk.rs", "zkp-core/src/pcs.rs",
               "zkp-core/src/sumcheck.rs", "zkp-core/src/transcript.rs"]
    sources += [f"hashline/src/private_block/{s}.rs" for s in ["accuracy", "accuracy_tables", "accuracy_groups", "accuracy_precision", "accuracy_aligned"]]
    write("PINNED_NATIVE_DEPENDENCIES.json", {
        "anchor": frozen["tree_sha256"], "native_library": library,
        "files": {rel: sha(R13 / "frozen-tree" / rel) for rel in sources},
        "scope": "Direct scalar module imports and native compiled CFS/PCS/M dependencies; experimental point/claim adapter remains separate from private-block integration",
    })
    report = {
        "utc": utc, "status": "PASS: S4 isolated-validation stage; awaiting independent design check",
        "scope": "No native split profile, full-block split receipt, endpoint/wire integration or security/privacy/fidelity acceptance",
        "anchor_unchanged": checks, "required_gates": gates,
        "results": {"algebra": algebra, "initial_pcs": pcs, "cfs_components": cfs, "native_scalars": scalar},
        "design_review_request": "DESIGN_REVIEW_REQUEST.json",
        "retained_failures": {
            "s4-algebra-run-1": "Ineffective wrong-axis negative point was all equal; non-vacuity failed; retained and corrected in attempt2",
            "s4-cfs-lift-run-1": "Changing only short-slice PCS opening point did not forge a false terminal; ineffective control accepted, corrected in attempt2 and retained. Full fixed-token validation in attempt4",
        },
        "memory": "COUNT.json is a model, not measured split RSS or T256-fit evidence; extremely fast microtest RSS sampling may report0.00GiB and is not a zero-memory claim",
        "native_layout_work": "held until coordinator-routed independent design check per 2026-10-29T06:35:14Z",
    }
    write("ISOLATED_VALIDATION.json", report)
    write("STATE.json", {
        "utc": utc, "phase": "S4 paper/count/isolated validation complete; ready for independent design review",
        "base_r13": frozen["tree_sha256"], "native_baselines": 4,
        "paper_sha256": sha(HERE / "PAPER.json"), "counts_sha256": sha(HERE / "COUNT.json"),
        "design_review_sha256": sha(HERE / "DESIGN_REVIEW_REQUEST.json"),
        "validation_sha256": sha(HERE / "ISOLATED_VALIDATION.json"),
        "live_tool_sessions": [], "native_layout_implementation_authorized": False,
        "next": "Coordinator routes independent soundness/privacy design check; resolve mask/rank/endpoints/zero-group handling and native census before implementing an isolated new profile. R13 review separate. T256 desktop only; no laptop-fit claim.",
    })
    excluded = {"evidence.sha256.json", "ISOLATED_VALIDATION.done"}
    write("evidence.sha256.json", {p.name: sha(p) for p in sorted(HERE.iterdir()) if p.is_file() and p.name not in excluded})
    (HERE / "ISOLATED_VALIDATION.done").write_text("0\n")
    print(json.dumps({"status": report["status"], "frozen_source_unchanged": 269,
                      "honest_cfs_pcs_microproofs": 24, "bad_microproofs_rejected": 192,
                      "native_scalar_equivalences": 104, "review_packet_sha256": sha(HERE / "DESIGN_REVIEW_REQUEST.json")}))


if __name__ == "__main__":
    main()
