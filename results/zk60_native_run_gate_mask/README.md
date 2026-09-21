# Round 8 evidence — the masking commitment `M` and the CFS channel

Lane `zk60-native-jointview`, 2026-09-21. Report:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md` §12. Ledger:
`docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md` round 8.

**Nothing here establishes a privacy property and nothing here is a privacy
acceptance.** Every figure is a rank, a count or an entry-by-entry
comparison in an explicitly stated LINEAR model, at four captured runs'
real challenges, at two development shapes.

| file | what it is |
|---|---|
| `run-*.json` | the gate's record per bundle, with BOTH arms on (`--full-preimage --mask-cfs`), so `stage12_mask_and_cfs` and `stage13_joint_run_preimage` are computed |
| `toy_equivalence.json` | the port run at the TOY's widths on the tracked toy block capture, against the figures the TOY gate's committed record carries |
| `before/` | the ten records of record as the repository had them BEFORE any refresh, taken with `git show HEAD:...` |
| `diffs/*.diff.json` | each of those ten, diffed leaf by leaf against its refreshed self |
| `all_ten_bundles_unchanged.json` | every differing leaf classified; an unclassified leaf makes the classifier exit nonzero |
| `time-run-*.log` | `/usr/bin/time -v` for each bundle of the run of record |
| `run.sh`, `run.log`, `run.done` | the FIRST pass, taken while the tools were still being edited (stage 13 did not exist yet) — superseded |
| `run2.sh`, `run2.log`, `run2.done` | **the run of record**, on frozen tool bytes |
| `before.sh`, `diff.sh` | the two helpers the run of record calls |

Reproduce:

```
bash results/zk60_native_run_gate_mask/before.sh
bash results/zk60_native_run_gate_mask/run2.sh
python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate_mask.py'
```
