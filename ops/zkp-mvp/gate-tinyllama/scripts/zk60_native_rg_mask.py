#!/usr/bin/env python3
"""**The masking commitment `M` and the masked-sumcheck (CFS) channel at the
SHAPED layouts** — the largest channel round 7 of the run gate left open.

WHAT THE RUN GATE SAID, AND WHY.  Channel 7 of the run gate's table ("the
masked sumcheck round messages and the published scalars") has carried the
same reason since round 1:

    the CFS analysis (`zk60_native_jv_cfs`) and the mask-row port
    (`zk60_native_mask_commit`) are written at the toy's row layout and slot
    specs; at the rung they would have to be re-derived from the shape.

**That reason is PARTLY WRONG, and round 8's first result is saying so
exactly.**  `MaskModel`, `MaskPreimage`, `disclosed_dimension` and
`CfsPreimage` read `mask["specs"]` and `len(specs)` from the capture: they
are already driven by the slot table, whatever it says, and the row count
`2S + 4` is derived, not written down.  What IS layout-specific in the toy
port is five other things, named in `LAYOUT_SPECIFIC` below and each dealt
with here: the Rust pins, the capture and replay TYPES, the three domain
constants taken from the toy's `zk.rs` rather than from the bundle, the
absence of any cross-check against a SHAPE (the toy has none to check
against), and the absence of a Merkle layer.  A port that had re-derived the
solver would have been a second solver; this module keeps the toy's and
supplies the five.

WHAT IS PORTED, AND FROM WHERE.  Nothing arithmetic is re-implemented.
`DERIVED_FROM` names, class by class and method by method, the toy object
each figure comes from; `NEW_HERE` names everything this module adds, so the
two maps together are a complete account of it.  `IMPORTED_OBJECTS` is the
list a test walks to assert that each name here IS the toy module's object
and that this file defines no function or class of those names.

THE `M` SYSTEM AT A SHAPED LAYOUT (`hashline/src/zk.rs::mask_commit`, and
`private_block/layout.rs::M_ROWS = 2 * N_SLOTS + 4`):

    rows 0 .. 2S-1   two a-rows per slot (re, im).  Row `2s+k` holds, in
                     VALUE form over `G_512`, the message
                         [ L_s mask coefficients | Q pads | zeros ]
                     with `L_s = CfsMask::len(n_s, d_s) = n_s d_s + 2` and
                     `(n_s, d_s) = (main_s + ext_s, degree_s)` READ FROM THE
                     SHAPE (`shape.rs::Shape::slots`).
    rows 2S, 2S+1    `b_re`, `b_im`: `2·512` coefficients each, one linear
                     constraint `b[512] = -b[0]`.
    rows 2S+2, 2S+3  `u_re`, `u_im`: `2·512` free coefficients each.

`S = 23` and so `M` has **50 rows at every shape of this schedule**: the row
count is a constant of the block's slot table, not of the rung.  What the
rung moves is every `L_s`, because the shape moves `main_s`, `ext_s` and (at
`lkv > 0`) the two bilinear slots' `degree_s`.

THE CHANNELS THIS CLOSES, and the one thing each of them really tests:

  1 `M`'s opening discloses exactly its batched value `V(a)` and nothing
    else — computed as an exact `Fp` rank over the coefficient unknowns,
    then exhibited as a PREIMAGE and as a REFUSAL one off the `V` plane.
  2 every slot's published masked round messages and mask-bearing scalar are
    reproduced from mask coefficients that are CONSISTENT with `M`'s view —
    one coefficient vector for both, which is new here (the toy gate solves
    the two sides separately and never joins them).
  3 the opened columns of `M`, rebuilt from the preimage, re-hashed under
    the bundle's own derived rule and re-authenticated against the PUBLISHED
    salts and paths — also new here: the toy port does not hash.
  4 the pad budget: `Q` pads per a-row against `D` distinct opened columns,
    and `L_s + Q <= 512` at every slot of every shape.

WHAT THE FIXED DATA IS, AND WHAT IT IS NOT.  For the commitment side round 7
fixes the data block to ZERO, which is a public object.  For THIS channel
the hidden data is the slots' *honest, unmasked* round messages and honest
scalars, and **no capture carries them** — the security owner has refused
publishing them for a real slot, and `ZK60_PRIVACY_CASE_FIRST_MVP.md` §4.3
asks for them only as a labelled synthetic test fixture.  They are not
recoverable from the bundle either: the honest round polynomials of the
all-zero WITNESS are a deterministic function of the public weights and the
challenges, but evaluating them means running each slot's composition over
its whole `2^(main+ext)` cube through the prover's table machinery, which
this gate does not have and which the capture does not carry.  So the gate
does what the toy gate does: it FIXES a named, public, deterministic element
of the channel's data space — `CfsPreimage.flat_transcript`, the flat
honest transcript whose claimed sum is what the hosted slots' published
scalars force — projects it onto the identities the `M` opening pins, and
SOLVES for the mask coefficients.  **Fixed**: that transcript.  **Solved**:
the `L_s` mask coefficients of every slot, the `Q` pads of every a-row, the
two `b` rows and the two `u` rows.  It is a statement about the view map,
not about the zero witness's own transcript.

NOTHING HERE ESTABLISHES A PRIVACY PROPERTY AND NOTHING HERE IS A PRIVACY
ACCEPTANCE.
"""

from __future__ import annotations

import hashlib
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

from zk60_native_jv_field import (  # noqa: E402
    F2_ZERO,
    P,
    f2_add,
    f2_from_list,
    f2_is_zero,
    f2_mul,
    rank,
)
from zk60_native_mask_commit import (  # noqa: E402  -- imported, never re-implemented
    MASK_LOG_DOM,
    MASK_LOG_MSG,
    MASK_Q,
    MSG_N,
    MaskModel,
    MaskPreimage,
    combined_weights,
    declared_functional_order,
    disclosed_dimension,
    force_functional,
    mask_len,
    single_functional_weights,
    synthetic_coefficients,
)
from zk60_native_pg_cfs import CfsPreimage  # noqa: E402
from zk60_native_rg_hashlayer import column_bytes  # noqa: E402

__all__ = [
    "DERIVED_FROM",
    "IMPORTED_OBJECTS",
    "LAYOUT_SPECIFIC",
    "MASK_LAYER_PINS",
    "NEW_HERE",
    "NOT_PINNABLE_FROM_A_BUNDLE",
    "StageReplay",
    "check_mask_layer_pins",
    "mask_cfs_run",
    "mask_cfs_stage",
    "shaped_mask_model",
    "slot_row_map",
    "toy_equivalence",
]


# --------------------------------------------------------------------------
# 0.  WHAT IS LAYOUT-SPECIFIC IN THE TOY PORT
# --------------------------------------------------------------------------
# Established 2026-09-21 by reading `zk60_native_mask_commit` and
# `zk60_native_pg_cfs` line by line against the four run bundles and against
# the Rust at their pinned commits.  Each entry says what the toy does, why
# it cannot be used at a run bundle as written, and what this module supplies
# instead.  A test requires every key to be one of the five.
LAYOUT_SPECIFIC = {
    "the Rust pins": (
        "`zk60_native_mask_commit.SOURCE_PINS` and `PATH_PINS` are read at "
        "the TOY lane's commits.  Five of the files the mask port transcribes "
        "moved by the run bundles' capture commits -- `zk.rs`, `pcs.rs`, "
        "`merkle.rs`, `transcript.rs`, `argument.rs` -- so `check_source_pins` "
        "refuses at a run bundle.  Supplied: `MASK_LAYER_PINS` and "
        "`NOT_PINNABLE_FROM_A_BUNDLE`, with the reading of every moved digest"
    ),
    "the capture and replay types": (
        "the toy takes `zk60_native_jv_capture.Capture` and "
        "`zk60_native_jv_replay.Replay`, one proof each, with `theta`, "
        "`slot_c` and `rho` as attributes.  A run bundle has L STAGES and its "
        "replay keeps the three per stage in `RunReplay.stages[k]`.  "
        "Supplied: `StageReplay`, three lines, and the run `Stage` object "
        "used directly as the capture (it already exposes `mask`, `slots` and "
        "`doc`)"
    ),
    "the three domain constants": (
        "`MASK_LOG_MSG = 9`, `MASK_LOG_DOM = 12` and `MASK_Q = 256` are "
        "module constants of the toy port, transcribed from `zk.rs:373-375`.  "
        "A run bundle DECLARES its own mask domain in "
        "`run.json[\"mask_domain\"]` and its own `q` length, and a gate that "
        "assumed the toy's would be silently wrong at a shape that moved "
        "them.  Supplied: `derive_mask_domain`, which reads the domain from "
        "the bundle and REFUSES BY NAME when it differs from the pinned "
        "constants"
    ),
    "the cross-check against a shape": (
        "the toy reads `mask[\"specs\"]` from the capture and has nothing to "
        "check it against: the toy profile's slot table is a module-level "
        "constant of the Rust (`argument.rs::SLOTS`) that no capture carries. "
        " A run bundle carries `run.json[\"shape\"][\"slots\"]`, the "
        "`(main, ext, degree)` triples `Shape::slots` returns, and "
        "`argument.rs::sum_weights(&sh, s)` is `CfsMask::sum_weights(main + "
        "ext, degree)`.  Supplied: `check_specs_against_shape`, which "
        "re-derives every spec from the shape and compares"
    ),
    "the Merkle layer": (
        "the toy port does not hash: `M`'s root, its 256 leaf salts and its "
        "12-level paths stay where the toy gate puts them.  A run bundle "
        "carries all three and the loader DERIVES the hash rule from the "
        "profile.  Supplied: `_hash_layer`, the rebuilt columns re-hashed and "
        "re-authenticated -- the same arm round 7 added for the PCS side"
    ),
}

