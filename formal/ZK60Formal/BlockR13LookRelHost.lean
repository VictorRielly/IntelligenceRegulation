/-
D63 lane L49 (2026-11-10), sub-agent `look`, round 2, part 2: **the hosts' LogUp relations at R13, vanishing, as
`HelperRel`'s relations** (`SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_FZC`), at a point of the host's cube, on the host
sub-agents' batch entries (`Dzc.xcDzcR`, `Qkv.xcZc` (= `Qkv.xcQzcR`, `Qkv.xcKvzcR`), `Fzc.xcFzcR`), generic in the
configuration; by lane L47's `BlockLookRelHost.lean` / `BlockLookRelPer.lean`.

* `planes_mem`: a lookup's plane is in its list's plane list;
* per host, the value list's positions hold the lookups' planes (`dzc_planesR`, `q_planesR`, `k_planesR`,
  `f_planesR`) and the helpers (`dzc_helpR`, `q_helpR`, `k_helpR`, `f_helpR`);
* **`relD_pairR`** (`SC_DZC`'s entry `13 + j`, `j < 17`), **`relQ_pairR`**, **`relK_pairR`** (entry `4 + j`, `j < 7`),
  **`relF_pairR`** (entry `4 + j`, `j < 7`), **`relActR`** (`SC_FZC`'s entry `3`, the ACT tuple).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookRelBase
import ZK60Formal.BlockR13HostDzcVals
import ZK60Formal.BlockR13HostQkvZc
import ZK60Formal.BlockR13HostFzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.LookRel

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.Join.W16 (aPl piB hPl cstK)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Layout
open ZK60.Circuit (gP GF tagW tagAct)

/-! ## Planes -/

theorem planes_mem (L : List LkW) : ∀ l ∈ L, ∀ t ∈ l.terms, t.1 ∈ L.flatMap (fun l => l.terms.map Prod.fst) :=
  fun l hl _ ht => List.mem_flatMap.mpr ⟨l, hl, List.mem_map_of_mem ht⟩

theorem planesD (p : ZK60.Exec.Slot.Build.Lay.PrecW) : ∀ l ∈ lkDe p, ∀ t ∈ l.terms, 9 ≤ t.1 ∧ t.1 ≤ 46 := by
  intro l hl t ht
  have hm := planes_mem _ l hl t ht
  rw [show (lkDe p).flatMap (fun l => l.terms.map Prod.fst) = [9, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23,
    24, 25, 25, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 43, 45, 46] from rfl] at hm
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
  omega

theorem planesQ (p : ZK60.Exec.Slot.Build.Lay.PrecW) : ∀ l ∈ lkQe p, ∀ t ∈ l.terms, 48 ≤ t.1 ∧ t.1 ≤ 60 := by
  intro l hl t ht
  have hm := planes_mem _ l hl t ht
  rw [show (lkQe p).flatMap (fun l => l.terms.map Prod.fst)
    = [48, 49, 50, 51, 51, 53, 54, 55, 55, 57, 58, 59, 60, 60] from rfl] at hm
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
  omega

theorem planesK (p : ZK60.Exec.Slot.Build.Lay.PrecW) : ∀ l ∈ lkKe p, ∀ t ∈ l.terms, 62 ≤ t.1 ∧ t.1 ≤ 74 := by
  intro l hl t ht
  have hm := planes_mem _ l hl t ht
  rw [show (lkKe p).flatMap (fun l => l.terms.map Prod.fst)
    = [62, 63, 64, 65, 65, 67, 68, 69, 70, 70, 72, 73, 74, 74] from rfl] at hm
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
  omega

theorem planesF (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) :
    ∀ l ∈ lkFe p ls, ∀ t ∈ l.terms, 86 + 2 * ls + 1 ≤ t.1 ∧ t.1 ≤ 86 + 2 * ls + 15 := by
  intro l hl t ht
  have hm := planes_mem _ l hl t ht
  rw [show (lkFe p ls).flatMap (fun l => l.terms.map Prod.fst)
    = [86 + 2 * ls + 1, 86 + 2 * ls + 2, 86 + 2 * ls + 3, 86 + 2 * ls + 3, 86 + 2 * ls + 6, 86 + 2 * ls + 7,
      86 + 2 * ls + 8, 86 + 2 * ls + 9, 86 + 2 * ls + 9, 86 + 2 * ls + 11, 86 + 2 * ls + 12, 86 + 2 * ls + 13,
      86 + 2 * ls + 14, 86 + 2 * ls + 15] from rfl] at hm
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
  omega

/-! ## `SC_DZC` -/

section Dzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
variable (hc : LookCfg c ls) (hr : RelCfg c ls)

include hc in
theorem dzc_planesR (b : Fin (c.sh.logs .D) → Bool) :
    ∀ l ∈ DefR13.lookups c Dm.D.dom, ∀ t ∈ l.terms,
      (Dzc.valsXD U G P D Pb Lay B b).getD (Dzc.shD t.1) 0 = aPl U P D (DefR13.aOff c t.1) (c.sh.logs .D) b := by
  rw [lkD' hc]
  intro l hl t ht
  obtain ⟨h1, h2⟩ := planesD c.p l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

include hc in
theorem dzc_helpR (b : Fin (c.sh.logs .D) → Bool) (j : ℕ) (hj : j < 17) :
    (Dzc.valsXD U G P D Pb Lay B b).getD (46 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (Dm.fh ls .D + j)).1 (DefR13.hOff c (Dm.fh ls .D + j)).2 (c.sh.logs .D) b := by
  have e : (Dzc.valsXD U G P D Pb Lay B b).getD (46 + 0 + j) 0 = Dzc.hDz U c P D j b := by
    interval_cases j <;> rfl
  rw [e]
  unfold Dzc.hDz
  rw [(fh_eq hc).2.1]
  rfl

variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

include hc hr hα in
/-- **`SC_DZC`'s entry `13 + j`** (`j < 17`), vanishing, IS `HelperRel`'s pair relation of `Dom::D`'s lookups `2j`,
`2j + 1` (helper plane `1 + j`). -/
theorem relD_pairR (b : Fin (c.sh.logs .D) → Bool) (j : ℕ) (hj : j < 17)
    (h0 : Dzc.xcDzcR U G P D Pb Lay B bga (13 + j) b = 0) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .D + j)).1 (DefR13.hOff c (Dm.fh ls .D + j)).2 (Dm.log c .D) b)
      (lkAtR U c P D .D (2 * j) b) (lkAtR U c P D .D (2 * j + 1) b) := by
  unfold Dzc.xcDzcR at h0
  rw [show 13 + j - 13 = j by omega] at h0
  exact W16.Look.host_pair U bga hα 14 Dzc.shD (DefR13.lookups c Dm.D.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .D) b) 46 _ j
    (by rw [lkLen hc .D, ite_eq_right (show ¬ Dm.D = Dm.S by decide)]; show 2 * j + 1 < 2 * 17 + 0; omega) (lkOK_R hc hr .D) (dzc_planesR U G P D Pb Lay B hc b)
    (dzc_helpR U G P D Pb Lay B hc b j hj) h0

