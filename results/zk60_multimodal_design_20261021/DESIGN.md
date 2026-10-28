# Proving image, video and audio moderation with Shieldstral: design and cost

MULTIMODAL DESIGN lane, 2026-10-21 UTC (D37–D39). **Paper design and counting
only.** No prover code was written, nothing was built or proved, and nothing in
this note is a soundness or privacy acceptance. Every new relation below needs
the reviews listed in §7.3.

Labels used throughout:

- **[VERIFIED: source]** — read from the named primary source today: Shieldstral's
  Hugging Face files at repository sha `003ec7e2…` (last modified 2026-08-05), or
  the `transformers` main-branch source files named in §1.
- **[COUNTED]** — exact on the native lane's replica of the frozen R9 layout, at a
  geometry the code admits, or would admit once a profile exists for it (and, for
  the Shieldstral decoder, once F2 decouples head_dim). The replica reproduces
  every size the R9 prover printed (§9).
- **[MODEL]** — an estimate. It covers plane lists for relations that do not
  exist, the speed plan's calibrated cost law applied at new sizes, and its
  platform factors. The assumptions are stated where each estimate is used.

Files in this directory:

- `mm_cost.py`, the counting script. Its checks are in §9.
- `mm_cost.out` and `mm_cost.json`, the script's outputs.
- `PROGRESS.md`, the lane log.

---

## 0. Summary

**What an image needs.** Shieldstral reads an image through its own vision encoder
(Pixtral, 24 layers, about 0.42 B parameters). Then a small projector feeds the
result into the same text decoder that classifies text posts. The proof needs:

- **Five changes to existing relations** that add no committed planes:
  - a non-causal attention mask;
  - 2D RoPE tables;
  - a GELU table;
  - the 2×2 merge as a re-indexing;
  - Pixtral's block geometry.
- **Two new small stages:**
  - a front end: patch embedding and `ln_pre`;
  - a projector: norm, merge layer, linear, GELU, linear.

  Together the two stages add about 20.8 M committed elements per image at 224 px
  (0.28 of one encoder block) and 83 M at 448 px [MODEL].
- **One new splice slot** that places the image embeddings among the decoder's
  template tokens.

**Correction to the brief.** The 2×2 merge is *not* only a reshape.
`Mistral3PatchMerger` is an unfold followed by a learned bias-free
`Linear(4096 → 1024)` [VERIFIED: modeling_mistral3.py]. The unfold costs nothing;
the linear layer is an ordinary matmul site.

**Cost per image** [MODEL]. Today's code, recommended options (DD in the encoder,
F6 in the decoder). The laptop is the Core Ultra 9 with 15 GB; "5090, today" means
only the commitments on the GPU.

