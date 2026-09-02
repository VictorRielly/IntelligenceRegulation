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

(lands with §1's commit)

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
