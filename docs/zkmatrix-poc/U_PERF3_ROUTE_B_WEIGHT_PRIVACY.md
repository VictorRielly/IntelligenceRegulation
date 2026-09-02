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

### 3.1 The idea, and what was actually read [EXTERNAL]

Instead of SENDING the 256 sampled columns and letting the verifier
run the column check, the prover PROVES, inside a second
zero-knowledge argument, that columns consistent with the
committed root exist and pass the check. Nothing about the cached
commitment is ever opened in the clear, so there is nothing to
accumulate.

What this memo read of L5 (the ePrint 2022/1010 page and the PDF's
text, extracted in this session): the abstract ("O(N) prover time
of field operations and hash functions and O(log^2 N) proof size
... the prover time is 3.09 s and the proof size is 1.5 MB for a
circuit with 2^20 multiplication gates"); the technique — "a proof
composition named 'code switching' proposed in [RR20] ... using
the encoding circuit of the linear-time encodable code"; the inner
system — "In our construction, we use the ZKP scheme in [ZXZS20]
[Virgo] as the second ZKP. The scheme is based on the interactive
oracle proofs (IOP) and the witness is encoded using the
Reed-Solomon code. Therefore, the technique is called code
switching"; Protocol 6's statement — "Witness: y_γ0, y_1, C1[:,
idx] ∀ idx ∈ Î ... Public input: γ0, r0, r1, y. Public
information: Î and I chosen by the verifier" (the clear vectors
and the sampled columns are the inner witness; the challenges and
the claimed value are public); the commitment's shape — "a Merkle
tree commitment for every column C2[:, i] of the n x n codeword C2,
and finally ... another Merkle tree on top of their roots", with
the verifier checking "the Merkle tree proofs of c1[idx], cγ0[idx]"
(a few ENTRIES of the sampled columns' own codewords — no hash is
evaluated inside the inner circuit); the parameters — an
expander-based code of relative distance 0.055 opening t = 1,568
columns, SHA-256, the field GF((2^61 - 1)^2), single-threaded on a
Xeon 8375C. Successor read: den Hollander and Slamanig, "A Crack
in the Firmament: Restoring Soundness of the Orion Proof System
and More" (ePrint 2024/1164, abstract only): "Orion in its current
revision is still unsound (with and without the zero-knowledge
property)"; the corrected scheme, Scorpius, keeps the linear-time
prover "without additional assumptions". Also read (abstract only):
Hirner, Krieger, Piber, Sinha Roy, TCHES 2025 (ePrint 2024/1918) —
an FPGA acceleration of Brakedown/Orion whose "end-to-end speedup
with Virgo" is quoted at up to 3.85x against a 463 s software
baseline at degree 2^28: evidence that at scale the outer
commitment, not the inner Virgo proof, dominates the pipeline.

### 3.2 Why the literal Orion form is NOT enough here [COUNTED]

Orion's inner oracle IS the cached column codeword (a Merkle tree
per column): each proof opens some q_in positions of each of the
256 sampled columns' codewords (Virgo's queries), and the pad that
makes those positions uniform is chosen when the column is
committed — once. The accumulation of §1 reappears one level down:
256 x q_in equations per proof against the N = 3.47e8 unknowns of
a 30B layer; at a FRI-class q_in of 100-300 the layer is
determined after N / (256 q_in) ≈ 4,500-13,000 proofs — 10-25x
slower than as built (513), not zero. A partial-knowledge leak,
bounded and slow, but not zero-knowledge across proofs; it fails
the rule. The form that meets the rule — call it option 2b — makes
the sampled columns the witness of a FRESH per-proof inner
commitment (fresh pads, so nothing accumulates) and proves their
binding to the cached outer root INSIDE the inner argument. That
means the outer tree's hash function is evaluated in-circuit, so
the cached W tree must use an arithmetic hash (Poseidon2, L7); the
inner witness's own commitment, whose openings nobody proves, can
stay blake3. The rest of this section prices 2b.

### 3.3 The exact inner statement at 8B and 30B [COUNTED from S3 `pcs::verify`]

Per sampled column j of one layer's W commitment (m rows), the
inner circuit must contain exactly what `verify` does with that
column, plus the mask rows of §1:

1. the column hash: m field elements absorbed at rate 8 (Poseidon2
   t = 12, capacity 4 = 256 bits) = m/8 permutations, plus one
   per-column salt element for hiding;
