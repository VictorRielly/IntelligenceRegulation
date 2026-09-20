# Evidence: the RUN gate, 2026-09-20

The privacy-consistency gate for a MULTI-BLOCK RUN capture.
Tool: `scripts/zk60_native_run_gate.py`. Report:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`.

**Nothing here is a privacy acceptance and no file here establishes a privacy
property.** Every number is a rank, a count or a digest of an explicitly
stated LINEAR model, at one captured run's real challenges, at ONE
development shape. The hash layer is argued, not computed.

## Files

| file | what |
|---|---|
| `run-a-tame.json`, `run-b-zero.json` | the gate's machine-readable record, one per bundle: integrity, replay, per-commitment, the boundary, the zero-data preimage, the controls, the channel table |
| `run-a-tame.log`, `run-b-zero.log` | the gate's console output (one line per stage) |
| `run-a-tame.done`, `run-b-zero.done` | `0` = the gate passed |
| `*.gate.done` | the detached wrapper's exit code |
| `tests_baseline.log` / `.done` | the test suite BEFORE this lane's work: 161 tests, OK |
| `tests_after.log` / `.done` | the test suite after: the same 161 plus this lane's |
| `tests_run_gate.log` / `.done` | this lane's own tests alone |
| `toy_unchanged.json` | the two toy gates re-run after this lane's work, diffed against their committed records field by field (timing excepted) |

## Input, read-only and NOT copied here

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-a-tame`
and `.../run-b-zero`: two independent honest three-block runs at the
development rung (24 tokens, width 96, hidden 192, 6 query heads over 2
key-value heads; 1,024 columns, inverse rate 4, 256 opened columns), schema
`hashline-native-capture/4-run`, source commit `cb27845d`, about 38.5 MB
each. `run-a-tame` is on the lane fixture's hidden input, `run-b-zero` on the
all-zero one; neither hidden input is in its bundle.

## Commands

```
python3 scripts/zk60_native_run_gate.py \
  --bundle <bundles>/run-a-tame --other <bundles>/run-b-zero \
  --evidence results/zk60_native_run_gate
python3 scripts/zk60_native_run_gate.py \
  --bundle <bundles>/run-b-zero --other <bundles>/run-a-tame \
  --evidence results/zk60_native_run_gate
```

About 9 s per bundle on the shared laptop, CPU only, single process; the
largest exact rank is 308 x 3,761 over Goldilocks (the whole run as one
system), about 1 s, and the largest single-matrix computation is the pad
block, 247 x 256, about 3.7 s.

## The headline figures, both bundles

* replay: the run binding, 375 recorded transcript positions and all 6,086
  challenges re-derived; nothing left un-re-derived;
* per commitment, all three stages: `A` 0, `H` 2 (the public LogUp
  identity), each external endpoint 0, each internal boundary 0, each
  masking commitment 0; every certifying minor nonsingular; 243..251
  distinct opened columns inside 256 pads;
* the boundary, restricted to its reserved rows: rank **6 of 6**, disclosed
  **0**; the three roles of one boundary plane: joint 0 = sum of the parts;
  the whole run: 308 x 3,761, joint 6 = sum of the parts;
* controls: a shared reserved pair gives rank 4 and **disclosed 2**, a
  single proximity row rank 5 and **disclosed 1**, a shared blinding row
  raises the joint from 0 to 1,024 while the marginals stand still, a
  swapped claim source and a foreign stage file are both refused.
