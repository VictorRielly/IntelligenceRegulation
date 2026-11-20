# Research handoff: which lane settings were ever measured at the app's W16R2 classifier, what one request does on its lane, and the lane-count test (2026-11-20, claude-tick 29)

From Claude, the background researcher. Tick 29, queue item 48 (parts a, b, d; part c dropped as the coordinator's 22:11 UTC note says).

**Scope.** Local reading only: the A24, A26, A27, A28 READMEs, the 2026-11-13 benchmark (`results/zk60_coord_batch2_20261112/`: `REPORT.md`, `run_batch2.py`, the retained prover logs' `served` lines), Astra's `app_stream_timing_20261120/REVIEW.md`, the coordination entries of 22:11:24Z, 22:45:30Z and 22:48:06Z, `deploy.json`, and the source (`classify_serve.rs`, `classify_cli.rs`, `classify_run.rs`, `gpu/metal.rs`). No web search, no run, no build, no Git. The per-request event logs in the owner-private directory were NOT read. Script `20261120-claude-tick29-app-lanes.py` (standard library; reads only the `served` lines) gives every DERIVED number. **Triage material, not a work order.** Everything here is settings or driver level: proof bytes do not change.

Labels: **MEASURED** (record cited), **CODE-READ** (file:line), **DERIVED** (script), **ASSUMED**.

## 0. Headline

1. **No lane count and no thread count was ever measured at the W16R2 classifier except 6 x 5 (the stream) and 3 x 10 (one post).** Every 8-lane, 6 x 8, 6 x 10, 8 x 6 and two-process figure is R13. The app's 6 x 5 was inherited from A24's R13 stream (2026-11-07, `stream_s8b`, shared queue, n = 1 each) and kept by A26 to A28; `deploy.json` carries it for the W16R2 entry with the note "no W16R2 native performance claim".
2. **All W16R2 stream figures (33.3 and 35.5 proof-only, 29.2 with checks, 39.58 lanes-full) were taken with the shared Metal queue, not the app's `HL_METAL_QUEUES=thread`** (coordinator, 22:48:06Z; I did not recheck). The R13 lane comparisons A26 to A28 ran with `thread` queues; A24's ran shared.
3. **A request at W16R2 stretches less from 3 to 6 lanes than at R13** (x1.56 against x1.72, section 2), so W16R2 is less saturated; a two-point model predicts 8 lanes at x1.075 over 6, x1.035 after the bias the same model showed at R13. That sits on the 3% pass line. Lane count is a small lever; the queue mode and the first-wave spacing are the discriminating tests.

## (a) Which settings were measured where

| Setting (lanes x threads) | Profile | Queue | Result | Record |
|---|---|---|---|---|
| 3 x 10 | R13 | shared | 9.02 tok/s (10.07 second half), 8-post stream | A24 §3 table |
| **6 x 5** | R13 | shared | 10.75 (12.69); "the app uses s8b's settings" | A24 |
| 8 x 3 (4 x 2 verifier) | R13 | shared | 10.31 (16.42), "no clear gain", n = 1 | A24 |
| 6 x 5 / 8 x 4 | R13 | thread | 14.32 / 13.95, single runs | A26 |
| 6 x 5 / 8 x 4, ABBA | R13 | thread | 16.49 / 16.51 | A27 §3.5 |
| 6 x 8, 6 x 10, 8 x 6, 2 x (3 x 5) | R13 | thread | 17.20, 16.57, 16.64, 17.06 / 17.87 against 16.73; singles | A28 §3.2 |
| seal-ahead at 6 x 5 | R13 | thread | +1.3% (17.02 to 17.25) | A28 §3.1 |
| **6 x 5 stream, 3 x 10 one post** | **W16R2** | **shared** | 29.22 tok/s with checks, 33.34 proof-only; one post 26.70 s | batch 2 `REPORT.md`; `run_batch2.py:1965-2002` hardcodes these |
| 6 x 5 (Nov 20 trace) | W16R2 | shared | 35.5 window, 39.58 lanes-full | Astra `CADENCE.json` |

MEASURED, retained `served` lines (script §1): request median at W16R2 **13.10 s at 3 x 10 (n = 6) and 20.47 s at 6 x 5 (n = 72)**; at R13 24.13 s and 41.57 s. The 6 x 5 choice was never re-tested against anything at W16R2; 3 x 10 and 6 x 5 differ in threads as well as lanes (R13 alone: 1 x 30 threads 17.9 s, 1 x 5 19.5 s, A28 §3.3), which inflates the W16R2 stretch by up to about 10% [ASSUMED to carry over].

## (b) One request on its lane, phase by phase (CODE-READ)

The lane thread takes a line (`classify_serve.rs:347-369`), runs `serve` inside `pool.install` on its own rayon pool of `--lane-threads`, then `prove_with_public` (`classify_cli.rs:680`):

1. Args, directories, policy, content, honest IN-C inputs, x_in load: one thread.
2. **`seal_chain_keeping`** (`:571`): 26 blocks in series: `build_for_block` (host, rayon over the lane pool: `witness.rs:707` splits by `current_num_threads`; the witness products go to the device), int16, parity, `check_lookup_misses`; keeps each witness within `--witness-cache-gib` (16 GiB per request, `classify_serve.rs:453`; how many of 26 fit is not counted here).
3. OUT-C values, input endpoint seal, statement: host, then the run gate (a no-op with seal-ahead off, `HL_A28_SEAL_AHEAD=0`).
4. `prove_classify_run_with` (`classify_run.rs:185`): its own sealing pass reduces to the kept-block checks and a no-op `seal_check` (`classify_cli.rs:552`); IN-C; then **26 blocks strictly in series on one transcript**, each: block load and check, B_k commitment, witness (the kept one or a rebuild), `prove_core_with` (A commit, about 190 device sumcheck rounds each ended by a blocking wait, host matmul slots, H commit), opening of B_(k-1), segment encode, write to disk; then OUT-C.
5. Owner file, statement, rename.

**Threads.** A request is one thread of control. Rayon sections can use the lane's 5 threads; encoding and waiting for the device are on the request's thread alone, so six lanes wait on the device with six threads. Waiting spins 200 microseconds, then blocks (`metal.rs:1180-1212`, `HL_METAL_SPIN_US=200`). In `thread` mode each calling thread gets its own queue (`metal.rs:831-851`), so a lane's pool threads can hold up to five queues. MEASURED at R13, one lane alone (A28 §3.3): of 21.7 s, 5.4 s waiting for command buffers, 5.5 s serial host, 10.9 s parallel host sections. The W16R2 split is NOT measured; the Nov 20 trace gives only 16.0 s in the 26 blocks (26 x 0.614 s) and 3.4 s outside them (coordinator, 22:11:24Z).

**What could make six lanes fall into step (CODE-READ unless marked).**
- **Equal requests plus a start-only stagger.** Every request is padded to 128 tokens, so all take the same time. `HL_A28_STAGGER_MS=300` spaces *starts* only (`classify_serve.rs:355-366`, one `next_start` mutex); later starts follow each lane's own finish, so the first wave's spacing is carried unchanged. DERIVED: five steps are 1.50 s, and Astra's completion groups are 1.37 to 1.60 s wide. The 3.4 s outside-block part of the six requests then overlaps for 1.9 s with all six lanes in it (script §3). This reading needs no lock and is consistent with the measured group width; it is not a proof of the 21.3% alignment of commit A.
- **Shared Metal queue** (the configuration the trace and the benchmark ran): Antigravity measured completion held until the head command buffer drains (22:45:30Z, 20.97 s of wait). I did not re-derive it; the installed `thread` mode is not what was traced.
- **Process-global host state:** the buffer pool mutex (`metal.rs:386`, `pool_take` scans the free list under the lock), the twiddle and pipeline caches, atomics, and, only while tracing, the trace mutex (`metal.rs:999-1013`; buffered, flushed each second or 64 KiB). No lock is held across a device wait that I found; contention on these is not measured. Host sections stretching x1.4 to x3.7 with six lanes at R13 (A28 §3.3) points at memory traffic, not a lock.
- Between requests a lane waits for nothing: the reader's channel holds `lanes` lines and the writers supply 0.67 requests/s against 0.31 consumed (Astra: every repeat had queued at least 11.1 s), so waves form from the stagger, not from supply.

## (d) The lane-count test, judged

- **Not already run at W16R2.** At R13, 8 x 4 equalled 6 x 5 on whole-stream wall (A27: 16.51 against 16.49; A26 -2.6%, A28 8 x 6 -0.5%, singles). That result is weaker than it looks: with 8 lanes the first wave needs three posts' requests, two lanes wait for the second writer pair (16 s against 7 s), and A27 saw the second half 41% faster (27.99 against 19.81) at equal wall. Whole-stream wall hides a lanes-full difference of a few percent; the coordinator's lanes-full metric is the right one.
- **DERIVED prior at W16R2** (script §2): c(N) = a + bN through 13.10 s at 3 lanes and 20.47 s at 6 gives 8 lanes at **x1.075**; the same model at R13 gives x1.042 against a measured x1.001, so bias-corrected **about x1.035**, at the 3% line and inside run-to-run noise (A27's six 6 x 5 runs span 16.30 to 16.55, 1.5%). Break-even needs a request under 27.3 s at 8 lanes (x1.33 of 20.47); the model says 25.4 s. Upper bound if the period did not grow at all: 52.8 tok/s with the GPU 95% busy (not a forecast).
- **Order:** the queue-mode A/B first (coordinator and Antigravity agree); then lanes on the better mode. 9 x 3 refuses at startup (`classify_serve.rs:444`), withdrawn.
- **Test S-L, stated, NOT scheduled.** Arms 6 x 5, 8 x 4, 8 x 4, 6 x 5 at the better queue mode, stagger as installed, same binary. **Use 48 requests** (16 posts: eight waves of six, six of eight; 24 requests give only 18 and 16 repeat completions). Metric: lanes-full rate from the same-lane repeat periods and GPU busy share from first commit A to last proof. **Pass: at least +3% over the mean of the 6 x 5 arms and a higher busy share. Kill: below +3% or a busy share not higher**, then stop varying lanes. Memory: six lanes peaked near 52 GiB, eight near 70 (DERIVED), inside the 220 GiB cap.
- **A cheaper, sharper companion, driver only:** space the first six request lines 3.2 s apart on stdin (lane period over six is 3.23 s), leaving `HL_A28_STAGGER_MS=300` as installed. A constant stagger of 3.2 s through the environment caps the rate at 40.0 tok/s, 1.1% above the lanes-full 39.58 (script §3), which is why the first wave must be spaced by the driver. Expected at most the 8.65 s of between-request idle (about 10%, coordinator's DERIVED); the pass line is the same.

## Expected effect

Committed words per request: **0** (settings and driver). Proved tokens per second: 8 lanes **+0 to +7.5%, central +3.5%**; first-wave spacing **up to about +10%** (ceiling, not a forecast); neither validated at W16R2.

## Risks and not verified

The two-point model is linear in lanes with two points that also differ in threads; the 3 x 10 point is a one-post run with a different writer count. The queue mode of the 2026-11-13 runs rests on the coordinator's reading of `run_batch2.py`. I did not read Astra's trace or the owner-private event logs, did not count how many of 26 witnesses fit 16 GiB, and did not verify Antigravity's head-of-line measurement. Test S-L and the spacing test are not scheduled.
