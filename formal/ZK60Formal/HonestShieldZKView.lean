/-
D63 lane L68c, part 3c (`HonestShieldZKView.lean`):
1. **28-Segment Honest-View Law Composition (`ShdViewCoins`, `shdL1_law_eq`, `shdL2_cond_law_eq`,
   `shdP_twoLevel_law_eq`, `shdP_twoLevel_hHV`)**:
   - Factors the Shieldstral T128 R13 view coins `ShdViewCoins` into Level 1 (`ShdL1Coins` / `Ω₁`: all 84 PCS
     tables' polynomial coins + leaf salts across `TE`, `B_0..26`, `A_0..27`, `H_0..27`) and Level 2
     (`ShdL2Coins` / `Ω₂`: all 28 segments' sumcheck CFS mask coins + `M` polynomial coins + `M` leaf salts).
   - Proves Level-1 joint law independence across all 84 PCS openings (`pcsStd_law_eq`, `pcsAH_law_eq`, `shdL1_law_eq`)
     by composing `Hiding.openingView_law_eq`, `ZKLinks.openingsAH_law_eq`, `ZKLinks.law_eq_pi`, and `ZKW16.law_eq_prod`.
   - Proves Level-2 conditional joint law independence across all 28 segments given any fixed Level-1 opening view
     (`shdSeg_hhosted`, `honest_seg_cond_law_eq`, `shdL2_cond_law_eq`), composing `ZKLinks.law_eq_pi` over `Fin 28`
     with `ZKHonest.honest_block_view_law_eq` using `HonestShieldZKBase.inc_hhosted`, `ZKHonest.w16_hhosted`, and
     `HonestShieldZKBase.outc_hhosted`.
   - Combines Level 1 and Level 2 via `HonestShieldZKBase.twoLevel_law_eq` (`twoLevel_law_eq_of_cond`,
     `shdP_twoLevel_law_eq`) and lifts via `ZKHonest.hHV_rel_of_view` (`shdP_twoLevel_hHV`)
     matching the exact `hHV` signature of `RunShieldOpenShell.classifyP_zk_of_prog_model`.
2. **Explicit Named Computational Assumption for Native OS-Seeded RNG Transfer (`withExpandedCoins`,
   `NativeOsRngIndist`, `shdP_nativeOsRng_zk`, `shdP_nativeOsRng_zkL`)**:
   - States multi-instance RO-aided indistinguishability of deterministic OS-seed expansion `expand : Dig → IdealCoins`
     from uniform `IdealCoins` as an explicit named `Prop` hypothesis (`NativeOsRngIndist`) matching
     `ZeroKnowledge` / `ZeroKnowledgeL`'s exact `OC` distinguisher type.
   - Proves `shdP_nativeOsRng_zk` and `shdP_nativeOsRng_zkL` (plus `classifyProtocolP` / `classifyProtocolUP`
     pullback bridges) by exact `ℝ≥0∞` triangle inequality.

Uses only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`).
-/
import ZK60Formal.HonestShieldZKBase

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest ZK60.HonestClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec (QB Dig HIn Tr liftH PlaneCommit)
open ZK60.Exec.Block (posTag)
open ZK60.Exec.Slot.W16R2 (Kind kindOf nSlots)
open ZK60.ProtocolClassify (shdP_K shdP_U shdP_hU ClsStmt ClsReceipt RunV RunP SegP Carry
  proveSegs honestSegs runProve honestRoot)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.ProtocolClassify.RunShapeP (classifyProtocolP classifyProtocolUP)

/-! ## 1. Shieldstral field facts & unified 28-segment slot-schedule hand-off -/

section FieldAndSchedule

/-- `[shdP_K : GF] = 2`. -/
theorem shdP_finrank : Module.finrank GF shdP_K = 2 :=
  (ZK60.Hiding.adjoinRoot_finrank Exec.seven_not_square).1

/-- `shdP_U ∉ GF` (`7` is not a square in `GF`). -/
theorem shdP_U_not_mem_range : shdP_U ∉ Set.range (algebraMap GF shdP_K) :=
  ZK60.Hiding.not_mem_range_of_sq shdP_hU Exec.seven_not_square

/-- `2 ≠ 0` in `shdP_K`. -/
theorem shdP_two_ne_zero : (2 : shdP_K) ≠ 0 := ZK60.Exec.two_ne_zero_K (K := shdP_K)

/-- Any degree `< gP` lies strictly below `ringChar shdP_K`. -/
theorem shdP_lt_ringChar {d : ℕ} (hd : d < gP) : d < ringChar shdP_K := by
  rw [ZK60.Exec.ringChar_eq_gP (K := shdP_K)]; exact hd

/-- Host-slot coefficients across the 28-segment Shieldstral run (`νBlk` for the 26 R13 blocks,
`(νOut₂, νOut₄)` for Stage OUT-C; Stage IN-C has no host slots). -/
structure ShdHostCoeffs (K : Type) where
  νBlk : Fin 26 → Fin nSlots → ℕ → K
  νOut₂ : K
  νOut₄ : K

/-- Number of sumcheck slots per segment (`0 ↦ 4` Stage IN-C, `1..26 ↦ 23` R13 blocks, `27 ↦ 8` Stage OUT-C). -/
def shdSegNS (s : Fin 28) : ℕ :=
  if s.val = 0 then 4 else if s.val = 27 then 8 else nSlots

private theorem shdSegNS_zero {s : Fin 28} (h0 : s.val = 0) : shdSegNS s = 4 := by
  unfold shdSegNS; rw [ite_eq_left h0]

private theorem shdSegNS_last {s : Fin 28} (h0 : s.val ≠ 0) (h27 : s.val = 27) : shdSegNS s = 8 := by
  unfold shdSegNS; rw [ite_eq_right h0, ite_eq_left h27]

private theorem shdSegNS_mid {s : Fin 28} (h0 : s.val ≠ 0) (h27 : s.val ≠ 27) : shdSegNS s = nSlots := by
  unfold shdSegNS; rw [ite_eq_right h0, ite_eq_right h27]

/-- Slot kind schedule per segment across all 28 segments (`incKind`, `kindOf`, `outcKind`). -/
def shdSegKind (s : Fin 28) : Fin (shdSegNS s) → Kind :=
  if h0 : s.val = 0 then fun t => incKind (t.cast (shdSegNS_zero h0))
  else if h27 : s.val = 27 then fun t => outcKind (t.cast (shdSegNS_last h0 h27))
  else fun t => kindOf (t.cast (shdSegNS_mid h0 h27)).val

/-- Host-slot lists per segment across all 28 segments (`incHosts`, `w16Hosts`, `outcHosts`). -/
def shdSegHosts {K : Type} (hc : ShdHostCoeffs K) (s : Fin 28) :
    Fin (shdSegNS s) → List (Fin (shdSegNS s) × K) :=
  if h0 : s.val = 0 then
    fun t => (incHosts (K := K) (t.cast (shdSegNS_zero h0))).map (fun p => (p.1.cast (shdSegNS_zero h0).symm, p.2))
  else if h27 : s.val = 27 then
    fun t => (outcHosts hc.νOut₂ hc.νOut₄ (t.cast (shdSegNS_last h0 h27))).map
      (fun p => (p.1.cast (shdSegNS_last h0 h27).symm, p.2))
  else
    fun t => (w16Hosts (hc.νBlk ⟨s.val - 1, by omega⟩) (t.cast (shdSegNS_mid h0 h27))).map
      (fun p => (p.1.cast (shdSegNS_mid h0 h27).symm, p.2))

/-- **Unified 28-segment hand-off theorem** (`inc_hhosted`, `w16_hhosted`, `outc_hhosted`):
for every segment `s : Fin 28`, every hosted slot of a host is masked. -/
theorem shdSeg_hhosted {K : Type} (hc : ShdHostCoeffs K) (s : Fin 28) :
    ∀ t : Fin (shdSegNS s), shdSegKind s t = .host →
      ∀ p ∈ shdSegHosts hc s t, maskedOfKind (shdSegKind s p.1) = true := by
  intro t ht p hp
  by_cases h0 : s.val = 0
  · simp only [shdSegKind, dite_eq_left h0] at ht
    simp only [shdSegHosts, dite_eq_left h0] at hp
    obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    simp only [shdSegKind, dite_eq_left h0]
    rw [show (q.1.cast (shdSegNS_zero h0).symm).cast (shdSegNS_zero h0) = q.1 from Fin.ext rfl]
    exact inc_hhosted (K := K) (t.cast (shdSegNS_zero h0)) ht q hq
  · by_cases h27 : s.val = 27
    · simp only [shdSegKind, dite_eq_right h0, dite_eq_left h27] at ht
      simp only [shdSegHosts, dite_eq_right h0, dite_eq_left h27] at hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      simp only [shdSegKind, dite_eq_right h0, dite_eq_left h27]
      rw [show (q.1.cast (shdSegNS_last h0 h27).symm).cast (shdSegNS_last h0 h27) = q.1 from Fin.ext rfl]
      exact outc_hhosted hc.νOut₂ hc.νOut₄ (t.cast (shdSegNS_last h0 h27)) ht q hq
    · simp only [shdSegKind, dite_eq_right h0, dite_eq_right h27] at ht
      simp only [shdSegHosts, dite_eq_right h0, dite_eq_right h27] at hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      simp only [shdSegKind, dite_eq_right h0, dite_eq_right h27]
      rw [show (q.1.cast (shdSegNS_mid h0 h27).symm).cast (shdSegNS_mid h0 h27) = q.1 from Fin.ext rfl]
      exact w16_hhosted (hc.νBlk ⟨s.val - 1, by omega⟩) (t.cast (shdSegNS_mid h0 h27)) ht q hq

end FieldAndSchedule

/-! ## 2. Level-1 coin factorization and 84-PCS-opening joint law independence -/

section Level1

/-- Static coin geometry of one PCS table (`TE`, `B_0..26`, `A_0..27`, or `H_0..27`): independent of the
distinct opened-column count `kOpen`, so the coin space is fixed across all value vectors `v`. -/
structure PcsTableSpec where
  n : ℕ
  Q : ℕ
  Dat : Type
  Γ : Type
  Salt : Type
  [finDat : Fintype Dat]
  [decDat : DecidableEq Dat]
  [finΓ : Fintype Γ]
  [decΓ : DecidableEq Γ]
  [finSalt : Fintype Salt]
  [neSalt : Nonempty Salt]

attribute [instance] PcsTableSpec.finDat PcsTableSpec.decDat PcsTableSpec.finΓ
  PcsTableSpec.decΓ PcsTableSpec.finSalt PcsTableSpec.neSalt

/-- Segment `(A, H)` PCS table specification. -/
structure PcsAHSpec where
  A : PcsTableSpec
  H : PcsTableSpec

/-- Complete 84-PCS-table Level-1 specification (`TE` + 27 boundaries `B_0..26` + 28 segment `(A_s, H_s)` pairs). -/
structure ShdL1Spec where
  te : PcsTableSpec
  bnd : Fin 27 → PcsTableSpec
  ah : Fin 28 → PcsAHSpec

/-- Distinct opened-column counts across all 84 PCS tables at a fixed value vector `v`. -/
structure ShdL1OpenK where
  te : ℕ
  bnd : Fin 27 → ℕ
  kA : Fin 28 → ℕ
  kH : Fin 28 → ℕ

abbrev PcsStdCoins (F : Type) (T : PcsTableSpec) : Type := Hiding.Coins F T.n T.Q T.Dat T.Γ × T.Salt
abbrev PcsStdView (F K : Type) (T : PcsTableSpec) (kOpen : ℕ) : Type := Hiding.View F K T.n T.Q kOpen T.Dat T.Γ × T.Salt

abbrev PcsAHCoins (F : Type) (S : PcsAHSpec) : Type :=
  (Hiding.Coins F S.A.n S.A.Q S.A.Dat S.A.Γ × Hiding.CoinsH F S.H.n S.H.Q S.H.Dat S.H.Γ) × (S.A.Salt × S.H.Salt)

abbrev PcsAHView (F K : Type) (S : PcsAHSpec) (kA kH : ℕ) : Type :=
  (Hiding.View F K S.A.n S.A.Q kA S.A.Dat S.A.Γ × Hiding.ViewH F K S.H.n S.H.Q kH S.H.Dat S.H.Γ)
    × (S.A.Salt × S.H.Salt)

/-- Level-1 coins (`Ω₁`): all 84 PCS tables' polynomial coins + leaf salts (`TE`, `B_0..26`, `A_0..27`, `H_0..27`). -/
abbrev ShdL1Coins (F : Type) (L1 : ShdL1Spec) : Type :=
  PcsStdCoins F L1.te × ((k : Fin 27) → PcsStdCoins F (L1.bnd k)) × ((s : Fin 28) → PcsAHCoins F (L1.ah s))

/-- Level-1 joint opening view (`V₁`): all 84 PCS opening views + leaf salts. -/
abbrev ShdL1View (F K : Type) (L1 : ShdL1Spec) (ks : ShdL1OpenK) : Type :=
  PcsStdView F K L1.te ks.te × ((k : Fin 27) → PcsStdView F K (L1.bnd k) (ks.bnd k))
    × ((s : Fin 28) → PcsAHView F K (L1.ah s) (ks.kA s) (ks.kH s))

instance instFintypeHidingCoins (F : Type) [Fintype F] (n Q : ℕ) (Dat Γ : Type)
    [Fintype Dat] [DecidableEq Dat] [Fintype Γ] [DecidableEq Γ] :
    Fintype (Hiding.Coins F n Q Dat Γ) :=
  inferInstanceAs (Fintype ((Dat → Fin Q → F) × (Γ × Bool → Hiding.Row F n Q) × (Bool → Hiding.Row F n Q)))

instance instFintypeHidingCoinsH (F : Type) [Fintype F] (n Q : ℕ) (Dat Γ : Type)
    [Fintype Dat] [DecidableEq Dat] [Fintype Γ] [DecidableEq Γ] :
    Fintype (Hiding.CoinsH F n Q Dat Γ) :=
  inferInstanceAs (Fintype ((Dat → Fin Q → F) × (Bool → Hiding.Row F n Q)
    × (Γ × Bool → Hiding.Row F n Q) × (Bool → Hiding.Row F n Q)))

instance instNonemptyHidingCoins (F : Type) [Zero F] (n Q : ℕ) (Dat Γ : Type) :
    Nonempty (Hiding.Coins F n Q Dat Γ) :=
  ⟨(fun _ _ => 0, fun _ _ => 0, fun _ _ => 0)⟩

instance instNonemptyHidingCoinsH (F : Type) [Zero F] (n Q : ℕ) (Dat Γ : Type) :
    Nonempty (Hiding.CoinsH F n Q Dat Γ) :=
  ⟨(fun _ _ => 0, fun _ _ => 0, fun _ _ => 0, fun _ _ => 0)⟩

/-- Opening parameters and hiding hypotheses for one standard PCS table (`TE` or `B_k`). -/
structure PcsStdData (F K Dt : Type) [Field F] [Fintype F] [Field K] [Algebra F K]
    (T : PcsTableSpec) (kOpen : ℕ) where
  E : Matrix (Fin kOpen) (Fin T.n ⊕ Fin T.Q) F
  ω : Hiding.Weights K T.Dat T.Γ
  d : Dt → T.Dat → Fin T.n → F
  hab : ∀ g, LinearIndependent F ![ω.a g, ω.b g]
  hp : LinearIndependent F ![ω.pa, ω.pb]
  hE : Function.Surjective (fun p : Fin T.Q → F => fun j => ∑ l, E j (Sum.inr l) * p l)

def PcsStdData.view {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    {T : PcsTableSpec} {kOpen : ℕ} (D : PcsStdData F K Dt T kOpen) (e : Dt) (c : PcsStdCoins F T) :
    PcsStdView F K T kOpen :=
  (Hiding.openingView D.E D.ω (D.d e) c.1, c.2)

/-- Opening parameters and hiding hypotheses for one segment's `(A, H)` pair. -/
structure PcsAHData (F K Dt : Type) [Field F] [Fintype F] [Field K] [Algebra F K]
    (S : PcsAHSpec) (kA kH : ℕ) where
  EA : Matrix (Fin kA) (Fin S.A.n ⊕ Fin S.A.Q) F
  ωA : Hiding.Weights K S.A.Dat S.A.Γ
  habA : ∀ g, LinearIndependent F ![ωA.a g, ωA.b g]
  hpA : LinearIndependent F ![ωA.pa, ωA.pb]
  hEA : Function.Surjective (fun p : Fin S.A.Q → F => fun j => ∑ l, EA j (Sum.inr l) * p l)
  EH : Matrix (Fin kH) (Fin S.H.n ⊕ Fin S.H.Q) F
  Z : (Fin S.H.n → F) → (Fin S.H.n → F)
  hZadd : ∀ u u', Z (u + u') = Z u + Z u'
  hZ : ∀ u : Fin S.H.n → F, ∑ c, u c = 0 → ∃ u', Z u' = u
  ωH : Hiding.WeightsH K S.H.Dat S.H.Γ
  hsH : LinearIndependent F ![ωH.sa, ωH.sb]
  habH : ∀ g, LinearIndependent F ![ωH.a g, ωH.b g]
  hpH : LinearIndependent F ![ωH.pa, ωH.pb]
  hEH : Function.Surjective (fun p : Fin S.H.Q → F => fun j => ∑ l, EH j (Sum.inr l) * p l)
  dA : Dt → S.A.Dat → Fin S.A.n → F
  dH : Dt → S.H.Dat → Fin S.H.n → F
  hdH : ∀ e, ∑ c, ∑ i, ωH.sD i * algebraMap F K (dH e i c) = 0

def PcsAHData.view {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    {S : PcsAHSpec} {kA kH : ℕ} (D : PcsAHData F K Dt S kA kH) (e : Dt) (c : PcsAHCoins F S) :
    PcsAHView F K S kA kH :=
  ((Hiding.openingView D.EA D.ωA (D.dA e) c.1.1, Hiding.openingViewH D.EH D.Z D.ωH (D.dH e) c.1.2), c.2)

/-- All 84 PCS tables' opening data and hiding hypotheses at a fixed value vector. -/
structure ShdL1Data (F K Dt : Type) [Field F] [Fintype F] [Field K] [Algebra F K]
    (L1 : ShdL1Spec) (ks : ShdL1OpenK) where
  te : PcsStdData F K Dt L1.te ks.te
  bnd : (k : Fin 27) → PcsStdData F K Dt (L1.bnd k) (ks.bnd k)
  ah : (s : Fin 28) → PcsAHData F K Dt (L1.ah s) (ks.kA s) (ks.kH s)

def ShdL1Data.view {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    {L1 : ShdL1Spec} {ks : ShdL1OpenK} (D : ShdL1Data F K Dt L1 ks) (e : Dt) (ω₁ : ShdL1Coins F L1) :
    ShdL1View F K L1 ks :=
  (D.te.view e ω₁.1, fun k => (D.bnd k).view e (ω₁.2.1 k), fun s => (D.ah s).view e (ω₁.2.2 s))

/-- Single standard PCS opening + leaf salts law independence (`Hiding.openingView_law_eq`). -/
theorem pcsStd_law_eq {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    (hK : Module.finrank F K = 2) {T : PcsTableSpec} {kOpen : ℕ} (D : PcsStdData F K Dt T kOpen) (e e' : Dt) :
    (PMF.uniformOfFintype (PcsStdCoins F T)).map (D.view e)
      = (PMF.uniformOfFintype (PcsStdCoins F T)).map (D.view e') :=
  ZKW16.law_eq_prod _ _ id id
    ((Hiding.openingView_law_eq hK D.E D.ω D.hab D.hp D.hE (D.d e)).trans
      (Hiding.openingView_law_eq hK D.E D.ω D.hab D.hp D.hE (D.d e')).symm) rfl

/-- Segment `(A, H)` pair opening + leaf salts law independence (`ZKLinks.openingsAH_law_eq`). -/
theorem pcsAH_law_eq {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    (hK : Module.finrank F K = 2) {S : PcsAHSpec} {kA kH : ℕ} (D : PcsAHData F K Dt S kA kH) (e e' : Dt) :
    (PMF.uniformOfFintype (PcsAHCoins F S)).map (D.view e)
      = (PMF.uniformOfFintype (PcsAHCoins F S)).map (D.view e') :=
  ZKW16.law_eq_prod _ _ id id
    (ZKLinks.openingsAH_law_eq hK D.EA D.ωA D.habA D.hpA D.hEA D.EH D.Z D.hZadd D.hZ D.ωH
      D.hsH D.habH D.hpH D.hEH D.dA D.dH D.hdH e e') rfl

private theorem law_eq_prod_any {Ω Ω' β γ : Type} {i1 : Fintype Ω} [Nonempty Ω] {i2 : Fintype Ω'} [Nonempty Ω']
    {i12 : Fintype (Ω × Ω')} [Nonempty (Ω × Ω')] (f f' : Ω → β) (g g' : Ω' → γ)
    (hf : (@PMF.uniformOfFintype Ω i1 _).map f = (@PMF.uniformOfFintype Ω i1 _).map f')
    (hg : (@PMF.uniformOfFintype Ω' i2 _).map g = (@PMF.uniformOfFintype Ω' i2 _).map g') :
    (@PMF.uniformOfFintype (Ω × Ω') i12 _).map (fun p => (f p.1, g p.2))
      = (@PMF.uniformOfFintype (Ω × Ω') i12 _).map (fun p => (f' p.1, g' p.2)) := by
  cases Subsingleton.elim i12 (@instFintypeProd Ω Ω' i1 i2)
  exact @ZKW16.law_eq_prod Ω Ω' β γ i1 _ i2 _ f f' g g' hf hg

private theorem shdL1_view_eq {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    {L1 : ShdL1Spec} {ks : ShdL1OpenK} (D : ShdL1Data F K Dt L1 ks) (e : Dt) :
    D.view e = fun p => (D.te.view e p.1, (fun q => ((fun c k => (D.bnd k).view e (c k)) q.1,
      (fun c s => (D.ah s).view e (c s)) q.2)) p.2) := rfl

private theorem shdL1_law_eq_aux {F K : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    {L1 : ShdL1Spec} {ks : ShdL1OpenK}
    (vte vte' : PcsStdCoins F L1.te → PcsStdView F K L1.te ks.te)
    (vbnd vbnd' : (k : Fin 27) → PcsStdCoins F (L1.bnd k) → PcsStdView F K (L1.bnd k) (ks.bnd k))
    (vah vah' : (s : Fin 28) → PcsAHCoins F (L1.ah s) → PcsAHView F K (L1.ah s) (ks.kA s) (ks.kH s))
    (hte : (PMF.uniformOfFintype (PcsStdCoins F L1.te)).map vte
      = (PMF.uniformOfFintype (PcsStdCoins F L1.te)).map vte')
    (hbnd : ∀ k, (PMF.uniformOfFintype (PcsStdCoins F (L1.bnd k))).map (vbnd k)
      = (PMF.uniformOfFintype (PcsStdCoins F (L1.bnd k))).map (vbnd' k))
    (hah : ∀ s, (PMF.uniformOfFintype (PcsAHCoins F (L1.ah s))).map (vah s)
      = (PMF.uniformOfFintype (PcsAHCoins F (L1.ah s))).map (vah' s)) :
    (PMF.uniformOfFintype (ShdL1Coins F L1)).map
        (fun p => (vte p.1, (fun q => ((fun c k => vbnd k (c k)) q.1, (fun c s => vah s (c s)) q.2)) p.2))
      = (PMF.uniformOfFintype (ShdL1Coins F L1)).map
        (fun p => (vte' p.1, (fun q => ((fun c k => vbnd' k (c k)) q.1, (fun c s => vah' s (c s)) q.2)) p.2)) := by
  let _ : ∀ k, DecidableEq (PcsStdView F K (L1.bnd k) (ks.bnd k)) := fun _ => Classical.decEq _
  let _ : ∀ s, DecidableEq (PcsAHView F K (L1.ah s) (ks.kA s) (ks.kH s)) := fun _ => Classical.decEq _
  have hB := ZKLinks.law_eq_pi vbnd vbnd' hbnd
  have hA := ZKLinks.law_eq_pi vah vah' hah
  have hBA := law_eq_prod_any (i12 := @instFintypeProd _ _ _ _)
    (fun (c : (k : Fin 27) → PcsStdCoins F (L1.bnd k)) k => vbnd k (c k))
    (fun (c : (k : Fin 27) → PcsStdCoins F (L1.bnd k)) k => vbnd' k (c k))
    (fun (c : (s : Fin 28) → PcsAHCoins F (L1.ah s)) s => vah s (c s))
    (fun (c : (s : Fin 28) → PcsAHCoins F (L1.ah s)) s => vah' s (c s)) hB hA
  exact law_eq_prod_any vte vte'
    (fun (q : ((k : Fin 27) → PcsStdCoins F (L1.bnd k)) × ((s : Fin 28) → PcsAHCoins F (L1.ah s))) =>
      ((fun (c : (k : Fin 27) → PcsStdCoins F (L1.bnd k)) k => vbnd k (c k)) q.1,
       (fun (c : (s : Fin 28) → PcsAHCoins F (L1.ah s)) s => vah s (c s)) q.2))
    (fun (q : ((k : Fin 27) → PcsStdCoins F (L1.bnd k)) × ((s : Fin 28) → PcsAHCoins F (L1.ah s))) =>
      ((fun (c : (k : Fin 27) → PcsStdCoins F (L1.bnd k)) k => vbnd' k (c k)) q.1,
       (fun (c : (s : Fin 28) → PcsAHCoins F (L1.ah s)) s => vah' s (c s)) q.2))
    hte hBA

/-- **Level-1 joint law independence across all 84 PCS openings** (`TE`, `B_0..26`, `A_0..27`, `H_0..27` + leaf salts),
composing `ZKLinks.law_eq_pi` (over `Fin 27` and `Fin 28`) with `pcsStd_law_eq`, `pcsAH_law_eq`, and `ZKW16.law_eq_prod`. -/
theorem shdL1_law_eq {F K Dt : Type} [Field F] [Fintype F] [Field K] [Algebra F K]
    (hK : Module.finrank F K = 2) {L1 : ShdL1Spec} {ks : ShdL1OpenK} (D : ShdL1Data F K Dt L1 ks) (e e' : Dt) :
    (PMF.uniformOfFintype (ShdL1Coins F L1)).map (D.view e)
      = (PMF.uniformOfFintype (ShdL1Coins F L1)).map (D.view e') := by
  rw [shdL1_view_eq D e, shdL1_view_eq D e']
  exact shdL1_law_eq_aux (D.te.view e) (D.te.view e')
    (fun k => (D.bnd k).view e) (fun k => (D.bnd k).view e')
    (fun s => (D.ah s).view e) (fun s => (D.ah s).view e')
    (pcsStd_law_eq hK D.te e e')
    (fun k => pcsStd_law_eq hK (D.bnd k) e e')
    (fun s => pcsAH_law_eq hK (D.ah s) e e')

end Level1

/-! ## 3. Level-2 coin factorization, 28-segment conditional law independence, and two-level `hHV` -/

section Level2AndTwoLevel

/-- Static Level-2 coin geometry of one segment: per-slot sumcheck dimensions `(n, d)`,
`M` message size `mm`, mask count `r`, pad count `Q`, and `M` leaf-salt space `MSalt`. -/
structure SegL2Spec (ns : ℕ) where
  n : Fin ns → ℕ
  d : Fin ns → ℕ
  mm : ℕ
  r : ℕ
  Q : ℕ
  MSalt : Type
  [finMSalt : Fintype MSalt]
  [neMSalt : Nonempty MSalt]

attribute [instance] SegL2Spec.finMSalt SegL2Spec.neMSalt

abbrev SegL2Coins (F K : Type) {ns : ℕ} (S : SegL2Spec ns) : Type :=
  (((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) × Hiding.MCoins F S.mm S.r S.Q) × S.MSalt

abbrev SegL2View (F K : Type) {ns : ℕ} (S : SegL2Spec ns) (qOpen : ℕ) : Type :=
  (((t : Fin ns) → K × (Fin (S.n t + 1) → Fin (S.d t + 1) → K) × K) × Hiding.MView F S.mm S.r qOpen) × S.MSalt

abbrev ShdL2Spec : Type 1 := (s : Fin 28) → SegL2Spec (shdSegNS s)
abbrev ShdL2Coins (F K : Type) (L2 : ShdL2Spec) : Type := (s : Fin 28) → SegL2Coins F K (L2 s)
abbrev ShdL2View (F K : Type) (L2 : ShdL2Spec) (qs : Fin 28 → ℕ) : Type := (s : Fin 28) → SegL2View F K (L2 s) (qs s)

/-- **Two-level factored Shieldstral view coins `ShdViewCoins = Ω₁ × Ω₂`**
(84 PCS tables' polynomial coins + leaf salts × 28 segments' sumcheck mask + `M` coins + `M` leaf salts). -/
abbrev ShdViewCoins (F K : Type) (L1 : ShdL1Spec) (L2 : ShdL2Spec) : Type :=
  ShdL1Coins F L1 × ShdL2Coins F K L2

instance instFintypeSegL2Coins (F K : Type) [Fintype F] [Fintype K] {ns : ℕ} (S : SegL2Spec ns) :
    Fintype (SegL2Coins F K S) :=
  inferInstanceAs (Fintype ((((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t))
    × Hiding.MCoins F S.mm S.r S.Q) × S.MSalt))

instance instNonemptySegL2Coins (F K : Type) [Zero F] [Zero K] {ns : ℕ} (S : SegL2Spec ns) :
    Nonempty (SegL2Coins F K S) := by
  let _ : Inhabited F := ⟨0⟩
  let _ : Inhabited K := ⟨0⟩
  let _ : Inhabited S.MSalt := ⟨Classical.choice S.neMSalt⟩
  exact inferInstance

/-- Full two-level composed honest view `V₁ × V₂`. -/
abbrev ShdView (F K : Type) (L1 : ShdL1Spec) (L2 : ShdL2Spec) (ks : ShdL1OpenK) (qs : Fin 28 → ℕ) : Type :=
  ShdL1View F K L1 ks × ShdL2View F K L2 qs

private theorem map_uniform_equiv {α β : Type} [Fintype α] [Nonempty α] [Fintype β] [Nonempty β]
    (e : α ≃ β) : (PMF.uniformOfFintype α).map e = PMF.uniformOfFintype β := by
  classical
  have hcard : Fintype.card α = Fintype.card β := Fintype.card_congr e
  ext b
  rw [PMF.map_apply, tsum_eq_single (e.symm b)]
  · simp [PMF.uniformOfFintype_apply, hcard]
  · intro a ha
    have hne : b ≠ e a := fun h => ha (by rw [h, e.symm_apply_apply])
    simp [hne]

/-- **Conditional single-segment honest view law** (from `ZKHonest.honest_block_view_law_eq` at `Ω₁ = Unit`):
two honest slot-polynomial families agreeing at their terminal challenges induce identical Level-2 view laws. -/
theorem honest_seg_cond_law_eq {K F : Type} [Field K] [Fintype K] [Field F] [Fintype F] [Algebra F K]
    {ns qOpen : ℕ} (S : SegL2Spec ns) (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K))
    (hd : ∀ t, 1 ≤ S.d t) (hdc : ∀ t, S.d t < ringChar K) (h2 : (2 : K) ≠ 0)
    (c : Fin ns → K) (hc : ∀ t, c t ≠ 0) (ρ : (t : Fin ns) → Fin (S.n t + 1) → K)
    (hhosted : ∀ s, kind s = .host → ∀ p ∈ hosts s, maskedOfKind (kind p.1) = true)
    (U θ : K) (hU : U ∉ Set.range (algebraMap F K)) (κ : F) (hU2 : U ^ 2 = algebraMap F K κ)
    (P : Hiding.MOpenPub F S.mm S.r S.Q qOpen) (hm : 0 < S.mm) (hmF : (S.mm : F) ≠ 0)
    (hy : Function.Injective P.y)
    (hsum : ∀ j < 2 * S.mm, ∑ i, P.y i ^ j = if j = 0 ∨ j = S.mm then (S.mm : F) else 0)
    (hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0)
    (hpad : ∀ s (v : Fin S.mm → F), ∃ g : Fin S.Q → F,
      ∀ t, (Lagrange.interpolate Finset.univ P.y (v - Hiding.placePads (P.π s) g)).eval (P.x t) = 0)
    (w : ((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) → Fin S.r → Bool → Fin S.mm → F)
    (hlay : ∀ a, ∑ s, ∑ i, Hiding.fp2 U (w a s true i, w a s false i) * Hiding.fp2 U (P.Wre s i, P.Wim s i)
      = mfComb θ (codeFunsAt ns kind hosts) c ρ a)
    (f₁ f₂ : (t : Fin ns) → (Fin (S.n t + 1) → K) → K)
    (hf₁ : ∀ t, Sound.IndDegLE (S.d t) (f₁ t)) (hf₂ : ∀ t, Sound.IndDegLE (S.d t) (f₂ t))
    (hstd₁ : ∀ t, kind t = .standalone → Sound.cubeSum (f₁ t) = 0)
    (hstd₂ : ∀ t, kind t = .standalone → Sound.cubeSum (f₂ t) = 0)
    (hsumH₁ : ∀ s, kind s = .host →
      Sound.cubeSum (f₁ s) = ((hosts s).map (fun p => p.2 * Sound.cubeSum (f₁ p.1))).sum)
    (hsumH₂ : ∀ s, kind s = .host →
      Sound.cubeSum (f₂ s) = ((hosts s).map (fun p => p.2 * Sound.cubeSum (f₂ p.1))).sum)
    (htermEq : ∀ t, f₁ t (ρ t) = f₂ t (ρ t)) :
    (PMF.uniformOfFintype (SegL2Coins F K S)).map
        (fun p => ((fun t => slotView (maskedOfKind (kind t))
            (honestCo (S.d t) (S.n t) (f₁ t) (ρ t)) (c t) (ρ t) (p.1.1 t),
          Hiding.mOpenView κ P hm (w p.1.1) p.1.2), p.2))
      = (PMF.uniformOfFintype (SegL2Coins F K S)).map
        (fun p => ((fun t => slotView (maskedOfKind (kind t))
            (honestCo (S.d t) (S.n t) (f₂ t) (ρ t)) (c t) (ρ t) (p.1.1 t),
          Hiding.mOpenView κ P hm (w p.1.1) p.1.2), p.2)) := by
  have hblk := honest_block_view_law_eq (K := K) (F := F) (Dt := Bool) (Ω₁ := Unit) (β₁ := Unit)
    kind hosts S.n S.d (fun _ _ => ()) false (fun _ => rfl) hd hdc h2 c hc ρ (fun b _ => cond b f₁ f₂)
    (fun b _ t => match b with | true => hf₁ t | false => hf₂ t)
    (fun b _ t h => match b with | true => hstd₁ t h | false => hstd₂ t h)
    (fun t _ => f₂ t (ρ t)) (fun b _ t => match b with | true => htermEq t | false => rfl) hhosted
    (fun b _ s h => match b with | true => hsumH₁ s h | false => hsumH₂ s h)
    U θ hU κ hU2 P hm hmF hy hsum hW hpad w hlay true
  let eUnit : (((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) × Hiding.MCoins F S.mm S.r S.Q)
      ≃ ((Unit × ((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t))) × Hiding.MCoins F S.mm S.r S.Q) :=
    { toFun := fun p => (((), p.1), p.2)
      invFun := fun p => (p.1.2, p.2)
      left_inv := fun _ => rfl
      right_inv := fun ⟨⟨(), _⟩, _⟩ => rfl }
  let proj :
      ((Unit × ((t : Fin ns) → K × (Fin (S.n t + 1) → Fin (S.d t + 1) → K) × K)) × Hiding.MView F S.mm S.r qOpen) →
        (((t : Fin ns) → K × (Fin (S.n t + 1) → Fin (S.d t + 1) → K) × K) × Hiding.MView F S.mm S.r qOpen) :=
    fun q => (q.1.2, q.2)
  have hrew : ∀ f' : (t : Fin ns) → (Fin (S.n t + 1) → K) → K,
      (PMF.uniformOfFintype (((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) × Hiding.MCoins F S.mm S.r S.Q)).map
          (fun p => (fun t => slotView (maskedOfKind (kind t))
              (honestCo (S.d t) (S.n t) (f' t) (ρ t)) (c t) (ρ t) (p.1 t),
            Hiding.mOpenView κ P hm (w p.1) p.2))
        = ((PMF.uniformOfFintype ((Unit × ((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)))
            × Hiding.MCoins F S.mm S.r S.Q)).map
            (fun q => (((), fun t => slotView (maskedOfKind (kind t))
                (honestCo (S.d t) (S.n t) (f' t) (ρ t)) (c t) (ρ t) (q.1.2 t)),
              Hiding.mOpenView κ P hm (w q.1.2) q.2))).map proj := by
    intro f'; rw [← map_uniform_equiv eUnit, PMF.map_comp, PMF.map_comp]; rfl
  have hinner :
      (PMF.uniformOfFintype (((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) × Hiding.MCoins F S.mm S.r S.Q)).map
          (fun p => (fun t => slotView (maskedOfKind (kind t))
              (honestCo (S.d t) (S.n t) (f₁ t) (ρ t)) (c t) (ρ t) (p.1 t),
            Hiding.mOpenView κ P hm (w p.1) p.2))
        = (PMF.uniformOfFintype (((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) × Hiding.MCoins F S.mm S.r S.Q)).map
          (fun p => (fun t => slotView (maskedOfKind (kind t))
              (honestCo (S.d t) (S.n t) (f₂ t) (ρ t)) (c t) (ρ t) (p.1 t),
            Hiding.mOpenView κ P hm (w p.1) p.2)) := by
    rw [hrew f₁, hrew f₂]
    exact congrArg (PMF.map proj) hblk
  exact ZKW16.law_eq_prod _ _ id id hinner rfl

/-- Per-segment Level-2 data and honest-prover conditions at a fixed value vector. -/
structure ShdSegL2Data (F K Dt Ω₁ V₁ : Type) [Field F] [Fintype F] [Field K] [Fintype K] [Algebra F K]
    (X₁ : Dt → Ω₁ → V₁) {ns : ℕ} (kind : Fin ns → Kind) (hosts : Fin ns → List (Fin ns × K))
    (U : K) (κ : F) (S : SegL2Spec ns) (qOpen : ℕ) where
  hd : ∀ t, 1 ≤ S.d t
  hdc : ∀ t, S.d t < ringChar K
  c : Fin ns → K
  hc : ∀ t, c t ≠ 0
  ρ : (t : Fin ns) → Fin (S.n t + 1) → K
  f : Dt → Ω₁ → (t : Fin ns) → (Fin (S.n t + 1) → K) → K
  hf : ∀ e ω₁ t, Sound.IndDegLE (S.d t) (f e ω₁ t)
  hstd : ∀ e ω₁ t, kind t = .standalone → Sound.cubeSum (f e ω₁ t) = 0
  T : (t : Fin ns) → V₁ → K
  hterm : ∀ e ω₁ t, f e ω₁ t (ρ t) = T t (X₁ e ω₁)
  hsumH : ∀ e ω₁ s, kind s = .host →
    Sound.cubeSum (f e ω₁ s) = ((hosts s).map (fun p => p.2 * Sound.cubeSum (f e ω₁ p.1))).sum
  θ : K
  P : Hiding.MOpenPub F S.mm S.r S.Q qOpen
  hm : 0 < S.mm
  hmF : (S.mm : F) ≠ 0
  hy : Function.Injective P.y
  hsum : ∀ j < 2 * S.mm, ∑ i, P.y i ^ j = if j = 0 ∨ j = S.mm then (S.mm : F) else 0
  hW : ∀ s l, P.Wre s (P.π s l) = 0 ∧ P.Wim s (P.π s l) = 0
  hpad : ∀ s (v : Fin S.mm → F), ∃ g : Fin S.Q → F,
    ∀ t, (Lagrange.interpolate Finset.univ P.y (v - Hiding.placePads (P.π s) g)).eval (P.x t) = 0
  w : ((t : Fin ns) → Hiding.CfsCoeffs K (S.n t) (S.d t)) → Fin S.r → Bool → Fin S.mm → F
  hlay : ∀ a, ∑ s, ∑ i, Hiding.fp2 U (w a s true i, w a s false i) * Hiding.fp2 U (P.Wre s i, P.Wim s i)
    = mfComb θ (codeFunsAt ns kind hosts) c ρ a

noncomputable def ShdSegL2Data.view {F K Dt Ω₁ V₁ : Type} [Field F] [Fintype F] [Field K] [Fintype K] [Algebra F K]
    {X₁ : Dt → Ω₁ → V₁} {ns : ℕ} {kind : Fin ns → Kind} {hosts : Fin ns → List (Fin ns × K)}
    {U : K} {κ : F} {S : SegL2Spec ns} {qOpen : ℕ}
    (D : ShdSegL2Data F K Dt Ω₁ V₁ X₁ kind hosts U κ S qOpen)
    (e : Dt) (ω₁ : Ω₁) (ω₂ : SegL2Coins F K S) : SegL2View F K S qOpen :=
  ((fun t => slotView (maskedOfKind (kind t))
      (honestCo (S.d t) (S.n t) (D.f e ω₁ t) (D.ρ t)) (D.c t) (D.ρ t) (ω₂.1.1 t),
    Hiding.mOpenView κ D.P D.hm (D.w ω₂.1.1) ω₂.1.2), ω₂.2)

/-- **Level-2 28-segment conditional joint law independence** (composing `ZKLinks.law_eq_pi` over `Fin 28`
with `honest_seg_cond_law_eq` and `shdSeg_hhosted`). -/
theorem shdL2_cond_law_eq {F K Dt Ω₁ V₁ : Type} [Field F] [Fintype F] [Field K] [Fintype K] [Algebra F K]
    (h2 : (2 : K) ≠ 0) {U : K} (hU : U ∉ Set.range (algebraMap F K)) {κ : F} (hU2 : U ^ 2 = algebraMap F K κ)
    {X₁ : Dt → Ω₁ → V₁} {L2 : ShdL2Spec} {qs : Fin 28 → ℕ} (hc : ShdHostCoeffs K)
    (D2 : (s : Fin 28) → ShdSegL2Data F K Dt Ω₁ V₁ X₁ (shdSegKind s) (shdSegHosts hc s) U κ (L2 s) (qs s))
    (e₁ e₂ : Dt) (ω₁ ω₁' : Ω₁) (hX : X₁ e₁ ω₁ = X₁ e₂ ω₁') :
    (PMF.uniformOfFintype (ShdL2Coins F K L2)).map (fun ω₂ s => (D2 s).view e₁ ω₁ (ω₂ s))
      = (PMF.uniformOfFintype (ShdL2Coins F K L2)).map (fun ω₂ s => (D2 s).view e₂ ω₁' (ω₂ s)) := by
  classical
  refine ZKLinks.law_eq_pi (fun s => (D2 s).view e₁ ω₁) (fun s => (D2 s).view e₂ ω₁') (fun s => ?_)
  exact honest_seg_cond_law_eq (L2 s) (shdSegKind s) (shdSegHosts hc s)
    (D2 s).hd (D2 s).hdc h2 (D2 s).c (D2 s).hc (D2 s).ρ (shdSeg_hhosted hc s)
    U (D2 s).θ hU κ hU2 (D2 s).P (D2 s).hm (D2 s).hmF (D2 s).hy (D2 s).hsum (D2 s).hW (D2 s).hpad
    (D2 s).w (D2 s).hlay ((D2 s).f e₁ ω₁) ((D2 s).f e₂ ω₁')
    ((D2 s).hf e₁ ω₁) ((D2 s).hf e₂ ω₁') ((D2 s).hstd e₁ ω₁) ((D2 s).hstd e₂ ω₁')
    ((D2 s).hsumH e₁ ω₁) ((D2 s).hsumH e₂ ω₁')
    (fun t => by rw [(D2 s).hterm e₁ ω₁ t, (D2 s).hterm e₂ ω₁' t, hX])

/-- **Two-level view-law composition when Level 2's conditional law depends on `(e, ω₁)` only through `X₁ e ω₁`**
(reduces directly to `HonestShieldZKBase.twoLevel_law_eq`). -/
theorem twoLevel_law_eq_of_cond {E Ω₁ Ω₂ V₁ V₂ : Type} [Fintype Ω₁] [Nonempty Ω₁] [Fintype Ω₂] [Nonempty Ω₂]
    (X₁ : E → Ω₁ → V₁) (X₂ : E → Ω₁ → Ω₂ → V₂) (e e' : E)
    (h1 : (PMF.uniformOfFintype Ω₁).map (X₁ e) = (PMF.uniformOfFintype Ω₁).map (X₁ e'))
    (hcond : ∀ (d₁ d₂ : E) (ω₁ ω₁' : Ω₁), X₁ d₁ ω₁ = X₁ d₂ ω₁' →
      (PMF.uniformOfFintype Ω₂).map (X₂ d₁ ω₁) = (PMF.uniformOfFintype Ω₂).map (X₂ d₂ ω₁')) :
    (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ e p.1, X₂ e p.1 p.2))
      = (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ e' p.1, X₂ e' p.1 p.2)) := by
  classical
  obtain ⟨ω₀⟩ := ‹Nonempty Ω₁›
  let S₂ : V₁ → Ω₂ → V₂ := fun x₁ =>
    if h : ∃ p : E × Ω₁, X₁ p.1 p.2 = x₁ then X₂ h.choose.1 h.choose.2 else X₂ e ω₀
  have hS : ∀ d ω₁, (PMF.uniformOfFintype Ω₂).map (X₂ d ω₁) = (PMF.uniformOfFintype Ω₂).map (S₂ (X₁ d ω₁)) := by
    intro d ω₁
    have hex : ∃ p : E × Ω₁, X₁ p.1 p.2 = X₁ d ω₁ := ⟨(d, ω₁), rfl⟩
    rw [show S₂ (X₁ d ω₁) = X₂ hex.choose.1 hex.choose.2 by dsimp only [S₂]; rw [dite_eq_left hex]]
    exact hcond d hex.choose.1 ω₁ hex.choose.2 hex.choose_spec.symm
  have hprod : PMF.uniformOfFintype (Ω₁ × Ω₂)
      = (PMF.uniformOfFintype Ω₁).bind (fun ω₁ => (PMF.uniformOfFintype Ω₂).map (fun ω₂ => (ω₁, ω₂))) := by
    ext ⟨ω₁, ω₂⟩
    simp only [PMF.uniformOfFintype_apply, PMF.bind_apply, PMF.map_apply, tsum_fintype, Fintype.card_prod,
      Nat.cast_mul, ENNReal.mul_inv (Or.inl (Nat.cast_ne_zero.mpr Fintype.card_ne_zero))
        (Or.inl (ENNReal.natCast_ne_top _)), Prod.mk.injEq]
    rw [Finset.sum_eq_single ω₁]
    · simp only [true_and, Finset.sum_ite_eq, Finset.mem_univ, ↓reduceIte]
    · intro a _ hne
      have h0 : (∑ a_1 : Ω₂, if ω₁ = a ∧ ω₂ = a_1 then ((Fintype.card Ω₂ : ℝ≥0∞)⁻¹) else 0) = 0 :=
        Finset.sum_eq_zero (fun _ _ => ite_eq_right (fun h => hne h.1.symm))
      rw [h0, mul_zero]
    · intro h; have hf : False := h (Finset.mem_univ _); cases hf
  have hrew : ∀ d : E,
      (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ d p.1, X₂ d p.1 p.2))
        = (PMF.uniformOfFintype (Ω₁ × Ω₂)).map (fun p => (X₁ d p.1, S₂ (X₁ d p.1) p.2)) := by
    intro d
    rw [hprod, PMF.map_bind, PMF.map_bind]; congr 1; funext ω₁; rw [PMF.map_comp, PMF.map_comp]
    have hsub1 : (PMF.uniformOfFintype Ω₂).map ((fun p : Ω₁ × Ω₂ => (X₁ d p.1, X₂ d p.1 p.2)) ∘ fun ω₂ => (ω₁, ω₂))
        = ((PMF.uniformOfFintype Ω₂).map (X₂ d ω₁)).map (fun x₂ => (X₁ d ω₁, x₂)) := by rw [PMF.map_comp]; rfl
    have hsub2 : (PMF.uniformOfFintype Ω₂).map ((fun p : Ω₁ × Ω₂ => (X₁ d p.1, S₂ (X₁ d p.1) p.2)) ∘ fun ω₂ => (ω₁, ω₂))
        = ((PMF.uniformOfFintype Ω₂).map (S₂ (X₁ d ω₁))).map (fun x₂ => (X₁ d ω₁, x₂)) := by rw [PMF.map_comp]; rfl
    rw [hsub1, hsub2, hS d ω₁]
  rw [hrew e, hrew e']
  exact twoLevel_law_eq X₁ (fun _ x₁ ω₂ => S₂ x₁ ω₂) e e' h1 (fun _ => rfl)

private theorem twoLevel_law_eq_of_cond_any {E Ω₁ Ω₂ V₁ V₂ : Type}
    {i1 : Fintype Ω₁} [Nonempty Ω₁] {i2 : Fintype Ω₂} [Nonempty Ω₂] {i12 : Fintype (Ω₁ × Ω₂)} [Nonempty (Ω₁ × Ω₂)]
    (X₁ : E → Ω₁ → V₁) (X₂ : E → Ω₁ → Ω₂ → V₂) (e e' : E)
    (h1 : (@PMF.uniformOfFintype Ω₁ i1 _).map (X₁ e) = (@PMF.uniformOfFintype Ω₁ i1 _).map (X₁ e'))
    (hcond : ∀ (d₁ d₂ : E) (ω₁ ω₁' : Ω₁), X₁ d₁ ω₁ = X₁ d₂ ω₁' →
      (@PMF.uniformOfFintype Ω₂ i2 _).map (X₂ d₁ ω₁) = (@PMF.uniformOfFintype Ω₂ i2 _).map (X₂ d₂ ω₁')) :
    (@PMF.uniformOfFintype (Ω₁ × Ω₂) i12 _).map (fun p => (X₁ e p.1, X₂ e p.1 p.2))
      = (@PMF.uniformOfFintype (Ω₁ × Ω₂) i12 _).map (fun p => (X₁ e' p.1, X₂ e' p.1 p.2)) := by
  cases Subsingleton.elim i12 (@instFintypeProd Ω₁ Ω₂ i1 i2)
  exact @twoLevel_law_eq_of_cond E Ω₁ Ω₂ V₁ V₂ i1 _ i2 _ X₁ X₂ e e' h1 hcond

private theorem shdP_twoLevel_law_eq_aux {F K Dt : Type} [Field F] [Fintype F] [Field K] [Fintype K] [Algebra F K]
    {L1 : ShdL1Spec} {L2 : ShdL2Spec} {ks : ShdL1OpenK} {qs : Fin 28 → ℕ}
    (X₁ : Dt → ShdL1Coins F L1 → ShdL1View F K L1 ks)
    (X₂ : (s : Fin 28) → Dt → ShdL1Coins F L1 → SegL2Coins F K (L2 s) → SegL2View F K (L2 s) (qs s))
    (e e' : Dt)
    (h1 : (PMF.uniformOfFintype (ShdL1Coins F L1)).map (X₁ e)
      = (PMF.uniformOfFintype (ShdL1Coins F L1)).map (X₁ e'))
    (h2 : ∀ (d₁ d₂ : Dt) (ω₁ ω₁' : ShdL1Coins F L1), X₁ d₁ ω₁ = X₁ d₂ ω₁' →
      (PMF.uniformOfFintype (ShdL2Coins F K L2)).map (fun ω₂ s => X₂ s d₁ ω₁ (ω₂ s))
        = (PMF.uniformOfFintype (ShdL2Coins F K L2)).map (fun ω₂ s => X₂ s d₂ ω₁' (ω₂ s))) :
    (PMF.uniformOfFintype (ShdViewCoins F K L1 L2)).map
        (fun p => (X₁ e p.1, fun s => X₂ s e p.1 (p.2 s)))
      = (PMF.uniformOfFintype (ShdViewCoins F K L1 L2)).map
        (fun p => (X₁ e' p.1, fun s => X₂ s e' p.1 (p.2 s))) :=
  twoLevel_law_eq_of_cond_any X₁ (fun d ω₁ (ω₂ : ShdL2Coins F K L2) s => X₂ s d ω₁ (ω₂ s)) e e' h1 h2

/-- **Full 28-segment two-level honest-view law equality** (`shdL1_law_eq` + `shdL2_cond_law_eq` via `twoLevel_law_eq`). -/
theorem shdP_twoLevel_law_eq {F K Dt : Type} [Field F] [Fintype F] [Field K] [Fintype K] [Algebra F K]
    (hK : Module.finrank F K = 2) (h2 : (2 : K) ≠ 0)
    {U : K} (hU : U ∉ Set.range (algebraMap F K)) {κ : F} (hU2 : U ^ 2 = algebraMap F K κ)
    {L1 : ShdL1Spec} {L2 : ShdL2Spec} {ks : ShdL1OpenK} {qs : Fin 28 → ℕ}
    (hc : ShdHostCoeffs K) (D1 : ShdL1Data F K Dt L1 ks)
    (D2 : (s : Fin 28) → ShdSegL2Data F K Dt (ShdL1Coins F L1) (ShdL1View F K L1 ks)
      D1.view (shdSegKind s) (shdSegHosts hc s) U κ (L2 s) (qs s))
    (e e' : Dt) :
    (PMF.uniformOfFintype (ShdViewCoins F K L1 L2)).map
        (fun p => (D1.view e p.1, fun s => (D2 s).view e p.1 (p.2 s)))
      = (PMF.uniformOfFintype (ShdViewCoins F K L1 L2)).map
        (fun p => (D1.view e' p.1, fun s => (D2 s).view e' p.1 (p.2 s))) :=
  shdP_twoLevel_law_eq_aux D1.view (fun s => (D2 s).view) e e'
    (shdL1_law_eq hK D1 e e') (fun d₁ d₂ ω₁ ω₁' hX => shdL2_cond_law_eq h2 hU hU2 hc D2 d₁ d₂ ω₁ ω₁' hX)

/-- Admissible inputs of `classifyModelP R` with a fixed public verdict `verdict`. -/
abbrev AdmAt {S : ZK60.Block.BlockShape} (R : ClassifyRunPublicP S) (verdict : ℕ) : Type :=
  { y : {x // (classifyModelP R).admissible x} // (classifySpecP R y.1).getD 0 = verdict }

/-- **Concrete Shieldstral T128 R13 28-segment two-level `hHV` composition (`GF`, `shdP_K`, `shdP_U`, `κ = 7`)**:
combines `shdP_twoLevel_law_eq` and `ZKHonest.hHV_rel_of_view` directly to discharge the exact `hHV` hypothesis of
`RunShieldOpenShell.classifyP_zk_of_prog_model`. -/
theorem shdP_twoLevel_hHV {S : ZK60.Block.BlockShape} {Hdr Coins : Type} [Fintype Coins] [Nonempty Coins]
    (R : ClassifyRunPublicP S) (Lq k : ℕ)
    (prog : {x // (classifyModelP R).admissible x} → Coins → PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt))
    (G : (Fin k → Dig) → Prop) (L1 : ShdL1Spec) (L2 : ShdL2Spec)
    (π : Coins → ShdViewCoins GF shdP_K L1 L2)
    (hπ : (PMF.uniformOfFintype Coins).map π = PMF.uniformOfFintype (ShdViewCoins GF shdP_K L1 L2))
    (ks : ℕ → (v : Fin k → Dig) → ¬ G v → ShdL1OpenK)
    (qs : ℕ → (v : Fin k → Dig) → ¬ G v → (Fin 28 → ℕ))
    (hc : ℕ → (v : Fin k → Dig) → ¬ G v → ShdHostCoeffs shdP_K)
    (D1 : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) →
      ShdL1Data GF shdP_K (AdmAt R verdict) L1 (ks verdict v hg))
    (D2 : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) → (s : Fin 28) →
      ShdSegL2Data GF shdP_K (AdmAt R verdict) (ShdL1Coins GF L1) (ShdL1View GF shdP_K L1 (ks verdict v hg))
        (D1 verdict v hg).view (shdSegKind s) (shdSegHosts (hc verdict v hg) s) shdP_U (7 : GF)
        (L2 s) (qs verdict v hg s))
    (Rc : (verdict : ℕ) → (v : Fin k → Dig) → (hg : ¬ G v) →
      ShdView GF shdP_K L1 L2 (ks verdict v hg) (qs verdict v hg) → ClsStmt Hdr × ClsReceipt)
    (hout : ∀ (verdict : ℕ) (y : AdmAt R verdict) (c : Coins) (v : Fin k → Dig) (hg : ¬ G v),
      PProg.outOf (prog y.1 c) v =
        Rc verdict v hg ((D1 verdict v hg).view y (π c).1, fun s => (D2 verdict v hg s).view y (π c).1 ((π c).2 s))) :
    ∀ x x' : {x // (classifyModelP R).admissible x},
      (classifySpecP R x.1).getD 0 = (classifySpecP R x'.1).getD 0 →
      ∀ v : Fin k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x c) v)
          = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog x' c) v) := by
  intro x x' hpub v hg
  let verdict : ℕ := (classifySpecP R x.1).getD 0
  let FM : FSModel Unit Dig (AdmAt R verdict) Coins (ClsStmt Hdr × ClsReceipt) :=
    { k := 0, dep := fun _ _ => ∅, pts := fun _ _ _ _ _ => (), out := fun y c _ => PProg.outOf (prog y.1 c) v,
      vis := fun _ _ => False, vp := fun _ _ _ _ => (),
      causal := fun _ _ _ _ _ _ _ => rfl, sep := fun _ _ _ _ _ _ => rfl, vis_pts := fun _ _ _ _ _ h => by cases h }
  exact hHV_rel_of_view FM π hπ (fun _ : AdmAt R verdict => ())
    (fun y _ ω => ((D1 verdict v hg).view y ω.1, fun s => (D2 verdict v hg s).view y ω.1 (ω.2 s)))
    (fun _ _ view => Rc verdict v hg view) (fun _ => False) (fun y c _ _ => hout verdict y c v hg)
    (fun _ y y' _ _ => shdP_twoLevel_law_eq shdP_finrank shdP_two_ne_zero shdP_U_not_mem_range shdP_hU
      (hc verdict v hg) (D1 verdict v hg) (D2 verdict v hg) y y')
    ⟨x, rfl⟩ ⟨x', hpub.symm⟩ rfl Fin.elim0 not_false

end Level2AndTwoLevel

/-! ## 4. Explicit named computational assumption for native OS-seeded RNG transfer -/

section NativeOsRngTransfer

/-- Replace a protocol's ideal uniform prover coins `IdealCoins` with a 256-bit native OS-RNG seed (`Dig`)
expanded deterministically via `expand : Dig → IdealCoins`. Every other protocol field is unchanged. -/
def withExpandedCoins {Q D IdealCoins : Type} {M : IntModel}
    (P : Protocol Q D IdealCoins M) (expand : Dig → IdealCoins) : Protocol Q D Dig M where
  Stmt := P.Stmt
  Receipt := P.Receipt
  Salt := P.Salt
  Leak := P.Leak
  leak := P.leak
  ypub := P.ypub
  opensIn := P.opensIn
  opensOut := P.opensOut
  prove H W x seed := P.prove H W x (expand seed)
  verify := P.verify

/-- Transport an ideal-coin `Simulator` unchanged to `withExpandedCoins P expand`. -/
def simWithExpandedCoins {Q D IdealCoins : Type} {M : IntModel}
    {P : Protocol Q D IdealCoins M} (expand : Dig → IdealCoins) (S : Simulator M P) :
    Simulator M (withExpandedCoins P expand) where
  State := S.State
  SCoins := S.SCoins
  fin := S.fin
  ne := S.ne
  inh := S.inh
  init := S.init
  step := S.step

/-- Transport an ideal-coin `SimulatorL` unchanged to `withExpandedCoins P expand`. -/
def simLWithExpandedCoins {Q D IdealCoins : Type} {M : IntModel}
    {P : Protocol Q D IdealCoins M} {L : Type} (expand : Dig → IdealCoins) (S : SimulatorL M P L) :
    SimulatorL M (withExpandedCoins P expand) L where
  State := S.State
  SCoins := S.SCoins
  fin := S.fin
  ne := S.ne
  inh := S.inh
  init := S.init
  step := S.step

/-- **Explicit named computational assumption (a transparent `Prop` hypothesis, NOT a postulate)**:
multi-instance RO-aided indistinguishability of deterministic OS-seed expansion `expand : Dig → IdealCoins`
from fresh uniform `IdealCoins`, against any `q`-query, `R`-receipt distinguisher `Dist` matching
`ZeroKnowledge` / `ZeroKnowledgeL`'s exact `OC` adversary type. -/
def NativeOsRngIndist {Q D IdealCoins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    {M : IntModel} (P : Protocol Q D IdealCoins M) (expand : Dig → IdealCoins)
    (εrng : ℕ → ℕ → ℝ≥0∞) : Prop :=
  ∀ (W : M.Weights) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool), Dist.Within q R →
      realProb M (withExpandedCoins P expand) W (q + R) Dist ≤ realProb M P W (q + R) Dist + εrng q R
        ∧ realProb M P W (q + R) Dist ≤ realProb M (withExpandedCoins P expand) W (q + R) Dist + εrng q R

/-- **Native OS-RNG transfer for `ZeroKnowledge`** (exact `ℝ≥0∞` triangle inequality). -/
theorem shdP_nativeOsRng_zk {Q D IdealCoins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    {M : IntModel} (P : Protocol Q D IdealCoins M) (expand : Dig → IdealCoins) {εzk εrng : ℕ → ℕ → ℝ≥0∞}
    (hRng : NativeOsRngIndist P expand εrng) (hZk : ZeroKnowledge M P εzk) :
    ZeroKnowledge M (withExpandedCoins P expand) (fun q R => εzk q R + εrng q R) := by
  obtain ⟨S, hS⟩ := hZk
  refine ⟨simWithExpandedCoins expand S, fun W q R Dist hD => ?_⟩
  obtain ⟨hzk1, hzk2⟩ := hS W q R Dist hD
  obtain ⟨hrng1, hrng2⟩ := hRng W q R Dist hD
  refine ⟨?_, ?_⟩
  · calc realProb M (withExpandedCoins P expand) W (q + R) Dist
        ≤ realProb M P W (q + R) Dist + εrng q R := hrng1
      _ ≤ (idealProb M P S W (q + R) Dist + εzk q R) + εrng q R := add_le_add hzk1 le_rfl
      _ = idealProb M (withExpandedCoins P expand) (simWithExpandedCoins expand S) W (q + R) Dist
            + (εzk q R + εrng q R) := by rw [add_assoc]; rfl
  · calc idealProb M (withExpandedCoins P expand) (simWithExpandedCoins expand S) W (q + R) Dist
        = idealProb M P S W (q + R) Dist := rfl
      _ ≤ realProb M P W (q + R) Dist + εzk q R := hzk2
      _ ≤ (realProb M (withExpandedCoins P expand) W (q + R) Dist + εrng q R) + εzk q R := add_le_add hrng2 le_rfl
      _ = realProb M (withExpandedCoins P expand) W (q + R) Dist + (εzk q R + εrng q R) := by
          rw [add_assoc, add_comm (εrng q R) (εzk q R)]

/-- **Native OS-RNG transfer for D76-approved `ZeroKnowledgeL`** (exact `ℝ≥0∞` triangle inequality). -/
theorem shdP_nativeOsRng_zkL {Q D IdealCoins : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D]
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    {M : IntModel} (P : Protocol Q D IdealCoins M) {L : Type} (Λ : M.Input → L)
    (expand : Dig → IdealCoins) {εzk εrng : ℕ → ℕ → ℝ≥0∞}
    (hRng : NativeOsRngIndist P expand εrng) (hZk : ZeroKnowledgeL M P Λ εzk) :
    ZeroKnowledgeL M (withExpandedCoins P expand) Λ (fun q R => εzk q R + εrng q R) := by
  obtain ⟨S, hS⟩ := hZk
  refine ⟨simLWithExpandedCoins expand S, fun W q R Dist hq hR hD => ?_⟩
  obtain ⟨hzk1, hzk2⟩ := hS W q R Dist hq hR hD
  obtain ⟨hrng1, hrng2⟩ := hRng W q R Dist hD
  refine ⟨?_, ?_⟩
  · calc realProb M (withExpandedCoins P expand) W (q + R) Dist
        ≤ realProb M P W (q + R) Dist + εrng q R := hrng1
      _ ≤ (idealProbL M P Λ S W (q + R) Dist + εzk q R) + εrng q R := add_le_add hzk1 le_rfl
      _ = idealProbL M (withExpandedCoins P expand) Λ (simLWithExpandedCoins expand S) W (q + R) Dist
            + (εzk q R + εrng q R) := by rw [add_assoc]; rfl
  · calc idealProbL M (withExpandedCoins P expand) Λ (simLWithExpandedCoins expand S) W (q + R) Dist
        = idealProbL M P Λ S W (q + R) Dist := rfl
      _ ≤ realProb M P W (q + R) Dist + εzk q R := hzk2
      _ ≤ (realProb M (withExpandedCoins P expand) W (q + R) Dist + εrng q R) + εzk q R := add_le_add hrng2 le_rfl
      _ = realProb M (withExpandedCoins P expand) W (q + R) Dist + (εzk q R + εrng q R) := by
          rw [add_assoc, add_comm (εrng q R) (εzk q R)]

/-- Pull back a segment prover `SegP` along a coin-expansion map `f : C₂ → C₁`. -/
def segPMapCoins {St X C₁ C₂ : Type} (f : C₂ → C₁) (p : SegP St X C₁) : SegP St X C₂ where
  run H s x c := p.run H s x (f c)

/-- Pull back a run prover `RunP` along a coin-expansion map `f : C₂ → C₁`. -/
def runPMapCoins {Hdr X C₁ C₂ : Type} (f : C₂ → C₁) (P : RunP Hdr X C₁) : RunP Hdr X C₂ where
  hdr := P.hdr
  inC := segPMapCoins f P.inC
  blk k := segPMapCoins f (P.blk k)
  outC := segPMapCoins f P.outC
  refused := P.refused

theorem proveSegs_mapCoins {St X C₁ C₂ : Type} (f : C₂ → C₁) (H : HIn → Dig) (s : St) (x : X)
    (c : C₂) (bnd : Dig) :
    ∀ (ps : List (SegP St X C₁)) (cr : Carry) (t : Tr),
      proveSegs H s x c bnd (ps.map (segPMapCoins f)) cr t = proveSegs H s x (f c) bnd ps cr t
  | [], _, _ => rfl
  | p :: ps, cr, t => by
    simp only [List.map_cons, proveSegs, segPMapCoins]
    cases p.run H s x (f c) bnd (posTag H t) cr t with
    | error _ => rfl
    | ok r =>
      change (proveSegs H s x c bnd (ps.map (segPMapCoins f)) r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2))
        = (proveSegs H s x (f c) bnd ps r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2))
      rw [proveSegs_mapCoins f H s x c bnd ps r.2.1 r.2.2]

theorem runProve_mapCoins {Hdr X C₁ C₂ : Type} (f : C₂ → C₁) (V : RunV Hdr) (P : RunP Hdr X C₁)
    (adm : X → Prop) (H : HIn → Dig) (root : Dig) (verdict : ℕ) (x : X) (c : C₂) :
    runProve V (runPMapCoins f P) adm H root verdict x c = runProve V P adm H root verdict x (f c) := by
  have hparts : (runPMapCoins f P).parts V.L = (P.parts V.L).map (segPMapCoins f) := by
    simp [RunP.parts, runPMapCoins, Function.comp_def]
  have hsegs : honestSegs V (runPMapCoins f P) H root verdict x c = honestSegs V P H root verdict x (f c) := by
    unfold honestSegs; rw [hparts, proveSegs_mapCoins]; rfl
  unfold runProve; rw [hsegs]; rfl

/-- Pulling `RunP` and `base` back along `expand` equals `withExpandedCoins` on `classifyProtocolP`. -/
theorem classifyProtocolP_mapCoins_eq {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (expand : Dig → IdealCoins) :
    classifyProtocolP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s))
      = withExpandedCoins (classifyProtocolP R Lq V P Cin h64 hr base) expand := by
  let P₀ := classifyProtocolP R Lq V P Cin h64 hr base
  have hprove :
      (fun (G : QB Lq → Dig) (_ : (classifyModelP R).Weights) (x : S.Tok → ℕ) (seed : Dig) =>
        runProve V (runPMapCoins expand P) (classifyModelP R).admissible (liftH G)
          (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x seed)
      = (fun (G : QB Lq → Dig) (_ : (classifyModelP R).Weights) (x : S.Tok → ℕ) (seed : Dig) =>
        runProve V P (classifyModelP R).admissible (liftH G)
          (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x (expand seed)) := by
    funext G _ x seed
    exact runProve_mapCoins expand V P (classifyModelP R).admissible (liftH G)
      (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x seed
  exact congrArg
    (fun (pr : (QB Lq → Dig) → (classifyModelP R).Weights → (classifyModelP R).Input → Dig → P₀.Stmt × P₀.Receipt) =>
      ({ Stmt := P₀.Stmt, Receipt := P₀.Receipt, Salt := P₀.Salt, Leak := P₀.Leak, leak := P₀.leak, ypub := P₀.ypub,
         opensIn := P₀.opensIn, opensOut := P₀.opensOut, prove := pr, verify := P₀.verify } :
        Protocol (QB Lq) Dig Dig (classifyModelP R)))
    hprove

/-- Pulling `RunP` and `base` back along `expand` equals `withExpandedCoins` on `classifyProtocolUP`. -/
theorem classifyProtocolUP_mapCoins_eq {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (expand : Dig → IdealCoins) :
    classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e
      = withExpandedCoins (classifyProtocolUP R Lq V P Cin h64 hr base e) expand := by
  let P₀ := classifyProtocolUP R Lq V P Cin h64 hr base e
  have hprove :
      (fun (G : QB Lq → Dig) (_ : (classifyModelP R).Weights) (x : S.Tok → ℕ) (seed : Dig) =>
        runProve V (runPMapCoins expand P) (classifyModelP R).admissible (liftH G)
          (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x seed)
      = (fun (G : QB Lq → Dig) (_ : (classifyModelP R).Weights) (x : S.Tok → ℕ) (seed : Dig) =>
        runProve V P (classifyModelP R).admissible (liftH G)
          (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x (expand seed)) := by
    funext G _ x seed
    exact runProve_mapCoins expand V P (classifyModelP R).admissible (liftH G)
      (honestRoot Cin Lq h64 hr G x (base (expand seed))) ((classifySpecP R x).getD 0) x seed
  exact congrArg
    (fun (pr : (QB Lq → Dig) → (classifyModelP R).Weights → (classifyModelP R).Input → Dig → P₀.Stmt × P₀.Receipt) =>
      ({ Stmt := P₀.Stmt, Receipt := P₀.Receipt, Salt := P₀.Salt, Leak := P₀.Leak, leak := P₀.leak, ypub := P₀.ypub,
         opensIn := P₀.opensIn, opensOut := P₀.opensOut, prove := pr, verify := P₀.verify } :
        Protocol (QB Lq) Dig Dig (classifyModelP R)))
    hprove

/-- Direct `classifyProtocolP` corollary of `shdP_nativeOsRng_zk` for a pulled-back `RunP`. -/
theorem shdP_nativeOsRng_classifyP_zk {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (expand : Dig → IdealCoins) {εzk εrng : ℕ → ℕ → ℝ≥0∞}
    (hRng : NativeOsRngIndist (classifyProtocolP R Lq V P Cin h64 hr base) expand εrng)
    (hZk : ZeroKnowledge (classifyModelP R) (classifyProtocolP R Lq V P Cin h64 hr base) εzk) :
    ZeroKnowledge (classifyModelP R)
      (classifyProtocolP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)))
      (fun q R' => εzk q R' + εrng q R') := by
  rw [classifyProtocolP_mapCoins_eq]
  exact shdP_nativeOsRng_zk (classifyProtocolP R Lq V P Cin h64 hr base) expand hRng hZk

/-- Direct `classifyProtocolUP` corollary of `shdP_nativeOsRng_zkL` for a pulled-back `RunP`. -/
theorem shdP_nativeOsRng_classifyUP_zkL {S : ZK60.Block.BlockShape} {Hdr Salt IdealCoins L : Type}
    [Fintype IdealCoins] [Nonempty IdealCoins] [Inhabited IdealCoins]
    (R : ClassifyRunPublicP S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) IdealCoins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq)
    (base : IdealCoins → Salt) (e : ℕ) (Λ : (classifyModelP R).Input → L)
    (expand : Dig → IdealCoins) {εzk εrng : ℕ → ℕ → ℝ≥0∞}
    (hRng : NativeOsRngIndist (classifyProtocolUP R Lq V P Cin h64 hr base e) expand εrng)
    (hZk : ZeroKnowledgeL (classifyModelP R) (classifyProtocolUP R Lq V P Cin h64 hr base e) Λ εzk) :
    ZeroKnowledgeL (classifyModelP R)
      (classifyProtocolUP R Lq V (runPMapCoins expand P) Cin h64 hr (fun s => base (expand s)) e)
      Λ (fun q R' => εzk q R' + εrng q R') := by
  rw [classifyProtocolUP_mapCoins_eq]
  exact shdP_nativeOsRng_zkL (classifyProtocolUP R Lq V P Cin h64 hr base e) Λ expand hRng hZk

end NativeOsRngTransfer

end ZK60.HonestShield
