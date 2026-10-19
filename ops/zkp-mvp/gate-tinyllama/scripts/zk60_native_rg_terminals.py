#!/usr/bin/env python3
"""The PER-SLOT TERMINAL IDENTITY at the run's shape, as far as the bundle
honestly allows.

    fin_s == c_s * mask_eval_s + poly_s(vals_s)

(`let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());`,
 `hashline/src/private_block/argument.rs:381`).  The capture writes
`terminal_polynomial = fin - c*mask_eval`, so recomputing `poly_s(vals_s)`
from the PUBLISHED TERMINALS and comparing it against that field is exactly
the verifier's own final check, with nothing taken on trust.

WHAT MAKES THIS POSSIBLE NOW, AND WHAT STILL DOES NOT.  Stage 15 of the Rust
lane added `run.json["plane_index"]` — which plane each slot's `terminals[j]`
is an evaluation of, in the prover's push order.  That was the missing field
(`ZK60_NATIVE_RUN_GATE.md` §3 item 4).  It is NOT the only thing a slot's
closure reads: a slot may also have PUBLIC tables, and a run bundle carries
their LENGTH and SHA-256 but not their VALUES
(`run.json["public_tables_included"] == false`).  A public table that is a
function of the SHAPE alone is rebuilt here and checked against the
capture's own SHA-256 before it is used; a public table that folds the
public WEIGHTS, the norm gains, the RoPE tables or the exp / activation
tables cannot be rebuilt, because a bundle carries none of those.  Every
slot in the second class stays OPEN, per slot, with that reason.

ROUND 3 (2026-09-20, the TAGGED bundles).  `public_tables_included` is TRUE
in `run-e-tame-tagged` / `run-f-zero-tagged`, so the eleven slots below that
were OPEN for want of a public table's VALUES are ported and evaluated, and
**all 23 slots are covered at this shape**.  A captured public table is not
taken on trust: every one of them is checked against the capture's OWN
length and SHA-256 before use (93 per bundle), every table that is a
function of the shape is still REBUILT here and compared, and every captured
table is additionally checked for the STRUCTURE its builder gives it — a
weight fold vanishing off the width's support (ruling P-2), a norm gain
periodic in the padded width, the RoPE pair's zero set and its
`(cos, -sin | +sin)` partner symmetry, a lookup table periodic in the byte
class after the P-3 lift.  What CANNOT be established from a bundle alone is
that a weight fold is the fold of the weight matrix the statement names: no
bundle carries a weight.  That is stated per slot in `TAKEN_FROM_CAPTURE`
and in the report, and it is a soundness-side reading, not a privacy one.

ROUND 4 (2026-09-20, finding S19-F1).  Slots 08 `SC_SCORE` and 09 `SC_PV`
have TWO definitions now, and the bundle's own `argument.rs` pin selects
one.  Under the REPAIRED definition (stage 20) each is `eq(r_g, .)` times
its two private factors — degree 3, `lkv = clog2(kv_heads)` more main
rounds — and the group point `r_g` is DERIVED here from the replayed
transcript and only COMPARED with the bundle's.  Under the PRE-REPAIR
definition each is the plain product, and the bundle is marked SUPERSEDED.
The geometry, the dimensions and both factors' whole coordinate lists live
in `zk60_native_rg_gqa`, which this module calls; a bundle whose
`argument.rs` digest is neither definition makes every slot NOT CHECKED.

COVERED AT THIS SHAPE — 12 of the 23 slots on a stage-15 bundle, and all 23
on a stage-18 one:

    00 SC_SS     01 SC_SSM    02 SC_TZC    03 SC_LZC    04 SC_RS
    08 SC_SCORE  09 SC_PV     17 SC_SZC    18 SC_FZC    20 SC_ZS
    21 SC_IO_IN  22 SC_IO_OUT
    05 SC_QMM    06 SC_KMM    07 SC_VMM    10 SC_WO     11 SC_GMM
    12 SC_UMM    13 SC_DMM    14 SC_DZC    15 SC_QZC    16 SC_KVZC
    19 SC_TAB                                     (round 3, captured tables)

They include everything the rung adds that the toy does not have, except the
weight-folding slots: the PAD-ZERO term `mu_pad * (1 - supp) * sum zeta^j *
plane_j` (slots 02, 03, 17, 18, and the `supp` gate in 00, 01, 04, 17, 18),
the GROUPED-HEAD (GQA) padded head slots (slots 08 and 09 read `A_QR8` /
`A_KR8` / `A_P` / `A_V8` at the key-value group's own coordinates, and slot
17's `Dom::Ht` indicator is the head one), the run's TWO BOUNDARY CLAIM
SITES (slots 21 and 22, whose IO table is an internal boundary in every
stage but the first / last), and the third `sigma_s` limb (`A_SR2` /
`A_SG2`, slot 17).

NOT COVERED on a bundle whose public tables carry no values, all for one
reason, stated per slot below: the slot's public table is not a function of
the shape.  The same eleven slots stay OPEN on `run-a-tame` … `run-d-zero`.

    05 SC_QMM  06 SC_KMM  07 SC_VMM  10 SC_WO   11 SC_GMM  12 SC_UMM
    13 SC_DMM      -- fold_rows_i8 / fold_cols_i8 of the public weights
    14 SC_DZC      -- the two norm gains gamma_a, gamma_m
    15 SC_QZC  16 SC_KVZC -- the RoPE (cos, sin) tables
    19 SC_TAB      -- the exp and activation table values

REVIEWED OBLIGATION.  Each ported polynomial equals its Rust closure by
READING.  The reading is pinned: the bundle's own
`manifest.json["source_pins"]` names `argument.rs`, `layout.rs`,
`protocol.rs` and `plane_index.rs` by SHA-256, and [`check_source_pins`]
compares them with the digests this port was written against.  A pin that
moved makes every slot NOT CHECKED rather than silently wrong.  (The other
four files a bundle pins -- `shape.rs` here, and `run_capture.rs`, `run.rs`
and `boundary.rs` in `zk60_native_rg_runpins` since 2026-09-21 -- are pinned
elsewhere; before that date the last three were pinned by nothing, which was
finding K4-F2.)  What the
machine does check is stronger than the pin: every rebuilt public table is
compared with the capture's SHA-256 of the real one, and the identity itself
must hold at the run's real challenges for every covered slot of every stage.

NOTHING HERE IS A PRIVACY STATEMENT.  This is a consistency check of the
verifier's view at two captured runs' real challenges.
"""

from __future__ import annotations

import hashlib
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_cfs import sumcheck_final  # noqa: E402
from zk60_native_rg_gqa import (  # noqa: E402
    ARGUMENT_DEFINITIONS,
    BILINEAR_SLOTS,
    PRE_REPAIR,
    REPAIRED,
    GroupFactors,
    definition_of_pin,
)
from zk60_native_jv_field import (  # noqa: E402
    F2_ONE,
    F2_ZERO,
    P,
    eq_table_msb,
    f2_add,
    f2_from_list,
    f2_inv,
    f2_mul,
    f2_mul_base,
    f2_neg,
    f2_sub,
)

add, sub, mul, mulb = f2_add, f2_sub, f2_mul, f2_mul_base
ONE, ZERO = F2_ONE, F2_ZERO

# ------------------------------------------------------------- source pins
# The digests of the Rust this port was READ from, which are exactly the
# digests `run-c-tame` / `run-d-zero` pin in their own manifests.  Four of the
# eight files a bundle pins decide what a slot's polynomial is.
#
# **ROUND 5 CORRECTION (2026-09-20).**  This comment used to say that the
# other files a bundle pins -- `run_capture.rs`, `run.rs`, `boundary.rs` --
# "are checked by `zk60_native_rg_bundle`".  THEY ARE NOT.  No run-gate tool
# hashes or compares them; `zk60_native_rg_bundle` reads the bundle's
# `source_pins` array into its record and checks the bundle's SIZES against
# `run.json["shape"]`, which is a different thing.  Those three files move
# freely without tripping anything here, and the rung-K4 bundles of round 5
# are the first to show it: their `run.rs` is `73f68221`, not the `65d55d25`
# every earlier bundle pinned, and nothing noticed.  The gap is recorded as
# finding **K4-F2** in `ZK60_NATIVE_RUN_GATE.md` §9; it is not repaired here
# because closing it means READING three more files at five capture commits,
# and a pin added without a reading is exactly what this discipline forbids.
# What round 5 does do is name the three and their observed digests, below,
# so the next reader starts from a true statement.
#
# **ROUND 6 CORRECTION (2026-09-21).  FINDING K4-F2 IS CLOSED.**  The three
# files below ARE now pinned -- by `zk60_native_rg_runpins`, which carries
# nine (file, digest) pairs covering all five capture commits, one written
# READING per pair, and an affected-stage table so that a digest this gate
# has not read leaves the affected stages NOT CHECKED by name rather than
# crashing.  The dict below is kept, with its name, as the dated record of
# what was true until 2026-09-21; it is no longer the state of the tools.
# Two corrections to round 5's own text are folded in, because a ledger is
# not rewritten and a wrong figure is not left standing:
#   * `run.rs` `0426ad2 -> 3247a89` is **9 added lines, 0 removed**
#     (`git diff --numstat`), not the 12 round 5 recorded;
#   * `boundary.rs` is NOT byte-identical at every capture commit.  It has
#     TWO digests: `9860c35d` at `cb27845d` and `aff891d` (bundles a-d) and
#     `3786a300` at `facc057`, `0426ad2` and `3247a89` (bundles e-j).
WAS_NOT_PINNED_BY_ANY_RUN_GATE_TOOL_UNTIL_20260921 = {
    "src/private_block/run_capture.rs": "the bundle WRITER: which fields a "
    "capture carries.  A change here changes what this gate can read, and "
    "until round 6 would have been caught only by the schema and allow-list "
    "checks the writer itself puts in the bundle",
    "src/private_block/run.rs": "the run's own geometry and profile table "
    "(`RunShape`, `RUN_PROFILE_*`).  Round 5's reading: `0426ad2 -> 3247a89` "
    "adds `RUN_PROFILE_RUNG_K4` and `RunShape::rung_k4` and changes no "
    "existing line (`git diff 0426ad2 3247a89 -- .../run.rs`, **9** added "
    "lines, 0 removed; round 5 wrote 12, corrected 2026-09-21)",
    "src/private_block/boundary.rs": "the internal boundary's rows and "
    "scales.  Round 5 said 'byte-identical at every capture commit so far "
    "(3786a300)'; that is WRONG and was corrected 2026-09-21 -- bundles a-d "
    "pin `9860c35d`, and the two digests differ by the D19 tag plumbing "
    "only (production +27/-3, no geometry accessor moved)",
}
# The name the round-5 tree used.  Kept as an alias so nothing that reads it
# breaks, and so a reader who greps the old name lands on the correction.
NOT_PINNED_BY_ANY_RUN_GATE_TOOL = (
    WAS_NOT_PINNED_BY_ANY_RUN_GATE_TOOL_UNTIL_20260921)
PORTED_FROM = {
    "src/private_block/argument.rs":
        "909670c96562e7ff99b7ad37f6c3aae027574f3c0e9ab74f01a27e45058bf675",
    "src/private_block/layout.rs":
        "fec2e6476f165e1e3be7871a3dfbdef56a4619f5b2e7560eb98ff2c97587a99f",
    "src/private_block/protocol.rs":
        "4e916c693ad8e6c62e8774ddb3d829f5e1c116932e74bb1c6088d62ab4aee449",
    "src/private_block/plane_index.rs":
        "9de8320a84770560d2b998c514b0e9745a8f6c9f0c1d0cdefda8164137107611",
}
# **ROUND 3: two of those four pins MOVED, and one file joined the set.**
# The stage-18 bundles were written at `facc057`, where stage 16, 17 and 18
# landed.  `argument.rs` and `plane_index.rs` -- the two files that decide
# what a slot's polynomial IS and which plane each terminal belongs to -- are
# byte-identical at both commits, so no ported polynomial is in question.
# `layout.rs` and `protocol.rs` moved, and both diffs were read line by line
# (`git diff aff891d facc057 --`): they are the D19 hash-tag plumbing and the
# T-3 / T-4 path-length checks -- `no_commitment_has_a_node_shaped_column_
# under`, `tagged_transcript`, `endpoint_pcs_params`, and the `verify_zk` /
# `mask_commit` call sites taking a tag.  Nothing this port reads from either
# file moved: not `lookups_at`, not a plane order or row count, not a
# calibration constant, not the `(beta, gamma, alpha)` draw.  `shape.rs` is
# newly pinned BY THE BUNDLE, and its diff is additions only
# (`hashes_under_the_legacy_rule`, `hash_tag`, `degree_range`, a test hook),
# so the digest it now pins is simply recorded here as an accepted second
# value.  A pin that moves for any OTHER reason still makes every slot NOT
# CHECKED.
ALSO_ACCEPTED = {
    "src/private_block/layout.rs": {
        "b765bdcbe5762cce3402dac9fb44b5359d53cb492f67c62dbee18f3b559b0d05":
            "stage 16/17/18: the shape-free half of the C-H4 row-count set "
            "moved into `hash_domain` and takes a HashTag; nothing this port "
            "reads changed",
        # [ROUND 9] the 125M capture commit.
        "14758039fbe9daa61affa1316c6e4159437b98d888d72a926f6e70e788592b30":
            "stage 23 (ruling S-1), at commit f4697f9.  "
            "`git diff 3247a89 f4697f9 -- .../layout.rs` is **34 added, 0 "
            "removed, ONE hunk, and every added line is a `///` doc "
            "comment** on `domain_log_at`: the invariant "
            "`log(Dom::Tab) == log_cols`, why the privacy argument's Fact 1 "
            "is false on `H` without it, and that `Shape::new` now refuses a "
            "shape that breaks it.  **Not one byte of code moved**, so "
            "`N_SLOTS`, `N_FUNCTIONALS`, `M_ROWS`, every plane order and "
            "every row count this port reads are byte-identical",
        # [ROUND 9j] lane stage 45's capture commits feae674 / 19f06bf (this
        # digest from stage 43's 601e97f onward).
        "64c37a4956ed221cb549d8e88257a14f5f332bb549fc4028c9a38246b111f23c":
            "stages 40 and 43 (a comment, and ruling CS-8), unchanged through "
            "feae674 and 19f06bf.  `git diff 99a8de8 feae674 -- .../layout.rs` "
            "is **45 added, 1 removed, TWO hunks**: a doc-comment figure "
            "corrected (the LogUp multiplicity bound at 125M, 98,582,528 -> "
            "98,598,912 with the P-3-lifted `Dom::L`, note C-6 of the census "
            "check -- the one removed line) and `Layout::check_is_for_shape` "
            "(ruling CS-8), a REFUSAL that re-derives `Layout::for_shape(sh)` "
            "and compares the ten row fields; it absorbs, draws and moves "
            "nothing.  **`N_SLOTS`, `N_FUNCTIONALS`, `M_ROWS`, every plane "
            "order and row count, `lookups_at`'s windows and the calibration "
            "constants are outside both hunks and byte-identical**",
    },
    "src/private_block/protocol.rs": {
        "e012450bdc4d7eb933e1d034960a87388385f0daa18ff631da395172e1201dda":
            "stage 16/17/18: `tagged_transcript`, `endpoint_pcs_params` and "
            "the tagged verify / commit call sites; the slot loop, the "
            "(beta, gamma, alpha) draw and the row counts are unchanged",
        # [ROUND 9] the 125M capture commit.
        "9e24fd2e1cf2e52a40762a506a39e0db82dbd4f3eb07320af15f7897a9c1bdc6":
            "stage 26 (the ruling on finding B-1), at commit f4697f9.  "
            "`git diff 3247a89 f4697f9 -- .../protocol.rs` is **10 added, 1 "
            "removed, ONE hunk**, and nine of the ten added lines are a "
            "comment.  The one statement: the single-block prover's "
            "OS-seeded blinding generator takes "
            "`hash_domain::single_block_seed_domain(sh)` -- a versioned use "
            "literal, the prover's role byte and the profile string -- "
            "instead of the bare profile bytes, at every UNFROZEN profile.  "
            "**That generator is not the transcript**: no absorb, no "
            "squeeze, no label and no published byte moves, and the slot "
            "loop, the `(beta, gamma, alpha)` draw, `tagged_transcript`, "
            "`endpoint_pcs_params` and every row count are byte-identical",
        # [ROUND 9b] the rung-P2 capture commit.
        "ac4122375397a155d392df27a7e08f818ee78f80b38d41207565b325f5290413":
            "stages 28 and 29 (the 125M prover made faster), at commit "
            "4ccbad1.  `git diff f4697f9 4ccbad1 -- .../protocol.rs` is "
            "**213 added, 15 removed, FOUR hunks**, and every one of them is "
            "on the PROVER'S WITNESS-BUILDING path: `lookup_values` gains an "
            "`_at` form with a parallel branch above `LOOKUP_PAR_MIN`; the "
            "byte histogram moves out of `prove_core` into "
            "`byte_histogram_at` with a chunked branch; and the LogUp helper "
            "inverses are taken from a 256-entry table of byte denominators "
            "(`u8_denominator_inverses`) instead of an element-wise batch "
            "inversion, through `helper_one`, with single and paired forms.  "
            "**Nothing this port reads moved**: not `lookups_at`, not a "
            "plane order or row count, not a calibration constant, and not "
            "the `(beta, gamma, alpha)` draw at protocol.rs:660-662 that "
            "`Geometry.set_logup` transcribes.  The three parallel "
            "thresholds are word counts of the PUBLIC shape, so no branch is "
            "chosen by a witness value; every changed computation is a "
            "rearrangement of exact field or integer arithmetic, and the "
            "lane's own `s28_tests` / `s29_tests` compare each against the "
            "text at `79f0726`.  Two things follow that this gate can check "
            "rather than believe: the transcript is unmoved (the rung-P2 "
            "replay re-derives every challenge) and the LogUp identity `H` "
            "carries is unmoved (slot 05's terminal identity and `H`'s "
            "disclosed 2 are recomputed here)",
        # [ROUND 9i] the rung-K8 capture commit, 99a8de8 (this digest from
        # stage 36's `5d0022f` onward).
        "e0e617be617a548641cb33c8564cee86ee7d2af90f9c6487b5fb7af30113d45b":
            "stage 36 task 4 (the read-only test observer), at commit "
            "5d0022f and unchanged to 99a8de8.  `git diff 6d71b40 99a8de8 -- "
            ".../protocol.rs` is **21 added, 0 removed, ONE hunk, inside "
            "`check_opening_challenges`**: an 11-line doc comment and five "
            "`#[cfg(test)]` statements -- one shadowing `draw` with "
            "`draw_observer::counting` (which bumps a thread-local counter "
            "and returns `inner()` unchanged, one call per call) and one "
            "noting the verdict beside each of the three exits.  Not one "
            "existing line is restructured.  NOTE that the bundles are "
            "written by a `cargo test` binary, so these five lines ARE "
            "compiled into the build that made them: they are pass-through, "
            "and the function draws from a CLONED challenge prefix anyway.  "
            "**Nothing this port reads moved**: `lookups_at`, the plane "
            "orders and row counts, the calibration constants and the "
            "`(beta, gamma, alpha)` draw are byte-identical, and the rung-K8 "
            "replay re-derives every challenge",
        # [ROUND 9j] lane stage 45's capture commits feae674 / 19f06bf.
        "974892cc1c45f27e446e1fd4595c888b6a1be647105bfbab3fe6298f7a731ea7":
            "stages 40-44 (rulings CS-1, CS-3, CS-4, CS-8) and stage 45's "
            "capture hooks, at feae674, unchanged at 19f06bf.  `git diff "
            "99a8de8 feae674 -- .../protocol.rs` is **168 added, 1 removed, "
            "13 hunks**, of three kinds.  (i) REFUSALS that fire before "
            "anything is absorbed, drawn or committed: ruling CS-3's "
            "`refuse_lookup_misses` / `u8_misses_of` and two miss counters in "
            "`prove_core` -- the PROVER's, after the three histograms and "
            "before the first `A` mask draw, with a `#[cfg(test)]` "
            "`CheatingProver` switch -- and ruling CS-8's "
            "`sh.check_constructed()` / `lay.check_is_for_shape(sh)` and "
            "rulings CS-1 / CS-4's `blk.check_for_shape(sh)` / "
            "`expected.spec.check_for_shape(sh)` at `prove_inner_at`, "
            "`prove_core`, `verify_core` and `verify_inner_at`.  (ii) Stage "
            "45's `#[cfg(test)]` block-capture hooks, 23 lines: `begin_block` "
            "after the header, checkpoints and records around `M`, `A`, `H` "
            "and both endpoints, `block_accepted` at the end -- each a no-op "
            "unless a recorder is attached.  (iii) One doc comment rewritten "
            "(the removed line).  **Nothing this port reads moved**: "
            "`lookups_at`, the plane orders and row counts, the calibration "
            "constants, `transcript()`'s header absorbs, "
            "`check_opening_challenges` and the `(beta, gamma, alpha)` draw "
            "are outside every hunk, and the standalone-block replay "
            "re-derives every challenge of all four stage-45 bundles",
    },
}

