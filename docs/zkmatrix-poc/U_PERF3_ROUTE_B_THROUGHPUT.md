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

"Per-model" means work that depends only on the weights and could
be done once at export time and cached; "per-proof" means work that
depends on the inputs or on the per-proof random challenges. The
contract's clock (S6 §3) excludes committing the weights, so
per-model work is legitimately off the clock — IF the protocol
separates it. Unlike the lattice line (S0 §2), Route B DOES separate
it by construction: the weight commitment is a hash of the encoded
weights and nothing else, and the transcript merely absorbs its root
(S3 `layer.rs`, "commit W"). What it does NOT separate is the
opening: every proof recomputes a fresh random row-combination of
the entire weight matrix (§2.3).

### 2.1 The measured pass, phase by phase, with what each loop does [MEASURED s from S1; loops COUNTED from S3]

UU's 8-thread run 1, summed over the 12 layers (the phases sum to
22.88 s against the 23.0 s p50 wall):

| phase | s | share | what the code does, per element [COUNTED] | per-model or per-proof | side | scales with |
|---|---:|---:|---|---|---|---|
| commit W | 2.19 | 9.6% | `pcs::commit`: per row of n = 2^14 elements an inverse NTT (2^14) then a forward NTT (2^16) — 39 butterflies per element; blake3 over each of the 4n encoded columns — 32 hashed bytes per element; a Merkle tree of 4n leaves | **per-model** (nothing in it depends on the proof) | weight | N_W = 3 d f per layer; 38.7 ns per element at 8T |
| commit A | 3.98 | 17.4% | the same loops over N_A = T (7 f + 3 d) | per-proof | activation | 38.9 ns per element |
| helpers + commit H | 4.58 | 20.0% | the LogUp helper columns: 2 extension subtractions and a batched inversion per lookup pair (7.08M Fp2 inversions per layer, ~15 ns each = 0.11 s of the 0.38 s per layer), then the same commit loops over N_H = T (6 f + 2 d) | per-proof (alpha-dependent) | activation | 53.9 ns per committed element |
| matmul g/u | 0.77 | 3.4% | `eval_many` of g8, rg, u8, ru at the claim point (4 T f multiply-adds); `fold_rows_i8(X)` (T d); `fold_cols_i8(Wg)`, `(Wu)` (2 d f); an 8-round sumcheck over six 256-entry tables (negligible) | per-proof | mixed: weight 41% (2 d f of 2 d f + 4 T f + T d) | d f and T f |
| matmul d | 0.60 | 2.6% | `eval_many` of z, rd (6 T x 256); `fold_rows_i32(h8)` (T f); `fold_cols_i8(Wd)` (d f); an 11-round sumcheck over two 2048-entry tables; three `fold_cols_base` over the Wd blocks AGAIN for the terminal values (d f) | per-proof | mixed: weight 63% | d f and T f |
| zero-check 20 | 4.50 | 19.7% | `sumcheck::prove` over 13 extension tables of 2^20, degree 4: per pair the constraint is evaluated at 5 points (~22 Fp2 multiplications each) and 13 tables are folded; ~1.3e8 Fp2 multiplications per layer; 27.5 ns per table-entry | per-proof | activation | T f |
| zero-check 17 | 2.30 | 10.1% | the same over 15 tables of 2^17 (3 eq tables + X, z, rd, hz in 3 blocks); measured **97 ns per table-entry — 3.5x the 20-variable rate**, an untuned per-round overhead at the smaller size (this memo scales it at its own constant, the pessimistic choice) | per-proof | activation | T d |
| PCS openings | 3.96 | 17.3% | `fold_rows_multi`: (k + 1) clear row-combinations per commitment (k = the number of distinct column-weight groups: W 2, A 2, H 3, plus one proximity combination), computed by reading the systematic positions of the encoded matrix at stride 4 and multiplying every element by k + 1 extension scalars: 3 x 4.72M + 3 x 8.52M + 4 x 7.08M = 68.0M multiply-adds per layer, 4.85 ns each at 8T (~40 ns per thread-op: strided reads, branches on zero — ~10x a tuned inner loop); then 256 column reads of m entries and 16-digest Merkle paths | per-proof | mixed: weight 21% | (k + 1) x N per commitment |
| verify (off the clock) | 2.8 | — | re-encode the 10 clear vectors (20 NTT pairs), hash 3 x 256 columns, 256 x (3 x 288 + 3 x 520 + 4 x 432) = 1.06M multiply-adds per layer, the LogUp table side | — | — | (k + 1) x 256 x m, plus 4n log n per clear vector |

