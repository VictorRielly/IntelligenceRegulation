/-
D63, step L3 (soundness): the 8B T128 W16R2 run in the approved target's form, query-free part included
(finding F25 closed under stated premises; Victor's ruling D66(4), option (a)).

`FSComposeBlock.lean` proves the per-query rate of a block and of a D12a run, `135/2^110 ≈ 2^-102.92`, and leaves the
query-free part at `(ℓW + 1)·εRate8B ≈ 2^-87`. This file gives the run's sub-protocols per-round errors
(`FSPathSched.lean`'s `SubProtP`) and bounds the path-wise query-free part of `FSPath.lean` at the 8B parameters.

**The sub-protocols with per-round errors** (each with a tag, `Tag8B`, that says what it contributes to a zone):
* `logupP` (tag `lu`): LogUp's `(β, γ)` round, error `2M/|F|·(1 + p/2^128)^4` (the fold), then its `α` round,
  `(N + 2M − 1)/|F|·(1 + p/2^128)^4`. Its claim (the lookups and multiplicities) is read off the MESSAGE of its first
  round: in a run, stage `k`'s `A_k` (and `B_k`, `M_k`) are absorbed in that message (`run.rs:1402-1407`,
  `protocol.rs:2023-2027`). Its doom is a doom after that message (`pre`). The total is `(N + 4M − 1)/|F|·(1 + p/2^128)^4`,
  at most `136/2^110` (`logupP_tot_8B`).
* `openingP` (tag `op`): a regular opening, `(λ, ρ)` with its field term, then `J` with its column term. At W16R2 the
  total is at most `4/2^113` (`openingP_tot_W16R2`).
* `mask` (tag `mask`): `M`'s opening, ANY sub-protocol whose round errors sum to at most `2^-106` (ASSUMED; the count's
  whole `M` term is `2^-106.248`; its Fiat–Shamir proof waits on the F12 fix).
* The slots' sumchecks, evaluation points, batching vectors and free challenges (tag `small a`), carried over from
  `FSComposeBlock.lean` (`SubProt.toP`): total at most `2a/p²`, `a` their numerator (`n·d`, `ℓ`, `1`, `0`).
* `rest` (tag `small 0`): sub-protocols with no rounds (such as the pending claim "the rest of the run is right").

**What is proved.**
* `Kind8BP.er_le`: every round's error is at most `εRate8B = 135/2^110` (the per-query rate is unchanged).
* `Kind8BP.tot_le`: each sub-protocol's total is at most its tag's bound (`tagBound`).
* `BlockZone8B`, `zone_budget_le`: a zone with at most one LogUp, at most one `M`, at most four regular openings and
  small sub-protocols whose numerators sum to at most `2^16` has total at most `εZone8B = 155/2^110 ≈ 2^-102.72`.
* `fs_path_run_8B`: a run (any schedule of these sub-protocols on one chain) whose zones meet `FSPath.lean`'s premises
  and whose every transcript's charged rounds lie in one such zone: a false statement is accepted with probability at
  most `q·εRate8B + εZone8B + collBound T + collBound (T + 1)`.
* `fs_path_run_8B_target`: **in the approved form, `εs(q) = q·2^-100 + 2^-100`, for EVERY `q ≤ 2^75`** (with
  `ℓW + 1 ≤ 2^75`): the query-free part is `εZone8B + collision terms ≤ 284/2^110 ≈ 2^-101.85 < 2^-100`.
* `fs_zerocheck_chain_sound_sum`: a worked instance of the sharper count with every premise proved (the zero-check and
  its sumcheck, `FSComposeZeroCheck.lean`): the query-free part is the interactive bound `(n + n·(d + 1))/|F|·bias`.

