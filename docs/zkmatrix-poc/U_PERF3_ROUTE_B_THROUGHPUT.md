# U-PERF3 lane YY — Route B (the hash-based line): proven tokens per second, honestly

Status: COMPLETE (2026-09-02; round 11 of tranche U-PERF3, lane YY,
docs only, worktree wt-uperf3-yy; sections landed one commit each;
the "Agent YY status" block in PROGRESS_UPERF3.md carries the
summary). The sibling of lane TT's
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

Victor's rule (S6 Amendment A1, 2026-07-27): "Zero Knowledge is
nonnegotiable (although partial knowledge may be acceptable in some
cases)" — zero-knowledge for the deployment's DECLARED private set
(P3 = weights and activations private, the default; P2 = weights
private; P1 = activations private; P0 = nothing private, non-ZK
label permitted). UU's row is P0 (S1: "NOT zero-knowledge"). This
section says what the built proof reveals, which known
constructions close it, what each costs as a fraction of the
measured phases, and — the load-bearing finding — why the
weights-private modes are structurally expensive on this line.

### 4.1 What the built proof reveals [COUNTED from S3]

- **Of the weights**: per layer per proof, 256 opened columns of the
  encoded W matrix (256 x 288 field elements; the encoding is
  SYSTEMATIC, so one column in four is a raw column of int8
  weights) and three clear row-combinations (3 x 2^14 extension
  elements = random linear functionals of the whole matrix).
- **Of the activations**: the same for A and H (256 x 520 and 256 x
  432 entries; 3 + 4 clear vectors); the multiplicity tables IN THE
  CLEAR — the histogram of the SiLU input g8, of u8/h8/z, and of
  every remainder column — the very "histogram leak" the lattice
  line closed in tranche U-K5 (S6 §3, audit C-01); the sumcheck
  round polynomials (low-dimensional functionals of the tables); the
  terminal evaluations (10 + 12 per layer) and the matmul claims
  (evaluations of the committed accumulators at random points); the
  six helper sums.
- **The Merkle roots** are hashes of unsalted columns: binding, but
  not hiding in the formal sense (an int8 column of 288 values is
  brute-force-resistant only by its ~2,300 bits of content).

Soundness and binding are untouched by all of this; the row's
guarantee class is "binding, not hiding".

### 4.2 The constructions that close it [EXTERNAL, L1-L3, L5-L6]

- **(a) Ligero-ZK for the commitment** (L1 §4; L2 notes the same
  techniques apply to Brakedown). Two devices. (i) *Randomised
  rows*: append Q uniformly random field elements to every row's
  message before encoding; then any Q opened positions of that row's
  codeword are jointly uniform and reveal nothing about the data
  (the Q pad symbols are a bijection onto any Q non-systematic
  positions). The rate moves from 1/4 to (n + Q)/4n = 0.254, the
  proximity bound (1 - delta/3)^Q from 2^-106 to 2^-105.6: nil. Two
  implementation costs: the message length n + Q = 16640 is not a
  power of two (a 2^15-point interpolation, or a non-systematic
  encoding), and the sampled columns must EXCLUDE the systematic
  positions (or the encoding must be non-systematic) — with sampling
  restricted to the 3n non-systematic columns the distance is 0.66
  and Q = 296 keeps 2^-106 [COUNTED]. (ii) *Mask rows*: for every
  clear row-combination v = rho^T M, commit one extra row u of
  uniformly random message and send v' = rho^T M + u; the verifier's
  column check reads u's entry from the opened column (u is a row of
  the same commitment) and its checks are otherwise unchanged. v' is
  uniform. k + 1 mask rows per commitment.
- **(b) Zero-knowledge sumcheck** (L3: Chiesa-Forbes-Spooner's
  masking, as instantiated in Libra). Before each sumcheck the
  prover commits to a random masking polynomial g with the same
  variable count and per-variable degree — n x d + 1 coefficients:
  81 for the 20-variable degree-4 zero-check, 69 for the 17-variable
  one, 17 and 23 for the matmul sumchecks — the verifier sends a
  scalar c, and the sumcheck runs on f + c g, whose round messages
  are then uniform; g's value at the final point is opened from its
  tiny commitment. Because g is a sum of univariates, its partial
  sums are closed-form: a few hundred field operations per round.
- **(c) Masked evaluation claims.** With (a) and (b) in place no
  unmasked evaluation is ever sent: the sumcheck's terminal claim is
  about f + c g, and the PCS proves f's and g's evaluations as ONE
  combined linear claim (Ligero handles a combined claim as one
  row-combination, which (a)(ii) masks). The matmul claims and the
  helper sums are folded the same way.
- **(d) Committed multiplicities.** The multiplicity tables (256 +
  256 + one per distinct shift of 2^sh <= 2^16 entries per layer)
  move into the A commitment; the table side of the LogUp identity
  becomes a small sumcheck over the table with its own helper (2 x
  2^16 elements at most), and the equality of the two sides is one
  combined claim.
- **(e) Salted leaves**: 32 random bytes appended to every column
  before hashing, so the unopened columns are hiding.
- Not needed on this line: nothing here changes the transcript's
  soundness bookkeeping beyond the Q = 296 adjustment; the ZK claim
  is honest-verifier zero-knowledge in the random-oracle model under
  Fiat-Shamir, per sub-protocol, with the chained-layer composition
  owed its own simulator — the same caveat class as the lattice
  line's lemmas Q4.7-Q4.9 (S6 §3).

### 4.3 The cost, as fractions of the measured phases [COUNTED from the constructions; MODEL as a whole]

