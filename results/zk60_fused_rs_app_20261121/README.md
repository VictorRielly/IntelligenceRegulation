# Fused RS encoder (`HL_METAL_FUSED_RS`) at the app profile: an independent full-lanes test on the T2 fixture

Run 2026-11-21 15:12 to 16:03 (local, PST) = 23:12 to 00:03 UTC by the A36 agent, from the coordination entries of 2026-11-21T22:21:03Z (rule), 23:09:46Z and 23:42:06Z (reading of the repeat). Labels: MEASURED (`raw/`), DERIVED (`fused_summary.py`'s arithmetic; output in `raw/fused_summary.txt`). Nothing interpreted beyond the posted rules.

**Binary.** Antigravity's commit `f3bd2646` (`agy/fused-rs-encoder`; not checked out), in a detached worktree of my own: HEAD `f3bd26464aad2d55412503d00ff6c1a7dd64bce2`, no source edit. **Deviation:** the sandbox refused `git worktree add` at `.claude/worktrees/t3-fused-rs` (outside my own worktree), so it is at `/private/tmp/claude-501/.../scratchpad/t3-fused-rs`. Release `zk60_classify` with gpu-metal, built under the guard (class build, run `4a83c6989c56`, exit 0, 70 s) with `/opt/homebrew/bin/cargo build --release --offline --locked -j 2 --features gpu-metal --manifest-path <worktree>/ops/zkp-mvp/gpu-metal/hashline/Cargo.toml --example zk60_classify`. **SHA-256 `93e33cbd6c6417141abea979dbfcd5046d1e306030860fbbe11e96c703d61976`.**

**Fixture (T2, unchanged except the switch).** `fused_driver.py` is a thin copy of the lanes-trace driver (itself a copy of `t2_driver.py`): `--bin` names the binary; the switch is `HL_METAL_FUSED_RS` 0 or 1; `HL_A36_CORE_AHEAD` is not set (this base has no A36); every ON leg's receipts are checked by `check-serve` after the leg and deleted, OFF legs deleted unverified. Server per leg (fresh): `zk60_classify serve --export <a29-uniform-calibration/export_u1> --tables <export_u1>/token_io --policies <three> --label zk60-classify-verdict --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only`, `HL_METAL_QUEUES=thread HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0 HL_PB_TIMING=0`; N + 48 = 54 requests over the eight public posts, written at once; rate = 48 x 128 / (c[N+48] - c[N]). The smoke leg (switch off, 6 x 5, N + 6; guard `62a672e9fe14`) ran with no driver change: the server interface of this base matched. The fixture entry was posted at 23:16:01Z before the first timed request. Detached guarded jobs via `fused_launch.py` (`guarded_here.py`), class gpu.

## Set of record, twice (untraced; rates in tok/s)

| set | leg | switch | rate | mean prove call, s | receipts |
|---|---|---|---|---|---|
| 1 (guard `eb24a2825522`, exit 0, peak 58.7 GiB RSS, 22.1 GiB VRAM) | 1 | off | 42.956 | 14.687 | unverified |
| | 2 | on | 44.858 | 14.029 | 54 of 54 checked |
| | 3 | on | 44.780 | 14.020 | 54 of 54 checked |
| | 4 | off | 43.532 | 14.466 | unverified |
| 2 (guard `1b44cef2d0d4`, exit 0, peak 59.0 GiB RSS, 22.3 GiB VRAM) | 1 | off | 43.019 | 14.635 | unverified |
| | 2 | on | 44.335 | 14.065 | 54 of 54 checked |
| | 3 | on | 44.039 | 14.251 | 54 of 54 checked |
| | 4 | off | 43.417 | 14.493 | unverified |

T2's untraced switch-off range on the A36 base was 43.0 to 43.9: all four off legs here are inside it or 0.1% under its low end (set 1 leg 1: 42.956). The 10% stop condition did not apply.

**Pair gains (rate on over rate off, less 1):** set 1: pair (leg 1, leg 2) **+4.43%**, pair (leg 4, leg 3) **+2.87%** (INCONCLUSIVE by the 22:21:03Z rule: neither pair under +1.5% nor both at +3%); set 2: **+3.06%** and **+1.43%** (by itself NO TRANSFER: one pair under +1.5%). Mean of the four pair gains **+2.95%**; the least pair +1.43%.

**Final verdict by the 23:42:06Z reading (mean of the four pair gains; PASS if mean at least +3% and every pair at least +1.5%; NO TRANSFER if mean under +1.5%; otherwise "transfers, under the bar"): TRANSFERS, UNDER THE BAR** (mean +2.95% is under +3%, and one pair, +1.43%, is under +1.5%; the mean is not under +1.5%).

**Correctness.** All 216 switch-on receipts of the two sets (54 per on leg, four on legs) were accepted by `check-serve` (3 lanes x 4 threads, `--min-bits 95`, the prover's statement identity); none failed; every request of every leg was `proved`. (The traced pair's on-leg receipts were also checked, 54 of 54, although the brief only required deletion.)

## Traced pair (off, on; 6 x 5; `HL_A27_GPU_TRACE`; guard `6226d3b93af4`, exit 0), no verdict

Same definitions as the lanes trace (window by begin time between completion N and N + 48; B = 26 x 48; prover buffers = every tag except `wprod`; the union over ALL buffers).

| leg | switch | rate | mean prove call | wall | prover e | q | w | union, all buffers | e: commit rows 2504 | e: commit rows 2606 | e: everything else |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | off | 42.491 | 14.781 s | 568.5 ms | 212.2 ms | 60.1 | 2.4 | 76.2 % | 25.81 | 22.69 | 163.66 |
| 2 | on | 44.589 | 14.084 s | 541.7 ms | 195.2 ms | 51.5 | 2.4 | 75.6 % | 19.68 | 18.28 | 157.23 |

(ms per block unless stated.) Off to on: rate +4.94% (a single pair, traced; not part of the rule), wall -26.8 ms, prover e -17.0 ms (commit 2504 -6.13, commit 2606 -4.41, everything else -6.43). The trace is complete in both legs (last record 0.032 and 0.047 s before the last completion).

## Not measured

The GPU busy share by Astra's capture; other lane counts or the shared queue; private content; the sparse-fold bundle (its own definition is the coordinator's to post); a third set (the posted rule allows none).

## Files and traces

Committed: `fused_driver.py`, `fused_launch.py`, `guarded_here.py`, `fused_summary.py`, `compress_traces.py`, this README, `raw/fused_summary.txt`, the logs, guard receipts and per-leg `t2_results.json` (the `A36` key in them is the driver copy's name for the switch value; the real key is `FUSED_RS`) of `raw/fu_smoke`, `fu_set`, `fu_set2`, `fu_trace`, and the xz-compressed traces `raw/traces/*.tsv.xz` (python lzma preset 6; the `.tsv` originals were round-trip checked and removed):

| file | uncompressed bytes | compressed bytes | SHA-256 of the `.xz` |
|---|---|---|---|
| `fu_trace_leg1.6643.tsv.xz` | 7,674,961 | 650,748 | `e7fdf00eff3111a50fdf26e397bd197024faad86d4453142ab01bae7385f92ae` |
| `fu_trace_leg2.8128.tsv.xz` | 7,674,986 | 649,000 | `b788ab6d5df8cbe734d5a21ddc1de1701566a59d6ffcff9d1bbe1e2cfff1a20d` |

Re-run: `python3 -I -B fused_summary.py raw` (reads the `.xz` directly).
