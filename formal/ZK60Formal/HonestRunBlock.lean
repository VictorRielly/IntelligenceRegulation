/-
D63 Lean lane L32 (2026-11-09), part 1, at a block: **a block core's honest data from its tables, and `verify_core`'s
acceptance with the three openings' completeness PROVED** (no longer contracts).

Lane L25's `blockVerify_of_prove` takes the completeness of `M`'s test and of `A`'s and `H`'s openings as premises
(`hM`, `hA`, `hH`), and the openings' path depths (`hpA`, `hpH`, `hpM`). With the honest opening provers of this lane
(`HonestOpenFields.lean`'s `bMask`, `bOpen`) they are theorems. What is left of a block core's completeness is the
arithmetic along the run only: each slot's obligation (`SlotsSum`), the functionals TRUE of the committed masks, and
the claims TRUE of the committed tables.

**The honest data depends on the start transcript** (finding L32-1). `H`'s table is a function of the LogUp challenges
`β, γ, α`, which are squeezed from the transcript after `A`'s and `M`'s roots. L25's `CoreData.hOpen` is handed the
claims and the transcript before the opening, not the challenges. So the honest `CoreData` is built here PER START
TRANSCRIPT (`coreDataAt`): it computes `β, γ, α` from the transcript the core starts on (`bgaOf`, the same absorbs and
squeezes `coreProve` makes) and opens `H`'s table at them.

What is here:
* `CoreTables`: a block core's honest commitments (`A`'s table, `M`'s rows, `H`'s table as a function of `β, γ, α`,
  the slots' data); `bgaOf`; **`coreDataAt`**: L25's `CoreData` at a start transcript;
* **`blockVerify_of_tables_r13`**: L9's executable `verify_core` at an R13 profile (the media app's blocks: L10's
  `maskField`, L17's `pcsFieldR13`) ACCEPTS the honest core, from the profile's pre-checks and depths, the slots'
  arithmetic, honest tables, true functionals and true claims: the openings' completeness and depth premises of
  `blockVerify_of_prove` are discharged.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.HonestOpenSites
import ZK60Formal.HonestClassifyBlock

set_option autoImplicit false

namespace ZK60.HonestRun

open ZK60 ZK60.Exec ZK60.Sound ZK60.HonestClassify ZK60.HonestOpen
open ZK60.Exec.Block (BlockParams blockVerify)
open ZK60.Circuit (gP GF)

section Core

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **A block core's honest commitments**: `A`'s table, `M`'s rows, `H`'s table as a function of the LogUp challenges
`β, γ, α` (the helper columns), and the slots' honest data. -/
structure CoreTables (P : BlockParams) where
  TA : Table
  M : MTable
  TH : Fp2 → Fp2 → Fp2 → Table
  slot : SlotData P

/-- **The LogUp challenges a core draws from its start transcript** (`absorb_root("A")`, `absorb("M")`, then `β, γ,
α`): L25's `coreB`, `coreG`, `coreA`, as a function of the two roots. -/
def bgaOf (P : BlockParams) (aRoot maskRoot : Dig) (t : Tr) : Fp2 × Fp2 × Fp2 :=
  ((((Block.absorbRoot H t Block.labA aRoot P.aRows P.logCols).absorb H Block.labM maskRoot.toList).challengeFp2 H).1,
    ((((Block.absorbRoot H t Block.labA aRoot P.aRows P.logCols).absorb H Block.labM
      maskRoot.toList).challengeFp2 H).2.challengeFp2 H).1,
    (((((Block.absorbRoot H t Block.labA aRoot P.aRows P.logCols).absorb H Block.labM
      maskRoot.toList).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1)

/-- **The honest core data at a start transcript** (L25's `CoreData`): the honest roots, the slots' data, and the
honest opening provers of `M`, `A` and `H`, with `H`'s table taken at the challenges the transcript gives. `prm`,
`depth` are the regular commitments' parameters and tree depth, `S` the mask count. -/
noncomputable def coreDataAt (prm : PcsPrm) (depth S : ℕ) (P : BlockParams) (C : CoreTables P) (t : Tr) :
    CoreData P where
  aRoot := rootOf H tag depth C.TA
  maskRoot := rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)
  hRoot := fun b g a => rootOf H tag depth (C.TH b g a)
  slot := C.slot
  mOpen := bMask H tag U hbij C.M S
  aOpen := bOpen H tag prm depth C.TA
  hOpen := bOpen H tag prm depth
    (C.TH (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).1
      (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.1
      (bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t).2.2)

/-- The challenges `coreDataAt` opens `H` at are the ones the honest core prover draws. -/
theorem bgaOf_core (prm : PcsPrm) (depth S : ℕ) (P : BlockParams) (C : CoreTables P) (t : Tr) :
    bgaOf H P (rootOf H tag depth C.TA) (rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) C.M)) t
      = ((coreB H P (coreDataAt H tag U hbij prm depth S P C t) t).1,
        (coreG H P (coreDataAt H tag U hbij prm depth S P C t) t).1,
        (coreA H P (coreDataAt H tag U hbij prm depth S P C t) t).1) := rfl

variable (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`verify_core` accepts the honest core at an R13 profile, with the openings' completeness proved.** For a block
profile `P` whose opening fields are L10's `maskField` and L17's `pcsFieldR13` (trees of depth `16` and `12`), the
honest core data at the start transcript (`coreDataAt`), and a run `R` of L25's honest core prover: given the profile's
pre-checks, the slots' arithmetic along the run (`SlotsSum`), honest `M` rows (`MHonest`) and functionals TRUE of the
masks, honest `A` and `H` tables (`ColsHonest`, their row counts the profile's) and claims TRUE of them, L9's
executable `verify_core` returns the core's IO claims and the prover's final transcript. -/
theorem blockVerify_of_tables_r13 (P : BlockParams) (S : ℕ) (rowsOf : Block.Cm → ℕ)
    (hPm : P.maskVerify = maskField tag S) (hPp : P.pcsVerify = R13.pcsFieldR13 tag rowsOf) (hdA : P.aPath = 16)
    (hdH : P.hPath = 16) (hdM : P.maskPath = 12) (C : CoreTables P) (t : Tr) (R : CoreRun)
    (h : coreProve H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD P s ∧ slotD P s < gP) (hpre : P.preChecks = .ok ())
    (hslots : SlotsSum H P U C.slot (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
      (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
      (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1 P.geom.slots.length [] 0 {}
      (coreT3 H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t))
    (hMh : MHonest U (algebraMap GF K (rootFp 9).toGF) C.M S)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK U
        = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U ((R.acc.fs ++ R.acc.hostFs).map toMF) S) (mA U C.M S) i)
    (hrA : rowsOf .a = C.TA.rows.length)
    (hcA : ColsHonest U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue U (2 ^ 14) 14 C.TA.rows (toZClaim c))
    (hrH : rowsOf .h = (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
      (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
      (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1).rows.length)
    (hcH : ColsHonest U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 16)
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1))
    (htH : ∀ c ∈ R.acc.claims.h ++ [P.logupSumClaim], ClaimTrue U (2 ^ 14) 14
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1).rows (toZClaim c)) :
    blockVerify H P R.core t = .ok ((R.acc.claims.inp, R.acc.claims.out), R.t7) := by
  obtain ⟨-, -, -, -, -, -, hhR, -, hmo, hao, hho⟩ :=
    coreProve_ok H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t R h
  have hmo' : (R.core.maskOpen, R.t5) = bMask H tag U hbij C.M S (R.acc.fs ++ R.acc.hostFs) R.t4 := hmo
  have hao' : (R.core.aOpen, R.t6) = bOpen H tag R13.r13Prm 16 C.TA R.acc.claims.a R.t5 := hao
  have hho' : (R.core.hOpen, R.t7) = bOpen H tag R13.r13Prm 16
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1)
      (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 := hho
  have hhR' : R.core.hRoot = rootOf H tag 16
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1) := hhR
  have hm1 : R.core.maskOpen = (bMask H tag U hbij C.M S (R.acc.fs ++ R.acc.hostFs) R.t4).1 :=
    congrArg Prod.fst hmo'
  have hm2 : R.t5 = (bMask H tag U hbij C.M S (R.acc.fs ++ R.acc.hostFs) R.t4).2 := congrArg Prod.snd hmo'
  have ha1 : R.core.aOpen = (bOpen H tag R13.r13Prm 16 C.TA R.acc.claims.a R.t5).1 := congrArg Prod.fst hao'
  have ha2 : R.t6 = (bOpen H tag R13.r13Prm 16 C.TA R.acc.claims.a R.t5).2 := congrArg Prod.snd hao'
  have hh1 : R.core.hOpen = (bOpen H tag R13.r13Prm 16
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1)
      (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).1 := congrArg Prod.fst hho'
  have hh2 : R.t7 = (bOpen H tag R13.r13Prm 16
      (C.TH (coreB H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreG H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1
        (coreA H P (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t).1)
      (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).2 := congrArg Prod.snd hho'
  have hnn : R13.r13Prm.nn = 2 ^ 16 := R13.r13Prm_nn
  have hnQ : 0 < R13.r13Prm.nQ := by norm_num [R13.r13Prm]
  refine blockVerify_of_prove H P U hU (coreDataAt H tag U hbij R13.r13Prm 16 S P C t) t R h hdeg hpre ?_ ?_ ?_ hslots
    ?_ ?_ ?_
  · rw [hdA, ha1]
    exact bOpen_pathsDepth H tag "A" R13.r13Prm 16 hnn hnQ C.TA _ _ 0
  · rw [hdH, hh1]
    exact bOpen_pathsDepth H tag "H" R13.r13Prm 16 hnn hnQ _ _ _ 0
  · rw [hdM, hm1]
    exact bMask_pathsDepth H tag U hbij "M" C.M S _ _ 0
  · rw [hPm, hm1, hm2]
    exact maskField_of_prove H tag U hbij hU C.M S hMh _ hMt _
  · rw [hPp, ha1, ha2]
    exact pcsFieldR13_of_prove H tag U hU rowsOf .a C.TA hrA hcA _ htA _
  · rw [hPp, hhR', hh1, hh2]
    exact pcsFieldR13_of_prove H tag U hU rowsOf .h _ hrH hcH _ htH _

end Core

end ZK60.HonestRun
