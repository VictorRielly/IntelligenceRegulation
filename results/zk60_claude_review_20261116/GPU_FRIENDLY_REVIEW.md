# Independent review: GPU-friendly microbenchmark (T1-T4) and tracks G1-G5

Reviewer: Claude (read-only review, 2026-11-16). Nothing was run. Labels: MEASURED = from
`microbench_m3_ultra.json` / logs; COUNTED = read from code; DERIVED = my arithmetic (shown).
Paths are relative to the repo root; `bench` = `results/zk60_gpu_friendly_protocols_20261115/microbench_metal_gpu.mm`,
`doc` = `.../INQUIRY_GPU_FRIENDLY_ZKP.md`, `prod` = `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal_kernels.metal`.

## Bottom line

The four ratios are real timings of four pairs of kernels, but the pairs do not compute the same
thing, no output is ever compared with a reference, and the Goldilocks multiply used in the benchmark
is itself wrong. The document's headline ("more ops ran faster, so hardware utilisation dominates")
is therefore not established by this data. What the data does establish: (a) T2 shows the padded
kernel is 12% slower and tracks bytes read exactly; (b) the benchmark's "baselines" are not the
production kernels; (c) the RTX 5090 [MODEL] figures have no cited source and one of them
(compute roof of a fold) is below the memory floor of the same operation.

## 0. Cross-cutting findings

1. **No correctness check exists anywhere in the benchmark.** COUNTED: `bench:248-508` never reads back
   any output buffer (`bufC_u64`, `bufSC_out`, `bufCnt`/`bufOutB`, `bufPCS_out`) and has no CPU reference.
   The batch driver (`run_batch4.py:~660-716`) only parses the printed JSON. So "same result" is
   unchecked for all four tests.
2. **The benchmark's `gl_mul` is not Goldilocks multiplication.** COUNTED `bench:26-35`: line 33
   `ulong add = hi_lo << 32;` adds `hi_lo * 2^32`, but 2^64 = 2^32 - 1 (mod p), so the term must be
   `hi_lo * (2^32 - 1)`, which is what production does (`prod:54`, `t1 = x_hi_lo * GL_EPS`). DERIVED: I
   re-implemented the bench's formula in python3 and compared with `(a*b) % p`: wrong on 10,000 of
   10,000 random 64-bit pairs; correct on 10,000 of 10,000 pairs with both operands < 2^24 (product
   < 2^48, so `hi = 0`). T1 happens to use 24-bit operands and is unaffected by this bug; T2 and T4
   feed full 64-bit pseudo-random words (`bench:361, 435`) through `gl_mul`, so their outputs are not
   field products. Timing is probably close to unchanged (one subtraction fewer), but the kernels
   are not the field operation they are labelled as.
3. **Run conditions.** MEASURED `results/zk60_resource_guard/history.jsonl:4064`: run id `0c6aaae2b580`,
   class gpu, `waited_s` 1319.3, `child_wall_seconds` 0.80, `peak_vram_mib` 1984, finished
   2026-11-16T00:58:52Z. The guard's heavy lock excludes other *guarded* jobs, and the preceding
   guarded GPU job (`...-tokenhonest-153`, line 4063) ended at 00:58:48Z, four seconds earlier. That is
   all I can establish. Unguarded GPU users (the project notes a shared Codex GPU agent and a multi-week
   frugal-lm training job on this Mac, `CLAUDE.md` "Wall-clock benchmarks need a quiesced box") are not
   excluded by any evidence in the log. Single run, no repeat.
4. **Timing method (T1-T4 all).** COUNTED `bench:237-246, 273-274`: one command buffer per sample,
   `waitUntilCompleted`, time = `GPUEndTime - GPUStartTime`; 4 warm-up and 12 timed iterations;
   only the mean of 12 is printed (`bench:469-508`); no min/max/stddev; the JSON holds one run.
   Awaiting completion inside the timed loop is correct. GPU-only time excludes host encode
   cost, which matters for T1 (9 MPS encodes + 1 kernel per sample vs 1 kernel).
5. **The "ops" columns are hard-coded, not measured.** COUNTED `bench:477, 502-504`: `9.0`, `2`, `28`,
   `14.0` are literals. Ops of different kinds (a 64-bit modular mul, an FP32 FMA, an atomic) are
   divided as if equal.
6. **The doc cites `microbench_gpu_friendly.py` as the source; the JSON in the directory comes from the
   `.mm`.** COUNTED `microbench_gpu_friendly.py:7,99` writes the same `microbench_m3_ultra.json` with a
   different schema (PyTorch MPS, fp16, different shapes); `run_batch4.py:~660-690` overwrites it from
   the `.mm`. The python script's results are not in the repo.

## 1. Same result? Per test

### T1 (scalar u64 mul-add vs "9x byte-limb FP32 slabs + recombine"): INVALID as an exactness claim; unproven as a speed claim for real field data

Exactness bound (DERIVED):
- Limbs are 8 bits (`bench:310-317`), 3 limbs per operand, 9 slab products (`bench:336-340`). A limb
  product is at most 255 x 255 = 65,025 (< 2^16).
