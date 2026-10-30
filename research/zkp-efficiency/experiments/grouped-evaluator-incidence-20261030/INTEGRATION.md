# Dictionary softmax grouping: review boundary

The inspected active and R14 `hashline/src/private_block/argument.rs` have
identical `SC_SZC if sh.dd_cap > 0` bodies, SHA-256
`1836f044a39f07dbcb505d262e4ca758eb3b75c97700096254768c7b32d473eb`.
That arm returns `b.finish(Box::new(poly), hosted)` without `def.groups`.
The following non-DD arm assigns three groups and the slot factory selects
`zkp-core/src/sumcheck/grouped.rs::GroupedEqRounds` when they are present.
These literal source facts are not a global callgraph or performance profile.

Candidate interface: factor the existing DD polynomial as three private,
internal bracket evaluations, with equality points `tau`, `pts.p_ht`,
`pts.p_s`, start zero, and bracket degrees **3 / 1 / 1**. Keep the original
full polynomial, degree-four messages, every table, original MSB folds and
ordered finals. Attach the groups to this DD definition through the existing
`SlotDef.groups` field; `run_slot`/`run_slot_scheduled` already dispatch it.
The mask driver, extension rounds and opening schedule stay with their
existing owners. Group running claims must start as `None` and arise only
from preceding computed unmasked group rounds.

Research patch locations: `dd_projection.py::bracket/expanded`,
`dd_experiment.py::generic_round/main`, and `candidate.py::Rounds` in this
directory. They are Python arithmetic projections, not an applied or compiled
Rust patch. No production source changed. Main/Claude owns native review,
implementation and integration; nothing is merged or queued.

The DD group-zero bracket must retain both Boolean clauses, every paired
range helper, exp helper and keyed tuple helper. In particular preserve
`g_dd + sum + beta*(mask*e) + beta2*p`. Do not omit the dictionary's own
zero-check, range checks, binding, future-pair score checks or independent
host relations. The tests use the default keyed relation; dropping its key
or mask is a negative control, never an optimization. DD padding refusal
remains in the original builder.

Validation here: 16 DD synthetic fixtures, n=0/1/2/3, base/full/zero/Boolean
Fp2 values and challenges, 480 round-value comparisons, 660 folded table
values, 480 ordered finals, 144 independent clause values and two controls.
The generic release/debug evaluator, grouped release/debug evaluator and
original-cube schoolbook tuple-field equations agree. A separate saved-evidence
audit imports neither candidate nor drivers and replays all DD rounds.
References are locally authored, not external reviewers or native verifiers.
This projection uses score shift six, four range lookups, two helper columns,
15 total tables, and synthetic full/short equality points. It does not admit
a model layout, prove host claim offsets, or validate other calibrations.

Baseline source scan/fold counts per row pair, with all 15 original columns:

| Recovery assumption | Generic bracket calls (three groups) | Grouped calls | Fp2 mul | mul_base | add | sub |
|---|---|---|---|---|---|---|
| First round / explicit | 5 / 5 / 5 | 4 / 2 / 2 | 150 -> 114 | 25 -> 18 | 195 -> 148 | 95 -> 80 |
| Later nonzero factors | 4 / 4 / 4 | 3 / 1 / 1 | 123 -> 87 | 20 -> 13 | 171 -> 124 | 82 -> 67 |

These counts include bracket arithmetic, suffix-weight products, weighted
accumulation, interpolation, differences and original-table folds. They
exclude new group prefix/suffix setup, inversions, recovery, polynomial degree
completion, pending values, parallel reduction and all surrounding proof
work. Thus they are not net operation totals, executed instructions or timing.
The n=7/14/23 sweeps are allocation-free counts, not actual model contexts.
Mixed zero-factor fallbacks require their actual per-group costs; no
challenge rejection or resampling makes recovery available.

Required owner gates: source-derived dependencies and degree over every
admitted DD calibration; exact native unmasked and masked rounds, RNG and
transcript continuation; debug and release, zero-prefix/factor fallbacks;
all extension/final/opening/refusal and frozen receipt bytes; fresh-process
complete-stack verification and the current privacy gate. No extra group
messages may be published. Distinct equality factors cannot become one
normalized shared factor. Every proof uses fresh masks/pads/openings as
required by the accepted construction.

Measure exclusive DD slot evaluation, group setup/recovery and actual allocated
capacities before an enclosing A/B under the current shared build/heavy locks.
For complete workload N positions and time T, the ceiling is
`N / (T - C_removed + A_added)`, with both terms unmeasured. Even free deletion
of the whole slot only bounds `N/(T-T_slot)`; T_slot is unknown. Reject on
any native value/byte/refusal/privacy mismatch, no DD incidence in the actual
workload, or added cost at least the saved critical time. The CPU test clocks
do not predict the private 8B high-end GPU rate.

Non-DD negative: public table-use interpolation removes only three Eq columns,
with no unique host-only columns. It overlaps the earlier symbolic Eq proposal.
Do not count it as an additional saving or prioritize it over the DD gap.