**What is assumed** (premises): `M`'s round errors (sum `≤ 2^-106`); the zone structure (`hhand`, `hframe`, `hstart`,
`hfinal`, and `hpath`: along every transcript the charged rounds belong to ONE block zone). `hpath` is the structural
premise "the boundary commitments split the run into block-local paths": a doom that enters block `k` (when `B_k`
makes block `k`'s relation false) is revived only in block `k`'s rounds and the openings of `B_{k−1}` and `B_k`.
`FSPath.lean`'s header and the findings (Part 9) say why it holds for the code and what it needs.
-/
import ZK60Formal.FSPathSched
import ZK60Formal.FSComposeBlock
import ZK60Formal.FSComposeZeroCheck

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

/-! ## LogUp with per-round errors, its claim read off its first message -/

section LogUpP

variable {F : Type} [Field F] [Fintype F] [DecidableEq F]
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
variable {Y M : Type}

/-- **LogUp's state**, its lookups and multiplicities read off its first round's message: nothing is claimed before
it; after `(β, γ)`, alive iff the lookups pass or the folded identity holds; after `α`, iff they pass or some helpers
pass. -/
def luStM (chal : Dg → F) (T : κ → Tup F) (lu : Y → M → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (y : Y) :
    List (M × List Dg) → Prop
  | [(m, [d0, d1])] => ¬ luFalse (lu y m).1 T ∨ foldedId (lu y m).1 T (lu y m).2 (chal d0) (chal d1)
  | [(m, [d0, d1]), (_, [d2])] => ¬ luFalse (lu y m).1 T
      ∨ ∃ H, HelperRel (fun l => fold (chal d0) (chal d1) ((lu y m).1 l)) (fun j => fold (chal d0) (chal d1) (T j))
          (lu y m).2 (chal d2) H
  | _ => True

/-- **LogUp's state after a round's message**: after its first message, alive iff the lookups it names pass. -/
def luPreM (chal : Dg → F) (T : κ → Tup F) (lu : Y → M → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (y : Y) :
    List (M × List Dg) → M → Prop
  | [], m => ¬ luFalse (lu y m).1 T
  | τ, _ => luStM chal T lu y τ

/-- The fold round's error with the code's challenges: `2M/|F|·(1 + p/2^128)^4`. -/
noncomputable def luFoldE (p : ℕ) (T : κ → Tup F) : ℝ≥0∞ :=
  ((2 * (univ.image T).card : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 4

/-- LogUp's round errors: the fold, then `α` (`luEps`). -/
noncomputable def luEr (p : ℕ) (T : κ → Tup F) : ℕ → ℝ≥0∞ :=
  fun i => if i = 0 then luFoldE p T else luEps (ι := ι) (π := π) p T

/-- **LogUp is round-by-round sound with its per-round errors**, from a doom after its first message. -/
theorem logupP_rbr (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    (lu : Y → M → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) :
    ∀ y τ m, τ.length < 2 → ¬ luPreM (fp2Field p (2 ^ 128) eF) T lu y τ m →
      (PMF.uniformOfFintype (Fin (luW τ.length) → Dg)).toOuterMeasure
          {b | luStM (fp2Field p (2 ^ 128) eF) T lu y (τ ++ [(m, List.ofFn b)])}
        ≤ luEr (ι := ι) (π := π) p T τ.length := by
  classical
  intro y τ m hτ hns
  have : Nonempty F := ⟨eF 0⟩
  rcases τ with _ | ⟨⟨u, ds⟩, _ | ⟨e2, τ⟩⟩
  · -- round 0: the fold challenges `(β, γ)`, the lookups read off the message `m`
    have hF : luFalse (lu y m).1 T := not_not.mp hns
    rw [prob_ofFn_congr (show luW ([] : List (M × List Dg)).length = 2 from rfl)
      (fun ds => luStM (fp2Field p (2 ^ 128) eF) T lu y ([] ++ [(m, ds)]))]
    have hset : {b : Fin 2 → Dg | luStM (fp2Field p (2 ^ 128) eF) T lu y ([] ++ [(m, List.ofFn b)])}
        = {b : Fin 2 → Dg | (fun c : Fin 2 → F => foldedId (lu y m).1 T (lu y m).2 (c 0) (c 1))
            (fun j => fp2Field p (2 ^ 128) eF (b j))} := by
      ext b
      have hb : List.ofFn b = [b 0, b 1] := by simp [List.ofFn_succ]
      simp only [Set.mem_ofPred_eq, List.nil_append, hb, luStM]
      exact ⟨fun h => h.resolve_left (not_not.mpr hF), Or.inr⟩
    rw [hset]
    refine (prob_fp2_vec_le p eF 2 (fun c : Fin 2 → F => foldedId (lu y m).1 T (lu y m).2 (c 0) (c 1))).trans ?_
    rw [show (PMF.uniformOfFintype (Fin 2 → F)).toOuterMeasure {c | foldedId (lu y m).1 T (lu y m).2 (c 0) (c 1)}
        = (PMF.uniformOfFintype (F × F)).toOuterMeasure {c | foldedId (lu y m).1 T (lu y m).2 c.1 c.2} from
      prob_equiv_comp (piFinTwoEquiv (fun _ => F)) (fun c => foldedId (lu y m).1 T (lu y m).2 c.1 c.2)]
    have h1 := logup_fold_round (lu y m).1 T (lu y m).2 hF
    simp only [luEr, List.length_nil, ↓reduceIte, luFoldE]
    exact mul_le_mul' h1 le_rfl
  · -- round 1: `α`, after the fold
    have hempty : ∀ (E : Set (Fin (luW ([(u, ds)] : List (M × List Dg)).length) → Dg)), (∀ b, b ∉ E) →
        (PMF.uniformOfFintype (Fin (luW ([(u, ds)] : List (M × List Dg)).length) → Dg)).toOuterMeasure E
          ≤ luEr (ι := ι) (π := π) p T ([(u, ds)] : List (M × List Dg)).length := by
      intro E hE
      rw [Set.eq_empty_iff_forall_notMem.mpr hE, MeasureTheory.measure_empty]
      exact zero_le
    have hns' : ¬ luStM (fp2Field p (2 ^ 128) eF) T lu y [(u, ds)] := hns
    match ds, hns' with
    | [d0, d1], hns' =>
      simp only [luStM, not_or, not_not] at hns'
      obtain ⟨hF, hfold⟩ := hns'
      rw [prob_ofFn_congr (show luW ([(u, [d0, d1])] : List (M × List Dg)).length = 1 from rfl)
        (fun ds => luStM (fp2Field p (2 ^ 128) eF) T lu y ([(u, [d0, d1])] ++ [(m, ds)]))]
      have hset : {b : Fin 1 → Dg | luStM (fp2Field p (2 ^ 128) eF) T lu y ([(u, [d0, d1])] ++ [(m, List.ofFn b)])}
          = {b : Fin 1 → Dg | (fun c : Fin 1 → F => ∃ H, HelperRel
              (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu y u).1 l))
              (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu y u).2 (c 0) H)
              (fun j => fp2Field p (2 ^ 128) eF (b j))} := by
        ext b
        have hb : List.ofFn b = [b 0] := by simp [List.ofFn_succ]
        simp only [Set.mem_ofPred_eq, List.cons_append, List.nil_append, hb, luStM]
        exact ⟨fun h => h.resolve_left (not_not.mpr hF), Or.inr⟩
      rw [hset]
      refine (prob_fp2_vec_le p eF 1 (fun c : Fin 1 → F => ∃ H, HelperRel
        (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu y u).1 l))
        (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu y u).2 (c 0) H)).trans ?_
      rw [show (PMF.uniformOfFintype (Fin 1 → F)).toOuterMeasure {c | ∃ H, HelperRel
            (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu y u).1 l))
            (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu y u).2 (c 0) H}
          = (PMF.uniformOfFintype F).toOuterMeasure {α | ∃ H, HelperRel
            (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu y u).1 l))
            (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu y u).2 α H} from
        prob_equiv_comp (Equiv.funUnique (Fin 1) F) (fun α => ∃ H, HelperRel
          (fun l => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) ((lu y u).1 l))
          (fun j => fold (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1) (T j)) (lu y u).2 α H)]
      have h1 := logup_alpha_round (lu y u).1 T (lu y u).2 (fp2Field p (2 ^ 128) eF d0) (fp2Field p (2 ^ 128) eF d1)
        hfold
      simp only [luEr, List.length_cons, List.length_nil, zero_add, one_ne_zero, ↓reduceIte]
      calc _ ≤ (((Fintype.card ι + 2 * Fintype.card π) + 2 * (univ.image T).card - 1 : ℕ) : ℝ≥0∞)
              / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * 1) := mul_le_mul' h1 le_rfl
        _ ≤ luEps (ι := ι) (π := π) p T :=
            mul_le_mul' le_rfl (pow_le_pow_right₀ (one_le_fp2_base p) (by norm_num))
    | [], hns' => exact hempty _ (fun _ _ => hns' trivial)
    | [_], hns' => exact hempty _ (fun _ _ => hns' trivial)
    | _ :: _ :: _ :: _, hns' => exact hempty _ (fun _ _ => hns' trivial)
  · simp at hτ

/-- **LogUp as a sub-protocol with per-round errors**: two rounds with no message of their own in the code (the
commitments and the stage's absorbs are its first round's message), widths `2` and `1`. -/
noncomputable def logupP (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    {X : Type} (lu : X × List (M × List Dg) → M → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F))
    (pend : X → List (M × List Dg) → Prop) (pendM : X → List (M × List Dg) → M → Prop)
    (post : X → List (M × List Dg) → Prop) : SubProtP X M Dg where
  n := 2
  w := luW
  hasMsg := fun i => i == 0
  er := luEr (ι := ι) (π := π) p T
  St := luStM (fp2Field p (2 ^ 128) eF) T lu
  pre := luPreM (fp2Field p (2 ^ 128) eF) T lu
  rbr := logupP_rbr p eF T lu
  pend := pend
  pendM := pendM
  post := post

end LogUpP

/-! ## A regular opening with per-round errors -/

section OpeningP

