#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v11, 2026-10-19, gate round 8: the D33 re-pin] The
READINGS behind every source pin of the TRAINED BLOCK bundles captured from
the gate's copy of the token lane's frozen round-7 tree ("tk7"), which the
earlier readings do not cover.  They are merged at the same definition sites
as the R5b and R7 readings, one marked line each.  No existing digest or
reading changes; the merge refuses a digest that is already present.

THE TREE.  `ops/zkp-mvp/trained-1b-gate-tk7/` is an rsync of
`results/zk60_token_io_r1_20261017/frozen-r7/`: 233 of 233 files equal to
`manifest_final_r7.sha256` (eb912dd5...), which is native R8 plus the token
files.  On top of it sit the gate's R5b capture patch (applied with offsets,
no reject) and the stage-47 module.  Sources manifest:
`results/zk60_gate_tinyllama_20261017/tk7/trained-1b-gate-tk7.sources.v1.sha256`
(d356e7aa...).

A block bundle written from tk7 pins 52 files.  40 of them are
byte-identical to the R7 pins read in v8.  The other 12 are read in two
places:
* the 11 the token lane changed or added are in
  `zk60_native_rg_tokenio_r7c_pins.TOKEN_R7C_READINGS` (read 2026-10-19
  17:46:55 UTC; frozen-r7's pinned files equal r7c's);
* the capture writer `run_capture.rs` is read HERE.  It is the token writer
  `aaff4e6e` plus the gate patch.

Of these 12, the block gate's ports transcribe from run.rs (RUN_LAYER_PINS)
and shape.rs (the terminal and mask layers).  The rest are report-only.

THE EXPORT FACT EVERY READING USES [READ]: `pg_rot1_export_T32/profile.json`
lists `per_layer_constants_differ = [exp_e_s, silu_member]`, none of R8's
eleven calibration keys.  So R8's per-layer calibration (`stage_cal`,
`apply_own`, `with_layer_calibration`) is inert: every stage is proved at the
run shape, and the schedule lines and identity bytes are R7's (token r7c
readings, run.rs / shape.rs / trained_statement.rs).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

from zk60_native_rg_tokenio_r7c_pins import TOKEN_R7C_READINGS as _TK

TREE = ("uncommitted:ops/zkp-mvp/trained-1b-gate-tk7 "
        "(the token lane's frozen round-7 tree eb912dd5 = native R8 + token files, "
        "+ the privacy-gate lane's capture patch and stage-47 module; sources manifest d356e7aa)",)
TK7_BUNDLES = ("tinyllama-trained-tk7-capture-dense-l1", "tinyllama-trained-tk7-capture-zero-l1",
               "tinyllama-trained-tk7-capture-dense-l2", "tinyllama-trained-tk7-capture-zero-l2",
               "tinyllama-trained-tk7-capture-dense-l22", "tinyllama-trained-tk7-capture-zero-l22")

RUN_CAPTURE_RS = "f47e28bf791aa225c9a0c19dd7f2662b2326846f847dcbc0041dac86be527289"


def _full(path, prefix):
    for d in _TK[path]:
        if d.startswith(prefix):
            return d
    raise KeyError(f"{path}: no token r7c reading of {prefix}")


RUN_RS = _full("src/private_block/run.rs", "2c158dc9")
SHAPE_RS = _full("src/private_block/shape.rs", "8c62519c")

RUN_LAYER_PINS = {
    "src/private_block/run.rs": {
        RUN_RS: {
            "blob": "23e2efa5a7af731840790c7fc79718405d4ea0a1",
            "commits": TREE,
            "bundles": TK7_BUNDLES,
            "bytes": 80119,
        },
    },
    "src/private_block/run_capture.rs": {
        RUN_CAPTURE_RS: {
            "blob": "d674f0130d6d3074da36bb06020bc5d6713c80df",
            "commits": TREE,
            "bundles": TK7_BUNDLES,
            "bytes": 135196,
            # the token writer pins G-2's three files and review r4's N-r4-d
            # three (checked by grep in the tk7 copy), so a bundle it wrote
            # must pin all six
            "pins_g2": True,
            "pins_nr4d": True,
        },
    },
}

READINGS = {
    ("src/private_block/run.rs", RUN_RS):
        "[TINYLLAMA PORT v11, round 8] the token r7c reading, verbatim from "
        "`zk60_native_rg_tokenio_r7c_pins.TOKEN_R7C_READINGS` (frozen-r7's run.rs = "
        "r7c's): " + _TK["src/private_block/run.rs"][RUN_RS]["reading"],
    ("src/private_block/run_capture.rs", RUN_CAPTURE_RS):
        "[TINYLLAMA PORT v11, round 8] read against `aaff4e6e` (the token r7c writer, "
        "read in round 7: the native writer 1d43d68c plus the token capture hooks, "
        "no-ops when no capture is active).  `diff -u` is +/- 47 lines in three hunks "
        "(offsets 590 / 824 / 885).  They are line for line the gate's R5b capture "
        "patch (`r5b/trained-1b-gate-r5b-vs-frozen-r5b.v1.patch`, checked by diffing "
        "the two hunk sets): the trained-calibration `shape` keys "
        "(`trained_calibration`, the norm and shift constants, `d_max`), their "
        "allow-list entries, and the README sentence.  No field, kind, label or order "
        "a loader reads moved, apart from those keys returning.  The token writer "
        "inserts its six files into `OWN_SOURCE_FILES` at positions 16-21, so pins "
        "are matched by name (the gate always has).  SHARED_SOURCE_FILES pins G-2's "
        "and N-r4-d's three each",
}

TERMINALS_PINNED_IF_PRESENT = {
    "src/private_block/shape.rs": {
        SHAPE_RS: "[TINYLLAMA PORT v11, round 8] the token r7c reading (frozen-r7's "
                  "shape.rs = native R8's): " + _TK["src/private_block/shape.rs"][SHAPE_RS]["reading"],
    },
}

MASK_LAYER_PINS = {
    "src/private_block/shape.rs": {
        SHAPE_RS: {
            "commits": TREE,
            "bundles": TK7_BUNDLES,
            "reading": "[TINYLLAMA PORT v11, round 8] `Shape::slots` and ruling C-4 are "
                       "outside the one hunk against R7's 7b0c9742 (`with_layer_calibration`, "
                       "R8; the token r7c reading)",
        },
    },
}
