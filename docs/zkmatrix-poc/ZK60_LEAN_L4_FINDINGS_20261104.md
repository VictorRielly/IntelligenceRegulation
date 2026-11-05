# D63 step L4: what the first zero-knowledge proofs established, and what they exposed (2026-11-04)

The Lean files are under `formal/ZK60Formal/`. They were checked again after the merge:
- `lake -d formal build` succeeds with no warnings, and no file uses `sorry`, `axiom`, `admit` or `native_decide`;
- every headline lemma depends only on `propext`, `Classical.choice` and `Quot.sound`.

## Proved (honest verifier, one opening, fixed challenges)

- **Opened columns** (`Hiding.lean`, `HidingRows.lean`):
  - for k ≤ Q distinct opened points outside the message domain, one row's opened values are exactly uniform;
  - so are r rows with independent pads, under sampling with replacement (at most Q distinct points), on the coset
    domain h·⟨ω⟩;
  - opening more than Q points is exactly what breaks this.
- **A-type opening view** (`HidingOpening.lean`, `openingView_law_eq`): the whole view (every claim's row
  combination, the proximity vector and every opened column) has the same law for any data as for zero data. A
  simulator that runs the honest opening on zeros reproduces it exactly. This needs every claim to carry its own pair
  of mask rows with F-independent coefficients, and the proximity pair likewise.
- **H-type opening view** (`HidingOpeningSum.lean`, `openingViewH_law_eq`): the same, with the LogUp sum claim
  masked by the zero-sum pair. It holds when the data satisfies the public LogUp identity.
- **One masked sumcheck round** (`HidingSumcheck.lean`, `cfsRound_law`): the round message's law is
  `(m₀, uniform)`.
- **A single mask row is NOT enough over Fp2** (`singleMask_reveals`): one base-field row under a coefficient
  outside Fp lets the data be decoded exactly.

## Exposed in the protocol (to act on; none affects an accepted privacy statement)

1. **The non-mr1 path is not private over Fp2.**
   - `prove_layer_zk_v3` (CLI `--zk --profile v3`) uses one mask row for one-row tables and a single proximity row.
     By `singleMask_reveals`, that hides nothing.
   - The header of `hashline/src/zk.rs`, §(a)(ii) ("one random row per site makes the clear vector uniform"), is
     false over Fp2.
   - Every accepted privacy statement (D22, D33, D58) is for an `hashline-zk-mr1` profile, which uses pairs.
   - **Receipts from the v3 path must not be called private.** The project already knew the single-row leak through
     the FA2/FA3 negative controls; the theorem is new.
2. **`zkp-core`'s `assert_mask_sites` admits the leaking configuration** (one mask row per group, a single proximity
   row).
   - Its test rig `zk_tests::rig` is such a configuration.
   - `zk_openings_are_uniform_and_every_site_is_masked` still passes, because its per-coordinate chi-square test
     cannot see linear relations between coordinates. It is not evidence of hiding.
   - The pair discipline is enforced only in hashline (`audit_claims`, `check_opening_challenges`, `check_masks`).
