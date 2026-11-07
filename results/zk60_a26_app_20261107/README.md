# A26: the media app's CPU work per proof, cut without moving a receipt byte (2026-11-07)

Lane A26. Goal (Victor, 2026-11-07, away for the weekend): "Focus on implementing the new optimizations into
the proof of concept media app. It would be nice to get the media app speed up to 30 or so tokens per second
for the proofs." A24 left the app at 11.4 proved tok/s; A25 found the W16R2 lever needs a design and a
ruling. This lane's brief: cut the CPU work per category proof and per verification **without changing the
protocol, a receipt byte, a statement byte, a verdict or a refusal message**.

**Labels:** [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers;
[CODE] read from the source.

**Metric** (MVP_STATUS's): proved tok/s = 128 x (category proofs completed) / wall seconds; every receipt
counted was freshly verified (the verifier server, its own process). Public text only.

**Machine:** the M3 Ultra Mac (24 performance + 8 efficiency cores, 80-core GPU), shared with four Lean
lanes. Every heavy run went through the resource guard at its default floors, with no `ds4-bench` running
(`*.quiet` files); the guard serializes heavy jobs, so no other heavy job ran beside a measurement.

## 0. Plain summary

- **The stream of 8 public posts: 11.25 → 14.10 proved tok/s (+25%)**, every receipt freshly verified, A/B
  pairs in both orders on the native servers (section 3.1). **One post: 55.2 → 46.7 s (6.96 → 8.23 tok/s,
  +18%)** (section 3.2). **Through the app** (single runs, against A24's app run): an 8-post stream 11.4 →
  **13.8 proved tok/s**, one post 70.0 → **54.4 s (7.1 tok/s)**, one long post 174.5 → 136.9 s (section 3.4).
  With verification on another machine the proof-only clock is **15.5 tok/s** (from 12.4; section 3.3).
- **The CPU work per category proof fell by a third: 184.6 → 123.8 CPU-s** (the prover −35%, the verifier
  −29%) [MEASURED].
- **The receipts did not change, byte for byte.** A new fixed-entropy harness for the Mac (A24 could not run
  one) shows A24's binary and A26's make identical receipts on the real Shieldstral export, every file of every
  category, and each verifier accepts the other's receipts (section 4). Same statement identity `e4f97455…`,
  same run profile, same verdicts and refusal messages.
- **The single biggest item: 37% of the prover's CPU was one product.** R13 LOW+h24's FFN down projection
  reads a 24-bit activation, which A4's int16 GPU kernel declines, so it ran on the CPU for every block of every
  proof. It now runs on the GPU as two exact int16 halves. The verifier's column test now sums only over each
  weight's nonzero rows, and its public tables use split eq tables.
- **30 proved tok/s is not reached: the stream is now GPU-bound** (Device Utilization 83% on average, 96%
  median, with half the CPU idle). What is left needs less GPU work per proof: W16R2-style rows (A25's design
  question and a ruling by Victor), faster device sumcheck kernels, or a second GPU (section 7).
- **The app's `shieldstral-fast` mode now pins the A26 binary** (`b6336628…`) and one Metal queue per prover
  thread; 217 app tests OK. Still a development candidate: "privacy statement pending", `production: false`.
- **Two further cuts are in the binary but OFF**, for the security owner's reading of D72 / D74: the prover's
  kept digest and startup check, and a verifier that checks and re-hashes each block once per verification
  instead of twice (−20% verifier CPU) (section 6).

## 1. The profile: where the time went (A24's binary)

**How it was measured.** `stream_driver.py` (A25's, plus: each server's CPU seconds over the clocked window
from `ps -o time=`, the writer's CPU from `RUSAGE_CHILDREN`, the GPU's `Device Utilization %` from `ioreg`
every 2 s, and macOS `sample` attached to both servers for 60 s from 90 s after the first post). A24's
8-post public stream at the app's settings (6 prover lanes x 5 threads, 3 verifier lanes x 4, 16 GiB
witness cache). `sample_profile.py` folds the call graphs: self time by function (with each rayon
helper's own instance and its nearest named caller), inclusive time, and the blocked / spinning / running
split. Raw samples are outside the repository (`~/zk60-artifacts/a26-tools/samples/`); the text profiles
are `stream_<tag>/profile_{prover,checker}.txt`, the GPU waits by caller `stream_<tag>/gpu_waits_by_caller.txt`
and each request's critical path `stream_<tag>/lane_tree_prove_with_public.txt`.

**CPU per category proof** [MEASURED, `stream_p1s8` (sampled) and `stream_p2a24` (not)]:

| | p1s8 | p2a24 |
|---|---:|---:|
| prover server | 139.5 CPU-s | 143.6 CPU-s |
| verifier server | 35.8 | 36.0 |
| activation writer (Python) | 6.8 | 6.8 |
| **all** | **182.2** | **186.4** |
| cores busy on average over the clock | 15.2 of 32 | 15.9 of 32 |
| GPU Device Utilization, mean / median | — | 72% / 93% |
| proved tok/s | 10.69 | 10.90 |

So A24's "about 300 core-seconds per proof, CPU-bound" was an inference from `top`: measured, it is about
185 CPU-s, and the stream used half the cores [MEASURED]. What bounded it was each lane's own critical
path and, under it, the GPU.

**The prover's CPU** [MEASURED, `stream_p1s8/profile_prover.txt`, self time of the running samples]:

| share | where | what |
|---:|---|---|
| **37%** | `witness::matmul_in_out` (the sealing pass's witness builder) | **the FFN down projection on the CPU.** At R13 LOW+h24 its input is the 24-bit FFN product; A4's int16 device kernel declines any activation outside i16, so this one product (128 x 16384 x 4096, padded) ran on the CPU in i64 lanes, every block, every proof |
| 12% | `gpu::metal::wait_done` | spinning on a command buffer's status (M5d's default wait) |
| 6.5% | BLAKE3 tree (`BlockPublic::a21_digest_tree`) | CS-6: each block re-hashed twice per proof |
| 6.3% | `fold_segments_a8_opts` (CPU half) | the openings' store folds |
| 5% | `weights_vanish_off_support` | CS-1 / CS-4: each block checked five times per proof |
| 3.5% | `lookup_values_at` | the lookup columns |
| 3.1% | `accuracy_fold::fold` | the public weight folds (challenge-dependent) |
| 2.7% | BLAKE3 XOF (`ZkRng`) | the proof's own randomness |
| 2.8% | `helper_one`, `write_helpers_u8` | the LogUp helpers |

**Each request's critical path** (the lane thread's own stack) [MEASURED, `stream_p1s8/lane_tree_prove_with_public.txt`]:
the sealing pass 30% of the request (the CPU down projection alone 21%), the run 68%; in the run, 35% of
the request was waiting for the GPU (`wait_done`), most of it in the device sumcheck slots.

**The verifier's CPU** [MEASURED, `stream_p1s8/profile_checker.txt`]:

| share | where | what |
|---:|---|---|
| 20% | BLAKE3 tree | CS-6: each block re-hashed twice per verification |
| 18% | `verify_core` (inlined `pcs::verify_zk_tagged`) | the column test: each opened column combined with every group's row weights over EVERY row, though a group's weights are zero off its claims' rows |
| 12% | `NttTables::transform` | the group vectors' encodings (inherent) |
| 11% | `weights_vanish_off_support` | CS-1 / CS-4: each block checked three times per verification |
| 14% | `accuracy_fold::fold` | the weight folds (inherent, challenge-dependent) |
| ~10% | `argument_with` helpers | each slot's public tables at its final point: a full eq table per table |
| 4% | `stage_in_c::challenges` | the embedding fold, one Fp2 product per word |

**The questions of the brief, answered** [CODE + MEASURED]:
- *Is the 809 MB receipt read, hashed or decoded more than once?* Read once (`door_statement`), decoded once,
  not hashed by the verifier (the app hashes it again in Python, `ClassifierCLI.collect_verified`; about 1%
  of the CPU).
- *Are Merkle paths, encodings or table derivations recomputed?* The paths are checked once. The verifier's
  column test summed over every row for every group (fixed, change 2). Each slot rebuilt a full eq table per
  public table (fixed, change 3). The blocks are re-hashed (CS-6) twice and re-checked (CS-1/CS-4) three times
  per verification, and twice / five times per proof (prover: partly fixed, change 5; the rest waits for a
  reading, section 6).
- *Are the 26 blocks verified one after another?* Yes, on one transcript. In the stream it does not matter:
  three verifier lanes run side by side and the verifier is not the limit.
- *Per-request work that is really per-model?* The block digests and checks (above), and the embedding table's
  digest (805 MB, hashed about three times per request on each side; about 3% of a request's critical path
  and 5% of the verifier: not changed, section 6).

## 2. What changed

Every change computes the same words or field elements as the code before it, and each has a switch that
restores that code (`0`), read once per process. [CODE; tests in section 5.]

**Native, on by default:**
1. **The out-of-i16 witness product on the device** (`witness.rs`: `on_device_split`, `HL_A26_SPLIT`). An
   activation outside i16 but inside i32 splits as `x = 2^16 hi + lo` with `lo = ((x + 2^15) mod 2^16) -
   2^15` and `hi = (x - lo) / 2^16`, both i16; A4's device product is exact for i16 times int8 (its bound,
   `gpu/metal.rs`), so `2^16 (W hi) + W lo = W x` exactly, in i64. For the (input, output) layout the
   trailing input columns that every row reads as zero (the padded hidden width, 16384 against 9216) are not
   sent. A word whose upper half leaves i16 (only `x >= 2^31 - 2^15`) is declined by A4's own pack check and the
   CPU path runs as before. This is the change that matters: 37% of the prover's CPU.
2. **The verifier's column test over each weight's nonzero rows** (`zkp-core/src/pcs.rs`:
   `verify_zk_tagged`, `a26_supports` / `a26_combine`, `HL_A26_PCS_SPARSE`). A group's row weights are zero
   off its claims' rows (`zpart_weights`); their nonzero rows are listed once per opening and every opened
   column is combined over them only. A weight more than half nonzero (the proximity one) keeps the full loop.
   `0 x = 0` and field addition is exact: the same sums, comparisons, verdict and message.
3. **The slots' public tables through split eq tables** (`zkp-core/src/mle.rs`: `SplitEq`;
   `argument.rs`'s verify arm, `HL_A26_MLE`). `eq(r, x) = eq(r_hi, hi) eq(r_lo, lo)`, so a table's MLE at the
   slot's final point is `sum_hi eq_hi * sum_lo v eq_lo`: two half tables per slot instead of a full `2^n` eq
   table per public table. The same field element as `eval_mle_ext`.
4. **The embedding fold in split 32-bit limbs** (`token_io/classify.rs`: `emb_fold`, `HL_A26_EMB`): each eq
   word `c = 2^32 c_hi + c_lo`, a row's sums `sum w c_hi`, `sum w c_lo` exact in i64 (`|w c_x| < 2^47`, fewer
   than 2^16 words), recombined in i128 and reduced once; the field fold is that integer mod p. Both sides.
