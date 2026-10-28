# D address census — reviewable negative result and narrow partial option

Cycle 0083, run `20261019T151854Z-4f2eec2a`. No native patch, merge or
performance gain. Main/Claude owns review and integration.

Single typed-pointer translations do not replace the repeated raw maps:
all nine non-reference instances fail exact address equality. Template 3
needs two raw pointer groups; template 6 needs three, including a group-14
exception. Do not apply the previous proposed uniform-raw shortcut.

Parameter/base translations are exact for the captured public graph.
The partial plan preserves all raw and scratch maps and could eliminate
77+22 u16 index requests (198 logical bytes/row), leaving 436. It adds 18
nonzero call-site pointer shifts with no additional helper arguments. This
would lower shared logical row bytes 9,162→8,964, while field work, 59
tables/folds/finals, scratch and proof obligations stay unchanged. It is not
a DRAM or runtime measurement. Partial native code/stack cost remains unknown;
the previous grouped timing regression remains a reason to keep this low
priority.

Reviewable research files:

- [run.py](../experiments/dzc-affine-address-census-20261019/run.py):
  `translated_plan(q,plan,('load_param','load_base'))` and independent direct
  SSA versus grouped numerical evaluation.
- [partial address plan](../experiments/dzc-affine-address-census-20261019/partial-address-plan.json):
  concrete typed addresses; interpreter deliberately retains the original map
  for comparison. A lowered Rust kernel was not generated.
- [audit.py](../experiments/dzc-affine-address-census-20261019/audit.py):
  separate captured-map matrix census, cost derivation and prior native-field
  scalar oracle.
- [README](../experiments/dzc-affine-address-census-20261019/README.md):
  commands, bounds, carried phase ceiling and full measurement limits.

Actual seam: GPU-lane `hashline/src/private_block/argument.rs:1551`
(`SC_DZC`) into `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`.
If reviewed, replace parameter/base address emission in prior research
`grouping.py::emit`, adjusting each call's typed pointer and keeping raw/
scratch map entries. ABI: `driven(raw,params,bases,out)`, 118 Fp2 endpoints,
129 proof-local Fp2 parameters, 36 canonical u64 parameters, five coefficients.
Use element offsets, not byte offsets. Validate both adjusted pointer and
effective load bounds in the lowered implementation.

Validation: 2,888 symbolic checks, 33 synthetic fixtures / 165 coefficients
per candidate arm, eight controls; separate 187-check audit, three controls,
36 native-field scalar fixtures / 180 coefficients. Main 0.254043 s,
audit 0.098289 s, ≤20,532 KiB measured RSS, one nice-19 Core Ultra 9 185H
CPU0, 59-second/512-MiB caps. All 20 carried source/evidence pins match.
Two initial harness/control assertions are retained with corrections.
No native profile, masks, RNG, transcript, PCS, proof/final verification or
device benchmark ran this cycle.

Owner gates: actual admitted per-layer calibration, fresh parameter and
challenge binding, source-map bounds/alias audit, native samplers and original
fold/final equivalence, seeded proof bytes and RNG/refusals, masked extension
and PCS composition, fresh-process verification/tamper, joint privacy and
enclosing measurements. No additional opening or reused masks. D30's
dictionary is a separate unbuilt profile; D32 fidelity remains mandatory.

Candidate enclosing gain is unknown. Deleting all D for free gives only
1.105058× on the carried R6/b7 CPU T128 diagnostic; this option changes a
strict subset and cannot inherit that bound as its expected gain. No GPU
ceiling or completed resident/decode rate exists. The researcher did not
reverify owner receipts. New target positions: zero.

Next local work: classify immutable public setup across sealing/restart with
the R8 identity/override rules. Prior suffix-witness replay is already known
and memory-limited; avoid rediscovering it or treating input-dependent sealing
as startup. Owner whole-prover GPU and completed resident-pass clocks remain
the most consequential next measurements.
