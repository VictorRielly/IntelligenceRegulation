/-
D63 lane L69, Milestone B Part 2b (`HonestShieldZKTraceExtract.lean`):
1. **Row-by-row `stdRowOf` / `hRowOf` agreement across all 84 PCS tables** (`B_0..26`, `A_0..27`, `H_0..27`),
   together with `hdH` discharges for Stage IN-C, all 26 R13 blocks, and Stage OUT-C.
2. **Exact `.res` trace extractors for `openingAuditFixedProg`, `zkBMaskFixedProg`, `slotProveFixedProg`,
   `slotsProveFixedProg`, and `stSlotsProveFixedProg`**:
   - Proves that every active run extracts exact `v`-only challenges (`lams`, `proxR`, `idxs`, `θ`, `rs`,
     `draws`, `c ≠ 0`, `rhoFull`, `es` good, `df`, `acc.claims.*.map ZClaim.parts`, `acc.fs ++ acc.hostFs` terms).
3. **`SlotAcc` → `codeFuns` & `stgPrivVals` → `X₁` Bridges**:
   - Proves `acc.fs ++ acc.hostFs` aligns 1-to-1 with `codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)`,
     discharging `segMOpenPub_hW` and `segMOpenPub_hlay` uniformly across all 28 segments.
   - Proves every `.priv p` claim in every slot's `df.tabs` lands in `acc.claims.{a, h, inp, out}`,
     expressing both `stgPrivVals` (`SlotProof.terms`) and `slotPolyK`/`blkSlotPolyK` at `vecK rhoFull`
     as pure functions of `ShdL1View`.

Uses only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKSegView

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Hiding ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest
open ZK60.HonestClassify ZK60.HonestOpen ZK60.ProtocolClassify ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldS0 ShieldRun shieldShape)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Slot.W16R2 (Kind kindOf hostsOf nSlots)
open ZK60.Exec.Block (BlockParams SlotDef SlotProof SlotRec SlotKind Cm Tab Acc Hist Claims4 Priv)
open ZK60.Exec.StageV (atLog sdAt)

/-! ## 1. Row-by-Row `stdRowOf` / `hRowOf` Bridges Across All 84 PCS Tables -/

section TableRowBridges

/-- Generic helper: `mkRows` with `packStdPads c` and data rows matching `dat` / `packSiteMask` / `packProxMask`
equals `rowAt (stdRowOf dat c r) k` at every `r < d + 2*g + 2` and `k < n + 256`! -/
theorem mkRows_std_eq {n d g : ℕ} (dat : Fin d → Fin n → GF)
    (c : Hiding.Coins GF n 256 (Fin d) (Fin g))
    (f : Fin (d + 2 * g + 2) → Fin n → Fp)
    (hfDat : ∀ (i : Fin d) (col : Fin n), (f ⟨i.val, by omega⟩ col).toGF = dat i col)
    (hfSite : ∀ (r : Fin (d + 2 * g + 2)) (h1 : ¬ r.val < d) (h2 : r.val < d + 2 * g) (col : Fin n),
      (f r col).toGF = packSiteMask c.2.1 ⟨r.val - d, by omega⟩ col)
    (hfProx : ∀ (r : Fin (d + 2 * g + 2)) (h1 : ¬ r.val < d + 2 * g) (col : Fin n),
      (f r col).toGF = packProxMask c.2.2 ⟨r.val - (d + 2 * g), by omega⟩ col)
    (r : Fin (d + 2 * g + 2)) (k : ℕ) (hk : k < n + 256) :
    (((mkRows (d + 2 * g + 2) n 256 f (packStdPads c)).getD r.val []).getD k Fp.zero).toGF
      = rowAt (stdRowOf dat c r) k := by
  rw [mkRows_getD_eq _ _ _ _ _ r.val k r.isLt hk]
  unfold rowAt stdRowOf packStdPads rowPadFp
  by_cases hk1 : k < n
  · rw [dite_eq_left hk1, dite_eq_left hk1]
    by_cases h1 : r.val < d
    · rw [dite_eq_left h1]
      exact hfDat ⟨r.val, h1⟩ ⟨k, hk1⟩
    · rw [dite_eq_right h1]
      by_cases h2 : r.val < d + 2 * g
      · rw [dite_eq_left h2]
        simpa only [packSiteMask, rowMsg] using hfSite r h1 h2 ⟨k, hk1⟩
      · rw [dite_eq_right h2]
        have hp := hfProx r h2 ⟨k, hk1⟩
        have hsub : (r.val - (d + 2 * g) = 0) ↔ (r.val = d + 2 * g) := by omega
        simpa only [packProxMask, rowMsg, hsub] using hp
  · have hk2 : k - n < 256 := by omega
    rw [dite_eq_right hk1, dite_eq_right hk1, dite_eq_left hk2]
    by_cases h1 : r.val < d
    · rw [dite_eq_left h1, dite_eq_left h1, Fp.toGF_ofGF]; rfl
    · rw [dite_eq_right h1, dite_eq_right h1]
      by_cases h2 : r.val < d + 2 * g
      · rw [dite_eq_left h2, dite_eq_left h2, Fp.toGF_ofGF]
      · rw [dite_eq_right h2, dite_eq_right h2, Fp.toGF_ofGF]

/-- Generic helper: `mkRows` with `packHPads c` and data / `shdP_zsGen` / `packSiteMask` / `packProxMask`
equals `rowAt (hRowOf dat c r) k` at every `r < d + 2 + 2*g + 2` and `k < n + 256`! -/
theorem mkRows_h_eq {n d g : ℕ} (dat : Fin d → Fin n → GF)
    (c : Hiding.CoinsH GF n 256 (Fin d) (Fin g))
    (f : Fin (d + 2 + 2 * g + 2) → Fin n → Fp)
    (hfDat : ∀ (i : Fin d) (col : Fin n), (f ⟨i.val, by omega⟩ col).toGF = dat i col)
    (hfU : ∀ (b : Bool) (col : Fin n),
      (f ⟨if b then d else d + 1, by cases b <;> simp only [↓reduceIte, Bool.false_eq_true] <;> omega⟩ col).toGF
        = shdP_zsGen (fun j => rowMsg (c.2.1 b) j) col)
    (hfSite : ∀ (r : Fin (d + 2 + 2 * g + 2)) (h1 : ¬ r.val < d + 2) (h2 : r.val < d + 2 + 2 * g) (col : Fin n),
      (f r col).toGF = packSiteMask c.2.2.1 ⟨r.val - (d + 2), by omega⟩ col)
    (hfProx : ∀ (r : Fin (d + 2 + 2 * g + 2)) (h1 : ¬ r.val < d + 2 + 2 * g) (col : Fin n),
      (f r col).toGF = packProxMask c.2.2.2 ⟨r.val - (d + 2 + 2 * g), by omega⟩ col)
    (r : Fin (d + 2 + 2 * g + 2)) (k : ℕ) (hk : k < n + 256) :
    (((mkRows (d + 2 + 2 * g + 2) n 256 f (packHPads c)).getD r.val []).getD k Fp.zero).toGF
      = rowAt (hRowOf dat c r) k := by
  rw [mkRows_getD_eq _ _ _ _ _ r.val k r.isLt hk]
  unfold rowAt hRowOf packHPads rowPadFp Hiding.zsRow
  by_cases hk1 : k < n
  · rw [dite_eq_left hk1, dite_eq_left hk1]
    by_cases h1 : r.val < d
    · rw [dite_eq_left h1]
      exact hfDat ⟨r.val, h1⟩ ⟨k, hk1⟩
    · rw [dite_eq_right h1]
      by_cases h2 : r.val < d + 2
      · rw [dite_eq_left h2]
        by_cases hEq : r.val = d
        · have hr : r = ⟨d, by omega⟩ := Fin.ext hEq
          rw [hr]; simpa only [↓reduceIte, decide_true, Sum.elim_inl, rowMsg] using hfU true ⟨k, hk1⟩
        · have hEq1 : r.val = d + 1 := by omega
          have hr : r = ⟨d + 1, by omega⟩ := Fin.ext hEq1
          rw [hr]; simpa only [Bool.false_eq_true, ↓reduceIte, show d + 1 ≠ d by omega, decide_false, Sum.elim_inl, rowMsg] using hfU false ⟨k, hk1⟩
      · rw [dite_eq_right h2]
        by_cases h3 : r.val < d + 2 + 2 * g
        · rw [dite_eq_left h3]
          simpa only [packSiteMask, rowMsg] using hfSite r h2 h3 ⟨k, hk1⟩
        · rw [dite_eq_right h3]
          have hp := hfProx r h3 ⟨k, hk1⟩
          have hsub : (r.val - (d + 2 + 2 * g) = 0) ↔ (r.val = d + 2 + 2 * g) := by omega
          simpa only [packProxMask, rowMsg, hsub] using hp
  · have hk2 : k - n < 256 := by omega
    rw [dite_eq_right hk1, dite_eq_right hk1, dite_eq_left hk2]
    by_cases h1 : r.val < d
    · rw [dite_eq_left h1, dite_eq_left h1, Fp.toGF_ofGF]; rfl
    · rw [dite_eq_right h1, dite_eq_right h1]
      by_cases h2 : r.val < d + 2
      · rw [dite_eq_left h2, dite_eq_left h2, Fp.toGF_ofGF]; rfl
      · rw [dite_eq_right h2, dite_eq_right h2]
        by_cases h3 : r.val < d + 2 + 2 * g
        · rw [dite_eq_left h3, dite_eq_left h3, Fp.toGF_ofGF]
        · rw [dite_eq_right h3, dite_eq_right h3, Fp.toGF_ofGF]

/-- Data-row extractors for Stage IN-C `A`, `H`, and `B_0..26`, R13 Block `A`, `H`, and Stage OUT-C `A`, `H`. -/
noncomputable def incADat (x : shieldS0.Tok → ℕ) (i : Fin 33) (col : Fin 4096) : GF :=
  (shdP_incTAData x (shdIncRndOf default) ⟨i.val, by omega⟩ col).toGF

