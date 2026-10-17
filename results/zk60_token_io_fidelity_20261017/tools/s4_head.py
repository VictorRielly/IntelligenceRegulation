#!/usr/bin/env python3
"""s4 (F1 + F2): the integer final norm + int8 LM head of DESIGN.md section 3, against the float head
(TOKEN_IO_SPEC float path) on the SAME integer stack output, and both against the float model.

F1, the integer head (rotated basis, exactly the design's form):
  * W' = lm_head diag(norm_weight) R^T (float64: forward rotation of each gamma-folded row);
  * per-tensor int8: s_w = max|W'| / 127, W'q = clip(floor(W' / s_w + 0.5), -127, 127) (tlcalib.qw);
    recorded alternative per output row: s_w[j] = max_i |W'[j, i]| / 127;
  * final norm = the block norm relation with a UNIFORM gain g0 (tlcalib.i_norm semantics, D24 tn 10):
    D = isqrt(sum x^2 + Ceps), y = floor((2 x g0 Cn + D 2^tn) / (2 D 2^tn)), y in [-127, 127] and both
    remainders below 2^32 or the position REFUSES (never clamped silently); Ceps = round(d eps / s_x^2)
    (= the profile's norm_ceps), (g0, Cn) from tlcalib.norm_site with c = 1 on the calibration maxima of
    the rotated xhat of the final residual, margin 0.5 (the export variant's margin) — the norm_a rule;
  * logits = the RAW int32 accumulators y . W'q_j (no requant); next token = numpy argmax (first maximum).
    Per-row alternative: the comparison multiplies row j by a public integer m_j = round(2^b s_w[j] / max s_w)
    (b in 4, 8, 12, 16) or, as the ideal, by the float s_w[j].
F2, per position of every held-out sequence (T 128 and T 32, 72 sequences each): top-1 agreement, exact
integer ties, integer margins, max |l| and the keyed difference window (2^15 (l_j - l_i) + (i - j), design
w = 41 bits), final-norm refusals, KL(float head || scaled integer head), and agreement with the float model.
Diagnostic sweep of Cn (margins 0.25 / 0 and the refusal-free Cn = 2^tn) to separate norm-output rounding
from head-weight rounding. Writes data/s4_head.json + data/s4_positions.npz. Calibration data, not a proof.
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

import b4_token_io as bt  # noqa: E402

tc, b3 = fc.tc, fc.b3

try:
    from threadpoolctl import threadpool_limits
except ImportError:  # pragma: no cover
    threadpool_limits = None

D_MODEL = tc.GEO.d
V_BITS = 15                 # V_pad = 2^15 >= 32000
W_DESIGN = 41               # design window for delta at TinyLlama
CHUNK = 512
VBLOCK = 8000
MULT_BITS = (4, 8, 12, 16)
SMOKE = "--smoke" in sys.argv     # T32 only, first 2 chunks, *_smoke outputs (a crash test, not a result)
SUFFIX = "_smoke" if SMOKE else ""


def final_norm(x: np.ndarray, g0: int, cn: int, tn: int, ceps: int, wrho: int):
    """tlcalib.i_norm with a uniform gain, on (n, d) int64 rows; per-ROW refusal flags."""
    ss = ceps + (x * x).sum(-1)
    D = tc.isqrt_vec(ss)
    a1 = ss - D * D
    a2 = 2 * D - a1
    dbad = (D < 1) | (D >= (1 << 24)) | (a1 < 0) | (a1 >= (1 << 24)) | (a2 < 0) | (a2 >= (1 << 24))
    D = np.maximum(D, 1)
    dv = D << tn
    den = (2 * dv)[:, None]
    num = 2 * x * (g0 * cn) + dv[:, None]
    q = num // den
    rho = num - q * den
    sigma = den - 1 - rho
    win = ((rho >= (1 << wrho)) | (sigma >= (1 << wrho))).any(-1)
    ybad = ((q < -127) | (q > 127)).any(-1)
    return q, dbad | win | ybad, {"y_bad": ybad, "window_bad": win, "d_bad": dbad}


def int_logits(y: np.ndarray, Wq: np.ndarray) -> np.ndarray:
    """Exact y . W'q_j (int8 x int8 sums over 2048 < 2^25, exact in float64)."""
    yf = y.astype(np.float64)
    out = np.empty((y.shape[0], Wq.shape[0]), dtype=np.int64)
    for v0 in range(0, Wq.shape[0], VBLOCK):
        out[:, v0:v0 + VBLOCK] = (yf @ Wq[v0:v0 + VBLOCK].astype(np.float64).T).astype(np.int64)
    return out


