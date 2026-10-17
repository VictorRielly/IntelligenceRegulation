# Owner disposition: demote whole-row CSE; retain optional affine-square cleanup

Cycle 0052, run `20261017T022624Z-f3bec81b`. Research-only candidate; main/Claude
reviews and integrates. No native source changed, Rust compiled or GPU job run.

Patch: `experiments/public-row-cse-20261017/row_graph.py`. Interface is a
proof-definition-local group-0 coefficient factory selected by public shape
and axis metadata, producing the same fixed `[Fp2; 5]` coefficients. The
Python symbolic tracer/interpreter is validation scaffolding, not the native
API. Optional helper: `square_affine([a0,a1]) -> [a0*a0, (a0*a1).double(), a1*a1]`.
This is coefficient squaring, not the earlier global Fp2 arithmetic proposal.

Current read-only seam in `ops/zkp-mvp/sonnet-hardening/`:
`hashline/src/private_block/argument.rs:1699/1783/1788` and
`zkp-core/src/sumcheck/grouped.rs:93/107/121/132`. The earlier fixed-array,
weighted-reduction and denominator-plan chain still needs owner translation.
The helper preserves original samples, folds, declared degree, own claims and
zero-factor fallback. No private equality, degree pruning, mask/opening reuse,
transcript, RNG or PCS change is introduced by the synthetic arithmetic.

Validation: 100 fixtures / 600 schedules, 5,832 independent cube samples,
16,272 direct finals, 1,024 arbitrary extension clause values, 256 raw/prior
counter matches and 256 zero/random schema/count matches. Sign/tail mutations
detected; equal concrete values in distinct input slots never imply a square.
Final exit0, seed2026101752, 24.749455s, 28,664KiB, one nice19 CPU thread;
commands, source/result pins and logs retained. No complete proof evidence.

Disposition: no multiplications saved; six illustrative counts save only
0.5299–0.5905% field API, with unknown weighted-time effect. At hp16/kv4/qh12/
T512/three limbs, save8,650,749adds+8,388,606subs; base products unchanged.
The whole-row interpreter pays1,996,226,061opcode steps and4,194,303pattern
lookups. Fixed-trace live words rise one, to120/122/123; serialized graph JSON
30,268bytes. LLVM may already share expressions. Reject a general graph
integration on this evidence. A direct helper can remain optional if the
factory is already being implemented and native enclosing A/B supports it.

**Port/census correction before actual trained-shape predictions:** native
argument.rs810 returns `None` for full domains; Gate978 supplies ONE and
PadTerm934 omits absent groups. Inherited research projections always build
both padded gate groups, including qh32/T512. They are illustrative formulas,
not exact native 8B layouts. Next local task: optional Ht/S supports and
independent omitted-group scalar/cube controls; preserve all old fixtures.
Do not claim native savings for behavior that already exists.

Native gates remain: exact arbitrary-extension/final values, masked/frozen
bytes, refusal behavior, challenge/RNG continuation, PCS openings and fresh
independent verification, then guarded subphase/peak/enclosing measurements
including both witness paths. Actual 8B affected clocks and startup are
unknown; no claimed throughput improvement. Privacy acceptance remains scoped
by existing rulings; D24 is proposed and has independent obligations.
