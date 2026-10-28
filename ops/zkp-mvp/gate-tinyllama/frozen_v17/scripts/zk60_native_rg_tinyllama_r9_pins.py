#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v17, 2026-10-20, gate round 14: DD, native R9] The
READINGS behind every source pin of the bundles captured from the gate's copy
of the native lane's frozen R9 tree, which the earlier readings do not cover.
They are merged at the same definition sites as the R5b, R7, tk7 and tk9
readings, one marked line each.  No existing digest or reading changes; the
merge refuses a digest that is already present.

THE TREE.  `ops/zkp-mvp/trained-1b-gate-r9/` is an rsync of
`results/zk60_1b_native_20261017/r9/frozen-tree/` (tree af90c703..., 222 of
222 files equal to `r9/manifest_frozen.json`), plus the gate's TEST-ONLY
capture patch H-1..H-5 (`round14/DD_CAPTURE_HOOK_REQUEST.md`): three files,
`run_capture.rs`, `plane_index.rs` and `run_capture_tests.rs`, all
`#[cfg(test)]` (`private_block.rs:220-230`).  Every production file is
byte-equal to R9.

R9 = native R8 + DD, the per-row division dictionary (register D30; D24
review r9 ACCEPTED it on soundness at the three DD profiles,
`results/zk60_d24_review_20261017/R9_VERDICT.md`).  A capture pins 46 files;
32 are byte-identical to the R7 pins read in v8.  The other 14 are read
here, each against the closest digest this gate has read:

* the nine files R8 did not change (protocol, argument, layout, shape,
  wire, hash_domain, witness, pad, trained_statement): frozen-r7's bytes,
  which the earlier readings hold, so each R9 reading is R9's own hunk;
* run.rs, private_block.rs and trained_block.rs, which the token lane also
  touched: read against frozen-r7's digest (the token r7c readings), the
  token lane's hunks being ABSENT in native R9 and R9's DD hunks added;
* the gate's two patched test-only files, read against R9's own.

THE PROFILE GATE [READ].  Every R9 change is branched on `sh.dd_cap > 0`, a
field set only for the three DD profiles (`shape.rs` R9 `DD_PROFILES`).  At
every other profile the slots, the plane lists, the 50 mask rows, the 34
functionals, the schedule and the transcript are R8's; the native lane's
`r9_golden_tests.rs` asserts the non-DD byte identity, and D24 r9 confirmed
it.  So the existing ports' transcriptions stay valid for non-DD bundles at
these digests; at a DD bundle the DD slots are ported separately in v17
(`zk60_native_rg_terminals.ports_for`: SC_SZC's DD arm and SC_DD).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate-r9 "
        "(the native lane's frozen R9 tree af90c703 + the privacy-gate lane's test-only "
        "DD capture patch H-1..H-5; sources manifest round14/trained-1b-gate-r9.sources.v1.sha256)",)
R9_BUNDLES = ("dd-rung-l1-dense", "dd-rung-l1-zero", "dd-rung-l2-dense", "dd-rung-l2-zero",
              "tl128dd-l1-dense", "tl128dd-l1-zero", "tl128dd-l2-dense", "tl128dd-l2-zero")

RUN_RS = "cf80735dbea505fef939abb91ed23ed5d4b74d2a9a1464727f6f7058dfc11339"
RUN_CAPTURE_RS = "c24b32c68cc83441163da1ffe5393af9fb5ebe70c54fadfdb4c6bab6bb9082f3"
PLANE_INDEX_RS = "0fe9eb4d3cd83fc742de9c3f889cb498bd7ad51fcbc5e4ca9414542828d57222"
ARGUMENT_RS = "112352bc35c8b877cba50707a5ea64ea239ec6c684becb193ad981bd643ff4f5"
LAYOUT_RS = "9332802e597beacab56cfa69cfe18325bc476d2ce6485f517051992b26d26efa"
PROTOCOL_RS = "c482402329e4da32a70c780435b2077e8054d1805b1006289f571820017564a4"
SHAPE_RS = "e214db86945e0b9df8336edc7974041ebcfe77f2f1884a565a77a0392fca1165"
PAD_RS = "20afa04f6418b4f14050736f55e21d7cf15718e4632323b30427f1c21ec5b4a8"

