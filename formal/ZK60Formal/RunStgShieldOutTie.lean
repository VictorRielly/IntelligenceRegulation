/-
D63 lane L63 (2026-11-16), part 26: **stage OUT-C's IO claims in the code's accumulator form** (step C).

Stage OUT-C reads every slot at one IO width (stage_out_c.rs:89; L63-5 settled SAME for OUT-C, §10), so the run's
OUT-C reader (`rsAccS` at the slot phase's end) IS the reading's accumulator (`ssh_outc_link`). Here:

* `StgClaimsIOCO`: every IO claim of the run's OUT-C reader is true (the accumulator form, as `StgClaimsIOC` for IN-C);
* **`ssh_ioOfIOCO`**: it gives L63's `StgClaimsIO` at OUT-C.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIOTie

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (OutcV)
open ZK60.Circuit (gP GF)

section Out

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Stage OUT-C's IO claims part over the run's accumulator reader** (`rsAccS` at the slot phase's end `e`). -/
def StgClaimsIOCO (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen e : ℕ)
    (absOf : QB L → Option (List UInt8)) (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L (fun _ => P) 2 hdrLen OutcV.bga G τ hdr core ch rs →
    ∀ k q, core.slots[k]? = some q →
      (∀ z ∈ (rsAccS P 2 OutcV.bga hdrLen (τ.take e)).claims.inp, csv (stgVw absOf Lg (opTrace (liftH G)
          (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps P core 2 ++ Block.fullOps P 0 (core.slots.take k)
            ++ Block.slotPreOps P k q))) .inp z = z.value.toK U)
      ∧ (∀ z ∈ (rsAccS P 2 OutcV.bga hdrLen (τ.take e)).claims.out, csv (stgVw absOf Lg (opTrace (liftH G)
          (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps P core 2 ++ Block.fullOps P 0 (core.slots.take k)
            ++ Block.slotPreOps P k q))) .out z = z.value.toK U)

/-- **THE TIE AT STAGE OUT-C**: the accumulator form gives `StgClaimsIO` (the run's reader is the reading's accumulator). -/
theorem ssh_ioOfIOCO (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (hdrLen e : ℕ)
    (absOf : QB L → Option (List UInt8)) (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig)
    (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2)
    (he : e = hdrLen + (7 + 2) + shapeLen P 0 P.geom.slots)
    (hIO : StgClaimsIOCO U key domain P hdrLen e absOf csv G Lg τ) :
    StgClaimsIO U key domain (fun _ => P) 2 hdrLen OutcV.bga absOf csv G Lg τ := by
  intro hdr core ch rs hrd acc t' hacc k q hq
  have hl := ssh_outc_link key domain P hdrLen e G τ hdr core ch rs hrd hgt hd he acc t' hacc
  rw [← hl]
  exact hIO hdr core ch rs hrd k q hq

end Out

end ZK60.ProtocolClassify
