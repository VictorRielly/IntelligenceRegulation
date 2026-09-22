#!/usr/bin/env python3
"""**The RUN LAYER's own source pins** — closing finding K4-F2.

Round 5 of the run gate (`ZK60_NATIVE_RUN_GATE.md` §9.1 item 3) found that
three of the eight files a run bundle pins in its own `manifest.json` are
pinned by NO run-gate tool, and that `zk60_native_rg_terminals`'s comment
said they were "checked by `zk60_native_rg_bundle`".  They were not.  The
rung-K4 bundles' `run.rs` moved from `65d55d25` to `73f68221` and nothing
noticed.  This module is the pin.

**WHY A PIN AND NOT THE REPLAY.**  Everything the gate says about the run
layer — the run header and its binding, the stage order, the boundary
geometry and its reserved rows, the segment position tags, what a capture
records and in which order — rests on the replay reproducing every challenge
and every tag.  That is strong evidence and it is not a pin: a change to the
CAPTURE WRITER that altered WHAT IS RECORDED without moving a challenge
would be invisible to it.  `run_capture.rs` decides which fields exist and
what they mean; the replay only checks the ones it reads.

**THE DISCIPLINE.**  A digest is in the table below only because the file
was READ at that commit against the port that depends on it, and the diff
between consecutive capture commits was classified hunk by hunk.  A pin
added without a reading is exactly what this lane forbids; `READINGS` carries
the reading beside every digest.

**THE MECHANISM IS BUNDLE-SIDE.**  This gate never reads the Rust lane's
tree: it reads a bundle.  So a file can be pinned here only if the WRITER
pins it, i.e. only if it is in `run_capture.rs::SOURCE_FILES`.  Four
run-layer files are not (`wire.rs`, `run_sink.rs`, `endpoint_g.rs`,
`hash_domain.rs`); they are named in `NOT_PINNABLE_FROM_A_BUNDLE` with the
reason, and none of them is transcribed by any run-gate port.

**A REFUSAL IS NEVER A CRASH** (round 5's finding K4-F1, which is exactly
this failure mode one layer up).  A bundle naming a digest this table does
not accept leaves the AFFECTED STAGES not checked, BY NAME, with every key a
caller reads present and zero-valued, and a sentence saying the zeros are the
absence of a check and not a passing one.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

# --------------------------------------------------------------------------
# 1.  WHAT THE PORTS DEPEND ON IN THE RUN LAYER
# --------------------------------------------------------------------------
# Established 2026-09-21 by reading every run-gate module against the Rust at
# the capture commits.  `DEPENDS` is the list this round's pin table must
# cover EXACTLY: a file a port depends on and the table does not carry is a
# gap, and a pin for a file no port depends on is padding.  The third element
# of each entry is the port's own reference — a function or a constant in the
# Python, so the next reader can go straight to it.
DEPENDS = {
    "src/private_block/run.rs": (
        (
            "zk60_native_rg_replay",
            "`RunStatement::transcript`: the run header's six absorbs in "
            "order -- `run-shape` (seven little-endian u64: L, tokens, width, "
            "hidden, q_heads, kv_heads, head_dim), `expected-IO`, "
            "`public-statement`, `parameters`, `calibration`, `schedule` -- "
            "and that the state there is the run binding",
            "RunReplay.run",
        ),
        (
            "zk60_native_rg_replay",
            "`prove_run` / `RunVerifier::step`: per stage `pb-run-stage(k)`, "
            "`pb-run-block(block_digests[k])`, then the boundary root under "
            "`B` when `k + 1 < L` -- BEFORE the block family's `A`, `M`, the "
            "three LogUp draws and `H`",
            "RunReplay._stage",
        ),
        (
            "zk60_native_rg_replay",
            "`run::position_tag`: two Fp2 squeezed from a DISCARDED clone, so "
            "a segment's start and end tags are outside the challenge chain "
            "(ruling M-6), and stage k's end tag is stage k+1's start tag",
            "RunReplay._position_tag",
        ),
        (
            "zk60_native_rg_bundle",
            "`RunStatement::capture_header`'s `run_shape_words` order, and "
            "`RunVerifier::step`'s opening order `M, A, H, Input` with "
            "`Output` only in the last stage",
            "integrity (`want`, `want_order`)",
        ),
        (
            "zk60_native_rg_joint",
            "`BOUNDARY_SITES = 2` and `RunStatement::in_site` / `out_site`: "
            "site 0 is block k's OUTGOING claim (slot 22) and site 1 block "
            "k+1's INCOMING one (slot 21), which is the identification the "
            "three-role figure is built on",
            "boundary_reserved_figure, discover_shared_planes",
        ),
    ),
    "src/private_block/boundary.rs": (
        (
            "zk60_native_rg_bundle",
            "`BoundarySpec`'s DERIVED geometry: `commitment_rows() = "
            "data_rows + 2*sites + 2`, `site_rows()` the `2*sites` rows after "
            "the data, `prox_row()` the first row after them, `mask_row(s) = "
            "data_rows + 2*s`, and ruling M-1's refusal of a declared row "
            "count that is not the derived one",
            "integrity (the boundary-table block: `row_rule`, `want_rows`, "
            "`want_sites`, `prox_row`, the pair adjacency and distinctness)",
        ),
        (
            "zk60_native_rg_joint",
            "the same geometry as a RESTRICTION: the reserved block is "
            "`2*sites + 2 = 6` columns and the opening's two singleton groups "
            "give `2(G+1) = 6` real generators",
            "boundary_reserved_figure",
        ),
        (
            "zk60_native_rg_pcs",
            "`prepare` setting `mask_rows = site_rows()` and "
            "`prox_mask_row = prox_row()`, which is what the capture's "
            "`row_roles` array reports and the role view ranks",
            "RunRoleView (the reserved-pair schedule check, inherited)",
        ),
        (
            "zk60_native_rg_controls",
            "controls C1 and C2 perturb exactly this geometry -- two sites "
            "sharing one reserved pair, and a single proximity row "
            "(`data + 2*sites + 1`) -- so the control is a control only if "
            "the honest geometry is the file's",
            "controls (C1, C2)",
        ),
    ),
    "src/private_block/run_capture.rs": (
        (
            "zk60_native_rg_bundle",
            "THE WRITER: `SCHEMA`, the three kinds "
            "(`zk60-run-verifier-observations`, "
            "`zk60-run-stage-observations`, `zk60-run-capture-manifest`), "
            "`coverage`, and the run-file and stage-file field names in "
            "`write_run` / `write_stage` -- every field this loader reads by "
            "name exists because that writer emits it",
            "RunBundle.__init__, Stage.__init__, Shape.__init__",
        ),
        (
            "zk60_native_rg_bundle",
            "`TRANSCRIPT_LABELS` (19 entries), transcribed verbatim as "
            "`EXPECTED_LABELS`, so a label added or renamed in Rust is a "
            "refusal here rather than a silent divergence",
            "EXPECTED_LABELS, integrity (`got_labels`)",
        ),
        (
            "zk60_native_rg_bundle",
            "`write_bundle`'s manifest: the per-file SHA-256 and byte length, "
            "`total_bytes`, and the `source_pins` array itself -- which is "
            "the very thing this module reads",
            "integrity (the manifest block)",
        ),
        (
            "zk60_native_rg_planes",
            "the stage-15 `plane_index` member: built from a stage's Layout, "
            "REBUILT and compared at every later stage, the per-slot push "
            "order tied to each slot's private tables by role and slice "
            "offset, and `take` refusing a bundle without one",
            "plane_index_of",
        ),
        (
            "zk60_native_rg_hashrule",
            "the stage-17 `hash_tag` member: the rule name and, on a tagged "
            "profile, the profile string, the four context strings and the "
            "four keys as hex -- which this port RE-DERIVES and compares, "
            "never consumes (ruling T-7)",
            "rule_for_bundle",
        ),
        (
            "zk60_native_rg_terminals",
            "`write_pcs` / `write_stage`'s Fp2 encoding (`c0` then `c1`, "
            "little-endian u64) and the `terminal_polynomial`, "
            "`public_tables` and `row_roles` members the terminal identity "
            "reads",
            "check_terminals, verify_captured_public_tables",
        ),
        (
            "zk60_native_rg_hashlayer",
            "the opened columns as recorded -- each column's index, its "
            "little-endian Fp words, its salt and its authentication path -- "
            "which is what the hash layer re-hashes",
            "check_hash_layer",
        ),
    ),
    # Already pinned before tonight, and named here so the dependency list is
    # the whole of it rather than only the new part.
    "src/private_block/plane_index.rs": (
        (
            "zk60_native_rg_planes",
            "`plane_index::build` and `PlaneIndex::render` / `locate`: the "
            "plane ids, names, domains and row ranges, and the per-slot "
            "ordered list this module tiles and cross-checks",
            "plane_index_of",
        ),
        (
            "zk60_native_rg_terminals",
            "the per-slot push order the terminal identity needs: which "
            "plane each of a slot's private tables is, in the order the "
            "prover pushed them",
            "check_terminals (`structural_push_order_check`)",
        ),
    ),
}

# Pinned BEFORE tonight, and by whom.  `plane_index.rs` is in `DEPENDS` above
# and is NOT in this module's table: it is checked by
# `zk60_native_rg_terminals.check_source_pins` against `PORTED_FROM`, and a
# moved pin there already makes every slot of every stage NOT CHECKED.  Two
# tools pinning one file at two digests is how a pin quietly stops meaning
# anything, so it stays where it is.
PINNED_ELSEWHERE = {
    "src/private_block/plane_index.rs":
        "zk60_native_rg_terminals.PORTED_FROM (one digest, "
        "9de8320a8477...); a moved pin makes every slot of every stage NOT "
        "CHECKED",
}

# Run-layer files a run-gate port does NOT depend on, named rather than
# merely absent.  Two separate reasons are given for each, because either
# alone would be a weaker statement than it looks.
NOT_PINNABLE_FROM_A_BUNDLE = {
    "src/private_block/wire.rs":
        "the segment codec.  (a) No port decodes a segment: the gate reads "
        "the bundle's JSON, and a stage's `segment_bytes` / `segment_sha256` "
        "are REPORTED sizes, never inputs to a check.  The start and end tags "
        "the frame binds are re-derived from the transcript and compared with "
        "the ones the capture recorded, so the comparison is against "
        "`run::position_tag`, not against the frame.  (b) The writer does not "
        "pin it, so no bundle carries a digest to compare",
    "src/private_block/run_sink.rs":
        "the segment writer (a run's bytes to a directory).  (a) No port "
        "reads a segment file; `HL_RUN_CAPTURE_SEGMENTS` is off in every "
        "committed bundle and no bundle in scope carries a `segments/` "
        "directory.  (b) The writer does not pin it",
    "src/private_block/endpoint_g.rs":
        "the external endpoint commitment.  (a) The gate reads the "
        "endpoint's row count from `run.json[\"shape\"][\"endpoint_rows\"]` "
        "and which rows are non-data from the capture's own `row_roles`; "
        "`endpoint_g::MASK_ROWS` is not transcribed anywhere in the run gate "
        "(the TOY gate's analogue, `private_seam.rs`, is pinned by "
        "`zk60_native_mask_commit.PATH_PINS`).  (b) The writer does not pin "
        "it",
    "src/private_block/hash_domain.rs":
        "the C-H4 / T-3 / T-4 hash-length guards.  (a) The one guard the gate "
        "computes is the path-length check, and it is ported from "
        "`pcs::verify_zk_tagged` (pcs.rs:1188) against the commitment's own "
        "encoded width, not from this file; no other guard has a Python "
        "counterpart.  (b) The writer does not pin it",
}

# **DATED CORRECTION, 2026-09-21 (round 9).**  Reason (b) above -- "the
# writer does not pin it" -- was true of every bundle up to `3247a89` and is
# FALSE of a bundle written at `f4697f9`.  Stage 27 grew
# `run_capture.rs::SOURCE_FILES` (8) into `OWN_SOURCE_FILES` (15) and
# `SHARED_SOURCE_FILES` (23), so all four files named above, and the eight
# shared ones the mask port could not pin either, are now in a bundle's
# `source_pins`.  That is the writer-side ask of R6.8 item 1 and R8.9 item 4,
# GRANTED by the Rust lane.  Reason (a) -- no port depends on them -- is
# unchanged and is still what keeps them out of `DEPENDS`.  Nothing above is
# rewritten; `SHARED_LAYER_PINS` below is what the new pins buy, and
# `WRITER_SIDE_ASK_GRANTED` says it in the record.
WRITER_SIDE_ASK_GRANTED = {
    "when": "2026-09-21, lane stage 27, commit f4697f9",
    "what": "`source_pins` grew from 15 entries to 38: `OWN_SOURCE_FILES` "
    "(15 `private_block` files, up from 8 -- `wire.rs`, `run_sink.rs`, "
    "`endpoint_g.rs`, `hash_domain.rs`, `private_block.rs`, `witness.rs` and "
    "`pad.rs` joined) and `SHARED_SOURCE_FILES` (23: `hashline/src/zk.rs`, "
    "`tables_attn.rs`, `causal_oracle.rs`, `private_seam.rs`, `export_v3.rs`, "
    "the seven one-line re-export adapters, and the eleven `zkp-core` "
    "modules behind them).  `timing.rs` is named in `NOT_ON_THE_RUNS_PATH` "
    "with its reason rather than left absent",
    "which_asks": ["R6.8 item 1 (round 6)", "R8.9 item 4 (round 8)"],
    "what_it_does_not_change": "no port's DEPENDS list grows because a file "
    "became pinnable; a pin is added here only after the file is read, and "
    "reason (a) of `NOT_PINNABLE_FROM_A_BUNDLE` -- that no run-gate port "
    "transcribes these four -- is unchanged",
    "applies_to": ("m125-capture-dense-l2", "m125-capture-zero-l2"),
}

# --------------------------------------------------------------------------
# 1b.  THE SHARED FILES, NEWLY PINNED (ROUND 9)
# --------------------------------------------------------------------------
# The 23 `SHARED_SOURCE_FILES` a `/5-run` bundle pins.  Three facts per
# entry, and each was COMPUTED on 2026-09-21 in the read-only Rust lane
# rather than carried over:
#
#   * does a run-gate port depend on it, and which one;
#   * is the digest the bundle declares the same as the blob at `3247a89`,
#     the last capture commit any earlier round accepted;
#   * is it the digest the MASK port recorded as
#     `at_the_capture_commits` in its own `NOT_PINNABLE_FROM_A_BUNDLE` --
#     that is, the bytes round 8 read.
#
# `git diff --numstat 3247a89 f4697f9 -- hashline/src zkp-core/src` touches
# no file in this table, so the second answer is "yes" for all 23 and the
# third is "yes" for all eight the mask port names.  The eight are therefore
# now CHECKABLE from a bundle at exactly the bytes round 8 read, which is
# the whole of what the writer-side ask was for.
SHARED_LAYER_PINS = {
    "src/zk.rs": {
        "sha256": "d4280962af3a89b61b3af69f35650d21f79dc9f51600dcf130442e44a50f1849",
        "depended_on_by": "zk60_native_rg_mask (the mask row model: "
        "`mask_commit`, `encode_coeffs_coset`, `combined_weights`, "
        "`weight_polys`, `poly_mul_512`, `mask_open`, `mask_verify` and the "
        "three constants), through the imported `zk60_native_mask_commit`",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/sumcheck.rs": {
        "sha256": "56dbb8c742d970d3ffd851dd052fbfd4cc4a0a1ab0630258955ffd250e007d19",
        "depended_on_by": "zk60_native_rg_mask (`CfsMask::len / sum_weights / "
        "eval_weights / round`) and zk60_native_rg_replay (the sumcheck "
        "round absorbs)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/ntt.rs": {
        "sha256": "97572d4f242637d21a089388abad4b5b39136c62036faa17ae94b3ba6f170890",
        "depended_on_by": "zk60_native_rg_mask (the forward / inverse "
        "convention the coset encoding rests on)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/field.rs": {
        "sha256": "df3eb5a68eb8f563d6cd4d2198b6959ce304c68429e53895147d7d8607d07f13",
        "depended_on_by": "every port, through zk60_native_jv_field (P, the "
        "nonresidue 7, the byte encodings)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/rng.rs": {
        "sha256": "0d4a99abbc424286de60ec4bfbe1084dc2ccaa2db8c5380e5f4594157ccea9eb",
        "depended_on_by": "zk60_native_rg_mask (the DRAW ORDER of every pad, "
        "mask row and salt of M)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/pcs.rs": {
        "sha256": "6b8d1bfa1a69293e0ea82df46a8b231d896043577e62ab3a837d3fbf743db81a",
        "depended_on_by": "zk60_native_rg_pcs and zk60_native_rg_hashlayer "
        "(`coset_powers`, `hash_column` / `salt_leaf` and their keyed forms, "
        "and `verify_zk_tagged`'s path-length rule)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/merkle.rs": {
        "sha256": "6e7817bd767a883985bfcd62b7a387d0c5f4c361010c4c5db37f5087d965744a",
        "depended_on_by": "zk60_native_rg_hashlayer (the leaf salting and "
        "the inner-node fold that every opened column is re-authenticated "
        "along)",
        "same_as_the_mask_port_read": True,
    },
    "../zkp-core/src/transcript.rs": {
        "sha256": "cc9752d0ef9bcd6d7b20e94e611ff26748593a2ea1a4f55b63d8c221715f1967",
        "depended_on_by": "zk60_native_rg_replay and zk60_native_rg_hashrule "
        "(absorb, squeeze and the keyed form D19 selects)",
        "same_as_the_mask_port_read": True,
    },
    # The remaining fifteen: pinned, read for nothing, and named so that a
    # later reader can see the whole list rather than the useful half.
    "src/tables_attn.rs": {"sha256": "5a874788e20581010b492d50ccc5e662255115c65b9eebcf2f88314733b121e3", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/causal_oracle.rs": {"sha256": "758bd3401cc726dd621ff0b04b9d7b09a50decc773f03f4a21ddbc031921d85a", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/private_seam.rs": {"sha256": "2f36c779e79c4d7a45538fb1d596a83e6eef9fe18f1b5e138b7d72afd3ee8cf5", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/export_v3.rs": {"sha256": "e0394ab4113d150336ee91353d7ba26589d5e4dffcb3cb7d2ad0fea833842acb", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/field.rs": {"sha256": "1dc6c53b9d3b014b8cabfb784c15dcbddde31bc58e6d7216101c6a4fbbf45669", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/merkle.rs": {"sha256": "06fd5f0bd725599d601dacb1b8aac1e797914c7ca8c344c0a52a412260b47eee", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/mle.rs": {"sha256": "bffe83fb5636f445f3a5a3b85141c374bdfeb4e4716c386eec30d10f5ed33741", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/ntt.rs": {"sha256": "a7f7ac0b838747c4de59e8226213500a41c047356ddd8bcdb3ab906818843c7c", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/pcs.rs": {"sha256": "f16932674e49dcf9d2426b89978aa33be9d71665b19f47c527ca4183cdad8789", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/sumcheck.rs": {"sha256": "f097dd71fab7888e95e61a29ab035b13153313d068e7547d91acbfd20c7bc566", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "src/transcript.rs": {"sha256": "4850b2b4dc80317659fd643908e307ca58923c98e98baf32c4c1623ba239fd78", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "../zkp-core/src/lib.rs": {"sha256": "388f012fbb535617bc5a105de8640c84b5572544284cb4947a4ad7606e891164", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "../zkp-core/src/hashtag.rs": {"sha256": "71bf33150a296c2ce4da49d189c6d84a9f741b9ada1ef2488711938cffd6b651", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "../zkp-core/src/mle.rs": {"sha256": "b20c8b75c9246471fe1cc395122558eba715f66d9efe1dc4cd5be1750f2e542e", "depended_on_by": None, "same_as_the_mask_port_read": None},
    "../zkp-core/src/pcs/backend.rs": {"sha256": "1734c03ce6897e784e8ac443581190a00f30f6a91c16479aa7a7a65e00617499", "depended_on_by": None, "same_as_the_mask_port_read": None},
}

# The seven `private_block` files stage 27 added to the bundle's OWN pins,
# with what this gate reads from each.  Four of them are exactly the four
# `NOT_PINNABLE_FROM_A_BUNDLE` names above; the other three were pinned by
# `zk60_native_rg_terminals.ALSO_READ` as digests only, with no bundle to
# compare against.
NEWLY_PINNED_OWN_FILES = {
    "src/private_block/wire.rs": "no port decodes a segment (reason (a) of "
    "NOT_PINNABLE_FROM_A_BUNDLE, unchanged)",
    "src/private_block/run_sink.rs": "no port reads a segment file "
    "(unchanged)",
    "src/private_block/endpoint_g.rs": "no port transcribes MASK_ROWS "
    "(unchanged).  Its stage-26 diff is the generator-domain change: "
    "`EndpointRole`, `seed_domain(spec, role)` and `prepare` taking the "
    "role, so the endpoint's OS-seeded blinding stream is separated by its "
    "bytes and not only by its entropy read.  Nothing absorbed moves",
    "src/private_block/hash_domain.rs": "the one guard the gate computes, "
    "the path length, is ported from `pcs::verify_zk_tagged` (unchanged).  "
    "Its stage-25/26 diff adds `RunFacts`, the four seed-domain builders "
    "and the role bytes -- refusal sets and generator domains, neither of "
    "them a published byte",
    "src/private_block.rs": "the module root; nothing is transcribed",
    "src/private_block/witness.rs": "read by no port -- a capture carries "
    "no witness, which is the whole reason this gate exists",
    "src/private_block/pad.rs": "the pad rule, read by "
    "`zk60_native_rg_terminals.ALSO_READ` as a digest and transcribed "
    "nowhere",
}

# --------------------------------------------------------------------------
# 2.  THE PIN TABLE
# --------------------------------------------------------------------------
# path -> sha256 -> (git blob, the capture commits that carry it, the bundles
# written at them).  Every digest was verified against the committed blob
# with `git show <commit>:<path> | sha256sum` on 2026-09-21 and equals what
# the bundles' own manifests declare.
RUN_LAYER_PINS = {
    "src/private_block/run_capture.rs": {
        "51f26bc1f0d341973992f36187c5e831460093a80db4ba32528e4b072dba89f9": {
            "blob": "8477446f295c915d4822a45e1f95d2eb041171c2",
            "commits": ("cb27845d5ad3a0e401c48c4eebeac7fe4a86f171",),
            "bundles": ("run-a-tame", "run-b-zero"),
            "bytes": 60883,
        },
        "975364b91da9d0850a9c5ff3bcbdc25dabde3d7cc9f907a72885307df45d3c0c": {
            "blob": "6cdc85fbb5af30caa651611b69e3e20fd01023f7",
            "commits": ("aff891dba109812a625b8a15459f9710abcb7a1a",),
            "bundles": ("run-c-tame", "run-d-zero"),
            "bytes": 64762,
        },
        "0cb54ae30f7aed660b69d973624a262a12777387eb85b6ca83709dfeb19f6a63": {
            "blob": "18fb8817c7203397d3fadbe8c0b6aeecf1058d13",
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",
                        "0426ad258cd5d1f77cd62760f29ae186dc43e624",
                        "3247a89762248cfb43f9fdd9cd9147251d69d1df"),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged",
                        "run-g-dense-s20", "run-h-zero-s20",
                        "run-i-dense-k4", "run-j-zero-k4"),
            "bytes": 67932,
        },
        # [ROUND 9] stage 27: the /5-run array store and the shared pins.
        # [ROUND 9b] byte-identical at 4ccbad1, which the rung-P2 bundles
        # pin: `git diff f4697f9 4ccbad1` does not touch this file.
        "d09f385315cac8e7b7fb16a65b0243219e4ba78c09af99b88a84782fe8082dd6": {
            "blob": "9608fa68dd93f61a71504167235d4c05eb41df07",
            "commits": ("f4697f9ccad82304c56dee8c53da3bf107d98b1e",
                        "4ccbad1b1da0a23449ac06461740750a6818c6e8"),
            "bundles": ("m125-capture-dense-l2", "m125-capture-zero-l2",
                        "run-k-dense-p2", "run-l-zero-p2"),
            "bytes": 85434,
        },
    },
    "src/private_block/run.rs": {
        "02f7ee7e922d83f66d77aa64540ee141305b3fe7a6c1127aca55739884cde6bb": {
            "blob": "4e79342ae11e3f9df67e960bd62eb6d166c451fb",
            "commits": ("cb27845d5ad3a0e401c48c4eebeac7fe4a86f171",
                        "aff891dba109812a625b8a15459f9710abcb7a1a"),
            "bundles": ("run-a-tame", "run-b-zero",
                        "run-c-tame", "run-d-zero"),
            "bytes": 36594,
        },
        "87b3f0c47dbd4d9bc8f29ea758504cf18f1eff731ad13038a8dfceac8a7c3ef8": {
            "blob": "c38c30e8657a29f6a2f4afceab06d8b326ee74c0",
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged"),
            "bytes": 39294,
        },
        "65d55d25531c50682ab5a7857364c9d88c134bef1487a0ce2d5fa3e660b25c4f": {
            "blob": "cc41cd8b9de5ad318580f4bfc4566b8cc206c90f",
            "commits": ("0426ad258cd5d1f77cd62760f29ae186dc43e624",),
            "bundles": ("run-g-dense-s20", "run-h-zero-s20"),
            "bytes": 41115,
        },
        "73f6822192fa9aa83753cc20cbf867ede4fdfb75170bb58d2460f2f6fb79a71c": {
            "blob": "0d86be903418faa4232d4c1d50cf53ed14bfda15",
            "commits": ("3247a89762248cfb43f9fdd9cd9147251d69d1df",),
            "bundles": ("run-i-dense-k4", "run-j-zero-k4"),
            "bytes": 41659,
        },
        # [ROUND 9] stages 25 and 26.
        "f24676c4bb38f0c498849e4af3f9caf3cfd0a0ea3d8fe529ae514128259bae35": {
            "blob": "adecd02dbab0f4f5b9b0d91dea7843c6f63da25e",
            "commits": ("f4697f9ccad82304c56dee8c53da3bf107d98b1e",),
            "bundles": ("m125-capture-dense-l2", "m125-capture-zero-l2"),
            "bytes": 44863,
        },
        # [ROUND 9b] stage 30: the rung-P2 run profile.
        "9a0ae11f92489be8c01e616372c8be32a0d539989ca623b746d0505ae2c104b5": {
            "blob": "a9d9d08885988312d24a143ae3faa027e41142ca",
            "commits": ("4ccbad1b1da0a23449ac06461740750a6818c6e8",),
            "bundles": ("run-k-dense-p2", "run-l-zero-p2"),
            "bytes": 45313,
        },
        # [ROUND 9c] stage 31: the rung-C6 run profile, the same two lines.
        "e161190b262691481ce9a52c21c8278b3d5859e68cf4c069c1257ef248c2b612": {
            "blob": "f6d59415f90d1cefc60ead43f75260b234340eca",
            "commits": ("3e106e192bc32701378ca3ce34bb0a8be8d2b7d5",),
            "bundles": ("run-m-dense-c6", "run-n-zero-c6"),
            "bytes": 45755,
        },
        # [ROUND 9c] stage 32: the rung-W14 run profile.  The rung-E32
        # bundles NAME `4505ddf`, which is this same blob -- see finding
        # E32-F1 in the round-9c report: their shape.rs and
        # private_block.rs digests are the ones at `6d71b40`, one commit
        # later, and their run.rs digest is the one at `6d71b40` too, so
        # this entry covers the W14 pair only.
        "472950d55257410829146f558b6fd733cc461a382a3bd0618f0e6456ed201c24": {
            "blob": "04843cea18f3bce4c6d5b8b074bba8c837163bd6",
            "commits": ("11703c94df428c3e53dbc6c37eac835e348f5bf9",
                        "4505ddfa24fc99ff57fa086be8c73dae8117875c"),
            "bundles": ("run-o-dense-w14", "run-p-zero-w14"),
            "bytes": 46205,
        },
        # [ROUND 9c] stage 33: the rung-E32 run profile.
        "f39aec7925ba27d51361cd3935e874b1301d7595be81f3199d9d2941c0f818e0": {
            "blob": "6af1c39cec721e4a16db27de7906f78f82de5d98",
            "commits": ("6d71b405de9863a7a95dc166ba932f6e12e5a2d0",
                        "2d04d941f1e7e4e52b72f7d1434060779814405e",
                        "226f3b2c6aed44fe9b1f495cd7c7e34b900e4e90"),
            "bundles": ("run-q-dense-e32", "run-r-zero-e32"),
            "bytes": 46667,
        },
    },
    "src/private_block/boundary.rs": {
        "9860c35d4db93afa52ba4287ac949209dc3d93957da51a6aeee91b0951a215e6": {
            "blob": "18f951e77f76370671d6fdd9a4cce29eeb5aba09",
            "commits": ("cb27845d5ad3a0e401c48c4eebeac7fe4a86f171",
                        "aff891dba109812a625b8a15459f9710abcb7a1a"),
            "bundles": ("run-a-tame", "run-b-zero",
                        "run-c-tame", "run-d-zero"),
            "bytes": 31741,
        },
        "3786a3001b49bcd760f07007096ba285531ae0ecb933630808fef6aa18a5e9db": {
            "blob": "c6f060c6886deb46b4e3f882b2c35917a3654d96",
            "commits": ("facc0574a3fe5817c24720157e802b33085a85d8",
                        "0426ad258cd5d1f77cd62760f29ae186dc43e624",
                        "3247a89762248cfb43f9fdd9cd9147251d69d1df"),
            "bundles": ("run-e-tame-tagged", "run-f-zero-tagged",
                        "run-g-dense-s20", "run-h-zero-s20",
                        "run-i-dense-k4", "run-j-zero-k4"),
            "bytes": 33954,
        },
        # [ROUND 9] stage 26.
        # [ROUND 9b] byte-identical at 4ccbad1, which the rung-P2 bundles
        # pin: `git diff f4697f9 4ccbad1` does not touch this file.
        "5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581": {
            "blob": "c2d57a37f4f442c65edc3ba9237f2d21118b09e9",
            "commits": ("f4697f9ccad82304c56dee8c53da3bf107d98b1e",
                        "4ccbad1b1da0a23449ac06461740750a6818c6e8"),
            "bundles": ("m125-capture-dense-l2", "m125-capture-zero-l2",
                        "run-k-dense-p2", "run-l-zero-p2"),
            "bytes": 36123,
        },
    },
}

# --------------------------------------------------------------------------
# 3.  THE READINGS
# --------------------------------------------------------------------------
# One entry per (file, digest).  The first digest of each file is the BASE
# reading -- the file read whole against the port.  Every later digest is the
# base plus a diff that was classified hunk by hunk, with the line counts
# from `git diff --numstat` and the split between production code and
# `#[cfg(test)] mod tests` counted rather than eyeballed.
READINGS = {
    ("src/private_block/run_capture.rs",
     "51f26bc1f0d341973992f36187c5e831460093a80db4ba32528e4b072dba89f9"):
        "BASE (stage 14, the writer's first version).  Read whole against "
        "`zk60_native_rg_bundle`: `SCHEMA = \"hashline-native-capture/4-run\"`, "
        "the three kinds, `coverage = \"native-run-all-stages-v1\"`, the "
        "run-file and stage-file field orders in `write_run` / `write_stage`, "
        "`TRANSCRIPT_LABELS` (19 entries, equal entry for entry to "
        "`EXPECTED_LABELS`), `ALLOWED_KEYS`, `SOURCE_FILES` (6), and "
        "`write_bundle`'s manifest with its per-file digests and "
        "`source_pins`.  Every field the loader reads by name is emitted "
        "here, and nothing the loader reads is absent",
    ("src/private_block/run_capture.rs",
     "975364b91da9d0850a9c5ff3bcbdc25dabde3d7cc9f907a72885307df45d3c0c"):
        "`git diff cb27845d aff891d`: **84 added, 3 removed, 9 hunks, none "
        "in a test module**.  STAGE 15, the plane index table: `SOURCE_FILES` "
        "6 -> 7, `Rec.index` / `index_json`, the per-stage rebuild-and-compare "
        "in `stage_begin`, the per-slot push-order check in `slot` (each "
        "private table located by role and slice offset), `take` refusing a "
        "bundle without a table, the `plane_index` member in `run.json`, and "
        "13 new `ALLOWED_KEYS`.  The three removed lines are the "
        "`SOURCE_FILES` count, the `Rec` initialiser and the `mask_domain` "
        "write, each re-emitted unchanged but for the new field.  **Nothing "
        "the loader already read moved**: not a schema string, not a kind, "
        "not `coverage`, not a label, not a field name or its order.  The new "
        "member is what `zk60_native_rg_planes` reads, and that port was "
        "written FOR it in round 2",
    ("src/private_block/run_capture.rs",
     "0cb54ae30f7aed660b69d973624a262a12777387eb85b6ca83709dfeb19f6a63"):
        "`git diff aff891d facc057`: **65 added, 7 removed, 9 hunks, none in "
        "a test module**.  STAGE 17/18, decision D19: the recorder rebuilds "
        "the header under `protocol::tagged_transcript` (so its binding "
        "comparison is the verifier's and a legacy-rule recorder would fail "
        "it at every tagged profile), `mask_verify_tagged` and "
        "`verify_zk_tagged` at the two replay call sites, a new `hash_tag` "
        "member in `run.json` with 9 new `ALLOWED_KEYS`, and `SOURCE_FILES` "
        "7 -> 8 (`shape.rs`).  `TRANSCRIPT_PROGRAM` grows 9 -> 10 entries; NO "
        "port reads it (`grep -rn transcript_program scripts/ tests/` is "
        "empty), and `transcript_labels`, which every port does read through "
        "`EXPECTED_LABELS`, is **unchanged at 19 entries**.  The `hash_tag` "
        "member is what `zk60_native_rg_hashrule` re-derives and compares "
        "under ruling T-7, written in round 3",
    ("src/private_block/run.rs",
     "02f7ee7e922d83f66d77aa64540ee141305b3fe7a6c1127aca55739884cde6bb"):
        "BASE (stage 14/15).  Read whole against `zk60_native_rg_replay`: "
        "`RunStatement::transcript` opens `Transcript::new(profile)` and "
        "absorbs `run-shape` (seven little-endian u64 in the order L, tokens, "
        "width, hidden, q_heads, kv_heads, head_dim), `expected-IO`, "
        "`public-statement`, `parameters`, `calibration`, `schedule`; "
        "`binding()` is the state there.  `prove_run` and `RunVerifier::step` "
        "absorb `pb-run-stage`, `pb-run-block`, then `absorb_root(b\"B\")` "
        "when `k + 1 < L`, then the block family.  `position_tag` squeezes "
        "two Fp2 from a DISCARDED clone.  `BOUNDARY_SITES = 2`, and "
        "`in_site` / `out_site` put the incoming claim at slot 21 and the "
        "outgoing at slot 22.  Each of those is a line of `RunReplay.run` / "
        "`._stage`, and the opening order is `integrity`'s `want_order`",
    ("src/private_block/run.rs",
     "87b3f0c47dbd4d9bc8f29ea758504cf18f1eff731ad13038a8dfceac8a7c3ef8"):
        "`git diff aff891d facc057`: **48 added, 9 removed, 12 hunks, no test "
        "module in this file**.  STAGE 16/17/18, decision D19 and rulings "
        "T-1 / T-3 / T-4 / T-7: the run-level hash-length guard "
        "(`hash_domain::imposed_at_shape_with` over A, H, M, the external "
        "endpoint and the internal boundary), `boundary_spec` -> "
        "`BoundarySpec::new_with_tag(..., &sh.hash_tag())`, `transcript` -> "
        "`protocol::tagged_transcript(sh, profile)`, T-4's "
        "`segment_paths_are_the_tree_depth`, the verifier's own `tag` field "
        "derived from its statement and never from a segment, and three "
        "`pcs::verify_zk` -> `verify_zk_tagged`.  **The header's six absorbs "
        "and their order, `position_tag`, the stage loop, the "
        "boundary-before-A rule, `BOUNDARY_SITES` and the opening order are "
        "untouched.**  The one thing a port depends on that DID move is the "
        "transcript constructor, and that is precisely what the D19 rule the "
        "loader DERIVES selects: `RunReplay.run` opens with "
        "`rule.transcript(...)`, written in round 3",
    ("src/private_block/run.rs",
     "65d55d25531c50682ab5a7857364c9d88c134bef1487a0ce2d5fa3e660b25c4f"):
        "`git diff facc057 0426ad2`: **30 added, 0 removed, 1 hunk**.  "
        "Ruling R-5 (register D12b item 3): a run refuses any block scale "
        "pair but the approved calibration's `ENDPOINT_SCALES`, because the "
        "INTERIOR scales were in no absorbed word.  **No absorb is added and "
        "no proof byte moves** -- it is a refusal and nothing else, and the "
        "Rust's own "
        "`run_tests::the_run_header_the_approved_scales_bind_is_byte_"
        "identical_under_ruling_r5` pins the rung-G `L = 3` binding, both "
        "boundary digests and the parameter line as literals captured before "
        "the refusal existed.  No run-gate port reads a block scale",
    ("src/private_block/run.rs",
     "73f6822192fa9aa83753cc20cbf867ede4fdfb75170bb58d2460f2f6fb79a71c"):
        "`git diff 0426ad2 3247a89`: **9 added, 0 removed, 2 hunks** "
        "(`--numstat` 9/0; round 5's report and ledger said 12 added -- a "
        "recording error, corrected 2026-09-21).  STAGE 22: "
        "`RUN_PROFILE_RUNG_K4` and `RunShape::rung_k4`, which calls the "
        "UNCHANGED `RunShape::new`.  Not one existing line moves.  The new "
        "profile string is read by `zk60_native_rg_hashrule`, which derives "
        "the four D19 keys from the bundle's own shape profile and compares "
        "them with the declared ones",
    ("src/private_block/boundary.rs",
     "9860c35d4db93afa52ba4287ac949209dc3d93957da51a6aeee91b0951a215e6"):
        "BASE (stage 14/15).  Read whole against `zk60_native_rg_bundle` and "
        "`zk60_native_rg_joint`: `commitment_rows() = data_rows + 2*sites + "
        "2`, `site_rows()` the `2*sites` rows after the data, `prox_row()` "
        "the first row after them, `mask_row(s) = data_rows + 2*s` with site "
        "0 the outgoing claim and site 1 the incoming, `MAX_SITES = 4`, "
        "ruling M-1's refusal of a declared row count that is not the derived "
        "one (with both numbers in the message), and `prepare` writing the "
        "plane at the front and setting `mask_rows = site_rows()`, "
        "`prox_mask_row = prox_row()`.  Those are exactly `integrity`'s "
        "boundary-table checks and the `2*sites + 2 = 6` reserved columns "
        "over `2(G+1) = 6` generators that `boundary_reserved_figure` ranks, "
        "and they are what controls C1 and C2 perturb",
    ("src/private_block/boundary.rs",
     "3786a3001b49bcd760f07007096ba285531ae0ecb933630808fef6aa18a5e9db"):
        "`git diff aff891d facc057`: **42 added, 13 removed, 13 hunks**, and "
        "the split matters: **production +27 / -3**, `#[cfg(test)] mod tests` "
        "(from line 311 of the old file) **+15 / -10**.  STAGE 17/18: `new` "
        "keeps its signature and delegates to a new `new_with_tag` under "
        "`HashTag::legacy()`; the C-H4 guard becomes "
        "`no_commitment_has_a_node_shaped_column_under(..., tag)`, imposed "
        "under the legacy rule only; `prepare` takes the run's tag and calls "
        "`commit_zk_owned_tagged`.  The ten test-side removals are `prepare` "
        "call sites gaining `&HashTag::legacy()` and the claim-sites refusal "
        "case moving from 3 sites to 4 (three would give 12 commitment rows, "
        "whose column hashes to 96 bytes, which the completed C-H4 now "
        "refuses for its own reason).  **Not one geometry accessor moved**: "
        "`data_rows`, `commitment_rows`, `site_rows`, `prox_row`, "
        "`mask_row`, `MAX_SITES` and ruling M-1's refusal are byte-identical, "
        "and the ports read only those",
    # ---------------------------------------------------------- ROUND 9
    ("src/private_block/run_capture.rs",
     "d09f385315cac8e7b7fb16a65b0243219e4ba78c09af99b88a84782fe8082dd6"):
        "`git diff 3247a89 f4697f9`: **368 added, 23 removed, 36 hunks**, and "
        "this file has no test module (its tests are `run_capture_tests.rs`, "
        "which no bundle pins), so the whole diff is production.  STAGE 27, "
        "and it is two changes.  (1) **The `/5-run` array store**: "
        "`SCHEMA_V5`, `ARRAY_MIN = 256`, `CaptureOpts`, `schema_of(arrays)`, "
        "an `ArrayStore` that appends an array's little-endian image to one "
        "blob, deduplicates by SHA-256 and returns "
        "`{array, elem, len, offset, bytes}`, and the six emission sites "
        "that now route through it -- an opened column's `values`, an "
        "opening group's `vector`, `proximity_rhos`, `proximity_vector`, "
        "the M opening's `q` and `prox`, and a public table's `values`.  "
        "The 23 removed lines are those same six `write!`s and the "
        "`SOURCE_FILES` constant, each re-emitted.  **Not one field name, "
        "member order, kind, coverage string or transcript label moves**, "
        "and `ALLOWED_KEYS` gains exactly two entries, `array` and `elem` "
        "(format 12: `offset`, `len`, `bytes` and `sha256` were already on "
        "it).  A `/4-run` bundle is still written when "
        "`HL_RUN_CAPTURE_ARRAYS=store` is absent, and the writer's own "
        "`the_array_store_and_the_classic_encoding_carry_the_same_values` "
        "captures one run twice in one process and asserts byte-for-byte "
        "equality of the expanded store with the classic encoding.  "
        "`zk60_native_rg_arrays` is this lane's reader for it, proved "
        "against a re-encoded development bundle (round 9, item N1).  "
        "(2) **`SOURCE_FILES` 8 -> `OWN_SOURCE_FILES` 15 + "
        "`SHARED_SOURCE_FILES` 23 = 38 pins**, plus `NOT_ON_THE_RUNS_PATH` "
        "naming `timing.rs` with its reason.  That is the writer-side ask "
        "R6.8 item 1 and R8.9 item 4, GRANTED: see `SHARED_LAYER_PINS` "
        "below",
    ("src/private_block/run.rs",
     "f24676c4bb38f0c498849e4af3f9caf3cfd0a0ea3d8fe529ae514128259bae35"):
        "`git diff 3247a89 f4697f9`: **50 added, 2 removed, 3 hunks**, and "
        "read hunk by hunk it is **three statements of production code and "
        "forty lines of comment**.  (1) The run-level hash-length guard now "
        "takes a `hash_domain::RunFacts { profile, l, parameter_line }` "
        "instead of the bare parameter line (stage 25, W-4), so the "
        "statement class goes into the imposed set: `let facts = ...;` added "
        "and the `imposed_at_shape_with` call re-emitted.  It is a REFUSAL "
        "SET and absorbs nothing.  (2) `ZkRng::from_os(profile.as_bytes())` "
        "becomes `ZkRng::from_os(&hash_domain::run_seed_domain(profile))` "
        "(stage 26, the ruling on finding B-1): the OS-seeded BLINDING "
        "stream's domain now carries a versioned use literal and the run "
        "prover's role byte beside the profile string.  **That stream is not "
        "the transcript.**  No absorb, no label, no squeeze and no "
        "verifier-visible byte moves, and a replay cannot see it -- which is "
        "why the round-9 replay reproduces every challenge of a bundle "
        "written under it.  (3) A 35-line doc comment, ruling H-1 on what a "
        "production caller owes.  **The header's six absorbs and their "
        "order, the seven-word shape, `position_tag`, the stage loop, the "
        "boundary-before-A rule, `BOUNDARY_SITES` and the opening order are "
        "byte-identical**, and those are the whole of what "
        "`zk60_native_rg_replay` transcribes",
    ("src/private_block/run.rs",
     "9a0ae11f92489be8c01e616372c8be32a0d539989ca623b746d0505ae2c104b5"):
        "`git diff f4697f9 4ccbad1`: **7 added, 0 removed, two hunks -- "
        "ADDITIONS ONLY**, and they are one constant and one constructor.  "
        "STAGE 30: `RUN_PROFILE_RUNG_P2 = "
        "\"hashline-zk-mr1/private-run-rung-p2-t32-dev/1\"` (one profile per "
        "shape, decision D17, so the rung-P2 runs get their own hash-tag key "
        "set and no existing profile moves) and `RunShape::rung_p2(l)` "
        "delegating to the UNCHANGED `RunShape::new`.  **Nothing this port "
        "transcribes moved**: `RunStatement::transcript`'s six absorbs and "
        "their order, the seven-word `run-shape`, `position_tag`'s discarded "
        "clone, the stage loop's `pb-run-stage` / `pb-run-block` / boundary "
        "order, `BOUNDARY_SITES`, `in_site` / `out_site` and the opening "
        "order `M, A, H, Input(, Output)` are byte-identical -- which is why "
        "the rung-P2 replay re-derives every challenge of a bundle written "
        "under a profile string this gate had never seen",
    ("src/private_block/run.rs",
     "e161190b262691481ce9a52c21c8278b3d5859e68cf4c069c1257ef248c2b612"):
        "[ROUND 9c] `git diff 4ccbad1 3e106e1 -- run.rs`: **7 added, 0 "
        "removed, two hunks -- ADDITIONS ONLY**, and they are letter for "
        "letter the rung-P2 pair one stage earlier.  STAGE 31: "
        "`RUN_PROFILE_RUNG_C6 = "
        "\"hashline-zk-mr1/private-run-rung-c6-t32-dev/1\"` (D17, one "
        "profile per shape, so rung-C6 gets its own hash-tag key set and "
        "no existing profile moves) and `RunShape::rung_c6(l)` delegating "
        "to the UNCHANGED `RunShape::new`.  **Nothing this port "
        "transcribes moved**: `RunStatement::transcript`'s six absorbs and "
        "their order, the seven-word `run-shape`, `position_tag`, the "
        "stage loop's `pb-run-stage` / `pb-run-block` / boundary order, "
        "`BOUNDARY_SITES`, `in_site` / `out_site` and the opening order "
        "`M, A, H, Input(, Output)` are byte-identical",
    ("src/private_block/run.rs",
     "472950d55257410829146f558b6fd733cc461a382a3bd0618f0e6456ed201c24"):
        "[ROUND 9c] `git diff 3e106e1 11703c9 -- run.rs`: **7 added, 0 "
        "removed, two hunks -- ADDITIONS ONLY**, the same two lines again.  "
        "STAGE 32: `RUN_PROFILE_RUNG_W14 = "
        "\"hashline-zk-mr1/private-run-rung-w14-t64-dev/1\"` and "
        "`RunShape::rung_w14(l)`.  Read against `4ccbad1` the file is **14 "
        "added, 0 removed** -- rung-C6's two lines and rung-W14's two -- "
        "and every absorb, tag, stage-loop step and opening order named in "
        "the entry above is byte-identical.  This blob is also what the "
        "commit the rung-E32 bundles NAME (`4505ddf`) carries, which is "
        "part of finding E32-F1 and not of this reading",
    ("src/private_block/run.rs",
     "f39aec7925ba27d51361cd3935e874b1301d7595be81f3199d9d2941c0f818e0"):
        "[ROUND 9c] `git diff 11703c9 6d71b40 -- run.rs`: **7 added, 0 "
        "removed, two hunks -- ADDITIONS ONLY**, the same two lines a "
        "third time.  STAGE 33: `RUN_PROFILE_RUNG_E32 = "
        "\"hashline-zk-mr1/private-run-rung-e32-t32-dev/1\"` and "
        "`RunShape::rung_e32(l)`.  Against `4ccbad1` the whole file is "
        "**21 added, 0 removed**: three constants and three constructors, "
        "one per new shape, and not one line of what the replay reads.  "
        "**The rung-E32 bundles record `source_commit: 4505ddf`, which "
        "does NOT carry this blob** -- `4505ddf` is the commit before "
        "`Shape::rung_e32` exists.  The commits listed here are the ones "
        "that do carry it, and the mismatch is finding E32-F1",
    ("src/private_block/boundary.rs",
     "5b1c85feefacf61fd97fa6e60b9f72d737f1dd56349ecaa650fc93d3ad0e6581"):
        "`git diff 3247a89 f4697f9`: **44 added, 6 removed, 9 hunks**, split "
        "**production +22 / -0** and `#[cfg(test)] mod tests` **+22 / -6**.  "
        "STAGE 26 again.  In production: one accessor, `index() -> u64` (the "
        "boundary's own index, a PUBLIC word of the run statement), and a "
        "16-line doc comment saying that a boundary is the one commitment on "
        "the path with no generator of its own -- it is handed the run's "
        "single stream -- and naming the domain it WOULD use "
        "(`hash_domain::boundary_seed_domain(index, spec.digest())`) without "
        "calling it.  In the tests: a `test_generator(spec)` helper and six "
        "call sites that now seed from that domain instead of the module's "
        "`DOMAIN` label.  **Not one geometry accessor moved**: `data_rows`, "
        "`commitment_rows`, `site_rows`, `prox_row`, `mask_row`, `MAX_SITES` "
        "and ruling M-1's refusal are byte-identical, and the ports read "
        "only those",
}

# --------------------------------------------------------------------------
# 4.  WHICH STAGES A MOVED PIN SUSPENDS
# --------------------------------------------------------------------------
# The gate's record keys, per file, with the reason.  A refusal suspends the
# UNION over the refused files.  `stage7_channels` is a summary of the others
# and is in every list, so `channels()` is never called on a partial record --
# which is the K4-F1 failure mode and is not repeated here.
ALL_STAGES = (
    "stage1_integrity",
    "stage2_transcript_replay",
    "stage3_per_commitment",
    "stage4_the_boundary",
    "stage5_zero_data_preimage",
    "stage6_negative_controls",
    "stage7_channels",
    "stage8_plane_index_and_terminals",
    "stage9_hash_layer",
    "stage10_bilinear_group_factor",
)

AFFECTED_STAGES = {
    "src/private_block/run_capture.rs": (
        ALL_STAGES,
        "the WRITER decides which fields a bundle has and what each one "
        "means, so an unread writer leaves every figure of this gate a "
        "reading of bytes whose definition is unknown",
    ),
    "src/private_block/run.rs": (
        ALL_STAGES,
        "the run's header, stage order, boundary-absorb rule, position tags "
        "and opening order are the replay, and every rank downstream is taken "
        "at challenges the replay re-derived; `integrity` also transcribes "
        "the `run_shape_words` order and the opening order from this file",
    ),
    "src/private_block/boundary.rs": (
        (
            "stage1_integrity",
            "stage3_per_commitment",
            "stage4_the_boundary",
            "stage5_zero_data_preimage",
            "stage6_negative_controls",
            "stage7_channels",
        ),
        "the derived row count, the reserved rows and the claim-site "
        "assignment are what the boundary table is checked against, what the "
        "restricted and three-role ranks are taken on, what the singleton "
        "preimage solves, and what controls C1-C3 perturb.  The replay "
        "absorbs the boundary ROOT with the rows and width the capture "
        "states, so stage 2 does not depend on this file; nor do the plane "
        "index, the terminal identity or the hash layer",
    ),
}


# --------------------------------------------------------------------------
# 5.  THE CHECK
# --------------------------------------------------------------------------
def check_shared_pins(bundle) -> dict:
    """[ROUND 9] The SHARED files a `/5-run` bundle pins, against the table
    above.  Never a refusal that suspends a stage: a bundle that does not
    pin them (every bundle before `f4697f9`) reports `pinned: false` and
    that is the state rounds 1-8 were in.  A bundle that pins one at a
    digest this gate has NOT read is named -- the gate says which port
    depends on it, so a reader can see at once whether the difference
    reaches a figure."""
    pins = {p["file"]: p["sha256"]
            for p in bundle.manifest.get("source_pins", [])}
    present = [f for f in SHARED_LAYER_PINS if f in pins]
    if not present:
        return {
            "pinned": False,
            "what": "this bundle's writer pins no shared file; the eight the "
            "mask port transcribes are checked by reading only "
            "(zk60_native_rg_mask.NOT_PINNABLE_FROM_A_BUNDLE), which is "
            "where rounds 1-8 left them",
            "files_pinned": 0,
            "of": len(SHARED_LAYER_PINS),
            "ok": True,
        }
    at_read, moved, depended = [], [], []
    for f in sorted(present):
        want = SHARED_LAYER_PINS[f]
        got = pins[f]
        dep = want["depended_on_by"]
        if dep:
            depended.append(f)
        if got == want["sha256"]:
            at_read.append(f)
        else:
            moved.append(
                f"{f}: the bundle pins {got[:12]}, this gate read "
                f"{want['sha256'][:12]}"
                + (f" -- and {dep} depends on it" if dep else
                   " -- no run-gate port depends on it")
            )
    return {
        "pinned": True,
        "what": "the 23 SHARED files stage 27 added to a bundle's "
        "source_pins, the writer-side ask of R6.8 item 1 and R8.9 item 4",
        "writer_side_ask_granted": WRITER_SIDE_ASK_GRANTED,
        "newly_pinned_own_files": NEWLY_PINNED_OWN_FILES,
        "files_pinned": len(present),
        "of": len(SHARED_LAYER_PINS),
        "at_a_digest_this_gate_read": len(at_read),
        "depended_on_by_a_port": sorted(depended),
        "equal_to_the_bytes_round_8_read": sorted(
            f for f in at_read
            if SHARED_LAYER_PINS[f]["same_as_the_mask_port_read"]
        ),
        "pins_that_moved": moved,
        "per_file": [
            {"file": f, "declared": pins[f], **SHARED_LAYER_PINS[f]}
            for f in sorted(present)
        ],
        "what_this_is_not": "a pin is a statement about which bytes this "
        "gate has read, not that the Rust is right, and a shared file's "
        "pin suspends no stage: the ports that depend on these eight were "
        "already checked against them by READING in round 8, and this "
        "makes the reading checkable from the bundle",
        "ok": not moved,
    }


def check_run_layer_pins(bundle) -> dict:
    """The bundle's own `source_pins` for the RUN LAYER against the digests
    this gate has READ.  A digest outside the table is a refusal by name; it
    is never a silent re-read and never an exception.

    The record names, for every pinned file: the digest, whether it is one
    this gate read, at which lane commits that digest lives and which bundles
    were written at them.  A file missing from the manifest is as much a
    refusal as a moved one -- a bundle that stopped declaring its writer
    would otherwise pass.
    """
    pins = {p["file"]: p["sha256"]
            for p in bundle.manifest.get("source_pins", [])}
    accepted, moved, missing = [], [], []
    detail = []
    for path in sorted(RUN_LAYER_PINS):
        table = RUN_LAYER_PINS[path]
        got = pins.get(path)
        if got is None:
            missing.append(
                f"{path}: the bundle declares no digest for it, and this gate "
                "does not read the Rust tree, so the file is unchecked"
            )
            detail.append({"file": path, "declared": None, "read": False})
            continue
        entry = table.get(got)
        if entry is None:
            moved.append(
                f"{path}: the bundle pins {got[:12]}, which is not one of the "
                f"{len(table)} digests this gate has read "
                f"({', '.join(sorted(d[:12] for d in table))})"
            )
            detail.append({"file": path, "declared": got, "read": False})
            continue
        accepted.append(f"{path}: {got[:12]} -- read at "
                        f"{', '.join(c[:7] for c in entry['commits'])}")
        detail.append({
            "file": path,
            "declared": got,
            "read": True,
            "git_blob": entry["blob"],
            "lane_commits": list(entry["commits"]),
            "bundles_written_at_them": list(entry["bundles"]),
            "bytes": entry["bytes"],
            "reading": READINGS[(path, got)],
        })
    ok = not moved and not missing
    suspended = {}
    if not ok:
        for line in moved + missing:
            path = line.split(":", 1)[0]
            stages, why = AFFECTED_STAGES[path]
            for s in stages:
                suspended.setdefault(s, []).append(f"{path}: {why}")
    return {
        "what": "the three RUN-LAYER files a bundle pins -- the capture "
                "writer, the run's own geometry and transcript, and the "
                "internal boundary -- against the digests this gate has READ "
                "(finding K4-F2, closed 2026-09-21)",
        "files_checked": sorted(RUN_LAYER_PINS),
        "pinned_elsewhere": PINNED_ELSEWHERE,
        "on_the_run_layer_but_not_pinnable_from_a_bundle":
            NOT_PINNABLE_FROM_A_BUNDLE,
        "shared_files": check_shared_pins(bundle),
        "per_file": detail,
        "pins_at_a_read_digest": accepted,
        "pins_that_moved": moved,
        "pins_missing_from_the_bundle": missing,
        "stages_not_checked": {k: sorted(set(v)) for k, v in suspended.items()},
        "ok": ok,
    }


def not_checked(stage: str, reasons) -> dict:
    """The record a suspended stage leaves behind.

    It carries `ok` (so the gate's own `all(record[k]["ok"])` sees the
    refusal), the stage's name, every reason, and the sentence that stops a
    reader taking an absent check for a passing one.  It carries no zeroed
    figure, because a zero that looks like a measurement is worse than a
    missing key -- the callers that read figures out of a stage are not
    reached, since `stage7_channels` is suspended whenever anything is.
    """
    return {
        "stage": stage,
        "checked": False,
        "not_checked_because": list(reasons),
        "what_the_absence_means": "a RUN-LAYER source pin moved or is "
        "missing, so this gate has not read the Rust that decides what this "
        "stage would be computing.  NOTHING HERE SAYS THE BUNDLE IS BAD, and "
        "the absence of a figure is not a figure",
        "ok": False,
    }
