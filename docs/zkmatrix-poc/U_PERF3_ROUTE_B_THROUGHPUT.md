# U-PERF3 lane YY — Route B (the hash-based line): proven tokens per second, honestly

Status: IN PROGRESS (opened 2026-09-02; round 11 of tranche U-PERF3,
lane YY, docs only, worktree wt-uperf3-yy). The sibling of lane TT's
`U_PERF3_THROUGHPUT_MODEL.md` (cited as S0 below) for the hash-based
line (`hashline/`, lane UU): the same yardstick, the same workload
definitions, the same model shapes, the same four labels. Where this
memo and S0 use the same word, it means the same thing; where a
number here differs from S0's lattice-line number, the two are meant
to be read side by side (§6).

Who this is for: a reader who knows what a cryptographic proof is
but has never opened this repository. Every term is defined where it
first appears. Every number carries one of four labels:

- **[MEASURED]** — a run happened on a named machine, on a named date.
- **[COUNTED]** — derived by arithmetic from measured pieces or from
  the code's own loops (the arithmetic is shown).
- **[MODEL]** — an estimate; the assumption is written next to it.
- **[EXTERNAL]** — someone else's claim; unverified by us.

Where a number is a [MODEL] built on another [MODEL], the cell says
so ("[MODEL on MODEL]"). Where two sources disagree, the memo says
which is newer and uses that one.

The question this memo answers (lane brief, PROGRESS_UPERF3.md round
11 "Lane YY"): the goal is **at least 50 proven tokens per second for
a 30B-parameter model on ONE GPU** (an H100 is allowed). Lane UU
built a hash-based prover of the same 12x512 statement and measured
it on the laptop's CPU. What does THAT line give, in those units, at
8B and 30B, on a laptop, a desktop board and an H100? What does
zero-knowledge — non-negotiable per Victor — add to it? What does
the 66.8 MB proof become under a different commitment scheme? And
what would a 50 tok/s design on this line have to look like?

## Sources (every number below traces to one of these)

| tag | file | what is taken from it |
|---|---|---|
| S0 | `docs/zkmatrix-poc/U_PERF3_THROUGHPUT_MODEL.md` (lane TT, 2026-09-02) | the workload definitions (§1.1-1.2), the 8B and 30B shapes (§1.3), MACs per token (§1.4), the witness sizes (§1.5), the hardware spec table and the composed-factor method (§3), the lattice line's tokens/s rows (§4.2-4.4), the competitor row (§6), the budget (§7.1) |
| S1 | `results/hashline_pass_12x512.md` (lane UU, 2026-09-02) | the measured row: 23.0 s p50 prove at 8 threads, 2.8 s verify, 66.8 MB, 1.56 GB, 1.26e9 proven MAC/s; the per-phase seconds; the proof-size anatomy; the parameters; the thread-scaling inversion; the tamper legs |
| S2 | `PROGRESS_UPERF3.md`, "Agent UU status (wt-uperf3-uu) — round 11" | the design of record (what is committed, which sumchecks, the LogUp form, the PCS shape); rung 4 (one layer at T = 512: 2.58 s with its phase split); rung 6 (the GPU estimate [MODEL]); the open items (a)-(f) |
| S3 | `hashline/src/pcs.rs`, `sumcheck.rs`, `layer.rs`, `mle.rs`, `ntt.rs`, `merkle.rs`, `bin/hashline.rs` | the loops this memo COUNTS: what each phase does per element, per row, per column; what the prover clock includes |
| S4 | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` §2-3 | the two channels side by side; the B row and its caveats; the "5-15x" hardware note this memo replaces for this mix |
| S5 | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md` §4 (family (d)), "Addendum 2026-08-11 — Attestable", "Conversion note 2026-08-18" | the FRI / STIR / WHIR / BaseFold / Brakedown rows (WHIR: 63 KiB, 360 us at degree 2^22, 100 bits [abstract verified there]); the competitor's claim and the 3.1e10 MACs-per-token conversion |
| S6 | `docs/zkmatrix-poc/TARGET_CONTRACT.md` §3-4 and Amendment A1; `docs/zkmatrix-poc/ZK_GAP_OPTIONS.md` §6 | what the clock covers; the hardware line; the ZK rule and the P0-P3 private-set modes; the accumulation asymmetry (weights are re-proven every pass, activations are fresh) |
| S7 | `docs/zkmatrix-poc/START_HERE.md` §2, §6 | the plain-language state (cross-checks only) |
| L1 | Ames, Hazay, Ishai, Venkitasubramaniam, "Ligero" (CCS 2017) | the interleaved-code commitment and its zero-knowledge form: random padding of every encoded row, mask rows for every linear check [EXTERNAL] |
| L2 | Golovnev, Lee, Setty, Thaler, Wahby, "Brakedown" (ePrint 2021/1043) | the linear-time, sqrt-size multilinear PCS; the tensor-form opening; its remark that ZK follows by the Ligero techniques [EXTERNAL] |
| L3 | Chiesa, Forbes, Spooner, "A zero knowledge sumcheck and its applications" (ePrint 2017/305); Xie et al., "Libra" (CRYPTO 2019) | zero-knowledge sumcheck by a committed low-degree masking polynomial [EXTERNAL] |
| L4 | Arnon, Chiesa, Fenzi, Yogev, "WHIR" (ePrint 2024/1586) and "STIR" (ePrint 2024/390); Ben-Sasson et al., "FRI" (ICALP 2018); Zeilberger, Chen, Fisch, "BaseFold" (ePrint 2023/1705) | the polylog-size multilinear PCS class and its stated complexities [EXTERNAL] |
| L5 | Xie, Zhang, Song, "Orion" (ePrint 2022/1010) | hiding the column openings of a Brakedown-class commitment inside an inner proof [EXTERNAL] |
| L6 | Papini, Haböck, "Improving logarithmic derivative lookups using GKR" (ePrint 2023/1284) | the LogUp-GKR form that drops the committed helper columns [EXTERNAL] |
| HW | the vendors' spec sheets as copied in S0 §3.2 (RTX 4070 Laptop, RTX 4090, RTX 5090, H100 SXM5 / PCIe); Intel's Core Ultra 9 185H page (memory: LPDDR5x-7467 / DDR5-5600) | SM counts, clocks, memory bandwidths, board power [EXTERNAL, spec sheet]; none measured here |

