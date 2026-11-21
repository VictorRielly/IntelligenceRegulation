/-
D63 lane L68a (2026-11-17): **concrete Shieldstral extension field (`shdP_K`, `shdP_U`, `shdP_hU`, `shdP_hbij`),
bit-cube block layout (`shdP_bitLay`, `shdP_bitLay_layR`, `shdP_bitLay_dPos`), public block table embedding
(`shdP_w16Pub`), Lean-defined 26-layer R13 block verifier family (`shdP_blkParams`, `shdP_Pk0`,
`shdP_Pk0_eq_blkParams`, `shdP_clampPk_Pk0`, `shdP_shieldRunAtD`), numeric zero-knowledge error bound (`shdP_hzk`),
and joined top theorem `sshC_productionReadyL_epP_blkLu` on `sshC_productionReadyL_epP_shieldLu`**.

What `sshC_productionReadyL_epP_blkLu` supplies on top of `sshC_productionReadyL_epP_shieldLu`:
- extension field & bijection (`K := shdP_K`, `U := shdP_U`, `hbij := shdP_hbij`, `hU := shdP_hU`);
- boundary-plane coordinate map (`dPos0 := shieldDPos0`, with `(shdP_bitLay Ly).dPos = shieldDPos0 := rfl` by
  definition of `shdP_bitLay`, which embeds `Tok/Wid/Grp/Hid` via MSB-first `Exec.msbBits` and fixes `hdEmb` as flip
  bit + 6 MSB bits and `slotEmb` as 3 + 2 MSB bits);
- `hPk0 : ShieldRunAtD` replaced by `hR : ShieldRun Rp` and by defining the block verifier `Pk0 := shdP_Pk0 ...`
  (`shdP_shieldRunAtD`): the theorem now holds for this Lean-defined verifier family (`shdP_blkParams`, fixing
  `aRows`, `hRows`, `aPath`, `hPath`, `maskPath`, `preChecks`, and one uniform triple `(ioIn, ioOut, checkOpening)`
  for all 26 blocks, with `min k 25` inside `shdP_Pk0`); that the registered Rust verifier equals this definition is
  the model-to-code correspondence outside Lean;
- clamp removal on `O` and the conclusion: `shdP_clampPk` is removed from `O : ClassifyOpenP` and from the
  `ProductionReadyL` conclusion via `shdP_clampPk_Pk0` (the four stage premises still mention `shdP_clampPk`);
- profile domain (`domain := shdP_runDomain`, `hs`, `hL`);
- stage IO pin equalities and empty output-endpoint matrix (`csIOI`, `hcsI := rfl`, `rE := 0`, `lcE := 0`, `Qe := 0`,
  `XE := 0`, `csIOO`, `hcsO := rfl`, `hXEl`);
- vocabulary bound (`hV := O.inPub.V2`, read from `O`);
- numeric zero-knowledge error bound (`εzk := refErr RunK.kinds`, `hzk := shdP_hzk`; the zero-knowledge simulator
  property itself remains open as `O.zk`).

Remaining open arguments/premises of `sshC_productionReadyL_epP_blkLu` (34 explicit binders + implicit `Hdr, Coins, ι`
and 4 instances): (1) the 4 stage premises `hLI_stg`, `hLO_stg`, `hdinS`, `hdoutS`; (2) `tag`, `Lq`, `hL20`, `hL64`,
`key`, `Rp`, `hR : ShieldRun Rp`, `hw`, `hhdrFit`, universally quantified verifier hooks `preA preB check0 paths
digest bndCheck`, `ioIn ioOut checkOpening`, run data `embDigest embFold bInRow wDigest bOutRow`, and prover data
`P epBase`; and (3) `site`, `kOf`, `δOf`, `O : ClassifyOpenP` (including `O.parts`, `O.refuse`, and `O.zk`), and `E0`.

Only at most `propext`, `Classical.choice`, `Quot.sound` (23 public, 32 private declarations).
-/
import ZK60Formal.RunStgShieldTopSJ
import ZK60Formal.ZKHonestCount

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Layout ZK60.TokenRun ZK60.Assembly ZK60.StageX ZK60.RunShape
open Code
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF maskF ropeSgn)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (BlockParams Cm SlotKind defineS)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR LayR)
open ZK60.Exec.Block.Join.R13H.Look (logupSumR13)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13L)
open ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldGrp shieldCal shieldS0 shieldShape
  zeroPub ShieldRun)

/-! ## 1. Concrete quadratic extension field `shdP_K = GF[u]/(u² - 7)` and ZK budget cap `shdP_hzk` -/

section ConcreteFieldAndZk

open Polynomial in
private theorem shdP_X2_sub_7_irred : Irreducible (Polynomial.X ^ 2 - Polynomial.C (7 : GF)) :=
  X_pow_sub_C_irreducible_of_prime Nat.prime_two
    (fun b hb => Exec.seven_not_square b (by rw [← hb]; ring))

instance shdP_X2_sub_7_fact : Fact (Irreducible (Polynomial.X ^ 2 - Polynomial.C (7 : GF))) :=
  ⟨shdP_X2_sub_7_irred⟩

/-- Concrete quadratic extension field `GF[u]/(u² - 7)` for the Shieldstral top theorem. -/
abbrev shdP_K : Type := AdjoinRoot (Polynomial.X ^ 2 - Polynomial.C (7 : GF))

/-- Distinguished root `U` satisfying `U² = 7` in `shdP_K`. -/
noncomputable def shdP_U : shdP_K := AdjoinRoot.root (Polynomial.X ^ 2 - Polynomial.C (7 : GF))

theorem shdP_hU : shdP_U ^ 2 = algebraMap GF shdP_K 7 :=
  (ZK60.Hiding.adjoinRoot_finrank Exec.seven_not_square).2

theorem shdP_hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) shdP_U) :=
  shdP_fp2_bijective shdP_U (ZK60.Hiding.adjoinRoot_finrank Exec.seven_not_square).1 shdP_hU

noncomputable instance shdP_K_decidableEq : DecidableEq shdP_K :=
  Equiv.decidableEq (Equiv.ofBijective _ shdP_hbij).symm

noncomputable instance shdP_K_fintype : Fintype shdP_K :=
  Fintype.ofEquiv (GF × GF) (Equiv.ofBijective _ shdP_hbij)

/-- Numeric error bound `refErr RunK.kinds q R' ≤ εzkTarget q R'` for `R' ≤ 2^64` (via `runK_ref_cap_110`);
the zero-knowledge simulator property itself remains open as `O.zk`. -/
theorem shdP_hzk (q R' : ℕ) (_hq : q ≤ 2 ^ 64) (hR' : R' ≤ 2 ^ 64) :
    ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds q R' ≤ εzkTarget q R' :=
  ZK60.ZKHonest.runK_ref_cap_110 q R' (hR'.trans (by norm_num))

end ConcreteFieldAndZk

/-! ## 2. Concrete bit-cube `W16Layout` (`shdP_bitLay`), `LayR`, and `dPos = shieldDPos0` -/

section BitLayout

private def axMsb {N n : ℕ} (h : N ≤ 2 ^ n) : Ax (Fin N) (Fin n → Bool) where
  emb x := Exec.msbBits n x.val
  inj x y hxy := by
    have hx := Exec.msbIndex_msbBits n x.val (lt_of_lt_of_le x.isLt h)
    have hy := Exec.msbIndex_msbBits n y.val (lt_of_lt_of_le y.isLt h)
    exact Fin.ext (hx.symm.trans ((congrArg (Exec.msbIndex n) hxy).trans hy))

