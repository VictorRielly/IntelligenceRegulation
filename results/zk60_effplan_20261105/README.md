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
  5.2 s for the fork run alone, so the fork run sets the pace. A5 is stopped here.
- The change stays: it is byte-identical and uses less CPU, which matters on a host-bound 5090.
- **Correction (A7, below):** this section first called the stream "close to GPU-bound". A7's timestamps show that
  the fork run is bound by the fork threads' host work, not by the GPU.

## A7: GPU timestamps and command queues (H121), done; per-thread queues are opt-in only

Full write-up: `a7/README.md`. Merged into perf on top of A5.

**Acceptance on the merged tree** (`check_a7merge.sh`, `a7merge.progress`, one guarded job) [MEASURED]:
- build rc 0; no-feature `cargo check --tests` rc 0; the requant tests 6/6;
- the full lib suite: 920 passed, exactly the known three failed, 98 ignored;
- the A7 queue test: six concurrent rung proofs give `96e4f0b6` on both the shared and per-thread queues;
- the W16R2 rung golden holds, and all six post-F12 digests are present under `HL_GPU_REQUIRED=1`;
- D55, default path:
  - one request from its input, best 9.18 s = 13.95 tok/s;
  - the 4-request stream 19.25 tok/s steady (17.20 amortized);
  - proof only, best 5.04 s = 25.38 tok/s;
  - fork receipts 818,728,672 B, every receipt verified.

  These match the pre-A7 figures within run-to-run variation, as expected: the default path did not change.

**The fork run is not GPU-bound** [MEASURED, W16R2 8B T128, 32 blocks, N = 6]:
- In the forks phase, the GPU runs at least one command buffer only **53–59%** of the time (2.8 s of a 4.8–5.3 s
  phase).
- Almost all of the idle time is in gaps of 5 ms or more, when all six forks are on the host at once. Gaps under 1 ms
  total under 15 ms.
- Each fork thread spends about 60% of its time on the host between command buffers. That is 0.47–0.62 s per block,
  against 0.22 s for the same work with no other fork running. Only 18–21 of the 32 cores are busy.
- Uncontended (the serial arm), a block needs 0.099 s of GPU: sumcheck batches 68 ms, commitments 31 ms.

**The queues.** The single shared queue lets at most 3 command buffers run at once, and a finished one is noticed
1.7 ms late. Per-thread queues (`HL_METAL_QUEUES=thread`) allow 6 at once and cut the delay to 0.2 ms, but they do
not move the wall:
- the proof-only fork run is about +1.4% (no gain);
- the stream's steady state is about −2.7% (a small loss).

So the shared queue stays the default. The first A/B claimed a 5.6% gain; that was arm-order bias (the second arm
of a pass runs about 4.5% faster whichever it is). **Every in-process A/B must now run both orders.**

**Also added, all opt-in or test-only:** the GPU timeline (command-buffer timestamps, read after completion), a CPU
meter, an in-process policy A/B in the D55 harness, and spin-then-block waits (`HL_METAL_SPIN_US`). The default code
path is the pre-A7 one.

**A6 was not implemented,** because the kernels do not limit the wall. Its census found an exact cut for later: slot 18
(the F zero-check) declares degree 5, but its IR reaches only degree 4 at W16R2 8B, so the sixth round value follows
from the other five. That saves about 5 ms of GPU per block (under 1% of the wall today) and touches the pinned
`metal_kernels.metal` (`a7/README.md` §6).

**Unresolved, one order only:** spin against block against spin-200, the device row fold (looked 2.7% slower), and
N = 8 against N = 6. Nobody should act on these before a both-orders A/B.

**For the privacy gate.** `gpu/metal.rs` and `gpu/mod.rs` changed digest again (diagnostics and opt-ins only). They
must be re-read at their new digests with A4's files before any GPU-made bundle counts.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**What this means for the plan.** The next byte-preserving gains are in the forks' host path:
- **why** a fork's host work takes 2–3× longer when six run together, with cores to spare: memory bandwidth, a shared
  rayon pool, allocator or driver locks, or the spinning waits;
- the host items themselves: the A row build at the phase's start (the longest gap, 0.17–0.22 s), the store folds
  (A8, Gram folding), and the opening's host fold.

A host profile of the forks phase comes first.

## A11: the forks' host path, done: one rayon pool per fork worker

Full write-up: `a11/README.md`. Merged into perf; acceptance and an independent repeat of the A/B on the merged tree:
`check_a11merge.sh`, `a11merge.progress`, `a11merge_pairs.md`.

**What the profile found** [MEASURED, macOS `sample`, N = 1 against N = 6]:
- Six forks do the same CPU work as one; it just takes longer.
- The cause is the one global rayon pool the six forks shared. A pool worker waiting inside one fork's parallel step
  picks up queued work, often another fork's, and the first fork cannot go on until that work ends.
  - At N = 6, 69% of the pool's running samples were such nested jobs (41% at N = 1).
  - Each fork waited about 3.5× longer on its own parallel steps, while the pool was about half asleep.
  - About a quarter of all CPU was system time, mostly the pool's threads sleeping and waking.

**What changed** (both byte-preserving):
- **Each fork worker runs its proofs on its own rayon pool** of ⌈cores / workers⌉ threads (6 at N = 6). This is the
  default; `HL_D55_FORK_POOL=0` restores the global pool.
- `Fp::from_u128` uses the Goldilocks reduction that `mul` already uses, instead of a software 128-bit division. It is
  tested against `v % p` on 400,000 random words and the edge cases.
- A reuse pool for the big A/H matrices was measured, did not pay, and was dropped.

**Byte evidence:** the seeded W16R2 rung inside pools of 1, 2, 3 and 6 threads, CPU and Metal, always gives the golden
`96e4f0b6`.

**Acceptance on the merged tree** [MEASURED, one guarded job]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 922 passed, exactly the known three failed, 99 ignored; zkp-core field tests 6/6;
- the A11 pool tests (CPU and Metal), the A7 queue test, the W16R2 rung golden and all six post-F12 digests pass;
- D55 default:
  - proof only, best 4.334 s = **29.53 tok/s**;
  - one request from its input, best 8.848 s = **14.47 tok/s**;
  - the 4-request stream **23.96 tok/s steady** (20.18 amortized; per-request latency about 10.3 s);
  - every receipt verified; fork receipts 818,728,672 B, unchanged.

**The independent A/B** [MEASURED, `a11merge_pairs.md`]: per-fork pools against the global pool, 4 passes, arm order
alternating.

| metric | mean change over 4 pairs | means global / per-fork |
|---|---:|---:|
| proof-only wall | **−9.5%** | 4.94 / 4.47 s |
| one request from its input | **−7.1%** | 9.42 / 8.75 s |
| stream, steady | **+19.0%** | 19.6 / 23.3 tok/s |
| stream, amortized | **+13.4%** | 17.5 / 19.8 tok/s |

Every pair, in both orders, favours the per-fork pools. This agrees with the agent's own 6-pass A/B (−10.6%, −4.5%,
+16.9%, +11.8%).

**For the privacy gate:** the production digests that moved are `private_block/run_fork.rs` and zkp-core's
`field.rs`. `gpu/metal.rs`, `gpu/mod.rs`, `protocol.rs` and `metal_kernels.metal` are unchanged by A11.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**What is left on the host** (the A11 profile after the fix):
- the device slots' table builds, about 1.3 GB per block written from the CPU (**A12, running**);
- the openings' store folds, about a fifth of a fork's host samples (**A8, running**);
- the A/H zero-fills;
- the randomness fill.

The forks phase is about 4.0–4.3 s, against A7's GPU-busy bound of about 2.8 s.

(Correction, same day: `a11merge_pairs.md` first came out as an empty table because `check_a11merge.sh` passed
`--n 4`. That flag of `a11/pairs.py` is the fork count N, not the pass count. The table above was computed by hand
from the log. `pairs.py ... --n 6` now gives the same numbers, and the file and both check scripts are fixed.)

## A12: the device slots' tables built on the GPU, done

Full write-up: `a12/README.md`. Merged into perf; acceptance and an independent repeat of the A/B on the merged tree:
`check_a12merge.sh`, `a12merge.progress`, `a12merge_pairs.md`.

**What the map found** [MEASURED, W16R2 8B]:
- The device slots 14–19, 21 and 22 build 168 tables per block: 82.6 M extension words (1.32 GB), 95% of all table words.
  - 18 are eq tables, 34 are public tables and 116 are committed-plane gathers.
- On the host they cost about 19–20 ms per block per fork at N = 1, and about 46–47 ms at N = 6.