variable {E κ μ G Cl : Type} [Field E] [Fintype E] [DecidableEq E]
  [Fintype κ] [DecidableEq κ] [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G]
variable {X : Type} {h : ℕ}

/-- The opening's round errors: the field term for `(λ, ρ)`, the column term for `J`. -/
noncomputable def opEr (A : ℕ) (βLR : ℝ≥0∞) (e nQ : ℕ) (βJ : ℝ≥0∞) : ℕ → ℝ≥0∞ :=
  fun i => if i = 0 then (A : ℝ≥0∞) / Fintype.card E * βLR
    else (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ

/-- **The opening is round-by-round sound with its per-round errors** (`FSOpening.lean`'s `opening_rbrWide`, each round
with its own term). -/
theorem opening_rbrR (enc : (μ → E) →ₗ[E] (Fin (2 ^ h) → E)) (henc : Function.Injective enc) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (clOf : X → OClaims Cl G κ μ E) (d₀ : Dg) (w0 w1 : ℕ) {nQ : ℕ}
    (chalLR : (Fin w0 → Dg) → (Cl → E) × (κ → E)) (chalJ : (Fin w1 → Dg) → (Fin nQ → Fin (2 ^ h)))
    (βLR βJ : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → E) × (κ → E) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → E) × (κ → E))).toOuterMeasure {y | Ev y} * βLR)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin w1 → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (Ux : X → κ → Fin (2 ^ h) → E) :
    ∀ x τ m, τ.length < 2 → ¬ opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x τ →
      (PMF.uniformOfFintype (Fin (opW w0 w1 τ.length) → Dg)).toOuterMeasure
          {b | opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x (τ ++ [(m, List.ofFn b)])}
        ≤ opEr (E := E) (h := h) A βLR e nQ βJ τ.length := by
  intro x τ m hτ hns
  have hE0 : opEr (E := E) (h := h) A βLR e nQ βJ 0 = (A : ℝ≥0∞) / Fintype.card E * βLR := by simp [opEr]
  have hE1 : opEr (E := E) (h := h) A βLR e nQ βJ 1
      = (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ := by
    simp [opEr]
  rcases τ with _ | ⟨⟨u, ds⟩, _ | ⟨e2, τ⟩⟩
  · rw [List.length_nil, hE0]
    rw [prob_ofFn_congr (show opW w0 w1 0 = w0 from rfl)
      (fun ds => opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([] ++ [(m, ds)]))]
    have hset : {b : Fin w0 → Dg | opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([] ++ [(m, List.ofFn b)])}
        = {b | (fun y : (Cl → E) × (κ → E) => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
            (clOf x).val y.1 y.2) (chalLR b)} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.nil_append, opSt, vecOf_ofFn]
    rw [hset]
    refine (hLR (fun y : (Cl → E) × (κ → E) => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
      (clOf x).val y.1 y.2)).trans ?_
    exact mul_le_mul' (opening_round0 enc hd h2 hA hca (Ux x) _ _ _ _ hns) le_rfl
  · rw [List.length_singleton, hE1]
    rw [prob_ofFn_congr (show opW w0 w1 1 = w1 from rfl)
      (fun ds' => opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([(u, ds)] ++ [(m, ds')]))]
    have hset : {b : Fin w1 → Dg | opSt enc e clOf d₀ w0 w1 chalLR chalJ (Ux x) x ([(u, ds)] ++ [(m, List.ofFn b)])}
        = {b | (fun J : Fin nQ → Fin (2 ^ h) => GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
            (clOf x).val (fun g _ _ => m.1 g) (fun _ _ => m.2) (chalLR (vecOf d₀ w0 ds)).1
            (chalLR (vecOf d₀ w0 ds)).2 J) (chalJ b)} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.cons_append, List.nil_append, opSt, vecOf_ofFn]
    rw [hset]
    refine (hJ (fun J : Fin nQ → Fin (2 ^ h) => GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
      (clOf x).val (fun g _ _ => m.1 g) (fun _ _ => m.2) (chalLR (vecOf d₀ w0 ds)).1
      (chalLR (vecOf d₀ w0 ds)).2 J)).trans ?_
    exact mul_le_mul' (opening_round1 enc henc hd h2 (Ux x) _ _ _ _ _ _ hns m.1 m.2 nQ) le_rfl
  · simp at hτ

