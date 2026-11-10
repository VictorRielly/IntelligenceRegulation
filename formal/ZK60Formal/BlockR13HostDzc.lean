/-
D63 lane L49 (2026-11-10), sub-agent dzc, part 4: **`SC_DZC`'s named identity at R13** (lane L36's `hform` at host
`14`, with its hosted `SC_WO` (slot `10`) and `SC_DMM` (slot `13`)), generic in the configuration: the R13 rung
(`cfgRungR13`) and every layer of the app's Shieldstral T128 R13 block (`cfgShieldR13 L`), on the lane's foundation
`BlockR13HostBase.lean`. The R13 counterpart of lane L44's `formAt_dzc` (BlockHostDzc.lean).

* **`dzc_cube`**: `SC_DZC`'s cube sum (L41's `cubeSum_host`) for any claim sites;
* `sum_HQR`, `append_drawsR`; **`mm_woR`**, **`mm_dmmR`**: the hosted matmuls' cube sums are the multilinear extensions
  of `r13Mm 14 0` / `r13Mm 14 1` at their claim points (the public folded weights `PubR.wo`, `PubR.wd`);
* `dl_dz`, `segSum_dz`, `segAt_dz`: `SC_DZC`'s draw segments at a configuration with `DzcCfg`;
* **`formAt_dzcR`**: L36's `FormAt` at host `14`, for every configuration with `GeoR`, `ShOkR`, `ProfR`, `DzcCfg`
  (`dzcCfg_rung`, `dzcCfg_shield`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostDzcVals

set_option autoImplicit false
-- Broad simp sets, as in `SlotW16BuildSlots.lean`. Style warnings only.
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

namespace ZK60.Exec.Block.Join.R13H.Dzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg cstK cstS_map aFx_eval pubT_eval mm_cube mm_fold eqDr formAt_two)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (hostTerms gV mmIr mmIr_eval)
open ZK60.Exec.Slot.Compose (mmIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## `SC_DZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s cube sum** (L41's `cubeSum_host`), at `n = log(Dom::D)` main variables, for any claim sites. -/
theorem dzc_cube (hcfg : DzcCfg c ls) (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk n e : ℕ)
    (hn : n = c.sh.logs .D) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hp0 : ∀ b : Fin (c.sh.logs .D) → Bool, ((pub 0).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gamA (splitD c (castB G.logD b))))
    (hp1 : ∀ b : Fin (c.sh.logs .D) → Bool, ((pub 1).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gamM (splitD c (castB G.logD b))))
    (hp2 : ∀ b : Fin (c.sh.logs .D) → Bool, ((pub 2).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gD (splitD c (castB G.logD b))))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((irDz c).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
      (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub n e x)) :
    cubeSum f = ∑ b : Fin (c.sh.logs .D) → Bool, hostPoly
      (fun a : Fin (c.sh.logs .D) => (((drR 14 34 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
      (fun b => zD U c hist dr (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e
        (cpt (c.sh.logs .D) e b)))
      ![(((drR 14 31 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 0 0,
        (((drR 14 31 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 1 0]
      ![fun a : Fin (c.sh.logs .D) => (((drR 10 0 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
        fun a : Fin (c.sh.logs .D) => (((drR 13 0 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
      (fun _ => 1)
      (fun i b => if i = 0
        then gV (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e
            (cpt (c.sh.logs .D) e b)) (some 63)
          * reqV8 (cstK U) (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e
            (cpt (c.sh.logs .D) e b)) c.p.ao 17 [20, 21, 22]
        else gV (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e
            (cpt (c.sh.logs .D) e b)) (some 63)
          * reqV8 (cstK U) (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e
            (cpt (c.sh.logs .D) e b)) c.p.down 35 [38, 39, 40]) b := by
  subst hn
  have hv := fun b => dzc_vals U G P D Pb Lay B hrl aB hB ioIn ioOut ak hk e b (Sym.eval hist 14 dr) pub (hp0 b)
    (hp1 b) (hp2 b)
  rw [cubeSum_host (c.sh.logs .D) e (valsN U c P D aB hB ioIn ioOut ak hk (Sym.eval hist 14 dr) pub (c.sh.logs .D) e)
    0 1 2 (some 63) (some 63) (((drR 14 31 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)) (zD U c hist dr)
    (fun v => reqV8 (cstK U) v c.p.ao 17 [20, 21, 22]) (fun v => reqV8 (cstK U) v c.p.down 35 [38, 39, 40]) f
    (fun x => by rw [hf x, dzc_irEval U hcfg hist dr]; first | done | rfl)
    (fun b y hy => dzc_off U P D aB hB ioIn ioOut ak hk e (Sym.eval hist 14 dr) pub b y hy)
    (fun a : Fin (c.sh.logs .D) => (((drR 14 34 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
    ![fun a : Fin (c.sh.logs .D) => (((drR 10 0 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
      fun a : Fin (c.sh.logs .D) => (((drR 13 0 (c.sh.logs .D)).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
    (fun b => by rw [hv b]; first | done | rfl) (fun b => by rw [hv b]; first | done | rfl)
    (fun b => by rw [hv b]; first | done | rfl)]

end Cube

/-! ## The hosted matmuls -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- A point of `a + b` coordinates read off one draw list. -/
theorem append_drawsR (dr : List Fp2) (a b : ℕ) :
    Fin.append (fun i : Fin a => (dr.getD i Fp2.zero).toK U) (fun j : Fin b => (dr.getD (a + j) Fp2.zero).toK U)
      = fun t : Fin (a + b) => (dr.getD t Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left, Fin.val_castAdd]
  · rw [Fin.append_right, Fin.val_natAdd]

/-- The head-slot-and-dimension bits as the product. -/
def eHQR (c : W16Cfg) : (Fin (nH c + c.sh.ldh) → Bool) ≃ (CgR c × CjR c) × CdR c :=
  ⟨splitHQ c, fun x => Fin.append (Fin.append x.1.1 x.1.2) x.2, append_splitHQR c, splitHQ_append c⟩

/-- `Dom::Q`'s head-slot-and-dimension sum as a sum over bit vectors. -/
theorem sum_HQR {M : Type} [AddCommMonoid M] (c : W16Cfg) (F : (CgR c × CjR c) × CdR c → M) :
    ∑ x, F x = ∑ q : Fin (nH c + c.sh.ldh) → Bool, F (splitHQ c q) :=
  (Fintype.sum_equiv (eHQR c) (fun q => F (splitHQ c q)) F (fun _ => rfl)).symm

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

include G hX in
/-- **`SC_WO`'s cube sum** (slot `10`): the multilinear extension of `r13Mm 14 0` (`Σ_c O(t, c)·W_o(c, w)`) at its claim
point `(r_q, r_j)`, with the public folded weight `PubR.wo`. -/
theorem mm_woR (hcfg : DzcCfg c ls) (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B)
    (ioIn ioOut : ℕ) (hs10 : (slotShape P 10).1 = nH c + c.sh.ldh) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r10 : SlotRec) (hr10 : rs[10]? = some r10) (hc10 : ∀ x ∈ r10.draws, x.Canon) :
    spSum P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) bga rs 10
      = mleAt (fun y : Fin (nD c) → Bool => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 0 (.d (splitD c y))))
          (fun t : Fin (nD c) => (r10.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk', hslot⟩ := progR13_slot c ioIn ioOut 10 (by norm_num)
  unfold spSum
  have hvs : ((drR 10 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)).length
      = c.sh.lt := drR_length 10 0 _ _
  rw [mm_cube U P D hrl (slotShape P 10).1 (slotShape P 10).2.1
    ((drR 10 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)) c.sh.lt
    (nH c + c.sh.ldh) hvs hs10 (by have := G.lt_pos; omega) (DefR13.aOff c 56) (DefR13.aDataRows c + 2 * ak)
    (pubs 10 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) r10.draws 0)
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 10 (seenOf bga rs 10))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 10 r10 hr10 x, hslot, hcfg.raw10]
      simp only [DefW16.numSlot, rawWo, numTabs_ac, numTabs_pubc, numTabs_nil]
      rw [mmIr_map, mmIr_map, cstS_map, mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ]
      first | done | rfl)]
  have hr : (fun i : Fin c.sh.lt => ((((drR 10 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10
      r10.draws)).getD i Fp2.zero).toK U)) = fun i : Fin c.sh.lt => (r10.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drR_getD _ 10 0 _ i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  simp only [hpub.wo _ _ hc10, eqDr]
  refine (mm_fold (fun z q => aPl U P D (DefR13.aOff c 56) (c.sh.lt + (nH c + c.sh.ldh)) (Fin.append z q))
    (fun q y => algebraMap GF K (B.Wo (splitHQ c q) y)) (fun i : Fin c.sh.lt => (r10.draws.getD i Fp2.zero).toK U)
    (fun a : Fin c.sh.ld => (r10.draws.getD (c.sh.lt + a) Fp2.zero).toK U)).trans ?_
  rw [append_drawsR U r10.draws c.sh.lt c.sh.ld]
  congr 1
  funext y
  simp only [r13Mm, map_sum, map_mul]
  rw [sum_HQR c]
  refine Finset.sum_congr rfl (fun q _ => ?_)
  show _ = algebraMap GF K (plQ U c P D (offR c 56) ((splitD c y).1, splitHQ c q)) * _
  rw [show algebraMap GF K (plQ U c P D (offR c 56) ((splitD c y).1, splitHQ c q))
      = aPl U P D (offR c 56) (nQ c) (Fin.append (splitD c y).1 (Fin.append (Fin.append (splitHQ c q).1.1
        (splitHQ c q).1.2) (splitHQ c q).2)) from aPl_alg U P D hX _ _ _, append_splitHQR]
  first | done | rfl

include G hX in
/-- **`SC_DMM`'s cube sum** (slot `13`): the multilinear extension of `r13Mm 14 1` (`Σ_f H(t, f)·W_d(f, w)`) at its
claim point `(r_row, r_j)`, with the public folded weight `PubR.wd`. -/
theorem mm_dmmR (hcfg : DzcCfg c ls) (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B)
    (ioIn ioOut : ℕ) (hs13 : (slotShape P 13).1 = c.sh.lf) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r13 : SlotRec) (hr13 : rs[13]? = some r13) (hc13 : ∀ x ∈ r13.draws, x.Canon) :
    spSum P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs) bga rs 13
      = mleAt (fun y : Fin (nD c) → Bool => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 1 (.d (splitD c y))))
          (fun t : Fin (nD c) => (r13.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk', hslot⟩ := progR13_slot c ioIn ioOut 13 (by norm_num)
  unfold spSum
  have hvs : ((drR 13 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)).length
      = c.sh.lt := drR_length 13 0 _ _
  rw [mm_cube U P D hrl (slotShape P 13).1 (slotShape P 13).2.1
    ((drR 13 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)) c.sh.lt
    c.sh.lf hvs hs13 (by have := G.lt_pos; omega) (DefR13.aOff c (86 + 2 * ls + 10)) (DefR13.aDataRows c + 2 * ak)
    (pubs 13 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) r13.draws 0)
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 13 (seenOf bga rs 13))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 13 r13 hr13 x, hslot, hcfg.raw13]
      simp only [DefW16.numSlot, rawDmm, numTabs_ac, numTabs_pubc, numTabs_nil]
      rw [mmIr_map, mmIr_map, cstS_map, mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ]
      first | done | rfl)]
  have hr : (fun i : Fin c.sh.lt => ((((drR 13 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13
      r13.draws)).getD i Fp2.zero).toK U)) = fun i : Fin c.sh.lt => (r13.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drR_getD _ 13 0 _ i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  simp only [hpub.wd _ _ hc13, eqDr]
  refine (mm_fold (fun z f => aPl U P D (DefR13.aOff c (86 + 2 * ls + 10)) (c.sh.lt + c.sh.lf) (Fin.append z f))
    (fun f y => algebraMap GF K (B.Wd f y)) (fun i : Fin c.sh.lt => (r13.draws.getD i Fp2.zero).toK U)
    (fun a : Fin c.sh.ld => (r13.draws.getD (c.sh.lt + a) Fp2.zero).toK U)).trans ?_
  rw [append_drawsR U r13.draws c.sh.lt c.sh.ld]
  congr 1
  funext y
  simp only [r13Mm, map_sum, map_mul]
  refine Finset.sum_congr rfl (fun f _ => ?_)
  show _ = algebraMap GF K (plF U c P D (offR c (86 + 2 * ls + 10)) ((splitD c y).1, f)) * _
  rw [show algebraMap GF K (plF U c P D (offR c (86 + 2 * ls + 10)) ((splitD c y).1, f))
      = aPl U P D (offR c (86 + 2 * ls + 10)) (nF c) (Fin.append (splitD c y).1 f) from aPl_alg U P D hX _ _ _]
  first | done | rfl

end Mm

/-! ## `SC_DZC`'s draw segments -/

section Seg

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (P : BlockParams) (hc : ShOkR c.sh P)

theorem dl_dz (hcfg : DzcCfg c ls) :
    (algShapeR c P hc).dl 14 = [(.mu, 31), (.nu, 2), (.zeta, 1), (.tau, c.sh.logs .D)] := hcfg.dl

theorem segSum_dz (hcfg : DzcCfg c ls) : segSum ((algShapeR c P hc).dl 14) = 34 + c.sh.logs .D := by
  rw [dl_dz P hc hcfg]
  simp only [segSum, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
  omega

/-- **A draw of `SC_DZC`'s segment `g`**, read at the draw vector of its record. -/
theorem segAt_dz (hcfg : DzcCfg c ls) (dr : List Fp2) {Dn : ℕ} (h : segSum ((algShapeR c P hc).dl 14) = Dn)
    (g : Seg) (i n : ℕ) (hoff : segOff [(.mu, 31), (.nu, 2), (.zeta, 1), (.tau, c.sh.logs .D)] g = n)
    (hlt : n + i < 34 + c.sh.logs .D) :
    segAt ((algShapeR c P hc).dl 14) (fun j => (dr.getD (Fin.cast h j).val Fp2.zero).toK U) g i
      = (dr.getD (n + i) Fp2.zero).toK U := by
  subst h
  have h1 : segOff ((algShapeR c P hc).dl 14) g + i < segSum ((algShapeR c P hc).dl 14) := by
    rw [segSum_dz P hc hcfg, dl_dz P hc hcfg, hoff]
    exact hlt
  unfold segAt
  rw [dite_eq_left h1]
  show (dr.getD (segOff ((algShapeR c P hc).dl 14) g + i) Fp2.zero).toK U = _
  rw [dl_dz P hc hcfg, hoff]

omit [Algebra GF K] in
/-- A sum over `Fin n` of a function of the index as a range sum. -/
theorem sum_fin_range {n : ℕ} (Gs : Fin n → K) (F : ℕ → K) (hG : ∀ i : Fin n, Gs i = F i) (m : ℕ) (hm : n = m) :
    ∑ i, Gs i = ∑ i ∈ range m, F i := by
  subst hm
  rw [← Fin.sum_univ_eq_sum_range]
  exact Finset.sum_congr rfl (fun i _ => hG i)

omit [Algebra GF K] in
/-- An extension read through an equality of lengths. -/
theorem mleAt_castB {n m : ℕ} (h : n = m) (F : (Fin m → Bool) → K) (g : ℕ → K) :
    mleAt (fun b : Fin n → Bool => F (castB h b)) (fun t : Fin n => g t) = mleAt F (fun t : Fin m => g t) := by
  subst h
  rfl

end Seg

/-! ## `SC_DZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_DZC`'s named identity at R13** (lane L36's `FormAt` at host `14`), generic in the configuration: for every
algebra data `dt` whose host-14 tables are `R13Rels`' relation tables of the extracted planes (`r13Cl 14` in the IR's
batch order `clIx 14`, `r13Gh 14`, `r13Mm 14`, embedded), the LogUp entries `xcDzcR` and the pad planes `pwDzcR`, on
every outcome whose verified slots passed their checks, `SC_DZC`'s certified polynomial at the drawn challenges IS its
unmasked residual. -/
theorem formAt_dzcR (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : DzcCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR c S) (_hW : ZK60.Layout.R13.R13Windows S ls) (_hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 14 cu rt bga κ b = if (κ : ℕ) < r13Count 14
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b))
        else xcDzcR U G P D Pb Lay B bga κ b)
    (hpw : ∀ j b, dt.pw 14 cu rt j b = pwDzcR U G P D Pb Lay B j b)
    (hgh : ∀ i b, dt.gh 14 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 14 i (encR G 14 b)))
    (hmm : ∀ i b, dt.mm 14 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 i (encR G 14 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 14 := by
  -- the slots' cubes
  have hs14 : (slotShape P 14).1 = c.sh.logs .D := by
    rw [hpf.slots 14 (by norm_num)]
    first | done | rfl
  have hs10 : (slotShape P 10).1 = nH c + c.sh.ldh := by
    rw [hpf.slots 10 (by norm_num)]
    exact G.lq
  have hs13 : (slotShape P 13).1 = c.sh.lf := by
    rw [hpf.slots 13 (by norm_num)]
    first | done | rfl
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, x.Canon := by
    intro j rj hrj
    obtain ⟨dfj, hdfj, -⟩ := hslots j rj hrj
    have h' : defineS (DefR13.progR13 c ioIn ioOut) pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws
        = .ok dfj := hdef ▸ hdfj
    have hcn := (defineS_ok h').1
    unfold HistCanon at hcn
    exact hcn.2.2.2
  -- the public tables of `SC_DZC`
  have hp0 : ∀ (hst : Hist) (drr : List Fp2) (b : Fin (c.sh.logs .D) → Bool),
      ((pubs 14 hst drr 0).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
        = algebraMap GF K (B.gamA (splitD c (castB G.logD b))) := fun hst drr b => by
    rw [← msbIndex_castB G.logD b]
    exact hpub.dzcGamA hst drr (castB G.logD b)
  have hp1 : ∀ (hst : Hist) (drr : List Fp2) (b : Fin (c.sh.logs .D) → Bool),
      ((pubs 14 hst drr 1).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
        = algebraMap GF K (B.gamM (splitD c (castB G.logD b))) := fun hst drr b => by
    rw [← msbIndex_castB G.logD b]
    exact hpub.dzcGamM hst drr (castB G.logD b)
  have hp2 : ∀ (hst : Hist) (drr : List Fp2) (b : Fin (c.sh.logs .D) → Bool),
      ((pubs 14 hst drr 2).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
        = algebraMap GF K (B.gD (splitD c (castB G.logD b))) := fun hst drr b => by
    rw [← msbIndex_castB G.logD b]
    exact hpub.dzcGate hst drr (castB G.logD b)
  -- the three slots of the numbered program
  obtain ⟨ak14, hk14, hslot14⟩ := progR13_slot c ioIn ioOut 14 (by norm_num)
  obtain ⟨ak10, hk10, hslot10⟩ := progR13_slot c ioIn ioOut 10 (by norm_num)
  obtain ⟨ak13, hk13, hslot13⟩ := progR13_slot c ioIn ioOut 13 (by norm_num)
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D _ dt cu rt bga rs 14
    (by decide) 10 13 (.dr 14 31) (.dr 14 32) (by rw [hslot14, hcfg.raw14]; first | done | rfl)
    (by rw [hslot10, hcfg.raw10]; first | done | rfl) (by rw [hslot13, hcfg.raw13]; first | done | rfl)
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 14 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r10, hr10⟩ : ∃ r10, rs[10]? = some r10 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r13, hr13⟩ : ∃ r13, rs[13]? = some r13 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 14)
  -- the hosted slots
  rw [mm_woR U G P D hX Pb Lay B hcfg hrl pubs hpub ioIn ioOut hs10 bga rs r10 hr10 (hcan 10 r10 hr10),
    mm_dmmR U G P D hX Pb Lay B hcfg hrl pubs hpub ioIn ioOut hs13 bga rs r13 hr13 (hcan 13 r13 hr13)]
  -- the host
  unfold spSum
  rw [dzc_cube U G P D Pb Lay B hcfg hrl (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
    (slotShape P 14).1 (slotShape P 14).2.1 hs14 hist r.draws (pubs 14 hist r.draws) (hp0 hist r.draws)
    (hp1 hist r.draws) (hp2 hist r.draws) (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 14 (seenOf bga rs 14))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 14 r hr x, hslot14, hcfg.raw14]; first | done | rfl)]
  rw [hostSp_Φ]
  unfold hostPhi
  refine congrArg₂ (· - ·) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    have hv := dzc_vals U G P D Pb Lay B hrl (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
      (slotShape P 14).2.1 t (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (hp0 hist r.draws t)
      (hp1 hist r.draws t) (hp2 hist r.draws t)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · -- τ
      have ha : (a : ℕ) < c.sh.logs .D := a.isLt
      rw [drR_getD _ 14 34 _ a ha]
      exact segAt_dz U P hc hcfg r.draws _ .tau a 34 rfl (by omega)
    · -- the batch
      show batched _ _ _ t = zD U c hist r.draws (valsN U c P D (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut
        ak14 hk14 (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (c.sh.logs .D) (slotShape P 14).2.1
        (cpt (c.sh.logs .D) (slotShape P 14).2.1 t))
      rw [hv, ← dzc_Z U hU G P D hX Pb Lay B hS hcfg hist r.draws (hist.beta, hist.gamma, hist.alpha) rfl rfl t]
      unfold batched
      have hz : segLn ((algShapeR c P hc).dl 14) .zeta = 1 := by
        rw [dl_dz P hc hcfg]
        rfl
      have hmz : segLn ((algShapeR c P hc).dl 14) .mu - segLn ((algShapeR c P hc).dl 14) .zeta = 30 := by
        rw [dl_dz P hc hcfg]
        rfl
      rw [ite_eq_left hz, ite_eq_left hz]
      dsimp only
      refine congrArg₂ (· + ·) ?_ (congrArg₂ (· * ·) ?_ ?_)
      · -- the thirteen clauses and the seventeen helper relations
        refine sum_fin_range _ _ (fun κ => ?_) 30 hmz
        have hκ : (κ : ℕ) < 30 := by have := κ.isLt; omega
        have e := segAt_dz U P hc hcfg r.draws ((algShapeR c P hc).hsum 14 (by decide)) .mu κ 0 rfl (by omega)
        rw [Nat.zero_add] at e
        rw [hcl, e]
        first | done | rfl
      · -- the pad weight
        rw [hmz]
        exact segAt_dz U P hc hcfg r.draws _ .mu 30 0 rfl (by omega)
      · -- the pad planes
        refine sum_fin_range _ _ (fun j => ?_) 39 rfl
        have e := segAt_dz U P hc hcfg r.draws ((algShapeR c P hc).hsum 14 (by decide)) .zeta 0 33 rfl (by omega)
        rw [hpw, e]
        first | done | rfl
    · -- ν
      fin_cases i
      · show segAt _ _ .nu 0 = (((drR 14 31 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 0 0
        exact segAt_dz U P hc hcfg r.draws _ .nu 0 31 rfl (by omega)
      · show segAt _ _ .nu 1 = (((drR 14 31 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 1 0
        exact segAt_dz U P hc hcfg r.draws _ .nu 1 31 rfl (by omega)
    · -- the hosted claim points
      have hj : (j : ℕ) < c.sh.logs .D := j.isLt
      fin_cases i
      · show algPt U (algShapeR c P hc) 14 hist 0 j
          = (((drR 10 0 (c.sh.logs .D)).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drR_getD _ 10 0 _ j hj, Nat.zero_add]
        first | done | rfl
      · show algPt U (algShapeR c P hc) 14 hist 1 j
          = (((drR 13 0 (c.sh.logs .D)).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drR_getD _ 13 0 _ j hj, Nat.zero_add]
        first | done | rfl
    · -- the hosted terms
      rw [algH_gh U _ dt 14 cu rt hist i (fun h => absurd h.1 (by decide)), hgh i t]
      fin_cases i
      · show _ = gV (valsN U c P D (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
            (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (c.sh.logs .D) (slotShape P 14).2.1
            (cpt (c.sh.logs .D) (slotShape P 14).2.1 t)) (some 63)
          * reqV8 (cstK U) (valsN U c P D (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
            (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (c.sh.logs .D) (slotShape P 14).2.1
            (cpt (c.sh.logs .D) (slotShape P 14).2.1 t)) c.p.ao 17 [20, 21, 22]
        rw [hv, (dzc_gh U G P D hX Pb Lay B hS hcfg t _ _ _).1]
        first | done | rfl
      · show _ = gV (valsN U c P D (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
            (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (c.sh.logs .D) (slotShape P 14).2.1
            (cpt (c.sh.logs .D) (slotShape P 14).2.1 t)) (some 63)
          * reqV8 (cstK U) (valsN U c P D (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak14 hk14
            (Sym.eval hist 14 r.draws) (pubs 14 hist r.draws) (c.sh.logs .D) (slotShape P 14).2.1
            (cpt (c.sh.logs .D) (slotShape P 14).2.1 t)) c.p.down 35 [38, 39, 40]
        rw [hv, (dzc_gh U G P D hX Pb Lay B hS hcfg t _ _ _).2]
        first | done | rfl
  · -- the hosted slots' sums
    have hM0 : algM (algShapeR c P hc) dt 14 cu rt 0 = fun b => (fun y : Fin (nD c) → Bool =>
        algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 0 (.d (splitD c y)))) (castB ((tau14 c).trans G.logD) b) := by
      rw [algM_mm _ dt 14 cu rt 0 (fun h => absurd h.1 (by decide))]
      exact funext (hmm 0)
    have hM1 : algM (algShapeR c P hc) dt 14 cu rt 1 = fun b => (fun y : Fin (nD c) → Bool =>
        algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 1 (.d (splitD c y)))) (castB ((tau14 c).trans G.logD) b) := by
      rw [algM_mm _ dt 14 cu rt 1 (fun h => absurd h.1 (by decide))]
      exact funext (hmm 1)
    have hP0 : algPt U (algShapeR c P hc) 14 hist 0 = fun t : Fin (tauLen c 14) => (r10.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 10 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 10 t r10 (by decide) hr10]
    have hP1 : algPt U (algShapeR c P hc) 14 hist 1 = fun t : Fin (tauLen c 14) => (r13.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 13 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 13 t r13 (by decide) hr13]
    rw [Fin.sum_univ_two, hM0, hM1, hP0, hP1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ ?_) (congrArg₂ (· * ·) ?_ ?_)
    · exact segAt_dz U P hc hcfg r.draws _ .nu 0 31 rfl (by omega)
    · exact mleAt_castB ((tau14 c).trans G.logD) (fun y : Fin (nD c) → Bool =>
        algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 0 (.d (splitD c y))))
        (fun t => (r10.draws.getD t Fp2.zero).toK U)
    · exact segAt_dz U P hc hcfg r.draws _ .nu 1 31 rfl (by omega)
    · exact mleAt_castB ((tau14 c).trans G.logD) (fun y : Fin (nD c) → Bool =>
        algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 14 1 (.d (splitD c y))))
        (fun t => (r13.draws.getD t Fp2.zero).toK U)

/-- **`SC_DZC`'s named identity at the R13 rung**: `formAt_dzcR` at `cfgRungR13` (`geoRung`, `dzcCfg_rung`), for a
verifier with the rung's draws (`shOk_rung`) and schedule (`profR_rung`). -/
theorem formAt_dzcR_rung (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.rungDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR DefR13.cfgRungR13 S) (hW : ZK60.Layout.R13.R13Windows S 2) (hLay : LayR Lay)
    (hpub : PubR U DefR13.cfgRungR13 pubs Pb Lay B)
    (dt : AlgData K L (algShapeR DefR13.cfgRungR13 P (shOk_rung P hdr))) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 14 cu rt bga κ b = if (κ : ℕ) < r13Count 14
        then algebraMap GF K (r13Cl Pb Lay B (xtR U DefR13.cfgRungR13 P D 2) 14 (clIx 14 κ) (encR geoRung 14 b))
        else xcDzcR U geoRung P D Pb Lay B bga κ b)
    (hpw : ∀ j b, dt.pw 14 cu rt j b = pwDzcR U geoRung P D Pb Lay B j b)
    (hgh : ∀ i b, dt.gh 14 cu rt i b
      = algebraMap GF K (r13Gh Pb Lay B (xtR U DefR13.cfgRungR13 P D 2) 14 i (encR geoRung 14 b)))
    (hmm : ∀ i b, dt.mm 14 cu rt i b
      = algebraMap GF K (r13Mm Pb Lay B (xtR U DefR13.cfgRungR13 P D 2) 14 i (encR geoRung 14 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR DefR13.cfgRungR13 P (shOk_rung P hdr)) dt hcard 0 cu rt k h).Φ) bga rs 14 :=
  formAt_dzcR U hU hcard Pb geoRung Lay B P (shOk_rung P hdr) (profR_rung P hdr hsl) dzcCfg_rung ioIn ioOut pubs hdef
    D hX hrl hS hW hLay hpub dt cu rt hcl hpw hgh hmm bga rs hslots

/-- **`SC_DZC`'s named identity at every layer of the app's Shieldstral T128 R13 block**: `formAt_dzcR` at
`cfgShieldR13 L` (`geoShield`, `dzcCfg_shield`), for a verifier with the block's draws (`shOk_shield`) and schedule
(`profR_shield`). -/
theorem formAt_dzcR_shield (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L' : ℕ}
    (L : ZK60.RunShape.Shield.ShieldLayer) (hL : L ∈ ZK60.RunShape.Shield.shieldExport)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR (DefR13.cfgShieldR13 L)) (CwR (DefR13.cfgShieldR13 L)) (CgR (DefR13.cfgShieldR13 L))
      (CjR (DefR13.cfgShieldR13 L)) (CdR (DefR13.cfgShieldR13 L)) (CfR (DefR13.cfgShieldR13 L)))
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws)
    (hsl : P.geom.slots = ZK60.Exec.Block.R13.shieldSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (DefR13.cfgShieldR13 L) S) (hW : ZK60.Layout.R13.R13Windows S 1) (hLay : LayR Lay)
    (hpub : PubR U (DefR13.cfgShieldR13 L) pubs Pb Lay B)
    (dt : AlgData K L' (algShapeR (DefR13.cfgShieldR13 L) P (shOk_shield L P hdr))) (cu : Cuts3 L') (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 14 cu rt bga κ b = if (κ : ℕ) < r13Count 14
        then algebraMap GF K (r13Cl Pb Lay B (xtR U (DefR13.cfgShieldR13 L) P D 1) 14 (clIx 14 κ)
          (encR (geoShield L) 14 b))
        else xcDzcR U (geoShield L) P D Pb Lay B bga κ b)
    (hpw : ∀ j b, dt.pw 14 cu rt j b = pwDzcR U (geoShield L) P D Pb Lay B j b)
    (hgh : ∀ i b, dt.gh 14 cu rt i b
      = algebraMap GF K (r13Gh Pb Lay B (xtR U (DefR13.cfgShieldR13 L) P D 1) 14 i (encR (geoShield L) 14 b)))
    (hmm : ∀ i b, dt.mm 14 cu rt i b
      = algebraMap GF K (r13Mm Pb Lay B (xtR U (DefR13.cfgShieldR13 L) P D 1) 14 i (encR (geoShield L) 14 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 (DefR13.cfgShieldR13 L) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR (DefR13.cfgShieldR13 L) P (shOk_shield L P hdr)) dt hcard 0 cu rt k h).Φ)
      bga rs 14 :=
  formAt_dzcR U hU hcard Pb (geoShield L) Lay B P (shOk_shield L P hdr) (profR_shield L P hdr hsl)
    (dzcCfg_shield L hL) ioIn ioOut pubs hdef D hX hrl hS hW hLay hpub dt cu rt hcl hpw hgh hmm bga rs hslots

end Form

end ZK60.Exec.Block.Join.R13H.Dzc
