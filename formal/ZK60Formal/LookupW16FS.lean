/-
D63 lane L21 (2026-11-07), part 3: **LogUp under Fiat–Shamir on the block's real schedule, over the lookups EXTRACTED
from the prover's log** (the probabilistic half of `block_knowledge`'s `hLk`).

`verify_core` absorbs the `A` root (the lookups and the multiplicities are `A` planes) and `M`'s, then squeezes
`β = challenge_fp2()`, `γ = challenge_fp2()`, `α = challenge_fp2()` with no absorb between (`ExecBlockFS.rootOps`), then
absorbs `H` (the helpers). `FSLogUp.lean` reads `(β, γ)` as ONE round of width 2, which on the code's chain needs a width
function `W` at `β`'s squeeze counter, and that counter depends on the header (L16-2). Here the three squeezes are THREE
rounds of width one (`W1`), so no counter premise is needed:

* `foldB`, `lkSt3`: LogUp's state round by round: before `β` "every looked-up tuple is a table tuple"; after `β` "every
  tuple outside the table agrees in tag and in its `β`-part with some table tuple"; after `γ` "every folded tuple is a
  folded table tuple"; after `α` "some helpers pass every relation and the sum claim" (`HelperRel`);
* `lk_round_beta`, `lk_round_gamma`, `lk_round_alpha`, **`lkSt3_rbr`**: the escape counts `2M`, `M`, `N + 2M − 1`
  (`M` the distinct table tuples, `N` the lookups); one count `N + 2M` for all three;
* `lkSq`: LogUp as a squeeze-run sub-protocol at entry `hdrLen + 4`, its lookups and multiplicities read off the
  prover's log cut at the `A` root's first absorption (the header shows the root);
* **`block_logup_fs_knowledge`**: for ANY block shape, any lookup list and table, a prover making `q` queries gets the
  slots accepted while some extracted looked-up tuple is NOT a table tuple and yet some helpers pass every relation at
  the transcript's `β, γ, α`, with probability at most `T·(N + 2M)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`,
  `T = q + hdrLen + 11` (the chain up to the `H` root);