# Read for the pad rule and the domain geometry, at the digest each was READ
# at.  Their digests are recorded so that a later reader can see what was
# read.
#
# **DATED CORRECTION AND FINDING P-F1, 2026-09-21 (round 9b).**  The header
# above said "Not pinned by a bundle".  That was true of every bundle up to
# `3247a89` and is FALSE since stage 27: `pad.rs`, `shape.rs` and
# `witness.rs` are all in a `/5-run` bundle's `source_pins` (round 9's
# `WRITER_SIDE_ASK_GRANTED`).  `shape.rs` has been checked against a bundle
# since round 3 through `PINNED_IF_PRESENT`; `pad.rs` was checked by nothing,
# and the digest recorded here is the one it had at `cb27845d` … `facc057`.
# It moved twice after that -- at `0426ad2` and at `3247a89` -- and no port
# noticed, which is finding K4-F2 again on the one file this port transcribes
# the pad rule from.  It is closed the same way: `pad.rs` joins
# `PINNED_IF_PRESENT` below with all three digests and a reading beside each,
# and the reading is that **not one production line of `pad.rs` has moved
# since round 1**.  `witness.rs` is byte-identical at all seven capture
# commits and no port transcribes it, so it stays a recorded digest.
ALSO_READ = {
    "src/private_block/pad.rs":
        "7b6a990be900ad56e890660e9e3587c19fefc69f434a9bb3d4eab817f603d1ff",
    "src/private_block/shape.rs":
        "144012d5d960446784a64a451b01ada2d4d6bdd9493ede51e4142e90d28942e0",
    "src/private_block/witness.rs":
        "b9b66c024e7ca68d2a0ae4ba46241eb2abbccc8c8d94fe828041abbc710850ad",
}
ALSO_READ_NOW_PINNED = {
    "src/private_block/pad.rs": "checked from a bundle since round 9b, in "
    "PINNED_IF_PRESENT (finding P-F1)",
    "src/private_block/shape.rs": "checked from a bundle since round 3, in "
    "PINNED_IF_PRESENT",
    "src/private_block/witness.rs": "pinned by the writer since stage 27 and "
    "transcribed by no port -- a capture carries no witness",
}

# A file this port READ that a bundle did not pin until stage 18.  It is
# checked only when the bundle pins it, so a stage-14 or stage-15 bundle is
# unaffected; both digests are accepted, and the stage-18 one is the first
# with the D19 additions (`hashes_under_the_legacy_rule`, `hash_tag`,
# `degree_range`, the test hook) and nothing else.
PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        "144012d5d960446784a64a451b01ada2d4d6bdd9493ede51e4142e90d28942e0":
            "the digest this port was read at (stage 15)",
        "9ac32109b176ffe10601b3412961204ac00c3a8feafd23226a9cc568f5104999":
            "stage 17/18: the D19 hash-tag selector and a degree_range helper, "
            "additions only; every geometry function this port reads is "
            "unchanged",
        "8f7344221ad7a783caaadfa768611fb927ac6320d5b02c1e6adeb658c7900a2a":
            "stage 20/21: the two bilinear slots' dims become "
            "`lkv + clog2(...)` main rounds and degree 2 + indicator + "
            "group_eq, and `Shape::new` gains finding F-2's named refusal "
            "for a P-3-lifted Dom::Q / Dom::Kv / Dom::S.  Both are DERIVED "
            "independently in `zk60_native_rg_gqa.Geometry` and compared "
            "with the shape's own `slots` array, so this port does not take "
            "the moved file's word for either",
        "07a0547f06602bc27cbad1658a7cc0079f2ac1158d2bb372e24096e930e6a7fd":
            "stage 22 (round 5): ONE addition, `Shape::rung_k4()` -- 24 "
            "tokens, width 96, hidden 192, 12 query heads of 8 over 4 "
            "key-value heads, h_pad 16, so lkv = 2 and the padded head "
            "slots are {3, 7, 11, 15}.  `git diff 0426ad2 3247a89 -- "
            ".../shape.rs` is 60 added lines and 0 removed: a doc comment "
            "and one constructor calling the UNCHANGED `Shape::new`.  Not "
            "one geometry function this port reads moved -- not `true_size`, "
            "not `head_slot`, not `pads`, not `clog2`, not `slot_dims` -- "
            "and the new shape's numbers are derived here from "
            "`run.json[\"shape\"]` and compared with the shape's own `slots` "
            "array, so this port takes nothing from the file on trust",
        # [ROUND 9] the 125M capture commit.
        "14ea01ee5a68986da8d1647afa97638dbeb4fea48a96fe74c1e81fa19705636c":
            "stages 23, 24 and 27, at commit f4697f9.  "
            "`git diff 3247a89 f4697f9 -- .../shape.rs` is **123 added, 0 "
            "removed, two hunks -- ADDITIONS ONLY**, and they are of two "
            "kinds.  (i) `Shape::m125()`, one constructor delegating to the "
            "UNCHANGED `Shape::new` (512 tokens, width 768, hidden 2048, 12 "
            "query heads of 64 over 4 key-value heads, log_cols 14, inverse "
            "rate 4, f_e 9, endpoint_rows 37).  (ii) THREE NAMED REFUSALS in "
            "`Shape::new`, each of which would have been a silent wrongness "
            "at a bigger shape: ruling S-1, `log(Dom::Tab) == log_cols` (the "
            "invariant `layout.rs`'s new comment explains); ruling S-3, "
            "`head_dim < 2^log_cols`, or the score slot's two private "
            "factors would share their whole tail and their column keys "
            "would collide; and ruling C-4, `L_s + MASK_Q <= MASK_MSG` for "
            "every slot -- exactly the assertion `zk.rs::mask_commit` makes, "
            "lifted to the shape so a shape that cannot carry its own masks "
            "is refused before a proof.  **Not one geometry function this "
            "port reads moved**, and every dimension is re-derived here "
            "from `run.json[\"shape\"]` and compared with the shape's own "
            "`slots` array",
        # [ROUND 9b] the rung-P2 capture commit.
        "502ba5caac76bdfd026c77761a7735ccc94cf56a157d8bd0dbfbde6c773dd04b":
            "stage 30, at commit 4ccbad1.  `git diff f4697f9 4ccbad1 -- "
            ".../shape.rs` is **63 added, 0 removed, ONE hunk -- ADDITIONS "
            "ONLY**: `Shape::rung_p2()`, one constructor delegating to the "
            "UNCHANGED `Shape::new` (32 tokens, width 96, hidden 256, 12 "
            "query heads of 8 over 4 key-value heads), and its doc comment.  "
            "It is rung-K4's PADDED layout with two true sizes moved onto "
            "their pads -- tokens 24 -> 32 so `Dom::T = t_pad = 2^5` and "
            "`Dom::Kv = 2^10` are exact, hidden 192 -> 256 so "
            "`Dom::F = 2^13` is exact -- while `Ht`, `L`, `D`, `Q`, `S` and "
            "`Tab` still pad.  That is **125M's own padded-domain set at a "
            "development size**, which is the shape finding M-F1's control "
            "needed.  **Not one geometry function this port reads moved** -- "
            "not `true_size`, not `pads`, not `head_slot`, not `clog2`, not "
            "`slot_dims` -- and every dimension is re-derived here from "
            "`run.json[\"shape\"]` and compared with the shape's own `slots` "
            "array",
        # [ROUND 9c] stages 31, 32 and 33: three more shapes, and ruling
        # S-6's construction refusal.  The reading is one reading, because
        # the three diffs are the same diff three times over.
        "3791ef61cd3c29356f3b71e8c271378ca8a31cd2bef7fb963d2e7ac8be7c8224":
            "stage 31, at commit 3e106e1.  `git diff 4ccbad1 3e106e1 -- "
            ".../shape.rs` is **75 added, 0 removed -- ADDITIONS ONLY**: "
            "`Shape::rung_c6()` with its doc comment (32 tokens, width 384, "
            "hidden 512, 12 query heads of 32 over 4 key-value heads, "
            "log_cols 10, endpoint_rows 21).  It is `rung_p2`'s geometry "
            "with the head dimension widened from 8 to 32, which is the "
            "smallest move that takes the width past 256 and so makes "
            "`Shape::norm_top_is_full_byte` TRUE -- correction **C-6**, "
            "four norm lookups dropped, `Dom::D` at 17 helper planes "
            "instead of 19 and slot 14 at 54 terminals instead of 56.  "
            "`lookups_at` in this port already implements C-6 (`norm_top = "
            "norm_wrho != 8 * ln`), and the prediction derives the flag "
            "from the width alone.  **Not one geometry function this port "
            "reads moved**",
        "b891869adb3d3df2564ba0f2524e8ec6dcbfa6a3c5a1139a39420b4f4e68c645":
            "stage 32, at commit 11703c9.  `git diff 4ccbad1 11703c9 -- "
            ".../shape.rs` is **154 added, 0 removed -- ADDITIONS ONLY**: "
            "rung-C6's constructor above plus `Shape::rung_w14()` (64 "
            "tokens, width 768, hidden 1024, 12 heads of 64 over 4, "
            "**log_cols 14**, endpoint_rows 9) and their doc comments.  "
            "rung-W14 is 125M's ROW GEOMETRY at a development size: a "
            "2^14-word message encoded to 2^16, Merkle depth 16, the byte "
            "table lifted by 64, and 125M's own head size.  **Not one "
            "geometry function this port reads moved**",
        "dbf4e2bc36e9f74c432d6e529b229e3a593e794271fd8593d1412b8312403911":
            "stage 33, at commit 6d71b40 (the rung-E32 bundles NAME "
            "`4505ddf`, which does not carry this blob -- finding E32-F1).  "
            "`git diff 4ccbad1 6d71b40 -- .../shape.rs` is **273 added, 0 "
            "removed -- ADDITIONS ONLY**, of three kinds.  (i) the three "
            "constructors `rung_c6`, `rung_w14` and `rung_e32` (the last: "
            "32 tokens, width 768, hidden 1024, 12 heads of 64 over 4, "
            "log_cols 10, **endpoint_rows 37** -- 125M's own 32 data rows "
            "and 37 commitment rows).  (ii) **ruling S-6**, a named "
            "construction refusal in `Shape::new`: a shape whose padded "
            "token count reaches the row width is refused, because it "
            "would reach `Shape::a_groups`'s first arm, which no "
            "registered shape takes.  It cannot fire at any shape this "
            "gate reads -- `natural_log(Dom::T)` is 5, 6 and 5 against row "
            "widths of 10, 14 and 10 -- and on the refused family the two "
            "arms agree anyway.  (iii) a doc comment on `a_groups` saying "
            "so; `a_groups`'s code is byte-identical.  **Not one geometry "
            "function this port reads moved**",
        # [ROUND 9j] lane stage 45's capture commits feae674 / 19f06bf (this
        # digest from stage 44's 51f8f2b onward).
        "5acecd8e431ea37d6669ab097be4e64c1102cff6617bd09712f4a742c658328f":
            "stages 40-44 (note C-6, rulings CS-2, CS-5, CS-8, CS-9), "
            "unchanged through feae674 and 19f06bf.  `git diff 99a8de8 "
            "feae674 -- .../shape.rs` is **291 added, 10 removed, eight "
            "hunks**, all REFUSALS and one rename: the constants `F_E_MAX` "
            "and `WIDTH_MAX` and two refusal prefixes; the block-profile "
            "REGISTRY (`REGISTERED_BLOCK_SHAPES`, `registered_block_shape`, "
            "rung-K8's arm under `#[cfg(test)]`); `Shape::new` becomes the old "
            "body renamed `Shape::build` (now private) followed by ruling "
            "CS-9's check that a registered profile names exactly its one "
            "shape; `build` gains note C-6's `f_e > 31`, ruling CS-5's `width "
            "> 16,384` and ruling CS-2's two window-override floors; and "
            "`check_constructed` (ruling CS-8) re-runs `Shape::new` on a "
            "value's own parameters.  The ten removed lines are one doc line "
            "and the nine registered constructors' `Shape::new(` -> "
            "`Shape::build(` (they ARE the registry's entries).  **Not one "
            "geometry function this port reads moved** -- not `true_size`, "
            "`pads`, `head_slot`, `clog2`, `slot_dims`, `Shape::slots` or "
            "ruling C-4 -- no new refusal fires on any registered shape, and "
            "every dimension is re-derived here from `block.json[\"shape\"]` "
            "and compared with the shape's own `slots` array",
    },
    # [ROUND 9b, finding P-F1] `pad.rs`, the file this port transcribes the
    # pad rule from (`PadGeometry`: `BitForm` at pad.rs:124,
    # `closed_form_indicator` at pad.rs:160, `zero_rule_a_planes` at
    # pad.rs:365 and `pad_zero_host`, which is what `Ctx.pad_on` and
    # `Ctx.zero_planes` are).  It was recorded in `ALSO_READ` as one digest
    # and compared against nothing; it has been in a bundle's `source_pins`
    # since stage 27 and it moved twice before that.  All three digests are
    # read, and the reading is the same for both moves.
    "src/private_block/pad.rs": {
        "7b6a990be900ad56e890660e9e3587c19fefc69f434a9bb3d4eab817f603d1ff":
            "the digest this port was read at (round 1, commits cb27845d "
            "through facc057)",
        "cc1ab831d377bb0542edab1ce8659024aaaee6bc72897b5c8ede3f7c053704a5":
            "stage 19/20, at commit 0426ad2.  `git diff facc057 0426ad2 -- "
            ".../pad.rs` is **94 added, 26 removed, three hunks**, and every "
            "changed line is inside `#[cfg(test)] mod tests` except ONE: the "
            "`#[cfg(test)] fn every_checkable_relation_holds` becomes "
            "`pub(super)`, a visibility change on a function that is "
            "compiled only in tests.  The tests themselves gained the `f > "
            "d` hidden-axis support statement and now run at both "
            "`Shape::rung()` and `Shape::rung_g()`.  **Not one production "
            "line moved**: `BitForm::of`, `closed_form_indicator`, "
            "`zero_rule_a_planes`, `pad_zero_host` and the exempt-plane rule "
            "are byte-identical, and those are the whole of what this port "
            "transcribes",
        "f8b1f6c26d18eadf01eb5e8527f3a2e9620fad533b8ab332cd57a6014bf96df0":
            "stage 22, at commit 3247a89, and UNCHANGED at f4697f9 and "
            "4ccbad1.  `git diff 0426ad2 3247a89 -- .../pad.rs` is **2 "
            "added, 2 removed, two hunks, both inside `mod tests`**: "
            "`Shape::rung_k4()` is added to the shape list of two test loops "
            "(the masked-length check and the declared-degree range).  **Not "
            "one production line moved.**  So the pad rule this port "
            "transcribes is byte-identical from round 1 to round 9b, which "
            "is what makes finding M-F1 a defect of the PORT alone and not "
            "of a moved Rust file",
    },
}

