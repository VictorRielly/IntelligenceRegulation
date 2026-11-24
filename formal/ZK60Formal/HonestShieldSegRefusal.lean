/-
D63 lane L68c, part 3b (`HonestShieldSegRefusal.lean`):
per-segment `startSite` refusal covers for Stage IN-C, Block `k` (`k < 26`), and Stage OUT-C
on the concrete Shieldstral T128 R13 instance, together with exact per-kind site counts proving
that `1 IN-C + 26 Blocks + 1 OUT-C` fits strictly inside `shdP_siteCount`:
- Kind 0 (opening dep-pair, `k = gP`): `3 + 26 * 3 + 3 = 84 ≤ 128`
- Kind 1 (opening zero draws + `openingGroupsAt` pairwise `ZKey` collisions, `k ≤ 1`):
  `20 + 26 * 872 + 175 = 22,867 ≤ 1,048,576`
- Kind 2 (CFS `c = 0`, `k = 1`): `4 + 26 * 23 + 8 = 610 ≤ 4,096`
- Kind 3 (degenerate extension `e ∈ {0, 1}`, exact `ext` rounds only, `k = 2`):
  `4 + 26 * 25 + 8 = 662 ≤ 4,096`
- Kind 4 (`define` zero draws, `k = 1`): `8 + 26 * 16 + 23 = 447 ≤ 4,096`
- Kind 5 (LogUp `α` + IN-C `r_emb`, `k ≤ 2^17`): `13 + 26 * 1 + 1 = 40 ≤ 141`
- Kind 6 (D66(3) dictionaries): `0 ≤ 32`.

Exported main theorems:
- `shdP_runUsedCount_eq`, `shdP_runUsedCount_le`, `shdP_runUsedCount_lt`
- `incSegSite`, `incSegSite_k_delta`, **`incSeg_refuse_cover`**
- `shdP_blkAlphaStartSite`, `shdP_blkAlphaBad_cover`, `blkSegSite`, `blkSegSite_k_delta`,
  **`blkSeg_refuse_cover`**, `shdP_blkSegP_refuse_cover`
- `outcSegSite`, `outcSegSite_k_delta`, **`outcSeg_refuse_cover`**.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); fast elaboration
(never unfolds `shdVi`, `clog2 131072`, `tauTable`, `embFoldL`, `shdP_Pk0`, or `pubsR13L`).
-/
import ZK60Formal.HonestShieldRefusal
import ZK60Formal.HonestShieldAuditDet
import ZK60Formal.HonestShieldBlockBase
import ZK60Formal.RunStgShieldDg
import ZK60Formal.RunStgShieldIncZS
import ZK60Formal.BlockR13LookBase
import ZK60Formal.BlockR13HostPub

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Exec.StageCheck ZK60.Sound ZK60.TokenRun
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldCal shieldS0 shieldShape ShieldRun)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec SlotKind SlotS Tab TabS Priv PrivS
  histOf slotShape slotTerms slotDefChecks hostedSum tabVals maskCoef labA labH labM
  absorbRoot defineS defineS_ok)
open ZK60.Exec.Block.Join.R13H.Look (TbIx TR13 card_tbIx)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13L pubsR13 restR13L)
open ZK60.Exec.Block.Join.R13T (restR13)
open ZK60.Exec.Block.Join.W16 (cubeTab foldTab)

/-! ## 1. Exact Per-Segment & Full-Run Site Counts, `Fin` Packing, and Block Opening Geometries -/

section CountsAndPacking

/-- Exact per-kind site counts for Stage IN-C (`3, 20, 4, 4, 8, 13, 0`). -/
def incSegCount : Fin 7 → ℕ
  | 0 => 3 | 1 => 20 | 2 => 4 | 3 => 4 | 4 => 8 | 5 => 13 | 6 => 0

/-- Exact per-kind site counts for one Shieldstral T128 R13 Block (`3, 872, 23, 25, 16, 1, 0`). -/
def blkSegCount : Fin 7 → ℕ
  | 0 => 3 | 1 => 872 | 2 => 23 | 3 => 25 | 4 => 16 | 5 => 1 | 6 => 0

/-- Exact per-kind site counts for Stage OUT-C (`3, 175, 8, 8, 23, 1, 0`). -/
def outcSegCount : Fin 7 → ℕ
  | 0 => 3 | 1 => 175 | 2 => 8 | 3 => 8 | 4 => 23 | 5 => 1 | 6 => 0

/-- Total refusal sites used across 1 Stage IN-C + 26 R13 Blocks + 1 Stage OUT-C, by kind. -/
def shdP_runUsedCount (j : Fin 7) : ℕ :=
  incSegCount j + 26 * blkSegCount j + outcSegCount j

/-- Exact per-kind totals across the 28-segment Shieldstral T128 R13 run. -/
theorem shdP_runUsedCount_eq :
    shdP_runUsedCount 0 = 84 ∧ shdP_runUsedCount 1 = 22867 ∧ shdP_runUsedCount 2 = 610
      ∧ shdP_runUsedCount 3 = 662 ∧ shdP_runUsedCount 4 = 447
      ∧ shdP_runUsedCount 5 = 40 ∧ shdP_runUsedCount 6 = 0 := by decide

/-- Every kind's total across 1 IN-C + 26 Blocks + 1 OUT-C fits inside `shdP_siteCount`. -/
theorem shdP_runUsedCount_le : ∀ j : Fin 7, shdP_runUsedCount j ≤ shdP_siteCount j := by decide

/-- Every kind's total fits strictly inside `shdP_siteCount`. -/
theorem shdP_runUsedCount_lt : ∀ j : Fin 7, shdP_runUsedCount j < shdP_siteCount j := by decide

/-- Concrete `OpenGeom` for Shieldstral R13 block commitment `A` (`4577` rows, `146` sites, `36` groups). -/
def shdP_blkOpenGeomA : OpenGeom := ⟨4577, List.range' 4283 292, none, 4575, 36⟩

/-- Concrete `OpenGeom` for Shieldstral R13 block commitment `H` (`4390` rows, `53` sites + `U`, `9` groups). -/
def shdP_blkOpenGeomH : OpenGeom := ⟨4390, List.range' 4282 106, some (4280, 4281), 4388, 9⟩

/-- Concrete `Cm → OpenGeom` for `Exec.checkField` on Shieldstral R13 blocks. -/
def shdP_blkOpenGeom : Cm → OpenGeom
  | .a => shdP_blkOpenGeomA
  | _ => shdP_blkOpenGeomH

/-- Concrete `OpenGeom` for a 38-row, 2-site Shieldstral R13 boundary commitment `B_k`. -/
def shdP_bndOpenGeom : OpenGeom := ⟨38, [32, 33, 34, 35], none, 36, 2⟩

/-- Concatenate two `Fin`-indexed families. -/
def finApp {A : Type*} {m n : ℕ} (f : Fin m → A) (g : Fin n → A) (i : Fin (m + n)) : A :=
  if h : i.val < m then f ⟨i.val, h⟩ else g ⟨i.val - m, by omega⟩

theorem finApp_left {A : Type*} {m n : ℕ} (f : Fin m → A) (g : Fin n → A) (i : Fin m) :
    finApp f g ⟨i.val, by omega⟩ = f i := by
  unfold finApp; rw [dite_eq_left i.isLt]

theorem finApp_right {A : Type*} {m n : ℕ} (f : Fin m → A) (g : Fin n → A) (j : Fin n) :
    finApp f g ⟨m + j.val, by omega⟩ = g j := by
  unfold finApp; rw [dite_eq_right (by dsimp only; omega)]; congr 1; exact Fin.ext (by dsimp only; omega)

theorem finApp_prop {A : Type*} {m n : ℕ} (f : Fin m → A) (g : Fin n → A) (P : A → Prop)
    (hf : ∀ i, P (f i)) (hg : ∀ j, P (g j)) (i : Fin (m + n)) : P (finApp f g i) := by
  unfold finApp
  by_cases h : i.val < m
  · rw [dite_eq_left h]; exact hf ⟨i.val, h⟩
  · rw [dite_eq_right h]; exact hg ⟨i.val - m, by omega⟩

/-- Concatenate three `Fin`-indexed families (`m₁ + m₂ + m₃`). -/
def finApp3 {A : Type*} {m₁ m₂ m₃ : ℕ} (f₁ : Fin m₁ → A) (f₂ : Fin m₂ → A) (f₃ : Fin m₃ → A)
    (i : Fin (m₁ + m₂ + m₃)) : A :=
  finApp (finApp f₁ f₂) f₃ i

theorem finApp3_1 {A : Type*} {m₁ m₂ m₃ : ℕ} (f₁ : Fin m₁ → A) (f₂ : Fin m₂ → A) (f₃ : Fin m₃ → A)
    (i : Fin m₁) : finApp3 f₁ f₂ f₃ ⟨i.val, by omega⟩ = f₁ i := by
  unfold finApp3
  rw [finApp_left (f := finApp f₁ f₂) (g := f₃) (i := ⟨i.val, by omega⟩), finApp_left]

theorem finApp3_2 {A : Type*} {m₁ m₂ m₃ : ℕ} (f₁ : Fin m₁ → A) (f₂ : Fin m₂ → A) (f₃ : Fin m₃ → A)
    (i : Fin m₂) : finApp3 f₁ f₂ f₃ ⟨m₁ + i.val, by omega⟩ = f₂ i := by
  unfold finApp3
  rw [finApp_left (f := finApp f₁ f₂) (g := f₃) (i := ⟨m₁ + i.val, by omega⟩), finApp_right]

theorem finApp3_3 {A : Type*} {m₁ m₂ m₃ : ℕ} (f₁ : Fin m₁ → A) (f₂ : Fin m₂ → A) (f₃ : Fin m₃ → A)
    (i : Fin m₃) : finApp3 f₁ f₂ f₃ ⟨m₁ + m₂ + i.val, by omega⟩ = f₃ i := by
  unfold finApp3; exact finApp_right (finApp f₁ f₂) f₃ i

theorem finApp3_prop {A : Type*} {m₁ m₂ m₃ : ℕ} (f₁ : Fin m₁ → A) (f₂ : Fin m₂ → A) (f₃ : Fin m₃ → A)
    (P : A → Prop) (h₁ : ∀ i, P (f₁ i)) (h₂ : ∀ i, P (f₂ i)) (h₃ : ∀ i, P (f₃ i))
    (i : Fin (m₁ + m₂ + m₃)) : P (finApp3 f₁ f₂ f₃ i) :=
  finApp_prop (finApp f₁ f₂) f₃ P (finApp_prop f₁ f₂ P h₁ h₂) h₃ i

/-- Index a pair-list site family via `List.getD`. -/
def listPairSite {A : Type*} (L : List (ℕ × ℕ)) (f : ℕ → ℕ → A) (i : Fin L.length) : A :=
  f (L.getD i.val (0, 0)).1 (L.getD i.val (0, 0)).2

theorem listPairSite_of_mem {A : Type*} (L : List (ℕ × ℕ)) (f : ℕ → ℕ → A) (P : A → Prop)
    (s j : ℕ) (hmem : (s, j) ∈ L) (hp : P (f s j)) : ∃ i : Fin L.length, P (listPairSite L f i) := by
  obtain ⟨m, hm, heq⟩ := exists_getD_of_mem (0, 0) (s, j) L hmem
  exact ⟨⟨m, hm⟩, by unfold listPairSite; rw [heq]; exact hp⟩

theorem listPairSite_prop {A : Type*} (L : List (ℕ × ℕ)) (f : ℕ → ℕ → A) (P : A → Prop)
    (h : ∀ s j, P (f s j)) (i : Fin L.length) : P (listPairSite L f i) := h _ _

theorem mem_range'_of_bounds : ∀ (a len x : ℕ), a ≤ x → x < a + len → x ∈ List.range' a len
  | _, 0, _, _, _ => by omega
  | a, len + 1, x, h1, h2 => by
    by_cases heq : x = a
    · subst heq; exact List.mem_cons_self
    · exact List.mem_cons_of_mem a (mem_range'_of_bounds (a + 1) len x (by omega) (by omega))

end CountsAndPacking

/-! ## 2. Shared `startSite` Combinators, Bounded Opening Covers, and `fam_startCover_ext` -/

section SharedCombinators

theorem noWrap_start_of_sqLE {β : Type} {key : Option Dig} {p : TProg β} {n : ℕ}
    (hsq : SqLE n p) (hn : n < 2 ^ 64) (dg : Dig) : TProg.NoWrap p ⟨dg, 0, key⟩ :=
  noWrap_of_sqLE p n ⟨dg, 0, key⟩ hsq (by
    change (0 : UInt64).toNat + n < 2 ^ 64
    rw [show (0 : UInt64).toNat = 0 from rfl, Nat.zero_add]; exact hn)

/-- `bMask` transcript program (`HonestRunProg.maskProg` at Shieldstral's `rootFp 9`, `rootFp 12`). -/
noncomputable def bMaskProg {α : Type} (S : ℕ) (M : α → MTable)
    (fs : α → List Exec.Block.MaskFunctional) (pre : TProg α) :
    TProg (α × List Fp2 × List Fp2 × List Dig) :=
  maskProg S
    (fun a th => polyWords shdP_U shdP_hbij
      (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) (M a) S ((fs a).map toMF) (th.toK shdP_U)))
    (fun a _ rs => polyWords shdP_U shdP_hbij (pPoly shdP_U (M a) S rs)) pre

theorem sep_bMaskProg {α : Type} (key : Option Dig) (S : ℕ) (M : α → MTable)
    (fs : α → List Exec.Block.MaskFunctional) (pre : TProg α) (hp : TProg.Sep key pre) :
    TProg.Sep key (bMaskProg S M fs pre) := sep_maskProg key S _ _ pre hp

theorem sqLE_bMaskProg {α : Type} (S m : ℕ) (M : α → MTable)
    (fs : α → List Exec.Block.MaskFunctional) (pre : TProg α) (hp : SqLE m pre) :
    SqLE (m + (1 + (2 * S + 2) + (mQ + 3) / 4)) (bMaskProg S M fs pre) := sqLE_maskProg S _ _ pre m hp

theorem final_bMaskProg {α : Type} (H : HIn → Dig) (tag : MTag) (S : ℕ) (M : α → MTable)
    (fs : α → List Exec.Block.MaskFunctional) (pre : TProg α) (t : Tr) :
    ((bMaskProg S M fs pre).final H t).1
      = (bMask H tag shdP_U shdP_hbij (M (pre.final H t).2) S (fs (pre.final H t).2) (pre.final H t).1).2
      ∧ ((bMaskProg S M fs pre).final H t).2.1 = (pre.final H t).2 :=
  final_maskProg_prove H tag shdP_U shdP_hbij (rootFp 9) (rootFp 12) M S (fun a => (fs a).map toMF) pre t

private theorem pushAt_sum_le {α β : Type} :
    ∀ (l : List (α × List β)) (i : ℕ) (m : β),
      ((pushAt l i m).map (fun g => g.2.length)).sum ≤ (l.map (fun g => g.2.length)).sum + 1
  | [], _, _ => by simp [pushAt]
  | _ :: _, 0, _ => by simp [pushAt]; omega
  | _ :: xs, i + 1, m => by
    have ih := pushAt_sum_le xs i m; simp only [pushAt, List.map_cons, List.sum_cons]; omega

private theorem groupZclaims_fold_sum_le (rows logCols : ℕ) :
    ∀ (claims : List Exec.ZClaim) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))),
      (((claims.foldl (groupStep rows logCols) st).2).map (fun g => g.2.length)).sum
        ≤ (st.2.map (fun g => g.2.length)).sum + claims.length
  | [], _ => by simp
  | c :: cs, st => by
    have hstep : (((groupStep rows logCols st c).2).map (fun g => g.2.length)).sum
        ≤ (st.2.map (fun g => g.2.length)).sum + 1 := by
      unfold groupStep; dsimp only
      cases keyIdx st.1 (claimWeights c rows logCols).2 with
      | some gi => dsimp only; exact pushAt_sum_le st.2 gi _
      | none => dsimp only; simp
    have ih := groupZclaims_fold_sum_le rows logCols cs (groupStep rows logCols st c)
    rw [List.foldl_cons, List.length_cons]; omega

theorem groupZclaims_sum_le (claims : List Exec.ZClaim) (rows logCols : ℕ) :
    ((groupZclaims claims rows logCols).map (fun g => g.2.length)).sum ≤ claims.length := by
  simpa [groupZclaims] using groupZclaims_fold_sum_le rows logCols claims ([], [])

/-- Truncated `bOpen` transcript program: unconditional `SqLE` by `maxCl + maxRows + (prm.nQ + 3) / 4`,
and exact `final` agreement with `bOpen` whenever `(cl a).length ≤ maxCl`. -/
def bOpenProg {α : Type} (prm : PcsPrm) (maxCl : ℕ) (T : α → Table)
    (cl : α → List Exec.Block.ZClaim) (pre : TProg α) :
    TProg (α × List (List Fp2) × List Dig) :=
  pcsProg prm T (fun a => ((cl a).map toZClaim).take maxCl) pre

theorem sep_bOpenProg {α : Type} (key : Option Dig) (prm : PcsPrm) (maxCl : ℕ) (T : α → Table)
    (cl : α → List Exec.Block.ZClaim) (pre : TProg α) (hp : TProg.Sep key pre) :
    TProg.Sep key (bOpenProg prm maxCl T cl pre) := sep_pcsProg key prm T _ pre hp

theorem sqLE_bOpenProg {α : Type} (prm : PcsPrm) (maxCl maxRows m : ℕ) (T : α → Table)
    (cl : α → List Exec.Block.ZClaim) (pre : TProg α) (hp : SqLE m pre)
    (hrows : ∀ a, (T a).rows.length ≤ maxRows) :
    SqLE (m + (maxCl + maxRows + (prm.nQ + 3) / 4)) (bOpenProg prm maxCl T cl pre) := by
  refine sqLE_pcsProg prm T _ pre m (maxCl + maxRows + (prm.nQ + 3) / 4) hp (fun a => ?_)
  unfold pGroups
  have h1 := groupZclaims_sum_le (((cl a).map toZClaim).take maxCl) (T a).rows.length prm.logCols
  have h2 := List.length_take_le maxCl ((cl a).map toZClaim)
  have h3 := hrows a; omega

theorem final_bOpenProg {α : Type} (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth maxCl : ℕ)
    (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ) (T : α → Table)
    (cl : α → List Exec.Block.ZClaim) (pre : TProg α) (t : Tr)
    (hlen : (cl (pre.final H t).2).length ≤ maxCl) :
    ((bOpenProg prm maxCl T cl pre).final H t).1
      = (bOpen H tag prm depth (T (pre.final H t).2) (cl (pre.final H t).2) (pre.final H t).1).2
      ∧ ((bOpenProg prm maxCl T cl pre).final H t).2.1 = (pre.final H t).2 := by
  have h := final_pcsProg_prove H tag prm depth hnn hnQ T (fun a => ((cl a).map toZClaim).take maxCl) pre t
  have htake : ((cl (pre.final H t).2).map toZClaim).take maxCl = (cl (pre.final H t).2).map toZClaim :=
    List.take_of_length_le (by rw [List.length_map]; exact hlen)
  unfold bOpenProg
  exact ⟨by rw [h.1, htake]; rfl, h.2⟩

/-- `startSite` lift of `depCSite` (`k = 1`, `δ = 0`, Kind 2). -/
noncomputable def depCStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (pre : Coins → TProg (α × List SlotRec × Acc)) (i : ℕ)
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (depCProg Pf (pre c) i) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom (fun c => depCProg Pf (pre c) i) (fun _ => {0}) 1
    (fun _ => by simp) (fun c => sep_depCProg Pf key (pre c) i (hs c)) hn

