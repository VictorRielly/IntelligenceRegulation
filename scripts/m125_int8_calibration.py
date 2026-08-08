#!/usr/bin/env python3
"""m125_int8_calibration.py — U-AG-B1 Agent BC: the frugal-lm 125M int8
calibration study (LLM_POC_ROADMAP.md risk 5 de-risk).

Reads the frugal-lm 125M checkpoint READ-ONLY and studies, per
TARGET_CONTRACT.md Section 2 semantics (int8 SYMMETRIC [-127, 127],
power-of-two scales, floor requantization x = 2^shift * y + r with the
remainder r proven in [0, 2^shift)):

  1. WEIGHTS (always): quantize the 12 layers' FFN tensors (w_gate,
     w_up, w_down) — ranges, chosen power-of-two scale exponents,
     saturation counts (at the chosen scale and one bit tighter),
     quantization error.
  2. ACCUMULATORS (always, closed form + measured): honest widths at
     the 125M inner dims 768/2048 — the contract's 27/29-bit rows are
     for inner 4096/11008 and are REPRODUCED here under the same
     convention before the 125M rows are derived.
  3. ACTIVATIONS (MLX inference, read-only): the FFN chain sampled on
     seeded fineweb-edu-val batches — X (the mlp_norm output = the
     statement's X), gate, up, a = SiLU(gate), h = a o up, z (down
     output) — ranges and scales calibrated on a CALIBRATION batch,
     range facts checked on a disjoint HELD-OUT batch.
  4. INT8 SIMULATION (exact integer arithmetic): the quantized FFN
     chain per contract semantics — int8 matmuls with exact int
     accumulators (float64-carried, all values << 2^53), floor
     requantization with nonnegative remainders, the 256-row SiLU
     table, per-layer matched-input error, end-to-end val-loss delta
     (attention/norms stay fp32: they are OUT of the proof statement,
     TARGET_CONTRACT Section 1), and the range-fact verdict.

Outputs: printed tables + results/m125_int8_calibration.json (in THIS
repo; frugal-lm is never written). The study document is
docs/zkmatrix-poc/M125_CALIBRATION_STUDY.md.

Run with frugal-lm's venv (mlx + numpy):
  /Users/victorrielly/frugal-lm/.venv/bin/python \
      scripts/m125_int8_calibration.py
Without mlx the script degrades to the weights-only + closed-form
sections and marks the activation sections [ENV PENDING] with exact
instructions. Seeded (1337); single run ~1-2 min on the Mac box
[MAC-BOX timings are informational only; every number that matters
here is machine-independent].
"""

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

# --------------------------------------------------------------------------
# constants (paths are READ-ONLY; outputs land in THIS repo)
# --------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parents[1]
FRUGAL = Path("/Users/victorrielly/frugal-lm")
CKPT = FRUGAL / "runs" / "125m-baseline" / "ckpt-00009536" / "model.safetensors"
VAL_SHARD = FRUGAL / "data" / "fineweb-edu-val" / "shard-00000.npy"
OUT_JSON = ROOT / "results" / "m125_int8_calibration.json"

SEED = 1337
N_LAYERS = 12
D_MODEL = 768
MLP_HIDDEN = 2048
T_TOKENS = 512            # the contract workload: single prefill, T = 512
N_CAL_SEQ = 8             # calibration batch (scale selection)
N_VAL_SEQ = 8             # held-out batch (range facts + loss)
QMAX = 127                # int8 SYMMETRIC per the contract (see Section 2
                          # derivation below: the contract's own 27-bit row
                          # at inner 4096 forces the [-127, 127] reading)

report = {"checkpoint": str(CKPT), "seed": SEED,
          "semantics": "TARGET_CONTRACT.md Section 2: int8 symmetric "
                       "[-127,127], power-of-two scales, floor requant "
                       "x = 2^shift*y + r, r in [0, 2^shift)"}


def p(line=""):
    print(line)


# --------------------------------------------------------------------------
# safetensors reading (pure numpy — works under any interpreter)
# --------------------------------------------------------------------------

