#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v5, 2026-10-17 round 4] The READINGS behind every
source pin the trained TinyLlama T32 bundles captured from the native lane's
FROZEN R5 tree carry, in ONE place -- the companion of
`zk60_native_rg_tinyllama_pins` (round 1, the pre-port tree), merged at the
same six definition sites, one marked line each, after round 1's.  No
existing digest or reading is changed or removed; the merge refuses a digest
already present.

HOW EACH FILE WAS READ.  The R5 bundles are written from
`ops/zkp-mvp/trained-1b-gate-r5/`: an rsync of
`results/zk60_1b_native_20261017/r5/frozen-tree/` (frozen 2026-10-17T19:48:50Z,
tree sha256 d67fae7e..., all 217 files equal to `r5/manifest_frozen.json`)
plus this lane's test-only capture code (sources manifest
`results/zk60_gate_tinyllama_20261017/r5/trained-1b-gate-r5.sources.v1.sha256`,
patch `.../r5/trained-1b-gate-r5-vs-frozen-r5.v1.patch`).  Every pinned file
that differs from round 1's capture tree is read as the plain `diff -u`
against the digest round 1 READ (`zk60_native_rg_tinyllama_pins`), hunk by
hunk, with the counts measured by `diff -u | grep -c`.  The R5 changes are
the native lane's rounds 3-5: the T64 / T128 / Llama-3-8B profiles, the
streaming block source, parallel exact witness arithmetic, phase-clock byte
counters, the CS-1 / 3 / 4 / 6 / 7 / 8 / 9 and S38-F1(a) port (finding G-1 of
this lane), the re-review R2-a / R2-b refusals and the r3_6 bounded segment
reader.  The question asked of every hunk: does it move an absorb, a draw, a
published byte, a slot's polynomial, a row, a plane or a coefficient a port
transcribes?  The answer, file by file, is below; for every file it is no.

WHAT A READING DOES NOT SAY.  That the Rust is right.  Every computed stage is
still a computation on the bundle's bytes; the replay re-derives every
challenge from them.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate-r5 "
        "(the native lane's frozen R5 tree d67fae7e + the privacy-gate lane's "
        "test-only capture code; sources manifest sha256 5a48ad4c)",)
R5_BUNDLES = ("tinyllama-trained-r5-capture-dense-l2",
              "tinyllama-trained-r5-capture-zero-l2",
              "tinyllama-trained-r5-capture-dense-l1",
              "tinyllama-trained-r5-capture-zero-l1",
              "tinyllama-trained-r5-capture-dense-l22",
              "tinyllama-trained-r5-capture-zero-l22")

LINEAGE_G1_R5 = (
    "the R5 tree carries the 125M lane's rulings CS-1, CS-3, CS-4, CS-6, "
    "CS-7, CS-8, CS-9 and S38-F1(a) (native round 5, `cs_port_tests.rs`, "
    "suite `r5-suite2` green at 19:48 UTC).  It does NOT carry CS-2 (the "
    "undersized `wrho_s` / `norm_wrho` override refusal) or CS-5 (the width "
    "bound), nor the stage-36 draw observers and the stage-47 root-rebuild "
    "check: owed by the native lane, not ported by this gate")

