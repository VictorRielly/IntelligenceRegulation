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
