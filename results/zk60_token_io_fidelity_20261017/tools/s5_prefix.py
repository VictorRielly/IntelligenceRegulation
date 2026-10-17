#!/usr/bin/env python3
"""s5 (F4): prefix consistency of the exact integer stack under one calibration (pg_rot1_b4, shared weights).

(a) the same token sequence run at T 128, at T 64 (prefix, export T64_cal128) and at T 32 (prefix, export
    T32_cal128): every layer's output at positions < T' must be identical;
(b) at T 128, the same first 64 tokens with a DIFFERENT suffix (positions 64..127 taken from other
    held-out sequences): every layer's output at positions < 64 must be identical (and the outputs at
    positions >= 64 are expected to differ: a sanity control that the suffix change took effect).
Sequences: held-out T128 indices 0, 1 (licence/docstring) and 36, 37 (FineWeb-Edu); suffix donors 2, 3, 38, 39.
Writes data/s5_prefix.json. Calibration data, not a proof.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fid_common as fc  # noqa: E402
import numpy as np  # noqa: E402

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None

SEL = [0, 1, 36, 37]
DONOR = [2, 3, 38, 39]
CUT = 64


def compare(A: list, B: list, upto: int) -> dict:
    per = []
    for l, (a, b) in enumerate(zip(A, B)):
        per.append(int((a[:, :upto] != b[:, :upto]).sum()))
    return {"layers": len(per), "words_differing_per_layer": per, "identical": all(v == 0 for v in per)}


def main():
    t0 = time.time()
    ids = np.load(fc.DATA / "tokens_heldout_T128.npz")["ids"]
    base = ids[SEL]
    rep = {"sequences_heldout_T128_index": SEL, "suffix_donors": DONOR, "cut": CUT}
    _, f128, _, L128 = fc.int_stack(base, 128, chunk=4, keep_layers=True, progress=False)
    fc.log(f"T128 run done ({time.time() - t0:.0f}s), refused {f128}")
    _, f64, _, L64 = fc.int_stack(base[:, :64], 64, chunk=4, keep_layers=True, progress=False)
    fc.log(f"T64 prefix run done ({time.time() - t0:.0f}s), refused {f64}")
    _, f32, _, L32 = fc.int_stack(base[:, :32], 32, chunk=4, keep_layers=True, progress=False)
    fc.log(f"T32 prefix run done ({time.time() - t0:.0f}s), refused {f32}")
    rep["refusals"] = {"T128": f128, "T64": f64, "T32": f32}
    rep["a_prefix_T64_vs_T128"] = compare(L128, L64, 64)
    rep["a_prefix_T32_vs_T128"] = compare(L128, L32, 32)
    alt = base.copy()
    alt[:, CUT:] = ids[DONOR][:, CUT:]
    rep["b_suffix_tokens_changed"] = int((alt != base).sum())
    _, falt, _, Lalt = fc.int_stack(alt, 128, chunk=4, keep_layers=True, progress=False)
    fc.log(f"T128 changed-suffix run done ({time.time() - t0:.0f}s), refused {falt}")
    rep["refusals"]["T128_changed_suffix"] = falt
    rep["b_changed_suffix_prefix_positions"] = compare(L128, Lalt, CUT)
    rep["b_changed_suffix_positions_ge_cut_words_differing_L21"] = int((L128[-1][:, CUT:] != Lalt[-1][:, CUT:]).sum())
    rep["ok"] = (rep["a_prefix_T64_vs_T128"]["identical"] and rep["a_prefix_T32_vs_T128"]["identical"]
                 and rep["b_changed_suffix_prefix_positions"]["identical"]
                 and rep["b_changed_suffix_positions_ge_cut_words_differing_L21"] > 0)
    rep["seconds"] = time.time() - t0
    (fc.DATA / "s5_prefix.json").write_text(fc.jdump(rep))
    print(json.dumps(rep, indent=1, default=str))
    return 0 if rep["ok"] else 1


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            rc = main()
    else:
        rc = main()
    sys.exit(rc)