| item | prover (of 23.0 s) | proof bytes (of 66.8 MB) | verifier (of 2.8 s) |
|---|---|---|---|
| (a)(i) randomised rows: +Q symbols per row (+1.6% of n), the 2^15 interpolation or a non-systematic encode (+0-25% of the inverse-NTT part of the 47% commit share), Q 256 -> 296 for the column gathers (~3% of the wall) | +1-5% | +7% (the column openings are 46% of the bytes and grow with Q) | +10-15% (the verifier's column work is proportional to Q) |
| (a)(ii) mask rows: k + 1 rows per commitment of m = 288-520 | +1% | +1% | +1% |
| (b) masking polynomials: four per layer, <= 81 coefficients each | < 0.1% | +~8 KB per layer (0.1%) | < 0.1% |
| (c) masked claims | nil | nil | nil |
| (d) committed multiplicities: <= 3 x 2^16 more elements in A (of 8.5M) and one small sumcheck | +0.5-1% | +0.1% | +0.5% |
| (e) salts: +32 B per column hashed (+1-2% of hashed bytes) and per opened column | +1% | +0.4% | +1% |
| **total for mode P1 (activations private, weights public: A and H masked, W as built)** | **+2-8%** | **+1-8%** | **+2-15%** |
| **P2 / P3 (weights private): the same devices on W — PLUS §4.4** | **+9.6% at 125M, +44% at 8B x 512, +54% at 30B x 512, +143% at decode** | +1-8% | +2-15% |

The P1 surcharge is small because every masked object is already
per-proof: the activation commitments are fresh every time, so
fresh pads and fresh mask rows ride inside work that is paid anyway.

### 4.4 The weights-private problem: a cached hash commitment leaks its columns [COUNTED]

Each proof opens 256 columns of the encoded weight matrix at
Fiat-Shamir-chosen, public indices. In the ZK form the FIRST proof
reveals nothing: the Q pad symbols per row make any Q opened
positions uniform. The SECOND proof opens 256 more columns: the
union of 512 positions gives 512 linear equations per row in
n + Q = 16640 unknowns, of which only 256 are random pad — so 256
dimensions of every weight row leak. After (n + Q)/Q = **65 proofs**
each row is fully determined and the weights are recoverable from
the published proofs by linear algebra. A larger pad does not help,
because the pad size and the query count scale together at fixed
soundness: rate 1/2 with pad n needs Q = 403 and is determined after
42 proofs; rate 1/8 after 78 [COUNTED, 2^-106 in every case]. The
ratio (n + p)/Q sits at 40-80 for any Reed-Solomon parameters at
100-bit soundness.

This is ZK_GAP_OPTIONS §6's accumulation asymmetry (S6) applied to
Route B: the weights are a fixed witness re-proven every pass and
their leak ACCUMULATES; the activations are fresh every pass, so
under the one-proof-per-witness rule their 256-column exposure is a
within-proof matter, perfectly hidden by the pad. Three ways out
for P2/P3:

1. **Re-commit the weights on every proof** with fresh pads and
   salts. Cost = the commit W phase, per proof: +2.19 s at 125M
   (+9.6%), +218 s at 8B x 512 (+44%), +832 s at 30B x 512 (+54%) on
   the laptop CPU [MODEL from MEASURED]; at decode the re-commit
   EXCEEDS the whole per-proof cost (+218 s on 152 s at 8B, +832 s
   on 578 s at 30B: +143%). On one H100 the floor is the NTT and
   the hashing of 32 bytes per weight: 180 GB at 8B (**1.8-6 s per
   proof**), 688 GB at 30B (**7-23 s per proof**) at a 30-100 GB/s
   device hash rate [MODEL] — by itself 70-230% of the 10.2 s
   prefill budget and 350-1,150x the 20 ms decode budget. This is
   the only counted option and the one §6 carries.
2. **Never reveal the weight columns**: Orion-class composition
   (L5) — the column checks (256 x m x (k + 1) multiply-adds and
   256 Merkle paths per commitment) are proven inside an inner
   zero-knowledge proof instead of being sent. At 30B that inner
   statement is 62 x 3 x (256 x ~2,600 x 3) ≈ 3.7e8 multiply-adds
   plus ~1e5 hash evaluations (which must then be an arithmetic
   hash, not blake3) — an inner proof of order 1e9 constraints per
   proof [COUNTED], whose prover this memo does not price (the
   lattice review priced the comparable family-(e) wrap at minutes,
   S5 §5) [MODEL, uncounted]. It removes the leak, not the linear
   per-proof pass.
3. **A hiding, rerandomisable weight commitment from a different
   assumption**: the lattice line's MLWE commitment (hiding by
   construction; the per-proof masks are what Tier Z prices, S6
   Amendment A1) or a discrete-log Pedersen/KZG (not post-quantum).
   Route B would carry the weights on the lattice channel and the
   activations on the hash channel, joined by a cross-commitment
   link that must itself be zero-knowledge (S5 §4.4 item 4: ~59 KB
   of link rows per tensor) [MODEL, uncounted]. This is S4 §3's
   "A + B" row made concrete.

   **Priced (lane ZZ, 2026-09-02): **
   counts the three options above (and a fourth from the
   literature: none found) on this memo's yardstick. Option 2 in
   its hash-in-circuit form (a once-per-model Poseidon2 tree, the
   column check proven per proof in a fresh ZK GKR, a fresh mask
   commitment) keeps P0's 30B prefill cells (46-137 tok/s at the
   floor / 7.8-58 scaled, one H100); option 1 reaches 50 only at
   B >= 16 stacked 512-token prefills per proof (42-127 / 12-87);
   option 3 only with Variant B at B >= 16 (32-128), and its
   Goldilocks-to-q31 link has no recorded design. Its §6 table and
   §7 verdict carry the ruling's numbers.

### 4.5 Partial knowledge: what each declared mode leaves in the clear on Route B

| mode (S6 A1) | private | stays in the clear | ZK machinery | surcharge over the P0 row |
|---|---|---|---|---|
| P0 | nothing | everything of §4.1 | none | 0 |
| **P1** | inputs / activations | the weights (a cached, unmasked W commitment and its columns — public anyway); shapes, shifts, the table digest, the multiplicity TOTALS | (a)-(e) on A and H | **+2-8% prover, +1-8% bytes, +2-15% verifier** |
| **P2** | weights | the activations, inputs, outputs, histograms, helper sums — all as built | (a), (e) on W; a FRESH W commitment per proof (§4.4 option 1) | **+9.6% / +44% / +54% / +143%** (125M / 8B x 512 / 30B x 512 / decode) on the laptop; on an H100 a hashing floor of 1.8-6 s (8B) / 7-23 s (30B) per proof |
| P3 | both | shapes, shifts, the table digest, the totals | everything above | the sum of P1 and P2 |