3. **`audit_claims` (`private_block/protocol.rs:240`) checks the pair structure, not the pair's independence.**
   - It requires each claim to touch exactly its own two adjacent reserved rows, with nonzero coefficients.
   - Hiding needs the pair's two row weights to be F-linearly independent (the determinant test that
     `check_opening_challenges` already applies to the proximity pair).
   - Today this holds because `build_claim` always weights a pair (c, c·u) with u ∉ Fp (u² = 7, a non-residue mod the
     Goldilocks prime; checked numerically 2026-11-04).
   - **Task:** add the per-pair determinant check, computed on the row weights the claim actually induces (its point,
     not only its `coef`), with a negative control that a (c, c) pair is refused. The zero-sum pair needs the same.
   - **Done, 2026-11-04.** Both audits (`private_block` and `private_attention`) now compute each claim's induced
     weights on its pair with `pcs::zpart_row_weight`, the PCS's own rule with the point included. They refuse a zero
     base-field determinant, for every evaluation claim and for the zero-sum pair. A group's nonzero member
     coefficient preserves independence (`det(c a, c b) = N(c) det(a, b)`), so the per-claim check suffices.
     - Negative controls: `l4_f3_the_schedule_audit_refuses_a_pair_with_dependent_induced_weights` in both test
       modules. They refuse (c, c), (1, 2), a single part across both rows at a base-field or boolean coordinate, and
       a (1, 1) zero-sum pair. They accept (c, c·u) and a part across both rows at `3 + u`.
     - **The fix found a leaking fixture.** The review test `the_mask_schedule_audit_still_refuses_every_case_at_the_rungs_row_width`
       used an "honest" pair: one part across both rows, read at the coordinate 1, which weights them (0, 1), so only
       one base-field row masks. The old audit accepted it. The fixture now reads the pair at `u`, and the test asserts
       that the old one is refused.
     - Checks (`results/zk60_h124_witness_20261104/`): the full lib suite is 904 / 3 / 93, exactly the known three
       failures (`f3_full2.log`); the W16R2 rung golden is unchanged (`f3_r2rung.log`); no honest flow refuses.
       Honest claims weight a pair (cm, cm·u), whose determinant is `N(cm) ≠ 0`.
4. **`audit_claims`' doc comment says "one pair per group"; the code enforces one pair per claim**, which is what
   hiding needs.

## Hypotheses the theorems take from the code

- At most `q_pad` distinct opened points per commitment over all its openings, so each hiding commitment is opened
  once.
- u ∉ Fp (true: 7 is a non-residue).
- h^N ≠ 1 (asserted in `coset_powers`).
- c ≠ 0 for the masked sumcheck (asserted).
- The H sum claim covers the whole row, matching the whole-row zero-sum constraint. Assumed; not yet checked against
  the layout's plane domains.

## Still open for L4

- the masked sumcheck's joint law over all rounds and its last round;
- the M commitment, whose pads sit in message positions (Lagrange basis), so its pad block is a scaled Cauchy matrix
  and needs its own full-rank lemma;
- the salted Merkle layer in the random-oracle model;
- Fiat–Shamir (challenges depend on the root);
- the refusal bit;
- the composition of A, H and M with the terminals that link them, the D12a/D55 run structure, and R receipts;
- finally, the instance that connects all of this to `ZeroKnowledge` in `Statements.lean`.

## Second batch, 2026-11-04: M's pad block, the masked sumcheck over all rounds, salted Merkle hiding

The first three items of the list above are done. Three new files: `HidingM.lean`, `HidingSumcheckJoint.lean` and
`HidingMerkle.lean`.
- `lake -d formal build` succeeds with no warnings, and no file uses `sorry`, `axiom`, `admit` or `native_decide`.
- `#print axioms` was run on every declaration of the three files (134 of them). Each depends only on `propext`,
  `Classical.choice` and `Quot.sound`, or on fewer.

### Proved (honest verifier, fixed challenges)