| canvas | laptop CPU | 5090, today | 5090, after the GPU port | peak memory | receipt |
|---|---|---|---|---|---|
| **224×224** | **~10 min** | ~4.4 min | ~30 s (after the speed plan's steps 1–4) | 7.2 GiB: fits | 1.46 GB |
| 448×448 | does not fit (33 GiB) | ~17 min (host RAM ≈ 25 GiB) | ~1.7 min | | 3.3 GB |
| 896×896 | no machine we have | no machine we have | — | 219–285 GiB per block | |

At 896 px the encoder's attention alone is 16× that of 448 px.

**Where the cost is.**

- **At 224 px the text decoder costs more than the vision encoder** (332 s against
  188 s on the laptop law).
- **A Shieldstral decoder block costs the same as a Llama-3-8B block at the same
  context length [COUNTED].** Its widths 3072 and 9216 pad to the 8B's 4096 and
  16384.
  - So a 64-token text post (156 positions, padded to 256) needs 14 GiB without
    public-prefix KV reuse (F6). It does not fit the laptop's CPU path.
  - With F6 it needs 7.2 GiB.
  - A "split-width" layout (3072 = 2048 + 1024 and 9216 = 8192 + 1024) would cut
    the decoder's committed elements by about 22–26% [MODEL bound]. This is a lever
    for the token lane.

**Binding the proof to the posted image (§3).**

- The proof's input is the canonical preprocessed pixel tensor. The run's input
  endpoint already commits to it with a *hiding* commitment: its masks and salted
  leaves act as a salt.
- Recommended MVP: a public, integer-only preprocessing spec applied to a lossless
  master of the post. The endpoint's opening randomness is shipped **with the post**
  (tens of KB [MODEL]).
- Anyone who can see the post recomputes the canonical tensor and the endpoint root,
  and checks that it equals the one in the verified statement. Anyone who sees only
  the proof or the chain anchor learns nothing about the image, and cannot test
  candidate images.
- This needs no new relation. It does need a reading of D23 (§8).

**Video (§4).** Frames are sampled with a public, content-independent rule and each
is proved as an image. The video is unsafe if any frame is. With a 30-second clip at
224 px [MODEL]:

| sampling | frames | laptop | 5090, today | 5090, after the port | receipts |
|---|---|---|---|---|---|
| 0.2 frames/s | 6 | ~53 min | ~22 min | ~2.8 min | 8.8 GB |
| 1 frame/s | 30 | ~4.4 h | ~1.8 h | ~14 min | 44 GB |

- Proof size is the binding constraint. One frame per second is impractical to
  publish without a succinct wrapper.
- Sampling misses everything between frames and all audio, and the verdict must say
  so.

**Audio (§5).** A proved speech recogniser (Whisper) is a different architecture:
encoder–decoder, LayerNorm, biases, cross-attention, a 1,500-frame encoder for every
30-second window. Whisper-tiny's encoder alone is about 1.3 G committed elements per
layer (63 GiB on the CPU path) [MODEL]. For the POC:

- no audio proof;
- captions or subtitles supplied with the video are proved as a text post and
  combined into the verdict;
- the verdict is labelled "visual frames + supplied captions; audio not assessed".

---

## 1. What the model actually computes [VERIFIED]

Sources:

- Shieldstral's files: `config.json`, `params.json`, `processor_config.json`,
  `chat_template.jinja` and `README.md` at sha `003ec7e2…`;
- `transformers` main: `models/pixtral/modeling_pixtral.py`,
  `models/mistral3/modeling_mistral3.py`, `models/pixtral/image_processing_pixtral.py`
  and `models/pixtral/processing_pixtral.py`.

The prep lane pins the same revision (`results/zk60_shieldstral_prep_20261021/PROGRESS.md`).

| piece | what it does | notes for the prover |
|---|---|---|
| Preprocessing | Convert to RGB. Resize (bicubic, `resample: 3`) so the longest edge is at most 1540 px and each side is a multiple of **28 px** (patch 14 × merge 2). Rescale by 1/255. Normalise with the CLIP mean and std | Float, and in HF it runs in torchvision, so it is not bit-reproducible. Our canonical spec replaces it (§3.2) |
| Patch embedding | `Conv2d(3 → 1024, kernel 14, stride 14, bias=False)` | A matmul over unfolded 3×14×14 = 588-value patches |
| `ln_pre` | RMSNorm(1024, eps 1e-5) on the patch embeddings, **before** layer 0 | Not in the brief. One norm whose output is the residual stream |
| 24 encoder layers | Pre-norm RMSNorm → MHA (16 heads × 64, **16 KV heads**, scale 64^-0.5 = 1/8, bias-free) → residual; RMSNorm → SwiGLU (4096, SiLU) → residual | The Llama block at d 1024, MHA. No final norm (`vision_feature_layer: -1`) |
| 2D RoPE | θ = 1e4, axial. Of the 32 rotation pairs per head, 16 use the patch row × the even-index frequencies and 16 the column × the odd-index ones, in HF's `rotate_half` layout | Only the public cos/sin values change (§2.3) |
| Attention mask | Block-diagonal over images, non-causal inside an image | One image per proof means full attention (§2.2) |
| Projector norm | RMSNorm(1024, eps 1e-5) | |
| Patch merger | `unfold(2×2)`, feature order (d, kh, kw), then **`Linear(4096 → 1024, bias=False)`** | The unfold is a free re-indexing; the linear layer is a matmul (§2.5) |
| Projector MLP | `Linear(1024 → 3072)` → **GELU (exact erf, `projector_hidden_act: gelu`)** → `Linear(3072 → 3072)`, all bias-free | One activation table (§2.6) |
| Decoder tokens | Per merged-grid row: one `[IMG]` per merged patch, then `[IMG_BREAK]`. The last break becomes `[IMG_END]`. **Count = rows × (cols + 1)**: 272 at 448², 72 at 224² | `[IMG]` positions take projector outputs; break/end are ordinary public tokens; 1D positions in the decoder |
| Prompt | The model card's image form is a **[text, image, text] sandwich**: the whole public `<Instruct>…<Query>…<Document>: ` prefix, then the image, then `" {caption}\n\n"`, then `[/INST]` | The public prefix (87–91 tokens) comes **before** the image, so public-prefix KV reuse (F6) still works. The template moves the image first only for a two-block [text, image] message, which the app must not send |
| Verdict | yes/no logits at the last position (D38) | Unchanged from text |

Parameter count: 24 × 16.78 M (blocks) + 16.78 M (projector) + 0.60 M (patch) is
about 0.42 B. With the text decoder's 3.43 B that gives 3.85 B, which matches the HF
count of 3,849,090,048 [VERIFIED: survey S4; DER].

Published image quality, self-reported and at bf16 [VERIFIED: model card]: VLGuard
F1 97.7, UnsafeBench 81.8, LlavaGuard 72.0. Integer fidelity at our canvas is
unmeasured (§7.1, step 1).

---

## 2. The image path, relation by relation

### 2.0 Counting conventions (the native lane's, R10/R11)

- A **plane** is one committed column over a domain; an int8 word is one plane.
- int16 = value + two limbs = 3 planes and 2 byte lookups.
- An L-limb requant remainder = L planes and L byte lookups, plus one top pin.
- Every two byte lookups on a domain share one LogUp **helper**, committed in H as
  two rows per position.
- Every domain is a power of two, lifted to the row width (2^14–2^17 here).
- **Committed elements** = (A rows + H rows) × row width.
- Memory on the CPU path ≈ 0.5 GiB + 53 B per committed element of the largest
  block (the speed plan's law, validated within 3% on TinyLlama and 8B).

### 2.1 A Pixtral layer is an existing block at a new geometry [COUNTED]

Each Pixtral layer is RMSNorm → attention → residual → RMSNorm → SwiGLU →
residual: exactly the trained block the native lane proves. What differs:

- d = 1024, FFN 4096, heads 16 × 64;
- KV heads = 16 (MHA, so the Kv domain is as large as Q);
- non-causal attention;
- 2D RoPE.

One block, per canvas [COUNTED layout; time and memory MODEL]:

| canvas → encoder tokens | DD? | committed elements | share in the score domain | receipt | memory (CPU path) | laptop proof + witness |
|---|---|---|---|---|---|---|
| 224² → 256 | yes | **75.4 M** | 18% | 24.7 MB | **4.2 GiB** | 7.2 + 0.6 s |
| 224² → 256 | no | 91.0 M | 36% | 25.9 MB | 5.0 GiB | 8.1 + 0.6 s |
| 336² → 576, padded to 1024 | no (DD needs an unpadded domain) | 741.9 M | 70% | 74.3 MB | 37.1 GiB | 55.9 + 2.1 s |
| 448² → 1024 | yes | 452.8 M | 48% | 57.9 MB | 22.9 GiB | 38.8 + 5.4 s |
| 448² → 1024 | no | 741.9 M | 70% | 74.3 MB | 37.1 GiB | 55.9 + 5.4 s |
| 896² → 4096 | yes | 4,428 M | 79% | 184 MB | 219 GiB | 369 + 70 s |
| reference: Llama-3-8B, T128 | no | 117.9 M | 12% | 29.3 MB | 6.3 GiB | 10.6 + 2.5 s |

How to read it:

- **The score domain is h·T² = 16 × T².** Image size therefore enters the cost
  squared: 4× the pixels gives 16× the attention.
- **DD pays off far more here than at 8B T128** (−17% at 224 px, −39% at 448 px).
  Each dictionary row has at most 32 slots against T keys.
- **DD and the merge both want an unpadded power-of-two patch grid.** That rules out
  336 px (576 patches) and favours 224 px and 448 px.
- **Non-causal attention wastes nothing.** The causal decoder pays for the full
  T × T square and masks half of it. An image uses every entry, so per useful score
  the encoder is twice as efficient.

### 2.2 Non-causal and block-diagonal attention (a mask variant)

**What exists.** Today the causal mask is a public table over the score domain,
equal to 1 on j ≤ t (`argument.rs causal_mask_at`). It enters the row-sum slot
`SC_RS` and the softmax zero-check `SC_SZC`. The softmax relation's support argument
("off the causal support it forces p = ρ_s = 0 because Sum ≥ 2^fE",
`layout.rs` ~l.752) is written for the causal support.

**What changes for one image on a fixed canvas.**

- The mask is **all ones**. The public table becomes the constant 1, and its MLE is
  1 at every point.
- The support argument simplifies, because every entry is on the support. It must
  be restated for the full support: the row-max attainment selector `ZSEL` and
  Sum ≥ 2^fE are unchanged.
- **Committed elements: 0. Lookups: 0** [COUNTED].
- **The verifier gets cheaper.** The speed plan's verify law charges 0.74 µs per
  score entry for the dense public tables: the causal mask and the other
  score-domain tables. Dropping the all-ones mask is the trivial case of lever L9
  ("public-table descriptors"). If the remaining score-domain tables also get
  descriptors, encoder verification at 448 px falls from about 12.4 s to about
  0.06 s per block [MODEL]. The mask alone saves part of that.

**Why not native aspect ratios with padding masks.** A non-square image would need
a key-padding mask, and its shape would be in the public statement. That **leaks
the image's aspect ratio**. It also pads the score domain (DD refuses padded domains
as built) and breaks the merge-as-bit-permutation (§2.5). Letterboxing in *pixel
space* onto a fixed square canvas avoids all three: the statement is byte-identical
for every image. The fidelity cost of letterboxing must be measured (§7.1, step 1).

**Block-diagonal attention** is needed only to put **several images or frames into
one block proof** (§4.3). It should be built as a **batch axis**, not as a masked
square:

- The score domain becomes (frame, head, i, j), of size B·h·T², rather than
  h·(B·T)² with a block mask. At B = 4 frames the masked square would be 4× larger.
- The frame bits are coordinates of both private factors of the score and PV slots.
  So, under the S19-F1 discipline already applied to the KV-group bits, they become
  sumcheck variables with a public eq. That is log2(B) more rounds and no
  committed planes [MODEL].

**Softmax precision (a fidelity cliff, not a cost).** F_P = 9 is fixed in
`shape.rs`. With T keys and diffuse attention, p ≈ 2^9/T:

| encoder tokens | p at F_P 9 | at F_P 12 | at F_P 15 |
|---|---|---|---|
| 256 | about 2 levels | 16 | 128 |
| 1024 | about 0.5: **rounds to zero** | 4 | 32 |

- The encoder needs F_P 12–15. R11 counted F_P up to 15 as free: p keeps two limbs,
  sh_o = F_P stays in its 9..=16 window, and DD's P_dict limbs are unchanged.
- Making F_P a per-profile constant is a D24 item.
- The DD cap (at most 32 distinct exp outputs per row) depends only on the exp table,
  not on T. It must be re-checked on Pixtral's calibrated exp table.

### 2.3 2D RoPE tables [COUNTED: zero committed change]

- **What exists.** `SC_QZC` / `SC_KVZC` read two public tables C and S′ with
  `out = C·x + S′·x_partner`. The partner is the index with the top head-dim bit
  flipped (HF `rotate_half` pairs i and i + hd/2). The tables are laid out per
  (token, head, dim) on the padded stride.
- **What changes.** Only the values. For pair k < 16, the angle is row(t) · θ^(−4k/64);
  for k ≥ 16, it is col(t) · θ^(−(4(k−16)+2)/64). Here row(t) = t div 16 and
  col(t) = t mod 16 on the 224² canvas (32 on 448²).
  - This matches HF's `inv_freq_2d = cat(inv_freq[0::2], inv_freq[1::2])` followed
    by the H-W recomposition [VERIFIED: modeling_pixtral.py].
  - The pairing, the table sizes, the quantisation (SH_ROPE 7) and the slot are
    unchanged.
- **Cost.** 0 planes, 0 lookups. The verifier's table evaluation is the same size
  as today's.
- **Pins.** The trained-profile registry must pin, as it pins rope_theta today:
  - θ = 1e4 (`trained_rope_theta`);
  - the grid side;
  - the axial layout.

  A wrong table is a different model, so the statement must bind it.
- **Pitfall.** Mistral's native `consolidated.safetensors` uses interleaved pairs;
  HF permutes q/k into `rotate_half`. Use one layout end to end. The prep lane
  checked the same equivalence for the text RoPE.

### 2.4 Patch embedding and `ln_pre` (a new front-end stage) [MODEL]

- **The matmul.** Each patch is 588 values, committed in **patch-major layout**:
  - one pixel plane on a domain of T × 1024, with 588 padded to 1024;
  - the unfold from image layout is not a bit permutation (14 is not a power of
    two), so the canonical tensor is *defined* in patch order (§3.2) and the unfold
    costs nothing.

  The weights are public: 1024 × 588, about 0.6 M words, a trivial verifier fold.
- **The normalisation folds into the weights exactly.**
  W·((x/255 − μ_c)/σ_c) = Σ_c (W_c / (255 σ_c))·x − Σ_c W_c μ_c / σ_c. So the
  committed input is the **raw uint8 pixel** (its range is one byte lookup, the U8
  table that exists).
  - The weights become W′ = W / (255 σ_c), re-quantised to int8.
  - A **public per-channel bias** b′ appears. This is the only genuinely new clause:
    a public column in the requant host, `2^sh·y + r − 2^(sh−1) = acc + b′`.
  - The verifier evaluates b′'s MLE in O(d). No Llama relation has a bias today.
- **The accumulator** is at most 588 × 255 × 128 ≈ 2^24.2, far from p ≈ 2^64.
- **`ln_pre`** is an RMSNorm whose output is the residual stream (int16). That is
  R11's N16 ("tn route", three norm limbs, a 24-bit window, a D24 item), not today's
  int8-output norm.
- **Planes, using the conventions of §2.0:**
  - pixel plane: 1 plane, 1 lookup;
  - conv output: int16, 3 planes;
  - remainder: two bytes;
  - ln_pre: N16, 6 limb planes + 3 output planes;
  - binding plane: 1. Only option L2 of §3.1 needs it; it stays in the count as a
    conservative margin.

  That is about 16 planes and 16 lookups on the T × 1024 domain.
- **Totals:** 8.9 M committed elements at 224 px (12% of a DD encoder block);
  35.7 M at 448 px (8%).

### 2.5 The 2×2 merge: a free re-indexing plus one ordinary matmul

- **The unfold** maps encoder token (h, w), feature d to merged token (h div 2,
  w div 2), feature 4d + 2(h mod 2) + (w mod 2) [VERIFIED: `F.unfold` order (d, kh, kw)].
  - With H, W and d powers of two, that is a **permutation of the index bits**:
    (h_hi | h_lo | w_hi | w_lo | d) → (h_hi | w_hi | d | h_lo | w_lo).
  - The MLE of the merged tensor at a point is the MLE of the source plane at the
    permuted point.
  - So the merge-layer matmul's input claim becomes a claim on the existing
    projector-norm output plane at a permuted point. **0 committed elements, 0
    lookups** [COUNTED].
- **Review item.** The opening groups key claims by the last `log_cols` coordinates
  of the point (the "column key", `shape.rs` ~l.787). A permuted point can create a
  new key: one more A group, about 0.27 MB of receipt at 2^14. It must be checked
  against the single-key rule of the LogUp sum claim (`logup_sum_claim_keys`).
- **On a grid that is not a power of two** (336 px: 24 × 24) the unfold is not a bit
  permutation. It would need a committed copy plus a permutation argument: avoid it.
  On a padded power-of-two grid (420 px: 30 × 30 inside 32 × 32) it is still a bit
  permutation, because 30 is even.
- **The merge layer `Linear(4096 → 1024)`** is a normal matmul site with its own
  requant (§2.6).

### 2.6 Projector and GELU [MODEL]

| piece | domain | new planes | byte lookups per position | committed elements (224 / 448 px) |
|---|---|---|---|---|
| RMSNorm, int8 out | T × 1024 | 9 (8 remainder limbs + y) | 10 | 5.0 / 19.9 M |
| merge layer: int8 out + two-byte remainder | T/4 × 1024 | 3 | 5 | 0.6 / 2.4 M |
| linear_1: int8 out + two-byte remainder; **GELU** a16 via the activation lookup; linear_2: int16 out + three-byte remainder | T/4 × 4096 | 10 | 11, plus one activation pair | 6.3 / 25.2 M |

At 224 px the smaller domains are lifted to the 2^14 row width, which is why the
224-px figures are not exactly a quarter of the 448-px ones.

- **GELU is a lookup table exactly like SiLU.** Today's activation lookup is a
  two-column table (g8 + 128, a16) keyed per block (`silu_member`). GELU swaps the
  table's values and pins it the same way.
  - There is no gate: GELU's output feeds linear_2 directly, as h16 feeds down.
  - An int12 input (a 4096-row table) is free in the counts (R11 SI12).
  - GELU is not monotone, which the lookup does not care about.
- **linear_2** accumulates 3072 × int16 × int8 ≈ 2^34. Its requant into the
  decoder's int16 residual class likely needs a **three-byte remainder**, R10's
  three-limb window. That is a D24 re-read.

### 2.7 Image tokens into the decoder

The decoder's input sequence for an image post with no caption:

- the public prefix: system prompt + Instruct + Query + `"<Document>: "`, 87–91
  tokens;
- the image tokens: rows × (cols + 1);
- about 4 trailing public tokens (`" \n\n"` + `[/INST]`) [MODEL];
- then the verdict, read at the last position (D38: z_yes − z_no against public c,
  two rows of the tied head).

**The splice** [MODEL].

- The decoder's input plane X0 holds public rows (the template, `[IMG_BREAK]`,
  `[IMG_END]`) and private rows (projector outputs).
