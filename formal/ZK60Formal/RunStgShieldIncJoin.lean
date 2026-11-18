/-
D63 lane L63 (2026-11-18), part 62: **SIC_QZC's and SIC_TZC's conclusions at every reading from "no doomed R0
entrant"**, and **`hLI_stg`'s conclusion from them and the two sum facts** (item 4b, steps 1 and 5, joined).

* `ShdIncSlotsT`, **`shdLuInAtK_of_slotsT`**: the slots' conclusions with the layout and the helpers read at ONE view
  (the run's whole trace `τ`: the `H_in` root sits after the head, so the head's view cannot read the helpers); the
  data at the head's view is the data at `τ`'s (`vwLoc_shdIncDataK`, `shdIncDataK_head`);
* **`stg_inc_def_zero`**: at a reading, an alive define state of a drawing slot is its define polynomial vanishing
  at every draw, over the claims' semantics at `τ`'s view (`stg_defAlive_of_notR0`, `stg_def_zero_of_alive`, the
  claims reading the view below the slot's window);
* **`shd_inc_qt`**: at stage IN-C's registered numbers, at every reading with no doomed `rtKR0` entrant,
  `QzcHolds` and `TzcHolds` of `shdIncLay` and `shdIncHd` at `τ`'s view (`inc_qzc_clauses`, `inc_tzc_clauses`,
  `shdQzcR_vals`, `shdTzcR_vals`, `qzcHolds_of_vals`, `tzcHolds_of_vals`);
