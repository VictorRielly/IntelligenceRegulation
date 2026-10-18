#!/usr/bin/env python3
"""PC-9 with a construction that holds on ANY bundle (round 5 correction).

Tools v6's PC-9 ("a pre-G-2 writer that pins ONE of the three G-2 files")
only SET one G-2 pin, which presumes a bundle whose writer pinned none (tree
A).  On an R5b bundle all three are already pinned, so the mutation was a
no-op and PC-9 came out honest (PASS) -- a control that could not fire there
(`r5b/l1/pincontrols/r5b-pincontrols-l1.json`).  Corrected construction: the
writer's run_capture.rs pin is set to tree A's read digest (a pre-G-2 writer),
ONE G-2 file is pinned at its read digest and the other two are DROPPED.
Predicted on any bundle: the two dropped sumcheck files refused, stages 7, 8,
10 held, ok false.  Uses the frozen v6 driver unchanged (only the control
list is replaced here); to be folded into the tool at the next freeze.

    python3 pincontrols_pc9.py <bundle> <evidence dir> <name>
"""
import sys
sys.path.insert(0, "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/scripts")
import zk60_native_rg_pincontrols as PC  # noqa: E402

TREE_A_RC = "c69e577621c4c2412a2819b4e0f2ae3c0a7613fb1db69c094d3f3e129cc876c9"


def pre_g2_writer_one_g2_pin(pins):
    PC._set(pins, "src/private_block/run_capture.rs", TREE_A_RC)
    PC._set(pins, PC.G2[0], PC.SHARED_G2_PINS[PC.G2[0]]["sha256"])
    for f in PC.G2[1:]:
        PC._drop(pins, f)


PC.CONTROLS = [
    ("PC-0", "honest", lambda p: None, (), True),
    ("PC-9b", "a pre-G-2 writer (tree A's run_capture.rs digest) pinning ONE of "
     "the three G-2 files, the other two dropped", pre_g2_writer_one_g2_pin,
     ("stage7_channels", "stage8_plane_index_and_terminals",
      "stage10_bilinear_group_factor"), False),
]
import os  # noqa: E402
os.makedirs(sys.argv[2], exist_ok=True)
raise SystemExit(PC.run_controls(sys.argv[1], sys.argv[2], sys.argv[3]))
