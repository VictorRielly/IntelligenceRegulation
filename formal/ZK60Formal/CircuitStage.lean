/-
D63, step L2 (`CircuitIff`): from one position to one STAGE. Every family is proved at one position given its inputs
(CircuitRequant, CircuitNorm, CircuitSoftmax, CircuitMatmul, CircuitRopeAct). A stage of the block is a family over a
whole plane, and its integer spec refuses when ANY position refuses. This file lifts the per-position iffs to planes
and proves the two stages whose positions are coupled: a norm ROW (one isqrt per token, shared by the row's divisions)
and a softmax ROW (one maximum and one total per row, shared by its divisions).

* `liftO f`: the plane `p ↦ a` when every `f p = some a`, else `none` (the builder's first `Err` at any position);
  `liftO_eq_some`, `liftO_exists`.
* `rq`: the requantized word alone (`requantIn`'s first component); `rq_eq_some`, `rq_class`.
* `normTok`, `NormTokRel`, `normTok_iff`: one RMSNorm row, the integer spec as `witness_accuracy::normalized` computes it
  (witness_accuracy.rs:414-457) and the constraints (`SC_TZC` with its `SC_SS` host, argument.rs:2022-2028, 2088-2101;
  `dzc_w16`, argument_accuracy.rs:490-493).
* `softmaxF`, `SoftmaxRowRel`, `softmaxRow_iff`: one softmax row, the spec as `build_with` computes it
  (witness_accuracy.rs:869-904) and the constraints (`szc_w16`, argument_accuracy.rs:624-631, `SC_RS`,
  argument.rs:2135-2148, the lookups of `Dom::S`, accuracy_layout.rs:326-336).

The softmax row's maximum is proved with no booleanity of the selector (`rowmax_gf`, candidate C7), and its total is
proved positive from the slack clause `c3` and its range facts, so the builder's `total ≤ 0` refusal and the circuit agree.
-/
import ZK60Formal.CircuitRopeAct
import ZK60Formal.Goldilocks

namespace ZK60.Circuit

open ZK60.Model

/-! ## Planes -/

open Classical in
/-- The plane `p ↦ a` of a per-position spec when no position refuses, else `none`. -/
noncomputable def liftO {P α : Type} (f : P → Option α) : Option (P → α) :=
  if h : ∀ p, ∃ a, f p = some a then some (fun p => Classical.choose (h p)) else none

theorem liftO_eq_some {P α : Type} {f : P → Option α} {v : P → α} :
    liftO f = some v ↔ ∀ p, f p = some (v p) := by
  unfold liftO
  split_ifs with h
  · constructor
    · intro he p
      have hv : (fun p => Classical.choose (h p)) = v := Option.some.inj he
      rw [← hv]
      exact Classical.choose_spec (h p)
    · intro hv
      congr 1
      funext p
      exact Option.some.inj ((Classical.choose_spec (h p)).symm.trans (hv p))
  · constructor
    · intro he
      cases he
    · intro hv
      exact absurd (fun p => ⟨v p, hv p⟩) h

/-- A per-position iff lifts to the plane. -/
theorem liftO_exists {P α : Type} (f : P → Option α) (R : P → α → Prop) :
    (∀ p, ∃ a, f p = some a ∧ R p a) ↔ ∃ v, liftO f = some v ∧ ∀ p, R p (v p) := by
  constructor
  · intro h
    obtain ⟨v, hv⟩ := Classical.skolem.mp h
    exact ⟨v, liftO_eq_some.mpr fun p => (hv p).1, fun p => (hv p).2⟩
  · rintro ⟨v, hv, hR⟩ p
    exact ⟨v p, liftO_eq_some.mp hv p, hR p⟩

theorem obind_eq_some {α β : Type} {o : Option α} {f : α → Option β} {b : β} :
    o.bind f = some b ↔ ∃ a, o = some a ∧ f a = some b := by
  cases o with
  | none => exact ⟨fun h => (by simp at h), fun ⟨_, h, _⟩ => (by simp at h)⟩
  | some a => exact ⟨fun h => ⟨a, rfl, h⟩, fun ⟨a', h, h'⟩ => by cases h; exact h'⟩

theorem obind_some {α β : Type} (a : α) (f : α → Option β) : (some a).bind f = f a := rfl

/-! ## The requantized word -/

/-- The word of a requantization (`quantized`'s `words`, witness_accuracy.rs:373-391). -/
def rq (lo hi acc : ℤ) (m s : ℕ) : Option ℤ := (requantIn lo hi acc m s).map Prod.fst

theorem rq_eq_some {lo hi acc : ℤ} {m s : ℕ} {v : ℤ} :
    rq lo hi acc m s = some v ↔ ∃ r, requantIn lo hi acc m s = some (v, r) := by
  unfold rq
  cases requantIn lo hi acc m s with
  | none => exact ⟨fun h' => (by simp at h'), fun ⟨_, h'⟩ => (by simp at h')⟩
  | some p =>
    obtain ⟨a, b⟩ := p
    constructor
    · intro h'
      have : a = v := Option.some.inj h'
      exact ⟨b, by rw [this]⟩
    · rintro ⟨r, h'⟩
      have : (a, b) = (v, r) := Option.some.inj h'
      rw [Prod.mk.injEq] at this
      simp [this.1]

/-- A requantized word lies in its class. -/
theorem rq_class {lo hi acc : ℤ} {m s : ℕ} {v : ℤ} (h : rq lo hi acc m s = some v) : lo ≤ v ∧ v ≤ hi := by
  obtain ⟨r, hr⟩ := rq_eq_some.mp h
  rw [requantIn_mul] at hr
  obtain ⟨hlo, hhi, hw, -⟩ := requantIn_eq_some.mp hr
  rw [← hw] at hlo hhi
  exact ⟨hlo, hhi⟩

theorem liftO_rq_class {P : Type} {lo hi : ℤ} {acc : P → ℤ} {m : P → ℕ} {s : ℕ} {v : P → ℤ}
    (h : liftO (fun p => rq lo hi (acc p) (m p) s) = some v) (p : P) : lo ≤ v p ∧ v p ≤ hi :=
  rq_class (liftO_eq_some.mp h p)

/-! ## Requantization stages -/

/-- **A matmul stage** (public weights): every position's hosted identity, word lookup and remainder lookups hold
exactly when no position of the integer stage refuses and the plane is the stage's words. -/
theorem rqPlane_iff {P ι : Type} [Fintype ι] (C : WordClass) (s : ℕ) (hs : s ≤ 24) (x w : P → ι → ℤ) (m : P → ℕ)
    (hb : ∀ p, |(∑ i, x p i * w p i) * (m p : ℤ)| ≤ 2 ^ 62) (X : P → ι → GF) (hX : ∀ p i, X p i = (x p i : GF))
    (Q : P → GF) :
    (∀ p, ∃ R : GF, HostRel s (∑ i, X p i * ((w p i * (m p : ℤ) : ℤ) : GF)) (Q p) R ∧ C.P (Q p) ∧
        RemW16 s R) ↔
      ∃ v, liftO (fun p => rq C.lo C.hi (∑ i, x p i * w p i) (m p) s) = some v ∧ ∀ p, Q p = (v p : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_) (liftO_exists _ fun p (a : ℤ) => Q p = (a : GF))
  have hsum : (∑ i, X p i * ((w p i * (m p : ℤ) : ℤ) : GF)) =
      ∑ i, ((x p i : ℤ) : GF) * ((w p i * (m p : ℤ) : ℤ) : GF) :=
    Finset.sum_congr rfl fun i _ => by rw [hX p i]
  rw [hsum, matmul_requant_iff C s hs (x p) (w p) (m p) (hb p) (Q p)]
  constructor
  · rintro ⟨v, r, hv, hq⟩
    exact ⟨v, rq_eq_some.mpr ⟨r, hv⟩, hq⟩
  · rintro ⟨v, hv, hq⟩
    obtain ⟨r, hr⟩ := rq_eq_some.mp hv
    exact ⟨v, r, hr, hq⟩

/-- **A private-by-private stage** (scores, `PV`). -/
theorem rqPlaneBil_iff {P ι : Type} [Fintype ι] (C : WordClass) (s : ℕ) (hs : s ≤ 24) (x w : P → ι → ℤ)
    (hb : ∀ p, |∑ i, x p i * w p i| ≤ 2 ^ 62) (X Y : P → ι → GF) (hX : ∀ p i, X p i = (x p i : GF))
    (hY : ∀ p i, Y p i = (w p i : GF)) (Q : P → GF) :
    (∀ p, ∃ R : GF, HostRel s (∑ i, X p i * Y p i) (Q p) R ∧ C.P (Q p) ∧ RemW16 s R) ↔
      ∃ v, liftO (fun p => rq C.lo C.hi (∑ i, x p i * w p i) 1 s) = some v ∧ ∀ p, Q p = (v p : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_) (liftO_exists _ fun p (a : ℤ) => Q p = (a : GF))
  have hsum : (∑ i, X p i * Y p i) = ∑ i, ((x p i : ℤ) : GF) * ((w p i : ℤ) : GF) :=
    Finset.sum_congr rfl fun i _ => by rw [hX p i, hY p i]
  rw [hsum, bilinear_requant_iff C s hs (x p) (w p) (hb p) (Q p)]
  constructor
  · rintro ⟨v, r, hv, hq⟩
    exact ⟨v, rq_eq_some.mpr ⟨r, hv⟩, hq⟩
  · rintro ⟨v, hv, hq⟩
    obtain ⟨r, hr⟩ := rq_eq_some.mp hv
    exact ⟨v, r, hr, hq⟩

/-! ## A norm row -/

/-- The window conditions of the isqrt witness, the builder's refusal test (witness_accuracy.rs:420-428). -/
def NormOK (ss : ℤ) : Prop :=
  0 ≤ ss ∧ (isqrtWitness ss).1 ≠ 0 ∧ inIsqrtWindow (isqrtWitness ss).1 = true ∧
    inIsqrtWindow (isqrtWitness ss).2.1 = true ∧ inIsqrtWindow (isqrtWitness ss).2.2 = true

/-- The sum of squares of a row, with the norm's epsilon. -/
def ssOf {n : ℕ} (ceps : ℤ) (x : Fin n → ℤ) : ℤ := ceps + ∑ i, x i * x i

open Classical in
/-- **One RMSNorm row** (`normalized`'s loop body, witness_accuracy.rs:414-457; `Model.normRow` on lists): the isqrt
`d` and each element's word, or the refusal. -/
noncomputable def normTok {n : ℕ} (ceps cn : ℤ) (tn : ℕ) (gam x : Fin n → ℤ) : Option (ℤ × (Fin n → ℤ)) :=
  if NormOK (ssOf ceps x) then
    (liftO fun i => (normElem tn cn (isqrtWitness (ssOf ceps x)).1 (x i) (gam i)).map Prod.fst).map
      fun y => ((isqrtWitness (ssOf ceps x)).1, y)
  else none

/-- The constraints of one norm row: the isqrt clauses on the hosted sum of squares (`SC_TZC` hosting `SC_SS`), the
three 24-bit facts (`threeBytes_iff` of the byte limbs), and per element the two division clauses, the two 24-bit
remainders and the int16 word. -/
def NormTokRel {n : ℕ} (ceps cn : ℤ) (tn : ℕ) (gam : Fin n → ℤ) (x : Fin n → GF) (D : GF) (y : Fin n → GF) : Prop :=
  (∃ dsq a1 a2 : GF, IsqrtRel ((ceps : GF) + ∑ i, x i * x i) D dsq a1 a2 ∧ InRange 24 D ∧ InRange 24 a1 ∧
    InRange 24 a2) ∧
  ∀ i, (∃ nr ns : GF, NormDivRel tn (cn : GF) (gam i : GF) (x i) D (y i) nr ns ∧ RemW16 24 nr ∧ RemW16 24 ns) ∧
    Word16 (y i)

/-- **`CircuitIff` for one norm row.** For int16 inputs over at most `4096` positions, symmetric int8 gains,
`1 ≤ ceps ≤ 2^24`, `|cn| ≤ 2^24` and `tn ≤ 16`. -/
theorem normTok_iff {n : ℕ} (hn : n ≤ 4096) (ceps cn : ℤ) (tn : ℕ) (hc1 : 1 ≤ ceps) (hc2 : ceps ≤ 2 ^ 24)
    (hcn : |cn| ≤ 2 ^ 24) (htn : tn ≤ 16) (gam x : Fin n → ℤ) (hg : ∀ i, |gam i| ≤ 127)
    (hx : ∀ i, -2 ^ 15 ≤ x i ∧ x i ≤ 2 ^ 15 - 1) (D : GF) (y : Fin n → GF) :
    NormTokRel ceps cn tn gam (fun i => (x i : GF)) D y ↔
      ∃ dd : ℤ, ∃ yy : Fin n → ℤ, normTok ceps cn tn gam x = some (dd, yy) ∧ D = (dd : GF) ∧
        ∀ i, y i = (yy i : GF) := by
  have hN : Fintype.card (Fin n) ≤ 4096 := by rw [Fintype.card_fin]; exact hn
  obtain ⟨hss0, hss1⟩ : 0 ≤ ssOf ceps x ∧ ssOf ceps x < 2 ^ 60 := ss_bounds x ceps hx (by linarith) hc2 hN
  have hcast : (ceps : GF) + ∑ i, (x i : GF) * (x i : GF) = ((ssOf ceps x : ℤ) : GF) := ss_cast x ceps
  have hsq0 : 0 ≤ ∑ i, x i * x i := Finset.sum_nonneg fun i _ => mul_self_nonneg (x i)
  have hpos : 1 ≤ (isqrtWitness (ssOf ceps x)).1 := isqrt_pos _ (by unfold ssOf; linarith)
  -- the per-element iff at the row's `d`
  have helem : ∀ (dd : ℤ), 1 ≤ dd → dd < 2 ^ 24 → ∀ i,
      (((∃ nr ns : GF, NormDivRel tn (cn : GF) (gam i : GF) (x i : GF) (dd : GF) (y i) nr ns ∧ RemW16 24 nr ∧
          RemW16 24 ns) ∧ Word16 (y i)) ↔
        ∃ a, (normElem tn cn dd (x i) (gam i)).map Prod.fst = some a ∧ y i = (a : GF)) := by
    intro dd h1 h2 i
    rw [normDiv_iff tn htn cn (gam i) (x i) dd hcn (hg i) (abs_le_of_int16 (hx i)) h1 h2 (y i)]
    constructor
    · rintro ⟨q, _, _, hq, hy⟩
      exact ⟨q, by simp [hq], hy⟩
    · rintro ⟨a, ha, hy⟩
      cases he : normElem tn cn dd (x i) (gam i) with
      | none => rw [he] at ha; cases ha
      | some e =>
        obtain ⟨q, r, s⟩ := e
        rw [he] at ha
        have hqa : q = a := Option.some.inj ha
        exact ⟨q, r, s, rfl, by rw [hqa]; exact hy⟩
  show (∃ dsq a1 a2 : GF, IsqrtRel ((ceps : GF) + ∑ i, (x i : GF) * (x i : GF)) D dsq a1 a2 ∧ InRange 24 D ∧
      InRange 24 a1 ∧ InRange 24 a2) ∧
    (∀ i, (∃ nr ns : GF, NormDivRel tn (cn : GF) (gam i : GF) (x i : GF) D (y i) nr ns ∧ RemW16 24 nr ∧
      RemW16 24 ns) ∧ Word16 (y i)) ↔ _
  rw [hcast, isqrt_iff _ hss0 hss1 D]
  constructor
  · rintro ⟨⟨w0, w1, w2, hD⟩, hdiv⟩
    have hd2 : (isqrtWitness (ssOf ceps x)).1 < 2 ^ 24 := by
      have h := w0
      unfold inIsqrtWindow at h
      exact (of_decide_eq_true h).2
    rw [hD] at hdiv
    obtain ⟨v, hv, hyv⟩ := (liftO_exists (fun i => (normElem tn cn (isqrtWitness (ssOf ceps x)).1 (x i)
      (gam i)).map Prod.fst) fun i a => y i = (a : GF)).mp (fun i => (helem _ hpos hd2 i).mp (hdiv i))
    refine ⟨(isqrtWitness (ssOf ceps x)).1, v, ?_, hD, hyv⟩
    unfold normTok
    rw [ite_eq_left (show NormOK (ssOf ceps x) from ⟨hss0, fun h0 => by rw [h0] at hpos; norm_num at hpos, w0, w1, w2⟩)]
    simp only [hv, Option.map_some]
  · rintro ⟨dd, yy, hnt, hD, hy⟩
    unfold normTok at hnt
    by_cases hok : NormOK (ssOf ceps x)
    · rw [ite_eq_left hok] at hnt
      obtain ⟨-, -, w0, w1, w2⟩ := hok
      obtain ⟨v, hv, hvy⟩ := Option.map_eq_some_iff.mp hnt
      have hvy2 : ((isqrtWitness (ssOf ceps x)).1, v) = (dd, yy) := hvy
      obtain ⟨hdd, hvyy⟩ := Prod.mk.inj hvy2
      rw [hvyy] at hv
      have hd2 : (isqrtWitness (ssOf ceps x)).1 < 2 ^ 24 := by
        have h := w0
        unfold inIsqrtWindow at h
        exact (of_decide_eq_true h).2
      subst hdd
      refine ⟨⟨w0, w1, w2, hD⟩, fun i => ?_⟩
      rw [hD]
      exact (helem _ hpos hd2 i).mpr ⟨yy i, liftO_eq_some.mp hv i, hy i⟩
    · rw [ite_eq_right hok] at hnt
      cases hnt

/-- The words of an admitted norm row are int16. -/
theorem normTok_class {n : ℕ} {ceps cn : ℤ} {tn : ℕ} {gam x : Fin n → ℤ} {a : ℤ × (Fin n → ℤ)}
    (h : normTok ceps cn tn gam x = some a) (i : Fin n) : -2 ^ 15 ≤ a.2 i ∧ a.2 i ≤ 2 ^ 15 - 1 := by
  obtain ⟨dd, yy⟩ := a
  show -2 ^ 15 ≤ yy i ∧ yy i ≤ 2 ^ 15 - 1
  unfold normTok at h
  by_cases hok : NormOK (ssOf ceps x)
  · rw [ite_eq_left hok] at h
    obtain ⟨v, hv, hvy⟩ := Option.map_eq_some_iff.mp h
    have hvy2 : ((isqrtWitness (ssOf ceps x)).1, v) = (dd, yy) := hvy
    obtain ⟨-, hvyy⟩ := Prod.mk.inj hvy2
    rw [hvyy] at hv
    have he : (normElem tn cn (isqrtWitness (ssOf ceps x)).1 (x i) (gam i)).map Prod.fst = some (yy i) :=
      liftO_eq_some.mp hv i
    cases hn : normElem tn cn (isqrtWitness (ssOf ceps x)).1 (x i) (gam i) with
    | none => rw [hn] at he; cases he
    | some e =>
      obtain ⟨q, r, s⟩ := e
      rw [hn] at he
      have hq : q = yy i := Option.some.inj he
      obtain ⟨⟨h0, h1, -, -⟩, hq', -, -⟩ := normElem_eq_some.mp hn
      rw [← hq', hq] at h0 h1
      unfold int16Lo at h0
      unfold int16Hi at h1
      exact ⟨by norm_num; linarith, by norm_num; linarith⟩
  · rw [ite_eq_right hok] at h
    cases h

/-! ## A softmax row -/

variable {T : ℕ}

/-- The causal mask of row `t` (`causal_mask_at`): `1` at the live columns `j ≤ t`. -/
def maskF (t j : Fin T) : GF := if j ≤ t then 1 else 0

/-- The masked score: the score at a live column, `MASK_SCORE = −127` beyond the row (layout.rs:75). -/
def smOf (t : Fin T) (s : Fin T → ℤ) (j : Fin T) : ℤ := if j ≤ t then s j else maskScore

/-- The row maximum over the live columns. -/
def bestOf (t : Fin T) (s : Fin T → ℤ) : ℤ := (Finset.univ.filter fun j => j ≤ t).sup' ⟨t, by simp⟩ s

/-- The exp value of each column, `exp[best − masked score]`. -/
def expRow (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) (j : Fin T) : ℤ := exp (bestOf t s - smOf t s j)

/-- The row total over the live columns. -/
def totalOf (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) : ℤ := ∑ j, if j ≤ t then expRow exp t s j else 0

/-- The numerator of each column, zero beyond the row. -/
def numOf (fp : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) (j : Fin T) : ℤ :=
  if j ≤ t then expRow exp t s j * 2 ^ fp else 0

open Classical in
/-- **One softmax row** (the softmax loop of `build_with`, witness_accuracy.rs:869-904; `Model.softmaxRow` on lists):
the quotients `P_j = ⌊num_j / total⌋`, refused when the total is not positive, when an exp index leaves `[0, 256)`, or
when a slack `total − 1 − (num_j mod total)` reaches `2^wrho_s`. -/
noncomputable def softmaxF (fp wrho : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) : Option (Fin T → ℤ) :=
  if 0 < totalOf exp t s ∧ ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256 then
    liftO fun j => if totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
      then some (numOf fp exp t s j / totalOf exp t s) else none
  else none

/-- The constraints of one softmax row: the exp tuple of every column at its masked index
`δ_j = mx − mask_j·(s_j + 127) + 127` (argument_accuracy.rs:626, 631), the selector's clauses `c0`, `c1` (:627-628),
the two row sums of `SC_RS` (argument.rs:2135-2148: `Σ_j mask_j·e_j = sum` and `Σ_j zsel_j = 1`, the two halves of the
`λ`-batched row claim), and per column the division clauses `c2`, `c3` (:629-630) with `P`'s direct lookup and the two
`wrho_s`-bit slacks (accuracy_layout.rs:335). -/
def SoftmaxRowRel (fp wrho : ℕ) (exp : ℤ → ℤ) (t : Fin T) (s8 : Fin T → GF) (mx sum : GF) (zsel e P : Fin T → GF) :
    Prop :=
  (∀ j, ExpTable exp (expQuery (mx - maskF t j * (s8 j + 127) + 127) (e j))) ∧
  (∀ j, zsel j * zsel j - zsel j = 0) ∧
  (∀ j, zsel j * (mx - maskF t j * (s8 j + 127) + 127) = 0) ∧
  (∑ j, maskF t j * e j = sum) ∧
  (∑ j, zsel j = 1) ∧
  ∀ j, (∃ sr sg : GF, SoftmaxDivRel (maskF t j * e j * 2 ^ fp) (P j) sum sr sg ∧ RemW16 wrho sr ∧ RemW16 wrho sg) ∧
    InRange (fp + 1) (P j)

theorem delta_eq (t j : Fin T) (s : Fin T → ℤ) (s8 : Fin T → GF) (hs8 : s8 j = (s j : GF)) (mx : GF) :
    mx - maskF t j * (s8 j + 127) + 127 = mx - ((smOf t s j : ℤ) : GF) := by
  rw [hs8]
  unfold maskF smOf maskScore
  by_cases h : j ≤ t
  · simp only [ite_eq_left h]
    ring
  · simp only [ite_eq_right h]
    push_cast; ring

theorem mask_e_eq (t j : Fin T) (exp : ℤ → ℤ) (s : Fin T → ℤ) :
    maskF t j * ((expRow exp t s j : ℤ) : GF) = (((if j ≤ t then expRow exp t s j else 0) : ℤ) : GF) := by
  unfold maskF
  by_cases h : j ≤ t
  · simp only [ite_eq_left h]
    ring
  · simp only [ite_eq_right h]
    push_cast; ring

theorem num_eq (fp : ℕ) (t j : Fin T) (exp : ℤ → ℤ) (s : Fin T → ℤ) :
    maskF t j * ((expRow exp t s j : ℤ) : GF) * 2 ^ fp = ((numOf fp exp t s j : ℤ) : GF) := by
  unfold maskF numOf
  by_cases h : j ≤ t
  · simp only [ite_eq_left h]
    push_cast; ring
  · simp only [ite_eq_right h]
    push_cast; ring

theorem term_nonneg (exp : ℤ → ℤ) (he0 : ∀ i, 0 ≤ exp i) (t : Fin T) (s : Fin T → ℤ) (i : Fin T) :
    0 ≤ (if i ≤ t then expRow exp t s i else 0) := by
  by_cases h : i ≤ t
  · rw [ite_eq_left h]; exact he0 _
  · exact le_of_eq (ite_eq_right h).symm

/-- The live total is between `0` and `T·2^f_e`. -/
theorem totalOf_bounds (fe : ℕ) (exp : ℤ → ℤ) (he0 : ∀ i, 0 ≤ exp i) (he1 : ∀ i, exp i ≤ 2 ^ fe) (t : Fin T)
    (s : Fin T → ℤ) : 0 ≤ totalOf exp t s ∧ totalOf exp t s ≤ (T : ℤ) * 2 ^ fe := by
  constructor
  · exact Finset.sum_nonneg fun i _ => term_nonneg exp he0 t s i
  · calc totalOf exp t s ≤ ∑ _j : Fin T, (2 : ℤ) ^ fe :=
          Finset.sum_le_sum fun j _ => by
            by_cases h : j ≤ t
            · rw [ite_eq_left h]; exact he1 _
            · rw [ite_eq_right h]; positivity
      _ = (T : ℤ) * 2 ^ fe := by rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]

theorem num_bounds (fp : ℕ) (exp : ℤ → ℤ) (he0 : ∀ i, 0 ≤ exp i) (t j : Fin T) (s : Fin T → ℤ) :
    0 ≤ numOf fp exp t s j ∧ numOf fp exp t s j ≤ 2 ^ fp * totalOf exp t s := by
  have hle : (if j ≤ t then expRow exp t s j else 0) ≤ totalOf exp t s :=
    Finset.single_le_sum (f := fun i => if i ≤ t then expRow exp t s i else 0)
      (fun i _ => term_nonneg exp he0 t s i) (Finset.mem_univ j)
  have htot0 : 0 ≤ totalOf exp t s := Finset.sum_nonneg fun i _ => term_nonneg exp he0 t s i
  have h2 : (0 : ℤ) < 2 ^ fp := by positivity
  unfold numOf
  by_cases hj : j ≤ t
  · rw [ite_eq_left hj] at hle ⊢
    refine ⟨mul_nonneg (he0 _) (le_of_lt h2), ?_⟩
    calc expRow exp t s j * 2 ^ fp = 2 ^ fp * expRow exp t s j := mul_comm _ _
      _ ≤ 2 ^ fp * totalOf exp t s := mul_le_mul_of_nonneg_left hle (le_of_lt h2)
  · rw [ite_eq_right hj]
    exact ⟨le_refl 0, mul_nonneg (le_of_lt h2) htot0⟩

/-- The selector of the honest witness: the indicator of one argmax column. -/
def zselOf (j0 j : Fin T) : GF := if j = j0 then 1 else 0

/-- The exp values of the honest witness. -/
def eOf (exp : ℤ → ℤ) (t : Fin T) (s : Fin T → ℤ) (j : Fin T) : GF := ((expRow exp t s j : ℤ) : GF)

/-- **`CircuitIff` for one softmax row.** For symmetric int8 scores `s` (committed as `s8`), a public exp table with
values in `[0, 2^f_e]` (CS-4, private_block.rs:640-642) and the window rule `T·2^f_e ≤ 2^wrho_s` (shape.rs:394-400). -/
theorem softmaxRow_iff (fp wrho fe : ℕ) (hfp : fp ≤ 24) (hw : wrho ≤ 24) (exp : ℤ → ℤ) (he0 : ∀ i, 0 ≤ exp i)
    (he1 : ∀ i, exp i ≤ 2 ^ fe) (hT : (T : ℤ) * 2 ^ fe ≤ 2 ^ wrho) (t : Fin T) (s : Fin T → ℤ)
    (hs : ∀ j, -127 ≤ s j ∧ s j ≤ 127) (s8 : Fin T → GF) (hs8 : ∀ j, s8 j = (s j : GF)) (P : Fin T → GF) :
    (∃ mx sum : GF, ∃ zsel e : Fin T → GF, SoftmaxRowRel fp wrho exp t s8 mx sum zsel e P) ↔
      ∃ pv, softmaxF fp wrho exp t s = some pv ∧ ∀ j, P j = (pv j : GF) := by
  have hW : (2 : ℤ) ^ wrho ≤ 2 ^ 24 := pow_le_pow_right₀ (by norm_num) hw
  obtain ⟨htot0, htot1⟩ := totalOf_bounds fe exp he0 he1 t s
  have hsm : ∀ j, -127 ≤ smOf t s j ∧ smOf t s j ≤ 127 := by
    intro j
    unfold smOf maskScore
    by_cases h : j ≤ t
    · rw [ite_eq_left h]; exact hs j
    · rw [ite_eq_right h]; constructor <;> norm_num
  have hmemt : t ∈ Finset.univ.filter fun j : Fin T => j ≤ t := by simp
  constructor
  · rintro ⟨mx, sum, zsel, e, hexp, -, hc1, hsum, hz, hdiv⟩
    -- the exp tuples: every δ_j is an index `ii j`, and `e_j = exp (ii j)`
    have hexp' := fun j => (expQuery_iff exp _ _).mp (hexp j)
    choose ii hii0 hii1 hiiδ hiie using hexp'
    have hδ : ∀ j, mx - ((smOf t s j : ℤ) : GF) = ((ii j : ℤ) : GF) := fun j => by
      rw [← delta_eq t j s s8 (hs8 j) mx]; exact hiiδ j
    have hzδ : ∀ j, zsel j * (mx - ((smOf t s j : ℤ) : GF)) = 0 := fun j => by
      rw [← delta_eq t j s s8 (hs8 j) mx]; exact hc1 j
    obtain ⟨j0, hmax, -, hd⟩ := rowmax_gf (smOf t s) hsm mx ii (fun j => ⟨hii0 j, hii1 j⟩) hδ zsel hz hzδ
    -- the committed maximum is the live maximum
    have hbest : bestOf t s = smOf t s j0 := by
      apply le_antisymm
      · refine (Finset.sup'_le_iff _ _).mpr fun j hj => ?_
        have hjt : j ≤ t := (Finset.mem_filter.mp hj).2
        have h1 : smOf t s j = s j := by unfold smOf; rw [ite_eq_left hjt]
        rw [← h1]
        exact hmax j
      · by_cases hj0 : j0 ≤ t
        · have h1 : smOf t s j0 = s j0 := by unfold smOf; rw [ite_eq_left hj0]
          rw [h1]
          have hm : j0 ∈ Finset.univ.filter fun j : Fin T => j ≤ t := Finset.mem_filter.mpr ⟨Finset.mem_univ _, hj0⟩
          exact Finset.le_sup' s hm
        · have h1 : smOf t s j0 = maskScore := by unfold smOf; rw [ite_eq_right hj0]
          have h2 : s t ≤ bestOf t s := Finset.le_sup' s hmemt
          rw [h1]
          unfold maskScore
          linarith [(hs t).1]
    have hii : ∀ j, ii j = bestOf t s - smOf t s j := fun j => by rw [hd j, hbest]
    have he : ∀ j, e j = ((expRow exp t s j : ℤ) : GF) := fun j => by
      rw [hiie j, hii j]; rfl
    have hsumc : sum = ((totalOf exp t s : ℤ) : GF) := by
      rw [← hsum]
      unfold totalOf
      rw [Int.cast_sum]
      refine Finset.sum_congr rfl fun j _ => ?_
      rw [he j, mask_e_eq t j exp s]
    -- the total is positive: `c3` at the diagonal column with its two range facts
    have hpos : 1 ≤ totalOf exp t s := by
      obtain ⟨⟨sr, sg, ⟨-, h3⟩, hsr, hsg⟩, -⟩ := hdiv t
      obtain ⟨a, ha0, ha1, rfl⟩ := (remW16_iff wrho sr).mp hsr
      obtain ⟨b, hb0, hb1, rfl⟩ := (remW16_iff wrho sg).mp hsg
      rw [hsumc] at h3
      have e3 : ((b + a + 1 - totalOf exp t s : ℤ) : GF) = 0 := by push_cast; linear_combination h3
      have := int_eq_zero_of_cast e3 (by linarith) (by linarith)
      linarith
    have hidx : ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256 := fun j => by
      rw [← hii j]; exact ⟨hii0 j, hii1 j⟩
    -- each column's division
    have hcol : ∀ j, P j = ((numOf fp exp t s j / totalOf exp t s : ℤ) : GF) := fun j => by
      obtain ⟨hn0, hn1⟩ := num_bounds fp exp he0 t j s
      refine (softmaxDiv_iff fp wrho hfp hw _ _ hn0 hn1 hpos (le_trans htot1 hT) (P j)).mp ?_
      have hj := hdiv j
      rw [he j, num_eq fp t j exp s, hsumc] at hj
      exact hj
    refine ⟨fun j => numOf fp exp t s j / totalOf exp t s, ?_, hcol⟩
    unfold softmaxF
    rw [ite_eq_left (show 0 < totalOf exp t s ∧ ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256 from
      ⟨by linarith, hidx⟩)]
    exact liftO_eq_some.mpr fun j =>
      ite_eq_left (softmax_sg_window wrho (numOf fp exp t s j) _ hpos (le_trans htot1 hT))
  · rintro ⟨pv, hpv, hP⟩
    unfold softmaxF at hpv
    by_cases hcond : 0 < totalOf exp t s ∧ ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256
    · rw [ite_eq_left hcond] at hpv
      obtain ⟨htpos, hidx⟩ := hcond
      have hpos : 1 ≤ totalOf exp t s := htpos
      have hcol : ∀ j, pv j = numOf fp exp t s j / totalOf exp t s := fun j => by
        have h : (if totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
            then some (numOf fp exp t s j / totalOf exp t s) else none) = some (pv j) := liftO_eq_some.mp hpv j
        by_cases hwin : totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
        · rw [ite_eq_left hwin] at h; exact (Option.some.inj h).symm
        · rw [ite_eq_right hwin] at h; cases h
      obtain ⟨j0, hj0, hj0b⟩ := Finset.exists_mem_eq_sup' ⟨t, hmemt⟩ s
      have hj0t : j0 ≤ t := (Finset.mem_filter.mp hj0).2
      have hb0 : bestOf t s = s j0 := hj0b
      refine ⟨((bestOf t s : ℤ) : GF), ((totalOf exp t s : ℤ) : GF), zselOf j0, eOf exp t s, ?_, ?_, ?_, ?_, ?_, ?_⟩
      · intro j
        rw [delta_eq t j s s8 (hs8 j)]
        exact (expQuery_iff exp _ _).mpr ⟨bestOf t s - smOf t s j, (hidx j).1, (hidx j).2,
          by push_cast; ring, rfl⟩
      · intro j
        unfold zselOf
        by_cases hj : j = j0
        · rw [ite_eq_left hj]; ring
        · rw [ite_eq_right hj]; ring
      · intro j
        rw [delta_eq t j s s8 (hs8 j)]
        unfold zselOf
        by_cases hj : j = j0
        · rw [ite_eq_left hj, hj]
          have h1 : smOf t s j0 = s j0 := by unfold smOf; rw [ite_eq_left hj0t]
          rw [h1, hb0]
          ring
        · rw [ite_eq_right hj]; ring
      · unfold totalOf
        rw [Int.cast_sum]
        exact Finset.sum_congr rfl fun j _ => mask_e_eq t j exp s
      · simp [zselOf]
      · intro j
        obtain ⟨hn0, hn1⟩ := num_bounds fp exp he0 t j s
        have h := (softmaxDiv_iff fp wrho hfp hw _ _ hn0 hn1 hpos (le_trans htot1 hT) (P j)).mpr
          (by rw [hP j, hcol j])
        have hnum : maskF t j * eOf exp t s j * 2 ^ fp = ((numOf fp exp t s j : ℤ) : GF) := num_eq fp t j exp s
        rw [hnum]
        exact h
    · rw [ite_eq_right hcond] at hpv
      cases hpv

/-- The quotients of an admitted softmax row lie in `[0, 2^f_p]`. -/
theorem softmaxF_class (fp wrho : ℕ) (exp : ℤ → ℤ) (he0 : ∀ i, 0 ≤ exp i) (t : Fin T) (s : Fin T → ℤ)
    {pv : Fin T → ℤ} (h : softmaxF fp wrho exp t s = some pv) (j : Fin T) : 0 ≤ pv j ∧ pv j ≤ 2 ^ fp := by
  unfold softmaxF at h
  by_cases hcond : 0 < totalOf exp t s ∧ ∀ j, 0 ≤ bestOf t s - smOf t s j ∧ bestOf t s - smOf t s j < 256
  · rw [ite_eq_left hcond] at h
    have hj : (if totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
        then some (numOf fp exp t s j / totalOf exp t s) else none) = some (pv j) := liftO_eq_some.mp h j
    by_cases hwin : totalOf exp t s - 1 - numOf fp exp t s j % totalOf exp t s < 2 ^ wrho
    · rw [ite_eq_left hwin] at hj
      have hpv : numOf fp exp t s j / totalOf exp t s = pv j := Option.some.inj hj
      obtain ⟨hn0, hn1⟩ := num_bounds fp exp he0 t j s
      have hpos : 0 < totalOf exp t s := hcond.1
      rw [← hpv]
      exact ⟨Int.ediv_nonneg hn0 (le_of_lt hpos), Int.ediv_le_of_le_mul hpos hn1⟩
    · rw [ite_eq_right hwin] at hj; cases hj
  · rw [ite_eq_right hcond] at h; cases h

end ZK60.Circuit

