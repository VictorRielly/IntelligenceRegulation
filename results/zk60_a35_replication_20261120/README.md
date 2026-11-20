# A35 replication by the coordinator, 2026-11-20: REPLICATED

By the Claude co-coordinator. An independent re-run of task A35's measurement
(`results/zk60_a35_bounds_ahead_20261120/README.md`): the commit phase of a served request made before its prover turn
(`HL_A35_BOUNDS_AHEAD`, test arm word `ba1`; off by default, not ruled). No source file changed here.

**Rule, posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 04:53:04Z before the run:** decision arm `serve8+lanes2+ba1`
against `serve8+lanes2`, steady gap per pass, (result[R-2] - result[1]) / (R-3); REPLICATED if lower in 6 of 6 passes and
by at least 3% at the median. The three-lane pair is a first look only.

## Setup [MEASURED unless marked]

- Binary: the A35 agent's test binary `hashline-ee9e07880f531987`, SHA-256
  `092590a2988938786193a27e29ce0caff128484666452e9fc74b77bf900da644`, built from `b0b5cf27` (checked before the run).
- Test `private_block::run::fork::tests::a22::a22_stream_ab`, one process, four arms interleaved, 6 passes, arm order
  reversed in odd passes; environment as `results/zk60_l2_ahead_window_20261120/run_l2.py` (W16R2_8B_T128_H24, 32 blocks,
  6 fork workers, witness budget 32 GiB, oracle off, no GPU trace). Synthetic stack, not trained weights.
- Guard run `0ae1db4e76ef` (class gpu, exit 0, 876 s, peak RSS 41.6 GiB), test result ok, 204 request lines.
  Before the run: heavy lock free, no `ds4-bench`, load average 1.6. Runner `run_rep.py`; logs in `raw/`.

## Result

| arm | steady gap per pass (s), passes 0 to 5 | median |
|---|---|---|
| `serve8+lanes2` | 3.823 3.806 3.823 3.768 3.783 3.829 | 3.814 |
| `serve8+lanes2+ba1` | 3.509 3.561 3.546 3.570 3.559 3.595 | 3.560 |
| `serve9+lanes3` | 3.701 3.754 3.788 3.779 3.735 3.769 | 3.762 |
| `serve9+lanes3+ba1` | 3.519 3.517 3.526 3.519 3.534 3.492 | 3.519 |

| pair (on minus off) | per pass (s) | median | lower in |
|---|---|---|---|
| two lanes (decision) | -0.314 -0.245 -0.277 -0.198 -0.224 -0.234 | -0.239 s (-6.27%) | 6 of 6 |
| three lanes (first look) | -0.182 -0.238 -0.262 -0.260 -0.201 -0.277 | -0.249 s (-6.61%) | 6 of 6 |

**REPLICATED.** The agent's own run gave -4.98% on a loaded machine (guard run `5dee3dc2932b`); this one gives -6.27% on a
quiet one. The test's steady mean (which includes the last request of a pass) goes from 34.07 to 36.27 tok/s at two lanes
and from 34.21 to 36.58 tok/s at three. Footprint peaks are equal with the switch off and on (48.0 / 48.1 GiB and
55.6 / 55.5 GiB, the test's figure).

By request position (medians over passes, two lanes, requests 2 to 6): the forks phase is unchanged (3.45 to 3.57 s off,
3.45 to 3.48 s on); the commit phase takes 0.28 to 0.34 s beside the previous request's forks instead of 0.21 to 0.22 s
inside the prover turn; the sealing pass is 0.06 to 0.17 s shorter. At three lanes the commit phase stretches to as much
as 0.87 s while several requests wait, and the forks phase is still unchanged (3.41 to 3.54 s on, 3.45 to 3.60 s off).

## Not shown

- Shieldstral (R13) profiles, trained weights, more or fewer fork workers, one lane.
- Why the sealing pass is shorter with the switch on [not investigated].
- A GPU trace was not on, so the statement that the commit phase overlaps the previous request's forks rests on the
  request clocks and the code, not on device timestamps.
