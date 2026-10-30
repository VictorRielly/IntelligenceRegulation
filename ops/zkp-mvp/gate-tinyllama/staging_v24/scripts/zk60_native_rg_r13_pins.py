#!/usr/bin/env python3
"""[TOOLS v22 staging, gate round 19, 2026-10-29: native R12b -> R13, and the
token tree frozen-r14 -> frozen-r15 -> frozen-r16 -> frozen-r16b on top of R13]
The READINGS behind the source pins a capture from token frozen-r16b carries,
read step by step from the last digests the gate read: native R12b and token
frozen-r14 (tools v21: `zk60_native_rg_tinyllama_r12b_pins`, whose chains end
at native R9 digests the block gate read in v17) and, for the classifier
files, `zk60_native_rg_classpins.CLASSIFY_R14_READINGS` /
`CLASSIFY_PORTED_FROM_V21`.  READ 2026-10-29 11:10-11:26 UTC by the reading
sub-lane of the privacy-gate lane with `diff -u` / `diff -U0` over the frozen
copies (saved under results/zk60_gate_tinyllama_20261017/round19/readings/);
nothing was built or run.  The parent merges these dicts; no existing digest
or reading changes here.

THE TREES.  Native R12b `results/zk60_1b_native_20261017/r12b/frozen-tree/`
(tree 51de5b83..., 229 files); native R13 `.../r13/frozen-tree/` (tree
bb9eb212..., 269 files, `r13/manifest_frozen.json`; D24 review REVIEW_R13
ACCEPTED on soundness, 2026-10-29 07:21 UTC); token frozen-r15 (259 files,
manifest_final_r15.sha256), frozen-r16 (300 files, list f42f8c6e...; REVIEW_R16
ACCEPTED WITH FIXES), frozen-r16b (301 files, manifest_final_r16b.sha256, list
04d94bc0...; UNREVIEWED by its own freeze note).  Every digest below was
re-hashed against the frozen copies (and the r13 / r16b manifests).

R13 = R12b + the accuracy stack S2 (LOW and LOW + h24): twelve NEW block
profiles (shape.rs `ACCURACY_PROFILES`) and twelve NEW run profiles (run.rs
`ACCURACY_RUN_PROFILES`), twelve NEW production modules (accuracy*.rs,
argument_accuracy.rs, trained_accuracy.rs, witness_accuracy.rs), export schema
`zk60-trained-profile-export/2`, the per-layer common gate denominator G
(`Shape::accuracy_gate_shift`, `LayerRecord::accuracy_gate_shift`), and
`BlockPublic.accuracy`.  Token round 16 rebases the token tree onto R13 and
registers the R13 Shieldstral classifier run profiles (T128 / T256 non-DD),
the moderate D37 policies, `stage_shape` at the layer's G, the R13 whole-run
LogUp term and N-r13-5 (one checkpoint stream); round 16b makes round 12's
card policy test-only (REVIEW_R16 F-1).

THE PROFILE GATES [READ].  Every R13 / round-16 / 16b change is one of:
* gated on a NEW profile: `accuracy_spec(profile)` (shape.rs; the twelve
  `R13_*` block profile strings) and its consequence `Shape::accuracy_stack()
  != Stack::Legacy`, `blk.accuracy().is_some()` (set only through
  `BlockPublic::with_accuracy`, called only by the R13 export loader and
  tests; `check_for_shape` REFUSES accuracy data at a legacy shape),
  `ACCURACY_RUN_PROFILES` / `ACCURACY_CLASSIFY_RUN_PROFILES`, the schema-/2
  export reader, `LayerRecord.accuracy_gate_shift` (`None` at every legacy
  record: `of_block` gives `blk.accuracy().map(..)`; the identity encodes
  `accuracy-gate-layer` only when `Some`), the tied derivation's margin row
  (`TiedDerivation`, only at a tied = Shieldstral export);
* the identity at every legacy shape (`limbs_p()` uses `f_p()` = F_P there;
  `Witness::output` reads `ids.at(A_X2)` = A_X2; the ACT multiplicity loop runs
  over `act_histogram`'s 256 entries as before; `RunStatement::stage_shape`
  and `fit_the_stages` reduce to the old code; the ff act table is `gact`,
  which the old code checked equal to the exported `act`);
* `#[cfg(test)]` code (run_capture.rs, plane_index.rs are test-only
  modules; RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST; the census helpers);
* new refusals that legacy inputs never meet (a legacy export naming
  `accuracy_stack` or an R13 array; a legacy record carrying a G).

At the profiles the gate captured before -- TinyLlama T32 block / token, the
rung block profiles, the token rung, the classifier rung run profile
`hashline-zk-mr1/private-classify-run-rung-tc-t32-public-row-dev/1` -- no step
read here moves a receipt byte, a block-stage byte or a public-statement byte
(slots, planes, mask rows / functionals, schedule, profile text, stage lines,
trained-statement identity, transcript).  REVIEW_R13 section 1 (9 / 9 golden
lines, retained stacks verify) and REVIEW_R16 section 7 / the r16b freeze
note (rung receipts cross-verify r15 <-> r16 <-> r16b, identity 061340df...
unchanged) say the same and are cited; the reading is the evidence.  What
moves is capture METADATA: every bundle's `source_pins` gains the twelve R13
accuracy modules (OWN_SOURCE_FILES 26 -> 38), and run.json's `shape.slots`
lists exactly n_slots triples since r15 (F18-1).

!! FINDING R19-PIN-1 (for the parent; capture-side, not a pin defect) !!
`plane_index.rs` (13a7dd6f, unchanged R12b -> R13 -> r16b, `#[cfg(test)]`)
names A planes only with the LEGACY segment table and pushes slots with the
LEGACY push order.  At an R13 shape `Ids` comes from `AccuracyIds` (109 A
planes at LOW+h24 non-DD with 3 sigma limbs, 107 with 2; the legacy table
gives 79 / 77 names there [COUNTED]), so
`plane_index::build` refuses ("the A plane name table has 79 names for 109
planes") and run_capture's recorder FAILS every R13 block stage ("replay: the
plane index does not build at stage k", run_capture.rs:981 / 1137 / 1277).
No frozen-r16b hook can write an R13-stack bundle as the tree stands.  See
OPEN_QUESTIONS and R13_READINGS.json `r13_block_changes_for_the_port`.

[v24, gate round 24, 2026-10-30] token frozen-r17 -> r18 -> r19 -> r19b
(manifest_final_r19b, 306 files, list cfae2d1e...): exactly two of the 72
capture pins move -- `src/private_block.rs` 2af1df7d -> 96c1cd16 (r18, one
re-exported name) and `tied_tables/derive.rs` c5bec3c6 -> 4b53222b (r19,
E7) -> 1d615010 (r19b, doc + tests).  `TOKEN_R19B_READINGS` reads each step;
`TOKEN_R19B_DIGESTS` is the r19b terminal table (r16b's with those two and
run_capture.rs cce0fc2a); `self_check` chains and re-hashes it too.
DERIVE_T16 / PRIVATE_BLOCK_T16 keep their values (the r16b links).  The
other eight moved paths (classify_cli.rs, the two batch files,
examples/zk60_classify.rs and four test files) are not capture pins.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import hashlib
import os

READ_AT_UTC = "2026-10-29T11:25:41Z"

def repo_root(start=None) -> str:
    """[v23, gate round 20] F19-G1: the repository root is the first directory
    ABOVE this file that holds both `results/` and `ops/zkp-mvp/` (v22 took a
    fixed five parent directories, true in `frozen_v22/` / `staging_v22/` and
    not in the working copy `ops/zkp-mvp/gate-tinyllama/scripts/`).  Refuses
    by name when there is none."""
    d = os.path.dirname(os.path.abspath(start or __file__))
    while True:
        if os.path.isdir(os.path.join(d, "results")) and os.path.isdir(os.path.join(d, "ops", "zkp-mvp")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            raise RuntimeError(f"F19-G1: no repository root (a directory with results/ and ops/zkp-mvp/) above "
                               f"{os.path.abspath(start or __file__)}")
        d = parent


# the repository root, found by searching upward (v22: <root>/ops/zkp-mvp/gate-tinyllama/<dir>/scripts/this file)
_ROOT = repo_root()
NATIVE_R12B_TREE = "results/zk60_1b_native_20261017/r12b/frozen-tree/hashline"
NATIVE_R13_TREE = "results/zk60_1b_native_20261017/r13/frozen-tree/hashline"
TOKEN_R14_TREE = "results/zk60_token_io_r1_20261017/frozen-r14/hashline"
TOKEN_R15_TREE = "results/zk60_token_io_r1_20261017/frozen-r15/hashline"
TOKEN_R16_TREE = "results/zk60_token_io_r1_20261017/frozen-r16/hashline"
TOKEN_R16B_TREE = "results/zk60_token_io_r1_20261017/frozen-r16b/hashline"
NATIVE_R13_TREE_SHA256 = "bb9eb2123c9350c738dafd19fe3b0133d6e2e7ab93f1e765cac4f20ccaed69ec"
TOKEN_R16B_MANIFEST = "results/zk60_token_io_r1_20261017/manifest_final_r16b.sha256"
TOKEN_R16B_LIST_SHA256 = "04d94bc0904ccaeb621d001b72be51b54034bfb5f7135a543e872a36a834c549"

TREE = ("results/zk60_token_io_r1_20261017/frozen-r16b (manifest_final_r16b.sha256, 301 files, "
        "list sha256 04d94bc0904ccaeb621d001b72be51b54034bfb5f7135a543e872a36a834c549), rebased on "
        "results/zk60_1b_native_20261017/r13/frozen-tree (tree "
        "bb9eb2123c9350c738dafd19fe3b0133d6e2e7ab93f1e765cac4f20ccaed69ec, 269 files)",)
# the round-19 captures (token frozen-r16b); the parent fills this tuple
R19_BUNDLES: tuple = ()

# ---------------------------------------------------------------- the files
ARG, SHP, WIT, PROT, LAY = ("src/private_block/argument.rs", "src/private_block/shape.rs",
                            "src/private_block/witness.rs", "src/private_block/protocol.rs",
                            "src/private_block/layout.rs")
TST, TBK, PBR = ("src/private_block/trained_statement.rs", "src/private_block/trained_block.rs",
                 "src/private_block.rs")
RUN, RCP = "src/private_block/run.rs", "src/private_block/run_capture.rs"
TTB, DRV = "src/private_block/tied_tables.rs", "src/private_block/tied_tables/derive.rs"
TIO, TRUN, TLOAD = ("src/private_block/token_io.rs", "src/private_block/token_io/run.rs",
                    "src/private_block/token_io/load.rs")
CLS, CTD, CRN = ("src/private_block/token_io/classify.rs", "src/private_block/token_io/classify_tied.rs",
                 "src/private_block/token_io/classify_run.rs")
ACC = {n: f"src/private_block/{n}.rs" for n in (
    "argument_accuracy", "accuracy_act", "accuracy_fold", "accuracy_layout",          # pinned FIRST in OWN_SOURCE_FILES
    "accuracy", "accuracy_aligned", "accuracy_groups", "accuracy_precision",          # pinned at the END
    "accuracy_public", "accuracy_tables", "trained_accuracy", "witness_accuracy")}

# ---------------------------------------------------------------- the digests (full) [COUNTED, re-hashed]
# the bases (read by tools v21)
ARGUMENT_R12B = "c4f9f9f4cb477346b03e9f769d7c3141a8529f096d08da2be6c415d5160a5e66"     # = t14 = t15
SHAPE_R12B = "9a87081897ff0ec716d7f27a2813cc32117683eb5b2f2082a248f479ef98c4c5"        # = t14 = t15
WITNESS_R12B = "a586b777c36c9fa5060d3dfa195a75ff0a2b7794a2521cad59aaf7f3f6144ec3"      # = t14 = t15
PROTOCOL_R12B = "c482402329e4da32a70c780435b2077e8054d1805b1006289f571820017564a4"     # = t14 = t15 (= R9 c4824023, block gate)
LAYOUT_R12B = "9332802e597beacab56cfa69cfe18325bc476d2ce6485f517051992b26d26efa"       # = t14 = t15 (= R9, block gate)
TRAINED_STATEMENT_R12B = "7908d827889d5bb424b51cb470313c666533577b29fd45c78957db00963e6a1d"  # = t14 = t15
TRAINED_BLOCK_R12B = "e2551aa15fddc7cf43753ca0f5ef65fe813b1f7c279f4928fad1fd6b8c5d77a5"
TRAINED_BLOCK_T14 = "f892dbc7d4de24d0a17945637107fb4e22a09d4e9a0bdc8520790352f121d06b"     # = t15
PRIVATE_BLOCK_R12B = "b4f73a054afed47450ff846218a4453607281da16b8bc56dca904a6ee7447108"
PRIVATE_BLOCK_T14 = "295409589f53c74144ce7fe8e9e4571f614660fe69b6f6f3cbd2e382b5940256"     # = t15
RUN_R12B = "5c9f0ffc12a2a4bdc239799dde6e0c3eab3f316a7bcc6ca071719407b9e96a8d"
RUN_T14 = "51e8aed2c52d21149618f0ba7f16c35774dd376c4bc0c557d6c2c7ef1e4ea6e9"               # = t15
RUN_CAPTURE_R12B = "8721e83d277f4ee853603bc8d5fe63f60b2b3917b9fbee7ed2123e25d0ec76db"
RUN_CAPTURE_T14 = "ef9c54dbdf9588df381055b6f959ee8d7a9f8396075c59bf2b774115b76cb012"
TIED_TABLES_R12B = "901fa1e4f4a1c4c5070665fc1f81534142038e362408bff4dbcb5fca1e57c8b2"
TIED_TABLES_T14 = "049ddc181ca31435681e24199b80c03b4ffc494898be80f8515156652df1a7ce"       # = t15
DERIVE_R12B = "e2b76895fae1ee04a469f095153d8451969c637ca4dd5939dd937c159d749adf"
DERIVE_T14 = "5cebeef0f0deea3973898648f87e1905ed87c76ddc6ceaf5a24ab742429a4f41"            # = t15 = NATIVE R13 (!)
TOKEN_IO_T14 = "eda64c31babe2efabb47f4f843c8f9061506042d82d469309a2697987d5f5f11"
TOKEN_RUN_T14 = "477cfc8ce45070ec44d846ff19e05045978d045396a1735aad0e5c56e3c1f439"         # = t15
LOAD_T14 = "a9b72811350e1042392b0a8b60bcffddcd01a6b8a39cfa32f97ce4f72cb030dc"              # = t15
CLASSIFY_T14 = "6c828db6673ec389eaa75eef7c543b378ce4f7693dbf70c0c999a6fe959a90ae"          # = t15 (v21 port digest)
CLASSIFY_TIED_T14 = "401d38d444b6ae2b69d19ab4b2e6a78996521e432303ea551d91889d43a6e76c"     # = t15 (v21 port digest)
CLASSIFY_RUN_T14 = "5d1d077f510202d17d76c7660a87a5cb6afd7254fc2fc450bf1a39577cb9ebd1"      # = t15 (v21 port digest)

# native R13 (read here)
ARGUMENT_R13 = "bc0332e39904ca881d26c255581aa1ab6a0e73899141689960ec2262f8561830"       # = t16 = t16b
SHAPE_R13 = "8e00a144bd194fd5a3dd30c9aaece2869d43d461df623cdcfc5a9da59e51436b"          # = t16 = t16b
WITNESS_R13 = "7620447c30ecf111f47f44cd3cd8d75152fda753802fb99c74a873bf7e8c9625"        # = t16 = t16b
PROTOCOL_R13 = "1011441431a37f735999405986af6c9f11c2d303b48aa6d9cefae55b0311718d"       # = t16 = t16b
LAYOUT_R13 = "8519a514b8d1f43ab51c86b0a8af955230a2eab4fff4fc4c594733c59dcfd0bf"         # = t16 = t16b
TRAINED_STATEMENT_R13 = "f6be924c6b8625ae6a51649b843ab7d118f3925e248ee140d081b9e0bc23e9d4"  # = t16 = t16b
TRAINED_BLOCK_R13 = "4ee6dccb5d788f4d99ad82ff7884ee4aa35d2b679d52a20f0cb3b72dd6d315ad"
PRIVATE_BLOCK_R13 = "c55da6ade97d9e2864d0cad43fc330620b4929f86a7338ff5517163b1242e677"
RUN_R13 = "66f0ac950f7ddff23fa89e2788b70fed9785c846cbc8beeb3612c1527566b156"
RUN_CAPTURE_R13 = "affddeae00a953f745de172b7b9829770b53cf724f253cb61c857b17ee3e2cc2"
TIED_TABLES_R13 = "1a321aff73517f94cb0311cd4bf2d7d243c063d442fc4c9aa27c3f92e2ada228"
DERIVE_R13 = DERIVE_T14

# token frozen-r15 / r16 / r16b (read here)
RUN_CAPTURE_T15 = "527df40efb5e427bd779359be7a9699d3d0de93814cd020dec23d3aee8937ef0"
RUN_CAPTURE_T16 = "cad25086949c34d5d338fd1522401486f8099448cce47551f5487d3a05fc0fd7"       # = t16b
TOKEN_IO_T15 = "3808d844490c2653ce4e7232eede59e70ec1dfcf840ce77806cbb56ab0e009c0"
TOKEN_IO_T16 = "2aabe64f8c9d4c9028f94af87d25dfddd44f0631ddb636616ec8679d09bed337"           # = t16b
RUN_T16 = "3dc5393db188cdd92a775011318fc8d8031812ff7d8772d6528dbc3261efa99f"                # = t16b
PRIVATE_BLOCK_T16 = "2af1df7d5bc222695c1d233050ff87a5f0981a26a5df1828678b67a6fe0a1cb3"      # = t16b
TRAINED_BLOCK_T16 = "dc6e8772bf80ff3d16dff49b416667cf92bf58148da60d8695004df01900ca07"      # = t16b
TIED_TABLES_T16 = "45fc3f0fe20c5d8b798f6bbc0fe3f1b7aa68f4427b0a3521c92ba83230b30e33"        # = t16b
DERIVE_T16 = "c5bec3c676e635aab1c609fdf2f541d003e14d7a50efc36d0fed42fc85b7d981"             # = t16b = t17 = t18 (v24: the r16b LINK; r19 / r19b below)
TOKEN_RUN_T16 = "aae4b0ab9568f90150f78a1eaf68710c65b52e54ab2654e18452de279039117e"          # = t16b
LOAD_T16 = "67307f096ca4ea9dd12e182a9b173436fd0015e7367a3b444e5733d188a4ce79"               # = t16b
CLASSIFY_T16 = "c23074e9db87563d610ebd65a4083cdddeda07744f86a4c3ddf00fa94d5b82c7"
CLASSIFY_T16B = "c180c83fb50f624d15ef9d17dae4195b53161a1131892ea0bb15b0761da99b1d"
CLASSIFY_TIED_T16 = "a89acfabc75c869c1f53d493a5caaa236af1a8df18ba6e30b1f3ab26167c4aaf"     # = t16b
CLASSIFY_RUN_T16 = "8abbf72f1c8e18bea1ac99e93a82562bca793afb4d94ed27dea24403850523f9"      # = t16b

# [v24, gate round 24] token frozen-r18 / r19 / r19b (READ in round 24, each against the previous digest:
# results/zk60_gate_tinyllama_20261017/round24/readings/).  Exactly two of an R13 classifier capture's 72
# source pins move r17 -> r19b (round24/READINGS_R24.json).  DERIVE_T16 and PRIVATE_BLOCK_T16 are NOT
# overwritten: they stay the r16b links of their chains (their readings above and below are unchanged); the
# r19b TERMINALS of those two files move to the digests here (TOKEN_R19B_DIGESTS).
PRIVATE_BLOCK_T18 = "96c1cd16270b087ab56d8fd4cf3777009e5000800ab2d65afc1342ae555c6ac4"      # = t19 = t19b
DERIVE_T19 = "4b53222b37820936821eea2fd506ff3dee991e2474d39a3b21f1c0c10d357d75"             # token round 19 (E7)
DERIVE_T19B = "1d6150100abb051d08e77d6c86e2cafed0915342203480ce73c8583170810fb7"            # token round 19b (R19-1 / R19-3)
RUN_CAPTURE_T17 = "cce0fc2a4062fcb4c92e771b8d7ac7f996c9ccfbc985bfb6decd79b29fba7ddf"        # = t18 = t19 = t19b (read in classpins v23)
TOKEN_R17_TREE = "results/zk60_token_io_r1_20261017/frozen-r17/hashline"
TOKEN_R18_TREE = "results/zk60_token_io_r1_20261017/frozen-r18/hashline"
TOKEN_R19_TREE = "results/zk60_token_io_r1_20261017/frozen-r19/hashline"
TOKEN_R19B_TREE = "results/zk60_token_io_r1_20261017/frozen-r19b/hashline"
TOKEN_R19B_MANIFEST = "results/zk60_token_io_r1_20261017/manifest_final_r19b.sha256"
TOKEN_R19B_LIST_SHA256 = "cfae2d1e3c9f662b477bc7ba7ee418ed74c8732d0717732a74385cd8430b67b9"

# the twelve NEW R13 modules: native R13 digest and the token frozen-r16b digest (equal except trained_accuracy.rs)
NEW_R13_DIGESTS = {
    ACC["argument_accuracy"]: ("a5e02391b61577c7041efc41c04cd2564610e3fbb26b188b66b1623a5b7940d9", None),
    ACC["accuracy_act"]: ("7ef5fe26fc9395817436fc55851dc1f2ea066bc06b8a5eaaa3e2c39a8045eb4e", None),
    ACC["accuracy_fold"]: ("53e2b5726440eb747f55d5d22bdd36929f8d17bba8b769d17162c0948890731a", None),
    ACC["accuracy_layout"]: ("37a3e3458e4961ddaab98440de114e575da3af21f7d872b532cb71a04ac788d3", None),
    ACC["accuracy"]: ("2996ff41016a65ac6b22db78768295879f4b37a48316267c655a410d667bc6af", None),
    ACC["accuracy_aligned"]: ("396d0cf271b9ac401364e0c96a6c549eb4a31f91750a3072391d55ac8b9e9f8d", None),
    ACC["accuracy_groups"]: ("63a87749a6e03e54104fdaa382d76421b0b984599fce7cca8714f348b7731731", None),
    ACC["accuracy_precision"]: ("145c1e0f66ea5aad558148aa7885b4fcaaf74c6145893cc1efd10f7a77eee56b", None),
    ACC["accuracy_public"]: ("0b44bf5424fed9ea9911e3b041c0977ea0727bb461b83be198a5d2210d73d660", None),
    ACC["accuracy_tables"]: ("0a92b7fff83a460b2f79560b195ed65c4a7024b80108631b3741bfbaba5511e8", None),
    ACC["trained_accuracy"]: ("20d44812a1d38a37a1ad20cd5378a921633d35b8c11031d0fea0918bf52e21fa",
                              "f47b1084574a36a160db6d81fc1a25dd43f4547d438653d5de53ec86826c66d7"),
    ACC["witness_accuracy"]: ("8b03abadc73db1d46be642e32c83312c87e34bfa4d560ab8d8e2675b14abcf2a", None),
}


def _r16b_digest_of_new(f):
    nat, tok = NEW_R13_DIGESTS[f]
    return tok or nat


# the terminal digests: the capture tree (token frozen-r16b) and native R13
TOKEN_R16B_DIGESTS = {
    ARG: ARGUMENT_R13, SHP: SHAPE_R13, WIT: WITNESS_R13, PROT: PROTOCOL_R13, LAY: LAYOUT_R13,
    TST: TRAINED_STATEMENT_R13, TBK: TRAINED_BLOCK_T16, PBR: PRIVATE_BLOCK_T16, RUN: RUN_T16,
    RCP: RUN_CAPTURE_T16, TTB: TIED_TABLES_T16, DRV: DERIVE_T16, TIO: TOKEN_IO_T16, TRUN: TOKEN_RUN_T16,
    TLOAD: LOAD_T16, CLS: CLASSIFY_T16B, CTD: CLASSIFY_TIED_T16, CRN: CLASSIFY_RUN_T16,
    **{f: _r16b_digest_of_new(f) for f in NEW_R13_DIGESTS},
}
# [v24] the terminal digests of token frozen-r19b (= frozen-r16b's above but for three files: private_block.rs
# and derive.rs, read below, and run_capture.rs, read in zk60_native_rg_classpins.TOKEN_R17_READINGS)
TOKEN_R19B_DIGESTS = dict(TOKEN_R16B_DIGESTS, **{PBR: PRIVATE_BLOCK_T18, DRV: DERIVE_T19B, RCP: RUN_CAPTURE_T17})
NATIVE_R13_DIGESTS = {
    ARG: ARGUMENT_R13, SHP: SHAPE_R13, WIT: WITNESS_R13, PROT: PROTOCOL_R13, LAY: LAYOUT_R13,
    TST: TRAINED_STATEMENT_R13, TBK: TRAINED_BLOCK_R13, PBR: PRIVATE_BLOCK_R13, RUN: RUN_R13,
    RCP: RUN_CAPTURE_R13, TTB: TIED_TABLES_R13, DRV: DERIVE_R13,
    **{f: d[0] for f, d in NEW_R13_DIGESTS.items()},
}
# the digest each chain must reach (read by tools v21; None: a NEW file's first reading)
CHAIN_ROOTS = {
    ARG: ARGUMENT_R12B, SHP: SHAPE_R12B, WIT: WITNESS_R12B, PROT: PROTOCOL_R12B, LAY: LAYOUT_R12B,
    TST: TRAINED_STATEMENT_R12B, TBK: (TRAINED_BLOCK_T14, TRAINED_BLOCK_R12B), PBR: (PRIVATE_BLOCK_T14, PRIVATE_BLOCK_R12B),
    RUN: (RUN_T14, RUN_R12B), RCP: (RUN_CAPTURE_T14, RUN_CAPTURE_R12B), TTB: (TIED_TABLES_T14, TIED_TABLES_R12B),
    DRV: (DERIVE_T14, DERIVE_R12B), TIO: TOKEN_IO_T14, TRUN: TOKEN_RUN_T14, TLOAD: LOAD_T14,
    CLS: CLASSIFY_T14, CTD: CLASSIFY_TIED_T14, CRN: CLASSIFY_RUN_T14,
    **{f: None for f in NEW_R13_DIGESTS},
}

_P = "[GATE ROUND 19, native R13 / token frozen-r16b] "


def _r(base, stat, reading, receipt=False, stage=False, cls="", diff=""):
    return {"base": base, "diff_stat": stat, "moves_a_receipt_byte": receipt,
            "moves_a_block_stage_byte": stage, "classification": cls, "diff_file": diff,
            "reading": _P + reading}


_D = "results/zk60_gate_tinyllama_20261017/round19/readings/"
GATED, IDENT, TEST, NEWF = ("gated-on-new-profiles", "identity-at-captured-profiles", "test-only", "new-file")

# file -> new digest -> its reading against `base` (native R12b -> native R13)
NATIVE_R13_READINGS = {
    ARG: {
        ARGUMENT_R13: _r(ARGUMENT_R12B, "+27 / -2, 5 hunks against c4f9f9f4 (native R12b)",
            "(1) `#[path = \"argument_accuracy.rs\"] mod accuracy;`.  (2) `Ctx` gains `accuracy: Option<&AccuracyPublic>` "
            "(protocol.rs passes `blk.accuracy()`, None at every legacy block).  (3) `define`: FIRST `if "
            "ctx.lay.shape().accuracy_stack() != Stack::Legacy { if let Some(def) = accuracy::define_changed(..)? { "
            "return Ok(def) } }` -- at a legacy shape the branch is not taken and the legacy body runs byte for byte.  "
            "(4) the Q / K / V / O matmul arm: `fold_rows_i8(w, outer, inner, &eq_table_msb(&r_j))` becomes `let "
            "weights = eq_table_msb(&r_j); let folded = if Legacy { fold_rows_i8(w, outer, inner, &weights) } else { "
            "accuracy_fold::fold(w, outer, inner, Axis::Rows, &coefficients(sh, data, site), &weights)? }` -- the same "
            "value at Legacy.  (5) the GMM / UMM / DMM arm: the same with `fold_cols_i8` / Axis::Columns.  The push "
            "order (a_at(plane, coords), public(fold)), the challenge r_j, the bilinear arms, every other arm, "
            "`run_slot`'s M-functional block, `sum_weights` and the slot loop are outside the hunks",
            cls=GATED, diff=_D + "nat-r12b-r13-argument.rs.diff"),
    },
    SHP: {
        SHAPE_R13: _r(SHAPE_R12B, "+123 / -5, 17 hunks against 9a870818 (native R12b)",
            "(1-2) `DD_PROFILES` [5] -> [11] and `TRAINED_CALIBRATION_PROFILES` [15] -> [27]: the twelve R13 strings "
            "APPENDED (membership tests; every old entry in place, so `dd_cap` and the trained-calibration door are "
            "unchanged at old profiles).  (3) the R13 registry: the twelve `R13_*` profile strings, `AccuracyProfile`, "
            "`ACCURACY_PROFILES`, `accuracy_spec(profile)` (Some only for those twelve).  (4-5) `trained_rope_theta` / "
            "`trained_rope_scaling` first map an R13 profile to its legacy twin (`accuracy_spec(..).map(|s| s.legacy)"
            ".unwrap_or(profile)`: the identity at every other profile).  (6) `trained_geometry`: an R13 arm before the "
            "old ones (only when `accuracy_spec` is Some).  (7) `Shape.accuracy_gate_shift: u32` (`17` at an R13 "
            "profile, `0` elsewhere, set in `Shape::build`); `accuracy_stack()` = Legacy unless `accuracy_spec`; "
            "`accuracy_registry`, `accuracy_base`, `accuracy_precision`, `f_p()` (= F_P at Legacy), "
            "`with_accuracy_gate_shift` (refused at Legacy), `accuracy_trained`.  (8) `Shape::build`'s D / F "
            "row-width refusal only when `accuracy_spec` is Some.  (9) `check_trained_class`: R13 checks only off "
            "Legacy.  (10) CS-8's rebuild: `with_accuracy_gate_shift` only off Legacy; the field compared (0 == 0 at "
            "Legacy).  (11) `limbs_norm` / `norm_top_is_full_byte`: 3 / true only off Legacy; `limbs_p` uses "
            "`f_p()` (F_P at Legacy).  (12) `a_plane_doms` and `lookups_per_position`: the R13 lists only off "
            "Legacy, returning early before the legacy bodies.  `slots()`, `claim_sites`, `slot_terms`, `n_slots`, "
            "`m_rows`, `n_functionals`, `helpers` (= lookups_per_position.div_ceil(2)) and every legacy list are "
            "outside the hunks, so at every old profile the (n, e, d) triples, plane lists, lookups, claim sites, "
            "mask rows (2 n_slots + 4) and functionals (34, + 2 at DD) are R12b's",
            cls=GATED, diff=_D + "nat-r12b-r13-shape.rs.diff"),
    },
    WIT: {
        WITNESS_R13: _r(WITNESS_R12B, "+37 / -7, 2 hunks against a586b777 (native R12b)",
            "(1) `#[path = \"witness_accuracy.rs\"] mod accuracy;`, `build_accuracy` (R13 component builder, refuses "
            "a gate mismatch) and `build_for_block(sh, blk, input)` = at Legacy `blk.check_for_shape(sh)` then the "
            "frozen `build_shaped` (an added refusal on the prover's side, the same planes), else the accuracy "
            "builder; `Witness` gains `output_plane` and `#[derive(Clone)]`; `output()` reads "
            "`planes[output_plane]`.  (2) `build_shaped` sets `output_plane: ids.at(A_X2)`, which is A_X2 at every "
            "legacy shape (the old doc: A_X2 sits below every growing limb group and `build_shaped` refuses a fifth "
            "norm limb), so `output()` reads the same plane.  The witness decides private values only; at the old "
            "profiles every plane value is R12b's",
            cls=IDENT, diff=_D + "nat-r12b-r13-witness.rs.diff"),
    },
    PROT: {
        PROTOCOL_R13: _r(PROTOCOL_R12B, "+38 / -15, 10 hunks against c4824023 (native R12b = R9)",
            "(1, 3, 6-7) the sealing pass, the ACT histogram, the ACT helper denominators and the ACT table column: "
            "`match blk.accuracy() { Some(data) => accuracy_act::{histogram, query_values, table}(..), None => <the "
            "legacy expression, byte for byte> }`.  (2) a comment rewritten.  (4) the multiplicity write: the old "
            "loop `for i in 0..U8_LEN { .. MU8, MEXP, MACT .. }` is split: MU8 / MEXP keep the U8_LEN loop, MACT is "
            "written `for (i, &count) in m_act.iter().enumerate()`; at Legacy `act_histogram` returns exactly "
            "U8_LEN = 256 counts (protocol.rs:477-486), so the same 256 words are written.  (5) the F-4 "
            "multiplicity hook's assert, `#[cfg(test)]`.  (8) the padded-row F-4 hook's table, `#[cfg(test)]` path "
            "with the same match.  (9-10) `Ctx { accuracy: blk.accuracy(), .. }` on both sides.  No absorb, draw, "
            "label, opening or order moves at a legacy block (blk.accuracy() is None there: BlockPublic::new sets "
            "None, `with_accuracy` is called only by the R13 loader and tests, and `check_for_shape` refuses "
            "accuracy data at a legacy shape)",
            cls=GATED, diff=_D + "nat-r12b-r13-protocol.rs.diff"),
    },
    LAY: {
        LAYOUT_R13: _r(LAYOUT_R12B, "+32 / -3, 7 hunks against 9332802e (native R12b = R9)",
            "(1-3) `Ids.accuracy: Option<AccuracyIds>`; `Ids::new` returns the `AccuracyIds` map FIRST when "
            "`accuracy_stack() != Legacy` (checked against the independently counted `a_plane_doms`), else the "
            "legacy construction with `accuracy: None` -- the same map, doms and limb counts.  (4) `nr / ns / mr / "
            "ms / pl / sr / sg` gain an `assert!(k < count)` (a panic where the old code read past a group: never "
            "reached by the legacy callers, whose k is below the counts by construction); `accuracy()`, "
            "`domain_range()` (new).  (5) `lookups_at`: the R13 lookup list only off Legacy, returning early.  "
            "(6) the schedule's calibration description line: an R13 arm FIRST only off Legacy (`if "
            "sh.accuracy_stack() != Legacy { R13 line } else if sh.trained_calibration { <old> } else { <old> }`), "
            "so every legacy schedule line and `schedule_digest` is R12b's",
            cls=GATED, diff=_D + "nat-r12b-r13-layout.rs.diff"),
    },
    TST: {
        TRAINED_STATEMENT_R13: _r(TRAINED_STATEMENT_R12B, "+123 / -7, 10 hunks against 7908d827 (native R12b)",
            "(1) `pinned_for_profile` and `tied_tensor_for_profile` map an R13 profile to its legacy twin first "
            "(identity elsewhere).  (2) `as_the_code_proves`: `norm_wrho`, `sh_u`, `f_p` take R13 values only off "
            "Legacy (`f_p: sh.f_p()` = F_P at Legacy).  (3) `LayerRecord.accuracy_gate_shift: Option<u32>`; "
            "`shape_at` (the old has_own / with_layer_calibration expression, then the G only when Some) and "
            "`check_accuracy_gate` (Legacy + None ok, Legacy + Some refused).  (4) `unhashed` / `of_block`: None at "
            "a legacy block (`blk.accuracy().map(..)`); `of_block`'s act digest and silu member are the legacy "
            "ones when `blk.accuracy()` is None.  (5) `check_self`: `check_accuracy_gate` per layer and the SiLU "
            "member check unchanged at Legacy.  (6) `encode`: `accuracy-gate-layer` ONLY `if let Some(g)` -- absent "
            "at every legacy record, so the canonical bytes and `identity()` of every old statement are R12b's.  "
            "(7) a `#[cfg(test)]` module",
            cls=GATED, diff=_D + "nat-r12b-r13-trained_statement.rs.diff"),
    },
    TBK: {
        TRAINED_BLOCK_R13: _r(TRAINED_BLOCK_R12B, "+126 / -39, 35 hunks against e2551aa1 (native R12b)",
            "The export reader / CLI bridge.  `ACCURACY_PROFILE_SCHEMA` (/2); `load` admits /1 (refusing an "
            "`accuracy_stack` key) or /2; `TrainedExport.accuracy_stack` (Legacy at /1) and `accuracy_dd`; "
            "`run_profile()` = `geometry.run_profile()` at Legacy (`trained_accuracy::profile_for` has no Legacy arm "
            "and errs); `constants_for_stack` / `table_keys_for_registry` (Legacy: the old functions' checks); "
            "`shape_for` (Legacy: the old `geometry.shape_at`); `load_layer`: a legacy export carrying an R13 array "
            "is refused, the act table read and checked as before, `FeedForwardPublic` built from `gact` (checked "
            "equal to the exported act above, so the same words), the accuracy data attached only off Legacy, "
            "`record.accuracy_gate_shift` None at Legacy; `witness_for_block` (Legacy: `build_shaped`); the "
            "stack's `ssh = cur.record.shape_at(&sh)` (Legacy: the old expression) and the layout cache keyed by "
            "the whole shape (the same layouts); the statement JSON's layer line adds `accuracy_gate_shift` only "
            "when Some; the CLI fresh-verifier control `a witness honest under norm_cn_m + 7` builds its "
            "counterfactual via `sh.with_layer_calibration` instead of `geometry.shape_at` (a control's "
            "counterfactual witness, never a receipt byte; REVIEW_R13 R13-F1 concerns these controls); `--dd` via "
            "`enable_dd()` (Legacy: the old `geometry.dd()`).  No receipt, stage, statement-identity or capture "
            "byte of an old geometry moves",
            cls=GATED, diff=_D + "nat-r12b-r13-trained_block.rs.diff"),
    },
    PBR: {
        PRIVATE_BLOCK_R13: _r(PRIVATE_BLOCK_R12B, "+62 / -1, 4 hunks against b4f73a05 (native R12b)",
            "(1) the nine R13 modules and three `#[cfg(test)]` test modules declared.  (2) `BlockPublic.accuracy: "
            "Option<AccuracyPublic>` (None from `new`), `with_accuracy`, `accuracy()`, `check_accuracy_for_shape` "
            "(refuses at Legacy).  (3) `check_for_shape`: off Legacy the R13 check; at Legacy the old checks plus a "
            "refusal of attached accuracy data.  (4) `digest()`: the R13 encoding absorbed ONLY `if let Some`, so "
            "every legacy block digest is R12b's.  `ExpectedIo`, `IoSpec`, `calibration_identity` and every "
            "absorbed word are outside the hunks",
            cls=GATED, diff=_D + "nat-r12b-r13-_private_block.rs.diff"),
    },
    RUN: {
        RUN_R13: _r(RUN_R12B, "+71 / -12, 11 hunks against 5c9f0ffc (native R12b)",
            "(1) the twelve R13 run-profile strings, `ACCURACY_RUN_PROFILES`, `accuracy_run_profile`.  (2) "
            "`registered_block_shape`: an R13 arm first (only for those strings).  (3) `RunShape::accuracy`.  (4) "
            "`RunStatement.stage_accuracy_gate` (zeros, unused at Legacy).  (5) `new_bound`: `blocks_fit_the_shape` "
            "only at Legacy (the old call), the per-stage `check_for_shape` only off Legacy.  (6) "
            "`new_bound_from_digests`: `r.check_accuracy_gate` (None at every legacy record) and the G recorded "
            "when Some.  (7) `stage_shape`: the old value at Legacy.  (8) the `fit_the_stages` default method "
            "(Legacy: `self.fit_the_shape(&st.rs.sh)`, the old call), called by prove / verify in place of "
            "`fit_the_shape(sh)`.  The header, stage order, boundary absorb, position tags, opening order, "
            "`capture_header` and the commitment row list are outside the hunks",
            cls=GATED, diff=_D + "nat-r12b-r13-run.rs.diff"),
    },
    RCP: {
        RUN_CAPTURE_R13: _r(RUN_CAPTURE_R12B, "+15 / -1, 2 hunks against 8721e83d (native R12b)",
            "TEST-ONLY module.  `OWN_SOURCE_FILES` [20] -> [32]: four R13 modules prepended (argument_accuracy, "
            "accuracy_act, accuracy_fold, accuracy_layout) and eight appended (accuracy, accuracy_aligned, "
            "accuracy_groups, accuracy_precision, accuracy_public, accuracy_tables, trained_accuracy, "
            "witness_accuracy).  Capture metadata only.  NOTE (R19-PIN-1): no R13 support was added to the "
            "recorder or to plane_index.rs",
            cls=TEST, diff=_D + "nat-r12b-r13-run_capture.rs.diff"),
    },
    TTB: {
        TIED_TABLES_R13: _r(TIED_TABLES_R12B, "+2 / -0, 1 hunk against 901fa1e4 (native R12b)",
            "`pub(crate) use derive::{bf16, norm, quantize};` with a comment: native R13 carries the token lane's "
            "R-C2 re-export (frozen-r14's 049ddc18 has the same line with another comment).  No body",
            cls=IDENT, diff=_D + "nat-r12b-r13-tied_tables.rs.diff"),
    },
    # DRV: native R13's derive.rs IS token frozen-r14's 5cebeef0 (Sol carried the three visibility words),
    # already read in tools v21 (zk60_native_rg_tinyllama_r12b_pins DERIVE_T14 against DERIVE_R12B)
}

# file -> new digest -> its reading (token frozen-r14 -> r15 -> r16 -> r16b; each against the previous digest)
TOKEN_R16B_READINGS = {
    RCP: {
        RUN_CAPTURE_T15: _r(RUN_CAPTURE_T14, "+15 / -2, 3 hunks against ef9c54db (token frozen-r14)",
            "TEST-ONLY.  F18-1 (gate round 18): the token-run and classifier-run writers list "
            "`sh.slots().iter().take(N_SLOTS)` (23 triples; rounds 7-14 wrote MAX_SLOTS = 24 with an all-zero 24th), "
            "with the reader contract's doc comment.  Capture metadata only (run.json's `shape.slots`); no "
            "receipt byte, no allow-list entry, no replay check",
            cls=TEST, diff=_D + "tok-r14-r15-run_capture.rs.diff"),
        RUN_CAPTURE_T16: _r(RUN_CAPTURE_T15, "+15 / -1, 2 hunks against 527df40e (token frozen-r15)",
            "TEST-ONLY.  The rebase's carry of native R12b -> R13's two hunks (the twelve accuracy modules in "
            "`OWN_SOURCE_FILES`, [26] -> [38], R13's 32 in front order as native, N-r13-6) [COUNTED: the added "
            "lines equal native's; ALLOWED_KEYS identical r14 -> r16b; `write_run_classify`, `ClassifyFacts` and "
            "every writer path unchanged].  r16 -> r16b: the same bytes",
            cls=TEST, diff=_D + "tok-r15-r16-run_capture.rs.diff"),
    },
    TIO: {
        TOKEN_IO_T15: _r(TOKEN_IO_T14, "+3 / -0, 1 hunk against eda64c31 (token frozen-r14)",
            "TEST-ONLY: `#[cfg(test)] mod classify_r15_tests;` with its comment",
            cls=TEST, diff=_D + "tok-r14-r15-token_io.rs.diff"),
        TOKEN_IO_T16: _r(TOKEN_IO_T15, "+3 / -0, 1 hunk against 3808d844 (token frozen-r15)",
            "TEST-ONLY: `#[cfg(test)] mod classify_r16_tests;` with its comment (r16b registers its test module by "
            "a #[path] line inside classify_r16_tests.rs, so token_io.rs keeps 2aabe64f)",
            cls=TEST, diff=_D + "tok-r15-r16-token_io.rs.diff"),
    },
    RUN: {
        RUN_T16: _r(RUN_T14, "+133 / -13, 13 hunks against 51e8aed2 (token frozen-r14); = native R13 66f0ac95 + the "
                    "token lane's hunks (+123 / -0 against native R13)",
            "[COUNTED with diff -U0] exactly (a) native R12b -> R13's eleven hunks (+71 / -12, NATIVE_R13_READINGS), "
            "(b) the token lane's r14 hunks over R12b carried verbatim (61 of 62 lines; the 62nd, "
            "`CLASSIFY_RUN_PROFILES: [&str; 1]`, replaced), and (c) round 16 (+62 / -1): "
            "`RUN_PROFILE_CLASSIFY_R13_SHIELD_T128 / _T256`, `ACCURACY_CLASSIFY_RUN_PROFILES`, `CLASSIFY_RUN_PROFILES` "
            "[1] -> [3], `accuracy_classify_run_profile`, the `#[cfg(test)]` "
            "`RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST`, `is_classify_run_profile`, `is_r13_classify_run_profile`, two "
            "`registered_block_shape` arms before the old match (the R13 classifier profiles; the test rung), and "
            "the blocks-only refusal of an R13 classifier run profile.  Every arm of an old profile, the header, "
            "stage order and capture header are unchanged: the legacy classifier rung, token and block profiles "
            "build what they built",
            cls=GATED, diff=_D + "tok-r14-r16b-run.rs.diff"),
    },
    PBR: {
        PRIVATE_BLOCK_T16: _r(PRIVATE_BLOCK_T14, "+62 / -1, 4 hunks against 29540958 (token frozen-r14)",
            "[COUNTED] exactly native R12b -> R13's four hunks (+62 / -1, NATIVE_R13_READINGS); the token lane's one "
            "hunk (the token / classifier CLI bridges and `mod token_io`, +10) is byte-identical at r14 over R12b "
            "and at r16b over R13",
            cls=GATED, diff=_D + "tok-r14-r16b-_private_block.rs.diff"),
    },
    TBK: {
        TRAINED_BLOCK_T16: _r(TRAINED_BLOCK_T14, "+167 / -43, 38 hunks against f892dbc7 (token frozen-r14); = native "
                              "R13 4ee6dccb + the token lane's hunks (+51 / -14 against native R13)",
            "[COUNTED] (a) native R12b -> R13's hunks (+126 / -39); (b) the token lane's ten visibility words carried "
            "(+10 / -10, as at r14); (c) round 16's N-r13-5 (+41 / -4): `tied_of` delegates to "
            "`tied_of_with_derivation` (its `(None, None)` early return first, so an untied export -- every legacy "
            "export -- returns `(None, None)` before reading anything), `TiedDerivation`, "
            "`declared_classifier_margin`, the derivation with the margin row only at a tied export naming "
            "`classifier_margin_parameters` (the row-less pass decides on a refusal), "
            "`TrainedExport.tied_derivation`.  No receipt, statement-identity or capture byte of an old geometry "
            "moves",
            cls=GATED, diff=_D + "tok-r14-r16b-trained_block.rs.diff"),
    },
    TTB: {
        TIED_TABLES_T16: _r(TIED_TABLES_T14, "+3 / -1, 1 hunk against 049ddc18 (token frozen-r14)",
            "The R-C2 re-export now native (another comment line), plus round 16's `pub(crate) use "
            "derive::recompute_declared_tied_tables_with_margin;`.  No body",
            cls=GATED, diff=_D + "tok-r14-r16b-tied_tables.rs.diff"),
    },
    DRV: {
        DERIVE_T16: _r(DERIVE_T14, "+10 / -1, 1 hunk against 5cebeef0 (token frozen-r14 = native R13)",
            "N-r13-5: `recompute_declared_tied_tables(export, expected)` becomes "
            "`recompute_declared_tied_tables_with_margin(export, expected, None)`, the old body with `margin` passed "
            "through (`None` = the old call `recompute_profile(.., None)`).  Reached only at a tied (Shieldstral) "
            "export; SHA-256 over model / table files, no proof transcript",
            cls=GATED, diff=_D + "tok-r14-r16b-tied_tables_derive.rs.diff"),
    },
    TRUN: {
        TOKEN_RUN_T16: _r(TOKEN_RUN_T14, "+42 / -3, 2 hunks against 477cfc8c (token frozen-r14)",
            "`R13_MAX_SILU_GROUPS` = 4 and `r13_block_logup_numerator(sh)` (None at Legacy: `N + 4 T_d - 1` with "
            "T_d = 512 + 4096 G (+ |Dd|) off Legacy); `whole_run_of`: the legacy branch is the old code "
            "(`lk.extend(vec![block_logup_size(sh); l])`, the same sum in the same order); no R13 token run "
            "profile is registered",
            cls=GATED, diff=_D + "tok-r14-r16b-token_io_run.rs.diff"),
    },
    TLOAD: {
        LOAD_T16: _r(LOAD_T14, "+13 / -2, 2 hunks against a9b72811 (token frozen-r14)",
            "`ExportPublic::load` = `load_with(export, token_run_profile_of)` (the old body); the trained statement "
            "is built `new_with_tied(.., ex.tied.clone())` (None at every untied export = `new`, so no legacy "
            "identity moves)",
            cls=IDENT, diff=_D + "tok-r14-r16b-token_io_load.rs.diff"),
    },
    CLS: {
        CLASSIFY_T16: _r(CLASSIFY_T14, "+208 / -14, 13 hunks against 6c828db6 (token frozen-r14 = r15)",
            "Round 16.  NEW: the three D37 moderate category policies (`policy_shieldstral_moderate_{sexual, "
            "violence,hate}`, ids `shieldstral-1.0-3b-moderate-*/1`, prefixes 72 / 72 / 78 ids = "
            "CATEGORY_TEMPLATE_HEAD (58) + the query (7 / 7 / 13) + TAIL (7), suffix [4], num_special 1000, yes 13059, "
            "no 2649, c 0, V 131072, pad 11, margin_scale_bits = 4.08288030735373e-6 = 0x3ed11ff597db2fb6) and "
            "`shieldstral_category_policies()`; `registered_policies` = [rung dev, CARD, the three] (r16); "
            "`CHUNK_OVERLAPS` [1] -> [3] (the rung's 4 kept; 8 at both R13 Shieldstral profiles); "
            "`chunk_overlap_of` 4 at the test rung (cfg(test)); `ClassifyRunStatement.stage_gate` from "
            "`LayerRecord::check_accuracy_gate` / `accuracy_gate_shift` (None at Legacy), every stage shape built "
            "at construction, `stage_shape(k)` (Legacy: the old value, refusing a legacy stage carrying a G; R13: "
            "`with_accuracy_gate_shift(G_k)`), `stage_gate(k)`; the stage line appends `; R13 gate denominator {g} "
            "(the layer record's accuracy-gate-layer)` ONLY when Some (legacy stage lines byte for byte); "
            "`whole_run_of_classifier` adds `r13_block_logup_numerator` off Legacy (the legacy branch is the old "
            "code); `new_chunk` admits `is_classify_run_profile` (the old list + the R13 profiles + the test rung).  "
            "TEST-ONLY: `registered_classify_runs` / `r13_census_calibration` / `r13_synthetic_model` / "
            "`census_classify_statement`; `ctl_q`'s comment.  `describe_under` (the profile text), `kappa`, "
            "`is_template`, `chunk_ranges`, the door, `parameter_line`, `schedule_digest` and the statement schema "
            "(`zk60-classify-run/3`, classify_cli.rs) are outside the hunks.  The policy LIST is not encoded in any "
            "statement (each statement names its own policy), so at the legacy classifier rung no receipt or "
            "statement byte moves",
            cls=GATED, diff=_D + "tok-r14-r16-token_io_classify.rs.diff"),
        CLASSIFY_T16B: _r(CLASSIFY_T16, "+21 / -7, 2 hunks against c23074e9 (token frozen-r16)",
            "Round 16b (REVIEW_R16 F-1): `policy_shieldstral_card` becomes `#[cfg(test)]` with a corrected doc "
            "comment; `registered_policies()` = [policy_rung_dev()] + the D37 category list (+ test policies in test "
            "builds).  The three moderate policies' constructor, constants and ids are untouched; no statement "
            "byte moves (the r16b freeze note: the real violence receipt re-verifies, identity 29aeba6c...)",
            cls=GATED, diff=_D + "tok-r16-r16b-token_io_classify.rs.diff"),
    },
    CTD: {
        CLASSIFY_TIED_T16: _r(CLASSIFY_TIED_T14, "+39 / -3, 6 hunks against 401d38d4 (token frozen-r14 = r15)",
            "`TiedSource::of` / `of_run_profile`: a `#[cfg(test)]` arm for the R13 rung (DevRung) and the R13 "
            "Shieldstral classifier run profiles -> Shieldstral; N-r13-5: `recompute_tied_classifier` = "
            "`recompute_tied_classifier_pre(.., None)` (the old body), the Shieldstral path reuses a `pre` derivation "
            "only when its margin equals the bound profile's (yes, no, scale bits); `load_bound_tables` = "
            "`load_bound_tables_pre(.., None)`; `load_tied_classifier_tables` passes the export's derivation.  "
            "`derive_dev`, `dev_tied_tensor_bytes`, `DEV_TIED_TENSOR_SHA256` and `TiedSource::describe` are outside "
            "the hunks (what zk60_native_rg_classtied transcribes)",
            cls=GATED, diff=_D + "tok-r14-r16b-token_io_classify_tied.rs.diff"),
    },
    CRN: {
        CLASSIFY_RUN_T16: _r(CLASSIFY_RUN_T14, "+15 / -1, 2 hunks against 5d1d077f (token frozen-r14 = r15)",
            "(1) the verifier's pre-header stage pass: ONLY off Legacy, every block checked against its own stage "
            "shape and digest (`stage_block_is_the_statements`) before the run header (native R13's "
            "`fit_the_stages`); (2) the honest pipeline builds each block with `witness::build_for_block` (Legacy: "
            "the block-shape check then the frozen `build_shaped`, the same planes; prover-side only).  The "
            "transcript, stage order, openings and boundary wrapping are outside the hunks",
            cls=GATED, diff=_D + "tok-r14-r16b-token_io_classify_run.rs.diff"),
    },
}

# [v24, gate round 24] file -> new digest -> its reading (token frozen-r17 -> r18 -> r19 -> r19b; each against
# the previous digest; READ 2026-10-30 from 15:46 UTC with `diff -u` over the frozen copies, the derive.rs
# production text also compared with comment lines dropped: round24/READINGS_R24.json)
_P24 = "[GATE ROUND 24, token frozen-r18 / r19 / r19b] "
_D24 = "results/zk60_gate_tinyllama_20261017/round24/readings/"
REEXPORT = "re-export-only"


def _r24(base, stat, reading, cls, diff):
    return {"base": base, "diff_stat": stat, "moves_a_receipt_byte": False, "moves_a_block_stage_byte": False,
            "classification": cls, "diff_file": diff, "reading": _P24 + reading}


TOKEN_R19B_READINGS = {
    PBR: {
        PRIVATE_BLOCK_T18: _r24(PRIVATE_BLOCK_T16, "+1 / -1, 1 hunk against 2af1df7d (token frozen-r17 = r16b)",
            "Token round 18 (A5 one-load batch): the classifier CLI bridge's `pub use token_io::classify_cli::{..}` "
            "(:142) names one more function, `classify_prove_batch_command` (the `prove-batch` subcommand of "
            "examples/zk60_classify.rs).  A re-export only: no item, constant, module declaration, `ExpectedIo` / "
            "`IoSpec` / `calibration_identity` byte or absorbed word moves (the run header absorbs "
            "`expected.to_bytes()`, not this text); every other line is byte-identical.  r18 -> r19 -> r19b: the "
            "same bytes (96c1cd16 in all three)",
            REEXPORT, _D24 + "tok-r17-r18-private_block.rs.diff"),
    },
    DRV: {
        DERIVE_T19: _r24(DERIVE_T16, "+97 / -3, 3 hunks against c5bec3c6 (token frozen-r18 = r17 = r16b)",
            "Token round 19, E7 (open release): the absolute `DEFAULT_CHECKPOINT` (r18 :10) is replaced by "
            "`CHECKPOINT_IN_MODELS` (the relative place below a models directory) and `default_checkpoint` / "
            "`default_checkpoint_from` (`$ZK60_MODELS/<place>` when ZK60_MODELS is set and non-empty, else "
            "`$HOME/models/<place>` when HOME is set and non-empty, else refused) and `checkpoint_path_with` (a "
            "declared `tied_embeddings.checkpoint_file` wins and the default is evaluated only without one; a "
            "non-string declaration is refused; an EMPTY declared string becomes the empty path, which "
            "`Checkpoint::open` -> `regular` refuses); the one call site in `recompute_profile` uses them "
            "(r19 :282-283).  The production text with comment lines dropped differs from r18 in exactly those "
            "lines (3 removed, 20 added: 230 -> 247 lines r16b -> r19b, round24/READINGS_R24.json): `Checkpoint::open` (size, header, extents, no "
            "LM head, the WHOLE file's SHA-256 against the compiled-in model pin), `rotate`, `quantize`, the "
            "consumed-tensor pin and the margin row are unchanged; no absorb, no transcript, no BLAKE3 "
            "(`Sha256::new(` 5 -> 5).  So only WHERE the file is read from moves, never what is accepted "
            "(REVIEW_R19 §2).  Reached only at a tied (Shieldstral) export; no receipt, block-stage or statement "
            "byte moves at any profile (REVIEW_R19 §3: r19's job-0 receipt = r18's on 30 / 30 files).  Three "
            "`#[cfg(test)]` E7 tests.  Mirrored by the gate in zk60_native_rg_classtied v24 "
            "(`shield_default_checkpoint` / `shield_checkpoint_path`)",
            GATED, _D24 + "tok-r18-r19-derive.rs.diff"),
        DERIVE_T19B: _r24(DERIVE_T19, "+136 / -0, 2 hunks against 4b53222b (token frozen-r19)",
            "Token round 19b: R19-3's 22 `///` lines on `default_checkpoint` (a symlinked model FILE is refused, "
            "symlinked directories are followed; a relative ZK60_MODELS resolves against the working directory; "
            "HOME unset and no ZK60_MODELS is refused; a set ZK60_MODELS naming a missing file never falls back), "
            "and R19-1's two `#[cfg(test)]` tests (a same-size sparse wrong file refused by the whole-file pin at "
            ":216; a symlinked model file refused by `regular`).  Production text with comment lines dropped: "
            "byte-identical to r19 (REVIEW_R19B §4)",
            GATED, _D24 + "tok-r19-r19b-derive.rs.diff"),
    },
}

# the twelve NEW R13 modules: first readings (base None), at the r16b digest
_NEW_TEXT = {
    "argument_accuracy": "the R13 relations of the SEVEN redefined slots (`define_changed`: SC_DZC, SC_FZC, "
        "SC_QZC / SC_KVZC, SC_SZC (+ its DD twin), SC_DD, SC_TAB), each calling "
        "`data.check_for_registry` and checking the common G first; reached ONLY from `argument::define` behind "
        "`accuracy_stack() != Legacy`",
    "accuracy_act": "ACT3: `table` (4096 G verifier-derived rows i + beta T_g[i] + beta^2 g + tag, pad rows = "
        "the (2048 + tag) zero tuple with support 0), `group_column` (public gid per F position), `query_values`, "
        "`histogram`; reached only under `blk.accuracy() = Some` (protocol.rs) and the R13 FZC / TAB relations",
    "accuracy_fold": "the multiplier folds (`Site`, `Axis`, `coefficients`, `fold`: the multipliers folded at "
        "Boolean output channels into the public matrix; refuses -128 weights); reached only off Legacy in the "
        "matmul arms of argument.rs",
    "accuracy_layout": "`Limbs`, `AccuracyIds` (the R13 A plane list, its NAMES, the limb groups) and `lookups` "
        "(byte and exact top-bit pins per domain, the Rg top pin at the stage's G); reached only from "
        "`Ids::new` / `lookups_at` off Legacy",
    "accuracy": "R13 profile helpers (the module root of the accuracy family); no legacy caller",
    "accuracy_aligned": "the aligned (group-scaled) product coefficients and `a_scaled`; called by the R13 "
        "public data / witness only",
    "accuracy_groups": "SiLU groups: the common denominator G = max(s_j, 17) <= 24, c_j = m_j 2^(G - s_j); R13 "
        "only",
    "accuracy_precision": "`Stack` {Legacy, Low, LowH24}, `BaseShifts`, `Precision`, `derive` (the R13 shifts "
        "and windows); `Stack::Legacy` is what every legacy shape reports",
    "accuracy_public": "`AccuracyPublic` (multipliers, groups, group ids, raw / scaled tables, folds, encode for "
        "the block digest), `check_for_registry`; constructed only by the R13 export loader and tests",
    "accuracy_tables": "`Registry` {Standard, Shieldstral} (the (0, -8) member only at Shieldstral), "
        "`silu_table`; R13 only (`Registry::permits` is called at Legacy only through the R13 branches)",
    "trained_accuracy": "the schema-/2 export reader (`profile_for` has NO Legacy arm, so a legacy export "
        "falls back to the old run profile; `load_for_registry`); token r16b's copy differs from native R13's "
        "only in the `#[cfg(test)]` fixture path (HL_R13_LOADER_FIXTURES), diff nat-r13-tok-r16b-trained_accuracy.rs.diff",
    "witness_accuracy": "the R13 witness builder (`build`, `assign`), reached only from `witness::build_accuracy` "
        "/ `build_for_block` off Legacy",
}
NEW_R13_READINGS = {
    f: {_r16b_digest_of_new(f): _r(None, "NEW at native R13 (read in full for the gate's purpose: entry points and "
                                       "their callers)", _NEW_TEXT[n], cls=NEWF,
                                   diff=(_D + "nat-r13-tok-r16b-trained_accuracy.rs.diff") if n == "trained_accuracy" else "")}
    for n, f in ACC.items()
}
# the native R13 digest of trained_accuracy.rs too (a native capture would pin it)
NEW_R13_READINGS[ACC["trained_accuracy"]][NEW_R13_DIGESTS[ACC["trained_accuracy"]][0]] = _r(
    None, "NEW at native R13", _NEW_TEXT["trained_accuracy"], cls=NEWF)

# the classifier files a v22 port must transcribe (the v21 rule: accepted only at a port digest, never by chain)
CLASSIFY_PORTED_FROM_V22_SUGGESTED = {
    CLS: CLASSIFY_T16B, CRN: CLASSIFY_RUN_T16,
    "src/private_block/token_io/stage_in_c.rs": "6a92da0ecfe736537f859bcde5eb3fb89c0852e8d06dfe7f21e0feb9c4bbe6ff",   # unchanged r14 -> r16b
    "src/private_block/token_io/stage_out_c.rs": "93a79a2b39ab1eb70442b6ee7f0d949cfbf20f7c84b660ec4aa4ebe2ef7a564a",  # unchanged r14 -> r16b
    CTD: CLASSIFY_TIED_T16,
}

CLASSIFIER_LEVEL_CHANGES = [
    "policies (D45(2)): production list at r16b = [rung dev (V 300), moderate-sexual/1, moderate-violence/1, "
    "moderate-hate/1]; the card policy is #[cfg(test)] (r16 admitted it at both R13 Shieldstral profiles: "
    "REVIEW_R16 F-1); P0 72 / 72 / 78, suffix [4], num_special 1000, yes 13059, no 2649, c 0, pad 11, V 131072, "
    "margin_scale_bits 0x3ed11ff597db2fb6 (4.08288030735373e-6); chunk size T - P0 - S = 55 / 55 / 49 at T128, "
    "183 / 183 / 177 at T256; overlap 8 at both Shieldstral profiles, 4 at the rung and the test rung",
    "run profiles: hashline-zk-mr1/private-classify-run-shieldstral-3b-t{128,256}-r13-public-row/1 (CS-7 over "
    "R13_SHIELD_T{128,256}_H24), test-only hashline-zk-mr1/private-classify-run-rung-lh-t32-public-row-tst/1 "
    "(over R13_RUNG_H24, tied source DevRung)",
    "stage_shape(k): at R13 the seed shape (G 17) with_accuracy_gate_shift(G_k) from the layer record; the "
    "stage line gains '; R13 gate denominator {G_k} (the layer record's accuracy-gate-layer)'; the model "
    "identity encodes accuracy-gate-layer per R13 layer",
    "the run header's layout_description and the schedule digest use Layout::for_shape(SEED shape): the "
    "calibration line 'calibration: R13 stack=LowH24 registry=... gate-common=17 precision=...' names the "
    "SEED's G, never a stage's; the per-stage G is visible only in the stage lines (and the identity)",
    "the verifier's pre-header stage pass (R13 only): every block against its own stage shape before the "
    "header (no transcript byte; one more block-load pass)",
    "whole-run figure: off Legacy the block term is l * (N + 4 T_d - 1) with T_d = 512 + 4096 * 4 (+|Dd|), "
    "stage OUT-C's legacy (N + 3R - 1); T128 floor 96, T256 floor 95 (r16b tests pin them); the parameter "
    "line's whole-run-floor-{b}-bits-{openings} moves with it",
    "N-r13-5: one checkpoint stream per command; the tied derivation reused only at the bound (yes, no, "
    "scale bits)",
    "NO change: the classify statement schema zk60-classify-run/3 (classify_cli.rs:110), the profile text "
    "format (describe_under), kappa / is_template / chunk_ranges, stage_in_c.rs / stage_out_c.rs (6a92da0e / "
    "93a79a2b), run_capture's ALLOWED_KEYS (identical r14 -> r16b), ClassifyFacts and write_run_classify "
    "(run.json's `classify` keys), CLASSIFY_SOURCE_FILES [5] (classify.rs, classify_tied.rs, "
    "classify_run.rs, stage_in_c.rs, stage_out_c.rs)",
    "capture metadata: OWN_SOURCE_FILES 38 (twelve R13 modules: 4 first, 8 last), so an r16b bundle carries "
    "60 + 12 = 72 source pins (CORE/SHARED unchanged); F18-1: run.json shape.slots has exactly 23 triples",
    "run.json's `shape` object has NO accuracy field (no stack, registry or G: run_capture.rs:2743-2787); an "
    "R13 capture shows R13 only through block_profile / shape.profile, layout_description, the stage lines and "
    "the parameter line",
]

ANYTHING_THAT_MOVES_A_RECEIPT_BYTE: list = []   # none at the previously captured profiles

OPEN_QUESTIONS = [
    "R19-PIN-1 (capture blocker, [READ]): plane_index.rs (13a7dd6f, #[cfg(test)], unchanged since R12b) names "
    "A planes with the LEGACY segment table (79 names at an R13 shape with limbs_norm forced to 3, limbs_p 2, "
    "limbs_sigma_s 3; 77 at ls 2) while Ids at an R13 shape is AccuracyIds (109 A planes at LOW+h24 non-DD, ls 3, "
    "107 at ls 2: T 4, Ht 2, "
    "L 2, D 39, Q 14, Kv 14, S 15, F 16, Tab 3).  `plane_index::build` refuses on the count, and run_capture's "
    "recorder fails every R13 block stage ('replay: the plane index does not build at stage k', "
    "run_capture.rs:981 / 1137 / 1277).  Even with R13 names, its hand-written legacy push order differs from "
    "the R13 definitions: SC_DZC (legacy range A_X..A_RDL; R13 pushes the whole D domain X..X2L1, whose order "
    "is ...Z, ZL, RDL x3, X2, X2L), and SC_FZC at LOW (A_RH1 is not the last RH limb).  No R13-stack bundle can be "
    "written by frozen-r16b's recorder; an R13 plane-index port (AccuracyIds.names exists, accuracy_layout.rs) "
    "is needed in the gate's capture tree (a test-only module, but a SOURCE PIN) or by the token / native lane.",
    "run.json carries no accuracy fields; the port must read each block stage's G from the stage lines "
    "('R13 gate denominator G') or the trained statement, and the seed G (17) from layout_description.",
    "The redefined R13 slots draw in a different ORDER from the legacy ports' assumption (tau first): SC_DZC, "
    "SC_FZC, SC_QZC / SC_KVZC draw mu, nu, zeta and THEN tau (argument_accuracy.rs dzc / fzc / qzc); SC_SZC "
    "(R13) draws tau, mu, nu, zeta; SC_TAB tau, mu, zeta; SC_DD tau, mu.",
    "frozen-r16b is UNREVIEWED by its freeze note (the r16b check is to follow); R19_BUNDLES is empty until the "
    "parent captures.",
    "native R13's derive.rs (5cebeef0) equals token frozen-r14's, already read in v21 (DERIVE_T14).",
    "Not pinned, so read only for context: classify_cli.rs t14 c1862e4b -> t15 8eddafc9 -> t16 = t16b b3b661b5 "
    "(round 15's label --expect-total; round 16's R13 export loading, build_for_block and stage shapes); its "
    "statement schema stays zk60-classify-run/3.",
]

MOVES_ONLY_OUTSIDE_THE_CAPTURED_PROFILES = [
    "NEW profiles only: the twelve R13 block / run profiles, the two R13 Shieldstral classifier run profiles "
    "and the test-only R13 rung classifier profile; their shapes (AccuracyIds plane lists, R13 lookups, the "
    "seven redefined slot relations, multiplier folds in the matmul public tables, the group column, the ACT3 "
    "table), the schema-/2 export, the per-layer G in records / identities / stage lines, the R13 whole-run "
    "term, the moderate policies and the N-r13-5 derivation reuse.",
]

CAPTURE_METADATA_CHANGES = [
    "every bundle's source_pins: + the twelve R13 accuracy modules (OWN_SOURCE_FILES 26 -> 38)",
    "run.json's shape.slots: exactly n_slots = 23 triples (F18-1, token round 15)",
]


# ---------------------------------------------------------------- self-checks
def _all_readings():
    out = {}
    for table in (NATIVE_R13_READINGS, TOKEN_R16B_READINGS, NEW_R13_READINGS, TOKEN_R19B_READINGS):   # [v24] + r19b
        for f, rd in table.items():
            out.setdefault(f, {}).update(rd)
    return out


def chain(file: str, digest: str) -> list:
    """the digests from `digest` back along `base` links through this module's readings"""
    allr = _all_readings()
    out, cur = [digest], digest
    for _ in range(10):
        r = allr.get(file, {}).get(cur)
        if r is None:
            break
        cur = r["base"]
        out.append(cur)
        if cur is None:
            break
    return out