/-- `startSite` lift of `depESite` (`k = 2`, `δ = 0`, Kind 3). -/
noncomputable def depEStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : Coins → TProg (α × List SlotRec × Acc)) (i m : ℕ)
    (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (depEProg Pf Df bga (pre c) i m) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom (fun c => depEProg Pf Df bga (pre c) i m) (fun _ => {0, 1}) 2
    (fun _ => Finset.card_le_two) (fun c => sep_depEProg Pf Df bga key (pre c) i m (hs c)) hn

/-- `startSite` lift of `drawZeroSite` (`k = 1`, `δ = 0`, Kind 4 / Kind 1). -/
noncomputable def drawZeroStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (j : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom (fun c => drawProg j (pre c)) (fun _ => {0}) 1
    (fun _ => by simp) (fun c => sep_drawProg key j (pre c) (hs c)) hn

theorem depCStartSite_fires_irrel {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (pre : Coins → TProg (α × List SlotRec × Acc)) (i : ℕ)
    (hs₁ hs₂ : ∀ c, TProg.Sep key (pre c))
    (hn₁ hn₂ : ∀ c dg, TProg.NoWrap (depCProg Pf (pre c) i) ⟨dg, 0, key⟩) (G : QB Lq → Dig) (c : Coins) :
    (depCStartSite Lq hLq key domain hdom Pf pre i hs₁ hn₁).fires shdP_U G c ↔
      (depCStartSite Lq hLq key domain hdom Pf pre i hs₂ hn₂).fires shdP_U G c := by
  simp only [depCStartSite, startSite_fires]

theorem depEStartSite_fires_congr {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : Coins → TProg (α × List SlotRec × Acc)) (i m₁ m₂ : ℕ) (hm : m₁ = m₂)
    (hs₁ hs₂ : ∀ c, TProg.Sep key (pre c))
    (hn₁ : ∀ c dg, TProg.NoWrap (depEProg Pf Df bga (pre c) i m₁) ⟨dg, 0, key⟩)
    (hn₂ : ∀ c dg, TProg.NoWrap (depEProg Pf Df bga (pre c) i m₂) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) :
    (depEStartSite Lq hLq key domain hdom Pf Df bga pre i m₁ hs₁ hn₁).fires shdP_U G c ↔
      (depEStartSite Lq hLq key domain hdom Pf Df bga pre i m₂ hs₂ hn₂).fires shdP_U G c := by
  subst hm; simp only [depEStartSite, startSite_fires]

theorem drawZeroStartSite_fires_congr {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (j₁ j₂ : ℕ) (hj : j₁ = j₂) (pre : Coins → TProg α) (hs₁ hs₂ : ∀ c, TProg.Sep key (pre c))
    (hn₁ : ∀ c dg, TProg.NoWrap (drawProg j₁ (pre c)) ⟨dg, 0, key⟩)
    (hn₂ : ∀ c dg, TProg.NoWrap (drawProg j₂ (pre c)) ⟨dg, 0, key⟩) (G : QB Lq → Dig) (c : Coins) :
    (drawZeroStartSite Lq hLq key domain hdom j₁ pre hs₁ hn₁).fires shdP_U G c ↔
      (drawZeroStartSite Lq hLq key domain hdom j₂ pre hs₂ hn₂).fires shdP_U G c := by
  subst hj; simp only [drawZeroStartSite, startSite_fires]

theorem drawZeroStartSite_fires_at {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n j : ℕ) (hj : j < n) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩) (G : QB Lq → Dig) (c : Coins) :
    (drawZeroStartSite Lq hLq key domain hdom j pre hs hn).fires shdP_U G c
      ↔ ((((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1.challengeFp2Vec (liftH G) n).1.getD j
          Fp2.zero).isZero = true := by
  unfold drawZeroStartSite; rw [startSite_fires_iff_tprogSite]
  exact drawZeroSite_fires_at Lq hLq shdP_U shdP_hU n j hj pre
    (fun _ => Tr.newKeyed (liftH G) domain key) hs (fun c' => hn c' _) G c

/-- Slot round-prefix program preserving `(x, recs, acc)` for pairwise `ZKey` collision `startSite`s. -/
def depRoundProg {α : Type} (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s))
    (bga : α → Fp2 × Fp2 × Fp2) (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) :
    TProg (α × List SlotRec × Acc) :=
  bindP (depCProg Pf pre i) (fun yd => .squeeze (fun dgc =>
    bindP (slotEAfter (Pf yd.1.1 i) i (Df yd.1.1 i) m
      (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.1.2.2 (challengeFp2Of dgc)
      ((Pf yd.1.1 i).define i (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.2))
      (fun _ => .done yd.1)))

theorem sep_depRoundProg {α : Type} (key : Option Dig) (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) (hp : TProg.Sep key pre) :
    TProg.Sep key (depRoundProg Pf Df bga pre i m) :=
  sep_bindP key _ _ (sep_depCProg Pf key pre i hp) (fun _ _ =>
    sep_bindP key _ _ (sep_slotEAfter _ _ _ key m _ _ _ _) (fun _ => trivial))

theorem sqLE_depRoundProg {α : Type} (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i r m dmax : ℕ)
    (hp : SqLE m pre) (hd : ∀ x, (Pf x i).draws i ≤ dmax) :
    SqLE (m + dmax + 1 + r) (depRoundProg Pf Df bga pre i r) := by
  unfold depRoundProg
  rw [show m + dmax + 1 + r = (m + dmax) + (r + 1) by omega]
  exact sqLE_bindP _ _ (m + dmax) (r + 1) (sqLE_depCProg Pf pre i m dmax hp hd) (fun yd dgc => by
    let hist := histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1
    have h := sqLE_bindP (slotEAfter (Pf yd.1.1 i) i (Df yd.1.1 i) r hist yd.1.2.2 (challengeFp2Of dgc)
        ((Pf yd.1.1 i).define i hist yd.2))
      (fun _ => TProg.done yd.1) r 0 (sqLE_slotEAfter _ _ _ _ _ _ _ _) (fun _ => trivial)
    simpa only [Nat.add_zero] using h)

/-- Kind-0 (dependent proximity pair, `k = gP`, `δ = 0`) opening `startSite` with bounded `NoWrap`. -/
noncomputable def openDepStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n prox : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ c dg, TProg.NoWrap (drawProg (n + prox + 1) (pre c)) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom (fun c => drawProg (n + prox + 1) (pre c))
    (fun a => lineBad shdP_U (a.2.getD (n + prox) Fp2.zero)) gP (fun _ => lineBad_card shdP_U _)
    (fun c => sep_drawProg key (n + prox + 1) (pre c) (hs c)) hn

/-- Kind-1 (`n + 1` zero draws, `k = 1`, `δ = 0`) opening `startSite` with bounded `NoWrap`. -/
noncomputable def openZeroStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n prox : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ j, j ≤ n + prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (j : Fin (n + 1)) : ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  if h : j.val < n then drawZeroStartSite Lq hLq key domain hdom j.val pre hs (hn j.val (by omega))
  else drawZeroStartSite Lq hLq key domain hdom (n + prox) pre hs (hn (n + prox) le_rfl)

theorem openZeroStartSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n prox : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ j, j ≤ n + prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩) (j : Fin (n + 1)) :
    (openZeroStartSite Lq hLq key domain hdom n prox pre hs hn j).k = 1
      ∧ (openZeroStartSite Lq hLq key domain hdom n prox pre hs hn j).δ = 0 := by
  unfold openZeroStartSite
  by_cases h : j.val < n
  · rw [dite_eq_left h]; exact ⟨rfl, rfl⟩
  · rw [dite_eq_right h]; exact ⟨rfl, rfl⟩

/-- Bounded-`NoWrap` `startSite` cover of `Block.openingChallenges` into Kind 0 (`1` site) ∨ Kind 1 (`n + 1` sites). -/
theorem openingChallenges_startCover_bd {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (counts : List ℕ) (n rows prox : ℕ) (hsum : counts.sum = n) (hprox : ¬ rows ≤ prox + 1)
    (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn0 : ∀ c dg, TProg.NoWrap (drawProg (n + prox + 1) (pre c)) ⟨dg, 0, key⟩)
    (hn1 : ∀ j, j ≤ n + prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (e : String)
    (herr : Block.openingChallenges (liftH G) counts rows prox
      ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error e) :
    (openDepStartSite Lq hLq key domain hdom n prox pre hs hn0).fires shdP_U G c
      ∨ ∃ j : Fin (n + 1), (openZeroStartSite Lq hLq key domain hdom n prox pre hs hn1 j).fires shdP_U G c := by
  let t0 := Tr.newKeyed (liftH G) domain key
  rcases openingChallenges_refuses (liftH G) counts rows prox _ e herr with hle | ⟨j, hj, hjz⟩ | hdet
  · have hf : False := hprox hle; cases hf
  · rw [hsum] at hj
    refine Or.inr ⟨⟨j, by omega⟩, ?_⟩
    unfold openZeroStartSite; rw [dite_eq_left hj]; unfold drawZeroStartSite
    rw [startSite_fires_iff_tprogSite]
    exact (drawZero_fires Lq hLq shdP_U shdP_hU j pre (fun _ => t0) hs (fun c' => hn1 j (by omega) c' _) G c).mpr hjz
  · rw [hsum] at hdet
    by_cases hz : (drawAt (liftH G) ((pre c).final (liftH G) t0).1 (n + prox)).isZero = true
    · refine Or.inr ⟨⟨n, by omega⟩, ?_⟩
      unfold openZeroStartSite; rw [dite_eq_right (Nat.lt_irrefl n)]; unfold drawZeroStartSite
      rw [startSite_fires_iff_tprogSite]
      exact (drawZero_fires Lq hLq shdP_U shdP_hU (n + prox) pre (fun _ => t0) hs
        (fun c' => hn1 (n + prox) le_rfl c' _) G c).mpr hz
    · refine Or.inl ?_
      unfold openDepStartSite; rw [startSite_fires_iff_tprogSite]
      exact (depPairSite_fires Lq hLq shdP_U (n + prox) pre (fun _ => t0) hs (fun c' => hn0 c' _) G c).mpr
        (det_zero_line shdP_U _ _ (drawAt_canon (liftH G) _ _) (ff_of_not hz) hdet)

/-- Pairwise `ZKey`-collision Kind-1 site family (`k ≤ 1`, `δ = 0`) for one commitment opening. -/
structure OpenCollFamily (Lq : ℕ) (Coins : Type) [Fintype Coins] [Nonempty Coins] (nColl : ℕ) where
  site : Fin nColl → ProtocolClassify.Site (QB Lq) Coins shdP_K
  hk : ∀ j, (site j).k ≤ 1
  hδ : ∀ j, (site j).δ = 0

/-- Surviving-run audit, uniform-grouping, and collision-cover contract for one `checkOpeningExec` call. -/
def OpenAuditOk {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (g : OpenGeom) (logN n nColl : ℕ) (F : OpenCollFamily Lq Coins nColl)
    (G : QB Lq → Dig) (c : Coins) (claims : List Exec.Block.ZClaim) : Prop :=
  claims.length = n
    ∧ auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox = .ok ()
    ∧ (∀ cl ∈ claims, ∀ p ∈ cl.parts, partKeyAt p logN = claimKey logN cl)
    ∧ (∀ groups, openingGroupsAt claims logN = .ok groups → groups.length ≠ g.groups →
        ∃ j : Fin nColl, (F.site j).fires shdP_U G c)

/-- Combined Kind-1 (`n + 1 + nColl` sites: opening zeros + pairwise `ZKey` collisions) for one opening. -/
noncomputable def openK1Site {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n prox nColl : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ j, j ≤ n + prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (F : OpenCollFamily Lq Coins nColl) :
    Fin ((n + 1) + nColl) → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  finApp (openZeroStartSite Lq hLq key domain hdom n prox pre hs hn) F.site

theorem openK1Site_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (n prox nColl : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn : ∀ j, j ≤ n + prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (F : OpenCollFamily Lq Coins nColl) (j : Fin ((n + 1) + nColl)) :
    (openK1Site Lq hLq key domain hdom n prox nColl pre hs hn F j).k ≤ 1
      ∧ (openK1Site Lq hLq key domain hdom n prox nColl pre hs hn F j).δ = 0 :=
  finApp_prop _ _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0)
    (fun i => let hk := openZeroStartSite_k_delta Lq hLq key domain hdom n prox pre hs hn i; ⟨hk.1.le, hk.2⟩)
    (fun i => ⟨F.hk i, F.hδ i⟩) j

/-- Bounded-`NoWrap` full `startSite` cover of `checkOpeningExec` into Kind 0 (`1`) ∨ Kind 1 (`n + 1 + nColl`). -/
theorem checkOpeningFull_startCover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (g : OpenGeom) (logN n nColl : ℕ) (pre : Coins → TProg α) (hs : ∀ c, TProg.Sep key (pre c))
    (hn0 : ∀ c dg, TProg.NoWrap (drawProg (n + g.prox + 1) (pre c)) ⟨dg, 0, key⟩)
    (hn1 : ∀ j, j ≤ n + g.prox → ∀ c dg, TProg.NoWrap (drawProg j (pre c)) ⟨dg, 0, key⟩)
    (F : OpenCollFamily Lq Coins nColl) (hprox : ¬ g.rows ≤ g.prox + 1)
    (G : QB Lq → Dig) (c : Coins) (claims : List Exec.Block.ZClaim)
    (hOk : OpenAuditOk g logN n nColl F G c claims) (e : String)
    (herr : checkOpeningExec (liftH G) g logN claims
      ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error e) :
    (openDepStartSite Lq hLq key domain hdom n g.prox pre hs hn0).fires shdP_U G c
      ∨ ∃ j : Fin ((n + 1) + nColl),
          (openK1Site Lq hLq key domain hdom n g.prox nColl pre hs hn1 F j).fires shdP_U G c := by
  obtain ⟨hcl, haud, hunif, hcoll⟩ := hOk
  rcases checkOpeningExec_refuses (liftH G) g logN claims _ e herr with ⟨_, ha'⟩ | ⟨_, hg'⟩ | ⟨groups, hgr, hne | hch⟩
  · rw [haud] at ha'; cases ha'
  · rw [openingGroupsAt_ok_of_uniform claims logN hunif] at hg'; cases hg'
  · obtain ⟨j, hj⟩ := hcoll groups hgr hne
    exact Or.inr ⟨⟨(n + 1) + j.val, by omega⟩, by unfold openK1Site; rw [finApp_right]; exact hj⟩
  · have hsum : (groups.map (·.2)).sum = n := (openingGroupsAt_sum claims logN groups hgr).trans hcl
    rcases openingChallenges_startCover_bd Lq hLq key domain hdom (groups.map (·.2)) n g.rows g.prox
        hsum hprox pre hs hn0 hn1 G c e hch with h0 | ⟨j, hj⟩
    · exact Or.inl h0
    · exact Or.inr ⟨⟨j.val, by omega⟩, by unfold openK1Site; rw [finApp_left]; exact hj⟩

/-- Deterministic `tabVals` success whenever `.eq` fits `rho.length` and `.pub` has length `2 ^ rho.length`. -/
theorem tabVals_ok_of_fit (sel : Fp2) (rho terms : List Fp2) :
    ∀ (ts : List Tab) (k : ℕ),
      (∀ t ∈ ts, match t with | .eq pt st => st + pt.length ≤ rho.length | .pub v => v.length = 2 ^ rho.length | .priv _ => True) →
      ∃ vs, tabVals sel rho terms ts k = .ok vs
  | [], _, _ => ⟨[], rfl⟩
  | t :: ts, k, hfit => by
    have ht := hfit t List.mem_cons_self
    have hrest := tabVals_ok_of_fit sel rho terms ts
    cases t with
    | eq pt st =>
      dsimp only at ht
      have hlen : pt.length = ((rho.drop st).take pt.length).length := by rw [List.length_take, List.length_drop]; omega
      have htv : Exec.Block.tabVal sel rho terms (.eq pt st) k
          = .ok (sel.mul (eqPointBody pt ((rho.drop st).take pt.length)), k) := by
        unfold Exec.Block.tabVal eqPoint; dsimp only; rw [ite_eq_left ht, ite_eq_left hlen]
      obtain ⟨vs, hvs⟩ := hrest k (fun t' ht' => hfit t' (List.mem_cons_of_mem _ ht'))
      exact ⟨_ :: vs, by unfold tabVals; rw [htv]; dsimp only; rw [hvs]⟩
    | pub v =>
      dsimp only at ht
      have htv : Exec.Block.tabVal sel rho terms (.pub v) k = .ok (sel.mul (mleSumExt v (eqTableMsb rho)), k) := by
        unfold Exec.Block.tabVal evalMleExt; dsimp only; rw [ite_eq_left ht]
      obtain ⟨vs, hvs⟩ := hrest k (fun t' ht' => hfit t' (List.mem_cons_of_mem _ ht'))
      exact ⟨_ :: vs, by unfold tabVals; rw [htv]; dsimp only; rw [hvs]⟩
    | priv _ =>
      obtain ⟨vs, hvs⟩ := hrest (k + 1) (fun t' ht' => hfit t' (List.mem_cons_of_mem _ ht'))
      exact ⟨terms.getD k Fp2.zero :: vs, by unfold tabVals Exec.Block.tabVal; dsimp only; rw [hvs]⟩

/-- Deterministic `hostedSum` success whenever every hosted slot index is `< scalars.length`. -/
theorem hostedSum_ok_of (scalars : List Fp2) :
    ∀ (hs : List (ℕ × Fp2)) (scalar : Fp2), (∀ p ∈ hs, p.1 < scalars.length) → ∃ v, hostedSum scalars scalar hs = .ok v
  | [], scalar, _ => ⟨scalar, rfl⟩
  | (hIdx, coef) :: rest, scalar, hall => by
    have hlt := hall (hIdx, coef) List.mem_cons_self
    obtain ⟨v, hv⟩ := hostedSum_ok_of scalars rest (scalar.add (coef.mul (scalars.getD hIdx Fp2.zero)))
      (fun p hp => hall p (List.mem_cons_of_mem _ hp))
    exact ⟨v, by unfold hostedSum; rw [ite_eq_left hlt]; exact hv⟩

/-- Deterministic `slotDefChecks` success from explicit schedule and table-shape invariants. -/
theorem slotDefChecks_ok_of (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef)
    (hcs : acc.cs.length = s) (hpriv : (df.tabs.filter Tab.isPriv).length = slotTerms P s)
    (hhost : decide (P.kind s = SlotKind.host) ≠ df.hosted.isEmpty)
    (hpt : ∀ p, Tab.priv p ∈ df.tabs → p.extRound < (slotShape P s).2.1 ∧ p.coords.length = p.log)
    (hpub : ∀ v, Tab.pub v ∈ df.tabs → v.length = 2 ^ (slotShape P s).1) :
    slotDefChecks P s acc df = .ok () := by
  unfold slotDefChecks; dsimp only
  have h3 : (decide (P.kind s = SlotKind.host) == df.hosted.isEmpty) = false := by
    cases h1 : decide (P.kind s = SlotKind.host) <;> cases h2 : df.hosted.isEmpty <;>
      simp only [h1, h2] at hhost ⊢
    · have hf : False := hhost rfl; cases hf
    · rfl
    · rfl
    · have hf : False := hhost rfl; cases hf
  have hg1 : (decide (s ≠ acc.cs.length) || decide ((df.tabs.filter Tab.isPriv).length ≠ slotTerms P s)
      || (decide (P.kind s = SlotKind.host) == df.hosted.isEmpty)) = false := by
    rw [decide_eq_false (by omega), decide_eq_false (by omega), h3]; rfl
  split_ifs with h1 h2 h3'
  · rw [hg1] at h1; cases h1
  · obtain ⟨tb, htbMem, htb⟩ := List.any_eq_true.mp h2
    cases tb with
    | eq _ _ => cases htb
    | pub _ => cases htb
    | priv p =>
      obtain ⟨he, hl⟩ := hpt p htbMem
      simp only [Bool.or_eq_true, decide_eq_true_eq] at htb
      have hf : False := by rcases htb with ha | hb <;> omega
      cases hf
  · obtain ⟨tb, htbMem, htb⟩ := List.any_eq_true.mp h3'
    cases tb with
    | eq _ _ => cases htb
    | priv _ => cases htb
    | pub v =>
      have hv := hpub v htbMem; simp only [decide_eq_true_eq] at htb
      have hf : False := htb hv; cases hf
  · rfl

def slotFuncInc : SlotKind → ℕ | .priv => 1 | .standalone => 2 | .host => 2

theorem slotProve_ok_struct (H : HIn → Dig) (P : BlockParams) (D : SlotData P) (s : ℕ)
    (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof) (r : SlotRec) (acc' : Acc) (t' : Tr)
    (h : slotProve H P D s hist acc t = .ok (sp, r, acc', t')) :
    ∃ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df
      ∧ r.draws = (t.challengeFp2Vec H (P.draws s)).1
      ∧ r.rho = (slotRho H P D s hist acc t df).take (slotShape P s).1
      ∧ r.es = (slotRho H P D s hist acc t df).drop (slotShape P s).1
      ∧ (∀ e ∈ r.es, e.Canon ∧ e ≠ Fp2.zero ∧ e ≠ Fp2.one)
      ∧ r.es.length = (slotShape P s).2.1
      ∧ acc'.cs.length = acc.cs.length + 1 ∧ acc'.scalars.length = acc.scalars.length + 1
      ∧ (acc'.fs ++ acc'.hostFs).length = (acc.fs ++ acc.hostFs).length + slotFuncInc (P.kind s)
      ∧ acc'.claims = Block.slotClaims P r.rho r.es sp.terms df.tabs 0 acc.claims := by
  unfold slotProve at h
  split at h
  · cases h
  · rename_i df hdf
    split_ifs at h with hc hes
    cases hchk : slotDefChecks P s acc df with
    | error _ => simp [hchk] at h
    | ok _ =>
      cases hhost : hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
      | error _ => simp [hchk, hhost] at h
      | ok claimed =>
        cases htab : tabVals (Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
            ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0 with
        | error _ => simp [hchk, hhost, htab] at h
        | ok vals =>
          simp only [hchk, hhost, htab, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl, rfl, rfl⟩ := h
          have hnoDeg := noDeg_of_any_false _ (ff_of_not hes)
          have hesLen : ((slotRho H P D s hist acc t df).drop (slotShape P s).1).length = (slotShape P s).2.1 := by
            rw [List.length_drop, slotRho_length]; unfold slotN; omega
          have hfsLen : ((Block.slotAcc P s acc df (slotC H P s t) (slotSP H P D s hist acc t df).scalar
              (((scFinalExec (slotSP H P D s hist acc t df).rounds (slotRho H P D s hist acc t df) claimed).sub
                (df.poly vals)).mul (slotC H P s t).inv) (slotRho H P D s hist acc t df)
              (slotSP H P D s hist acc t df).terms).fs
              ++ (Block.slotAcc P s acc df (slotC H P s t) (slotSP H P D s hist acc t df).scalar
              (((scFinalExec (slotSP H P D s hist acc t df).rounds (slotRho H P D s hist acc t df) claimed).sub
                (df.poly vals)).mul (slotC H P s t).inv) (slotRho H P D s hist acc t df)
              (slotSP H P D s hist acc t df).terms).hostFs).length
              = (acc.fs ++ acc.hostFs).length + slotFuncInc (P.kind s) := by
            unfold Block.slotAcc; cases P.kind s <;> simp [slotFuncInc] <;> omega
          exact ⟨df, hdf, rfl, rfl, rfl,
            fun e he => ⟨scChal_canon H _ _ e (List.mem_of_mem_drop he), (hnoDeg e he).1, (hnoDeg e he).2⟩,
            hesLen, by simp [Block.slotAcc], by simp [Block.slotAcc], hfsLen, rfl⟩

def famFuncInc (Pf : ℕ → BlockParams) : ℕ → ℕ → ℕ
  | 0, _ => 0
  | m + 1, s => slotFuncInc ((Pf s).kind s) + famFuncInc Pf m (s + 1)

theorem famProve_inv (H : HIn → Dig) (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s)) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) sps recs' acc' t',
      (∀ r ∈ recs, ∀ w ∈ r.draws, w.Canon) →
      famProve H Pf Df b g a m recs s acc t = .ok (sps, recs', acc', t') →
      acc'.cs.length = acc.cs.length + m ∧ acc'.scalars.length = acc.scalars.length + m
        ∧ (acc'.fs ++ acc'.hostFs).length = (acc.fs ++ acc.hostFs).length + famFuncInc Pf m s
        ∧ (∀ r ∈ recs', ∀ w ∈ r.draws, w.Canon)
  | 0, _, _, _, _, _, _, _, _, hcan, h => by
    simp only [famProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, rfl, -⟩ := h; exact ⟨by omega, by omega, by simp [famFuncInc], hcan⟩
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hcan, h => by
    simp only [famProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h; obtain ⟨-, rfl, rfl, -⟩ := h
        obtain ⟨_, -, hdr, -, -, -, -, hcs, hsc, hfs, -⟩ := slotProve_ok_struct H (Pf s) (Df s) s _ acc t sp r acc₁ t₁ hsp
        have hcan1 : ∀ r' ∈ recs ++ [r], ∀ w ∈ r'.draws, w.Canon := fun r' hr' w hw => by
          rcases List.mem_append.mp hr' with h1 | h2
          · exact hcan r' h1 w hw
          · rw [List.mem_singleton.mp h2, hdr] at hw; exact chalVec_canon H _ _ w hw
        obtain ⟨h1, h2, h3, h4⟩ := famProve_inv H Pf Df b g a m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂ hcan1 hrest
        exact ⟨by omega, by omega, by simp only [famFuncInc]; omega, h4⟩

theorem famSqBound_mono (Pf : ℕ → BlockParams) {a b : ℕ} (hab : a ≤ b) :
    famSqBound Pf a 0 ≤ famSqBound Pf b 0 := by
  have hsplit : ∀ k m s, famSqBound Pf (k + m) s = famSqBound Pf k s + famSqBound Pf m (s + k) := by
    intro k; induction k with
    | zero => intro m s; simp [famSqBound]
    | succ k ih =>
      intro m s; rw [show k + 1 + m = (k + m) + 1 by omega]
      simp only [famSqBound, ih m (s + 1), show s + 1 + k = s + (k + 1) by omega]; omega
  rw [show b = a + (b - a) by omega, hsplit a (b - a) 0]; omega

/-- Bounded-`NoWrap` `startSite`-lifted `fam_refuse_cover_ext`, also returning `acc.cs.length = i`,
`acc.scalars.length = i`, and canonical prior `recs.draws`. -/
theorem fam_startCover_ext {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (hd : Coins → TProg α) (hs : ∀ c, TProg.Sep key (hd c)) (n rBound : ℕ)
    (hnC : ∀ i, i < n → ∀ c dg, TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c) i) i) ⟨dg, 0, key⟩)
    (hnE : ∀ i, i < n → ∀ m, m < rBound → ∀ c dg, TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c) i) i m) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (x : α) (t3 : Tr)
    (hrB : ∀ i, i < n → slotN (Pf x i) i ≤ rBound)
    (hF : (hd c).final (liftH G) (Tr.newKeyed (liftH G) domain key) = (t3, x))
    (h : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 = .error ()) :
    ∃ (i : ℕ) (hi : i < n) (ti : Tr) (recs : List SlotRec) (acc : Acc),
      (famPre Pf Df bga (hd c) i).final (liftH G) (Tr.newKeyed (liftH G) domain key) = (ti, (x, recs, acc))
      ∧ acc.cs.length = i ∧ acc.scalars.length = i ∧ (∀ r ∈ recs, ∀ w ∈ r.draws, w.Canon)
      ∧ ((∃ e, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
            (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .error e)
        ∨ (depCStartSite Lq hLq key domain hdom Pf (fun c => famPre Pf Df bga (hd c) i) i
            (fun c => sep_famPre Pf Df bga key (hd c) (hs c) i) (hnC i hi)).fires shdP_U G c
        ∨ (∃ (j : Fin (slotShape (Pf x i) i).2.1) (hm : (slotShape (Pf x i) i).1 + j.val < rBound),
            (depEStartSite Lq hLq key domain hdom Pf Df bga (fun c => famPre Pf Df bga (hd c) i) i
              ((slotShape (Pf x i) i).1 + j.val)
              (fun c => sep_famPre Pf Df bga key (hd c) (hs c) i)
              (hnE i hi ((slotShape (Pf x i) i).1 + j.val) hm)).fires shdP_U G c)
        ∨ ∃ df, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
              (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .ok df
            ∧ ((∃ e, slotDefChecks (Pf x i) i acc df = .error e)
              ∨ (∃ e, hostedSum acc.scalars
                  (slotSP (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).scalar
                  df.hosted = .error e)
              ∨ ∃ e, tabVals
                  (Block.oneMinusProd ((slotRho (liftH G) (Pf x i) (Df x i) i
                    (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).drop (slotShape (Pf x i) i).1))
                  ((slotRho (liftH G) (Pf x i) (Df x i) i
                    (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).take (slotShape (Pf x i) i).1)
                  (slotSP (liftH G) (Pf x i) (Df x i) i
                    (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).terms df.tabs 0 = .error e)) := by
  let t0 := Tr.newKeyed (liftH G) domain key
  obtain ⟨i, sps, recs, acc, ti, hi, hok, hr⟩ :=
    famProve_refuses_at (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 h
  rw [Nat.zero_add] at hr
  obtain ⟨hcs, hsc, -, hcan⟩ := famProve_inv (liftH G) (Pf x) (Df x) _ _ _ i [] 0 {} t3 sps recs acc ti
    (fun _ hr' => by cases hr') hok
  have hY : (famPre Pf Df bga (hd c) i).final (liftH G) t0 = (ti, (x, recs, acc)) := by
    rw [final_famPre (liftH G) Pf Df bga (hd c) i t0 sps recs acc ti (by rw [hF]; exact hok), hF]
  refine ⟨i, hi, ti, recs, acc, hY, by simpa using hcs, by simpa using hsc, hcan, ?_⟩
  rcases slotProve_refuses_ext shdP_U shdP_hU (liftH G) (Pf x i) (Df x i) i _ acc ti hr with
    hdef | ⟨df, hdf, hc | ⟨j, hj'⟩ | hrest⟩
  · exact Or.inl hdef
  · refine Or.inr (Or.inl ?_)
    unfold depCStartSite; rw [startSite_fires_iff_tprogSite]
    have hsepI : ∀ c', TProg.Sep t0.key (famPre Pf Df bga (hd c') i) := fun c' => sep_famPre Pf Df bga key (hd c') (hs c') i
    have hnwC : ∀ c', TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c') i) i) t0 := fun c' => hnC i hi c' _
    change (depCSite Lq hLq Pf (fun c => famPre Pf Df bga (hd c) i) i (fun _ => t0) hsepI hnwC (K := shdP_K)).fires shdP_U G c
    rw [depCSite_fires Lq hLq Pf shdP_U shdP_hU, hY]
    exact (slot_c_guard_iff shdP_U shdP_hU (liftH G) (Pf x i) i ti).mpr hc
  · have hmN : (slotShape (Pf x i) i).1 + j.val < slotN (Pf x i) i := by unfold slotN; have := j.isLt; omega
    have hm : (slotShape (Pf x i) i).1 + j.val < rBound := lt_of_lt_of_le hmN (hrB i hi)
    refine Or.inr (Or.inr (Or.inl ⟨j, hm, ?_⟩))
    unfold depEStartSite; rw [startSite_fires_iff_tprogSite]
    have hsepI : ∀ c', TProg.Sep t0.key (famPre Pf Df bga (hd c') i) := fun c' => sep_famPre Pf Df bga key (hd c') (hs c') i
    have hnwE : ∀ c', TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c') i) i ((slotShape (Pf x i) i).1 + j.val)) t0 :=
      fun c' => hnE i hi _ hm c' _
    change (depESite Lq hLq Pf Df bga (fun c => famPre Pf Df bga (hd c) i) i
      ((slotShape (Pf x i) i).1 + j.val) (fun _ => t0) hsepI hnwE (K := shdP_K)).fires shdP_U G c
    rw [depESite_fires Lq hLq Pf Df bga shdP_U shdP_hU _ i ((slotShape (Pf x i) i).1 + j.val)
      (fun _ => t0) hsepI hnwE G c ti x recs acc hY hmN df hdf]
    exact (degenerate_guard_iff shdP_U shdP_hU _ (Fp2.canon_getD (scChal_canon (liftH G) _ _) _)).mpr hj'
  · exact Or.inr (Or.inr (Or.inr ⟨df, hdf, hrest⟩))

theorem slotClaims_inp_unchanged (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Exec.Block.Claims4),
      (∀ t ∈ ts, match t with | .priv p => p.cm ≠ .inp | _ => True) →
      (Block.slotClaims P rho es terms ts k cl).inp = cl.inp
  | [], _, _, _ => rfl
  | .eq _ _ :: ts, k, cl, h => slotClaims_inp_unchanged P rho es terms ts k cl (fun t ht => h t (List.mem_cons_of_mem _ ht))
  | .pub _ :: ts, k, cl, h => slotClaims_inp_unchanged P rho es terms ts k cl (fun t ht => h t (List.mem_cons_of_mem _ ht))
  | .priv p :: ts, k, cl, h => by
    have hp : p.cm ≠ .inp := h (.priv p) List.mem_cons_self
    unfold Block.slotClaims
    rw [slotClaims_inp_unchanged P rho es terms ts (k + 1) _ (fun t ht => h t (List.mem_cons_of_mem _ ht))]
    cases hcm : p.cm with
    | inp => have hf : False := hp hcm; cases hf
    | a | h | out => rfl

theorem slotClaims_out_unchanged (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Exec.Block.Claims4),
      (∀ t ∈ ts, match t with | .priv p => p.cm ≠ .out | _ => True) →
      (Block.slotClaims P rho es terms ts k cl).out = cl.out
  | [], _, _, _ => rfl
  | .eq _ _ :: ts, k, cl, h => slotClaims_out_unchanged P rho es terms ts k cl (fun t ht => h t (List.mem_cons_of_mem _ ht))
  | .pub _ :: ts, k, cl, h => slotClaims_out_unchanged P rho es terms ts k cl (fun t ht => h t (List.mem_cons_of_mem _ ht))
  | .priv p :: ts, k, cl, h => by
    have hp : p.cm ≠ .out := h (.priv p) List.mem_cons_self
    unfold Block.slotClaims
    rw [slotClaims_out_unchanged P rho es terms ts (k + 1) _ (fun t ht => h t (List.mem_cons_of_mem _ ht))]
    cases hcm : p.cm with
    | out => have hf : False := hp hcm; cases hf
    | a | h | inp => rfl

theorem famProve_claims_out_nil (H : HIn → Dig) (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s))
    (b g a : Fp2) (N : ℕ)
    (hnoOut : ∀ s, s < N → ∀ hist dr df, dr.length = (Pf s).draws s → (∀ w ∈ dr, w.Canon) →
      (Pf s).define s hist dr = .ok df → ∀ tb ∈ df.tabs, match tb with | .priv p => p.cm ≠ .out | _ => True) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) sps recs' acc' t',
      s + m ≤ N → acc.claims.out = [] →
      famProve H Pf Df b g a m recs s acc t = .ok (sps, recs', acc', t') → acc'.claims.out = []
  | 0, _, _, _, _, _, _, _, _, _, hnil, h => by
    simp only [famProve, Except.ok.injEq, Prod.mk.injEq] at h; obtain ⟨-, -, rfl, -⟩ := h; exact hnil
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hle, hnil, h => by
    simp only [famProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h; obtain ⟨-, -, rfl, -⟩ := h
        obtain ⟨df, hdf, -, -, -, -, -, -, -, -, hcl⟩ := slotProve_ok_struct H (Pf s) (Df s) s _ acc t sp r acc₁ t₁ hsp
        have hnil1 : acc₁.claims.out = [] := by
          rw [hcl, slotClaims_out_unchanged _ _ _ _ df.tabs 0 acc.claims
            (hnoOut s (by omega) _ _ df (chalVec_length H _ _) (chalVec_canon H _ _) hdf), hnil]
        exact famProve_claims_out_nil H Pf Df b g a N hnoOut m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (by omega) hnil1 hrest

private theorem filter_isPriv_cons_eq (pt : List Fp2) (st : ℕ) (ts : List Tab) :
    ((Tab.eq pt st :: ts).filter Tab.isPriv) = ts.filter Tab.isPriv := rfl

private theorem filter_isPriv_cons_pub (v : List Fp2) (ts : List Tab) :
    ((Tab.pub v :: ts).filter Tab.isPriv) = ts.filter Tab.isPriv := rfl

private theorem filter_isPriv_cons_priv (p : Priv) (ts : List Tab) :
    ((Tab.priv p :: ts).filter Tab.isPriv) = Tab.priv p :: ts.filter Tab.isPriv := rfl

private theorem filter_isPriv_map_priv {α : Type} (l : List α) (f : α → Priv) :
    ((l.map (fun x => Tab.priv (f x))).filter Tab.isPriv).length = l.length := by
  induction l with
  | nil => rfl
  | cons _ tl ih => rw [List.map_cons, filter_isPriv_cons_priv, List.length_cons, List.length_cons, ih]

end SharedCombinators

/-! ## 3. Stage IN-C Per-Segment `startSite` Family & `incSeg_refuse_cover` -/

section StageInSegRefusal

/-- The 4 `(slot, extRound)` pairs of Stage IN-C (`ext = 1` on all 4 slots). -/
def incExtList : List (ℕ × ℕ) := [(0, 8), (1, 12), (2, 17), (3, 12)]

/-- The 8 `(slot, drawIdx)` nonzero-checked draws of Stage IN-C (`5` in INC-01, `3` in INC-02). -/
def incNzList : List (ℕ × ℕ) :=
  (List.range' 12 5).map (fun j => (1, j)) ++ (List.range' 17 3).map (fun j => (2, j))

private theorem shdP_incDraws_eq (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (s : ℕ) :
    incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s =
      match s with | 0 => 8 | 1 => 17 | 2 => 20 | _ => 0 := by
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  match s with
  | 0 => unfold incDraws; rw [hep, shdP_clog2_256]; rfl
  | 1 => unfold incDraws; rw [hti]; rfl
  | 2 => unfold incDraws; rw [hvoc]; rfl
  | _ + 3 => rfl

private theorem shdP_incDraws_le_20 (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (s : ℕ) :
    incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s ≤ 20 := by
  rw [shdP_incDraws_eq]
  match s with | 0 | 1 | 2 => decide | _ + 3 => exact Nat.zero_le _

private theorem shdP_incSlotShape_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (bInRow : ℕ) (cx : IncCtx) (s : ℕ) :
    slotShape ((shdVi tag Rp embDigest bInRow).bp cx) s =
      match s with | 0 => (8, 1, 3) | 1 => (12, 1, 4) | 2 => (17, 1, 4) | 3 => (12, 1, 2) | _ => (0, 0, 0) := by
  have hgs' : ((shdVi tag Rp embDigest bInRow).bp cx).geom.slots = [(8, 1, 3), (12, 1, 4), (17, 1, 4), (12, 1, 2)] :=
    (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.2.2
  unfold slotShape; rw [hgs']; match s with | 0 | 1 | 2 | 3 | _ + 4 => rfl

private theorem shdP_inc_famSqBound_le {Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : Coins × List Fp2) (i : ℕ) (hi : i ≤ 4) :
    famSqBound (incPf (shdVi tag Rp embDigest bInRow) x) i 0 ≤ 102 := by
  have hd : ∀ s, ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub x.2)).draws s
      = incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s := fun _ => rfl
  have hs : ∀ s, slotN (incPf (shdVi tag Rp embDigest bInRow) x s) s =
      match s with | 0 => 9 | 1 => 13 | 2 => 18 | 3 => 13 | _ => 0 := by
    intro s; unfold slotN
    change (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) x.2)) s).1
      + (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) x.2)) s).2.1 = _
    rw [shdP_incSlotShape_eq]; match s with | 0 | 1 | 2 | 3 | _ + 4 => rfl
  have h4 : famSqBound (incPf (shdVi tag Rp embDigest bInRow) x) 4 0 = 102 := by
    simp only [famSqBound, hd, hs, shdP_incDraws_eq]
  exact (famSqBound_mono _ hi).trans h4.le

