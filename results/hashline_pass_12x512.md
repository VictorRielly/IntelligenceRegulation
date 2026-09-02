# hashline — the hash-based comparison row at 12x512 (U-PERF3 lane UU, 2026-09-02)

The measured record behind the [MEASURED] row in
docs/zkmatrix-poc/PROVING_CHANNEL_OPTIONS.md section 3. Every number
here is [MEASURED] on the WSL laptop (Core Ultra 9 185H, 22 threads,
15 GB; CPU only — no GPU code exists in `hashline/`), label
[WSL-BOX NOISY-SHARED] (two other lanes were building/running on the
box; load average 2-3 during the runs). Commit: see the status section.

## What was proven

THE SAME statement the lattice engine's 21.0 s row proves: the 125M FFN
pass, 12 layers x 512 tokens (T 512, d 768, f 2048), exact int8
semantics (TARGET_CONTRACT.md section 2): per layer gacc = X.Wg and
uacc = X.Wu with exact accumulators; floor requant by the sidecar
shifts with the remainders proven in [0, 2^sh); the FROZEN 256-row
silu-int8-table-v2 member (digest-pinned: bdf8bc71.. / 06399348..)
applied to the requantized gate as a proven pair lookup; the Hadamard
with u; the requant of h; z = h.Wd with its requant to the sidecar's z
width; u8/h8/z range-proven in [-128, 127]. The witness is the WSL
re-export (results/m125_ffn_export_wsl/, 48/48 tensor sha256s and
12/12 z sha256s reproduced by `hashline check-export` / `hashline
chain 12`). 2.899e10 MACs per pass (12 x 512 x (2 x 768 x 2048 +
2048 x 768)).

