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

# Part 4 (2026-11-04): the openings as the code runs them, and `M`'s product-form test

New files under `formal/ZK60Formal/`: `SoundGroups.lean` and `SoundMProduct.lean`.
- `lake -d formal build` succeeds with no warnings (3390 jobs). No file uses `sorry`, `axiom`, `admit`,
  `native_decide` or a `maxHeartbeats` option.
- `#print axioms` was run on all 38 new theorems. Each depends on `propext`, `Classical.choice` and `Quot.sound` only.
- No new lake dependency. Nothing was copied from FlashProve. `SoundMProduct.lean` reuses three lemmas of
  `HidingMOpening.lean` (`sum_eval_nodes`, `rootsOfUnity_powSum`, `natDegree_interpolate_lt`).

**Scope.** As in Parts 2 and 3: interactive, the challenges exactly uniform and independent, the prover arbitrary,
the committed rows fixed. Part 3's extracted matrix can be substituted; `groups_sound_extracted` does so.

**The main result is a finding, F12 (§R4): `M`'s check certifies its first functional only up to a constant that the
prover chooses when it commits `M`.** Read from the code, this looks exploitable in the token-I/O stages. It has NOT
been run against the Rust verifier.

## R1. What is proved

**Task 1, several claim groups with the `λ` batching** (`SoundGroups.lean`). The model follows `group_zclaims`,
`zk_rhos` and `verify_zk_tagged` (`pcs.rs:926-1279`):
- a claim `c` is row weights `rw_c`, a claimed value `val_c` and a group `grp c`; the group's column weights `cw_g` are
  shared by its claims;
- the encoder is any injective linear map `enc : (μ → E) → (ι → E)` from clear vectors (message, then pads) to words;
  the code is its range;
- a claim is a linear functional of the committed MESSAGE: on message rows `X` its value is
  `claimValue = Σ_i rw_c(i)·⟨X_i, cw_{grp c}⟩`;
- the verifier draws one INDEPENDENT uniform `λ_c` per claim (`challenge_fp2_vec(members.len())` per group, not
  powers) and the proximity weights `ρ`, all before any vector; group `g`'s row weights are `Σ_{c ∈ g} λ_c·rw_c`;
- the prover answers, as any functions of `(λ, ρ)`, one clear vector per group and the clear proximity vector; the
  verifier checks every group's claim, re-encodes, and checks every group and the proximity vector at `Q` uniform
  columns (`GroupsAccept`).

`ok` is now defined through the decoder:
- `decodeWord enc = Function.invFun enc`, the inverse of the encoder on the code (`decodeWord_enc`, `enc_decodeWord`);
- `closeTable` is the table of codewords a close matrix agrees with; `decodeRows` decodes it row by row;
- `GroupsGood`: `U` is close, and every claim holds of `decodeRows enc e U`;
- `groupsGood_iff`: that is the same as "some message rows `X`, encoded, agree with `U` outside `e` columns and
  satisfy every claim" (unique decoding, `Close.unique`). So the decoded data is the extracted data.

```lean
theorem groups_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype κ]
    [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
    (enc : (μ → E) →ₗ[E] (ι → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A)
    (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G) (val : Cl → E)
    (v : G → (Cl → E) → (κ → E) → μ → E) (w : (Cl → E) → (κ → E) → μ → E) (Q : ℕ) :
    (PMF.uniformOfFintype (((Cl → E) × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | GroupsAccept enc U rw cw grp val v w x.1.1 x.1.2 x.2 ∧ ¬ GroupsGood enc e U rw cw grp val}
      ≤ (A : ℝ≥0∞) / Fintype.card E
        + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q
```
- **The bound is the one-group bound of `opening_sound`.** `U` decides the case before any challenge.
  - Far: the proximity vector, as before.
  - Close, with a false claim `c₀`: either the `λ`-combination of the errors of `c₀`'s group vanishes (`≤ 1/|E|`,
    `batch_prob`; the algebra is `batch_identity`), or the group's combined claim is false of the decoded rows, and
    then the group vector differs from `Σ_i a_{g,i}·U_i` in `≥ d − e ≥ e + 1` columns (`le_card_ne_add`).
  - `1/|E| ≤ A/|E|`, so the batching term is absorbed. The requested additive form, the batching term plus the
    one-group bound, is `groups_sound_add` (`≤ 1/|E| + (A/|E| + col)`).
- Several groups cost nothing more: the close case uses only the group of one false claim.
- Instances: `groups_sound_rs_half` (`N/|E| + col`) and `groups_sound_rs_third` (`(e + 1)/|E| + col`), with the
  hypothesis `LinearMap.range enc = rsCode dom K`.
- **With the Merkle layer** (`groups_sound_extracted`): a three-phase prover against the random oracle (`P₁` commits;
  `P₂` sees `(λ, ρ)`; `P₃` opens), and `GroupsGood` of the matrix extracted from `P₁`'s log. The bound is
  `A/|E| + ((N − (e + 1))/N)^nQ + collBound T D + extGuess T q₁ D`, `T = q₁ + (q₂ + q₃) + nQ(h + 2)`. The proof is
  Part 3's split, with `groups_sound` in place of `opening_sound`.
- **Powers of one challenge** would cost `(k − 1)/|E|` for `k` claims. The PCS does not use powers; `M` does (task 2).

**Task 2, `M`'s product-form test** (`SoundMProduct.lean`). The model is `mask_verify_tagged` (`zk.rs:657-698`) over
one field `E`:
- one `θ`; the combined weights `W_s(θ) = Σ_i θ^(i + o)·w_{i,s}` and value `V(θ) = Σ_i θ^(i + o)·value_i` (`mW`,
  `mV`). The code has `o = 0` (`combined_weights`: `th` starts at `Fp2::ONE`);
- the prover sends `q'` (degree `< 2m`, any function of `θ`); the sum check is `m·(q'_0 + q'_m) = V(θ)`; at each of
  `Q` uniform columns the verifier checks `b_j + Σ_s a_{s,j}·p_{W_s}(η_j) = q'(η_j)` (`MProdAccept`), where `p_W`
  interpolates `W` on `G_m = {ω^j}` (`mInterp`);
