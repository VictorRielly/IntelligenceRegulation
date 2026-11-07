# A27: the media app's GPU work per proof, cut without moving a receipt byte (2026-11-07)

Lane A27. Goal (Victor, 2026-11-07, away for the weekend): "Focus on implementing the new optimizations into
the proof of concept media app. It would be nice to get the media app speed up to 30 or so tokens per second
for the proofs." A26 left the app's stream at 14.1 proved tok/s and GPU-bound (Device Utilization 83% mean).
This lane's brief: profile the GPU side properly, then cut the GPU time per category proof with
byte-preserving kernel changes: no protocol, profile, receipt, statement, verdict or refusal change.

**Labels:** [MEASURED] a number from a log in this directory; [INFERRED] derived from measured numbers;
[CODE] read from the source.

**Metric** (MVP_STATUS's): proved tok/s = 128 x (category proofs completed) / wall seconds; every receipt
counted was freshly verified (the verifier server, its own process). Public text only.

**Machine:** the M3 Ultra Mac (80-core GPU), shared with the Lean lanes. Every heavy run went through the
resource guard at its default floors, with no `ds4-bench` running (`*.quiet` files, `pgrep ds4-bench`).

## 0. Plain summary

- **The GPU profile, measured per command buffer** (a new trace, `HL_A27_GPU_TRACE`): one category proof kept
  the GPU busy 6.93 s; 59% of it the device sumcheck slots (slot 14 alone 24%, slot 18 21%), 34% the A and H
  commitments, 6% the witness products (section 1).
- **The biggest kernel cost was arithmetic the polynomial did not need to repeat**: 33-41% of the big
  zero-checks' field products evaluate parts that are affine in the tables, at every point of every pair of
  every round. A27 keeps those parts as tables of their own (computed once, folded with the rest) and skips the
  one evaluation point that a slot's attained degree makes redundant. **Slot 14 is 2.3x faster, slot 18 1.7x.**
  Round 2 runs the commitment's NTT two stages per pass (the transform was bound by its threadgroup passes, not
  its multiplies). **One proof's GPU time fell 6.93 → 5.01 s (−28%)** (section 1.1).
- **The 8-post stream: 14.27 → 16.86 proved tok/s (+18.2%) with the pinned binary** (round 2; round 1 alone
  14.05 → 16.41, +16.8%), every receipt freshly verified, A/B pairs in both orders, every pair (sections 3.1,
  3.6). **One post: 46.9 → 44.2 s (+6%)** (section 3.2, round 1). **Proof only: 14.7 → 17.7 tok/s (+21%)**
  (section 3.3, round 1). **Through the app** (single run, against A26's app run): the 8-post stream 13.83 →
  **16.34 proved tok/s**, one post 54.4 → **47.8 s**, one long post 136.9 → 127.0 s (section 3.7).
- **The receipts did not change, byte for byte**: on the real Shieldstral export under fixed test entropy,
  A26's binary, A27's and A27 with every switch off make identical receipts, every file of every category, and
  each verifier accepts the others' (section 4). The six trained profiles' recorded digests (R13 / W16 / W16R2,
  Shieldstral and 8B) hold on CPU and Metal, and the 8B stack's server tests pass on the device.
- **30 proved tok/s is not reached.** The stream is still bound by the GPU's shared throughput: 8 prover lanes
  instead of 6 give the same stream (section 3.5), and the commitments are still 43% of the GPU's work (2.16 of
  5.01 s). What is left is in section 7.
- **The app's `shieldstral-fast` mode now pins the A27 round-2 binary** (`b5b6b9a4…`); 218 app tests OK. Still a
  development candidate: "privacy statement pending", `production: false`. A26's two ruling switches stay off.

## 1. The GPU profile (the A26 tree, the real Shieldstral export, through `zk60_classify serve`)

