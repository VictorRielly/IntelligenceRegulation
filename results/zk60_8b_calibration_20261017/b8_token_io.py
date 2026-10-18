#!/usr/bin/env python3
"""B8: Llama-3-8B token I/O artifacts for rung R3 of the next-token proof (coordinator 2026-10-18 01:4xZ).

Same format and rules as the TinyLlama R2 inputs (results/zk60_1b_calibration_20260929/export/TOKEN_IO_SPEC.md,
b4_token_io.py; the fidelity lane's results/zk60_token_io_fidelity_20261017/tools/s4_head.py build_heads and
final-norm rule; results/zk60_token_io_r1_20261017/tools/export_head_r2.py file layout), at 8B:

  (1) embedding_int16.bin [128256, 4096] int16 LE: x_in_L00[t] = table[t] = floor(float64(float32(E[t] R^T)) / s_in
      + 0.5) (float32 bf16 widening, float64 forward rotation, cast to float32, round half up; refuse outside
      int16), checked against every exported sequence's x_in_L00 AND the run's whole held-out integer input chain;
  (2) the folded head W' = lm_head diag(norm_weight) R^T (float64), per-row int8 W'q_j = clip(floor(W'_j / s_j
      + 0.5), -127, 127), s_j = max_i |W'_j,i| / 127, and 12-bit integer multipliers m_j = max(1, floor(2^12 s_j /
      max s + 0.5)) (D25 T4 as amended): head_int8_perrow.bin, head_mult12.bin; the final norm (block norm relation,
      uniform gain g0) with (g0, Cn) from tlcalib.norm_site(c = 1) on the calibration maxima of the rotated xhat of
      the final residual at the export variant's margin, tn = the profile's (9 at width 4096), Ceps = the
      profile's; the refusal-free Cn = 2^tn recorded beside it;
  (3) F2 fidelity on the run's held-out sequences: integer head (final norm -> raw int logits l_j = y . W'q_j ->
      C_j = m_j l_j -> first maximum) vs the float head (TOKEN_IO_SPEC float path) on the SAME integer stack
      output: overall, at float top-2 margin >= 0.3 logits (D25 T4: must be 100%), by domain, last position;
      final-norm refusals; exact ties in C; max |l| and max |C| bits; the keyed window delta_i = 2^17 (C_j - C_i) +
      (i - j) (max bits vs the 56-bit window; min over i != j must be > 0).

Modes:  b8_token_io.py build <export_dir> <run_dir>              (computes everything; T128 first)
        b8_token_io.py reuse <export_dir> <run_dir> <token_io_dir_of_a_build>
        (hard-links the byte-identical shared files after checking scales / rotation / digests; F2 at this T)
Writes <export_dir>/token_io/ (must not exist). Public model data + calibration data; not a proof.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import b5_8b as m  # noqa: E402  (ZK60_MODEL=llama3-8b + thread env before numpy; tlcalib / b3calib / b3_ladder)
import numpy as np  # noqa: E402

tc, b3, bl = m.tc, m.b3, m.bl
G = tc.GEO
D = G.d
V_BITS = 17                     # V_pad = 2^17 >= 128256
MULT_BITS = 12
BOS = m.BOS
VB = 4096                       # vocab block
PCH = 128                       # position chunk
SHARED = ("embedding_int16.bin", "head_int8_perrow.bin", "head_mult12.bin", "calib_final_xhat_rot_absmax.bin")


def log(s):
    print(f"[{time.strftime('%H:%M:%SZ', time.gmtime())}] {s}", flush=True)


def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()


def sha_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blk in iter(lambda: f.read(1 << 24), b""):
            h.update(blk)
    return h.hexdigest()


def window_bits(d, V, mult_bits):
    return int(((1 << V_BITS) * 2 * d * 127 * 127 * (1 << mult_bits) + V - 1).bit_length())


def raw_u16(ck, name):
    ref = ck.refs[name]
    return np.frombuffer(ref.read_bytes(max_bytes=ref.end - ref.start), dtype="<u2").reshape(ref.shape)


def f32_rows(raw, v0, v1):
    return (raw[v0:v1].astype(np.uint32) << 16).view(np.float32)


def final_norm(x, g0, cn, tn, ceps, wrho):
    """s4_head.final_norm (= tlcalib.i_norm with a uniform gain) on (n, d) int64 rows; per-row refusal flags."""
    ss = ceps + (x * x).sum(-1)
    Dv = tc.isqrt_vec(ss)
    a1 = ss - Dv * Dv
    a2 = 2 * Dv - a1
    dbad = (Dv < 1) | (Dv >= (1 << 24)) | (a1 < 0) | (a1 >= (1 << 24)) | (a2 < 0) | (a2 >= (1 << 24))
    Dv = np.maximum(Dv, 1)
    dv = Dv << tn
    den = (2 * dv)[:, None]
    num = 2 * x * (g0 * cn) + dv[:, None]
    q = num // den
    rho = num - q * den
    sigma = den - 1 - rho
    win = ((rho >= (1 << wrho)) | (sigma >= (1 << wrho))).any(-1)
    ybad = ((q < -127) | (q > 127)).any(-1)
    return q, dbad | win | ybad


def int_logits(y, Wq):
    """exact y . W'q_j (|sum| <= 4096 * 127^2 < 2^53: exact in float64)."""
    yf = y.astype(np.float64)
    out = np.empty((y.shape[0], Wq.shape[0]), dtype=np.int64)
    for v0 in range(0, Wq.shape[0], VB):
        out[:, v0:v0 + VB] = (yf @ Wq[v0:v0 + VB].astype(np.float64).T).astype(np.int64)
    return out


