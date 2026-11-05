# Efficiency plan, Phase A: results (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`. Every item in Phase A is byte-preserving: the goldens,
the six pinned trained digests and the receipt sizes must stay unchanged.

## A2: the D55 preflight in parallel (H122), done

**Change** (`run_fork.rs`, `preflight`; `private_block.rs`, `check_accuracy_for_shape`):
- the per-block public checks run one block per rayon task, about 7 GB of weights at 8B;
- the int8 symmetry scan runs in parallel chunks;
- the refusal is the serial loop's: results are read back in block order and the first error is returned.

**Acceptance** (`results/zk60_h124_witness_20261104/check_a1a2.sh`, `a1a2.progress`):
- the full lib suite is 913 / 3 known / 94;
- the W16R2 rung golden is unchanged;
- the six post-F12 trained digests are present;
- every D55 receipt verified, and the receipt is 818,728,672 B, unchanged.

**Time, one W16R2 8B T128 request, 32 blocks, forks N = 6** [MEASURED, best of 2, `d55_ab_a2.log`]:

| | before (F12 merge run) | after A2 |
|---|---:|---:|
| preflight | 0.35–0.38 s | **0.081–0.084 s** |
| forks, witnesses prebuilt (proof only) | 5.749 s = 22.27 tok/s | **5.111 s = 25.04 tok/s** |
| one request from its input (sealed) | 11.664 s = 10.97 tok/s | **10.807 s = 11.84 tok/s** |
| a stream of 4 requests, steady | 15.94 tok/s | 15.95 tok/s (limited by the sealing pass, A4's target) |

## A1: where one 8B block's proving time goes

`HL_PB_TIMING=1`, one D12a serial block, uncontended, 4-block run, one fork worker [MEASURED, shared box, one run;
`results/zk60_h124_witness_20261104/a1_phases.log`]. Wall 0.591 s:

| Phase group | s | % |
|---|---:|---:|
| A: witness planes into rows, lookups, histograms, mask rows | 0.047 | 8.0 |
| **A commit** (encode + Merkle, one call) | **0.078** | **13.3** |
| H: LogUp helper inverses (six domains + exp/act) | 0.032 | 5.4 |
| **H commit** (encode + Merkle, one call) | **0.072** | **12.2** |
| M commit, table helpers, mask and zero-sum rows | 0.013 | 2.2 |
| **slot 18, F zero-check** (79.7 M elem-terms) | **0.106** | **17.9** |
| slot 14, D zero-check | 0.045 | 7.6 |
| slot 17, softmax zero-check | 0.028 | 4.8 |
| slot 15, Q zero-check | 0.023 | 3.9 |
| the other 19 slots | 0.086 | 14.6 |
| openings A, H, M | 0.044 | 7.4 |

**What it says for the plan:**
- **The two commitments (25%) and the F and D zero-checks (26%) are half the block.** They are the targets of B1, of
  A6 (kernels) and of A8 (Gram folding), and B4 and B5 would shrink both by committing fewer rows.
- **Concurrency matters:** in the fork run the same blocks take 0.42–1.25 s each, and 32 blocks finish in about 4.7 s
  on 6 workers. That is about 0.15 s of wall per block, so CPU and GPU phases overlap across forks. A7's per-fork
  queues and GPU timestamps will show which resource limits.

## A3: the witness cache sized to the machine, done

**Change** (`trained_block.rs`). Without `--witness-cache-gib`, `stack-prove` keeps the sealing pass's witnesses up to
an eighth of physical RAM, at least the old 4 GiB and at most 64 (`default_witness_cache_gib`). Test builds keep 4.
The old fixed 4 GiB kept only about 13 of an 8B run's 32 witnesses (about 0.3 GB each) and rebuilt the other 19
serially on the fork feeder during proving.

**Acceptance** (`check_a3.sh`, `a3.progress`):
- the A3 test reports 256 GiB of RAM and a 32 GiB default on this Mac;
- the trained-stack CLI tests show only the known `review_n_r6_b` failure;
- the full lib suite is 914 / 3 known / 95.

**The effect is not measured on the Mac**: no trained 8B export is here. It equals the harness's SEALED arm, with all
32 kept, against the rebuild path [INFERRED].

## Census of what a block commits (for B4 and B5)

`range16_tests::effplan_census_of_the_committed_rows_by_domain` (ignored); log `census.log`.

| W16R2 8B T128 | A (witness words, limbs, remainders, histograms) | H (LogUp helpers, Fp2 = 2 rows each) |
|---|---:|---:|
| data rows | 2,279 | 2,514 (1,257 helper planes' rows × 2) |
| F domain (feed-forward) | 9 planes, 1,152 rows | 5 helpers, 1,280 rows |
| D domain | 19 planes, 608 rows | 10 helpers, 640 rows |
| S / Q / Kv | 256 / 192 / 48 rows | 320 / 192 / 48 rows |
| lookups per position | — | D 19, F 7, S 7, Q 6, Kv 6, L 2 |

**What it says.** 52% of a block's committed data rows are LogUp helpers. The A1 table puts the H commit at 12% of
the block's time, the helper inverses at 5%, and the helper tables inside slots 14 and 18.
- **B5, LogUp-GKR,** replaces committed helpers with a GKR proof.
- **B4, probabilistic range checks,** lowers the lookups per position, mainly D's 19, and so thins both H and A's limb
  planes.

These are the two largest structural levers. Both need their design studies, decision 3 of the plan, before any
estimate.

## A4: the witness weight products on the Metal GPU, exactly, done

Full write-up: `a4/README.md`.

**Change** (`gpu/metal.rs` `[A4]`, `gpu/mod.rs`, the dispatch in `witness.rs`). FlashProve's byte-slab idea, on Apple
`simdgroup_matrix<float>`:
- each i16 activation is split into an unsigned low byte and a signed high byte;
- products with int8 weights are summed exactly in fp32 over 512-term slabs. Every partial sum is at most
  512·32,640 < 2^24, so every operation is exact; fast math is off.
- slab totals go to int32 (|Σ| < 2^31, K ≤ 65,536 checked first), and `256·hi + lo` is recombined in int64.

The safety nets:
- a start-up self-check at the slab bound turns the device path off on any mismatch;
- the CPU path stays the reference and the default without `HL_GPU=1`;
- activations outside i16 stay on the CPU.

The route was chosen on GPU time: `simd2x4` 9.9 ms per block, against 12.1 ms for `simd4x2` and 19.5 ms for int32
multiply-adds.

**Exactness tests** (`witness_speed_tests.rs`): the device equals the CPU on every input class, route, layout and
transfer mode, at the slab extremes, and on every witness plane for six profiles (the DD refusals identical).

**Time** [MEASURED, one run per arm, shared box; `a4/`]:

| | CPU products | device products |
|---|---:|---:|
| one W16R2 8B T128 witness (32 threads) | 0.162 s | **0.103 s** (the products 0.085 → 0.014 s) |
| the sealing pass, 32 blocks | 5.450 s | **3.615 s** |
| one request from its input (sealed) | 10.919 s = 11.72 tok/s | **9.237 s = 13.86 tok/s** |
| a stream of 4 requests, steady | 15.98 tok/s | **20.73 tok/s** (amortized 18.20) |
| per-request latency in the stream | about 14.5 s | about 11.6 s |
| proof only | 5.34 s | 5.17 s (noise) |

**For the privacy gate.** No new file or pin, but three pinned files changed digest and must be re-read at the full
digest before any GPU-made bundle counts: `gpu/metal.rs`, `gpu/mod.rs` and `private_block/witness.rs`. The details are
in `a4/README.md`, "What the privacy gate will need to read". The device handles private activations on the local GPU.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A5: the builder's remainder, first step (no measurable gain; stopped)

**The profile** (`check_a5_profile.sh`, `a5prof_sample.txt` not committed, 14.5 MB). With the A4 device products on,
the hottest CPU work in the builder was `requant`. It divides by `2^shift` with i128 `div_euclid`/`rem_euclid`, which
compiles to the generic 128-bit division.

**The change** (`accuracy.rs`): an arithmetic right shift and a mask, the same words for every sign. The test
`requant_shift_form_equals_euclid` covers every shift 1..=63 with negative, zero, positive and extreme numerators.

**Acceptance** (`check_a5.sh`, `a5.progress`): the full lib suite is 920 / 3 known / 96; the W16R2 rung golden is
unchanged; all six post-F12 digests are present.

**Time** [MEASURED, one run, shared box]: no measurable gain end to end. The witness per block is 0.114 s (A4's run:
0.103 s), the sealing pass 3.606 s (3.551), the stream 19.56 tok/s steady (20.36). These are within run-to-run
variation.
- **Why:** the division is parallel work over 32 threads. Its share of CPU samples was not a share of the critical
  path.
- **More witness speed now buys little for the stream.** The stream costs about 6.3 s per request against about
  5.2 s for the fork run alone, so it is close to GPU-bound. A5 is stopped here.
- The change stays: it is byte-identical and uses less CPU, which matters on a host-bound 5090.
- **The next gains are on the GPU side** (A7/A6, running) and in the protocol bundle (W16R3).
