# THE FULL-LAYER PROOF on the hash line (U-PERF3 lane AG, 2026-09-03)

> **SUPERSEDED IN PART, 2026-09-04.** Every number below is lane AG's
> round-13 measurement and is left exactly as recorded — it is the
> history, not the current default. Lane AK then built the claim fold
> (the 60 tok/s plan's lever L5), which is now ON by default and moves
> the proof BYTES: the 12-layer pass 404,327,452 -> 282,217,500 B
> (-30.2%, verify -69%, prove +7.1%), one 125M layer at T=512
> 33,234,332 -> 23,539,100 B, one Mistral layer at T=16 48,478,456 ->
> 42,977,736 B. Setting `HL_NO_FOLD=1` reproduces every digest on this
> page byte for byte, which is how these results stay checkable.
> Current record: `results/hashline_attn_fold.md`.

The measured record behind the FULL-LAYER rows in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3, in the form of
lane XX's results/hashline_gpu_12x512.md. Every number is [MEASURED] on
the WSL laptop (Core Ultra 9 185H, 22 threads, 15 GB), 8 rayon threads,
CPU only, label [WSL-BOX 8T CPU NOISY-SHARED] (lane AH built and ran on
the same box during these runs). Lane AG's commits are listed in
PROGRESS_UPERF3.md, "Agent AG status".

## 1. What is proven that was not proven before

Every hash-line proof before this one covered the **feed-forward half**
of a transformer layer: the attention block, the two RMSNorms and the
residual stream were outside the statement, and each layer's input was
committed afresh from the export instead of being derived from the
previous layer.

This record covers **whole layers**, and (section 4) a whole 12-layer
model:

    x_in --(attn_norm)--> xn8 --(Wq/Wk/Wv)--> q8/k8/v8 --(RoPE)--> qr8/kr8
        --(per-head scores)--> s8 --(softmax)--> P --(PV)--> o8
        --(Wo)--> ao --(residual)--> xres1 --(mlp_norm)--> xm8
        --(the v3 FFN)--> z16 --(residual)--> xres2 = the next layer's x_in

with every arrow a proven relation over ONE transcript. The proving
primitives, per object:

| object | how it is proven |
|---|---|
| SS_t = sum_i x(t,i)^2 (both norm sites) | one degree-3 row-sum sumcheck, terminal tied to the committed x |
| D_t = isqrt(SS + Ceps) | the pair a1 = SSe - D^2, a2 = 2D - a1 with both in U16 limb pairs, plus a D^2 zero-check |
| the norm division (ROUND) | y (2 div) + rho = 2 x g Cn + div in a (t,i) zero-check, D row-broadcast and gamma column-broadcast (both free: a broadcast table's MLE at (r_t, r_i) IS the small plane's MLE), rho and sigma as U16 limb pairs |
| Q, K, V | ONE batched matmul sumcheck over the inner d (three output points, one folded x table) |
| RoPE | a zero-check reading q8 at the COORDINATE-FLIPPED point against the public cos/sin tables (the flip is one point coordinate r -> 1 - r) |
| the per-head scores | ONE sumcheck over (kv head, head dim): the GQA map is the high bits of the padded head index, so it is free |
| s8, rS, P, rho, sigma | LogUp against INT8 / the balanced window / PROB / SREM |
| the exponential | the FUSED (d, E) LogUp row with d = m - (mask s8 - 127(1 - mask)) computed inside the constraint — E is never committed as a lookup key |
| m (the row maximum) | dominance from the fused row's domain [0,255], attainment from zsel binary + sum_j zsel = 1 + zsel d = 0 |
| Sum | the masked row-sum sumcheck, batched with sum_j zsel = 1 |
| the softmax division | mask (P Sum + rho - 2^fP E) + (1 - mask)(P + rho) = 0 with Sum row-broadcast |
| PV, Wo | one sumcheck each |
| the requant edges, the residual pins, sigma = 2 div - 1 - rho, the isqrt pair, the limb reconstructions | POINTWISE-LINEAR: checked on the claimed evaluations at the zero-checks' random points — sound by Schwartz-Zippel, free in the prover |
| **the inner seam** (the FFN's X IS the attention's xm8; the residual pin's z16 copy IS the FFN's z16) | two claims per d-block at the point the FFN's own zero-check D drew AFTER both A commitments; the attention half's opening is deferred until then |
| **the layer seam** (layer l's xres2 IS layer l+1's x_in) | one MLE equality at a point drawn after BOTH layers' A commitments; layer l's A opening deferred until layer l+1 has committed |

## 2. ONE FULL LAYER — 125M (d 768, f 2048, H 12/4, d_h 64), layer 0

    hashline attn-full <attn-export> --export <v3-export> --t 512 --threads 8

| shape | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **FULL layer, T = 512** | **10.12 s** (8.77 s on a second run) | 0.23 s | 33.2 MB (attention half 27.3) | 5.10 GB | ACCEPT |
| FFN-only layer, T = 512 | 1.65 s | 0.03 s | 5.90 MB | 1.12 GB | ACCEPT |
| **ratio** | **6.1x** | 7.4x | 5.6x | 4.5x | |
| FULL layer, T = 256 | 4.21 s | 0.29 s | 27.0 MB | 2.11 GB | ACCEPT |
| FULL layer, T = 128 | 2.68 s | 0.28 s | 24.1 MB | 1.06 GB | ACCEPT |
| FULL layer, T = 64 | 1.15 s | 0.13 s | 23.0 MB | — | ACCEPT |

Lane AE's rung-3.5 count predicted 4.58x on committed elements; the
measured 6.1x is that count plus this build's two deliberate trades
(section 5).

## 3. THE TAMPER LEGS — 12 distinct legs, all REJECT

At T = 512 and T = 64 (125M) and at T = 16 (Mistral-7B). A cheating
prover's own consistency asserts are silenced (`set_tamper_mode`), so
what rejects is the VERIFIER.

| leg | rejected by |
|---|---|
| flipped score s8 | the score matmul sumcheck |
| wrong exponential-table entry | the LogUp identity (125M) / the softmax zero-check (Mistral) |
| wrong softmax quotient P | the softmax zero-check |
| wrong norm output xn8 | the D-domain zero-check |
| wrong RoPE rotation qr8 | the Q-domain zero-check |
| wrong row maximum m | the softmax zero-check |
| flipped layer input x_in | the SS row-sum sumcheck |
| wrong isqrt D | the isqrt pair (a2 = 2D - a1) |
| moved attainment selector zsel | the softmax zero-check |
| **broken INNER seam** (the z16 copy changed and the residual pin RECOMPUTED, so only the seam can catch it) | **the seam claim** |
| **broken LAYER seam** (layer 1's x_in changed by one and its whole witness rebuilt on it, so every other relation still holds) | **the layer-seam claim** |
| FFN half: wrong int16 table entry / wrong requant h16 | the FFN's own LogUp / zero-check |

## 4. THE 12-LAYER FULL-MODEL PASS (the first full-model-coverage proof in this project)

    hashline attn-pass <attn-export-prefix> 12 --export <v3-export> --t 512 --threads 8

| pass | witness | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---:|---|
| **12 FULL layers x 512 tokens, seams bound** | 4.95 s | **94.54 s** | **2.03 s** | **404.3 MB** | **6.56 GB** | **ACCEPT** |
| 12 FFN-only layers x 512 (`pass 12 512 --profile v3`) | 1.60 s | 16.01 s | 0.43 s | 70.8 MB | ~1.2 GB | ACCEPT |
| **ratio** | | **5.9x** | 4.7x | **5.7x** | 5.5x | |
| 12 FULL layers x 64 tokens | 1.13 s | 17.37 s | 1.59 s | 281.5 MB | — | ACCEPT |

PROOF sha256 (the flat little-endian encoding of the 12 attention proofs
interleaved with the 12 FFN proofs, 404,327,452 B):

    c91f8713e2ed805543c1ca3a5f1c752734278606e7b13d199f1348dbf22f0ece

and at T = 64 (281,521,404 B): 05f54591e28630d831a05582839c5b0a357ff88bcd3e8548fa89f2f7412c1ed0

Proven work: 7,077,888 MAC per token per layer (3 d f + 2 d^2 + 2 d d_kv
+ 2 T d) = **4.349e10 MACs**, so **4.60e8 proven MAC/s** on this CPU
[MEASURED] against 1.8e9 for the FFN-only pass — the full statement
proves 3.9x fewer MAC/s because attention's committed planes are
quadratic in T while its MACs are not.

## 5. ONE FULL MISTRAL-7B LAYER (d 4096, f 14336, H 32/8, d_h 128), layer 0

The int24 residual class of lane AE's rung-1 verdict is exercised here:
xres1 and xres2 are committed as U16 + U8 limb pairs and reconstructed
linearly inside every constraint; ao is int16.

| shape | PROVE | VERIFY | proof | peak RSS | verdict |
|---|---:|---:|---:|---:|---|
| **FULL layer, T = 16** | **12.91 s** | 0.11 s | 48.5 MB (attention half 22.6) | 10.08 GB | ACCEPT (10/10 tamper legs reject) |
| FFN-only layer, T = 16 | 11.03 s | 0.04 s | 25.9 MB | 7.48 GB | ACCEPT |
| **ratio at T = 16** | **1.17x** | | 1.87x | 1.35x | |
| **FULL layer, T = 64** | **14.27 s** | 0.13 s | 52.8 MB | 11.24 GB | ACCEPT |
| FFN-only layer, T = 64 | 8.86 s | 0.02 s | 27.1 MB | 8.04 GB | ACCEPT |
| **ratio at T = 64** | **1.61x** | | 1.95x | 1.40x | |

The full-layer surcharge SHRINKS with width and grows with context, for
the same reason the ZK surcharge shrinks with width: at 8B width the
weight commitments dominate, and attention adds only 4 more weight
matrices (Wq/Wk/Wv/Wo) and — at small T — small activation planes. Lane
AE's count of 2.87x is a T = 512 number; the 32-layer full-model pass at
T = 512 is NOT measured here (its FFN-only row alone peaks at 14 GB on
this box, and the attention half adds ~2 GB plus the quadratic planes).

## 6. The two deliberate trades (and how to undo them)

1. **Padding, not blocking.** Every axis is padded to a power of two
   (d 768 -> 1024; the 12 query heads -> 16 slots, re-indexed so the kv
   group is the HIGH bits and the GQA map costs nothing) so that one
   plane is ONE Ligero slice. The padding is INERT, not zero-filled by
   fiat: the pad columns and pad heads carry the values the chain itself
   produces on zero inputs (a zero gamma column gives rho = div, sigma =
   div - 1; a zero query head gives its own softmax and its own PV), so
   every constraint holds on them unchanged. Cost: 1.33x on the two
   dominant domains at 125M; NOTHING at Mistral (4096 and 32 are already
   powers of two). Undo by blocking the way the v3 FFN prover blocks.
2. **Many opening points, not folded claims.** The v3 FFN prover folds
   every pending evaluation claim into its two zero-checks so that A and
   H open at two points; this prover opens at ~20 points, each costing
   one group vector of 2^log_cols field-extension elements. That is why
   the attention half's proof is 27.3 MB where the FFN half's is 5.9 MB:
   about 8 MB per layer is group vectors that folding would remove.
   Folding changes no soundness property.

## 7. What still is NOT proven (for an end-to-end model proof)

* **The embedding.** x_in of layer 0 is a committed input; its gather
  from token ids is not proven (the design memo's PW-5 selector).
* **The final norm and the LM head.** The last layer's xres2 is the
  proven output; the logits are not.
* **The KV cache / the decode regime.** The statement is prefill-only:
  every position's K and V are recomputed inside the proof. A decode
  step would carry the cached K/V planes as committed inputs bound by
  seams ACROSS proofs — the same mechanism this record uses between
  layers, one level up.
* **Sliding windows** at T > the window (T <= 4096 is plain causal for
  Mistral).
* **Zero knowledge** for the attention half (`--zk` covers the v2 and v3
  FFN statements; the attention prover is not ZK and its planes would
  need ZA's mask/pad treatment).
* **The GPU.** The attention half is CPU-only (the device path is
  Ligero+v3-shaped; `HL_GPU=1` changes nothing in `attn-full`). The FFN
  half inside a full layer still takes the device path when built with
  `--features gpu-cuda`.

## 8. Reproducing

    # the oracle export (per layer), python, ~30 s each at 125M
    python3 scripts/attention_hash_ref.py --arch 125m --layer L --export DIR_L
    # one full layer
    hashline attn-full DIR_0 --export <v3-export> --t 512 --threads 8 --all-tampers
    # the 12-layer full-model pass with the seams bound
    hashline attn-pass DIR_PREFIX 12 --export <v3-export> --t 512 --threads 8
    # the attention half alone (no FFN), with its own 12 legs
    hashline attn-layer DIR_0 --t 512 --threads 8 --all-tampers
    # the rung-3 digest gate (the oracle's 64 tensors)
    hashline attn-chain DIR_0
