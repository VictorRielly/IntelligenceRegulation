/-
D63 lane L49 (2026-11-10), sub-agent `qkv`, part 7: **`SC_QZC`'s and `SC_KVZC`'s cube sums with R13's named
relations** (hosts `15`, `16`), generic in the configuration.

* **`qzc_cubeR`**: `SC_QZC`'s numbered slot's cube sum is
  `Σ_t hostPoly(τ, Σ_{κ < 11} μ_κ·(r13Cl 15 κ, or xcQzcR κ), ν, (p_QMM, p_PV), 1, r13Gh 15)(t)`;
* **`kvzc_cubeR`**: the same for `SC_KVZC` (`r13Cl 16`, `xcKvzcR`, `r13Gh 16`, points `p_KMM`, `p_VMM`);
* `drs_append`, `getD_app3`: draw runs joined, a list of three blocks read at an index.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostQkvNamed

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl cstK)
open ZK60.Exec.Block.Join.W16.Qkv (drs eqv)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.DefR13 (QzcR13 r13QzcIr)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## Lists -/

theorem drs_append (s off a b : ℕ) : drs s off a ++ drs s (off + a) b = drs s off (a + b) := by
  unfold drs
  rw [List.range_add, List.map_append, List.map_map]
  congr 1
  refine List.map_congr_left (fun i _ => ?_)
  simp only [Function.comp_apply, Nat.add_assoc]

theorem getD_app3 {α : Type} (l1 l2 l3 : List α) (n1 n2 : ℕ) (h1 : l1.length = n1) (h2 : l2.length = n2) (j : ℕ)
    (d : α) :
    (l1 ++ l2 ++ l3).getD j d
      = if j < n1 then l1.getD j d else if j < n1 + n2 then l2.getD (j - n1) d else l3.getD (j - n1 - n2) d := by
  subst h1 h2
  rw [List.append_assoc, List.getD_eq_getElem?_getD]
  by_cases hj1 : j < l1.length
  · rw [ite_eq_left hj1, List.getElem?_append_left hj1, List.getD_eq_getElem?_getD]
  · rw [ite_eq_right hj1, List.getElem?_append_right (by omega)]
    by_cases hj2 : j < l1.length + l2.length
    · rw [ite_eq_left hj2, List.getElem?_append_left (by omega), List.getD_eq_getElem?_getD]
    · rw [ite_eq_right hj2, List.getElem?_append_right (by omega), List.getD_eq_getElem?_getD]

/-! ## `SC_QZC` -/

