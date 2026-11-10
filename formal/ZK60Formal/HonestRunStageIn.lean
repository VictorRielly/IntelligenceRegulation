/-
D63 Lean lane L32 (2026-11-09), part 1, at stage IN-C: **stage IN-C's honest data from its tables, and
`stage_in_c::verify`'s acceptance with the four openings' completeness PROVED**.

Lane L29's `incVerify_of_prove` takes the completeness of `M`'s test and of the openings of `A`, `H` and the input
token endpoint as premises (`hM`, `hA`, `hH`, `hE`), and the four path-depth pre-checks. With this lane's honest
opening provers they are theorems, at the parameters of L29's `incVAt` (`M` by `maskField tag 4`; `A`, `H` and the
endpoint by `pcsAt`). As for a block (`HonestRunBlock.lean`, finding L32-1), the honest data is built PER START
TRANSCRIPT: `H`'s table is a function of the head's challenges `β, γ, α, r_emb`, which `incDataAt` recomputes from the
transcript the stage starts on (`incChOf`).

* `IncTables`, `incChOf`, **`incDataAt`**: stage IN-C's honest commitments and L29's `IncData` at a start transcript;
* **`incVerify_of_tables`**: L29's executable `stage_in_c::verify` ACCEPTS the honest segment, from the slots'
  arithmetic (`StSlotsSum`), honest tables, true functionals and true claims: the openings' completeness and depth
  premises of `incVerify_of_prove` are discharged.

Every premise is an explicit hypothesis. Stage OUT-C's version is the same construction with the boundary opening
`bVerify` in place of the endpoint's and the carry check `own`; it is not written here.
-/
import ZK60Formal.HonestOpenFields
import ZK60Formal.StageVerifyExecComplete

set_option autoImplicit false

namespace ZK60.HonestRun

open ZK60 ZK60.Exec ZK60.Sound ZK60.HonestClassify ZK60.HonestOpen ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section StageIn

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **Stage IN-C's honest commitments**: `B_in`'s root (opened by the first block), `A`'s table, `M`'s rows, `H`'s
table as a function of the head's challenges, the input token endpoint's table, and the slots' honest data. -/
structure IncTables (V : IncV) where
  bRoot : Dig
  TA : Table
  M : MTable
  TH : List Fp2 → Table
  TE : Table
  slot : (ch : List Fp2) → SlotData (V.bp (incCtx V.pub ch))

/-- **The head's challenges stage IN-C draws from its start transcript** (L29's `incCh`), as a function of the three
roots. -/
def incChOf (V : IncV) (bRoot aRoot maskRoot : Dig) (t : Tr) : List Fp2 :=
  (((Block.absorbRoot H (V.frame H bRoot t) Block.labA aRoot V.lay.aRows V.lay.logN).absorb H Block.labM
    maskRoot.toList).challengeFp2Vec H (incHeadDraws V.pub)).1

/-- **Stage IN-C's honest data at a start transcript** (L29's `IncData`), for a stage whose regular commitments have
rate `2^-lr` and `q` opened columns and whose endpoint has rate `2^-elr` and `eq` opened columns. -/
noncomputable def incDataAt (V : IncV) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) : IncData V where
  bRoot := C.bRoot
  aRoot := rootOf H tag (V.pub.lt + lr) C.TA
  maskRoot := rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M)
  hRoot := fun ch => rootOf H tag (V.pub.lt + lr) (C.TH ch)
  slot := C.slot
  mOpen := bMask H tag U hbij C.M 4
  aOpen := bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA
  hOpen := bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr)
    (C.TH (incChOf H V C.bRoot (rootOf H tag (V.pub.lt + lr) C.TA)
      (rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M)) t))
  epOpen := bOpen H tag ⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ (V.pub.epLogN + elr) C.TE