def float_head(X, s_out, R, nw, lm_raw):
    """TOKEN_IO_SPEC float path on int16 stack outputs X (n, d): float64(X) s_out -> R inverse (float64) -> float32
    -> float32 RMSNorm (mean(x*x) float32, + eps, sqrt) * norm_weight -> float32 logits (vocab blocks)."""
    x = R.inv(X.astype(np.float64) * s_out).astype(np.float32)
    var = np.mean(x * x, axis=-1, keepdims=True, dtype=np.float32)
    h = (x / np.sqrt(var + np.float32(G.eps))).astype(np.float32) * nw
    out = np.empty((X.shape[0], lm_raw.shape[0]), dtype=np.float32)
    for v0 in range(0, lm_raw.shape[0], 16384):
        out[:, v0:v0 + 16384] = h @ f32_rows(lm_raw, v0, v0 + 16384).T
    return out


def top2(L):
    p = np.partition(L, L.shape[-1] - 2, axis=-1)
    return p[:, -1], p[:, -2]


def keyed_stats(C, a):
    V = C.shape[-1]
    mx = C[np.arange(C.shape[0]), a]
    dl = (mx[:, None] - C) * (1 << V_BITS) + (np.arange(V)[None, :] - a[:, None])
    dmax = dl.max(-1)
    dl[np.arange(C.shape[0]), a] = np.iinfo(np.int64).max
    return dmax, dl.min(-1)


def export_info(root: Path):
    prof = json.loads((root / "profile.json").read_text())
    meta = prof["metadata_out_of_proof"]
    pc = prof["profile_constants"]
    raw = (root / "rotation_sign.bin").read_bytes()
    assert sha_bytes(raw) == meta["rotation"]["sign_sha256"]
    R = b3.Rotation(D, int(meta["rotation"]["seed"]))
    assert np.array_equal(R.sign, np.frombuffer(raw, dtype="<f8")), "rotation_sign.bin is not Rotation(4096, seed)"
    return {"prof": prof, "s_in": float(meta["residual_scales_in"][0]), "s_out": float(meta["residual_scales_out"][-1]),
            "tn": int(pc["norm_tn"]), "ceps": int(pc["norm_ceps"]), "margin": float(prof["variant_options"]["margin"]),
            "T": int(prof["T"]), "R": R, "rotation_sign_sha256": meta["rotation"]["sign_sha256"]}


def heldout_ids(run: Path, T: int):
    """regenerate the run's held-out ids with the driver's own selection; check them against the run's metadata."""
    s = json.loads((run / "summary.json").read_text())
    a = s["args"]
    tok = m.HFTokenizer(Path(a["tokenizer"]))
    ho, meta = m.text_sequences(tok, "heldout", T, a["heldout_per"])
    h2, n2 = m.fineweb_sequences(tok, "heldout", T, a["fw_heldout"])
    ho, meta = ho + h2, meta + n2
    assert [x["sha256"] for x in meta] == [x["sha256"] for x in s["heldout_sequences"]], "held-out ids differ from the run"
    return np.array(ho, dtype=np.int64), np.array([x["domain"] for x in meta]), s


