# U-PERF3 lane ZZ — Route B (the hash-based line): keeping the WEIGHTS private across many proofs, priced

Status: SKELETON (2026-09-02; round 11 of tranche U-PERF3, lane ZZ,
docs only, worktree wt-uperf3-zz; sections land one commit each).
The sibling of lane YY's `U_PERF3_ROUTE_B_THROUGHPUT.md` (cited as
S0 below) for ONE question that memo left open in its §4.4: on the
hash-based line, how can the weights stay private across MANY
proofs, and what does each way cost against the goal of 50 proven
tokens per second for a 30B model on one H100? Same yardstick, same
shapes, same hardware ranges, same floors, same labels as S0; where
this memo and S0 use the same word, it means the same thing.

Who this is for: a reader who knows what a cryptographic proof is
but has never opened this repository. Every term is defined where it
first appears. Every number carries one of four labels:

- **[MEASURED]** — a run happened on a named machine, on a named date.
- **[COUNTED]** — derived by arithmetic from measured pieces or from
  the code's own loops (the arithmetic is shown).
- **[MODEL]** — an estimate; the assumption is written next to it.
- **[EXTERNAL]** — someone else's claim; unverified by us.

Where a number is a [MODEL] built on another [MODEL], the cell says
so ("[MODEL on MODEL]").

The rule this memo serves (S6 Amendment A1, Victor 2026-07-27):
"Zero Knowledge is nonnegotiable (although partial knowledge may be
acceptable in some cases)" — zero-knowledge for the deployment's
DECLARED private set: P3 = weights and activations private (the
default), P2 = weights private, P1 = inputs/activations private, P0
= nothing private. The weights are the accumulation-critical class
(a fixed witness re-proven every pass), so P2 and P3 are the modes
this memo is about.

## Sources (every number below traces to one of these)

| tag | file | what is taken from it |
|---|---|---|
| S0 | `docs/zkmatrix-poc/U_PERF3_ROUTE_B_THROUGHPUT.md` (lane YY, 2026-09-02) | the yardstick (50 tok/s at 30B = 1.55e12 proven MAC/s = 20 ms per token, 10.2 s per 512-token proof); the shapes (§1.3); the witness sizes (§1.5); the per-proof anatomy (§2); the hardware ranges (§3.3: laptop GPU 5-15x, 4090 15-75x, H100 25-180x over the laptop CPU row); the ZK constructions and the P1 surcharge (§4.2-4.3); the weights-private problem and its three options (§4.4); the partial-knowledge modes (§4.5); the counted H100 floors (§6.4, §7.2); the P0/P1 tokens/s rows (§6.2-6.3) |
| S1 | `PROGRESS_UPERF3.md`, "Agent QQ status (wt-uperf3-qq) — round 10" | the lattice line's per-proof weight-side opening with the per-model part warm: 2.08 s [MEASURED] at the 12x512 weight group on the RTX 4070 Laptop; the constants K1-K8; the projection table (8B: 62-75 s design of record, 14-27 s Variant B; 30B: 280-340 s / 65-125 s) [MODEL] |
| S2 | `PROGRESS_UPERF3.md`, "Agent UU status (wt-uperf3-uu) — round 11" | the hash prototype's design of record (three commitments per layer: W, A, H; the PCS parameters; what is opened where); the commit-phase anatomy |
| S3 | `hashline/src/pcs.rs`, `merkle.rs`, `layer.rs` | the column check as built (`verify`: per sampled column, a blake3 column hash, a Merkle path of log2(4n) digests, and (k + 1) inner products of length m); the W claims per layer (`layer.rs` lines 518-520: Wg and Wu blocks at one point, Wd blocks at a second point — k = 2 column-weight groups, so k + 1 = 3 row-combinations per W commitment) |
| S4 | `docs/zkmatrix-poc/U_PERF3_THROUGHPUT_MODEL.md` (lane TT, 2026-09-02) | the lattice line's per-proof weight side (§2.4), its hardware ranges (§3.3: 4090 2-6x, H100 2-8x over the laptop WITH its GPU), the budget arithmetic (§7) |
| S5 | `docs/zkmatrix-poc/AGGREGATION_LITERATURE.md` §4.4 item 4, §5 (family (e)), §4.5 | the "field-switch + link" pricing (~59 KB of link rows per tensor x 3 tensors x 32 layers ~ 5.7 MB) and its Z1 obligation (the link must be simulatable); the family-(e) wrap pricing ("minutes-to-hours class") |
| S6 | `docs/zkmatrix-poc/TARGET_CONTRACT.md` Amendment A1; `docs/zkmatrix-poc/ZK_GAP_OPTIONS.md` §6-7 | the ZK rule; the modes P0-P3; the accumulation asymmetry; the lattice line's Tier Z surcharge per masked floor |
| S7 | `docs/zkmatrix-poc/GADGET_MODULUS_DECISION.md` §3.5, §6; `docs/zkmatrix-poc/GATE_ALTERNATIVES.md` option 2 | the link rows as designed: w = 11-bit random integer functionals, l = 24 rows, 59 KB per tensor, per-row miss 2^-11, aggregate 2^-264; the integer-exact (no-wrap) pattern; prototyped in `gadget_link_spike.rs` |
| S8 | `docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md` §3 | the "A + B" row (B as the fast channel, A as the audit channel over the SAME committed int8 weights) |
| L1 | Ames, Hazay, Ishai, Venkitasubramaniam, "Ligero" (CCS 2017) | the ZK form of the interleaved-code commitment (random padding of rows; mask rows) [EXTERNAL, as read in S0 §4.2] |
| L2 | Golovnev, Lee, Setty, Thaler, Wahby, "Brakedown" (ePrint 2021/1043) | the tensor-form opening; ZK by the Ligero techniques [EXTERNAL] |
| L3 | Chiesa, Forbes, Spooner (ePrint 2017/305); Xie et al., "Libra" (CRYPTO 2019) | zero-knowledge sumcheck by a committed masking polynomial; the linear-time GKR prover [EXTERNAL] |
| L5 | Xie, Zhang, Song, "Orion" (ePrint 2022/1010) | proving the column checks of a linear-code commitment inside an inner argument ("code switching") [EXTERNAL; what was read is stated in §3] |
| L7 | Grassi, Khovratovich, Schofnegger, "Poseidon2" (ePrint 2023/323) | the arithmetic hash's round structure over 64-bit fields [EXTERNAL; what was read is stated in §3] |
| HW | the spec-sheet table copied in S0 §3.2 | SM counts, memory bandwidths, board power [EXTERNAL, spec sheet] |