**How it was measured.** `xctrace` is not installed, so the lane added a diagnostic trace that works in any
build (`HL_A27_GPU_TRACE=<prefix>`, `gpu/metal.rs`): every completed command buffer of the process is written
to `<prefix>.<pid>.tsv` with its call-site tag, a shape detail (a slot's label, tables, cube, degree, rounds; a
commitment's rows and widths), the thread and queue, and the host times it was begun, committed and seen
complete with its `GPUStartTime` / `GPUEndTime` (A7's timestamps, read after completion; nothing the GPU
computed is read; off by default, nothing formatted). `trace_report.py` folds a trace: GPU busy (at least one
command buffer executing), idle gaps, how many ran at once, GPU time per tag, per slot and per commitment
shape. The binary for the profile was A26's tree plus the trace with the A27 kernels switched off
(`zk60_classify.a27-b0`, `p1.plan`); the traces (16,047 lines for the stream) stay outside the repository
(`~/zk60-artifacts/a27-traces/`), the reports are `profile_p1{solo,one,s8}.txt`.

**One category proof alone** (`p1solo`: one public post, one prover lane of 30 threads, its three
categories one after another) [MEASURED, `profile_p1solo.txt`]: **the GPU is busy 6.93 s per category proof**.

| GPU work per category proof | GPU s | share |
|---|---:|---:|
| device sumcheck batches (23 slots x 26 blocks; one command buffer per slot) | 4.19 | 59% |
| &nbsp;&nbsp; slot 14, the D zero-check (64 tables, 2^19, degree 5) | 1.72 | 24% |
| &nbsp;&nbsp; slot 18, the F zero-check (29 tables, 2^21, degree 5) | 1.50 | 21% |
| &nbsp;&nbsp; slots 15, 16, 17 (the Q, KV and softmax zero-checks) | 0.74 | 10% |
| &nbsp;&nbsp; the small slots (0, 1, 3, 4, 20, 21, 22) | 0.23 | 3% |
| commitments: A (4577 x 2^14 -> 2^16) 1.23, H (4390 rows) 1.18, the rest 0.02 | 2.43 | 34% |
| witness products (A4's int16 kernel, the A26 halves among them) | 0.45 | 6% |
| column gathers | 0.01 | 0% |

Per block that is about 66 ms for slot 14, 58 ms for slot 18, 47 + 45 ms for the A and H commitments
[MEASURED]. One lane alone leaves the GPU idle 68% of the time (host work between command buffers).

**The 8-post stream at the app's setting** (`p1s8`: 6 prover lanes x 5 threads) [MEASURED, `profile_p1s8.txt`]:
13.84 proved tok/s (the trace on; A26 measured 14.1 without it). Over the trace's window **the GPU is busy
75% of the time and 6.38 s per category proof** (about the solo figure: the stream is GPU-work-bound), with
2.9 command buffers executing at once on average while busy (up to 6). The 25% idle is mostly gaps of 5 ms or
more (44.9 s of 50.2 s): moments when every lane is in host work at once (the stream's start, while the first
posts' activation writer and sealing passes run, is one of them). Waits from commit to GPU start total 101 s for
the slot batches and 52 s for the commitments: command buffers queue behind each other's work.

**What a slot batch is made of** [CODE, MEASURED with a kernel bench]. One command buffer per slot holds, per
round, the fold of the previous round, the round kernel (one thread per pair and evaluation point), a
partial-sum reduction and the one-threadgroup transcript step. The round kernels dominate: the A27 kernel bench
(`kbench/`, the real slot kernels dumped from the run, `HL_METAL_DUMP`) times slot 14's later rounds at 43 ms
and slot 18's at 31 ms per block. Their cost is the polynomial body (M4g's finding: loads and line values are
about a fifth): slot 14's body makes 502 base-field products per evaluation point and slot 18's 222
(`gen.py`), and **about 40% (slot 14) and 33% (slot 18) of those products evaluate parts of the polynomial that
are affine in the tables** (limb recombinations, the batched linear clauses, the challenge-weighted sums of
dozens of tables) at every point of every pair of every round.

### 1.1 The same profile after A27 [MEASURED, `profile_p2solo.txt`, `profile_p2s8.txt`, `profile_p3solo.txt`; the A27 binaries, the trace on]

| GPU s per category proof | A26 (`p1solo`) | A27 round 1, c1 (`p2solo`) | A27 round 2, c2 (`p3solo`) | change, A26 → c2 |
|---|---:|---:|---:|---:|
| **GPU busy, one proof alone** | **6.93** | **5.36** | **5.01** | **−28%** |
| device sumcheck batches | 4.19 | 2.54 | 2.54 | −39% |
| &nbsp;&nbsp; slot 14 (D zero-check) | 1.72 | 0.73 | 0.73 | −58% |
| &nbsp;&nbsp; slot 18 (F zero-check) | 1.50 | 0.90 | 0.90 | −40% |
| &nbsp;&nbsp; slots 15, 16, 17 | 0.74 | 0.68 | 0.68 | −8% |
| &nbsp;&nbsp; the small slots | 0.23 | 0.22 | 0.22 | — |
| commitments (A, H, the rest) | 2.43 | 2.51 | **2.16** | −11% (A 47 → 42 ms, H 45 → 40 ms per block) |
| witness products | 0.45 | 0.43 | 0.44 | — |
| **the 8-post stream: GPU busy per proof** (`p1s8` / `p2s8`) | **6.38** | **4.91** | — | |
| the stream: GPU busy share of the window | 75% | 70% | — | |

Per block: slot 14 66 → 28 ms, slot 18 58 → 35 ms; after round 1 the commitments were 47% of the GPU's work
(2.51 of 5.36 s), after round 2 43% (2.16 of 5.01 s). In every 10-second window of round 1's stream (`p2s8`)
at least one command buffer executes 46–79% of the time (20% in
the first, while the first post's writer and sealing pass run), and the CPU is about half busy (15 of 32
cores). But more lanes do not raise the stream (section 3.5): it is still bound by the GPU's shared throughput
(its own utilization counter 80% mean, 95% median; every command buffer runs 2.6x longer than alone), so GPU
work per proof is still the lever.

## 2. What changed

Each change computes the same field elements, digests and words as the code before it, and each has a switch
that restores that code (`HL_A27_*=0`, read once per process). The app sets none of them. [CODE; tests in
sections 4 and 5.]

1. **The linear parts of a zero-check as tables of their own** (`private_block/metal_slot.rs`: `lin_plan`,
   `node_pass`, `gen_mat_kernel`; `gpu/metal.rs`: `mat_parts`, `encode_mat`, `encode_xfold`; `HL_A27_LIN`).
   A node of the slot IR of degree <= 1 is an affine function of the tables, `L = k + sum c_t v_t` (a formal
   fact of the graph: `SlotIr::recompute_degrees`). Along a pair's line its value is `L(lo) + d (L(hi) - L(lo))`,
   and folding the table of its values by `r` gives the table of `L` over the folded tables: in exact field
   arithmetic, the same element the kernel computed from the tables' line values, at every point of every round.
   So the device now computes such parts once per cube point before round 0 (`k_sc_mat`, in the same library
   as the round kernels), keeps them in extra tables (`xtabs`, buffer 4), folds them with the slot's own
   tables, and the round kernels read their line values. Which parts: a node of degree <= 1 whose own
   expression makes >= 3 base products and that a node of degree >= 2 or a term uses, and, of a sum node of
   degree >= 2, its subterms of degree <= 1 (at least two, >= 3 base products together; a bare reference to a
   node already materialized not counted). The plan is a function of the graph's structure only. The
   coefficients still come from the one `cf` buffer (all three kernels push them in the same order; asserted).
   The slot's finals are still its own `k` tables'. At the classifier's shape [MEASURED, the trace's batch
   details]: slot 14 keeps 4 such tables, slot 18 4, slot 17 3, slots 15, 16 and 3 one each.
2. **Fewer evaluation points at the attained degree** (`metal_slot.rs`: `evaluated_degree`; `metal.rs`:
   `kernel_de`, `extrapolation_weights`, `extrapolate`; `metal_kernels.metal`: `k_sc_part_reduce`,
   `k_sc_fs_step`; `HL_A27_DEGREE`). A slot whose IR attains a lower degree than it declares (A6's census
   finding; at the classifier slots 14 and 18 attain 4 of a declared 5) has a round polynomial of degree <= 4
   for any table values, so `s(5)` follows from `s(0..4)` by Lagrange extrapolation, exactly. The kernel skips
   the point; the transcript step on the device fills it in (weights in buffer 5), the unbatched path on the
   host, and **the host's replay of every device round recomputes it and refuses the attempt on any
   difference** (beside its s(1) check).
3. **Three-product folds** (`metal_kernels.metal`: `k_fold_tables3`, `k_fold_tables_dev3`; `HL_A27_FOLD`): the
   step `r (hi - lo)` as Karatsuba's three base products (7 bd by doublings) instead of five, and two when the
   step's imaginary part is zero (a base-field table's first fold).