# --------------------------------------------------------------------------
# zk60_native_rg_runpins.RUN_LAYER_PINS and READINGS
# --------------------------------------------------------------------------
RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        "05302591f969f95cd8369a263ea1f387e5ebca37c76c8914f972699b3ff285d1": {
            "blob": "08ba468b3ba0be33d5df3e3719ebc164920f055f",
            "commits": TREE,
            "bundles": R5_BUNDLES,
            "bytes": 70440,
        },
    },
    "src/private_block/run_capture.rs": {
        "9c5f844bb2dcd0ff57dc43191aed2029ba4316e2f687186645944494447d1f95": {
            "blob": "1d124e61a30fc1dcc53215f1334d8c7c31d3942e",
            "commits": TREE,
            "bundles": R5_BUNDLES,
            "bytes": 89297,
            # this writer's SHARED_SOURCE_FILES carries finding G-2's three
            # prover-path files, so a bundle it wrote must pin all three
            "pins_g2": True,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs",
     "05302591f969f95cd8369a263ea1f387e5ebca37c76c8914f972699b3ff285d1"):
        "[TINYLLAMA PORT v5, round 4] read against `296aeaaf` (round 1): "
        "`diff -u` is **+347 / -30, 15 hunks**, none of them at an absorb.  "
        "(1) run-profile constants for the trained T64 / T128 / Llama-3-8B "
        "shapes (the T32 string is unchanged, so the transcript constructor "
        "length H-8 is unchanged); (2) ruling CS-8: `RunShape` / "
        "`RunStatement::rs` fields made private with read accessors; (3) "
        "ruling CS-7: `registered_block_shape`, the run-profile registry, "
        "checked in `RunShape::new` (a refusal); `tinyllama_trained` "
        "dispatches a trained shape to its own run profile; (4) CS-1 / CS-4 "
        "re-checks (`blocks_fit_the_shape`, `policy_fits_the_shape`) in "
        "`new_with_calibration`, `new_bound` and the run prover / verifier "
        "entries, before anything is absorbed; `new_bound` now delegates to "
        "`new_bound_from_digests` (the same digests, the same calibration "
        "word); (5) ROUND 4's `BlockSource` / `SliceBlocks` / `BlockRef`: "
        "block `k` comes from a source that hands the SAME `&BlockPublic` "
        "(a slice, or a streaming cache checked against the statement's "
        "digest); `prove_run` / `verify_run` / `verify_run_from_dir` wrap "
        "`*_with` variants over `SliceBlocks`; (6) ruling CS-6: "
        "`as_many_blocks_as_the_statement`, `blocks_are_the_statements`, "
        "`digest_is_the_statements` -- refusals before the header exists "
        "(the prover's skipped only under the cfg(test) cheating switch); "
        "(7) phase-clock marks (`ph.mark` / `ph.mark_bytes`, write-only, "
        "inert without HL_PB_TIMING); (8) review r3_6: "
        "`read_segment_bounded` replaces an unbounded `std::fs::read` of a "
        "segment file in `verify_run_from_dir_with` (the counted length "
        "checked from metadata before the open; a verifier DoS fix, not a "
        "transcript change).  **Outside every hunk**: `RunStatement::"
        "transcript`'s six header absorbs in order (`run-shape`, "
        "`expected-IO`, `public-statement`, `parameters`, `calibration`, "
        "`schedule`), `position_tag`, the per-stage `pb-run-stage` / "
        "`pb-run-block` absorbs in the prover and in `RunVerifier::step`, "
        "`BOUNDARY_SITES`, `boundary_spec`, `in_site` / `out_site`, "
        "`SegGeom` and the opening order.  The replay re-derives every "
        "challenge from the bundle",
    ("src/private_block/run_capture.rs",
     "9c5f844bb2dcd0ff57dc43191aed2029ba4316e2f687186645944494447d1f95"):
        "[TINYLLAMA PORT v5, round 4] read against `c69e5776` (round 1, the "
        "same writer with this lane's additions): `diff -u` is **+9 / -1, "
        "two hunks**, both the native lane's finding-G-2 change: "
        "`SHARED_SOURCE_FILES` 23 -> 26, the three zkp-core files "
        "`pcs/encode_buffer.rs`, `sumcheck/rounds.rs`, `sumcheck/grouped.rs` "
        "APPENDED LAST (so no index into `source_pins` moves) with their "
        "comment.  This lane's additive capture code (the trained shape keys, "
        "their allow-list entries, the README sentence) is byte-identical to "
        "round 1's.  Nothing the loader reads moved",
}