## 0. The answer in one paragraph

(lands with §0's commit)

## 1. The problem, restated for a newcomer

**How the hash line commits to the weights, and what an opening
shows.** One layer's weights (8B: 3 x 4096 x 14336 = 1.76e8 int8
values; 30B stand-in: 3 x 5376 x 21504 = 3.47e8) are laid out as a
matrix of m rows by n columns (n = 2^16 / 2^17 at S0 §5.2's
per-commitment optimum, so m = 2,688 / 2,648 rows; at the measured
125M rig n = 2^14, m = 288). Each row is stretched by a
Reed-Solomon code to 4n symbols (rate 1/4), and the 4n stretched
columns are hashed, one blake3 digest per column, into a Merkle
tree whose 32-byte root is the commitment (S3 `pcs::commit`). To
prove a statement about the committed values — here, the value of
the weights' multilinear polynomial at a random point, which is
what the matmul sumcheck leaves behind — the prover sends one
random combination of the rows in the clear (the "clear vector": n
extension-field elements), and the verifier checks it against the
root by sampling 256 of the 4n columns at random (the sample is
derived from the transcript by Fiat-Shamir, so it is public),
receiving those 256 columns in full — m values each — with their
Merkle paths, and checking at each sampled column that the same
combination of the column's entries equals the encoding of the
clear vector at that position (S3 `pcs::verify`). Because the code
has relative distance 3/4, a prover who committed to something far
from a valid encoding is caught with probability 1 - (3/4)^256 =
1 - 2^-106 [COUNTED, S3 module header].

