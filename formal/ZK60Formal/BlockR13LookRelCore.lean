/-
D63 lane L49 (2026-11-10), sub-agent `look`, round 2, part 3: **`HelperRel` at R13 from the relations domain by
domain, the sum claim and `H_U`'s sum** (the R13 counterpart of lane L47's `hhr_core`), generic in the configuration.

* **`RelsR`**: the helper relations at R13, domain by domain: every pair helper of every lookup domain (`L`, `D`, `Q`,
  `Kv`, `S`, `F`), every single helper (`Dom::S`'s last lookup, the exp tuple, the ACT tuple), every table helper, on
  the committed `H` planes the code reads (`hOff c (first + j)`);
* **`hhr_of_relsR`**: `RelsR`, the code's sum claim and `H_U`'s zero sum give `∃ Hh, HelperRel …` for lane L36's
  `Alk := AlkR13`, `T := TR13`, `mlk := mlkR13`;
* **`pr_L`**: `Dom::L`'s pair from `SC_LZC`'s relation (`Help.cLzcR`), at `Dom::L`'s cube (one row).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookRelBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.LookRel

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.Join.W16 (aPl piB hPl)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (Dom)
open ZK60.Layout
open ZK60.Circuit (gP GF)

section Core

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The helper relations at R13, domain by domain**, on the committed data `D` at `bga = (β, γ, α)`. -/
structure RelsR {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c))
    (B : W16Pub S Pb Lay) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) : Prop where
  pr : ∀ (d : Dm) (j : ℕ), j < d.np ls → ∀ b : Fin (d.log c) → Bool,
    W16.Look.PairR U bga (hPl U P D (DefR13.hOff c (d.fh ls + j)).1 (DefR13.hOff c (d.fh ls + j)).2 (d.log c) b)
      (lkAtR U c P D d (2 * j) b) (lkAtR U c P D d (2 * j + 1) b)
  sg : ∀ (s : Sg) (b : Fin (s.log c) → Bool),
    W16.Look.SingleR U bga (hPl U P D (DefR13.hOff c (s.hp ls)).1 (DefR13.hOff c (s.hp ls)).2 (s.log c) b)
      (sgTupR U c P D Pb Lay B G s b)
  tb : ∀ (k : Fin 3) (b : Fin 14 → Bool),
    R13T.helpTabR U c P D k b * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TR13 exp act nG (k, b)))
      = R13T.multTabR U c P D k b

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`HelperRel` at R13 from the relations, the code's sum claim and `H_U`'s sum**, on any committed data (lane
L47's `hhr_core`). -/
theorem hhr_of_relsR {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (hc : LookCfg c ls) (P : BlockParams) (D : CmData K P)
    (hln : rowLog P .h = 14) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (exp : ℤ → ℤ)
    (act : ℕ → ℤ → ℤ) (nG : ℕ) (bga : Fp2 × Fp2 × Fp2) (hR : RelsR U G P D Pb Lay B exp act nG bga)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumR13 c) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D (DefR13.hOff c (DefR13.fh c 10)).1 (DefR13.hOff c (DefR13.fh c 10)).2 14 b
      = 0)
    (Alk : SgIx c ⊕ (PrIx c ls ⊕ PrIx c ls) → Tup K)
    (hA : ∀ l, Alk l = AlkR13 (L := 0) U c P Pb Lay B G (fun _ => D) [] l)
    (m : TbIx → K) (hm : ∀ j, m j = mlkR13 (L := 0) U c P (fun _ => D) [] j) :
    ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (Alk l))
      (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TR13 exp act nG j)) m (bga.2.2.toK U) Hh := by
  refine ⟨⟨fun i => hPl U P D (DefR13.hOff c (i.1.hp ls)).1 (DefR13.hOff c (i.1.hp ls)).2 (i.1.log c) i.2,
      fun k => hPl U P D (DefR13.hOff c (k.1.fh ls + k.2.1)).1 (DefR13.hOff c (k.1.fh ls + k.2.1)).2 (k.1.log c) k.2.2,
      fun j => R13T.helpTabR U c P D j.1 j.2⟩, ?_, ?_, ?_, ?_⟩
  · rintro ⟨s, b⟩
    show _ * (_ - ZK60.Sound.fold _ _ (Alk (.inl ⟨s, b⟩))) = 1
    rw [hA]
    exact hR.sg s b
  · rintro ⟨d, j, b⟩
    unfold pairFst pairSnd
    show _ * ((_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
      * (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩)))))
      = (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
        + (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩))))
    rw [hA, hA]
    exact hR.pr d j j.isLt b
  · rintro ⟨k, b⟩
    rw [hm]
    exact hR.tb k b
  · exact hhr_sumR U hU hc P D hln hcl hzs

end Core

/-! ## `Dom::L`'s pair from `SC_LZC` -/

section L

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (P : BlockParams) (D : CmData K P)

theorem lkAtR_L (hc : LookCfg c ls) (i : ℕ) (b : Fin (Dm.log c .L) → Bool) :
    lkAtR U c P D .L i b = W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) (Dm.log c .L) b)
      (lkLe.getD i ⟨[], 0, 0⟩) := by
  unfold lkAtR
  rw [lkL' hc]
  rfl

/-- **`Dom::L`'s pair** (its one helper, plane `0`) from `SC_LZC`'s relation, at every point of `Dom::L`'s cube. -/
theorem pr_L (hc : LookCfg c ls) (gL : (Fin 14 → Bool) → GF) (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)
    (hLz : ∀ b, Help.cLzcR U c P D gL bga b = 0) (j : ℕ) (hj : j < Dm.np ls .L) (b : Fin (Dm.log c .L) → Bool) :
    W16.Look.PairR U bga
      (hPl U P D (DefR13.hOff c (Dm.fh ls .L + j)).1 (DefR13.hOff c (Dm.fh ls .L + j)).2 (Dm.log c .L) b)
      (lkAtR U c P D .L (2 * j) b) (lkAtR U c P D .L (2 * j + 1) b) := by
  obtain rfl : j = 0 := by
    change j < 1 at hj
    omega
  have h := relL_pairR U c P D bga hα gL (castB hc.logL b) (hLz _)
  have e1 : hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 (Dm.log c .L) b
      = hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 14 (castB hc.logL b) :=
    (hPl_castB U P D _ _ hc.logL b).symm
  have e2 : (fun q => aPl U P D (DefR13.aOff c q) (Dm.log c .L) b)
      = (fun q => aPl U P D (DefR13.aOff c q) 14 (castB hc.logL b)) :=
    funext fun q => (aPl_castB' U P D _ hc.logL b).symm
  rw [lkAtR_L U P D hc, lkAtR_L U P D hc]
  show W16.Look.PairR U bga (hPl U P D (DefR13.hOff c 0).1 (DefR13.hOff c 0).2 (Dm.log c .L) b)
    (W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) (Dm.log c .L) b) (bLk 6))
    (W16.Look.lkTupP (fun q => aPl U P D (DefR13.aOff c q) (Dm.log c .L) b) (bLk 7))
  rw [e1, e2]
  exact h

end L

end ZK60.Exec.Block.Join.R13H.LookRel