- Image positions are public on a fixed canvas, but they sit at stride cols + 1
  (17 at 224 px), which is not a bit permutation. One **public selection slot**
  binds them:
  - X̃0(r_t, r_d) − pub(r_t, r_d) = Σ_m M̃(r_t, m) · P̃(m, r_d);
  - M is the public 0/1 placement matrix. The verifier evaluates its MLE in
    O(#image tokens). pub is the public embedding rows.
- This is a matmul-shaped slot with 6–8 inner rounds, **0 committed planes**.
- The run's external input becomes the pixel endpoint (§3), not a token endpoint.
  For an image-only post, every text position is public.

**Decoder length per canvas** [COUNTED arithmetic]:

| canvas | encoder tokens (padded) | image tokens | decoder positions, no F6 (padded) | proved with F6: queries / keys (padded) |
|---|---|---|---|---|
| **224²** | 256 (256) | 72 | 167 (**256**) | 76 / 167 (**128 / 256**) |
| 280² | 400 (512) | 110 | 205 (256) | 114 / 205 (128 / 256) |
| 336² | 576 (1024) | 156 | 251 (256) | 160 / 251 (256 / 256) |
| 448² | 1024 (1024) | 272 | 367 (**512**) | 276 / 367 (**512 / 512**) |
| 896² | 4096 (4096) | 1056 | 1151 (2048) | 1060 / 1151 (2048 / 2048) |

**F6, public-prefix KV** (survey feature F6, shared with the text MVP).

- Under P1 the weights and the prefix are public. The prefix's K/V can therefore be
  computed in public, once per policy, and only the image and trailing tokens are
  proved.
- The score domain becomes h × Tq × Tk, with a public half in the score and PV
  slots. The verifier recomputes the public K/V once per policy, or pins them by a
  digest.
- No private state crosses proofs, so the D8/D11 question does not arise.
- **F6 decides whether 224 px fits the laptop.** It moves the decoder from 256 to
  128 padded positions: 14.0 → 7.2 GiB. It does not help at 448 px, where 276 proved
  positions still pad to 512.

**A finding for the token lane: Shieldstral's decoder block is as large as
Llama-3-8B's** [COUNTED].

- d 3072 pads to 4096, and the FFN's 9216 pads to 16384 (8B: 14336 → 16384). Q is
  32 × 128 = 4096 and Kv is 8 × 128, both as in 8B.
- So at equal T the committed layout, the receipt and most phases equal the 8B
  block's: 117.9 M elements at T128, 272.7 M at T256, 663.3 M at T512. Only the
  witness is smaller: 1.5 against 2.5 s per block at T128 [MODEL].
- The survey's "0.43× of 8B" counts MACs. The prover pays for padded planes.
- **Lever: split-width domains.** Commit D as 2048 + 1024 and F as 8192 + 1024, each
  a power of two, instead of padding.
  - Upper bound on the saving, before the extra claim sites: −25.6% committed at
    T128, −22.1% at T256, −18.2% at T512 [MODEL].
  - That would bring a T256 text block to about 11 GiB.
  - It is a layout change: new profile, D24/pad-rule re-read.

### 2.8 The relations side by side

Committed elements and lookups are per image at 224 px (448 px in brackets).

| relation | what changes against today | committed elements | byte lookups | label |
|---|---|---|---|---|
| Pixtral block geometry (d 1024, MHA 16 × 64, FFN 4096) | a new trained profile; Kv as large as Q | 75.4 M (452.8 M) per block with DD | 25 per position on D, 13 on Q, 12 on Kv, 4 on S (DD), 9 on F | COUNTED |
| Non-causal mask | public mask = all ones; support clause restated | 0 | 0 | COUNTED |
| Block-diagonal (multi-frame) | a batch axis on the score domain; frame bits as sumcheck variables | 0 per frame; memory × B | 0 | MODEL |
| 2D RoPE | public cos/sin values keyed by (row, col) | 0 | 0 | COUNTED |
| F_P 12–15 | constant per profile (fidelity) | 0 up to F_P 15 | 0 | COUNTED (R11) |
| Patch embedding + ln_pre (+ binding plane) | new stage: uint8 plane, folded weights, **bias column**, N16 norm | 8.9 M (35.7 M) | about 16 per position | MODEL |
| 2×2 merge (unfold) | claims at bit-permuted points | 0 (maybe +1 opening group) | 0 | COUNTED |
| Merge layer, linear_1, linear_2 | ordinary matmul sites + requant windows | inside the next row | | MODEL |
| Projector norm + GELU + three matmuls | new stage; GELU table like SiLU | 11.9 M (47.4 M) | about 26 per position | MODEL |
| Splice into the decoder | public selection slot | 0 | 0 | MODEL |
| Decoder at image lengths | existing (after F1–F4); F6 rectangular scores | 136.3 M per block (F6, T128 / keys 256) | as 8B | COUNTED (no F6) / MODEL (F6) |

---

## 3. Binding the proof to the posted image

### 3.1 Options

**(a1) Prove the decoding in-circuit (JPEG/PNG to pixels). Not for this prover.**

- JPEG entropy decoding is branchy and byte-serial. It belongs to a zkVM, and the
  zkVM line's measured rate (6.55 M cycles in about 1 h of CPU STARK) puts a
  megapixel decode far out of reach.
- JPEG's IDCT is not bit-exact across decoders anyway.

**(a2) Prove the resize in-circuit, from a canonical larger image. Affordable later.**

- The resize is a linear map with public, sparse fixed-point coefficients: two
  separable passes, each a "public-matrix matmul" slot.
- Committing a 1024 × 1024 × 3 canonical source (one byte lookup each), one
  intermediate plane and the remainders is about 20 M elements, about 0.27 of a
  224-px encoder block [MODEL].
- It lets the binding cover a displayed-resolution image instead of the 224-px
  canvas. Worth doing after (b).

**(b) Commit to the canonical pixel tensor; the app derives it from the post with a
public, deterministic spec. Recommended.** The question is how to link the tensor
to something a content holder can recheck. Four ways:

- **(b-L3) Use the run's input endpoint. Recommended for the MVP.**
  - The canonical pixel tensor is the run's external input. It is committed by a
    prover-sealed **hiding** endpoint commitment (D18; RS-coded rows with mask rows
    and salted leaves, covered by D22/D33's endpoint argument). Its root is in the
    verified statement.
  - The prover hands the endpoint's opening randomness (mask rows and the leaf-salt
    seed; tens of KB [MODEL]) to the app, which stores it **with the post** as a
    "binding blob".
  - A content holder recomputes the canonical tensor from the post, recomputes the
    root from tensor + blob, and checks it equals the statement's root.
  - This is D25 T2's "owner can check the input endpoint", extended to everyone who
    can see the post. **No new relation, no new public output.** It needs a D23
    reading (§8).
- **(b-L2) A salted fingerprint.** The fallback if the D23 reading goes the other
  way.
  - Publish C_s = H(salt) in the statement, absorbed before any challenge.
  - Commit the salt block s = PRF(salt) beside the pixels. After the A root, draw r
    by Fiat–Shamir and publish v = (X‖s)~(r), proved as one extra opening claim.
  - The holder recomputes X from the post, s from the salt, and checks v.
  - Soundness by Schwartz–Zippel: s is fixed by C_s, X′ by the root, both before r,
    so a wrong X′ survives with probability about log N / |F|, about 2^-123.
  - Privacy: v is masked by s, so it is uniform to anyone without the salt.
  - Cost: one plane plus one claim. Needs its own privacy reading, because it is a
    new disclosed value.
- **(b-L1) Hash the tensor inside the proof** (Poseidon2 or BLAKE3 as a relation).
  Sound, but a new expensive relation for no gain over L3. Not recommended.
- **(c) The platform signs (post id → root).** Not sound against the platform, which
  is exactly who a public proof should not have to trust. Useful only as an app-level
  index, never as the binding.

### 3.2 The canonical pipeline (the MVP spec, to be written as a pinned reference implementation with test vectors)

1. **A lossless master.** At upload the app transcodes the image once to a lossless
   master (PNG, RGB8, EXIF orientation applied). The displayed post is the master or
   is derived from it. PNG decoding is exact, so no decoder needs pinning.
   - If the app must keep JPEG originals, the spec pins one decoder build and IDCT
     mode (for example libjpeg-turbo, a fixed version, `JDCT_ISLOW`, no fancy
     upsampling).
2. **Resize.** An integer resize with fixed-point coefficients and specified
   rounding: an antialiased bicubic close to the model's training-time resize, or an
   area average. The longest edge goes to the canvas size.
3. **Letterbox.** Centre the image on the fixed canvas (224 × 224, or 448 × 448).
   Fill with the per-channel mean colour, so that the normalised padding is
   about 0.
4. **Layout.** Patch-major uint8 tensor (patch row, patch column, channel, 14 × 14),
   zero-padded per patch to the plane layout.
5. **Prompt.** The policy prefix and the trailing tokens are public and fixed per
   policy; the verdict rule is D38's.

Model-side normalisation and the patch conv are inside the proof (§2.4), so nothing
float remains outside it.

### 3.3 What a verifier can and cannot conclude

**With the post and its binding blob,** a verifier who checks the receipt and
recomputes the root can conclude:

- the canonical tensor of *this* post (spec version v), run through the **pinned
  calibrated integer model** (Shieldstral image path, export digest pinned in the
  statement) with the **public policy text** P, gives z_yes − z_no below the public
  threshold c, that is "safe";
- the soundness error is about the custom line's per-run figure. D27 accepts about
  95 bits whole-run at its named workload. An image run has 50 blocks plus stages,
  so the union bound must be recounted at this workload.

**Without the post** (a chain observer, a search engine): only that *some* image,
under a hiding commitment, passed model M with policy P at some time. Nothing about
the image, and no way to test a candidate image (§3.4).

**What no verifier can conclude:**

1. **That the float model would agree.** Only the integer model is proved. Its
   fidelity on image benchmarks is unmeasured (§7.1, step 1, and D32).
2. **Anything the canvas drops.** At 224 px small text in an image, fine detail and
   watermarks may be illegible. Letterbox margins carry no content.
3. **That the classifier is right.** False negatives exist (self-reported UnsafeBench
   F1 81.8). An uploader can also **search for an adversarial variant** that the
   classifier passes and then prove it honestly. The proof attests the computation,
   not the truth.
4. **That the displayed post is the bound one,** unless the viewer's client actually
   recomputes the canonical tensor. A UI badge alone proves nothing.
5. **Other channels:** EXIF and metadata, captions (unless proved as text), and, for
   video, audio and unsampled frames.

### 3.4 Privacy of the binding

- **An unsalted hash of a low-entropy image is brute-forceable.** Anyone holding a
  candidate can confirm it: a known meme, a solid colour, a frame of a public video,
  a re-post. Even a high-entropy photo is confirmable by whoever has the photo. So
  the public anchor must be salted. In L3 the endpoint's masks and leaf salts *are*
  the salt; in L2 it is a 256-bit salt.
- **The blob must travel only with the content,** under the same access control,
  and be deleted with it. A blob that leaks without the content re-enables
  confirmation attacks.
- **A fixed canvas leaks nothing.** The statement, every domain and the token layout
  are identical for every image. Native aspect ratios would publish the aspect ratio
  through the grid shape (§2.2).
- **The verdict bit is public by D38(c).** Typically only "safe" proofs are
  published, so selection adds no further disclosure.

---

## 4. Video

### 4.1 The sampling policy (public, deterministic, content-independent)

- **Frames.** Take every frame at presentation time t_k = k·Δ, for k = 0 to
  ⌊duration/Δ⌋, with Δ = 5 s (0.2 frames/s) as the POC default and 1 s as the strict
  option. Select by container timestamps in integer arithmetic: the first frame with
  PTS ≥ t_k.
- **Decoding.** H.264, HEVC, VP9 and AV1 decoding are specified bit-exactly. So any
  conforming decoder yields the same frames from the posted file. This is a
  standards property, to be confirmed with two decoders as a test. Then come a
  pinned integer YUV→RGB conversion (matrix, range and chroma upsampling) and the
  image spec of §3.2.
- **Scene cuts.**
  - Cut detection depends on content, so the *number and times* of cut frames
    would reveal something about the video to anyone who sees the manifest.
  - POC: fixed-rate frames only.
  - If cuts are added later: prove a **fixed budget** of extra frames per duration
    bucket (duplicates when fewer cuts exist). Then the frame count depends only on
    the duration bucket.
- **Duration** is public through the frame count. Bucket it if that matters.

### 4.2 One verdict

- The video verdict is **unsafe if any sampled frame is unsafe** (or if the
  supplied caption is, §5). This is a public rule over the per-frame verdicts.
- Only the combined verdict needs publishing. For a published (safe) video every
  per-frame verdict is "safe", so listing them discloses nothing more.
- **Completeness is the soundness hazard.** An uploader could simply omit an
  unsafe frame's proof. The manifest must therefore list exactly the policy's frame
  indices, and a checker with the video recomputes that list and requires a proof
  for each.
  - Without the video, a checker can verify only internal consistency: the count
    equals f(duration bucket), every proof verifies, every verdict is safe.

### 4.3 Proof count, cost per minute, and aggregation [MODEL]

Per frame = one image run (24 encoder blocks, the stages, 26 decoder blocks, F6).
Frames go in one run, so weights load once.

| | frames per 30 s | laptop | 5090, today | 5090, after the port | receipts | per minute (laptop / 5090 today / ported / receipts) |
|---|---|---|---|---|---|---|
| 224 px, 0.2 frames/s | 6 | 0.89 h | 0.37 h | 2.8 min | 8.8 GB | 1.8 h / 44 min / 5.5 min / 18 GB |
| 224 px, 1 frame/s | 30 | 4.4 h | 1.8 h | 14 min | 44 GB | 8.8 h / 3.6 h / 28 min / 88 GB |
| 448 px, 0.2 frames/s | 6 | not on the laptop | 1.6 h | 10 min | 20 GB | — |
| 448 px, 1 frame/s | 30 | not on the laptop | 8.2 h | 51 min | 99 GB | — |

There are three ways to aggregate:

- **A manifest statement.**
  - What it holds: the policy id and version, the duration bucket, the frame
    indices and timestamps, one receipt digest and one binding root per frame, and
    the combined verdict.
  - Its cost: no cryptographic aggregation. Size is the sum of the receipts, and
    verification is the sum of the verifications.
  - Status: this is the POC.
  - Per-frame binding blobs derive from one master seed, `seed_k = PRF(seed, k)`, so
    the post carries one seed.
- **One proof run for all frames.** This saves the weight loads (about 79 s per
  frame on the laptop) and the run header. Per-block work is unchanged.
- **A batch axis: B frames per block proof** (block-diagonal attention, §2.2;
  speed-plan lever L6). Per frame, at 224 px with F6:

| B | encoder time per frame per block | encoder receipt per frame per block | encoder memory | decoder time | decoder receipt | decoder memory |
|---|---|---|---|---|---|---|
| 1 | 7.85 s | 24.7 MB | 4.2 GiB | 12.8 s | 31.6 MB | 7.2 GiB |
| 2 | 7.06 s (−10%) | 16.7 MB (−32%) | 7.6 GiB | 12.4 s | 22.5 MB | 14.0 GiB |
| 4 | 6.93 s (−12%) | 11.9 MB (−52%) | 14.8 GiB | 11.7 s | 15.4 MB | 26.8 GiB |
| 8 | 6.60 s (−16%) | 8.1 MB (−67%) | 28.4 GiB | 11.6 s | 11.0 MB | 53.1 GiB |

  Batching mostly shrinks **receipts**: each block's receipt has a fixed part of
  about 10 MB of opened vectors. It barely shortens proving, and memory grows with B.
  It is a new layout (a profile, plus review of the batch-bit sumcheck variables).
  Worth it on the 5090 box for video, not on the laptop.

**Recursion or a succinct wrapper** would turn about 1.5 GB per frame into a few
hundred bytes. It is out of scope for this prover today: the chain lane estimates
about 2–3 × 10^11 zkVM cycles just to verify one Shieldstral receipt. Without it,
1 frame/s video is not publishable at reasonable cost. D39's "proof off-chain,
digest on-chain" shape is mandatory.

**Soundness across frames.** Union over frames: 30 frames cost about 5 bits against
the per-run bound [MODEL]. Recount with D27's rule at the chosen workload.

### 4.4 What sampling misses (the verdict text must say so)

- Anything **between sampled frames**. At 0.2 frames/s a 4-second unsafe segment can
  fall entirely between samples. At 1 frame/s, a sub-second flash can.
- **Motion and temporal context**: an act that is unsafe only as a sequence.
- **Audio**: speech, music lyrics, sounds (§5).
- **On-screen detail** lost at the canvas resolution.
- **Adversarial placement.** A public, content-independent schedule is predictable,
  so an adversary can place content between sample times. This argues for 1
  frame/s, or a schedule offset derived after upload from a public beacon. A
  per-post random offset revealed later must still be bound before proving. Ruling
  item (§8).

---

## 5. Audio and transcripts

**Option A: a proved speech recogniser (Whisper)** [VERIFIED configs:
`openai/whisper-{tiny,base,small}/config.json`]:

| | layers enc / dec | d | heads × 64 | FFN | encoder frames | vocabulary |
|---|---|---|---|---|---|---|
| tiny | 4 / 4 | 384 | 6 | 1536 | 1500 per 30 s | 51,865 |
| base | 6 / 6 | 512 | 8 | 2048 | 1500 | 51,865 |
| small | 12 / 12 | 768 | 12 | 3072 | 1500 | 51,865 |

**What is new against our relations:**

- a log-mel front end: a windowed DFT, which is a public-matrix matmul; squared
  magnitude; a mel filterbank (public matmul); log (a table). Expressible in our
  relation family, unlike JPEG decoding.
- two conv1d layers with GELU;
- **LayerNorm**: mean subtraction plus variance, a variant of RMSNorm;
- **biases** everywhere;
- a GELU MLP with 2 matmuls;
- learned or sinusoidal absolute positions;
- **cross-attention**: a rectangular score domain whose keys and values are private
  encoder outputs;
- **greedy decoding** of the whole transcript. That is D25 mode (ii): every output
  token is an argmax over 51,865 logits.

**Size** [MODEL, approximated with the Llama-block layout, ±30%].

- Whisper pads every window to 30 s = 1500 frames, which pads to 2048. Heads pad
  6 → 8.
- Whisper-tiny's encoder is therefore about **1.27 G committed elements per layer**
  (63 GiB on the CPU path). Four layers is about 390 s on the laptop law, which the
  laptop cannot hold. Whisper-small is about 2.5 G per layer.
- The transcript decoder (128 tokens against 1500 keys) is small by comparison:
  84 M per layer at tiny.
- Then the transcript must be classified by Shieldstral's text path **in the same
  run**. Chaining a private transcript between two runs would refer to an endpoint
  root from a later artifact: the D23/D8 question.

Whisper-tiny's transcription quality is also weak for moderation-grade use.

**Option B: captions or subtitles as a text post** (an uploader-supplied subtitle
track, or the app's captions, with the uploader attesting them).

- Zero new relations: the text path with a token endpoint, bound to the caption
  text exactly as images are bound (§3, L3 on the token endpoint).
- The verdict covers **the captions, not the audio**.

**Option C: the platform transcribes with an unproved ASR, then the transcript is
proved as text.** This adds a trusted step. It is labelled as such, and it is not
part of the public guarantee.

**Recommendation for the POC.**

- No audio proof.
- If captions exist, prove them as text and fold the result into the video's OR.
- Publish the coverage label "visual frames at Δ + supplied captions; audio not
  assessed".
- A proved Whisper is a later milestone. It needs the non-causal, LayerNorm, bias,
  GELU and cross-attention relations and a large-memory machine (Mac, or 5090 box
  with ≥ 64 GiB host).

---

## 6. Cost table

Every time is [MODEL]: the speed plan's cost law, calibrated on R4-era code, applied
to [COUNTED] layouts. Columns:

- **Laptop**: Core Ultra 9 185H, 16 threads, one cold pass including weight loads.
  "No fit" means the CPU-path peak exceeds the 15 GB box (speed-plan rule: 12 GiB).
- **5090, today**: today's code with only the commitments on the GPU (board factor
  5); every other phase on the 5090 PC's host CPU, assumed 2× the laptop. The host
  CPU and its RAM are unknown.
- **5090, ported**: the speed plan's step 4. The whole prover and the witness on the
  GPU, central band (25× the laptop for ported CPU phases), resident model. That is
  about 35–55 lane-days of GPU work away.
- **Peak memory**: CPU path. In brackets, the host on the GPU-commit path and the
  VRAM, commit only.
- **Receipt**: the sum of per-block counted receipts. The two image stages are
  charged one encoder-block receipt each [MODEL, conservative].

| content | proved positions (padded) | laptop | 5090, today | 5090, ported | peak memory | receipt | verify (with L9 descriptors) |
|---|---|---|---|---|---|---|---|
| Text, 64 tokens, no F6 | 156 (256) | 713 s, **no fit** (GPU-commit arm marginal, 10.7 GiB) | 297 s | 29 s | 14.0 GiB (10.7 / 2.2) | 1.17 GB | 50 s |
| **Text, 64 tokens, F6** | 65 / keys 156 (128 / 256) | **398 s** | 177 s | 17 s | **7.2 GiB** | 0.82 GB | 30 s |
| Text, 256 tokens (F6 does not help: 257 → 512) | 348 (512) | 1,555 s, **no fit** | 612 s | 60 s | 33.2 GiB (25.2 / 5.1) | 1.81 GB | 171 s |
| **Image 224², DD encoder + F6 decoder** | enc 256; dec 76 / 167 (128 / 256) | **602 s** | 265 s | 28 s | **7.2 GiB** (encoder 4.2) | 1.46 GB | 50 s (11 s) |
| Image 224², DD, no F6 | enc 256; dec 167 (256) | 917 s, **no fit** | 386 s | 40 s | 14.0 GiB | 1.81 GB | 70 s |
| Image 448², DD + F6 | enc 1024; dec 276 (512) | 2,608 s, **no fit** | 1,029 s | 102 s | 33.2 GiB (25.2 / 5.1); encoder 22.9 | 3.31 GB | 469 s (11 s) |
| Image 448², non-DD, no F6 | enc 1024; dec 367 (512) | 3,054 s, no fit | 1,178 s | 119 s | 37.1 GiB | 3.74 GB | 469 s |
| Image 896², DD + F6 | enc 4096; dec 1060 (2048) | 22,359 s, no fit | 8,501 s, **no fit** (VRAM 43 GiB) | 826 s (hypothetical) | 285 GiB (decoder), 219 GiB (encoder) | 9.94 GB | 7,331 s (11 s) |
| **Video 30 s, 0.2 frames/s, 224²** | 6 frames | **53 min** | 22 min | 2.8 min | 7.2 GiB | 8.8 GB | ~5 min |
| Video 30 s, 1 frame/s, 224² | 30 frames | 4.4 h | 1.8 h | 14 min | 7.2 GiB | 44 GB | ~25 min |
| Video 30 s, 0.2 frames/s, 448² | 6 frames | no fit | 1.6 h | 10 min | 33.2 GiB | 20 GB | ~47 min |
| Video 30 s, 1 frame/s, 448² | 30 frames | no fit | 8.2 h | 51 min | 33.2 GiB | 99 GB | ~4 h |

**Image split at 224 px with F6** (laptop law):

- encoder 188 s (24 × 7.8 s);
- decoder 332 s (26 × 12.8 s);
- stages about 2 s;
- loads 79 s.

**How far to trust the law.** Against the measured anchors, the cold-pass law
gives:

| anchor | law | measured | error |
|---|---|---|---|
| Llama-3-8B T32 (brief) | 285 s | 296 s | −4% |
| Llama-3-8B T128 (brief) | 580 s | 569 s | +2% |
| Llama-3-8B T128, R8 quiet run (prove + load) | 580 s | 506 s | +15% |
| TinyLlama T32 (brief) | 64 s | 85 s | −24% |

- The R8 gap means today's code is a little faster than the law, so the table is
  mildly pessimistic. The brief's TinyLlama 85 s includes run overheads the law does
  not count.
- The receipt law gives 938 MB for 8B T128 against the brief's 928 MB.
- Its memory law gives 6.3 GiB against the measured 6.7–8 GiB (with witness cache).

**Two extrapolation risks.** Both are untested: the law was fitted at score domains
up to 2^19, and the 448-px encoder's score domain is 2^24. The witness law is a
TinyLlama fit scaled by weights and h·hd.

---

## 7. Build plan

### 7.1 Steps, cheapest first

Each step gives the owning lane and what it demonstrates.

0. **Settle the canvas and the coverage label with Victor (§8).** No code. 224 px
   is the laptop-feasible POC; 448 px needs the 5090 box or the Mac.
1. **Float and integer reference of the image path** (fidelity / prep lane; CPU,
   guarded).
   - Extend the prep lane's numpy layer-streamed reference (`tools/shieldstral_ref.py`)
     with Pixtral, the projector and the splice.
   - Cross-check it against HF transformers at fp32.
   - Run the **canonical pipeline** (§3.2) against HF's own preprocessing on VLGuard
     and UnsafeBench subsets, at 224 and 448 px, letterboxed vs native aspect.
   - Calibrate the int8 export: per-layer constants (R8), F_P 12–15, the GELU table,
     the DD cap on Pixtral's exp table. Check the residual class (int16 vs int24:
     ViTs are known to carry high-norm outlier tokens; unmeasured for Pixtral).
   - *Demonstrates:* the integer image classifier matches the float model on images
     (D32), and how much 224 px costs in F1. **This gates everything below:** if
     224 px loses too much, the plan moves to 448 px on the 5090 box.