## 0. The answer in one paragraph

The only Route-B proof ever timed is lane UU's: 12 layers x 512
tokens of the 125M model, **23.0 s of prover time on the laptop's CPU
alone** (8 threads; no GPU code exists), 2.8 s to verify, 66.8 MB of
proof, NOT zero-knowledge [MEASURED, S1] — 22 proven tokens per
second OF THAT SMALL MODEL, feed-forward blocks only. Counted from
the code (§2), 9.6% of that time (the weight commitment) is
per-model and cacheable, 6.6% (the weight side of the matmul
sumchecks and of the commitment opening) is per-proof and LINEAR in
the weight count, and 83.8% is the activation side, linear in tokens
x width. Scaling each phase by its counted size, the prototype at 8B
is a **~1.0 tokens/s system for 512-token prefill on the laptop CPU
and ~0.007 tok/s for batch-1 decode; at 30B, 0.33 and 0.0017**
[MODEL from the measured constants] — the same two-workload split as
the lattice line, for the same reason: at one token per proof the
weights are 99.9% of the witness and their opening is paid in full
per token. The hardware factor for THIS mix (NTT, hashing, streaming
reductions; memory-bound) is 5-15x to the laptop's own GPU [MODEL
until lane XX measures], 15-75x to a 4090-class board and 25-180x to
an H100 [MODEL on MODEL, §3] — much larger factors than the lattice
line's 2-8x because the measured row is a CPU row and every phase is
device-native. That puts Route B on one H100 at **8-60 tok/s for 30B
prefill and 0.04-0.3 tok/s for 30B decode, FFN-only, without zero
knowledge** (§6); the spec-sheet floor for the same proof (§7) is
~4-11 s per 512-token proof (47-138 tok/s), dominated by hashing 311
GB of encoded activations. Zero knowledge (§4) costs +2-8% in the
activations-private mode P1 [COUNTED from the Ligero/Libra
constructions] but is STRUCTURALLY expensive in the weights-private
modes P2/P3: a cached hash-based weight commitment reveals 256 of its
encoded columns per proof, and after ~65 proofs the weights are
recoverable by linear algebra [COUNTED], so under P2/P3 the weights
must be re-committed with fresh randomness on every proof — +9.6% at
125M, +44% at 8B x 512, +54% at 30B x 512 on the laptop, and a
hashing floor of 7-23 s per proof at 30B on an H100 that by itself
is 70-230% of the 10.2 s per-proof budget. The 66.8 MB proof is the
sqrt-size class (0.6 GB per 8B x 512 proof, 1.5 GB per 30B x 512
proof, 0.7 GB per 30B DECODE token); a WHIR/STIR-class PCS swap cuts
it 30-100x at 0.9-1.6x the prover's commit + open phases [MODEL from
stated complexities, §5]. **Verdict (§7): 50 tok/s at 30B on one
H100 is reachable on Route B under the counted assumptions ONLY for
512-token prefill or batched proving, FFN-only, in modes P0/P1, and
only in the upper half of the hardware range (>= ~90x over the
laptop CPU as built) — it hinges on lane XX's GPU factor and on the
device's sustained hash rate (>= ~30 GB/s). Batch-1 decode at 50
tok/s is NOT reachable: the linear weight opening's floor at 30B is
25-60 ms per proof against a 20 ms budget [COUNTED]; batched decode
at >= 8 requests is the product shape that could. Under P2/P3
(weights private), as counted, no cell reaches 50 tok/s.**