* `ShdIncSumAt` (defined, not assumed: the `H` opening's value-0 sum claim and SIC_ZS's zero sum, at the helpers
  `shdIncHd` read at `τ`'s view) and **`shd_hLI_of_sum`**: with them, `hLI_stg`'s conclusion `StgLkAtV … shd_ΛI …`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncIdT

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-! ## 1. The slots' conclusions at one view -/

section SlotsT

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **The IN-C slots' conclusions at every reading, with the layout and the helpers at one view** (defined). -/
def ShdIncSlotsT {V nu : ℕ} (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (Dv : InData K shieldS0.Tok (Fin V) 12)
    (Lv : IncLayout (RingHom.id K) Dv 12 17) (hd : IncHelpers K 12 17 nu)
    (G : QB Lq → Dig) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 15
    ∧ QzcHolds (incQ Lv (incChalOf U ch) hd) (incChalOf U ch).1.2 (incChalOf U ch).1.1.1 (Lv.g (incChalOf U ch)) Lv.bos
    ∧ TzcHolds (incT Lv (incChalOf U ch) hd) (incChalOf U ch).1.2
    ∧ IncSum hd ∧ ∑ j, hd.2.2 j = 0

/-- **The slots' conclusions at one view give the stage's LogUp relation** when the data at every head's view is the
data at that view. -/
theorem shdLuInAtK_of_slotsT {V nu : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (Dof : StgVw Lq → InData K shieldS0.Tok (Fin V) 12) (vT : StgVw Lq)
    (Lv : IncLayout (RingHom.id K) (Dof vT) 12 17) (hd : IncHelpers K 12 17 nu)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdIncSlotsT U key domain Pof hdrLen bgaOf (Dof vT) Lv hd G τ)
    (hhead : ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      Dof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
        = Dof vT) :
    ShdLuInAtK U key domain Pof hdrLen bgaOf absOf Dof G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, hq, ht, hs, hz⟩ := h hdr core ch rs hrd
  refine ⟨hl, incHelpers Lv hd, ?_⟩
  rw [hhead hdr core ch rs hrd]
  exact (incCube (RingHom.id K) _ Lv (incChalOf U ch) hd hq ht hs hz).1

end SlotsT

/-! ## 2. The data reads the view below the head -/

section Loc

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ} (U : K) (tag : MTag) (h64 : 64 ≤ Lq)

/-- The matrix extracted at view position `i` reads the view below `n > i`. -/
theorem stgIOX_loc (lc h Q e r i n : ℕ) (hi : i < n) (v v' : StgVw Lq) (h1 : ∀ j, j < n → v.1 j = v'.1 j)
    (h2 : v.2.take n = v'.2.take n) :
    stgIOX (K := K) tag h64 lc h Q e r i v = stgIOX tag h64 lc h Q e r i v' := by
  unfold stgIOX
  rw [h1 i hi, ssh_absAt_eq v.2 v'.2 n i hi h2]

/-- **The `K`-valued IN-C data reads the view below `n`** (its `A_in` and `B_in` roots below `n`). -/
theorem vwLoc_shdIncDataK (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB iA n : ℕ) (hA : iA < n) (hB : iB < n) :
    VwLoc n (shdIncDataK U tag h64 P I Epad iB iA) := by
  intro v v' h1 h2
  have eA : ∀ lc h Q e r, stgIOX (K := K) tag h64 lc h Q e r iA v = stgIOX tag h64 lc h Q e r iA v' :=
    fun lc h Q e r => stgIOX_loc tag h64 lc h Q e r iA n hA v v' h1 h2
  have eB : ∀ lc h Q e r, stgIOX (K := K) tag h64 lc h Q e r iB v = stgIOX tag h64 lc h Q e r iB v' :=
    fun lc h Q e r => stgIOX_loc tag h64 lc h Q e r iB n hB v v' h1 h2
  simp only [shdIncDataK, shdIncData, stgPlK, stgPlB, eA, eB]

/-- **At a reading, the data at the head's view is the data at `τ`'s view.** -/
theorem shdIncDataK_head (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF)
    (iB hdrLen : ℕ) (hB : iB < hdrLen + 4) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (G : QB Lq → Dig) (Lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs) :
    shdIncDataK U tag h64 P I Epad iB hdrLen
        (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))
      = shdIncDataK U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) := by
  obtain ⟨h1, -⟩ := stg_rd_head key domain Pof 15 hdrLen bgaOf G τ hdr core ch rs hrd
  rw [← h1]
  exact vw_take absOf Lg (hdrLen + 4) (hdrLen + 4) le_rfl _
    (vwLoc_shdIncDataK U tag h64 P I Epad iB hdrLen (hdrLen + 4) (by omega) hB) τ

end Loc

/-! ## 3. An alive define state over `τ`'s view -/

section Zero

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED R0 ENTRANT: STAGE IN-C'S DEFINE POLYNOMIAL AT A DRAWING SLOT VANISHES AT EVERY DRAW**, over the claims'
semantics at `τ`'s view. -/
theorem stg_inc_def_zero (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n) (tag : MTag) (h64 : 64 ≤ Lq)
    (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (hIOl : VwLoc (hdrLen + (7 + 15)) csIO)
    (hR : D.r0 0 = stgDefsV P0 15 hdrLen (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen 15 lc h Q e rA rH csIO) sshDgI)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hno : ¬ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      G τ hdr core ch rs)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hgt : (Vi.bp (incCtx Vi.pub ch)).geom.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.terms.length)
    (hgeom : ∀ k, k < (Vi.bp (incCtx Vi.pub ch)).geom.slots.length →
      1 ≤ (Block.slotShape (Vi.bp (incCtx Vi.pub ch)) k).2.2)
    (k : ℕ) (hk : k ∈ stgDrawing P0) :
    ∀ y : Fin (P0.draws k) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ))
      (Fp2.zero, Fp2.zero, Fp2.zero) ((rs.take k).map Block.SlotRec.draws) k (stgWords U hbij y) = 0 := by
  have hal := stg_defAlive_of_notR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD n 0 hi hin P0
    (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
    (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) _ sshDgI G lg τ hdr core ch rs hrd hP hgt hR hno k hk
  have hslen : core.slots.length = (Vi.bp (incCtx Vi.pub ch)).geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := by
    rw [hslen, ← hP.2]
    exact List.mem_range.mp (List.mem_filter.mp hk).1
  have hz := stg_def_zero_of_alive key domain P0 (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) _ sshDgI G lg τ
    hdr core ch rs hrd hP hgeom hgt k hkl.le hal
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkl⟩
  obtain ⟨h1, -⟩ := stg_rd_def key domain (fun ch => Vi.bp (incCtx Vi.pub ch)) 15 hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G τ hdr core ch rs hrd hgt k q hq
  have hcsv : stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
      (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Vi.bp (incCtx Vi.pub ch)) core 15
            ++ Block.fullOps (Vi.bp (incCtx Vi.pub ch)) 0 (core.slots.take k))))
      = stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) csIO
        (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg τ) := by
    rw [← h1]
    exact vw_take _ lg (hdrLen + (7 + 15)) _ (by unfold stgDefPos; omega) _
      (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 15) _ (by omega) (by omega) csIO hIOl) τ
  intro y
  rw [← hcsv]
  exact hz y