# the report-only pins (no gate port transcribes them), each read
REPORT_ONLY = {
    "src/private_block/wire.rs": (
        "f312067871bb87dc93436263b5820e5f3fb9a9623f190efc924023a28c5d41d0",
        "read against `c8c13033` (R8 = frozen-r7): +14 / -14, ten hunks, every one "
        "`N_SLOTS` -> `lay.n_slots()` or `M_ROWS` -> `lay.m_rows()` in the segment "
        "size, the slot-count refusal, the mask-column length refusal and the two "
        "parsers (prover and verifier).  23 and 50 at every non-DD profile"),
    "src/private_block/hash_domain.rs": (
        "2012142194303e3b7d4bf0757d89621ae9d78c000cd5b58aac33de43bd946214",
        "read against `da61c1d9`: +4 / -2, one hunk in `imposed_at_shape`'s census: "
        "the slot-term lengths over `0..sh.n_slots()` and the IO condition `s == "
        "SC_IO_IN || s == SC_IO_OUT` (was `s >= SC_IO_IN`; equal over 0..23).  No "
        "domain, label or key moves"),
    "src/private_block.rs": (
        "5e50acd54e7e3e4926b03e9e329073116f278ad203fdcd175e3230464041432c",
        "read against `08551c3d` (native R8; frozen-r7's `45286ae8` is it plus the "
        "token lane's `mod token_io` and CLI re-exports, absent here): +43 / -1.  "
        "Two `#[cfg(test)]` module lines (r9_golden_tests, r9_tests); "
        "`AttentionPublic::dd_e_column(cap)` / `dd_e_column_of(exp, cap)`: "
        "sorted({0} U exp outputs) padded with 0 to cap, refused by name above cap "
        "(D30 (6)); `BlockPublic::check_for_shape` calls it at a DD shape only"),
    "src/private_block/witness.rs": (
        "d1a859187b58ac12c9bda0b0c98c25d85d24d87b6100724fd9d697f9b7fad607",
        "read against `130f6301`: +147 / -7, four hunks.  A `#[cfg(test)]` DD cheat "
        "(off in release); the `Dom::Dd` position list; the score entry's division "
        "limbs written only off DD; at DD, per (h, t) row and per slot k of the e "
        "column, q = e_k 2^F_P / Sum, rho, sigma = Sum - 1 - rho range-checked, "
        "P_dict and its limbs written, and M_dd counting each score entry's (mask E) "
        "column position.  Off DD every plane is R8's"),
    "src/private_block/trained_statement.rs": (
        "ac61bf90cc0d93da24c6049d6be61e7d7b9d75c662ca3817d855692de777cb52",
        "read against `e623c227`: +2 / -2, one hunk: the TinyLlama / Llama-3-8B "
        "family tests also admit the DD profiles.  The identity encoder and `check` "
        "are outside it"),
    "src/private_block/trained_block.rs": (
        "357e27974e4f3c8224cb0aca9e52a56d2e4ebef68b22e7e255febf2b3048628d",
        "read against `0943bade` (frozen-r7 = native R8 `cc401eb4` plus the token "
        "lane's ten `fn` -> `pub(crate) fn` visibility changes, absent here): R9's "
        "hunks are the DD geometries (TinyLlamaDd, Llama3_8BDd, RungDdDev), "
        "`Geometry::dd()` (refused by name off T128 / the DD rung), `is_dd`, their "
        "run profiles, scope string and shape constructors (the DD rung fixes f_e "
        "12), the trained door's cap refusal (D30 (6)) and the CLIs' `--dd` flag.  "
        "Without `--dd` no geometry is DD"),
}

RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        RUN_RS: {
            "blob": "13e61011dd0090dc90fbdb78c5ad4341648faabf",
            "commits": TREE,
            "bundles": R9_BUNDLES,
            "bytes": 78868,
        },
    },
    "src/private_block/run_capture.rs": {
        RUN_CAPTURE_RS: {
            "blob": "a08b1e5010b1518cebb82244bcafafcdc3234e8e",
            "commits": TREE,
            "bundles": R9_BUNDLES,
            "bytes": 92248,
            "pins_g2": True,
            "pins_nr4d": True,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs", RUN_RS):
        "[TINYLLAMA PORT v17, gate round 14] read against `2c158dc9` (frozen-r7, the "
        "token r7c reading) and native R8's `d913a081`.  Native R9 has none of the "
        "token lane's hunks (the TOKEN_IO profile constants, their shape arms, the "
        "blocks-only refusal, `token: None`).  R9's hunks against R8, +19 / -1, five: "
        "three DD run-profile constants (TinyLlama T128, Llama-3-8B T128, the DD "
        "rung); their `registered_block_shape` arms; the DD block profiles' run "
        "profiles in `run_profile_of`; `RunShape::rung_dd`; `M_ROWS` -> `lay.m_rows()` "
        "in the commitment row list (50 off DD).  The header, the stage order, the "
        "boundary absorb, the position tags, the opening order and `stage_shape` are "
        "outside them",
    ("src/private_block/run_capture.rs", RUN_CAPTURE_RS):
        "[TINYLLAMA PORT v17, gate round 14] the gate's TEST-ONLY patch, read against "
        "R9's own `e1c87a07` (= native R8's `1d43d68c` plus one line: `run.json`'s "
        "slot list takes `n_slots` entries).  H-1: the stage close compares the "
        "stage's own `lay.n_slots()` (was the constant 23).  H-2: `n_slots` is "
        "`sh.n_slots()`, and at a DD shape six public geometry keys (dd_cap, dd_log, "
        "dd_helpers, tag_dd, m_rows, n_functionals), each on the allow-list.  The "
        "gate's trained-calibration shape keys (the R5b patch, line for line) and the "
        "README's trained-weights sentence.  The recorder's own transcript replay, "
        "the slot record, the plane-order check and every allow-list entry before "
        "these are unchanged; `SHARED_SOURCE_FILES` pins G-2's and N-r4-d's three",
}

TERMINALS_ALSO_ACCEPTED = {
    "src/private_block/layout.rs": {
        LAYOUT_RS:
            "[TINYLLAMA PORT v17, gate round 14] read against `ee871fff` (R8 = "
            "frozen-r7): +184 / -32, 26 hunks, every one DD-gated or a widening "
            "that is the identity off DD: `Dom::Dd`; `Ids::new`'s DD segment table "
            "(the p / rho_s / sigma_s limbs move to Dom::Dd between P_dict and M_dd, "
            "after the feed-forward planes); `HIds` gains `stuple` (Dom::S), the Dd "
            "helpers and `gdd`, and `is_table` includes `gdd`; `lookups_at` puts the "
            "division limbs on Dom::Dd at DD; `SC_DD = 23`, `MAX_SLOTS = 24`, "
            "`TAG_DD = 141`, a 24th SLOT_NAMES / SLOT_KINDS entry (Standalone); "
            "`slot_terms`' IO condition `==` (equal over 0..23); the Layout arrays "
            "sized MAX_SLOTS and every prefix over `n_slots`; `m_rows`, "
            "`lookup_doms`; the schedule's dictionary line (DD only).  Off DD the "
            "plane lists, slots, sites and lookups this port transcribes are R8's",
    },
    "src/private_block/protocol.rs": {
        PROTOCOL_RS:
            "[TINYLLAMA PORT v17, gate round 14] read against `85ca8931` (R8 = R7): "
            "+133 / -7, eleven hunks.  `logup_sum_claim` skips the two DD columns "
            "only under a `#[cfg(test)]` lapse (constant false in release); "
            "`dd_tuples` / `dd_misses` / `refuse_dictionary_misses` and CS-3 for the "
            "dictionary in the sealing pass and in `prove_core` before the A mask "
            "draws (DD only); `M_ROWS` -> `lay.m_rows()` in three phase marks; at DD "
            "the H columns `stuple` and `gdd` written (every dictionary slot "
            "inverted on every attempt, D30 (4)); `Ctx` carries `g_dd = gamma "
            "TAG_DD` on both sides.  `transcript()`'s absorbs, the (beta, gamma, "
            "alpha) draw, the slot loop, the commitment calls and the openings are "
            "outside every hunk",
    },
    "src/private_block/plane_index.rs": {
        PLANE_INDEX_RS:
            "[TINYLLAMA PORT v17, gate round 14] the gate's TEST-ONLY patch H-3, read "
            "against `13a7dd6f` (R7..R9).  At a DD shape only: the A and H name "
            "tables in `Ids::new` / `HIds::new`'s DD order (A_PDICT, A_PL*, A_SR*, "
            "A_SG* and A_MDD on Dom::Dd after the feed-forward block; H_STUPLE after "
            "H_SEXP; H_DD* and H_GDD after H_FACT); the slot loop over "
            "`lay.n_slots()`; the IO condition `s == SC_IO_IN || s == SC_IO_OUT`; "
            "slot 23's push order (a_range(P_dict, M_dd), A_SUM, the Dd helpers, "
            "gdd) and SC_SZC's DD push order (A_S8..A_P, A_MX, A_SUM, the S helpers, "
            "H_SEXP, H_STUPLE).  Off DD every list is the R7 one",
    },
}

TERMINALS_PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        SHAPE_RS:
            "[TINYLLAMA PORT v17, gate round 14] read against `8c62519c` (R8 = "
            "frozen-r7): +201 / -36, 25 hunks.  The three DD profiles and their "
            "geometries (`DD_CAP = 32`); `dd_cap` set only for them and "
            "`check_dd_geometry` (unpadded heads, tokens and dictionary; cap a power "
            "of two); `Dom::Dd`'s log and size; the DD branches of `a_plane_doms`, "
            "`h_plane_doms`, `lookups_per_position`, `claim_sites` (slot 23: the Dd "
            "A planes + A_SUM, the Dd helpers + gdd; SC_SZC +1 H); `BASE_DEGREE`'s "
            "24th entry (4); `slots` / `slot_terms` / `slot_lengths` over "
            "`n_slots`; `n_slots`, `m_rows`, `n_functionals` (+2 at DD), A groups "
            "+2 and H groups +1 at DD; `lookup_doms`.  Off DD every value this port "
            "reads is R8's",
    },
    "src/private_block/pad.rs": {
        PAD_RS:
            "[TINYLLAMA PORT v17, gate round 14] read against `4f0c11c5`: +10 / -3, "
            "five hunks.  `Dom::Dd`'s bit forms (h, t | k) and its host / indicator "
            "slot SC_DD, listed for totality: a DD dictionary never pads "
            "(`check_dd_geometry`), so no pad term is built for it; a test-only "
            "array widened to MAX_SLOTS.  Every non-DD indicator is R8's",
    },
}

