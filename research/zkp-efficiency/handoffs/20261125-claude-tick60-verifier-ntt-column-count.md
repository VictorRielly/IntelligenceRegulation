# Research handoff: the NTT and column-product work of today's verifier, counted from `pcs.rs` (2026-11-25, claude tick 60, queue item 100)

From the Claude background researcher. Reading and arithmetic only: no build, no run, no web search, no Git. Written: this file,
`20261125-claude-tick60-verifier-ntt-column-count.py` (standard library, under a second) and its output
`20261125-claude-tick60-verifier-ntt-column-count.out.txt`. Triage material, not a work order: nothing here changes what the prover
commits; any change to the verifier's checks needs the owner's ruling, a new profile version and re-proving in Lean.

**Read** (full text of the code, no web): `ops/zkp-mvp/gpu-metal/zkp-core/src/pcs.rs` (`verify_zk_tagged` 1235-1336, `encode_row_zk`
674-693, `coset_powers` 661-670, the A26 loop 1167-1212, `salt_leaf_keyed` 710-715), `zkp-core/src/ntt.rs` (`transform` 69-108),
`hashline/src/private_block/shape.rs` (`a_groups` 2806-2824, `h_groups` 2832-2835, W16R2 constants 305-323), `run_fork.rs:2929-2973`,
tick 56, 57 and 58 handoffs, the A26 README (`results/zk60_a26_app_20261107/README.md`, verifier profile at :91-99) and the D55 A/B
log (`results/zk60_effplan_20261105/a12merge_d55_ab.log:222-246`). Labels: COUNTED (file:line), MEASURED (record), DERIVED (script), ASSUMED.

## 1. Result

**Pass on the item's line, with one correction to tick 58 that matters more than the pass.** The NTT term is **75 to 94 ms a block, one
thread, factor 1.25** (DERIVED; COUNTED butterflies x MEASURED rates). The removed work is **118 to 136 ms** and the B6a block
(stays plus the spike's BAT + tower) a range **17.8 ms wide at each rate**, under the 25 ms line:

| rate | B6a as built, ms a block | rational switch row, ms a block |
|---|---|---|
| 1/8 | 45.5 to 63.3 | 34.4 to 52.2 |
| 1/4 | 49.5 to 67.3 | 34.6 to 52.4 |
| 1/2 | 63.3 to 81.1 | 35.4 to 53.2 |

(tick 58: 45.7 to 91.5 as built, 34.7 to 63.6 rational.) The upper end of each range rests on a cap that the record gives, not on counts
(section 4): treat it as bounded, not measured.

**Correction.** The 141.9 ms a block (4.54 s / 32) is the 2026-11-05 record. A26's sparse column loop (`HL_A26_PCS_SPARSE`, default on,
`pcs.rs:1175-1178`) was merged 2026-11-07, so the column work in that record is the dense loop and **today's verifier is faster than
141.9 ms a block by a saving no retained W16R2 record gives**. A bound: at most 32 to 49 ms (section 5), so today's block is 93 to 141.9
ms, and the B6a verifier's gain against today's is **x1.15 to x3.1 as built** (tick 58: x1.6 to x3.1), not x1.6 to x3.1.

## 2. The NTTs, counted (COUNTED, `pcs.rs:1290-1303`, `ntt.rs:55-108`)

- **Which vectors:** all 47. `all_vecs` is every group vector plus the proximity vector: A has 36 groups + 1, H has 9 + 1
  (`shape.rs:2806-2835`; W16R3 design `:228`). Each is an Fp2 vector of n + q = 16,664 entries, and **each component is encoded
  separately** (`re`, `im`), with no skip for an all-zero imaginary part: **94 encodes a block**. The proximity vector is encoded the same
  way. The code runs the vectors under `par_iter`; on one thread the 94 are serial.