## 1. Workloads and MACs per token

Everything in this section is S0 §1's, restated so this memo stands
alone; the shapes and MACs are copied, not re-derived.

### 1.1 Terms (S0 §1.1, with the Route-B additions)

- **MAC**: one 8-bit integer multiply-accumulate; a model with P
  weights costs about P MACs per token in its matmuls.
- **Token / prefill / decode**: one text position; a whole prompt of
  T tokens in one forward pass; one new token per forward pass.
- **Proof / statement / witness**: one prover run; "these committed
  weights, applied to these T tokens, produced these outputs"; every
  number the proof is about.
- **Weight side vs activation side**: the weights are the same for
  every proof of a model; the activations differ per proof and grow
  with T. `hashline/` commits them as separate commitments — W
  (weights), A (activations, inputs and outputs), H (the LogUp helper
  columns, which are activation-side) — and opens each once per
  layer (S2, design of record).
- **Field element**: Route B's unit. Every committed value is one
  element of the Goldilocks field (p = 2^64 - 2^32 + 1, 8 bytes);
  int8 weights and activations are embedded one per element; helper
  values are extension elements (two per helper). Costs of the
  commitment and opening phases scale with element counts, not
  MACs; the sumcheck phases scale with table sizes (§2).
- **Proven MAC/s**: MACs in the statement divided by the prover's
  wall-clock seconds (S5 conversion note; S4 §3).
- **The prover clock**: per the contract (S6 §3) it starts with the
  committed model and the tokens in memory and stops when the proof
  bytes exist; it EXCLUDES the one-time weight commitment and
  INCLUDES witness inference. UU's 23.0 s INCLUDES the three
  per-layer commitments (the weights recommitted every proof) and
  EXCLUDES the witness load + integer chain (0.9-1.5 s, S1). On the
  contract's clock the row is therefore ~23.0 - 2.2 + ~1.0 = ~22 s
  with a cached weight commitment; this memo uses the measured 23.0
  s and says where the 2.19 s moves (§2).

### 1.2 The three workloads (S0 §1.2, verbatim in substance)

| workload | tokens per proof | weight side paid | activation side paid | tokens/s |
|---|---:|---|---|---|
| **batch-1 decode** | 1 | once per proof = once per TOKEN | for one position | `1 / cost(T=1)` |
| **batch-T prefill** | T (512 in the contract, S6 §3) | once per proof = once per T tokens | for T positions | `T / cost(T)` |
| **pipelined / batched** | T per proof, several proofs in flight, or B requests decoded together | as prefill | as prefill | `T / (busiest resource's time per proof)` |

`cost(T) = W + A(T) + F`: W the per-proof weight-side work, A(T) the
activation-side work (linear in T above a small floor), F the fixed
per-proof overhead. Route B has no CRS expansion and no device
initialisation; F is the eq-table builds and the tiny sumchecks
(milliseconds at T = 1, §2.4). Multi-request batching at B requests
is the same amortisation as prefill with T = B.

### 1.3 The two model shapes (S0 §1.3, copied)