private def tokInv (c : Fin 7 → Bool) : Fin 128 :=
  ⟨Exec.msbIndex 7 c, Exec.msbIndex_lt 7 c⟩

private theorem tokInv_msbBits (t : Fin 128) : tokInv (Exec.msbBits 7 t.val) = t :=
  Fin.ext (Exec.msbIndex_msbBits 7 t.val t.isLt)

private theorem msbBits_tokInv (c : Fin 7 → Bool) : Exec.msbBits 7 (tokInv c).val = c :=
  Exec.msbBits_msbIndex 7 c

private def grpInv (c : Fin 3 → Bool) : Fin 8 :=
  ⟨Exec.msbIndex 3 c, Exec.msbIndex_lt 3 c⟩

private theorem grpInv_msbBits (g : Fin 8) : grpInv (Exec.msbBits 3 g.val) = g :=
  Fin.ext (Exec.msbIndex_msbBits 3 g.val g.isLt)

private theorem msbBits_grpInv (c : Fin 3 → Bool) : Exec.msbBits 3 (grpInv c).val = c :=
  Exec.msbBits_msbIndex 3 c

private def hdZero : Fin 7 := ⟨0, by norm_num⟩

private def hdEmb (x : Bool × Fin 64) (i : Fin 7) : Bool :=
  if i.val = 0 then x.1 else Exec.msbBits 6 x.2.val ⟨i.val - 1, by omega⟩

private def hdInv (d : Fin 7 → Bool) : Bool × Fin 64 :=
  (d hdZero, ⟨Exec.msbIndex 6 (fun j : Fin 6 => d ⟨j.val + 1, by omega⟩), Exec.msbIndex_lt 6 _⟩)

private def hdFlip (d : Fin 7 → Bool) : Fin 7 → Bool :=
  Function.update d hdZero (!d hdZero)

private theorem hdInv_hdEmb (x : Bool × Fin 64) : hdInv (hdEmb x) = x := by
  rcases x with ⟨b, k⟩
  have htail : (fun j : Fin 6 => hdEmb (b, k) ⟨j.val + 1, by omega⟩) = Exec.msbBits 6 k.val := by
    funext j
    simp [hdEmb]
  refine Prod.ext (by simp [hdInv, hdEmb, hdZero]) (Fin.ext ?_)
  dsimp only [hdInv]
  rw [htail]
  exact Exec.msbIndex_msbBits 6 k.val k.isLt

private theorem hdEmb_hdInv (d : Fin 7 → Bool) : hdEmb (hdInv d) = d := by
  funext i
  unfold hdEmb hdInv
  by_cases hi : i.val = 0
  · have hi0 : i = hdZero := Fin.ext hi
    subst hi0
    rfl
  · simp only [hi, ↓reduceIte]
    have hb := congrFun (Exec.msbBits_msbIndex 6 (fun j : Fin 6 => d ⟨j.val + 1, by omega⟩)) ⟨i.val - 1, by omega⟩
    dsimp only at hb
    rw [hb]
    congr 1
    exact Fin.ext (by dsimp only; omega)

private theorem hdFlip_hdEmb (b : Bool) (k : Fin 64) :
    hdEmb (!b, k) = hdFlip (hdEmb (b, k)) := by
  funext i
  unfold hdFlip
  by_cases hi : i.val = 0
  · have hi0 : i = hdZero := Fin.ext hi
    subst hi0
    simp [hdEmb, hdZero]
  · have hne : i ≠ hdZero := fun h => hi (congrArg Fin.val h)
    simp [hdEmb, hi, Function.update_of_ne hne]

private def slotEmb (h : Fin 32) : (Fin 3 → Bool) × (Fin 2 → Bool) :=
  (Exec.msbBits 3 (h.val / 4), Exec.msbBits 2 (h.val % 4))

private def slotInv (s : (Fin 3 → Bool) × (Fin 2 → Bool)) : Fin 32 :=
  ⟨4 * Exec.msbIndex 3 s.1 + Exec.msbIndex 2 s.2, by
    have h1 := Exec.msbIndex_lt 3 s.1
    have h2 := Exec.msbIndex_lt 2 s.2
    omega⟩

private theorem slotInv_slotEmb (h : Fin 32) : slotInv (slotEmb h) = h := by
  unfold slotInv slotEmb
  have h1 : Exec.msbIndex 3 (Exec.msbBits 3 (h.val / 4)) = h.val / 4 :=
    Exec.msbIndex_msbBits 3 (h.val / 4) (by omega)
  have h2 : Exec.msbIndex 2 (Exec.msbBits 2 (h.val % 4)) = h.val % 4 :=
    Exec.msbIndex_msbBits 2 (h.val % 4) (by omega)
  apply Fin.ext
  dsimp only
  rw [h1, h2, Nat.div_add_mod]

private theorem slotEmb_slotInv (s : (Fin 3 → Bool) × (Fin 2 → Bool)) : slotEmb (slotInv s) = s := by
  rcases s with ⟨s1, s2⟩
  unfold slotEmb slotInv
  dsimp only
  have hlt2 : Exec.msbIndex 2 s2 < 4 := Exec.msbIndex_lt 2 s2
  have hdiv : (4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) / 4 = Exec.msbIndex 3 s1 := by omega
  have hmod : (4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) % 4 = Exec.msbIndex 2 s2 := by omega
  rw [hdiv, hmod, Exec.msbBits_msbIndex 3 s1, Exec.msbBits_msbIndex 2 s2]

/-- Concrete bit-cube `W16Layout` for any Shieldstral layer `Ly`. -/
def shdP_bitLay (Ly : ShieldLayer) :
    W16Layout (shieldShape Ly)
      (CtR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) where
  tok := axMsb (N := (shieldShape Ly).T) (n := 7) (by show 128 ≤ 2 ^ 7; norm_num)
  wid := axMsb (N := (shieldShape Ly).d) (n := 12) (by show 3072 ≤ 2 ^ 12; norm_num)
  grp := axMsb (N := (shieldShape Ly).G) (n := 3) (by show 8 ≤ 2 ^ 3; norm_num)
  within h := Exec.msbBits 2 (h.val % 4)
  hd := ⟨hdEmb, Function.LeftInverse.injective hdInv_hdEmb⟩
  hid := axMsb (N := (shieldShape Ly).f) (n := 14) (by show 9216 ≤ 2 ^ 14; norm_num)
  slot_inj := Function.LeftInverse.injective slotInv_slotEmb
  flip := hdFlip
  hd_flip := hdFlip_hdEmb

theorem shdP_bitLay_layR (Ly : ShieldLayer) : LayR (shdP_bitLay Ly) where
  tok := Function.RightInverse.surjective msbBits_tokInv
  hd := Function.RightInverse.surjective hdEmb_hdInv
  slot := Function.RightInverse.surjective slotEmb_slotInv
  grp := Function.RightInverse.surjective msbBits_grpInv
  flip _ _ := rfl

theorem shdP_bitLay_dPos (Ly : ShieldLayer) : (shdP_bitLay Ly).dPos = shieldDPos0 := rfl

/-! ## 3. Concrete `W16Pub` (`shdP_w16Pub`) for any `Pb : BlockPublic (shieldShape Ly)` -/

private theorem wid_msbBits_lt {Ly : ShieldLayer} (i : (shieldShape Ly).Wid) : i.val < 2 ^ 12 := by
  have hi : i.val < 3072 := i.isLt; omega