Reading: on Route B the CHEAP partial-knowledge mode is P1 (open
weights, private inputs) and the EXPENSIVE one is P2 (proprietary
weights, open inputs) — the reverse of what a model vendor wants,
and the reverse of ZK_GAP_OPTIONS' expectation for the lattice line,
where P2 was "the likely flagship mode" at a fixed surcharge (Tier N
pass + 0.3-0.4 MiB, S6). The reason is structural, not a tuning
matter: a lattice commitment is hiding and re-openable with a fresh
sqrt-class mask per proof; a hash commitment is binding but not
hiding across openings, and hiding it costs a fresh commitment.
Whether the competitor's "weights private behind a commitment" (S5
addendum) means the cumulative sense used here is not stated in
their material.

## 5. The proof-size lever

### 5.1 Why 66.8 MB: the sqrt law [MEASURED anatomy from S1; law COUNTED from S3 `Opening::size_bytes`]

Per layer 5.57 MB = column openings 256 x (288 + 520 + 432) rows x
8 B = 2.54 MB + 10 clear vectors x 2^14 x 16 B = 2.62 MB + Merkle
paths 3 x 256 x 16 x 32 B = 0.39 MB + sumchecks and claims ~10 KB.
For one commitment of N elements laid out as m x n, the bytes are
`Q x m x 8 + (k + 1) x n x 16 + Q x log2(4n) x 32` with m = N / n: the
first term falls with n, the second rises, and the minimum sits at
n* = sqrt(128 N / (k + 1)), where the bytes are proportional to
**sqrt(N)** — the Ligero/Brakedown sqrt-size class (L1, L2; S5 §4.4
item 2). At 125M the as-built n = 2^14 is already within 2% of the
optimum for all three commitments [COUNTED]; there is no free lever
in the parameters.

### 5.2 The sqrt class at every shape [COUNTED at the per-commitment optimum n]

| shape | n (W / A / H) | per layer | per 512-token pass | per prefill token | per DECODE token (the W opening is per proof) |
|---|---|---:|---:|---:|---:|
| 125M, 12 layers (as built, S1) | 2^14 / 2^14 / 2^14 | 5.57 MB | **66.8 MB** [MEASURED] | 130 KB | 18 MB |
| 8B, 32 layers | 2^16 / 2^16 / 2^15 | 19.1 MB | **613 MB** | 1.2 MB | **282 MB** |
| 30B stand-in, 62 layers | 2^17 / 2^16 / 2^16 | 24.4 MB | **1.51 GB** | 3.0 MB | **736 MB** |

Two readings. Per prefill token the sqrt class is 1-3 MB — the same
order as the competitor's 4-8 MiB per token-step (S5 addendum) —
but per proof it is a 0.6-1.5 GB artifact, and per DECODE token it
is 0.3-0.7 GB, because the weight opening's bytes do not shrink with
T. The verifier's work grows the same way: 2.8 s at 12x512 (8
threads) [MEASURED] scales to ~3-5 s at 8B and ~8-12 s at 30B [MODEL:
re-encoding 10 clear vectors of 4n per layer plus 256 x (k + 1) x m
multiply-adds per commitment], against the contract's <= 2 s
single-threaded line (S6 §4). The sqrt class therefore fails R5 (S0
§7.2) at 8B and above, and is unshippable for decode at any scale.

### 5.3 The levers, counted

