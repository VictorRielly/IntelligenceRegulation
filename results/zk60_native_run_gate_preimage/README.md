# Evidence: the PREIMAGE for `A` and `H`, 2026-09-21 (round 7)

The RUN gate run with `--full-preimage` on the four current bundles. That
arm — `scripts/zk60_native_rg_ahpreimage.py`, with
`scripts/zk60_native_rg_ahcontrols.py` for its six controls — is the toy
gate's P10 solve (`scripts/zk60_native_pg_pcs.py`) with the message and pad
widths apart, which is what rounds 1–6 meant by "`A` and `H` are skipped,
not faked". Report: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §11.
Ledger: `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`, round 7.
Tests: `tests/test_zk60_native_run_gate_ahpreimage.py`.

**Nothing here is a privacy acceptance and no file here establishes a
privacy property.** What is shown is that the captured LINEAR view of every
PCS commitment is reproducible from a data block that is identically zero,
with blinding this tool solves for and then checks by recomputing the view
entry by entry. That a preimage EXISTS is not the statement that the honest
prover's randomness is uniform on the fibre — which is the lemma's job and
is untouched. `privacy_review_complete` is `false` in every bundle and in
every record here.

**No witness is read anywhere.** No capture carries one. "Dense" and "zero"
below are claims about the Rust lane's test that wrote each bundle (its own
README), not something measured here. The exhibited blinding is a SOLVED
object for a public fixed data block, and the records keep a sha256 of it
rather than its values.

## Clock

Written 2026-09-21. The four runs of record were taken between **05:16 and
05:30 PDT** on the shared WSL laptop, CPU only, one at a time under
`flock /tmp/zk-heavy.lock`, detached with `.done` markers. A first pass
(`run.log`, 05:02–05:14) was taken while the tool was still being edited and
is kept as the log it is; the records in this directory are the second
pass's, and `tool_sha256` in each pins the bytes now in the tree.

## What is here

| file | what |
|---|---|
| `run-{g,h,i,j}-*.json`, `.done` | the four gate records, arm ON (10 PCS commitments each) |
| `time-run-*.log` | `/usr/bin/time -v` for each of the four: wall clock and peak resident set |
| `run.sh`, `run.log`, `run.done` | the first pass (superseded; kept) |
| `run2.sh`, `run2.log`, `run2.done` | the run of record, then the refresh and the leaf diff |
| `mem_probe.py`, `mem_probe.log`, `.done` | the arm's own peak memory, isolated from the four bundles a gate run holds |
| `before.sh`, `before/` | the ten committed records, taken with `git show HEAD:…` BEFORE any refresh run |
| `refresh.sh` | the ten records of record re-run with the arm OFF (round 6's command lines) |
| `diff.sh`, `diffs/`, `all_ten_bundles_unchanged.json` | the leaf diff and its classification — **0 unclassified leaves on all ten** |
| `tests_*.log` | this round's test file, the run-gate suite, the whole native suite |

## The figures, in one table

| bundle | witness | commitments exhibited | view entries compared | differing | salted leaves re-authenticated |
|---|---|---:|---:|---:|---:|
| `run-g-dense-s20` | fully dense generic | 10 / 10 | 1,097,847 | **0** | 2,560 |
| `run-h-zero-s20` | all zero | 10 / 10 | 1,103,569 | **0** | 2,560 |
| `run-i-dense-k4` | fully dense generic | 10 / 10 | 1,282,025 | **0** | 2,560 |
| `run-j-zero-k4` | all zero | 10 / 10 | 1,279,861 | **0** | 2,560 |
| **total** | | **40 / 40** | **4,763,302** | **0** | **10,240** |

Channel table with the arm on: 25 channels, **5 constructed / 5 derived /
4 argued / 11 open** (round 6: 2 / 5 / 4 / 14). With the arm off — which is
the default and what the ten records of record still carry — it is
unchanged at 2 / 5 / 4 / 14.

## Reproduce

```
bash results/zk60_native_run_gate_preimage/run2.sh
python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate_ahpreimage.py' -v
```

The bundles live on the Rust lane's worktree
(`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`) and
are never copied into this repository; only this record is.