def log_softmax(L: np.ndarray) -> np.ndarray:
    L = L.astype(np.float64)
    L = L - L.max(-1, keepdims=True)
    return L - np.log(np.exp(L).sum(-1, keepdims=True))


def top2(L: np.ndarray):
    V = L.shape[-1]
    p = np.partition(L, V - 2, axis=-1)
    return p[:, V - 1], p[:, V - 2]


def keyed_stats(C: np.ndarray, a: np.ndarray):
    """Keyed-argmax difference delta_i = 2^v (C_j - C_i) + (i - j) at j = a (the first maximum).
    Returns (max delta, min delta over i != j) — the honest prover's window need and the strictness check."""
    V = C.shape[-1]
    mx = C[np.arange(C.shape[0]), a]
    dl = (mx[:, None] - C) * (1 << V_BITS) + (np.arange(V)[None, :] - a[:, None])
    dmax = dl.max(-1)
    dl[np.arange(C.shape[0]), a] = np.iinfo(np.int64).max
    return dmax, dl.min(-1)


def selftests(X: np.ndarray) -> dict:
    """R0-style checks: (1) final_norm == tlcalib.i_norm with a uniform gain (real rows + random int16 rows,
    extremes included); (2) the keyed argmax (kappa_i = 2^v l_i + (2^v - 1 - i)) picks numpy's first maximum
    and every honest delta_i (i != j) is > 0, on random vectors with forced ties."""
    rng = np.random.default_rng(20261017)
    xr = rng.integers(-32768, 32768, size=(64, D_MODEL), dtype=np.int64)
    xr[0] = 32767
    xr[1] = -32768
    xr[2] = 0
    xs = np.concatenate([X[:64].astype(np.int64), xr])
    out = {"final_norm_equals_i_norm": True}
    for cn in (1024, 3000, 65536):
        q, _, _ = final_norm(xs, 127, cn, 10, 74429, tc.norm_window(D_MODEL, 10))
        q2, _ = tc.i_norm(xs[None], np.full(D_MODEL, 127, dtype=np.int8), cn, 10, 74429, tc.norm_window(D_MODEL, 10),
                          tc.Rec(1), "t", 0, clamp=False)
        out["final_norm_equals_i_norm"] &= bool(np.array_equal(q, q2[0]))
    ok_arg, ok_delta, forced = True, True, 0
    for k in range(200):
        L = rng.integers(-2000, 2000, size=(4, 32000), dtype=np.int64)
        m = L.max(-1)
        for r in range(4):                    # force 1-3 extra copies of the maximum at random indices
            idx = rng.choice(32000, size=1 + (k + r) % 3, replace=False)
            L[r, idx] = m[r]
            forced += 1
        a = L.argmax(-1)
        kappa = L * (1 << V_BITS) + ((1 << V_BITS) - 1 - np.arange(32000))[None, :]
        ok_arg &= bool(np.array_equal(kappa.argmax(-1), a))
        _, dmin = keyed_stats(L, a)
        ok_delta &= bool((dmin > 0).all())
    out.update({"keyed_argmax_equals_numpy_first_max": ok_arg, "honest_delta_positive_off_argmax": ok_delta,
                "random_vectors": 800, "forced_tie_rows": forced})
    assert all(v for k, v in out.items() if isinstance(v, bool)), out
    return out