# Every arithmetic object this module uses that belongs to a hash-pinned toy
# record.  A test asserts each name resolves to that module's own object and
# that this file defines no `def`/`class` of the same name.
IMPORTED_OBJECTS = {
    "zk60_native_mask_commit": (
        "MaskModel", "MaskPreimage", "combined_weights",
        "declared_functional_order", "disclosed_dimension", "force_functional",
        "mask_len", "single_functional_weights", "synthetic_coefficients",
        "MASK_LOG_MSG", "MASK_LOG_DOM", "MASK_Q", "MSG_N",
    ),
    "zk60_native_pg_cfs": ("CfsPreimage",),
    "zk60_native_rg_hashlayer": ("column_bytes",),
}

DERIVED_FROM = {
    "mask_cfs_stage/the M model": (
        "zk60_native_privacy_gate.mask_stage -- the same `MaskModel`, the same "
        "`shape()`, `declared_functional_order`, `disclosed_dimension`, two "
        "seeded coefficient vectors on the V plane and the off-plane refusal; "
        "what differs is that the capture is one STAGE of a run and that a "
        "third coefficient vector, the CFS-solved one, is exhibited beside "
        "the two seeded ones"
    ),
    "mask_cfs_stage/the CFS solve": (
        "zk60_native_privacy_gate's CFS stage -- the same `CfsPreimage`, the "
        "same flat fixed transcript, the same two accountings ('all' and "
        "'theta') and the same `verify`, `functional_values` and "
        "`fibre_dimension`; what differs is the capture and that the solved "
        "coefficients are then FED to the M preimage"
    ),
    "mask_cfs_stage/the pad budget": (
        "zk60_native_mask_commit.MaskModel.shape -- `pad_margin`, "
        "`coefficients_plus_pads_fit`, `nodes_distinct`, `nodes_off_G512` and "
        "`weights_vanish_above_L`, unchanged; this module only records them "
        "per stage and per shape and refuses on any of them"
    ),
    "toy_equivalence": (
        "zk60_native_privacy_gate.mask_stage again -- the SAME entry point "
        "run on a TOY capture through this module's own driver, so that its "
        "figures can be compared with the toy gate's committed record"
    ),
}

NEW_HERE = {
    "StageReplay": "three attributes of one stage of a run replay, so that "
    "the toy's `(capture, replay)` signature takes a run stage",
    "derive_mask_domain": "the mask domain READ from the bundle "
    "(`run.json[\"mask_domain\"]`, `len(mask[\"q\"])`, `mask[\"rows\"]`) and "
    "compared with the pinned Rust constants, refusing by name on a "
    "difference",
    "check_specs_against_shape": "every `(n_s, d_s)` re-derived from "
    "`shape[\"slots\"]` as `(main + ext, degree)` and compared with the "
    "capture's own `mask[\"specs\"]`",
    "shaped_mask_model": "the toy's `MaskModel` built on one stage of a run "
    "through `StageReplay`; the class is the toy's, the inputs are shaped",
    "slot_row_map": "the slot -> rows/offset map of M at this shape: which "
    "two rows carry a slot's coefficients, how many of the 512 message "
    "positions each occupies, and where its pads start",
    "check_mask_layer_pins": "the mask layer's own pin table, checked "
    "bundle-side against `manifest.json[\"source_pins\"]`, with the files no "
    "bundle pins named rather than merely absent",
    "_hash_layer": "the rebuilt columns of M re-hashed under the bundle's own "
    "rule and their salted leaves re-authenticated against the PUBLISHED "
    "salts and paths.  The toy port has no Merkle layer",
    "joined_coefficients": "THE JOIN: the coefficient vector the CFS side "
    "solved, fed to the M preimage, so that one vector reproduces both the "
    "23 slots' masked rounds and scalars AND M's whole published opening.  "
    "The toy gate solves the two sides separately and never joins them",
    "mask_cfs_stage": "one stage of a run, end to end",
    "mask_cfs_run": "every stage of a bundle, with the totals",
    "toy_equivalence": "the driver run at the toy's widths on a tracked toy "
    "capture, its figures compared with the toy gate's own",
}


