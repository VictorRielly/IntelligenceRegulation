#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v6, 2026-10-18 round 5] The READINGS behind every
source pin of the bundles captured from the native lane's frozen R5b tree
that round 4's R5 readings (`zk60_native_rg_tinyllama_r5_pins`) do not
already cover, merged at the same definition sites, one marked line each,
after round 4's.  No existing digest or reading is changed; the merge
refuses a digest already present.

HOW EACH FILE WAS READ.  The R5b bundles are written from
`ops/zkp-mvp/trained-1b-gate-r5b/`: an rsync of
`results/zk60_1b_native_20261017/r5b/frozen-tree/` (frozen
2026-10-18T00:06:31Z, tree 44013397..., all 218 files equal to
`r5b/manifest_frozen.json`) plus this lane's test-only capture code and the
P-12 stage-47 module (mounted under the unpinned `run_capture_tests.rs`;
sources manifest `results/zk60_gate_tinyllama_20261017/r5b/
trained-1b-gate-r5b.sources.v1.sha256`).  Against R5 (whose readings stand),
the pinned files that changed are read as the plain `diff -u` against the R5
digest; the four files R5b pins for the first time (review r4 note N-r4-d,
draft section 5a) are read whole for what the CPU path takes from them.  Of
the files a port transcribes, `layout.rs`, `protocol.rs` and `argument.rs`
are byte-identical to R5 (their R5 readings apply); `shape.rs` changed.

WHAT A READING DOES NOT SAY.  That the Rust is right.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate-r5b "
        "(the native lane's frozen R5b tree 44013397 + the privacy-gate lane's "
        "test-only capture code and stage-47 module; sources manifest 444b948f)",)
R5B_BUNDLES = ("tinyllama-trained-r5b-capture-dense-l2",
               "tinyllama-trained-r5b-capture-zero-l2",
               "tinyllama-trained-r5b-capture-dense-l1",
               "tinyllama-trained-r5b-capture-zero-l1",
               "tinyllama-trained-r5b-capture-dense-l22",
               "tinyllama-trained-r5b-capture-zero-l22")

RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        "c192fd33d41e1d3244ad9e076f7e450145dad29168038991319124309e1e35ad": {
            "blob": "f0c89230a2bb5834a860c045d27c050a6fecc93f",
            "commits": TREE,
            "bundles": R5B_BUNDLES,
            "bytes": 73795,
        },
    },
    "src/private_block/run_capture.rs": {
        "31557a2722997d900bcf21e67f3aa312b9bf7f70ea81a0212470c32602c5be6f": {
            "blob": "e3f3e223d90db0851a1b6f77c9069f5622101878",
            "commits": TREE,
            "bundles": R5B_BUNDLES,
            "bytes": 90312,
            # this writer pins finding G-2's three files AND review r4's
            # N-r4-d three, so a bundle it wrote must pin all six
            "pins_g2": True,
            "pins_nr4d": True,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs",
     "c192fd33d41e1d3244ad9e076f7e450145dad29168038991319124309e1e35ad"):
        "[TINYLLAMA PORT v6, round 5] read against `05302591` (R5, read in "
        "round 4): `diff -u` is +52 / -1, five hunks.  (1) the run-profile "
        "constants of the trained Llama-3-8B shapes at T64 and T128 and their "
        "two entries in the CS-7 registry and in `tinyllama_trained`'s "
        "dispatch; (2) the trained-profile list of `new_with_calibration`'s "
        "refusal gains the two strings; (3) review r4's r4_B: "
        "`read_regular_file_bounded`, a bounded reader for the files the CLI "
        "and the MVP driver read by path (refuses a non-regular file and an "
        "over-long one before the open).  **Outside every hunk**: the six "
        "header absorbs, `position_tag`, the per-stage absorbs, "
        "`prove_run_with` / `RunVerifier` and the boundary rules; at the "
        "TinyLlama T32 profile no byte of a run moves",
    ("src/private_block/run_capture.rs",
     "31557a2722997d900bcf21e67f3aa312b9bf7f70ea81a0212470c32602c5be6f"):
        "[TINYLLAMA PORT v6, round 5] read against `9c5f844b` (R5 + this "
        "lane's capture additions): +26 / -10, four hunks, all review r4's "
        "N-r4-d: `SHARED_SOURCE_FILES` 26 -> 29 (`src/gpu/mod.rs`, "
        "`src/tables_v3.rs`, `../zkp-core/src/tables.rs`, appended LAST), "
        "`OWN_SOURCE_FILES` 16 -> 17 (`src/private_block/trained_block.rs`, "
        "appended LAST), `NOT_ON_THE_RUNS_PATH` 3 -> 2 (trained_block.rs "
        "leaves it), and a doc comment.  This lane's additions (the trained "
        "shape keys, their allow-list entries, the README sentence) are "
        "byte-identical; no field, kind, label or order a loader reads moved",
}

