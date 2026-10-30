#!/usr/bin/env python3
"""[TINYLLAMA PORT, 2026-10-17] The READINGS behind every new source pin the
trained TinyLlama T32 bundles carry, in ONE place.

WHY ONE MODULE.  The gate keeps its pins in six tables across five modules
(`zk60_native_rg_runpins.RUN_LAYER_PINS` / `READINGS` / `SHARED_ALSO_READ`,
`zk60_native_rg_terminals.ALSO_ACCEPTED` / `PINNED_IF_PRESENT`,
`zk60_native_rg_gqa.ARGUMENT_DEFINITIONS`, `zk60_native_rg_mask.
MASK_LAYER_PINS`).  Each of those tables now MERGES the matching dict below
at its own definition site (one marked line each), so every TinyLlama digest
the gate accepts is accepted for exactly the reason written here, and an
auditor reads the whole port's pin discipline in one file.  No existing
digest or reading is changed or removed; a digest outside these tables is
still refused by name.

HOW EACH FILE WAS READ.  The trained bundles are written from
`ops/zkp-mvp/trained-1b-gate/` (no git: an UNCOMMITTED copy of the frozen,
reviewed `trained-1b-review-r2` plus this lane's test-only capture code;
sources manifest `results/zk60_gate_tinyllama_20261017/trained-1b-gate.
sources.sha256`).  That tree descends from the integrator's
`ops/zkp-mvp/candidate/`, whose files are, for every pinned file but four,
byte-identical to a digest this gate already READ (rung-K8 / 125M L=2 era):
`run.rs` f39aec79, `run_capture.rs` d09f3853, `protocol.rs` ac412237,
`layout.rs` 14758039, `shape.rs` dbf4e2bc, `plane_index.rs` 9de8320a,
`pad.rs` f8b1f6c2, `witness.rs` b9b66c02, `wire.rs` 99e69b5c.  So each
reading below is the plain `diff -u` of the candidate file (a READ digest)
against the trained file, classified hunk by hunk, with the counts measured
by `diff -u | grep -c`; `argument.rs`, `zk.rs`, `src/pcs.rs` and the three
zkp-core files are read against the `17830dc` digests of round 9m (the
working files of `/home/victor/wt-zk60-block125m`, digest-checked).  The
`commits` field cannot name a commit: it names the uncommitted tree.

WHAT A READING DOES NOT SAY.  That the Rust is right.  Every computed stage
(the replay, the hash layer, the terminal identity, the ranks, the
preimages) is still a computation on the bundle's bytes; a pin says which
Rust the gate's TRANSCRIPTIONS were compared with.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate "
        "(sources manifest sha256 1a52c5c8; trained-1b-review-r2 + the "
        "privacy-gate lane's test-only capture code)",)
TINYLLAMA_BUNDLES = ("tinyllama-trained-capture-dense-l2",
                     "tinyllama-trained-capture-zero-l2",
                     "tinyllama-trained-capture-dense-l1",
                     "tinyllama-trained-capture-zero-l1")

# Lineage finding G-1, recorded where the pins are: the trained tree does not
# carry the 125M lane's stages 36-45.  None of the missing items moves an
# absorb, a draw or a published byte (the replay re-derives every challenge of
# both trained bundles with the UNEDITED tools -- `probe_before_port/`), but
# each is a hardening the security owner accepted for the run layer.
LINEAGE_G1 = (
    "the trained tree (candidate + lane C + native lane) descends from a "
    "point BEFORE the 125M lane's stages 36-45, so it does not carry: "
    "rulings CS-1 / CS-4 (block and endpoint statements re-checked against "
    "the shape at every proving and verifying entry), CS-3 (the prover's "
    "named refusal of a lookup miss before the A commitment), CS-6 (the run "
    "prover and verifier refuse blocks other than the ones the statement "
    "names), CS-7 (the run-profile registry), CS-8 (sealed RunShape / "
    "RunStatement fields, `check_constructed`, `check_is_for_shape`), CS-9, "
    "S38-F1(a) (`act[128] == 0` at a shape whose Dom::F pads), the stage-36 "
    "draw observer and the stage-45 standalone-block capture writer.  All "
    "are refusals or test hooks; none moves an absorb, a draw or a byte of an "
    "honest receipt")

# --------------------------------------------------------------------------
# zk60_native_rg_runpins.RUN_LAYER_PINS and READINGS
# --------------------------------------------------------------------------
RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        "296aeaafd3bd8a026c93f04f66d5a0dd4c200c81fa31f94e71a86d8d8eebdbe5": {
            "blob": "aaf33b791ef254e015c7161cd5264080987d2f33",
            "commits": TREE,
            "bundles": TINYLLAMA_BUNDLES,
            "bytes": 51941,
        },
    },
    "src/private_block/run_capture.rs": {
        "c69e577621c4c2412a2819b4e0f2ae3c0a7613fb1db69c094d3f3e129cc876c9": {
            "blob": "996d7ea40a611bc22855ecc33db9eddc036913d8",
            "commits": TREE,
            "bundles": TINYLLAMA_BUNDLES,
            "bytes": 88811,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs",
     "296aeaafd3bd8a026c93f04f66d5a0dd4c200c81fa31f94e71a86d8d8eebdbe5"):
        "[TINYLLAMA PORT 2026-10-17] read against `f39aec79` (READ in round "
        "9c/9i; the candidate's own bytes): `diff -u` is **+80 / -7, four "
        "hunks**.  (1) three profile constants: the cfg(test) "
        "`RUN_PROFILE_TINYLLAMA_T32_DEV`, `RUN_PROFILE_TINYLLAMA_T32_TRAINED` "
        "= `hashline-zk-mr1/private-run-tinyllama-1.1b-t32-trained-statement/1` "
        "and `RUN_PROFILE_RUNG_TC`; (2) three `RunShape` constructors calling "
        "the UNCHANGED `RunShape::new`; (3) `RunStatement::new` refuses a "
        "trained-calibration shape or profile, and its body moves into "
        "`new_with_calibration(.., calibration, approved)`; (4) the NEW "
        "`new_bound`, which checks a `TrainedModelStatement` against the "
        "run's own block digests, profile, geometry and scales and passes "
        "`model.identity()` as the run header's `\"calibration\"` word and the "
        "model's scale pair as the approved one.  **What the ports transcribe "
        "is untouched**: `RunStatement::transcript`'s six header absorbs in "
        "order (`run-shape`, `expected-IO`, `public-statement`, `parameters`, "
        "`calibration`, `schedule`) -- only the VALUE of the calibration word "
        "differs at a trained profile, and the replay reads that value from "
        "`run.json[\"calibration\"]` and reproduces `run_binding`; "
        "`prove_run` / `RunVerifier::step`'s per-stage absorbs, "
        "`position_tag`, `BOUNDARY_SITES`, `in_site` / `out_site` and the "
        "opening order are outside every hunk.  Lineage finding G-1: this "
        "file is NOT the 125M lane's `f5f4d571` -- rulings CS-1/4/6/7/8 "
        "(refusals and sealed fields) are absent; the replay of both trained "
        "bundles with the UNEDITED tools re-derived every challenge "
        "(`probe_before_port/`)",
    ("src/private_block/run_capture.rs",
     "c69e577621c4c2412a2819b4e0f2ae3c0a7613fb1db69c094d3f3e129cc876c9"):
        "[TINYLLAMA PORT 2026-10-17] read against `d09f3853` (READ in rounds "
        "9-9m; the candidate's own bytes): `diff -u` is **+67 / -7, five "
        "hunks**, two authors.  NATIVE LANE: `OWN_SOURCE_FILES` 15 -> 16 "
        "(`src/private_block/trained_statement.rs`, appended LAST, so no "
        "index a reader takes into `source_pins` moves) and "
        "`NOT_ON_THE_RUNS_PATH` 1 -> 3 (`trained_block.rs`, `mvp_driver.rs`, "
        "each with its reason).  PRIVACY GATE LANE (additive, cfg(test) like "
        "the whole module): `write_run` appends to `shape` -- ONLY when "
        "`sh.trained_calibration` -- `trained_calibration`, `norm_tn`, "
        "`norm_cn_a`, `norm_cn_m`, `norm_ceps`, `sh_ao`, `sh_qkv`, `sh_s`, "
        "`sh_o`, `sh_g`, `sh_h`, `sh_z`, `d_max` (the empty string at every "
        "other shape, so no bundle of a frozen profile moves a byte); those "
        "13 keys join `ALLOWED_KEYS`; and `write_bundle`'s README sentence "
        "about synthetic weights is replaced, for the two trained run "
        "profiles only, by one about the export's trained words.  **Nothing "
        "the loader already read moved**: `SCHEMA` / `SCHEMA_V5`, the three "
        "kinds, `coverage`, `TRANSCRIPT_LABELS` (19), every existing run- and "
        "stage-file field and its order, the array store, the manifest and "
        "the `source_pins` order",
}

# --------------------------------------------------------------------------
# zk60_native_rg_runpins.SHARED_ALSO_READ (shared files at a second digest)
# --------------------------------------------------------------------------
SHARED_ALSO_READ = {
    "src/zk.rs": {
        "66d1128675bea3b473abd4f2fe70d470b1abc19a7fe5a579a227616d76280e32":
            "[TINYLLAMA PORT 2026-10-17] read against `d4280962` (the bytes "
            "round 8 read): `diff -u` is **+404 / -20, 18 hunks, the first at "
            "line 1058**.  Every function the mask port transcribes -- "
            "`MASK_LOG_MSG` / `MASK_LOG_DOM` / `MASK_Q` (:373-375), "
            "`encode_coeffs_coset` (:424), `mask_commit` (:430), "
            "`mask_commit_tagged` (:481), `combined_weights` (:521), "
            "`weight_polys` (:541), `poly_mul_512` (:550), `mask_open` "
            "(:563), `mask_verify` (:603), `mask_verify_tagged` (:648) -- "
            "lies before the first hunk and is byte-identical.  The hunks: "
            "GPU-decline messages routed through `gpu::declined`; the "
            "additive `masked_prove_rounds` (a prover entry over a round "
            "EVALUATOR that publishes only the existing `CfsMasker`'s rounds; "
            "`masked_prove` is kept as the oracle) and its test module; and "
            "the v3 FEED-FORWARD prover's host staging pool, int8 block fold "
            "and `mr1` probe, which the private block never calls",
    },
    "src/pcs.rs": {
        "8b14096b66f6597e3cdfe239a7359457dd17dfd475c2a5d0f4e112a41342127f":
            "[TINYLLAMA PORT 2026-10-17] read against `f1693267`: **+50 / -9, "
            "two hunks** -- `commit_planes` (a gpu-cuda-feature W-plane "
            "commit for the v3 FFN, `None` without the feature) and a "
            "rewritten doc comment on `commit_zk_owned_tagged`, whose body is "
            "unchanged.  No run-gate port depends on this adapter",
    },
    "../zkp-core/src/pcs.rs": {
        "5c9cfc4e9c84283309f4c47f87d4a9146e2c9c9f5b52aa608b4ce6a7588cd495":
            "[TINYLLAMA PORT 2026-10-17] read against `6b8d1bfa`: **+41 / -23, "
            "six hunks**.  Production: (i) a TAGGED commitment now offers its "
            "columns to `Backend::try_commit_zk_keyed` (a new hook whose "
            "DEFAULT declines; the CPU backend these bundles were made with "
            "does not override it, so the CPU body runs as before); (ii) the "
            "CPU body's encoding moves to `encode_buffer::encode_rows` -- a "
            "NEW, UNPINNED file, read here: per row it inverse-NTTs the "
            "message, writes `(coeff_i - pad_i) * pow_i` for i < Q, the pad "
            "row `pad_i - pad_{n+i}` (n+i < Q) else `pad_i` times `pow_{n+i}`, "
            "zeros, then forward-NTTs -- term for term `encode_row_zk`'s "
            "arithmetic, with the same pads and salts drawn in the same order "
            "before any branch.  `coset_powers`, `hash_column` / `salt_leaf` "
            "and their keyed forms and `verify_zk_tagged`'s path-length rule "
            "(what `zk60_native_rg_pcs` and `zk60_native_rg_hashlayer` "
            "transcribe) are outside every hunk.  The rest is a test rename "
            "and a new test.  The hash layer and the blinding reproduction "
            "re-check the encoding by COMPUTATION on every opened column",
    },
    "../zkp-core/src/pcs/backend.rs": {
        "ff2cb5c1806b34653f8a44ad82f54201fb5d9f6ba2602afe5efeae4d104e0103":
            "[TINYLLAMA PORT 2026-10-17] read against `1734c03c`: **+8 / -0, "
            "one hunk** -- the default `try_commit_zk_keyed` that declines.  "
            "No run-gate port depends on it",
    },
    "../zkp-core/src/sumcheck.rs": {
        "fc7374bbd5e5cc4ede62e8a21d325eb62acff9b9dcc786d12eae39efbdfdbb95":
            "[TINYLLAMA PORT 2026-10-17] read against `56dbb8c7`: **+5 / -0, "
            "one hunk** -- `mod rounds; mod grouped;` and their re-exports "
            "(`prove_rounds`, `ClosureRounds`, `SumcheckRounds`, "
            "`EqualityGroup`, `GroupedEqRounds`), two NEW, UNPINNED "
            "prover-side round evaluators.  `CfsMask::len / sum_weights / "
            "eval_weights / round` (the mask port) and the round absorbs "
            "(the replay) are byte-identical; the replay re-derives every "
            "challenge from the published rounds",
    },
}

# --------------------------------------------------------------------------
# zk60_native_rg_terminals.ALSO_ACCEPTED / PINNED_IF_PRESENT
# --------------------------------------------------------------------------
TERMINALS_ALSO_ACCEPTED = {
    "src/private_block/layout.rs": {
        "bfd3677b849118d8bc114e3bc6aa88ee9d8ef318224cce524060ff6adf698197":
            "[TINYLLAMA PORT 2026-10-17] read against `14758039` (READ in round "
            "9): **+56 / -15, five hunks**, and TWO of them change what this "
            "port transcribes, at a trained profile only.  (1)+(2) "
            "`lookups_at`: the top-limb pin of every windowed requantization "
            "remainder is the SHAPE's `one(sh) = 2^(8 - sh)` or `two(sh) = "
            "2^(16 - sh)` -- RAL `2^(8-sh_ao)`, RDL `one(sh_z)`, RGL "
            "`one(sh_g)`, RH1 `two(sh_h)`, RQL / RKL / RVL `one(sh_qkv)`, RO1 "
            "`two(sh_o)`, RSL `one(sh_s)` -- the historical literals 2, 4, 2, "
            "4, 2, 128, 4 at the frozen shifts, and the RoPE remainders RQRL / "
            "RKRL keep their literal 2.  THIS PORT NOW READS THE SAME "
            "COEFFICIENTS from `run.json[\"shape\"]` (`Calibration` in "
            "`zk60_native_rg_terminals`), frozen values when the bundle "
            "declares no trained calibration, so no frozen bundle's figure "
            "moves.  (3) `Layout::for_shape` refuses a non-frozen calibration "
            "without the trained door and re-runs `check_trained_class` "
            "(refusals).  (4) the schedule's calibration and feed-forward "
            "lines print the trained constants at a trained profile (the "
            "frozen format byte for byte otherwise) -- a public word the "
            "replay reads from `run.json`.  `N_SLOTS`, `N_FUNCTIONALS`, "
            "`M_ROWS`, every plane order and row count, `domain_log_at` and "
            "the `(beta, gamma, alpha)` draw are outside every hunk.  "
            "(Ruling CS-8's `check_is_for_shape`, in the 125M lane's "
            "`64c37a49`, is absent -- lineage finding G-1.)",
    },
    "src/private_block/protocol.rs": {
        "efb3dff181e79d010f7d7b2fbee1e4d2e761f7008f6f8aef1bd1a9281182c75f":
            "[TINYLLAMA PORT 2026-10-17] read against `ac412237` (READ in "
            "round 9b): **+26 / -2, four hunks**: `single_block_profile_"
            "allowed` and its two call sites (a REFUSAL of single-block "
            "receipts at a trained profile, R2-4); an `assert!` of it in "
            "`transcript()` before anything is absorbed; and `parameter_line` "
            "printing `sh.sh_g / sh.sh_h / sh.sh_z` where it printed the "
            "frozen literals (identical at a frozen shape; a public word the "
            "replay reads from `run.json[\"parameter_line\"]`).  "
            "`transcript()`'s absorbs, `check_opening_challenges`, the slot "
            "loop, the `(beta, gamma, alpha)` draw and every row count are "
            "outside every hunk.  (The 125M lane's `974892cc` adds CS-1/3/4/8 "
            "refusals and stage-45 hooks on top of `ac412237`; none is here "
            "-- lineage finding G-1.)",
    },
    "src/private_block/plane_index.rs": {
        "13a7dd6ff1f9178dd640e3d38309a5581a39cf13c9c61238c41ceba83420afbf":
            "[TINYLLAMA PORT 2026-10-17] read against `9de8320a` (the port's "
            "own `PORTED_FROM`): **+6 / -0, one hunk** -- `a_plane_names(sh)`, "
            "a NEW read-only helper over the unchanged `a_segments` / `expand` "
            "(the D16 item-5 audit names planes with it).  `build`, `render`, "
            "`locate` and every segment table are byte-identical",
    },
}

TERMINALS_PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        "a53e2fe2bbfaf8452d1e02d661b1c2e2ba1ff55495cc3e194e4bcdc99c53e45d":
            "[TINYLLAMA PORT 2026-10-17] read against `dbf4e2bc` (READ in "
            "round 9c; the candidate's bytes): **+500 / -0 -- ADDITIONS ONLY, "
            "four hunks**: the trained profile strings and their declared "
            "classes (tn 1..=16, Cn <= 2^20, Ceps <= 2^40, width <= 4096, "
            "sh_ao <= 8, one-limb shifts 1..=8, two-limb shifts 9..=16, f_e "
            "9..=16, wrho_s <= 24, exp e_s -8..=8, RoPE base 10000); "
            "`NormCalibration` (`FROZEN`, `derive_at_width` with D_max = "
            "isqrt(Ceps + width * 32768^2) and wrho = tn + 1 + bits(D_max), "
            "D24); eleven new `Shape` fields set to the frozen values in "
            "`Shape::new`; and the TinyLlama / rung-TC constructors with "
            "`with_trained_calibration` / `check_trained_class`, which REPLACE "
            "`norm_wrho` and `d_max` by the derived values.  `true_size`, "
            "`pads`, `head_slot`, `clog2`, `Shape::slots`, `a_groups`, "
            "`h_groups`, `norm_top_is_full_byte`, `h_plane_doms` and ruling "
            "C-4 are after the last hunk and byte-identical; every dimension "
            "is re-derived here from `run.json[\"shape\"]` and compared with "
            "the shape's own `slots` array.  (The 125M lane's `5acecd8e` "
            "refusals CS-2/5/8/9 are absent -- lineage finding G-1.)",
    },
    "src/private_block/pad.rs": {
        "4f0c11c50503dd8cb4fb38d2b5be5e4f08ec310ee916b83a357f0283ede9eb42":
            "[TINYLLAMA PORT 2026-10-17] read against `f8b1f6c2` (READ in "
            "round 9b): **+3 / -1, one hunk, inside `#[cfg(test)] fn "
            "every_checkable_relation_holds`** (the norm epsilon is the "
            "shape's).  Not one production line moved: `BitForm::of`, "
            "`closed_form_indicator`, `support_indicator`, `indicator_table`, "
            "`zero_rule_a_planes`, `pad_zero_host` and the exempt-plane rule "
            "are byte-identical",
    },
}

# --------------------------------------------------------------------------
# zk60_native_rg_gqa.ARGUMENT_DEFINITIONS
# --------------------------------------------------------------------------
ARGUMENT_DEFINITIONS = {
    "9b26bda8105c1c73d5847a9c02f9ecc07fa7845f8f5769cc3e34ea3d724d160f": (
        "repaired",
        "[TINYLLAMA PORT 2026-10-17] read against `2cee0a22` (READ in round "
        "9j) in two steps.  `2cee0a22 -> candidate b3b02383` is **+65 / -15, "
        "nine hunks**: the stage-45 test hooks removed (3 hunks); `SlotDef` "
        "gains a private `groups` field (`None` everywhere but slot 17); "
        "`run_slot` proves through `masked_prove_rounds` over a "
        "`ClosureRounds` (or, for slot 17, a `GroupedEqRounds`) evaluator, "
        "with a cfg(test) oracle asserting byte-equality with `masked_prove` "
        "on bounded fixtures; and SC_SZC's closure becomes `sum_g v[g] * "
        "bracket(g, v)` with bracket 0 = the old `zc`, 1 = `nu0 * ght * (sum "
        "+ lam)`, 2 = `nu1 * gs * host_s` -- the old closure's three terms "
        "exactly (`g` there IS `gs.at(v)`), so the verifier's polynomial is "
        "the same function.  `candidate -> trained` is **+40 / -16, 14 "
        "hunks, all constants**: SC_TZC's `k(NORM_CEPS)` -> `k(sh.norm_ceps)`; "
        "SC_DZC's `2 Cn` split into `2 cn_a` (norm_a) and `2 cn_m` (norm_m, "
        "clause c6), `2^tn` / `2^(tn+1)` and `2^sh_ao` / `2^sh_z` with "
        "`half(sh) = 2^(sh-1)` (0 at sh = 0); SC_FZC's `2^sh_h` / "
        "`2^sh_g`; SC_QZC / SC_KVZC's `2^sh_qkv` / `2^sh_o`; SC_SZC's "
        "`2^sh_s` -- each the frozen literal at a frozen shape.  THIS PORT "
        "NOW TRANSCRIBES THE SAME CONSTANTS from the bundle's shape "
        "(`Calibration` in `zk60_native_rg_terminals`).  The two bilinear "
        "slots' arms, every other slot's closure, the push order of every "
        "private table, `pad_on`, the `mu` / `nu` / `zeta` draws, `lg`, "
        "`B::supp` / `B::group_eq`, `run_slot`'s M-functional block, "
        "`sum_weights`, `acc.fs.extend(hosts)` and the `N_FUNCTIONALS` guard "
        "are byte-identical -- stage 20's repaired definition",
    ),
}

# --------------------------------------------------------------------------
# zk60_native_rg_mask.MASK_LAYER_PINS
# --------------------------------------------------------------------------
MASK_LAYER_PINS = {
    "src/private_block/argument.rs": {
        "9b26bda8105c1c73d5847a9c02f9ecc07fa7845f8f5769cc3e34ea3d724d160f": {
            "commits": TREE,
            "bundles": TINYLLAMA_BUNDLES,
            "reading": "[TINYLLAMA PORT 2026-10-17] the block this port reads "
            "-- `run_slot`'s M-functional block, `fn sum_weights(sh, slot)`, "
            "`acc.fs.extend(hosts)` and the guard `acc.fs.len() != "
            "N_FUNCTIONALS` -- is outside every hunk of both steps "
            "(`2cee0a22 -> candidate -> trained`; see "
            "`ARGUMENT_DEFINITIONS` in this module), so the DECLARED "
            "functional order is the one round 8 read.  `run_slot` now proves "
            "through `masked_prove_rounds`, which publishes the same "
            "`CfsMasker`'s masked rounds",
        },
    },
    "src/private_block/layout.rs": {
        "bfd3677b849118d8bc114e3bc6aa88ee9d8ef318224cce524060ff6adf698197": {
            "commits": TREE,
            "bundles": TINYLLAMA_BUNDLES,
            "reading": "[TINYLLAMA PORT 2026-10-17] `N_SLOTS = 23`, "
            "`N_FUNCTIONALS = 34`, `M_ROWS = 2 * N_SLOTS + 4` and their two "
            "assertions are outside all five hunks (the trained top-limb "
            "coefficients, the trained door's refusals and the trained "
            "calibration line), so M has fifty rows and thirty-four "
            "functionals at the trained shape too",
        },
    },
    "src/private_block/shape.rs": {
        "a53e2fe2bbfaf8452d1e02d661b1c2e2ba1ff55495cc3e194e4bcdc99c53e45d": {
            "commits": TREE,
            "bundles": TINYLLAMA_BUNDLES,
            "reading": "[TINYLLAMA PORT 2026-10-17] ADDITIONS ONLY against "
            "`dbf4e2bc`; `Shape::slots` (every `(n_s, d_s)` this port turns "
            "into `L_s`) and ruling C-4's refusal are byte-identical.  The "
            "prediction derives the largest `L_s` and the C-4 headroom at the "
            "trained shape before the run",
        },
    },
}

# --------------------------------------------------------------------------
# REPORT-ONLY own files (no port transcribes them; recorded so the record
# names every digest the trained bundles carry)
# --------------------------------------------------------------------------
REPORT_ONLY_OWN_FILES = {
    "src/private_block/trained_statement.rs": (
        "ace961453a63467b2e377c0ecbdc48da29283324f93459bf9e201d141a703968",
        "NEW pin (native lane): the trained-model statement whose "
        "`identity()` a bound run absorbs as its `calibration` word.  No port "
        "transcribes it: the replay takes the word's VALUE from "
        "`run.json[\"calibration\"]` and reproduces `run_binding` from it, "
        "which is the machine check that the value the bundle declares is "
        "the one absorbed.  That the identity binds the export, the layer "
        "records and the calibration is the D24 review's statement, not this "
        "gate's"),
    "src/private_block.rs": (
        "8c1d056b72c49e0d43572ccf3e472642a44c9bcc51c543b0773c4cea44bceb7c",
        "the module root.  Against the candidate's `9540a7e6` (+47 / -0, five "
        "hunks): the trained modules, the CLI re-exports, cfg(test) test "
        "modules, `ExpectedIo::from_bytes_at` and two "
        "`single_block_profile_allowed` refusals.  The CS-1/CS-4/CS-8 "
        "statement checks of the 125M lane's `2764a7ec` are absent (G-1).  "
        "Nothing is transcribed"),
    "src/private_block/witness.rs": (
        "73a06441e7d8d1720da3e6ad0421fdca8a481235de26fe746f7bbb4e28f6a3f5",
        "against `b9b66c02` (+25 / -15, eleven hunks): `rms_norm` takes "
        "`tn`, `Ceps` and the per-site `Cn` from the shape, every "
        "`quantize` takes the shape's shift, and a cfg(test) forgery hook "
        "(review D24).  A capture carries no witness; read by no port"),
    "src/private_block/wire.rs": (
        "c8c13033f341ed40bd524091cfe870be3cb54433de566a6d9f4078c15cac374f",
        "against `99e69b5c` (+21 / -3, four hunks): a 256 MiB transport "
        "ceiling for trained profiles (`wire_ceiling`).  No port decodes a "
        "segment"),
}


def merge_two_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{path: {digest: entry}}` into a gate table WITHOUT changing an
    existing entry: a digest already present is a refusal (a reading is
    never silently replaced)."""
    for path, digests in add.items():
        slot = into.setdefault(path, {})
        for d, entry in digests.items():
            if d in slot:
                raise ValueError(f"{table}: {path} {d[:12]} is already read; "
                                 "the TinyLlama port does not replace a reading")
            slot[d] = entry
    return into


def merge_one_level(into: dict, add: dict, table: str) -> dict:
    """Merge `{key: value}` without replacing an existing key."""
    for key, value in add.items():
        if key in into:
            raise ValueError(f"{table}: {key!r} is already present; the "
                             "TinyLlama port does not replace a reading")
        into[key] = value
    return into
