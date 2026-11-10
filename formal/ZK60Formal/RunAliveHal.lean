/-
D63 lane L50 (2026-11-10), part 5: **the six remaining alive conclusions on the classify run, at every part**: the
26 blocks' parts from each block's own algebra at the block's reading of the run, the two stages' parts named.

At a block part (`i = k + 1`, block `k`), the run's transcript is the block's verifier trace and more (`ra_blk_acc`),
so the block's sub-protocols in the kinds data are alive at the end of the run's transcript as soon as, at the block's
reading of the run (its header `hdr`, core, `β, γ, α`, slot records), the block-level facts hold:

* `RaTermAt`: every slot's terminal identity `fin = F(cuts, roots, j, seen)(ρ ‖ es)` (L16's `blockSlots_terminal`
  gives it from the claims' and `M`'s truth and L11 / L13's `SlotEval`);
* `RaDefAt`: a squeeze run is one of the block's define draws (`defSq` at the block's position) whose polynomial
  vanishes at the drawn challenges (L36's `SchedVan`, which `alg_hvR` / `alg_hvH` give on `AccT`);
* `RaLkAt`: a squeeze run is the block's LogUp run (`lkSq`) and helpers meet LogUp's relations at `β, γ, α` (L36 /
  L47's `hhr`).

Theorems:
* **`ra_hal_sl`**: `hal_slots`'s conclusion `(rtKsl … D hD).Al n lg τ` on an accepted run, when every block part's
  slots are L16's schedule `blockSchedX (Pk k) (off (k + 1) + 5) absOf (F k)` with `RaTermAt`, and the two stage parts'
  slots are alive (named: `hS0`, `hS1`);
* **`ra_hal_def`**: a define kind's conclusion (`hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`) when every block part's squeeze
  runs of that kind meet `RaDefAt`, the stage parts' named;
* **`ra_hal_lu`**: `hal_LU`'s, when every block part's LogUp runs meet `RaLkAt`, the stage parts' named.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveRun
import ZK60Formal.RunExtractParts

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-! ## The block-level facts at a block's reading of a transcript -/

section At

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Every slot's terminal identity at every reading of block `P` (at `hdrLen`) on the transcript `τ`**: whenever the
block's slot phase accepted after a header `hdr` (`SlotsAcc`) and `τ` is the trace of the block's operations followed by
operations that fit, every slot's final value is the slot polynomial `F` (over the tables extracted from the log `lg` at
the core's roots) at its point. -/
def RaTermAt (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P j).1 + (Block.slotShape P j).2.1) → K) → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc → (∀ op ∈ T, op.len ≤ L) →
    τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
    ∀ j r, rs[j]? = some r → r.fin.toK U = F (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core) j
      (Block.seenOf bga rs j) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)

