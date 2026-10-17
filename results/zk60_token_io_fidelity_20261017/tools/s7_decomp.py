#!/usr/bin/env python3
"""s7: where the integer head's top-1 loss comes from (diagnostic, all 11,520 held-out positions).

Against the float head's token (s4_positions.npz, TOKEN_IO_SPEC float path on the same integer output):
  A  exact xhat' (float64)            x  per-tensor int8 W' (dequantised)   -> head-weight rounding only
  B  exact xhat'                      x  per-row int8 W' (dequantised)      -> per-row weight rounding only
  C  int8 y of the final norm (cal Cn) x float W'                           -> norm-output rounding only
  D  int16 y (uniform gain, refusal-free: y = floor(x * 32767 / D + 1/2), |y| <= 32767 since D >= |x|)
       x per-tensor int8 W'  (raw integer logits; a recorded DESIGN ALTERNATIVE, not the block norm relation)
  E  int16 y x per-row int8 W' (exact float row scales)
  F/G int16 y x per-row int8 W' with public integer row multipliers m_j = round(2^b s_j / max s), b = 12 / 8
Writes data/s7_decomp.json. Calibration data, not a proof.
"""

from __future__ import annotations

import json
import math
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fid_common as fc  # noqa: E402
import numpy as np  # noqa: E402

import s4_head as s4  # noqa: E402

tc = fc.tc

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None


def fprod(y: np.ndarray, Wq: np.ndarray) -> np.ndarray:
    yf = y.astype(np.float64)
    out = np.empty((y.shape[0], Wq.shape[0]), dtype=np.float64)
    for v0 in range(0, Wq.shape[0], s4.VBLOCK):
        out[:, v0:v0 + s4.VBLOCK] = yf @ Wq[v0:v0 + s4.VBLOCK].astype(np.float64).T
    return out


def main():
    t0 = time.time()
    ck = tc.open_checkpoint()
    rep = {}
    nw, lm, Wp, Wt, Wr, s_t, s_r = s4.build_heads(ck, rep)
    del lm, nw
    H = json.loads((fc.DATA / "s4_head.json").read_text())
    cn = int(H["final_norm"]["cn_configs"]["cal_m1.50"])
    g0, tn, ceps, wrho = 127, 10, int(H["final_norm"]["ceps"]), int(H["final_norm"]["window_bits"])
    pos = np.load(fc.DATA / "s4_positions.npz")
    out = {"cn": cn, "variants": {}}
    keys = ("A_exact_y_pt_W", "B_exact_y_pr_W", "C_int8_y_float_W", "D_int16_y_pt_W", "E_int16_y_pr_W",
            "F_int16_y_pr_m12", "G_int16_y_pr_m8")
    mult = {b: np.maximum(1, np.floor((2 ** b) * s_r / s_r.max() + 0.5)).astype(np.int64) for b in (12, 8)}
    for T in (128, 32):
        X = np.load(fc.DATA / f"int_xout_T{T}.npy").reshape(-1, s4.D_MODEL).astype(np.int64)
        ref = pos[f"T{T}/float_head_tok"]
        n = X.shape[0]
        toks = {k: np.zeros(n, dtype=np.int64) for k in keys}
        d16_absmax, d16_ties = 0, 0
        kd = {"D": 0, "F": 0, "G": 0}
        for c0 in range(0, n, s4.CHUNK):
            sl = slice(c0, min(n, c0 + s4.CHUNK))
            x = X[sl]
            ss = ceps + (x * x).sum(-1)
            D = tc.isqrt_vec(ss)
            xh = x * math.sqrt(s4.D_MODEL) / np.sqrt(ss.astype(np.float64))[:, None]    # exact xhat' (eps = Ceps)
            toks["A_exact_y_pt_W"][sl] = fprod(xh, Wt).argmax(-1)
            toks["B_exact_y_pr_W"][sl] = (fprod(xh, Wr) * s_r[None, :]).argmax(-1)
            y8, refused, _ = s4.final_norm(x, g0, cn, tn, ceps, wrho)
            assert not refused.any()
            toks["C_int8_y_float_W"][sl] = (y8.astype(np.float64) @ Wp.T).argmax(-1)
            y16 = (2 * x * 32767 + D[:, None]) // (2 * D[:, None])                  # floor(x 32767 / D + 1/2)
            assert np.abs(y16).max() <= 32767
            L16 = fprod(y16, Wt)
            assert np.abs(L16).max() < 2 ** 52
            L16 = L16.astype(np.int64)
            a16 = L16.argmax(-1)
            toks["D_int16_y_pt_W"][sl] = a16
            mx = L16[np.arange(L16.shape[0]), a16]
            d16_ties += int(((L16 == mx[:, None]).sum(-1) > 1).sum())
            d16_absmax = max(d16_absmax, int(np.abs(L16).max()))
            kd["D"] = max(kd["D"], int(s4.keyed_stats(L16, a16)[0].max()))
            Lr16 = fprod(y16, Wr)
            toks["E_int16_y_pr_W"][sl] = (Lr16 * s_r[None, :]).argmax(-1)
            Lr16 = Lr16.astype(np.int64)
            for b, key, kk in ((12, "F_int16_y_pr_m12", "F"), (8, "G_int16_y_pr_m8", "G")):
                C = Lr16 * mult[b][None, :]
                ab = C.argmax(-1)
                toks[key][sl] = ab
                kd[kk] = max(kd[kk], int(s4.keyed_stats(C, ab)[0].max()))
            del Lr16
            fc.log(f"  T{T} {sl.start}-{sl.stop} of {n}")
        out["variants"][f"T{T}"] = {k: {"agree": int((v == ref).sum()), "n": int(n), "rate": float((v == ref).mean())}
                                   for k, v in toks.items()}
        out["variants"][f"T{T}"]["D_int16_logit_absmax"] = d16_absmax
        out["variants"][f"T{T}"]["D_int16_logit_absmax_bits"] = math.log2(max(1, d16_absmax))
        out["variants"][f"T{T}"]["D_int16_tie_positions"] = d16_ties
        out["variants"][f"T{T}"]["keyed_delta_bits_measured"] = {k: int(v).bit_length() for k, v in kd.items()}
        out["variants"][f"T{T}"]["keyed_delta_bits_worst_case"] = {
            "D": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 32767 * 127 + (1 << s4.V_BITS)).bit_length()),
            "F": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 32767 * 127 * 4096 + (1 << s4.V_BITS)).bit_length()),
            "G": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 32767 * 127 * 256 + (1 << s4.V_BITS)).bit_length()),
            "int8_y_pt": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 127 * 127 + (1 << s4.V_BITS)).bit_length()),
            "int8_y_pr_m12": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 127 * 127 * 4096 + (1 << s4.V_BITS)).bit_length()),
            "int8_y_pr_m8": int(((1 << s4.V_BITS) * 2 * s4.D_MODEL * 127 * 127 * 256 + (1 << s4.V_BITS)).bit_length())}
        out["variants"][f"T{T}"]["D_int16_keyed_window_bits_worst_case"] = int(
            ((1 << s4.V_BITS) * 2 * s4.D_MODEL * 32767 * 127 + (1 << s4.V_BITS)).bit_length())
        fc.log(f"T{T}: {out['variants'][f'T{T}']}")
    out["seconds"] = time.time() - t0
    (fc.DATA / "s7_decomp.json").write_text(fc.jdump(out))
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()
