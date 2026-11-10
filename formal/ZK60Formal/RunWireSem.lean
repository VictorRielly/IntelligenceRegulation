/-
D63 lane L54 (2026-11-10), part 1: **the run-level `hsem`** (the brief's deliverable 1; lane L50 §5 (a), lane L28's
`hsem_geo` carried from one block's own chain to the classify run).

On the run's transcript, a regular opening whose first half (`opA`) did not enter its window doomed is in its good
case (`GroupsGood`: the extracted matrix is close to the code and EVERY claim it checks is true of the decoded matrix),
and `M` whose sub-protocol did not enter its window doomed is in its good case (`MGood`: every functional it checks is
true of the decoded mask table). The run's kinds data `ebData` (lanes L43, L52) reads, at block part `k + 1`, exactly
the block's own accumulator: `A` checks `acc.claims.a`, `H` checks `acc.claims.h` (and the LogUp sum claim), the part's
closing opening checks the previous part's outgoing claims and `acc.claims.inp`, and the NEXT part's closing opening
checks `acc.claims.out` (finding L46-1). So "no doomed `opA` and no doomed `M` entrant" makes the block's accumulator's
claims and functionals true of the run's extracted data:

* `wrOSem`: a claim's value on an opening's decoded extracted matrix (lane L28's `claimSem` at the opening's own code
  `encGL lc h Q` and radius);
* `wrCs`, `wrMs`: the claims' and the functionals' semantics of block part `i` on the run (`A`, `H`, the part's closing
  opening, the next part's closing opening; `M`'s decoded table);
* **`wr_opA_good`**, **`wr_rkOpen_sem`**: one opening, no doomed `opA` entrant ⇒ `GroupsGood` ⇒ its claims true;
* **`wr_rkMask_sem`**: one `M`, no doomed entrant ⇒ `MGood` ⇒ its functionals true;
* `wr_ndA`, `wr_ndM`: the kinds `rtKA`, `rtKM` without a doomed entrant give no doomed entrant at each part's openings
  and `M`;
* `wr_allOps_len`, **`wr_acc_rd`**: EVERY reading of block `k` on the transcript (a header of the block's length, a core
  of the block's shape whose slot phase accepted, the transcript the trace of the block's operations and more) has the
  accumulator the run's reader `rxAcc (k + 1)` returns at every window after the slot phase (L31's `tAccRd_trace`);
* **`wr_hsem`**: THE RUN-LEVEL `hsem`, deterministic: with the openings' and `M`'s acceptance facts at their windows
  (`RhOpW`, `RhMW`, lane L43) and no doomed `opA` and `M` entrant, at every block `k < Lb` and every reading of it,
  `ClaimsTrue` (all four commitments) and `MTrue` (`fs ++ hostFs`) for the reading's accumulator;
* **`wr_hsem_acc`**: the same ON AN ACCEPTED RUN OUTSIDE THE RUN'S EXTRACTION EVENTS, with the acceptance facts
  discharged (lane L45 / L48's `rx_parts_AHG`, `rx_parts_MG`; the closing openings of parts `1` on by the top theorem's
  premise `hopX1`, lane L55's area).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunEpBTopT

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

/-! ## The semantics of the run's extracted data -/

section Sem

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **A claim's value on an opening's decoded extracted matrix**: lane L28's `claimSem` on the rows `decodeRows` gives
for the matrix the opening extracts from the log `lg` at the header `hdr`, at the opening's own code and radius. -/
noncomputable def wrOSem (U : K) (o : RtOpen K Lq) (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig))
    (z : Block.ZClaim) : K :=
  claimSem U o.rows o.lc o.Q (decodeRows (encGL (K := K) o.lc o.h o.Q) o.e (o.Ux lg hdr)) z

/-- **The claims' semantics of part `i` on the run**: `A`'s and `H`'s claims on the part's `A`, `H` openings' decoded
extracted matrices at their windows; its incoming claims on its closing opening's; its outgoing claims on the NEXT
part's closing opening's (finding L46-1). -/
noncomputable def wrCs (U : K) (D : RtKData K Lq) (pf : RtProf) (i : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) : Block.Cm → Block.ZClaim → K
  | .a => wrOSem U (D.opA i) lg (τ.take (pf.off i + (pf.part i).oA))
  | .h => wrOSem U (D.opH i) lg (τ.take (pf.off i + (pf.part i).oH))
  | .inp => wrOSem U (D.opX i) lg (τ.take (pf.off i + (pf.part i).oX))
  | .out => wrOSem U (D.opX (i + 1)) lg (τ.take (pf.off (i + 1) + (pf.part (i + 1)).oX))

