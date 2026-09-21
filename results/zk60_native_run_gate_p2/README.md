# Round 9b — the gate at `rung-P2`, the shape that takes both arms of the pad rule

Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §14.
Ledger: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md` §R9b.

**Nothing here establishes a privacy property and nothing here is a privacy
acceptance.** Both bundles carry `privacy_review_complete: false` and so
does every record.

The bundles are READ-ONLY in the Rust lane's worktree and are never copied
here: `/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`
`run-k-dense-p2` (16.0 MB) and `run-l-zero-p2` (15.9 MB), schema
`hashline-native-capture/5-run`, two blocks, written at lane commit
`4ccbad1`.

| file | what it is |
|---|---|
| `prediction_p2.json`, `predict.log` | what the gate MUST report, computed from the shape and the capture's declared geometry and **committed before the gate was run here** (commit `dfecca3`), validated on the rung-G, rung-K4 and 125M records |
| `run.sh`, `run.log`, `run.done` | the whole gate on both bundles with both opt-in arms (`--full-preimage --mask-cfs`) |
| `run-k-dense-p2.json`, `run-l-zero-p2.json` | the two records of record, 46 of 46 slot checks each |
| `time-run-*.log` | wall clock and peak resident set of each pass |
| `witness_comparison_p2_dense_vs_zero.json` | 136 figures, 120 identical |
| `comparison_table_p2.json` | 180 figures classified against rung-K4 and rung-G: 0 unexplained |
| `before/`, `before.sh`, `refresh.sh`, `diff.sh`, `refresh.log`, `diffs/`, `all_eighteen_records_unchanged.json` | the eighteen records of record re-run under this round's tool bytes and diffed leaf by leaf against the committed ones |
| `m125-dense-9b.log`, `m125-zero-9b.log` (+ `.done`) | the two 125M records of record, re-taken once each under the heavy lock; **read the marker before reading the record** |
| `tests_run_gate.log`, `tests_native_all.log` (+ `.done`) | the suites |
