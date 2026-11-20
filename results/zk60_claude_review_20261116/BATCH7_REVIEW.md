# Batch 7 independent review (sealing-pass phase profile, overlap decomposition, three-lane stream, retained traces)

Reviewer: Claude (reading review only; no GPU run, no build, no guarded job, no git write, no edit of the author's files).
Date: 2026-11-17. Repository HEAD 4716c6b5 (the binary was built at 2df5f72d; no source under `ops/zkp-mvp/gpu-metal` changed since), perf/zk-batch-optimizations.
Scope read: `results/zk60_batch7_sealing_lanes3_20261117/` (REPORT.md, BATCH7_SEALING_AND_LANES3_METRICS.json, run_batch7_guarded.py, the three logs, the three guard
receipts); the three gz traces in `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/` (sha256 of all three, and of the decompressed bytes, equal the report/JSON);
`BATCH6_REVIEW.md`; the 2026-11-17T11:38:15Z and 12:29:00Z entries of `ops/zkp-mvp/RECOVERY_COORDINATION.md`; `results/zk60_resource_guard/history.jsonl`;
the committed Batch 5/6 files at 4716c6b5 (`git show`); the prover sources `hashline/src/gpu/metal.rs` (`wprod_run`, `result_plane`, `weight_buffer`, `tl_record`, `trace_write`),
`private_block/trained_block.rs` (`seal_chain`, `SealPool`, the A22 turn comments), `private_block/witness.rs` (`build_accuracy_with`, A16 notes),
`private_block/witness_accuracy.rs` (`build_with`, `assign_with`), `private_block/run_fork_tests.rs` (`a22_stream_ab`, `usage_now`); and two earlier measurements that bear on the same question:
`results/zk60_effplan_20261105/a16/README.md` (sampler profile of the sealing pass) and `.../a4/README.md` (per-phase cost of the witness products).
My scripts (standard library only, read-only, print to the screen), all in `results/zk60_claude_review_20261116/batch7_review/`:
`recompute_logs.py`, `recompute_trace.py`, `recompute_extra.py`, `recompute_wait.py`, `recompute_gpubusy.py`, `recompute_p8_vs_gpu.py`.
(`recompute_gpubusy.py.bak` is a stray backup of my own from fixing one regular expression; ignore it.)

Labels: **[A]** the author's figure, quoted; **[R]** recomputed by me from the raw logs and traces; **[C]** my reading of code; **[E]** an estimate; **[NC]** not checked.

## Verdict: STANDS WITH CORRECTIONS

Every table number in the report reproduces from the raw logs and the gz traces: the phase table 1B, the overlap table, the three-lane table, and the per-slot table in section 4. The
runs are clean (one guarded job at a time, same binary as Batch 6, no source change, no secret in the directory). What does not stand is most of the causal story told about the
numbers:

1. The 13.0 s of system CPU time is not evidence about the sealing pass. It is the whole process over the whole request (prover included), and it is flat per request whatever the overlap.
2. "P8 is 54% of the pass" is a measured residual (the time with no witness command buffer in flight). What happens inside it (allocation and zero-fill, lookup scan, `norm_a`) is a
   reading of the code, and the report's size figure (300 MB per block) does not follow from its own formula. An earlier sampler profile (A16) put zeroing at 0.05 to 0.10 s per pass.
   "Pre-allocate the witness buffers" is one hypothesis for part of 1.2 s, not a supported target for the whole of it.
3. The closing inference (79 to 82% of the overlap slowdown, 54% of solo sealing) adds up the full P8 and the full queue wait. That is the gain if both vanished, not a target. The queue
   wait beside a proof is 87 to 97% spent while a prover command buffer is executing, so pacing barriers cannot remove it.
4. The three-lane comparison compares lanes3 post-fill with lanes2 steady (0.998x); like for like it is 0.984x. "S_ov is the hard ceiling" is a model with a constant S, which the batch's
   own data contradict.

Finding counts: 3 High, 6 Medium, 5 Low, 2 Note (list at the end).

---

## 1. Do the headline numbers recompute? (question 1)

All from `recompute_logs.py` and `recompute_trace.py` [R]. Every figure is a **median** of per-request (or per-pass) values; n is stated. Warm-up excluded as stated: the cold request is
dropped, the 6 warm passes are kept, and the 231 start-up and 224 cold-request witness command buffers are stripped from each trace (counts: 1,799 / 5,831 / 8,519 t=128 witness buffers
= 231 + 224 x (1 + 6 x R)).

| Quantity | n | Report [A] | Mine [R] |
|---|---:|---:|---:|
| sealing pass, serve1 solo, median (IQR) | 6 | 2.2150 (0.070) | 2.215 (0.070); passes 2.182 2.247 2.183 2.181 2.302 2.254 |
| sealing pass, serve4 request 0, median (IQR) | 6 | 2.1520 (0.066) | 2.152 (0.066) |
| sealing pass, serve4 requests 1..3, median (IQR) | 18 | 3.3535 (0.176) | 3.353 (0.176); mean 3.359 |
| sealing pass, serve6 requests 1..5 | 30 | 3.2305 (0.175) | 3.231 (0.175) |
| ratio overlapped / solo | | 1.514x (1.558x in process) | 1.514x, 1.558x; pooled solo (serve1 + serve4 req0 + serve6 req0, n = 18) 2.174 s gives 1.543x |
| P1..P9 medians (all rows of table 1B) | 6, 6, 18, 30 | as printed | all equal to the last digit |
| P8 share of solo pass | | 54.3% | 54.3% as a ratio of medians; per pass 51.5% to 56.1% |
| host / GPU summary rows (0.370 GPU busy, 0.249 queue wait, 0.016, 0.402, 1.617 = 73.0%) | | as printed | equal; per pass host share 70.9% to 75.0% |
| steady cadence, lanes2 / lanes3 | 6 / 6 | 3.6678 s (34.90) / 3.7394 s (34.23) | 3.6678 / 3.7394 (34.90 / 34.23) |
| post-fill cadence, lanes2 / lanes3 | | 3.6170 / 3.6760 | 3.6170 / 3.6760 |
| lane admission wait lanes2 / lanes3 | 12 / 18 | 0.5960 / 0.000 | 0.596 / 0.000 |
| prover slack by request position (lanes3) | | 0.53 1.11 1.65 2.35 2.69 | 0.525 1.109 1.650 2.348 2.686 |
| GPU busy union per steady request | 6 | 2.6494 (71.96%) / 2.6823 (71.22%) | 2.6487 (71.91%) / 2.6822 (71.21%), with my own window anchor |
| per-slot spans, section 4 (14 slots) | 6 passes | 44.535 ... 0.017; sum 134.646 | identical (134.645) |
| footprint 45.35 / 50.70 GiB, RSS 32.39 / 38.16, sys 13.0 s | | as printed | equal |

**Mixing of overlapped and unoverlapped passes (the Batch 6 High finding): not repeated in the sealing headline.** The overlapped sealing passes (serve4 requests 1..3, serve6 requests 1..5)
have a prover run beside them for 100% of their span (the previous request's prove call covers the whole sealing turn, 18 of 18 [R]); request 0 is kept apart. The prover's GPU is busy
only 70 to 81% of each overlapped chain window (serve4 request 1 0.70, 2 0.80, 3 0.81; serve6 0.66 to 0.71) [R], so "overlapped" means a prover running, not a saturated GPU.
**Mixing does remain in the steady cadence figures** (finding H7): serve4's 3.668 s averages three result-to-result intervals one of which (request 3) has its prove call uncontended;
serve6's averages five, two of them uncontended. They are not like for like.

## 2. How are P1..P9 defined, and what is measured? (question 2)

**Measured:** the begin, committed, GPUStart, GPUEnd and done timestamps of every witness command buffer (`wprod`, queue 99): 224 per request, 7 per block, in the order Q, K, V, Wo, Wg,
Wu, Wd. I checked the shape and order of all 7 buffers in every one of the 1 + 6 x R requests in all three traces (k and n of each product, and begin(Wo) >= done(QKV), begin(GU) >=
done(Wo), begin(Wd) >= done(GU), begin(QKV of block k+1) >= done(Wd of block k)): no violation, and no two requests' chains overlap in time. So the phase **boundaries** are the
timestamps of real buffers, and the order matches `build_with` (`witness_accuracy.rs:588` norm_a, `:606-:632` Q/K/V products, `:672` the join, `:949` Wo, `:971` norm_m, `:1002` gate/up
join, `:1061` down). P1, P3, P5, P7 are the wall of the buffers' group (min begin to max done). P2, P4, P6 are the gaps between groups inside a block. P8a is the 31 gaps between blocks.
**P8b is a residual**: seal_pass (from the log, 1 ms resolution) minus the first-begin to last-done chain span; sum(P1..P8) equals seal_pass by construction (my check: 0.0 for every request;
P8b 0.033 to 0.035 s every time). P9 is seal_side minus seal_pass, from the log.

**Assumed (not timed by anything):** what code runs inside each gap. The report assigns P2 to "attention scores, softmax, PV", P4 to "AO, residual, norm_m", P6 to "SwiGLU and limbs" and P8
to "assign_with, zero, CS-3 lookup scan, norm_a". Two facts of the code move work across those boundaries [C]:

- `begin` is stamped **after** the host prelude of each product: the i16 pack of the activations, `weight_buffer` (the no-copy page view of the weights) and `result_plane` (a zeroed
  `Vec<i64>` of the plane plus its page view) all run before `begin = host_time_s()` (`metal.rs:4797-4839`). The copy-back/drop runs after `done`. So the pack (2.56 ms per block measured by
  A4, about 0.08 s per request) and the output-plane allocation of each product land in the gap before it: Q/K/V in P8, Wo in P2, Wg/Wu in P4, Wd in P6.
- The requantisation and RoPE of the last-finishing Q/K/V branch run after its `done` (inside `rayon::join`, `witness_accuracy.rs:672`), so they sit in P2.
- Between Wd of block k and Q/K/V of block k+1 the serial chain in `seal_chain` (`trained_block.rs:3020-3088`) runs, in order: the tail of the builder, `assign_with`, `check_lookup_misses`
  (CS-3), `padded_plane`, `true_words`, the `seq` comparison, `hand.block` and `hand.witness`, then the next block's `build_for_block` (the shared `check_accuracy_for_shape` including the -128
  scan of the nine weight arrays), `norm_a` and its requantisation, and the Q/K/V preludes. The report names three of these.

## 3. Inside P8 (question 3)

**Not measured.** There is no timer, counter or sampler inside P8 in this batch. What I could check:

- **The 13.0 s of sys time.** The log's `user X s + sys Y s` comes from `usage_now().since(u0)` (`getrusage(RUSAGE_SELF)`, `run_fork_tests.rs:1979-2001`) taken around the whole `serve_stream` call:
  all threads of the process for the whole 6.2 s request (sealing, the six prover forks, the 28 to 32 thread global pool, 16 receipt writers). It cannot be assigned to the sealing pass.
  It is also **flat per request whatever the overlap**: serve1 13.0 s (user 51.4), serve4 52.9 / 4 = 13.2 s, serve6 82.2 / 6 = 13.7 s, while the sealing pass goes from 2.2 to 3.3 s [R]. The report's
  "1.62 s x 8 SealPool threads = 13.0 s" is arithmetic that happens to match. An earlier measurement of the sealing pass **alone** (A16 stage 1, `README.md:126-145`) gave 1.63 to 1.67 s wall,
  user 5.1 s and **sys 4.0 s** for the whole pass (A15: 7 + 2 s under an 8-thread pool).
- **Size per block.** The report says `assign_with` allocates "2,504 + 2,606 = 5,110 rows x 16,384 cols x 8 B, about 300 MB per block, 9.6 GB per request". 5,110 x 16,384 x 8 B = **670 MB**,
  not 300 MB. Those row counts are the committed A and H matrices (`layout.rs`; 8 x a_rows x n x (1 + inv_rate) is the A19 "part" estimate); `assign_with` allocates the witness **planes**
  (`vec![0; g.len(dom)]` per plane id, `witness_accuracy.rs:1132`), whose sizes are the domain lengths (D, Q, S planes 4 MiB, Kv 1 MiB, F planes 16 MiB at t_pad 128 and f_pad 16,384 [C]), and H is built
  in the prover, not in the sealing pass. Three figures disagree: 670 MB (the report's formula), 300 MB (its claim), and the footprint step per extra sealed request divided by 32
  (5.35 GiB / 32 = 169 MiB). A16 counted about 529,000 minor faults per pass, which at this machine's 16 KiB page (sysctl `hw.pagesize` 16384) is about 8.1 GiB, so "several GiB of fresh pages per request" is plausible [C, A16].
  The per-block figure itself is **not established** by this report.
- **What the earlier sampler said.** A16's `sample` profile of the pass after the A16 forms (`README.md:155-168`) put the zeroing of fresh planes at 0.05 to 0.10 s per pass (where most pages are
  first touched), `assign`'s limb planes at 0.29 s, `quantized`'s fills at 0.20 s, the device wait at 0.36 s and the serial remainder at 0.04 s, main line 1.24 s. That is about 1.1 to 1.3 s of
  host work in total, the same size as P8 plus the middle phases, but with first-touch and zeroing a small part of it. It was taken on the code of 2026-11-06, and the stream today takes 2.2 s against
  A16's 1.63 to 1.67 s harness figure; the 0.5 s difference is in code the harness does not run (CS-3, `hand`, `padded_plane`) or in stream conditions, and nothing here attributes it.
- **P8 per gap is flat** [R]: median 37.3, 35.7, 35.5 ... 35.0, 35.7, 35.6 ms for the 31 gaps (first three 37.3 / 35.7 / 35.5, last three 35.0 / 35.7 / 35.6, middle median 36.3 ms), no first-touch trend.
  That fits a fixed per-block cost, which says nothing about which part of the block.

So "pre-allocate the witness buffers for P8" is **one hypothesis among several** (zeroing and first touch; the limb scatter itself; the CS-3 scan; the weight scan; the preludes) for a measured
1.2 s. How to measure it without touching a pinned file: print `ru_minflt` (it is already in the `rusage` struct the harness reads) and per-pass sys time for a solo `serve1` pass, and take the same
`/usr/bin/sample` call graph that A15 and A16 used, re-split by the A16 `mainline_split.py`. Env-gated timers in `trained_block.rs` or `witness_accuracy.rs` need coordination with Astra's source
pin (REPORT.md section 0); not in `metal.rs` or `pcs.rs`.

## 4. "Metal driver/idle-wake wait" (question 4)

**Formula** (`partition_wprod_group`, `run_batch7_guarded.py:386-430`): for each of the 4 groups of a block, over [min begin, max done] of the group's buffers, count the time at which no buffer of
the group is executing on the GPU (GPUStart to GPUEnd union) but at least one is between `committed` and `gpu_start`. It is the host-clock commit time to Metal's GPUStartTime. My
recomputation equals theirs (0.2489 s solo, 0.7044 s beside a proof). The sum of the per-buffer commit-to-start gaps is larger (0.444 s solo) because the three buffers of a group queue together.

**What it can and cannot say** [R]:
- With no prover running (serve1, and request 0 of serve4 and serve6) the gap is 0.92 to 1.07 ms median for Q, K, V, Wo and **1.5 to 2.2 ms for Wg, Wu, Wd** (mean over all 224: 1.98 ms). Nothing else
  is on the GPU, so this is latency of the submit path itself. Its cause is not separable: GPU wake from idle, the driver's submit and residency work, or the mapping of the no-copy page views
  (`newBufferWithBytesNoCopy` of 4 to 67 MB of weights and a freshly zeroed output plane). The larger gap for the 67 MB weight products fits the page-view reading at least as well as an idle-wake
  reading; `HL_GPU_WITNESS_VIEW=0` (an existing switch) would separate them. The report's label is an interpretation.
- Beside a proof (serve4 requests 1..3, serve6 1..5) 87% to 97% of the per-request sum of these gaps lies inside time when a prover command buffer is executing (`recompute_wait.py`). So the
  **excess** over solo is waiting behind running prover work, as the report says. Whether the GPU time-slices, queues or lowers the witness queue's priority is not visible in the trace.
  All prover buffers are on queue 0 (the shared queue, 14,558 rows in serve4); the "six concurrent fork queues" are six threads submitting to one queue. Queue 99 is the witness queue.
- **The label "host pack 0.016 s" is wrong.** `wprod host inside` is `wall - GPU busy - queue wait` within [begin, done], i.e. begin-to-commit encode (0.0025 s per request, sum of 224) plus
  done-minus-GPUEnd wake (0.026 s) and small gaps. The i16 pack is outside it (finding H5).

## 5. The overlap decomposition (question 5)

Recomputed from the traces (`recompute_trace.py`) [R]:

| Part (serve4 requests 1..3, n = 18, against serve1 solo, n = 6) | delta, medians | share of +1.1385 | delta, means | share of +1.1337 |
|---|---:|---:|---:|---:|
| queue wait on queue 99 | +0.4554 | 40.0% | +0.4595 | 40.5% |
| P8 | +0.4443 | 39.0% | +0.4705 | 41.5% |
| P2 + P4 + P6 | +0.1249 | 11.0% | +0.1316 | 11.6% |
| wprod GPU busy | +0.0680 | 6.0% | +0.0697 | 6.2% |
| wprod host inside | +0.0012 | 0.1% | +0.0024 | 0.2% |
| sum | +1.0939 | **96.1%** | +1.1337 | 100.0% |

- **Where the rest is:** 96.1% is the sum of five medians; medians do not add (the report says so, "non-additivity of medians", and that is right). The means add exactly. The shares on means are
  40.5 / 41.5 / 11.6 / 6.2 / 0.2.
- **Baseline.** serve1 (2.215) and serve4 request 0 (2.152) are both solo and 3% apart with an IQR of 0.07 and n = 6 each; serve6 request 0 is 2.1525; pooled 2.174. The headline uses serve1; the
  in-process baseline (serve4 request 0, +1.2015 s, x1.558) is the cleaner comparison. Either is fine if both are given; the shares barely move (41.4 / 41.4 / 10.6 / 6.4 / 0.2 on means against the pooled solo).
- **Side check, positions.** Request 1 of serve4 runs beside request 0's prove call and is the slowest (3.465 s); requests 2 and 3 are 3.353 and 3.265 s. The "overlapped" medians mix these.
- **Memory bandwidth and page locks are supposed, not measured.** P8 slows x1.37 and P2+P4+P6 x1.31: both host phases slow by a similar factor, which points to a common host cause
  (cores, caches, memory system), not one specific to page zeroing. The two host parts together are +0.569 s (50%), the two GPU parts +0.523 s (46%). One direct test I could make: across all 558
  (serve4) and 930 (serve6) inter-block gaps in the overlapped requests, **the gap is shorter when the prover's GPU is busy during it**: Pearson r = -0.59 (serve4) and -0.36 (serve6); median 62 ms
  when the prover GPU is busy less than half the gap and 47 ms when it is busy more than half (solo: 36 ms) (`recompute_p8_vs_gpu.py`). If P8's growth came from the prover's GPU streaming through
  unified memory, the long gaps should coincide with a busy prover GPU. They coincide with the prover's host-side phases instead (commit hashing and Merkle work, the opening folds, the sumcheck host
  rounds). It is an association with the prover's phases, not proof, but it argues against the report's explanation.