/-- **Stage IN-C `incDefine` refusal**: on canonical draws, `incDefine` refuses ONLY at one of `incNzList`. -/
theorem shdP_incDefine_refuses (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (cx : IncCtx) (s : ℕ) (hs : s < 4) (hist : Hist) (dr : List Fp2)
    (hlen : dr.length = incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s)
    (hcan : ∀ a ∈ dr, a.Canon) (e : String)
    (herr : incDefine (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) cx s hist dr = .error e) :
    ∃ p ∈ incNzList, p.1 = s ∧ (dr.getD p.2 Fp2.zero).isZero = true := by
  let I := shdP_incPub Rp embDigest (embFoldL Rp.inp); let G := shdP_incGeo bInRow
  obtain ⟨hti, hvoc, -, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hti' : I.tiLog = 12 := hti
  have hvoc' : I.vocLog = 17 := hvoc
  have h123 : s = 0 ∨ s = 1 ∨ s = 2 ∨ s = 3 := by omega
  rcases h123 with rfl | rfl | rfl | rfl
  · change incDefIO I G dr = .error e at herr; rw [incDefIO_ok I G dr] at herr; cases herr
  · change incDefQZC I G cx dr = .error e at herr; rw [shdP_incDraws_eq] at hlen
    let y : Fin 17 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 17 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 17 I.tiLog 5, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and, hti'] at hj
      exact hno ⟨(1, j.val), List.mem_append_left _ (List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 12 5 j.val hj.1 (by omega), rfl⟩),
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := incDefQZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change incDefTZC I G cx dr = .error e at herr; rw [shdP_incDraws_eq] at hlen
    let y : Fin 20 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 20 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 20 I.vocLog 3, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and, hvoc'] at hj
      exact hno ⟨(2, j.val), List.mem_append_right _ (List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 17 3 j.val hj.1 (by omega), rfl⟩),
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := incDefTZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change incDefZS I G = .error e at herr; rw [incDefZS_ok I G] at herr; cases herr

/-- **Stage IN-C deterministic slot checks**: for `s < 4`, whenever `incDefine = .ok df`, all 3 checks succeed. -/
theorem shdP_inc_slotChecks_ok (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (bInRow : ℕ) (ch : List Fp2) (hchLen : ch.length = 15) (s : ℕ) (hs : s < 4)
    (hist : Hist) (acc : Acc) (hcs : acc.cs.length = s)
    (dr : List Fp2) (hlen : dr.length = incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s)
    (hcan : ∀ a ∈ dr, a.Canon) (df : SlotDef)
    (hdef : incDefine (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow)
      (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) s hist dr = .ok df)
    (sel sc : Fp2) (rho terms : List Fp2)
    (hrho : rho.length = (slotShape ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch)) s).1) :
    let P := atLog ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch))
      (incElog (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14 s)
    slotDefChecks P s acc df = .ok () ∧ (∃ v, hostedSum acc.scalars sc df.hosted = .ok v)
      ∧ (∃ vs, tabVals sel rho terms df.tabs 0 = .ok vs) := by
  intro P
  let I := shdP_incPub Rp embDigest (embFoldL Rp.inp); let G := shdP_incGeo bInRow; let cx := incCtx I ch
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hti' : I.tiLog = 12 := hti
  have hvoc' : I.vocLog = 17 := hvoc
  have hep' : I.inEpWords = 256 := hep
  have hepc : clog2 I.inEpWords = 8 := by rw [hep', shdP_clog2_256]
  have htbits : I.tBits = 7 := shdP_clog2_128
  have hbin : I.bInLog = 19 := by show Nat.log2 (128 * 4096) = 19; exact (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  have hshP : slotShape P s = slotShape ((shdVi tag Rp embDigest bInRow).bp cx) s := rfl
  have hterms : ∀ k, k < 4 → slotTerms P k = ([2, 3, 2, 1] : List ℕ).getD k 0 := fun k hk => by interval_cases k <;> rfl
  have hkind : ∀ k, k < 4 → P.kind k = .standalone := fun k hk => by interval_cases k <;> rfl
  have h123 : s = 0 ∨ s = 1 ∨ s = 2 ∨ s = 3 := by omega
  rcases h123 with rfl | rfl | rfl | rfl
  · change incDefIO I G dr = .ok df at hdef; rw [incDefIO_ok I G dr] at hdef; cases hdef
    have hsh0 : slotShape ((shdVi tag Rp embDigest bInRow).bp cx) 0 = (8, 1, 3) :=
      shdP_incSlotShape_eq tag Rp embDigest bInRow cx 0
    rw [hsh0] at hrho; change rho.length = 8 at hrho
    refine ⟨slotDefChecks_ok_of P 0 acc _ hcs (by rw [hterms 0 (by omega)]; rfl)
      (by rw [hkind 0 (by omega)]; dsimp only; decide) (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h | h
      · cases h
      · cases h
      · cases h; rw [hshP, hsh0]
        exact ⟨Nat.zero_lt_one, by simp [fixedC, rhoC, incLay, incA_TOK, hti', hepc]⟩
      · cases h; rw [hshP, hsh0]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h | h | h
      · cases h
      · cases h; rw [hshP, hsh0]; simp [supp, hep']
      · cases h
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl | rfl
      · dsimp only; rw [hepc, hrho, Nat.zero_add]; exact List.length_take_le 8 dr
      · simp [supp, hep', hrho]
      · trivial
      · trivial
  · change incDefQZC I G cx dr = .ok df at hdef; rw [shdP_incDraws_eq] at hlen
    let y : Fin 17 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 17 hlen
    have hne : ∀ j ∈ Z_range 17 I.tiLog 5, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := incDefQZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := incDefQZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
    have hsh1 : slotShape ((shdVi tag Rp embDigest bInRow).bp cx) 1 = (12, 1, 4) :=
      shdP_incSlotShape_eq tag Rp embDigest bInRow cx 1
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh1] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 1 acc _ hcs (by rw [hterms 1 (by omega)]; rfl)
      (by rw [hkind 1 (by omega)]; dsimp only; decide) (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h | h | h | h | h | h | h
      · cases h
      · cases h
      · cases h
      · cases h
      · cases h
      · cases h
      · cases h; rw [hshP, hsh1]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
      · cases h; rw [hshP, hsh1]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
      · cases h; rw [hshP, hsh1]
        have hremb : cx.rEmb = ch.drop 3 := rfl
        exact ⟨Nat.zero_lt_one, by simp [rhoC, fixedC, hremb, hchLen, hti', htbits, hbin]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h | h | h | h | h | h | h | h
      · cases h
      · cases h; rw [hshP, hsh1]; simp [supp, hti']
      · cases h; rw [hshP, hsh1]; simp [supp, hti']
      · cases h; rw [hshP, hsh1]; simp [hti']
      · cases h; rw [hshP, hsh1]; simp [hti']
      · cases h; rw [hshP, hsh1]; simp [hti']
      · cases h
      · cases h
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · dsimp only; rw [hti', hrho, Nat.zero_add]; exact List.length_take_le 12 dr
      · simp [supp, hti', hrho]
      · simp [supp, hti', hrho]
      · simp [hti', hrho]
      · simp [hti', hrho]
      · simp [hti', hrho]
      · trivial
      · trivial
      · trivial
  · change incDefTZC I G cx dr = .ok df at hdef; rw [shdP_incDraws_eq] at hlen
    let y : Fin 20 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 20 hlen
    have hne : ∀ j ∈ Z_range 20 I.vocLog 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := incDefTZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := incDefTZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
    have hsh2 : slotShape ((shdVi tag Rp embDigest bInRow).bp cx) 2 = (17, 1, 4) :=
      shdP_incSlotShape_eq tag Rp embDigest bInRow cx 2
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh2] at hrho; change rho.length = 17 at hrho
    have htauLen : cx.tauTab.length = 2 ^ 17 := by
      have htau : ∀ (I' : IncPub) ef b g, (tauTable I' ef b g).length = 2 ^ I'.vocLog := by
        intro I' ef b g; unfold tauTable; dsimp only; rw [List.length_map, List.length_range]
      exact (htau I _ _ _).trans (by rw [hvoc'])
    refine ⟨slotDefChecks_ok_of P 2 acc _ hcs (by rw [hterms 2 (by omega)]; rfl)
      (by rw [hkind 2 (by omega)]; dsimp only [List.isEmpty]; decide) (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h | h | h
      · cases h
      · cases h
      · cases h
      · cases h; rw [hshP, hsh2]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
      · cases h; rw [hshP, hsh2]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h | h | h | h
      · cases h
      · cases h; rw [hshP, hsh2]; simp [supp, hvoc']
      · cases h; rw [hshP, hsh2]; exact htauLen
      · cases h
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl | rfl | rfl
      · dsimp only; rw [hvoc', hrho, Nat.zero_add]; exact List.length_take_le 17 dr
      · simp [supp, hvoc', hrho]
      · rw [hrho]; exact htauLen
      · trivial
      · trivial
  · change incDefZS I G = .ok df at hdef; rw [incDefZS_ok I G] at hdef; cases hdef
    have hsh3 : slotShape ((shdVi tag Rp embDigest bInRow).bp cx) 3 = (12, 1, 2) :=
      shdP_incSlotShape_eq tag Rp embDigest bInRow cx 3
    rw [hsh3] at hrho; change rho.length = 12 at hrho
    have hhu : (incLay I G.bLogN).hLog.getD incH_U 0 = 12 := rfl
    refine ⟨slotDefChecks_ok_of P 3 acc _ hcs (by rw [hterms 3 (by omega)]; rfl)
      (by rw [hkind 3 (by omega)]; dsimp only; decide) (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h
      · cases h
      · cases h; rw [hshP, hsh3]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h
      · rw [Tab.pub.inj h, hshP, hsh3, List.length_replicate, hhu]
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · dsimp only; rw [List.length_replicate, hhu, hrho]
      · trivial

/-- **Stage IN-C post-slot facts**: `nFunctionals = 8` and `checkTokenEp` reduces to `openingChallenges [1] 6 3`. -/
theorem shdP_inc_postSlots (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (ch : List Fp2)
    (D : SlotData ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (t3 : Tr) (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (h : stSlotsProve H ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub ch))
      (incElog (shdVi tag Rp embDigest bInRow).pub 14) D Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} t3
      = .ok (sps, recs, acc, t4)) :
    (acc.fs ++ acc.hostFs).length = (shdVi tag Rp embDigest bInRow).lay.nFunctionals
      ∧ ∀ t7, checkTokenEp H acc.claims.inp (shdVi tag Rp embDigest bInRow).geo.epDataRows
          (shdVi tag Rp embDigest bInRow).pub.epN t7 = Block.openingChallenges H [1] 6 3 t7 := by
  let V := shdVi tag Rp embDigest bInRow; let I := shdP_incPub Rp embDigest (embFoldL Rp.inp)
  let G := shdP_incGeo bInRow; let cx := incCtx I ch; let P := V.bp cx; let elog := incElog I 14
  have hnF : V.lay.nFunctionals = 8 := (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.2.1
  have hfam : famProve H (fun s => atLog P (elog s)) (fun s => sdAt D (elog s)) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} t3
      = .ok (sps, recs, acc, t4) :=
    (stSlotsProve_eq_fam H _ _ D Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} t3).symm.trans h
  obtain ⟨-, -, hfs, -⟩ := famProve_inv H (fun s => atLog P (elog s)) (fun s => sdAt D (elog s))
    Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} t3 sps recs acc t4 (fun _ hr => by cases hr) hfam
  have hinc8 : famFuncInc (fun s => atLog P (elog s)) 4 0 = 8 := rfl
  refine ⟨by rw [hfs, hinc8, hnF]; rfl, fun t7 => ?_⟩
  have hstep : ∀ {m recs s acc0 t0 sps' recs' acc' t'},
      stSlotsProve H P elog D Fp2.zero Fp2.zero Fp2.zero (m + 1) recs s acc0 t0 = .ok (sps', recs', acc', t') →
      ∃ sp r acc1 t1 sps1,
        slotProve H (atLog P (elog s)) (sdAt D (elog s)) s (histOf Fp2.zero Fp2.zero Fp2.zero recs) acc0 t0 = .ok (sp, r, acc1, t1)
        ∧ stSlotsProve H P elog D Fp2.zero Fp2.zero Fp2.zero m (recs ++ [r]) (s + 1) acc1 t1 = .ok (sps1, recs', acc', t') := by
    intro m recs s acc0 t0 sps' recs' acc' t' hst
    simp only [stSlotsProve] at hst
    split at hst
    · cases hst
    · rename_i sp r acc1 t1 hsp
      split at hst
      · cases hst
      · rename_i sps1 recs1 acc2 t2 hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at hst
        obtain ⟨-, rfl, rfl, rfl⟩ := hst
        exact ⟨sp, r, acc1, t1, sps1, hsp, hrest⟩
  obtain ⟨sp0, rec0, acc1, t1, _, h0, hst1⟩ := hstep h
  obtain ⟨sp1, rec1, acc2, t2, _, h1, hst2⟩ := hstep hst1
  obtain ⟨sp2, rec2, acc3, t3', _, h2, hst3⟩ := hstep hst2
  obtain ⟨sp3, rec3, acc4, t4', _, h3, hst4⟩ := hstep hst3
  simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at hst4
  obtain ⟨-, -, rfl, -⟩ := hst4
  obtain ⟨df0, hdf0, -, -, -, he0, he0L, -, -, -, hcl1⟩ := slotProve_ok_struct H _ _ 0 _ {} t3 sp0 rec0 acc1 t1 h0
  obtain ⟨df1, hdf1, -, -, -, -, -, -, -, -, hcl2⟩ := slotProve_ok_struct H _ _ 1 _ acc1 t1 sp1 rec1 acc2 t2 h1
  obtain ⟨df2, hdf2, -, -, -, -, -, -, -, -, hcl3⟩ := slotProve_ok_struct H _ _ 2 _ acc2 t2 sp2 rec2 acc3 t3' h2
  obtain ⟨df3, hdf3, -, -, -, -, -, -, -, -, hcl4⟩ := slotProve_ok_struct H _ _ 3 _ acc3 t3' sp3 rec3 acc4 t4' h3
  change incDefIO I G _ = .ok df0 at hdf0; rw [incDefIO_ok I G _] at hdf0; cases hdf0
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hepc : clog2 I.inEpWords = 8 := by rw [hep, shdP_clog2_256]
  have hsh0 : (slotShape (atLog P (elog 0)) 0).2.1 = 1 := by show (slotShape (V.bp cx) 0).2.1 = 1; rw [shdP_incSlotShape_eq]; rfl
  rw [hsh0] at he0L
  cases hes0 : rec0.es with
  | nil => rw [hes0] at he0L; cases he0L
  | cons e0 rest0 =>
    cases rest0 with
    | cons _ _ => rw [hes0] at he0L; cases he0L
    | nil =>
      have he0F := he0 e0 (by rw [hes0]; exact List.mem_cons_self)
      have hinp1 : acc2.claims.inp = acc1.claims.inp := by
        rw [hcl2]; refine slotClaims_inp_unchanged _ _ _ _ df1.tabs 0 acc1.claims ?_
        change incDefQZC I G cx _ = .ok df1 at hdf1
        let dr1 := (t1.challengeFp2Vec H ((atLog P (elog 1)).draws 1)).1
        let y1 : Fin 17 → shdP_K := fun j => (dr1.getD j.val Fp2.zero).toK shdP_U
        have hw1 : stgWords shdP_U shdP_hbij y1 = dr1 :=
          stgWords_toK shdP_U shdP_hbij shdP_hU dr1 (chalVec_canon H _ _) 17 (by rw [chalVec_length]; exact shdP_incDraws_eq Rp embDigest 1)
        have hne1 : ∀ j ∈ Z_range 17 I.tiLog 5, y1 j ≠ 0 := fun j hj hy0 => by
          obtain ⟨_, hm⟩ := incDefQZC_err shdP_U shdP_hbij shdP_hU I G cx y1 ⟨j, hj, hy0⟩; rw [hw1] at hm; rw [hm] at hdf1; cases hdf1
        have hok1 := incDefQZC_ok shdP_U shdP_hbij shdP_hU I G cx (by have : I.tiLog = 12 := hti; omega) y1 hne1
        rw [hw1] at hok1; rw [hok1] at hdf1; cases hdf1
        intro tb htb; simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> (dsimp only <;> decide)
      have hinp2 : acc3.claims.inp = acc2.claims.inp := by
        rw [hcl3]; refine slotClaims_inp_unchanged _ _ _ _ df2.tabs 0 acc2.claims ?_
        change incDefTZC I G cx _ = .ok df2 at hdf2
        let dr2 := (t2.challengeFp2Vec H ((atLog P (elog 2)).draws 2)).1
        let y2 : Fin 20 → shdP_K := fun j => (dr2.getD j.val Fp2.zero).toK shdP_U
        have hw2 : stgWords shdP_U shdP_hbij y2 = dr2 :=
          stgWords_toK shdP_U shdP_hbij shdP_hU dr2 (chalVec_canon H _ _) 20 (by rw [chalVec_length]; exact shdP_incDraws_eq Rp embDigest 2)
        have hne2 : ∀ j ∈ Z_range 20 I.vocLog 3, y2 j ≠ 0 := fun j hj hy0 => by
          obtain ⟨_, hm⟩ := incDefTZC_err shdP_U shdP_hbij shdP_hU I G cx y2 ⟨j, hj, hy0⟩; rw [hw2] at hm; rw [hm] at hdf2; cases hdf2
        have hok2 := incDefTZC_ok shdP_U shdP_hbij shdP_hU I G cx (by have : I.vocLog = 17 := hvoc; omega) y2 hne2
        rw [hw2] at hok2; rw [hok2] at hdf2; cases hdf2
        intro tb htb; simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl | rfl | rfl | rfl <;> (dsimp only <;> decide)
      have hinp3 : acc4.claims.inp = acc3.claims.inp := by
        rw [hcl4]; refine slotClaims_inp_unchanged _ _ _ _ df3.tabs 0 acc3.claims ?_
        change incDefZS I G = .ok df3 at hdf3; rw [incDefZS_ok I G] at hdf3; cases hdf3
        intro tb htb; simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl <;> (dsimp only <;> decide)
      rw [hinp3, hinp2, hinp1, hcl1, hes0]
      simp only [Block.slotClaims, Exec.Block.Claims4.push, List.nil_append]
      exact checkTokenEp_header_ok_of_ext1 H (atLog P (elog 0))
        ⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, rhoC 0 (clog2 I.inEpWords), G.epDataRows, 0⟩
        _ e0 _ G.epDataRows t7 rfl rfl rfl (by change (2 ^ clog2 I.inEpWords + 2 ^ 8 - 1) / 2 ^ 8 = 1; rw [hepc]; rfl)
        rfl he0F.1 he0F.2.1 he0F.2.2

/-- Stage IN-C `TProg` chain: `incSlotEndProg` → `incMaskProg` → `incOpenAProg` → `incOpenHProg`. -/
noncomputable def incSlotEndProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) (i : ℕ) (c : Coins) :
    TProg ((Coins × List Fp2) × List SlotRec × Acc) :=
  let V := shdVi tag Rp embDigest bInRow
  famPre (incPf V) (incDf V Dc) incBga
    (incHeadProg V c (pre c) (rootOfP tag 16 (TB c)) (rootOfP tag 14 (TA c))
      (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c))) (fun ch => rootOfP tag 14 (TH c ch))) i

noncomputable def incMaskProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) (c : Coins) :=
  bMaskProg 4 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
    (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc 4 c)

noncomputable def incOpenAProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) (c : Coins) :=
  bOpenProg ⟨12, 4, 256, 256⟩ 3 (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
    (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c)

noncomputable def incOpenHProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) (c : Coins) :=
  let V := shdVi tag Rp embDigest bInRow
  bOpenProg ⟨12, 4, 256, 256⟩ 4 (fun y => TH y.1.1.1.1 y.1.1.1.2)
    (fun y => y.1.1.2.2.claims.h ++ [V.lay.logupSumClaim])
    (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c)

private theorem incSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 4) (c : Coins) :
    TProg.Sep key (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c)
      ∧ SqLE (mPre + 117) (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c) := by
  let V := shdVi tag Rp embDigest bInRow
  have hhdSq : SqLE (mPre + 15) (incHeadProg V c (pre c) (rootOfP tag 16 (TB c)) (rootOfP tag 14 (TA c))
      (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c))) (fun ch => rootOfP tag 14 (TH c ch))) := by
    have h := sqLE_incHeadProg V c (pre c) (rootOfP tag 16 (TB c)) (rootOfP tag 14 (TA c))
      (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c))) (fun ch => rootOfP tag 14 (TH c ch)) mPre (hsq c)
    have hhd : incHeadDraws V.pub = 15 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
    rwa [hhd] at h
  exact ⟨sep_famPre _ _ _ key _ (sep_incHeadProg V key c (pre c) _ _ _ _ (hs c)) i,
    sqLE_mono _ ((mPre + 15) + 102) (mPre + 117)
      (sqLE_famPre (incPf V) (incDf V Dc) incBga _ i (mPre + 15) 102 hhdSq
        (fun x => shdP_inc_famSqBound_le tag Rp embDigest bInRow x i hi)) (by omega)⟩

private theorem incMaskProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 192) (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c) :=
  let hS := incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq 4 le_rfl c
  ⟨sep_bMaskProg key 4 _ _ _ hS.1,
   sqLE_mono _ _ (mPre + 192) (sqLE_bMaskProg 4 (mPre + 117) _ _ _ hS.2) (by norm_num [mQ])⟩

private theorem incOpenAProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 300) (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c) :=
  let hM := incMaskProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq c
  ⟨sep_bOpenProg key _ 3 _ _ _ hM.1,
   sqLE_mono _ _ (mPre + 300)
     (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 3 41 (mPre + 192) _ _ _ hM.2 (fun y => hrA y.1.1.1)) (by dsimp only; omega)⟩

private theorem incOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 76)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 444) (incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c) :=
  let hA := incOpenAProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH hrA Dc hs hsq c
  ⟨sep_bOpenProg key _ 4 _ _ _ hA.1,
   sqLE_mono _ _ (mPre + 444)
     (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 4 76 (mPre + 300) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 y.1.1.1.2)) (by dsimp only; omega)⟩

/-- **Concrete Stage IN-C per-segment `startSite` family** (`SiteIdx incSegCount`, `3/20/4/4/8/13/0`). -/
noncomputable def incSegSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 76)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (collA : OpenCollFamily Lq Coins 3) (collH : OpenCollFamily Lq Coins 6) :
    SiteIdx incSegCount → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  let V := shdVi tag Rp embDigest bInRow
  let preS := incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc
  let preM := incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc
  let preA := incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc
  let preH := incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc
  let hS := fun i (hi : i ≤ 4) c => incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq i hi c
  let hM := fun c => incMaskProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq c
  let hA := fun c => incOpenAProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH hrA Dc hs hsq c
  let hH := fun c => incOpenHProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH hrA hrH Dc hs hsq c
  fun ⟨kind, idx⟩ =>
    match kind, idx with
    | ⟨0, _⟩, ⟨0, _⟩ => openDepStartSite Lq hLq key domain hdom 3 39 preM (fun c => (hM c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 43 (mPre + 192) (preM c) (hM c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨1, _⟩ => openDepStartSite Lq hLq key domain hdom 4 74 preA (fun c => (hA c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 79 (mPre + 300) (preA c) (hA c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨2, _⟩ => openDepStartSite Lq hLq key domain hdom 1 3 preH (fun c => (hH c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 5 (mPre + 444) (preH c) (hH c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨n + 3, h⟩ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
    | ⟨1, _⟩, idx =>
      finApp3
        (openK1Site Lq hLq key domain hdom 3 39 3 preM (fun c => (hM c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 192) (preM c) (hM c).2) (by omega) dg) collA)
        (openK1Site Lq hLq key domain hdom 4 74 6 preA (fun c => (hA c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 300) (preA c) (hA c).2) (by omega) dg) collH)
        (openZeroStartSite Lq hLq key domain hdom 1 3 preH (fun c => (hH c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 444) (preH c) (hH c).2) (by omega) dg)) idx
    | ⟨2, _⟩, idx =>
      depCStartSite Lq hLq key domain hdom (incPf V) (preS idx.val) idx.val
        (fun c => (hS idx.val (Nat.le_of_lt idx.isLt) c).1)
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depCProg (incPf V) (preS idx.val c) idx.val (mPre + 117) 20 (hS idx.val (Nat.le_of_lt idx.isLt) c).2
            (fun _ => shdP_incDraws_le_20 Rp embDigest _))
          (by omega) dg)
    | ⟨3, _⟩, idx =>
      listPairSite incExtList (fun s r =>
        if h4 : s < 4 then
          depEStartSite Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga (preS s) s (min r 20)
            (fun c => (hS s (Nat.le_of_lt h4) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_depEProg (incPf V) (incDf V Dc) incBga (preS s c) s (min r 20) (mPre + 117) 20 (hS s (Nat.le_of_lt h4) c).2
                (fun _ => shdP_incDraws_le_20 Rp embDigest _))
              (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨4, _⟩, idx =>
      listPairSite incNzList (fun s j =>
        if h4 : s < 4 then
          drawZeroStartSite Lq hLq key domain hdom (min j 20) (preS s)
            (fun c => (hS s (Nat.le_of_lt h4) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_drawProg (min j 20) (mPre + 117) (preS s c) (hS s (Nat.le_of_lt h4) c).2) (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨5, _⟩, idx =>
      shdP_incAlphaStartSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre
        (fun c => rootOfP tag 16 (TB c)) (fun c => rootOfP tag 14 (TA c))
        (fun c => rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c))) hs
        (fun j c dg => noWrap_start_of_sqLE
          (sqLE_incHeadDrawProg V (pre c) _ _ _ (2 + j.val) mPre (hsq c)) (by have := j.isLt; omega) dg) idx
    | ⟨6, _⟩, idx => by have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
    | ⟨k + 7, h⟩, _ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k) h; cases hf

theorem incSegSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hV : Rp.inp.V = 131072) (embDigest : Dig) (bInRow : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 76)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (collA : OpenCollFamily Lq Coins 3) (collH : OpenCollFamily Lq Coins 6)
    (i : SiteIdx incSegCount) :
    (incSegSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre mPre hs hsq hmPre TB TA M TH hrA hrH Dc collA collH i).k
      ≤ kPer gP (2 ^ 17) (2 ^ 20) i.1
    ∧ (incSegSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre mPre hs hsq hmPre TB TA M TH hrA hrH Dc collA collH i).δ = 0 := by
  rcases i with ⟨kind, idx⟩
  match kind, idx with
  | ⟨0, _⟩, ⟨0, _⟩ | ⟨0, _⟩, ⟨1, _⟩ | ⟨0, _⟩, ⟨2, _⟩ => exact ⟨le_rfl, rfl⟩
  | ⟨0, _⟩, ⟨n + 3, h⟩ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
  | ⟨1, _⟩, idx =>
    exact finApp3_prop _ _ _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 3 39 3 _ _ _ collA j)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 4 74 6 _ _ _ collH j)
      (fun j => let hk := openZeroStartSite_k_delta Lq hLq key domain hdom 1 3 _ _ _ j; ⟨hk.1.le, hk.2⟩) idx
  | ⟨2, _⟩, _ => exact ⟨le_rfl, rfl⟩
  | ⟨3, _⟩, idx =>
    exact listPairSite_prop incExtList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 2 ∧ s.δ = 0) (fun s _ => by
      by_cases h4 : s < 4
      · rw [dite_eq_left h4]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h4]; exact ⟨by change 0 ≤ 2; omega, rfl⟩) idx
  | ⟨4, _⟩, idx =>
    exact listPairSite_prop incNzList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0) (fun s _ => by
      by_cases h4 : s < 4
      · rw [dite_eq_left h4]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h4]; exact ⟨by change 0 ≤ 1; omega, rfl⟩) idx
  | ⟨5, _⟩, _ => exact ⟨le_rfl, rfl⟩
  | ⟨6, _⟩, idx => have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
  | ⟨k + 7, h⟩, _ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k) h; cases hf

/-- **Stage IN-C per-segment refusal cover**: whenever `incProve` refuses on `shdVi`, one of the
`incSegCount` (`3/20/4/4/8/13/0`) `startSite`s in `incSegSite` fires. -/
theorem incSeg_refuse_cover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hIn : Rp.inp.Valid) (hV : Rp.inp.V = 131072)
    (embDigest : Dig) (bInRow : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 76)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (collA : OpenCollFamily Lq Coins 3) (collH : OpenCollFamily Lq Coins 6)
    (G : QB Lq → Dig) (c : Coins) (D : IncData (shdVi tag Rp embDigest bInRow))
    (hB : D.bRoot = rootOf (liftH G) tag 16 (TB c))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (hMO : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij (M c) 4)
    (hAO : D.aOpen = bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TA c))
    (hHO : D.hOpen = bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14
      (TH c (incCh (liftH G) (shdVi tag Rp embDigest bInRow) D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1))
    (hAudA : ∀ sps recs acc t4,
      let V := shdVi tag Rp embDigest bInRow
      let ch := (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      stSlotsProve (liftH G) (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) (D.slot ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
        (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN)
        = .ok (sps, recs, acc, t4) →
      OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ 12 3 3 collA G c acc.claims.a)
    (hAudH : ∀ sps recs acc t4,
      let V := shdVi tag Rp embDigest bInRow
      let ch := (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      stSlotsProve (liftH G) (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) (D.slot ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
        (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN)
        = .ok (sps, recs, acc, t4) →
      OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ 12 4 6 collH G c (acc.claims.h ++ [V.lay.logupSumClaim]))
    (href : incProve (liftH G) (shdVi tag Rp embDigest bInRow) D
      ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error ()) :
    ∃ i : SiteIdx incSegCount,
      (incSegSite Lq hLq key domain hdom tag Rp hV embDigest bInRow pre mPre hs hsq hmPre
        TB TA M TH hrA hrH Dc collA collH i).fires shdP_U G c := by
  let V := shdVi tag Rp embDigest bInRow
  let t0 := Tr.newKeyed (liftH G) domain key
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (incCh (liftH G) V D tStart).1
  let hd := fun c' => incHeadProg V c' (pre c') (rootOfP tag 16 (TB c')) (rootOfP tag 14 (TA c'))
    (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))
  have hF : (hd c).final (liftH G) t0
      = (absorbRoot (liftH G) (incCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN, (c, ch)) := by
    rw [final_incHeadProg]; dsimp only [tStart, ch]; unfold incCh; rw [hB, hA, hM, hH]
  have hS := fun i (hi : i ≤ 4) c' => incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq i hi c'
  unfold incProve at href
  split_ifs at href with hbad
  · obtain ⟨j, hj⟩ := shdP_incAlphaBad_cover Lq hLq key domain hdom tag Rp hIn hV embDigest bInRow pre
      (fun c' => rootOfP tag 16 (TB c')) (fun c' => rootOfP tag 14 (TA c'))
      (fun c' => rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c'))) hs
      (fun j c' dg => noWrap_start_of_sqLE (sqLE_incHeadDrawProg V (pre c') _ _ _ (2 + j.val) mPre (hsq c'))
        (by have := j.isLt; omega) dg) G c D hB hA hM hbad
    exact ⟨⟨⟨5, by norm_num⟩, j⟩, hj⟩
  · split at href
    · rename_i e he; cases e
      rw [stSlotsProve_eq_fam, hD] at he
      have hrB : ∀ i, i < 4 → slotN (incPf V (c, ch) i) i ≤ 20 := fun i hi => by
        have hsh := shdP_incSlotShape_eq tag Rp embDigest bInRow (incCtx V.pub ch) i
        change (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx V.pub ch)) i).1
          + (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx V.pub ch)) i).2.1 ≤ 20
        rw [hsh]; interval_cases i <;> decide
      have hchLen : ch.length = 15 := by
        unfold ch incCh
        rw [chalVec_length]; exact (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
      obtain ⟨i, hi, ti, recs, acc, hY, hcs, _, _, hcase⟩ :=
        fam_startCover_ext Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga hd
          (fun c' => sep_incHeadProg V key c' (pre c') _ _ _ _ (hs c')) 4 20
          (fun i hi c' dg => noWrap_start_of_sqLE
            (sqLE_depCProg (incPf V) (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c') i (mPre + 117) 20
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => shdP_incDraws_le_20 Rp embDigest _))
            (by omega) dg)
          (fun i hi m hm c' dg => noWrap_start_of_sqLE
            (sqLE_depEProg (incPf V) (incDf V Dc) incBga (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c') i m (mPre + 117) 20
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => shdP_incDraws_le_20 Rp embDigest _))
            (by omega) dg) G c (c, ch) _ hrB hF he
      rcases hcase with ⟨e', hdefErr⟩ | hC | ⟨j, hm, hE⟩ | ⟨df, hdf, hdet⟩
      · obtain ⟨p, hpMem, hp1, hp0⟩ := shdP_incDefine_refuses Rp embDigest bInRow (incCtx V.pub ch) i hi
          (histOf (incBga (c, ch)).1 (incBga (c, ch)).2.1 (incBga (c, ch)).2.2 recs)
          (Tr.challengeFp2Vec (liftH G) ti ((incPf V (c, ch) i).draws i)).1
          (chalVec_length (liftH G) _ _) (chalVec_canon (liftH G) _ _) e' hdefErr
        have hp2Lt : p.2 < incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) i := by
          rw [shdP_incDraws_eq, ← hp1]
          exact (show ∀ q ∈ incNzList, q.2 < (match q.1 with | 0 => 8 | 1 => 17 | 2 => 20 | _ => 0) by decide) p hpMem
        have hp2Le : p.2 ≤ 20 := (show ∀ q ∈ incNzList, q.2 ≤ 20 by decide) p hpMem
        have hfire : (drawZeroStartSite Lq hLq key domain hdom (min p.2 20)
            (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i)
            (fun c' => (hS i (Nat.le_of_lt hi) c').1)
            (fun c' dg => noWrap_start_of_sqLE
              (sqLE_drawProg (min p.2 20) (mPre + 117) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)).fires shdP_U G c := by
          rw [drawZeroStartSite_fires_congr Lq hLq key domain hdom (min p.2 20) p.2 (Nat.min_eq_left hp2Le) _ _
            (fun c' => (hS i (Nat.le_of_lt hi) c').1) _
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg p.2 (mPre + 117) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)]
          rw [drawZeroStartSite_fires_at Lq hLq key domain hdom (incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) i) p.2 hp2Lt]
          change ((((incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c).final (liftH G) t0).1.challengeFp2Vec (liftH G) _).1.getD p.2 Fp2.zero).isZero = true
          rw [show (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c).final (liftH G) t0 = (ti, ((c, ch), recs, acc)) from hY]
          exact hp0
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem incNzList
          (fun s j => if h4 : s < 4 then drawZeroStartSite Lq hLq key domain hdom (min j 20)
            (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc s) (fun c' => (hS s (Nat.le_of_lt h4) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg (min j 20) (mPre + 117) _ (hS s (Nat.le_of_lt h4) c').2) (by omega) dg)
            else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) p.1 p.2 hpMem (by rw [hp1, dite_eq_left hi]; exact hfire)
        exact ⟨⟨⟨4, by norm_num⟩, idx⟩, hidx⟩
      · refine ⟨⟨⟨2, by norm_num⟩, ⟨i, hi⟩⟩, ?_⟩
        exact (depCStartSite_fires_irrel Lq hLq key domain hdom (incPf V)
          (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i) i
          _ (fun c' => (hS i (Nat.le_of_lt hi) c').1) _ _ G c).mp hC
      · have hshape := shdP_incSlotShape_eq tag Rp embDigest bInRow (incCtx V.pub ch) i
        have hj0 : j.val = 0 := by
          have hlt := j.isLt
          change j.val < (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx V.pub ch)) i).2.1 at hlt
          rw [hshape] at hlt
          have hlt1 : j.val < 1 := by interval_cases i <;> exact hlt
          omega
        let r := (slotShape (incPf V (c, ch) i) i).1 + j.val
        have hmem : (i, r) ∈ incExtList := by
          change (i, (slotShape ((shdVi tag Rp embDigest bInRow).bp (incCtx V.pub ch)) i).1 + j.val) ∈ incExtList
          rw [hshape, hj0]; interval_cases i <;> decide
        have hrLe : r ≤ 20 := Nat.le_of_lt hm
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem incExtList
          (fun s r' => if h4 : s < 4 then depEStartSite Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga
            (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc s) s (min r' 20)
            (fun c' => (hS s (Nat.le_of_lt h4) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_depEProg (incPf V) (incDf V Dc) incBga _ s (min r' 20) (mPre + 117) 20
              (hS s (Nat.le_of_lt h4) c').2 (fun _ => shdP_incDraws_le_20 Rp embDigest _))
              (by omega) dg) else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) i r hmem (by
            rw [dite_eq_left hi]
            exact (depEStartSite_fires_congr Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga _ i r (min r 20)
              (Nat.min_eq_left hrLe).symm _ _ _ _ G c).mp hE)
        exact ⟨⟨⟨3, by norm_num⟩, idx⟩, hidx⟩
      · let histI := histOf Fp2.zero Fp2.zero Fp2.zero recs
        let drI := (ti.challengeFp2Vec (liftH G) ((incPf V (c, ch) i).draws i)).1
        let rhoAll := slotRho (liftH G) (incPf V (c, ch) i) (incDf V Dc (c, ch) i) i histI acc ti df
        let selI := Block.oneMinusProd (rhoAll.drop (slotShape (incPf V (c, ch) i) i).1)
        let scI := (slotSP (liftH G) (incPf V (c, ch) i) (incDf V Dc (c, ch) i) i histI acc ti df).scalar
        let rhoI := rhoAll.take (slotShape (incPf V (c, ch) i) i).1
        let termsI := (slotSP (liftH G) (incPf V (c, ch) i) (incDf V Dc (c, ch) i) i histI acc ti df).terms
        have hrhoLen : rhoI.length = (slotShape (V.bp (incCtx V.pub ch)) i).1 := by
          dsimp only [rhoI, rhoAll]; rw [List.length_take, slotRho_length]; unfold slotN; exact Nat.min_eq_left (by omega)
        obtain ⟨hchk, ⟨_, hv⟩, ⟨_, hvs⟩⟩ := shdP_inc_slotChecks_ok tag Rp embDigest bInRow ch hchLen i hi histI acc hcs drI
          (chalVec_length (liftH G) _ _) (chalVec_canon (liftH G) _ _) df hdf selI scI rhoI termsI hrhoLen
        rcases hdet with ⟨_, he1⟩ | ⟨_, he2⟩ | ⟨_, he3⟩
        · have hf : (Except.ok () : Except String Unit) = .error _ := hchk.symm.trans he1; cases hf
        · have hf : (Except.ok _ : Except String Fp2) = .error _ := hv.symm.trans he2; cases hf
        · have hf : (Except.ok _ : Except String (List Fp2)) = .error _ := hvs.symm.trans he3; cases hf
    · rename_i sps recs acc t4 hsl
      have hPost := shdP_inc_postSlots (liftH G) tag Rp embDigest bInRow ch (D.slot ch) _ sps recs acc t4 hsl
      rw [ite_eq_right (not_not.mpr hPost.1)] at href
      have hEnd : (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc 4 c).final (liftH G) t0 = (t4, ((c, ch), recs, acc)) := by
        rw [incSlotEndProg, final_famPre (liftH G) (incPf V) (incDf V Dc) incBga (hd c) 4 t0 sps recs acc t4
          (by rw [hF, ← stSlotsProve_eq_fam, ← hD]; exact hsl), hF]
      have hMask : ((incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
            = (bMask (liftH G) tag shdP_U shdP_hbij (M c) 4 (acc.fs ++ acc.hostFs) t4).2
          ∧ ((incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).2.1 = ((c, ch), recs, acc) := by
        have h := final_bMaskProg (liftH G) tag 4 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
          (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc 4 c) t0
        rw [hEnd] at h; exact h
      have ht5 : ((incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
          = (D.mOpen (acc.fs ++ acc.hostFs) t4).2 := by rw [hMO]; exact hMask.1
      have haRows : V.lay.aRows = 41 := (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).1
      have hhRows : V.lay.hRows = 76 := (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.1
      have haProx : V.lay.aProx = 39 := by unfold Lay.aRows at haRows; omega
      have hhProx : V.lay.hProx = 74 := by unfold Lay.hRows at hhRows; omega
      have hM := fun c' => incMaskProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq c'
      have hA' := fun c' => incOpenAProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH hrA Dc hs hsq c'
      have hH' := fun c' => incOpenHProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH hrA hrH Dc hs hsq c'
      have hAudA' := hAudA sps recs acc t4 hsl
      have hAudH' := hAudH sps recs acc t4 hsl
      cases hcA : V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e =>
        change checkOpeningExec (liftH G) ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ 12 acc.claims.a _ = .error e at hcA
        rw [← ht5, haRows, haProx] at hcA
        rw [haRows, haProx] at hAudA'
        rcases checkOpeningFull_startCover Lq hLq key domain hdom ⟨41, V.lay.aSiteRows, none, 39, incAGroups⟩ 12 3 3
            (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc) (fun c' => (hM c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 43 (mPre + 192) _ (hM c').2) (by omega) dg)
            (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 192) _ (hM c').2) (by dsimp only at hj; omega) dg)
            collA (by dsimp only; omega) G c acc.claims.a hAudA' e hcA with h0 | ⟨j, hj⟩
        · exact ⟨⟨⟨0, by decide⟩, ⟨0, by decide⟩⟩, h0⟩
        · refine ⟨⟨⟨1, by decide⟩, ⟨j.val, by change j.val < 20; omega⟩⟩, ?_⟩
          change ProtocolClassify.Site.fires shdP_U
            (finApp3 (m₁ := (3 + 1) + 3) (m₂ := (4 + 1) + 6) (m₃ := 1 + 1) _ _ _ ⟨j.val, by omega⟩) G c
          rw [finApp3_1]; exact hj
      | ok _ =>
        have hOpenA : ((incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
              = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TA c) acc.claims.a
                  (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2
            ∧ ((incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).2.1.1 = ((c, ch), recs, acc) := by
          have h := final_bOpenProg (liftH G) tag ⟨12, 4, 256, 256⟩ 14 3 (by norm_num [PcsPrm.nn]) (by norm_num)
            (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
            (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c) t0 (by rw [hMask.2]; exact hAudA'.1.le)
          rw [hMask.2, ht5] at h
          exact ⟨h.1, (congrArg Prod.fst h.2).trans hMask.2⟩
        have ht6 : ((incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
            = (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 := by
          rw [hAO]; exact hOpenA.1
        cases hcH : V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | error e =>
          change checkOpeningExec (liftH G) ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ 12 _ _ = .error e at hcH
          rw [← ht6, hhRows, hhProx] at hcH
          rw [hhRows, hhProx] at hAudH'
          rcases checkOpeningFull_startCover Lq hLq key domain hdom ⟨76, V.lay.hSiteRows, some V.lay.hURows, 74, incHGroups⟩ 12 4 6
              (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc) (fun c' => (hA' c').1)
              (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 79 (mPre + 300) _ (hA' c').2) (by omega) dg)
              (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 300) _ (hA' c').2) (by dsimp only at hj; omega) dg)
              collH (by dsimp only; omega) G c _ hAudH' e hcH with h0 | ⟨j, hj⟩
          · exact ⟨⟨⟨0, by decide⟩, ⟨1, by decide⟩⟩, h0⟩
          · refine ⟨⟨⟨1, by decide⟩, ⟨7 + j.val, by change 7 + j.val < 20; omega⟩⟩, ?_⟩
            change ProtocolClassify.Site.fires shdP_U
              (finApp3 (m₁ := (3 + 1) + 3) (m₂ := (4 + 1) + 6) (m₃ := 1 + 1) _ _ _ ⟨((3 + 1) + 3) + j.val, by omega⟩) G c
            rw [finApp3_2]; exact hj
        | ok _ =>
          have hOpenH : ((incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
              = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TH c ch) (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 := by
            have h := final_bOpenProg (liftH G) tag ⟨12, 4, 256, 256⟩ 14 4 (by norm_num [PcsPrm.nn]) (by norm_num)
              (fun y => TH y.1.1.1.1 y.1.1.1.2) (fun y => y.1.1.2.2.claims.h ++ [V.lay.logupSumClaim])
              (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c) t0 (by rw [hOpenA.2]; exact hAudH'.1.le)
            have h1 := h.1; rw [hOpenA.2, ht6] at h1; exact h1
          have ht7 : ((incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c).final (liftH G) t0).1
              = (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 := by
            rw [hHO]; exact hOpenH
          cases hcE : checkTokenEp (liftH G) acc.claims.inp V.geo.epDataRows V.pub.epN
              (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
          | ok _ => dsimp only [V] at hcA hcH hcE; simp only [hcA, hcH, hcE] at href; cases href
          | error e =>
            rw [hPost.2, ← ht7] at hcE
            rcases openingChallenges_startCover_bd Lq hLq key domain hdom [1] 1 6 3 rfl (by omega)
                (incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc) (fun c' => (hH' c').1)
                (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 5 (mPre + 444) _ (hH' c').2) (by omega) dg)
                (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 444) _ (hH' c').2) (by omega) dg)
                G c e hcE with h0 | ⟨j, hj⟩
            · exact ⟨⟨⟨0, by decide⟩, ⟨2, by decide⟩⟩, h0⟩
            · refine ⟨⟨⟨1, by decide⟩, ⟨18 + j.val, by change 18 + j.val < 20; omega⟩⟩, ?_⟩
              change ProtocolClassify.Site.fires shdP_U
                (finApp3 (m₁ := (3 + 1) + 3) (m₂ := (4 + 1) + 6) (m₃ := 1 + 1) _ _ _ ⟨((3 + 1) + 3) + ((4 + 1) + 6) + j.val, by omega⟩) G c
              rw [finApp3_3]; exact hj

end StageInSegRefusal

/-! ## 4. Block `k` (`k < 26`) Per-Segment `startSite` Family & `blkSeg_refuse_cover` -/

section BlockSegRefusal

/-- Layer `k < 26` of Shieldstral's registered export. -/
abbrev shdP_blkLy (k : ℕ) (hk : k < 26) : ShieldLayer :=
  shieldExport[k]'(by rw [shieldExport_l17.1]; exact hk)

/-- Public block parameters of layer `k < 26` cast to `shieldShape (shdP_blkLy k hk)`. -/
noncomputable abbrev shdP_blkPb (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    BlockPublic (shieldShape (shdP_blkLy k hk)) :=
  cast (congrArg (fun cal => BlockPublic (cal.over shieldS0)) (shdP_blk_cal_eq hR k hk))
    (Rp.blks[k]'(by rw [shdP_blks_length hR]; exact hk)).pub

/-- Block `k`'s framing program (`pb-run-stage`, `pb-run-block`, `absorb_root("B", B_{k+1}, 38, 14)`). -/
def blkFrameProg {α : Type} {rB : (HIn → Dig) → Dig} (k : ℕ) (dig : Dig)
    (pre : TProg α) (RB : RootProg rB) : TProg α :=
  bindP pre (fun a => .absorb labRunStage (le64 (UInt64.ofNat (k + 1)))
    (.absorb labRunBlock dig.toList (absorbRootP RB labB 38 14 (fun _ => .done a))))

theorem sep_blkFrameProg {α : Type} {rB : (HIn → Dig) → Dig} (key : Option Dig) (k : ℕ) (dig : Dig)
    (pre : TProg α) (RB : RootProg rB) (hp : TProg.Sep key pre) :
    TProg.Sep key (blkFrameProg k dig pre RB) :=
  sep_bindP key pre _ hp (fun _ => sep_bindP key RB.p _ (RB.sep key) (fun _ => trivial))

theorem sqLE_blkFrameProg {α : Type} {rB : (HIn → Dig) → Dig} (k : ℕ) (dig : Dig) (m : ℕ)
    (pre : TProg α) (RB : RootProg rB) (hp : SqLE m pre) :
    SqLE m (blkFrameProg k dig pre RB) :=
  sqLE_mono _ (m + 0) m (sqLE_bindP pre _ m 0 hp (fun _ =>
    sqLE_absorbRootP RB labB 38 14 0 _ (fun _ => trivial))) (by omega)

theorem final_blkFrameProg {α : Type} {rB : (HIn → Dig) → Dig} (H : HIn → Dig) (k : ℕ) (dig : Dig)
    (pre : TProg α) (RB : RootProg rB) (t : Tr) :
    ((blkFrameProg k dig pre RB).final H t).1 =
      absorbRoot H (((pre.final H t).1.absorbU64 H labRunStage (UInt64.ofNat (k + 1))).absorb H labRunBlock dig.toList)
        labB (rB H) 38 14 := by
  unfold blkFrameProg; rw [final_bindP, final_absorb, final_absorb, final_absorbRootP]; rfl

/-- Block `k`'s LogUp `α` prefix program: frame + `A` root + `M` root + 2 draws (`[β, γ]`). -/
def blkAlphaProg {α : Type} {rA rM : (HIn → Dig) → Dig} (P : BlockParams)
    (preFrame : TProg α) (RA : RootProg rA) (RM : RootProg rM) : TProg (List Fp2) :=
  bindP preFrame (fun _ => absorbRootP RA labA P.aRows P.logCols (fun _ =>
    bindP RM.p (fun m => .absorb labM m.toList (drawsP 2 (fun ch => .done ch)))))

theorem sep_blkAlphaProg {α : Type} {rA rM : (HIn → Dig) → Dig} (key : Option Dig) (P : BlockParams)
    (preFrame : TProg α) (RA : RootProg rA) (RM : RootProg rM) (hp : TProg.Sep key preFrame) :
    TProg.Sep key (blkAlphaProg P preFrame RA RM) :=
  sep_bindP key preFrame _ hp (fun _ => sep_bindP key RA.p _ (RA.sep key) (fun _ =>
    sep_bindP key RM.p _ (RM.sep key) (fun _ => sep_drawsP key 2 _ (fun _ => trivial))))

theorem sqLE_blkAlphaProg {α : Type} {rA rM : (HIn → Dig) → Dig} (P : BlockParams) (m : ℕ)
    (preFrame : TProg α) (RA : RootProg rA) (RM : RootProg rM) (hp : SqLE m preFrame) :
    SqLE (m + 2) (blkAlphaProg P preFrame RA RM) :=
  sqLE_bindP preFrame _ m 2 hp (fun _ => sqLE_absorbRootP RA labA P.aRows P.logCols 2 _ (fun _ => by
    have h := sqLE_bindP RM.p (fun m => .absorb labM m.toList (drawsP 2 (fun ch => .done ch))) 0 2 RM.sq (fun _ => by
      have h1 := sqLE_drawsP 2 0 (fun ch => TProg.done ch) (fun _ => trivial); rwa [Nat.add_zero] at h1)
    rwa [Nat.zero_add] at h))

theorem final_blkAlphaProg {α : Type} {rA rM : (HIn → Dig) → Dig} (H : HIn → Dig) (P : BlockParams)
    (preFrame : TProg α) (RA : RootProg rA) (RM : RootProg rM) (t : Tr) :
    (blkAlphaProg P preFrame RA RM).final H t =
      let T2 := (absorbRoot H (preFrame.final H t).1 labA (rA H) P.aRows P.logCols).absorb H labM (rM H).toList
      ((T2.challengeFp2Vec H 2).2, (T2.challengeFp2Vec H 2).1) := by
  unfold blkAlphaProg; rw [final_bindP, final_absorbRootP, final_bindP, RM.final_eq, final_absorb, final_drawsP]; rfl

/-- Bad `α` set for one R13 block: all `49,152` folded table values `fold β γ (TR13 j)`. -/
noncomputable def blkAlphaBadSet (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (ch : List Fp2) :
    Finset shdP_K :=
  Finset.univ.image (fun j : TbIx =>
    fold ((ch.getD 0 Fp2.zero).toK shdP_U) ((ch.getD 1 Fp2.zero).toK shdP_U)
      (TR13 (K := shdP_K) Pb.exp Pb.act (shieldShape Ly).nG j))

theorem blkAlphaBadSet_card (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (ch : List Fp2) :
    (blkAlphaBadSet Ly Pb ch).card ≤ 49152 := by
  unfold blkAlphaBadSet
  exact Finset.card_image_le.trans (le_of_eq (by rw [Finset.card_univ, card_tbIx]))

/-- Block `k` LogUp zero-denominator event (`α` hits a folded table entry `TR13 j`). -/
def blkAlphaBadP (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly)) (b g a : Fp2) : Prop :=
  ∃ j : TbIx, a.toK shdP_U = fold (b.toK shdP_U) (g.toK shdP_U) (TR13 (K := shdP_K) Pb.exp Pb.act (shieldShape Ly).nG j)

/-- Concrete Block `k` LogUp `α` `startSite` (`k = 49,152 ≤ 2^17`, `δ = 0`, Kind 5). -/
noncomputable def shdP_blkAlphaStartSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (P : BlockParams) (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    {rA rM : Coins → (HIn → Dig) → Dig} (preFrame : Coins → TProg α)
    (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (preFrame c))
    (hn : ∀ c dg, TProg.NoWrap (blkAlphaProg P (preFrame c) (RA c) (RM c)) ⟨dg, 0, key⟩) :
    ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  startSite Lq hLq key domain hdom (fun c => blkAlphaProg P (preFrame c) (RA c) (RM c))
    (blkAlphaBadSet Ly Pb) 49152 (blkAlphaBadSet_card Ly Pb)
    (fun c => sep_blkAlphaProg key P (preFrame c) (RA c) (RM c) (hs c)) hn

private theorem challengeFp2Vec_2_eq (H : HIn → Dig) (t : Tr) :
    (t.challengeFp2Vec H 2).1.getD 0 Fp2.zero = (t.challengeFp2 H).1
    ∧ (t.challengeFp2Vec H 2).1.getD 1 Fp2.zero = ((t.challengeFp2 H).2.challengeFp2 H).1
    ∧ challengeFp2Of (H ⟨(t.challengeFp2Vec H 2).2.key,
        squeezeMsg (t.challengeFp2Vec H 2).2.state (t.challengeFp2Vec H 2).2.counter⟩)
      = (((t.challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1 :=
  ⟨rfl, rfl, rfl⟩

theorem shdP_blkAlphaBad_cover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (P : BlockParams) (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    {rA rM : Coins → (HIn → Dig) → Dig} (preFrame : Coins → TProg α)
    (RA : ∀ c, RootProg (rA c)) (RM : ∀ c, RootProg (rM c))
    (hs : ∀ c, TProg.Sep key (preFrame c))
    (hn : ∀ c dg, TProg.NoWrap (blkAlphaProg P (preFrame c) (RA c) (RM c)) ⟨dg, 0, key⟩)
    (G : QB Lq → Dig) (c : Coins) (D : CoreData P)
    (hA : D.aRoot = rA c (liftH G)) (hM : D.maskRoot = rM c (liftH G))
    (hbad : blkAlphaBadP Ly Pb
      (coreB (liftH G) P D ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      (coreG (liftH G) P D ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      (coreA (liftH G) P D ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1) :
    (shdP_blkAlphaStartSite Lq hLq key domain hdom P Ly Pb preFrame RA RM hs hn).fires shdP_U G c := by
  obtain ⟨j, hj⟩ := hbad
  unfold shdP_blkAlphaStartSite
  rw [startSite_fires]
  dsimp only
  rw [final_blkAlphaProg]
  dsimp only
  have hT2 : (absorbRoot (liftH G) ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      labA (rA c (liftH G)) P.aRows P.logCols).absorb (liftH G) labM (rM c (liftH G)).toList
      = coreT2 (liftH G) P D ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 := by
    unfold coreT2; rw [hA, hM]
  rw [hT2]
  have hc := challengeFp2Vec_2_eq (liftH G)
    (coreT2 (liftH G) P D ((preFrame c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1)
  unfold blkAlphaBadSet
  refine Finset.mem_image.mpr ⟨j, Finset.mem_univ j, ?_⟩
  rw [hc.1, hc.2.1, hc.2.2]
  unfold coreB coreG coreA at hj
  exact hj.symm

/-- The 25 `(slot, extRound)` pairs of a Shieldstral R13 block (`ext = 2` on slots 8, 9; `ext = 1` elsewhere). -/
def blkExtList : List (ℕ × ℕ) :=
  [(0, 19), (1, 19), (2, 7), (3, 14), (4, 19), (5, 12), (6, 12), (7, 12),
   (8, 10), (8, 11), (9, 10), (9, 11), (10, 12), (11, 12), (12, 12), (13, 14),
   (14, 19), (15, 19), (16, 17), (17, 19), (18, 21), (19, 14), (20, 14), (21, 19), (22, 19)]

/-- Per-slot nonzero draw indices of a Shieldstral R13 block (`16` draws total across 8 slots). -/
def blkNzOf : ℕ → List ℕ
  | 2 => [13, 14] | 3 => [15] | 14 => [31, 32, 33] | 15 => [11, 12]
  | 16 => [11, 12] | 17 => [33, 34] | 18 => [12, 13, 14] | 19 => [18] | _ => []

/-- The 16 `(slot, drawIdx)` nonzero-checked draws of a Shieldstral R13 block. -/
def blkNzList : List (ℕ × ℕ) :=
  [(2, 13), (2, 14), (3, 15), (14, 31), (14, 32), (14, 33), (15, 11), (15, 12),
   (16, 11), (16, 12), (17, 33), (17, 34), (18, 12), (18, 13), (18, 14), (19, 18)]

private def blkMaxPub (s : ℕ) : ℕ :=
  [1, 1, 0, 1, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 3, 2, 2, 1, 2, 5, 1, 0, 0].getD s 0

private def shdLy0 : ShieldLayer := ⟨8, 7, 16, 8, 19, 848, 1716, 3⟩

private def privCountS : List TabS → ℕ | [] => 0 | .priv _ :: ts => 1 + privCountS ts | _ :: ts => privCountS ts
private def pubCountS : List TabS → ℕ | [] => 0 | .pub _ :: ts => 1 + pubCountS ts | _ :: ts => pubCountS ts

private def tabShapeOKb (main ext : ℕ) : TabS → Bool
  | .priv p => decide (p.extRound < ext) && decide (p.coords.length = p.log)
  | .eq pt st => decide (st + pt.length ≤ main)
  | .pub _ => true

private def tabsShapeOKb (main ext terms maxPub : ℕ) (ts : List TabS) : Bool :=
  decide (privCountS ts = terms) && decide (pubCountS ts ≤ maxPub) && ts.all (tabShapeOKb main ext)

private theorem bytes_length (g : List ℕ) (b : Option ℕ) :
    (Exec.Block.DefR13.bytes g b).length = g.length + (if b.isSome then 1 else 0) := by
  cases b <;> simp [Exec.Block.DefR13.bytes]

private theorem nHelp_cfgShieldR13 (Ly : ShieldLayer) (d : Exec.Slot.W16R2.Dom) :
    Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 Ly) d
      = Exec.Block.DefR13.nHelp (Exec.Block.DefR13.cfgShieldR13 shdLy0) d := by
  cases d <;> simp [Exec.Block.DefR13.nHelp, Exec.Block.DefR13.lookups, Exec.Block.DefR13.ids,
    Exec.Block.DefR13.lsOf, Exec.Block.DefR13.cfgShieldR13, Exec.Block.DefR13.precShieldR13, bytes_length]

private theorem rawSlot_tabs_congr (c₁ c₂ : Exec.Block.DefW16.W16Cfg)
    (hsh : c₁.sh = c₂.sh) (hlc : c₁.logCols = c₂.logCols)
    (hh24 : c₁.p.h24 = c₂.p.h24) (hwrho : c₁.p.wrho = c₂.p.wrho)
    (hnh : ∀ d, Exec.Block.DefR13.nHelp c₁ d = Exec.Block.DefR13.nHelp c₂ d) (s : ℕ) :
    (Exec.Block.DefR13.rawSlot c₁ s).tabs = (Exec.Block.DefR13.rawSlot c₂ s).tabs := by
  have hids : Exec.Block.DefR13.ids c₁ = Exec.Block.DefR13.ids c₂ := by
    unfold Exec.Block.DefR13.ids Exec.Block.DefR13.lsOf; rw [hh24, hwrho]
  have hdomS : ∀ d, Exec.Block.DefR13.domStart c₁ d = Exec.Block.DefR13.domStart c₂ d := fun d => by
    unfold Exec.Block.DefR13.domStart; simp only [hids]
  have hdomE : ∀ d, Exec.Block.DefR13.domEnd c₁ d = Exec.Block.DefR13.domEnd c₂ d := fun d => by
    unfold Exec.Block.DefR13.domEnd; simp only [hids]
  have hdomPl : ∀ d, Exec.Block.DefR13.domPl c₁ d = Exec.Block.DefR13.domPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.domPl; rw [hdomS, hdomE]
  have hplaneDom : ∀ q, Exec.Block.DefR13.planeDom c₁ q = Exec.Block.DefR13.planeDom c₂ q := fun q => by
    unfold Exec.Block.DefR13.planeDom; simp only [hdomE]
  have hrowsOf : ∀ d, Exec.Block.DefW16.rowsOf c₁ d = Exec.Block.DefW16.rowsOf c₂ d := fun d => by
    unfold Exec.Block.DefW16.rowsOf; rw [hsh, hlc]
  have hdomRow : ∀ d, Exec.Block.DefR13.domRow c₁ d = Exec.Block.DefR13.domRow c₂ d := fun d => by
    unfold Exec.Block.DefR13.domRow; simp only [hdomS, hdomE, hrowsOf]
  have haOff : ∀ q, Exec.Block.DefR13.aOff c₁ q = Exec.Block.DefR13.aOff c₂ q := fun q => by
    unfold Exec.Block.DefR13.aOff; rw [hdomRow, hplaneDom, hdomS, hrowsOf, hlc]
  have hlogOf : ∀ q, Exec.Block.DefR13.logOf c₁ q = Exec.Block.DefR13.logOf c₂ q := fun q => by
    unfold Exec.Block.DefR13.logOf; rw [hsh, hplaneDom]
  have haPlane : Exec.Block.DefR13.aPlane c₁ = Exec.Block.DefR13.aPlane c₂ := funext fun q => by
    unfold Exec.Block.DefR13.aPlane; rw [haOff, hlogOf]
  have hsupp : ∀ d, Exec.Block.DefW16.supp c₁ d = Exec.Block.DefW16.supp c₂ d := fun d => by
    unfold Exec.Block.DefW16.supp; rw [hsh]
  have hzeroPl : ∀ d, Exec.Block.DefR13.zeroPl c₁ d = Exec.Block.DefR13.zeroPl c₂ d := fun d => by
    unfold Exec.Block.DefR13.zeroPl; rw [hsh, hdomPl, hids]
  have hseg : ∀ s' j, Exec.Block.DefR13.seg c₁ s' j = Exec.Block.DefR13.seg c₂ s' j := fun s' j => by
    unfold Exec.Block.DefR13.seg; rw [hsh]
  have hclaimPt : ∀ s', Exec.Block.DefR13.claimPt c₁ s' = Exec.Block.DefR13.claimPt c₂ s' := fun s' => by
    unfold Exec.Block.DefR13.claimPt; simp only [hseg]
  have hfh : ∀ k, Exec.Block.DefR13.fh c₁ k = Exec.Block.DefR13.fh c₂ k := fun k => by
    unfold Exec.Block.DefR13.fh Exec.Block.DefR13.hIdsN; simp only [hnh]
  have hhDoms : Exec.Block.DefR13.hDoms c₁ = Exec.Block.DefR13.hDoms c₂ := by
    unfold Exec.Block.DefR13.hDoms; simp only [hnh]
  have hhOff : ∀ hp, Exec.Block.DefR13.hOff c₁ hp = Exec.Block.DefR13.hOff c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hOff; simp only [hhDoms, hrowsOf, hlc]
  have hhTab : ∀ hp, Exec.Block.DefR13.hTab c₁ hp = Exec.Block.DefR13.hTab c₂ hp := fun hp => by
    unfold Exec.Block.DefR13.hTab; simp only [hhOff, hhDoms, hsh]
  have hepTab : ∀ cm, Exec.Block.DefW16.epTab c₁ cm = Exec.Block.DefW16.epTab c₂ cm := fun cm => by
    unfold Exec.Block.DefW16.epTab; rw [hsh]
  unfold Exec.Block.DefR13.rawSlot
  dsimp only
  simp only [apply_ite SlotS.tabs, hids, hsh, hsupp, hseg, haPlane, haOff, hlogOf, hclaimPt,
    hzeroPl, hhTab, hfh, hdomPl, hnh, hepTab]

private theorem rawSlot_tabs_indep (Ly : ShieldLayer) (s : ℕ) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs
      = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s).tabs :=
  rawSlot_tabs_congr (Exec.Block.DefR13.cfgShieldR13 Ly) (Exec.Block.DefR13.cfgShieldR13 shdLy0)
    rfl rfl rfl rfl (nHelp_cfgShieldR13 Ly) s

private theorem rawSlot_tabs_shape :
    ∀ s : Fin 23,
      tabsShapeOKb (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).1
        (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).2.1
        (Exec.Block.R13.shieldTerms.getD s.val 0) (blkMaxPub s.val)
        (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s.val).tabs = true := by
  decide +kernel

private theorem numTabs_privCount (aB hB ioIn ioOut : ℕ) :
    ∀ (ts : List TabS) (ak hk pk : ℕ), privCountS (Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts) = privCountS ts
  | [], _, _, _ => rfl
  | .priv _ :: ts, ak, hk, pk => by simp [Exec.Block.DefW16.numTabs, privCountS, numTabs_privCount]
  | .pub _ :: ts, ak, hk, pk => by simp [Exec.Block.DefW16.numTabs, privCountS, numTabs_privCount]
  | .eq _ _ :: ts, ak, hk, pk => by simp [Exec.Block.DefW16.numTabs, privCountS, numTabs_privCount]

private theorem numTabs_shape_ok (aB hB ioIn ioOut main ext : ℕ) :
    ∀ (ts : List TabS) (ak hk pk : ℕ), ts.all (tabShapeOKb main ext) = true →
      (Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts).all (tabShapeOKb main ext) = true
  | [], _, _, _, _ => rfl
  | .priv _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨h.1, numTabs_shape_ok aB hB ioIn ioOut main ext ts _ _ pk h.2⟩
  | .pub _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨rfl, numTabs_shape_ok aB hB ioIn ioOut main ext ts ak hk (pk + 1) h.2⟩
  | .eq _ _ :: ts, ak, hk, pk, h => by
    simp only [List.all_cons, Bool.and_eq_true] at h
    simp only [Exec.Block.DefW16.numTabs, List.all_cons, Bool.and_eq_true]
    exact ⟨h.1, numTabs_shape_ok aB hB ioIn ioOut main ext ts ak hk pk h.2⟩

private theorem numTabs_pub_lt (aB hB ioIn ioOut : ℕ) :
    ∀ (ts : List TabS) (ak hk pk i : ℕ),
      TabS.pub i ∈ Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk pk ts → i < pk + pubCountS ts
  | [], _, _, _, _, h => by cases h
  | .priv _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1
    · exact numTabs_pub_lt aB hB ioIn ioOut ts _ _ pk i h2
  | .pub _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1; simp only [pubCountS]; omega
    · have ih := numTabs_pub_lt aB hB ioIn ioOut ts ak hk (pk + 1) i h2; simp only [pubCountS]; omega
  | .eq _ _ :: ts, ak, hk, pk, i, h => by
    rcases List.mem_cons.mp h with h1 | h2
    · cases h1
    · exact numTabs_pub_lt aB hB ioIn ioOut ts ak hk pk i h2

private theorem tabs_eval_filter_priv (ev : Exec.Block.Sym → Fp2) (pub : ℕ → List Fp2) :
    ∀ ts : List TabS, ((ts.map (TabS.eval ev pub)).filter Tab.isPriv).length = privCountS ts
  | [] => rfl
  | .priv _ :: ts => by
    simp only [List.map_cons, TabS.eval, List.filter_cons, Tab.isPriv, ↓reduceIte,
      List.length_cons, privCountS, tabs_eval_filter_priv]; omega
  | .pub _ :: ts => by simp only [List.map_cons, TabS.eval, List.filter_cons, Tab.isPriv, Bool.false_eq_true, ↓reduceIte, privCountS, tabs_eval_filter_priv]
  | .eq _ _ :: ts => by simp only [List.map_cons, TabS.eval, List.filter_cons, Tab.isPriv, Bool.false_eq_true, ↓reduceIte, privCountS, tabs_eval_filter_priv]

private theorem cubeTab_length (n : ℕ) (g : (Fin n → Bool) → GF) : (cubeTab n g).length = 2 ^ n := by
  simp [cubeTab]

private theorem foldTab_length (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) :
    (foldTab m n W r).length = 2 ^ m := by
  simp [foldTab]

private theorem pubsR13L_length (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (i : ℕ) (hi : i < blkMaxPub s) :
    (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb)
      (shieldShape Ly).nG s hist dr i).length = 2 ^ (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1 := by
  interval_cases s <;> simp only [blkMaxPub, List.getD_cons_zero, List.getD_cons_succ] at hi
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; rw [ite_eq_left (Or.inl rfl), hi0, ite_eq_left rfl, cubeTab_length]
    refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; rw [ite_eq_left (Or.inr rfl), hi0, ite_eq_left rfl, cubeTab_length]
    refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · have hi0 : i = 0 := by omega
    unfold pubsR13L; rw [Exec.Block.Join.R13H.Pub.pubsR13_rest _ _ _ _ _ 3 (Or.inl rfl)]
    rw [Exec.Block.Join.R13H.Pub.restR13L_three, hi0, ite_eq_left rfl, cubeTab_length]
    refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · omega
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, foldTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_right (by decide), ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · unfold pubsR13L pubsR13; dsimp only; repeat rw [ite_eq_right (by decide)]
    rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by decide), ite_eq_left rfl, cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · rw [Exec.Block.Join.R13H.Pub.pubsR13L_tab _ _ _ _ _ 19 (Or.inl rfl)]
    unfold restR13; dsimp only; rw [ite_eq_left rfl]; interval_cases i
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_left (by omega), List.length_map, List.length_range]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by omega), ite_eq_left (by omega), cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
    · rw [ite_eq_right (by omega), ite_eq_left (by omega), cubeTab_length]; refine congrArg (2 ^ ·) ?_; rfl
  · have hi0 : i = 0 := by omega
    rw [Exec.Block.Join.R13H.Pub.pubsR13L_tab _ _ _ _ _ 20 (Or.inr rfl)]
    unfold restR13; dsimp only; rw [ite_eq_right (by decide), ite_eq_left rfl, hi0, ite_eq_left rfl, cubeTab_length]
    refine congrArg (2 ^ ·) ?_; rfl
  · omega
  · omega

private theorem blkRawSlot_nonzero_eq (Ly : ShieldLayer) (s : ℕ) (hs : s < 23) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).nonzero =
      (blkNzOf s).map (fun j => Exec.Block.Sym.dr s j) := by
  interval_cases s <;> rfl

private def blkHostedFst : ℕ → List ℕ
  | 2 => [0, 1] | 14 => [10, 13] | 15 => [5, 9] | 16 => [6, 7] | 17 => [4, 8] | 18 => [11, 12] | _ => []

private theorem blkRawSlot_hosted_fst (Ly : ShieldLayer) (s : ℕ) (hs : s < 23) :
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map Prod.fst = blkHostedFst s := by
  interval_cases s <;> rfl

private theorem blkHostedFst_hostNe :
    ∀ k : Fin 23, decide (shdP_slotKind k.val = SlotKind.host) ≠ (blkHostedFst k.val).isEmpty := by
  decide

private theorem blkHostedFst_hostNe_at (s : ℕ) (hs : s < 23) :
    decide (shdP_slotKind s = SlotKind.host) ≠ (blkHostedFst s).isEmpty := by
  have h : ∀ (k : Fin 23) (n : ℕ), k.val = n →
      decide (shdP_slotKind n = SlotKind.host) ≠ (blkHostedFst n).isEmpty := by
    intro k n hkn; subst hkn; exact blkHostedFst_hostNe k
  exact h ⟨s, hs⟩ s rfl

private theorem blkHostedFst_lt :
    ∀ k : Fin 23, ∀ x ∈ blkHostedFst k.val, x < k.val := by
  decide

private theorem blkHostedFst_lt_at (s : ℕ) (hs : s < 23) (x : ℕ) (hx : x ∈ blkHostedFst s) : x < s := by
  have h : ∀ (k : Fin 23) (n : ℕ), k.val = n → ∀ y ∈ blkHostedFst n, y < n := by
    intro k n hkn; subst hkn; exact blkHostedFst_lt k
  exact h ⟨s, hs⟩ s rfl x hx

private theorem rawSlot_tabs_shape_at (s : ℕ) (hs : s < 23) :
    tabsShapeOKb (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1
      (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.1
      (Exec.Block.R13.shieldTerms.getD s 0) (blkMaxPub s)
      (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) s).tabs = true := by
  have h : ∀ (k : Fin 23) (n : ℕ), k.val = n →
      tabsShapeOKb (Exec.Block.R13.shieldSlots.getD n (0, 0, 0)).1
        (Exec.Block.R13.shieldSlots.getD n (0, 0, 0)).2.1
        (Exec.Block.R13.shieldTerms.getD n 0) (blkMaxPub n)
        (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 shdLy0) n).tabs = true := by
    intro k n hkn; subst hkn; exact rawSlot_tabs_shape k
  exact h ⟨s, hs⟩ s rfl

private theorem numSlot_tabs (aB hB ioIn ioOut ak hk : ℕ) (s : SlotS) :
    (Exec.Block.DefW16.numSlot aB hB ioIn ioOut ak hk s).tabs
      = Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk 0 s.tabs := rfl

private theorem list_map_fst_pair {α β : Type} (f : α → β) :
    ∀ l : List (ℕ × α), (l.map fun h => (h.1, f h.2)).map Prod.fst = l.map Prod.fst
  | [] => rfl
  | hd :: tl => congrArg (hd.1 :: ·) (list_map_fst_pair f tl)

private theorem shdP_blk_famSqBound_le {Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    (x : Coins × List Fp2) (i : ℕ) (hi : i ≤ 23) :
    famSqBound (corePf (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) x) i 0 ≤ 844 := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  have hd : P.draws = Exec.Block.R13.shieldDraws := shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk
  have hsl : P.geom.slots = Exec.Block.R13.shieldSlots := shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk
  have h23 : famSqBound (corePf P x) 23 0 = 844 := by
    simp only [famSqBound, corePf, slotN, slotShape, hd, hsl]; decide
  exact (famSqBound_mono _ hi).trans h23.le

/-- **Block `k` `defineS` refusal**: on canonical history/draws, `defineS` refuses ONLY at one of `blkNzList`. -/
theorem shdP_blkDefine_refuses (Ly : ShieldLayer) (ioIn ioOut : ℕ) (pubs : Exec.Block.PubTabs)
    (s : ℕ) (hs : s < 23) (hist : Hist) (dr : List Fp2) (hcan : Exec.Block.HistCanon hist dr) (e : String)
    (herr : defineS (Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut) pubs s hist dr = .error e) :
    ∃ p ∈ blkNzList, p.1 = s ∧ (dr.getD p.2 Fp2.zero).isZero = true := by
  unfold defineS at herr; rw [ite_eq_left hcan] at herr
  cases hnz : ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).nonzero.any
      (fun sym => (sym.eval hist s dr).isZero) with
  | false => rw [hnz, ite_eq_right Bool.false_ne_true] at herr; cases herr
  | true =>
    obtain ⟨sym, hsymMem, hsym0⟩ := List.any_eq_true.mp hnz
    obtain ⟨_, _, hslot⟩ := Exec.Block.Join.R13H.progR13_slot (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut s hs
    rw [hslot, (Exec.Block.Join.R13H.numSlot_fields _ _ _ _ _ _ _).2.2, blkRawSlot_nonzero_eq Ly s hs] at hsymMem
    obtain ⟨j, hjMem, rfl⟩ := List.mem_map.mp hsymMem
    have hev : (Exec.Block.Sym.dr s j).eval hist s dr = dr.getD j Fp2.zero := by
      unfold Exec.Block.Sym.eval Exec.Block.drawAt; rw [ite_eq_left rfl]
    rw [hev] at hsym0
    have hmem : (s, j) ∈ blkNzList := by
      have hall : ∀ s' : Fin 23, ∀ j' ∈ blkNzOf s'.val, (s'.val, j') ∈ blkNzList := by decide
      exact hall ⟨s, hs⟩ j hjMem
    exact ⟨(s, j), hmem, rfl, hsym0⟩

private theorem blk_slotChecks_core (P : BlockParams) (s : ℕ) (hs : s < 23)
    (aB hB ioIn ioOut ak hk' : ℕ) (rawTabs : List TabS) (pubs : Exec.Block.PubTabs)
    (hist : Hist) (acc : Acc) (hcs : acc.cs.length = s) (hsc : acc.scalars.length = s)
    (dr : List Fp2) (df : SlotDef)
    (hshape : slotShape P s = Exec.Block.R13.shieldSlots.getD s (0, 0, 0))
    (hterms : slotTerms P s = Exec.Block.R13.shieldTerms.getD s 0)
    (hkind : P.kind s = shdP_slotKind s)
    (htabs : df.tabs = (Exec.Block.DefW16.numTabs aB hB ioIn ioOut ak hk' 0 rawTabs).map
      (TabS.eval (Exec.Block.Sym.eval hist s dr) (pubs s hist dr)))
    (hhost : df.hosted.map Prod.fst = blkHostedFst s)
    (hshOK : tabsShapeOKb (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1
      (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.1
      (Exec.Block.R13.shieldTerms.getD s 0) (blkMaxPub s) rawTabs = true)
    (hpubLen : ∀ i < blkMaxPub s, (pubs s hist dr i).length = 2 ^ (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1)
    (sel sc : Fp2) (rho terms : List Fp2) (hrho : rho.length = (slotShape P s).1) :
    slotDefChecks P s acc df = .ok () ∧ (∃ v, hostedSum acc.scalars sc df.hosted = .ok v)
      ∧ (∃ vs, tabVals sel rho terms df.tabs 0 = .ok vs) := by
  simp only [tabsShapeOKb, Bool.and_eq_true, decide_eq_true_eq] at hshOK
  obtain ⟨⟨hprivS, hpubS⟩, hallS⟩ := hshOK
  have hnumAll := numTabs_shape_ok aB hB ioIn ioOut
    (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1 (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.1
    rawTabs ak hk' 0 hallS
  have hpriv : (df.tabs.filter Tab.isPriv).length = slotTerms P s := by
    rw [htabs, tabs_eval_filter_priv, numTabs_privCount, hprivS, hterms]
  have hhostNe : decide (P.kind s = SlotKind.host) ≠ df.hosted.isEmpty := by
    have hE : df.hosted.isEmpty = (df.hosted.map Prod.fst).isEmpty := by cases df.hosted <;> rfl
    rw [hE, hhost, hkind]
    exact blkHostedFst_hostNe_at s hs
  have hpt : ∀ p, Tab.priv p ∈ df.tabs → p.extRound < (slotShape P s).2.1 ∧ p.coords.length = p.log := by
    intro p hp; rw [htabs] at hp
    obtain ⟨tb, htbMem, htbEq⟩ := List.mem_map.mp hp
    have hok := List.all_eq_true.mp hnumAll tb htbMem
    cases tb with
    | eq _ _ => cases htbEq
    | pub _ => cases htbEq
    | priv ps =>
      rw [← Tab.priv.inj htbEq, hshape]; simp only [tabShapeOKb, Bool.and_eq_true, decide_eq_true_eq] at hok
      exact ⟨hok.1, by simp [PrivS.eval, hok.2]⟩
  have hpub : ∀ v, Tab.pub v ∈ df.tabs → v.length = 2 ^ (slotShape P s).1 := by
    intro v hv; rw [htabs] at hv
    obtain ⟨tb, htbMem, htbEq⟩ := List.mem_map.mp hv
    cases tb with
    | eq _ _ => cases htbEq
    | priv _ => cases htbEq
    | pub i =>
      rw [← Tab.pub.inj htbEq, hshape]
      have hilt : i < blkMaxPub s := lt_of_lt_of_le (by
        have hlt := numTabs_pub_lt aB hB ioIn ioOut rawTabs ak hk' 0 i htbMem
        rwa [Nat.zero_add] at hlt) hpubS
      exact hpubLen i hilt
  refine ⟨slotDefChecks_ok_of P s acc df hcs hpriv hhostNe hpt hpub,
    hostedSum_ok_of acc.scalars df.hosted sc (fun p hp => by
      have hp1 : p.1 ∈ df.hosted.map Prod.fst := List.mem_map.mpr ⟨p, hp, rfl⟩
      rw [hhost] at hp1; rw [hsc]
      exact blkHostedFst_lt_at s hs p.1 hp1),
    tabVals_ok_of_fit sel rho terms df.tabs 0 (fun t ht => by
      cases t with
      | priv _ => trivial
      | pub v => rw [hrho]; exact hpub v ht
      | eq pt st =>
        rw [htabs] at ht
        obtain ⟨tb, htbMem, htbEq⟩ := List.mem_map.mp ht
        have hok := List.all_eq_true.mp hnumAll tb htbMem
        cases tb with
        | priv _ => cases htbEq
        | pub _ => cases htbEq
        | eq pts st' =>
          obtain ⟨hptEq, hstEq⟩ := Tab.eq.inj htbEq; simp only [tabShapeOKb, decide_eq_true_eq] at hok
          dsimp only; rw [← hptEq, ← hstEq, hrho, hshape, List.length_map]; exact hok)⟩

/-- **Block `k` deterministic slot checks**: for every `s < 23`, `slotDefChecks`, `hostedSum`, and `tabVals` succeed. -/
theorem shdP_blk_slotChecks_ok (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (s : ℕ) (hs : s < 23) (hist : Hist) (acc : Acc) (hcs : acc.cs.length = s) (hsc : acc.scalars.length = s)
    (dr : List Fp2) (df : SlotDef)
    (hdef : (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb).define s hist dr = .ok df)
    (sel sc : Fp2) (rho terms : List Fp2)
    (hrho : rho.length = (slotShape (shdP_blkParams tag ioIn ioOut checkOpening Ly Pb) s).1) :
    let P := shdP_blkParams tag ioIn ioOut checkOpening Ly Pb
    slotDefChecks P s acc df = .ok () ∧ (∃ v, hostedSum acc.scalars sc df.hosted = .ok v)
      ∧ (∃ vs, tabVals sel rho terms df.tabs 0 = .ok vs) := by
  intro P
  obtain ⟨-, hdf⟩ := defineS_ok hdef
  obtain ⟨ak, hk', hslot⟩ := Exec.Block.Join.R13H.progR13_slot (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut s hs
  have htabs : df.tabs = (Exec.Block.DefW16.numTabs
      (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
      (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut ak hk' 0
      (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs).map
      (TabS.eval (Exec.Block.Sym.eval hist s dr)
        (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG s hist dr)) :=
    calc df.tabs
        = ((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).tabs.map
            (TabS.eval (Exec.Block.Sym.eval hist s dr)
              (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG s hist dr)) :=
            congrArg SlotDef.tabs hdf
      _ = (Exec.Block.DefW16.numSlot
            (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
            (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut ak hk'
            (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s)).tabs.map
            (TabS.eval (Exec.Block.Sym.eval hist s dr)
              (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG s hist dr)) :=
            congrArg (fun sl : SlotS => sl.tabs.map
              (TabS.eval (Exec.Block.Sym.eval hist s dr)
                (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG s hist dr))) hslot
      _ = _ := congrArg (List.map _) (numSlot_tabs _ _ _ _ _ _ _)
  have hhost : df.hosted.map Prod.fst = blkHostedFst s := by
    calc df.hosted.map Prod.fst
        = (((Exec.Block.DefR13.progR13 (Exec.Block.DefR13.cfgShieldR13 Ly) ioIn ioOut).getD s SlotS.empty).hosted.map
            fun h => (h.1, h.2.eval hist s dr)).map Prod.fst := congrArg (fun d => d.hosted.map Prod.fst) hdf
      _ = (((Exec.Block.DefW16.numSlot
            (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
            (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly)) ioIn ioOut ak hk'
            (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s)).hosted.map
            fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) :=
          congrArg (fun sl : SlotS => (sl.hosted.map fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) hslot
      _ = (((Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map
            fun h => (h.1, h.2.eval hist s dr)).map Prod.fst) :=
          congrArg (fun l => (l.map fun h => (h.1, h.2.eval hist s dr)).map Prod.fst)
            (Exec.Block.Join.R13H.numSlot_fields _ _ _ _ _ _ _).2.1
      _ = (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).hosted.map Prod.fst :=
          list_map_fst_pair (fun sym : Exec.Block.Sym => sym.eval hist s dr) _
      _ = blkHostedFst s := blkRawSlot_hosted_fst Ly s hs
  have hshOK : tabsShapeOKb (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).1
      (Exec.Block.R13.shieldSlots.getD s (0, 0, 0)).2.1
      (Exec.Block.R13.shieldTerms.getD s 0) (blkMaxPub s)
      (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs = true := by
    rw [rawSlot_tabs_indep Ly s]
    exact rawSlot_tabs_shape_at s hs
  exact blk_slotChecks_core P s hs
    (Exec.Block.DefR13.aDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
    (Exec.Block.DefR13.hDataRows (Exec.Block.DefR13.cfgShieldR13 Ly))
    ioIn ioOut ak hk'
    (Exec.Block.DefR13.rawSlot (Exec.Block.DefR13.cfgShieldR13 Ly) s).tabs
    (pubsR13L (Exec.Block.DefR13.cfgShieldR13 Ly) Pb (shdP_bitLay Ly) (shdP_w16Pub Ly Pb) (shieldShape Ly).nG)
    hist acc hcs hsc dr df rfl rfl rfl htabs hhost hshOK
    (fun i hi => pubsR13L_length Ly Pb s hs hist dr i hi)
    sel sc rho terms hrho

theorem shdP_blk_nFunctionals (H : HIn → Dig) (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    (D : SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)) (b g a : Fp2) (t3 : Tr)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (h : slotsProve H (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) D b g a 23 [] 0 {} t3 = .ok (sps, recs, acc, t4)) :
    (acc.fs ++ acc.hostFs).length = (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).nFunctionals := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  rw [slotsProve_eq_fam] at h
  obtain ⟨-, -, hfs, -⟩ := famProve_inv H (fun _ => P) (fun _ => D) b g a 23 [] 0 {} t3 sps recs acc t4
    (fun _ hr => by cases hr) h
  have hkind : P.kind = shdP_slotKind := by dsimp only [P]; rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]; rfl
  have hinc34 : famFuncInc (fun _ => P) 23 0 = 34 := by simp only [famFuncInc, hkind]; decide
  rw [hfs, hinc34, shdP_Pk0_nFunctionals tag ioIn ioOut checkOpening Rp hR k hk]; rfl

/-- Block `k` `TProg` chain: `blkHeadProg` → `blkSlotEndProg` → `blkMaskProg` → `blkOpenAProg` → `blkOpenHProg`. -/
noncomputable def blkHeadProg {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (c : Coins) : TProg (Coins × List Fp2) :=
  coreHeadProg P c (blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c)))
    (rootOfP tag 16 (TA c)) (rootOfP tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (fun ch => rootOfP tag 16 (TH c (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero) (ch.getD 2 Fp2.zero)))

noncomputable def blkSlotEndProg {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (Dc : Coins → SlotData P) (i : ℕ) (c : Coins) :
    TProg ((Coins × List Fp2) × List SlotRec × Acc) :=
  famPre (corePf P) (coreDf P Dc) coreBga (blkHeadProg tag P k dig pre TB_next TA M TH c) i

noncomputable def blkMaskProg {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (Dc : Coins → SlotData P) (c : Coins) :=
  bMaskProg 23 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
    (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc 23 c)

noncomputable def blkOpenAProg {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (Dc : Coins → SlotData P) (c : Coins) :=
  bOpenProg Exec.R13.r13Prm 146 (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
    (blkMaskProg tag P k dig pre TB_next TA M TH Dc c)

noncomputable def blkOpenHProg {α Coins : Type} (tag : MTag) (P : BlockParams) (k : ℕ) (dig : Dig)
    (pre : Coins → TProg α) (TB_next TA : Coins → Table) (M : Coins → MTable)
    (TH : Coins → Fp2 → Fp2 → Fp2 → Table) (Dc : Coins → SlotData P) (c : Coins) :=
  bOpenProg Exec.R13.r13Prm 54
    (fun y => TH y.1.1.1.1 (coreBga y.1.1.1).1 (coreBga y.1.1.1).2.1 (coreBga y.1.1.1).2.2)
    (fun y => y.1.1.2.2.claims.h ++ [P.logupSumClaim])
    (blkOpenAProg tag P k dig pre TB_next TA M TH Dc c)

private theorem blkSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 23) (c : Coins) :
    TProg.Sep key (blkSlotEndProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc i c)
      ∧ SqLE (mPre + 847) (blkSlotEndProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc i c) := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  have hfrSep := sep_blkFrameProg key k dig (pre c) (rootOfP tag 16 (TB_next c)) (hs c)
  have hfrSq := sqLE_blkFrameProg k dig mPre (pre c) (rootOfP tag 16 (TB_next c)) (hsq c)
  exact ⟨sep_famPre _ _ _ key _ (sep_coreHeadProg P key c _ _ _ _ hfrSep) i,
    sqLE_mono _ ((mPre + 3) + 844) (mPre + 847)
      (sqLE_famPre (corePf P) (coreDf P Dc) coreBga _ i (mPre + 3) 844
        (sqLE_coreHeadProg P c _ _ _ _ mPre hfrSq)
        (fun x => shdP_blk_famSqBound_le tag ioIn ioOut checkOpening Rp hR k hk x i hi)) (by omega)⟩

private theorem blkMaskProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (blkMaskProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 960) (blkMaskProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c) :=
  let hS := blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq 23 le_rfl c
  ⟨sep_bMaskProg key 23 _ _ _ hS.1,
   sqLE_mono _ _ (mPre + 960) (sqLE_bMaskProg 23 (mPre + 847) _ _ _ hS.2) (by norm_num [mQ])⟩

private theorem blkOpenAProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (blkOpenAProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 5747) (blkOpenAProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c) :=
  let hM := blkMaskProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq c
  ⟨sep_bOpenProg key _ 146 _ _ _ hM.1,
   sqLE_mono _ _ (mPre + 5747)
     (sqLE_bOpenProg Exec.R13.r13Prm 146 4577 (mPre + 960) _ _ _ hM.2 (fun y => hrA y.1.1.1))
     (by norm_num [Exec.R13.r13Prm])⟩

private theorem blkOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (blkOpenHProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 10255) (blkOpenHProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c) :=
  let hA := blkOpenAProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH hrA Dc hs hsq c
  ⟨sep_bOpenProg key _ 54 _ _ _ hA.1,
   sqLE_mono _ _ (mPre + 10255)
     (sqLE_bOpenProg Exec.R13.r13Prm 54 4390 (mPre + 5747) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 _ _ _))
     (by norm_num [Exec.R13.r13Prm])⟩

/-- **Concrete Block `k` (`k < 26`) per-segment `startSite` family** (`SiteIdx blkSegCount`, `3/872/23/25/16/1/0`). -/
noncomputable def blkSegSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (collA : OpenCollFamily Lq Coins 630) (collH : OpenCollFamily Lq Coins 36) (collB : OpenCollFamily Lq Coins 1) :
    SiteIdx blkSegCount → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let preFr := fun c => blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))
  let preS := blkSlotEndProg tag P k dig pre TB_next TA M TH Dc
  let preM := blkMaskProg tag P k dig pre TB_next TA M TH Dc
  let preA := blkOpenAProg tag P k dig pre TB_next TA M TH Dc
  let preH := blkOpenHProg tag P k dig pre TB_next TA M TH Dc
  let hS := fun i (hi : i ≤ 23) c => blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq i hi c
  let hM := fun c => blkMaskProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq c
  let hA := fun c => blkOpenAProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH hrA Dc hs hsq c
  let hH := fun c => blkOpenHProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH hrA hrH Dc hs hsq c
  fun ⟨kind, idx⟩ =>
    match kind, idx with
    | ⟨0, _⟩, ⟨0, _⟩ => openDepStartSite Lq hLq key domain hdom 146 4575 preM (fun c => (hM c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 4722 (mPre + 960) (preM c) (hM c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨1, _⟩ => openDepStartSite Lq hLq key domain hdom 54 4388 preA (fun c => (hA c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 4443 (mPre + 5747) (preA c) (hA c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨2, _⟩ => openDepStartSite Lq hLq key domain hdom 2 36 preH (fun c => (hH c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 39 (mPre + 10255) (preH c) (hH c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨n + 3, h⟩ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
    | ⟨1, _⟩, idx =>
      finApp3
        (openK1Site Lq hLq key domain hdom 146 4575 630 preM (fun c => (hM c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 960) (preM c) (hM c).2) (by omega) dg) collA)
        (openK1Site Lq hLq key domain hdom 54 4388 36 preA (fun c => (hA c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 5747) (preA c) (hA c).2) (by omega) dg) collH)
        (openK1Site Lq hLq key domain hdom 2 36 1 preH (fun c => (hH c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 10255) (preH c) (hH c).2) (by omega) dg) collB) idx
    | ⟨2, _⟩, idx =>
      depCStartSite Lq hLq key domain hdom (corePf P) (preS idx.val) idx.val
        (fun c => (hS idx.val (Nat.le_of_lt idx.isLt) c).1)
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depCProg (corePf P) (preS idx.val c) idx.val (mPre + 847) 53 (hS idx.val (Nat.le_of_lt idx.isLt) c).2
            (fun _ => by
              change P.draws idx.val ≤ 53; rw [shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk]
              exact (show ∀ s : Fin 23, Exec.Block.R13.shieldDraws s.val ≤ 53 by decide) idx))
          (by omega) dg)
    | ⟨3, _⟩, idx =>
      listPairSite blkExtList (fun s r =>
        if h23 : s < 23 then
          depEStartSite Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga (preS s) s (min r 25)
            (fun c => (hS s (Nat.le_of_lt h23) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_depEProg (corePf P) (coreDf P Dc) coreBga (preS s c) s (min r 25) (mPre + 847) 53 (hS s (Nat.le_of_lt h23) c).2
                (fun _ => by
                  change P.draws s ≤ 53; rw [shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk]
                  exact (show ∀ s' : Fin 23, Exec.Block.R13.shieldDraws s'.val ≤ 53 by decide) ⟨s, h23⟩))
              (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨4, _⟩, idx =>
      listPairSite blkNzList (fun s j =>
        if h23 : s < 23 then
          drawZeroStartSite Lq hLq key domain hdom (min j 53) (preS s)
            (fun c => (hS s (Nat.le_of_lt h23) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_drawProg (min j 53) (mPre + 847) (preS s c) (hS s (Nat.le_of_lt h23) c).2) (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨5, _⟩, _ =>
      shdP_blkAlphaStartSite Lq hLq key domain hdom P (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) preFr
        (fun c => rootOfP tag 16 (TA c)) (fun c => rootOfP tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
        (fun c => sep_blkFrameProg key k dig (pre c) _ (hs c))
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_blkAlphaProg P mPre (preFr c) _ _ (sqLE_blkFrameProg k dig mPre (pre c) _ (hsq c))) (by omega) dg)
    | ⟨6, _⟩, idx => by have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
    | ⟨k' + 7, h⟩, _ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k') h; cases hf

theorem blkSegSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (collA : OpenCollFamily Lq Coins 630) (collH : OpenCollFamily Lq Coins 36) (collB : OpenCollFamily Lq Coins 1)
    (i : SiteIdx blkSegCount) :
    (blkSegSite Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
      TB_next TA M TH hrA hrH Dc collA collH collB i).k ≤ kPer gP (2 ^ 17) (2 ^ 20) i.1
    ∧ (blkSegSite Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
      TB_next TA M TH hrA hrH Dc collA collH collB i).δ = 0 := by
  rcases i with ⟨kind, idx⟩
  match kind, idx with
  | ⟨0, _⟩, ⟨0, _⟩ | ⟨0, _⟩, ⟨1, _⟩ | ⟨0, _⟩, ⟨2, _⟩ => exact ⟨le_rfl, rfl⟩
  | ⟨0, _⟩, ⟨n + 3, h⟩ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
  | ⟨1, _⟩, idx =>
    exact finApp3_prop _ _ _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 146 4575 630 _ _ _ collA j)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 54 4388 36 _ _ _ collH j)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 2 36 1 _ _ _ collB j) idx
  | ⟨2, _⟩, _ => exact ⟨le_rfl, rfl⟩
  | ⟨3, _⟩, idx =>
    exact listPairSite_prop blkExtList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 2 ∧ s.δ = 0) (fun s _ => by
      by_cases h23 : s < 23
      · rw [dite_eq_left h23]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h23]; exact ⟨by change 0 ≤ 2; omega, rfl⟩) idx
  | ⟨4, _⟩, idx =>
    exact listPairSite_prop blkNzList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0) (fun s _ => by
      by_cases h23 : s < 23
      · rw [dite_eq_left h23]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h23]; exact ⟨by change 0 ≤ 1; omega, rfl⟩) idx
  | ⟨5, _⟩, _ => exact ⟨by change 49152 ≤ 2 ^ 17; norm_num, rfl⟩
  | ⟨6, _⟩, idx => have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
  | ⟨k' + 7, h⟩, _ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k') h; cases hf

/-- **Block `k` (`k < 26`) per-segment refusal cover**: covers LogUp `blkAlphaBad`, any `coreProve` refusal,
or any `bndCheck` refusal into the `blkSegCount` (`3/872/23/25/16/1/0`) `startSite`s of `blkSegSite`. -/
theorem blkSeg_refuse_cover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (collA : OpenCollFamily Lq Coins 630) (collH : OpenCollFamily Lq Coins 36) (collB : OpenCollFamily Lq Coins 1)
    (G : QB Lq → Dig) (c : Coins) (D : CoreData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (pending : List Exec.Block.ZClaim) (bndCheck : List Exec.Block.ZClaim → Tr → Except String Unit)
    (hchkA : ∀ cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ cl t e, bndCheck cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hA : D.aRoot = rootOf (liftH G) tag 16 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH c b g a))
    (hD : D.slot = Dc c)
    (hMO : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij (M c) 23)
    (hAO : D.aOpen = bOpen (liftH G) tag Exec.R13.r13Prm 16 (TA c))
    (hHO : D.hOpen = bOpen (liftH G) tag Exec.R13.r13Prm 16
      (let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
       TH c (coreB (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) D tFr).1
         (coreG (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) D tFr).1
         (coreA (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) D tFr).1))
    (hAudA : ∀ sps recs acc t4,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) →
      OpenAuditOk shdP_blkOpenGeomA 14 146 630 collA G c acc.claims.a)
    (hAudH : ∀ sps recs acc t4,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) →
      OpenAuditOk shdP_blkOpenGeomH 14 54 36 collH G c (acc.claims.h ++ [P.logupSumClaim]))
    (hAudB : ∀ R,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      coreProve (liftH G) P D tFr = .ok R →
      OpenAuditOk shdP_bndOpenGeom 14 2 1 collB G c (pending ++ R.acc.claims.inp))
    (href :
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      blkAlphaBadP (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)
          (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1
        ∨ coreProve (liftH G) P D tFr = .error ()
        ∨ ∃ R e, coreProve (liftH G) P D tFr = .ok R ∧ bndCheck (pending ++ R.acc.claims.inp) R.t7 = .error e) :
    ∃ i : SiteIdx blkSegCount,
      (blkSegSite Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
        TB_next TA M TH hrA hrH Dc collA collH collB i).fires shdP_U G c := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let t0 := Tr.newKeyed (liftH G) domain key
  let preFr := fun c' => blkFrameProg k dig (pre c') (rootOfP tag 16 (TB_next c'))
  let tFr := ((preFr c).final (liftH G) t0).1
  let hd := blkHeadProg tag P k dig pre TB_next TA M TH
  have hPeq := shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk
  have hDraws := shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk
  have hSlots := shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk
  have hLen23 := shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk
  have hS := fun i (hi : i ≤ 23) c' => blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq i hi c'
  have hM' := fun c' => blkMaskProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq c'
  have hA' := fun c' => blkOpenAProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH hrA Dc hs hsq c'
  have hH' := fun c' => blkOpenHProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH hrA hrH Dc hs hsq c'
  let x0 : Coins × List Fp2 :=
    (c, [(coreB (liftH G) P D tFr).1, (coreG (liftH G) P D tFr).1, (coreA (liftH G) P D tFr).1])
  have hF : (hd c).final (liftH G) t0 = (coreT3 (liftH G) P D tFr, x0) := by
    unfold hd blkHeadProg; rw [final_coreHeadProg]
    have hT2 : (absorbRoot (liftH G) tFr labA (rootOf (liftH G) tag 16 (TA c)) P.aRows P.logCols).absorb (liftH G)
        labM (rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c))).toList = coreT2 (liftH G) P D tFr := by
      unfold coreT2; rw [hA, hM]
    rw [hT2, ← hH]; rfl
  rcases href with hbad | hcore | ⟨R, eB, hRok, hBerr⟩
  · refine ⟨⟨⟨5, by decide⟩, ⟨0, by decide⟩⟩, ?_⟩
    exact shdP_blkAlphaBad_cover Lq hLq key domain hdom P (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk) preFr
      (fun c' => rootOfP tag 16 (TA c')) (fun c' => rootOfP tag 12 (mTab 23 (cosetPt (rootFp 12)) (M c')))
      (fun c' => sep_blkFrameProg key k dig (pre c') _ (hs c'))
      (fun c' dg => noWrap_start_of_sqLE
        (sqLE_blkAlphaProg P mPre (preFr c') _ _ (sqLE_blkFrameProg k dig mPre (pre c') _ (hsq c'))) (by omega) dg)
      G c D hA hM hbad
  · unfold coreProve at hcore; rw [hLen23] at hcore
    split at hcore
    · rename_i e he; cases e; rw [slotsProve_eq_fam, hD] at he
      have hrB : ∀ i, i < 23 → slotN P i ≤ 25 := fun i hi => by
        unfold slotN slotShape; rw [hSlots]
        exact (show ∀ s : Fin 23, (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).1
          + (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).2.1 ≤ 25 by decide) ⟨i, hi⟩
      obtain ⟨i, hi, ti, recs, acc, hY, hcs, hsc, hcanRecs, hcase⟩ :=
        fam_startCover_ext Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga hd
          (fun c' => sep_coreHeadProg P key c' (preFr c') _ _ _ (sep_blkFrameProg key k dig (pre c') _ (hs c'))) 23 25
          (fun i hi c' dg => noWrap_start_of_sqLE
            (sqLE_depCProg (corePf P) (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i c') i (mPre + 847) 53
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => by change P.draws i ≤ 53; rw [hDraws]; exact (show ∀ s : Fin 23, Exec.Block.R13.shieldDraws s.val ≤ 53 by decide) ⟨i, hi⟩))
            (by omega) dg)
          (fun i hi m hm c' dg => noWrap_start_of_sqLE
            (sqLE_depEProg (corePf P) (coreDf P Dc) coreBga (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i c') i m (mPre + 847) 53
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => by change P.draws i ≤ 53; rw [hDraws]; exact (show ∀ s : Fin 23, Exec.Block.R13.shieldDraws s.val ≤ 53 by decide) ⟨i, hi⟩))
            (by omega) dg) G c x0 _ hrB hF he
      rcases hcase with ⟨e', hdefErr⟩ | hC | ⟨j, hm, hE⟩ | ⟨df, hdf, hdet⟩
      · have hHistCan : Exec.Block.HistCanon (histOf (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1
            (coreA (liftH G) P D tFr).1 recs) (ti.challengeFp2Vec (liftH G) (P.draws i)).1 := by
          refine ⟨canon_challengeFp2Of _, canon_challengeFp2Of _, ?_, chalVec_canon (liftH G) _ _⟩
          intro l hl; unfold histOf at hl; obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hl; exact hcanRecs r hr
        have hDefEq : P.define = (shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)).define :=
          congrArg BlockParams.define hPeq
        change P.define i _ _ = .error e' at hdefErr
        rw [hDefEq] at hdefErr
        obtain ⟨p, hpMem, hp1, hp0⟩ := shdP_blkDefine_refuses (shdP_blkLy k hk) ioIn ioOut _ i hi _ _ hHistCan e' hdefErr
        have hp2Lt : p.2 < P.draws i := by
          rw [hDraws, ← hp1]
          exact (show ∀ q ∈ blkNzList, q.2 < Exec.Block.R13.shieldDraws q.1 by decide) p hpMem
        have hp2Le : p.2 ≤ 53 := (show ∀ q ∈ blkNzList, q.2 ≤ 53 by decide) p hpMem
        have hfire : (drawZeroStartSite Lq hLq key domain hdom (min p.2 53)
            (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i)
            (fun c' => (hS i (Nat.le_of_lt hi) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg (min p.2 53) (mPre + 847) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)).fires shdP_U G c := by
          rw [drawZeroStartSite_fires_congr Lq hLq key domain hdom (min p.2 53) p.2 (Nat.min_eq_left hp2Le) _ _
            (fun c' => (hS i (Nat.le_of_lt hi) c').1) _
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg p.2 (mPre + 847) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)]
          rw [drawZeroStartSite_fires_at Lq hLq key domain hdom (P.draws i) p.2 hp2Lt]
          change ((((blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i c).final (liftH G) t0).1.challengeFp2Vec (liftH G) _).1.getD p.2 Fp2.zero).isZero = true
          rw [show (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i c).final (liftH G) t0 = (ti, (x0, recs, acc)) from hY]
          exact hp0
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem blkNzList
          (fun s j => if h23 : s < 23 then drawZeroStartSite Lq hLq key domain hdom (min j 53)
            (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc s) (fun c' => (hS s (Nat.le_of_lt h23) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg (min j 53) (mPre + 847) _ (hS s (Nat.le_of_lt h23) c').2) (by omega) dg)
            else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) p.1 p.2 hpMem (by rw [hp1, dite_eq_left hi]; exact hfire)
        exact ⟨⟨⟨4, by norm_num⟩, idx⟩, hidx⟩
      · refine ⟨⟨⟨2, by norm_num⟩, ⟨i, hi⟩⟩, ?_⟩
        exact (depCStartSite_fires_irrel Lq hLq key domain hdom (corePf P)
          (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc i) i
          _ (fun c' => (hS i (Nat.le_of_lt hi) c').1) _ _ G c).mp hC
      · let r := (slotShape P i).1 + j.val
        have hmem : (i, r) ∈ blkExtList := by
          have hshape : slotShape P i = Exec.Block.R13.shieldSlots.getD i (0, 0, 0) := by
            unfold slotShape; dsimp only [P]; rw [hSlots]
          have hjLt : j.val < (Exec.Block.R13.shieldSlots.getD i (0, 0, 0)).2.1 :=
            lt_of_lt_of_eq j.isLt (congrArg (fun t => t.2.1) hshape)
          have hrEq : r = (Exec.Block.R13.shieldSlots.getD i (0, 0, 0)).1 + j.val :=
            congrArg (· + j.val) (congrArg Prod.fst hshape)
          rw [hrEq]
          exact (show ∀ s : Fin 23, ∀ o : Fin 2, o.val < (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).2.1 →
            (s.val, (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).1 + o.val) ∈ blkExtList by decide)
            ⟨i, hi⟩ ⟨j.val, by
              have hle2 : (Exec.Block.R13.shieldSlots.getD i (0, 0, 0)).2.1 ≤ 2 :=
                (show ∀ s : Fin 23, (Exec.Block.R13.shieldSlots.getD s.val (0, 0, 0)).2.1 ≤ 2 by decide) ⟨i, hi⟩
              omega⟩ hjLt
        have hrLe : r ≤ 25 := Nat.le_of_lt hm
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem blkExtList
          (fun s r' => if h23 : s < 23 then depEStartSite Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga
            (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc s) s (min r' 25)
            (fun c' => (hS s (Nat.le_of_lt h23) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_depEProg (corePf P) (coreDf P Dc) coreBga _ s (min r' 25) (mPre + 847) 53
              (hS s (Nat.le_of_lt h23) c').2 (fun _ => by change P.draws s ≤ 53; rw [hDraws]; exact (show ∀ s' : Fin 23, Exec.Block.R13.shieldDraws s'.val ≤ 53 by decide) ⟨s, h23⟩))
              (by omega) dg) else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) i r hmem (by
            rw [dite_eq_left hi]
            exact (depEStartSite_fires_congr Lq hLq key domain hdom (corePf P) (coreDf P Dc) coreBga _ i r (min r 25)
              (Nat.min_eq_left hrLe).symm _ _ _ _ G c).mp hE)
        exact ⟨⟨⟨3, by norm_num⟩, idx⟩, hidx⟩
      · let histI := histOf (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 recs
        let drI := (ti.challengeFp2Vec (liftH G) (P.draws i)).1
        let rhoAll := slotRho (liftH G) P (Dc c) i histI acc ti df
        let selI := Block.oneMinusProd (rhoAll.drop (slotShape P i).1)
        let scI := (slotSP (liftH G) P (Dc c) i histI acc ti df).scalar
        let rhoI := rhoAll.take (slotShape P i).1
        let termsI := (slotSP (liftH G) P (Dc c) i histI acc ti df).terms
        have hrhoLen : rhoI.length = (slotShape P i).1 := by
          dsimp only [rhoI, rhoAll]; rw [List.length_take, slotRho_length]; unfold slotN; exact Nat.min_eq_left (by omega)
        have hDefEq : P.define = (shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)).define :=
          congrArg BlockParams.define hPeq
        have hShapeEq : slotShape P i = slotShape (shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)) i :=
          congrArg (fun Q => slotShape Q i) hPeq
        have hChkEq : slotDefChecks P i acc df = slotDefChecks (shdP_blkParams tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)) i acc df :=
          congrArg (fun Q => slotDefChecks Q i acc df) hPeq
        have hok := shdP_blk_slotChecks_ok tag ioIn ioOut checkOpening (shdP_blkLy k hk) (shdP_blkPb Rp hR k hk)
          i hi histI acc hcs hsc drI df (by rw [← hDefEq]; exact hdf) selI scI rhoI termsI (by rw [← hShapeEq]; exact hrhoLen)
        rcases hdet with ⟨_, he1⟩ | ⟨_, he2⟩ | ⟨_, he3⟩
        · change slotDefChecks P i acc df = .error _ at he1
          rw [hChkEq, hok.1] at he1; cases he1
        · obtain ⟨_, hv⟩ := hok.2.1; change hostedSum acc.scalars scI df.hosted = .error _ at he2
          rw [hv] at he2; cases he2
        · obtain ⟨_, hvs⟩ := hok.2.2; change tabVals selI rhoI termsI df.tabs 0 = .error _ at he3
          rw [hvs] at he3; cases he3
    · rename_i sps recs acc t4 hsl
      have hnF := shdP_blk_nFunctionals (liftH G) tag ioIn ioOut checkOpening Rp hR k hk D.slot _ _ _ _ sps recs acc t4 hsl
      rw [ite_eq_right (not_not.mpr hnF)] at hcore
      have hEnd : (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc 23 c).final (liftH G) t0 = (t4, (x0, recs, acc)) := by
        rw [blkSlotEndProg, final_famPre (liftH G) (corePf P) (coreDf P Dc) coreBga (hd c) 23 t0 sps recs acc t4
          (by rw [hF, ← slotsProve_eq_fam, ← hD]; exact hsl), hF]
      have hMask : ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
            = (bMask (liftH G) tag shdP_U shdP_hbij (M c) 23 (acc.fs ++ acc.hostFs) t4).2
          ∧ ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).2.1 = (x0, recs, acc) := by
        have h := final_bMaskProg (liftH G) tag 23 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
          (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc 23 c) t0
        rw [hEnd] at h; exact h
      have ht5 : ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
          = (D.mOpen (acc.fs ++ acc.hostFs) t4).2 := by rw [hMO]; exact hMask.1
      have hAudA' := hAudA sps recs acc t4 hsl
      have hAudH' := hAudH sps recs acc t4 hsl
      cases hcA : P.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e =>
        have hchkEq : P.checkOpening = checkOpening := by dsimp only [P]; rw [hPeq]; rfl
        rw [hchkEq] at hcA
        obtain ⟨e', he'⟩ := hchkA _ _ e hcA; rw [← ht5] at he'
        rcases checkOpeningFull_startCover Lq hLq key domain hdom shdP_blkOpenGeomA 14 146 630
            (blkMaskProg tag P k dig pre TB_next TA M TH Dc) (fun c' => (hM' c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 4722 (mPre + 960) _ (hM' c').2) (by omega) dg)
            (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 960) _ (hM' c').2)
              (by unfold shdP_blkOpenGeomA at hj; dsimp only at hj; omega) dg)
            collA (by unfold shdP_blkOpenGeomA; dsimp only; omega)
            G c acc.claims.a hAudA' e' he' with h0 | ⟨j, hj⟩
        · exact ⟨⟨⟨0, by decide⟩, ⟨0, by decide⟩⟩, h0⟩
        · refine ⟨⟨⟨1, by decide⟩, ⟨j.val, by change j.val < 872; omega⟩⟩, ?_⟩
          change ProtocolClassify.Site.fires shdP_U
            (finApp3 (m₁ := (146 + 1) + 630) (m₂ := (54 + 1) + 36) (m₃ := (2 + 1) + 1) _ _ _ ⟨j.val, by omega⟩) G c
          rw [finApp3_1]; exact hj
      | ok _ =>
        have hOpenA : ((blkOpenAProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
            = (bOpen (liftH G) tag Exec.R13.r13Prm 16 (TA c) acc.claims.a
                (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 := by
          have h := final_bOpenProg (liftH G) tag Exec.R13.r13Prm 16 146 (by norm_num [Exec.R13.r13Prm, PcsPrm.nn])
            (by norm_num [Exec.R13.r13Prm]) (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
            (blkMaskProg tag P k dig pre TB_next TA M TH Dc c) t0 (by rw [hMask.2]; exact hAudA'.1.le)
          have h1 := h.1; rw [hMask.2, ht5] at h1; exact h1
        have ht6 : ((blkOpenAProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
            = (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 := by
          rw [hAO]; exact hOpenA
        cases hcH : P.checkOpening (liftH G) .h (acc.claims.h ++ [P.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | ok _ => dsimp only [P] at hcA hcH; simp only [hcA, hcH] at hcore; cases hcore
        | error e =>
          have hchkEq : P.checkOpening = checkOpening := by dsimp only [P]; rw [hPeq]; rfl
          rw [hchkEq] at hcH
          obtain ⟨e', he'⟩ := hchkH _ _ e hcH; rw [← ht6] at he'
          rcases checkOpeningFull_startCover Lq hLq key domain hdom shdP_blkOpenGeomH 14 54 36
              (blkOpenAProg tag P k dig pre TB_next TA M TH Dc) (fun c' => (hA' c').1)
              (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 4443 (mPre + 5747) _ (hA' c').2) (by omega) dg)
              (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 5747) _ (hA' c').2)
                (by unfold shdP_blkOpenGeomH at hj; dsimp only at hj; omega) dg)
              collH (by unfold shdP_blkOpenGeomH; dsimp only; omega)
              G c _ hAudH' e' he' with h0 | ⟨j, hj⟩
          · exact ⟨⟨⟨0, by decide⟩, ⟨1, by decide⟩⟩, h0⟩
          · refine ⟨⟨⟨1, by decide⟩, ⟨777 + j.val, by change 777 + j.val < 872; omega⟩⟩, ?_⟩
            change ProtocolClassify.Site.fires shdP_U
              (finApp3 (m₁ := (146 + 1) + 630) (m₂ := (54 + 1) + 36) (m₃ := (2 + 1) + 1) _ _ _ ⟨((146 + 1) + 630) + j.val, by omega⟩) G c
            rw [finApp3_2]; exact hj
  · -- `coreProve = .ok R ∧ bndCheck ... R.t7 = .error eB`
    obtain ⟨hsl, -, -, -, -, -, -, -, hmo, hao, hho⟩ := coreProve_ok (liftH G) P D tFr R hRok
    rw [hLen23] at hsl
    have hAudA' := hAudA R.core.slots R.recs R.acc R.t4 hsl
    have hAudH' := hAudH R.core.slots R.recs R.acc R.t4 hsl
    have hAudB' := hAudB R hRok
    have hEnd : (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc 23 c).final (liftH G) t0 = (R.t4, (x0, R.recs, R.acc)) := by
      rw [blkSlotEndProg, final_famPre (liftH G) (corePf P) (coreDf P Dc) coreBga (hd c) 23 t0 R.core.slots R.recs R.acc R.t4
        (by rw [hF, ← slotsProve_eq_fam, ← hD]; exact hsl), hF]
    have hMask : ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
          = (bMask (liftH G) tag shdP_U shdP_hbij (M c) 23 (R.acc.fs ++ R.acc.hostFs) R.t4).2
        ∧ ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).2.1 = (x0, R.recs, R.acc) := by
      have h := final_bMaskProg (liftH G) tag 23 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
        (blkSlotEndProg tag P k dig pre TB_next TA M TH Dc 23 c) t0
      rw [hEnd] at h; exact h
    have ht5 : ((blkMaskProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1 = R.t5 := by
      have hm2 := congrArg Prod.snd hmo; rw [hMO] at hm2; exact hMask.1.trans hm2.symm
    have hOpenA : ((blkOpenAProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
          = (bOpen (liftH G) tag Exec.R13.r13Prm 16 (TA c) R.acc.claims.a R.t5).2
        ∧ ((blkOpenAProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).2.1.1 = (x0, R.recs, R.acc) := by
      have h := final_bOpenProg (liftH G) tag Exec.R13.r13Prm 16 146 (by norm_num [Exec.R13.r13Prm, PcsPrm.nn])
        (by norm_num [Exec.R13.r13Prm]) (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
        (blkMaskProg tag P k dig pre TB_next TA M TH Dc c) t0 (by rw [hMask.2]; exact hAudA'.1.le)
      rw [hMask.2, ht5] at h
      exact ⟨h.1, (congrArg Prod.fst h.2).trans hMask.2⟩
    have ht6 : ((blkOpenAProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1 = R.t6 := by
      have ha2 := congrArg Prod.snd hao; rw [hAO] at ha2
      exact hOpenA.1.trans ha2.symm
    have hOpenH : ((blkOpenHProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1
        = (bOpen (liftH G) tag Exec.R13.r13Prm 16 (TH c (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1
            (coreA (liftH G) P D tFr).1) (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).2 := by
      have h := final_bOpenProg (liftH G) tag Exec.R13.r13Prm 16 54 (by norm_num [Exec.R13.r13Prm, PcsPrm.nn])
        (by norm_num [Exec.R13.r13Prm])
        (fun y => TH y.1.1.1.1 (coreBga y.1.1.1).1 (coreBga y.1.1.1).2.1 (coreBga y.1.1.1).2.2)
        (fun y => y.1.1.2.2.claims.h ++ [P.logupSumClaim])
        (blkOpenAProg tag P k dig pre TB_next TA M TH Dc c) t0 (by rw [hOpenA.2]; exact hAudH'.1.le)
      have h1 := h.1; rw [hOpenA.2, ht6] at h1; exact h1
    have ht7 : ((blkOpenHProg tag P k dig pre TB_next TA M TH Dc c).final (liftH G) t0).1 = R.t7 := by
      have hh2 := congrArg Prod.snd hho; rw [hHO] at hh2
      exact hOpenH.trans hh2.symm
    obtain ⟨e', he'⟩ := hbnd _ _ eB hBerr; rw [← ht7] at he'
    rcases checkOpeningFull_startCover Lq hLq key domain hdom shdP_bndOpenGeom 14 2 1
        (blkOpenHProg tag P k dig pre TB_next TA M TH Dc) (fun c' => (hH' c').1)
        (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 39 (mPre + 10255) _ (hH' c').2) (by omega) dg)
        (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 10255) _ (hH' c').2)
          (by unfold shdP_bndOpenGeom at hj; dsimp only at hj; omega) dg)
        collB (by unfold shdP_bndOpenGeom; dsimp only; omega)
        G c _ hAudB' e' he' with h0 | ⟨j, hj⟩
    · exact ⟨⟨⟨0, by decide⟩, ⟨2, by decide⟩⟩, h0⟩
    · refine ⟨⟨⟨1, by decide⟩, ⟨868 + j.val, by change 868 + j.val < 872; omega⟩⟩, ?_⟩
      change ProtocolClassify.Site.fires shdP_U
        (finApp3 (m₁ := (146 + 1) + 630) (m₂ := (54 + 1) + 36) (m₃ := (2 + 1) + 1) _ _ _ ⟨((146 + 1) + 630) + ((54 + 1) + 36) + j.val, by omega⟩) G c
      rw [finApp3_3]; exact hj

private theorem coreDataAt_hOpen_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (TH' : Fp2 → Fp2 → Fp2 → Table) (hTH : C.TH = TH') :
    let D := coreDataAt H tag shdP_U shdP_hbij prm depth S P C t
    D.hOpen = bOpen H tag prm depth (TH' (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1) := by
  intro D
  have hbga := bgaOf_core H tag shdP_U shdP_hbij prm depth S P C t
  have h1 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).1
      = (coreB H P D t).1 := congrArg Prod.fst hbga
  have h2 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.1
      = (coreG H P D t).1 := congrArg (fun x => x.2.1) hbga
  have h3 : (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.2
      = (coreA H P D t).1 := congrArg (fun x => x.2.2) hbga
  show bOpen H tag prm depth
      (C.TH (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).1
        (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.1
        (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.2)
    = bOpen H tag prm depth (TH' (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1)
  refine congrArg (bOpen H tag prm depth) ?_
  rw [h1, h2, h3, hTH]

/-- Corollary on `shdP_blkSegP`: whenever `shdP_blkSegP.run` refuses on an owned carry, one of `blkSegSite` fires. -/
theorem shdP_blkSegP_refuse_cover {α St X Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (sgeom : St → ℕ → Exec.Block.SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Exec.Block.Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (W : (HIn → Dig) → St → X → Coins → (k' : ℕ) → ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k')
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 12000 < 2 ^ 64)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (collA : OpenCollFamily Lq Coins 630) (collH : OpenCollFamily Lq Coins 36) (collB : OpenCollFamily Lq Coins 1)
    (G : QB Lq → Dig) (st : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry)
    (hdig : digest st k = dig) (hbr : bRows (k + 1) = 38) (hbl : bLogN (k + 1) = 14)
    (hW : let w := W (liftH G) st x c k
      w.TB_next = TB_next c ∧ w.coreT.TA = TA c ∧ w.coreT.M = M c ∧ w.coreT.TH = TH c ∧ w.coreT.slot = Dc c)
    (hown : cr.root = rootOf (liftH G) tag 16 (W (liftH G) st x c k).TB_prev
      ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 (W (liftH G) st x c k).TB_prev.rows (toZClaim cl))
    (hchkA : ∀ cl t e, checkOpening (liftH G) .a cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t = .error e')
    (hchkH : ∀ cl t e, checkOpening (liftH G) .h cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t = .error e')
    (hbnd : ∀ cl t e, bndCheck st k cl t = .error e →
      ∃ e', checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t = .error e')
    (hAudA : ∀ sps recs acc t4,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W (liftH G) st x c k).coreT tFr
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) →
      OpenAuditOk shdP_blkOpenGeomA 14 146 630 collA G c acc.claims.a)
    (hAudH : ∀ sps recs acc t4,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W (liftH G) st x c k).coreT tFr
      slotsProve (liftH G) P D.slot (coreB (liftH G) P D tFr).1 (coreG (liftH G) P D tFr).1 (coreA (liftH G) P D tFr).1 23 [] 0 {}
        (coreT3 (liftH G) P D tFr) = .ok (sps, recs, acc, t4) →
      OpenAuditOk shdP_blkOpenGeomH 14 54 36 collH G c (acc.claims.h ++ [P.logupSumClaim]))
    (hAudB : ∀ R,
      let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
      let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
      let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W (liftH G) st x c k).coreT tFr
      coreProve (liftH G) P D tFr = .ok R →
      OpenAuditOk shdP_bndOpenGeom 14 2 1 collB G c (cr.pending ++ R.acc.claims.inp))
    (href : (shdP_blkSegP tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp) sgeom check paths digest bRows bLogN
      bndCheck bndOpen W k).run (liftH G) st x c bnd start cr
        ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error ()) :
    ∃ i : SiteIdx blkSegCount,
      (blkSegSite Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig pre mPre hs hsq hmPre
        TB_next TA M TH hrA hrH Dc collA collH collB i).fires shdP_U G c := by
  obtain ⟨hTBn, hTA, hM, hTH, hSl⟩ := hW
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let tFr := ((blkFrameProg k dig (pre c) (rootOfP tag 16 (TB_next c))).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1
  have htFrEq : blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut checkOpening Rp) sgeom check paths digest bRows bLogN bndCheck bndOpen)
      (liftH G) st k (rootOf (liftH G) tag 16 (W (liftH G) st x c k).TB_next)
      ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = tFr := by
    unfold tFr blockFrame d12aBlockProf; dsimp only; rw [hdig, hbr, hbl, hTBn, final_blkFrameProg]
  let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P (W (liftH G) st x c k).coreT tFr
  dsimp only [shdP_blkSegP] at href
  split_ifs at href with hown'
  · rw [htFrEq] at href
    have hdisj : coreProve (liftH G) P D tFr = .error ()
        ∨ ∃ R e, coreProve (liftH G) P D tFr = .ok R ∧ bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 = .error e := by
      cases hcp : coreProve (liftH G) P D tFr with
      | error _ => exact Or.inl rfl
      | ok R =>
        have hcp' : coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
            (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
              (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) (W (liftH G) st x c k).coreT tFr) tFr = .ok R := hcp
        rw [hcp'] at href; dsimp only at href
        cases hbc : bndCheck st k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | error e => exact Or.inr ⟨R, e, rfl, hbc⟩
        | ok _ => rw [hbc] at href; dsimp only at href; cases href
    exact blkSeg_refuse_cover Lq hLq key domain hdom tag ioIn ioOut checkOpening Rp hR k hk dig
      pre mPre hs hsq hmPre TB_next TA M TH hrA hrH Dc collA collH collB G c D cr.pending (bndCheck st k)
      hchkA hchkH hbnd (by dsimp only [D, coreDataAt]; rw [hTA]) (by dsimp only [D, coreDataAt]; rw [hM])
      (fun _ _ _ => by dsimp only [D, coreDataAt]; rw [hTH]) (by dsimp only [D, coreDataAt]; exact hSl)
      (by dsimp only [D, coreDataAt]; rw [hM]) (by dsimp only [D, coreDataAt]; rw [hTA])
      (coreDataAt_hOpen_eq (liftH G) tag Exec.R13.r13Prm 16 23 P (W (liftH G) st x c k).coreT tFr (TH c) hTH)
      hAudA hAudH hAudB (Or.inr hdisj)
  · classical
    rw [decide_eq_true_eq] at hown'
    have hf : False := hown' hown; cases hf

end BlockSegRefusal

/-! ## 5. Stage OUT-C Per-Segment `startSite` Family & `outcSeg_refuse_cover` -/

section StageOutSegRefusal

/-- The 8 `(slot, extRound)` pairs of Stage OUT-C (`ext = 1` on all 8 slots). -/
def outcExtList : List (ℕ × ℕ) :=
  [(0, 12), (1, 12), (2, 1), (3, 12), (4, 12), (5, 12), (6, 12), (7, 12)]

/-- The 23 `(slot, drawIdx)` nonzero-checked draws of Stage OUT-C (`6 + 3 + 11 + 3`). -/
def outcNzList : List (ℕ × ℕ) :=
  (List.range' 1 6).map (fun j => (2, j))
    ++ (List.range' 12 3).map (fun j => (4, j))
    ++ (List.range' 12 11).map (fun j => (5, j))
    ++ (List.range' 12 3).map (fun j => (6, j))

private theorem shdP_outcDraws_eq (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v s : ℕ) :
    outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s =
      match s with | 0 => 12 | 2 => 7 | 4 => 15 | 5 => 23 | 6 => 15 | _ => 0 := by
  rw [rc_outcDraws_verdict]
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  match s with
  | 0 => unfold outcDraws; exact hdb
  | 1 => rfl
  | 2 => rfl
  | 3 => rfl
  | 4 => unfold outcDraws; rw [hllo]; rfl
  | 5 => unfold outcDraws; rw [hldo]; rfl
  | 6 => unfold outcDraws; rw [hltab]; rfl
  | _ + 7 => rfl

private theorem shdP_outcDraws_le_23 (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v s : ℕ) :
    outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s ≤ 23 := by
  rw [shdP_outcDraws_eq]
  match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 => decide | _ + 7 => exact Nat.zero_le _

private theorem shdP_outcSlotShape_eq (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig)
    (bOutRow v s : ℕ) :
    slotShape (shdVo tag Rp wDigest bOutRow v).bp s =
      match s with
      | 0 => (12, 1, 2) | 1 => (12, 1, 4) | 2 => (1, 1, 3) | 3 => (12, 1, 2)
      | 4 => (12, 1, 4) | 5 => (12, 1, 5) | 6 => (12, 1, 3) | 7 => (12, 1, 2) | _ => (0, 0, 0) := by
  have hgs : (shdVo tag Rp wDigest bOutRow v).bp.geom.slots =
      [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)] := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).geomSlots = _
    rw [rc_outcLay_verdict]; exact (shdP_outcLay_nums Rp wDigest).2.2.2
  unfold slotShape; rw [hgs]; match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | _ + 8 => rfl

private theorem shdP_outc_famSqBound_le {Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (x : Coins × List Fp2) (i : ℕ) (hi : i ≤ 8) :
    famSqBound (outcPf (shdVo tag Rp wDigest bOutRow v) x) i 0 ≤ 173 := by
  have hd : ∀ s, (outcPf (shdVo tag Rp wDigest bOutRow v) x s).draws s
      = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s := fun _ => rfl
  have hs : ∀ s, slotN (outcPf (shdVo tag Rp wDigest bOutRow v) x s) s =
      match s with | 0 => 13 | 1 => 13 | 2 => 2 | 3 => 13 | 4 => 13 | 5 => 13 | 6 => 13 | 7 => 13 | _ => 0 := by
    intro s; unfold slotN; change (slotShape (shdVo tag Rp wDigest bOutRow v).bp s).1 + (slotShape _ s).2.1 = _
    rw [shdP_outcSlotShape_eq]; match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | _ + 8 => rfl
  have h8 : famSqBound (outcPf (shdVo tag Rp wDigest bOutRow v) x) 8 0 = 173 := by
    simp only [famSqBound, hd, hs, shdP_outcDraws_eq]
  exact (famSqBound_mono _ hi).trans h8.le

/-- **Stage OUT-C `outcDefine` refusal**: on canonical draws, `outcDefine` refuses ONLY at one of `outcNzList`. -/
theorem shdP_outcDefine_refuses (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (s : ℕ) (hs : s < 8) (hist : Hist) (dr : List Fp2)
    (hlen : dr.length = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s)
    (hcan : ∀ a ∈ dr, a.Canon) (e : String)
    (herr : outcDefine (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow) s hist dr = .error e) :
    ∃ p ∈ outcNzList, p.1 = s ∧ (dr.getD p.2 Fp2.zero).isZero = true := by
  let O := rcVerdict (shdP_outcPub Rp wDigest) v; let G := shdP_outcGeo bOutRow
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : O.llo = 12 := hllo; have hldo' : O.ldo = 12 := hldo; have hltab' : O.ltab = 12 := hltab
  interval_cases s
  · change outcDefIO O G dr = .error e at herr; rw [outcDefIO_ok O G dr] at herr; cases herr
  · change outcDefSS O G = .error e at herr; rw [outcDefSS_ok O G] at herr; cases herr
  · change outcDefTZC O G dr = .error e at herr; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 7 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 7 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 7 1 6, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hj
      exact hno ⟨(2, j.val), by
        refine List.mem_append_left _ (List.mem_append_left _ (List.mem_append_left _ ?_))
        exact List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 1 6 j.val hj.1 hj.2, rfl⟩,
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := outcDefTZC_ok shdP_U shdP_hbij shdP_hU O G rfl y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change outcDefPD O G = .error e at herr; rw [outcDefPD_ok O G] at herr; cases herr
  · change outcDefLZC O G hist dr = .error e at herr; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 15 O.llo 3, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and, hllo'] at hj
      exact hno ⟨(4, j.val), by
        refine List.mem_append_left _ (List.mem_append_left _ (List.mem_append_right _ ?_))
        exact List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 12 3 j.val hj.1 hj.2, rfl⟩,
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := outcDefLZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change outcDefDZC O G hist dr = .error e at herr; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 23 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 23 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 23 O.ldo 11, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and, hldo'] at hj
      exact hno ⟨(5, j.val), by
        refine List.mem_append_left _ (List.mem_append_right _ ?_)
        exact List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 12 11 j.val hj.1 hj.2, rfl⟩,
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := outcDefDZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change outcDefTAB O G hist dr = .error e at herr; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    by_contra hno
    have hZ : ∀ j ∈ Z_range 15 O.ltab 3, y j ≠ 0 := fun j hj hy0 => by
      simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and, hltab'] at hj
      exact hno ⟨(6, j.val), List.mem_append_right _ (List.mem_map.mpr ⟨j.val, mem_range'_of_bounds 12 3 j.val hj.1 hj.2, rfl⟩),
        rfl, (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_getD hcan j.val)).mpr hy0⟩
    have hok := outcDefTAB_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hZ
    rw [hw] at hok; rw [hok] at herr; cases herr
  · change outcDefZS O G = .error e at herr; rw [outcDefZS_ok O G] at herr; cases herr

/-- **Stage OUT-C deterministic slot checks & no-`.out`-claim invariant** for every `s < 8`. -/
theorem shdP_outc_slotChecks_ok (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig)
    (bOutRow v s : ℕ) (hs : s < 8) (hist : Hist) (acc : Acc) (hcs : acc.cs.length = s) (hsc : acc.scalars.length = s)
    (dr : List Fp2) (hlen : dr.length = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s)
    (hcan : ∀ a ∈ dr, a.Canon) (df : SlotDef)
    (hdef : outcDefine (rcVerdict (shdP_outcPub Rp wDigest) v) (shdP_outcGeo bOutRow) s hist dr = .ok df)
    (sel sc : Fp2) (rho terms : List Fp2)
    (hrho : rho.length = (slotShape (shdVo tag Rp wDigest bOutRow v).bp s).1) :
    let P := (shdVo tag Rp wDigest bOutRow v).bp
    slotDefChecks P s acc df = .ok () ∧ (∃ val, hostedSum acc.scalars sc df.hosted = .ok val)
      ∧ (∃ vs, tabVals sel rho terms df.tabs 0 = .ok vs)
      ∧ (∀ tb ∈ df.tabs, match tb with | .priv p => p.cm ≠ .out | _ => True) := by
  intro P
  let O := rcVerdict (shdP_outcPub Rp wDigest) v; let G := shdP_outcGeo bOutRow
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : O.llo = 12 := hllo; have hldo' : O.ldo = 12 := hldo; have hltab' : O.ltab = 12 := hltab
  have hdb' : O.dBits = 12 := hdb; have htb' : O.tBits = 7 := shdP_clog2_128
  have hlift : O.lift = 0 := by unfold OutcPub.lift; omega
  have hbout : O.bOutLog = 19 := by show Nat.log2 (128 * 4096) = 19; exact (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  have haLogEq : (outcLay O G.bLogN).aLog = [1, 1, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12] := by
    show [OutcPub.toLog, OutcPub.toLog, O.llo] ++ List.replicate 12 O.ldo ++ [O.ltab] = _
    rw [hllo', hldo', hltab']; rfl
  have hhLogEq : (outcLay O G.bLogN).hLog = [12, 12, 12, 12, 12, 12, 12, 12, 12] := by
    show [O.llo] ++ List.replicate 6 O.ldo ++ [O.ltab, O.lt] = _
    rw [hllo', hldo', hltab']; rfl
  have hterms : ∀ k, k < 8 → slotTerms P k = ([2, 1, 11, 1, 2, 19, 2, 1] : List ℕ).getD k 0 := fun k hk => by interval_cases k <;> rfl
  have hkind : ∀ k, k < 8 → P.kind k = ([SlotKind.standalone, .priv, .host, .priv, .host, .standalone, .standalone, .standalone]).getD k .priv :=
    fun k hk => by interval_cases k <;> rfl
  interval_cases s
  · change outcDefIO O G dr = .ok df at hdef; rw [outcDefIO_ok O G dr] at hdef; cases hdef
    have hsh0 : slotShape P 0 = (12, 1, 2) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 0
    rw [hsh0] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 0 acc _ hcs (by rw [hterms 0 (by omega)]; rfl) (by rw [hkind 0 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun _ hv => by simp at hv), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h
      · cases h
      · cases h; rw [hsh0]; exact ⟨Nat.zero_lt_one, by simp [fixedC, rhoC, haLogEq, ocC_X, hlift, hdb']⟩
      · cases h; rw [hsh0]; exact ⟨Nat.zero_lt_one, by simp [fixedBits, rhoC, htb', hdb', hbout]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl
      · dsimp only; rw [hdb', hrho, Nat.zero_add]; exact List.length_take_le 12 dr
      · trivial
      · trivial
  · change outcDefSS O G = .ok df at hdef; rw [outcDefSS_ok O G] at hdef; cases hdef
    have hsh1 : slotShape P 1 = (12, 1, 4) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 1
    rw [hsh1] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 1 acc _ hcs (by rw [hterms 1 (by omega)]; rfl) (by rw [hkind 1 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h
      · cases h
      · cases h; rw [hsh1]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h
      · rw [Tab.pub.inj h, hsh1, supp, List.length_map, List.length_range, hldo']
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · simp [supp, hldo', hrho]
      · trivial
  · change outcDefTZC O G dr = .ok df at hdef; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 7 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 7 hlen
    have hne : ∀ j ∈ Z_range 7 1 6, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefTZC_err shdP_U shdP_hbij shdP_hU O G y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefTZC_ok shdP_U shdP_hbij shdP_hU O G rfl y hne
    have hsh2 : slotShape P 2 = (1, 1, 3) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 2
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh2] at hrho; change rho.length = 1 at hrho
    refine ⟨slotDefChecks_ok_of P 2 acc _ hcs
      (by
        rw [hterms 2 (by omega), filter_isPriv_cons_eq, List.filter_append, List.length_append,
          filter_isPriv_cons_pub, filter_isPriv_cons_priv, filter_isPriv_cons_priv, filter_isPriv_map_priv]
        rfl)
      (by rw [hkind 2 (by omega)]; dsimp only [List.isEmpty]; decide)
      (fun p hp => ?_) (fun v hv => ?_),
      hostedSum_ok_of acc.scalars _ sc (fun p hp => by rw [List.mem_singleton] at hp; rw [hp, hsc]; omega),
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => ?_⟩
    · rcases List.mem_cons.mp hp with h | h
      · cases h
      · rcases List.mem_append.mp h with h1 | h2
        · simp only [List.mem_cons, List.not_mem_nil, or_false] at h1
          rcases h1 with h1 | h1 | h1
          · cases h1
          · cases h1; rw [hsh2]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
          · cases h1; rw [hsh2]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
        · obtain ⟨_, _, h2'⟩ := List.mem_map.mp h2; cases h2'; rw [hsh2]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · rcases List.mem_cons.mp hv with h | h
      · cases h
      · rcases List.mem_append.mp h with h1 | h2
        · simp only [List.mem_cons, List.not_mem_nil, or_false] at h1
          rcases h1 with h1 | h1 | h1
          · cases h1; rw [hsh2]; simp [supp, OutcPub.toLog]
          · cases h1
          · cases h1
        · obtain ⟨_, _, h2'⟩ := List.mem_map.mp h2; cases h2'
    · rcases List.mem_cons.mp ht with rfl | h
      · dsimp only; rw [hrho, Nat.zero_add]; exact List.length_take_le 1 dr
      · rcases List.mem_append.mp h with h1 | h2
        · simp only [List.mem_cons, List.not_mem_nil, or_false] at h1
          rcases h1 with rfl | rfl | rfl
          · simp [supp, OutcPub.toLog, hrho]
          · trivial
          · trivial
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h2; trivial
    · rcases List.mem_cons.mp htb with rfl | h
      · trivial
      · rcases List.mem_append.mp h with h1 | h2
        · simp only [List.mem_cons, List.not_mem_nil, or_false] at h1
          rcases h1 with rfl | rfl | rfl <;> (dsimp only <;> decide)
        · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h2; dsimp only; decide
  · change outcDefPD O G = .ok df at hdef; rw [outcDefPD_ok O G] at hdef; cases hdef
    have hsh3 : slotShape P 3 = (12, 1, 2) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 3
    rw [hsh3] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 3 acc _ hcs (by rw [hterms 3 (by omega)]; rfl) (by rw [hkind 3 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h
      · cases h; rw [hsh3]; exact ⟨Nat.zero_lt_one, by simp [fixedC, rhoC, haLogEq, ocC_Y, hlift, hdb']⟩
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h
      · cases h
      · rw [Tab.pub.inj h, hsh3, wTab, List.length_map, List.length_range]; change 4096 = 2 ^ 12; norm_num
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · trivial
      · dsimp only; rw [hrho, wTab, List.length_map, List.length_range]; change 4096 = 2 ^ 12; norm_num
  · change outcDefLZC O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    have hne : ∀ j ∈ Z_range 15 O.llo 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefLZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefLZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    have hsh4 : slotShape P 4 = (12, 1, 4) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 4
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh4] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 4 acc _ hcs (by rw [hterms 4 (by omega)]; rfl) (by rw [hkind 4 (by omega)]; dsimp only [List.isEmpty]; decide)
      (fun p hp => ?_) (fun v hv => ?_),
      hostedSum_ok_of acc.scalars _ sc (fun p hp => by rw [List.mem_singleton] at hp; rw [hp, hsc]; omega),
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl | rfl | rfl | rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h | h | h | h
      · cases h
      · cases h
      · cases h
      · cases h
      · cases h; rw [hsh4]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
      · cases h; rw [hsh4]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h | h | h | h | h
      · cases h
      · rw [Tab.pub.inj h, hsh4, liveTab, List.length_map, List.length_range, hllo']
      · rw [Tab.pub.inj h, hsh4]; unfold gTab; dsimp only; rw [List.length_map, List.length_range, hllo']
      · rw [Tab.pub.inj h, hsh4, supp, List.length_map, List.length_range, hllo']
      · cases h
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl | rfl | rfl | rfl
      · dsimp only; rw [hllo', hrho, Nat.zero_add]; exact List.length_take_le 12 dr
      · simp [liveTab, hllo', hrho]
      · simp [gTab, hllo', hrho]
      · simp [supp, hllo', hrho]
      · trivial
      · trivial
  · change outcDefDZC O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 23 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 23 hlen
    have hne : ∀ j ∈ Z_range 23 O.ldo 11, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefDZC_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefDZC_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    have hsh5 : slotShape P 5 = (12, 1, 5) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 5
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh5] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 5 acc _ hcs
      (by
        dsimp only
        rw [hterms 5 (by omega), filter_isPriv_cons_eq, filter_isPriv_cons_pub,
          List.filter_append, List.filter_append, List.length_append, List.length_append,
          filter_isPriv_map_priv, filter_isPriv_map_priv, filter_isPriv_cons_priv]
        rfl)
      (by rw [hkind 5 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => ?_⟩
    · rcases List.mem_cons.mp hp with h | h
      · cases h
      · rcases List.mem_cons.mp h with h | h
        · cases h
        · rcases List.mem_append.mp h with h1 | h2
          · rcases List.mem_append.mp h1 with h1a | h1b
            · obtain ⟨_, _, h'⟩ := List.mem_map.mp h1a; cases h'; rw [hsh5]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
            · rw [List.mem_singleton] at h1b; cases h1b; rw [hsh5]; exact ⟨Nat.zero_lt_one, by simp [fixedC, haLogEq, ocC_D, OutcPub.toLog]⟩
          · obtain ⟨_, _, h'⟩ := List.mem_map.mp h2; cases h'; rw [hsh5]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · rcases List.mem_cons.mp hv with h | h
      · cases h
      · rcases List.mem_cons.mp h with h | h
        · rw [Tab.pub.inj h, hsh5, supp, List.length_map, List.length_range, hldo']
        · rcases List.mem_append.mp h with h1 | h2
          · rcases List.mem_append.mp h1 with h1a | h1b
            · obtain ⟨_, _, h'⟩ := List.mem_map.mp h1a; cases h'
            · rw [List.mem_singleton] at h1b; cases h1b
          · obtain ⟨_, _, h'⟩ := List.mem_map.mp h2; cases h'
    · rcases List.mem_cons.mp ht with rfl | h
      · dsimp only; rw [hldo', hrho, Nat.zero_add]; exact List.length_take_le 12 dr
      · rcases List.mem_cons.mp h with rfl | h
        · simp [supp, hldo', hrho]
        · rcases List.mem_append.mp h with h1 | h2
          · rcases List.mem_append.mp h1 with h1a | h1b
            · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h1a; trivial
            · rw [List.mem_singleton] at h1b; rw [h1b]; trivial
          · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h2; trivial
    · rcases List.mem_cons.mp htb with rfl | h
      · trivial
      · rcases List.mem_cons.mp h with rfl | h
        · trivial
        · rcases List.mem_append.mp h with h1 | h2
          · rcases List.mem_append.mp h1 with h1a | h1b
            · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h1a; dsimp only; decide
            · rw [List.mem_singleton] at h1b; rw [h1b]; dsimp only; decide
          · obtain ⟨_, _, rfl⟩ := List.mem_map.mp h2; dsimp only; decide
  · change outcDefTAB O G hist dr = .ok df at hdef; rw [shdP_outcDraws_eq] at hlen
    let y : Fin 15 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 15 hlen
    have hne : ∀ j ∈ Z_range 15 O.ltab 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := outcDefTAB_err shdP_U shdP_hbij shdP_hU O G hist y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := outcDefTAB_ok shdP_U shdP_hbij shdP_hU O G hist (by omega) y hne
    have hsh6 : slotShape P 6 = (12, 1, 3) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 6
    rw [hw] at hok; rw [hok] at hdef; cases hdef; rw [hsh6] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 6 acc _ hcs (by rw [hterms 6 (by omega)]; rfl) (by rw [hkind 6 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl | rfl | rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h | h | h | h
      · cases h
      · cases h
      · cases h
      · cases h; rw [hsh6]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
      · cases h; rw [hsh6]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h | h | h | h
      · cases h
      · rw [Tab.pub.inj h, hsh6, supp, List.length_map, List.length_range, hltab']
      · rw [Tab.pub.inj h, hsh6, tvTab, List.length_map, List.length_range, hltab']
      · cases h
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl | rfl | rfl | rfl
      · dsimp only; rw [hltab', hrho, Nat.zero_add]; exact List.length_take_le 12 dr
      · simp [supp, hltab', hrho]
      · simp [tvTab, hltab', hrho]
      · trivial
      · trivial
  · change outcDefZS O G = .ok df at hdef; rw [outcDefZS_ok O G] at hdef; cases hdef
    have hsh7 : slotShape P 7 = (12, 1, 2) := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v 7
    rw [hsh7] at hrho; change rho.length = 12 at hrho
    refine ⟨slotDefChecks_ok_of P 7 acc _ hcs (by rw [hterms 7 (by omega)]; rfl) (by rw [hkind 7 (by omega)]; dsimp only; decide)
      (fun p hp => ?_) (fun v hv => ?_), ⟨sc, rfl⟩,
      tabVals_ok_of_fit sel rho terms _ 0 (fun t ht => ?_), fun tb htb => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at htb
        rcases htb with rfl | rfl <;> (dsimp only <;> decide)⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with h | h
      · cases h
      · cases h; rw [hsh7]; exact ⟨Nat.zero_lt_one, by simp [rhoC]⟩
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at hv
      rcases hv with h | h
      · rw [Tab.pub.inj h, hsh7, List.length_replicate]; exact congrArg (2 ^ ·) (by simp [hhLogEq, ocH_U])
      · cases h
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
      rcases ht with rfl | rfl
      · dsimp only; rw [List.length_replicate, hrho]; exact congrArg (2 ^ ·) (by simp [hhLogEq, ocH_U])
      · trivial

/-- **Stage OUT-C post-slot facts**: `nFunctionals = 14` and `acc.claims.out = []`. -/
theorem shdP_outc_postSlots (H : HIn → Dig) (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (D : SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (b g a : Fp2) (t3 : Tr) (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (h : slotsProve H (shdVo tag Rp wDigest bOutRow v).bp D b g a 8 [] 0 {} t3 = .ok (sps, recs, acc, t4)) :
    (acc.fs ++ acc.hostFs).length = (shdVo tag Rp wDigest bOutRow v).lay.nFunctionals ∧ acc.claims.out = [] := by
  let V := shdVo tag Rp wDigest bOutRow v
  rw [slotsProve_eq_fam] at h
  obtain ⟨-, -, hfs, -⟩ := famProve_inv H (fun _ => V.bp) (fun _ => D) b g a 8 [] 0 {} t3 sps recs acc t4
    (fun _ hr => by cases hr) h
  have hnF : V.lay.nFunctionals = 14 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).nFunctionals = 14
    rw [rc_outcLay_verdict]; exact (shdP_outcLay_nums Rp wDigest).2.2.1
  have hinc14 : famFuncInc (fun _ => V.bp) 8 0 = 14 := rfl
  refine ⟨by rw [hfs, hinc14, hnF]; rfl, ?_⟩
  exact famProve_claims_out_nil H (fun _ => V.bp) (fun _ => D) b g a 8
    (fun s hs hist dr df hlen hcan hdf =>
      (shdP_outc_slotChecks_ok tag Rp wDigest bOutRow v s hs hist
        ⟨List.replicate s Fp2.zero, List.replicate s Fp2.zero, {}, [], []⟩
        (List.length_replicate) (List.length_replicate) dr hlen hcan df hdf Fp2.zero Fp2.zero
        (List.replicate (slotShape V.bp s).1 Fp2.zero) [] (List.length_replicate)).2.2.2)
    8 [] 0 {} t3 sps recs acc t4 le_rfl rfl h

/-- Stage OUT-C `TProg` chain: `outcSlotEndProg` → `outcMaskProg` → `outcOpenAProg` → `outcOpenHProg`. -/
noncomputable def outcSlotEndProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) (i : ℕ) (c : Coins) :
    TProg ((Coins × List Fp2) × List SlotRec × Acc) :=
  let V := shdVo tag Rp wDigest bOutRow v
  famPre (outcPf V) (outcDf V Dc) outcBga
    (outcHeadProg V c (pre c) (rootOfP tag 14 (TA c))
      (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c))) (fun ch => rootOfP tag 14 (TH c ch))) i

noncomputable def outcMaskProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) (c : Coins) :=
  bMaskProg 8 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
    (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc 8 c)

noncomputable def outcOpenAProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) (c : Coins) :=
  bOpenProg ⟨12, 4, 256, 256⟩ 29 (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
    (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c)

noncomputable def outcOpenHProg {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v : ℕ) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp) (c : Coins) :=
  let V := shdVo tag Rp wDigest bOutRow v
  bOpenProg ⟨12, 4, 256, 256⟩ 10 (fun y => TH y.1.1.1.1 y.1.1.1.2)
    (fun y => y.1.1.2.2.claims.h ++ [V.lay.logupSumClaim])
    (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c)

private theorem outcSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 8) (c : Coins) :
    TProg.Sep key (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c)
      ∧ SqLE (mPre + 175) (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c) := by
  let V := shdVo tag Rp wDigest bOutRow v
  exact ⟨sep_famPre _ _ _ key _ (sep_outcHeadProg V key c (pre c) _ _ _ (hs c)) i,
    sqLE_mono _ ((mPre + 2) + 173) (mPre + 175)
      (sqLE_famPre (outcPf V) (outcDf V Dc) outcBga _ i (mPre + 2) 173
        (sqLE_outcHeadProg V c (pre c) _ _ _ mPre (hsq c))
        (fun x => shdP_outc_famSqBound_le tag Rp wDigest bOutRow v x i hi)) (by omega)⟩

private theorem outcMaskProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 258) (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c) :=
  let hS := outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq 8 le_rfl c
  ⟨sep_bMaskProg key 8 _ _ _ hS.1,
   sqLE_mono _ _ (mPre + 258) (sqLE_bMaskProg 8 (mPre + 175) _ _ _ hS.2) (by norm_num [mQ])⟩

private theorem outcOpenAProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 427) (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c) :=
  let hM := outcMaskProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq c
  ⟨sep_bOpenProg key _ 29 _ _ _ hM.1,
   sqLE_mono _ _ (mPre + 427)
     (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 29 76 (mPre + 258) _ _ _ hM.2 (fun y => hrA y.1.1.1)) (by dsimp only; omega)⟩

private theorem outcOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 38)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 539) (outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c) :=
  let hA := outcOpenAProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH hrA Dc hs hsq c
  ⟨sep_bOpenProg key _ 10 _ _ _ hA.1,
   sqLE_mono _ _ (mPre + 539)
     (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 10 38 (mPre + 427) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 y.1.1.1.2)) (by dsimp only; omega)⟩

/-- **Concrete Stage OUT-C per-segment `startSite` family** (`SiteIdx outcSegCount`, `3/175/8/8/23/1/0`). -/
noncomputable def outcSegSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 38)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (collA : OpenCollFamily Lq Coins 120) (collH : OpenCollFamily Lq Coins 10) (collB : OpenCollFamily Lq Coins 1) :
    SiteIdx outcSegCount → ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  let V := shdVo tag Rp wDigest bOutRow v
  let preS := outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc
  let preM := outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc
  let preA := outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc
  let preH := outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc
  let hS := fun i (hi : i ≤ 8) c => outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq i hi c
  let hM := fun c => outcMaskProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq c
  let hA := fun c => outcOpenAProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH hrA Dc hs hsq c
  let hH := fun c => outcOpenHProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH hrA hrH Dc hs hsq c
  fun ⟨kind, idx⟩ =>
    match kind, idx with
    | ⟨0, _⟩, ⟨0, _⟩ => openDepStartSite Lq hLq key domain hdom 29 74 preM (fun c => (hM c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 104 (mPre + 258) (preM c) (hM c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨1, _⟩ => openDepStartSite Lq hLq key domain hdom 10 36 preA (fun c => (hA c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 47 (mPre + 427) (preA c) (hA c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨2, _⟩ => openDepStartSite Lq hLq key domain hdom 2 36 preH (fun c => (hH c).1)
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg 39 (mPre + 539) (preH c) (hH c).2) (by omega) dg)
    | ⟨0, _⟩, ⟨n + 3, h⟩ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
    | ⟨1, _⟩, idx =>
      finApp3
        (openK1Site Lq hLq key domain hdom 29 74 120 preM (fun c => (hM c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 258) (preM c) (hM c).2) (by omega) dg) collA)
        (openK1Site Lq hLq key domain hdom 10 36 10 preA (fun c => (hA c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 427) (preA c) (hA c).2) (by omega) dg) collH)
        (openK1Site Lq hLq key domain hdom 2 36 1 preH (fun c => (hH c).1)
          (fun j hj c dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 539) (preH c) (hH c).2) (by omega) dg) collB) idx
    | ⟨2, _⟩, idx =>
      depCStartSite Lq hLq key domain hdom (outcPf V) (preS idx.val) idx.val
        (fun c => (hS idx.val (Nat.le_of_lt idx.isLt) c).1)
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depCProg (outcPf V) (preS idx.val c) idx.val (mPre + 175) 23 (hS idx.val (Nat.le_of_lt idx.isLt) c).2
            (fun _ => shdP_outcDraws_le_23 Rp wDigest v idx.val))
          (by omega) dg)
    | ⟨3, _⟩, idx =>
      listPairSite outcExtList (fun s r =>
        if h8 : s < 8 then
          depEStartSite Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga (preS s) s (min r 15)
            (fun c => (hS s (Nat.le_of_lt h8) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_depEProg (outcPf V) (outcDf V Dc) outcBga (preS s c) s (min r 15) (mPre + 175) 23 (hS s (Nat.le_of_lt h8) c).2
                (fun _ => shdP_outcDraws_le_23 Rp wDigest v s))
              (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨4, _⟩, idx =>
      listPairSite outcNzList (fun s j =>
        if h8 : s < 8 then
          drawZeroStartSite Lq hLq key domain hdom (min j 23) (preS s)
            (fun c => (hS s (Nat.le_of_lt h8) c).1)
            (fun c dg => noWrap_start_of_sqLE
              (sqLE_drawProg (min j 23) (mPre + 175) (preS s c) (hS s (Nat.le_of_lt h8) c).2) (by omega) dg)
        else shdP_emptySite Lq) idx
    | ⟨5, _⟩, _ =>
      shdP_outcAlphaStartSite Lq hLq key domain hdom V pre
        (fun c => rootOfP tag 14 (TA c)) (fun c => rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c))) hs
        (fun c dg => noWrap_start_of_sqLE (sqLE_outcAlphaProg V (pre c) _ _ mPre (hsq c)) (by omega) dg)
    | ⟨6, _⟩, idx => by have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
    | ⟨k + 7, h⟩, _ => by have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k) h; cases hf

theorem outcSegSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 38)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (collA : OpenCollFamily Lq Coins 120) (collH : OpenCollFamily Lq Coins 10) (collB : OpenCollFamily Lq Coins 1)
    (i : SiteIdx outcSegCount) :
    (outcSegSite Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH hrA hrH Dc collA collH collB i).k
      ≤ kPer gP (2 ^ 17) (2 ^ 20) i.1
    ∧ (outcSegSite Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre TA M TH hrA hrH Dc collA collH collB i).δ = 0 := by
  rcases i with ⟨kind, idx⟩
  match kind, idx with
  | ⟨0, _⟩, ⟨0, _⟩ | ⟨0, _⟩, ⟨1, _⟩ | ⟨0, _⟩, ⟨2, _⟩ => exact ⟨le_rfl, rfl⟩
  | ⟨0, _⟩, ⟨n + 3, h⟩ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 3 n) h; cases hf
  | ⟨1, _⟩, idx =>
    exact finApp3_prop _ _ _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 29 74 120 _ _ _ collA j)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 10 36 10 _ _ _ collH j)
      (fun j => openK1Site_k_delta Lq hLq key domain hdom 2 36 1 _ _ _ collB j) idx
  | ⟨2, _⟩, _ => exact ⟨le_rfl, rfl⟩
  | ⟨3, _⟩, idx =>
    exact listPairSite_prop outcExtList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 2 ∧ s.δ = 0) (fun s _ => by
      by_cases h8 : s < 8
      · rw [dite_eq_left h8]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h8]; exact ⟨by change 0 ≤ 2; omega, rfl⟩) idx
  | ⟨4, _⟩, idx =>
    exact listPairSite_prop outcNzList _ (fun (s : ProtocolClassify.Site (QB Lq) Coins shdP_K) => s.k ≤ 1 ∧ s.δ = 0) (fun s _ => by
      by_cases h8 : s < 8
      · rw [dite_eq_left h8]; exact ⟨le_rfl, rfl⟩
      · rw [dite_eq_right h8]; exact ⟨by change 0 ≤ 1; omega, rfl⟩) idx
  | ⟨5, _⟩, _ => exact ⟨by change 256 ≤ 2 ^ 17; norm_num, rfl⟩
  | ⟨6, _⟩, idx => have hf : False := Nat.not_lt_zero idx.val idx.isLt; cases hf
  | ⟨k + 7, h⟩, _ => have hf : False := Nat.not_lt.mpr (Nat.le_add_left 7 k) h; cases hf

/-- **Stage OUT-C per-segment refusal cover**: whenever `outcProve` refuses on `shdVo v` with an owned carry,
one of the `outcSegCount` (`3/175/8/8/23/1/0`) `startSite`s in `outcSegSite` fires. -/
theorem outcSeg_refuse_cover {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 38)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (collA : OpenCollFamily Lq Coins 120) (collH : OpenCollFamily Lq Coins 10) (collB : OpenCollFamily Lq Coins 1)
    (G : QB Lq → Dig) (c : Coins) (D : OutcData (shdVo tag Rp wDigest bOutRow v)) (cr : Carry)
    (hown : D.own cr = true)
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (hMO : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij (M c) 8)
    (hAO : D.aOpen = bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TA c))
    (hHO : D.hOpen = bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14
      (TH c (outcCh (liftH G) (shdVo tag Rp wDigest bOutRow v) D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1))
    (hAudA : ∀ sps recs acc t4,
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4) →
      OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ 12 29 120 collA G c acc.claims.a)
    (hAudH : ∀ sps recs acc t4,
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4) →
      OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ 12 10 10 collH G c (acc.claims.h ++ [V.lay.logupSumClaim]))
    (hAudB : ∀ sps recs acc t4,
      let V := shdVo tag Rp wDigest bOutRow v
      let ch := (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      slotsProve (liftH G) V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 8 [] 0 {}
        (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols)
        = .ok (sps, recs, acc, t4) →
      OpenAuditOk shdP_bndOpenGeom 14 2 1 collB G c (cr.pending ++ acc.claims.inp))
    (href : outcProve (liftH G) (shdVo tag Rp wDigest bOutRow v) D cr
      ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1 = .error ()) :
    ∃ i : SiteIdx outcSegCount,
      (outcSegSite Lq hLq key domain hdom tag Rp wDigest bOutRow v pre mPre hs hsq hmPre
        TA M TH hrA hrH Dc collA collH collB i).fires shdP_U G c := by
  let V := shdVo tag Rp wDigest bOutRow v
  let t0 := Tr.newKeyed (liftH G) domain key
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (outcCh (liftH G) V D tStart).1
  let hd := fun c' => outcHeadProg V c' (pre c') (rootOfP tag 14 (TA c'))
    (rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))
  have hF : (hd c).final (liftH G) t0
      = (absorbRoot (liftH G) (outcCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols, (c, ch)) := by
    rw [final_outcHeadProg]; dsimp only [tStart, ch]; unfold outcCh; rw [hA, hM, hH]
  have hS := fun i (hi : i ≤ 8) c' => outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq i hi c'
  unfold outcProve at href
  rw [ite_eq_right (by rw [hown]; decide)] at href
  split_ifs at href with hbad
  · refine ⟨⟨⟨5, by decide⟩, ⟨0, by decide⟩⟩, ?_⟩
    exact shdP_outcAlphaBad_cover Lq hLq key domain hdom V pre
      (fun c' => rootOfP tag 14 (TA c')) (fun c' => rootOfP tag 12 (mTab 8 (cosetPt (rootFp 12)) (M c'))) hs
      (fun c' dg => noWrap_start_of_sqLE (sqLE_outcAlphaProg V (pre c') _ _ mPre (hsq c')) (by omega) dg)
      G c D hA hM hbad
  · split at href
    · rename_i e he; cases e; rw [slotsProve_eq_fam, hD] at he
      have hrB : ∀ i, i < 8 → slotN (outcPf V (c, ch) i) i ≤ 15 := fun i hi => by
        have hsh := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v i
        change (slotShape (shdVo tag Rp wDigest bOutRow v).bp i).1 + (slotShape (shdVo tag Rp wDigest bOutRow v).bp i).2.1 ≤ 15
        rw [hsh]; interval_cases i <;> decide
      obtain ⟨i, hi, ti, recs, acc, hY, hcs, hsc, _, hcase⟩ :=
        fam_startCover_ext Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga hd
          (fun c' => sep_outcHeadProg V key c' (pre c') _ _ _ (hs c')) 8 15
          (fun i hi c' dg => noWrap_start_of_sqLE
            (sqLE_depCProg (outcPf V) (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c') i (mPre + 175) 23
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => shdP_outcDraws_le_23 Rp wDigest v i))
            (by omega) dg)
          (fun i hi m hm c' dg => noWrap_start_of_sqLE
            (sqLE_depEProg (outcPf V) (outcDf V Dc) outcBga (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c') i m (mPre + 175) 23
              (hS i (Nat.le_of_lt hi) c').2
              (fun _ => shdP_outcDraws_le_23 Rp wDigest v i))
            (by omega) dg) G c (c, ch) _ hrB hF he
      rcases hcase with ⟨e', hdefErr⟩ | hC | ⟨j, hm, hE⟩ | ⟨df, hdf, hdet⟩
      · obtain ⟨p, hpMem, hp1, hp0⟩ := shdP_outcDefine_refuses Rp wDigest bOutRow v i hi _ _
          (chalVec_length (liftH G) _ _) (chalVec_canon (liftH G) _ _) e' hdefErr
        have hp2Lt : p.2 < outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) i := by
          rw [shdP_outcDraws_eq, ← hp1]
          exact (show ∀ q ∈ outcNzList, q.2 < (match q.1 with | 0 => 12 | 2 => 7 | 4 => 15 | 5 => 23 | 6 => 15 | _ => 0) by decide) p hpMem
        have hp2Le : p.2 ≤ 23 := (show ∀ q ∈ outcNzList, q.2 ≤ 23 by decide) p hpMem
        have hfire : (drawZeroStartSite Lq hLq key domain hdom (min p.2 23)
            (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i)
            (fun c' => (hS i (Nat.le_of_lt hi) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg (min p.2 23) (mPre + 175) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)).fires shdP_U G c := by
          rw [drawZeroStartSite_fires_congr Lq hLq key domain hdom (min p.2 23) p.2 (Nat.min_eq_left hp2Le) _ _
            (fun c' => (hS i (Nat.le_of_lt hi) c').1) _
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg p.2 (mPre + 175) _ (hS i (Nat.le_of_lt hi) c').2) (by omega) dg)]
          rw [drawZeroStartSite_fires_at Lq hLq key domain hdom (outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) i) p.2 hp2Lt]
          change ((((outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c).final (liftH G) t0).1.challengeFp2Vec (liftH G) _).1.getD p.2 Fp2.zero).isZero = true
          rw [show (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c).final (liftH G) t0 = (ti, ((c, ch), recs, acc)) from hY]
          exact hp0
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem outcNzList
          (fun s j => if h8 : s < 8 then drawZeroStartSite Lq hLq key domain hdom (min j 23)
            (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc s) (fun c' => (hS s (Nat.le_of_lt h8) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg (min j 23) (mPre + 175) _ (hS s (Nat.le_of_lt h8) c').2) (by omega) dg)
            else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) p.1 p.2 hpMem (by rw [hp1, dite_eq_left hi]; exact hfire)
        exact ⟨⟨⟨4, by norm_num⟩, idx⟩, hidx⟩
      · refine ⟨⟨⟨2, by norm_num⟩, ⟨i, hi⟩⟩, ?_⟩
        exact (depCStartSite_fires_irrel Lq hLq key domain hdom (outcPf V)
          (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i) i
          _ (fun c' => (hS i (Nat.le_of_lt hi) c').1) _ _ G c).mp hC
      · have hshape := shdP_outcSlotShape_eq tag Rp wDigest bOutRow v i
        have hj0 : j.val = 0 := by
          have hlt : j.val < (match i with
              | 0 => (12, 1, 2) | 1 => (12, 1, 4) | 2 => (1, 1, 3) | 3 => (12, 1, 2)
              | 4 => (12, 1, 4) | 5 => (12, 1, 5) | 6 => (12, 1, 3) | 7 => (12, 1, 2) | _ => (0, 0, 0)).2.1 :=
            lt_of_lt_of_eq j.isLt (congrArg (fun x => x.2.1) hshape)
          have hlt1 : j.val < 1 := by interval_cases i <;> exact hlt
          omega
        let r := (slotShape V.bp i).1 + j.val
        have hrEq : r = (match i with
            | 0 => (12, 1, 2) | 1 => (12, 1, 4) | 2 => (1, 1, 3) | 3 => (12, 1, 2)
            | 4 => (12, 1, 4) | 5 => (12, 1, 5) | 6 => (12, 1, 3) | 7 => (12, 1, 2) | _ => (0, 0, 0)).1 := by
          calc r = (slotShape (shdVo tag Rp wDigest bOutRow v).bp i).1 + 0 := congrArg _ hj0
            _ = (slotShape (shdVo tag Rp wDigest bOutRow v).bp i).1 := Nat.add_zero _
            _ = _ := congrArg Prod.fst hshape
        have hmem : (i, r) ∈ outcExtList := by
          rw [hrEq]
          exact (show ∀ k : Fin 8, (k.val, (match k.val with
            | 0 => (12, 1, 2) | 1 => (12, 1, 4) | 2 => (1, 1, 3) | 3 => (12, 1, 2)
            | 4 => (12, 1, 4) | 5 => (12, 1, 5) | 6 => (12, 1, 3) | 7 => (12, 1, 2) | _ => (0, 0, 0)).1) ∈ outcExtList by
            decide) ⟨i, hi⟩
        have hrLe : r ≤ 15 := Nat.le_of_lt hm
        obtain ⟨idx, hidx⟩ := listPairSite_of_mem outcExtList
          (fun s r' => if h8 : s < 8 then depEStartSite Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga
            (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc s) s (min r' 15)
            (fun c' => (hS s (Nat.le_of_lt h8) c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_depEProg (outcPf V) (outcDf V Dc) outcBga _ s (min r' 15) (mPre + 175) 23
              (hS s (Nat.le_of_lt h8) c').2 (fun _ => shdP_outcDraws_le_23 Rp wDigest v s))
              (by omega) dg) else shdP_emptySite Lq)
          (fun site => site.fires shdP_U G c) i r hmem (by
            rw [dite_eq_left hi]
            exact (depEStartSite_fires_congr Lq hLq key domain hdom (outcPf V) (outcDf V Dc) outcBga _ i r (min r 15)
              (Nat.min_eq_left hrLe).symm _ _ _ _ G c).mp hE)
        exact ⟨⟨⟨3, by norm_num⟩, idx⟩, hidx⟩
      · let histI := histOf (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 recs
        let drI := (ti.challengeFp2Vec (liftH G) (V.bp.draws i)).1
        let rhoAll := slotRho (liftH G) V.bp (Dc c) i histI acc ti df
        let selI := Block.oneMinusProd (rhoAll.drop (slotShape V.bp i).1)
        let scI := (slotSP (liftH G) V.bp (Dc c) i histI acc ti df).scalar
        let rhoI := rhoAll.take (slotShape V.bp i).1
        let termsI := (slotSP (liftH G) V.bp (Dc c) i histI acc ti df).terms
        have hrhoLen : rhoI.length = (slotShape V.bp i).1 := by
          dsimp only [rhoI, rhoAll]; rw [List.length_take, slotRho_length]; unfold slotN; exact Nat.min_eq_left (by omega)
        obtain ⟨hchk, ⟨_, hval⟩, ⟨_, hvs⟩, -⟩ := shdP_outc_slotChecks_ok tag Rp wDigest bOutRow v i hi histI acc hcs hsc drI
          (chalVec_length (liftH G) _ _) (chalVec_canon (liftH G) _ _) df hdf selI scI rhoI termsI hrhoLen
        rcases hdet with ⟨_, he1⟩ | ⟨_, he2⟩ | ⟨_, he3⟩
        · have hf : (Except.ok () : Except String Unit) = .error _ := hchk.symm.trans he1; cases hf
        · have hf : (Except.ok _ : Except String Fp2) = .error _ := hval.symm.trans he2; cases hf
        · have hf : (Except.ok _ : Except String (List Fp2)) = .error _ := hvs.symm.trans he3; cases hf
    · rename_i sps recs acc t4 hsl
      have hPost := shdP_outc_postSlots (liftH G) tag Rp wDigest bOutRow v D.slot _ _ _ _ sps recs acc t4 hsl
      rw [ite_eq_right (not_not.mpr hPost.1), ite_eq_right (not_not.mpr hPost.2)] at href
      have hEnd : (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc 8 c).final (liftH G) t0 = (t4, ((c, ch), recs, acc)) := by
        rw [outcSlotEndProg, final_famPre (liftH G) (outcPf V) (outcDf V Dc) outcBga (hd c) 8 t0 sps recs acc t4
          (by rw [hF, ← slotsProve_eq_fam, ← hD]; exact hsl), hF]
      have hMask : ((outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
            = (bMask (liftH G) tag shdP_U shdP_hbij (M c) 8 (acc.fs ++ acc.hostFs) t4).2
          ∧ ((outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).2.1 = ((c, ch), recs, acc) := by
        have h := final_bMaskProg (liftH G) tag 8 (fun y => M y.1.1) (fun y => y.2.2.fs ++ y.2.2.hostFs)
          (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc 8 c) t0
        rw [hEnd] at h; exact h
      have ht5 : ((outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
          = (D.mOpen (acc.fs ++ acc.hostFs) t4).2 := by rw [hMO]; exact hMask.1
      have haRows : V.lay.aRows = 76 := by
        change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aRows = 76
        rw [rc_outcLay_verdict]; exact (shdP_outcLay_nums Rp wDigest).1
      have hhRows : V.lay.hRows = 38 := by
        change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hRows = 38
        rw [rc_outcLay_verdict]; exact (shdP_outcLay_nums Rp wDigest).2.1
      have haProx : V.lay.aProx = 74 := by unfold Lay.aRows at haRows; omega
      have hhProx : V.lay.hProx = 36 := by unfold Lay.hRows at hhRows; omega
      have hM' := fun c' => outcMaskProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq c'
      have hA' := fun c' => outcOpenAProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH hrA Dc hs hsq c'
      have hH' := fun c' => outcOpenHProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH hrA hrH Dc hs hsq c'
      have hAudA' := hAudA sps recs acc t4 hsl
      have hAudH' := hAudH sps recs acc t4 hsl
      have hAudB' := hAudB sps recs acc t4 hsl
      cases hcA : V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e =>
        change checkOpeningExec (liftH G) ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ 12 acc.claims.a _ = .error e at hcA
        rw [← ht5, haRows, haProx] at hcA; rw [haRows, haProx] at hAudA'
        rcases checkOpeningFull_startCover Lq hLq key domain hdom ⟨76, V.lay.aSiteRows, none, 74, outcAGroups⟩ 12 29 120
            (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc) (fun c' => (hM' c').1)
            (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 104 (mPre + 258) _ (hM' c').2) (by omega) dg)
            (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 258) _ (hM' c').2) (by dsimp only at hj; omega) dg)
            collA (by dsimp only; omega) G c acc.claims.a hAudA' e hcA with h0 | ⟨j, hj⟩
        · exact ⟨⟨⟨0, by decide⟩, ⟨0, by decide⟩⟩, h0⟩
        · refine ⟨⟨⟨1, by decide⟩, ⟨j.val, by change j.val < 175; omega⟩⟩, ?_⟩
          change ProtocolClassify.Site.fires shdP_U
            (finApp3 (m₁ := (29 + 1) + 120) (m₂ := (10 + 1) + 10) (m₃ := (2 + 1) + 1) _ _ _ ⟨j.val, by omega⟩) G c
          rw [finApp3_1]; exact hj
      | ok _ =>
        have hOpenA : ((outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
              = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TA c) acc.claims.a
                  (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2
            ∧ ((outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).2.1.1 = ((c, ch), recs, acc) := by
          have h := final_bOpenProg (liftH G) tag ⟨12, 4, 256, 256⟩ 14 29 (by norm_num [PcsPrm.nn]) (by norm_num)
            (fun y => TA y.1.1.1) (fun y => y.1.2.2.claims.a)
            (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c) t0 (by rw [hMask.2]; exact hAudA'.1.le)
          rw [hMask.2, ht5] at h
          exact ⟨h.1, (congrArg Prod.fst h.2).trans hMask.2⟩
        have ht6 : ((outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
            = (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 := by
          rw [hAO]; exact hOpenA.1
        cases hcH : V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | error e =>
          change checkOpeningExec (liftH G) ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ 12 _ _ = .error e at hcH
          rw [← ht6, hhRows, hhProx] at hcH; rw [hhRows, hhProx] at hAudH'
          rcases checkOpeningFull_startCover Lq hLq key domain hdom ⟨38, V.lay.hSiteRows, some V.lay.hURows, 36, outcHGroups⟩ 12 10 10
              (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc) (fun c' => (hA' c').1)
              (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 47 (mPre + 427) _ (hA' c').2) (by omega) dg)
              (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 427) _ (hA' c').2) (by dsimp only at hj; omega) dg)
              collH (by dsimp only; omega) G c _ hAudH' e hcH with h0 | ⟨j, hj⟩
          · exact ⟨⟨⟨0, by decide⟩, ⟨1, by decide⟩⟩, h0⟩
          · refine ⟨⟨⟨1, by decide⟩, ⟨150 + j.val, by change 150 + j.val < 175; omega⟩⟩, ?_⟩
            change ProtocolClassify.Site.fires shdP_U
              (finApp3 (m₁ := (29 + 1) + 120) (m₂ := (10 + 1) + 10) (m₃ := (2 + 1) + 1) _ _ _ ⟨((29 + 1) + 120) + j.val, by omega⟩) G c
            rw [finApp3_2]; exact hj
        | ok _ =>
          have hOpenH : ((outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
              = (bOpen (liftH G) tag ⟨12, 4, 256, 256⟩ 14 (TH c ch) (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 := by
            have h := final_bOpenProg (liftH G) tag ⟨12, 4, 256, 256⟩ 14 10 (by norm_num [PcsPrm.nn]) (by norm_num)
              (fun y => TH y.1.1.1.1 y.1.1.1.2) (fun y => y.1.1.2.2.claims.h ++ [V.lay.logupSumClaim])
              (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c) t0 (by rw [hOpenA.2]; exact hAudH'.1.le)
            have h1 := h.1; rw [hOpenA.2, ht6] at h1; exact h1
          have ht7 : ((outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c).final (liftH G) t0).1
              = (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 := by
            rw [hHO]; exact hOpenH
          cases hcB : V.bCheck (liftH G) (cr.pending ++ acc.claims.inp)
              (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
          | ok _ => dsimp only [V] at hcA hcH hcB; simp only [hcA, hcH, hcB] at href; cases href
          | error e =>
            change checkOpeningExec (liftH G) shdP_bndOpenGeom 14 (cr.pending ++ acc.claims.inp) _ = .error e at hcB
            rw [← ht7] at hcB
            rcases checkOpeningFull_startCover Lq hLq key domain hdom shdP_bndOpenGeom 14 2 1
                (outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc) (fun c' => (hH' c').1)
                (fun c' dg => noWrap_start_of_sqLE (sqLE_drawProg 39 (mPre + 539) _ (hH' c').2) (by omega) dg)
                (fun j hj c' dg => noWrap_start_of_sqLE (sqLE_drawProg j (mPre + 539) _ (hH' c').2)
                  (by unfold shdP_bndOpenGeom at hj; dsimp only at hj; omega) dg)
                collB (by unfold shdP_bndOpenGeom; dsimp only; omega)
                G c _ hAudB' e hcB with h0 | ⟨j, hj⟩
            · exact ⟨⟨⟨0, by decide⟩, ⟨2, by decide⟩⟩, h0⟩
            · refine ⟨⟨⟨1, by decide⟩, ⟨171 + j.val, by change 171 + j.val < 175; omega⟩⟩, ?_⟩
              change ProtocolClassify.Site.fires shdP_U
                (finApp3 (m₁ := (29 + 1) + 120) (m₂ := (10 + 1) + 10) (m₃ := (2 + 1) + 1) _ _ _ ⟨((29 + 1) + 120) + ((10 + 1) + 10) + j.val, by omega⟩) G c
              rw [finApp3_3]; exact hj

end StageOutSegRefusal

end ZK60.HonestShield
