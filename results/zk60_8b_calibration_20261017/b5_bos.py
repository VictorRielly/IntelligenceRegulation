#!/usr/bin/env python3
"""Lane B5: the BOS-row residual stream of Llama-3-8B through all 32 layers
(float32 reference). Position 0 is BOS (id 128000) in every sequence and its
causal attention sees only itself, so these activations do not depend on any
other token: the massive-activation picture at BOS needs no tokenizer.
Reports per layer the residual absmax, its top channels (model basis) and the
absmax in the rotated basis (seed 1), plus the residual scale one int16 range
would need. Calibration evidence, not a proof."""

from __future__ import annotations

import os

os.environ.setdefault("ZK60_MODEL", "llama3-8b")
import json  # noqa: E402
import sys  # noqa: E402
from pathlib import Path  # noqa: E402

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929")
import numpy as np  # noqa: E402

import tlcalib as tc  # noqa: E402
import b3calib as b3  # noqa: E402

ck = tc.open_checkpoint()
ref = ck.refs["model.embed_tokens.weight"]
raw = np.frombuffer(ref.read_bytes(max_bytes=ref.end - ref.start), dtype="<u2").reshape(ref.shape)
x = ((raw[128000].astype(np.uint32) << 16).view(np.float32))[None, None, :].copy()
del raw
R = b3.Rotation(tc.GEO.d, 1)
cos, sin = tc.rope_f32(1)
rows = []
for l in range(ck.config["layers"]):
    W = tc.layer_f32(ck, l)
    x = tc.f_block(x, W, cos, sin)
    v = x[0, 0].astype(np.float64)
    top = np.argsort(-np.abs(v))[:4]
    xr = R.fwd(v[None])[0]
    rows.append({"layer": l, "absmax": float(np.abs(v).max()), "rms": float(np.sqrt((v * v).mean())),
                 "top_channels": top.tolist(), "top_values": [round(float(v[i]), 2) for i in top],
                 "rotated_absmax": float(np.abs(xr).max()), "rotated_rms": float(np.sqrt((xr * xr).mean()))})
    print(f"L{l:02d} BOS out absmax {rows[-1]['absmax']:8.2f} rms {rows[-1]['rms']:6.3f} top {rows[-1]['top_channels']} "
          f"{rows[-1]['top_values']} | rotated absmax {rows[-1]['rotated_absmax']:6.2f}", flush=True)
mx = max(r["absmax"] for r in rows)
mr = max(r["rotated_absmax"] for r in rows)
out = {"model": "NousResearch/Meta-Llama-3-8B@315b2009", "token": 128000, "layers": rows,
       "one_scale_needs_s_x_at_margin_1.5": {"model_basis": mx * 1.5 / 32767, "rotated_basis": mr * 1.5 / 32767}}
Path(__file__).resolve().parent.joinpath("runs", "b5_bos_massive.json").write_text(json.dumps(out, indent=1))
print(json.dumps(out["one_scale_needs_s_x_at_margin_1.5"]))