def _sha(path):
    try:
        with open(path, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    except FileNotFoundError:
        return None


def self_check(rehash: bool = True) -> dict:
    """every terminal digest chains to a v21-read digest (or to a NEW file's first reading); every digest is 64
    hex; no reading moves a byte; and (rehash) every digest named re-hashes against its frozen copy"""
    bad, hashed = [], 0
    hexd = set("0123456789abcdef")
    for f, table in _all_readings().items():
        for d, r in table.items():
            for x in (d, r["base"]):
                if x is not None and (len(x) != 64 or set(x) - hexd):
                    bad.append(f"{f}: digest {x!r} is not 64 hex")
            if r["moves_a_receipt_byte"] or r["moves_a_block_stage_byte"]:
                bad.append(f"{f}: {d[:8]} moves a byte")
    for name, terms in (("token r16b", TOKEN_R16B_DIGESTS), ("native r13", NATIVE_R13_DIGESTS),
                        ("token r19b", TOKEN_R19B_DIGESTS)):          # [v24] + the r19b terminals
        for f, d in terms.items():
            c = chain(f, d)
            roots = CHAIN_ROOTS[f] if isinstance(CHAIN_ROOTS[f], tuple) else (CHAIN_ROOTS[f],)
            if f == DRV and name == "native r13" and d == DERIVE_T14:
                continue   # read in v21
            if f == RCP and name == "token r19b":
                continue   # [v24] cce0fc2a is read in zk60_native_rg_classpins.TOKEN_R17_READINGS (its r19b_self_check)
            if c[-1] not in roots:
                bad.append(f"{name} {f}: chain {[x[:8] if x else x for x in c]} does not reach {roots}")
    if rehash:
        trees = {"t16b": TOKEN_R16B_TREE, "n13": NATIVE_R13_TREE, "t19b": TOKEN_R19B_TREE}
        for tag, terms in (("t16b", TOKEN_R16B_DIGESTS), ("n13", NATIVE_R13_DIGESTS), ("t19b", TOKEN_R19B_DIGESTS)):
            for f, d in terms.items():
                got = _sha(os.path.join(_ROOT, trees[tag], f))
                hashed += 1
                if got != d:
                    bad.append(f"{tag} {f}: re-hashed {str(got)[:12]}, the module says {d[:12]}")
        for f, rd in _all_readings().items():
            for d, r in rd.items():
                for x in (d, r["base"]):
                    if x is None:
                        continue
                    found = False
                    for t in (NATIVE_R12B_TREE, NATIVE_R13_TREE, TOKEN_R14_TREE, TOKEN_R15_TREE, TOKEN_R16_TREE, TOKEN_R16B_TREE,
                              TOKEN_R17_TREE, TOKEN_R18_TREE, TOKEN_R19_TREE, TOKEN_R19B_TREE):   # [v24] + r17 .. r19b
                        if _sha(os.path.join(_ROOT, t, f)) == x:
                            found = True
                            break
                    hashed += 1
                    if not found:
                        bad.append(f"{f}: {x[:12]} is in no frozen tree read here")
        man = os.path.join(_ROOT, TOKEN_R16B_MANIFEST)
        try:
            with open(man, "rb") as fh:
                mb = fh.read()
            if hashlib.sha256(mb).hexdigest() != TOKEN_R16B_LIST_SHA256:
                bad.append("manifest_final_r16b.sha256: list digest moved")
            listed = dict((ln.split("  ", 1)[1], ln.split("  ", 1)[0]) for ln in mb.decode().splitlines() if "  " in ln)
            for f, d in TOKEN_R16B_DIGESTS.items():
                if listed.get("hashline/" + f) != d:
                    bad.append(f"manifest_final_r16b: hashline/{f} is {str(listed.get('hashline/' + f))[:12]}")
        except FileNotFoundError:
            bad.append("manifest_final_r16b.sha256 missing")
        # [v24] the r19b terminals against token round 19b's manifest
        man = os.path.join(_ROOT, TOKEN_R19B_MANIFEST)
        try:
            with open(man, "rb") as fh:
                mb = fh.read()
            if hashlib.sha256(mb).hexdigest() != TOKEN_R19B_LIST_SHA256:
                bad.append("manifest_final_r19b.sha256: list digest moved")
            listed = dict((ln.split("  ", 1)[1], ln.split("  ", 1)[0]) for ln in mb.decode().splitlines() if "  " in ln)
            for f, d in TOKEN_R19B_DIGESTS.items():
                if listed.get("hashline/" + f) != d:
                    bad.append(f"manifest_final_r19b: hashline/{f} is {str(listed.get('hashline/' + f))[:12]}")
        except FileNotFoundError:
            bad.append("manifest_final_r19b.sha256 missing")
    return {"ok": not bad, "problems": bad, "digests_rehashed": hashed}


if __name__ == "__main__":
    import json
    print(json.dumps(self_check(), indent=1))
