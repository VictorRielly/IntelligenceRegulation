/-
D63 lane L49 (2026-11-10), sub-agent `look`, part 3: **every logical lookup of the R13 block is an entry of the code's
lookup list** (lane L36's `hcov` at R13, PROVED, generic in the configuration), by lane L47's W16R2 pattern
(`BlockLookCov.lean`, `BlockLookCov2.lean`).

* `lt_of_getD`, **`exists_lkR`**: every lookup of the code's list (at every point of its domain's cube) is an entry of
  `AlkR13` (the pairs `2j`, `2j + 1`, `Dom::S`'s single);
* `aPl_castB`, `covR1`, `covP`, `covByte`, `covBytes`, `covPin`: a one-term code lookup's tuple at a cube point IS the
  range query of the plane it reads, on a base-valued `A` matrix, the cube point given as its product point;
* `covLimbR`: an isqrt limb (a `2^lt`-entry sub-slice of `Dom::L`) is the code's `Dom::L` byte lookup at the same entry;
* `covExp`, `covAct`: the exp and ACT tuples;
* `getD_appL`, `getD_appR`, `getD_mapRange`, `lkS_sr`, `lkS_sg`, …: the code's `Dom::S` list at `ls + 1` softmax limbs;
* **`cover_xtR`**: every field of `R13LookupsG` asks, at every position, a tuple that IS an entry of `AlkR13` (read on
  data whose `A` planes are the extracted ones), at the shape's precision (`PrecR c S`, finding L47-5);
* **`hcov_r13`**: lane L36's `hcov` in the exact form of `block_knowledge_join_r13_rung` / `_shield`, for `AlkR13` on the
  data the `A` cut fixes (`dofAR`), on every outcome.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB aPl_alg)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Circuit (gP GF tagW tagExp tagAct rangeQuery expQuery actQuery)
open ZK60.Layout
open ZK60.Layout.R13 (R13Data)

/-! ## List facts -/

theorem lt_of_getD (l : List LkW) (n q : ℕ) (cf cst : ℤ) (w : ℕ)
    (h : l.getD n ⟨[], 0, 0⟩ = ⟨[(q, cf)], cst, w⟩) : n < l.length := by
  by_contra hn
  rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by omega)] at h
  have := congrArg LkW.terms h
  simp at this

