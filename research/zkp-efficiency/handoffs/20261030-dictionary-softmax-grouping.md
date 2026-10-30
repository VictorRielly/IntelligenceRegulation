# Conditional DD softmax grouping handoff — cycle0168

The current dictionary softmax zero-check still chooses the generic CPU
evaluator. The following non-DD branch already uses grouped equality rounds.
The active and R14 DD bodies match exactly. A locally authored 16-fixture
arithmetic projection reproduces the DD degree-four polynomial with the
existing three-group evaluator (bracket degrees3/1/1), preserving all original
tables/folds/finals. No native proving improvement is measured.

Review [the exact interface, counts, validation and risks](../experiments/grouped-evaluator-incidence-20261030/INTEGRATION.md).
Research implementation: `dd_projection.py`, `dd_experiment.py`, and the
bracket callback in `candidate.py` in that directory. Native patch location:
`hashline/src/private_block/argument.rs`, `SC_SZC if sh.dd_cap > 0` arm,
through `SlotDef.groups` and `GroupedEqRounds::new`. No Rust patch is applied
or compiled. Main/Claude owns review and integration; no merge or job queued.

The row scan/fold census, including equality weighting, removes36 Fp2
multiplies,7 mul_base,47 additions and15 subtractions per row pair in the
score-shift-six projection. Group setup, inversions/recovery, degree completion,
parallel reduction and enclosing work remain unpriced. This is a conditional
candidate, not a net cost or throughput measurement.

Do not weaken the keyed tuple, skip any dictionary relation, publish subgroup
rounds, change masked degree-four messages, reuse masks, or bypass DD padding
refusals. Native masked/transcript/RNG/frozen-byte/refusal/independent full-stack
verification and current privacy gates remain required. First establish actual
DD slot incidence and exclusive cost. Complete private8B >=50 proved tokens/s
on a named high-end GPU remains unachieved.