4. **The NTT head's stages 1..6 by powers of 2** (`metal_kernels.metal`: `gl_mul_pow2`, `k_ntt_head`;
   `metal.rs`: `head_pow2_buffers`; `HL_A27_NTT`). A stage-s <= 6 twiddle is a 64th root of unity, and every
   64th root of unity of the Goldilocks field is a power of 2 (2 has order 192), so the head multiplies by it
   with shifts and reductions. The exponents are found on the host among the 192 powers of 2 (a fallback to
   `gl_mul` if one were missing; a test checks they all are found and equal the twiddles).
5. **Round 2: the fused NTT two stages per pass** (`metal_kernels.metal`: `k_ntt_head`, `k_ntt_tail` with
   `r4`, `head_twiddle_mul`; `metal.rs`: `ntt_r4_on`, the thread counts; `HL_A27_NTT4`). Each thread holds the
   four elements `i0, i0 + h, i0 + 2h, i0 + 3h` and applies exactly the two radix-2 butterflies stages s and
   s + 1 apply to them, with the same twiddles (stage s: `k` for both pairs; stage s + 1: `k` and `k + h`): the
   same words with half the threadgroup barriers and round trips; a stage left over runs as before. Found with
   the commitment bench (section 3.4): the transform is bound by its passes, not its multiplies.
6. **The GPU trace** (`HL_A27_GPU_TRACE`, diagnostic, section 1).

**What did not change.** No receipt, statement, transcript, profile, verifier verdict or refusal message. No
edit to `protocol.rs`, `argument*.rs`, `run_fork.rs`, `trained_block.rs`, the PCS, zkp-core or
`src/manifest.rs`; no new source file (the census lists are unchanged). The edits are confined to
`gpu/metal.rs`, `gpu/metal_kernels.metal`, `gpu/mod.rs` (test re-exports) and `private_block/metal_slot.rs`,
with the tests in `private_block/slot_ir_accuracy.rs`'s test module. `HL_A26_KEPT` / `HL_A26_VERIFY_ONCE`
stay off. The device evaluator still runs only after the IR has been checked equal to the slot's closure.