# --------------------------------------------------------------------------
# 1.  THE MASK LAYER'S OWN PINS
# --------------------------------------------------------------------------
# The discipline is round 6's (`zk60_native_rg_runpins`): a digest is in a
# table below only because the file was READ at that commit against the port
# that depends on it, and the mechanism is BUNDLE-SIDE -- this gate never
# reads the Rust lane's tree, so a file can be CHECKED here only if the
# capture writer pins it.
#
# path -> sha256 -> (git blob, the capture commits, the bundles, the reading)
MASK_LAYER_PINS = {
    "src/private_block/argument.rs": {
        "dd8469cb0279281e1ea7fcc92c0d14ec23a29b8f6bed8a28b10b704bd15ff08f": {
            "commits": ("0426ad258cd5d1f77cd62760f29ae186dc43e624",
                        "3247a89762248cfb43f9fdd9cd9147251d69d1df",
                        # [ROUND 9] byte-identical at the 125M capture
                        # commit: `git diff --numstat 3247a89 f4697f9`
                        # does not list argument.rs at all.
                        "f4697f9ccad82304c56dee8c53da3bf107d98b1e"),
            "bundles": ("run-g-dense-s20", "run-h-zero-s20",
                        "run-i-dense-k4", "run-j-zero-k4",
                        "m125-capture-dense-l2", "m125-capture-zero-l2"),
            "reading": "the DECLARED functional order.  READ 2026-09-21 "
            "against the toy port's pinned bytes "
            "(e62f46c2..., `zk60_native_mask_commit.SOURCE_PINS`): "
            "`run_slot`'s M-functional block and `argument`'s "
            "`acc.fs.extend(hosts)` are IDENTICAL except that "
            "`sum_weights(s)` became `sum_weights(&sh, s)`, and "
            "`fn sum_weights(sh, slot)` is `CfsMask::sum_weights(n + e, d)` "
            "over `sh.slots()[slot]` where the toy read the module-level "
            "`SLOTS[slot]`.  Same function of the same triple, taken from the "
            "shape instead of a constant -- which is exactly what "
            "`check_specs_against_shape` checks here.  The guard "
            "`acc.fs.len() != N_FUNCTIONALS` is unchanged",
        },
        "909670c96562e7ff99b7ad37f6c3aae027574f3c0e9ab74f01a27e45058bf675": {
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged"),
            "reading": "the same block, BEFORE stage 20's repair of finding "
            "S19-F1.  Accepted here only so that the six superseded bundles "
            "do not read as a pin failure; no figure of round 8 is taken at "
            "them",
        },
        # [ROUND 9b] the rung-P2 capture commit.
        "ec3f97443245f119dd8adc0739a5df17588dc15bb3730382310a95fb7d2a9f9d": {
            "commits": ("4ccbad1b1da0a23449ac06461740750a6818c6e8",),
            "bundles": ("run-k-dense-p2", "run-l-zero-p2"),
            "reading": "READ 2026-09-21 (round 9b).  `git diff f4697f9 "
            "4ccbad1 -- .../argument.rs` is 230 added, 48 removed, five "
            "hunks, all of them stage 28's and stage 29's table-build speed "
            "work -- `priv_table`'s bit-permutation maps, `eq_cube`, "
            "`table_of_taking`, `build_tables_at`, the chunked claimed sum, "
            "`timing::slot_step` and the env-gated base-field census.  "
            "**The block this port reads is untouched**: `run_slot`'s "
            "M-functional block, `acc.fs.extend(hosts)`, "
            "`fn sum_weights(sh, slot)` and the guard "
            "`acc.fs.len() != N_FUNCTIONALS` are byte-identical, so the "
            "DECLARED functional order is the one round 8 read",
        },
        # [ROUND 9i] the rung-K8 capture commit.
        "f7fa2ad4213d925b2d8dcb8d8273b92c6af2e9f90f94978da8630cc123fcef3d": {
            "commits": ("99a8de832a6322c94bf951f0f443b96e1dc63cb8",),
            "bundles": ("run-s-dense-k8", "run-t-zero-k8"),
            "reading": "READ 2026-09-22 (round 9i).  `git diff 6d71b40 "
            "99a8de8 -- .../argument.rs` is 137 added, 18 removed, four "
            "hunks, all of them stage 35's rewrite of two closure bodies "
            "inside `define` -- slot 14 (`SC_DZC`) and slot 17 (`SC_SZC`): "
            "base-field constants through `mul_base`, the `256^0` weight "
            "dropped, one shared sub-product, the support gate hoisted, and "
            "`#[cfg(test)]` differential blocks.  **The block this port "
            "reads is untouched**: `run_slot` (argument.rs:444), "
            "`fn sum_weights(sh, slot)` (:433), `acc.fs.extend(hosts)` and "
            "the guard `acc.fs.len() != N_FUNCTIONALS` (:1877-1878) are "
            "outside every hunk and byte-identical, so the DECLARED "
            "functional order is the one round 8 read",
        },
        # [ROUND 9j] lane stage 45's STANDALONE block bundles.
        "2cee0a2253d6ef91bea23f564d8e24a3362663da53a10182d6b0edaa8a10a013": {
            "commits": ("feae674dbd5c5a3e7646da9e33bc423e76b8ab32",
                        "19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c"),
            "bundles": ("rung-g-dense", "rung-g-zero", "m125-dense", "m125-zero"),
            "reading": "READ 2026-09-23 (round 9j).  `git diff 99a8de8 "
            "feae674 -- .../argument.rs` is 6 added, 0 removed, three hunks, "
            "every added line `#[cfg(test)]`, a comment or a "
            "`block_capture_shaped::` hook (stage 45).  **The block this port "
            "reads is untouched**: `run_slot`'s M-functional block, "
            "`fn sum_weights(sh, slot)`, `acc.fs.extend(hosts)` and the guard "
            "`acc.fs.len() != N_FUNCTIONALS` are outside every hunk and "
            "byte-identical, so the DECLARED functional order is the one "
            "round 8 read",
        },
    },
    "src/private_block/layout.rs": {
        "b765bdcbe5762cce3402dac9fb44b5359d53cb492f67c62dbee18f3b559b0d05": {
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",
                        "0426ad258cd5d1f77cd62760f29ae186dc43e624",
                        "3247a89762248cfb43f9fdd9cd9147251d69d1df"),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged",
                        "run-g-dense-s20", "run-h-zero-s20",
                        "run-i-dense-k4", "run-j-zero-k4"),
            "reading": "READ 2026-09-21 for the three constants this port's "
            "row model rests on: `N_SLOTS = 23` (:763), "
            "`N_FUNCTIONALS = 34` (:895) and `M_ROWS = 2 * N_SLOTS + 4` "
            "(:896), with the assertions `M_ROWS == 50` (:1284) and "
            "`N_SLOTS + #Standalone + HOSTS.len() == N_FUNCTIONALS` (:1290).  "
            "None of the three is a function of the shape, which is why M has "
            "fifty rows and thirty-four functionals at BOTH rungs",
        },
        # [ROUND 9] the 125M capture commit.
        "14758039fbe9daa61affa1316c6e4159437b98d888d72a926f6e70e788592b30": {
            "commits": ("f4697f9ccad82304c56dee8c53da3bf107d98b1e",),
            "bundles": ("m125-capture-dense-l2", "m125-capture-zero-l2"),
            "reading": "READ 2026-09-21.  `git diff 3247a89 f4697f9 -- "
            ".../layout.rs` is 34 added lines, 0 removed, ONE hunk, and "
            "every added line is a `///` doc comment on `domain_log_at` "
            "(ruling S-1's invariant).  **Not one byte of code moved**, so "
            "`N_SLOTS = 23`, `N_FUNCTIONALS = 34` and "
            "`M_ROWS = 2 * N_SLOTS + 4` are the same constants this port's "
            "row model rests on -- which is why M has fifty rows and "
            "thirty-four functionals at the 125M shape too",
        },
        # [ROUND 9j] lane stage 45's STANDALONE block bundles.
        "64c37a4956ed221cb549d8e88257a14f5f332bb549fc4028c9a38246b111f23c": {
            "commits": ("feae674dbd5c5a3e7646da9e33bc423e76b8ab32",
                        "19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c"),
            "bundles": ("rung-g-dense", "rung-g-zero", "m125-dense", "m125-zero"),
            "reading": "READ 2026-09-23 (round 9j).  `git diff 99a8de8 "
            "feae674 -- .../layout.rs` is 45 added, 1 removed, two hunks: a "
            "doc-comment figure corrected (the one removed line) and "
            "`Layout::check_is_for_shape` (ruling CS-8), a refusal.  "
            "`N_SLOTS = 23`, `N_FUNCTIONALS = 34`, `M_ROWS = 2 * N_SLOTS + 4` "
            "and their two assertions are outside both hunks, so M has fifty "
            "rows and thirty-four functionals in a standalone block too",
        },
    },
    "src/private_block/shape.rs": {
        "8f7344221ad7a783caaadfa768611fb927ac6320d5b02c1e6adeb658c7900a2a": {
            "commits": ("0426ad258cd5d1f77cd62760f29ae186dc43e624",),
            "bundles": ("run-g-dense-s20", "run-h-zero-s20"),
            "reading": "READ 2026-09-21 for `Shape::slots` (:634-684), the "
            "source of every `(n_s, d_s)`: `main` is the slot's cube log or "
            "its inner log, `ext` is 2 for the two BILINEAR slots "
            "(`SC_SCORE`, `SC_PV`) and 1 otherwise, and `degree` is "
            "`BASE_DEGREE[s] + indicator + group_eq` with `group_eq` set only "
            "for those two slots and only when `lkv > 0`.  That is stage 20's "
            "repair of S19-F1 and it is why slots 08 and 09 are the two whose "
            "`L` moved",
        },
        "07a0547f06602bc27cbad1658a7cc0079f2ac1158d2bb372e24096e930e6a7fd": {
            "commits": ("3247a89762248cfb43f9fdd9cd9147251d69d1df",),
            "bundles": ("run-i-dense-k4", "run-j-zero-k4"),
            "reading": "the same `Shape::slots`, at the commit that added "
            "the rung-K4 profile.  READ 2026-09-21: the rung moves `d_pad`, "
            "`t_pad` and `f_pad` and so moves `main` on eight slots; the "
            "`ext` and `degree` rules are unchanged",
        },
        "9ac32109b176ffe10601b3412961204ac00c3a8feafd23226a9cc568f5104999": {
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged"),
            "reading": "the pre-stage-20 `Shape::slots`; accepted for the "
            "superseded bundles only, as for `argument.rs` above",
        },
        # [ROUND 9] the 125M capture commit.
        "14ea01ee5a68986da8d1647afa97638dbeb4fea48a96fe74c1e81fa19705636c": {
            "commits": ("f4697f9ccad82304c56dee8c53da3bf107d98b1e",),
            "bundles": ("m125-capture-dense-l2", "m125-capture-zero-l2"),
            "reading": "READ 2026-09-21.  `git diff 3247a89 f4697f9 -- "
            ".../shape.rs` is 123 added lines and 0 removed -- ADDITIONS "
            "ONLY.  `Shape::slots` (the source of every `(n_s, d_s)` this "
            "port turns into `L_s`) is byte-identical; what is new is "
            "`Shape::m125()` and three named refusals in `Shape::new`, one "
            "of which is DIRECTLY this port's own feasibility condition: "
            "ruling C-4 refuses any shape with `L_s + MASK_Q > MASK_MSG` "
            "for some slot, which is the assertion `zk.rs::mask_commit` "
            "makes, lifted to the shape.  So the 125M shape existing at all "
            "is the Rust's own statement that its masks fit, and "
            "`derive_mask_domain` here checks the domain the bundle "
            "declares rather than assuming it -- R8.9 item 5's question, "
            "answered by the file rather than by this port",
        },
        # [ROUND 9b] the rung-P2 capture commit.
        "502ba5caac76bdfd026c77761a7735ccc94cf56a157d8bd0dbfbde6c773dd04b": {
            "commits": ("4ccbad1b1da0a23449ac06461740750a6818c6e8",),
            "bundles": ("run-k-dense-p2", "run-l-zero-p2"),
            "reading": "READ 2026-09-21 (round 9b).  `git diff f4697f9 "
            "4ccbad1 -- .../shape.rs` is 63 added lines and 0 removed -- "
            "ADDITIONS ONLY, one hunk, `Shape::rung_p2()` and its doc "
            "comment.  `Shape::slots` -- the source of every `(n_s, d_s)` "
            "this port turns into `L_s` -- is byte-identical, and so is "
            "ruling C-4 in `Shape::new`.  What the NEW SHAPE does to this "
            "port is arithmetic and not code: slots 16 and 18 lose the "
            "pad-zero factor, so their degrees are 4 where rung-K4's are 5 "
            "and their `L_s` are shorter; `derive_mask_domain` reads the "
            "domain the bundle declares, as always",
        },
        # [ROUND 9c] stages 31, 32 and 33: rung-C6, rung-W14 and rung-E32.
        # One reading for the three, because the three diffs are the same
        # diff with one, two and three constructors in it.
        "3791ef61cd3c29356f3b71e8c271378ca8a31cd2bef7fb963d2e7ac8be7c8224": {
            "commits": ("3e106e192bc32701378ca3ce34bb0a8be8d2b7d5",),
            "bundles": ("run-m-dense-c6", "run-n-zero-c6"),
            "reading": "READ 2026-09-21 (round 9c).  `git diff 4ccbad1 "
            "3e106e1 -- .../shape.rs` is **75 added, 0 removed -- "
            "ADDITIONS ONLY**: `Shape::rung_c6()` and its doc comment.  "
            "`Shape::slots` -- the source of every `(n_s, d_s)` this port "
            "turns into `L_s` -- is byte-identical, and so is ruling C-4's "
            "refusal in `Shape::new`, which is this port's own feasibility "
            "condition.  What the new shape does to this port is "
            "arithmetic: correction C-6 drops two `Dom::D` helper planes, "
            "so slot 14's term list is shorter, and slots 16 and 18 keep "
            "rung-P2's unpadded degrees.  The prediction derives the "
            "largest `L_s` (77) and the C-4 headroom (179) before the run",
        },
        "b891869adb3d3df2564ba0f2524e8ec6dcbfa6a3c5a1139a39420b4f4e68c645": {
            "commits": ("11703c94df428c3e53dbc6c37eac835e348f5bf9",),
            "bundles": ("run-o-dense-w14", "run-p-zero-w14"),
            "reading": "READ 2026-09-21 (round 9c).  `git diff 4ccbad1 "
            "11703c9 -- .../shape.rs` is **154 added, 0 removed -- "
            "ADDITIONS ONLY**: `Shape::rung_c6()` and `Shape::rung_w14()` "
            "with their doc comments.  `Shape::slots` and ruling C-4 are "
            "byte-identical.  rung-W14 is the first shape this port sees "
            "at `log_cols = 14`: `MASK_MSG` and `MASK_Q` are constants of "
            "`zk.rs` and do not move with the row width, so the C-4 "
            "headroom TIGHTENS to 169 -- the largest `L_s` is 87 at slot "
            "14 because the domain logs are two larger -- and the "
            "prediction names both numbers before the run",
        },
        "dbf4e2bc36e9f74c432d6e529b229e3a593e794271fd8593d1412b8312403911": {
            "commits": ("6d71b405de9863a7a95dc166ba932f6e12e5a2d0",
                        "2d04d941f1e7e4e52b72f7d1434060779814405e",
                        "226f3b2c6aed44fe9b1f495cd7c7e34b900e4e90",
                        # [ROUND 9i] byte-identical at the rung-K8 capture
                        # commit: rung-K8 is built in a TEST file
                        # (`k8_tests.rs`) through the unchanged
                        # `Shape::new`, so `shape.rs` did not move.
                        "99a8de832a6322c94bf951f0f443b96e1dc63cb8"),
            "bundles": ("run-q-dense-e32", "run-r-zero-e32",
                        "run-s-dense-k8", "run-t-zero-k8"),
            "reading": "READ 2026-09-21 (round 9c).  `git diff 4ccbad1 "
            "6d71b40 -- .../shape.rs` is **273 added, 0 removed -- "
            "ADDITIONS ONLY**: the three constructors, ruling S-6's named "
            "construction refusal (a shape whose padded token count "
            "reaches the row width, which no registered shape is and no "
            "bundle here is near) and a doc comment on `a_groups`.  "
            "`Shape::slots` and ruling C-4 are byte-identical; `a_groups` "
            "itself is byte-identical.  The largest `L_s` is 82 and the "
            "C-4 headroom 174.  **The rung-E32 bundles NAME `4505ddf`, "
            "which does not carry this blob** -- finding E32-F1; the "
            "commits listed here are the ones that do",
        },
        # [ROUND 9j] lane stage 45's STANDALONE block bundles.
        "5acecd8e431ea37d6669ab097be4e64c1102cff6617bd09712f4a742c658328f": {
            "commits": ("feae674dbd5c5a3e7646da9e33bc423e76b8ab32",
                        "19f06bfde4a1e4fcb0f39acc19da1f6654d66f9c"),
            "bundles": ("rung-g-dense", "rung-g-zero", "m125-dense", "m125-zero"),
            "reading": "READ 2026-09-23 (round 9j).  `git diff 99a8de8 "
            "feae674 -- .../shape.rs` is 291 added, 10 removed: refusals "
            "(note C-6, rulings CS-2, CS-5, CS-8, CS-9), the block-profile "
            "registry, and `Shape::new` renamed `Shape::build` for the nine "
            "registered constructors.  `Shape::slots` -- the source of every "
            "`(n_s, d_s)` this port turns into `L_s` -- and ruling C-4's "
            "refusal are outside every hunk and byte-identical; the largest "
            "`L_s` and the C-4 headroom are derived by the prediction (72 / "
            "184 at rung-G, 117 / 139 at 125M) before the run",
        },
    },
}

