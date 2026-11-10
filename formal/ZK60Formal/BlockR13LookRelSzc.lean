/-
D63 lane L49 (2026-11-10), sub-agent `look`, round 2, part 4: **`SC_SZC`'s LogUp relations at R13, vanishing, as
`HelperRel`'s relations**, on sub-agent szc's batch entries (`Szc.xcSzcR`), generic in the configuration.

* `planesS`, `s_restPl`, `s_planesR`, `s_helpR`, `lenKR`: `SC_SZC`'s value list holds `Dom::S`'s planes and its
  `7 + ls` helpers;
* **`relS_pairR`** (entry `5 + j`, `j < 6 + ls`), **`relS_singleR`** (entry `11 + ls`, `Dom::S`'s odd last lookup),
  **`relExpR`** (entry `12 + ls`, the exp tuple).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookRelHost
import ZK60Formal.BlockR13HostSzcVals

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.LookRel

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.Join.W16 (aPl piB hPl cstK aPl_alg)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Layout
open ZK60.Circuit (gP GF tagW tagExp)

theorem planesS (p : ZK60.Exec.Slot.Build.Lay.PrecW) (ls : ℕ) :
    ∀ l ∈ lkSe p ls, ∀ t ∈ l.terms, 75 ≤ t.1 ∧ t.1 ≤ 85 + 2 * ls := by
  intro l hl t ht
  rw [lkSe_eq] at hl
  rcases List.mem_append.mp hl with hl | hl
  · rcases List.mem_append.mp hl with hl | hl
    · have hm := planes_mem _ l hl t ht
      rw [show (lkS0 p).flatMap (fun l => l.terms.map Prod.fst) = [75, 75, 76, 77, 78, 78, 82, 83, 83] from rfl] at hm
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hm
      omega
    · rcases List.mem_append.mp hl with hl | hl
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hl
        rw [List.mem_range'_1] at hq
        simp only [bLk, List.mem_singleton] at ht
        subst ht
        show 75 ≤ q ∧ q ≤ 85 + 2 * ls
        omega
      · rw [List.mem_singleton] at hl
        subst hl
        simp only [pLk, List.mem_singleton] at ht
        subst ht
        show 75 ≤ 84 + ls ∧ 84 + ls ≤ 85 + 2 * ls
        omega
  · rcases List.mem_append.mp hl with hl | hl
    · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hl
      rw [List.mem_range'_1] at hq
      simp only [bLk, List.mem_singleton] at ht
      subst ht
      show 75 ≤ q ∧ q ≤ 85 + 2 * ls
      omega
    · rw [List.mem_singleton] at hl
      subst hl
      simp only [pLk, List.mem_singleton] at ht
      subst ht
      show 75 ≤ 84 + (ls + 1) + ls ∧ 84 + (ls + 1) + ls ≤ 85 + 2 * ls
      omega

section Szc

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
variable (hc : LookCfg c ls) (hr : RelCfg c ls)

theorem s_restPl (b : Fin (c.sh.logs .S) → Bool) (i : ℕ) (hi : i < 11 + 2 * ls) :
    (Szc.valsR U G P D B 0 0 0 b).getD (4 + i) 0 = aPl U P D (DefR13.aOff c (75 + i)) (c.sh.logs .S) b := by
  unfold Szc.valsR
  rw [show 4 + i = i + 1 + 1 + 1 + 1 by omega]
  simp only [List.getD_cons_succ]
  unfold Szc.restTR
  rw [getD_appL _ _ _ _ (by simp only [List.length_map, List.length_range]; exact hi), List.getD_eq_getElem?_getD,
    List.getElem?_map, List.getElem?_range hi]
  rfl

/-- `SC_SZC`'s value list past its `11 + 2·ls` planes. -/
theorem s_tail (b : Fin (c.sh.logs .S) → Bool) (i : ℕ) :
    (Szc.valsR U G P D B 0 0 0 b).getD (4 + (11 + 2 * ls) + i) 0
      = (aPl U P D (DefR13.aOff c 4) (c.sh.logs .Ht) (Szc.hdB _ b) :: aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht)
          (Szc.hdB _ b) :: ((List.range (7 + ls)).map (fun j => hPl U P D (DefR13.hOff c (DefR13.fh c 4 + j)).1
          (DefR13.hOff c (DefR13.fh c 4 + j)).2 (c.sh.logs .S) b)
          ++ [hPl U P D (DefR13.hOff c (DefR13.fh c 5)).1 (DefR13.hOff c (DefR13.fh c 5)).2 (c.sh.logs .S) b])).getD
        i 0 := by
  unfold Szc.valsR
  rw [show 4 + (11 + 2 * ls) + i = (11 + 2 * ls + i) + 1 + 1 + 1 + 1 by omega]
  simp only [List.getD_cons_succ]
  unfold Szc.restTR
  rw [getD_appR _ _ _ _ (by simp only [List.length_map, List.length_range]; omega)]
  simp only [List.length_map, List.length_range]
  rw [show 11 + 2 * ls + i - (11 + 2 * ls) = i by omega]

include hc in
theorem s_planesR (b : Fin (c.sh.logs .S) → Bool) :
    ∀ l ∈ DefR13.lookups c Dm.S.dom, ∀ t ∈ l.terms,
      (Szc.valsR U G P D B 0 0 0 b).getD (Szc.shapedR t.1) 0 = aPl U P D (DefR13.aOff c t.1) (c.sh.logs .S) b := by
  rw [lkS' hc]
  intro l hl t ht
  obtain ⟨h1, h2⟩ := planesS c.p ls l hl t ht
  rw [show Szc.shapedR t.1 = 4 + (t.1 - 75) by rfl, s_restPl U G P D B b (t.1 - 75) (by omega),
    show 75 + (t.1 - 75) = t.1 by omega]

include hc in
theorem s_helpR (b : Fin (c.sh.logs .S) → Bool) (j : ℕ) (hj : j < 7 + ls) :
    (Szc.valsR U G P D B 0 0 0 b).getD (17 + 2 * ls + 0 + j) 0
      = hPl U P D (DefR13.hOff c (Dm.fh ls .S + j)).1 (DefR13.hOff c (Dm.fh ls .S + j)).2 (c.sh.logs .S) b := by
  rw [show 17 + 2 * ls + 0 + j = 4 + (11 + 2 * ls) + (j + 1 + 1) by omega, s_tail]
  simp only [List.getD_cons_succ]
  rw [getD_appL _ _ _ _ (by simp only [List.length_map, List.length_range]; exact hj), List.getD_eq_getElem?_getD,
    List.getElem?_map, List.getElem?_range hj]
  simp only [Option.map_some, Option.getD_some]
  rw [(fh_eq hc).2.2.2.2.1]
  rfl

include hc in
theorem lenKR (bga : Fp2 × Fp2 × Fp2) : (Szc.lksKR U c bga).length = 13 + 2 * ls := by
  unfold Szc.lksKR DefR13.lksS
  simp only [List.length_map]
  show (DefR13.lookups c Dm.S.dom).length = _
  rw [lkLen hc .S, ite_eq_left rfl]
  show 2 * (6 + ls) + 1 = _
  omega

variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

include hc in
theorem xcS_rel (b : Fin (c.sh.logs .S) → Bool) (j : ℕ) (hj : j < 7 + ls) :
    Szc.xcSzcR U G P D B bga (5 + j) b
      = (lkRels (cstK U) (Szc.valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0 (Szc.lksKR U c bga)).getD j 0 := by
  have hl : (lkRels (cstK U) (Szc.valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0 (Szc.lksKR U c bga)).length = 7 + ls := by
    rw [lkRels_length, lenKR U hc bga]
    omega
  unfold Szc.xcSzcR
  rw [getD_appL _ _ _ _ (by rw [List.length_append, List.length_replicate, hl]; omega),
    getD_appR _ _ _ _ (by rw [List.length_replicate]; omega), List.length_replicate,
    show 5 + j - 5 = j by omega]

include hc hr hα in
/-- **`SC_SZC`'s entry `5 + j`** (`j < 6 + ls`), vanishing, IS `HelperRel`'s pair relation of `Dom::S`'s lookups `2j`,
`2j + 1` (helper plane `32 + j`). -/
theorem relS_pairR (b : Fin (c.sh.logs .S) → Bool) (j : ℕ) (hj : j < 6 + ls)
    (h0 : Szc.xcSzcR U G P D B bga (5 + j) b = 0) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .S + j)).1 (DefR13.hOff c (Dm.fh ls .S + j)).2 (Dm.log c .S) b)
      (lkAtR U c P D .S (2 * j) b) (lkAtR U c P D .S (2 * j + 1) b) := by
  rw [xcS_rel U G P D B hc bga b j (by omega)] at h0
  exact W16.Look.host_pair U bga hα 17 Szc.shapedR (DefR13.lookups c Dm.S.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .S) b) (17 + 2 * ls) _ j
    (by rw [lkLen hc .S, ite_eq_left rfl]; show 2 * j + 1 < 2 * (6 + ls) + 1; omega) (lkOK_R hc hr .S)
    (s_planesR U G P D B hc b) (s_helpR U G P D B hc b j (by omega)) h0

include hc hr hα in
/-- **`SC_SZC`'s entry `11 + ls`**, vanishing, IS `HelperRel`'s single relation of `Dom::S`'s odd last lookup (helper
plane `38 + ls`). -/
theorem relS_singleR (b : Fin (c.sh.logs .S) → Bool) (h0 : Szc.xcSzcR U G P D B bga (5 + (6 + ls)) b = 0) :
    W16.Look.SingleR U bga
      (hPl U P D (DefR13.hOff c (Sg.hp ls .S)).1 (DefR13.hOff c (Sg.hp ls .S)).2 (Sg.log c .S) b)
      (sgTupR U c P D Pb Lay B G .S b) := by
  rw [xcS_rel U G P D B hc bga b (6 + ls) (by omega)] at h0
  have hh := s_helpR U G P D B hc b (6 + ls) (by omega)
  rw [show Dm.fh ls .S + (6 + ls) = Sg.hp ls .S by show 32 + (6 + ls) = 38 + ls; omega] at hh
  exact W16.Look.host_single U bga hα 17 Szc.shapedR (DefR13.lookups c Dm.S.dom) _
    (fun q => aPl U P D (DefR13.aOff c q) (c.sh.logs .S) b) (17 + 2 * ls) _ (6 + ls)
    (by rw [lkLen hc .S, ite_eq_left rfl]; rfl) (lkOK_R hc hr .S) (s_planesR U G P D B hc b) hh h0

