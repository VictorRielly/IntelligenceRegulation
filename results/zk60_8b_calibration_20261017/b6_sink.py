#!/usr/bin/env python3
"""B6 diagnostic (FLOAT ONLY, no integer path, no export): how much of layer 1's score / Q / K range is the
BOS attention sink? Same calibration (B5 T=32: 27 licence + 27 FineWeb seqs) and the 36 FineWeb held-out
seqs of B6-2, rotated basis (seed 1), layer 0 then layer 1 in float. Reports, per query head and overall:
max |raw score| on the full T x T rectangle (what the native int8 score range must hold), the same without
the BOS key column t'=0, and without both BOS row and column; the e_s each implies (margin 1.25, int8 127);
the K / Q per-(head, RoPE pair) range with and without position 0; the softmax mass on BOS.
Writes runs/b6_sink_layer1.json. Calibration data only."""
import json
import math
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import b5_8b as m  # noqa: E402  (sets ZK60_MODEL=llama3-8b and thread env before numpy; imports tlcalib / b3calib / b3_ladder)
import numpy as np  # noqa: E402

tc, b3, bl = m.tc, m.b3, m.bl
G = tc.GEO


def e_s(x, m2=1.25):
    return int(math.ceil(math.log2(x * m2 / 127.0) - 1e-9))


def pairmax(a, heads):            # (..., heads, dh) abs max over leading axes -> (heads, half) RoPE-pair max
    r = np.abs(a).reshape(-1, heads, G.dh).max(0)
    return np.maximum(r[:, :G.half], r[:, G.half:])


