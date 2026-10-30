# Actual evaluator incidence and dictionary softmax grouping

Cycle0168, run `20261030T164123Z-9635c75b`, October30,2026 UTC.
**No measured proving improvement.** This cycle follows actual private-slot
source incidence after the previous cycle found that the legacy CUDA reducer
was absent from the inspected slot evaluators.

The useful new finding is a source gap: `SC_SZC if sh.dd_cap > 0` returns a
generic definition, while the following non-DD arm already attaches grouped
equality rounds. The active and R14 DD bodies match exactly. Factoring that
DD polynomial into three internal brackets, degrees3/1/1, reproduces the
same degree-four round values in the tested projection. This is a possible
use of the existing evaluator, not a replacement proof architecture.

The DD arm passes16 synthetic fixtures: n=0/1/2/3, base/full/zero/Boolean Fp2,
full and short Ht equality points, score shift6, four range lookups and two
helper columns. Generic release/debug, grouped release/debug and independent
original-cube equations agree on480 round values,660 folded table values,
480 ordered finals and144 direct clause values. Missing tuple key and missing
mask controls reject. All15 original tables, their folds and final order stay.
Default keyed semantics only; other calibrations and native refusal coverage
remain untested. The dictionary's own relations are not removed.

The source-level row scan/fold census, including weighting and accumulation,
removes36 Fp2 multiplies,7 mul_base,47 additions and15 subtractions per row
pair. Group setup, inversions/recovery, degree completion, pending/reduction
costs and enclosing work remain unpriced. These are operation counts, not
net costs, executed instructions or speed. See
[the detailed integration boundary](INTEGRATION.md) for the before/after table,
exact interface, source hash, costs, falsification and native owner gates.

The first study is a useful negative: public table-use interpolation passes64
fixtures and12 controls, but the actual non-DD dependency union has no unique
host-only columns. Only three Eq columns can be omitted in that round loop,
overlapping the earlier symbolic Eq proposal. No separate saving is claimed.
It removes no field multiplications, original-table folds or storage here.
Across both arms there are80 fixtures,14 controls and14,924 named check entries;
counts mix arithmetic values, source/dependency facts and census checks.

The separate saved-evidence audit passes2,347 checks. It imports neither
candidate nor experiment drivers and replays DD rounds with independently
written equations, using schoolbook tuple Fp2 and direct original-cube MLEs.
The locally authored references are algorithmically independent, not external
reviewers. No native Rust, cryptographic verifier, CFS mask, transcript, RNG,
PCS, receipt, GPU, race or physical memory test ran.

Reproduce from this research directory:

```sh
python3 -B experiments/grouped-evaluator-incidence-20261030/run_bounded.py experiment
python3 -B experiments/grouped-evaluator-incidence-20261030/run_bounded.py audit
```

The final checking process took1.676428s /22012KiB RSS; audit0.267143s /
18508KiB. Each leaf uses one nice19 CPU affinity,30s CPU/40s alarm/45s parent,
256MiB address-space caps and64MiB estimated memory. Device: Intel CoreUltra9
185H; Python3.10.12; no GPU. Seeds20261030168 and2026103016801. Small cubes
contain synthetic data only. n=7/14/23 studies are allocation-free counts,
not actual model contexts, large allocations or admitted geometries.

`commands.jsonl`, execution JSON/logs, source/reference pins, fixtures, negative
controls and artifact manifests retain evidence. The first audit failed a
JSON-list/tuple conversion; failed source/logs remain under
`initial-audit-list-tuple-failure/`, with the corrected pass retained separately.
An earlier partial DD census omitted weighting and accumulation; its costs/logs
are retained under `before-dd-complete-weight-census/` and superseded by final
`dd-costs.json`. Initial non-DD source versions were reconstructed by reversing
the recorded additive DD patch and are explicitly labeled as reconstructed,
not source captured at initial runtime. The final full replay is pinned.

| Priority | Hypothesis | Integration and falsification |
|---|---|---|
|1 retained|Complete verified high-endGPU fixed-context resident1/2/4/8 workloads|Whole-prover device path, actual fit, exclusive clocks, fresh proof work and independent verification; no inference from kernels.|
|2 retained|Admitted context/DD/fidelity scaling|Keep profile/refusal/privacy and quadratic attention costs; distinguish aggregate independent contexts from decode.|
|3 retained|Exclusive native phases and actual capacities|Measure enclosing critical work, not nested timer sums or requested bytes; profiler perturbation must be controlled.|
|4 new H103|DD softmax grouping through existing evaluator|Moderate bracket extraction; actual DD incidence, degree/calibration, native masked/RNG/transcript/receipt/refusal/privacy gates. Reject any mismatch or added critical costs at least removed costs.|
|Demoted H102|Public interpolation liveness|No distinct host-only columns; saving overlaps existing symbolic Eq work.|

All101 prior hypothesis dictionaries and previous findings/negative results
remain intact. Complete-workload ceiling is `N/(T-C_removed+A_added)`;
required measurements are absent. Counts cannot imply a numerical end-to-end
ceiling. Promising result is handed to the owner in
[the handoff](../../handoffs/20261030-dictionary-softmax-grouping.md); no native
patch applied/compiled, no production change, merge or heavy job queued.

LIVE primary searches cover new older
[Giraffe2017](https://eprint.iacr.org/2017/242) full-cost accounting and
[its implementation README](https://github.com/pepper-project/giraffe),
refreshed [combined sumcheck2026](https://eprint.iacr.org/2026/587),
[Akita's mixed-factor message boundary](https://layerzero-labs.github.io/akita/foundations/eq-factored-sumcheck.html),
[cuPQC0.6](https://nvidia.github.io/cuPQC/releases/v0.6/) and
[zkDuel Oct26](https://arxiv.org/abs/2610.37710). The old Giraffe cost model
supports checking setup and actual incidence before interpreting speed;
its interactive ASIC construction is a different architecture. cuPQC custom
NTT primes remain below2^62, excluding native Goldilocks. Akita's normalized
message rule cannot combine distinct equality factors; no such rewrite is
proposed. No author performance reproduced or external code executed.
Ten qualified source records, dates/unknowns, licenses and failures are in
`sources-cycle.json`, appended1122->1132 to the durable ledger. Giraffe's
GPL3-or-later README notice was inspected, full LICENSE/history fetches failed;
no source was adopted. Exposed tracker hashes are not inspected commits.

New independently verified full-stack proofs / complete-model passes / proved
positions: **0 / 0 / 0**. Actual context:none; device:one CPU affinity,noGPU.
Witness/proof/serialization/verification/startup/initial-prefill clocks,
startup fraction,proof latency/bytes,steady-state and total-workload rates:
**unmeasured**. No long-context prefill,resident proof series or decode ran.
Larger workloads remain permitted; attention can grow quadratically.
Complete private8B **>=50 proved tokens/s on RTX5090 or another named high-end
GPU remains unachieved**. No mask,pad or private-opening reuse/weaker privacy.

Next local experiment: source-derived admitted score-shift/range-descriptor
and shorter Ht spans for DD grouping, retaining every clause and original
degree. Next owner experiment: actual DD incidence/exclusive group and slot
costs, then native byte/refusal/privacy/fresh complete-stack gates under current
shared build/heavy locks. Preserve the owner's R14 freeze/review work.
Only research outside runtime written. Saved reports are not notifications
or evidence of supervisor/job liveness.
