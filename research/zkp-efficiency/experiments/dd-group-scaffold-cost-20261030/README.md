# DD scalar scaffold and selected-profile gap — cycle0170

Run `20261030T184123Z-46af51dd`. **No measured proving improvement.**

The main result is a scope correction. Current R14 LOW/LOW+h24 profiles enter
`argument_accuracy.rs::szc_dd` through an early dispatch in `argument.rs`.
The legacy DD branch text matches the earlier branch, but that is insufficient
to establish its incidence for the selected profile. The actual accuracy path
uses `precision.score = base.score + 12`, three remainder limbs, six lookups
and three helpers. Its 14 private terminals plus three equality tables and a
public causal mask make 18 tables. The prior 15-table, four-lookup, two-helper,
shift1..8 synthetic tests validate the **legacy projection only**.

The saved source control shows why this matters: for synthetic base shift6,
derived shift18, score2 and remainder limbs[3,4,1], the actual host expression
is459779; the stale legacy expression is99. No private model data is used.

The bounded experiment completes the legacy scalar arithmetic census:
split equality tables, factors/prefix updates, inversion/recovery, degree
completion and group running claims, alongside the original scans/folds.

| Legacy projection | Generic base products | Grouped base products | Count change |
|---|---:|---:|---:|
| Synthetic n7/span4, nonzero recovery |97,995|105,494|+7.65%|
| n19/span12, nonzero recovery |381,433,875|279,881,762|−26.62%|
| n19/span12, all recovery falls back |381,433,875|317,884,829|−16.66%|

n19/span12 matches public T128/32-head dimensions, **not the selected LOW+h24
relation or its costs**. n21/n23 rows are also dimension-only projections;
no new 8B DD profile is admitted. Expanded base products use current source
API arithmetic: five products per Fp2 multiplication,127 per base inversion
and132 per Fp2 inverse. They are neither machine instructions nor timings.
Compiler constant folding may remove public arithmetic. The synthetic count
crossover at n8 is not a runtime threshold. At n19, scalar extra work is159565
products and peak split-Eq logical payload34304B. Rayon reduction, allocation,
dispatch, locality and enclosing proof time remain unmeasured.

New H105 batches the base norms of eligible nonzero factors. It retains `None`
for zero/ineligible factors and the original singleton path. For three factors,
it replaces three Fp2 inversions with one base inversion and24 base products.
At legacy n19 it saves36 base inversions but adds162 base products, net4410
products:0.0011562% of the counted legacy baseline. The known batch method
already exists elsewhere natively; this is a new incidence study, not a new
algorithm. It is too small to justify a standalone native port.

Validation: both inverse arms replay160 saved synthetic fixtures,3200 round
values and4800 ordered finals.160 inversion fixtures include every64
zero/eligibility pattern and96 random/base arrays, checked against a separate
exponent-p²−2 reference. All8 mutation controls fire. The standalone audit
imports neither driver nor candidate and passes11422 checks, including direct
original-cube equations, expanded count formulas,21 pins and the actual
profile-dispatch negative. Recorded mutation labels are checked, not independently
reexecuted. Both references are locally authored; this is not an external
review, native cryptographic verification or privacy proof.

```sh
python3 -B experiments/dd-group-scaffold-cost-20261030/run_bounded.py experiment
python3 -B experiments/dd-group-scaffold-cost-20261030/run_bounded.py audit
```

Seed20261030170. Main0.518977s/24056KiB; final audit1.174219s/21624KiB RSS.
Intel Core Ultra9 185H, Python3.10.12, one nice19 CPU affinity;30s CPU,
40s alarm,45s parent,256MiB address-space caps,64MiB estimated memory. No
native build or GPU ran. Earlier passing audit is retained before the extra
profile-incidence checks. No failed experiment/audit occurred.

Baseline/removed/added/ceiling/falsification: actual selected DD is still
generic. Factoring may remove repeated bracket evaluations and interpolation
scans. Charge all scalar and nonfield costs; exclusive native phase fractions
are absent. Complete-workload ceiling `N/(T-C_removed+A_added)` is unknown.
Reject any selected-path, table/lookup/degree/host, value, byte, RNG/transcript,
refusal, final/PCS or privacy mismatch, absent material incidence, or added
critical cost at least removed cost. No mask, pad or private-opening reuse.
H39 finite-difference interpolation overlaps scalar reductions; no additive
speed claim is made.

Rank1: independently verified high-end GPU resident1/2/4/8 full-stack work.
Rank2: admitted context/DD/fidelity scaling with full quadratic attention.
Rank3: exclusive native phases and actual capacities. H103 remains conditional
priority4, now requiring actual accuracy-path differential first. H105 is
demoted. All104 prior hypothesis dictionaries and negative findings remain.

Sources searched LIVE include the newly inspected older
[author chapter](https://www.joppebos.com/montgomery/book_ch1.pdf) (publisher
online2017-10-25), [zkDuel](https://arxiv.org/abs/2610.37710) (Oct26,2026),
[extended sumcheck](https://eprint.iacr.org/2026/587),
[Efficient Sumcheck](https://github.com/compsec-epfl/efficient-sumcheck),
[cuPQC0.6](https://nvidia.github.io/cuPQC/releases/v0.6/) and NVIDIA's binary
arithmetic boundary. Eight source records include dates/unknowns, license-label
limits, AMS403 and commit429; no inspected commit or reproduced author gain.
Native batch inversion was already assessed in cycle0108. Web content was
treated as data; no foreign script/code executed.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual context:none; passes0; device:one CPU,no GPU. Witness/proof/serialization/
verification/startup/initial-prefill clocks, startup fraction, proof latency/
bytes, steady-state and total-workload proved-token rates: **unmeasured**.
No long-context prefill, resident-model proof series or decode ran. Larger
workloads remain allowed; attention may grow quadratically. Complete private8B
**>=50 proved tokens/s on RTX5090 or named high-end GPU remains unachieved**.

Next: actual accuracy DD18-table/six-lookup/three-helper source projection and
full round/fold/final differential; then its own census and owner exclusive
clocks/native gates. See [handoff](../../handoffs/20261030-dd-scaffold-current-profile-gap.md).
No production/Git/runtime/receipts/calibration/gates/instructions/reviewers were
modified; no external writes/messages, installations, purchases or escalation.
Main/Claude reviews and integrates; no merge. Saved reports are not delivery.