# --------------------------------------------------------------------------
# zk60_native_rg_runpins: the three prover-path files finding G-2 asked the
# writer to pin (checked by `check_shared_pins` ONLY when a bundle pins them,
# so no earlier record gains a leaf)
# --------------------------------------------------------------------------
SHARED_G2_PINS = {
    "../zkp-core/src/pcs/encode_buffer.rs": {
        "sha256": "3c01433d84507cddadcf5c1387c08948fd3efe853a066d74690c0a6e1ce3dd70",
        "depended_on_by": "no port transcribes it; the blinding reproduction "
        "and the hash layer re-check the encoding by COMPUTATION on every "
        "opened column",
        "reading": "[TINYLLAMA PORT v5, round 4; finding G-2] read in round 1 "
        "(the same bytes, now pinned): `encode_rows`, per row, inverse-NTTs "
        "the message, writes `(coeff_i - pad_i) * pow_i` for i < Q, the pad "
        "row `pad_i - pad_{n+i}` (n+i < Q) else `pad_i` times `pow_{n+i}`, "
        "zeros, then forward-NTTs -- term for term `encode_row_zk`'s "
        "arithmetic.  It READS pads the caller (`zkp-core/src/pcs.rs`, "
        "pinned) drew before any branch; it draws nothing and absorbs "
        "nothing",
    },
    "../zkp-core/src/sumcheck/rounds.rs": {
        "sha256": "c60520596e6d855687e0a225850850c12bd15b8741522de69a624f0db8a003df",
        "depended_on_by": "no port; the replay re-derives every challenge "
        "from the PUBLISHED rounds",
        "reading": "[TINYLLAMA PORT v5, round 4; finding G-2] a prover-side "
        "round EVALUATOR (`prove_rounds`, `SumcheckRounds`, "
        "`ClosureRounds`): it computes the round polynomials the existing "
        "`CfsMasker` masks and publishes (`zk.rs::masked_prove_rounds`, "
        "pinned); the published rounds and their absorbs are the masker's, "
        "which the mask port and the replay check",
    },
    "../zkp-core/src/sumcheck/grouped.rs": {
        "sha256": "7777a19c8db97694c51e66c78d1a7688573158bddaa7fcb370345ebd14ab669b",
        "depended_on_by": "no port; slot 17's verifier polynomial is read in "
        "argument.rs (ARGUMENT_DEFINITIONS)",
        "reading": "[TINYLLAMA PORT v5, round 4; finding G-2] the grouped "
        "equality evaluator (`EqualityGroup`, `GroupedEqRounds`) slot 17's "
        "prover uses; round 1 read that the verifier's polynomial is the "
        "same function as the old closure.  A prover-side evaluator: it "
        "publishes nothing of its own",
    },
}

# --------------------------------------------------------------------------
# zk60_native_rg_terminals.ALSO_ACCEPTED / PINNED_IF_PRESENT
# --------------------------------------------------------------------------
TERMINALS_ALSO_ACCEPTED = {
    "src/private_block/layout.rs": {
        "ee871fff7eed377cafcb05ec0438df95a70695ae8fdcd5b5822f5f40663b0ee9":
            "[TINYLLAMA PORT v5, round 4] read against `bfd3677b` (round 1): "
            "**+42 / -0, two hunks, ADDITIONS ONLY, both refusals**: ruling "
            "CS-8's `Layout::check_is_for_shape` (the ten row fields against "
            "`Layout::for_shape(sh)`; absorbs nothing, draws nothing) and, in "
            "`Layout::for_shape`, re-review R2-a's refusals (a "
            "trained-calibration profile string without the trained door's "
            "flag; `Shape::check_softmax_window`).  `lookups_at` (and the "
            "trained top-limb coefficients round 1 ported), `N_SLOTS`, "
            "`N_FUNCTIONALS`, `M_ROWS`, every plane order and row count, "
            "`domain_log_at` and the `(beta, gamma, alpha)` draw are outside "
            "both hunks",
    },
    "src/private_block/protocol.rs": {
        "7cf6e486d67c7e84377cad1f12151ee2f4630c9ca3ddd65c2f2d61cfebf8f78b":
            "[TINYLLAMA PORT v5, round 4] read against `efb3dff1` (round 1): "
            "**+115 / -8, 12 hunks**.  (1) ruling CS-3: `u8_misses_of`, "
            "`LOOKUP_MISS_REFUSAL`, `refuse_lookup_misses` and the cfg(test) "
            "`CheatingProver`; `prove_core` counts exp / activation misses "
            "beside the existing histograms and refuses ANY miss after the "
            "three histograms and BEFORE the first draw of the A mask rows, "
            "the A commitment and any absorb of the block's body (an honest "
            "admissible witness has none, so its path is unchanged); (2) "
            "CS-8 / CS-1 / CS-4 re-checks (`check_constructed`, "
            "`check_is_for_shape`, `check_for_shape`) at every proving and "
            "verifying entry and in `prove_core` / `verify_core`, before "
            "anything is drawn or absorbed; (3) R2-a: "
            "`single_block_profile_allowed` refuses by profile string as well "
            "as by flag; (4) phase-clock byte counters (`ph.mark_bytes`, "
            "write-only).  `transcript()`'s absorbs, "
            "`check_opening_challenges`, the slot loop, the `(beta, gamma, "
            "alpha)` draw, the A / H / M commitment calls and every row count "
            "are outside every hunk",
    },
}

