# A28: the media app's commitment kernels and the GPU's idle gaps (2026-11-07, resumed 2026-11-09)

**STATUS: WORK IN PROGRESS** (the final A/B pairs, the acceptance on the committed tree, the byte identity of
the final candidate and the app runs are running; the sections marked PENDING wait for them).

Lane A28. Goal (Victor, 2026-11-07): "Focus on implementing the new optimizations into the proof of concept
media app. It would be nice to get the media app speed up to 30 or so tokens per second for the proofs." A27
left the app's stream at 16.9 proved tok/s. This lane's brief has two parts, both byte-preserving: (1) the
commitment kernels (43% of a proof's GPU time after A27); (2) the GPU's idle gaps in the stream (scheduling and
server code only). No protocol, profile, receipt, statement, verdict or refusal change.

The first session was cut off on 2026-11-07 19:11Z; the Mac was rebooted on 2026-11-09 and the lane resumed
that day (section 8).

**Labels:** [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers;
[CODE] read from the source.

**Metric** (MVP_STATUS's): proved tok/s = 128 x (category proofs completed) / wall seconds; every receipt
counted was freshly verified (the verifier server, its own process). Public text only.

**Machine:** the M3 Ultra Mac (24 performance and 8 efficiency cores, 80-core GPU, 256 GB of unified memory),
shared with the Lean lanes. Every heavy run went through the resource guard at its default floors, with no
`ds4-bench` running (`*.quiet` files, `pgrep ds4-bench`).

## 0. Plain summary

PENDING.

## 1. The profile first (A27 as pinned, the 8-post stream at the app's setting)

[MEASURED, `p0.plan`, `profile_p0s8.txt` (the GPU trace, `trace_report.py`), `profile_p0s8_lane0.txt` /
`profile_p0s8_lane4.txt` (macOS `sample` of the prover for 60 s, `lane_split.py`), `stream_p0s8/`.]

- **The GPU.** Over the trace's window (173 s, 24 proofs) at least one command buffer executes 65.8% of the
  time: 113.9 s, 4.75 s per proof, the same as one proof alone (5.01 s, A27's `profile_p3solo.txt`). So the
  device serves the lanes' command buffers by sharing its time: 2.4 execute at once on average while it is
  busy, each takes 2.4x as long as alone, and the work done is the sum of the solo work. For 29% of the window
  no command buffer is even committed and waiting. Command buffers wait 106.7 s between commit and start (4.4 s
  per proof), 23.6 s of it the witness products, which all go through ONE shared queue.
- **A prover lane's own thread** (the thread that runs a request, 6 lanes x 5 threads): **32% of its time
  waiting for its command buffers, 23% in serial host work (its four other threads idle), 46% in parallel
  host sections.** Per 38 s request: 12 s waiting for the GPU (2.4x the 5 s the device needs for it), 8.7 s
  serial, 17.7 s parallel. The serial part is a long tail: `__bzero` of the A and H rows 5.2%, the
  classifier tables' BLAKE3 digests 4.3% (three per request), the segments' SHA-256 1.6%, page unmapping 1.3%.
  The parallel part: the openings' host folds 6.6%, each block's CS-6 digest 4.2% and CS-1 / CS-4 word checks
  3.8% (the two that A26's `HL_A26_KEPT` would take from the startup; it stays off), the witness planes 2.9%.

## 2. What changed

Each change computes the same words as the code before it and has a switch that restores that code (read once
per process). [CODE; tests in sections 4 and 5.]

1. **`HL_A28_PRUNE`** (default on; `gpu/metal_kernels.metal` `k_ntt_head_pruned`, `gpu/metal.rs`
   `encode_fused`): the commitment's forward transform reads a row zero-padded from 2^14 (+ 256 hiding words)
   to 2^16. At rate 1/2 or lower every bit-reversed working position with bit 0 set holds zero, so the head's
   first radix-4 pass reads only positions 4b and 4b + 2 and skips the products and sums of the zeros. The zero
   positions are a function of the shape alone. The pruned head is its own kernel instance (a template), so
   A27's head is unchanged where the shape does not allow it.
2. **`HL_A28_HASH`** (default on; `k_hash_chunk` + `k_hash_merge`, `encode_hash`): the column leaves in two
   passes: one thread per (column, 1024-byte chunk) for the chunks' chaining values, then one thread per
   column merging them with BLAKE3's chaining-value stack. BLAKE3 is a function: the same leaves.
3. **`HL_A28_SEAL_AHEAD`** (default OFF, `1` turns it on; `token_io/classify_serve.rs`, `classify_cli.rs`
   `SharedProve::run_gate`): a lane takes a second request while its first one runs; the second request's
   sealing pass runs beside the first one's run and its run waits at the lane's gate. The reader sends each
   request to the least loaded lane (an idle lane first, never a third to a lane). Each request is still
   `prove_with_public` from its first step to its last on one thread, with its own fresh draws; only when its
   run starts changes. Off by default because of what it costs for what it gives (section 3.1).
4. **`HL_A28_STAGGER_MS`** (default 0; `classify_serve.rs`): a minimum interval between request starts.

**Tried and taken out again** (the first two candidates had them; the final one does not):
- `HL_A28_CALLOC` (A's and H's zero rows from the allocator's zeroed pages instead of a serial fill):
  nothing alone (section 3.3) or in the stream. `private_block/protocol.rs` is back at its base: no edit of
  this lane is left in it.
- `HL_A28_WQ` (each thread's witness products on a Metal queue of its own instead of the one shared witness
  queue): the products' commit-to-start waits in the stream were 31.5 s with it against 23.6 s without
  (`profile_x4s8.txt`, `profile_p0s8.txt`): they wait for the device, not for the queue; their GPU time alone
  was 7% more.
- `HL_A28_QOS` (the user-initiated quality of service for the lane threads): 17.17 against 17.25 proved tok/s.

**What did not change.** No receipt, statement, transcript, profile, verifier verdict or refusal message. Files
outside `gpu/` and `token_io/classify_serve.rs`: `token_io/classify_cli.rs` (the run gate: one field of
`SharedProve`, one lock taken before the run), `token_io/classify_batch.rs` (that field's `None`),
`token_io/classify_serve_tests.rs` and `private_block/slot_ir_accuracy.rs` (tests). No edit to `protocol.rs`,
`argument*.rs`, `run_fork.rs`, `trained_block.rs`, the PCS or zkp-core; no new source file.
`HL_A26_KEPT` / `HL_A26_VERIFY_ONCE` stay off.

**The kernels one by one** [MEASURED, `nb3.log`; the zk commitment at the classifier's A shape, 4577 rows x
2^14 -> 2^16, each kernel alone, GPU timestamps, best of 5, every variant's words compared with the tree's]:

| kernel | A27 | A28 | variants that lost |
|---|---:|---:|---|
| forward head (11 stages in threadgroup memory) | 19.59 ms | **16.91 ms** (pruned) | radix 8 in registers 21.13, radix 16 28.92 |
| forward tail (5 stages) | 9.56 ms | 9.56 ms | 5 stages in registers 12.46-12.51 |
| inverse head / tail | 5.18 / 2.24 ms | the same | radix 8 5.74, radix 16 7.25; tail in registers 2.15-2.18 |
| column hash | 5.47 ms | **4.24 ms** (two passes) | |
| an in-register butterfly probe (no memory): 11 stages' worth | 15.72 ms | | add and sub alone 10.36, the product alone 13.16 |

- The transform is bound by the device's 64-bit integer arithmetic, not by its passes any more: the forward
  head runs at 84 G butterflies/s against 105 G/s for butterflies in registers with no memory at all, and
  rewritten adds, subs and products (`nbf1.log`: three forms, all equal word for word on 2^25 pairs) are no
  faster. Deeper passes (A27's suggestion) lose: they trade threadgroup round trips for register pressure.
  The tail and the hash move 4.8 and 2.4 GB in 9.6 and 4.2 ms: about 500 GB/s.
- So the commitment had about 4 ms of 42 in these two changes, and has no more in this design.

**In a real proof** [MEASURED, `p2.plan`, `profile_p2solo*.txt`: one post's three proofs one after another on
one lane of 30 threads, the GPU trace on, a28-q2 (the same two kernels as the final candidate)]:

| GPU s per category proof | A27 (`p2soloA`, `p2soloA2`) | A28 kernels (`p2soloB`) | A28 binary, every switch off (`p2soloB0`) |
|---|---:|---:|---:|
| **GPU busy** | **5.036 / 5.045** | **4.841 (-3.9%)** | 5.042 |
| device sumcheck batches | 2.544 / 2.547 | 2.541 | 2.540 |
| commitments | 2.169 / 2.169 | **1.975 (-9.0%)** | 2.172 |
| &nbsp;&nbsp; A (4577 rows), per block | 42.41 ms | 38.63 ms | 42.49 ms |
| &nbsp;&nbsp; H (4390 rows), per block | 40.47 ms | 36.82 ms | 40.50 ms |
| witness products | 0.458 / 0.466 | 0.492 (with `HL_A28_WQ`, since removed) | 0.469 |
| one proof's seconds (the post's second and third) | 18.40, 18.46 / 18.66, 18.31 | 18.02, 17.89 | 18.29, 18.29 |

## 3. Numbers

**What is on the clock** (A24's definition, unchanged): the native rows start at the first post and stop when
the last post's third category label is accepted; on them the activation writer, the sealing pass, the proof,
the receipt write (every segment fsync'd), fresh verification in the separate verifier process, the
input-owner check and the label. Server startup is off the clock.

### 3.1 The first two candidates, 6 x 5 lanes [MEASURED, `q1s.progress`, `q2s.progress`, `stream_m1*`, `stream_m3*`]

A27 as pinned (`b5b6b9a4…`) against the first candidate (a28-q1, `a55adb13…`: seal-ahead with one shared
request queue) and the second (a28-q2, `34b62314…`, commit `5794c756`: seal-ahead with the least-loaded lane
dispatch; both with seal-ahead ON by default), the 8-post public stream at the app's setting, order A B B A in
one guarded job each, 2026-11-07:

| run | binary | env (beside `HL_METAL_QUEUES=thread`) | wall | proved tok/s | second half | first post | prover CPU-s per proof | GPU utilization mean / median |
|---|---|---|---:|---:|---:|---:|---:|---|
| m1a1 | A27 | | 180.1 s | 17.06 | 21.49 | 55 s | 81.5 | 80% / 91% |
| m1b1 | a28-q1 | | 183.7 s | 16.73 | 31.35 | 85 s | 90.1 | 76% / 94% |
| m1b2 | a28-q1 | | 184.5 s | 16.65 | 31.49 | 87 s | 91.6 | 83% / 94% |
| m1a2 | A27 | | 183.4 s | 16.75 | 20.67 | 57 s | 83.7 | 76% / 91% |
| m3a1 | A27 | | 180.0 s | 17.06 | 21.19 | 55 s | 83.2 | 80% / 93% |
| m3b1 | a28-q2 | | 177.7 s | **17.29** | 24.06 | 56 s | 94.0 | 80% / 96% |
| m3b2 | a28-q2 | | 178.6 s | **17.20** | 24.16 | 56 s | 94.4 | 83% / 96% |
| m3a2 | A27 | | 181.0 s | 16.97 | 21.08 | 54 s | 83.1 | 78% / 93% |
| m3off | a28-q2 | `HL_A28_SEAL_AHEAD=0` | 183.6 s | 16.73 | 20.61 | 55 s | 85.0 | 81% / 94% |
| m3spin | a28-q2 | `HL_METAL_SPIN_US=200` | 178.1 s | 17.25 | 23.74 | 57 s | 71.5 | 82% / 96% |
| m3stag | a28-q2 | + `HL_A28_STAGGER_MS=300` | 174.7 s | 17.59 | 24.14 | 55 s | 71.1 | 81% / 95% |
| m3qos | a28-q2 | `HL_METAL_SPIN_US=200 HL_A28_QOS=1` | 178.9 s | 17.17 | 23.65 | 56 s | 71.2 | 81% / 96% |

- **The first candidate lost** (16.69 against 16.91): its lanes took requests from one shared queue, so a lane's
  second thread took a post's second category while other lanes sat idle, and the first post waited 85 s.
- **Seal-ahead at the app's 6 x 5: 17.02 -> 17.25 proved tok/s, +1.3%** (each a28-q2 run faster than each A27
  run; the single runs of this stream vary by about 2%). It moves about 5.7 s of a request's host work beside
  the previous run, but the lane's cycle shortens only from 39.0 to 37.6 s. It costs about 60 GiB (guarded
  peaks of 156-163 GiB against 100-107 GiB) and 11 CPU-s per proof. **On one lane alone it does what it
  should** (`p2soloBs`: the post's three proofs end 58.8 s after the post arrives instead of 65.6 s). So it is
  kept, tested in both modes, and OFF by default.
- Without seal-ahead the second candidate measured 16.73 (one run): the kernels' 3.9% of GPU work is inside
  the runs' spread.
- A7's spin-then-block wait (`HL_METAL_SPIN_US=200`) frees 23 CPU-s per proof at the same speed; the 300 ms
  stagger measured +2% once; the QoS class changed nothing.

### 3.2 More threads a lane, more lanes, two processes [MEASURED, `x1.progress`, `x3.progress`, `stream_x1*`, `stream_x3*`; a28-q2, single runs]

| run | prover lanes x threads | seal-ahead | wall | proved tok/s | a lane's request (median) | prover CPU-s per proof |
|---|---|---|---:|---:|---:|---:|
| (m3off) | 6 x 5 | off | 183.6 s | 16.73 | 39.0 s | 85.0 |
| x1b | 6 x 8 | off | 178.6 s | 17.20 | 37.9 s | 96.9 |
| x1d | 6 x 10 | off | 185.4 s | 16.57 | 39.4 s | 107.1 |
| x1c | 8 x 6 | off | 184.6 s | 16.64 | 48.5 s | 101.2 |
| x1a | 6 x 8 | on | 184.1 s | 16.69 | | 109.3 |
| x3c | two processes of 3 x 5 | off | 180.1 s | 17.06 | 37.6 s | 80.5 |
| x3e | two processes of 3 x 5 | off | 171.9 s | 17.87 | 35.8 s | 80.4 |

- **A lane is not short of threads**: with 8 or 10 threads its request takes as long as with 5 and burns more
  CPU (idle workers spinning). **Nor is the stream short of lanes**: 8 lanes finish 8 proofs in the time 6
  lanes finish 6 (A27 found the same at 8 x 4). The app keeps 6 x 5.
- **Two `serve` processes of three lanes** (post i to process i mod 2; `stream_driver.py --provers 2`) gave
  17.06 and 17.87: the two runs differ by more than either differs from one process, so no claim. If the
  lanes of one process were much in each other's way (its allocator, its address space, its Metal context),
  both runs would be clearly faster. Not pursued.
- **Every setting gives about one category proof every 6 to 6.5 s** (a lane's request divided by the lanes).

### 3.3 One proof alone, and what a lane loses in company [MEASURED, `p2.progress`, `x3.progress`, `x4.progress`, `stream_p2solo*`, `stream_x3*`, `profile_x4*.txt`; a28-q2 without seal-ahead]

| setting | one proof | note |
|---|---:|---|
| 1 lane x 30 threads, alone | 17.9-18.0 s | 4.84 s of it GPU |
| the same with `HL_A28_CALLOC=0` | 17.85-17.98 s | the calloc'd rows change nothing |
| 1 lane x 5 threads, alone | 19.5-19.7 s | five threads instead of thirty cost 1.6 s |
| 3 lanes x 5, three at once | 27.7 s | |
| 3 lanes x 10, three at once (A27's binary, its README) | 25.8-26.2 s | |
| 6 lanes x 5, six at once (the stream) | 38-39 s | |
| 8 lanes x 6, eight at once | 48.5 s | |

A proof that takes 19.6 s alone on five threads takes 38 s beside five others, on the same five threads.
**The same lane sampled alone and in the stream** (job x4: one lane of five threads alone, then the 6 x 5
stream, macOS `sample` on the prover, `lane_split.py`; both runs slowed a little by the sampling):

| the lane's own thread, seconds per request | alone (21.7 s) | in the stream (43.5 s; two lanes) | ratio |
|---|---:|---:|---:|
| waiting for its command buffers | 5.4 | 12.4 / 14.9 | 2.3-2.8x |
| serial host work | 5.5 | 7.6 / 8.1 | 1.4-1.5x |
| parallel host sections | 10.9 | 21.1 / 23.0 | 1.9-2.1x |

- **The device's queue is the larger part**: a lane waits 7 to 9.5 s more for its command buffers. A queueing
  model of lanes that share nothing but one time-shared device (`queue_model.py`: 14.2 s of host work and 5.4 s
  of device per proof, both measured alone) gives a 33.5 s cycle at six lanes with the device 97% busy, and a
  steady stream that does not rise with more lanes [INFERRED]. The trace sees less than that: command buffers
  execute during 66% of the stream's window, before and after A28 (`profile_p0s8.txt`, `profile_x4s8.txt`),
  and the device's own utilization counter reads 80% over the clock (93-96% median).
- **The host work also runs slower in company: 16 s alone, 29-31 s in the stream.** Every section stretches,
  serial ones included (`profile_x4solo_lane0.txt` against `profile_x4s8_lane*.txt`): the tables' BLAKE3
  digests and the segments' SHA-256 1.3-1.4x, the openings' folds and the blocks' digests 1.5-1.6x, the
  witness planes, the lookups and the row uploads 2x to 3.7x (the memory-heavy ones most).
- **What it is not** [MEASURED]: not threads (section 3.2); not the lanes of one process (two processes: no
  clear gain); not page faults (1.4 million per proof alone, 2.5 million in the stream: one to three seconds of
  the host work at the rate the zero rows were filled [INFERRED]); not the machine's memory rate exhausted (a one-thread copy probe beside the stream keeps 74 GiB/s
  against 102 beside one proof and 56-108 on the idle machine: `profile_x4_membw.txt`, inconclusive at
  best).
- **So the stream is pinned by its two shared resources together**: the one device, already 66% (trace) to 97%
  (model) busy with the six lanes' command buffers, and a host that slows by a factor of 1.8 when six lanes
  and the verifier run at once. Reordering the same work (seal-ahead, the stagger, more lanes or threads) does
  not move it; less work per proof does.

### 3.4 The activation writer [MEASURED, `writer_time_w1.log`, `writer_time.py`; beside a Lean job]

The pinned Python writer for one 14-token post, 4 BLAS threads a process:

| grouping | seconds |
|---|---:|
| one process, one category | 6.1 |
| one process, the post's three categories (the native stream driver) | 10.3 |
| three processes of one category, at once | 6.0 |
| two at once, then the third (the app's service, `WRITERS_AT_ONCE = 2`) | 11.8 |

A category's activation files are the same bytes in every grouping. In the app a post's third category starts
its proof 5.7 s after the other two. PENDING: the app with three writers at once.

### 3.5 PENDING: the final candidate (A B C C B A against A27), one post, proof only, through the app

## 4. Byte preservation

**The real Shieldstral export under fixed public test entropy** [MEASURED, `bi_q1.progress`, `bi_q2.progress`,
`byteid_bi_q*/summary.json`]: A26's fixed-entropy harness (`results/zk60_a26_app_20261107/fixed_entropy.c`, its
dylib outside the repository; `byteid.py`), one public post, the activation writer run once, then each binary's
prover server proves the three categories into its own directories, in the order A (A27's pinned binary), B
(the candidate), B0 (the candidate with its kernel switches off), A again; every server with
`HL_METAL_QUEUES=thread`, three lanes of ten threads (one category a lane). For both earlier candidates: every
receipt file of every category identical in all four runs, and all six cross-verifications accepted (each
binary's verifier on the other two's receipts: verify, input-owner, label).
PENDING: the same for the final candidate, and on ONE lane with seal-ahead on and off (`bi3.sh`).

**Gates on the final candidate a28-q3** (`80f2b704…`) [MEASURED, `q3.progress`]: the commitment test at the
classifier's shapes (plain, hiding and keyed rows at 2^14 -> 2^16 with 4577 and 4390 rows; leaves, roots and
columns, CPU = Metal); `tests/zk60_metal_commit.rs` 5 passed; the two A28 serve tests and the five A24 ones;
`s25_tests` 20, `hash_domain` 15; the six trained profiles' recorded digests on CPU and Metal (`5a6193d3`,
`f590b01f`, `79f987ef`, `a8258241`, `0e88d84f`, `90003b76`).

**A candidate is its committed tree's build** [MEASURED, `rebuild_q2.progress`]: the hashline crate recompiled
at commit `5794c756` gives a28-q2 (`34b62314…`) again, bit for bit. PENDING: the same check for a28-q3 at
`85b256c4` (`final1.sh`).

## 5. PENDING: tests (the native acceptance, the full lib suite, the app suite)

## 6. PENDING: open issues and privacy notes

## 7. PENDING: what is left to reach 30 proved tok/s

## 8. Operational notes

- **The resume.** The first session's scratchpad (`/private/tmp`) and the app-test venv
  (`/private/tmp/zk60-astra-app-refresh-20261104-venv`) were lost in the reboot. The venv was rebuilt from
  `results/zk60_astra_20261026/app_decision_refresh_20261104/requirements-replay.txt` (Python 3.12.13, the same
  50 pinned packages) at `~/zk60-artifacts/a28-tools/venv`; this lane's scripts use it. The kernel bench crate
  (`nbench/`: `main.rs`, `field.rs`, `variants.metal`, `Cargo.toml`) is kept here as source; its build
  directory was lost (`nb.sh` / `nbf.sh` expect it rebuilt under `~/zk60-artifacts/a28-tools/a28nb`).
  The second candidate's acceptance job had finished after the cut-off; its results were read on the resume.
- **Guard.** Default floors (disk floor 40 GiB; 139-145 GiB free). The Lean lanes' jobs and this lane's
  alternated on the heavy lock; this lane's jobs waited up to 25 minutes for it. No `ds4-bench` was seen in any
  run (`*.quiet` files).
- **Paths outside git.** Binaries: `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a28` (the final
  candidate, read only, `80f2b704…`), `.a28-q3` (the same file), `.a28-q2` (`34b62314…`), `.a28-q1`
  (`a55adb13…`). GPU traces: `~/zk60-artifacts/a28-traces/`. Samples: `~/zk60-artifacts/a28-tools/samples/`.
  The venv: `~/zk60-artifacts/a28-tools/venv`. Private run data (`~/zk60-owner-private/a28-*`, 0700) and
  receipts (`~/zk60-artifacts/a28-media-app-20261107/`) are deleted after each job (`xrun.sh`, `bi3.sh`,
  `app1.sh`).
- **Scripts.** `stream_driver.py` (`--provers`, page faults), `stream.sh`, `runs.sh` + `*.plan`, `xrun.sh`,
  `xprobe.sh`, `after2.sh`, `after_app.sh`, `byteid.py` + `bi.sh` / `bi3.sh`, `app_driver.py` + `app1.sh`,
  `trace_report.py`, `lane_split.py`, `membw_probe.py` / `membw_report.py`, `writer_time.py`,
  `queue_model.py`, `gpu_align.py`, `lanes.py`, `sample_*.py`, `q1.sh`, `q3.sh`, `accept.sh`, `final1.sh`,
  `rebuild_check.sh`, `nbench/` + `nb.sh` / `nbf.sh`.