# [TINYLLAMA PORT 2026-10-17] the trained bundles' argument.rs, layout.rs
# and shape.rs digests, each READ (`zk60_native_rg_tinyllama_pins`).
from zk60_native_rg_tinyllama_pins import (  # noqa: E402
    MASK_LAYER_PINS as _TL_MLP, merge_two_level as _tl_merge2)
_tl_merge2(MASK_LAYER_PINS, _TL_MLP, "MASK_LAYER_PINS")
# [TINYLLAMA PORT v5, round 4] the R5 tree's digests of the same three files
# (`zk60_native_rg_tinyllama_r5_pins`).
from zk60_native_rg_tinyllama_r5_pins import (  # noqa: E402
    MASK_LAYER_PINS as _R5_MLP)
_tl_merge2(MASK_LAYER_PINS, _R5_MLP, "MASK_LAYER_PINS")
# [TINYLLAMA PORT v6, round 5] the R5b tree's shape.rs
from zk60_native_rg_tinyllama_r5b_pins import (  # noqa: E402
    MASK_LAYER_PINS as _R5B_MLP)
_tl_merge2(MASK_LAYER_PINS, _R5B_MLP, "MASK_LAYER_PINS")
# [TINYLLAMA PORT v8, round 6 part (B)] the R7 tree's shape.rs
from zk60_native_rg_tinyllama_r7_pins import (  # noqa: E402
    MASK_LAYER_PINS as _R7_MLP)
_tl_merge2(MASK_LAYER_PINS, _R7_MLP, "MASK_LAYER_PINS")

