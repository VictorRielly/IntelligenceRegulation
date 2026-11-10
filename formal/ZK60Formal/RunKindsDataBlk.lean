/-
D63 lane L43 (2026-11-10), part 2: **non-vacuity of `rkData` at the run's blocks: the reader returns what the run
verifier itself accumulated** (L39 §5 item 1; L31's `tAccRd` carried from the block's own trace to the run's).

`rkData` (`RunKindsData.lean`) takes one accumulator reader per part. For a block, the reader is L31's `tAccRd` (the
whole slot phase read off the trace: the LogUp challenges, each slot's `define` draws, `c`, scalar, rounds and
terminals, `define` re-run) read at the block's ABSOLUTE position on the run's transcript:

* `rkAccBlk`: `tAccRd` of the block's parameters, from the position after the run's steps before the block and the
  frame's five absorbs, on the header cut at the slot phase's end;
* **`rk_blk_run`**: on an accepted run (the run verifier `classifyVerifyE` accepts; both protocol objects reduce to
  it), for a part `i` of the schedule that is a D12a block `k` (`rtBlockSeg`): the verifier decoded a canonical segment
  of the block's shape; ran block `k`'s slot phase on the run's transcript before the part followed by the frame,
  accumulating `acc`; checked `M` on `acc.fs ++ acc.hostFs` (the block's functional count), `A` on `acc.claims.a`, `H`
  on `acc.claims.h ++ [the LogUp sum claim]`, and the closing boundary on the carry's pending claims followed by
  `acc.claims.inp`; handed on `acc.claims.out`; and the reader `rkAccBlk` returns EXACTLY `acc` on every header that
  agrees with the run's transcript up to the slot phase's end. With `RunKindsData.lean`'s `rkData_opA_cl`,
  `rkData_opH_cl`, `rkData_msk_Dm`, `rkData`'s `M`, `A` and `H` readers at block part `i`, on the run's transcript at
  their windows, return the functionals and claims the run verifier itself checked there (used in `RunHalBlk.lean`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsData
import ZK60Formal.RunTrStages
import ZK60Formal.BlockInstRead

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-- **Block `P`'s accumulator reader on the run's transcript**: L31's `tAccRd`, its slot phase read from position `a`
(after the run's steps before the block and the frame's five absorbs), on the header cut at `e` (the slot phase's
end). -/
noncomputable def rkAccBlk (P : Block.BlockParams) (a e : ℕ) (hdr : List (TItem × Dig)) : Block.Acc :=
  Block.tAccRd P a (hdr.take e)

theorem rk_take_take_le {β : Type} (l : List β) (e a : ℕ) (h : e ≤ a) : (l.take a).take e = l.take e := by
  rw [List.take_take, Nat.min_eq_left h]

/-- Two lists related entrywise: the entries at the same index are related. -/
theorem rk_forall₂_getElem? {β γ : Type} {R : β → γ → Prop} : ∀ {l₁ : List β} {l₂ : List γ},
    List.Forall₂ R l₁ l₂ → ∀ (i : ℕ) (a : β) (b : γ), l₁[i]? = some a → l₂[i]? = some b → R a b
  | _, _, .nil, _, _, _, h, _ => by simp at h
  | _, _, .cons hab _, 0, a, b, h1, h2 => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
    subst h1
    subst h2
    exact hab
  | _, _, .cons _ t, i + 1, a, b, h1, h2 =>
    rk_forall₂_getElem? t i a b (by simpa using h1) (by simpa using h2)

section Run

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  {S : BlockShape} {Salt Coins : Type}
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **AN ACCEPTED RUN, AT A BLOCK PART, AS THE RUN VERIFIER SAW IT** (non-vacuity of `rkData` at the blocks). On an
accepted run, if part `i` of the schedule is D12a block `k` with its counts `p`, then the verifier decoded a canonical
segment of block `k`'s shape, ran the slot phase on the run's transcript before the part and the frame, accumulating
`acc`, checked `M`, `A`, `H` and the closing boundary on the accumulator's functionals and claims (the boundary's after
the carry's pending ones), handed on `acc.claims.out`, and the reader `rkAccBlk` returns `acc` on every header that
agrees with the run's transcript up to the slot phase's end. -/
theorem rk_blk_run (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ) (p : RtPart)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p))
    (bp : RtBlk Lq (Pk k)) (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) :
    ∃ (cr : Carry) (sg : Block.Segment) (root : Dig) (ic oc : List Block.ZClaim) (t₂ t' : Tr)
      (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (tM tA tH : Tr),
      R.Inv i cr
      ∧ Block.CoreCanon sg.core ∧ Block.HidingCanon sg.inOpen ∧ Block.CoreShape (Pk k).geom sg.core
      ∧ (R.rd (s, segs)).2[i]? = some (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg)
      ∧ R.pf.parts[i]? = some p
      ∧ sg.bRoot = some root
      ∧ Block.blockSlots (liftH G) (Pk k) sg.core
          (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
            (stpsOps (rtPre R.pf (R.rd (s, segs)) i))) (rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1))))
          = .ok (bga, rs, acc, tM)
      ∧ (acc.fs ++ acc.hostFs).length = (Pk k).nFunctionals
      ∧ (Pk k).maskVerify (liftH G) sg.core.maskRoot (acc.fs ++ acc.hostFs) sg.core.maskOpen tM = .ok tA
      ∧ (Pk k).pcsVerify (liftH G) .a sg.core.aRoot acc.claims.a sg.core.aOpen tA = .ok tH
      ∧ (Pk k).pcsVerify (liftH G) .h sg.core.hRoot (acc.claims.h ++ [(Pk k).logupSumClaim]) sg.core.hOpen tH
          = .ok t₂
      ∧ ic = acc.claims.inp ∧ oc = acc.claims.out
      ∧ bndOpen (liftH G) s k cr.root (cr.pending ++ ic) sg.inOpen t₂ = .ok t'
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨cr, cr', t, t'', hinv, ht, hstep, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  obtain ⟨-, sg, e', root, ic, oc, t₂, hdec, -, hroot, hbv, -, hbo, -, hcr⟩ :=
    (d12a_blockSeg_step_ok_iff Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k (liftH G) s _ _ cr t cr'
      t'').mp hstep
  have hgt' : (sgeom s k).g.slots.length = (sgeom s k).g.terms.length := by
    rw [hgeo s]
    exact bp.hgt
  have hspec := Block.decodeSegment_spec hgt' hdec
  have hshape : Block.CoreShape (Pk k).geom sg.core := by
    have h0 := hspec.2.2.1
    rw [hgeo s] at h0
    exact h0
  have hrd : rtBlockRd Pk sgeom digest bRows bLogN k s (segs.getD i [])
      = rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg := by
    simp only [rtBlockRd, rtSegOf_decode hgt' hdec]
  have hrdi' : (R.rd (s, segs)).2[i]? = some (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) := by
    rw [hrdi]
    exact congrArg some hrd
  have hpi : R.pf.parts[i]? = some p := by
    show (R.σs.map (fun σ => σ.p))[i]? = some p
    rw [List.getElem?_map, hσi]
    rfl
  obtain ⟨bga, rs, acc, tM, tA, tH, hbs, hnf, hmv, hpa, hph, hio⟩ :=
    rt_blockVerify_io (liftH G) (Pk k) sg.core _ (ic, oc) t₂ hbv
  simp only [Prod.mk.injEq] at hio
  obtain ⟨hic, hoc⟩ := hio
  have hgd : sg.bRoot.getD zeroDig = root := by rw [hroot]; rfl
  have hbs' : Block.blockSlots (liftH G) (Pk k) sg.core
      (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
        (stpsOps (rtPre R.pf (R.rd (s, segs)) i))) (rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1))))
      = .ok (bga, rs, acc, tM) := by
    rw [← ht]
    exact hbs
  refine ⟨cr, sg, root, ic, oc, t₂, t'', bga, rs, acc, tM, tA, tH, hinv, hspec.2.1, hspec.2.2.2.1, hshape, hrdi', hpi,
    hroot, hbs', hnf, hmv, hpa, hph, hic.symm, hoc.symm, hbo, ?_⟩
  -- the reader
  intro hdr hhdr
  have hpd : RtPartOk Lq p (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) :=
    rk_forall₂_getElem? hgood.2.2.2 i p _ hpi hrdi'
  have hplen : (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length = p.pre := hpd.1
  obtain ⟨tk, -, -, -, -⟩ := rtTr_part key domain Lq R.pf R.rd hv G (s, segs) hgood i p
    (rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg) hpi hrdi'
    (opsStps (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots))) _ rfl
  rw [stpsOps_opsStps, hplen, stpsOps_append, stpsOps_opsStps, hgd] at tk
  have hlen : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)).length = R.pf.off i := (rtPre_facts Lq R.pf _ hgood i).2.1
  have hbs'' : Block.blockSlots (liftH G) (Pk k) sg.core
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
        ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1)))) = .ok (bga, rs, acc, tM) := by
    rw [runOps_append]
    exact hbs'
  have hread := Block.tAccRd_trace (liftH G) (Pk k) sg.core _ (Tr.newKeyed (liftH G) domain key) bga rs acc tM
    hspec.2.1 hshape.1 (fun j hj => (bp.hgeomL j hj).1) hbs''
  have hl5 : (stpsOps (rtPre R.pf (R.rd (s, segs)) i)
      ++ rtBlockFrame k (digest s k) root (bRows (k + 1)) (bLogN (k + 1))).length = R.pf.off i + 5 := by
    rw [List.length_append, hlen]
    rfl
  rw [hl5] at hread
  unfold rkAccBlk
  rw [hhdr]
  show Block.tAccRd (Pk k) (R.pf.off i + 5) ((rtTr key domain Lq R.pf R.rd G (s, segs)).take (R.pf.off i + p.pre)) = acc
  rw [tk, ← hread]
  simp only [List.append_assoc]

end Run

end ZK60.ProtocolClassify