def calib_xhat_rot_absmax(ck, run: Path, R):
    """float model in the rotated basis (the driver's float path: rotated float32 weights, tlcalib.f_block) on the
    run's calibration set; per-channel max |xhat'| of the final residual (xhat' = x' / sqrt(mean x'^2 + eps), f64)."""
    s = json.loads((run / "summary.json").read_text())
    a = s["args"]
    Tc = int(s["calibration"]["T_cal"])
    tok = m.HFTokenizer(Path(a["tokenizer"]))
    cal, cm = m.text_sequences(tok, "calib", Tc, a["calib_per"])
    c2, cm2 = m.fineweb_sequences(tok, "calib", Tc, a["fw_calib"])
    cal, cm = cal + c2, cm + cm2
    assert [x["sha256"] for x in cm] == [x["sha256"] for x in s["calib_sequences"]], "calibration ids differ from the run"
    ids = np.array(cal, dtype=np.int64)
    eraw = raw_u16(ck, "model.embed_tokens.weight")
    x = m.bf16_rows(eraw.reshape(-1), ids.reshape(-1), D).reshape(*ids.shape, D)
    del eraw
    x = R.fwd(x.reshape(-1, D)).astype(np.float32).reshape(x.shape)
    rope = tc.rope_f32(Tc)
    for l in range(ck.config["layers"]):
        t0 = time.time()
        W = bl.load_layer(ck, l, R)
        x = np.concatenate([tc.f_block(x[s0:s0 + 8], W, *rope) for s0 in range(0, len(x), 8)])
        del W
        if l % 8 == 0 or l == ck.config["layers"] - 1:
            log(f"  calibration float forward L{l:02d} ({time.time() - t0:.0f}s)")
    xr = x.reshape(-1, D).astype(np.float64)
    xh = xr / np.sqrt(np.mean(xr * xr, axis=-1, keepdims=True) + G.eps)
    return np.abs(xh).max(0), {"sequences": int(ids.shape[0]), "T_cal": Tc, "xhat_rot_absmax": float(np.abs(xh).max()),
                               "final_residual_absmax": float(np.abs(xr).max())}


def build_table(eraw, R, s_in):
    """TOKEN_IO_SPEC steps 1-3 for every vocabulary row (refuse outside int16)."""
    V = eraw.shape[0]
    table = np.empty((V, D), dtype=np.int16)
    for v0 in range(0, V, VB):
        xr32 = R.fwd(f32_rows(eraw, v0, v0 + VB).astype(np.float64)).astype(np.float32)
        q = np.floor(xr32.astype(np.float64) / s_in + 0.5)
        if np.abs(q).max() > 32767:
            raise ValueError(f"embedding rows {v0}.. leave int16 at s_in (those tokens would refuse)")
        table[v0:v0 + VB] = q.astype(np.int16)
    return table


def build_head(lm_raw, nw, R):
    """s4_head.build_heads per-row form at 8B: W' = lm_head diag(norm_weight) R^T (float64), s_j = max|W'_j| / 127,
    int8 clip(floor(W' / s + 0.5)); 12-bit multipliers m_j = max(1, floor(2^12 s_j / max s + 0.5))."""
    V = lm_raw.shape[0]
    Wr = np.empty((V, D), dtype=np.int8)
    s_r = np.empty(V)
    clipped = 0
    for v0 in range(0, V, VB):
        Wp = R.fwd(f32_rows(lm_raw, v0, v0 + VB).astype(np.float64) * nw.astype(np.float64)[None, :])
        s = np.abs(Wp).max(1) / 127.0
        q = np.floor(Wp / s[:, None] + 0.5)
        clipped += int((np.abs(q) > 127).sum())
        Wr[v0:v0 + VB] = np.clip(q, -127, 127).astype(np.int8)
        s_r[v0:v0 + VB] = s
    mult = np.maximum(1, np.floor((2 ** MULT_BITS) * s_r / s_r.max() + 0.5)).astype(np.int64)
    assert mult.min() >= 1 and mult.max() <= 4096
    return Wr, s_r, mult, clipped


