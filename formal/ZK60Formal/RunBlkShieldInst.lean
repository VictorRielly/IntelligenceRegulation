/-
D63 lane L62 (2026-11-16): **concrete Shieldstral R13 instantiation of `RdBlkR13B` across all 26 layers of
`shieldExport` (`rdBlkR13B_shield`, `nonempty_rdBlkR13B_of_shieldBlkRunData`, `bw_productionReadyL_epP_shield_r13`)
+ discharge of `hoAK`, `hoHK`, `hoIK`, `hoOK` (Review R1 findings R1-1 and R1-3)**.

* `shield_draws_21`, `shield_draws_22`: `nD (cfgShieldR13 Ly) ≤ P.draws 21` and `≤ P.draws 22` by `decide`;
* `rdBlkR13B_shield`: constructs `RdBlkR13B` at `shieldShape Ly` (`ls = 1`, `shield_shapes_r13`, `algShapeR`, `dtR`,
  `xtR`, `encR`, `encHtR`, `hspecR`, `ioDefSchedB`, `AlkR13B`, `TR13`, `mlkR13B`, `hTtab_shield`, `hcov_shieldB`);
* `rdBlkR13B_cast`, `ShieldBlkRunData`, `nonempty_rdBlkR13B_of_shieldBlkRunData`: transports `RdBlkR13B` onto
  `Rp.blks[k].pub` on `shieldS0`;
* `shield_hoAK`, `shield_hoHK`, `shield_hoIK`, `shield_hoOK` (R1-3): derives all four opening column-log equalities
  from `hDe`, `hPk`, `hgX1`, `hgXk`, `hgXo`, and `(Pk k).endpointLogN = 14`;
* `bw_productionReadyL_epP_shield_r13`: `bw_productionReadyL_epP_shield` at `S := shieldS0` with `hblk` and
  `hoAK..hoOK` discharged.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBlkWireTop

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (BlockParams Cm ZClaim Cuts3 RootsO HdrX SlotRec Hist defSqB lkSqB w16r2DR w16r2RelKs algSp
  rootsAt cuts3 cutO absAt hdrX histOf tupK card_K_gt dXof rowLog)
open ZK60.Exec.Block.Join.W16 (aPl piB)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD offR xtR shShieldR geoShield LayR algShapeR shOk_shield
  dtR hspecR encR encHtR perRow_shield xcR pwcR ShieldBlkAt ShieldRunAt)
open ZK60.Exec.Block.Join.R13H.Look (dofARB AlkR13B mlkR13B hcov_shieldB TR13 hTtab_shield SgIx PrIx TbIx)
open ZK60.Layout (W16Layout W16Pub)
open ZK60.RunShape (ClassifyRunPublicP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldCal shieldS0 shieldShape shield_shapes_r13)

section ShieldRdBlk

theorem shield_draws_21 (Ly : ShieldLayer) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) :
    nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) ≤ P.draws 21 := by
  rw [hdr]
  show shShieldR.lt + shShieldR.ld ≤ ZK60.Exec.Block.R13.shieldDraws 21
  decide

theorem shield_draws_22 (Ly : ShieldLayer) (P : BlockParams)
    (hdr : P.draws = ZK60.Exec.Block.R13.shieldDraws) :
    nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) ≤ P.draws 22 := by
  rw [hdr]
  show shShieldR.lt + shShieldR.ld ≤ ZK60.Exec.Block.R13.shieldDraws 22
  decide

theorem shieldRun_logCols {S0 : BlockShape} {Pk : ℕ → BlockParams}
    {blks : List (ZK60.RunShape.RunBlock S0)} {Lb : ℕ}
    (hPk : ShieldRunAt Pk blks Lb) (k : ℕ) (hk : k < Lb) :
    (Pk k).logCols = 14 := by
  obtain ⟨_, _, _, _, _, _, _, hb⟩ := hPk k hk
  obtain ⟨_, _, _, _, _, _, _, _, hlc, _⟩ := hb
  exact hlc

