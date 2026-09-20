# `results/zk60_native_privacy_gate/` — the P10 gate's evidence

Produced by `scripts/zk60_native_privacy_gate.py` on branch
`zk60-native-jointview`, 2026-09-20. Read
`docs/zkmatrix-poc/ZK60_NATIVE_PRIVACY_GATE.md` for what the numbers mean and,
above all, for what they do NOT establish. **Nothing here is a privacy
acceptance and nothing here establishes a privacy property.**

> **2026-09-20, later: `privacy_gate.json` was REGENERATED here.** Commit
> `d360466` changed the gate (the masking commitment M's row layout ported)
> without refreshing this record, so what was on disk stayed at the P10
> lane's picture — `version` 1, 8 / 2 / 8 / 10, 7 controls, pre-port
> `tool_sha256` — while every report already quoted the port's numbers. The
> record here is now the current tool's output: **28 channels, 11
> CONSTRUCTED / 2 DERIVED / 8 ARGUED / 7 OPEN**, `version` 2, 10 controls,
> four captures `ok`, 249.1 s, marker `0`
> (`results/zk60_native_gate_record_refresh/gate_refresh_p10.log`). The old
> bytes stay in git history, correct at `825213e`, and `gate_run.log` below
> is that original 179.2 s run. **No number quoted in any report changed**;
> the comparison, key by key, is in
> `results/zk60_native_gate_record_refresh/README.md` and in §15 of
> `docs/zkmatrix-poc/ZK60_NATIVE_JOINT_VIEW.md`.

| file | what it is |
|---|---|
| `privacy_gate.json` | the gate's record: per capture, the model's sizes, the two fixed inputs' preimages with their verification counts and fibre dimensions, the masking commitment's two accountings, the `channels` array (one entry per channel of the privacy case's §2, each with a status), the grade, and the negative controls |
| `privacy_gate.done` | the exit code (`0` = every capture passed) |
| `gate_run.log` | the run's console output (four captures, `--columns full --controls-on all`) |
| `tests_baseline.log`, `tests_baseline.done` | the suite BEFORE this lane: 85 tests, 72.8 s, OK (1 skip) |
| `tests_after.log`, `tests_after.done` | the suite AFTER this lane, with the gate's own tests added |

Reproduce (about 160 s on the WSL box, single core, no GPU and no build):

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate \
  --columns full --controls-on all
```

`--columns N` verifies only the first N opened columns per commitment (a
short pass for development); the evidence above was taken with `full`, so
every opened column value of every commitment was recomputed and compared.

**What the record contains.** Counts, dimensions, ranks, indices, booleans,
digests and challenge-derived field elements. The exhibited randomness
itself is recorded as a sha256 (`exhibited_randomness_sha256`, one per
commitment per fixed input), not as values: the solve is deterministic, so
the digest makes the exhibited object checkable across runs without printing
178,432 field elements. It contains no witness value,
no salt and no private plane — the captures hold no witness, and the gate
constructs prover randomness rather than reading any. The second fixed input
is generated from a published seed and is not private.
