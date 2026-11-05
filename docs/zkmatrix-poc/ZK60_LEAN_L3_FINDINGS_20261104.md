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