- **M's pad block** (`HidingM.lean`).
  - The code (`zk.rs` `mask_commit_tagged`) matches the earlier note. Each a-row's message is `[L_s coefficients,
    256 pads, zeros]`. The message is read as values on `G_512` (`ntt.inverse`, natural order) and evaluated on
    `7·G_4096`. So each pad reaches an opened point `x` through the Lagrange basis `L_{π l}(x)`, and the pad block
    is a scaled Cauchy matrix.
  - The full-rank proof (`mPadBlock_surjective`) does not use the Cauchy determinant. It is a degree count: a
    polynomial of degree `< 512` that vanishes at the `512 − k` non-pad message points and at the `k` opened points is
    zero. It holds for any distinct message points.
  - Consequences:
    - one a-row's opened values are exactly uniform for every message (`mOpened_uniform`);
    - several a-rows' opened values are too, jointly, each row with its own pad positions (`L_s` differs per
      sumcheck), under sampling with replacement (`mRowsOpened_uniform`, `mRowsSampled_law_eq`);
    - `mask_aRows_law_eq` is the statement on M's coset. `mRowMsg_eq` checks the code's layout.
- **The masked sumcheck over all rounds** (`HidingSumcheckJoint.lean`).
  - `CfsMask`'s closed forms are a consistent sumcheck of the mask: `g_0(0) + g_0(1) = G`,
    `g_{j+1}(0) + g_{j+1}(1) = g_j(r_j)` and `g_N(r_N) = g(ρ)`.
  - `cfsView_law_eq`: the joint law of (`G`, every round message, `g(ρ)`) depends on the unmasked rounds only through
    their chain defects. For an honest prover the defects are the claimed sum `S`, zeros, and the terminal value `F`.
    `cfsView_values_law_eq` states the same for the code's value form of the rounds.
  - `cfsViewMasked_law_eq`: with the scalar sent as `S + c·G` (`SlotKind::Private`), the law does not depend on `S`
    either.
  - The joint forms (`cfsView_joint_law_eq`, `cfsViewMasked_joint_law_eq`) hold together with any other part of the
    view computed from independent coins. That is the form that composes with the opening lemmas.
  - The extension: its terminal is `poly` of the masked terminals. A slot whose extension is an identity has defects
    `(S, 0, poly(masked terminals))` (`slot_chainDefect`). So a private slot's view depends on its data only through
    `poly` of the masked terminals (`slot_view_law_eq`).
- **Salted Merkle hiding in the random-oracle model** (`HidingMerkle.lean`, with `Statements.lean`'s `OC`).
  - One level of salted leaves (`saltedLeaves_real_ideal`, `saltedLeaves_hiding`). The adversary sees every leaf
    digest and the opened salts, and makes `q` queries. It gains at most `n·(n + q)/|S|` over fresh random leaves.
    So two leaf vectors that agree on the opened leaves are told apart with advantage at most `2·n·(n + q)/|S|`.
  - The tree (`saltedLeaves_view_hiding`, `merkleLevels_bounded`, `merkle_hiding`). Any `t`-query view of the leaves
    costs `t` more queries, and the whole tree over `N = 2^h` leaves (every root and path) costs `N − 1`.
  - At `N ≤ 2^16` and 256-bit salts the advantage is at most `q·2^-239 + 2^-222`.
  - The factor `n` cannot be removed in general. When all leaves hold the same content, one salt guess hits any of
    them.
  - The proof: a reprogramming involution (the coupling), "identical until bad" for oracle computations, and a counting
    bound for one salt.

### What the proofs showed about the code (none affects an accepted privacy statement)

1. **`a'` is not used by the joint lemma.**
   - The coin shift behind every law statement has `Δa' = 0`. So the joint law of (`G`, rounds, `g(ρ)`) depends only on
     the defects for the mask WITHOUT `a'` as well.
   - The justification in `zk.rs` (b)(i) and `sumcheck.rs` ("needed so that BOTH the mask's total G and its terminal
     g(rho) are uniform given the round messages") is not what this proof uses.
   - `a'` is harmless; no change is proposed (removing it would move bytes and needs a ruling).
2. **The extension round must be an identity, `poly(ext) = 0`, and the prover does not check it.**
   - `run_slot` and `zk::extension` publish the extension round without comparing `s_k(0) + s_k(1)` with the previous
     claim.
   - If a slot's polynomial ever had a term with no public or `eq` factor in an extension round, the honest receipt
     would be rejected by the verifier's round check. That rejected receipt would publish the defect `poly(ext)`, a
     function of the mask rows' evaluations.
   - Today every slot satisfies it: the honest suites verify, and the bilinear slots `SC_SCORE` and `SC_PV` mask their
     two private factors in two separate extension rounds.
   - **Suggestion:** a prover-side assertion `poly(exts) == 0` before the extension round is absorbed. It would turn
     this into a refusal.
3. **Merkle hiding needs the column hash and the salted-leaf hash to be domain-separated.**
   - The tagged profiles have it (distinct column and leaf keys, D19 T-1).
   - Under the legacy untagged rule it fails only for a commitment whose column is exactly 64 bytes (8 base-field
     rows). Such a column input and a salted-leaf input (digest ‖ salt) are then both 64-byte unkeyed BLAKE3 inputs.
     None of the hiding commitments checked (A, H and M of the `zk.rs` paths; M has `2·#masks + 4` rows) has 8 rows.
   - The node hash needs no separation. The legacy rule's leaf/node ambiguity does not affect hiding.
4. **M must be opened at most once per commitment.**
   - It is: `protocol.rs` makes ONE `mask_open` call per block.
   - `MASK_Q = 256` samples with replacement never exceed the 256 pads.
   - A second opening of the same M would break `mPadBlock_surjective`'s hypothesis.

### Hypotheses the new theorems take from the code

- **M:**
  - `L_s + 256 ≤ 512` (the `assert!` in `mask_commit`);
  - `7^4096 ≠ 1` (`coset_powers`);
  - samples `≤` pads;
  - one opening.
- **Sumcheck:**
  - `c ≠ 0` (refused);
  - odd characteristic;
  - round degree `≥ 1` (every slot has degree `≥ 2`, `Shape::degree_range`);
  - extension rounds are identities (verifier-enforced, item 2);
  - challenges fixed.
- **Merkle:**
  - the leaf input `digest ‖ salt` is an injective encoding;
  - the column hash is domain-separated from the salted leaf (item 3);
  - salts are uniform and fresh (`rng.bytes32()` from OS entropy);
  - the opened set is fixed (it is derived from the root under Fiat–Shamir).

### Still open for L4 (replaces the list above)

- M's whole opening view: the clear product polynomial `q'` (masked by the zero-sum blinding row `b`), the clear
  proximity vector (masked by `u`), and the `b` and `u` columns, jointly with the a-row columns. The pad lemma above is
  the first ingredient. The plan in `zk.rs`'s header ("`q'` is uniform given `V`; `b` and `u` are determined") should go
  through with the same coin-shift method.
- Fiat–Shamir: the challenges, the sampled columns and the opened set depend on the transcript and the roots.
- The refusal bit.
- Composition:
  - `A`, `H` and `M` with the terminals that link them;
  - the slots of a block (independent masks; a host slot's scalar combines other slots' totals);
  - the D12a/D55 run structure and R receipts.
- The instance that connects all of this to `ZeroKnowledge` in `Statements.lean`.

## Fixed, 2026-11-04: the prover now refuses an extension round that is not an identity

`zk::extension` (`hashline/src/zk.rs`, the only place `run_slot` and the private seam build an extension round) now
asserts `s_k(1) = poly(ext) = 0` before masking and absorbing the round.
- The verifier already requires `s_k(0) + s_k(1) = poly(fin)`, so this cannot refuse an honest proof that would verify.
  It only stops the prover from publishing the defect `poly(ext)` in a receipt that would be rejected anyway.
- Checks (`results/zk60_h124_witness_20261104/`, `ext.progress`, `ext_full2.log`):
  - full lib suite 899 passed / 3 failed / 93 ignored, the failures exactly the known three;
  - the refusal never fired;
  - the W16R2 rung golden and the six pinned trained digests are unchanged.
- The first suite run (`ext_full.log`, 32 failures) lacked `HL_R13_LOADER_FIXTURES`. It was rerun with the variable set,
  as earlier suites were.

## Third batch, 2026-11-04: M's whole opening view, the refusal bit, one block composed

Three new files: `HidingMOpening.lean`, `HidingRefusal.lean` and `HidingBlock.lean`.
- `lake -d formal build` succeeds with no warnings, and no file uses `sorry`, `axiom`, `admit` or `native_decide`.
- `#print axioms` was run on every declaration of the three files (64 of them). Each depends only on `propext`,
  `Classical.choice` and `Quot.sound`, or on fewer.

### Proved (honest verifier, fixed challenges)

- **M's whole opening view** (`HidingMOpening.lean`).
  - What the verifier sees, from `zk.rs` (`mask_commit_tagged`, `mask_open`, `mask_verify_tagged`):
    - `q' = Σ_s p_{a_s}·p_{W_s} + p_b`, as 1024 Fp2 coefficients. The code computes it in components:
      `q_re = b_re + Σ (a_re·w_re + 7·a_im·w_im)` and `q_im = b_im + Σ (a_re·w_im + a_im·w_re)`;
    - `prox = u + Σ_rows r_row·row`, as 1024 Fp2 coefficients, over the a-rows and `b_re`, `b_im`;
    - at each of the 256 sampled columns, the value of every base row: the a-rows, `b_re`, `b_im`, `u_re`, `u_im`.
  - `mOpenView_law_eq`: the joint law of all of it, over the pads, `b` and `u`, depends on the CFS mask coefficients
    **only through the functional value `V`** (both components). The verifier computes `V` itself, from the `g(ρ)`'s
    and the scalars, so `M` adds nothing. A simulator runs the honest opening with ANY coefficients of value `V`.
  - The proof is the coin shift (`mOpenView_shift`):
    - the a-row pads absorb the coefficients' opened values (`mPad_reach`, from `mPadBlock_surjective`);
    - `b` absorbs the change of `Σ p_a·p_W`. The change has zero sum over `G_512` exactly because `V` is unchanged
      (`sum_eval_nodes`, `rootsOfUnity_powSum`), so the shifted `b` keeps the code's constraint `b_512 = −b_0`;
    - `u` absorbs the change of the proximity vector;
    - every shift vanishes at the sampled points.
  - `mOpenView_joint_law_eq` is the joint form with the rest of the view. `mask_open_law_eq` is the statement on the
    code's layout (`mRowMsg`, pads at `L_s + l`, weights only on `0..L_s`, `G_512` in natural order, `7·G_4096`,
    samples with replacement).
  - The Fp2 reading. A code pair `(c0, c1)` is `c0 + U·c1` in an extension `K` with `U² = 7`:
    - `fp2_mul` is the code's multiplication rule (`Fp2::mul`), and `fp2_mul_base` is `mul_base`;
    - `fp2_bijective`: `{1, U}` is an `F`-basis of `K` when `[K : F] = 2` and `7` is not a square in `F`;
    - `adjoinRoot_finrank`: `F[u]/(u² − κ)` is such a `K` for any non-square `κ`;
    - `fp2_uniform`: a pair of uniform base-field values is a uniform Fp2 value (the `u = u_re + U·u_im` reading);
    - `mOpenView_law_eq_fp2`: the hypothesis stated as an equality of `V` in `K`.
