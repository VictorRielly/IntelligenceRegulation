#!/usr/bin/env python3
"""Arithmetic behind GAP_ANALYSIS.md (2026-10-30). Pure arithmetic, no I/O
beyond stdout, one thread, well under 1 s and a few MiB.

Every input is quoted in GAP_ANALYSIS.md section 0 with its source. Labels:
MEASURED (someone ran it), CLAIMED (vendor/author number, not reproduced),
COUNTED (exact arithmetic on a published shape), INFERRED (assumption).
"""

def per_layer_dense(d, q_dim, kv_dim, f, gated=True):
    """multiply-accumulates per token for one transformer layer's weights"""
    attn = d * q_dim + 2 * d * kv_dim + q_dim * d
    ffn = (3 if gated else 2) * d * f
    return attn + ffn

def attn_scores_per_seq(heads, head_dim, t):
    """QK^T plus PV, dense T x T (no causal halving), one layer, one sequence"""
    return 2 * heads * head_dim * t * t

MODELS = {
    # name: (layers, per-layer weight MACs/token, heads, head_dim, lm_head MACs/token)
    "Shieldstral-3B (ours)": (26, per_layer_dense(3072, 4096, 1024, 9216), 32, 128, 3072 * 131072),
    "Llama-3-8B (ours)":     (32, per_layer_dense(4096, 4096, 1024, 14336), 32, 128, 4096 * 128256),
    "Gemma-3-1B (DeepProve)":(26, per_layer_dense(1152, 1024, 256, 6912), 4, 256, 1152 * 262144),
    "GPT-2 124M (DeepProve)":(12, per_layer_dense(768, 768, 768, 3072, gated=False), 12, 64, 768 * 50257),
    "LLaMA-2-13B (zkLLM)":   (40, per_layer_dense(5120, 5120, 5120, 13824), 40, 128, 5120 * 32000),
}

# cross-checks against counts already in the repository
assert per_layer_dense(3072, 4096, 1024, 9216) == 116_391_936      # SHIELDSTRAL_COST.md
assert per_layer_dense(4096, 4096, 1024, 14336) == 218_103_808    # SHIELDSTRAL_COST.md (8B words per block)

RUNS = [
    # label, model, T (proved positions), seconds, threads/hardware, proof bytes, verify s, kind, include_head
    ("ours: Shieldstral T128 classifier, violence (MEASURED)", "Shieldstral-3B (ours)", 128, 456.30, "8 thr Core Ultra 9 185H", 848_412_096, 69.30, "hidden IO", False),
    ("ours: Llama-3-8B T128 L32 older profile, prove (MEASURED)", "Llama-3-8B (ours)", 128, 393.785, "16 thr same laptop, GPU off", 922_711_264, 42.709, "hidden IO", False),
    ("DeepProve README: Gemma-3-1B T512 (CLAIMED)", "Gemma-3-1B (DeepProve)", 512, 18.95 * 60, "24-core EPYC 9254", 21.73 * 2**20, 4.32, "public IO", False),
    ("DeepProve README: Gemma-3-1B T512 + head every position (CLAIMED)", "Gemma-3-1B (DeepProve)", 512, 18.95 * 60, "24-core EPYC 9254", 21.73 * 2**20, 4.32, "public IO", True),
    ("DeepProve README: GPT-2 T512 (CLAIMED)", "GPT-2 124M (DeepProve)", 512, 7.64 * 60, "24-core EPYC 9254", 10.71 * 2**20, 1.33, "public IO", True),
    ("zkLLM CCS24 Table 1: LLaMA-2-13B T2048 (CLAIMED)", "LLaMA-2-13B (zkLLM)", 2048, 803.0, "A100 SXM4 40GB", 188_000, 3.95, "hidden weights, public input", False),
]

def macs(model, t, include_head):
    L, w, h, hd, head = MODELS[model]
    lin = L * w * t
    att = L * attn_scores_per_seq(h, hd, t)
    hd_m = head * t if include_head else 0
    return lin, att, hd_m

print("== per-token weight MACs (COUNTED) ==")
for k, (L, w, h, hd, head) in MODELS.items():
    print(f"{k:28s} stack {L*w/1e9:7.3f} G  lm-head {head/1e9:6.3f} G")

