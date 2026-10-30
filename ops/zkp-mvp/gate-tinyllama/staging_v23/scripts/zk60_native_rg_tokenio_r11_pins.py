#!/usr/bin/env python3
"""[GATE ROUND 15, tools v18, 2026-10-21] The READINGS of the two pinned
files the token lane's ROUND 11 moved relative to frozen-r9
(`results/zk60_token_io_r1_20261017/frozen-r9/`, manifest
`manifest_final_r9.sha256`, list b666a991...), on the frozen round-11 tree
(`results/zk60_token_io_r1_20261017/frozen-r11/`, 237 files =
`manifest_final_r11.sha256`, list d8075d76...), which the named round-11 CPU
binary `cli/zk60_token_io.r11.release.bin` (0c9f247c...) was built from.

READ 2026-10-21 about 00:20 UTC by the privacy gate lane, with `diff -u`
between the two frozen copies.  Round 11 changes four files and adds one:
the example's doc header (`examples/zk60_token_io.rs`, not pinned), the new
`token_io/r11_tests.rs` (`#[cfg(test)]`, not pinned), `token_io/cli_tests.rs`
(not pinned), and the two PINNED files read here.  No block or run file
changed since frozen-r9.

Each reading's `base` is the frozen-r9 digest it was read against.  That
digest is itself read in `zk60_native_rg_tokenio_r9_pins` against frozen-r7,
so a gate that accepts a pin by reading walks the chain back to the digest
it was ported at, and every step must say `moves_a_receipt_byte: False`.

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

TOKEN_R11_READINGS = {
    "src/private_block/token_io.rs": {
        "7730c8d01bd85b916be81a176f3aeb4238d426748a99aef7075f3630e0a00fb4": {
            "base": "602597ad50d0978d4ea82385011084e2ff4f3678ecbffedc3f192b69d8fe5d9f",
            "diff_stat": "+4 / -0, 1 hunk against 602597ad (frozen-r9)",
            "moves_a_receipt_byte": False,
            "moves_a_block_stage_byte": False,
            "reading": "TEST-ONLY: one `#[cfg(test)] mod r11_tests;` declaration with its "
                       "two-line comment (review REVIEW6 TR7-5: the CLI's stage-shape "
                       "derivation pinned to the library's at every registered profile).  "
                       "No production item changes",
        },
    },
    "src/private_block/token_io/cli.rs": {
        "3eaaacdbafdcd2a7863a52294a7f762898f70f0837eaa06eb34cb7560751fabc": {
            "base": "b9079130204b49f5f73d38d8f5d531fcfa388d3a8d57c84ff87142eb57b655e9",
            "diff_stat": "+75 / -10, 7 hunks against b9079130 (frozen-r9)",
            "moves_a_receipt_byte": False,
            "moves_a_block_stage_byte": False,
            "reading": "THE CLI ONLY (a caller of the token run).  TR7-5: `seal_chain`'s inline "
                       "stage-shape derivation moved into `cli_stage_shape(sh, own)`, the same "
                       "expression (the run shape when the layer's calibration equals the "
                       "run's, else `Shape::with_layer_calibration(apply_own(base, own))`), "
                       "pinned to `TokenRunStatement::stage_shape` by the test-only "
                       "`r11_tests`.  TR7-6: `owner_inner` refuses an existing `--token-out` "
                       "path BEFORE the full re-verification (it was refused after it, by "
                       "`write_private`'s create-new, which still closes the race); a "
                       "test-only counter of `check_run` calls.  TR7-7: the owners' default "
                       "base and its per-user level are tightened to 0700 on use "
                       "(`tighten_to_0700`), with a stdout event naming the path and its old "
                       "mode only; a non-directory base is refused.  Doc comments for TR7-6 / "
                       "TR7-7.  The statement, the run directory, the verifier's reading of "
                       "it, the transcript, every draw and every opening are those of the "
                       "shared prover / verifier, unchanged",
        },
    },
}

READ_AT = "2026-10-21 ~00:20 UTC, frozen-r11 (manifest_final_r11 d8075d76...) against frozen-r9"