/-- The challenges `incDataAt` opens `H` at are the ones the honest stage prover draws. -/
theorem incChOf_data (V : IncV) (lr elr q eq : ℕ) (C : IncTables V) (t : Tr) :
    incChOf H V C.bRoot (rootOf H tag (V.pub.lt + lr) C.TA) (rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M)) t
      = (incCh H V (incDataAt H tag U hbij V lr elr q eq C t) t).1 := rfl

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`stage_in_c::verify` accepts the honest segment, with the openings' completeness proved.** For a stage
verifier `V` whose opening fields are L10's `maskField tag 4` and L29's `pcsAt` (the fields of `incVAt`), the honest
data at the start transcript (`incDataAt`) and a run `R` of L29's honest stage prover: given the degrees, the slots'
arithmetic along the run (`StSlotsSum`), honest `M` rows and functionals TRUE of the masks, honest `A`, `H` and
endpoint tables (their row counts the layout's) and claims TRUE of them, the executable stage verifier returns the
claims left on `B_in`, `B_in`'s root and the prover's final transcript. -/
theorem incVerify_of_tables (V : IncV) (lr elr q eq : ℕ) (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t
      = pcsAt tag V.pub.epLogN elr eq H' root V.geo.epRows cl o t)
    (hk : V.pub.lt + lr ≤ 31) (hq : 0 < q) (hke : V.pub.epLogN + elr ≤ 31) (heq : 0 < eq)
    (hdB : V.blk.path = V.pub.lt + lr) (hdE : V.ed.path = V.pub.epLogN + elr) (C : IncTables V) (t : Tr)
    (R : IncRun) (h : incProve H V (incDataAt H tag U hbij V lr elr q eq C t) t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD (V.bp (incCtx V.pub R.ch)) s ∧ slotD (V.bp (incCtx V.pub R.ch)) s < gP)
    (hslots : StSlotsSum H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) U (C.slot R.ch) Fp2.zero Fp2.zero
      Fp2.zero V.lay.ns [] 0 {} R.t3)
    (hMh : MHonest U (algebraMap GF K (rootFp 9).toGF) C.M 4)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK U
        = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4) (mA U C.M 4) i)
    (hrA : V.lay.aRows = C.TA.rows.length)
    (hcA : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue U (2 ^ V.pub.lt) V.pub.lt C.TA.rows (toZClaim c))
    (hrH : V.lay.hRows = (C.TH R.ch).rows.length)
    (hcH : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr)
      (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue U (2 ^ V.pub.lt) V.pub.lt (C.TH R.ch).rows (toZClaim c))
    (hrE : V.geo.epRows = C.TE.rows.length)
    (hcE : ColsHonest U (lagK V.pub.epLogN (by omega)) eq (cosetPt (rootFp (V.pub.epLogN + elr)))
      (2 ^ V.pub.epLogN * 2 ^ elr) C.TE)
    (htE : ∀ c ∈ R.acc.claims.inp, ClaimTrue U (2 ^ V.pub.epLogN) V.pub.epLogN C.TE.rows (toZClaim c)) :
    V.verify H (rootOf H tag (V.pub.epLogN + elr) C.TE) R.seg t = .ok ((R.acc.claims.out, C.bRoot), R.t8) := by
  obtain ⟨-, hch, -, -, -, -, -, -, -, -, -, -, hmo, hao, hho, hcl, ht8⟩ :=
    incProve_ok H V (incDataAt H tag U hbij V lr elr q eq C t) t R h
  have hchO : incChOf H V C.bRoot (rootOf H tag (V.pub.lt + lr) C.TA)
      (rootOf H tag 12 (mTab 4 (cosetPt (rootFp 12)) C.M)) t = R.ch := hch.symm
  have hmo' : (R.seg.core.maskOpen, R.t5) = bMask H tag U hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4 := hmo
  have hao' : (R.seg.core.aOpen, R.t6)
      = bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5 := hao
  have hho' : (R.seg.core.hOpen, R.t7) = bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 := by
    rw [← hchO]
    exact hho
  have hcl' : R.seg.closes
      = [(bOpen H tag ⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ (V.pub.epLogN + elr) C.TE R.acc.claims.inp R.t7).1] := hcl
  have ht8' : R.t8
      = (bOpen H tag ⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ (V.pub.epLogN + elr) C.TE R.acc.claims.inp R.t7).2 := ht8
  have hm1 : R.seg.core.maskOpen = (bMask H tag U hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo'
  have hm2 : R.t5 = (bMask H tag U hbij C.M 4 (R.acc.fs ++ R.acc.hostFs) R.t4).2 := congrArg Prod.snd hmo'
  have ha1 : R.seg.core.aOpen
      = (bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5).1 := congrArg Prod.fst hao'
  have ha2 : R.t6 = (bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) C.TA R.acc.claims.a R.t5).2 :=
    congrArg Prod.snd hao'
  have hh1 : R.seg.core.hOpen = (bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).1 := congrArg Prod.fst hho'
  have hh2 : R.t7 = (bOpen H tag ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) (C.TH R.ch)
      (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).2 := congrArg Prod.snd hho'
  have hnn : (⟨V.pub.lt, 2 ^ lr, q, q⟩ : PcsPrm).nn = 2 ^ (V.pub.lt + lr) := (pow_add 2 V.pub.lt lr).symm
  have hnnE : (⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ : PcsPrm).nn = 2 ^ (V.pub.epLogN + elr) :=
    (pow_add 2 V.pub.epLogN elr).symm
  refine incVerify_of_prove H V U hU (incDataAt H tag U hbij V lr elr q eq C t)
    (rootOf H tag (V.pub.epLogN + elr) C.TE) t R h hdeg ?_ ?_ ?_ ?_ hslots ?_ ?_ ?_ ?_
  · rw [hdB, ha1]
    exact bOpen_pathsDepth H tag "stage IN-C A" ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) hnn hq C.TA _ _ 0
  · rw [hdB, hh1]
    exact bOpen_pathsDepth H tag "stage IN-C H" ⟨V.pub.lt, 2 ^ lr, q, q⟩ (V.pub.lt + lr) hnn hq _ _ _ 0
  · rw [hm1]
    exact bMask_pathsDepth H tag U hbij "M" C.M 4 _ _ 0
  · rw [hdE, hcl']
    exact bOpen_pathsDepth H tag "input token endpoint" ⟨V.pub.epLogN, 2 ^ elr, eq, eq⟩ (V.pub.epLogN + elr) hnnE
      heq C.TE _ _ 0
  · rw [hVm, hm1, hm2]
    exact maskField_of_prove H tag U hbij hU C.M 4 hMh _ hMt _
  · rw [hVa, ha1, ha2, hrA]
    exact pcsAt_of_prove H tag U hU V.pub.lt lr q hk hq C.TA hcA _ htA _
  · rw [hVh, hh1, hh2, hrH]
    exact pcsAt_of_prove H tag U hU V.pub.lt lr q hk hq (C.TH R.ch) hcH _ htH _
  · rw [hVe, hcl', ht8', hrE]
    exact pcsAt_of_prove H tag U hU V.pub.epLogN elr eq hke heq C.TE hcE _ htE _

end StageIn

end ZK60.HonestRun