Cross-check: rung 4's one-layer run at T = 512 (S2: commit W 0.22 /
A 0.44 / H 0.54 / g,u 0.11 / d 0.07 / zc20 0.52 / zc17 0.28 /
openings 0.41 = 2.58 s) agrees with the 12-layer sums divided by 12
(0.18 / 0.33 / 0.38 / 0.06 / 0.05 / 0.38 / 0.19 / 0.33) within
layer 0's thread-pool warm-up.

### 2.2 The split at 125M [COUNTED from the table above]

Attributing the two mixed matmul phases by their multiply-add counts
(g/u: weight 3.15M of 7.73M; d: weight 3.15M of 4.99M) and the
openings by theirs (W 14.2M of 68.0M):

| | seconds of 22.88 | share | constant |
|---|---:|---:|---|
| **per-model** (commit W) | **2.19** | 9.6% | 38.7 ns per weight |
| **per-proof, weight side** (g/u folds 0.31 + d folds 0.38 + W opening 0.82) | **1.52** | 6.6% | 26.8 ns per weight = 4.33 multiply-adds per weight (4/3 in the sumcheck folds: Wg, Wu once, Wd twice; 3 in the opening) at 6.2 ns each |
| **per-proof, activation side** (everything else) | **19.17** | 83.8% | 102 ns per committed activation element (1.87e8 elements per pass) |

So at 12x512 the weights are 16% of the prover's time (10% cacheable,
7% not) and the activations 84%. With the weight commitment cached
per model the row is 20.7 s (§1.1: ~22 s on the contract's clock,
which adds the ~1.0 s integer chain).

### 2.3 The per-proof weight side at 8B and 30B: operations and bytes [COUNTED]

**Operations.** Per weight per proof, as built: 4/3 + 3 = 4.33
extension-by-base multiply-adds (each = 2 Goldilocks multiplications
+ 2 additions). The floor for this protocol shape is 3-4: one
sumcheck fold (if the Wd terminal pass reuses the first fold's
per-block outputs) plus 2-3 opening combinations (Brakedown's PCS
sends a testing combination and an evaluation combination, L2 —
k + 1 >= 2; 3 as built because Wg/Wu and Wd are opened at two
points).

| | 8B | 30B stand-in |
|---|---:|---:|
| weights per proof (N_W) | 5.64e9 | 2.15e10 |
| multiply-adds per proof, floor / as built | 1.7e10 / 2.4e10 | 6.5e10 / 9.3e10 |
| Goldilocks multiplications, floor / as built | 3.4e10 / 4.9e10 | 1.3e11 / 1.9e11 |

**Bytes moved per proof.** As built, the folds read the int8 weights
(4/3 N_W bytes: 7.5 GB at 8B, 29 GB at 30B) and the opening reads the
encoded matrix's systematic positions at stride 4 — 8 bytes used per
32-byte cache line, so 32 N_W bytes of line traffic: **180 GB at 8B,
688 GB at 30B** [COUNTED from `fold_rows_multi`]. Fused (one pass
reading the int8 weights once and updating both the sumcheck fold
and the row-combinations): **N_W bytes — 5.6 GB at 8B, 21.5 GB at
30B** — plus the 256 column decommitments per commitment (256 x m x
8 B per layer: 88 MB at 8B, 336 MB at 30B at the §5 column counts)
and the Merkle paths (negligible). The column decommitments are read
from the per-model cache (§1.5: 141 / 538 GB at rate 1/4), which
therefore must be stored COLUMN-major (one contiguous read per
column); as built the store is row-major (`encoded[i * nn + j]`), so
each column is m random 8-byte reads [COUNTED from S3] — fine in RAM
at 125M, not from NVMe at 30B.

