# A15: the sealing pass's witness builds in their own rayon pool (2026-11-05)

The plan: `docs/zkmatrix-poc/ZK60_EFFICIENCY_PLAN_20261105.md`, item A15. Byte-preserving. It productionizes A13's
harness-only probe (`../a13/README.md` §6: the sealing pass in a pool of 8 or 16 threads paid in every pair).

Labels: [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers; [ESTIMATE] a
judgement, not a measurement.

All runs: W16R2 8B T128, 32 blocks, the D55 fork run at N = 6 (A11's per-fork pools of 6), `HL_GPU=1 HL_PB_ORACLE=0
HL_METAL_TIMING=0`, on the shared M3 Ultra (32 logical CPUs), every stage one guarded job (class gpu, the shared
heavy lock). Stage 1 ran on perf `dd4e5a66`; stages 2 to 4 on perf `345f257a` (A14 merged, the XOF default blake3)
with A15.

## Plain summary

- **What was slow.** Before a request's forks can start, the sealing pass builds all 32 witnesses one after another.
  Each build is some 70 to 90 short parallel regions. On the 32-thread global rayon pool every region wakes workers
  through rayon's sleep lock, and when it ends the idle workers spin on `yield_now` (a system call on macOS) before
  they sleep again. Alone, the pass took 4.0 s and 15 user + 25 system CPU-seconds for about 6.3 CPU-seconds of work
  [MEASURED, §2].
- **The cause is the pool's width, not sharing it or nesting.** A dedicated 32-thread pool costs the same; entering
  the global pool on one of its own workers (as production did) saves 2%. System CPU falls from 25.7 s at 32 threads
  to 7.2 at 16 and 2.1 at 8; the sample puts the 32-thread pool's time in the sleep lock (21 thread-seconds per two
  passes) and the yields (17) [MEASURED, §2].
- **The fix** (`trained_block.rs`, production, and the harness): each witness build of the sealing pass, and each
  rebuild of a witness the cache did not keep, runs inside a dedicated rayon pool, `SealPool`, made once per size.
  `HL_SEAL_POOL=<threads|0|auto>`; 0 is the global pool. **The default is a quarter of the logical CPUs, at most 8:
  8 threads on this Mac**, chosen by a 7-arm sweep (§5.1).
- **The gain** [MEASURED, §5.2, 6 passes, both orders, every pair]:
  - **one request from its input −12.7%**, 8.42 → 7.35 s (15.2 → 17.4 tok/s; best 17.8);
  - **the 4-request stream +18.9% steady**, 24.4 → 29.0 tok/s (best 29.9), **+17.5% amortized**, 20.8 → 24.4 tok/s;
  - the sealing pass −23.6% (4.37 → 3.34 s), its user CPU −52%, its system CPU −90%;
  - proof only, the control without a sealing pass: +0.8%, noise.
- **No byte moves** (§4): every plane of every witness of the 32-block 8B chain has one digest in pools of 1 to 32
  threads and on the global pool; the rung's planes are equal in every pool (a suite test); the 8B block's are equal
  under CPU and device products in every pool; the rung golden, the six trained digests and the receipt sizes hold.
- **The coordinator's lazy-sums check** (§5.3): on top of the sealing pool, A14's lazy sums no longer cost the stream
  (+0.6% steady, +0.4% amortized, within noise); one request −0.9% in every pair. Keep them on.
- **Next** (§7): the builder's serial remainder (about 1.6 s of the 2.9 s pass), production's doubled public checks
  per block, and the rule on the RTX 5090's CPU.

## 1. Where the sealing pass and the witness chain run

| # | site | what | A15 |
|---|---|---|---|
| 1 | `trained_block::seal_and_record` | the production sealing pass of `stack-prove` (D12a and D55, `--d55-workers`): each layer's witness built from the previous output, beside the next layer's load (`rayon::join`) | **the build in the sealing pool**; the load stays on the global pool |
| 2 | `trained_block::StackSource::witness_of` | the production witness source: a witness A3's cache did not keep is rebuilt from its sealed input, on the D55 fork feeder or before each D12a stage | **the rebuild in the sealing pool** |
| 3 | `run_fork_tests.rs`, `forked_sealed` | the D55 harness, one request from its input (`HL_D55_SEALED`, `HL_D55_AB_SEALED`) | **through the sealing pool** (arm words below) |
| 4 | `run_fork_tests.rs`, `piped` | the D55 harness's stream (`HL_D55_PIPE`, `HL_D55_AB_PIPE`): request r + 1's sealing pass on a sealing thread while request r's forks run | **through the sealing pool** |
| 5 | `run_fork_tests.rs`, the setup chain and `witnesses()` | the harness's own off-the-clock builds (the chain's inputs; the witness sets of the proof-only and D12a calls, 8 builder threads) | unchanged (not on any clock) |
| 6 | `run_fork_tests.rs`, `forked_jit` | witnesses built on the clock by concurrent builder threads (`HL_D55_JIT`, H124c) | unchanged |
| 7 | `mvp_driver.rs`, `StackSource::prepass` / `advance` | the synthetic-stack MVP driver (D12a): its sealing pass and a rebuild before every stage | same shape, **not changed** (not on the D55 path) |
| 8 | `token_io/cli.rs`, `seal_chain` and `CliSource::witness`; `token_io/run.rs`, `downstream_at` | the token CLI's sealing pass (PR4-4) and its per-stage builds (D12a token runs); the honest pipeline of the token tests | same shape, **not changed** (not on the D55 path) |
| 9 | `trained_block::parity` | one block's parity check (one build) | not changed |

D12a's per-stage build in production is site 2 (a rebuild only when the cache did not keep the witness: on this Mac
A3's default keeps all 32). Sites 7 and 8 would take the same pool by one line each; they are left for their owners.

## 2. Why the global pool costs so much system time (stage 1)

**Method** (`s1.sh`). The harness's new `HL_A15_SEAL_AB` runs the sealing pass ALONE (32 serial witness builds of the
8B chain, no forks, no proof) under each arm, and prints its wall and the process's `getrusage` over it. Arms:
- `sp0`: the global pool of 32, the build called from the harness thread (the harness before A15);
- `spg`: the global pool, the build entered on one of its workers (as production's `seal_and_record` ran it before
  A15, inside its `rayon::join`);
- `sp<t>`: a dedicated pool of `t` threads (production's new `SealPool`).

Then `HL_A15_SAMPLE`: two sealing passes per arm between handshakes with `/usr/bin/sample` (2 ms), on `sp0`, `spg` and
`sp8`. `sample_seal.py` (on A11's parser) gives every self sample a role (`main`: any stack holding the builder; a
rayon worker's other samples; other) and a state by its leaf (`yield` = `swtch_pri`; `mutex`; `wake`; `sleep`;
`run`). The raw call graphs (3–11 MB) are not committed; the summaries are `s1_sample_*.summary.txt`.

**The sealing pass alone, 4 passes, arm order reversed in odd passes** [MEASURED, `s1_alone_table.md`]:

| arm | wall s | user CPU s | sys CPU s | cores busy | involuntary csw | wall vs `sp0`, bias out |
|---|---:|---:|---:|---:|---:|---:|
| `sp0` global, from the harness thread | 4.024 | 14.93 | 24.94 | 9.9 | 627,768 | — |
| `spg` global, entered on a worker | 3.936 | 14.71 | 23.85 | 9.8 | 612,471 | −2.1% |
| `sp32` own pool of 32 | 3.839 | 13.71 | 25.73 | 10.3 | 575,901 | −4.5% |
| `sp16` | 3.147 | 9.40 | 7.18 | 5.3 | 174,901 | −21.8% |
| `sp12` | 3.050 | 8.28 | 4.44 | 4.2 | 96,762 | −24.2% |
| **`sp8`** | **2.943** | **7.12** | **2.13** | 3.1 | 36,971 | **−26.8%** |
| `sp6` | 3.147 | 6.93 | 1.26 | 2.6 | 22,541 | −21.8% |
| `sp4` | 3.436 | 6.65 | 0.86 | 2.2 | 10,450 | −14.6% |
| `sp2` | 4.537 | 6.45 | 0.61 | 1.6 | 3,119 | +12.8% |
| `sp1` (the byte run, 1 pass) | 6.653 | 6.34 | 0.40 | 1.0 | 800 | +63% (against that run's `sp0`, 4.070 s) |

Minor faults are about 525,000 per pass in every arm (the witnesses' fresh pages), so they are not the difference.

**What it says.**
- **The cost follows the pool's size, not the global pool as such.** A dedicated pool of 32 costs what the global pool
  costs (26 against 25 system CPU-seconds), and entering the global pool on a worker (`spg`, no cold entry per region)
  saves only 2%. System CPU grows faster than linearly with the threads: 0.4, 0.9, 2.1, 7.2, 25.7 s at 1, 4, 8, 16, 32
  threads; so do the involuntary context switches.
- **The work itself is about 6.3 user CPU-seconds** (one thread). At 32 threads the pass burns 39 CPU-seconds to do it,
  and is slower than at 8.

**The sample says where** (two passes per arm; thread-seconds) [MEASURED, `s1_sample_*.summary.txt`]:

| | `sp0` (global, 32) | `spg` (global, 32, on a worker) | `sp8` |
|---|---:|---:|---:|
| window, 2 passes | 10.06 s | 9.86 s | 6.57 s |
| rayon workers, running | 32.5 | 28.8 | 9.9 |
| rayon workers, **yielding** (`swtch_pri` in `wait_until_cold`) | **17.3** | **14.1** | 0.5 |
| rayon workers, **blocked on rayon's sleep lock** (`__psynch_mutexwait` in `Sleep::wake_specific_thread`) | **20.8** | **21.3** | 0.2 |
| rayon workers, signalling a condition variable (`wake_specific_thread`) | 1.6 | 1.8 | 0.1 |
| the build's own line: waiting on a region it handed out | 3.19 (47%) | 1.78 (26%) | 0.17 (3%) |
| the build's own line: its own work | 2.44 | 2.68 | 3.14 |
| the build's own line: waiting on the GPU (the A4 products) | 1.13 | 1.14 | 1.08 |

- Of the rayon workers' lock waits, 97% are in `Sleep::wake_specific_thread` called from `wake_any_threads` (a worker
  that finds or pushes work wakes a sleeping one, taking that sleeper's mutex): a lock convoy among 32 threads. Of the
  yields, all are the idle loop of `WorkerThread::wait_until_cold`: rayon-core 1.13 spins 32 rounds of `yield_now`
  (`ROUNDS_UNTIL_SLEEPY`), each a steal attempt over every other worker's deque, before it sleeps.
- **So the cause is many short parallel regions on a wide pool** [INFERRED from the two tables]. Each 8B build is some
  70 to 90 parallel regions [ESTIMATE, counted from the code: 9 weight scans, 12 requantizations, the scores and the
  softmax heads, 7 product packs, and one region per limb plane in `assign`], most of them a few milliseconds of work.
  Each region's start wakes workers through the sleep lock, and its end leaves the woken workers spinning on `yield_now`
  (a system call on macOS) and on steal attempts across the pool before they sleep again. With 32 workers that is the
  pass's 25 system CPU-seconds and its 600,000 involuntary context switches; with 8 it is 2 s.
- **Not nested joins.** With `sp0` the build's line is the harness thread, not a worker, so nothing nests; `spg`, where
  regions nest, costs the same.
- **Not page faults** (the same count in every arm) and **not the GPU** (its waits are the same 1.1 s in every arm).

**A cause inside the builder?** The pool removes the system time. What remains at 8 threads is the build's own line:
in the `sp8` sample 61% of it is its own serial work (`quantized`'s read-back loop, `Geom::support` recomputed per
domain, `build`'s and `normalized`'s per-position loops, `assign`'s closures), 21% the GPU products, 13% its own
regions [MEASURED]. Coarser regions (fewer, larger `fill_planes` regions) would save at most the ~2 system and ~0.8
extra user CPU-seconds left at 8 threads, and little wall, so that was not done [INFERRED]. The serial remainder
(about 1.6 s of the 2.9 s pass) is the builder's next lever; it is a separate item in `witness_accuracy.rs` (§7).

## 3. What changed

**Production** (`private_block/trained_block.rs`, the block marked `[A15]`; nothing else in production):
- **`SealPool`**: a rayon pool for the sealing pass's witness builds, made once per size and kept for the process
  (threads `hl-seal{t}-{i}`; an idle rayon thread sleeps). `SealPool::get()` takes the size from
  `seal_pool_threads()`; `run(f)` runs one build on a thread of the pool (`install`), so every parallel region of that
  build runs on the pool's threads only. Size 0 is the global pool: `run(f)` is then `f()`, the code before A15.
- **The switch `HL_SEAL_POOL`**: unset, empty or `auto`, the default rule; `0`, the global pool (before A15); `t`, a
  pool of `t` threads (at most 1024). A pool that cannot be made is an error by name, before the run header.
- **The default rule**: a quarter of the logical CPUs, at least 1 and at most 8: 8 on this Mac (§5).
- **`seal_and_record`**: the pool is taken once at the start; each layer's build runs in it, inside the existing
  `rayon::join` whose other half (the next layer's load) stays on the global pool.
- **`StackSource::witness_of`**: a witness A3's cache did not keep is rebuilt in the same pool.
- **The `sealed` event** of `stack-prove` gains `"seal_pool_threads"` beside `"rayon_threads"`.

**Test code only:**
- `run_fork_tests.rs`, the block marked `[A15]`: the arm words `sp<t>` (`sp0` the global pool from the harness
  thread), `spauto` (the default rule) and `spg` (the global pool entered on one of its workers), joinable with every
  other word (`spauto+lazy0`); one request's sealing pass and the stream's sealing thread go through them
  (`A15Sealer`). New lines: A13's `SEALED` line (so `../a13/seal_pairs.py` reads it), `D55-AB A15 SEALED` (the
  sealing pass's own user and system CPU, context switches, faults) and `D55-AB A15 PIPE-SEAL` (each streamed
  request's sealing pass). `HL_A15_SEAL_AB`, `HL_A15_SAMPLE` and `HL_A15_ONLY` (§2).
- `trained_block.rs`: `set_seal_pool_for_test`, `set_seal_pool_auto_for_test`, `default_seal_pool_threads_for_test`
  (`#[cfg(test)]`).
- `w16r2_tests.rs`, the block marked `[A15]`: the two byte tests of §4.
- Without an arm word the harness now seals in the default pool, as production does; `sp0` is the old harness.

## 4. Why no byte can move, and the byte evidence

**The argument.** The pool decides only which threads run the builder's parallel regions and how many there are.
Every region on the builder's path is an indexed write (`par_chunks_mut`, `fill_planes`), an exact integer sum read
back in its chunks' order, or a boolean scan, and each refusal is the sequential loop's first one (H124c's rules,
`witness_accuracy.rs`). The products split their output columns by `current_num_threads()` (`tiled16`), but each word
is one exact integer sum, whatever the split. The A4 device products are exact and do not depend on the calling
thread. Nothing in the builder draws randomness or touches a transcript.

**The words, not only the argument** [MEASURED]:
- **The 8B chain, 32 blocks, every plane of every witness** (the harness's `HL_A15_SEAL_AB`, device products, one
  digest over all 32 witnesses' planes per arm; `s1_bytes.log`, `s1_alone.log`): `c0d2266503df6675` in pools of 1, 2,
  4, 6, 8, 12, 16 and 32 threads, the default (8), the global pool from the harness thread and the global pool on one
  of its workers. The chain's last output equals the setup chain's in every pass.
- **The W16R2 rung, CPU, in the suite** (`w16r2_tests::a15_the_seal_pool_rule_and_the_rung_witness_planes_in_every_pool`,
  `s1_rung.log`): a chain of three witnesses through the trained stack's builder (`witness::build_for_block`, what
  `seal_and_record` and the rebuild call) on the calling thread, in rayon pools of 1, 4, 8 and 16 threads, and in
  `SealPool` at 0, 1, 4, 8, 16 threads and the default: every plane of every witness equal, and the first witness is
  `rung_case`'s. The same test pins the size rule (1, 4, 8, 16, 32, 64, 128 CPUs give 1, 1, 2, 4, 8, 8, 8).
- **The 8B block, CPU and device products** (`w16r2_tests::a15_the_8b_witness_planes_in_every_sealing_pool`,
  ignored, run in the acceptance, `s4_a15_8b.log`): a chain of three W16R2 8B T128 witnesses through the trained
  stack's builder at all 11 places of the rung test, once with CPU products and once with the A4 device products (21
  device products per chain): every witness's digest of every plane is `5808a1cd…` at all 22.
- **A caveat on "every block".** The synthetic block reaches a fixed point at once: its output is its input, so all
  three 8B witnesses have one digest, and the harness's 32-block chain repeats one build too [INFERRED from the
  equal digests]. The pools are therefore compared on that build (with its device products) and on the rung's chain,
  not on 32 different inputs.
