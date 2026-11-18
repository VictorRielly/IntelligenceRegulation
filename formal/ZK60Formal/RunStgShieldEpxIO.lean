/-
D63 lane L63 (2026-11-18), part 48: **the extractor wrapper `epxIOE` (tokW, xC pinned by construction) and the plane
identity** (HANDOFF_20261117_5.md section 5, items 2 and 3; the coordinator's rulings (a) `tokW := epW`, `xC` from the
extracted boundary plane `Lb`, by construction; (b) `dPos0 := shieldDPos0`).

* `epxIOE`: a run extractor wrapper setting `tokW` to `epxE`'s decoded input endpoint words (the same expression `epxE`
  writes into `epW`) and `xC i` to the extracted boundary plane `Lb` at `(row, i)` (`bndPlanes`, the plane `epxBndE`
  writes into `planes`). Composed as `epxE … (epxBndE … (epxIOE … E0))`, every field but `r'` is fixed by construction.
* `epxIO_inOkP`: on it, `InOkP` is exactly `InSat inp epW (bndPlanes … 0)` (the second conjunct `epW = tokW` holds by
  definition); `epxIO_outOkP`: `OutOkP b` is exactly `b ≤ 1 ∧ OutCSat out (bndPlanes … Lb (row, ·)) b` when
  `Lb = blks.length` and `row` is the public row (the third conjunct holds by definition).
* **The plane identity** `bndPlanes_view`: the extracted plane `j` is `piB` of the R13 plane reader on the stage view's
  `bxUxV` at position `off j + 2`, whenever the closing opening `D.opX (j + 1)` has R13's code geometry with `R` rows and
  the view's header shows the same root at `off j + 2` as the run (privZ ignores the plane's `Cm` tag).
  `bndPlanes0_shdIncData`: at `dPos0 := shieldDPos0`, plane `0` at `(t, i)` is `shdIncData`'s `X t (msbBits 12 i)`
  (`shd_ΛI`'s `B_in` reader, rows `38`).
* At a reading of a stage on the run's transcript (`StgRd`, the head view `hdr ++ rootOpsA`), both hypotheses hold for
  positions below `hdrLen + 4` (`stg_rd_head`, `absAt_rtTr_indep`): `bndPlanes_head`, `bndPlanes0_head`.
* `shdRkD_opX_succ_geo`, `shdRkD_opX_out_geo`: the concrete kinds data's closing openings at parts `j + 1 ≤ Lb` (blocks'
  incoming boundaries) and `Lb + 1` (`B_out`) have R13's code geometry with rows `pXk_rows j` resp. `Oout_rX`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuRd
import ZK60Formal.RunBlkPinsHd
import ZK60Formal.RunEpXMk

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams)
open ZK60.RunShape (ClassifyRunPublicP RunBlock)
open ZK60.RunShape.Shield (shieldS0)
open ZK60.ProtocolClassify.RunShapeP (InOkP OutOkP)
open ZK60.Out (OutCSat)

/-! ## 1. The wrapper and what `InOkP`, `OutOkP` become on it -/

section Wrap

variable {K : Type} [Field K] [Algebra GF K] {Hdr Salt : Type} {Lq : ℕ}

/-- **The run extractor wrapper pinning `tokW` and `xC` by construction**: `tokW` is the decoded input endpoint words
(`epxE`'s `epW` expression), `xC i` the extracted boundary plane `Lb` at `(row, i)`. -/
noncomputable def epxIOE (C : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt)
    (pos : shieldS0.Tok → Fin C.dR × Fin C.n)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
    (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
    (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)) (Lb : ℕ) (row : shieldS0.Tok)
    (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt) :
    List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt :=
  fun lg s rc =>
    { E0 lg s rc with
      tokW := fun t => (C.decodeIn (ops lg s) 768).1 (C.place (pos t).1) (pos t).2
      xC := fun i => bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) Lb (row, i) }