/-- **The functionals' semantics of part `i` on the run**: lane L28's `msOfTab` on `M`'s table extracted at the part's
`M` root, read at `M`'s window. -/
noncomputable def wrMs (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (ps : ℕ → RkPart K Lq)
    (pf : RtProf) (i : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : List (ℕ × List Fp2) → K :=
  msOfTab U (ps i).S (rkColsM tag Lq h64 key domain hs hL (ps i).mpos lg (τ.take (pf.off i + (pf.part i).pre)))

end Sem

/-! ## One opening, one `M`: no doomed entrant makes its claims true -/

section One

/-- **An opening whose first half did not enter its window doomed is in its good case**: at its window `aO` (a step's
end inside the transcript) the extracted matrix is close to the code and every claim it checks holds of the decoded
matrix (`opA`'s state with no round read, L20's `opASt`). -/
theorem wr_opA_good {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) {Lq : ℕ} (o : RtOpen K Lq) (W : UInt64 → ℕ) (aO : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hnd : ¬ EntD W (o.opA U hbij aO lg) τ)
    (hle : aO ≤ τ.length) (hpre : tRem W (τ.take aO) = some 0) :
    GroupsGood (encGL (K := K) o.lc o.h o.Q) o.e (o.Ux lg (τ.take aO)) (o.cl (τ.take aO)).rw
      (o.cl (τ.take aO)).cw (o.cl (τ.take aO)).grp (o.cl (τ.take aO)).val := by
  by_contra hg
  exact hnd ⟨hle, hpre, hg⟩

/-- **An opening of the run's kinds data (`rkOpen`) whose first half did not enter doomed makes every claim it checks
true** of its decoded extracted matrix (L28's `groupsGood_claimSem` at the run). -/
theorem wr_rkOpen_sem {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
    (vpos : ℕ) (W : UInt64 → ℕ) (aO : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hnd : ¬ EntD W ((rkOpen U tag Lq h64 key domain hs hL g nC clr vpos).opA U hbij aO lg) τ)
    (hle : aO ≤ τ.length) (hpre : tRem W (τ.take aO) = some 0) (hcnt : (clr (τ.take aO)).length = nC) :
    ∀ z ∈ clr (τ.take aO),
      wrOSem U (rkOpen U tag Lq h64 key domain hs hL g nC clr vpos) lg (τ.take aO) z = z.value.toK U :=
  groupsGood_claimSem U g.rows g.lc g.Q (encGL (K := K) g.lc g.h g.Q) g.e _ (clr (τ.take aO)) nC hcnt
    (wr_opA_good U hbij _ W aO lg τ hnd hle hpre)

/-- **A run's `M` (`rkMask`) whose sub-protocol did not enter its window doomed makes every functional it checks true**
of the decoded extracted mask table (L28's `mGood_mTrue'` at the run). -/
theorem wr_rkMask_sem {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional)
    (W : UInt64 → ℕ) (a : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hnd : ¬ EntD W ((rkMask U tag Lq h64 key domain hs hL S k mpos fsr).sub U hbij a lg) τ)
    (hle : a ≤ τ.length) (hpre : tRem W (τ.take a) = some 0) (hk : (fsr (τ.take a)).length = k) :
    ∀ mf ∈ fsr (τ.take a),
      msOfTab U S (rkColsM tag Lq h64 key domain hs hL mpos lg (τ.take a)) mf.terms = mf.value.toK U := by
  have hg : ((rkMask U tag Lq h64 key domain hs hL S k mpos fsr).sub U hbij a lg).St (τ.take a) [] := by
    by_contra h
    exact hnd ⟨hle, hpre, h⟩
  exact mGood_mTrue' U S (fsr (τ.take a)) k hk (rkColsM tag Lq h64 key domain hs hL mpos lg (τ.take a)) hg

end One

/-! ## No doomed entrant of the kinds, part by part -/

section Kinds

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **No doomed `opA` entrant of the kind ⇒ none at part `i`'s three openings.** -/
theorem wr_ndA (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hA : ¬ (rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) (i : ℕ) (hi : i < pf.parts.length)
    (hn : pf.parts.length ≤ n) :
    ∀ x ∈ rtOps pf D i, ¬ EntD (rtW pf.sqs) (x.1.opA U hbij x.2.1 lg) τ := by
  intro x hx he
  apply hA
  refine ⟨i, by omega, x.1.opA U hbij x.2.1 lg, ?_, he⟩
  simp only [rtKA, rtKind2, dite_eq_left hi, RtKPart.ofOpA, RtKPart.ofMap]
  exact List.mem_map.mpr ⟨x, hx, rfl⟩

/-- **No doomed `M` entrant of the kind ⇒ none at part `i`'s `M`.** -/
theorem wr_ndM (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hM : ¬ (rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) (i : ℕ) (hi : i < pf.parts.length)
    (hn : pf.parts.length ≤ n) :
    ¬ EntD (rtW pf.sqs) ((D.msk i).sub U hbij (pf.off i + (pf.part i).pre) lg) τ := by
  intro he
  apply hM
  refine ⟨i, by omega, (D.msk i).sub U hbij (pf.off i + (pf.part i).pre) lg, ?_, he⟩
  simp only [rtKM, rtKind2, dite_eq_left hi, RtKPart.ofMask, RtKPart.ofMap]
  exact List.mem_map.mpr ⟨(), by simp, rfl⟩

end Kinds

/-! ## Every reading of a block has the run reader's accumulator -/

section Read

/-- **The block's operations up to the slot loop's end have the shape's length** (`hdr`, the roots' ten, every whole
slot as the shape counts it). -/
theorem wr_allOps_len (P : Block.BlockParams) (hgt : P.geom.slots.length = P.geom.terms.length)
    (hdr : List Op) (core : Block.Core) (hsh : Block.CoreShape P.geom core) :
    (Block.allOps P (hdr, core)).length = hdr.length + (10 + shapeLen P 0 P.geom.slots) := by
  have hr : ∀ (i : ℕ) (sp : Block.SlotProof) (s : ℕ × ℕ × ℕ), core.slots[i]? = some sp →
      P.geom.slots[i]? = some s → sp.rounds.length = s.1 + s.2.1 := by
    intro i sp s h1 h2
    have hi : i < P.geom.terms.length := by
      rw [← hgt]
      exact (List.getElem?_eq_some_iff.mp h2).1
    exact (hsh.2.1 i sp s _ h1 h2 (List.getElem?_eq_getElem hi)).1
  have hf := (full_shape P 0 core.slots P.geom.slots hsh.1 hr).1
  show (hdr ++ Block.rootOps P core ++ Block.fullOps P 0 core.slots).length = _
  rw [List.length_append, List.length_append, Link.rootOps_length, Link.fullOps_length, hf]
  omega

/-- **EVERY READING OF BLOCK `P` AT `hdrLen` ON A TRANSCRIPT HAS THE ACCUMULATOR L31'S READER RETURNS THERE**: if the
slot phase accepted after a header `hdr` of length `hdrLen` on a core of the block's shape (`SlotsAcc`) and `τ` is the
trace of the block's operations followed by more, then `tAccRd` of `τ` cut at the slot loop's end (`hdrLen + 10` and the
shape's slot operations) is the reading's accumulator. -/
theorem wr_acc_rd (key : Option Dig) (domain : List UInt8) {Lq : ℕ} (P : Block.BlockParams) (hdrLen : ℕ)
    (G : QB Lq → Dig) (hgt : P.geom.slots.length = P.geom.terms.length)
    (hd : ∀ j, j < P.geom.slots.length → 1 ≤ (Block.slotShape P j).2.2)
    (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (T : List Op) (hsa : Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc) (τ : List (TItem × Dig))
    (htr : τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T)) :
    Block.tAccRd P hdrLen (τ.take (hdrLen + (10 + shapeLen P 0 P.geom.slots))) = acc := by
  obtain ⟨hl, -, hcan, hsh, t', hbs⟩ := hsa
  have hl' : hdr.length = hdrLen := hl
  have hlen := wr_allOps_len P hgt hdr core hsh
  rw [hl'] at hlen
  have hτ : τ.take (Block.allOps P (hdr, core)).length
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core)) := by
    rw [htr, Block.opTrace_append, List.take_left' (Block.opTrace_length _ _ _)]
  have h := Block.tAccRd_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) bga rs acc t' hcan hsh.1 hd
    hbs
  rw [hl'] at h
  rw [← hlen, hτ]
  exact h

end Read

/-! ## The run-level `hsem` -/

section Hsem

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag)
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)
  (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **THE RUN-LEVEL `hsem`** (deterministic). On a transcript `τ` of the classify run at which every part's `A` and `H`
(`hAH`), every closing opening of parts `1` on (`hX`) and every `M` (`hMW`) meet their acceptance facts at their windows
(lane L43's `RhOpW`, `RhMW`: the windows are step ends inside `τ`, the readers return claim lists of the opening's
count), if no `opA` and no `M` entered its window doomed (`hA`, `hM`: the ordered cover's hypotheses `¬ rtKA.Dm`,
`¬ rtKM.Dm`), then at every block `k < Lb` and EVERY reading of block `k` on `τ` (at the block's run position
`off (k + 1) + 5`), the reading's accumulator has
* every claim TRUE of the run's extracted data (`wrCs`): `A`'s and `H`'s of the part's `A`, `H` openings' decoded
  matrices; the incoming ones of the part's closing opening's; the outgoing ones of the NEXT part's closing opening's;
* every functional (`fs` and `hostFs`) TRUE of `M`'s decoded table (`wrMs`). -/
theorem wr_hsem
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (rdx : List UInt8 → Option Dig) (ps : ℕ → RkPart K Lq) (Win : List (TItem × Dig) → IncV)
    (Wout : List (TItem × Dig) → OutcV) (lsc : ℕ → Block.ZClaim) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx R.pf ps (rxAcc Win Wout Pk R.pf Lb) lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (hAH : ∀ i, i < R.pf.parts.length →
      Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).gA (ps i).nA
          (fun hdr => (rxAcc Win Wout Pk R.pf Lb i hdr).claims.a) (R.pf.off i + (R.pf.part i).oA)
          (R.pf.off i + (R.pf.part i).oBA) (R.pf.off i + (R.pf.part i).oA + ((ps i).nA + (ps i).gA.rows)) lg G τ)
        ∧ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).gH (ps i).nH
          (fun hdr => (rxAcc Win Wout Pk R.pf Lb i hdr).claims.h ++ [lsc i]) (R.pf.off i + (R.pf.part i).oH)
          (R.pf.off i + (R.pf.part i).oBH) (R.pf.off i + (R.pf.part i).oH + ((ps i).nH + (ps i).gH.rows)) lg G τ))
    (hX : ∀ i, 0 < i → i < R.pf.parts.length →
      Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).gX (ps i).nX
        (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) i hdr ++ (rxAcc Win Wout Pk R.pf Lb i hdr).claims.inp)
        (R.pf.off i + (R.pf.part i).oX) (R.pf.off i + (R.pf.part i).oBX)
        (R.pf.off i + (R.pf.part i).oX + ((ps i).nX + (ps i).gX.rows)) lg G τ))
    (hMW : ∀ i, i < R.pf.parts.length →
      Nonempty (RhMW tag Lq h64 key domain hs hL (rtW R.pf.sqs) (ps i).S (ps i).k (ps i).mpos
        (fun hdr => (rxAcc Win Wout Pk R.pf Lb i hdr).fs ++ (rxAcc Win Wout Pk R.pf Lb i hdr).hostFs)
        (R.pf.off i + (R.pf.part i).pre) lg G τ))
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij
      (ebData U tag Lq h64 key domain hs hL rdx R.pf ps (rxAcc Win Wout Pk R.pf Lb) lsc eL) hD).Dm n lg τ)
    (hM : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij
      (ebData U tag Lq h64 key domain hs hL rdx R.pf ps (rxAcc Win Wout Pk R.pf Lb) lsc eL) hD).Dm n lg τ) :
    ∀ k, k < Lb → ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op),
      Block.SlotsAcc key domain (Pk k) (R.pf.off (k + 1) + 5) G (hdr, core) bga rs acc →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps (Pk k) (hdr, core) ++ T) →
      Block.ClaimsTrue U (wrCs U (ebData U tag Lq h64 key domain hs hL rdx R.pf ps (rxAcc Win Wout Pk R.pf Lb) lsc eL)
          R.pf (k + 1) lg τ) acc.claims
        ∧ Block.MTrue U (wrMs U tag Lq h64 key domain hs hL ps R.pf (k + 1) lg τ) (acc.fs ++ acc.hostFs) := by
  intro k hk hdr core bga rs acc T hsa htr
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have hi1 : k + 1 < R.pf.parts.length := by omega
  have hi2 : k + 1 + 1 < R.pf.parts.length := by omega
  -- block `k`'s part and its single phase's length
  have hσb := ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck
    bndOpen R cx0 pin pout bp wXk gXk mXk hσ k hk
  have hpart : R.pf.part (k + 1) = rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m
      ((bp k).nH + (bp k).pH.rows) (bp k).pH.m (wXk k) (gXk k) (mXk k) := rx_part_of R (k + 1) _ hσb
  have hpre : (R.pf.part (k + 1)).pre = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots := by
    rw [hpart]
    rfl
  -- the reading's accumulator is the run reader's at every window after the slot phase
  have hacc := wr_acc_rd key domain (Pk k) (R.pf.off (k + 1) + 5) G (bp k).hgt (fun j hj => ((bp k).hgeomL j hj).1)
    hdr core bga rs acc T hsa τ htr
  have hrd : ∀ a, R.pf.off (k + 1) + (R.pf.part (k + 1)).pre ≤ a →
      rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take a) = acc := by
    intro a ha
    rw [rxAcc_blk _ _ _ _ _ k hk]
    show Block.tAccRd (Pk k) (R.pf.off (k + 1) + 5) ((τ.take a).take (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre))
      = acc
    rw [rk_take_take_le τ _ a ha, hpre, show R.pf.off (k + 1) + (15 + shapeLen (Pk k) 0 (Pk k).geom.slots)
      = R.pf.off (k + 1) + 5 + (10 + shapeLen (Pk k) 0 (Pk k).geom.slots) by omega]
    exact hacc
  have hoff2 := R.pf.off_succ (k + 1) hi1
  -- the windows lie after the slot phase
  have wA : R.pf.off (k + 1) + (R.pf.part (k + 1)).pre ≤ R.pf.off (k + 1) + (R.pf.part (k + 1)).oA := by
    simp only [RtPart.oA]
    omega
  have wH : R.pf.off (k + 1) + (R.pf.part (k + 1)).pre ≤ R.pf.off (k + 1) + (R.pf.part (k + 1)).oH := by
    simp only [RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have wX : R.pf.off (k + 1) + (R.pf.part (k + 1)).pre ≤ R.pf.off (k + 1) + (R.pf.part (k + 1)).oX := by
    simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  have wX2 : R.pf.off (k + 1) + (R.pf.part (k + 1)).pre
      ≤ R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX := by
    rw [hoff2]
    simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
    omega
  -- the witnesses
  obtain ⟨⟨oA⟩, ⟨oH⟩⟩ := hAH (k + 1) hi1
  obtain ⟨oX⟩ := hX (k + 1) (by omega) hi1
  obtain ⟨oX2⟩ := hX (k + 1 + 1) (by omega) hi2
  obtain ⟨oM⟩ := hMW (k + 1) hi1
  have hlen : ∀ (a : ℕ), (τ.take a).length = a → a ≤ τ.length := by
    intro a h
    rw [List.length_take] at h
    omega
  -- no doomed `opA` entrant at the four openings, nor at `M`
  have ndA := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n lg τ hA (k + 1) hi1 hn
  have ndA2 := wr_ndA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n lg τ hA (k + 1 + 1) hi2 hn
  have ndM := wr_ndM key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD n lg τ hM (k + 1) hi1 hn
  have sA := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (ps (k + 1)).gA (ps (k + 1)).nA
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (k + 1) hdr).claims.a) _ (rtW R.pf.sqs) _ lg τ
    (ndA _ List.mem_cons_self) (hlen _ oA.hpl) oA.hpre (by have h := oA.hcnt; rw [← oA.hrd] at h; exact h)
  have sH := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (ps (k + 1)).gH (ps (k + 1)).nH
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (k + 1) hdr).claims.h ++ [lsc (k + 1)]) _ (rtW R.pf.sqs) _ lg τ
    (ndA _ (List.mem_cons_of_mem _ List.mem_cons_self)) (hlen _ oH.hpl) oH.hpre
    (by have h := oH.hcnt; rw [← oH.hrd] at h; exact h)
  have sX := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (ps (k + 1)).gX (ps (k + 1)).nX
    (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) (k + 1) hdr ++ (rxAcc Win Wout Pk R.pf Lb (k + 1) hdr).claims.inp)
    _ (rtW R.pf.sqs) _ lg τ
    (ndA _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))) (hlen _ oX.hpl) oX.hpre
    (by have h := oX.hcnt; rw [← oX.hrd] at h; exact h)
  have sX2 := wr_rkOpen_sem U hbij tag Lq h64 key domain hs hL (ps (k + 1 + 1)).gX (ps (k + 1 + 1)).nX
    (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) (k + 1 + 1) hdr
      ++ (rxAcc Win Wout Pk R.pf Lb (k + 1 + 1) hdr).claims.inp)
    _ (rtW R.pf.sqs) _ lg τ
    (ndA2 _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))) (hlen _ oX2.hpl) oX2.hpre
    (by have h := oX2.hcnt; rw [← oX2.hrd] at h; exact h)
  have sM := wr_rkMask_sem U hbij tag Lq h64 key domain hs hL (ps (k + 1)).S (ps (k + 1)).k (ps (k + 1)).mpos
    (fun hdr => (rxAcc Win Wout Pk R.pf Lb (k + 1) hdr).fs ++ (rxAcc Win Wout Pk R.pf Lb (k + 1) hdr).hostFs)
    (rtW R.pf.sqs) _ lg τ ndM (hlen _ oM.hpl) oM.hpre
    (by have h := oM.hk; rw [← oM.hrd] at h; exact h)
  refine ⟨fun cm c hc => ?_, fun mf hmf => ?_⟩
  · cases cm with
    | a =>
      have hc' : c ∈ acc.claims.a := hc
      refine sA c ?_
      show c ∈ (rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).oA))).claims.a
      rw [hrd _ wA]
      exact hc'
    | h =>
      have hc' : c ∈ acc.claims.h := hc
      refine sH c ?_
      show c ∈ (rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).oH))).claims.h
        ++ [lsc (k + 1)]
      rw [hrd _ wH]
      exact List.mem_append_left _ hc'
    | inp =>
      have hc' : c ∈ acc.claims.inp := hc
      refine sX c ?_
      show c ∈ rkPend (rxAcc Win Wout Pk R.pf Lb) (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).oX))
        ++ (rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).oX))).claims.inp
      rw [hrd _ wX]
      exact List.mem_append_right _ hc'
    | out =>
      have hc' : c ∈ acc.claims.out := hc
      refine sX2 c ?_
      show c ∈ (rxAcc Win Wout Pk R.pf Lb (k + 1)
          (τ.take (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX))).claims.out
        ++ (rxAcc Win Wout Pk R.pf Lb (k + 1 + 1)
          (τ.take (R.pf.off (k + 1 + 1) + (R.pf.part (k + 1 + 1)).oX))).claims.inp
      rw [hrd _ wX2]
      exact List.mem_append_left _ hc'
  · refine sM mf ?_
    show mf ∈ (rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre))).fs
      ++ (rxAcc Win Wout Pk R.pf Lb (k + 1) (τ.take (R.pf.off (k + 1) + (R.pf.part (k + 1)).pre))).hostFs
    rw [hrd _ le_rfl]
    exact hmf

/-- **THE RUN-LEVEL `hsem` ON AN ACCEPTED RUN OUTSIDE THE RUN'S EXTRACTION EVENT** (the brief's deliverable 1). On an
accepted run (`classifyVerifyE` accepts the output of `A` at `G`), whose stage readers return the stages' contracts
(`hWin`, `hWout`), outside the run's Merkle extraction event `EvXR`, with the closing openings of parts `1` on meeting
their acceptance facts (`hX1`: the top theorem's `hopX1`), and with no doomed `opA` and no doomed `M` entrant: at every
block `k < Lb` and every reading of block `k` on the run's transcript, every claim of the reading's accumulator is true
of the run's extracted data (`wrCs`) and every functional of `M`'s decoded table (`wrMs`). The acceptance facts of every
part's `A`, `H` and `M` are lanes L45 / L48's `rx_parts_AHG`, `rx_parts_MG` (the stages' at the stage code geometry
`gS`). -/
theorem wr_hsem_acc
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (cx0 : IncCtx) (pin pout : RtPart) (I : RtInc Lq inc incG pin) (O : RtOutc Lq outc outcG pout)
    (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hLb : Lb ≤ 26) (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom)
    (gS : OGeo) (hgS : gS.Ok) (hgSQ : gS.Q ≤ 256)
    (hIA : RkPcsAt U tag gS I.pA) (hIH : RkPcsAt U tag gS I.pH) (hOA : RkPcsAt U tag gS O.pA)
    (hOH : RkPcsAt U tag gS O.pH)
    (hBA : ∀ k, RkPcsR13 U tag (bp k).pA) (hBH : ∀ k, RkPcsR13 U tag (bp k).pH)
    (htI : I.tag = tag) (htO : O.tag = tag) (htB : ∀ k, (bp k).tag = tag)
    (hfIA : 8 * I.pA.rows ≤ Lq) (hfIH : 8 * I.pH.rows ≤ Lq) (hfOA : 8 * O.pA.rows ≤ Lq) (hfOH : 8 * O.pH.rows ≤ Lq)
    (hfBA : ∀ k, 8 * (bp k).pA.rows ≤ Lq) (hfBH : ∀ k, 8 * (bp k).pH.rows ≤ Lq)
    (hfIM : 8 * (2 * pin.S + 4) ≤ Lq) (hfOM : 8 * (2 * pout.S + 4) ≤ Lq) (hfBM : ∀ k, 8 * (2 * (bp k).S + 4) ≤ Lq)
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (lscIn lscOut : Block.ZClaim)
    (mIn kIn kOut : ℕ) (hlscIn : ∀ hd, (inc hd).lay.logupSumClaim = lscIn)
    (hlscOut : ∀ hd v, (outc hd v).lay.logupSumClaim = lscOut) (hmIn : ∀ hd, incHeadDraws (inc hd).pub = mIn)
    (hkIn : ∀ hd, (inc hd).lay.nFunctionals = kIn) (hkOut : ∀ hd v, (outc hd v).lay.nFunctionals = kOut)
    (base : ℕ → RkPart K Lq) (rdx : List UInt8 → Option Dig) (eL : ℕ)
    (hD : (ebData U tag Lq h64 key domain hs hL rdx R.pf
      (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
        (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
        (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
      (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (n : ℕ) (hn : R.pf.parts.length ≤ n)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G)
      (A.run G).1 (A.run G).2 = .ok ())
    (hWin : Win ((R.tr G (A.run G)).take (R.pf.off 0 + pin.pre)) = inc (A.run G).1.hdr)
    (hWout : Wout ((R.tr G (A.run G)).take (R.pf.off (Lb + 1) + pout.pre)) = outc (A.run G).1.hdr (A.run G).1.verdict)
    (hX : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hX1 : ∀ i, 0 < i → i < R.pf.parts.length →
      EbXW U tag Lq h64 key domain hs hL rdx i (rtW R.pf.sqs)
        ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
          (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
          (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).gX
        ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
          (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
          (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).nX
        (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) i hdr ++ (rxAcc Win Wout Pk R.pf Lb i hdr).claims.inp)
        (R.pf.off i + (R.pf.part i).oX) (R.pf.off i + (R.pf.part i).oBX)
        (R.pf.off i + (R.pf.part i).oX
          + (((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
            (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
            (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).nX
          + ((rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
            (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
            (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH)) i).gX.rows))
        (A.runLog G).2 G (R.tr G (A.run G)))
    (hA : ¬ (rtKA key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G)))
    (hM : ¬ (rtKM key domain hs Lq hL R.pf R.rd hL64 hv U hbij _ hD).Dm n (A.runLog G).2 (R.tr G (A.run G))) :
    ∀ k, k < Lb → ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
      (acc : Block.Acc) (T : List Op),
      Block.SlotsAcc key domain (Pk k) (R.pf.off (k + 1) + 5) G (hdr, core) bga rs acc →
      R.tr G (A.run G) = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps (Pk k) (hdr, core) ++ T) →
      Block.ClaimsTrue U (wrCs U (ebData U tag Lq h64 key domain hs hL rdx R.pf
          (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
            (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
            (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
          (rxAcc Win Wout Pk R.pf Lb) (rxLsc lscIn lscOut Pk Lb) eL)
          R.pf (k + 1) (A.runLog G).2 (R.tr G (A.run G))) acc.claims
        ∧ Block.MTrue U (wrMs U tag Lq h64 key domain hs hL
          (rxPs base Lb (rxDinG gS R.pf pin.S kIn I.pA.rows I.pH.rows I.nA I.nH mIn)
            (fun k => rxDblk R.pf k (bp k).S (Pk k).nFunctionals (bp k).pA.rows (bp k).pH.rows (bp k).nA (bp k).nH)
            (rxDoutG gS R.pf Lb pout.S kOut O.pA.rows O.pH.rows O.nA O.nH))
          R.pf (k + 1) (A.runLog G).2 (R.tr G (A.run G))) (acc.fs ++ acc.hostFs) :=
  wr_hsem U hbij tag h64 hs hL hL64 Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN
    bndCheck bndOpen R hv cx0 pin pout bp wXk gXk mXk hσ rdx _ Win Wout _ eL hD n hn (A.runLog G).2 G
    (R.tr G (A.run G))
    (fun i hi => rx_parts_AHG (U := U) (gS := gS) (hgS := hgS) (hgSQ := hgSQ) (tag := tag) (h64 := h64) (hs := hs)
      (hL := hL) (Lb := Lb) (preA := preA) (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc)
      (outcG := outcG) (Pk := Pk) (sgeom := sgeom) (check := check) (paths := paths) (digest := digest)
      (bRows := bRows) (bLogN := bLogN) (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0)
      (pin := pin) (pout := pout) (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ)
      (hLb := hLb) (hgeo := hgeo) (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) (kOut := kOut)
      (base := base) (acc := _) (hacc := rfl) (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout)
      (hX := hX) (i := i) (hi := hi) (hIA := hIA) (hIH := hIH) (hOA := hOA) (hOH := hOH) (hBA := hBA) (hBH := hBH)
      (hfIA := hfIA) (hfIH := hfIH) (hfOA := hfOA) (hfOH := hfOH) (hfBA := hfBA) (hfBH := hfBH) (lscIn := lscIn)
      (lscOut := lscOut) (hlscIn := hlscIn) (hlscOut := hlscOut) (hmIn := hmIn) (ps := _) (hps := rfl) (lsc := _)
      (hlsc := rfl))
    (fun i hi0 hi => by
      obtain ⟨j, rfl⟩ : ∃ j, i = j + 1 := ⟨i - 1, by omega⟩
      exact hX1 (j + 1) hi0 hi)
    (fun i hi => rx_parts_MG (tag := tag) (gS := gS) (h64 := h64) (hs := hs) (hL := hL) (Lb := Lb) (preA := preA)
      (preB := preB) (start := start) (inc := inc) (incG := incG) (outc := outc) (outcG := outcG) (Pk := Pk)
      (sgeom := sgeom) (check := check) (paths := paths) (digest := digest) (bRows := bRows) (bLogN := bLogN)
      (bndCheck := bndCheck) (bndOpen := bndOpen) (R := R) (hv := hv) (cx0 := cx0) (pin := pin) (pout := pout)
      (I := I) (O := O) (bp := bp) (wXk := wXk) (gXk := gXk) (mXk := mXk) (hσ := hσ) (hLb := hLb) (hgeo := hgeo)
      (Win := Win) (Wout := Wout) (mIn := mIn) (kIn := kIn) (kOut := kOut) (base := base) (acc := _) (hacc := rfl)
      (A := A) (G := G) (hE := hE) (hWin := hWin) (hWout := hWout) (hX := hX) (i := i) (hi := hi) (htI := htI)
      (htO := htO) (htB := htB) (hfIM := hfIM) (hfOM := hfOM) (hfBM := hfBM) (hkIn := hkIn) (hkOut := hkOut)
      (ps := _) (rIA := I.pA.rows) (rIH := I.pH.rows) (rOA := O.pA.rows) (rOH := O.pH.rows)
      (rBA := fun k => (bp k).pA.rows) (rBH := fun k => (bp k).pH.rows) (hps := rfl))
    hA hM

end Hsem

end ZK60.ProtocolClassify