- **The proofs:** the W16R2 rung golden `96e4f0b6`, the six trained digests and the receipt sizes in the acceptance
  (§6), and every D55 receipt of every A/B call verified at 818,728,672 B.

## 5. The A/Bs

In-process, N = 6, `HL_D55_AB_ALTERNATE=1 HL_D55_AB_SEALED=1 HL_D55_AB_PIPE=4`: each arm and pass a proof-only fork
call (the control: it has no sealing pass), one request from its input and a 4-request stream (every stream receipt
verified after its clock; each arm's first proof-only and sealed receipt verified; every fork receipt 818,728,672 B).
"Base first" and "test first" are the passes in which that arm ran first; the bias-solved figure is their mean (the
second arm of a pass runs about 4.5% faster whichever it is, A7). (n pairs, n favouring the test.) From
`../a11/pairs.py --alternate --n 6`, `../a13/seal_pairs.py` and this directory's `seal_pairs.py`.

### 5.1 Stage 2: the size sweep (exploratory, 4 passes, 7 arms) [MEASURED, `s2_pairs_*.md`, `s2_seal*_*.md`]

The whole arm order is reversed in odd passes, so `sp0` ran first or last. Against `sp0` (the global pool from the
harness thread), bias solved out:

| arm | one request | sealing pass (one request) | sealing CPU | stream steady | stream amortized | proof only (control) |
|---|---:|---:|---:|---:|---:|---:|
| `spg` (global, on a worker: production before A15) | −0.6% | −1.2% | −2.8% | −0.0% | +0.0% | −0.1% |
| `sp4` | −5.4% (4 of 4) | −12.2% | −80.6% | +8.7% (4 of 4) | +7.8% | +0.4% |
| `sp6` | −11.3% (4 of 4) | −19.7% | −79.0% | +16.0% (4 of 4) | +14.3% | +0.8% |
| **`sp8`** | **−11.0%** (4 of 4) | **−22.0%** | **−76.0%** | **+19.2%** (4 of 4) | **+16.7%** | +0.3% |
| `sp12` | −11.3% (4 of 4) | −21.8% | −67.6% | +19.0% (4 of 4) | +15.9% | +0.7% |
| `sp16` | −9.6% (4 of 4) | −19.0% | −57.2% | +16.0% (4 of 4) | +13.8% | +0.7% |

Means: one request `sp0` 8.441 s, `sp8` 7.509 s (15.2 → 17.0 tok/s); the stream steady 24.27 → 28.93 tok/s, amortized
20.80 → 24.28 tok/s. Against `spg`, the production form before A15, `sp8` gives −10.5% and +19.3% (`s2_pairs_spg_*.md`).

**The sealing pass's own clocks, `sp8` against `sp0`** (`s2_seal_sp8.md`):
- one request's sealing pass 4.355 → 3.397 s (−22.0%): user CPU 15.8 → 7.6 s (−51.6%), system CPU 28.2 → 2.9 s
  (−89.6%), involuntary context switches −93.7%;
- in the stream, request 0's sealing pass (alone) −23.8%; requests 1 to 3, sealed beside the previous request's forks,
  5.372 → 4.590 s (−14.6%).

**The choice: 8 threads, the rule a quarter of the logical CPUs, at most 8.** 6, 8 and 12 threads are within noise of
each other on one request; 8 is best on the stream and costs 35% less sealing CPU than 12; 16 and 4 are worse. The
sealing pass alone (§2) says the same: the builder's parallel work stops paying beyond about 8 threads. On another
machine the rule is an extrapolation [ESTIMATE]: the RTX 5090 box should re-measure it with its own CPU.

**A small cost that did not repeat.** In this sweep the one request's preflight and commit phases (on the global
pool, right after the sealing pass) took 0.293 → 0.332 s with `sp8` (+13%, every pair) [MEASURED, `s2_seal13_sp8.md`],
as if the global pool's threads started that phase asleep. Stage 3 found −0.1% (§5.2), so it is noise or at most
0.04 s of a 0.9 s gain.