**Why the columns accumulate into the weights.** Every opened
column is m raw field elements. The encoding is systematic, so as
built one column in four IS a raw column of int8 weights; and even
the non-systematic columns are public linear functions of the row.
The zero-knowledge form (L1, S0 §4.2 (a)(i)) fixes the SINGLE-proof
leak: append Q = 256 uniformly random pad symbols to every row's
message before encoding, and any 256 opened positions of that
row's codeword are jointly uniform — the first proof reveals
nothing. But the pad is chosen once, at commit time, and a cached
commitment is reused. The second proof samples 256 DIFFERENT
columns: the union is 512 linear equations per row in n + Q
unknowns of which only Q are random, so 256 dimensions of every
weight row are now determined. After (n + Q)/Q proofs the sampled
positions span the row and the weights are recoverable from the
published proofs by linear algebra: **65 proofs at the measured
125M parameters (n = 2^14) [COUNTED, S0 §4.4]; 257 proofs at 8B
and 513 at 30B at the §5.2 optimum n (2^16 / 2^17) [COUNTED, the
same formula]** — hundreds of proofs, i.e. minutes of a deployment
that proves every request. A larger pad does not help: at fixed
soundness the pad and the number of sampled columns scale together
(rate 1/2 needs 403 columns and is determined after 42 proofs at
125M; rate 1/8 after 78; S0 §4.4), so the horizon sits at
(n + Q)/Q ~ n/Q for any Reed-Solomon parameters. Two smaller
per-proof leaks ride alongside and are counted in §3: the clear
vector itself is a random linear functional of the whole matrix
(L1's answer is a "mask row" — a random row committed alongside
the data and added to the clear vector — but a mask row INSIDE a
cached commitment is itself fixed, so two proofs' masked vectors
differ by an UNMASKED functional (rho - rho')^T M: in any
cached-commitment design the masks must come from a fresh
per-proof commitment); and the sumcheck's terminal evaluation
W~(r) is one linear functional per proof, hidden by the fresh
masking polynomial of the zero-knowledge sumcheck (L3, S0 §4.2
(b)-(c)).

**Why the activations do not have this problem.** An activation
commitment is made fresh for every proof, with fresh pads and fresh
salts, and — under the one-proof-per-witness rule S6 §6 states —
its 256 columns are seen ONCE, ever, against that witness. The pad
hides them perfectly within the proof, and there is no second proof
against the same activations for the equations to accumulate in.
This is ZK_GAP_OPTIONS §6's accumulation asymmetry (S6), applied to
Route B: the weights are a fixed witness re-proven on every pass,
so any per-proof leak accumulates against the same secret; the
activations are never re-proven. It is also why S0 found P1 (open
weights, private inputs) cheap (+2-8%) and P2/P3 (private weights)
structurally expensive on this line: the hash commitment is
binding but not hiding across openings, and hiding it across
openings costs either a fresh commitment every proof (§2), or never
opening it in the clear (§3), or a commitment from a different
assumption that IS hiding across openings (§4), or something the
literature has that this repository has not read (§5).

## 2. Option 1 — re-commit the weights on every proof

### 2.1 S0's counted baseline, restated

Under P2/P3 the weight commitment is rebuilt for every proof with
fresh pad symbols and fresh salts, so no two proofs open the same
codeword and §1's equations never accumulate. The cost is the
"commit W" phase of the measured pass, paid per proof instead of
per model: 2.19 s of the 23.0 s at 125M (38.7 ns per weight, 8
threads) [MEASURED, S0 §2.1]; scaled by the weight count, **218 s
per proof at 8B and 832 s at 30B on the laptop CPU** [MODEL from
MEASURED, S0 §4.4] — +44% / +54% on a 512-token prefill proof and
+143% on a decode proof, where it exceeds everything else. On one
H100 the phase has a counted floor: the encoded matrix is 4
elements of 8 bytes per weight, all of it hashed — 180 GB at 8B,
688 GB at 30B — and at a device hash rate of 30-100 GB/s [MODEL,
no source in this repository; lane XX rung 2 measures] that is
**1.8-6 s per proof at 8B and 7-23 s at 30B** [MODEL on spec
sheet, S0 §4.4], against a 10.2 s budget per 512-token proof and a
20 ms budget per decode token. This memo carries S0's two numbers
unchanged and adds what S0 did not count: the batching
amortisation (§2.3), the hash choice (§2.2) and the NTT share.

### 2.2 What the re-commit is made of: hashing, the NTT, the hash choice [COUNTED on spec sheet]

Per row of the weight matrix the commit does an inverse NTT of n
points and a forward NTT of 4n points (39 butterflies per weight,
S0 §2.1) and then hashes every stretched column. At 30B that is
8.4e11 butterflies per proof; at the H100's counted Goldilocks
rate (1.67e13 int32 ops/s at ~7 int32 ops per 64-bit modular
multiply = 2.4e12 multiplies/s, S0 §7.2) the butterflies are ~0.35
s, and the 3-5 passes the NTT makes over the 688 GB encoded matrix
at 3.35 TB/s are 0.6-1.0 s of memory traffic — **the NTT is
0.4-1.3 s of the 7-23 s re-commit (2-15%); the hashing is the
rest.** The zero-knowledge form (L1: Q random pad symbols per row,
so n + Q is not a power of two) makes the inverse transform a
2^15/2^17/2^18-point interpolation instead of 2^14/2^16/2^17
(+0-25% of the NTT part, S0 §4.3): negligible inside the
re-commit.

The hash choice, then, IS the re-commit's cost:

| hash | rate per device | 30B re-commit (688 GB) | 8B (180 GB) | label |
|---|---:|---:|---:|---|
| blake3 (as built, S3) | 30-100 GB/s on an H100 [MODEL, no source; lane XX rung 2 measures]; 1-3 GB/s per CPU core on 2-4 KB inputs | **7-23 s** | 1.8-6 s | [MODEL on spec sheet] |
| Poseidon2 over Goldilocks, t = 12 (rate 8 elements = 64 B per permutation) | 2.81 us per permutation single-thread in Rust = 23 MB/s per thread [EXTERNAL, L7 Table 2; COUNTED rate]; on a GPU 1e7-1e8 permutations/s = 0.6-6 GB/s [MODEL, no source in this repository] | 110-1,100 s | 30-300 s | [MODEL] |
| blake3 at rate 1/2 (Q 256 -> 403 for 2^-106, S0 §4.4) | as blake3; 16 B hashed per weight | 3.4-11.5 s (+57% opened columns per proof) | 0.9-3 s | [COUNTED from the blake3 row] |
| a 31/32-bit field (the competitor's lineage, S0 §7.2) at rate 1/2 | as blake3; 8 B hashed per weight | 1.7-6 s | 0.45-1.5 s | [MODEL: a change of the whole prover's field] |

So an arithmetic hash is NOT a candidate for a per-proof re-commit
(10-100x slower per byte than blake3 on every part in the table);
it enters this memo only in §3, where the hash is evaluated inside
a proof and the per-model tree is built once. Rate and field are
the two levers that shrink the re-commit, at 2x each, and both are
design changes to the whole prover (bytes, soundness bookkeeping).
The re-committed matrix must be held until the opening reads its
256 columns: 11.1 GB per layer at 30B, 5.7 GB at 8B (S0 §1.5),
committed, opened and discarded layer by layer — it fits an H100
next to the 21.5 GB int8 weights and a layer's 16 GB activation
working set (49 GB), and the 538 GB per-model cache of S0 §1.5 is
simply not built under this option.

### 2.3 The batching amortisation [COUNTED]

The re-commit, like the linear weight opening, is paid ONCE PER
PROOF, so it is amortised over however many tokens a proof covers:
T tokens of one request (prefill) or B requests together (batched
decode, or B prefills in one proof). One condition, counted from
the code: the B requests must be proven as ONE statement — their
token rows stacked into one X matrix — so that the matmul
sumcheck leaves ONE evaluation claim on each weight tensor. If
instead each request left its own claim point, the weight folds
(`fold_cols_i8`, S3 `layer.rs` lines 380-416) and the opening's
row-combinations (`fold_rows_multi`: k + 1 combinations for k
distinct column-weight groups, S3 `pcs.rs`) would both scale with
B, and the amortisation would vanish. Stacking is what S0 §1.2
already assumes ("batching at B requests is the same amortisation
as prefill with T = B"); this memo makes the reason explicit.

Per token, then: (re-commit + weight opening) / (B x T) + the
activation side per token. The constants, on one H100 [S0 §2.3,
§6.4, §7.2]:

| term | 8B, floor | 8B, scaled constants | 30B, floor | 30B, scaled constants |
|---|---:|---:|---:|---:|
| re-commit per proof | 1.8-6 s | 1.2-8.7 s (218 s / 25-180) | 7-23 s | 4.6-33 s (832 s / 25-180) |
| weight opening per proof | 10-20 ms | 0.84-6.0 s (151 s / 25-180) | 25-60 ms | 3.2-23 s (576 s / 25-180) |
| activation side per token | 2.5-7.2 ms | 3.7-27 ms | 7-21 ms | 11-76 ms |

("floor" = S0's spec-sheet floor: tuned kernels, weights
HBM-resident, the device saturated; "scaled" = the measured laptop
CPU constants divided by S0 §3.3's H100 range 25-180x. Both are
[MODEL]; the truth is expected between them, and lane XX's port is
the first measurement.)

**Prefill (T = 512 per request), tokens/s on one H100, option 1
(P2/P3):**

| B requests per proof (tokens per proof) | 8B floor | 8B scaled | 30B floor | 30B scaled | working set per layer at 30B [COUNTED, S0 §2.4] |
|---:|---:|---:|---:|---:|---:|
| 1 (512) | 53-165 | 18-130 | **15-48** | 5.4-39 | 16 GB |
| 4 (2,048) | 98-293 | 29-213 | **31-96** | 9.7-71 | 64 GB |
| 16 (8,192) | 126-362 | 35-256 | **42-127** | 12-87 | 258 GB — exceeds the H100 |
| 64 (32,768) | 135-385 | 36-263 | **46-139** | 13-93 | 1 TB |
| P0 for comparison (any B) | 140-400 | 26-187 | 47-138 | 8.3-60 | |

Arithmetic for one cell, 30B floor at B = 16: (7-23 s) + (0.025-0.06
s) + 8,192 x (7-21 ms) = 64-195 s per proof, / 8,192 tokens = 7.9-24
ms per token = 42-127 tok/s.

**Decode (T = 1 per request), tokens/s on one H100, option 1:**

| B requests per proof | 8B floor | 8B scaled | 30B floor | 30B scaled |
|---:|---:|---:|---:|---:|
| 1 | 0.17-0.55 | 0.068-0.49 | **0.043-0.14** | 0.018-0.13 |
| 4 | 0.66-2.2 | 0.27-2.0 | 0.17-0.57 | 0.07-0.5 |
| 16 | 2.6-8.6 | 1.1-7.6 | **0.68-2.2** | 0.28-2.0 |
| 64 | 9.8-32 | 3.9-28 | **2.6-8.5** | 1.0-7.5 |
| P0 for comparison, B = 1 / 16 | 33-80 / ~130-370 | 0.16-1.2 / 2.5-19 | 12-33 / ~40-110 | 0.04-0.3 / 0.6-4.5 |

Reading:

1. **At B x T >= ~8,000 tokens per proof the re-commit stops being
   the binding term**: 7-23 s over 8,192 tokens is 0.9-2.8 ms per
   token, under the activation side's own floor of 7-21 ms. Option
   1 then sits within ~10% of the P0 row (42-127 vs 47-138 at the
   floor). That is 50 tok/s at 30B **only in the upper half of the
   band, only for 16 or more 512-token prefills per proof**, and
   at a per-layer working set (258 GB at B = 16) that no single
   board holds — the token-streaming design S0 R3 names is a
   precondition, not an option.
2. **Decode never gets there.** Even 64 requests per proof leave
   the re-commit at 110-360 ms per token at 30B: 2.6-8.5 tok/s at
   the floor. The decode budget (20 ms per token) would need B >=
   ~400-1,200 concurrent requests per proof, at which point the
   proof is a prefill in all but name.
3. The scaled-constant column is the honest one until lane XX
   lands: there, 30B prefill under option 1 reaches 50 tok/s only
   at B >= 16 and only at the top of the hardware range (87-93).
4. The proof bytes and the verifier are S0's P3 row: +1-8% bytes,
   +2-15% verifier over P0 (S0 §4.3); the re-commit adds no bytes.

## 3. Option 2 — never reveal the columns (Orion-class hidden openings)

(lands with §3's commit)

## 4. Option 3 — the lattice-hybrid weight commitment

(lands with §4's commit)

## 5. Option 4 — anything else the literature offers

(lands with §5's commit)

## 6. THE TABLE

(lands with §6's commit)

## 7. The verdict for the ruling

(lands with §7's commit)

## What is not known

(lands with §7's commit)
