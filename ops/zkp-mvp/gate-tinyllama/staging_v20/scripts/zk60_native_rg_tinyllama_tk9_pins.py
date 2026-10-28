#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v15, 2026-10-20, gate round 10: the frozen-r9
re-pin] The READING behind the one block-path source pin of the TRAINED BLOCK
bundles captured from the gate's copy of the token lane's FROZEN round-9 tree
("tk9") that the earlier readings do not cover.  Merged at the same
definition site as the R5b, R7 and tk7 readings, one marked line.  No existing
digest or reading changes; the merge refuses a digest that is already present.

THE TREE.  `ops/zkp-mvp/trained-1b-gate-tk9/` is an rsync of
`results/zk60_token_io_r1_20261017/frozen-r9/`: 236 of 236 files equal to
`manifest_final_r9.sha256` (list sha256 b666a991..., = manifest_r9C, the tree
the named token binary b56f1b71... and the CLI-path capture came from).  On
top of it sit the gate's four test-only files, byte-identical to the tk7
copy's (`run_capture.rs` f47e28bf, `run_capture_tests.rs`,
`gr4_trained_tests.rs`, `gr4_token_tests.rs`).  frozen-r9's `run_capture.rs`
and `run_capture_tests.rs` are frozen-r7's bytes, so the patch is the tk7
patch.  Sources manifest:
`results/zk60_gate_tinyllama_20261017/tk9/trained-1b-gate-tk9.sources.v1.sha256`
(597b2204...).

A block bundle written from tk9 pins 52 files, and SIX differ from a tk7
bundle's: `run.rs` and the five token-I/O files round 9 moved.  Each has a
reading in `zk60_native_rg_tokenio_r9_pins.TOKEN_R9_READINGS` (v13; read
pre-freeze on manifest_r9C, which IS frozen-r9: the six digests are equal).
Of the six, the block gate's ports transcribe from ONE: `run.rs`
(RUN_LAYER_PINS, the run-layer port).  The five token files are report-only
on a block bundle, as in tk7: no block-gate port transcribes them, and
`run.rs`, `trained_block.rs` and `shape.rs` make no call into `token_io`.
The capture writer is the tk7 writer (f47e28bf, already read in v11); its
entry is not touched (the merge would refuse it), so its record names the tk7
bundles it was read with.

BOTH HASHES OF `run.rs`: frozen-r7 / tk7 `2c158dc9c22c23e4...` (80,119 B,
blob 23e2efa5) -> frozen-r9 / tk9 `cc2c420498b11427...` (81,468 B, blob
09647b56).  `diff -u`: +16 / -1 in 2 hunks (round 8).  Read below.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

from zk60_native_rg_tokenio_r9_pins import TOKEN_R9_READINGS as _R9

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate-tk9 "
        "(the token lane's frozen round-9 tree b666a991 = frozen-r7 + round 8/9 token-run code, "
        "+ the privacy-gate lane's capture patch and stage-47 module; sources manifest 597b2204)",)
TK9_BUNDLES = ("tinyllama-trained-tk9-capture-dense-l1", "tinyllama-trained-tk9-capture-zero-l1",
               "tinyllama-trained-tk9-capture-dense-l2", "tinyllama-trained-tk9-capture-zero-l2",
               "tinyllama-trained-tk9-capture-dense-l22", "tinyllama-trained-tk9-capture-zero-l22")

RUN_RS_TK7 = "2c158dc9c22c23e46e1fc9b8b1215555880a3e7e8642703cc47d37f24b6116f2"
RUN_RS = "cc2c420498b114273c4e67874c500b0f0fb3a0256e6ccef0a171f438ba0f3226"
assert _R9["src/private_block/run.rs"][RUN_RS]["base"] == RUN_RS_TK7
assert _R9["src/private_block/run.rs"][RUN_RS]["moves_a_block_stage_byte"] is False

# the six pins a tk9 block bundle carries that a tk7 bundle does not
# (frozen-r9's digests, = the v13 readings' keys)
TK9_MOVED_PINS = {
    "src/private_block/run.rs": RUN_RS,
    "src/private_block/token_io.rs": "602597ad50d0978d4ea82385011084e2ff4f3678ecbffedc3f192b69d8fe5d9f",
    "src/private_block/token_io/stage_in.rs": "e4609b1acc8c9306c200321f1e80c13fa9ffdfa2b28e50dce88611b2be12eecd",
    "src/private_block/token_io/run.rs": "4671d03edea02468403066bbc33e0a117f5d3cbe6cfd142110718bb48f7fcfca",
    "src/private_block/token_io/load.rs": "8c0417214a15ed45afafe89a345609dedfd622fe45fb9b007a8782ed4344935e",
    "src/private_block/token_io/cli.rs": "b9079130204b49f5f73d38d8f5d531fcfa388d3a8d57c84ff87142eb57b655e9",
}
for _f, _d in TK9_MOVED_PINS.items():
    assert _d in _R9[_f], _f

RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        RUN_RS: {
            "blob": "09647b5657441d82a0d0945650177d7fe4b5bda1",
            "commits": TREE,
            "bundles": TK9_BUNDLES,
            "bytes": 81468,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs", RUN_RS):
        "[TINYLLAMA PORT v15, gate round 10: the frozen-r9 re-pin] read against "
        "2c158dc9 (frozen-r7 = tk7), `diff -u` +16 / -1 in two hunks (round 8).  "
        "Hunk 1 (after `RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T32`): two new `pub(crate) const` "
        "token-I/O run profile strings, `RUN_PROFILE_TOKEN_IO_TINYLLAMA_T128` and "
        "`RUN_PROFILE_TOKEN_IO_LLAMA3_8B_T128`, with their doc comments, and "
        "`TOKEN_IO_RUN_PROFILES` grown from `[&str; 3]` to `[&str; 5]` by appending them.  "
        "Hunk 2 (`registered_block_shape`): two new arms keyed by those two strings, "
        "`Shape::tinyllama_trained(128, ..)` and `Shape::llama3_8b_trained(128, ..)`.  "
        "On this profile's path: the match is by string equality and the two new strings "
        "differ from every block profile (stage 25's W-2 census), so "
        "`RUN_PROFILE_TINYLLAMA_T32_TRAINED` selects the arm it selected before; "
        "`TOKEN_IO_RUN_PROFILES` is read in two places, `RunStatement::new_bound_from_digests` "
        "(a blocks-only run statement refuses a token-I/O profile: two more strings refused, "
        "none of them a block profile) and `token_io::run` (a token run must carry one).  "
        "The header, `run_shape_words`, the stage order, the boundary absorb, the position "
        "tags, the opening order, `stage_shape`, `stage_cal` and the schedule lines are "
        "outside both hunks and byte-identical, so every block profile builds what it built.  "
        "The token r9 reading (v13), verbatim: " + _R9["src/private_block/run.rs"][RUN_RS]["reading"],
}