include hc hα in
/-- **`SC_SZC`'s entry `12 + ls`**, vanishing, IS `HelperRel`'s single relation of the exp tuple (helper plane
`sexp = 39 + ls`), on a base-valued `A` matrix. -/
theorem relExpR (hX : ∀ i t, D.X .a i t ∈ baseR K) (hβ : bga.1.Canon) (b : Fin (c.sh.logs .S) → Bool)
    (h0 : Szc.xcSzcR U G P D B bga (12 + ls) b = 0) :
    W16.Look.SingleR U bga
      (hPl U P D (DefR13.hOff c (Sg.hp ls .Exp)).1 (DefR13.hOff c (Sg.hp ls .Exp)).2 (Sg.log c .Exp) b)
      (expTupR U c P D Pb Lay B G b) := by
  have hl : (List.replicate 5 (0 : K) ++ lkRels (cstK U) (Szc.valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0
      (Szc.lksKR U c bga)).length = 12 + ls := by
    rw [List.length_append, List.length_replicate, lkRels_length, lenKR U hc bga]
    omega
  unfold Szc.xcSzcR at h0
  rw [getD_appR _ _ _ _ (by rw [hl]), hl, Nat.sub_self, List.getD_cons_zero] at h0
  have hamd : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.sub .alpha (.gtag 129))).toK U
      = bga.2.2.toK U - bga.2.1.toK U * 129 := by
    show (Fp2.sub bga.2.2 (bga.2.1.mulBase (Fp.new (UInt64.ofNat 129)))).toK U = _
    rw [Fp2.toK_sub U _ _ hα (Fp2.canon_mulBase _ _), Fp2.toK_mulBase, Fp.new_toGF_ofNat 129 (by norm_num),
      map_natCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.neg .beta)).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hb1 : (cstK U).base (-127) = -127 := by
    rw [W16.cstK_base U (-127) (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) (-127)).trans (by norm_num)
  have hb2 : (cstK U).base 127 = 127 := by
    rw [W16.cstK_base U 127 (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) 127).trans (by norm_num)
  have e3 : (Szc.valsR U G P D B 0 0 0 b).getD 3 0 = algebraMap GF K (B.mask (splitS c (castB G.logS b))) := rfl
  have e4 : (Szc.valsR U G P D B 0 0 0 b).getD 4 0 = aPl U P D (DefR13.aOff c 75) (c.sh.logs .S) b :=
    s_restPl U G P D B b 0 (by omega)
  have e9 : (Szc.valsR U G P D B 0 0 0 b).getD 9 0 = aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) b :=
    s_restPl U G P D B b 5 (by omega)
  have emx : (Szc.valsR U G P D B 0 0 0 b).getD (15 + 2 * ls) 0
      = aPl U P D (DefR13.aOff c 4) (nHt c) (Fin.append (Fin.append (splitS c (castB G.logS b)).1.1
          (splitS c (castB G.logS b)).1.2) (splitS c (castB G.logS b)).2.1) := by
    rw [show 15 + 2 * ls = 4 + (11 + 2 * ls) + 0 by omega, s_tail]
    have h1 := Szc.alg_plHt_R U G P D hX (DefR13.aOff c 4) b
    unfold plH at h1
    rw [aPl_alg U P D hX] at h1
    exact h1.symm
  have ehx : (Szc.valsR U G P D B 0 0 0 b).getD (24 + 3 * ls) 0
      = hPl U P D (DefR13.hOff c (Sg.hp ls .Exp)).1 (DefR13.hOff c (Sg.hp ls .Exp)).2 (Sg.log c .Exp) b := by
    rw [show 24 + 3 * ls = 4 + (11 + 2 * ls) + (7 + ls + 1 + 1) by omega, s_tail]
    simp only [List.getD_cons_succ]
    rw [getD_appR _ _ _ _ (by simp only [List.length_map, List.length_range]; omega)]
    simp only [List.length_map, List.length_range, Nat.sub_self, List.getD_cons_zero]
    rw [(fh_eq hc).2.2.2.2.2.1]
    rfl
  unfold Szc.r13SzcExp Szc.r13SzcDelta at h0
  simp only [Szc.RSzR] at h0
  rw [hamd, hnb, hb1, hb2, e3, e4, e9, emx, ehx] at h0
  unfold W16.Look.SingleR expTupR ZK60.Sound.fold
  have ht : ((tagExp : ℕ) : K) = 129 := by norm_num
  rw [ht]
  linear_combination h0

end Szc

end ZK60.Exec.Block.Join.R13H.LookRel
