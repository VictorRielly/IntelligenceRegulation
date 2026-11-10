/-
D63 lane L43 (2026-11-10), part 1: **the run's kinds data `D` built from the verifier's own readers** (L39 §5 item 1;
gap audit register row 7: `D` was free data).

L34's `RtKData` holds, part by part, the sub-protocols the nine kinds speak of. Its side conditions (`RtKData.Valid`)
are counts and bounds; nothing tied its readers (an opening's claims, an opening's matrix, `M`'s functionals and table)
to what the run verifier reads, so any `D` meeting the counts could be put in the top theorem, and the `hal_*` could
not be proved of it. Here `D` is BUILT from the readers the verifier uses:

* `RkGeo`, `RkGeo.Ok`, `rkR13`, **`rkR13_ok`**: a regular opening's geometry at the run (with the position `ipos` at
  which the run's transcript absorbs the opened root); R13's `(16, 256, 24448)` meets the conditions;
* **`rkOpen`**: an opening whose claims are `oclOf` of `group_zclaims` of a claim list read off the transcript header
  (L28's `clOfO`), and whose matrix is the one extracted from the prover's log for the root the header absorbs at
  `ipos` (L28's `UxW`, L22's `colX`); **`rkOpen_cut`**, **`rkOpen_valid`**;
* `rkColsM`, **`rkMask`**: `M`'s data `mDataOf` of a functional list read off the header and the table extracted for
  `M`'s root (L28's `DmW`); **`rkMask_cut`**;
* `RkPart`: one part's schedule data (counts, geometries, root positions, slots, squeeze runs); `rkPend`;
* **`rkData`**: `D` from the parts and ONE accumulator reader per part (`acc i`: the part's slot phase read off the
  transcript, as the verifier accumulates it). For EVERY part (stage IN-C, a block, stage OUT-C) the verifier checks:
  `M` on `acc.fs ++ acc.hostFs`; `A` on `acc.claims.a`; `H` on `acc.claims.h ++ [the LogUp sum claim]`; the closing
  commitment on the claims the previous part left pending (`acc_{i-1}.claims.out`; none before stage IN-C) followed by
  `acc.claims.inp` (StageVerifyExec.lean's `IncV.verify`, `OutcV.verify`, ProtocolClassify.lean's `blockSeg`);
* `RkPart.Ok`, `RkSqOk`, `rk_w_le`, **`rkData_valid`**: `hD` from the parts' numeric facts (the cut reading of every
  extraction PROVED, the batching widths' bound from the profile's validity);
* **`rkData_opA_cl`**, **`rkData_opH_cl`**, **`rkData_opX_cl`**, **`rkData_msk_Dm`**: what each reader returns when the
  part's accumulator reader returns an accumulator `a` (the bridge to "what the verifier checked", used by
  `RunKindsDataBlk.lean` and the `hal_*`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCoverParse

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## A regular opening's geometry at the run -/

/-- **A regular opening's geometry at the run**: codewords of `2^h` symbols, `Q` queries and pads, decoding radius `e`,
`rows` rows, `mI` index squeezes, and the position `ipos` at which the run's transcript absorbs the opened root. -/
structure RkGeo where
  h : ℕ
  Q : ℕ
  e : ℕ
  rows : ℕ
  mI : ℕ
  hQm : Q ≤ mI * 4
  ipos : ℕ

/-- **The geometry's numeric conditions** (`RtOpen.Valid` but the batching bound and the cut reading). -/
structure RkGeo.Ok (g : RkGeo) : Prop where
  hh : g.h ≤ 16
  hQ0 : 0 < g.Q
  he : 2 * g.e + (2 ^ 14 + g.Q) ≤ 2 ^ g.h
  hεB : (((Fintype.card (Fin (2 ^ g.h)) - (g.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ g.h))) ^ g.Q * 1
    ≤ (2⁻¹ : ℝ≥0∞) ^ 126

/-- **R13's geometry** (the media app's profile, L28): codewords of `2^16`, `256` queries and pads, radius `24448`, `64`
index squeezes (`(256 + 3) / 4`). -/
def rkR13 (rows ipos : ℕ) : RkGeo := ⟨16, 256, 24448, rows, 64, by norm_num, ipos⟩