variable (C : PlaneCommit (shieldS0.Tok → ℕ) (ClsStmt Hdr) Salt) (mk : C.SaltMk)
  (pos : shieldS0.Tok → Fin C.dR × Fin C.n)
  (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin C.N → Option (MerkleOpening Dig Dig (ColR C.R)))
  (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
  (hL : (startMsg domain).length ≤ Lq) (pf : RtProf)
  (rd : ClsStmt Hdr × ClsReceipt → List Op × List RtData)
  (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)) (Lb : ℕ) (row : shieldS0.Tok)
  (E0 : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt shieldS0 Salt)

/-- **`InOkP` on the wrapped extractor is `InSat` of the decoded input words and the extracted plane `0`.** -/
theorem epxIO_inOkP (R : ClassifyRunPublicP shieldS0) (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    InOkP R (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc)
      ↔ InSat R.inp (fun t => (C.decodeIn (ops lg s) 768).1 (C.place (pos t).1) (pos t).2)
          (bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) 0) :=
  ⟨fun h => h.1, fun h => ⟨h, fun _ => rfl⟩⟩

/-- **`OutOkP` on the wrapped extractor is `b ≤ 1 ∧ OutCSat` of the extracted plane `Lb`'s public row**, when `Lb` is
the number of blocks and `row` the public row. -/
theorem epxIO_outOkP (R : ClassifyRunPublicP shieldS0) (hLb : R.blks.length = Lb) (hrow : R.row = row) (b : ℕ)
    (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    OutOkP R b (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc)
      ↔ b ≤ 1 ∧ OutCSat R.out
          (fun i => bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) Lb (row, i)) b := by
  subst hLb hrow
  exact ⟨fun h => ⟨h.1, h.2.1⟩, fun h => ⟨h.1, h.2, fun _ => rfl⟩⟩

/-! The fields of the wrapped extractor, as equations (`rfl`): for rewriting, and for the concrete top theorem, where the
kernel-level `rfl` on the concrete extractor makes the elaborator's unifier exceed its recursion depth. -/

theorem epxIO_tokW (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).tokW
      = fun t => (C.decodeIn (ops lg s) 768).1 (C.place (pos t).1) (pos t).2 :=
  rfl

theorem epxIO_planes (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).planes
      = bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) :=
  rfl

theorem epxIO_xC (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).xC
      = fun i => bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg (s, rc) Lb (row, i) :=
  rfl

/-- `InOkP`'s second conjunct on the wrapped extractor. -/
theorem epxIO_epW_tokW (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) (t : shieldS0.Tok) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).epW t
      = (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).tokW t :=
  rfl

/-- `OutOkP`'s third conjunct on the wrapped extractor. -/
theorem epxIO_xC_planes (R : ClassifyRunPublicP shieldS0) (hLb : R.blks.length = Lb) (hrow : R.row = row)
    (lg : List (QB Lq × Dig)) (s : ClsStmt Hdr) (rc : ClsReceipt) (i : Fin shieldS0.d) :
    (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).xC i
      = (epxE C mk pos ops (epxBndE U tag Lq h64 key domain hs hL pf rd D dPos0
        (epxIOE C pos ops U tag h64 key domain hs hL pf rd D dPos0 Lb row E0)) lg s rc).planes R.blks.length
          (R.row, i) := by
  subst hLb hrow
  rfl

end Wrap

/-! ## 2. The plane identity -/

section Plane

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

theorem hdrX_at_lt (absOf : QB Lq → Option (List UInt8)) (lg : List (QB Lq × Dig)) (hdrLen : ℕ)
    (τ : List (TItem × Dig)) (i : ℕ) (hi : i < hdrLen) :
    Block.hdrX absOf lg hdrLen τ i = (Block.absAt τ i, Block.cutO absOf (Block.absAt τ i) lg) := by
  show (if i < hdrLen then _ else _) = _
  exact ite_eq_left hi

