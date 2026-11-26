# Native arithmetic through all 24 image encoder layers

The native integer implementation matches the unchanged complete N16 reference
through all 24 layers on black, white and coordinate canvases. All 72 layer
comparisons complete, with 2,341,085,184 compared output/intermediate words across
4,392 plane comparisons. Each case begins from the pinned frontend-output fixture.
The native process carries its own computed output into the next layer; it is
never replaced by the reference output between layers.

This qualifies the full encoder's numerical arithmetic on these development
cases. It is **not** a 24-layer proof, an image-task accuracy result, an installed
profile or a privacy/production acceptance. The separate four-stage package
qualifies the first encoder layer's proof. Composing the remaining proof stages,
projector/splice, real image evaluation and soundness/privacy/Lean work remain.

`chain.rs` implements the native N16/QKV prefix and reuses byte-identical qualified
attention, tail and field modules. Its input stream fixes all layer ordinals,
model geometries, matching calibration digests and scale continuity. Layer 13
changes the residual scale from -11 to -4; layer 23 changes it from -4 to -1.
Every model table and unit is checked against the retained metadata audit.

`compare_chain.py` calls unchanged `precision.run_integer` with clamping disabled
for every layer. It derives the remaining witness/remainder planes with the
original exact matrix helpers, verifies them against the full reference trace,
and streams the reference values for direct native comparison. Original integer
classes bound every reference float64 dot partial sum below 2^53. There is no
recalibration, rounding substitution or test-case exclusion.

Each native run compares norm_a/Q/K/V, all 24 attention planes and all 33 tail
planes at every layer. The records retain hashes of all 61 reference planes per
layer, source/model provenance, native stdout/stderr and resource observations.
The pipeline streams approximately 17.44 GiB of reference words over all cases;
it retains no duplicate tensor archive or model arrays in the public repository.

All three original tool sessions (56404, 59644 and 37364) exited zero. Execution
was single-threaded and within existing sandbox permissions, alongside the
guarded proof batch. The combined parent/child peak upper bound stayed below
1.0 GiB. Timings are shared-host functional diagnostics, not benchmarks.

`RESULT.json` and `PACKAGE.json` are the authoritative qualification and frozen
artifact inventory. Per-case reports are in `run-black`, `run-white` and
`run-coordinates`. No main-native/formal/Git changes or publication occurred.