print("\n== runs: positions/s and proven MAC/s ==")
rows = {}
for lab, model, t, s, hw, pb, vs, kind, inc in RUNS:
    lin, att, hm = macs(model, t, inc)
    tot = lin + att + hm
    rows[lab] = (t / s, tot / s, lin / s)
    print(f"{lab}\n    {hw}; {kind}; {t} positions in {s:.1f} s -> {t/s:.3f} pos/s; "
          f"MACs {tot:.3e} (attention {att/tot*100:.1f}%, head {hm/tot*100:.1f}%) -> {tot/s:.3e} MAC/s; "
          f"proof {pb/1e6:.1f} MB; verify {vs} s")

ours = rows["ours: Shieldstral T128 classifier, violence (MEASURED)"]
ours8 = rows["ours: Llama-3-8B T128 L32 older profile, prove (MEASURED)"]

# paper-level and vendor claims without hardware or full shapes
paper = {
    "DeepProve paper, Gemma 3 single machine, 86 tok/min (CLAIMED, hardware unknown)": (86 / 60, MODELS["Gemma-3-1B (DeepProve)"][0] * MODELS["Gemma-3-1B (DeepProve)"][1]),
    "DeepProve paper, GPT-2 single machine, 174 tok/min (CLAIMED, hardware unknown)": (174 / 60, MODELS["GPT-2 124M (DeepProve)"][0] * MODELS["GPT-2 124M (DeepProve)"][1] + MODELS["GPT-2 124M (DeepProve)"][4]),
    "DeepProve paper, distributed 1855 tok/min if GPT-2 (CLAIMED, nodes unknown)": (1855 / 60, MODELS["GPT-2 124M (DeepProve)"][0] * MODELS["GPT-2 124M (DeepProve)"][1] + MODELS["GPT-2 124M (DeepProve)"][4]),
    "DeepProve paper, distributed 1855 tok/min if Gemma-3-1B (CLAIMED, nodes unknown)": (1855 / 60, MODELS["Gemma-3-1B (DeepProve)"][0] * MODELS["Gemma-3-1B (DeepProve)"][1]),
    "Attestable blog, Gemma-4-31B 53 tok/s batch 1 16K (CLAIMED, 1 H100)": (53.0, 3.1e10),
    "Attestable blog, Gemma-4-31B 77 tok/s 4x4K (CLAIMED, 1 H100)": (77.0, 3.1e10),
}
print("\n== ratios against ours (Shieldstral T128, 8 threads): >1 means they are faster ==")
for lab, (pos, macs_s, _) in rows.items():
    print(f"{lab:66s} tok/s x{pos/ours[0]:7.2f}   MAC/s x{macs_s/ours[1]:7.2f}")
for lab, (tps, mac_per_tok) in paper.items():
    print(f"{lab:66s} tok/s x{tps/ours[0]:7.2f}   MAC/s x{tps*mac_per_tok/ours[1]:7.2f}")

print("\n== proof size and verification against ours ==")
print(f"DeepProve Gemma T512 proof 21.73 MiB vs ours 848.4 MB: x{848_412_096/(21.73*2**20):.1f} larger ours (x{848_412_096/(27*2**20):.1f} against the root README's 27 MiB)")
print(f"zkLLM 13B proof <=188 kB vs ours: x{848_412_096/188_000:.0f}")
print(f"Attestable 4.35-7.92 MiB vs ours: x{848_412_096/(7.92*2**20):.0f}-x{848_412_096/(4.35*2**20):.0f}")

# hardware factors (INFERRED): our measured CPU->GPU port ratio and bandwidth ratios
cpu_to_4070 = 285 / 38.6      # MEASURED legacy public-IO FFN activation side, 8 CPU threads vs 4070 Laptop
bw = {"4070 Laptop": 256, "A100 SXM4 40GB": 1555, "H100 SXM": 3350, "RTX 5090": 1792}
print(f"\n== hardware factors (INFERRED) ==\nCPU(8 thr) -> 4070 Laptop, measured legacy FFN pass: x{cpu_to_4070:.1f}")
for k, v in bw.items():
    print(f"CPU(8 thr) -> {k:15s}: x{cpu_to_4070 * v / 256:6.1f}  (measured port ratio x bandwidth ratio)")
print("EPYC 9254 24C vs 8 laptop threads: x3-4 (core count and 12-channel DDR5 vs ~120 GB/s LPDDR5x)")

