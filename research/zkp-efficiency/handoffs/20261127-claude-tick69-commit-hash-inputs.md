# Research handoff: what the commitment hash kernel reads, and the rate it runs at (2026-11-27, claude tick 69)

From Claude, the background researcher (D50). Queue item 109 (pins the inputs of tick 67's test T-P1, H167b). Clock at writing 2026-11-27T03:53Z.

**Scope.** Local reading and arithmetic only; no web, no build, no run, no Git. Written: this file, `20261127-claude-tick69-commit-hash-inputs.py` and `.out.txt` (every DERIVED number comes from the script). Read, in the prover that runs (`ops/zkp-mvp/gpu-metal/`): `hashline/src/gpu/metal.rs` (`hash2_on` 529-538, `encode_hash` 544-570, `commit_impl` 2933-3126, `metal_commit_zk` 3135-3143), `hashline/src/gpu/metal_kernels.metal` (`k_hash_cols` 1153-1235, `k_hash_chunk` 1243-1277, `k_hash_merge` 1279-1309), `zkp-core/src/pcs.rs` (`commit_zk_owned_with_tag` 782-817, `salt_leaf_keyed` 710), `hashline/src/zk.rs` 820-876 (the M commitment), `hashline/src/gpu/mod.rs` 980-1017; records: tick 21, tick 62, tick 67 and its coordinator check, `results/zk60_a28_app_20261107/` (`nb3.log`, README 126-142, `nbench/variants.metal` 290-326), `results/zk60_w16r2_shield_block_20261120/summary.json`, `results/zk60_effplan_20261105/census.log:218`. **Triage material, not a work order.** Labels: COUNTED (file:line), MEASURED (record), DERIVED (script), ASSUMED.

## 0. Headline (pass on the volume, one correction to tick 67's rate range)

- **PASS.** The kernel hashes **167.44 M words a block** (1,339.6 MB), within 0.13% of tick 67's 167.2 M (pass line: 5%). The rows are the traced ones, **2,504 (A) and 2,606 (H)**, not the census model's 2,501 and 2,602 (difference 7 rows, 0.14%, source of the gap not found).
- **Implied rate.** MEASURED old-form diag hash at this shape: 3.39 ms = **395 GB/s, 56% of the 700 GB/s copy roofline**; the production two-pass form is **2.4 to 2.7 ms, 500 to 566 GB/s (71 to 81%)** [DERIVED from the A28 bench ratio at another shape, not measured at W16R2]. So tick 67's "3.4 to 3.9 ms" is the old form (3.39) and a scaled share (3.9); production is about 0.7 ms faster.
- **CORRECTION to tick 67 section 3.** Its low end of 32 ms a block for a Goldilocks hash used an ASSUMED ceiling of 478 G mulmod/s. The A28 bench already measured the shipped `gl_mul` in registers with no memory traffic: **125.4 G/s** (mul only), 105 G/s for a full butterfly. At 736 multiplications a permutation (15.41 G a block) that is **123 ms at best, 147 to 183 ms at butterfly-like rates**, not 32 to 172. Extra over BLAKE3: about **+120 to +180 ms a block, +3.8 to +5.8 s a request** at full pass-through, and T-P1's kill line (at least 30 ms) is predicted to be met four to six times over.

## 1. Exactly what is hashed

All COUNTED unless marked.

- **One kernel family, two commits a block.** `commit_impl` runs once for A and once for H (`metal.rs:2933`); `rows = data.len() / n` of that commit (`pcs.rs:788`). Inside each, the leaves are `encode_hash(c, enc, &e, &leaves_buf, cvs, &ha)` on the encoded buffer `e` (`rows x nn` words, `metal.rs:2950, 3016`).
- **Width.** Encoded width `nn = 2^15` (log line `commit 2504 x 2^14 -> 2^15`), n = 2^14 message words. The 256 or 280 hiding pad symbols are not extra words: they are inside the coset code (K = n + q coefficients encoded to 2^15 points, tick cycle-4 census). **No Q appendix is hashed**; every one of the 32,768 columns is hashed over all `rows` words.
- **Per column** (A 2,504 words, H 2,606): A is 20,032 B = 20 chunks, 313 blocks + 19 parents = **332 compressions**; H is 20,848 B = 21 chunks, 326 + 20 = **346**. Per block: 10.88 M + 11.34 M = **22.22 M compressions** (DERIVED). The same column of words as a rate-8 sponge is 313 and 326 permutations, **20.94 M a block**.
- **Not in this kernel.** The salted leaves (`salt_leaf_keyed`, `pcs.rs:806`) and the Merkle build (`pcs.rs:807`) run on the host (rayon) after the device returns the *unsalted* leaves (`metal.rs:3105-3106`): about 131 K compressions a block, 0.59% of the kernel's. **M is not in the same buffer**: it is a separate commitment of 50 rows x 4,096 columns hashed on the CPU (`zk.rs:842, 872`). So the 167.44 M words are A and H only, in two separate commit calls.
- **Dispatch (two-pass, default on, `hash2_on`).** `k_hash_chunk`: grid 32,768 x chunks (655,360 threads for A, 688,128 for H), threadgroup 64, one thread per (column, 1,024-byte chunk); thread (j, c) loads word `(c*128 + blk*8 + t) * nn + j` (`metal_kernels.metal:1137-1147`), so adjacent threads read adjacent words of one row (coalesced 256 B per SIMD group). Then `k_hash_merge`, one thread per column, over `cvs` (A 20.97 MB, H 22.02 MB, 43.0 MB written and read back: **+6.4% traffic** over the column bytes). Keyed: the key is the BLAKE3 IV; no extra input words.
- **Bytes through the kernel [DERIVED]:** 1,339.6 MB of columns + 86.0 MB of chaining values + 2 MB of leaves, about 1.43 GB a block.

## 2. Rates

| Figure | Value | Source |
|---|---:|---|
| Old-form diag hash, A / H, W16R2 arm | 1.660 / 1.727 ms (0.663 us a row both: linear) | MEASURED, tick 21 (5 warm passes) |
| Same, both commits | 3.39 ms, **395 GB/s**, 6.56 G compressions/s | DERIVED |
| Bench, 4,577 rows x 2^16, old form | 5.469 ms, 439 GB/s | MEASURED, `nb3.log:34` |
| Bench, two-pass | 4.237 ms, **566 GB/s**, 9.40 G compressions/s | MEASURED, `nb3.log:35` |
| Bench, chunk pass only | 3.951 ms, 607 GB/s | MEASURED, `nb3.log:38` |
| Two-pass at W16R2, old diag x 0.775 | 2.62 ms, 510 GB/s | DERIVED |
| Same at the bench byte rate / at "about 500 GB/s" | 2.37 / 2.68 ms | DERIVED |
| Copy roofline floor for 1,339.6 MB | 1.91 ms | DERIVED at 700 GB/s (K0) |

Reading: the old form at this shape runs lower (395 against 439 GB/s) because it has only 32,768 threads; the two-pass form is the one in production and is 71 to 81% of the roofline, at 9.4 G compressions a second, which is also near the ALU side (a compression is about 800 32-bit operations, ASSUMED), so the hash is not a lever either way (tick 42's finding stands). No production-form hash time at a W16R2 shape is in any record I found (the `hash` field of the commit log line has 1 ms resolution: 0.002 s at both commits); **the 2.4 to 2.7 ms is derived, not measured.**

## 3. The forward NTT behind the 14.0 ms

Tick 21's 14.0 ms is the diag forward (6.90 + 7.13 ms), `MODE_PLAIN`, on **5,110 rows (2,504 + 2,606) of 2^15 points**: 1,255.8 M butterflies unpruned (5,110 x 2^14 x 15), **89.5 G/s**. Two points tick 67 did not carry: (a) the diag form is the A28 pruned head (extent 2^14 is at most 2^(15-1), `metal.rs:593`), so up to 2 of 15 stage-equivalents are skipped and the rate is 78 to 90 G/s, not exactly 89.6; production is `MODE_ZK` (extent 2^14 + q, not pruned) or, with `HL_METAL_FUSED_RS=1`, the fused three-pass path whose forward is not separated in any trace; (b) the forward includes the tail, which is memory-bound, so it is a lower bound on the arithmetic rate. **The bench measured the ceiling directly** (`nb3.log:40-42`, `variants.metal:292-326`, 1.65 G butterflies each, 11 stages in registers): butterfly 105 G/s, `gl_mul` alone 125.4 G/s, add+sub alone 159 G/s; the forward head at 84 G/s (unpruned). So a 478 G/s mulmod ceiling has no support in any record; the measured one is about 125 G/s.

## 4. What this does to tick 67 (DERIVED, section 4 of the script)

At 15.41 G multiplications a block (736 a permutation: 4 x 8 x 12 full-round S-box products, 4 x 22 partial, 12 x 22 diagonal; the structure of the standard width-12 x^7 instance, ASSUMED to be the one a wrapper would use; 20.94 M permutations): 478 G/s gives 32 ms (tick 67's floor, unsupported); **125.4 G/s gives 123 ms; 105 G/s 147 ms; 84 G/s 183 ms**. That is 134% to 200% of the 91.46 ms block GPU, +3.8 to +5.8 s a request over a BLAKE3 pass of 2.4 to 2.7 ms at full pass-through (tick 22 rule a still applies: the stream is not GPU-paced, so some of it may hide, not quantified here). Additions are not priced separately in the first row; they would push the figures up.

## 5. Falsifiable tests (none run)

- **T-P1 (tick 67), revised.** Prediction now: a standalone Poseidon2 column hash of the 5,110 x 32,768 matrix takes **120 to 190 ms**, against the 2.4 to 2.7 ms shipped. Pass for the swap: at most 10 ms (this needs 15 G multiplications in 10 ms, 1.5 T mulmod/s, twelve times the measured `gl_mul` rate); kill: at least 30 ms. Given the prediction, T-P1 is a confirmation of a kill, not a discriminating test, and I would not schedule it; a cheaper falsifier is **T-H1**: run `nb3`'s `gl_mul` probe with the 736-multiplication permutation as the loop body for 2^20 states (seconds, one kernel, no prover change), the prediction is 5.9 to 8.7 ns a permutation amortized over the grid (123 to 183 ms over 20.94 M permutations); pass for the swap at most 0.48 ns (10 ms a block), kill at least 1.43 ns (30 ms), the same lines as T-P1.
- **T-H2 (volume pin, CPU-light).** Assert in a test that for the W16R2 block profile `rows_A * nn + rows_H * nn` equals 167,444,480 and that the census and the traced rows agree; today they differ by 7 rows. Pass: equal or the difference named.

## 6. Expected effect

**Committed words per request:** unchanged (the hash digests the words). **Proved tokens per second:** nothing for the shipped BLAKE3 hash; a field-hash swap costs a cadence of roughly 3.2 s plus up to 3.8 to 5.8 s at full pass-through. Tick 67's conclusion (a trade, not a lever) stands and is stronger: the commitment side now costs more than the wrapper saves unless the wrapper is built and the extra device time hides in the stream's slack.

## 7. Risks and what was not verified

- The rows gap (2,504 / 2,606 traced against 2,501 / 2,602 counted) is not explained; the installed W16R2 Shieldstral profile also reports 2,504 and 2,606 (`MVP_STATUS.md:2801`), so the "8B" arm of the harness may run that geometry. Which profile tick 21's traces were taken at is not re-verified here.
- The production-form hash time at W16R2 is derived from the bench ratio at a different shape (65,536 columns, 36 chunks); a measurement with the commit's `HL_METAL_TIMING=1` and `fused_rs` on would give it directly (the log's 1 ms resolution is too coarse; use the GPU trace).
- The 736 multiplications, the absence of addition cost in the first rows, the 800 operations a BLAKE3 compression, and the claim that a Poseidon2 state loop reaches the `gl_mul` probe's rate (the probe has 16-way independent chains; a permutation's S-box chains are dependent across the 4 products but 12 lanes are independent) are ASSUMED.
- The probe's 125.4 G/s includes a XOR and loads and stores amortized over 88 products, so it is a slightly low estimate of raw `gl_mul` speed; I take it as the measured shipped-code figure, not a hardware limit.

## 8. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H167b (field-hash commitments) stands as a trade, now priced at +120 to +180 ms a block on the commitment side by measured mulmod rates; no new hypothesis.

## Coordinator's check (2026-11-27)

By the Claude co-coordinator. Script `20261127-claude-tick69-commit-hash-inputs-crosscheck.py`, output
`20261127-claude-tick69-commit-hash-inputs-crosscheck.out.txt` (52 checks, all pass; run as `python3 -I <script>`).
The handoff's own script, re-run with both locks free, reproduces its saved output byte for byte.

**Stands.**

- **The volume.** 167,444,480 words a block on rows 2,504 and 2,606. Those are the rows of the 8B arm's trace of
  17 November (`results/zk60_w16r2_shield_block_20261120/summary.json`) and of tick 21. Tick 67 used the census rows
  of 5 November (2,501 and 2,602); the two differ by 0.137%.
- **The kernel facts I read myself:** the two-pass hash is on unless `HL_A28_HASH=0` (`metal.rs:535-538`); rows of a
  commit (`pcs.rs:788`); salted leaves and the tree are made on the host afterwards (`pcs.rs:806-807`); the word a
  thread loads (`metal_kernels.metal:1140-1143`).
- **The correction to tick 67.** Its 478 G products a second was an assumption, in its own words. The bench's
  product-alone probe took 13.155 ms (`nb3.log:42`) for 1,649,770,496 products (4,577 x 2^16 words, 16 a thread, 88
  operations a thread: `variants.metal:291-303`, README line 135), so 125.4 G a second [time MEASURED, rate DERIVED].
  At that rate 15.41 G products take 123 ms; at the butterfly probe's rate 147 ms; at the forward head's 183 ms.

**What this check adds.**

1. **The 7-row gap is one range table plane** (most of the new item 112). Rows are data rows plus two rows a site
   plus a proximity pair (`layout.rs:1340-1342`, `1351-1353`). The census: A 2,279 + 2 x 110 + 2 = 2,501 and
   H 2,514 + 2 x 43 + 2 = 2,602, with 15 table planes in A and 16 in H (`census.log:218-236`). The traced totals equal
   those of the installed classifier profile, read today: A 2,280 + 2 x 111 + 2 = 2,504 and H 2,516 + 2 x 44 + 2 =
   2,606, with 16 and 17 table planes. One more range sub-plane adds exactly one data row and one site pair in A
   (3 rows) and one helper and one site pair in H (4 rows). That the 8B arm's rows split the same way is inferred
   from the equal totals, not read from a record of that arm. Still open: which input gave the census run one
   sub-plane fewer (the set of range widths follows from the calibration).
2. **Per request.** The handoff's +3.8 to +5.8 s is for 32 blocks, the 8B path. The installed classifier has the same
   rows and width a block and 26 layers: +3.1 to +4.7 s at the same price a block.
3. **My own remark under tick 67** estimated 94 to 108 ms a block from assumed operation counts. The measured product
   rate puts the floor at 123 ms. My estimate was low and is replaced by this one.

**Not carried.**

- The shares of a "700 GB/s roofline": that figure is an earlier tick's and was not re-checked here.
- The 2.4 to 2.7 ms for the shipped two-pass hash at this shape is derived from the bench's ratio at another shape.
  No record measures it.
- 123 ms is a floor under assumptions, not a measurement of a field hash: the 736 products a permutation are a
  count for an assumed standard instance, additions are not priced, and the probe's products are independent of
  each other while a permutation's are chained. No field-hash kernel was run.

**Decision.** None needed. Tests T-H1 and T-H2 are not scheduled. A change of hash would change the protocol and its
Lean model, so it would need the owner's ruling whatever a test said.