/-- **THE PLANE IDENTITY**: the extracted boundary plane `j` is `piB` of the R13 plane reader on the stage view's `bxUxV`
at position `off j + 2`, when the closing opening `D.opX (j + 1)` has R13's code geometry with `R` rows and the view's
header shows the run's root at `off j + 2`. -/
theorem bndPlanes_view (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (lg : List (QB Lq × Dig)) (o : α) (j : ℕ) (p : shieldS0.Pos) (R : ℕ)
    (hg : (D.opX (j + 1)).h = 16 ∧ (D.opX (j + 1)).lc = 14 ∧ (D.opX (j + 1)).Q = 256
      ∧ (D.opX (j + 1)).e = 24448 ∧ (D.opX (j + 1)).rows = R)
    (hdr : List (TItem × Dig))
    (habs : Block.absAt (rtTr key domain Lq pf rd (fun _ => zeroDig) o) (pf.off j + 2)
      = Block.absAt hdr (pf.off j + 2)) :
    bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg o j p
      = Exec.Block.Join.W16.piB K (Exec.Block.Join.planeZ U 14 R 256
          (bxUxV tag Lq h64 R (pf.off j + 2) (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdr))
          ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (dPos0 p).1 (dPos0 p).2)) := by
  unfold bndPlanes bndPl
  rw [hdrX_at_lt _ lg _ _ (pf.off j + 2) (by omega), habs]
  obtain ⟨h1, h2, h3, h4, h5⟩ := hg
  generalize D.opX (j + 1) = o' at h1 h2 h3 h4 h5 ⊢
  cases o'
  dsimp only at h1 h2 h3 h4 h5
  subst h1 h2 h3 h4 h5
  rfl

/-- **Plane `0` is `shd_ΛI`'s `B_in` reading** at `dPos0 := shieldDPos0` (rows `38`, position `off 0 + 2`). -/
theorem bndPlanes0_shdIncData (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (lg : List (QB Lq × Dig)) (o : α)
    (hg : (D.opX 1).h = 16 ∧ (D.opX 1).lc = 14 ∧ (D.opX 1).Q = 256 ∧ (D.opX 1).e = 24448 ∧ (D.opX 1).rows = 38)
    (hdr : List (TItem × Dig))
    (habs : Block.absAt (rtTr key domain Lq pf rd (fun _ => zeroDig) o) (pf.off 0 + 2)
      = Block.absAt hdr (pf.off 0 + 2))
    (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iA : ℕ)
    (t : shieldS0.Tok) (i : shieldS0.Wid) :
    bndPlanes U tag Lq h64 key domain hs hL pf rd D shieldDPos0 lg o 0 (t, i)
      = (shdIncData U tag h64 P I Epad (pf.off 0 + 2) iA
          (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg hdr)).X t (msbBits 12 i.val) := by
  rw [bndPlanes_view U tag h64 key domain hs hL pf rd D shieldDPos0 lg o 0 (t, i) 38 hg hdr habs,
    shdIncData_X]
  rfl

/-- **At a reading of a stage on the run's transcript, the head view's header shows the run's roots below
`hdrLen + 4`**, against any oracle for the run. -/
theorem rd_head_absAt_rtTr (key : Option Dig) (domain : List UInt8) {α : Type} (pf : RtProf)
    (rd : α → List Op × List RtData) (o : α) (G G' : QB Lq → Dig)
    (Pof : List Fp2 → BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G (rtTr key domain Lq pf rd G o) hdr core ch rs)
    (i : ℕ) (hi : i < hdrLen + 4) :
    Block.absAt (rtTr key domain Lq pf rd G' o) i
      = Block.absAt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)) i := by
  rw [absAt_rtTr_indep key domain Lq pf rd G' G o i, ← (stg_rd_head key domain Pof m hdrLen bgaOf G _ hdr core ch rs
    hrd).1, ssh_absAt_take _ _ i hi]

/-- **The plane identity at the head view of a stage reading on the run's transcript.** -/
theorem bndPlanes_head (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
    (lg : List (QB Lq × Dig)) (o : α) (j : ℕ) (p : shieldS0.Pos) (R : ℕ)
    (hg : (D.opX (j + 1)).h = 16 ∧ (D.opX (j + 1)).lc = 14 ∧ (D.opX (j + 1)).Q = 256
      ∧ (D.opX (j + 1)).e = 24448 ∧ (D.opX (j + 1)).rows = R)
    (G : QB Lq → Dig) (Pof : List Fp2 → BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G (rtTr key domain Lq pf rd G o) hdr core ch rs)
    (hj : pf.off j + 2 < hdrLen + 4) :
    bndPlanes U tag Lq h64 key domain hs hL pf rd D dPos0 lg o j p
      = Exec.Block.Join.W16.piB K (Exec.Block.Join.planeZ U 14 R 256
          (bxUxV tag Lq h64 R (pf.off j + 2) (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
            (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core))))
          ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (dPos0 p).1 (dPos0 p).2)) :=
  bndPlanes_view U tag h64 key domain hs hL pf rd D dPos0 lg o j p R hg _
    (rd_head_absAt_rtTr key domain pf rd o G _ Pof m hdrLen bgaOf hdr core ch rs hrd _ hj)