**What changed** (byte-preserving):
- **Two device kernels:**
  - an eq table is the product of its point's two half tables (the host's `eq_cube_split_into`);
  - a committed plane is gathered through the host's own inverse bit map (`argument::plane_plan`).
- **Public tables** are still written by the host, beside the device's.
- **Where the rows come from:** A's and H's rows are read from the commitments' own device copies, which `prove_core`
  registers for its slots (`MetalCommit::resident_rows`). Lookup is by exact address and length, on the registering
  thread only.
- **When it runs:** the build is encoded at the head of the slot's first round command buffer, so it costs no command
  buffer or queue wait of its own.
- **Why that form:** the first form ran in its own command buffer and mapped fresh views of the host rows. It lost about
  9% at N = 6, because of about 2.2 ms of residency per 330 MB view plus the queue wait behind the other forks.
- **Switches:** the default is the device build. `HL_METAL_DEVICE_TABLES=0` restores the host build, and `=sync`
  selects the own-command-buffer form. A large slice that is not resident is never mapped; that slot stays on the host
  build.

**Byte evidence:**
- **CPU test** (in the suite): the kernels' formula, evaluated on the host, equals both host builders on every word, at
  every slot of the W16R2 rung.
- **Metal census:** every word equals the host's.
  - W16R2 8B: 228 tables, 87.0 M words.
  - The rung: 238 tables.
  - This holds in both forms and with deferred builds.
- **Rung golden `96e4f0b6`:** holds with the tables on the host, on the device ahead of the first round, and on the
  device in their own command buffer. It holds alone and as three concurrent proofs.

**Acceptance on the merged tree** [MEASURED, one guarded job]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 923 passed, exactly the known three failed, 101 ignored; zkp-core field tests 6/6;
- the A12 census and rung-mode tests, the A11 pool tests (CPU and Metal), the A7 queue test, the W16R2 rung golden and
  all six post-F12 digests pass;
- D55 default:
  - proof only, best 4.256 s = **30.08 tok/s**;
  - one request from its input, best 8.356 s = **15.32 tok/s**;
  - the 4-request stream **23.60 tok/s steady** (20.34 amortized; per-request latency 8.9–10.4 s);
  - every receipt verified; fork receipts 818,728,672 B, unchanged.

**The independent A/B** [MEASURED, `a12merge_pairs.md`]: device tables against host tables, 4 passes, arm order
alternating.

| metric | order bias removed | means host / device |
|---|---:|---:|
| proof-only wall | **−6.5%** | 4.68 / 4.37 s |
| forks phase | **−7.8%** | 4.30 / 3.96 s |
| one request from its input | **−4.0%** | 9.01 / 8.65 s |
| stream, steady | **+5.0%** | 22.9 / 24.0 tok/s |
| stream, amortized | **+5.0%** | 19.5 / 20.5 tok/s |
| user CPU | **−16.5%** | 56.2 / 46.9 s |

Every pair, in both orders, favours the device build. This agrees with the agent's own 6-pass A/B: −6.9%, −3.5%, +6.4%
and +4.8%.