* **`lk_of_logup`**: `block_knowledge`'s `hLk` from it: the slots accept and LogUp's conclusion (`W16Lookups`) fails on
  the extracted planes with probability at most `εhelp + ` that bound, given the bridge from `W16Lookups` to the lookup
  list (`hlook`: a failing lookup is a tuple outside the table; L11's `word16_of_lk`… read backwards) and `εhelp`, the
  probability that the slots accept while the EXTRACTED helpers fail a relation or the sum claim (the zero-checks'
  helper clauses and `H`'s sum row: the same composition as `hRel` and `hOpen`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Chain
import ZK60Formal.SoundLogUpBlock

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Polynomial
open Finset (univ mem_image mem_image_of_mem mem_univ card_biUnion_le sum_le_sum mem_biUnion sum_const card_image_le
  image_image mem_filter)

/-! ## LogUp's three rounds of width one -/

section Rounds

variable {K : Type} [Field K] [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

/-- A tuple's fold without its tag term: `x + β·y + β²·z`. -/
def foldB (β : K) (u : Tup K) : K := u.x + β * u.y + β ^ 2 * u.z

omit [DecidableEq K] in
theorem fold_eq_foldB (β γ : K) (u : Tup K) : fold β γ u = foldB β u + γ * u.tag := by
  unfold fold foldB
  ring

/-- **LogUp's state, round by round** (the messages are ignored). -/
def lkSt3 (A : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (m : κ → K) : List (List UInt8 × K) → Prop
  | [] => ∀ l, ∃ j, T j = A l
  | [(_, β)] => ∀ l, (∀ j, T j ≠ A l) → ∃ j, (T j).tag = (A l).tag ∧ foldB β (T j) = foldB β (A l)
  | [(_, β), (_, γ)] => ∀ l, ∃ j, fold β γ (T j) = fold β γ (A l)
  | [(_, β), (_, γ), (_, α)] => ∃ H, HelperRel (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m α H
  | _ => True

/-- The difference of two tuples' `β`-parts as a polynomial in `β` (degree `≤ 2`). -/
noncomputable def lkQ (a τ : Tup K) : K[X] := C (τ.z - a.z) * X ^ 2 + C (τ.y - a.y) * X + C (τ.x - a.x)

omit [DecidableEq K] in
theorem lkQ_natDegree (a τ : Tup K) : (lkQ a τ).natDegree ≤ 2 := by
  unfold lkQ
  compute_degree

omit [DecidableEq K] in
theorem lkQ_eval (a τ : Tup K) (β : K) : (lkQ a τ).eval β = foldB β τ - foldB β a := by
  simp only [lkQ, foldB, eval_add, eval_mul, eval_C, eval_pow, eval_X]
  ring

omit [DecidableEq K] in
/-- Two tuples of the same tag with the same `β`-polynomial are equal. -/
theorem lkQ_ne_zero (a τ : Tup K) (ht : τ.tag = a.tag) (hne : τ ≠ a) : lkQ a τ ≠ 0 := by
  intro h0
  have c0 := congrArg (fun p => p.coeff 0) h0
  have c1 := congrArg (fun p => p.coeff 1) h0
  have c2 := congrArg (fun p => p.coeff 2) h0
  simp only [lkQ, coeff_add, coeff_C_mul, coeff_X_pow, coeff_X, coeff_C, coeff_zero] at c0 c1 c2
  norm_num at c0 c1 c2
  exact hne (Tup.ext' (by linear_combination c0) ht (by linear_combination c1) (by linear_combination c2))

variable [Fintype K]

omit [Fintype ι] [Fintype π] [Fintype K] in
/-- **The `β` round**: for a tuple outside the table, at most `2M` values of `β` make it agree in tag and `β`-part with
some table tuple (a nonzero quadratic per distinct table tuple of its tag). -/
theorem lk_round_beta (A : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (l : ι ⊕ (π ⊕ π)) (hl : ∀ j, T j ≠ A l) :
    EscapesWithin (fun β => ∃ j, (T j).tag = (A l).tag ∧ foldB β (T j) = foldB β (A l)) (2 * (univ.image T).card) := by
  classical
  let qOf : Tup K → K[X] := fun τ => lkQ (A l) τ
  have hq0 : ∀ τ ∈ univ.image T, τ.tag = (A l).tag → qOf τ ≠ 0 := by
    intro τ hτ ht
    obtain ⟨j, -, rfl⟩ := mem_image.mp hτ
    exact lkQ_ne_zero (A l) (T j) ht (hl j)
  have hdeg : ∀ τ, (qOf τ).natDegree ≤ 2 := fun τ => lkQ_natDegree (A l) τ
  have heval : ∀ τ β, (qOf τ).eval β = foldB β τ - foldB β (A l) := fun τ β => lkQ_eval (A l) τ β
  refine ⟨(univ.image T).biUnion (fun τ => if τ.tag = (A l).tag then (qOf τ).roots.toFinset else ∅), ?_, ?_⟩
  · refine card_biUnion_le.trans ?_
    calc ∑ τ ∈ univ.image T, (if τ.tag = (A l).tag then (qOf τ).roots.toFinset else ∅).card
        ≤ ∑ _τ ∈ univ.image T, 2 := by
          refine sum_le_sum (fun τ _ => ?_)
          split_ifs
          · exact (Multiset.toFinset_card_le _).trans ((card_roots' _).trans (hdeg τ))
          · simp
      _ = 2 * (univ.image T).card := by rw [sum_const, smul_eq_mul, mul_comm]
  · rintro β ⟨j, ht, hf⟩
    refine mem_biUnion.mpr ⟨T j, mem_image_of_mem T (mem_univ j), ?_⟩
    rw [ite_eq_left ht, Multiset.mem_toFinset, mem_roots (hq0 (T j) (mem_image_of_mem T (mem_univ j)) ht), IsRoot.def,
      heval, hf, sub_self]

omit [Fintype ι] [Fintype π] [Fintype K] in
/-- **The `γ` round**: when no table tuple agrees with `A l` in tag and `β`-part, at most `M` values of `γ` make its fold
a folded table tuple (one per distinct table tuple of a different tag). -/
theorem lk_round_gamma (A : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (β : K) (l : ι ⊕ (π ⊕ π))
    (hl : ∀ j, ¬ ((T j).tag = (A l).tag ∧ foldB β (T j) = foldB β (A l))) :
    EscapesWithin (fun γ => ∃ j, fold β γ (T j) = fold β γ (A l)) (univ.image T).card := by
  classical
  refine ⟨(univ.image T).image (fun τ => (foldB β (A l) - foldB β τ) / (τ.tag - (A l).tag)), card_image_le, ?_⟩
  rintro γ ⟨j, hj⟩
  refine mem_image.mpr ⟨T j, mem_image_of_mem T (mem_univ j), ?_⟩
  rw [fold_eq_foldB, fold_eq_foldB] at hj
  have ht : (T j).tag - (A l).tag ≠ 0 := by
    intro h0
    have htag : (T j).tag = (A l).tag := sub_eq_zero.mp h0
    apply hl j
    refine ⟨htag, ?_⟩
    rw [htag] at hj
    exact add_right_cancel hj
  show (foldB β (A l) - foldB β (T j)) / ((T j).tag - (A l).tag) = γ
  rw [div_eq_iff ht]
  linear_combination -hj

open Classical in
/-- **The `α` round**: when some folded tuple is not a folded table tuple, at most `N + 2M − 1` values of `α` leave
helpers passing every relation (`card_helperRel_le'`). -/
theorem lk_round_alpha (A : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (m : κ → K) (β γ : K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) (l : ι ⊕ (π ⊕ π))
    (hl : ∀ j, fold β γ (T j) ≠ fold β γ (A l)) :
    EscapesWithin (fun α => ∃ H, HelperRel (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m α H)
      (Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card) := by
  have hcardL : Fintype.card (ι ⊕ (π ⊕ π)) = Fintype.card ι + 2 * Fintype.card π := by
    rw [Fintype.card_sum, Fintype.card_sum]
    ring
  have hne := logup_ne_of_not_mem (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m (by rw [hcardL]; exact hN)
    (i := l) hl
  have himg : (univ.image (fun j => fold β γ (T j))).card ≤ (univ.image T).card := by
    rw [show univ.image (fun j => fold β γ (T j)) = (univ.image T).image (fold β γ) by rw [image_image]; rfl]
    exact card_image_le
  refine ⟨univ.filter (fun α => ∃ H, HelperRel (fun l => fold β γ (A l)) (fun j => fold β γ (T j)) m α H),
    (card_helperRel_le' _ _ m hne).trans (by omega), fun α hα => mem_filter.mpr ⟨mem_univ _, hα⟩⟩

/-- **LogUp's three rounds are round-by-round sound** with at most `N + 2M` escaping challenges per round. -/
theorem lkSt3_rbr (A : ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (m : κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) (τ : List (List UInt8 × K)) (mg : List UInt8)
    (hτ : τ.length < 3) (hns : ¬ lkSt3 A T m τ) :
    EscapesWithin (fun c => lkSt3 A T m (τ ++ [(mg, c)]))
      (Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card) := by
  rcases τ with _ | ⟨⟨m0, β⟩, _ | ⟨⟨m1, γ⟩, _ | ⟨e, τ⟩⟩⟩
  · -- before β
    have hns' : ∃ l, ∀ j, T j ≠ A l := by
      by_contra hc
      apply hns
      intro l
      by_contra hno
      exact hc ⟨l, fun j hj => hno ⟨j, hj⟩⟩
    obtain ⟨l, hl⟩ := hns'
    obtain ⟨B, hB, hS⟩ := lk_round_beta A T l hl
    exact ⟨B, hB.trans (by omega), fun β hβ => hS β (hβ l hl)⟩
  · -- after β, before γ
    have hns' : ∃ l, (∀ j, T j ≠ A l) ∧ ∀ j, ¬ ((T j).tag = (A l).tag ∧ foldB β (T j) = foldB β (A l)) := by
      by_contra hc
      apply hns
      intro l hl
      by_contra hno
      exact hc ⟨l, hl, fun j hj => hno ⟨j, hj.1, hj.2⟩⟩
    obtain ⟨l, -, hno⟩ := hns'
    obtain ⟨B, hB, hS⟩ := lk_round_gamma A T β l hno
    exact ⟨B, hB.trans (by omega), fun γ hγ => hS γ (hγ l)⟩
  · -- after γ, before α
    have hns' : ∃ l, ∀ j, fold β γ (T j) ≠ fold β γ (A l) := by
      by_contra hc
      apply hns
      intro l
      by_contra hno
      exact hc ⟨l, fun j hj => hno ⟨j, hj⟩⟩
    obtain ⟨l, hl⟩ := hns'
    obtain ⟨B, hB, hS⟩ := lk_round_alpha A T m β γ hN l hl
    exact ⟨B, hB, fun α hα => hS α hα⟩
  · simp only [List.length_cons] at hτ
    omega

end Rounds

/-! ## LogUp on the block's chain, over the extracted lookups -/

section Chain

variable {K : Type} [Field K] [Algebra GF K] [DecidableEq K] {L : ℕ}
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

/-- **LogUp as a squeeze-run sub-protocol** of the block's schedule: its window at entry `hdrLen + 4` (after the header
and the `A`, `M` absorbs), its three squeezes `β, γ, α`, its lookups `Alk` and multiplicities `mlk` read off the
prover's log cut at the `A` root the header shows. -/
def lkSq (hdrLen : ℕ) (absOf : QB L → Option (List UInt8)) (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K) : SqX K L where
  a := hdrLen + 4
  n := 3
  e := Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card
  St Lg hdr τ := lkSt3 (Alk (cutO absOf (absAt hdr hdrLen) Lg)) T (mlk (cutO absOf (absAt hdr hdrLen) Lg)) τ

omit [Algebra GF K] in
theorem lkSq_rbr [Fintype K] (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K) : (lkSq hdrLen absOf Alk T mlk).Rbr :=
  fun _ _ τ mg hτ hns => lkSt3_rbr _ T _ hN τ mg hτ hns

/-- The verifier's operations up to the `H` root: the header and the roots' ten. -/
def lkOps (P : BlockParams) (out : List Op × Core) : List Op := out.1 ++ rootOps P out.2

theorem challengeFp2Vec_three (H : HIn → Dig) (t : Tr) :
    (t.challengeFp2Vec H 3).1 = [(t.challengeFp2 H).1, ((t.challengeFp2 H).2.challengeFp2 H).1,
      (((t.challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1] := rfl

/-- The `A` root is the absorb right after the header. -/
theorem absAt_rootsA (H : HIn → Dig) (P : BlockParams) (core : Core) (hdr : List Op) (t : Tr) :
    absAt (opTrace H t (hdr ++ rootOpsA P core)) hdr.length = some core.aRoot.toList := by
  have hl : (opTrace H t hdr).length = hdr.length := opTrace_length H t hdr
  have h0 : (opTrace H t hdr).length ≤ hdr.length := by rw [hl]
  unfold absAt
  rw [opTrace_append, List.getElem?_append_right h0, hl, Nat.sub_self]
  simp [rootOpsA, opTrace]

/-- **The prover wins against LogUp**: the slots accept, some looked-up tuple EXTRACTED from the prover's log (cut at
the `A` root) is not a table tuple, and yet some helpers pass every relation at the transcript's `β, γ, α`. -/
def LkWin (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (cuA : List (QB L × Dig)) (G : QB L → Dig) (out : List Op × Core) : Prop :=
  ∃ bga rs acc, SlotsAcc key domain P hdrLen G out bga rs acc
    ∧ (∃ l, ∀ j, T j ≠ Alk cuA l)
    ∧ ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk cuA l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk cuA) (bga.2.2.toK U) Hh

omit [Algebra GF K] in
/-- LogUp's state is frozen once the header up to the `A` root is logged (`cutO_stable`). -/
theorem lkSq_stab (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hdrLen : ℕ) (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K) {β : Type} (A : OC (QB L) Dig β) :
    ∀ (G : QB L → Dig) (P1 P1' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = hdrLen + 1 → (∀ y ∈ qs, y ∈ P1.map Prod.fst) →
      P1 <+: P1' → (∀ e ∈ P1', e.2 = G e.1) →
      ∀ sx ∈ [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk], ∀ ext : List (TItem × Dig),
        sx.St (proverLog A P1) (τ.map entB ++ ext) = sx.St (proverLog A P1') (τ.map entB ++ ext) := by
    intro G P1 P1' τ qs hc hl hq hpre _ sx hsx ext
    rw [List.mem_singleton] at hsx
    subst hsx
    have hab : absAt (τ.map entB ++ ext) hdrLen = absAt (τ.map entB) hdrLen := by
      unfold absAt
      rw [List.getElem?_append_left (by rw [List.length_map, hl]; omega)]
    have hcut := cutO_stable (chainEncB key domain hs L hL) G τ qs hc P1 P1' hq hpre A hdrLen
    show (fun τr => lkSt3 (Alk (cutO (absOfC (chainEncB key domain hs L hL)) (absAt (τ.map entB ++ ext) hdrLen)
        (proverLog A P1))) T (mlk (cutO (absOfC (chainEncB key domain hs L hL)) (absAt (τ.map entB ++ ext) hdrLen)
        (proverLog A P1))) τr)
      = (fun τr => lkSt3 (Alk (cutO (absOfC (chainEncB key domain hs L hL)) (absAt (τ.map entB ++ ext) hdrLen)
        (proverLog A P1'))) T (mlk (cutO (absOfC (chainEncB key domain hs L hL)) (absAt (τ.map entB ++ ext) hdrLen)
        (proverLog A P1'))) τr)
    rw [hab, hcut]

/-- **A win against LogUp is the composed event** on the trace of the header and the roots (`fs_sq_knowledge`'s
premise). -/
theorem lkWin_event (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig)
    (hG : LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G)) :
    (∀ op ∈ lkOps P (A.run G), op.len ≤ L) ∧ (lkOps P (A.run G)).length ≤ hdrLen + 10
      ∧ (∃ sx ∈ [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk],
          sx.a ≤ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).length
          ∧ ¬ sx.St (A.runLog G).2
            ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take sx.a) [])
      ∧ ∀ sx ∈ [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk],
          ∃ (ks : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)), ks.length = sx.n ∧ ds.length = sx.n
          ∧ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).drop sx.a
            = (ks.map TItem.squeeze).zip ds ++ rest
          ∧ sx.St (A.runLog G).2
            ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take sx.a)
            (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))) := by
  obtain ⟨bga, _rs, _acc, ⟨hhl, hhfit, -, -, t', hacc⟩, ⟨l, hl⟩, Hh, hH⟩ := hG
  -- the transcript's β, γ, α are `blockSlots`' bga
  have hbga : bga = (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)).challengeFp2
      (liftH G)).1,
      (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).1,
      ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)).challengeFp2
        (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1) := by
    rw [blockSlots_eq] at hacc
    simp only [← runOps_append] at hacc
    split at hacc
    · simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
      exact hacc.1.symm
    · cases hacc
  have hfit : ∀ op ∈ lkOps P (A.run G), op.len ≤ L := by
    intro op hop
    rcases List.mem_append.mp hop with hop | hop
    · exact hhfit op hop
    · exact rootOps_len P _ L hL81 op hop
  have htr : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)
        ++ (opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2))
          (drawOps 3)
          ++ opTrace (liftH G) (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
            ((A.run G).1 ++ rootOpsA P (A.run G).2)) (drawOps 3)) (rootOpsH P (A.run G).2)) := by
    have hops : lkOps P (A.run G) = ((A.run G).1 ++ rootOpsA P (A.run G).2) ++ (drawOps 3
        ++ rootOpsH P (A.run G).2) := by
      simp only [lkOps, rootOps, List.append_assoc]
      rfl
    rw [hops, opTrace_append (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)
      (drawOps 3 ++ rootOpsH P (A.run G).2), opTrace_append (liftH G) _ (drawOps 3) (rootOpsH P (A.run G).2)]
  have hlA : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2)).length
      = hdrLen + 4 := by
    rw [opTrace_length, List.length_append, hhl, show (rootOpsA P (A.run G).2).length = 4 from rfl]
  obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) 3
    (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2))
  obtain ⟨d1, d2, d3, rfl⟩ := List.length_eq_three.mp h3
  rw [challengeFp2Vec_three] at h4
  simp only [List.map_cons, List.map_nil] at h4
  obtain ⟨e1, h4⟩ := List.cons.inj h4
  obtain ⟨e2, h4⟩ := List.cons.inj h4
  obtain ⟨e3, -⟩ := List.cons.inj h4
  have hb1 : (challengeFp2Of d1).toK U = bga.1.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e1
  have hb2 : (challengeFp2Of d2).toK U = bga.2.1.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e2
  have hb3 : (challengeFp2Of d3).toK U = bga.2.2.toK U := by rw [hbga]; exact congrArg (Fp2.toK U) e3
  have hhead : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take (hdrLen + 4)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2) := by
    rw [htr, ← hlA, List.take_left' rfl]
  have hroot : absAt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ((A.run G).1 ++ rootOpsA P (A.run G).2))
      hdrLen = some (A.run G).2.aRoot.toList := by
    rw [← hhl]
    exact absAt_rootsA (liftH G) P (A.run G).2 (A.run G).1 _
  have hlen : (lkOps P (A.run G)).length = hdrLen + 10 := by
    rw [lkOps, List.length_append, hhl, show (rootOps P (A.run G).2).length = 10 from rfl]
  refine ⟨hfit, le_of_eq hlen, ⟨lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk,
    List.mem_singleton_self _, ?_, ?_⟩, ?_⟩
  · show hdrLen + 4 ≤ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).length
    rw [htr, List.length_append, hlA]
    exact Nat.le_add_right _ _
  · show ¬ lkSt3 (Alk (cutO (absOfC (chainEncB key domain hs L hL))
        (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take (hdrLen + 4)) hdrLen)
        (A.runLog G).2)) T (mlk (cutO (absOfC (chainEncB key domain hs L hL))
        (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take (hdrLen + 4)) hdrLen)
        (A.runLog G).2)) []
    rw [hhead, hroot]
    simp only [lkSt3, not_forall, not_exists]
    exact ⟨l, hl⟩
  · intro sx hsx
    rw [List.mem_singleton] at hsx
    subst hsx
    refine ⟨ks', [d1, d2, d3], opTrace (liftH G) (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      ((A.run G).1 ++ rootOpsA P (A.run G).2)) (drawOps 3)) (rootOpsH P (A.run G).2), h2, rfl, ?_, ?_⟩
    · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).drop (hdrLen + 4) = _
      rw [htr, ← hlA, List.drop_left' rfl, h1]
    · show lkSt3 (Alk (cutO (absOfC (chainEncB key domain hs L hL))
        (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take (hdrLen + 4)) hdrLen)
        (A.runLog G).2)) T (mlk (cutO (absOfC (chainEncB key domain hs L hL))
        (absAt ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (lkOps P (A.run G))).take (hdrLen + 4)) hdrLen)
        (A.runLog G).2)) ([d1, d2, d3].map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))
      rw [hhead, hroot]
      simp only [List.map_cons, List.map_nil, lkSt3]
      rw [hb1, hb2, hb3]
      exact ⟨Hh, hH⟩