/-- **A regular opening as a sub-protocol with per-round errors**, the code's derivations, for the matrix `Ux` the
statement names (soundness rounds), its messages read through `g`. -/
noncomputable def openingP {F : Type} [Field F] [Fintype F] [DecidableEq F] {M : Type} (p : ℕ) [NeZero p]
    (eF : ZMod p × ZMod p ≃ F) (hh : h ≤ 64) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F))
    (henc : Function.Injective enc) {dmin e A : ℕ} (hd : MinDist (LinearMap.range enc) dmin) (h2 : 2 * e < dmin)
    (hA : e + 1 ≤ A) (hca : CAOn Unit (LinearMap.range enc) e A)
    (clOf : X × List (M × List Dg) → OClaims Cl G κ μ F) {w0 m nQ : ℕ} (hnQ : nQ ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ)
    (Ux : X × List (M × List Dg) → κ → Fin (2 ^ h) → F) (g : M → OMsg G μ F) (d₀ : Dg)
    (pend : X → List (M × List Dg) → Prop) (post : X → List (M × List Dg) → Prop) : SubProtP X M Dg where
  n := 2
  w := opW w0 m
  hasMsg := opMsg
  er := opEr (E := F) (h := h) A ((1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)) e nQ 1
  St := fun y τ => opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux y) y (τ.map (fun e' => (g e'.1, e'.2)))
  pre := fun y τ _ => opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux y) y
    (τ.map (fun e' => (g e'.1, e'.2)))
  rbr := by
    intro y τ m' hτ hns
    have : Nonempty F := ⟨eF 0⟩
    have hl : (τ.map (fun e' : M × List Dg => (g e'.1, e'.2))).length = τ.length := List.length_map _
    have hr := opening_rbrR enc henc hd h2 hA hca clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) _ 1
      (lrCode_prob_le p eF eLR) (idxCode_prob_le hh hnQ) Ux y (τ.map (fun e' : M × List Dg => (g e'.1, e'.2)))
      (g m') (by rw [hl]; exact hτ) hns
    rw [hl] at hr
    have hset : {b : Fin (opW w0 m τ.length) → Dg | opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux y) y
        ((τ ++ [(m', List.ofFn b)]).map (fun e' : M × List Dg => (g e'.1, e'.2)))}
        = {b | opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux y) y
          (τ.map (fun e' : M × List Dg => (g e'.1, e'.2)) ++ [(g m', List.ofFn b)])} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.map_append, List.map_cons, List.map_nil]
    show (PMF.uniformOfFintype (Fin (opW w0 m τ.length) → Dg)).toOuterMeasure
      {b | opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux y) y
        ((τ ++ [(m', List.ofFn b)]).map (fun e' : M × List Dg => (g e'.1, e'.2)))} ≤ _
    rw [hset]
    exact hr
  pend := pend
  pendM := fun x τ _ => pend x τ
  post := post

end OpeningP

/-! ## The numbers -/

section Numbers

/-- **The zone budget** at the 8B T128 W16R2 parameters: `155/2^110 ≈ 2^-102.72`. -/
noncomputable def εZone8B : ℝ≥0∞ := ((155 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞)

/-- LogUp's total bound: `136/2^110` (the exact total is `2^-102.922`). -/
noncomputable def εLU8B : ℝ≥0∞ := ((136 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞)

/-- A regular opening's total bound at W16R2: `4/2^113 = 2^-111` (the exact total is `2^-112.39`). -/
noncomputable def εOp8B : ℝ≥0∞ := ((4 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞)

/-- `M`'s assumed total, `2^-106`. -/
noncomputable def εMask8B : ℝ≥0∞ := (2⁻¹ : ℝ≥0∞) ^ 106

/-- A small sub-protocol's bound, `2a/p²`. -/
noncomputable def εSmall8B (a : ℕ) : ℝ≥0∞ := ((2 * a : ℕ) : ℝ≥0∞) / ((goldP ^ 2 : ℕ) : ℝ≥0∞)

/-- **LogUp's total at the 8B parameters**: `(N_lk + 4·T_d − 1)/p²·(1 + p/2^128)^4 ≤ 136/2^110`. -/
theorem luTot_8B_le {F : Type} [Field F] [Fintype F] [DecidableEq F] {ι π κ : Type} [Fintype ι] [Fintype π]
    [Fintype κ] (T : κ → Tup F) (hF : Fintype.card F = goldP ^ 2)
    (hN : Fintype.card ι + 2 * Fintype.card π = 34897920) (hM : (univ.image T).card = 127668) :
    luFoldE (F := F) goldP T + luEps (ι := ι) (π := π) goldP T ≤ εLU8B := by
  rw [luFoldE, luEps, ← add_mul, ENNReal.div_add_div_same, ← Nat.cast_add, hN, hM, hF,
    one_add_div_eq goldP (2 ^ 128) (by norm_num), natCast_div_pow, natCast_div_mul_div]
  exact natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])

/-- The fold round's error is at most the `α` round's. -/
theorem luFoldE_le {F : Type} [Field F] [Fintype F] [DecidableEq F] {ι π κ : Type} [Fintype ι] [Fintype π]
    [Fintype κ] (T : κ → Tup F) (p : ℕ) (hN : 1 ≤ Fintype.card ι + 2 * Fintype.card π) :
    luFoldE (F := F) p T ≤ luEps (ι := ι) (π := π) p T := by
  unfold luFoldE luEps
  gcongr
  omega

/-- **The opening's total at W16R2**: field term `≤ 3/2^113`, column term `≤ 1/2^113`. -/
theorem opTot_W16R2_le {F : Type} [Fintype F] (hF : Fintype.card F = goldP ^ 2) {A w0 : ℕ}
    (hA : A ≤ 2 ^ 15) (hw0 : w0 ≤ 2 ^ 40) :
    (A : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      + ((((Fintype.card (Fin (2 ^ 15)) - (8052 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 15))) ^ 280 * 1)
      ≤ εOp8B := by
  have hfield : (A : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((3 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞) := by
    have hk : 2 * w0 ≤ 2 ^ 62 := (Nat.mul_le_mul_left 2 hw0).trans (by norm_num)
    have hb := fp2_bias_pow_le_two (p := goldP) (by norm_num [goldP]) hk
    calc (A : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
        ≤ ((2 ^ 15 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
          rw [hF]
          exact mul_le_mul' (ENNReal.div_le_div_right (by exact_mod_cast hA) _) (by exact_mod_cast hb)
      _ = ((2 ^ 15 * 2 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
          rw [← natCast_div_mul_div, Nat.cast_one, div_one]
      _ ≤ ((3 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞) :=
          natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])
  have hcol : ((((Fintype.card (Fin (2 ^ 15)) - (8052 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 15))) ^ 280 * 1)
      ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞) := by
    rw [mul_one, Fintype.card_fin, natCast_div_pow]
    refine natCast_div_le_div (by positivity) (by norm_num) ?_
    rw [show (280 : ℕ) = 140 * 2 from rfl, pow_mul, pow_mul]
    norm_num
  calc _ ≤ ((3 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞) + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 113 : ℕ) : ℝ≥0∞) :=
        add_le_add hfield hcol
    _ = εOp8B := by rw [ENNReal.div_add_div_same, ← Nat.cast_add]; rfl

/-- `M`'s assumed total is under the rate. -/
theorem εMask8B_le_rate : εMask8B ≤ εRate8B := mask_eps_le

/-- **The zone budget adds up**: one LogUp, one `M`, four regular openings and small numerators summing to at most
`2^16`: `136/2^110 + 2^-106 + 4·2^-111 + 2^17/p² ≤ 155/2^110`. -/
theorem zone_sum_le (a : ℕ) (ha : a ≤ 2 ^ 16) :
    εLU8B + εMask8B + 4 * εOp8B + εSmall8B a ≤ εZone8B := by
  have h1 : εMask8B = ((16 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
    rw [εMask8B, inv_two_pow_eq]
    rw [show ((16 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) = ((1 * 16 : ℕ) : ℝ≥0∞) / ((2 ^ 106 * 16 : ℕ) : ℝ≥0∞) by
      norm_num]
    rw [← natCast_div_mul_div, ENNReal.div_self (by norm_num) (by simp), mul_one]
  have h2 : 4 * εOp8B = ((2 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
    rw [εOp8B, show (4 : ℝ≥0∞) = ((4 : ℕ) : ℝ≥0∞) / ((1 : ℕ) : ℝ≥0∞) by simp, natCast_div_mul_div]
    rw [show ((2 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) = ((2 * 8 : ℕ) : ℝ≥0∞) / ((2 ^ 110 * 8 : ℕ) : ℝ≥0∞) by
      rw [← natCast_div_mul_div, ENNReal.div_self (by norm_num) (by simp), mul_one]]
    norm_num
  have h3 : εSmall8B a ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
    rw [εSmall8B]
    refine natCast_div_le_div (by norm_num [goldP]) (by norm_num) ?_
    calc 2 * a * 2 ^ 110 ≤ 2 * 2 ^ 16 * 2 ^ 110 := by gcongr
      _ ≤ 1 * goldP ^ 2 := by norm_num [goldP]
  rw [εLU8B, h1, h2, εZone8B]
  calc ((136 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) + ((16 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞)
        + ((2 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) + εSmall8B a
      ≤ ((136 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) + ((16 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞)
        + ((2 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
        gcongr
    _ = ((155 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same, ENNReal.div_add_div_same]
        norm_num

/-- The two chain terms over 256-bit digests stay under `129/2^110` while `T ≤ 2^76`. -/
theorem collBound_pair_le_129 {T : ℕ} (hT : T ≤ 2 ^ 76) :
    collBound T Dg + collBound (T + 1) Dg ≤ ((129 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞) := by
  unfold collBound
  rw [ENNReal.div_add_div_same, ← Nat.cast_add, show Fintype.card Dg = 2 ^ 128 * 2 ^ 128 by simp [Dg]]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  have h1 : T * (T - 1) / 2 ≤ 2 ^ 76 * 2 ^ 76 :=
    (Nat.div_le_self _ _).trans (Nat.mul_le_mul hT ((Nat.sub_le T 1).trans hT))
  have h2 : (T + 1) * (T + 1 - 1) / 2 ≤ (2 ^ 76 + 1) * 2 ^ 76 :=
    (Nat.div_le_self _ _).trans (Nat.mul_le_mul (Nat.add_le_add_right hT 1) (by rw [Nat.add_sub_cancel]; exact hT))
  calc (T * (T - 1) / 2 + (T + 1) * (T + 1 - 1) / 2) * 2 ^ 110
      ≤ (2 ^ 76 * 2 ^ 76 + (2 ^ 76 + 1) * 2 ^ 76) * 2 ^ 110 := by gcongr
    _ ≤ 129 * (2 ^ 128 * 2 ^ 128) := by norm_num

/-- **The bound in the approved target's form, for every `q ≤ 2^75`**:
`q·εRate8B + εZone8B + collBound T + collBound (T + 1) ≤ q·2^-100 + 2^-100` when `T ≤ 2^76`. -/
theorem path_le_target {q T : ℕ} (hT : T ≤ 2 ^ 76) :
    (q : ℝ≥0∞) * εRate8B + εZone8B + collBound T Dg + collBound (T + 1) Dg ≤ εsTarget q := by
  rw [εsTarget, add_assoc, add_assoc]
  refine add_le_add ?_ ?_
  · refine mul_le_mul' le_rfl ?_
    rw [εRate8B, inv_two_pow_eq]
    exact natCast_div_le_div (by norm_num) (by norm_num) (by norm_num)
  · refine (add_le_add le_rfl (collBound_pair_le_129 hT)).trans ?_
    rw [εZone8B, ENNReal.div_add_div_same, ← Nat.cast_add, inv_two_pow_eq]
    exact natCast_div_le_div (by norm_num) (by norm_num) (by norm_num)

end Numbers

/-! ## The run's sub-protocols with per-round errors, at the 8B parameters -/

section Kinds

variable {X M : Type}

/-- **What a sub-protocol contributes to a zone**: LogUp, `M`, a regular opening, or a small sub-protocol with
numerator `a`. -/
inductive Tag8B where
  | lu
  | mask
  | op
  | small (a : ℕ)
  deriving DecidableEq

/-- A tag's total bound. -/
noncomputable def tagBound : Tag8B → ℝ≥0∞
  | .lu => εLU8B
  | .mask => εMask8B
  | .op => εOp8B
  | .small a => εSmall8B a

/-- A tag's small numerator (`0` for the others). -/
def smallNum : Tag8B → ℕ
  | .small a => a
  | _ => 0

/-- **The sub-protocols of a run at the 8B T128 W16R2 parameters, with per-round errors**, each with its tag. -/
inductive Kind8BP : Tag8B → SubProtP X M Dg → Prop
  | logup {F ι π κ : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype ι] [Fintype π] [Fintype κ]
      (eF : ZMod goldP × ZMod goldP ≃ F) (T : κ → Tup F)
      (lu : X × List (M × List Dg) → M → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F))
      (pend : X → List (M × List Dg) → Prop) (pendM : X → List (M × List Dg) → M → Prop)
      (post : X → List (M × List Dg) → Prop)
      (hN : Fintype.card ι + 2 * Fintype.card π = 34897920) (hM : (univ.image T).card = 127668) :
      Kind8BP .lu (logupP goldP eF T lu pend pendM post)
  | opening {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
      [Fintype Cl] [DecidableEq Cl] [DecidableEq G] (eF : ZMod goldP × ZMod goldP ≃ F) (hh : 15 ≤ 64)
      (enc : (μ → F) →ₗ[F] (Fin (2 ^ 15) → F)) (henc : Function.Injective enc) {dmin A : ℕ}
      (hd : MinDist (LinearMap.range enc) dmin) (h2 : 2 * 8052 < dmin) (hA : 8052 + 1 ≤ A)
      (hca : CAOn Unit (LinearMap.range enc) 8052 A) (clOf : X × List (M × List Dg) → OClaims Cl G κ μ F)
      {w0 m : ℕ} (hnQ : 280 ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ) (Ux : X × List (M × List Dg) → κ → Fin (2 ^ 15) → F)
      (g : M → OMsg G μ F) (d₀ : Dg) (pend post : X → List (M × List Dg) → Prop)
      (hA15 : A ≤ 2 ^ 15) (hw0 : w0 ≤ 2 ^ 40) (hw00 : 0 < w0) (hm : 0 < m) :
      Kind8BP .op (openingP goldP eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post)
  | sumcheck {F : Type} [Field F] [Fintype F] [DecidableEq F] {d n : ℕ} (hd : d < ringChar F)
      (eF : ZMod goldP × ZMod goldP ≃ F) (stmt : X × List (M × List Dg) → ((Fin n → F) → F) × F)
      (g : M → (Fin (d + 1) → F)) (d₀ : Dg) (pend post : X → List (M × List Dg) → Prop) (hd20 : d ≤ 2 ^ 20) :
      Kind8BP (.small (n * d)) (sumcheckSP goldP hd eF stmt g d₀ pend post).toP
  | mle {F : Type} [Field F] [Fintype F] [DecidableEq F] {ℓ : ℕ} (eF : ZMod goldP × ZMod goldP ≃ F)
      (P : X × List (M × List Dg) → (Fin ℓ → Bool) → F) (d₀ : Dg) (msg : Bool)
      (pend post : X → List (M × List Dg) → Prop) (hℓ0 : 0 < ℓ) (hℓ : ℓ ≤ 2 ^ 20) :
      Kind8BP (.small ℓ) (mleSP goldP eF P d₀ msg pend post).toP
  | batch {F : Type} [Field F] [Fintype F] [DecidableEq F] {k : ℕ} {β : Type} (eF : ZMod goldP × ZMod goldP ≃ F)
      (R : X × List (M × List Dg) → Fin k → β → F) (d₀ : Dg) (msg : Bool)
      (pend post : X → List (M × List Dg) → Prop) (hk0 : 0 < k) (hk : k ≤ 2 ^ 40) :
      Kind8BP (.small 1) (batchSP goldP eF R d₀ msg pend post).toP
  | free (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (P : X × List (M × List Dg) → Prop)
      (pend post : X → List (M × List Dg) → Prop) (hw : ∀ i, 0 < w i) :
      Kind8BP (.small 0) (freeSP n w hasMsg P pend post).toP
  | mask (c : SubProtP X M Dg) (hw : ∀ i, 0 < c.w i) (htot : c.tot ≤ εMask8B) : Kind8BP .mask c
  | rest (c : SubProtP X M Dg) (hw : ∀ i, 0 < c.w i) (hn : c.n = 0) : Kind8BP (.small 0) c

/-- A round's error is at most its sub-protocol's total. -/
theorem SubProtP.er_le_tot {D : Type} [Fintype D] [Nonempty D] (c : SubProtP X M D) (i : ℕ) (hi : i < c.n) :
    c.er i ≤ c.tot :=
  Finset.single_le_sum (f := c.er) (fun _ _ => zero_le) (mem_range.mpr hi)

/-- **Every round's error is at most `εRate8B`**: the per-query rate is unchanged. -/
theorem Kind8BP.er_le {t : Tag8B} {c : SubProtP X M Dg} (h : Kind8BP t c) (i : ℕ) (hi : i < c.n) :
    c.er i ≤ εRate8B := by
  cases h with
  | logup eF T lu pend pendM post hN hM =>
    have hLU : luEps (ι := _) (π := _) goldP T ≤ εRate8B := luEps_8B_le T (card_eq_of_equiv eF) hN hM
    show luEr goldP T i ≤ εRate8B
    unfold luEr
    split_ifs
    · exact (luFoldE_le T goldP (by omega)).trans hLU
    · exact hLU
  | opening eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post hA15 hw0 hw00 hm =>
    have hb := opening_eps_W16R2_le (card_eq_of_equiv eF) hA15 hw0
    show opEr _ _ _ _ _ i ≤ εRate8B
    unfold opEr
    split_ifs
    · exact (le_max_left _ _).trans hb
    · exact (le_max_right _ _).trans hb
  | sumcheck hd eF stmt g d₀ pend post hd20 =>
    exact (Kind8B.sumcheck hd eF stmt g d₀ pend post hd20).eps_le
  | mle eF P d₀ msg pend post hℓ0 hℓ => exact (Kind8B.mle eF P d₀ msg pend post hℓ0 hℓ).eps_le
  | batch eF R d₀ msg pend post hk0 hk => exact (Kind8B.batch eF R d₀ msg pend post hk0 hk).eps_le
  | free n w hasMsg P pend post hw => exact (Kind8B.free n w hasMsg P pend post hw).eps_le
  | mask c hw htot => exact ((c.er_le_tot i hi).trans htot).trans εMask8B_le_rate
  | rest c hw hn => exact absurd hi (by omega)

/-- Every round squeezes at least once. -/
theorem Kind8BP.w_pos {t : Tag8B} {c : SubProtP X M Dg} (h : Kind8BP t c) : ∀ i, 0 < c.w i := by
  cases h with
  | logup eF T lu pend pendM post hN hM => exact luW_pos
  | opening eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post hA15 hw0 hw00 hm => exact opW_pos hw00 hm
  | sumcheck hd eF stmt g d₀ pend post hd20 => exact fun _ => one_pos
  | mle eF P d₀ msg pend post hℓ0 hℓ => exact fun _ => hℓ0
  | batch eF R d₀ msg pend post hk0 hk => exact fun _ => hk0
  | free n w hasMsg P pend post hw => exact hw
  | mask c hw htot => exact hw
  | rest c hw hn => exact hw

/-- A small sub-protocol's per-round error, `x/|F|·bias`, is at most `2x/p²`. -/
theorem small_le_two {F : Type} [Fintype F] (hF : Fintype.card F = goldP ^ 2) {a k : ℕ} (hk : k ≤ 2 ^ 62) :
    (a : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k ≤ εSmall8B a := by
  calc (a : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k
      ≤ (a : ℝ≥0∞) / ((goldP ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl (by exact_mod_cast fp2_bias_pow_le_two (by norm_num [goldP]) hk)
    _ = εSmall8B a := by
        rw [εSmall8B, show ((2 : ℕ) : ℝ≥0∞) = ((2 : ℕ) : ℝ≥0∞) / ((1 : ℕ) : ℝ≥0∞) by simp,
          natCast_div_mul_div, mul_one, mul_comm a 2]

/-- **Each sub-protocol's total is at most its tag's bound.** -/
theorem Kind8BP.tot_le {t : Tag8B} {c : SubProtP X M Dg} (h : Kind8BP t c) : c.tot ≤ tagBound t := by
  cases h with
  | logup eF T lu pend pendM post hN hM =>
    show ∑ i ∈ range 2, luEr goldP T i ≤ εLU8B
    rw [Finset.sum_range_succ, Finset.sum_range_one]
    simp only [luEr, ↓reduceIte, one_ne_zero]
    exact luTot_8B_le T (card_eq_of_equiv eF) hN hM
  | opening eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post hA15 hw0 hw00 hm =>
    show ∑ i ∈ range 2, opEr _ _ _ _ _ i ≤ εOp8B
    rw [Finset.sum_range_succ, Finset.sum_range_one]
    simp only [opEr, ↓reduceIte, one_ne_zero]
    exact opTot_W16R2_le (card_eq_of_equiv eF) hA15 hw0
  | @sumcheck F _ _ _ d n hd eF stmt g d₀ pend post hd20 =>
    rw [SubProt.toP_tot]
    show (n : ℝ≥0∞) * ((d : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
      ≤ εSmall8B (n * d)
    refine (mul_le_mul' le_rfl (small_le_two (card_eq_of_equiv eF) (by norm_num))).trans (le_of_eq ?_)
    rw [εSmall8B, εSmall8B, ← mul_div_assoc, show (n : ℝ≥0∞) * ((2 * d : ℕ) : ℝ≥0∞) = ((2 * (n * d) : ℕ) : ℝ≥0∞) by
      push_cast; ring]
  | @mle F _ _ _ ℓ eF P d₀ msg pend post hℓ0 hℓ =>
    rw [SubProt.toP_tot]
    show ((1 : ℕ) : ℝ≥0∞) * ((ℓ : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * ℓ))
      ≤ εSmall8B ℓ
    rw [Nat.cast_one, one_mul]
    exact small_le_two (card_eq_of_equiv eF) ((Nat.mul_le_mul_left 2 hℓ).trans (by norm_num))
  | @batch F _ _ _ k β eF R d₀ msg pend post hk0 hk =>
    rw [SubProt.toP_tot]
    show ((1 : ℕ) : ℝ≥0∞) * ((1 : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * k))
      ≤ εSmall8B 1
    rw [Nat.cast_one, one_mul]
    have h1 := small_le_two (a := 1) (card_eq_of_equiv eF) ((Nat.mul_le_mul_left 2 hk).trans (by norm_num))
    rw [Nat.cast_one] at h1
    exact h1
  | free n w hasMsg P pend post hw =>
    rw [SubProt.toP_tot]
    show (n : ℝ≥0∞) * 0 ≤ εSmall8B 0
    rw [mul_zero]
    exact zero_le
  | mask c hw htot => exact htot
  | rest c hw hn =>
    show c.tot ≤ εSmall8B 0
    rw [SubProtP.tot, hn, Finset.sum_range_zero]
    exact zero_le

/-- **A block zone**: at most one LogUp, at most one `M`, at most four regular openings (`A`, `H`, and the two
boundary openings of a D12a stage), and small sub-protocols whose numerators sum to at most `2^16`. -/
def BlockZone8B (tag : ℕ → Tag8B) (Zb : Finset ℕ) : Prop :=
  (Zb.filter (fun k => tag k = .lu)).card ≤ 1 ∧ (Zb.filter (fun k => tag k = .mask)).card ≤ 1
    ∧ (Zb.filter (fun k => tag k = .op)).card ≤ 4 ∧ ∑ k ∈ Zb, smallNum (tag k) ≤ 2 ^ 16

/-- A tag's bound, split by kind. -/
theorem tagBound_split (t : Tag8B) :
    tagBound t = (if t = .lu then εLU8B else 0) + (if t = .mask then εMask8B else 0)
      + (if t = .op then εOp8B else 0) + εSmall8B (smallNum t) := by
  cases t <;> simp [tagBound, smallNum, εSmall8B]

/-- `2a/p²` adds up over a set. -/
theorem sum_εSmall8B (Zb : Finset ℕ) (f : ℕ → ℕ) : ∑ k ∈ Zb, εSmall8B (f k) = εSmall8B (∑ k ∈ Zb, f k) := by
  simp only [εSmall8B, div_eq_mul_inv, ← sum_mul, Finset.mul_sum, Nat.cast_sum, Nat.cast_mul]

/-- **A block zone's totals add up to at most `εZone8B`.** -/
theorem zone_budget_le (tag : ℕ → Tag8B) (Zb : Finset ℕ) (h : BlockZone8B tag Zb) :
    ∑ k ∈ Zb, tagBound (tag k) ≤ εZone8B := by
  obtain ⟨hlu, hmk, hop, hsm⟩ := h
  have hcnt : ∀ (P : ℕ → Prop) [DecidablePred P] (c : ℝ≥0∞) (b : ℕ), (Zb.filter P).card ≤ b →
      ∑ k ∈ Zb, (if P k then c else 0) ≤ b * c := by
    intro P _ c b hb
    rw [← Finset.sum_filter, sum_const, nsmul_eq_mul]
    exact mul_le_mul' (by exact_mod_cast hb) le_rfl
  simp only [tagBound_split, sum_add_distrib]
  refine le_trans ?_ (zone_sum_le _ hsm)
  rw [sum_εSmall8B]
  refine add_le_add (add_le_add (add_le_add ?_ ?_) ?_) le_rfl
  · simpa using hcnt (fun k => tag k = .lu) εLU8B 1 hlu
  · simpa using hcnt (fun k => tag k = .mask) εMask8B 1 hmk
  · simpa using hcnt (fun k => tag k = .op) εOp8B 4 hop

end Kinds

/-! ## The run on the chain -/

section Run

variable {X M Q : Type} [Fintype Q] [DecidableEq Q]

omit [Fintype Q] [DecidableEq Q] in
/-- A schedule of tagged sub-protocols squeezes at least once per round. -/
theorem kinds8B_w_pos (cs : List (SubProtP X M Dg)) (tag : ℕ → Tag8B)
    (hk : ∀ k c, cs[k]? = some c → Kind8BP (tag k) c) : ∀ c ∈ cs, ∀ i, 0 < c.w i := by
  intro c hc
  obtain ⟨k, hkc⟩ := List.getElem?_of_mem hc
  exact (hk k c hkc).w_pos

/-- **A run at the 8B T128 W16R2 parameters, path-wise.** The run is any schedule of the tagged sub-protocols on one
chain (`hk`), with zones that meet `FSPath.lean`'s premises, a false statement dooming the starting zone, and the
verifier rejecting a doom in the final zone. If along every transcript the charged rounds belong to one block zone
(`hpath`), a prover making at most `q` hash queries gets a false statement accepted with probability at most
`q·εRate8B + εZone8B + collBound T + collBound (T + 1)`, `T = q + ℓW + 1`. -/
theorem fs_path_run_8B (cs : List (SubProtP X M Dg)) (tag : ℕ → Tag8B)
    (hk : ∀ k c, cs[k]? = some c → Kind8BP (tag k) c) {m₀ : M} (C : ChainEnc (PItem X M) Q Dg) {Mf : Type}
    {L : X → Prop} {accept : X → List (M × List Dg) → Mf → Prop}
    (zone₀ : X → Finset ℕ) (zone : X → List (M × List Dg) → M → Finset ℕ)
    (hhand : ∀ x τ m, τ.length < nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ∃ j ∈ zone x τ m, ¬ POfP cs j x τ m)
    (hframe : ∀ j x τ m (b : Fin (wOfP cs τ.length) → Dg), τ.length < nOfP cs → ownOfP cs τ.length ≠ j →
      j ∈ zone x τ m → ¬ POfP cs j x τ m → SOfP cs j x (τ ++ [(m, List.ofFn b)]) →
        ∃ j' ∈ zone x τ m, j < j' ∧ ¬ POfP cs j' x τ m)
    (hpath : ∀ x (τ : List (M × List Dg)), τ.length ≤ nOfP cs → ∃ Zb : Finset ℕ,
      (∀ i (hi : i < τ.length), ownOfP cs i ∈ zone x (τ.take i) (τ[i]).1 → ownOfP cs i ∈ Zb)
      ∧ BlockZone8B tag Zb)
    (hstart : ∀ x, ¬ L x → ∃ j ∈ zone₀ x, ¬ SOfP cs j x [])
    (hfinal : ∀ x τ mf, τ.length = nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ¬ accept x τ mf)
    (q : ℕ) (A : OC Q Dg (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOfP cs) (wOfP cs)
          (wOfP_pos cs (kinds8B_w_pos cs tag hk)) (msgOfP cs) m₀ accept C H (A.run H).1 (A.run H).2.1
          (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * εRate8B + εZone8B + collBound (q + ℓW (nOfP cs) (wOfP cs) + 1) Dg
        + collBound (q + ℓW (nOfP cs) (wOfP cs) + 1 + 1) Dg := by
  classical
  refine fs_chain_sound_schedP_path cs (kinds8B_w_pos cs tag hk) C zone₀ zone hhand hframe εRate8B
    (fun c hc i hi => by
      obtain ⟨k, hkc⟩ := List.getElem?_of_mem hc
      exact (hk k c hkc).er_le i hi) εZone8B (fun x τ hτ => ?_) hstart hfinal q A hA
  obtain ⟨Zb, hZ, hzone⟩ := hpath x τ hτ
  refine ⟨Zb, hZ, ?_⟩
  have htot : ∀ k, totAtP cs k ≤ tagBound (tag k) := by
    intro k
    unfold totAtP
    rcases hck : cs[k]? with _ | c
    · exact zero_le
    · exact (hk k c hck).tot_le
  calc ∑ k ∈ range cs.length, (if k ∈ Zb then totAtP cs k else 0)
      = ∑ k ∈ (range cs.length).filter (· ∈ Zb), totAtP cs k := (Finset.sum_filter _ _).symm
    _ ≤ ∑ k ∈ Zb, totAtP cs k :=
        Finset.sum_le_sum_of_subset (fun k hk' => (mem_filter.mp hk').2)
    _ ≤ ∑ k ∈ Zb, tagBound (tag k) := sum_le_sum (fun k _ => htot k)
    _ ≤ εZone8B := zone_budget_le tag Zb hzone

/-- **The run in the approved target's form, for every `q ≤ 2^75`.** Under the premises of `fs_path_run_8B` and
`ℓW + 1 ≤ 2^75`, a prover making at most `q` hash queries gets a false statement accepted with probability at most
`εsTarget q = q·2^-100 + 2^-100`. The verifier's own hash positions no longer count as attempts at the largest error:
the query-free part is `εZone8B + collision terms ≤ 284/2^110 ≈ 2^-101.85`. -/
theorem fs_path_run_8B_target (cs : List (SubProtP X M Dg)) (tag : ℕ → Tag8B)
    (hk : ∀ k c, cs[k]? = some c → Kind8BP (tag k) c) {m₀ : M} (C : ChainEnc (PItem X M) Q Dg) {Mf : Type}
    {L : X → Prop} {accept : X → List (M × List Dg) → Mf → Prop}
    (zone₀ : X → Finset ℕ) (zone : X → List (M × List Dg) → M → Finset ℕ)
    (hhand : ∀ x τ m, τ.length < nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ∃ j ∈ zone x τ m, ¬ POfP cs j x τ m)
    (hframe : ∀ j x τ m (b : Fin (wOfP cs τ.length) → Dg), τ.length < nOfP cs → ownOfP cs τ.length ≠ j →
      j ∈ zone x τ m → ¬ POfP cs j x τ m → SOfP cs j x (τ ++ [(m, List.ofFn b)]) →
        ∃ j' ∈ zone x τ m, j < j' ∧ ¬ POfP cs j' x τ m)
    (hpath : ∀ x (τ : List (M × List Dg)), τ.length ≤ nOfP cs → ∃ Zb : Finset ℕ,
      (∀ i (hi : i < τ.length), ownOfP cs i ∈ zone x (τ.take i) (τ[i]).1 → ownOfP cs i ∈ Zb)
      ∧ BlockZone8B tag Zb)
    (hstart : ∀ x, ¬ L x → ∃ j ∈ zone₀ x, ¬ SOfP cs j x [])
    (hfinal : ∀ x τ mf, τ.length = nOfP cs → (∃ j ∈ lastZone zone₀ zone x τ, ¬ SOfP cs j x τ) →
      ¬ accept x τ mf)
    (hℓ : ℓW (nOfP cs) (wOfP cs) + 1 ≤ 2 ^ 75)
    (q : ℕ) (hq : q ≤ 2 ^ 75) (A : OC Q Dg (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOfP cs) (wOfP cs)
          (wOfP_pos cs (kinds8B_w_pos cs tag hk)) (msgOfP cs) m₀ accept C H (A.run H).1 (A.run H).2.1
          (A.run H).2.2)
      ≤ εsTarget q :=
  (fs_path_run_8B cs tag hk C zone₀ zone hhand hframe hpath hstart hfinal q A hA).trans
    (path_le_target (by rw [show (2 : ℕ) ^ 76 = 2 ^ 75 + 2 ^ 75 by norm_num]; omega))

end Run

/-! ## A worked instance of the sharper count, every premise proved -/

section ZeroCheckSum

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {d n : ℕ} {X : Type}
variable (p : ℕ) [NeZero p] (hd : d + 1 < ringChar F) (ι : ZMod p × ZMod p ≃ F) (R : X → (Fin n → F) → F)
  (d₀ : Dg)
variable {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The zero-check on the code's chain, with the sharper count.** `FSComposeZeroCheck.lean`'s
`fs_zerocheck_chain_sound` charges the verifier's own hash positions at the larger round error; charged each at its own
round's error, the query-free part is the interactive bound itself: one `τ` round and `n` sumcheck rounds,
`n/|F|·bias + n·(d + 1)/|F|·bias` (`SoundZeroCheck.lean`'s `zerocheck_sound`, `(n + n·(d + 1))/|F|`, times the
derivation's bias). The per-query rate stays the maximum. Every premise is proved. -/
theorem fs_zerocheck_chain_sound_sum (hR : ∀ x, IndDegLE d (R x)) (hn : 0 < n) {m₀ : Fin (d + 2) → F}
    (C : ChainEnc (PItem X (Fin (d + 2) → F)) Q Dg) (q : ℕ)
    (A : OC Q Dg (X × List (Fin (d + 2) → F) × Unit)) (hA : A.Bounded q) :
    prH (fun H => ¬ (∀ b : Fin n → Bool, R (A.run H).1 (fun i => bit (b i)) = 0)
        ∧ chainAcceptsW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀))
          (wOf_pos _ (zc_wpos p hd ι R d₀ hn))
          (msgOf (zcSched p hd ι R d₀)) m₀ (zcAccept (d := d) p ι R d₀) C H (A.run H).1 (A.run H).2.1
          (A.run H).2.2)
      ≤ (q : ℝ≥0∞) * max ((n : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * n))
            (((d + 1 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
        + ((n : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * n)
          + (n : ℝ≥0∞) * (((d + 1 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2))
        + collBound (q + ℓW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀)) + 1) Dg
        + collBound (q + ℓW (nOf (zcSched p hd ι R d₀)) (wOf (zcSched p hd ι R d₀)) + 1 + 1) Dg := by
  have h := fs_chain_sound_sched_sum (m₀ := m₀) (zcSched p hd ι R d₀) (zc_wpos p hd ι R d₀ hn) C
    (L := fun x => ∀ b : Fin n → Bool, R x (fun i => bit (b i)) = 0)
    (max ((n : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * n))
      (((d + 1 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)) (by
      intro c hc
      simp only [zcSched, List.mem_cons, List.not_mem_nil, or_false] at hc
      rcases hc with rfl | rfl
      · exact le_max_left _ _
      · exact le_max_right _ _) (zc_frame p hd ι R d₀ hR)
    (fun x hx => zc_start p hd ι R d₀ x hx) (zc_final p hd ι R d₀ hR) q A hA
  refine h.trans (le_of_eq ?_)
  simp only [zcSched, zcC0, zcC1, mleSP, sumcheckSP, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
    Nat.cast_one, one_mul, add_zero]

end ZeroCheckSum

end ZK60.Sound