**For the privacy gate:** the production digests that moved are `gpu/metal.rs`, `private_block/argument.rs` and
`private_block/protocol.rs`, where one scoped statement in `prove_core` registers the resident rows. `metal_kernels.metal`,
`gpu/mod.rs` and `metal_slot.rs` are unchanged; the new kernels are a source string inside `metal.rs`.
`D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**Still on the host:**
- the private slots 00–13's tables and the public-table copies (about 10 ms per block per fork at N = 6);
- the openings' store folds (**A8, done below**);
- the A/H zero-fills;
- the randomness fill.

The forks phase is now about 3.9–4.0 s, against the GPU-busy bound of about 2.75 s.

## A8: the openings' store folds, done (no Gram folding to do; a faster fold)

Full write-up: `a8/README.md`. Merged into perf on top of A12; acceptance and an independent repeat of the A/B on the
merged tree: `check_a8merge.sh`, `a8merge.progress`, `a8merge_pairs.md`.

**What the agent found** [MEASURED]:
- **There was no Gram folding to do.** Each opening already reads its committed rows once, and the coefficient vectors
  are already combined per group. A's 37 vectors and H's 10 are different linear maps, and each goes in the receipt, so
  the arithmetic is fixed. Only the constant factor could improve.
- **The fold waited on memory, not arithmetic.** Each row's slice of a chunk starts 128 KB after the previous row's; one
  row of software prefetch was the largest single gain [the latency reading is INFERRED from the sweep].
- **A's rows are mostly small words:** 37 vectors, but only 2.26 rows' worth of nonzero coefficients, and 85% of its
  updates fall on 16-bit signed words. H has almost none.
- **The pads (q = 280 columns) were folded afterwards on one thread:** 2.4 ms for A, 3.3 ms for H.

**What changed** (byte-preserving; the default, `HL_METAL_A8_FOLD=m11` restores the old forms):
- **A new store fold** in `gpu/metal.rs`:
  - each row's nonzero coefficients are listed once and summed exactly in u128, then reduced once per output;
  - 256-column chunks, with the next row's slice prefetched;
  - 16-bit words are summed in NEON u64 lanes with an offset of 2^15, which is taken back out exactly;
  - the pads are folded in the same parallel pass.
- **The fold alone, in a 6-thread pool:** A 24.6 → 10.1 ms, H 31.5 → 19.3 ms.
- **A new defaulted method** `EncodedStore::fold_rows_with_pads` in zkp-core. The CPU, CUDA and `NoExternal` stores
  decline it and keep the old path.
- **Measured and dropped:**
  - an allocator-zeroed A/H made the fork run +5.6% slower;
  - skipping the prover's unused column-weight tables had no effect.

**My review of the arithmetic:** the arithmetic is exact.
- **u128 path:** every product is below 2^128, and overflows are counted and reduced through 2^128 mod p.
- **Small-word path:** each lane gains under 2^48 per row, and the path is used only below 2^16 rows, so no lane
  overflows. Then Σ r(x + 2^15) − 2^15 Σ r = Σ r·x over the same rows, with x ≡ the word mod p.
- **Prefetch:** every address is inside the source slice, as the segment assertion requires.

**Byte evidence:**
- 765 fold forms equal the per-term fold, word for word (a suite test).
- The rung golden `96e4f0b6` holds under the old, row-sparse and small-word forms, with every captured fold re-folded
  by 90 forms.
- The 8B block's core proof gives the same digest under every form.

**Acceptance on the merged tree** [MEASURED, one guarded job]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 924 passed, exactly the known three failed, 103 ignored; zkp-core lib 78 passed;
- the A8 rung test, the A12 census and rung-mode tests, the A11 pool tests, the A7 queue test, the W16R2 rung golden and
  all six post-F12 digests pass;
- D55 default:
  - proof only, best 3.932 s = **32.55 tok/s**;
  - one request from its input, best 8.255 s = **15.51 tok/s**;
  - the 4-request stream **24.17 tok/s steady** (20.93 amortized; per-request latency 8.6–10.0 s);
  - every receipt verified; fork receipts 818,728,672 B, unchanged.

**The independent A/B** [MEASURED, `a8merge_pairs.md`]: the A8 fold against the old forms, 4 passes, arm order
alternating.

| metric | order bias removed | means old / A8 |
|---|---:|---:|
| proof-only wall | **−2.9%** | 4.24 / 4.12 s |
| forks phase | **−3.1%** | 3.88 / 3.76 s |
| one request from its input | **−1.7%** | 8.45 / 8.31 s |
| stream, steady | **+2.2%** | 23.9 / 24.5 tok/s |
| user CPU | **−9.2%** | 47.1 / 42.7 s |

- **Smaller than the agent's figure.** The agent's own 6-pass A/B on the merged tree gave −5.1%, −3.2% and +2.6%.
- **Pairs:** on the proof-only and forks clocks, one test-first pair did not favour A8 (3 of 4 pairs favour it). Every
  other clock favours it in every pair.
- **Why it stays the default:** it is byte-preserving and every mean favours it.

**For the privacy gate:**
- **Digests that moved:** `gpu/metal.rs`, `gpu/mod.rs` and zkp-core's `pcs.rs` and `pcs/backend.rs`.
- **A timing dependence on the hidden data.** The small-word path tests whether a row chunk's words are all 16-bit
  signed integers, so the prover's running time depends slightly on the witness.
  - It is probably fixed by the layout: A's rows are mostly 16-bit activations, and H's helpers are full-width words.
    That has not been shown.
  - The two Lean production statements cover what the proof reveals, not timing.
  - The gate should decide whether this matters for a served prover. `HL_METAL_A8_FOLD=m11` removes it.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**Not done:**
- Gram folding of the zero-check rounds (device kernels);
- re-measuring the device fold (`HL_METAL_DEVICE_FOLD=1`);
- the transcript absorb of A's clear vectors (about 9.9 MB of BLAKE3 per block on one thread; `update_rayon` gives the
  same digest);
- the unexplained small rise in system CPU (flat on the merged tree);
- an in-process A/B at N = 1.

## A13: before-challenge work during the sealing pass, a negative result (not merged)

Full write-up: `a13/README.md`. Only its results are in perf. The code stays on its branch as a record (8158de49,
35573146), because it adds complexity to two privacy-gated files for no gain.

**The idea:** a fork's work before its first transcript use needs only its own block's witness. That work is A's rows,
the lookups and histograms, the mask rows, A's commitment and M's commitment. Do it during the sealing pass instead of
after it.
- **Byte-identical:** every parked fork equals the same fork proved whole, byte for byte, and the rung golden holds with
  the core split across threads.
- **Its share:** 63 ms per block alone (21.5%) and 140 ms per block at N = 6 [MEASURED].

**Why it does not pay** [MEASURED, 2 passes, both orders]:
- With all 32 parts made beside the sealing pass, the forks phase fell 9.4% but the sealing pass rose 9.2% (CPU
  contention; the GPU wait barely moved).
- **Net:** one request +1.1%, within the noise; the stream steady −7.3%.
- **Smaller windows and lower QoS did not rescue it:** one request −3.5% to +1.6%, the stream −3.5% to −12.1%.
- **The ceiling:** even a free before-part would take only about 0.3 s off one request [INFERRED].
- **Memory:** peak 72–80 GiB with 32 forks parked, against 35–64 GiB [MEASURED, Metal pool on].

**What it found on the way: the sealing pass wastes its cores.**
- It keeps about 10 of 32 cores busy, and 26 of its 42 CPU-seconds are system time.
- **A harness-only probe** ran its witness builds in a rayon pool of 8 or 16 threads instead of the 32-thread global
  pool. Every pair favours it, in both orders [MEASURED, 2 passes; the proof-only control moved +0.3% to +5.5%]:

| pool | sealing pass | one request from its input | stream, steady |
|---|---:|---:|---:|
| 16 threads | −17.8% (4.22 → 3.47 s) | −11.0% (16.8 tok/s) | +16.4% (27.3 tok/s) |
| 8 threads | −21.8% (→ 3.30 s) | −11.5% (16.9 tok/s) | +19.6% (28.1 tok/s) |

- **This is item A15,** now running: the same pool in the production sealing pass, the cause of the system time, a
  witness-plane byte test, and a 6-pass A/B to choose the pool size.

## A14: the forks' remaining host work, done (lazy sums on; the lane XOF and parallel absorb opt-in)

Full write-up: `a14/README.md`. Merged into perf; acceptance and an independent repeat of the A/B on the merged tree:
`check_a14merge.sh`, `a14merge.progress`, `a14merge_pairs.md`.

**The profile** [MEASURED, macOS `sample`, N = 6, tree 76e9b280]:
- In the forks phase each fork's main line waits on the GPU 48% of the time.
- The host share, by main-line time:

| bucket | share |
|---|---:|
| A/H zero-fill and free | 14.2% |
| the store fold | 11.7% |
| lookups and histograms | 10.2% |
| `define`'s public weight folds | 9.7% |
| helper inverses | 9.5% |
| randomness | 7.8% |
| commit host parts | 6.2% |
| private slots' tables | 5.1% |
| per-block public checks | 4.1% |
| witness planes into A | 4.0% |
| extension rounds | 3.9% |
| claimed sums | 2.9% |
| transcript absorb | 2.8% |

**What changed** (all byte-preserving):
- **Lazy sums** (`argument.rs`, the default; `HL_ARG_LAZY=0` restores):
  - Where: the accumulating private tables and `mask_eval_eq`.
  - How: the `Fp2 × Fp` products are summed exactly in u128, with wrap counts, then reduced once (2^128 ≡ −2^32 mod p).
  - My check: each product is below 2^128, every wrap is counted, and the constant is right.
- **The randomness XOF in NEON lanes** (zkp-core `rng.rs`; **opt-in**, `HL_RNG_XOF=lanes8`):
  - It is byte-identical to blake3 over 4,000 blocks and every counter edge, and `fill_fp` leaves the same state.
  - A14 made it the default. **The coordinator made it opt-in:** on top of the lazy sums it moved the proof-only wall
    by −0.2%, and it is a hand-written BLAKE3 compression inside the hiding generator, which the privacy gate would
    have to audit for no measured gain.
  - It is kept for the RTX 5090, whose host path is projected to be the limit.
- **A parallel transcript absorb** (zkp-core `transcript.rs`, via `blake3::hazmat`; opt-in, `HL_TRANSCRIPT_PAR=1`): it
  measured +1% worse.

**Byte evidence:**
- The lazy sums equal the per-term sums on every table of the rung (476 tables) and on the 8B private slots (56 tables,
  8.56 M words).
- The rung golden `96e4f0b6` holds on the CPU and on Metal under all six settings.
- One 8B block's core proof gives digest `a32cb0dd0fc2ec46` under every setting.
- 330 parallel absorbs equal the serial digest.

**Acceptance on the merged tree** (the default XOF switched to blake3) [MEASURED, one guarded job]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 925 passed, exactly the known three failed, 106 ignored; zkp-core lib 81 passed;
- the A14, A8, A12, A11 and A7 byte tests, the W16R2 rung golden and all six post-F12 digests pass;
- D55 default:
  - proof only, best 3.981 s = 32.15 tok/s;
  - one request from its input, best 8.264 s = 15.49 tok/s;
  - the stream 24.29 tok/s steady (20.63 amortized);
  - every receipt verified; 818,728,672 B unchanged.

**The independent A/B** [MEASURED, `a14merge_pairs.md`]: the lazy sums against the per-term sums, 4 passes, alternating.

| metric | order bias removed | pairs favouring the lazy sums |
|---|---:|---:|
| proof-only wall | **−2.8%** | 3 of 4 |
| forks phase | **−3.2%** | 3 of 4 |
| one request from its input | −0.4% | 2 of 4 |
| stream, steady | **−1.8% (worse)** | 0 of 4 |
| stream, amortized | −0.7% (worse) | 1 of 4 |
| user CPU | −3.4% | 4 of 4 |

- **The stream did not gain.** The agent's own A/B agrees (stream steady −0.7%).
- The stream appears limited by the sealing pass and the forks sharing the machine, which is A15's target.
- **The lazy sums stay on for now.** A15's final A/B repeats this pair on top of its sealing pool. If the stream still
  loses there, they become opt-in.

**For the privacy gate:**
- Digests that moved: `private_block/argument.rs`, zkp-core `rng.rs` and `transcript.rs` (the last two are in the run
  capture's `SHARED_SOURCE_FILES`).
- No new timing dependence on the hidden data: the lazy sums have no data-dependent branch; the lane XOF is
  constant-time and off by default; the absorb splits by length only.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

**Left on the host** (A14's ranking):
- the A/H zero-fill (first-touch by the parallel writers is still untried);
- lookups, inverses and witness planes;
- the per-block public checks, which repeat preflight's and could be cached per resident model;
- `define`'s public int8 weight folds, which would need a device fold;
- salts drawn one by one in `pcs.rs`.

## A15: the sealing pass's witness builds in their own rayon pool, done (the default)

Full write-up: `a15/README.md`. Merged into perf (910c2ac4); acceptance and an independent A/B on the merged tree:
`check_a15merge.sh`, `a15merge.progress`, `a15merge_pairs.md`, `a15merge_seal_pairs.md`.

**The cause** [MEASURED, the sealing pass alone, macOS `sample`]:
- On the 32-thread global pool the sealing pass took about 4.0 s and 15 user + 25 system CPU-seconds, for about 6.3
  CPU-s of real work.
- The system time is rayon's own: workers block on its sleep lock (20.8 thread-s), and idle workers spin on
  `yield_now` (17.3 thread-s). Each build is a run of many short parallel regions (about 70–90 per block, ESTIMATE),
  and each one wakes a wide pool.
- The pool's width is the cause. System CPU is 0.9 / 2.1 / 7.2 / 25.7 s at 4 / 8 / 16 / 32 threads, and a dedicated
  32-thread pool costs the same as the global one.

**What changed** (`trained_block.rs` only in production; byte-preserving):
- Each layer's witness build runs in a dedicated pool, `SealPool`, in `seal_and_record` (production `stack-prove`, D12a
  and D55) and in `StackSource::witness_of` (rebuilds). The next layer's load stays on the global pool.
- The switch is `HL_SEAL_POOL=<threads|0|auto>`; 0 restores the global pool.
- The default rule is `(cores/4).clamp(1, 8)`, 8 on the M3 Ultra. It is capped at 8 because 16 measured worse. On
  other machines the rule is an extrapolation; the RTX 5090 box should re-measure it.
- Harness arm words `sp<t>`, `spauto`, `spg` (the global pool entered on one of its own workers, production's form
  before A15).

**Byte evidence:**
- A 32-block 8B chain gives one digest of every witness plane in pools of 1–32 threads and on the global pool.
- At 8B, with CPU and with device products, the digest is `5808a1cd` everywhere; the rung chain's planes are equal at
  11 settings.
- The synthetic block reaches a fixed point, so the 8B chains repeat one build.

**Acceptance on the merged tree** [MEASURED, one guarded job]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 926 passed, exactly the known three failed, 107 ignored; zkp-core lib 81 passed;
- the A15 8B chain in every pool, and the A14, A8, A12, A11 and A7 byte tests, pass;
- the W16R2 rung golden `96e4f0b6` (CPU = Metal) and all six post-F12 digests pass;
- D55 default:
  - one request from its input, best 7.323 s = 17.48 tok/s;
  - the stream 29.12 tok/s steady, 24.36 amortized, per-request latency 7.8–8.9 s;
  - proof only, best 4.252 s = 30.10 tok/s (see the note below);
  - every receipt verified: fork receipts 818,728,672 B, D12a 818,728,480 B. The four stream receipts verified after
    the clock in 9.9 s.

**The independent A/B** [MEASURED, `a15merge_pairs.md`, `a15merge_seal_pairs.md`]:
- The arms: `spg` (production before A15) against `spauto`, 4 passes, alternating.
- This differs from the agent's A/B, which ran against `sp0`, the harness thread.

| metric | order bias removed | pairs favouring the pool | means before / after |
|---|---:|---:|---:|
| one request from its input | **−10.5%** | 4 of 4 | 8.487 / 7.595 s |
| stream, steady | **+16.1%** | 4 of 4 | 24.04 / 27.92 tok/s |
| stream, amortized | **+14.9%** | 4 of 4 | 20.55 / 23.61 tok/s |
| sealing pass, one request | **−20.6%** | 4 of 4 | 4.32 / 3.44 s |
| sealing pass beside the forks (stream) | −13.7% | 4 of 4 | 5.46 / 4.71 s |
| sealing user / system CPU | −50.7% / −89.6% | 4 of 4 | — |
| proof only (the control) | +0.6% | 1 of 4 | 4.158 / 4.175 s |

- **The agent's own A/B** (6 passes against `sp0`): one request −12.7%, the stream steady +18.9%. Its size sweep against
  `spg`: −10.5% and +19.3%.
- **Proof only:** this run's best (4.25 s) is slower than A14's acceptance (3.98 s). The in-process control shows no
  change from A15 (+0.6%, noise), so this is run-to-run variance on the shared Mac, not a regression.
- **The lazy sums re-checked on top of the pool** (agent, 6 passes): the stream steady +0.6% (noise), one request
  −0.9% (6 of 6 pairs), user CPU −2.6%. The earlier stream loss does not reappear; they stay on.
- **The stream is now balanced:** about 4.4 s of proof per request against about 4.6 s of sealing beside the forks
  [MEASURED, agent]. Further stream gains need both sides faster (A16: the sealing builder; A17: the forks' host
  work).

**For the privacy gate:**
- The only production digest that moved is `private_block/trained_block.rs`.
- No new timing dependence on hidden data; the pool size depends on the machine only.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A17: the forks' host work in `protocol.rs`, done (both forms on by default)

Full write-up: `a17/README.md`. Merged into perf; acceptance and an independent A/B on the merged tree:
`check_a17merge.sh`, `a17merge.progress`, `a17merge_pairs.md`, `a17merge_seal_pairs.md`.

**The profile first** [MEASURED, agent, macOS `sample`, N = 6, the post-A15 tree], shares of a fork's main-line host
time:
- A/H zero-fill and free 14.5%;
- the openings' store fold 12.8%;
- lookups 10.9%;
- public weight folds 9.9%;
- LogUp helper inverses 9.6%;
- randomness 8.5%;
- the per-block public checks 4.0%;
- the witness planes 4.0%.

**What changed** (`private_block/protocol.rs`, `private_block/run_fork.rs`; byte-preserving; each form has a switch,
and `0` restores the old code):
- **`HL_A17_LOOKED` (on): one-term lookups read straight from their witness planes.**
  - At a W16 profile every lookup but `word24`'s low limb is `cst + c * plane[x]`. Each used to be copied into its own
    column first, about 220 MB of fresh pages per block [INFERRED from the faults removed].
  - `LookedCol` reads it a 1,024-word sub-block at a time. It is used in `prove_core` and in `check_lookup_misses`, so
    production's sealing pass also does slightly less work (not measured).
- **`HL_A17_CHECKED` (on): the preflight's record stands in for each fork's CS-1/CS-4 re-check.**
  - The record is `CheckedPublic`. It holds the checked block by reference, so the block cannot change, move or be freed
    while the record lives.
  - Its only constructor runs the check, and it covers only that same block object (`ptr::eq`) at an equal shape.
  - Every other caller goes through `prove_core` and checks as before. A fork handed a different block is refused.
  - On its own it is within noise; it is kept because it only removes work and fails closed.
- **Dropped: each fork worker keeping its A and H between blocks.** Bytes matched, but it was +3.6% slower. That is
  the third zero-fill form to lose, after A11's pool and A8's calloc.

**Byte evidence:**
- The W16R2 rung golden `96e4f0b6` holds under all four A17 settings, on CPU and Metal, through both entry points.
- One 8B T128 block's seeded core proof is `90003b760eb7ad80` under every setting.
- A modified block proved beside the honest block's record is refused with CS-1/CS-4's own message.

**Acceptance on the merged tree** [MEASURED, one guarded job, the GPU quiet throughout (no `ds4-bench`)]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 929 passed, exactly the known three failed, 109 ignored; zkp-core lib 81 passed;
- the A17 rung golden under every setting, the A17 8B block under every setting, and the A15, A14, A8, A12, A11 and A7
  byte tests, all pass;
- the W16R2 rung golden `96e4f0b6` (CPU = Metal) and all six post-F12 digests pass;
- D55 default:
  - proof only, best 3.745 s = 34.18 tok/s;
  - one request from its input, best 7.145 s = 17.92 tok/s;
  - the stream 30.58 tok/s steady, 25.66 amortized, per-request latency 7.40–8.31 s;
  - every receipt verified: fork receipts 818,728,672 B, D12a 818,728,480 B. The four stream receipts verified after
    the clock in 9.4 s.

**The independent A/B** [MEASURED, `a17merge_pairs.md`, `a17merge_seal_pairs.md`]: `a17old` (the code before A17)
against `a17new` (the default), 4 passes, alternating.

| metric | order bias removed | pairs favouring A17 | means before / after |
|---|---:|---:|---:|
| proof only | **−3.6%** | 4 of 4 | 4.088 / 3.942 s |
| forks phase | −3.4% | 4 of 4 | 3.702 / 3.577 s |
| one request from its input | −0.9% | 3 of 4 | 7.301 / 7.235 s |
| stream, steady | **+2.6%** | 4 of 4 | 29.45 / 30.23 tok/s |
| stream, amortized | +2.0% | 4 of 4 | 24.69 / 25.19 tok/s |
| user / system CPU | −3.3% / −37.9% | 4 of 4 | — |
| minor faults | −41.6% | 4 of 4 | 1.15 M / 0.67 M |
| sealing pass, one request | +0.4% (noise) | 2 of 4 | 3.283 / 3.295 s |

- **The agent's own A/B** (6 passes): proof only −2.7%, one request −2.0%, the stream steady +2.4%. They agree.
- **The stream is now sealing-bound:** about 3.9 s of proof per request against about 4.4 s of sealing beside the
  forks. A16's sealing work sets the next stream gain.
- **Left** (the profile after, agent): a fork's main-line host time −10% (1.268 → 1.141 s per fork per call).
  Remaining:
  - the A/H zero-fill and the store fold, 14% each;
  - the helper inverses, 11%. The range families' 2^16-entry inverse tables are built twice;
  - the public weight folds in `define`, 11%;
  - randomness, 10%;
  - `define`'s per-slot registry re-check in `argument_accuracy.rs`, 0.019 s per fork per call, which the same record
    could cover;
  - the bulk salt draw (zkp-core `pcs.rs`), left for Sol's W16R3 work.

**For the privacy gate:**
- The production digests that moved are `protocol.rs` (a `SHARED_SOURCE_FILES` pin) and `run_fork.rs` (pinned by the
  D55 capture).
- No branch reads a hidden value. What is borrowed follows the public layout. Whether a fork re-checks follows the
  block's address and the public shape.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A16: the sealing pass's serial remainder, done (every form on by default)

Full write-up: `a16/README.md`. Merged into perf (418cf197, on top of A17). Acceptance and an independent A/B on the
merged tree: `check_a16merge.sh`, `a16merge.progress`, `a16merge_pairs.md`, `a16merge_seal_pairs.md`.

**The cause** [MEASURED, agent, macOS `sample`]. After A15, about 1.1 s of the sealing pass's 2.6 s main line per
32-block pass was the builder's own serial work:
- the supports and chunk plans, rebuilt every block;
- `quantized`'s serial read-back;
- `normalized`'s i128 divisions;
- `build`'s per-position loops;
- production's three-fold public check of each block.

After A16 that serial part is 0.04 s.

**What changed** (`private_block/witness.rs`, `private_block/witness_accuracy.rs`; byte-preserving): seven forms, all on
by default. `HL_A16=0` restores the old builder; `all` or a list such as `cache,norm` chooses forms.
- **`cache`:** each domain's support and chunk plan is kept per public geometry. The key holds every value the
  support and the plans read.
- **`quant`:** chunked requantization with no serial read-back.
- **`norm`:** rows in parallel, in i64 wherever every intermediate provably fits.
- **`loops`:** `build`'s per-position loops run on the pool.
- **`kernels`:** the score and PV sums run over contiguous int16 rows.
- **`overlap`:** Q/K/V run side by side, and so do gate and up.
- **`once`:** production's `build_for_block` runs `check_accuracy_for_shape` once.
  - Each skipped repeat is the same function of the same shape and the same borrowed halves. Bad data is still refused
    by the first check, with its message.
  - `build_accuracy`, called directly, keeps every check except its exact duplicate of `check_for_registry`.

Every parallel form falls back to the sequential loop on any refusal, so refusals are the old ones. The pool rule stays
at 8 threads: 12 and 16 lost every pair in the clean re-sweep.

**Byte evidence:**
- The 32-block 8B chain's planes have one digest under all 18 sealing-alone arms.
- The 8B witness planes are `5808a1cd` in every form set, with CPU and with device products.
- The calibration variants refuse identically in every form set.
- At the rungs, R13 DD and TinyLlama T128, under 16 form sets, every plane and every refusal is equal.

**Acceptance on the merged tree** [MEASURED, one guarded job, the GPU quiet throughout]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 936 passed, exactly the known three failed, 110 ignored; zkp-core lib 81 passed;
- the A16 8B test, the A17 rung golden and 8B block under every setting, and the A15, A14, A8, A12, A11 and A7 byte
  tests, all pass;
- the W16R2 rung golden `96e4f0b6` (CPU = Metal) and all six post-F12 digests pass;
- D55 default:
  - one request from its input, best 5.347 s = 23.94 tok/s; the sealing pass 1.47–1.52 s;
  - the stream 33.02 tok/s steady, 29.09 amortized, per-request latency 5.97–10.93 s;
  - proof only, best 3.796 s = 33.72 tok/s;
  - every receipt verified: fork receipts 818,728,672 B, D12a 818,728,480 B. The four stream receipts verified after
    the clock in 9.2 s.

**The independent A/B** [MEASURED, `a16merge_pairs.md`, `a16merge_seal_pairs.md`]: `a16old+prod` against
`a16def+prod`, 4 passes, alternating.
- Every witness is built through production's `build_for_block`, as `seal_and_record` builds it.
- The agent's main A/B used the harness's `build_accuracy` path.

| metric | order bias removed | pairs favouring A16 | means before / after |
|---|---:|---:|---:|
| one request from its input | **−23.8%** | 4 of 4 | 7.377 / 5.624 s (17.4 → 22.8 tok/s) |
| sealing pass, one request | **−50.8%** | 4 of 4 | 3.476 / 1.708 s |
| sealing pass beside the forks (stream) | −41.8% | 4 of 4 | 4.554 / 2.648 s |
| stream, steady | **+12.8%** | 4 of 4 | 29.02 / 32.72 tok/s |
| stream, amortized | **+17.1%** | 4 of 4 | 24.43 / 28.60 tok/s |
| proof only (the control) | −2.1% | 4 of 4 | 3.970 / 3.887 s |
| sealing user / system CPU | −36.4% / +47.6% | — | — |

- **The agent's own A/Bs agree** (6 passes, quiet GPU):
  - the harness path: one request −22.1%, the stream +7.0% steady and +12.8% amortized;
  - production's builder (4 passes): one request −23.9%.
- **The sealing pass's system CPU rose** (2.9 → 4.3 s). It now runs more, shorter parallel regions on its 8 threads.
  That cost is already inside the measured wall.
- **The stream is now fork-bound.** Sealing beside the forks (2.6 s) is shorter than a fork run (about 3.9 s). Its
  steady rate is the forks' own (about 33 tok/s), and latency inside the stream rises as sealed requests queue for the
  forks.
- **Left in the sealing pass:**
  - the seven device products;
  - `assign`'s per-plane fill regions, which could be fused;
  - `quantized`'s fills, and the zeroing and first touch of fresh pages;
  - overlapping the attention half's `assign` with the feed-forward products;
  - production's load-time `check_accuracy_for_shape` in `load_layer_mode`, still repeated by the build.

**For the privacy gate:**
- The production digests that moved are `private_block/witness.rs` and `private_block/witness_accuracy.rs`.
- No path whose time depends on a hidden value was added:
  - sequential re-runs happen only on a refusal, which ends the build;
  - the int16 and i64 forms decline only outside classes that earlier range checks already enforce;
  - the norm's bound uses at least the int16 maximum and the public isqrt window.
- The caches hold only public geometry. `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A18: the forks phase, round 2, done (two small forms on; A13's window ported, off by default)

Full write-up: `a18/README.md`. Merged into perf (3577a374, on top of A16 and the plan's 028a0012); no conflicts.
Acceptance and an independent A/B on the merged tree: `check_a18merge.sh`, `a18merge.progress`, `a18merge_pairs.md`,
`a18merge_seal_pairs.md`.

**The profile** [MEASURED, agent, macOS `sample`, `a18/s1_rank.md`]. With six forks, 54.5% of a fork's main-line
samples wait on the GPU. Of the rest (about 1.1 s per fork per call), the largest host buckets are:
- the openings' store fold, 14.8%;
- the A/H zero-fill and free, 13.1%;
- the LogUp helper inverses, 10.9%;
- `define`'s public weight folds and tables, 10.9%;
- the randomness, 9.5%.

**What changed** (`private_block/protocol.rs`, `run_fork.rs`, `argument.rs`, `argument_accuracy.rs`; byte-preserving):
- **`HL_A18_TABINV`** (on by default):
  - the range table helpers read their families' inverse tables, which are already made for the looked columns'
    helpers, instead of inverting the same denominators a second time;
  - the byte and exp table helpers invert only the 256 distinct entries of their periodic tables;
  - the three table helpers fell from 4.65 to 0.78 ms per block. No parallel region is added.
- **`HL_A18_REGISTRY`** (on by default): in the D55 fork run, preflight's record stands in for `define`'s per-slot
  `check_for_registry`.
  - Only for the same data object at an equal shape: `CheckedPublic::covers_accuracy` uses `ptr::eq`, and its
    `check_accuracy_for_shape` runs that very call with the same registry, geometry, base and stack.
  - Any other caller checks slot by slot, as before.
- **A13's split, ported onto A14–A17:**
  - `prove_core_with` is now `prove_core_before_with` followed by `prove_core_after_with`. The only move is that A's
    root is absorbed after M is committed; M's commitment reads no transcript, so the transcript and the generator see
    the same sequence.
  - The rest refuses a state made for another block object, shape or layout.
  - In `run_fork.rs`, `ForkLate` carries what only exists after preflight and the commit phase.
  - The window `HL_D55_AHEAD` is **off by default**.
- **Removed after measurement:** the range tables and the activation table helper in parallel chunks (+3.2%, +1.6%), and
  `define`'s public tables in parallel maps (+1.2%, +1.4%). Both added short parallel regions to every fork, and sys
  CPU rose 4–7%. A11's pool width was re-swept: 6 stays.

**Byte evidence** [MEASURED, agent and the merged tree]:
- the W16R2 rung golden `96e4f0b6` under every A18 setting, CPU and Metal, through `prove_core`, through
  `prove_core_with` beside the record, and through the split core;
- the 8B block `90003b760eb7ad80` in every proof under every setting;
- A13's parked forks equal whole forks byte for byte on every path, CPU and Metal (seeded generators, test builds
  only).

**Acceptance on the merged tree** [MEASURED, one guarded job, the GPU quiet throughout]:
- build rc 0; no-feature `cargo check --tests` rc 0;
- full lib suite: 939 passed, exactly the known three failed, 113 ignored; zkp-core lib 81 passed;
- passing: the A18 rung golden, 8B block and parked-fork device tests; the A16 8B planes in every form (`5808a1cd`);
  the A17 rung golden and 8B block; the A15, A14, A8, A12, A11 and A7 byte tests;
- the W16R2 rung golden `96e4f0b6` (CPU = Metal) and all six post-F12 digests pass;
- D55 default (window off):
  - one request from its input, best 5.373 s = 23.82 tok/s (mean 23.40);
  - the stream 32.84 tok/s steady, 29.21 amortized;
  - proof only, best 3.925 s = 32.61 tok/s;
  - every receipt verified: fork receipts 818,728,672 B, D12a 818,728,480 B.

**The independent A/B** [MEASURED, `a18merge_pairs.md`, `a18merge_seal_pairs.md`]: `a18old+prod` against
`a18def+prod`, 4 passes, alternating, every witness through production's `build_for_block`.

| metric | order bias removed | pairs favouring A18 | means before / after |
|---|---:|---:|---:|
| proof only | +0.7% | 1 of 4 | 3.966 / 3.995 s |
| forks phase | +1.4% | 0 of 4 | 3.571 / 3.622 s |
| one request from its input | −1.9% | 4 of 4 | 5.559 / 5.454 s |
| stream, steady | +0.3% | 2 of 4 | 32.40 / 32.48 tok/s |
| stream, amortized | −0.1% | 2 of 4 | 28.86 / 28.84 tok/s |
| sealing pass, one request (the control) | −0.4% | 1 of 4 | 1.524 / 1.512 s |

- **The default forms are neutral within the ±2% noise floor.** The agent's final A/B (6 passes) agrees: one request
  −2.0% (6 of 6), proof only +0.2%, stream −0.6%.
  - The one-request direction is the same in all 10 pairs, but the forks phase here leans slightly the other way.
  - They stay on: one is pure work removal and the other is fail-closed. `0` restores either.
- **A13's window is the real gain** [MEASURED, agent, harness only]. At window 16, against the A18 forms, 6 passes,
  both orders:
  - the 4-request stream +5.0% steady (32.11 → 33.70 tok/s, 6 of 6) and one request −2.3%;
  - the forks phase −7.7% and the sealing pass +9.0%;
  - peak footprint 74.5 → 86 GiB;
  - window 8: +2.5%; window 32: +0.5% with amortized −5.7% and 130 GiB.

  Production cannot use it yet: `stack-prove` builds its statement, `ForkRun` and fork blocks only after the whole
  sealing pass. **A19 is porting it to production's D55 path.**
- **Why parallel forms lose here** [INFERRED]: six 6-thread fork pools already oversubscribe the 32 cores. A short
  parallel region's wake-up and spin cost the other forks' commits more than the few milliseconds of serial work it
  saves.

**For the privacy gate:**
- The production digests that moved are `private_block/protocol.rs`, `run_fork.rs`, `argument.rs` and
  `argument_accuracy.rs`.
- No path whose time depends on a hidden value was added. The range-table gathers are indexed by public table
  positions, and the registry skip follows the block's address and the shape.
- With the window off nothing is parked. If it is ever turned on, W-8(5)'s wording changes ("the generator is moved
  with the parked fork"), while the s25 census still holds; A19 must also show that H-1 (D29) still holds.
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A19: production's D55 path, done (shared blocks on; A13's window usable from production, off by default)

