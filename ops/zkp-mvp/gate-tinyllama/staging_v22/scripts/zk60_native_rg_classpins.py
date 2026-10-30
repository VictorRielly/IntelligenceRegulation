#!/usr/bin/env python3
"""[GATE ROUND 16, tools v19, 2026-10-21] The READINGS of the token lane's
round-12 (rung R-C1) source changes against frozen-r11, as a classifier
capture will pin them, read PRE-FREEZE on the working copy at manifest_r12B
(`results/zk60_token_io_r1_20261017/manifest_r12B.sha256`, list sha256
edbffc75..., 245 files).  When the round-12 tree freezes, each digest is
checked against the frozen manifest; a different digest has no reading here
and is refused by name.

Against frozen-r11 (manifest_final_r11, d8075d76...) round 12 changes three
PINNED files, additively (0 lines removed, 27 added:
`classifier/rc1_pinned_files_additive.diff`), and adds eight files (the
classifier stages, run, CLI and tests, and `examples/zk60_classify.rs`).  No
block or run RELATION file changes; the next-token stages are untouched.

The classifier port (`zk60_native_rg_classterminals`, `zk60_native_rg_classify`)
was transcribed from the four files in `CLASSIFY_PORTED_FROM`; a classifier
bundle pinning another digest of any of them is refused before any slot is
evaluated (the token port's rule).

[v21, gate round 18] the R-C2 / R-C3 readings at token frozen-r14
(`CLASSIFY_R14_READINGS`, `CLASSIFY_PORTED_FROM_V21`) and the v21 pin rule
(`classify_capture_pins_v21`): the native files moved by the rebase onto R12b
chain through `zk60_native_rg_tinyllama_r12b_pins.NATIVE_R12B_READINGS` to
digests the BLOCK gate read (v17's native R9 readings); an R-C1 capture is
refused by name (REVIEW_R13 N-r13-8: R-C1 receipts support no classifier
claim).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

MANIFEST = "results/zk60_token_io_r1_20261017/manifest_r12B.sha256"
MANIFEST_LIST_SHA256 = "edbffc75"

# the three pinned files round 12 moves, each read against frozen-r11's digest
CLASSIFY_R12_READINGS = {
    "src/private_block.rs": {
        "a9727239c5669ae08481ab2fd2bd0f12479a63f10658501132fc306a305d3a9a": {
            "base": "45286ae8f3be17da7f0938cec7ed0d689ba80f2ffda1d73d3b9329b3b25c3130",
            "diff_stat": "+2 / -0, 1 hunk against 45286ae8 (frozen-r11)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "ADDITIVE: one `pub use token_io::classify_cli::{...}` line (the classifier CLI "
                       "bridge for `examples/zk60_classify.rs`) with its comment. No item of a block, "
                       "run or token run changes",
        },
    },
    "src/private_block/run.rs": {
        "10cfc2b1aa2fb2e288300aeb924a9f2c3ae012d1e975707eb15c66a4875c2e6d": {
            "base": "cc2c420498b114273c4e67874c500b0f0fb3a0256e6ccef0a171f438ba0f3226",
            "diff_stat": "+12 / -0, 2 hunks against cc2c4204 (frozen-r9 = frozen-r11)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "ADDITIVE: a new profile string `RUN_PROFILE_CLASSIFY_RUNG_TC` (65 characters, the "
                       "token rung's length, admitted by the W-2 census) with `CLASSIFY_RUN_PROFILES` "
                       "(one entry), and one `registered_block_shape` arm mapping it to `Shape::rung_tc` "
                       "(the token rung's shape). Every existing arm, TOKEN_IO_RUN_PROFILES (still 5), the "
                       "header, the stage order, the boundary absorb, the position tags and the schedule "
                       "lines are byte-identical: every block and token profile builds what it built",
        },
    },
    "src/private_block/token_io.rs": {
        "057137a2d308555ed5c6642ffc7d080847d8025d86afdaabfc6cb393d2350849": {
            "base": "7730c8d01bd85b916be81a176f3aeb4238d426748a99aef7075f3630e0a00fb4",
            "diff_stat": "+13 / -0, 2 hunks against 7730c8d0 (frozen-r11)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "ADDITIVE: five `pub(crate) mod` declarations (classify, classify_run, "
                       "classify_cli, stage_in_c, stage_out_c) and two `#[cfg(test)] mod` declarations "
                       "(classify_tests, classify_cli_tests), with comments. StageLayout, the slot "
                       "builder, run_stage_slot, the verifier's slot loop, TokenProfile and the tables are "
                       "byte-identical",
        },
    },
}

# [v20, gate round 17] the frozen round-12 tree (frozen-r12, manifest_final_r12,
# list f2436b15...; = manifest_r12C) and the CAPTURE tree (frozen-r12 + the
# round-16 capture hooks, every hook `#[cfg(test)]` or insert-only): each
# moved file read against its frozen-r12 digest, which is in turn read
# against frozen-r11 above (or, for a classifier file, is the v19 reading's
# digest or an additive test-only step from it).  READ 2026-10-26 ~19:20 UTC
# with `diff -u` between results/zk60_token_io_r1_20261017/frozen-r12/ and
# the working copy ops/zkp-mvp/token-io/ (= every one of the captures' 56
# pins, checked file by file).
FROZEN_R12_MANIFEST = "results/zk60_token_io_r1_20261017/manifest_final_r12.sha256"
FROZEN_R12_LIST_SHA256 = "f2436b15"
HOOKED_READINGS = {
    "src/private_block/token_io/classify.rs": {
        "5d2c642a60d1d7e77ec8caa32b5dfed7a6815e706f3c7ec35293c3d6a3786cda": {
            "base": "fe1d9bd77e992ffa9c1af06e82c78dcaf95144bc8d25e7d627099fc65fc9bd10",
            "diff_stat": "+108 / -0, 1 hunk against fe1d9bd7 (frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: `#[cfg(test)] capture_header()` (the run header with ClassifyFacts: "
                       "the run-shape words, policy, c, margin-vector and embedding digests, final norm, "
                       "window and limbs, LAM_BASE, tier, the input endpoint and boundaries, the verdict and "
                       "the chunk) and `#[cfg(test)] binding()`. No production line changes",
        },
        "fe1d9bd77e992ffa9c1af06e82c78dcaf95144bc8d25e7d627099fc65fc9bd10": {
            "base": "dd31955296cbc8b041a7ef26ad3136d3350c30ac66517729ced7ecad671732b8",
            "diff_stat": "+32 lines before the door, all under `#[cfg(test)]` (token lane PROGRESS 17:33: "
                         "registered_classify_runs, census_classify_statement); the r12B copy is not kept, "
                         "so this step is checked by the unchanged text of every item the port reads "
                         "(chunk_ranges, ChunkRef::bytes, C_MAX, LAM_BASE, the window, is_template, kappa, "
                         "ctl, ctl_q, describe_under, transcript) [READ]",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: the registry census helpers",
        },
    },
    "src/private_block/token_io/classify_run.rs": {
        "be2ccd1c97f1f5be48046dd6caf50441bfd37e8fc26f24db562b33a5011e450b": {
            "base": "56fcccef973883dae1bd44b33aa7d9c3f2f51c67ef0078fff0ceb0dd889a013b",
            "diff_stat": "+46 / -0, 4 hunks against 56fcccef (frozen-r12 = the v19 reading)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: `#[cfg(test)]` stage_begin_stage / stage_end around stage IN-C, each block "
                       "and stage OUT-C; the boundary opening wrapped in checkpoint + pcs(Geom) with its claim "
                       "sources; run_accepted after OUT-C",
        },
    },
    "src/private_block/token_io/stage_in_c.rs": {
        "05c1aae265195c130f35a5cab358eb99ca16341e10708c70539761c110914707": {
            "base": "7bc3c30b5f201c28882c1d15a3e23fbc928394145f8cbcc129d44ce5f6df9824",
            "diff_stat": "+38 / -0, 2 hunks against 7bc3c30b (frozen-r12 = the v19 reading)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: start_slot before each define; checkpoint + mask / pcs around M_in, A-in, "
                       "H-in and the input endpoint; `capture_planes` (A_TOK, A_MULT / H_Q, H_TAB, H_U; roles "
                       "A-in, H-in, E-token-in, B-in). `define` and every relation unchanged",
        },
    },
    "src/private_block/token_io/stage_out_c.rs": {
        "ee1cd2374ef37dbce52b68267ba3b53518fa85c6d14b40940cb92892d5da80da": {
            "base": "46cb695192cf7a878f3d2a83a92c99f5c21b4ce4073811da51b01ded24b7760b",
            "diff_stat": "+70 / -0, 2 hunks against 46cb6951 (frozen-r12 = the v19 reading)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: start_slot; checkpoint + mask / pcs around M_out, A-out, H-out and B-out "
                       "(B-out's claim sources: the last block's SC_IO_OUT, then OUTC-00); `capture_planes` "
                       "(16 A / 9 H names; roles A-out, H-out, B-out, none). `define` and every relation unchanged",
        },
    },
    "src/private_block/run.rs": {
        "ebc64fd159030036f126ad895e3d57442429ebe369c5b2d59f724ebd05e04fcd": {
            "base": "10cfc2b1aa2fb2e288300aeb924a9f2c3ae012d1e975707eb15c66a4875c2e6d",
            "diff_stat": "+2 / -0, 1 hunk against 10cfc2b1 (frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "CAPTURE-ONLY: `classify: None` in the block run's capture_header RunHeader",
        },
    },
    "src/private_block/token_io.rs": {
        "f6e56c818f0a70f609751700e37946a1236e99183dc71f31c10b74030d727a53": {
            "base": "057137a2d308555ed5c6642ffc7d080847d8025d86afdaabfc6cb393d2350849",
            "diff_stat": "+3 / -0, 1 hunk against 057137a2 (frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: `#[cfg(test)] mod classify_capture_tests;`",
        },
    },
    "src/private_block/token_io/run.rs": {
        "477cfc8ce45070ec44d846ff19e05045978d045396a1735aad0e5c56e3c1f439": {
            "base": "4671d03edea02468403066bbc33e0a117f5d3cbe6cfd142110718bb48f7fcfca",
            "diff_stat": "+2 / -0, 1 hunk against 4671d03e (frozen-r9 = frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "CAPTURE-ONLY: `classify: None` in the token run's capture_header RunHeader",
        },
    },
    "src/private_block/run_capture.rs": {
        "d1e25882ea0a74d15a70ed6982319f79883f24ac83f893c6a63b29ea288d81c5": {
            "base": "aaff4e6e20c4deca7a0342f5b7dd2b9ac53a2837432af72f57c8a852e479db5e",
            "diff_stat": "+564 / -0 (insert-only, 13 hunks) against aaff4e6e (frozen-r7 .. frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "CAPTURE WRITER, insert-only: RunHeader.classify (ClassifyFacts) and its header "
                       "re-check (classify-verdict, classify-chunk absorbed after schedule); the classifier "
                       "stage begin; write_stage_classify / write_run_classify (schema "
                       "hashline-native-capture/7-classify-run, coverage classify-run-all-stages-v1, "
                       "`classify` replacing `token_io`, no output endpoint); the four classifier source pins; "
                       "the README. Every existing writer path (blocks, token runs) is byte-identical",
        },
    },
}

# [v20] the files the v20 classifier port transcribes: the CAPTURE tree's
# digests (each relation unchanged from the v19 reading: HOOKED_READINGS)
CLASSIFY_PORTED_FROM_V20 = {
    "src/private_block/token_io/classify.rs": "5d2c642a60d1d7e77ec8caa32b5dfed7a6815e706f3c7ec35293c3d6a3786cda",
    "src/private_block/token_io/classify_run.rs": "be2ccd1c97f1f5be48046dd6caf50441bfd37e8fc26f24db562b33a5011e450b",
    "src/private_block/token_io/stage_in_c.rs": "05c1aae265195c130f35a5cab358eb99ca16341e10708c70539761c110914707",
    "src/private_block/token_io/stage_out_c.rs": "ee1cd2374ef37dbce52b68267ba3b53518fa85c6d14b40940cb92892d5da80da",
}

# the files the v19 classifier port transcribes, at manifest_r12B
CLASSIFY_PORTED_FROM = {
    "src/private_block/token_io/classify.rs": "dd31955296cbc8b041a7ef26ad3136d3350c30ac66517729ced7ecad671732b8",
    "src/private_block/token_io/classify_run.rs": "56fcccef973883dae1bd44b33aa7d9c3f2f51c67ef0078fff0ceb0dd889a013b",
    "src/private_block/token_io/stage_in_c.rs": "7bc3c30b5f201c28882c1d15a3e23fbc928394145f8cbcc129d44ce5f6df9824",
    "src/private_block/token_io/stage_out_c.rs": "46cb695192cf7a878f3d2a83a92c99f5c21b4ce4073811da51b01ded24b7760b",
}

# the other new files of round 12 (report-only: no gate port transcribes them)
CLASSIFY_REPORT_ONLY = {
    "src/private_block/token_io/classify_cli.rs": "7c4057589be96d5e5f5fcc5dbe416cf2028af6409285dbd75c51dd0fc9c04a2f",
    "examples/zk60_classify.rs": "10332833db8535ddb14201b81357b1af6c5b0a8a24a85bea4642781a97e97609",
}


# [v21, gate round 18] TOKEN FROZEN-r14 (manifest_final_r14, list
# 0b4c429b..., 258 files; rungs R-C2 + R-C3, rebased onto native R12b).  READ
# 2026-10-29 02:30-03:00 UTC with `diff -u` between the frozen copies
# frozen-r12 -> frozen-r13 -> frozen-r14 (saved under
# results/zk60_gate_tinyllama_20261017/round18/readings/tok-*.diff).  The
# native files the rebase moved are read in `zk60_native_rg_tinyllama_r12b_pins`
# (NATIVE_R12B_READINGS: native R9 -> R12 -> R12b, and the token tree's own
# hunks on top of R12b), whose chains end at native R9 digests the block gate
# read in v17 (`zk60_native_rg_tinyllama_r9_pins`).
FROZEN_R14_MANIFEST = "results/zk60_token_io_r1_20261017/manifest_final_r14.sha256"
FROZEN_R14_LIST_SHA256 = "0b4c429b"
CLASSIFY_R14_READINGS = {
    # ---- the five PORTED classifier files: what moved, and where v21 ports it.
    # They are accepted only at the v21 port's digests (CLASSIFY_PORTED_FROM_V21),
    # never by a chain: R-C2 and R-C3 move receipt bytes at the classifier rung.
    "src/private_block/token_io/classify.rs": {
        "6c828db6673ec389eaa75eef7c543b378ce4f7693dbf70c0c999a6fe959a90ae": {
            "base": "0937952f30a0f351a40f8a914dc87fe239d81e46091b6a47109fe8154a90d2f2",
            "diff_stat": "+132 / -35, 15 hunks against 0937952f (frozen-r13)",
            "moves_a_receipt_byte": True, "moves_a_block_stage_byte": False,
            "reading": "R-C3 (DESIGN v2.4 §15): Policy.pad (rung 2, Shieldstral card 11) and the door's pad < V "
                       "refusal; chunk_ranges returns [(0, total)] for 1 <= total < size and refuses total = 0; "
                       "the door admits P0 + n + S <= T; item_len / pad_positions / verdict_row; kappa = suffix "
                       "id on P0+n..P0+n+S, the PUBLIC pad id after it up to T (is_template unchanged: t >= P0+n); "
                       "tokens_of pads the item; the profile text adds item-length= pad-id= pad-positions= "
                       "verdict-row= and short-content=one-chunk-of-its-length-pad-pinned, and chunk-size is the "
                       "PLAN's size T - P0 - S (was n); the stage line names the verdict row; the D45 rulings "
                       "sentence. R-C3's N-r13-1: ClassifyRunStatement::new / new_chunk take "
                       "BoundClassifierTables, check_for, the plan size from the shape and n == b - a, "
                       "check_tables at prove / verify; ClassifyFacts.tables_derived (test-only capture header). "
                       "Ported in v21: zk60_native_rg_classify (door, kappa, verdict row, chunk_ranges), "
                       "zk60_native_rg_classterminals (ClassCtx, OUTC-00's row), zk60_native_rg_classgate "
                       "(integrity: the new profile-text fields re-derived; D41 with the plan size)",
        },
        "0937952f30a0f351a40f8a914dc87fe239d81e46091b6a47109fe8154a90d2f2": {
            "base": "fe1d9bd77e992ffa9c1af06e82c78dcaf95144bc8d25e7d627099fc65fc9bd10",
            "diff_stat": "+128 / -2, 4 hunks against fe1d9bd7 (frozen-r12)",
            "moves_a_receipt_byte": True, "moves_a_block_stage_byte": False,
            "reading": "the round-12 capture hooks (`#[cfg(test)] capture_header()` / `binding()`, +108, the "
                       "text v20 read at the hooked digest 5d2c642a) and R-C2: Policy.margin_scale_bits (rung "
                       "2^-8; Shieldstral 4.08288030735373e-6) and the profile text's margin-scale= "
                       "margin-scale-bits= and tied-source sentence (moves the classifier profile digest and the "
                       "parameter line: a receipt byte at the classifier rung). Ported in v21: the profile-text "
                       "fields and the tied source read by zk60_native_rg_classtied (B-3 derived)",
        },
    },
    "src/private_block/token_io/classify_run.rs": {
        "5d1d077f510202d17d76c7660a87a5cb6afd7254fc2fc450bf1a39577cb9ebd1": {
            "base": "be2ccd1c97f1f5be48046dd6caf50441bfd37e8fc26f24db562b33a5011e450b",
            "diff_stat": "+24 / -16, 7 hunks against be2ccd1c (frozen-r13 = the v20 hooked reading)",
            "moves_a_receipt_byte": True, "moves_a_block_stage_byte": False,
            "reading": "BoundClassifierTables at prove / verify (st.check_tables replaces the two-digest "
                       "comparison); the owner's check rebuilds the item with tokens_of (pad up to T); the "
                       "honest pipeline reads stage OUT-C's row at verdict_row(). The transcript, the stage "
                       "order, every opening and the boundary wrapping are outside the hunks; the verdict row "
                       "moves OUT-C's IO-in claim at a SHORT item only (T - 1 = verdict_row at full length)",
        },
    },
    "src/private_block/token_io/stage_in_c.rs": {
        "6a92da0ecfe736537f859bcde5eb3fb89c0852e8d06dfe7f21e0feb9c4bbe6ff": {
            "base": "05c1aae265195c130f35a5cab358eb99ca16341e10708c70539761c110914707",
            "diff_stat": "+4 / -2, 2 hunks against 05c1aae2 (frozen-r13 = the v20 hooked reading)",
            "moves_a_receipt_byte": True, "moves_a_block_stage_byte": False,
            "reading": "the module doc and INC-01's SlotSpec NAME ('TEMPLATE (prefix, suffix, trailing pad ids)'), "
                       "which is in the schedule's stage line (a receipt byte); `define`, the template clause "
                       "(its own fresh mu2 over pi * (tok - kappa)), tau_table and the challenge order are "
                       "unchanged: the clause covers the pad positions through kappa / pi (classify.rs). Ported: "
                       "CL.INC_NAMES[1]",
        },
    },
    "src/private_block/token_io/stage_out_c.rs": {
        "93a79a2b39ab1eb70442b6ee7f0d949cfbf20f7c84b660ec4aa4ebe2ef7a564a": {
            "base": "ee1cd2374ef37dbce52b68267ba3b53518fa85c6d14b40940cb92892d5da80da",
            "diff_stat": "+5 / -3, 3 hunks against ee1cd237 (frozen-r13 = the v20 hooked reading)",
            "moves_a_receipt_byte": True, "moves_a_block_stage_byte": False,
            "reading": "the module doc; OUTC-00's SlotSpec NAME (the verdict row); OUTC-00's B_out claim at "
                       "fixed_bits(cp.verdict_row()) (was cp.tokens - 1; equal at full length). Ported: "
                       "CL.OUTC_NAMES[0], classterminals SOC_IO, the classgate joint figure's B_out row",
        },
    },
    "src/private_block/token_io/classify_tied.rs": {
        "401d38d444b6ae2b69d19ab4b2e6a78996521e432303ea551d91889d43a6e76c": {
            "base": "b0eb5047cafd81260fc9ab66cf2df5fe51cbf6e5605e57c5f9e053f1ae6558b0",
            "diff_stat": "+200 / -12, 5 hunks against b0eb5047 (frozen-r13; new there, +332)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "N-r13-1 / N-r13-2 / N-r13-6: BoundClassifierTables (private fields; load_bound_tables; "
                       "check_for; the test-only synthetic_for_relation_tests marked not-derived), the "
                       "Shieldstral recompute stub (cfg(test)), the post-derivation profile-digest check kept. "
                       "derive_dev, dev_tied_tensor_bytes, TiedSource::describe and DEV_TIED_TENSOR_SHA256 are "
                       "byte-identical to r13's [COUNTED: the four items' text compared]; they are what "
                       "zk60_native_rg_classtied transcribes (the tensor regenerated: bba6d094...; the derived "
                       "embedding / margin rows: REVIEW_R13's reference digests c0e816c9... / 24e6ff4c...)",
        },
    },
    # ---- the token-I/O files that are NOT ported: chained, each step moving no receipt byte
    "src/private_block/token_io.rs": {
        "eda64c31babe2efabb47f4f843c8f9061506042d82d469309a2697987d5f5f11": {
            "base": "4a1e967a8448d5ba44bbf680e613e68395b5f6a7322a949bc91d35d494ba0c8e",
            "diff_stat": "+3 / -0, 1 hunk against 4a1e967a (frozen-r13)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: `#[cfg(test)] mod classify_r14_tests;` with its comment",
        },
        "4a1e967a8448d5ba44bbf680e613e68395b5f6a7322a949bc91d35d494ba0c8e": {
            "base": "057137a2d308555ed5c6642ffc7d080847d8025d86afdaabfc6cb393d2350849",
            "diff_stat": "+7 / -0, 2 hunks against 057137a2 (frozen-r12)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "ADDITIVE: `pub(crate) mod classify_tied;` (R-C2) and the two test-only modules "
                       "`classify_tied_tests`, `classify_capture_tests` (the latter the v20 hooked reading "
                       "f6e56c81's +3). StageLayout, the slot builder, run_stage_slot, the verifier's slot "
                       "loop, TokenProfile and every table are outside the hunks",
        },
    },
    "src/private_block/token_io/load.rs": {
        "a9b72811350e1042392b0a8b60bcffddcd01a6b8a39cfa32f97ce4f72cb030dc": {
            "base": "8c0417214a15ed45afafe89a345609dedfd622fe45fb9b007a8782ed4344935e",
            "diff_stat": "+2 / -0, 1 hunk against 8c041721 (frozen-r12 = frozen-r9)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "the token loader's Provenance gains `rope_scaling: ex.rope_scaling` (native R12's F1 "
                       "field, R12-F3: refused / encoded only when the export declares a RoPE transform; the "
                       "trained-statement identity encodes it only when it is not `none`, per the native "
                       "trained_statement.rs R12 reading in NATIVE_R12B_READINGS). No rung, TinyLlama or "
                       "classifier export declares one, so no identity byte moves at those profiles",
        },
    },
    "src/private_block/run_capture.rs": {
        "ef9c54dbdf9588df381055b6f959ee8d7a9f8396075c59bf2b774115b76cb012": {
            "base": "2329306125671947d877431b33636c6f2dcfbe9a73f89c9d5586e4087647712f",
            "diff_stat": "+11 / -0, 2 hunks against 23293061 (frozen-r13)",
            "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "reading": "CAPTURE WRITER, insert-only: ClassifyFacts.tables_derived (not serialized: run.json's "
                       "`classify` keys are unchanged, checked on the r14 captures) and the replay's refusal of "
                       "a classifier header whose tables are not derived (N-r13-1: no capture of the relation "
                       "tests' synthetic tables is written). Every existing writer path and the allow-list are "
                       "byte-identical",
        },
    },
}

# [v21] the files the v21 classifier port transcribes, at token frozen-r14
CLASSIFY_PORTED_FROM_V21 = {
    "src/private_block/token_io/classify.rs": "6c828db6673ec389eaa75eef7c543b378ce4f7693dbf70c0c999a6fe959a90ae",
    "src/private_block/token_io/classify_run.rs": "5d1d077f510202d17d76c7660a87a5cb6afd7254fc2fc450bf1a39577cb9ebd1",
    "src/private_block/token_io/stage_in_c.rs": "6a92da0ecfe736537f859bcde5eb3fb89c0852e8d06dfe7f21e0feb9c4bbe6ff",
    "src/private_block/token_io/stage_out_c.rs": "93a79a2b39ab1eb70442b6ee7f0d949cfbf20f7c84b660ec4aa4ebe2ef7a564a",
    "src/private_block/token_io/classify_tied.rs": "401d38d444b6ae2b69d19ab4b2e6a78996521e432303ea551d91889d43a6e76c",
}
# report-only at r14 (no gate port transcribes them; not pinned by a capture)
CLASSIFY_REPORT_ONLY_V21 = {
    "src/private_block/token_io/classify_cli.rs": "c1862e4b13f8ec3da3a931941ef6978c02ec7f12dbbe4b48653831a77c8abb68",
}


def _token_accepts(f, d):
    """does the token gate (v18) accept digest d of file f"""
    import zk60_native_rg_tokenio_r7c_pins as TP
    import zk60_native_rg_tokenio_r9_pins as R9
    import zk60_native_rg_tokenio_r11_pins as R11
    return (d in TP.TOKEN_R7C_READINGS.get(f, {}) or d in R9.TOKEN_R9_READINGS.get(f, {})
            or d in R11.TOKEN_R11_READINGS.get(f, {}) or TP.R7_PINS_READ_IN_V8.get(f) == d)


def _block_gate_accepts(f, d):
    """[v21] does the block gate accept digest d of file f: a digest one of
    its ports was read at (the terminals port's PORTED_FROM / ALSO_ACCEPTED /
    PINNED_IF_PRESENT / ARGUMENT_DEFINITIONS, the run layer's RUN_LAYER_PINS),
    or a report-only digest of the native R9 readings (v17)"""
    import zk60_native_rg_runpins as RP
    import zk60_native_rg_terminals as T
    import zk60_native_rg_tinyllama_r9_pins as N9
    if T.PORTED_FROM.get(f) == d or d in T.ALSO_ACCEPTED.get(f, {}) or d in T.PINNED_IF_PRESENT.get(f, {}):
        return True
    if f == T.ARGUMENT_FILE and d in T.ARGUMENT_DEFINITIONS:
        return True
    if d in RP.RUN_LAYER_PINS.get(f, {}):
        return True
    ro = N9.REPORT_ONLY.get(f)
    return bool(ro) and ro[0] == d


def _native_readings():
    try:
        import zk60_native_rg_tinyllama_r12b_pins as N12
    except ImportError:
        return {}
    return getattr(N12, "NATIVE_R12B_READINGS", {})


def _reading(f, d):
    for table in (CLASSIFY_R14_READINGS, _native_readings(), HOOKED_READINGS, CLASSIFY_R12_READINGS):
        r = table.get(f, {}).get(d)
        if r is not None:
            return r
    return None


def classify_capture_pins_v20(manifest: dict) -> dict:
    """[v20, kept for the record; v21 does not call it] every `source_pins` entry of a classifier capture: accepted when
    the token gate accepts it, or when it is a ported classifier file at
    the digest the v20 port was read at, or when a chain of written readings
    (HOOKED_READINGS, then CLASSIFY_R12_READINGS) leads from it to a digest
    the token gate accepts, every step moving no receipt byte; refused by
    name otherwise.  Every ported classifier file must be pinned."""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    per, refused = [], []
    for f in sorted(pins):
        d = pins[f]
        if f in CLASSIFY_PORTED_FROM_V20:
            if d == CLASSIFY_PORTED_FROM_V20[f]:
                per.append({"file": f, "sha256": d, "status": "the v20 classifier port's digest"})
            else:
                refused.append(f"{f}: {d[:12]}, the classifier port was read at {CLASSIFY_PORTED_FROM_V20[f][:12]}")
                per.append({"file": f, "sha256": d, "status": "REFUSED"})
            continue
        if _token_accepts(f, d):
            per.append({"file": f, "sha256": d, "status": "read by the token gate (v18)"})
            continue
        chain, cur, ok = [], d, False
        for _ in range(6):
            r = HOOKED_READINGS.get(f, {}).get(cur) or CLASSIFY_R12_READINGS.get(f, {}).get(cur)
            if r is None or r.get("moves_a_receipt_byte") is not False:
                break
            chain.append(f"{cur[:12]} -> {r['base'][:12]}")
            cur = r["base"]
            if _token_accepts(f, cur):
                ok = True
                break
        if ok:
            per.append({"file": f, "sha256": d, "status": "read by a chain of readings: " + "; ".join(chain)})
        else:
            refused.append(f"{f}: {d[:12]} has no reading")
            per.append({"file": f, "sha256": d, "status": "REFUSED"})
    missing = [f for f in CLASSIFY_PORTED_FROM_V20 if f not in pins]
    refused += [f"{f}: not pinned (the classifier port was read from it)" for f in missing]
    return {"pins": len(pins), "per_file": per, "refusals": refused, "ok": not refused}


def classify_capture_pins_v21(manifest: dict) -> dict:
    """[v21] every `source_pins` entry of an R-C2 / R-C3 classifier capture
    (token frozen-r14): accepted when it is a ported classifier file at the
    v21 port's digest; when the token gate or the block gate accepts it; or
    when a chain of written readings (CLASSIFY_R14_READINGS, the native
    R9 -> R12b readings, v20's HOOKED_READINGS, v19's CLASSIFY_R12_READINGS)
    leads from it to such a digest, or to a NEW file's first reading, every
    step saying `moves_a_receipt_byte: False`; refused by name otherwise.
    Every v21-ported file must be pinned, so an R-C1 capture (no
    classify_tied.rs, the port's files at R-C1 digests) is refused by name."""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    per, refused = [], []
    for f in sorted(pins):
        d = pins[f]
        if f in CLASSIFY_PORTED_FROM_V21:
            if d == CLASSIFY_PORTED_FROM_V21[f]:
                per.append({"file": f, "sha256": d, "status": "the v21 classifier port's digest"})
            else:
                refused.append(f"{f}: {d[:12]}, the classifier port was read at {CLASSIFY_PORTED_FROM_V21[f][:12]}")
                per.append({"file": f, "sha256": d, "status": "REFUSED"})
            continue
        if _token_accepts(f, d):
            per.append({"file": f, "sha256": d, "status": "read by the token gate (v18)"})
            continue
        if _block_gate_accepts(f, d):
            per.append({"file": f, "sha256": d, "status": "read by the block gate (v17 native R9 readings and earlier)"})
            continue
        chain, cur, ok = [], d, False
        for _ in range(10):
            r = _reading(f, cur)
            if r is None or r.get("moves_a_receipt_byte") is not False:
                break
            base = r.get("base")
            chain.append(f"{cur[:12]} -> {(base or 'NEW FILE')[:12]}")
            if base is None:
                ok = True
                break
            cur = base
            if _token_accepts(f, cur) or _block_gate_accepts(f, cur):
                ok = True
                break
        if ok:
            per.append({"file": f, "sha256": d, "status": "read by a chain of readings: " + "; ".join(chain)})
        else:
            refused.append(f"{f}: {d[:12]} has no reading" + (f" (chain {'; '.join(chain)} stops)" if chain else ""))
            per.append({"file": f, "sha256": d, "status": "REFUSED"})
    missing = [f for f in CLASSIFY_PORTED_FROM_V21 if f not in pins]
    refused += [f"{f}: not pinned (the v21 classifier port was read from it)" for f in missing]
    return {"pins": len(pins), "per_file": per, "refusals": refused, "ok": not refused,
            "port": "v21 (token frozen-r14)"}


def classify_capture_pins(manifest: dict) -> dict:
    """[v21] the classifier capture pin check is v21's: R-C2 / R-C3
    captures of token frozen-r14 only (`classify_capture_pins_v21`); v20's
    R-C1 rule is kept as `classify_capture_pins_v20` for the record"""
    return classify_capture_pins_v21(manifest)


def check_classify_pins(manifest: dict) -> dict:
    """a classifier capture's `source_pins`: every ported file at its read
    digest, every moved pinned file at a read digest; refusals by name"""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    refused, read = [], []
    for f, d in CLASSIFY_PORTED_FROM.items():
        got = pins.get(f)
        if got is None:
            refused.append(f"{f}: not pinned (the classifier port was read from it)")
        elif got != d:
            refused.append(f"{f}: {got[:12]}, the port was read at {d[:12]}")
        else:
            read.append(f)
    for f, rd in CLASSIFY_R12_READINGS.items():
        got = pins.get(f)
        if got is not None and got not in rd and got not in (r["base"] for r in rd.values()):
            refused.append(f"{f}: {got[:12]} has no reading")
    return {"read": read, "refusals": refused, "ok": not refused}


# =====================================================================
# [v22, gate round 19, 2026-10-29] token frozen-r16b on native R13
# =====================================================================
# The classifier port (`zk60_native_rg_classgate` / `_classify` /
# `_classterminals` / `_classtied` at v22) was READ against these digests of
# token frozen-r16b (manifest_final_r16b, list 04d94bc0...): classify.rs at
# r16b (the R13 stage lines "R13 gate denominator G", `stage_shape` /
# `stage_gate`, the Shieldstral moderate policy list, pad id 11, overlap 8,
# the R13 whole-run term), classify_tied.rs (the Shieldstral tied source),
# classify_run.rs (the pre-header stage check, no transcript byte), and the
# two stage files, unchanged since r14 (the reading sub-lane,
# `zk60_native_rg_r13_pins`).
CLASSIFY_PORTED_FROM_V22 = {
    "src/private_block/token_io/classify.rs": "c180c83fb50f624d15ef9d17dae4195b53161a1131892ea0bb15b0761da99b1d",
    "src/private_block/token_io/classify_run.rs": "8abbf72f1c8e18bea1ac99e93a82562bca793afb4d94ed27dea24403850523f9",
    "src/private_block/token_io/classify_tied.rs": "a89acfabc75c869c1f53d493a5caaa236af1a8df18ba6e30b1f3ab26167c4aaf",
    "src/private_block/token_io/stage_in_c.rs": "6a92da0ecfe736537f859bcde5eb3fb89c0852e8d06dfe7f21e0feb9c4bbe6ff",
    "src/private_block/token_io/stage_out_c.rs": "93a79a2b39ab1eb70442b6ee7f0d949cfbf20f7c84b660ec4aa4ebe2ef7a564a",
}

# the gate's OWN test-only patches in its capture tree (round 19), read here:
# each moves only a `#[cfg(test)]` recorder module, never a prover or
# verifier byte, and chains to the frozen-r16b digest it patched
GATE19_PATCH_READINGS = {
    "src/private_block/plane_index.rs": {
        "ce79803c86a80dde832dc92a262a023efdd52bb95b9a15f128791978c306ffac": {
            "base": "13a7dd6ff1f9178dd640e3d38309a5581a39cf13c9c61238c41ceba83420afbf", "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "classification": "gate test-only patch H19-3 (cfg(test) recorder module)",
            "reading": "[GATE ROUND 19, H19-3] at an R13 accuracy shape `build` names the A planes from "
                       "`AccuracyIds` (prefix A_, domains already matched by `Ids::new` against "
                       "`Shape::a_plane_doms`) and SC_DZC / SC_QZC / SC_KVZC / SC_FZC sweep the whole "
                       "domain range (argument_accuracy.rs `b.a_range(range.start, range.end - 1)`); every "
                       "legacy branch is byte-identical (patch round19/cap/H19-3.plane_index.patch). The "
                       "recorder still compares each slot's ACTUAL private-table order with this list and "
                       "the counts with `Shape::claim_sites`, so a wrong list refuses the capture",
        },
    },
    "src/private_block/run_capture.rs": {
        "8292b1c6856daa521439037570930827ecc3979bd64c279127a2b0f1b6014817": {
            "base": "cad25086949c34d5d338fd1522401486f8099448cce47551f5487d3a05fc0fd7", "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "classification": "gate test-only patch H19-4 (cfg(test) recorder module)",
            "reading": "[GATE ROUND 19, H19-4] `bundle_is_classify` uses `run::is_classify_run_profile` "
                       "(which admits the test-only R13 rung classifier profile) instead of the three "
                       "production CLASSIFY_RUN_PROFILES: an R13-rung classifier bundle is written under "
                       "`7-classify-run` with the five classifier pins (finding F19-1). Production "
                       "profiles: identical (they are in both lists)",
        },
    },
}


def _full(prefix_map):
    """expand the short digests above against the frozen-r16b manifest"""
    import os
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), *([os.pardir] * 5)))
    man = os.path.join(root, "results/zk60_token_io_r1_20261017/manifest_final_r16b.sha256")
    full = {}
    for line in open(man):
        d, p = line.rstrip("\n").split("  ", 1)
        full[p[len("hashline/"):] if p.startswith("hashline/") else p] = d
    out = {}
    for f, d in prefix_map.items():
        want = full.get(f)
        out[f] = want if want and want.startswith(d[:8]) else d
    return out


