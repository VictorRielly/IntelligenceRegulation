/-
D63 lane L56 (2026-11-10), part 8: **the define draws' polynomials also see the run's header data** (finding L56-7, the
same type obstruction as L54-1, for the boundary slots' DEFINE draws; deliverable 3, finding L46-3's `DIO`).

The two boundary slots of every R13 block (`SC_IO_IN`, `SC_IO_OUT`: `ioIr` on `[eq(τ), aPlane x / x2, epTab inp / out]`)
draw their `eq` point `τ` with `define`; the draw is good when `Σ_x eq(τ, x)·(A(x) − B(x))` vanishes at the drawn `τ`,
where `B` is the BOUNDARY table. Lane L21's draw sub-protocol `defSq P hdrLen absOf Φ dg k` and lane L50's `RaDefAt` give
its polynomial `Φ` only the block's `A`, `M`, `H` cuts and roots (`Cuts3 → RootsO → …`, as L16's slots before this lane),
so no `Φ` of that type is the boundary draws' polynomial for every adversary. Here, as for the slots:

* **`defSqB`**: the draw sub-protocol whose polynomial also receives the header's roots and cuts (`hdrX`);
  `defSqB_rbr` (Schwartz–Zippel from the degree, `RtSqOk`'s `Rbr`), **`defSqB_cut`** (a cut reader, `RtSqOk`'s `SqCut`);
* **`ra_def_blkB`**: lane L50's `ra_def_blk` for it (the draw is alive at the end of any extension of the block's trace
  when its polynomial vanishes at the drawn challenges);
* `RaDefAtB`, **`ra_hal_defB`**: lane L50's `RaDefAt`, `ra_hal_def` for it: a define kind's alive conclusion on the
  classify run, when every block part's draws of that kind are `defSqB` draws vanishing at every reading.