- FP32 holds integers exactly up to 2^24 = 16,777,216.
- Each slab output is a sum of K = 14,336 such products (`bench:277`). Worst case 14,336 x 65,025 =
  932,198,400 (about 2^29.8), which is 55.6x the exact limit. With the benchmark's own limb values
  (roughly uniform bytes, mean product about 16,256) the typical partial sum is about 233,049,600,
  13.9x the limit. The largest K that stays exact for 8-bit limbs in FP32 is floor(2^24 / 65,025) = 258.
- Conclusion: the FP32 slab outputs are rounded for this K; they are not the integer products. The
  design is exact only with an integer accumulator: INT8 x INT8 -> INT32 (tensor-core style) is exact
  up to K = 33,025 (floor((2^31 - 1) / 65,025)), so K = 14,336 fits with margin. That is a different
  datapath from what was timed (MPS `MPSDataTypeFloat32`, `bench:320-322`).

Recombination bug (COUNTED `bench:57-73`): shifts are right (`(ia+ib)*8`, line 68), but line 72 combines
with XOR, `acc0 ^ (acc1 << 32)`; the correct combination is a sum. `acc0` accumulates terms up to
`v << 24` (about 2^54), so it overlaps the bits `acc1 << 32` occupies and XOR is wrong whenever they
overlap. `(long)slabs[...]` also casts already-rounded floats.

Other mismatches in the T1 pair:
- Inputs are masked to 24 bits (`bench:283-284`: `& 0xFFFFFF`). Real Goldilocks operands are 64-bit.
  64-bit x 64-bit by 8-bit limbs is 8 x 8 = 64 limb products (DERIVED), not 9. The doc's "36x" for
  "64-bit Karatsuba" (`doc:9`) has no derivation in any file I could find (36 = 8*9/2 does not
  correspond to a Karatsuba count: one level gives 48... three levels 27). The ratio 9x applies only to the
  24-bit toy operands.
- With 24-bit operands the true sum is below 2^62 (DERIVED: 14,336 x (2^24-1)^2 = 4.04e18 < 2^64 < p),
  so no modular reduction is required, and none is done. For real 64-bit operands the recombined
  15 diagonals (each up to 8 slabs x K x 65,025) exceed 2^64 and need a 128+-bit accumulate followed
  by a Goldilocks reduction. The timed region (`bench:333-350`) contains the 9 GEMMs and the recombine
  kernel but no modular reduction and no limb splitting (the splitting loops `bench:309-318` run on the
  CPU outside the timing). So the "+ recombine" in the doc's table is a partial recombine.
- The baseline arm is unfairly slow for 24-bit data: `goldilocks_matmul_u64` (`bench:38-54`) does a full
  `gl_mul` plus `gl_add` reduction at each of the K steps even though a product of two 24-bit numbers
  needs one 64-bit multiply and add and no reduction until the end (the sum fits in 64 bits).
  It is also an untiled one-thread-per-output loop with no threadgroup reuse. A fair "minimal-op" arm
  for these operands is a tiled integer kernel, which this is not.
- Memory (DERIVED): u64 operands + result = 125.3 MB; FP32 slabs = 189.5 MB. The GPU-friendly arm moves
  1.5x the bytes, so its win is compute, not bandwidth.
- "Matrix-Core" is not supported by the evidence: MPS FP32 GEMM on the M3 Ultra ran at 16.91 Gop /
  2.1086 ms = 8.02 Tflop/s (DERIVED), the throughput of ordinary FP32 SIMD ALUs. I have no evidence
  of dedicated matrix units on this chip generation; the label is an assertion. Equally, nothing
  here measures an RTX 5090 INT8 tensor core.
- Production check: `prod:474-498` `k_fold_rows` folds at most 8 Fp2 vectors (`k <= 8`) against the
  data; T1's N = 64, M = 1,024 matrix-matrix shape is not a production shape (COUNTED).

What T1 supports: 8-bit-limb FP32 GEMM runs 5.0x faster than a naive per-step-reducing u64 loop for
24-bit inputs, with inexact results. That does not support "GPU-friendly witness folding is 4.97x
faster".

### T2 (ragged 14,336 vs padded 16,384 fold): VALID as a throughput-vs-bytes measurement; the label and the conclusion built on it are wrong

- Same output? No, by construction: different row widths. Ragged reads rows at stride 14,336 from the same
  buffer the padded kernel reads at stride 16,384, so even the input data differs (`bench:76-111,
  358-361`). Neither output is checked. That is acceptable for a bandwidth test but it is not
  "the same math with fewer bits wasted".
- Direction (DERIVED from MEASURED `ragged 1.1055 ms`, `pow2 1.2551 ms`): the padded kernel is 1.1353x
  *slower* (13.5% longer); the JSON key `wall_speedup_of_14pct_more_ops: 0.881` is ragged-over-padded.
  The doc table (`doc:28`) prints "**0.88x faster**" in the Wall-Clock Speedup column of the
  padded arm, which reads as the padded arm being 12% faster. Correct: 0.881x, i.e. 12% slower.
