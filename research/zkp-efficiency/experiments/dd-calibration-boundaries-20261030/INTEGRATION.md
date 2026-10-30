# DD grouping calibration and row-span handoff

This extends H103 from cycle0168. It validates arithmetic boundaries; it does
not demonstrate native proving speed. The owner reviews and implements it.

The actual seam is `hashline/src/private_block/argument.rs` at
`SC_SZC if sh.dd_cap > 0`, through `SlotDef.groups` to
`zkp-core/src/sumcheck/grouped.rs::GroupedEqRounds`. Both the active tree and
R14 final-working-tree DD bodies are identical in this read. Full-file hashes
and original paths are in `native-pins.json` and `owner-read-pins.json`.
The existing non-DD branch shows how to attach `EqualityGroup` and `GroupPoly`.
No Rust patch was applied, compiled or merged.

Expose three INTERNAL bracket evaluations with points `tau`, `pts.p_ht` and
`pts.p_s`, all `start=0`, bracket degrees **3,1,1**. Keep slot degree **4**,
all original tables, MSB folds and ordered finals. `pts.p_ht` covers the row
prefix, not necessarily the whole score cube. Keep the native builder's
`hosted = [(SC_RS,nu0*per_row),(SC_SCORE,nu1)]`, with
`per_row=|Dom::S|/|Dom::Ht|`. Do not seed group claims from asserted host sums.
The saved independent audit checks this multiplicity on all160 fixtures.

For an admitted score-shift value `sh` (the source window is1..8), preserve:

| Quantity | Exact value |
|---|---|
| Score reconstruction | `2^sh*S8 + RSL - 2^(sh-1)` |
| Four U8 lookups, in order | `127+S8`, `127-S8`, `RSL`, `2^(8-sh)*RSL` |
| Range helpers | two paired helpers, never an omitted duplicate at sh8 |
| Keyed tuple | `g_dd + Sum + beta*(mask*E) + beta^2*P` |
| Group0 | all Boolean, range, exp and tuple clauses |

Retain DD geometry/padding refusals. Testing a shift in the structural window
does not admit a calibration/profile or replace its fidelity/security review.
The experiment is a15-table arithmetic projection. Owner R14's separate
native census reports14 terminals on DD slot17; those are different counts.
No native opening-order or claim-offset equivalence follows from this test.

Research patch: `dd_projection.py::config/bracket/expanded` parameterizes the
three shift-dependent constants, retaining the prior source-derived equations.
`candidate.py::Rounds` is the unchanged locally authored grouped projection.
`experiment.py` checks generic release/debug and grouped release/debug against
expanded original-cube equations. `audit.py` is a standalone ungrouped replay;
it imports no candidate or local reference modules. See `local-provenance.json`.

Validation:160 fixtures, shifts1..8, n0..3, every Ht span0..n, full Fp2 and
Boolean values/challenges, row-sliced MX/Sum. All6400 round comparisons,
9360 folded values,4800 ordered-final comparisons and960 clause values match.
There are344 recovered group claims and184 exact-zero fallbacks, with no
resampling. All54 negative controls fire: missing key/mask/helper, stale
range/score/half constants, bracket degree2, and extended Ht equality.
The standalone audit passes27026 checks, including all saved1600 distinct
round samples,2400 terminals, lookup membership and host reconstruction.
Its control audit checks saved unequal outputs; it does not rerun mutations.
These are locally authored references, not external review or a proof verifier.

The counted row scan/fold saving remains the earlier **36 Fp2 multiplies,
7 mul_base,47 adds,15 subs per row pair**; all eight shifts have identical
bracket API counts. This cycle adds no distinct saving and does not add it
to prior non-DD symbolic-Eq savings. Group setup, inverse/recovery, degree
completion, pending values, parallel reduction, dispatch and whole-proof work
remain unpriced. CPU checking clocks are not native benchmark clocks.
The complete-workload ceiling `N/(T-C_removed+A_added)` is unknown. Even free
whole-slot removal needs exclusive `T_slot` for `N/(T-T_slot)`. A required
50/s condition is `T-C_removed+A_added <= N/50`, for the actual workload.

Owner gates, under current shared build/heavy locks: establish actual DD
incidence and exclusive slot/group clocks; native unmasked AND masked rounds,
RNG/transcript continuation, extension/PCS/opening/final order, debug/release,
degree/lookup/refusal and frozen receipt parity across admitted calibrations;
fresh-process complete-stack verification and current privacy gate. Do not
publish subgroup values, merge distinct equality factors or reuse private
masks/pads/openings. No causal/future-score checks or dictionary obligations
are removed. Reject on any mismatch, absent incidence or added critical cost
at least the avoided cost. Preserve the owner's R14 freeze/review work.

Next local experiment, if owner native evidence is still unavailable: profile
the public source scaffold's suffix-Eq setup, inverse/recovery and interpolation
operation counts across actual slot dimensions, including mixed zero factors
and short-Ht tails. Price the excluded work before inventing another scan win.