5. **The run's CS-1 / CS-4 record for the core proof** (`token_io/classify_run.rs`: `stage_block_kept`,
   `HL_A26_RUN_RECORD`). The run's stage check of block `k` is made with A17's `CheckedPublic::check` (the same
   check, the same refusal string) and handed to `prove_core_with` as `CoreHints`, which already honours such
   a record only for that very object at an equal shape: `prove_core`'s own re-check and `define`'s seven
   per-slot registry re-checks (A18) are not repeated. The prover still checks every block before its
   stage, as before.
6. **The resident servers' blocks as `run::fork::KeptBlock`** (`classify_serve.rs`): each block moved where it
   lives for the server's life, its digest computed there and compared with the digest pass's record exactly
   as before (the startup refusal unchanged), plus its CS-1 / CS-4 pass at its own stage shape. Nothing reads
   the records unless `HL_A26_KEPT=1` (below); the verifier never does.

**Native, off by default (each waits for the security owner's reading; section 6):**
- `HL_A26_KEPT=1`: the prover's CS-6 compares the digest kept with the resident block and its CS-1 / CS-4 takes
  the startup pass at an equal shape (D72's and D74's four conditions, which `KeptBlock` was written for; D72/D74
  were read for `stack-serve` and the D55 preflight, not for `classify-serve`). A wrong kept digest is refused by
  CS-6's name (tested).
- `HL_A26_VERIFY_ONCE=1`: over a resident source only (`TokenBlocks::resident`, a borrowed slice that outlives
  the call), the verifier's stage loop does not repeat the pre-header pass's CS-1 / CS-4 / CS-6 on the very
  object that pass checked and hashed in the same call. Every block is still checked and re-hashed once per
  verification, before the header.

**Device setting (env only, A7's existing opt-in):** `HL_METAL_QUEUES=thread`, one Metal command queue per
prover thread, so the six lanes' command buffers can run side by side on the now-saturated GPU.

**What did not change.** No receipt, statement, transcript, profile, verifier verdict or refusal message
(section 4). No edit to `protocol.rs`, `run_fork.rs`, `trained_block.rs` or `src/manifest.rs`. The edits
outside `token_io/` are: `witness.rs` (the split, additive), `argument.rs` (the verify arm's public-table
evaluation: 3 lines plus the switch), `zkp-core/src/pcs.rs` (the column loop of `verify_zk_tagged`: 2 lines
plus two helpers and a switch) and `zkp-core/src/mle.rs` (the new `SplitEq`); the A4 test
`a4_activations_outside_i16_stay_on_the_cpu` (`witness_speed_tests.rs`) now expects the two device halves.
The prover's generator construction stays in `prove_classify_run_with` (s25's census), which gained one
argument, `kept`.

**App (`apps/proven-media/`):** `shieldstral_fast_runtime.py` pins the A26 binary (`zk60_classify.a26`, its
SHA-256), `LANE = 'A26'`, the new description, and `NATIVE_SETTINGS = {'HL_METAL_QUEUES': 'thread'}` passed to
both servers; the statement identity, run profile, privacy status ("privacy statement pending") and
`production: False` are A24's. `deploy.json`'s `shieldstral-mac-fast` profile records the pin and the native
settings (validated against the runtime, `hardware_profiles.py`). The record strings name the lane from the
runtime. One new app test.

## 3. Numbers

**What is on the clock** (A24's definitions, unchanged): the native rows start at the first post and stop when
the last post's third category label is accepted; on them the activation writer, the sealing pass, the
proof, the receipt write (every segment fsync'd), fresh verification in the separate verifier process, the
input-owner check and the label. Server startup (about 35 s per server) is off the clock. The app rows add
tokenization and screening, the queue, the app's re-checks and publication (section 3.4).

### 3.1 The stream, A/B pairs in both orders [MEASURED, `m1.progress`, `stream_m1*`]

A24 as shipped (A24's pinned binary `ccd58102…`, A24's settings) against A26 as shipped (`b6336628…`, the same
6 x 5 prover and 3 x 4 verifier lanes and 16 GiB witness cache, plus `HL_METAL_QUEUES=thread`), A24's 8-post
public stream (137 content tokens, 24 category proofs), order A B B A, one guarded job, no `ds4-bench`:

| run | binary | wall | proved tok/s | second half | first post's latency | CPU-s per proof: prover / verifier / writer / all | cores busy | GPU utilization mean / median |
|---|---|---:|---:|---:|---:|---|---:|---|
| m1a1 | A24 | 274.1 s | 11.21 | 13.08 | 78 s | 142.9 / 35.4 / 6.7 / 185.0 | 16.2 | 74% / 93% |
| m1b1 | A26 | 217.5 s | **14.13** | 16.97 | 64 s | 91.9 / 25.0 / 6.7 / 123.6 | 13.6 | 83% / 96% |
| m1b2 | A26 | 218.5 s | **14.06** | 16.62 | 61 s | 92.3 / 24.9 / 6.8 / 124.0 | 13.6 | 84% / 96% |
| m1a2 | A24 | 272.5 s | 11.28 | 13.09 | 79 s | 142.3 / 35.1 / 6.8 / 184.2 | 16.2 | 75% / 94% |

- **The stream: 11.25 → 14.10 proved tok/s, +25.3%** (each A26 run faster than each A24 run: +24.6% to +26.0%).
- **CPU work per category proof: 184.6 → 123.8 CPU-s, −33%**; the prover −35% (142.6 → 92.1), the verifier
  −29% (35.3 → 25.0).
- One category proof every 9.08 s instead of 11.39 s; the GPU now 83–84% busy on average (96% median).
- All 24 proofs of every run freshly verified, owner-checked and labelled ("checked", `records.json`).

**The diagnostic single runs** (`p1`, `p2`, single runs, the `p1s8`, `p1b1` and `p2b2` runs with `sample`
attached for 60 s): A24 10.69–10.90; b1 (the verifier's two changes only) 11.06; b2 (all code changes, the
shared queue) 13.33; b2 with per-thread queues 14.32; b2 with `HL_A26_KEPT` and `HL_A26_VERIFY_ONCE` 13.69 (CPU
113.5 per proof, the verifier 19.9); b2 with 8 lanes of 4 threads 13.95. So of the +25%, the code changes give
about +20% and the per-thread queues about +7% [INFERRED from single runs; the pairs above are the combined
figure].

### 3.2 One post, A/B pairs in both orders [MEASURED, `m2.progress`, `stream_m2o*`]

A24's one-post setting (3 prover lanes x 10 threads, 3 verifier lanes x 4), one public post of 14 tokens,
its three category proofs at once, order A B B A:

| run | binary | wall (= the post's latency) | proved tok/s | writer | the three proofs at once | the three checks at once (verify) | CPU-s per proof, all |
|---|---|---:|---:|---:|---:|---:|---:|
| m2o1a | A24 | 55.4 s | 6.93 | 10.0 s | 34.4–35.2 s | 10.1–10.2 s (9.40–9.44) | 169.5 |
| m2o1b | A26 | 46.7 s | **8.22** | 9.9 s | 28.6–28.7 s | 8.0–8.1 s (7.39–7.42) | 120.6 |
| m2o2b | A26 | 46.6 s | **8.24** | 10.3 s | 28.0–28.2 s | 8.1–8.2 s (7.43–7.53) | 121.3 |
| m2o2a | A24 | 54.9 s | 6.99 | 9.9 s | 34.4–34.9 s | 10.0–10.1 s (9.31–9.41) | 172.7 |

- **One post: 55.2 → 46.7 s, 6.96 → 8.23 proved tok/s, +18%** (every pair). The proofs −19%, the checks −20%;
  the Python activation writer (10 s, a fifth of the post) is unchanged.
- One post is not GPU-bound (GPU utilization mean 42–47%): its time is the three proofs' own critical path.

### 3.3 Proof only, and verification on another machine [MEASURED, `stream_m2d8*`, single runs, B then A]

The 8-post stream with the verifier server started only after the last proof is written (standing for
verification on another machine); every receipt is then freshly verified, owner-checked and labelled on its own
clock (the verifier's 32 s startup excluded):

| run | binary | proof-only wall | **proof-only proved tok/s** | then: verifying all 24 (3 x 4 threads) | verified tok/s |
|---|---|---:|---:|---:|---:|
| m2d8b | A26 | 198.4 s | **15.49** | 65.5 s | 46.9 |
| m2d8a | A24 | 247.3 s | 12.42 | 82.1 s | 37.4 |

- **Proof only: 12.42 → 15.49 proved tok/s (+25%)**; the verifier alone, with 12 threads: +25%.
- With the verifier on its own machine, this Mac's stream is the proof-only figure, 15.5 tok/s; the verifier
  needs no GPU and about 25 CPU-s per category, so one 12-thread verifier keeps up with three such provers.

### 3.4 Through the app [MEASURED, `app_a1/summary.json`, `app_a1.out`; single run]

The real app in process (`app_driver.py`: A25's driver with `--binary`), `PM_PROVER=shieldstral-fast` with the
A26 pin, A24's three phases on one warm service (one guarded gpu-class job: both servers, the writers). Against
A24's own app run (`results/zk60_a24_app_20261107/app_a2`, measured on 2026-11-07 earlier, a single run, not a
pair: the A26 app cannot run A24's binary, whose pin it refuses):

| phase | posts | category proofs | A24 app (A24 README) | **A26 app** | change |
|---|---:|---:|---:|---:|---:|
| one short public post | 1 | 3 | 70.0 s, 5.49 tok/s | **54.4 s, 7.06 tok/s** | −22% latency |
| one long public post (3 chunks per category) | 1 | 9 | 174.5 s, 6.60 tok/s | **136.9 s, 8.41 tok/s** | −22% |
| a stream: 8 short public posts at once | 8 | 24 | 269.3 s, 11.41 tok/s (second half 15.4) | **222.2 s, 13.83 tok/s** (second half 22.6) | +21% |

- All 10 posts published (36 category jobs, 36 accepted, 0 failed); every label "no", `bound_by_proof: true`;
  every record `shieldstral-fast`, "privacy statement pending", `production: false`, run profile `/2`; each
  post's signed manifest (3 or 9 entries). The service's heartbeat names the binary `b6336628…`.
- The service (one guarded job) waited 1,566 s for the heavy lock behind this lane's own measurement job and the
  Lean lanes, ran 448 s, peaked at 101.0 GiB RSS and 48.3 GB of GPU memory, and stopped cleanly; no other heavy
  job ran beside it (the guard's history), no `ds4-bench`.
- The "second half" column is the last four posts of one closed batch (they compete with no new work); the
  amortized column is the honest stream figure, as in A24's README.

## 4. Byte preservation

**A fixed-entropy harness for the Mac** (`fixed_entropy.c`, `fixed_entropy_selftest.py`, `byteid.py`, `bi.sh`).
A24 could not run the fixed-entropy byte comparison: `r18/tools/run_fixed.sh` needs bubblewrap. Here a 30-line
interposer, loaded with `DYLD_INSERT_LIBRARIES` into the prover server only, answers every `open("/dev/urandom")`
with a descriptor on one fixed public 64-byte file, so every `ZkRng::from_os` draws the same public bytes
(the self-test checks the interposition and its absence). TEST ONLY, PUBLIC CONTENT ONLY: under it the receipts
hide nothing; the dylib lives outside the repository and nothing in the app can load it. `byteid.py` runs the
activation writer once for one public post, then each binary's prover server proves the post's three
categories into its own directories; every receipt file (28 segments, the unverified statement, and the owner
decommitment compared by hash only, never printed) is SHA-256'd and compared across the runs; then each
binary's verifier server checks the other binaries' receipts (verify + input-owner + label).

**Result on the real Shieldstral export** [MEASURED, `bi1.progress`, `byteid_bi1/summary.json`]:
- order A (A24's pinned binary), B (the A26 candidate b2), Bk (b2 with `HL_A26_KEPT=1` and
  `HL_A26_VERIFY_ONCE=1`), A again;
- **every file of every category identical in all four runs** (30 of 30 per category, 3 categories): A
  against A is the harness's own determinism control; A against B and against Bk is the byte identity of
  the changes, the default ones and the two that are off by default;
- **all six cross-verifications accepted** (A's verifier on B's and Bk's receipts, B's on A's and Bk's,
  Bk's on A's and B's), each with input-owner and label;
- the same three categories' verification, three at once on 3 x 4 threads [MEASURED, per category]:
  A24's verifier 9.28–9.41 s, b2's 7.19–7.50 s (−21%), b2 with verify-once 5.93–6.18 s (−35%).

**Repeated with the pinned binary** (`b6336628…`, built from the final tree in the measurement job itself)
[MEASURED, `bi2.progress`, `byteid_bi2/summary.json`]: the same order A, B, Bk, A; again every file of every
category identical in all four runs (30 of 30, 3 categories), all six cross-verifications accepted; one
category's verification, three at once: A24's 9.20–9.33 s, A26's 7.15–7.44 s, A26 with verify-once
6.06–6.25 s.

**Other byte evidence** [MEASURED, `accept_t*.progress`]: the L9 and L11 test-only exports regenerate their
committed corpora byte for byte (W16R2 rung receipts and their replayed challenges); every
`token_io::classify` test, every A24 serve test and the census tests pass; the unchanged CLI paths run the
old functions (`HL_A26_*=0` restores each form in the same binary).

**Verdicts and refusals.** The verifier changes compute the same field elements before every comparison, so
each check passes or fails as before with the same message [CODE]. Tested: the sparse column combination
equals the full loop at zero, `p - 1` and dense weights (`a26_sparse_column_combination_equals_the_full_loop`);
`SplitEq` equals `eval_mle_ext` at arities 0..17 (`a26_split_eq_evaluation_equals_eval_mle_ext`); the split
embedding fold equals the field fold with `i16::MIN`, `i16::MAX`, zeros and extreme eq words
(`a26_the_split_limb_embedding_fold_equals_the_field_fold`); the device halves equal the sequential products
for 24-bit and i32 words in both layouts, and `i32::MAX` falls back to the CPU
(`a26_out_of_i16_activations_split_into_two_exact_device_halves`); a tampered receipt is refused with the same
string with verify-once on and off, and a wrong kept digest is refused by CS-6's name
(`a26_kept_records_prove_verifiable_receipts_and_a_wrong_kept_digest_is_refused_by_cs6`). A24's
negative-control tests (`a24_check_serve_refuses_every_negative_control`: tampered segment, other content,
unadmitted policy, prefix only, missing chunk, wrong model) pass on the new binary's code.

## 5. Tests

**Native** (`accept.sh`, one guarded job each; `accept_t3.progress` on the final tree) [MEASURED]:
- the release CLI builds; its SHA-256 is the app's pin, `b6336628…`;
- `a26_` (3 tests: the kept records and verify-once; the split embedding fold; the device halves) passed;
- `a4_` (5, A4's device-product tests, one updated for the halves) passed;
- `s25_tests` 20, `hash_domain` 15, `r19b` 5 passed: the census lists are unchanged (no new file; the
  generator construction stays in `prove_classify_run_with`);
- every `token_io::classify` test 84 passed (12 ignored, as before), A24's serve tests among them;
- the L9 and L11 test-only exports regenerate their committed corpora byte for byte;
- zkp-core: 83 passed (A24: 81; the two new A26 tests), and its other suites;
- `cargo check --tests` without the gpu-metal feature: clean;
- **the full hashline lib suite** (release, gpu-metal; `accept_t3_full.log`): 971 passed, 3 failed, 130 ignored.
  The three failures are exactly the A23 merge's known ones (`a_toy_receipt_made_before_f12_is_refused`,
  `accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`, a fixture absent on the Mac,
  and `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`), as in A24's and A25's runs;
- (`accept_t2` found one census failure, `the_generator_is_never_cloned_and_each_prover_constructs_exactly_one`,
  when the run's body had moved into a new function; the body went back into `prove_classify_run_with`, which
  took a `kept` argument instead; `accept_t1`'s test build failed on test-module paths, fixed.)

**App** (the coordinator's command, the `/private/tmp/zk60-astra-app-refresh-20261104-venv` python):
217 tests OK (A24's 216 and one new: the A26 pin, the servers' device settings, the two ruling switches not
set, the identity and run profile A24's) [MEASURED, `app_tests.log`].

## 6. Open issues, and what the security owner could decide

1. **`HL_A26_KEPT` (prover, off).** It applies D72 (a kept digest for CS-6) and D74 (the startup CS-1 / CS-4
   pass at an equal shape) to `classify-serve`'s resident blocks, through the very `run::fork::KeptBlock` type
   those rulings were read for (private fields, one constructor that hashes and checks the object where it
   lives, `&` only; a mismatch refused by CS-6's name, tested). D72 and D74 name `stack-serve` and the D55
   preflight, so turning it on for the classifier is the security owner's reading. Measured effect: prover
   CPU about −4% (with verify-once, `stream_p2b2k`, single run); byte-identical (bi1).
2. **`HL_A26_VERIFY_ONCE` (verifier, off).** Over a resident source the verifier checks and re-hashes each
   block once per verification (its pre-header pass) instead of twice. D72 says "the VERIFIER's CS-6 is
   unchanged and still re-hashes every block it binds"; with this on it still does, once per verification,
   on the same object, before the header. Whether that reading holds is the security owner's. Measured: the
   verifier's CPU about −20% (`stream_p2b2k`), one post's verification 7.3 → 6.1 s per category (bi1).
   `verify_core`'s own third check (`protocol.rs`) was left alone.
3. **The embedding table's digest** (805 MB, about three BLAKE3 passes per request on each side: about 3% of
   a request's critical path, 5% of the verifier's CPU) could be kept with the bound tables; it is the same
   kind of reading (a digest kept with an immutable in-memory object) and was not done.
4. **Privacy.** Unchanged from A24: this binary, its GPU execution (now including the down projection's two
   halves, A4's existing kernel) and its server form are not covered by D58; "privacy statement pending",
   public posts only, `production: false`. D63 holds.
5. **The fixed-entropy harness** is test-only and deliberately outside the app; its dylib is outside the
   repository. Receipts made under it hide nothing and were deleted.

## 7. What is left to reach 30 proved tok/s

**The stream is now GPU-bound** [MEASURED, `stream_p2*`]: with the candidate the GPU's Device Utilization is
83% on average and 95–97% at the median over the clock, while the CPU is about 43% busy (13–14 of 32 cores).
More lanes do not help (8 x 4: 13.95 proved tok/s against 14.32 at 6 x 5, `stream_p2b2q8`), and further CPU
cuts mostly shorten waits for the GPU. 30 tok/s is one category proof every 4.3 s; the stream now finishes one
every 9.06–9.10 s (`stream_m1b1`, `stream_m1b2`), against 11.35–11.42 s with A24's binary. So about 2.1x less GPU time per proof, or a second GPU, is what is left.

**Where the GPU waits are** [MEASURED, `stream_p2b2/gpu_waits_by_caller.txt`; the lane threads' waits, which
include queueing behind other lanes, not a GPU timeline: Xcode's `xctrace` is not installed]: the device
sumcheck slots 61%, the commitments (A, H, the boundaries) 27%, the openings' device folds and the rest of the
core 6%, the witness products 4% (the down projection's two halves among them, about 1%).

**The levers, largest first:**
1. **The block profile (A10 / A25's routes).** At W16R2 rows (rate 1/2, about 1.8x fewer committed rows than
   R13) the commitments' encode-and-hash work falls about 3.6x and the zero-check slots shrink with the
   planes. A25 found the real model needs a design step (per-layer plane lists, or a uniform-calibration
   export, or R13 at rate 1/2) and a ruling by Victor, then the W16R2 privacy gate on GPU bundles.
2. **The device sumcheck kernels** (61% of the GPU waits). Byte-preserving by construction (the device IR must
   equal each slot's closure before it may run, M3), so a GPU lane could work on them: fewer round trips per
   slot, typed base-field tables, fused folds. Not this lane's brief.
3. **A second GPU / machine.** The receipts are files and the verifier uses no GPU: proving on two machines,
   or verifying elsewhere (section 3's proof-only clock), scales the stream.
4. **Smaller, CPU-side, not useful while GPU-bound:** the two switches waiting for a reading (section 6), the
   embedding digest kept with the tables, a faster weight fold (14% of the verifier, 3% of the prover).

## 8. Operational notes

- **Guard.** Default floors (disk floor 40 GiB; 119–131 GiB free throughout). The four Lean lanes queued
  many short jobs; the guard is not FIFO (`fifo.on` needs an announced decision, so it was not touched), so
  this lane's jobs waited up to about an hour for the heavy lock. One launcher (`p1`) was stopped after a
  19-minute polite wait and its job queued directly with the guard.
- **Paths outside git.** Binaries: `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a26` (pinned),
  `.a26-b1`, `.a26-b2` (the measured candidates), beside A24's `.a24`. The fixed-entropy dylib and the raw
  `sample` files: `~/zk60-artifacts/a26-tools/`. Private run data: `~/zk60-owner-private/a26-*` (0700, files
  0600). Receipts: `~/zk60-artifacts/a26-*`, deleted after their verification (`--keep 0`; byteid deletes its
  own).
- **Scripts.** `stream_driver.py` (A25's driver + CPU, GPU and sampling), `stream.sh` (quiet-box record),
  `runs.sh` + `*.plan` (a list of runs in one guarded job), `byteid.py` + `bi.sh` (byte identity),
  `sample_profile.py` / `sample_callers.py` / `sample_tree.py` / `summarize_samples.py` (profiles),
  `accept.sh` (native acceptance), `final1.sh`, `app_driver.py` (A25's, with `--binary`).