# [TINYLLAMA PORT 2026-10-17] the trained bundles' layout.rs, protocol.rs,
# plane_index.rs, shape.rs and pad.rs digests, each READ
# (`zk60_native_rg_tinyllama_pins`); no entry above changes.
from zk60_native_rg_tinyllama_pins import (  # noqa: E402
    TERMINALS_ALSO_ACCEPTED as _TL_AA,
    TERMINALS_PINNED_IF_PRESENT as _TL_PIP,
    merge_two_level as _tl_merge2)
_tl_merge2(ALSO_ACCEPTED, _TL_AA, "ALSO_ACCEPTED")
_tl_merge2(PINNED_IF_PRESENT, _TL_PIP, "PINNED_IF_PRESENT")
# [TINYLLAMA PORT v5, round 4] the R5 tree's layout.rs, protocol.rs and
# shape.rs digests, each READ (`zk60_native_rg_tinyllama_r5_pins`).
from zk60_native_rg_tinyllama_r5_pins import (  # noqa: E402
    TERMINALS_ALSO_ACCEPTED as _R5_AA,
    TERMINALS_PINNED_IF_PRESENT as _R5_PIP)
_tl_merge2(ALSO_ACCEPTED, _R5_AA, "ALSO_ACCEPTED")
_tl_merge2(PINNED_IF_PRESENT, _R5_PIP, "PINNED_IF_PRESENT")
# [TINYLLAMA PORT v6, round 5] the R5b tree's shape.rs (layout.rs, protocol.rs
# are R5's bytes) (`zk60_native_rg_tinyllama_r5b_pins`)
from zk60_native_rg_tinyllama_r5b_pins import (  # noqa: E402
    TERMINALS_PINNED_IF_PRESENT as _R5B_PIP)
_tl_merge2(PINNED_IF_PRESENT, _R5B_PIP, "PINNED_IF_PRESENT")
# [TINYLLAMA PORT v8, round 6 part (B)] the R7 tree's protocol.rs and shape.rs
# (`zk60_native_rg_tinyllama_r7_pins`)
from zk60_native_rg_tinyllama_r7_pins import (  # noqa: E402
    TERMINALS_ALSO_ACCEPTED as _R7_AA,
    TERMINALS_PINNED_IF_PRESENT as _R7_PIP)
_tl_merge2(ALSO_ACCEPTED, _R7_AA, "ALSO_ACCEPTED")
_tl_merge2(PINNED_IF_PRESENT, _R7_PIP, "PINNED_IF_PRESENT")

# **ROUND 4 (2026-09-20), finding S19-F1.**  `argument.rs` is the file that
# decides what a slot's polynomial IS, and its stage-20 digest carries a
# DIFFERENT definition of slots 08 and 09 from every earlier one.  It is
# therefore no longer checked against one pinned value: it selects which of
# the two definitions this port implements, out of `ARGUMENT_DEFINITIONS`
# (`zk60_native_rg_gqa`).  A digest outside that table is a refusal exactly
# as a moved pin was, and the digest `PORTED_FROM` still names is the
# pre-repair one, so the count of pins at an accepted second digest does not
# move for a bundle written before stage 20.
ARGUMENT_FILE = "src/private_block/argument.rs"


def check_source_pins(bundle) -> dict:
    """The bundle's own `source_pins` against the digests this port was
    written from.  A moved pin is a refusal, never a silent re-read.

    `argument.rs` is the one exception and it is an explicit one: both of
    its digests are definitions this port has READ, and the pin SELECTS one
    (see `zk60_native_rg_gqa`).  The record says which."""
    pins = {p["file"]: p["sha256"] for p in bundle.manifest.get("source_pins", [])}
    moved, missing, accepted = [], [], []
    definition, definition_why = None, None
    for f, want in PORTED_FROM.items():
        got = pins.get(f)
        second = ALSO_ACCEPTED.get(f, {})
        if f == ARGUMENT_FILE:
            if got is None:
                missing.append(f)
                continue
            definition, definition_why = definition_of_pin(got)
            if definition is None:
                moved.append(
                    f"{f}: the bundle pins {got[:12]}, which is neither definition "
                    "of the bilinear attention slots this port has read "
                    f"({', '.join(d[:12] for d in ARGUMENT_DEFINITIONS)})"
                )
            elif got != want:
                accepted.append(f"{f}: {got[:12]} -- {definition_why}")
            continue
        if got is None:
            missing.append(f)
        elif got == want:
            continue
        elif got in second:
            accepted.append(f"{f}: {got[:12]} -- {second[got]}")
        else:
            moved.append(f"{f}: the bundle pins {got[:12]}, the port was read at {want[:12]}")
    for f, ok_digests in PINNED_IF_PRESENT.items():
        got = pins.get(f)
        if got is None:
            continue
        if got in ok_digests:
            accepted.append(f"{f}: {got[:12]} -- {ok_digests[got]}")
        else:
            moved.append(
                f"{f}: the bundle pins {got[:12]}, which is not one this port has read"
            )
    return {
        "ported_from": PORTED_FROM,
        "also_read_not_pinned_by_a_bundle": ALSO_READ,
        "bilinear_definition_selected_by_the_argument_pin": definition,
        "bilinear_definition_reason": definition_why,
        "argument_definitions_this_port_implements": {
            d[:12]: v[0] for d, v in ARGUMENT_DEFINITIONS.items()
        },
        "pins_missing_from_the_bundle": missing,
        "pins_that_moved": moved,
        "pins_at_an_accepted_second_digest": accepted,
        "ok": not moved and not missing,
    }


# ------------------------------------------------- calibration constants
# `layout.rs` consts.  These are the PUBLIC calibration of the private-block
# kernel and do not move with a shape; the three that DO move at the rung
# (`norm_wrho` 31, `wrho_s` 17, `f_e` 12) are read from `run.json["shape"]`.
NORM_CEPS = 1        # layout.rs:64
F_P = 9              # shape.rs:38, the softmax quotient's scale
MASK_SCORE = -127    # layout.rs, the masked-out score
SH_S = 6             # layout.rs:68
SH_G = 7             # layout.rs (the gate's requantisation shift)
SH_H_PROD = 14       # layout.rs (the hidden product's shift)
# round 3: the constants the eleven newly ported slots read
NORM_TN = 11         # layout.rs:62
NORM_CN = 1024       # layout.rs:63
SH_QKV = 7           # layout.rs:66
SH_ROPE = 7          # layout.rs:67
SH_O = 9             # layout.rs:69
SH_AO = 7            # layout.rs:70
SH_Z = 6             # layout.rs:80
LIMBS_ISQRT = 3      # shape.rs:28; `N_LIMBS = 3 * LIMBS_ISQRT = 9`
U8_LEN = 256         # layout.rs:59
# `gamma.mul_base(Fp::new(TAG))`, tables_attn.rs
TAG_EXP, TAG_U8, TAG_ACT = 129, 133, 134

POW256 = [(pow(256, j, P), 0) for j in range(4)]

# ------------------------------------------------ [TINYLLAMA PORT 2026-10-17]
# THE CALIBRATION, PER BUNDLE.  The constants above are the FROZEN
# calibration every registered profile proves with (`shape.rs`:
# `NormCalibration::FROZEN`).  A TRAINED-calibration profile (decision D24
# and round 2 of the native lane) carries its own `tn`, two norm multipliers
# `Cn_a` / `Cn_m`, `Ceps` and seven windowed requantization shifts as SHAPE
# fields; the relations read them from the shape (`argument.rs` SC_TZC,
# SC_DZC, SC_FZC, SC_QZC / SC_KVZC, SC_SZC; `layout.rs::lookups_at`'s top-limb
# coefficients), each the frozen literal at a frozen shape.  The trained
# capture writes them into `run.json["shape"]` beside `trained_calibration:
# true`; this class reads them from there and falls back to the frozen values
# ONLY when the bundle declares no trained calibration -- a bundle that names
# some trained keys and not the flag, or the flag and not every key, is a
# refusal, never a silent mixture.  At a frozen bundle every coefficient below
# equals the literal this port used before, so no frozen figure can move.
FROZEN_CALIBRATION = {
    "norm_tn": NORM_TN, "norm_cn_a": NORM_CN, "norm_cn_m": NORM_CN,
    "norm_ceps": NORM_CEPS, "sh_ao": SH_AO, "sh_qkv": SH_QKV, "sh_s": SH_S,
    "sh_o": SH_O, "sh_g": SH_G, "sh_h": SH_H_PROD, "sh_z": SH_Z,
}
TRAINED_KEYS = tuple(FROZEN_CALIBRATION)


class Calibration:
    """`Shape::norm_calibration()` read from a bundle's shape."""

    def __init__(self, shape_raw: dict):
        flag = shape_raw.get("trained_calibration")
        present = [kk for kk in TRAINED_KEYS if kk in shape_raw]
        if flag is True:
            missing = [kk for kk in TRAINED_KEYS if kk not in shape_raw]
            if missing:
                raise ValueError("run.json shape declares a trained calibration "
                                 f"but not {missing}")
            self.values = {kk: int(shape_raw[kk]) for kk in TRAINED_KEYS}
            self.trained = True
        elif flag is None and not present:
            self.values = dict(FROZEN_CALIBRATION)
            self.trained = False
        else:
            raise ValueError("run.json shape: trained calibration keys "
                             f"{present} without trained_calibration: true "
                             f"(flag {flag!r})")
        for kk, v in self.values.items():
            setattr(self, kk, v)

    @staticmethod
    def half(sh: int) -> int:
        """`witness::half` (witness.rs:93): 0 at sh = 0, else 2^(sh-1)."""
        return 0 if sh == 0 else 1 << (sh - 1)

    @staticmethod
    def one(sh: int) -> int:
        """`lookups_at`'s one-limb top pin `2^(8 - sh)` (layout.rs)."""
        return 1 << (8 - sh)

    @staticmethod
    def two(sh: int) -> int:
        """`lookups_at`'s two-limb top pin `2^(16 - sh)` (layout.rs)."""
        return 1 << (16 - sh)

    def record(self) -> dict:
        return {"trained": self.trained, **self.values}


def k(v: int):
    """`Fp2::from_i64` (zkp-core/src/field.rs:148)."""
    return (v % P, 0)


def double(a):
    return add(a, a)


def eq_point(r, s):
    """`eq_point` (zkp-core/src/mle.rs:54)."""
    if len(r) != len(s):
        raise ValueError("eq_point arity")
    acc = ONE
    for a, b in zip(r, s):
        acc = mul(acc, add(mul(a, b), mul(sub(ONE, a), sub(ONE, b))))
    return acc