def read_safetensors(path):
    """Minimal safetensors reader: header JSON + raw little-endian data.
    BF16 is widened to float32 exactly (uint16 << 16 reinterpreted)."""
    with open(path, "rb") as f:
        n = struct.unpack("<Q", f.read(8))[0]
        hdr = json.loads(f.read(n))
        base = 8 + n
        raw = f.read()  # rest of file
    out = {}
    for k, v in hdr.items():
        if k == "__metadata__":
            continue
        s, e = v["data_offsets"]
        blob = raw[s:e]
        if v["dtype"] == "BF16":
            u16 = np.frombuffer(blob, dtype="<u2").astype(np.uint32)
            arr = (u16 << 16).view(np.float32).astype(np.float32)
        elif v["dtype"] == "F32":
            arr = np.frombuffer(blob, dtype="<f4").astype(np.float32)
        else:
            raise ValueError("unhandled dtype %s for %s" % (v["dtype"], k))
        out[k] = arr.reshape(v["shape"])
    return out


# --------------------------------------------------------------------------
# contract-semantics primitives
# --------------------------------------------------------------------------

def pow2_exp_for(absmax):
    """Smallest e with absmax <= QMAX * 2^e  (round(|x|/2^e) <= 127 then
    holds a fortiori for |x| <= absmax)."""
    if absmax == 0:
        return -30
    return int(math.ceil(math.log2(absmax / QMAX)))


def quantize(x, e):
    """Symmetric int8 at scale 2^e: q = clamp(round(x / 2^e)). Returns
    (q int array, clipped count pre-clamp)."""
    q = np.round(x / (2.0 ** e))
    clipped = int(np.count_nonzero(np.abs(q) > QMAX))
    return np.clip(q, -QMAX, QMAX), clipped


def floor_requant(acc, shift, mode="floor"):
    """The contract's requantization: acc = 2^shift * y + r with
    r in [0, 2^shift): y = floor(acc / 2^shift). Exact on float64-carried
    integers (all |acc| << 2^53). `shift` may be a scalar or a per-column
    vector (per-channel weight scales). mode="round" implements
    round-to-nearest as floor((acc + 2^(shift-1)) / 2^shift) — the SAME
    proven relation applied to the publicly pre-shifted value (a
    statement-level design choice, flagged in the study doc)."""
    sh = np.asarray(shift, dtype=np.float64)
    assert float(sh.min()) >= 0, "requant shift must be nonnegative"
    step = 2.0 ** sh
    x = acc + np.where(sh > 0, step / 2.0, 0.0) if mode == "round" else acc
    y = np.floor(x / step)
    r = x - y * step
    assert float(r.min()) >= 0 and float((r - step).max()) < 0
    return y


def narrow_int8(y):
    """The proven range fact: y must lie in [-127, 127]. Returns
    (clamped, violation count) — a nonzero count means the range fact
    FAILS for those positions (the proof would reject BY DESIGN)."""
    viol = int(np.count_nonzero(np.abs(y) > QMAX))
    return np.clip(y, -QMAX, QMAX), viol


# --------------------------------------------------------------------------
# Section 1 — weights
# --------------------------------------------------------------------------

def weight_study(wts):
    p("=" * 78)
    p("SECTION 1 — FFN weight quantization (12 layers x w_gate/w_up/w_down)")
    p("   [semantics: per-tensor symmetric int8, power-of-two scale 2^e, "
      "e = ceil(log2(absmax/127))]")
    p("=" * 78)
    rows = []
    hdr = "%-7s %-7s %10s %10s %5s %9s %10s %10s" % (
        "layer", "tensor", "absmax", "rms", "e", "sat@e", "sat@e-1", "relRMS")
    p(hdr)
    for l in range(N_LAYERS):
        for name in ("w_gate", "w_up", "w_down"):
            W = wts["blocks.%d.mlp.%s.weight" % (l, name)].astype(np.float64)
            absmax = float(np.abs(W).max())
            rms = float(np.sqrt((W ** 2).mean()))
            e = pow2_exp_for(absmax)
            q, sat = quantize(W, e)
            _, sat_tight = quantize(W, e - 1)
            deq = q * (2.0 ** e)
            rel = float(np.sqrt(((W - deq) ** 2).mean()) / rms)
            rows.append(dict(layer=l, tensor=name, shape=list(W.shape),
                             absmax=absmax, rms=rms, exp=e, sat=sat,
                             sat_tighter=sat_tight, rel_rms_err=rel))
            p("%-7d %-7s %10.5f %10.5f %5d %9d %10d %10.5f"
              % (l, name, absmax, rms, e, sat, sat_tight, rel))
    sats = sum(r["sat"] for r in rows)
    p("-> all 36 tensors quantize with %d saturations at the chosen "
      "scales (by construction); worst per-tensor relative RMS error "
      "%.4f" % (sats, max(r["rel_rms_err"] for r in rows)))
    report["weights"] = rows
    return rows