/-- **A squeeze run is one of block `P`'s define draws (at `hdrLen`), vanishing at every reading**: it is `defSq` of some
slot `s` and polynomial `Φ`, and at every reading of the block on `τ` the slot `s` was run and `Φ` vanishes at its
drawn challenges (on the reading's history, the cuts at the core's roots). -/
def RaDefAt (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8)) (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (sx : SqX K L) : Prop :=
  ∃ (Φ : Block.Cuts3 L → Block.RootsO → (j : ℕ) → Block.Hist → (Fin (P.draws j) → K) → K) (dg : ℕ → ℕ) (s : ℕ),
    sx = Block.defSq P hdrLen absOf Φ dg s
    ∧ ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
      (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc → (∀ op ∈ T, op.len ≤ L) →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      ∃ r, rs[s]? = some r ∧ Φ (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core) s
        (Block.histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

/-- **A squeeze run is block `P`'s LogUp run (at `hdrLen`, lookups `Alk`, table `T`, multiplicities `mlk`), with helpers
at every reading**: at every reading of the block on `τ`, some helpers meet LogUp's relations at the reading's
`β, γ, α` for the lookups read at the `A` root's cut. -/
def RaLkAt [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (U : K) (key : Option Dig)
    (domain : List UInt8)
    (P : Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig)) (sx : SqX K L) : Prop :=
  sx = Block.lkSq hdrLen absOf Alk T mlk
    ∧ ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
      (T' : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc → (∀ op ∈ T', op.len ≤ L) →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T') →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (Block.cutO absOf (some core.aRoot.toList) lg) l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (Block.cutO absOf (some core.aRoot.toList) lg))
        (bga.2.2.toK U) Hh

end At

/-! ## The app's block slots meet the kinds data's slot conditions -/

/-- **The Shieldstral T128 R13 block's slots meet `RtKData.Valid`'s slot conditions** (degree between `1` and `7`, rounds
times degree at most `7·370`): L16's schedule over a block of that shape can be the block part's slots (`hslB`) without
breaking `hD`'s `slDeg`. -/
theorem ra_shield_slot_conds : ∀ k, k < 23 →
    1 ≤ (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ∧ (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ≤ 7
      ∧ ((Block.R13.shieldSlots.getD k (0, 0, 0)).1 + (Block.R13.shieldSlots.getD k (0, 0, 0)).2.1)
        * (Block.R13.shieldSlots.getD k (0, 0, 0)).2.2 ≤ 7 * 370 := by
  decide

/-! ## The six conclusions on the classify run -/

section Hal

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {Hdr : Type} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
  (Lb : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
  (inc : Hdr → IncV) (incG : Hdr → StageGeom) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **The block part's segment** (`i = k + 1`, `k < Lb`) of the classify run's schedule. -/
theorem ra_blk_seg
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (k : ℕ) (hk : k < Lb) :
    R.σs[k + 1]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k))) := by
  rw [hσ]
  exact rx_getBlk (V := classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) _ _ _ k hk

/-- **`hal_slots`'s conclusion on the classify run.** On an accepted run, if every block part's slots are L16's
schedule over the extracted tables (`hslB`) and every block's slots meet their terminal identities at the block's
reading of the run (`hterm`), and the two stage parts' slots are alive (`hS0`, `hS1`), the slots' kind is alive at the
end of the run's transcript. -/
theorem ra_hal_sl (hU : U ^ 2 = algebraMap GF K 7) (hL81 : 81 ≤ Lq)
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf)
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (absOf : QB Lq → Option (List UInt8))
    (F : (k : ℕ) → Block.Cuts3 Lq → Block.RootsO → (j : ℕ) → Block.Seen →
      (Fin ((Block.slotShape (Pk k) j).1 + (Block.slotShape (Pk k) j).2.1) → K) → K)
    (hslB : ∀ k, k < Lb → D.sls (k + 1) = Block.blockSchedX (Pk k) (R.pf.off (k + 1) + 5) absOf (F k))
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hterm : ∀ k, k < Lb → RaTermAt U key domain (Pk k) (R.pf.off (k + 1) + 5) absOf (F k) G lg (R.tr G (s, segs)))
    (hS0 : allSt W1 (slotSubs U (slotsAt (D.sls 0) lg)) (R.tr G (s, segs)))
    (hS1 : allSt W1 (slotSubs U (slotsAt (D.sls (Lb + 1)) lg)) (R.tr G (s, segs))) :
    (rtKsl key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD).Al n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  have h64' : Lq < 18446744073709551616 := by
    have h := hL64
    norm_num at h
    exact h
  have hgeomB : ∀ k j, j < (Pk k).geom.slots.length → 1 ≤ (Block.slotShape (Pk k) j).2.2
      ∧ (Block.slotShape (Pk k) j).2.2 < gP ∧ 56 + 16 * ((Block.slotShape (Pk k) j).2.2 + 1) ≤ Lq
      ∧ 55 + 16 * Block.slotTerms (Pk k) j ≤ Lq := by
    intro k j hj
    obtain ⟨h1, h2, h3⟩ := (bp k).hgeomL j hj
    refine ⟨h1, ?_, h2, h3⟩
    show (Block.slotShape (Pk k) j).2.2 < 18446744069414584321
    omega
  intro i _
  by_cases hi : i < R.pf.parts.length
  · rw [ra_ksl_cs key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD i hi]
    rcases i with _ | k
    · exact hS0
    · by_cases hk : k < Lb
      · obtain ⟨hdr, core, bga, rs, acc, T, hsa, hT, htr⟩ := ra_blk_acc Pk sgeom check paths digest bRows bLogN
          bndCheck bndOpen R hv G s segs hE (k + 1) k _
          (ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
            R cx0 pin pout bp wXk gXk mXk hσ k hk) (bp k) (hgeo k)
        rw [hslB k hk, htr]
        exact ra_blk_slots_alive U hU key domain hs hL hL64 hL81 (Pk k) _ absOf (F k) (hgeomB k) (bp k).hgt G lg hdr
          core bga rs acc hsa (hterm k hk hdr core bga rs acc T hsa hT htr) T hT
      · have hk' : k = Lb := by omega
        rw [hk']
        exact hS1
  · rw [ra_ksl_cs_out key domain hs Lq hL R.pf R.rd hL64 hv U hbij D hD i hi]
    intro j c hc
    simp at hc

/-- **A define kind's conclusion on the classify run** (`hal_R0`, `hal_R1`, `hal_H0`, `hal_H1`): on an accepted run, if
every block part's squeeze runs of the kind are the block's define draws vanishing at the block's reading (`hB`), and
the two stage parts' are alive (`hS0`, `hS1`), the kind is alive at the end of the run's transcript. -/
theorem ra_hal_def (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf emax ND sxs)
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (absOf : QB Lq → Option (List UInt8))
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hB : ∀ k, k < Lb → ∀ sx ∈ sxs (k + 1),
      RaDefAt U key domain (Pk k) (R.pf.off (k + 1) + 5) absOf G lg (R.tr G (s, segs)) sx)
    (hS0 : ∀ sx ∈ sxs 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
    (hS1 : ∀ sx ∈ sxs (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) :
    (rtKsq key domain hs Lq hL R.pf R.rd hL64 hv U hbij emax ND sxs hsx).Al n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  refine ra_Ksq_al key domain hs Lq hL R.pf R.rd hL64 hv U hbij emax ND sxs hsx n lg _ (fun i hi sx hmem => ?_)
  rcases i with _ | k
  · exact hS0 sx hmem
  · by_cases hk : k < Lb
    · obtain ⟨Φ, dg, s', rfl, hvan⟩ := hB k hk sx hmem
      obtain ⟨hdr, core, bga, rs, acc, T, hsa, hT, htr⟩ := ra_blk_acc Pk sgeom check paths digest bRows bLogN
        bndCheck bndOpen R hv G s segs hE (k + 1) k _
        (ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
          R cx0 pin pout bp wXk gXk mXk hσ k hk) (bp k) (hgeo k)
      obtain ⟨r, hr, hz⟩ := hvan hdr core bga rs acc T hsa hT htr
      rw [htr]
      exact Block.ra_def_blk U key domain (Pk k) _ absOf Φ dg (fun j hj => ((bp k).hgeomL j hj).1) (bp k).hgt G lg
        hdr core bga rs acc hsa T s' r hr hz
    · have hk' : k = Lb := by omega
      rw [hk'] at hmem
      exact hS1 sx hmem

/-- **`hal_LU`'s conclusion on the classify run**: on an accepted run, if every block part's LogUp runs are the block's
LogUp run with helpers at the block's reading (`hB`, the LogUp data of block `k` being `Alk k`, `T k`, `mlk k`), and the
two stage parts' are alive (`hS0`, `hS1`), LogUp's kind is alive at the end of the run's transcript. -/
theorem ra_hal_lu (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (R : RtRun (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) key domain Lq)
    (hv : R.pf.Valid) (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) R.pf emax ND sxs)
    (cx0 : IncCtx) (pin pout : RtPart) (bp : ∀ k, RtBlk Lq (Pk k)) (wXk gXk mXk : ℕ → ℕ)
    (hσ : R.σs = rtParts (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG)
      (rtIncSeg inc incG cx0 pin)
      (fun k => rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
        (rtBlockPart (Pk k) (bp k).S ((bp k).nA + (bp k).pA.rows) (bp k).pA.m ((bp k).nH + (bp k).pH.rows) (bp k).pH.m
          (wXk k) (gXk k) (mXk k)))
      (rtOutcSeg outc outcG pout))
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (absOf : QB Lq → Option (List UInt8))
    {ι π κ : ℕ → Type} [∀ k, Fintype (ι k)] [∀ k, Fintype (π k)] [∀ k, Fintype (κ k)]
    (Alk : (k : ℕ) → List (QB Lq × Dig) → ι k ⊕ (π k ⊕ π k) → Tup K) (T : (k : ℕ) → κ k → Tup K)
    (mlk : (k : ℕ) → List (QB Lq × Dig) → κ k → K)
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE (classifyRunV Lb preA preB start inc incG
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) outc outcG) (liftH G) s segs = .ok ())
    (hB : ∀ k, k < Lb → ∀ sx ∈ sxs (k + 1),
      RaLkAt U key domain (Pk k) (R.pf.off (k + 1) + 5) absOf (Alk k) (T k) (mlk k) G lg (R.tr G (s, segs)) sx)
    (hS0 : ∀ sx ∈ sxs 0, subSt W1 (sqSub U sx lg) (R.tr G (s, segs)))
    (hS1 : ∀ sx ∈ sxs (Lb + 1), subSt W1 (sqSub U sx lg) (R.tr G (s, segs))) :
    (rtKsq key domain hs Lq hL R.pf R.rd hL64 hv U hbij emax ND sxs hsx).Al n lg (R.tr G (s, segs)) := by
  have hL2 : R.pf.parts.length = Lb + 2 := RtRun.parts_length R
  refine ra_Ksq_al key domain hs Lq hL R.pf R.rd hL64 hv U hbij emax ND sxs hsx n lg _ (fun i hi sx hmem => ?_)
  rcases i with _ | k
  · exact hS0 sx hmem
  · by_cases hk : k < Lb
    · obtain ⟨rfl, hhelp⟩ := hB k hk sx hmem
      obtain ⟨hdr, core, bga, rs, acc, T', hsa, hT, htr⟩ := ra_blk_acc Pk sgeom check paths digest bRows bLogN
        bndCheck bndOpen R hv G s segs hE (k + 1) k _
        (ra_blk_seg Lb preA preB start inc incG outc outcG Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
          R cx0 pin pout bp wXk gXk mXk hσ k hk) (bp k) (hgeo k)
      rw [htr]
      exact Block.ra_lk_blk U key domain (Pk k) _ absOf (Alk k) (T k) (mlk k) G lg hdr core bga rs acc hsa T'
        (hhelp hdr core bga rs acc T' hsa hT htr)
    · have hk' : k = Lb := by omega
      rw [hk'] at hmem
      exact hS1 sx hmem

end Hal

end ZK60.ProtocolClassify
