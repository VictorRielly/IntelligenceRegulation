#!/usr/bin/env python3
"""Diagnostic: why the Llama-3-8B b7 export refuses WikiText-2 windows at layer 0 (site V).
Runs the calibration lane's own tlcalib.i_block (not fp_lib) on 4 WikiText windows and 4 FineWeb
documents; reports the V range violations by token, the pre-clamp |V| maximum and the class bound."""
import json, sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl, fp_data
from fp_lib import tc, GEO
from fp_selfcheck import layerint
ex = fl.Export(Path(sys.argv[1]))
T = ex.T
ids, meta, mask, info = fp_data.build(fl.MODEL, T, "fineweb:4,wikitext:4")
Lw = ex.layer(0)
P = layerint(Lw)
rope = (Lw["w"]["rope_cos"].reshape(T, -1).astype(np.int64), Lw["w"]["rope_sin"].reshape(T, -1).astype(np.int64))
x = np.asarray(ex.embedding_table()[ids.reshape(-1)], dtype=np.int64).reshape(*ids.shape, GEO.d)
# pre-clamp V
M = P.mats()
y, _ = tc.i_norm(x, P.gamma_a, P.cn_a, P.tn, P.ceps, P.norm_wrho, tc.Rec(len(ids)), "norm_a", 0, True)
v = tc.requant(M["v"](y), P.sh_qkv)
bad = np.abs(v) > 127
from tokenizers import Tokenizer
tk = Tokenizer.from_file("/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json")
out = {"export": str(ex.root), "v_absmax_per_seq": np.abs(v).reshape(len(ids), -1).max(1).tolist(), "class": 127, "offending": {}}
for i in range(len(ids)):
    pos = np.nonzero(bad[i].any(-1))[0]
    toks = [int(ids[i, p]) for p in pos]
    for t in toks:
        out["offending"].setdefault(tk.id_to_token(t), 0)
        out["offending"][tk.id_to_token(t)] += 1
    print(meta[i]["corpus"], "max|V|", int(np.abs(v[i]).max()), "violating positions", len(pos), "tokens", sorted(set(tk.id_to_token(t) for t in toks))[:10])
r = tc.Rec(len(ids))
tc.i_block(x, P, rope, r)
out["i_block_refusals"] = r.summary()["first_refusal_sites"]
out["i_block_refused"] = r.summary()["sequences_refused"]
print(json.dumps(out, indent=1)[:1500])
(fl.HERE / "runs" / fl.MODEL / "diag_v0.json").write_text(json.dumps(out, indent=1))