/-- **Plane `0` at the head view of a stage reading on the run's transcript is `shd_ΛI`'s `B_in` reading there.** -/
theorem bndPlanes0_head (U : K) (tag : MTag) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
    (D : RtKData K Lq) (lg : List (QB Lq × Dig)) (o : α)
    (hg : (D.opX 1).h = 16 ∧ (D.opX 1).lc = 14 ∧ (D.opX 1).Q = 256 ∧ (D.opX 1).e = 24448 ∧ (D.opX 1).rows = 38)
    (G : QB Lq → Dig) (Pof : List Fp2 → BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hdr : List Op) (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain Lq Pof m hdrLen bgaOf G (rtTr key domain Lq pf rd G o) hdr core ch rs)
    (hj : pf.off 0 + 2 < hdrLen + 4)
    (P : InPublic shieldS0) (I : IncPub) (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iA : ℕ)
    (t : shieldS0.Tok) (i : shieldS0.Wid) :
    bndPlanes U tag Lq h64 key domain hs hL pf rd D shieldDPos0 lg o 0 (t, i)
      = (shdIncData U tag h64 P I Epad (pf.off 0 + 2) iA
          (stgVw (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) lg
            (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA (Pof ch) core)))).X t
          (msbBits 12 i.val) :=
  bndPlanes0_shdIncData U tag h64 key domain hs hL pf rd D lg o hg _
    (rd_head_absAt_rtTr key domain pf rd o G _ Pof m hdrLen bgaOf hdr core ch rs hrd _ hj) P I Epad iA t i

end Plane

/-! ## 3. The concrete kinds data's closing geometries -/

section Geo

