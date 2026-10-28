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