| lever | what changes | bytes per pass, 125M / 8B / 30B | prover time | verifier | label |
|---|---|---|---|---|---|
| as built | — | 67 MB / 613 MB / 1.51 GB | 1.0x | 2.8 s / ~3-5 s / ~8-12 s | [MEASURED / COUNTED / MODEL] |
| **batched-evaluation reduction + one merged commitment** (UU's item (b)): reduce every claim on a commitment to ONE point by a batching sumcheck (a random combination of the claims at their points, proven equal to one evaluation at a fresh point — standard for multilinear PCS), so k + 1 = 2 clear vectors; merge W, A, H into one matrix and re-optimise n (2^15 / 2^17 / 2^17-2^18) | columns unchanged, clear vectors 10 -> 2, paths 3 -> 1 | 30 MB / 280 MB / 760 MB (−56% / −54% / −50%) | +5-15% [MODEL]: one more N-sized sumcheck per commitment (+10-20%), minus a third of the row-combinations (−6%) | ~−50% | [COUNTED bytes, MODEL time] |
| **WHIR / STIR-class multilinear PCS** (L4): the whole commitment as one Reed-Solomon codeword (one NTT of 2^23-2^28 x 1/rate instead of 300-3,000 independent 2^16 NTTs), rate 1/2, a sumcheck-driven opening that folds the codeword 16x per round and re-commits the folded remainder, ~100-300 queries per round with Merkle paths | proof size polylog in N: WHIR reports 63 KiB at degree 2^22, 100 bits [EXTERNAL, S5 §4.2 abstract verified]; 60-150 KiB per opening at our 2^22-2^28 sizes [MODEL from the stated growth]; one opening per commitment per layer, or one per layer merged | **1.2-2.4 MB / 3-6 MB / 6-12 MB** (−30-60x / −100-200x / −125-250x); per decode token 3-12 MB instead of 282-736; with one cross-layer batched opening per proof ~0.2-0.5 MB [MODEL] | commit: the NTT part 1-2x (a larger, cache-unfriendly transform) and the hashed bytes −50% (rate 1/2: 16 B per element instead of 32); open: one N-sized sumcheck (≈ a zero-check of the same size, ~0.2 s per 2^23 commitment on the laptop) plus ~1/15 of a commit for the fold rounds. Net: **commit + open phases x 0.9-1.6, the whole prover x 0.94-1.4** [MODEL from stated complexities] | 360 us per opening at 2^22 [EXTERNAL]; tens of ms per pass at any shape — the <= 2 s line met with ~100x margin | [EXTERNAL / MODEL] |
| **FRI** (L4, fold-by-2 with a re-commit per round) | as above, larger proofs: STIR reports 1.25-2.5x smaller than FRI and WHIR smaller again [EXTERNAL] | ~2-3x the WHIR row: 3-6 MB / 8-16 MB / 15-30 MB | commit as WHIR; open: the fold rounds sum to ~1x a commit -> commit + open x 1.3-2 [MODEL] | ms-class | [EXTERNAL / MODEL] |
| BaseFold (S5 §4.4 item 1, field-agnostic) | not needed here: Goldilocks has 2-adicity 32, so the "two-adicity wall" that blocked this family on the lattice line's q31 field (S5 §4.3) does not exist on Route B — the field choice is what makes the polylog PCS available at all | — | — | — | — |
| recursion (a SNARK of the Ligero verifier; S5 family (e)) | the 2.8 s verifier is ~1e9 field operations — an inner circuit of that order per pass; hundreds of seconds of prover [MODEL] | KB-class | far worse | ms | not a latency lever |

### 5.4 What the swap does and does not change

- It is the mandatory step for a shippable decode artifact and for
  the verifier budget at 8B and above; on the prover it is roughly
  neutral (x0.94-1.4), because Ligero's cheap GEMV opening is traded
  for a cheaper commit (half the hashed bytes) plus an N-sized
  sumcheck.
- It does NOT change §2's per-proof weight-side linearity: every
  hash-based PCS known to this memo does Omega(N) prover work per
  opening of an N-sized polynomial (the folds and the sumcheck walk
  every coefficient); R1 stands.
- It does NOT change §4.4: a FRI-class opening reveals query values
  of the codeword and of its folds at hundreds of public positions
  per proof; a cached weight commitment accumulates the same leak,
  and the ZK forms of FRI/STIR/WHIR blind the polynomial with fresh
  randomness per proof — a per-proof re-commit of the weights
  again.
- It is a spike, not a design change: the multilinear claims, the
  sumchecks and the LogUp form stay; only `pcs.rs` is replaced. UU
  sized it as an open item; this memo prices it as the largest
  byte lever and a prover wash, and names the spike in §7.4.

## 6. The tokens/s table, next to the lattice line

How to read it: tokens/s = tokens per proof / prover-clock seconds
per proof (§1.1). "Prefill" is T = 512 tokens per proof; "decode" is
batch 1. The Route-B laptop-CPU column applies §2.5's costs; the
device columns divide by §3.3's ranges (laptop GPU 5-15x, desktop
board 15-75x, H100 25-180x). "P0" is the row as built (no ZK);
"P1" applies §4.3's +2-8% (activations private); "P3" adds the
per-proof weight re-commit of §4.4 (weights private; P2 costs the
same). Every token is an **FFN-only** token (§1.4). The lattice
rows are copied from S0 §4.2-4.3 for the comparison: their "laptop"
column is the laptop WITH its GPU (the lattice line's reference
pass), which this memo places under "laptop GPU"; the lattice line
has no CPU-only 8B row.

Labels: the only [MEASURED] cell is the 125M anchor. Every 8B cell
is [MODEL] (no 8B proof has run on either line — S7 §3.1). Every
30B cell is [MODEL on MODEL]. Every device cell adds §3's unmeasured
factor. Cells are cut where a counted floor binds and say so.

### 6.1 The anchors [MEASURED]

| line | shape | machine | prover clock | tokens/s (of the 125M model, FFN-only) |
|---|---|---|---:|---:|
| Route B (S1) | 12 x 512 | WSL laptop, 8 threads, CPU only, NOISY-SHARED | 23.0 s (25.8 s wall incl. verify); 20.7 s with the weight commitment cached (§2.2) | **22** (20 on the wall; 25 cached) |
| lattice (S0 §4.1) | 12 x 512 | WSL laptop, 8 threads + RTX 4070 Laptop, QUIET | 18.0 s (21.0 s wall) | 28 (24 on the wall) |

### 6.2 8B (Mistral-7B shape), proven FFN tokens per second [MODEL]; each cell "prefill / decode"