private theorem hid_msbBits_lt {Ly : ShieldLayer} (f : (shieldShape Ly).Hid) : f.val < 2 ^ 14 := by
  have hf : f.val < 9216 := f.isLt; omega

private theorem not_wid_lt_of_pad {c : Fin 12 → Bool} (h : ∀ i : Fin 3072, Exec.msbBits 12 i.val ≠ c) :
    ¬ Exec.msbIndex 12 c < 3072 := by
  intro hlt
  exact h ⟨Exec.msbIndex 12 c, hlt⟩ (Exec.msbBits_msbIndex 12 c)

private theorem not_hid_lt_of_pad {c : Fin 14 → Bool} (h : ∀ f : Fin 9216, Exec.msbBits 14 f.val ≠ c) :
    ¬ Exec.msbIndex 14 c < 9216 := by
  intro hlt
  exact h ⟨Exec.msbIndex 14 c, hlt⟩ (Exec.msbBits_msbIndex 14 c)

private def grpColFn (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (p : (Fin 7 → Bool) × (Fin 14 → Bool)) : GF :=
  if h : Exec.msbIndex 14 p.2 < 9216 then (Pb.grpF ⟨Exec.msbIndex 14 p.2, h⟩ : GF) else 0

private theorem grpColFn_emb (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (p : (shieldShape Ly).Tok × (shieldShape Ly).Hid) :
    grpColFn Ly Pb (Exec.msbBits 7 p.1.val, Exec.msbBits 14 p.2.val) = (Pb.grpF p.2 : GF) := by
  unfold grpColFn
  have hidx := Exec.msbIndex_msbBits 14 p.2.val (hid_msbBits_lt p.2)
  have hlt : Exec.msbIndex 14 (Exec.msbBits 14 p.2.val) < 9216 := by rw [hidx]; exact p.2.isLt
  rw [dite_eq_left hlt]
  exact congrArg (fun k : ℕ => (k : GF)) (congrArg Pb.grpF (Fin.ext hidx))

private def wgFn (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cw : Fin 12 → Bool) (cf : Fin 14 → Bool) : GF :=
  if hw : Exec.msbIndex 12 cw < 3072 then
    if hf : Exec.msbIndex 14 cf < 9216 then
      let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
      ((Pb.wg ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mg f : ℤ) : ℤ) : GF)
    else 0
  else 0

private theorem wgFn_emb (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (i : (shieldShape Ly).Wid) (f : (shieldShape Ly).Hid) :
    wgFn Ly Pb (Exec.msbBits 12 i.val) (Exec.msbBits 14 f.val)
      = ((Pb.wg i f * (Pb.mg f : ℤ) : ℤ) : GF) := by
  unfold wgFn
  have hi0 := Exec.msbIndex_msbBits 12 i.val (wid_msbBits_lt i)
  have hf0 := Exec.msbIndex_msbBits 14 f.val (hid_msbBits_lt f)
  have hltW : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 := by rw [hi0]; exact i.isLt
  have hltF : Exec.msbIndex 14 (Exec.msbBits 14 f.val) < 9216 := by rw [hf0]; exact f.isLt
  rw [dite_eq_left hltW, dite_eq_left hltF]
  have hi : (⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), hltW⟩ : (shieldShape Ly).Wid) = i := Fin.ext hi0
  have hf : (⟨Exec.msbIndex 14 (Exec.msbBits 14 f.val), hltF⟩ : (shieldShape Ly).Hid) = f := Fin.ext hf0
  rw [hi, hf]

private def wuFn (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cw : Fin 12 → Bool) (cf : Fin 14 → Bool) : GF :=
  if hw : Exec.msbIndex 12 cw < 3072 then
    if hf : Exec.msbIndex 14 cf < 9216 then
      let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
      ((Pb.wu ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mu f : ℤ) : ℤ) : GF)
    else 0
  else 0

private theorem wuFn_emb (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (i : (shieldShape Ly).Wid) (f : (shieldShape Ly).Hid) :
    wuFn Ly Pb (Exec.msbBits 12 i.val) (Exec.msbBits 14 f.val)
      = ((Pb.wu i f * (Pb.mu f : ℤ) : ℤ) : GF) := by
  unfold wuFn
  have hi0 := Exec.msbIndex_msbBits 12 i.val (wid_msbBits_lt i)
  have hf0 := Exec.msbIndex_msbBits 14 f.val (hid_msbBits_lt f)
  have hltW : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 := by rw [hi0]; exact i.isLt
  have hltF : Exec.msbIndex 14 (Exec.msbBits 14 f.val) < 9216 := by rw [hf0]; exact f.isLt
  rw [dite_eq_left hltW, dite_eq_left hltF]
  have hi : (⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), hltW⟩ : (shieldShape Ly).Wid) = i := Fin.ext hi0
  have hf : (⟨Exec.msbIndex 14 (Exec.msbBits 14 f.val), hltF⟩ : (shieldShape Ly).Hid) = f := Fin.ext hf0
  rw [hi, hf]

private def wdFn (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cf : Fin 14 → Bool) (cw : Fin 12 → Bool) : GF :=
  if hf : Exec.msbIndex 14 cf < 9216 then
    if hw : Exec.msbIndex 12 cw < 3072 then
      let j : (shieldShape Ly).Wid := ⟨Exec.msbIndex 12 cw, hw⟩
      ((Pb.wd ⟨Exec.msbIndex 14 cf, hf⟩ j * (Pb.md j : ℤ) : ℤ) : GF)
    else 0
  else 0

