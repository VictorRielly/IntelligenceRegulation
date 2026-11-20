# Is the stream's prove call GPU-bound? Prover GPU time by phase, from the kept Batch 7 traces

Author: Claude (analysis from existing files only: no run, no build, no GPU, no git write). Date: 2026-11-17.
Scripts (standard library only, they print their tables, outputs kept beside them as `*.out.txt`):
`/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/stream_gpu_phases/` (`run_all.py` runs all of them in about a minute).

Labels: **RECOMPUTED** (from the named trace, with n), **CODE-READ** (from `metal.rs` or a committed note), **MODEL** (arithmetic on measured numbers, not a measurement), **NOT SHOWN** (cannot be settled from these files).
All figures are medians over the warm passes; the cold request and start-up buffers are excluded (n is stated in each table). "P" is the prove call from the log (preflight + commit phase + forks + join).

## 0. Answer in short

**The stream's prove call is mixed, with the GPU as the larger and harder constraint. It is not host-bound, and it is not purely GPU-bound.**

| | serve1 (n=6) | serve4 beside a sealing pass (n=18) | serve4 last request, nothing beside (n=6) | serve6 beside (n=30) |
|---|---:|---:|---:|---:|
| prove call P | 3.662 s | 3.809 s | 3.512 s | 3.889 s |
| prover GPU-busy union inside P | 2.508 s (68.1 %) | 2.688 s (70.8 %) | 2.501 s (70.7 %) | 2.674 s (69.4 %) |
| no prover buffer executing (host-only) | 1.168 s (31.9 %) | 1.109 s (29.2 %) | 1.014 s (29.3 %) | 1.193 s (30.6 %) |

(P for requests 1..3 of serve4, the convention behind "3.70 s", is 3.700 s, n=18; the request 0 prove call is the slowest, 4.02 s.)

1. **The GPU is saturated while it is busy** (about 70 to 78 % of the call). A buffer's execution span stretches with the number of buffers overlapping it (commit A 13.4 ms alone, 43.4 ms at depth about 3; slots about 2.1x), and the whole set of spans is 2.15x what the same buffers take alone while the mean depth is 2.4, so overlapping buys only 1.11x (beside sealing) to 1.19x (nothing beside) over running the buffers back to back at their solo speed. "GPU busy" therefore means nearly full, not "has headroom".
2. **Host-only time is still 29 to 32 % of the call (1.0 to 1.2 s)** and host work can only remove that. It sits in a serial start phase (0.25 to 0.37 s), a serial join (0.08 s) and about 0.7 s of gaps inside the fork region where all six forks are on the host together.
3. **Two floors for P (MODEL):** (i) host-only time gone, today's overlap kept: 2.50 s (nothing beside) to 2.69 s (beside sealing). (ii) GPU work serialised at solo speed: 2.98 s (equals 32 x 93.48 ms = 2.99 s from the one-block log). The target 2.56 s is below floor (ii), and at or below floor (i). Reaching it needs GPU work removed as well as nearly all idle time removed.
4. **Prover GPU time by phase** (serve4 beside, share of the 2.69 s union, equal-split attribution): commit A 19.3 %, commit H 14.9 %, domain zero-check slots 14 to 18 together 49.5 % (slot 18 alone 20.6 %, slot 14 13.6 %, slot 17 7.5 %, slot 15 4.7 %, slot 16 2.7 %), slot 19 3.7 %, the other sumcheck slots 11.5 %, openings (GPU gather) 0.4 %, small commits 0.4 %.
5. **Candidate A in GPU terms:** H commit plus H open are 15.2 % of the prover GPU union (0.41 s) (measured). With a modelled helper share of slots 14 to 18 and of the TAB slot, 20.6 % to 29.9 %. If the call is GPU-bound, P falls by the removed union: x1.12 (measured part only) to x1.28 (all modelled parts), before A's own added cost (not measured, not estimated here). On the two-lane cadence with S held at 3.35 s that is x1.08 to x1.14.

## 1. Inputs, anchoring, definitions

Inputs [read, not changed]: the three Batch 7 traces `serve1_6warm.15048`, `serve4_lanes2_6warm.15818`, `serve6_lanes3_6warm.16734` (`.tsv.gz`, 1,799 / 5,831 / 8,519 witness rows plus 4,064 / 14,558 / 21,548 non-witness rows), the three Batch 7 logs, `BATCH6_HEAD_PROFILE_METRICS.json` and `batch6_1block_m4_7warm.log` (one block alone), `results/zk60_effplan_20261105/a7/README.md`, `metal.rs`. Two unsampled Batch 8 serve1 traces (`a1_default`, `a2_default`) are used as a replication check only (section 12).

**Owners.** Witness = queue 99, tag `wprod`. Prover = every other row (all on queue 0; 4,064 rows in serve1 = 7 prove calls). Execution span of a buffer = `gpu_end - gpu_start` (Metal GPUStartTime / GPUEndTime, host clock).

**Splitting the prover rows into requests [RECOMPUTED].** Prove calls do not overlap. Each call starts with a serial run of exactly 31 small commits (`commit rows=38`), so request k starts at its first such commit (217 / 31 = 7, 775 / 31 = 25, 1,147 / 31 = 37 calls including the cold one; every call has exactly 32 A and 32 H commits). A first attempt that cut on the big commits mis-assigned the 31 small commits to the previous request; the final split is checked against the log (below).