# Files the mask port transcribes that NO bundle pins, so that nothing in
# this module can check them.  The digests were read at the capture commits
# on 2026-09-21 with `git show <commit>:<path>` in the read-only Rust lane,
# and the reading of each difference from the toy port's pin is recorded --
# because the port itself is checked against the TOY pin
# (`zk60_native_mask_commit.check_source_pins`), and a reader has to know
# whether the bytes the bundles were MADE by differ from the bytes the port
# was READ against.
NOT_PINNABLE_FROM_A_BUNDLE = {
    "hashline/src/zk.rs": {
        "toy_pin": "c5b54753d01d85f3469b8fbb873a36c7fcbc91faf15d16004f8cecff019c1310",
        "at_the_capture_commits": "d4280962af3a89b61b3af69f35650d21f79dc9f51600dcf130442e44a50f1849",
        "reading": "DIFFERENT, and the difference is PURELY ADDITIVE: 106 "
        "lines added, ONE line removed (a trailing blank).  The addition is "
        "three functions -- `mask_commit_tagged`, `mask_verify_tagged` and "
        "`pcs_hash_column_keyed` -- the D19 / T-1 keyed entry points.  Every "
        "function this port transcribes (`mask_commit`, "
        "`encode_coeffs_coset`, `combined_weights`, `weight_polys`, "
        "`poly_mul_512`, `mask_open`, `mask_verify`) and all three constants "
        "are byte-identical, and `mask_commit_tagged`'s body draws the "
        "generator in exactly `mask_commit`'s order and builds exactly "
        "`mask_commit`'s rows -- so the ROW MODEL this port implements is the "
        "same object under either rule.  Read 2026-09-21",
        "why_not_pinnable": "`run_capture.rs::SOURCE_FILES` pins eight "
        "`private_block` files and no `zkp-core` or `hashline` root file, so "
        "no bundle carries a digest for it",
    },
    "zkp-core/src/sumcheck.rs": {
        "toy_pin": "56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19",
        "at_the_capture_commits": "56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19",
        "reading": "UNCHANGED at all three capture commits: "
        "`CfsMask::len / sum_weights / eval_weights / round` are the bytes the "
        "toy port was read against",
        "why_not_pinnable": "as above",
    },
    "zkp-core/src/ntt.rs": {
        "toy_pin": "97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890",
        "at_the_capture_commits": "97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890",
        "reading": "UNCHANGED: the forward/inverse convention the whole port "
        "rests on",
        "why_not_pinnable": "as above",
    },
    "zkp-core/src/field.rs": {
        "toy_pin": "df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13",
        "at_the_capture_commits": "df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13",
        "reading": "UNCHANGED: P, the nonresidue 7, and the byte encodings",
        "why_not_pinnable": "as above",
    },
    # [ROUND 9i] `rng.rs` and `transcript.rs` below are NOT at these bytes at
    # the rung-K8 capture commit `99a8de8`: stage 36 added a gated read-only
    # accessor to each (`consumed_bytes` / `refills`, `squeezes`) and their
    # tests, ADDITIONS ONLY -- `next_u64`, `refill`, `fp`, `fp2`, `bytes32`,
    # `absorb`, `squeeze_bytes` and every `challenge_*` are byte-identical.
    # The reading and the two digests are in
    # `zk60_native_rg_runpins.SHARED_ALSO_READ`, where the bundle-side check
    # lives; the entries here keep the bytes round 8 read.
    "zkp-core/src/rng.rs": {
        "toy_pin": "0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb",
        "at_the_capture_commits": "0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb",
        "reading": "UNCHANGED: the DRAW ORDER of every pad, mask row and salt "
        "of M",
        "why_not_pinnable": "as above",
    },
    "zkp-core/src/pcs.rs": {
        "toy_pin": "2d9149564ff7f77482bcc314ad1949eef4e183d2a6c9b6b3f8ac7ac4cc72b24d",
        "at_the_capture_commits": "6b8d1bfa1a69293e0ea82df46a8b231d896043577e62ab3a837d3fbf743db81a",
        "reading": "DIFFERENT.  What this port takes from it is "
        "`coset_powers` and `hash_column` / `salt_leaf`; the keyed forms "
        "`hash_columns_keyed` and `salt_leaf_keyed` are what a tagged "
        "bundle's M uses, and they are transcribed by "
        "`zk60_native_rg_hashrule`, which IS checked against the rule the "
        "loader derives from the profile and against the bundle's own bytes "
        "(the cross-rule probe of round 3).  So the hash side is checked by "
        "computation rather than by this pin",
        "why_not_pinnable": "as above",
    },
    "zkp-core/src/merkle.rs": {
        "toy_pin": "77bc5f51e5f11f150bec0813a2a810dd77d3dff3d1d4963e43a8923d106e4f62",
        "at_the_capture_commits": "6e7817bd767a883985bfcd62b7a387d0c5f4c361010c4c5db37f5087d965744a",
        "reading": "DIFFERENT, for the keyed fold `build_keyed` / "
        "`verify_path_keyed`.  Same remark: the fold is checked by "
        "COMPUTATION here -- every one of M's 256 opened columns is rebuilt "
        "and re-authenticated against the published root",
        "why_not_pinnable": "as above",
    },
    "zkp-core/src/transcript.rs": {
        "toy_pin": "31ce3c9a72da3bd3d6dcc9203c9ed7a51963cde462b59a66186467b4cb733da8",
        "at_the_capture_commits": "cc9752d0ef9bcd6d7b20e94e611ff26748593a2ea1a4f55b63d8c221715f1967",
        "reading": "DIFFERENT, for the keyed transcript.  `theta`, the "
        "`2S+2` proximity coefficients and the 256 column indices of M are "
        "all RE-DERIVED by the run gate's stage 2 and compared with the "
        "capture, so this file is checked by computation too",
        "why_not_pinnable": "as above",
    },
}


def check_mask_layer_pins(bundle) -> dict:
    """The mask layer's pins, checked against the bundle's own manifest.

    A bundle naming a digest this table does not accept leaves the mask
    stage NOT CHECKED, by name -- never a crash, and never a zero that
    reads like a pass (round 5's finding K4-F1, one layer up).
    """
    declared = {
        p["file"]: p["sha256"] for p in bundle.manifest.get("source_pins", [])
    }
    out = {
        "what": "the Rust the mask port transcribes, pinned where the capture "
        "writer pins it and named where it does not",
        "bundle": bundle.name,
        "source_commit": bundle.manifest.get("source_commit"),
        "files_checked": sorted(MASK_LAYER_PINS),
        "checked": 0,
        "accepted": [],
        "refusals": [],
        "not_pinnable_from_a_bundle": sorted(NOT_PINNABLE_FROM_A_BUNDLE),
        "not_pinnable_count": len(NOT_PINNABLE_FROM_A_BUNDLE),
    }
    for path in sorted(MASK_LAYER_PINS):
        got = declared.get(path)
        if got is None:
            out["refusals"].append(
                f"{path}: the bundle's manifest does not pin it, so the mask "
                "port's dependence on it is unchecked"
            )
            continue
        out["checked"] += 1
        table = MASK_LAYER_PINS[path]
        if got not in table:
            out["refusals"].append(
                f"{path}: the bundle declares {got[:16]}…, which this table "
                "does not accept -- the file must be re-read before the mask "
                "stage means anything"
            )
            continue
        out["accepted"].append({"file": path, "sha256": got[:16] + "…"})
    out["ok"] = not out["refusals"]
    return out


# --------------------------------------------------------------------------
# 2.  THE SHAPE, DERIVED FROM THE BUNDLE
# --------------------------------------------------------------------------
def derive_mask_domain(bundle, stage) -> dict:
    """M's domain READ from the bundle, and compared with the pinned Rust.

    The toy port takes `MASK_LOG_MSG`, `MASK_LOG_DOM` and `MASK_Q` from
    `zk.rs:373-375` as module constants.  A bundle declares its own:
    `run.json["mask_domain"]` gives `log_dom` and the number of opened
    columns, `len(mask["q"]) == 2 * 512` gives the message width, and
    `mask["rows"]` gives `2S + 4`.  They agree here, and that agreement is
    CHECKED rather than assumed -- at a shape that moved any of the three the
    toy solver would be silently wrong, and this refuses instead.

    `MASK_Q` is one Rust constant used twice -- pads per a-row AND opened
    columns -- so `mask_domain["columns"]` is what fixes the pad count; the
    comment on `zk.rs:375` is the whole of that argument and it is quoted
    here rather than left implicit.
    """
    md = bundle.run["mask_domain"]
    m = stage.mask
    out = {
        "declared_by_the_bundle": {
            "log_dom": md["log_dom"],
            "columns": md["columns"],
            "q_len": len(m["q"]),
            "prox_len": len(m["prox"]),
            "rows": m["rows"],
        },
        "pinned_in_the_port": {
            "MASK_LOG_MSG": MASK_LOG_MSG,
            "MASK_LOG_DOM": MASK_LOG_DOM,
            "MASK_Q": MASK_Q,
            "MSG_N": MSG_N,
        },
        "msg_width_from_q": len(m["q"]) // 2,
        "refusals": [],
    }
    if md["log_dom"] != MASK_LOG_DOM:
        out["refusals"].append(
            f"mask domain: the bundle declares log_dom {md['log_dom']}, the "
            f"port is written at {MASK_LOG_DOM}"
        )
    if md["columns"] != MASK_Q:
        out["refusals"].append(
            f"mask domain: the bundle declares {md['columns']} opened columns, "
            f"the port is written at MASK_Q = {MASK_Q}"
        )
    if len(m["q"]) != 2 * MSG_N or len(m["prox"]) != 2 * MSG_N:
        out["refusals"].append(
            f"mask domain: q/prox are {len(m['q'])}/{len(m['prox'])} long, the "
            f"port is written at {2 * MSG_N}"
        )
    if m["rows"] != 2 * len(m["specs"]) + 4:
        out["refusals"].append(
            f"mask domain: {m['rows']} rows for {len(m['specs'])} slots "
            f"(layout.rs::M_ROWS = 2 * N_SLOTS + 4)"
        )
    out["ok"] = not out["refusals"]
    return out


def check_specs_against_shape(bundle, stage) -> dict:
    """Every `(n_s, d_s)` re-derived from the SHAPE and compared.

    `argument.rs::sum_weights(&sh, s)` is `CfsMask::sum_weights(n + e, d)`
    over `sh.slots()[s] = (main, ext, degree)`, so the spec the capture
    carries must be `(main + ext, degree)`.  The toy port has nothing to make
    this comparison with; a run bundle carries the shape.
    """
    triples = [tuple(t) for t in bundle.run["shape"]["slots"]]
    specs = [tuple(s) for s in stage.mask["specs"]]
    want = [(m + e, d) for (m, e, d) in triples]
    bad = [
        f"slot {s}: the capture says {specs[s]}, the shape gives {want[s]}"
        for s in range(min(len(specs), len(want)))
        if specs[s] != want[s]
    ]
    if len(specs) != len(want):
        bad.append(f"{len(specs)} specs for {len(want)} shape triples")
    return {
        "slots": len(want),
        "specs_from_the_shape": want,
        "mask_lengths": [mask_len(n, d) for n, d in want],
        "largest_mask_length": max(mask_len(n, d) for n, d in want),
        "bilinear_slots": [s for s, (_m, e, _d) in enumerate(triples) if e == 2],
        "bilinear_mask_lengths": {
            s: mask_len(*want[s]) for s, (_m, e, _d) in enumerate(triples) if e == 2
        },
        "failures": bad,
        "ok": not bad,
    }


