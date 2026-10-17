#!/usr/bin/env python3
"""Lane C scratch probe (2026-09-30): can the FROZEN integer calibration of the
private block (power-of-two shifts in layout.rs:62-80, one int16 residual scale
shared by every block) carry the TRAINED TinyLlama-1.1B stack?

This is a float dynamic-range measurement on two PUBLIC prompts, not a
calibration and not a proof. It records aggregate statistics only (maxima,
percentiles, RMS), never activations. The float forward is checked against
Hugging Face transformers' LlamaModel on the first two layers before use.

Constraint algebra (scales s_* = float value of one integer unit; see PLAN.md
section C for the derivation):
  C1 (attention output into the int16 residual, SH_AO = 7, residual shift 0):
     feasible iff max|v| * max|Wo| <= 127^2 / 128 * s_x
  C2 (down projection into the int16 residual, SH_Z = 6, residual shift 0):
     feasible iff max|Wd| * 64 * s_h_min <= 127 * s_x, with
     s_h_min = max(max|h|/32767, s_a_min * s_u_min * 2^14)
  C3 (up projection is EXACT, SH_U = 0, into int16): s_u = s_nm * s_wu >= max|u|/32767
  N  (norm output int8, multiplier mu = Cn / 2^tn): |y| <= 127 needs
     mu <= 127 * sqrt(d) / max|g_int * z|; the frozen mu is 1024 / 2^11 = 0.5
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
import time
from pathlib import Path

import torch
from safetensors import safe_open

torch.set_num_threads(2)
MODEL_DIR = Path.home() / "models/tinyllama-1.1b-chat-fe8a4ea1"
OUT = Path(__file__).resolve().parent / "calib_range_probe.json"
T = 32
D, F, HQ, HKV, DH, L = 2048, 5632, 32, 4, 64, 22
EPS, THETA = 1e-5, 10000.0

PROMPTS = [
    "The quick brown fox jumps over the lazy dog while the scientist writes a careful report about proofs, privacy and large language models on a small laptop.",
    "<|user|>\nExplain in two sentences why zero-knowledge proofs of neural network inference are expensive, and what could make them cheaper.</s>\n<|assistant|>\n",
]


def sp_pieces(path: Path) -> list[tuple[str, float]]:
    """Minimal protobuf parse of a SentencePiece ModelProto: field 1 pieces."""
    buf = path.read_bytes()
    i, out = 0, []

    def varint(b, j):
        v, s = 0, 0
        while True:
            c = b[j]
            j += 1
            v |= (c & 0x7F) << s
            s += 7
            if c < 0x80:
                return v, j

    while i < len(buf):
        key, i = varint(buf, i)
        field, wt = key >> 3, key & 7
        if wt == 2:
            n, i = varint(buf, i)
            body = buf[i:i + n]
            i += n
            if field == 1:
                j, piece, score = 0, "", 0.0
                while j < len(body):
                    k2, j = varint(body, j)
                    f2, w2 = k2 >> 3, k2 & 7
                    if w2 == 2:
                        m, j = varint(body, j)
                        if f2 == 1:
                            piece = body[j:j + m].decode("utf-8")
                        j += m
                    elif w2 == 5:
                        if f2 == 2:
                            score = struct.unpack("<f", body[j:j + 4])[0]
                        j += 4
                    elif w2 == 0:
                        _, j = varint(body, j)
                    else:
                        raise ValueError("unexpected wire type")
                out.append((piece, score))
        elif wt == 0:
            _, i = varint(buf, i)
        elif wt == 5:
            i += 4
        elif wt == 1:
            i += 8
        else:
            raise ValueError("unexpected wire type")
    return out


def tokenize(text: str, vocab: dict[str, int]) -> list[int]:
    """Greedy longest-match over SentencePiece pieces with byte fallback. An
    approximation of the real tokenizer: good enough for dynamic ranges."""
    s = "▁" + text.replace(" ", "▁")
    ids, i = [1], 0  # BOS
    maxlen = max(len(p) for p in vocab)
    while i < len(s):
        for n in range(min(maxlen, len(s) - i), 0, -1):
            if s[i:i + n] in vocab:
                ids.append(vocab[s[i:i + n]])
                i += n
                break
        else:
            for b in s[i].encode("utf-8"):
                ids.append(vocab[f"<0x{b:02X}>"])
            i += 1
    return ids


def rope(x, pos):
    # HF Llama half-split rotation (rotate_half), theta 10000
    inv = 1.0 / (THETA ** (torch.arange(0, DH, 2, dtype=torch.float64) / DH))
    ang = pos[:, None].double() * inv[None, :]
    cos = torch.cat([ang.cos(), ang.cos()], -1).float()
    sin = torch.cat([ang.sin(), ang.sin()], -1).float()
    x1, x2 = x[..., : DH // 2], x[..., DH // 2:]
    rot = torch.cat([-x2, x1], -1)
    return x * cos[None] + rot * sin[None]


def rmsnorm(x, g):
    return x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + EPS) * g


def stats(t):
    a = t.detach().abs().flatten().double()
    q = torch.quantile(a[torch.randperm(a.numel(), generator=torch.Generator().manual_seed(0))[:1_000_000]] if a.numel() > 1_000_000 else a,
                       torch.tensor([0.5, 0.99, 0.999], dtype=torch.float64))
    return {"max": float(a.max()), "p50": float(q[0]), "p99": float(q[1]), "p999": float(q[2]), "rms": float(a.pow(2).mean().sqrt())}


def layer_tensors(f, k):
    p = f"model.layers.{k}."
    g = lambda n: f.get_tensor(p + n).float()
    return {
        "wq": g("self_attn.q_proj.weight"), "wk": g("self_attn.k_proj.weight"), "wv": g("self_attn.v_proj.weight"),
        "wo": g("self_attn.o_proj.weight"), "ga": g("input_layernorm.weight"), "gm": g("post_attention_layernorm.weight"),
        "wg": g("mlp.gate_proj.weight"), "wu": g("mlp.up_proj.weight"), "wd": g("mlp.down_proj.weight"),
    }


RESIDUAL_MAX = 170.0  # a bound on max|x| over every layer of both prompts, set from a first pass


def residual_quantization(x):
    """What rounding the residual stream to an integer class does to the next
    norm's input: cosine of the normalized vectors and the median relative
    error of the channels below 1.0 in magnitude (the non-outlier channels)."""
    out = {}
    z = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + EPS)
    small = (x.abs() < 1.0) & (x.abs() > 1e-6)
    for name, s in (("int16_global", RESIDUAL_MAX / 32767), ("int16_this_layer", float(x.abs().max()) / 32767),
                    ("int24_global", RESIDUAL_MAX / 8388607), ("int32_global", RESIDUAL_MAX / 2147483647)):
        xq = torch.round(x / s) * s
        zq = xq * torch.rsqrt(xq.pow(2).mean(-1, keepdim=True) + EPS)
        cos = torch.nn.functional.cosine_similarity(z, zq, dim=-1).min()
        rel = ((xq - x).abs() / x.abs())[small]
        out[name] = {"unit": s, "min_token_cosine": float(cos), "median_rel_err_small_channels": float(rel.median()) if rel.numel() else 0.0,
                     "zero_fraction_small_channels": float((xq[small] == 0).double().mean()) if rel.numel() else 0.0}
    return out


def block(x, w, record):
    t = x.shape[0]
    pos = torch.arange(t)
    rec = record
    rec["x_in"] = stats(x)
    rec["x_in_quantization"] = residual_quantization(x)
    z = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + EPS)
    rec["z_norm_a"] = stats(z)
    na = z * w["ga"]
    rec["na"] = stats(na)
    rec["gamma_a"] = stats(w["ga"])
    q = na @ w["wq"].T
    k = na @ w["wk"].T
    v = na @ w["wv"].T
    rec["q"], rec["k"], rec["v"] = stats(q), stats(k), stats(v)
    qh = rope(q.view(t, HQ, DH).transpose(0, 1), pos)
    kh = rope(k.view(t, HKV, DH).transpose(0, 1), pos)
    vh = v.view(t, HKV, DH).transpose(0, 1)
    kh_r = kh.repeat_interleave(HQ // HKV, 0)
    vh_r = vh.repeat_interleave(HQ // HKV, 0)
    sc = qh @ kh_r.transpose(1, 2)  # raw q.k, before 1/sqrt(dh)
    mask = torch.triu(torch.ones(t, t, dtype=torch.bool), 1)
    rec["score_raw"] = stats(sc.masked_fill(mask, 0.0))
    p = torch.softmax((sc / math.sqrt(DH)).masked_fill(mask, float("-inf")), -1)
    o = (p @ vh_r).transpose(0, 1).reshape(t, D)
    rec["o"] = stats(o)
    ao = o @ w["wo"].T
    rec["ao"] = stats(ao)
    x1 = x + ao
    rec["x1"] = stats(x1)
    zm = x1 * torch.rsqrt(x1.pow(2).mean(-1, keepdim=True) + EPS)
    nm = zm * w["gm"]
    rec["z_norm_m"], rec["nm"], rec["gamma_m"] = stats(zm), stats(nm), stats(w["gm"])
    g = nm @ w["wg"].T
    u = nm @ w["wu"].T
    a = torch.nn.functional.silu(g)
    h = a * u
    zz = h @ w["wd"].T
    rec["g"], rec["u"], rec["a"], rec["h"], rec["z"] = stats(g), stats(u), stats(a), stats(h), stats(zz)
    x2 = x1 + zz
    rec["x2"] = stats(x2)
    for n in ("wq", "wk", "wv", "wo", "wg", "wu", "wd"):
        rec[n] = stats(w[n])
    # the two norm outputs' int8 need, in units of the frozen code
    rec["max_abs_gammaint_times_z_a"] = float((z * (w["ga"] / w["ga"].abs().max() * 127)).abs().max())
    rec["max_abs_gammaint_times_z_m"] = float((zm * (w["gm"] / w["gm"].abs().max() * 127)).abs().max())
    return x2


def check_against_hf(f, ids):
    from transformers import LlamaConfig, LlamaModel
    cfg = LlamaConfig(vocab_size=32000, hidden_size=D, intermediate_size=F, num_hidden_layers=2, num_attention_heads=HQ,
                      num_key_value_heads=HKV, rms_norm_eps=EPS, rope_theta=THETA, max_position_embeddings=2048)
    m = LlamaModel(cfg).float().eval()
    sd = {}
    for name in m.state_dict():
        src = "model." + name
        sd[name] = f.get_tensor(src).float() if not name.startswith("norm") else torch.ones(D)
    m.load_state_dict(sd)
    with torch.no_grad():
        out = m(torch.tensor([ids]), output_hidden_states=True)
    hf = [h[0] for h in out.hidden_states[:3]]
    del m
    return hf


def main():
    t0 = time.time()
    vocab = {p: i for i, (p, _) in enumerate(sp_pieces(MODEL_DIR / "tokenizer.model"))}
    seqs = []
    for text in PROMPTS:
        ids = tokenize(text, vocab)
        if len(ids) < T:
            raise SystemExit(f"prompt too short: {len(ids)} tokens")
        seqs.append(ids[:T])
    st = MODEL_DIR / "model.safetensors"
    result = {"schema": "lane-c-calib-range-probe/1", "model": "TinyLlama/TinyLlama-1.1B-Chat-v1.0@fe8a4ea1", "tokens": T,
              "prompts_sha256": hashlib.sha256("\n".join(PROMPTS).encode()).hexdigest(),
              "tokenizer": "greedy longest-match over tokenizer.model pieces (approximation)", "sequences": []}
    with torch.no_grad(), safe_open(str(st), framework="pt") as f:
        emb = f.get_slice("model.embed_tokens.weight")
        # validation: our float forward vs transformers on layers 0 and 1
        hf = check_against_hf(f, seqs[0])
        x = torch.stack([emb[i:i + 1][0].float() for i in seqs[0]])
        ours = [x]
        for k in range(2):
            x = block(x, layer_tensors(f, k), {})
            ours.append(x)
        # HF's last hidden state is taken AFTER the final norm (weight set to 1)
        ours[2] = ours[2] * torch.rsqrt(ours[2].pow(2).mean(-1, keepdim=True) + EPS)
        err = [float((a - b).abs().max() / b.abs().max()) for a, b in zip(ours, hf)]
        result["hf_check_rel_err_layers_0_1"] = err
        if max(err) > 1e-3:
            raise SystemExit(f"float forward disagrees with transformers: {err}")
        for s, ids in enumerate(seqs):
            x = torch.stack([emb[i:i + 1][0].float() for i in ids])
            layers = []
            for k in range(L):
                rec = {"layer": k}
                x = block(x, layer_tensors(f, k), rec)
                layers.append(rec)
            result["sequences"].append({"index": s, "n_tokens": len(ids), "layers": layers})
    result["seconds"] = time.time() - t0
    OUT.write_text(json.dumps(result, indent=1) + "\n")
    print(json.dumps({"hf_check": result["hf_check_rel_err_layers_0_1"], "seconds": result["seconds"]}))


if __name__ == "__main__":
    sys.exit(main())
