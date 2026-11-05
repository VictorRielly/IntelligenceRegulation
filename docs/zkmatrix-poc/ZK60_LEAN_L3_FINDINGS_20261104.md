# D63 step L3: the first soundness proofs, how they compare with our count, and what they exposed (2026-11-04)

The Lean files are under `formal/ZK60Formal/`: `SoundSchwartzZippel.lean`, `SoundSumcheck.lean`,
`SoundMultilinear.lean`, `SoundLogUp.lean`, `SoundLogUpBlock.lean` and `SoundZeroCheck.lean`.
- `lake -d formal build` succeeds with no warnings. No file uses `sorry`, `axiom`, `admit` or `native_decide`.
- `#print axioms` was run on all 78 theorems of the six files. Each depends only on `propext`,
  `Classical.choice` and `Quot.sound`, or on fewer.
- No new lake dependency. Only Mathlib is used, including its `Lagrange` interpolation and `RatFunc`. Nothing was
  copied from FlashProve or ArkLib.

**Scope.** These are the foundations of step L3. Every bound below is INTERACTIVE:
- the challenges are exactly uniform and independent;
- the prover is arbitrary, unbounded and adaptive;
- Fiat–Shamir is not modelled.

The count does the same: it is an interactive union bound, which under Fiat–Shamir is a per-attempt rate
(ACCOUNTING.md, A2). Nothing here is yet a statement about a whole receipt, or about `KnowledgeSound` in
`Statements.lean`.

## 1. What is proved

`F` is any finite field. For our protocol it is `Fp2`, with `|F| = p²` and `p = 2^64 − 2^32 + 1`. Probabilities are
`(PMF.uniformOfFintype Ω).toOuterMeasure {…}` in `ℝ≥0∞`, as in `Statements.lean`.

**Schwartz–Zippel, univariate** (`SoundSchwartzZippel.lean`).
```lean
theorem schwartzZippel {p : F[X]} (hp : p ≠ 0) {d : ℕ} (hd : p.natDegree ≤ d) :
    (PMF.uniformOfFintype F).toOuterMeasure {r | p.eval r = 0} ≤ (d : ℝ≥0∞) / Fintype.card F
theorem schwartzZippel_ne {p q : F[X]} (hpq : p ≠ q) {d : ℕ} (hp : p.natDegree ≤ d) (hq : q.natDegree ≤ d) :
    (PMF.uniformOfFintype F).toOuterMeasure {r | p.eval r = q.eval r} ≤ (d : ℝ≥0∞) / Fintype.card F
```

**The sumcheck** (`SoundSumcheck.lean`). The model follows `zkp_core::sumcheck`.
- Round messages are `d + 1` values at `X = 0, …, d`.
- The verifier checks `s(0) + s(1) = claim`, draws `r`, and continues with the claim `interpolate_eval(s, r)`.
- The caller's terminal check is `f(r)`.
- Round `j` fixes variable `j`.
- `interpEval` is the code's formula, and `interpEval_eq` proves that it equals the Lagrange interpolant.
- A prover is a strategy tree (`Prover F d n`): the first message, then for each challenge a strategy for the rest.
  That is every choice of round messages as functions of the earlier challenges.
- `IndDegLE d f` means that `f` has degree `≤ d` in each variable once the others are fixed.

```lean
theorem sumcheck_sound {n d : ℕ} (hd : d < ringChar F) {f : (Fin n → F) → F} (hf : IndDegLE d f) {C : F}
    (hC : C ≠ cubeSum f) (P : Prover F d n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure {r | Accepts n f C P r}
      ≤ ((n * d : ℕ) : ℝ≥0∞) / Fintype.card F
```
The same file also proves:
- **One round:** `sumcheck_sound_one_round`, `d/|F|`.
- **The masked sumcheck:** `sumcheck_sound_masked`. The sumcheck runs on `f + c·g` with the claim `S + c·Σg`. The
  bound `n·d/|F|` holds for ANY mask `g` of individual degree `≤ d` and ANY `c`.
- **The last-round extension:** `sumcheck_sound_extended` gives `(n + 1)·d/|F|` when the trailing variable's `y = 1`
  half vanishes on the cube. `extension_halves` proves that the code's extension has that property whenever `poly`
  vanishes once its public inputs are zero.

**The code's own form** (`SoundMultilinear.lean`). Here the tables live on the cube, `poly` is an `MvPolynomial` of
total degree `≤ d`, and the terminal check is `poly` of the tables' multilinear extensions at `r` (the code's
`poly(finals)`).
```lean
theorem sumcheck_sound_tables {n k d : ℕ} (hd : d < ringChar F) (T : Fin k → (Fin n → Bool) → F)
    (poly : MvPolynomial (Fin k) F) (hp : poly.totalDegree ≤ d) {C : F}
    (hC : C ≠ ∑ b : Fin n → Bool, MvPolynomial.eval (fun t => T t b) poly) (P : Prover F d n) :
    (PMF.uniformOfFintype (Fin n → F)).toOuterMeasure
        {r | Accepts n (fun x => MvPolynomial.eval (fun t => mleAt (T t) x) poly) C P r}
      ≤ ((n * d : ℕ) : ℝ≥0∞) / Fintype.card F
```

**LogUp, algebraic** (`SoundLogUp.lean`). Lookups `a : ι → F`, a table `t : κ → F` (positions may repeat a value)
and multiplicities `m : κ → F`. `logupLhs` and `logupRhs` live in `RatFunc F`.
```lean
theorem logup_iff_counts (a : ι → F) (t : κ → F) (m : κ → F) :
    logupLhs a = logupRhs t m ↔ ∀ v, lookCount a v = tableMass t m v
theorem logup_mem_of_eq (a : ι → F) (t : κ → F) (m : κ → F) (hN : Fintype.card ι < ringChar F)
    (h : logupLhs a = logupRhs t m) (i : ι) : ∃ j, t j = a i
theorem logup_iff_multiset (a : ι → F) (t : κ → F) (μ : κ → ℕ) (hN : Fintype.card ι < ringChar F)
    (hμ : ∑ j, μ j < ringChar F) :
    logupLhs a = logupRhs t (fun j => (μ j : F)) ↔ univ.val.map a = ∑ j, μ j • ({t j} : Multiset F)
```
- `lookCount a v` is the number of lookups equal to `v`, as a field element.
- `tableMass t m v` is `Σ_{j : t_j = v} m_j`.
- The soundness direction, `logup_mem_of_eq`, needs only `N < char F`. The multiplicities may be ANY field elements.
- The multiset form also needs `Σ μ < char F`. This is the "characteristic exceeds the multiplicities and `|A|`"
  condition.

**LogUp, the random challenge** (`SoundLogUp.lean`). `S = poles a t` is the set of distinct lookup and table values.
```lean
theorem logup_challenge_bound (a : ι → F) (t : κ → F) (m : κ → F) (h : logupLhs a ≠ logupRhs t m) :
    (PMF.uniformOfFintype F).toOuterMeasure {x | x ∉ poles a t ∧ logupLhsAt a x = logupRhsAt t m x}
      ≤ (((poles a t).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F
```
`logup_challenge_bound'` gives `≤ (N + M − 1)/|F|` with `N` lookups and `M` table positions. That is sharper than the
`(|A| + |T|)/|F|` the task suggested. The event is "`α` is not a pole AND the two sums agree at `α`". At a pole the
sums are not defined. How the protocol handles poles is the next item.

**LogUp as the code runs it** (`SoundLogUpBlock.lean`). The model has:
- single helpers `h·(α − a) = 1`;
- pair helpers `h·(α − a)(α − b) = (α − a) + (α − b)` (`argument::helper_sum`);
- table helpers `g·(α − t) = m` (`SC_TAB`);
- the value-0 sum claim (`logup_sum_claim`);
- lookups as tuples `(x, tag, y, z)`, folded as `x + γ·tag + β·y + β²·z`.

Off the poles, the relations force the helpers (`helperRel_forces`). At a pole that is not bad, no helpers exist
(`helperRel_none`). A bad pole is a zero-multiplicity table value or an equal-pair pole: REVIEW_R13's B2.
```lean
theorem logup_block_bound (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar F) (l : ι ⊕ (π ⊕ π)) (hl : ∀ j, T j ≠ A l) :
    (PMF.uniformOfFintype ((F × F) × F)).toOuterMeasure
        {ω | ∃ H, HelperRel (fun l => fold ω.1.1 ω.1.2 (A l)) (fun j => fold ω.1.1 ω.1.2 (T j)) m ω.2 H}
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 4 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞) / Fintype.card F
```
- The sizes: `N = |ι| + 2|π|` lookups (singles and pairs) and `M = (univ.image T).card` distinct table tuples.
- The pieces: `logup_helpers_bound` is `(N + 2M − 1)/|F|` over `α` alone, and `fold_collision_card` is `2/|F|` per
  pair of different tuples.

**The zero-check and batching** (`SoundZeroCheck.lean`).
- `mle_zero_prob`: if `P` is nonzero somewhere on the cube, `Pr_τ[Σ_b eq(τ, b)·P(b) = 0] ≤ n/|F|`.
- `zerocheck_sound`: for `R` of individual degree `≤ d` that is nonzero somewhere on the cube, the claim
  `Σ_x eq(τ, x)·R(x) = 0` is accepted with probability `≤ (n + n·(d + 1))/|F|` over `τ` and the sumcheck challenges.
  The prover may choose its strategy after seeing `τ`.
- `batch_prob`: independent uniform coefficients kill a nonzero relation vector with probability `≤ 1/|F|`.

## 2. How the bounds compare with the count

The count is `results/zk60_w16r2_q280_20261103/recount_q280.out.txt` (`count.py`, `accounting_recheck.py`). Here
`|F| = |Fp2| = p²`.