CLASSIFY_PORTED_FROM_V22 = _full(CLASSIFY_PORTED_FROM_V22)
for _f, _tbl in GATE19_PATCH_READINGS.items():
    for _d, _r in _tbl.items():
        _r["base"] = _full({_f: _r["base"]})[_f]


def _r13_tables():
    try:
        import zk60_native_rg_r13_pins as R13
    except ImportError:
        return []
    return [getattr(R13, k, {}) for k in ("TOKEN_R16B_READINGS", "NATIVE_R13_READINGS", "NEW_R13_READINGS")]


def _reading_v22(f, d):
    for table in [GATE19_PATCH_READINGS] + _r13_tables() + [CLASSIFY_R14_READINGS, _native_readings(),
                                                           HOOKED_READINGS, CLASSIFY_R12_READINGS]:
        r = table.get(f, {}).get(d)
        if r is not None:
            return r
    return None


def classify_capture_pins_v22(manifest: dict) -> dict:
    """[v22] every `source_pins` entry of a classifier capture of token
    frozen-r16b on native R13 (made through the gate's H19 capture tree):
    accepted when it is a ported classifier file at the v22 port's digest;
    when the token gate or the block gate accepts it; or when a chain of
    written readings (the gate's own H19 patch readings, the reading sub-lane's
    r16b / R13 readings, then v21's tables) leads from it to such a digest or
    to a NEW file's first reading, every step `moves_a_receipt_byte: False`;
    refused by name otherwise.  Every v22-ported file must be pinned, so an
    r14 capture (classify.rs at 6c828db6) is refused by name."""
    pins = {p["file"]: p["sha256"] for p in manifest.get("source_pins", [])}
    per, refused = [], []
    for f in sorted(pins):
        d = pins[f]
        if f in CLASSIFY_PORTED_FROM_V22:
            if d == CLASSIFY_PORTED_FROM_V22[f]:
                per.append({"file": f, "sha256": d, "status": "the v22 classifier port's digest"})
            else:
                refused.append(f"{f}: {d[:12]}, the v22 classifier port was read at {CLASSIFY_PORTED_FROM_V22[f][:12]}")
                per.append({"file": f, "sha256": d, "status": "REFUSED"})
            continue
        if _token_accepts(f, d):
            per.append({"file": f, "sha256": d, "status": "read by the token gate (v18)"})
            continue
        if _block_gate_accepts(f, d):
            per.append({"file": f, "sha256": d, "status": "read by the block gate"})
            continue
        chain, cur, ok = [], d, False
        for _ in range(12):
            r = _reading_v22(f, cur)
            if r is None or r.get("moves_a_receipt_byte") is not False:
                break
            base = r.get("base")
            chain.append(f"{cur[:12]} -> {(base or 'NEW FILE')[:12]}")
            if base is None:
                ok = True
                break
            cur = base
            if _token_accepts(f, cur) or _block_gate_accepts(f, cur):
                ok = True
                break
        if ok:
            per.append({"file": f, "sha256": d, "status": "read by a chain of readings: " + "; ".join(chain)})
        else:
            refused.append(f"{f}: {d[:12]} has no reading" + (f" (chain {'; '.join(chain)} stops)" if chain else ""))
            per.append({"file": f, "sha256": d, "status": "REFUSED"})
    missing = [f for f in CLASSIFY_PORTED_FROM_V22 if f not in pins]
    refused += [f"{f}: not pinned (the v22 classifier port was read from it)" for f in missing]
    return {"pins": len(pins), "per_file": per, "refusals": refused, "ok": not refused,
            "port": "v22 (token frozen-r16b on native R13, gate capture tree + H19)"}


def classify_capture_pins(manifest: dict) -> dict:  # noqa: F811  [v22] replaces v21's dispatcher
    """[v22] the classifier capture pin check is v22's (token frozen-r16b);
    v21's rule is kept as `classify_capture_pins_v21` for the record"""
    return classify_capture_pins_v22(manifest)
