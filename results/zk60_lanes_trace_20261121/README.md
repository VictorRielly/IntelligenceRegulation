# Lanes trace: five GPU-traced stream legs on the T2 fixture (diagnostic only; A36 stays closed)

Run 2026-11-21 16:00 to 16:17 UTC by the A36 agent, from the pre-registration of the coordination entry of 2026-11-21T15:58:07Z (legs, quantities and rules not changed). Labels: MEASURED (the traces and completion times in `raw/`), DERIVED (arithmetic on them, by `trace_summary.py`). No rate claim, no merge decision.

**Fixture.** The T2 fixture exactly: release `zk60_classify` of this worktree (SHA-256 `97cc002bee86794e35055fb063f73367a450c96d9c4896578c6b8e42871e3ea0`, checked before the first leg, not rebuilt), `serve --export <a29-uniform-calibration/export_u1> --tables <export_u1>/token_io --policies <the three> --label zk60-classify-verdict --lanes L --lane-threads T --witness-cache-gib 16 --dev-w16r2-public-content-only`, the T1 environment (`HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0`, `HL_PB_TIMING=0`) with `HL_METAL_QUEUES` thread or shared and `HL_A27_GPU_TRACE=<prefix>_legN` per leg; the eight public posts in rotation, all requests written to stdin at once; receipts deleted unverified. `trace_driver.py` is a thin copy of `t2_driver.py` (a `--spec` list of legs `LANES:THREADS:A36:QUEUES:TIMED`, the trace prefix, the absolute completion times kept; nothing else changed). `trace_launch.py` starts one guarded detached job; `guarded_here.py` is the A35/A36 guard wrapper with this directory's `raw/`. Leg 1 (the smoke) ran alone first, guard `9a07eaa4e924` (exit 0); legs 2 to 5 in one job, guard `4b4d5b20917a` (exit 0; peak RSS 75.8 GiB, peak VRAM 29.1 GiB). The fixture entry was posted before leg 2 (16:02:40Z).

**Trace and mapping.** One line per completed command buffer: tag, detail, thread, queue, begin, committed, gpu_start, gpu_end, done (mach seconds; the same clock as the driver's `time.monotonic`: in every leg the last trace record is 0.025 to 0.039 s before the last completion, so the traces are complete, and every server ended on stdin close with exit 0). Sealing/witness-product buffers = tag `wprod` (queue 99); prover buffers = every other tag (`batch`, `commit`, `gather`, ...). The window is cut by host BEGIN time between completion N and completion N + timed; B = 26 x timed (DERIVED: the timed requests' blocks, 156 for leg 1, 1248 for legs 2 to 5).

## Per leg (`raw/trace_summary.txt`; times ms per block unless stated)

| leg | setting | rate, tok/s | wall | prover e | q | w | u | buffers/block, queues (prover) | sealing e / q / w / u | vs T2's untraced range |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 x 5, off, thread | 11.383 | 343.4 | 96.9 | 12.2 | 3.0 | 22.4 % | 18.49, 1 | 17.3 / 7.8 / 1.1 / 2.7 % | none at one lane |
| 2 | 6 x 5, off, thread | 44.047 | 546.9 | 204.1 | 51.9 | 2.4 | 72.9 % | 18.62, 6 | 13.5 / 19.1 / 1.1 / 9.5 % | 43.0 to 43.9: not perturbed |
| 3 | 6 x 5, on, thread | 39.262 | 619.7 | 245.6 | 150.5 | 2.4 | 65.9 % | 18.55, 12 | 13.2 / 34.3 / 1.1 / 8.6 % | 38.0 to 38.9: not perturbed |
| 4 | 6 x 5, off, shared | 40.982 | 597.0 | 183.8 | 79.6 | 33.1 | 69.6 % | 18.61, 1 | 13.6 / 19.4 / 1.1 / 8.9 % | no T2 reference |
| 5 | 8 x 4, off, thread | 42.896 | 768.8 | 270.9 | 130.8 | 2.4 | 69.0 % | 18.60, 8 | 13.0 / 28.3 / 1.2 / 8.5 % | 44.1 to 46.4: not perturbed |

Mean prove calls (s): 8.929, 14.219, 16.111, 15.522, 19.990 (`wall` = mean / 26). Every request of every leg was proved. Legs 2 to 5 have 54 or 56 requests (N + 48); leg 1 has 7.

## Verdict words by the pre-registered rules (DERIVED)

- **(a) What paces the off stream at six lanes (leg 1 to leg 2): DEVICE-SIDE.** wall 343.4 to 546.9 ms (+203.5); e + q 109.1 to 256.0 ms (+146.9); ratio 0.72, at least two thirds.
- **(b) Why A36 lost (leg 2 to leg 3): DEVICE-SIDE.** wall 546.9 to 619.7 ms (+72.8); e + q 256.0 to 396.0 ms (+140.0); ratio 1.92. With A36 on the job's buffers run beside the block's own (12 queues instead of 6), so e + q is not a share of wall here, as the entry says; the rule uses the difference only.
- (c) Legs 4 and 5 beside leg 2, no verdict, single legs: rate 40.98 (shared queue) and 42.90 (eight lanes) against 44.05; e 183.8 and 270.9 against 204.1; q 79.6 and 130.8 against 51.9; w 33.1 and 2.4 against 2.4; u 69.6 % and 69.0 % against 72.9 %.
- Perturbation: no leg is more than 5% under T2's untraced range (legs 2, 3 and 5); leg 4 has no reference and is reported as it is. Leg 1 has no one-lane T2 reference, so its status is not defined by the pre-registration.

