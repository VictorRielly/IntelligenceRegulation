/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 5: **the hosted slots of `SC_QZC` and `SC_KVZC` at R13**, generic in
the configuration: `SC_QMM`, `SC_KMM`, `SC_VMM` (matmuls with the folded weights `W_q`, `W_k`, `W_v`) and `SC_PV` (the
bilinear `eq(r_g)·PP·V`, claim point permuted: L36's `ipStd`).

* `prog_mm`, `prog_pv`: the numbered program's slots `5`, `6`, `7`, `9` (from `QkvCfg`'s raw slots);
* **`qmm_spSumR`**: `SC_QMM`'s unmasked sum is the extension of `r13Mm 15 0` at its draws;
* **`kvmm_spSumR`**: `SC_KMM`'s (`SC_VMM`'s) is the extension of `r13Mm 16 i` at the split point (`SC_QMM`'s `r_q`, then
  its own draws);
* `ptK4`, `ptK3`, `ptK_rng`, `ptK_fix`, **`ptPPR`**, **`ptVR`**: `SC_PV`'s two claim points at a cube point;
* **`pv_cubeR`**, **`pv_targetR`**, **`pv_spSumR`**: `SC_PV`'s unmasked sum is the extension of `r13Mm 15 1` at its
  published point (`ipStd`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg cstS_map eqT_eval sum_append mleAt_append_bits)
open ZK60.Exec.Block.Join.W16.Qkv (drs drs_getD drs_length eval_self drs_map_hist mm_spSum pv_sum mleAt_app'
  mleAt_bits_append fxT)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (bilIr bilIr_eval mmIr gV_some)
