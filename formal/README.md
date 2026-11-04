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
- `Statements.lean` holds STATEMENTS. None of `ProductionReady`, `ZeroKnowledge`, `SemanticHiding` or
  `KnowledgeSound` is proved for our protocol yet; the lemmas below are ingredients of `ZeroKnowledge` (step L4) and of
  `KnowledgeSound` (step L3), proved about models of our commitment and of our IOP.
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
    non-constant coefficients uniform (`cfsRound_tail_uniform`, `cfsRound_law`).
  - `HidingM.lean`: the mask commitment `M`, whose pads sit in message positions of `G_512` and reach the opened
    points through the Lagrange basis (a scaled Cauchy block). The pad block of `k ≤ Q` distinct points outside
    `G_512` has full row rank (`mPadBlock_surjective`, by a degree count rather than the Cauchy determinant), so one
    a-row's opened values are exactly uniform for every message (`mOpened_uniform`), and so are several a-rows'
    jointly, with sampling with replacement and each row's own pad positions (`mRowsOpened_uniform`,
    `mRowsSampled_law_eq`). `mRowMsg_eq` checks the code's layout (coefficients, pads, zeros) and
    `mask_aRows_law_eq` is the statement on `M`'s coset `7·G_4096`.
  - `HidingSumcheckJoint.lean`: the masked sumcheck over ALL its rounds. The closed forms of `CfsMask` are a
    consistent sumcheck of the mask (`cfsMask_roundSum_zero`, `cfsMask_roundSum_succ`, `cfsMask_terminal`). The joint
    law of (the total `G`, every round message, `g(ρ)`) depends on the unmasked rounds only through their chain
    defects, `(S, 0, F)` for an honest prover (`cfsView_law_eq`, `cfsView_values_law_eq` in the code's value form);
    with the scalar sent as `S + c·G`, not even on `S` (`cfsViewMasked_law_eq`). The joint forms
    (`cfsView_joint_law_eq`, `cfsViewMasked_joint_law_eq`) compose with the rest of the view. With the last-round
    extension, a private slot's view depends on its data only through `poly` of the masked terminals
    (`slot_chainDefect`, `slot_view_law_eq`).
  - `HidingMerkle.lean`: salted Merkle hiding in the random-oracle model, with `Statements.lean`'s `OC`. One level of
    salted leaves: an adversary seeing every leaf digest and the opened salts, with `q` queries, gains at most
    `n·(n + q)/|S|` over fresh random leaves (`saltedLeaves_real_ideal`), so two leaf vectors that agree on the opened
    leaves are told apart with advantage at most `2·n·(n + q)/|S|` (`saltedLeaves_hiding`). The tree: any `t`-query
    view of the leaves costs `t` more queries (`saltedLeaves_view_hiding`), and the whole tree over `N = 2^h` leaves,
    every root and path, costs `N − 1` (`merkleLevels_bounded`, `merkle_hiding`).
  - What these lemmas assume, and what L4 still needs (the joint law of `M`'s whole opening view with its clear
    product polynomial and proximity vector, Fiat–Shamir, the refusal bit, composition over commitments, slots and
    receipts, and the instance that connects them to `ZeroKnowledge`), is in each file's header and in
    `docs/zkmatrix-poc/ZK60_LEAN_L4_FINDINGS_20261104.md`.
  - A sanity check: the trivial arithmetization satisfies `CircuitIff`.
- Proved so far (step L3, soundness of the IOP, foundations; interactive, with uniform independent challenges, no
  Fiat–Shamir yet; same build and axiom checks as above):
  - `SoundSchwartzZippel.lean`: a nonzero polynomial of degree `≤ d` over a finite field vanishes at a uniform point
    with probability `≤ d/|F|` (`schwartzZippel`, `schwartzZippel_ne`), and the counting-to-probability lemmas the other
    files use.
  - `SoundSumcheck.lean`: the sumcheck as `zkp_core::sumcheck` runs it. Round messages are `d + 1` values at
    `X = 0, …, d`; the verifier's `interpolate_eval` is the Lagrange interpolant (`interpEval_eq`), so the degree bound
    is automatic once `d < char F` (`roundPoly_natDegree_le`). For a false claim and ANY prover strategy the verifier
    accepts with probability `≤ n·d/|F|` (`sumcheck_sound`; one round, `sumcheck_sound_one_round`). The bound is
    unchanged for the CFS-masked sumcheck on `f + c·g` with the claim `S + c·G` (`sumcheck_sound_masked`), and is
    `(n + 1)·d/|F|` with the last-round extension (`sumcheck_sound_extended`), which is sound only because every slot
    polynomial vanishes once its public inputs are zero (`extension_halves`).
  - `SoundMultilinear.lean`: the same theorem in the code's own terms: tables on the cube, `poly` of total degree
    `≤ d`, the terminal check `poly(finals)` (`sumcheck_sound_tables`, via `indDegLE_mle_comp`).
  - `SoundLogUp.lean`: the LogUp identity `Σ_i 1/(X − a_i) = Σ_j m_j/(X − t_j)` in `RatFunc F` holds iff every value's
    lookup count equals the table's multiplicity mass there (`logup_iff_counts`); with fewer lookups than `char F`
    every looked-up value is then in the table, whatever the multiplicities (`logup_mem_of_eq`); the multiset form
    with natural multiplicities (`logup_iff_multiset`); and a failing identity holds at a uniform non-pole `α` with
    probability `≤ (|S| − 1)/|F| ≤ (N + M − 1)/|F|` (`logup_challenge_bound`, `logup_challenge_bound'`).
  - `SoundLogUpBlock.lean`: LogUp with the code's helper columns (single and pair helpers, table helpers, the value-0
    sum claim) and the `(β, γ)` tuple fold. A looked-up tuple outside the table survives `β, γ, α` with probability
    `≤ (N + 4M − 1)/|F|`, `M` the distinct table tuples (`logup_block_bound`): the count's per-block LogUp term
    `(N_lk + 4·T_d − 1)/|Fp2|`.
  - `SoundZeroCheck.lean`: Schwartz–Zippel for the multilinear extension (`mle_zero_prob`, `n/|F|`), the zero-check
    composed with the sumcheck (`zerocheck_sound`, `(n + n·(d + 1))/|F|`), and batching with independent coefficients
    (`batch_prob`, `1/|F|`).
  - The comparison with the counted figures, the code's departures from the textbook protocols, the findings and what
    L3 still needs (the PCS, composition over slots and blocks, Fiat–Shamir, the instances) are in
    `docs/zkmatrix-poc/ZK60_LEAN_L3_FINDINGS_20261104.md`.
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