/-- **LogUp under Fiat–Shamir on the block's schedule, knowledge version** (D63 lane L21; `hLk`'s probabilistic half).
For ANY block shape, any lookup list `Alk` and multiplicities `mlk` over the `A` planes extracted from the prover's log
(cut at the `A` root's first absorption), any table `T` (`N` lookups, `M` distinct table tuples, `N < char K`): the
probability that the slots accept, some extracted looked-up tuple is not a table tuple, and yet some helpers pass every
relation at the transcript's `β, γ, α` is at most `T·(N + 2M)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`,
`T = q + (hdrLen + 10) + 1` (L8's count; `RelW16Pos.block_logup_fs_knowledge_pos` is the per-position one). -/
theorem block_logup_fs_knowledge [Fintype K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G))
      ≤ (((q + (hdrLen + 10) + 1) * (Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card) : ℕ) : ℝ≥0∞)
          / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (hdrLen + 10) + 1) Dig + collBound (q + (hdrLen + 10) + 1 + 1) Dig := by
  have hmain := fs_sq_knowledge U hU hK2 key domain hs hL hL64
    [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk]
    (Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      exact lkSq_rbr hdrLen _ Alk T mlk hN)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      exact le_rfl)
    (lkOps P) (hdrLen + 10) (hdrLen + 1)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      show hdrLen + 1 < hdrLen + 4
      omega)
    q A hA (lkSq_stab key domain hs hL hdrLen Alk T mlk A)
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact lkWin_event U key domain hs hL hL81 P hdrLen Alk T mlk A G hG

