# A28: the media app's commitment kernels and the GPU's idle gaps (2026-11-07, resumed 2026-11-09)

**STATUS: WORK IN PROGRESS.** This file is written as the lane goes (the first session was cut off on
2026-11-07 19:11Z; the Mac was rebooted on 2026-11-09 and the lane resumed that day). Sections marked PENDING
are not measured yet. Nothing here is pinned in the app until section 3 says so.

Lane A28. Goal (Victor, 2026-11-07): "Focus on implementing the new optimizations into the proof of concept
media app. It would be nice to get the media app speed up to 30 or so tokens per second for the proofs." A27
left the app's stream at 16.9 proved tok/s. This lane's brief has two parts, both byte-preserving: (1) the
commitment kernels (43% of a proof's GPU time after A27); (2) the GPU's idle gaps in the stream (scheduling and
server code only). No protocol, profile, receipt, statement, verdict or refusal change.

**Labels:** [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers;
[CODE] read from the source.

**Metric** (MVP_STATUS's): proved tok/s = 128 x (category proofs completed) / wall seconds; every receipt
counted was freshly verified (the verifier server, its own process). Public text only.

**Machine:** the M3 Ultra Mac (32 CPU cores, 80-core GPU), shared with the Lean lanes. Every heavy run went
through the resource guard at its default floors, with no `ds4-bench` running (`*.quiet` files,
`pgrep ds4-bench`).

## 1. The profile first (A27 as pinned, the 8-post stream at the app's setting)

[MEASURED, `p0.plan`, `profile_p0s8.txt` (the GPU trace, `trace_report.py`), `profile_p0s8_lane0.txt` /
`profile_p0s8_lane4.txt` (macOS `sample` of the prover for 60 s, `lane_split.py`), `stream_p0s8/`.]

- **The GPU.** Over the trace's window (173 s, 24 proofs) at least one command buffer executes 65.8% of the
  time: 113.9 s, 4.75 s per proof, the same as one proof alone (5.01 s, A27's `profile_p3solo.txt`). So the
  device serves the lanes' command buffers by sharing its time: 2.4 execute at once on average while it is
  busy, each takes 2.4x as long as alone, and the work done is the sum of the solo work. The other 34% of the
  window (59 s) no command buffer executes. Command buffers also wait 106.7 s between commit and start (4.4 s
  per proof), 23.6 s of it the witness products, which all went through ONE shared queue.
- **A prover lane's own thread** (the thread that runs a request, 6 lanes x 5 threads): **32% of its time
  waiting for its command buffers, 23% in serial host work (its four other threads idle), 46% in parallel
  host sections.** Per 38 s request: 12 s waiting for the GPU (2.4x the 5 s the device needs for it), 8.6 s
  serial, 17.4 s parallel. The serial part is a long tail: `__bzero` of the A and H rows 5.2%, the
  classifier tables' BLAKE3 digests 4.3% (three per request), the segments' SHA-256 1.6%, page unmapping 1.3%.
  The parallel part: the openings' host folds 6.6%, each block's CS-6 digest 4.2% and CS-1 / CS-4 word checks
  3.8% (the two that A26's `HL_A26_KEPT` would take from the startup; it stays off), the witness planes 2.9%.
- **A model that fits** [INFERRED, `queue_model.py`]: N lanes that each alternate host work (Z seconds per
  proof, no queueing) and the one device (S seconds per proof, time-shared) form a closed queueing network.
  With Z = 11 s serial + 70 CPU-s parallel / threads and S = 5.0 s (fitted on two runs: one lane of 30 threads
  18.4 s per proof, six lanes of five 38 s) it gives 25.5 s for three lanes of ten (measured 25.8-26.2 s) and,
  at the app's 6 x 5, a 37.1 s lane cycle with the device 81% utilized and 12.1 s of GPU wait per proof
  (measured 38 s and 12 s). **What it says:** the stream already runs at about 80% of the device's bound
  (one proof per 5 s of GPU: 25.6 proved tok/s steady). Host-side and scheduling changes can win at most the
  remaining 20%, with diminishing returns; every further gain needs less GPU work per proof.

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
3. **`HL_A28_WQ`** (default on; `gpu/metal.rs` `witness_queue`): under `HL_METAL_QUEUES=thread` each thread's
   witness products go to a queue of its own instead of the one shared witness queue.
4. **`HL_A28_CALLOC`** (default on; `private_block/protocol.rs` `zeroed_rows`, two call sites): A's and H's
   zero rows from the allocator's zeroed pages instead of a serial fill by the proving thread. `Fp` is
   `repr(transparent)` over `u64` and its zero is the zero word.
5. **`HL_A28_SEAL_AHEAD`** (`token_io/classify_serve.rs`, `classify_cli.rs` `SharedProve::run_gate`): a lane
   takes a second request while its first one runs; the second request's sealing pass runs beside the first
   one's run and its run waits at the lane's gate. The reader sends each request to the least loaded lane (an
   idle lane first, never a third to a lane). Each request is still `prove_with_public` from its first step to
   its last on one thread, with its own fresh draws; only when its run starts changes.
6. **`HL_A28_STAGGER_MS`**, **`HL_A28_QOS`** (default off; `classify_serve.rs`): a minimum interval between
   request starts, and the user-initiated quality of service for the lane threads. Diagnostics.

**What did not change.** No receipt, statement, transcript, profile, verifier verdict or refusal message. Files
outside `gpu/` and `token_io/classify_serve.rs`: `private_block/protocol.rs` (`zeroed_rows` and its two call
sites, implementation only), `token_io/classify_cli.rs` (the run gate: one field of `SharedProve`, one lock
taken before the run), `token_io/classify_batch.rs` (that field's `None`), `private_block/slot_ir_accuracy.rs`
(one test). No new source file. `HL_A26_KEPT` / `HL_A26_VERIFY_ONCE` stay off.

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
- So the commitment has about 4 ms of 42 left in these two changes, and no more in this design.

## 3. Numbers

**What is on the clock** (A24's definition, unchanged): the native rows start at the first post and stop when
the last post's third category label is accepted; on them the activation writer, the sealing pass, the proof,
the receipt write (every segment fsync'd), fresh verification in the separate verifier process, the
input-owner check and the label. Server startup is off the clock.

### 3.1 The first two candidates, 6 x 5 lanes [MEASURED, `q1s.progress`, `q2s.progress`, `stream_m1*`, `stream_m3*`]

A27 as pinned (`b5b6b9a4…`) against the first candidate (a28-q1, `a55adb13…`: seal-ahead with one shared
request queue) and the second (a28-q2, `34b62314…`, commit `5794c756`: seal-ahead with the least-loaded lane
dispatch), the 8-post public stream at the app's setting, order A B B A in one guarded job each, 2026-11-07:

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
- **The second candidate at the app's 6 x 5: 17.02 -> 17.25 proved tok/s, +1.3%** (each a28-q2 run faster than
  each A27 run; the single runs of this stream vary by about 2%). Seal-ahead moves 5.7 s of a request's host
  work beside the previous run, but the lane's cycle shortens only from 39.0 to 37.6 s: the sealing pass also
  uses the device (the witness products) and the lanes' cores, and the stream is already at 80% of the device's
  bound (section 1). It costs 60 GiB (a guarded peak of 163 GiB against 103 GiB) and 11 CPU-s per proof.
- Without seal-ahead the candidate measured 16.73 (one run): the kernel changes' 4% of GPU work is inside the
  runs' spread.
- A7's spin-then-block wait (`HL_METAL_SPIN_US=200`) frees 23 CPU-s per proof at the same speed; the 300 ms
  stagger measured +2% once; the QoS class changed nothing.

### 3.2 PENDING: lane threads, the final candidate, one post, proof only, through the app

## 4. Byte preservation

**The real Shieldstral export under fixed public test entropy** [MEASURED, `bi_q1.progress`, `bi_q2.progress`,
`byteid_bi_q*/summary.json`]: A26's fixed-entropy harness (`results/zk60_a26_app_20261107/fixed_entropy.c`, its
dylib outside the repository; `byteid.py`), one public post, the activation writer run once, then each binary's
prover server proves the three categories into its own directories, in the order A (A27's pinned binary), B
(the candidate), B0 (the candidate with `HL_A28_PRUNE=0 HL_A28_HASH=0 HL_A28_WQ=0`), A again; every server with
`HL_METAL_QUEUES=thread`, three lanes of ten threads (one category a lane, so no two requests share a lane here). For both candidates: every receipt file of every category identical in all four runs,
and all six cross-verifications accepted (each binary's verifier on the other two's receipts: verify,
input-owner, label). PENDING: the same for the final candidate, with `HL_A28_CALLOC=0` and both seal-ahead modes
in B0.

**Gates on a28-q2** [MEASURED, `q2.progress`]: the new commitment test at the classifier's shapes (plain,
hiding and keyed rows at 2^14 -> 2^16 with 4577 and 4390 rows; leaves, roots and columns, CPU = Metal);
`tests/zk60_metal_commit.rs` 5 passed; the A24 serve tests 5 passed (seal-ahead on); `s25_tests` 20,
`hash_domain` 15; the six trained profiles' recorded digests on CPU and Metal (`5a6193d3`, `f590b01f`,
`79f987ef`, `a8258241`, `0e88d84f`, `90003b76`).

**The binary is the committed tree's build** [MEASURED, `rebuild_q2.progress`]: the hashline crate recompiled
at commit `5794c756` gives `34b62314…` again, bit for bit.

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
- **Paths outside git.** Binaries: `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a28-q1`, `.a28-q2`.
  GPU traces: `~/zk60-artifacts/a28-traces/`. Samples: `~/zk60-artifacts/a28-tools/samples/`. Private run data
  (`~/zk60-owner-private/a28-*`, 0700) and receipts (`~/zk60-artifacts/a28-media-app-20261107/`) are deleted
  after each job (`xrun.sh`).
- **Scripts.** `stream_driver.py`, `stream.sh`, `runs.sh` + `*.plan`, `xrun.sh`, `byteid.py` + `bi.sh`,
  `app_driver.py` + `app1.sh`, `trace_report.py`, `lane_split.py`, `queue_model.py`, `gpu_align.py`, `lanes.py`,
  `sample_*.py`, `q1.sh`, `accept.sh`, `rebuild_check.sh`, `nbench/` + `nb.sh` / `nbf.sh`.