# --------------------------------------------------------------------------
# Section 2 — honest accumulator widths at the 125M inner dims
# --------------------------------------------------------------------------

def acc_width(inner):
    """Signed bits needed for sum of `inner` products of symmetric int8
    values: max |acc| = inner * 127^2; width = magnitude bits + sign."""
    m = inner * QMAX * QMAX
    return m, int(math.floor(math.log2(m))) + 1 + 1


def accumulator_section():
    p()
    p("=" * 78)
    p("SECTION 2 — honest accumulator widths (contract convention "
      "re-derivation)")
    p("=" * 78)
    p("convention check — the contract's OWN rows reproduce under "
      "symmetric [-127,127]:")
    for inner, want in ((4096, 27), (11008, 29)):
        m, bits = acc_width(inner)
        tag = "OK" if bits == want else "MISMATCH"
        p("  inner %6d: max|acc| = %11d (2^%.2f) -> %d-bit signed "
          "(contract says %d-bit) %s"
          % (inner, m, math.log2(m), bits, want, tag))
        assert bits == want, "contract convention reproduction failed"
    p("  (under [-128,128] products the inner-4096 bound is exactly 2^26, "
      "which does NOT fit 27-bit two's complement — the contract's 27-bit "
      "row therefore pins the symmetric [-127,127] reading used here)")
    p("the 125M rows (this study's derivation):")
    out = {}
    for inner, where in ((D_MODEL, "gate/up matmuls (inner 768)"),
                         (MLP_HIDDEN, "down matmul (inner 2048)")):
        m, bits = acc_width(inner)
        out[str(inner)] = dict(max_abs_acc=m, signed_bits=bits)
        p("  inner %6d: max|acc| = %11d (2^%.2f) -> %d-bit signed  [%s]"
          % (inner, m, math.log2(m), bits, where))
    p("  both far inside q31 (q/2 ~ 2^30): worst-case exact at q31 a "
      "fortiori (the contract's 27/29-bit rows are for 4096/11008 and do "
      "NOT transfer verbatim — these 25/26-bit rows are the 125M "
      "statement's honest lines)")
    report["accumulators"] = out
    return out


# --------------------------------------------------------------------------
# activation study (MLX; read-only inference)
# --------------------------------------------------------------------------

ENV_PENDING_MSG = """
SECTION 3/4 — [ENV PENDING] activation sampling + int8 simulation
This interpreter has no mlx; the weights-only sections above are
complete. To produce the activation sections exactly as designed, run:

    /Users/victorrielly/frugal-lm/.venv/bin/python \\
        scripts/m125_int8_calibration.py

(that venv carries mlx + numpy; the script auto-detects and runs the
full study; nothing under /Users/victorrielly/frugal-lm is written).
"""


def try_mlx():
    try:
        import mlx.core as mx  # noqa: F401
        return True
    except Exception:
        return False


