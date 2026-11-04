# `formal/`: the D63 production statements in Lean 4

Ruling D63 (Victor, 2026-11-04): no ZKP goes into production before two statements are formalized and proved in
Lean.

**`ZK60Formal/Statements.lean`** states them precisely, for an abstract registered profile:
- `CircuitIff`, `Complete`, `KnowledgeSound` and `Binding`: "accepted exactly when the output is the
  discretized model's output";
- `ZeroKnowledge` and `SemanticHiding`: "the receipts teach nothing useful about the hidden data";
- `ProductionReady`: all of them together, with the error targets as parameters.

The plain-words version, the modelling choices and the open decisions are in
`docs/zkmatrix-poc/ZK60_LEAN_PRODUCTION_STATEMENTS.md`.

**Status:**
- These are STATEMENTS. Nothing about our protocol is proved yet.
- Proved so far:
  - `Hiding.lean`, the first zero-knowledge ingredient: the opened columns of a masked row are EXACTLY uniform
    for every message (`openedValues_uniform`), when the `Q` opened points are distinct and outside the message
    domain. This is the D59 pad-block property, now a theorem, using only Lean's three standard axioms.
  - A sanity check: the trivial arithmetization satisfies `CircuitIff`.
- The wording was approved by Victor on 2026-11-04, with the §6 choices.
- The work still to do: instances for a real profile (the integer model, the constraint system, the D55 protocol),
  and proofs of `ProductionReady` for them (plan L1–L5).

**Build** (Lean 4.34.1 and Mathlib v4.34.1, pinned in `lean-toolchain` and `lakefile.toml`):

```
lake -d formal update
lake -d formal exe cache get   # Mathlib's prebuilt files
lake -d formal build
```

Lean checks proofs, not what definitions mean. Read `Statements.lean` itself: it is short, and each definition
says in words what it states.
