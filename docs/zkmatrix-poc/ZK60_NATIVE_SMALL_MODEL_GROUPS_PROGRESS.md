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
- [x] S1 new test-support module with the six cases
- [x] S2 tests
- [x] S3 evidence run under `results/zk60_native_small_model_groups/`
- [x] S4 report section in `ZK60_NATIVE_JOINT_VIEW.md`
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

### 2026-09-20 04:30 — S1..S4 done

`scripts/zk60_native_jv_groups.py` (new; `GroupedToyView(ToyView)` overriding
only `build()` and `hypotheses()`, six case builders, the evidence writer) and
`tests/test_zk60_native_small_model_groups.py` (new; **27 tests**, one a
recorded `expectedFailure`). Evidence
`results/zk60_native_small_model_groups/small_model_groups.json`, 0.5 s.
Report section **§13** of `ZK60_NATIVE_JOINT_VIEW.md`.

The six figures (`n = 4` message columns, so 4 is the toy's analogue of the
review's 256 `Fp` and 8 of its 512):

| # | case | dense | reduction | per-group | expected | observed |
|---|---|---|---|---|---|---|
| a | multi-member, `m = 3,4,5`, 4 draws each | 0 | 0 | 0 | agree at 0 | as expected |
| b | two terminals on one pair, same group | **2** | **0** | 2 | dense > 0 | as expected |
| b' | the same, in two different groups | **2** | **0** | **0** | dense > 0 | as expected |
| c | H-style: two groups, the zero-sum pair | **2** | **2** | **0** | jointly 2 | as expected |
| d | singleton, `Fp`-dependent pair, `cm != 0` | **4** | **4** | 4 | `n` | as expected |
| d' | the same shape in a 4-member group | 0 | 0 | 0 | 0 | as expected |
| d'' | singleton, pair removed (`cm = 0`) | **8** | **8** | 8 | `2n` | as expected |
| e | `lambda_c = 0`, `m = 3,5`, 3 draws each | 0 | 0 | 0 | 0 | as expected |
| f | one opened position beyond the budget | **3** | **refused** (0 unguarded) | 0 | dense > 0 | as expected |

Findings, all three written into §13.5:

- **F-1 (confirms the review's A5, now against THIS gate's reduction).** The
  reduction does **not** see one opened position beyond the pad budget:
  dense 3 `Fp`, reduction 0. The new module's reduction path now **refuses**
  (`PadBudgetRefusal`) on exactly the condition the real-capture path already
  checks (`zk60_native_jv_pcs.py::_check_pad_budget`, fact
  `distinct_opened_columns_within_pad_count`, which feeds stage 2's verdict);
  `disclosed_reduction_unguarded` keeps the finding exhibitable. The guard is
  in the new module for the placement reason above; moving it into
  `ToyView.disclosed_reduction` is a one-line follow-up for the next time the
  gate's evidence is regenerated, and a test pins the old class's current
  behaviour so the difference cannot be forgotten.
- **F-2 (new).** The reduction is blind to pair sharing (dense 2,
  reduction 0): it drops the individual claim values — the collapse `H-pair`
  licenses — and the group vector is unharmed by two members on one pair, so
  `k0` stays 0. The `H-pair` check is the whole defence. First machine
  demonstration of what that check is holding up.
- **F-3 (new).** Sharing ACROSS two groups is invisible to the per-group
  system as well (per-group 0, dense 2), where sharing within one group is
  caught by that group's own system (the review's C1, reproduced at 2).
- **On case (c):** the gate's own `H-pair` check **passes** on the H-style
  sharing, exactly as `audit_claims` does on the real H; the premise that
  fails is cross-group disjointness, reported separately as
  `groups_pairwise_disjoint_off_data`. Jointly the figure is 2 and its span
  equals the sum claim's own data-row weights exactly
  (`rank_disclosed = rank_public_identity = rank_of_both_together = 2`).
  Per group, in the step's own model, it is 0 — wrong.
- **Extra, not owed:** the per-group blinding rank is the review's closed
  form `2(n + m) − 2` for every `m` from 1 to 6, with codimension exactly 2
  (the verifier's identity). Machine-checked for the first time.
</content>
</invoke>
