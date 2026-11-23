# The composed device bundle on the synthetic 8B stream, merged head (2026-11-23 UTC): CONFIRMED

By the Claude co-coordinator. The two device switches merged on 2026-11-22, the fused RS encoder (`HL_METAL_FUSED_RS`, arm
word `frs1`) and the sparse opening fold (`HL_METAL_SPARSE_FOLD`, `sf1`), both off by default, were timed on the synthetic
8B stream one at a time by Antigravity (-6.2% and -2.8% of the steady gap) and together only at the six-lane classifier
profile (`results/zk60_composed_app_20261122/`). This record times them together on the 8B stream. No source file changed.

**Rule, posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T00:02:52Z, before the timed run:** decision pair
`serve8+lanes2+frs1+sf1` against `serve8+lanes2`; steady gap of a pass = (completion[R-2] - completion[1]) / (R-3);
CONFIRMED AT THE 8B SHAPE if the gap is lower in 6 of 6 passes and by at least 3.0% at the median; NO GAIN if lower in fewer
than 5 of 6 passes or by less than 1.5% at the median; otherwise a gain under the bar. One run. The three-lane pair is a
first look only. Expectation written with the rule: -7% to -9%, steady mean near 36.8 and 39.5 to 40 tok/s.

## Setup [MEASURED unless marked]

- Binary: the lib test binary the merge gate built in the main checkout from the merged tree (source head `fe68a2f9`),
  `hashline-a90b6cf7715dc2a7`, SHA-256 `30ba5501928f888d308c8ebc5549ea62f4c55f8c4290fbede1819258a6cc59fb`, checked by the
  runner before each run.
- Test `private_block::run::fork::tests::a22::a22_stream_ab`, one process, four arms interleaved, 6 passes, arm order
  reversed in odd passes; `W16R2_8B_T128_H24`, 32 blocks, 6 fork workers, witness budget 32 GiB, oracle off, no GPU
  trace. Synthetic stack, not trained weights. Since `f323bb82` an arm with no `ba` word runs with the A35 commit-ahead
  switch on, so the base arms are the merged head's defaults; the STREAM lines print `bounds ahead true` in all four arms
  and `fused rs`, `sparse fold` true only in the two on arms.
- Smoke, one pass, two arms: guard run `63836dc6d56f` (100 s, exit 0). Timed set: guard run `0ea21532060c` (class gpu,
  exit 0, 808 s, peak RSS 42.5 GiB), 2026-11-23 00:02:56 to 00:16:24 UTC, test result ok, 205 request lines. The test
  verified all receipts of pass 0 in every arm (8, 8, 9, 9 and the cold request), 818,728,672 B each in every arm.
  Before the run: heavy lock free, no `ds4-bench`; no agent and no other heavy job ran beside it.

## Result

| arm | steady gap per pass (s), passes 0 to 5 | median | 128 / median | test's steady mean (best) |
|---|---|---:|---:|---:|
| `serve8+lanes2` | 3.480 3.488 3.480 3.432 3.460 3.524 | 3.480 | 36.78 tok/s | 37.15 (37.62) |
| `serve8+lanes2+frs1+sf1` | 3.194 3.194 3.232 3.200 3.230 3.216 | 3.208 | 39.90 tok/s | 40.21 (40.58) |
| `serve9+lanes3` | 3.430 3.463 3.475 3.437 3.413 3.467 | 3.450 | 37.10 tok/s | 37.35 (37.67) |
| `serve9+lanes3+frs1+sf1` | 3.215 3.188 3.202 3.183 3.215 3.163 | 3.195 | 40.06 tok/s | 40.36 (40.51) |

| pair (on minus off) | per pass (s) | median | lower in |
|---|---|---|---|
| two lanes (decision) | -0.286 -0.294 -0.248 -0.232 -0.230 -0.308 | -0.267 s (-7.67%) | 6 of 6 |
| three lanes (first look) | -0.215 -0.275 -0.273 -0.253 -0.198 -0.303 | -0.263 s (-7.63%) | 6 of 6 |

**CONFIRMED AT THE 8B SHAPE.** With both switches the synthetic 8B stream's steady mean is 40.2 tok/s at two lanes and
40.4 at three, against 37.2 and 37.4 at the merged head's defaults. The expectation (-7% to -9%) held. The two separate
results would give -8.8% if they added in full; together they give -7.7%. Amortized means (first request included):
34.06 to 36.66 tok/s at two lanes, 34.46 to 37.10 at three. Peak footprint is equal with the switches off and on (48.5 /
48.6 GiB and 55.8 / 55.9 GiB, the test's figure).

The completion times in the STREAM lines have 0.01 s resolution, so a pass's gap is exact to 0.002 s (0.06%).
`summary_8b.py` reproduces the A35 replication's table from that record's log to that precision.

## Not shown

- Trained weights: the stack is synthetic. The 8B stream figure is a shape figure.
- The six-lane classifier profile (see `results/zk60_composed_app_20261122/` and `results/zk60_lane_threads_20261122/`).
- More fork workers, more than three lanes, the tail-round setting, private content.
- Whether the switches should be on by default: that is the kernel owner's and the reviewer's question, not timed here.

## Files

`run_8b.py` (the runner: one guarded GPU job, hash check, switches stripped from the caller's environment so that only arm
words set them), `summary_8b.py` (`python3 -I -B summary_8b.py raw/set1.log <on>:<off> ...`), `raw/` (logs, guard
records, machine state before and after, `set1_summary.txt`). No receipts and no binaries are kept.