# =====================================================================
#  the pad rule, ported and then CHECKED against the capture's own digests
# =====================================================================
class PadGeometry:
    """`pad.rs` and the parts of `shape.rs` the indicators need, at the
    bundle's own shape.  Every domain log is READ from the plane index table,
    never derived: `domain_log_at`'s P-3 lift is the table's business."""

    def __init__(self, shape_raw: dict, domain_log: dict):
        self.s = shape_raw
        self.domain_log = dict(domain_log)
        # [TINYLLAMA PORT] the bundle's calibration (frozen when undeclared)
        self.cal = Calibration(shape_raw)

    def log(self, dom: str) -> int:
        return self.domain_log[dom]

    def size(self, dom: str) -> int:
        return 1 << self.domain_log[dom]

    def true_size(self, dom: str) -> int:
        """`Shape::true_size` (shape.rs:405)."""
        s = self.s
        return {
            "T": s["tokens"],
            "Ht": s["q_heads"] * s["tokens"],
            "L": 3 * LIMBS_ISQRT * s["tokens"],
            "D": s["tokens"] * s["width"],
            "Q": s["tokens"] * s["q_heads"] * s["head_dim"],
            "Kv": s["tokens"] * s["kv_heads"] * s["head_dim"],
            "S": s["q_heads"] * s["tokens"] * s["tokens"],
            "F": s["tokens"] * s["hidden"],
            "Tab": U8_LEN,
        }[dom]

    def pads(self, dom: str) -> bool:
        """`Shape::pads` (shape.rs:430)."""
        return self.size(dom) != self.true_size(dom)

    def head_slot(self, h: int) -> int:
        """`Shape::head_slot` (shape.rs:338), correction C-1."""
        s = self.s
        group = s["q_heads"] // s["kv_heads"]
        per = s["h_pad"] // s["kv_heads"]
        return (h // group) * per + (h % group)

    # --------------------------------------------------- BitForm (pad.rs:124)
    @staticmethod
    def _bitform(lim: int, pad: int):
        if not (pad & (pad - 1) == 0 and 0 < lim <= pad):
            raise ValueError(f"BitForm::of({lim}, {pad})")
        m = pad.bit_length() - 1
        if lim == pad:
            return ("always", ())
        if lim & (lim - 1) == 0:
            return ("allzero", tuple(range(lim.bit_length() - 1, m)))
        q = pad - lim
        if q & (q - 1) == 0:
            return ("notallone", tuple(range(q.bit_length() - 1, m)))
        return None

    @staticmethod
    def _at(form, x: int) -> int:
        kind, bits = form
        if kind == "always":
            return 1
        if kind == "allzero":
            return 1 if all((x >> b) & 1 == 0 for b in bits) else 0
        return 0 if all((x >> b) & 1 == 1 for b in bits) else 1

    def closed_form_indicator(self, dom: str):
        """`pad::closed_form_indicator` (pad.rs:160)."""
        s = self.s
        t_pad, d_pad, f_pad, dh = s["t_pad"], s["d_pad"], s["f_pad"], s["head_dim"]
        per = s["h_pad"] // s["kv_heads"]
        bf = self._bitform

        def head():
            return bf(s["q_heads"] // s["kv_heads"], per)

        if dom == "T":
            axes = [(1, bf(s["tokens"], t_pad))]
        elif dom == "D":
            axes = [(1, bf(s["width"], d_pad)), (d_pad, bf(s["tokens"], t_pad))]
        elif dom == "F":
            axes = [(1, bf(s["hidden"], f_pad)), (f_pad, bf(s["tokens"], t_pad))]
        elif dom == "Kv":
            axes = [(s["kv_heads"] * dh, bf(s["tokens"], t_pad))]
        elif dom == "Q":
            axes = [(dh, head()), (d_pad, bf(s["tokens"], t_pad))]
        elif dom == "Ht":
            axes = [(1, bf(s["tokens"], t_pad)), (t_pad, head())]
        elif dom == "S":
            axes = [(1, bf(s["tokens"], t_pad)), (t_pad, bf(s["tokens"], t_pad)),
                    (t_pad * t_pad, head())]
        elif dom == "L":
            axes = [(1, bf(s["tokens"], t_pad)),
                    (t_pad, bf(3 * LIMBS_ISQRT, self.size("L") // t_pad))]
        else:
            axes = [(1, bf(U8_LEN, self.size("Tab")))]
        factors = []
        for stride, form in axes:
            if form is None:
                return None
            if form[0] != "always":
                factors.append(((stride & -stride).bit_length() - 1, form))
        v = [1] * self.size(dom)
        for x in range(len(v)):
            for shift, form in factors:
                if v[x]:
                    v[x] = self._at(form, x >> shift)
        return v

    def support_indicator(self, dom: str):
        """`pad::support_indicator` (pad.rs:48) through `Geom::support`
        (witness.rs:211)."""
        s = self.s
        t, d, f = s["tokens"], s["width"], s["hidden"]
        hq, hkv, dh = s["q_heads"], s["kv_heads"], s["head_dim"]
        t_pad, d_pad, f_pad = s["t_pad"], s["d_pad"], s["f_pad"]
        kvw = hkv * dh
        if dom == "D":
            idx = [tt * d_pad + i for tt in range(t) for i in range(d)]
        elif dom == "Q":
            idx = [tt * d_pad + self.head_slot(h) * dh + i
                   for tt in range(t) for h in range(hq) for i in range(dh)]
        elif dom == "Kv":
            idx = [tt * kvw + kv * dh + i
                   for tt in range(t) for kv in range(hkv) for i in range(dh)]
        elif dom == "S":
            idx = [(self.head_slot(h) * t_pad + tt) * t_pad + j
                   for h in range(hq) for tt in range(t) for j in range(t)]
        elif dom == "F":
            idx = [tt * f_pad + j for tt in range(t) for j in range(f)]
        elif dom == "T":
            idx = list(range(t))
        elif dom == "Ht":
            idx = [self.head_slot(h) * t_pad + tt for h in range(hq) for tt in range(t)]
        elif dom == "L":
            idx = [kk * t_pad + tt for kk in range(3 * LIMBS_ISQRT) for tt in range(t)]
        else:
            idx = list(range(U8_LEN))
        v = [0] * self.size(dom)
        for i in idx:
            v[i] = 1
        return v

    def indicator_table(self, dom: str):
        """`pad::indicator_table` (pad.rs:335)."""
        c = self.closed_form_indicator(dom)
        return c if c is not None else self.support_indicator(dom)

    def supp(self, dom: str, cube: int):
        """`B::supp` (argument.rs:556): the indicator tiled over the slot's
        own cube, or None where the domain does not pad."""
        if not self.pads(dom):
            return None
        t = self.indicator_table(dom)
        if len(t) == 0 or cube == 0 or cube % len(t) != 0:
            raise ValueError(
                f"an indicator that does not tile its slot's cube ({len(t)} in {cube})"
            )
        rep = cube // len(t)
        return [t[x // rep] for x in range(cube)]

    def causal_mask(self):
        """`causal_mask_at` (argument.rs:761)."""
        t = self.s["t_pad"]
        return [1 if x % t <= (x // t) % t else 0 for x in range(self.size("S"))]

    def ones_tab(self):
        """`SC_ZS`'s all-ones vector over `Dom::Tab` (argument.rs:1435)."""
        return [1] * self.size("Tab")


def table_digest(values) -> str:
    """The SHA-256 the capture records for a public table: each `Fp2` as
    `c0` then `c1`, little-endian u64 (`run_capture.rs:788`,
    `field.rs:193`).  An entry may be a BASE-field integer (`c1 = 0`), which
    is what every rebuildable table is, or an `Fp2` pair, which is what a
    captured one is."""
    b = bytearray()
    for x in values:
        if isinstance(x, int):
            c0, c1 = x % P, 0
        else:
            c0, c1 = x[0] % P, x[1] % P
        b += c0.to_bytes(8, "little") + c1.to_bytes(8, "little")
    return hashlib.sha256(bytes(b)).hexdigest()


# =====================================================================
#  the lookup lists, by plane NAME (layout.rs::lookups_at)
# =====================================================================
def _byte(name):
    return ([(name, 1)], 0)


def _scaled(name, c):
    return ([(name, c)], 0)


def _sym(name):
    """`sym`, the int8 subset [-127, 127] (layout.rs:274)."""
    return [([(name, 1)], 127), ([(name, -1)], 127)]


def lookups_at(dom: str, counts: dict, shape_raw: dict):
    """`layout.rs::lookups_at` (layout.rs:667), written in plane NAMES.

    Only the three things the doc-comment there names move with a shape: the
    plane ids (handled by names), the byte-limb counts `ln` / `ls` / `lp`,
    and the `scaled` coefficient that pins the top limb's slack bits.
    """
    ln, ls, lp = counts["ln"], counts["ls"], counts["lp"]
    norm_wrho, wrho_s = shape_raw["norm_wrho"], shape_raw["wrho_s"]
    # [TINYLLAMA PORT] the windowed top-limb pins are the SHAPE's
    # (layout.rs `one(sh) = 2^(8-sh)`, `two(sh) = 2^(16-sh)`); the frozen
    # shifts give the historical literals 2, 4, 2, 4, 2, 128, 4
    cal = Calibration(shape_raw)
    one, two = Calibration.one, Calibration.two
    norm_top = norm_wrho != 8 * ln           # `Shape::norm_top_is_full_byte`
    norm_scale = 1 << (8 * ln - norm_wrho)
    sigma_scale = 1 << (8 * ls - wrho_s)
    p_scale = 1 << (8 * lp - (F_P + 1))
    v = []
    if dom == "L":
        v += [_byte("A_LIMB"), _byte("A_LIMBM")]
    elif dom == "D":
        v += [_byte("A_XL0"), _byte("A_XL1")]
        v += _sym("A_Y")
        v += [_byte(f"A_NR{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_NR{ln - 1}", norm_scale)]
        v += [_byte(f"A_NS{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_NS{ln - 1}", norm_scale)]
        v += [_byte("A_AL0"), _byte("A_AL1"), _byte("A_RAL"),
              _scaled("A_RAL", one(cal.sh_ao)), _byte("A_X1L0"), _byte("A_X1L1")]
        v += _sym("A_YM")
        v += [_byte(f"A_MR{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_MR{ln - 1}", norm_scale)]
        v += [_byte(f"A_MS{j}") for j in range(ln)]
        if norm_top:
            v += [_scaled(f"A_MS{ln - 1}", norm_scale)]
        v += [_byte("A_X2L0"), _byte("A_X2L1")]
        v += [_byte("A_ZL0"), _byte("A_ZL1"), _byte("A_RDL"),
              _scaled("A_RDL", one(cal.sh_z))]
    elif dom == "F":
        v += [_byte("A_RGL"), _scaled("A_RGL", one(cal.sh_g))]
        v += [_byte("A_UL0"), _byte("A_UL1")]
        v += [_byte("A_HL0"), _byte("A_HL1")]
        v += [_byte("A_RH0"), _byte("A_RH1"), _scaled("A_RH1", two(cal.sh_h))]
    elif dom == "Q":
        v += _sym("A_Q8")
        v += [_byte("A_RQL"), _scaled("A_RQL", one(cal.sh_qkv))]
        v += _sym("A_QR8")
        v += [_byte("A_RQRL"), _scaled("A_RQRL", 2)]
        v += _sym("A_O8")
        v += [_byte("A_RO0"), _byte("A_RO1"), _scaled("A_RO1", two(cal.sh_o))]
    elif dom == "Kv":
        v += _sym("A_K8")
        v += [_byte("A_RKL"), _scaled("A_RKL", one(cal.sh_qkv))]
        v += _sym("A_V8")
        v += [_byte("A_RVL"), _scaled("A_RVL", one(cal.sh_qkv))]
        v += _sym("A_KR8")
        v += [_byte("A_RKRL"), _scaled("A_RKRL", 2)]
    elif dom == "S":
        v += _sym("A_S8")
        v += [_byte("A_RSL"), _scaled("A_RSL", one(cal.sh_s))]
        v += [_byte(f"A_PL{j}") for j in range(lp)]
        v += [_scaled(f"A_PL{lp - 1}", p_scale)]
        v += [_byte(f"A_SR{j}") for j in range(ls)]
        v += [_scaled(f"A_SR{ls - 1}", sigma_scale)]
        v += [_byte(f"A_SG{j}") for j in range(ls)]
        v += [_scaled(f"A_SG{ls - 1}", sigma_scale)]
    return v


def helper_sum(v, lks, h0, alpha, mu):
    """`helper_sum` (argument.rs:642)."""
    def den(l):
        terms, cst = l
        a = cst
        for (i, c) in terms:
            a = add(a, mulb(v[i], c % P))
        return sub(alpha, a)

    acc = ZERO
    for j in range((len(lks) + 1) // 2):
        h = v[h0 + j]
        d1 = den(lks[2 * j])
        if 2 * j + 1 < len(lks):
            d2 = den(lks[2 * j + 1])
            rel = sub(mul(mul(h, d1), d2), add(d1, d2))
        else:
            rel = sub(mul(h, d1), ONE)
        acc = add(acc, mul(mu[j], rel))
    return acc


def limbs(v, ix):
    """`limbs` (argument.rs:613): sum_k v[ix[k]] * 256^k."""
    acc = ZERO
    for j, i in enumerate(ix):
        acc = add(acc, mul(v[i], POW256[j]))
    return acc


class PadTerm:
    """`PadTerm` (argument.rs:677): the batched pad-zero term.  The `zeta`
    powers continue ACROSS the groups of one slot, so a plane is batched at
    one power and one only."""

    def __init__(self):
        self.groups = []
        self.mu = ZERO

    def add(self, supp, tables, zeta):
        if supp is None or not tables:
            return
        p = ONE
        for _ in range(sum(len(g) for _, g in self.groups)):
            p = mul(p, zeta)
        g = []
        for t in tables:
            g.append((t, p))
            p = mul(p, zeta)
        self.groups.append((supp, g))

    def eval(self, v):
        acc = ZERO
        for supp, tables in self.groups:
            anti = sub(ONE, v[supp])
            inner = ZERO
            for t, w in tables:
                inner = add(inner, mul(w, v[t]))
            acc = add(acc, mul(anti, inner))
        return mul(self.mu, acc)


def gate_at(i, v):
    """`Gate::at` (argument.rs:727)."""
    return ONE if i is None else v[i]


def _runs(idx: list) -> list:
    """A sorted index list as inclusive runs, for reporting a table's
    support without printing the table."""
    out = []
    for i in idx:
        if out and i == out[-1][1] + 1:
            out[-1][1] = i
        else:
            out.append([i, i])
    return [tuple(r) for r in out]


# =====================================================================
#  one slot's context: the resolution of a plane NAME to a table index
# =====================================================================
class SlotCtx:
    """Everything a covered slot's closure captured, resolved through the
    PLANE INDEX TABLE rather than through a ported id map.

    `t(name, k)` is the table index of the `k`-th time this slot pushes the
    plane called `name` -- the analogue of `B::tab` (argument.rs:508), which
    the Rust resolves through its own shaped map.  Addressing by name is what
    makes a re-ordered or re-pointed plane list change the ARITHMETIC and not
    just a label: the polynomial then reads a different terminal.
    """

    def __init__(self, gate, arg, plane_names, dc, lam_z, structural=True):
        self.g = gate
        self.arg = arg
        self.slot = arg["slot"]
        self.dc = dc
        self.lam_z = lam_z
        self.structural = structural
        self.alpha, self.beta = gate.alpha, gate.beta
        self.g_u8, self.g_exp, self.g_act = gate.g_u8, gate.g_exp, gate.g_act
        self.main = arg["main"]
        self.cube = 1 << arg["main"]
        self.names = list(plane_names)
        self.eq_idx, self.pub_idx, self.priv_idx = [], [], []
        for i, tab in enumerate(arg["tables"]):
            if tab["kind"] == "eq":
                self.eq_idx.append(i)
            elif tab["kind"] == "public":
                self.pub_idx.append(i)
            else:
                self.priv_idx.append(i)
        if len(self.names) != len(self.priv_idx):
            raise ValueError(
                f"slot {self.slot}: the plane index table lists {len(self.names)} "
                f"planes for {len(self.priv_idx)} private tables"
            )
        self.by_name: dict[str, list[int]] = {}
        for j, nm in enumerate(self.names):
            self.by_name.setdefault(nm, []).append(self.priv_idx[j])
        self.pub_of: dict[tuple, int] = {}
        self.public_values: dict[int, list] = {}
        # which public tables are 0/1 base-field indicators (the fast path in
        # `vals`) and which are Fp2-valued (every captured one, and the byte
        # table, which carries the LogUp tag `g_u8`)
        self.public_is_base: dict[int, bool] = {}
        self.rho_full: list = []
        # [round 4] which definition of the two bilinear slots is in force,
        # and the group point this tool DERIVED for this slot.  A derived
        # point is never defaulted from the capture: a repaired bilinear
        # slot with no derived point is refused.
        self.bilinear_definition = None
        self.group_table_required = None
        self.derived_eq_points: dict[int, list] = {}
        self.eq_points_compared = 0

    # -------------------------------------------------------------- lookups
    def expect(self, want: list) -> None:
        """The port's DECLARED push order.  A run with `structural=False`
        drops this check, so that a control can show the identity itself
        failing rather than the label."""
        if self.structural and self.names != want:
            raise ValueError(
                f"slot {self.slot}: the plane index table's push order "
                f"{self.names} is not the ported {want}"
            )

    def t(self, name: str, k: int = 0) -> int:
        try:
            return self.by_name[name][k]
        except (KeyError, IndexError):
            raise ValueError(
                f"slot {self.slot} does not push plane {name!r} {k + 1} time(s): "
                f"the plane index table's push order is {self.names}"
            ) from None

    def p(self, kind: str, dom):
        """The table index of the public table `(kind, dom)`, or None when
        this shape pushes none (a domain that does not pad has no `supp`)."""
        return self.pub_of.get((kind, dom))

    def c(self, label: str) -> int:
        """The table index of the CAPTURED public table called `label` --
        one this tool cannot rebuild, taken from the bundle after its length,
        its SHA-256 and its structure were checked.  Absent (a bundle with no
        public table values) raises, so the slot stays OPEN and is never
        reported checked."""
        i = self.pub_of.get(("captured", label))
        if i is None:
            raise ValueError(
                f"slot {self.slot}: the public table {label!r} is not in this "
                "bundle (`public_tables_included` is false), so the slot's "
                "polynomial cannot be evaluated"
            )
        return i

    def eq(self, i: int) -> int:
        return self.eq_idx[i]

    def group_gate(self, v):
        """`Gate(b.group_eq(r_g)).at(v)` (argument.rs:488, :754) -- the
        PUBLIC group factor of a bilinear slot, or ONE.

        The definition in force decides whether there must be a table, and
        the structure is checked both ways: a repaired slot at a grouped
        shape MUST carry exactly one eq table whose point this tool derived
        for itself, and a pre-repair slot (or a shape with one key-value
        head) MUST carry none.  Either mismatch is a refusal, so the port
        cannot silently evaluate one definition's polynomial on the other
        definition's bytes."""
        if self.slot not in BILINEAR_SLOTS:
            raise ValueError(f"slot {self.slot} is not a bilinear attention slot")
        if self.bilinear_definition is None or self.group_table_required is None:
            raise ValueError(
                f"slot {self.slot}: no definition of the bilinear attention slots "
                "is in force for this bundle, so its polynomial is unknown"
            )
        if not self.group_table_required:
            if self.eq_idx:
                raise ValueError(
                    f"slot {self.slot}: the {self.bilinear_definition} definition "
                    "at this shape has no public group table and the bundle "
                    f"declares {len(self.eq_idx)}"
                )
            return ONE
        if len(self.eq_idx) != 1:
            raise ValueError(
                f"slot {self.slot}: the repaired definition at this shape has "
                f"exactly one public group table and the bundle declares "
                f"{len(self.eq_idx)}"
            )
        if self.eq_idx[0] not in self.derived_eq_points:
            raise ValueError(
                f"slot {self.slot}: no group point was DERIVED for this slot (its "
                "derivation refused, or the comparison with the bundle's failed), "
                "and the port will not fall back to the point the capture names"
            )
        return v[self.eq_idx[0]]

    # --------------------------------------------- [ROUND 9] finding M-F1
    def pad_on(self, *doms: str) -> bool:
        """`pad_on` of `argument.rs:936` -- whether this slot's batched
        pad-zero term EXISTS, and therefore whether the slot draws the extra
        `mu` entry and the `zeta`.

        `pad_on = !pad_doms.is_empty()`, and `pad_doms` keeps a domain only
        when `pad::zero_rule_a_planes(sh, ids, d)` is non-empty -- which that
        function's own doc line says is "empty when the profile carries no
        pad rule OR THE DOMAIN DOES NOT PAD" (pad.rs:361-369, and `a_rule`:
        "planes on unpadded domains carry no rule").  So it is exactly
        `any(Shape::pads(d))` over the domains this slot HOSTS
        (`pad::pad_zero_host`).

        **Until round 9 every port hardcoded this true**, because at the toy
        and at both development rungs every domain pads.  At the 125M shape
        three do not -- `Dom::T` (512 tokens), `Dom::Kv` (512*4*64 = 2^17)
        and `Dom::F` (512*2048 = 2^20) are exact powers of two -- and their
        three host slots consume two definition draws fewer each.  That is
        finding **M-F1**, and it is the reason this method exists.
        """
        return any(self.g.geom.pads(d) for d in doms)

    def pad_draws(self, lt: int, n_base: int, n_nu: int, *doms: str):
        """The slot's `(mu, nu, zeta)` at `argument.rs`'s own arithmetic:
        `mu(n_base + n_pad)`, `nu(n_nu)`, and `zeta` ONLY when `pad_on`.

        It also REFUSES by name when the capture does not declare exactly
        the draws the port consumes.  Before round 9 a mismatch here was an
        `IndexError` that the per-slot arm turned into "not checked: list
        index out of range" -- true, and useless.  A refusal that does not
        say what is wrong is the failure mode findings K4-F1 and R8-F1 are
        about, one level further in."""
        on = self.pad_on(*doms)
        n_pad = 1 if on else 0
        want = lt + n_base + n_pad + n_nu + n_pad
        if len(self.dc) != want:
            raise ValueError(
                f"slot {self.slot}: this slot consumes {want} definition "
                f"draws (tau {lt} + mu {n_base}+{n_pad} + nu {n_nu}"
                + (" + zeta 1" if on else " + no zeta, the domains "
                   f"{list(doms)} do not pad")
                + f") and the capture declares {len(self.dc)}"
            )
        mu = self.dc[lt:lt + n_base + n_pad]
        nu = self.dc[lt + n_base + n_pad:lt + n_base + n_pad + n_nu]
        zeta = self.dc[want - 1] if on else None
        return mu, nu, zeta, on

    def zero_planes(self, dom: str) -> list[int]:
        """`pad::zero_rule_a_planes(sh, ids, dom)` (pad.rs:365) mapped through
        `B::tab`: every `A` plane of the domain, in plane order, except
        `A_E` (the one EXEMPT plane, pad.rs:299).

        **[ROUND 9]** and EMPTY on a domain that does not pad, which is the
        other half of the same sentence of pad.rs and the other half of
        finding M-F1: on an unpadded domain the port would otherwise have
        built a pad term the prover never built."""
        if not self.g.geom.pads(dom):
            return []
        return [self.t(nm) for nm in self.g.a_plane_names_by_domain[dom]
                if nm != "A_E"]


# =====================================================================
#  the twelve ported polynomials
# =====================================================================
def _ss(v, cx, plane):
    """`SC_SS` / `SC_SSM` (argument.rs:908-926).  Tables: eq(r_t), the `A`
    plane, supp(Dom::D).
    `|v| g.at(v).mul(v[0]).mul(v[1]).mul(v[1])`"""
    cx.expect([plane])
    g = gate_at(cx.p("supp", "D"), v)
    return mul(mul(mul(g, v[cx.eq(0)]), v[cx.t(plane)]), v[cx.t(plane)])


def sc_ss(v, cx):
    return _ss(v, cx, "A_X")


def sc_ssm(v, cx):
    return _ss(v, cx, "A_X1")


def sc_tzc(v, cx):
    """`SC_TZC` (argument.rs:927-1000).  Draws tau(log T), mu(6 + n_pad),
    nu(2), zeta(1).  Push order: eq(tau) eq(r_t) eq(r_t2) A_D A_DSQ, nine
    `A_LIMB` sub-slices, A_DM A_DSQM, nine `A_LIMBM` sub-slices, then
    supp(Dom::T)."""
    n_limbs = 3 * LIMBS_ISQRT
    cx.expect(["A_D", "A_DSQ"] + ["A_LIMB"] * n_limbs
              + ["A_DM", "A_DSQM"] + ["A_LIMBM"] * n_limbs)
    lt = cx.g.log("T")
    mu, nu, zeta, pad_on = cx.pad_draws(lt, 6, 2, "T")
    gi = cx.p("supp", "T")
    i_tau, i_rt, i_rt2 = cx.eq(0), cx.eq(1), cx.eq(2)
    lim = [cx.t("A_LIMB", j) for j in range(n_limbs)]
    limm = [cx.t("A_LIMBM", j) for j in range(n_limbs)]

    def l3(ix, o):
        return add(add(v[ix[o]], mul(v[ix[o + 1]], POW256[1])),
                   mul(v[ix[o + 2]], POW256[2]))

    d, dsq = v[cx.t("A_D")], v[cx.t("A_DSQ")]
    dl, a1, a2 = l3(lim, 0), l3(lim, 3), l3(lim, 6)
    dm, dsqm = v[cx.t("A_DM")], v[cx.t("A_DSQM")]
    dlm, a1m, a2m = l3(limm, 0), l3(limm, 3), l3(limm, 6)
    zc = add(add(mul(mu[0], sub(dsq, mul(d, d))), mul(mu[1], sub(d, dl))),
             mul(mu[2], sub(sub(double(d), a1), a2)))
    zc = add(add(add(zc, mul(mu[3], sub(dsqm, mul(dm, dm)))),
                 mul(mu[4], sub(dm, dlm))),
             mul(mu[5], sub(sub(double(dm), a1m), a2m)))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[6]
        pz.add(gi, cx.zero_planes("T"), zeta)
    g = gate_at(gi, v)
    ceps = k(cx.g.cal.norm_ceps)              # [TINYLLAMA PORT] the shape's
    return add(add(mul(v[i_tau], add(zc, pz.eval(v))),
                   mul(mul(mul(nu[0], v[i_rt]), g), sub(add(dsq, a1), ceps))),
               mul(mul(mul(nu[1], v[i_rt2]), g), sub(add(dsqm, a1m), ceps)))


def sc_lzc(v, cx):
    """`SC_LZC` (argument.rs:1002-1030).  Draws tau(log L), mu_pad(1),
    zeta(1).  Push order: eq(tau) A_LIMB A_LIMBM H_L0, then supp(Dom::L).
    `|v| v[0].mul(helper_sum(v, &lks, h0, alpha, &mu).add(pz.eval(v)))`"""
    cx.expect(["A_LIMB", "A_LIMBM", "H_L0"])
    lt = cx.g.log("L")
    mu_p, _nu, zeta, pad_on = cx.pad_draws(lt, 0, 0, "L")
    gi = cx.p("supp", "L")
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu_p[0]
        pz.add(gi, cx.zero_planes("L"), zeta)
    lks = cx.g.lk_tables(cx, "L")
    mu = [ONE] * cx.g.n_helpers("L")
    return mul(v[cx.eq(0)],
               add(helper_sum(v, lks, cx.t("H_L0"), cx.alpha, mu), pz.eval(v)))


def sc_rs(v, cx):
    """`SC_RS` (argument.rs:1031-1047).  Draws p_ht(log Ht), lam_z(1).
    Push order: eq(p_ht) public(causal mask) A_E A_ZSEL, then supp(Dom::S).
    `|v| g.at(v).mul(v[0]).mul(v[1].mul(v[2]).add(lam.mul(v[3])))`"""
    cx.expect(["A_E", "A_ZSEL"])
    lam = cx.dc[cx.g.log("Ht")]
    g = gate_at(cx.p("supp", "S"), v)
    mask = v[cx.p("causal", None)]
    return mul(mul(g, v[cx.eq(0)]),
               add(mul(mask, v[cx.t("A_E")]), mul(lam, v[cx.t("A_ZSEL")])))


def _bilinear(v, cx, want):
    """`SC_SCORE` / `SC_PV`: two private factors, the first masked in
    extension round 0 and the second in round 1, times the PUBLIC group
    factor.

    **ROUND 4, finding S19-F1.**  Under the REPAIRED definition
    (argument.rs:1126-1187, stage 20) the polynomial is

        |v| ig.at(v).mul(v[iq]).mul(v[ik])

    -- `eq(r_g, rho[..lkv])` times the two terminals, degree 3, `lkv` extra
    main rounds.  Under the PRE-REPAIR definition it is the plain product
    `|v| v[0].mul(v[1])`, and so it is under either definition at a shape
    with ONE key-value head, where `lkv = 0` and `B::group_eq` returns
    nothing.  [`SlotCtx.group_gate`] is the `Gate`, and the group point it
    multiplies in is the one this tool DERIVED from the transcript and
    compared with the bundle's -- never the bundle's own.

    The key-value factor is read at the key-value GROUP, which under the
    repair is a summed variable of both factors rather than a fixed
    coordinate of both (correction C-1, trap T-3).  That is a fact about
    the claim POINT; `zk60_native_rg_gqa` re-derives the whole coordinate
    list of both factors and compares it with the capture's."""
    cx.expect(want)
    return mul(cx.group_gate(v), mul(v[cx.t(want[0])], v[cx.t(want[1])]))


def sc_score(v, cx):
    return _bilinear(v, cx, ["A_QR8", "A_KR8"])


def sc_pv(v, cx):
    return _bilinear(v, cx, ["A_P", "A_V8"])


def sc_szc(v, cx):
    """`SC_SZC` (argument.rs:1304-1378).  Draws tau(log S),
    mu(5 + n_help + 1 + n_pad), nu(2), zeta(1).  Push order: eq(tau)
    eq(p_ht) eq(p_s) public(causal), `A_S8 .. A_SG{ls-1}`, the `A_MX` and
    `A_SUM` `Dom::Ht` slices, `H_S0 .. H_S{n-1}`, `H_SEXP`, then supp(Ht)
    and supp(S).

    This is the slot that hosts TWO domains: `Dom::Ht` has no zero-check of
    its own, its two planes are read on the leading coordinates, and its
    indicator is lifted over the trailing `j` axis and carries its own
    pad-zero group (finding S9-F7)."""
    ls, lp = cx.g.counts["ls"], cx.g.counts["lp"]
    n_help = cx.g.n_helpers("S")
    cx.expect(["A_S8", "A_RSL", "A_ZSEL", "A_E", "A_P"]
              + [f"A_PL{j}" for j in range(lp)]
              + [f"A_SR{j}" for j in range(ls)]
              + [f"A_SG{j}" for j in range(ls)]
              + ["A_MX", "A_SUM"]
              + [f"H_S{j}" for j in range(n_help)] + ["H_SEXP"])
    lt = cx.g.log("S")
    mu, nu, zeta, pad_on = cx.pad_draws(lt, 5 + n_help + 1, 2, "Ht", "S")
    im = cx.p("causal", None)
    ght, gs = cx.p("supp", "Ht"), cx.p("supp", "S")
    imx, isum = cx.t("A_MX"), cx.t("A_SUM")
    i_pl = [cx.t(f"A_PL{j}") for j in range(lp)]
    i_sr = [cx.t(f"A_SR{j}") for j in range(ls)]
    i_sg = [cx.t(f"A_SG{j}") for j in range(ls)]
    pz = PadTerm()
    if pad_on and gs is not None:
        pz.mu = mu[5 + n_help + 1]
        pz.add(ght, [imx, isum], zeta)
        pz.add(gs, cx.zero_planes("S"), zeta)
    lks = cx.g.lk_tables(cx, "S")
    mask, s8 = v[im], v[cx.t("A_S8")]
    zsel, e, pp = v[cx.t("A_ZSEL")], v[cx.t("A_E")], v[cx.t("A_P")]
    sm, sr = v[isum], limbs(v, i_sr)
    # delta = max - the masked score, the masked score being
    # mask * (s8 + 127) - 127
    delta = add(sub(v[imx], mul(mask, add(s8, k(-MASK_SCORE)))), k(-MASK_SCORE))
    c0 = sub(mul(zsel, zsel), zsel)
    c1 = mul(zsel, delta)
    c2 = sub(sub(mul(mul(k(1 << F_P), mask), e), mul(pp, sm)), sr)
    c3 = sub(add(add(limbs(v, i_sg), sr), ONE), sm)
    c4 = sub(pp, limbs(v, i_pl))
    cxx = sub(mul(v[cx.t("H_SEXP")],
                  sub(cx.alpha, add(add(delta, mul(cx.beta, e)), cx.g_exp))), ONE)
    g = gate_at(gs, v)
    zc = add(add(helper_sum(v, lks, cx.t("H_S0"), cx.alpha, mu[5:5 + n_help]),
                 mul(mu[5 + n_help], cxx)), pz.eval(v))
    for m, c in zip(mu, [c0, c1, c2, c3, c4]):
        zc = add(zc, mul(mul(m, g), c))
    host_rs = add(sm, cx.lam_z)
    cal = cx.g.cal                            # [TINYLLAMA PORT] the shape's
    host_s = sub(add(mul(k(1 << cal.sh_s), s8), v[cx.t("A_RSL")]),
                 k(Calibration.half(cal.sh_s)))
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), gate_at(ght, v)), host_rs)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_s))


def sc_fzc(v, cx):
    """`SC_FZC` (argument.rs:1189-1245).  Draws tau(log F),
    mu(4 + n_help + n_pad), nu(2), zeta(1).  Push order: eq(tau) eq(p_g)
    eq(p_u), `A_G8 .. A_RH1`, `H_F0 .. H_F{n-1}`, `H_FACT`, then
    supp(Dom::F)."""
    n_help = cx.g.n_helpers("F")
    cx.expect(["A_G8", "A_RGL", "A_A16", "A_U16", "A_UL0", "A_UL1",
               "A_H16", "A_HL0", "A_HL1", "A_RH0", "A_RH1"]
              + [f"H_F{j}" for j in range(n_help)] + ["H_FACT"])
    lt = cx.g.log("F")
    mu, nu, zeta, pad_on = cx.pad_draws(lt, 4 + n_help, 2, "F")
    gi = cx.p("supp", "F")
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[4 + n_help]
        pz.add(gi, cx.zero_planes("F"), zeta)
    lks = cx.g.lk_tables(cx, "F")

    def l2(a, b):
        return add(v[cx.t(a)], mul(v[cx.t(b)], POW256[1]))

    g8, a16 = v[cx.t("A_G8")], v[cx.t("A_A16")]
    u16, h16 = v[cx.t("A_U16")], v[cx.t("A_H16")]
    cal = cx.g.cal                            # [TINYLLAMA PORT] the shape's
    f0 = add(sub(sub(mul(a16, u16), mul(k(1 << cal.sh_h), h16)),
                 l2("A_RH0", "A_RH1")), k(Calibration.half(cal.sh_h)))
    f1 = sub(add(u16, k(32768)), l2("A_UL0", "A_UL1"))
    f2 = sub(add(h16, k(32768)), l2("A_HL0", "A_HL1"))
    # the activation PAIR lookup's helper relation: the LogUp arm, never gated
    f_act = sub(mul(v[cx.t("H_FACT")],
                    sub(cx.alpha,
                        add(add(add(g8, k(128)), mul(cx.beta, a16)), cx.g_act))), ONE)
    g = gate_at(gi, v)
    zc = add(add(helper_sum(v, lks, cx.t("H_F0"), cx.alpha, mu[4:]),
                 mul(mu[3], f_act)), pz.eval(v))
    for m, c in zip(mu, [f0, f1, f2]):
        zc = add(zc, mul(mul(m, g), c))
    host_g = sub(add(mul(k(1 << cal.sh_g), g8), v[cx.t("A_RGL")]),
                 k(Calibration.half(cal.sh_g)))
    host_u = u16                       # SH_U = 0: no coefficient (T2 A.4)
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), g), host_g)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_u))