| Per block (8B T128, W16R2 Q 280) | Count | Lean | Status |
|---|---|---|---|
| LogUp | `(N_lk + 4·T_d − 1)/p²` = 35,408,591/p² = **2^-102.922** | `logup_block_bound`: `(N + 4M − 1)/|F|`, `N` = lookups, `M` = distinct table tuples | **Same formula.** With `N = N_lk = 34,897,920` and `M = T_d = 127,668` it gives the same 2^-102.922. The split agrees term by term with REVIEW_R13 §3: B1 (fold) `2·T_d`; B2 + B3 (`α`) `N + 2·T_d − 1` |
| Sumcheck | `Σ (main + ext)·degree / p²` = 1099/p² = **2^-117.898** | `sumcheck_sound_extended`: `(main + 1)·degree/|F|` per slot; `sumcheck_sound_masked` shows the CFS mask changes nothing | **Same formula** for the 21 slots with one extension round. The two `(10, 2, 3)` slots (bilinear score / PV, two extension rounds) need the two-variable form. It is the same argument and is not yet written |
| Zero-check, batching, output-point allowance | `Σ (3(main + ext) + 3)/p²` = 1179/p² = **2^-117.797** | The `τ` draw costs `main/|F|` (`mle_zero_prob`). Each independent `μ` batch costs `1/|F|` (`batch_prob`). Summed over all 23 slots as if each were a zero-check with one batch: 368/p² | **Not yet reproduced, but the allowance has room.** The proved pieces use 368 of the 1179. Still uncounted by a lemma: the powers-of-`ζ` pad-term batching (`(k − 1)/|F|` for `k` planes), the `ν` pair, and the output points |
| Whole run, 32 blocks | LogUp-bound: 32 × 2^-102.922 = 2^-97.922; whole 2^-97.779 | — | The union over blocks, the PCS terms and composition are not yet theorems |

Caveats on reading the LogUp row:
- **`T_d` counts distinct table entries:** 256 + 256 + 4096·G + Σ2^w, with G = 4 as a conservative choice. The
  table helper columns run over every table POSITION, including the padded copies (`Dom::Tab` is the full row width).
  A first version of the Lean bound charged positions, which would have been far larger than the count. The final
  version charges distinct tuples (`univ.image T`). It needs no assumption about the padded copies, because a copy
  repeats an existing tuple. So `T_d` is the right quantity, as long as it counts distinct tuples, which is how it is
  derived.
- **`N_lk` counts lookup positions**, two per pair helper. The Lean `N` is the same.
- **The theorem is about one bad lookup in one block.** Several bad lookups do not add terms: one is enough to fail.

## 3. Where the code differs from the textbook protocols (the Lean model follows the code)

1. **Round polynomials are sent as values, not coefficients.**
   - The verifier checks only the length, `d + 1`.
   - Interpolation through the nodes `0, …, d` then bounds the degree automatically. This needs the nodes to be
     distinct, i.e. `d < char F` (`node_injective`).
   - The code meets this with `d ≤ 5` and `char = p ≈ 2^64`.
   - At `d = 0` the code's `s[1]` would be out of bounds. No slot has `d < 2`, and the Lean model handles `d = 0`
     anyway (`msg_zero_add_one`).
2. **The terminal check is the caller's.** The verifier compares the final claim with `poly` of terminal values
   opened from the PCS. The Lean verifier evaluates `f` at the challenge point. That the opened values ARE the
   tables' multilinear extensions there is the PCS's job, which is the next part of L3.