2. **A non-causal block at a Pixtral-geometry development rung** (native lane).
   - The rung: d 1024, 16 × 64, 16 KV heads, T 256.
   - Build the all-ones mask function, the restated support clause, and the mask
     dropped from the verifier's dense tables.
   - *Demonstrates:* one generic dense non-causal block proves and verifies,
     bit-exact against an independent reference kernel, with generic witnesses (heads
     that differ, dense weights).
3. **2D RoPE tables + the registry pins** (native).
   - *Demonstrates:* the same block with Pixtral's RoPE, bit-exact.
4. **Trained Pixtral profile, 24-block encoder-only stack** (native).
   - Per-layer calibration (R8 mechanism), F_P per profile (D24 item), DD at T256.
   - *Demonstrates:* the whole vision tower as one bound run. Parity at every layer
     against the step-1 integer reference. Measured time and memory against this
     note's MODEL (encoder 188 s, 4.2 GiB at 224 px).
5. **Front-end stage** (native).
   - Uint8 pixel plane in the canonical layout, folded patch weights with the
     **bias column**, `ln_pre` as N16, the pixel plane as the run's input endpoint,
     and the owner-check tool: recompute the root from the canonical tensor plus the
     blob.
   - *Demonstrates:* pixels → encoder input, proved and bound; tampering with one
     pixel fails the owner check.