## e per block by tag, legs 1, 2, 3 (the twelve largest; ms per block; the same table is in `raw/trace_summary.txt`)

Tags here are the trace's tag plus its detail string (the slot's label and shape; the detail's tail names the profile and is cut). The largest: slot 18 F zero-check 21.3 / 35.0 / 51.0; slot 14 D zero-check 13.2 / 30.5 / 36.9; the two commitments (A, 2606 rows... and H, 2504 rows) 14.8 / 21.4 / 34.3 and 14.3 / 23.6 / 33.1; slot 17 softmax zero-check (two shapes) 0.3 + 7.3 / 11.9 + 4.8 / 15.0 + 4.9; slot 15 Q zero-check 5.7 / 9.3 / 13.4; slot 19 table-helper zero-check (two shapes) 0.0 + 4.0 / 7.2 + 4.3 / 10.2 + 3.3; slot 16 KV zero-check 1.9 / 5.4 / 7.1. (Some slots split into two detail strings between legs, so a slot's two rows should be added.)

## Not interpreted

Nothing beyond the pre-registered rules. This is `e + q` against `wall` over command buffers by begin time; it does not say which kernel or which queue is the cause, and `u` is the union of the prover buffers' execution intervals only.

## Files

Committed: `trace_driver.py`, `trace_launch.py`, `guarded_here.py`, `trace_summary.py`, this README, `raw/trace_summary.txt`, `raw/tr_leg1*`, `raw/tr_main*` (logs, guard records, per-leg `t2_results.json` under `raw/tr_leg1/`, `raw/tr_main/`, each under 1 MiB). **Raw traces, not committed**, in `/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a3be4019d2dca3765/results/zk60_lanes_trace_20261121/raw/traces/`:

| file | bytes | SHA-256 |
|---|---|---|
| `tr_leg1_leg1.37969.tsv` | 981,916 | `47c4396bd6691814488905df86c6be4d3181f4bcc6290f18186c0467ee8da3f2` |
| `tr_main_leg2.39067.tsv` | 7,649,448 | `ebc1ae0406180a369032ef94c808ba57e234b860f2bad482532c8222a798c58a` |
| `tr_main_leg3.40462.tsv` | 7,624,830 | `c2a5e01411491a34ef5ff8bcd4c9493e5a1d7bb0cc221ac2423dd49f0565a6d4` |
| `tr_main_leg4.42023.tsv` | 7,629,286 | `7c1e0e2f1c0a7a64e07dcdc04871ba066a6ae137ddb1f5ff130bd0d7d375b2dc` |
| `tr_main_leg5.43522.tsv` | 7,927,178 | `332a06de245f65167c908dbfaec9704d541bdf53dc7c6e5dacd537a89a8214e4` |

Re-run: `python3 -I -B trace_summary.py raw`.

## Added by the co-coordinator on the working branch (2026-11-21)

**Files here.** The five raw traces are kept compressed as `raw/traces/*.tsv.xz` (2.6 MiB in all; 31 MiB uncompressed). `trace_summary.py` wants them uncompressed (`xz -dk` each first); `trace_check.py` reads the compressed files directly.

**Independent check.** `trace_check.py` (written by the co-coordinator, sharing no code with `trace_summary.py`; run as `python3 -I -B trace_check.py raw`, output in `raw/trace_check.txt`) recomputes the rate, wall, e, q, w and u of every leg from the raw traces and agrees with the table above to the digit shown. It adds three DERIVED quantities:

| leg | setting | no buffer executing | one | two | three or more | union, all buffers | device work, solo-seconds per second | the same per busy second |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 x 5, off, thread | 74.9 % | 23.9 % | 1.0 % | 0.1 % | 25.1 % | 0.264 | 1.05 |
| 2 | 6 x 5, off, thread | 22.7 % | 16.4 % | 20.7 % | 40.2 % | 77.3 % | 1.021 | 1.32 |
| 3 | 6 x 5, on, thread | 30.7 % | 8.9 % | 13.7 % | 46.7 % | 69.3 % | 0.910 | 1.31 |
| 4 | 6 x 5, off, shared | 26.4 % | 16.4 % | 24.3 % | 33.0 % | 73.6 % | 0.950 | 1.29 |
| 5 | 8 x 4, off, thread | 26.0 % | 8.9 % | 13.2 % | 52.0 % | 74.0 % | 0.995 | 1.34 |

The unit of device work is leg 1's execution time per request, prover and sealing buffers together: 2.968 s (26 x (96.9 + 17.3) ms). "Device work per second" is the requests completed per second times that unit; "per busy second" divides it by the union over all buffers.

**What the added columns say (the co-coordinator's reading; ARGUED from single legs).** In every full-lanes leg the device does about 1.3 solo-seconds of work per second while any buffer is executing (1.29 to 1.34), and the legs differ in how much of the time that is (69 to 77 %). So the pre-registered word "device-side" must not be read as "the device is saturated": at six lanes no buffer is executing for 22.7 % of the window, although each lane has a buffer waiting or executing for 47 % of its block (independent lanes would leave the device empty about 2 % of the time). The lanes are bunched: they are on the host together and on the device together. A36 lost by more bunching (empty 30.7 %), not by more device work (the same 1.31 per busy second). Eight lanes bunch more than six (three or more at once 52 %, empty 26 %).