**Negative and small results** [MEASURED, `kb1.log`, `q1.progress`]: line values by additions instead of a
small multiply (`gen.py` v2) help the old kernels but add nothing on top of the materialization; the
power-of-2 NTT stages move a commitment by 0-5% (the transform is not bound by its multiplies, section 3.4).

## 3. Numbers

**What is on the clock** (A24's and A26's definitions, unchanged): the native rows start at the first post and
stop when the last post's third category label is accepted; on them the activation writer, the sealing pass,
the proof, the receipt write (every segment fsync'd), fresh verification in the separate verifier process, the
input-owner check and the label. Server startup (about 35 s per server) is off the clock.

### 3.1 The stream, A/B pairs in both orders [MEASURED, `m1.progress`, `stream_m1*`]

A26 as shipped (its pinned binary `b6336628…`, 6 x 5 prover and 3 x 4 verifier lanes, 16 GiB witness cache,
`HL_METAL_QUEUES=thread`) against A27 round 1 (c1, `ed798413…`, the same settings), A24's 8-post public stream (137 content
tokens, 24 category proofs), order A B B A, one guarded job, no `ds4-bench` at any point:

| run | binary | wall | proved tok/s | second half | first post's latency | s per proof | CPU-s per proof: prover / verifier / writer / all | cores busy | GPU utilization mean / median |
|---|---|---:|---:|---:|---:|---:|---|---:|---|
| m1a1 | A26 | 221.0 s | 13.90 | 16.40 | 65 s | 9.21 | 92.8 / 24.9 / 6.8 / 124.5 | 13.5 | 85% / 96% |
| m1b1 | A27 | 188.0 s | **16.34** | 19.59 | 55 s | 7.83 | 84.4 / 25.2 / 6.9 / 116.5 | 14.9 | 81% / 93% |
| m1b2 | A27 | 186.5 s | **16.47** | 20.18 | 57 s | 7.77 | 84.3 / 25.1 / 6.9 / 116.3 | 15.0 | 80% / 94% |
| m1a2 | A26 | 216.3 s | 14.20 | 17.25 | 65 s | 9.01 | 91.3 / 25.0 / 6.8 / 123.2 | 13.7 | 81% / 96% |

- **The stream: 14.05 → 16.41 proved tok/s, +16.8%** (each A27 run faster than each A26 run: +15.1% to
  +18.5%); the second half 16.8 → 19.9.
- One category proof every 7.8 s instead of 9.1 s. All 24 proofs of every run freshly verified, owner-checked
  and labelled.
- The prover's CPU per proof fell too (92 → 84 CPU-s): less spinning on command buffers (M5d's wait).

### 3.2 One post, A/B pairs in both orders [MEASURED, `m2.progress`, `stream_m2o*`]

A24's one-post setting (3 prover lanes x 10 threads, 3 verifier lanes x 4), one public post of 14 tokens,
its three category proofs at once, order A B B A:

| run | binary | wall (= the post's latency) | proved tok/s | writer | the three proofs at once | the three checks at once (verify) | CPU-s per proof, all | GPU utilization mean |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| m2o1a | A26 | 46.9 s | 8.18 | 10.4 s | 27.9–28.4 s | 8.1 s (7.44–7.47) | 121.2 | 45% |
| m2o1b | A27 | 44.4 s | **8.65** | 10.0 s | 25.8–26.2 s | 8.1 s (7.45–7.46) | 118.8 | 40% |
| m2o2b | A27 | 43.9 s | **8.75** | 10.0 s | 25.7–25.8 s | 8.0 s (7.37) | 119.0 | 42% |
| m2o2a | A26 | 46.8 s | 8.20 | 10.2 s | 27.9–28.4 s | 8.1–8.2 s (7.47–7.49) | 121.7 | 46% |

- **One post: 46.85 → 44.15 s, 8.19 → 8.70 proved tok/s, +6%** (every pair); the three proofs at once −8%.
- One post is not GPU-bound (the GPU 40–46% busy): its time is the three proofs' own critical path (the
  sealing pass, each lane's host work between command buffers, the command buffers' latency), the Python
  activation writer (10 s, a fifth of the post) and the verification (unchanged; it uses no GPU).

### 3.3 Proof only, and verification on another machine [MEASURED, `stream_m2d8*`, single runs, B then A]