def sc_zs(v, cx):
    """`SC_ZS` (argument.rs:1427-1438).  Push order: public(all ones over
    `Dom::Tab`), `H_U`.  `|v| v[0].mul(v[1])`"""
    cx.expect(["H_U"])
    return mul(v[cx.p("ones", "Tab")], v[cx.t("H_U")])


def _io(v, cx, plane, io):
    """`SC_IO_IN` / `SC_IO_OUT` (argument.rs:1440-1447).  Push order:
    eq(tau over `Dom::D`), the block's `A` plane, the endpoint.
    `|v| v[0].mul(v[1].sub(v[2]))`

    **The run's two boundary claim sites.**  At a RUN the endpoint table is
    the EXTERNAL endpoint only in stage 0 (slot 21) and the last stage (slot
    22); in every other stage it is the internal BOUNDARY commitment, at the
    reserved pair the stage's position implies (`Layout::io_mask_row`,
    argument.rs:520-540).  The polynomial is the SAME one either way -- which
    is what the boundary construction is for -- and it is checked in every
    stage, so both claim sites of every boundary are covered: block `k`'s
    slot 22 and block `k+1`'s slot 21."""
    cx.expect([plane, io])
    return mul(v[cx.eq(0)], sub(v[cx.t(plane)], v[cx.t(io)]))


