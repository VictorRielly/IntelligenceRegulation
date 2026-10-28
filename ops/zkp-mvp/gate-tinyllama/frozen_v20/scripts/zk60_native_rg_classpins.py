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


def _token_accepts(f, d):
    """does the token gate (v18) accept digest d of file f"""
    import zk60_native_rg_tokenio_r7c_pins as TP
    import zk60_native_rg_tokenio_r9_pins as R9
    import zk60_native_rg_tokenio_r11_pins as R11
    return (d in TP.TOKEN_R7C_READINGS.get(f, {}) or d in R9.TOKEN_R9_READINGS.get(f, {})
            or d in R11.TOKEN_R11_READINGS.get(f, {}) or TP.R7_PINS_READ_IN_V8.get(f) == d)


def classify_capture_pins(manifest: dict) -> dict:
    """[v20] every `source_pins` entry of a classifier capture: accepted when
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