- **The refusal bit** (`HidingRefusal.lean`). Every prover-side refusal falls in one of five classes:

  | class | sites (code) | data-independent? | Lean |
  |---|---|---|---|
  | (A) public | shape, layout and block checks (CS-1/4/6/7/8), "witness shape", the slot schedule and table shape, `audit_claims`' structural failures, the group count, the endpoint geometry and claim, the NTT ceiling, the trained door's `cap`, the run statement, the wire and file checks | yes: functions of public data | simulated exactly |
  | (B) input admissibility | `witness::build`: "fixed oracle range refusal: <site>" (12 reachable sites); CS-3: a lookup miss, naming the table family; the dictionary miss | NO: deterministic functions of the hidden input | `refusal_output_must_be_leaked` |
  | (C) challenge-only | "zero CFS mask challenge" (`c = 0`); "degenerate terminal mask challenge" (`e ∈ {0, 1}`); "zero batching challenge"; "zero terminal mask coefficient" (`cm = e·∏(1 − e')`); "zero group member coefficient" and "dependent proximity mask coefficients" (`check_opening_challenges`, for `A`, `H` and the endpoints); the `zk.rs` asserts on `c` (unreachable from the private block); `assert_mask_sites` (pre-empted); the OS entropy failure | yes | `attempt_law_eq`, `prob_mem_finset` |
  | (D) structural assertion | `zk::extension`'s "the extension round is not an identity" | yes: it never fires while every slot monomial has a public or `eq` factor (NL-1 S1) | a special case of (C) |
  | (E) LogUp denominators, public tables | "zero LogUp denominator" for the byte, exp, activation, W16 range and R13 ACT tables | yes: every table entry is inverted on every attempt (S28-F1), and after CS-3 every looked tuple is a table tuple | `logup_refusal_iff_table` |
  | (E) LogUp denominators, private values | the same refusal for the DD dictionary (D30) and the next-token stages IN and OUT (D34) | NO: the inverted values include private ones | `logup_attempt_prob_le` |

  - `attempt_law_eq`: a refusal that is a function of the challenges alone, composed with any view whose law at each
    challenge value is data-independent, gives a law of (refused or served, challenges, transcript) that is the same
    for all data.
  - `attempt_prob_le`: a data-dependent refusal moves every probability by at most the chance that the two refusal
    predicates differ.
  - `logup_attempt_prob_le`: with at most `N` and `N'` data-dependent inverted values, that chance is at most
    `(N + N')/|K|`, and the public table entries cancel.
  - `refusal_output_must_be_leaked` is a theorem about the approved `ZeroKnowledge` itself. Take two inputs with the
    same public output part and the same declared leakage. If the prover gives them two different fixed outputs (a
    class (B) refusal), then every simulator has advantage at least `1/2` against one proof request with no hash
    query.
  - **Answer to the statement's question.** The served bit is needed, because class (B) is a function of the hidden
    input. For admissible inputs, classes (A), (C) and (D) are data-independent. Class (E) is data-dependent only at
    the DD and next-token profiles, by at most `N/|Fp2|` per block or token stage. That belongs in `εzk`, not in the
    leakage. But the bit is not enough as the code stands (finding 1).
