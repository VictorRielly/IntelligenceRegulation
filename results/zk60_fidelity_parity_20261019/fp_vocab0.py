#!/usr/bin/env python3
"""Vocabulary-wide layer-0 range check of an export (exact, integer).

At layer 0 the norm output and the Q / K / V planes of a position depend on
that position's token ALONE (no mixing happens before V; Q and K only get
rotated by RoPE). So every vocabulary token can be checked exhaustively:
  * norm_a: denominator window and the int8 quotient (tlcalib.i_norm, exact);
  * Q, K, V: requant to int8 (exact int64 products of the export's words);
  * QR, KR (RoPE): a per-pair bound |rot| <= round(|pair| * max_t sqrt(c_t^2 + s_t^2) / 2^f_ro);
    tokens whose bound exceeds 127 are re-checked exactly at every position t < T.
Scores (q . k across two tokens and positions) are NOT exhaustive; a loose bound
over all token pairs is reported for information only.

  [ZK60_MODEL=llama3-8b] python3 fp_vocab0.py EXPORT_DIR
Writes runs/<model>/vocab0_<export>.json: every refusing token with its sites
and the worst margins. Fidelity/completeness data, not a proof.
"""
import json
import sys
import time
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fp_lib as fl  # noqa: E402
import fp_data  # noqa: E402
from fp_lib import tc, GEO  # noqa: E402


def main():
    root = Path(sys.argv[1])
    t0 = time.time()
    ex = fl.Export(root)
    T = ex.T
    Lw = ex.layer(0)
    w, c = Lw["w"], Lw["c"]
    V = int(fl.checkpoint().config["vocab"]) if "vocab" in fl.checkpoint().config else None
    try:
        tab = ex.embedding_table()
        V = tab.shape[0]
        get = lambda a, b: np.asarray(tab[a:b], dtype=np.int64)  # noqa: E731
        src = "export embedding table"
    except FileNotFoundError:
        ref = fl.checkpoint().refs["model.embed_tokens.weight"]
        V = ref.shape[0]
        get = lambda a, b: np.floor(ex.R.fwd(fl.emb_rows(np.arange(a, b))).astype(np.float32).astype(np.float64)  # noqa: E731
                                    / ex.s_in[0] + 0.5).astype(np.int64)
        src = "TOKEN_IO_SPEC rule from the checkpoint rows"
    mats = {n: tc.ExactMat(np.ascontiguousarray(w[n].T)) for n in ("wq", "wk", "wv")}
    half = GEO.dh // 2
    cos = w["rope_cos"].reshape(T, half).astype(np.float64)
    sin = w["rope_sin"].reshape(T, half).astype(np.float64)
    rmax = np.sqrt(cos ** 2 + sin ** 2).max(0)                        # per frequency, over positions
    sc = float(1 << int(c["f_ro"]))
    bad = {}
    worst = {"y": 0, "Q": 0, "K": 0, "V": 0, "QR_bound": 0, "KR_bound": 0}
    qpair_max = np.zeros((GEO.H, half))
    kpair_max = np.zeros((GEO.KV, half))
    B = 4096
    for a in range(0, V, B):
        b = min(V, a + B)
        x = get(a, b)[:, None, :]
        if np.abs(x).max() > 32767:
            raise ValueError("embedding outside int16")
        rec = tc.Rec(b - a)
        y, _ = tc.i_norm(x, w["gamma_a"], int(c["norm_cn_a"]), int(c["norm_tn"]), int(c["norm_ceps"]), c["wrho"], rec, "norm_a", 0, False)
        nb = [i for i, f in enumerate(rec.first) if f]
        for i in nb:
            bad.setdefault(a + i, set()).add(rec.first[i])
        worst["y"] = max(worst["y"], int(np.abs(y).max()))
        for n, site in (("wq", "Q"), ("wk", "K"), ("wv", "V")):
            v = tc.requant(mats[n](y), int(c["sh_qkv"]))[:, 0, :]
            worst[site] = max(worst[site], int(np.abs(v).max()))
            for i in np.nonzero((np.abs(v) > 127).any(-1))[0]:
                bad.setdefault(a + int(i), set()).add(site)
            if site in ("Q", "K"):
                heads = GEO.H if site == "Q" else GEO.KV
                vv = np.clip(v, -127, 127).reshape(-1, heads, GEO.dh).astype(np.float64)
                pn = np.sqrt(vv[..., :half] ** 2 + vv[..., half:] ** 2)          # (B, heads, half)
                bound = np.floor(pn * rmax[None, None, :] / sc + 0.5)
                worst[site + "R_bound"] = max(worst[site + "R_bound"], int(bound.max()))
                (qpair_max if site == "Q" else kpair_max)[:] = np.maximum(qpair_max if site == "Q" else kpair_max, pn.max(0))
                for i in np.nonzero((bound > 127).any(-1).any(-1))[0]:
                    # exact over every position
                    ai = vv[i, :, :half][None]                                  # (1, heads, half)
                    bi = vv[i, :, half:][None]
                    r1 = np.floor((cos[:, None, :] * ai - sin[:, None, :] * bi) / sc + 0.5)
                    r2 = np.floor((sin[:, None, :] * ai + cos[:, None, :] * bi) / sc + 0.5)
                    if max(np.abs(r1).max(), np.abs(r2).max()) > 127:
                        bad.setdefault(a + int(i), set()).add(site + "R")
        if a % (8 * B) == 0:
            fl.log(f"tokens {a}..{b}: refusing so far {len(bad)} ({time.time() - t0:.0f}s)")
    # loose score bound over all token pairs (information only)
    G = GEO.G
    sb = 0.0
    for h in range(GEO.H):
        sb = max(sb, float((qpair_max[h] * kpair_max[h // G]).sum()))
    s_bound = int(np.floor(sb * 1.0 / float(1 << int(c["sh_s"])) + 0.5))
    tok = fp_data.Tok(fl.MODEL)
    dec = (lambda t: tok.tk.id_to_token(t)) if fl.IS8B else (lambda t: tok.tk.decode([t]))
    rows = [{"token": t, "text": dec(t), "sites": sorted(v)} for t, v in sorted(bad.items())]
    out = {"export": str(root), "profile_sha256": fl.sha_file(root / "profile.json"), "vocab": V, "input": src,
           "refusing_tokens": len(rows), "by_site": {s: sum(1 for r in rows if s in r["sites"]) for s in sorted({x for r in rows for x in r["sites"]})},
           "worst_abs": worst, "class_int8": 127,
           "score_bound_all_token_pairs_loose": s_bound, "score_class": 127, "rows": rows, "seconds": time.time() - t0,
           "scope": "layer 0 only (exhaustive over the vocabulary for norm_a / Q / K / V / RoPE); later layers depend on context"}
    p = fl.HERE / "runs" / fl.MODEL / f"vocab0_{root.name}.json"
    p.write_text(json.dumps(out, indent=1, ensure_ascii=False))
    fl.log(f"refusing tokens at layer 0: {len(rows)} of {V}; by site {out['by_site']}; worst {worst}; loose score bound {s_bound}")
    for r in rows[:40]:
        fl.log(f"  {r}")
    fl.log(f"done ({time.time() - t0:.0f}s) -> {p}")


if __name__ == "__main__":
    main()