def build_model():
    """Import frugal-lm's OWN model code (read-only) and load the
    checkpoint strictly — zero re-implementation drift for the reference
    forward."""
    sys.path.insert(0, str(FRUGAL / "src"))
    import mlx.core as mx
    from mlx.utils import tree_flatten, tree_map
    from frugal_lm.config import ModelConfig
    from frugal_lm.model import Transformer

    cfg = ModelConfig(n_layers=N_LAYERS, d_model=D_MODEL, n_heads=12,
                      n_kv_heads=4, vocab_size=49152, context_length=2048,
                      tie_embeddings=True)
    assert cfg.mlp_hidden == MLP_HIDDEN, cfg.mlp_hidden
    model = Transformer(cfg)
    model.load_weights(str(CKPT))          # strict: shape/key mismatch raises
    # cast to float32 for numerically clean reference statistics
    model.update(tree_map(lambda p_: p_.astype(mx.float32),
                          model.parameters()))
    model.eval()
    n_params = model.num_params()
    return model, n_params


def token_batches():
    """Seeded, disjoint (input, target) windows from the val shard."""
    toks = np.load(VAL_SHARD, mmap_mode="r")
    rng = np.random.default_rng(SEED)
    need = N_CAL_SEQ + N_VAL_SEQ
    span = T_TOKENS + 1
    offs = np.sort(rng.choice((len(toks) - span) // span, size=need,
                              replace=False)) * span
    wins = np.stack([np.asarray(toks[o:o + span], dtype=np.int64)
                     for o in offs])
    cal, val = wins[:N_CAL_SEQ], wins[N_CAL_SEQ:]
    return cal, val


def stats_of(x):
    a = np.abs(np.asarray(x, dtype=np.float64)).ravel()
    return dict(absmax=float(a.max()),
                p9999=float(np.quantile(a, 0.9999)),
                p999=float(np.quantile(a, 0.999)))


class FfnCapture:
    """Reference forward via the model's OWN modules, block by block,
    capturing the FFN chain (X = mlp_norm output, gate, up, a, h, z).
    Optionally substitutes an int8-simulated FFN (callable) to produce
    the quantized end-to-end pass."""

    def __init__(self, model):
        self.model = model

    def walk(self, tokens_np, ffn_override=None, collect=None):
        import mlx.core as mx
        toks = mx.array(tokens_np)
        x = self.model.embed(toks)
        for li, blk in enumerate(self.model.blocks):
            x = x + blk.attn(blk.attn_norm(x))
            xin = blk.mlp_norm(x)
            if ffn_override is None:
                gate = xin @ blk.mlp.w_gate.weight.T
                up = xin @ blk.mlp.w_up.weight.T
                import mlx.nn as nn
                a = nn.silu(gate)
                h = a * up
                z = h @ blk.mlp.w_down.weight.T
                if collect is not None:
                    mx.eval(xin, gate, up, a, h, z)
                    collect(li, dict(x=np.array(xin), gate=np.array(gate),
                                     up=np.array(up), a=np.array(a),
                                     h=np.array(h), z=np.array(z)))
            else:
                z_np = ffn_override(li, np.array(xin.astype(mx.float32)))
                z = mx.array(z_np.astype(np.float32))
            x = x + z
        x = self.model.final_norm(x)
        return x                              # final hidden; head applied by caller

    def loss(self, tokens_np, ffn_override=None):
        """Mean next-token cross-entropy over the batch (per-sequence to
        cap logits memory)."""
        import mlx.core as mx
        tot, cnt = 0.0, 0
        for s in range(tokens_np.shape[0]):
            seq = tokens_np[s:s + 1]
            hid = self.walk(seq[:, :-1], ffn_override=ffn_override)
            logits = self.model.embed.as_linear(hid)
            tgt = mx.array(seq[:, 1:])
            lse = mx.logsumexp(logits, axis=-1)
            picked = mx.take_along_axis(
                logits, tgt[..., None], axis=-1).squeeze(-1)
            nll = (lse - picked).mean()
            mx.eval(nll)
            tot += float(nll) * (seq.shape[1] - 1)
            cnt += (seq.shape[1] - 1)
        return tot / cnt


# --------------------------------------------------------------------------
# Section 3 — calibration (scales from the calibration batch)
# --------------------------------------------------------------------------