def build_heads(ck, rep: dict):
    nw = tc.tensor_f32(ck.refs["model.norm.weight"])
    lm = tc.tensor_f32(ck.refs["lm_head.weight"])
    R = b3.Rotation(D_MODEL, 1)
    assert np.array_equal(R.sign, fc.export_rotation(128))
    V = lm.shape[0]
    Wp = np.empty((V, D_MODEL), dtype=np.float64)
    for v0 in range(0, V, 4000):
        Wp[v0:v0 + 4000] = R.fwd(lm[v0:v0 + 4000].astype(np.float64) * nw.astype(np.float64)[None, :])
    s_t = float(np.abs(Wp).max()) / 127.0
    hrep = {}
    Wt = tc.qw(Wp, s_t, hrep, "head_per_tensor")
    row_max = np.abs(Wp).max(1)
    s_r = row_max / 127.0
    Wr = np.empty_like(Wt)
    clipped_r = 0
    for v0 in range(0, V, 4000):
        q = np.floor(Wp[v0:v0 + 4000] / s_r[v0:v0 + 4000, None] + 0.5)
        clipped_r += int((np.abs(q) > 127).sum())
        Wr[v0:v0 + 4000] = np.clip(q, -127, 127).astype(np.int8)
    lv = row_max / s_t        # int8 levels each row reaches under the per-tensor scale
    rep["head"] = {
        "form": "W' = lm_head diag(norm_weight) R^T (rotated basis), int8, raw int32 logits, no requant",
        "vocab": int(V), "d": int(D_MODEL),
        "per_tensor": {"s_w": s_t, "clipped": hrep["weights_clipped"]["head_per_tensor"],
                       "minus128": int((Wt == -128).sum()), "absmax_int": int(np.abs(Wt.astype(np.int16)).max()),
                       "row_absmax_levels_quantiles": {q: float(np.quantile(lv, q)) for q in (0.0, 0.01, 0.5, 0.99, 1.0)},
                       "sha256_int8_row_major": fc.sha_bytes(Wt.tobytes())},
        "per_row": {"s_w_min": float(s_r.min()), "s_w_max": float(s_r.max()), "s_w_ratio_max_min": float(s_r.max() / s_r.min()),
                    "clipped": clipped_r, "minus128": int((Wr == -128).sum()),
                    "sha256_int8_row_major": fc.sha_bytes(Wr.tobytes()),
                    "sha256_scales_f64": fc.sha_bytes(s_r.astype("<f8").tobytes())},
    }
    return nw, lm, Wp, Wt, Wr, s_t, s_r