def slot_row_map(model) -> list:
    """Which rows of M carry which slot's coefficients, and where the pads go.

    Row `2s+k` of M holds `[ L_s coefficients | Q pads | zeros ]` in value
    form over `G_512`: `k = 0` the real parts of slot `s`'s mask
    coefficients, `k = 1` the imaginary parts (`zk.rs:436-447`).  The pads
    of that row occupy message positions `L_s .. L_s + Q - 1`, which is
    where the Cauchy block of the pad solve lives.
    """
    out = []
    for s in range(model.S):
        L = model.L[s]
        out.append(
            {
                "slot": s,
                "spec": list(model.specs[s]),
                "L": L,
                "rows": [2 * s, 2 * s + 1],
                "rows_hold": ["re", "im"],
                "message_positions": [0, L - 1],
                "pad_positions": [L, L + MASK_Q - 1],
                "zeros_from": L + MASK_Q,
                "fits": L + MASK_Q <= MSG_N,
            }
        )
    out.append(
        {
            "slot": None,
            "rows": [2 * model.S, 2 * model.S + 1],
            "rows_hold": ["b_re", "b_im"],
            "coefficients": 2 * MSG_N,
            "constraint": "b[512] = -b[0] (zero sum over G_512)",
        }
    )
    out.append(
        {
            "slot": None,
            "rows": [2 * model.S + 2, 2 * model.S + 3],
            "rows_hold": ["u_re", "u_im"],
            "coefficients": 2 * MSG_N,
            "constraint": None,
        }
    )
    return out


class StageReplay:
    """The three challenges of ONE stage, in the shape the toy takes."""

    def __init__(self, acc: dict):
        self.rho = acc["rho"]
        self.slot_c = acc["slot_c"]
        self.theta = acc["theta"]


def shaped_mask_model(stage, replay_acc):
    """`MaskModel` at one stage of a run: the toy's object, shaped inputs."""
    return MaskModel(stage, StageReplay(replay_acc))


# --------------------------------------------------------------------------
# 3.  THE HASH LAYER (new here)
# --------------------------------------------------------------------------
def _hash_layer(model, preimage, rule, root, columns=None) -> dict:
    """M's rebuilt columns re-hashed and re-authenticated.

    Every opened column of the capture is rebuilt from the preimage, hashed
    under the bundle's own derived rule, salted with the PUBLISHED salt and
    folded along the PUBLISHED path.  Reaching the committed root means the
    construction reproduces the receipt's BYTES for M's opened columns, not
    only its field values.
    """
    if rule is None or root is None:
        return {
            "checked": False,
            "why": "no hash rule or root was supplied (the toy captures have "
            "no Merkle layer in this gate's model)",
        }
    cols = columns if columns is not None else model.m["columns"]
    enc = [model.encode_row(preimage.acoef[r]) for r in range(2 * model.S)]
    for c in (preimage.b[0], preimage.b[1], preimage.u[0], preimage.u[1]):
        enc.append(model.encode_row(c))
    out = {
        "checked": True,
        "rule": rule.name,
        "columns_rehashed": 0,
        "column_values_equal_to_the_capture_s": 0,
        "salted_leaves_authenticated": 0,
        "path_levels": None,
        "failures": [],
        "unopened_leaves": "NOT reproducible from any preimage: an unopened "
        "leaf is a salted digest of data nothing publishes.  Its hiding is "
        "M-2 / M-3 and stays ARGUED",
    }
    rootb = bytes(root)
    for c in cols:
        j = c["index"]
        vals = [enc[r][j] for r in range(model.n_base)]
        out["columns_rehashed"] += 1
        if vals == list(c["values"]):
            out["column_values_equal_to_the_capture_s"] += 1
        leaf = rule.column_digest(column_bytes(vals))
        salted = rule.salt_leaf(leaf, bytes(c["salt"]))
        if out["path_levels"] is None:
            out["path_levels"] = len(c["path"])
        if rule.verify_path(rootb, j, salted, [bytes(x) for x in c["path"]]):
            out["salted_leaves_authenticated"] += 1
        else:
            out["failures"].append(
                f"M: the column rebuilt at index {j} does not authenticate "
                "against the published salt and path"
            )
    out["ok"] = (
        not out["failures"]
        and out["salted_leaves_authenticated"] == out["columns_rehashed"]
        and out["column_values_equal_to_the_capture_s"] == out["columns_rehashed"]
    )
    return out


# --------------------------------------------------------------------------
# 4.  ONE STAGE, END TO END
# --------------------------------------------------------------------------
def joined_coefficients(stage, replay_acc, which="all"):
    """THE JOIN: coefficients that meet the slots' rounds AND M's batch.

    `CfsPreimage` solves, per slot, `c_s R_s coef_s = masked_s - honest_s`
    and `c_s <w_s, coef_s> = scalar_s - sigma_s` at the flat fixed
    transcript; `project` then moves the fixed transcript onto the
    functional identities the M opening pins.  The result is ONE coefficient
    vector per stage that both sides of the masking layer see.

    `which = "all"` is the conservative accounting -- all 34 published
    functional values, as if each derived mask evaluation were an
    independent observation.  `which = "theta"` requires only the
    combination M's opening really pins.  Both are reported; the run of
    record joins on "all", which is the stronger of the two.
    """
    cp = CfsPreimage(stage, StageReplay(replay_acc))
    got = cp.run(fixed="zero")
    if got is None:
        return cp, None, {"solved": False, "findings": list(cp.findings)}
    zero_residual_is_zero = f2_is_zero(cp.theta_residual())
    proj = cp.project(which=which)
    return cp, cp.coef, {
        "solved": True,
        "fixed_transcript": "the flat honest transcript whose claimed sum is "
        "what the hosted slots' published scalars force, projected onto the "
        "identities the M opening pins",
        "zero_transcript_is_infeasible": not zero_residual_is_zero,
        "projection": proj,
        "findings": list(cp.findings),
    }