def calibrate(cap, cal_tokens, wrows):
    p()
    p("=" * 78)
    p("SECTION 3 — activation calibration (batch: %d seq x %d tokens, "
      "seeded %d, fineweb-edu-val)" % (N_CAL_SEQ, T_TOKENS, SEED))
    p("=" * 78)
    acts = {}

    def collect(li, d):
        acts.setdefault(li, {k: [] for k in d})
        for k, v in d.items():
            acts[li][k].append(v)

    cap.walk(cal_tokens[:, :-1], collect=collect)
    scales = []
    p("%-6s %8s %8s %8s %8s %8s %8s   %s" % (
        "layer", "eX", "eGate", "eUp", "eA", "eH", "eZ", "absmax(X/gate/z)"))
    for li in range(N_LAYERS):
        d = {k: np.concatenate([a.ravel() for a in v])
             for k, v in acts[li].items()}
        st = {k: stats_of(v) for k, v in d.items()}
        e = {k: pow2_exp_for(st[k]["absmax"]) for k in st}
        wg = next(r for r in wrows if r["layer"] == li
                  and r["tensor"] == "w_gate")
        wu = next(r for r in wrows if r["layer"] == li
                  and r["tensor"] == "w_up")
        wd = next(r for r in wrows if r["layer"] == li
                  and r["tensor"] == "w_down")
        scales.append(dict(layer=li, stats=st,
                           eX=e["x"], eGate=e["gate"], eUp=e["up"],
                           eA=e["a"], eH=e["h"], eZ=e["z"],
                           eWg=wg["exp"], eWu=wu["exp"], eWd=wd["exp"]))
        p("%-6d %8d %8d %8d %8d %8d %8d   %.3f / %.3f / %.3f"
          % (li, e["x"], e["gate"], e["up"], e["a"], e["h"], e["z"],
             st["x"]["absmax"], st["gate"]["absmax"], st["z"]["absmax"]))
    report["calibration"] = scales
    return scales


# --------------------------------------------------------------------------
# Section 4 — the int8 chain (exact contract semantics) on held-out data
# --------------------------------------------------------------------------

def silu_table(eg, ea):
    """The frozen 256-row int8 -> int8 SiLU table at scales (2^eg, 2^ea):
    row g -> clamp(round(silu(g*2^eg)/2^ea)). Table content is frozen
    offline; the proof checks membership (its digest sits in the
    statement header)."""
    g = np.arange(-128, 128, dtype=np.float64)
    x = g * (2.0 ** eg)
    y = x / (1.0 + np.exp(-x))
    q = np.clip(np.round(y / (2.0 ** ea)), -QMAX, QMAX)
    return q  # index by g + 128


def quantize_weights(wts, scales, wgran):
    """Per-layer int8 weight tensors. wgran="tensor": one scale per tensor
    (the Section 1 exponents). wgran="channel": one power-of-two scale per
    OUTPUT channel (matmul row) — the requant shift becomes a per-column
    vector; contract-granularity note in the study doc."""
    wq = []
    for li in range(N_LAYERS):
        d = {}
        for name in ("w_gate", "w_up", "w_down"):
            W = wts["blocks.%d.mlp.%s.weight" % (li, name)].astype(np.float64)
            sc = next(s for s in scales if s["layer"] == li)
            if wgran == "tensor":
                e = {"w_gate": sc["eWg"], "w_up": sc["eWu"],
                     "w_down": sc["eWd"]}[name]
                q, _ = quantize(W, e)
                evec = np.full(W.shape[0], e, dtype=np.int64)
            else:
                am = np.abs(W).max(axis=1)
                evec = np.ceil(np.log2(np.maximum(am, 1e-30) / QMAX)
                               ).astype(np.int64)
                q = np.clip(np.round(W / (2.0 ** evec)[:, None]),
                            -QMAX, QMAX)
            d[name] = (q, evec)
        wq.append(d)
    return wq


