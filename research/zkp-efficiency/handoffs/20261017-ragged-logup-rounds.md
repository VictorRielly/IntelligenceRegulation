# Research handoff: public padding, factor supports and bit placement

2026-10-17, cycle 0069. Unapplied; owner review and integration required.
No native proof, GPU result, privacy acceptance or measured proving gain.

Research code: `experiments/ragged-logup-rounds-20261017/ragged.rs`.
The function `rounds(public_positions, three_factor_values, cube, challenges)`
returns degree-three round samples at 0,1,2,3, three ordered finals, and public
pair-visit counts. It uses native captured Goldilocks Fp2 arithmetic, native
MSB pairing and canonical sorted public support. Challenges are externally
provided fixture inputs; this is not a Fiat–Shamir protocol. Refuse duplicate,
unsorted and out-of-cube indices, wrong round count and non-power-of-two cubes.
CPU BTreeMap is an arithmetic oracle, not a proposed CUDA data structure.

Actual seam: `ops/zkp-mvp/gpu-zerocheck/zkp-core/src/sumcheck/rounds.rs`,
`SumcheckRounds::{n_vars,degree,round,fold,finals}` and `prove_rounds`.
The function can be split into that stateful adapter: `round` builds the
structural pairs and returns unmasked samples; `fold` consumes the driver's
challenge and projects the public support. Keep the existing transcript masker,
round label, challenge draw, original table order and caller-owned extension,
terminal and opening checks. No native trait adapter was built in this lane.
Lookup integration separately touches `private_block/protocol.rs` lookup/H
construction, `argument.rs` original ordered links and `shape.rs`/`layout.rs`
H/M/PCS schedules. Captured source paths and SHA-256 pins are in `native-pins.json`.

Measured local validation: 94 synthetic fixtures, 1,424 round values, 282 final
factors, 1,600 mask values and 23 controls. Independent audit: 5,185 checks.
Main 2.038 s including compile, 22,404 KiB; rustc 134,544 KiB; audit 0.552 s,
17,724 KiB. One Core Ultra 9 185H CPU0 thread, nice19, seed2026101769, <60 s /
512 MiB per experiment. Full logs and exact commands retained. No native proof
or real private data was read. First passing revision also retained.

Useful result: column-first MSB padding immediately mixes into all remaining
nodes, so it saves zero pair visits on minimally padded rectangular domains.
Row-first MSB keeps dummy columns separable through row rounds. Counted 8B T32,
four groups: 17,842,172 -> 11,714,587 pairs (34.3433% fewer). This is a new
batched-lookup layout, not a byte-preserving reorder of a frozen native proof.
Both layouts individually match dense polynomials; matched data and permuted
terminal coordinates have equal initial sums and three equal final factors.
Public support may compact only fixed public shape padding, never hidden
prompt length, hidden selectors, witness zeros or private mask rows.

The negative controls matter: zero Boolean products need not remain zero off
the cube (`[1,0] * [0,1]` gives `X(1-X)`); never replace factor support by
support of their pointwise product. S~ is not Boolean at a random terminal;
do not drop its final factor. Raw virtual evaluations still disclose private
values. Whole-cube CFS masks cannot be summed only over compact base support.
No new mask sites can be discharged by uniform-marginal arguments or mask reuse.

Before promotion, factor public equality/support data without constructing
full E/S tables or an index map. The naive four-group sum is 625.625 MiB for
indices plus three factors before tree scratch; it is not measured peak.
One full E array alone is 178.75 MiB. Binding all83 original ordered columns,
distinct initial-point reduction, wrapping-i64 correctness, table refusal
semantics, GKR, fresh masks, private final openings and whole-run soundness
must be designed and costed. Existing H is not simply deleted; no new query
commitment is saved. The earlier 19.5 s direct H-phase deletion ceiling is
1.128224x on the carried171.578 s CPU run with all other work fixed, before
added costs. It bounds that phase set only, not this whole architecture or GPU.

Next bounded local test: implicit per-column equality weights and public
selector terminals under row-first MSB, versus this explicit dense/compact
oracle, at independent starting points. Retain singular/Boolean challenges,
odd columns and all three final factors. Reject if the scheme exposes a raw
private value, changes the relation/refusals, needs expanded public arrays
larger than what it removes, or shows no enclosing gain in eventual owner runs.
Owner whole-prover GPU/residency and complete fixed-context workload slopes
remain higher priority; this lane queues no heavy work.