def main():
    t0 = time.time()
    rep = {"scope": "calibration data, not a proof, not a privacy claim"}
    ck = tc.open_checkpoint()
    nw, lm, Wp, Wt, Wr, s_t, s_r = build_heads(ck, rep)
    fc.log(f"heads built: {rep['head']}")

    # ---------------- final-norm constants (norm_site with c = 1, the norm_a rule)
    prof = fc.export_profile(128)
    s_in, s_out = fc.export_scales(128)
    assert fc.export_scales(32) == (s_in, s_out)
    margin = float(prof["variant_options"]["margin"])
    tn = int(prof["profile_constants"]["norm_tn"])
    cal = np.load(fc.DATA / "calib_final_xhat.npz")
    nrep = {}
    g8, cn_cal, tn_s, ceps, s_y, _ = tc.norm_site(np.ones(D_MODEL), cal["ch_max_rot"], [], "final_norm",
                                                   tc.CalibOptions(margin=margin, tn=tn), s_out, nrep, "final_norm")
    assert tn_s == tn and np.all(g8 == g8[0])
    g0 = int(g8[0])
    assert ceps == int(prof["profile_constants"]["norm_ceps"]), (ceps, prof["profile_constants"]["norm_ceps"])
    wrho = tc.norm_window(D_MODEL, tn)
    amax = float(cal["ch_max_rot"].max())
    base = (2 ** tn) * math.sqrt(D_MODEL)
    cfgs = {"cal_m1.50": cn_cal,
            "diag_m1.25": int(math.floor(base / (1.25 * amax))),
            "diag_m1.00": int(math.floor(base / (1.00 * amax))),
            "diag_safe": 2 ** tn}          # g0 Cn = 127 2^tn: |y| <= 127 for every int16 input (D >= |x|)
    assert g0 == 127 and all(1 <= c <= 65536 for c in cfgs.values())
    rep["final_norm"] = {"g0": g0, "tn": tn, "ceps": int(ceps), "window_bits": int(wrho), "margin": margin,
                         "calib_xhat_rot_absmax": amax, "norm_site": nrep["final_norm"], "cn_configs": cfgs,
                         "K_configs": {k: base / c for k, c in cfgs.items()},
                         "xhat_rot_at_which_y_reaches_127": {k: 127.0 * (base / c) / g0 for k, c in cfgs.items()}}
    fc.log(f"final norm: g0 {g0} tn {tn} ceps {ceps} Cn {cfgs} (calib |xhat'| max {amax:.3f})")
    sign = fc.export_rotation(128)
    V = Wt.shape[0]
    mult = {b: np.maximum(1, np.floor((2 ** b) * s_r / s_r.max() + 0.5)).astype(np.int64) for b in MULT_BITS}

    # ---------------- fold check (F1): the rotated float head equals the spec float head
    X128 = np.load(fc.DATA / ("int_xout_T32.npy" if SMOKE else "int_xout_T128.npy")).reshape(-1, D_MODEL)
    rep["selftests"] = selftests(X128)
    fc.log(f"selftests {rep['selftests']}")
    xs = X128[:CHUNK].astype(np.float64) * s_out
    Lspec = bt.head_logits(X128[:CHUNK], s_out, nw, lm, sign).astype(np.float64)
    xh = xs / np.sqrt(np.mean(xs * xs, axis=-1, keepdims=True) + tc.GEO.eps)
    Lrot = xh @ Wp.T
    rep["fold_check"] = {"positions": CHUNK, "top1_agreement": float((Lspec.argmax(-1) == Lrot.argmax(-1)).mean()),
                         "max_abs_logit_diff": float(np.abs(Lspec - Lrot).max()),
                         "logit_absmax": float(np.abs(Lspec).max())}
    fc.log(f"fold check {rep['fold_check']}")
    del Wp, Lspec, Lrot, xh, xs

    # ---------------- per-position evaluation
    recs = {}
    for T in ((32,) if SMOKE else (128, 32)):
        X = (X128 if T == 128 else np.load(fc.DATA / f"int_xout_T{T}.npy").reshape(-1, D_MODEL)).astype(np.int64)
        XF = np.load(fc.DATA / f"float_final_T{T}.npy").reshape(-1, D_MODEL)
        ho = np.load(fc.DATA / f"tokens_heldout_T{T}.npz")
        N = ho["ids"].shape[0]
        r = {"seq": np.repeat(np.arange(N), T), "pos": np.tile(np.arange(T), N),
             "domain": np.repeat(ho["domains"], T)}
        if SMOKE:
            X, XF, r = X[:2 * CHUNK], XF[:2 * CHUNK], {k: v[:2 * CHUNK] for k, v in r.items()}
        n = X.shape[0]
        acc = {}

        def put(key, idx, val):
            if key not in acc:
                acc[key] = np.zeros(n, dtype=np.asarray(val).dtype)
            acc[key][idx] = val

        for c0 in range(0, n, CHUNK):
            tc0 = time.time()
            sl = slice(c0, min(n, c0 + CHUNK))
            xi = X[sl]
            Lf = bt.head_logits(xi.astype(np.int16), s_out, nw, lm, sign)          # float head, same int output
            Lm = tc.f_head(XF[sl], nw, lm)                                          # float model
            af, am = Lf.argmax(-1), Lm.argmax(-1)
            f1, f2 = top2(Lf)
            put("float_head_tok", sl, af)
            put("float_model_tok", sl, am)
            put("float_head_margin", sl, (f1 - f2).astype(np.float64))
            lsf = log_softmax(Lf)
            pf = np.exp(lsf)
            rows = np.arange(xi.shape[0])
            for name, cn in cfgs.items():
                y, refused, why = final_norm(xi, g0, cn, tn, ceps, wrho)
                put(f"{name}/refused", sl, refused)
                put(f"{name}/y_absmax", sl, np.abs(y).max(-1))
                yc = np.clip(y, -127, 127)          # clamped ONLY to continue past a refusal (diagnostic)
                K = base / cn
                # per-tensor head
                Lt = int_logits(yc, Wt)
                at = Lt.argmax(-1)
                t1, t2 = top2(Lt)
                put(f"{name}/pt_tok", sl, at)
                put(f"{name}/pt_ties", sl, (Lt == t1[:, None]).sum(-1) - 1)
                put(f"{name}/pt_margin", sl, t1 - t2)
                put(f"{name}/pt_absmax", sl, np.abs(Lt).max(-1))
                if name == "cal_m1.50":
                    dmax, dmin = keyed_stats(Lt, at)
                    put("pt_delta_max", sl, dmax)
                    put("pt_delta_min_other", sl, dmin)
                    put("pt_float_regret", sl, (Lf[rows, af] - Lf[rows, at]).astype(np.float64))
                    put("pt_float_rank", sl, (Lf > Lf[rows, at][:, None]).sum(-1))
                lsi = log_softmax(Lt.astype(np.float64) * (s_t * K / g0))
                put(f"{name}/pt_kl", sl, (pf * (lsf - lsi)).sum(-1))
                del Lt, lsi
                # per-row head: ideal float scaling and integer multipliers
                Lr = int_logits(yc, Wr)
                Cr = Lr.astype(np.float64) * s_r[None, :]
                put(f"{name}/pr_exact_tok", sl, Cr.argmax(-1))
                lsi = log_softmax(Cr * (K / g0))
                put(f"{name}/pr_exact_kl", sl, (pf * (lsf - lsi)).sum(-1))
                del Cr, lsi
                for b in (MULT_BITS if name == "cal_m1.50" else ()):
                    C = Lr * mult[b][None, :]
                    ab = C.argmax(-1)
                    b1, _ = top2(C)
                    put(f"{name}/pr_m{b}_tok", sl, ab)
                    put(f"{name}/pr_m{b}_ties", sl, (C == b1[:, None]).sum(-1) - 1)
                    if name == "cal_m1.50":
                        dmax, dmin = keyed_stats(C, ab)
                        put(f"pr_m{b}_delta_max", sl, dmax)
                        put(f"pr_m{b}_delta_min_other", sl, dmin)
                    del C
                del Lr
            del Lf, Lm, lsf, pf
            fc.log(f"  T{T} positions {sl.start}-{sl.stop} of {n} ({time.time() - tc0:.1f}s)")
        r.update(acc)
        recs[T] = r
    np.savez_compressed(fc.DATA / f"s4_positions{SUFFIX}.npz",
                        **{f"T{T}/{k}": v for T, r in recs.items() for k, v in r.items()})

    # ---------------- summaries
    def agree(a, b, m):
        return {"agree": int((a[m] == b[m]).sum()), "n": int(m.sum()), "rate": float((a[m] == b[m]).mean()) if m.any() else None}

    summ = {}
    for T, r in recs.items():
        last = r["pos"] == (T - 1)
        sets = {"all": np.ones_like(last), "last_position": last}
        for dom in np.unique(r["domain"]):
            sets[f"domain:{dom}"] = r["domain"] == dom
        S = {}
        for sname, m in sets.items():
            m = m.astype(bool)
            e = {"positions": int(m.sum()),
                 "float_head_vs_float_model": agree(r["float_head_tok"], r["float_model_tok"], m)}
            for name in cfgs:
                ok = m & ~r[f"{name}/refused"]
                e[name] = {
                    "refused_positions": int((m & r[f"{name}/refused"]).sum()),
                    "int_pt_vs_float_head": agree(r[f"{name}/pt_tok"], r["float_head_tok"], m),
                    "int_pt_vs_float_head_accepted_only": agree(r[f"{name}/pt_tok"], r["float_head_tok"], ok),
                    "int_pt_vs_float_model": agree(r[f"{name}/pt_tok"], r["float_model_tok"], m),
                    "int_pr_exact_vs_float_head": agree(r[f"{name}/pr_exact_tok"], r["float_head_tok"], m),
                    "int_pr_exact_vs_float_model": agree(r[f"{name}/pr_exact_tok"], r["float_model_tok"], m),
                    **{f"int_pr_m{b}_vs_float_head": agree(r[f"{name}/pr_m{b}_tok"], r["float_head_tok"], m)
                       for b in (MULT_BITS if name == "cal_m1.50" else ())},
                    "pt_tie_positions": int((m & (r[f"{name}/pt_ties"] > 0)).sum()),
                    "pt_kl_mean": float(r[f"{name}/pt_kl"][m].mean()),
                    "pr_exact_kl_mean": float(r[f"{name}/pr_exact_kl"][m].mean()),
                    "y_absmax": int(r[f"{name}/y_absmax"][m].max()),
                }
            S[sname] = e
        cal_ = "cal_m1.50"
        dis = r[f"{cal_}/pt_tok"] != r["float_head_tok"]
        fm = r["float_head_margin"]
        mg = r[f"{cal_}/pt_margin"]
        edges = [0, 1, 2, 4, 16, 64, 256, 1024, 4096, 1 << 62]
        hist = {f"[{edges[i]},{edges[i + 1]})": int(((mg >= edges[i]) & (mg < edges[i + 1])).sum()) for i in range(len(edges) - 1)}
        fedges = [0.0, 0.01, 0.03, 0.1, 0.3, 1.0, 3.0, 1e9]
        fdis = {f"[{fedges[i]},{fedges[i + 1]})": {"positions": int(((fm >= fedges[i]) & (fm < fedges[i + 1])).sum()),
                                                   "disagree": int((dis & (fm >= fedges[i]) & (fm < fedges[i + 1])).sum())}
                for i in range(len(fedges) - 1)}
        K = base / cfgs[cal_]
        S["details_cal"] = {
            "int_margin_hist_l1_minus_l2": hist,
            "int_margin_float_units_per_lsb": s_t * K / g0,
            "tie_positions": int((r[f"{cal_}/pt_ties"] > 0).sum()),
            "tie_positions_decided_by_lowest_index": int((r[f"{cal_}/pt_ties"] > 0).sum()),
            "max_abs_logit": int(r[f"{cal_}/pt_absmax"].max()),
            "max_abs_logit_bits": float(math.log2(max(1, int(r[f"{cal_}/pt_absmax"].max())))),
            "bound_d_127sq": D_MODEL * 127 * 127,
            "keyed_delta_max": int(r["pt_delta_max"].max()),
            "keyed_delta_bits_needed": int(int(r["pt_delta_max"].max()).bit_length()),
            "keyed_delta_window_bits_design": W_DESIGN,
            "keyed_delta_fits_window": bool(int(r["pt_delta_max"].max()) < (1 << W_DESIGN)),
            "keyed_delta_min_over_i_ne_j": int(r["pt_delta_min_other"].min()),
            "per_row_multiplier_delta_bits": {b: int(int(r[f"pr_m{b}_delta_max"].max()).bit_length()) for b in MULT_BITS},
            "per_row_multiplier_delta_min_over_i_ne_j": {b: int(r[f"pr_m{b}_delta_min_other"].min()) for b in MULT_BITS},
            "per_row_multiplier_tie_positions": {b: int((r[f"{cal_}/pr_m{b}_ties"] > 0).sum()) for b in MULT_BITS},
            "disagreements": int(dis.sum()),
            "disagreement_by_float_head_margin": fdis,
            "disagreement_float_rank_hist": {int(k): int(v) for k, v in zip(*np.unique(r["pt_float_rank"][dis], return_counts=True))},
            "disagreement_float_regret_quantiles": ({q: float(np.quantile(r["pt_float_regret"][dis], q)) for q in (0.5, 0.9, 1.0)}
                                                    if dis.any() else None),
            "float_head_margin_quantiles": {q: float(np.quantile(fm, q)) for q in (0.01, 0.05, 0.5)},
        }
        summ[f"T{T}"] = S
    # pooled over both context lengths
    pooled = {}
    for name in cfgs:
        a = np.concatenate([recs[T][f"{name}/pt_tok"] for T in recs])
        f = np.concatenate([recs[T]["float_head_tok"] for T in recs])
        pr = np.concatenate([recs[T][f"{name}/pr_exact_tok"] for T in recs])
        rf = np.concatenate([recs[T][f"{name}/refused"] for T in recs])
        m = np.ones_like(rf)
        pooled[name] = {"int_pt_vs_float_head": agree(a, f, m), "int_pr_exact_vs_float_head": agree(pr, f, m),
                        "refused_positions": int(rf.sum())}
        if name == "cal_m1.50":
            for b in MULT_BITS:
                pb = np.concatenate([recs[T][f"{name}/pr_m{b}_tok"] for T in recs])
                pooled[name][f"int_pr_m{b}_vs_float_head"] = agree(pb, f, m)
    summ["pooled_T128_T32"] = pooled
    rep["summary"] = summ
    rep["seconds"] = time.time() - t0
    (fc.DATA / f"s4_head{SUFFIX}.json").write_text(fc.jdump(rep))
    fc.log(f"pooled: {json.dumps(pooled)}")
    fc.log(f"done ({rep['seconds']:.0f}s)")


if __name__ == "__main__":
    if threadpool_limits is not None:
        with threadpool_limits(limits=2):
            main()
    else:
        main()
