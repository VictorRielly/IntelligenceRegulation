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
  q31 (the 31-bit prime modulus all value tensors are committed under;
  q46 below is the 46-bit modulus of the range-proof gadget layer).
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
  output tensor values, the proof. [AMENDED 2026-07-27 — Amendment
  A1: the private set becomes a per-deployment declaration (modes
  P1/P2/P3, ZK_GAP_OPTIONS.md Section 6); zero-knowledge for the
  DECLARED private set is non-negotiable.] ZK status (updated 2026-07-10,
  tranche U-K5): the lookup transcript is now MASKED — the U-K5
  masking landed with its adversarial battery green, closing the
  histogram leak the audit flagged (C-01); the masked subprotocol is
  honest-verifier zero-knowledge at the proof-of-protocol level
  (lemmas Q4.7-Q4.9). Two caveats must accompany any ZK claim: the
  guarantee is per-subprotocol (chain-wide composition carries its
  own analysis, the R1.3-class honesty note), and the FFN-integration
  caveat (updated 2026-07-14, closing the 2026-07-12 audit M-02
  status conflict): the masked lookup HAS now run inside a
  range->lookup->Hadamard chain with measured marginals — the U-K8
  exit CLOSED 2026-07-10 at 1020-element row-block granularity
  (M4_LOOKUP_DESIGN.md Section 7''), but NOT as a single full-shape
  512x11008 instance (the q31 C2 wave cap binds a committed descent
  near 2^17 elements) and not as a multi-layer pass.
- **The latency clock starts** with the committed model and the input
  tokens in memory, and **stops** when the serialized proof bytes
  exist. It INCLUDES witness inference (the quantized forward pass),
  all per-proof commitments (activations, remainders, bit planes), all
  claim/lookup/link proofs, hashing, and proof serialization. It
  EXCLUDES one-time setup: expanding the common reference string (the
  public commitment key), building the A1 number-theoretic-transform
  kernel caches, committing the weights, freezing the table.

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
- **Statistic:** the claim uses **p95** (95th-percentile) wall-clock
  over at least 20 warm runs on an otherwise idle machine, with p50
  (the median) reported alongside; cold-start (first run after setup)
  reported separately.
- **Proof size budget:** <= 256 KB serialized. Current ~120-170 KB
  figures are modeled from field-element counts, not a wire format
  (audit M-05) — the budget binds once a canonical encoding exists.
  [AMENDED 2026-07-27 — see the Amendment A1 block at the end of
  this document: ZK is non-negotiable; the size line is re-tiered.]
  TIGHTNESS FLAG (2026-07-10): the masked lookup transcript alone is
  150 KB at the FFN point (freeze row LKP-7, counted at 64 B per
  extension-field element) — masking added ~30 KB over the unmasked
  model, so lookup transcript + claim-layer proof now presses against
  the 256 KB budget; the canonical wire format and any transcript
  compression are load-bearing for this line, not cosmetic.
- **Verifier budget:** <= 2 s single-threaded on the CPU reference
  machine, statement validation included. Verifier time at full shape
  is unmeasured today (toy-shape chain verifies in ~0.2 s).

## 5. Honest status of the pieces (2026-07-10; SiLU lookup row updated 2026-07-14)