**Prove-call window [RECOMPUTED].** S = first `rows=38` commit begin minus the log's preflight (1 to 2 ms); E = S + the log's prove call. Check (`anchor.py`): the first prover buffer begins 1 to 2 ms after S (max 5 ms); the last prover buffer ends 6 to 11 ms before E (max 26 ms once); the stream-clock origin implied by S differs from the one implied by the first witness buffer by a median of 0.3 to 3 ms (range -17 ms to +4 ms over the 69 requests, the extremes being the cold requests and a few others; the witness anchor includes the host prelude of the first product). The window edges are good to a few ms of a 3.7 s call.

**Steady window for item 1a** is the Batch 7 review's: `[result(0), result(R-1)]` per pass, divided by R-1 requests (serve4, serve6); for serve1 the whole request. My unions reproduce the review's 2.6487 / 2.6822 s (mine 2.649 / 2.682).

**Equal-split attribution** (used for "share of the union"): every instant with d prover buffers executing gives 1/d of its length to each of them, so the labels' shares add to exactly the prover's GPU-busy union. "Sum of spans" counts overlap twice; "own union" is the union of one label's spans.

## 2. What the trace labels mean [CODE-READ, `ops/zkp-mvp/gpu-metal/hashline/src/gpu/metal.rs`]

One row per completed command buffer (`tl_record` 924, `trace_write` 999). A tag is set at the call site; a detail string adds shapes only.

| tag (seen in these traces) | call site | one buffer is | detail | per prove call |
|---|---|---|---|---:|
| `commit` | `run_tagged(c, "commit", ...)` 2097 | inverse NTT of every row, forward NTT with the ZK pads (RS encoding), column leaf hash (`encode_fused`, `encode_hash`), all in ONE buffer; the upper Merkle levels are on the host and not in the trace | `rows=` `log_n` `log_nn` `zk` `keyed` | 32 with rows=2504, 32 with rows=2606, 31 with rows=38, 2 with rows=37 |
| `gather` | `gather_columns_device` 1448-1465 | the opened columns gathered (`k_gather_cols`); the opening's row fold and audit are on the host by default (`device_fold_on` is false unless `HL_METAL_DEVICE_FOLD=1`, line 1480; no `devfold` row in any trace) | `rows=` `nn=` `cols=` | 32 + 32 (rows 2504, 2606), 31 + 2 small |
| `batch` | `run_tagged_pre(cx, "batch", ...)` 4029 | ONE whole sumcheck slot: the deferred table build (`pre=` tables, the `tables` encoder of the same buffer), all rounds, the device fold of each round, the Fiat-Shamir step | `slot N (name) at path: tables, nodes, terms \| k m log_cap deg de nd n_vars recover pre` | 12 of the 23 slots run on the GPU in every block (0, 1, 3, 4, 14 to 19, 21, 22); slots 13 and 20 appear in a few buffers |
| `wprod` | 4857-4858 | one witness product of the sealing pass, queue 99 | `t k n in_out` | 224 per request (7 per block) |

Not present in these traces: `round`, `fold`, `tables`, `devfold`, `diag`, `other`, `test`.