# residuals after hardware
zk = rows["zkLLM CCS24 Table 1: LLaMA-2-13B T2048 (CLAIMED)"][1] / ours[1]
print(f"\nzkLLM per-MAC lead x{zk:.1f}; after A100 hardware factor x{cpu_to_4070*1555/256:.0f}: residual x{zk/(cpu_to_4070*1555/256):.2f}")
att = 53 * 3.1e10 / ours[1]
print(f"Attestable per-MAC lead x{att:.0f}; after H100 hardware factor x{cpu_to_4070*3350/256:.0f}: residual x{att/(cpu_to_4070*3350/256):.1f}")
dp = rows["DeepProve README: Gemma-3-1B T512 (CLAIMED)"][1] / ours[1]
print(f"DeepProve README per-MAC: x{dp:.2f} (they are slower); after EPYC x3-4 hardware: ours ahead x{3/dp:.1f}-x{4/dp:.1f} per unit hardware")

# phase attribution, TinyLlama T128, 22 blocks, CPU (MEASURED, results/zk60_1b_native_20261017/r4/PHASES_T128.md)
walls = 152.2
hiding = {"extension rounds (CFS terminal masking)": 5.86 + 2.10 + 1.90 + 1.65 + 1.43 + 0.69,
          "A mask + proximity rows": 1.61, "H mask + zero-sum rows": 0.69, "M mask commit": 0.49,
          "IO endpoint equality slots 21/22": 1.05 + 0.92}
hs = sum(hiding.values())
print(f"\n== hiding-attributable phases, TinyLlama T128 CPU (MEASURED rows) ==")
for k, v in hiding.items():
    print(f"  {k:42s} {v:6.2f} s  {v/walls*100:5.1f}%")
print(f"  total {hs:.2f} s = {hs/walls*100:.1f}% of block walls -> factor x{walls/(walls-hs):.3f}")
hmach = 18.13 + 6.91 + 1.39 + 3.60
zc = 27.50 + 17.63 + 11.53 + 7.95 + 4.41
print(f"H helper machinery (commit + inverses + open H): {hmach:.2f} s = {hmach/walls*100:.1f}%; zero-checks {zc:.2f} s = {zc/walls*100:.1f}%")
amach = 16.56 + 5.15
print(f"A commit + open A: {amach:.2f} s = {amach/walls*100:.1f}%")

# H share of zero-check terms by domain (COUNTED from shape.rs claim_sites; legacy plane counts of the speed plan)
terms = {"D": (54, 17, 7.8), "S": (24, 9, 6.7), "F": (17, 6, 5.3), "Q": (15, 7, 1.9), "Kv": (13, 6, 1.1)}
num = sum(h / t * s for t, h, s in terms.values()); den = sum(s for *_, s in terms.values())
print(f"H tables' share of 8B T512 zero-check time (terms-weighted, MODEL law): {num/den*100:.1f}%")

# 8B T512 roofline at 40% of a 5090 (speed plan section 5), per block, seconds
roof = {"commit": 0.157, "zero-checks": 0.050, "inverses": 0.024, "openings": 0.015, "witness": 0.003, "host": 0.025}
base = sum(roof.values())
def apply(changes):
    r = dict(roof)
    for k, f in changes.items():
        r[k] = r[k] * f if not isinstance(f, tuple) else r[k] * f[0] + f[1]
    return sum(r.values())
h_share_commit = 0.55
zc_h = num / den
for lab, extra in [("masked LogUp-GKR, GKR work = 50% of today's zero-checks", 0.5),
                   ("masked LogUp-GKR, GKR work = 100% of today's zero-checks", 1.0)]:
    t = apply({"commit": 1 - h_share_commit, "openings": 1 - h_share_commit, "inverses": 0.5,
               "zero-checks": (1 - zc_h + extra, 0.0)})
    print(f"roofline 40%: {lab}: {base:.3f} -> {t:.3f} s/block = x{base/t:.2f}")
for lab, c in [("committed -10%", 0.90), ("committed -20%", 0.80), ("committed -30%", 0.70)]:
    t = apply({"commit": c, "openings": c, "zero-checks": c + (1 - c) / 2})
    print(f"roofline 40%: {lab} (zero-check terms half as much): x{base/t:.2f}")
print(f"budget for 50 pos/s at T512: {512/50/32:.3f} s/block; 40% roofline today {base:.3f}")