Full write-up: `a19/README.md`. Merged into perf (3fc8cf92, on top of A18's 3577a374 and c0d25b29); no conflicts.
Acceptance and an independent A/B on the merged tree: `check_a19merge.sh`, `a19merge.progress`, `a19merge_pairs.md`,
`a19merge_seal_pairs.md`.

**What changed** (`private_block/trained_block.rs`, `run_fork.rs`, and one line of `r6_tests.rs`; byte-preserving):
- `stack-prove --d55-workers N` now runs `trained_block::d55_seal_and_prove`. Its steps, refusals and stdout events are
  in the order they had before. The `sealed` and `d55-proved` events gain public counts.
  - The sealing pass is `seal_chain` over a `StackModel`: production's export (`ExportStack`), or the tests' synthetic
    stack. D12a's `seal_and_record` runs the same `seal_chain` with nothing handed over (`NoHand`), so D12a is
    unchanged.
- **`HL_A19_SHARE`** (on by default; `0` restores the old code): the fork run proves with the block objects the sealing
  pass loaded and checked (`run_fork::SealedBlocks`, each block set once). Before, it loaded all 32 blocks a second time
  after the sealing pass. The preflight still re-hashes every block against the statement (CS-6).
- **A13's window from production** (`HL_D55_AHEAD`, **off by default**):
  - a `ForkPlan` (the D55 profile, the NTT domain and each stage's IO rows) is made from the run shape before the
    statement exists;
  - `prove_run_with_forks_planned` runs the sealing pass with the side workers beside it;
  - `Planned::check` holds the plan against the fork run before the run directory exists;
  - each part is held against its fork's own stage when it is finished.
- R6's CS-3 source audit now reads `seal_chain`, and checks that both entry points run it. The coordinator reviewed
  this edit and accepted it.

**Byte evidence** [MEASURED, agent and the merged tree]:
- the planned path at the W16R2 rung, and real `stack-prove` / `stack-verify` on a 4-layer R13 export (the registered
  D55 profile), CPU and Metal, window off and on, blocks shared and reloaded: every receipt verifies, heads equal the
  replayed commit phase, and interior forks equal whole forks;
- the controls refuse as required: a refused chain gives window 0's exact string, creates nothing and leaves 0 parts
  alive; a plan with another profile or with swapped IO rows, parts against another blocks object, and a layout with
  swapped IO rows are all refused.

**Acceptance on the merged tree** [MEASURED, one guarded job, the GPU quiet at every clock]:
- builds: the build, the no-feature `cargo check --tests` and the production (non-test) library build, rc 0;
- full lib suite: 941 passed, exactly the known three failed, 116 ignored; zkp-core lib: 81 passed;
- passing:
  - A19's two device tests;
  - the A18 rung golden, 8B block and parked-fork tests;
  - the A16 8B planes in every form;
  - the A17, A15, A14, A8, A12, A11 and A7 byte tests;
- the W16R2 rung golden `96e4f0b6` (CPU = Metal), all six post-F12 digests and the 8B core `90003b760eb7ad80`: all
  pass;
- the harness's D55 default:
  - one request from its input, best 5.411 s = 23.65 tok/s;
  - the stream 33.40 tok/s steady, 29.57 amortized;
  - proof only, best 3.940 s = 32.49 tok/s;
  - every receipt verified: 818,728,672 B (D12a 818,728,480 B);
- **production's D55 path on the default** (`d55_seal_and_prove`, the synthetic 32-block W16R2 8B T128 stack, each
  layer's load hashing its layer record as production's load does): one request best 15.300 s = 8.37 tok/s. Its
  receipts verified in the run directory.

**The independent A/B** [MEASURED, `a19merge_pairs.md`, `a19merge_seal_pairs.md`]:
- `share0+noahead` (the path before A19) against `share1+noahead` (the A19 default);
- through production's function, 4 passes, alternating, budget 32 GiB;
- the cold run and each arm's first pass were verified in the run directory; every receipt was 818,728,672 B.

| metric | order bias removed | pairs favouring A19 | means before / after |
|---|---:|---:|---:|
| one request from its input (production's path) | **−20.9%** | 4 of 4 | 19.347 / 15.305 s |
| its prove call | −0.5% | 4 of 4 | 4.196 / 4.176 s |
| its forks phase | +0.4% | 2 of 4 | 3.569 / 3.583 s |
| its sealing pass | +1.2% | 0 of 4 | 8.990 / 9.102 s |
| request user / sys CPU | −4.8% / +9.2% | | |

- **The shared blocks pay in every pair.** The agent's 6-pass A/B agrees: −20.7%, 19.26 → 15.28 s. The 4.15 s second
  load is gone. The sealing pass is about 1% slower, which is probably the cost of keeping all 32 blocks resident
  beside the builds [INFERRED]. Peak footprint is unchanged.
- **A13's window stays off** [MEASURED, agent, production's path, 6 passes, both orders]:

  | form | one request | prove call | peak footprint |
  |---|---:|---:|---:|
  | window 16 | −0.4% | −4.0% | +10 GiB |
  | window 16, copy-only loads | −1.0% | | |
  | window 32, 64 GiB budget | −1.0% | −9.4% | +30 GiB |

  None of these clears the ±2% noise floor. Production has no stream form, which is where the window paid (+5.0%,
  A18).

**Where production's one request goes** [MEASURED, agent, `a19/README.md` §4.5; the means of 6 passes]:

| part of the request | time |
|---|---:|
| the sealing pass | 9.1 s |
| its 32 witness builds, slowed about 5× by the loads beside them | 8.1 s (1.7 s with copy-only loads) |
| the prove call | 4.2 s |
| writing the receipt | about 1.9 s |
| the preflight's CS-6 re-hash of 32 distinct blocks | 0.30 s |

- The sealing pass is load-bound. Each layer's load hashes the layer record beside the witness builds.
- The harness's 5.4 s does not include these per-request costs. Production's figure (15.3 s, 8.4 tok/s) is the honest
  single-request figure for `stack-prove` today. A real export also reads and pads the weight files, so 15.3 s is a
  lower bound.
- **A20 (running)** cuts these costs without moving a byte.

**For the privacy gate:**
- The production digests that moved are `private_block/trained_block.rs` and `run_fork.rs`.
- No path whose time depends on a hidden value was added. The hand-over schedule reads k, the window and byte sizes
  derived from the shape.
- With the window off nothing is parked. If it is turned on, W-8(5)'s wording changes as A18 noted.
- H-1 (D29) is read as still holding by D68 (security owner's reading, not a privacy acceptance).
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A20: production's per-request host work, done (three forms on by default)

Full write-up: `a20/README.md`. Merged into perf (e4a887e0, on top of A19's write-up 8314fcb0 and D69 c07e0b33); no
conflicts. Acceptance and an independent A/B on the merged tree: `check_a20merge.sh`, `a20merge.progress`,
`a20merge_pairs.md`, `a20merge_seal_pairs.md`, `a20merge_prod_pairs.md`, `a20merge_table.md`.

**What the profile found** [MEASURED, agent, 8B block]:
- SHA-256 runs in software on this Mac, at about 0.5 GB/s. `sha2 0.10.9` uses the Arm SHA instructions only with its
  `asm` feature, which needs the `sha2-asm` crate.
- One 8B layer record took 252 ms: the nine word SHA-256s in parallel (146 ms; the 67 MB `wg_t` alone 132 ms), then
  the block's one-thread BLAKE3 digest (115 ms).
- The 1.94 s receipt write was 1.62 s of frame SHA-256s, one after another.
- **Correction to A19:** "the loads slow the builds 5×" was a clock artifact. Inside `rayon::join`, the worker waiting
  for the build runs the queued load itself, so the build's clock read 258 ms; the build takes 40 ms. The sealing pass
  was waiting on its loads.

**What changed** (`private_block/trained_block.rs`, `run_fork.rs`, `trained_statement.rs`; byte-preserving; each
form restored by its switch at `0`):
- **`HL_A20_RECPAR`** (on): the layer record's block digest is computed beside its SHA-256s. Every field is a pure
  function of the block.
- **`HL_A20_LOADS = 4`**: the sealing pass's loads run on threads of their own, up to 4 layers ahead of the build. The
  pass takes them in layer order, at the place it always took them. A scope joins the loaders before `seal_chain`
  returns.
- **`HL_A20_WRITE = 16`**: the receipt's frames are written, flushed and hashed by 16 threads. Each frame goes through
  the same steps (`write_fork_frame`). The list is in file order, and the first failure in file order is returned.
- The words hashed in place instead of from their copies measured +0.6% and were removed, with their `unsafe` block.

**Byte evidence** [MEASURED, agent and the merged tree]:
- Layer records, block digests and the statement identity (`10a8fd14…` at the R13 rung) are equal under every
  setting. The tests cover the W16R2 rung block, a legacy block, the R13 export through the real loader and the 8B
  block, on the CPU and Metal.
- Everything the sealing pass returns is equal at 7 load and record settings and 2 budgets.
- The receipt write gives the same files, bytes, list and refusals at writer counts 0 to 64.
- Production's path under the forms off and on: every receipt verifies, heads replay, and interior forks equal whole
  forks.
- A chain whose layer 1 fails parity while layers 2 and 3 fail their loads refuses with layer 1's parity, at every
  setting.

**Acceptance on the merged tree** [MEASURED, one guarded job, the GPU quiet at every clock]:
- **Builds:** the build, the no-feature `cargo check --tests` and the production (non-test) library build, rc 0. The
  same six dead-code warnings as A19; none is new.
- **Suites:**
  - full lib suite: 945 passed, exactly the known three failed, 119 ignored;
  - zkp-core lib: 81 passed.
- **Device and byte tests, all passing:**
  - A19's two device tests and A20's two device tests;
  - the A18 rung golden, 8B block and parked-fork tests;
  - the A16 8B planes in every form;
  - the A17, A15, A14, A8, A12, A11 and A7 byte tests.
- **Goldens:** the W16R2 rung golden `96e4f0b6` (CPU = Metal), all six post-F12 digests and the 8B core
  `90003b760eb7ad80` all pass.
- **The harness's D55 default** (the model in memory):
  - one request from its input: best 5.465 s = 23.42 tok/s;
  - the stream: 32.29 tok/s steady, 28.76 amortized (one stream pass; A19's was 33.40 / 29.57);
  - proof only: best 3.942 s = 32.47 tok/s;
  - every receipt verified: 818,728,672 B (D12a 818,728,480 B).
- **Production's D55 path on the default** (2 passes): best 8.134 s = 15.74 tok/s. Its receipts verified in the run
  directory.

**The independent A/B** [MEASURED, `a20merge_prod_pairs.md`, `a20merge_pairs.md`, `a20merge_seal_pairs.md`]:
- `a20old` (every A20 form off) against `default` (the A20 defaults);
- through production's `d55_seal_and_prove`, 4 passes, alternating, budget 32 GiB;
- the cold run and each arm's first pass were verified in the run directory; all 25 receipts were 818,728,672 B.

| clock | order bias removed | pairs favouring A20 | means before / after |
|---|---:|---:|---:|
| **one request from its input (production's path)** | **−50.1%** | 4 of 4 | 16.073 / 8.011 s |
| its sealing pass | −65.4% | 4 of 4 | 9.688 / 3.345 s |
| its witness builds (summed) | −78.0% | 4 of 4 | 8.517 / 1.869 s |
| the receipt write | −83.1% | 4 of 4 | 1.951 / 0.330 s |
| its prove call | −1.6% | 3 of 4 | 4.340 / 4.270 s |
| peak footprint | +0.5% | | 43.2 / 43.4 GiB |

- The agent's 6-pass A/B on its final tree agrees: −50.6% in every pair (15.49 → 7.65 s; best 7.59 s = 16.88 tok/s).
- In this A/B, production's best one request was 7.865 s = 16.27 tok/s.

**Where production's one request goes now** [MEASURED, agent §10 and the A/B means]:
- the prove call: 4.2–4.3 s;
- the sealing pass: 3.1–3.3 s, of which 1.7–1.9 s is builds, about 0.8 s waiting for loads, and the rest the first loads
  and the checks;
- the receipt write: 0.33 s;
- the preflight's CS-6 re-hash: 0.30 s.

**What comes next:**
- **A21 (running):** hardware SHA-256 written in-tree on the stable aarch64 intrinsics, with no new crate; and a
  parallel BLAKE3 block digest.
  - Enabling `sha2`'s own `asm` feature is the wrong fix: on x86 it would replace the SHA-NI path with plain assembly,
    a regression on the RTX 5090 box.
- **A22 (running, D70):** production's resident-model stream form. The model is loaded and its records made once per
  process, and the stream is the harness's pipeline.

**For the privacy gate:**
- The production digests that moved are `private_block/trained_block.rs`, `run_fork.rs` and `trained_statement.rs`.
- New threads: up to 4 loaders and 16 writers, each in a scope joined before its function returns. They hold public
  blocks and receipt bytes only; the private sequence is read on the pass's own thread.
- There is no `unsafe` in production text, and no new hash call site or absorb label.
- H-1 (D29) is read as still holding by D71 (security owner's reading, not a privacy acceptance).
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## A21: production's host hashing, done (both forms on by default)

Full write-up: `a21/README.md`. Merged into perf (2eb26c7f). Acceptance and an independent A/B on the merged tree were
run together with A22's, in one job (`check_a22merge.sh`, `a22merge.progress`, `a22merge_prod_pairs.md`). A21's own
merged-tree job (`check_a21merge.sh`) was queued behind other jobs and stopped before it started; the combined job
covers every test it listed.

**What changed** (`run_sink.rs`, `private_block.rs`, `trained_statement.rs`, `trained_block.rs`; byte-preserving; each
form restored by its switch at `0`):
- **`HL_A21_SHA`** (on):
  - FIPS 180-4 SHA-256 written in-tree (`run_sink::a21_sha`), with its compression on the stable aarch64 SHA-2
    intrinsics.
  - It is used only after `is_aarch64_feature_detected!("sha2")`; on every other target and CPU, `sha2` runs unchanged.
  - One wrapper serves the layer record, the export loader's array hashes and the receipt frames, both written and
    verified.
  - No crate was added and nothing in Cargo changed. `sha2`'s `asm` feature would have replaced x86's SHA-NI path
    with plain assembly.
- **`HL_A21_B3PAR`** (on, 1 MiB leaf):
  - `BlockPublic::digest` is computed as BLAKE3's own tree, with its subtrees hashed in rayon tasks through blake3's
    public `hazmat` API.
  - The int8 words are fed from stack buffers: no copies and no `unsafe`.

**Profile** [MEASURED, agent, 8B]:

| measure | before | after |
|---|---:|---:|
| SHA-256 throughput | 0.51 GB/s | 2.31 GB/s |
| block digest | 115.3 ms | 5.9 ms |
| layer record | 138.7 ms | 32.2 ms |
| one load | 143 ms | 36 ms (cheaper than one 45 ms witness build) |
| the verifier's frame hashing | 1,618 ms | 352 ms |

**Byte evidence** [MEASURED, agent]:
- SHA-256 equals `sha2` on the NIST vectors, every length 0..=1100 at 8 offsets, lengths up to 16 MB, and the 8B
  words.
- The tree digest equals the one-pass digest on rung, legacy, R13, 8B and random blocks, at six leaf sizes.
- Records, the statement identity `10a8fd14…`, the sealing pass and every refusal are unchanged, on the CPU and on
  Metal.

**The A/Bs:**

| A/B | one request | pairs | means |
|---|---:|---:|---|
| agent: both forms against neither | −10.5% | 6 of 6 | 7.873 → 7.045 s |
| agent: SHA inside the defaults | −10.7% | 6 of 6 | |
| agent: B3PAR inside the defaults | −6.3% | 6 of 6 | |
| agent: SHA alone | −2.2% | | |
| agent: B3PAR alone | 0.0% | | |
| **merged tree: `a21old` against `default`** (4 passes) | **−8.0%** | 4 of 4 | 7.859 → 7.229 s |

- Alone, each form helps little or not at all: the record runs both hashes side by side and waits for the slower one.
- On the merged tree, the sealing pass is −13.1% and its wait for loads −90.3% (0.757 → 0.073 s). The pass now waits
  on its witness builds.
- The verifier: −30.3% (4.998 → 3.462 s, 4 of 4, agent).
- Production's one request on the default: best 6.819 s = **18.77 proved tok/s** (merged tree).

**For the privacy gate:**
- The source pins that moved are `run_sink.rs`, `private_block.rs`, `trained_statement.rs` and `trained_block.rs`.
- There is new `unsafe`, in `a21_sha` only: the call into the target-feature function after detection, and the NEON
  loads and stores over fixed-size arrays, each with a SAFETY comment.
- Private sequence files given with a manifest are now hashed by the new code. Its time depends on their length only.

## A22: production's resident-model stream form `stack-serve`, done (D70; stream 29.7 tok/s steady)

Full write-up: `a22/README.md`. Merged into perf (ab7e63cb, on top of A21). Acceptance and an independent stream A/B
on the merged tree: `check_a22merge.sh`, `a22merge.progress`, `a22merge_stream_table.md`.

**What it is:**
- `stack-serve` is a long-lived prover over any `StackModel`. At startup it loads and checks the export once, with
  every `stack-prove` admission check, then makes every layer's record and the model statement once. That takes
  0.57 s for the synthetic 8B stack.
- Requests arrive one per stdin line (JSON) and results leave one per line, in request order.
- Each request runs the unchanged `d55_seal_and_prove` over the resident model and that request's own input.
  - Request r + 1's sealing pass runs beside request r's fork run. There are two lanes, a sealing turn and a prover
    turn taken in request order, and at most one sealed request waits.
  - The receipt write happens outside both turns.
- A request's statement must equal the startup identity before its run header. Refusals print D65(2)'s constant line.
  A failure after the header removes that run's directory, and the stream carries on.
- **One data owner per process** (the security owner's rule, until a ruling): a request's latency shows the previous
  request's sealing time.

**Byte evidence** [MEASURED, agent; the merged tree's device tests]:
- The server's sealing pass is `stack-prove`'s, word for word.
- Four requests on one input:
  - each is verified by a fresh `stack-verify`;
  - each has `stack-prove`'s identity, receipt size and frame list;
  - no two share any commitment or frame, so the randomness is fresh per request.
- A 10-request stream gets each case right, in order:
  - refused inputs;
  - an existing directory;
  - I/O failures after the header;
  - a bad line;
  - a statement-file failure.
- With seeded generators, heads replay and interior forks equal whole forks.
- Every served 8B receipt is 818,728,672 B.

**Acceptance on the merged tree (A21 and A22 together)** [MEASURED, one guarded job, the GPU quiet at every clock]:
- **Builds:** the build, the no-feature `cargo check --tests`, the production non-test build and the stack CLI example
  (`stack-prove`, `stack-serve`) all return rc 0, with the same six dead-code warnings as before.
- **Suites:** the full lib suite passed 953, failed exactly the known three, and ignored 127. zkp-core lib passed 81.
- **Device tests:**
  - A22's three: the R13 export through the server against `stack-prove`, the resident rung stream and the resident
    8B stream;
  - A21's two, A20's two and A19's two.
- **Earlier byte tests:** A18's rung golden, 8B block and parked forks; the A16 8B planes; and the A17, A15, A14, A8,
  A12, A11 and A7 tests.
- **Goldens:** the W16R2 rung golden `96e4f0b6` (CPU = Metal), all six digests and the 8B core `90003b760eb7ad80`.
- **The harness's D55 default** (the model in memory): one request best 5.427 s = 23.59 tok/s; proof only best
  3.917 s = 32.68 tok/s.

**The independent stream A/B** [MEASURED, `a22merge_stream_table.md`; through the server's code path, in process;
synthetic W16R2 8B T128, 32 blocks, N = 6, 4 passes, alternating]:

| arm | steady tok/s | amortized tok/s | first request's latency | peak footprint |
|---|---:|---:|---:|---:|
| `serve1` (one request) | — | 18.85 | 6.79 s | 50.3 GiB |
| **`serve4`** | **29.67** | **25.28** | 7.31 s | 59.8 GiB |
| `serve8` | 29.06 | 26.89 | 7.25 s | 60.3 GiB |
| `harness4` (the model in memory, receipts kept in memory) | 32.65 | 28.93 | 5.94 s | 54.7 GiB |

- The agent's 4-pass A/B on the same tree agrees: serve4 29.23 steady, harness4 32.53. Its digests-ahead form
  (`HL_A22_DIGEST_AHEAD`) gave +4.9% steady (4 of 4).
- Mean latency from arrival (13.9 s for serve4) is queueing: all four requests arrive at t = 0. Each request's own
  time is about 9 s.
- **The gap to the harness** (agent §5.3; about 0.44 s a request, the stream bound by the prover turn):
  - +0.20 s in the preflight, mostly CS-6 re-hashing 32 distinct block copies;
  - +0.21 s in the forks, slowed beside the next request's heavier production sealing pass, which copies about 7.8 GB
    of layers;
  - +0.03 s in the commit.

**What comes next:**
- **D72:** CS-6 may compare a digest kept with the block object.
- **A23 (running):** share the resident blocks across requests instead of copying them, with CS-6 checking their
  startup digests under D72. The target is the harness's 32.5 tok/s or better.
- `HL_A22_DIGEST_AHEAD` and A13's window stay off in this merge.

**For the privacy gate:**
- The source pins that moved are `trained_block.rs`, `run_fork.rs`, `private_block.rs` (one re-export) and
  `examples/zk60_trained_block.rs`.
- **New threads per stream:** one reader and two lanes. A lane holds a private input only for the request it is
  serving.
- **Known limit:** the process-wide `gpu_declines` count fails closed. After one decline every later request fails;
  the correct value would be a per-request count.
- H-1 per request and the cached-record binding are read as holding by D73 (the security owner's reading, not a
  privacy acceptance).
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