The 8-post stream with the verifier server started only after the last proof is written (standing for
verification on another machine); every receipt is then freshly verified, owner-checked and labelled on its
own clock (the verifier's startup excluded):

| run | binary | proof-only wall | **proof-only proved tok/s** | then: verifying all 24 (3 x 4 threads) | verified tok/s |
|---|---|---:|---:|---:|---:|
| m2d8b | A27 | 173.5 s | **17.71** | 66.8 s | 46.0 |
| m2d8a | A26 | 209.2 s | 14.68 | 65.5 s | 46.9 |

- **Proof only: 14.68 → 17.71 proved tok/s (+21%)**; the verifier unchanged (it uses no GPU; A26's 46.9).
  (A26's own run of this clock measured 15.49 for its binary: the single runs vary by about 5%.)

### 3.4 The commitment's kernels, one by one [MEASURED, `nb1.log`, `nbench/`]

The zk commitment at the classifier's A shape (4577 rows x 2^14 -> 2^16, q = 256), each kernel alone in its own
command buffer, GPU timestamps, best of 3, random field words (the tree's `metal_kernels.metal` plus
`nbench/variants.metal`):

| kernel | GPU ms |
|---|---:|
| inverse transform: head (11 stages in threadgroup memory) / tail (3 stages) | 6.18 / 2.87 |
| forward transform, the hiding row's head: as shipped in c1 (power-of-2 stages 1..6) | 22.54 |
| &nbsp;&nbsp; the same without the power-of-2 stages | 22.68 |
| &nbsp;&nbsp; **two stages per pass** (radix 4 in registers; every word equal) | **19.46** |
| &nbsp;&nbsp; its loads and stores alone (a floor) | 6.91 |
| forward tail (5 stages) / **two stages per pass** (every word equal) | 11.59 / **9.47** |
| the column hash (BLAKE3, one column per thread) | 5.48 |
| **sum** (the traced commitment: 49 ms) | **48.7** |

- The forward transform is 70% of a commitment. Its multiplies are not what bounds it: the power-of-2 form of
  stages 1-6 removes three quarters of their multiply instructions and saves 0.6%. Its threadgroup barriers and
  round trips do: running two stages per pass saves 14% of the head and 18% of the tail, about 11% of a
  commitment. That is round 2 (`HL_A27_NTT4`, section 3.6).

### 3.5 More prover lanes do not raise the stream [MEASURED, `m3.progress`, `stream_m3*`, A B B A on A27]

| run | lanes x threads | wall | proved tok/s | second half | first post |
|---|---|---:|---:|---:|---:|
| m3l6a | 6 x 5 (the app's) | 185.6 s | 16.55 | 19.81 | 56 s |
| m3l8a | 8 x 4 | 186.4 s | 16.48 | 27.99 | 62 s |
| m3l8b | 8 x 4 | 185.7 s | 16.54 | 27.90 | 62 s |
| m3l6b | 6 x 5 | 186.9 s | 16.43 | 19.93 | 56 s |

- **6 x 5 and 8 x 4 give the same stream (16.49 against 16.51 tok/s)**; the server refuses more than 8 lanes
  (`classify_serve.rs`). Only the "second half" moves, because with 8 lanes the last posts finish together.
  The app keeps 6 x 5.
- So the stream is bound by a shared resource, not by each lane's latency: the GPU's own utilization counter
  reads 80% mean and 95% median, every command buffer runs 2.6x longer than alone (six lanes share the GPU), and
  the trace's "at least one command buffer executing" is 70% of the window. GPU work is still the lever.
- The A27 6 x 5 stream across all its runs: 16.34, 16.47, 16.30, 16.55, 16.43 and 16.41 (traced) tok/s: a
  stable 16.4.

### 3.6 Round 2 (two NTT stages per pass): the stream, A/B pairs in both orders [MEASURED, `m4.progress`, `stream_m4*`]

A26 as shipped against the round-2 binary c2 (`b5b6b9a4…`, the app's pin), the same settings and stream as
section 3.1, order A B B A, one guarded job (`final2.sh`, after its acceptance and byte identity):

| run | binary | wall | proved tok/s | second half | first post's latency | s per proof | CPU-s per proof: prover / verifier / writer / all | cores busy | GPU utilization mean / median |
|---|---|---:|---:|---:|---:|---:|---|---:|---|
| m4a1 | A26 | 214.6 s | 14.32 | 16.76 | 62 s | 8.94 | 90.8 / 25.0 / 6.7 / 122.6 | 13.7 | 83% / 97% |
| m4c1 | A27 c2 | 181.3 s | **16.95** | 20.87 | 56 s | 7.55 | 83.0 / 25.2 / 6.9 / 115.1 | 15.2 | 80% / 94% |
| m4c2 | A27 c2 | 183.3 s | **16.76** | 20.70 | 55 s | 7.64 | 83.6 / 25.3 / 6.9 / 115.7 | 15.2 | 79% / 93% |
| m4a2 | A26 | 216.2 s | 14.21 | 17.07 | 60 s | 9.01 | 91.8 / 24.9 / 6.8 / 123.5 | 13.7 | 84% / 96% |

- **The stream, A26 → A27 as pinned: 14.27 → 16.86 proved tok/s, +18.2%** (each c2 run faster than each A26 run:
  +17.0% to +19.3%); the second half 16.9 → 20.8. One category proof every 7.6 s instead of 9.0 s.
- Against round 1 (c1, 16.4 in six runs across the afternoon) round 2 adds about 2.7% [INFERRED: different
  jobs on the same box]; its GPU time per proof is 5.01 s against c1's 5.36 (`profile_p3solo.txt`).

### 3.7 Through the app [MEASURED, `app_a2/summary.json`, `app_a2.out`; single run]

The real app in process (`app_driver.py`: A25's driver with `--binary`), `PM_PROVER=shieldstral-fast` with the
A27 pin (c2, `b5b6b9a4…`), A24's three phases on one warm service (one guarded gpu-class job: both servers, the
writers), against A26's own app run (`results/zk60_a26_app_20261107/app_a1`, a single run, not a pair: the A27
app cannot run A26's binary, whose pin it refuses):

| phase | posts | category proofs | A26 app (A26 README) | **A27 app** | change |
|---|---:|---:|---:|---:|---:|
| one short public post | 1 | 3 | 54.4 s, 7.06 tok/s | **47.8 s, 8.03 tok/s** | −12% latency |
| one long public post (3 chunks per category) | 1 | 9 | 136.9 s, 8.41 tok/s | **127.0 s, 9.07 tok/s** | −7% |
| a stream: 8 short public posts at once | 8 | 24 | 222.2 s, 13.83 tok/s (second half 22.6) | **187.9 s, 16.34 tok/s** (second half 23.6) | +18% |

- All 10 posts published (36 category jobs, 0 failed); every label "no", `bound_by_proof: true`; every record
  `shieldstral-fast`, "privacy statement pending", `production: false`, run profile `/2`; each post's signed
  manifest (3 or 9 entries). The service's heartbeat names the binary `b5b6b9a4…`.
- The service was ready 369 s after the app asked for it (the heavy lock behind a Lean lane, then both
  servers' startup); no other heavy job ran beside it, no `ds4-bench` (`app_a2.quiet`).
- (`app_a1`: an earlier launcher of the same run that waited three hours for a free window behind the Lean
  lanes; its directory was pre-created so that, when it fired, it stopped at its first step. Not a measurement.)

## 4. Byte preservation

**The real Shieldstral export under fixed public test entropy** [MEASURED, `bi1.progress`,
`byteid_bi1/summary.json`]: A26's fixed-entropy harness (`results/zk60_a26_app_20261107/fixed_entropy.c`, its
dylib outside the repository; `byteid.py`), one public post, the activation writer run once, then each
binary's prover server proves the three categories into its own directories, in the order A (A26's pinned
binary `b6336628…`), B (A27's round-1 candidate `ed798413…`), B0 (the same A27 binary with every A27 switch off:
`HL_A27_LIN=0 HL_A27_DEGREE=0 HL_A27_FOLD=0 HL_A27_NTT=0`), A again; every server with `HL_METAL_QUEUES=thread`:
- **every receipt file of every category identical in all four runs** (30 of 30 per category: 28 segments,
  the unverified statement, and the owner decommitment compared by hash only); A against A is the harness's own
  determinism control, A against B the byte identity of A27's kernels, A against B0 that of the switches' off
  form;
- **all six cross-verifications accepted** (each binary's verifier on the other two binaries' receipts: verify,
  input-owner, label), 7.1-7.5 s per category, three at once;
- receipts deleted after (public content only; under fixed entropy they hide nothing).

**The same for round 2** [MEASURED, `bi2.progress`, `byteid_bi2/summary.json`]: A26's pin, the round-2 binary
c2 (`b5b6b9a4…`, the app's pin now), c2 with all five A27 switches off (`HL_A27_NTT4=0` too), A26 again: every
file of every category identical in all four runs (30 of 30, 3 categories), all six cross-verifications
accepted.

**The device byte gates** (`accept_t1.progress` on commit `9e1e882b`, and again `accept_t2.progress` on commit
`1f366341`, round 2: every line below passed in both) [MEASURED]:
- M4: every development accuracy shape's seeded block proof, CPU digest = Metal digest (R13 rung LOW, H24 and
  both DD shapes);
- **the six trained profiles' recorded digests, on the CPU and on Metal**: R13 Shieldstral `5a6193d3`, R13 8B
  `f590b01f`, W16 Shieldstral `79f987ef`, W16 8B `a8258241`, W16R2 Shieldstral `0e88d84f`, W16R2 8B `90003b76`;
- the W16R2 rung golden (CPU and Metal), and its A18, A17 and A12 every-setting variants; the 8B block under
  every A18 setting (core proof `90003b760eb7ad80`); A11's per-fork pools and A7's one and six queues on the
  device; A12's device tables word for word;
- **the 8B stack's servers**: A22's R13 export through `stack-serve` = `stack-prove` on the device, A23's with
  shared blocks, and A23's resident 8B stream (blocks shared) replaying;
- the Metal commitment tests against the CPU (`tests/zk60_metal_commit.rs`: plain, hiding and keyed
  commitments, leaves, roots, columns and folds);
- in the test suites (debug and release), slots of at most 2^18 terms are compared on every proof with the CPU
  evaluator, rounds, challenges, folded tables and transcript (`HL_PB_ORACLE`'s default).

**New unit tests** (`private_block/slot_ir_accuracy.rs`): `a27_three_product_folds_write_the_five_product_folds_words`
(random and base-field tables, the edges 0, 1, p - 1, challenges with and without an imaginary part, first and
later folds, both kernels); `a27_extrapolated_round_values_equal_the_evaluated_ones` (every 1 <= de < D <= 7);
`a27_the_ntt_head_twiddles_of_stages_1_to_6_are_powers_of_2` (2^16, 2^17, 2^19, forward and inverse); and the
census `a27_slot_census_at_a_trained_shape` (ignored, prints).

**Why no verdict or refusal can move.** The verifier is not touched (the device runs only in the prover). The
prover's device path computes the same unmasked round values, challenges and finals as before; the host's
replay of every device round now also recomputes the extrapolated values and refuses the attempt on any
difference, so a device fault costs an attempt, never a byte.

## 5. Tests

**Native** (`accept.sh`; `accept_t1.progress` for round 1, `accept_t2.progress` for round 2, the same results)
[MEASURED]:
- the release CLI builds (103 warning lines, as A26's): round 1 `ed798413…` (c1), round 2 `b5b6b9a4…` (c2, the
  app's pin);
- `a27_` 3, `a26_` 3, `a4_` 5, `s25_tests` 20, `hash_domain` 15, `r19b` 5, every `token_io::classify` test (85, 12
  ignored as before; the A24 serve tests among them): all passed; the census lists unchanged (no new file);
- the L9 and L11 test-only exports regenerate their committed corpora byte for byte;
- zkp-core: 83 passed; `cargo check --tests` without the gpu-metal feature: clean;
- every device byte gate of section 4;
- **the full hashline lib suite** (release, gpu-metal, `HL_R13_LOADER_FIXTURES`): **981 passed, 3 failed, 131
  ignored. The three failures are exactly the A23 merge's known ones** (`a_toy_receipt_made_before_f12_is_refused`,
  `accuracy_v2_dense_witness_matches_all_nineteen_independent_integer_traces`,
  `review_n_r6_b_a_stale_statement_writing_dir_is_removed_or_refused_by_name`). (A26: 971 passed; since then
  the three new A27 tests and the merged Lean L17 export tests.)

**The 8B stack** (the same kernels serve `stack-prove` / `stack-serve`): the trained W16R2 8B block's recorded
digest `90003b76` on CPU and Metal, the 8B block under every A18 setting, A23's resident 8B stream and the
R13 export through `stack-serve` all pass on the device (section 4). Its device sumcheck rounds in the trained
test fell 0.084–0.086 s → 0.073–0.075 s per block (`q1_trained.log` against
`results/zk60_effplan_20261105/a23merge_trained.log`; the test's own clock, n = 2, synthetic weights)
[MEASURED]; the 8B stream was not re-measured here.

**App** (the coordinator's command, the `/private/tmp/zk60-astra-app-refresh-20261104-venv` python):
**218 tests OK** (A26's 217 and one new: the A27 pin, never A26's or A24's, the same identity and run profile,
no `HL_A27_*` switch and no trace set by the app, A26's two ruling switches still not set) [MEASURED,
`app_tests.log`].

## 6. Open issues, and what the security owner could decide

1. **Privacy.** Unchanged from A24 and A26: this binary, its GPU execution and its server form are not covered by
   D58; "privacy statement pending", public posts only, `production: false`. D63 holds;
   `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` untouched. The changed GPU files (`gpu/metal.rs`,
   `gpu/metal_kernels.metal`, `private_block/metal_slot.rs`) have new digests: as A7 noted for its own edits,
   they must be re-read at those digests before any GPU-made bundle counts for the privacy gate. What the new
   code does with private values: the materialized tables hold affine combinations of the slot's own tables (the
   same private witness, in the same unified memory, on the local GPU, in pooled buffers whose stale contents
   are never read, as every other slot table); the extrapolation runs on round values the device already
   produced; nothing is printed, kept or hashed. The trace writes only shapes and timestamps, and only when
   `HL_A27_GPU_TRACE` is set (the app never sets it).
   **One timing note for the privacy gate** (like A8's 16-bit fast path): the three-product fold
   (`a27_fold_pair`) takes a two-product path per element when the step's imaginary part is zero. For a
   base-field table that is the table's provenance (every element, a public fact of the shape); for an
   extension table built from a private plane with an extension slice coefficient it happens exactly when two
   neighbouring hidden values are equal, so a fold's GPU time can depend slightly on the private data.
   `HL_A27_FOLD=0` removes it (the five-product kernel, the same words); deciding the path per table from the
   round-0 base flags instead of per element would keep most of the gain without the dependence. The other A27
   kernels branch only on public values (the shape, the plan, the twiddle exponents).
2. **A26's two switches** (`HL_A26_KEPT`, `HL_A26_VERIFY_ONCE`) stay off, waiting for Victor's reading of
   D72/D74; nothing here changes their case.
3. **The power-of-2 NTT stages** (`HL_A27_NTT`) are byte-identical and tested but bought nothing measurable
   (section 3.4); they could be turned off or removed to keep the commitment kernel simpler (both forms are in
   the byte-identity runs: B with them, B0 without).
4. **Commands outside the brief's list:** to keep an in-progress README out of a milestone commit this lane ran
   `git reset -q <one path>` once (an index-only unstage, no branch or commit moved) and later `git restore
   --staged` for files of jobs still running. No push, rebase or checkout.

## 7. What is left to reach 30 proved tok/s

30 tok/s is one category proof every 4.27 s in the stream; A27 makes one every 7.6 s (16.9 tok/s; the second
half about 21). So about 1.8x is still missing.

**Still the GPU's throughput** [MEASURED, `profile_p2s8.txt`, `m3.progress`]: at least one command buffer
executes about 70% of the window and the CPU is about 15 of 32 cores busy, but 8 lanes give the same stream as 6
(section 3.5), the GPU's own counter reads 80% mean / 95% median, and each command buffer runs 2.6x longer than
alone. So the stream needs less GPU work per proof (or a second GPU); the levers, largest first:

1. **The commitments: 2.16 s of a proof's 5.01 s of GPU (43%) after round 2.** The A and H commitments (4577
   and 4390 rows x 2^14 -> 2^16 per block) are now 42 + 40 ms of GPU each (from 49 + 47), still about two thirds
   of it the forward NTT, which is bound by its threadgroup passes, not its multiplies (section 3.4). The next
   kernel steps: a third and fourth stage per pass (radix 8/16 in
   registers), a tile of 4096 words (32 KB of threadgroup memory) so the forward transform's tail has fewer
   stages, and the column hash fused behind the tail. Beyond kernels, A25's W16R2-style rows (rate 1/2, about
   1.8x fewer committed rows than R13) would cut the encode-and-hash work about 3.6x, but need a design step
   and Victor's ruling, then the W16R2 privacy gate on GPU bundles.
2. **The rest of the device slots: 2.54 s per proof.** Slots 14 and 18 are now 28 and 35 ms per block (from 66
   and 58), slots 15-17 about 25 ms together. What is left in them is mostly round 0 (half the cube, five or six
   points), the folds (memory-bound: each round reads every table's two halves and writes one), and the
   materialization pass. A fold fused into the next round, or narrower (base-field) round-0 tables, are the next
   kernel steps; each is byte-preserving by the same argument.
3. **One post's latency** (44 s; not GPU-bound) is the three proofs' own critical path: the sealing pass, each
   block's host work between its command buffers, and the Python activation writer (about 10 s, a fifth of the
   post; in a stream of posts that arrive together it also serializes the start: the first post waits 55 s).
   Overlapping a request's sealing pass with the previous request's proof inside a lane (what A22 did for
   `stack-serve`) is `token_io` server code, outside this lane's brief.
4. **A second GPU or machine.** The receipts are files and the verifier uses no GPU: proving on two machines, or
   verifying elsewhere (the proof-only clock, 17.7 tok/s), scales the stream.

## 8. Operational notes

- **Guard.** Default floors (disk floor 40 GiB; 112-134 GiB free throughout). The Lean lanes queued many short
  jobs back to back; this lane's guarded jobs waited up to about 20 minutes each for the heavy lock (a polite
  launcher waiting for a free window never found one; section 3.7). No `ds4-bench` was seen in any measured run
  (`*.quiet` files).
- **Paths outside git.** Binaries: `~/zk60-artifacts/proven-media-fast/bin/zk60_classify.a27` (pinned, read
  only, `b5b6b9a4…`), `.a27-c2` (the same file, round 2), `.a27-c1` (round 1, `ed798413…`), `.a27-b0` (the profile binary: A26's
  tree plus the trace). GPU traces and kernel dumps: `~/zk60-artifacts/a27-traces/`. Private run data
  (`~/zk60-owner-private/a27-*`, 0700: the posts' activations and owner decommitments) and every receipt
  (`~/zk60-artifacts/a27-*`, the app run's 40 GB of published bundles included) were deleted once their numbers
  were recorded; only the public 64-byte test entropy file is left.
- **Scripts.** `stream_driver.py`, `stream.sh`, `runs.sh` + `*.plan`, `byteid.py` + `bi.sh` / `bi2.sh`,
  `app_driver.py` + `app1.sh` (A26's, with this lane's paths); `trace_report.py` (the GPU trace's report),
  `app_summary.py`; `p1.sh`, `q1.sh`, `accept.sh`, `final1.sh`, `final2.sh` (the jobs); `kbench/` (the
  slot-kernel bench: `main.rs`, `gen.py`, the dumped slot 14 and 18 kernels) and `nbench/` + `nb1.sh` (the
  commitment-kernel bench).
