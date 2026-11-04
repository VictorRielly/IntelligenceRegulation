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

- **The PCS.**
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
