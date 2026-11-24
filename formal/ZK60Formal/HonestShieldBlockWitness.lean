/-
D63 lane L68c, part 2b-i (`HonestShieldBlockWitness.lean`):
Part 1 of the 3-file Shieldstral T128 R13 block completeness lane
(`HonestShieldBlockWitness.lean` → `HonestShieldBlockTables.lean` → `HonestShieldBlockArith.lean`).

What this file proves (complete proofs; standard Lean logic only):
1. **`FullBndTableSpec` & Boundary Table Continuity:**
   - `FullBndTableSpec y TB`: 38-row, `logN = 14`, `Q = 256` honest boundary table contract over all
     `128 × 3072` positions (`ColsHonest` at `(lagK 14, 256, cosetPt (rootFp 16), 2^16)`).
   - `FullBndTableSpec.toBndTableSpec`: projects directly to `HonestShieldStageOutTables.BndTableSpec`.
   - `FullBndTableSpec.tabMat_at`: reads `tabMat 38 14 TB.rows` pointwise.
   - `shdP_incTB_fullBndTableSpec`: proves Stage IN-C's `shdP_incTB Rp x rnd` satisfies `FullBndTableSpec`.
   - `shdP_blkBndTable`, `shdP_blkBndTable_spec`: canonical per-block boundary table `TB_{k+1}`.
2. **26-Layer State Trajectory Extraction:**
   - `shdP_layer`, `shdP_blkPub`, `shdP_blkPub_valid`, `runSpecP_append`.
   - `shdP_blkState`: exact 27-state trajectory `Fin 27 → (shieldS0.Pos → ℤ)` with
     `shdP_blkState_zero`, `shdP_blkState_i16`, `shdP_blkState_step`, and `shdP_blkState_last`
     (exact bridge to `outcWitness_of_adm.y25`).
3. **Per-Block `BlkWitness` & `R13Data` Extraction (`blkWitness_of_spec`):**
   - Byte-limb decomposition (`gfByte`, `lv_gfByte`, `gfByte_pin_codeTable`), bit-cube axis inverses,
     zero-padding predicates (`BlkPadD`, `BlkPadF`, `BlkPadL`), and `blkWitness_of_spec` reusing
     `CircuitBlock.blockSat_iff` directly to produce `R13Data`, `R13Rels`, `R13Lookups`, padding, and IO.
4. **LogUp Multiplicities (`blkMultU8`, `blkMultExp`, `blkMultAct`) & Fiberwise Sum Lemma:**
   - Cube-wide lookup evaluator `blkLkTup` (matching `AlkR13` via `blkLkTup_eq_AlkR13`), canonical
     active-table target `blkLkTarget` (`blkLkTarget_active`, `blkLkTup_eq_tabTupE`, `blkLkTup_eq_TR13`),
     multiplicity bounds `< gP` via `hN_shield`, and the exact fiberwise LogUp sum identities
     (`blkMult_sum_fiber`, `blkMult_logup_sum`, `blkMult_logup_sum_3`).
-/
import ZK60Formal.HonestShieldBlockBase
import ZK60Formal.HonestShieldStageOutTables
import ZK60Formal.BlockR13LookCov

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun ZK60.Layout
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldGrp shieldCal shieldS0
  shieldShape shield_layers_ok shield_shapes_valid shield_shapes_r13 ShieldRun)
open ZK60.Circuit (gP GF InRange Word16 WordS8 Word24 RemW16 CodeTable ExpTable ActTable
  IsqrtRel NormDivRel HostRel RopeRel ProdRel ResidualRel SoftmaxRowRel SoftmaxDivRel
  maskF ropeSgn tagW tagExp tagAct rangeQuery expQuery actQuery
  word16_iff word24_iff remW16_iff expQuery_iff actQuery_iff
  codeTable_range_iff codeTable_exp_iff codeTable_act_iff obind_eq_some)
open ZK60.Block (BlockShape BlockPublic BlockWit BlockSat blockSpec blockSat_iff blockSpec_class
  i16 flipQ flipK)
open ZK60.Layout.R13 (R13Data R13Rels R13Lookups R13Windows lv lv_three r13Fams r13Fams_ok
  mem_r13Fams inRange8_of val_lt_of_inRange Bytes BytesPin pow256)
open ZK60.Exec.Block (BlockParams Cm CmData tupK)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Block.Join (castB)
open ZK60.Exec.Block.Join.W16 (aPl)
open ZK60.Exec.Block.Join.W16.Tab (tabTupE)
open ZK60.Exec.Block.Join.R13H (CtR CwR CgR CjR CdR CfR nD nH nQ nK nS nHt nF
  splitD splitQ splitK splitS splitF splitHt geoShield)
open ZK60.Exec.Block.Join.R13H.Look (Dm Sg SgIx PrIx TbIx AlkR13 TR13 hN_shield lookCfg_shield
  bLk pLk lkLe lkDe lkQe lkKe lkSe lkFe lkAtR lkTupR expTupR actTupR sgTupR lkLen)
open ZK60.Exec.Slot.Build.Lay (LkW)

/-! ## 1. `FullBndTableSpec` & Boundary Table Continuity -/

section FullBoundary

/-- Full 128-token × 3072-dim boundary table contract (`38` rows, `logN = 14`, `Q = 256`,
`ColsHonest` at `(lagK 14, 256, cosetPt (rootFp 16), 2^16)`). -/
structure FullBndTableSpec (y : shieldS0.Pos → ℤ) (TB : Table) : Prop where
  rows_len : TB.rows.length = 38
  cols_len : ∀ j, (TB.cols j).length = 38
  cols_canon : ∀ j, ∀ w ∈ TB.cols j, w.Canon
  cols_honest : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) TB
  entry_eq : ∀ (r : Fin 32) (col : Fin 16384),
    (TB.rows.getD r.val []).getD col.val Fp.zero =
      if hc : (r.val * 16384 + col.val) % 4096 < 3072 then
        Fp.fromI64 (y (⟨(r.val * 16384 + col.val) / 4096,
            show (r.val * 16384 + col.val) / 4096 < 128 by have := r.isLt; have := col.isLt; omega⟩,
          ⟨(r.val * 16384 + col.val) % 4096, hc⟩))
      else Fp.zero

/-- Project `FullBndTableSpec y TB` directly to Stage OUT-C's `BndTableSpec y row TB`. -/
theorem FullBndTableSpec.toBndTableSpec {y : shieldS0.Pos → ℤ} {TB : Table}
    (h : FullBndTableSpec y TB) (row : shieldS0.Tok) : BndTableSpec y row TB where
  rows_len := h.rows_len
  cols_len := h.cols_len
  cols_canon := h.cols_canon
  cols_honest := by rw [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num]; exact h.cols_honest
  row_eq := fun r col ht => by
    rw [h.entry_eq r col]
    by_cases hc : (r.val * 16384 + col.val) % 4096 < 3072
    · rw [dite_eq_left hc, dite_eq_left hc]; congr 2; exact Prod.ext (Fin.ext ht) rfl
    · rw [dite_eq_right hc, dite_eq_right hc]

/-- Reading `tabMat 38 14 TB.rows` at `(r, col)` under `FullBndTableSpec y TB` and `i16 y`. -/
theorem FullBndTableSpec.tabMat_at {y : shieldS0.Pos → ℤ} {TB : Table}
    (h : FullBndTableSpec y TB) (hy : ∀ p, i16 (y p)) (r : Fin 32) (col : Fin 16384) :
    tabMat (K := shdP_K) 38 14 TB.rows ⟨r.val, by have := r.isLt; omega⟩ ⟨col.val, col.isLt⟩ =
      if hc : (r.val * 16384 + col.val) % 4096 < 3072 then
        algebraMap GF shdP_K
          ((y (⟨(r.val * 16384 + col.val) / 4096,
              show (r.val * 16384 + col.val) / 4096 < 128 by have := r.isLt; have := col.isLt; omega⟩,
            ⟨(r.val * 16384 + col.val) % 4096, hc⟩) : ℤ) : GF)
      else 0 := by
  unfold tabMat; dsimp only; rw [h.entry_eq r col]
  by_cases hc : (r.val * 16384 + col.val) % 4096 < 3072
  · rw [dite_eq_left hc, dite_eq_left hc]
    obtain ⟨hlo, hhi⟩ := hy _
    rw [Fp.toGF_fromI64 _ (by norm_num at hlo ⊢; linarith) (by norm_num at hhi ⊢; linarith)]
  · rw [dite_eq_right hc, dite_eq_right hc, fp_zero_toGF, map_zero]

/-- Stage IN-C's output boundary table `shdP_incTB Rp x rnd` satisfies `FullBndTableSpec` for `x_0`. -/
theorem shdP_incTB_fullBndTableSpec (Rp : ClassifyRunPublicP shieldS0)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) :
    FullBndTableSpec (fun p => Rp.inp.emb (x p.1) p.2) (shdP_incTB Rp x rnd) where
  rows_len := shdP_incTB_rows_len Rp x rnd
  cols_len := fun j =>
    (mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j).trans (mkRows_length 38 16384 256 _ _)
  cols_canon := mkPcsTable_cols_canon 14 2 256 (by norm_num) _ _
  cols_honest := by
    have h := shdP_incTB_colsHonest Rp x rnd
    rwa [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] at h
  entry_eq := fun r col => by
    change ((mkRows 38 16384 256 (shdP_incTBData Rp x rnd) rnd.bPads).getD r.val []).getD col.val Fp.zero = _
    rw [mkRows_data_getD 38 16384 256 _ _ ⟨r.val, by have := r.isLt; omega⟩ col]
    unfold shdP_incTBData; dsimp only; rw [dite_eq_left r.isLt]

/-- Canonical per-block boundary table `TB` (`38` rows, `logN = 14`, `lr = 2`, `Q = 256`),
definitionally equal to `shdP_outcBndTable y rnd` so Block 25 shares `TB_25` with Stage OUT-C by `rfl`. -/
noncomputable def shdP_blkBndTable (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BndRand) : Table := by
  have _ := hy
  exact shdP_outcBndTable y rnd

/-- `shdP_blkBndTable y hy rnd` satisfies `FullBndTableSpec y`. -/
theorem shdP_blkBndTable_spec (y : shieldS0.Pos → ℤ) (hy : ∀ p, i16 (y p)) (rnd : BndRand) :
    FullBndTableSpec y (shdP_blkBndTable y hy rnd) where
  rows_len := mkRows_length 38 16384 256 _ _
  cols_len := fun j =>
    (mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j).trans (mkRows_length 38 16384 256 _ _)
  cols_canon := mkPcsTable_cols_canon 14 2 256 (by norm_num) _ _
  cols_honest := by
    have h := mkPcsTable_colsHonest shdP_U 14 2 256 (by norm_num)
      (mkRows 38 16384 256 (shdP_outcBndData y rnd) rnd.bPads) rnd.bSalts
    rwa [show (2 : ℕ) ^ 14 * 2 ^ 2 = 2 ^ 16 by norm_num] at h
  entry_eq := fun r col => by
    change ((mkRows 38 16384 256 (shdP_outcBndData y rnd) rnd.bPads).getD r.val []).getD col.val Fp.zero = _
    rw [mkRows_data_getD 38 16384 256 _ _ ⟨r.val, by have := r.isLt; omega⟩ col]
    unfold shdP_outcBndData; dsimp only; rw [dite_eq_left r.isLt]

end FullBoundary

/-! ## 2. 26-Layer Accessors & State Trajectory Extraction -/

section StateTrajectory

/-- Shieldstral layer `k < 26` from `shieldExport`. -/
def shdP_layer (k : ℕ) (hk : k < 26) : ShieldLayer :=
  shieldExport[k]'(by rw [shieldExport_l17.1]; exact hk)

theorem shdP_layer_mem (k : ℕ) (hk : k < 26) : shdP_layer k hk ∈ shieldExport :=
  List.getElem_mem (by rw [shieldExport_l17.1]; exact hk)

/-- Block `k < 26`'s public data cast to `BlockPublic (shieldShape (shdP_layer k hk))`,
matching `shdP_Pk0_eq_blkParams` definitionally. -/
def shdP_blkPub (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    BlockPublic (shieldShape (shdP_layer k hk)) :=
  let b := Rp.blks[k]'(by rw [shdP_blks_length hR]; exact hk)
  cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) (shdP_blk_cal_eq hR k hk)) b.pub

private theorem blockPublic_valid_cast {c₁ c₂ : BlockCal} (h : c₁ = c₂)
    (p : BlockPublic (c₁.over shieldS0)) (hp : p.Valid) :
    (cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) h) p).Valid := by
  subst h; exact hp

private theorem blockSpec_cast {c₁ c₂ : BlockCal} (h : c₁ = c₂)
    (p : BlockPublic (c₁.over shieldS0)) (x : shieldS0.Pos → ℤ) :
    blockSpec (cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) h) p) x = blockSpec p x := by
  subst h; rfl

