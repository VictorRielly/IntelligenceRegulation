#!/usr/bin/env python3
"""s3: the exact integer stack (tlcalib.i_block = the native block relations) on ALL 72 held-out sequences
of one context length, layer by layer from the export binaries (every sha256 checked), input from the
public int16 embedding table. Writes data/int_xout_T{T}.npy (int16 x_out_L21) and
data/s3_int_T{T}.json (refusals, per-layer site summaries, bit-exact check on the exported sequences).

Usage: s3_int.py T   (T in 128, 64, 32; export pg_rot1_b4_T128 / _T64_cal128 / _T32_cal128).
Calibration data, not a proof.
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


def main(T: int):
    t0 = time.time()
    fc.log(f"exact-mm selfcheck {fc.tc.selfcheck_exact_mm()}")
    ho = np.load(fc.DATA / f"tokens_heldout_T{T}.npz")
    ids = ho["ids"]
    xo, first, summaries, _ = fc.int_stack(ids, T)
    np.save(fc.DATA / f"int_xout_T{T}.npy", xo)
    checks = {}
    for sname, (idx, tids, x_in, x_out) in fc.exported_sequences(T).items():
        checks[sname] = {"heldout_index": idx, "tokens_equal": bool(np.array_equal(ids[idx], tids)),
                         "x_out_L21_bit_exact": bool(np.array_equal(xo[idx], x_out)),
                         "words_differing": int((xo[idx] != x_out).sum())}
    ok = all(c["tokens_equal"] and c["x_out_L21_bit_exact"] for c in checks.values())
    rep = {"T": T, "export": str(fc.EXPORTS[T]), "sequences": int(ids.shape[0]),
           "refused_sequences": int(sum(f is not None for f in first)), "first_refusal": first,
           "export_sequence_checks": checks, "export_bit_exact_ok": ok,
           "x_out_absmax": int(np.abs(xo.astype(np.int64)).max()),
           "layer_site_summaries": summaries, "seconds": time.time() - t0}
    (fc.DATA / f"s3_int_T{T}.json").write_text(fc.jdump(rep))
    fc.log(f"T{T}: refused {rep['refused_sequences']}/{ids.shape[0]}, export checks {checks}, {rep['seconds']:.0f}s")
    return 0 if ok else 1


if __name__ == "__main__":
    T = int(sys.argv[1])
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            rc = main(T)
    else:
        rc = main(T)
    sys.exit(rc)
