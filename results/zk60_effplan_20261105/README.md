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