theorem getD_appL {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : n < l.length) : (l ++ l').getD n d = l.getD n d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_left h]

theorem getD_appR {α : Type} (l l' : List α) (d : α) (n : ℕ) (h : l.length ≤ n) :
    (l ++ l').getD n d = l'.getD (n - l.length) d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_right h]

theorem getD_mapRange {α : Type} (f : ℕ → α) (s n k : ℕ) (d : α) (hk : k < n) :
    ((List.range' s n).map f).getD k d = f (s + k) := by
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range' hk, Nat.one_mul]
  rfl

/-- The head of `Dom::S`'s list (`S8`'s pair, `RSL` + pin, `PL` + pin). -/
def lkS0 (p : ZK60.Exec.Slot.Build.Lay.PrecW) : List LkW :=
  [⟨[(75, 1)], 127, 8⟩, ⟨[(75, -1)], 127, 8⟩, bLk 76, bLk 77, bLk 78, pLk 78 (8 * 3 - p.score), bLk 82, bLk 83,
    pLk 83 (8 * 2 - (p.fp + 1))]

theorem lkSe_eq (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) : lkSe p ls = lkS0 p
    ++ ((List.range' 84 (ls + 1)).map bLk ++ [pLk (84 + ls) (8 * (ls + 1) - p.wrho)])
    ++ ((List.range' (84 + (ls + 1)) (ls + 1)).map bLk ++ [pLk (84 + (ls + 1) + ls) (8 * (ls + 1) - p.wrho)]) := rfl

theorem lkS0_len (p : ZK60.Exec.Slot.Build.Lay.PrecW) : (lkS0 p).length = 9 := rfl

theorem lkSe_head (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls i : ℕ) (hi : i < 9) :
    (lkSe p ls).getD i ⟨[], 0, 0⟩ = (lkS0 p).getD i ⟨[], 0, 0⟩ := by
  rw [lkSe_eq, getD_appL _ _ _ _ (by simp only [List.length_append, lkS0_len]; omega),
    getD_appL _ _ _ _ (by rw [lkS0_len]; exact hi)]

/-- `SR`'s byte `k`. -/
theorem lkSe_sr (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls k : ℕ) (hk : k < ls + 1) :
    (lkSe p ls).getD (9 + k) ⟨[], 0, 0⟩ = bLk (84 + k) := by
  rw [lkSe_eq, getD_appL _ _ _ _ (by simp only [List.length_append, lkS0_len, List.length_map, List.length_range',
      List.length_cons, List.length_nil]; omega),
    getD_appR _ _ _ _ (by rw [lkS0_len]; omega), lkS0_len, show 9 + k - 9 = k by omega,
    getD_appL _ _ _ _ (by simp only [List.length_map, List.length_range']; exact hk), getD_mapRange _ _ _ _ _ hk]

/-- `SR`'s pin. -/
theorem lkSe_srPin (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) :
    (lkSe p ls).getD (9 + (ls + 1)) ⟨[], 0, 0⟩ = pLk (84 + ls) (8 * (ls + 1) - p.wrho) := by
  rw [lkSe_eq, getD_appL _ _ _ _ (by simp only [List.length_append, lkS0_len, List.length_map, List.length_range',
      List.length_cons, List.length_nil]; omega),
    getD_appR _ _ _ _ (by rw [lkS0_len]; omega), lkS0_len, show 9 + (ls + 1) - 9 = ls + 1 by omega,
    getD_appR _ _ _ _ (by simp only [List.length_map, List.length_range']; omega)]
  simp only [List.length_map, List.length_range', Nat.sub_self]
  rfl

/-- The length of `Dom::S`'s list before `SG`. -/
theorem lkS0_sr_len (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) :
    (lkS0 p ++ ((List.range' 84 (ls + 1)).map bLk ++ [pLk (84 + ls) (8 * (ls + 1) - p.wrho)])).length
      = 9 + (ls + 2) := by
  simp only [List.length_append, lkS0_len, List.length_map, List.length_range', List.length_cons, List.length_nil]

/-- `SG`'s byte `k`. -/
theorem lkSe_sg (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls k : ℕ) (hk : k < ls + 1) :
    (lkSe p ls).getD (9 + (ls + 2) + k) ⟨[], 0, 0⟩ = bLk (84 + (ls + 1) + k) := by
  rw [lkSe_eq, getD_appR _ _ _ _ (by rw [lkS0_sr_len]; omega), lkS0_sr_len,
    show 9 + (ls + 2) + k - (9 + (ls + 2)) = k by omega,
    getD_appL _ _ _ _ (by simp only [List.length_map, List.length_range']; exact hk), getD_mapRange _ _ _ _ _ hk]

/-- `SG`'s pin. -/
theorem lkSe_sgPin (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) :
    (lkSe p ls).getD (9 + (ls + 2) + (ls + 1)) ⟨[], 0, 0⟩ = pLk (84 + (ls + 1) + ls) (8 * (ls + 1) - p.wrho) := by
  rw [lkSe_eq, getD_appR _ _ _ _ (by rw [lkS0_sr_len]; omega), lkS0_sr_len,
    show 9 + (ls + 2) + (ls + 1) - (9 + (ls + 2)) = ls + 1 by omega,
    getD_appR _ _ _ _ (by simp only [List.length_map, List.length_range']; omega)]
  simp only [List.length_map, List.length_range', Nat.sub_self]
  rfl

/-! ## The lists at `Dm`'s domains -/

section DmL

variable {c : W16Cfg} {ls : ℕ} (hc : LookCfg c ls)
include hc

theorem lkL' : DefR13.lookups c Dm.L.dom = lkLe := hc.lkL
theorem lkD' : DefR13.lookups c Dm.D.dom = lkDe c.p := hc.lkD
theorem lkQ' : DefR13.lookups c Dm.Q.dom = lkQe c.p := hc.lkQ
theorem lkK' : DefR13.lookups c Dm.Kv.dom = lkKe c.p := hc.lkK
theorem lkS' : DefR13.lookups c Dm.S.dom = lkSe c.p ls := hc.lkS
theorem lkF' : DefR13.lookups c Dm.F.dom = lkFe c.p ls := hc.lkF

end DmL

/-! ## Every code lookup is an entry of the list -/

section Alk

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) {ls : ℕ} (G : GeoR c ls)
  (hc : LookCfg c ls) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig))

include hc in
/-- **Every lookup of a domain, at every point of its cube, is an entry of the list.** -/
theorem exists_lkR (d : Dm) (i : ℕ) (hi : i < (DefR13.lookups c d.dom).length) (b : Fin (d.log c) → Bool) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = lkAtR U c P (Dof cut) d i b := by
  rw [lkLen hc d] at hi
  by_cases h2 : i < 2 * d.np ls
  · obtain ⟨j, rfl | rfl⟩ := Nat.even_or_odd' i
    · exact ⟨.inr (.inl ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
    · exact ⟨.inr (.inr ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
  · by_cases hS : d = .S
    · subst hS
      rw [ite_eq_left rfl] at hi
      obtain rfl : i = 2 * Dm.np ls .S := by omega
      exact ⟨.inl ⟨.S, b⟩, rfl⟩
    · rw [ite_eq_right hS] at hi
      exfalso
      omega

end Alk

/-! ## A code lookup's tuple is its plane's range query -/

section Cov

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) {ls : ℕ} (G : GeoR c ls)
  (hc : LookCfg c ls) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

/-- A plane read at a cast point is the plane at the point. -/
theorem aPl_castB (D' : CmData K P) (off : ℕ) {m n : ℕ} (h : m = n) (v : Fin m → Bool) :
    aPl U P D' off n (castB h v) = aPl U P D' off m v := by
  subst h
  rfl

include hc hD in
/-- **A one-term lookup of the code's list covers the range query of the value it reads.** -/
theorem covR1 (d : Dm) (i q : ℕ) (cf cst : ℤ) (w : ℕ)
    (hl : (DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, cf)], cst, w⟩) (b : Fin (d.log c) → Bool) (x : GF)
    (hx : algebraMap GF K x = (cf : K) * aPl U P D (DefR13.aOff c q) (d.log c) b + (cst : K)) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (rangeQuery (tagW w) x) := by
  obtain ⟨l, hl'⟩ := exists_lkR U P Pb Lay B G hc Dof cut d i (lt_of_getD _ _ _ _ _ _ hl) b
  refine ⟨l, ?_⟩
  rw [hl']
  unfold lkAtR lkTupR
  rw [hl]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, hD, tupK, rangeQuery, hx,
    map_natCast, map_zero]

include hc hD in
/-- The same at a product point `v` of the domain's cube (`d.log c = n`). -/
theorem covP (d : Dm) {n : ℕ} (hn : d.log c = n) (i q : ℕ) (cf cst : ℤ) (w : ℕ)
    (hl : (DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, cf)], cst, w⟩) (v : Fin n → Bool) (x : GF)
    (hx : algebraMap GF K x = (cf : K) * aPl U P D (DefR13.aOff c q) n v + (cst : K)) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (rangeQuery (tagW w) x) :=
  covR1 U P Pb Lay B G hc Dof cut D hD d i q cf cst w hl (castB hn.symm v) x
    (by rw [aPl_castB U P D _ hn.symm v]; exact hx)

include hc hD hX in
/-- A byte lookup `bLk q`. -/
theorem covByte (d : Dm) {n : ℕ} (hn : d.log c = n) (i q : ℕ)
    (hl : (DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩ = bLk q) (v : Fin n → Bool) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (rangeQuery (tagW 8) (piB K (aPl U P D (DefR13.aOff c q) n v))) :=
  covP U P Pb Lay B G hc Dof cut D hD d hn i q 1 0 8 hl v _ (by
    rw [aPl_alg U P D hX]
    push_cast
    ring)

include hc hD hX in
/-- A byte group `bLk (q0 + k)` at the indices `i0 + k`. -/
theorem covBytes (d : Dm) {n : ℕ} (hn : d.log c = n) (i0 q0 m : ℕ)
    (hl : ∀ k < m, (DefR13.lookups c d.dom).getD (i0 + k) ⟨[], 0, 0⟩ = bLk (q0 + k)) (v : Fin n → Bool) (k : Fin m) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l
      = tupK (rangeQuery (tagW 8) (piB K (aPl U P D (DefR13.aOff c (q0 + k)) n v))) :=
  covByte U P Pb Lay B G hc Dof cut D hD hX d hn (i0 + k) (q0 + k) (hl k k.isLt) v

include hc hD hX in
/-- A top pin `pLk q e`. -/
theorem covPin (d : Dm) {n : ℕ} (hn : d.log c = n) (i q e : ℕ)
    (hl : (DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩ = pLk q e) (v : Fin n → Bool) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l
      = tupK (rangeQuery (tagW 8) (2 ^ e * piB K (aPl U P D (DefR13.aOff c q) n v))) :=
  covP U P Pb Lay B G hc Dof cut D hD d hn i q (2 ^ e) 0 8 hl v _ (by
    rw [map_mul, map_pow, map_ofNat, aPl_alg U P D hX]
    push_cast
    ring)

include hc hD hX in
/-- An int8 byte with a constant (`±plane + 127`). -/
theorem covSym (d : Dm) {n : ℕ} (hn : d.log c = n) (i q : ℕ) (sg : ℤ)
    (hl : (DefR13.lookups c d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, sg)], 127, 8⟩) (v : Fin n → Bool) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l
      = tupK (rangeQuery (tagW 8) ((sg : GF) * piB K (aPl U P D (DefR13.aOff c q) n v) + 127)) :=
  covP U P Pb Lay B G hc Dof cut D hD d hn i q sg 127 8 hl v _ (by
    rw [map_add, map_mul, map_intCast, map_ofNat, aPl_alg U P D hX]
    push_cast
    ring)

include hc hD hX G in
/-- **An isqrt limb of `Dom::L`** (sub-slice `3i + k` of `2^lt` entries) is the code's byte lookup of `Dom::L` at the
same entry. -/
theorem covLimbR (hlc : P.logCols = 14) (j q : ℕ) (hl : (DefR13.lookups c .L).getD j ⟨[], 0, 0⟩ = bLk q)
    (i k : Fin 3) (t : CtR c) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (rangeQuery (tagW 8)
      (piB K (aPl U P D (DefR13.aOff c q + (3 * (i : ℕ) + k) * 2 ^ c.sh.lt) c.sh.lt t))) := by
  have hr0 : rowLog P .a = 14 := hlc
  have hP : 2 ^ c.sh.lt ≤ 2 ^ 10 := Nat.pow_le_pow_right (by norm_num) hc.lt10
  have h10 : (2 : ℕ) ^ 10 = 1024 := by norm_num
  have h14 : (2 : ℕ) ^ 14 = 16384 := by norm_num
  rw [h10] at hP
  have ht := msbIndex_lt c.sh.lt t
  have hs : (3 * (i : ℕ) + k) * 2 ^ c.sh.lt ≤ 8 * 2 ^ c.sh.lt :=
    Nat.mul_le_mul_right _ (by have := i.isLt; have := k.isLt; omega)
  obtain ⟨X, hX0⟩ : ∃ X, DefR13.aOff c q = X * 2 ^ 14 := ⟨_, by unfold DefR13.aOff; rw [G.lc]⟩
  rw [h14] at hX0
  have hidx : (3 * (i : ℕ) + k) * 2 ^ c.sh.lt + msbIndex c.sh.lt t < 2 ^ 14 := by rw [h14]; omega
  refine covP U P Pb Lay B G hc Dof cut D hD .L hc.logL j q 1 0 8 hl
    (msbBits 14 ((3 * (i : ℕ) + k) * 2 ^ c.sh.lt + msbIndex c.sh.lt t)) _ ?_
  rw [aPl_alg U P D hX]
  rw [W16.Look.aPl_flat U P D (DefR13.aOff c q + (3 * (i : ℕ) + k) * 2 ^ c.sh.lt) c.sh.lt (DefR13.aOff c q) 14 t
    (msbBits 14 ((3 * (i : ℕ) + k) * 2 ^ c.sh.lt + msbIndex c.sh.lt t))
    (by rw [hr0, hX0, h14]; omega) (by rw [hr0, hX0, h14]; omega) (by rw [hr0, hX0, h14]; omega)
    (by rw [hr0, msbIndex_msbBits 14 _ hidx, hX0, h14]; omega)]
  push_cast
  ring

include hD hX in
/-- **The exp tuple at a product point of `Dom::S`** is an entry of the list. -/
theorem covExp (x : (CgR c × CjR c) × CtR c × CtR c) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (expQuery
      (piB K (aPl U P D (DefR13.aOff c 4) (nHt c) (Fin.append (Fin.append x.1.1 x.1.2) x.2.1))
        - B.mask x * (piB K (aPl U P D (DefR13.aOff c 75) (nS c)
          (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2))) + 127) + 127)
      (piB K (aPl U P D (DefR13.aOff c 80) (nS c) (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2))))) := by
  refine ⟨.inl ⟨.Exp, (castB G.logS.symm (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2)) :
    Fin (c.sh.logs .S) → Bool)⟩, ?_⟩
  show expTupR U c P (Dof cut) Pb Lay B G _ = _
  unfold expTupR
  rw [castB_castB, splitS_append c x]
  simp only [hD, aPl_castB]
  refine Tup.ext' ?_ ?_ ?_ ?_
  · show _ = algebraMap GF K (piB K (aPl U P D (DefR13.aOff c 4) (nHt c) (Fin.append (Fin.append x.1.1 x.1.2) x.2.1))
        - B.mask x * (piB K (aPl U P D (DefR13.aOff c 75) (nS c)
          (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2))) + 127) + 127)
    simp only [map_add, map_sub, map_mul, map_ofNat, aPl_alg U P D hX]
    ring
  · exact (map_natCast (algebraMap GF K) tagExp).symm
  · show _ = algebraMap GF K (piB K (aPl U P D (DefR13.aOff c 80) (nS c)
        (Fin.append (Fin.append x.1.1 x.1.2) (Fin.append x.2.1 x.2.2))))
    rw [aPl_alg U P D hX]
  · show _ = algebraMap GF K 0
    rw [map_zero]

include hD hX in
/-- **The ACT tuple at a product point of `Dom::F`** (group `g` there) is an entry of the list. -/
theorem covAct (x : CtR c × CfR c) (g : ℕ) (hg : B.grpCol x = (g : GF)) :
    ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK (actQuery
      (piB K (aPl U P D (DefR13.aOff c (86 + 2 * ls)) (nF c) (Fin.append x.1 x.2)))
      (piB K (aPl U P D (DefR13.aOff c (86 + 2 * ls + 4)) (nF c) (Fin.append x.1 x.2))) g) := by
  refine ⟨.inl ⟨.Act, (castB G.logF.symm (Fin.append x.1 x.2) : Fin (c.sh.logs .F) → Bool)⟩, ?_⟩
  show actTupR U c P (Dof cut) Pb Lay B G _ = _
  unfold actTupR
  rw [castB_castB, splitF_append c x, hg]
  simp only [hD, aPl_castB]
  refine Tup.ext' ?_ ?_ ?_ ?_
  · show _ = algebraMap GF K (piB K (aPl U P D (DefR13.aOff c (86 + 2 * ls)) (nF c) (Fin.append x.1 x.2)) + 2048)
    simp only [map_add, map_ofNat, aPl_alg U P D hX]
  · exact (map_natCast (algebraMap GF K) tagAct).symm
  · show _ = algebraMap GF K (piB K (aPl U P D (DefR13.aOff c (86 + 2 * ls + 4)) (nF c) (Fin.append x.1 x.2)))
    rw [aPl_alg U P D hX]
  · rfl

end Cov

/-! ## The cover -/

section Cover

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) {ls : ℕ} (G : GeoR c ls)
  (hc : LookCfg c ls) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hc hD hX in
/-- **Every logical lookup of the extracted planes is an entry of the list**, at the shape's precision. -/
theorem cover_xtR (hS : PrecR c S) (hlc : P.logCols = 14) :
    R13LookupsG (fun u => ∃ l, AlkR13 U c P Pb Lay B G Dof cut l = tupK u) Pb Lay B (xtR U c P D ls) where
  la t i k := covLimbR U P Pb Lay B G hc Dof cut D hD hX hlc 0 6 (by rw [hc.lkL]; rfl) i k (Lay.tok.emb t)
  lm t i k := covLimbR U P Pb Lay B G hc Dof cut D hD hX hlc 1 7 (by rw [hc.lkL]; rfl) i k (Lay.tok.emb t)
  xl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 0 9 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  yl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 2 12 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  aol p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 10 21 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  x1l p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 16 27 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  yml p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 18 30 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  zl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 26 39 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  x2l p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 32 45 2
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  nr p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 4 14 3
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  ns p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 7 17 3
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  mr p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 20 32 3
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  ms p := covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 23 35 3
    (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)
  ral p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 12 23 3
      (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2), by
    rw [hS.sao]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .D G.logD 15 25 (8 * 3 - c.p.ao) (by rw [lkD' hc]; rfl)
      (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)⟩
  rdl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .D G.logD 28 41 3
      (fun k hk => by rw [lkD' hc]; interval_cases k <;> rfl) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2), by
    rw [hS.sdown]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .D G.logD 31 43 (8 * 3 - c.p.down) (by rw [lkD' hc]; rfl)
      (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)⟩
  ql p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 0 48 2
    (fun k hk => by rw [lkQ' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
  qrl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 5 53 2
    (fun k hk => by rw [lkQ' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
  ol p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 9 57 2
    (fun k hk => by rw [lkQ' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
  rql p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 2 50 2
      (fun k hk => by rw [lkQ' hc]; interval_cases k <;> rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2)), by
    rw [hS.sq]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 4 51 (8 * 2 - c.p.q) (by rw [lkQ' hc]; rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))⟩
  rqrl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 7 55 1
      (fun k hk => by rw [lkQ' hc]; interval_cases k; rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2)), by
    have h := covPin U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 8 55 (8 * 1 - c.p.rope) (by rw [lkQ' hc]; rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
    rw [hS.rope] at h
    exact h⟩
  ro p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 11 59 2
      (fun k hk => by rw [lkQ' hc]; interval_cases k <;> rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2)), by
    rw [hS.spv]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .Q G.logQ 13 60 (8 * 2 - c.p.pv) (by rw [lkQ' hc]; rfl)
      (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))⟩
  kl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 0 62 2
    (fun k hk => by rw [lkK' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))
  krl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 10 72 2
    (fun k hk => by rw [lkK' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))
  vl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 5 67 2
    (fun k hk => by rw [lkK' hc]; interval_cases k <;> rfl)
    (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))
  rkl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 2 64 2
      (fun k hk => by rw [lkK' hc]; interval_cases k <;> rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)), by
    rw [hS.sk]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 4 65 (8 * 2 - c.p.k) (by rw [lkK' hc]; rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))⟩
  rkrl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 12 74 1
      (fun k hk => by rw [lkK' hc]; interval_cases k; rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)), by
    have h := covPin U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 13 74 (8 * 1 - c.p.rope) (by rw [lkK' hc]; rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))
    rw [hS.rope] at h
    exact h⟩
  rvl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 7 69 2
      (fun k hk => by rw [lkK' hc]; interval_cases k <;> rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)), by
    rw [hS.sv]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .Kv G.logK 9 70 (8 * 2 - c.p.v) (by rw [lkK' hc]; rfl)
      (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))⟩
  sB p := by
    refine ⟨?_, ?_⟩
    · have h := covSym U P Pb Lay B G hc Dof cut D hD hX .S G.logS 0 75 1
        (by rw [lkS' hc, lkSe_head _ _ 0 (by norm_num)]; rfl)
        (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
      simp only [Int.cast_one, one_mul] at h
      exact h
    · have h := covSym U P Pb Lay B G hc Dof cut D hD hX .S G.logS 1 75 (-1)
        (by rw [lkS' hc, lkSe_head _ _ 1 (by norm_num)]; rfl)
        (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
      simp only [Int.cast_neg, Int.cast_one, neg_one_mul] at h
      exact h
  rsl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .S G.logS 2 76 3
      (fun k hk => by rw [lkS' hc, lkSe_head _ _ (2 + k) (by omega)]; interval_cases k <;> rfl)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)), by
    rw [hS.ss]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .S G.logS 5 78 (8 * 3 - c.p.score)
      (by rw [lkS' hc, lkSe_head _ _ 5 (by norm_num)]; rfl)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))⟩
  pl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .S G.logS 6 82 2
      (fun k hk => by rw [lkS' hc, lkSe_head _ _ (6 + k) (by omega)]; interval_cases k <;> rfl)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)), by
    rw [hS.fp]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .S G.logS 8 83 (8 * 2 - (c.p.fp + 1))
      (by rw [lkS' hc, lkSe_head _ _ 8 (by norm_num)]; rfl)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))⟩
  sr p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .S G.logS 9 84 (ls + 1)
      (fun k hk => by rw [lkS' hc]; exact lkSe_sr _ _ _ hk)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)), by
    rw [hS.wrho]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .S G.logS (9 + (ls + 1)) (84 + ls) (8 * (ls + 1) - c.p.wrho)
      (by rw [lkS' hc]; exact lkSe_srPin _ _)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))⟩
  sg p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .S G.logS (9 + (ls + 2)) (84 + (ls + 1)) (ls + 1)
      (fun k hk => by rw [lkS' hc]; exact lkSe_sg _ _ _ hk)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)), by
    rw [hS.wrho]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .S G.logS (9 + (ls + 2) + (ls + 1)) (84 + (ls + 1) + ls)
      (8 * (ls + 1) - c.p.wrho) (by rw [lkS' hc]; exact lkSe_sgPin _ _)
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))⟩
  sExp p := covExp U P Pb Lay B G Dof cut D hD hX (Lay.sPos p)
  rgl p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .F G.logF 0 (86 + 2 * ls + 1) 3
      (fun k hk => by rw [lkF' hc]; interval_cases k <;> rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2), by
    rw [hS.sgate]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .F G.logF 3 (86 + 2 * ls + 3) (8 * 3 - c.p.gate)
      (by rw [lkF' hc]; rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)⟩
  ul p := covBytes U P Pb Lay B G hc Dof cut D hD hX .F G.logF 4 (86 + 2 * ls + 6) 2
    (fun k hk => by rw [lkF' hc]; interval_cases k <;> rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)
  ru p := ⟨covBytes U P Pb Lay B G hc Dof cut D hD hX .F G.logF 6 (86 + 2 * ls + 8) 2
      (fun k hk => by rw [lkF' hc]; interval_cases k <;> rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2), by
    rw [hS.sup]
    exact covPin U P Pb Lay B G hc Dof cut D hD hX .F G.logF 8 (86 + 2 * ls + 9) (8 * 2 - c.p.up)
      (by rw [lkF' hc]; rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)⟩
  hl p := covBytes U P Pb Lay B G hc Dof cut D hD hX .F G.logF 9 (86 + 2 * ls + 11) 3
    (fun k hk => by rw [lkF' hc]; interval_cases k <;> rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)
  rh p := covBytes U P Pb Lay B G hc Dof cut D hD hX .F G.logF 12 (86 + 2 * ls + 14) 2
    (fun k hk => by rw [lkF' hc]; interval_cases k <;> rfl) (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)
  fAct p := covAct U P Pb Lay B G Dof cut D hD hX (Lay.fPos p) (Pb.grpF p.2) (B.grpCol_emb p)

end Cover

/-! ## `hcov` -/

/-- **Lane L36's `hcov` at R13, PROVED, generic in the configuration** (the form of `block_knowledge_join_r13_rung` /
`_shield`, at the opening geometry `(16, 256, 24448, rA, rH)`): on every outcome, every logical query of the extracted
planes `xtR` is an entry of the lookup list `AlkR13` read off the data the `A` cut fixes (`dofAR`), at a shape with the
configuration's precision. -/
theorem hcov_r13 {K : Type} [Field K] [Algebra GF K] {L : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (hlc : P.logCols = 14) (rA rH : ℕ) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (hc : LookCfg c ls) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c))
    (B : W16Pub S Pb Lay) (hS : PrecR c S) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G' q, R13Query Pb Lay B (xtR U c P (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE
        (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) ls) q →
      ∃ l, AlkR13 U c P Pb Lay B G (dofAR tag hL20 P hlc 16 256 24448 rA rH rE QE XE
        (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G').1 l = tupK q := by
  intro G' q hq
  have hcov := cover_xtR U P Pb Lay B G hc
    (dofAR tag hL20 P hlc 16 256 24448 rA rH rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
    (cutsOf key domain hs hL A G').1
    (dXof tag hL20 P hlc 16 256 24448 rA rH rE QE XE (cutsOf key domain hs hL A G') (rootsOf (A.run G').2))
    (fun off log b => dofAR_aPl U key domain hs hL tag hL20 P hlc 16 256 24448 rA rH rE QE XE A G' off log b)
    (dXof_base_r13 tag hL20 P hlc rA rH rE QE XE (cutsOf key domain hs hL A G') (rootsOf (A.run G').2)) hS hlc
  exact r13Query_of hcov hq

/-- **`hcov` at the R13 rung**, in the exact form of `block_knowledge_join_r13_rung`'s premise (opening geometry
`(16, 256, 24448, 437, 248)`), at a shape with the rung's precision (`RungS`). -/
theorem hcov_rung {K : Type} [Field K] [Algebra GF K] {L : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (hS : W16.RungS S) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G q, R13Query Pb Lay B (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2) q →
      ∃ l, AlkR13 U DefR13.cfgRungR13 P Pb Lay B geoRung (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
        (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l = tupK q :=
  hcov_r13 U key domain hs hL tag hL20 P hlc 437 248 rE QE XE geoRung lookCfg_rung Pb Lay B (precR_rung hS) A

/-- **`hcov` at a layer of the Shieldstral T128 R13 block**, in the exact form of `block_knowledge_join_r13_shield`'s
premise (opening geometry `(16, 256, 24448, 4577, 4390)`, the layer's own shape), with no shape premise. -/
theorem hcov_shield {K : Type} [Field K] [Algebra GF K] {L : ℕ} (Ly : ZK60.RunShape.Shield.ShieldLayer) (U : K)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly))
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G q, R13Query Pb Lay B (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1) q →
      ∃ l, AlkR13 U (DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly) (dofAR tag hL20 P hlc 16 256 24448 4577 4390
        rE QE XE (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l = tupK q :=
  hcov_r13 U key domain hs hL tag hL20 P hlc 4577 4390 rE QE XE (geoShield Ly) (lookCfg_shield Ly) Pb Lay B
    (precR_shield Ly) A

end ZK60.Exec.Block.Join.R13H.Look
