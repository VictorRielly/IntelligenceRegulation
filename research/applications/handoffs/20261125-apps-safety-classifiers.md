# Which public safety classifiers a buyer would name, and what each needs from the prover (A10)

**Question.** Which open-weight safety or moderation classifiers of up to about 8B parameters are in common use, what do their own pages say about size, architecture, context, labels and licence, and which operations does our block prover lack for each?

**Answer in one line.** Only the Llama-architecture guards (Llama Guard 3 at 1B and 8B, Nemotron Safety Guard 8B v3 after merging its adapter) match the operations the prover already has; Granite Guardian, Qwen3Guard and ShieldGemma each add new relations, and every generative guard also needs a label relation the installed single-margin classifier does not have. Nothing here was run. A model fitting on paper is not a fidelity result.

## What was read and how

12 web searches (standard mode) and 12 page fetches: vendor `config.json` and pages for Qwen3Guard-Gen-8B and Granite Guardian 3.3 8B, the ShieldGemma paper abstract, and **mirror** configs for Llama Guard 3 1B and 8B (not Meta's). Meta's and Google's pages redirected to other domains, which I did not follow; the Gemma and Llama repositories return 401 (gated). **The fetch budget is spent**, so several rows rest on search snippets, marked below. Local reading: `rope.rs`, `tables_attn.rs`, `scripts/zk60_1b_checkpoint.py`, the Shieldstral statement v3, `MVP_STATUS.md`.

## What the prover has today (COUNTED)

- Decoder blocks with RMSNorm, grouped-query causal attention, SiLU gated feed-forward, tied or untied head, RoPE with `none`, `llama3` and `yarn` frequency transforms as public tables ([rope.rs:29-35](../../../ops/zkp-mvp/gpu-metal/hashline/src/private_block/rope.rs)). A YaRN profile whose attention factor is not exactly 1 is refused by name (rope.rs:87).
- The attention scale 1/sqrt(d_h) lives in the exponential table's decay parameter, as a power-of-two exponent over sqrt(d_h) ([tables_attn.rs:7-16, 97](../../../ops/zkp-mvp/gpu-metal/hashline/src/tables_attn.rs)).
- No file under `hashline/src` mentions QK-norm, soft-capping, sliding window, LayerNorm or GELU (grep, zero hits). A GELU relation exists only in the separate image-projector proof (MVP_STATUS, 2026-11-15 entry), not in the block prover.
- The generic importer refuses `rope_scaling`, sliding window, tied embeddings and bias ([zk60_1b_checkpoint.py:121-145](../../../scripts/zk60_1b_checkpoint.py)); the Shieldstral native export path handles tied embeddings and YaRN, so the importer is the narrower of the two.
- The installed classifier proves one comparison: a tied yes/no margin after a fixed suffix, on a T = 128 profile, with three registered policies ([privacy statement v3, Policies row](../../../docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md)). A trained Llama-3-8B proof exists for one next token on a calibration prompt, as a development profile that failed the D32 quality run (MVP_STATUS line 5 and its second reading).

## The table

DERIVED sizes are my arithmetic from the published dimensions (attention, gated MLP, norms, embeddings, one head unless tied). Context lengths are `max_position_embeddings`; the prover's limit is T = 128 per chunk, so a published context does not decide fit.

| Model | Size and architecture | Labels and output | Licence | Needs beyond today's prover |
| --- | --- | --- | --- | --- |
| **Llama Guard 3 1B** | [Mirror config] 16 layers, width 2048, 32 query / 8 key-value heads, head_dim 64, MLP 8192, vocab 128,256, untied, llama3 RoPE (factor 8), max positions 131,072. DERIVED 1.50B. | MLCommons categories S1 to S14; the 1B card says it is not tuned for S14; eight languages [search snippet of Meta's card]. Output is generated text. | Llama 3.2 licence [search snippet] | Import path with `llama3` RoPE (the table code exists; the importer refuses it). Label relation (below). **Closest to a drop-in.** |
| **Llama Guard 3 8B** | [Mirror config] identical shape to Llama 3.1 8B: 32 layers, width 4096, MLP 14,336, 8 key-value heads, untied, llama3 RoPE. DERIVED 8.03B. | Same S1 to S14, text generation | Llama 3.1 licence [search snippet; not read] | Same as above, at the size where the proven 8B export already failed D32 once and is being refitted. The published prompt lists every category; its token length was not counted here. |
| **Nemotron Safety Guard 8B v3** | [Search snippet of NVIDIA and HF pages] Llama-3.1-8B-Instruct plus a LoRA (rank 8, q and v projections only); 23 safety categories, 9 languages. | Generated structured text | NVIDIA Open Model Licence plus Llama 3.1 terms; one NGC page says "no longer supported" | Merge the adapter into the public weights, then as Llama Guard 3 8B. The merged weights are a new export needing their own calibration. |
| **Qwen3Guard-Gen 8B** (also 4B, 0.6B) | [Vendor config] Qwen3, 36 layers, width 4096, 32 / 8 heads, head_dim 128, MLP 12,288, vocab 151,936, untied, theta 1e6, no scaling, max positions 32,768. DERIVED 8.19B with per-head q/k norms counted. | Safety: Safe, Unsafe or Controversial; eight named categories; Refusal yes/no for responses; 119 languages [vendor page] | Apache-2.0 [vendor page] | **Per-head RMSNorm on queries and keys before RoPE.** The config has no field for it; I recall it from Qwen3's modeling code and did not verify it this tick. Label relation. |
| **Granite Guardian 3.3 8B** | [Vendor config] Granite, 40 layers, width 4096, 32 / 8 heads, MLP 12,800, vocab 49,159, **tied**, max positions 131,072, plus `embedding_multiplier` 12, `residual_multiplier` 0.22, `attention_multiplier` 0.0078125, `logits_scaling` 16. DERIVED 8.17B. | Yes/no in `<score>` tags; harm, RAG and function-calling risks; English only [vendor page] | Apache 2.0 [vendor page] | Residual multiplier on both branches (changes requantisation); attention scale 2^-7 instead of 1/sqrt(128), so the exponential table needs a different parameterisation; embedding multiplier folds into the public rows. The logits scale does not change which of two logits is larger. |
| **ShieldGemma 2B / 9B** (27B excluded) | [Search snippets of the Gemma 2 report; configs 401] Gemma 2 base. For the 9B: 42 layers, width 3584, 16 / 8 heads, GeGLU, alternating 4,096-token local and 8,192-token global attention, tanh soft-cap 50 in attention and 30 on final logits, pre- and post-norms. | Four harm types: sexually explicit, dangerous, harassment, hate; prompt or prompt-and-response mode [search snippet] | Gemma terms | **Most new relations:** GELU gate, soft-cap tanh (both a lookup relation), sliding-window mask, extra post-norms. The Yes/No logit form is the nearest to Shieldstral's; I recalled this from memory and did not retrieve it. |
| **WildGuard 7B** | [Search snippet] fine-tuned from Mistral-7B-v0.3; three tasks (prompt harm, response harm, refusal). I did not retrieve its config. | Three yes/no fields in generated text (from memory) | Apache 2.0 [HF snippet]; gated download | Likely only the Llama-family operations; unverified because I did not read its config. Label relation for three fields. |
| **Llama Prompt Guard 2 (86M, 22M)** | [Search snippet] mDeBERTa-base and DeBERTa-xsmall encoders; 512 tokens | Benign or malicious; injections and jailbreaks, not content harm | Llama 4 community licence (listings disagree) | Disentangled bidirectional attention, LayerNorm, GELU, classification head; a different proof family. **It is not a moderation classifier**; include it only if a buyer names it. |
| *Not in scope by size* | Llama Guard 4 12B (dense, pruned from Llama 4 Scout, text and images [search snippet]); ShieldGemma 27B; gpt-oss-safeguard (not searched). | | | |

For reference, our installed model is Shieldstral-1.0-3B: Ministral-3-3B base, Pixtral encoder (not proved), Apache 2.0, policy supplied as a natural-language question and a single yes/no token [secondary reports; the app's own statement counts the proved text path].

## The gap that is not an operation: the label relation

The installed relation fixes two token ids and proves their margin after a fixed suffix. Llama Guard 3, Qwen3Guard, Granite and WildGuard emit **several generated tokens** (a verdict, then categories or fields). A product choosing any of these must pick one of two relations: (a) prove only the first label token (a verdict bit, as today), and treat categories as unproved; or (b) prove a greedy decode of k tokens, k forward steps with an argmax relation each. Option (b) multiplies the proving work by roughly k, DERIVED from one forward pass per generated token, and I have no measurement of it. Which tokens are the decisive ones in each card's format was not verified.

## What a product would have to build

1. An **import-and-fit** per guard, calibrated against the D32 bar (1.01x perplexity, 99%, zero range refusals; MVP_STATUS around line 3505).
2. A **policy template that fits** the T and chunk plan (Shieldstral's registered texts are 72 and 78 tokens; Llama Guard's category list was not counted).
3. The **label relation**, and a registered policy list per buyer (the prover admits fixed policies only).
4. For Qwen, Granite or Gemma guards, the new relations in the table, each with its own review and Lean statement.

## A test that would confirm or kill the finding

Take Llama Guard 3 1B. Export through the native path with the `llama3` RoPE table; run the integer reference and the float model on 300 held-out public prompts using the published template; record verdict agreement and range refusals; then prove one prompt and verify. **Confirmed** if agreement is at least 99% of the float verdict with zero refusals and the one proof verifies at a rung whose T holds the template. **Killed** (for this family) if the published prompt exceeds the chunk plan without a safe split, if refusals appear, or if a first-token verdict loses the category information the buyer needs.

## What was not verified

Official cards for Llama Guard 3, ShieldGemma and WildGuard (gated or redirected); Llama Guard 3's exact context claim and prompt length; Qwen3's QK-norm in code; ShieldGemma's config and output tokens; all quality or false-positive figures; whether any model's integer range fits the prover's bounds. The 12-fetch budget is exhausted, so a follow-up should read those pages directly.