def check_embedding(table, root: Path, ex, ho_ids, X0, XL, ck):
    """table[tokens] == x_in_L00 for every exported sequence (and its x_out_L31 == the run's chain), and
    table[held-out ids] == the run's whole x_L00 chain."""
    T = ex["T"]
    checks = {"exported_sequences": [], "heldout_chain_sequences": int(len(ho_ids))}
    for sname in ex["prof"]["sequences"]:
        sd = root / sname
        smf = json.loads((sd / "manifest.json").read_text())
        toks = np.array(smf["token_ids"])
        xin = np.frombuffer((sd / "x_in_L00.bin").read_bytes(), dtype="<i2").reshape(T, D)
        assert toks[0] == BOS
        assert np.array_equal(table[toks], xin), f"{sname}: table[tokens] != x_in_L00"
        xo = np.frombuffer((sd / f"x_out_L{ck.config['layers'] - 1:02d}.bin").read_bytes(), dtype="<i2").reshape(T, D)
        assert np.array_equal(xo, XL[smf["heldout_index"]]), f"{sname}: exported x_out != the run's integer chain"
        checks["exported_sequences"].append(sname)
    assert np.array_equal(table[ho_ids], X0), "table[held-out ids] != the run's x_L00 chain"
    log(f"embedding checks ok: {checks}")
    return checks


def norm_constants(ch_max, ex):
    nrep = {}
    g8, cn, tn_s, ceps, s_y, _ = tc.norm_site(np.ones(D), ch_max, [], "final_norm",
                                              tc.CalibOptions(margin=ex["margin"], tn=ex["tn"]), ex["s_out"], nrep, "final_norm")
    assert tn_s == ex["tn"] and np.all(g8 == g8[0]) and int(g8[0]) == 127, (tn_s, g8[:4])
    assert int(ceps) == ex["ceps"], ("Ceps by the calibration rule != the profile's", ceps, ex["ceps"])
    assert 1 <= cn <= (1 << 20), cn            # D24: Cn <= 2^20
    return {"g0": int(g8[0]), "tn": int(tn_s), "ceps": int(ceps), "cn_calibrated": int(cn), "cn_refusal_free": 1 << tn_s,
            "window_bits": int(tc.norm_window(D, tn_s)), "margin": ex["margin"], "norm_site": nrep["final_norm"]}


def selftest_norm(X, fn):
    rng = np.random.default_rng(20261018)
    xr = rng.integers(-32768, 32768, size=(32, D), dtype=np.int64)
    xr[0], xr[1], xr[2] = 32767, -32768, 0
    xs = np.concatenate([X[:32].astype(np.int64), xr])
    ok = True
    for cn in (fn["cn_calibrated"], fn["cn_refusal_free"], 4096):
        q, _ = final_norm(xs, 127, cn, fn["tn"], fn["ceps"], fn["window_bits"])
        q2, _ = tc.i_norm(xs[None], np.full(D, 127, dtype=np.int8), cn, fn["tn"], fn["ceps"], fn["window_bits"],
                          tc.Rec(1), "t", 0, clamp=False)
        ok &= bool(np.array_equal(q, q2[0]))
    assert ok, "final_norm != tlcalib.i_norm with a uniform gain"
    return {"final_norm_equals_i_norm": ok, "rows": int(xs.shape[0])}