| design | laptop CPU (8T) | laptop GPU (RTX 4070 Laptop) | one desktop board (4090 class) | one H100 |
|---|---:|---:|---:|---:|
| **Route B, P0 (as built, no ZK)** | **1.0 / 0.0066** | 5.2-16 / 0.033-0.099 | 16-78 / 0.10-0.49 | **26-187 / 0.16-1.2** |
| Route B, P1 (activations private) | 0.96-1.0 / 0.0061-0.0065 | 4.8-15 / 0.031-0.097 | 15-76 / 0.09-0.48 | 24-183 / 0.15-1.2 |
| Route B, P3 (weights + activations private: W re-committed per proof) | 0.72 / 0.0027 | 3.6-11 / 0.014-0.041 | 11-54 / 0.041-0.20 | 18-130 / 0.068-0.49 (floor: 1.8-6 s of hashing per proof) |
| lattice (a) built (S0) | — | 0.56-0.83 / 0.0024-0.0027 | 1.1-5.0 / 0.005-0.016 | 1.1-6.6 / 0.005-0.022 |
| lattice (b) built + Stage A (S0) | — | 0.71-0.80 / 0.0024-0.0027 | 1.4-4.8 / 0.005-0.016 | 1.4-6.4 / 0.005-0.022 |
| lattice (c) two-tier + weight preprocessing, routes constants (S0) | — | 3.3-5.6 / 0.08-0.25 | 6.6-33 / 0.15-0.55 | 6.6-45 / 0.15-2.0 |
| lattice (c') same, spike-measured constants (S0) | — | 0.9-2.4 / 0.003-0.016 | 1.8-9.7 / 0.006-0.06 | 1.8-9.7 / 0.006-0.06 |

Per-proof costs behind the Route-B cells (laptop CPU, prover clock,
s): P0 492 / 152; P1 502-531 / 155-164; P3 710 / 370 (§2.5, §4.4).
The 8B pass fits the laptop's 15 GB only barely as built (§2.4) and
not its 8 GB VRAM: the laptop-GPU column is "streamed per layer".

### 6.3 30B (the §1.3 stand-in shape), proven FFN tokens per second [MODEL on MODEL]; each cell "prefill / decode"

| design | laptop CPU (8T) | laptop GPU | one desktop board (4090 class) | one H100 |
|---|---:|---:|---:|---:|
| **Route B, P0 (as built, no ZK)** | **0.33 / 0.0017** (does not fit 15 GB) | 1.7-5.0 / 0.0087-0.026 (does not fit 8 GB VRAM: streamed) | 5.0-25 / 0.026-0.13 (decode floor 0.9 s: the weights streamed, §3.5) | **8.3-60 / 0.043-0.31** |
| Route B, P1 (activations private) | 0.31-0.32 / 0.0016-0.0017 | 1.6-4.9 / 0.0081-0.026 | 4.6-24 / 0.024-0.13 | 7.7-58 / 0.040-0.30 |
| Route B, P3 (weights + activations private) | 0.22 / 0.0007 | 1.1-3.2 / 0.0035-0.011 | 3.2-16 / 0.011-0.053 | 5.4-39 / 0.018-0.13 (**floor: 7-23 s of hashing per proof** — the top of the range holds only at a >= 70 GB/s device hash rate) |
| lattice (a) built (S0) | — | 0.17-0.24 / 0.0006-0.0007 | 0.35-1.4 / 0.0013-0.004 | 0.35-1.9 / 0.0013-0.006 |
| lattice (b) built + Stage A (S0) | — | 0.21-0.23 / 0.0006-0.0007 | 0.42-1.4 / 0.0013-0.004 | 0.42-1.9 / 0.0013-0.006 |
| lattice (c) routes constants (S0) | — | 1.1-1.9 / 0.024-0.09 | 2.3-12 / 0.05-0.14 | **2.3-15 / 0.05-0.3** (0.05-0.7 with a packed store) |
| lattice (c') spike constants (S0) | — | 0.26-0.78 / 0.0008-0.004 | 0.5-3.1 / 0.0016-0.017 | 0.5-3.1 / 0.0016-0.017 |

Per-proof costs behind the Route-B cells (laptop CPU, s): P0 1,546 /
578; P1 1,577-1,670 / 590-624; P3 2,378 / 1,410. Memory: no Route-B
30B pass fits the laptop; a 4090 holds one layer's working set OR
the weights, not both (§3.5); an H100 holds both.

### 6.4 The counted floors on one H100, for the cells that matter [COUNTED on spec sheet, §7.2]

The scaled-constant cells above carry the as-built CPU code's
inefficiencies (§2.1: ~10x on the streaming loops, 3.5x on the
small zero-check) divided by a hardware range. The spec-sheet floor
— tuned kernels, the weights HBM-resident, the device saturated —
is a different number, and the distance between the two is the
kernel-quality unknown (the analogue of S0's (c)/(c') spread):

| cell | scaled-constant model | counted floor | what the floor is made of |
|---|---:|---:|---|
| 8B prefill, P0 | 26-187 tok/s (2.7-20 s per proof) | ~140-400 tok/s (1.3-3.7 s) | hashing 108 GB of encoded activations at 30-100 GB/s; NTT 0.05 s; sumchecks 0.03 s; weight side 10-20 ms |
| 8B decode, P0 | 0.16-1.2 tok/s | **~33-80 tok/s** (12-30 ms) | weight side 10-20 ms (§2.3); 212 MB of activations hashed (2-7 ms) |
| 30B prefill, P0 | 8.3-60 tok/s (8.6-62 s) | **~47-138 tok/s** (3.7-11 s) | hashing 311 GB at 30-100 GB/s (3.1-10.4 s); NTT 0.14 s; zero-checks 0.09 s; openings 0.02 s; ~1 TB of memory traffic 0.3 s; weight side 25-60 ms; witness inference ~8 ms |
| 30B decode, P0 | 0.043-0.31 tok/s | **~12-33 tok/s** (30-80 ms) | the weight side alone is 25-60 ms: 6.4 ms of reads + 18-36 ms of arithmetic + 7 ms of cache columns; plus 608 MB of activations hashed (6-20 ms) |
| 30B prefill, P3 | 5.4-39 tok/s | ~15-48 tok/s (11-34 s) | the P0 floor plus the weight re-commit: 688 GB hashed (7-23 s) |
| 30B decode, P3 | 0.018-0.13 tok/s | **<= 0.14 tok/s** (>= 7 s) | the re-commit's hashing alone |

### 6.5 The same cells in proven MAC/s, for the yardstick of §7

| design, workload | laptop CPU | laptop GPU | one desktop board | one H100 |
|---|---:|---:|---:|---:|
| Route B, 125M 12x512 [MEASURED, S1] | 1.26e9 | — | — | — |
| lattice, 125M 12x512 [MEASURED, S0] | (3.6e8 CPU-only) | 1.4e9 wall / 1.6e9 clock | — | — |
| Route B, 8B prefill P0 [MODEL] | 5.9e9 | 2.9-8.8e10 | 0.9-4.4e11 | 1.5e11-1.1e12 |
| Route B, 30B prefill P0 [MODEL on MODEL] | 7.1e9 | 3.6e10-1.1e11 | 1.1-5.3e11 | **1.8e11-1.3e12** |
| Route B, 30B decode P0 | 3.7e7 | 1.9-5.6e8 | 0.6-2.8e9 | 0.9-6.7e9; **counted floor 2.7-7.2e11** |
| lattice (c), 30B prefill [S0 §4.4] | — | 2.4-4.1e10 | 0.5-2.5e11 | 0.5-3.3e11 |
| **the target: 50 tok/s at 30B** | | | | **1.55e12** |
| the competitor's claim (S5) [EXTERNAL] | | | | 1.6e12 (batch 1), 2.4e12 (batch 4) |

### 6.6 What the table says

1. **On the laptop's CPU alone, Route B as built is a ~1 tok/s
   system at 8B prefill and a ~0.007 tok/s system at 8B decode**
   [MODEL from the measured 125M pass] — the same two-workload
   shape as the lattice line and, per proof, in the class of the
   lattice line's (c') row, which needed the GPU.