/-- R13's geometry meets the conditions (`2·24448 + 2^14 + 256 = 2^16`; the column round within `2^-126`). -/
theorem rkR13_ok (rows ipos : ℕ) : (rkR13 rows ipos).Ok where
  hh := le_rfl
  hQ0 := by norm_num [rkR13]
  he := by norm_num [rkR13]
  hεB := rtOpen_r13_epsB

/-! ## The readers -/

section Readers

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **A regular opening of the run from the verifier's readers**: its claims at its window are `oclOf` of
`group_zclaims` of the claim list `clr` reads off the transcript header (L28's `clOfO`), its matrix is the one
extracted from the prover's log for the root the header absorbs at `g.ipos` (L28's `UxW`), its group vectors are read
at `vpos`. -/
noncomputable def rkOpen (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) :
    RtOpen K Lq where
  h := g.h
  Q := g.Q
  e := g.e
  rows := g.rows
  nC := nC
  mI := g.mI
  hQm := g.hQm
  cl hdr := oclOf U g.rows 14 g.Q nC (groupZclaims ((clr hdr).map toZClaim) g.rows 14)
  Ux P hdr := UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P hdr
  vpos := vpos

/-- **The opening's extracted matrix is a cut reader** (L22's `colX` reads the log cut at the root the header
absorbs: `colX_cutEq`). -/
theorem rkOpen_cut (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).Ux := by
  intro P P' hdr h
  funext r j
  show UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P hdr r j
    = UxW tag Lq h64 key domain hs hL g.h g.ipos g.rows P' hdr r j
  unfold UxW
  rw [colX_cutEq tag h64 key domain hs hL g.h g.ipos hdr P P' h]

/-- **The opening meets `RtOpen.Valid`** when its geometry meets the conditions and its batching run is at most `2^61`
wide. -/
theorem rkOpen_valid (g : RkGeo) (hg : g.Ok) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim) (vpos : ℕ)
    (hw : nC + g.rows ≤ 2 ^ 61) :
    (rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) :=
  ⟨hg.hh, hg.hQ0, hg.he, hw, hg.hεB, rkOpen_cut U tag Lq h64 key domain hs hL g nC clr vpos⟩

/-- **`M`'s extracted table**: the column at each index, extracted for the root the header absorbs at `mpos` (depth
`12`; L28's `colsM` at a run position). -/
noncomputable def rkColsM (mpos : ℕ) (P : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) : Fin (2 ^ 12) → List Fp :=
  fun j => ((colX tag Lq h64 key domain hs hL 12 mpos P hdr j).map Subtype.val).getD []

/-- **`M` of the run from the verifier's readers**: `mDataOf` of the functional list `fsr` reads off the header and the
table extracted for `M`'s root (L28's `DmW`). -/
noncomputable def rkMask (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional) : RtMask K Lq where
  S := S
  k := k
  Dm P hdr := mDataOf U S k (fsr hdr) (rkColsM tag Lq h64 key domain hs hL mpos P hdr)