## 6. Three lanes (question 6)

- **34.23 against 34.90 tok/s.** Per-pass cadence lanes2: 3.643 3.724 3.660 3.719 3.676 3.632; lanes3: 3.782 3.745 3.732 3.708 3.734 3.779 [R]. Difference 0.071 s (1.9%); Welch t = 3.6 with 6 against 6, one
  process each, fixed order (serve1, serve4, serve6, not interleaved). The ranges overlap (3.708 and 3.724 are in both). The A19 README quotes about +-2% as the noise floor of this kind of A/B. So: a small loss, at the edge of what these runs can separate; "no gain" is supported, "0.981x" is a measured ratio of two means from different request mixes.
- **The 0.998x is wrong as labelled.** It is 34.82 (lanes3 post-fill) over 34.90 (lanes2 **steady**). Like for like, post-fill is 3.617 against 3.676 s: 35.39 against 34.82 tok/s, **0.984x**.
  Mid-stream intervals tell the same way: request 1 to 3 results are 3.88, 3.84, 3.93 s on lanes3 against 3.77, 3.70 (and 3.54 for the uncontended last) on lanes2 [R].
- **Consistency with Batch 6.** serve4 steady cadence 3.668 against Batch 6's 3.606: +0.062 s (+1.7%). Sealing alone 2.215 against 2.172 (+2.0%); serve1 wall per request 6.188 against 6.093 (+1.6%);
  overlapped sealing 3.353 against 3.321 (+1.0%). The whole machine ran 1 to 2% slower than during Batch 6, uniformly. The report does not mention it. It does not bias lanes3 against lanes2 (same batch),
  but quoting 3.668 as "the two-lane figure" next to Batch 6's 3.606 needs the note.
