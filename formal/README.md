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
- Proved so far (step L3, the polynomial commitment's tests; interactive, uniform independent challenges, the
  committed matrix fixed before them; same build and axiom checks):
  - `SoundColumnTest.lean`: `Q` column indices drawn uniformly WITH replacement (`challenge_indices`) miss a set `D`
    of the `N` columns with probability exactly `((N − |D|)/N)^Q` (`column_miss_prob`), so a re-encoded vector that
    disagrees with the combination of the committed rows on `≥ e + 1` columns passes with probability
    `≤ (1 − (e + 1)/N)^Q` (`column_test_sound`), `count.py`'s exact integer form; at rate 1/4 that is at most the
    counted `((2N + K)/(3N))^Q` (`third_column_le`).
  - `SoundProximity.lean`: for ANY linear code of minimum distance `d` with `2e < d`, a bound of `A ≥ e + 1`
    exceptional values for lines gives the bound `A/|E|` for independent uniform weights on any number of rows, with
    no loss (`comb_close_prob`): the step from BCIKS20's line theorem to its Thm 1.7 / Thm 3.1 form. With the
    Roth–Zémor line bound at `3e < d` this is the δ/3 lemma (Ligero/AHIV style), `(e + 1)/|E|` (`proximity_third`).
    The affine form `u + Σ r_i·U_i` of the mask commitment `M` costs `A/(|E| − 1)` (`affine_proximity_third`).
  - `SoundProximityRS.lean`: our Reed–Solomon code (degree `≤ K` at `N` distinct points, distance `N − K`): δ/3,
    `(e + 1)/|E|` for `3e + K + 1 ≤ N` (`rs_proximity_third`); **δ/2, the unique-decoding radius (D59, BCIKS20
    Thm 3.1), `N/|E|` for `2e + K + 1 ≤ N`** (`rs_proximity_half`, from FlashProve's proof of BCIKS20 Thm 4.1); and
    the code's field split, rows over `F_p`, weights over `F_p²` (`close_of_close_lift`, `rs_proximity_*_ext`).
  - `SoundOpening.lean`: one opening, the two tests composed. For any prover, the verifier accepts while the
    committed matrix does not decode to rows that satisfy the claim with probability
    `≤ A/|E| + (1 − (e + 1)/N)^Q` (`opening_sound`; the far and close cases exclude each other); for our code at
    rate 1/4 and rate 1/2 (`opening_sound_rs_third`, `opening_sound_rs_half`), and at rate 1/4 in `count.py`'s own
    terms with its carried ceiling (`opening_sound_rs_third_counted`).
  - `ThirdParty/FlashProve/`: 15 files adapted from FlashProve's Apache-2.0 Lean library (`lean/`, commit
    9e2bdd8f, version 0.16.0): `Prob/Cnt`, `Prob/Count` (cut to its counting part), `Code/Agree`, `Code/Third`
    (Roth–Zémor up to a third of the distance, `cnt_close_le`, `mca_third`), `Code/Mutual`, `Code/Half` (BCIKS20
    Thm 4.1 for Reed–Solomon codes, `caOn_rsCode`, `mca_rsCode`) and the nine files of `Code/Lines/` (its proof).
    FlashProve was written for Lean 4.29.1 and an older Mathlib; the port needed four one-line fixes (deprecated
    names, a `simpa` and a `convert` that the newer versions leave open). Each file says what was changed; the
    repository's `NOTICE` has the attribution (FlashProve, and ArkLib as FlashProve credits it). No new lake
    dependency.
  - What these lemmas assume and what L3 still needs (Merkle binding, the λ batching inside a group, `M`'s
    product-form test, composition over openings, slots and blocks, Fiat–Shamir) are in the findings document's
    second part.
- Proved so far (step L3, the Merkle layer in the random-oracle model, with `Statements.lean`'s `OC` and `prH`; the
  challenges still interactive; same build and axiom checks):
  - `SoundRO.lean`: the random oracle. A point the event names but has not yet fixed lands in a set of `m` values
    with probability `≤ m/|D|` (`prob_fresh_mem_le`); along an adaptive run, a first-time query lands in a set of
    `m t` values computed from the log before it with probability `≤ Σ_{t<T} m t/|D|` (`freshHit_prob_le`). Hence
    collision resistance: a `q`-query computation's queries collide with probability `≤ q(q − 1)/2 / |D|`
    (`collision_prob_le`), it OUTPUTS a collision with probability `≤ (q + 2)(q + 1)/2 / |D|`
    (`collision_out_prob_le`); a fixed target is hit with probability `≤ q/|D|` (`preimage_query_prob_le`); an
    output preimage at a point never asked has probability `≤ 1/|D|` (`preimage_out_prob_le`). Also the log lemmas the
    other files use (`runLog_bind`, `runLog_take_agree`, `runLog_eq_of_agree`, `replay`).
  - `SoundMerkle.lean`: the tree as `merkle.rs` / `pcs.rs` build and verify it (column digest, salted leaf, inner
    nodes, the position's low bit choosing left or right, the path-length check). Two openings of one root at one
    position with different columns contain a collision among the verifier's queries (`opens_collision`), so a
    `q`-query adversary produces them with probability `≤ collBound (q + 2(h + 2))` (`merkle_binding`). Only the
    injectivity of each of the three input encodings is assumed, no separation between them. Without the path-length
    check binding fails for EVERY encoding, keyed or not (`mixed_depth_opens`).
  - `SoundExtract.lean`: the straight-line extractor. It reads only the commit phase's log and descends from the
    root (`descend`, `extractCol`). An opening that verifies equals the extracted column unless a verifier's query
    collides with a logged one or a never-logged query hits one of the at most `3q₁ + 1` digests named in the log
    (`extract_of_opens`); so with a commit phase of `q₁` queries and a later phase of `q₂` that opens `n` columns, some
    verifying opening differs from the extraction with probability `≤ collBound T + T(3q₁ + 1)/|D|`,
    `T = q₁ + q₂ + n(h + 2)` (`extract_sound`).
  - `SoundOpeningRO.lean`: `opening_sound` with the matrix EXTRACTED from the commit log instead of fixed: a
    three-phase prover (commit; answer the weights; open the sampled columns) against a random oracle, the
    challenges uniform and drawn after the root; the error is the field term + the column term + the extraction
    error (`opening_sound_extracted`).
  - The comparison with the count, what the model assumes and the findings are in Part 3 of
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
