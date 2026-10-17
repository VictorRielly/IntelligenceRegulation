#!/usr/bin/env python3
"""s2: the float32 model (HF Llama semantics, original basis, tlcalib.f_block; no quantisation anywhere).

* calibration set (T 128, 108 sequences, the B4 calibration corpus): the final residual (input of the
  final norm), rotated x' = x R^T (float64), xhat' = x' / sqrt(mean(x'^2) + eps): per-channel and global
  maxima -> data/calib_final_xhat.npz (the final-norm Cn is chosen from these, as norm_a's is);
* held-out T 128 and T 32 (72 sequences each): the final residual -> data/float_final_T{T}.npy (float32).

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

tc, b3 = fc.tc, fc.b3

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None


def forward(ck, ids: np.ndarray, T: int, chunk: int = 12) -> np.ndarray:
    E = tc.tensor_f32(ck.refs["model.embed_tokens.weight"])
    x = E[ids]
    del E
    rope = tc.rope_f32(T)
    for l in range(ck.config["layers"]):
        t0 = time.time()
        W = tc.layer_f32(ck, l)
        x = np.concatenate([tc.f_block(x[s:s + chunk], W, *rope) for s in range(0, x.shape[0], chunk)])
        del W
        if l % 7 == 0 or l == ck.config["layers"] - 1:
            fc.log(f"  float T{T} N{ids.shape[0]} L{l:02d} ({time.time() - t0:.1f}s)")
    return x


def main():
    t0 = time.time()
    ck = tc.open_checkpoint()
    sign = fc.export_rotation(128)
    R = b3.Rotation(tc.GEO.d, 1)
    assert np.array_equal(R.sign, sign)
    rep = {}
    # ---- calibration statistics of the final residual (rotated basis)
    cal = np.load(fc.DATA / "tokens_calib_T128.npz")
    cal_ids = cal["ids"]
    xc = forward(ck, cal_ids, 128)
    eps = tc.GEO.eps
    ch_max = np.zeros(tc.GEO.d)
    ch_max_unrot = np.zeros(tc.GEO.d)
    allmax = []
    for s in range(0, xc.shape[0], 12):
        xr = R.fwd(xc[s:s + 12].reshape(-1, tc.GEO.d))                    # float64 x' = x R^T
        xh = xr / np.sqrt(np.mean(xr * xr, axis=-1, keepdims=True) + eps)
        ch_max = np.maximum(ch_max, np.abs(xh).max(0))
        allmax.append(np.abs(xh).max(-1))
        xu = xc[s:s + 12].reshape(-1, tc.GEO.d).astype(np.float64)
        xuh = xu / np.sqrt(np.mean(xu * xu, axis=-1, keepdims=True) + eps)
        ch_max_unrot = np.maximum(ch_max_unrot, np.abs(xuh).max(0))
    allmax = np.concatenate(allmax)
    np.savez(fc.DATA / "calib_final_xhat.npz", ch_max_rot=ch_max, ch_max_unrot=ch_max_unrot, pos_max_rot=allmax)
    rep["calib"] = {"sequences": int(cal_ids.shape[0]), "T": 128,
                    "xhat_rot_absmax": float(ch_max.max()), "xhat_rot_pos_max_quantiles": {
                        q: float(np.quantile(allmax, q)) for q in (0.5, 0.9, 0.99, 0.999, 1.0)},
                    "xhat_unrot_absmax": float(ch_max_unrot.max()),
                    "final_residual_absmax": float(np.abs(xc).max())}
    fc.log(f"calibration final-norm stats: {rep['calib']}")
    del xc
    # ---- held-out final residuals
    for T in (128, 32):
        ho = np.load(fc.DATA / f"tokens_heldout_T{T}.npz")
        xf = forward(ck, ho["ids"], T)
        np.save(fc.DATA / f"float_final_T{T}.npy", xf.astype(np.float32))
        rep[f"heldout_T{T}"] = {"shape": list(xf.shape), "final_residual_absmax": float(np.abs(xf).max())}
        fc.log(f"held-out T{T} float final residual saved {xf.shape}")
        del xf
    rep["seconds"] = time.time() - t0
    (fc.DATA / "s2_float_report.json").write_text(json.dumps(rep, indent=1))
    print(json.dumps(rep, indent=1))


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()