- **One encode** (`encode_row_zk`): an inverse NTT of size 2^14 (n; 14 x 8,192 = 114,688 butterflies, then 16,384 multiplications by
  1/n), a pad fold, 16,664 pointwise multiplications by coset powers, a forward NTT of size 2^15 (nn; 15 x 16,384 = 245,760 butterflies).
  **360,448 butterflies, 11.0 per output point.** The loop is a plain radix-2 Cooley-Tukey with a bit-reversal pass and a strided twiddle
  table (`ntt.rs:76-106`): no zero-input shortcut, because n + q = 16,664 is above nn/2 = 16,384.
- **Per block:** 94 x 360,448 = **33.88 M butterflies**, plus 3.11 M Fp multiplications (the 1/n scale and the coset powers), up to 2.3 M
  swaps, and 24.6 MB of encoded output. `coset_powers` adds nn = 32,768 multiplications once per call (A and H each), negligible.
- **Tick 58's NTT term used 3.08 M points x 8 butterflies = 24.6 M**, which counted the forward half alone and not the inverse; the
  right count is 33.88 M (x1.38). That, not the rates, is why its range ran to 103 ms.

## 3. Rates, and the NTT term

- MEASURED, tick 56: the W2 commitment's NTT row loop is serial and runs at **2.11 to 2.18 ns a butterfly all-in** at transform size 2^15
  (the verifier's forward size). All-in includes setup, scatter and the hash of the commit, so it is a mild overestimate for a bare NTT.
- MEASURED, tick 57: 96 forward rows in 5.88 ms on five threads, 11.0 M butterflies: at most **2.67 ns** a butterfly per thread
  (an upper bound: it assumes the five threads were busy throughout).
- Term = butterflies x rate + 3.11 M multiplications x 1.12 ns (BAT's rate, tick 58): **75.0, 77.3 and 94.0 ms.** Factor 1.25: pass.
- The A26 profile of the classifier's verifier (A24 binary, R13 Shieldstral, not this profile) puts `NttTables::transform` at 12.3% of
  running samples (16,209 of 131,602), 14.8% in the A26 binary; that cannot be turned into nanoseconds without a count of blocks verified
  in the 60 s window, which the profile does not give, so it is not used as a rate.

## 4. The columns, hashing and the cap

- **Column products, dense (the loop of the 11-05 record):** 280 x (37 x 2,501 + 10 x 2,602) = **33.20 M `mul_base` products**
  (each two Fp multiplications), matching tick 58's 33.2 M. With A26 on, a group's weight is summed over its nonzero rows only
  (`a26_supports`, `pcs.rs:1182-1192`); the two proximity weights are more than half nonzero and stay dense: 1.43 M products.
  The supports' sizes of the real groups are not retained (they depend on each claim's slice rows), so today's sparse count lies between
  1.43 M and 33.2 M.
- **Hashed bytes:** 280 x (2,501 + 2,602) x 8 = 11.43 MB of columns (BLAKE3, about 178,600 64-byte blocks plus parents), 560 salted leaves
  of one compression each, and 15 path hops x 560 = 8,400 compressions: about 6.1 ms at tick 58's 0.53 ms a MB (tick 58's 12.0 MB included
  salts and paths). This stays under B6a. The transcript absorb of the 47 vectors (12.53 MB) is 6.1 ms (MEASURED, prover side) and goes.
  The group inner products `<v, c>` (45 x 16,384 = 737,280 Fp2 multiplications, 3.7 ms at 5 ns, ASSUMED rate) also go with the vectors.
- **The cap.** The record's whole block is 141.9 ms. Subtracting NTT (75 ms), hashing (6.1), absorb (6.1) and inner products (3.7) leaves
  **51 ms for the dense columns and every non-PCS check together**, i.e. at most 1.54 ns a product (0.96 ns if the NTT is 94 ms). Tick 58's
  1.12 ns a multiplication, taken twice per product, was already too high for this record. The removed work cannot exceed 141.9 - 6.1 =
  135.8 ms. Its low end takes the columns at a 1.0 ns floor (33 ms, ASSUMED): 118.0 ms. Width 17.8 ms.
