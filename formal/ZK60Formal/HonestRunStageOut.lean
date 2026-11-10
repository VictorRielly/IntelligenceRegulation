/-
D63 Lean lane L32 (2026-11-09), part 1, at stage OUT-C: **stage OUT-C's honest data from its tables, and
`stage_out_c::verify`'s acceptance with the four openings' completeness PROVED**.

Lane L29's `outcVerify_of_prove` takes the completeness of `M`'s test and of the openings of `A`, `H` and `B_out`
(the last boundary, on the carry's pending claims followed by the stage's own) as premises (`hM`, `hA`, `hH`, `hB`),
and the four path-depth pre-checks. With this lane's honest opening provers they are theorems, at the parameters of
L29's `outcVAt` (`M` by `maskField tag 8`; `A`, `H` and `B_out` by `pcsAt`). As for a block and for stage IN-C
(finding L32-1), the honest data is built PER START TRANSCRIPT: `H`'s table is a function of the head's `γ, α`, which
`outcDataAt` recomputes from the transcript the stage starts on (`outcChOf`).

The stage opens the boundary the LAST BLOCK committed. Its honest prover checks that the carry's root is its own
(lane L25's finding L25-1): here `own` compares the carry's root with the honest root of the boundary table.

* `OutcTables`, `outcChOf`, **`outcDataAt`**: stage OUT-C's honest commitments and L29's `OutcData` at a start
  transcript;
* **`outcVerify_of_tables`**: L29's executable `stage_out_c::verify` ACCEPTS the honest segment on the honest carry,
  from the slots' arithmetic (`SlotsSum`), honest tables, true functionals and true claims (the carry's pending claims
  included): the openings' completeness and depth premises of `outcVerify_of_prove` are discharged.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.HonestOpenFields
import ZK60Formal.StageVerifyExecComplete

set_option autoImplicit false

namespace ZK60.HonestRun

open ZK60 ZK60.Exec ZK60.Sound ZK60.HonestClassify ZK60.HonestOpen ZK60.Exec.StageV ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)

section StageOut

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **Stage OUT-C's honest commitments**: `A`'s table, `M`'s rows, `H`'s table as a function of the head's
challenges, the last boundary's table (committed by the last block, opened here), and the slots' honest data. -/
structure OutcTables (V : OutcV) where
  TA : Table
  M : MTable
  TH : List Fp2 → Table
  TB : Table
  slot : SlotData V.bp

/-- **The head's challenges stage OUT-C draws from its start transcript** (L29's `outcCh`), as a function of the two
roots. -/
def outcChOf (V : OutcV) (aRoot maskRoot : Dig) (t : Tr) : List Fp2 :=
  (((Block.absorbRoot H (V.frame H t) Block.labA aRoot V.bp.aRows V.bp.logCols).absorb H Block.labM
    maskRoot.toList).challengeFp2Vec H 2).1

