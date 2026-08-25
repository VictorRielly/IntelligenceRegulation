# The general quantization contract — design memo

Status: DRAFT FOR VICTOR'S RULING (orchestrator, 2026-08-25).
Companion measurements: U_PERF3_M8B_SMOOTH_REPORT.md (the fold
experiment, agent U), U_PERF3_M8B_BLITE_REPORT.md (per-column
pricing, agent V — IN FLIGHT, its numbers plug into §3.2/§5 when it
lands), results/m8b_int8_calibration_wsl.json (the Mistral baseline
verdict). Authority: Victor, console 2026-08-25 (verbatim): "Let's
look for a fix that can work in many different contexts (such as
this proof requires no more than 8 bit quantization models) or
something, instead of conjuring a fix specific to this precise use
case. The more general fix is much more easy to maintain going into
the future. Be sure to document the engineering design choices and
limitations." Plus, same day, the model-side question: is there an
open 8B-class model whose NATIVE quantization is friendlier
(Gemma 4 named)? §6 answers it with sources.

## 0. The problem, restated generally

TARGET_CONTRACT §2 as frozen assumes: one power-of-two scale PER
TENSOR SITE, int8 everywhere, exact floor-requant chain. That
contract was designed and validated at 125M — below the scale at
which transformer activations develop "massive activations":
a small, channel-stable set of coordinates carrying 3-6000x the
bulk range (measured on Mistral-7B-v0.1: x absmax/p99.99 2-6.5x
per layer, Hadamard h up to 6158x; the literature places emergence
at ~6.7B+ and finds it in essentially every modern pretrained LLM).
Consequences [MEASURED WSL-BOX 2026-08-24]: 14,531 held-out
range-fact violations and +8.18 nats of chain loss — the statement
is both FALSE and, made true by rescaling, WORTHLESS (agent U:
exact per-channel folds reach 3 violations but the loss stays
+7.9..9.1 in every policy — covering outliers at per-tensor
granularity destroys bulk precision).

So the choice is: patch the spec per-model (rejected by the
authority quote), or redesign the quantization contract so that it
is MODEL-AGNOSTIC: any checkpoint that can be represented at <= 8
bits with static scales either QUALIFIES under a public, mechanical
gate, or fails it HONESTLY, with the failure measured and recorded.
This memo is that redesign.

## 1. The contract (proposed TARGET_CONTRACT §2 v3, behind a
##    statement-version selector — the frozen v2 statement and its
##    freeze rows do not move; tranche rule "Transcript-changing
##    work is a NEW protocol version" applies)

C1 — CHAIN FORM (unchanged). The proved computation stays the exact
integer chain: int8 operands, exact integer accumulation, floor
requant x = 2^shift * y + r with r in [0, 2^shift), elementwise
gates through frozen int8 lookup tables, range facts on every
declared class. Nothing in this memo touches the proof-side
semantics of a single arithmetic operation.