- **One block composed** (`HidingBlock.lean`).
  - `block_view_law_eq`: suppose the openings' view has a data-independent law, the slots' view is simulated from it,
    and `M`'s view is simulated from both. Then the whole block view has the same law for every data as for zero
    data. The simulator runs the openings on zero data, then the slot simulator, then `M`'s.
  - `block_view_law_eq_slot_M`: the same with the slot layer and the `M` layer instantiated by the proved lemmas
    (`cfsViewMasked_joint_law_eq`, `mOpenView_joint_law_eq`). What remains as hypotheses:
    - the opening layer, proved separately for `A` and `H`;
    - the two links of the instance: the slot's defects are a function of the opening view (its masked terminals are
      claim values), and `M`'s functional value is a function of the slot's view.

### What the proofs showed about the code

1. **A class (B) refusal returns more than "refused" (Medium for T2 as worded).**
   - `private_block::prove` returns `witness::build`'s "fixed oracle range refusal: <site>". The site is one of 12, so
     it says where the hidden input left the integer class.
   - CS-3 names the table family that missed. Ruling K-2 keeps the count out, but the family is still a function of
     the hidden input.
   - The declared leakage in `Statements.lean` (`Leak`: "whether it is served") does not determine these messages. By
     `refusal_output_must_be_leaked`, `ZeroKnowledge` then fails, with advantage at least 1/2, against a
     distinguisher that submits two inputs refused at different sites.
   - **Fix, one of:**
     - the external refusal is one constant ("refused"), and the site and family go to a private log only;
     - or Victor widens the declared leakage to "the refusal class". That changes the approved statement's wording,
       so it needs his ruling.
