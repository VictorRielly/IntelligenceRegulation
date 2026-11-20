# L2: A13's window (`HL_D55_AHEAD`) on the prover-paced stream, 2026-11-20

By the Claude co-coordinator, covering the speed lane. Test L2 of research tick 24
(`research/zkp-efficiency/handoffs/20261120-claude-tick24-host-only-inventory.md`, section 4). No source file changed.

**Verdict: the window does not pass at any size tried (4, 8, 16, 32). The switch stays off.** Both pass rules were
posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` before their runs (03:56:33Z and 04:07:47Z).

## Setup [MEASURED unless marked]

- Test `private_block::run::fork::tests::a22::a22_stream_ab`, one process per run, arms interleaved, 6 passes, arm order
  reversed in odd passes (`HL_D55_AB_ALTERNATE=1`). Environment as Batch 7 and A33: `HL_GPU=1 HL_GPU_REQUIRED=1
  HL_PB_ORACLE=0 HL_METAL_TIMING=0 HL_D55_PROFILE=W16R2_8B_T128_H24 HL_D55_L=32 HL_D55_WORKERS=6 HL_A19_BUDGET_GIB=32
  HL_A22_AB_PASSES=6`; no GPU trace. The stream is the D55 harness's synthetic stack, not trained weights.
- Binary: A33's merged patched test binary `hashline-4ff65cafe9d88959`, SHA-256
  `c54517e2514d4498b4c9cb0471309a178058ba411ddec1a38cf834002c4f8913` (checked before each run).
  `git diff --stat 732756f3 HEAD -- ops/zkp-mvp/gpu-metal` was empty, so it is the working branch's prover.
- Guard, class gpu: run 1 `d6e69de757a5` (exit 0, 466 s, peak RSS 52.3 GiB), run 2 `cf6b66ae3a32` (exit 0, 862 s,
  peak RSS 45.0 GiB). No `ds4-bench` before or after either run. Load average before: 2.9 (run 1), 3.2 (run 2, started
  three minutes after run 1 ended). During run 2 a reading agent (A35, stage 1) was active on the machine.
- Scripts: `run_l2.py` (the guarded leaf), `launch_detached.py`, `l2_terms.py` (run 1's terms), `l2_steady.py`
  (steady gap). Outputs: `L2_TERMS_run1.md`, `L2_STEADY_run1.md`, `L2_STEADY_run2.md`, `raw/`.

## Run 1: four-request streams, decision arm `serve4+ahead16`

Rule: PASS if the cadence, (result[3] - result[0]) / 3, is lower in 6 of 6 pass pairs and by at least 3% at the median;
KILL if within 1% at the median or the admission wait does not fall.

| arm | cadence median (s) | pairs lower | median difference | admission wait (s) | footprint peak (GiB) |
|---|---|---|---|---|---|
| `serve4` | 3.765 | | | 0.871 | 73.7 |
| `serve4+ahead8` | 3.685 | 5 of 6 | -1.75% | 0.803 | 76.1 |
| `serve4+ahead16` | 3.690 | 4 of 6 | -2.21% | 0.863 | 81.2 |
| `serve4+ahead32` | 3.752 | 3 of 6 | +0.41% | 0.867 | 87.4 |

**Not a pass (4 of 6, -2.2%), and killed on the admission wait (0.871 to 0.863 s).** By request position the steady
prove call is unchanged at 16 (3.843 and 3.881 s without a window, 3.853 and 3.874 s with it) and 0.10 to 0.13 s longer
at 32; only the last request of a pass, which has nothing beside it, gains (3.520 to 3.343 s). The cadence difference is
that end effect.

Exploratory only: at window 8 the middle gap (result[2] - result[1]) was lower in 6 of 6 passes (median -0.13 s). The
arm and the measure were chosen after seeing the data, so run 2 tested it.

## Run 2: eight-request streams, decision arm `serve8+lanes2+ahead8`

Rule: measure the steady gap per pass, (result[6] - result[1]) / 5. PASS if lower in 6 of 6 and by at least 3% at the
median; KILL if lower in fewer than 5 of 6 or within 1% at the median.

| arm | steady gap median (s) [min-max] | pairs lower | median difference | footprint peak (GiB) |
|---|---|---|---|---|
| `serve8+lanes2` | 3.803 [3.774-3.890] | | | 66.1 |
| `serve8+lanes2+ahead4` | 3.824 [3.775-3.931] | 3 of 6 | +0.07% | 67.3 |
| `serve8+lanes2+ahead8` | 3.811 [3.764-3.880] | 4 of 6 | -0.25% | 68.7 |
| `serve8+lanes2+ahead16` | 3.899 [3.799-3.925] | 1 of 6 | +1.09% | 72.5 |

**KILL (4 of 6, -0.25%). Run 1's hint at window 8 did not replicate.** At 16 the steady gap is 1.1% longer and the
sealing pass beside a proof 0.07 to 0.23 s longer.

## What this shows and does not show

- The window moves the before-challenge part of a block (A build, A commit, M commit) into the sealing turn. On this
  stream that work comes back as a longer prove call beside it. The tick's model term "S + W + P unchanged" does not hold
  for work that uses the GPU. [DERIVED from the tables; no GPU trace was on, so the mechanism is not shown directly.]
- Base-arm facts used by task A35 [MEASURED, run 2, requests 2 to 6]: prove call 3.73 to 3.87 s, of which the serial
  commit phase 0.21 to 0.23 s; sealing pass 3.0 to 3.2 s beside a proof and 1.89 s alone; a sealed request waits 0.34 to
  0.49 s for the prover.
- Not shown: anything at three lanes, at Shieldstral, on trained weights, or with a different number of fork workers.
  Six passes per arm; pass-to-pass spread of the steady gap is about 0.1 s (3%).
