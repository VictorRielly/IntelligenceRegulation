/-
D63 lane L55 (2026-11-10), part 5: **the carry between two parts, tied to the run's transcript** (the first step of the
closing openings `hopX1` of parts `1` on; findings L43-3, L55-4).

Part `i ≥ 1`'s closing opening opens the root and the claims part `i − 1` handed on. L34's `RtRun.accept_part` gives,
for each part alone, a carry meeting the part's invariant (the pending claims' COUNT) and the transcript before the
part; L43's `rk_blk_run` reads the block's data from that carry, so its claims and root are not the previous part's
(finding L55-4). L45's `rx_accept_two` gives two consecutive steps on ONE carry, but not the transcript before the
second. Here:

* **`cb_pre_succ`**: the run's steps before part `j + 1` are those before part `j` and part `j`'s;
* **`cb_two`**: on an accepted run, for consecutive parts `j`, `j + 1`: part `j`'s step from a carry meeting `Inv j` on
  the transcript before part `j`, handing on `cr'`, which meets `Inv (j + 1)`, on the transcript before part `j + 1`,
  and part `j + 1`'s step from `cr'` on it;
* **`cb_blk_run_of`**: L43's `rk_blk_run` at a GIVEN carry and step (so the carry can be the previous part's), and the
  carry it hands on: `⟨acc.claims.out, B_{k+1}⟩`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsDataBlk
import ZK60Formal.RunExtractCarry

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

section Two

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **The run's steps before part `j + 1`** are those before part `j` and part `j`'s, on an output of the profile's
shape. -/
theorem cb_pre_succ (pf : RtProf) (o : List Op × List RtData) (h : RtGood Lq pf o) (j : ℕ) (p : RtPart) (d : RtData)
    (hp : pf.parts[j]? = some p) (hd : o.2[j]? = some d) :
    rtPre pf o (j + 1) = rtPre pf o j ++ rtPartStps p d := by
  have e1 := (rtPre_facts Lq pf o h j).1
  have e2 := (rtPre_facts Lq pf o h (j + 1)).1
  rw [rtPartsStps_drop _ _ j p d hp hd] at e1
  have e3 := e2.symm.trans e1
  rw [← List.append_assoc] at e3
  exact List.append_cancel_right e3

/-- **TWO CONSECUTIVE PARTS OF AN ACCEPTED RUN, ON ONE CARRY, EACH ON THE RUN'S TRANSCRIPT BEFORE IT.** -/
theorem cb_two (R : RtRun V key domain Lq) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8))
    (hacc : classifyVerifyE V H s segs = .ok ()) (j : ℕ) (σ σ' : RtSeg (ClsStmt Hdr)) (hσ : R.σs[j]? = some σ)
    (hσ' : R.σs[j + 1]? = some σ') :
    ∃ (cr cr' cr'' : Carry) (t t' t'' : Tr), R.Inv j cr
      ∧ t = runOps H (Tr.newKeyed H domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) j))
      ∧ segStep σ.v H s (V.start H s).state (segs.getD j []) cr t = .ok (cr', t')
      ∧ R.Inv (j + 1) cr'
      ∧ t' = runOps H (Tr.newKeyed H domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) (j + 1)))
      ∧ segStep σ'.v H s (V.start H s).state (segs.getD (j + 1) []) cr' t' = .ok (cr'', t'') := by
  obtain ⟨cr, cr', cr'', t, t', t'', hinv, ht, h1, h2⟩ := rx_accept_two R H s segs hacc j σ σ' hσ hσ'
  obtain ⟨et, -, hinv'⟩ := R.hσ j σ hσ H s _ _ cr t cr' t' hinv h1
  obtain ⟨hgood, -⟩ := R.accept H s segs hacc
  obtain ⟨-, -, -, -, -, -, -, hrdj⟩ := R.accept_part H s segs hacc j σ hσ
  have hpj : R.pf.parts[j]? = some σ.p := by
    show (R.σs.map (fun σ => σ.p))[j]? = some σ.p
    rw [List.getElem?_map, hσ]
    rfl
  have hpre := cb_pre_succ R.pf (R.rd (s, segs)) hgood j σ.p _ hpj hrdj
  refine ⟨cr, cr', cr'', t, t', t'', hinv, ht, h1, hinv', ?_, h2⟩
  rw [et, hpre, stpsOps_append, runOps_append, ← ht]

end Two

section Blk

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
  (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
  (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
  (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **L43's `rk_blk_run` AT A GIVEN CARRY AND STEP**, with the carry the block hands on. On an accepted run, if part
`i` is D12a block `k` and its step accepted from the carry `cr` on the run's transcript before the part, handing on
`cr'`: the verifier decoded a canonical segment of block `k`'s shape, ran the slot phase, checked `M`, `A`, `H` and
the closing boundary (opened against `cr.root` on `cr.pending ++ acc.claims.inp`), handed on
`cr' = ⟨acc.claims.out, B_{k+1}⟩`, and `rkAccBlk` reads `acc` off every header agreeing with the run's transcript up to
the slot phase's end. -/
theorem cb_blk_run_of (R : RtRun V key domain Lq) (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (i k : ℕ) (p : RtPart)
    (hσi : R.σs[i]? = some (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p))
    (bp : RtBlk Lq (Pk k)) (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom)
    (cr cr' : Carry) (t t'' : Tr)
    (ht : t = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i)))
    (hstep : segStep (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k p).v (liftH G) s
      (V.start (liftH G) s).state (segs.getD i []) cr t = .ok (cr', t'')) :
    ∃ (sg : Block.Segment) (root : Dig) (ic oc : List Block.ZClaim) (t₂ : Tr)
      (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (tM tA tH : Tr),
      Block.CoreCanon sg.core ∧ Block.HidingCanon sg.inOpen ∧ Block.CoreShape (Pk k).geom sg.core
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
      ∧ bndOpen (liftH G) s k cr.root (cr.pending ++ ic) sg.inOpen t₂ = .ok t''
      ∧ cr' = ⟨acc.claims.out, root⟩
      ∧ ∀ hdr : List (TItem × Dig), hdr.take (R.pf.off i + p.pre) = (R.tr G (s, segs)).take (R.pf.off i + p.pre) →
          rkAccBlk (Pk k) (R.pf.off i + 5) (R.pf.off i + p.pre) hdr = acc := by
  obtain ⟨-, -, -, -, -, -, -, hrdi⟩ := R.accept_part (liftH G) s segs hE i _ hσi
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
  have hcr' : cr' = ⟨acc.claims.out, root⟩ := by
    rw [hcr, ← hoc]
  refine ⟨sg, root, ic, oc, t₂, bga, rs, acc, tM, tA, tH, hspec.2.1, hspec.2.2.2.1, hshape, hrdi', hpi,
    hroot, hbs', hnf, hmv, hpa, hph, hic.symm, hoc.symm, hbo, hcr', ?_⟩
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

end Blk

end ZK60.ProtocolClassify