private theorem wdFn_emb (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (f : (shieldShape Ly).Hid) (j : (shieldShape Ly).Wid) :
    wdFn Ly Pb (Exec.msbBits 14 f.val) (Exec.msbBits 12 j.val)
      = ((Pb.wd f j * (Pb.md j : ℤ) : ℤ) : GF) := by
  unfold wdFn
  have hf0 := Exec.msbIndex_msbBits 14 f.val (hid_msbBits_lt f)
  have hj0 := Exec.msbIndex_msbBits 12 j.val (wid_msbBits_lt j)
  have hltF : Exec.msbIndex 14 (Exec.msbBits 14 f.val) < 9216 := by rw [hf0]; exact f.isLt
  have hltW : Exec.msbIndex 12 (Exec.msbBits 12 j.val) < 3072 := by rw [hj0]; exact j.isLt
  rw [dite_eq_left hltF, dite_eq_left hltW]
  have hf : (⟨Exec.msbIndex 14 (Exec.msbBits 14 f.val), hltF⟩ : (shieldShape Ly).Hid) = f := Fin.ext hf0
  have hj : (⟨Exec.msbIndex 12 (Exec.msbBits 12 j.val), hltW⟩ : (shieldShape Ly).Wid) = j := Fin.ext hj0
  rw [hf, hj]

/-- Concrete `W16Pub` embedding any `Pb : BlockPublic (shieldShape Ly)` onto the R13 bit cube. -/
def shdP_w16Pub (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    W16Pub (shieldShape Ly) Pb (shdP_bitLay Ly) where
  gT _ := 1
  gD p := if Exec.msbIndex 12 p.2 < 3072 then 1 else 0
  gQ _ := 1
  gK _ := 1
  gS _ := 1
  gHt _ := 1
  gF p := if Exec.msbIndex 14 p.2 < 9216 then 1 else 0
  gT_one _ := rfl
  gD_one p := by
    have hp2 : p.2.val < 3072 := p.2.isLt
    show (if Exec.msbIndex 12 (Exec.msbBits 12 p.2.val) < 3072 then (1 : GF) else 0) = 1
    rw [Exec.msbIndex_msbBits 12 p.2.val (wid_msbBits_lt p.2), ite_eq_left hp2]
  gQ_one _ := rfl
  gK_one _ := rfl
  gS_one _ := rfl
  gHt_one _ := rfl
  gF_one p := by
    have hp2 : p.2.val < 9216 := p.2.isLt
    show (if Exec.msbIndex 14 (Exec.msbBits 14 p.2.val) < 9216 then (1 : GF) else 0) = 1
    rw [Exec.msbIndex_msbBits 14 p.2.val (hid_msbBits_lt p.2), ite_eq_left hp2]
  gD_pad _ _ h := ite_eq_right (not_wid_lt_of_pad h)
  gS_pad _ _ j h := absurd (msbBits_tokInv j) (h (tokInv j))
  gamA p := if h : Exec.msbIndex 12 p.2 < 3072 then (Pb.gA ⟨Exec.msbIndex 12 p.2, h⟩ : GF) else 0
  gamM p := if h : Exec.msbIndex 12 p.2 < 3072 then (Pb.gM ⟨Exec.msbIndex 12 p.2, h⟩ : GF) else 0
  gamA_emb p := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 p.2.val) < 3072 then
      (Pb.gA ⟨Exec.msbIndex 12 (Exec.msbBits 12 p.2.val), h⟩ : GF) else 0) = (Pb.gA p.2 : GF)
    have hidx := Exec.msbIndex_msbBits 12 p.2.val (wid_msbBits_lt p.2)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 p.2.val) < 3072 := by rw [hidx]; exact p.2.isLt
    rw [dite_eq_left hlt]
    congr 2
    exact Fin.ext hidx
  gamM_emb p := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 p.2.val) < 3072 then
      (Pb.gM ⟨Exec.msbIndex 12 (Exec.msbBits 12 p.2.val), h⟩ : GF) else 0) = (Pb.gM p.2 : GF)
    have hidx := Exec.msbIndex_msbBits 12 p.2.val (wid_msbBits_lt p.2)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 p.2.val) < 3072 := by rw [hidx]; exact p.2.isLt
    rw [dite_eq_left hlt]
    congr 2
    exact Fin.ext hidx
  cosT p := (Pb.cos (tokInv p.1) (hdInv p.2.2).2 : GF)
  sinT p := ((ropeSgn (hdInv p.2.2).1 * Pb.sin (tokInv p.1) (hdInv p.2.2).2 : ℤ) : GF)
  cosT_emb p := by
    have ht : tokInv (Exec.msbBits 7 p.1.val) = p.1 := tokInv_msbBits p.1
    have hh : hdInv (hdEmb p.2.2) = p.2.2 := hdInv_hdEmb p.2.2
    show (Pb.cos (tokInv (Exec.msbBits 7 p.1.val)) (hdInv (hdEmb p.2.2)).2 : GF) = _
    rw [ht, hh]
  sinT_emb p := by
    have ht : tokInv (Exec.msbBits 7 p.1.val) = p.1 := tokInv_msbBits p.1
    have hh : hdInv (hdEmb p.2.2) = p.2.2 := hdInv_hdEmb p.2.2
    show ((ropeSgn (hdInv (hdEmb p.2.2)).1
      * Pb.sin (tokInv (Exec.msbBits 7 p.1.val)) (hdInv (hdEmb p.2.2)).2 : ℤ) : GF) = _
    rw [ht, hh]
  cosK p := (Pb.cos (tokInv p.1) (hdInv p.2.2).2 : GF)
  sinK p := ((ropeSgn (hdInv p.2.2).1 * Pb.sin (tokInv p.1) (hdInv p.2.2).2 : ℤ) : GF)
  cosK_emb p := by
    have ht : tokInv (Exec.msbBits 7 p.1.val) = p.1 := tokInv_msbBits p.1
    have hh : hdInv (hdEmb p.2.2) = p.2.2 := hdInv_hdEmb p.2.2
    show (Pb.cos (tokInv (Exec.msbBits 7 p.1.val)) (hdInv (hdEmb p.2.2)).2 : GF) = _
    rw [ht, hh]
  sinK_emb p := by
    have ht : tokInv (Exec.msbBits 7 p.1.val) = p.1 := tokInv_msbBits p.1
    have hh : hdInv (hdEmb p.2.2) = p.2.2 := hdInv_hdEmb p.2.2
    show ((ropeSgn (hdInv (hdEmb p.2.2)).1
      * Pb.sin (tokInv (Exec.msbBits 7 p.1.val)) (hdInv (hdEmb p.2.2)).2 : ℤ) : GF) = _
    rw [ht, hh]
  mask p := maskF (tokInv p.2.1) (tokInv p.2.2)
  mask_emb p := by
    have h1 : tokInv (Exec.msbBits 7 p.2.1.val) = p.2.1 := tokInv_msbBits p.2.1
    have h2 : tokInv (Exec.msbBits 7 p.2.2.val) = p.2.2 := tokInv_msbBits p.2.2
    dsimp only [W16Layout.sPos, shdP_bitLay, axMsb]
    rw [h1, h2]
    rfl
  grpCol := grpColFn Ly Pb
  grpCol_emb := grpColFn_emb Ly Pb
  Wq cw qc :=
    if h : Exec.msbIndex 12 cw < 3072 then
      let q : (shieldShape Ly).QC := (slotInv qc.1, hdInv qc.2)
      ((Pb.wq ⟨Exec.msbIndex 12 cw, h⟩ q * (Pb.mq q : ℤ) : ℤ) : GF)
    else 0
  Wk cw kc :=
    if h : Exec.msbIndex 12 cw < 3072 then
      let k : (shieldShape Ly).KC := (grpInv kc.1, hdInv kc.2)
      ((Pb.wk ⟨Exec.msbIndex 12 cw, h⟩ k * (Pb.mK k : ℤ) : ℤ) : GF)
    else 0
  Wv cw kc :=
    if h : Exec.msbIndex 12 cw < 3072 then
      let k : (shieldShape Ly).KC := (grpInv kc.1, hdInv kc.2)
      ((Pb.wv ⟨Exec.msbIndex 12 cw, h⟩ k * (Pb.mv k : ℤ) : ℤ) : GF)
    else 0
  Wo qc cw :=
    if h : Exec.msbIndex 12 cw < 3072 then
      let q : (shieldShape Ly).QC := (slotInv qc.1, hdInv qc.2)
      ((Pb.wo q ⟨Exec.msbIndex 12 cw, h⟩ * (Pb.mo ⟨Exec.msbIndex 12 cw, h⟩ : ℤ) : ℤ) : GF)
    else 0
  Wg := wgFn Ly Pb
  Wu := wuFn Ly Pb
  Wd := wdFn Ly Pb
  Wq_emb i c := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 then
      ((Pb.wq ⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), h⟩ (slotInv (slotEmb c.1), hdInv (hdEmb c.2))
        * (Pb.mq (slotInv (slotEmb c.1), hdInv (hdEmb c.2)) : ℤ) : ℤ) : GF) else 0) = _
    have hidx := Exec.msbIndex_msbBits 12 i.val (wid_msbBits_lt i)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 := by rw [hidx]; exact i.isLt
    have hs : slotInv (slotEmb c.1) = c.1 := slotInv_slotEmb c.1
    have hh : hdInv (hdEmb c.2) = c.2 := hdInv_hdEmb c.2
    rw [dite_eq_left hlt, hs, hh]
    have hi : (⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), hlt⟩ : (shieldShape Ly).Wid) = i := Fin.ext hidx
    rw [hi]
  Wk_emb i c := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 then
      ((Pb.wk ⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), h⟩ (grpInv (Exec.msbBits 3 c.1.val), hdInv (hdEmb c.2))
        * (Pb.mK (grpInv (Exec.msbBits 3 c.1.val), hdInv (hdEmb c.2)) : ℤ) : ℤ) : GF) else 0) = _
    have hidx := Exec.msbIndex_msbBits 12 i.val (wid_msbBits_lt i)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 := by rw [hidx]; exact i.isLt
    have hg : grpInv (Exec.msbBits 3 c.1.val) = c.1 := grpInv_msbBits c.1
    have hh : hdInv (hdEmb c.2) = c.2 := hdInv_hdEmb c.2
    rw [dite_eq_left hlt, hg, hh]
    have hi : (⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), hlt⟩ : (shieldShape Ly).Wid) = i := Fin.ext hidx
    rw [hi]
  Wv_emb i c := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 then
      ((Pb.wv ⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), h⟩ (grpInv (Exec.msbBits 3 c.1.val), hdInv (hdEmb c.2))
        * (Pb.mv (grpInv (Exec.msbBits 3 c.1.val), hdInv (hdEmb c.2)) : ℤ) : ℤ) : GF) else 0) = _
    have hidx := Exec.msbIndex_msbBits 12 i.val (wid_msbBits_lt i)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 i.val) < 3072 := by rw [hidx]; exact i.isLt
    have hg : grpInv (Exec.msbBits 3 c.1.val) = c.1 := grpInv_msbBits c.1
    have hh : hdInv (hdEmb c.2) = c.2 := hdInv_hdEmb c.2
    rw [dite_eq_left hlt, hg, hh]
    have hi : (⟨Exec.msbIndex 12 (Exec.msbBits 12 i.val), hlt⟩ : (shieldShape Ly).Wid) = i := Fin.ext hidx
    rw [hi]
  Wo_emb c j := by
    change (if h : Exec.msbIndex 12 (Exec.msbBits 12 j.val) < 3072 then
      ((Pb.wo (slotInv (slotEmb c.1), hdInv (hdEmb c.2)) ⟨Exec.msbIndex 12 (Exec.msbBits 12 j.val), h⟩
        * (Pb.mo ⟨Exec.msbIndex 12 (Exec.msbBits 12 j.val), h⟩ : ℤ) : ℤ) : GF) else 0) = _
    have hidx := Exec.msbIndex_msbBits 12 j.val (wid_msbBits_lt j)
    have hlt : Exec.msbIndex 12 (Exec.msbBits 12 j.val) < 3072 := by rw [hidx]; exact j.isLt
    have hs : slotInv (slotEmb c.1) = c.1 := slotInv_slotEmb c.1
    have hh : hdInv (hdEmb c.2) = c.2 := hdInv_hdEmb c.2
    rw [dite_eq_left hlt, hs, hh]
    have hj : (⟨Exec.msbIndex 12 (Exec.msbBits 12 j.val), hlt⟩ : (shieldShape Ly).Wid) = j := Fin.ext hidx
    rw [hj]
  Wg_emb := wgFn_emb Ly Pb
  Wu_emb := wuFn_emb Ly Pb
  Wd_emb := wdFn_emb Ly Pb
  Wq_pad c _ h := dite_eq_right (not_wid_lt_of_pad h)
  Wk_pad c _ h := dite_eq_right (not_wid_lt_of_pad h)
  Wv_pad c _ h := dite_eq_right (not_wid_lt_of_pad h)
  Wo_pad c _ h := by
    exfalso
    exact h (slotInv c.1, hdInv c.2) (Prod.ext (slotEmb_slotInv c.1) (hdEmb_hdInv c.2))
  Wg_pad c _ h := by unfold wgFn; exact dite_eq_right (not_wid_lt_of_pad h)
  Wu_pad c _ h := by unfold wuFn; exact dite_eq_right (not_wid_lt_of_pad h)
  Wd_pad c _ h := by unfold wdFn; exact dite_eq_right (not_hid_lt_of_pad h)

