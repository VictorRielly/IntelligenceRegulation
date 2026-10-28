# Safety classifiers for the first application: survey and fit to our prover (2026-10-21)

Compiled by the classifier-survey research lane (a delegated agent) and saved
here verbatim by the coordinating session, because the lane could not write this
file itself. Coordinator spot-check (2026-10-21 ~01:00 UTC): the Hugging Face
page `mistralai/Shieldstral-1.0-3B` exists. It states the Apache 2.0 licence and
"built on Ministral-3-3B-Base-2512 with a native Pixtral vision encoder". It
states that the model "emits a single `yes`/`no` token", scored by a softmax over
the yes/no log-probabilities at the first generated position, with threshold
0.5. Everything else is the lane's research; the per-fact labels below say which
facts were verified.

Research only: no prover code, no git writes, no heavy runs. The only
computation was counting template tokens with each model's own tokenizer
(`token_counts.json`, `count_tokens.py`).

## Summary

- **Mistral's hosted Moderation API has no downloadable weights.** The current model is Mistral Moderation 2 (`mistral-moderation-2603`, March 2026).
- **Mistral's open model is Shieldstral-1.0-3B:** released 4 Aug 2026, Apache 2.0, no gating. It is a Ministral-3-3B decoder with an image encoder.
- **Shieldstral answers one yes/no question.** Its verdict is the **first generated token** ("yes" or "no"). Mistral reports text scores level with guard models up to 7x its size (F1: ToxicChat 84.1, OpenAI Moderation 81.4).
- **Recommendation: Shieldstral, text only, as the first MVP.** Its public template is about 70–90 tokens, almost all before the user content. Its per-token block work is about 0.43x Llama-3-8B's. It has the best licence and quality in the field.
- **It needs four modest prover changes:** head size decoupled from hidden/heads (3072 vs 32×128); a YaRN RoPE frequency table; tied embeddings; and a verdict that checks "yes-logit minus no-logit > a public threshold".
- **Zero-change option:** **Kanana-Safeguard-8B** has exactly Llama-3-8B's shapes and a single-token verdict, but it is Korean-only. **Llama Guard 3 1B** is plain Llama at TinyLlama size, but it needs RoPE scaling and scores poorly in a third-party test (ToxicChat F1 22.3).
- **Media:** every open image classifier needs a vision encoder; none is a pure decoder. Shieldstral's encoder is the closest to our blocks (RMSNorm, SwiGLU, 2D RoPE, non-causal attention). No production open video classifier exists, so video means proving sampled frames.
- **Biggest new speed lever:** under P1 the weights and the policy text are both public. The template prefix's KV cache can be computed in public, leaving only the private content and a few trailing tokens to prove.

Labels:
- **[V: Sn]**: verified from source Sn (`SOURCES.md`).
- **[UNV]**: not verified.
- **[DER]**: derived by us from verified inputs, with the inputs named.
- **[EST]**: rough estimate, not a measurement.

## Problems spotted in the repo (not changed)

- `scripts/m8b_int8_calibration.py:245` reads only `rope_theta` and ignores `rope_scaling`. A rope-scaled model (Llama Guard 3, Shieldstral) would be silently mis-rotated.
- `scripts/zk60_1b_checkpoint.py:118-147` rejects `rope_scaling`, tied embeddings and `head_dim ≠ hidden/heads`. Shieldstral hits all three, so whichever import path the native prover uses must accept them.
- Switching to a two-logit verdict changes the public statement from "greedy next token" to "score above threshold". That needs a ruling from Victor in the decisions register.

## Detailed table