/-- **Transport `RdBlkR13B` across equal `BlockShape`s and `HEq` public / boundary data.** -/
def rdBlkR13B_cast {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
    (U : K) (D : RtKData K Lq) (k : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K)
    {S1 S2 : BlockShape} (hS : S1 = S2)
    {Pb1 : BlockPublic S1} {Pb2 : BlockPublic S2} (hPb : HEq Pb1 Pb2)
    {Xin1 Xout1 : S1.Pos → GF} {Xin2 Xout2 : S2.Pos → GF}
    (hXin : HEq Xin1 Xin2) (hXout : HEq Xout1 Xout2)
    (bd : RdBlkR13B U D k lg τ absOf hcard Pb1 Xin1 Xout1) :
    RdBlkR13B U D k lg τ absOf hcard Pb2 Xin2 Xout2 := by
  subst hS
  cases hPb
  cases hXin
  cases hXout
  exact bd

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Concrete `RdBlkR13B` instance at any Shieldstral layer `Ly ∈ shieldExport`** (Review R1-1). -/
noncomputable def rdBlkR13B_shield {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport)
    (U : K) (D : RtKData K Lq) (k : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : IsShieldR13 P tag rowsOf)
    (hlc : P.logCols = 14) (hdrLen : ℕ)
    (rE QE : Cm → ℕ) (XE : Cuts3 Lq → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) (CtR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (shieldShape Ly) Pb Lay) (hLay : LayR Lay)
    (bIn bOut : HdrX Lq → (Fin (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) → K)
    (Xin Xout : (shieldShape Ly).Pos → GF)
    (hXin : ∀ p, Xin p = piB K (bIn (hdrX absOf lg hdrLen τ) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)))
    (hXout : ∀ p, Xout p = piB K (bOut (hdrX absOf lg hdrLen τ) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hdefR : ∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
      RdDefAt D (k + 1) τ bga rs
        (defSqB P hdrLen absOf
          (fun cu rt _ s' h =>
            (w16r2DR P (algSp U
              (algShapeR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
              (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
                (fun cu' rt' => xtR U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
                  (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') 1)
                (perRow_shield Ly)
                (xcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
                (pwcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B))
              hcard) i).Φ cu rt s' h)
          (fun _ => 80) s)
        P hdrLen s)
    (hdefIO : ∀ s ∈ [21, 22],
      RdDefAt D (k + 1) τ bga rs
        (defSqB P hdrLen absOf
          (ioDefSchedB P (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
            (shield_draws_21 Ly P hP.hdr) (shield_draws_22 Ly P hP.hdr)
            (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
              (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
            (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
              (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
            bIn bOut).Φ
          (fun _ => 1) s)
        P hdrLen s)
    (hlu : lkSqB hdrLen absOf
      (AlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly)
        (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE))
      (TR13 (K := K) Pb.exp Pb.act (shieldShape Ly).nG)
      (mlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
        (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE)) ∈ D.lu (k + 1))
    (hlen : hdrLen + 4 ≤ τ.length) :
    RdBlkR13B U D k lg τ absOf hcard Pb Xin Xout where
  Ct := CtR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  Cw := CwR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  Cg := CgR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  Cj := CjR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  Cd := CdR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  Cf := CfR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  ls := 1
  Lay := Lay
  B := B
  hWr := shield_shapes_r13 Ly hLy
  h24 := rfl
  P := P
  hdrLen := hdrLen
  sh := algShapeR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr)
  dt := dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
    (fun cu' rt' => xtR U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
      (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') 1)
    (perRow_shield Ly)
    (xcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
    (pwcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
  xtE := fun cu' rt' => xtR U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
    (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') 1
  enc := encR (geoShield Ly)
  encHt := encHtR (geoShield Ly)
  hspec := hspecR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
    (fun cu' rt' => xtR U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
      (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') 1)
    (perRow_shield Ly)
    (xcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
    (pwcR U (geoShield Ly) P (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
  hTok := hLay.tok
  hHd := hLay.hd
  bga := bga
  rs := rs
  hdefR := hdefR
  DIO := ioDefSchedB P (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
    (shield_draws_21 Ly P hP.hdr) (shield_draws_22 Ly P hP.hdr)
    (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
      (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
    (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
      (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
    bIn bOut
  hIOΦ := ioDefSchedB_hIOΦ P (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
    (shield_draws_21 Ly P hP.hdr) (shield_draws_22 Ly P hP.hdr)
    (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
      (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
    (fun cu' rt' b => aPl U P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
      (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
    bIn bOut
  hdefIO := hdefIO
  hIO := fun hgd =>
    ioDefSchedB_r13_hIO U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P 1
      (fun cu' rt' => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
      (shield_draws_21 Ly P hP.hdr) (shield_draws_22 Ly P hP.hdr)
      bIn bOut Lay
      (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf lg hdrLen τ)
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 21)) (histOf bga.1 bga.2.1 bga.2.2 (rs.take 22))
      Xin Xout hXin hXout
      (hgd 21 (by simp [ioDefSchedB])) (hgd 22 (by simp [ioDefSchedB]))
  ι := SgIx (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)
  π := PrIx (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 1
  κ := TbIx
  Alk := AlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly)
    (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE)
  T := TR13 (K := K) Pb.exp Pb.act (shieldShape Ly).nG
  mlk := mlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) P
    (dofARB tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE)
  hlu := hlu
  hlen := hlen
  hTtab := hTtab_shield Ly hLy Pb
  hcov := fun q hq =>
    hcov_shieldB Ly U tag hL20 P hlc rE QE XE Pb Lay B
      (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) q hq

/-- **Runtime transcript-reading bundle for block `k` of a `ShieldRunAt` classifier run** (`shieldS0` carrier). -/
structure ShieldBlkRunData {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    (Rp : ClassifyRunPublicP shieldS0) (Pk : ℕ → BlockParams)
    (U : K) (D : RtKData K Lq) (k : ℕ) (hk : k < Rp.blks.length)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8))
    (Xin Xout : shieldS0.Pos → GF) : Prop where
  exists_layer :
    ∃ (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (tag : MTag) (rowsOf : Cm → ℕ)
      (Lay : W16Layout (shieldShape Ly) (CtR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
        (CwR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) (CgR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
        (CjR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) (CdR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
        (CfR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)))
      (B : W16Pub (shieldShape Ly) Pb Lay)
      (hP : IsShieldR13 (Pk k) tag rowsOf)
      (hlc : (Pk k).logCols = 14)
      (hdrLen : ℕ) (rE QE : Cm → ℕ)
      (XE : Cuts3 Lq → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog (Pk k) cm + QE cm) → K)
      (bIn bOut : HdrX Lq → (Fin (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) → K)
      (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec),
      Ly ∈ shieldExport
        ∧ Rp.blks[k].cal = shieldCal Ly
        ∧ HEq Pb Rp.blks[k].pub
        ∧ LayR Lay
        ∧ (∀ p, Xin p = piB K (bIn (hdrX absOf lg hdrLen τ) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)))
        ∧ (∀ p, Xout p = piB K (bOut (hdrX absOf lg hdrLen τ) (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)))
        ∧ (∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
            RdDefAt D (k + 1) τ bga rs
              (defSqB (Pk k) hdrLen absOf
                (fun cu rt _ s' h =>
                  (w16r2DR (Pk k) (algSp U
                    (algShapeR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) (Pk k) (shOk_shield Ly (Pk k) hP.hdr))
                    (dtR (geoShield Ly) Pb Lay B (Pk k) (shOk_shield Ly (Pk k) hP.hdr)
                      (fun cu' rt' => xtR U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) (Pk k)
                        (dXof tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE cu' rt') 1)
                      (perRow_shield Ly)
                      (xcR U (geoShield Ly) (Pk k) (fun cu' rt' => dXof tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B)
                      (pwcR U (geoShield Ly) (Pk k) (fun cu' rt' => dXof tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE cu' rt') Pb Lay B))
                    (card_K_gt K)) i).Φ cu rt s' h)
                (fun _ => 80) s)
              (Pk k) hdrLen s)
        ∧ (∀ s ∈ [21, 22],
            RdDefAt D (k + 1) τ bga rs
              (defSqB (Pk k) hdrLen absOf
                (ioDefSchedB (Pk k) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly))
                  (shield_draws_21 Ly (Pk k) hP.hdr) (shield_draws_22 Ly (Pk k) hP.hdr)
                  (fun cu' rt' b => aPl U (Pk k) (dXof tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
                    (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 8) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
                  (fun cu' rt' b => aPl U (Pk k) (dXof tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE cu' rt')
                    (offR (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) 44) (nD (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly)) b)
                  bIn bOut).Φ
                (fun _ => 1) s)
              (Pk k) hdrLen s)
        ∧ lkSqB hdrLen absOf
            (AlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) (Pk k) Pb Lay B (geoShield Ly)
              (dofARB tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE))
            (TR13 (K := K) Pb.exp Pb.act (shieldShape Ly).nG)
            (mlkR13B U (ZK60.Exec.Block.DefR13.cfgShieldR13 Ly) (Pk k)
              (dofARB tag hL20 (Pk k) hlc 16 256 24448 4577 4390 rE QE XE)) ∈ D.lu (k + 1)
        ∧ hdrLen + 4 ≤ τ.length

/-- **`ShieldBlkRunData` produces `Nonempty (RdBlkR13B ... Rp.blks[k].pub Xin Xout)`.** -/
theorem nonempty_rdBlkR13B_of_shieldBlkRunData {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    (Rp : ClassifyRunPublicP shieldS0) (Pk : ℕ → BlockParams)
    (U : K) (D : RtKData K Lq) (k : ℕ) (hk : k < Rp.blks.length)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8))
    (Xin Xout : shieldS0.Pos → GF)
    (hsd : ShieldBlkRunData hL20 Rp Pk U D k hk lg τ absOf Xin Xout) :
    Nonempty (RdBlkR13B U D k lg τ absOf (card_K_gt K) Rp.blks[k].pub Xin Xout) := by
  obtain ⟨Ly, Pb, tag, rowsOf, Lay, B, hP, hlc, hdrLen, rE, QE, XE, bIn, bOut, bga, rs,
    hLy, hcal, hPb, hLay, hXin, hXout, hdefR, hdefIO, hlu, hlen⟩ := hsd.exists_layer
  have hS : shieldShape Ly = Rp.blks[k].cal.over shieldS0 := by
    unfold shieldShape
    rw [hcal]
  exact ⟨rdBlkR13B_cast U D k lg τ absOf (card_K_gt K) hS hPb HEq.rfl HEq.rfl
    (rdBlkR13B_shield hL20 Ly hLy U D k lg τ absOf (card_K_gt K) (Pk k) tag rowsOf hP hlc hdrLen rE QE XE
      Pb Lay B hLay bIn bOut Xin Xout hXin hXout bga rs hdefR hdefIO hlu hlen)⟩

/-! ## Discharging `hoAK`, `hoHK`, `hoIK`, `hoOK` from `hDe` + `hPk` + `hep14` (Review R1-3) -/

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_gX_succ {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ)
    (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) (i : ℕ) :
    (rxPs base Lb din dblk dout (i + 1)).gX = (base (i + 1)).gX := by
  dsimp only [rxPs]
  by_cases h : i < Lb
  · rw [ite_eq_left h]; rfl
  · rw [ite_eq_right h]; rfl

omit [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] in
theorem rxPs_succ_lt {Lq : ℕ} (base : ℕ → RkPart K Lq) (Lb : ℕ)
    (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) {k : ℕ} (hk : k < Lb) :
    rxPs base Lb din dblk dout (k + 1) = rxSet (base (k + 1)) (dblk k) := by
  dsimp only [rxPs]
  rw [ite_eq_left hk]

omit [Fintype K] [DecidableEq K] in
theorem shield_hoAK {S0 : BlockShape} {Lq : ℕ} {U : K} {tag : MTag} {h64 : 64 ≤ Lq}
    {key : Option Dig} {domain : List UInt8} {hs : decodeLink (startMsg domain) = none}
    {hL : (startMsg domain).length ≤ Lq} {rdx : List UInt8 → Option Dig}
    {pf : RtProf} {base : ℕ → RkPart K Lq} {Lb : ℕ} {din : RxMAH}
    {dblk : ℕ → RxMAH} {dout : RxMAH}
    {acc : ℕ → List (TItem × Dig) → ZK60.Exec.Block.Acc} {lsc : ℕ → ZK60.Exec.Block.ZClaim} {eL : ℕ}
    {D : RtKData K Lq}
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL)
    (hdA : ∀ k, k < Lb → (dblk k).gA.lc = 14)
    {Pk : ℕ → BlockParams} {blks : List (ZK60.RunShape.RunBlock S0)}
    (hPk : ShieldRunAt Pk blks Lb) :
    ∀ k, k < Lb → (D.opA (k + 1)).lc = rowLog (Pk k) .a := by
  intro k hk
  rw [hDe]
  show ((rxPs base Lb din dblk dout) (k + 1)).gA.lc = (Pk k).logCols
  rw [rxPs_succ_lt base Lb din dblk dout hk]
  show (dblk k).gA.lc = (Pk k).logCols
  rw [hdA k hk, shieldRun_logCols hPk k hk]

omit [Fintype K] [DecidableEq K] in
theorem shield_hoHK {S0 : BlockShape} {Lq : ℕ} {U : K} {tag : MTag} {h64 : 64 ≤ Lq}
    {key : Option Dig} {domain : List UInt8} {hs : decodeLink (startMsg domain) = none}
    {hL : (startMsg domain).length ≤ Lq} {rdx : List UInt8 → Option Dig}
    {pf : RtProf} {base : ℕ → RkPart K Lq} {Lb : ℕ} {din : RxMAH}
    {dblk : ℕ → RxMAH} {dout : RxMAH}
    {acc : ℕ → List (TItem × Dig) → ZK60.Exec.Block.Acc} {lsc : ℕ → ZK60.Exec.Block.ZClaim} {eL : ℕ}
    {D : RtKData K Lq}
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL)
    (hdH : ∀ k, k < Lb → (dblk k).gH.lc = 14)
    {Pk : ℕ → BlockParams} {blks : List (ZK60.RunShape.RunBlock S0)}
    (hPk : ShieldRunAt Pk blks Lb) :
    ∀ k, k < Lb → (D.opH (k + 1)).lc = rowLog (Pk k) .h := by
  intro k hk
  rw [hDe]
  show ((rxPs base Lb din dblk dout) (k + 1)).gH.lc = (Pk k).logCols
  rw [rxPs_succ_lt base Lb din dblk dout hk]
  show (dblk k).gH.lc = (Pk k).logCols
  rw [hdH k hk, shieldRun_logCols hPk k hk]

omit [Fintype K] [DecidableEq K] in
theorem shield_hoIK {Lq : ℕ} {U : K} {tag : MTag} {h64 : 64 ≤ Lq}
    {key : Option Dig} {domain : List UInt8} {hs : decodeLink (startMsg domain) = none}
    {hL : (startMsg domain).length ≤ Lq} {rdx : List UInt8 → Option Dig}
    {pf : RtProf} {base : ℕ → RkPart K Lq} {Lb : ℕ} {din : RxMAH} {dblk : ℕ → RxMAH} {dout : RxMAH}
    {acc : ℕ → List (TItem × Dig) → ZK60.Exec.Block.Acc} {lsc : ℕ → ZK60.Exec.Block.ZClaim} {eL : ℕ}
    {D : RtKData K Lq}
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL)
    (hgX1_lc : (base 1).gX.lc = 14)
    (hgXk_lc : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX.lc = 14)
    {Pk : ℕ → BlockParams} (hep14 : ∀ k, k < Lb → (Pk k).endpointLogN = 14) :
    ∀ k, k < Lb → (D.opX (k + 1)).lc = rowLog (Pk k) .inp := by
  intro k hk
  rw [hDe]
  show ((rxPs base Lb din dblk dout) (k + 1)).gX.lc = (Pk k).endpointLogN
  rw [rxPs_gX_succ]
  rcases k with _ | j
  · rw [hgX1_lc, hep14 0 hk]
  · rw [hgXk_lc j hk, hep14 (j + 1) hk]

omit [Fintype K] [DecidableEq K] in
theorem shield_hoOK {Lq : ℕ} {U : K} {tag : MTag} {h64 : 64 ≤ Lq}
    {key : Option Dig} {domain : List UInt8} {hs : decodeLink (startMsg domain) = none}
    {hL : (startMsg domain).length ≤ Lq} {rdx : List UInt8 → Option Dig}
    {pf : RtProf} {base : ℕ → RkPart K Lq} {Lb : ℕ} {din : RxMAH} {dblk : ℕ → RxMAH} {dout : RxMAH}
    {acc : ℕ → List (TItem × Dig) → ZK60.Exec.Block.Acc} {lsc : ℕ → ZK60.Exec.Block.ZClaim} {eL : ℕ}
    {D : RtKData K Lq}
    (hDe : D = ebData U tag Lq h64 key domain hs hL rdx pf (rxPs base Lb din dblk dout) acc lsc eL)
    (hgXk_lc : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX.lc = 14)
    (hgXo_lc : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX.lc = 14)
    {Pk : ℕ → BlockParams} (hep14 : ∀ k, k < Lb → (Pk k).endpointLogN = 14) :
    ∀ k, k < Lb → (D.opX (k + 1 + 1)).lc = rowLog (Pk k) .out := by
  intro k hk
  rw [hDe]
  show ((rxPs base Lb din dblk dout) (k + 1 + 1)).gX.lc = (Pk k).endpointLogN
  rw [rxPs_gX_succ]
  by_cases hk1 : k + 1 < Lb
  · rw [hgXk_lc k hk1, hep14 k hk]
  · have heq : k + 1 = Lb := by omega
    rw [hgXo_lc k heq, hep14 k hk]

end ShieldRdBlk

namespace RunShapeP

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code ZK60.RunShape
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)
open ZK60.D76 (classifyLeak LeaksAtMost productionReadyL_of_productionReady zeroKnowledgeL_target_of_cap_or
  semanticHidingL_of_zeroKnowledgeL)
open ZK60.ProtocolClassify (ClsHdrW clsHdrOf clsStart ShieldBlkRunData nonempty_rdBlkR13B_of_shieldBlkRunData
  shield_hoAK shield_hoHK shield_hoIK shield_hoOK)
open ZK60.RunShape.Shield (shieldS0)

section ShieldTopR13

variable {Hdr Coins : Type}
variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (Rr dR : ℕ) {pos : shieldS0.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (hplace : Function.Injective place) (tag : MTag)
local notation "CinS" =>
  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place (ZK60.ProtocolClassify.epxMsg Rr dR place pos)
    (ZK60.ProtocolClassify.epxMsg_place Rr dR place pos hplace) ZK60.ProtocolClassify.EpxSalt.pads
    ZK60.ProtocolClassify.EpxSalt.salts ZK60.ProtocolClassify.EpxSalt.paths ClsStmt.inRoot tag

/-- **THE SHIELDSTRAL T128 R13 CLASSIFIER TOP THEOREM WITH `RdBlkR13B` INSTANTIATED ACROSS ALL 26 LAYERS AND
`hoAK..hoOK` DISCHARGED** (D63 lane L62; Review R1-1 and R1-3). -/
theorem bw_productionReadyL_epP_shield_r13 (Rp : ClassifyRunPublicP shieldS0) (Lq : ℕ) (Lb : ℕ)
    (hL20 : 2 ^ 20 ≤ Lq)
    (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (Pk : ℕ → Exec.Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Exec.Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit) (digest : ClsStmt Hdr → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr →
      Except String Tr)
    (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (shieldS0.Tok → ℕ) Coins) (h64 : 64 ≤ Lq)
    (hr : 8 * (CinS).R ≤ Lq) (hon : HonestIn Coins (CinS)) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (Rn : RtRun (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : (RtRun.pf Rn).Valid)
    (hw : Hdr → ClsHdrW) (hRn : ∀ s, RtRun.hdr Rn s = clsHdrOf hw s) (D : RtKData K Lq)
    (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (RtRun.pf Rn))
    {ι : Type} [Fintype ι] (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (ZK60.ProtocolClassify.EpxSalt Rr))
    {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpenP Rp Lq (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) P (CinS) h64 hr hon U site kOf δOf εzk)
    (hU : U ^ 2 = algebraMap GF K 7)
    (cx0 : IncCtx) (pin pout : RtPart) (Iin : RtInc Lq inc incG pin) (Oout : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : RtRun.σs Rn = rtParts (classifyRunV Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (hIA : RkPcsAt U tag ogStage Iin.pA) (hIH : RkPcsAt U tag ogStage Iin.pH)
    (hOA : RkPcsAt U tag ogStage Oout.pA) (hOH : RkPcsAt U tag ogStage Oout.pH) (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : Iin.tag = tag) (htO : Oout.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * Iin.pA.rows ≤ Lq) (hfIH : 8 * Iin.pH.rows ≤ Lq) (hfOA : 8 * Oout.pA.rows ≤ Lq)
    (hfOH : 8 * Oout.pH.rows ≤ Lq) (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Vi : IncV) (F : ℕ → OutcV) (hinc : ∀ hd, inc hd = Vi) (houtc : ∀ hd v, outc hd v = F v)
    (hchk : ∀ s : ClsStmt Hdr, check s 0 = .ok () → s.verdict ≤ 1) (hLb1 : 0 < Lb)
    (lscIn lscOut : Exec.Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq) (eL : ℕ)
    (hDe : D = ebData U tag Lq h64 key domain hs hL abRdIn (RtRun.pf Rn)
      (rxPs base Lb (rxDinG ogStage (RtRun.pf Rn) pin.S kIn Iin.pA.rows Iin.pH.rows Iin.nA Iin.nH mIn)
        (fun k => rxDblk (RtRun.pf Rn) k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA
          (bp k).nH)
        (rxDoutG ogStage (RtRun.pf Rn) Lb pout.S kOut Oout.pA.rows Oout.pH.rows Oout.nA Oout.nH))
      (rxAcc (ZK60.ProtocolClassify.vdWin Vi) (ZK60.ProtocolClassify.vdWout F) Pk (RtRun.pf Rn) Lb) (rxLsc lscIn lscOut Pk Lb) eL)
    (pXk : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t))
    (hXk : ∀ k, ZK60.ProtocolClassify.RkPcsR13 U tag (pXk k))
    (hwXk : ∀ k, k + 1 < Lb → wXk (k + 1) = (bp k).nOut + (bp (k + 1)).nIn + (pXk (k + 1)).rows)
    (hmXk : ∀ k, k + 1 < Lb → mXk (k + 1) = (pXk (k + 1)).m) (hfitXk : ∀ k, 8 * (pXk k).rows ≤ Lq)
    (hgXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 (pXk (k + 1)).rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXk : ∀ k, k + 1 < Lb → (base (k + 1 + 1)).nX = (bp k).nOut + (bp (k + 1)).nIn)
    (hwX0 : wXk 0 = Iin.nOut + (bp 0).nIn + (pXk 0).rows) (hmX0 : mXk 0 = (pXk 0).m)
    (hgX1 : (base 1).gX = ZK60.ProtocolClassify.rkR13 (pXk 0).rows ((RtRun.pf Rn).off 0 + 2))
    (hnX1 : (base 1).nX = Iin.nOut + (bp 0).nIn)
    (hOX : ZK60.ProtocolClassify.RkPcsR13 U tag Oout.pX)
    (hwXo : ∀ k, k + 1 = Lb → pout.wX = (bp k).nOut + Oout.nIn + Oout.pX.rows) (hfitXo : 8 * Oout.pX.rows ≤ Lq)
    (hgXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).gX
      = ZK60.ProtocolClassify.rkR13 Oout.pX.rows ((RtRun.pf Rn).off (k + 1) + 2))
    (hnXo : ∀ k, k + 1 = Lb → (base (k + 1 + 1)).nX = (bp k).nOut + Oout.nIn)
    (hgX0 : (base 0).gX = rkAt ogEp Iin.pX.rows 1) (hnX0 : (base 0).nX = Iin.nIn)
    (hXep : RkPcsAt U tag ogEp Iin.pX) (hfitX : 8 * Iin.pX.rows ≤ Lq)
    (hRr : Iin.pX.rows = Rr)
    (hL81 : 81 ≤ Lq)
    (hPk : ZK60.Exec.Block.Join.R13H.ShieldRunAt Pk Rp.blks Lb)
    (hep14 : ∀ k, k < Lb → (Pk k).endpointLogN = 14)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Exec.Block.blockSchedXB (Pk k) ((RtRun.pf Rn).off (k + 1) + 5)
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ((ZK60.ProtocolClassify.bwFslRun U tag Lq h64 Lb Pk (fun k => (bp k).S) D (RtRun.pf Rn)
        (shield_hoAK hDe (fun _ _ => rfl) hPk)
        (shield_hoHK hDe (fun _ _ => rfl) hPk)
        (shield_hoIK hDe (by rw [hgX1]; rfl) (fun j hj => by rw [hgXk j hj]; rfl) hep14)
        (shield_hoOK hDe (fun j hj => by rw [hgXk j hj]; rfl) (fun j hj => by rw [hgXo j hj]; rfl) hep14)
        (ZK60.ProtocolClassify.shieldRunProg hPk) (ZK60.ProtocolClassify.shieldRunPubs hPk)) k))
    {ιL πL κL : ℕ → Type} [∀ k, Fintype (ιL k)] [∀ k, Fintype (πL k)] [∀ k, Fintype (κL k)]
    (AlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → ιL k ⊕ (πL k ⊕ πL k) → Tup K) (TL : (k : ℕ) → κL k → Tup K)
    (mlkL : (k : ℕ) → List (QB Lq × Dig) × Option (List UInt8) → κL k → K)
    (P0in P0out : Exec.Block.BlockParams)
    (csIOI csIOO : StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
    (hIOI : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOI v cm { z with value := a } = csIOI v cm z)
    (hIOO : ∀ v (cm : Exec.Block.Cm) (z : Exec.Block.ZClaim) (a : Fp2), csIOO v cm { z with value := a } = csIOO v cm z)
    (hNin : ∀ k, k < P0in.geom.slots.length → 0 < stgN P0in k ∧ stgN P0in k * (Exec.Block.slotShape P0in k).2.2 + 2 ≤ 512)
    (hNout : ∀ k, k < P0out.geom.slots.length → 0 < stgN P0out k ∧ stgN P0out k * (Exec.Block.slotShape P0out k).2.2 + 2 ≤ 512)
    (ΦI : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0in.draws k) → K) → K)
    (ΦO : StgVw Lq → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0out.draws k) → K) → K)
    (dgI dgO : ℕ → ℕ)
    (eI eO : ℕ)
    (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)
    (hb0 : StgLists (base 0) (stgSchedV P0in mIn ((RtRun.pf Rn).off 0 + 5) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstI U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI))
      (stgDefsV P0in mIn ((RtRun.pf Rn).off 0 + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦI dgI) (stgLkSqV mIn ((RtRun.pf Rn).off 0 + 5) eI (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI))
    (hbL : StgLists (base (Lb + 1)) (stgSchedV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO))
      (stgDefsV P0out 2 ((RtRun.pf Rn).off (Lb + 1) + 2) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦO dgO) (stgLkSqV 2 ((RtRun.pf Rn).off (Lb + 1) + 2) eO (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO))
    (hPin : ∀ hd cx, StgSame P0in ((inc hd).bp cx))
    (hPout : ∀ hd v, StgSame P0out (outc hd v).bp)
    (hTrI : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgTrueAt U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (fun v ch => ((ZK60.ProtocolClassify.vdWin Vi) (v.2.take ((RtRun.pf Rn).off 0 + pin.pre))).bp (ZK60.Exec.StageV.incCtx ((ZK60.ProtocolClassify.vdWin Vi) (v.2.take ((RtRun.pf Rn).off 0 + pin.pre))).pub ch)) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows ((RtRun.pf Rn).off 0 + 5) ((RtRun.pf Rn).off 0 + 5 + 4 + mIn) csIOI) (ZK60.ProtocolClassify.stgMsv U tag h64 pin.S ((RtRun.pf Rn).off 0 + 5 + 3)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hTrO : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ZK60.ProtocolClassify.StgTrueAt U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (fun v _ => ((ZK60.ProtocolClassify.vdWout F) (v.2.take ((RtRun.pf Rn).off (Lb + 1) + pout.pre))).bp) (ZK60.ProtocolClassify.stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows ((RtRun.pf Rn).off (Lb + 1) + 2) ((RtRun.pf Rn).off (Lb + 1) + 2 + 4 + 2) csIOO) (ZK60.ProtocolClassify.stgMsv U tag h64 pout.S ((RtRun.pf Rn).off (Lb + 1) + 2 + 3)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hR0_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.r0 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hDI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgDefAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hDO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgDefAtV U key domain P0out (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΦO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hR1_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.r1 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hH0_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.h0 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hH1_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.h1 (k + 1), RaDefAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hLU_blk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ∀ k, k < Lb → ∀ sx ∈ D.lu (k + 1), RaLkAtB U key domain (Pk k) ((RtRun.pf Rn).off (k + 1) + 5) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (AlkL k) (TL k) (mlkL k) G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) sx)
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (rtKB key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKM key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKA key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKsl key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKR1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH0 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      ¬ (rtKH1 key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD).Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)) →
      StgLkAtV U key domain (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ InOkP Rp ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0in (fun ch => (inc (A.run G).1.hdr).bp (ZK60.Exec.StageV.incCtx (inc (A.run G).1.hdr).pub ch)) mIn ((RtRun.pf Rn).off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) ZK60.ProtocolClassify.stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstI U hbij tag h64 P0in (ZK60.ProtocolClassify.vdWin Vi) ((RtRun.pf Rn).off 0 + pin.pre) ((RtRun.pf Rn).off 0 + 5) mIn ogStage.lc ogStage.h ogStage.Q ogStage.e Iin.pA.rows Iin.pH.rows pin.S csIOI) ΦI dgI eI ΛI G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hblkS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ShieldBlkRunData hL20 Rp Pk U D k hk (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G))
        (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
        (((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        (((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ OutOkP Rp ((classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).ypub (A.runLog G).1.1)
        ((ZK60.ProtocolClassify.epxE (CinS) (ZK60.ProtocolClassify.epxMk Rr dR place hpos hplace ClsStmt.inRoot tag) pos (ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) E0) (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ZK60.ProtocolClassify.StgDoomAtV U key domain P0out (fun _ => (outc (A.run G).1.hdr (A.run G).1.verdict).bp) 2 ((RtRun.pf Rn).off (Lb + 1) + 2) OutcV.bga (ZK60.ProtocolClassify.stgHostOut P0out) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (ZK60.ProtocolClassify.stgFstO U hbij tag h64 P0out (ZK60.ProtocolClassify.vdWout F) ((RtRun.pf Rn).off (Lb + 1) + pout.pre) ((RtRun.pf Rn).off (Lb + 1) + 2) ogStage.lc ogStage.h ogStage.Q ogStage.e Oout.pA.rows Oout.pH.rows pout.S csIOO) ΦO dgO eO ΛO G (A.runLog G).2
        (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
        (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G ∨ ZK60.ProtocolClassify.exEvIn tag Lq h64 key domain hs hL incG outcG sgeom Lb A G) →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → ((CinS).decodeIn ((ZK60.ProtocolClassify.epxOps tag Lq h64 key domain hs hL abRdIn 11 Rr (N := 2 ^ 11)) (A.runLog G).2 (A.runLog G).1.1) 768).1 ((CinS).place k) i = 0)
        → ∃ K' ∈ rtKo key domain hs Lq hL (RtRun.pf Rn) (RtRun.rd Rn) hL64 hv U hbij D hD,
          K'.Dm (Rp.blks.length + 2) (A.runLog G).2 (rtTr key domain Lq (RtRun.pf Rn) (RtRun.rd Rn) G (A.run G)))
    (hzk : ∀ q R', q ≤ 2 ^ 64 → R' ≤ 2 ^ 64 → εzk q R' ≤ εzkTarget q R') :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) (classifyProtocolUExecP Rp Lq Lb preA preB start inc incG (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG P (CinS) h64 hr hon.base 768)
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget :=
  bw_productionReadyL_epP_shield (Rr := Rr) (dR := dR) (hpos := hpos) (place := place) (hplace := hplace)
    (tag := tag) (Rp := Rp) (Lq := Lq) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc)
    (incG := incG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest) (bRows := bRows)
    (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (outc := outc) (outcG := outcG) (P := P) (h64 := h64)
    (hr := hr) (hon := hon) (U := U) (hbij := hbij) (key := key) (domain := domain) (hs := hs) (hL := hL)
    (hL64 := hL64) (Rn := Rn) (hv := hv) (hw := hw) (hRn := hRn) (D := D) (hD := hD) (site := site) (kOf := kOf)
    (δOf := δOf) (E0 := E0) (O := O) (hU := hU) (cx0 := cx0) (pin := pin) (pout := pout) (Iin := Iin) (Oout := Oout)
    (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hgeo := hgeo) (hIA := hIA) (hIH := hIH)
    (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH) (htI := htI) (htO := htO) (htB := htB) (hfIA := hfIA)
    (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (hfIM := hfIM) (hfOM := hfOM)
    (hfBM := hfBM) (Vi := Vi) (F := F) (hinc := hinc) (houtc := houtc) (hchk := hchk) (hLb1 := hLb1) (lscIn := lscIn)
    (lscOut := lscOut) (mIn := mIn) (kIn := kIn) (kOut := kOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn)
    (hkIn := hkIn) (hkOut := hkOut) (base := base) (eL := eL) (hDe := hDe) (pXk := pXk) (hXk := hXk) (hwXk := hwXk)
    (hmXk := hmXk) (hfitXk := hfitXk) (hgXk := hgXk) (hnXk := hnXk) (hwX0 := hwX0) (hmX0 := hmX0) (hgX1 := hgX1)
    (hnX1 := hnX1) (hOX := hOX) (hwXo := hwXo) (hfitXo := hfitXo) (hgXo := hgXo) (hnXo := hnXo) (hgX0 := hgX0)
    (hnX0 := hnX0) (hXep := hXep) (hfitX := hfitX) (hRr := hRr) (hL81 := hL81) (hPk := hPk)
    (hoAK := shield_hoAK hDe (fun _ _ => rfl) hPk)
    (hoHK := shield_hoHK hDe (fun _ _ => rfl) hPk)
    (hoIK := shield_hoIK hDe (by rw [hgX1]; rfl) (fun j hj => by rw [hgXk j hj]; rfl) hep14)
    (hoOK := shield_hoOK hDe (fun j hj => by rw [hgXk j hj]; rfl) (fun j hj => by rw [hgXo j hj]; rfl) hep14)
    (hslB := hslB) (AlkL := AlkL) (TL := TL)
    (mlkL := mlkL) (P0in := P0in) (P0out := P0out) (csIOI := csIOI) (csIOO := csIOO) (hIOI := hIOI) (hIOO := hIOO)
    (hNin := hNin) (hNout := hNout) (ΦI := ΦI) (ΦO := ΦO) (dgI := dgI) (dgO := dgO) (eI := eI) (eO := eO)
    (ΛI := ΛI) (ΛO := ΛO) (hb0 := hb0) (hbL := hbL) (hPin := hPin) (hPout := hPout) (hTrI := hTrI) (hTrO := hTrO)
    (hR0_blk := hR0_blk) (hDI_stg := hDI_stg) (hDO_stg := hDO_stg) (hR1_blk := hR1_blk) (hH0_blk := hH0_blk)
    (hH1_blk := hH1_blk) (hLU_blk := hLU_blk) (hLI_stg := hLI_stg) (hLO_stg := hLO_stg) (hdinS := hdinS)
    (hblk := fun A G k hk hv' hno => nonempty_rdBlkR13B_of_shieldBlkRunData hL20 Rp Pk U D k hk _ _ _ _ _ (hblkS A G k hk hv' hno))
    (hdoutS := hdoutS) (hdzero := hdzero) (hzk := hzk)

end ShieldTopR13

end RunShapeP

end ZK60.ProtocolClassify