/-- **`M`'s data is a cut reader.** -/
theorem rkMask_cut (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional) :
    CutReads (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (rkMask U tag Lq h64 key domain hs hL S k mpos fsr).Dm := by
  intro P P' hdr h
  have e : rkColsM tag Lq h64 key domain hs hL mpos P hdr = rkColsM tag Lq h64 key domain hs hL mpos P' hdr := by
    funext j
    unfold rkColsM
    rw [colX_cutEq tag h64 key domain hs hL 12 mpos hdr P P' h]
  show mDataOf U S k (fsr hdr) (rkColsM tag Lq h64 key domain hs hL mpos P hdr)
    = mDataOf U S k (fsr hdr) (rkColsM tag Lq h64 key domain hs hL mpos P' hdr)
  rw [e]

end Readers

/-! ## The parts and `D` -/

/-- **One part's schedule data** besides the accumulator's reader: `M`'s mask-spec and functional counts and the
position of `M`'s root; the three openings' geometries (with their roots' positions) and claim counts; the part's
sumcheck slots and squeeze runs (two relation schedules, two host schedules, LogUp). -/
structure RkPart (K : Type) (Lq : ℕ) where
  S : ℕ
  k : ℕ
  mpos : ℕ
  gA : RkGeo
  gH : RkGeo
  gX : RkGeo
  nA : ℕ
  nH : ℕ
  nX : ℕ
  sls : List (SlotX K Lq)
  r0 : List (SqX K Lq)
  r1 : List (SqX K Lq)
  h0 : List (SqX K Lq)
  h1 : List (SqX K Lq)
  lu : List (SqX K Lq)

/-- **The claims pending on part `i`'s closing commitment**, left by the part before: none before stage IN-C (stage IN-C
ignores the carry), else the previous part's outgoing claims (`acc_{i-1}.claims.out`: stage IN-C's claims on `B_in`, a
block's on its output boundary). -/
def rkPend (acc : ℕ → List (TItem × Dig) → Block.Acc) : ℕ → List (TItem × Dig) → List Block.ZClaim
  | 0, _ => []
  | i + 1, hdr => (acc i hdr).claims.out

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **THE RUN'S KINDS DATA FROM THE VERIFIER'S READERS.** Part `i`'s `M` checks the functionals `acc i` reads
(`fs ++ hostFs`); its `A` the claims `(acc i).claims.a`; its `H` `(acc i).claims.h ++ [lsc i]`; its closing commitment
`rkPend acc i ++ (acc i).claims.inp`; every matrix and table is the one extracted for the root the run's transcript
absorbs at the part's positions; the group vectors are read after each batching run. -/
noncomputable def rkData (pf : RtProf) (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc)
    (lsc : ℕ → Block.ZClaim) (eL : ℕ) : RtKData K Lq where
  sls i := (ps i).sls
  msk i := rkMask U tag Lq h64 key domain hs hL (ps i).S (ps i).k (ps i).mpos
    (fun hdr => (acc i hdr).fs ++ (acc i hdr).hostFs)
  opA i := rkOpen U tag Lq h64 key domain hs hL (ps i).gA (ps i).nA (fun hdr => (acc i hdr).claims.a)
    (pf.off i + (pf.part i).oA + ((ps i).nA + (ps i).gA.rows))
  opH i := rkOpen U tag Lq h64 key domain hs hL (ps i).gH (ps i).nH (fun hdr => (acc i hdr).claims.h ++ [lsc i])
    (pf.off i + (pf.part i).oH + ((ps i).nH + (ps i).gH.rows))
  opX i := rkOpen U tag Lq h64 key domain hs hL (ps i).gX (ps i).nX
    (fun hdr => rkPend acc i hdr ++ (acc i hdr).claims.inp)
    (pf.off i + (pf.part i).oX + ((ps i).nX + (ps i).gX.rows))
  r0 i := (ps i).r0
  r1 i := (ps i).r1
  h0 i := (ps i).h0
  h1 i := (ps i).h1
  lu i := (ps i).lu
  eL := eL

/-! ### What the readers return -/

variable (pf : RtProf) (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim)
  (eL : ℕ)

/-- **`A`'s claims at a header are those of the accumulator the part's reader returns there.** -/
theorem rkData_opA_cl (i : ℕ) (hdr : List (TItem × Dig)) (a : Block.Acc) (h : acc i hdr = a) :
    ((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opA i).cl hdr
      = oclOf U (ps i).gA.rows 14 (ps i).gA.Q (ps i).nA (groupZclaims (a.claims.a.map toZClaim) (ps i).gA.rows 14) := by
  show oclOf U (ps i).gA.rows 14 (ps i).gA.Q (ps i).nA
      (groupZclaims ((acc i hdr).claims.a.map toZClaim) (ps i).gA.rows 14) = _
  rw [h]

/-- **`H`'s claims** (with the part's LogUp sum claim, as the verifier passes them). -/
theorem rkData_opH_cl (i : ℕ) (hdr : List (TItem × Dig)) (a : Block.Acc) (h : acc i hdr = a) :
    ((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opH i).cl hdr
      = oclOf U (ps i).gH.rows 14 (ps i).gH.Q (ps i).nH
          (groupZclaims ((a.claims.h ++ [lsc i]).map toZClaim) (ps i).gH.rows 14) := by
  show oclOf U (ps i).gH.rows 14 (ps i).gH.Q (ps i).nH
      (groupZclaims (((acc i hdr).claims.h ++ [lsc i]).map toZClaim) (ps i).gH.rows 14) = _
  rw [h]

/-- **The closing commitment's claims**: the previous part's outgoing claims, then the part's incoming ones. -/
theorem rkData_opX_cl (i : ℕ) (hdr : List (TItem × Dig)) (pend : List Block.ZClaim) (a : Block.Acc)
    (hp : rkPend acc i hdr = pend) (h : acc i hdr = a) :
    ((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).opX i).cl hdr
      = oclOf U (ps i).gX.rows 14 (ps i).gX.Q (ps i).nX
          (groupZclaims ((pend ++ a.claims.inp).map toZClaim) (ps i).gX.rows 14) := by
  show oclOf U (ps i).gX.rows 14 (ps i).gX.Q (ps i).nX
      (groupZclaims ((rkPend acc i hdr ++ (acc i hdr).claims.inp).map toZClaim) (ps i).gX.rows 14) = _
  rw [hp, h]

/-- **`M`'s data**: `mDataOf` of the accumulator's functionals and the extracted table. -/
theorem rkData_msk_Dm (i : ℕ) (P : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) (a : Block.Acc)
    (h : acc i hdr = a) :
    ((rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).msk i).Dm P hdr
      = mDataOf U (ps i).S (ps i).k (a.fs ++ a.hostFs) (rkColsM tag Lq h64 key domain hs hL (ps i).mpos P hdr) := by
  show mDataOf U (ps i).S (ps i).k ((acc i hdr).fs ++ (acc i hdr).hostFs)
      (rkColsM tag Lq h64 key domain hs hL (ps i).mpos P hdr) = _
  rw [h]

end Data

/-! ## `hD` from the parts' facts -/

section Valid

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- A part's squeeze runs meet a squeeze kind's conditions between the part's offsets. -/
def RkSqOk {Lq : ℕ} (absOf : QB Lq → Option (List UInt8)) (lo hi emax ND : ℕ) (sxs : List (SqX K Lq)) : Prop :=
  (∀ sx ∈ sxs, SqCut absOf sx ∧ sx.Rbr ∧ sx.e ≤ emax ∧ sx.n * sx.e ≤ ND ∧ lo ≤ sx.a ∧ sx.a ≤ hi)
    ∧ sxs.Pairwise (fun a b => a.a ≤ b.a)

/-- **One part's numeric facts at a profile** (part `i`): the slots' statements cut readers, degree `≤ 7`, `n·d ≤
7·370`, windows in the part; `M`'s counts, `S` the profile's; the openings' geometries meet the conditions, their
batching widths and index squeezes are the profile's; the squeeze runs meet their kinds' conditions in the part. -/
structure RkPart.Ok {Lq : ℕ} (absOf : QB Lq → Option (List UInt8)) (pf : RtProf) (eL i : ℕ) (p : RkPart K Lq) :
    Prop where
  slCut : ∀ sl ∈ p.sls, CutReads absOf sl.stmt
  slDeg : ∀ sl ∈ p.sls, sl.d < gP ∧ sl.d ≤ 7 ∧ sl.n * sl.d ≤ 7 * 370
  slWin : ∀ (k : ℕ) (sl : SlotX K Lq), p.sls[k]? = some sl →
    pf.off i ≤ slotsLenX (p.sls.take k) + sl.s ∧ slotsLenX (p.sls.take k) + sl.s ≤ pf.off (i + 1)
  mK : 0 < p.k ∧ p.k ≤ 2 ^ 20 ∧ 2 * p.S + 2 ≤ 2 ^ 20
  mS : p.S = (pf.part i).S
  gA : p.gA.Ok
  gH : p.gH.Ok
  gX : p.gX.Ok
  wA : p.nA + p.gA.rows = (pf.part i).wA ∧ p.gA.mI = (pf.part i).mA
  wH : p.nH + p.gH.rows = (pf.part i).wH ∧ p.gH.mI = (pf.part i).mH
  wX : p.nX + p.gX.rows = (pf.part i).wX ∧ p.gX.mI = (pf.part i).mX
  r0 : RkSqOk absOf (pf.off i) (pf.off (i + 1)) 80 (80 * 451) p.r0
  r1 : RkSqOk absOf (pf.off i) (pf.off (i + 1)) 80 (80 * 451) p.r1
  h0 : RkSqOk absOf (pf.off i) (pf.off (i + 1)) 80 (80 * 451) p.h0
  h1 : RkSqOk absOf (pf.off i) (pf.off (i + 1)) 80 (80 * 451) p.h1
  lu : RkSqOk absOf (pf.off i) (pf.off (i + 1)) eL (3 * eL) p.lu

/-- **Every batching width of a part is at most `2^61`** on a valid profile (each is one of the profile's squeeze
runs). -/
theorem rk_w_le (pf : RtProf) (hv : pf.Valid) (i : ℕ) (hi : i < pf.parts.length) :
    (pf.part i).wA ≤ 2 ^ 61 ∧ (pf.part i).wH ≤ 2 ^ 61 ∧ (pf.part i).wX ≤ 2 ^ 61 := by
  have hmem : pf.part i ∈ pf.parts := by
    unfold RtProf.part
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi]
    exact List.getElem_mem hi
  have hsub : ∀ n ∈ (pf.part i).sqs, n ∈ pf.sqs := fun n hn => by
    unfold RtProf.sqs
    exact List.mem_append_right _ (List.mem_flatMap.mpr ⟨pf.part i, hmem, hn⟩)
  refine ⟨hv.le _ (hsub _ ?_), hv.le _ (hsub _ ?_), hv.le _ (hsub _ ?_)⟩ <;>
    simp [RtPart.sqs]

variable (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [DecidableEq K] in
/-- **`hD` FOR THE KINDS DATA BUILT FROM THE VERIFIER'S READERS**: on a valid profile, if `K` has `p²` elements, every
part meets its numeric facts and LogUp's escape count is at most `2^26`, then `rkData … ` meets `RtKData.Valid`. The
cut reading of every opening's matrix and `M`'s table is PROVED (`rkOpen_cut`, `rkMask_cut`), the batching widths'
bound comes from the profile (`rk_w_le`). -/
theorem rkData_valid (pf : RtProf) (hv : pf.Valid) (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc)
    (lsc : ℕ → Block.ZClaim) (eL : ℕ) (hK : Fintype.card K = gP ^ 2)
    (hp : ∀ i, i < pf.parts.length → (ps i).Ok (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf eL i)
    (heL : eL ≤ 2 ^ 26) :
    (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf where
  hK := hK
  slCut := fun i hi => (hp i hi).slCut
  slDeg := fun i hi => (hp i hi).slDeg
  slWin := fun i hi => (hp i hi).slWin
  mK := fun i hi => (hp i hi).mK
  mCut := fun i _ => rkMask_cut U tag Lq h64 key domain hs hL _ _ _ _
  mS := fun i hi => (hp i hi).mS
  opV := fun i hi => by
    have hw := rk_w_le pf hv i hi
    refine ⟨rkOpen_valid U tag Lq h64 key domain hs hL _ (hp i hi).gA _ _ _ ?_,
      rkOpen_valid U tag Lq h64 key domain hs hL _ (hp i hi).gH _ _ _ ?_,
      rkOpen_valid U tag Lq h64 key domain hs hL _ (hp i hi).gX _ _ _ ?_⟩
    · rw [(hp i hi).wA.1]
      exact hw.1
    · rw [(hp i hi).wH.1]
      exact hw.2.1
    · rw [(hp i hi).wX.1]
      exact hw.2.2
  opW := fun i hi => ⟨(hp i hi).wA, (hp i hi).wH, (hp i hi).wX⟩
  r0 := fun i hi => ⟨fun sx h => (hp i hi).r0.1 sx h, (hp i hi).r0.2⟩
  r1 := fun i hi => ⟨fun sx h => (hp i hi).r1.1 sx h, (hp i hi).r1.2⟩
  h0 := fun i hi => ⟨fun sx h => (hp i hi).h0.1 sx h, (hp i hi).h0.2⟩
  h1 := fun i hi => ⟨fun sx h => (hp i hi).h1.1 sx h, (hp i hi).h1.2⟩
  lu := fun i hi => ⟨fun sx h => (hp i hi).lu.1 sx h, (hp i hi).lu.2⟩
  heL := heL

end Valid

end ZK60.ProtocolClassify