NOT proven (same as the lattice line's composed FFN tower): attention;
the seams between layers (X_l is committed fresh per layer, not tied
to z_{l-1}); X and weight int8 ranges are DECLARED, not range-proven
(the lattice statement's open M3 finding — the same gap on both
lines). NOT zero-knowledge (no masking rows; the Ligero ZK addition is
known and cheap, not built).

## The stack and its parameters (the assumption class)

- Field: Goldilocks p = 2^64 - 2^32 + 1; every challenge in
  F_{p^2} = F_p[u]/(u^2 - 7) (|F_{p^2}| ~ 2^128).
- PCS: Ligero/Brakedown tensor form; Reed-Solomon rate 1/4 (rows of
  n = 2^14 encoded to 2^16 via NTT, systematic); blake3 Merkle over
  columns; Q = 256 random column checks shared by every functional on
  a commitment; one clear row-combination per column-weight group plus
  one proximity combination. Three commitments per layer: W (9 x 2^19
  weight blocks, m = 288 rows), A (activations + X + z, 65 x 2^17
  elements, m = 520), H (LogUp helpers, 54 x 2^17, m = 432).
- Matmuls: the matrix-multiplication sumcheck (g and u batched with a
  random lambda on one point, 8 rounds over k' in 2^8 with the three
  d-blocks summed; d over k in 2^11 with the three output blocks
  batched). Prover cost = the matrix SIZES (a fold of X against
  eq(r_i) and of W against eq(r_j)), not the MACs.
- Lookups: LogUp with committed helper columns h = 1/(alpha - v1) +
  1/(alpha - v2) (one F_{p^2} helper per TWO lookups), the helper
  identity as a degree-4 zero-check batched with the Hadamard
  zero-check, helper sums as plain functionals, the table side computed
  by the verifier from multiplicities sent in the clear; tables tagged
  by gamma * tag (SiLU pairs v + beta S[v]; int8; [0, 2^sh) per shift).
- Every pending evaluation claim is folded into the two zero-check
  sumchecks (20 and 17 variables) so A and H are opened at two points.
- Fiat-Shamir over blake3; one transcript chains the 12 layers.
- Soundness bookkeeping: proximity test (1 - delta/3)^Q with delta =
  3/4 -> (3/4)^256 = 2^-106; LogUp (N + |T|)/|F_{p^2}| with N ~ 2^23
  lookups per layer -> 2^-105 per layer, 2^-101 over 12 layers;
  sumcheck rounds sum(deg)/2^128 ~ 2^-120; blake3 2^-128; Fiat-Shamir
  in the random-oracle model. => ~100-bit, hash-only (+ ROM) class.

## The runs (12 x 512, `hashline pass 12 512 --threads N`, /usr/bin/time -v)

| threads | PROVE (incl. the 3 commitments) | VERIFY | proof bytes | peak RSS | proven MAC/s |
|---|---:|---:|---:|---:|---:|
| 8T (run 1) | 22.92 s | 3.12 s | 66,844,928 B | 1.56 GB | 1.265e9 |
| 8T (run 2, tamper pass; prove same) | 23.07 s | (reject at layer 6) | same | — | 1.256e9 |
| 8T (run 3) | 23.69 s | 2.76 s | same | 1.56 GB | 1.224e9 |
| 8T (run 4) | 21.48 s | 2.76 s | same | 1.56 GB | 1.349e9 |
| **8T p50 of the 4 proves** | **23.0 s** | **2.8 s** | **66.8 MB** | **1.56 GB** | **1.26e9** |
| 16T | 32.20 s | 5.69 s | same | 1.56 GB | 9.0e8 |
| 22T (run 1) | 39.41 s | 7.87 s | same | 1.57 GB | 7.4e8 |
| 22T (run 2) | 37.09 s | 8.08 s | same | 1.57 GB | 7.8e8 |

Witness load + the plain integer chain (not in the prover clock): 0.9-1.5 s.
Per-layer prove at 8T: 1.80-2.49 s (layer 0 carries the thread-pool warm-up).

Prover phases, summed over 12 layers (8T, run 1): commit W 2.19 s |
commit A 3.98 s | helpers + commit H 4.58 s | matmul g/u 0.77 s |
matmul d 0.60 s | zero-check 20 4.50 s | zero-check 17 2.30 s | PCS
openings 3.96 s. I.e. commitments (NTT + blake3) 47%, the two
zero-check sumchecks 30%, openings 17%, the matmul sumchecks 6%.

Thread scaling is INVERTED beyond 8 threads on this box (reproduced:
16T +40%, 22T +60-70% on prove; verify 2.8 -> 8 s). Not chased.
Hypotheses [MODEL]: the hybrid part (6 P + 8 E + 2 LP-E cores; the
E-cores are weak on the 64x64->128 multiplies Goldilocks reduction
uses) under a laptop power limit; rayon chunking that is not
E-core-aware; WSL2 vCPU scheduling. The 8T figure is the row (it is
also the lattice line's ZK_THREADS=8 convention).

Proof size per layer 5.57 MB = column openings 256 x (288 + 520 + 432)
rows x 8 B = 2.54 MB + 10 clear vectors x 2^14 x 16 B = 2.62 MB +
Merkle paths 3 x 256 x 16 x 32 B = 0.39 MB + sumchecks/claims ~10 KB.
This is the sqrt-size Ligero/Brakedown class by construction; a FRI /
STIR / WHIR-based PCS would give ~100s of KB per pass at more prover
time and is the known trade — not built.

## Tamper legs (all REJECT; `hashline layer 0 512 --all-tampers --threads 8`, and one pass-level leg)

| leg | what the cheating prover does | rejected by |
|---|---|---|
| flipped X entry | commits X with one entry +1; the chain is honest | g/u matmul sumcheck round 0 |
| flipped Wg entry | commits Wg with one entry +1 | g/u matmul sumcheck round 0 |
| out-of-range remainder | rg[i] += 2^sh_g, g8[i] -= 1 (gacc identity kept), multiplicities padded so the totals pass | the LogUp identity |
| wrong table entry | a8[i] += 1 with the whole downstream chain recomputed consistently | the LogUp identity |
| wrong requant | h8[i] += 1, rh unchanged | zero-check 20 round 0 |
| wrong z | z[i] += 1 | d matmul sumcheck round 0 |
| pass-level: wrong requant in layer 6 of the 12-layer chained transcript | as above | layer 6 rejects (`pass 12 512 --tamper requant`) |

Rung 2's standalone differential (3 layers x 16 tokens, the verifier
evaluating its own plain matrices, no PCS): honest ACCEPT x3; flipped
X / flipped Wg / wrong claimed gacc REJECT x3 each.

## Side by side (the honest comparison)

| | lattice line (zkmatrix-rs, 2026-08-18 reference) | hashline (this record) |
|---|---|---|
| statement | 125M FFN 12x512 exact int8 | THE SAME (digest-identical witness) |
| box / device | WSL laptop, 8T + RTX 4070 Laptop GPU, QUIET | WSL laptop, 8T CPU ONLY, NOISY-SHARED |
| prove (incl. commit) | 18.0 s (2.5 commit + 15.5 prove) [GPU]; 81.5 s total CPU-only | 23.0 s p50 (21.5 min) |
| verify | 1.7 s (8T) | 2.8 s (8T) |
| total wall | 21.0 s p50 [GPU] | 25.8 s (+1.1 s witness derivation) |
| proof bytes | 1.51 MB | 66.8 MB (44x) |
| peak RSS | 6.7 GB | 1.56 GB |
| proven MAC/s | 1.4e9 [GPU + 8T] / ~3.6e8 CPU-only | 1.26e9 [CPU 8T] |
| assumptions | MLWE/MSIS lattice, 2^-220 knowledge error, post-quantum | hash-only + ROM, ~100-bit (2^-101..106), post-quantum |
| zero-knowledge | yes (declared private set) | NO (prototype) |
| exact-integer semantics | yes | yes (same integers; the same open M3 gap on X/W ranges) |

Reading: on the CPU alone, the hash-based prover of the same statement
lands at parity with the lattice line's GPU-assisted reference clock
and ~3.5x under its CPU-only clock, with 4.3x less memory and 44x
larger proofs, after one lane-day of untuned Rust. This is the number
Victor asked for; what it does NOT say is anything about 30B / H100
throughput — that is a [MODEL] extrapolation left to the memo.
