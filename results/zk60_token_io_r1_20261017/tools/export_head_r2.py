"""R2 input: the TinyLlama per-row int8 head W' and its 12-bit multipliers, exported as files.

The fidelity lane (results/zk60_token_io_fidelity_20261017/) builds the head from the pinned checkpoint
(`s4_head.build_heads`: W' = lm_head diag(norm_weight) R^T in float64, R the export's seed-1 randomized
Hadamard; per-row int8 `clip(floor(W'_j / s_j + 0.5), -127, 127)` with s_j = max_i |W'_j,i| / 127) but keeps
only its digest. This script calls the SAME function (read-only import of that lane's tools), checks the
int8 rows' SHA-256 against the lane's recorded `b99cbec5...`, derives the multipliers exactly as the lane's
s4 does (`m_j = max(1, floor(2^12 s_j / max s + 0.5))`, D25 T4 as amended 20:21 UTC) and writes:
  head_int8_perrow.bin (32000 x 2048 int8, row-major), head_mult12.bin (32000 int64 LE),
  head_manifest.json (digests, shapes, the final-norm constants of data/s4_head.json: g0 127, tn 10,
  Ceps 74429, Cn 5664 = the calibration rule (cal_m1.50), BOS 1, V 32000).
Public model data derived from the pinned checkpoint. Not a proof. Peak memory ~2 GB (float64 W').
"""
import hashlib
import json
import os
import sys
import time

FID = "/home/victor/IntelligenceRegulation/results/zk60_token_io_fidelity_20261017"
sys.path.insert(0, os.path.join(FID, "tools"))
sys.dont_write_bytecode = True
import numpy as np  # noqa: E402

import s4_head as s4  # noqa: E402

WANT_ROWS = "b99cbec5f457e47ca2441de517135ba1bd1870e2ae8abe2038dbd84617436280"
WANT_SCALES = "5eb2b350e384749b9f7ab976e1f5027a4793e6a5a75515af9577e43ad5ea1b1c"


def main(out):
    t0 = time.time()
    os.makedirs(out, exist_ok=True)
    rep = {}
    ck = s4.tc.open_checkpoint()
    nw, lm, Wp, Wt, Wr, s_t, s_r = s4.build_heads(ck, rep)
    rows = Wr.astype(np.int8).tobytes()
    sha_rows = hashlib.sha256(rows).hexdigest()
    sha_scales = hashlib.sha256(s_r.astype("<f8").tobytes()).hexdigest()
    assert sha_rows == WANT_ROWS, ("the per-row int8 head is not the fidelity lane's", sha_rows)
    assert sha_scales == WANT_SCALES, ("the per-row scales are not the fidelity lane's", sha_scales)
    mult = np.maximum(1, np.floor((2 ** 12) * s_r / s_r.max() + 0.5)).astype(np.int64)
    assert mult.min() >= 1 and mult.max() <= 4096
    open(os.path.join(out, "head_int8_perrow.bin"), "wb").write(rows)
    mb = mult.astype("<i8").tobytes()
    open(os.path.join(out, "head_mult12.bin"), "wb").write(mb)
    fid = json.load(open(os.path.join(FID, "data", "s4_head.json")))
    fn = fid["final_norm"]
    man = {
        "kind": "token-io R2 head (per-row int8 + 12-bit multipliers, D25 T4 as amended)",
        "source": "results/zk60_token_io_fidelity_20261017/tools/s4_head.py build_heads (read-only import)",
        "V": int(Wr.shape[0]), "d": int(Wr.shape[1]),
        "head_int8_perrow.bin": {"dtype": "int8", "shape": [int(Wr.shape[0]), int(Wr.shape[1])], "sha256": sha_rows},
        "head_mult12.bin": {"dtype": "int64 little-endian", "shape": [int(mult.shape[0])], "sha256": hashlib.sha256(mb).hexdigest(),
                            "rule": "m_j = max(1, floor(2^12 s_j / max s + 0.5))", "min": int(mult.min()), "max": int(mult.max()),
                            "distinct": int(len(np.unique(mult)))},
        "scales_f64_sha256": sha_scales,
        "minus128": int((Wr == -128).sum()),
        "final_norm": {"g0": int(fn["g0"]), "tn": int(fn["tn"]), "ceps": int(fn["ceps"]), "cn_calibrated": int(fn["cn_configs"]["cal_m1.50"]),
                       "cn_refusal_free": int(fn["cn_configs"]["diag_safe"]), "window_bits": int(fn["window_bits"])},
        "bos": 1,
        "seconds": time.time() - t0,
    }
    json.dump(man, open(os.path.join(out, "head_manifest.json"), "w"), indent=1)
    print(json.dumps(man, indent=1))


if __name__ == "__main__":
    main(sys.argv[1])