noncomputable def incHDat (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (ch : List Fp2)
    (x : shieldS0.Tok → ℕ) (i : Fin 66) (col : Fin 4096) : GF :=
  (shdP_incTHData Rp embDigest x (shdIncRndOf default) ch ⟨i.val, by omega⟩ col).toGF

noncomputable def bndDatAt (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (k : Fin 27) (x : {x // (classifyModelP Rp).admissible x}) (i : Fin 32) (col : Fin 16384) : GF :=
  (shdP_outcBndData (shdP_blkState Rp hR hweights hinPub x.1 x.2 k) (shdBndRndOf default k)
    ⟨i.val, by omega⟩ col).toGF

noncomputable def blkADat (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (k : Fin 26) (x : {x // (classifyModelP Rp).admissible x}) (i : Fin 4283) (col : Fin 16384) : GF :=
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
  (blkTAData w (shdBlkRndOf default k) ⟨i.val, by omega⟩ col).toGF

noncomputable def blkHDat (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (k : Fin 26) (bga : Fp2 × Fp2 × Fp2) (x : {x // (classifyModelP Rp).admissible x})
    (i : Fin 4280) (col : Fin 16384) : GF :=
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
  (blkTHData w (shdBlkRndOf default k) bga ⟨i.val, by omega⟩ col).toGF

noncomputable def outcADat (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (i : Fin 16) (col : Fin 4096) : GF :=
  (shdP_outcTAData Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf default) ⟨i.val, by omega⟩ col).toGF

noncomputable def outcHDat (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (gamma alpha : Fp2) (x : {x // (classifyModelP Rp).admissible x}) (i : Fin 16) (col : Fin 4096) : GF :=
  (shdP_outcTHData Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf default) gamma alpha
    ⟨i.val, by omega⟩ col).toGF

private theorem mkPcsTable_rows_eq (logN lr q : ℕ) (h : logN ≤ 32)
    (rows : List (List Fp)) (salts : ℕ → Dig) :
    (mkPcsTable logN lr q h rows salts).rows = rows := rfl

private theorem blkTAData_indep_rnd {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (r₁ r₂ : BlkRand)
    (i : Fin 4283) (col : Fin 16384) :
    blkTAData w r₁ ⟨i.val, by omega⟩ col = blkTAData w r₂ ⟨i.val, by omega⟩ col := by
  unfold blkTAData; dsimp only
  have hlt := i.isLt
  by_cases h0 : i.val = 0; · simp only [h0, ↓reduceIte]
  simp only [h0, ↓reduceIte]
  by_cases h1 : i.val = 1; · simp only [h1, ↓reduceIte]
  simp only [h1, ↓reduceIte]
  by_cases h2 : i.val = 2; · simp only [h2, ↓reduceIte]
  simp only [h2, ↓reduceIte]
  by_cases h3 : i.val = 3; · simp only [h3, ↓reduceIte]
  simp only [h3, ↓reduceIte]
  by_cases h4 : i.val = 4; · simp only [h4, ↓reduceIte]
  simp only [h4, ↓reduceIte]
  by_cases h5 : i.val = 5; · simp only [h5, ↓reduceIte]
  simp only [h5, ↓reduceIte]
  by_cases h6 : i.val = 6; · simp only [h6, ↓reduceIte]
  simp only [h6, ↓reduceIte]
  by_cases h7 : i.val = 7; · simp only [h7, ↓reduceIte]
  simp only [h7, ↓reduceIte]
  by_cases h8 : i.val < 1256; · simp only [h8, ↓reduceIte]
  simp only [h8, ↓reduceIte]
  by_cases h9 : i.val < 1704; · simp only [h9, ↓reduceIte]
  simp only [h9, ↓reduceIte]
  by_cases h10 : i.val < 1816; · simp only [h10, ↓reduceIte]
  simp only [h10, ↓reduceIte]
  by_cases h11 : i.val < 2232; · simp only [h11, ↓reduceIte]
  simp only [h11, ↓reduceIte]
  by_cases h12 : i.val < 4280; · simp only [h12, ↓reduceIte]
  simp only [h12, ↓reduceIte]
  by_cases h13 : i.val = 4280; · simp only [h13, ↓reduceIte]
  simp only [h13, ↓reduceIte]
  by_cases h14 : i.val = 4281; · simp only [h14, ↓reduceIte]
  simp only [h14, ↓reduceIte, show i.val = 4282 by omega]

private theorem blkHValK_indep_rnd {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)}
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness Ly Pb xIn xOut) (r₁ r₂ : BlkRand)
    (bga : Fp2 × Fp2 × Fp2) (hp idx : ℕ) (hlt : hp < 52) :
    blkHValK w r₁ bga hp idx = blkHValK w r₂ bga hp idx := by
  unfold blkHValK
  by_cases h0 : hp < 1; · simp only [h0, ↓reduceIte]
  simp only [h0, ↓reduceIte]
  by_cases h1 : hp < 18; · simp only [h1, ↓reduceIte]
  simp only [h1, ↓reduceIte]
  by_cases h2 : hp < 25; · simp only [h2, ↓reduceIte]
  simp only [h2, ↓reduceIte]
  by_cases h3 : hp < 32; · simp only [h3, ↓reduceIte]
  simp only [h3, ↓reduceIte]
  by_cases h4 : hp < 39; · simp only [h4, ↓reduceIte]
  simp only [h4, ↓reduceIte]
  by_cases h5 : hp = 39; · simp only [h5, ↓reduceIte]
  simp only [h5, ↓reduceIte]
  by_cases h6 : hp = 40; · simp only [h6, ↓reduceIte]
  simp only [h6, ↓reduceIte]
  by_cases h7 : hp < 48; · simp only [h7, ↓reduceIte]
  simp only [h7, ↓reduceIte]
  by_cases h8 : hp = 48; · simp only [h8, ↓reduceIte]
  simp only [h8, ↓reduceIte, dite_eq_left hlt]

private theorem shdP_outcTAData_indep_rnd (Rp : ClassifyRunPublicP shieldS0)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (r₁ r₂ : OutcRand)
    (i : Fin 16) (col : Fin 4096) :
    shdP_outcTAData Rp w r₁ ⟨i.val, by omega⟩ col = shdP_outcTAData Rp w r₂ ⟨i.val, by omega⟩ col := by
  unfold shdP_outcTAData; dsimp only
  have hlt := i.isLt
  by_cases h0 : i.val = 0; · simp only [h0, ↓reduceIte]
  simp only [h0, ↓reduceIte]
  by_cases h1 : i.val = 1; · simp only [h1, ↓reduceIte]
  simp only [h1, ↓reduceIte]
  by_cases h2 : i.val = 2; · simp only [h2, ↓reduceIte]
  simp only [h2, ↓reduceIte]
  by_cases h3 : i.val = 3; · simp only [h3, ↓reduceIte]
  simp only [h3, ↓reduceIte]
  by_cases h4 : i.val = 4; · simp only [h4, ↓reduceIte]
  simp only [h4, ↓reduceIte]
  by_cases h5 : i.val = 5; · simp only [h5, ↓reduceIte]
  simp only [h5, ↓reduceIte]
  by_cases h6 : i.val = 6; · simp only [h6, ↓reduceIte]
  simp only [h6, ↓reduceIte]
  by_cases h7 : i.val < 15; · simp only [h7, ↓reduceDIte]
  simp only [h7, ↓reduceDIte, show i.val = 15 by omega, ↓reduceIte]

/-- Stage IN-C `TA` matches `stdRowOf (incADat x) (c.1.2.2 0).1.1`. -/
theorem shdP_incTA_rows_eq (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (r : Fin 41) (k : ℕ) (hk : k < 4096 + 256) :
    (((shdP_incTA x (shdIncRndOf c)).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (stdRowOf (incADat x) (c.1.2.2 ⟨0, by decide⟩).1.1 r) k := by
  refine mkRows_std_eq (incADat x) (c.1.2.2 ⟨0, by decide⟩).1.1 (shdP_incTAData x (shdIncRndOf c))
    ?_ ?_ ?_ r k hk
  · intro i col; unfold incADat shdP_incTAData
    by_cases h0 : i.val = 0
    · rw [ite_eq_left h0, ite_eq_left h0]
    · rw [ite_eq_right h0, ite_eq_right h0, ite_eq_left i.isLt, ite_eq_left i.isLt]
  · intro r' h1 h2 col
    unfold shdP_incTAData
    rw [ite_eq_right (by omega), ite_eq_right h1, dite_eq_left h2, Fp.toGF_ofGF]; rfl
  · intro r' h1 col
    unfold shdP_incTAData
    rw [ite_eq_right (by omega), ite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]; rfl

/-- Stage IN-C `TH` matches `hRowOf (incHDat ...) (c.1.2.2 0).1.2`. -/
theorem shdP_incTH_rows_eq (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (ch : List Fp2)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (r : Fin 76) (k : ℕ) (hk : k < 4096 + 256) :
    (((shdP_incTH Rp embDigest x (shdIncRndOf c) ch).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (hRowOf (incHDat Rp embDigest ch x) (c.1.2.2 ⟨0, by decide⟩).1.2 r) k := by
  refine mkRows_h_eq (incHDat Rp embDigest ch x) (c.1.2.2 ⟨0, by decide⟩).1.2
    (shdP_incTHData Rp embDigest x (shdIncRndOf c) ch) ?_ ?_ ?_ ?_ r k hk
  · intro i col; unfold incHDat shdP_incTHData; dsimp only
    by_cases h0 : i.val = 0
    · simp only [h0, ↓reduceIte]
    · by_cases h1 : i.val = 1
      · simp only [h1, ↓reduceIte]
      · by_cases h34 : i.val < 34
        · simp only [h0, h1, h34, ↓reduceIte]
        · simp only [h0, h1, h34, i.isLt, ↓reduceIte]
  · intro b col
    cases b with
    | true =>
      unfold shdP_incTHData; dsimp only
      simp only [show (66 : ℕ) ≠ 0 by omega, show (66 : ℕ) ≠ 1 by omega, show ¬ (66 : ℕ) < 34 by omega,
        show ¬ (66 : ℕ) < 66 by omega, ↓reduceIte, Fp.toGF_ofGF]
      have h := congrArg Prod.fst (huVal_eq_zsGen (n := 4096) (by norm_num) (shdIncRndOf c).hURaw col)
      exact h
    | false =>
      have hidx : (⟨if false then 66 else 66 + 1, by simp only [Bool.false_eq_true, ↓reduceIte]; omega⟩ : Fin 76) = ⟨67, by decide⟩ := Fin.ext rfl
      rw [hidx]
      unfold shdP_incTHData
      rw [ite_eq_right (by decide), ite_eq_right (by decide), ite_eq_right (by decide),
        ite_eq_right (by decide), ite_eq_right (by decide), ite_eq_left rfl, Fp.toGF_ofGF]
      exact congrArg Prod.snd (huVal_eq_zsGen (n := 4096) (by norm_num) (shdIncRndOf c).hURaw col)
  · intro r' h1 h2 col
    unfold shdP_incTHData; dsimp only
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), dite_eq_left h2, Fp.toGF_ofGF]; rfl
  · intro r' h1 col
    unfold shdP_incTHData; dsimp only
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]; rfl

/-- All 27 boundary tables `B_0..26` (`shdP_bndTableAt`) match `stdRowOf (bndDatAt ... k x) (c.1.2.1 k).1`! -/
theorem shdP_bndTableAt_rows_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (idx : Fin 27)
    (r : Fin 38) (k : ℕ) (hk : k < 16384 + 256) :
    (((shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 idx).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (stdRowOf (bndDatAt Rp hR hweights hinPub idx x) (c.1.2.1 idx).1 r) k := by
  rcases idx with ⟨j, hj⟩
  cases j with
  | zero =>
    change (((shdP_incTB Rp x.1 (shdIncRndOf c)).rows.getD r.val []).getD k Fp.zero).toGF = _
    refine mkRows_std_eq (bndDatAt Rp hR hweights hinPub ⟨0, hj⟩ x) (c.1.2.1 ⟨0, hj⟩).1
      (shdP_incTBData Rp x.1 (shdIncRndOf c)) ?_ ?_ ?_ r k hk
    · intro i col
      unfold bndDatAt shdP_incTBData shdP_outcBndData
      dsimp only
      rw [dite_eq_left i.isLt, dite_eq_left i.isLt]
      split_ifs with hc
      · congr 2
      · rfl
    · intro r' h1 h2 col
      unfold shdP_incTBData; dsimp only
      rw [dite_eq_right h1, dite_eq_left h2, Fp.toGF_ofGF]; rfl
    · intro r' h1 col
      unfold shdP_incTBData; dsimp only
      rw [dite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]; rfl
  | succ m =>
    change (((shdP_outcBndTable (shdP_blkState Rp hR hweights hinPub x.1 x.2 ⟨m + 1, hj⟩)
      (shdBlkRndOf c ⟨m, by omega⟩).bnd).rows.getD r.val []).getD k Fp.zero).toGF = _
    refine mkRows_std_eq (bndDatAt Rp hR hweights hinPub ⟨m + 1, hj⟩ x) (c.1.2.1 ⟨m + 1, hj⟩).1
      (shdP_outcBndData (shdP_blkState Rp hR hweights hinPub x.1 x.2 ⟨m + 1, hj⟩) (shdBlkRndOf c ⟨m, by omega⟩).bnd)
      ?_ ?_ ?_ r k hk
    · intro i col; unfold bndDatAt shdP_outcBndData; dsimp only; rw [dite_eq_left i.isLt, dite_eq_left i.isLt]
    · intro r' h1 h2 col
      unfold shdP_outcBndData; dsimp only
      rw [dite_eq_right h1, dite_eq_left h2, Fp.toGF_ofGF]; rfl
    · intro r' h1 col
      unfold shdP_outcBndData; dsimp only
      rw [dite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]; rfl

/-- Helper: cast `c.1.2.2 ⟨k.val + 1, _⟩` to `PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩`. -/
def blkAHCoins (c : ShdCoins) (k : Fin 26) : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩ :=
  have hah : shdP_L1Spec.ah ⟨k.val + 1, by omega⟩ = ⟨shdP_blkASpec, shdP_blkHSpec⟩ := by
    dsimp only [shdP_L1Spec]
    rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  hah ▸ c.1.2.2 ⟨k.val + 1, by omega⟩

/-- Interior block `k : Fin 26` `TA` matches `stdRowOf (blkADat ... k x) (blkAHCoins c k).1.1`! -/
theorem blkTA_rows_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (k : Fin 26)
    (r : Fin 4577) (j : ℕ) (hj : j < 16384 + 256) :
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    (((blkTA w (shdBlkRndOf c k)).rows.getD r.val []).getD j Fp.zero).toGF
      = rowAt (stdRowOf (blkADat Rp hR hweights hinPub k x) (blkAHCoins c k).1.1 r) j := by
  dsimp only
  unfold blkTA
  rw [mkPcsTable_rows_eq]
  have hpads : (shdBlkRndOf c k).aPads = packStdPads (blkAHCoins c k).1.1 := rfl
  rw [hpads]
  exact mkRows_std_eq (n := 16384) (d := 4283) (g := 146)
    (blkADat Rp hR hweights hinPub k x) (blkAHCoins c k).1.1
    (blkTAData (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt) (shdBlkRndOf c k))
    (fun i col => congrArg Fp.toGF (blkTAData_indep_rnd _ (shdBlkRndOf c k) (shdBlkRndOf default k) i col))
    (fun r' h1 h2 col => by
      unfold blkTAData; dsimp only
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), dite_eq_left h2, Fp.toGF_ofGF]
      rfl)
    (fun r' h1 col => by
      unfold blkTAData; dsimp only
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
        ite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]
      rfl)
    r j hj

private theorem shdHRowDecode_lt_52 {r : ℕ} (hr : r < 4280) : (shdHRowDecode r).1 < 52 := by
  unfold shdHRowDecode
  split_ifs <;> dsimp only <;> omega

private theorem shdHRowDecode_4280 : shdHRowDecode 4280 = (52, false, 0) := by decide
private theorem shdHRowDecode_4281 : shdHRowDecode 4281 = (52, true, 0) := by decide

/-- Interior block `k : Fin 26` `TH` matches `hRowOf (blkHDat ... k bga x) (blkAHCoins c k).1.2`! -/
theorem blkTH_rows_eq (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (k : Fin 26)
    (bga : Fp2 × Fp2 × Fp2) (r : Fin 4390) (j : ℕ) (hj : j < 16384 + 256) :
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    (((blkTH w (shdBlkRndOf c k) bga).rows.getD r.val []).getD j Fp.zero).toGF
      = rowAt (hRowOf (blkHDat Rp hR hweights hinPub k bga x) (blkAHCoins c k).1.2 r) j := by
  dsimp only
  unfold blkTH
  rw [mkPcsTable_rows_eq]
  have hpads : (shdBlkRndOf c k).hPads = packHPads (blkAHCoins c k).1.2 := rfl
  rw [hpads]
  exact mkRows_h_eq (n := 16384) (d := 4280) (g := 53)
    (blkHDat Rp hR hweights hinPub k bga x) (blkAHCoins c k).1.2
    (blkTHData (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt) (shdBlkRndOf c k) bga)
    (fun i col => by
      have hblkTH_lt : ∀ {Ly : ShieldLayer} {Pb : BlockPublic (shieldShape Ly)} {xIn xOut : shieldS0.Pos → ℤ}
          (w' : BlkWitness Ly Pb xIn xOut) (rnd' : BlkRand) (bga' : Fp2 × Fp2 × Fp2) (i' : Fin 4280) (col' : Fin 16384),
          blkTHData w' rnd' bga' ⟨i'.val, by omega⟩ col'
            = let dec := shdHRowDecode i'.val
              let v := ofK shdP_U shdP_hbij (blkHValK w' rnd' bga' dec.1 (dec.2.2 * 16384 + col'.val))
              if dec.2.1 then v.c1 else v.c0 := fun w' rnd' bga' i' col' => by
        unfold blkTHData; dsimp only; rw [ite_eq_left (by omega : i'.val < 4282)]
      have hdatEq : blkHDat Rp hR hweights hinPub k bga x i col
          = (blkTHData (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt)
              (shdBlkRndOf default k) bga ⟨i.val, by omega⟩ col).toGF := rfl
      rw [hdatEq, hblkTH_lt, hblkTH_lt]
      dsimp only
      rw [blkHValK_indep_rnd _ (shdBlkRndOf c k) (shdBlkRndOf default k) bga _ _ (shdHRowDecode_lt_52 i.isLt)])
    (fun b col => by
      have hfp2 : ∀ (p : GF × GF),
          ofK shdP_U shdP_hbij (algebraMap GF shdP_K p.1 + shdP_U * algebraMap GF shdP_K p.2)
            = ⟨Fp.ofGF p.1, Fp.ofGF p.2⟩ := fun p => by
        refine Fp2.toK_injective shdP_U shdP_hU (ofK_canon shdP_U shdP_hbij _) ⟨Fp.ofGF_canon _, Fp.ofGF_canon _⟩ ?_
        rw [toK_ofK shdP_U shdP_hbij]
        simp [Fp2.toK, Hiding.fp2, Fp.toGF_ofGF]
      cases b with
      | true =>
        have hidx : (⟨if true then 4280 else 4280 + 1, by simp only [↓reduceIte]; omega⟩ : Fin 4390) = ⟨4280, by omega⟩ := Fin.ext rfl
        rw [hidx]
        unfold blkTHData
        rw [ite_eq_left (by omega : (4280 : ℕ) < 4282), shdHRowDecode_4280]
        rw [ite_eq_right Bool.false_ne_true]
        have h52 : blkHValK (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt) (shdBlkRndOf c k) bga 52 (0 * 16384 + col.val)
            = algebraMap GF shdP_K (blkHUVal (shdBlkRndOf c k) col).1
              + shdP_U * algebraMap GF shdP_K (blkHUVal (shdBlkRndOf c k) col).2 := by
          unfold blkHValK
          simp only [show ¬ (52 : ℕ) < 1 by omega, show ¬ (52 : ℕ) < 18 by omega, show ¬ (52 : ℕ) < 25 by omega,
            show ¬ (52 : ℕ) < 32 by omega, show ¬ (52 : ℕ) < 39 by omega, show (52 : ℕ) ≠ 39 by omega,
            show (52 : ℕ) ≠ 40 by omega, show ¬ (52 : ℕ) < 48 by omega, show (52 : ℕ) ≠ 48 by omega,
            show ¬ (52 : ℕ) < 52 by omega, ↓reduceIte, ↓reduceDIte, Nat.zero_mul, Nat.zero_add]
          have hmod : (⟨col.val % 16384, Nat.mod_lt col.val (by norm_num)⟩ : Fin 16384) = col :=
            Fin.ext (Nat.mod_eq_of_lt col.isLt)
          rw [hmod]
        rw [h52, hfp2, Fp.toGF_ofGF]
        exact congrArg Prod.fst (huVal_eq_zsGen (n := 16384) (by norm_num) (shdBlkRndOf c k).hURaw col)
      | false =>
        have hidx : (⟨if false then 4280 else 4280 + 1, by simp only [Bool.false_eq_true, ↓reduceIte]; omega⟩ : Fin 4390) = ⟨4281, by omega⟩ := Fin.ext rfl
        rw [hidx]
        unfold blkTHData
        rw [ite_eq_left (by omega : (4281 : ℕ) < 4282), shdHRowDecode_4281]
        rw [ite_eq_left rfl]
        have h52 : blkHValK (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt) (shdBlkRndOf c k) bga 52 (0 * 16384 + col.val)
            = algebraMap GF shdP_K (blkHUVal (shdBlkRndOf c k) col).1
              + shdP_U * algebraMap GF shdP_K (blkHUVal (shdBlkRndOf c k) col).2 := by
          unfold blkHValK
          simp only [show ¬ (52 : ℕ) < 1 by omega, show ¬ (52 : ℕ) < 18 by omega, show ¬ (52 : ℕ) < 25 by omega,
            show ¬ (52 : ℕ) < 32 by omega, show ¬ (52 : ℕ) < 39 by omega, show (52 : ℕ) ≠ 39 by omega,
            show (52 : ℕ) ≠ 40 by omega, show ¬ (52 : ℕ) < 48 by omega, show (52 : ℕ) ≠ 48 by omega,
            show ¬ (52 : ℕ) < 52 by omega, ↓reduceIte, ↓reduceDIte, Nat.zero_mul, Nat.zero_add]
          have hmod : (⟨col.val % 16384, Nat.mod_lt col.val (by norm_num)⟩ : Fin 16384) = col :=
            Fin.ext (Nat.mod_eq_of_lt col.isLt)
          rw [hmod]
        rw [h52, hfp2, Fp.toGF_ofGF]
        exact congrArg Prod.snd (huVal_eq_zsGen (n := 16384) (by norm_num) (shdBlkRndOf c k).hURaw col))
    (fun r' h1 h2 col => by
      unfold blkTHData; dsimp only
      rw [ite_eq_right h1, dite_eq_left h2, Fp.toGF_ofGF]; rfl)
    (fun r' h1 col => by
      unfold blkTHData; dsimp only
      rw [ite_eq_right (by omega), dite_eq_right h1, Fp.toGF_ofGF]; rfl)
    r j hj

/-- Stage OUT-C `TA` matches `stdRowOf (outcADat ... x) (c.1.2.2 27).1.1`. -/
theorem shdP_outcTA_rows_eq (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (r : Fin 76) (k : ℕ) (hk : k < 4096 + 256) :
    (((shdP_outcTA Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c)).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (stdRowOf (outcADat Rp houtPub x) (c.1.2.2 ⟨27, by decide⟩).1.1 r) k := by
  refine mkRows_std_eq (outcADat Rp houtPub x) (c.1.2.2 ⟨27, by decide⟩).1.1
    (shdP_outcTAData Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c)) ?_ ?_ ?_ r k hk
  · intro i col
    exact congrArg Fp.toGF (shdP_outcTAData_indep_rnd Rp (outcWitness_of_adm Rp houtPub x.1 x.2)
      (shdOutcRndOf c) (shdOutcRndOf default) i col)
  · intro r' h1 h2 col
    unfold shdP_outcTAData
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), dite_eq_right (by omega), ite_eq_right (by omega),
      dite_eq_left h2, Fp.toGF_ofGF]; rfl
  · intro r' h1 col
    unfold shdP_outcTAData
    rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      ite_eq_right (by omega), dite_eq_right (by omega), ite_eq_right (by omega),
      dite_eq_right h1, Fp.toGF_ofGF]; rfl

/-- Stage OUT-C `TH` matches `hRowOf (outcHDat ... gamma alpha x) (c.1.2.2 27).1.2`. -/
theorem shdP_outcTH_rows_eq (Rp : ClassifyRunPublicP shieldS0) (houtPub : Rp.out.Valid)
    (gamma alpha : Fp2) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (r : Fin 38) (k : ℕ) (hk : k < 4096 + 256) :
    (((shdP_outcTH Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c) gamma alpha).rows.getD r.val []).getD k Fp.zero).toGF
      = rowAt (hRowOf (outcHDat Rp houtPub gamma alpha x) (c.1.2.2 ⟨27, by decide⟩).1.2 r) k := by
  refine mkRows_h_eq (outcHDat Rp houtPub gamma alpha x) (c.1.2.2 ⟨27, by decide⟩).1.2
    (shdP_outcTHData Rp (outcWitness_of_adm Rp houtPub x.1 x.2) (shdOutcRndOf c) gamma alpha)
    ?_ ?_ ?_ ?_ r k hk
  · intro i col
    unfold outcHDat shdP_outcTHData; dsimp only
    rw [dite_eq_left i.isLt, dite_eq_left i.isLt]
  · intro b col
    cases b with
    | true =>
      have hidx : (⟨if true then 16 else 16 + 1, by simp only [↓reduceIte]; omega⟩ : Fin 38) = ⟨16, by decide⟩ := Fin.ext rfl
      rw [hidx]
      unfold shdP_outcTHData
      rw [dite_eq_right (by decide), ite_eq_left rfl, Fp.toGF_ofGF]
      exact congrArg Prod.fst (huVal_eq_zsGen (n := 4096) (by norm_num) (shdOutcRndOf c).hURaw col)
    | false =>
      have hidx : (⟨if false then 16 else 16 + 1, by simp only [Bool.false_eq_true, ↓reduceIte]; omega⟩ : Fin 38) = ⟨17, by decide⟩ := Fin.ext rfl
      rw [hidx]
      unfold shdP_outcTHData
      rw [dite_eq_right (by decide), ite_eq_right (by decide), ite_eq_left rfl, Fp.toGF_ofGF]
      exact congrArg Prod.snd (huVal_eq_zsGen (n := 4096) (by norm_num) (shdOutcRndOf c).hURaw col)
  · intro r' h1 h2 col
    unfold shdP_outcTHData; dsimp only
    rw [dite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      dite_eq_left h2, Fp.toGF_ofGF]; rfl
  · intro r' h1 col
    unfold shdP_outcTHData; dsimp only
    rw [dite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
      dite_eq_right h1, Fp.toGF_ofGF]; rfl

end TableRowBridges

/-! ## 2. Exact `.res` Trace Extractors for `openingAuditFixedProg`, `zkBMaskFixedProg`, and Slots -/

section AtomicProgramExtract

/-- Exact `.res` extraction of `openingAuditFixedProg`: returns all `v`-only challenges (`lams`, `proxR`, `sq`, `idxs`),
audit booleans, and the exact `Option Exec.Block.OpeningZk` output. -/
theorem openingAuditFixedProg_res_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom)
    (T : Table) (tree : MerkleLevels depth) (active hdrOk : Bool) (cl : List Exec.Block.ZClaim)
    (t : Tr) (H : QB Lq → Dig) (vf : ℕ → Dig) (base : ℕ) :
    let gs := pGroups prm T (cl.map toZClaim)
    let preOk := active && hdrOk && decide ((gs.map (fun x => x.2.length)).sum = nClaims) && decide (gs.length = nGroups)
    let lams := (List.range nClaims).map (fun j => challengeFp2Of (vf (base + j)))
    let proxR := (List.range rows).map (fun j => challengeFp2Of (vf (base + nClaims + j)))
    let sq := (List.range ((prm.nQ + 3) / 4)).map (fun j => vf (base + nClaims + rows + nGroups + 1 + j))
    let idxs := idxOf prm.nn prm.nQ sq
    let auditPass := preOk && openingAuditOk lams proxR g.rows g.prox
    let vecs := if auditPass then (groupRhosAux rows gs lams).map (fun rho => combVec (prm.n + prm.qPad) rho T.rows) else []
    let prox := if auditPass then combVec (prm.n + prm.qPad) proxR T.rows else []
    let cols := idxs.map (fun j => ofOCol (j, T.cols j, T.salts j, tree.pathD j))
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).res H vf base).1
      = if auditPass then some ⟨vecs, prox, cols⟩ else none := by
  dsimp only
  unfold openingAuditFixedProg
  rw [PProg.res_andThen H vf _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key nClaims t),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H vf _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key rows _),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H vf _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key nGroups _ _),
      trAbsorbVecsFixed_res,
      PProg.res_andThen H vf _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1)
        (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
      trSqueezeVecKeyed_res]
  rfl

/-- Exact `.res` extraction of `zkBMaskFixedProg` when `active = true`. -/
theorem zkBMaskFixedProg_res_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (vf : ℕ → Dig) (base : ℕ) :
    let θ := challengeFp2Of (vf base)
    let rs := (List.range (2 * S + 2)).map (fun j => challengeFp2Of (vf (base + 2 + j)))
    let sq := (List.range ((mQ + 3) / 4)).map (fun j => vf (base + 2 + (2 * S + 2) + 1 + j))
    let idxs := idxOf mDom mQ sq
    let qw := polyWords shdP_U shdP_hbij (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M S (fs.map toMF) (θ.toK shdP_U))
    let pw := polyWords shdP_U shdP_hbij (pPoly shdP_U M S rs)
    let cols := idxs.map (fun j => ofOCol (j, mCol S (cosetPt (rootFp 12)) M j, M.salts j, tree.pathD j))
    ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M S tree fs t).res H vf base).1 = ⟨qw, pw, cols⟩ := by
  dsimp only
  unfold zkBMaskFixedProg
  rw [PProg.res_andThen H vf _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H vf _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H vf _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1)
        (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _),
      trSqueezeVecKeyed_res]
  simp only [PProg.res, ↓reduceIte, Nat.add_assoc]
  have h1 : (List.range (2 * S + 2)).map (fun k => challengeFp2Of (vf (base + (1 + (1 + k)))))
      = (List.range (2 * S + 2)).map (fun j => challengeFp2Of (vf (base + (2 + j)))) :=
    List.map_congr_left fun k _ => by congr 2; omega
  have h2 : (List.range ((mQ + 3) / 4)).map (fun k => vf (base + (1 + (1 + (2 * S + (2 + (1 + k)))))))
      = (List.range ((mQ + 3) / 4)).map (fun j => vf (base + (2 + (2 * S + (2 + (1 + j)))))) :=
    List.map_congr_left fun k _ => by congr 1; omega
  rw [h1, h2]

/-- Round-polynomial output `.1` of `scProveFixedProg.res` does not depend on the starting transcript `t`. -/
theorem scProveFixedProg_res_tr_indep (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (vf : ℕ → Dig) :
    ∀ (n : ℕ) (active : Bool) (wp : WProver n) (t₁ t₂ : Tr) (base : ℕ),
      ((scProveFixedProg Lq hL20 key n active wp t₁).res H vf base).1
        = ((scProveFixedProg Lq hL20 key n active wp t₂).res H vf base).1
  | 0, _, _, _, _, _ => rfl
  | n + 1, active, wp, t₁, t₂, base => by
    unfold scProveFixedProg
    rw [PProg.res_andThen H vf _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t₁ scLabel (by decide) _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H vf _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n active _ _),
      PProg.res_andThen H vf _ _ 1 base (trAbsorbFp2Keyed_ptLen Lq hL20 key t₂ scLabel (by decide) _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ 1 (base + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res,
      PProg.res_andThen H vf _ _ (2 * n) (base + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key n active _ _)]
    simp only [PProg.res]
    exact congrArg (List.cons _) (scProveFixedProg_res_tr_indep Lq hL20 key H vf n active _ _ _ (base + 1 + 1))

/-- Exact `.res` extraction of one active `slotProveFixedProg` step! -/
theorem slotProveFixedProg_res_some (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc)
    (t : Tr) (H : QB Lq → Dig) (vf : ℕ → Dig) (base : ℕ)
    (sp : SlotProof) (rec_ : SlotRec) (acc' : Acc)
    (hSome : ((slotProveFixedProg Lq hL20 key P D s active hist acc t).res H vf base).1 = some (sp, rec_, acc')) :
    let dr := (List.range (P.draws s)).map (fun k => challengeFp2Of (vf (base + k)))
    let ch := challengeFp2Of (vf (base + P.draws s + 1))
    let scBase := base + P.draws s + 3
    let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
    let rho := rhoFull.take (Exec.Block.slotShape P s).1
    let es := rhoFull.drop (Exec.Block.slotShape P s).1
    ∃ df vals,
      active = true
      ∧ ch.isZero = false
      ∧ P.define s hist dr = .ok df
      ∧ es.any (fun x => x.isZero || decide (x = Fp2.one)) = false
      ∧ Exec.Block.slotDefChecks P s acc df = .ok ()
      ∧ Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho (D.terms s hist acc df ch rhoFull) df.tabs 0 = .ok vals
      ∧ rec_.draws = dr
      ∧ rec_.c = ch
      ∧ rec_.scalar = D.scalar s hist acc df ch
      ∧ rec_.rho = rho
      ∧ rec_.es = es
      ∧ rec_.terms = D.terms s hist acc df ch rhoFull
      ∧ sp.scalar = D.scalar s hist acc df ch
      ∧ sp.rounds = ((scProveFixedProg Lq hL20 key (slotN P s) true (D.strat s hist acc df ch)
            ⟨vf (base + P.draws s + 2), 0, key⟩).res H vf scBase).1
      ∧ sp.terms = D.terms s hist acc df ch rhoFull
      ∧ acc' = Exec.Block.slotAcc P s acc df ch sp.scalar
          ((rec_.fin.sub (df.poly vals)).mul ch.inv) rhoFull sp.terms := by
  dsimp only
  unfold slotProveFixedProg at hSome
  rw [PProg.res_andThen H vf _ _ (P.draws s) base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key (P.draws s) t),
      trChallengeFp2VecKeyed_res,
      PProg.res_andThen H vf _ _ 1 (base + P.draws s) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbKeyed_res,
      PProg.res_andThen H vf _ _ 1 (base + P.draws s + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _),
      trChallengeFp2Keyed_res] at hSome
  rw [PProg.res_andThen H vf _ _ 1 (base + P.draws s + 1 + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res,
      PProg.res_andThen H vf _ _ (2 * slotN P s) (base + P.draws s + 1 + 1 + 1)
        (scProveFixedProg_ptLen Lq hL20 key _ _ _ _),
      PProg.res_andThen H vf _ _ 1 (base + P.draws s + 1 + 1 + 1 + 2 * slotN P s)
        (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _),
      trAbsorbFp2Keyed_res] at hSome
  simp only [PProg.res] at hSome
  cases active with
  | false => simp only [Bool.false_eq_true, ↓reduceIte] at hSome; cases hSome
  | true =>
    simp only [↓reduceIte, Bool.true_and] at hSome
    set dr := (List.range (P.draws s)).map (fun k => challengeFp2Of (vf (base + k)))
    set ch := challengeFp2Of (vf (base + P.draws s + 1))
    set rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (base + P.draws s + 3 + 2 * r + 1)))
    set rho := rhoFull.take (Exec.Block.slotShape P s).1
    set es := rhoFull.drop (Exec.Block.slotShape P s).1
    cases hdef : P.define s hist dr with
    | error _ => rw [hdef] at hSome; cases hSome
    | ok df =>
      rw [hdef] at hSome; dsimp only at hSome
      cases hcz : ch.isZero with
      | true => rw [hcz] at hSome; simp at hSome
      | false =>
        rw [hcz] at hSome
        simp only [Bool.not_false, ↓reduceIte, Bool.not_true, Bool.false_eq_true] at hSome
        have hscr21 : ∀ t4' : Tr,
            ((scProveFixedProg Lq hL20 key (slotN P s) true (D.strat s hist acc df ch) t4').res H vf
              (base + P.draws s + 1 + 1 + 1)).2.1 = rhoFull :=
          fun t4' => (scProveFixedProg_res_spec Lq hL20 key H vf (slotN P s) true
            (D.strat s hist acc df ch) t4' (base + P.draws s + 1 + 1 + 1)).2.1
        rw [hscr21] at hSome
        by_cases hes : es.any (fun x => x.isZero || decide (x = Fp2.one)) = true
        · rw [hes] at hSome
          simp only [↓reduceIte] at hSome
          cases hSome
        · have hesF : es.any (fun x => x.isZero || decide (x = Fp2.one)) = false :=
            Bool.eq_false_iff.mpr hes
          rw [hesF] at hSome
          simp only [Bool.false_eq_true, ↓reduceIte] at hSome
          cases hchk : Exec.Block.slotDefChecks P s acc df with
          | error _ => rw [hchk] at hSome; cases hSome
          | ok _ =>
            rw [hchk] at hSome; dsimp only at hSome
            cases hho : Exec.Block.hostedSum acc.scalars (D.scalar s hist acc df ch) df.hosted with
            | error _ => rw [hho] at hSome; cases hSome
            | ok claimed =>
              rw [hho] at hSome; dsimp only at hSome
              cases htv : Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho (D.terms s hist acc df ch rhoFull) df.tabs 0 with
              | error _ => rw [htv] at hSome; cases hSome
              | ok vals =>
                rw [htv] at hSome; dsimp only at hSome
                have hinj := Option.some.inj hSome
                have hsp : sp = _ := (congrArg Prod.fst hinj).symm
                have hrec : rec_ = _ := (congrArg (fun p => p.2.1) hinj).symm
                have hacc : acc' = _ := (congrArg (fun p => p.2.2) hinj).symm
                refine ⟨df, vals, rfl, rfl, rfl, hesF, hchk, htv, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
                · rw [hrec]
                · rw [hrec]
                · rw [hrec]
                · rw [hrec]
                · rw [hrec]
                · rw [hrec]
                · rw [hsp]
                · rw [hsp, show base + P.draws s + 1 + 1 + 1 = base + P.draws s + 3 by omega]
                  exact scProveFixedProg_res_tr_indep Lq hL20 key H vf (slotN P s) true _ _ _ _
                · rw [hsp]
                · rw [hacc, hsp, hrec]

/-- `fwt` and `qPoly` depend ONLY on `.terms` of each `MaskFunctional` (never on `.value`)! -/
theorem fwt_eq_of_terms (f₁ f₂ : Exec.Block.MaskFunctional) (h : f₁.terms = f₂.terms) :
    fwt shdP_U (toMF f₁) = fwt shdP_U (toMF f₂) := by
  funext s j; unfold fwt toMF; rw [h]

theorem qPoly_eq_of_terms (M : MTable) (S : ℕ) (fs₁ fs₂ : List Exec.Block.MaskFunctional)
    (h : fs₁.map Exec.Block.MaskFunctional.terms = fs₂.map Exec.Block.MaskFunctional.terms) (θ : shdP_K) :
    qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M S (fs₁.map toMF) θ
      = qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M S (fs₂.map toMF) θ := by
  have hlen : fs₁.length = fs₂.length := by have := congrArg List.length h; simpa using this
  unfold qPoly mProduct
  refine congrArg (HonestOpen.mB shdP_U M S + ·) ?_
  refine Finset.sum_congr rfl fun s _ => ?_
  refine congrArg (HonestOpen.mA shdP_U M S s * ·) (congrArg (mInterp _) (funext fun j => ?_))
  unfold mW
  have hlenM : (fs₁.map toMF).length = (fs₂.map toMF).length := by simp [hlen]
  refine Fintype.sum_equiv (finCongr hlenM) _ _ fun i => ?_
  have hi1 : i.val < fs₁.length := by simpa [List.length_map] using i.isLt
  have hi2 : i.val < fs₂.length := by omega
  refine congrArg₂ (· * ·) (by simp [finCongr]) ?_
  unfold wtOf
  have h1 : (fs₁.map toMF).get i = toMF fs₁[i.val] := by
    simp [List.get_eq_getElem]
  have h2 : (fs₂.map toMF).get (finCongr hlenM i) = toMF fs₂[i.val] := by
    simp [List.get_eq_getElem]
  rw [h1, h2]
  have ht : fs₁[i.val].terms = fs₂[i.val].terms := by
    have hi := congrArg (fun l => l[i.val]?) h
    simp only [List.getElem?_map, List.getElem?_eq_getElem hi1,
      List.getElem?_eq_getElem hi2, Option.map_some, Option.some.injEq] at hi
    exact hi
  exact congrFun (congrFun (fwt_eq_of_terms _ _ ht) s) j

/-- `openingAuditOk` implies the proximity-pair determinant is nonzero! -/
theorem det_ne_zero_of_openingAuditOk {lams proxR : List Fp2} {rows prox : ℕ}
    (hok : openingAuditOk lams proxR rows prox = true) :
    (Exec.Block.det (proxR.getD prox Fp2.zero) (proxR.getD (prox + 1) Fp2.zero)).v ≠ 0 := by
  unfold openingAuditOk at hok
  have h2 := (Bool.and_eq_true _ _).mp hok |>.2
  have hfalse : decide (prox + 1 ≥ rows ∨ (Exec.Block.det (proxR.getD prox Fp2.zero) (proxR.getD (prox + 1) Fp2.zero)).v = 0) = false := by
    cases hd : decide (prox + 1 ≥ rows ∨ (Exec.Block.det (proxR.getD prox Fp2.zero) (proxR.getD (prox + 1) Fp2.zero)).v = 0)
    · rfl
    · rw [hd] at h2; cases h2
  intro h0
  exact Bool.false_ne_true (hfalse.symm.trans (decide_eq_true (Or.inr h0)))

/-- `openingHdrOk` implies `auditClaims ... = .ok ()`! -/
theorem auditClaims_ok_of_openingHdrOk {g : OpenGeom} {logCols : ℕ} {cl : List Exec.Block.ZClaim}
    (hok : openingHdrOk g logCols cl = true) :
    auditClaims cl (2 ^ logCols) g.rows g.siteRows g.sumRows g.prox = .ok () := by
  unfold openingHdrOk at hok
  cases ha : auditClaims cl (2 ^ logCols) g.rows g.siteRows g.sumRows g.prox with
  | error _ => rw [ha] at hok; cases hok
  | ok u => cases u; rfl

end AtomicProgramExtract

/-! ## 3. Generic Slot-Loop Trace Extraction (`slotsProveFixedProg` & `stSlotsProveFixedProg`) -/

section SlotLoopExtract

/-- Step-by-step trace invariant for an active `slotsProveFixedProg` run over `m` slots starting at `s0`. -/
structure SlotsTrace (P : BlockParams) (m : ℕ) (vf : ℕ → Dig) (base : ℕ)
    (b g a : Fp2) (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) : Prop where
  sps_len : sps.length = m
  recs_len : recs.length = m
  cs_len : acc.cs.length = m
  scalars_len : acc.scalars.length = m
  cs_eq : ∀ j : Fin m, acc.cs[j.val]'(by omega) = challengeFp2Of (vf (base + slotsFixedLen P 0 j.val + P.draws j.val + 1))
  c_nz : ∀ j : Fin m, (challengeFp2Of (vf (base + slotsFixedLen P 0 j.val + P.draws j.val + 1))).isZero = false
  recs_draws : ∀ j : Fin m,
    (recs[j.val]'(by omega)).draws =
      (List.range (P.draws j.val)).map (fun k => challengeFp2Of (vf (base + slotsFixedLen P 0 j.val + k)))
  recs_c : ∀ j : Fin m,
    (recs[j.val]'(by omega)).c = challengeFp2Of (vf (base + slotsFixedLen P 0 j.val + P.draws j.val + 1))
  recs_rho_es : ∀ j : Fin m,
    (recs[j.val]'(by omega)).rho ++ (recs[j.val]'(by omega)).es =
      (List.range (slotN P j.val)).map (fun r => challengeFp2Of (vf (base + slotsFixedLen P 0 j.val + P.draws j.val + 3 + 2 * r + 1)))
  es_good : ∀ j : Fin m,
    (recs[j.val]'(by omega)).es.any (fun x => x.isZero || decide (x = Fp2.one)) = false
  slot_def : ∀ j : Fin m,
    ∃ df, P.define j.val (Exec.Block.histOf b g a (recs.take j.val)) (recs[j.val]'(by omega)).draws = .ok df
      ∧ (∀ (D : SlotData P), True)

/-- Pure `v`-only functional list terms built from a sequence of slot definitions `dfs : Fin m → SlotDef`
and `v`-only challenges `cs : Fin m → Fp2`, `rhos : (j : Fin m) → List Fp2`. -/
def slotAccFsOf (P : BlockParams) (m : ℕ) (cs : Fin m → Fp2) (rhos : Fin m → List Fp2)
    (dfs : Fin m → SlotDef) : List (List (ℕ × List Fp2)) × List (List (ℕ × List Fp2)) :=
  let fs := (List.finRange m).flatMap fun j =>
    let nd := Exec.Block.slotShape P j.val
    let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs j))
    let ev := [(j.val, Cfs.evalWeights (rhos j) nd.2.2)]
    match P.kind j.val with
    | .standalone => [[(j.val, sw)], ev]
    | _ => [ev]
  let hostFs := (List.finRange m).filterMap fun j =>
    let nd := Exec.Block.slotShape P j.val
    let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs j))
    match P.kind j.val with
    | .host =>
      some ((j.val, sw) :: (dfs j).hosted.map fun hk =>
        (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
          (Exec.Block.slotShape P hk.1).2.2).map
            (fun w => w.mul (hk.2.mul (if h : hk.1 < m then cs ⟨hk.1, h⟩ else Fp2.zero)).neg)))
    | _ => none
  (fs, hostFs)

/-- Pure `v`-only `slotClaims` parts collector across `m` slots (exact match with `acc.claims.*.map ZClaim.parts`). -/
def slotAccClaimParts (P : BlockParams) (m : ℕ) (rhos : Fin m → List Fp2) (dfs : Fin m → SlotDef)
    (cm : Cm) : List (List Block.ZPart) :=
  (List.finRange m).flatMap fun j =>
    let n := (Exec.Block.slotShape P j.val).1
    let rho := (rhos j).take n
    let es := (rhos j).drop n
    ((Exec.Block.slotClaimList P rho es [] (dfs j).tabs 0).filter (fun p => p.1 == cm)).map
      (fun p => p.2.parts)

/-- Helper: `slotClaimList` with any `terms` has identical `.map (fun p => (p.1, p.2.parts))`! -/
theorem slotClaimList_parts_indep (P : BlockParams) (rho es terms₁ terms₂ : List Fp2) :
    ∀ (tabs : List Tab) (k : ℕ),
      (Exec.Block.slotClaimList P rho es terms₁ tabs k).map (fun p => (p.1, p.2.parts))
        = (Exec.Block.slotClaimList P rho es terms₂ tabs k).map (fun p => (p.1, p.2.parts))
  | [], _ => rfl
  | .eq _ _ :: ts, k => slotClaimList_parts_indep P rho es terms₁ terms₂ ts k
  | .pub _ :: ts, k => slotClaimList_parts_indep P rho es terms₁ terms₂ ts k
  | .priv p :: ts, k => by
    simp only [Exec.Block.slotClaimList, List.map_cons, List.cons.injEq]
    exact ⟨rfl, slotClaimList_parts_indep P rho es terms₁ terms₂ ts (k + 1)⟩

/-- Helper: every `.priv p` in `tabs` produces a claim in `slotClaimList` whose `parts` match
`buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound) Fp2.zero`. -/
theorem mem_slotClaimList_of_priv (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (tabs : List Tab) (k : ℕ) (p : Exec.Block.Priv),
      Tab.priv p ∈ tabs →
      ∃ z, (p.cm, z) ∈ Exec.Block.slotClaimList P rho es terms tabs k
        ∧ z.parts = (Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
            (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero).parts
  | [], _, _, h => by cases h
  | .eq _ _ :: ts, k, p, h => by
    rcases List.mem_cons.mp h with he | ht
    · cases he
    · exact mem_slotClaimList_of_priv P rho es terms ts k p ht
  | .pub _ :: ts, k, p, h => by
    rcases List.mem_cons.mp h with he | ht
    · cases he
    · exact mem_slotClaimList_of_priv P rho es terms ts k p ht
  | .priv q :: ts, k, p, h => by
    rcases List.mem_cons.mp h with he | ht
    · cases he
      exact ⟨_, List.mem_cons_self, rfl⟩
    · obtain ⟨z, hz, hp⟩ := mem_slotClaimList_of_priv P rho es terms ts (k + 1) p ht
      exact ⟨z, List.mem_cons_of_mem _ hz, hp⟩

/-- Helper: `slotClaims` appends each `(cm, z)` from `slotClaimList` onto the corresponding bucket of `Claims4`. -/
theorem mem_slotClaims_of_mem_list (P : BlockParams) (rho es terms : List Fp2)
    (tabs : List Tab) (k : ℕ) (cl : Exec.Block.Claims4) (cm : Cm) (z : Block.ZClaim)
    (hmem : (cm, z) ∈ Exec.Block.slotClaimList P rho es terms tabs k) :
    match cm with
    | .a => z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).a
    | .h => z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).h
    | .inp => z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).inp
    | .out => z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).out := by
  have h := Exec.Block.slotClaims_mem P rho es terms tabs k cl (cm, z) hmem
  cases cm <;> exact h

/-- `slotClaims` preserves membership in all 4 claim buckets! -/
theorem slotClaims_mem_mono (P : BlockParams) (rho es terms : List Fp2)
    (tabs : List Tab) (k : ℕ) (cl : Exec.Block.Claims4) :
    (∀ z ∈ cl.a, z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).a)
    ∧ (∀ z ∈ cl.h, z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).h)
    ∧ (∀ z ∈ cl.inp, z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).inp)
    ∧ (∀ z ∈ cl.out, z ∈ (Exec.Block.slotClaims P rho es terms tabs k cl).out) :=
  ⟨fun z hz => Exec.Block.slotClaims_mono P rho es terms tabs k cl .a z hz,
   fun z hz => Exec.Block.slotClaims_mono P rho es terms tabs k cl .h z hz,
   fun z hz => Exec.Block.slotClaims_mono P rho es terms tabs k cl .inp z hz,
   fun z hz => Exec.Block.slotClaims_mono P rho es terms tabs k cl .out z hz⟩

/-- **Pure `X₁`-evaluation of `stgPrivVals` and `tabVals`**:
if every claim `z` produced by `Tab.priv p ∈ tabs` agrees with a pure function `csView p.cm z.parts`,
then `stgPrivVals` equals `stgPrivValsFromView` AND `tabVals` equals a pure function of `csView`! -/
noncomputable def stgPrivValsFromView (P : BlockParams) (csView : Cm → List Block.ZPart → shdP_K)
    (rho es : List Fp2) : List Tab → List Fp2
  | [] => []
  | .eq _ _ :: ts => stgPrivValsFromView P csView rho es ts
  | .pub _ :: ts => stgPrivValsFromView P csView rho es ts
  | .priv p :: ts =>
    let z := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
      (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
    ofK shdP_U shdP_hbij (csView p.cm z.parts) :: stgPrivValsFromView P csView rho es ts

theorem stgPrivVals_eq_fromView (P : BlockParams) (cs : Cm → Block.ZClaim → shdP_K)
    (csView : Cm → List Block.ZPart → shdP_K) (rho es : List Fp2) :
    ∀ tabs : List Tab,
      (∀ p, Tab.priv p ∈ tabs →
        let z := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
          (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
        cs p.cm z = csView p.cm z.parts) →
      stgPrivVals shdP_U shdP_hbij P cs rho es tabs = stgPrivValsFromView P csView rho es tabs
  | [], _ => rfl
  | .eq _ _ :: ts, h => stgPrivVals_eq_fromView P cs csView rho es ts
      (fun p hp => h p (List.mem_cons_of_mem _ hp))
  | .pub _ :: ts, h => stgPrivVals_eq_fromView P cs csView rho es ts
      (fun p hp => h p (List.mem_cons_of_mem _ hp))
  | .priv q :: ts, h => by
    unfold stgPrivVals stgPrivValsFromView
    rw [h q List.mem_cons_self,
      stgPrivVals_eq_fromView P cs csView rho es ts (fun p hp => h p (List.mem_cons_of_mem _ hp))]

/-- Generic helper: `Cfs.sumWeights N d` has length `N * d + 2`. -/
theorem cfs_sumWeights_length (N d : ℕ) : (Cfs.sumWeights N d).length = N * d + 2 :=
  ZK60.Exec.sumWeights_length N d

/-- Generic helper: `Cfs.evalWeights rho d` has length `rho.length * d + 2`. -/
theorem cfs_evalWeights_length (rho : List Fp2) (d : ℕ) : (Cfs.evalWeights rho d).length = rho.length * d + 2 :=
  ZK60.Exec.evalWeights_length rho d

private theorem slotsProveFixedProg_lens (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc),
      recs0.length = s0 → acc0.cs.length = s0 →
      ((slotsProveFixedProg Lq hL20 key P D b g a m active recs0 s0 acc0 t).res H vf base).1
        = some (sps, recs, acc) →
      sps.length = m ∧ recs.length = s0 + m ∧ acc.cs.length = s0 + m
  | 0, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold slotsProveFixedProg at hSome
    cases active with
    | false => simp [PProg.res] at hSome
    | true =>
      simp only [↓reduceIte, PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
      rcases hSome with ⟨rfl, rfl, rfl⟩
      exact ⟨rfl, by omega, by omega⟩
  | m + 1, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold slotsProveFixedProg at hSome
    rw [PProg.res_andThen H vf _ _ (slotFixedLen P s0) base
      (slotProveFixedProg_ptLen Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t)] at hSome
    set r1 := (slotProveFixedProg Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t).res H vf base
    cases h1 : r1.1 with
    | none =>
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m false recs0 (s0 + 1) acc0 r1.2)] at hSome
      simp [PProg.res] at hSome
    | some v1 =>
      rcases v1 with ⟨sp0, rec0, acc1⟩
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2)] at hSome
      cases h2 : ((slotsProveFixedProg Lq hL20 key P D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2).res H vf
          (base + slotFixedLen P s0)).1 with
      | none => rw [h2] at hSome; simp [PProg.res] at hSome
      | some v2 =>
        rcases v2 with ⟨spsRest, recsF, accF⟩
        rw [h2] at hSome
        simp only [PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
        rcases hSome with ⟨rfl, rfl, rfl⟩
        obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hacc1Eq⟩ :=
          slotProveFixedProg_res_some Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t H vf base sp0 rec0 acc1 h1
        have hrl1 : (recs0 ++ [rec0]).length = s0 + 1 := by simp [hrl]
        have hcl1 : acc1.cs.length = s0 + 1 := by rw [hacc1Eq]; simp [Exec.Block.slotAcc, hcl]
        obtain ⟨h1', h2', h3'⟩ := slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m true (recs0 ++ [rec0])
          (s0 + 1) acc1 r1.2 (base + slotFixedLen P s0) spsRest recsF accF hrl1 hcl1 h2
        exact ⟨by simp [h1'], by omega, by omega⟩

/-- **Complete inductive extraction of `slotsProveFixedProg`**:
for any active `slotsProveFixedProg` run over `m` slots starting at `s0`, returns exact `v`-only
challenges, `df`s, `SlotProof`s, `acc.cs`, `acc.claims` inclusions, and `acc.fs` / `acc.hostFs`! -/
theorem slotsProveFixedProg_extract (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc)
      (hrl : recs0.length = s0) (hcl : acc0.cs.length = s0)
      (hSome : ((slotsProveFixedProg Lq hL20 key P D b g a m active recs0 s0 acc0 t).res H vf base).1
        = some (sps, recs, acc)),
      active = true
      ∧ sps.length = m
      ∧ recs.length = s0 + m
      ∧ recs.take s0 = recs0
      ∧ acc.cs.length = s0 + m
      ∧ acc.cs.take s0 = acc0.cs
      ∧ (∀ z ∈ acc0.claims.a, z ∈ acc.claims.a)
      ∧ (∀ z ∈ acc0.claims.h, z ∈ acc.claims.h)
      ∧ (∀ z ∈ acc0.claims.inp, z ∈ acc.claims.inp)
      ∧ (∀ z ∈ acc0.claims.out, z ∈ acc.claims.out)
      ∧ (∃ (dfs : Fin m → SlotDef) (vals : Fin m → List Fp2) (accs : Fin m → Acc),
          (∀ j : Fin m,
            let s := s0 + j.val
            let bj := base + slotsFixedLen P s0 j.val
            let dr := (List.range (P.draws s)).map (fun k => challengeFp2Of (vf (bj + k)))
            let ch := challengeFp2Of (vf (bj + P.draws s + 1))
            let scBase := bj + P.draws s + 3
            let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
            let rho := rhoFull.take (Exec.Block.slotShape P s).1
            let es := rhoFull.drop (Exec.Block.slotShape P s).1
            let hist := Exec.Block.histOf b g a (recs.take s)
            ch.isZero = false
            ∧ P.define s hist dr = .ok (dfs j)
            ∧ es.any (fun x => x.isZero || decide (x = Fp2.one)) = false
            ∧ Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho (D.terms s hist (accs j) (dfs j) ch rhoFull) (dfs j).tabs 0 = .ok (vals j)
            ∧ (accs j).cs = acc.cs.take s
            ∧ (recs[s]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).draws = dr
            ∧ (recs[s]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).c = ch
            ∧ (recs[s]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).rho = rho
            ∧ (recs[s]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).es = es
            ∧ (acc.cs[s]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.2; omega)) = ch
            ∧ (sps[j.val]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).scalar = D.scalar s hist (accs j) (dfs j) ch
            ∧ (sps[j.val]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).rounds =
                ((scProveFixedProg Lq hL20 key (slotN P s) true (D.strat s hist (accs j) (dfs j) ch)
                  ⟨vf (bj + P.draws s + 2), 0, key⟩).res H vf scBase).1
            ∧ (sps[j.val]'(by have := (slotsProveFixedProg_lens Lq hL20 key P D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).terms = D.terms s hist (accs j) (dfs j) ch rhoFull
            ∧ (∀ p, Tab.priv p ∈ (dfs j).tabs →
                let z0 := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
                  (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
                match p.cm with
                | .a => ∃ z ∈ acc.claims.a, z.parts = z0.parts
                | .h => ∃ z ∈ acc.claims.h, z.parts = z0.parts
                | .inp => ∃ z ∈ acc.claims.inp, z.parts = z0.parts
                | .out => ∃ z ∈ acc.claims.out, z.parts = z0.parts))
          ∧ acc.fs.map Exec.Block.MaskFunctional.terms =
              acc0.fs.map Exec.Block.MaskFunctional.terms ++
                (List.finRange m).flatMap (fun j =>
                  let s := s0 + j.val
                  let bj := base + slotsFixedLen P s0 j.val
                  let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                  let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                  let nd := Exec.Block.slotShape P s
                  let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                  let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                  match P.kind s with
                  | .standalone => [[(s, sw)], ev]
                  | _ => [ev])
          ∧ acc.hostFs.map Exec.Block.MaskFunctional.terms =
              acc0.hostFs.map Exec.Block.MaskFunctional.terms ++
                (List.finRange m).filterMap (fun j =>
                  let s := s0 + j.val
                  let bj := base + slotsFixedLen P s0 j.val
                  let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                  let nd := Exec.Block.slotShape P s
                  let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                  match P.kind s with
                  | .host =>
                    some ((s, sw) :: (dfs j).hosted.map fun hk =>
                      (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                        (Exec.Block.slotShape P hk.1).2.2).map
                          (fun w => w.mul (hk.2.mul ((accs j).cs.getD hk.1 Fp2.zero)).neg)))
                  | _ => none))
  | 0, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold slotsProveFixedProg at hSome
    cases active with
    | false => simp [PProg.res] at hSome
    | true =>
      simp only [↓reduceIte, PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
      rcases hSome with ⟨rfl, rfl, rfl⟩
      refine ⟨rfl, rfl, by omega, by simp [hrl], by omega, by simp [hcl],
        fun _ h => h, fun _ h => h, fun _ h => h, fun _ h => h,
        fun j => j.elim0, fun j => j.elim0, fun j => j.elim0, fun j => j.elim0, by simp, by simp⟩
  | m + 1, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold slotsProveFixedProg at hSome
    rw [PProg.res_andThen H vf _ _ (slotFixedLen P s0) base
      (slotProveFixedProg_ptLen Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t)] at hSome
    set r1 := (slotProveFixedProg Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t).res H vf base
    cases h1 : r1.1 with
    | none =>
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m false recs0 (s0 + 1) acc0 r1.2)] at hSome
      simp [PProg.res] at hSome
    | some v1 =>
      rcases v1 with ⟨sp0, rec0, acc1⟩
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2)] at hSome
      cases h2 : ((slotsProveFixedProg Lq hL20 key P D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2).res H vf
          (base + slotFixedLen P s0)).1 with
      | none => rw [h2] at hSome; simp [PProg.res] at hSome
      | some v2 =>
        rcases v2 with ⟨spsRest, recsF, accF⟩
        rw [h2] at hSome
        simp only [PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
        rcases hSome with ⟨rfl, rfl, rfl⟩
        obtain ⟨df0, vals0, hact, hcz0, hdef0, hes0, hchk0, htv0, hrecDr0, hrecC0, hrecSc0,
          hrecRho0, hrecEs0, hrecTm0, hspSc0, hspRd0, hspTm0, hacc1Eq⟩ :=
          slotProveFixedProg_res_some Lq hL20 key P D s0 active (Exec.Block.histOf b g a recs0) acc0 t H vf base sp0 rec0 acc1 h1
        have hrl1 : (recs0 ++ [rec0]).length = s0 + 1 := by simp [hrl]
        have hcl1 : acc1.cs.length = s0 + 1 := by rw [hacc1Eq]; simp [Exec.Block.slotAcc, hcl]
        obtain ⟨_, hspsLen, hrecsLen, hrecsTake, hcsLen, hcsTake, hmA, hmH, hmI, hmO,
          dfsR, valsR, accsR, hAllR, hFsR, hHostFsR⟩ :=
          slotsProveFixedProg_extract Lq hL20 key P D b g a H vf m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2
            (base + slotFixedLen P s0) spsRest recsF accF hrl1 hcl1 h2
        have htake0 : recsF.take s0 = recs0 := calc
          recsF.take s0 = (recsF.take (s0 + 1)).take s0 := by rw [List.take_take, Nat.min_eq_left (by omega)]
          _ = (recs0 ++ [rec0]).take s0 := by rw [hrecsTake]
          _ = recs0 := by rw [List.take_append_of_le_length (by omega), ← hrl, List.take_length]
        have hcsTake0 : accF.cs.take s0 = acc0.cs := calc
          accF.cs.take s0 = (accF.cs.take (s0 + 1)).take s0 := by rw [List.take_take, Nat.min_eq_left (by omega)]
          _ = acc1.cs.take s0 := by rw [hcsTake]
          _ = (acc0.cs ++ [challengeFp2Of (vf (base + P.draws s0 + 1))]).take s0 := by rw [hacc1Eq]; rfl
          _ = acc0.cs := by rw [List.take_append_of_le_length (by omega), ← hcl, List.take_length]
        set rhoFull0 := (List.range (slotN P s0)).map (fun r => challengeFp2Of (vf (base + P.draws s0 + 3 + 2 * r + 1)))
        have hclMono0 := slotClaims_mem_mono P (rhoFull0.take (Exec.Block.slotShape P s0).1)
          (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims
        have hacc1Cl : acc1.claims = Exec.Block.slotClaims P (rhoFull0.take (Exec.Block.slotShape P s0).1)
            (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims := by
          rw [hacc1Eq]; rfl
        have hslotsShift : ∀ k : ℕ, slotsFixedLen P s0 (k + 1) = slotFixedLen P s0 + slotsFixedLen P (s0 + 1) k :=
          fun _ => rfl
        refine ⟨hact, by simp [hspsLen], by omega, htake0, by omega, hcsTake0,
          fun z hz => hmA z (by rw [hacc1Cl]; exact hclMono0.1 z hz),
          fun z hz => hmH z (by rw [hacc1Cl]; exact hclMono0.2.1 z hz),
          fun z hz => hmI z (by rw [hacc1Cl]; exact hclMono0.2.2.1 z hz),
          fun z hz => hmO z (by rw [hacc1Cl]; exact hclMono0.2.2.2 z hz),
          Fin.cases df0 dfsR, Fin.cases vals0 valsR, Fin.cases acc0 accsR, ?_, ?_, ?_⟩
        · intro j
          refine Fin.cases ?_ (fun j' => ?_) j
          · -- `j = 0`
            have hrec0At : recsF[s0]'(by omega) = rec0 := by
              have h1' : (recsF.take (s0 + 1))[s0]'(by rw [List.length_take]; omega) = recsF[s0]'(by omega) :=
                List.getElem_take
              rw [← h1']
              simp only [hrecsTake, List.getElem_append_right (by omega : recs0.length ≤ s0),
                hrl, Nat.sub_self, List.getElem_cons_zero]
            have hcs0At : accF.cs[s0]'(by omega) = challengeFp2Of (vf (base + P.draws s0 + 1)) := by
              have h1' : (accF.cs.take (s0 + 1))[s0]'(by rw [List.length_take]; omega) = accF.cs[s0]'(by omega) :=
                List.getElem_take
              rw [← h1']
              simp only [hcsTake, hacc1Eq, Exec.Block.slotAcc,
                List.getElem_append_right (by omega : acc0.cs.length ≤ s0), hcl, Nat.sub_self, List.getElem_cons_zero]
            simp only [Fin.val_zero, Nat.add_zero, slotsFixedLen, Fin.cases_zero, htake0, hcsTake0,
              hrec0At, hcs0At, List.getElem_cons_zero]
            refine ⟨hcz0, hdef0, hes0, htv0, trivial, hrecDr0, hrecC0, hrecRho0, hrecEs0, trivial, hspSc0, hspRd0, hspTm0, ?_⟩
            intro p hp
            obtain ⟨z, hzMem, hzParts⟩ := mem_slotClaimList_of_priv P (rhoFull0.take (Exec.Block.slotShape P s0).1)
              (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 p hp
            cases hcm : p.cm with
            | a =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list P (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .a z hzMem
              exact ⟨z, hmA z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | h =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list P (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .h z hzMem
              exact ⟨z, hmH z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | inp =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list P (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .inp z hzMem
              exact ⟨z, hmI z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | out =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list P (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .out z hzMem
              exact ⟨z, hmO z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
          · -- `j = j'.succ`
            have hR := hAllR j'
            have hsEq : s0 + (j'.val + 1) = (s0 + 1) + j'.val := by omega
            have hbEq : base + slotsFixedLen P s0 (j'.val + 1) = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j'.val := by
              rw [hslotsShift, Nat.add_assoc]
            have hscEq : ∀ {s₁ s₂ : ℕ} (hs : s₁ = s₂) (h1 : Hist) (a1 : Acc) (d1 : SlotDef) (c1 : Fp2) (st1 : Tr) (b1 : ℕ),
                ((scProveFixedProg Lq hL20 key (slotN P s₁) true (D.strat s₁ h1 a1 d1 c1) st1).res H vf b1).1
                  = ((scProveFixedProg Lq hL20 key (slotN P s₂) true (D.strat s₂ h1 a1 d1 c1) st1).res H vf b1).1 := by
              intro s₁ s₂ hs; subst hs; intros; rfl
            dsimp only
            simp only [Fin.val_succ, Fin.cases_succ, hbEq, List.getElem_cons_succ]
            rw [hscEq hsEq]
            simpa only [hsEq] using hR
        · -- `accF.fs.map terms`
          rw [hFsR, List.finRange_succ, List.flatMap_cons, hacc1Eq]
          simp only [Exec.Block.slotAcc, List.map_append, List.map_singleton, List.append_assoc,
            Fin.val_zero, Nat.add_zero, slotsFixedLen]
          have hrest :
              ((List.finRange m).map Fin.succ).flatMap (fun j =>
                let s := s0 + j.val
                let bj := base + slotsFixedLen P s0 j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                match P.kind s with | .standalone => [[(s, sw)], ev] | _ => [ev])
              = (List.finRange m).flatMap (fun j =>
                let s := (s0 + 1) + j.val
                let bj := (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                match P.kind s with | .standalone => [[(s, sw)], ev] | _ => [ev]) := by
            rw [List.flatMap_map]
            congr 1; funext j
            have hsEq : s0 + j.succ.val = (s0 + 1) + j.val := by simp [Fin.val_succ]; omega
            have hbEq : base + slotsFixedLen P s0 j.succ.val = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val := by
              simp only [Fin.val_succ, hslotsShift, Nat.add_assoc]
            simp only [Function.comp_apply, hsEq, hbEq]
          rw [hrest]
          cases P.kind s0 <;> simp [rhoFull0, List.append_assoc]
        · -- `accF.hostFs.map terms`
          rw [hHostFsR, List.finRange_succ, List.filterMap_cons, hacc1Eq]
          simp only [Exec.Block.slotAcc, List.map_append, List.map_singleton, List.append_assoc,
            Fin.val_zero, Nat.add_zero, slotsFixedLen, Fin.cases_zero]
          have hrest :
              ((List.finRange m).map Fin.succ).filterMap (fun j =>
                let s := s0 + j.val
                let bj := base + slotsFixedLen P s0 j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                match P.kind s with
                | .host =>
                  some ((s, sw) :: (Fin.cases (motive := fun _ => SlotDef) df0 dfsR j).hosted.map fun hk =>
                    (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                      (Exec.Block.slotShape P hk.1).2.2).map
                        (fun w => w.mul (hk.2.mul ((Fin.cases (motive := fun _ => Acc) acc0 accsR j).cs.getD hk.1 Fp2.zero)).neg)))
                | _ => none)
              = (List.finRange m).filterMap (fun j =>
                let s := (s0 + 1) + j.val
                let bj := (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                match P.kind s with
                | .host =>
                  some ((s, sw) :: (dfsR j).hosted.map fun hk =>
                    (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                      (Exec.Block.slotShape P hk.1).2.2).map
                        (fun w => w.mul (hk.2.mul ((accsR j).cs.getD hk.1 Fp2.zero)).neg)))
                | _ => none) := by
            rw [List.filterMap_map]
            congr 1; funext j
            have hsEq : s0 + j.succ.val = (s0 + 1) + j.val := by simp [Fin.val_succ]; omega
            have hbEq : base + slotsFixedLen P s0 j.succ.val = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val := by
              simp only [Fin.val_succ, hslotsShift, Nat.add_assoc]
            simp only [Function.comp_apply, Fin.cases_succ, hsEq, hbEq]
          rw [hrest]
          cases P.kind s0 <;> simp [List.append_assoc]

private theorem stSlotsProveFixedProg_lens (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc),
      recs0.length = s0 → acc0.cs.length = s0 →
      ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m active recs0 s0 acc0 t).res H vf base).1
        = some (sps, recs, acc) →
      sps.length = m ∧ recs.length = s0 + m ∧ acc.cs.length = s0 + m
  | 0, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold stSlotsProveFixedProg at hSome
    cases active with
    | false => simp [PProg.res] at hSome
    | true =>
      simp only [↓reduceIte, PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
      rcases hSome with ⟨rfl, rfl, rfl⟩
      exact ⟨rfl, by omega, by omega⟩
  | m + 1, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold stSlotsProveFixedProg at hSome
    rw [PProg.res_andThen H vf _ _ (slotFixedLen P s0) base
      (slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
        (Exec.Block.histOf b g a recs0) acc0 t)] at hSome
    set r1 := (slotProveFixedProg Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
      (Exec.Block.histOf b g a recs0) acc0 t).res H vf base
    cases h1 : r1.1 with
    | none =>
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m false recs0 (s0 + 1) acc0 r1.2)] at hSome
      simp [PProg.res] at hSome
    | some v1 =>
      rcases v1 with ⟨sp0, rec0, acc1⟩
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2)] at hSome
      cases h2 : ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2).res H vf
          (base + slotFixedLen P s0)).1 with
      | none => rw [h2] at hSome; simp [PProg.res] at hSome
      | some v2 =>
        rcases v2 with ⟨spsRest, recsF, accF⟩
        rw [h2] at hSome
        simp only [PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
        rcases hSome with ⟨rfl, rfl, rfl⟩
        obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hacc1Eq⟩ :=
          slotProveFixedProg_res_some Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
            (Exec.Block.histOf b g a recs0) acc0 t H vf base sp0 rec0 acc1 h1
        have hrl1 : (recs0 ++ [rec0]).length = s0 + 1 := by simp [hrl]
        have hcl1 : acc1.cs.length = s0 + 1 := by rw [hacc1Eq]; simp [Exec.Block.slotAcc, hcl]
        obtain ⟨h1', h2', h3'⟩ := stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m true
          (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2 (base + slotFixedLen P s0) spsRest recsF accF hrl1 hcl1 h2
        exact ⟨by simp [h1'], by omega, by omega⟩

/-- **Complete inductive extraction of `stSlotsProveFixedProg`** (for Stage IN-C where `atLog P (elog s)`
updates `endpointLogN` per slot, leaving `draws`, `geom`, `kind`, `define`, `logCols` invariant). -/
theorem stSlotsProveFixedProg_extract (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc)
      (hrl : recs0.length = s0) (hcl : acc0.cs.length = s0)
      (hSome : ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m active recs0 s0 acc0 t).res H vf base).1
        = some (sps, recs, acc)),
      active = true
      ∧ sps.length = m
      ∧ recs.length = s0 + m
      ∧ recs.take s0 = recs0
      ∧ acc.cs.length = s0 + m
      ∧ acc.cs.take s0 = acc0.cs
      ∧ (∀ z ∈ acc0.claims.a, z ∈ acc.claims.a)
      ∧ (∀ z ∈ acc0.claims.h, z ∈ acc.claims.h)
      ∧ (∀ z ∈ acc0.claims.inp, z ∈ acc.claims.inp)
      ∧ (∀ z ∈ acc0.claims.out, z ∈ acc.claims.out)
      ∧ (∃ (dfs : Fin m → SlotDef) (vals : Fin m → List Fp2) (accs : Fin m → Acc),
          (∀ j : Fin m,
            let s := s0 + j.val
            let bj := base + slotsFixedLen P s0 j.val
            let dr := (List.range (P.draws s)).map (fun k => challengeFp2Of (vf (bj + k)))
            let ch := challengeFp2Of (vf (bj + P.draws s + 1))
            let scBase := bj + P.draws s + 3
            let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
            let rho := rhoFull.take (Exec.Block.slotShape P s).1
            let es := rhoFull.drop (Exec.Block.slotShape P s).1
            let hist := Exec.Block.histOf b g a (recs.take s)
            ch.isZero = false
            ∧ P.define s hist dr = .ok (dfs j)
            ∧ es.any (fun x => x.isZero || decide (x = Fp2.one)) = false
            ∧ Exec.Block.tabVals (Exec.Block.oneMinusProd es) rho (D.terms s hist (accs j) (dfs j) ch rhoFull) (dfs j).tabs 0 = .ok (vals j)
            ∧ (accs j).cs = acc.cs.take s
            ∧ (recs[s]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).draws = dr
            ∧ (recs[s]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).c = ch
            ∧ (recs[s]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).rho = rho
            ∧ (recs[s]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.1; omega)).es = es
            ∧ (acc.cs[s]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).2.2; omega)) = ch
            ∧ (sps[j.val]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).scalar = D.scalar s hist (accs j) (dfs j) ch
            ∧ (sps[j.val]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).rounds =
                ((scProveFixedProg Lq hL20 key (slotN P s) true (D.strat s hist (accs j) (dfs j) ch)
                  ⟨vf (bj + P.draws s + 2), 0, key⟩).res H vf scBase).1
            ∧ (sps[j.val]'(by have := (stSlotsProveFixedProg_lens Lq hL20 key P elog D b g a H vf m active recs0 s0 acc0 t base sps recs acc hrl hcl hSome).1; omega)).terms = D.terms s hist (accs j) (dfs j) ch rhoFull
            ∧ (∀ p, Tab.priv p ∈ (dfs j).tabs →
                let z0 := Exec.Block.buildClaim (atLog P (elog s)) p (Exec.Block.claimPoint p rho)
                  (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
                match p.cm with
                | .a => ∃ z ∈ acc.claims.a, z.parts = z0.parts
                | .h => ∃ z ∈ acc.claims.h, z.parts = z0.parts
                | .inp => ∃ z ∈ acc.claims.inp, z.parts = z0.parts
                | .out => ∃ z ∈ acc.claims.out, z.parts = z0.parts))
          ∧ acc.fs.map Exec.Block.MaskFunctional.terms =
              acc0.fs.map Exec.Block.MaskFunctional.terms ++
                (List.finRange m).flatMap (fun j =>
                  let s := s0 + j.val
                  let bj := base + slotsFixedLen P s0 j.val
                  let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                  let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                  let nd := Exec.Block.slotShape P s
                  let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                  let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                  match P.kind s with
                  | .standalone => [[(s, sw)], ev]
                  | _ => [ev])
          ∧ acc.hostFs.map Exec.Block.MaskFunctional.terms =
              acc0.hostFs.map Exec.Block.MaskFunctional.terms ++
                (List.finRange m).filterMap (fun j =>
                  let s := s0 + j.val
                  let bj := base + slotsFixedLen P s0 j.val
                  let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                  let nd := Exec.Block.slotShape P s
                  let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                  match P.kind s with
                  | .host =>
                    some ((s, sw) :: (dfs j).hosted.map fun hk =>
                      (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                        (Exec.Block.slotShape P hk.1).2.2).map
                          (fun w => w.mul (hk.2.mul ((accs j).cs.getD hk.1 Fp2.zero)).neg)))
                  | _ => none))
  | 0, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold stSlotsProveFixedProg at hSome
    cases active with
    | false => simp [PProg.res] at hSome
    | true =>
      simp only [↓reduceIte, PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
      rcases hSome with ⟨rfl, rfl, rfl⟩
      refine ⟨rfl, rfl, by omega, by simp [hrl], by omega, by simp [hcl],
        fun _ h => h, fun _ h => h, fun _ h => h, fun _ h => h,
        fun j => j.elim0, fun j => j.elim0, fun j => j.elim0, fun j => j.elim0, by simp, by simp⟩
  | m + 1, active, recs0, s0, acc0, t, base, sps, recs, acc, hrl, hcl, hSome => by
    unfold stSlotsProveFixedProg at hSome
    rw [PProg.res_andThen H vf _ _ (slotFixedLen P s0) base
      (slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
        (Exec.Block.histOf b g a recs0) acc0 t)] at hSome
    set r1 := (slotProveFixedProg Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
      (Exec.Block.histOf b g a recs0) acc0 t).res H vf base
    cases h1 : r1.1 with
    | none =>
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m false recs0 (s0 + 1) acc0 r1.2)] at hSome
      simp [PProg.res] at hSome
    | some v1 =>
      rcases v1 with ⟨sp0, rec0, acc1⟩
      rw [h1] at hSome
      rw [PProg.res_andThen H vf _ _ (slotsFixedLen P (s0 + 1) m) _
        (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2)] at hSome
      cases h2 : ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2).res H vf
          (base + slotFixedLen P s0)).1 with
      | none => rw [h2] at hSome; simp [PProg.res] at hSome
      | some v2 =>
        rcases v2 with ⟨spsRest, recsF, accF⟩
        rw [h2] at hSome
        simp only [PProg.res, Option.some.injEq, Prod.mk.injEq] at hSome
        rcases hSome with ⟨rfl, rfl, rfl⟩
        obtain ⟨df0, vals0, hact, hcz0, hdef0, hes0, hchk0, htv0, hrecDr0, hrecC0, hrecSc0,
          hrecRho0, hrecEs0, hrecTm0, hspSc0, hspRd0, hspTm0, hacc1Eq⟩ :=
          slotProveFixedProg_res_some Lq hL20 key (atLog P (elog s0)) (sdAt D (elog s0)) s0 active
            (Exec.Block.histOf b g a recs0) acc0 t H vf base sp0 rec0 acc1 h1
        have hrl1 : (recs0 ++ [rec0]).length = s0 + 1 := by simp [hrl]
        have hcl1 : acc1.cs.length = s0 + 1 := by rw [hacc1Eq]; simp [Exec.Block.slotAcc, hcl]
        obtain ⟨_, hspsLen, hrecsLen, hrecsTake, hcsLen, hcsTake, hmA, hmH, hmI, hmO,
          dfsR, valsR, accsR, hAllR, hFsR, hHostFsR⟩ :=
          stSlotsProveFixedProg_extract Lq hL20 key P elog D b g a H vf m true (recs0 ++ [rec0]) (s0 + 1) acc1 r1.2
            (base + slotFixedLen P s0) spsRest recsF accF hrl1 hcl1 h2
        have htake0 : recsF.take s0 = recs0 := calc
          recsF.take s0 = (recsF.take (s0 + 1)).take s0 := by rw [List.take_take, Nat.min_eq_left (by omega)]
          _ = (recs0 ++ [rec0]).take s0 := by rw [hrecsTake]
          _ = recs0 := by rw [List.take_append_of_le_length (by omega), ← hrl, List.take_length]
        have hcsTake0 : accF.cs.take s0 = acc0.cs := calc
          accF.cs.take s0 = (accF.cs.take (s0 + 1)).take s0 := by rw [List.take_take, Nat.min_eq_left (by omega)]
          _ = acc1.cs.take s0 := by rw [hcsTake]
          _ = (acc0.cs ++ [challengeFp2Of (vf (base + P.draws s0 + 1))]).take s0 := by rw [hacc1Eq]; rfl
          _ = acc0.cs := by rw [List.take_append_of_le_length (by omega), ← hcl, List.take_length]
        set rhoFull0 := (List.range (slotN P s0)).map (fun r => challengeFp2Of (vf (base + P.draws s0 + 3 + 2 * r + 1)))
        have hclMono0 := slotClaims_mem_mono (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
          (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims
        have hacc1Cl : acc1.claims = Exec.Block.slotClaims (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
            (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims := by
          rw [hacc1Eq]; rfl
        have hslotsShift : ∀ k : ℕ, slotsFixedLen P s0 (k + 1) = slotFixedLen P s0 + slotsFixedLen P (s0 + 1) k :=
          fun _ => rfl
        refine ⟨hact, by simp [hspsLen], by omega, htake0, by omega, hcsTake0,
          fun z hz => hmA z (by rw [hacc1Cl]; exact hclMono0.1 z hz),
          fun z hz => hmH z (by rw [hacc1Cl]; exact hclMono0.2.1 z hz),
          fun z hz => hmI z (by rw [hacc1Cl]; exact hclMono0.2.2.1 z hz),
          fun z hz => hmO z (by rw [hacc1Cl]; exact hclMono0.2.2.2 z hz),
          Fin.cases df0 dfsR, Fin.cases vals0 valsR, Fin.cases acc0 accsR, ?_, ?_, ?_⟩
        · intro j
          refine Fin.cases ?_ (fun j' => ?_) j
          · have hrec0At : recsF[s0]'(by omega) = rec0 := by
              have h1' : (recsF.take (s0 + 1))[s0]'(by rw [List.length_take]; omega) = recsF[s0]'(by omega) :=
                List.getElem_take
              rw [← h1']
              simp only [hrecsTake, List.getElem_append_right (by omega : recs0.length ≤ s0),
                hrl, Nat.sub_self, List.getElem_cons_zero]
            have hcs0At : accF.cs[s0]'(by omega) = challengeFp2Of (vf (base + P.draws s0 + 1)) := by
              have h1' : (accF.cs.take (s0 + 1))[s0]'(by rw [List.length_take]; omega) = accF.cs[s0]'(by omega) :=
                List.getElem_take
              rw [← h1']
              simp only [hcsTake, hacc1Eq, Exec.Block.slotAcc,
                List.getElem_append_right (by omega : acc0.cs.length ≤ s0), hcl, Nat.sub_self, List.getElem_cons_zero]
            simp only [Fin.val_zero, Nat.add_zero, slotsFixedLen, Fin.cases_zero, htake0, hcsTake0,
              hrec0At, hcs0At, List.getElem_cons_zero]
            refine ⟨hcz0, hdef0, hes0, htv0, trivial, hrecDr0, hrecC0, hrecRho0, hrecEs0, trivial, hspSc0, hspRd0, hspTm0, ?_⟩
            intro p hp
            obtain ⟨z, hzMem, hzParts⟩ := mem_slotClaimList_of_priv (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
              (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 p hp
            cases hcm : p.cm with
            | a =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .a z hzMem
              exact ⟨z, hmA z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | h =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .h z hzMem
              exact ⟨z, hmH z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | inp =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .inp z hzMem
              exact ⟨z, hmI z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
            | out =>
              rw [hcm] at hzMem
              have hIn1 := mem_slotClaims_of_mem_list (atLog P (elog s0)) (rhoFull0.take (Exec.Block.slotShape P s0).1)
                (rhoFull0.drop (Exec.Block.slotShape P s0).1) sp0.terms df0.tabs 0 acc0.claims .out z hzMem
              exact ⟨z, hmO z (by rw [hacc1Cl]; exact hIn1), hzParts⟩
          · have hR := hAllR j'
            have hsEq : s0 + (j'.val + 1) = (s0 + 1) + j'.val := by omega
            have hbEq : base + slotsFixedLen P s0 (j'.val + 1) = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j'.val := by
              rw [hslotsShift, Nat.add_assoc]
            have hscEq : ∀ {s₁ s₂ : ℕ} (hs : s₁ = s₂) (h1 : Hist) (a1 : Acc) (d1 : SlotDef) (c1 : Fp2) (st1 : Tr) (b1 : ℕ),
                ((scProveFixedProg Lq hL20 key (slotN P s₁) true (D.strat s₁ h1 a1 d1 c1) st1).res H vf b1).1
                  = ((scProveFixedProg Lq hL20 key (slotN P s₂) true (D.strat s₂ h1 a1 d1 c1) st1).res H vf b1).1 := by
              intro s₁ s₂ hs; subst hs; intros; rfl
            dsimp only
            simp only [Fin.val_succ, Fin.cases_succ, hbEq, List.getElem_cons_succ]
            rw [hscEq hsEq]
            simpa only [hsEq] using hR
        · have hshAt : ∀ s, Exec.Block.slotShape (atLog P (elog s0)) s = Exec.Block.slotShape P s := fun _ => rfl
          have hsnAt : ∀ s, slotN (atLog P (elog s0)) s = slotN P s := fun _ => rfl
          rw [hFsR, List.finRange_succ, List.flatMap_cons, hacc1Eq]
          simp only [Exec.Block.slotAcc, hshAt, hsnAt, List.map_append, List.map_singleton, List.append_assoc,
            Fin.val_zero, Nat.add_zero, slotsFixedLen]
          have hrest :
              ((List.finRange m).map Fin.succ).flatMap (fun j =>
                let s := s0 + j.val
                let bj := base + slotsFixedLen P s0 j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                match P.kind s with | .standalone => [[(s, sw)], ev] | _ => [ev])
              = (List.finRange m).flatMap (fun j =>
                let s := (s0 + 1) + j.val
                let bj := (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let rhoFull := (List.range (slotN P s)).map (fun r => challengeFp2Of (vf (bj + P.draws s + 3 + 2 * r + 1)))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                let ev := [(s, Cfs.evalWeights rhoFull nd.2.2)]
                match P.kind s with | .standalone => [[(s, sw)], ev] | _ => [ev]) := by
            rw [List.flatMap_map]
            congr 1; funext j
            have hsEq : s0 + j.succ.val = (s0 + 1) + j.val := by simp [Fin.val_succ]; omega
            have hbEq : base + slotsFixedLen P s0 j.succ.val = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val := by
              simp only [Fin.val_succ, hslotsShift, Nat.add_assoc]
            simp only [Function.comp_apply, hsEq, hbEq]
          rw [hrest]
          cases P.kind s0 <;> simp [atLog, hshAt, hsnAt, rhoFull0, List.append_assoc]
        · have hshAt : ∀ s, Exec.Block.slotShape (atLog P (elog s0)) s = Exec.Block.slotShape P s := fun _ => rfl
          rw [hHostFsR, List.finRange_succ, List.filterMap_cons, hacc1Eq]
          simp only [Exec.Block.slotAcc, hshAt, List.map_append, List.map_singleton, List.append_assoc,
            Fin.val_zero, Nat.add_zero, slotsFixedLen, Fin.cases_zero]
          have hrest :
              ((List.finRange m).map Fin.succ).filterMap (fun j =>
                let s := s0 + j.val
                let bj := base + slotsFixedLen P s0 j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                match P.kind s with
                | .host =>
                  some ((s, sw) :: (Fin.cases (motive := fun _ => SlotDef) df0 dfsR j).hosted.map fun hk =>
                    (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                      (Exec.Block.slotShape P hk.1).2.2).map
                        (fun w => w.mul (hk.2.mul ((Fin.cases (motive := fun _ => Acc) acc0 accsR j).cs.getD hk.1 Fp2.zero)).neg)))
                | _ => none)
              = (List.finRange m).filterMap (fun j =>
                let s := (s0 + 1) + j.val
                let bj := (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val
                let ch := challengeFp2Of (vf (bj + P.draws s + 1))
                let nd := Exec.Block.slotShape P s
                let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch)
                match P.kind s with
                | .host =>
                  some ((s, sw) :: (dfsR j).hosted.map fun hk =>
                    (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                      (Exec.Block.slotShape P hk.1).2.2).map
                        (fun w => w.mul (hk.2.mul ((accsR j).cs.getD hk.1 Fp2.zero)).neg)))
                | _ => none) := by
            rw [List.filterMap_map]
            congr 1; funext j
            have hsEq : s0 + j.succ.val = (s0 + 1) + j.val := by simp [Fin.val_succ]; omega
            have hbEq : base + slotsFixedLen P s0 j.succ.val = (base + slotFixedLen P s0) + slotsFixedLen P (s0 + 1) j.val := by
              simp only [Fin.val_succ, hslotsShift, Nat.add_assoc]
            simp only [Function.comp_apply, Fin.cases_succ, hsEq, hbEq]
          rw [hrest]
          cases P.kind s0 <;> simp [atLog, hshAt, rhoFull0, List.append_assoc]

private theorem slotAcc_fs_len_eq (s : Fin 28) (P : BlockParams) (hc : ShdHostCoeffs shdP_K)
    (hKind : ∀ t : Fin (shdSegNS s), P.kind t.val = match shdSegKind s t with
      | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host)
    (cs : Fin (shdSegNS s) → Fp2) (rhos : Fin (shdSegNS s) → List Fp2) (dfs : Fin (shdSegNS s) → SlotDef)
    (fs : List Exec.Block.MaskFunctional)
    (hFsTerms : fs.map Exec.Block.MaskFunctional.terms =
      (List.finRange (shdSegNS s)).flatMap (fun t =>
        let nd := Exec.Block.slotShape P t.val
        let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
        let ev := [(t.val, Cfs.evalWeights (rhos t) nd.2.2)]
        match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
      ++ (List.finRange (shdSegNS s)).filterMap (fun t =>
        let nd := Exec.Block.slotShape P t.val
        let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
        match P.kind t.val with
        | .host =>
          some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
            (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
              (Exec.Block.slotShape P hk.1).2.2).map
                (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then cs ⟨hk.1, h⟩ else Fp2.zero)).neg)))
        | _ => none)) :
    fs.length = (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length := by
  have h1 := congrArg List.length hFsTerms
  simp only [List.length_map, List.length_append] at h1
  rw [h1]
  unfold codeFuns
  rw [List.length_append]
  refine congrArg₂ (· + ·) ?_ ?_
  · rw [List.length_flatMap, List.length_flatMap]
    congr 1; refine List.map_congr_left fun t _ => ?_
    rw [hKind t]; cases shdSegKind s t <;> rfl
  · have hfm : ∀ (l : List (Fin (shdSegNS s))) (f : Fin (shdSegNS s) → Option (List (ℕ × List Fp2)))
        (g : Fin (shdSegNS s) → Option (MFun shdP_K (shdSegNS s))),
        (∀ t ∈ l, (f t).isSome = (g t).isSome) → (l.filterMap f).length = (l.filterMap g).length := by
      intro l f g hfg; induction l with
      | nil => rfl
      | cons a as ih =>
        have ha := hfg a List.mem_cons_self
        have ih' := ih (fun t ht => hfg t (List.mem_cons_of_mem _ ht))
        cases hf : f a <;> cases hg : g a <;> simp_all
    refine hfm _ _ _ fun t _ => ?_
    rw [hKind t]; cases shdSegKind s t <;> rfl

/-- **Generic `codeFuns` 1-to-1 match for `acc.fs ++ acc.hostFs`** across ANY segment `s : Fin 28`:
discharges BOTH `segMOpenPub_hW` AND `segMOpenPub_hlay` in one shot! -/
theorem slotAcc_codeFuns_hW_hlay (s : Fin 28) (P : BlockParams) (hc : ShdHostCoeffs shdP_K)
    (hKind : ∀ t : Fin (shdSegNS s), P.kind t.val = match shdSegKind s t with
      | .standalone => SlotKind.standalone | .priv => SlotKind.priv | .host => SlotKind.host)
    (hShape : ∀ t : Fin (shdSegNS s),
      (Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1 = (shdP_L2Spec s).n t + 1
      ∧ (Exec.Block.slotShape P t.val).2.2 = (shdP_L2Spec s).d t)
    (hN64 : ∀ t : Fin (shdSegNS s), (shdP_L2Spec s).n t + 1 < 64)
    (cs : Fin (shdSegNS s) → Fp2)
    (rhos : Fin (shdSegNS s) → List Fp2)
    (hrhoLen : ∀ t : Fin (shdSegNS s), (rhos t).length = (shdP_L2Spec s).n t + 1)
    (dfs : Fin (shdSegNS s) → SlotDef)
    (hHosted : ∀ t : Fin (shdSegNS s), shdSegKind s t = .host →
      (dfs t).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))
        = (shdSegHosts hc s t).map (fun p => (p.1.val, p.2))
      ∧ ∀ hk ∈ (dfs t).hosted, hk.1 < t.val)
    (fs : List Exec.Block.MaskFunctional)
    (hFsTerms : fs.map Exec.Block.MaskFunctional.terms =
      (List.finRange (shdSegNS s)).flatMap (fun t =>
        let nd := Exec.Block.slotShape P t.val
        let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
        let ev := [(t.val, Cfs.evalWeights (rhos t) nd.2.2)]
        match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
      ++ (List.finRange (shdSegNS s)).filterMap (fun t =>
        let nd := Exec.Block.slotShape P t.val
        let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
        match P.kind t.val with
        | .host =>
          some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
            (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
              (Exec.Block.slotShape P hk.1).2.2).map
                (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then cs ⟨hk.1, h⟩ else Fp2.zero)).neg)))
        | _ => none)) :
    (∀ f ∈ fs, ∀ tm ∈ f.terms, ∃ hlt : tm.1 < shdSegNS s, tm.2.length ≤ shdP_slotMaskLen s ⟨tm.1, hlt⟩)
    ∧ fs.length = (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length
    ∧ ∀ (a : (t : Fin (shdSegNS s)) → Hiding.CfsCoeffs shdP_K ((shdP_L2Spec s).n t) ((shdP_L2Spec s).d t))
        (i : Fin (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length),
        let f := fs[i.val]'(by have := slotAcc_fs_len_eq s P hc hKind cs rhos dfs fs hFsTerms; omega)
        let aCoeffs := packSegMA s ((a, (fun _ _ _ => 0, fun _ _ => 0, fun _ _ => 0)), fun _ => zeroDig)
        (f.terms.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum
          = mfMask (fun t => (cs t).toK shdP_U) (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhos t))
              (codeFunsAt (shdSegNS s) (shdSegKind s) (shdSegHosts hc s) i) a := by
  let L1 := (List.finRange (shdSegNS s)).flatMap fun t =>
    let nd := Exec.Block.slotShape P t.val
    let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
    let ev := [(t.val, Cfs.evalWeights (rhos t) nd.2.2)]
    match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev]
  let L2 := (List.finRange (shdSegNS s)).filterMap fun t =>
    let nd := Exec.Block.slotShape P t.val
    let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul (cs t))
    match P.kind t.val with
    | .host =>
      some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
        (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
          (Exec.Block.slotShape P hk.1).2.2).map
            (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then cs ⟨hk.1, h⟩ else Fp2.zero)).neg)))
    | _ => none
  let C1 : List (MFun shdP_K (shdSegNS s)) := (List.finRange (shdSegNS s)).flatMap fun t =>
    if shdSegKind s t = .standalone then [MFun.total t, MFun.eval t] else [MFun.eval t]
  let C2 : List (MFun shdP_K (shdSegNS s)) := (List.finRange (shdSegNS s)).filterMap fun t =>
    if shdSegKind s t = .host then some (MFun.host t (shdSegHosts hc s t)) else none
  have hMdotEq : ∀ (a : (t : Fin (shdSegNS s)) → Hiding.CfsCoeffs shdP_K ((shdP_L2Spec s).n t) ((shdP_L2Spec s).d t)),
      (L1 ++ L2).map (fun ts => (ts.map (Block.mdot shdP_U (mRowKOf (shdSegNS s)
        (packSegMA s ((a, (fun _ _ _ => 0, fun _ _ => 0, fun _ _ => 0)), fun _ => zeroDig))) 512)).sum)
        = (C1 ++ C2).map (fun mf => mfMask (fun t => (cs t).toK shdP_U)
            (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhos t)) mf a) := by
    intro a
    set aCoeffs := packSegMA s ((a, (fun _ _ _ => 0, fun _ _ => 0, fun _ _ => 0)), fun _ => zeroDig)
    have hL1 : L1.map (fun ts => (ts.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum)
        = C1.map (fun mf => mfMask (fun t => (cs t).toK shdP_U)
            (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhos t)) mf a) := by
      dsimp only [L1, C1]
      rw [List.map_flatMap, List.map_flatMap]
      congr 1; funext t
      have hsh := hShape t
      have hW512 : ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t + 2 ≤ 512 := by
        have := (shdP_L2_slot_bounds s t).2.2.2; unfold shdP_slotMaskLen at this; omega
      have hsw : Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512
            (t.val, (Cfs.sumWeights ((Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1)
              (Exec.Block.slotShape P t.val).2.2).map (fun w => w.mul (cs t)))
          = (cs t).toK shdP_U * Hiding.cfsTotal (a t) := by
        rw [hsh.1, hsh.2, mTrue_sumWeights_eq (shdSegNS s) aCoeffs t.val _ _ (by omega) (hN64 t) hW512 (cs t),
          cubeSum_maskPoly_packSegMA_eq_cfsTotal s _ t]
      have hev : Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512
            (t.val, Cfs.evalWeights (rhos t) (Exec.Block.slotShape P t.val).2.2)
          = Hiding.cfsEval (a t) (vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhos t)) := by
        rw [hsh.2, mTrue_evalWeights_eq (shdSegNS s) aCoeffs t.val _ _ (by omega) (rhos t) (hrhoLen t) hW512,
          maskPoly_packSegMA_eq_cfsEval s _ t]
      rw [hKind t]
      cases hk : shdSegKind s t <;> simp [mfMask, hsw, hev]
    have hL2 : L2.map (fun ts => (ts.map (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512)).sum)
        = C2.map (fun mf => mfMask (fun t => (cs t).toK shdP_U)
            (fun t => vecK shdP_U ((shdP_L2Spec s).n t + 1) (rhos t)) mf a) := by
      dsimp only [L2, C2]
      rw [List.map_filterMap, List.map_filterMap]
      congr 1; funext t
      rw [hKind t]
      cases hk : shdSegKind s t with
      | standalone => simp
      | priv => simp
      | host =>
        simp only [↓reduceIte, Option.map_some, Option.some.injEq, List.map_cons, List.sum_cons, mfMask]
        have hsh := hShape t
        have hW512 : ((shdP_L2Spec s).n t + 1) * (shdP_L2Spec s).d t + 2 ≤ 512 := by
          have := (shdP_L2_slot_bounds s t).2.2.2; unfold shdP_slotMaskLen at this; omega
        have hsw : Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512
              (t.val, (Cfs.sumWeights ((Exec.Block.slotShape P t.val).1 + (Exec.Block.slotShape P t.val).2.1)
                (Exec.Block.slotShape P t.val).2.2).map (fun w => w.mul (cs t)))
            = (cs t).toK shdP_U * Hiding.cfsTotal (a t) := by
          rw [hsh.1, hsh.2, mTrue_sumWeights_eq (shdSegNS s) aCoeffs t.val _ _ (by omega) (hN64 t) hW512 (cs t),
            cubeSum_maskPoly_packSegMA_eq_cfsTotal s _ t]
        rw [hsw, sub_eq_add_neg ((cs t).toK shdP_U * Hiding.cfsTotal (a t))]
        refine congrArg ((cs t).toK shdP_U * Hiding.cfsTotal (a t) + ·) ?_
        obtain ⟨hHostMap, hHostLt⟩ := hHosted t hk
        have htail :
            (((dfs t).hosted.map fun hk =>
              (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                (Exec.Block.slotShape P hk.1).2.2).map
                  (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then cs ⟨hk.1, h⟩ else Fp2.zero)).neg))).map
              (Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512))
            = (shdSegHosts hc s t).map (fun p => -(p.2 * ((cs p.1).toK shdP_U * Hiding.cfsTotal (a p.1)))) := by
          rw [List.map_map]
          have h1 : ((dfs t).hosted.map fun hk =>
              Block.mdot shdP_U (mRowKOf (shdSegNS s) aCoeffs) 512
                (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
                  (Exec.Block.slotShape P hk.1).2.2).map
                    (fun w => w.mul (hk.2.mul (if h : hk.1 < shdSegNS s then cs ⟨hk.1, h⟩ else Fp2.zero)).neg)))
              = ((dfs t).hosted.map (fun hk => (hk.1, hk.2.toK shdP_U))).map (fun p =>
                  if h : p.1 < shdSegNS s then -(p.2 * ((cs ⟨p.1, h⟩).toK shdP_U * Hiding.cfsTotal (a ⟨p.1, h⟩))) else 0) := by
            rw [List.map_map]
            refine List.map_congr_left fun hk hmem => ?_
            have hltS : hk.1 < shdSegNS s := lt_trans (hHostLt hk hmem) t.isLt
            simp only [Function.comp_apply, dite_eq_left hltS]
            let u : Fin (shdSegNS s) := ⟨hk.1, hltS⟩
            have hshu := hShape u
            have hWu : ((shdP_L2Spec s).n u + 1) * (shdP_L2Spec s).d u + 2 ≤ 512 := by
              have := (shdP_L2_slot_bounds s u).2.2.2; unfold shdP_slotMaskLen at this; omega
            rw [hshu.1, hshu.2,
              mTrue_sumWeights_eq (shdSegNS s) aCoeffs u.val _ _ (by omega) (hN64 u) hWu _,
              cubeSum_maskPoly_packSegMA_eq_cfsTotal s _ u,
              Fp2.toK_neg shdP_U _ (Fp2.canon_mul _ _), Fp2.toK_mul shdP_U shdP_hU]
            ring
          rw [Function.comp_def, h1, hHostMap, List.map_map]
          refine List.map_congr_left fun p _ => by simp [p.1.isLt]
        rw [htail]
        have hsumNeg : ∀ l : List (Fin (shdSegNS s) × shdP_K),
            (l.map fun p => -(p.2 * ((cs p.1).toK shdP_U * Hiding.cfsTotal (a p.1)))).sum
              = -(l.map fun p => p.2 * ((cs p.1).toK shdP_U * Hiding.cfsTotal (a p.1))).sum := by
          intro l; induction l with
          | nil => simp
          | cons p ps ih => simp only [List.map_cons, List.sum_cons, ih]; ring
        exact hsumNeg _
    rw [List.map_append, List.map_append, hL1, hL2]
  have hLenEq : fs.length = (codeFuns (shdSegNS s) (shdSegKind s) (shdSegHosts hc s)).length := by
    have h0 := congrArg List.length (hMdotEq (fun _ => (0, 0, fun _ _ => 0)))
    have h1 := congrArg List.length hFsTerms
    simp only [List.length_map] at h0 h1
    exact h1.trans h0
  refine ⟨?_, hLenEq, ?_⟩
  · intro f hf tm htm
    have hfIn : f.terms ∈ L1 ++ L2 := by
      rw [← hFsTerms]; exact List.mem_map.mpr ⟨f, hf, rfl⟩
    rcases List.mem_append.mp hfIn with h1 | h2
    · obtain ⟨t, -, ht⟩ := List.mem_flatMap.mp h1
      have hsh := hShape t
      rw [hKind t] at ht
      cases hk : shdSegKind s t with
      | standalone =>
        simp only [hk, List.mem_cons, List.not_mem_nil, or_false] at ht
        rcases ht with ht | ht
        · rw [ht] at htm; obtain rfl := List.mem_singleton.mp htm
          refine ⟨t.isLt, ?_⟩
          simp only [List.length_map, cfs_sumWeights_length, hsh.1, hsh.2]; exact le_rfl
        · rw [ht] at htm; obtain rfl := List.mem_singleton.mp htm
          refine ⟨t.isLt, ?_⟩
          simp only [cfs_evalWeights_length, hrhoLen t, hsh.2]; exact le_rfl
      | priv =>
        simp only [hk, List.mem_cons, List.not_mem_nil, or_false] at ht
        rw [ht] at htm; obtain rfl := List.mem_singleton.mp htm
        refine ⟨t.isLt, ?_⟩
        simp only [cfs_evalWeights_length, hrhoLen t, hsh.2]; exact le_rfl
      | host =>
        simp only [hk, List.mem_cons, List.not_mem_nil, or_false] at ht
        rw [ht] at htm; obtain rfl := List.mem_singleton.mp htm
        refine ⟨t.isLt, ?_⟩
        simp only [cfs_evalWeights_length, hrhoLen t, hsh.2]; exact le_rfl
    · obtain ⟨t, -, ht⟩ := List.mem_filterMap.mp h2
      rw [hKind t] at ht
      cases hk : shdSegKind s t with
      | standalone => simp only [hk] at ht; cases ht
      | priv => simp only [hk] at ht; cases ht
      | host =>
        simp only [hk, Option.some.injEq] at ht
        rw [← ht] at htm
        rcases List.mem_cons.mp htm with rfl | htm'
        · refine ⟨t.isLt, ?_⟩
          have hsh := hShape t
          simp only [List.length_map, cfs_sumWeights_length, hsh.1, hsh.2]; exact le_rfl
        · obtain ⟨hkPair, hhkMem, rfl⟩ := List.mem_map.mp htm'
          have hltS : hkPair.1 < shdSegNS s := lt_trans ((hHosted t hk).2 hkPair hhkMem) t.isLt
          refine ⟨hltS, ?_⟩
          have hshu := hShape ⟨hkPair.1, hltS⟩
          simp only [List.length_map, cfs_sumWeights_length, hshu.1, hshu.2]; exact le_rfl
  · intro a i
    have hMap := hMdotEq a
    rw [← hFsTerms, List.map_map] at hMap
    have hget := congrArg (fun l => l[i.val]?) hMap
    have hiFs : i.val < fs.length := by omega
    have hiCF : i.val < (C1 ++ C2).length := i.isLt
    simp only [List.getElem?_map, List.getElem?_eq_getElem hiFs, List.getElem?_eq_getElem hiCF,
      Option.map_some, Option.some.injEq, Function.comp_apply] at hget
    exact hget

end SlotLoopExtract

end ZK60.HonestShield
