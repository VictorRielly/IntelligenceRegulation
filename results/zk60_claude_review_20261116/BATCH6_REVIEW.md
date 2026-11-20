# Batch 6 independent review (HEAD one-block profile, six-fork stream, candidate A removal list, candidate E fold, Batch 5 corrections)

Reviewer: Claude (reading review only; no GPU run, no build, no guarded job, no git write, no edit of the author's files).
Date: 2026-11-17. Repository HEAD b809b591 (the build was at 2df5f72d), perf/zk-batch-optimizations.
Scope read: `results/zk60_h132_batched_forward_20261116/` (BATCH6_HEAD_PROFILE_METRICS.json, REPORT.md, run_batch6_guarded.py,
the three Batch 6 guard JSONs, batch6_1block_m4_7warm.log, batch6_1block_a4_30reps.log, both stream logs, the retained build log,
H132_H128_H127_METRICS.json, the Batch 5 Rust logs), the last Antigravity entry in `ops/zkp-mvp/RECOVERY_COORDINATION.md`
(2026-11-17T11:22:00Z, section 2), `docs/zkmatrix-poc/ZK60_NEXT_PROTOCOL_CANDIDATES.md` (section 3 A, E; section 6),
`research/zkp-efficiency/experiments/logup-gkr-20261101/` (ZK_DESIGN_NOTE.md, projection.py), `results/zk60_resource_guard/history.jsonl`,
and the prover sources `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs`, `private_block/run_fork_tests.rs`, `private_block/argument.rs`.
My scripts (read-only, print to the screen): `batch6_review/recompute_one_block.py`, `batch6_review/recompute_stream.py`.

Labels used for every number: **[A]** measured by the author and quoted; **[R]** recomputed by me from the author's raw log lines or the
author's JSON; **[C]** my reading of code or a document; **[E]** an estimate (and from what); **[NC]** not checked.

## Verdict: STANDS WITH CORRECTIONS

The measurements themselves are sound. The build is from HEAD sources, all eight Metal passes match the CPU digest, every headline
number recomputes, and nothing else heavy ran in the two timing windows. What does not stand is the use made of them for candidate A:

1. The "everything candidate A removes" list leaves out the helper-relation work inside the 23 sumcheck slots, so the one-block
   gross ceiling of x1.24 is a floor for the gross figure, not the figure (about x1.29 to x1.41, an estimate).
2. The stream "floor" of 3.054 s is not a floor. The number is a mean that includes an unoverlapped request, the log shows two
   admission lanes, and the sealing pass is slowed by the overlap. The stream ceiling that I can support is x1.09 to x1.19 on the
   author's list (x1.13 to x1.27 with the helper slots), not x1.18 to x1.22.
3. The statement that the drop from 337 ms to 268 ms is due to A27, A28 and A30 is not supported, and the 337 ms run was taken with a
   diagnostic switch that inflates the commitment phases (it re-runs GPU parts on scratch buffers).

Finding counts: 3 High, 5 Medium, 4 Low, 1 Note (list at the end).

---

## 1. Is the candidate-A removal list right, in both directions?

### 1.1 What candidate A removes and adds (from the candidates document and the design note) [C]

- Removed: the H commitment's helper columns, the helper inverses that fill them, the H opened columns and claim groups, **every helper
  constraint term in the domain zero-checks**, and the table-helper part of the TAB slot (`ZK_DESIGN_NOTE.md` section 3, "What is
  removed"; candidates doc section 3 A).
- Kept: the five domain zero-checks themselves (D, Q, Kv, S, F; "run each domain zero-check after the GKR"), the zero-sum pair in G2 and G3.
- Variants (candidates doc section 3 A table): G1 retires range and table helpers only (2,911 rows); G2 puts every lookup in the tree
  (2,591 rows); G3 also drops the 82 H mask rows (2,509 rows). The 52 ms list matches G3 (all helper inverses, all H masks).
- Added (not netted off anywhere in the REPORT): the GKR rounds themselves (about 300 rounds over a 2^25-leaf tree; the 2026-11-01
  Metal estimate is 0.040 to 0.105 s per block and no GPU GKR exists), one leaf-claim term in each domain zero-check (about 9 ms on that
  estimate), +48 to +144 M rows (M commit is 5 ms for 50 rows today), the masks and the new simulator obligations. On the 2026-11-01
  projection these added costs are the same size as the 52 to 77 ms removed, so a gross ceiling says nothing about a net gain.

### 1.2 The author's 52 ms, recomputed [R]

From the seven warm PB-TIMING blocks in `batch6_1block_m4_7warm.log`: helper inverses 17.0 ms (7 + 9 + 1), H masks and zero-sum rows
2.0, H commit 23.0, open H 10.0; per-pass sums 56, 71, 51, 52, 50, 50, 52; median 52.0, IQR 3.5. 52.0 / 268.0 = 19.4 % (the author's
19.31 % is the median of per-pass ratios); x1.241. Matches the author. The H commit split (14.001 ms GPU, 9.147 host) and the open H
split (0.081, 9.922) come from the JSON per-pass samples and re-aggregate to the stated medians. All of this is arithmetic on measured
phase times; each phase has 1 ms resolution, so the 52 ms carries about +-2 ms.

### 1.3 Counted that candidate A would not fully remove [C], small

- The 2.0 ms "H: mask rows + the zero-sum rows": the zero-sum pair stays in G2 and G3; only the 82 mask rows go (G3). At most 1 to 2 ms.
- The list is the G3 reading. In G1 (range and table helpers only) the exp/act helper inverses (9 ms) stay and 2,192 of H's 2,606 rows
  go (84 %). That gives about 7 + 1 + 0.84 x 23 + 0.84 x 10 = 36 ms (x1.15) before any slot share. The REPORT does not say which variant
  the 52 ms belongs to; the coordinator's "x1.2" should be read as the G3 case.

### 1.4 Missing: what candidate A removes that the list leaves out [R + E]

**The helper-relation work inside the 23 slots.** The 23 slots take 139 ms (IQR 5.5) [R], 65.9 ms GPU + 75.1 ms host [A, re-aggregated].
Five of them are the domain zero-checks D, Q, Kv, S, F (slots 14 to 18) and carry the helper constraint terms; slot 19 is "TAB table helper
zero-check"; slot 20 is the zero-sum row. Medians per slot over the seven warm passes [R]:

| slot | ms | role |
|---|---:|---|
| 14 D zero-check | 18 | helper terms: 10 helper columns of 37 table inputs |
| 15 Q zero-check | 9 | 3 of 15 |
| 16 KV zero-check | 5 | 3 of 15 |
| 17 softmax (S) zero-check | 11 | 4 of 19 |
| 18 F zero-check | 32 | 4 of 19 |
| slots 14 to 18 together | 74 (IQR 1.5) | |
| 19 TAB table helper zero-check | 8 | table-helper part removed by A |
| 20 ZS zero-sum row | 1 | stays in G2 and G3 |

The table counts per slot in the `tables: build` lines (18,874,368 words = 36 tables of 2^19 for slot 14; 7,864,320 = 15 x 2^19; 1,966,080
= 15 x 2^17; 9,961,472 = 19 x 2^19; 39,845,888 = 19 x 2^21) agree with the table counts (37, 15, 15, 19, 19) that the 2026-11-01
projection (`logup-gkr-20261101/projection.py`, dictionary `DOM`) used, so that attribution still applies to the HEAD shapes [R, C].

Bound on slot time due to helpers:
- **Method (E).** Take each domain slot's time times (helper columns / table inputs), exactly as projection.py does. Result: 16.5 ms
  (per pass 15.9 to 17.4; by domain D 4.9, Q 1.8, Kv 1.0, S 2.3, F 6.7). This is an estimate by table count; it is not a measurement.
- **Lower end (E).** Each of these slots runs 17 to 21 rounds, and the 2026-11-01 note measured a round-latency floor of 0.30 to 0.35 ms
  per round that does not scale with the number of tables. That floor is about 28 to 32 ms of the 74 ms, so the part that scales with
  table inputs is nearer 42 to 46 ms and its helper share 8 to 10 ms. (A27 changed the slot kernels since that measurement; the floor may
  have moved.)
- **TAB (slot 19), 0 to 8 ms (C).** The design note says only "the table-helper part of TAB" goes. Whole slot: 8 ms.

**Second ceiling, one block (gross, before candidate A's own cost):**

| Reading | removed | share of 268 ms | ceiling |
|---|---:|---:|---:|
| author's list (G3), measured | 52 ms | 19.4 % | x1.24 |
| + helper share of slots 14 to 18, low end 8 ms | 60 ms | 22.4 % | x1.29 |
| + same, table-count value 16.5 ms | 68.5 ms | 25.6 % | x1.34 |
| + whole TAB slot (8 ms) and ZS (1 ms) | 77.5 ms | 28.9 % | x1.41 |
| G1 reading (range and table helpers only), before slot share | about 36 ms | 13 % | x1.15 |

On witness plus prove (342.8 ms composite [A]) the middle row is 342.8 / (342.8 - 68.5) = x1.25 (the author's: x1.18).

**How firm.** The 52 ms is measured (n = 7, 1 ms resolution). The slot share is an estimate: table-count proportionality from a 2026-11-01
projection, applied to 1 ms slot rows, with an unquantified round-latency floor. I give "x1.29 to x1.41" as the range for A's gross
one-block ceiling; it is soft at the level of +-0.05. The raw per-slot GPU rows that could settle it (tag, table count, rounds, GPU span
per slot) were in the trace TSVs, and the author's script deletes them (`shutil.rmtree(SCRATCH_TRACES)`), so I could not bound the
helper share from measured per-slot GPU time. Request: keep the TSVs (a few MB, outside the repository).

**Other places helpers show up** [C]:
- Transcript absorption of H's root and five claim groups (about 1.3 MB of absorbed bytes per block): under 1 ms, not separable from the logs.
- Receipt: H opened columns and claim groups are about 5.1 MB of 25.6 MB per block (about 20 %). Receipt write is 0.225 s per request
  and, in the stream, it is on the admission chain (below); a 20 % cut is about 0.045 s per request. Candidates doc: codewords per request
  43.2 GB to 21.5 GB, which frees memory that could pay for a third lane.
- `A: lookup values + the byte histogram` (10 ms) and the A-side planes stay: A needs the multiplicities.

### 1.5 What A adds that is not netted off (no costing)
The GKR proving (about 300 rounds, no GPU GKR exists; 2026-11-01 CPU prototype and Metal estimate in `handoffs/20261101-logup-gkr-w16.md`),
the leaf-claim shares in the five zero-checks, and the extra M mask rows with their commitment and opening. The REPORT says "BEFORE
subtracting" but the coordination entry and the REPORT executive table present x1.18 to x1.22 as "the ceiling"; read it as a gross
bound only.

---

## 2. Provenance

- **Sources at the build [C].** `git status --short hashline zkp-core` prints nothing, but only because those directories do not exist at
  the repository root; the real tree is `ops/zkp-mvp/gpu-metal/{hashline,zkp-core,private-block-kernel,...}`. `git status --short` there
  shows untracked `results/r12-*` directories only (no modified source), `git diff --stat 2df5f72d -- ops/zkp-mvp/gpu-metal` is empty, no
  `.rs` file under hashline/src, zkp-core/src or private-block-kernel is newer than the build's `.d` file, and b809b591 touches only
  `formal/ZK60Formal.lean` and `formal/ZK60Formal/RunBlkAliveR13.lean`. The JSON records `git_head` 2df5f72d. Clean.
- **Binary [R].** `.../hashline/target/release/deps/hashline-a90b6cf7715dc2a7`, 22,951,056 B, mtime 2026-11-17 11:10 UTC; I re-hashed it:
  sha256 aaaab7e6fd38af59d406f201f94cfdb0325a3fe6adb3a04332873580f3acad11, equal to the JSON and REPORT. Built by guard run 75ef1a77331c
  (`cargo test --release --offline --locked -j 2 --features gpu-metal --lib --no-run`, 170.8 s, exit 0). The guard record's `cmd` list is cut
  after `--features`; the retained (shortened) build log shows `"features":["gpu-metal"]` on the compiler-artifact line. **Note:** this is
  the same file name as the 2026-11-06 binary that Batch 5 used (cargo reuses the name), so the old binary was overwritten and the Batch 5
  profile can no longer be re-run or A/B'd against HEAD.
- **Environment [C, from the guard commands].** One block: `HL_GPU=1 HL_GPU_REQUIRED=1 HL_PB_ORACLE=0 HL_PB_TIMING=1 HL_METAL_TIMING=0
  HL_M4_PHASES=1 HL_M4_WARM_PASSES=7 HL_M4_PROFILES=W16R2_8B_T128_H24 HL_A27_GPU_TRACE=<scratch>`. Stream: `HL_GPU=1 HL_GPU_REQUIRED=1
  HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32 HL_A22_AB_PASSES=6
  HL_A22_AB=serve1|serve4 HL_A27_GPU_TRACE=<scratch>`. `HL_METAL_TIMING=0` is what the repository's own comment prescribes for timing runs
  (`run_fork_tests.rs:36-40`: "never with HL_METAL_TIMING=1"); Batch 5 used 1 (finding 3).
- **CPU against Metal digest [R].** `batch6_1block_m4_7warm.log` has 8 lines "digest cpu 90003b76... metal 90003b76..." (1 cold + 7 warm), all
  identical (`grep -c` = 8). The CPU pass is in the same process (2.412 s). Stream: "all 4 receipts verified from their run directories,
  818728672 B each" for serve4 pass 0 and "all 1 receipts verified" for serve1 pass 0 and the cold request. The stream logs have no CPU
  digest comparison; they verify receipts.
- **Tracing on while timing [C].** `HL_A27_GPU_TRACE` formats one line per completed command buffer under a mutex (`metal.rs:998-1014`),
  after the buffer completed; no untraced control run exists on HEAD, so its effect is unmeasured (expected microseconds per buffer).

## 3. Method

- **GPU busy [C].** The trace records, per command buffer, the host begin and commit times and Metal's `GPUStartTime` and `GPUEndTime`
  (`metal.rs:926-932, 998-1014`). `gpu_busy_interval` in `run_batch6_guarded.py:207-243` keeps buffers with `gs > 0 and ge >= gs`, builds
  a +1 / -1 event list from `[gs, ge]` clipped to the window, sorts by (time, -delta), and adds the time at which depth > 0: a true interval
  union on GPU start and end times. Host = pass wall minus that union, so it still includes all waits, encode, commit-to-start latency and
  the host's own work ("host between command buffers" is a fair label). For one block the union equals the sum of spans (no concurrency):
  per pass, A commit + H commit + slots + open A + open H GPU equals the union to within 0.003 ms [R], so no other buffer is hiding in the window.
- **Passes [R].** One block: 1 cold + 7 warm in one process, cold excluded (`metal_pb[1:]`), all in one log. The seven warm prove-core
  times are 296, 285, 268, 267, 270, 259, 266 ms (median 268, IQR 11). The first two are still settling (mean 290.5 against 266.0 for the last five);
  the last five have IQR 2 ms. The median is fine; the IQR 11 is a warm-up trend, not noise. Stream: each arm one process, cold request
  excluded, 6 warm passes (serve4: 4 requests each), medians from the raw `A22-AB REQ` lines. The two arms ran in separate processes in a
  fixed order (serve1 then serve4), not interleaved; the unoverlapped request 0 of serve4 has the same sealing time as serve1 (2.143 against
  2.172 s), which supports comparing them.
- **Recomputation of every headline [R].** Matches, except as listed:

| quantity | author | mine |
|---|---:|---:|
| prove core, median / IQR | 268.0 / 11.0 | 268.0 / 11.0 |
| GPU busy, median / IQR (JSON samples) | 93.482 / 1.260 | 93.482 / 1.260 |
| GPU share | 35.12 % | 35.12 % (median of per-pass ratios; 93.482/268 = 34.88 %) |
| host (wall - union) | 172.974 | 172.974 (median of per-pass differences; difference of medians 174.518) |
| Candidate A removed | 52.0 (3.5), 19.31 %, x1.24; x1.18 on 342.8 | same ([R], section 1.2) |
| serve1 wall per request / tok/s | 6.093 s / 21.01 | 6.0925 / 21.01 |
| serve1 sealing pass, share | 2.172 s, 35.6 % | 2.1715, 35.64 % |
| serve4 steady cadence / tok/s | 3.606 s / 35.50 | 3.6057 / 35.50 |
| serve4 prove call, forks, sealing (means of 4 per pass) | 3.697, 3.386, 3.054 | 3.6971, 3.3862, 3.0539 |
| serve4 amortized | 4.309 s, 29.71 tok/s | 4.3087, 29.705 |
| forks request 1 to 2 against request 3 | 3.409 / 3.207 (+0.156) | 3.4093 / 3.2065 (+0.156) |
| GPU busy union, serve1 / serve4 steady | 2.885 s (47.09 %) / 2.663 s (73.68 %) | **not recomputable (raw TSVs deleted); code read, formula sound** |

  Small points: 93.482 + 172.974 = 266.456, not 268.0 (medians of separate series; harmless). The window anchor for the stream union uses the
  last buffer's completion time as the last request's prover end (`t0_host` in `parse_a22_stream`); the prover's join phase after the last buffer
  makes this off by at most tens of ms of an 11 s window [C, NC to measure].
- **JSON against REPORT [R].** Every Batch 6 value I compared agrees. The H share of non-witness GPU spans is 13.33 % (serve4) and 13.88 % (serve1).

## 4. Quiet machine [R + A]

Guard history: build 75ef1a77331c ended 11:10:38Z (wall 170.8 s, so it started about 11:07:47Z); one block 2667991f6da8 ended 11:11:30Z (39.9 s,
about 11:10:50Z to 11:11:30Z); stream ba52f58399f4 ended 11:14:41Z (179.0 s, about 11:11:42Z to 11:14:41Z). The one other guarded job nearby,
`claude-l64-review-kernel` (class cpu, 4.4 s), has `ts_end` 10:55:10Z, 16 minutes before the build starts; it did not overlap any window.
The next guarded job, `agy-lean-l64-docfix-build` (14.6 s), ended 11:18:00Z, after the stream. `waited_s` was 0.0 to 0.1 on all three, the
heavy lock was held by the author's job. Peak RSS 4.46, 3.82 and 31.92 GiB; peak VRAM 4,317 and 22,067 MiB.
**ds4-bench quiet:** the evidence is the script's own `pgrep -fl ds4-bench` at the start and end of each leaf, stored in the JSON
(`quiet_gpu_checks`: four entries, all `quiet: true`, 0 polls waited). Nothing samples GPU use during the runs (the serve4 arm runs 125 s
between checks), and unguarded light work cannot be excluded from the retained files. Reasonable, not proven; the guard JSONs carry no
quietness field beyond `gpu_drain_failed: false`.

## 5. The stream argument

**Numbers.** All stream numbers recompute (section 3). The "18 of 18" claim holds as defined: for every steady request the sealing side
finished before the previous request's prover ended (`max(0, seal_done(q) - prover_end(q-1))` is 0.000 for all 18) [R].

**But the margin is thin, and the log's own column says so.** The log's `waited` field is (prover start - sealing done); for the 18 steady
requests it is 0.416, 0.110, 0.182, 0.482, 0.127, 0.055, 0.588, 0.132, 0.141, 0.413, 0.098, 0.146, 0.558, 0.132, 0.124, 0.458, 0.127, 0.129 s: median
0.137 s, 3.8 % of a prove call. Requests 2 and 3 (12 of the 18) have only 0.055 to 0.182 s of slack. The pipeline is almost exactly balanced today.

**The 3.054 s is not a floor, for three reasons [R].**
1. It is the mean of the four requests' sealing passes in a pass, and request 0 (2.143 s, nothing running beside it) is one of the four. The
   overlapped passes (requests 1 to 3, 18 values) are 3.321 s (IQR 0.145; min 3.135, max 3.553).
2. The stream has two lanes (the STREAM line says "lanes 2"): request q's sealing turn is the result time of request q-2 (12 of 12 pairs I checked
   agree within 2 ms; the sealing turn of request 1 equals the sealing completion of request 0; the prover of request q starts at the
   previous prover's end). So the chain that can limit the cadence is `S + W + P` over two requests, where S is the sealing pass, W the
   receipt write and P the prove call, not S alone. Cadence = max(P, (S + W + P)/2). With today's steady numbers (S 3.321, W 0.225, P 3.626)
   the two branches are 3.626 and 3.586: both close to the measured 3.606. Cutting P by 0.657 s with S unchanged gives
   (3.321 + 0.225 + 3.043)/2 = 3.295 s, which is x1.09 on the cadence, not x1.22.
3. S itself is slowed by the overlap: 2.172 s alone against 3.321 s beside the prover (x1.53); request 0, which has no prover beside it, is
   2.143 s. A shorter prove call shortens the overlapped part. A simple model (sealing runs at 1/1.53 speed while the prover runs and at solo speed
   after; it reproduces 3.321 s at today's P) gives S falling to about 3.15 s for the author's P, a cadence of 3.207 s: x1.12.

**Ceiling I can support for the stream (gross, before A's own cost) [R, with the model above, E].**

| removal assumed (share of the forks time) | sealing unchanged | overlap model | sealing fully follows (no floor) |
|---|---:|---:|---:|
| 13.3 % (H's share of GPU spans in the stream) | x1.06 | x1.08 | x1.11 |
| 19.3 % (author's list; share of the solo block) | x1.09 | x1.12 | x1.19 |
| 21.9 % (H's host share of the solo block) | x1.11 | x1.15 | x1.22 |
| 25.6 % (author's list + helper share of slots 14 to 18) | x1.13 | x1.18 | x1.27 |
| 28.9 % (also whole TAB slot) | x1.15 | x1.21 | x1.33 |

Reading: **x1.09 to x1.19 on the author's list (middle x1.12); x1.13 to x1.27 with the helper slots (middle x1.18).** The author's
"x1.18 to x1.22" sits at the top of the first range and rests on a wrong floor. What moves the figure: (a) how the block's share converts to
the forks wall (the author assumes 19.4 %; 13 % to 22 % are defensible from the GPU-span and host shares; this is an assumption, not a measurement),
(b) whether sealing speeds up when the prover shortens, (c) the number of lanes: the arm label accepts `lanesN` and A frees about 21 GB of codewords
per request, so a third lane (not measured) lifts the sealing chain to (S + W + P)/3-ish and removes the floor, (d) which A variant (G1 or G3).
All of it before A's own cost.

## 6. The 337 ms to 268 ms attribution (A27, A28, A30): asserted, and probably confounded

- Evidence offered: none beyond the sentence. The old binary was overwritten (section 2), so no A/B exists.
- Phase by phase, Batch 5's last warm pass (`rust_m4_8b_pbtiming.log`) against the Batch 6 median [R]: A commit 58 to 22 ms (-36), H commit 41 to 23
  (-18), the 23 slots 148 to 139 (-9; slot 18 -4, slot 13 -2), A allocate -4, byte histogram -2, exp/act inverses -3; everything else within 1 ms.
  So **54 of the 69 ms are the two commit phases**.
- **The Batch 5 M2 run set `HL_METAL_TIMING=1`** (guard record `agy-batch5-m2-h127-hostshare`, `run_batch5_guarded.py:296`). In
  `metal.rs:2147-2155` that switch makes the commitment function re-run its GPU parts one by one on freshly allocated scratch buffers
  ("DIAGNOSTIC ONLY: the same GPU parts re-run") inside the same call, so it inflates exactly the A and H commit phases. Batch 6 used 0.
  Other differences: 7 passes against 1, trace on against off, a shared box three seconds after a 98 s CPU test (Batch 5 review).
- A30 (`10f1071b`, 2026-11-12) changes `private_block.rs`, `run.rs`, `token_io/*` (the classifier and a table digest); nothing in `gpu/`, `protocol.rs`
  or `argument.rs` [C, from the commit's file list]. I found no path from it to the 38 timed phases. A27 and A28 are plausible for commit work
  (A27: NTT head and tail two stages per pass; A28: pruned forward transform and two-pass hash), but their own commit messages claim -9 % commit GPU
  time (A28), not -62 % of commit wall.
- Consequence: the sentence should be withdrawn or marked untested; the Batch 5 M2 profile (host share, 414.1 ms composite, the H127 buckets)
  was taken under a diagnostic that inflates commits and is superseded by Batch 6, which is the better baseline.

## 7. Candidate E fold

- **Section 6 of the candidates document asks for** (row E, with my GPU_FRIENDLY_REVIEW section 5, G1): an INT8-limb fold against the production fold,
  full 64-bit operands, word for word over a whole 8B block, at least 30 repeats on a quiet box; pass = every word equal and at least x1.5 end to end;
  kill = any word differs or below x1.2.
- **Grep [C].** No such kernel exists: `fold` appears 0 times in `metal_int_gemm.mm` and `metal_batched_llama8b.mm`; the only fold kernels in the
  hashline tree are the production Goldilocks kernels (`k_fold_rows`, `k_fold_partial`, `k_fold_reduce`, `k_fold_tables*`); `microbench_metal_gpu.mm`
  Test 1B is a 24-bit, FP32, 3 x 3-slab mock (my GPU_FRIENDLY_REVIEW already marked it invalid as an exactness claim). The author's
  "no exact-integer fold kernel exists" is correct.
- **The added reason is wrong [C].** The REPORT says the production fold is negligible because `devfold + gather` is 0.094 + 0.081 = 0.175 ms per block.
  The device fold (`fold_rows_device`, the only place the `devfold` tag is produced) runs only when `HL_METAL_DEVICE_FOLD=1`; by default the opening's
  fold runs on the host ("the host fold over the shared buffer is the default: measured on the 8B T128 block it beats the device fold",
  `metal.rs:1288-1296`). Batch 5's own log shows that host fold: "store fold with pads (Small) ... 0.0053 s" for A and "0.0059 s" for H, about 11 ms per
  block, roughly 4 % of the prove core and about half of the host share of open A plus open H (25 ms). The 0.175 ms is, as far as I can tell, the `gather`
  buffers only; the `devfold + gather` label in the REPORT and JSON does not match what ran (the raw TSVs that would show the tag counts are deleted).
  Dropping E's fold half for lack of a kernel is a fair statement; dropping it because the fold costs 0.175 ms is not. The host fold is a real
  target (about 11 ms per block), and the candidate-E experiment as defined was not run.

## 8. Batch 5 corrections, F1 to F13 (BATCH5_REVIEW.md)

| ID | Asked | REPORT.md | H132_H128_H127_METRICS.json | Status |
|---|---|---|---|---|
| F1 | H132 FAIL on sk4 K = 1 baseline (0.887, 0.832) | Applied: executive row and section 4 give 0.887 / 0.832 and "FAILS" | the sk4 flag is false as before; the sk1 and stage2 flags still say true with no note; no verdict field | Applied (REPORT); JSON partly |
| F2 | D80a not unblocked; slower kernel is the answer asked; Amdahl x1.009 to x1.02 | Applied: "D80a NOT unblocked", 0.56x / 0.67x stated. Amdahl text says "3.85 ms saved out of about 343 ms" but keeps the 1.009x low end of the 414 ms base (343 gives 1.011x) | n/a | Applied, one stale figure |
| F3 | Census caveats | Applied: fallback prompts, flat 450 against 342, classes C and M not measured, "does NOT settle" | no field records the fallback prompts (only `sequences: 2`) | Applied (REPORT); JSON partly |
| F4 | Rust A4 row: do not mix min and means; shape; drop 1.875x | Applied on the HEAD log (best of 30 = 14.3 ms kept apart from component means summing to 17.31 ms); 1.875x gone | raw lines retained | Applied |
| F5 | Do not headline 1.754x / 2.090x | Applied: rows labelled "Scope B mixes 1 vs 7 cb" | summary keys named with cb counts | Applied |
| F6 | Arbitrary int16 about 1.03x | Applied (row 3, table row). One cell error: the sk1 int16 7-cb GPU figure 8.255 is the 1-cb value (JSON 7-cb is 8.2815; ratio 1.065 not 1.068) | | Applied, one new small error |
| F7 | Stale binary; harness faster than Rust log unexplained | Applied by rebuilding for Batch 6 and re-running the Rust A4. The harness-against-Rust gap is not mentioned: HEAD Rust A4 GPU mean 10.27 ms against the harness 8.807 ms (17 % higher) | | Partly applied |
| F8 | M2 n = 1, subtraction, upper bound, composite; H127 bucket judgement | M2 replaced by n = 7 with command-buffer union (good). H127: "Closed / small, not robust to bucket choice" with 12.8 % in brackets; the cycle-2 10 % line is not reconciled | verdict still "KILLED under both definitions"; 414.1 composite only inside the stale-note text | Partly applied |
| F9 | Verification scope | Applied (section 2 items 2 and 3, section 4 header "sequential mode blocks, n = 8..16") | | Applied |
| F10 | Stale numbers (1a to 1c, 1e) | Applied: 17.860 / 0.357, 7.515 / 0.181, IQRs 0.512 and 0.503 checked against the JSON | note text now 127.4 / 37.8 % and so on | Applied |
| F11 | fp16 baseline caveats; mechanism claims | fp16 and "tok/s" caveats applied. "Why the gain appears" still gives mechanisms (FAST_WS = 65 padding, barrier cadence); the .mm header still says "0 register spills", "bank-conflict-free"; no compiler or profiler evidence added | | Partly applied |
| F12 | Do not commit the dylib | Applied: absent, build command in the REPORT header. `__pycache__` also absent | | Applied |
| F13 | Note (the things that checked out) | Nothing to apply; the shader-identity statement and n = 32 interleaving are kept. The author lists F1 to F12 only, which is correct for a Note | | Not applicable |

Directory check [C]: no binary, no `.dylib`, no `__pycache__`; `git check-ignore` confirms `__pycache__/` is ignored and `.dylib` is not (so
its absence matters; nothing in `.gitignore` guards it). No credential, token or personal data found by grep. Everything is untracked
(`?? results/zk60_h132_batched_forward_20261116/`). Items that should not or need not go in the commit: three zero-byte logs
(`agy-batch5-m2-h127-hostshare.log`, `agy-batch6-head-1block.log`, `agy-batch6-head-stream.log`); `agy-batch6-head-build.log` (44 KB, the last 30
lines of cargo's JSON, of little use). `run_batch6_guarded.py` hard-codes `/Users/victorrielly/.gemini/antigravity-cli/brain/<session id>/scratch`
(a home path and an agent session id; low). Suggested commit set: the `.mm`, the `.py` scripts, REPORT.md after the corrections below, both JSONs,
the Batch 6 and Batch 5 logs that carry numbers.

---

## Findings list (for the coordinator)

| ID | Level | Finding |
|---|---|---|
| G1 | High | Removal list omits the helper-relation work in the 23 slots: helper terms of the five domain zero-checks (estimate 8 to 17 ms by table count) and the TAB slot (0 to 8 ms). One-block gross ceiling is x1.24 on the measured list and about x1.29 to x1.41 with these (estimate; the per-slot traces that could measure it were deleted). |
| G2 | High | The stream "3.054 s floor" is a mean that includes the unoverlapped request 0; overlapped sealing is 3.32 s; the stream has two lanes so the sealing chain is (S + W + P)/2, not S; S is slowed x1.53 by overlap and shortens with P. Supported stream ceiling x1.09 to x1.19 on the author's list (x1.13 to x1.27 with helper slots), not x1.18 to x1.22. The pipeline slack today is only 0.14 s (median). |
| G3 | High | The 337 to 268 ms attribution to A27/A28/A30 is unsupported. 54 of the 69 ms are in the commit phases, and the 337 ms run used `HL_METAL_TIMING=1`, which re-runs commit GPU parts on scratch buffers. A30 touches no code on the timed path. The old binary was overwritten, so no A/B is possible. The Batch 5 M2 profile was inflated; Batch 6 supersedes it. |
| G4 | Medium | Candidate E fold: "no kernel exists" is right, but the supporting figure (0.175 ms) is the GPU time of the gather buffers; the production fold runs on the host by default (about 11 ms per block, about 4 % of the prove core, from Batch 5's log). The `devfold + gather` label does not match what ran. The experiment section 6 defines was not run. |
| G5 | Medium | The 52 ms list is the G3 reading (all helpers, all H masks). Under G1 it is about 36 ms (x1.15) before the slot share. The REPORT does not say which variant it prices; the 2 ms of H mask and zero-sum rows is partly retained. |
| G6 | Medium | Conversion from block share (19.4 % of the solo prove core) to the stream forks wall (19.4 % of 3.386 s) is assumed. In the stream H is 13.3 % of GPU spans, and in the solo block 21.9 % of host time; the supportable range is 13 % to 22 %. |
| G7 | Medium | Gross removal is not a gain estimate: the 2026-11-01 estimates of A's own cost (GKR 40 to 105 ms per block on Metal, leaf-claim terms about 9 ms, +48 to +144 M rows) are the same size as the 52 to 77 ms removed. The REPORT and the coordination entry headline x1.18 to x1.22 without that caveat in the headline row. |
| G8 | Medium | GPU-busy figures for the stream cannot be re-checked from the retained files: the raw trace TSVs are deleted by the script. The formula is sound by reading; one-block sums of GPU buckets equal the union to 0.003 ms [R]. Tracing was on during timing and there is no untraced HEAD control. |
| G9 | Low | IQR 11 ms for the one-block prove core is a warm-up trend (296, 285 ms in the first two warm passes; last five IQR 2 ms). |
| G10 | Low | Medians of separate series do not add (93.482 + 172.974 = 266.456 against 268.0); GPU 35.12 % is a median of ratios (34.88 % of medians). |
| G11 | Low | REPORT 3A: sk1 arbitrary-int16 7-cb GPU "8.255" is the 1-cb figure (7-cb is 8.2815; 1.065x not 1.068x). Amdahl low end 1.009x is on the 414 ms base while the text uses 343 ms (1.011x). H127 JSON verdict "KILLED under both definitions" not updated. Mechanism claims (0 spills, bank conflicts) still unsupported. |
| G12 | Low | Hygiene: three zero-byte logs, a build log cut to 30 cargo-JSON lines, a home path with an agent session id in the script. No binary, no secret. |
| N1 | Note | Checked and fine: HEAD source provenance (clean, empty diff, binary hash re-computed), 8 of 8 CPU = Metal digests, feature gpu-metal, no overlapping guarded job in either window, all headline numbers recompute, receipts verified in the stream, union formula, 18 of 18 claim as defined. |

## What I did not check

- The raw GPU intervals: deleted by the author's script, so the union and the per-bucket spans are as the author's code produced them.
- The REPORT's statement that in `m4_trained` "477 - 337 = 140 ms was verify and digest while `wit()` ran before the timer" (a code claim in
  section 5 header); and the Batch 5 M1 and H132 numbers beyond the cells touched by the corrections (spot-checked 3A and 3B against the JSON).
- Whether `ds4-bench` or any unguarded process used the GPU during the runs (only the author's start and end `pgrep`).
- Any effect of the trace being on, any thermal effect of order or fixed arm order in the stream.
- The helper share of the slots by measurement: only the 2026-11-01 table-count attribution, applied to 1 ms slot rows.
- The G1 retained-rows arithmetic (84 %) uses the census counts of the candidates document applied to H = 2,606 rows; I did not re-run the census.
- The Lean part of the coordination entry.

## Suggested corrections before the numbers are used for the decision

1. Replace "ceiling x1.18 to x1.22" with the stream and one-block ranges above, labelled gross and variant G3; add the helper-slot estimate, flagged as
   estimate; state that A's own cost (GKR, leaf claims, M rows) is of the same size.
2. Withdraw the A27/A28/A30 sentence or mark it untested; note the `HL_METAL_TIMING=1` confound for the Batch 5 M2 profile.
3. Re-state the candidate E fold reason (host fold about 11 ms per block; no INT8-limb kernel exists; experiment not run).
4. Keep the trace TSVs (compressed, outside the repository) and, if the helper share matters for the decision, one measured run per slot (the retained
   trace already has the slot label, table count and rounds per buffer); a `lanes3` serve arm would measure how much of the floor is the admission window.