def main():
    t0 = time.time()
    T = 32
    tok = m.HFTokenizer(Path(sys.argv[1]))
    cal, _ = m.text_sequences(tok, "calib", T, 3)
    c2, _ = m.fineweb_sequences(tok, "calib", T, 27)
    ho, _ = m.fineweb_sequences(tok, "heldout", T, 36)
    sets = {"calibration": np.array(cal + c2, dtype=np.int64), "heldout_fineweb": np.array(ho, dtype=np.int64)}
    ck = tc.open_checkpoint()
    R = b3.Rotation(G.d, 1)
    eref = ck.refs["model.embed_tokens.weight"]
    eraw = np.frombuffer(eref.read_bytes(max_bytes=eref.end - eref.start), dtype="<u2")
    rope = tc.rope_f32(T)
    W0, W1 = bl.load_layer(ck, 0, R), bl.load_layer(ck, 1, R)
    out = {"model": m.MODEL, "T": T, "rotation_seed": 1, "scope": "float diagnostic, calibration data only"}
    for name, ids in sets.items():
        x = m.bf16_rows(eraw, ids.reshape(-1), G.d).reshape(*ids.shape, -1)
        x = R.fwd(x.reshape(-1, G.d)).astype(np.float32).reshape(x.shape)
        raw_all = np.zeros(G.H); raw_nocol = np.zeros(G.H); raw_norowcol = np.zeros(G.H); raw_causal_nobos = np.zeros(G.H)
        kmax_all = np.zeros((G.KV, G.half)); kmax_nb = np.zeros((G.KV, G.half))
        qmax_all = np.zeros((G.H, G.half)); qmax_nb = np.zeros((G.H, G.half))
        mass, cnt = np.zeros(G.H), 0
        tri = np.tril(np.ones((T, T), dtype=bool))
        # signed extremes (B6 22:1xZ): which sign / region sets the symmetric int8 score range
        sg = {k: np.full(G.H, -np.inf) for k in ("pos_full", "neg_full", "pos_causal", "neg_causal", "pos_causal_bos_col",
                                                  "pos_causal_diag", "pos_causal_offdiag_nobos")}
        eye = np.eye(T, dtype=bool)
        for s in range(0, len(x), 8):
            x1 = tc.f_block(x[s:s + 8], W0, *rope)
            _, P = b3._f_block_parts(x1, W1, *rope, G)
            rw = P["raw"]                                            # (N, KV, G, T, T) signed
            hmx = lambda a: a.max(axis=(0, 3, 4)).reshape(-1)
            ninf = np.float32(-np.inf)
            sg["pos_full"] = np.maximum(sg["pos_full"], hmx(rw))
            sg["neg_full"] = np.maximum(sg["neg_full"], hmx(-rw))
            sg["pos_causal"] = np.maximum(sg["pos_causal"], hmx(np.where(tri, rw, ninf)))
            sg["neg_causal"] = np.maximum(sg["neg_causal"], hmx(np.where(tri, -rw, ninf)))
            sg["pos_causal_bos_col"] = np.maximum(sg["pos_causal_bos_col"], hmx(rw[..., :, :1]))
            sg["pos_causal_diag"] = np.maximum(sg["pos_causal_diag"], hmx(np.where(eye, rw, ninf)))
            off = tri & ~eye
            off[:, 0] = False
            sg["pos_causal_offdiag_nobos"] = np.maximum(sg["pos_causal_offdiag_nobos"], hmx(np.where(off, rw, ninf)))
            raw = np.abs(rw)                                         # (N, KV, G, T, T)
            hm = lambda a: a.max(axis=(0, 3, 4)).reshape(-1)
            raw_all = np.maximum(raw_all, hm(raw))
            raw_nocol = np.maximum(raw_nocol, hm(raw[..., 1:]))
            raw_norowcol = np.maximum(raw_norowcol, hm(raw[..., 1:, 1:]))
            raw_causal_nobos = np.maximum(raw_causal_nobos, hm(np.where(tri, raw, 0)[..., 1:, 1:]))
            kr, qr = tc.f_rope(P["k"], *rope), tc.f_rope(P["q"], *rope)   # (N, T, heads, dh)
            kmax_all = np.maximum(kmax_all, pairmax(kr, G.KV)); kmax_nb = np.maximum(kmax_nb, pairmax(kr[:, 1:], G.KV))
            qmax_all = np.maximum(qmax_all, pairmax(qr, G.H)); qmax_nb = np.maximum(qmax_nb, pairmax(qr[:, 1:], G.H))
            lg = np.where(tri, P["raw"] / np.float32(math.sqrt(G.dh)), -np.inf)
            lg -= lg.max(-1, keepdims=True)
            p = np.exp(lg); p /= p.sum(-1, keepdims=True)
            mass += p[..., 1:, 0].sum(axis=(0, 3)).reshape(-1); cnt += p.shape[0] * (T - 1)
        r = lambda a: [round(float(v), 1) for v in a]
        out[name] = {
            "sequences": int(len(ids)),
            "raw_score_absmax": {"full_rectangle": float(raw_all.max()), "without_bos_key_column": float(raw_nocol.max()),
                                 "without_bos_row_and_column": float(raw_norowcol.max()),
                                 "causal_without_bos": float(raw_causal_nobos.max())},
            "e_s_implied_margin_1.25": {"full_rectangle": e_s(raw_all.max()), "without_bos_key_column": e_s(raw_nocol.max()),
                                        "without_bos_row_and_column": e_s(raw_norowcol.max())},
            "per_head": {"raw_full": r(raw_all), "raw_without_bos_column": r(raw_nocol),
                         "e_s_full": [e_s(v) for v in raw_all], "e_s_without_bos_column": [e_s(v) for v in raw_nocol],
                         "softmax_mass_on_bos_mean": [round(float(v), 3) for v in mass / cnt]},
            "k_pair_range_ratio_all_over_no_bos": {"max": float((kmax_all / kmax_nb).max()), "median": float(np.median(kmax_all / kmax_nb))},
            "q_pair_range_ratio_all_over_no_bos": {"max": float((qmax_all / qmax_nb).max()), "median": float(np.median(qmax_all / qmax_nb))},
            "softmax_mass_on_bos_mean_all_heads": float((mass / cnt).mean()),
            "signed_extremes": {"overall": {k: float(v.max()) for k, v in sg.items()},
                                "per_head": {k: r(v) for k, v in sg.items()},
                                "note": "neg_* are max of -raw (magnitude of the most negative score); pos_causal_bos_col is "
                                        "the BOS key column (always causal); diag = a token with itself"},
        }
        print(name, "signed", json.dumps(out[name]["signed_extremes"]["overall"]), flush=True)
        print(name, json.dumps(out[name]["raw_score_absmax"]), out[name]["e_s_implied_margin_1.25"],
              "K ratio", out[name]["k_pair_range_ratio_all_over_no_bos"], "Q ratio", out[name]["q_pair_range_ratio_all_over_no_bos"],
              "BOS mass", round(out[name]["softmax_mass_on_bos_mean_all_heads"], 3), flush=True)
    out["seconds"] = time.time() - t0
    (HERE / "runs" / "b6_sink_layer1.json").write_text(json.dumps(out, indent=1))
    print(f"done ({out['seconds']:.0f}s)")


if __name__ == "__main__":
    from threadpoolctl import threadpool_limits
    with threadpool_limits(limits=4):
        main()