theorem shdP_blkPub_valid (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (k : ℕ) (hk : k < 26) :
    (shdP_blkPub Rp hR k hk).Valid :=
  blockPublic_valid_cast (shdP_blk_cal_eq hR k hk) _ (hweights _ (List.getElem_mem _))

/-- `runSpecP` distributes over list append. -/
theorem runSpecP_append {S0 : BlockShape} :
    ∀ (bs₁ bs₂ : List (RunBlock S0)) (x : S0.Pos → ℤ),
      runSpecP (bs₁ ++ bs₂) x = (runSpecP bs₁ x).bind (fun y => runSpecP bs₂ y)
  | [], _, _ => rfl
  | b :: bs₁, bs₂, x => by
    show (blockSpec b.pub x).bind (fun y => runSpecP (bs₁ ++ bs₂) y) =
      ((blockSpec b.pub x).bind (fun y => runSpecP bs₁ y)).bind (fun y => runSpecP bs₂ y)
    cases blockSpec b.pub x with
    | none => rfl
    | some y => exact runSpecP_append bs₁ bs₂ y

private theorem list_take_succ_eq_append {α : Type} :
    ∀ (l : List α) (k : ℕ) (hk : k < l.length),
      l.take (k + 1) = l.take k ++ [l[k]'hk]
  | [], k, hk => by have hf : False := Nat.not_lt_zero k hk; cases hf
  | _ :: _, 0, _ => rfl
  | a :: l, k + 1, hk => by
    have hk' : k < l.length := by simpa using hk
    simpa only [List.take_succ_cons, List.cons_append, List.getElem_cons_succ] using
      congrArg (a :: ·) (list_take_succ_eq_append l k hk')

private theorem runSpecP_adm_eq {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ}
    (hx : (classifyModelP Rp).admissible x) :
    ∃ y25, runSpecP Rp.blks (fun p => Rp.inp.emb (x p.1) p.2) = some y25 := by
  obtain ⟨v, hv⟩ := hx
  change classifySpecP Rp x = some v at hv
  unfold classifySpecP at hv
  obtain ⟨x0, hin, hv⟩ := obind_eq_some.mp hv
  obtain ⟨y25, hrun, -⟩ := obind_eq_some.mp hv
  rw [(inSpec_some hin).2] at hrun
  exact ⟨y25, hrun⟩

/-- Exact 27-state trajectory `x_0, x_1, ..., x_26` across the 26 Shieldstral blocks. -/
noncomputable def shdP_blkState (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    Fin 27 → (shieldS0.Pos → ℤ) := by
  have _ := hR; have _ := hweights; have _ := hinPub; have _ := hx
  exact fun k => (runSpecP (Rp.blks.take k.val) (fun p => Rp.inp.emb (x p.1) p.2)).getD (fun _ => 0)

theorem shdP_blkState_prefix_some (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (k : Fin 27) :
    runSpecP (Rp.blks.take k.val) (fun p => Rp.inp.emb (x p.1) p.2)
      = some (shdP_blkState Rp hR hweights hinPub x hx k) := by
  obtain ⟨y25, hrun⟩ := runSpecP_adm_eq hx
  rw [← List.take_append_drop k.val Rp.blks, runSpecP_append] at hrun
  obtain ⟨sk, hsk, -⟩ := obind_eq_some.mp hrun
  have hget : shdP_blkState Rp hR hweights hinPub x hx k = sk := by
    change (runSpecP (Rp.blks.take k.val) _).getD (fun _ => 0) = sk
    rw [hsk]; rfl
  rw [hget]; exact hsk

theorem shdP_blkState_zero (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (t : shieldS0.Tok) (c : shieldS0.Wid) :
    shdP_blkState Rp hR hweights hinPub x hx 0 (t, c) = Rp.inp.emb (x t) c := rfl

theorem shdP_blkState_i16 (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    ∀ (k : Fin 27) (p : shieldS0.Pos), i16 (shdP_blkState Rp hR hweights hinPub x hx k p) := fun k =>
  runSpecP_class (Rp.blks.take k.val) (fun p => Rp.inp.emb (x p.1) p.2)
    (shdP_blkState Rp hR hweights hinPub x hx k)
    (fun p => hinPub.emb (x p.1) p.2)
    (shdP_blkState_prefix_some Rp hR hweights hinPub x hx k)

theorem shdP_blkState_step (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (k : ℕ) (hk : k < 26) :
    blockSpec (shdP_blkPub Rp hR k hk) (shdP_blkState Rp hR hweights hinPub x hx ⟨k, by omega⟩)
      = some (shdP_blkState Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩) := by
  have hk_len : k < Rp.blks.length := by rw [shdP_blks_length hR]; exact hk
  have h1 := shdP_blkState_prefix_some Rp hR hweights hinPub x hx ⟨k, by omega⟩
  have h2 := shdP_blkState_prefix_some Rp hR hweights hinPub x hx ⟨k + 1, by omega⟩
  rw [list_take_succ_eq_append Rp.blks k hk_len, runSpecP_append, h1] at h2
  have hsingle : ∀ (b : RunBlock shieldS0) (y : shieldS0.Pos → ℤ),
      runSpecP [b] y = blockSpec b.pub y := fun b y => by unfold runSpecP; cases blockSpec b.pub y <;> rfl
  change runSpecP [Rp.blks[k]'hk_len] _ = _ at h2
  rw [hsingle] at h2
  exact (blockSpec_cast (shdP_blk_cal_eq hR k hk) (Rp.blks[k]'hk_len).pub _).trans h2

theorem shdP_blkState_last (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (hOut : Rp.out.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) :
    shdP_blkState Rp hR hweights hinPub x hx ⟨26, by omega⟩ = (outcWitness_of_adm Rp hOut x hx).y25 := by
  set w := outcWitness_of_adm Rp hOut x hx
  have hrun : runSpecP Rp.blks (fun p => Rp.inp.emb (x p.1) p.2) = some w.y25 := by
    rw [← (inSpec_some w.hin).2]; exact w.hrun
  have htake : Rp.blks.take 26 = Rp.blks := List.take_of_length_le (by rw [shdP_blks_length hR])
  change (runSpecP (Rp.blks.take 26) _).getD (fun _ => 0) = w.y25
  rw [htake, hrun]; rfl

end StateTrajectory

/-! ## 3. Per-Block `BlkWitness` & `R13Data` Extraction (`blkWitness_of_spec`) -/

section BlockWitness

/-! ### 3a. Byte-limb decomposition helpers on `GF` -/

/-- `k`-th byte limb of a `GF` element's canonical representative (`0..255`). -/
def gfByte (n : ℕ) (x : GF) (k : Fin n) : GF :=
  (((x.val / 2 ^ (8 * k.val)) % 256 : ℕ) : GF)

theorem inRange8_zero : InRange 8 (0 : GF) := ⟨0, le_rfl, by norm_num, by simp⟩

theorem gfByte_inRange8 (n : ℕ) (x : GF) (k : Fin n) : InRange 8 (gfByte n x k) :=
  ⟨(((x.val / 2 ^ (8 * k.val)) % 256 : ℕ) : ℤ), by positivity,
    by exact_mod_cast Nat.mod_lt (x.val / 2 ^ (8 * k.val)) (show 0 < 256 by norm_num),
    by simp only [gfByte, Int.cast_natCast]⟩

theorem gfByte_codeTable (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG n : ℕ) (x : GF) (k : Fin n) :
    CodeTable r13Fams exp act nG (rangeQuery (tagW 8) (gfByte n x k)) :=
  (codeTable_range_iff r13Fams_ok exp act nG mem_r13Fams _).mpr (gfByte_inRange8 n x k)

theorem lv_gfByte {C : Type} {n b : ℕ} (hbn : b ≤ 8 * n) (hn63 : 8 * n ≤ 63)
    (f : C → GF) (x : C) (hx : InRange b (f x)) :
    lv (fun k c => gfByte n (f c) k) x = f x := by
  have hv' : (f x).val < 2 ^ (8 * n) :=
    lt_of_lt_of_le (val_lt_of_inRange (by omega) hx) (Nat.pow_le_pow_right (by norm_num) hbn)
  have hcast : ((∑ k ∈ Finset.range n, 2 ^ (8 * k) * (byteOf k (f x).val).val : ℕ) : GF)
      = (((f x).val : ℕ) : GF) := congrArg Nat.cast (sum_bytes_eq n (f x).val hv')
  rw [ZMod.natCast_zmod_val, Finset.sum_range, Nat.cast_sum] at hcast
  unfold lv; rw [← hcast]
  refine Finset.sum_congr rfl (fun k _ => ?_)
  rw [Nat.cast_mul, Nat.cast_pow, Nat.cast_ofNat, pow256]; rfl

theorem gfByte_three_sum (x : GF) (hx : InRange 24 x) :
    gfByte 3 x 0 + 2 ^ 8 * gfByte 3 x 1 + 2 ^ 16 * gfByte 3 x 2 = x := by
  have h := lv_gfByte (n := 3) (b := 24) (by norm_num) (by norm_num) (fun _ : Unit => x) () hx
  rwa [lv_three] at h

theorem gfByte_pin_inRange8 {n b : ℕ} (hb1 : 8 * n < b) (hb2 : b ≤ 8 * (n + 1)) (hn63 : 8 * (n + 1) ≤ 63)
    (x : GF) (hx : InRange b x) :
    InRange 8 ((2 : GF) ^ (8 * (n + 1) - b) * gfByte (n + 1) x (Fin.last n)) := by
  have hv : x.val < 2 ^ (b - 8 * n) * 2 ^ (8 * n) := by
    rw [← pow_add, show b - 8 * n + 8 * n = b by omega]; exact val_lt_of_inRange (by omega) hx
  have hq : x.val / 2 ^ (8 * n) < 2 ^ (b - 8 * n) := Nat.div_lt_of_lt_mul (by rw [mul_comm]; exact hv)
  have hq256 : x.val / 2 ^ (8 * n) < 256 :=
    lt_of_lt_of_le hq (show 2 ^ (b - 8 * n) ≤ 2 ^ 8 from Nat.pow_le_pow_right (by norm_num) (by omega))
  have hmul : 2 ^ (8 * (n + 1) - b) * (x.val / 2 ^ (8 * n)) < 2 ^ 8 := by
    have h1 := Nat.mul_lt_mul_of_pos_left hq (Nat.two_pow_pos (8 * (n + 1) - b))
    rwa [← pow_add, show 8 * (n + 1) - b + (b - 8 * n) = 8 by omega] at h1
  refine ⟨((2 ^ (8 * (n + 1) - b) * (x.val / 2 ^ (8 * n)) : ℕ) : ℤ), by positivity, by exact_mod_cast hmul, ?_⟩
  unfold gfByte
  rw [Fin.val_last, Nat.mod_eq_of_lt hq256, Int.cast_natCast, Nat.cast_mul, Nat.cast_pow, Nat.cast_ofNat]

theorem gfByte_pin_codeTable (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    {n b : ℕ} (hb1 : 8 * n < b) (hb2 : b ≤ 8 * (n + 1)) (hn63 : 8 * (n + 1) ≤ 63)
    (x : GF) (hx : InRange b x) :
    CodeTable r13Fams exp act nG (rangeQuery (tagW 8) ((2 : GF) ^ (8 * (n + 1) - b) * gfByte (n + 1) x (Fin.last n))) :=
  (codeTable_range_iff r13Fams_ok exp act nG mem_r13Fams _).mpr (gfByte_pin_inRange8 hb1 hb2 hn63 x hx)

/-! ### 3b. Bit-cube axis inverses, padding wrappers, and sum reindexing -/

def blkTokInv (c : Fin 7 → Bool) : Fin 128 := ⟨Exec.msbIndex 7 c, Exec.msbIndex_lt 7 c⟩
def blkGrpInv (c : Fin 3 → Bool) : Fin 8 := ⟨Exec.msbIndex 3 c, Exec.msbIndex_lt 3 c⟩
def blkHdInv (d : Fin 7 → Bool) : Bool × Fin 64 :=
  (d ⟨0, by norm_num⟩, ⟨Exec.msbIndex 6 (fun j : Fin 6 => d ⟨j.val + 1, by omega⟩), Exec.msbIndex_lt 6 _⟩)
def blkSlotInv (s : (Fin 3 → Bool) × (Fin 2 → Bool)) : Fin 32 :=
  ⟨4 * Exec.msbIndex 3 s.1 + Exec.msbIndex 2 s.2,
    by have := Exec.msbIndex_lt 3 s.1; have := Exec.msbIndex_lt 2 s.2; omega⟩

theorem blkTokInv_emb (Ly : ShieldLayer) (t : (shieldShape Ly).Tok) : blkTokInv ((shdP_bitLay Ly).tok.emb t) = t :=
  Fin.ext (Exec.msbIndex_msbBits 7 t.val t.isLt)
theorem emb_blkTokInv (Ly : ShieldLayer) (c : Fin 7 → Bool) : (shdP_bitLay Ly).tok.emb (blkTokInv c) = c :=
  Exec.msbBits_msbIndex 7 c
theorem blkGrpInv_emb (Ly : ShieldLayer) (g : Fin 8) : blkGrpInv ((shdP_bitLay Ly).grp.emb g) = g :=
  Fin.ext (Exec.msbIndex_msbBits 3 g.val g.isLt)
theorem emb_blkGrpInv (Ly : ShieldLayer) (c : Fin 3 → Bool) : (shdP_bitLay Ly).grp.emb (blkGrpInv c) = c :=
  Exec.msbBits_msbIndex 3 c

theorem blkHdInv_emb (Ly : ShieldLayer) (x : Bool × Fin 64) : blkHdInv ((shdP_bitLay Ly).hd.emb x) = x := by
  rcases x with ⟨b, k⟩
  have ht : (fun j : Fin 6 => (shdP_bitLay Ly).hd.emb (b, k) (⟨j.val + 1, by omega⟩ : Fin 7)) = Exec.msbBits 6 k.val := by
    funext j
    show (if j.val + 1 = 0 then b else Exec.msbBits 6 k.val ⟨j.val + 1 - 1, by omega⟩) = _
    rw [ite_eq_right (by omega)]
    exact congrArg (Exec.msbBits 6 k.val) (Fin.ext (by dsimp only; omega))
  refine Prod.ext rfl (Fin.ext ?_)
  exact (congrArg (Exec.msbIndex 6) ht).trans (Exec.msbIndex_msbBits 6 k.val k.isLt)

theorem emb_blkHdInv (Ly : ShieldLayer) (d : Fin 7 → Bool) : (shdP_bitLay Ly).hd.emb (blkHdInv d) = d := by
  refine funext (fun i : Fin 7 => ?_)
  show (if i.val = 0 then (blkHdInv d).1 else Exec.msbBits 6 (blkHdInv d).2.val ⟨i.val - 1, by omega⟩) = d i
  by_cases hi : i.val = 0
  · rw [ite_eq_left hi, show i = ⟨0, by norm_num⟩ from Fin.ext hi]; rfl
  · rw [ite_eq_right hi]
    have hb := congrFun (Exec.msbBits_msbIndex 6 (fun j : Fin 6 => d ⟨j.val + 1, by omega⟩)) ⟨i.val - 1, by omega⟩
    dsimp only at hb
    dsimp only [blkHdInv]
    rw [hb]
    exact congrArg d (Fin.ext (by dsimp only; omega))

theorem blkHdInv_flip (Ly : ShieldLayer) (d : Fin 7 → Bool) :
    blkHdInv ((shdP_bitLay Ly).flip d) = (!(blkHdInv d).1, (blkHdInv d).2) := by
  have hfl : ((shdP_bitLay Ly).flip d : Fin 7 → Bool) =
      Function.update d (⟨0, by norm_num⟩ : Fin 7) (!d ⟨0, by norm_num⟩) := rfl
  refine (congrArg blkHdInv hfl).trans ?_
  refine Prod.ext ?_ (Fin.ext ?_)
  · exact Function.update_self (⟨0, by norm_num⟩ : Fin 7) (!d ⟨0, by norm_num⟩) d
  · show Exec.msbIndex 6 (fun j : Fin 6 =>
          Function.update d (⟨0, by norm_num⟩ : Fin 7) (!d ⟨0, by norm_num⟩) ⟨j.val + 1, by omega⟩) =
        Exec.msbIndex 6 (fun j : Fin 6 => d ⟨j.val + 1, by omega⟩)
    refine congrArg (Exec.msbIndex 6) (funext fun j => ?_)
    have hne : (⟨j.val + 1, by omega⟩ : Fin 7) ≠ ⟨0, by norm_num⟩ := fun h => by
      have hval : j.val + 1 = 0 := congrArg Fin.val h
      omega
    exact Function.update_of_ne hne (!d ⟨0, by norm_num⟩) d

theorem blkSlotInv_slot (Ly : ShieldLayer) (h : Fin 32) : blkSlotInv ((shdP_bitLay Ly).slot h) = h := by
  apply Fin.ext
  show 4 * Exec.msbIndex 3 (Exec.msbBits 3 (h.val / 4)) + Exec.msbIndex 2 (Exec.msbBits 2 (h.val % 4)) = h.val
  rw [Exec.msbIndex_msbBits 3 (h.val / 4) (by omega), Exec.msbIndex_msbBits 2 (h.val % 4) (by omega), Nat.div_add_mod]

theorem slot_blkSlotInv (Ly : ShieldLayer) (s : (Fin 3 → Bool) × (Fin 2 → Bool)) :
    (shdP_bitLay Ly).slot (blkSlotInv s) = s := by
  rcases s with ⟨s1, s2⟩
  have h2 : Exec.msbIndex 2 s2 < 4 := Exec.msbIndex_lt 2 s2
  refine Prod.ext ?_ ?_
  · show Exec.msbBits 3 ((4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) / 4) = s1
    rw [show (4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) / 4 = Exec.msbIndex 3 s1 by omega, Exec.msbBits_msbIndex 3]
  · show Exec.msbBits 2 ((4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) % 4) = s2
    rw [show (4 * Exec.msbIndex 3 s1 + Exec.msbIndex 2 s2) % 4 = Exec.msbIndex 2 s2 by omega, Exec.msbBits_msbIndex 2]

theorem shieldGrp_blkSlotInv (s : (Fin 3 → Bool) × (Fin 2 → Bool)) : shieldGrp (blkSlotInv s) = blkGrpInv s.1 := by
  have := Exec.msbIndex_lt 2 s.2
  exact Fin.ext (show (4 * Exec.msbIndex 3 s.1 + Exec.msbIndex 2 s.2) / 4 = Exec.msbIndex 3 s.1 by omega)

private def onD (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) : GF :=
  if h : Exec.msbIndex 12 x.2 < 3072 then f (blkTokInv x.1, ⟨Exec.msbIndex 12 x.2, h⟩) else 0
private def onF (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) : GF :=
  if h : Exec.msbIndex 14 x.2 < 9216 then f (blkTokInv x.1, ⟨Exec.msbIndex 14 x.2, h⟩) else 0
private def qPt (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      ((CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
        CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    (shieldShape Ly).Tok × (shieldShape Ly).QC := (blkTokInv x.1, (blkSlotInv x.2.1, blkHdInv x.2.2))
private def kPt (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    (shieldShape Ly).Tok × (shieldShape Ly).KC := (blkTokInv x.1, (blkGrpInv x.2.1, blkHdInv x.2.2))
private def sPt (Ly : ShieldLayer)
    (x : (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
      CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) :
    Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok :=
  (blkSlotInv x.1, blkTokInv x.2.1, blkTokInv x.2.2)
private def htPt (Ly : ShieldLayer)
    (r : (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
      CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) : Fin (shieldShape Ly).H × (shieldShape Ly).Tok :=
  (blkSlotInv r.1, blkTokInv r.2)

private theorem onD_eq_p (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 x.2 < 3072) :
    onD Ly f x = f (blkTokInv x.1, ⟨Exec.msbIndex 12 x.2, h⟩) := dite_eq_left h
private theorem onD_eq (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 cw < 3072) :
    onD Ly f (ct, cw) = f (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) := onD_eq_p Ly f (ct, cw) h
private theorem onD_pad_p (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 x.2 < 3072) : onD Ly f x = 0 := dite_eq_right h
private theorem onD_pad (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 cw < 3072) : onD Ly f (ct, cw) = 0 := onD_pad_p Ly f (ct, cw) h

private theorem onF_eq_p (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 14 x.2 < 9216) :
    onF Ly f x = f (blkTokInv x.1, ⟨Exec.msbIndex 14 x.2, h⟩) := dite_eq_left h
private theorem onF_eq (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 14 cf < 9216) :
    onF Ly f (ct, cf) = f (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩) := onF_eq_p Ly f (ct, cf) h
private theorem onF_pad_p (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 x.2 < 9216) : onF Ly f x = 0 := dite_eq_right h
private theorem onF_pad (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 cf < 9216) : onF Ly f (ct, cf) = 0 := onF_pad_p Ly f (ct, cf) h

private theorem onD_dPos (Ly : ShieldLayer) (f : shieldS0.Pos → GF) (p : shieldS0.Pos) :
    onD Ly f ((shdP_bitLay Ly).dPos p) = f p := by
  have hp2 : p.2.val < 3072 := p.2.isLt
  have hidx : Exec.msbIndex 12 ((shdP_bitLay Ly).dPos p).2 = p.2.val :=
    Exec.msbIndex_msbBits 12 p.2.val (by omega)
  exact (onD_eq_p Ly f ((shdP_bitLay Ly).dPos p) (lt_of_eq_of_lt hidx hp2)).trans
    (congrArg f (Prod.ext (blkTokInv_emb Ly p.1) (Fin.ext hidx)))

private theorem onF_fPos (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (p : (shieldShape Ly).Tok × (shieldShape Ly).Hid) : onF Ly f ((shdP_bitLay Ly).fPos p) = f p := by
  have hp2 : p.2.val < 9216 := p.2.isLt
  have hidx : Exec.msbIndex 14 ((shdP_bitLay Ly).fPos p).2 = p.2.val :=
    Exec.msbIndex_msbBits 14 p.2.val (by omega)
  exact (onF_eq_p Ly f ((shdP_bitLay Ly).fPos p) (lt_of_eq_of_lt hidx hp2)).trans
    (congrArg f (Prod.ext (blkTokInv_emb Ly p.1) (Fin.ext hidx)))

private theorem onD_wid (Ly : ShieldLayer) (f : shieldS0.Pos → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (i : (shieldShape Ly).Wid) :
    onD Ly f (ct, (shdP_bitLay Ly).wid.emb i) = f (blkTokInv ct, i) :=
  (congrArg (onD Ly f) (Prod.ext (emb_blkTokInv Ly ct).symm rfl :
    (ct, (shdP_bitLay Ly).wid.emb i) = (shdP_bitLay Ly).dPos (blkTokInv ct, i))).trans
    (onD_dPos Ly f (blkTokInv ct, i))

private theorem onF_hid (Ly : ShieldLayer) (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF)
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (k : (shieldShape Ly).Hid) :
    onF Ly f (ct, (shdP_bitLay Ly).hid.emb k) = f (blkTokInv ct, k) :=
  (congrArg (onF Ly f) (Prod.ext (emb_blkTokInv Ly ct).symm rfl :
    (ct, (shdP_bitLay Ly).hid.emb k) = (shdP_bitLay Ly).fPos (blkTokInv ct, k))).trans
    (onF_fPos Ly f (blkTokInv ct, k))

private theorem qPos_qPt (Ly : ShieldLayer) (x) : (shdP_bitLay Ly).qPos (qPt Ly x) = x :=
  Prod.ext (emb_blkTokInv Ly x.1) (Prod.ext (slot_blkSlotInv Ly x.2.1) (emb_blkHdInv Ly x.2.2))
private theorem kPos_kPt (Ly : ShieldLayer) (x) : (shdP_bitLay Ly).kPos (kPt Ly x) = x :=
  Prod.ext (emb_blkTokInv Ly x.1) (Prod.ext (emb_blkGrpInv Ly x.2.1) (emb_blkHdInv Ly x.2.2))
private theorem sPos_sPt (Ly : ShieldLayer) (x) : (shdP_bitLay Ly).sPos (sPt Ly x) = x :=
  Prod.ext (slot_blkSlotInv Ly x.1) (Prod.ext (emb_blkTokInv Ly x.2.1) (emb_blkTokInv Ly x.2.2))
private theorem qPt_qPos (Ly : ShieldLayer) (p : (shieldShape Ly).Tok × (shieldShape Ly).QC) :
    qPt Ly ((shdP_bitLay Ly).qPos p) = p := by
  unfold qPt; dsimp only
  exact Prod.ext (blkTokInv_emb Ly p.1) (Prod.ext (blkSlotInv_slot Ly p.2.1) (blkHdInv_emb Ly p.2.2))
private theorem kPt_kPos (Ly : ShieldLayer) (p : (shieldShape Ly).Tok × (shieldShape Ly).KC) :
    kPt Ly ((shdP_bitLay Ly).kPos p) = p := by
  unfold kPt; dsimp only
  exact Prod.ext (blkTokInv_emb Ly p.1) (Prod.ext (blkGrpInv_emb Ly p.2.1) (blkHdInv_emb Ly p.2.2))
private theorem sPt_sPos (Ly : ShieldLayer) (p : Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok) :
    sPt Ly ((shdP_bitLay Ly).sPos p) = p := by
  unfold sPt; dsimp only
  exact Prod.ext (blkSlotInv_slot Ly p.1) (Prod.ext (blkTokInv_emb Ly p.2.1) (blkTokInv_emb Ly p.2.2))
private theorem qPt_flip (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      ((CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
        CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    qPt Ly (x.1, (x.2.1, (shdP_bitLay Ly).flip x.2.2)) = flipQ (qPt Ly x) := by
  unfold qPt flipQ; dsimp only
  exact congrArg (fun d : Bool × Fin 64 => (blkTokInv x.1, (blkSlotInv x.2.1, d))) (blkHdInv_flip Ly x.2.2)
private theorem kPt_flip (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    kPt Ly (x.1, (x.2.1, (shdP_bitLay Ly).flip x.2.2)) = flipK (kPt Ly x) := by
  unfold kPt flipK; dsimp only
  exact congrArg (fun d : Bool × Fin 64 => (blkTokInv x.1, (blkGrpInv x.2.1, d))) (blkHdInv_flip Ly x.2.2)
private theorem qPt_snd_emb (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      ((CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
        CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    x.2 = ((shdP_bitLay Ly).slot (qPt Ly x).2.1, (shdP_bitLay Ly).hd.emb (qPt Ly x).2.2) := by
  unfold qPt; dsimp only
  exact Prod.ext (slot_blkSlotInv Ly x.2.1).symm (emb_blkHdInv Ly x.2.2).symm
private theorem kPt_snd_emb (Ly : ShieldLayer)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    x.2 = ((shdP_bitLay Ly).grp.emb (kPt Ly x).2.1, (shdP_bitLay Ly).hd.emb (kPt Ly x).2.2) := by
  unfold kPt; dsimp only
  exact Prod.ext (emb_blkGrpInv Ly x.2.1).symm (emb_blkHdInv Ly x.2.2).symm

private theorem w16Pub_gD_pos (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 cw < 3072) : (shdP_w16Pub Ly Pb).gD (ct, cw) = 1 :=
  (congrArg (shdP_w16Pub Ly Pb).gD (Prod.ext (emb_blkTokInv Ly ct).symm (Exec.msbBits_msbIndex 12 cw).symm :
    (ct, cw) = (shdP_bitLay Ly).dPos (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩))).trans
    ((shdP_w16Pub Ly Pb).gD_one _)
private structure ValBox (α : Type) where
  val : α

private theorem valBox_val_mk {α : Type} (x : α) : ValBox.val (ValBox.mk x) = x := rfl

private def gFBox (Ly : ShieldLayer) :
    ValBox (CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF) :=
  ⟨fun p => if Exec.msbIndex 14 p.2 < 9216 then (1 : GF) else 0⟩

private theorem w16Pub_gF_eq_box (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    (shdP_w16Pub Ly Pb).gF = (gFBox Ly).val := rfl

private theorem gFBox_eq (Ly : ShieldLayer) :
    gFBox Ly = ⟨fun p => if Exec.msbIndex 14 p.2 < 9216 then (1 : GF) else 0⟩ := rfl

private theorem w16Pub_gD_neg (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 cw < 3072) : (shdP_w16Pub Ly Pb).gD (ct, cw) = 0 :=
  (shdP_w16Pub Ly Pb).gD_pad ct cw fun i hi =>
    have hi3 : i.val < 3072 := i.isLt
    h (lt_of_eq_of_lt ((congrArg (Exec.msbIndex 12) hi.symm).trans
      (Exec.msbIndex_msbBits 12 i.val (by omega))) hi3)
private theorem w16Pub_gF_pos (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 14 cf < 9216) : (shdP_w16Pub Ly Pb).gF (ct, cf) = 1 :=
  (congrArg (shdP_w16Pub Ly Pb).gF (Prod.ext (emb_blkTokInv Ly ct).symm (Exec.msbBits_msbIndex 14 cf).symm :
    (ct, cf) = (shdP_bitLay Ly).fPos (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩))).trans
    ((shdP_w16Pub Ly Pb).gF_one _)
private theorem w16Pub_gF_def (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    (shdP_w16Pub Ly Pb).gF =
      fun p : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly) =>
        if Exec.msbIndex 14 p.2 < 9216 then (1 : GF) else 0 :=
  (w16Pub_gF_eq_box Ly Pb).trans ((congrArg ValBox.val (gFBox_eq Ly)).trans (valBox_val_mk _))
private theorem w16Pub_gF_neg_p (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (p : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 p.2 < 9216) : (shdP_w16Pub Ly Pb).gF p = 0 :=
  (congrFun (w16Pub_gF_def Ly Pb) p).trans (ite_eq_right h)
private theorem w16Pub_gF_neg (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 cf < 9216) : (shdP_w16Pub Ly Pb).gF (ct, cf) = 0 :=
  w16Pub_gF_neg_p Ly Pb (ct, cf) h
private theorem w16Pub_gamA (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 cw < 3072) :
    (shdP_w16Pub Ly Pb).gamA (ct, cw) = (Pb.gA ⟨Exec.msbIndex 12 cw, h⟩ : GF) :=
  (congrArg (shdP_w16Pub Ly Pb).gamA (Prod.ext (emb_blkTokInv Ly ct).symm (Exec.msbBits_msbIndex 12 cw).symm :
    (ct, cw) = (shdP_bitLay Ly).dPos (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩))).trans
    ((shdP_w16Pub Ly Pb).gamA_emb _)
private theorem w16Pub_gamM (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 cw < 3072) :
    (shdP_w16Pub Ly Pb).gamM (ct, cw) = (Pb.gM ⟨Exec.msbIndex 12 cw, h⟩ : GF) :=
  (congrArg (shdP_w16Pub Ly Pb).gamM (Prod.ext (emb_blkTokInv Ly ct).symm (Exec.msbBits_msbIndex 12 cw).symm :
    (ct, cw) = (shdP_bitLay Ly).dPos (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩))).trans
    ((shdP_w16Pub Ly Pb).gamM_emb _)
private theorem w16Pub_cosT (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (x) :
    (shdP_w16Pub Ly Pb).cosT x = (Pb.cos (qPt Ly x).1 (qPt Ly x).2.2.2 : GF) := by
  conv_lhs => rw [← qPos_qPt Ly x]
  exact (shdP_w16Pub Ly Pb).cosT_emb (qPt Ly x)
private theorem w16Pub_sinT (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (x) :
    (shdP_w16Pub Ly Pb).sinT x = ((ropeSgn (qPt Ly x).2.2.1 * Pb.sin (qPt Ly x).1 (qPt Ly x).2.2.2 : ℤ) : GF) := by
  conv_lhs => rw [← qPos_qPt Ly x]
  exact (shdP_w16Pub Ly Pb).sinT_emb (qPt Ly x)
private theorem w16Pub_cosK (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (x) :
    (shdP_w16Pub Ly Pb).cosK x = (Pb.cos (kPt Ly x).1 (kPt Ly x).2.2.2 : GF) := by
  conv_lhs => rw [← kPos_kPt Ly x]
  exact (shdP_w16Pub Ly Pb).cosK_emb (kPt Ly x)
private theorem w16Pub_sinK (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (x) :
    (shdP_w16Pub Ly Pb).sinK x = ((ropeSgn (kPt Ly x).2.2.1 * Pb.sin (kPt Ly x).1 (kPt Ly x).2.2.2 : ℤ) : GF) := by
  conv_lhs => rw [← kPos_kPt Ly x]
  exact (shdP_w16Pub Ly Pb).sinK_emb (kPt Ly x)
private theorem w16Pub_mask (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (x) :
    (shdP_w16Pub Ly Pb).mask x = maskF (sPt Ly x).2.1 (sPt Ly x).2.2 := by
  conv_lhs => rw [← sPos_sPt Ly x]
  exact (shdP_w16Pub Ly Pb).mask_emb (sPt Ly x)

private def grpColBox (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ValBox ((Fin 7 → Bool) × (Fin 14 → Bool) → GF) :=
  ⟨fun p => if h : Exec.msbIndex 14 p.2 < 9216 then (Pb.grpF ⟨Exec.msbIndex 14 p.2, h⟩ : GF) else 0⟩

private theorem shdP_w16Pub_grpCol_eq_box (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).grpCol : (Fin 7 → Bool) × (Fin 14 → Bool) → GF) = (grpColBox Ly Pb).val := rfl

private theorem grpColBox_eq (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    grpColBox Ly Pb =
      ⟨fun p => if h : Exec.msbIndex 14 p.2 < 9216 then (Pb.grpF ⟨Exec.msbIndex 14 p.2, h⟩ : GF) else 0⟩ := rfl

private theorem shdP_w16Pub_grpCol_def (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).grpCol : (Fin 7 → Bool) × (Fin 14 → Bool) → GF) =
      fun p : (Fin 7 → Bool) × (Fin 14 → Bool) =>
        if h : Exec.msbIndex 14 p.2 < 9216 then (Pb.grpF ⟨Exec.msbIndex 14 p.2, h⟩ : GF) else 0 :=
  (shdP_w16Pub_grpCol_eq_box Ly Pb).trans ((congrArg ValBox.val (grpColBox_eq Ly Pb)).trans (valBox_val_mk _))

theorem shdP_w16Pub_grpCol_pad (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (p : (Fin 7 → Bool) × (Fin 14 → Bool)) (h : ¬ Exec.msbIndex 14 p.2 < 9216) :
    (shdP_w16Pub Ly Pb).grpCol p = 0 :=
  (congrFun (shdP_w16Pub_grpCol_def Ly Pb) p).trans (dite_eq_right h)

private theorem w16Pub_Wo_pad_cw (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (qc : (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
      CdR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 cw < 3072) : (shdP_w16Pub Ly Pb).Wo qc cw = 0 := dite_eq_right h

private def wgBox (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ValBox ((Fin 12 → Bool) → (Fin 14 → Bool) → GF) :=
  ⟨fun cw cf =>
    if hw : Exec.msbIndex 12 cw < 3072 then
      if hf : Exec.msbIndex 14 cf < 9216 then
        let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
        ((Pb.wg ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mg f : ℤ) : ℤ) : GF)
      else 0
    else 0⟩

private theorem w16Pub_Wg_eq_box (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wg : (Fin 12 → Bool) → (Fin 14 → Bool) → GF) = (wgBox Ly Pb).val := rfl

private theorem wgBox_eq (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    wgBox Ly Pb =
      ⟨fun cw cf =>
        if hw : Exec.msbIndex 12 cw < 3072 then
          if hf : Exec.msbIndex 14 cf < 9216 then
            let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
            ((Pb.wg ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mg f : ℤ) : ℤ) : GF)
          else 0
        else 0⟩ := rfl

private theorem w16Pub_Wg_def (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wg : (Fin 12 → Bool) → (Fin 14 → Bool) → GF) =
      fun (cw : Fin 12 → Bool) (cf : Fin 14 → Bool) =>
        if hw : Exec.msbIndex 12 cw < 3072 then
          if hf : Exec.msbIndex 14 cf < 9216 then
            let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
            ((Pb.wg ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mg f : ℤ) : ℤ) : GF)
          else 0
        else 0 :=
  (w16Pub_Wg_eq_box Ly Pb).trans ((congrArg ValBox.val (wgBox_eq Ly Pb)).trans (valBox_val_mk _))

private theorem w16Pub_Wg_pad_cf (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 cf < 9216) : (shdP_w16Pub Ly Pb).Wg cw cf = 0 := by
  refine (congrFun (congrFun (w16Pub_Wg_def Ly Pb) cw) cf).trans ?_
  dsimp only
  by_cases hw : Exec.msbIndex 12 cw < 3072
  · rw [dite_eq_left hw]; exact dite_eq_right h
  · exact dite_eq_right hw

private def wuBox (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ValBox ((Fin 12 → Bool) → (Fin 14 → Bool) → GF) :=
  ⟨fun cw cf =>
    if hw : Exec.msbIndex 12 cw < 3072 then
      if hf : Exec.msbIndex 14 cf < 9216 then
        let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
        ((Pb.wu ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mu f : ℤ) : ℤ) : GF)
      else 0
    else 0⟩

private theorem w16Pub_Wu_eq_box (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wu : (Fin 12 → Bool) → (Fin 14 → Bool) → GF) = (wuBox Ly Pb).val := rfl

private theorem wuBox_eq (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    wuBox Ly Pb =
      ⟨fun cw cf =>
        if hw : Exec.msbIndex 12 cw < 3072 then
          if hf : Exec.msbIndex 14 cf < 9216 then
            let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
            ((Pb.wu ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mu f : ℤ) : ℤ) : GF)
          else 0
        else 0⟩ := rfl

private theorem w16Pub_Wu_def (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wu : (Fin 12 → Bool) → (Fin 14 → Bool) → GF) =
      fun (cw : Fin 12 → Bool) (cf : Fin 14 → Bool) =>
        if hw : Exec.msbIndex 12 cw < 3072 then
          if hf : Exec.msbIndex 14 cf < 9216 then
            let f : (shieldShape Ly).Hid := ⟨Exec.msbIndex 14 cf, hf⟩
            ((Pb.wu ⟨Exec.msbIndex 12 cw, hw⟩ f * (Pb.mu f : ℤ) : ℤ) : GF)
          else 0
        else 0 :=
  (w16Pub_Wu_eq_box Ly Pb).trans ((congrArg ValBox.val (wuBox_eq Ly Pb)).trans (valBox_val_mk _))

private theorem w16Pub_Wu_pad_cf (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 cf < 9216) : (shdP_w16Pub Ly Pb).Wu cw cf = 0 := by
  refine (congrFun (congrFun (w16Pub_Wu_def Ly Pb) cw) cf).trans ?_
  dsimp only
  by_cases hw : Exec.msbIndex 12 cw < 3072
  · rw [dite_eq_left hw]; exact dite_eq_right h
  · exact dite_eq_right hw

private def wdBox (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ValBox ((Fin 14 → Bool) → (Fin 12 → Bool) → GF) :=
  ⟨fun cf cw =>
    if hf : Exec.msbIndex 14 cf < 9216 then
      if hw : Exec.msbIndex 12 cw < 3072 then
        let j : (shieldShape Ly).Wid := ⟨Exec.msbIndex 12 cw, hw⟩
        ((Pb.wd ⟨Exec.msbIndex 14 cf, hf⟩ j * (Pb.md j : ℤ) : ℤ) : GF)
      else 0
    else 0⟩

private theorem w16Pub_Wd_eq_box (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wd : (Fin 14 → Bool) → (Fin 12 → Bool) → GF) = (wdBox Ly Pb).val := rfl

private theorem wdBox_eq (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    wdBox Ly Pb =
      ⟨fun cf cw =>
        if hf : Exec.msbIndex 14 cf < 9216 then
          if hw : Exec.msbIndex 12 cw < 3072 then
            let j : (shieldShape Ly).Wid := ⟨Exec.msbIndex 12 cw, hw⟩
            ((Pb.wd ⟨Exec.msbIndex 14 cf, hf⟩ j * (Pb.md j : ℤ) : ℤ) : GF)
          else 0
        else 0⟩ := rfl

private theorem w16Pub_Wd_def (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) :
    ((shdP_w16Pub Ly Pb).Wd : (Fin 14 → Bool) → (Fin 12 → Bool) → GF) =
      fun (cf : Fin 14 → Bool) (cw : Fin 12 → Bool) =>
        if hf : Exec.msbIndex 14 cf < 9216 then
          if hw : Exec.msbIndex 12 cw < 3072 then
            let j : (shieldShape Ly).Wid := ⟨Exec.msbIndex 12 cw, hw⟩
            ((Pb.wd ⟨Exec.msbIndex 14 cf, hf⟩ j * (Pb.md j : ℤ) : ℤ) : GF)
          else 0
        else 0 :=
  (w16Pub_Wd_eq_box Ly Pb).trans ((congrArg ValBox.val (wdBox_eq Ly Pb)).trans (valBox_val_mk _))

private theorem w16Pub_Wd_pad_cw (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 cw < 3072) : (shdP_w16Pub Ly Pb).Wd cf cw = 0 := by
  refine (congrFun (congrFun (w16Pub_Wd_def Ly Pb) cf) cw).trans ?_
  dsimp only
  by_cases hf : Exec.msbIndex 14 cf < 9216
  · rw [dite_eq_left hf]; exact dite_eq_right h
  · exact dite_eq_right hf

private theorem lv_onD_gfByte (Ly : ShieldLayer) {n b : ℕ} (hbn : b ≤ 8 * n) (hn63 : 8 * n ≤ 63)
    (f : shieldS0.Pos → GF) (hf : ∀ p, InRange b (f p))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 12 cw < 3072) :
    lv (fun k => onD Ly (fun p => gfByte n (f p) k)) (ct, cw) = f (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) := by
  unfold lv
  simp_rw [show ∀ k : Fin n, onD Ly (fun p => gfByte n (f p) k) (ct, cw) =
    gfByte n (f (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)) k from fun _ => onD_eq Ly _ ct cw h]
  exact lv_gfByte hbn hn63 (fun _ : Unit => f (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)) () (hf _)

private theorem lv_onF_gfByte (Ly : ShieldLayer) {n b : ℕ} (hbn : b ≤ 8 * n) (hn63 : 8 * n ≤ 63)
    (f : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF) (hf : ∀ p, InRange b (f p))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : Exec.msbIndex 14 cf < 9216) :
    lv (fun k => onF Ly (fun p => gfByte n (f p) k)) (ct, cf) = f (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩) := by
  unfold lv
  simp_rw [show ∀ k : Fin n, onF Ly (fun p => gfByte n (f p) k) (ct, cf) =
    gfByte n (f (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩)) k from fun _ => onF_eq Ly _ ct cf h]
  exact lv_gfByte hbn hn63 (fun _ : Unit => f (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩)) () (hf _)

private theorem sum_cw_eq (Ly : ShieldLayer) (f : CwR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF)
    (hpad : ∀ c, ¬ Exec.msbIndex 12 c < 3072 → f c = 0) :
    ∑ c, f c = ∑ i : (shieldShape Ly).Wid, f ((shdP_bitLay Ly).wid.emb i) :=
  sum_emb (shdP_bitLay Ly).wid f (fun c hc => hpad c (fun hlt => hc ⟨Exec.msbIndex 12 c, hlt⟩ (Exec.msbBits_msbIndex 12 c)))

private theorem sum_cf_eq (Ly : ShieldLayer) (f : CfR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF)
    (hpad : ∀ c, ¬ Exec.msbIndex 14 c < 9216 → f c = 0) :
    ∑ c, f c = ∑ k : (shieldShape Ly).Hid, f ((shdP_bitLay Ly).hid.emb k) :=
  sum_emb (shdP_bitLay Ly).hid f (fun c hc => hpad c (fun hlt => hc ⟨Exec.msbIndex 14 c, hlt⟩ (Exec.msbBits_msbIndex 14 c)))

private theorem sum_ct_eq (Ly : ShieldLayer) (f : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF) :
    ∑ c, f c = ∑ t : (shieldShape Ly).Tok, f ((shdP_bitLay Ly).tok.emb t) :=
  sum_emb (shdP_bitLay Ly).tok f (fun c hc => by have hf : False := hc (blkTokInv c) (emb_blkTokInv Ly c); cases hf)

private theorem sum_cd_eq (Ly : ShieldLayer) (f : CdR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF) :
    ∑ c, f c = ∑ d : (shieldShape Ly).HD, f ((shdP_bitLay Ly).hd.emb d) :=
  sum_emb (shdP_bitLay Ly).hd f (fun c hc => by have hf : False := hc (blkHdInv c) (emb_blkHdInv Ly c); cases hf)

private theorem sum_qc_eq (Ly : ShieldLayer)
    (f : (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) × CdR (Exec.Block.DefR13.cfgShieldR13 Ly) → GF) :
    ∑ c, f c = ∑ qc : (shieldShape Ly).QC, f ((shdP_bitLay Ly).slot qc.1, (shdP_bitLay Ly).hd.emb qc.2) :=
  (Equiv.sum_comp
    { toFun := fun qc : (shieldShape Ly).QC => ((shdP_bitLay Ly).slot qc.1, (shdP_bitLay Ly).hd.emb qc.2)
      invFun := fun c => (blkSlotInv c.1, blkHdInv c.2)
      left_inv := fun qc => Prod.ext (blkSlotInv_slot Ly qc.1) (blkHdInv_emb Ly qc.2)
      right_inv := fun c => Prod.ext (slot_blkSlotInv Ly c.1) (emb_blkHdInv Ly c.2) } f).symm

private def limbPlaneOfIdx (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF) (idx : ℕ) : GF :=
  if h : idx / 128 < 9 then
    l ⟨(idx / 128) / 3, by omega⟩ ⟨(idx / 128) % 3, by omega⟩ (Exec.msbBits 7 (idx % 128))
  else 0

/-- Full `Dom::L` limb plane (`16384` entries) packing `l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF`
on `< 1152` and `0` on padded positions `≥ 1152`. -/
def limbPlaneOf (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF) (b : Fin 14 → Bool) : GF :=
  limbPlaneOfIdx l (Exec.msbIndex 14 b)

private theorem limbPlaneOfIdx_active (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF) (i k : Fin 3) (t : Fin 7 → Bool) :
    limbPlaneOfIdx l ((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t) = l i k t := by
  have ht := Exec.msbIndex_lt 7 t; have hi := i.isLt; have hk := k.isLt
  unfold limbPlaneOfIdx
  rw [dite_eq_left (by omega)]
  have hi' : (⟨(((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t) / 128) / 3, by omega⟩ : Fin 3) = i :=
    Fin.ext (by dsimp only; omega)
  have hk' : (⟨(((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t) / 128) % 3, by omega⟩ : Fin 3) = k :=
    Fin.ext (by dsimp only; omega)
  rw [hi', hk', show ((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t) % 128 = Exec.msbIndex 7 t by omega,
    Exec.msbBits_msbIndex 7 t]

private theorem limbPlaneOfIdx_byte (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF)
    (hl : ∀ i k t, InRange 8 (l i k t)) (idx : ℕ) : InRange 8 (limbPlaneOfIdx l idx) := by
  unfold limbPlaneOfIdx
  by_cases h : idx / 128 < 9
  · rw [dite_eq_left h]; exact hl _ _ _
  · rw [dite_eq_right h]; exact inRange8_zero

private theorem limbPlaneOfIdx_pad (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF)
    (idx : ℕ) (h : ¬ idx / 128 < 9) : limbPlaneOfIdx l idx = 0 :=
  dite_eq_right h

theorem limbPlaneOf_active (l : Fin 3 → Fin 3 → (Fin 7 → Bool) → GF) (i k : Fin 3) (t : Fin 7 → Bool) :
    limbPlaneOf l (Exec.msbBits 14 ((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t)) = l i k t := by
  have ht := Exec.msbIndex_lt 7 t; have hi := i.isLt; have hk := k.isLt
  rw [limbPlaneOf, Exec.msbIndex_msbBits 14 _ (by omega)]
  exact limbPlaneOfIdx_active l i k t

/-! ### 3c. Zero-padding predicates, `BlkWitness`, and `blkWitness_of_spec` -/

/-- All 39 `Dom::D` witness planes vanish on padded width positions (`msbIndex 12 cw ≥ 3072`). -/
structure BlkPadD {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1) : Prop where
  X : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.X (ct, cw) = 0
  Y : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.Y (ct, cw) = 0
  AO : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.AO (ct, cw) = 0
  X1 : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.X1 (ct, cw) = 0
  YM : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.YM (ct, cw) = 0
  Z : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.Z (ct, cw) = 0
  X2 : ∀ ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.X2 (ct, cw) = 0
  xl : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.xl k (ct, cw) = 0
  yl : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.yl k (ct, cw) = 0
  aol : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.aol k (ct, cw) = 0
  x1l : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.x1l k (ct, cw) = 0
  yml : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.yml k (ct, cw) = 0
  zl : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.zl k (ct, cw) = 0
  x2l : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.x2l k (ct, cw) = 0
  nr : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.nr k (ct, cw) = 0
  ns : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.ns k (ct, cw) = 0
  mr : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.mr k (ct, cw) = 0
  ms : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.ms k (ct, cw) = 0
  ral : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.ral k (ct, cw) = 0
  rdl : ∀ k ct cw, ¬ Exec.msbIndex 12 cw < 3072 → E.rdl k (ct, cw) = 0

/-- All 16 `Dom::F` witness planes vanish on padded hidden positions (`msbIndex 14 cf ≥ 9216`). -/
structure BlkPadF {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1) : Prop where
  G : ∀ ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.G (ct, cf) = 0
  A : ∀ ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.A (ct, cf) = 0
  U : ∀ ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.U (ct, cf) = 0
  H : ∀ ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.H (ct, cf) = 0
  rgl : ∀ k ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.rgl k (ct, cf) = 0
  ul : ∀ k ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.ul k (ct, cf) = 0
  ru : ∀ k ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.ru k (ct, cf) = 0
  hl : ∀ k ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.hl k (ct, cf) = 0
  rh : ∀ k ct cf, ¬ Exec.msbIndex 14 cf < 9216 → E.rh k (ct, cf) = 0

/-- Both `Dom::L` limb planes vanish on padded positions (`msbIndex 14 b / 128 ≥ 9`). -/
structure BlkPadL (limbA limbM : (Fin 14 → Bool) → GF) : Prop where
  limbA : ∀ b, ¬ Exec.msbIndex 14 b / 128 < 9 → limbA b = 0
  limbM : ∀ b, ¬ Exec.msbIndex 14 b / 128 < 9 → limbM b = 0

/-- Complete R13 witness bundle for one Shieldstral layer `(Ly, Pb)` mapping `xIn` to `xOut`. -/
structure BlkWitness (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (xIn xOut : shieldS0.Pos → ℤ) where
  E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
        (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
        (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1
  limbA : (Fin 14 → Bool) → GF
  limbM : (Fin 14 → Bool) → GF
  hLimbA : ∀ (i k : Fin 3) (t : Fin 7 → Bool),
    limbA (Exec.msbBits 14 ((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t)) = E.la i k t
  hLimbM : ∀ (i k : Fin 3) (t : Fin 7 → Bool),
    limbM (Exec.msbBits 14 ((3 * i.val + k.val) * 128 + Exec.msbIndex 7 t)) = E.lm i k t
  hLimbA_byte : ∀ b : Fin 14 → Bool, InRange 8 (limbA b)
  hLimbM_byte : ∀ b : Fin 14 → Bool, InRange 8 (limbM b)
  hRels : R13Rels (shieldShape Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) E
  hLook : R13Lookups (shieldShape Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) E
  hPadD : BlkPadD E
  hPadF : BlkPadF E
  hPadL : BlkPadL limbA limbM
  hIO : (∀ p, E.X (shieldDPos0 p) = (xIn p : GF)) ∧ (∀ p, E.X2 (shieldDPos0 p) = (xOut p : GF))
  hAct0 : Pb.act 0 2048 = 0
  hLy : Ly ∈ shieldExport
  hPb : Pb.Valid

theorem BlkWitness.X_eq {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (ct : Fin 7 → Bool) (cw : Fin 12 → Bool) :
    w.E.X (ct, cw) = if h : Exec.msbIndex 12 cw < 3072 then (xIn (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) : GF) else 0 := by
  by_cases h : Exec.msbIndex 12 cw < 3072
  · rw [dite_eq_left h]
    have hp : (ct, cw) = shieldDPos0 (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) :=
      (Prod.ext (Exec.msbBits_msbIndex 7 ct) (Exec.msbBits_msbIndex 12 cw)).symm
    exact (congrArg w.E.X hp).trans (w.hIO.1 _)
  · rw [dite_eq_right h]; exact w.hPadD.X ct cw h

theorem BlkWitness.X2_eq {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (ct : Fin 7 → Bool) (cw : Fin 12 → Bool) :
    w.E.X2 (ct, cw) = if h : Exec.msbIndex 12 cw < 3072 then (xOut (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) : GF) else 0 := by
  by_cases h : Exec.msbIndex 12 cw < 3072
  · rw [dite_eq_left h]
    have hp : (ct, cw) = shieldDPos0 (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩) :=
      (Prod.ext (Exec.msbBits_msbIndex 7 ct) (Exec.msbBits_msbIndex 12 cw)).symm
    exact (congrArg w.E.X2 hp).trans (w.hIO.2 _)
  · rw [dite_eq_right h]; exact w.hPadD.X2 ct cw h

private structure BlkSatExt (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (xIn xOut : shieldS0.Pos → ℤ) where
  hLy : Ly ∈ shieldExport
  hPb : Pb.Valid
  hAct0 : Pb.act 0 2048 = 0
  hW : R13Windows (shieldShape Ly) 1
  w : BlockWit (shieldShape Ly)
  hw : BlockSat Pb (fun p => (xIn p : GF)) (fun p => (xOut p : GF)) w
  dsqAw : (shieldShape Ly).Tok → GF
  a1Aw : (shieldShape Ly).Tok → GF
  a2Aw : (shieldShape Ly).Tok → GF
  hNA_isq : ∀ t, IsqrtRel (((shieldShape Ly).ceps : GF) + ∑ i, (xIn (t, i) : GF) * (xIn (t, i) : GF))
    (w.dA t) (dsqAw t) (a1Aw t) (a2Aw t)
  hdA24 : ∀ t, InRange 24 (w.dA t)
  ha1A24 : ∀ t, InRange 24 (a1Aw t)
  ha2A24 : ∀ t, InRange 24 (a2Aw t)
  nrw : shieldS0.Pos → GF
  nsw : shieldS0.Pos → GF
  hNA_div : ∀ p, NormDivRel (shieldShape Ly).tn ((shieldShape Ly).cnA : GF) (Pb.gA p.2 : GF)
    (xIn p : GF) (w.dA p.1) (w.Y p) (nrw p) (nsw p)
  hnr24 : ∀ p, InRange 24 (nrw p)
  hns24 : ∀ p, InRange 24 (nsw p)
  hYw : ∀ p, Word16 (w.Y p)
  dsqMw : (shieldShape Ly).Tok → GF
  a1Mw : (shieldShape Ly).Tok → GF
  a2Mw : (shieldShape Ly).Tok → GF
  hNM_isq : ∀ t, IsqrtRel (((shieldShape Ly).ceps : GF) + ∑ i, w.X1 (t, i) * w.X1 (t, i))
    (w.dM t) (dsqMw t) (a1Mw t) (a2Mw t)
  hdM24 : ∀ t, InRange 24 (w.dM t)
  ha1M24 : ∀ t, InRange 24 (a1Mw t)
  ha2M24 : ∀ t, InRange 24 (a2Mw t)
  mrw : shieldS0.Pos → GF
  msw : shieldS0.Pos → GF
  hNM_div : ∀ p, NormDivRel (shieldShape Ly).tn ((shieldShape Ly).cnM : GF) (Pb.gM p.2 : GF)
    (w.X1 p) (w.dM p.1) (w.YM p) (mrw p) (msw p)
  hmr24 : ∀ p, InRange 24 (mrw p)
  hms24 : ∀ p, InRange 24 (msw p)
  hYMw : ∀ p, Word16 (w.YM p)
  rqw : (shieldShape Ly).Tok × (shieldShape Ly).QC → GF
  hQrel : ∀ p, HostRel (shieldShape Ly).sq
    (∑ i, w.Y (p.1, i) * ((Pb.wq i p.2 * (Pb.mq p.2 : ℤ) : ℤ) : GF)) (w.Q p) (rqw p)
  hQw : ∀ p, Word16 (w.Q p)
  hQrem : ∀ p, InRange (shieldShape Ly).sq (rqw p)
  rkw : (shieldShape Ly).Tok × (shieldShape Ly).KC → GF
  hKrel : ∀ p, HostRel (shieldShape Ly).sk
    (∑ i, w.Y (p.1, i) * ((Pb.wk i p.2 * (Pb.mK p.2 : ℤ) : ℤ) : GF)) (w.K p) (rkw p)
  hKw : ∀ p, Word16 (w.K p)
  hKrem : ∀ p, InRange (shieldShape Ly).sk (rkw p)
  rvw : (shieldShape Ly).Tok × (shieldShape Ly).KC → GF
  hVrel : ∀ p, HostRel (shieldShape Ly).sv
    (∑ i, w.Y (p.1, i) * ((Pb.wv i p.2 * (Pb.mv p.2 : ℤ) : ℤ) : GF)) (w.V p) (rvw p)
  hVw : ∀ p, Word16 (w.V p)
  hVrem : ∀ p, InRange (shieldShape Ly).sv (rvw p)
  rqrw : (shieldShape Ly).Tok × (shieldShape Ly).QC → GF
  hQRrel : ∀ p, RopeRel (Pb.cos p.1 p.2.2.2 : GF) ((ropeSgn p.2.2.1 * Pb.sin p.1 p.2.2.2 : ℤ) : GF)
    (w.Q p) (w.Q (flipQ p)) (w.QR p) (rqrw p)
  hQRw : ∀ p, Word16 (w.QR p)
  hQRrem : ∀ p, InRange 7 (rqrw p)
  rkrw : (shieldShape Ly).Tok × (shieldShape Ly).KC → GF
  hKRrel : ∀ p, RopeRel (Pb.cos p.1 p.2.2.2 : GF) ((ropeSgn p.2.2.1 * Pb.sin p.1 p.2.2.2 : ℤ) : GF)
    (w.K p) (w.K (flipK p)) (w.KR p) (rkrw p)
  hKRw : ∀ p, Word16 (w.KR p)
  hKRrem : ∀ p, InRange 7 (rkrw p)
  rsw : Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok → GF
  hSrel : ∀ p, HostRel (shieldShape Ly).ss
    (∑ c : (shieldShape Ly).HD, w.QR (p.2.1, (p.1, c)) * w.KR (p.2.2, ((shieldShape Ly).grp p.1, c))) (w.S8 p) (rsw p)
  hSw : ∀ p, WordS8 (w.S8 p)
  hSrem : ∀ p, InRange (shieldShape Ly).ss (rsw p)
  row : (shieldShape Ly).Tok × (shieldShape Ly).QC → GF
  hOrel : ∀ p, HostRel (shieldShape Ly).spv
    (∑ j : (shieldShape Ly).Tok, w.PP (p.2.1, p.1, j) * w.V (j, ((shieldShape Ly).grp p.2.1, p.2.2))) (w.O p) (row p)
  hOw : ∀ p, Word16 (w.O p)
  hOrem : ∀ p, InRange (shieldShape Ly).spv (row p)
  raow : shieldS0.Pos → GF
  hAOrel : ∀ p, HostRel (shieldShape Ly).sao
    (∑ c : (shieldShape Ly).QC, w.O (p.1, c) * ((Pb.wo c p.2 * (Pb.mo p.2 : ℤ) : ℤ) : GF)) (w.AO p) (raow p)
  hAOw : ∀ p, Word16 (w.AO p)
  hAOrem : ∀ p, InRange (shieldShape Ly).sao (raow p)
  rgw : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF
  hGrel : ∀ p, HostRel (shieldShape Ly).sgate
    (∑ i, w.YM (p.1, i) * ((Pb.wg i p.2 * (Pb.mg p.2 : ℤ) : ℤ) : GF)) (w.Gt p) (rgw p)
  hGrem : ∀ p, InRange (shieldShape Ly).sgate (rgw p)
  hGact : ∀ p, ActTable Pb.act (shieldShape Ly).nG (actQuery (w.Gt p) (w.Ac p) (Pb.grpF p.2))
  ruw : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF
  hUrel : ∀ p, HostRel (shieldShape Ly).sup
    (∑ i, w.YM (p.1, i) * ((Pb.wu i p.2 * (Pb.mu p.2 : ℤ) : ℤ) : GF)) (w.U p) (ruw p)
  hUw : ∀ p, Word16 (w.U p)
  hUrem : ∀ p, InRange (shieldShape Ly).sup (ruw p)
  rhw : (shieldShape Ly).Tok × (shieldShape Ly).Hid → GF
  hHrel : ∀ p, ProdRel (shieldShape Ly).sprod (w.Ac p) (w.U p) (w.Hh p) (rhw p)
  hH24 : ∀ p, InRange 24 (w.Hh p + 2 ^ 23)
  hHrem : ∀ p, InRange (shieldShape Ly).sprod (rhw p)
  rdw : shieldS0.Pos → GF
  hZrel : ∀ p, HostRel (shieldShape Ly).sdown
    (∑ k : (shieldShape Ly).Hid, w.Hh (p.1, k) * ((Pb.wd k p.2 * (Pb.md p.2 : ℤ) : ℤ) : GF)) (w.Z p) (rdw p)
  hZw : ∀ p, Word16 (w.Z p)
  hZrem : ∀ p, InRange (shieldShape Ly).sdown (rdw p)
  srw : Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok → GF
  sgw : Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok → GF
  hSM_div : ∀ p, SoftmaxDivRel (maskF p.2.1 p.2.2 * w.E p * 2 ^ (shieldShape Ly).fp) (w.PP p)
    (w.SUM (p.1, p.2.1)) (srw p) (sgw p)
  hsr16 : ∀ p, InRange (shieldShape Ly).wrho (srw p)
  hsg16 : ∀ p, InRange (shieldShape Ly).wrho (sgw p)
  hP13 : ∀ p, InRange ((shieldShape Ly).fp + 1) (w.PP p)

private theorem blkSatExt_exists (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport)
    (Pb : BlockPublic (shieldShape Ly)) (hPb : Pb.Valid) (hAct0 : Pb.act 0 2048 = 0)
    (xIn xOut : shieldS0.Pos → ℤ) (hxIn : ∀ p, i16 (xIn p)) (hspec : blockSpec Pb xIn = some xOut) :
    Nonempty (BlkSatExt Ly Pb xIn xOut) := by
  have hS : (shieldShape Ly).Valid := shield_shapes_valid Ly hLy
  have hW : R13Windows (shieldShape Ly) 1 := shield_shapes_r13 Ly hLy
  have hxOut : ∀ p, i16 (xOut p) := blockSpec_class Pb xIn xOut hspec
  obtain ⟨w, hw⟩ :=
    (blockSat_iff hS Pb hPb xIn hxIn (fun p => (xOut p : GF))).mpr ⟨xOut, hspec, hxOut, fun _ => rfl⟩
  choose dsqAw a1Aw a2Aw hNA_isq hdA24 ha1A24 ha2A24 using fun t => (hw.normA t).1
  choose nrw nsw hNA_div hnrW hnsW using fun p : shieldS0.Pos => ((hw.normA p.1).2 p.2).1
  choose dsqMw a1Mw a2Mw hNM_isq hdM24 ha1M24 ha2M24 using fun t => (hw.normM t).1
  choose mrw msw hNM_div hmrW hmsW using fun p : shieldS0.Pos => ((hw.normM p.1).2 p.2).1
  choose rqw hQrel hQw hQrem using hw.q
  choose rkw hKrel hKw hKrem using hw.k
  choose rvw hVrel hVw hVrem using hw.v
  choose rqrw hQRrel hQRw hQRrem using hw.qr
  choose rkrw hKRrel hKRw hKRrem using hw.kr
  choose rsw hSrel hSw hSrem using hw.score
  choose row hOrel hOw hOrem using hw.pv
  choose raow hAOrel hAOw hAOrem using hw.ao
  choose rgw hGrel hGrem hGact using hw.gate
  choose ruw hUrel hUw hUrem using hw.up
  choose rhw hHrel hHw hHrem using hw.prod
  choose rdw hZrel hZw hZrem using hw.down
  choose srw sgw hSM_div hsrW hsgW using fun p : Fin (shieldShape Ly).H × (shieldShape Ly).Tok × (shieldShape Ly).Tok =>
    ((hw.softmax (p.1, p.2.1)).2.2.2.2.2 p.2.2).1
  have hH24 : ∀ p, InRange 24 (w.Hh p + 2 ^ 23) := fun p => by
    obtain ⟨q, hlo, hhi, hq⟩ := (word24_iff (w.Hh p)).mp (hHw p)
    exact ⟨q + 2 ^ 23, by linarith, by norm_num at hlo hhi ⊢; linarith, by rw [hq]; push_cast; ring⟩
  exact ⟨{
    hLy := hLy, hPb := hPb, hAct0 := hAct0, hW := hW, w := w, hw := hw,
    dsqAw := dsqAw, a1Aw := a1Aw, a2Aw := a2Aw, hNA_isq := hNA_isq,
    hdA24 := hdA24, ha1A24 := ha1A24, ha2A24 := ha2A24,
    nrw := nrw, nsw := nsw, hNA_div := hNA_div,
    hnr24 := fun p => (remW16_iff 24 (nrw p)).mp (hnrW p),
    hns24 := fun p => (remW16_iff 24 (nsw p)).mp (hnsW p),
    hYw := fun p => ((hw.normA p.1).2 p.2).2,
    dsqMw := dsqMw, a1Mw := a1Mw, a2Mw := a2Mw, hNM_isq := hNM_isq,
    hdM24 := hdM24, ha1M24 := ha1M24, ha2M24 := ha2M24,
    mrw := mrw, msw := msw, hNM_div := hNM_div,
    hmr24 := fun p => (remW16_iff 24 (mrw p)).mp (hmrW p),
    hms24 := fun p => (remW16_iff 24 (msw p)).mp (hmsW p),
    hYMw := fun p => ((hw.normM p.1).2 p.2).2,
    rqw := rqw, hQrel := hQrel, hQw := hQw, hQrem := fun p => (remW16_iff _ _).mp (hQrem p),
    rkw := rkw, hKrel := hKrel, hKw := hKw, hKrem := fun p => (remW16_iff _ _).mp (hKrem p),
    rvw := rvw, hVrel := hVrel, hVw := hVw, hVrem := fun p => (remW16_iff _ _).mp (hVrem p),
    rqrw := rqrw, hQRrel := hQRrel, hQRw := hQRw, hQRrem := fun p => (remW16_iff 7 _).mp (hQRrem p),
    rkrw := rkrw, hKRrel := hKRrel, hKRw := hKRw, hKRrem := fun p => (remW16_iff 7 _).mp (hKRrem p),
    rsw := rsw, hSrel := hSrel, hSw := hSw, hSrem := fun p => (remW16_iff _ _).mp (hSrem p),
    row := row, hOrel := hOrel, hOw := hOw, hOrem := fun p => (remW16_iff _ _).mp (hOrem p),
    raow := raow, hAOrel := hAOrel, hAOw := hAOw, hAOrem := fun p => (remW16_iff _ _).mp (hAOrem p),
    rgw := rgw, hGrel := hGrel, hGrem := fun p => (remW16_iff _ _).mp (hGrem p), hGact := hGact,
    ruw := ruw, hUrel := hUrel, hUw := hUw, hUrem := fun p => (remW16_iff _ _).mp (hUrem p),
    rhw := rhw, hHrel := hHrel, hH24 := hH24, hHrem := fun p => (remW16_iff _ _).mp (hHrem p),
    rdw := rdw, hZrel := hZrel, hZw := hZw, hZrem := fun p => (remW16_iff _ _).mp (hZrem p),
    srw := srw, sgw := sgw, hSM_div := hSM_div,
    hsr16 := fun p => (remW16_iff _ (srw p)).mp (hsrW p),
    hsg16 := fun p => (remW16_iff _ (sgw p)).mp (hsgW p),
    hP13 := fun p => ((hw.softmax (p.1, p.2.1)).2.2.2.2.2 p.2.2).2 }⟩

private def blkWitnessData {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1 :=
  { dA := fun ct => ext.w.dA (blkTokInv ct), dsqA := fun ct => ext.dsqAw (blkTokInv ct),
    dM := fun ct => ext.w.dM (blkTokInv ct), dsqM := fun ct => ext.dsqMw (blkTokInv ct),
    la := fun i k ct => gfByte 3
      (match i.val with | 0 => ext.w.dA (blkTokInv ct) | 1 => ext.a1Aw (blkTokInv ct) | _ => ext.a2Aw (blkTokInv ct)) k,
    lm := fun i k ct => gfByte 3
      (match i.val with | 0 => ext.w.dM (blkTokInv ct) | 1 => ext.a1Mw (blkTokInv ct) | _ => ext.a2Mw (blkTokInv ct)) k,
    X := onD Ly (fun p => (xIn p : GF)), Y := onD Ly ext.w.Y, AO := onD Ly ext.w.AO, X1 := onD Ly ext.w.X1,
    YM := onD Ly ext.w.YM, Z := onD Ly ext.w.Z, X2 := onD Ly (fun p => (xOut p : GF)),
    xl := fun k => onD Ly (fun p => gfByte 2 ((xIn p : GF) + 32768) k),
    yl := fun k => onD Ly (fun p => gfByte 2 (ext.w.Y p + 32768) k),
    aol := fun k => onD Ly (fun p => gfByte 2 (ext.w.AO p + 32768) k),
    x1l := fun k => onD Ly (fun p => gfByte 2 (ext.w.X1 p + 32768) k),
    yml := fun k => onD Ly (fun p => gfByte 2 (ext.w.YM p + 32768) k),
    zl := fun k => onD Ly (fun p => gfByte 2 (ext.w.Z p + 32768) k),
    x2l := fun k => onD Ly (fun p => gfByte 2 ((xOut p : GF) + 32768) k),
    nr := fun k => onD Ly (fun p => gfByte 3 (ext.nrw p) k), ns := fun k => onD Ly (fun p => gfByte 3 (ext.nsw p) k),
    mr := fun k => onD Ly (fun p => gfByte 3 (ext.mrw p) k), ms := fun k => onD Ly (fun p => gfByte 3 (ext.msw p) k),
    ral := fun k => onD Ly (fun p => gfByte 3 (ext.raow p) k), rdl := fun k => onD Ly (fun p => gfByte 3 (ext.rdw p) k),
    Q := fun x => ext.w.Q (qPt Ly x), QR := fun x => ext.w.QR (qPt Ly x), O := fun x => ext.w.O (qPt Ly x),
    ql := fun k x => gfByte 2 (ext.w.Q (qPt Ly x) + 32768) k,
    qrl := fun k x => gfByte 2 (ext.w.QR (qPt Ly x) + 32768) k,
    ol := fun k x => gfByte 2 (ext.w.O (qPt Ly x) + 32768) k, rql := fun k x => gfByte 2 (ext.rqw (qPt Ly x)) k,
    rqrl := fun k x => gfByte 1 (ext.rqrw (qPt Ly x)) k, ro := fun k x => gfByte 2 (ext.row (qPt Ly x)) k,
    K := fun x => ext.w.K (kPt Ly x), KR := fun x => ext.w.KR (kPt Ly x), V := fun x => ext.w.V (kPt Ly x),
    kl := fun k x => gfByte 2 (ext.w.K (kPt Ly x) + 32768) k,
    krl := fun k x => gfByte 2 (ext.w.KR (kPt Ly x) + 32768) k,
    vl := fun k x => gfByte 2 (ext.w.V (kPt Ly x) + 32768) k, rkl := fun k x => gfByte 2 (ext.rkw (kPt Ly x)) k,
    rkrl := fun k x => gfByte 1 (ext.rkrw (kPt Ly x)) k, rvl := fun k x => gfByte 2 (ext.rvw (kPt Ly x)) k,
    S8 := fun x => ext.w.S8 (sPt Ly x), ZSEL := fun x => ext.w.ZSEL (sPt Ly x), E := fun x => ext.w.E (sPt Ly x),
    PP := fun x => ext.w.PP (sPt Ly x), rsl := fun k x => gfByte 3 (ext.rsw (sPt Ly x)) k,
    pl := fun k x => gfByte 2 (ext.w.PP (sPt Ly x)) k, sr := fun k x => gfByte 2 (ext.srw (sPt Ly x)) k,
    sg := fun k x => gfByte 2 (ext.sgw (sPt Ly x)) k, MX := fun r => ext.w.MX (htPt Ly r),
    SUM := fun r => ext.w.SUM (htPt Ly r),
    G := onF Ly ext.w.Gt, A := onF Ly ext.w.Ac, U := onF Ly ext.w.U, H := onF Ly ext.w.Hh,
    rgl := fun k => onF Ly (fun p => gfByte 3 (ext.rgw p) k),
    ul := fun k => onF Ly (fun p => gfByte 2 (ext.w.U p + 32768) k),
    ru := fun k => onF Ly (fun p => gfByte 2 (ext.ruw p) k),
    hl := fun k => onF Ly (fun p => gfByte 3 (ext.w.Hh p + 2 ^ 23) k),
    rh := fun k => onF Ly (fun p => gfByte 2 (ext.rhw p) k) }

private theorem blkWitnessData_eq {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    blkWitnessData ext =
      { dA := fun ct => ext.w.dA (blkTokInv ct), dsqA := fun ct => ext.dsqAw (blkTokInv ct),
        dM := fun ct => ext.w.dM (blkTokInv ct), dsqM := fun ct => ext.dsqMw (blkTokInv ct),
        la := fun i k ct => gfByte 3
          (match i.val with | 0 => ext.w.dA (blkTokInv ct) | 1 => ext.a1Aw (blkTokInv ct) | _ => ext.a2Aw (blkTokInv ct)) k,
        lm := fun i k ct => gfByte 3
          (match i.val with | 0 => ext.w.dM (blkTokInv ct) | 1 => ext.a1Mw (blkTokInv ct) | _ => ext.a2Mw (blkTokInv ct)) k,
        X := onD Ly (fun p => (xIn p : GF)), Y := onD Ly ext.w.Y, AO := onD Ly ext.w.AO, X1 := onD Ly ext.w.X1,
        YM := onD Ly ext.w.YM, Z := onD Ly ext.w.Z, X2 := onD Ly (fun p => (xOut p : GF)),
        xl := fun k => onD Ly (fun p => gfByte 2 ((xIn p : GF) + 32768) k),
        yl := fun k => onD Ly (fun p => gfByte 2 (ext.w.Y p + 32768) k),
        aol := fun k => onD Ly (fun p => gfByte 2 (ext.w.AO p + 32768) k),
        x1l := fun k => onD Ly (fun p => gfByte 2 (ext.w.X1 p + 32768) k),
        yml := fun k => onD Ly (fun p => gfByte 2 (ext.w.YM p + 32768) k),
        zl := fun k => onD Ly (fun p => gfByte 2 (ext.w.Z p + 32768) k),
        x2l := fun k => onD Ly (fun p => gfByte 2 ((xOut p : GF) + 32768) k),
        nr := fun k => onD Ly (fun p => gfByte 3 (ext.nrw p) k), ns := fun k => onD Ly (fun p => gfByte 3 (ext.nsw p) k),
        mr := fun k => onD Ly (fun p => gfByte 3 (ext.mrw p) k), ms := fun k => onD Ly (fun p => gfByte 3 (ext.msw p) k),
        ral := fun k => onD Ly (fun p => gfByte 3 (ext.raow p) k), rdl := fun k => onD Ly (fun p => gfByte 3 (ext.rdw p) k),
        Q := fun x => ext.w.Q (qPt Ly x), QR := fun x => ext.w.QR (qPt Ly x), O := fun x => ext.w.O (qPt Ly x),
        ql := fun k x => gfByte 2 (ext.w.Q (qPt Ly x) + 32768) k,
        qrl := fun k x => gfByte 2 (ext.w.QR (qPt Ly x) + 32768) k,
        ol := fun k x => gfByte 2 (ext.w.O (qPt Ly x) + 32768) k, rql := fun k x => gfByte 2 (ext.rqw (qPt Ly x)) k,
        rqrl := fun k x => gfByte 1 (ext.rqrw (qPt Ly x)) k, ro := fun k x => gfByte 2 (ext.row (qPt Ly x)) k,
        K := fun x => ext.w.K (kPt Ly x), KR := fun x => ext.w.KR (kPt Ly x), V := fun x => ext.w.V (kPt Ly x),
        kl := fun k x => gfByte 2 (ext.w.K (kPt Ly x) + 32768) k,
        krl := fun k x => gfByte 2 (ext.w.KR (kPt Ly x) + 32768) k,
        vl := fun k x => gfByte 2 (ext.w.V (kPt Ly x) + 32768) k, rkl := fun k x => gfByte 2 (ext.rkw (kPt Ly x)) k,
        rkrl := fun k x => gfByte 1 (ext.rkrw (kPt Ly x)) k, rvl := fun k x => gfByte 2 (ext.rvw (kPt Ly x)) k,
        S8 := fun x => ext.w.S8 (sPt Ly x), ZSEL := fun x => ext.w.ZSEL (sPt Ly x), E := fun x => ext.w.E (sPt Ly x),
        PP := fun x => ext.w.PP (sPt Ly x), rsl := fun k x => gfByte 3 (ext.rsw (sPt Ly x)) k,
        pl := fun k x => gfByte 2 (ext.w.PP (sPt Ly x)) k, sr := fun k x => gfByte 2 (ext.srw (sPt Ly x)) k,
        sg := fun k x => gfByte 2 (ext.sgw (sPt Ly x)) k, MX := fun r => ext.w.MX (htPt Ly r),
        SUM := fun r => ext.w.SUM (htPt Ly r),
        G := onF Ly ext.w.Gt, A := onF Ly ext.w.Ac, U := onF Ly ext.w.U, H := onF Ly ext.w.Hh,
        rgl := fun k => onF Ly (fun p => gfByte 3 (ext.rgw p) k),
        ul := fun k => onF Ly (fun p => gfByte 2 (ext.w.U p + 32768) k),
        ru := fun k => onF Ly (fun p => gfByte 2 (ext.ruw p) k),
        hl := fun k => onF Ly (fun p => gfByte 3 (ext.w.Hh p + 2 ^ 23) k),
        rh := fun k => onF Ly (fun p => gfByte 2 (ext.rhw p) k) } := rfl

private theorem blkWitness_hWD {Ly : ShieldLayer} (Pb : BlockPublic (shieldShape Ly))
    (f : shieldS0.Pos → GF) (hf : ∀ p, Word16 (f p))
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) :
    (shdP_w16Pub Ly Pb).gD x *
      (onD Ly f x + 32768 - lv (fun k => onD Ly (fun p => gfByte 2 (f p + 32768) k)) x) = 0 := by
  rcases x with ⟨ct, cw⟩
  by_cases h : Exec.msbIndex 12 cw < 3072
  · rw [onD_eq Ly f ct cw h, lv_onD_gfByte Ly (by norm_num) (by norm_num) (fun p => f p + 32768) hf ct cw h,
      sub_self, mul_zero]
  · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]

private theorem blkWitness_hSS {Ly : ShieldLayer} (Pb : BlockPublic (shieldShape Ly))
    (f : shieldS0.Pos → GF) (dsq a1 : (shieldShape Ly).Tok → GF)
    (hisq : ∀ t, dsq t + a1 t = ((shieldShape Ly).ceps : GF) + ∑ i, f (t, i) * f (t, i))
    (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) :
    (shdP_w16Pub Ly Pb).gT ct * (dsq (blkTokInv ct) + a1 (blkTokInv ct) - ((shieldShape Ly).ceps : GF))
      = ∑ cw, (shdP_w16Pub Ly Pb).gD (ct, cw) * onD Ly f (ct, cw) * onD Ly f (ct, cw) := by
  rw [show (shdP_w16Pub Ly Pb).gT ct = 1 from rfl, one_mul,
    sum_cw_eq Ly _ (fun cw hpad => by rw [w16Pub_gD_neg Ly Pb ct cw hpad, zero_mul, zero_mul])]
  have hsum : (∑ i : (shieldShape Ly).Wid,
      (shdP_w16Pub Ly Pb).gD (ct, (shdP_bitLay Ly).wid.emb i)
        * onD Ly f (ct, (shdP_bitLay Ly).wid.emb i) * onD Ly f (ct, (shdP_bitLay Ly).wid.emb i))
      = ∑ i : (shieldShape Ly).Wid, f (blkTokInv ct, i) * f (blkTokInv ct, i) :=
    Finset.sum_congr rfl (fun i _ => by
      rw [onD_wid Ly, show (ct, (shdP_bitLay Ly).wid.emb i) = (shdP_bitLay Ly).dPos (blkTokInv ct, i) from
        Prod.ext (emb_blkTokInv Ly ct).symm rfl, (shdP_w16Pub Ly Pb).gD_one, one_mul])
  rw [hsum]; linear_combination hisq (blkTokInv ct)

private theorem blkWitness_rels_D0 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gD x * ((shdP_w16Pub Ly Pb).gamA x * E.X x * (2 * ((shieldShape Ly).cnA : GF))
      + E.dA x.1 * 2 ^ (shieldShape Ly).tn - 2 ^ ((shieldShape Ly).tn + 1) * E.dA x.1 * E.Y x - lv E.nr x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (lv E.nr x + lv E.ns x + 1 - 2 ^ ((shieldShape Ly).tn + 1) * E.dA x.1) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.X1 x - E.X x - E.AO x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * ((shdP_w16Pub Ly Pb).gamM x * E.X1 x * (2 * ((shieldShape Ly).cnM : GF))
      + E.dM x.1 * 2 ^ (shieldShape Ly).tn - 2 ^ ((shieldShape Ly).tn + 1) * E.dM x.1 * E.YM x - lv E.mr x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (lv E.mr x + lv E.ms x + 1 - 2 ^ ((shieldShape Ly).tn + 1) * E.dM x.1) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.X2 x - E.X1 x - E.Z x) = 0) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun ⟨ct, cw⟩ => ?_, fun ⟨ct, cw⟩ => ?_, fun ⟨ct, cw⟩ => ?_,
          fun ⟨ct, cw⟩ => ?_, fun ⟨ct, cw⟩ => ?_, fun ⟨ct, cw⟩ => ?_⟩
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [w16Pub_gD_pos Ly Pb ct cw h, w16Pub_gamA Ly Pb ct cw h, one_mul, onD_eq Ly _ ct cw h,
        onD_eq Ly _ ct cw h, lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.nrw ext.hnr24 ct cw h]
      exact (ext.hNA_div (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)).1
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.nrw ext.hnr24 ct cw h,
        lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.nsw ext.hns24 ct cw h, (ext.hNA_div _).2, mul_zero]
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [onD_eq Ly _ ct cw h, onD_eq Ly _ ct cw h, onD_eq Ly _ ct cw h, (ext.hw.res1 _).1, mul_zero]
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [w16Pub_gD_pos Ly Pb ct cw h, w16Pub_gamM Ly Pb ct cw h, one_mul, onD_eq Ly _ ct cw h,
        onD_eq Ly _ ct cw h, lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.mrw ext.hmr24 ct cw h]
      exact (ext.hNM_div (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)).1
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.mrw ext.hmr24 ct cw h,
        lv_onD_gfByte Ly (by norm_num) (by norm_num) ext.msw ext.hms24 ct cw h, (ext.hNM_div _).2, mul_zero]
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · rw [onD_eq Ly _ ct cw h, onD_eq Ly _ ct cw h, onD_eq Ly _ ct cw h, (ext.hw.res2 _).1, mul_zero]
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]

private theorem blkWitness_rels_wo_dmm {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (2 ^ (shieldShape Ly).sao * E.AO x + lv E.ral x - 2 ^ ((shieldShape Ly).sao - 1))
      = ∑ c, E.O (x.1, c) * (shdP_w16Pub Ly Pb).Wo c x.2) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (2 ^ (shieldShape Ly).sdown * E.Z x + lv E.rdl x - 2 ^ ((shieldShape Ly).sdown - 1))
      = ∑ c, E.H (x.1, c) * (shdP_w16Pub Ly Pb).Wd c x.2) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun ⟨ct, cw⟩ => ?_, fun ⟨ct, cw⟩ => ?_⟩
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · let p : shieldS0.Pos := (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)
      rw [w16Pub_gD_pos Ly Pb ct cw h, one_mul, onD_eq Ly _ ct cw h,
        lv_onD_gfByte Ly (by have := ext.hW.ao.2; omega) (by norm_num) ext.raow ext.hAOrem ct cw h, sum_qc_eq Ly]
      rw [Finset.sum_congr rfl (fun qc _ => by
        have hq : qPt Ly (ct, ((shdP_bitLay Ly).slot qc.1, (shdP_bitLay Ly).hd.emb qc.2)) = (p.1, qc) := by
          unfold qPt; dsimp only
          exact congrArg (p.1, ·) (Prod.ext (blkSlotInv_slot Ly qc.1) (blkHdInv_emb Ly qc.2))
        have hcw : cw = (shdP_bitLay Ly).wid.emb p.2 := (Exec.msbBits_msbIndex 12 cw).symm
        rw [hq, hcw, (shdP_w16Pub Ly Pb).Wo_emb qc p.2])]
      exact ext.hAOrel p
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
      exact (Finset.sum_eq_zero (fun c _ => by rw [w16Pub_Wo_pad_cw Ly Pb c cw h, mul_zero])).symm
  · by_cases h : Exec.msbIndex 12 cw < 3072
    · let p : shieldS0.Pos := (blkTokInv ct, ⟨Exec.msbIndex 12 cw, h⟩)
      rw [w16Pub_gD_pos Ly Pb ct cw h, one_mul, onD_eq Ly _ ct cw h,
        lv_onD_gfByte Ly (by have := ext.hW.down.2; omega) (by norm_num) ext.rdw ext.hZrem ct cw h,
        sum_cf_eq Ly _ (fun cf hpad => by rw [onF_pad Ly ext.w.Hh ct cf hpad, zero_mul])]
      rw [Finset.sum_congr rfl (fun k _ => by
        rw [onF_hid Ly, show cw = (shdP_bitLay Ly).wid.emb p.2 from (Exec.msbBits_msbIndex 12 cw).symm,
          (shdP_w16Pub Ly Pb).Wd_emb k p.2])]
      exact ext.hZrel p
    · rw [w16Pub_gD_neg Ly Pb ct cw h, zero_mul]
      exact (Finset.sum_eq_zero (fun c _ => by rw [w16Pub_Wd_pad_cw Ly Pb c cw h, mul_zero])).symm

private theorem blkWitness_rels_Q {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * ((shdP_w16Pub Ly Pb).cosT x * E.Q x
      + (shdP_w16Pub Ly Pb).sinT x * E.Q (x.1, (x.2.1, (shdP_bitLay Ly).flip x.2.2))
      - 2 ^ 7 * E.QR x - lv E.rqrl x + 2 ^ 6) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * (E.Q x + 32768 - lv E.ql x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * (E.QR x + 32768 - lv E.qrl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * (E.O x + 32768 - lv E.ol x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * (2 ^ (shieldShape Ly).sq * E.Q x + lv E.rql x - 2 ^ ((shieldShape Ly).sq - 1))
      = ∑ c, E.Y (x.1, c) * (shdP_w16Pub Ly Pb).Wq c x.2) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gQ x * (2 ^ (shieldShape Ly).spv * E.O x + lv E.ro x - 2 ^ ((shieldShape Ly).spv - 1))
      = ∑ j, E.PP (x.2.1, x.1, j) * E.V (j, (x.2.1.1, x.2.2))) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_⟩
  · rw [show (shdP_w16Pub Ly Pb).gQ x = 1 from rfl, one_mul, w16Pub_cosT, w16Pub_sinT,
      lv_gfByte (by norm_num) (by norm_num) (fun y => ext.rqrw (qPt Ly y)) x (ext.hQRrem (qPt Ly x)),
      qPt_flip Ly x]
    exact ext.hQRrel (qPt Ly x)
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.Q (qPt Ly y) + 32768) x (ext.hQw _), sub_self, mul_zero]
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.QR (qPt Ly y) + 32768) x (ext.hQRw _), sub_self, mul_zero]
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.O (qPt Ly y) + 32768) x (ext.hOw _), sub_self, mul_zero]
  · rw [show (shdP_w16Pub Ly Pb).gQ x = 1 from rfl, one_mul,
      lv_gfByte (by have := ext.hW.q.2; omega) (by norm_num) (fun y => ext.rqw (qPt Ly y)) x (ext.hQrem _),
      sum_cw_eq Ly _ (fun cw hpad => by rw [onD_pad Ly ext.w.Y x.1 cw hpad, zero_mul])]
    rw [Finset.sum_congr rfl (fun i _ => by
      rw [onD_wid Ly, qPt_snd_emb Ly x, (shdP_w16Pub Ly Pb).Wq_emb i (qPt Ly x).2])]
    exact ext.hQrel (qPt Ly x)
  · rw [show (shdP_w16Pub Ly Pb).gQ x = 1 from rfl, one_mul,
      lv_gfByte (by have := ext.hW.pv.2; omega) (by norm_num) (fun y => ext.row (qPt Ly y)) x (ext.hOrem _),
      sum_ct_eq Ly]
    rw [Finset.sum_congr rfl (fun j _ => by
      have hs : sPt Ly (x.2.1, x.1, (shdP_bitLay Ly).tok.emb j) = ((qPt Ly x).2.1, (qPt Ly x).1, j) := by
        unfold sPt qPt; dsimp only
        exact congrArg (fun t => (blkSlotInv x.2.1, blkTokInv x.1, t)) (blkTokInv_emb Ly j)
      have hk : kPt Ly ((shdP_bitLay Ly).tok.emb j, (x.2.1.1, x.2.2)) =
          (j, ((shieldShape Ly).grp (qPt Ly x).2.1, (qPt Ly x).2.2)) := by
        unfold kPt qPt; dsimp only
        exact Prod.ext (blkTokInv_emb Ly j) (congrArg (fun g : Fin 8 => (g, blkHdInv x.2.2)) (shieldGrp_blkSlotInv x.2.1).symm)
      rw [hs, hk])]
    exact ext.hOrel (qPt Ly x)

private theorem blkWitness_rels_K {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gK x * ((shdP_w16Pub Ly Pb).cosK x * E.K x
      + (shdP_w16Pub Ly Pb).sinK x * E.K (x.1, (x.2.1, (shdP_bitLay Ly).flip x.2.2))
      - 2 ^ 7 * E.KR x - lv E.rkrl x + 2 ^ 6) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gK x * (E.K x + 32768 - lv E.kl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gK x * (E.KR x + 32768 - lv E.krl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gK x * (E.V x + 32768 - lv E.vl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gK x * (2 ^ (shieldShape Ly).sk * E.K x + lv E.rkl x - 2 ^ ((shieldShape Ly).sk - 1))
      = ∑ c, E.Y (x.1, c) * (shdP_w16Pub Ly Pb).Wk c x.2) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gK x * (2 ^ (shieldShape Ly).sv * E.V x + lv E.rvl x - 2 ^ ((shieldShape Ly).sv - 1))
      = ∑ c, E.Y (x.1, c) * (shdP_w16Pub Ly Pb).Wv c x.2) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_⟩
  · rw [show (shdP_w16Pub Ly Pb).gK x = 1 from rfl, one_mul, w16Pub_cosK, w16Pub_sinK,
      lv_gfByte (by norm_num) (by norm_num) (fun y => ext.rkrw (kPt Ly y)) x (ext.hKRrem (kPt Ly x)),
      kPt_flip Ly x]
    exact ext.hKRrel (kPt Ly x)
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.K (kPt Ly y) + 32768) x (ext.hKw _), sub_self, mul_zero]
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.KR (kPt Ly y) + 32768) x (ext.hKRw _), sub_self, mul_zero]
  · rw [lv_gfByte (by norm_num) (by norm_num) (fun y => ext.w.V (kPt Ly y) + 32768) x (ext.hVw _), sub_self, mul_zero]
  · rw [show (shdP_w16Pub Ly Pb).gK x = 1 from rfl, one_mul,
      lv_gfByte (by have := ext.hW.k.2; omega) (by norm_num) (fun y => ext.rkw (kPt Ly y)) x (ext.hKrem _),
      sum_cw_eq Ly _ (fun cw hpad => by rw [onD_pad Ly ext.w.Y x.1 cw hpad, zero_mul])]
    rw [Finset.sum_congr rfl (fun i _ => by
      rw [onD_wid Ly, kPt_snd_emb Ly x, (shdP_w16Pub Ly Pb).Wk_emb i (kPt Ly x).2])]
    exact ext.hKrel (kPt Ly x)
  · rw [show (shdP_w16Pub Ly Pb).gK x = 1 from rfl, one_mul,
      lv_gfByte (by have := ext.hW.v.2; omega) (by norm_num) (fun y => ext.rvw (kPt Ly y)) x (ext.hVrem _),
      sum_cw_eq Ly _ (fun cw hpad => by rw [onD_pad Ly ext.w.Y x.1 cw hpad, zero_mul])]
    rw [Finset.sum_congr rfl (fun i _ => by
      rw [onD_wid Ly, kPt_snd_emb Ly x, (shdP_w16Pub Ly Pb).Wv_emb i (kPt Ly x).2])]
    exact ext.hVrel (kPt Ly x)

private theorem blkWitness_rels_S {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gS x * (E.ZSEL x * E.ZSEL x - E.ZSEL x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gS x * (E.ZSEL x * (E.MX (x.1, x.2.1) - (shdP_w16Pub Ly Pb).mask x * (E.S8 x + 127) + 127)) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gS x * ((shdP_w16Pub Ly Pb).mask x * E.E x * 2 ^ (shieldShape Ly).fp
      - E.PP x * E.SUM (x.1, x.2.1) - lv E.sr x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gS x * (lv E.sg x + lv E.sr x + 1 - E.SUM (x.1, x.2.1)) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gS x * (E.PP x - lv E.pl x) = 0) ∧
    (∀ r, (shdP_w16Pub Ly Pb).gHt r * E.SUM r
      = ∑ j, (shdP_w16Pub Ly Pb).gS (r.1, r.2, j) * ((shdP_w16Pub Ly Pb).mask (r.1, r.2, j) * E.E (r.1, r.2, j))) ∧
    (∀ r, (shdP_w16Pub Ly Pb).gHt r = ∑ j, (shdP_w16Pub Ly Pb).gS (r.1, r.2, j) * E.ZSEL (r.1, r.2, j)) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gS x * (2 ^ (shieldShape Ly).ss * E.S8 x + lv E.rsl x - 2 ^ ((shieldShape Ly).ss - 1))
      = ∑ c, E.QR (x.2.1, (x.1, c)) * E.KR (x.2.2, (x.1.1, c))) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun x => ?_, fun r => ?_, fun r => ?_, fun x => ?_⟩
  · have hz : ext.w.ZSEL (sPt Ly x) * ext.w.ZSEL (sPt Ly x) - ext.w.ZSEL (sPt Ly x) = 0 :=
      (ext.hw.softmax ((sPt Ly x).1, (sPt Ly x).2.1)).2.1 (sPt Ly x).2.2
    rw [hz, mul_zero]
  · rw [w16Pub_mask]
    have hm : ext.w.ZSEL (sPt Ly x) * (ext.w.MX (htPt Ly (x.1, x.2.1))
        - maskF (sPt Ly x).2.1 (sPt Ly x).2.2 * (ext.w.S8 (sPt Ly x) + 127) + 127) = 0 :=
      (ext.hw.softmax ((sPt Ly x).1, (sPt Ly x).2.1)).2.2.1 (sPt Ly x).2.2
    rw [hm, mul_zero]
  · rw [w16Pub_mask, lv_gfByte (by have := ext.hW.wrho.2; omega) (by norm_num) (fun y => ext.srw (sPt Ly y)) x (ext.hsr16 _)]
    have hd : maskF (sPt Ly x).2.1 (sPt Ly x).2.2 * ext.w.E (sPt Ly x) * 2 ^ (shieldShape Ly).fp
        - ext.w.PP (sPt Ly x) * ext.w.SUM (htPt Ly (x.1, x.2.1)) - ext.srw (sPt Ly x) = 0 :=
      (ext.hSM_div (sPt Ly x)).1
    rw [hd, mul_zero]
  · rw [lv_gfByte (by have := ext.hW.wrho.2; omega) (by norm_num) (fun y => ext.sgw (sPt Ly y)) x (ext.hsg16 _),
      lv_gfByte (by have := ext.hW.wrho.2; omega) (by norm_num) (fun y => ext.srw (sPt Ly y)) x (ext.hsr16 _)]
    have hd : ext.sgw (sPt Ly x) + ext.srw (sPt Ly x) + 1 - ext.w.SUM (htPt Ly (x.1, x.2.1)) = 0 :=
      (ext.hSM_div (sPt Ly x)).2
    rw [hd, mul_zero]
  · rw [lv_gfByte (by have := ext.hW.fp.2; omega) (by norm_num) (fun y => ext.w.PP (sPt Ly y)) x (ext.hP13 _), sub_self, mul_zero]
  · rw [show (shdP_w16Pub Ly Pb).gHt r = 1 from rfl, one_mul, sum_ct_eq Ly]
    rw [Finset.sum_congr rfl (fun j _ => by
      have hs : sPt Ly (r.1, r.2, (shdP_bitLay Ly).tok.emb j) = ((htPt Ly r).1, (htPt Ly r).2, j) := by
        unfold sPt htPt; dsimp only
        exact congrArg (fun t => (blkSlotInv r.1, blkTokInv r.2, t)) (blkTokInv_emb Ly j)
      rw [show (shdP_w16Pub Ly Pb).gS (r.1, r.2, (shdP_bitLay Ly).tok.emb j) = 1 from rfl, one_mul, w16Pub_mask, hs])]
    exact ((ext.hw.softmax (htPt Ly r)).2.2.2.1).symm
  · rw [show (shdP_w16Pub Ly Pb).gHt r = 1 from rfl, sum_ct_eq Ly]
    rw [Finset.sum_congr rfl (fun j _ => by
      have hs : sPt Ly (r.1, r.2, (shdP_bitLay Ly).tok.emb j) = ((htPt Ly r).1, (htPt Ly r).2, j) := by
        unfold sPt htPt; dsimp only
        exact congrArg (fun t => (blkSlotInv r.1, blkTokInv r.2, t)) (blkTokInv_emb Ly j)
      rw [show (shdP_w16Pub Ly Pb).gS (r.1, r.2, (shdP_bitLay Ly).tok.emb j) = 1 from rfl, one_mul, hs])]
    exact ((ext.hw.softmax (htPt Ly r)).2.2.2.2.1).symm
  · rw [show (shdP_w16Pub Ly Pb).gS x = 1 from rfl, one_mul,
      lv_gfByte (by have := ext.hW.ss.2; omega) (by norm_num) (fun y => ext.rsw (sPt Ly y)) x (ext.hSrem _),
      sum_cd_eq Ly]
    rw [Finset.sum_congr rfl (fun c _ => by
      have hq : qPt Ly (x.2.1, (x.1, (shdP_bitLay Ly).hd.emb c)) = ((sPt Ly x).2.1, ((sPt Ly x).1, c)) := by
        unfold qPt sPt; dsimp only
        exact congrArg (fun d : Bool × Fin 64 => (blkTokInv x.2.1, (blkSlotInv x.1, d))) (blkHdInv_emb Ly c)
      have hk : kPt Ly (x.2.2, (x.1.1, (shdP_bitLay Ly).hd.emb c)) =
          ((sPt Ly x).2.2, ((shieldShape Ly).grp (sPt Ly x).1, c)) := by
        unfold kPt sPt; dsimp only
        exact congrArg (fun p : Fin 8 × (Bool × Fin 64) => (blkTokInv x.2.2, p))
          (Prod.ext (shieldGrp_blkSlotInv x.1).symm (blkHdInv_emb Ly c))
      rw [hq, hk])]
    exact ext.hSrel (sPt Ly x)

private theorem blkWitness_rels_F {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gF x * (E.A x * E.U x - 2 ^ (shieldShape Ly).sprod * E.H x - lv E.rh x
      + 2 ^ ((shieldShape Ly).sprod - 1)) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gF x * (E.U x + 32768 - lv E.ul x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gF x * (E.H x + 2 ^ 23 - lv E.hl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gF x * (2 ^ (shieldShape Ly).sgate * E.G x + lv E.rgl x - 2 ^ ((shieldShape Ly).sgate - 1))
      = ∑ c, E.YM (x.1, c) * (shdP_w16Pub Ly Pb).Wg c x.2) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gF x * (2 ^ (shieldShape Ly).sup * E.U x + lv E.ru x - 2 ^ ((shieldShape Ly).sup - 1))
      = ∑ c, E.YM (x.1, c) * (shdP_w16Pub Ly Pb).Wu c x.2) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  refine ⟨fun ⟨ct, cf⟩ => ?_, fun ⟨ct, cf⟩ => ?_, fun ⟨ct, cf⟩ => ?_, fun ⟨ct, cf⟩ => ?_, fun ⟨ct, cf⟩ => ?_⟩
  · by_cases h : Exec.msbIndex 14 cf < 9216
    · rw [onF_eq Ly _ ct cf h, onF_eq Ly _ ct cf h, onF_eq Ly _ ct cf h,
        lv_onF_gfByte Ly (by rw [ext.hW.prod]) (by norm_num) ext.rhw ext.hHrem ct cf h, ext.hHrel _, mul_zero]
    · rw [w16Pub_gF_neg Ly Pb ct cf h, zero_mul]
  · by_cases h : Exec.msbIndex 14 cf < 9216
    · rw [onF_eq Ly _ ct cf h, lv_onF_gfByte Ly (by norm_num) (by norm_num) (fun p => ext.w.U p + 32768) ext.hUw ct cf h,
        sub_self, mul_zero]
    · rw [w16Pub_gF_neg Ly Pb ct cf h, zero_mul]
  · by_cases h : Exec.msbIndex 14 cf < 9216
    · rw [onF_eq Ly _ ct cf h, lv_onF_gfByte Ly (by norm_num) (by norm_num) (fun p => ext.w.Hh p + 2 ^ 23) ext.hH24 ct cf h,
        sub_self, mul_zero]
    · rw [w16Pub_gF_neg Ly Pb ct cf h, zero_mul]
  · by_cases h : Exec.msbIndex 14 cf < 9216
    · let p : (shieldShape Ly).Tok × (shieldShape Ly).Hid := (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩)
      rw [w16Pub_gF_pos Ly Pb ct cf h, one_mul, onF_eq Ly _ ct cf h,
        lv_onF_gfByte Ly (by have := ext.hW.gate.2; omega) (by norm_num) ext.rgw ext.hGrem ct cf h,
        sum_cw_eq Ly _ (fun cw hpad => by rw [onD_pad Ly ext.w.YM ct cw hpad, zero_mul])]
      rw [Finset.sum_congr rfl (fun i _ => by
        rw [onD_wid Ly, show cf = (shdP_bitLay Ly).hid.emb p.2 from (Exec.msbBits_msbIndex 14 cf).symm,
          (shdP_w16Pub Ly Pb).Wg_emb i p.2])]
      exact ext.hGrel p
    · rw [w16Pub_gF_neg Ly Pb ct cf h, zero_mul]
      exact (Finset.sum_eq_zero (fun c _ => by rw [w16Pub_Wg_pad_cf Ly Pb c cf h, mul_zero])).symm
  · by_cases h : Exec.msbIndex 14 cf < 9216
    · let p : (shieldShape Ly).Tok × (shieldShape Ly).Hid := (blkTokInv ct, ⟨Exec.msbIndex 14 cf, h⟩)
      rw [w16Pub_gF_pos Ly Pb ct cf h, one_mul, onF_eq Ly _ ct cf h,
        lv_onF_gfByte Ly (by have := ext.hW.up.2; omega) (by norm_num) ext.ruw ext.hUrem ct cf h,
        sum_cw_eq Ly _ (fun cw hpad => by rw [onD_pad Ly ext.w.YM ct cw hpad, zero_mul])]
      rw [Finset.sum_congr rfl (fun i _ => by
        rw [onD_wid Ly, show cf = (shdP_bitLay Ly).hid.emb p.2 from (Exec.msbBits_msbIndex 14 cf).symm,
          (shdP_w16Pub Ly Pb).Wu_emb i p.2])]
      exact ext.hUrel p
    · rw [w16Pub_gF_neg Ly Pb ct cf h, zero_mul]
      exact (Finset.sum_eq_zero (fun c _ => by rw [w16Pub_Wu_pad_cf Ly Pb c cf h, mul_zero])).symm

private theorem tzc_d_aux (x : GF) (hx : InRange 24 x) :
    x - (gfByte 3 x 0 + 2 ^ 8 * gfByte 3 x 1 + 2 ^ 16 * gfByte 3 x 2) = 0 := by
  rw [gfByte_three_sum x hx, sub_self]

private theorem tzc_a_aux (d a1 a2 : GF) (h1 : InRange 24 a1) (h2 : InRange 24 a2) (h : 2 * d - a1 - a2 = 0) :
    2 * d - (gfByte 3 a1 0 + 2 ^ 8 * gfByte 3 a1 1 + 2 ^ 16 * gfByte 3 a1 2)
      - (gfByte 3 a2 0 + 2 ^ 8 * gfByte 3 a2 1 + 2 ^ 16 * gfByte 3 a2 2) = 0 := by
  rw [gfByte_three_sum a1 h1, gfByte_three_sum a2 h2]; exact h

private theorem ss_aux (gT dsq a1 ceps rhs : GF) (ha : InRange 24 a1) (h : gT * (dsq + a1 - ceps) = rhs) :
    gT * (dsq + (gfByte 3 a1 0 + 2 ^ 8 * gfByte 3 a1 1 + 2 ^ 16 * gfByte 3 a1 2) - ceps) = rhs := by
  rw [gfByte_three_sum a1 ha]; exact h

private theorem blkWitness_rels_T {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ ct, E.dsqA ct - E.dA ct * E.dA ct = 0) ∧
    (∀ ct, E.dA ct - (E.la 0 0 ct + 2 ^ 8 * E.la 0 1 ct + 2 ^ 16 * E.la 0 2 ct) = 0) ∧
    (∀ ct, 2 * E.dA ct - (E.la 1 0 ct + 2 ^ 8 * E.la 1 1 ct + 2 ^ 16 * E.la 1 2 ct)
      - (E.la 2 0 ct + 2 ^ 8 * E.la 2 1 ct + 2 ^ 16 * E.la 2 2 ct) = 0) ∧
    (∀ ct, E.dsqM ct - E.dM ct * E.dM ct = 0) ∧
    (∀ ct, E.dM ct - (E.lm 0 0 ct + 2 ^ 8 * E.lm 0 1 ct + 2 ^ 16 * E.lm 0 2 ct) = 0) ∧
    (∀ ct, 2 * E.dM ct - (E.lm 1 0 ct + 2 ^ 8 * E.lm 1 1 ct + 2 ^ 16 * E.lm 1 2 ct)
      - (E.lm 2 0 ct + 2 ^ 8 * E.lm 2 1 ct + 2 ^ 16 * E.lm 2 2 ct) = 0) ∧
    (∀ ct, (shdP_w16Pub Ly Pb).gT ct * (E.dsqA ct + (E.la 1 0 ct + 2 ^ 8 * E.la 1 1 ct + 2 ^ 16 * E.la 1 2 ct)
      - ((shieldShape Ly).ceps : GF)) = ∑ c, (shdP_w16Pub Ly Pb).gD (ct, c) * E.X (ct, c) * E.X (ct, c)) ∧
    (∀ ct, (shdP_w16Pub Ly Pb).gT ct * (E.dsqM ct + (E.lm 1 0 ct + 2 ^ 8 * E.lm 1 1 ct + 2 ^ 16 * E.lm 1 2 ct)
      - ((shieldShape Ly).ceps : GF)) = ∑ c, (shdP_w16Pub Ly Pb).gD (ct, c) * E.X1 (ct, c) * E.X1 (ct, c)) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  exact ⟨
    fun ct => (ext.hNA_isq (blkTokInv ct)).1,
    fun ct => tzc_d_aux (ext.w.dA (blkTokInv ct)) (ext.hdA24 (blkTokInv ct)),
    fun ct => tzc_a_aux (ext.w.dA (blkTokInv ct)) (ext.a1Aw (blkTokInv ct)) (ext.a2Aw (blkTokInv ct))
      (ext.ha1A24 (blkTokInv ct)) (ext.ha2A24 (blkTokInv ct)) (ext.hNA_isq (blkTokInv ct)).2.1,
    fun ct => (ext.hNM_isq (blkTokInv ct)).1,
    fun ct => tzc_d_aux (ext.w.dM (blkTokInv ct)) (ext.hdM24 (blkTokInv ct)),
    fun ct => tzc_a_aux (ext.w.dM (blkTokInv ct)) (ext.a1Mw (blkTokInv ct)) (ext.a2Mw (blkTokInv ct))
      (ext.ha1M24 (blkTokInv ct)) (ext.ha2M24 (blkTokInv ct)) (ext.hNM_isq (blkTokInv ct)).2.1,
    fun ct => ss_aux _ _ _ _ _ (ext.ha1A24 (blkTokInv ct))
      (blkWitness_hSS Pb (fun p => (xIn p : GF)) ext.dsqAw ext.a1Aw (fun t => (ext.hNA_isq t).2.2) ct),
    fun ct => ss_aux _ _ _ _ _ (ext.ha1M24 (blkTokInv ct))
      (blkWitness_hSS Pb ext.w.X1 ext.dsqMw ext.a1Mw (fun t => (ext.hNM_isq t).2.2) ct)⟩

private theorem blkWitness_rels_WD {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    let E := blkWitnessData ext
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.X x + 32768 - lv E.xl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.Y x + 32768 - lv E.yl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.AO x + 32768 - lv E.aol x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.X1 x + 32768 - lv E.x1l x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.YM x + 32768 - lv E.yml x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.Z x + 32768 - lv E.zl x) = 0) ∧
    (∀ x, (shdP_w16Pub Ly Pb).gD x * (E.X2 x + 32768 - lv E.x2l x) = 0) := by
  dsimp only
  rw [blkWitnessData_eq ext]
  dsimp only
  exact ⟨
    blkWitness_hWD Pb (fun p => (xIn p : GF)) ext.hw.inX,
    blkWitness_hWD Pb ext.w.Y ext.hYw,
    blkWitness_hWD Pb ext.w.AO ext.hAOw,
    blkWitness_hWD Pb ext.w.X1 (fun p => (ext.hw.res1 p).2),
    blkWitness_hWD Pb ext.w.YM ext.hYMw,
    blkWitness_hWD Pb ext.w.Z ext.hZw,
    blkWitness_hWD Pb (fun p => (xOut p : GF)) (fun p => (ext.hw.res2 p).2)⟩

private theorem blkWitness_hRels {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    R13Rels (shieldShape Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (blkWitnessData ext) := by
  obtain ⟨ht0, ht1, ht2, ht3, ht4, ht5, hss, hssm⟩ := blkWitness_rels_T ext
  obtain ⟨hwX, hwY, hwAO, hwX1, hwYM, hwZ, hwX2⟩ := blkWitness_rels_WD ext
  obtain ⟨hd0, hd1, hd2, hd3, hd4, hd5⟩ := blkWitness_rels_D0 ext
  obtain ⟨hwo, hdmm⟩ := blkWitness_rels_wo_dmm ext
  obtain ⟨hqrope, hwQ, hwQR, hwO, hqmm, hpv⟩ := blkWitness_rels_Q ext
  obtain ⟨hkrope, hwK, hwKR, hwV, hkmm, hvmm⟩ := blkWitness_rels_K ext
  obtain ⟨hs0, hs1, hs2, hs3, hs4, hrsE, hrsZ, hscore⟩ := blkWitness_rels_S ext
  obtain ⟨hf0, hf1, hf2, hgmm, humm⟩ := blkWitness_rels_F ext
  exact {
    tzc_sq := ht0, tzc_d := ht1, tzc_a := ht2, tzc_sqm := ht3, tzc_dm := ht4, tzc_am := ht5,
    ss := hss, ssm := hssm,
    d0 := hd0, d1 := hd1, d2 := hd2, d3 := hd3, d4 := hd4, d5 := hd5,
    wX := hwX, wY := hwY, wAO := hwAO, wX1 := hwX1, wYM := hwYM, wZ := hwZ, wX2 := hwX2,
    wo := hwo, dmm := hdmm, qrope := hqrope, wQ := hwQ, wQR := hwQR, wO := hwO, qmm := hqmm, pv := hpv,
    krope := hkrope, wK := hwK, wKR := hwKR, wV := hwV, kmm := hkmm, vmm := hvmm,
    s0 := hs0, s1 := hs1, s2 := hs2, s3 := hs3, s4 := hs4, rsE := hrsE, rsZ := hrsZ, score := hscore,
    f0 := hf0, f1 := hf1, f2 := hf2, gmm := hgmm, umm := humm,
    pp_pad := fun _ _ j h => (by have hf : False := h (blkTokInv j) (emb_blkTokInv Ly j); cases hf),
    kr_pad := fun _ _ c h => (by have hf : False := h (blkHdInv c) (emb_blkHdInv Ly c); cases hf) }

private theorem blkWitness_hLook {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    R13Lookups (shieldShape Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (blkWitnessData ext) := by
  rw [blkWitnessData_eq ext]
  exact {
    la := fun _ _ _ => gfByte_codeTable _ _ _ _ _ _,
    lm := fun _ _ _ => gfByte_codeTable _ _ _ _ _ _,
    xl := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    yl := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    aol := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    x1l := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    yml := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    zl := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    x2l := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    nr := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    ns := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    mr := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    ms := fun _ _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    ral := fun p => ⟨fun _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
      by dsimp only; rw [onD_dPos Ly]; exact gfByte_pin_codeTable _ _ _ ext.hW.ao.1 ext.hW.ao.2 (by norm_num) (ext.raow p) (ext.hAOrem p)⟩,
    rdl := fun p => ⟨fun _ => by dsimp only; rw [onD_dPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
      by dsimp only; rw [onD_dPos Ly]; exact gfByte_pin_codeTable _ _ _ ext.hW.down.1 ext.hW.down.2 (by norm_num) (ext.rdw p) (ext.hZrem p)⟩,
    ql := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    qrl := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    ol := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    rql := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.q.1 ext.hW.q.2 (by norm_num) _ (ext.hQrem _)⟩,
    rqrl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ (by norm_num) (by norm_num) (by norm_num) _ (ext.hQRrem _)⟩,
    ro := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.pv.1 ext.hW.pv.2 (by norm_num) _ (ext.hOrem _)⟩,
    kl := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    krl := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    vl := fun _ _ => gfByte_codeTable _ _ _ _ _ _,
    rkl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.k.1 ext.hW.k.2 (by norm_num) _ (ext.hKrem _)⟩,
    rkrl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ (by norm_num) (by norm_num) (by norm_num) _ (ext.hKRrem _)⟩,
    rvl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.v.1 ext.hW.v.2 (by norm_num) _ (ext.hVrem _)⟩,
    sB := fun p => by
      dsimp only; rw [sPt_sPos]
      exact ⟨(codeTable_range_iff r13Fams_ok _ _ _ mem_r13Fams _).mpr (ext.hSw p).1,
        (codeTable_range_iff r13Fams_ok _ _ _ mem_r13Fams _).mpr (ext.hSw p).2⟩,
    rsl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.ss.1 ext.hW.ss.2 (by norm_num) _ (ext.hSrem _)⟩,
    pl := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.fp.1 ext.hW.fp.2 (by norm_num) _ (ext.hP13 _)⟩,
    sr := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.wrho.1 ext.hW.wrho.2 (by norm_num) _ (ext.hsr16 _)⟩,
    sg := fun _ => ⟨fun _ => gfByte_codeTable _ _ _ _ _ _, gfByte_pin_codeTable _ _ _ ext.hW.wrho.1 ext.hW.wrho.2 (by norm_num) _ (ext.hsg16 _)⟩,
    sExp := fun p => by
      dsimp only
      have hht : htPt Ly ((shdP_bitLay Ly).slot p.1, (shdP_bitLay Ly).tok.emb p.2.1) = (p.1, p.2.1) := by
        unfold htPt; dsimp only; exact Prod.ext (blkSlotInv_slot Ly p.1) (blkTokInv_emb Ly p.2.1)
      rw [(shdP_w16Pub Ly Pb).mask_emb, sPt_sPos, hht]
      exact (codeTable_exp_iff r13Fams_ok _ _ _ _ _).mpr ((ext.hw.softmax (p.1, p.2.1)).1 p.2.2),
    rgl := fun p => ⟨fun _ => by dsimp only; rw [onF_fPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
      by dsimp only; rw [onF_fPos Ly]; exact gfByte_pin_codeTable _ _ _ ext.hW.gate.1 ext.hW.gate.2 (by norm_num) (ext.rgw p) (ext.hGrem p)⟩,
    ul := fun _ _ => by dsimp only; rw [onF_fPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    ru := fun p => ⟨fun _ => by dsimp only; rw [onF_fPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
      by dsimp only; rw [onF_fPos Ly]; exact gfByte_pin_codeTable _ _ _ ext.hW.up.1 ext.hW.up.2 (by norm_num) (ext.ruw p) (ext.hUrem p)⟩,
    hl := fun _ _ => by dsimp only; rw [onF_fPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    rh := fun _ _ => by dsimp only; rw [onF_fPos Ly]; exact gfByte_codeTable _ _ _ _ _ _,
    fAct := fun p => by
      dsimp only; rw [onF_fPos Ly, onF_fPos Ly]
      exact (codeTable_act_iff r13Fams_ok _ _ _ _ _ _).mpr (ext.hGact p) }

private theorem blkWitness_hPadD {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) : BlkPadD (blkWitnessData ext) := by
  rw [blkWitnessData_eq ext]
  exact {
    X := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    Y := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    AO := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    X1 := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    YM := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    Z := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    X2 := fun ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    xl := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    yl := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    aol := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    x1l := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    yml := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    zl := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    x2l := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    nr := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    ns := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    mr := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    ms := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    ral := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h,
    rdl := fun _ ct cw h => by dsimp only; exact onD_pad Ly _ ct cw h }

private theorem blkWitness_hPadF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) : BlkPadF (blkWitnessData ext) := by
  rw [blkWitnessData_eq ext]
  exact {
    G := fun ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    A := fun ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    U := fun ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    H := fun ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    rgl := fun _ ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    ul := fun _ ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    ru := fun _ ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    hl := fun _ ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h,
    rh := fun _ ct cf h => by dsimp only; exact onF_pad Ly _ ct cf h }

private theorem blkWitness_hIO {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (ext : BlkSatExt Ly Pb xIn xOut) :
    (∀ p, (blkWitnessData ext).X (shieldDPos0 p) = (xIn p : GF)) ∧
      (∀ p, (blkWitnessData ext).X2 (shieldDPos0 p) = (xOut p : GF)) := by
  rw [blkWitnessData_eq ext, ← shdP_bitLay_dPos Ly]
  dsimp only
  exact ⟨fun p => onD_dPos Ly (fun q => (xIn q : GF)) p,
         fun p => onD_dPos Ly (fun q => (xOut q : GF)) p⟩

/-- **Extract a full `BlkWitness` from `blockSpec Pb xIn = some xOut`** (reusing `CircuitBlock.blockSat_iff`). -/
noncomputable def blkWitness_of_spec (Ly : ShieldLayer) (hLy : Ly ∈ shieldExport)
    (Pb : BlockPublic (shieldShape Ly)) (hPb : Pb.Valid) (hAct0 : Pb.act 0 2048 = 0)
    (xIn xOut : shieldS0.Pos → ℤ) (hxIn : ∀ p, i16 (xIn p)) (hspec : blockSpec Pb xIn = some xOut) :
    BlkWitness Ly Pb xIn xOut :=
  let ext := Classical.choice (blkSatExt_exists Ly hLy Pb hPb hAct0 xIn xOut hxIn hspec)
  let E := blkWitnessData ext
  ⟨E, limbPlaneOf E.la, limbPlaneOf E.lm, limbPlaneOf_active E.la, limbPlaneOf_active E.lm,
    fun b => limbPlaneOfIdx_byte E.la (fun _ _ _ => gfByte_inRange8 _ _ _) (Exec.msbIndex 14 b),
    fun b => limbPlaneOfIdx_byte E.lm (fun _ _ _ => gfByte_inRange8 _ _ _) (Exec.msbIndex 14 b),
    blkWitness_hRels ext, blkWitness_hLook ext, blkWitness_hPadD ext, blkWitness_hPadF ext,
    ⟨fun b h => limbPlaneOfIdx_pad E.la (Exec.msbIndex 14 b) h,
     fun b h => limbPlaneOfIdx_pad E.lm (Exec.msbIndex 14 b) h⟩,
    blkWitness_hIO ext,
    hAct0, hLy, hPb⟩

end BlockWitness

/-! ## 4. LogUp Multiplicities (`mu8`, `mexp`, `mact`) & Fiberwise Sum Lemma -/

section BlockLogUp

/-- Complete R13 lookup index set matching `AlkR13`: singles ⊕ (pair-left ⊕ pair-right). -/
abbrev BlkLkIx (Ly : ShieldLayer) : Type :=
  SgIx (Exec.Block.DefR13.cfgShieldR13 Ly) ⊕
    (PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1 ⊕ PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1)

/-- Active table predicate matching `SC_TAB`'s pad gates (`gateTabW`):
`idx < 256` on U8 (`k = 0`) and EXP (`k = 1`), and `idx < nG * 4096` on ACT (`k = 2`). -/
def tabActive (nG : ℕ) (j : TbIx) : Prop :=
  if j.1.val < 2 then Exec.msbIndex 14 j.2 < 256 else Exec.msbIndex 14 j.2 < nG * 4096

instance instDecidablePredTabActive (nG : ℕ) : DecidablePred (tabActive nG) := fun j => by
  unfold tabActive; infer_instance

private def blkPlaneD0 {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CwR (Exec.Block.DefR13.cfgShieldR13 Ly)) : ℕ → GF
  | 0 => E.X x | 1 => E.xl 0 x | 2 => E.xl 1 x | 3 => E.Y x | 4 => E.yl 0 x | 5 => E.yl 1 x
  | 6 => E.nr 0 x | 7 => E.nr 1 x | 8 => E.nr 2 x | 9 => E.ns 0 x | 10 => E.ns 1 x | 11 => E.ns 2 x
  | 12 => E.AO x | 13 => E.aol 0 x | 14 => E.aol 1 x | 15 => E.ral 0 x | 16 => E.ral 1 x | 17 => E.ral 2 x
  | 18 => E.X1 x | 19 => E.x1l 0 x | 20 => E.x1l 1 x | 21 => E.YM x | 22 => E.yml 0 x | 23 => E.yml 1 x
  | 24 => E.mr 0 x | 25 => E.mr 1 x | 26 => E.mr 2 x | 27 => E.ms 0 x | 28 => E.ms 1 x | 29 => E.ms 2 x
  | 30 => E.Z x | 31 => E.zl 0 x | 32 => E.zl 1 x | 33 => E.rdl 0 x | 34 => E.rdl 1 x | 35 => E.rdl 2 x
  | 36 => E.X2 x | 37 => E.x2l 0 x | 38 => E.x2l 1 x | _ => 0

private def blkPlaneF0 {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) : ℕ → GF
  | 0 => E.G x | 1 => E.rgl 0 x | 2 => E.rgl 1 x | 3 => E.rgl 2 x | 4 => E.A x | 5 => E.U x
  | 6 => E.ul 0 x | 7 => E.ul 1 x | 8 => E.ru 0 x | 9 => E.ru 1 x | 10 => E.H x | 11 => E.hl 0 x
  | 12 => E.hl 1 x | 13 => E.hl 2 x | 14 => E.rh 0 x | 15 => E.rh 1 x | _ => 0

private def blkPlaneQ {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      ((CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
        CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) :
    ℕ → GF
  | 47 => E.Q x | 48 => E.ql 0 x | 49 => E.ql 1 x | 50 => E.rql 0 x | 51 => E.rql 1 x | 52 => E.QR x
  | 53 => E.qrl 0 x | 54 => E.qrl 1 x | 55 => E.rqrl 0 x | 56 => E.O x | 57 => E.ol 0 x | 58 => E.ol 1 x
  | 59 => E.ro 0 x | 60 => E.ro 1 x | _ => 0

private def blkPlaneK {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1)
    (x : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) ×
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CdR (Exec.Block.DefR13.cfgShieldR13 Ly))) : ℕ → GF
  | 61 => E.K x | 62 => E.kl 0 x | 63 => E.kl 1 x | 64 => E.rkl 0 x | 65 => E.rkl 1 x | 66 => E.V x
  | 67 => E.vl 0 x | 68 => E.vl 1 x | 69 => E.rvl 0 x | 70 => E.rvl 1 x | 71 => E.KR x | 72 => E.krl 0 x
  | 73 => E.krl 1 x | 74 => E.rkrl 0 x | _ => 0

private def blkPlaneS {Ly : ShieldLayer}
    (E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1)
    (x : (CgR (Exec.Block.DefR13.cfgShieldR13 Ly) × CjR (Exec.Block.DefR13.cfgShieldR13 Ly)) ×
      CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) :
    ℕ → GF
  | 75 => E.S8 x | 76 => E.rsl 0 x | 77 => E.rsl 1 x | 78 => E.rsl 2 x | 79 => E.ZSEL x | 80 => E.E x
  | 81 => E.PP x | 82 => E.pl 0 x | 83 => E.pl 1 x | 84 => E.sr 0 x | 85 => E.sr 1 x | 86 => E.sg 0 x
  | 87 => E.sg 1 x | _ => 0

/-- Read witness plane `q` of domain `d : Dm` at cube point `b` (planes `6..103`). -/
def blkDomPlane {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) : (d : Dm) → ℕ → (Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) → GF
  | .L, 6, b => w.limbA b
  | .L, 7, b => w.limbM b
  | .L, _, _ => 0
  | .D, q, b => if q < 8 then 0 else blkPlaneD0 w.E (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)) (q - 8)
  | .Q, q, b => blkPlaneQ w.E (splitQ (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logQ b)) q
  | .Kv, q, b => blkPlaneK w.E (splitK (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logK b)) q
  | .S, q, b => blkPlaneS w.E (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)) q
  | .F, q, b => if q < 88 then 0 else blkPlaneF0 w.E (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)) (q - 88)

private theorem blkPlaneD0_pad {Ly : ShieldLayer}
    {E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1}
    (hPad : BlkPadD E) (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cw : CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 12 cw < 3072) : ∀ m, blkPlaneD0 E (ct, cw) m = 0
  | 0 => hPad.X ct cw h | 1 => hPad.xl 0 ct cw h | 2 => hPad.xl 1 ct cw h | 3 => hPad.Y ct cw h
  | 4 => hPad.yl 0 ct cw h | 5 => hPad.yl 1 ct cw h | 6 => hPad.nr 0 ct cw h | 7 => hPad.nr 1 ct cw h
  | 8 => hPad.nr 2 ct cw h | 9 => hPad.ns 0 ct cw h | 10 => hPad.ns 1 ct cw h | 11 => hPad.ns 2 ct cw h
  | 12 => hPad.AO ct cw h | 13 => hPad.aol 0 ct cw h | 14 => hPad.aol 1 ct cw h | 15 => hPad.ral 0 ct cw h
  | 16 => hPad.ral 1 ct cw h | 17 => hPad.ral 2 ct cw h | 18 => hPad.X1 ct cw h | 19 => hPad.x1l 0 ct cw h
  | 20 => hPad.x1l 1 ct cw h | 21 => hPad.YM ct cw h | 22 => hPad.yml 0 ct cw h | 23 => hPad.yml 1 ct cw h
  | 24 => hPad.mr 0 ct cw h | 25 => hPad.mr 1 ct cw h | 26 => hPad.mr 2 ct cw h | 27 => hPad.ms 0 ct cw h
  | 28 => hPad.ms 1 ct cw h | 29 => hPad.ms 2 ct cw h | 30 => hPad.Z ct cw h | 31 => hPad.zl 0 ct cw h
  | 32 => hPad.zl 1 ct cw h | 33 => hPad.rdl 0 ct cw h | 34 => hPad.rdl 1 ct cw h | 35 => hPad.rdl 2 ct cw h
  | 36 => hPad.X2 ct cw h | 37 => hPad.x2l 0 ct cw h | 38 => hPad.x2l 1 ct cw h | _ + 39 => rfl

private theorem blkPlaneF0_pad {Ly : ShieldLayer}
    {E : R13Data (CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CwR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CgR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CjR (Exec.Block.DefR13.cfgShieldR13 Ly))
      (CdR (Exec.Block.DefR13.cfgShieldR13 Ly)) (CfR (Exec.Block.DefR13.cfgShieldR13 Ly)) 1}
    (hPad : BlkPadF E) (ct : CtR (Exec.Block.DefR13.cfgShieldR13 Ly)) (cf : CfR (Exec.Block.DefR13.cfgShieldR13 Ly))
    (h : ¬ Exec.msbIndex 14 cf < 9216) : ∀ m, blkPlaneF0 E (ct, cf) m = 0
  | 0 => hPad.G ct cf h | 1 => hPad.rgl 0 ct cf h | 2 => hPad.rgl 1 ct cf h | 3 => hPad.rgl 2 ct cf h
  | 4 => hPad.A ct cf h | 5 => hPad.U ct cf h | 6 => hPad.ul 0 ct cf h | 7 => hPad.ul 1 ct cf h
  | 8 => hPad.ru 0 ct cf h | 9 => hPad.ru 1 ct cf h | 10 => hPad.H ct cf h | 11 => hPad.hl 0 ct cf h
  | 12 => hPad.hl 1 ct cf h | 13 => hPad.hl 2 ct cf h | 14 => hPad.rh 0 ct cf h | 15 => hPad.rh 1 ct cf h
  | _ + 16 => rfl

/-- Every `Dom::D` plane vanishes on padded `Dom::D` positions (`msbIndex 12 cw ≥ 3072`). -/
theorem blkDomPlane_pad_D {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (q : ℕ) (b : Fin (Dm.D.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool)
    (h : ¬ Exec.msbIndex 12 (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)).2 < 3072) :
    blkDomPlane w .D q b = 0 := by
  show (if q < 8 then 0 else blkPlaneD0 w.E
    (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)) (q - 8)) = 0
  by_cases hq : q < 8
  · exact ite_eq_left hq
  · rw [ite_eq_right hq]; exact blkPlaneD0_pad w.hPadD _ _ h (q - 8)

/-- Every `Dom::F` plane vanishes on padded `Dom::F` positions (`msbIndex 14 cf ≥ 9216`). -/
theorem blkDomPlane_pad_F {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (q : ℕ) (b : Fin (Dm.F.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool)
    (h : ¬ Exec.msbIndex 14 (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)).2 < 9216) :
    blkDomPlane w .F q b = 0 := by
  show (if q < 88 then 0 else blkPlaneF0 w.E
    (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)) (q - 88)) = 0
  by_cases hq : q < 88
  · exact ite_eq_left hq
  · rw [ite_eq_right hq]; exact blkPlaneF0_pad w.hPadF _ _ h (q - 88)

/-- Evaluate a single `LkW` linear expression on `w` over `GF`. -/
def blkLkValGF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (d : Dm) (l : LkW) (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) : GF :=
  (l.terms.map fun t => (t.2 : GF) * blkDomPlane w d t.1 b).sum + (l.cst : GF)

/-- Lookup `i` of domain `d` on `w` as a `Tup GF` (matching `lkAtR`). -/
def blkLkAtGF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (d : Dm) (i : ℕ) (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) : Tup GF :=
  let l := (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).getD i ⟨[], 0, 0⟩
  ⟨blkLkValGF w d l b, ((tagW l.tag : ℕ) : GF), 0, 0⟩

/-- Exp tuple at a `Dom::S` cube point (matching `expTupR`). -/
def blkExpTupGF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) → Bool) : Tup GF :=
  expQuery
    (w.E.MX ((splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)).1,
             (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)).2.1)
      - (shdP_w16Pub Ly Pb).mask (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b))
        * (w.E.S8 (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)) + 127) + 127)
    (w.E.E (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)))

/-- ACT tuple at a `Dom::F` cube point (matching `actTupR`). -/
def blkActTupGF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) : Tup GF :=
  ⟨w.E.G (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)) + 2048, ((tagAct : ℕ) : GF),
    w.E.A (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)),
    (shdP_w16Pub Ly Pb).grpCol (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b))⟩

/-- Single lookup tuple on `w` (matching `sgTupR`). -/
def blkSgTupGF {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) : (s : Sg) → (Fin (s.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) → Tup GF
  | .S, b => blkLkAtGF w .S (2 * Dm.np 1 .S) b
  | .Exp, b => blkExpTupGF w b
  | .Act, b => blkActTupGF w b

/-- Complete R13 lookup tuple vector over `BlkLkIx Ly` (matching `AlkR13`). -/
def blkLkTup {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) : BlkLkIx Ly → Tup GF
  | .inl ⟨s, b⟩ => blkSgTupGF w s b
  | .inr (.inl ⟨d, j, b⟩) => blkLkAtGF w d (2 * j.val) b
  | .inr (.inr ⟨d, j, b⟩) => blkLkAtGF w d (2 * j.val + 1) b

private theorem map_list_sum_alg {α : Type} (f : α → GF) :
    ∀ (l : List α), algebraMap GF shdP_K (l.map f).sum = (l.map (fun x => algebraMap GF shdP_K (f x))).sum
  | [] => map_zero _
  | a :: l => by simp only [List.map_cons, List.sum_cons, map_add, map_list_sum_alg f l]

private theorem blkActTupGF_eq {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    blkActTupGF w b =
      ⟨w.E.G (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)) + 2048,
       ((tagAct : ℕ) : GF),
       w.E.A (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)),
       (shdP_w16Pub Ly Pb).grpCol (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b))⟩ := rfl

private theorem tupK_mk (x t y z : GF) :
    tupK (K := shdP_K) ⟨x, t, y, z⟩ =
      ⟨algebraMap GF shdP_K x, algebraMap GF shdP_K t, algebraMap GF shdP_K y, algebraMap GF shdP_K z⟩ := rfl

private theorem blkLkTup_eq_AlkR13_exp {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (P : BlockParams) {L : ℕ} (Dof : List (QB L × Dig) → CmData shdP_K P) (cut : List (QB L × Dig))
    (hMX : ∀ b : Fin (nHt (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool,
      aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 4)
        (nHt (Exec.Block.DefR13.cfgShieldR13 Ly)) b
        = algebraMap GF shdP_K (w.E.MX (splitHt (Exec.Block.DefR13.cfgShieldR13 Ly) b)))
    (hS8 : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 75)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) b = algebraMap GF shdP_K (blkDomPlane w .S 75 b))
    (hE : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 80)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) b = algebraMap GF shdP_K (blkDomPlane w .S 80 b))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) → Bool) :
    expTupR shdP_U (Exec.Block.DefR13.cfgShieldR13 Ly) P (Dof cut) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
      (geoShield Ly) b = tupK (blkExpTupGF w b) := by
  unfold expTupR blkExpTupGF expQuery tupK
  dsimp only
  rw [hMX, hS8, hE, Exec.Block.Join.R13H.splitHt_append (Exec.Block.DefR13.cfgShieldR13 Ly)
    ((splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)).1,
     (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)).2.1)]
  refine Tup.ext' ?_ (map_natCast _ _).symm rfl (map_zero _).symm
  dsimp only [blkDomPlane, blkPlaneS]; simp only [map_add, map_sub, map_mul, map_ofNat]; ring

private theorem blkLkTup_eq_AlkR13_act {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (P : BlockParams) {L : ℕ} (Dof : List (QB L × Dig) → CmData shdP_K P) (cut : List (QB L × Dig))
    (hG : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 88)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b = algebraMap GF shdP_K (blkDomPlane w .F 88 b))
    (hA : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 92)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b = algebraMap GF shdP_K (blkDomPlane w .F 92 b))
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    actTupR shdP_U (Exec.Block.DefR13.cfgShieldR13 Ly) P (Dof cut) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
      (geoShield Ly) b = tupK (blkActTupGF w b) := by
  rw [blkActTupGF_eq, tupK_mk]
  unfold actTupR
  rw [show (86 + 2 * 1 : ℕ) = 88 from rfl, show (88 + 4 : ℕ) = 92 from rfl, hG, hA]
  refine Tup.ext' ?_ (map_natCast _ _).symm rfl rfl
  set gVal := w.E.G (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b))
  show algebraMap GF shdP_K gVal + 2048 = algebraMap GF shdP_K (gVal + 2048)
  exact (congrArg (algebraMap GF shdP_K gVal + ·) (map_ofNat (algebraMap GF shdP_K) 2048).symm).trans
    (map_add (algebraMap GF shdP_K) gVal 2048).symm

/-- Exact bridge from `blkLkTup` to `AlkR13`: whenever committed `A` planes match `w`,
`AlkR13` equals `tupK ∘ blkLkTup` pointwise on all `66,879,488` lookups. -/
theorem blkLkTup_eq_AlkR13 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (P : BlockParams) {L : ℕ} (Dof : List (QB L × Dig) → CmData shdP_K P) (cut : List (QB L × Dig))
    (hPl : ∀ (d : Dm) (i : ℕ), i < (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).length →
      ∀ t ∈ ((Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).getD i ⟨[], 0, 0⟩).terms,
      ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) t.1)
        (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) b
        = algebraMap GF shdP_K (blkDomPlane w d t.1 b))
    (hMX : ∀ b : Fin (nHt (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool,
      aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 4)
        (nHt (Exec.Block.DefR13.cfgShieldR13 Ly)) b
        = algebraMap GF shdP_K (w.E.MX (splitHt (Exec.Block.DefR13.cfgShieldR13 Ly) b)))
    (hS8 : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 75)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) b = algebraMap GF shdP_K (blkDomPlane w .S 75 b))
    (hE : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 80)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) b = algebraMap GF shdP_K (blkDomPlane w .S 80 b))
    (hG : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 88)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b = algebraMap GF shdP_K (blkDomPlane w .F 88 b))
    (hA : ∀ b, aPl shdP_U P (Dof cut) (Exec.Block.DefR13.aOff (Exec.Block.DefR13.cfgShieldR13 Ly) 92)
        ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) b = algebraMap GF shdP_K (blkDomPlane w .F 92 b))
    (l : BlkLkIx Ly) :
    AlkR13 shdP_U (Exec.Block.DefR13.cfgShieldR13 Ly) P Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (geoShield Ly) Dof cut l
      = tupK (blkLkTup w l) := by
  have hAt : ∀ (d : Dm) (i : ℕ), i < (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).length →
      ∀ b, lkAtR shdP_U (Exec.Block.DefR13.cfgShieldR13 Ly) P (Dof cut) d i b = tupK (blkLkAtGF w d i b) := fun d i hi b => by
    unfold lkAtR lkTupR blkLkAtGF blkLkValGF tupK
    refine Tup.ext' ?_ (map_natCast _ _).symm (map_zero _).symm (map_zero _).symm
    dsimp only
    rw [map_add, map_intCast, map_list_sum_alg]
    congr 1
    refine congrArg List.sum (List.map_congr_left fun t ht => ?_)
    rw [map_mul, map_intCast, hPl d i hi t ht b]
  have hc := lookCfg_shield Ly
  rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩
  · cases s with
    | S => exact hAt .S (2 * Dm.np 1 .S) (by rw [lkLen hc .S, ite_eq_left rfl]; omega) b
    | Exp => exact blkLkTup_eq_AlkR13_exp w P Dof cut hMX hS8 hE b
    | Act => exact blkLkTup_eq_AlkR13_act w P Dof cut hG hA b
  · exact hAt d (2 * j.val) (by rw [lkLen hc d]; have := j.isLt; omega) b
  · exact hAt d (2 * j.val + 1) (by rw [lkLen hc d]; have := j.isLt; omega) b

private theorem forall_mem_nil {α : Type} {P : α → Prop} : (∀ x ∈ ([] : List α), P x) ↔ True :=
  ⟨fun _ => trivial, fun _ _ h => by cases h⟩
private theorem forall_mem_cons {α : Type} {P : α → Prop} {a : α} {l : List α} :
    (∀ x ∈ a :: l, P x) ↔ P a ∧ ∀ x ∈ l, P x :=
  ⟨fun h => ⟨h a List.mem_cons_self, fun x hx => h x (List.mem_cons_of_mem _ hx)⟩,
   fun ⟨ha, hl⟩ x hx => (List.mem_cons.mp hx).elim (fun h => h ▸ ha) (hl x)⟩

private theorem blkLkValGF_bLk {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (d : Dm) (q : ℕ)
    (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) : blkLkValGF w d (bLk q) b = blkDomPlane w d q b := by
  unfold blkLkValGF bLk
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Int.cast_one, one_mul, Int.cast_zero]

private theorem blkLkValGF_pLk {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (d : Dm) (q e : ℕ)
    (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) :
    blkLkValGF w d (pLk q e) b = (2 : GF) ^ e * blkDomPlane w d q b := by
  unfold blkLkValGF pLk
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Int.cast_zero, Int.cast_pow, Int.cast_ofNat]

private theorem ok_bC {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    {w : BlkWitness Ly Pb xIn xOut} {d : Dm} {q : ℕ} {b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool}
    {v : GF} (hv : blkDomPlane w d q b = v)
    (h : CodeTable r13Fams Pb.exp Pb.act Ly.nG (rangeQuery (tagW 8) v)) :
    InRange 8 (blkLkValGF w d (bLk q) b) ∧ (bLk q).tag = 8 :=
  ⟨by rw [blkLkValGF_bLk, hv]; exact inRange8_of h, rfl⟩

private theorem ok_pC {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    {w : BlkWitness Ly Pb xIn xOut} {d : Dm} {q e : ℕ} {b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool}
    {v : GF} (hv : blkDomPlane w d q b = v)
    (h : CodeTable r13Fams Pb.exp Pb.act Ly.nG (rangeQuery (tagW 8) ((2 : GF) ^ e * v))) :
    InRange 8 (blkLkValGF w d (pLk q e) b) ∧ (pLk q e).tag = 8 :=
  ⟨by rw [blkLkValGF_pLk, hv]; exact inRange8_of h, rfl⟩

private theorem blkLkValGF_zero {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} {w : BlkWitness Ly Pb xIn xOut} {d : Dm}
    {b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool} (hpad : ∀ q, blkDomPlane w d q b = 0)
    (l : LkW) (hcst : l.cst = 0) (htag : l.tag = 8) : InRange 8 (blkLkValGF w d l b) ∧ l.tag = 8 := by
  unfold blkLkValGF
  have hz : (l.terms.map fun t => (t.2 : GF) * blkDomPlane w d t.1 b).sum = 0 := by
    induction l.terms with
    | nil => rfl
    | cons t ts ih => simp only [List.map_cons, List.sum_cons, hpad t.1, mul_zero, zero_add, ih]
  rw [hz, hcst, Int.cast_zero, add_zero]; exact ⟨inRange8_zero, htag⟩

private theorem lkSe_shield (Ly : ShieldLayer) :
    lkSe (Exec.Block.DefR13.cfgShieldR13 Ly).p 1 =
      [⟨[(75, 1)], 127, 8⟩, ⟨[(75, -1)], 127, 8⟩, bLk 76, bLk 77, bLk 78, pLk 78 (8 * 3 - (shieldShape Ly).ss),
       bLk 82, bLk 83, pLk 83 (8 * 2 - ((shieldShape Ly).fp + 1)), bLk 84, bLk 85, pLk 85 (8 * 2 - (shieldShape Ly).wrho),
       bLk 86, bLk 87, pLk 87 (8 * 2 - (shieldShape Ly).wrho)] := rfl

private theorem lkFe_shield (Ly : ShieldLayer) :
    lkFe (Exec.Block.DefR13.cfgShieldR13 Ly).p 1 =
      [bLk 89, bLk 90, bLk 91, pLk 91 (8 * 3 - (shieldShape Ly).sgate), bLk 94, bLk 95, bLk 96, bLk 97,
       pLk 97 (8 * 2 - (shieldShape Ly).sup), bLk 99, bLk 100, bLk 101, bLk 102, bLk 103] := rfl

private theorem blkLkAtGF_u8 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (d : Dm) (i : ℕ) (hi : i < (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).length)
    (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) :
    InRange 8 (blkLkAtGF w d i b).x ∧ (blkLkAtGF w d i b).tag = ((tagW 8 : ℕ) : GF)
      ∧ (blkLkAtGF w d i b).y = 0 ∧ (blkLkAtGF w d i b).z = 0 := by
  suffices hall : ∀ l ∈ Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom,
      InRange 8 (blkLkValGF w d l b) ∧ l.tag = 8 by
    have hmem : (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).getD i ⟨[], 0, 0⟩
        ∈ Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some]; exact List.getElem_mem hi
    obtain ⟨h8, htag⟩ := hall _ hmem
    unfold blkLkAtGF; dsimp only; exact ⟨h8, by rw [htag], rfl, rfl⟩
  have hc := lookCfg_shield Ly
  cases d with
  | L =>
    rw [show Dm.L.dom = .L from rfl, hc.lkL]; simp only [lkLe, forall_mem_cons, forall_mem_nil, and_true]
    exact ⟨⟨by rw [blkLkValGF_bLk]; exact w.hLimbA_byte b, rfl⟩, ⟨by rw [blkLkValGF_bLk]; exact w.hLimbM_byte b, rfl⟩⟩
  | D =>
    rw [show Dm.D.dom = .D from rfl, hc.lkD]
    by_cases h : Exec.msbIndex 12 (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)).2 < 3072
    · let p : shieldS0.Pos := (blkTokInv (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)).1,
        ⟨Exec.msbIndex 12 (splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b)).2, h⟩)
      have hx : splitD (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logD b) = (shdP_bitLay Ly).dPos p :=
        Prod.ext (emb_blkTokInv Ly _).symm (Exec.msbBits_msbIndex 12 _).symm
      simp only [lkDe, forall_mem_cons, forall_mem_nil, and_true]
      exact ⟨ok_bC (congrArg (w.E.xl 0) hx) (w.hLook.xl p 0), ok_bC (congrArg (w.E.xl 1) hx) (w.hLook.xl p 1),
        ok_bC (congrArg (w.E.yl 0) hx) (w.hLook.yl p 0), ok_bC (congrArg (w.E.yl 1) hx) (w.hLook.yl p 1),
        ok_bC (congrArg (w.E.nr 0) hx) (w.hLook.nr p 0), ok_bC (congrArg (w.E.nr 1) hx) (w.hLook.nr p 1),
        ok_bC (congrArg (w.E.nr 2) hx) (w.hLook.nr p 2), ok_bC (congrArg (w.E.ns 0) hx) (w.hLook.ns p 0),
        ok_bC (congrArg (w.E.ns 1) hx) (w.hLook.ns p 1), ok_bC (congrArg (w.E.ns 2) hx) (w.hLook.ns p 2),
        ok_bC (congrArg (w.E.aol 0) hx) (w.hLook.aol p 0), ok_bC (congrArg (w.E.aol 1) hx) (w.hLook.aol p 1),
        ok_bC (congrArg (w.E.ral 0) hx) ((w.hLook.ral p).1 0), ok_bC (congrArg (w.E.ral 1) hx) ((w.hLook.ral p).1 1),
        ok_bC (congrArg (w.E.ral 2) hx) ((w.hLook.ral p).1 2), ok_pC (congrArg (w.E.ral 2) hx) (w.hLook.ral p).2,
        ok_bC (congrArg (w.E.x1l 0) hx) (w.hLook.x1l p 0), ok_bC (congrArg (w.E.x1l 1) hx) (w.hLook.x1l p 1),
        ok_bC (congrArg (w.E.yml 0) hx) (w.hLook.yml p 0), ok_bC (congrArg (w.E.yml 1) hx) (w.hLook.yml p 1),
        ok_bC (congrArg (w.E.mr 0) hx) (w.hLook.mr p 0), ok_bC (congrArg (w.E.mr 1) hx) (w.hLook.mr p 1),
        ok_bC (congrArg (w.E.mr 2) hx) (w.hLook.mr p 2), ok_bC (congrArg (w.E.ms 0) hx) (w.hLook.ms p 0),
        ok_bC (congrArg (w.E.ms 1) hx) (w.hLook.ms p 1), ok_bC (congrArg (w.E.ms 2) hx) (w.hLook.ms p 2),
        ok_bC (congrArg (w.E.zl 0) hx) (w.hLook.zl p 0), ok_bC (congrArg (w.E.zl 1) hx) (w.hLook.zl p 1),
        ok_bC (congrArg (w.E.rdl 0) hx) ((w.hLook.rdl p).1 0), ok_bC (congrArg (w.E.rdl 1) hx) ((w.hLook.rdl p).1 1),
        ok_bC (congrArg (w.E.rdl 2) hx) ((w.hLook.rdl p).1 2), ok_pC (congrArg (w.E.rdl 2) hx) (w.hLook.rdl p).2,
        ok_bC (congrArg (w.E.x2l 0) hx) (w.hLook.x2l p 0), ok_bC (congrArg (w.E.x2l 1) hx) (w.hLook.x2l p 1)⟩
    · intro l hl
      have h0 : l.cst = 0 ∧ l.tag = 8 := by
        simp only [lkDe, bLk, pLk, List.mem_cons, List.not_mem_nil, or_false] at hl
        rcases hl with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
          rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
          rfl | rfl | rfl | rfl <;> exact ⟨rfl, rfl⟩
      exact blkLkValGF_zero (fun q => blkDomPlane_pad_D w q b h) l h0.1 h0.2
  | Q =>
    rw [show Dm.Q.dom = .Q from rfl, hc.lkQ]
    let p := qPt Ly (splitQ (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logQ b))
    have hx : splitQ (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logQ b) = (shdP_bitLay Ly).qPos p :=
      (qPos_qPt Ly _).symm
    simp only [lkQe, forall_mem_cons, forall_mem_nil, and_true]
    exact ⟨ok_bC (congrArg (w.E.ql 0) hx) (w.hLook.ql p 0), ok_bC (congrArg (w.E.ql 1) hx) (w.hLook.ql p 1),
      ok_bC (congrArg (w.E.rql 0) hx) ((w.hLook.rql p).1 0), ok_bC (congrArg (w.E.rql 1) hx) ((w.hLook.rql p).1 1),
      ok_pC (congrArg (w.E.rql 1) hx) (w.hLook.rql p).2, ok_bC (congrArg (w.E.qrl 0) hx) (w.hLook.qrl p 0),
      ok_bC (congrArg (w.E.qrl 1) hx) (w.hLook.qrl p 1), ok_bC (congrArg (w.E.rqrl 0) hx) ((w.hLook.rqrl p).1 0),
      ok_pC (congrArg (w.E.rqrl 0) hx) (w.hLook.rqrl p).2, ok_bC (congrArg (w.E.ol 0) hx) (w.hLook.ol p 0),
      ok_bC (congrArg (w.E.ol 1) hx) (w.hLook.ol p 1), ok_bC (congrArg (w.E.ro 0) hx) ((w.hLook.ro p).1 0),
      ok_bC (congrArg (w.E.ro 1) hx) ((w.hLook.ro p).1 1), ok_pC (congrArg (w.E.ro 1) hx) (w.hLook.ro p).2⟩
  | Kv =>
    rw [show Dm.Kv.dom = .Kv from rfl, hc.lkK]
    let p := kPt Ly (splitK (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logK b))
    have hx : splitK (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logK b) = (shdP_bitLay Ly).kPos p :=
      (kPos_kPt Ly _).symm
    simp only [lkKe, forall_mem_cons, forall_mem_nil, and_true]
    exact ⟨ok_bC (congrArg (w.E.kl 0) hx) (w.hLook.kl p 0), ok_bC (congrArg (w.E.kl 1) hx) (w.hLook.kl p 1),
      ok_bC (congrArg (w.E.rkl 0) hx) ((w.hLook.rkl p).1 0), ok_bC (congrArg (w.E.rkl 1) hx) ((w.hLook.rkl p).1 1),
      ok_pC (congrArg (w.E.rkl 1) hx) (w.hLook.rkl p).2, ok_bC (congrArg (w.E.vl 0) hx) (w.hLook.vl p 0),
      ok_bC (congrArg (w.E.vl 1) hx) (w.hLook.vl p 1), ok_bC (congrArg (w.E.rvl 0) hx) ((w.hLook.rvl p).1 0),
      ok_bC (congrArg (w.E.rvl 1) hx) ((w.hLook.rvl p).1 1), ok_pC (congrArg (w.E.rvl 1) hx) (w.hLook.rvl p).2,
      ok_bC (congrArg (w.E.krl 0) hx) (w.hLook.krl p 0), ok_bC (congrArg (w.E.krl 1) hx) (w.hLook.krl p 1),
      ok_bC (congrArg (w.E.rkrl 0) hx) ((w.hLook.rkrl p).1 0), ok_pC (congrArg (w.E.rkrl 0) hx) (w.hLook.rkrl p).2⟩
  | S =>
    rw [show Dm.S.dom = .S from rfl, hc.lkS, lkSe_shield]
    let p := sPt Ly (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b))
    have hx : splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b) = (shdP_bitLay Ly).sPos p :=
      (sPos_sPt Ly _).symm
    simp only [forall_mem_cons, forall_mem_nil, and_true]
    have hS0 : InRange 8 (blkLkValGF w .S ⟨[(75, 1)], 127, 8⟩ b) := by
      unfold blkLkValGF
      simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Int.cast_one, one_mul,
        Int.cast_ofNat]
      change InRange 8 (w.E.S8 (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)) + 127)
      rw [hx]
      exact inRange8_of (w.hLook.sB p).1
    have hS1 : InRange 8 (blkLkValGF w .S ⟨[(75, -1)], 127, 8⟩ b) := by
      unfold blkLkValGF
      simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, Int.cast_neg, Int.cast_one,
        neg_one_mul, Int.cast_ofNat]
      change InRange 8 (-w.E.S8 (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b)) + 127)
      rw [hx]
      exact inRange8_of (w.hLook.sB p).2
    exact ⟨hS0, hS1,
      ok_bC (congrArg (w.E.rsl 0) hx) ((w.hLook.rsl p).1 0), ok_bC (congrArg (w.E.rsl 1) hx) ((w.hLook.rsl p).1 1),
      ok_bC (congrArg (w.E.rsl 2) hx) ((w.hLook.rsl p).1 2), ok_pC (congrArg (w.E.rsl 2) hx) (w.hLook.rsl p).2,
      ok_bC (congrArg (w.E.pl 0) hx) ((w.hLook.pl p).1 0), ok_bC (congrArg (w.E.pl 1) hx) ((w.hLook.pl p).1 1),
      ok_pC (congrArg (w.E.pl 1) hx) (w.hLook.pl p).2, ok_bC (congrArg (w.E.sr 0) hx) ((w.hLook.sr p).1 0),
      ok_bC (congrArg (w.E.sr 1) hx) ((w.hLook.sr p).1 1), ok_pC (congrArg (w.E.sr 1) hx) (w.hLook.sr p).2,
      ok_bC (congrArg (w.E.sg 0) hx) ((w.hLook.sg p).1 0), ok_bC (congrArg (w.E.sg 1) hx) ((w.hLook.sg p).1 1),
      ok_pC (congrArg (w.E.sg 1) hx) (w.hLook.sg p).2⟩
  | F =>
    rw [show Dm.F.dom = .F from rfl, hc.lkF, lkFe_shield]
    by_cases h : Exec.msbIndex 14 (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)).2 < 9216
    · let p : (shieldShape Ly).Tok × (shieldShape Ly).Hid :=
        (blkTokInv (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)).1,
         ⟨Exec.msbIndex 14 (splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b)).2, h⟩)
      have hx : splitF (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logF b) = (shdP_bitLay Ly).fPos p :=
        Prod.ext (emb_blkTokInv Ly _).symm (Exec.msbBits_msbIndex 14 _).symm
      simp only [forall_mem_cons, forall_mem_nil, and_true]
      exact ⟨ok_bC (congrArg (w.E.rgl 0) hx) ((w.hLook.rgl p).1 0), ok_bC (congrArg (w.E.rgl 1) hx) ((w.hLook.rgl p).1 1),
        ok_bC (congrArg (w.E.rgl 2) hx) ((w.hLook.rgl p).1 2), ok_pC (congrArg (w.E.rgl 2) hx) (w.hLook.rgl p).2,
        ok_bC (congrArg (w.E.ul 0) hx) (w.hLook.ul p 0), ok_bC (congrArg (w.E.ul 1) hx) (w.hLook.ul p 1),
        ok_bC (congrArg (w.E.ru 0) hx) ((w.hLook.ru p).1 0), ok_bC (congrArg (w.E.ru 1) hx) ((w.hLook.ru p).1 1),
        ok_pC (congrArg (w.E.ru 1) hx) (w.hLook.ru p).2, ok_bC (congrArg (w.E.hl 0) hx) (w.hLook.hl p 0),
        ok_bC (congrArg (w.E.hl 1) hx) (w.hLook.hl p 1), ok_bC (congrArg (w.E.hl 2) hx) (w.hLook.hl p 2),
        ok_bC (congrArg (w.E.rh 0) hx) (w.hLook.rh p 0), ok_bC (congrArg (w.E.rh 1) hx) (w.hLook.rh p 1)⟩
    · intro l hl
      have h0 : l.cst = 0 ∧ l.tag = 8 := by
        simp only [bLk, pLk, List.mem_cons, List.not_mem_nil, or_false] at hl
        rcases hl with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact ⟨rfl, rfl⟩
      exact blkLkValGF_zero (fun q => blkDomPlane_pad_F w q b h) l h0.1 h0.2

/-- Canonical active table index `(k, msbBits 14 idx) : TbIx` hit by each R13 lookup `l : BlkLkIx Ly`. -/
def blkLkTarget {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
    (w : BlkWitness Ly Pb xIn xOut) : BlkLkIx Ly → TbIx
  | .inl ⟨.S, b⟩ => (⟨0, by norm_num⟩, Exec.msbBits 14 (blkLkAtGF w .S (2 * Dm.np 1 .S) b).x.val)
  | .inl ⟨.Exp, b⟩ => (⟨1, by norm_num⟩, Exec.msbBits 14 (blkExpTupGF w b).x.val)
  | .inl ⟨.Act, b⟩ => (⟨2, by norm_num⟩, Exec.msbBits 14 ((blkActTupGF w b).z.val * 4096 + (blkActTupGF w b).x.val))
  | .inr (.inl ⟨d, j, b⟩) => (⟨0, by norm_num⟩, Exec.msbBits 14 (blkLkAtGF w d (2 * j.val) b).x.val)
  | .inr (.inr ⟨d, j, b⟩) => (⟨0, by norm_num⟩, Exec.msbBits 14 (blkLkAtGF w d (2 * j.val + 1) b).x.val)

private theorem blkLkAtGF_hit {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (d : Dm) (i : ℕ) (hi : i < (Exec.Block.DefR13.lookups (Exec.Block.DefR13.cfgShieldR13 Ly) d.dom).length)
    (b : Fin (d.log (Exec.Block.DefR13.cfgShieldR13 Ly)) → Bool) :
    tabActive Ly.nG (⟨0, by norm_num⟩, Exec.msbBits 14 (blkLkAtGF w d i b).x.val)
      ∧ blkLkAtGF w d i b = tabTupE Pb.exp Pb.act Ly.nG 0 (Exec.msbIndex 14 (Exec.msbBits 14 (blkLkAtGF w d i b).x.val)) := by
  obtain ⟨h8, htag, hy, hz⟩ := blkLkAtGF_u8 w d i hi b
  have hv : (blkLkAtGF w d i b).x.val < 256 := val_lt_of_inRange (by norm_num) h8
  have hidx : Exec.msbIndex 14 (Exec.msbBits 14 (blkLkAtGF w d i b).x.val) = (blkLkAtGF w d i b).x.val :=
    Exec.msbIndex_msbBits 14 _ (by omega)
  refine ⟨by unfold tabActive; dsimp only; rw [ite_eq_left (by norm_num : (0 : ℕ) < 2), hidx]; exact hv, ?_⟩
  unfold tabTupE; rw [ite_eq_left rfl, hidx, Nat.mod_eq_of_lt hv, ZMod.natCast_zmod_val]
  exact Tup.ext' rfl htag hy hz

private theorem tup_x_mk {α : Type} (x t y z : α) : (Tup.mk x t y z).x = x := rfl
private theorem tup_tag_mk {α : Type} (x t y z : α) : (Tup.mk x t y z).tag = t := rfl
private theorem tup_y_mk {α : Type} (x t y z : α) : (Tup.mk x t y z).y = y := rfl
private theorem tup_z_mk {α : Type} (x t y z : α) : (Tup.mk x t y z).z = z := rfl

private theorem blkLkTarget_spec_exp {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .S) → Bool) :
    tabActive Ly.nG (⟨1, by norm_num⟩, Exec.msbBits 14 (blkExpTupGF w b).x.val)
      ∧ blkExpTupGF w b = tabTupE Pb.exp Pb.act Ly.nG 1
        (Exec.msbIndex 14 (Exec.msbBits 14 (blkExpTupGF w b).x.val)) := by
  let p := sPt Ly (splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b))
  have hs : splitS (Exec.Block.DefR13.cfgShieldR13 Ly) (castB (geoShield Ly).logS b) = (shdP_bitLay Ly).sPos p :=
    (sPos_sPt Ly _).symm
  have hexp : ExpTable Pb.exp (blkExpTupGF w b) := by
    unfold blkExpTupGF; rw [hs]; exact (codeTable_exp_iff r13Fams_ok Pb.exp Pb.act Ly.nG _ _).mp (w.hLook.sExp p)
  obtain ⟨i, hi0, hi1, hx, hy⟩ := (expQuery_iff Pb.exp _ _).mp hexp
  have hx' : (blkExpTupGF w b).x = (i : GF) := hx
  have hy' : (blkExpTupGF w b).y = (Pb.exp i : GF) := hy
  set n := i.toNat
  have hnZ : (n : ℤ) = i := Int.toNat_of_nonneg hi0
  have hn256 : n < 256 := by omega
  have hxv : (blkExpTupGF w b).x.val = n := by
    rw [hx', ← hnZ, Int.cast_natCast, ZMod.val_natCast, Nat.mod_eq_of_lt (by unfold gP; omega)]
  have hidx : Exec.msbIndex 14 (Exec.msbBits 14 (blkExpTupGF w b).x.val) = n := by
    rw [hxv]; exact Exec.msbIndex_msbBits 14 n (by omega)
  refine ⟨by
    unfold tabActive; dsimp only; rw [ite_eq_left (by norm_num : (1 : ℕ) < 2), hidx]; exact hn256, ?_⟩
  unfold tabTupE; rw [ite_eq_right (by norm_num), ite_eq_left rfl, hidx, Nat.mod_eq_of_lt hn256]
  exact Tup.ext' (by rw [hx', ← hnZ, Int.cast_natCast]) rfl (by rw [hy', hnZ]) rfl

private theorem blkLkTarget_spec_act {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut)
    (hnGle : Ly.nG ≤ 4) (hnGge : 1 ≤ Ly.nG)
    (b : Fin ((Exec.Block.DefR13.cfgShieldR13 Ly).sh.logs .F) → Bool) :
    tabActive Ly.nG (⟨2, by norm_num⟩, Exec.msbBits 14 ((blkActTupGF w b).z.val * 4096 + (blkActTupGF w b).x.val))
      ∧ blkActTupGF w b = tabTupE Pb.exp Pb.act Ly.nG 2
        (Exec.msbIndex 14 (Exec.msbBits 14 ((blkActTupGF w b).z.val * 4096 + (blkActTupGF w b).x.val))) := by
  suffices h_act : ∀ (u : Tup GF)
      (f : CtR (Exec.Block.DefR13.cfgShieldR13 Ly) × CfR (Exec.Block.DefR13.cfgShieldR13 Ly)),
      u = ⟨w.E.G f + 2048, ((tagAct : ℕ) : GF), w.E.A f, (shdP_w16Pub Ly Pb).grpCol f⟩ →
      tabActive Ly.nG (⟨2, by norm_num⟩, Exec.msbBits 14 (u.z.val * 4096 + u.x.val))
        ∧ u = tabTupE Pb.exp Pb.act Ly.nG 2
          (Exec.msbIndex 14 (Exec.msbBits 14 (u.z.val * 4096 + u.x.val))) by
    exact h_act (blkActTupGF w b) _ (blkActTupGF_eq w b)
  intro u f hu
  have hux0 : u.x = w.E.G f + 2048 := (congrArg Tup.x hu).trans (tup_x_mk _ _ _ _)
  have hutag0 : u.tag = ((tagAct : ℕ) : GF) := (congrArg Tup.tag hu).trans (tup_tag_mk _ _ _ _)
  have huy0 : u.y = w.E.A f := (congrArg Tup.y hu).trans (tup_y_mk _ _ _ _)
  have huz0 : u.z = (shdP_w16Pub Ly Pb).grpCol f := (congrArg Tup.z hu).trans (tup_z_mk _ _ _ _)
  by_cases hf : Exec.msbIndex 14 f.2 < 9216
  · obtain ⟨p, hfp⟩ : ∃ p : (shieldShape Ly).Tok × (shieldShape Ly).Hid, f = (shdP_bitLay Ly).fPos p :=
      ⟨(blkTokInv f.1, ⟨Exec.msbIndex 14 f.2, hf⟩),
        Prod.ext (emb_blkTokInv Ly f.1).symm (Exec.msbBits_msbIndex 14 f.2).symm⟩
    have hact : ActTable Pb.act Ly.nG (actQuery (w.E.G f) (w.E.A f) (Pb.grpF p.2)) := by
      rw [hfp]; exact (codeTable_act_iff r13Fams_ok Pb.exp Pb.act Ly.nG _ _ _).mp (w.hLook.fAct p)
    have hgrpLt : Pb.grpF p.2 < Ly.nG := w.hPb.grpF p.2
    obtain ⟨gi, hgi0, hgi1, hg, ha⟩ := (actQuery_iff Pb.act Ly.nG (by unfold gP; omega) _ _ _ hgrpLt).mp hact
    set m := (gi + 2048).toNat
    have hmZ : (m : ℤ) = gi + 2048 := Int.toNat_of_nonneg (by omega)
    have hm4096 : m < 4096 := by omega
    have hux : u.x = (m : GF) := by
      rw [hux0, hg, ← Int.cast_natCast (R := GF) m, hmZ, Int.cast_add, Int.cast_ofNat]
    have huxv : u.x.val = m := by rw [hux, ZMod.val_natCast, Nat.mod_eq_of_lt (by unfold gP; omega)]
    have huz : u.z = (Pb.grpF p.2 : GF) := by
      rw [huz0, hfp]; exact (shdP_w16Pub Ly Pb).grpCol_emb p
    have huzv : u.z.val = Pb.grpF p.2 := by rw [huz, ZMod.val_natCast, Nat.mod_eq_of_lt (by unfold gP; omega)]
    have hflatLt : Pb.grpF p.2 * 4096 + m < Ly.nG * 4096 :=
      lt_of_lt_of_le (Nat.add_lt_add_left hm4096 _)
        (by rw [← Nat.succ_mul]; exact Nat.mul_le_mul_right 4096 hgrpLt)
    have hidx : Exec.msbIndex 14 (Exec.msbBits 14 (u.z.val * 4096 + u.x.val)) = Pb.grpF p.2 * 4096 + m := by
      rw [huzv, huxv]; exact Exec.msbIndex_msbBits 14 _ (lt_of_lt_of_le hflatLt (by omega))
    refine ⟨by
      unfold tabActive; dsimp only; rw [ite_eq_right (by norm_num : ¬ (2 : ℕ) < 2), hidx]; exact hflatLt, ?_⟩
    unfold tabTupE
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_left rfl, hidx, ite_eq_left hflatLt,
      show (Pb.grpF p.2 * 4096 + m) / 4096 = Pb.grpF p.2 by omega,
      show (Pb.grpF p.2 * 4096 + m) % 4096 = m by omega]
    exact Tup.ext' hux hutag0 (by rw [huy0, ha, hmZ]) huz
  · have hG0 : w.E.G f = 0 := w.hPadF.G f.1 f.2 hf
    have hA0 : w.E.A f = 0 := w.hPadF.A f.1 f.2 hf
    have hgr0 : (shdP_w16Pub Ly Pb).grpCol f = 0 := shdP_w16Pub_grpCol_pad Ly Pb f hf
    have hux : u.x = ((2048 : ℕ) : GF) := by
      rw [hux0, hG0, zero_add, Nat.cast_ofNat]
    have huxv : u.x.val = 2048 := by rw [hux, ZMod.val_natCast, Nat.mod_eq_of_lt (by unfold gP; omega)]
    have huz : u.z = ((0 : ℕ) : GF) := by
      rw [huz0, Nat.cast_zero]; exact hgr0
    have huzv : u.z.val = 0 := by rw [huz, Nat.cast_zero]; exact ZMod.val_zero
    have hidx : Exec.msbIndex 14 (Exec.msbBits 14 (u.z.val * 4096 + u.x.val)) = 2048 := by
      rw [huzv, huxv, zero_mul, zero_add]; exact Exec.msbIndex_msbBits 14 2048 (by norm_num)
    refine ⟨by
      unfold tabActive; dsimp only; rw [ite_eq_right (by norm_num : ¬ (2 : ℕ) < 2), hidx]; omega, ?_⟩
    unfold tabTupE
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), ite_eq_left rfl, hidx,
      ite_eq_left (by omega : 2048 < Ly.nG * 4096),
      show 2048 / 4096 = 0 by norm_num, show 2048 % 4096 = 2048 by norm_num]
    exact Tup.ext' hux hutag0 (by rw [huy0, hA0, show ((2048 : ℕ) : ℤ) = 2048 by norm_num, w.hAct0, Int.cast_zero]) huz

/-- Every R13 lookup targets an active entry of `SC_TAB`, and equals that entry's `tabTupE`. -/
theorem blkLkTarget_spec {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (l : BlkLkIx Ly) :
    tabActive Ly.nG (blkLkTarget w l)
      ∧ blkLkTup w l = tabTupE Pb.exp Pb.act Ly.nG (blkLkTarget w l).1 (Exec.msbIndex 14 (blkLkTarget w l).2) := by
  have hc := lookCfg_shield Ly
  have hLyOk := shield_layers_ok Ly w.hLy
  have hnGle : Ly.nG ≤ 4 := hLyOk.2.2.2.2.2.2.2.2.2.2.1
  have hnGge : 1 ≤ Ly.nG := hLyOk.2.2.2.2.2.2.2.2.2.2.2
  rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩
  · cases s with
    | S => exact blkLkAtGF_hit w .S (2 * Dm.np 1 .S) (by rw [lkLen hc .S, ite_eq_left rfl]; omega) b
    | Exp => exact blkLkTarget_spec_exp w b
    | Act => exact blkLkTarget_spec_act w hnGle hnGge b
  · exact blkLkAtGF_hit w d (2 * j.val) (by rw [lkLen hc d]; have := j.isLt; omega) b
  · exact blkLkAtGF_hit w d (2 * j.val + 1) (by rw [lkLen hc d]; have := j.isLt; omega) b

theorem blkLkTarget_active {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (l : BlkLkIx Ly) :
    tabActive Ly.nG (blkLkTarget w l) := (blkLkTarget_spec w l).1

theorem blkLkTup_eq_tabTupE {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (l : BlkLkIx Ly) :
    blkLkTup w l = tabTupE Pb.exp Pb.act Ly.nG (blkLkTarget w l).1 (Exec.msbIndex 14 (blkLkTarget w l).2) :=
  (blkLkTarget_spec w l).2

theorem blkLkTup_eq_TR13 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (l : BlkLkIx Ly) :
    tupK (K := shdP_K) (blkLkTup w l) = TR13 (K := shdP_K) Pb.exp Pb.act Ly.nG (blkLkTarget w l) :=
  congrArg tupK (blkLkTup_eq_tabTupE w l)

/-- Exact LogUp multiplicity of table entry `j : TbIx` across all R13 lookups (`BlkLkIx Ly`). -/
noncomputable def blkMult {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (j : TbIx) : ℕ :=
  (Finset.univ.filter (fun l : BlkLkIx Ly => blkLkTarget w l = j)).card

/-- U8 (`mu8`), EXP (`mexp`), and ACT (`mact`) table multiplicity planes (`16384` entries each). -/
noncomputable def blkMultU8 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : ℕ :=
  blkMult w (⟨0, by norm_num⟩, Exec.msbBits 14 idx.val)
noncomputable def blkMultExp {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : ℕ :=
  blkMult w (⟨1, by norm_num⟩, Exec.msbBits 14 idx.val)
noncomputable def blkMultAct {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : ℕ :=
  blkMult w (⟨2, by norm_num⟩, Exec.msbBits 14 idx.val)

theorem blkMult_eq_zero_of_not_active {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (j : TbIx) (hj : ¬ tabActive Ly.nG j) :
    blkMult w j = 0 :=
  Finset.card_eq_zero.mpr (Finset.filter_eq_empty_iff.mpr fun l _ hEq => hj (hEq ▸ blkLkTarget_active w l))

theorem blkMultU8_pad {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) (h : ¬ idx.val < 256) :
    blkMultU8 w idx = 0 :=
  blkMult_eq_zero_of_not_active w _ (by
    unfold tabActive; dsimp only
    rw [ite_eq_left (by norm_num : (0 : ℕ) < 2), Exec.msbIndex_msbBits 14 idx.val idx.isLt]; exact h)

theorem blkMultExp_pad {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) (h : ¬ idx.val < 256) :
    blkMultExp w idx = 0 :=
  blkMult_eq_zero_of_not_active w _ (by
    unfold tabActive; dsimp only
    rw [ite_eq_left (by norm_num : (1 : ℕ) < 2), Exec.msbIndex_msbBits 14 idx.val idx.isLt]; exact h)

theorem blkMultAct_pad {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) (h : ¬ idx.val < Ly.nG * 4096) :
    blkMultAct w idx = 0 :=
  blkMult_eq_zero_of_not_active w _ (by
    unfold tabActive; dsimp only
    rw [ite_eq_right (by norm_num : ¬ (2 : ℕ) < 2), Exec.msbIndex_msbBits 14 idx.val idx.isLt]; exact h)

/-- Every multiplicity count is strictly below `gP` (via `hN_shield`: total lookups `66,879,488 < gP`). -/
theorem blkMult_lt_gP {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (j : TbIx) : blkMult w j < gP := by
  have hle : blkMult w j ≤ Fintype.card (BlkLkIx Ly) :=
    (Finset.card_filter_le _ _).trans_eq Finset.card_univ
  have hcard : Fintype.card (BlkLkIx Ly) =
      Fintype.card (SgIx (Exec.Block.DefR13.cfgShieldR13 Ly)) +
        2 * Fintype.card (PrIx (Exec.Block.DefR13.cfgShieldR13 Ly) 1) := by
    rw [Fintype.card_sum, Fintype.card_sum]; ring
  have hN := hN_shield (K := shdP_K) Ly
  rw [ZK60.Exec.ringChar_eq_gP] at hN; omega

theorem blkMultU8_lt_gP {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : blkMultU8 w idx < gP :=
  blkMult_lt_gP w _
theorem blkMultExp_lt_gP {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : blkMultExp w idx < gP :=
  blkMult_lt_gP w _
theorem blkMultAct_lt_gP {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (idx : Fin 16384) : blkMultAct w idx < gP :=
  blkMult_lt_gP w _

/-- Non-pole propagation: if every active table entry has `α - fold β γ (TR13 ... j) ≠ 0`,
then every R13 lookup `l : BlkLkIx Ly` has `α - fold β γ (tupK (blkLkTup w l)) ≠ 0`. -/
theorem blkLk_denom_ne_zero {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (β γ α : shdP_K)
    (hne : ∀ j : TbIx, tabActive Ly.nG j → α - fold β γ (TR13 Pb.exp Pb.act Ly.nG j) ≠ 0) (l : BlkLkIx Ly) :
    α - fold β γ (tupK (blkLkTup w l)) ≠ 0 := by
  rw [blkLkTup_eq_TR13 w l]; exact hne (blkLkTarget w l) (blkLkTarget_active w l)

/-- General fiberwise partition identity across all R13 lookups and all `TbIx`. -/
theorem blkMult_sum_fiber_all {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (φ : Tup shdP_K → shdP_K) :
    ∑ l : BlkLkIx Ly, φ (tupK (blkLkTup w l))
      = ∑ j : TbIx, (blkMult w j : shdP_K) * φ (TR13 Pb.exp Pb.act Ly.nG j) := by
  rw [Finset.sum_congr rfl (fun l _ => congrArg φ (blkLkTup_eq_TR13 w l)),
    ← Finset.sum_fiberwise' Finset.univ (blkLkTarget w) (fun j => φ (TR13 Pb.exp Pb.act Ly.nG j))]
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [Finset.sum_const, nsmul_eq_mul]; rfl

/-- General fiberwise partition identity restricted to active `TbIx` entries. -/
theorem blkMult_sum_fiber {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (φ : Tup shdP_K → shdP_K) :
    ∑ l : BlkLkIx Ly, φ (tupK (blkLkTup w l))
      = ∑ j ∈ Finset.univ.filter (fun j : TbIx => tabActive Ly.nG j),
          (blkMult w j : shdP_K) * φ (TR13 Pb.exp Pb.act Ly.nG j) := by
  have hzero : ∑ j ∈ Finset.univ.filter (fun j : TbIx => ¬ tabActive Ly.nG j),
      (blkMult w j : shdP_K) * φ (TR13 Pb.exp Pb.act Ly.nG j) = 0 :=
    Finset.sum_eq_zero fun j hj => by
      rw [blkMult_eq_zero_of_not_active w j (Finset.mem_filter.mp hj).2, Nat.cast_zero, zero_mul]
  rw [blkMult_sum_fiber_all w φ,
    ← Finset.sum_filter_add_sum_filter_not Finset.univ (fun j : TbIx => tabActive Ly.nG j), hzero, add_zero]

/-- **Exact LogUp fiberwise sum identity** over `BlkLkIx Ly` and active `TbIx`. -/
theorem blkMult_logup_sum {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (β γ α : shdP_K)
    (_hne : ∀ j : TbIx, tabActive Ly.nG j → α - fold β γ (TR13 Pb.exp Pb.act Ly.nG j) ≠ 0) :
    ∑ l : BlkLkIx Ly, (α - fold β γ (tupK (blkLkTup w l)))⁻¹
      = ∑ j ∈ Finset.univ.filter (fun j : TbIx => tabActive Ly.nG j),
          (blkMult w j : shdP_K) * (α - fold β γ (TR13 Pb.exp Pb.act Ly.nG j))⁻¹ :=
  blkMult_sum_fiber w (fun q => (α - fold β γ q)⁻¹)

private theorem sum_bits14_active (N : ℕ) (hN : N ≤ 16384) (m : Fin 16384 → ℕ)
    (hm : ∀ idx : Fin 16384, ¬ idx.val < N → m idx = 0) (f : ℕ → shdP_K) :
    (∑ b : Fin 14 → Bool, (m ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩ : shdP_K) * f (Exec.msbIndex 14 b))
      = ∑ idx : Fin N, (m ⟨idx.val, by omega⟩ : shdP_K) * f idx.val := by
  let e14 : (Fin 14 → Bool) ≃ Fin 16384 :=
    { toFun := fun b => ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩,
      invFun := fun idx => Exec.msbBits 14 idx.val,
      left_inv := fun b => Exec.msbBits_msbIndex 14 b,
      right_inv := fun idx => Fin.ext (Exec.msbIndex_msbBits 14 idx.val idx.isLt) }
  have hcomp : (∑ b : Fin 14 → Bool, (m ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩ : shdP_K) * f (Exec.msbIndex 14 b))
      = ∑ idx : Fin 16384, (m idx : shdP_K) * f idx.val :=
    Equiv.sum_comp e14 (fun idx : Fin 16384 => (m idx : shdP_K) * f idx.val)
  have hzero : ∑ idx ∈ Finset.univ.filter (fun idx : Fin 16384 => ¬ idx.val < N),
      (m idx : shdP_K) * f idx.val = 0 :=
    Finset.sum_eq_zero fun idx hidx => by
      rw [hm idx (Finset.mem_filter.mp hidx).2, Nat.cast_zero, zero_mul]
  rw [hcomp, ← Finset.sum_filter_add_sum_filter_not Finset.univ (fun idx : Fin 16384 => idx.val < N),
    hzero, add_zero]
  exact Finset.sum_bij
    (fun (idx : Fin 16384) (hidx : idx ∈ Finset.univ.filter (fun idx : Fin 16384 => idx.val < N)) =>
      (⟨idx.val, (Finset.mem_filter.mp hidx).2⟩ : Fin N))
    (fun _ _ => Finset.mem_univ _) (fun a _ b _ h => Fin.ext (congrArg (Fin.val : Fin N → ℕ) h))
    (fun idx _ => ⟨⟨idx.val, lt_of_lt_of_le idx.isLt hN⟩, Finset.mem_filter.mpr ⟨Finset.mem_univ _, idx.isLt⟩, Fin.ext rfl⟩)
    (fun _ _ => rfl)

/-- **3-table expanded LogUp fiberwise sum identity** in terms of `blkMultU8`, `blkMultExp`, `blkMultAct`. -/
theorem blkMult_logup_sum_3 {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (β γ α : shdP_K)
    (_hne : ∀ j : TbIx, tabActive Ly.nG j → α - fold β γ (TR13 Pb.exp Pb.act Ly.nG j) ≠ 0) :
    ∑ l : BlkLkIx Ly, (α - fold β γ (tupK (blkLkTup w l)))⁻¹
      = (∑ idx : Fin 256,
            (blkMultU8 w ⟨idx.val, by omega⟩ : shdP_K)
              * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 0 idx.val)))⁻¹)
        + (∑ idx : Fin 256,
            (blkMultExp w ⟨idx.val, by omega⟩ : shdP_K)
              * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 1 idx.val)))⁻¹)
        + (∑ idx : Fin (Ly.nG * 4096),
            (blkMultAct w ⟨idx.val, lt_of_lt_of_le idx.isLt
                (by have := (shield_layers_ok Ly w.hLy).2.2.2.2.2.2.2.2.2.2.1; omega)⟩ : shdP_K)
              * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 2 idx.val)))⁻¹) := by
  have hnG : Ly.nG * 4096 ≤ 16384 := by have := (shield_layers_ok Ly w.hLy).2.2.2.2.2.2.2.2.2.2.1; omega
  rw [blkMult_sum_fiber_all w (fun q => (α - fold β γ q)⁻¹), Fintype.sum_prod_type, Fin.sum_univ_three]
  have h0 : (∑ b : Fin 14 → Bool, (blkMult w (0, b) : shdP_K) * (α - fold β γ (TR13 Pb.exp Pb.act Ly.nG (0, b)))⁻¹)
      = ∑ idx : Fin 256, (blkMultU8 w ⟨idx.val, by omega⟩ : shdP_K)
          * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 0 idx.val)))⁻¹ := by
    simp_rw [show ∀ b : Fin 14 → Bool, blkMult w (0, b) = blkMultU8 w ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩ from
      fun b => by unfold blkMultU8; dsimp only; rw [Exec.msbBits_msbIndex 14 b]; rfl]
    exact sum_bits14_active 256 (by norm_num) (blkMultU8 w) (blkMultU8_pad w)
      (fun i => (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 0 i)))⁻¹)
  have h1 : (∑ b : Fin 14 → Bool, (blkMult w (1, b) : shdP_K) * (α - fold β γ (TR13 Pb.exp Pb.act Ly.nG (1, b)))⁻¹)
      = ∑ idx : Fin 256, (blkMultExp w ⟨idx.val, by omega⟩ : shdP_K)
          * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 1 idx.val)))⁻¹ := by
    simp_rw [show ∀ b : Fin 14 → Bool, blkMult w (1, b) = blkMultExp w ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩ from
      fun b => by unfold blkMultExp; dsimp only; rw [Exec.msbBits_msbIndex 14 b]; rfl]
    exact sum_bits14_active 256 (by norm_num) (blkMultExp w) (blkMultExp_pad w)
      (fun i => (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 1 i)))⁻¹)
  have h2 : (∑ b : Fin 14 → Bool, (blkMult w (2, b) : shdP_K) * (α - fold β γ (TR13 Pb.exp Pb.act Ly.nG (2, b)))⁻¹)
      = ∑ idx : Fin (Ly.nG * 4096), (blkMultAct w ⟨idx.val, lt_of_lt_of_le idx.isLt hnG⟩ : shdP_K)
          * (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 2 idx.val)))⁻¹ := by
    simp_rw [show ∀ b : Fin 14 → Bool, blkMult w (2, b) = blkMultAct w ⟨Exec.msbIndex 14 b, Exec.msbIndex_lt 14 b⟩ from
      fun b => by unfold blkMultAct; dsimp only; rw [Exec.msbBits_msbIndex 14 b]; rfl]
    exact sum_bits14_active (Ly.nG * 4096) hnG (blkMultAct w) (blkMultAct_pad w)
      (fun i => (α - fold β γ (tupK (tabTupE Pb.exp Pb.act Ly.nG 2 i)))⁻¹)
  rw [h0, h1, h2]

end BlockLogUp

end ZK60.HonestShield
