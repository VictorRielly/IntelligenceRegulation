# ZK60 — small-model opening GROUPS: ledger

**Lane** `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`.
**Opened** 2026-09-20 03:55 PDT. **Scope** review change **R-8** (accepted by
the security owner in `ZK60_JOINT_LAW_COMPOSITION_DISPOSITION.md`, ruling
block "J-2 is resolved"): the joint-view gate's own small model has **one
opening group per claim**, so the case the real receipts actually use —
several claims batched into ONE group by a challenge `lambda` — was never
machine-validated, and neither was a group whose members share a reserved
mask pair.

**NOT a privacy acceptance.** Everything here is a rank of an explicitly
stated linear model on a synthetic, public toy instance. No receipt, no
capture, no Rust source is touched.

## Rules this lane works under

- Sole writer in this worktree. Everything else on the box is read-only.
- Python only. No cargo, no builds, no GPU.
- **Additive.** The 112 existing tests stay green and both gates' outputs on
  the four real captures stay unchanged.
- Evidence holds counts, dimensions, indices and booleans only.

## The six cases owed (each: the tool's reduction vs a DENSE rank)

| # | case | what it is for |
|---|---|---|
| a | multi-member group, `m >= 3` batched by `lambda_c` | the case the real receipts use and the small model never had |
| b | shared pair, two ordinary terminals | marginals unchanged, joint moves with the data |
| c | H-style legitimate sharing (two groups, one zero-sum pair, public identity) | why the exception exists |
| d | wrong pair shape (base-field-dependent weights, `cm != 0`) | the condition that carries privacy is the SHAPE |
| e | `lambda_c = 0` for one member | must NOT disclose (soundness refusal, not a privacy one) |
| f | one opened position beyond the pad budget | the reduction's dependence on H-pad |

## Status

- [x] S0 ledger skeleton, baseline test run
- [ ] S1 new test-support module with the six cases
- [ ] S2 tests
- [ ] S3 evidence run under `results/zk60_native_small_model_groups/`
- [ ] S4 report section in `ZK60_NATIVE_JOINT_VIEW.md`
- [ ] S5 both gates re-run, JSON compared with the committed evidence

## Log

### 2026-09-20 03:55 — S0 opened

Baseline: 112 tests, `OK (skipped=1)`, 161.7 s (the run of 2026-09-20 02:36
recorded under `results/zk60_native_privacy_gate/tests_after.log`); re-run
here as `results/zk60_native_small_model_groups/tests_baseline.log`.

**Placement decision.** `scripts/zk60_native_jv_smallmodel.py` is one of the
nine files whose SHA-256 the joint-view gate writes into its record
(`zk60_native_joint_view.py::TOOLS`), and
`test_zk60_native_joint_view.py::GateRecord` asserts
`rec["tool_sha256"] == gate.tool_hashes()`. Editing it would therefore change
the committed `results/zk60_native_joint_view/joint_view.json`, which this
lane is forbidden to do. The extension goes into a NEW module,
`scripts/zk60_native_jv_groups.py`, which is not in `TOOLS` and which
**subclasses** `ToyView`, so the reduction and the dense map under test are
the existing tool's own code, unmodified.
</content>
</invoke>