def mask_cfs_stage(bundle, replay, k, columns="full", coefficients="cfs",
                   rule=None, hash_layer=True) -> dict:
    """Everything round 8 computes about one stage's masking layer."""
    t0 = time.time()
    stage = bundle.stages[k]
    acc = replay.stages[k]
    mm = shaped_mask_model(stage, acc)
    out = {
        "stage": k,
        "mask_domain": derive_mask_domain(bundle, stage),
        "specs_against_the_shape": check_specs_against_shape(bundle, stage),
        "shape": mm.shape(),
        "slot_row_map": slot_row_map(mm),
        "declared_order": declared_functional_order(stage, StageReplay(acc)),
        "disclosed": disclosed_dimension(mm),
        "model_failures": list(mm.failures),
    }
    # ---------------------------------------------------------- the join
    cp, coef, cfs = joined_coefficients(stage, acc, which="all")
    out["cfs"] = cfs
    if coef is not None:
        out["cfs"]["verification"] = cp.verify()
        out["cfs"]["functional_values"] = cp.functional_values()
        out["cfs"]["fibre"] = cp.fibre_dimension()
    # ------------------------------------------------ the M preimage
    if coefficients == "cfs":
        if coef is None:
            # A REFUSAL IS NEVER A CRASH (round 5's finding K4-F1).  Every
            # key a caller reads is present and zero-valued, and the record
            # says the zeros are the absence of a construction and not a
            # passing one.
            out["preimage"] = {
                "preimage_exhibited": False,
                "why": "the CFS side did not solve: " + "; ".join(
                    cfs.get("findings") or ["no reason recorded"]),
            }
            out["hash_layer"] = {"checked": False,
                                 "why": "there is no preimage to re-hash"}
            out["pad_budget"] = {"ok": False,
                                 "why": "not evaluated: the stage refused"}
            out["entries_recomputed"] = _entries(out)
            out["entries_recomputed"]["these_zeros_are_an_absence"] = (
                "no entry was recomputed, because nothing was constructed"
            )
            out["seconds"] = round(time.time() - t0, 2)
            out["ok"] = False
            return out
        coefs, corrected = coef, None
    else:
        coefs, corrected = force_functional(
            mm, synthetic_coefficients(mm, coefficients), mm.v
        )
    pre = MaskPreimage(mm, coefs).build()
    ver = pre.verify(columns=columns) if pre.ok else None
    out["preimage"] = {
        "coefficients": (
            "the CFS-solved coefficients of THIS stage: the same vector that "
            "reproduces all 23 slots' masked rounds and scalars"
            if coefficients == "cfs"
            else "public, seeded; corrected at one position onto the V plane"
        ),
        "corrected_at": corrected,
        "preimage_exhibited": bool(ver and ver["all_entries_equal"]),
        "exhibited_randomness_sha256": pre.blinding_digest() if pre.ok else None,
        "coefficient_digest_sha256": _coef_digest(coefs),
        "verification": ver,
        "no_preimage_reason": list(pre.failures),
    }
    # the off-plane refusal, the other side of the same statement
    off, _ = force_functional(
        mm, synthetic_coefficients(mm, "a3"), f2_add(mm.v, (1, 0))
    )
    po = MaskPreimage(mm, off).build()
    vo = po.verify(columns=4)
    out["off_the_V_plane_has_no_preimage"] = {
        "what": "a coefficient vector with V(a) one off the captured batch",
        "b_admissible": vo["b_admissible"],
        "q_sum_identity_holds": vo["q_sum_identity_holds"],
        "column_mismatches": vo["column_mismatches"],
        "preimage_exhibited": vo["all_entries_equal"],
        "why": "b's only constraint is its zero sum over G_512, which reads "
        "512 (q[0] + q[512]) = V(a); off that plane no b exists and the fibre "
        "is EMPTY.  The columns still match -- the pads absorb every "
        "coefficient vector -- so the disclosure is exactly this one Fp2",
    }
    # ------------------------------------------------- the hash layer
    if hash_layer and pre.ok:
        out["hash_layer"] = _hash_layer(
            mm, pre, rule if rule is not None else bundle.hash_rule,
            stage.mask["root"],
        )
    else:
        out["hash_layer"] = {"checked": False, "why": "no preimage to re-hash"}
    # ------------------------------------------------- the pad budget
    out["pad_budget"] = {
        "pads_per_a_row": MASK_Q,
        "sampled_columns": len(mm.idx),
        "distinct_columns": mm.D,
        "margin": MASK_Q - mm.D,
        "coefficients_plus_pads_fit": out["shape"]["coefficients_plus_pads_fit"],
        "largest_L_plus_Q": max(mm.L) + MASK_Q,
        "message_width": MSG_N,
        "why_it_matters": "the a-row's Cauchy block is square and nonsingular "
        "exactly when the pad count is at least the DISTINCT sampled node "
        "count; below it the row cannot meet the captured columns and the "
        "view has no preimage (control M-4)",
        "ok": MASK_Q >= mm.D and out["shape"]["coefficients_plus_pads_fit"],
    }
    ent = _entries(out)
    out["entries_recomputed"] = ent
    out["seconds"] = round(time.time() - t0, 2)
    out["ok"] = bool(
        out["mask_domain"]["ok"]
        and out["specs_against_the_shape"]["ok"]
        and out["shape"]["ok"]
        and out["declared_order"]["ok"]
        and out["disclosed"]["matches_prediction"]
        and out["preimage"]["preimage_exhibited"]
        and not out["off_the_V_plane_has_no_preimage"]["preimage_exhibited"]
        and out["pad_budget"]["ok"]
        and (not out["hash_layer"]["checked"] or out["hash_layer"]["ok"])
        and cfs.get("solved")
        and out["cfs"]["verification"]["all_entries_equal"]
        and out["cfs"]["functional_values"]["mismatches"] == 0
        and not out["model_failures"]
    )
    return out


def _coef_digest(coefs) -> str:
    h = hashlib.sha256()
    for row in coefs:
        for a, b in row:
            h.update(int(a).to_bytes(8, "little"))
            h.update(int(b).to_bytes(8, "little"))
    return h.hexdigest()


def _entries(rec: dict) -> dict:
    """Every entry this stage RECOMPUTED and compared, by kind.

    An Fp2 entry counts once, as in round 7's table.
    """
    v = (rec.get("preimage") or {}).get("verification") or {}
    cv = (rec.get("cfs") or {}).get("verification") or {}
    fv = (rec.get("cfs") or {}).get("functional_values") or {}
    hl = rec.get("hash_layer") or {}
    out = {
        "masked_round_entries": cv.get("round_entries", 0),
        "masked_scalars": cv.get("scalars", 0),
        "functional_values": fv.get("functionals", 0),
        "q_entries": v.get("q_entries", 0),
        "prox_entries": v.get("prox_entries", 0),
        "column_entries": v.get("column_entries", 0),
        "differing": (
            cv.get("round_mismatches", 0)
            + cv.get("scalar_mismatches", 0)
            + fv.get("mismatches", 0)
            + v.get("q_mismatches", 0)
            + v.get("prox_mismatches", 0)
            + v.get("column_mismatches", 0)
        ),
        "salted_leaves_authenticated": hl.get("salted_leaves_authenticated", 0),
    }
    out["total"] = (
        out["masked_round_entries"] + out["masked_scalars"]
        + out["functional_values"] + out["q_entries"]
        + out["prox_entries"] + out["column_entries"]
    )
    return out


def mask_cfs_run(bundle, replay, columns="full", coefficients="cfs",
                 hash_layer=True) -> dict:
    """Every stage of one bundle's masking layer."""
    t0 = time.time()
    out = {
        "what": "the masking commitment M and the masked-sumcheck (CFS) "
        "channel, at this run's shape, stage by stage",
        "bundle": bundle.name,
        "profile": bundle.profile,
        "privacy_property_established": False,
        "privacy_acceptance": False,
        "source_pins": check_mask_layer_pins(bundle),
        "per_stage": [],
    }
    if not out["source_pins"]["ok"]:
        out["stages_checked"] = 0
        out["why_not_checked"] = (
            "the mask layer's pins refused for this bundle; every count below "
            "is ABSENT, not passing: " + "; ".join(out["source_pins"]["refusals"])
        )
        out["entries_recomputed"] = 0
        out["entries_differing"] = 0
        out["salted_leaves_authenticated"] = 0
        out["ok"] = False
        out["seconds"] = round(time.time() - t0, 2)
        return out
    for k in range(bundle.blocks):
        out["per_stage"].append(
            mask_cfs_stage(bundle, replay, k, columns=columns,
                           coefficients=coefficients, hash_layer=hash_layer)
        )
    out["stages_checked"] = len(out["per_stage"])
    # `.get` throughout: a stage that REFUSED carries zeroed counts and an
    # `these_zeros_are_an_absence` note, and summing must not crash on it.
    def _sum(field):
        return sum(
            (s.get("entries_recomputed") or {}).get(field, 0)
            for s in out["per_stage"]
        )

    out["entries_recomputed"] = _sum("total")
    out["entries_differing"] = _sum("differing")
    out["salted_leaves_authenticated"] = _sum("salted_leaves_authenticated")
    out["stages_that_refused"] = [
        s["stage"] for s in out["per_stage"] if not s.get("ok")
    ]
    out["functional_count"] = out["per_stage"][0]["declared_order"][
        "captured_functionals"
    ]
    out["mask_rows"] = out["per_stage"][0]["shape"]["rows"]
    out["mask_lengths"] = out["per_stage"][0]["specs_against_the_shape"][
        "mask_lengths"
    ]
    out["ok"] = all(s["ok"] for s in out["per_stage"])
    out["seconds"] = round(time.time() - t0, 2)
    return out


# --------------------------------------------------------------------------
# 5.  THE EQUIVALENCE RUN
# --------------------------------------------------------------------------
def toy_equivalence(capture, replay, columns="full") -> dict:
    """This module's driver at the TOY's widths, on a tracked toy capture.

    The point is not that the numbers are plausible: it is that they are the
    toy gate's own, to the byte.  The driver takes the seeded coefficient
    path (`a1`, `a2`) precisely so that the exhibited-randomness digests can
    be compared with `zk60_native_privacy_gate`'s committed record.  The
    hash layer is off: the toy gate has no Merkle model.
    """
    mm = MaskModel(capture, replay)
    out = {
        "capture": getattr(capture, "name", None),
        "shape": mm.shape(),
        "declared_order": declared_functional_order(capture, replay),
        "disclosed": disclosed_dimension(mm),
        "slot_row_map_rows": len(slot_row_map(mm)),
        "preimages": {},
    }
    for tag in ("a1", "a2"):
        coefs, where = force_functional(mm, synthetic_coefficients(mm, tag), mm.v)
        pre = MaskPreimage(mm, coefs).build()
        ver = pre.verify(columns=columns)
        out["preimages"][tag] = {
            "corrected_at": where,
            "exhibited_randomness_sha256": pre.blinding_digest(),
            "verification": ver,
        }
    cp, coef, cfs = joined_coefficients(capture, {
        "rho": replay.rho, "slot_c": replay.slot_c, "theta": replay.theta,
    }, which="all")
    out["cfs"] = {
        "projection": cfs.get("projection"),
        "zero_transcript_is_infeasible": cfs.get("zero_transcript_is_infeasible"),
        "verification": cp.verify() if coef is not None else None,
        "functional_values": cp.functional_values() if coef is not None else None,
        "fibre_dimension_fp": (
            cp.fibre_dimension()["fibre_dimension_fp"] if coef is not None else None
        ),
    }
    joined = MaskPreimage(mm, coef).build() if coef is not None else None
    out["joined_preimage_at_the_toy"] = (
        joined.verify(columns=columns) if joined and joined.ok else None
    )
    return out