**Seconds.**

| per-proof weight side | 8B | 30B | label |
|---|---:|---:|---|
| at the measured constant (26.8 ns per weight; laptop 8T, as built) | **151 s** | **576 s** | [MODEL from MEASURED] |
| at a tuned CPU rate (1-1.5 ns per multiply-add at 8T; 4-6 ns per weight) | 23-34 s | 86-130 s | [MODEL] |
| on one H100 (§7.2: the weights HBM-resident, tuned kernels, cache columns over PCIe 5) | 10-20 ms | **25-60 ms** | [COUNTED on spec sheet] |

The as-built and the tuned constants are 5-7x apart on the CPU and
the tuned-CPU-to-H100 count is a further ~1,000-3,000x (on the spec
sheets an H100 has ~100x the laptop CPU's peak 64-bit-multiply rate
and ~30x its memory bandwidth; the "tuned CPU" row itself is only
~5% of that CPU peak, and the H100 floor assumes its peak is reached
by a kernel that does not exist) — the same shape of
disagreement lane TT found between the routes memo's model and the
spike's measurement (S0 §2.4), and for the same reason: the counted
number assumes a streaming kernel that has not been written. Lane
XX's port of the row-combination (its rung 4) is the measurement
that collapses it.

**The per-model term, for the record.** Commit W at 38.7 ns per
weight: 218 s at 8B, 832 s at 30B, once per model on the laptop CPU
[MODEL from MEASURED], plus the write of the 141 / 538 GB cache. If
the cache is not kept (or cannot be — §4 shows the weights-private
modes forbid reusing it), the same seconds land on EVERY proof.

### 2.4 The activation side at 8B and 30B, at T = 512 and T = 1 [MODEL from MEASURED constants]

Each activation-side phase scaled by its counted driver (§2.1) from
the 125M per-token-layer counts (§1.5) to the 8B and 30B shapes and
layer counts. Factors per pass: 8B — A x18.1, H x18.2, T f x18.7,
T d x14.2; 30B — A x51.8, H x52.2, T f x54.3, T d x36.2 [COUNTED].

| activation phase (12x512 s -> scaled) | 8B x 512 | 30B x 512 |
|---|---:|---:|
| commit A (3.98 x A) | 72 | 206 |
| helpers + commit H (4.58 x H) | 83 | 239 |
| matmul activation folds and claim evaluations (0.68 x ~18 / ~51) | 12 | 35 |
| zero-check 20-class (4.50 x T f) | 84 | 244 |
| zero-check 17-class (2.30 x T d, at its own pessimistic constant) | 33 | 83 |
| activation openings (3.13 x A) | 57 | 163 |
| **A(512), laptop CPU 8T** | **341 s** | **970 s** |
| A(1) = A(512) / 512 | 0.67 s | 1.9 s |
| F (eq tables, the tiny sumchecks; at T = 1 every table is f-sized) | ~0.01-0.1 s | ~0.01-0.1 s |

Memory at these shapes [COUNTED from §1.5]: the prover holds one
layer's encoded matrices (9.0 GB at 8B, 16.1 GB at 30B at rate 1/4)
plus the 13 zero-check tables (1.5 / 2.3 GB) — the 8B pass would
just fit the 15 GB laptop, the 30B pass would not; both fit a 24 GB
board per layer, an H100 with room to spare. The per-model weight
cache lives off-device in either case.

### 2.5 Summary: the per-proof cost model, laptop CPU 8T, prover clock