2. the Merkle path to the cached root: log2(4n) compressions
   (two 4-element digests in, one out: a t = 8 permutation);
3. the (k + 1) = 3 row-combinations restricted to the column: m
   extension-by-base multiply-adds each (2 base multiplies + 2
   adds), with the row weights rho_g public (S3 `layer.rs` lines
   518-520: Wg and Wu blocks at one point, Wd at a second, so k = 2
   column-weight groups, k + 1 = 3 with the proximity row);
4. the comparison with Enc(v'_g)[j] - Enc(U)[g][j]: v' (the masked
   clear vectors) are public and the verifier re-encodes them as
   built; U is the per-proof fresh mask matrix (3 rows of n per
   layer, §1), whose column j — 3 elements — is inner witness with
   its own Merkle path to the per-proof U root (log2(4n) more
   compressions), so that rho^T Enc(M)[:, j] is never public.

Public inputs: the W root (per model), the U root (per proof), rho
(from the transcript), the 256 indices, and Enc(v')[j] at those
indices. One W commitment per layer holds Wg, Wu and Wd (S2's
design of record; one `pcs::commit(&w_pcs, ..)` per layer in
`layer.rs`), so the statement is 256 columns x L layers; a single
per-model W commitment (m = L x m_layer rows) would have the same
column-hash count and L times fewer paths — a < 6% difference,
since column hashing dominates. Counted per layer:

| | 8B | 30B |
|---|---:|---:|
| layers L; W per layer as n columns x m rows (S0 §5.2's optimum n) | 32; 2^16 x 2,688 | 62; 2^17 x 2,648 |
| column-hash permutations per column (m/8, t = 12) | 336 | 331 |
| Merkle compressions per column, W tree + U tree (2 x log2 4n) | 36 | 38 |
| permutations per column | 372 | 369 |
| **permutations per proof** (x 256 x L) | **3.05e6** | **5.86e6** |
| native Goldilocks multiplies per t = 12 permutation: R_F = 8 full rounds x 12 S-boxes (x^7 = 4 multiplies) + R_P = 22 partial rounds x 1 S-box + the linear layers [COUNTED from L7's round structure; R_F = 8 is L7 eq. (1); R_P = 22 for Goldilocks t = 12 is the value the open Goldilocks Poseidon2 parameter sets instantiate — EXTERNAL, not re-derived here] | ~700 | ~700 |
| hash part, native multiplies | 2.1e9 | 4.1e9 |
| inner-product part: 256 x m x 3 x 2 x L | 1.3e8 | 2.5e8 |
| **inner statement, native Goldilocks multiplies per proof** | **~2.3e9** | **~4.4e9** |
| inner witness (the sampled columns): 256 x m x L elements | 2.2e7 (176 MB) | 4.2e7 (336 MB) |

Cross-check against S0 §4.4's "62 x 3 x (256 x ~2,600 x 3) ≈ 3.7e8
multiply-adds plus ~1e5 hash evaluations ... of order 1e9
constraints": S0 counted all three commitments (A and H need not
be in the inner proof — they are fresh per proof and stay in the
clear under P2 or Ligero-padded under P3) and counted only the
paths as hashes; once the hash is arithmetic the column hashes
themselves (336 MB of elements per proof at 30B) are the dominant
term. Same order of magnitude, different composition.

### 3.4 Which inner prover, its time, and the hash swap's cost on the OUTER commit

**The inner prover** is a zero-knowledge sumcheck/GKR over a
data-parallel circuit: 256 x L identical Poseidon2 instances with
the inner products folded in. The reference construction is
Libra's linear-time GKR with its masking (L3); the seed in this
repository is `hashline/src/sumcheck.rs` (S3), whose measured
constant — 27.5 ns per table-entry at 8 threads for a 13-table,
degree-4 zero-check (S0 §2.1) — is the only sumcheck-prover rate
measured here. Its zero-knowledge is the standard pair: masking
polynomials for the sumcheck rounds, and Ligero-ZK pads on the
inner witness's own commitment, which is FRESH per proof (blake3:
32 B per element over 176 / 336 MB of witness = 0.7 / 1.3 GB
hashed: **7-23 ms at 8B, 13-45 ms at 30B** at 30-100 GB/s
[COUNTED]). The per-proof U commitment (3 x 4n elements per layer,
a per-column leaf of 24 B and a 4n-leaf tree, blake3) is another
0.74 GB (8B) / 2.9 GB (30B) hashed: **7-25 ms / 29-95 ms**
[COUNTED]. Neither needs an arithmetic hash.

**The prover overhead constant K_ov [MODEL]: 5-20x native.** A
sumcheck prover evaluates every constraint at (degree + 1) points
per round over tables that halve each round; S0 §2.1's measured
zero-check spends ~110 extension multiplies (~330 base) per table
entry on a constraint whose native cost is ~20 multiplies — ~15x,
the pessimistic end; linear-time GKR provers over layered circuits
are reported with small constants (L3) — 5x the optimistic end.

| inner prover, per proof | 8B | 30B | label |
|---|---:|---:|---|
| field multiplies (native x 5-20) | 1.2e10-4.6e10 | 2.2e10-8.8e10 | [COUNTED x MODEL] |
| H100, counted floor (2.4e12 multiplies/s, S0 §7.2) | **5-19 ms** | **9-37 ms** | [MODEL on spec sheet] |
| laptop CPU 8T (1.0e9 base multiplies/s: S0 §2.1's 1.3e8 Fp2 multiplies per layer in 0.375 s, 3 base per Fp2) | 12-46 s | 22-88 s | [MODEL from MEASURED constant] |
| H100, scaled (laptop CPU / 25-180) | 0.07-1.8 s | **0.12-3.5 s** | [MODEL on MODEL] |
| plus the two fresh blake3 commitments (inner witness + U) | 14-48 ms | 42-140 ms | [COUNTED on spec sheet] |

**As a fraction of the P0 row** (S0 §6.4, §7.2; the whole W-side
surcharge = inner prover + fresh commitments):

| cell | P0 per proof | option 2 adds | fraction |
|---|---:|---:|---:|
| 30B prefill (512 tokens), floor | 3.7-11 s | 0.05-0.18 s | +0.5-5% |
| 30B prefill, scaled | 8.6-62 s | 0.16-3.6 s | +2-40% (central ~4%: ~1 s on ~25 s) |
| 30B decode, floor | 30-80 ms | 51-177 ms | **x2.7-3.2** (the fresh commitments and the inner proof are each the size of the whole row) |
| 30B decode, scaled | 3.2-23 s | 0.16-3.6 s | +5-16% |
| 8B prefill, floor / scaled | 1.3-3.7 s / 2.7-20 s | 0.02-0.07 s / 0.08-1.8 s | +1-5% / +3-9% |
| 8B decode, floor | 12-30 ms | 19-67 ms | x2.6-3.2 |

**The hash swap on the OUTER commit phase.** Only the per-model W
tree changes; A and H stay blake3, so the ON-CLOCK hash rate —
the dominant term of every S0 floor — is untouched. Per model
[COUNTED from the sizes; rates EXTERNAL/MODEL]: the encoded W
matrix is 4N elements (8.6e10 at 30B, 2.3e10 at 8B) = 4N/8
column-absorption permutations plus 4n x L tree compressions:
**~1.1e10 permutations at 30B, ~2.8e9 at 8B.** At L7's Table 2
rate (2.81 us per t = 12 permutation, Rust, one thread) that is
8.6 h / 2.2 h of one CPU thread — ~1.1 h / ~17 min at 8 threads
[MODEL]; on a GPU at 1e7-1e8 permutations/s [MODEL, no source in
this repository] **2-18 min at 30B, 0.5-5 min at 8B**, once per
model, off the contract's clock (S0 §1.1) — 5-150x blake3's 7-23 s
for the same tree. The cached object is the same 538 / 141 GB
encoded matrix (the 256 column reads per proof — 336 / 88 MB
column-major over the host link, S0 §2.3 — are unchanged) plus its
tree (2^19 x 62 x 32 B = 1 GB at 30B).

### 3.5 Proof bytes and verifier time

**Bytes at 30B per 512-token proof [COUNTED from S0 §5.1's
formula].** As built the W side sends 256 x 2,648 x 8 B x 62 = 336
MB of columns and 256 x 19 x 32 B x 62 = 9.6 MB of paths. Option 2b
replaces both with: one inner proof — with a Ligero-class inner
PCS over the 4.2e7-element inner witness at its own optimum (n =
2^16, m = 640, k + 1 = 2): 256 x 640 x 8 + 2 x 2^16 x 16 + 256 x 18
x 32 = 3.6 MB, plus the GKR/sumcheck transcript (~0.2 MB) — plus
U's 256 opened columns per layer (3 elements and a 19-digest path:
62 x 256 x 632 B = 10 MB): **~14 MB in place of 346 MB.** At 8B:
176 + 4.7 MB become ~7.6 MB. With a WHIR-class inner PCS (S0 §5.3)
the inner proof is ~0.1-0.3 MB. The masked W clear vectors (3 x
2^17 x 16 B x 62 = 390 MB at 30B) are NOT touched by option 2; they
fall with the PCS swap of S0 §5. So the 30B proof goes 1.51 GB ->
~1.18 GB in the sqrt class, and to the S0 §5.3 6-12 MB row after
the swap of both layers.

**Verifier.** The as-built W work per layer (256 blake3 hashes of
21 KB columns, 256 x 2,648 x 3 multiply-adds, 256 paths: ~0.3-0.6 s
single-threaded per 30B proof [COUNTED]) moves into the inner
proof; the verifier instead checks the inner proof — the inner
PCS's 256 columns x 640 x 2, two NTTs of 2^18, the GKR rounds: ~10-30
ms [MODEL] — and U's trivial openings. The 3 W clear-vector
re-encodings per layer (62 x 3 NTTs of 2^19 at 30B, ~2-4 s
single-threaded [COUNTED, S0 §5.2's term]) remain, and remain the
reason the <= 2 s line needs the PCS swap. Net: the verifier is
slightly FASTER than as built.

### 3.6 Per proof, or amortisable?

Per proof: rho, the indices and U are fresh every time. Batched
across the L layers into ONE inner proof (identical circuits — the
GKR is data-parallel). Amortised over the B x T tokens of the proof
exactly as the weight opening is (§2.3): at B x T = 8,192 the
30B surcharge is 0.006-0.44 ms per token. NOT amortisable across
proofs by any construction counted here. One candidate exists for
deferring column checks across proofs — Arc (Bünz, Mishra, Nguyen,
Wang, ePrint 2024/1731, CRYPTO 2025: "a hash-based accumulation
scheme ... for claims about proximity of claimed codewords to the
Reed-Solomon code", unbounded steps, random-oracle only [EXTERNAL,
abstract]) — but whether the accumulated instances stay HIDDEN is
not addressed in its abstract, and it is not counted.

### 3.7 What option 2 rests on (honesty)

(a) Nothing is built: `hashline` has no Poseidon2, no inner prover,
no zero-knowledge form. (b) K_ov = 5-20x is a model with one
measured anchor. (c) R_P = 22 for t = 12 over Goldilocks is taken as
instantiated by the public parameter sets, not re-derived from L7's
formula (1); a different t or R_P moves the hash term
proportionally. (d) The composition's soundness needs its own
written argument: the successor paper found Orion's published
revision unsound [EXTERNAL, ePrint 2024/1164]. Our column check is
the Reed-Solomon/Ligero one (distance 3/4, 256 columns, S3), not
Orion's expander code, and the inner statement is a plain circuit
over it; the risk sits in the composition — the fresh U mask, the
salted cached tree, two Fiat-Shamir layers — which needs a
simulator and an extractor, the same obligation class as S0 §4.2's
last bullet and S5 §4.5's "the cross-commitment link argument must
be simulatable too". (e) The per-model hash rate is unmeasured and
off the clock. (f) The decode row is where option 2 costs most (the
fresh commitments are the size of the whole P0 decode row); the
prefill row barely notices it.

## 4. Option 3 — the lattice-hybrid weight commitment

### 4.1 The shape

The lattice line's weight commitment is hiding by construction
(MLWE), and it is re-openable with a fresh challenge every proof
without the columns problem: what leaks per opening is a bounded
set of functional images — the "floor" of S6 §3 — and the masked
(Tier Z) path hides those (S6 Amendment A1). So the hybrid keeps
the WEIGHTS on the lattice channel — committed once per model as
the built weight group (lane QQ's per-model build: the tier-1
commitments, the tier-2 U, the int8 layout; **2.34 s at 12x512
[MEASURED, S1]**; 233 s at 8B, 1,040 s at 30B on the laptop GPU
[MODEL, S1]) and opened per proof by the two-tier opening (**2.08 s
at the 12x512 weight group with the per-model part warm
[MEASURED, S1]**; 62-75 s at 8B and 280-340 s at 30B in the design
of record, 14-27 / 65-125 s with Variant B [MODEL, S1]; lane VV is
measuring Variant B) — and carries everything else (the activation
commitments, the helpers, the lookups, the requant identities, the
Hadamard check) on the hash channel at Route B's rates. This is
S8's "A + B" row made concrete, and S5 §4.4 item 4's
"field-switch + link" with the fast prover on the hash side.

### 4.2 The cross-commitment link — the crux

The two channels meet at the matmul. `hashline` proves gacc = X Wg,
uacc = X Wu and z = h8 Wd with Thaler's matrix-multiplication
sumcheck (S2), which ends in evaluation claims on the multilinear
extensions of BOTH factors at a random point in Fp2 (Goldilocks,
degree-2 extension): X~(r_i, r_k) and Wg~(r_k, r_j) (S3 `layer.rs`
lines 379-381, 518-520). The weight claim must now be opened from
the LATTICE commitment. What object carries it, and what it costs,
depends on which side runs the matmul.

**Form 3a — the matmul on the lattice channel.** The three matmuls
are proven by the lattice engine exactly as in the built pass (its
claim layer over q31 rings, S1's "b_rows"), so the weight-side
object is the lattice engine's own ct-claim and needs no bridge.
But the matmul's OTHER terminal claims land on activation tensors
— X, the accumulators (through g8, rg, u8, ru), h8, z — which must
then also be lattice-committed, per proof, fresh (the built
activation group), and tied to their hash-side twins (which the
lookups and requant checks read) by S7's link rows: two
commitments of the SAME integers at two moduli, l = 24 random
w = 11-bit integer functionals, each proven on both sides ("Two
linear ct-claims per row assert the SAME y_l", S7 §3.2), the
integer y_l revealed and range-gated. On the hash side any
public-weight linear functional is one sumcheck of the tensor's
size (batched over the rows: cheap). This is the RECORDED link,
applied verbatim; its price is that ~30% of the activation witness
(4 T f + 2 T d of the 13 f + 5 d elements per token-layer, S0
§1.5 [COUNTED]) is committed and opened on the lattice channel at
the lattice line's activation-side rates — S4 §2.2/2.4: 250-491 s
built, 90-240 s two-tier, per 8B x 512 proof on the laptop; 30% of
that, x2.87 at 30B, over the H100's 2-8x: **12-215 s per 30B
prefill proof** on top of the weight opening [MODEL on MODEL]. Form
3a is therefore never cheaper than the lattice line's own
activation side for those tensors; it is the audit-channel form
(S8), not the fast one.

**Form 3b — the matmul on the hash channel, the weight claim
bridged.** The object is an MLE evaluation claim W~(r) with r in
Fp2: a linear functional of the int8 weights whose coefficients
eq(r, i) are 128-bit field elements. The lattice claim layer
proves linear functionals of the committed rings with coefficients
mod q31 = 2^31 - 399, and those are INTEGER-exact only when the
functional cannot wrap: |<xi, v>| < q/2 (S7 §3.3's w_max rule).
**No recorded design opens a Goldilocks-field claim from the q31
commitment; the recorded link (S7) ties two COMMITMENTS of the same
integers at two moduli through revealed small-coefficient integer
functionals.** The cheapest honest bridge this memo can construct
is that pattern applied to one claim value:

1. Split each coefficient's two 64-bit limbs into 11-bit digits:
   c_i = sum_{l<2} u^l sum_{t<6} 2^{11 t} c_{i,l,t}. Then W~(r) =
   sum_{l,t} u^l 2^{11 t} F_{l,t} with F_{l,t} = sum_i c_{i,l,t} w_i
   — **12 integer functionals per weight claim with 11-bit
   non-negative coefficients** (S7's w = 11 class), 36 per layer.
2. The lattice side proves each F_{l,t} EXACTLY as an integer (a
   ct-claim with the range gate); the verifier recombines them mod
   p — an integer identity holds in every field. Exactness needs
   |F| < q/2 on the grounding side: |F| < 2^11 x 2^7 x N; for one
   30B weight tensor N = 5376 x 21504 = 2^26.8, so |F| < 2^44.8 —
   it does NOT fit q31 (2^30) and fits the q46 gadget class (q46/2
   = 2^45) with 0.2 bits to spare (10-bit digits, 14 functionals,
   give 1.2 bits). At q31 the functional would have to be chunked
   into pieces of < 2^(23 - w) coordinates — with w = 1 and 128
   bit-planes that is ~3,600 functionals per tensor per claim, and
   the two-tier fold's cost is proportional to the number of
   challenge rows G (S1: the fold-as-GEMM, G = 64-96 today), so
   ~40-100x the measured opening: dead. **The bridge therefore
   requires the weight group committed at a >= 46-bit modulus** —
   the q46 gadget class already designed for bit tensors (S7 §3.1),
   here carrying the int8 VALUE rings (Variant B's committed
   object, S1) — a per-model change to the committed object of the
   same ruling class as Variant B, with 46-bit modular reduction in
   the per-proof fold [MODEL: x1-1.5 on S1's K2/K4].
3. Per proof the lattice side serves 36-42 extra functionals per
   layer (2,200-2,600 per proof at 30B) — the same class as the
   64-96 challenge rows the built opening already serves per weight
   group (S1), so the opening's cost is **x1-1.5** [MODEL]. Each
   revealed F is one linear functional of a whole tensor: 12
   equations per proof against 1.2e8 unknowns — the lattice line's
   floor-leak class, ~1e7 proofs from recovery by linear algebra
   [COUNTED], which Victor's rule masks anyway: on the lattice side
   the ct-round's g-masks hide y_l ("Both claims ride their side's
   ordinary ct-round (g-masks, reveals, combined mask images)", S7
   §3.2); on the hash side the sumcheck's terminal claim is already
   masked by the fresh Libra polynomial (S0 §4.2 (b)-(c)), so the
   recombination target W~(r) + c g~(r) is masked too, and the
   twelve lattice masks must satisfy ONE linear relation (their
   recombination = c g~(r) mod p) while staying inside the range
   gate. That mask design is not recorded; its cost class is the
   Tier Z masked-floor surcharge (S6 A1: +272,640-281,856 B per
   masked floor at 8B) per weight tensor per proof [MODEL].
4. Bytes: S0's "~59 KB of link rows per tensor" is S7 §3.4's row —
   "full FFN tensor | 24 [rows] | 2,519 B | 59.0 [KB/link] | 7.4
   [MB/pass at 128 linked tensors]", bytes per row = "revealed y (8
   B) + q46 reveal h_l and mask image W_l (736 B each) + q31 h_l and
   W_l (496 B each) + amortized g-slot share on both sides" — as
   scaled by S5 §4.4 item 4 to "~59 KB/tensor x 3 tensors x 32
   layers ~ 5.7 MB". The 3b bridge is one-sided (only the lattice
   side reveals) with 12-14 rows: **~15-20 KB per tensor per proof**
   [COUNTED from S7's row composition], 2.8-3.7 MB per 30B proof
   (186 tensors), plus the masked-floor surcharge. Prover time for
   the functionals is noise-class (S7 §3.4: 2.25e11 MACs per pass =
   3.3 s at 22 threads; here 2.6e11 per 30B proof, inside the fold
   on the device).

Either form leaves the lattice line's Tier Z simulator obligation
(S5 §4.5: "the cross-commitment link argument must be simulatable
too, and the double-committed witness doubles the surface the
rank/recovery battery class must cover") plus a new one for the
Goldilocks-side recombination. Nothing in this subsection is
built; the ct-claim machinery, the q46 gadget layer design and the
link prototype (`gadget_link_spike.rs`, S7 §3.6) are the pieces.

### 4.3 The hybrid's per-proof cost on one H100 [MODEL on MODEL]

**Weight side (lattice).** S1's 30B rows use an assumed 64 x 5120 x
25600 = 2.52e10-weight shape; rescaled linearly to S0's 30B
stand-in (2.15e10, x0.85 [COUNTED]): design of record 239-290 s,
Variant B 55-107 s on the laptop GPU; 8B 62-75 / 14-27 s. The
two-tier opening is lattice-line work — device GEMMs plus
host-side tails (S1's attribution: the fold's host tail K5 is 0.38
s of the 2.08 s; the recursion 0.34 s) — so it is normalised with
S4 §3.3's lattice ranges (H100 2-8x over the laptop WITH its GPU),
not S0's 25-180x. With the 3b bridge's x1-1.5:

| per-proof weight opening, one H100 | 8B | 30B |
|---|---:|---:|
| design of record (digit rings) | 7.8-57 s | 30-218 s |
| Variant B (value rings; lane VV measuring) | **1.75-20 s** | **6.9-81 s** |

Memory: the fold walks every committed weight ring per proof, so
the store must be device-resident. The design of record's digit
store is 45 GB at 8B and 172 GB at 30B — the 30B store does NOT
fit an H100 unless packed to 2 bits (43 GB [MODEL], S4 §3.4), else
it streams from the host at ~3.4 s per pass; Variant B's int8 value
rings are 5.6 / 21.5 GB and fit. Variant B is the only 30B form on
one board, for memory as much as for time.

**Hash side.** The whole activation side of Route B at P1's
surcharge (x1.02-1.08): per 512 tokens at 30B, floor 3.6-10.8 s
(7-21 ms per token), scaled 5.4-39 s; at 8B floor 1.3-3.7 s, scaled
2.7-20 s (S0 §6.4, §7.2). Links and masks: noise-class time (§4.2
item 4), bytes as counted.

**Tokens/s, option 3 with Variant B (hash side at the floor; the
scaled hash side in parentheses) [MODEL on MODEL]:**

| cell | per proof | tokens/s |
|---|---:|---:|
| 30B prefill, B = 1 (512 tokens) | 6.9-81 + 3.6-10.8 = 10.5-92 s (12-120 s) | **5.6-49** (4.3-42) |
| 30B prefill, B = 16 (8,192 tokens) | 6.9-81 + 57-172 = 64-253 s (93-704 s) | **32-128** (12-88) |
| 30B decode, B = 1 | 6.9-81 s | 0.012-0.14 |
| 30B decode, B = 16 | (6.9-81 + 0.11-0.34) / 16 | 0.2-2.3 |
| 8B prefill, B = 1 | 1.75-20 + 1.3-3.7 = 3.1-24 s | 21-165 |
| 8B prefill, B = 16 | 1.75-20 + 21-59 = 23-79 s | 104-356 |
| 8B decode, B = 1 | 1.75-20 s | 0.05-0.57 |
| design of record instead of Variant B: 30B prefill B = 1 / B = 16; decode | 34-229 s / 87-390 s; 30-218 s | 2.2-15 / 21-94; 0.005-0.03 |
| design of record, 8B prefill B = 1; decode | 9.1-61 s; 7.8-57 s | 8.4-56; 0.018-0.13 |

### 4.4 Reading

1. The hybrid inherits the lattice line's per-proof weight
   opening — the term lanes TT and QQ showed keeps the lattice line
   at 0.5-15 tok/s. At 30B it reaches 50 tok/s **only with Variant
   B, only at B >= 16 prefills per proof, only in the upper half of
   BOTH hardware ranges**; never at a single 512-token prefill
   (5.6-49 at best); never in decode (< 2.5 tok/s at B = 16).
2. Both openings are linear in the weights, but the lattice fold
   is over rings with modular arithmetic and a recursion, the hash
   opening is two int8 multiply-adds per weight: 6.9-81 s against
   25-60 ms at 30B on the same board — the 100-1,000x that decides
   §6. Option 2 keeps the hash opening and hides it; option 3
   replaces it.
3. What option 3 buys that option 2 does not: the weight-side
   guarantee is the lattice line's (MLWE hiding; the audit channel
   of S8, where "a mismatch between the two proofs is itself an
   audit signal"); a 1-byte-per-weight per-model store (Variant B)
   instead of the hash line's 25-byte cache; no arithmetic hash.
   What it costs: two proof systems to maintain and audit (S5
   §4.6's permanent burden), an unrecorded bridge that forces a
   q46-class weight commitment (a ruling), the Tier Z mask design
   for twelve revealed integers per tensor, and 10-100x option 2's
   weight-side per-proof time.

## 5. Option 4 — anything else the literature offers

(lands with §5's commit)

## 6. THE TABLE

(lands with §6's commit)

## 7. The verdict for the ruling

(lands with §7's commit)

## What is not known

(lands with §7's commit)