MASK_LAYER_PINS = {
    "src/private_block/argument.rs": {
        ARGUMENT_RS: {
            "commits": TREE,
            "bundles": R9_BUNDLES,
            "reading": "[TINYLLAMA PORT v17, gate round 14] read against `02df55eb`: "
            "+179 / -2.  The slot loop runs `0..sh.n_slots()` and the functional "
            "guard is `sh.n_functionals()` (23 / 34 off DD); `run_slot`'s "
            "M-functional block, `fn sum_weights` and the host order are outside "
            "the hunks, so the declared functional order is round 8's with SC_DD's "
            "two functionals (eval, Gamma: a Standalone slot) in slot order",
        },
    },
    "src/private_block/layout.rs": {
        LAYOUT_RS: {
            "commits": TREE,
            "bundles": R9_BUNDLES,
            "reading": "[TINYLLAMA PORT v17, gate round 14] see the terminals "
            "reading; for this port: `M_ROWS = 2 N_SLOTS + 4` stays 50 and the "
            "layout's `m_rows()` is `2 n_slots + 4` (52 at DD); `mask_specs` over "
            "`slots()` (n_slots entries); SLOT_KINDS' 24th entry Standalone",
        },
    },
    "src/private_block/shape.rs": {
        SHAPE_RS: {
            "commits": TREE,
            "bundles": R9_BUNDLES,
            "reading": "[TINYLLAMA PORT v17, gate round 14] `Shape::slots` over "
            "`n_slots` (slot 23 on Dom::Dd, base degree 4), `n_functionals` 34 + 2 "
            "at DD, `m_rows` 2 n_slots + 4; ruling C-4's budget is unchanged",
        },
    },
}

ARGUMENT_DEFINITIONS = {
    ARGUMENT_RS: (
        "repaired",
        "[TINYLLAMA PORT v17, gate round 14] read against `02df55eb` (R8 = R7, the "
        "repaired definition): +179 / -2, six hunks.  `#[cfg(test)]` DD lapse "
        "switches (`dd_lapse` is the constant false in release); `Ctx.g_dd`; the "
        "DD arm of SC_SZC (`if sh.dd_cap > 0`: no division clause, one tuple "
        "lookup) and SC_DD (the dictionary zero-check), both refusing a pad term; "
        "the slot loop over `n_slots` and the functional guard `n_functionals`.  "
        "The bilinear arms SC_SCORE / SC_PV, every non-DD arm and every push "
        "order outside DD are byte-identical -- stage 20's repaired definition",
    ),
}
