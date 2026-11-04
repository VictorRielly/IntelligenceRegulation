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
- `Statements.lean` holds STATEMENTS. None of `ProductionReady`, `ZeroKnowledge` or `SemanticHiding` is proved for
  our protocol yet; the lemmas below are ingredients of `ZeroKnowledge`, proved about models of our commitment.
- Proved so far (step L4, zero knowledge; every file builds with no `sorry` and no warnings, and `#print axioms`
  shows only `propext`, `Classical.choice`, `Quot.sound`):
  - `Hiding.lean`: the opened columns of a masked row are EXACTLY uniform for every message
    (`openedValues_uniform`), when the `Q` opened points are distinct and outside the message domain. This is the
    D59 pad-block property, now a theorem.
  - `HidingRows.lean`: the same with FEWER distinct points than pads (`openedValuesAt_uniform`), with the verifier's
    sampling WITH REPLACEMENT (`sampledValues_law_eq`), for SEVERAL ROWS with independent pads
    (`rowsOpenedValues_uniform`, `rowsSampledValues_law_eq`), and on the protocol's coset domain
    (`coset_rowsSampledValues_law_eq`).
  - `HidingOpening.lean`: the clear vectors of one opening TOGETHER WITH its opened columns. A reserved pair of
    base-field rows hides one Fp2 clear vector (`pairMask_uniform`); a single base-field mask row does not: the clear
    vector then determines a one-row table exactly (`singleMask_reveals`, `singleMask_law_injective`). The joint law
    of the group vectors, the proximity vector and every opened column is the same for every data matrix
    (`openingView_law_eq`, `openingView_law_eq_of_points`): the zero-witness simulator, for one opening.
  - `HidingOpeningSum.lean`: the same for `H`, whose LogUp sum claim is masked by the zero-sum pair `u`; the view
    then depends on the data only through the public identity the sum claim proves (`openingViewH_law_eq`).
  - `HidingSumcheck.lean`: one round of a CFS-masked sumcheck: the round's own mask coefficients make its
    non-constant coefficients uniform (`cfsRound_tail_uniform`, `cfsRound_law`). The joint statement over all
    rounds, the total and the terminal is not proved yet.
  - What these lemmas assume, and what L4 still needs (the CFS joint lemma, the mask commitment `M`, salted Merkle
    hiding in the random-oracle model, Fiat–Shamir, the refusal bit, composition over commitments and receipts, and
    the instance that connects them to `ZeroKnowledge`), is in each file's header.
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