# --------------------------------------------------------------------------
# 6.  THE SHARED-COEFFICIENT RANK STATEMENT (control M-6's arithmetic)
# --------------------------------------------------------------------------
def disclosed_with_identification(model, pairs) -> dict:
    """The disclosed dimension when two slots SHARE a mask coefficient.

    `pairs` is a list of `((s1, t1), (s2, t2))`: each pair is declared to be
    ONE unknown rather than two.  The batched functional's weight on the
    shared unknown is the sum of the two weights, and the unknown space
    loses one Fp2 per pair.  Everything else is `disclosed_dimension`'s own
    computation, done here over the identified coordinate list because the
    toy function takes no identification.
    """
    coords = []
    index = {}
    for s in range(model.S):
        for t in range(model.L[s]):
            index[(s, t)] = len(coords)
            coords.append([(s, t)])
    merged = 0
    for (a, b) in pairs:
        ia, ib = index[a], index[b]
        if ia == ib:
            continue
        coords[ia].extend(coords[ib])
        for key in coords[ib]:
            index[key] = ia
        coords[ib] = []
        merged += 1
    live = [c for c in coords if c]
    width = 2 * len(live)
    r0 = [0] * width
    r1 = [0] * width
    for col, group in enumerate(live):
        w = F2_ZERO
        for (s, t) in group:
            w = f2_add(w, model.ws[s][t])
        r0[2 * col] = w[0]
        r0[2 * col + 1] = w[1] * 7 % P
        r1[2 * col] = w[1]
        r1[2 * col + 1] = w[0]
    got = rank([r0, r1], width)
    return {
        "identified_pairs": merged,
        "coefficient_unknowns_fp": width,
        "coefficient_unknowns_fp_without_identification": 2 * sum(model.L),
        "disclosed_fp_computed": got,
        "fibre_dimension_fp": width - got,
    }


def theta_weight_of(model, s, t):
    """The batched weight `ws[s][t]`, for a control that needs one entry."""
    return model.ws[s][t]


def batched_value(model, coefs, ws=None):
    """`V(a)` under a given weight table -- the one functional M pins."""
    ws = model.ws if ws is None else ws
    v = F2_ZERO
    for s in range(model.S):
        for t in range(model.L[s]):
            w = ws[s][t]
            if not f2_is_zero(w):
                v = f2_add(v, f2_mul(w, coefs[s][t]))
    return v


def permuted_weights(model, i, j):
    """The batched weights and value with functionals `i` and `j` swapped."""
    fns = list(model.m["functionals"])
    fns[i], fns[j] = fns[j], fns[i]
    ws, v, fail = combined_weights(model.specs, fns, model.theta)
    return fns, ws, v, fail


def one_functional(model, i):
    """One captured functional's weight table, unbatched."""
    return single_functional_weights(model, i)


def f2_of(x):
    """A captured `[re, im]` pair as this lane's Fp2."""
    return f2_from_list(x)


# --------------------------------------------------------------------------
# 7.  THE EQUIVALENCE RECORD
# --------------------------------------------------------------------------
# The figures the TOY gate's committed record carries for the block capture
# `40083e7a…`, transcribed here so that the equivalence run compares against
# a fixed expectation rather than against whatever the toy gate says today.
# Source: `results/zk60_native_privacy_gate/privacy_gate.json`,
# `per_capture[0]["masking_commitment_M_opening"]` and
# `["masking_commitment"]["all"]`.
TOY_BLOCK_EXPECTED = {
    "capture_prefix": "40083e7a",
    "disclosed_fp_computed": 2,
    "coefficient_unknowns_fp": 1166,
    "fibre_dimension_fp": 1164,
    "declared_functionals": 34,
    "position_matches": 34,
    "value_matches": 34,
    "weight_matches": 34,
    "rows": 50,
    "distinct_columns": 246,
    "pad_margin": 10,
    "blinding_unknowns_fp": 15870,
    "q_entries": 1024,
    "prox_entries": 1024,
    "column_entries": 12800,
    "exhibited_randomness_sha256": {
        "a1": "e0513e2248d0f773fe872691429add245acb64d0b557f42112ab1381f203d015",
        "a2": "f943d3a08c3663bc53405a82509988a8b066143ef590130fb007aa03eb90c5d6",
    },
    "cfs_round_entries": 721,
    "cfs_scalars": 23,
    "cfs_fibre_dimension_fp": 46,
    "cfs_projection": {
        "which": "all", "conditions": 34, "unmet_before": 29,
        "conditions_on_the_fixed_transcript_fp": 68,
    },
}


def compare_with_the_toy_record(eq: dict) -> dict:
    """Every figure of the equivalence run against the toy gate's own."""
    got = {
        "disclosed_fp_computed": eq["disclosed"]["disclosed_fp_computed"],
        "coefficient_unknowns_fp": eq["disclosed"]["coefficient_unknowns_fp"],
        "fibre_dimension_fp": eq["disclosed"]["fibre_dimension_fp"],
        "declared_functionals": eq["declared_order"]["captured_functionals"],
        "position_matches": eq["declared_order"]["position_matches"],
        "value_matches": eq["declared_order"]["value_matches"],
        "weight_matches": eq["declared_order"]["weight_matches"],
        "rows": eq["shape"]["rows"],
        "distinct_columns": eq["shape"]["distinct_columns"],
        "pad_margin": eq["shape"]["pad_margin"],
        "blinding_unknowns_fp": eq["shape"]["blinding_unknowns_fp"],
        "q_entries": eq["preimages"]["a1"]["verification"]["q_entries"],
        "prox_entries": eq["preimages"]["a1"]["verification"]["prox_entries"],
        "column_entries": eq["preimages"]["a1"]["verification"]["column_entries"],
        "exhibited_randomness_sha256": {
            t: eq["preimages"][t]["exhibited_randomness_sha256"]
            for t in ("a1", "a2")
        },
        "cfs_round_entries": eq["cfs"]["verification"]["round_entries"],
        "cfs_scalars": eq["cfs"]["verification"]["scalars"],
        "cfs_fibre_dimension_fp": eq["cfs"]["fibre_dimension_fp"],
        "cfs_projection": {
            k: eq["cfs"]["projection"][k]
            for k in ("which", "conditions", "unmet_before",
                      "conditions_on_the_fixed_transcript_fp")
        },
    }
    want = {k: v for k, v in TOY_BLOCK_EXPECTED.items() if k != "capture_prefix"}
    bad = [f"{k}: got {got[k]!r}, the toy record has {want[k]!r}"
           for k in want if got[k] != want[k]]
    return {
        "what": "this module's driver at the toy's widths, on the tracked toy "
        "block capture, against the figures the TOY gate's committed record "
        "carries.  Equality here is what makes the port the toy's "
        "construction and not a second one",
        "figures_compared": len(want),
        "equal": len(want) - len(bad),
        "differences": bad,
        "ok": not bad,
    }


def main(argv=None):
    import argparse
    import glob
    import json

    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--toy", required=True,
                    help="the tracked toy captures directory")
    ap.add_argument("--evidence", required=True)
    args = ap.parse_args(argv)

    from zk60_native_jv_capture import Capture
    from zk60_native_jv_replay import Replay

    paths = sorted(glob.glob(os.path.join(args.toy, "*.json")))
    hit = [p for p in paths
           if os.path.basename(p).startswith(TOY_BLOCK_EXPECTED["capture_prefix"])]
    if not hit:
        raise SystemExit(
            f"no toy capture starting {TOY_BLOCK_EXPECTED['capture_prefix']} "
            f"in {args.toy}"
        )
    cap = Capture(hit[0])
    rp = Replay(cap).run()
    t0 = time.time()
    eq = toy_equivalence(cap, rp)
    eq["seconds"] = round(time.time() - t0, 2)
    rec = {
        "what": "round 8's equivalence run: the shape-driven driver at the "
        "toy's widths",
        "privacy_property_established": False,
        "privacy_acceptance": False,
        "capture": os.path.basename(hit[0]),
        "capture_sha256": cap.sha256,
        "layout_specific": sorted(LAYOUT_SPECIFIC),
        "imported_objects": {k: list(v) for k, v in IMPORTED_OBJECTS.items()},
        "derived_from": sorted(DERIVED_FROM),
        "new_here": sorted(NEW_HERE),
        "equivalence": eq,
        "against_the_toy_record": compare_with_the_toy_record(eq),
    }
    rec["ok"] = rec["against_the_toy_record"]["ok"]
    os.makedirs(args.evidence, exist_ok=True)
    out = os.path.join(args.evidence, "toy_equivalence.json")
    with open(out, "w") as fh:
        fh.write(json.dumps(rec, indent=1, sort_keys=True) + "\n")
    print(f"{out}: {rec['against_the_toy_record']['equal']} of "
          f"{rec['against_the_toy_record']['figures_compared']} figures equal "
          f"to the toy gate's record")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