| design | per-model (off the clock) | W per proof | A(512) | A(1) + F | cost(512) | cost(1) = per decode token |
|---|---|---:|---:|---:|---:|---:|
| Route B as built, 8B | commit W 218 s once; 141 GB cache [MODEL] | 151 [MODEL from MEASURED] | 341 | ~0.8 | **492** | **~152** |
| Route B as built, 30B | 832 s once; 538 GB cache | 576 | 970 | ~2 | **1,546** | **~578** |
| Route B, the weight loops tuned [MODEL] | same | 23-34 / 86-130 | same | same | 364-375 / 1,056-1,100 | 24-35 / 88-132 |
| for comparison, the lattice line (S0 §2.5), 8B, laptop GPU: (a) built | none separable | 370-409 | 250-491 | ~2 | 620-910 | 372-411 |
| lattice (c) two-tier + preprocessing, routes constants | ~20 min 1T CPU | 2-10 | 90-145 | 2-3 | 92-155 | 4-13 |
| lattice (c') same, spike-measured constants | same | 60-330 | 150-240 | 2-3 | 210-570 | 62-333 |

Reading: on the laptop's CPU ALONE, Route B as built sits at 8B
prefill between the lattice line's (c) and (c') rows — which needed
the GPU — and at decode in the (c') class; its structure is the
lattice line's (c) structure (a cached weight commitment, a linear
per-proof weight pass, an activation side linear in T) obtained
without a two-tier opening, because a hash commitment's opening is
linear by nature. What it does not have is any per-proof weight-side
term below linear — the same R1 wall as S0 §7.2.

### 2.6 The levers UU named, as multipliers [MODEL]

- **(d) cache the weight commitment per model**: -9.6% at 125M,
  -218 s at 8B x 512 (already assumed in §2.5); forbidden under
  P2/P3 (§4.4).
- **(f) LogUp-GKR** (L6): drop the H commitment (20% of the wall) for
  a GKR over the fractions; UU: "half of it recoverable" -> ~-10%.
- **(e) X/W range lookups** (closing the M3 gap on this line): +15-20%.
- the zero-check-17 constant tuned to the 20-variable rate: -7%.
- the weight loops tuned (§2.3): -26% at 8B x 512, -84% at 8B decode.
- witness inference on the clock (S6 §3): +1.0 s at 125M; the 8B
  int8 chain is 2.9e12 MACs, ~10-30 s on 8 CPU threads, milliseconds
  on a tensor-core GPU [MODEL].

## 3. The hardware factor for THIS mix, as a range

No Route-B number has been measured on anything but the laptop's
CPU at 8 threads (S1). This section says what the work is made of,
copies the spec sheets S0 used, and composes a factor per machine
as a range with its reasoning. Lane XX's port is the measurement
that replaces the first column; until it lands every device cell in
§6 is [MODEL] on top of the CPU row.

### 3.1 What kind of work the pass is [MEASURED shares from S1; kinds COUNTED from S3]

| kind | phases | share of the 23.0 s | what bounds it on a CPU | what bounds it on a GPU |
|---|---|---:|---|---|
| **NTT** (Reed-Solomon encoding of every committed row: 39 butterflies per element, rows of 2^14 -> 2^16 elements = 128-512 KB, L2-resident) | commit W / A / H | ~35-40% [MODEL split of the 47% commit share: the hash is ~10-20% of a commit on the CPU] | 64-bit modular multiplies (scalar `mulx` + the Goldilocks reduction); ~7 ns per butterfly per thread as built | memory bandwidth (a batched small-NTT kernel reads and writes each row a few times) — the textbook GPU kernel |
| **blake3 hashing** (32 bytes per committed element; the Merkle tree adds 1/m) | commit W / A / H; the transcript | ~5-10% [MODEL] | ALU; ~1-3 GB/s per core on 2-4 KB inputs [MODEL] | ALU (compute-bound); tens of GB/s per board [MODEL, no source in this repository — lane XX rung 2 measures it] |
| **sumcheck rounds** (map-reduce over 13-15 extension tables; ~100 Fp2 multiplications per pair; the tables halve each round) | zero-checks 20 and 17; the two matmul sumchecks' rounds | 30% | extension multiplies (3 Goldilocks products each) and the per-round table pass; 27.5 ns per table-entry at 8T | a reduction kernel: bandwidth for the table passes, ALU for the constraint body — the standard GPU sumcheck |
| **streaming reductions** (row-combinations `fold_rows_multi`, the matmul folds `fold_rows/cols_i8/i32`) | PCS openings; matmul g/u and d | 23% | as built, strided 32-byte-line reads for 8 used bytes and per-element branches: 4.85-6.2 ns per multiply-add at 8T, ~10x from a tuned loop | pure bandwidth: 1 byte (int8 weights) or 8 bytes (activations) read per multiply-add — GEMV-class |
| other (batched inversions for the helpers ~0.5%; column gathers and Merkle paths; the ~130 Fiat-Shamir squeezes per layer, microseconds each) | | ~2% | | the serial fraction is < 0.1% [COUNTED]: no spine problem (S0 §5.4's concern does not arise here) |

Every kind is device-native, there is no phase that must stay on the
host, and a layer's whole working set fits one device (650 MB at
125M; 9-16 GB at 8B/30B, §2.4) — unlike the lattice line's pass,
half of which is CPU-bound by measurement (S0 §3.1). That is why
the factors below are much larger than S0's 2-8x: the Route-B row is
a CPU-only row of device-shaped work, and the GPU port is the first
step, not a refinement.

