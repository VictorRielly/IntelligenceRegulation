# The harness stream at the installed Shieldstral profile: NOT RUN (the fixture refuses the profile), 2026-11-20

By the Claude co-coordinator. No source file changed.

**In one line: the stream test cannot run at `W16R2_SHIELD_T128_H24` without a change to the test sources. The two
tests I had posted for it (S2a, S2b) have no result. The 8B control leaf of the same sequence ran and gives one more
sample of A35 at 8B: 3.774 s off, 3.552 s on.**

## What was attempted and why

Research tick 28 proposed running the harness stream (`a22_stream_ab`) at the app's profile and block count
(`research/zkp-efficiency/handoffs/20261120-claude-tick28-shield-repair.md`, test S2). It would have given the A35
switch at the installed profile and a like-for-like figure beside the app's own stream (3.839 s per request
proof-only on 2026-11-13). I checked that the test looks its profile name up in `W16R2_PROFILES`, which lists the
Shieldstral profile, posted a correction of my earlier "needs a test change" and a rule
(`ops/zkp-mvp/RECOVERY_COORDINATION.md`, 19:54:17Z), and launched. **That correction was wrong**; retracted at
19:55:30Z.

## What happened [MEASURED]

- Leaf `shield26` (guard run `a08410be6546`, class gpu, `HL_D55_PROFILE=W16R2_SHIELD_T128_H24 HL_D55_L=26`): exit 101
  after 4.7 s, peak 1.1 GiB, nothing proved. The test panicked at `run_fork_tests.rs:3664`, "a W16R2 test-only run
  identity": the fixture takes its run profile from `W16_TEST_RUN_PROFILES` (`w16_privacy_gate_tests.rs:76`, five
  entries), and the W16R2 Shieldstral block profile has none.
- Leaf `ctl8b32` (guard run `dc7876922dc4`, exit 0, 230 s, peak RSS 32.8 GiB, test ok): `W16R2_8B_T128_H24`, 32
  layers, 6 fork workers, 3 passes, arms interleaved and reversed in the odd pass. Before it: heavy lock free, no
  `ds4-bench`, load average 3.8.

| arm (8B, 32 layers) | steady gap per pass (s) | median | this morning's replication |
|---|---|---|---|
| `serve8+lanes2` | 3.764 3.776 3.774 | 3.774 | 3.814 |
| `serve8+lanes2+ba1` | 3.552 3.492 3.554 | 3.552 | 3.560 |
| on minus off | -0.212 -0.284 -0.220 | -0.220 s (-5.83%), lower in 3 of 3 | -0.239 s (-6.27%), 6 of 6 |

The control is within 1.0% of this morning's figure (the posted line was 3%). It controls nothing here, since the
Shieldstral leaf did not run; it stands as a third sample of the A35 switch at 8B (the agent's -4.98% on a loaded
machine, the replication's -6.27%, this -5.83% over three passes).

## What the Shieldstral stream run needs

A sixth entry in `W16_TEST_RUN_PROFILES` for the W16R2 Shieldstral block (a test-only run identity), with whatever
`s33_tests.rs` checks over that list (it reads the list at lines 81 and 96), and a rebuild of the test binary. Test
sources only; not started, not scheduled.

**What it would probably show [DERIVED, not measured]:** the two W16R2 blocks cost the same on the GPU and have the
same slots (`results/zk60_w16r2_shield_block_20261120/README.md`), so 26 Shieldstral layers should give about 26/32
of the 8B stream: 2.9 to 3.1 s per request. The app's own stream is the measurement that would add information.

## Files

`run_stream.py` (the runner, two guarded leaves one after the other), `analyze_stream.py` (steady gap per pass from
the `A22-AB STREAM` lines; applied to the A35 replication's log it reproduces that table to 0.001 s), `summary.json`,
`raw/` (logs, guard records, the status before each leaf).
