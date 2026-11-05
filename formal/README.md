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
  `KnowledgeSound` (step L3), proved about models of our commitment and of our IOP, and its Fiat–Shamir step.
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
  - `HidingMOpening.lean`: `M`'s WHOLE opening view, as `mask_open` sends it: the clear product polynomial `q'`
    (masked by the zero-sum blinding row `b`), the proximity vector (masked by `u`), and every opened column of every
    row (the a-rows, `b_re`, `b_im`, `u_re`, `u_im`). Its joint law over the pads, `b` and `u` depends on the CFS mask
    coefficients ONLY through the functional value `V` that the verifier computes itself (`mOpenView_shift`,
    `mOpenView_law_eq`; the joint form with the rest of the view, `mOpenView_joint_law_eq`; on the code's layout,
    `G_512` and the coset `7·G_4096`, `mask_open_law_eq`). The proof is a coin shift: the a-row pads absorb the
    coefficients' opened values, `b` absorbs the change of `Σ p_a·p_W` and keeps its zero sum exactly because `V` is
    unchanged (`sum_eval_nodes`, `rootsOfUnity_powSum`), and `u` absorbs the change of the proximity vector. The Fp2
    reading: a code pair `(c0, c1)` is `c0 + U·c1` with `U² = 7` (`fp2_mul`); `{1, U}` is a basis when `[K : F] = 2`
    and `7` is a non-square (`fp2_bijective`; `adjoinRoot_finrank` for `F[u]/(u² − κ)`); a uniform pair is a uniform
    Fp2 value (`fp2_uniform`); the hypothesis stated in Fp2 (`mOpenView_law_eq_fp2`).
  - `HidingRefusal.lean`: the refusal bit. Every refusal site of the private-block prover, classified (header): public,
    input admissibility, challenge-only, a structural assertion, and the data-dependent LogUp denominators. A refusal
    that is a function of the challenges alone leaks nothing, jointly with the served transcript (`attempt_law_eq`);
    a data-dependent one moves every probability by at most the chance that the two refusal predicates differ
    (`attempt_prob_le`); with public tables the LogUp refusal is challenge-only (`logup_refusal_iff_table`), and with
    `N` and `N'` data-dependent denominators it costs at most `(N + N')/|K|` (`logup_attempt_prob_le`). About the
    approved `ZeroKnowledge`: two inputs with the same public part and leakage but different deterministic refusals
    force an advantage of at least `1/2` (`refusal_output_must_be_leaked`), so the declared leakage must determine the
    refusal OUTPUT.
  - `HidingBlock.lean`: the composition of one block's layers (openings, a private slot, `M`): if each layer is
    simulated from the one below, the whole view has the same law for every data as for zero data
    (`map_pair_eq_bind`, `block_view_law_eq`); with the slot and `M` layers instantiated by the proved lemmas and the
    two links of the instance as hypotheses (`block_view_law_eq_slot_M`).
  - What these lemmas assume, and what L4 still needs (Fiat–Shamir, the links of the registered layouts, several slots
    and blocks, the run structure and receipts, and the instance that connects them to `ZeroKnowledge`), is in each
    file's header and in `docs/zkmatrix-poc/ZK60_LEAN_L4_FINDINGS_20261104.md`.
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
- Proved so far (step L3, the openings as the code runs them; interactive challenges; same build and axiom checks):
  - `SoundGroups.lean`: one opening of `verify_zk_tagged` with SEVERAL claim groups and the `λ` batching (one
    independent draw per claim, as `zk_rhos` draws them). Claims are linear functionals of the committed MESSAGE,
    read through the inverse of the encoder (`decodeWord`, `closeTable`, `decodeRows`; `groupsGood_iff`: the decoded
    data is the extracted data). Some claim false of the decoded message, accepted: probability
    `≤ A/|E| + (1 − (e + 1)/N)^Q`, the one-group bound; the batching's `1/|E|` arises only in the close case and is
    absorbed (`groups_sound`; the additive form `groups_sound_add`; `groups_sound_rs_half`, `groups_sound_rs_third`).
    With the Merkle layer and the matrix extracted from the commit log: `groups_sound_extracted`.
  - `SoundMProduct.lean`: the mask commitment `M`'s product-form test as `mask_verify_tagged` runs it (`θ` powers,
    the sum check `m·(q'_0 + q'_m) = V`, the column check `b + Σ_s a_s·p_{W_s} = q'`). If `q'` is the decoded rows'
    product polynomial the sum check is a root of the residual `Σ_i (value_i − tru_i)·θ^i − off` (`mResidual_root`),
    where `off` is the decoded `b`'s sum over `G_m`, which the verifier never checks. So the test certifies the
    functionals only up to that constant on the FIRST functional (`mproduct_sound_code`; the attack
    `mproduct_offset_accepts`; finding F12); with powers from `θ^1` every false functional is caught
    (`mproduct_sound_shift`, `k/|E|`). `M`'s whole opening, the affine proximity test with the product test:
    `mopening_sound`, `mopening_sound_absorbed`; the decoded rows are unique (`mDecoded_unique`).
  - The comparison with the count, the model and the findings (F12: High, needs a code check) are in Part 4 of
    `docs/zkmatrix-poc/ZK60_LEAN_L3_FINDINGS_20261104.md`.

- Proved so far (step L3, Fiat–Shamir in the random-oracle model, with `Statements.lean`'s `OC` and `prH`; the
  challenges are hash outputs and the prover chooses the statement; same build and axiom checks):
  - `FSRbr.lean`: round-by-round soundness (`RbrSound`, Canetti et al.: a state function, at most `e` escaping
    challenges per round) and the Fiat–Shamir compilation with each challenge `chal (H (statement, transcript so far,
    message))`. A prover making at most `q` hash queries makes the verifier accept a false statement with probability
    at most `(q + n)·e·K/|D|` (`fs_sound_of_rbr`), `K` the digests per challenge value. Written as the interactive
    per-round error times the derivation's bias factor `K·|Ch|/|D|`: `(q + n)·e/|Ch|·bias` (`fs_sound_of_rbr_bias`,
    `fs_sound_uniform`). The step is `freshHitQ_prob_le`, `SoundRO.lean`'s fresh-hit lemma with the bad set named
    by the query.
  - `FSChallenge.lean`: the code's `challenge_fp2` (two 128-bit halves, each reduced mod `p`) has at most
    `(⌊2^128/p⌋ + 1)²` digests per `Fp2` value (`card_fp2Field_fiber_le`). Its bias factor is at most
    `(1 + p/2^128)²` (`biasFactor_fp2_le`), at most `(1 + 2^-64)²` for `p ≤ 2^64` (`bias_le_two_pow_64`).
    `challenge_indices` (a masked `u64`) is exactly uniform (`biasFactor_idx_eq_one`).
  - `FSSumcheck.lean`: the sumcheck verifier on a transcript list (`scAccept`; it is `SoundSumcheck.lean`'s `Accepts`,
    `scAccept_proverTr`) is RBR sound with `d` escapes per round and the state "every check passed and the current
    claim is true" (`sumcheck_rbr`). Under Fiat–Shamir the error is `(q + n)·d/|F|` with uniform challenges
    (`fs_sumcheck_sound_uniform`), against the interactive `n·d/|F|`, and `(q + n)·d/|F|·(1 + 2^-64)²` with the
    code's derivation (`fs_sumcheck_sound_goldilocks`).
  - `FSChain.lean`: the code's transcript is a hash CHAIN (each absorb or squeeze hashes the previous 32-byte state
    with one item), not a prefix hash. `ChainEnc` models it. A trace-back recovers the chain behind a digest from the
    log before a query (`traceBack_chain`), in order unless a guess occurs (`chain_ordered`). For any state function
    on chains with `k` escaping digests per item, the error is `T·k/|D| + collBound T + collBound (T + 1)`,
    `T = q + ℓ + 1` (`chain_sound`): the prefix bound plus about `T²/2^256`.
  - `FSChainRbr.lean`: an RBR-sound protocol run on the chain the code hashes (the statement, then per round the
    message and a counter squeeze): `fs_chain_sound_of_rbr`. The sumcheck as the code hashes it, with the code's
    `challenge_fp2`: `T·d/|F|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + 2n + 2`
    (`fs_sumcheck_chain_sound_code`).
  - `FSWide.lean`: VECTOR challenges (finding F19). The code draws `λ`, `ρ`, the index vector `J` and LogUp's
    `β, γ, α` as several squeezes with no absorb between. A step of `k` such squeezes is ONE fresh uniform `k`-tuple
    per attempt: rewriting `H` along the step's own queries is a bijection of `(Q → D) × D^k` (`wideSwap`,
    `wide_card_le`), so in an adaptive run of `T` queries a set of probability `ε` named by the log is hit with
    probability at most `T·ε` (`wideHit_prob_le`). `chain_sound_wide` is `chain_sound` with such steps, and its state
    may read the log (for knowledge soundness), provided the state is frozen once the chain's queries are logged.
  - `FSWideRbr.lean`: a protocol with per-round widths, rounds with or without a message, and the code's running
    squeeze counter, on the chain (`pSteps`, `pHeadsW`, the reader `rDecodeW`). Round-by-round soundness with vector
    challenges at the level of digests (`RbrWide`) gives `T·ε + collBound T + collBound (T + 1)`,
    `T = q + ℓW + 1` (`fs_chain_sound_of_rbr_wide`; the general form with a log-reading state, `fs_chain_wide_flip`).
    From the interactive bound to digests: `prob_vec_comap_le`; for `challenge_fp2_vec`, `(1 + p/2^128)^(2k)`
    (`prob_fp2_vec_le`).
  - `FSLogUp.lean`: LogUp under Fiat–Shamir as the code draws it. Two rounds with no message, `(β, γ)` then `α`,
    with the per-round errors `logup_block_bound` decomposes into: the fold `2M/|F|` (`logup_fold_round`) and the
    `α` step `(N + 2M − 1)/|F|` (`logup_alpha_round`); they add up to `(N + 4M − 1)/|F|` (`logup_rounds_add`).
    On the chain: `(q + 7)·(N + 2M − 1)/|F|·(1 + p/2^128)^4 + chain terms` (`fs_logup_chain_sound`).
  - `FSOpening.lean`: one opening under Fiat–Shamir with the matrix EXTRACTED from the prover's log cut at the
    root's absorption: round-by-round KNOWLEDGE soundness. The rounds (`opening_round0`: `(λ, ρ)`, `A/|E|`;
    `opening_round1`: `J`, the column term); the cut (`cutLog`, `proverLog` by replaying the prover,
    `cut_proverLog_stable`); the Merkle extraction failure in the whole run (`opening_extract_fail`,
    `collBound T' + 2T'²/|D|`); `fs_opening_knowledge`, and `fs_opening_knowledge_code` with the code's derivations
    (`challenge_fp2_vec`: `(1 + p/2^128)^(2·w0)`; `challenge_indices`: exactly uniform, `chunkEquiv`, `idxCode`).
  - `FSCompose.lean`: sub-protocols COMPOSED on one chain, round by round (finding F20). The combined state is "every
    sub-protocol alive" (`AllAlive`); a round revives only the sub-protocol it belongs to, unless a later one is already
    doomed (a reduction hands its claim forward) (`Composed`). Then the combined protocol is `RbrWide` with the MAXIMUM
    of the rounds' errors (`Composed.rbrWide`, `_sup`), and on the chain the per-query rate is that maximum
    (`fs_chain_sound_of_composed`; with log-reading states, `fs_chain_wide_flip_composed`). Schedules of sub-protocols
    one after the other, each with its own `RbrWide` and its claim fixed by earlier rounds (`SubProt`, `SOf`,
    `sched_composed`, `fs_chain_sound_sched`).
  - `FSComposeBlock.lean`: the block's sub-protocols on digests with the code's derivations (LogUp; the sumcheck,
    `rbrWide_of_rbrSound`; evaluation points, `mle_rbrWide`; batching, `batch_rbrWide`; free challenges such as the CFS
    `c`; the regular openings), at the 8B T128 W16R2 parameters (`Kind8B`), with `M`'s opening ASSUMED at error
    `≤ 2^-106` (its proof waits on F12). Each error is at most `135/2^110 ≈ 2^-102.92` (`Kind8B.eps_le`; LogUp's `α`
    is the largest). One block and a D12a run of blocks on one chain (`fs_block_sound_8B`, `fs_run_sound_8B`), and in
    the approved target's form `εsTarget (max q (ℓW + 1))` (`fs_run_sound_8B_target`). The hand-offs between the
    sub-protocols are premises.
  - `FSComposeZeroCheck.lean`: a worked instance with every premise proved: the zero-check's `τ` handing its claim to
    the sumcheck of `eq(τ, ·)·R` (`zc_handover`, `fs_zerocheck_chain_sound`); per query the maximum of the two errors,
    where the interactive `zerocheck_sound` adds them.
  - `FSTree.lean`: a TREE of chains (finding F26, the D55 fork-join: forks rebuilt from the common state `S0`, a join
    that absorbs their end states). A query's state digest traces back to ONE path, so each hash query attacks one
    round of one branch. Because D55's branches all start their squeeze counters at `S0`'s, one counter starts steps of
    different widths in different branches; the wide-digest lemma is restated with widths read off the log
    (`WideHitP`, `wideHitP_prob_le`). `flip_subset` and `tree_sound_wide`: for ANY family of chains that a verifier
    hashes (the family may depend on the oracle, as the join's head does), the probability that some chain of the
    family flips is at most `T·ε + collBound T + collBound (T + 1)`, `T = q + v`, `v` the verifier's query budget: one
    union over the queries, not one per chain. `chainsOC` hashes several chains in turn.
  - `FSTreeRbr.lean`: round-by-round protocols laid out on the tree: a trunk item, then per branch a head item and the
    branch's rounds (`Tree`, `liftT`, `liftT_round`, the verifier `Tree.verOC`, `Tree.Accepts`). `fs_tree_sound`: with
    every branch `RbrWide` at error `ε`, a false statement is accepted with probability at most
    `(q + ℓT)·ε + collBound (q + ℓT) + collBound (q + ℓT + 1)`, given that a false statement dooms some fork, that a
    fork ending doomed and accepted dooms the join's start, and that the join rejects when it ends doomed;
    `fs_tree_sound_sched` with each branch a schedule of `SubProt`s.
  - `FSTreeD55.lean`: the D55 instance (`D55Head`, `d55JoinOf`: the join's head carries each fork's index, end state,
    squeeze counter and claims, as `absorb_join` does). With every sub-protocol of every branch a `Kind8B` (`M` ASSUMED
    at `2^-106`): `fs_d55_sound_8B`, per hash query `135/2^110 ≈ 2^-102.92` for any number of forks (the union over 32
    forks was `2^-97.93`); `fs_d55_sound_8B_target`, `εsTarget (max q ℓT)`.
  - The comparison with the interactive bounds and the target, the code's transcript order (what is absorbed before
    each challenge), the findings (F16–F19) and what remained are in Part 5 of
    `docs/zkmatrix-poc/ZK60_LEAN_L3_FINDINGS_20261104.md`; the vector challenges, LogUp, the opening, the whole-block
    figure per hash query and the findings F20–F23 are in its Part 6; the composition, the block and run figures, the
    code check and the findings F24–F27 are in its Part 7; the tree of chains, the D55 figure, its code check and the
    findings F28–F31 are in its Part 8.
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