def sc_io_in(v, cx):
    return _io(v, cx, "A_X", "IO_IN")


def sc_io_out(v, cx):
    return _io(v, cx, "A_X2", "IO_OUT")


# =====================================================================
#  ROUND 3: the eleven slots that needed a captured public table
# =====================================================================
def _matmul(v, cx, plane, label):
    """The seven MATMUL slots (argument.rs:1028-1118): one private `A` plane
    and one FOLDED public weight table, and nothing else.
    `|v| v[0].mul(v[1])`

    `SC_QMM` / `SC_KMM` / `SC_VMM` / `SC_WO` fold the weight matrix over its
    OUTPUT index (`fold_rows_i8`, w is `(output j, input i)`); `SC_GMM` /
    `SC_UMM` / `SC_DMM` fold over the second index (`fold_cols_i8`, w is
    `(input i, output j)`).  Which one it is changes the table, never the
    polynomial, and the table is the capture's.
    """
    cx.expect([plane])
    return mul(v[cx.t(plane)], v[cx.c(label)])


def sc_qmm(v, cx):
    return _matmul(v, cx, "A_Y", "fold(w_q)")


def sc_kmm(v, cx):
    return _matmul(v, cx, "A_Y", "fold(w_k)")


def sc_vmm(v, cx):
    return _matmul(v, cx, "A_Y", "fold(w_v)")


def sc_wo(v, cx):
    return _matmul(v, cx, "A_O8", "fold(w_o)")


def sc_gmm(v, cx):
    return _matmul(v, cx, "A_YM", "fold(w_g)")


def sc_umm(v, cx):
    return _matmul(v, cx, "A_YM", "fold(w_u)")


def sc_dmm(v, cx):
    return _matmul(v, cx, "A_H16", "fold(w_d)")


def sc_dzc(v, cx):
    """`SC_DZC` (argument.rs:1119-1188).  Draws tau(log D),
    mu(11 + n_help + n_pad), nu(2), zeta(1).  Push order: eq(tau) eq(p_a)
    eq(p_z), the two GAIN tables, `A_X .. A_RDL`, the `A_D` and `A_DM`
    `Dom::T` slices, `H_D0 .. H_D{n-1}`, then supp(Dom::D).

    The eleven clauses are the two norm relations (`norm_a` on `x`, `norm_m`
    on `x1`), their int16 decompositions, residual 1, residual 2 and
    `z16`'s class; it hosts `SC_WO` and `SC_DMM`.  The two GAIN vectors are
    the only reason this slot could not be evaluated in round 2: they are
    the padded `gamma_a` / `gamma_m` of ruling P-2, public constants of the
    statement that no bundle carried until stage 18."""
    ln = cx.g.counts["ln"]
    n_help = cx.g.n_helpers("D")
    cx.expect(["A_X", "A_XL0", "A_XL1", "A_Y"]
              + [f"A_NR{j}" for j in range(ln)]
              + [f"A_NS{j}" for j in range(ln)]
              + ["A_AO", "A_AL0", "A_AL1", "A_RAL", "A_X1", "A_X1L0", "A_X1L1", "A_YM"]
              + [f"A_MR{j}" for j in range(ln)]
              + [f"A_MS{j}" for j in range(ln)]
              + ["A_Z16", "A_X2", "A_X2L0", "A_X2L1", "A_ZL0", "A_ZL1", "A_RDL"]
              + ["A_D", "A_DM"]
              + [f"H_D{j}" for j in range(n_help)])
    lt = cx.g.log("D")
    mu, nu, zeta, pad_on = cx.pad_draws(lt, 11 + n_help, 2, "D")
    gi = cx.p("supp", "D")
    ig, igm = cx.c("gamma_a"), cx.c("gamma_m")

    def at(nm):
        return v[cx.t(nm)]

    def l2(a, b):
        return add(v[cx.t(a)], mul(v[cx.t(b)], POW256[1]))

    x, y, ao, x1, d = at("A_X"), at("A_Y"), at("A_AO"), at("A_X1"), at("A_D")
    nmm, x2, z16, dm = at("A_YM"), at("A_X2"), at("A_Z16"), at("A_DM")
    nr = limbs(v, [cx.t(f"A_NR{j}") for j in range(ln)])
    ns = limbs(v, [cx.t(f"A_NS{j}") for j in range(ln)])
    mr = limbs(v, [cx.t(f"A_MR{j}") for j in range(ln)])
    ms = limbs(v, [cx.t(f"A_MS{j}") for j in range(ln)])
    # [TINYLLAMA PORT] tn, the two norms' SEPARATE multipliers and the AO / Z
    # shifts are the shape's (argument.rs SC_DZC: b_num = 2 cn_a for norm_a,
    # b_num_m = 2 cn_m for norm_m's clause c6)
    cal = cx.g.cal
    k_num, k_num_m = k(2 * cal.norm_cn_a), k(2 * cal.norm_cn_m)
    k_dv, k_den = k(1 << cal.norm_tn), k(1 << (cal.norm_tn + 1))
    c0 = sub(sub(add(mul(mul(k_num, v[ig]), x), mul(k_dv, d)),
                 mul(mul(k_den, y), d)), nr)
    c1 = sub(add(add(ns, nr), ONE), mul(k_den, d))
    c2 = sub(add(x, k(32768)), l2("A_XL0", "A_XL1"))
    c3 = sub(add(ao, k(32768)), l2("A_AL0", "A_AL1"))
    c4 = sub(add(x1, k(32768)), l2("A_X1L0", "A_X1L1"))
    c5 = sub(sub(x1, x), ao)
    c6 = sub(sub(add(mul(mul(k_num_m, v[igm]), x1), mul(k_dv, dm)),
                 mul(mul(k_den, nmm), dm)), mr)
    c7 = sub(add(add(ms, mr), ONE), mul(k_den, dm))
    c8 = sub(add(x2, k(32768)), l2("A_X2L0", "A_X2L1"))
    c9 = sub(sub(x2, x1), z16)
    c10 = sub(add(z16, k(32768)), l2("A_ZL0", "A_ZL1"))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[11 + n_help]
        pz.add(gi, cx.zero_planes("D"), zeta)
    lks = cx.g.lk_tables(cx, "D")
    g = gate_at(gi, v)
    zc = add(helper_sum(v, lks, cx.t("H_D0"), cx.alpha, mu[11:]), pz.eval(v))
    for m, c in zip(mu, [c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]):
        zc = add(zc, mul(mul(m, g), c))
    host_wo = sub(add(mul(k(1 << cal.sh_ao), ao), at("A_RAL")),
                  k(Calibration.half(cal.sh_ao)))
    host_dmm = sub(add(mul(k(1 << cal.sh_z), z16), at("A_RDL")),
                   k(Calibration.half(cal.sh_z)))
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), g), host_wo)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host_dmm))


def _zc_rope(v, cx, q):
    """`SC_QZC` / `SC_KVZC` (argument.rs:1244-1303).  Draws tau(log dom),
    mu(1 + n_help + n_pad), nu(2), zeta(1).  Push order: eq(tau), the two
    claim points, the RoPE `cos` and `sin` tables, the domain's `A` range,
    the PARTNER slice (the same source plane at the flipped coordinate), the
    `H` helpers, then supp(dom).

    The one clause is the RoPE relation `cos*src + sin*partner = 2^SH_ROPE *
    rot + rem - 2^(SH_ROPE-1)`; the partner is the same committed plane read
    with the bit at `log - log2(head_dim)` flipped (trap T-8), which is why
    the plane list names the source twice and the port reads occurrence 0
    and occurrence 1.  The `(cos, sin)` pair is the only reason this slot
    could not be evaluated in round 2."""
    dom = "Q" if q else "Kv"
    n_help = cx.g.n_helpers(dom)
    if q:
        rng = ["A_Q8", "A_RQL", "A_QR8", "A_RQRL", "A_O8", "A_RO0", "A_RO1"]
        src, rot, rem, hp = "A_Q8", "A_QR8", "A_RQRL", "H_Q"
    else:
        rng = ["A_K8", "A_RKL", "A_V8", "A_RVL", "A_KR8", "A_RKRL"]
        src, rot, rem, hp = "A_K8", "A_KR8", "A_RKRL", "H_KV"
    cx.expect(rng + [src] + [f"{hp}{j}" for j in range(n_help)])
    lt = cx.g.log(dom)
    mu, nu, zeta, pad_on = cx.pad_draws(lt, 1 + n_help, 2, dom)
    gi = cx.p("supp", dom)
    ic, isin = cx.c("rope_cos"), cx.c("rope_sin")
    i_src, iflip = cx.t(src, 0), cx.t(src, 1)

    def at(nm):
        return v[cx.t(nm)]

    rope = add(sub(sub(add(mul(v[ic], v[i_src]), mul(v[isin], v[iflip])),
                       mul(k(1 << SH_ROPE), v[cx.t(rot)])),
                   v[cx.t(rem)]),
               k(1 << (SH_ROPE - 1)))
    pz = PadTerm()
    if pad_on and gi is not None:
        pz.mu = mu[1 + n_help]
        pz.add(gi, cx.zero_planes(dom), zeta)
    lks = cx.g.lk_tables(cx, dom)
    g = gate_at(gi, v)
    zc = add(add(mul(mul(mu[0], g), rope),
                 helper_sum(v, lks, cx.t(f"{hp}0"), cx.alpha, mu[1:])),
             pz.eval(v))
    # [TINYLLAMA PORT] the Q/K/V and PV-output shifts are the shape's
    cal = cx.g.cal
    kq, half = k(1 << cal.sh_qkv), k(Calibration.half(cal.sh_qkv))
    if q:
        host1 = sub(add(mul(kq, at("A_Q8")), at("A_RQL")), half)
        host2 = sub(add(add(mul(k(1 << cal.sh_o), at("A_O8")), at("A_RO0")),
                        mul(at("A_RO1"), POW256[1])),
                    k(Calibration.half(cal.sh_o)))
    else:
        host1 = sub(add(mul(kq, at("A_K8")), at("A_RKL")), half)
        host2 = sub(add(mul(kq, at("A_V8")), at("A_RVL")), half)
    return add(add(mul(v[cx.eq(0)], zc),
                   mul(mul(mul(nu[0], v[cx.eq(1)]), g), host1)),
               mul(mul(mul(nu[1], v[cx.eq(2)]), g), host2))


def sc_qzc(v, cx):
    return _zc_rope(v, cx, True)


def sc_kvzc(v, cx):
    return _zc_rope(v, cx, False)


def sc_tab(v, cx):
    """`SC_TAB` (argument.rs:1381-1426).  Draws tau(log Tab), mu(3 + n_pad),
    zeta(1).  Push order: eq(tau), then three times (multiplicity `A`
    plane, table helper `H` plane, the table's public VALUES), then
    supp(Dom::Tab).

    The three relations are the LogUp table arms: `helper * (alpha - value)
    = multiplicity`, one per lookup table.  Two of the three value tables --
    exp and activation -- are functions of the public statement's quantised
    tables and are the capture's; the byte table is rebuilt here from
    `table_values_u8_at` and digest-compared.

    **Finding F-2's literal indices.**  The Rust addresses this slot's ten
    tables by LITERAL position because they are its own push order.  The
    port addresses them by NAME and then asserts the two agree, so a
    re-ordered plane list is caught by the same check that catches it
    everywhere else."""
    cx.expect(["A_MU8", "H_GU8", "A_MEXP", "H_GEXP", "A_MACT", "H_GACT"])
    lt = cx.g.log("Tab")
    mu, _nu, zeta, pad_on = cx.pad_draws(lt, 3, 0, "Tab")
    i_u8 = cx.p("u8", None)
    triples = [
        (cx.t("A_MU8"), cx.t("H_GU8"), i_u8),
        (cx.t("A_MEXP"), cx.t("H_GEXP"), cx.c("exp_values")),
        (cx.t("A_MACT"), cx.t("H_GACT"), cx.c("act_values")),
    ]
    want = [(1, 2, 3), (4, 5, 6), (7, 8, 9)]
    if cx.structural and [tuple(t) for t in triples] != want:
        raise ValueError(
            f"slot 19: the (multiplicity, helper, values) table indices are "
            f"{[tuple(t) for t in triples]}, not this slot's own push order {want}"
        )
    rel = []
    for i_m, i_h, i_v in triples:
        rel.append(sub(mul(v[i_h], sub(cx.alpha, v[i_v])), v[i_m]))
    pz = PadTerm()
    si = cx.p("supp", "Tab")
    if pad_on and si is not None:
        pz.mu = mu[3]
        pz.add(si, [t[0] for t in triples], zeta)
        pz.add(si, [t[1] for t in triples], zeta)
    inner = add(add(add(mul(mu[0], rel[0]), mul(mu[1], rel[1])),
                    mul(mu[2], rel[2])), pz.eval(v))
    return mul(v[cx.eq(0)], inner)


# --------------------------------------------------------- the slot table
_WEIGHTS = (
    "the slot's public table is `fold_rows_i8` / `fold_cols_i8` of a public "
    "WEIGHT matrix at the round's point (argument.rs:1035, :1104).  A run "
    "bundle carries a public table's length and SHA-256 but not its values "
    "(`public_tables_included: false`), and it carries no weight matrix, so "
    "the table cannot be rebuilt from the bundle.  Nothing HIDDEN is missing: "
    "the weights are public.  Re-capturing with "
    "`HL_RUN_CAPTURE_PUBLIC_TABLES=1`, or carrying the folded table's "
    "preimage, closes this slot"
)

# slot -> the PUBLIC tables the ported closure needs, in push order.  A
# `("supp", dom)` entry is absent from the capture when the domain does not
# pad; the loader below skips it and the closure's `cx.p(...)` is then None,
# which is `Gate(None)` -- exactly `B::supp`'s `Ok(None)` (argument.rs:556).
#
# ROUND 3.  A `("captured", label, structure)` entry is a table this tool
# CANNOT rebuild -- it is a function of the public STATEMENT (a weight
# matrix, a norm gain, the RoPE constants, a quantised lookup table) and no
# bundle carries the statement.  Such a table is taken from the capture's
# own `values`, after its length and its SHA-256 are checked against the
# capture's own `len` and `sha256`, and after the STRUCTURE check `structure`
# names.  A bundle without `values` leaves every slot that has such an entry
# OPEN, exactly as in round 2.
PUBLIC_SPEC = {
    0: [("supp", "D")],
    1: [("supp", "D")],
    2: [("supp", "T")],
    3: [("supp", "L")],
    4: [("causal", None), ("supp", "S")],
    5: [("captured", "fold(w_q)", "weight_fold@width")],
    6: [("captured", "fold(w_k)", "weight_fold@width")],
    7: [("captured", "fold(w_v)", "weight_fold@width")],
    8: [],
    9: [],
    10: [("captured", "fold(w_o)", "weight_fold@heads")],
    11: [("captured", "fold(w_g)", "weight_fold@width")],
    12: [("captured", "fold(w_u)", "weight_fold@width")],
    13: [("captured", "fold(w_d)", "weight_fold@hidden")],
    14: [("captured", "gamma_a", "gain"),
         ("captured", "gamma_m", "gain"),
         ("supp", "D")],
    15: [("captured", "rope_cos", "rope_cos@Q"),
         ("captured", "rope_sin", "rope_sin@Q"),
         ("supp", "Q")],
    16: [("captured", "rope_cos", "rope_cos@Kv"),
         ("captured", "rope_sin", "rope_sin@Kv"),
         ("supp", "Kv")],
    17: [("causal", None), ("supp", "Ht"), ("supp", "S")],
    18: [("supp", "F")],
    19: [("u8", None),
         ("captured", "exp_values", "lookup_values"),
         ("captured", "act_values", "lookup_values"),
         ("supp", "Tab")],
    20: [("ones", "Tab")],
    21: [],
    22: [],
}

# The slots whose port needs a table no tool can rebuild from a bundle, and
# the plain-words reason -- reported per slot whenever a bundle carries no
# values, and reported as TAKEN FROM THE CAPTURE when it does.
PUBLIC_WHAT = {
    "fold(w_q)": "fold_rows_i8 of the public query weight matrix at the round's point "
                 "(argument.rs:1048)",
    "fold(w_k)": "fold_rows_i8 of the public key weight matrix (argument.rs:1048)",
    "fold(w_v)": "fold_rows_i8 of the public value weight matrix (argument.rs:1048)",
    "fold(w_o)": "fold_rows_i8 of the public output-projection matrix (argument.rs:1048)",
    "fold(w_g)": "fold_cols_i8 of the public gate weight matrix (argument.rs:1110)",
    "fold(w_u)": "fold_cols_i8 of the public up weight matrix (argument.rs:1110)",
    "fold(w_d)": "fold_cols_i8 of the public down weight matrix (argument.rs:1110)",
    "gamma_a": "the padded attention norm gain vector (argument.rs:1132)",
    "gamma_m": "the padded feed-forward norm gain vector (argument.rs:1133)",
    "rope_cos": "the RoPE cos table at this domain (rope_tables_at, argument.rs:790)",
    "rope_sin": "the RoPE sin table at this domain (rope_tables_at, argument.rs:790)",
    "exp_values": "the exp lookup table's public rows i + beta*exp[i] + g_exp "
                  "(table_values_exp_at, argument.rs:843)",
    "act_values": "the activation lookup table's public rows i + beta*act[i] + g_act "
                  "(table_values_act_at, argument.rs:854)",
}