end BitLayout

/-! ## 4. Concrete 26-layer `BlockParams` (`shdP_Pk0`) and `ShieldRunAtD` from `ShieldRun Rp` -/

section ConcreteBlocks

/-- Row counts per commitment for a Shieldstral R13 block (`A = 4577`, `H = 4390`, endpoints `38`). -/
def shdP_rowsOf : Cm → ℕ
  | .a => 4577
  | .h => 4390
  | _ => 38

/-- Slot kinds for the 23-slot R13 / W16R2 block schedule, as `SlotW16R2.kindOf` (layout.rs `SLOT_KINDS`): hosts at
`{2, 14, 15, 16, 17, 18}`, standalone at `{3, 19, 20, 21, 22}`, private elsewhere (ruling L63-9, finding L68b-2). -/
def shdP_slotKind (s : ℕ) : SlotKind :=
  if s = 2 ∨ s = 14 ∨ s = 15 ∨ s = 16 ∨ s = 17 ∨ s = 18 then SlotKind.host
  else if s = 3 ∨ s = 19 ∨ s = 20 ∨ s = 21 ∨ s = 22 then SlotKind.standalone else SlotKind.priv

/-- Concrete `BlockParams` for one Shieldstral layer `(Ly, Pb)` at R13. The mask's opened columns have `mRows = 50`
words (`2·23 + 4` for the 23 mask specs: `maskField tag 23` checks `2S + 4`, `shape_corpus.txt` has `m_rows 50`; ruling
L63-9, finding L68b-1). -/
def shdP_blkParams (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) : BlockParams where
  geom := Exec.Block.R13.geom Exec.Block.R13.shieldSlots Exec.Block.R13.shieldTerms 50 36 4577 9 4390
  logCols := 14
  endpointLogN := 14
  aRows := 4577
  hRows := 4390
  aPath := 16
  hPath := 16
  maskPath := 12
  preChecks := .ok ()
  kind := shdP_slotKind
  name s := toString s
  draws := Exec.Block.R13.shieldDraws
  define := defineS (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut)
    (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG)
  nFunctionals := 34
  logupSumClaim := logupSumR13 (Exec.Block.DefR13.cfgShieldR13 Ly)
  maskVerify := maskField tag 23
  checkOpening := checkOpening
  pcsVerify := ZK60.Exec.R13.pcsFieldR13 tag shdP_rowsOf

theorem shdP_blkParams_shieldBlkAtD (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ShieldBlkAtD tag shieldDPos0 (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb) Ly Pb :=
  ⟨shdP_rowsOf, shdP_bitLay Ly, shdP_w16Pub Ly Pb, ioIn, ioOut,
    ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩,
    rfl, rfl, rfl,
    show shdP_slotKind 3 = SlotKind.standalone from by decide,
    show shdP_slotKind 19 = SlotKind.standalone from by decide,
    show shdP_slotKind 20 = SlotKind.standalone from by decide,
    show shdP_slotKind 21 = SlotKind.standalone from by decide,
    show shdP_slotKind 22 = SlotKind.standalone from by decide,
    rfl, shdP_bitLay_layR Ly, shdP_bitLay_dPos Ly⟩

/-- Concrete 26-layer `Pk0 : ℕ → BlockParams` read directly from `Rp : ClassifyRunPublicP shieldS0`
(clamped at `min k 25` so `shdP_clampPk (shdP_Pk0 ...) = shdP_Pk0 ...`). -/
noncomputable def shdP_Pk0 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (k : ℕ) : BlockParams := by
  classical
  exact match shieldExport[min k 25]?, Rp.blks[min k 25]? with
    | some Ly, some b =>
        if hcal : b.cal = shieldCal Ly then
          shdP_blkParams tag ioIn ioOut checkOpening Ly
            (cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) hcal) b.pub)
        else
          shdP_blkParams tag ioIn ioOut checkOpening Ly (zeroPub (shieldShape Ly))
    | _, _ =>
        let Ly0 : ShieldLayer := ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩
        shdP_blkParams tag ioIn ioOut checkOpening Ly0 (zeroPub (shieldShape Ly0))