- the rows agree outside `e` columns with decoded polynomials `Ah_s`, `Bh` of degree `≤ K` (the proximity part);
- the decoded message of a row is its values on `G_m`; the true values are `tru_i = Σ_s Σ_j w_{i,s,j}·Ah_s(ω^j)`
  (`mTrue`); the offset is `off = Σ_{x ∈ G_m} Bh(x) = m·(Bh_0 + Bh_m)` (`mOff`, `mOff_eq`);
- the residual is `Σ_i (value_i − tru_i)·X^(i + o) − off` (`mResidual`).

What the checks say:
- `sum_mPts_eval`: `Σ_{x ∈ G_m} p(x) = m·(p_0 + p_m)` for degree `< 2m`. So the sum check reads the sum over `G_m`.
- `mResidual_root`: if `q'` IS the product polynomial `Bh + Σ_s Ah_s·p_{W_s}`, the sum check says exactly that `θ` is a
  root of the residual.
- `mprod_columns_prob`: otherwise the column checks pass only off the agreement set or at a root of `P − q'`, that is
  on at most `e + dd` columns (`dd ≥ K + m − 1` and `dd ≥ 2m − 1`): probability `≤ ((e + dd)/N)^Q`.

```lean
theorem mproduct_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m) (η : ι → E) (hη : Function.Injective η)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (a : σ → ι → E) (b : ι → E)
    (Ah : σ → E[X]) (Bh : E[X]) (hAh : ∀ s, (Ah s).natDegree ≤ K) (hB : Bh.natDegree ≤ K)
    (S : Finset ι) (hS : Fintype.card ι ≤ S.card + e)
    (haS : ∀ j ∈ S, ∀ s, a s j = (Ah s).eval (η j)) (hbS : ∀ j ∈ S, b j = Bh.eval (η j))
    (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (hres : mResidual o val (mTrue ω wt Ah) (mOff m ω Bh) ≠ 0)
    (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) :
    (PMF.uniformOfFintype (E × (Fin Q → ι))).toOuterMeasure
        {x | MProdAccept η ω o wt val a b q x.1 x.2}
      ≤ ((k - 1 + o : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q
```
- `mproduct_sound_code` (`o = 0`, the code): if some `value_i ≠ tru_i + [i = 0]·off`, the probability is
  `≤ (k − 1)/|E| + ((e + dd)/N)^Q`. **This is the most the code's check gives**: it says nothing about a functional 0
  that is too large by exactly `off`.
- `mproduct_offset_accepts`, the attack: for any `Ah_s` of degree `< m` and any `Bh` of degree `< 2m`, with the rows
  their exact evaluations, `value_0 = tru_0 + off` and the other values true, the prover that sends the product
  polynomial passes the product test for EVERY `θ` and every column sample. `mproduct_offset_false`: functional 0 is
  then false whenever `off ≠ 0`.
- `mproduct_sound_shift` (`o = 1`, the fix): if ANY functional is false, whatever `b` is, the probability is
  `≤ k/|E| + ((e + dd)/N)^Q`.