What the labels can and cannot separate:
- **A against H: yes, exactly,** by `rows=`: A is the 2,504-row matrix, H the 2,606-row one (the two sizes the Batch 6/7 scripts also call A and H).
- **Commit against open: yes, per matrix.** Commit buffers are `commit`; the only GPU part of an opening is the `gather` buffer (0.1 ms). The rest of an opening is host and is not in the trace.
- **Inside a commit buffer, NTT against hash: no.** One buffer, no per-kernel label. Merkle upper levels: host, not shown.
- **Sumcheck: per slot, yes; per phase inside a slot, no.** The label is per phase (per slot), not per kernel. Table build, rounds and folds of one slot are one buffer. So the helper-constraint terms that candidate A removes from slots 14 to 18 cannot be separated by measurement; section 8 uses a stated model.
- **Helper inverses and H masks are not on the GPU.** No buffer type for them exists in the trace (tags above), and the Batch 6 one-block phase table lists them as host phases (17 ms and 2 ms). So they only matter through host-only time.
- **The 38-row and 37-row commits are not identified by the labels.** Counts only (31 per call, one per 32-block boundary by count; 2 per call, issued by the sealing side near the end of its pass, so they fall inside the previous request's prove window). Their GPU time is 0.3 ms each.

## 3. Item 1: GPU-busy union by owner

**1a. Per steady request [RECOMPUTED, n = 6 passes each, medians; window per request in brackets].**

| | serve1 (6.188 s) | serve4 (3.668 s) | serve6 (3.739 s) |
|---|---:|---:|---:|
| GPU busy union, any owner | 2.881 s (46.7 %) | 2.649 s (71.9 %) | 2.682 s (71.2 %) |
| prover only | 2.509 s (40.7 %) | 2.357 s (64.0 %) | 2.379 s (63.0 %) |
| witness (queue 99) only | 0.370 s (6.0 %) | 0.028 s (0.8 %) | 0.055 s (1.5 %) |
| both executing at once | 0.000 s | 0.264 s (7.2 %) | 0.244 s (6.5 %) |
| neither (GPU idle) | 3.304 s (53.3 %) | 1.027 s (28.1 %) | 1.081 s (28.8 %) |

Note on the witness row: the window holds R-1 prover calls but only R-2 sealing passes (the last prove call has no sealing beside it), so 0.293 s per window-request is about 0.44 s per overlapped sealing pass (section 11).

**1b. Inside the prove-call window [S, E] [RECOMPUTED].**

| class (n calls) | P | prover busy | host-only | witness only | both | neither |
|---|---:|---:|---:|---:|---:|---:|
| serve1, solo (6) | 3.662 | 2.508 (68.1 %) | 1.168 (31.9 %) | 0 | 0 | 1.168 |
| serve4, requests 0..2, sealing beside (18) | 3.809 | 2.688 (70.8 %) | 1.109 (29.2 %) | 0.051 | 0.378 | 1.054 |
| serve4, request 3, last (6) | 3.512 | 2.501 (70.7 %) | 1.014 (29.3 %) | 0 | 0 | 1.014 |
| serve6, requests 0..4, beside (30) | 3.889 | 2.674 (69.4 %) | 1.193 (30.6 %) | 0.086 | 0.391 | 1.098 |
| serve6, request 5, last (6) | 3.516 | 2.511 (71.5 %) | 1.009 (28.5 %) | 0 | 0 | 1.009 |

"Host-only" = no prover buffer executing (it includes the 0.05 to 0.09 s in which only a witness buffer runs). Fraction of the prove call with at least one prover buffer executing: 68 to 72 % in every class. Fraction with none: 28.5 to 31.9 %.

## 4. Item 2: prover GPU time by label (serve4, requests 0..2, n = 18; prover union U = 2.688 s)

[RECOMPUTED `labels.py`; ms per prove call, medians; the serve1 and serve6 shares are in the last two columns]

| label | buffers | sum of spans | equal-split share | % of U | serve1 % (n=6) | serve6 % (n=30) |
|---|---:|---:|---:|---:|---:|---:|
| slot 18 F zero-check (hosts 13G, 13U) | 32 | 1404 | 554 | 20.6 | 19.8 | 20.8 |
| commit A (2504 rows) | 32 | 1116 | 515 | 19.3 | 21.1 | 19.3 |
| commit H (2606 rows) | 32 | 876 | 403 | 14.9 | 15.0 | 14.9 |
| slot 14 D zero-check (hosts 12, 13D) | 32 | 952 | 365 | 13.6 | 14.1 | 13.7 |
| slot 17 softmax zero-check | 32 | 522 | 202 | 7.5 | 8.2 | 7.8 |
| slot 15 Q zero-check | 32 | 344 | 127 | 4.7 | 4.7 | 4.7 |
| slot 19 TAB table helper | 32 | 233 | 98 | 3.7 | 3.4 | 3.8 |
| slot 00 row sums norm_a | 32 | 217 | 86 | 3.2 | 3.4 | 3.2 |
| slot 16 KV zero-check | 32 | 187 | 72 | 2.7 | 2.6 | 2.7 |
| slot 04 masked row sums + selector | 32 | 146 | 69 | 2.6 | 1.7 | 2.3 |
| slot 01 row sums norm_m | 32 | 119 | 52 | 1.9 | 2.2 | 2.0 |
| slot 03 limb zero-check | 32 | 78 | 38 | 1.4 | 1.3 | 1.5 |
| slot 22 IO-out endpoint equality | 32 | 66 | 30 | 1.1 | 0.8 | 1.0 |
| slot 21 IO-in endpoint equality | 32 | 61 | 27 | 1.0 | 0.9 | 1.0 |
| small commits (rows 37/38) | 33 | 15 | 11 | 0.4 | 0.6 | 0.6 |
| gathers A and H (the GPU part of the openings) | 64 | 17 | 10 | 0.4 | 0.3 | 0.4 |
| slots 13 and 20 (a few buffers) | 2 to 3 | 9 | 3 | 0.1 | 0.0 | 0.1 |
| total | | 6361 | 2663 | | | |

Roll-ups (share of U, serve4 / serve1 / serve6): A commit 19.3 / 21.1 / 19.3 %; H commit 14.9 / 15.0 / 14.9 %; sumcheck slots 0 to 4 and 13 together 9.2 / 8.6 / 9.2 %; **slots 14 to 18 together 49.5 / 49.8 / 49.7 %**; slot 19 3.7 / 3.4 / 3.8 %; slots 20 to 22 2.3 / 1.7 / 2.0 %; all sumcheck slots 64.8 / 63.5 / 64.4 %; openings (GPU gather) 0.4 / 0.3 / 0.4 %. The shares are the same in the three traces to within about 1.5 points (and in the two Batch 8 traces, section 12), so they do not depend on lane count. Nothing else exists: the union is commits (35 %) plus sumcheck slots (65 %).

Rows with 0 to 2 buffers per call (`slot 05..12` matmul labels, `slot 13`, `slot 20`) are a handful of stray rows (under 7 ms per call in total).

## 5. Item 3: concurrency of prover buffers inside the prove call [RECOMPUTED `busy_split.py`]

Time share at depth d (prover buffers executing at one instant), median per call:

| class (n) | d=0 | d=1 | d=2 | d=3 | d>=4 | mean depth while busy |
|---|---:|---:|---:|---:|---:|---:|
| serve1 solo (6) | 31.9 % | 4.9 % | 15.9 % | 46.7 % | 0 | 2.61 |
| serve4 beside (18) | 29.2 % | 10.0 % | 22.2 % | 36.8 % | 0 | 2.39 |
| serve4 last (6) | 29.3 % | 7.1 % | 19.5 % | 44.8 % | 0 | 2.53 |
| serve6 beside (30) | 30.6 % | 9.3 % | 21.3 % | 38.7 % | 0 | 2.42 |
| serve6 last (6) | 28.5 % | 6.4 % | 18.0 % | 46.2 % | 0 | 2.55 |

The prover never has more than 3 buffers executing at once in any of the 69 prove calls (7 + 25 + 37, cold ones included) although six fork threads submit (`natural_experiment.py`). With the witness queue added the maximum is 6, for 1.9 s (serve4) and 2.7 s (serve6) of about 70 and 103 s of busy time. This matches the code comment that the shared queue "caps it" at 3 (`metal.rs` 773-780; `a7/README.md` lines 13-16, 86-87) **[CODE-READ]**.

## 6. Item 4: saturation test

For every prover buffer inside a prove call, md = the time-averaged number of buffers (prover and witness) executing during its own span, itself included; md = 1 means it ran alone. Median span per label and md class [RECOMPUTED `saturation.py`; ms; n in the full output]. Selected rows (serve4 n = 768 buffers per label, serve6 1,152; serve1 192):

| label | alone (md<1.1) | md 1.75-2.25 | md > 2.75 | stretch at md about 3 | other arms (alone / md>2.75) |
|---|---:|---:|---:|---:|---|
| commit A | 13.4 (n=22) | 30.1 | 43.4 | **3.2x** | serve1 13.6 / 44.1; serve6 13.5 / 43.9 |
| commit H | 13.7 (n=21) | 30.4 | 28.6 | 2.1x | serve1 13.6 (n=1) / 21.6; serve6 13.8 / 29.8 |
| slot 14 | 14.4 (n=6) | 21.3 | 30.9 | 2.1x | serve1 14.2 (n=2) / 30.6; serve6 14.3 / 31.1 |
| slot 18 | 22.1 (n=2) | 36.5 | 48.4 | 2.2x | serve1 21.4 (md 1.1-1.75, n=1) / 51.7; serve6 22.5 (n=14) / 48.5 |
| slot 17 | 7.8 (n=12) | 10.9 | 16.2 | 2.1x | serve6 7.7 / 16.3 |
| slot 15 | 5.6 to 6.0 (n=1 to 4) | 8.1 | 10.3 | about 1.8x | serve6 5.6 / 10.2 |
| slot 16 | 2.9 (n=12) | 3.4 | 5.7 | 2.0x | serve6 2.9 / 5.7 |
| slot 19 | 3.9 (n=17) | 4.1 | 6.7 | 1.7x | serve6 4.0 / 6.5 |
| slots 0, 1, 3, 4, 21, 22 | 1.1 to 1.7 | 1.2 to 1.8 | 1.4 to 7.9 | flat to md 2.25, then up to 5x | (about 13 % of U in total) |

One-block log (Batch 6, n = 7, one block run alone) **[RECOMPUTED from the JSON]**: commit A 13.376 ms, commit H 14.001 ms, 23 slots 65.9 ms, openings 0.175 ms, total 93.482 ms. The alone-spans above (13.4 to 13.6 and 13.7 to 13.8 ms) are the same numbers, so the stream's "alone" buffers behave like the one-block run. Per-block stretch against the one-block log, all buffers of the warm prove calls (n = 6, 24, 36) [RECOMPUTED]: commit A 2.68x (serve4, n=24 calls) / 2.70x (serve6) / 2.97x (serve1); commit H 1.97x / 2.02x / 2.05x; the 23 slots 135.4 ms per block against 65.9 ms = 2.05x / 2.06x / 2.07x; all of them 198.7 ms per block against 93.5 ms = 2.13x / 2.14x / 2.19x. The stream's per-buffer spans are the same in serve1, serve4 and serve6 (slots 135.4 to 136.1 ms per block), so having a sealing pass beside does not change them.

Reading, per label:
- **Commit A stretches at least in proportion to depth** (3.2x at depth about 3). Overlapping commits gain nothing: the GPU is saturated.
- **Commit H and the slots stretch by about 0.6 to 0.75 of depth** (1.7x to 2.2x at depth about 3). Some headroom: three overlapped H commits or slot buffers do about 1.4x the work of one in a span.
- **Short slots** (1 to 2 ms alone) stay flat until another large buffer overlaps, then jump, so they are the passengers, not the cause.
- **Whole call:** the sum of actual spans is 6.4 s against 2.98 s of solo spans (2.15x), at mean depth 2.4, so overlap buys 2.98 / 2.69 = **1.11x** (beside sealing) and 2.98 / 2.50 = **1.19x** (nothing beside) over serial execution at solo speed. Per block, the prover's GPU union in the stream is 78 to 84 ms against 93.5 ms alone.
- The alone-spans do not depend on the host context (commit A alone: 13.6 ms in serve1, 13.4 and 13.5 ms in the streams with a sealing pass beside), so the stretch comes from buffers sharing the GPU, not from the host's memory traffic **[RECOMPUTED]**.

Per-thread evidence (`gaps.py` part B, six fork threads, serve4 beside, thread-time summed over the threads, n = 18): queue wait (commit to GPU start) 20.4 %, execution 33.2 %, wake 3.8 %, host between buffers 42.5 %. So the fork threads are inside GPU buffers (waiting for the GPU or running on it) 54 % of their time, and between buffers on the host 42.5 %. The 2026-11-05 note A7 measured the same quantity at 60 % host and a GPU busy 53 to 59 % of the forks phase (4.8 to 5.3 s); today's forks phase is 3.2 to 3.4 s and the GPU union has barely moved (2.8 s then, 2.5 to 2.7 s now) **[CODE-READ, a7/README.md lines 9-12, 84-96, 115]**. The call has moved from host-bound toward the GPU floor since then, because the host side shrank and the GPU work did not.

**Verdict on saturation:** saturated while busy (commit A fully, H commit and the slots mostly), so the busy union is a real constraint, not an overstatement. A direct natural experiment points the same way: with per-thread queues (up to 6 buffers at once instead of 3) the union stayed about 2.8 s and the D55 wall did not improve (A7: proof-only about +1.4 %, stream about -2.7 %) **[CODE-READ, `metal.rs` 774-780, a7/README.md 17-20, 115; older code]**.

## 7. Item 5: two floors for the prove call (MODEL)

[RECOMPUTED inputs, MODEL arithmetic; `floors.py`.] "Solo span" per label = median span with md < 1.1 pooled over the three traces (n of at least 10 for every label that matters; small stray labels use their own median).

| class (n) | P today | (i) prover GPU union (host-only time gone, today's overlap kept) | (ii) sum of solo spans (serialised, no stretch) | sum of actual spans |
|---|---:|---:|---:|---:|
| serve1 solo (6) | 3.662 | 2.508 | 2.976 | 6.538 |
| serve4 beside (18) | 3.809 | 2.688 | 2.979 | 6.399 |
| serve4 last (6) | 3.512 | 2.501 | 2.976 | 6.268 |
| serve6 beside (30) | 3.889 | 2.674 | 2.978 | 6.455 |
| serve6 last (6) | 3.516 | 2.511 | 2.977 | 6.425 |

Cross-check for (ii): 32 blocks x 93.482 ms (one block alone, Batch 6, n = 7) = 2.991 s.

Against the 50 tok/s target (2.56 s): floor (i) is 2.50 to 2.51 s with nothing beside (0.05 s below the target) and 2.67 to 2.69 s with sealing beside (0.11 to 0.13 s above). Floor (ii) is 2.98 s (0.42 s above). Against today's 3.70 s (3.81 beside, 3.51 to 3.66 alone): floor (i) is 68 to 73 % and floor (ii) about 80 % of 3.70 s.
Two-lane arithmetic that the target also needs (MODEL): (S + W + P)/2 <= 2.56 with S = 3.35, W = 0.22 gives P <= 1.55 s, so at two lanes the sealing chain, not P, would limit; at three lanes (S + W + P)/3 <= 2.56 needs only P <= 4.1 s, so P <= 2.56 s is the binding condition.

How much GPU work must go for P = 2.56 s, as a function of the host-only time left (MODEL, P = U' + idle left; today's idle is 1.0 to 1.2 s):

| idle left | 0.0 s | 0.2 s | 0.4 s | 0.6 s | 0.8 s |
|---|---:|---:|---:|---:|---:|
| union to remove, serve4 beside (U = 2.688 s) | 0.13 s (4.8 %) | 0.33 s (12 %) | 0.53 s (20 %) | 0.73 s (27 %) | 0.93 s (35 %) |
| union to remove, nothing beside (U = 2.50 s) | none (floor 0.06 s under target) | 0.14 s (5.6 %) | 0.34 s (14 %) | 0.54 s (22 %) | 0.74 s (30 %) |

## 8. Item 6: candidate A in GPU terms

**What A removes (from `BATCH6_REVIEW.md` section 1):** H commit, helper inverses, H opened columns, H masks, helper terms in slots 14 to 18, the table-helper part of slot 19.

**Measured GPU spans [RECOMPUTED, `floors.py`, serve4 beside n = 18; serve6 n = 30 and serve1 n = 6 agree to 1 %]:**
- H commit: equal-split share 403 ms = **15.0 %** of the prover GPU union (sum of spans 876 ms).
- H open (the `gather` buffers): 5.6 ms = 0.2 % (the fold, audit and Merkle path of an opening are host).
- Helper inverses 17 ms and H masks 2 ms per block: **not on the GPU** (section 2). They count only as host time.

**Slot share, MODEL.** The labels cannot split a slot, so the helper terms of slots 14 to 18 are priced as in `BATCH6_REVIEW.md` section 1.4 (helper columns over table inputs: D 10/37, Q 3/15, Kv 3/15, S 4/19, F 4/19) applied to the measured equal-split time of each slot: **298 ms (11.1 % of U)**; low end (the review's 8 ms against 16.5 ms) **144 ms (5.4 %)**. Slot 19, the TAB slot, is 98 ms (3.7 %) in total; how much of it A removes is 0 to 100 % (the design note says "the table-helper part").

| variant (serve4 beside, U = 2.688 s) | union removed | share of U | MODEL P' = 3.70 - removed | factor on P | two-lane cadence, S 3.35 and W 0.22 held (today 3.70 modelled) | three-lane cadence |
|---|---:|---:|---:|---:|---:|---:|
| A1: H commit + H open (measured) | 408 ms | 15.2 % | 3.29 s | x1.12 | 3.43 s (x1.08) | 3.29 s (x1.12) |
| A2: A1 + helper share of slots 14-18, low end | 553 ms | 20.6 % | 3.15 s | x1.18 | 3.36 s (x1.10) | 3.15 s (x1.18) |
| A3: A1 + helper share, table-count value | 706 ms | 26.3 % | 2.99 s | x1.24 | 3.28 s (x1.13) | 2.99 s (x1.24) |
| A4: A3 + the whole TAB slot | 804 ms | 29.9 % | 2.90 s | x1.28 | 3.24 s (x1.14) | 2.90 s (x1.28) |

serve1 and serve6 give the same factors to the second decimal (serve1: x1.12, 1.16, 1.22, 1.25 on P). These are before A's own added cost (GKR rounds, leaf-claim terms, extra mask rows), which is not measured in any file I read and which I do not estimate. The "three-lane" column is P' itself because (S + W + P')/3 is below P' for any P' above 1.8 s; three lanes were run (serve6) but only at today's P.

**Host side of A.** A also removes about 38 ms of host thread-time per block (17 + 2 + 9 + 10 ms of the Batch 6 list). Most of it is hidden behind other forks' GPU work: the gap class it sits in (A commit to H commit) is 74 to 88 % covered by a running prover buffer (serve4 beside: 2.22 thread-seconds per call, 0.57 exposed; serve1: 1.74, 0.21). The union idle in that class is 52 to 67 ms per call, and in the A-open to H-open class 75 to 100 ms per call, so A's host side can shorten P by at most about 0.1 s (MODEL, upper bound), already small against 0.41 to 0.80 s on the GPU side.

**Contrast with the wall-time conversion in `BATCH6_REVIEW.md`.** That review took the author's list as 19.3 % of one block's wall (52 of 268 ms, x1.24 on the one-block prove core) and converted to x1.09 to x1.19 on the stream cadence (x1.13 to x1.27 with helper slots). In GPU terms the list is not 19.3 % of what limits the stream: its GPU part is 15.2 % of the prover's GPU-busy union and its host part is mostly hidden. So at the level of P the measured list gives x1.12, not x1.24, and the cadence gain at two lanes (x1.08 to x1.14) lands at the bottom of the review's range, because the sealing chain (S + W + P)/2 absorbs half of any change in P. The upper end (x1.28 on P, x1.14 on the cadence) needs the modelled slot share to be real. The two conversions agree on the order of the gain and disagree on its source: it comes from GPU time, which the wall-time list undercounts for H commit (23 ms wall, 14 ms of it GPU, at one block alone) and does not see for the slots.

## 9. Item 7: where the host-only time inside the prove call sits [RECOMPUTED `gaps.py`, `phases_of_call.py`, `gap_timeline.py`]

**Split of the prove call** (median wall | prover busy | idle, s):

| class (n) | start: S to first A or H commit | forks: first big commit to last fork buffer | join: after the last fork buffer to E |
|---|---:|---:|---:|
| serve1 (6) | 0.289 \| 0.015 \| **0.276** | 3.291 \| 2.496 \| **0.796** | 0.082 \| 0 \| **0.081** |
| serve4 beside (18) | 0.274 \| 0.009 \| **0.264** | 3.410 \| 2.678 \| **0.740** | 0.083 \| 0 \| **0.083** |
| serve4 last (6) | 0.259 \| 0.009 \| **0.250** | 3.163 \| 2.492 \| **0.679** | 0.083 \| 0 \| **0.083** |
| serve6 beside (30) | 0.368 \| 0.014 \| **0.354** | 3.438 \| 2.662 \| **0.756** | 0.089 \| 0 \| **0.089** |

Idle inside the forks region is 22 % of it (0.68 to 0.80 s); the GPU is busy 76 to 79 % of the forks region.

**Gaps (no prover buffer executing), per call, serve4 beside, n = 18:** total 1.109 s in about 200 gaps (68 of them 5 ms or longer): sizes 0 to 1 ms 50 gaps 19 ms; 1 to 5 ms 80 gaps 182 ms; 5 to 20 ms 53 gaps 443 ms; 20 to 50 ms 13 gaps 369 ms; over 50 ms 1.7 gaps 136 ms. Largest classes, with the buffers that bracket them (previous buffer to next buffer; ms per call, gaps per call):

| class | ms per call | gaps | typical gap | where it sits |
|---|---:|---:|---:|---|
| small commit to small commit (the serial commit phase) | 202 | 30 | 6.6 ms | start of the call; the GPU is used 0.3 ms of each 6 ms; one thread loops over 31 blocks |
| slots 0-4,13,20-22 to A open (gather) | 107 | 4 | 26.6 ms | a fork's last sumcheck slot to its opening: opening host work (audit, row fold, Merkle path) |
| H open to A commit | 97 | 4 | 32.5 ms | next block's host build of A (planes, histogram, masks, 28 ms in the one-block log) |
| A open to H open | 75 | 4 | 21.1 ms | host fold of the A opening and audit |
| join gathers (small gather to small gather) | 70 | 32 | 2.1 ms | end of the call; one thread loops over 31 + 2 gathers |
| slots 0-4,13,20-22 to slots 0-4,13,20-22 | 68 | 41.5 | 1.1 ms | between small slots |
| slots to slot 14 | 63 | 4 | 16.2 ms | host between the small slots and the first domain zero-check |
| last small commit to first A commit | 59 | 1 | 59.2 ms (max 159) | the serial phase hands over to the forks (first A build) |
| A commit to H commit | 52 | 2 | 18 ms | helper inverses, H masks, mask commit (candidate A's host phases) |

Where in the call they fall (`gap_timeline.py`, idle ms per 0.5 s slice, serve4 beside, n = 18): 289, 98, 85, 86, 105, 105, 143, 184 (the call is 3.8 s long). So about 0.29 s in the first half second, about 0.1 s per half second in the middle (a 17 to 21 % idle share), and 0.14 to 0.18 s in the last two slices.

**Exposed or hidden, by thread (serve4 beside, thread-seconds per call summed over the six forks; exposed = no prover buffer of any thread executing meanwhile)** [RECOMPUTED]:

| host gap of a fork thread (previous buffer to next) | thread-s per call | exposed | exposed share |
|---|---:|---:|---:|
| A commit to H commit (helper inverses, masks) | 2.22 | 0.57 | 26 % (74 % hidden) |
| H open to A commit (next block's A build) | 1.42 | 1.05 | 74 % |
| slots to slot 14 | 1.06 | 0.40 | 37 % |
| last small slot to A open (opening host work) | 0.99 | 0.74 | 75 % |
| A open to H open | 0.91 | 0.67 | 73 % |
| between small slots | 0.45 | 0.16 | 35 % |
| slot 17 to slot 18 | 0.42 | 0.06 | 14 % |
| H commit to the next small slot | 0.19 | 0.04 | 23 % |

All host gaps of the fork threads together: 8.1 thread-seconds per call (42 % of thread time), 54 % hidden behind another thread's executing buffer, 3.6 thread-seconds exposed. Serve1 and serve6 show the same classes in the same order (serve1: 7.1 thread-seconds, 45 % hidden).

Reading: **hidden** host phases are the commit-side ones (A commit to H commit, between and inside slots 14 to 18), which means candidate A's host removals mostly vanish into other forks' GPU time. **Exposed** are the serial start and join loops (about 0.35 s per call), the A build between blocks, and the opening host work (audit, fold, Merkle path). The openings and the A build are exposed because the six forks run the same schedule and reach those phases together, and neither phase has GPU work of its own (an opening's GPU part is 0.1 ms).

## 10. Item 8: the verdicts

- **Is the stream's prove call GPU-bound, host-bound or mixed today?** Mixed, with the GPU as the larger and harder part: the prover has a buffer executing 69 to 72 % of the call, buffers stretch in step with the overlap (overlap buys 1.11x to 1.19x), the fork threads spend 54 % of their time inside GPU buffers, and 1.0 to 1.2 s (29 to 32 %) is time with no prover buffer executing (sections 3, 6, 9).
- **(a) Host-side engineering in the prover:** it can shorten P only through that 1.0 to 1.2 s of host-only time, at most to the GPU floor of 2.5 to 2.7 s. The single clean piece is about 0.35 s of serial loops (the 31 small commits at 6 ms each, 0.17 to 0.25 s; the 32 join gathers, 0.07 s; the hand-over to the first A commit, 0.05 to 0.1 s); the other 0.7 s is fork phase alignment and opening host work, which could also be removed by staggering. No amount of host work gets P below 2.5 s, and reaching 2.56 s by host work alone would need all of it plus sealing's GPU use gone (floor i).
- **(b) Removing GPU work by protocol change:** it converts about 1:1 into P while the GPU is saturated (MODEL): every 0.27 s (10 % of the union) is about x1.08 on P. Candidate A's measured GPU part (H commit and H open, 0.41 s) gives x1.12 on P; the largest single owners are slots 14 to 18 (49.5 %, 1.33 s), commit A (19.3 %, 0.52 s) and slot 18 alone (20.6 %, 0.55 s). The target 2.56 s needs 0.13 to 0.93 s of union removed depending on how much idle time is also removed (section 7).
- **(c) The sealing pass's GPU use:** the sealing chain has 0.37 s of GPU union solo and 0.40 to 0.44 s beside a prover, 80 to 88 % of it while a prover buffer executes; beside the sealing pass the prover's own GPU union rises from 2.50 s to 2.67 to 2.69 s (+0.17 to +0.19 s) and P from 3.51 (last request) to 3.81 s (+0.3 s) or from 3.66 (serve1) to 3.81 s (+0.15 s) (section 11). That makes it a competitor worth up to about 0.2 to 0.3 s on P (5 to 8 %), part of which is the GPU and part is host contention that these traces cannot separate; it is about 11 % of the GPU-busy union per window-request (0.29 to 0.30 of 2.65 to 2.68 s).

## 11. Sealing pass GPU use and what it does to the prover [RECOMPUTED `witness_gpu.py`]

| arm, class (n) | witness GPU union | sum of spans | chain wall | part of the union while a prover buffer executes |
|---|---:|---:|---:|---:|
| serve1 solo (6) | 0.370 s | 0.504 s | 2.180 s | 0 |
| serve4 request 0, nothing beside (6) | 0.366 s | 0.519 s | 2.113 s | 0 |
| serve4 requests 1..3, prover beside (18) | 0.438 s | 0.479 s | 3.307 s | 0.378 s (88 %) |
| serve6 request 0 (6) | 0.363 s | 0.504 s | 2.114 s | 0 |
| serve6 requests 1..5, prover beside (30) | 0.401 s | 0.449 s | 3.174 s | 0.322 s (80 %) |

Prover GPU union inside the prove call: 2.508 s (serve1, nothing running), 2.501 and 2.511 s (stream, last request, nothing beside), 2.688 and 2.674 s (sealing beside) [section 3]. Prove call: 3.662 (serve1), 3.512 and 3.516 (last request), 3.809 and 3.889 (beside). The "nothing beside" baseline for P is 3.51 or 3.66 depending on which of the two you take, so the P effect of the sealing pass is +0.15 to +0.38 s; the union effect (+0.17 to +0.19 s) is stable. Across the warm prove calls of each trace (n = 6, 24, 36) P follows the idle time better than the union (correlation of P with idle 0.89 to 0.93, with union 0.72 to 0.84; `natural_experiment.py`), which fits a call whose variation is mostly host timing on top of a GPU floor.

## 12. Replication check: two unsampled Batch 8 serve1 traces [RECOMPUTED `batch8_check.py`, window from the trace itself]

`a1_default` and `a2_default`, 7 prove calls each, first excluded: P 3.669 and 3.743 s, prover busy 2.520 and 2.495 s (66 to 70 %), idle 1.145 and 1.223 s, commit A share 19.3 to 21.8 % and commit H 14.1 to 15.8 % of the union in each call. Same picture as Batch 7 serve1 (3.662 s, 2.508 s, 1.168 s, 21.1 % and 15.0 %).

## 13. What this does not show

- **The trace was on** (`HL_A27_GPU_TRACE`, one formatted line per buffer under a mutex, after the buffer completed). No untraced control exists. The cost is expected in microseconds per buffer but is unmeasured, and it falls on the host side (a host-only share could be a few percent smaller untraced).
- **Synthetic stack.** The stream serves the D55 harness's synthetic block repeated 32 times, not a trained export; the commit and slot shapes are the real ones for W16R2 8B T128 but the data and cache behaviour are those of one repeated block.
- **GPUStartTime / GPUEndTime semantics for overlapping buffers.** I take Metal's two timestamps as given. For overlapped buffers a span includes time in which other buffers hold the shader cores, so "span" is residence, not work. The busy union counts a buffer as busy while it is in flight even if it uses few cores. The stretch test (section 6) is the check on that, and it is only as good as the assumption that a solo span measures the work. A buffer made of many small dependent dispatches (the sumcheck slots) could stretch for reasons other than core saturation (driver scheduling between buffers). I cannot separate these from the traces.
- **No power, clock or utilisation counter.** Nothing here observes shader occupancy, memory bandwidth, thermal state or GPU clock. Whether the stretch is compute, memory bandwidth (the host's six forks and eight sealing threads share the same unified memory), or scheduling is not shown. The alone-spans being the same with and without a sealing pass beside is evidence against a host-memory effect, not a proof.
- **Cap of 3.** The traces show at most 3 prover buffers executing at once on queue 0. That the shared queue caps concurrency is stated in the code comment and the A7 note (older code, 2026-11-05); I did not re-test it, and a per-thread-queue run with today's code does not exist.
- **Floors are models.** Floor (i) assumes the same overlap efficiency without the host gaps; if removing the gaps raised concurrency further, the union could be shorter than 2.5 s (the cap of 3 and the A7 per-thread-queue result, where the union stayed 2.8 s with up to 6 at once, argue against much). Floor (ii) assumes solo spans are the work. Candidate A's conversion to P assumes freed GPU time converts 1:1 and idle time is independent of the GPU work. The slot share of A is priced by table counts, an estimate, not a measurement; A's own added cost is not included.
- **Equal-split attribution is a convention.** It adds to 100 % but a buffer's share depends on what overlaps it. The sum-of-spans column is the alternative and gives the same order (commit H 13.8 % and A 17.5 %, slots 14 to 18 54 % of 6.36 s for serve4).
- **Window edges.** The prove-call window is anchored by the first small commit and the log's call length; it is good to a few ms. The 2 small commits of 37 rows per request fall in the previous request's window (0.6 ms in total).
- **Request-level confounds.** Request 0 of each pass has the slowest prove call (4.02 s serve4, 4.03 s serve6) with the same GPU union; I do not know why. Arm order was fixed (serve1, serve4, serve6). N is 6 passes per request position.
- **Not checked:** the 38-row and 37-row matrices' identity, the CPU load per call, how the sealing pass's host work contends with the prover's (only its GPU part is measured here), and any run on a quiet versus loaded box beyond the Batch 7 guard record.

## 14. Scripts (all in `stream_gpu_phases/`, read-only on traces and logs, standard library)

`common.py` (loader, request split, windows, interval maths), `anchor.py` (clock tie and window check), `busy_split.py` (items 1 and 3), `labels.py` (item 2 and the GPU side of item 6), `saturation.py` (item 4), `floors.py` (items 5 and 6), `gaps.py` (item 7, thread view), `gap_timeline.py`, `phases_of_call.py`, `natural_experiment.py` (max depth, P against union and idle), `witness_gpu.py` (section 11), `batch8_check.py` (section 12), `run_all.py` (runs all and writes the `*.out.txt` files). Run with `python3 -I run_all.py`.