### 5.2 Stage 3: the default against the global pool, 6 passes [MEASURED, `s3_pairs_default.md`, `s3_seal*_default.md`]

`sp0` (the global pool from the harness thread, the harness before A15) against `spauto` (the default: 8 threads).

| metric | base first | test first | order bias solved out | means, global / sealing pool |
|---|---|---|---|---|
| **one request from its input** | −13.2% (3, 3) | −12.3% (3, 3) | **−12.7%** | 8.419 / 7.346 s = 15.20 / 17.43 tok/s |
| its sealing pass | −23.8% (3, 3) | −23.4% (3, 3) | **−23.6%** | 4.368 / 3.336 s |
| its sealing pass's user CPU | −51.6% (3, 3) | −51.6% (3, 3) | **−51.6%** | 15.70 / 7.60 s |
| its sealing pass's system CPU | −90.0% (3, 3) | −90.0% (3, 3) | **−90.0%** | 28.71 / 2.88 s |
| its prove call (preflight to last byte) | −1.7% (3, 3) | −0.3% (3, 2) | −1.0% | 4.051 / 4.009 s |
| **the 4-request stream, steady** | +19.7% (3, 3) | +18.1% (3, 3) | **+18.9%** | 24.41 / 29.02 tok/s |
| **the 4-request stream, amortized** | +18.0% (3, 3) | +17.0% (3, 3) | **+17.5%** | 20.80 / 24.44 tok/s |
| the stream's sealing passes beside the forks (requests 1–3) | −16.1% (3, 3) | −15.5% (3, 3) | **−15.8%** | 5.382 / 4.530 s |
| proof only (the control) | +0.9% (3, 1) | +0.7% (3, 1) | +0.8% | 4.029 / 4.061 s |
| proof only, user / system CPU | | | +0.4% / +3.8% | 41.1 / 41.2 s; 6.95 / 7.20 s |