A draw that does not read the boundary (every relation layer's) is a `defSqB` draw whose polynomial ignores the header
data, so the kinds data can list every block draw as `defSqB` (the restated top theorem does: `RaDefAtB` for all four
define kinds).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunBndHal

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section DefB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Slot `k`'s draws as a sub-protocol, its polynomial also over the header's roots and cuts**: lane L21's `defSq`
whose polynomial `Φ (cuts) (roots) (hdrX) k (hist)` also sees every root the run absorbed before the block. -/
def defSqB (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (k : ℕ) : SqX K L where
  a := defPos P hdrLen k
  n := P.draws k
  e := dg k
  St Lg hdr τ :=
    match tHistD P hdrLen k hdr with
    | some (h, _) => szSt (Φ (cuts3 absOf Lg (rootsAt hdrLen hdr)) (rootsAt hdrLen hdr) (hdrX absOf Lg hdrLen hdr) k h) τ
    | none => True

omit [Algebra GF K] in
/-- Its round condition: Schwartz–Zippel's, from the degree. -/
theorem defSqB_rbr [Fintype K] [DecidableEq K] (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (k : ℕ)
    (hdeg : ∀ cu rt hx h, IndDegLE (dg k) (Φ cu rt hx k h)) : (defSqB P hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ m hτ hns
  simp only [defSqB] at hns ⊢
  split at hns
  · exact szSt_escape _ (hdeg _ _ _ _) τ m hτ hns
  · exact absurd trivial hns

/-- **A BLOCK'S DEFINE DRAW (NEW FORM) IS ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE** (lane L50's `ra_def_blk`):
when the block's slot phase accepted after the header `hdr`, slot `k`'s draw `defSqB P hdrLen absOf Φ dg k` is alive at
the end of the trace of the block's operations followed by any operations `T`, provided its polynomial (at the core's
roots and the header's roots and cuts) vanishes at the outcome's drawn challenges. -/
theorem ra_def_blkB (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (hdr : List Op) (core : Core) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (acc : Acc) (hacc : SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc) (T : List Op)
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r)
    (hzero : Φ (cuts3 absOf Lg (rootsOf core)) (rootsOf core)
      (hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)) k
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0) :
    subSt W1 (sqSub U (defSqB P hdrLen absOf Φ dg k) Lg)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core) ++ T)) := by
  obtain ⟨hhl, -, -, hsh, t', hbs⟩ := hacc
  simp only at hhl hsh hbs
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [blockSlots_eq] at hbs
  simp only [← runOps_append] at hbs
  split at hbs
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hbs
    obtain ⟨hbga, hres⟩ := hbs
    subst hres
    subst hbga
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs' htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hgeom i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
        r.draws = (preVals (liftH G) P (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core)) 0 core.slots i) i q).1 := by
      intro i q r hq hr
      have h1 := congrArg Prod.fst (hall i q r hq hr).1
      rw [Nat.zero_add] at h1
      exact h1
    have hk : k < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
    obtain ⟨hw1, ⟨rest, hw2⟩, hw3⟩ := def_window (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq
      hround
    rw [hhl] at hw1
    rw [hhl] at hw2
    rw [hhl] at hw3
    have hhist := tHistD_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k hk.le hround rs
      (by omega) hv
    rw [hhl] at hhist
    have hroots := rootsAt_trace (liftH G) P core hdr (fullOps P 0 (core.slots.take k))
      (Tr.newKeyed (liftH G) domain key)
    rw [hhl] at hroots
    have hX : hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)))
        = hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) := by
      rw [List.append_assoc]
      exact hdrX_opTrace_pre absOf Lg (liftH G) _ hdr _ hdrLen hhl
    obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) (P.draws k)
      (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core)) 0
        core.slots k)
    have hext : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (allOps P (hdr, core) ++ T)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) T :=
      opTrace_append (liftH G) _ _ _
    rw [hext]
    refine ZK60.ProtocolClassify.ra_sq_end U _ Lg _ ks' ds (rest ++ opTrace (liftH G) (runOps (liftH G)
      (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) T) h2 (by rw [h2, h3]) ?_ ?_
    · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ _).drop (defPos P hdrLen k) = _
      rw [List.drop_append_of_le_length hw3, hw2, h1, List.append_assoc]
    · show (defSqB P hdrLen absOf Φ dg k).St Lg
        ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          ++ _).take (defPos P hdrLen k)) _
      rw [List.take_append_of_le_length hw3, hw1]
      simp only [defSqB, hhist, hroots, hX]
      have h4' : ds.map challengeFp2Of = r.draws := by
        rw [hv k q r hq hr]
        exact h4
      have hm : ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))
          = (r.draws.map (Fp2.toK U)).map (fun c => (([] : List UInt8), c)) := by
        rw [← h4']
        simp only [List.map_map, Function.comp_def]
      have hlenr : (r.draws.map (Fp2.toK U)).length = P.draws k := by
        rw [List.length_map, ← h4', List.length_map, h3]
      rw [hm, szSt_full_map _ _ _ hlenr]
      have hf : (fun i : Fin (P.draws k) => (r.draws.map (Fp2.toK U)).getD i.val 0)
          = (fun i : Fin (P.draws k) => (r.draws.getD i.val Fp2.zero).toK U) :=
        funext (fun i => getD_map_toK U _ _)
      rw [hf]
      exact hzero
  · cases hbs

end DefB

end ZK60.Exec.Block

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV incHeadDraws IncCtx)
open ZK60.Circuit (gP GF)

section CutB

variable {K : Type} [Field K] {L : ℕ}

/-- **The new draws' states are cut readers** (`RtSqOk`'s `SqCut`). -/
theorem defSqB_cut (P0 : Exec.Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Exec.Block.Cuts3 L → Exec.Block.RootsO → Exec.Block.HdrX L → (k : ℕ) → Exec.Block.Hist →
      (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqCut absOf (Exec.Block.defSqB P0 hdrLen absOf Φ dg k) := by
  intro P P' hdr h τr
  have eX : Exec.Block.hdrX absOf P hdrLen hdr = Exec.Block.hdrX absOf P' hdrLen hdr := by
    funext i
    by_cases hi : i < hdrLen
    · simp only [Exec.Block.hdrX, ite_eq_left hi, h i]
    · simp only [Exec.Block.hdrX, ite_eq_right hi]
  simp only [Exec.Block.defSqB, cuts3_cutEq absOf hdr P P' h hdrLen, eX]

end CutB

/-! ## The define kinds' alive conclusions for the new draws -/

section AtDefB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A squeeze run is one of block `P`'s define draws in the new form (at `hdrLen`), vanishing at every reading**
(lane L50's `RaDefAt` with the polynomial also over the header's roots and cuts of `τ`). -/
def RaDefAtB (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8)) (G : QB L → Dig) (lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (sx : SqX K L) : Prop :=
  ∃ (Φ : Block.Cuts3 L → Block.RootsO → Block.HdrX L → (j : ℕ) → Block.Hist → (Fin (P.draws j) → K) → K)
    (dg : ℕ → ℕ) (s : ℕ),
    sx = Block.defSqB P hdrLen absOf Φ dg s
    ∧ ∀ (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
      (T : List Op), Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc → (∀ op ∈ T, op.len ≤ L) →
      τ = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T) →
      ∃ r, rs[s]? = some r ∧ Φ (Block.cuts3 absOf lg (Block.rootsOf core)) (Block.rootsOf core)
        (Block.hdrX absOf lg hdrLen τ) s (Block.histOf bga.1 bga.2.1 bga.2.2 (rs.take s))
        (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0

end AtDefB

section HalDefB

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

/-- **A define kind's conclusion on the classify run, for the new draws** (lane L50's `ra_hal_def`): on an accepted
run, if every block part's squeeze runs of the kind are the block's define draws in the new form vanishing at the
block's reading (`hB`, `RaDefAtB`), and the two stage parts' are alive (`hS0`, `hS1`), the kind is alive at the end of
the run's transcript. -/
theorem ra_hal_defB (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
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
      RaDefAtB U key domain (Pk k) (R.pf.off (k + 1) + 5) absOf G lg (R.tr G (s, segs)) sx)
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
      rw [ra_blk_hdrX key domain (Pk k) _ absOf G lg _ hdr core bga rs acc T hsa htr] at hz
      rw [htr]
      exact Block.ra_def_blkB U key domain (Pk k) _ absOf Φ dg (fun j hj => ((bp k).hgeomL j hj).1) (bp k).hgt G
        lg hdr core bga rs acc hsa T s' r hr hz
    · have hk' : k = Lb := by omega
      rw [hk'] at hmem
      exact hS1 sx hmem

end HalDefB

end ZK60.ProtocolClassify