How to read the columns:
- **Fixed tokens** are the public template tokens around a 41-token sample post: the total, then how many come before and after the user content [DER: T1, each model's own tokenizer and chat template].
- **Block work vs 8B** is the model's non-embedding linear-layer parameters per token divided by Meta-Llama-3-8B's 6.98B [DER].

| Model (release) | Params | Fit to our Llama-style prover | Licence | Fixed tokens (before / after) | Verdict | Published F1, selected |
|---|---|---|---|---|---|---|
| **Shieldstral-1.0-3B** (2026-08-04) [V: S5, S7] | 3.85B total; text decoder 3.43B; block work 0.43x [V: S4; DER] | Llama-like dense decoder. Differs in head_dim 128 ≠ 3072/32, YaRN RoPE table, tied 131k vocab, and a Pixtral vision tower that text inputs don't use [V: S2, S15] | Apache 2.0, ungated, commercial use OK [V: S1, S4] | 71 (71/1) with the card's example policy; 91 (91/1) with a 7-category instruction [DER: T1] | **First token** "yes"/"no". Score = two-way softmax of the yes/no logits, threshold 0.5 [V: S1, S8] | Prompt: ToxicChat 84.1, OpenAI Mod 81.4, Aegis v2 86.2, WildGuardTest 88.1. Response: BeaverTails 85.0, XSTest 93.5 (self-reported) [V: S1] |
| **Llama Guard 3 1B** (2024-09) [V: S19] | 1.50B (16 layers, untied head); block work 0.14x, same as TinyLlama [V: S19; DER] | Plain LlamaForCausalLM. Only difference: `rope_scaling` of type llama3, factor 8 [V: S20] | Llama 3.2 Community: commercial use OK below 700M monthly users; "Built with Llama" required [V: S33] | 193 (139/56) | "safe"/"unsafe" on the first line; a "\n\n" token probably comes first [V: S26; the "\n\n" is UNV] | Meta internal English F1 0.899 [V: S18]. Third-party: ToxicChat 22.3, OpenAI Mod 36.8, BeaverTails 51.6 [V: S63] |
| Llama Guard 3 8B (2024-07) | 8.03B; block work 1.00x | Same shapes as Meta-Llama-3-8B, plus llama3 RoPE scaling [V: S25] | Llama 3.1 Community [V: S24] | 200 (147/55) | As 1B. Meta defines the unsafe score as the first-token probability [V: S24] | Meta internal F1 0.939, AUPRC 0.985 [V: S24]. Third-party: ToxicChat 53.8, OpenAI Mod 79.5, BeaverTails 67.9 [V: S44] |
| Llama Guard 4 12B (2025-04-29) [V: S31] | 12.0B (text part 11.1B); block work 1.30x [V: S29; DER] | Dense model pruned from Llama 4 Scout. QK-norm, llama3 RoPE scaling, 202k vocab, early-fusion vision [V: S30, S28] | Llama 4 Community [V: S28] | 204 (147/58) | "safe"/"unsafe", then the category [V: S28] | Meta internal English F1 61% [V: S28]. Third-party: ToxicChat 51.3, OpenAI Mod 73.5 [V: S44] |
| Qwen3Guard-Gen 0.6B / 4B / 8B (2025-10-16) [V: S42, S44] | 0.6B / 4.0B / 8.2B; block work 0.06x / 0.52x / 1.00x [DER] | Llama-like plus QK-norm. 0.6B and 4B also have head_dim ≠ d/h and tied embeddings [V: S43, S45] | Apache 2.0 [V: S42] | 296 (202/96) | Not first. "Safety: Safe/Unsafe/Controversial", decided at the 3rd token after a fixed "Safety:" [DER: T1] | 0.6B strict/loose: ToxicChat 65.1/77.7, OpenAI Mod 66.5/77.6. 4B: 69.5/82.8 and 68.3/80.7 (self-reported) [V: S44] |
| ShieldGemma 2B / 9B / 27B (2024-07) [V: S35] | 2.61B (2B); block work 0.29x [V: S36; DER] | Gemma 2: GeGLU, four (1+w) norms per layer, tanh attention softcapping, head_dim 256 ≠ d/h, 256k tied vocab, alternating sliding window [V: S37, S38] | Gemma Terms: prohibited-use rules must be passed on [V: S41] | 130 (31/100), one policy per call [DER: T1; V: S35] | **First token** "Yes"/"No"; score = softmax of the two logits [V: S35] | Google, optimal-threshold F1 (2B): OpenAI Mod 0.812, ToxicChat 0.704 [V: S35]. Third-party (2B): OpenAI Mod 44.8, ToxicChat 36.4 [V: S63] |
| Granite Guardian 3.1 2B (2024-12-18) [V: S54] | 2.53B; block work 0.35x [DER] | Granite = Llama plus scalar multipliers that can be folded in; tied 49k vocab [V: S54] | Apache 2.0 [V: S54] | 175 (92/84) | **First token** "Yes"/"No"; leading whitespace [UNV] | ToxicChat 0.60, OpenAI Mod 0.68, BeaverTails 0.80, Aegis 0.87 [V: S54] |
| Granite Guardian 4.1 8B (2026-04) [V: S51] | 8.38B; block work 1.14x [DER] | Granite architecture, 40 layers, tied 100k vocab [V: S52] | Apache 2.0 [V: S51] | 116 (3/113) | Not first: "<think>\n</think>" then "<score> yes </score>" [V: S51] | No-think: ToxicChat 0.78, OpenAI Mod 0.83, BeaverTails 0.79 [V: S51] |
| Nemotron-3.5-Content-Safety (2026-06-02) [V: S56] | 4B; text block work 0.46x [DER] | Gemma 3 4B plus SigLIP; 29 sliding-window layers and 5 global; GeGLU; 262k vocab [V: S57] | OpenMDW v1.1 plus Gemma Terms; "ready for commercial use" [V: S56] | 466 (338/129) | Not first: "User Safety: safe/unsafe" [V: S57] | NVIDIA: Aegis 2.0 0.86, WildGuard 0.85, VLGuard 0.90 [V: S56]. Mistral's test: ToxicChat 72.2, OpenAI Mod 74.7 [V: S1] |
| gpt-oss-safeguard 20B / 120B (2025-10-29) [V: S47] | 21B total, 3.6B active (20B) [V: S47] | MoE (32 experts, 4 active), 128-token sliding window, YaRN, clamped SwiGLU, MXFP4 [V: S48] | Apache 2.0 [V: S47] | The user writes the policy; 400–600 tokens recommended [V: S49] | Not first: reasons, then gives the label [V: S49] | Mistral's test: ToxicChat 79.8, OpenAI Mod 84.0 [V: S1] |
| Kanana-Safeguard-8B (2025-05) [V: S61] | 8.03B; block work 1.00x | **Identical shapes to Meta-Llama-3-8B**, no RoPE scaling, plus 8 added verdict tokens [V: S61] | Apache 2.0 [V: S61] | about 60 [EST] | **Single token** `<SAFE>` or `<UNSAFE-S1..S7>` [V: S61] | Internal F1 0.946, Korean only [V: S61] |
| Llama-3.1-Nemotron-Safety-Guard-8B-v3 (2025-10-28) [V: S59] | 8.03B | Llama 3.1 8B Instruct plus LoRA; RoPE scaling [UNV] | NVIDIA Open Model License plus Llama 3.1 terms [V: S59] | about 200–250 words | Not first: JSON [V: S59] | 9-language suite; metric not named [V: S59] |
| WildGuard 7B (2024-06) [V: S62] | 7B | Built on Mistral-7B-v0.3 [UNV] | Apache 2.0, gated behind AI2's terms [V: S62] | not counted | Not first: "Harmful request: yes/no" | ToxicChat 70.8, OpenAI Mod 72.1 [V: S44] |

### Exact text-decoder configurations (each repository's config.json; gated Meta models read through ungated mirrors that match the official parameter counts)

| Model | Layers | d | Heads / KV | head_dim (= d/h?) | FFN | Vocab (tied?) | Norm | RoPE | Attention |
|---|---|---|---|---|---|---|---|---|---|
| TinyLlama (proven) | 22 | 2048 | 32/4 | 64 (yes) | 5632 SwiGLU | 32000 (no) | RMSNorm | θ=1e4 | causal |
| Meta-Llama-3-8B (proven) | 32 | 4096 | 32/8 | 128 (yes) | 14336 | 128256 (no) | RMSNorm | θ=5e5, no scaling | causal |
| Shieldstral text [S2, S15] | 26 | 3072 | 32/8 | **128 (no; q is 4096 wide)** | 9216 SwiGLU | 131072 (**yes**) | RMSNorm 1e-5, pre-norm only | θ=1e6, **YaRN** (factor 16, original 16384, β 32/1, mscale = mscale_all_dim = 1, so attention factor 1); Llama-4 query scale exactly 1 below 16k | causal, `sliding_window: null` |
| Llama Guard 3 1B [S20] | 16 | 2048 | 32/8 | 64 (yes) | 8192 | 128256 (no) | RMSNorm | θ=5e5, **llama3** (factor 8, low 1, high 4, original 8192) | causal |
| Llama Guard 3 8B [S25] | 32 | 4096 | 32/8 | 128 (yes) | 14336 | 128256 (no) | RMSNorm | θ=5e5, llama3 factor 8 | causal |
| Llama Guard 4 text [S30] | 48 | 5120 | 40/8 | 128 (yes) | 8192 dense | 202048 (no) | RMSNorm + **QK-norm** | θ=5e5, llama3 factor 16 | `no_rope_layers` reading [UNV] |
| Qwen3Guard 0.6B / 4B / 8B [S43, S45] | 28 / 36 / 36 | 1024 / 2560 / 4096 | 16/8, 32/8, 32/8 | 128 (no / no / yes) | 3072 / 9728 / 12288 | 151936 (yes / yes / no) | RMSNorm + **QK-norm** | θ=1e6 | causal |
| ShieldGemma 2B [S37, S38] | 26 | 2304 | 8/4 | **256 (no)** | 9216 **GeGLU-tanh** | 256000 (yes) | (1+w) RMSNorm ×4/layer; embeddings scaled by √d | θ=1e4 | 4096 window alternate layers; **softcap 50**; final softcap 30 |
| Granite Guardian 3.1 2B [S54] | 40 | 2048 | 32/8 | 64 (yes) | 8192 | 49155 (yes) | RMSNorm | θ=5e6 | causal + multipliers |
| Granite Guardian 4.1 8B [S52] | 40 | 4096 | 32/8 | 128 (yes) | 12800 | 100352 (yes) | RMSNorm | θ=1e7 | causal; embedding ×12, attention 1/128, residual ×0.22, logits ÷16 |
| Nemotron-3.5-CS text [S57] | 34 | 2560 | 8/4 | **256 (no)** | 10240 GeGLU-tanh | 262208 | RMSNorm | global θ=1e6 (linear ×8); local θ=1e4 | 29 layers with a 1024-token window, 5 global |
| gpt-oss-safeguard-20b [S48] | 24 | 2880 | 64/8 | 64 (no) | MoE 32 experts, top-4 | 201088 | RMSNorm | YaRN factor 32 | 128-token window on alternate layers |
| Kanana-Safeguard-8B [S61] | 32 | 4096 | 32/8 | 128 (yes) | 14336 | 128264 (no) | RMSNorm | θ=5e5, no scaling | causal |

Prompts under 1,024 tokens never trigger the Gemma 2/3 sliding windows (4096 and 1024 tokens), so they change nothing at our lengths. gpt-oss's 128-token window would apply [DER].

## 1. Mistral's moderation and safety classifiers

**Moderation API v1, `mistral-moderation-2411`**
- What it is: launched 2024-11-07, "based on Ministral 8B 24.10", 9 categories [V: S12, S13].
- Weights: **API only** [V: S13].
- Status: deprecated 2026-03-31, retired 2026-06-30 [V: S14].

**Mistral Moderation 2, `mistral-moderation-2603`**
- What it is: released 2026-03-12, 128k context, adds jailbreak detection. 11 categories: sexual, hate and discrimination, violence and threats, dangerous, criminal, self-harm, health, financial, law, PII, jailbreaking [V: S9, S10, S11].
- Weights: **API only**. Mistral's docs don't mention self-hosting [V: S9, S10].
- Other facts: free to use [V: S10]. Mistral does not state the base model or size [UNV elsewhere]. Output is a score plus a "violated" flag per category [V: S9]. **It cannot be proved, because the weights can't be run locally.**

**Classifier Factory**
- What it is: Mistral's hosted service for fine-tuning custom classifiers, launched 2025-04-16 [V: S11].
- Weights: hosted; we found no way to export weights [UNV].

**Shieldstral-1.0-3B**
- What it is: open text+image safety classifier. Paper 2026-07-28; blog and docs 2026-08-04; labelled "public preview" [V: S5, S6, S7].
- Weights: **open**, Apache 2.0, ungated, 3,849,090,048 parameters [V: S4].
- Running it: self-hosted only, with no Mistral API endpoint [V: S8]. Works with vLLM ≥ 0.26, Transformers and llama.cpp; fits one 16 GB GPU; trained to 32k context [V: S1, S8].

Shieldstral details:
- **Base model:** Ministral-3-3B-Base-2512, fine-tuned with LoRA, then a SLERP merge of 3 checkpoints [V: S4, S5].
- **Vision tower:** Pixtral. 24 layers, d=1024, 16 heads, head_dim 64, FFN 4096. Uses SwiGLU, RMSNorm and 2D RoPE (θ=1e4); 14-pixel patches; images up to 1540 px [V: S2, S16].
- **Projector:** RMSNorm → 2×2 patch merge → linear 1024→3072 → GELU → linear [V: S17].
- **Fixed system prompt:** "Judge whether the Document meets the requirements based on the Query and the Instruction provided. Note that the answer can only be "yes" or "no"."
- **User message:** `<Instruct>: …\n\n<Query>: <one yes/no question>\n\n<Document>: <content>`, wrapped as `<s>[SYSTEM_PROMPT]…[/SYSTEM_PROMPT][INST]…[/INST]` [V: S1, S3].
- **Categories:** no fixed taxonomy; the policy is free text. Official advice is one policy per query, or list the categories in `<Instruct>` and ask "Is this content unsafe?" [V: S1].
- **How the score works:** no classification head. One forward pass, then score = e^{z_yes}/(e^{z_yes}+e^{z_no}) over the yes/no logits at the last position, flagged above 0.5 [V: S1, S8]. That is the same as checking z_yes − z_no > ln(τ/(1−τ)): two rows of the output head compared against a public constant [DER].

## 2. Notes per model

- **Llama Guard 3 1B.** The Hugging Face weights are the unpruned 16-layer model with an untied 128k head. The official count of 1,498,482,688 parameters matches that config exactly [DER: S19, S20].
  - Meta's pruned version (12 layers, MLP 6400, 20-token head, about 440 MB) ships only as an ExecuTorch `.pte` file [V: S22, S23].
  - Default categories are S1–S13; S14 is for the 8B model only [V: S26].
- **Llama Guard 4.** No Llama Guard 5 exists [V: S32, S66].
- **Qwen3Guard.** Comes in "Gen" and "Stream" versions; Stream uses token-level classification heads [V: S44]. Labels are three-way: Safe, Controversial, Unsafe. No newer Qwen guard model was on Hugging Face as of 2026-10-20 [V: S46].
- **ShieldGemma.** Takes one harm policy per call. The policy text comes **after** the content, so prefix reuse doesn't help [V: S35; DER: T1].
  - Google's F1 uses an "optimal" threshold. GuardReasoner's third-party run reports ShieldGemma 2B prompt F1 under 15 on every benchmark [V: S64].
- **Granite Guardian.** 4.x judges against named criteria and has think and no-think modes; 3.x answers Yes/No directly [V: S51, S54].
- **Independent cross-check** (arXiv 2605.28830, ICLR 2026 workshop) [V: S65]:
  - Best F1: Nemotron Safety 8B 0.761, Qwen3Guard-4B 0.756.
  - Weaker: ShieldGemma 2B 0.586, Llama Guard 4 0.468, gpt-oss-safeguard-20B 0.380.
  - Scores depend on how each paper maps policies, so treat them as a rough ranking only.
- **Others not tabulated:** DynaGuard (Qwen3-based), SGuard-v1 (Granite-3.3 2B), PolyGuard, Roblox Guard 1.0 (an adapter on Llama-3.1-8B) [V: S66, S73]. Encoder-only classifiers: GLiGuard 300M, ModernBERT-based guards, Llama Prompt Guard 2 [V: S66].

## 3. Text versus media

No open image or video safety classifier is a pure text decoder.

| Image-capable model | Vision part | How close to our blocks |
|---|---|---|
| **Shieldstral** (2026-08) | Pixtral ViT, about 0.4B: RMSNorm, SwiGLU, **2D RoPE**, **non-causal block-diagonal attention**; projector with one GELU and a 2×2 merge [V: S16, S17] | **Closest.** New pieces: non-causal mask, 2D RoPE table, one GELU, reshapes |
| ShieldGemma 2 4B (2025-03) | SigLIP plus Gemma 3 4B (4.30B) [V: S39, S40] | Uses LayerNorm, GELU and learned position embeddings, plus the Gemma 3 decoder |
| Nemotron-3 / 3.5-CS (2026-03 / 2026-06) | SigLIP: 27 layers, d=1152, GELU-tanh, LayerNorm, 896 px → 256 tokens [V: S57] | Same as ShieldGemma 2 |
| Llama Guard 3 11B Vision (2024-09) | Llama 3.2 Vision encoder [V: S34] | Cross-attention [UNV]. Licence denies EU-based licensees rights to the multimodal models [V: S34] |
| Llama Guard 4 12B | 34 layers, d=1408, GELU [V: S30] | 12B is too large |
| LlavaGuard v1.2 0.5B / 7B (2024-11) | LLaVA-OneVision [V: S67] | [UNV] |
| OmniGuard (2025-12), GuardReasoner-Omni (2026-02) | Handle **video and audio**; reason before the verdict [V: S68, S69] | Research models; reasoning means hundreds of tokens to prove |

**Video:** we found no production-grade open video classifier. In practice: sample frames and check each with an image classifier; turn audio into text and check that with a text classifier.

**Cost of one image through Shieldstral** [EST]: a 448×448 image is 1,024 patches through 24 encoder layers (about 0.4 TMAC), producing 272 decoder tokens (about 0.8 TMAC). Total about 1.2 TMAC, versus about 0.9 TMAC for our measured 8B proof at 128 tokens (569 s). One image costs roughly as much as today's largest proof.

**Gap:** images need a non-causal attention relation, 2D RoPE tables, a GELU table, and binding the proof to the posted image (prove the resize and normalisation, or hash-link a committed tensor).

## 4. Fit and recommendation

| | Shieldstral (text) | Llama Guard 3 1B | Qwen3Guard-0.6B | Kanana-Safeguard-8B |
|---|---|---|---|---|
| (a) Architecture | Llama-like; needs decoupled head_dim, YaRN, tied head | Plain Llama; needs llama3 RoPE table | Needs QK-norm, decoupled head_dim, tied head | **Exact Llama-3-8B shapes** |
| (b) Size | 3.43B text, block work 0.43x | 1.50B, block work like TinyLlama, head 4x larger | 0.60B | 8.03B; fits the laptop at about 125 tokens |
| (c) Fixed vs content tokens | about 90 fixed: **90 before content, 1 after** | 193 fixed: 139 before, 56 after | about 298 fixed: 202 before, 96 after | about 60 fixed [EST] |
| (d) Single-token verdict | **Yes**, decided by comparing two logits | Yes, possibly after "\n\n" [UNV] | Yes, after a 2-token "Safety:" prefill | **Yes** |
| (e) Licence | **Apache 2.0, ungated** | Llama 3.2 Community, gated | Apache 2.0 | Apache 2.0 |
| (f) Quality | **Best:** ToxicChat 84.1, OpenAI Mod 81.4 | Weak in third-party tests (22.3 / 36.8) | Good for its size (77.7 / 77.6, loose) | Korean only |

**Recommendation:**
1. **Shieldstral-1.0-3B, text only, is the MVP classifier.** It is the Mistral model Victor asked about. It has the best licence and quality in the 1–8B range. Its template is the shortest, and the verdict is the first token. Its policy is a public string the app can publish. Its image path is the most Llama-like for later.
2. **Optional zero-change smoke test: Kanana-Safeguard-8B.** It would show a real published moderation model proved end to end. Not suitable for the investor demo, because it is Korean-only.
3. **Fallback if Shieldstral's int8 accuracy disappoints: Qwen3Guard-Gen-0.6B.** It needs QK-norm on top of Shieldstral's feature list.
4. **Not first:** Llama Guard 3 1B (weak independent scores); ShieldGemma and Granite 4.x (the policy text comes after the content); gpt-oss-safeguard and Llama Guard 4 (too large or too different).

**New prover features (flagged)**

| # | Feature | Needed by | Notes |
|---|---|---|---|
| F1 | YaRN and llama3 RoPE frequency transforms | Shieldstral; Llama Guard 3/4 | A change to a public constant table only. The importer refuses `rope_scaling`; the int8 calibration script ignores it |
| F2 | head_dim decoupled from d/heads | Shieldstral, Qwen 0.6B/4B, Gemma | The importer currently raises "unsupported head dimension" |
| F3 | Tied embedding and output head | Shieldstral, Qwen 0.6B/4B, Granite, Gemma | `zk60_1b_checkpoint.py` rejects it. Confirm the native import path |
| F4 | Verdict as z_yes − z_no > c (c a public constant) instead of argmax over the full vocabulary | Shieldstral, ShieldGemma, Granite | 2 head rows instead of 131k, and it matches the official decision rule. **It changes the public statement, so it needs a ruling** |
| F5 | Assistant prefill (fixed tokens appended so the verdict comes next) | Qwen3Guard, Granite 4.1, Nemotron; maybe Llama Guard 3 | No new circuit; must be checked against the model's free generation |
| F6 | **Public-prefix KV reuse (P1)** | All; biggest gain for Shieldstral (90 of 91 fixed tokens before the content), Llama Guard 3, Qwen | New relation: attention reads a public or committed KV for the prefix |
| F7 | QK-norm | Qwen3Guard, Llama Guard 4, Gemma 3 | Reuse the RMSNorm gadget on each head |
| F8 | Gemma operations, including tanh softcapping on every attention score | ShieldGemma, Nemotron-CS | Softcapping is the expensive part |
| F9 | Granite multipliers | Granite | Can be folded into the weights |
| F10 | Pixtral vision tower plus binding to the image | Shieldstral images | See section 3 |
| F11 | Int8 fidelity check | All | Published F1 numbers are for BF16. Re-measure on ToxicChat and OpenAI Moderation after our int8 calibration before quoting any accuracy |

**Statement note:** the proof must name which content it covered. Bind the private-input commitment to the posted item's hash, and either prove tokenization or commit to the token IDs directly. This is a statement-design item; it does not reopen the P1 decision.

## 5. Rough proving-time extrapolation [EST]

A three-unknown formula fitted exactly to the three laptop runs in the brief (TinyLlama at 32 tokens 85 s; 8B at 32 tokens 296 s; 8B at 128 tokens 569 s):

t ≈ 51 s + 19.1 s × (total params, B) + 0.407 s × tokens × (block params, B)

It has **not** been checked against any other run; use it only to rank the candidates.

| Model | 64-token post: tokens proved → est. time | With F6 | 256-token post | 256 with F6 |
|---|---|---|---|---|
| Shieldstral | 155 → about 310 s | 65 → about 200 s | 347 → about 545 s | 257 → about 435 s |
| Llama Guard 3 1B | 257 → about 180 s | 120 → about 130 s | 449 → about 260 s | 312 → about 205 s |
| Qwen3Guard-0.6B | 362 → about 130 s | 162 → about 90 s | 554 → about 160 s | 354 → about 125 s |
| Qwen3Guard-4B | 362 → about 660 s | 162 → about 370 s | 554 → about 950 s | 354 → about 650 s |
| ShieldGemma-2B, one policy (F8 cost not included) | 194 → about 260 s | 164 → about 235 s | 386 → about 420 s | 356 → about 395 s |
| Kanana-8B | 124 → about 560 s | 74 → about 415 s | 316 → about 1,100 s (may not fit memory) | — |
| Llama Guard 3 8B | 264 → about 955 s | 119 → about 545 s | 456 → about 1,500 s | 311 → about 1,090 s |

Memory: about 8 GiB was measured for 8B at 128 tokens. Shieldstral at about 150 tokens should need less, but this is [UNV] until measured.

## 6. Caveats

- Headline F1 numbers are self-reported unless marked third-party. Third-party numbers swing with the policy text and threshold: ShieldGemma 2B scores 0.812 on OpenAI Mod in Google's run and 44.8 in DuoGuard's.
- Gated Meta and Google files were read from ungated mirrors (S20, S25, S30, S37). Each matched the official parameter count or model card.
- Two details need one real forward pass to settle: whether Llama Guard emits "\n\n" first, and the exact whitespace in Granite 4.1's output. Neither changes the recommendation.
- Mistral labels Shieldstral "public preview" [V: S7]. Pin the weight hash when importing (repository last modified 2026-08-05 [V: S4]).

## Sources

`SOURCES.md` in this directory has the full annotated list, numbered S1–S73 and T1. Key primary sources:
- Shieldstral: https://huggingface.co/mistralai/Shieldstral-1.0-3B ; https://mistral.ai/news/shieldstral ; https://arxiv.org/abs/2607.25857 ; https://docs.mistral.ai/models/shieldstral-1-0
- Mistral Moderation API: https://docs.mistral.ai/models/mistral-moderation-26-03 ; https://docs.mistral.ai/resources/changelogs
- Meta: https://huggingface.co/meta-llama/Llama-Guard-3-1B ; https://huggingface.co/meta-llama/Llama-Guard-3-8B ; https://huggingface.co/meta-llama/Llama-Guard-4-12B
- Google: https://huggingface.co/google/shieldgemma-2b ; https://huggingface.co/google/shieldgemma-2-4b-it
- Qwen: https://huggingface.co/Qwen/Qwen3Guard-Gen-0.6B ; https://arxiv.org/html/2510.14276v1
- OpenAI: https://huggingface.co/openai/gpt-oss-safeguard-20b
- IBM: https://huggingface.co/ibm-granite/granite-guardian-4.1-8b ; https://huggingface.co/ibm-granite/granite-guardian-3.1-2b
- NVIDIA: https://huggingface.co/nvidia/Nemotron-3.5-Content-Safety
- Kakao: https://huggingface.co/kakaocorp/kanana-safeguard-8b
- Third-party evaluations: https://arxiv.org/html/2502.05163 (DuoGuard); https://arxiv.org/html/2501.18492 (GuardReasoner); https://arxiv.org/html/2605.28830v1