- **One request and the stream favour the sealing pool in every pair, in both orders.** The proof-only call, which has
  no sealing pass, moves +0.8% (1 of 3 pairs each way): noise, as it should be.
- Bests: one request 8.255 → 7.191 s (15.51 → 17.80 tok/s); the stream steady 24.92 → 29.86 tok/s.
- Per-request latency inside the stream (requests 1–3): 9.25–10.14 s with the global pool, 8.36–9.07 s with the
  sealing pool; the first request 8.64–9.11 / 7.52–7.90 s (`s3_default_d55_ab.log`'s PIPE lines).
- Against A13's probe (sp8, 2 passes): one request −11.5%, the stream +19.6% steady. This repeat agrees.
- The sweep's +13% on one request's preflight and commit (§5.1) did not repeat here (−0.1%).

### 5.3 Stage 3: A14's lazy sums on top of the sealing pool (the coordinator's check), 6 passes [MEASURED, `s3_pairs_lazy.md`, `s3_seal*_lazy.md`]

The coordinator's repeat of A14 (`../a14merge_pairs.md`, without the sealing pool) found the lazy sums −2.8% on proof
only but the stream steady −1.8% with 0 of 4 pairs favouring them, and asked whether the stream was sealing-bound.
Here the base is the default (`spauto`, lazy sums on) and the test `spauto+lazy0` (A14's per-term sums). The table
is the lazy sums' own change (the default against `lazy0`), so a minus on a time and a plus on a rate favour them:

| metric | `lazy0` first | lazy sums first | order bias solved out | means, `lazy0` / lazy sums |
|---|---|---|---|---|
| proof only | +0.6% (3, 2 of 3 favour lazy) | +0.2% (3, 1) | +0.4% | 4.089 / 4.107 s |
| one request from its input | −0.9% (3, 3) | −0.9% (3, 3) | **−0.9%** | 7.491 / 7.425 s |
| the stream, steady | −0.5% (3, 1) | +1.8% (3, 2) | **+0.6%** | 28.91 / 29.10 tok/s |
| the stream, amortized | +0.1% (3, 3) | +0.7% (3, 2) | **+0.4%** | 24.24 / 24.34 tok/s |
| user CPU (proof-only call) | −2.2% (3, 3) | −3.1% (3, 3) | **−2.6%** | 42.53 / 41.42 s |

(Each cell is the inverse of `s3_pairs_lazy.md`'s, whose base is `spauto`; the pair counts are the same pairs.)

- **On top of the sealing pool the lazy sums no longer lose the stream:** +0.6% steady (3 of 6 pairs) and +0.4%
  amortized (5 of 6), within noise. One request favours them in every pair (−0.9%), and they take 2.6% of the user CPU
  off in every pair.
- **Their proof-only gain did not show in this run** (+0.4%, 3 of 6 pairs; A14 −3.9%, the coordinator's repeat
  −2.8%). The sealing pass itself does not depend on them (its sealing pass +0.8%, its CPU +0.6%: noise).
- So the stream's earlier loss is consistent with a sealing-bound stream [INFERRED]: with the 32-thread pool, the next
  request's sealing pass competed with the forks for the CPU and set the pace; with the pool it no longer does, and
  the lazy sums are neutral to slightly positive there. The recommendation is to keep them on.

## 6. Acceptance [MEASURED]

**Stage 4** (`s4.sh`, `s4.progress`, `s4_*.log`, `s4.guard.json`) is the final tree: perf `345f257a` (A14 merged, the
XOF default blake3) with A15, the sealing pool the default; `check_a14merge.sh`'s commands pointed at this worktree,
plus A15's tests. One guarded job (20:53–21:01 UTC), on the same build as stage 3's A/Bs:
- **build:** rc 0. **The no-feature `cargo check --tests`:** rc 0.
- **The full lib suite** (`--test-threads=8`, the R13 loader fixtures; `s4_full.log`): **926 passed, 3 failed, 107
  ignored**. The three failures are exactly the known ones:
  - `review_tests::a_toy_receipt_made_before_f12_is_refused`;
  - `trained_block::accuracy::profile_tests::accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`;
  - `trained_stack_tests::review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`.
  - 926 is A14's 925 plus `a15_the_seal_pool_rule_and_the_rung_witness_planes_in_every_pool`; 107 ignored is A14's 106
    plus `a15_the_8b_witness_planes_in_every_sealing_pool`. The trained-stack CLI tests (which run `seal_and_record`
    and, with `--witness-cache-gib 0`, the rebuild) pass in the sealing pool.
- **zkp-core's lib tests:** 81 passed, 2 ignored.
- **A15's 8B byte test** (CPU and device products, 22 places): every plane equal (§4).
- **A14's byte tests:** the 8B private tables under both sums (56 tables, 8.56 M words equal); the rung golden
  `96e4f0b6` on the CPU under three settings and on Metal under six; the 8B block's core proof under every setting,
  twice each, one digest (`a32cb0dd0fc2ec46`).
- **The A8 rung test** (every store fold form), **the A12 census and rung-mode tests, the A11 pool tests (CPU and
  Metal), the A7 queue test:** all pass, `96e4f0b6` throughout.
- **The W16R2 rung golden** (`HL_GPU_REQUIRED=1`): CPU = Metal = `96e4f0b6f34f7876…`.
- **The six post-F12 trained digests** (`HL_GPU_REQUIRED=1`): 5a6193d3, f590b01f, 79f987ef, a8258241, 0e88d84f and
  90003b76 are all present.
- **The D55 harness on the default** (`s4_d55.log`; `HL_D55_WORKERS=6 HL_D55_PASSES=2 HL_D55_SEALED=1
  HL_D55_PIPE=4`; the sealing pass in a pool of 8):

| W16R2 8B T128, 32 blocks, N = 6 | this run (`s4_d55.log`) | A14's merged tree (`../a14merge_d55.log`), for reference |
|---|---:|---:|
| proof only, the two calls | 4.061, 4.044 s | — |
| proof only, best | 31.65 tok/s | 32.15 |
| one request from its input, the two calls | 7.213, 7.205 s (sealing passes 3.160, 3.226 s) | |
| one request from its input, best | **7.205 s = 17.76 tok/s** | 15.49 |
| stream of 4, steady / amortized | **28.60 / 24.49 tok/s** | 24.29 steady |
| per-request latency in the stream | 7.48, 8.65, 8.91, 8.74 s | |
| the stream's sealing passes | 3.28 s alone; 4.42, 4.47, 4.79 s beside the forks | |
| serial D12a, best | 9.574 s = 13.37 tok/s | |

- **Receipts:** every receipt the harness verifies verified (the D12a verifier on the first serial pass, the D55
  verifier on the first proof-only and sealed passes, all 4 stream receipts after the clock). Fork receipts
  818,728,672 B and D12a receipts 818,728,480 B, unchanged (and in every call of every A/B of stages 2 and 3).
- The A14 column is another process on another state of the box; the in-process A/Bs of §5 are the measurement.

## 7. What is left

- **The builder's serial remainder.** At 8 threads the sealing pass is about 2.9 s alone, and the build's own line is
  about 1.6 s of it [INFERRED from the `sp8` sample's main-line shares]: `quantized`'s serial read-back of its parallel
  chunks, `Geom::support` recomputed for each domain (in `build`, `residual` and `assign`), `build`'s per-position loops
  (the ungated exp lookup over every score position, `a_scaled`, the products `hacc`) and `normalized`. Each has a
  byte-identical parallel or cached form; they are in `witness_accuracy.rs` (privacy-pinned), so a separate item.
- **Production checks each block's public data twice.** `witness::build_for_block` runs `check_accuracy_for_shape`
  (the registry check and the scan of the block's int8 weights, about 220–240 MB) and then `build_accuracy` runs both
  again [from the code]. About 9 parallel regions and one scan per block; small at 8 threads, and the harness (which
  calls `build_accuracy`) does not see it.
- **The stream is now balanced** [INFERRED]: its steady period is about 4.4 s per request (28.9 tok/s), the sealing
  pass beside the forks 4.6 s, the proof-only fork run 4.1 s. A further stream gain needs both the sealing pass and
  the forks faster.
- **Sites 7 and 8** (the MVP driver's and the token CLI's sealing passes and per-stage builds) have the same shape and
  could take the same pool; they are not on the D55 path.
- **The verifier's fork threads** still share the global pool (A11's note).
- **Not measured:** a trained 8B export's own sealing pass (no trained 8B export is on the Mac; the harness's sealing
  pass is its model, A3's caveat), and the rule on any machine but this one (the RTX 5090 box should re-measure it).

## 8. Files

- `ops/zkp-mvp/gpu-metal/hashline/src/private_block/trained_block.rs` (production): `[A15]` `SealPool`,
  `seal_pool_threads` (`HL_SEAL_POOL`), `default_seal_pool_threads`; the pool in `seal_and_record` and in
  `StackSource::witness_of`; `SealTimes::pool_threads` and the `sealed` event's `seal_pool_threads`; test-only
  `set_seal_pool_for_test`, `set_seal_pool_auto_for_test`, `default_seal_pool_threads_for_test`.
- Tests: `run_fork_tests.rs` (the `[A15]` block: `A15Seal`, `a15_word`, `a15_apply`, `A15Sealer`, `a15_digest`,
  `a15_sealed_report`; the arm field and its hooks in `GpuArm`, `gpu_arm` and the A/B loop; the sealing pass of
  `forked_sealed` and `piped` through `A15Sealer`; the `HL_A15_*` stage before the cold serial call); `w16r2_tests.rs`
  (the `[A15]` block at the end: `A15At`, `a15_chain`, `a15_witness_digest`, `a15_chain_digests`, `a15_every_place`,
  the rung test in the suite and the ignored 8B test).
- No new module, so no census list changes: s25's `TEST_ONLY_FILES` and the module graph are untouched.
- This directory: `s1.sh` (measure first), `s2.sh` (the sweep), `s3.sh` (the A/Bs of the default), `s4.sh` (the
  acceptance), their progress files, guard records and trimmed logs; `sample_seal.py` (on A11's parser), `seal_pairs.py`,
  `alone_table.py`; `run_stage.py` and `watch.py` (A11's); the tables `s1_alone_table.md`, `s2_pairs_*.md`,
  `s2_seal*_*.md`, `s3_pairs_*.md`, `s3_seal*_*.md` (regenerated from the committed logs by `tables.py`); the sample
  summaries `s1_sample_*.summary.txt`; the D55 logs `s1_bytes.log`, `s1_alone.log`, `s1_sample.log`, `s2_d55_ab.log`,
  `s3_default_d55_ab.log`, `s3_lazy_d55_ab.log`, `s4_d55.log` and the suite log `s4_full.log` (each under 150 KB). The
  raw sample call graphs (3–11 MB) stay in `raw/`, not committed.

**For the privacy gate.**
- **The one production digest that moved: `private_block/trained_block.rs`**, a source pin of the run capture (it was
  pinned in R5b as the trained loader and CLI bridge). `witness.rs`, `witness_accuracy.rs`, `protocol.rs`,
  `argument.rs`, `run_fork.rs`, `private_block.rs`, `gpu/metal.rs`, `gpu/mod.rs`, `metal_kernels.metal` and zkp-core
  are unchanged by A15.
- The new code reads no value: the pool decides only which threads run the same build. It keeps nothing, prints only
  the pool's size, and adds no dependency.
- **Timing:** no path whose running time depends on a hidden value is added; the pool's size is a public process
  setting. (A8's small-word fold remains the one known value-dependent path.)
- `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.