**`M`'s whole opening** (`mopening_sound`).
- The committed rows are `Ub` (the code's `2·masks + 2` base rows) and the proximity mask `u`.
- The product test reads fixed combinations `a_s = Σ_κ La_{s,κ}·Ub_κ` and `b = Σ_κ Lb_κ·Ub_κ` (the code:
  `a_{s,re} + i·a_{s,im}` and `b_re + i·b_im`).
- At every sampled column the verifier also checks `u + Σ_κ r_κ·Ub_κ = prox` (`MAccept`).
- `MGood`: `(u, Ub)` is close to polynomials of degree `≤ K`, and the decoded data's residual vanishes. Those
  polynomials are unique (`mDecoded_unique`), so this is a statement about THE decoded data.
```lean
theorem mopening_sound [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι] [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k m Q e K dd : ℕ} (hm : 0 < m) {ω : E} (hω : IsPrimitiveRoot ω m)
    (dom : ι ↪ E) (h3 : 3 * e < Fintype.card ι - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (o : ℕ) (wt : Fin k → σ → Fin m → E) (val : Fin k → E) (Ub : κ → ι → E) (u : ι → E) (La : σ → κ → E)
    (Lb : κ → E) (q : E → E[X]) (hq : ∀ θ, (q θ).natDegree < 2 * m) (prox : E → (κ → E) → E[X])
    (hprox : ∀ θ r, (prox θ r).natDegree ≤ K) :
    (PMF.uniformOfFintype ((E × (κ → E)) × (Fin Q → ι))).toOuterMeasure
        {x | MAccept dom ω o wt val Ub u La Lb q prox x.1.1 x.1.2 x.2
          ∧ ¬ MGood dom ω o e K wt val Ub u La Lb}
      ≤ max (((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ)
              + (((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q)
            (((k - 1 + o : ℕ) : ℝ≥0∞) / Fintype.card E + (((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q)
```
- Far: `affine_proximity_third` (F6), then the column test against the proximity vector.
- Close: `mproduct_sound` on the decoded rows.
- `mopening_sound_absorbed`: when `k − 1 + o ≤ e + 1` and `e + dd ≤ N − (e + 1)`, the bound is the proximity-only
  `(e + 1)/(|E| − 1) + ((N − (e + 1))/N)^Q`.

## R2. How the bounds compare with the count

| Opening | Count | Lean | Status |
|---|---|---|---|
| Regular, several groups (W16R2: N 2^15, Q 280) | −112.278 per opening; groups and `λ` not itemized | `groups_sound_rs_half`: `N/p² + col`, −112.392 | **The per-opening term covers several groups and the `λ` batching**: neither adds a term |
| `M` (RS(1024, 4096), Q 256, e 1024) | −106.248: `(3/4)^256 + (2·512 + 1 + 4096)/p²` | far: `1025/(p² − 1)` = 2^−117.999 and `(3071/4096)^256` = 2^−106.370; close: `33/p²` = 2^−122.956 (34 functionals) and `(2558/4096)^256` = 2^−173.875 (`dd = 1534`) | **Covered, but only for the offset-aware event.** `mopening_sound_absorbed` applies (`33 ≤ 1025`, `2558 ≤ 3071`), so the product test adds nothing to −106.370. What is bounded is "a functional false beyond the offset on functional 0", not "a functional false" (F12) |

- `M`'s `θ` batching is by POWERS. It costs `(k − 1)/|E|` per opening: `33/p²` for the 34 functionals of a block
  (`N_FUNCTIONALS`). The count does not itemize it (as F3 for `ζ`); the max form absorbs it.
- The product test's column term uses the degree `K + m − 1 = 1534`, not `1022`, because the a-rows are
  degree-tested only at `< 2m` (F13). It is still 2^−173.9.
- With the fix of F12 (`o = 1`) the close case's field term is `34/p²` = 2^−122.913. Nothing else moves.

## R3. What the model assumes, and how it meets the code

1. **The `λ` draws are independent and uniform, one per claim.** `zk_rhos` calls `challenge_fp2_vec(members.len())`
   per group, then draws `ρ`, before any group vector is absorbed. The model lets every vector depend on all of
   `(λ, ρ)`.
2. **The encoder** is any injective linear map with the code as its range. The instance obligation: `encode_row_zk`
   (`f_data + Z_n·g_pad` on the coset) is a bijection onto `RS[n + Q]` there (lemma check §1), and the re/im split is
   its `F_p²`-linear extension. Not proved here.
3. **The claim as a functional.** `claimValue` is the bilinear form of `(rw, cw)`. That `zpart_weights` (with
   `eq_table_msb`) turns a `ZClaim`'s MLE evaluation into exactly this form is part 1 §3.2's reduction. Not done.
4. **One field.** The committed rows are `E`-rows; `F_p` rows are a special case. Closeness over `F_p²` implies it over
   `F_p` (`close_of_close_lift`), so nothing is lost.
5. **`M`'s layout.**
   - The product rows are fixed `E`-combinations of the committed rows (`La`, `Lb`).
   - How `u` is built from `u_re`, `u_im` does not matter for soundness: it is the affine offset.
   - The message points are `ω^j` in natural order. The NTT's order is a fixed bijection, which only relabels the
     weights, and `weight_polys` uses the same NTT.
6. **The degrees are wire lengths.** `q'` and the proximity vector have `2m` coefficients each (`op.q.len()`,
   `op.prox.len()`); hence `hq` and `hprox`.
7. **The order.** `M`'s root precedes every challenge. All functional values are fixed before `θ`: they are assembled
   before `mask_verify_tagged` draws it. `q'` precedes `r`, and the proximity vector precedes the indices.

## R4. Findings

**F12 (High, needs a code check: `M` certifies its first functional only up to a constant the prover chooses).**
- **What the code does.**
  - `combined_weights` (`zk.rs:530-547`) starts the powers at `θ^0 = 1`.
  - The verifier checks `512·(q'_0 + q'_512) = V`. If `q'` is the product polynomial of the committed rows, the left
    side is `Σ_i θ^i·tru_i + Σ_{x ∈ G_512} b(x)` (`mResidual_root`).
  - The honest prover sets `b_512 = −b_0` so that the last sum is zero (`mask_commit_tagged`, `zk.rs:512-515`).
  - **Nothing checks it.** The proximity test only bounds `b`'s degree, and `b` is in no functional.
- **The consequence.** A prover commits `M` with `Σ_{G_512} b = δ` (for example `b_re[512] = −b_re[0] + δ/512`) and
  claims `value_0 = tru_0 + δ`, every other value true. It passes `mask_verify_tagged` with probability 1
  (`mproduct_offset_accepts`; the Merkle and proximity parts are honest). `δ` is fixed before any challenge; the
  prover only has to make functional 0 come out `δ` too large.
- **Where it bites depends on what functional 0 is.** Read from the code, not run:
  - **Private block, private attention, the ZK layer** (`argument.rs`, `private_attention/argument.rs`,
    `verify_layer_zk`).
    - Slot 0 is a `Private` slot (`SLOT_KINDS[0]`), or the layer's `g_gu(ρ)`. So functional 0 is an EVALUATION
      value, `g_val = (fin − poly(vals))/c_0`.
    - The shift then enters the slot's terminal multiplied by `c_0`. The private slot's scalar moves by
      `2^(n + ext)·c_0·δ`, and its host's relation must absorb that. `c_0` is drawn after `M` and the witness are
      committed, so this is a `≲ deg/|F|` event, not an exploit.
    - But no current argument charges it. `sumcheck_sound_masked` assumes that `G` and `g(ρ)` come from the same
      committed `g` (part 1, §3.3), and that is exactly what fails here.
  - **Token-I/O stages** (`stage_in.rs`, `stage_in_c.rs`, `stage_out.rs`, `stage_out_c.rs`).
    - Slot 0 is the `Standalone` IO-in slot. So functional 0 is its `Γ = c·G_0`, whose value is the scalar the prover
      SENDS (`pb-scalar`), and the slot's claimed sum is that scalar.
    - The shift moves the claim itself: the zero claim `Σ_x eq(τ, x)·R(x) = 0` becomes `= δ`. Since
      `Σ_x eq(τ, x) = 1`, a relation with `R ≡ δ` on the whole cube passes for every `τ`.
    - **OUT-00** (`stage_out.rs:355-365`). `R(x) = A_X(x) − B_out(T − 1, x)` over the whole `d_pad` plane
      (`d_pad = h_pad·head_dim = d` for 8B: no pad positions). `A_X` is the stage's private copy of the final hidden
      state. As far as this read shows, only this slot ties it to `B_out`. A prover that commits `M` with offset `δ`
      and sets `A_X = B_out(T − 1) + δ·1` can run every other slot honestly on the shifted vector, and by the Lean
      model every check of `M` passes. The result would be an accepted next-token receipt computed from a shifted
      final hidden state, with `δ` free to choose offline. `stage_out_c.rs` (OUTC-00) has the same shape.
    - **IN-00** (`stage_in.rs:200-211`). `R = end − supp·tok`. With an endpoint whose pads are zero and whose
      position 0 is BOS (the QZC clause forces `tok(0) = BOS`), `R(0) = 0 ≠ δ`, so the shift is caught. It is open
      only if the prover chooses the endpoint plane.
  - **The experimental seam** (`private_seam.rs`): functional 0 is the `Γ` of `Σ_x eq(τ, x)·(A − B)(x) = 0`, so
    `A = B + δ` would be accepted as equal.
  - `zk_ffn_fresh_io.rs` appends its IO functionals after the FFN's own (from slot 6). Its functional 0 is an
    evaluation value, as in the block.
- **Why the tests pass.** The honest prover's `b` has zero sum, and no negative test commits a `b` with a nonzero sum.
- **Suggested.**
  - (a) Start the powers at `θ`: `let mut th = theta;` in `combined_weights`, which the prover and the verifier share.
    Then a `b` offset or any false functional makes the residual `Σ_i δ_i·θ^(i+1) − off` nonzero, and the test is
    sound for every functional (`mproduct_sound_shift`, `k/|E|`). Completeness and hiding are unaffected: the honest
    `b` still has zero sum, and `q'` is still uniform given `V`. It changes `q'`, so it needs a new profile version.
  - (b) Or constrain `b` itself: for example, commit it as `x·r(x) + (x^512 − 1)·t(x)` with `r` and `t` degree-tested
    separately. That is more code than (a).
  - (c) A Rust negative test. Commit `M` with `b_re[512] = −b_re[0] + δ/512` and add `δ` to functional 0's value. Today's
    `mask_verify_tagged` should ACCEPT it, which reproduces F12; after the fix it should reject it. Then the end-to-end
    version, on stage OUT with `A_X` shifted by `δ`.
  - Until it is fixed, no soundness claim should be made for the token-I/O stages, and the count's `M` term bounds
    only the offset-aware event.

**F13 (Info: `M`'s a-rows are degree-tested only at `< 2m`).** The proximity vector has `2m = 1024` coefficients. So
the a-rows, honestly of degree `< 512`, are only known to have degree `< 1024`.
- Nothing is lost: the decoded a-row's message is read as its values on `G_512`, which is exactly what the sum check
  reads (`sum_mProduct`).
- The cost is in the product polynomial's degree bound, `1534` instead of `1022`, inside the column term:
  `(2558/4096)^256` = 2^−173.9.

**F14 (Info: the batching terms).**
- The PCS `λ` are independent, one per claim: `1/|E|`, and only in the close case, where it is absorbed
  (`groups_sound`). No term.
- `M`'s `θ` are powers: `(k − 1)/|E|`, `33/p²` per block opening. The count does not itemize it; the max with the far
  case absorbs it (`mopening_sound_absorbed`).

## R5. What remains

- **F12**: the fix, or a per-profile proof that functional 0 is an evaluation value with the `c_0`-scaled shift
  charged in the composition; the negative test; the end-to-end check on the token-I/O stages.
- **The instance**: `encode_row_zk` as an injective linear map onto `rsCode` on the coset; `zpart_weights` and
  `eq_table_msb` as `claimValue`; `M`'s `La`, `Lb` with `U² = 7`; the NTT order.
- **Task 3 (optional, not done)**: one block's `3 + 1` openings as one union bound over a shared oracle, with one
  collision term and a guess term per commitment.
- **Composition and Fiat–Shamir**, as in Parts 1–3.

## F12 CONFIRMED against the Rust verifier (coordinator, 2026-11-04)

`hashline/src/zk_f12_tests.rs` (`results/zk60_h124_witness_20261104/f12_test.log`) commits `M` with a blinding
polynomial whose sum over G_512 is δ = 5, by setting `b_re[512] = −b_re[0] + δ/512`, and opens it with functional 0
claimed as `true + δ`. **`mask_verify` returns `Ok(())`.**

Controls, each behaving as F12 predicts:
- the true values are rejected against this commitment;
- the same shift on functional 1 (θ¹) is rejected;
- an honest commitment rejects a shifted functional 0.

**What this means:**
- The mask-level forgery is real.
- Whether it gives an end-to-end forgery depends on what functional 0 is in each stage. The Lean agent's code
  reading:
  - **token-I/O OUT / OUT-C:** functional 0 is the standalone IO-in slot's Γ, so a receipt from a shifted final
    hidden state would be accepted;
  - **the private block:** the shift is scaled by a later challenge, so it is small but uncharged.
- That end-to-end consequence is NOT yet reproduced. **Until it is fixed, no soundness claim should be made for
  token-I/O or classifier (OUT-C) receipts.** Nothing is in production (D63).

**The fix:**
- Start the θ powers at θ¹ in `combined_weights`, shared by prover and verifier. `mproduct_sound_shift` proves this
  catches every false functional with probability at least 1 − k/|F|.
- It changes every `M` opening, so every receipt's bytes, every golden and every registered digest. It therefore
  needs new profile versions, re-registration and a new gate run. That rollout is Victor's decision.
- The reproduction test then flips to expect a rejection.


> Merge note (coordinator, 2026-11-04): this section was written in parallel with the multi-group Part 4 above.
> It is renumbered Part 5, and its findings are renumbered F16–F19 (the agent wrote F12–F15), so they do not
> collide with F12 (M's offset, High) above. Its F16 is the Low `RunStatement.context` finding.

# Part 5 (2026-11-04): Fiat–Shamir in the random-oracle model

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

## S1. What is proved

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

## S2. The bounds compared

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
    `(N_lk + 2·T_d − 1)/p² = 2^-102.93`, or `2^-102.92` with `β, γ, α` read as one draw (F19).
  - That would give `εs(q) ≈ q·2^-102.9` for the whole run, plus `≈ T²/2^256`.
  - Reading the count's whole-run `2^-97.78` as a per-attempt rate (ACCOUNTING A2) is the more conservative figure.

## S3. What the model assumes, and how it meets the code

1. **The statement is bound before any challenge** (verified in the code).
   - The block header `protocol::transcript` (`protocol.rs:113-127`) absorbs these, after the profile's domain:
     - `expected-IO`: the context digest, both scales, the input and output endpoint roots;
     - `public-statement`: the weights and tables digest;
     - `parameters`, `calibration` and `schedule`.
   - Then come the `A` root (with rows and log-cols) and the `M` root, before `β, γ, α` (`protocol.rs:2003-2007`).
   - The run headers (`run.rs:844-861`, `run_fork.rs:749-763`) absorb the same, plus `run-shape`.
   - Stage and fork indices are absorbed before each stage (audit, not re-read).
   - The exception is F16.
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
   - Vector challenges drawn by several squeezes (F19).
   - Several protocols composed on one chain (slots, blocks, the PCS).
   - The extractor's log cut at the root's absorption (task 4).
   - The refusals of zero draws (they only add rejection).

## S4. Findings

**F16 (Low: a statement field of D12a/D55 runs is not bound).** `RunStatement` has its own `context` field
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

**F17 (Info: nothing a challenge depends on is absorbed after it).** A read-only audit covered the private-block
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

**F18 (Info: under Fiat–Shamir the error is per query, the maximum over rounds).** See §R2.
- The count's interactive union bound is not the Fiat–Shamir figure.
- Round-by-round soundness of the whole IOP, with the per-round errors the count already itemizes, gives `q·max`
  instead. The chain adds `≈ T²/2^256`.
- When the IOP's RBR instances are proved, `εs q` can be stated from them directly.

**F19 (Info: vector challenges are drawn by several squeezes).**
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

## S5. What remains

- **The wide-digest lemma** (F19). Then the RBR instances of LogUp (`β, γ, α` as one round, `logup_block_bound`) and
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

# Part 6 (2026-11-04): vector challenges, LogUp and one opening under Fiat–Shamir

New files under `formal/ZK60Formal/`: `FSWide.lean`, `FSWideRbr.lean`, `FSLogUp.lean`, `FSOpening.lean`.
- `lake -d formal build` succeeds with no warnings (3399 jobs). Each of the 52 modules was also built alone, through
  the resource guard. No file uses `sorry`, `axiom`, `admit`, `native_decide` or a `maxHeartbeats` option.
- `#print axioms` was run on all 83 theorems of the four files. Each depends on `propext`, `Classical.choice` and
  `Quot.sound` only, or on fewer (three on none).
- The four files set `autoImplicit false` (see F23). No new lake dependency, and nothing was copied from FlashProve.

**Scope.** `Statements.lean`'s model, as in Part 5:
- one uniformly random `H : Q → D`;
- the prover is a deterministic `OC Q D _` making at most `q` hash queries on every path, and it chooses the
  statement;
- the transcript is the code's hash chain (`FSChain.lean`), and the challenges are the code's derivations of its
  digests.

The code read is the `gpu-metal` tree (`ops/zkp-mvp/gpu-metal/`), as in Parts 3–5.

## U1. What is proved

**The wide-digest lemma (closes the proof gap of F19)** (`FSWide.lean`).
- A STEP is an item and its forced continuation (`Steps`). For a squeeze `sq c` that starts a `k`-wide challenge, the
  continuation is `sq (c + 1)`, …, `sq (c + k − 1)`, with no absorb between them.
- The step's queries are `y = link(d, it)`, then `link(D_j, item j + 1)`; each names the digest before it.
- `wideSwap` and `wide_card_le` are the counting core. Fix the start query `y`. Rewriting `H` along the step's own
  queries (`Function.extend`) is a bijection of `(Q → D) × D^k` that exchanges "the step's digests" with "a free
  `k`-tuple".
- `wideHit_prob_le` is the lemma in an adaptive run. It covers a query `y` that is asked for the first time, starts a
  step whose later queries are all new, and whose `k` digests land in a set named by the log before `y`:
```lean
theorem wideHit_prob_le {α : Type} (A : OC Q D α) (T : ℕ) (hA : A.Bounded T) (wd : Q → ℕ)
    (nx : Q → ℕ → D → Q) (hinj : ∀ y (b : Fin (wd y) → D), Function.Injective (widePts y (nx y) b))
    (Bad : List (Q × D) → Q → List D → Prop) (ε : ℝ≥0∞)
    (hBad : ∀ P y, (PMF.uniformOfFintype (Fin (wd y) → D)).toOuterMeasure {b | Bad P y (List.ofFn b)} ≤ ε) :
    prH (fun H => WideHit wd nx Bad H (A.runLog H).2) ≤ (T : ℝ≥0∞) * ε
```
  Each of the `T` positions is one attempt, and each attempt gets a fresh, uniform `k`-tuple. The per-attempt bound
  `ε` is the WIDE challenge's own (for `ρ`, `A/|E|`), not a bound paid once per squeeze.
- `chain_sound_wide` is `chain_sound` with steps:
```lean
theorem chain_sound_wide (C : ChainEnc It Q D) (S : Steps It) (St : List (Q × D) → List (It × D) → Prop)
    (s : ℕ) (ε : ℝ≥0∞)
    (hround : ∀ P τ it, s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) → ¬ St P τ →
      (PMF.uniformOfFintype (Fin (S.wd it) → D)).toOuterMeasure {b | St P (τ ++ S.ents it (List.ofFn b))} ≤ ε)
    (hstab : ∀ (H : Q → D) (P P' : List (Q × D)) (τ : List (It × D)) (qs : List Q) (ext : List (It × D)),
      C.Chain H τ qs → s ≤ τ.length → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        (St P (τ ++ ext) ↔ St P' (τ ++ ext)))
    {α : Type} (heads : α → List It) (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => ¬ St ((C.stepRun S heads A).runLog H).2
          (C.chainFrom H [] (((heads (A.run H)).take s).flatMap S.items))
        ∧ St ((C.stepRun S heads A).runLog H).2 (C.chainFrom H [] ((heads (A.run H)).flatMap S.items)))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) D + collBound (q + ℓ + 1 + 1) D
```
  - The verifier hashes every step in full, so a chain is never cut inside a vector challenge. That is why the round
    hypothesis is asked only of chains made of whole steps.
  - The state may READ THE LOG (`St P τ`). Knowledge soundness needs this. The condition `hstab` asks that, once a
    chain's queries are logged, a longer log changes neither its state nor that of its extensions.
  - The proof is `chain_sound`'s. One more thing is needed: the later queries of the escaping step were not asked
    before its first one. If one had been, the chain up to it, ordered by `chain_ordered`, would put the first query
    earlier.

**A protocol with vector challenges on the chain** (`FSWideRbr.lean`).
- `n` rounds. Round `i` has width `w i ≥ 1` and a message iff `hasMsg i`.
- The squeeze counter is the code's running count: `ctr w i = Σ_{i'<i} w i'`.
- The verifier's items are `pHeadsW`, expanded by `pSteps`. The reader is `rDecodeW`: it never stops inside a round
  (`foldl_bnd_flatMap`), and it reads the verifier's own chain as exactly `|ms|` rounds (`foldl_roundHeads`).
- The protocol's transcript records each round's message (a default when there is none) and its RAW DIGESTS. The
  derivation of the challenge is the state function's business.
- Round-by-round soundness at the level of digests:
```lean
structure RbrWide [Fintype D] [Nonempty D] (n : ℕ) (w : ℕ → ℕ) (St : X → List (M × List D) → Prop) (ε : ℝ≥0∞) :
    Prop where
  round : ∀ x τ m, τ.length < n → ¬ St x τ →
    (PMF.uniformOfFintype (Fin (w τ.length) → D)).toOuterMeasure {b | St x (τ ++ [(m, List.ofFn b)])} ≤ ε
theorem fs_chain_sound_of_rbr_wide (hw : ∀ i, 0 < w i) (C : ChainEnc (PItem X M) Q D) {Mf : Type}
    {L : X → Prop} {accept : X → List (M × List D) → Mf → Prop} {St : X → List (M × List D) → Prop}
    (ε : ℝ≥0∞) (hR : RbrWide n w St ε) (hstart : ∀ x, ¬ L x → ¬ St x [])
    (hfinal : ∀ x τ mf, τ.length = n → ¬ St x τ → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q D (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW n w hw hasMsg m₀ accept C H (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW n w + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓW n w + 1) D
        + collBound (q + ℓW n w + 1 + 1) D
```
  `ℓW n w = 1 + Σ_{i<n} (1 + w i)`. The general form, with a state that reads the log, is `fs_chain_wide_flip`.
- From an interactive bound to digests: `prob_vec_comap_le`, a vector read coordinatewise through a derivation with
  at most `K` digests per value, costs `biasFactor K C D ^ k`. For the code's `challenge_fp2_vec`, `prob_fp2_vec_le`
  gives `(1 + p/2^128)^(2k)`.

**LogUp** (`FSLogUp.lean`; task 2). It has two rounds with no message, as the code draws them: `(β, γ)` of width 2,
then `α` of width 1 (`protocol.rs:2005-2007`, the prover at `1708-1710`).
```lean
theorem logup_fold_round (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F) (h : luFalse A T) :
    (PMF.uniformOfFintype (F × F)).toOuterMeasure {p | foldedId A T m p.1 p.2}
      ≤ ((2 * (univ.image T).card : ℕ) : ℝ≥0∞) / Fintype.card F
theorem logup_alpha_round (A : ι ⊕ (π ⊕ π) → Tup F) (T : κ → Tup F) (m : κ → F) (β γ : F)
    (h : ¬ foldedId A T m β γ) :
    (PMF.uniformOfFintype F).toOuterMeasure
        {α | ∃ H, HelperRel (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m α H}
      ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞)
        / Fintype.card F
theorem fs_logup_chain_sound (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    (lu : X → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (C : ChainEnc (PItem X Unit) Q Dg) (q : ℕ)
    (A : OC Q Dg (X × List Unit × Helpers ι π κ F)) (hA : A.Bounded q) :
    prH (fun H => luFalse (lu (A.run H).1).1 T
        ∧ chainAcceptsW 2 luW luW_pos luMsg () (luAccept (fp2Field p (2 ^ 128) eF) T lu) C H (A.run H).1
            (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + 6 + 1 : ℕ) : ℝ≥0∞) * luEps (ι := ι) (π := π) p T + collBound (q + 6 + 1) Dg
        + collBound (q + 6 + 1 + 1) Dg
```
- `luEps p T = (N + 2M − 1)/|F| · (1 + p/2^128)^4`, where `N` counts the lookups (two per pair) and `M` the distinct
  table tuples.
- The state is "the folded identity holds" after `(β, γ)`, and "some helpers pass every relation and the sum claim"
  after `α`.
- The two rounds' errors are the halves of `logup_block_bound`'s proof. They add up to its `(N + 4M − 1)/|F|`
  (`logup_rounds_add`).
- The statement carries the lookups and multiplicities as values. The table is fixed (public).

**One opening with the extracted matrix: round-by-round knowledge soundness** (`FSOpening.lean`; task 3).
- The rounds come from `groups_sound`'s proof, split at the message:
  - `opening_round0`. If some claim is false of the decoded message (or `U` is far), uniform `(λ, ρ)` keep the
    opening alive with probability at most `A/|E|`. Alive means close with every group's `λ`-combined claim true, or
    far with `Σ ρ_i U_i` close (`Alive1`).
  - `opening_round1`. From a doomed `(λ, ρ)`, whatever vectors the prover sends, uniform `J` pass with probability at
    most `((N − (e + 1))/N)^Q`.
- The extraction:
  - `cutLog` cuts a log at the first query that absorbs the root.
  - `proverLog` recovers the prover's own log from any longer log by replaying the prover (`OC.replay`).
  - `xtU` is `extractU` of the prover's log so cut. It reads only the prover's log and the root in the receipt, as
    `KnowledgeSound` requires.
  - `cut_proverLog_stable`: once a log contains an absorption of the root, every longer log extracts the same matrix.
    This is the `hstab` above.
- `opening_extract_fail` is the Merkle part, in the whole run: the prover, the verifier's chain and the verifier's
  Merkle checks at the derived indices. An opened column that verifies but is not the extracted one has probability
  at most `collBound T' D + 2T'²/|D|`, `T' = q + (ℓW + 1) + Q(h + 2)`.
  - The named set (`extNamed`, at most `4|P| + 2` digests) holds the Merkle children and leaf contents of the log,
    and the roots that a logged query (or the query itself) absorbs or that the replayed prover outputs.
  - Part 3's `T(3q₁ + 1)` becomes `2T'²`. Under Fiat–Shamir the commit phase is the prover's whole run up to the
    root's absorption, so `q₁` is replaced by `T'`.
- The knowledge theorem with the code's derivations:
```lean
theorem fs_opening_knowledge_code (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (hh : h ≤ 64)
    (M : MerkleEnc Q Dg S Col) (colVal : Col → κ → F) (c₀ : Col)
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (C : ChainEnc (PItem X (OMsg G μ F)) Q Dg)
    (clOf : X → OClaims Cl G κ μ F) (rootOf : X → Dg) (d₀ : Dg) (m₀ : OMsg G μ F) {w0 m : ℕ} (h0 : 0 < w0)
    (hm : 0 < m) {nQ : ℕ} (hnQ : nQ ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ)
    (q : ℕ) (Pv : OC Q Dg (X × List (OMsg G μ F) × (Fin nQ → MerkleOpening Dg S Col))) (hPv : Pv.Bounded q) :
    prH (fun H => opAccepts M colVal enc clOf rootOf d₀ m₀ h0 hm (lrCode p eF eLR) (idxCode h hnQ) C H
          (Pv.run H).1 (Pv.run H).2.1 (Pv.run H).2.2
        ∧ ¬ GroupsGood enc e (extractU M colVal c₀ (cutLog C rootOf (rootOf (Pv.run H).1) (Pv.runLog H).2) h
            (rootOf (Pv.run H).1)) (clOf (Pv.run H).1).rw (clOf (Pv.run H).1).cw (clOf (Pv.run H).1).grp
            (clOf (Pv.run H).1).val)
      ≤ ((q + ℓW 2 (opW w0 m) + 1 : ℕ) : ℝ≥0∞)
          * max ((A : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0))
            ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * 1)
        + collBound (q + ℓW 2 (opW w0 m) + 1) Dg + collBound (q + ℓW 2 (opW w0 m) + 1 + 1) Dg
        + (collBound (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) Dg
          + ((2 * (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) * (q + (ℓW 2 (opW w0 m) + 1) + nQ * (h + 2)) : ℕ)
            : ℝ≥0∞) / Fintype.card Dg)
```
  - `fs_opening_knowledge` is the same for any derivations whose bias is bounded.
  - `lrCode_prob_le`: the code's `(λ, ρ)` costs `(1 + p/2^128)^(2·w0)`.
  - `idxCode_prob_le`: the code's `challenge_indices` is exactly uniform. `chunkEquiv` gives the four 8-byte chunks
    of a digest (`lo mod 2^64`, `lo / 2^64`, `hi mod 2^64`, `hi / 2^64`; `chunkEquiv_spec`). Index `k` is chunk
    `k mod 4` of squeeze `⌊k/4⌋`, masked (`idxCode_spec`). The unused chunks of the last squeeze are free coordinates
    (`prob_restrict_eq`).

## U2. The bounds compared

The figures are per hash query, with `|F| = |E| = p²`, `N_lk = 34,897,920` and `T_d = 127,668` (Part 1).

| Protocol | Count (interactive, `recount_q280`) | Proved under Fiat–Shamir, per hash query: the max over its rounds |
|---|---|---|
| LogUp, one block | `(N_lk + 4T_d − 1)/p²` = 2^-102.922 | `α`: `(N_lk + 2T_d − 1)/p²·(1 + p/2^128)^4` = **2^-102.933**; the fold `2T_d/p²` = 2^-110.04 |
| Regular opening, W16R2 (N 2^15, Q 280, e 8,052) | column + field −112.278 (proved interactively: −112.392) | field `N/p²·(1 + p/2^128)^(2w0)` = **2^-113.000** (the bias is `1 + O(w0·2^-63)`); column 2^-113.932, bias exactly 1 |
| `M`'s opening | −106.248 | not under Fiat–Shamir yet (interactive, offset-aware: −106.370, F12) |
| Sumcheck slot, `d = 5` | — | 5/p² = 2^-125.678 (Part 5) |

- The chain and the extraction add `collBound T + collBound (T + 1) + collBound T' + 2T'²/2^256 ≤ 3.5·T'²/2^256`. That
  is 2^-126.2 at `T' = 2^64`, and it stays below 2^-100 while `T' ≤ 2^77`.
- Every bound is linear in `q`, the approved target's shape. Per hash query, LogUp is 2.9 bits under the target's
  2^-100 and the opening 13 bits under.
- The count's LogUp term and the proved per-query term differ in kind:
  - the count's is the interactive SUM of LogUp's two rounds;
  - the per-query term is the MAXIMUM of the two, because each query attacks one round.

## U3. What the model takes from the code, and where it differs

1. **The vector challenges are back-to-back squeezes** (verified):
   - `zk_rhos` draws every group's `λ`, then `ρ`, with no transcript operation between them (`pcs.rs:952-973`);
   - `challenge_fp2_vec` loops `challenge_fp2` (`transcript.rs:131-133`);
   - `challenge_indices` loops `squeeze_bytes` over four 8-byte chunks each (`transcript.rs:136-148`);
   - LogUp's `β, γ, α` are three calls in a row (`protocol.rs:2005-2007`).
   Each squeeze increments the counter (`transcript.rs:101-111`), so the items of one step are distinct, as `Steps`
   requires.
2. **The order** (verified):
   - the `A` root is absorbed (`protocol.rs:2003`) before `β, γ, α` and long before the opening's `λ, ρ`;
   - in the opening, the vectors are absorbed (`pcs.rs:1220-1226`) before `J` (`pcs.rs:1227`);
   - the opened column must sit at the sampled index (`pcs.rs:1251`), and its path must have the tree's depth
     (`pcs.rs:1199-1204`).
3. **The index derivation is the code's exactly** (`chunkEquiv_spec`, `idxCode_spec`): little-endian `u64` chunks,
   masked by `bound − 1`, `⌈Q/4⌉` squeezes (70 at `Q = 280`). `v as usize` is lossless on a 64-bit target.
4. **Where the model simplifies** (none of these is a defect in the code):
   - **The opening's statement** (the root and the claims) is one item. In the code the root is absorbed first, and
     the claims are fixed later by the slots' transcript. That prover is weaker, so the model is conservative. But
     the composition with the slots that fix the claims is not stated.
   - **The cut item.** `rootAbs` recognizes a statement link that carries the root. A code-level instance must
     recognize `absorb_root(tr, "A", root, rows, log_cols)` (`protocol.rs:2003`), a different item.
   - **Multi-absorb messages and headers are one item each**: the opening's `"pcs-vec"` per group and `"pcs-prox"`,
     LogUp's `A` and `M` roots. This is the same chain with more links; only `T` changes.
   - **LogUp's lookups and multiplicities are statement values.** In the code they are committed in `A`. The
     knowledge version (extracting them from `A`'s commitment) is not stated.
   - **The refusals of zero draws are not modelled.** They only add rejection.

**No place was found where the code's transcript order or challenge derivation does not match what the proofs
need.**

## U4. Task 4: the whole-block figure, per hash query (union bound)

What is proved so far gives one Fiat–Shamir theorem per sub-protocol. Their union is a bound for a run that contains
them all. Per hash query, it is the SUM of the sub-protocols' per-query errors:

| One block (8B T128, W16R2 Q 280) | Per hash query |
|---|---|
| LogUp | 2^-102.933 (proved, U2) |
| `M`'s opening | 2^-106.248 (count; not yet under Fiat–Shamir) |
| 3 regular openings (`A` and `H`, verified in the block, and the endpoint claims `ic, oc` it returns to its caller, `protocol.rs:2030`) | 3 × 2^-113.000 = 2^-111.415 (proved, U2) |
| 23 sumcheck slots | ≤ 23 × 5/p² = 2^-121.15 (proved per slot, Part 5) |
| The slots' zero-check `τ` draws and batches | ≈ 23 × 25/p² = 2^-118.83 (wide `τ`: `main/|F|`; `μ`: `1/|F|`; not yet under Fiat–Shamir) |
| **Union, one block** | **2^-102.791** |
| **Union, the count's 32-block run** | **2^-97.791 per hash query** |

- The count's whole run is 2^-97.779 (2^-102.779 per block). That is an interactive TOTAL, with no `q`.
- The union is a per-hash-query RATE: `εs(q) ≈ q·2^-97.79 + 3.5·T'²/2^256`. The two figures agree to 0.01 bit
  because LogUp dominates both. Its Fiat–Shamir term (`α`'s `N + 2T_d − 1`) is slightly smaller than the count's
  `N + 4T_d − 1`. Its other entries take the max where the count takes the sum.
- One chain, composed as ONE round-by-round protocol, would give the maximum over all rounds of the run instead:
  LogUp's 2^-102.933 per hash query. That composition is not proved (F20).

## U5. Findings

**F20 (Medium: the approved soundness target needs the one-chain composition).**
- The approved target is `εs(q) = q·2^-100 + 2^-100`, a per-query rate of 2^-100.
- **What is proved now gives only a union over sub-protocols.** That is 2^-97.79 per hash query for the 32-block run
  (U4), **2.21 bits above the target**. At `q = 2^64` it is 2^-33.8 against the target's 2^-36.
- **Composed on one chain**, each query attacks one round of one sub-protocol, and the per-query error is the maximum
  over all rounds: LogUp's 2^-102.933, **2.93 bits under**. This needs:
  - a combined state, "every sub-statement still alive", in which a round can only revive the sub-protocol it belongs
    to;
  - one schedule for the slots, LogUp, the openings, `M` and the blocks.
  `FSWideRbr.lean`'s wrapper already takes per-round widths, rounds with and without messages, and the running
  counter, so it is the natural place.
- **Until it is proved, no proved bound meets `εs`.** This is not a code defect.
- **Alternatives**, if the composition stalls: a profile that brings the union under 2^-100 per query (fewer blocks
  per run, or a smaller LogUp term), or a ruling on the target. Either is Victor's decision.

**F21 (Info: LogUp's per-query error is the `α` round's, not the count's joint figure).**
- The fold `(β, γ)` and the `α` step are separate rounds. The second has no message: the state after `(β, γ)` is
  determined by the statement and the two digests, which `RbrWide` allows.
- Per hash query: `(N + 2M − 1)/|F|` = 2^-102.933. The count's `(N + 4M − 1)/|F|` = 2^-102.922 is their sum.
- F19's "three rounds" reading (`N + 5M − 1`) is not needed. The wide lemma makes `(β, γ)` one round.

**F22 (Info: the regular opening, per query, is its field term).**
- `max(N/|E|·(1 + p/2^128)^(2w0), ((N − (e + 1))/N)^Q)` = 2^-113.000 at W16R2.
- The `(λ, ρ)` bias, `(1 + 2^-64)^(2w0) ≈ 1 + w0·2^-63`, is negligible for `w0 ≤ 2^40`. The column term's
  derivation is exactly uniform.
- The extraction under Fiat–Shamir costs `2T'²/2^256` (Part 3's `T(3q₁ + 1)` with `q₁ = T'`).

**F23 (Low: `autoImplicit` is on in `formal/`).**
- `lakefile.toml` sets no Lean options, and Lean's default turns on auto-bound implicits. An unknown name in a
  statement then silently becomes a universally quantified variable, and the statement still compiles.
- **It happened in this work.** A statement in a scratch draft used `Dg`, defined in a file it did not import. It
  compiled, with `Dg` read as an arbitrary type, until `set_option autoImplicit false` exposed it. The four new files
  set the option.
- **All 52 modules compile with `-DautoImplicit=false`.** Each was tested alone against the built imports, in scratch
  only; nothing in `formal/` was changed for the test.
- **Suggested:** `leanOptions = { autoImplicit = false }` in `formal/lakefile.toml`. It changes every module's build,
  so it was not made here.

## U6. What remains

- **The composition on one chain (F20).** The 23 slots, LogUp, the three openings, `M` and the blocks of a run, as
  one round-by-round protocol: `q·max + T²/2^256`.
- **`M`'s opening under Fiat–Shamir.** The pattern of `FSOpening.lean`, with the affine proximity test and the
  product-form test (`SoundMProduct.lean`), after F12's fix.
- **The knowledge versions of LogUp and the slots:**
  - the lookups and multiplicities extracted from `A`;
  - the sumcheck's committed tables;
  - the zero-check's wide `τ` and the batching vectors under Fiat–Shamir.
- **The code-level instance.** `ChainEnc` for keyed BLAKE3 byte strings, the header's absorbs, the counter offset,
  and `rootAbs` for `absorb_root`.
- **`KnowledgeSound`** of `Statements.lean`, from the above.