3. **The masked sumcheck's claim is published after `c`, as one scalar `S'' = s + c·G`.**
   - The lemma holds for any `g`, any `c` and any `S''`, with `S := S'' − c·Σg`.
   - It needs the `G` and `g(ρ)` the verifier uses to come from the same committed `g`. That holds: `M` is committed
     before `β, γ, α` and before every `c`.
   - That `S` is the right value (the zero-checks' claims derived through `Γ`) is cross-slot composition, not yet
     formalized.
4. **The last-round extension** (finding F1 below).
5. **LogUp is not one identity check.**
   - The code's form adds helpers per lookup or pair and per table position, relations zero-checked on the cube, one
     value-0 sum claim over every domain of the block, the zero-sum mask row `u`, and the `(β, γ)` fold.
   - The model leaves `u` out. Its sum is zero by its own sumcheck (`SC_ZS`).
   - The model takes every summed helper to have exactly its own relation. The code enforces this: `layout.rs:1377`
     refuses a helper count other than `⌈lookups/2⌉`, which closes REVIEW_W16 finding F2.
6. **The characteristic condition is met by a wide margin.**
   - LogUp needs `N < char F` for the lookups of one sum claim: one block's `N_lk ≈ 2^25.06`, against `p ≈ 2^64`.
   - The multiplicities are free field elements in `A`. Nothing about them needs checking for soundness. They must be
     committed before `β, γ, α`, and they are.
7. **Challenges are not exactly uniform.** `challenge_fp2` reduces 128 hash bits mod `p` per coordinate. Pointwise,
   each coordinate's probability is at most `(1 + p/2^128)/p`. Each Lean bound therefore carries a factor of at most
   `(1 + 2^-64)^(2k)` for `k` `Fp2` challenges. That is negligible, but the Fiat–Shamir step must state it.
   `nonzero(…)` and `c ≠ 0` refuse zero draws, which only adds rejection.

## 4. Findings (to act on)

**F1 (Medium: a soundness premise mislabelled as a completeness premise).** The header of `private_block/argument.rs`
says this about slot polynomials:
> CONSTRUCTION PREMISE (not re-derived here): every slot polynomial has a public factor … in every monomial, so
> `poly(extensions) = 0` … a new term without a public factor would make honest proofs fail, not leak.

For soundness the consequence is worse than "honest proofs fail".
- **What the theorem needs.** `sumcheck_sound_extended` needs the `y = 1` half `Σ_x poly(R(x), 0)` to vanish.
  `extension_halves` shows that this is exactly the premise.
- **What goes wrong without it.** If some monomial has no public factor, that half is a polynomial in the mask rows
  `R`. The mask rows are free reserved rows that a cheating prover chooses. The prover can solve
  `Σ_x poly(R(x), 0) = C − Σ_x f(x)`. That makes the extended claim TRUE for a false `C`, and the honest sumcheck
  algorithm then passes with probability 1.
- **Why nothing breaks today.**
  - The premise holds by construction.
  - Honest round trips would expose a violation with high probability (random `R`, by Schwartz–Zippel).
  - The prover now asserts `poly(ext) = 0` (commit 333c4ba5).
- **The gap.** No verifier-side or static check exists, and the premise is load-bearing for soundness.
- **Suggested:**
  - (a) correct the comment;
  - (b) add a cheap static test: for each of the 23 slots, evaluate `poly` with every public input zero at random
    private inputs, on both sides, and assert zero;
  - (c) prove the premise per slot in the Lean instance.

**F2 (Low, latent: unbatched relations in `SC_LZC`).** `argument.rs:1774` builds `SC_LZC` with
`mu = vec![Fp2::ONE; sh.helpers(Dom::L)]`. Its helper relations are summed with coefficient 1 and no `μ` is drawn.
- **Why it is sound today.** `lookups_per_position(Dom::L) = 2` in every branch of `shape.rs`, so there is one pair
  helper and one relation. The pad term has its own random `μ_pad`.
- **The hazard.** With two or more helpers on `Dom::L`, their relations could cancel each other pointwise on the cube.
  The single sum claim could then absorb a failed lookup.
- **The gap.** Nothing at the slot asserts `helpers(Dom::L) == 1`.
- **Suggested:** draw `μ` as every other slot does (`tr.challenge_fp2_vec`, covered by `batch_prob`), or refuse by
  name when `helpers(Dom::L) != 1`.

**F3 (Info: the count does not itemize two batching terms).**
- **The pad-zero term.** It batches its planes with powers of ONE challenge `ζ` (`argument.rs:1439`, "their power of
  the slot's single batching challenge"). Powers cost `(k − 1)/|F|` for `k` planes, not `1/|F|`.
- **The `ν` pair.** It is not itemized either.
- **Both are probably inside the zero-check allowance** (§2: 368 of 1179 is used by the proved pieces). They should
  be itemized when the allowance becomes a theorem.

**F4 (Info: the LogUp conclusion is about FIELD tuples).**
- Two integer tuples whose casts agree mod `p` are the same lookup.
- So `CircuitIff` (L2) must show that every fold coordinate (`x`, `tag`, `y`, `z`) is a canonical representative.
- The range arguments are the place to do this. Wrap-freeness is already recorded as the L2 obligation.

## 5. What remains for L3

- **The PCS.** (Part 2 below proves the first two items per opening; its §P6 is the updated list.)
  - Ligero-style proximity at δ/3 (rate 1/4, D15) and at δ/2 (rate 1/2, D59, BCIKS20 Thm 3.1).
  - The column test and the field term.
  - Merkle binding in the random-oracle model, with the q-dependent bound.
  - The reduction from "terminal values opened" to "they are the multilinear extensions at the point".
  - FlashProve's Apache-2.0 Lean library proves the Reed–Solomon proximity results; it is the natural source.
- **Slot-level pieces.**
  - The two-extension-variable slots.
  - The zero-check, the extension and the mask in one statement.
  - The powers-of-`ζ` batching and the output points, to turn the zero-check allowance into a theorem.
- **Composition.**
  - One block's IOP: the 23 slots, `A`/`H`/`M`, and the `Γ` functionals that link the masked sums, written as a union
    bound with the code's challenge order.
  - Then the L blocks and the D55 fork–join, with the 3L + 1 regular and L mask openings.
- **Fiat–Shamir in the random-oracle model.** The q-dependent `εs q` of `Statements.lean`, with the challenge bias of
  §3.7 and the refusals.
- **The instances.**
  - The 23 slot polynomials: their degrees and the public-factor premise of F1.
  - `N_lk` and `T_d` derived from the layout in Lean.
  - The extractor for `KnowledgeSound`, from the hash-query log.

## Coordinator's note on F1 (2026-11-04)

The premise F1 depends on, "a public factor in every monomial" of every slot polynomial, is already checked
statically by the Python privacy gate: NL-1 S1 ("premise, a public factor in every monomial").
- The FR25-17 closing run passed it on all 23 slots in all four challenge modes, at fork 1 of the 8B T128,
  Shieldstral T256 and TinyLlama T128 registered bundles (`results/zk60_d60_20261102/privacy_gate_fr25_17/`).
- The merged 18-part gate covers the other seven slots on every registered bundle.
- So the property holds on everything registered today.

What F1 adds is that it is a SOUNDNESS premise too, not only a privacy one. Still owed, as the finding says:
- a Rust-side static test per slot (every public input zero, random private inputs: `poly` must vanish);
- the corrected `argument.rs` header comment;
- the premise proved per slot in the Lean instance (L2/L3).

# Part 2 (2026-11-04): the polynomial commitment's column test and proximity test

New files under `formal/ZK60Formal/`: `SoundColumnTest.lean`, `SoundProximity.lean`, `SoundProximityRS.lean`,
`SoundOpening.lean`, and `ThirdParty/FlashProve/` (15 files adapted from FlashProve, see §P5).
- `lake -d formal build` succeeds with no warnings (3381 jobs). No file uses `sorry`, `axiom`, `admit`,
  `native_decide` or a `maxHeartbeats` option.
- `#print axioms` was run on all 41 new theorems and on 11 ported FlashProve theorems they rest on (`caOn_rsCode`,
  `caOn_rsCode_tight`, `mca_rsCode`, `minDist_rsCode`, `lines_tight`, `cnt_close_le`, `mca_third`, `CAOn.of_one_row`,
  `MCAOn.of_one_row`, `MinDist.extendCode`, `MinDist.decode_unique`). Each depends on `propext`, `Classical.choice`
  and `Quot.sound` only.
- No new lake dependency.

**Scope.** As in part 1: interactive, challenges exactly uniform and independent, the prover arbitrary. In addition
the committed matrix `U` is FIXED before the challenges: that the opened columns are columns of one `U` is Merkle
binding, a separate random-oracle step not done here.

## P1. What is proved

Notation (FlashProve's, ported):
- a code is a subspace `D` of `ι → E`; `MinDist D d`: every nonzero codeword has at least `d` nonzero symbols;
- `Close D e f` for `f : R → ι → E`: on one common set of all but at most `e` columns every row agrees with a codeword
  (one word `w`: `Close D e (fun _ : Unit => w)`);
- `CAOn Unit D e A`: two words that are not close together have at most `A` values `z` with `f₀ + z·f₁` close;
- `comb U r = Σ_i r_i • U i`; `rsCode dom K`: the polynomials of degree `≤ K` at the distinct points `dom : ι ↪ L`.

**Task 1, the column test** (`SoundColumnTest.lean`). `Q` indices drawn uniformly WITH replacement (the code's
`challenge_indices`: a masked `u64` per draw, `N` a power of two):
```lean
theorem column_miss_prob (D : Finset ι) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, J k ∉ D}
      = (((Fintype.card ι - D.card : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q
theorem column_test_sound {F : Type} [DecidableEq F] (w v : ι → F) {e : ℕ}
    (h : e + 1 ≤ (univ.filter (fun j => w j ≠ v j)).card) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | ∀ k, w (J k) = v (J k)}
      ≤ (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q
theorem third_column_le {N K e : ℕ} (hN : 0 < N) (he : N - K ≤ 3 * (e + 1)) (Q : ℕ) :
    (((N - (e + 1) : ℕ) : ℝ≥0∞) / N) ^ Q ≤ (((2 * N + K : ℕ) : ℝ≥0∞) / (3 * N : ℕ)) ^ Q
```
- `column_test_sound` is `count.py`'s exact integer form, `Q_(nn − e − 1, nn) ** q`. The law is exact
  (`column_miss_prob` is an equality), and `card_miss` is the count `(N − |D|)^Q` itself.
- `third_column_le`: the rate-1/4 count prices the column term as `((2N + K)/(3N))^Q = (1 − δ/3)^Q` while it uses
  the radius `e = ⌊(N − K)/3⌋`. Since `3(e + 1) > N − K`, the proved term is never larger: the count is conservative.

**Task 2, the proximity lemma, for any linear code** (`SoundProximity.lean`).
```lean
theorem comb_close_prob [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ}
    (hd : MinDist D d) (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit D e A)
    (U : κ → ι → E) (hfar : ¬ Close D e U) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => comb U r)}
      ≤ (A : ℝ≥0∞) / Fintype.card E
theorem proximity_third [Fintype E] [DecidableEq κ] {D : Submodule E (ι → E)} {d e : ℕ}
    (hd : MinDist D d) (h3 : 3 * e < d) (U : κ → ι → E) (hfar : ¬ Close D e U) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | Close D e (fun _ : Unit => comb U r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card E
```
- `comb_close_prob` is the step from a line theorem to independent uniform weights on any number of rows, WITH NO
  LOSS: the error for `m` rows is the line error `A/|E|`. This is the form of BCIKS20 Thm 1.7 and Thm 3.1, here for
  every linear code with `2e < d`. The proof has two cases.
  - Some combination `Σ b_i U_i` is far (`comb_close_cnt_of_far_dir`). Then along every line `a + z·b` of weights at
    most `A` points are close, and those lines cover the weight space.
  - Every combination is close (`all_close_absurd`). Then every pair of combinations is close together (the whole
    line is close and `|E| > A`), so unique decoding is linear, `v(r) = Σ r_i V_i`. If `U` and `V` differed in
    `e + 1` columns, some weight vector would be nonzero on all of them, since `(e + 1)·|E|^(m−1) < |E|^m`, and its
    combination would be `(e + 1)`-far from its own decoding. So `|E| ≤ e + 1 ≤ A`, and the bound is trivial.
- `proximity_third` is the δ/3 lemma (Ligero, AHIV Lemma 4.2 style). The line bound `e + 1` for `3e < d` is the
  Roth–Zémor argument, FlashProve's `cnt_close_le` (ported). The result is exactly `(e + 1)/|E|`, the count's δ/3 field
  term without its carried ceiling.
- `affine_proximity_third` (and `affine_close_prob`): the mask commitment's AFFINE form `u + Σ r_i·U_i` (see F6),
  `(e + 1)/(|E| − 1)`, by homogenizing.

**Task 2, the Reed–Solomon instance, and task 3, δ/2** (`SoundProximityRS.lean`). The code of `pcs.rs` is
`RS[D, K']` with `K' = n + q_pad` message symbols on `N` distinct points (the lemma check §1). Here that is
`rsCode dom (K' − 1)`, of distance `N − K' + 1` (`minDist_rsCode`; `d = N − n + 1` in the task's notation).
```lean
theorem rs_proximity_third [Fintype L] [DecidableEq κ] (dom : ι ↪ L) {e K : ℕ}
    (hn : 3 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → L) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure {r | Close (rsCode dom K) e (fun _ : Unit => comb U r)}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / Fintype.card L
theorem rs_proximity_half [Fintype L] [DecidableEq κ] (dom : ι ↪ L) {e K : ℕ}
    (hn : 2 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → L) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure {r | Close (rsCode dom K) e (fun _ : Unit => comb U r)}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card L
theorem rs_proximity_half_ext [Fintype L] [DecidableEq κ] (dom : ι ↪ F) {e K : ℕ}
    (hn : 2 * e + K + 1 ≤ Fintype.card ι) (U : κ → ι → F) (hfar : ¬ Close (rsCode dom K) e U) :
    (PMF.uniformOfFintype (κ → L)).toOuterMeasure
        {r | Close (rsCode (liftDom L dom) K) e (fun _ : Unit => comb (fun i => liftWord L (U i)) r)}
      ≤ (Fintype.card ι : ℝ≥0∞) / Fintype.card L
```
- `rs_proximity_half` is BCIKS20 Thm 3.1 at the unique-decoding radius (`2e + K' ≤ N`): `N/|L|`. Its line case is
  FlashProve's proof of BCIKS20 Thm 4.1 (`caOn_rsCode`: Berlekamp–Welch over `F[Z]` and Polishchuk–Spielman, ported).
- `rs_proximity_half_ext` and `rs_proximity_third_ext` handle the code's field split: rows over `F` (`F_p`), weights
  over `L` (`F_p²`).
  - `close_of_close_lift`: if the rows read in `L` are `e`-close to the RS code over `L` at the same points, the rows
    are `e`-close over `F`. The proof applies an `F`-linear form `φ` with `φ 1 = 1` to the coefficients of the decoded
    polynomials.
  - So an `F_p` matrix that is far over `F_p` is far over `F_p²`, and the `F_p²` bound applies.

**Task 4, one opening** (`SoundOpening.lean`). The model is one claim group of `pcs::verify_zk_tagged`:
- `U` is fixed;
- the claim is a predicate `ok` on the re-encoded group vector (the verifier re-encodes, so the vectors are
  codewords; its encoder is injective, so a predicate on the clear vector is one on its codeword);
- `ρ` is uniform; the prover's group vector `g ρ` and proximity vector `w ρ` are any functions of `ρ`;
- the `Q` indices are drawn after the vectors.
```lean
theorem opening_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] {D : Submodule E (ι → E)} {d e A : ℕ} (hd : MinDist D d) (h2 : 2 * e < d)
    (hA : e + 1 ≤ A) (hca : CAOn Unit D e A) (U : κ → ι → E) (a : κ → E) (ok : (ι → E) → Prop)
    (g w : (κ → E) → ι → E) (hg : ∀ ρ, g ρ ∈ D) (hw : ∀ ρ, w ρ ∈ D) (Q : ℕ) :
    (PMF.uniformOfFintype ((κ → E) × (Fin Q → ι))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood D e U a ok}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q
```
- `OpeningAccepts`: `ok (g ρ)`, and at every sampled column `g ρ = Σ a_i U_i` and `w ρ = Σ ρ_i U_i`.
- `OpeningGood`: `U` agrees outside at most `e` columns with codeword rows `V` (unique, `Close.unique`), and the claim
  holds of `Σ a_i V_i`. That is, the extracted data satisfies the claim.
- `U` decides between the far and close cases before any challenge, so their terms do not add (the lemma check's
  refinement 1).
  - Far: `A/|E|` for a close combination; otherwise `≥ e + 1` disagreeing columns.
  - Close with a false claim: `g ρ ≠ Σ a_i V_i` are two codewords, so `≥ d − e ≥ e + 1` disagreeing columns, for
    every `ρ`.
- Instances:
  - `opening_sound_rs_third`: `(e + 1)/|E| + col`;
  - `opening_sound_rs_half`: `N/|E| + col`;
  - `opening_sound_rs_third_counted`: the rate-1/4 bound in `count.py`'s own terms,
    `((2N + K')/(3N))^Q + (e + 1 + 4096)/|E|`.

## P2. How the bounds compare with the count

Per opening, `|E| = p²`, against `results/zk60_w16r2_q280_20261103/recount_q280.out.txt` (exact rationals, `log2`):

| Opening | Count: column, field, both | Lean: column, field, both | Status |
|---|---|---|---|
| W16R2 regular (rate 1/2, δ/2; n 2^14, N 2^15, Q 280, K' 16,664, e 8,052) | −113.932, −112.830 (`(N + 4096)/p²`), −112.278 | −113.932, −113.000 (`N/p²`), −112.392 | **Column: the same formula and figure.** Field: the count's term is the proved one plus the 4096 ceiling. `opening_sound_rs_half` |
| W16 regular (rate 1/4, δ/3; N 2^16, Q 256, K' 16,640, e 16,298) | −105.609 (`(1 − δ/3)^Q`), −113.684 (`(e + 1 + 4096)/p²`), −105.604 | −105.611 (`(1 − (e + 1)/N)^Q`), −114.008 (`(e + 1)/p²`), −105.607 | The count is slightly conservative on both terms. `opening_sound_rs_third_counted` proves the counted form itself |
| M (RS(1024, 4096), MASK_Q 256, e 1,024, affine) | −106.250 (`(3/4)^256`), −115.678 (`(2·512 + 1 + 4096)/p²`), −106.248 | proximity half only: −106.370, −117.999 (`(e + 1)/(p² − 1)`) | The proximity half is covered (F6). M's product-form claim test is not modelled |

- **The δ/2 count is now a theorem per opening, in the model of P1.**
  - `2e + K' ≤ N` holds with EQUALITY at the W16R2 point (2·8,052 + 16,664 = 32,768). The theorem's hypothesis is
    inclusive, so the edge is allowed.
  - REVIEW_W16R2's F1 attack attains the column term, so the Lean bound is also tight.
- **The δ/3 count** is dominated term by term by what is proved.
- **No case was found where the count uses a bound stronger than the proved one, or applies a theorem outside its
  hypotheses, for the per-opening PCS terms.** The carried 4096 is pure slack per opening. The regular openings do
  not need it; for M it covers the `|E|/(|E| − 1)` factor many times over.

## P3. What the model assumes, and how it meets the code

1. **`U` is fixed before `ρ`.** The Merkle root precedes the claims, `λ` and `ρ`. That every opened column is a column
   of one `U` is Merkle binding (the RO model, with the tagged verifier's path-length check). It is not yet
   formalized.
2. **The weights are independent and uniform over `F_p²`** (`challenge_fp2_vec(rows)`, every row, mask rows
   included). Powers of one challenge would need BCIKS20 Thm 1.6, with a factor `m − 1`. That is not formalized, and
   it is not what the code does. The challenge bias `(1 + p/2^128)^(2m)` is part 1's §3.7 item.
3. **The code is the full RS code.** `rsCode dom (K' − 1)` is ALL polynomials of degree `< K'`, and the verifier's
   encoder is a bijection onto it (lemma check §1, `pcs.rs:557-569`). The domain only needs `N` distinct points, and
   `7·G_N` qualifies.
4. **The claim check.** `ok` is any predicate on the group vector's codeword. The instance must define it as
   `⟨Dec(c)[..n], c_weights⟩ = Σ λ·value`, with `Dec` the inverse of the verifier's encoder (L2/instance work).
5. **One claim group, fixed row weights `a`.**
   - Several groups: each group's vector is checked at the same columns, and the close-case argument applies to each.
   - The `λ` batching of a group's claims: a false member survives it with probability `≤ 1/|E|` (`batch_prob`). This
     happens in the close case only, so the total is `max(N, 1)/|E|` (the lemma check's refinement 1).
   - Neither is a Lean statement yet.

## P4. Findings

**F5 (Info: the count's per-opening PCS terms are proved).** See P2.
- Both regimes are covered, with the code's sampling (with replacement), its weights (independent uniform `F_p²`), its
  field split (`F_p` rows) and its exact integer radius `e`.
- The rate-1/2 field term needs no ceiling; the 4096 can be kept as slack or dropped.

**F6 (Low: the mask commitment's proximity combination is affine, and its claim test is not a linear one).**
`zk::mask_verify_tagged` combines the rows as `u + Σ r_i·row_i` (`zk.rs:594-600`, `:688-690`). The proximity mask
`u = u_re + i·u_im` has the fixed coefficient 1; only the `2·specs + 2` other rows get uniform weights.
- BCIKS20 Thm 3.1 / Thm 1.7 and Ligero's Lemma 4.2 are stated for LINEAR combinations.
  - The affine form is proved here with `(e + 1)/(|E| − 1)` (`affine_proximity_third`), not `(e + 1)/|E|`.
  - The count's M field term is covered only because it carries the 4096 ceiling: `2·512 + 1` alone would be short
    by the factor `p²/(p² − 1)`.
- Reading `u` over `F_p` (two committed rows with the fixed coefficients `1, i`) needs `{1, i}` to be an `F_p`-basis
  of `F_p²`. That is an instance obligation, not proved.
- M's functionals are checked by a PRODUCT-form test (`q' = Σ p_{a_s}·p_{W_s} + p_b`, `zk.rs:355-370`), not by a
  linear group vector. Its close case is a different argument and has no Lean statement yet.

**F7 (Info: the field split is sound).**
- The count applies Thm 3.1 over `F_p²` to an `F_p` matrix.
- Proved (`close_of_close_lift`): far over `F_p` implies far over `F_p²` at the same points, and the decoded rows are
  over `F_p`.
- This is BCIKS20 Remark 1.5 as the lemma check used it.

**F8 (Info: no loss from lines to independent weights).**
- FlashProve's own lines-to-weights lemma (`MCAFor.cnt_close_comb_mul`, in its `Code/Derived.lean`, not ported) gives
  `bad/(|E| − 1)`.
- `comb_close_prob` gives `A/|E|` for every code with `2e < d` and `A ≥ e + 1`. That is what the count (and BCIKS20
  Thm 1.7) uses.

## P5. FlashProve: what was reused, and how

- **What it proves.** FlashProve's Lean library (`github.com/anthropics/FlashProve`, `lean/`, version 0.16.0, commit
  9e2bdd8f, Apache-2.0) has, among much else:
  - BCIKS20 Thm 4.1, correlated agreement on lines at the unique-decoding radius with at most `n` exceptional values,
    for Reed–Solomon codes over any finite field (`Code/Half.lean`, `caOn_rsCode`, proved in the nine files of
    `Code/Lines/`);
  - its mutual form for interleaved words (`mca_rsCode`);
  - Roth–Zémor up to a third of the distance, for every linear code (`Code/Third.lean`).
  - It was cloned read-only into the session scratchpad.
- **Ported**, into `formal/ZK60Formal/ThirdParty/FlashProve/`: those files and their small dependencies (`Prob/Cnt`,
  `Prob/Count` cut to its counting part, `Code/Agree`, `Code/Mutual`), 15 files.
- **Version gap.** FlashProve builds with Lean 4.29.1 and an older Mathlib; we use 4.34.1 / v4.34.1. Four one-line
  fixes were needed:
  - a deprecated name (`finset_sum_coeff`);
  - a `simpa` that no longer closes the goal up to unfolding (`degZ`);
  - a `convert` that leaves an `Iff.rfl` goal;
  - a `haveI` that the style linter rejects.
  - In addition, `Code/Third.lean` and `Code/Half.lean` lose the declarations that need unported files
    (`Code/Iface.lean`, `Code/RS.lean`).
- **Attribution.** Every ported file keeps its header and says what was changed. The repository's `NOTICE` has the
  attribution: FlashProve, and ArkLib as FlashProve's credits list it for eleven of the files. `formal/README.md`
  lists the files.

## P6. What remains for L3 (the PCS part)

- **Merkle binding** in the random-oracle model, with the `q`-dependent bound, and the extractor that reads `U` from
  the query log. That turns "U fixed" into a theorem.
- **The opening as the code runs it**: several groups, the `λ` batching (`batch_prob` composed), and `ok` defined
  through the encoder's inverse (the multilinear claim on the first `n` message symbols).
- **M**: the product-form linear test, and the `F_p` reading of `u` (F6).
- **Composition**:
  - the `3L + 1` regular and `L` mask openings of a run;
  - the reduction from "terminal values opened" to "they are the multilinear extensions at the point" (part 1's §3.2);
  - the union with the IOP terms of part 1.
- **Fiat–Shamir** with the challenge bias, as in part 1.
- **The instance**: the domain `7·G_N` as `ι ↪ F_p`, `K' = n + q_pad`, and the profile's `ColumnRegime` choosing δ/2
  only for the rate-1/2 regular openings.

# Part 3 (2026-11-04): Merkle binding and the extractor for `U`, in the random-oracle model

New files under `formal/ZK60Formal/`: `SoundRO.lean`, `SoundMerkle.lean`, `SoundExtract.lean`, `SoundOpeningRO.lean`.
- `lake -d formal build` succeeds with no warnings. No file uses `sorry`, `axiom`, `admit`, `native_decide` or a
  `maxHeartbeats` option.
- `#print axioms` was run on all 56 new theorems. Each depends on `propext`, `Classical.choice` and `Quot.sound`
  only, or on fewer.
- No new lake dependency. Nothing was copied from FlashProve (its `Rom/` and `Hash/` folders were not needed).

**Scope.** The model is `Statements.lean`'s: the hash is one uniformly random function `H : Q → D`; an adversary is
a deterministic oracle computation `OC Q D α` whose budget `OC.Bounded q` counts queries on every path; probabilities
are `prH`. The four keyed BLAKE3 functions of a tagged profile and the unkeyed one are one random function on the
disjoint union of their inputs, so one `H` loses nothing. The PCS challenges stay INTERACTIVE: `ρ` and `J` are exactly
uniform and independent of `H`, drawn after the root (`P₁` outputs the root before either is drawn; `P₂` sees `ρ`;
`P₃` sees `J`). Fiat–Shamir is not modelled.

This removes the "`U` is fixed" assumption of Part 2: the committed matrix is now READ OFF THE COMMITTER'S HASH LOG.

## Q1. What is proved

**Task 1, the random oracle** (`SoundRO.lean`). The one probabilistic fact is `prob_fresh_mem_le`. Suppose the event
names, for each oracle, at most one point `y` that it has not yet fixed (changing `H` at `y` changes neither the event
nor a set `T` of at most `m` digests). Then `H y ∈ T` has probability at most `m/|D|`. The proof swaps `H y` with a
fresh value, an involution of `(Q → D) × D`. Applied position by position to an adaptive run:
```lean
theorem freshHit_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T)
    (F : List (Q × D) → Finset D) (m : ℕ → ℕ) (hF : ∀ P, (F P).card ≤ m P.length) :
    prH (fun H => FreshHit F (A.runLog H).2)
      ≤ ((∑ t ∈ range T, m t : ℕ) : ℝ≥0∞) / Fintype.card D
theorem collision_prob_le {α : Type} (A : OC Q D α) (q : ℕ) (hA : A.Bounded q) :
    prH (fun H => ∃ a ∈ OC.queries H A, ∃ b ∈ OC.queries H A, a ≠ b ∧ H a = H b)
      ≤ ((q * (q - 1) / 2 : ℕ) : ℝ≥0∞) / Fintype.card D
theorem collision_out_prob_le (A : OC Q D (Q × Q)) (q : ℕ) (hA : A.Bounded q) :
    prH (fun H => (A.run H).1 ≠ (A.run H).2 ∧ H (A.run H).1 = H (A.run H).2)
      ≤ (((q + 2) * (q + 1) / 2 : ℕ) : ℝ≥0∞) / Fintype.card D
theorem preimage_query_prob_le {α : Type} (A : OC Q D α) (q : ℕ) (hA : A.Bounded q) (t₀ : D) :
    prH (fun H => ∃ y ∈ OC.queries H A, H y = t₀) ≤ (q : ℝ≥0∞) / Fintype.card D
theorem preimage_out_prob_le {α : Type} (A : OC Q D (Q × D × α)) :
    prH (fun H => H (A.run H).1 = (A.run H).2.1 ∧ (A.run H).1 ∉ OC.queries H A) ≤ 1 / Fintype.card D
```
- `FreshHit F L`: some entry asks a question no earlier entry asked, and its answer lies in `F` of the entries before
  it.
- `collBound q D` names the bound `q(q − 1)/2 / |D|`.
- The query-free preimage bound `1/|D|` needs no budget: the answer at a point never asked is still uniform.
- The log lemmas the other files use are here too: `runLog_bind`, `runLog_take_agree` (a prefix of the log depends
  only on the answers in it), `runLog_eq_of_agree`, and `replay` with `replay_runLog_append`.

**The model of the tree** (`SoundMerkle.lean`). `MerkleEnc Q D S Col` holds the three hash inputs, each with a left
inverse:
- `colQ c`: the column's little-endian bytes under the column key;
- `leafQ x s`: `x ‖ s` under the leaf key;
- `nodeQ l r`: `l ‖ r` under the node key.

The climb follows `verify_path_keyed`: at each level the running digest is the left child when the current low bit of
the position is 0, then the position is halved. `Opens H h root j o` is the tagged verifier's acceptance: the path has
exactly `h` entries and the climb from `H_leaf(H_col(col) ‖ salt)` reaches the root. **No separation between the three
kinds of input is assumed**, only that each one is injective.

**Task 2, Merkle binding.**
```lean
theorem opens_collision (H : Q → D) {h : ℕ} {root : D} {j : ℕ} {o₁ o₂ : MerkleOpening D S Col}
    (hc : o₁.col ≠ o₂.col) (h₁ : M.Opens H h root j o₁) (h₂ : M.Opens H h root j o₂) :
    ∃ a ∈ M.openQs H j o₁, ∃ b ∈ M.openQs H j o₂, a ≠ b ∧ H a = H b
theorem merkle_binding (h q : ℕ) (A : OC Q D (D × ℕ × MerkleOpening D S Col × MerkleOpening D S Col))
    (hA : A.Bounded q) :
    prH (fun H => (A.run H).2.2.1.col ≠ (A.run H).2.2.2.col
        ∧ M.Opens H h (A.run H).1 (A.run H).2.1 (A.run H).2.2.1
        ∧ M.Opens H h (A.run H).1 (A.run H).2.1 (A.run H).2.2.2)
      ≤ collBound (q + 2 * (h + 2)) D
```
- Both paths have the same length `h`. So the two climbs compare a node query with a node query at the same level,
  then the salted leaf with the salted leaf, then the column digest with the column digest. Each comparison either
  finds a collision or passes the equality down.
- `mixed_depth_opens` (see F9) shows that without the length check the statement is false for every encoding.

**Task 3, the straight-line extractor** (`SoundExtract.lean`). `extractCol L h j root` reads only the commit phase's
log `L`. Starting from the root, it repeats `h` times: take the first logged question whose answer is the current
digest, decode it as a node, and follow the child that the position's bit names (the climb's bit). At the leaf level
it decodes the logged question as `(x, salt)`, then decodes the logged question whose answer is `x` as a column.
Nothing is rewound or guessed.
```lean
theorem extract_of_opens [DecidableEq Q] (H : Q → D) (L : List (Q × D)) (hL : ∀ e ∈ L, e.2 = H e.1) (root : D)
    {h j : ℕ} {o : MerkleOpening D S Col} (ho : M.Opens H h root j o) :
    M.extractCol L h j root = some o.col ∨ ExtBad H L (M.targets L root) (M.openQs H j o)
theorem extract_sound (h : ℕ) {St : Type} (q₁ q₂ n : ℕ) (A₁ : OC Q D (D × St)) (hA₁ : A₁.Bounded q₁)
    (B : St → OC Q D (Fin n → ℕ × MerkleOpening D S Col)) (hB : ∀ st, (B st).Bounded q₂) :
    prH (fun H => ∃ k, M.Opens H h (A₁.runLog H).1.1 (((B (A₁.runLog H).1.2).run H) k).1
          (((B (A₁.runLog H).1.2).run H) k).2
        ∧ M.extractCol (A₁.runLog H).2 h (((B (A₁.runLog H).1.2).run H) k).1 (A₁.runLog H).1.1
            ≠ some (((B (A₁.runLog H).1.2).run H) k).2.col)
      ≤ collBound (q₁ + q₂ + n * (h + 2)) D + extGuess (q₁ + q₂ + n * (h + 2)) q₁ D
```
- `ExtBad`: a verifier's query collides with a logged question, or a verifier's query that was never logged has its
  answer in `targets L root`.
- `targets L root` is the root plus the digests that logged questions name as node children or as leaf contents:
  at most `3|L| + 1` of them (`targets_card`).
- `extGuess T q₁ D = T(3q₁ + 1)/|D|`. This is the unqueried path guess: the commit phase leaves a hole (a digest with
  no logged preimage) and a query asked for the first time AFTER the commit phase must land on one of those digests to
  fill it.
- The collision term covers every query of the run: the commit phase's, the later phase's and the verifier's.

**Task 4, one opening with `U` extracted** (`SoundOpeningRO.lean`). `ROAccepts` is the verifier of one claim group of
`verify_zk_tagged`. It checks the claim on the group vector's codeword, and at each sampled index it checks the Merkle
opening against the root and the opened column against both vectors. The prover runs in three phases (commit; answer
`ρ`; open `J`).
```lean
theorem opening_sound_extracted (M : MerkleEnc Q D S Col) (val : Col → κ → E) (c₀ : Col) {h : ℕ}
    {C : Submodule E (Fin (2 ^ h) → E)} {d e A : ℕ} (hd : MinDist C d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit C e A) (a : κ → E) (ok : (Fin (2 ^ h) → E) → Prop) (nQ : ℕ) {St₁ St₂ : Type}
    (q₁ q₂ q₃ : ℕ) (P₁ : OC Q D (D × St₁)) (hP₁ : P₁.Bounded q₁)
    (P₂ : St₁ → (κ → E) → OC Q D (St₂ × C × C)) (hP₂ : ∀ st ρ, (P₂ st ρ).Bounded q₂)
    (P₃ : St₂ → (Fin nQ → Fin (2 ^ h)) → OC Q D (Fin nQ → MerkleOpening D S Col))
    (hP₃ : ∀ st J, (P₃ st J).Bounded q₃) :
    (PMF.uniformOfFintype ((Q → D) × ((κ → E) × (Fin nQ → Fin (2 ^ h))))).toOuterMeasure
        {x | ROAccepts M val a ok P₁ P₂ P₃ x
          ∧ ¬ OpeningGood C e (extractU M val c₀ (P₁.runLog x.1).2 h (P₁.runLog x.1).1.1) a ok}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ
        + (collBound (q₁ + (q₂ + q₃) + nQ * (h + 2)) D + extGuess (q₁ + (q₂ + q₃) + nQ * (h + 2)) q₁ D)
```
- `extractU` is the extracted matrix: entry `(i, j)` is entry `i` of `extractCol` at `j`, with a default column `c₀`
  where extraction fails. It is a function of `P₁`'s log alone, so it is fixed before `ρ` and `J`. That is exactly
  what `opening_sound` needs.
- The proof splits the event in two. In one part every opening equals its extracted column; then it is
  `opening_sound`'s event for `extractU`, for each `H` (`prob_prod_le_of_forall_fst`). In the other part some opening
  differs from its extracted column; that is `extract_sound`'s event, for each `(ρ, J)` (`prob_prod_le_of_forall_snd`).
- `opening_sound_extracted_rs_half` is the rate-1/2 (δ/2) instance: `N/|E| + col + Merkle`.

## Q2. What the model assumes, and how it meets the code

1. **The three encodings are injective, with fixed-length fields.**
   - `colQ`: the column has exactly `rows` entries. `verify_zk_tagged` refuses another length, and `wire.rs` reads
     `rows` field elements. `Fp::to_bytes` is the canonical `u64`, because `Fp::new` reduces.
   - `leafQ` and `nodeQ` are both 32 + 32 bytes.
   - Under the tagged profiles the inputs also carry the key. Under the legacy rule `leafQ = nodeQ` as functions.
     The model allows that, because no separation is assumed.
2. **The path has exactly `h = log2 N` entries.** This is the assumption binding rests on (F9).
   - `verify_zk_tagged` checks it (`pcs.rs:1199–1204`).
   - The private block checks it for every commitment before the core verifiers run: `hash_domain.rs`
     `paths_are_the_tree_depth` / `mask_paths_are_the_tree_depth`, called at `protocol.rs:2000–2002`, `run.rs:1390` and
     `run_fork.rs:1273–1275`.
   - `wire.rs` reads the path count from the layout, never from the receipt.
3. **The position.** The column index must equal the sampled index, and `challenge_indices` masks it below `N` (a power
   of two). The climb uses exactly the low `h` bits, as the model does.
4. **`N` is a power of two, so there is no padding.** `MerkleTree::build_keyed` asserts it. The PCS has
   `N = 2^log_cols · inv_rate`; the mask commitment has `N = 2^MASK_LOG_DOM`. Nothing in the binding or extraction
   argument depends on how a non-power-of-two width would be padded, because no such width occurs.
5. **The salt** sits after the column digest in the leaf input (`salt_leaf_keyed(digest, salt)`). Binding is about the
   column, so the two openings may carry different salts.
6. **The order.** The root precedes `ρ`. The private block's verifier absorbs every root first (`protocol.rs:2003–2011`;
   `absorb_root` also absorbs `rows` and `log_cols`), and `zk_rhos` draws `λ` and `ρ` from that transcript later. The
   vectors precede `J` (`pcs-vec`, `pcs-prox`, then `challenge_indices`). The interactive model draws `ρ` and `J`
   uniformly at those points.
7. **What is not modelled.** Fiat–Shamir (the challenges as hash outputs), several claim groups and the `λ` batching,
   `M`'s product-form test, and the composition of the 129 commitments of a run that share one oracle.

## Q3. How the bounds compare with the count

The count (`results/zk60_w16r2_q280_20261103/recount_q280.out.txt`) is an interactive union bound. It has **no hash
term at all**. The Merkle terms proved here are new terms, and they belong to the `q`-dependent `εs q` of
`Statements.lean`. Per commitment, with `|D| = 2^256` (BLAKE3), `q₁ = q`, and `T = q + nQ(h + 2)`:

| Commitment | Verifier's queries `nQ(h + 2)` | `q = 2^40` | `q = 2^64` | `q = 2^80` |
|---|---|---|---|---|
| W16R2 regular (N 2^15, Q 280) | 4,760 | 2^-174.19 | 2^-126.19 | 2^-94.19 |
| M (N 2^12, MASK_Q 256) | 3,584 | 2^-174.19 | 2^-126.19 | 2^-94.19 |

- Each entry is `collBound T + T(3q + 1)/2^256`. The guess term dominates by about `2^2.4`. The verifier's own
  queries are negligible: at `q = 0` the collision term is `2^-232.6`.
- **Against the per-opening figures** (W16R2 −112.278, W16 −105.604, M −106.248), the Merkle term is invisible for
  any `q ≤ 2^64`.
- **Against the whole run.** Charged once per commitment (97 regular + 32 M openings), it adds at most
  `129 × 2^-126.19 = 2^-119.18` at `q = 2^64`. The counted −97.779 does not move.
- **Against the proposed target `εs q = q·2^-100 + 2^-100`.** The bound is quadratic, about `3.5·q²/2^256`, so it is
  at most `q·2^-100` for every `q ≤ 2^154.2`. Its absolute value reaches `2^-100` at `q ≈ 2^77.1`, where the target is
  `2^-23`.
- **Shape.** The guess term is `T(3q₁ + 1)/|D|`, not `q/|D|`, for two reasons. The commit phase can name up to
  `3q₁ + 1` digests, and a later query may aim at any of them. A per-position version would charge only the
  `n(h + 2)` digests on the extracted paths of the sampled positions, and gives `T·n(h + 2)/|D|`. It is not proved;
  the proved form is enough for every `q` that matters.

## Q4. Findings

**F9 (Low, latent; a documented rationale is wrong). The path-length check is the ONLY protection of binding against
a tree of mixed depth. The D19 keys do not give it.** `mixed_depth_opens` proves this for every oracle and every
encoding, including perfectly separated leaf and node inputs.
- **The construction.** Put column 1's salted leaf `ℓ₁` at depth 1 with sibling `R = H_node(ℓ₂ ‖ X)`, and column 2's
  salted leaf `ℓ₂` at depth 2 under `R`. The root is `H_node(ℓ₁ ‖ R)`.
- **The two openings.** Position 2 opens to column 1 with the path `[R]`, and to column 2 with the path `[X, ℓ₁]`.
  Both climbs reach the root (bit 0 of 2 is 0, bit 1 is 1). No collision is used.
- **What the docs say.**
  - The D19 disposition (§1) says the depth gap "disappears with a one-line check … **or** when leaves and nodes are
    hashed under different keys". The second half is wrong. The keys stop an inner node from being presented as a
    salted leaf, which was the attack the disposition analysed. They do not stop genuine leaves sitting at two depths.
  - The comments repeat this: `pcs.rs` `verify_zk_tagged` ("the length check is the second line") and `merkle.rs`
    `verify_path_keyed` ("needs a key it does not have").
- **Why nothing breaks today.** Every tagged verifier path in the private block is length-checked: `verify_zk_tagged`
  itself; `M` through `mask_paths_are_the_tree_depth` (`protocol.rs:2002`, before `mask_verify_tagged` at `:2023`);
  and the `wire.rs` layout counts.
- **The gap.** `zk::mask_verify_tagged` has no length check of its own, so on its own it is not binding.
- **The legacy verifiers.** `pcs::verify_zk` and the plain `verify` have no length check and no leaf/node separation.
  They are binding only where the wire format fixes the path count.
- **Suggested:**
  - move the check into `mask_verify_tagged`, as `verify_zk_tagged` has it;
  - correct the D19 sentence and the two comments: the length check is the first line, not the second;
  - keep the T-4 tests.

**F10 (Info: binding and extraction need no domain separation).** At a fixed depth, statement 1's Merkle steps use
only that each of the three encodings is injective. That includes the legacy rule's identical leaf and node inputs,
and its 8-row columns whose column input is also 64 bytes.
- This is unlike hiding: `HidingMerkle.lean` needs the column and salted-leaf inputs separated, and excludes the
  legacy 8-row case.
- The T-1 keys are therefore not load-bearing for soundness of the Merkle layer. They remain so for hiding, and
  possibly for Fiat–Shamir programmability; that is not examined here.

**F11 (Info: the extractor is straight-line and reads only the commit phase).** No rewinding is needed.
- This is the form `KnowledgeSound` asks for: an extractor reading the prover's hash-query log.
- Under Fiat–Shamir the commit phase is not a separate computation. The natural extractor reads the log up to the
  transcript query that absorbs the root. Queries asked after that point and landing on a target are exactly this
  file's fresh hits.
- That composition is part of the Fiat–Shamir step, and is not done here.

## Q5. What remains (the Merkle part)

- **Fiat–Shamir.** `ρ` and `J` become transcript outputs, the extractor's log ends at the root's absorption, and the
  challenge bias of part 1's §3.7 enters.
- **The 129 commitments of a run sharing one oracle.** There is one collision term for the whole run, and a guess term
  per commitment, or one guess term over the union of their targets.
- **The extractor for `KnowledgeSound`.** Decode the extracted `U` to its unique codeword rows (`Close.unique`), read
  the witness off them, and extract the input and output commitments' openings (`opensIn`, `opensOut`) in the same
  way.
- **The instance.**
  - A `MerkleEnc` for keyed BLAKE3 (`Q` = key × bounded-length bytes, finite).
  - The column decoder (canonical `Fp` bytes, `rows` entries).
  - `val` reading a column's `F_p` entries into `F_p²` (the field split of Part 2).

## Fixed, 2026-11-04: F9, the M verifier checks its own path length

`zk::mask_verify_tagged` now refuses a Merkle path whose length is not the tree's depth (`MASK_LOG_DOM` = 12) before it
verifies the path. It no longer relies on every caller running `mask_paths_are_the_tree_depth` (T-4) first.
- The callers are the private block, the four token-I/O stages and the capture verifier.
- Full lib suite: 899 passed / 3 failed / 93 ignored, the failures exactly the known three
  (`results/zk60_h124_witness_20261104/f9_full.log`). The new refusal never fired.
- Still owed for F9: correct the D19 disposition's sentence ("or when leaves and nodes are hashed under different
  keys") and the comments in `pcs.rs` (`verify_zk_tagged`) and `merkle.rs` (`verify_path_keyed`).

# Part 4 (2026-11-04): Fiat–Shamir in the random-oracle model

New files under `formal/ZK60Formal/`: `FSRbr.lean`, `FSChallenge.lean`, `FSSumcheck.lean`, `FSChain.lean`,
`FSChainRbr.lean`.
- `lake -d formal build` succeeds with no warnings (3393 jobs). No file uses `sorry`, `axiom`, `admit`,
  `native_decide` or a `maxHeartbeats` option.
- `#print axioms` was run on all 65 theorems of the five files. Each depends on `propext`, `Classical.choice` and
  `Quot.sound` only, or on fewer.
- No new lake dependency, and nothing was copied from FlashProve.
  - Its `Iop/Rbr.lean` (`Doomed`, a count of escaping challenges per round) states the same round-by-round notion.
  - Its `Rom/` folder compiles Fiat–Shamir in its own oracle model (`OComp`, typed oracle families). That model does
    not match `Statements.lean`'s `OC`, so it was not ported.

**Scope.**
- The model is `Statements.lean`'s:
  - one uniformly random `H : Q → D`;
  - the prover is a deterministic oracle computation `OC Q D _` making at most `q` hash queries on every path;
  - probabilities are `prH`.
- The prover CHOOSES the statement after seeing hash values (adaptive soundness).
- The challenges are now hash outputs, not uniform draws.

## R1. What is proved

**Round-by-round soundness** (`FSRbr.lean`; Canetti et al. 2019, Def. 5.3). A state function `St x τ` on partial
transcripts (false means doomed), with at most `e` escaping challenges per round:
```lean
structure RbrSound (n : ℕ) (L : X → Prop) (accept : X → List (M × Ch) → Mf → Prop)
    (St : X → List (M × Ch) → Prop) (e : ℕ) : Prop where
  start : ∀ x, ¬ L x → ¬ St x []
  round : ∀ x τ m, τ.length < n → ¬ St x τ → EscapesWithin (fun c => St x (τ ++ [(m, c)])) e
  final : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf
```
`EscapesWithin S e` means the `c` with `S c` lie in a set of at most `e` values. The per-round error is `e/|Ch|`
(`RbrSound.round_prob`).

**Fiat–Shamir with a prefix hash** (`FSRbr.lean`).
- The challenge of round `i` is `chal (H (enc x τ_i m_i))`.
- `enc` (`FSEnc`, with its left inverse) is an injective encoding of the statement, the transcript so far (messages
  AND challenges) and the round's message.
- `fsAccepts` recomputes the challenges and runs `accept`.
```lean
theorem fs_sound_of_rbr [DecidableEq Ch] {n e : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop}
    {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e) (E : FSEnc X M Ch Q) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ fsAccepts n accept E chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + n) * (e * K) : ℕ) : ℝ≥0∞) / Fintype.card D
theorem fs_sound_of_rbr_bias ... :
    prH (...) ≤ (((q + n) * e : ℕ) : ℝ≥0∞) / Fintype.card Ch * biasFactor K Ch D
```
- `biasFactor K Ch D = K·|Ch|/|D|` is the derivation's bias factor. `fs_sound_uniform` (`chal = id`) gives
  `(q + n)·e/|Ch|`.
- The proof:
  - the bad set of a query is decoded from the query itself (`FreshHitQ`; `freshHitQ_prob_le` is `SoundRO.lean`'s
    fresh-hit lemma with the set named by the query);
  - the round where a false statement escapes doom (`fs_flip`) is a verifier's query whose first-time answer lands
    in its own escape set.
- The `n` counts the verifier's own `n` queries.

**The challenges as the code derives them** (`FSChallenge.lean`).
- A digest is two 128-bit halves: `Fin N × Fin N`, `N = 2^128`.
- `fp2Chal` reduces each half mod `p` (`Fp::from_u128`).
- `fp2Field` reads the pair through any bijection `ι : ZMod p × ZMod p ≃ F`; for `Fp2` that is `c0 + U·c1`.
```lean
theorem card_fp2Field_fiber_le {F : Type} [DecidableEq F] (N p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F) (c : F) :
    (univ.filter (fun v : Fin N × Fin N => fp2Field p N ι v = c)).card ≤ (N / p + 1) ^ 2
theorem biasFactor_fp2_le {F : Type} [Fintype F] (N p : ℕ) [NeZero N] (hF : Fintype.card F = p ^ 2) :
    biasFactor ((N / p + 1) ^ 2) F (Fin N × Fin N) ≤ (1 + (p : ℝ≥0∞) / N) ^ 2
theorem bias_le_two_pow_64 (p : ℕ) (hp : p ≤ 2 ^ 64) :
    (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 ≤ (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2
theorem biasFactor_idx_eq_one {h : ℕ} (hh : h ≤ 64) :
    biasFactor (2 ^ 64 / 2 ^ h) (Fin (2 ^ h)) (Fin (2 ^ 64)) = 1
```
- Part 1 §3.7's factor `(1 + 2^-64)^(2k)` is now a theorem, in the form the Fiat–Shamir bound uses. It is a
  multiplicative factor `(1 + p/2^128)²` on the per-query error, paid once per hash query and not once per
  challenge.
- `prob_fp2Field_mem_le`: a set `S` of `Fp2` values is hit with probability `≤ |S|/|F| · (1 + p/N)²`.
- `challenge_indices` (a `u64` masked by `2^h − 1`; `idxChal`, `idxChal_eq`) has bias factor exactly `1`.

**The sumcheck** (`FSSumcheck.lean`).
- `scAccept` is the verifier on a transcript list. `scAccept_proverTr` shows it is `SoundSumcheck.lean`'s `Accepts`
  on a strategy's transcript.
- The state function `scState` is "every check so far passed and the current claim is TRUE". A round's step is
  `sumcheck_one_round`.
```lean
theorem sumcheck_rbr {X : Type} {n : ℕ} (hd : d < ringChar F) (stmt : X → ((Fin n → F) → F) × F) :
    RbrSound n (fun x => ¬ IndDegLE d (stmt x).1 ∨ (stmt x).2 = cubeSum (stmt x).1)
      (fun x (τ : List ((Fin (d + 1) → F) × F)) (_ : Unit) => scAccept τ n (stmt x).1 (stmt x).2)
      (fun x (τ : List ((Fin (d + 1) → F) × F)) => ¬ IndDegLE d (stmt x).1 ∨ scState τ n (stmt x).1 (stmt x).2)
      d
theorem fs_sumcheck_sound_goldilocks {n p : ℕ} [NeZero p] (hp : p ≤ 2 ^ 64) (hd : d < ringChar F)
    (ι : ZMod p × ZMod p ≃ F) (stmt : X → ((Fin n → F) → F) × F) (E : FSEnc X (Fin (d + 1) → F) F Q) (q : ℕ)
    (A : OC Q (Fin (2 ^ 128) × Fin (2 ^ 128)) (X × List (Fin (d + 1) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => IndDegLE d (stmt (A.run H).1).1 ∧ (stmt (A.run H).1).2 ≠ cubeSum (stmt (A.run H).1).1
        ∧ scAccept (fsTr E (fp2Field p (2 ^ 128) ι) H (A.run H).1 [] (A.run H).2.1) n (stmt (A.run H).1).1
            (stmt (A.run H).1).2)
      ≤ (((q + n) * d : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2
```
The same file also proves:
- `fs_sumcheck_sound`: any derivation, `(q + n)·d·K/|D|`;
- `fs_sumcheck_sound_uniform`: `(q + n)·d/|F|`;
- `fs_sumcheck_sound_code`: `(q + n)·d/|F| · (1 + p/2^128)²`.

**The code's transcript is a hash chain** (`FSChain.lean`).
- `zkp_core::transcript` does not hash the prefix. It keeps a 32-byte state:
  - `new` sets it to `H("hashline-v1/" ‖ domain)`;
  - each absorb sets it to `H(state ‖ le64|label| ‖ label ‖ le64|data| ‖ data)`;
  - each squeeze sets it to `H(state ‖ "squeeze" ‖ le64 counter)`, whose bytes are the challenge.
- `ChainEnc` models exactly this: a start query, and an injective `link` of a state digest with one item, with its
  left inverse. The start query decodes as no link.
- `traceBack` reads the log before a query and recovers the chain behind the digest the query names, like
  `SoundExtract.lean`'s extractor. `traceBack_chain`: it returns the true chain when the chain's queries are logged
  and no two logged questions collide.
- `chain_ordered`: every query of a chain is logged before the next one's first occurrence, unless a GUESS occurs. A
  guess is a first-time answer that lands on a digest an earlier query (or the query itself) already named
  (`chainTargets`, at most `t + 1` digests at position `t`).
```lean
theorem chain_sound (C : ChainEnc It Q D) (St : List (It × D) → Prop) (s k : ℕ)
    (hround : ∀ τ it, s ≤ τ.length → ¬ St τ → EscapesWithin (fun d : D => St (τ ++ [(it, d)])) k)
    {α : Type} (q ℓ : ℕ) (A : OC Q D (List It × α)) (hA : A.Bounded q) :
    prH (fun H => ¬ St (C.chainFrom H [] (((A.run H).1.take ℓ).take s))
        ∧ St (C.chainFrom H [] ((A.run H).1.take ℓ)))
      ≤ (((q + ℓ + 1) * k : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + ℓ + 1) D
        + collBound (q + ℓ + 1 + 1) D
```
The bound is the prefix-hash term plus a collision term and a guess term; the last two together are about `T²/|D|`,
`T = q + ℓ + 1`.

**A protocol on the chain** (`FSChainRbr.lean`).
- The items are the ones the code's verifiers hash: the statement, then per round the message and one squeeze with
  its counter (`pItems`). `sumcheck::verify` absorbs `"sc-round"`, then calls `challenge_fp2`.
- `rDecode` reads a chain back as a protocol transcript. `rDecode_rounds`: on the verifier's chain it returns the `n`
  messages.
- `liftSt` is the protocol's state on chains. `liftSt_round`: a message item never escapes, and a squeeze item is the
  protocol round, with `e·K` escaping digests.
```lean
theorem fs_chain_sound_of_rbr ... (hR : RbrSound n L accept St e) (C : ChainEnc (PItem X M) Q D) (chal : D → Ch)
    (K : ℕ) (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1 ∧ chainAccepts n accept C chal H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ (((q + (2 * n + 1) + 1) * (e * K) : ℕ) : ℝ≥0∞) / Fintype.card D + collBound (q + (2 * n + 1) + 1) D
        + collBound (q + (2 * n + 1) + 1 + 1) D
```
`fs_sumcheck_chain_sound_code` is the sumcheck as the code hashes it, with the code's `challenge_fp2`:
`T·d/|F| · (1 + p/2^128)² + collBound T + collBound (T + 1)` over `|D| = 2^256`, `T = q + 2n + 2`.

## R2. The bounds compared

`|F| = p²` and `log2 |F| ≈ 128`. With `d = 5` the per-round error is `d/|F| = 2^-125.678`. The bias factor
`(1 + p/2^128)²` is `1 + 2^-63`, invisible at this precision.

| One sumcheck slot, `d = 5`, `n ≈ 24` rounds | `q = 2^40` | `q = 2^64` | `q = 2^80` |
|---|---|---|---|
| Interactive, `sumcheck_sound`: `n·d/|F|` (no `q`) | 2^-121.1 | 2^-121.1 | 2^-121.1 |
| Fiat–Shamir, prefix hash: `(q + n)·d/|F|·bias` | 2^-85.68 | 2^-61.68 | 2^-45.68 |
| Chain: the added collision and guess terms, `≈ T²/2^256` | 2^-176 | 2^-128 | 2^-96 |
| Proposed target `εs q = q·2^-100 + 2^-100` | 2^-60 | 2^-36 | 2^-20 |

- **Every Fiat–Shamir bound is linear in `q`, the target's own shape.** Per hash query the sumcheck costs
  `2^-125.68`, 25.7 bits under the target's `2^-100` per query.
- The chain's extra terms are quadratic in `T`. They stay below `2^-100` while `T ≤ 2^78`; there the target is
  `2^-22`.
- **The count is an interactive union bound over all rounds.**
  - Round by round, the Fiat–Shamir error is `q · max_round(error)`, not `q · Σ_round(error)`: an attack must win
    some single round, and each query attacks one round.
  - Indicatively (these RBR instances are not proved yet), the largest per-round error in the count is LogUp's `α`:
    `(N_lk + 2·T_d − 1)/p² = 2^-102.93`, or `2^-102.92` with `β, γ, α` read as one draw (F15).
  - That would give `εs(q) ≈ q·2^-102.9` for the whole run, plus `≈ T²/2^256`.
  - Reading the count's whole-run `2^-97.78` as a per-attempt rate (ACCOUNTING A2) is the more conservative figure.

## R3. What the model assumes, and how it meets the code

1. **The statement is bound before any challenge** (verified in the code).
   - The block header `protocol::transcript` (`protocol.rs:113-127`) absorbs these, after the profile's domain:
     - `expected-IO`: the context digest, both scales, the input and output endpoint roots;
     - `public-statement`: the weights and tables digest;
     - `parameters`, `calibration` and `schedule`.
   - Then come the `A` root (with rows and log-cols) and the `M` root, before `β, γ, α` (`protocol.rs:2003-2007`).
   - The run headers (`run.rs:844-861`, `run_fork.rs:749-763`) absorb the same, plus `run-shape`.
   - Stage and fork indices are absorbed before each stage (audit, not re-read).
   - The exception is F12.
2. **Each round's message is absorbed before its challenge.**
   - `sumcheck::verify` absorbs `"sc-round"` then calls `challenge_fp2` (`sumcheck.rs:159-160`).
   - `pcs::verify_zk_tagged` absorbs every `"pcs-vec"` and `"pcs-prox"` before `challenge_indices`
     (`pcs.rs:1220-1227`).
   - The sumcheck does not absorb the claimed sum itself. The sum is fixed by `s_0(0) + s_0(1)` and by the earlier
     `"pb-scalar"` absorb.
3. **The link encoding is injective.**
   - An absorb input carries both lengths. A squeeze input has exactly 47 bytes, and an absorb input at least 48.
   - That is all the chain theorem needs. No round index and no label is needed for soundness, because the chain binds
     the prefix through the previous state.
   - Under the legacy rule the transcript, column, leaf and node hashes are one unkeyed BLAKE3, and some absorb
     inputs are 64 bytes, like a Merkle node (the `"log-cols"` absorb). The single-oracle model already covers this:
     every prover query counts in `q`, and a Merkle query equal to a link query IS that link query.
4. **The start query decodes as no link.**
   - To decode as an absorb, `"hashline-v1/" ‖ domain` would have to carry a little-endian length in bytes 32–39,
     and ASCII text there gives at least `2^56`. To decode as a squeeze it would have to be 47 bytes with `"squeeze"`
     in bytes 32–38.
   - The registered domain strings meet this. It is an assumption of `ChainEnc`, not a checked instance.
5. **Challenges.**
   - `challenge_fp2` reads the low 16 bytes as `c0` and the high 16 as `c1`, each mod `p`.
   - The squeeze's 32 bytes become the state, so the chain links through the challenge digest itself.
   - `challenge_indices` masks 8-byte chunks, four per squeeze. It is exact on a 64-bit `usize`.
6. **The statement as one item, the counter as `j`.**
   - The code absorbs the header as six items.
   - Its squeeze counter is the transcript's total squeeze count, so it differs from `j` by an offset.
   - Both change only `T` and the decoder's offset, but neither is formalized.
7. **What is not modelled.**
   - Vector challenges drawn by several squeezes (F15).
   - Several protocols composed on one chain (slots, blocks, the PCS).
   - The extractor's log cut at the root's absorption (task 4).
   - The refusals of zero draws (they only add rejection).

## R4. Findings

**F12 (Low: a statement field of D12a/D55 runs is not bound).** `RunStatement` has its own `context` field
(`run.rs:514`).
- The constructor only refuses zero (`run.rs:635-637`). It never compares `context` with `expected.spec.context`,
  which IS absorbed through the `expected-IO` bytes (`private_block.rs:1122-1131`).
- No header absorbs it (`run.rs:844-861`, `run_fork.rs:749-763`), and neither `parameter_line` nor `schedule_digest`
  contains it.
- Its only uses:
  - `boundary_spec` (`run.rs:730`). `BoundarySpec::digest()` is never absorbed (`run.rs:655-656` says so). It is used
    prover-side only: the boundary seed domain (`boundary.rs:396`) and `PreparedBoundary`'s spec check
    (`boundary.rs:276`).
  - The test-only capture (`run.rs:908`).
- **Effect.** A D12a or D55 run receipt verifies under ANY nonzero run context, so the receipt does not attest it.
  - The verifier's decision does not depend on it. No equation is at risk, and this is not a Fiat–Shamir soundness
    break.
  - It is a statement word that a reader may take as attested, and it is not.
  - The token-I/O run is not affected: its context enters `expected_bytes` (`token_io/run.rs:375-383`, per the audit,
    not re-read).
- **Suggested:** refuse `context != expected.spec.context` in `RunStatement::new_with_calibration`, or drop the field
  and derive it from `expected`. A refusal changes no proof byte.

**F13 (Info: nothing a challenge depends on is absorbed after it).** A read-only audit covered the private-block
verifier: the block, the D12a run, the D55 fork–join and the token-I/O stages. Every root and message is absorbed
before the challenges that depend on it:
- the header first; `A` and `M` before `β, γ, α`; `H` after them, because it is built from them;
- per slot: its own challenges, `"pb-slot"`, `c`, `"pb-scalar"`, the rounds, `"pb-term"`;
- `M`'s opening: `θ`, `"mask-q"`, the `r`s, `"mask-prox"`, the indices;
- the PCS openings: `λ`, `ρ`, `"pcs-vec"`, `"pcs-prox"`, the indices.

The `clone_state` transcripts do one of two things, neither of which reaches the proof:
- they refuse degenerate draws;
- they squeeze position tags that are compared and never adopted.

I checked the header, the commitment order, the sumcheck loop and the PCS order myself (cited in §R3). The slot
`define` arms were read only through their challenge draws.

**F14 (Info: under Fiat–Shamir the error is per query, the maximum over rounds).** See §R2.
- The count's interactive union bound is not the Fiat–Shamir figure.
- Round-by-round soundness of the whole IOP, with the per-round errors the count already itemizes, gives `q·max`
  instead. The chain adds `≈ T²/2^256`.
- When the IOP's RBR instances are proved, `εs q` can be stated from them directly.

**F15 (Info: vector challenges are drawn by several squeezes).**
- **Where.** `challenge_fp2_vec` (`λ`, `ρ`, the `M` weights, the batching vectors) and `challenge_indices` beyond four
  indices squeeze several times with no absorb between.
- **What that means.** The whole vector is a deterministic function of the state before the first squeeze. To a
  prover it is ONE wide challenge, which is what the interactive bounds assume (`ρ` jointly uniform, `J` jointly
  uniform).
- **The gap in the proofs.** The proved theorems take one challenge per squeeze. A squeeze-by-squeeze state function
  cannot carry a joint bound such as `A/|E|` for `ρ`; it would pay roughly the line bound once per coordinate.
- **What closes it.** A "wide digest" lemma: once the first query of a squeeze run is fresh, the run's digests are
  jointly uniform unless a guess occurs (the chain's guess term again). This is a gap in the proofs, not in the code.
- LogUp's `β, γ, α` are the same case (`protocol.rs:2005-2007`, no absorb between them). Treated as three rounds
  instead, the fold costs 3 escapes per table tuple instead of 2: `(N + 5M − 1)/p² = 2^-102.917` against
  `2^-102.922`.

## R5. What remains

- **The wide-digest lemma** (F15). Then the RBR instances of LogUp (`β, γ, α` as one round, `logup_block_bound`) and
  of the opening (`ρ`: the field term; `J`: the column term).
- **The opening under Fiat–Shamir with the extractor.**
  - Its state function depends on the matrix extracted from the log, cut at the query that absorbs the root
    (`absorb_root(A)`, `protocol.rs:2003`).
  - That is round-by-round KNOWLEDGE soundness: the extraction error of `SoundExtract.lean` composed with
    `chain_sound`.
- **Composition on one chain.** The 23 slots, `A`/`H`/`M`, and the blocks and forks of a run, as one RBR protocol.
  The per-round errors are the count's items, and the bound is `q·max + T²/2^256`.
- **The code-level instance.** A `ChainEnc` for keyed BLAKE3 byte strings, the header's six absorbs and the counter
  offset, including `ldec_start` for the registered domains.
- **`KnowledgeSound`** of `Statements.lean`: the extractor of the witness and of the commitment openings, composed
  with the above.