/-- **Stage OUT-C's honest data at a start transcript** (L29's `OutcData`), for a stage whose regular commitments
have rate `2^-lr` and `q` opened columns and whose boundary has rate `2^-blr` and `bq` opened columns. The carry is
the prover's own when its root is the honest boundary root. -/
noncomputable def outcDataAt (V : OutcV) (lr blr q bq : ℕ) (C : OutcTables V) (t : Tr) : OutcData V where
  aRoot := rootOf H tag (V.pub.lt + lr) C.TA
  maskRoot := rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)
  hRoot := fun ch => rootOf H tag (V.pub.lt + lr) (C.TH ch)
  slot := C.slot
  mOpen := bMask H tag U hbij C.M 8
  aOpen := HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA
  hOpen := HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr)
    (C.TH (outcChOf H V (rootOf H tag (V.pub.lt + lr) C.TA) (rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)) t))
  bOpen := HonestOpen.bOpen H tag ⟨V.geo.bLogN, 2 ^ blr, bq, bq⟩ (V.geo.bLogN + blr) C.TB
  own := fun cr => decide (cr.root = rootOf H tag (V.geo.bLogN + blr) C.TB)

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`stage_out_c::verify` accepts the honest segment, with the openings' completeness proved.** For a stage
verifier `V` whose opening fields are L10's `maskField tag 8` and L29's `pcsAt` (the fields of `outcVAt`), the honest
data at the start transcript (`outcDataAt`) and a run `R` of L29's honest stage prover on a carry `cr`: given the
degrees, the slots' arithmetic along the run (`SlotsSum`), honest `M` rows and functionals TRUE of the masks, honest
`A`, `H` and boundary tables (their row counts the layout's) and claims TRUE of them (for the boundary: the carry's
pending claims followed by the stage's own), the executable stage verifier accepts on the carry and returns the
prover's final transcript. -/
theorem outcVerify_of_tables (V : OutcV) (lr blr q bq rowsA rowsH : ℕ) (hVm : V.maskVerify = maskField tag 8)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root rowsA cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root rowsH cl o t)
    (hVb : ∀ (H' : HIn → Dig) root cl o t, V.bVerify H' root cl o t
      = pcsAt tag V.geo.bLogN blr bq H' root V.geo.bRows cl o t)
    (hk : V.pub.lt + lr ≤ 31) (hq : 0 < q) (hkb : V.geo.bLogN + blr ≤ 31) (hbq : 0 < bq)
    (hdB : V.blk.path = V.pub.lt + lr) (hdD : V.bd.path = V.geo.bLogN + blr) (C : OutcTables V) (cr : Carry)
    (t : Tr) (R : OutcRun) (h : outcProve H V (outcDataAt H tag U hbij V lr blr q bq C t) cr t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD V.bp s ∧ slotD V.bp s < gP)
    (hslots : SlotsSum H V.bp U C.slot (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 V.lay.ns [] 0 {}
      R.t3)
    (hMh : MHonest U (algebraMap GF K (rootFp 9).toGF) C.M 8)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK U
        = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8) (mA U C.M 8) i)
    (hrA : rowsA = C.TA.rows.length)
    (hcA : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue U (2 ^ V.pub.lt) V.pub.lt C.TA.rows (toZClaim c))
    (hrH : rowsH = (C.TH R.ch).rows.length)
    (hcH : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr)
      (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue U (2 ^ V.pub.lt) V.pub.lt (C.TH R.ch).rows (toZClaim c))
    (hrB : V.geo.bRows = C.TB.rows.length)
    (hcB : ColsHonest U (lagK V.geo.bLogN (by omega)) bq (cosetPt (rootFp (V.geo.bLogN + blr)))
      (2 ^ V.geo.bLogN * 2 ^ blr) C.TB)
    (htB : ∀ c ∈ cr.pending ++ R.acc.claims.inp, ClaimTrue U (2 ^ V.geo.bLogN) V.geo.bLogN C.TB.rows (toZClaim c)) :
    V.verify H cr.root cr.pending R.seg t = .ok R.t8 := by
  obtain ⟨hown, -, hch, -, -, -, -, -, -, -, -, -, -, -, hmo, hao, hho, hcl, ht8⟩ :=
    outcProve_ok H V (outcDataAt H tag U hbij V lr blr q bq C t) cr t R h
  have hroot : cr.root = rootOf H tag (V.geo.bLogN + blr) C.TB := of_decide_eq_true hown
  have hchO : outcChOf H V (rootOf H tag (V.pub.lt + lr) C.TA)
      (rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) C.M)) t = R.ch := hch.symm
  have hmo' : (R.seg.core.maskOpen, R.t5) = bMask H tag U hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4 := hmo
  have hao' : (R.seg.core.aOpen, R.t6)
      = HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5 := hao
  have hho' : (R.seg.core.hOpen, R.t7) = HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 := by
    rw [← hchO]
    exact hho
  have hcl' : R.seg.closes = [(HonestOpen.bOpen H tag ⟨V.geo.bLogN, 2 ^ blr, bq, bq⟩ (V.geo.bLogN + blr) C.TB
      (cr.pending ++ R.acc.claims.inp) R.t7).1] := hcl
  have ht8' : R.t8 = (HonestOpen.bOpen H tag ⟨V.geo.bLogN, 2 ^ blr, bq, bq⟩ (V.geo.bLogN + blr) C.TB
      (cr.pending ++ R.acc.claims.inp) R.t7).2 := ht8
  have hm1 : R.seg.core.maskOpen = (bMask H tag U hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo'
  have hm2 : R.t5 = (bMask H tag U hbij C.M 8 (R.acc.fs ++ R.acc.hostFs) R.t4).2 := congrArg Prod.snd hmo'
  have ha1 : R.seg.core.aOpen
      = (HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5).1 :=
    congrArg Prod.fst hao'
  have ha2 : R.t6 = (HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5).2 :=
    congrArg Prod.snd hao'
  have hh1 : R.seg.core.hOpen = (HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).1 := congrArg Prod.fst hho'
  have hh2 : R.t7 = (HonestOpen.bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).2 := congrArg Prod.snd hho'
  have hnn : (⟨V.pub.lt, 2 ^ lr, q, q⟩ : PcsPrm).nn = 2 ^ (V.pub.lt + lr) := (pow_add 2 V.pub.lt lr).symm
  have hnnB : (⟨V.geo.bLogN, 2 ^ blr, bq, bq⟩ : PcsPrm).nn = 2 ^ (V.geo.bLogN + blr) :=
    (pow_add 2 V.geo.bLogN blr).symm
  refine outcVerify_of_prove H V U hU (outcDataAt H tag U hbij V lr blr q bq C t) cr t R h hdeg ?_ ?_ ?_ ?_ hslots
    ?_ ?_ ?_ ?_
  · rw [hdB, ha1]
    exact bOpen_pathsDepth H tag "stage OUT-C A" ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) hnn hq C.TA _ _ 0
  · rw [hdB, hh1]
    exact bOpen_pathsDepth H tag "stage OUT-C H" ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) hnn hq _ _ _ 0
  · rw [hm1]
    exact bMask_pathsDepth H tag U hbij "M" C.M 8 _ _ 0
  · rw [hdD, hcl']
    exact bOpen_pathsDepth H tag "B_out" ⟨V.geo.bLogN, 2 ^ blr, bq, bq⟩ (V.geo.bLogN + blr) hnnB hbq C.TB _ _ 0
  · rw [hVm, hm1, hm2]
    exact maskField_of_prove H tag U hbij hU C.M 8 hMh _ hMt _
  · rw [hVa, ha1, ha2, hrA]
    exact pcsAt_of_prove H tag U hU V.pub.lt lr q hk hq C.TA hcA _ htA _
  · rw [hVh, hh1, hh2, hrH]
    exact pcsAt_of_prove H tag U hU V.pub.lt lr q hk hq (C.TH R.ch) hcH _ htH _
  · rw [hVb, hroot, hcl', ht8', hrB]
    exact pcsAt_of_prove H tag U hU V.geo.bLogN blr bq hkb hbq C.TB hcB _ htB _

end StageOut

end ZK60.HonestRun
