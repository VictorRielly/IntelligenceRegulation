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
