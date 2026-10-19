#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v5, 2026-10-17 round 4; independent review finding
P-2] The negative controls of the source-pin ENFORCEMENT in the staged driver.

    python3 zk60_native_rg_pincontrols.py --bundle <a small run bundle> \
        --evidence <dir> --name <name>

Before v5 the staged driver stored the run-layer pin check and ignored its
map of stages not to run, `ok` left the pins out, shared-file pins never
suspended anything and finding G-2's three prover files were pinned nowhere.
Each control below changes ONE pin of the bundle's manifest IN MEMORY (the
driver's `load_bundle` is wrapped for the length of one pass; nothing on disk
is touched) and runs the real staged driver over pass A's stages.  It must:
the record's `ok` false, exactly the predicted stages NOT RUN (`checked:
false`), every other stage run, and the status NOT-OK.  The honest pass must
be ok with nothing suspended.

  PC-0  honest
  PC-1  run.rs at an unread digest           -> every stage held
  PC-2  boundary.rs at an unread digest      -> stages 1, 3, 4, 5, 7 held
  PC-3  zkp-core/src/pcs.rs (a shared file a port depends on) moved
                                            -> 3, 4, 5, 7, 9 held
  PC-4  src/mle.rs (a shared file no port depends on) moved
                                            -> nothing held, ok false
  PC-5  src/mle.rs dropped from the pins     -> nothing held, ok false
  PC-6  an R5-writer pin set (run.rs, run_capture.rs at the R5 digests, the
        three G-2 files at the digests read) -> ok (honest for that writer)
  PC-7  PC-6 without encode_buffer.rs        -> 5, 7 held, ok false
  PC-8  PC-6 with sumcheck/rounds.rs moved   -> 7, 8, 10 held, ok false
  PC-9  [v7] a pre-G-2 writer (tree A's run_capture.rs digest) pinning ONE
        G-2 file, the other two dropped -> the two refused (7, 8, 10 held);
        holds on any bundle, whatever its own writer pinned
  PC-10 [v6] an R5b-writer pin set (G-2 + N-r4-d, every digest read) -> ok
  PC-11 [v6] PC-10 without src/gpu/mod.rs -> 3, 4, 5, 7, 9 held

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_rg_m125 as M  # noqa: E402
from zk60_native_rg_tinyllama_r5_pins import RUN_LAYER_PINS as R5, SHARED_G2_PINS  # noqa: E402
from zk60_native_rg_tinyllama_r5b_pins import RUN_LAYER_PINS as R5B, SHARED_NR4D_PINS  # noqa: E402

STAGES = ["load", "replay", "hash", "terminals", "commitments", "boundary",
          "preimage", "channels"]
PASS_A_KEYS = ("stage1_integrity", "stage2_transcript_replay", "stage9_hash_layer",
               "stage8_plane_index_and_terminals", "stage10_bilinear_group_factor",
               "stage3_per_commitment", "stage4_the_boundary",
               "stage5_zero_data_preimage", "stage7_channels")
G2 = sorted(SHARED_G2_PINS)
R5_RUN = next(iter(R5["src/private_block/run.rs"]))
R5_RC = next(iter(R5["src/private_block/run_capture.rs"]))
UNREAD = "0" * 64
# tree A's run_capture.rs (round 1's capture writer, which pins no G-2 file)
TREE_A_RC = "c69e577621c4c2412a2819b4e0f2ae3c0a7613fb1db69c094d3f3e129cc876c9"


def _set(pins, path, digest):
    for p in pins:
        if p["file"] == path:
            p["sha256"] = digest
            return
    pins.append({"file": path, "sha256": digest})


def _drop(pins, path):
    pins[:] = [p for p in pins if p["file"] != path]


def _r5_writer(pins):
    _set(pins, "src/private_block/run.rs", R5_RUN)
    _set(pins, "src/private_block/run_capture.rs", R5_RC)
    for f in G2:
        _set(pins, f, SHARED_G2_PINS[f]["sha256"])


def _r5b_writer(pins):
    """[v6] an R5b-writer pin set: R5b's run-layer digests, G-2 and N-r4-d"""
    _set(pins, "src/private_block/run.rs", next(iter(R5B["src/private_block/run.rs"])))
    _set(pins, "src/private_block/run_capture.rs", next(iter(R5B["src/private_block/run_capture.rs"])))
    for f in G2:
        _set(pins, f, SHARED_G2_PINS[f]["sha256"])
    for f, e in SHARED_NR4D_PINS.items():
        _set(pins, f, e["sha256"])


CONTROLS = [
    ("PC-0", "honest", lambda p: None, (), True),
    ("PC-1", "run.rs at an unread digest",
     lambda p: _set(p, "src/private_block/run.rs", UNREAD), PASS_A_KEYS, False),
    ("PC-2", "boundary.rs at an unread digest",
     lambda p: _set(p, "src/private_block/boundary.rs", UNREAD),
     ("stage1_integrity", "stage3_per_commitment", "stage4_the_boundary",
      "stage5_zero_data_preimage", "stage7_channels"), False),
    ("PC-3", "zkp-core/src/pcs.rs (a port depends on it) at an unread digest",
     lambda p: _set(p, "../zkp-core/src/pcs.rs", UNREAD),
     ("stage3_per_commitment", "stage4_the_boundary", "stage5_zero_data_preimage",
      "stage7_channels", "stage9_hash_layer"), False),
    ("PC-4", "src/mle.rs (no port depends on it) at an unread digest",
     lambda p: _set(p, "src/mle.rs", UNREAD), (), False),
    ("PC-5", "src/mle.rs dropped from the bundle's pins",
     lambda p: _drop(p, "src/mle.rs"), (), False),
    ("PC-6", "an R5-writer pin set, every digest read", _r5_writer, (), True),
    ("PC-7", "the R5-writer pin set without zkp-core pcs/encode_buffer.rs",
     lambda p: (_r5_writer(p), _drop(p, "../zkp-core/src/pcs/encode_buffer.rs")),
     ("stage5_zero_data_preimage", "stage7_channels"), False),
    ("PC-8", "the R5-writer pin set with zkp-core sumcheck/rounds.rs moved",
     lambda p: (_r5_writer(p), _set(p, "../zkp-core/src/sumcheck/rounds.rs", UNREAD)),
     ("stage7_channels", "stage8_plane_index_and_terminals",
      "stage10_bilinear_group_factor"), False),
    # [v7, round 6] PC-9 is PC-9b: v6's construction only SET one G-2 pin and
    # was a no-op on a bundle whose writer already pins all three (R5b), so
    # it could not fire there (round 5). Now the writer's run_capture.rs pin
    # is set to tree A's read digest (a pre-G-2 writer), one G-2 file is
    # pinned at its read digest and the other two are DROPPED: on ANY
    # bundle the two dropped sumcheck files are refused, stages 7, 8, 10 held.
    ("PC-9", "a pre-G-2 writer (tree A's run_capture.rs digest) pinning ONE of "
     "the three G-2 files, the other two dropped",
     lambda p: (_set(p, "src/private_block/run_capture.rs", TREE_A_RC),
                _set(p, G2[0], SHARED_G2_PINS[G2[0]]["sha256"]),
                [_drop(p, f) for f in G2[1:]]),
     ("stage7_channels", "stage8_plane_index_and_terminals",
      "stage10_bilinear_group_factor"), False),
    # [v6, round 5] the R5b writer: honest, and without one N-r4-d pin
    ("PC-10", "an R5b-writer pin set (G-2 and N-r4-d), every digest read",
     _r5b_writer, (), True),
    ("PC-11", "the R5b-writer pin set without src/gpu/mod.rs",
     lambda p: (_r5b_writer(p), _drop(p, "src/gpu/mod.rs")),
     ("stage3_per_commitment", "stage4_the_boundary", "stage5_zero_data_preimage",
      "stage7_channels", "stage9_hash_layer"), False),
]


@contextlib.contextmanager
def tampered(mutate):
    real = M.load_bundle

    def load(d):
        b = real(d)
        mutate(b.manifest["source_pins"])
        return b
    M.load_bundle = load
    try:
        yield
    finally:
        M.load_bundle = real


def run_controls(bundle_dir, evidence, name):
    rows = []
    for cid, what, mutate, held_want, ok_want in CONTROLS:
        with tampered(mutate):
            d = M.Driver(bundle_dir, evidence, f"{name}-{cid}")
            rec = d.run(list(STAGES))
        held = sorted(k for k in PASS_A_KEYS
                      if isinstance(rec.get(k), dict) and rec[k].get("checked") is False)
        ran = sorted(k for k in PASS_A_KEYS if k not in held)
        exact = sorted(held_want) == held
        fires = (rec["ok"] is ok_want) and exact and (
            d.status["status"] == ("PASS" if ok_want else "NOT-OK"))
        rows.append({"control": cid, "what": what, "record_ok": rec["ok"],
                     "status": d.status["status"], "stages_not_run": held,
                     "stages_run": ran, "predicted_not_run": sorted(held_want),
                     "exactly_the_predicted_stages": exact,
                     "pins_ok": (rec.get("run_layer_source_pins") or {}).get("ok"),
                     "fires" if not ok_want else "honest_as_predicted": fires})
        print(f"{cid}: ok={rec['ok']} status={d.status['status']} held={len(held)} "
              f"exact={exact}", flush=True)
    good = all(r.get("fires", r.get("honest_as_predicted")) for r in rows)
    with open(os.path.abspath(__file__), "rb") as fh:
        me = hashlib.sha256(fh.read()).hexdigest()
    out = {"what": "negative controls of the source-pin enforcement (review P-2)",
           "bundle": os.path.basename(bundle_dir), "tool_sha256": me,
           "stages": STAGES, "controls": rows, "ok": good,
           "nothing_written_to_the_bundle": True,
           "privacy_property_established": False, "privacy_acceptance": False}
    p = os.path.join(evidence, f"{name}.json")
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"record: {p}   ok={good}")
    return 0 if good else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    os.makedirs(a.evidence, exist_ok=True)
    return run_controls(a.bundle, a.evidence, a.name)


if __name__ == "__main__":
    raise SystemExit(main())