| piece | status |
|---|---|
| FFN matmul commitments at full shape | measured (commitment stream only, M5-lite) |
| matmul claim proofs at full shape | NOT measured (largest full proof: 128x256x64) |
| range family, integer-exact (q46 link) | built + adversarially tested at toy shape (chain-demo) |
| SiLU lookup core | built, unmasked, microbenchmarked single-thread; FFN-INTEGRATED [H-03 rename 2026-07-15, audit 2026-07-14: read "committed activation-chain rig" — the rig proves no FFN matmul, requantization edge, or residual; a complete caller-supplied FFN layer is an OPEN security exit, RANGE_AGGREGATION_DESIGN.md Section 0 item 5] (update 2026-07-14): the U-K8 exit closed 2026-07-10 at 1020-el row-block granularity — masked committed lookup inside the `ffn-chain` range->lookup->Hadamard rig, measured marginals in M4_LOOKUP_DESIGN Section 7''; the single-instance 512x11008 shape did NOT run (q31 C2 wave cap) and multi-layer chaining remains NOT implemented (row below) |
| lookup zero-knowledge masking (U-K5) | built + battery green (2026-07-10): committed masked pass, engine-scale histogram-recovery closed, E3Z-N1..N4 ordering/rank pairs; HVZK at subprotocol level; masked transcript 150 KB/pass (LKP-7) |
| multi-layer chaining (32 blocks under one statement) | NOT implemented (statement format exists; `statement-inventory` walks the 32-layer DAG) |
| attention, softmax, RoPE, RMSNorm, residual, embedding | NOT implemented, NOT specified as integers |
| GPU kernels | none exist |

*Companion docs: LLM_SCALE_ESTIMATE.md (cost ladder),
M5_LITE_REPORT.md (measured commitment stream), CLAIM_MANIFEST.md +
src/manifest.rs (statement format), codex-audit-2026-07-10 (findings
H-02/H-05 this contract answers).*

## Amendment A1 (2026-07-27) — ZK non-negotiable; size line re-tiered

Authority: Victor, console decision 2026-07-27 ("Let's go with option
B. Zero Knowledge is nonnegotiable (although partial knowledge may be
acceptable in some cases)"), at the U-AG3 close. Context and the full
options analysis: ZK_GAP_OPTIONS.md; technical basis:
AGGREGATION_ZK_DESIGN.md (the evaluation-proof floor leak, AZ-T1).
This block supersedes the two lines it is referenced from; nothing
else in the contract moves.

1. **ZK requirement (new, binding).** The deployment claim requires
   zero-knowledge for the deployment's DECLARED private set. The
   private set is a per-deployment declaration: P3 = weights AND
   inputs/activations private (the original Section 3 reading, the
   default); P2 = weights private, inputs public; P1 = inputs
   private, weights public; P0 = nothing private (verification-only;
   no ZK machinery required, non-ZK label permitted). Partial
   knowledge is acceptable ONLY as an explicit per-deployment
   declaration of a smaller private set — never as a silent
   degradation of a declared one. Weights are the
   accumulation-critical class (a fixed witness re-proven every
   pass): any mode declaring weights private requires the masked
   (full-ZK) evaluation-proof path on every weight-touching proof,
   every pass.
2. **Proof-size budget (re-tiered; supersedes the single <= 256 KB
   line).**
   - Tier N (non-ZK-labeled aggregate artifact, mode P0 only):
     <= 262,144 B per FFN layer — the U-AG-B1 engineering gate,
     unchanged in number, now explicitly scoped to P0.
   - Tier Z (full-ZK aggregate artifact, modes P1-P3): interim
     ceiling <= 512 KiB per FFN layer unfolded (the Option B
     corridor, 453-517 KiB [MODEL]); the BINDING pass-level Tier Z
     budget is to be FROZEN at the U-AG4 FINAL from the folding
     round's derived numbers (target class 0.5-2 MiB per 32-layer
     pass [MODEL] — the ZK surcharge is per evaluation proof, not
     per layer, so folding concentrates it).
   - The pre-reroute wave-architecture path keeps the original
     Section 4 line unchanged (it is fully HVZK and does not meet
     any aggregate byte tier; its role is recorded in
     ZK_GAP_OPTIONS.md Option E).
   - Budget scope: the 256 KB figure historically read ambiguously;
     the per-pass reading was adopted at the U-AG3 FINAL
     (AGGREGATION_ENCODING_DESIGN.md Section 4's three contract
     anchors). Tier N is per-layer BY THIS AMENDMENT (an engineering
     gate); Tier Z's frozen form at U-AG4 FINAL will state its scope
     explicitly.
3. **Verifier budget:** unchanged (<= 2 s single-threaded, statement
   validation included) and applies to every tier and mode.