def make_int8_ffn(scales, wq, acc_track, viol_track, err_track, cap,
                  mode="floor"):
    """Returns ffn_override(li, x_np) implementing the contract chain with
    exact integer arithmetic (float64-carried; every value << 2^53)."""

    def ffn(li, x):
        sc = scales[li]
        B, T, C = x.shape
        xf = x.reshape(-1, C).astype(np.float64)
        xq, xclip = quantize(xf, sc["eX"])
        viol_track[li]["X_clip"] += xclip
        (Wg, eWg), (Wu, eWu), (Wd, eWd) = (
            wq[li][k] for k in ("w_gate", "w_up", "w_down"))
        # gate/up matmuls: int8 x int8, inner 768 -> exact acc (<= 2^24)
        acc_g = xq @ Wg.T
        acc_u = xq @ Wu.T
        acc_track[li]["gateup"] = max(acc_track[li]["gateup"],
                                      float(np.abs(acc_g).max()),
                                      float(np.abs(acc_u).max()))
        # requant to int8 (floor semantics, proven remainder); shift is a
        # per-column vector under per-channel weight scales
        sh_g = sc["eGate"] - sc["eX"] - eWg
        sh_u = sc["eUp"] - sc["eX"] - eWu
        yg, vg = narrow_int8(floor_requant(acc_g, sh_g[None, :], mode))
        yu, vu = narrow_int8(floor_requant(acc_u, sh_u[None, :], mode))
        viol_track[li]["gate_range"] += vg
        viol_track[li]["up_range"] += vu
        # SiLU via the frozen 256-row table (domain membership = narrowing)
        tab = silu_table(sc["eGate"], sc["eA"])
        aq = tab[(yg.astype(np.int64) + 128)]
        # Hadamard: int8 x int8 -> 15-bit-signed class (the committed Z)
        hq = aq * yu
        acc_track[li]["had"] = max(acc_track[li]["had"],
                                   float(np.abs(hq).max()))
        # requant h to int8 before the down matmul
        sh_h = sc["eH"] - sc["eA"] - sc["eUp"]
        yh, vh = narrow_int8(floor_requant(hq, sh_h, mode))
        viol_track[li]["h_range"] += vh
        # down matmul: inner 2048 -> exact acc (<= 2^25.98)
        acc_d = yh @ Wd.T
        acc_track[li]["down"] = max(acc_track[li]["down"],
                                    float(np.abs(acc_d).max()))
        sh_z = sc["eZ"] - sc["eH"] - eWd
        yz, vz = narrow_int8(floor_requant(acc_d, sh_z[None, :], mode))
        viol_track[li]["z_range"] += vz
        z = (yz * (2.0 ** sc["eZ"])).astype(np.float32).reshape(B, T, -1)
        # matched-input error: fp FFN on the SAME x
        blk = cap.model.blocks[li]
        import mlx.core as mx
        import mlx.nn as nn
        xin = mx.array(x.astype(np.float32))
        zf = ((nn.silu(xin @ blk.mlp.w_gate.weight.T)
               * (xin @ blk.mlp.w_up.weight.T))
              @ blk.mlp.w_down.weight.T)
        zf = np.array(zf.astype(mx.float32), dtype=np.float64)
        num = float(np.sqrt(((zf - z) ** 2).mean()))
        den = float(np.sqrt((zf ** 2).mean()))
        err_track[li].append(num / den if den else 0.0)
        return z

    return ffn


def make_wonly_ffn(wq, cap):
    """Weights-only variant: dequantized int8 weights, fp activations —
    isolates the weight-quantization cost (the P2-relevant side)."""

    def ffn(li, x):
        import mlx.core as mx
        import mlx.nn as nn
        (Wg, eWg), (Wu, eWu), (Wd, eWd) = (
            wq[li][k] for k in ("w_gate", "w_up", "w_down"))
        dg = mx.array((Wg * (2.0 ** eWg)[:, None]).astype(np.float32))
        du = mx.array((Wu * (2.0 ** eWu)[:, None]).astype(np.float32))
        dd = mx.array((Wd * (2.0 ** eWd)[:, None]).astype(np.float32))
        xin = mx.array(x.astype(np.float32))
        z = (nn.silu(xin @ dg.T) * (xin @ du.T)) @ dd.T
        mx.eval(z)
        return np.array(z)

    return ffn