# zk60_native_rg_runpins: review r4's N-r4-d files (draft section 5a).
# Required from a writer whose run_capture.rs digest is read as `pins_nr4d`.
SHARED_NR4D_PINS = {
    "src/gpu/mod.rs": {
        "sha256": "d651be2ccf8f19ff75fe6bca5ad42f4b773b569d0ae2017306f0bf819c51b283",
        "depended_on_by": "no port transcribes it; it decides which backend "
        "every commitment's columns go through",
        "reading": "[TINYLLAMA PORT v6, round 5; N-r4-d] read whole for the "
        "CPU build: without `gpu-cuda` the module is the constant-false stub "
        "-- `mod cuda` is `#[cfg(feature = \"gpu-cuda\")]` (:19-20), the "
        "non-feature `seam::backend()` returns `zkp_core::pcs::Cpu` (never "
        "takes over) and `DevStore` is `NoExternal`, `enabled()` is the "
        "constant false and `label()` the fixed off string a trained "
        "statement records (P-7).  `required` / `declines` / `declined` / "
        "`require_live` count and refuse GPU CLAIMS only (fail closed); none "
        "touches a field value.  The CUDA bodies (`cuda.rs`, `kernels.cu`) "
        "are not compiled into a CPU binary and are not pinned (section 5a)",
    },
    "src/tables_v3.rs": {
        "sha256": "726c9355f9e663ef1a43dc9efe17cb2c85aa3583977d0c794dad4cf21a24715d",
        "depended_on_by": "no port; the trained door's SiLU registry check",
        "reading": "[TINYLLAMA PORT v6, round 5; N-r4-d] three lines: a "
        "compatibility adapter, `pub use zkp_core::tables::*;`",
    },
    "../zkp-core/src/tables.rs": {
        "sha256": "8cc95bc8b576907a99f24755cd9d16ea8904cd9ccc514f32f471a95ca8f13e50",
        "depended_on_by": "no port; the trained door admits only an `act` equal "
        "to a member of this registry (review P-15's enforcement claim)",
        "reading": "[TINYLLAMA PORT v6, round 5; N-r4-d] read whole: the frozen "
        "int16-out activation families (`silu-int16out-table-v3`, 9 members; "
        "gelu, 6), each 256 rows over g = -128..=127, S[g] = "
        "clamp(round_half_up(f(g 2^e_in) / 2^e_out)), regenerated from that "
        "formula and CHECKED against frozen spec digests before use (a "
        "platform libm drift is a hard stop).  Row 128 is g = 0 and "
        "silu(0) = 0, so every SiLU member has act[128] = 0 -- the fact P-15's "
        "GS-12 enforcement rests on.  The gate measures act[128] per stage "
        "(E4) independently",
    },
}