2. **At the DD profiles, the data-dependent LogUp refusal exceeds the proposed per-request `εzk` term (Medium for the
   error target).**
   - The tight one-sided term (the real prover against a simulator that refuses on the public values only) is
     `|Dd|/|Fp2|` per block. `|Dd| = q_heads·T·cap` is `2^17` at the T128 DD profiles (TinyLlama, Llama-3-8B and the
     R13 DD variants) and `2^18` at Shieldstral T256 DD.
   - That is about `2^-111` per block, and `2^-106` for a 32-block run.
   - The proposed target is `εzk = q·2^-128 + R·2^-120`. The expected sources listed in
     `ZK60_LEAN_PRODUCTION_STATEMENTS.md` §4 do not include this term.
   - The next-token stages (D34): `(T + 256)/|Fp2|` per run by the tight count, about `2^-119.8` at `T = 32`, just
     above `2^-120`.
   - **Decision for Victor:** a profile-dependent per-request term (about `2^-100` covers every DD profile), or a
     design change that makes the dictionary refusal challenge-only.
3. **D30 (4)'s and D34's counts are upper bounds and can be tightened (Info).**
   - D30 (4) counts `2·L·(768 + rows·cap)/p²`, and D34 counts `2·(768L + 32 + 256)/p²`.
   - The public table entries (the `768` per block) cancel: both worlds refuse on them alike.
   - The factor 2 is not needed against a simulator that refuses on the public values only.