6. **Projector stage** (native).
   - Norm, the merge as a point permutation in the claim plumbing, the merge layer,
     linear_1, the **GELU table**, linear_2 with a three-byte window.
   - *Demonstrates:* encoder output → image embeddings, bit-exact.
7. **Splice + decoder at image lengths** (token lane, after the text MVP's F1–F4).
   - The public selection slot; public template rows in the decoder input; the D38
     verdict.
   - *Demonstrates:* the **first end-to-end image proof** (224 px, no F6 at first),
     on the 5090 box or Mac, since the decoder at T256 does not fit the laptop.
8. **F6 public-prefix KV** (token lane; shared with the text MVP and its largest
   lever).
   - *Demonstrates:* a 224-px image proof **on the laptop** (about 10 min, 7.2 GiB
     [MODEL]) and a 64-token text proof in 7.2 GiB.
9. **Privacy gate on the image profile** (security-owner lane).
   - Rank lemma, NL-1 and joint view on captures of the new profile, including the
     public decoder rows and the endpoint owner-check reading.
   - *Demonstrates:* a D33-style statement for the image profile.
10. **Video tooling** (app lane + native).
    - Canonical frame extraction with a two-decoder bit-exactness test, the manifest
      format and checker, and N frames in one run.
    - *Demonstrates:* a 30-second clip at 0.2 frames/s, about 1 h on the laptop.
11. **Batch axis profile** (native, 5090 box).
    - Block-diagonal attention as frame bits, plus the batched decoder.
    - *Demonstrates:* receipts per frame down 30–50% at B = 2–4.
12. **(a2) the resize in-circuit** from a canonical displayed-resolution source.
    - *Demonstrates:* the binding covers the displayed image, not only the canvas.
13. **Later.** 448 px on the 5090 box (after the speed-plan GPU steps), a
    split-width decoder layout, then Whisper. 896 px is not planned.

### 7.2 What runs on which machine

| | laptop (15 GB) | 5090 box (32 GB VRAM; host RAM unknown, ≥ 32 GiB advised) | Mac (256 GB) |
|---|---|---|---|
| Text 64 + F6, image 224 + F6 | yes | yes | yes |
| Text 64 without F6, image 224 without F6 | no (14 GiB) | yes | yes |
| Text 256, image 448 | no | yes (host ≈ 25 GiB on the GPU-commit path) | yes |
| Image 896 | no | no | no (285 GiB) |

### 7.3 Soundness and privacy review items per relation

None of these has been done.

| relation | soundness items | privacy items |
|---|---|---|
| Pixtral profile (MHA, d 1024) | D24 windows at the new widths; no-wrap at width 1024 / FFN 4096 (inside today's class maxima); D27 whole-run lookup bound recounted for 50 blocks plus stages | New profile, so D33 does not cover it: rank lemma, NL-1 and joint view on its captures |
| Non-causal mask | Restate the softmax support clause (max attainment, Sum ≥ 2^fE) for full support; the verifier's constant-mask shortcut is a verifier change; the pad rule if any pad remains | Same captures |
| Block-diagonal batch axis | Frame bits as sumcheck variables with a public eq (S19-F1 discipline); per-frame independence of endpoints | Fresh masks per frame; no reuse across frames |
| 2D RoPE | Tables pinned in the statement (θ, grid side, axial layout, pair rule); a wrong table is a wrong model | Public tables only |
| F_P 12–15 | F_P per profile (D24); D30 condition (5) re-read with P < 2^(F_P+1); DD cap on the new exp table | — |
| Patch embedding | The **bias host clause** (a new public column); uint8 range by byte lookup; the folded-weight export bound in the statement digest; accumulator no-wrap | The pixel plane is the hidden input: endpoint rules D18 / D21 / D23 / D26 analogue |
| ln_pre (int16 output) | R11 N16: the tn route, three norm limbs, the 24-bit window (D24, D16); restate D12/D12a for an int16-output norm | — |
| 2×2 merge (unfold) | Claims at bit-permuted points: column-key discipline and the single-key LogUp sum claim; the permutation is exactly the canonical layout's | — |
| Merge layer, linear_1, linear_2 | Requant windows (three-byte at linear_2: R10's three-limb argument); D31 identical-pair reading at window tops | — |
| GELU | Table pinned and keyed per profile (like `silu_member`); membership unchanged | — |
| Splice slot | The verifier's sparse MLE of the placement matrix; every image row bound and every public row equal to its embedding | Public rows in a private plane: the rank lemma must treat them as public, not as masks |
| F6 | Score and PV slots with a public half; the public K/V digest per policy; rectangular score domain | Unchanged hidden set; new profile captures |
| Binding (L3) | The owner-check recomputation spec; the canonical-pipeline spec version bound in the statement | **D23 reading** (§8); the blob's distribution rules (D21-style); confirmation-attack argument |
| Binding (L2, if chosen) | Challenge ordering (C_s before r; r after the input root); Schwartz–Zippel bound | v is a new disclosed value: uniformity given the view needs the salt block's eq coefficient ≠ 0 and s opened nowhere else |
| Video manifest | Completeness (every policy frame present); union bound over frames | Frame count and timestamps reveal the duration bucket; scene cuts only as a fixed budget |

---

## 8. Rulings and decisions for Victor

1. **Canvas: 224 px for the POC, 448 px as the 5090-box target.** 896 px is not
   feasible with today's code. Decide after step 1 measures what 224 px costs in
   accuracy.
2. **Binding by the input endpoint (L3) needs a reading of D23.**
   - D23 says an accepted receipt's endpoint roots are never "registered,
     republished or referred to by a later artifact". Its concern is a later
     *proof* or registry opening or chaining the root.
   - A content holder recomputing the root from the content plus a shipped blob is
     D25 T2's owner check, extended to viewers. It reveals the full opening only to
     parties who already hold the input.
   - Proposed reading: allowed, provided no other proof ever opens that root and the
     blob is distributed only with the content. Otherwise L2.
3. **Video sampling:** 0.2 frames/s (cheap, misses up to 5-second segments) or
   1 frame/s (5× the cost, 44 GB of receipts per 30 s at 224 px). Also: a fixed
   schedule offset, or one derived from a public beacon after upload.
4. **Coverage label:** "visual frames at Δ + supplied captions; audio not assessed"
   for the POC, with Whisper deferred.
5. **F6 (public-prefix KV)** for the text MVP and images. It decides laptop
   feasibility at 64 tokens and at 224 px.
6. **The canonical-pipeline spec** (lossless master, integer resize, letterbox) is
   a product decision: it fixes what "this post" means in the proof.

---

## 9. Method, checks and reproduction

`mm_cost.py` defines one layout class, `Lay`, that restates:

- the native R10 replica (`results/zk60_1b_native_20261017/r10/`), which restates
  the frozen R9 `shape.rs` / `layout.rs` / `argument.rs` counting;
- the speed plan's receipt and slot replica (`results/zk60_speed_plan_20261017/layout.py`).

It generalises four things: geometry, DD with its receipt, the F6 rectangular score
domain [MODEL], and a batch axis [MODEL]. Before anything is counted, the script
asserts:

- R10's anchor: the replica equals every size the R9 prover printed in HL_PB_TIMING
  for the four T128 runs;
- `Lay` equals the speed plan's replica in A rows, H rows, receipt and U8, at
  TinyLlama T32–T512 and 8B T32 (row widths 2^11–2^15), T128, T512 and T1024. The
  speed plan's replica was itself checked against the Rust counted ladder;
- `Lay` equals the R10 replica with DD off and on: TinyLlama and 8B at T128, and 8B
  at T512 (DD 525,172,736: the review's D30 anchor);
- DD's counted receipt delta is +235,008 B per block, and the R9 counted receipts
  23,049,192 / 29,300,856 B are reproduced;
- the cost law through `Lay` equals the speed plan's `block_phases` and witness law
  at its validation shapes.

The new stages (§2.4–2.6) are plane-list sketches in `stage_counts()`, using the
conventions of §2.0. They are not specifications.

To reproduce: `python3 mm_cost.py` (pure Python, about a second; it reads the R8/R9
`prove.log` files for the anchor). Output goes to `mm_cost.out` and `mm_cost.json`.

**Sources** [VERIFIED today]:

- `https://huggingface.co/mistralai/Shieldstral-1.0-3B/raw/main/{config.json, params.json, processor_config.json, chat_template.jinja, README.md}`
  at sha `003ec7e2b0bab5f0e6307edbaf186fa5822b76f5`;
- `https://raw.githubusercontent.com/huggingface/transformers/main/src/transformers/models/{pixtral/modeling_pixtral.py, mistral3/modeling_mistral3.py, pixtral/image_processing_pixtral.py, pixtral/processing_pixtral.py}`;
- `https://huggingface.co/openai/whisper-{tiny,base,small}/raw/main/config.json`.

One note on the `transformers` main branch: its `PixtralVisionRotaryEmbedding` now
accepts only `rope_type: axial`, while Shieldstral's config says `default`.
Presumably the config class maps one to the other. The rotation itself, axial with
the H/W frequency split, is what §2.3 uses.