TERMINALS_PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        "6c262f59877aee3f7eebd42c7338be2b3bc9ea8d6fa340531f8208df58d3a6ef":
            "[TINYLLAMA PORT v6, round 5] read against `38d32443` (R5): +58 / "
            "-2, five hunks, all the trained Llama-3-8B shapes at T64 and "
            "T128: two profile strings and their list, "
            "`TRAINED_CALIBRATION_PROFILES` 5 -> 7, `llama3_8b_log_cols`, the "
            "RoPE base of the 8B list, two `trained_geometry` entries and "
            "`Shape::llama3_8b_trained` (+ a cfg(test) counted-layout "
            "constructor).  The TinyLlama T32 entry of `trained_geometry`, "
            "`Shape::slots`, `pads`, `true_size`, `hash_tag`, the calibration "
            "and every refusal at the T32 profile are outside every hunk",
    },
}

MASK_LAYER_PINS = {
    "src/private_block/shape.rs": {
        "6c262f59877aee3f7eebd42c7338be2b3bc9ea8d6fa340531f8208df58d3a6ef": {
            "commits": TREE,
            "bundles": R5B_BUNDLES,
            "reading": "[TINYLLAMA PORT v6, round 5] `Shape::slots` and ruling "
            "C-4 are outside all five hunks (the 8B T64 / T128 shapes)",
        },
    },
}

REPORT_ONLY_OWN_FILES = {
    "src/private_block.rs": (
        "e1847bf0445532bb21255580623524b8a435916e140483f90bb5304f004101c0",
        "against `1c282586` (R5): +5 / -0, one cfg(test) module declaration "
        "(`ladder8b_tests`).  `ExpectedIo::to_bytes` and every statement check "
        "are byte-identical"),
    "src/private_block/trained_statement.rs": (
        "ecd7459eaa1e6bfd71b49ad0e9b4c73943f1dada9c85fd78c094f9ddc6d93f29",
        "against `cab092a0` (R5): +1 / -1, `pinned_for_profile` covers every "
        "Llama-3-8B profile.  The encoding and the identity are unchanged"),
    "src/private_block/trained_block.rs": (
        "46d4c5d44e0f1bceca2c9a5804b85aed27892b1152665dff03b4f550e79b70f6",
        "NEW pin (N-r4-d): the trained export reader and CLI.  Against R5 "
        "(+488 / -194, 40 hunks), read for the review's fixes: P-1 -- the "
        "chain is sealed by the witness builder's own pass with its refusals "
        "and the parity check BEFORE the run header (`PARITY_REFUSAL` before "
        "the header), an incomplete run directory is removed and a failed "
        "removal is reported loudly, and an unverified run's statement goes to "
        "`<out>.unverified-statement/`, promoted only by `stack-verify` after "
        "a fresh-process verification; P-5 -- `--seq-dir` reads the hidden "
        "input from a prover-private directory, and a verifier refuses an "
        "export directory holding `seq_*`; P-6 -- one parity refusal text with "
        "no count, position or value, and the sequence-file refusal prints no "
        "digest, size or value; C-R4 -- `--label` is allow-listed; P-7 -- "
        "`statement.json` records `backend`; review r4's r4_A -- each array's "
        "dtype and shape checked before it is read.  The capture harness the "
        "bundles come from builds blocks through `load_layer` (the door's "
        "SiLU-registry and table checks) and does not call the CLI"),
}


def merge_two_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{path: {digest: entry}}` WITHOUT changing an existing entry."""
    for path, digests in add.items():
        slot = into.setdefault(path, {})
        for d, entry in digests.items():
            if d in slot:
                raise ValueError(f"{table}: {path} {d[:12]} is already read; "
                                 "the R5b pins do not replace a reading")
            slot[d] = entry
    return into


def merge_one_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{key: value}` without replacing an existing key."""
    for key, value in add.items():
        if key in into:
            raise ValueError(f"{table}: {key!r} is already present; the R5b "
                             "pins do not replace a reading")
        into[key] = value
    return into