4. **The `zk.rs` header's plan for `M` holds (Info).** "`q'` is uniform given `V`; `b` and `u` are determined" is
   proved in the form "the view's law depends on the coefficients only through `V`". Two code facts carry the proof
   and must stay:
   - `combined_weights` writes weights only on the coefficient positions `0..L_s`, so the pads (at
     `L_s..L_s + 256`) never enter `V`;
   - `b_512 = −b_0`, the constraint the shift preserves.

   `b` and `u` need no pads: they have 1024 free coefficients each, and their shifts vanish at the sampled points by
   construction. Only the a-rows need "distinct samples ≤ pads".
5. **Two refusals are panics, not errors (Low).**
   - `zk::extension`'s identity assert and the `zk.rs` asserts on `c` panic instead of returning `Err`.
   - Neither depends on the data: the first never fires, and the second is unreachable from the private block.
   - A panic in a long-lived prover is an observable abort with its own message. Returning the same `Err` as the
     other refusals would make the output uniform.
6. **Under P3 (weights hidden), re-check class (E).** The exp and activation tables are public under P1. If P3 makes
   them private, the public-table argument no longer applies, and they join the dictionary's case.

### Hypotheses the new theorems take from the code

- **M:**
  - `512 ≠ 0` in `F`;
  - `G_512` in natural order, and `7^4096 ≠ 1`;
  - at most 256 distinct sampled columns;
  - weights zero at the pad positions;
  - `b_512 := −b_0`;
  - `7` a non-square (checked numerically 2026-11-04, not proved in Lean);
  - one opening.
- **Refusal:**
  - challenges uniform and independent of the data (honest verifier, before Fiat–Shamir);
  - CS-3 runs before the LogUp inversions;
  - every public table entry is inverted on every attempt;
  - no retry on the same transcript.
- **Composition:**
  - independent coins for the openings, the masks and `M`;
  - the two links, stated as hypotheses.

### Still open for L4 (replaces the list above)

- Fiat–Shamir: the challenges, the sampled columns and the opened set depend on the transcript and the roots.
- The links for the registered layouts:
  - which claim value is which masked terminal;
  - which `M` functional is which `g(ρ)` or `Γ` (a host slot's scalar combines other slots' totals);
  - the code's `CfsMask` coefficient layout as `M`'s a-row messages.
- Several slots at once (`Ω₂` a product), several blocks, the D12a/D55 run structure and R receipts.
- Finding 1 (class (B)'s refusal output) and finding 2 (the `εzk` target at the DD profiles). Both need a ruling or a
  code change before `ZeroKnowledge` can be proved as worded.
- The instance that connects all of this to `ZeroKnowledge` in `Statements.lean`.