variable {Hdr : Type}
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool))
  (Lq : ℕ) (h64 : 64 ≤ Lq) (hL20 : 2 ^ 20 ≤ Lq)
  (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (Lb : ℕ) (hLb1 : 0 < Lb) (pf : RtProf) (Pk : ℕ → BlockParams)
  {blks : List (RunBlock shieldS0)} (hPkD : ShieldRunAtD tag dPos0 Pk blks Lb)
  (Vi : IncV) (F : ℕ → OutcV) (lscIn lscOut : Exec.Block.ZClaim)
  (pin pout : RtPart) (mIn kIn kOut : ℕ)
  (Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut : ℕ)
  (Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn : ℕ)
  (bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows : ℕ → ℕ)
  (P0in P0out : BlockParams)
  (csIOI csIOO : StgVw Lq → Exec.Block.Cm → Exec.Block.ZClaim → K)
  (eI eO : ℕ) (ΛI ΛO : StgVw Lq → List (List UInt8 × K) → Prop)

set_option quotPrecheck false in
local notation "RkD" =>
  shdRkD U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO

set_option quotPrecheck false in
local notation "RkD0" =>
  shdRkD0 U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut pin pout mIn kIn kOut
    Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows

omit [Fintype K] [DecidableEq K] in
/-- The closing opening of part `i + 1` of `shdRkD0` is an `rkOpen` at `rxPs`'s closing geometry. -/
theorem shdRkD0_opX_succ_g (i : ℕ) :
    ((RkD0).opX (i + 1)).h = ((rxPs (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn
        bp_nOut pXk_rows) Lb (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
        (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
        (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH)) (i + 1)).gX.h
    ∧ ((RkD0).opX (i + 1)).lc = ((rxPs (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn
        bp_nOut pXk_rows) Lb (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
        (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
        (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH)) (i + 1)).gX.lc
    ∧ ((RkD0).opX (i + 1)).Q = ((rxPs (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn
        bp_nOut pXk_rows) Lb (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
        (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
        (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH)) (i + 1)).gX.Q
    ∧ ((RkD0).opX (i + 1)).e = ((rxPs (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn
        bp_nOut pXk_rows) Lb (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
        (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
        (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH)) (i + 1)).gX.e
    ∧ ((RkD0).opX (i + 1)).rows = ((rxPs (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn
        bp_nOut pXk_rows) Lb (rxDinG ogStage pf pin.S kIn Iin_rA Iin_rH Iin_nA Iin_nH mIn)
        (fun k => rxDblk pf k (bp_S k) (Pk k).nFunctionals (bp_rA k) (bp_rH k) (bp_nA k) (bp_nH k))
        (rxDoutG ogStage pf Lb pout.S kOut Oout_rA Oout_rH Oout_nA Oout_nH)) (i + 1)).gX.rows :=
  ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- **The closing opening of part `j + 1 ≤ Lb` (block `j`'s incoming boundary) has R13's code geometry with
`pXk_rows j` rows.** -/
theorem shdRkD_opX_succ_geo (j : ℕ) (hj : j < Lb) :
    ((RkD).opX (j + 1)).h = 16 ∧ ((RkD).opX (j + 1)).lc = 14 ∧ ((RkD).opX (j + 1)).Q = 256
      ∧ ((RkD).opX (j + 1)).e = 24448 ∧ ((RkD).opX (j + 1)).rows = pXk_rows j := by
  rw [(shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (j + 1)).2.2]
  obtain ⟨g1, g2, g3, g4, g5⟩ := shdRkD0_opX_succ_g U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows j
  rw [g1, g2, g3, g4, g5, rxPs_blk _ _ _ _ _ j hj]
  have hgX : (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows
      (j + 1)).gX = rkR13 (pXk_rows j) (pf.off j + 2) := by
    rcases j with _ | k
    · exact (shdRkBaseX_1_gX (K := K) Lq Lb hLb1 pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut
        pXk_rows).1
    · exact (shdRkBaseX_blk_gX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows k
        hj).1
  dsimp only [rxSet]
  rw [hgX]
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- **The closing opening of part `Lb + 1` (`B_out`) has R13's code geometry with `Oout_rX` rows.** -/
theorem shdRkD_opX_out_geo :
    ((RkD).opX (Lb + 1)).h = 16 ∧ ((RkD).opX (Lb + 1)).lc = 14 ∧ ((RkD).opX (Lb + 1)).Q = 256
      ∧ ((RkD).opX (Lb + 1)).e = 24448 ∧ ((RkD).opX (Lb + 1)).rows = Oout_rX := by
  rw [(shdRkD_ops_eq_D0 U hbij tag dPos0 Lq h64 hL20 key domain hs hL Lb hLb1 pf Pk hPkD Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn
    bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows P0in P0out csIOI csIOO eI eO ΛI ΛO (Lb + 1)).2.2]
  obtain ⟨g1, g2, g3, g4, g5⟩ := shdRkD0_opX_succ_g U tag Lq h64 key domain hs hL Lb pf Pk Vi F lscIn lscOut
    pin pout mIn kIn kOut Iin_rA Iin_rH Iin_rX Iin_nA Iin_nH Iin_nIn Iin_nOut
    Oout_rA Oout_rH Oout_rX Oout_nA Oout_nH Oout_nIn bp_S bp_rA bp_rH bp_nA bp_nH bp_nIn bp_nOut pXk_rows Lb
  rw [g1, g2, g3, g4, g5, rxPs_out]
  have hgX : (shdRkBaseX (K := K) Lq Lb pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut pXk_rows
      (Lb + 1)).gX = rkR13 Oout_rX (pf.off Lb + 2) := by
    obtain ⟨k, rfl⟩ : ∃ k, Lb = k + 1 := ⟨Lb - 1, by omega⟩
    exact (shdRkBaseX_out_gX (K := K) Lq (k + 1) pf Iin_rX Iin_nIn Iin_nOut Oout_rX Oout_nIn bp_nIn bp_nOut
      pXk_rows k rfl).1
  dsimp only [rxSet]
  rw [hgX]
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

end Geo

end ZK60.ProtocolClassify