TERMINALS_PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        "38d32443fb9399a7c2d2de501ef2fa0d73a696ed54dd254842756f7480b273d7":
            "[TINYLLAMA PORT v5, round 4] read against `a53e2fe2` (round 1): "
            "**+289 / -39, 19 hunks**.  (1) the T64 / T128 / Llama-3-8B "
            "profile strings, their RoPE bases and `TRAINED_CALIBRATION_"
            "PROFILES` 2 -> 5; (2) ruling CS-9: `REGISTERED_BLOCK_SHAPES`, "
            "`registered_block_shape`, `trained_geometry` and "
            "`block_profile_names_this_shape` in `Shape::new` (a refusal); the "
            "nine frozen constructors and the trained ones now call the "
            "private `Shape::build` (every refusal of the old `Shape::new` but "
            "CS-9's), and `Shape::tinyllama_trained(32, ..)` builds through "
            "`trained_geometry` with EXACTLY round 1's parameters (the T32 "
            "name and profile string, T 32, width 2048, hidden 5632, 32 heads "
            "of 64 over 4, row width 2^12, rate 4, the handed f_e, 21 "
            "endpoint rows = (32 * 2048 >> 12) + 5, no overrides) before "
            "`with_trained_calibration`; (3) ruling CS-8: "
            "`check_constructed` (rebuild and compare; computes no digest); "
            "(4) R2-a: `check_softmax_window`.  `true_size`, `pads`, "
            "`head_slot`, `clog2`, `Shape::slots`, `a_groups`, `h_groups`, "
            "`h_plane_doms`, `hash_tag`, `NormCalibration`, "
            "`derive_at_width`, `with_trained_calibration`, "
            "`check_trained_class` and ruling C-4 are outside every hunk; "
            "every dimension is re-derived from `run.json[\"shape\"]` and "
            "compared with the shape's own `slots` array",
    },
}

# --------------------------------------------------------------------------
# zk60_native_rg_gqa.ARGUMENT_DEFINITIONS
# --------------------------------------------------------------------------
ARGUMENT_DEFINITIONS = {
    "02df55ebec4da046d5522dfc14bf17a691c1fca851f014ba50a759502804e3b5": (
        "repaired",
        "[TINYLLAMA PORT v5, round 4] read against `9b26bda8` (round 1, the "
        "repaired definition at the trained constants): **+5 / -3, one "
        "hunk**, inside `argument()`'s slot loop: the phase clock's "
        "`ph.slot(slot, cube, \"cube\")` becomes `ph.slot_work(slot, cube * "
        "n_tabs)` with `n_tabs = def.tabs.len()` read from the slot's "
        "definition AFTER `define` returns.  `ph` is write-only and returns "
        "on its first line without HL_PB_TIMING (the module's own STAGE-11 "
        "note), so no definition, challenge, table or terminal depends on "
        "it.  Every slot closure, the trained constants round 1 ported, the "
        "bilinear arms, the push order of every private table, `run_slot`, "
        "the M-functional block and the `N_FUNCTIONALS` guard are "
        "byte-identical -- stage 20's repaired definition",
    ),
}

