/-
D63 lane L39 (2026-11-10): the gap audit's probe of finding GA-1 (results/zk60_gap_audit_premises_20261110/
gap_d_rtinc.lean), re-asked on the REPAIRED contracts. Scratch file, never imported by the root.

The audit proved, for EVERY `RtInc` (unguarded `hcnt`): `nA = 0 ∧ nH = 1 ∧ nIn = 0 ∧ nOut = 0` (`gap_rtInc_counts`, by
the core with no slots), hence stage IN-C never accepts. After the repair (`hcnt` guarded by the core's slot count):

* `l39_empty_outside_in`, `l39_empty_outside_out`: the audit's witness, the core with no slots, is OUTSIDE the guard at
  every stage verifier (the geometry has 4 / 8 slots), so `hcnt` says nothing about it;
* `l39_real_exists`: the repaired `RtInc` and `RtOutc` EXIST at L29's real stage verifiers (`incVAt`, `outcVAt`);
* `l39_real_counts_not_audit`: at the real `RtInc`, the audit's conclusion is false (`nIn = 1`, `nA = 3`, `nH = 4`,
  `nOut = 1`), so no proof of `gap_rtInc_counts`'s statement for the repaired structure exists;
* `l39_tokenEp_matches`: whenever the real stage IN-C verifier accepts, its endpoint claims number exactly the
  contract's `nIn`.
-/
import ZK60Formal.RunCoverStage

set_option autoImplicit false

namespace L39Probe

open ZK60 ZK60.Exec ZK60.ProtocolClassify ZK60.Exec.StageV

/-- The audit's witness (the core with no slots) is outside the repaired guard at every stage IN-C verifier. -/
theorem l39_empty_outside_in (V : IncV) (core0 : Block.Core) :
    ({ core0 with slots := [] } : Block.Core).slots.length ≠ V.geom.slots.length := by
  rw [rc_incGeom_len]
  simp

/-- Likewise at every stage OUT-C verifier. -/
theorem l39_empty_outside_out (V : OutcV) (core0 : Block.Core) :
    ({ core0 with slots := [] } : Block.Core).slots.length ≠ V.geom.slots.length := by
  rw [rc_outcGeom_len]
  simp

/-- **The repaired contracts exist at L29's real stage verifiers**, for every header type, at the tier's numbers. -/
theorem l39_real_exists {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (pub : IncPub) (geo : IncGeo)
    (blk ed : Block.Dim) (lr elr q eq total : ℕ) (hq : 0 < q) (heq : 0 < eq) (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15)
    (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) (O : OutcPub) (ogeo : OutcGeo) (oblk bd : Block.Dim)
    (idx olr blr oq bq pend : ℕ) (hoq : 0 < oq) (hbq : 0 < bq) (ho15 : 2 ^ O.lt + oq ≤ 2 ^ 15)
    (hb15 : 2 ^ ogeo.bLogN + bq ≤ 2 ^ 15) :
    Nonempty (RtInc Lq (fun _ : Hdr => incVAt tag pub geo blk ed lr elr q eq)
        (fun _ => rcIncGeom (incVAt tag pub geo blk ed lr elr q eq) total)
        (rcIncPart (incVAt tag pub geo blk ed lr elr q eq) q eq))
      ∧ Nonempty (RtOutc Lq (fun (_ : Hdr) v => outcVAt tag (rcVerdict O v) ogeo oblk bd idx olr blr oq bq)
        (fun _ => rcOutcGeom (outcVAt tag O ogeo oblk bd idx olr blr oq bq) total)
        (rcOutcPart (outcVAt tag O ogeo oblk bd idx olr blr oq bq) oq bq pend)) :=
  ⟨⟨rcIncAt Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15⟩,
    ⟨rcOutcAt Lq hL20 tag O ogeo oblk bd idx olr blr oq bq total pend hoq hbq ho15 hb15⟩⟩

/-- **The audit's conclusion `nA = 0 ∧ nH = 1 ∧ nIn = 0 ∧ nOut = 0` is FALSE at the real repaired contract.** -/
theorem l39_real_counts_not_audit {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (pub : IncPub)
    (geo : IncGeo) (blk ed : Block.Dim) (lr elr q eq total : ℕ) (hq : 0 < q) (heq : 0 < eq)
    (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) :
    ¬ ((rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15).nA = 0
      ∧ (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15).nH = 1
      ∧ (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15).nIn = 0
      ∧ (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15).nOut = 0) := by
  rintro ⟨h1, -, -, -⟩
  have h3 : (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15).nA = 3 := rfl
  omega

/-- **The contract's `nIn` is what acceptance demands**: whenever the real stage IN-C verifier accepts, its endpoint
claims number exactly `1` (`check_token_endpoint_opening`), the repaired contract's `nIn`. -/
theorem l39_tokenEp_matches (H : HIn → Dig) (V : IncV) (epRoot : Dig) (seg : StageSeg) (t : Tr)
    (pending : List Block.ZClaim) (root : Dig) (t' : Tr) (hv : V.verify H epRoot seg t = .ok ((pending, root), t')) :
    ∃ (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr), V.slots H seg.core (V.frame H root t) = .ok (recs, acc, t4)
      ∧ acc.claims.inp.length = 1 := by
  obtain ⟨-, -, -, -, -, -, recs, acc, t4, t5, t6, t7, hs, -, -, -, -, -, -, hep, -, -⟩ :=
    (incVerify_ok_iff H V epRoot seg t pending root t').mp hv
  exact ⟨recs, acc, t4, hs, rc_checkTokenEp_len H _ _ _ _ _ hep⟩

end L39Probe

#print axioms L39Probe.l39_empty_outside_in
#print axioms L39Probe.l39_empty_outside_out
#print axioms L39Probe.l39_real_exists
#print axioms L39Probe.l39_real_counts_not_audit
#print axioms L39Probe.l39_tokenEp_matches