end Dzc

/-! ## `SC_QZC` and `SC_KVZC` -/

section Qkv

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (P : BlockParams) (D : CmData K P)
variable (hc : LookCfg c ls) (hr : RelCfg c ls)

include hc in
theorem q_planesR (b : Fin (c.sh.logs .Q) → Bool) :
    ∀ l ∈ DefR13.lookups c Dm.Q.dom, ∀ t ∈ l.terms,
      (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Q 47 2 b).getD ((fun p => 5 + (p - 47)) t.1) 0
        = aPl U P D (DefR13.aOff c t.1) (c.sh.logs .Q) b := by
  rw [lkQ' hc]
  intro l hl t ht
  obtain ⟨h1, h2⟩ := planesQ c.p l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

include hc in
theorem k_planesR (b : Fin (c.sh.logs .Kv) → Bool) :
    ∀ l ∈ DefR13.lookups c Dm.Kv.dom, ∀ t ∈ l.terms,
      (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Kv 61 3 b).getD ((fun p => 5 + (p - 61)) t.1) 0
        = aPl U P D (DefR13.aOff c t.1) (c.sh.logs .Kv) b := by
  rw [lkK' hc]
  intro l hl t ht
  obtain ⟨h1, h2⟩ := planesK c.p l hl t ht
  generalize t.1 = q at h1 h2 ⊢
  interval_cases q <;> rfl

include hc in
theorem q_helpR (b : Fin (c.sh.logs .Q) → Bool) (j : ℕ) (hj : j < 7) :
    (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Q 47 2 b).getD (20 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (Dm.fh ls .Q + j)).1 (DefR13.hOff c (Dm.fh ls .Q + j)).2 (c.sh.logs .Q) b := by
  have e : (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Q 47 2 b).getD (20 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (DefR13.fh c 2 + j)).1 (DefR13.hOff c (DefR13.fh c 2 + j)).2 (c.sh.logs .Q) b := by
    interval_cases j <;> rfl
  rw [e, (fh_eq hc).2.2.1]
  rfl

include hc in
theorem k_helpR (b : Fin (c.sh.logs .Kv) → Bool) (j : ℕ) (hj : j < 7) :
    (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Kv 61 3 b).getD (20 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (Dm.fh ls .Kv + j)).1 (DefR13.hOff c (Dm.fh ls .Kv + j)).2 (c.sh.logs .Kv) b := by
  have e : (0 :: 0 :: 0 :: 0 :: 0 :: Qkv.zcPl U c P D .Kv 61 3 b).getD (20 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (DefR13.fh c 3 + j)).1 (DefR13.hOff c (DefR13.fh c 3 + j)).2 (c.sh.logs .Kv) b := by
    interval_cases j <;> rfl
  rw [e, (fh_eq hc).2.2.2.1]
  rfl

variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

theorem getD_cons4 {R : Type} [Zero R] (L : List R) (j : ℕ) :
    (0 :: 0 :: 0 :: 0 :: L).getD (4 + j) 0 = L.getD j 0 := by
  rw [show 4 + j = j + 1 + 1 + 1 + 1 by omega]
  simp only [List.getD_cons_succ]

include hc hr hα in
/-- **`SC_QZC`'s entry `4 + j`** (`j < 7`), vanishing, IS `HelperRel`'s pair relation of `Dom::Q`'s lookups `2j`,
`2j + 1` (helper plane `18 + j`). -/
theorem relQ_pairR (b : Fin (c.sh.logs .Q) → Bool) (j : ℕ) (hj : j < 7)
    (h0 : Qkv.xcZc U c P D .Q 47 2 bga (4 + j) b = 0) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .Q + j)).1 (DefR13.hOff c (Dm.fh ls .Q + j)).2 (Dm.log c .Q) b)
      (lkAtR U c P D .Q (2 * j) b) (lkAtR U c P D .Q (2 * j + 1) b) := by
  unfold Qkv.xcZc at h0
  rw [getD_cons4] at h0
  exact W16.Look.host_pair U bga hα 0 (fun p => 5 + (p - 47)) (DefR13.lookups c Dm.Q.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .Q) b) 20 _ j
    (by rw [lkLen hc .Q, ite_eq_right (show ¬ Dm.Q = Dm.S by decide)]; show 2 * j + 1 < 2 * 7 + 0; omega) (lkOK_R hc hr .Q) (q_planesR U P D hc b)
    (q_helpR U P D hc b j hj) h0

