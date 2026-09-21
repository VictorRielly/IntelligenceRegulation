# Round 6 evidence — the RUN LAYER's own source pins (finding K4-F2, closed)

**2026-09-21, lane `zk60-native-jointview`.** Report:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §10. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md` §R6. Tool:
`scripts/zk60_native_rg_runpins.py`.

Round 5 found that three of the eight files a run bundle pins in its own
manifest — `run_capture.rs`, `run.rs`, `boundary.rs` — were checked by no
run-gate tool, and that a tool comment said otherwise. This round reads
them at every capture commit and pins them. **No figure about any run
changed.**

## What is here

| path | what |
|---|---|
| `before/` | the ten records of record as COMMITTED, taken with `git show HEAD:…` **before any run**, so the leaf diff is against the committed bytes and not against a file the refresh overwrote |
| `refresh.sh`, `refresh.log`, `refresh.done` | the ten in-scope bundles re-run under the new tools, into the same evidence directory each record of record lives in.  Detached under `flock /tmp/zk-heavy.lock`.  **The first launch died at `run-d-zero` with exit 2 and no traceback**; that bundle was re-run alone (14.4 s, clean) and the remaining six enqueued on the same lock — the log carries all of it |
| `diff.sh`, `diff.log`, `diffs/*.diff.json` | each record diffed LEAF BY LEAF against `before/` (`zk60_native_rg_recdiff.py`) |
| `all_ten_bundles_unchanged.json` | every differing leaf put in a class (`zk60_native_rg_recclass.py`).  **0 unclassified on all ten**; the only differences are the new `run_layer_source_pins` block (46 leaves on a–d, 52 on e–j), two changed tool hashes plus one new one, and one to three wall clocks |
| `tests_runpins.log` | this round's test file — **25 tests, OK**, 28.5 s |
| `tests_run_gate_all.log` | `-p 'test_zk60_native_run_gate*.py'` — **184 tests, OK**, 71.6 s (round 5: 159) |
| `tests_native_all.log`, `.done` | the whole native suite |

## What this is not

Not a privacy acceptance, and no statement here establishes a privacy
property. A pin says which Rust this gate has READ; the reading is a human
reading, recorded next to the digest. Every bundle carries
`privacy_review_complete: false` and so does every record.
