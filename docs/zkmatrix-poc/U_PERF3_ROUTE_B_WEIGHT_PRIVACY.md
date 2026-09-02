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

(lands with §2's commit)

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