C2 — SCALE GRANULARITY (generalized). Every quantization site
carries a PUBLIC vector of power-of-two exponents over one declared
axis (weights: per output channel; activations: per channel of the
site's channel axis), frozen at calibration time. "One scale per
tensor" remains as the degenerate constant vector — the 125M
statement is the special case, unchanged. All scales stay powers
of two, so requant remains shift-only; mixed-exponent accumulation
aligns by per-column shifts before the sum (exact integers; the
engine surface of exactly this is what agent V prices).

C3 — MODEL IDENTITY = RAW CHECKPOINT + DECLARED PREPROCESSING.
The identity binds: (i) the raw checkpoint digests, (ii) a declared
pipeline of function-preserving fp-side transforms, (iii) the
calibration record (data, seed, windows), (iv) the transformed
weight digests the statement actually commits. Admissible
transforms:
  T1 per-channel power-of-two folds across linear seams (the agent
     U family: norm-weight/column, up-row/down-column) — exactly
     function-preserving, even in fp (PoT products are exact).
  T2 STATIC orthogonal rotations folded into weights across linear
     seams on the d-axis (QuaRot/SpinQuant-class incoherence
     processing) — function-preserving in real arithmetic; fp
     realization rounding is absorbed by the C4 quality gate (it is
     measured, not assumed away). At d = 4096 = 2^12 the
     Walsh-Hadamard normalization 1/sqrt(4096) = 2^-6 is itself a
     power of two — the natural first rotation.
  T3 nothing else: no retraining inside the identity (a QAT
     fine-tune produces a DIFFERENT checkpoint, honestly labeled as
     such — see §4 route Q).
Any verifier can re-derive (iv) from (i)+(ii)+(iii); the pipeline
is data, not trust.

C4 — THE QUALIFICATION GATE (new, the heart of the generality).
A (checkpoint, pipeline, calibration) triple QUALIFIES iff, on a
declared held-out set:
  (i)  range-fact violations = 0 in every class;
  (ii) chain quality delta vs the checkpoint's own bf16 reference
       <= a declared budget (proposal: <= 0.10 nats for the
       "faithful" label; the budget is printed on the statement
       either way);
  (iii) every table member used is in the frozen registry (C5).
The gate is a mechanical, reproducible script run (the m8b
calibration machinery is already exactly this); its verdict JSON is
part of the public record. A model that cannot meet (i)+(ii) at 8
bits with static scales FAILS VISIBLY — the contract's promise is
honest detection, not universal rescue.

C5 — OPEN TABLE REGISTRY (generalizes W-6). The elementwise-gate
table family becomes a registry keyed by (function, e_in, e_out):
silu members, gelu-tanh members (Gemma), relu^2 (BitNet-class),
each frozen with its digest once, manifest-pinned, added by ruling.
Adding a member is a table freeze, never a protocol change.

C6 — DECLARED MARGINS. Calibration margin bits per class are
statement data (agent U measured why they must ride with
compaction: margins alone moved the bulge h->z, 357k violations).

## 2. Why this is the general fix (the design argument)

The measured failure has one cause with one invariant structure:
outlier CHANNELS are few and channel-stationary. The two
mathematical tools that exist for that structure are (a) DIAGONAL
per-channel rescaling — commutes with everything elementwise,
folds exactly across linear seams, costs shift-alignment in the
engine — and (b) ORTHOGONAL rotation — spreads outliers provably
(incoherence), free for the engine (pure preprocessing), but only
available across LINEAR seams. C2+C3 admit exactly these two tools
in their sound forms and nothing model-specific. Every mechanism
agent U/V measured, everything the PTQ literature uses statically
(SmoothQuant migration, AWQ scaling, QuaRot/SpinQuant rotation),
and every natively-quantized checkpoint (QAT models arrive with
tame stats and use the degenerate constant vectors) are instances
of the SAME contract. Nothing in C1-C6 mentions Mistral, SwiGLU
widths, or layer counts.

## 3. Engineering design choices (each with its why)

D1 Static scales, frozen at calibration — NOT dynamic per-token.
   Why: scales are public statement data; dynamic scales are
   witness-dependent and would move quantization INTO the proved
   computation (new claim families, data-dependent range classes).
   Cost: models whose outliers are not channel-stationary fail C4.
   Evidence this is the right trade: SmoothQuant works statically
   on exactly these models; our own fold run took violations
   14,531 -> 3 with static vectors.
D2 Powers of two only. Why: requant stays shift-only (no
   multiplier witnesses), folds are fp-exact, the engine's digit
   machinery is untouched. Cost: up to 1 bit of per-channel range
   slack vs arbitrary scales — measured tolerable (agent U's s/t
   histograms are PoT by construction).
D3 Rotations d-axis only; f-axis outliers handled by diagonal
   scales. Why (the sharp algebraic fact): elementwise
   nonlinearities commute with DIAGONAL transforms only; a
   rotation cannot cross silu(g) ⊙ u, so the f-axis has no
   rotation seam — this is a theorem-shaped limitation, not a
   preference. The d-axis (residual stream in/out of the FFN) is a
   clean linear seam.
D4 Preprocessing outside the proof, gate inside the record. Why:
   keeps the engine at ZERO added cost for T2 and confines the T1
   cost to shift-alignment (agent V's pricing); the verifier's
   trust anchor is re-derivability (C3), not more circuit.
D5 Per-column accumulator alignment rather than widening every
   class to int16. Why: widening is a blanket 2x on witness digit
   rings for the widened sites (the clock and memory pay it
   everywhere); per-column shifts pay only where outliers live.
   Selective widening stays available per-site where V's
   measurements say shifts are insufficient.
D6 The v2 statement is not edited. Why: freeze discipline — v3 is
   a selector with its own digests/batteries; the 125M line and
   every landed benchmark remain reproducible forever.

## 4. Routes THROUGH the contract for a given checkpoint

R (rescale): T1 folds + margins. Measured on Mistral: formality
  yes (3 violations), quality no (+8.4 nats) — INSUFFICIENT ALONE
  for outlier-hostile checkpoints.
R+ (rescale + per-column classes): + C2 activation vectors at the
  outlier sites, per-column w_down scales. Agent V is measuring
  the loss this reaches and counting the engine bill. [SLOT: V's
  numbers land here.]
T (rotate + rescale): T2 on the d-axis + R+ on the f-axis. The
  literature's strongest static result class (QuaRot/SpinQuant
  W8A8-static ~lossless on Llama-class models [EXTERNAL, to be
  reproduced by our gate before any adoption]).
Q (QAT qualification): fine-tune the checkpoint to the contract,
  then qualify the RESULT as its own checkpoint. General but needs
  training compute + relabeling; the fallback when R+/T fail C4.
N (native): pick a checkpoint whose training already satisfies C4
  (§6: Gemma 4 QAT is the live 8B-class candidate). The contract
  is identical — N models just use constant vectors and no bridge.

## 5. Limitations (stated for the record; Victor asked)

L1 Static-scale boundary: per-token-dynamic native schemes
   (BitNet's a8 absmax-per-token) do not map onto C2; such models
   enter via route Q or a future dynamic-scale protocol version
   (out of scope here — it changes claim families).
L2 C4 can fail. The contract detects, it does not rescue; a
   checkpoint can be genuinely un-quantizable at static-8-bit.
L3 The f-axis has no rotation seam (D3): if a model's f-axis
   outliers defeat diagonal scales + widening, routes T/R+ are
   exhausted there.
L4 Quality budget (ii) is measured on ONE held-out distribution;
   fidelity elsewhere is not certified (same status as every
   calibration-based deployment; recorded, not hidden).
L5 Engine bill of C2 is not free: per-column shift alignment +
   exponent-vector statement data (~14 KB/layer/site at f=14336)
   + range-fact classes keyed per channel group. Agent V's memo
   carries the counted lane-days; the ruling should see them.
L6 MVP-2 (attention) inherits C1-C6 by construction, but softmax/
   RMSNorm integerization has its own spec (ATTENTION_INTEGER_
   SPEC.md) — this memo does not discharge it.
L7 The 125M freeze rows stay v2; dual maintenance until v3 lands
   (bounded by D6's selector discipline).

## 6. The model survey (Victor's question; searched 2026-08-25,
##    all [EXTERNAL], to be re-verified by our own C4 gate)

- **Gemma 4** (Google, April 2, 2026: E2B/E4B, 26B MoE, 31B dense;
  12B "Unified" June 3): **QAT checkpoints released June 5, 2026**,
  including "unquantized QAT" research checkpoints on HF
  (google/gemma-4-12B-it-qat-q4_0-unquantized) and a mobile
  variant trained with per-channel int2/int4 WEIGHTS + **int8
  ACTIVATIONS** — i.e., activation-int8 was in the training loop:
  exactly the distribution-taming our gate wants. THE prime
  8B-class candidate for route N. To verify on download: FFN dims
  (multiples of 128?), gate function (GeGLU -> one C5 registry
  member), the QAT recipe's activation-scale granularity, and the
  HF license gate (Gemma requires terms acceptance + token —
  needs Victor).
- **BitNet b1.58 2B4T** (Microsoft): the only fully NATIVE
  W1.58A8 open model; 2B only, per-token dynamic activation
  scales (L1) -> not the MVP vehicle; the watch-item for scale-ups.
  BitNet v2 (native a4 via Hadamard) independently confirms the
  rotation bridge's mechanism.
- **Qwen3-8B / Llama-3.1-8B / Mistral-7B**: standard bf16 SwiGLU
  pretrains; Mistral is MEASURED hostile and there is no
  architectural reason to expect the others differ (same emergence
  physics) — all are route R+/T customers.
- Industry PTQ practice (vLLM/llm-compressor W8A8): SmoothQuant +
  per-channel weights + DYNAMIC per-token activations — evidence
  that the static-activation contract is the strict variant; their
  1-3% claims lean on dynamism we exclude by D1.

## 7. Recommendation and what needs Victor

1. Adopt C1-C6 as the v3 contract draft (ruling AFTER agent V's
   pricing lands, so the R+ engine bill is on the table).
2. MVP-1 checkpoint strategy, two honest tracks: (N) Gemma-4-12B
   QAT-unquantized — needs the Gemma license acceptance + HF token
   [VICTOR], a GeGLU adapter extension + C5 member, then our C4
   gate run; if it qualifies cleanly this is the fastest honest
   8B-class MVP. (R+/T) Mistral-7B through the bridge — the
   hard-case generality demonstration; keep as track 2.
3. The W-6 SiLU member freeze from the Mistral run WAITS for this
   ruling (the member list depends on the adopted route).
4. Immediate work not blocked by the ruling: agent V (in flight),
   the Gemma download/config inspection (attempted; license gate
   status recorded in the ledger), M1/M2 engine rungs (synthetic
   witnesses, unchanged).