include hc hr hα in
/-- **`SC_KVZC`'s entry `4 + j`** (`j < 7`), vanishing, IS `HelperRel`'s pair relation of `Dom::Kv`'s lookups `2j`,
`2j + 1` (helper plane `25 + j`). -/
theorem relK_pairR (b : Fin (c.sh.logs .Kv) → Bool) (j : ℕ) (hj : j < 7)
    (h0 : Qkv.xcZc U c P D .Kv 61 3 bga (4 + j) b = 0) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .Kv + j)).1 (DefR13.hOff c (Dm.fh ls .Kv + j)).2 (Dm.log c .Kv) b)
      (lkAtR U c P D .Kv (2 * j) b) (lkAtR U c P D .Kv (2 * j + 1) b) := by
  unfold Qkv.xcZc at h0
  rw [getD_cons4] at h0
  exact W16.Look.host_pair U bga hα 0 (fun p => 5 + (p - 61)) (DefR13.lookups c Dm.Kv.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .Kv) b) 20 _ j
    (by rw [lkLen hc .Kv, ite_eq_right (show ¬ Dm.Kv = Dm.S by decide)]; show 2 * j + 1 < 2 * 7 + 0; omega) (lkOK_R hc hr .Kv) (k_planesR U P D hc b)
    (k_helpR U P D hc b j hj) h0

