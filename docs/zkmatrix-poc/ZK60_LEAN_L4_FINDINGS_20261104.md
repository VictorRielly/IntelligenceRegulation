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
