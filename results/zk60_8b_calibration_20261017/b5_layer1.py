#!/usr/bin/env python3
"""Lane B5: what a wider score class would buy at Llama-3-8B layer 1 (the layer
whose attention sees the BOS sink: raw scores up to ~223 force e_s = 2 with
int8 scores). Isolated, layer 1 only, same calibration statistics and profile
as the pg+rot T=32 export: (a) the native int8 score; (b) the s16 experiment
(int16 score, SH_S = 1, exp table of 65536 rows — NOT a native relation).
Held-out subset: the first 12 sequences of each domain. Diagnostic only."""

from __future__ import annotations

import os

os.environ.setdefault("ZK60_MODEL", "llama3-8b")
import json  # noqa: E402
import pickle  # noqa: E402
import sys  # noqa: E402
from pathlib import Path  # noqa: E402

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import numpy as np  # noqa: E402

import b5_8b as b5  # noqa: E402

tc, b3, bl = b5.tc, b5.b3, b5.bl
run = HERE / "runs" / "llama3_8b_pg_rot1_T32"
prof = json.loads((run / "prepass.json").read_text())["profile"]
stats = pickle.load(open(HERE / "runs" / "b5_stats_T32_n54_r1_L32.pkl", "rb"))
tok = b5.HFTokenizer(tc.MODEL_DIR / "tokenizer.json")
ho, _ = b5.text_sequences(tok, "heldout", 32, 4)
h2, _ = b5.fineweb_sequences(tok, "heldout", 32, 36)
ids = np.array(ho[:12] + h2[:12], dtype=np.int64)
ck = tc.open_checkpoint()
R = b3.Rotation(tc.GEO.d, 1)
eref = ck.refs["model.embed_tokens.weight"]
eraw = np.frombuffer(eref.read_bytes(max_bytes=eref.end - eref.start), dtype="<u2")
x = b5.bf16_rows(eraw, ids.reshape(-1), tc.GEO.d).reshape(*ids.shape, -1)
del eraw
x = R.fwd(x.reshape(-1, tc.GEO.d)).astype(np.float32).reshape(x.shape)
rope_f = tc.rope_f32(32)
rope_i = b3.rope_generate(32, tc.GEO.dh, tc.GEO.theta, b3.F_RO)
x = tc.f_block(x, bl.load_layer(ck, 0, R), *rope_f)        # float input of layer 1
W = bl.load_layer(ck, 1, R)
xf_next = tc.f_block(x, W, *rope_f)
s_x = prof["s_in"][1]
res = {}
for vn in ("pg", "pg+s16"):
    v0 = b3.variant_by_name(vn, rotate=1)
    kw = dict(v0.__dict__)
    kw.update(tn=9, cn_max=1 << 20)
    var = b3.Variant(**kw)
    glob = b3.Globals(s_in=prof["s_in"], s_out=prof["s_out"], cn_a=prof["cn_a"], cn_m=prof["cn_m"],
                      K_a=b3.norm_K(prof["cn_a"], 9), K_m=b3.norm_K(prof["cn_m"], 9), shifts=prof["shifts"])
    P, rep = b3.solve_layer(W, stats[1], var, s_x, s_x, glob, {})
    rec = tc.Rec(len(ids))
    xq = tc.quantize_input(x, s_x, rec)
    y = bl.run_int(xq, P, rope_i, rec, 6)
    site = b3.site_errors(xq[:6], P, rope_i, W, rope_f)
    res[vn] = {"e_s": P.e_s, "sh_s": P.sh_s, "iso_cos": float(tc.cos_rows(y * s_x, xf_next).mean()),
               "iso_dcos": float(tc.cos_rows(y * s_x - xq * s_x, xf_next - x).mean()),
               "refused": int(sum(f is not None for f in rec.first)),
               "site": {k: round(v, 3) for k, v in site.items() if k in ("q", "k", "score", "prob", "o", "ao", "update")}}
    print(vn, json.dumps(res[vn]), flush=True)
(HERE / "runs" / "b5_layer1_score_class.json").write_text(json.dumps(res, indent=1))