TAKEN_FROM_CAPTURE = {
    5: "a fold of the public query weight matrix",
    6: "a fold of the public key weight matrix",
    7: "a fold of the public value weight matrix",
    10: "a fold of the public output-projection weight matrix",
    11: "a fold of the public gate weight matrix",
    12: "a fold of the public up weight matrix",
    13: "a fold of the public down weight matrix",
    14: "the two padded norm gain vectors",
    15: "the RoPE (cos, sin) pair on Dom::Q",
    16: "the RoPE (cos, sin) pair on Dom::Kv",
    19: "the exp and activation lookup tables' values",
}

# `(slot, name, the ported polynomial, the reason it can be OPEN)`.  A slot
# whose reason is not None is evaluated only when the bundle carries the
# public table VALUES its port needs; on a bundle without them the reason is
# what the record reports, exactly as in round 2.
PORTS = (
    (0, "SC_SS", sc_ss, None),
    (1, "SC_SSM", sc_ssm, None),
    (2, "SC_TZC", sc_tzc, None),
    (3, "SC_LZC", sc_lzc, None),
    (4, "SC_RS", sc_rs, None),
    (5, "SC_QMM", sc_qmm, _WEIGHTS),
    (6, "SC_KMM", sc_kmm, _WEIGHTS),
    (7, "SC_VMM", sc_vmm, _WEIGHTS),
    (8, "SC_SCORE", sc_score, None),
    (9, "SC_PV", sc_pv, None),
    (10, "SC_WO", sc_wo, _WEIGHTS),
    (11, "SC_GMM", sc_gmm, _WEIGHTS),
    (12, "SC_UMM", sc_umm, _WEIGHTS),
    (13, "SC_DMM", sc_dmm, _WEIGHTS),
    (14, "SC_DZC", sc_dzc,
     "two of the slot's three public tables are the padded norm GAIN vectors "
     "`ctx.public.gamma_a` and `ctx.ff.gamma_m` (argument.rs:1132-1133).  They "
     "are public constants of the statement, but a bundle without "
     "`public_tables_included` carries neither them nor the tables they build, "
     "so the polynomial cannot be evaluated.  The third table, `supp(Dom::D)`, "
     "IS rebuildable and its digest matches where slots 0 and 1 use it"),
    (15, "SC_QZC", sc_qzc,
     "two of the slot's three public tables are the RoPE `(cos, sin)` pair "
     "`rope_tables_at(sh, ctx.public, dom)` (argument.rs:1258), a function of "
     "the public statement's RoPE constants, which a bundle without "
     "`public_tables_included` does not carry"),
    (16, "SC_KVZC", sc_kvzc,
     "as slot 15, on `Dom::Kv`: the RoPE `(cos, sin)` pair is not in a bundle "
     "without `public_tables_included`"),
    (17, "SC_SZC", sc_szc, None),
    (18, "SC_FZC", sc_fzc, None),
    (19, "SC_TAB", sc_tab,
     "two of the slot's four public tables are `table_values_exp_at(..., "
     "ctx.public, beta, g_exp)` and `table_values_act_at(..., ctx.ff, beta, "
     "g_act)` (argument.rs:1391, :1394) -- the exp and activation LOOKUP "
     "table values, functions of the public statement's quantised tables, "
     "which a bundle without `public_tables_included` does not carry.  The "
     "other two, `table_values_u8_at` and `supp(Dom::Tab)`, are rebuildable; "
     "two of four are not, so the slot is not evaluated"),
    (20, "SC_ZS", sc_zs, None),
    (21, "SC_IO_IN", sc_io_in, None),
    (22, "SC_IO_OUT", sc_io_out, None),
)

# The twelve that need nothing but the shape, and the eleven that need the
# captured public tables as well.
COVERED_WITHOUT_TABLES = tuple(s for s, _n, fn, r in PORTS if fn is not None and r is None)
COVERED_WITH_TABLES = tuple(s for s, _n, fn, r in PORTS if fn is not None and r is not None)
COVERED = tuple(s for s, _n, fn, _r in PORTS if fn is not None)


def covered_at(bundle) -> tuple:
    """Which slots this port can evaluate for THIS bundle: the twelve
    shape-only ones always, and the other eleven only when the bundle
    carries its public tables' values."""
    if getattr(bundle, "public_tables_included", False):
        return COVERED
    return COVERED_WITHOUT_TABLES