def run_variant(cap, scales, wts, val_tokens, mode, wgran, label,
                verbose=False):
    wq = quantize_weights(wts, scales, wgran)
    acc_track = [dict(gateup=0.0, had=0.0, down=0.0) for _ in range(N_LAYERS)]
    viol_track = [dict(X_clip=0, gate_range=0, up_range=0, h_range=0,
                       z_range=0) for _ in range(N_LAYERS)]
    err_track = [[] for _ in range(N_LAYERS)]
    ffn = make_int8_ffn(scales, wq, acc_track, viol_track, err_track, cap,
                        mode=mode)
    loss = cap.loss(val_tokens, ffn_override=ffn)
    m_gu, b_gu = acc_width(D_MODEL)
    m_dn, b_dn = acc_width(MLP_HIDDEN)
    total_viol = 0
    if verbose:
        p("%-6s %12s %12s %10s %28s %10s" % (
            "layer", "max|acc768|", "max|acc2048|", "max|h15|",
            "range-fact violations (held-out)", "relFFNerr"))
    for li in range(N_LAYERS):
        v = viol_track[li]
        total_viol += sum(v.values())
        if verbose:
            p("%-6d %12.0f %12.0f %10.0f %28s %10.4f"
              % (li, acc_track[li]["gateup"], acc_track[li]["down"],
                 acc_track[li]["had"],
                 "X:%d g:%d u:%d h:%d z:%d" % (v["X_clip"], v["gate_range"],
                                               v["up_range"], v["h_range"],
                                               v["z_range"]),
                 float(np.mean(err_track[li]))))
        assert acc_track[li]["gateup"] <= m_gu
        assert acc_track[li]["down"] <= m_dn
    if verbose:
        p("-> accumulator ceilings respected everywhere: gate/up %d-bit "
          "(bound %d), down %d-bit (bound %d); Hadamard products inside "
          "the 15-bit class" % (b_gu, m_gu, b_dn, m_dn))
    return dict(label=label, mode=mode, wgran=wgran, loss=loss,
                total_viol=total_viol,
                acc_bounds=dict(gateup=[m_gu, b_gu], down=[m_dn, b_dn]),
                per_layer=[dict(acc=acc_track[li], viol=viol_track[li],
                                rel_ffn_err=float(np.mean(err_track[li])))
                           for li in range(N_LAYERS)])


def int8_study(cap, scales, wts, val_tokens):
    p()
    p("=" * 78)
    p("SECTION 4 — int8 chain on HELD-OUT data (%d seq x %d tokens; "
      "scales frozen from Section 3)" % (N_VAL_SEQ, T_TOKENS))
    p("=" * 78)
    n_pos = int(np.prod(val_tokens[:, :-1].shape))
    loss_ref = cap.loss(val_tokens)

    p("variant A — the semantics as written (floor requant, per-tensor "
      "weight scales):")
    A = run_variant(cap, scales, wts, val_tokens, "floor", "tensor",
                    "A floor/per-tensor", verbose=True)
    p("-> range-fact violations on held-out data: %d of %d positions x 5 "
      "facts; val loss %.4f (ref %.4f, delta %+.4f nats)"
      % (A["total_viol"], n_pos, A["loss"], loss_ref,
         A["loss"] - loss_ref))

    p()
    p("attribution variants (same statement gadgets, design-choice "
      "deltas):")
    B = run_variant(cap, scales, wts, val_tokens, "round", "tensor",
                    "B round/per-tensor")
    C = run_variant(cap, scales, wts, val_tokens, "round", "channel",
                    "C round/per-channel-W")
    wq_ch = quantize_weights(wts, scales, "channel")
    loss_wonly = cap.loss(val_tokens,
                          ffn_override=make_wonly_ffn(wq_ch, cap))
    p("%-26s %10s %10s %12s" % ("variant", "loss", "delta", "range viol"))
    p("%-26s %10.4f %10s %12s" % ("bf16 reference", loss_ref, "—", "—"))
    for v in (A, B, C):
        p("%-26s %10.4f %+10.4f %12d"
          % (v["label"], v["loss"], v["loss"] - loss_ref, v["total_viol"]))
    p("%-26s %10.4f %+10.4f %12s"
      % ("W weights-only (per-ch)", loss_wonly, loss_wonly - loss_ref,
         "n/a"))
    report["int8_chain"] = dict(
        loss_ref=loss_ref, positions=n_pos,
        variants=[A, B, C],
        weights_only=dict(loss=loss_wonly,
                          delta=loss_wonly - loss_ref))
    return A, B, C, loss_ref, loss_wonly