def f2(X, domains, T, fn, Wr, mult, ex, nw, lm_raw):
    n = X.shape[0]
    rec = {k: [] for k in ("int_tok", "float_tok", "float_margin", "ties", "refused", "labs", "cabs", "dmax", "dmin")}
    for c0 in range(0, n, PCH):
        t0 = time.time()
        xi = X[c0:c0 + PCH].astype(np.int64)
        y, refused = final_norm(xi, fn["g0"], fn["cn_calibrated"], fn["tn"], fn["ceps"], fn["window_bits"])
        yc = np.clip(y, -127, 127)              # clamped ONLY to continue past a refusal (diagnostic)
        Lr = int_logits(yc, Wr)
        C = Lr * mult[None, :]
        a = C.argmax(-1)
        c1, _ = top2(C)
        dmax, dmin = keyed_stats(C, a)
        Lf = float_head(xi, ex["s_out"], ex["R"], nw, lm_raw)
        af = Lf.argmax(-1)
        f1, f2_ = top2(Lf)
        for k, v in (("int_tok", a), ("float_tok", af), ("float_margin", (f1 - f2_).astype(np.float64)),
                     ("ties", (C == c1[:, None]).sum(-1) - 1), ("refused", refused), ("labs", np.abs(Lr).max(-1)),
                     ("cabs", np.abs(C).max(-1)), ("dmax", dmax), ("dmin", dmin)):
            rec[k].append(v)
        del Lr, C, Lf
        log(f"  F2 T{T} positions {c0}-{min(n, c0 + PCH)} of {n} ({time.time() - t0:.1f}s)")
    r = {k: np.concatenate(v) for k, v in rec.items()}
    pos = np.tile(np.arange(T), n // T)
    dom = np.repeat(domains, T)

    def agree(msk):
        k = int(msk.sum())
        g = int((r["int_tok"][msk] == r["float_tok"][msk]).sum())
        return {"agree": g, "n": k, "rate": (g / k) if k else None}

    crit = r["float_margin"] >= 0.3
    sets = {"all": np.ones(n, bool), "float_margin_ge_0.3 (D25 T4)": crit, "last_position": pos == T - 1}
    for d_ in np.unique(dom):
        sets[f"domain:{d_}"] = dom == d_
    dis = r["int_tok"] != r["float_tok"]
    fe = [0.0, 0.01, 0.03, 0.1, 0.3, 1.0, 3.0, 1e9]
    W = window_bits(D, Wr.shape[0], MULT_BITS)
    out = {"T": T, "positions": n, "sequences": n // T,
           "int_vs_float_head": {k: agree(v) for k, v in sets.items()},
           "d25_t4_criterion_met": bool(agree(crit)["agree"] == int(crit.sum())),
           "final_norm_refused_positions": int(r["refused"].sum()),
           "tie_positions": int((r["ties"] > 0).sum()), "ties_rule": "lowest token id (numpy first maximum), D25 T3",
           "max_abs_raw_logit": int(r["labs"].max()), "max_abs_raw_logit_bits": int(int(r["labs"].max()).bit_length()),
           "raw_logit_class_bound_bits": int((D * 127 * 127).bit_length()),
           "max_abs_scaled_logit": int(r["cabs"].max()), "max_abs_scaled_logit_bits": int(int(r["cabs"].max()).bit_length()),
           "keyed_delta_max": int(r["dmax"].max()), "keyed_delta_bits_needed": int(int(r["dmax"].max()).bit_length()),
           "keyed_window_bits": W, "keyed_delta_fits_window": bool(int(r["dmax"].max()) < (1 << W)),
           "keyed_delta_min_over_i_ne_j": int(r["dmin"].min()), "keyed_delta_strict": bool(int(r["dmin"].min()) > 0),
           "disagreements": int(dis.sum()),
           "disagreement_by_float_margin": {f"[{fe[i]},{fe[i + 1]})": {
               "positions": int(((r["float_margin"] >= fe[i]) & (r["float_margin"] < fe[i + 1])).sum()),
               "disagree": int((dis & (r["float_margin"] >= fe[i]) & (r["float_margin"] < fe[i + 1])).sum())}
               for i in range(len(fe) - 1)},
           "float_margin_quantiles": {q: float(np.quantile(r["float_margin"], q)) for q in (0.01, 0.05, 0.5)}}
    return out


def write_manifests(td: Path, ex, fn, head, emb, checks, calib, mode, src):
    tio = {"schema": m.SCHEMA, "kind": "token_io", "model": m.MODEL, "T": ex["T"],
           "embedding_table": emb, "s_x_in_layer0": ex["s_in"], "s_x_out_layer31": ex["s_out"],
           "rotation": {"seed": 1, "file": "../rotation_sign.bin (see ../rotation.json)", "sign_sha256": ex["rotation_sign_sha256"]},
           "source_tensors_sha256": src, "rms_norm_eps": G.eps, "bos": BOS,
           "spec": "results/zk60_1b_calibration_20260929/export/TOKEN_IO_SPEC.md (8B: d 4096, V 128256, BOS 128000, 32 layers)",
           "checked_against": checks, "mode": mode, "scope": "public model data + calibration data; not a proof"}
    (td / "token_io.json").write_text(json.dumps(tio, indent=1, sort_keys=True))
    man = {"kind": "token-io R3 head (per-row int8 + 12-bit multipliers, D25 T4 as amended)",
           "source": "results/zk60_8b_calibration_20261017/b8_token_io.py (the fidelity lane's s4_head.build_heads rule at 8B)",
           "V": head["V"], "d": D, "head_int8_perrow.bin": head["rows"], "head_mult12.bin": head["mult"],
           "scales_f64_sha256": head["scales_sha256"], "minus128": head["minus128"], "clipped": head["clipped"],
           "final_norm": {k: fn[k] for k in ("g0", "tn", "ceps", "cn_calibrated", "cn_refusal_free", "window_bits")},
           "final_norm_rule": "tlcalib.norm_site(c = 1) on calib_final_xhat_rot_absmax.bin at the export variant's margin "
                              f"{fn['margin']}, tn = profile norm_tn, Ceps = profile norm_ceps (asserted equal)",
           "calibration_final_xhat": calib, "bos": BOS, "keyed_window_bits": window_bits(D, head["V"], MULT_BITS),
           "keyed_window_rule": "bits(2^17 * 2 d 127^2 * 2^12 + V - 1) (V_pad 2^17)"}
    (td / "head_manifest.json").write_text(json.dumps(man, indent=1, sort_keys=True))


def write_readme(td: Path, ex, fn, head, emb, checks, rep, mode):
    f = rep["f2"]
    a = f["int_vs_float_head"]

    def pct(k):
        e = a[k]
        return f"{100 * e['rate']:.2f} % ({e['agree']}/{e['n']})" if e["n"] else "n/a"
    doms = [k for k in a if k.startswith("domain:")]
    txt = f"""# Token I/O for this export (rung R3, Llama-3-8B)

Calibration lane B8, written by `results/zk60_8b_calibration_20261017/b8_token_io.py` ({mode}). Public model data
and calibration data: not a proof, not a privacy claim. Format and rules as the TinyLlama R2 inputs
(`results/zk60_1b_calibration_20260929/export/TOKEN_IO_SPEC.md`; the fidelity lane's `s4_head.py` per-row head;
D25 T3 ties to the lowest id, T4 as amended: per-row int8 + 12-bit multipliers). Hashes of every file: `SHA256SUMS`.

| file | content |
|---|---|
| `embedding_int16.bin` | int16 LE [{emb['shape'][0]}, {D}]: x_in_L00[t] = table[token_t] (TOKEN_IO_SPEC steps 1-3 at s_in = {ex['s_in']!r}, rotated basis seed 1); sha256 {emb['sha256']} |
| `head_int8_perrow.bin` | int8 [{head['V']}, {D}] row-major: W' = lm_head diag(norm_weight) R^T, row j quantised at s_j = max_i abs(W'_j,i) / 127, round half up, clip +-127 ({head['clipped']} clipped, {head['minus128']} words -128); sha256 {head['rows']['sha256']} |
| `head_mult12.bin` | int64 LE [{head['V']}]: m_j = max(1, floor(2^12 s_j / max s + 0.5)), in [{head['mult']['min']}, {head['mult']['max']}], {head['mult']['distinct']} distinct; sha256 {head['mult']['sha256']} |
| `calib_final_xhat_rot_absmax.bin` | float64 [{D}]: per-channel max abs of the rotated xhat of the calibration set's final residual (the final-norm Cn input) |
| `head_manifest.json`, `token_io.json` | digests, shapes, rules, scales, source tensor digests |
| `f2_fidelity.json` | the checks and F2 below, in full |

Final norm (block norm relation, uniform gain): g0 {fn['g0']}, tn {fn['tn']} (window {fn['window_bits']} bits at width {D}),
Ceps {fn['ceps']} (= the profile's), **Cn {fn['cn_calibrated']}** by the calibration rule (norm_site, c = 1, margin {fn['margin']});
refusal-free alternative Cn = 2^tn = {fn['cn_refusal_free']}. Integer next token: y = final norm of x_out_L31; l_j = y . W'q_j
(raw, exact); C_j = m_j l_j; token = first maximum of C (lowest id on ties). Keyed window: bits(2^17 x 2 d 127^2 x 2^12 + V - 1)
= {f['keyed_window_bits']} bits.

Checks [MEASURED]: the table reproduces x_in_L00 of every exported sequence ({', '.join(checks['exported_sequences'])}) and the
run's whole held-out integer input chain ({checks['heldout_chain_sequences']} sequences x T {ex['T']}); each exported x_out_L31 equals
the run's integer chain; final_norm == tlcalib.i_norm with a uniform gain ({rep['selftest']['rows']} rows incl. int16 extremes).

F2, integer head vs the float head (TOKEN_IO_SPEC float path) on the SAME integer stack output, {f['sequences']} held-out
sequences x T {ex['T']} = {f['positions']} positions [MEASURED]:

| set | agreement |
|---|---|
| all positions | {pct('all')} |
| float top-2 margin >= 0.3 logits (D25 T4 criterion) | {pct('float_margin_ge_0.3 (D25 T4)')} -> criterion met: {f['d25_t4_criterion_met']} |
| last position | {pct('last_position')} |
""" + "".join(f"| {k} | {pct(k)} |\n" for k in doms) + f"""
Final-norm refusals: {f['final_norm_refused_positions']} positions. Exact ties in C: {f['tie_positions']} positions (lowest id rule).
Max abs raw logit {f['max_abs_raw_logit']} ({f['max_abs_raw_logit_bits']} bits; class bound {f['raw_logit_class_bound_bits']} bits); max abs
scaled logit {f['max_abs_scaled_logit_bits']} bits; keyed delta needs {f['keyed_delta_bits_needed']} of {f['keyed_window_bits']} bits
(fits: {f['keyed_delta_fits_window']}; strict off the argmax: {f['keyed_delta_strict']}). Disagreements: {f['disagreements']}
(by float margin in f2_fidelity.json). Shared box, n=1.
"""
    (td / "README.md").write_text(txt)


def main():
    t0 = time.time()
    mode, root, run = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    td = root / "token_io"
    if td.exists():
        raise SystemExit(f"{td} exists: token_io is written fresh (hard links; never write in place)")
    ex = export_info(root)
    T = ex["T"]
    ck = tc.open_checkpoint()
    ident = ck.identity["tensor_sha256"]
    src = {k: ident[k] for k in ("model.embed_tokens.weight", "model.norm.weight", "lm_head.weight")}
    td.mkdir()
    rep = {"mode": mode, "export": str(root), "run": str(run), "T": T}
    ho_ids, domains, summ = heldout_ids(run, T)
    chain = run / "chain_int16"
    X0 = np.load(chain / "x_L00.npy")
    XL = np.load(chain / f"x_L{ck.config['layers']:02d}.npy")
    assert X0.shape == (len(ho_ids), T, D) and XL.shape == X0.shape
    if mode == "build":
        # ---- final-norm calibration maxima FIRST (float forward, ~3 GiB, freed before the 1 GB tables);
        # cached under runs/ (keyed by the calibration ids' digests) so a rerun skips the forward
        cache = HERE / "runs" / f"b8_calib_final_xhat_{run.name}.json"
        if cache.exists():
            cj = json.loads(cache.read_text())
            ch_max, calib = np.array(cj["ch_max_rot"]), cj["calib"]
            log(f"calibration final xhat maxima from cache {cache.name}")
        else:
            ch_max, calib = calib_xhat_rot_absmax(ck, run, ex["R"])
            cache.write_text(json.dumps({"ch_max_rot": ch_max.tolist(), "calib": calib}))
        (td / "calib_final_xhat_rot_absmax.bin").write_bytes(ch_max.astype("<f8").tobytes())
        log(f"calibration final xhat maxima: {calib}")
        # ---- (1) embedding table
        eraw = raw_u16(ck, "model.embed_tokens.weight")
        V = eraw.shape[0]
        table = build_table(eraw, ex["R"], ex["s_in"])
        del eraw
        (td / "embedding_int16.bin").write_bytes(table.astype("<i2").tobytes())
        log("embedding table written")
        checks = check_embedding(table, root, ex, ho_ids, X0, XL, ck)
        del table
        # ---- (2) head
        nw = tc.tensor_f32(ck.refs["model.norm.weight"]).astype(np.float32)
        lm_raw = raw_u16(ck, "lm_head.weight")
        Wr, s_r, mult, clipped = build_head(lm_raw, nw, ex["R"])
        (td / "head_int8_perrow.bin").write_bytes(Wr.tobytes())
        (td / "head_mult12.bin").write_bytes(mult.astype("<i8").tobytes())
        log(f"head written (clipped {clipped}, -128 {int((Wr == -128).sum())}, m in [{mult.min()}, {mult.max()}])")
        scales_sha = sha_bytes(s_r.astype("<f8").tobytes())
    else:
        src_td = Path(sys.argv[4])
        sm = json.loads((src_td / "head_manifest.json").read_text())
        st = json.loads((src_td / "token_io.json").read_text())
        assert (st["s_x_in_layer0"], st["s_x_out_layer31"], st["rotation"]["sign_sha256"]) == \
            (ex["s_in"], ex["s_out"], ex["rotation_sign_sha256"]), "scales / rotation differ: the shared files do not apply"
        assert st["source_tensors_sha256"] == src
        for f in SHARED:
            os.link(src_td / f, td / f)            # byte-identical by construction (same s_in, rotation, checkpoint)
        V = sm["V"]
        assert sha_file(td / "embedding_int16.bin") == st["embedding_table"]["sha256"]
        table = np.frombuffer((td / "embedding_int16.bin").read_bytes(), dtype="<i2").reshape(V, D)
        checks = check_embedding(table, root, ex, ho_ids, X0, XL, ck)
        del table
        Wr = np.frombuffer((td / "head_int8_perrow.bin").read_bytes(), dtype=np.int8).reshape(V, D)
        mult = np.frombuffer((td / "head_mult12.bin").read_bytes(), dtype="<i8").astype(np.int64)
        assert sha_file(td / "head_int8_perrow.bin") == sm["head_int8_perrow.bin"]["sha256"]
        assert sha_file(td / "head_mult12.bin") == sm["head_mult12.bin"]["sha256"]
        ch_max = np.frombuffer((td / "calib_final_xhat_rot_absmax.bin").read_bytes(), dtype="<f8")
        calib = sm["calibration_final_xhat"]
        scales_sha = sm["scales_f64_sha256"]
        clipped = sm["clipped"]
        nw = tc.tensor_f32(ck.refs["model.norm.weight"]).astype(np.float32)
        lm_raw = raw_u16(ck, "lm_head.weight")
        rep["reused_from"] = str(src_td)
    fn = norm_constants(ch_max, ex)
    rep["final_norm"] = fn
    rep["selftest"] = selftest_norm(XL.reshape(-1, D), fn)
    log(f"final norm {fn['g0']} / Cn {fn['cn_calibrated']} (refusal-free {fn['cn_refusal_free']}) / tn {fn['tn']} / "
        f"Ceps {fn['ceps']} / window {fn['window_bits']}; selftest {rep['selftest']}")
    # ---- (3) F2
    rep["f2"] = f2(XL.reshape(-1, D), domains, T, fn, Wr, mult, ex, nw, lm_raw)
    log(f"F2: {json.dumps({k: rep['f2'][k] for k in ('int_vs_float_head', 'd25_t4_criterion_met', 'tie_positions', 'max_abs_raw_logit_bits', 'keyed_delta_bits_needed', 'keyed_window_bits', 'final_norm_refused_positions')})}")
    # ---- manifests, sha list
    emb = {"file": "embedding_int16.bin", "dtype": "int16", "shape": [int(V), D], "sha256": sha_file(td / "embedding_int16.bin"),
           "rule": "floor(float64(float32(R.fwd(float64(float32(E[t]))))) / s_in + 0.5), refuse outside int16"}
    head = {"V": int(V), "rows": {"dtype": "int8", "shape": [int(V), D], "sha256": sha_file(td / "head_int8_perrow.bin")},
            "mult": {"dtype": "int64 little-endian", "shape": [int(V)], "sha256": sha_file(td / "head_mult12.bin"),
                     "rule": "m_j = max(1, floor(2^12 s_j / max s + 0.5))", "min": int(mult.min()), "max": int(mult.max()),
                     "distinct": int(len(np.unique(mult)))},
            "scales_sha256": scales_sha, "minus128": int((Wr == -128).sum()), "clipped": int(clipped)}
    write_manifests(td, ex, fn, head, emb, checks, calib, mode, src)
    rep["seconds"] = time.time() - t0
    (td / "f2_fidelity.json").write_text(json.dumps(rep, indent=1, sort_keys=True, default=float))
    write_readme(td, ex, fn, head, emb, checks, rep, mode)
    lines = [f"{sha_file(p)}  {p.name}" for p in sorted(td.iterdir()) if p.is_file() and p.name != "SHA256SUMS"]
    (td / "SHA256SUMS").write_text("\n".join(lines) + "\n")
    log(f"done ({rep['seconds']:.0f}s) -> {td}")


if __name__ == "__main__":
    from threadpoolctl import threadpool_limits
    with threadpool_limits(limits=4):
        main()