/-- Because `shdP_Pk0` already indexes at `min k 25`, `shdP_clampPk` is the identity on `shdP_Pk0`. -/
theorem shdP_clampPk_Pk0 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) :
    shdP_clampPk (shdP_Pk0 tag ioIn ioOut checkOpening Rp) = shdP_Pk0 tag ioIn ioOut checkOpening Rp := by
  funext k
  simp only [shdP_clampPk, shdP_Pk0, Nat.min_assoc, Nat.min_self]

/-- Block list length `Rp.blks.length = 26` from `hR : ShieldRun Rp`. -/
theorem shdP_blks_length {Rp : ClassifyRunPublicP shieldS0} (hR : ShieldRun Rp) :
    Rp.blks.length = 26 := by
  have hm := congrArg List.length hR
  simp only [List.length_map, shieldExport_l17.1] at hm
  exact hm

/-- Block `k`'s calibration equals `shieldCal shieldExport[k]` for `k < 26` under `hR : ShieldRun Rp`. -/
theorem shdP_blk_cal_eq {Rp : ClassifyRunPublicP shieldS0} (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    (Rp.blks[k]'(by rw [shdP_blks_length hR]; exact hk)).cal =
      shieldCal (shieldExport[k]'(by rw [shieldExport_l17.1]; exact hk)) := by
  have hk_exp : k < shieldExport.length := by rw [shieldExport_l17.1]; exact hk
  have hk_blk : k < Rp.blks.length := by rw [shdP_blks_length hR]; exact hk
  have hcal_opt : (Rp.blks.map RunBlock.cal)[k]? = (shieldExport.map shieldCal)[k]? :=
    congrArg (fun l => l[k]?) hR
  simp only [List.getElem?_map, List.getElem?_eq_getElem hk_blk, List.getElem?_eq_getElem hk_exp,
    Option.map_some, Option.some.injEq] at hcal_opt
  exact hcal_opt

/-- Exported equation giving `shdP_Pk0 ... k` (`k < 26`) as `shdP_blkParams` at block `k`'s layer and public data
(proved before `attribute [irreducible] shdP_Pk0` so downstream proofs never need to unfold `shdP_Pk0`). -/
theorem shdP_Pk0_eq_blkParams (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    shdP_Pk0 tag ioIn ioOut checkOpening Rp k =
      let Ly := shieldExport[k]'(by rw [shieldExport_l17.1]; exact hk)
      let b := Rp.blks[k]'(by rw [shdP_blks_length hR]; exact hk)
      shdP_blkParams tag ioIn ioOut checkOpening Ly
        (cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) (shdP_blk_cal_eq hR k hk)) b.pub) := by
  classical
  have hk_min : min k 25 = k := Nat.min_eq_left (by omega)
  have hk_exp : k < shieldExport.length := by rw [shieldExport_l17.1]; exact hk
  have hk_blk : k < Rp.blks.length := by rw [shdP_blks_length hR]; exact hk
  have hLy : shieldExport[k]? = some (shieldExport[k]'hk_exp) := List.getElem?_eq_getElem hk_exp
  have hb : Rp.blks[k]? = some (Rp.blks[k]'hk_blk) := List.getElem?_eq_getElem hk_blk
  have hcal := shdP_blk_cal_eq hR k hk
  unfold shdP_Pk0
  simp only [hk_min, hLy, hb, dite_eq_left hcal]

/-- Given `hR : ShieldRun Rp`, the Lean-defined block verifier family `shdP_Pk0` satisfies
`ShieldRunAtD tag shieldDPos0 (shdP_Pk0 ...) Rp.blks 26` by construction. -/
theorem shdP_shieldRunAtD (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) :
    ShieldRunAtD tag shieldDPos0 (shdP_Pk0 tag ioIn ioOut checkOpening Rp) Rp.blks 26 := by
  intro k hk
  have hk_exp : k < shieldExport.length := by rw [shieldExport_l17.1]; exact hk
  have hk_blk : k < Rp.blks.length := by rw [shdP_blks_length hR]; exact hk
  let Ly := shieldExport[k]'hk_exp
  let b := Rp.blks[k]'hk_blk
  have hLy : shieldExport[k]? = some Ly := List.getElem?_eq_getElem hk_exp
  have hb : Rp.blks[k]? = some b := List.getElem?_eq_getElem hk_blk
  have hcal : b.cal = shieldCal Ly := shdP_blk_cal_eq hR k hk
  let Pb : BlockPublic (shieldShape Ly) :=
    cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) hcal) b.pub
  have hPb : HEq Pb b.pub := cast_heq _ b.pub
  refine ⟨Ly, b, Pb, hLy, hb, hcal, hPb, ?_⟩
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]
  exact shdP_blkParams_shieldBlkAtD tag ioIn ioOut checkOpening Ly Pb

-- Intentionally global `@[irreducible]` so downstream theorems pass `shdP_Pk0` without unfolding the 26-layer match;
-- use `shdP_Pk0_eq_blkParams`, `shdP_clampPk_Pk0`, and `shdP_shieldRunAtD` for its specification.
attribute [irreducible] shdP_Pk0

end ConcreteBlocks

/-! ## 5. Joined top theorem `sshC_productionReadyL_epP_blkLu` on `sshC_productionReadyL_epP_shieldLu` -/

section BlkLuTop

variable {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
  (tag : MTag)
  (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (key : Option Dig)
  (Rp : ClassifyRunPublicP shieldS0)
  (hR : ShieldRun Rp)
  (hw : Hdr → ClsHdrW)
  (hhdrFit : ∀ hd : Hdr,
    64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq)
  (preA preB : Hdr → Except String Unit)
  (check0 : ClsStmt Hdr → ℕ → Except String Unit)
  (paths : ClsStmt Hdr → Exec.Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig)
  (bndCheck : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
  (ioIn ioOut : ℕ)
  (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
  (embDigest : Dig) (embFold : List Fp2 → List Fp2) (bInRow : ℕ)
  (wDigest : Dig) (bOutRow : ℕ)
  (P : RunP Hdr (shieldS0.Tok → ℕ) Coins)
  (epBase : Coins → EpxSalt 6)
  (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 (EpxSalt 6))

set_option quotPrecheck false

local notation "Pk0B" => shdP_Pk0 tag ioIn ioOut checkOpening Rp
local notation "HPk0B" => shdP_shieldRunAtD tag ioIn ioOut checkOpening Rp hR
local notation "DomB" => shdP_runDomain
local notation "HsB" => shdP_runDomain_start_none
local notation "HLB" => shdP_runDomain_start_le hL20

local notation "RnB" =>
  shdP_rtRun Lq hL20 tag key DomB hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
    HPk0B check0 paths digest bndCheck

local notation "ViB" => shdP_incV tag Rp embDigest embFold bInRow
local notation "FoB" => shdP_outcV tag Rp wDigest bOutRow
local notation "IinB" => shdP_Iin (Hdr := Hdr) Lq hL20 tag Rp embDigest embFold bInRow
local notation "OoutB" => shdP_Oout (Hdr := Hdr) Lq hL20 tag Rp wDigest bOutRow
local notation "P0inB" => shdP_P0in tag Rp embDigest embFold bInRow
local notation "P0outB" => shdP_P0out tag Rp wDigest bOutRow
local notation "AbsB" => Exec.Block.absOfC (chainEncB key DomB HsB Lq HLB)
local notation "HvB" =>
  shdP_rtProf_valid Lq hL20 tag key DomB hw hhdrFit preA preB Rp embDigest embFold bInRow wDigest bOutRow
    HPk0B check0 paths digest bndCheck

private theorem zero_lt_26_blk : 0 < 26 := by decide

local notation "BpB" => shdP_rtBlk Lq hL20 tag HPk0B
local notation "PXkB" => cbBndPcs (St := ClsStmt Hdr) tag 38
local notation "CinB" =>
  epTokenCommit (St := ClsStmt Hdr) 6 1 shdP_epPos_injective shdP_epPlace
    (epxMsg 6 1 shdP_epPlace shdP_epPos) (epxMsg_place 6 1 shdP_epPlace shdP_epPos shdP_epPlace_injective)
    EpxSalt.pads EpxSalt.salts EpxSalt.paths ClsStmt.inRoot tag

local notation "CsIOIB" =>
  stgCsIOm shdP_U 6 8 256 (PXkB 0).rows 14 256
    (epUxV tag Lq (le64_of_le20 hL20) key DomB HsB HLB 6)
    (bxUxV tag Lq (le64_of_le20 hL20) (PXkB 0).rows ((RnB).pf.off 0 + 2))

local notation "XEB" => fun (_ : StgVw Lq) (_ : Fin 0) (_ : Fin (2 ^ 0 + 0)) => (0 : shdP_K)

local notation "CsIOOB" =>
  stgCsIOm shdP_U (OoutB).pX.rows 14 256 0 0 0
    (bxUxV tag Lq (le64_of_le20 hL20) (OoutB).pX.rows ((RnB).pf.off 26 + 2)) (XEB)

local notation "ΛIcB" =>
  shd_ΛI (K := shdP_K) shdP_U tag (le64_of_le20 hL20) Rp.inp (shdP_incPub Rp embDigest embFold) (shdEpad Rp.inp)
    ((RnB).pf.off 0 + 2) ((RnB).pf.off 0 + 5)

local notation "ΛOcB" =>
  shd_ΛO (K := shdP_K) shdP_U tag (le64_of_le20 hL20) (shdP_outcPub Rp wDigest) ((RnB).pf.off 27 + 2)

local notation "RkDLB" =>
  shdRkD shdP_U shdP_hbij tag shieldDPos0 Lq (le64_of_le20 hL20) hL20 key DomB HsB HLB 26 zero_lt_26_blk
    (RnB).pf (shdP_clampPk Pk0B) (shdP_shieldRunAtD_clamp HPk0B) ViB FoB
    (ViB).lay.logupSumClaim (FoB 0).lay.logupSumClaim
    (rcIncPart ViB 256 256) (rcOutcPart (FoB 0) 256 256 1)
    15 8 14 (IinB).pA.rows (IinB).pH.rows (IinB).pX.rows (IinB).nA (IinB).nH (IinB).nIn (IinB).nOut
    (OoutB).pA.rows (OoutB).pH.rows (OoutB).pX.rows (OoutB).nA (OoutB).nH (OoutB).nIn
    (fun j => (BpB j).S) (fun j => (BpB j).pA.rows) (fun j => (BpB j).pH.rows)
    (fun j => (BpB j).nA) (fun j => (BpB j).nH) (fun j => (BpB j).nIn) (fun j => (BpB j).nOut)
    (fun j => (PXkB j).rows) P0inB P0outB (CsIOIB) (CsIOOB) shdP_eI shdP_eO (ΛIcB) (ΛOcB)

local notation "ProtoClampedB" =>
  classifyProtocolUExecP Rp Lq 26 preA preB (clsStart DomB key hw)
    (fun _ => ViB) (fun _ => rcIncGeom ViB 28)
    (d12aBlockProf (shdP_clampPk Pk0B) (shdP_sgeom Hdr (shdP_clampPk Pk0B)) (vdChk check0) paths digest
      (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
    (fun _ v => FoB v) (fun _ => rcOutcGeom (FoB 0) 28)
    P (CinB) (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn (Hdr := Hdr) tag epBase).base 768

local notation "ProtoUnclampedB" =>
  classifyProtocolUExecP Rp Lq 26 preA preB (clsStart DomB key hw)
    (fun _ => ViB) (fun _ => rcIncGeom ViB 28)
    (d12aBlockProf Pk0B (shdP_sgeom Hdr Pk0B) (vdChk check0) paths digest
      (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
    (fun _ v => FoB v) (fun _ => rcOutcGeom (FoB 0) 28)
    P (CinB) (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn (Hdr := Hdr) tag epBase).base 768

local notation "BadEvB" => fun A G =>
  EvXR tag Lq (le64_of_le20 hL20) (chainEncB key DomB HsB Lq HLB) 256 256 256 16 16 12 26
    (rxCoreOf (shdP_sgeom Hdr (shdP_clampPk Pk0B)))
    (rxVx tag Lq (le64_of_le20 hL20) (fun _ => rcIncGeom ViB 28) (fun _ => rcOutcGeom (FoB 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0B)) 26)
    (rxRoots (fun _ => rcIncGeom ViB 28) (fun _ => rcOutcGeom (FoB 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0B)) 26) A G
  ∨ exEvIn tag Lq (le64_of_le20 hL20) key DomB HsB HLB
      (fun _ => rcIncGeom ViB 28) (fun _ => rcOutcGeom (FoB 0) 28)
      (shdP_sgeom Hdr (shdP_clampPk Pk0B)) 26 A G

/-- **JOINED CONCRETE SHIELDSTRAL T128 R13 TOP THEOREM (`L68a`)** on top of `sshC_productionReadyL_epP_shieldLu`:
instantiates `shdP_K`, `shdP_U`, `shdP_hbij`, `shdP_hU`, `shieldDPos0`, `shdP_runDomain`, the Lean-defined block
verifier `shdP_Pk0` (`shdP_shieldRunAtD` from `hR : ShieldRun Rp`), `csIOI`/`csIOO`/`XE` (`hcsI = rfl`, `hcsO = rfl`),
`hV := O.inPub.V2`, and the numeric ZK error bound `shdP_hzk` (`O.zk` remains open), while removing `shdP_clampPk`
from `O` and from the `ProductionReadyL` conclusion (`shdP_clampPk_Pk0`). -/
theorem sshC_productionReadyL_epP_blkLu
    {ι : Type} [Fintype ι]
    (site : (shieldS0.Tok → ℕ) → ι → Site (QB Lq) Coins shdP_K)
    (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (O : ClassifyOpenP Rp Lq
      (shdP_runV tag key DomB hw preA preB Rp embDigest embFold bInRow wDigest bOutRow
        Pk0B check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site kOf δOf (ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds))
    (hLI_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDLB).Valid AbsB (RnB).pf),
      (ProtoClampedB).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvB A G →
      ¬ (rtKB key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKM key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKA key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKsl key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKR0 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKR1 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKH0 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKH1 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      StgLkAtV shdP_U key DomB (fun ch => (ViB).bp (incCtx (ViB).pub ch)) 15
        ((RnB).pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) AbsB (ΛIcB) G (A.runLog G).2
        (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)))
    (hLO_stg : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
      (hDV : (RkDLB).Valid AbsB (RnB).pf),
      (ProtoClampedB).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvB A G →
      ¬ (rtKB key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKM key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKA key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKsl key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKR0 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKR1 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKH0 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      ¬ (rtKH1 key DomB HsB Lq HLB (RnB).pf (RnB).rd hL64 HvB shdP_U shdP_hbij RkDLB hDV).Dm (Rp.blks.length + 2)
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)) →
      StgLkAtV shdP_U key DomB (fun _ => (FoB (A.run G).1.verdict).bp) 2 ((RnB).pf.off 27 + 2) OutcV.bga AbsB (ΛOcB) G
        (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)))
    (hdinS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (ProtoClampedB).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvB A G →
      ¬ InOkP Rp ((epxE (CinB)
        (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos
        (epxOps tag Lq (le64_of_le20 hL20) key DomB HsB HLB abRdIn 11 6 (N := 2 ^ 11))
        (epxBndE shdP_U tag Lq (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf (RnB).rd RkDLB shieldDPos0 E0))
        (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      StgDoomAtV shdP_U key DomB P0inB (fun ch => (ViB).bp (incCtx (ViB).pub ch)) 15
        ((RnB).pf.off 0 + 5) (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn AbsB
        (stgFstIC shdP_U shdP_hbij tag (le64_of_le20 hL20) P0inB (vdWin ViB)
          ((RnB).pf.off 0 + (rcIncPart ViB 256 256).pre) ((RnB).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinB).pA.rows (IinB).pH.rows (rcIncPart ViB 256 256).S (CsIOIB))
        (sshΦIC shdP_U shdP_hbij tag (le64_of_le20 hL20) P0inB ViB
          ((RnB).pf.off 0 + (rcIncPart ViB 256 256).pre) ((RnB).pf.off 0 + 5)
          15 ogStage.lc ogStage.h ogStage.Q ogStage.e (IinB).pA.rows (IinB).pH.rows (CsIOIB))
        sshDgI shdP_eI (ΛIcB) G (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G)))
    (hdoutS : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (ProtoClampedB).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BadEvB A G →
      ¬ OutOkP Rp ((ProtoClampedB).ypub (A.runLog G).1.1)
        ((epxE (CinB)
          (epxMk 6 1 shdP_epPlace shdP_epPos_injective shdP_epPlace_injective ClsStmt.inRoot tag) shdP_epPos
          (epxOps tag Lq (le64_of_le20 hL20) key DomB HsB HLB abRdIn 11 6 (N := 2 ^ 11))
          (epxBndE shdP_U tag Lq (le64_of_le20 hL20) key DomB HsB HLB (RnB).pf (RnB).rd RkDLB shieldDPos0 E0))
          (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      StgDoomAtV shdP_U key DomB P0outB (fun _ => (FoB (A.run G).1.verdict).bp) 2 ((RnB).pf.off 27 + 2) OutcV.bga
        (stgHostOut P0outB) AbsB
        (stgFstO shdP_U shdP_hbij tag (le64_of_le20 hL20) P0outB (vdWout FoB)
          ((RnB).pf.off 27 + (rcOutcPart (FoB 0) 256 256 1).pre) ((RnB).pf.off 27 + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e (OoutB).pA.rows (OoutB).pH.rows (rcOutcPart (FoB 0) 256 256 1).S (CsIOOB))
        (sshΦO shdP_U shdP_hbij tag (le64_of_le20 hL20) P0outB FoB
          ((RnB).pf.off 27 + (rcOutcPart (FoB 0) 256 256 1).pre) ((RnB).pf.off 27 + 2)
          ogStage.lc ogStage.h ogStage.Q ogStage.e (OoutB).pA.rows (OoutB).pH.rows (CsIOOB))
        sshDgO shdP_eO (ΛOcB) G (A.runLog G).2 (rtTr key DomB Lq (RnB).pf (RnB).rd G (A.run G))) :
    ProductionReadyL (classifyModelP Rp) (classifyArithP Rp) ProtoUnclampedB
      (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget := by
  have hclamp := shdP_clampPk_Pk0 tag ioIn ioOut checkOpening Rp
  have O_clamped : ClassifyOpenP Rp Lq
      (shdP_runV tag key DomB hw preA preB Rp embDigest embFold bInRow wDigest bOutRow
        (shdP_clampPk Pk0B) check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site kOf δOf (ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds) :=
    (congrArg (fun Pk => ClassifyOpenP Rp Lq
      (shdP_runV tag key DomB hw preA preB Rp embDigest embFold bInRow wDigest bOutRow
        Pk check0 paths digest bndCheck)
      P (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn tag epBase) shdP_U site kOf δOf (ZK60.ZKHonest.refErr ZK60.ZKCount.RunK.kinds))
      hclamp.symm).mp O
  have hmain := sshC_productionReadyL_epP_shieldLu
    (Hdr := Hdr) (Coins := Coins) (K := shdP_K)
    (U := shdP_U) (hbij := shdP_hbij) (tag := tag) (dPos0 := shieldDPos0)
    (Lq := Lq) (hL20 := hL20) (hL64 := hL64) (key := key)
    (domain := DomB) (hs := HsB) (hL := HLB) (Rp := Rp) (hw := hw) (hhdrFit := hhdrFit)
    (preA := preA) (preB := preB) (check0 := check0) (paths := paths) (digest := digest) (bndCheck := bndCheck)
    (embDigest := embDigest) (embFold := embFold) (bInRow := bInRow) (wDigest := wDigest) (bOutRow := bOutRow)
    (Pk0 := Pk0B) (hPk0 := HPk0B) (P := P) (epBase := epBase) (E0 := E0)
    (csIOI := CsIOIB) (csIOO := CsIOOB)
    (hU := shdP_hU) (site := site) (kOf := kOf) (δOf := δOf) (O := O_clamped) (hzk := shdP_hzk)
    (hcsI := rfl) (rE := 0) (lcE := 0) (Qe := 0) (XE := XEB) (hcsO := rfl)
    (hXEl := fun _ _ _ _ => rfl) (hV := O.inPub.V2)
    (hLI_stg := hLI_stg) (hLO_stg := hLO_stg) (hdinS := hdinS) (hdoutS := hdoutS)
  exact (congrArg (fun Pk => ProductionReadyL (classifyModelP Rp) (classifyArithP Rp)
    (classifyProtocolUExecP Rp Lq 26 preA preB (clsStart DomB key hw)
      (fun _ => ViB) (fun _ => rcIncGeom ViB 28)
      (d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) paths digest
        (fun _ => 38) (fun _ => 14) bndCheck (cbBndOpen tag 38))
      (fun _ v => FoB v) (fun _ => rcOutcGeom (FoB 0) 28)
      P (CinB) (le64_of_le20 hL20) (shdP_hr tag hL20) (shdP_honestIn (Hdr := Hdr) tag epBase).base 768)
    (classifyLeakP Rp) εcTarget εsTarget εsTarget εzkTarget) hclamp).mp hmain

end BlkLuTop

end ZK60.ProtocolClassify