# --------------------------------------------------------------------------
# zk60_native_rg_mask.MASK_LAYER_PINS
# --------------------------------------------------------------------------
MASK_LAYER_PINS = {
    "src/private_block/argument.rs": {
        "02df55ebec4da046d5522dfc14bf17a691c1fca851f014ba50a759502804e3b5": {
            "commits": TREE,
            "bundles": R5_BUNDLES,
            "reading": "[TINYLLAMA PORT v5, round 4] the one hunk against "
            "`9b26bda8` is the phase clock's counter in `argument()`'s slot "
            "loop; `run_slot`'s M-functional block, `fn sum_weights(sh, "
            "slot)`, `acc.fs.extend(hosts)` and the `N_FUNCTIONALS` guard are "
            "outside it, so the DECLARED functional order is round 8's",
        },
    },
    "src/private_block/layout.rs": {
        "ee871fff7eed377cafcb05ec0438df95a70695ae8fdcd5b5822f5f40663b0ee9": {
            "commits": TREE,
            "bundles": R5_BUNDLES,
            "reading": "[TINYLLAMA PORT v5, round 4] two refusal hunks "
            "(CS-8's `check_is_for_shape`, R2-a in `for_shape`); `N_SLOTS = "
            "23`, `N_FUNCTIONALS = 34`, `M_ROWS = 2 * N_SLOTS + 4` and their "
            "assertions are outside both",
        },
    },
    "src/private_block/shape.rs": {
        "38d32443fb9399a7c2d2de501ef2fa0d73a696ed54dd254842756f7480b273d7": {
            "commits": TREE,
            "bundles": R5_BUNDLES,
            "reading": "[TINYLLAMA PORT v5, round 4] `Shape::slots` and "
            "ruling C-4's refusal are outside all 19 hunks (registry, CS-8 / "
            "CS-9, new profiles, the `build` refactor, the softmax window)",
        },
    },
}

# --------------------------------------------------------------------------
# REPORT-ONLY own files (no port transcribes them)
# --------------------------------------------------------------------------
REPORT_ONLY_OWN_FILES = {
    "src/private_block/trained_statement.rs": (
        "cab092a083d1c9b9665c1331985ac8962102a5b8e241138de5fcff704ffce9a6",
        "against `ace96145` (+96 / -20, 9 hunks): the Llama-3-8B shard pins "
        "and `shards_digest`, `ModelSource::llama3_8b` / "
        "`pinned_for_profile`, the RoPE base pinned per profile, "
        "`LayerRecord::unhashed` (the proving-pass reload record), the nine "
        "padded-word SHA-256s computed in parallel (same bytes, same order), "
        "and R2-b's cfg(test)-only synthetic waiver field (not part of the "
        "encoding).  The replay reproduces `run_binding` from "
        "`run.json[\"calibration\"]`; no port transcribes the file"),
    "src/private_block.rs": (
        "1c2825860bfbd9e047d39de4f55820926b2edecd4e419b4a26e128762c301762",
        "against `8c1d056b` (+156 / -12, 11 hunks): cfg(test) module "
        "declarations (`witness_speed_tests`, `r4_tests`, `cs_port_tests`), "
        "the CS-1 / CS-4 / CS-8 statement checks (`check_words` / "
        "`check_for_shape` of the attention and feed-forward halves, S38-F1(a) "
        "`act[128] == 0` where Dom::F pads, `IoSpec::check_for_shape`, the "
        "pinned scales) and a parallel pre-scan in the support check (same "
        "verdict).  `ExpectedIo::to_bytes` (absorbed by the run header) is "
        "outside every hunk"),
    "src/private_block/witness.rs": (
        "130f6301ba1118a9dd90f852d8bd5adf076ef4222fb58eb0e1b17a3c0a83de94",
        "against `73a06441` (+126 / -16, 3 hunks): the matrix products and "
        "the per-head score sums made PARALLEL (exact integer sums, "
        "bit-identical to the sequential form, which is kept as a cfg(test) "
        "reference), and the CS-1 / CS-4 checks before the input is read.  A "
        "capture carries no witness; the dense captures check parity with the "
        "export's reference output bit for bit at every layer"),
}


def merge_two_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{path: {digest: entry}}` WITHOUT changing an existing entry."""
    for path, digests in add.items():
        slot = into.setdefault(path, {})
        for d, entry in digests.items():
            if d in slot:
                raise ValueError(f"{table}: {path} {d[:12]} is already read; "
                                 "the R5 pins do not replace a reading")
            slot[d] = entry
    return into


def merge_one_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{key: value}` without replacing an existing key."""
    for key, value in add.items():
        if key in into:
            raise ValueError(f"{table}: {key!r} is already present; the R5 "
                             "pins do not replace a reading")
        into[key] = value
    return into