- **What `HL_A19_BUDGET_GIB` governs** [C]. It is `cfg.budget` of the served request, passed to **each** request's `seal_chain` as `budget_bytes` (`trained_block.rs:4012`, `:3068`, `:3081`): the bytes of witnesses
  plus A-side "parts" that one request may keep or hand to the fork window before the rest are rebuilt. It is **per request**, not a limit on the process, and it does not admit or refuse a lane. The
  number of lanes is `HL_A22_LANES` / the arm label, clamped 1 to 4 (`trained_block.rs:3849-3853`). So the guard's `--need-gib 48 --cap-gib 64` are the guard's limits, and "a budget that admits it"
  is not what happened; the budget was the same 32 GiB per request in all three arms. RSS 38.2 GiB and footprint 50.7 GiB are over the budget number because the budget is per request.
- **"Lanes hold BlockWitness planes, not the 43.2 GB codewords."** Consistent with the code comment (one sealing turn and one prover turn at a time, the prove call builds the codewords) and with the
  measurements (VRAM peak 22.5 against 23.2 GiB: no growth; RSS +5.8 GiB). But "+5.4 GiB per lane" is not a per-lane constant: peak footprint is 42.40 (serve1), 45.35 (serve4), 50.70 (serve6) GiB, i.e. +2.95 for
  the step 1 to 2 lanes and +5.35 for 2 to 3, with different request counts and queue depths (up to 2 sealed requests waiting in lanes3, slack 2.7 s). The held "parts" may also include A's host rows,
  which the A19 note puts at about 1.28 GB per part with the witness. Say "about 5 GiB more at the peak" and not "per lane".