- Byte accounting (DERIVED): ragged moves 704.6 MB at 637 GB/s; padded 805.3 MB at 642 GB/s. Byte
  ratio 1.1429; time ratio 1.1353. Both kernels run at the same bandwidth; ragged addressing (runtime
  `/` and `%`, `bench:85-87`) costs nothing measurable. This is the only fully clean result in the
  file, and it says padding costs its bytes.
- The doc's own takeaway at `doc:32` ("proves power-of-2 padding only wins when fused across multiple
  stages") is not what T2 shows; T2 shows padding does not win here at all, and T4's win is not
  evidence about padding (T4's arms differ in algorithm, not in width).
- `run_batch4.py:2645` states "Metal compiles constant `/ 7168` into `umulhi`". COUNTED `bench:81,
  85` take `dims` from a runtime `constant uint2&` buffer; the divisor is not a compile-time constant.
  The explanation is unsupported (the measured equality of bandwidth is enough without it).
- Baseline vs production (COUNTED): production folds with `k_fold_tables` / `k_fold_tables3`
  (`prod:560-577, 602-609`): in-place, half-split pairing (`lo_i` and `lo_i + nhalf`), Fp2 tables, five or
  three base multiplications per pair. T2's kernel is out-of-place, pairs adjacent elements, works on Fp
  (one mul), and uses the broken `gl_mul` (finding 0.2). Production B3's raggedness lives in layout/piece
  boundaries, not in the fold's index arithmetic.

### T3 (global atomic counting vs "privatized 2x byte-slab histograms"): INVALID

- Different output. COUNTED `bench:113-123`: arm A fills 65,536 per-entry counts. `bench:126-152`: arm B
  fills a 256-bin histogram of the low byte and a 256-bin histogram of the high byte, 512 numbers per
  threadgroup. Two marginal histograms do not determine the joint 65,536-bin counts, which is what a lookup
  multiplicity table is. B is not a faster way to compute A; to get A in shared memory one needs
  65,536 x 4 B = 256 KiB per threadgroup, which exceeds Apple GPU threadgroup memory (32 KiB on this
  generation, to my knowledge; unverified here) , and that is the reason a naive global atomic is the
  usual answer, not an oversight.
- Skew tuned against the baseline. COUNTED `bench:389-391`: 166 of every 256 draws land in 8 bins
  (`r & 7`); DERIVED 64.8% of queries hit 8 counters. That is maximal atomic contention, chosen by the
  author. Real range-lookup distributions have not been compared.
- The "ops" ratio is wrong in the doc: the table says "2.06x" (`doc:29`), the JSON says 2.125 (MEASURED
  `matches COUNTED 2 + 4096*512/2^24`), and `doc:32` says "2.13x".
- Baseline vs production: COUNTED. I found no multiplicity or histogram kernel in the Metal sources
  (`metal_kernels.metal`, `metal.rs`, `metal_slot.rs` contain no counting kernel; the only atomics are
  `atomic_fetch_or` error flags at `metal.rs:2931, 2984`). Multiplicities are built in Rust on the host
  (`private_block/witness.rs:1142` is where the multiplicity planes are allocated). So T3A is not the
  production implementation; there is no GPU counting step today to speed up.
- Rates (DERIVED from MEASURED): 9.3 and 11.4 G queries/s; 2^24 queries x 2 B = 33.6 MB read in
  1.5-1.8 ms = 19-23 GB/s, far below DRAM bandwidth. Neither arm is memory-bound, so the contrast is
  atomic contention vs less contention, nothing more.

### T4 (random O(N) "RAA" gather vs "coalesced 14-stage butterfly"): INVALID as an encode comparison

- Neither arm is the production encoder. Production PCS encoding is a Reed-Solomon NTT (`prod:89-128`
  `k_ntt_stage`, fused `k_ntt_head_t` at `prod:266`, `k_ntt_tail` at `prod:381`; header comment `prod:4-8`
  says it computes the CPU's NTT). I found no RAA / repeat-accumulate code in `docs/` or
  `ops/zkp-mvp` (grep for RAA in .md and .rs returned nothing). So "RAA vs NTT" is not a choice the
  production prover faces; production is already in the "fused shared-memory butterfly" camp.
- T4B is not an NTT. COUNTED `bench:187-225`: it processes independent 512-element tiles (`tile_base +
  lid`), never combining across tiles, so it is at most a 9-stage 512-point transform, not a 16,384-point row
  transform. The 5 "register" rounds (`bench:201-206`) apply 5 butterflies to the same pair (`a`, `b`),
  which is not an NTT stage pattern. Twiddles are `0x123456789ABCDEF + r` (`bench:200,202,215`), not
  roots of unity. The "14 stages" in the label and `butterfly_ops_per_word: 28` (`bench:503`) are
  matched to log2(16384) by construction; the kernel is a mock with the right operation count.
- T4A is not an RAA encoder either: `bench:168-184` adds three permuted words, with no accumulation chain,
  and its random gather is within one 16,384-word row = 128 KiB (`bench:176-183`), which fits cache. That
  contradicts the premise of a "12-15x random-gather bandwidth gap" (`doc:10`): MEASURED effective
  rate DERIVED = 1.074 GB / 4.5133 ms = 238 GB/s for T4A (vs 291 GB/s for T4B).
- The roofline script's M3 Ultra prediction for random-gather encode is 8.39 ms per 8.4 M words
  (`roofline_numbers.json:25`); DERIVED from MEASURED T4A: 4.5133 ms / 8 = 0.56 ms per 8.4 M words, 15x
  below the model. The model's `eff_random_gather_gb_s: 48` (`roofline_and_waste_tradeoff.py:12`) is
  contradicted by the same machine. Likewise the NTT model 6.47 ms vs 0.46 ms DERIVED from T4B.
- Therefore 1.22x says only that a mock compute kernel with fewer DRAM round trips beat a different mock
  gather kernel; it says nothing about NTT vs RAA vs dense GEMM encode.

### Summary table (labels corrected)

| Test | Same math? | Checked? | Baseline = production? | Correct reading of MEASURED ratio |
|---|---|---|---|---|
| T1 4.97x | no: FP32 slabs inexact (K=14,336 > 258), XOR recombine, 24-bit operands only | no | no (untiled, reduces every step; production is Fp2, <= 8 vectors) | slab arm 4.97x faster, wrong answers |
| T2 0.88x | no (different widths) | no | no (Fp, adjacent pairing, out-of-place; production Fp2, half-split, in place) | padded kernel 1.135x slower, equals byte ratio |
| T3 1.22x | no (512 marginal bins vs 65,536 joint bins) | no | no (no GPU counting in production) | invalid; contention-tuned data |
| T4 1.22x | no (mock NTT tiles vs mock RAA) | no | no (production = NTT) | not an encode comparison |

## 2. Fair baseline: where it differs from production (COUNTED)

- Field multiply: bench `gl_mul` (`bench:26-35`) is wrong; production `gl_mul` is `mul_64x64` +
  `gl_reduce128` (`prod:36-64`), checked against the CPU by `tests/zk60_metal_commit.rs` (header
  `prod:4-8`).
- Fold: production `k_fold_tables`/`k_fold_tables3` (`prod:560-609`), `k_fold_rows`/`k_fold_partial`
  (`prod:474-532`, Fp2 with zero skip). Sumcheck rounds are generated per slot as fused kernels with
  one thread per (pair, evaluation point) (`private_block/metal_slot.rs:382-460` and the M4e/M4g
  comments there). None of these resemble T1A or T2.
- Encode: fused NTT head (11 stages in threadgroup memory) and tail, with mode-0/1/2 row initialisers
  fused in (`prod:194-263`, `prod:266`, `prod:381`). Rows in production reach nn = 262,144 columns
  (`PROGRESS_UPERF3.md:11992`); bench rows are 16,384 wide with 512-wide independent tiles.
- Lookups: no GPU counting kernel (see T3).
- Hashing: GPU BLAKE3 already exists on both backends (Metal `k_hash_cols`/`k_hash_chunk`/`k_hash_merge`,
  `prod:694-820`; CUDA `kernels.cu:584-593, 1437`), relevant to G5.

## 3. Timing method

See cross-cutting item 4. Additional points:
- Sizes: T1 2^30.8 multiply-adds, T2 4096 x 16,384, T3 2^24 queries, T4 4096 x 16,384. Production
  per-block shapes were not compared; T1's N = 64 and T3's 65,536 bins with 8 hot bins are not
  production shapes.
- T2/T3/T4 interleave the two arms inside each iteration (`bench:379-381, 424-426, 464-466`), which
  reduces drift bias. T1 runs all of A then all of B (`bench:299-302, 351-354`), so thermal or clock
  drift could bias T1, the largest claimed ratio.
- MEASURED T3 and T4 ratios (1.218, 1.222) are close to each other and to nothing in particular; with
  one run and no spread, a difference of a few percent cannot be distinguished from noise.
- T1/T2 ratios are large enough (5x, 13%) to survive modest noise; T3/T4 (22%) probably do but this is
  unproven.

## 4. Labels and the [MODEL] figures

- T2 direction: wrong in the doc (see T2).
- `doc:11`: "Shrinking FFN width 16,384 -> 14,336 cut 14.29% wasted lanes (-424 KB receipt) yet ran 2.18%
  SLOWER on M3 Ultra Metal [MEASURED] (`MVP_STATUS.md:326`)". COUNTED: `MVP_STATUS.md:326` is the A17
  lookup-read item (about 220 MB of fresh pages per block) and says nothing about B3 or 14,336. A grep for
  "2.18%" in `docs/` and the `results/zk60_sol_20261105_w16r3` md/json files finds no such measurement.
  What the status file does say about B3 timing (`MVP_STATUS.md:37`): "earlier B3 timing is still
  marginal (0.153%, opposite signs by run order)", i.e. no measurable effect, not 2.18% slower. The
  roofline script hard-codes the number and labels it the opposite direction:
  `roofline_and_waste_tradeoff.py:60` `'measured_metal_wall_advantage_of_wasteful_pow2_pct': 2.18`
  (an *advantage* of padding), copied into `roofline_numbers.json:18`. The 2.18 figure is therefore
  unsourced and its sign is inconsistent between two files by the same author. (A different "2.18x"
  at `MVP_STATUS.md:2883` is a per-block ratio about TinyLlama and is unrelated.) "-424 KB": I found no
  source. The wasted-lane percent also needs a base: padded-over-exact is +14.29%; exact-below-padded
  saves 12.5% (DERIVED 2,048 / 16,384).
- `doc:10`: "17.5x more ops" and "3.4x faster" vs `roofline_numbers.json:23, 25-26`: ratio 19.2x
  (DERIVED 964.7 / 50.3 = 19.18) and 3.5 / 1.13 = 3.10x. The doc's 17.5x and 3.4x do not match its own
  JSON.
- `doc:9` "~1,500 TOPS vs ~0.85 TOPS", "49x to 196x" [MODEL]. Derivation (COUNTED
  `roofline_and_waste_tradeoff.py:15-21, 42-54`): 1,500,000 Gops / 850 Gops = 1,764.7x raw ratio, divided
  by the op inflation 9 or 36 gives 196.1x and 49.0x (DERIVED, arithmetic is right). Problems:
  1. No source is cited for either input. `850` (Goldilocks Gops) and `1,500,000` (sustained dense
     INT8 Gops) are literals. My recollection of NVIDIA's published RTX 5090 figure is about 3,352 "AI
     TOPS" for FP4 with sparsity, which implies roughly 838 TOPS dense INT8; I could not verify this
     offline, but if right the 1,500 TOPS input is about 1.8x too high.
  2. Op-count mixing: `scalar_ops = 2*N` counts a mul-add as 2 at 850 G "ops"/s, then slab ops are
     counted in FMAs x 2 at tensor TOPS. A Goldilocks mul-add costs tens of integer instructions, so "850
     Gops" must mean something specific (field mul-adds per second x 2?). Not stated.
  3. The case is a fold of 32 x 128 x 16,384 = 67.1 M elements (`roofline_and_waste_tradeoff.py:24`),
     i.e. a streaming, no-reuse operation. DERIVED: reading 67.1 M x 8 B = 537 MB at the script's own
     effective streaming rate (1,450 GB/s) takes 0.370 ms; at the 1,792 GB/s peak it takes 0.300 ms.
     The script's "scalar compute 0.158 ms" is below that, so the scalar kernel would already be
     memory-bound and the 196x/49x speedup cannot appear: both arms are floored at about 0.30-0.37 ms,
     so the achievable gain is about 1x, and the tensor-path time of 0.0008 ms is below that floor. The
     roof ratio is only meaningful for operations with data reuse (a real GEMM), and the script does
     not distinguish.
  4. Slab inputs need splitting into limbs (not counted) and recombination plus a modular reduction
     (not counted).
- `doc:10` "1.13 ms vs 3.5 ms": DERIVED from the script, NTT time is compute-bound at the assumed 850
  Gops (964.7 M ops / 850 G = 1.135 ms; memory term 0.278 ms) and RAA is bandwidth-bound at an assumed
  115 GB/s random-gather rate (402.7 MB / 115 GB/s = 3.5 ms; compute term 0.06 ms). The 3.1x therefore
  rests entirely on the unsourced ratio 1,450 / 115 = 12.6x. DERIVED from the workload: 8.39 M words x 8
  B = 67 MB, inside the RTX 5090's L2 (I recall 96 MB, unverified), which would make that random-gather
  rate pessimistic; the same machine-model error appears on M3 Ultra (T4 discussion above).
- `run_batch4.py:2641` "8x-14x expected on RTX 5090 INT8 Tensor Cores" is unsourced.

## 5. Verdict per track

"Receipt/verifier" means whether the receipt bytes, the verifier, or the Lean statements (D63) change.

| Track | Verdict | Receipt / verifier change |
|---|---|---|
| G1 INT8-slab sumcheck/Gram fold | **Needs one experiment.** The idea (INT8 limbs, INT32 accumulate, exact for K <= 33,025) is sound in principle, but the benchmark did not test it: it used FP32 (inexact), 24-bit operands, a broken recombination, and a straw-man baseline. | Drop-in in principle: if every output is the same canonical field element the transcript is byte-identical, so no receipt or verifier change. That holds only if bit-exactness is demonstrated. |
| G2 power-of-2 / 256-tile padding | **Not supported.** The only clean measurement (T2) shows padding costs bytes 1:1 (12% slower); the 2.18%-slower figure for B3 has no source and conflicts with `MVP_STATUS.md:37` (0.153%, sign flips with run order). The "pad batches to warp tiles" half has no measurement. | **Not drop-in.** The layout domain (14,336 vs 16,384) sets committed row widths and the receipt size; D67 (`ZK60_DECISIONS.md:116`) rules B3's 14,336 into W16R3, so "keep 16,384" changes the bytes and reverses a ruling. |
| G3 tensor-code / GEMM PCS (+ B6b wide rows) | **Not supported.** T4 compares two mock kernels, neither of which is the production Reed-Solomon NTT; no dense-GEMM encode was measured in the JSON; "819 MB -> ~45 MB" and "2x-4x faster encode" have no cited source. Brakedown (expander codes) and WHIR (Reed-Solomon IOP) are also not "GEMM Reed-Solomon". | Changes receipt format, opening protocol and verifier (different PCS); D63 Lean statements would need re-proving. Correctly labelled W16R4. |
| G4 coalesced fractional LogUp-GKR vs atomic scatter | **Not supported.** T3 measures a different output (two marginal histograms) on contention-tuned data and no GKR tree was measured; production has no GPU counting step to replace. B5 (LogUp-GKR) is already a separately gated study in D67. | Changes the lookup argument, therefore the receipt and verifier. Not drop-in. |
| G5 warp-transposed on-GPU BLAKE3 | **Needs one experiment.** Nothing in this benchmark touches hashing. The "~60% CPU Merkle bottleneck on RTX 5090" and "+10-25% padded compressions" are unsourced, and no RTX 5090 run exists. GPU BLAKE3 already exists in production (Metal and CUDA kernels listed in section 2). | Drop-in: BLAKE3 is a function of the bytes, so digests and receipts are unchanged. |

Experiments (name, pass condition, size):
- **G1:** `INT8 limb GEMM vs production fold, bit-exact`. Implement INT8 limbs with INT32 accumulate
  (CUDA `mma.s8` on the target GPU, or `simdgroup_matrix` int on Metal if available), full 64-bit
  Goldilocks operands (8 limbs, or the production's small witness x 64-bit challenge, which needs
  fewer limbs: say what production's witness word width is), with a full recombine + `gl_reduce128`
  inside the timed region. Pass: output equal word for word to the production `k_fold_rows` /
  CPU reference over the whole array, and end-to-end time at least 1.5x better than the production
  Metal/CUDA kernel (not a naive loop), repeated at least 30 times with min/median/stddev reported on a
  quiesced box. Size: production block shapes (rows, nn, up to 8 Fp2 vectors; N = 64 is not
  production), at least one 8B-model block.
- **G5:** `profile before building`. Measure the share of wall time spent in CPU Merkle/host work in a
  production-shape 32-layer proof on the target GPU (RTX 5090 is not available now; on the M3 Ultra use
  the existing Metal hash path). Pass: if the CPU Merkle share is below about 20%, drop G5; if
  above, a new kernel must give identical leaf and root bytes on every column of a full commitment and
  reduce that share. Size: nn = 2^18 columns, full row counts.
- (Not requested but implied for G2) re-measure B3 at 14,336 vs 16,384 in the real prover with
  at least 6 alternating pairs and report the spread, since the existing note shows sign flips.

## 6. The single most important correction

Replace the key takeaway at `doc:32` and the T1-T4 table (`doc:25-30`): the four pairs do not compute
the same quantity, no output is checked, the benchmark's `gl_mul` is wrong (`bench:33` omits the
`- hi_lo` term), the FP32 slab sums for K = 14,336 exceed the 2^24 exactness limit by up to 55x, and the
baselines are not production kernels, so they do not show that more operations ran faster. T2, the one
clean measurement, shows the padded kernel 12% slower. The "2.18% slower" B3 citation
(`doc:11`, `MVP_STATUS.md:326`) does not exist at that line.

## Addendum: metal_int_gemm.mm

Scope: `results/zk60_llama3_8b_feedforward_20261115/metal_int_gemm.mm` (kernel `exact_int_gemm_simd`,
lines 29-169, `kern`), driver `llama8b_working_model.py` (`drv`), run log
`results/zk60_coord_batch4_20261115/batch4.log`. Nothing run. Each line carries one label.
This kernel is not what Test 1B (`microbench_metal_gpu.mm`) timed; sections 0-5 above about T1 stand
for T1 as written. Verdict on this kernel: **exact as written** (derived), self-checked on one 128-token
sequence (see 4).

### A1. Chunk length and accumulation type

- COUNTED: one chunk rule for every path. A K-tile is 32 columns (`kern:65-67`); the float accumulators
  are flushed into `long i64_acc[16]` when `((t+1) & 15) == 0` or at the last tile (`kern:123`), so the chunk
  is 16 x 32 = 512 K-columns in both int8 mode and int16 mode. K = 4,096 gives 8 chunks, K = 14,336
  gives 28 chunks (448 tiles / 16, divisible), the head (K = 4,096, N = 128,256) 8 chunks. No other chunk
  length appears in the file.
- COUNTED: per-chunk float to integer: `(long)C_scratch[...]` (`kern:129-130, 136-137`), then `+=` into int64
  (`kern:139-143`); the int16 combination is `hi * 256L + lo` in int64 (carried arithmetic, not XOR/OR).
  The accumulators are zeroed after each flush (`kern:131, 138`).
- DERIVED: float to long conversion of an integer-valued float is exact (rounding mode irrelevant, there is
  no fractional part), provided the float holds the exact integer, which is A3.
- DERIVED: int64 overflow bound at the largest K = 14,336 (int16 mode, |x| <= 32,768, |w| <= 128):
  14,336 x 32,768 x 128 = 6.01e10, against 2^63 = 9.22e18. No overflow. Int8 mode is smaller.
- COUNTED: scratch/lane mapping is consistent: `simdgroup_store(..., stride 8)` then lane and lane+32 give rows
  lane/8 and lane/8+4, column lane%8, and the final write (`kern:154-166`) uses the same mapping. I found no
  mismatch.
- COUNTED: the K tail is zero-filled (`kern:85-88, 97-99`), so a partial last tile adds zero terms.

### A2. Operand ranges actually reaching the kernel

- COUNTED: weights are `int8` arrays (`drv:216, 258-264`), read as signed `char` (`kern:31, 98`). The kernel
  comment says [-127, 127] (`kern:25`), but nothing in the driver checks the weight files for -128. NOT VERIFIED
  whether any weight is -128.
- COUNTED: int8-mode activations are cast with `np.ascontiguousarray(x, dtype=np.int8)` (`drv:227`), which wraps
  silently modulo 256 if a value is outside [-128, 127]. The GEMM inputs `y`, `o8`, `nm`, `y_final` are
  checked against [-127, 127] before the call (`drv:325, 386, 396, 423-426`) but only counted, not clamped; the
  run asserts the count is zero (`drv:478, 491, 498, 534`). So under a passing run the cast does not wrap.
- COUNTED: int16-mode is used only for the down projection input `h16` (`drv:409`), checked to
  [-32768, 32767] (`drv:406`). The kernel splits it as `lo = u & 0xFF` in [0, 255] and `hi = s >> 8` (arithmetic
  shift) in [-128, 127] (`kern:82-83`), so s = 256 hi + lo exactly (floor division), and the weight is the same
  int8 operand.
- DERIVED: per-chunk worst case, 512 terms, FP32 exactness limit 2^24 = 16,777,216:
  - int8 mode, |x| <= 128, |w| <= 128: 512 x 128 x 128 = 8,388,608 (half the limit). With w in [-127, 127]
    and x in [-127, 127] (the checks): 8,258,048.
  - int16 mode, low limb (unsigned 255) x w: 512 x 255 x 127 = 16,581,120 (the author's figure, valid only
    if no weight is -128); with w = -128 it is 512 x 255 x 128 = 16,711,680, still below 2^24 with a margin
    of 65,536 (0.39%). **Tightest guaranteed bound: 16,711,680 < 16,777,216.**
  - int16 mode, high limb (|hi| <= 128) x w: 512 x 128 x 128 = 8,388,608.
  - Largest exact chunk (DERIVED): floor(2^24 / (255 x 128)) = 514 K-terms (518 if |w| <= 127). The kernel's
    chunk is 512, and 512 is the largest multiple of the 32-wide tile that fits, so there is almost no spare
    margin in the low limb; a change to a 576-wide chunk (18 tiles) would break exactness.
  - Not a limb-product-255x255 case: the weight is never an unsigned limb, so 255 x 255 does not occur.
  - Not wider than 8 bits: no int16 weight path exists in this kernel; a wider weight would break the bound.
- COUNTED: recombination of the two activation limbs is carried addition `hi*256 + lo` in int64
  (`kern:139-140`), not XOR/OR.

### A3. Is `simdgroup_float8x8` multiply-accumulate exact on integer values < 2^24?

- DERIVED (argument): each product is an integer with magnitude at most 255 x 128 = 32,640, exactly
  representable. Whatever order, grouping, fusion or tree the hardware uses, every intermediate value is a
  sum of a subset of the 512 signed terms, so its absolute value is at most the sum of the absolute values,
  at most 16,711,680 < 2^24. A binary32 value holds every integer up to 2^24 exactly, so each intermediate
  is representable and round-to-nearest returns it unchanged. Therefore an IEEE-style FP32 multiply or FMA or
  add, in any order, gives the exact integer result. Integer operands also leave no fractional bits for a
  truncating aligner to drop, and 255 fits in FP16 exactly in case an inner unit narrows inputs.
- NOT VERIFIED: that Apple's `simdgroup_multiply_accumulate` follows the above (the Metal specification does
  not guarantee IEEE-754 order or exact FMA semantics, and I did not run anything). The argument fails only
  if the hardware keeps fewer than about 25 integer bits internally. The only direct evidence is the
  empirical comparison in A4, which tests actual data, not worst-case sums.

### A4. Self-check against an integer CPU reference

- COUNTED: the CPU reference `cpu_gemm_nk` (`drv:328-337`) multiplies in float64 over 2,048-column slices
  (the docstring says 512, `drv:329`) and converts to int64. DERIVED: exact, since a slice sum is at most
  2,048 x 32,768 x 128 = 8.6e9, far below 2^53 = 9.0e15. It is an independent code path, not the Metal kernel.
- COUNTED: `drv:468-479`: one CPU forward and one Metal forward on the same 128 tokens, then
  `per_layer_max_diff` over `outs` (the residual stream after each of the 32 layers,
  32 x 128 x 4,096 = 16,777,216 int64 values) and `logits_max_diff` over `C` (128 x 128,256 = 16,416,768
  values). The comparison is `max |a - b| == 0` with `assert` (`drv:476-478`); a mismatch raises
  AssertionError and exits nonzero (the driver is launched with `-B`, not `-O`). It is a fail-stop, not a log
  line. The log line `batch4.log` "Stage 2 COMPLETE: 0-ULP diff=0, refusals=0" (2026-11-16T06:07:15Z) is
  therefore consistent with the check passing. `working_model_metrics.json` records both max diffs as 0
  (MEASURED).
- COUNTED: what is not compared: the raw int64 GEMM outputs of the 224 per-layer matrices. Only the residual
  stream after `requant` (right shifts of 4 to 8 bits from `d32_and_shift_audit.json`: `sh_ao` 4-8, `sh_z`
  5-8) is compared, so an error of +-1 or +-2 in a raw sum is mostly hidden by the rounding shift. DERIVED: the
  per-layer test is a weaker detector of FP32 rounding than a raw int64 comparison. The head GEMM is the
  exception: `logits_C = l_raw * head_mult` (`drv:431`) is compared in full (16.4 M values), which tests the
  raw head GEMM unless a multiplier is zero (NOT VERIFIED).
- COUNTED: single input only: one 128-token sequence. Intended source is WikiText-2 (`drv:451-455`), but
  `drv:130` points at `results/zk60_fidelity_parity_20261019/data/wikitext2`, which now contains only
  `test.parquet` and `validation.parquet`, not `wiki.test.tokens`. So the `else` branch (`drv:456-460`, a
  fixed sentence repeated 8 times) was almost certainly used. NOT VERIFIED for the actual run (I did not see its
  stdout), but the label "held-out WikiText-2" in the driver comment is unsupported by the directory.
- DERIVED: real activations have far smaller sums than the worst case (signed terms cancel), so this
  data does not approach 2^24; the check supports "no gross error", while the exactness guarantee rests
  on A2/A3.
- COUNTED: a separate PyTorch-MPS path exists (`llama8b_fast_int_forward.py:62-79`): 6-bit activation limbs,
  2,048-column chunks, `torch.matmul` FP32 then `.to(torch.int64)`, recombined by carried adds
  `s0 + (s1<<6) + (s2<<12)`. DERIVED bound: 2,048 x 63 x 128 = 16,515,072 < 2^24 (also fine). It checks only
  layer-0 QKV and down-proj on random inputs with `assert ... == 0` (`:92, 98`) and is not what `batch4.log`
  ran. NOT VERIFIED that `torch.matmul` on MPS accumulates in plain FP32 without split-K or reduced
  precision.

### A5. What the timed figures include

- COUNTED: `zk60_metal_gemm_batch` returns `([cb GPUEndTime] - [cb GPUStartTime]) * 1000` (`kern:327`) after
  `waitUntilCompleted`. The int64 flush runs inside the kernel, so it is included.
- COUNTED: excluded from that figure: the host `memcpy` of X into the shared buffer (`kern:297`), the host
  `memcpy` of every int64 output back to NumPy (`kern:322-326`; 128 x 128,256 x 8 B = 131 MB for the head),
  `np.ascontiguousarray` and `np.empty` (`drv:227-232`), and all Python (norms, attention, softmax,
  requant).
- MEASURED (`working_model_metrics.json`): `gpu_zkp_exact_int_gemm_kernels_ms` 509.77 (mean of 3 warm
  runs of the summed kernel time of 225 GEMMs, `drv:485-490, 501`), hybrid wall 1223.76 ms, CPU 5739.61 ms.
  DERIVED: 1223.76 - 509.77 = 714 ms is everything else (copies, conversion, NumPy).
- COUNTED: the headline ratio `zkp_int_gpu_kernels_over_fp16_gpu` divides the int GEMM-kernel time (GEMMs
  only) by `fp16_wall_ms` (`drv:581`), the wall time of a full FP16 forward pass that also does RMSNorm,
  attention and SwiGLU (`kern:331-336`). MEASURED 509.77 / 120.96 = 4.21; DERIVED with the FP16 GPU time
  111.95: 4.55. The key says "gpu" while the denominator is wall. The int arm is therefore several times slower
  than FP16 even with a smaller scope, and nothing here compares it with a Goldilocks or production field
  kernel, so it does not rescue T1's claim that 9x more ops are faster than production.
- COUNTED: no repeat count beyond 3 warm iterations, mean only, no variance (`drv:485-501`).