section QCube

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hX hrlA hrlH hL in
/-- **`SC_QZC`'s cube sum with R13's named relations.** -/
theorem qzc_cubeR (hS : PrecR c S) (hcfg : QkvCfg c ls) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B)
    (aB hB ioIn ioOut ak hk : ℕ) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2)
    (ha : hist.alpha = bga.2.2) (hgm : hist.gamma = bga.2.1) (n e : ℕ) (hn : n = c.sh.logs .Q)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((DefW16.numSlot aB hB ioIn ioOut ak hk (rawQ c)).ir.map (Sym.eval hist 15 dr)).map
        (Fp2.toK U))
      (((DefW16.numSlot aB hB ioIn ioOut ak hk (rawQ c)).tabs.map
        (TabS.eval (Sym.eval hist 15 dr) (pubs 15 hist dr))).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin (c.sh.logs .Q) → Bool,
      hostPoly (fun a : Fin (c.sh.logs .Q) =>
          (((drs 15 13 (c.sh.logs .Q)).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 11, (((drs 15 0 11).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 κ (encR G 15 t))
            else xcQzcR U c P D bga κ t))
        ![(((drs 15 11 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 15 11 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin (c.sh.logs .Q) =>
            (((drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U,
          fun a : Fin (c.sh.logs .Q) => (((drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh
            ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1)
        (fun i t => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 15 i (encR G 15 t))) t := by
  have hQ : c.sh.logs .Q = c.sh.lt + (c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh) := G.logQ
  have hle := G.lkv_le
  have hlq : c.sh.lq = c.sh.lkv + (c.sh.lh - c.sh.lkv) + c.sh.ldh := G.lq
  have hpos : 0 < c.sh.logs .Q := by
    have := G.lt_pos
    omega
  have h1 : (drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq).length = c.sh.logs .Q := by
    rw [List.length_append, drs_len, drs_len]
    omega
  have h2 : (drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh).length
      = c.sh.logs .Q := by
    rw [List.length_append, List.length_append, drs_len, drs_len, drs_len]
    omega
  rw [zc_cube U c .Q 15 47 2 _ _ RQ rfl c.p.rope c.p.q c.p.pv shQR aB hB ioIn ioOut ak hk P D hrlA hrlH hpos hist dr
    (pubs 15 hist dr) h1 h2 n e hn f hf]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hcos : ((pubs 15 hist dr 0).getD (msbIndex _ t) Fp2.zero).toK U
      = algebraMap GF K (B.cosT (splitQ c (castB G.logQ t))) := by
    rw [← hpub.qzcCos hist dr (castB G.logQ t), msbIndex_castB]
  have hsin : ((pubs 15 hist dr 1).getD (msbIndex _ t) Fp2.zero).toK U
      = algebraMap GF K (B.sinT (splitQ c (castB G.logQ t))) := by
    rw [← hpub.qzcSin hist dr (castB G.logQ t), msbIndex_castB]
  have hV : zcV U c P D .Q 15 47 2 (drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq)
        (drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh) (Sym.eval hist 15 dr)
        (pubs 15 hist dr) t
      = eqv U (drs 15 13 (c.sh.logs .Q)) (Sym.eval hist 15 dr) _ t
        :: eqv U (drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq) (Sym.eval hist 15 dr) _ t
        :: eqv U (drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh)
          (Sym.eval hist 15 dr) _ t
        :: algebraMap GF K (B.cosT (splitQ c (castB G.logQ t)))
        :: algebraMap GF K (B.sinT (splitQ c (castB G.logQ t))) :: zcPl U c P D .Q 47 2 t := by
    unfold zcV
    rw [hcos, hsin]
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · rw [hV, q_clauses U G P D hX Pb Lay B hL hS.rope, show RQ.h0 = 20 from rfl,
      show shQR = fun p => 5 + (p - 47) from rfl, zc_Z U c P D .Q 47 2 hcfg.lkQ bga hist 15 dr ha hgm]
    refine Finset.sum_congr rfl (fun κ _ => ?_)
    congr 1
    by_cases hκ : (κ : ℕ) < 4
    · rw [ite_eq_left hκ, ite_eq_left hκ]
      obtain ⟨k, hk⟩ := κ
      change k < 4 at hκ
      change _ = algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 15 k (encR G 15 t))
      interval_cases k <;> rfl
    · rw [ite_eq_right hκ, ite_eq_right hκ]
      rfl
  · rw [hV]
    obtain ⟨g0, g1⟩ := q_hosts U G P D hX Pb Lay B hL hS hcfg.sq hcfg.spv
      (eqv U (drs 15 13 (c.sh.logs .Q)) (Sym.eval hist 15 dr) _ t)
      (eqv U (drs 5 0 c.sh.lt ++ drs 5 c.sh.lt c.sh.lq) (Sym.eval hist 15 dr) _ t)
      (eqv U (drs 9 c.sh.lh c.sh.lt ++ drs 9 0 c.sh.lh ++ drs 9 (c.sh.lh + c.sh.lt) c.sh.ldh) (Sym.eval hist 15 dr) _ t)
      (algebraMap GF K (B.cosT (splitQ c (castB G.logQ t)))) (algebraMap GF K (B.sinT (splitQ c (castB G.logQ t)))) t
    fin_cases i
    · exact g0
    · exact g1

end QCube

/-! ## `SC_KVZC` -/

section KCube

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hX hrlA hrlH hL in
/-- **`SC_KVZC`'s cube sum with R13's named relations.** -/
theorem kvzc_cubeR (hS : PrecR c S) (hcfg : QkvCfg c ls) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B)
    (aB hB ioIn ioOut ak hk : ℕ) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2)
    (ha : hist.alpha = bga.2.2) (hgm : hist.gamma = bga.2.1) (n e : ℕ) (hn : n = c.sh.logs .Kv)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((DefW16.numSlot aB hB ioIn ioOut ak hk (rawKv c)).ir.map (Sym.eval hist 16 dr)).map
        (Fp2.toK U))
      (((DefW16.numSlot aB hB ioIn ioOut ak hk (rawKv c)).tabs.map
        (TabS.eval (Sym.eval hist 16 dr) (pubs 16 hist dr))).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin (c.sh.logs .Kv) → Bool,
      hostPoly (fun a : Fin (c.sh.logs .Kv) =>
          (((drs 16 13 (c.sh.logs .Kv)).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 11, (((drs 16 0 11).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 κ (encR G 16 t))
            else xcKvzcR U c P D bga κ t))
        ![(((drs 16 11 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 16 11 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin (c.sh.logs .Kv) =>
            (((drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U,
          fun a : Fin (c.sh.logs .Kv) =>
            (((drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1)
        (fun i t => algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 16 i (encR G 16 t))) t := by
  have hK : c.sh.logs .Kv = c.sh.lt + (c.sh.lkv + c.sh.ldh) := G.logK
  have hkw : c.sh.lkvw = c.sh.lkv + c.sh.ldh := G.lkvw
  have hpos : 0 < c.sh.logs .Kv := by
    have := G.lt_pos
    omega
  have h1 : (drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw).length = c.sh.logs .Kv := by
    rw [List.length_append, drs_len, drs_len]
    omega
  have h2 : (drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw).length = c.sh.logs .Kv := by
    rw [List.length_append, drs_len, drs_len]
    omega
  rw [zc_cube U c .Kv 16 61 3 _ _ RK rfl c.p.rope c.p.k c.p.v shKR aB hB ioIn ioOut ak hk P D hrlA hrlH hpos hist dr
    (pubs 16 hist dr) h1 h2 n e hn f hf]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hcos : ((pubs 16 hist dr 0).getD (msbIndex _ t) Fp2.zero).toK U
      = algebraMap GF K (B.cosK (splitK c (castB G.logK t))) := by
    rw [← hpub.kvCos hist dr (castB G.logK t), msbIndex_castB]
  have hsin : ((pubs 16 hist dr 1).getD (msbIndex _ t) Fp2.zero).toK U
      = algebraMap GF K (B.sinK (splitK c (castB G.logK t))) := by
    rw [← hpub.kvSin hist dr (castB G.logK t), msbIndex_castB]
  have hV : zcV U c P D .Kv 16 61 3 (drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw) (drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw)
        (Sym.eval hist 16 dr) (pubs 16 hist dr) t
      = eqv U (drs 16 13 (c.sh.logs .Kv)) (Sym.eval hist 16 dr) _ t
        :: eqv U (drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw) (Sym.eval hist 16 dr) _ t
        :: eqv U (drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw) (Sym.eval hist 16 dr) _ t
        :: algebraMap GF K (B.cosK (splitK c (castB G.logK t)))
        :: algebraMap GF K (B.sinK (splitK c (castB G.logK t))) :: zcPl U c P D .Kv 61 3 t := by
    unfold zcV
    rw [hcos, hsin]
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · rw [hV, k_clauses U G P D hX Pb Lay B hL hS.rope, show RK.h0 = 20 from rfl,
      show shKR = fun p => 5 + (p - 61) from rfl, zc_Z U c P D .Kv 61 3 hcfg.lkK bga hist 16 dr ha hgm]
    refine Finset.sum_congr rfl (fun κ _ => ?_)
    congr 1
    by_cases hκ : (κ : ℕ) < 4
    · rw [ite_eq_left hκ, ite_eq_left hκ]
      obtain ⟨k, hk⟩ := κ
      change k < 4 at hκ
      change _ = algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 16 k (encR G 16 t))
      interval_cases k <;> rfl
    · rw [ite_eq_right hκ, ite_eq_right hκ]
      rfl
  · rw [hV]
    obtain ⟨g0, g1⟩ := k_hosts U G P D hX Pb Lay B hL hS hcfg.sk hcfg.sv
      (eqv U (drs 16 13 (c.sh.logs .Kv)) (Sym.eval hist 16 dr) _ t)
      (eqv U (drs 5 0 c.sh.lt ++ drs 6 0 c.sh.lkvw) (Sym.eval hist 16 dr) _ t)
      (eqv U (drs 5 0 c.sh.lt ++ drs 7 0 c.sh.lkvw) (Sym.eval hist 16 dr) _ t)
      (algebraMap GF K (B.cosK (splitK c (castB G.logK t)))) (algebraMap GF K (B.sinK (splitK c (castB G.logK t)))) t
    fin_cases i
    · exact g0
    · exact g1

end KCube

end ZK60.Exec.Block.Join.R13H.Qkv