end Qkv

/-! ## `SC_FZC` -/

section Fzc

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) {c : W16Cfg} {ls : ℕ}
  (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
variable (hc : LookCfg c ls) (hr : RelCfg c ls)

theorem f_rest (b : Fin (c.sh.logs .F) → Bool) (i : ℕ) (h1 : 1 ≤ i) (h2 : i ≤ 15) :
    (Fzc.valsFR U G P D B b).getD (3 + i) 0 = aPl U P D (DefR13.aOff c (86 + 2 * ls + i)) (c.sh.logs .F) b := by
  interval_cases i <;> rfl

include hc in
theorem f_planesR (b : Fin (c.sh.logs .F) → Bool) :
    ∀ l ∈ DefR13.lookups c Dm.F.dom, ∀ t ∈ l.terms,
      (Fzc.valsFR U G P D B b).getD (Fzc.shFR ls t.1) 0 = aPl U P D (DefR13.aOff c t.1) (c.sh.logs .F) b := by
  rw [lkF' hc]
  intro l hl t ht
  obtain ⟨h1, h2⟩ := planesF c.p ls l hl t ht
  obtain ⟨i, hi⟩ : ∃ i, t.1 = 86 + 2 * ls + i := ⟨t.1 - (86 + 2 * ls), by omega⟩
  rw [hi, show Fzc.shFR ls (86 + 2 * ls + i) = 3 + i by unfold Fzc.shFR; omega]
  exact f_rest U G P D B b i (by omega) (by omega)

include hc in
theorem f_helpR (b : Fin (c.sh.logs .F) → Bool) (j : ℕ) (hj : j < 7) :
    (Fzc.valsFR U G P D B b).getD (19 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (Dm.fh ls .F + j)).1 (DefR13.hOff c (Dm.fh ls .F + j)).2 (c.sh.logs .F) b := by
  have e : (Fzc.valsFR U G P D B b).getD (19 + 0 + j) 0
      = hPl U P D (DefR13.hOff c (DefR13.fh c 6 + j)).1 (DefR13.hOff c (DefR13.fh c 6 + j)).2 (c.sh.logs .F) b := by
    interval_cases j <;> rfl
  rw [e, (fh_eq hc).2.2.2.2.2.2.1]
  rfl

variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

include hc hr hα in
/-- **`SC_FZC`'s entry `4 + j`** (`j < 7`), vanishing, IS `HelperRel`'s pair relation of `Dom::F`'s lookups `2j`,
`2j + 1` (helper plane `40 + ls + j`). -/
theorem relF_pairR (b : Fin (c.sh.logs .F) → Bool) (j : ℕ) (hj : j < 7)
    (h0 : Fzc.xcFzcR U G P D B bga (4 + j) b = 0) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .F + j)).1 (DefR13.hOff c (Dm.fh ls .F + j)).2 (Dm.log c .F) b)
      (lkAtR U c P D .F (2 * j) b) (lkAtR U c P D .F (2 * j + 1) b) := by
  unfold Fzc.xcFzcR at h0
  rw [ite_eq_right (show ¬ (4 + j = 3) by omega), show 4 + j - 4 = j by omega] at h0
  exact W16.Look.host_pair U bga hα 18 (Fzc.shFR ls) (DefR13.lookups c Dm.F.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .F) b) 19 _ j
    (by rw [lkLen hc .F, ite_eq_right (show ¬ Dm.F = Dm.S by decide)]; show 2 * j + 1 < 2 * 7 + 0; omega) (lkOK_R hc hr .F) (f_planesR U G P D B hc b)
    (f_helpR U G P D B hc b j hj) h0