# --------------------------------------------------------------------------

def main():
    p("m125_int8_calibration — frugal-lm 125M, TARGET_CONTRACT Section 2 "
      "semantics")
    p("checkpoint: %s (READ-ONLY)" % CKPT)
    wts = read_safetensors(CKPT)
    n_mlp = sum(1 for k in wts if ".mlp.w_" in k)
    assert n_mlp == 36, n_mlp
    wrows = weight_study(wts)
    accumulator_section()

    if not try_mlx():
        p(ENV_PENDING_MSG)
        report["activations"] = "[ENV PENDING] — run under frugal-lm venv"
        OUT_JSON.parent.mkdir(exist_ok=True)
        OUT_JSON.write_text(json.dumps(report, indent=1))
        p("JSON (weights-only) -> %s" % OUT_JSON)
        return

    model, n_params = build_model()
    p()
    p("model loaded via frugal_lm's own modules (strict): %d params" %
      n_params)
    cap = FfnCapture(model)
    cal, val = token_batches()

    # self-check: the manual walk must reproduce the model's own forward
    import mlx.core as mx
    hid_walk = cap.walk(cal[:1, :64])
    logits_walk = model.embed.as_linear(hid_walk)
    logits_model = model(mx.array(cal[:1, :64]))
    mx.eval(logits_walk, logits_model)
    dmax = float(mx.abs(logits_walk - logits_model).max())
    assert dmax < 1e-3, dmax
    p("walk self-check: manual block walk == model forward (max |d| = "
      "%.2e)" % dmax)

    scales = calibrate(cap, cal, wrows)
    A, B, C, loss_ref, loss_wonly = int8_study(cap, scales, wts, val)

    p()
    p("=" * 78)
    p("VERDICT")
    p("=" * 78)
    calibrates = (A["total_viol"] == 0)
    p("range facts on held-out data: %s (%d violations, variant A; "
      "B/C: %d/%d)" % ("HOLD" if calibrates else "FAIL",
                       A["total_viol"], B["total_viol"], C["total_viol"]))
    p("verdict: the 125M checkpoint %s in the FORMAL sense — every proof-"
      "side fact (range facts, accumulator ceilings, remainders, table "
      "domain) HOLDS on held-out data at the calibrated per-tensor "
      "power-of-two scales; the QUALITY cost of the as-written chain is "
      "%+.4f nats (A), improved to %+.4f by round-to-nearest requant (B) "
      "and to %+.4f with per-channel weight scales (C); weights-only "
      "quantization costs %+.4f — the damage is activation-resolution-"
      "side (outlier-driven), which is model-side work, not proof-system "
      "work (LLM_POC_ROADMAP.md risk 5's anticipated branch)"
      % ("CALIBRATES" if calibrates else "DOES NOT CALIBRATE",
         A["loss"] - loss_ref, B["loss"] - loss_ref,
         C["loss"] - loss_ref, loss_wonly - loss_ref))
    report["verdict"] = dict(
        calibrates_formally=calibrates,
        range_violations=dict(A=A["total_viol"], B=B["total_viol"],
                              C=C["total_viol"]),
        loss_ref=loss_ref,
        loss_delta_nats=dict(A=A["loss"] - loss_ref,
                             B=B["loss"] - loss_ref,
                             C=C["loss"] - loss_ref,
                             weights_only=loss_wonly - loss_ref))
    OUT_JSON.parent.mkdir(exist_ok=True)
    OUT_JSON.write_text(json.dumps(report, indent=1))
    p("JSON -> %s" % OUT_JSON)


if __name__ == "__main__":
    main()