end Zero

/-! ## 4. The slots' conclusions at the registered stage -/

section Qt

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- `g_emb = γ·TAG_EMB` in `K`. -/
theorem gEmb_toK (I : IncPub) (ch : List Fp2) :
    (incCtx I ch).gEmb.toK U = (ch.getD 1 Fp2.zero).toK U * algebraMap GF K ((tagEmb : ℕ) : GF) := by
  show ((ch.getD 1 Fp2.zero).mulBase (Fp.new (UInt64.ofNat tagEmb))).toK U = _
  rw [Fp2.toK_mulBase, Fp.new_toGF_ofNat _ (by unfold tagEmb; norm_num)]

/-- **SIC_QZC'S AND SIC_TZC'S CONCLUSIONS FROM THEIR DEFINE POLYNOMIALS VANISHING**, at stage IN-C's registered
numbers (the claims' semantics, the layout and the helpers at one view `w`). -/
theorem shd_inc_qt (hU : U ^ 2 = algebraMap GF K 7) (P : InPublic shieldS0) (P0 : Block.BlockParams) (Vi : IncV)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA rA rH iH rX : ℕ) (hrA : rA = 41) (hrX : rX = 38)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hcsO : ∀ z, csIO w .out z = claimSem U rX 14 256 (bxUxV tag Lq h64 rX iB w) z)
    (hIO1 : StgCsIODeg U hbij Vi.geo.bLogN (IncPrivIO1 Vi.pub) csIO)
    (ch : List Fp2) (hl : ch.length = 15) (hch : ∀ a ∈ ch, a.Canon)
    (hP : StgSame P0 (Vi.bp (incCtx Vi.pub ch)))
    (hti : Vi.pub.tiLog = 12) (hvoc : Vi.pub.vocLog = 17) (htB : Vi.pub.tBits = 7) (hbIn : Vi.pub.bInLog = 19)
    (hGb : Vi.geo.bLogN = 14) (hlt : Vi.pub.lt ≤ ogStage.lc) (hlc : ∀ cx, 0 < (Vi.bp cx).logCols)
    (hbos : Vi.pub.bos < 2 ^ 63) (hkap : ∀ t, Vi.pub.kappa t < 2 ^ 63)
    (hns : Vi.pub.numSpecial = P.ns) (hVV : P.V = 131072)
    (hEmb : ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((Vi.pub.embFold rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (Epad v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U))
    (hv : Vi.pub.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : Vi.pub.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, Vi.pub.ctlQ t.val = decide (ctlPos P t = 1))
    (hd1 hd2 : List (List Fp2)) (hhd1 : hd1.length = 1) (hhd2 : hd2.length = 2)
    (hz1 : ∀ y : Fin (P0.draws 1) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd1 1 (stgWords U hbij y) = 0)
    (hz2 : ∀ y : Fin (P0.draws 2) → K, stgΦBC U hbij P0 (Vi.bp (incCtx Vi.pub ch)) (incElog Vi.pub Vi.geo.bLogN)
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (Fp2.zero, Fp2.zero, Fp2.zero) hd2 2 (stgWords U hbij y) = 0) :
    QzcHolds (incQ (shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq) (incChalOf U ch)
        (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w))
      (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
      ((shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq).g (incChalOf U ch))
      (shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq).bos
    ∧ TzcHolds (incT (shdIncLay U tag h64 P Vi.pub Epad iB iA w hv hV htok hcq) (incChalOf U ch)
        (shdIncHd U tag h64 Vi.pub ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)) (incChalOf U ch).1.2 := by
  have hN1 : stgN P0 1 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vi.pub.tiLog + 1 = 13; omega
  have hN2 : stgN P0 2 = 18 := by unfold stgN; rw [stg_slotShape hP]; show Vi.pub.vocLog + 1 = 18; omega
  have hq := inc_qzc_clauses U hbij hU tag h64 P0 Vi ch hch hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    csIO w hlt hIO1 hd1 hhd1 hz1 12 hti
  have ht := inc_tzc_clauses U hbij hU tag h64 P0 Vi ch hch hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    csIO w hlt hd2 hhd2 hz2 17 hvoc
  have hvq := fun b => shdQzcR_vals U hbij tag h64 hU P Vi Epad iB iA rA rH iH rX hrA hrX csIO w hcsO ch hl hch hti
    htB hbIn hGb hlc hkap hv hV htok hcq hN1 b
  have hvt := fun c => shdTzcR_vals U hbij tag h64 hU P Vi Epad iB iA rA rH iH hrA csIO w ch hl hch hvoc hGb hlc hns
    hVV hEmb hv hV htok hcq hN2 c
  refine ⟨qzcHolds_of_vals _ _ _
    (fun b j => shdQzcR U hbij Vi ch (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (stgN P0 1) b j)
    ((kI Vi.pub.bos).toK U) ((incCtx Vi.pub ch).gEmb.toK U)
    (fun b => (hvq b).1) (fun b => (hvq b).2.1) (fun b => (hvq b).2.2.1) (fun b => (hvq b).2.2.2.1)
    (fun b => (hvq b).2.2.2.2.1) (fun b => (hvq b).2.2.2.2.2.1) (fun b => (hvq b).2.2.2.2.2.2.1)
    (fun b => (hvq b).2.2.2.2.2.2.2) (kI_nat_toK U _ hbos) (gEmb_toK U Vi.pub ch) (fun b => hq b), ?_⟩
  exact tzcHolds_of_vals _ _ _
    (fun c j => shdTzcR U hbij Vi ch (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (stgN P0 2) c j)
    (fun c => (hvt c).1) (fun c => (hvt c).2.1) (fun c => (hvt c).2.2.1) (fun c => (hvt c).2.2.2) (fun c => ht c)

end Qt

/-! ## 5. The two sum facts, and `hLI_stg` from them -/

section Sum

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- **The two sum facts at `τ`'s view** (defined, not assumed): the `H` opening's value-0 LogUp sum claim
`Σ h_q − Σ h_tab + Σ u = 0` and SIC_ZS's `Σ u = 0`, at the helpers read as the `H_in` planes (`shdIncHd`). What item
4b still has to prove from "no doomed A / sl / R0 entrant" (HANDOFF_20261118_3.md). -/
def ShdIncSumAt (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (I : IncPub) (rH iH : ℕ) (w : StgVw Lq) : Prop :=
  IncSum (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w)
    ∧ ∑ j, (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH w).2.2 j = 0

/-- **`hLI_stg`'s conclusion from the slots' clauses at every reading and the two sum facts.** -/
theorem shd_hLI_of_sum (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB hdrLen rH iH : ℕ) (hB : iB < hdrLen + 4)
    (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1))
    (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hqt : ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      ch.length = 15
      ∧ QzcHolds (incQ (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ)))
        (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
        ((shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).g (incChalOf U ch))
        (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).bos
      ∧ TzcHolds (incT (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ))) (incChalOf U ch).1.2)
    (hsum : ShdIncSumAt U tag h64 I rH iH (stgVw absOf Lg τ)) :
    StgLkAtV U key domain Pof 15 hdrLen bgaOf absOf (shd_ΛI U tag h64 P I Epad iB hdrLen) G Lg τ := by
  have hK : ShdLuInAtK U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB hdrLen) G Lg τ :=
    shdLuInAtK_of_slotsT U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB hdrLen)
      (stgVw absOf Lg τ) (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq)
      (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ)) G Lg τ
      (fun hdr core ch rs hrd => by
        obtain ⟨hl, hq, ht⟩ := hqt hdr core ch rs hrd
        exact ⟨hl, hq, ht, hsum.1, hsum.2⟩)
      (fun hdr core ch rs hrd =>
        shdIncDataK_head U tag h64 P I Epad iB hdrLen hB key domain Pof bgaOf absOf G Lg τ hdr core ch rs hrd)
  exact stgLkAtV_of_luIn U key domain Pof hdrLen bgaOf absOf (shdIncData U tag h64 P I Epad iB hdrLen) G Lg τ
    (shdLuInAt_of_K U tag h64 P I Epad iB hdrLen key domain Pof hdrLen bgaOf absOf G Lg τ hK)

end Sum

end ZK60.ProtocolClassify