### 3.2 The parts [EXTERNAL, spec sheet; copied from S0 §3.2 with the laptop CPU added]

| part | SMs / cores | boost clock | SM x GHz (integer ALU proxy) | memory | memory bandwidth | host link | board power |
|---|---:|---:|---:|---:|---:|---|---:|
| Core Ultra 9 185H (the measured CPU) — 6 P + 8 E + 2 LP cores, 22 threads; the row uses 8 threads | 16 cores | P-cores to 5.1 GHz spec; sustained ~3-4 [MODEL] | ~1 x 64-bit multiply per P-core cycle: ~2-3e10 mul/s at 8T | 15 GB of the box's RAM | LPDDR5x-7467: 120 GB/s (DDR5-5600: 90 GB/s) | — | 45-115 W package |
| RTX 4070 Laptop (AD106) | 36 | 2.18 spec; ~1.5-2.0 sustained at 55-70 W [MODEL] | 54-72 | 8 GB | 256 GB/s | PCIe 4 x8; 11.7 GB/s measured (S0 S14) | 55-70 W |
| RTX 4090 (AD102) — "one desktop board" | 128 | 2.52 | 323 | 24 GB | 1,008 GB/s | PCIe 4 x16, ~25 GB/s | 450 W (the contract's line) |
| RTX 5090 (GB202) | 170 | 2.41 | 410 | 32 GB | 1,792 GB/s | PCIe 5 x16, ~50 GB/s | 575 W — over the contract's line |
| H100 SXM5 | 132 | 1.98 | 261 | 80 GB HBM3 | 3,350 GB/s | PCIe 5 x16 / NVLink | 700 W |
| H100 PCIe | 114 | 1.76 | 200 | 80 GB HBM2e | 2,000 GB/s | PCIe 5 x16 | 350 W |

The 64-bit modular multiply at the heart of every kind here is
emulated on a GPU as four 32-bit wide multiplies plus adds in every
lane the same way (the standard Goldilocks kernels of the open
STARK libraries [EXTERNAL, project code; not verified here]); so
SM x GHz is the right proxy for the hash and constraint parts, and
memory bandwidth for the NTT, reductions and table passes. As S0
§3.2 notes, on scalar integer work an H100 is NOT faster than a
4090; its advantages for THIS mix are bandwidth (3.3x a 4090) and
capacity (80 GB: the only board where the 30B int8 weights, 21.5 GB,
and a layer's 16 GB working set are both resident).

### 3.3 The composed factor, as a range with its reasoning [MODEL]

The laptop CPU row as built is the base. Its own headroom matters:
the streaming loops run ~10x below a tuned CPU loop (§2.1), the
commit's NTT ~2-3x [MODEL] — so part of any first "GPU factor" is
really a tuning factor, and the range below is over the row AS
MEASURED, not over a tuned CPU.

| machine | factor over the laptop CPU row (as built) | low end means | high end means |
|---|---:|---|---|
| **the laptop's own GPU** (RTX 4070 Laptop) | **5-15x** [MODEL; lane XX measures] | only the commits (NTT + hash) and the sumcheck rounds ported; the openings' gathers and the folds stay CPU-side | all four kinds on the device at UU's per-kernel 10-30x (S2 rung 6: 1.5-2.5 s per 12x512 pass = 9-15x), Amdahl over the measured shares |
| **one desktop board** (4090 class, <= 450 W) | **15-75x** [MODEL on MODEL] | the laptop-GPU port x3: bandwidth-bound (3.9x the laptop GPU's), weights fed over PCIe per layer | x5: the compute-bound parts (hashing, constraint bodies) at 4.5-6x SM-GHz, everything device-resident |
| **one H100 SXM** | **25-180x** [MODEL on MODEL] | x5 over the laptop GPU: hash-bound (3.6-4.8x SM-GHz) with the bandwidth-bound parts partly hidden behind it | x12: bandwidth-bound throughout (13x), weights and working set resident, PCIe only for the cache columns |
| (one H100 PCIe) | 15-120x | | |

Central values used in the prose of §6-7: 4090 ~35x, H100 ~70x.
There is no measured point anywhere in this table; the honest
statement of §6 is that every device cell is the CPU row divided by
one of these ranges.

### 3.4 The measured inverted thread scaling, and why it does not transfer

S1: 8 threads 23.0 s, 16 threads 32.2 s, 22 threads 37-39 s; verify
2.8 s -> 5.7 -> 8 s. Reproduced, not chased. The hypotheses recorded
there [MODEL]: (i) the hybrid part's E-cores are weak on the
64x64 -> 128 multiply the Goldilocks reduction uses and, under the
laptop's package power limit, adding them lowers the P-cores'
clocks; (ii) rayon's static chunking gives every thread an equal
share, so in each of the ~130 parallel regions per layer the
slowest E-core sets the finish time and the P-cores wait at the
barrier; (iii) WSL2's vCPU scheduling. None of these mechanisms
exists on a GPU: the lanes are homogeneous, the 64-bit multiply is
emulated identically in every lane, work is split into thousands of
hardware-scheduled blocks with no per-chunk barrier at the thread
level, and there is no core asymmetry induced by a power limit. The
inversion is an artefact of this laptop part, not a property of the
workload. Two consequences this memo carries: the 8-thread row is
the ONLY CPU row (no 22-thread "improvement" exists to scale from),
and a CPU core-count scaling is not a factor this memo uses (a
32-core server at 4x the threads would be [MODEL] 2-4x, not 4x —
S0 §3.3's k_c, applied only if a CPU row is ever wanted).

### 3.5 The per-proof memory floor for Route B (matters for decode)

Every Route-B proof reads the weights once (§2.3), int8, one byte
each — 8x less than the lattice line's digit store (S0 §3.4):

| weight store | size | laptop (15 GB RAM, 8 GB VRAM) | RTX 4090 (24 GB, ~25 GB/s link) | H100 SXM (80 GB, 3.35 TB/s) |
|---|---:|---|---|---|
| 8B, int8 | 5.6 GB | RAM-resident: ~0.1 s at ~50 GB/s effective; VRAM-resident: 22 ms | resident: 5.6 ms | resident: **1.7 ms** |
| 30B stand-in, int8 | 21.5 GB | does not fit | resident only WITHOUT the layer's 16 GB working set (§2.4): streamed from the host, **0.86 s** per proof | resident with 58 GB to spare: **6.4 ms** |
| the per-model encoded cache at rate 1/4 (the column decommitments' source), 8B / 30B | 141 / 538 GB | NVMe | NVMe or host RAM | host RAM (a server) or NVMe; per proof 88 / 336 MB read column-major: ~2 / ~7 ms over PCIe 5 from host RAM, 0.03-0.1 / 0.1-0.3 s from NVMe |

Reading for §7: on one H100 the memory floor of a 30B decode proof
is ~6.4 + ~7 = **~13 ms** — 65% of the 20 ms budget, before any
arithmetic — the same figure S0 §3.4 reached for the lattice line
by a different route (there, a 13 ms read of a packed 43 GB digit
store; here, 6 ms of int8 weights plus 7 ms of decommitment columns
over the host link). On a 4090 the 30B decode floor is ~0.9 s per
proof (the weights streamed): at most ~1 tok/s at batch 1 whatever
the arithmetic; at T = 512 the same 0.9 s is 8% of the 10.2 s
budget.

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