open ZK60.Exec.Slot.Compose (bilIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The numbered hosted slots -/

section Prog

variable {c : W16Cfg} {ls : ℕ}

theorem prog_mm (hcfg : QkvCfg c ls) (ioIn ioOut s : ℕ) (hs : s = 5 ∨ s = 6 ∨ s = 7) :
    ∃ mrow, (DefR13.progR13 c ioIn ioOut).getD s SlotS.empty
      = ⟨[fxT (DefR13.aOff c 11) (c.sh.lt + c.sh.ld) (drs 5 0 c.sh.lt) c.sh.ld mrow 0, .pub 0],
          mmIr DefW16.cstS 0 1, [], []⟩ := by
  obtain ⟨ak, hk, h⟩ := progR13_slot c ioIn ioOut s (by omega)
  have hr : DefR13.rawSlot c s = rawMm c := by
    rcases hs with rfl | rfl | rfl
    · exact hcfg.raw5
    · exact hcfg.raw6
    · exact hcfg.raw7
  rw [h, hr]
  exact ⟨_, rfl⟩

theorem prog_pv (hcfg : QkvCfg c ls) (ioIn ioOut : ℕ) :
    ∃ m1 m2, (DefR13.progR13 c ioIn ioOut).getD 9 SlotS.empty
      = ⟨[.eq (drs 9 0 c.sh.lkv) 0, .priv ⟨.a, [(DefR13.aOff c 81, false)], nS c, ppCR c, m1, 0⟩,
          .priv ⟨.a, [(DefR13.aOff c 66, false)], nK c, vCR c, m2, 1⟩], bilIr DefW16.cstS (some 0) 1 2, [], []⟩ := by
  obtain ⟨ak, hk, h⟩ := progR13_slot c ioIn ioOut 9 (by norm_num)
  rw [h, hcfg.raw9]
  exact ⟨_, _, rfl⟩

theorem shape_mm {P : BlockParams} (hpf : ProfR c.sh P) (s : ℕ) (hs : s = 5 ∨ s = 6 ∨ s = 7) :
    (slotShape P s).1 = c.sh.ld := by
  rw [hpf.slots s (by omega)]
  rcases hs with rfl | rfl | rfl <;> rfl

theorem shape_pv {P : BlockParams} (hpf : ProfR c.sh P) : (slotShape P 9).1 = c.sh.lkv + c.sh.lt := by
  rw [hpf.slots 9 (by norm_num)]
  rfl

end Prog

/-! ## `SC_QMM`, `SC_KMM`, `SC_VMM` -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrlA : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

include hX in
theorem alg_plDR (off : ℕ) (x : CtR c × CwR c) :
    algebraMap GF K (plD U c P D off x) = aPl U P D off (nD c) (Fin.append x.1 x.2) :=
  aPl_alg U P D hX off (nD c) _

include G hX hrlA in
/-- **`SC_QMM`'s unmasked sum is the extension of `r13Mm 15 0` at its draws** (`Y·W_q`, `PubR.wq`). -/
theorem qmm_spSumR (hcfg : QkvCfg c ls) (hpf : ProfR c.sh P) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B)
    (ioIn ioOut : ℕ) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec) (hr : rs[5]? = some r)
    (hc : ∀ x ∈ r.draws, x.Canon) :
    spSum P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) bga rs 5
      = mleAt (fun b : Fin (c.sh.logs .Q) → Bool =>
          algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 0 (.q (splitQ c (castB G.logQ b)))))
        (fun t => (r.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨mrow, hprog⟩ := prog_mm hcfg ioIn ioOut 5 (Or.inl rfl)
  refine Eq.trans ?_ (mleAt_castB G.logQ (fun y : Fin (nQ c) → Bool =>
    algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 0 (.q (splitQ c y))))
    (fun t : Fin (nQ c) => (r.draws.getD t Fp2.zero).toK U)).symm
  rw [mm_spSum U P D hrlA _ pubs 5 (DefR13.aOff c 11) mrow c.sh.lt c.sh.ld (nH c + c.sh.ldh) (drs 5 0 c.sh.lt)
    (drs_len 5 0 c.sh.lt) (shape_mm hpf 5 (Or.inl rfl)) (by have := G.lt_pos; omega) hprog bga rs r hr
    (fun cc y => algebraMap GF K (B.Wq cc (splitHQ c y))) (fun a => (r.draws.getD (c.sh.lt + a) Fp2.zero).toK U)
    (fun cc => hpub.wq _ _ hc cc)]
  have hpt : Fin.append (fun i : Fin c.sh.lt => (((drs 5 0 c.sh.lt).map
      (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 5)) 5 r.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin (nH c + c.sh.ldh) => (r.draws.getD (c.sh.lt + a) Fp2.zero).toK U)
      = fun t : Fin (nQ c) => (r.draws.getD t Fp2.zero).toK U := by
    funext t
    refine Fin.addCases (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left, drs_getD _ 5 0 c.sh.lt i i.isLt, eval_self, Nat.zero_add, Fin.val_castAdd]
    · rw [Fin.append_right, Fin.val_natAdd]
  rw [hpt]
  congr 1
  funext y
  simp only [r13Mm, xtR, map_sum, map_mul, alg_plDR U P D hX]
  rfl

/-- A split claim point: the first `a` coordinates `SC_QMM`'s draws, the rest the hosted slot's own. -/
theorem split_ptR (a m : ℕ) (d5 dj : List Fp2) :
    Fin.append (fun i : Fin a => (d5.getD i Fp2.zero).toK U) (fun i : Fin m => (dj.getD (0 + i) Fp2.zero).toK U)
      = fun t : Fin (a + m) => if (t : ℕ) < a then (d5.getD t Fp2.zero).toK U
          else (dj.getD ((t : ℕ) - a) Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left, Fin.val_castAdd, ite_eq_left i.isLt]
  · rw [Fin.append_right, Fin.val_natAdd, ite_eq_right (by omega), Nat.zero_add, Nat.add_sub_cancel_left]

include G hX hrlA in
/-- **`SC_KMM`'s (`SC_VMM`'s) unmasked sum is the extension of `r13Mm 16 i` at its split point.** -/
theorem kvmm_spSumR (hcfg : QkvCfg c ls) (hpf : ProfR c.sh P) (pubs : PubTabs) (ioIn ioOut : ℕ) (s : ℕ)
    (hs : s = 6 ∨ s = 7) (i : Fin 2) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r5 r : SlotRec)
    (hr5 : rs[5]? = some r5) (hr : rs[s]? = some r)
    (hW : ∀ cc, ((pubs s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) r.draws 0).getD (msbIndex c.sh.ld cc)
        Fp2.zero).toK U
      = ∑ y : Fin (c.sh.lkv + c.sh.ldh) → Bool, W16.eqDr U r.draws 0 (c.sh.lkv + c.sh.ldh) y
        * algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) cc (splitGD c y))) :
    spSum P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) bga rs s
      = mleAt (fun b : Fin (c.sh.logs .Kv) → Bool =>
          algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 16 i (.kv (splitK c (castB G.logK b)))))
        (fun t => if (t : ℕ) < c.sh.lt then (r5.draws.getD t Fp2.zero).toK U
          else (r.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U) := by
  obtain ⟨mrow, hprog⟩ := prog_mm hcfg ioIn ioOut s (Or.inr hs)
  refine Eq.trans ?_ (mleAt_castB G.logK (fun y : Fin (nK c) → Bool =>
    algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 16 i (.kv (splitK c y))))
    (fun t : Fin (nK c) => if (t : ℕ) < c.sh.lt then (r5.draws.getD t Fp2.zero).toK U
      else (r.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U)).symm
  rw [mm_spSum U P D hrlA _ pubs s (DefR13.aOff c 11) mrow c.sh.lt c.sh.ld (c.sh.lkv + c.sh.ldh) (drs 5 0 c.sh.lt)
    (drs_len 5 0 c.sh.lt) (shape_mm hpf s (Or.inr hs)) (by have := G.lt_pos; omega) hprog bga rs r hr
    (fun cc y => algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) cc (splitGD c y)))
    (fun a => (r.draws.getD (0 + a) Fp2.zero).toK U) hW]
  have h5s : 5 < s := by omega
  rw [drs_map_hist bga rs s 5 r.draws r5 h5s hr5 0 c.sh.lt (histOf bga.1 bga.2.1 bga.2.2 [])]
  have hpt : Fin.append (fun i : Fin c.sh.lt => (((drs 5 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 5
      r5.draws)).getD i Fp2.zero).toK U) (fun a : Fin (c.sh.lkv + c.sh.ldh) => (r.draws.getD (0 + a) Fp2.zero).toK U)
      = fun t : Fin (nK c) => if (t : ℕ) < c.sh.lt then (r5.draws.getD t Fp2.zero).toK U
          else (r.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U := by
    refine Eq.trans ?_ (split_ptR U c.sh.lt (c.sh.lkv + c.sh.ldh) r5.draws r.draws)
    congr 1
    funext a
    rw [drs_getD _ 5 0 c.sh.lt a a.isLt, eval_self, Nat.zero_add]
  rw [hpt]
  congr 1
  funext y
  rcases i with ⟨_ | _ | _, hi⟩
  · simp only [r13Mm, xtR, map_sum, map_mul, alg_plDR U P D hX]
    rfl
  · simp only [r13Mm, xtR, map_sum, map_mul, alg_plDR U P D hX]
    rfl
  · omega

end Mm

/-! ## Claim points made of coordinate blocks -/

section Pt

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem ptK_rng (xr : ℕ → K) (s m a : ℕ) (h : a < m) :
    ptK U xr ((List.range' s m).map Coord.rho) a = xr (s + a) := by
  unfold ptK
  rw [List.getElem?_map, List.getElem?_range' h, Nat.one_mul]
  rfl

theorem ptK_fix (xr : ℕ → K) (vs : List Fp2) (a : ℕ) (h : a < vs.length) :
    ptK U xr (vs.map Coord.fixed) a = (vs.getD a Fp2.zero).toK U := by
  unfold ptK
  rw [List.getElem?_map, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem h]
  rfl

/-- A claim point of three coordinate blocks. -/
theorem ptK3 (xr : ℕ → K) (A B C : List Coord) (na nb : ℕ) (ha : A.length = na) (hb : B.length = nb) (a : ℕ) :
    ptK U xr (A ++ B ++ C) a
      = if a < na then ptK U xr A a else if a < na + nb then ptK U xr B (a - na) else ptK U xr C (a - na - nb) := by
  subst ha hb
  unfold ptK
  rw [List.append_assoc]
  by_cases h1 : a < A.length
  · rw [ite_eq_left h1, List.getElem?_append_left h1]
  · rw [ite_eq_right h1, List.getElem?_append_right (by omega)]
    by_cases h2 : a < A.length + B.length
    · rw [ite_eq_left h2, List.getElem?_append_left (by omega)]
    · rw [ite_eq_right h2, List.getElem?_append_right (by omega)]

/-- A claim point of four coordinate blocks. -/
theorem ptK4 (xr : ℕ → K) (A B C D : List Coord) (na nb nc : ℕ) (ha : A.length = na) (hb : B.length = nb)
    (hc : C.length = nc) (a : ℕ) :
    ptK U xr (A ++ B ++ C ++ D) a
      = if a < na then ptK U xr A a else if a < na + nb then ptK U xr B (a - na)
        else if a < na + nb + nc then ptK U xr C (a - na - nb) else ptK U xr D (a - na - nb - nc) := by
  subst ha hb hc
  unfold ptK
  rw [List.append_assoc, List.append_assoc]
  by_cases h1 : a < A.length
  · rw [ite_eq_left h1, List.getElem?_append_left h1]
  · rw [ite_eq_right h1, List.getElem?_append_right (by omega)]
    by_cases h2 : a < A.length + B.length
    · rw [ite_eq_left h2, List.getElem?_append_left (by omega)]
    · rw [ite_eq_right h2, List.getElem?_append_right (by omega)]
      by_cases h3 : a < A.length + B.length + C.length
      · rw [ite_eq_left h3, List.getElem?_append_left (by omega)]
      · rw [ite_eq_right h3, List.getElem?_append_right (by omega)]

variable (c : W16Cfg) (e : ℕ) (g : Fin c.sh.lkv → Bool) (t' : Fin c.sh.lt → Bool)

omit [Algebra GF K] in
theorem xr_g (i : Fin c.sh.lkv) :
    xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')) i = bit (g i) := by
  have := i.isLt
  rw [xrK_cpt, dite_eq_left (by omega),
    show (⟨(i : ℕ), by omega⟩ : Fin (c.sh.lkv + c.sh.lt)) = Fin.castAdd c.sh.lt i from rfl, Fin.append_left]

omit [Algebra GF K] in
theorem xr_t (i : Fin c.sh.lt) :
    xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')) (c.sh.lkv + i) = bit (t' i) := by
  have := i.isLt
  rw [xrK_cpt, dite_eq_left (by omega),
    show (⟨c.sh.lkv + (i : ℕ), by omega⟩ : Fin (c.sh.lkv + c.sh.lt)) = Fin.natAdd c.sh.lkv i from rfl,
    Fin.append_right]

omit [Algebra GF K] in
theorem xr_gk (i : Fin c.sh.lkv) (k : ℕ) (hk : k = i) :
    xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')) k = bit (g i) := by
  rw [hk]
  exact xr_g c e g t' i

omit [Algebra GF K] in
theorem xr_tk (i : Fin c.sh.lt) (k : ℕ) (hk : k = c.sh.lkv + i) :
    xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')) k = bit (t' i) := by
  rw [hk]
  exact xr_t c e g t' i

theorem ev_k (ev : Sym → Fp2) (j k : ℕ) (hk : k = j) : (ev (.dr 9 k)).toK U = (ev (.dr 9 j)).toK U := by
  rw [hk]

/-- **`PP`'s claim point at the cube point `(g, t')`**: `(g, r_hj, r_t, t')`. -/
theorem ptPPR (ev : Sym → Fp2) :
    (fun a : Fin (nS c) => ptK U (xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')))
        ((ppCR c).map (CoordS.eval ev)) a)
      = Fin.append (Fin.append (fun i : Fin c.sh.lkv => bit (g i))
          (fun i : Fin (c.sh.lh - c.sh.lkv) => (ev (.dr 9 (c.sh.lkv + i))).toK U))
        (Fin.append (fun i : Fin c.sh.lt => (ev (.dr 9 (c.sh.lh + i))).toK U) (fun i : Fin c.sh.lt => bit (t' i))) := by
  have hmap : (ppCR c).map (CoordS.eval ev)
      = (List.range' 0 (c.sh.lkv - 0)).map Coord.rho ++ ((drs 9 c.sh.lkv (c.sh.lh - c.sh.lkv)).map ev).map Coord.fixed
        ++ ((drs 9 c.sh.lh c.sh.lt).map ev).map Coord.fixed
        ++ (List.range' c.sh.lkv (c.sh.lkv + c.sh.lt - c.sh.lkv)).map Coord.rho := by
    unfold ppCR
    simp only [List.map_append, rhoC_eval, List.map_map]
    rfl
  have hnH : nH c = c.sh.lkv + (c.sh.lh - c.sh.lkv) := rfl
  funext a
  rw [hmap, ptK4 U _ _ _ _ _ c.sh.lkv (c.sh.lh - c.sh.lkv) c.sh.lt (by simp) (by simp [drs_len])
    (by simp [drs_len])]
  refine Fin.addCases (fun a1 => ?_) (fun a2 => ?_) a
  · rw [Fin.append_left]
    refine Fin.addCases (fun i => ?_) (fun i => ?_) a1
    · have := i.isLt
      rw [Fin.append_left, Fin.val_castAdd, Fin.val_castAdd, ite_eq_left (by omega), ptK_rng U _ _ _ _ (by omega)]
      exact xr_gk (K := K) c e g t' i _ (by omega)
    · have := i.isLt
      rw [Fin.append_right, Fin.val_castAdd, Fin.val_natAdd, ite_eq_right (by omega), ite_eq_left (by omega),
        ptK_fix U _ _ _ (by rw [List.length_map, drs_len]; omega), drs_getD _ 9 _ _ _ (by omega)]
      exact ev_k U ev _ _ (by omega)
  · rw [Fin.append_right]
    refine Fin.addCases (fun i => ?_) (fun i => ?_) a2
    · have := i.isLt
      rw [Fin.append_left, Fin.val_natAdd, Fin.val_castAdd, ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_left (by omega), ptK_fix U _ _ _ (by rw [List.length_map, drs_len]; omega), drs_getD _ 9 _ _ _ (by omega)]
      exact ev_k U ev _ _ (by omega)
    · have := i.isLt
      rw [Fin.append_right, Fin.val_natAdd, Fin.val_natAdd, ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ptK_rng U _ _ _ _ (by omega)]
      exact xr_tk (K := K) c e g t' i _ (by omega)

/-- **`V`'s claim point at the cube point `(g, t')`**: `(t', g, r_i)`. -/
theorem ptVR (ev : Sym → Fp2) :
    (fun a : Fin (nK c) => ptK U (xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')))
        ((vCR c).map (CoordS.eval ev)) a)
      = Fin.append (fun i : Fin c.sh.lt => bit (t' i))
          (Fin.append (fun i : Fin c.sh.lkv => bit (g i))
            (fun i : Fin c.sh.ldh => (ev (.dr 9 (c.sh.lh + c.sh.lt + i))).toK U)) := by
  have hmap : (vCR c).map (CoordS.eval ev)
      = (List.range' c.sh.lkv (c.sh.lkv + c.sh.lt - c.sh.lkv)).map Coord.rho
        ++ (List.range' 0 (c.sh.lkv - 0)).map Coord.rho
        ++ ((drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh).map ev).map Coord.fixed := by
    unfold vCR
    simp only [List.map_append, rhoC_eval, List.map_map]
    rfl
  funext a
  rw [hmap, ptK3 U _ _ _ _ c.sh.lt c.sh.lkv (by simp) (by simp)]
  refine Fin.addCases (fun i => ?_) (fun a2 => ?_) a
  · have := i.isLt
    rw [Fin.append_left, Fin.val_castAdd, ite_eq_left (by omega), ptK_rng U _ _ _ _ (by omega)]
    exact xr_t (K := K) c e g t' i
  · rw [Fin.append_right]
    refine Fin.addCases (fun i => ?_) (fun i => ?_) a2
    · have := i.isLt
      rw [Fin.append_left, Fin.val_natAdd, Fin.val_castAdd, ite_eq_right (by omega), ite_eq_left (by omega),
        ptK_rng U _ _ _ _ (by omega)]
      exact xr_gk (K := K) c e g t' i _ (by omega)
    · have := i.isLt
      rw [Fin.append_right, Fin.val_natAdd, Fin.val_natAdd, ite_eq_right (by omega), ite_eq_right (by omega),
        ptK_fix U _ _ _ (by rw [List.length_map, drs_len]; omega), drs_getD _ 9 _ _ _ (by omega)]
      exact ev_k U ev _ _ (by omega)

end Pt

/-! ## `SC_PV` -/

section Pv

variable {K : Type} [Field K] [Algebra GF K] (U : K)

omit [Algebra GF K] in
/-- `PP`'s extension at `(g, r_j, r_t, t')`. -/
theorem mle_ppR {a b d e : ℕ} (f : (Fin ((a + b) + (d + e)) → Bool) → K) (g : Fin a → Bool) (q : Fin b → K)
    (r : Fin d → K) (t' : Fin e → Bool) :
    mleAt f (Fin.append (Fin.append (fun i => bit (g i)) q) (Fin.append r (fun i => bit (t' i))))
      = ∑ z : Fin b → Bool, eqPoly q (fun i => bit (z i)) * ∑ w : Fin d → Bool, eqPoly r (fun i => bit (w i))
          * f (Fin.append (Fin.append g z) (Fin.append w t')) := by
  rw [mleAt_app', mleAt_bits_append]
  simp only [mleAt_append_bits]

omit [Algebra GF K] in
/-- `V`'s extension at `(t', g, r_i)`. -/
theorem mle_vR {a b d : ℕ} (f : (Fin (a + (b + d)) → Bool) → K) (t' : Fin a → Bool) (g : Fin b → Bool)
    (s : Fin d → K) :
    mleAt f (Fin.append (fun i => bit (t' i)) (Fin.append (fun i => bit (g i)) s))
      = ∑ cc : Fin d → Bool, eqPoly s (fun i => bit (cc i)) * f (Fin.append t' (Fin.append g cc)) := by
  rw [mleAt_app', mleAt_bit, mleAt_bits_append]

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P) (hrlA : 0 < rowLog P .a)

include G hrlA in
/-- **`SC_PV`'s cube sum** at R13 (`n = lkv + lt` main variables, `0 < lkv`):
`Σ_{g, t'} eq(r_g, g)·PP̃(g, r_j, r_t, t')·Ṽ(t', g, r_i)`. -/
theorem pv_cubeR (n e : ℕ) (hn : n = c.sh.lkv + c.sh.lt) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (m1 m2 : ℕ) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 9 dr)).map (Fp2.toK U))
      (([TabS.eq (drs 9 0 c.sh.lkv) 0, .priv ⟨.a, [(DefR13.aOff c 81, false)], nS c, ppCR c, m1, 0⟩,
          .priv ⟨.a, [(DefR13.aOff c 66, false)], nK c, vCR c, m2, 1⟩].map
        (TabS.eval (Sym.eval hist 9 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin c.sh.lkv → Bool, ∑ t' : Fin c.sh.lt → Bool,
      eqPoly (fun i : Fin c.sh.lkv => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i))
        * ((∑ z : Fin (c.sh.lh - c.sh.lkv) → Bool,
              eqPoly (fun i : Fin (c.sh.lh - c.sh.lkv) => (dr.getD (c.sh.lkv + i) Fp2.zero).toK U) (fun i => bit (z i))
              * ∑ w : Fin c.sh.lt → Bool,
                eqPoly (fun i : Fin c.sh.lt => (dr.getD (c.sh.lh + i) Fp2.zero).toK U) (fun i => bit (w i))
                * aPl U P D (DefR13.aOff c 81) (nS c) (Fin.append (Fin.append g z) (Fin.append w t')))
          * (∑ cc : Fin c.sh.ldh → Bool,
              eqPoly (fun i : Fin c.sh.ldh => (dr.getD (c.sh.lh + c.sh.lt + i) Fp2.zero).toK U) (fun i => bit (cc i))
              * aPl U P D (DefR13.aOff c 66) (nK c) (Fin.append t' (Fin.append g cc)))) := by
  subst hn
  set ev := Sym.eval hist 9 dr with hev
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map ev).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U), gV_some]
  have hnS : 0 < nS c := by
    have := G.lt_pos
    show 0 < nH c + (c.sh.lt + c.sh.lt)
    omega
  have hnK : 0 < nK c := by
    have := G.lt_pos
    show 0 < c.sh.lt + (c.sh.lkv + c.sh.ldh)
    omega
  rw [cubeSum_split]
  refine (sum_append (a := c.sh.lkv) (b := c.sh.lt) _).trans (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl
    (fun t' _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt _ e (Fin.append g t')) = _
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
    have h0 : tabK U P D (c.sh.lkv + c.sh.lt) e (cpt (c.sh.lkv + c.sh.lt) e (Fin.append g t')) (.eq ((drs 9 0 c.sh.lkv).map ev) 0)
        = eqPoly (fun i : Fin c.sh.lkv => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i)) := by
      rw [tabK_eqHead_cpt U P D (c.sh.lkv + c.sh.lt) e (Fin.append g t') _ c.sh.lkv (drs_length 9 0 c.sh.lkv ev)
        (by omega)]
      congr 1
      · funext a
        rw [drs_getD ev 9 0 c.sh.lkv a a.isLt, hev, eval_self, Nat.zero_add]
      · funext a
        rw [show (⟨(a : ℕ), by omega⟩ : Fin (c.sh.lkv + c.sh.lt)) = Fin.castAdd c.sh.lt a from rfl, Fin.append_left]
    have h1 : tabK U P D (c.sh.lkv + c.sh.lt) e (cpt (c.sh.lkv + c.sh.lt) e (Fin.append g t'))
          (TabS.eval ev pub (.priv ⟨.a, [(DefR13.aOff c 81, false)], nS c, ppCR c, m1, 0⟩))
        = ∑ z : Fin (c.sh.lh - c.sh.lkv) → Bool,
            eqPoly (fun i : Fin (c.sh.lh - c.sh.lkv) => (dr.getD (c.sh.lkv + i) Fp2.zero).toK U) (fun i => bit (z i))
            * ∑ w : Fin c.sh.lt → Bool,
              eqPoly (fun i : Fin c.sh.lt => (dr.getD (c.sh.lh + i) Fp2.zero).toK U) (fun i => bit (w i))
              * aPl U P D (DefR13.aOff c 81) (nS c) (Fin.append (Fin.append g z) (Fin.append w t')) := by
      show tabK U P D (c.sh.lkv + c.sh.lt) e (cpt (c.sh.lkv + c.sh.lt) e (Fin.append g t'))
        (.priv ⟨.a, [(DefR13.aOff c 81, Fp2.one)], nS c, (ppCR c).map (CoordS.eval ev), m1, 0⟩) = _
      rw [tabK_priv_cpt U P D _ e _ _ (by simp) hnS hrlA]
      show mleAt (n := (c.sh.lkv + (c.sh.lh - c.sh.lkv)) + (c.sh.lt + c.sh.lt)) (aPl U P D (DefR13.aOff c 81) (nS c))
        (fun a => ptK U (xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')))
          ((ppCR c).map (CoordS.eval ev)) a) = _
      rw [ptPPR U c e g t' ev]
      simp only [hev, eval_self]
      exact mle_ppR _ g _ _ t'
    have h2 : tabK U P D (c.sh.lkv + c.sh.lt) e (cpt (c.sh.lkv + c.sh.lt) e (Fin.append g t'))
          (TabS.eval ev pub (.priv ⟨.a, [(DefR13.aOff c 66, false)], nK c, vCR c, m2, 1⟩))
        = ∑ cc : Fin c.sh.ldh → Bool,
            eqPoly (fun i : Fin c.sh.ldh => (dr.getD (c.sh.lh + c.sh.lt + i) Fp2.zero).toK U) (fun i => bit (cc i))
            * aPl U P D (DefR13.aOff c 66) (nK c) (Fin.append t' (Fin.append g cc)) := by
      show tabK U P D (c.sh.lkv + c.sh.lt) e (cpt (c.sh.lkv + c.sh.lt) e (Fin.append g t'))
        (.priv ⟨.a, [(DefR13.aOff c 66, Fp2.one)], nK c, (vCR c).map (CoordS.eval ev), m2, 1⟩) = _
      rw [tabK_priv_cpt U P D _ e _ _ (by simp) hnK hrlA]
      show mleAt (n := c.sh.lt + (c.sh.lkv + c.sh.ldh)) (aPl U P D (DefR13.aOff c 66) (nK c))
        (fun a => ptK U (xrK (c.sh.lkv + c.sh.lt) (cpt (K := K) (c.sh.lkv + c.sh.lt) e (Fin.append g t')))
          ((vCR c).map (CoordS.eval ev)) a) = _
      rw [ptVR U c e g t' ev]
      simp only [hev, eval_self]
      exact mle_vR _ t' g _
    rw [h0, h1, h2]
  · show f (bpt _ e (Fin.append g t') y) = 0
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D _ e _ y hy, zero_mul]

variable (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

include hX in
/-- **`SC_PV`'s target**: the extension of `r13Mm 15 1` at a point `(r_t, (r_g, r_j), r_i)`, as five sums. -/
theorem pv_targetR (rt : Fin c.sh.lt → K) (rg : Fin c.sh.lkv → K) (rj : Fin (c.sh.lh - c.sh.lkv) → K)
    (ri : Fin c.sh.ldh → K) :
    mleAt (fun y : Fin (nQ c) → Bool => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c y))))
      (Fin.append rt (Fin.append (Fin.append rg rj) ri))
      = ∑ t : Fin c.sh.lt → Bool, eqPoly rt (fun i => bit (t i))
        * ∑ g : Fin c.sh.lkv → Bool, eqPoly rg (fun i => bit (g i))
          * ∑ j : Fin (c.sh.lh - c.sh.lkv) → Bool, eqPoly rj (fun i => bit (j i))
            * ∑ cc : Fin c.sh.ldh → Bool, eqPoly ri (fun i => bit (cc i))
              * ∑ t' : Fin c.sh.lt → Bool, aPl U P D (DefR13.aOff c 81) (nS c) (Fin.append (Fin.append g j) (Fin.append t t'))
                * aPl U P D (DefR13.aOff c 66) (nK c) (Fin.append t' (Fin.append g cc)) := by
  simp only [mleAt_app']
  unfold mleAt
  refine Finset.sum_congr rfl fun t _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun g _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun j _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun cc _ => ?_
  congr 1
  beta_reduce
  rw [show splitQ c (Fin.append t (Fin.append (Fin.append g j) cc)) = (t, ((g, j), cc)) from
    splitQ_append c (t, ((g, j), cc))]
  simp only [r13Mm, xtR, plS, plK, map_sum, map_mul]
  refine Finset.sum_congr rfl fun t' _ => ?_
  rw [aPl_alg U P D hX, aPl_alg U P D hX]

include G hX hrlA in
/-- **`SC_PV`'s unmasked sum is the extension of `r13Mm 15 1` at its published point** (L36's `ipStd`). -/
theorem pv_spSumR (hcfg : QkvCfg c ls) (hpf : ProfR c.sh P) (pubs : PubTabs) (ioIn ioOut : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec) (hr : rs[9]? = some r) :
    spSum P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) bga rs 9
      = mleAt (fun b : Fin (c.sh.logs .Q) → Bool =>
          algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c (castB G.logQ b)))))
        (fun t => (r.draws.getD (ipStd c.sh.lt c.sh.lh 15 1 t) Fp2.zero).toK U) := by
  obtain ⟨m1, m2, hprog⟩ := prog_pv hcfg ioIn ioOut
  have hle := G.lkv_le
  have hnH : nH c = c.sh.lkv + (c.sh.lh - c.sh.lkv) := rfl
  refine Eq.trans ?_ (mleAt_castB G.logQ (fun y : Fin (nQ c) → Bool =>
    algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 15 1 (.q (splitQ c y))))
    (fun t : Fin (nQ c) => (r.draws.getD (ipStd c.sh.lt c.sh.lh 15 1 t) Fp2.zero).toK U)).symm
  have hpt : (fun t : Fin (nQ c) => (r.draws.getD (ipStd c.sh.lt c.sh.lh 15 1 t) Fp2.zero).toK U)
      = Fin.append (fun i : Fin c.sh.lt => (r.draws.getD (c.sh.lh + i) Fp2.zero).toK U)
          (Fin.append (Fin.append (fun i : Fin c.sh.lkv => (r.draws.getD i Fp2.zero).toK U)
            (fun i : Fin (c.sh.lh - c.sh.lkv) => (r.draws.getD (c.sh.lkv + i) Fp2.zero).toK U))
            (fun i : Fin c.sh.ldh => (r.draws.getD (c.sh.lh + c.sh.lt + i) Fp2.zero).toK U)) := by
    funext t
    unfold ipStd
    rw [ite_eq_left (⟨rfl, rfl⟩ : (15 = 15 ∧ (1 : Fin 2) = 1))]
    refine Fin.addCases (fun i => ?_) (fun a2 => ?_) t
    · have := i.isLt
      rw [Fin.append_left, Fin.val_castAdd, ite_eq_left i.isLt]
    · rw [Fin.append_right]
      refine Fin.addCases (fun a1 => ?_) (fun i => ?_) a2
      · rw [Fin.append_left]
        refine Fin.addCases (fun i => ?_) (fun i => ?_) a1
        · have := i.isLt
          rw [Fin.append_left, Fin.val_natAdd, Fin.val_castAdd, Fin.val_castAdd, ite_eq_right (by omega),
            ite_eq_left (by omega)]
          exact congrArg (fun k => (r.draws.getD k Fp2.zero).toK U) (by omega)
        · have := i.isLt
          rw [Fin.append_right, Fin.val_natAdd, Fin.val_castAdd, Fin.val_natAdd, ite_eq_right (by omega),
            ite_eq_left (by omega)]
          exact congrArg (fun k => (r.draws.getD k Fp2.zero).toK U) (by omega)
      · have := i.isLt
        rw [Fin.append_right, Fin.val_natAdd, Fin.val_natAdd, ite_eq_right (by omega), ite_eq_right (by omega)]
        exact congrArg (fun k => (r.draws.getD k Fp2.zero).toK U) (by omega)
  rw [hpt, pv_targetR U P D hX Pb Lay B]
  unfold spSum
  rw [pv_cubeR U G P D hrlA (slotShape P 9).1 (slotShape P 9).2.1 (shape_pv hpf)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9)) r.draws (pubs 9 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9)) r.draws) m1 m2
    (polyS U P D _ pubs 9 (seenOf bga rs 9)) (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 9 r hr x, hprog])]
  exact pv_sum (fun g : Fin c.sh.lkv → Bool => eqPoly (fun i : Fin c.sh.lkv => (r.draws.getD i Fp2.zero).toK U)
      (fun i => bit (g i)))
    (fun j : Fin (c.sh.lh - c.sh.lkv) → Bool =>
      eqPoly (fun i : Fin (c.sh.lh - c.sh.lkv) => (r.draws.getD (c.sh.lkv + i) Fp2.zero).toK U) (fun i => bit (j i)))
    (fun t : Fin c.sh.lt → Bool => eqPoly (fun i : Fin c.sh.lt => (r.draws.getD (c.sh.lh + i) Fp2.zero).toK U)
      (fun i => bit (t i)))
    (fun cc : Fin c.sh.ldh → Bool =>
      eqPoly (fun i : Fin c.sh.ldh => (r.draws.getD (c.sh.lh + c.sh.lt + i) Fp2.zero).toK U) (fun i => bit (cc i)))
    (fun g j t t' => aPl U P D (DefR13.aOff c 81) (nS c) (Fin.append (Fin.append g j) (Fin.append t t')))
    (fun t' g cc => aPl U P D (DefR13.aOff c 66) (nK c) (Fin.append t' (Fin.append g cc)))

end Pv

end ZK60.Exec.Block.Join.R13H.Qkv