- **Not removed by B6a and not measured here:** the non-PCS work of `verify_core` (the block digest hashing and the support checks, which are
  31% of the classifier verifier's running samples on real weights in the A26 profile, the slot replay, M, boundaries). If the diagonal-weight
  block carries a share like that, "stays" is above the range's top and the counts at these rates overstate; T-N1 below pins the NTT rate.

## 5. A26: what it does to today's verifier

Only the proximity weights stay dense, so A26 removes at most 32 to 49 ms a block from a dense column term of 33 to 51 ms (the floor, and the
cap with NTT at 75 ms). The A26 README's whole-verifier figure is a classifier at R13: 9.28 to 9.41 s down to 7.19 to 7.50 s a post
(-21%, README :291-292, both A26 verifier changes together). Today's one-thread block is therefore 93 to 141.9 ms; at 32 blocks 2.98 to 4.54 s
(one thread, diagonal test weights). B6a verifier against it, per request: rate 1/8 x1.47 to x3.12, 1/4 x1.38 to x2.87, 1/2 x1.15 to x2.24,
as built; the rational switch row adds about 10 ms off the top of each (tick 58). The remaining wide edge is the unknown size of today's
sparse supports, not the NTT.

## 6. For the record: pruning the verifier's re-encode (DERIVED, script section 6)

The verifier reads 280 of the 32,768 outputs of each encode, but splitting the forward transform after s stages and finishing only the
residue classes hit saves at most a quarter of the forward half (best s = 10: 183,447 butterflies against 245,760; 0.83 of the whole encode),
and direct evaluation at 280 points costs 12.9 x the NTT. The prover-side L9 pruning (4.38 x) relied on 244 of 4,096 residues; here 245 of 1,024
are hit. Not worth a lane; B6a removes the NTTs outright.

## 7. Falsifiable tests (none scheduled)

- **T-N1 (one CPU-only micro-bench, under 1 s, 25 MB; the NTT rate in place).** On the Mac, one thread, time `encode_row_zk` over 94 random
  rows at n = 2^14, nn = 2^15, q = 280, 7 repetitions, median. Pass: 33.9 M butterflies in 65 to 95 ms (1.9 to 2.8 ns including the
  scale and coset multiplications) and the NTT term stays in section 3's range; kill: under 50 ms, then the NTT term falls to under 55 ms
  and the 17.8 ms width moves with it (more of the 141.9 ms is column or non-PCS work). It needs a test-only harness; it runs nothing heavy.
- **T-V1 (tick 58, still decides).** The D55 verifier at 1, 2, 3 and 6 workers with phase marks, on a receipt from today's binary, so A26 is
  in. Pass: the A, H and M opening phases' one-thread time is the figure section 5 bounds (93 to 141.9 ms a block).

## 8. Honest effect

Committed words per request: 0 changed. Proved tokens per second: none (verification runs after the clock). What this tick changes is a
figure in the size-step case: the B6a verifier saving against today's is x1.15 to x3.1, not x1.6 to x3.1, because the record under it
predates A26. Any claim of a verifier speed-up for B6a should quote a post-A26 one-thread record.

## 9. Risks and not verified

- The 2.11 to 2.18 ns rate is all-in for a commit loop on the same Mac; the bare verifier loop was not timed. The 2.67 ns upper bound
  assumes full busy time on five threads.
- The 1.0 ns product floor and the 5 ns Fp2 multiplication are ASSUMED. The cap is arithmetic on one record whose binary predates A26.
- Today's sparse supports (rows per group) were not counted: they need the claim slices of a real block.
- Not read: `zk_rhos` (the row-weight tables, per group, rows long), `group_zclaims`, and the cost of the Fp2-to-component copies.
- The A26 profile is a different profile (R13, rate 1/4, real weights); no W16R2 verifier phase record exists after A26.