2. **Zero knowledge splits by mode.** P1 (activations private)
   costs 2-8% and does not move any cell. P3/P2 (weights private)
   costs the weight commitment on every proof: −31% on 8B prefill,
   −59% on 8B decode, −35% / −59% at 30B, and on an H100 a hashing
   floor that caps 30B decode at ~0.1 tok/s and takes 70-230% of
   the 10.2 s prefill budget by itself.
3. **The device columns are where the two lines part.** Route B's
   work is entirely device-shaped, so its factors are 25-180x
   (H100) against the lattice line's 2-8x; that is the whole reason
   Route B's 30B-prefill H100 cell (8-60 tok/s) is 4x the lattice
   line's best (2-15). None of it is measured; lane XX's row is the
   first point.
4. **The 30B prefill cell straddles the goal.** 8.3-60 tok/s by
   scaled constants, 47-138 at the counted floor: 50 tok/s needs the
   upper half of the hardware range or kernels near the floor, and
   the floor is set by the device's hash rate (§7.2).
5. **Batch-1 decode does not reach the goal in any Route-B cell**,
   scaled or counted: the counted floor at 30B is 12-33 tok/s, set
   by a per-proof pass over 21.5 GB of weights that no hash-based
   PCS avoids (§5.4), and the scaled model is 100x below that.