- **"S_ov = 3.231 s is the hard ceiling" is a model, and the arithmetic holds only under its assumption.** (S_ov + W + P')/3 <= (3.231 + 0.22 + 3.58)/3 = 2.34 s is right, so for P' below 3.58 s the three-lane
  chain is not the limit and the Turn-serialised sealing is. But (1) S_ov is the median of the overlapped sealing pass at **today's** prover speed; as P' falls the prover covers less of the sealing pass and
  S falls toward the solo 2.17 s (the Batch 6 review's point G2, which this report does not apply to its own ceiling), so the floor lies between about 2.2 and 3.3 s, not at 3.231. (2) The Turn is held for
  the whole sealing side, 3.296 s median on lanes3 (seal_done minus seal_turn [R]), not the sealing pass 3.231. (3) S_ov differs by arm and position: 3.353 on serve4, 3.231 on serve6, and on serve6
  request 1 is 3.487 and requests 2 to 5 are 3.18 to 3.23 s. (4) "1.135x above today's 3.668 s cadence" is the wrong direction: S_ov is below the cadence; 3.668 / 3.231 = 1.135 is the most a faster prover could
  gain **if S stayed 3.231**. Label it MODEL.

## 7. Run hygiene (question 7)

- **Guard receipts** [R]: serve1 `061723c7aeb6` (class gpu, exit 0, waited 0.1 s, wall 53.6 s, peak RSS 29.34 GiB, VRAM 22,965 MiB, need 36 / cap 48); serve4 `48fd544d9472` (127.1 s, 32.39 GiB, 23,151 MiB, 40 / 52);
  serve6 `604ae9fa4f37` (176.8 s, 38.16 GiB, 22,508 MiB, 48 / 64). All `enforcement: watchdog-only`, `hard_killed 0`, `gpu_drain_failed false`, same binary path.
- **No other guarded job in any window** [R]: `history.jsonl` rows ending between 11:55Z and 12:30Z are only these three (starts 12:07:27Z, 12:16:40Z, 12:19:01Z; ends 12:08:21Z, 12:18:48Z, 12:21:58Z). Unguarded
  light work cannot be excluded from the retained files.
- **ds4-bench quiet:** the JSON `quiet_gpu_checks` has **4 entries (serve4 and serve6, pre and post), none for serve1**: the final run of the script reused the serve1 leaf from an earlier run
  (`main()` reuse branch). "ds4-bench absent pre/post every leaf" is supported for two of the three leaves (finding H9).
- **Warm-up:** the cold request is excluded (the `[serve1 (cold)]` lines are not used), n = 6 warm passes per arm, as stated.
- **Receipts and digests:** each arm logs `all N receipts verified` **twice**: for the cold request and for **pass 0 only** (the test verifies "each arm's first pass", `run_fork_tests.rs` doc of `a22_stream_ab`).
  Passes 1 to 5 are not verified in the stream logs; they print the receipt size (818,728,672 B each). The logs carry no proof digest. The report's "every warm receipt verified from its run directory" is too strong.
- **Binary** [R]: `hashline-a90b6cf7715dc2a7`, sha256 aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11 re-computed, equal to the Batch 6 value, the JSON and the report.
  `git diff --stat 2df5f72d HEAD -- ops/zkp-mvp/gpu-metal` is empty; `git status --short` on hashline, zkp-core and private-block-kernel prints nothing (and under `ops/zkp-mvp/gpu-metal` only
  untracked `results/r12-*` and `r13-*` directories). "0 Rust lines touched": supported.
- **Scope notes** [C]: the stream test serves **the D55 harness's synthetic stack** (`A22Synth`, "one synthetic block, the honest chain", repeated 32 times), not a trained export; the report does not say so. The GPU
  trace was on in all arms (no untraced control, as in Batch 6); arm order was fixed (serve1, serve4, serve6).
- **Hardware line wrong:** the report says Apple M3 Max, 28 CPU threads, 400 GB/s. `sysctl`: Apple M3 Ultra, 32 cores, 256 GiB. The mechanism text "28-thread Rayon pool on 28 CPU threads" (report section 2, script line 819)
  follows from it. The seal pool of 8 is right (cores / 4, clamped to 8).

## 8. Publication hygiene (question 8)

Checked by grep over every file in the directory [R]. **Nothing must be removed.** No credential, token, password, e-mail address or personal data; no agent session id; the only home-directory paths are
`/Users/victorrielly/IntelligenceRegulation/...` and `/Users/victorrielly/zk60-artifacts/batch7_traces_20261117/...`, which are already public; `run_batch7_guarded.py` uses `Path.home()` and no `.gemini` or
brain path. No zero-byte or truncated file (sizes 1.4 KB to 143 KB; each log ends with `test result: ok`). No binary, no `.dylib`, no `__pycache__`. Everything is untracked (`?? results/zk60_batch7_sealing_lanes3_20261117/`).
All 9 files back a number: the report, the JSON (143 KB, mostly per-pass samples), the script, the three logs, the three guard receipts. Optional: the JSON is large; it is fine. After the corrections below
(especially the hardware line and the labels), commit by named paths. The traces stay outside the repository (1.45 MB).

## 9. Batch 5/6 corrections in 4716c6b5, G1 to G12 (question 9)

From `git show 4716c6b5:results/zk60_h132_batched_forward_20261116/{REPORT.md,BATCH6_HEAD_PROFILE_METRICS.json,H132_H128_H127_METRICS.json,run_batch6_guarded.py,metal_batched_llama8b.mm}`:

| ID | Status | One line |
|---|---|---|
| G1 | Applied | Slot helper share given as [ESTIMATE] 8 to 16.5 ms plus 0 to 8 ms for TAB; ceiling x1.24 measured, x1.29 to x1.41 with the estimate; stated as gross. |
| G2 | Applied | 3.054 s explained as a 4-request mean with unoverlapped request 0; 3.321 s overlapped; model max(P, (S+W+P)/2); ceiling x1.09 to x1.19 (x1.13 to x1.27 with slots); slack 0.137 s. |
| G3 | Applied | Sentence withdrawn in the header and in the Batch 5 JSON note; the HL_METAL_TIMING=1 confound, metal.rs lines and the overwritten binary stated. |
| G4 | Applied | Host fold about 11.2 ms per block (5.3 + 5.9), 4% of the proof core; the 0.175 ms is the gather buffers; "dropped for lack of a kernel, experiment not run". |
| G5 | Applied | The 52 ms list is called variant G3; G1 variant about 36 ms (x1.15) given. |
| G6 | Applied | Conversion stated as an assumption with the 13% to 22% range. |
| G7 | Applied | Candidate A's own cost (GKR 40 to 105 ms, leaf claims 9 ms, +48..+144 M rows) named; net about x0.8 to x1.1; "prototype not ordered on speed grounds". |
| G8 | Applied | `trace_retention_note_G8` in the JSON and a caveat in the report; Batch 7 keeps the traces (done, see section 1). |
| G9 | Applied | "IQR 11.0; last 5 settled passes median 266.0 ms, IQR 2.0". |
| G10 | Partly | 35.12% labelled as a median of ratios against 34.88% of medians; the note that 93.482 + 172.974 does not equal 268.0 (medians of separate series) is not in the report row. |
| G11 | Partly | Table 3A cell fixed (8.282 ms, 1.065x); H127 verdict rewritten ("Closed / small, not robust to bucket choice") in the JSON; the Amdahl sentence is no longer in the report (nothing to check); the `.mm` still says "Zero-Spill" in the kernel comments (lines 1235 and 1246), the "bank-conflict" wording is gone. |
| G12 | Applied | The 20 committed files contain no zero-byte log, no build-log fragment and no session-id path (`run_batch6_guarded.py` has no `.gemini` literal; the Batch 5 script holds the plain public `/Users/victorrielly/...` paths). |

---

## Findings list (for the coordinator)

| ID | Level | Finding |
|---|---|---|
| H1 | High | The "13.0 s of macOS sys CPU per request corroborates page-faulting in P8" is process-wide `getrusage` over the whole request (prover, receipt writers, pools). It is flat per request (13.0 serve1, 13.2 serve4, 13.7 serve6) while sealing goes 2.2 to 3.3 s. A16 measured sys 4.0 s for the sealing pass alone. The "1.62 s x 8 threads" arithmetic is a coincidence. Remove it as evidence. |
| H2 | High | The split inside P8 (allocation and zero-fill vs lookup scan vs `norm_a`) is not measured. P8 is the time with no witness buffer in flight, so it also holds the builder tail, `check_lookup_misses`, `padded_plane`, `hand`, the next block's checks and weight scan, and the Q/K/V preludes. The "300 MB per block" does not follow from the stated formula (670 MB), which counts H rows `assign_with` does not allocate; footprint step / 32 gives 169 MiB. A16's sampler put zeroing at 0.05 to 0.10 s per pass. Pre-allocation is one hypothesis for part of 1.2 s. |
| H3 | High | Closing inference F ("79 to 82% of the overlap slowdown and 54% of solo sealing") is the sum of the whole queue-wait growth and the whole of P8 (and all of P8 solo): a ceiling if both vanished, not a target. 87 to 97% of the overlapped queue wait is spent with prover work executing, the 4 barriers per block are data dependencies, and P8 cannot be removed, only its allocation part. |
| H4 | Medium | The cause of P8's growth beside a proof (memory bandwidth, VM page locks) is supposed. Host phases P8 (x1.37) and P2+P4+P6 (x1.31) grow alike (common host cause); P8 gaps are longer when the prover GPU is idle (62 against 47 ms, r = -0.59 and -0.36), which points at the prover's host-side work, not its GPU streaming. |
| H5 | Medium | Labels: "Metal driver/idle-wake wait" is commit-to-GPUStartTime, not separable from submit and page-view residency work (it is larger for the 67 MB weight products); "host pack 0.016 s" is encode plus completion wake, while the i16 pack, `weight_buffer` and `result_plane` run before `begin` and sit in P2, P4, P6 and P8 (about 0.08 s per request by A4). |
| H6 | Medium | Phase boundaries are measured (buffer timestamps; order and barriers verified on every request); what runs inside P2, P4, P6, P8 is assumed from code order, and the preludes and requantisation cross the boundaries. P8b is a residual of a 1 ms log figure and a trace span. |
| H7 | Medium | Three lanes: the 0.998x compares lanes3 post-fill with lanes2 steady; like for like it is 0.984x (3.617 against 3.676 s). 0.981x (3.668 against 3.739 s, t = 3.6 at n = 6 and 6, fixed order) is a small loss at the edge of the +-2% noise floor, and the two cadence figures average different mixes of contended and uncontended intervals. "A third lane buys nothing" is supported; "0%" is not. |
| H8 | Medium | "S_ov = 3.231 s is the hard ceiling" is a model with S held constant, contradicting G2 (S shortens as P shortens, floor between about 2.2 and 3.3 s), using the sealing pass 3.231 rather than the Turn's sealing side 3.296 s, with S_ov differing by arm (3.353 serve4) and position. "1.135x above" is the wrong direction (it is the most a faster prover could gain at constant S). |
| H9 | Medium | Run claims too strong: "every warm receipt verified" (only the cold request and pass 0 are verified, no digests in the logs); "ds4-bench quiet pre/post every leaf" (recorded for serve4 and serve6 only; serve1 was reused); `HL_A19_BUDGET_GIB` is a per-request witness budget (32 GiB in all arms), not an admission control for lanes. |
| H10 | Low | The decomposition percentages are medians and sum to 96.1% (unexplained +0.045 s); on means they sum to 100% (40.5 / 41.5 / 11.6 / 6.2 / 0.2). The serve1 and serve4-request-0 baselines differ by 3% (IQR 0.07); give both or the pooled 2.174 s (x1.54). |
| H11 | Low | Hardware header wrong (M3 Max, 28 threads, 400 GB/s; machine is M3 Ultra, 32 cores, 256 GiB); "28-thread Rayon pool on 28 CPU threads" in the mechanism text. |
| H12 | Low | Not stated: this batch ran 1.0 to 2.0% slower than Batch 6 throughout (serve4 cadence 3.668 against 3.606 s, sealing alone 2.215 against 2.172, serve1 wall 6.188 against 6.093). |
| H13 | Low | Section 4 reproduces exactly, but the sentence "consistent with G1's 0 to 8 ms TAB bound and 8 to 17 ms helper share" is not an inference: the spans are sums over six forks (sum / union up to 2.3x for the large slots), not wall, and the "about 18 to 35 ms per block wall" is a guess. Slots 13 and 20 are present in 5 and 3 of 6 passes. The table is useful as per-slot GPU work (distribution), and could now give a measured per-slot GPU share for G1. |
| H14 | Low | Wording: "six concurrent prover fork queues": the trace has all prover buffers on queue 0 (six submitting threads); "+5.4 GiB per lane" is +2.95 GiB for the second and +5.35 GiB for the third at the peak, not a per-lane constant. |
| H15 | Note | Scope: the stream serves the harness's synthetic stack, not a trained export; the trace was on; arm order was fixed; passes were not interleaved. The sealing figures are for this fixture. |
| N1 | Note | Checked and fine: all table numbers; the three trace hashes (compressed and decompressed); the binary hash equals Batch 6; clean source tree; one guarded job at a time; no secret or session id; barrier order on every block; section 4 slot table; the identity sum(P1..P8) = seal_pass; every request chunk disjoint in time; the 18 of 18 overlap fact. |

## Supported reading: where the sealing pass's time goes and what would speed it up

- **MEASURED (author, re-derived by me [R]).** A solo 32-block sealing pass takes 2.2 s (2.17 pooled, n = 18). The time with no witness command buffer in flight (P2, P4, P6, P8 plus the 2 x 0.036 s bookends) is 71 to 75% of it;
  the 128 witness-product groups account for 28.5%, of which the GPU executes about 0.37 s and about 0.25 s is commit-to-GPUStart latency with nothing else on the GPU. [RECOMPUTED]
- **MEASURED [R].** The single largest block of host-only time is the gap between blocks: 31 gaps of about 36 ms (1.17 s, 52.7%), flat across blocks. The middle gaps inside a block (attention, pre-FFN, SwiGLU) total 0.40 s.
- **CODE-READ.** The between-block gap is the serial chain of `seal_chain` and the builder (assign, CS-3 scan, plane copy, hand-over, the next block's checks and norm, the first product preludes). Page zeroing and first
  touch of the new planes happens inside it. How much of the 36 ms each item takes is **not measured**. [CODE-READ]
- **PRIOR MEASUREMENT (A16, 2026-11-06 sampler, other code revision).** Zeroing and first touch 0.05 to 0.10 s per pass, limb planes 0.29 s, quantisation fills 0.20 s, device wait 0.36 s. [MEASURED, earlier]
  That is a prior against "allocation dominates P8".
- **MEASURED [R].** Beside a proof the sealing pass takes 3.35 s (x1.51 to x1.56). About half of the extra 1.14 s is in the GPU witness products (queue wait +0.46 s, 40%; kernel +0.07 s, 6%) and about half in
  host phases (P8 +0.44, middle phases +0.12). Of the queue-wait growth, 87 to 97% is spent while prover work executes on the GPU. [RECOMPUTED]
- **ASSUMED.** That the host-side growth is memory-bandwidth or page-lock contention (not supported; the gap lengths follow the prover's host phases, not its GPU activity). That commit-to-start latency is
  driver idle-wake (could equally be page-view mapping or submit cost).
- **What would speed it up, ranked by what is supported.** (1) Anything that shortens the between-block host chain, but first measure it (minor-fault count and a `sample` graph on a solo pass; the machinery exists).
  Reusing or pre-zeroed planes is one candidate; the limb scatter (A16: 0.29 s), the quantisation fills (0.20 s) and the CS-3 scan are others. [ASSUMED until measured] (2) Fewer, larger witness command buffers
  (for example Q, K, V in one) would cut per-buffer latency; A4 already noted this and that it needs a builder change. [CODE-READ; gain not measured, bounded by 0.25 s solo] (3) Moving P2+P4+P6 to the GPU touches at most
  0.40 s of 2.2 s (18%), as the report says. [RECOMPUTED] (4) The overlap slowdown is shared between GPU waiting and host contention; no single fix reaches the 79 to 82% quoted. [RECOMPUTED]
- **Stream.** Today the two-lane pipeline is prover-bound (prover stall 0.000 s) and a third lane gives no gain (and about 2% loss at this noise level). [MEASURED] What limits a faster prover later is the Turn-serialised
  sealing side, between about 2.2 s and 3.3 s depending on how much the prover is still running beside it. [MODEL, ASSUMED constants]

## What I did not check

- Anything inside P8: no counter, timer or sampler exists in the retained files; I read the code only.
- The clock identity of `host_time_s()` and Metal's GPUStartTime (the traces are consistent: gpu_start is always after committed and before gpu_end for every buffer I read).
- Whether any unguarded process used the GPU or memory bandwidth during the runs (only the author's `pgrep` for two leaves).
- The effect of the trace being on, of arm order or of thermal state; the sealing time of a real trained export (the stream serves the synthetic stack).
- The plane sizes of `assign_with` exactly (I read the layout code and the domain lengths but did not count every plane; the 0.3 to 0.45 GB per block I considered is an estimate [E] and is not used in any finding).
- Whether `result_plane`/`weight_buffer` page-view residency is the cause of the commit-to-start latency (the switch that would test it, `HL_GPU_WITNESS_VIEW=0`, was not run: no runs allowed).
- The Lean part of the coordination entry.

## Corrections requested (for Antigravity, REPORT.md and the JSON, before the numbers enter the status documents)

1. Delete the 13.0 s sys-CPU "corroboration" and the "1.62 s x 8 threads" sentence everywhere; say that sys time is process-wide, per request about 13 s in all arms, and that A16 measured about 4 s for the
   sealing pass alone.
2. State that the split inside P8 is not measured. Define P8 as "the time between witness command buffers with none in flight", list its code content as in section 2 of this review, and mark the allocation/zero-fill
   share as a hypothesis. Remove "300 MB per block = 9.6 GB per request" or recompute it from the plane lengths; do not use the 5,110-row figure (it is the A and H matrices, and H is not built in the sealing pass).
   Cite A16's sampler (zeroing 0.05 to 0.10 s) next to it.
3. Rewrite the closing inference (section 2 and the coordination entry) as an upper bound: "if P8 and the queue wait vanished the pass would fall by 54% (solo) and the overlap slowdown by 79 to 82%";
   state that this is not a target, that 87 to 97% of the overlapped queue wait is spent beside executing prover work, and that the barriers are data dependencies.
4. Replace the memory-bandwidth and page-lock mechanism for P8 beside a proof by "cause not separated"; add that P8 and P2+P4+P6 grow by a similar factor and that the long gaps coincide with prover phases in which
   its GPU is idle.
5. Relabel "Metal driver/idle-wake wait" as "commit to GPUStartTime wait (cause not separated: submit path, GPU wake, page-view mapping)"; relabel "host pack" as "encode + completion wake" and note that the pack,
   `weight_buffer` and `result_plane` run before `begin`, inside P2, P4, P6, P8.
6. Say plainly in section 1A which boundaries are measured (buffer timestamps, order and barriers verified) and which content is assumed; note that P8b is a residual and the requantisation and preludes cross boundaries.
7. Fix the three-lane statements: report post-fill like for like (3.617 s lanes2, 35.39 tok/s, against 3.676 s lanes3, 34.82 tok/s, 0.984x), give the per-pass ranges and the 1.9% difference at n = 6, say it is at
   the noise floor and that the cadence figures average different mixes of contended and uncontended intervals; do not write "0.998x" or "buys 0%".
8. Label the "S_ov hard ceiling" a model; use the sealing-side 3.296 s; say S is expected to fall as the prover gets faster (floor between about 2.2 and 3.3 s) and fix "1.135x above".
9. Correct the run claims: receipts verified for the cold request and pass 0 only, no digests in the logs; ds4-bench check recorded for serve4 and serve6 only (the JSON has no serve1 entry); `HL_A19_BUDGET_GIB` is
   a per-request witness budget, the same in all arms, and lanes are set by the arm label.
10. Give the decomposition shares on means (40.5 / 41.5 / 11.6 / 6.2 / 0.2, sum 100%) or state that the medians sum to 96.1%; give both baselines (x1.514 and x1.558) or the pooled 2.174 s (x1.543).
11. Fix the hardware line (M3 Ultra, 32 cores, 256 GiB) and the "28 CPU threads" mechanism text in the report and in `run_batch7_guarded.py:819`.
12. Add one sentence that this batch ran 1.0 to 2.0% slower than Batch 6 (3.668 against 3.606 s cadence) and that the stream serves the synthetic harness stack with the trace on.
13. Section 4: drop "consistent with G1's bounds" and the "about 18 to 35 ms per block wall" guess; say the spans are summed over six concurrent forks.
14. Wording: "six concurrent fork queues" to "six fork threads on the shared queue 0"; "+5.4 GiB per lane" to "about +5 GiB at the peak with the third lane (+3 GiB for the second)".
15. For the next batch (measurement, no source change needed): print `ru_minflt` and sys time per pass for a solo `serve1`; take a `/usr/bin/sample` call graph of one solo pass and re-split it with the A16 scripts;
    run `HL_GPU_WITNESS_VIEW=0` once to test the page-view reading of the commit-to-start latency. If timers are wanted inside `seal_chain` or `assign_with`, ask Astra about the source pin first (not `metal.rs`, `pcs.rs`).
16. Commit by named paths after the corrections: REPORT.md, the JSON, `run_batch7_guarded.py`, the three logs and the three guard receipts (9 files); nothing needs to be removed.