**8B**: Mistral-7B-v0.1 — L = 32 layers, d = 4096, FFN hidden f =
14336 [EXTERNAL, model card]. **30B stand-in**: the public
Gemma-3-27B architecture — L = 62, d = 5376, f = 21504, 27e9
parameters [EXTERNAL, model card]; if the real 31B model is 15%
larger, every 30B cost row scales by ~1.15x [MODEL]. Route B handles
non-power-of-two widths by block structure, not zero padding (S2:
d = 768 = 3 x 2^8 at 125M); this memo counts f = 14336 = 7 x 2^11
and f = 21504 = 21 x 2^10 the same way, so no padding term appears
(the lattice line's 12.5% / 52% padding, S0 §1.5, does not apply).

### 1.4 MACs per token [COUNTED from the shapes; S0 §1.4, copied]

| term (per token) | 8B | 30B stand-in |
|---|---:|---:|
| FFN (gate, up, down) = `L x 3 x d x f` | **5.64e9** | **2.15e10** |
| attention projections | 1.34e9 | 4.10e9 |
| output head | 1.3e8 | 1.41e9 |
| dense total | 7.11e9 | 2.70e10 |
| total incl. attention scores at context | 7.2-8.2e9 | 2.9-3.5e10 |
| FFN share | 69-78% | 61-75% |

The yardstick stays S5's: **50 tok/s at 30B = 50 x 3.1e10 = 1.55e12
proven MAC/s = 20 ms per token; 10.2 s per 512-token proof.**

**The FFN-only caveat, restated.** The built and measured Route-B
statement is the FFN only (S1: "NOT proven: attention; the seams
between layers"); every tokens/s number in §6 is an **FFN-proven
token** (5.64e9 MACs at 8B, 2.15e10 at 30B). Attention adds 1.3-1.6x
MACs and an unmeasured multiple of proof MASS (the softmax chain is
lookups and range facts, not matmuls; S0 §1.4 prices it at ~3.5x per
layer for the lattice line [MODEL]); on Route B its cost is
unmeasured until an attention layer is proven there. Two further
gaps shared with the lattice tower (S1): X and the weights are
declared int8, not range-proven (UU's item (e): +15-20% [MODEL]);
the layer seams are not proven.

### 1.5 The Route-B witness at each workload [COUNTED from S3 `layer.rs::Layout`]

Per layer, the three commitments hold (T tokens, width d, hidden f):
W = 3 d f elements (Wg, Wu, Wd); A = T (7 f + 3 d) elements (g8, rg,
a8, u8, ru, h8, rh — seven T x f columns — plus X, z, rd in d/256
blocks of T x 256); H = T (6 f + 2 d) elements (three T x f helper
columns and d/256 helper blocks, each as a real and an imaginary
base column). Per token-layer the activation side is therefore
**13 f + 5 d** elements.

| group | 125M, T = 512 (per layer / per pass) | 8B, T = 512 | 8B, T = 1 | 30B stand-in, T = 512 | 30B, T = 1 |
|---|---:|---:|---:|---:|---:|
| W (elements) | 4.72M / 5.66e7 | 1.76e8 / **5.64e9** | 5.64e9 | 3.47e8 / **2.15e10** | 2.15e10 |
| A (elements) | 8.52M / 1.02e8 | 5.77e7 / 1.85e9 | 3.6e6 | 8.53e7 / 5.29e9 | 1.03e7 |
| H (elements) | 7.08M / 8.49e7 | 4.82e7 / 1.54e9 | 3.0e6 | 7.16e7 / 4.44e9 | 8.7e6 |
| A + H per token (all layers) | 30,464 x 12 = 3.66e5 | 6.62e6 | 6.62e6 | 1.90e7 | 1.90e7 |
| weight share of the committed witness | 23% | 62% | **99.9%** | 69% | **99.9%** |
| encoded bytes per layer at rate 1/4 (32 B per element; what the commit phase writes and hashes) | 650 MB | 9.0 GB | 5.7 GB | 16.1 GB | 11.1 GB |

Two facts to carry: (1) at T = 1 the proof is a proof about the
weights, exactly as on the lattice line (S0 §1.5); (2) Route B's
per-model store is **one byte per weight** if kept as int8 (5.6 GB at
8B, 21.5 GB at 30B — 8x smaller than the lattice line's digit store,
45 / 172 GB), but its CACHED commitment (the encoded matrix the
opening reads columns from) is 25 bytes per weight at rate 1/4 —
141 GB at 8B, 538 GB at 30B [COUNTED] — which sets the per-proof
byte question of §2.3 and §7.

## 2. The per-proof cost anatomy for Route B: per-model vs per-proof

(pending)

## 3. The hardware factor for THIS mix, as a range

(pending)

## 4. The zero-knowledge surcharge [MODEL, mandatory]

(pending)

## 5. The proof-size lever

(pending)

## 6. The tokens/s table, next to the lattice line

(pending)

## 7. The competitor row, and what a 50 tok/s Route-B design must have

(pending)

## What is not known

(pending)