6. Pipelining consecutive proofs buys ~1x on one board once the
   pass is device-resident (S0 §5.3's argument applies verbatim);
   batching B requests per proof is the lever (§7.3).

## 7. The competitor row, and what a 50 tok/s Route-B design must have

### 7.1 The competitor row on this memo's yardstick

The claim (S5 addendum; S0 §6): Gemma-4-31B INT8, **53 tok/s at
batch 1** (16K context) and **77 tok/s at batch 4**, on ONE H100;
proofs 4.35-7.92 MiB; CPU verification 157-648 ms; hash-based,
post-quantum, 100-bit; "all non-linear operations in floating point,
all matrix multiplications quantized to integers"; weights "private
behind a commitment". No paper, no code, no third-party
reproduction. Every number **[EXTERNAL, VENDOR-CLAIMED, UNVERIFIED]**.

| row | tokens/s | proven MAC/s | ms per token | what the statement covers | label |
|---|---:|---:|---:|---|---|
| Attestable, batch 1 | 53 | **1.6e12** | 18.9 | the full model: attention, FFN, float nonlinears (approximate), 16K context | [EXTERNAL, VENDOR-CLAIMED] |
| Attestable, batch 4 | 77 | 2.4e12 | 52 per 4-token step | same | [EXTERNAL, VENDOR-CLAIMED] |
| **the goal** | 50 | 1.55e12 | 20 | | |
| Route B, measured (125M, 12x512, laptop CPU 8T) | 22 (of a 125M model) | 1.26e9 | 45 (of a 125M token) | FFN only, exact integer, hash-only ~100-bit, NOT ZK | [MEASURED, S1] |
| Route B, 30B prefill, one H100, P0, scaled constants | 8.3-60 | 1.8e11-1.3e12 | 17-120 | FFN only | [MODEL on MODEL] |
| Route B, 30B prefill, one H100, P0, counted floor | 47-138 | 1.0-3.0e12 | 7-21 | FFN only | [COUNTED on spec sheet] |
| Route B, 30B decode, one H100, P0, counted floor | 12-33 | 2.7-7.2e11 | 30-80 | FFN only | [COUNTED on spec sheet] |
| Route B, 30B decode, one H100, P3 (weights private) | <= 0.14 | <= 3e9 | >= 7,000 | FFN only | [COUNTED floor] |
| lattice (c), 30B prefill, one H100 (S0 §6) | 2.3-15 | 0.5-3.3e11 | 65-430 | FFN only | [MODEL on MODEL] |

Ratios: the claim is ~1,300x Route B's measured CPU rate, 1.2-9x
above its scaled 30B-prefill cell on an H100, and INSIDE the counted
floor's band (1.0-3.0e12 against 1.6e12). Read plainly: **a
hash-based prover at the spec-sheet floor, FFN-only, batched, is
consistent with the claimed rate** — the first time a number in this
repository has been. For batch-1 decode the claim sits 1.5-4x above
the counted floor of a LINEAR weight opening on the same board
(12-33 tok/s), and their statement is said to include attention
(1.3-1.6x MACs and more proof mass): either their per-token
weight-side cost is sublinear (a structure not known to this memo —
and one that is hard to reconcile with "weights private behind a
commitment" in the cumulative sense of §4.4), or the 53 tok/s is an
amortised figure; the material does not say. The other columns:
their 4-8 MiB per token-step and 0.16-0.65 s verification are what
Route B gets only after the PCS swap of §5 (12-25 KB per prefill
token, 3-12 MB per decode token, ms verification); in the sqrt
class as built Route B is 3 MB per prefill token, 0.7 GB per decode
token and 8-12 s to verify at 30B.

### 7.2 The budget on one H100, and the per-proof weight-side count [COUNTED on spec sheet]

| quantity | batch-1 decode | T = 512 prefill (or a 512-request batch) |
|---|---:|---:|
| proven MAC/s required | 1.55e12 | 1.55e12 |
| time per proof | **20 ms** | **10.2 s** |
| the per-proof weight side at 30B (§2.3, §3.5): 21.5 GB of int8 weights HBM-resident, read once, 6.4 ms; 6.5-9.3e10 extension-by-int8 multiply-adds at ~7 int32 ops each on 1.67e13 int32 ops/s, 18-36 ms (a tuned fused kernel: two 64 x 8-bit products per weight, lazy reduction); 336 MB of decommitment columns over PCIe 5 from host RAM, 7 ms | **25-60 ms = 1.3-3x the WHOLE budget** | 25-60 ms = 0.3-0.6% of the budget |
| left for the activation side | **nothing** | ~10.1 s for 1.1e13 MACs (~1.1e12 MAC/s) |
| the activation side at 30B, counted floor (§6.4): hashing 311 GB of encoded activations at 30-100 GB/s, 3.1-10.4 s; NTT 0.14 s; zero-checks 0.09 s; openings 0.02 s; ~1 TB of memory traffic 0.3 s; witness inference ~8 ms | per token: 608 MB hashed = 6-20 ms, plus ~1 ms | **3.7-11 s** |
| the activation side by scaled constants (§2.4: 970 s laptop CPU / 25-180) | 11-76 ms per token | 5.4-39 s |
| **total per proof, counted floor** | **30-80 ms -> 12-33 tok/s** | **3.7-11 s -> 47-138 tok/s** |
| total, scaled constants | 3.2-23 s -> 0.04-0.3 tok/s | 8.6-62 s -> 8-60 tok/s |
| with ZK, mode P1 | x1.02-1.08 | x1.02-1.08 |
| with ZK, modes P2/P3 (the weight re-commit: 688 GB hashed, 7-23 s per proof) | >= 7 s -> <= 0.14 tok/s | floor 11-34 s -> 15-48 tok/s; scaled 13-95 s -> 5-39 |

**Is a linear weight opening affordable on an H100?** At batch 1,
NO: 25-60 ms against 20 ms, and the arithmetic (18-36 ms) is the
larger part, not the bytes (6.4 ms) — even the two-multiply-add
floor (2 x 2.15e10 x 7 / 1.67e13 = 18 ms) plus the reads and the
columns is 31 ms. At T = 512, or at B >= 8 requests per proof, YES:
25-60 ms is 0.3-0.6% of a 10.2 s budget and 3-8 ms per token at
B = 8.

**Batching, counted.** Per token at 30B at the counted floor: the
weight side (25-60 ms) / B plus the activation side per token (7-21
ms, set by the hash rate):

| requests per proof B | ms per token | tok/s |
|---:|---:|---:|
| 1 | 32-81 | 12-31 |
| 4 | 13-36 | 28-77 |
| 8 | 10-28 | 36-100 |
| 16 | 9-25 | 40-110 |
| 512 (prefill) | 7-21 | 47-138 |

So at the counted floor, 50 tok/s at 30B needs **B >= 4-16 requests
per proof AND a sustained device hash rate >= ~50 GB/s** (at 30 GB/s
the activation side alone is 21 ms per token: 47 tok/s at any B).
The competitor's batch-4 figure (77) sits at the top of the B = 4
band. Halving the hashed bytes — rate 1/2 (Q ~ 400), or a 32-bit
field, or both (4x) — moves the activation-side floor from 7-21 ms
to 2-10 ms per token [MODEL]: the field and rate are design choices
that trade soundness bookkeeping and proof bytes for hash volume,
and the competitor's Circle-STARK lineage (S5 addendum) is a 31-bit
field.

### 7.3 The requirements, stated as "must" (the Route-B reading of S0 §7.2)

- **R1 (weight side).** The per-proof weight pass is linear and
  stays linear under every hash-based PCS (§5.4); it is affordable
  only AMORTISED: >= 4-16 tokens per proof (batched decode) or
  prefill. The product is "batched / prefill proving", not batch-1
  decode — S0's R1b, reached on this line by a different route.
- **R2 (activation side).** A sustained device hash rate of >= 30-50
  GB/s on 2-4 KB inputs (blake3 or an arithmetic hash), and NTT /
  sumcheck / GEMV kernels near the bandwidth floor. By scaled
  constants this is a >= ~90x factor over the CPU row as built.
- **R3 (memory).** H100-class capacity: the 21.5 GB int8 weights and
  a layer's 16 GB working set resident (§3.5); the 538 GB encoded
  cache column-major in host RAM or NVMe (or dropped, under P2/P3).
- **R4 (statement).** Attention on this line (1.3-1.6x MACs; proof
  mass unmeasured); the X/W range facts (+15-20% [MODEL]); the layer
  seams.
- **R5 (verifier and bytes).** The PCS swap of §5 — mandatory for a
  decode artifact (0.7 GB per token in the sqrt class) and for the
  <= 2 s verifier line at 8B and above; roughly neutral on the
  prover.
- **R6 (zero knowledge, Victor's rule).** P1 is +2-8% and changes no
  cell. P2/P3 as counted need a fresh weight commitment per proof —
  7-23 s per proof at 30B on an H100 (1.7-6 s at rate 1/2 in a
  32-bit field [MODEL]) — which alone is 70-230% (17-60%) of the
  prefill budget; 50 tok/s under P2/P3 therefore needs either a
  >= 100 GB/s hash rate with >= 1,000-token batches, or one of
  §4.4's uncounted designs (Orion-class hidden columns; a hiding
  lattice commitment for the weights with a ZK link). This is a
  product decision (which private set the deployment declares) that
  changes the answer by 2x or more.

### 7.4 Which measurement replaces which constant

| constant in this memo | current status | who measures it | where it lands |
|---|---|---|---|
| the laptop-GPU factor (5-15x, §3.3) | [MODEL] (UU rung 6) | **lane XX** rung 5: the 12x512 pass on the RTX 4070, proofs byte-identical, prove/verify walls | the laptop-GPU column of §6 becomes [MEASURED]; the board and H100 columns become [MODEL on MEASURED] |
| the device hash rate (30-100 GB/s) — the dominant floor term | [MODEL, no source in this repository] | **lane XX** rung 2 (blake3 Merkle on the device; or its decision to leave hashing on the CPU, which itself is a measurement) | the activation-side floor of §7.2; R2 |
| the row-combination on the device (25-60 ms at 30B) | [COUNTED on spec] | **lane XX** rung 4, ideally fused and int8-sourced with the weights resident | R1's per-proof constant; every decode cell |
| the sumcheck rounds on the device (10-20x) | [MODEL] | lane XX rung 3 | 30% of the wall |
| the ZK surcharge P1 (+2-8%) and the P2/P3 re-commit | [COUNTED from constructions] | **a ZK spike**: Ligero-ZK pads and mask rows, Libra masks, committed multiplicities and salts on `hashline` at 12x512 — bytes, prove, verify, and a simulator argument for the chained transcript | §4.3's row becomes [MEASURED]; the P2/P3 re-commit is today's commit-W phase, already measured |
| the PCS swap (x0.94-1.4 prover, 30-250x fewer bytes) | [MODEL from stated complexities] | **a PCS spike**: a WHIR/STIR-class `pcs.rs` behind a switch, the same claims, at 12x512 | §5's row; R5; the decode artifact |
| the 8B activation-side constants (x18.1-18.7 per pass) | [COUNTED sizes x MEASURED 125M constants] | an 8B-shape layer of `hashline` on the Mac at T = 16 / 64 / 512 (the T-scaling leg, as S0's M5) | the 8B column of §2.4-2.5; the zero-check-17 anomaly resolved |
| the 30B shape (x3.81 weights, x2.87 activations) | assumed (S0 §1.3) | Victor (the target model) | every 30B row |
| attention's cost on this line | unknown | an attention layer in `hashline` (the X3 analogue) | R4 |
| the board / H100 factor | [MODEL] | choice C (S7 §7): a 4090 or a rented H100 under the 12x512 rig, 20 warm QUIET runs | every device column |

### 7.5 The unknowns that decide the answer, and the verdict

1. **U1 — the port factor and the device hash rate (lane XX).**
   They decide whether the 30B-prefill H100 cell is 8 or 60 tok/s
   by scaled constants, i.e. whether 50 is inside the band, and
   whether the counted floor (47-138) is approachable. Nothing else
   in this memo moves the prefill answer as much.
2. **U2 — the declared private set.** P1 leaves every cell where it
   is; P2/P3 halve the prefill cells and cap decode at ~0.1 tok/s
   under the only counted design. This is Victor's product ruling,
   not a measurement.
3. **U3 — attention's proof mass on this line**, the same R4 as S0.

**Verdict for Route B.** Under the assumptions counted here, **50
proven tokens per second at 30B on one H100 is reachable on Route B
only for 512-token prefill or batched proving (B >= 4-16), FFN-only,
in modes P0/P1, and only if the GPU port lands in the upper half of
§3's range (>= ~90x over the CPU row as built) with a sustained
device hash rate of >= ~50 GB/s** — the spec-sheet floor for that
cell is 47-138 tok/s, so the goal is inside the floor's band and
outside the lower half of the scaled band. It hinges on lane XX's
two numbers (the port factor; the hash rate) before anything else.
**Batch-1 decode at 50 tok/s is not reachable on this line under any
counted assumption**: the per-proof linear weight opening is 25-60
ms on an H100 against a 20 ms budget, and every hash-based PCS
keeps it linear. **Under P2/P3 (weights private) no counted cell
reaches 50 tok/s** — the per-proof weight re-commit is 70-230% of
the prefill budget by itself — unless an uncounted design (hidden
columns, or a hiding lattice commitment for the weights) prices in.
Against the lattice line's best modelled cell (2-15 tok/s, S0), Route
B's scaled cell is 4x higher and its floor 10x higher, at the price
of the hash-only assumption class, the sqrt-size artifact until the
PCS swap, and — the finding of §4 — a weights-private mode that is
structurally, not incrementally, more expensive.

## What is not known

1. **Any Route-B wall on any device.** The only measured row is the
   laptop CPU at 8 threads (S1). Every device cell in §6 is that row
   divided by an unmeasured factor; lane XX's rung 5 is the first
   point.
2. **The device hash rate** — the dominant term of every counted
   floor (§6.4, §7.2). No source in this repository; 30-100 GB/s is
   a [MODEL] band.
3. **The 8B and 30B activation-side constants.** Sizes are counted
   from the code; the per-element constants are measured at 125M
   only, and the 3.5x gap between the two zero-checks' per-entry
   rates (§2.1) shows they are not settled. An 8B-shape layer run
   (the T-scaling leg) is the fix.
4. **The per-proof weight-side constant on a device** (25-60 ms at
   30B): counted on the spec sheet, never run — the Route-B twin of
   S0's U1.
5. **Whether the fused, int8-sourced weight pass reaches the
   bandwidth floor**; as built it moves 32x the bytes (§2.3).
6. **The zero-knowledge constructions' real overheads** (+2-8% is
   counted from the papers, unbuilt) and the simulator argument for
   the chained 12/32/62-layer transcript.
7. **The weights-private answer beyond re-commit**: Orion-class
   hidden columns and the lattice-hybrid link are named, not
   priced (§4.4).
8. **The PCS swap's real prover factor** (0.94-1.4 from stated
   complexities; the WHIR paper's benchmarks are at other rates and
   shapes) and its ZK form's cost.
9. **The 30B architecture** (as S0 §1.3: a stand-in).
10. **Attention on this line**: never designed or run in
    `hashline`.
11. **Whether the competitor's claim holds**, and whether its
    "weights private" is cumulative across proofs (§4.4) or
    per-proof.
12. **Memory and layout at 30B on a 24 GB board**: streaming per
    layer and the column-major cache are design notes.
13. **The verifier at 8B and 30B in the sqrt class** (3-5 s and 8-12
    s at 8 threads [MODEL]) against the <= 2 s single-thread line.
14. **Witness inference on the clock** at 8B/30B on a device
    (milliseconds on tensor cores [MODEL]; 10-30 s on 8 CPU threads).