/-- **`block_knowledge`'s `hLk` from LogUp under Fiat–Shamir** (D63 lane L21). For any block shape and any reading `xtE`
of the extracted planes: if a failing LogUp conclusion on the extracted planes means some extracted looked-up tuple is
outside the table (`hlook`, the lookup list's bridge), and the slots accept while the EXTRACTED helpers `Hx` fail a
relation or the sum claim with probability at most `εhelp` (`hHelp`: the zero-checks' helper clauses and `H`'s sum
row), then the slots accept while `W16Lookups` fails with probability at most `εhelp + ` LogUp's bound. -/
theorem lk_of_logup [Fintype K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (Bad : Cuts3 L → RootsO → Prop) (Hx : Cuts3 L → RootsO → Helpers ι π κ K)
    (hlook : ∀ cu rt, Bad cu rt → ∃ l, ∀ j, T j ≠ Alk cu.1 l)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (εhelp : ℝ≥0∞)
    (hHelp : prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
          (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          (Hx (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εhelp) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, SlotsAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Bad (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ≤ εhelp + ((((q + (hdrLen + 10) + 1) * (Fintype.card ι + 2 * Fintype.card π + 2 * (univ.image T).card) : ℕ)
          : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (hdrLen + 10) + 1) Dig + collBound (q + (hdrLen + 10) + 1 + 1) Dig) := by
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hHelp (block_logup_fs_knowledge U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN q A hA)))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hbad⟩ := hG
  by_cases hrel : HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
      (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
      (Hx (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
  · exact Or.inr ⟨bga, rs, acc, hacc, hlook _ _ hbad, _, hrel⟩
  · exact Or.inl ⟨bga, rs, acc, hacc, hrel⟩

end Chain

end ZK60.Exec.Block
