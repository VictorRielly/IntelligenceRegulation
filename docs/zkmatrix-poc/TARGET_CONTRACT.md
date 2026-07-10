# Target Contract: What "a 5-15 s Proof of an 8B Feedforward" Will Mean

Status: FROZEN benchmark boundary (audit 2026-07-10 finding H-05). This
page pins every word of the headline claim so that a future latency
number is checkable instead of elastic. Nothing here is a measurement;
where a budget is not yet met (or not yet measurable) it says so.

## 1. The model

- **Measured surrogate (today):** 32 identical feedforward (FFN) blocks
  with model width d = 4096 and hidden width f = 11008 — the Llama-2-7B
  FFN dimensions. Each block is: gate = Wg X, up = Wu X (both d -> f),
  a = SiLU(gate) via the frozen int8 lookup table, h = a o up
  (elementwise product), out = Wd h (f -> d). "7B-class surrogate"
  always means THIS configuration, matmul shape 512 x 4096 x 11008.
- **The 8B target adds** (Llama-3-8B-class): hidden width f = 14336;
  grouped-query attention (32 query heads, 8 key/value heads, head
  dimension 128) with rotary position embeddings (RoPE) and softmax;
  RMSNorm twice per layer; residual additions; embedding/unembedding at
  a ~128k vocabulary. **None of these are implemented in the proof
  system today** — softmax/normalization do not even have a frozen
  integer specification yet. Any latency number quoted before they
  exist is a number for the FFN surrogate only and must say so.
- **Model identity:** the proof statement (manifest.rs `Statement` v2)
  carries a model identity digest — a hash of the architecture
  descriptor, the quantization spec below, every weight commitment, and
  the activation-table digest. A verifier accepts a proof only for that
  exact frozen model.

## 2. Quantization (the exact integer semantics)

- Weights and activations: 8-bit signed integers (int8), symmetric,
  power-of-two scales. Matmul accumulators: 27-bit signed (inner
  dimension 4096) / 29-bit signed (inner 11008) — worst-case exact at
  the q31 working modulus (no wraparound possible).
- Requantization: power-of-two rescale x = 2^shift * y + r with the
  remainder r **proven** in [0, 2^shift) — dense bit planes committed at
  the q46 gadget modulus, tied to the q31 values by the U-L modulus
  link (the integer-exact construction demonstrated in `chain-demo`).
- Rescaled activations are narrowed back to int8 by a **proven** range
  fact, or by SiLU table-domain membership where the activation feeds
  the lookup. An uncalibrated model simply cannot be proven (the range
  facts fail) — that is intended behavior.
- SiLU: the frozen 256-row int8 -> int8 table; its digest
  (`ring/lookup.rs::table_spec_digest`) sits in every statement header.
- NOT yet proven: input-token and weight ranges are *declared* in the
  statement's quantization metadata, not range-proven against their
  commitments (open M3 finding). The contract's soundness story is
  complete only once those facts are added or a commitment discipline
  argument replaces them.

## 3. Workload, visibility, and what the clock covers

- **Token mode:** single-request prefill over a sequence of T = 512
  tokens (one forward pass; no generation loop, no batching).
- **Private:** weights (committed once, off the clock) and all
  activations/intermediates (committed per proof). **Public:** the
  statement (shapes, quantization metadata, digests), the declared
  output tensor values, the proof. ZK caveat: the current lookup
  transcript is NOT zero-knowledge (audit C-01); until the U-K5 masking
  lands, "private" holds only against the commitment layer, not the
  lookup transcript, and no ZK claim may accompany a latency claim.
- **The latency clock starts** with the committed model and the input
  tokens in memory, and **stops** when the serialized proof bytes
  exist. It INCLUDES witness inference (the quantized forward pass),
  all per-proof commitments (activations, remainders, bit planes), all
  claim/lookup/link proofs, hashing, and proof serialization. It
  EXCLUDES one-time setup: CRS expansion, A1 kernel caches, weight
  commitment, table freezing.

## 4. Hardware, statistics, and budgets

- **CPU reference machine:** the repo workstation — Intel Core Ultra 9
  185H (6P + 8E + 2LP cores, 22 threads), 15 GB RAM, WSL2, stock power
  limits, no accelerator. All current measurements are from this box.
- **GPU rung:** the 5-15 s headline is only claimable on one consumer
  GPU (<= 450 W board power, exact model and driver to be named in the
  benchmark artifact when a kernel exists). Today **no GPU kernel
  exists in this repo**; every GPU row in the cost documents is an
  assumption, and this contract makes the headline claim CONDITIONAL on
  that rung being built and measured (audit H-02/H-03 sequencing).
- **Statistic:** the claim uses **p95** wall-clock over at least 20
  warm runs on an otherwise idle machine, with p50 reported alongside;
  cold-start (first run after setup) reported separately.
- **Proof size budget:** <= 256 KB serialized. Current ~120-170 KB
  figures are modeled from field-element counts, not a wire format
  (audit M-05) — the budget binds once a canonical encoding exists.
- **Verifier budget:** <= 2 s single-threaded on the CPU reference
  machine, statement validation included. Verifier time at full shape
  is unmeasured today (toy-shape chain verifies in ~0.2 s).

## 5. Honest status of the pieces (2026-07-10)

| piece | status |
|---|---|
| FFN matmul commitments at full shape | measured (commitment stream only, M5-lite) |
| matmul claim proofs at full shape | NOT measured (largest full proof: 128x256x64) |
| range family, integer-exact (q46 link) | built + adversarially tested at toy shape (chain-demo) |
| SiLU lookup core | built, unmasked, microbenchmarked single-thread; not FFN-integrated (U-K8 open) |
| lookup zero-knowledge masking (U-K5) | in progress on a parallel branch; not complete |
| multi-layer chaining (32 blocks under one statement) | NOT implemented (statement format exists; `statement-inventory` walks the 32-layer DAG) |
| attention, softmax, RoPE, RMSNorm, residual, embedding | NOT implemented, NOT specified as integers |
| GPU kernels | none exist |

*Companion docs: LLM_SCALE_ESTIMATE.md (cost ladder),
M5_LITE_REPORT.md (measured commitment stream), CLAIM_MANIFEST.md +
src/manifest.rs (statement format), codex-audit-2026-07-10 (findings
H-02/H-05 this contract answers).*