include hU hc hα in
/-- **`SC_FZC`'s entry `3`**, vanishing, IS `HelperRel`'s single relation of the ACT tuple (helper plane `fact`). -/
theorem relActR (hβ : bga.1.Canon) (b : Fin (c.sh.logs .F) → Bool) (h0 : Fzc.xcFzcR U G P D B bga 3 b = 0) :
    W16.Look.SingleR U bga
      (hPl U P D (DefR13.hOff c (Sg.hp ls .Act)).1 (DefR13.hOff c (Sg.hp ls .Act)).2 (Sg.log c .Act) b)
      (actTupR U c P D Pb Lay B G b) := by
  unfold Fzc.xcFzcR at h0
  rw [ite_eq_left rfl] at h0
  have hamq : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.amqS).toK U
      = bga.2.2.toK U - 2048 - bga.2.1.toK U * 134 := by
    show (Fp2.sub (Fp2.sub bga.2.2 (Fp2.fromBase (Fp.fromI64 2048)))
      (bga.2.1.mulBase (Fp.new (UInt64.ofNat 134)))).toK U = _
    rw [Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ hα (Fp2.canon_fromBase _ (W16.Look.fromI64_canon _)))
        (Fp2.canon_mulBase _ _),
      Fp2.toK_sub U _ _ hα (Fp2.canon_fromBase _ (W16.Look.fromI64_canon _)), Fp2.toK_fromBase,
      Fp.toGF_fromI64 2048 (by norm_num) (by norm_num), Fp2.toK_mulBase, Fp.new_toGF_ofNat 134 (by norm_num),
      map_natCast, map_intCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.nbS).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hnb2 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] W16.Fzc.nb2S).toK U
      = -(bga.1.toK U * bga.1.toK U) := by
    show (Fp2.neg (Fp2.mul bga.1 bga.1)).toK U = _
    rw [Fp2.toK_neg U _ (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
  have hf7 : DefR13.fh c 7 = 47 + ls := (fh_eq hc).2.2.2.2.2.2.2.1
  have e26 : (Fzc.valsFR U G P D B b).getD 26 0
      = hPl U P D (DefR13.hOff c (Sg.hp ls .Act)).1 (DefR13.hOff c (Sg.hp ls .Act)).2 (Sg.log c .Act) b := by
    show hPl U P D (DefR13.hOff c (DefR13.fh c 7)).1 (DefR13.hOff c (DefR13.fh c 7)).2 (c.sh.logs .F) b = _
    rw [hf7]
    rfl
  have e3 : (Fzc.valsFR U G P D B b).getD 3 0 = aPl U P D (DefR13.aOff c (86 + 2 * ls)) (c.sh.logs .F) b := rfl
  have e7 : (Fzc.valsFR U G P D B b).getD 7 0 = aPl U P D (DefR13.aOff c (86 + 2 * ls + 4)) (c.sh.logs .F) b := rfl
  have e27 : (Fzc.valsFR U G P D B b).getD 27 0 = algebraMap GF K (B.grpCol (splitF c (castB G.logF b))) := rfl
  unfold Fzc.r13FzcAct at h0
  simp only [Fzc.rrFR] at h0
  rw [hamq, hnb, hnb2, e26, e3, e7, e27] at h0
  unfold W16.Look.SingleR actTupR ZK60.Sound.fold
  have ht : ((tagAct : ℕ) : K) = 134 := by norm_num
  rw [ht]
  linear_combination h0

end Fzc

end ZK60.Exec.Block.Join.R13H.LookRel
