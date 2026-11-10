/-
D63 lane L49 (2026-11-10), sub-agent `look`, part 4: **R13's LogUp sum claim read in the field, and the sum of
`HelperRel`** (the R13 counterpart of lane L47's `logupSum_planes` and `hhr_sum`, BlockLookRelW16.lean), generic in the
configuration.

* `sgR`, `lsR`, `logupSumR13_parts`, `sgR_eq`, `sgR_canon`, `lsR_ge`, **`logupSumR13_empty`**: the claim's parts (signs
  `−1` exactly on the three table helpers `48 + ls … 50 + ls`; log sizes at least a row);
* `domAt`, **`domList_getD`**: the code's `H` plane list, plane by plane;
* `PSpR`, `fR`, **`logupSumR13_planes`**: the code's `logup_sum_claim` on the `H` matrix IS `Σ_hp sign_hp·Σ_cube H_hp`
  (lane L47's `claimSem_empty`, `sum_planeZ2`, which are generic);
* **`hhr_sumR`**: with `H_U`'s zero sum (`SC_ZS`), `Σ singles + Σ pairs − Σ table = 0` over this lane's index sets
  (`SgIx`, `PrIx`, `TbIx`), the helper of each single, pair and table position being the code's `H` plane.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookLk
import ZK60Formal.BlockLookSum
import ZK60Formal.BlockR13JoinTab

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (hPl)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Circuit (gP GF)
open Finset

/-! ## The claim's parts -/

/-- The sum claim's sign of `H` plane `hp` (`HIds::is_table`). -/
def sgR (c : W16Cfg) (hp : ℕ) : Fp2 :=
  if decide (DefR13.fh c 8 ≤ hp) && decide (hp < DefR13.fh c 8 + 3) then Fp2.one.neg else Fp2.one

/-- The log size of `H` plane `hp` (its domain's). -/
def lsR (c : W16Cfg) (hp : ℕ) : ℕ := c.sh.logs ((DefR13.hDoms c).getD hp .Tab)

theorem logupSumR13_parts (c : W16Cfg) : (logupSumR13 c).parts = (List.range (DefR13.hDoms c).length).flatMap
    fun hp => [(⟨(DefR13.hOff c hp).1, lsR c hp, sgR c hp, []⟩ : Block.ZPart),
      ⟨(DefR13.hOff c hp).2, lsR c hp, (sgR c hp).mul fp2U, []⟩] := rfl

theorem sgR_eq {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (hp : ℕ) :
    sgR c hp = if 48 + ls ≤ hp ∧ hp < 51 + ls then Fp2.one.neg else Fp2.one := by
  unfold sgR
  rw [(fh_eq hc).2.2.2.2.2.2.2.2.1]
  by_cases h : 48 + ls ≤ hp ∧ hp < 51 + ls
  · rw [ite_eq_left h]
    simp [h.1, show hp < 48 + ls + 3 by omega]
  · rw [ite_eq_right h]
    by_cases h3 : 48 + ls ≤ hp
    · simp [h3, show ¬ (hp < 48 + ls + 3) by omega]
    · simp [h3]

theorem sgR_canon (c : W16Cfg) (hp : ℕ) : (sgR c hp).Canon := by
  unfold sgR
  split_ifs
  · exact And.intro (Fp.neg_canon _ Fp2.canon_one.1) (Fp.neg_canon _ Fp2.canon_one.2)
  · exact Fp2.canon_one

/-- Every `H` domain but `Dom::T` and `Dom::Ht` is at least one row. -/
theorem log14 {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (d : Dom) (h1 : d ≠ .T) (h2 : d ≠ .Ht) :
    14 ≤ c.sh.logs d := by
  cases d
  · exact absurd rfl h1
  · exact absurd rfl h2
  · exact hc.logL.ge
  · exact hc.logD
  · exact hc.logQ
  · exact hc.logK
  · exact hc.logS
  · exact hc.logF
  · exact hc.logTab.ge

theorem lsR_ge {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (hp : ℕ) : 14 ≤ lsR c hp := by
  unfold lsR
  rw [hDoms_eq hc, List.getD_eq_getElem?_getD]
  cases h : (domList ls)[hp]? with
  | none => exact log14 hc .Tab (by decide) (by decide)
  | some d =>
    have hm : d ∈ domList ls := List.mem_of_getElem? h
    have hT : d ≠ .T := by
      rintro rfl
      simp [domList] at hm
    have hH : d ≠ .Ht := by
      rintro rfl
      simp [domList] at hm
    exact log14 hc d hT hH

/-- **The claim's parts have empty points and slices at least a row wide.** -/
theorem logupSumR13_empty {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) : W16.Look.EmptyParts 14 (logupSumR13 c) := by
  intro q hq
  rw [logupSumR13_parts] at hq
  obtain ⟨hp, -, hq⟩ := List.mem_flatMap.mp hq
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with rfl | rfl
  · exact ⟨rfl, lsR_ge hc hp, sgR_canon c hp⟩
  · exact ⟨rfl, lsR_ge hc hp, Fp2.canon_mul _ _⟩

/-! ## The `H` plane list, plane by plane -/

/-- The domain of `H` plane `hp` (`Dom::Tab` past the end, as `getD` reads it). -/
def domAt (ls hp : ℕ) : Dom :=
  if hp < 1 then .L else if hp < 18 then .D else if hp < 25 then .Q else if hp < 32 then .Kv
  else if hp < 40 + ls then .S else if hp < 48 + ls then .F else .Tab

theorem domList_getD (ls hp : ℕ) : (domList ls).getD hp .Tab = domAt ls hp := by
  unfold domList domAt
  simp only [List.getD_eq_getElem?_getD, List.append_assoc, List.singleton_append, List.getElem?_append,
    List.length_replicate, List.length_cons, List.getElem?_replicate, List.getElem?_cons, List.getElem?_nil]
  split_ifs <;> first | rfl | (exfalso; omega)

/-! ## The claim read in the field -/

section Sum

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- An `H` plane's sum over its cube. -/
noncomputable def PSpR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hp log : ℕ) : K :=
  ∑ b : Fin log → Bool, hPl U P D (DefR13.hOff c hp).1 (DefR13.hOff c hp).2 log b

/-- The claim's summand at `H` plane `hp`. -/
noncomputable def fR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hp : ℕ) : K :=
  (sgR c hp).toK U * PSpR U c P D hp (lsR c hp)

theorem sum_flatMap2R {M : Type} [AddCommMonoid M] {α : Type} (a b : ℕ → α) (g : α → M) :
    ∀ L : List ℕ, ((L.flatMap fun x => [a x, b x]).map g).sum = (L.map fun x => g (a x) + g (b x)).sum
  | [] => rfl
  | x :: L => by
    rw [List.flatMap_cons, List.map_append, List.sum_append, sum_flatMap2R a b g L, List.map_cons, List.sum_cons]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]

theorem listSum_range {M : Type} [AddCommMonoid M] (f : ℕ → M) :
    ∀ n, ((List.range n).map f).sum = ∑ i ∈ range n, f i
  | 0 => by simp
  | n + 1 => by
    rw [List.range_succ, List.map_append, List.sum_append, listSum_range f n, Finset.sum_range_succ]
    simp

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The code's `logup_sum_claim` at R13, on the `H` matrix, is `Σ_hp sign_hp·Σ_cube H_hp`.** -/
theorem logupSumR13_planes {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (P : BlockParams) (D : CmData K P)
    (hln : rowLog P .h = 14) :
    Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumR13 c) = ∑ hp ∈ range (52 + ls), fR U c P D hp := by
  have he : W16.Look.EmptyParts (rowLog P .h) (logupSumR13 c) := by rw [hln]; exact logupSumR13_empty hc
  obtain ⟨q0, qs, hz⟩ : ∃ q0 qs, (logupSumR13 c).parts = q0 :: qs := by
    rw [logupSumR13_parts, hDoms_eq hc, domList_length, show 52 + ls = (51 + ls) + 1 by omega,
      List.range_succ_eq_map, List.flatMap_cons]
    exact ⟨_, _, rfl⟩
  rw [W16.Look.claimSem_empty U _ _ _ _ _ q0 qs hz he, logupSumR13_parts, hDoms_eq hc, domList_length, sum_flatMap2R,
    listSum_range]
  refine Finset.sum_congr rfl (fun hp _ => ?_)
  have hls := lsR_ge hc hp
  unfold fR PSpR
  rw [show (∑ b : Fin (lsR c hp) → Bool, hPl U P D (DefR13.hOff c hp).1 (DefR13.hOff c hp).2 (lsR c hp) b)
      = ∑ b : Fin (lsR c hp) → Bool, planeZ U (rowLog P .h) (D.rows .h) (D.Q .h) (D.X .h)
          ⟨.h, [((DefR13.hOff c hp).1, Fp2.one), ((DefR13.hOff c hp).2, fp2U)], lsR c hp, [], 0, 0⟩ b from rfl,
    W16.Look.sum_planeZ2 U (rowLog P .h) (D.rows .h) (D.Q .h) hln (D.X .h) .h _ _ (lsR c hp) hls [] 0 0,
    Fp2.toK_mul U hU]
  simp only [add_mul, Finset.sum_add_distrib, mul_assoc, ← Finset.mul_sum]
  ring

omit hU in
theorem toK_negOneR : (Fp2.one.neg).toK U = -1 := by
  rw [Fp2.toK_neg U _ Fp2.canon_one, Fp2.toK_one]

omit hU in
/-- A summand of the claim, by its plane's domain. -/
theorem fR_dom {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (P : BlockParams) (D : CmData K P) (hp : ℕ) (d : Dom)
    (hd : domAt ls hp = d) :
    fR U c P D hp = (if 48 + ls ≤ hp ∧ hp < 51 + ls then -1 else 1) * PSpR U c P D hp (c.sh.logs d) := by
  unfold fR lsR
  rw [hDoms_eq hc, domList_getD, hd, sgR_eq hc]
  split_ifs
  · rw [toK_negOneR]
  · rw [Fp2.toK_one]

/-- **The sum of `HelperRel` at R13, from the code's sum claim and `H_U`'s zero sum**: the singles' helpers (`Dom::S`'s
last helper, `sexp`, `fact`), the pairs' helpers (`first_d + j` at each domain's cube point) and the table helpers
(`gu8 + k`), summed over their cubes, give `Σ singles + Σ pairs − Σ table = 0`. -/
theorem hhr_sumR {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls) (P : BlockParams) (D : CmData K P)
    (hln : rowLog P .h = 14)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumR13 c) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D (DefR13.hOff c (DefR13.fh c 10)).1 (DefR13.hOff c (DefR13.fh c 10)).2 14 b
      = 0) :
    ∑ i : SgIx c, hPl U P D (DefR13.hOff c (i.1.hp ls)).1 (DefR13.hOff c (i.1.hp ls)).2 (i.1.log c) i.2
      + ∑ k : PrIx c ls, hPl U P D (DefR13.hOff c (k.1.fh ls + k.2.1)).1 (DefR13.hOff c (k.1.fh ls + k.2.1)).2
          (k.1.log c) k.2.2
      - ∑ j : TbIx, R13T.helpTabR U c P D j.1 j.2 = 0 := by
  rw [logupSumR13_planes U hU hc P D hln] at hcl
  have hf8 : DefR13.fh c 8 = 48 + ls := (fh_eq hc).2.2.2.2.2.2.2.2.1
  have hf10 : DefR13.fh c 10 = 51 + ls := (fh_eq hc).2.2.2.2.2.2.2.2.2
  -- the claim, cut at the code's helper blocks
  have c1 : ∑ x ∈ range (52 + ls), fR U c P D x = ∑ x ∈ range (51 + ls), fR U c P D x + fR U c P D (51 + ls) := by
    rw [show 52 + ls = 51 + ls + 1 by omega, Finset.sum_range_succ]
  have c2 : ∑ x ∈ range (51 + ls), fR U c P D x
      = ∑ x ∈ range (48 + ls), fR U c P D x + ∑ x ∈ range 3, fR U c P D (48 + ls + x) := by
    rw [show 51 + ls = 48 + ls + 3 by omega, Finset.sum_range_add]
  have c3 : ∑ x ∈ range (48 + ls), fR U c P D x = ∑ x ∈ range (47 + ls), fR U c P D x + fR U c P D (47 + ls) := by
    rw [show 48 + ls = 47 + ls + 1 by omega, Finset.sum_range_succ]
  have c4 : ∑ x ∈ range (47 + ls), fR U c P D x
      = ∑ x ∈ range (40 + ls), fR U c P D x + ∑ x ∈ range 7, fR U c P D (40 + ls + x) := by
    rw [show 47 + ls = 40 + ls + 7 by omega, Finset.sum_range_add]
  have c5 : ∑ x ∈ range (40 + ls), fR U c P D x = ∑ x ∈ range (39 + ls), fR U c P D x + fR U c P D (39 + ls) := by
    rw [show 40 + ls = 39 + ls + 1 by omega, Finset.sum_range_succ]
  have c6 : ∑ x ∈ range (39 + ls), fR U c P D x = ∑ x ∈ range (38 + ls), fR U c P D x + fR U c P D (38 + ls) := by
    rw [show 39 + ls = 38 + ls + 1 by omega, Finset.sum_range_succ]
  have c7 : ∑ x ∈ range (38 + ls), fR U c P D x
      = ∑ x ∈ range 32, fR U c P D x + ∑ x ∈ range (6 + ls), fR U c P D (32 + x) := by
    rw [show 38 + ls = 32 + (6 + ls) by omega, Finset.sum_range_add]
  have c8 : ∑ x ∈ range 32, fR U c P D x = ∑ x ∈ range 25, fR U c P D x + ∑ x ∈ range 7, fR U c P D (25 + x) :=
    Finset.sum_range_add (fR U c P D) 25 7
  have c9 : ∑ x ∈ range 25, fR U c P D x = ∑ x ∈ range 18, fR U c P D x + ∑ x ∈ range 7, fR U c P D (18 + x) :=
    Finset.sum_range_add (fR U c P D) 18 7
  have c10 : ∑ x ∈ range 18, fR U c P D x = ∑ x ∈ range 1, fR U c P D x + ∑ x ∈ range 17, fR U c P D (1 + x) :=
    Finset.sum_range_add (fR U c P D) 1 17
  rw [c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, Finset.sum_range_one] at hcl
  -- each block, by its domain and sign
  have dom : ∀ hp d, domAt ls hp = d → (if 48 + ls ≤ hp ∧ hp < 51 + ls then (-1 : K) else 1) = 1 →
      fR U c P D hp = PSpR U c P D hp (c.sh.logs d) := by
    intro hp d hd hs
    rw [fR_dom U hc P D hp d hd, hs, one_mul]
  have bL : fR U c P D 0 = ∑ j ∈ range (Dm.np ls .L), PSpR U c P D (Dm.fh ls .L + j) (Dm.log c .L) := by
    rw [show Dm.np ls .L = 1 from rfl, Finset.sum_range_one]
    exact dom 0 .L (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bD : ∑ x ∈ range 17, fR U c P D (1 + x)
      = ∑ j ∈ range (Dm.np ls .D), PSpR U c P D (Dm.fh ls .D + j) (Dm.log c .D) := by
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 17 := Finset.mem_range.mp hx
    exact dom _ .D (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bQ : ∑ x ∈ range 7, fR U c P D (18 + x)
      = ∑ j ∈ range (Dm.np ls .Q), PSpR U c P D (Dm.fh ls .Q + j) (Dm.log c .Q) := by
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 7 := Finset.mem_range.mp hx
    exact dom _ .Q (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bK : ∑ x ∈ range 7, fR U c P D (25 + x)
      = ∑ j ∈ range (Dm.np ls .Kv), PSpR U c P D (Dm.fh ls .Kv + j) (Dm.log c .Kv) := by
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 7 := Finset.mem_range.mp hx
    exact dom _ .Kv (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bS : ∑ x ∈ range (6 + ls), fR U c P D (32 + x)
      = ∑ j ∈ range (Dm.np ls .S), PSpR U c P D (Dm.fh ls .S + j) (Dm.log c .S) := by
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 6 + ls := Finset.mem_range.mp hx
    exact dom _ .S (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bF : ∑ x ∈ range 7, fR U c P D (40 + ls + x)
      = ∑ j ∈ range (Dm.np ls .F), PSpR U c P D (Dm.fh ls .F + j) (Dm.log c .F) := by
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 7 := Finset.mem_range.mp hx
    exact dom _ .F (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have sS : fR U c P D (38 + ls) = PSpR U c P D (Sg.hp ls .S) (Sg.log c .S) :=
    dom _ .S (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have sE : fR U c P D (39 + ls) = PSpR U c P D (Sg.hp ls .Exp) (Sg.log c .Exp) :=
    dom _ .S (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have sA : fR U c P D (47 + ls) = PSpR U c P D (Sg.hp ls .Act) (Sg.log c .Act) :=
    dom _ .F (by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)) (ite_eq_right (by omega))
  have bT : ∑ x ∈ range 3, fR U c P D (48 + ls + x) = -∑ k ∈ range 3, PSpR U c P D (DefR13.fh c 8 + k) 14 := by
    rw [← Finset.sum_neg_distrib]
    refine Finset.sum_congr rfl (fun x hx => ?_)
    have hx' : x < 3 := Finset.mem_range.mp hx
    have hd : domAt ls (48 + ls + x) = .Tab := by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)
    have hs : 48 + ls ≤ 48 + ls + x ∧ 48 + ls + x < 51 + ls := ⟨by omega, by omega⟩
    rw [fR_dom U hc P D _ .Tab hd, ite_eq_left hs, hc.logTab, hf8, neg_one_mul]
  have sU : fR U c P D (51 + ls) = 0 := by
    have hd : domAt ls (51 + ls) = .Tab := by unfold domAt; split_ifs <;> first | rfl | (exfalso; omega)
    have hs : ¬ (48 + ls ≤ 51 + ls ∧ 51 + ls < 51 + ls) := by omega
    rw [dom (51 + ls) .Tab hd (ite_eq_right hs), hc.logTab]
    unfold PSpR
    rw [← hf10]
    exact hzs
  rw [bL, bD, bQ, bK, bS, bF, sS, sE, sA, bT, sU] at hcl
  -- the goal's three sums, by blocks
  have gS : ∑ i : SgIx c, hPl U P D (DefR13.hOff c (i.1.hp ls)).1 (DefR13.hOff c (i.1.hp ls)).2 (i.1.log c) i.2
      = PSpR U c P D (Sg.hp ls .S) (Sg.log c .S)
        + (PSpR U c P D (Sg.hp ls .Exp) (Sg.log c .Exp) + PSpR U c P D (Sg.hp ls .Act) (Sg.log c .Act)) := by
    rw [Fintype.sum_sigma, sum_sg]
    rfl
  have gP : ∑ k : PrIx c ls, hPl U P D (DefR13.hOff c (k.1.fh ls + k.2.1)).1 (DefR13.hOff c (k.1.fh ls + k.2.1)).2
      (k.1.log c) k.2.2 = ∑ d : Dm, ∑ j ∈ range (d.np ls), PSpR U c P D (d.fh ls + j) (d.log c) := by
    rw [Fintype.sum_sigma]
    refine Finset.sum_congr rfl (fun d _ => ?_)
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun j => PSpR U c P D (d.fh ls + j) (d.log c)) (d.np ls)
  have gT : ∑ j : TbIx, R13T.helpTabR U c P D j.1 j.2 = ∑ k ∈ range 3, PSpR U c P D (DefR13.fh c 8 + k) 14 := by
    rw [Fintype.sum_prod_type]
    exact Fin.sum_univ_eq_sum_range (fun k => PSpR U c P D (DefR13.fh c 8 + k) 14) 3
  rw [gS, gP, gT, sum_dm]
  linear_combination hcl

end Sum

end ZK60.Exec.Block.Join.R13H.Look