# =====================================================================
#  the gate over a whole run
# =====================================================================
class TerminalGate:
    """The port, instantiated at one bundle's shape and plane index."""

    def __init__(self, bundle, index):
        self.bundle = bundle
        self.index = index
        self.shape_raw = bundle.run["shape"]
        self.geom = PadGeometry(self.shape_raw, index.domain_log)
        # [TINYLLAMA PORT] the slot closures read `cx.g.cal`
        self.cal = self.geom.cal
        self.alpha = self.beta = None
        self.g_u8 = self.g_exp = self.g_act = None
        self.public_tables: dict[tuple, str] = {}
        self.public_digest_failures: list[str] = []
        # round 3: the tables that are TAKEN from the capture, and the
        # structure checks they pass before the port will use one
        self.captured_tables: dict[tuple, str] = {}
        self.public_structure_failures: list[str] = []
        self.structure_checks = 0
        self.structure_detail: dict[str, list] = {}
        # the plane names of each domain, in PLANE ORDER: the name-space form
        # of `pad::zero_rule_a_planes`' iteration
        self.a_plane_names_by_domain: dict[str, list[str]] = {}
        for p in index.a_planes:
            self.a_plane_names_by_domain.setdefault(p.domain, []).append(p.name)
        self.h_plane_names_by_domain: dict[str, list[str]] = {}
        for p in index.h_planes:
            self.h_plane_names_by_domain.setdefault(p.domain, []).append(p.name)
        # the three byte-limb counts, READ from the table's own plane names
        self.counts = {"ln": self._group("A_NR"), "ls": self._group("A_SR"),
                       "lp": self._group("A_PL")}
        self._lk_cache: dict[str, list] = {}

    def _group(self, prefix: str) -> int:
        pat = re.compile("^" + prefix + r"\d+$")
        return sum(1 for p in self.index.a_planes if pat.match(p.name))

    def set_logup(self, logup_challenges) -> None:
        """`protocol.rs:660-662`: the stage draws (beta, gamma, alpha) and
        makes `g_x = gamma * TAG_x`."""
        beta, gamma, alpha = (f2_from_list(x) for x in logup_challenges)
        self.alpha, self.beta = alpha, beta
        self.g_u8 = mulb(gamma, TAG_U8)
        self.g_exp = mulb(gamma, TAG_EXP)
        self.g_act = mulb(gamma, TAG_ACT)

    def log(self, dom: str) -> int:
        return self.geom.log(dom)

    def n_helpers(self, dom: str) -> int:
        """`Shape::helpers(dom)`, READ from the plane index: the `H` planes of
        the domain, minus the ONE extra pair helper `Dom::S` and `Dom::F`
        carry (`H_SEXP`, `H_FACT` -- shape.rs:486-489)."""
        extra = {"S": "H_SEXP", "F": "H_FACT"}.get(dom)
        return sum(1 for n in self.h_plane_names_by_domain.get(dom, [])
                   if n != extra)

    def lk_tables(self, cx, dom: str):
        """`lk_tables` (argument.rs:634), in this slot's table-index space."""
        lks = self._lk_cache.get(dom)
        if lks is None:
            lks = lookups_at(dom, self.counts, self.shape_raw)
            self._lk_cache[dom] = lks
        return [([(cx.t(nm), c) for (nm, c) in terms], add(k(cst), self.g_u8))
                for (terms, cst) in lks]

    # ---------------------------------- the public tables, rebuilt or taken
    def build_public(self, cx, check_digests=True) -> None:
        """Place every public table the slot's port declares at its table
        index.

        A table that is a function of the SHAPE is REBUILT here and compared
        with the capture's own SHA-256; a digest that differs is a refusal,
        because the port would otherwise evaluate a polynomial the verifier
        never evaluated.  A table that is a function of the public STATEMENT
        is TAKEN from the capture's `values`, after three checks of its own:
        the length against the capture's `len`, the SHA-256 against the
        capture's `sha256`, and the STRUCTURE its builder gives it.

        `check_digests=False` is for ONE control, which shows that a
        perturbed table value is caught by the arithmetic and not only by
        the digest; nothing else may call it that way.
        """
        spec = PUBLIC_SPEC[cx.slot]
        built = []
        for entry in spec:
            kind, dom = entry[0], entry[1]
            label = entry[1] if kind == "captured" else None
            structure = entry[2] if kind == "captured" else None
            if kind == "supp":
                vals = self.geom.supp(dom, cx.cube)
                what = f"supp({dom})"
            elif kind == "causal":
                vals = self.geom.causal_mask()
                what = "causal_mask_at"
            elif kind == "ones":
                vals = self.geom.ones_tab()
                what = "the all-ones Dom::Tab vector"
            elif kind == "u8":
                # `table_values_u8_at(len, g_u8)` (argument.rs:834): the byte
                # class lifted by repetition, the P-3 lift's first condition
                vals = [add(k(i % U8_LEN), self.g_u8) for i in range(cx.cube)]
                what = "table_values_u8_at"
            else:
                vals = None                      # taken below, never rebuilt
                what = PUBLIC_WHAT[label]
            if kind != "captured" and vals is None:   # the domain does not pad
                continue
            built.append((kind, dom, label, structure, what, vals))
        if len(built) != len(cx.pub_idx):
            raise ValueError(
                f"slot {cx.slot}: the port declares {len(built)} public tables, "
                f"the capture has {len(cx.pub_idx)}"
            )
        for (kind, dom, label, structure, what, vals), i in zip(built, cx.pub_idx):
            tab = cx.arg["tables"][i]
            if kind == "captured":
                got = tab.get("values")
                if got is None:
                    raise ValueError(
                        f"slot {cx.slot} public table {i} ({what}): the capture "
                        "carries no values for it"
                    )
                vals = [f2_from_list(x) for x in got]
                if tab["len"] != len(vals):
                    raise ValueError(
                        f"slot {cx.slot} public table {i} ({what}): the capture "
                        f"declares {tab['len']} entries and carries {len(vals)}"
                    )
                if check_digests:
                    d = table_digest(vals)
                    if d != tab["sha256"]:
                        self.public_digest_failures.append(
                            f"slot {cx.slot} public table {i} ({what}): the values "
                            f"hash to {d[:12]}, the capture declares {tab['sha256'][:12]}"
                        )
                        raise ValueError(
                            f"slot {cx.slot} public table {i} ({what}): the carried "
                            "values are not the ones the capture's digest names"
                        )
                bad = self.check_structure(structure, label, vals)
                if bad:
                    self.public_structure_failures += bad
                    raise ValueError(
                        f"slot {cx.slot} public table {i} ({what}): {bad[0]}"
                    )
                self.captured_tables[(cx.slot, i)] = what
                cx.pub_of[("captured", label)] = i
                cx.public_values[i] = vals
                cx.public_is_base[i] = False
                continue
            if tab["len"] != len(vals):
                raise ValueError(
                    f"slot {cx.slot} public table {i} ({what}): the capture has "
                    f"{tab['len']} entries, the rebuilt one {len(vals)}"
                )
            d = table_digest(vals)
            if check_digests and d != tab["sha256"]:
                self.public_digest_failures.append(
                    f"slot {cx.slot} public table {i} ({what}): the rebuilt digest "
                    f"{d[:12]} is not the capture's {tab['sha256'][:12]}"
                )
                raise ValueError(
                    f"slot {cx.slot} public table {i} ({what}): the rebuilt table "
                    "is not the captured one"
                )
            self.public_tables[(cx.slot, i)] = what
            cx.pub_of[(kind, dom)] = i
            cx.public_values[i] = vals
            cx.public_is_base[i] = kind != "u8"

    # ------------------------------- the structure of a CAPTURED table
    def check_structure(self, structure: str, label: str, vals) -> list:
        """**A captured table is not a blob.**  Each one has a shape its
        builder gives it, and every one of those shapes is a function of the
        PUBLIC statement's geometry, so it can be checked without the
        statement itself.  A failure is returned as a named string; the
        caller refuses.

        What this does NOT establish: that a fold is the fold of the weight
        matrix the statement names.  No bundle carries a weight, so that
        stays a reading of the capture, and it is said so per slot.
        """
        s = self.shape_raw
        out = []
        self.structure_checks += 1
        if structure.startswith("weight_fold@"):
            # ruling P-2: a public weight matrix vanishes off ITS OWN input
            # index's support, so its fold does too, at every point.  Which
            # support that is depends on the matrix: the three attention
            # projections and the two feed-forward inputs are indexed by the
            # residual WIDTH, the output projection by the PADDED HEAD SLOTS
            # (a dead head slot is not an index above the width), and the
            # down projection by the HIDDEN dimension.
            kind = structure.split("@")[1]
            n, dh = len(vals), s["head_dim"]
            want_len = s["f_pad"] if kind == "hidden" else s["d_pad"]
            if n != want_len:
                out.append(f"{label}: a fold of {n} entries, not {want_len}")
            else:
                if kind == "width":
                    live = set(range(s["width"]))
                elif kind == "hidden":
                    live = set(range(s["hidden"]))
                else:
                    slots = {self.geom.head_slot(h) for h in range(s["q_heads"])}
                    live = {sl * dh + i for sl in slots for i in range(dh)}
                bad = [i for i in range(n) if i not in live and vals[i] != ZERO]
                if bad:
                    out.append(
                        f"{label}: the fold is nonzero at {len(bad)} positions "
                        f"outside the {kind} support (first {bad[0]}), and ruling "
                        "P-2 says a public weight vanishes off the support"
                    )
                self.structure_detail.setdefault(label, []).append(
                    {"support": kind, "live_positions": len(live),
                     "nonzero_positions": sum(1 for x in vals if x != ZERO),
                     "runs": _runs([i for i, x in enumerate(vals) if x != ZERO])}
                )
        elif structure == "gain":
            dp, w = s["d_pad"], s["width"]
            if len(vals) != self.geom.size("D"):
                out.append(f"{label}: {len(vals)} entries, not |Dom::D|")
            else:
                per = [i for i in range(len(vals)) if vals[i] != vals[i % dp]]
                if per:
                    out.append(
                        f"{label}: not periodic in the padded width "
                        f"({len(per)} positions differ, first {per[0]})"
                    )
                bad = [i for i in range(dp) if i >= w and vals[i] != ZERO]
                if bad:
                    out.append(
                        f"{label}: nonzero at {len(bad)} padded columns of the "
                        f"first period (first {bad[0]}), against ruling P-2"
                    )
        elif structure.startswith("rope_"):
            kind, dom = structure.split("@")
            out += self._rope_structure(kind, dom, label, vals)
        elif structure == "lookup_values":
            out += self._lookup_structure(label, vals)
        else:
            out.append(f"{label}: no structure check is declared for it")
        if out:
            self.structure_checks -= 1
        return out

    def _rope_structure(self, structure: str, dom: str, label: str, vals) -> list:
        """`rope_tables_at` (argument.rs:790): zero off the live set, and
        within a head `cos` repeats at the partner coordinate while `sin`
        NEGATES there -- `-sin[at]` on the low half and `+sin[at]` on the
        high half of one head."""
        s = self.shape_raw
        dh, heads = s["head_dim"], (s["h_pad"] if dom == "Q" else s["kv_heads"])
        half, n = dh // 2, self.geom.size(dom)
        out = []
        if len(vals) != n:
            return [f"{label}: {len(vals)} entries, not |Dom::{dom}| = {n}"]
        true_slots = ({self.geom.head_slot(h) for h in range(s["q_heads"])}
                      if dom == "Q" else set(range(s["kv_heads"])))
        dead, sym = 0, 0
        for x in range(n):
            i, slot, t = x % dh, (x // dh) % heads, x // (dh * heads)
            live = (t < s["tokens"] and (dom != "Q" or slot in true_slots)
                    and x < s["t_pad"] * heads * dh)
            if not live:
                if vals[x] != ZERO:
                    out.append(f"{label}: nonzero at the dead position {x}")
                    break
                dead += 1
            elif i < half:
                want = vals[x] if structure == "rope_cos" else f2_neg(vals[x])
                if vals[x + half] != want:
                    out.append(
                        f"{label}: the partner at {x + half} is not the "
                        f"{'repeat' if structure == 'rope_cos' else 'negation'} "
                        f"of {x}"
                    )
                    break
                sym += 1
        self.structure_detail.setdefault(label, []).append(
            {"dead_positions": dead, "partner_pairs": sym}
        )
        return out

    def _lookup_structure(self, label: str, vals) -> list:
        """`table_values_exp_at` / `table_values_act_at` (argument.rs:843,
        :854): `value[x] = (x % 256) + beta * T[x % 256] + g`.  The port
        recovers `T` and checks it is a BASE-field element and a small
        integer -- which is what a quantised lookup table's entries are, and
        what a random 16-byte blob is not."""
        out = []
        n = self.geom.size("Tab")
        if len(vals) != n:
            return [f"{label}: {len(vals)} entries, not |Dom::Tab| = {n}"]
        g = self.g_exp if label == "exp_values" else self.g_act
        per = [x for x in range(n) if vals[x] != vals[x % U8_LEN]]
        if per:
            return [
                f"{label}: not periodic in the byte class after the P-3 lift "
                f"({len(per)} positions differ, first {per[0]})"
            ]
        binv = f2_inv(self.beta)
        big = []
        recovered = []
        for i in range(U8_LEN):
            t = mul(sub(sub(vals[i], k(i)), g), binv)
            if t[1] != 0:
                out.append(f"{label}: entry {i} does not recover a base-field value")
                break
            signed = t[0] if t[0] < P // 2 else t[0] - P
            recovered.append(signed)
            if abs(signed) >= 1 << 32:
                big.append(i)
        if big:
            out.append(
                f"{label}: {len(big)} recovered entries are not small integers "
                f"(first {big[0]})"
            )
        detail = {"recovered_entries": U8_LEN}
        # [TINYLLAMA PORT 2026-10-17] at a TRAINED profile each block carries
        # its OWN exp / SiLU table (per-layer table keys), so the record names
        # which table each stage carried -- the SHA-256 of the recovered
        # int64 entries -- and the two entries a pad relies on: exp[0] =
        # 2^f_e and act[128] = 0 (the condition ruling S38-F1(a) refused
        # otherwise, absent from the trained tree, finding G-1).  Recorded
        # only when the bundle declares a trained calibration, so no frozen
        # record gains a leaf.
        if self.cal.trained and len(recovered) == U8_LEN:
            raw = b"".join(int(v).to_bytes(8, "little", signed=True)
                           for v in recovered)
            detail["recovered_sha256"] = hashlib.sha256(raw).hexdigest()
            if label == "act_values":
                detail["act_128"] = recovered[128]
                detail["act_128_is_zero"] = recovered[128] == 0
            else:
                detail["exp_0"] = recovered[0]
        self.structure_detail.setdefault(label, []).append(detail)
        return out

    # --------------------------------------------------------- the vals list
    def vals(self, cx):
        """The verifier's `vals` (argument.rs:365-378).  `sel` multiplies the
        PUBLIC entries only; a private table contributes its published
        terminal unchanged."""
        arg = cx.arg
        main = arg["main"]
        sel = ONE
        for e in cx.rho_full[main:]:
            sel = mul(sel, sub(ONE, e))
        rho_main = cx.rho_full[:main]
        eq_msb = None
        out, kt = [], 0
        terminals = arg["terminals"]
        for i, tab in enumerate(arg["tables"]):
            if tab["kind"] == "eq":
                point = [f2_from_list(x) for x in tab["point"]]
                start = tab["start"]
                # [round 4] a table this tool DERIVED for itself is used in
                # its derived form, and the bundle's is only compared.  The
                # comparison already happened in `zk60_native_rg_gqa`; it is
                # repeated here so that no path can reach the arithmetic
                # with the two disagreeing.
                derived = cx.derived_eq_points.get(i)
                if derived is not None:
                    cx.eq_points_compared += 1
                    if derived != point:
                        raise ValueError(
                            f"slot {cx.slot}: the eq point this tool derived is not "
                            "the one the bundle names, so the slot is refused rather "
                            "than evaluated at the prover's own point"
                        )
                    point = derived
                out.append(mul(sel, eq_point(point, rho_main[start:start + len(point)])))
            elif tab["kind"] == "public":
                values = cx.public_values[i]
                if len(values) != 1 << main:
                    raise ValueError("public table length differs from 2^main")
                if eq_msb is None:
                    eq_msb = eq_table_msb(rho_main)
                acc = ZERO
                if cx.public_is_base.get(i, True):
                    for x, e in zip(values, eq_msb):
                        if x:
                            acc = add(acc, mulb(e, x % P))
                else:
                    # an Fp2-valued public table: `eval_mle_ext` over the
                    # captured (or tagged) values, not the 0/1 fast path
                    for x, e in zip(values, eq_msb):
                        if x != ZERO:
                            acc = add(acc, mul(e, x))
                out.append(mul(sel, acc))
            else:
                out.append(f2_from_list(terminals[kt]))
                kt += 1
        if kt != len(terminals):
            raise ValueError("private table count differs from the terminal count")
        return out


def lam_z_of(stage_doc):
    """`pts.lam_z`, drawn by `SC_RS` (argument.rs:1036) as the challenge
    after `p_ht`, and read by `SC_SZC`."""
    return f2_from_list(stage_doc["arguments"][4]["definition_challenges"][-1])


def check_terminals(bundle, index, replay=None, structural=True,
                    stage_docs=None, slot_planes=None, check_digests=True,
                    group=None, force_definition=None) -> dict:
    """The per-slot terminal identity over every stage of the run.

    `stage_docs` / `slot_planes` override the bundle's own, which is how a
    control perturbs a terminal or a plane list without writing any file.
    `structural=False` drops the port's declared push-order check, so that a
    control can show the ARITHMETIC failing and not merely the label.

    `group` is a ready-made [`GroupFactors`] (round 4): the two bilinear
    slots' group point, derived from the shape and the replayed transcript.
    When it is not given, one is built here from the same inputs, so every
    caller -- the gate and every control -- gets the derived factor without
    asking.  `force_definition` makes a control evaluate the OTHER
    definition of those two slots on these bytes.
    """
    gate = TerminalGate(bundle, index)
    covered = covered_at(bundle)
    out = {
        "what": "fin_s == c_s * mask_eval_s + poly_s(vals_s), the verifier's own "
        "final check (argument.rs:381), recomputed from the published terminals "
        "and compared with the capture's `terminal_polynomial` (= fin - c*mask_eval)",
        "bundle": bundle.name,
        "source_pins": check_source_pins(bundle),
        "structural_push_order_check": structural,
        "public_table_digest_check": check_digests,
        "challenges_from": "transcript replay" if replay is not None else "the capture",
        "public_tables_included": bool(getattr(bundle, "public_tables_included", False)),
        "slots_per_stage": bundle.shape.n_slots,
        "stages": bundle.blocks,
        "covered_slots": list(covered),
        "covered_without_captured_tables": list(COVERED_WITHOUT_TABLES),
        "covered_only_with_captured_tables": [s for s in covered
                                              if s in COVERED_WITH_TABLES],
        "slot_checks_attempted": 0,
        "slot_checks_equal": 0,
        "slot_checks_matching_the_stored_terminal_polynomial": 0,
        "public_tables_rebuilt_and_digest_matched": 0,
        "public_tables_taken_from_the_capture": 0,
        "public_table_digest_failures": [],
        "public_table_structure_checks": 0,
        "public_table_structure_failures": [],
        "open_slots": [{"slot": s, "name": n, "reason": r}
                       for s, n, fn, r in PORTS if s not in covered],
        "per_stage": [],
        "findings": [],
        # [round 5, finding K4-F1] every key a CALLER reads, present from the
        # start.  The moved-pin arm below returns this dict as it stands, and
        # until round 5 it returned it WITHOUT these keys -- so `stage8` and
        # `terminal_controls` raised `KeyError: 'slot_checks_expected'` and
        # the whole gate died with a traceback instead of reporting the
        # refusal it had correctly computed.  A refusal path that crashes is
        # not a refusal path, and this one had never been exercised
        # end-to-end because no bundle had ever moved a pin.  The rung-K4
        # bundles moved two.
        "slot_checks_expected": len(covered) * bundle.blocks,
        "slots_open_per_stage": bundle.shape.n_slots - len(covered),
        "derived_group_points_used_and_compared": 0,
        "rebuilt_public_tables": [],
        "captured_public_tables": [],
        "public_table_structure_detail": [],
        "what_a_captured_table_does_not_establish": None,
        "bilinear_group_factor": {
            "definition_in_force": None,
            "definition_selected_by": None,
            "superseded": None,
            "slots_with_a_derived_group_point": 0,
            "failures": [],
            "refusals": [],
            "ok": False,
        },
    }
    if not out["source_pins"]["ok"]:
        out["findings"].append(
            "the bundle's source pins are not the ones this port was read at: "
            + "; ".join(out["source_pins"]["pins_that_moved"]
                        + out["source_pins"]["pins_missing_from_the_bundle"])
        )
        out["refused_before_any_slot_was_evaluated"] = (
            "a moved or missing source pin: NO slot of any stage was checked, "
            "and the zeros above are the absence of a check, not a passing "
            "one.  Nothing here says the bundle is bad -- it says this port "
            "has not read the Rust that made it"
        )
        out["ok"] = False
        return out

    docs = stage_docs if stage_docs is not None else [st.doc for st in bundle.stages]
    planes = slot_planes if slot_planes is not None else [
        [p.name for p in row] for row in index.slot_planes
    ]
    # [round 4] the bilinear slots' group factor, derived here unless the
    # caller already derived it
    if group is None:
        group = GroupFactors(bundle, replay=replay, stage_docs=docs,
                             definition=force_definition)
    gs = group.summary()
    out["bilinear_group_factor"] = {
        "definition_in_force": gs["definition_in_force"],
        "definition_selected_by": gs["definition_selected_by"],
        "superseded": gs["superseded"],
        "slots_with_a_derived_group_point": gs["slots_with_a_derived_group_point"],
        "failures": gs["failures"],
        "refusals": gs["refusals"],
        "ok": gs["ok"],
    }
    for st in bundle.stages:
        doc = docs[st.index]
        gate.set_logup(doc["logup_challenges"])
        lam_z = lam_z_of(doc)
        row = {"stage": st.index, "checked": [], "equal": [], "not_checked": []}
        for s, nm, fn, _reason in PORTS:
            arg = doc["arguments"][s]
            if s not in covered:
                row["not_checked"].append({"slot": s, "name": nm, "why": "OPEN"})
                continue
            try:
                dc = [f2_from_list(x) for x in arg["definition_challenges"]]
                cx = SlotCtx(gate, arg, planes[s], dc, lam_z, structural=structural)
                cx.bilinear_definition = group.definition
                cx.group_table_required = group.group_table_required()
                if s in BILINEAR_SLOTS:
                    pt = group.point(st.index, s)
                    if pt is not None:
                        if not cx.eq_idx:
                            raise ValueError(
                                f"slot {s}: a group point was derived and the bundle "
                                "declares no eq table to compare it with"
                            )
                        cx.derived_eq_points = {cx.eq_idx[0]: pt}
                if replay is not None:
                    cx.rho_full = replay.stages[st.index]["rho"][s]
                    c = replay.stages[st.index]["slot_c"][s]
                else:
                    cx.rho_full = [f2_from_list(x) for x in arg["rho"]]
                    c = f2_from_list(arg["c"])
                gate.build_public(cx, check_digests=check_digests)
                poly = fn(gate.vals(cx), cx)
                out["derived_group_points_used_and_compared"] = (
                    out.get("derived_group_points_used_and_compared", 0)
                    + cx.eq_points_compared
                )
            except (ValueError, IndexError, KeyError) as exc:
                row["not_checked"].append({"slot": s, "name": nm, "why": str(exc)})
                out["findings"].append(f"stage {st.index} slot {s} [{nm}]: {exc}")
                continue
            out["slot_checks_attempted"] += 1
            row["checked"].append(s)
            claimed = f2_from_list(arg["scalar"])
            for h in arg["hosted"]:
                claimed = add(claimed,
                              mul(f2_from_list(h["coefficient"]),
                                  f2_from_list(doc["arguments"][h["slot"]]["scalar"])))
            fin, _consistent = sumcheck_final(arg["rounds"], arg["degree"],
                                              cx.rho_full, claimed)
            mask_eval = f2_from_list(arg["mask_eval"])
            if fin is not None and fin == add(mul(c, mask_eval), poly):
                out["slot_checks_equal"] += 1
                row["equal"].append(s)
            else:
                out["findings"].append(
                    f"stage {st.index} slot {s} [{nm}]: "
                    "fin != c*mask_eval + poly(terminals)"
                )
            if poly == f2_from_list(arg["terminal_polynomial"]):
                out["slot_checks_matching_the_stored_terminal_polynomial"] += 1
            else:
                out["findings"].append(
                    f"stage {st.index} slot {s} [{nm}]: the recomputed polynomial is "
                    "not the capture's terminal_polynomial"
                )
        out["per_stage"].append(row)
    out["public_tables_rebuilt_and_digest_matched"] = len(gate.public_tables)
    out["public_table_digest_failures"] = gate.public_digest_failures
    out["rebuilt_public_tables"] = sorted(set(gate.public_tables.values()))
    out["public_tables_taken_from_the_capture"] = len(gate.captured_tables)
    out["captured_public_tables"] = sorted(set(gate.captured_tables.values()))
    out["public_table_structure_checks"] = gate.structure_checks
    out["public_table_structure_failures"] = gate.public_structure_failures
    out["public_table_structure_detail"] = gate.structure_detail
    out["what_a_captured_table_does_not_establish"] = (
        "that a folded weight table is the fold of the weight matrix the "
        "statement names.  No bundle carries a weight, so the port checks the "
        "capture's own length and SHA-256, the structure ruling P-2 gives the "
        "fold, and the identity at the run's real challenges -- and no more.  "
        "The tables that ARE functions of the shape are rebuilt here instead "
        "and never taken"
    )
    want = len(covered) * bundle.blocks
    out["slot_checks_expected"] = want
    out["slots_open_per_stage"] = bundle.shape.n_slots - len(covered)
    out.setdefault("derived_group_points_used_and_compared", 0)
    out["ok"] = (
        not out["findings"]
        and not gate.public_digest_failures
        and not gate.public_structure_failures
        and out["slot_checks_attempted"] == want
        and out["slot_checks_equal"] == want
        and out["slot_checks_matching_the_stored_terminal_polynomial"] == want
        and out["bilinear_group_factor"]["ok"]
    )
    return out


def verify_captured_public_tables(bundle) -> dict:
    """**Every public table the bundle carries, against the capture's own
    `len` and `sha256`** -- all 23 slots of all L stages, independently of
    whether any port reads them.

    The digest is over the concatenated 16-byte little-endian `Fp2`
    encodings of exactly those values (`run_capture.rs:788`), so this is the
    check the format document says a reader can make offline.  It is a
    SELF-CONSISTENCY check of the capture: it catches a truncated or
    corrupted table, not a capture that lies about its own statement.
    """
    out = {
        "what": "each carried public table's values against the capture's own len "
        "and SHA-256 (the 16-byte little-endian Fp2 encoding, run_capture.rs:788)",
        "bundle": bundle.name,
        "public_tables_included": bool(getattr(bundle, "public_tables_included", False)),
        "public_tables": 0,
        "with_values": 0,
        "length_checked": 0,
        "digest_checked": 0,
        "per_stage": [],
        "findings": [],
    }
    for st in bundle.stages:
        n, wv, ln, dg = 0, 0, 0, 0
        for arg in st.doc["arguments"]:
            for i, tab in enumerate(arg["tables"]):
                if tab["kind"] != "public":
                    continue
                n += 1
                vals = tab.get("values")
                if vals is None:
                    continue
                wv += 1
                if len(vals) == tab["len"]:
                    ln += 1
                else:
                    out["findings"].append(
                        f"stage {st.index} slot {arg['slot']} table {i}: "
                        f"{len(vals)} values for a declared len of {tab['len']}"
                    )
                    continue
                if table_digest([f2_from_list(x) for x in vals]) == tab["sha256"]:
                    dg += 1
                else:
                    out["findings"].append(
                        f"stage {st.index} slot {arg['slot']} table {i}: the values "
                        "do not hash to the capture's own sha256"
                    )
        out["per_stage"].append(
            {"stage": st.index, "public_tables": n, "with_values": wv,
             "length_checked": ln, "digest_checked": dg}
        )
        out["public_tables"] += n
        out["with_values"] += wv
        out["length_checked"] += ln
        out["digest_checked"] += dg
    out["ok"] = (
        not out["findings"]
        and (out["with_values"] == out["public_tables"]
             if out["public_tables_included"] else out["with_values"] == 0)
    )
    return out
