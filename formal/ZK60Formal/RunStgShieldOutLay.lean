/-
D63 lane L63 (2026-11-20), L63 leg 14, part 95: **`shdOutcLay` and `shdOutcData`: stage OUT-C's `OutCLayout` and
`OutCData` at a view** (item 5 of HANDOFF_20261119_3.md section 6), and `OutCSat` from the slot facts with TZC's four
facts as the one remaining input (`shd_outC_of_parts`).

* `shdOutcLay`: `To`'s entry `0` (`z0 = fun _ => false`), the isqrt limb sub-planes (`lpos s z`: `Lo`'s entry `2s + z`),
  the margin limbs (`mpos j`: `Lo`'s entry `32 + j`), `zl0 = msbBits 12 0`, no lift (`d_bits = ldo = 12`), the live
  channels and table rows at `msbBits 12`, and the public tables written by their specifications;
* `shdOutcData`: the `A_out` planes `D`, `Dsq` (log `1`), the limb plane, the twelve `Do` planes, the byte histogram
  (log `12`) at `A_out`'s header index, and `B_out`'s verdict row (`bxUxV`'s R13 plane reader at `msbBits 7 row ++ c`);
* **`shd_outC_of_parts`**: OUTC-00's equation, TZC's four facts, DZC's clauses at the live channels, the margin and
  `AllBytes` give `OutCSat P (fun i => B_out(row, msbBits 12 i)) b` (`outC_of_facts`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutRd

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic OutCSat sigOf)

section Lay

variable {K : Type} [Field K]

theorem msbBits12_injLt (n : ℕ) (f : Fin n → ℕ) (hf : ∀ i, f i < 4096) (hfi : Function.Injective f) :
    Function.Injective (fun i : Fin n => msbBits 12 (f i)) := fun a a' h =>
  hfi (msbBits12_eq_of (f a) (f a') (hf a) (hf a') h)

/-- **Stage OUT-C's layout map and public tables** (`n₀ = 1`, `nd = ndo = nl = nt = 12`, no lift). -/
noncomputable def shdOutcLay (φ : GF →+* K) {d : ℕ} (P : OutCPublic d) (b : ℕ) (hd : d ≤ 4096)
    (hlim : 32 + P.limbs ≤ 4096) : OutCLayout φ P b 1 12 12 12 12 where
  z0 := fun _ => false
  lpos := fun s z => msbBits 12 (2 * s.val + msbIndex 1 z)
  mpos := fun j => msbBits 12 (32 + j.val)
  zl0 := msbBits 12 0
  dlift := fun c => c
  dpos := fun i => msbBits 12 i.val
  tpos := fun j => msbBits 12 j.val
  mpos_inj := msbBits12_injLt P.limbs (fun j => 32 + j.val) (fun j => by have := j.isLt; omega)
    (fun a a' h => Fin.ext (by simpa using h))
  dpos_inj := msbBits12_injLt d (fun i => i.val) (fun i => by have := i.isLt; omega) (fun a a' h => Fin.ext h)
  live_inj := msbBits12_injLt d (fun i => i.val) (fun i => by have := i.isLt; omega) (fun a a' h => Fin.ext h)
  tpos_inj := msbBits12_injLt 256 (fun j => j.val) (fun j => by have := j.isLt; omega)
    (fun a a' h => Fin.ext h)
  u0 := fun z => if z = (fun _ => false) then 1 else 0
  sD := fun c => if msbIndex 12 c < d then 1 else 0
  sL := fun _ => 0
  Gm := fun z => if 32 ≤ msbIndex 12 z ∧ msbIndex 12 z < 32 + P.limbs then
    φ (sigOf b * (2 : GF) ^ (8 * (msbIndex 12 z - 32))) else 0
  uL := fun z => if z = msbBits 12 0 then 1 else 0
  wd := fun c => if h : msbIndex 12 c < d then φ (P.wΔ ⟨msbIndex 12 c, h⟩ : GF) else 0
  sT := fun c => if msbIndex 12 c < 256 then 1 else 0
  tv := fun g c => ((msbIndex 12 c : ℕ) : K) + g
  u0_eq := fun _ => rfl
  sD1 := fun i => by
    show (if msbIndex 12 (msbBits 12 i.val) < d then (1 : K) else 0) = 1
    rw [msbIndex_msbBits 12 i.val (by have := i.isLt; omega), ite_eq_left i.isLt]
  sD0 := fun c hc => by
    show (if msbIndex 12 c < d then (1 : K) else 0) = 0
    refine ite_eq_right (fun hlt => hc ⟨⟨msbIndex 12 c, hlt⟩, msbBits_msbIndex 12 c⟩)
  Gm_pos := fun j => by
    have hj := j.isLt
    show (if 32 ≤ msbIndex 12 (msbBits 12 (32 + j.val)) ∧ msbIndex 12 (msbBits 12 (32 + j.val)) < 32 + P.limbs then
      φ (sigOf b * (2 : GF) ^ (8 * (msbIndex 12 (msbBits 12 (32 + j.val)) - 32))) else 0) = _
    rw [msbIndex_msbBits 12 (32 + j.val) (by omega), ite_eq_left (by omega),
      show 32 + j.val - 32 = j.val by omega]
  Gm0 := fun z hz => by
    show (if 32 ≤ msbIndex 12 z ∧ msbIndex 12 z < 32 + P.limbs then
      φ (sigOf b * (2 : GF) ^ (8 * (msbIndex 12 z - 32))) else 0) = 0
    refine ite_eq_right (fun h => hz ⟨⟨msbIndex 12 z - 32, by omega⟩, ?_⟩)
    show msbBits 12 (32 + (msbIndex 12 z - 32)) = z
    rw [show 32 + (msbIndex 12 z - 32) = msbIndex 12 z by omega, msbBits_msbIndex]
  uL_eq := fun _ => rfl
  wd_pos := fun i => by
    have hi := i.isLt
    have e : msbIndex 12 (msbBits 12 i.val) = i.val := msbIndex_msbBits 12 i.val (by omega)
    show (if h : msbIndex 12 (msbBits 12 i.val) < d then φ (P.wΔ ⟨msbIndex 12 (msbBits 12 i.val), h⟩ : GF) else 0) = _
    rw [dite_eq_left (by rw [e]; exact hi)]
    congr 3
    exact Fin.ext e
  wd0 := fun c hc => by
    show (if h : msbIndex 12 c < d then φ (P.wΔ ⟨msbIndex 12 c, h⟩ : GF) else 0) = 0
    refine dite_eq_right (fun hlt => absurd ⟨⟨msbIndex 12 c, hlt⟩, msbBits_msbIndex 12 c⟩ hc)
  sT1 := fun j => by
    show (if msbIndex 12 (msbBits 12 j.val) < 256 then (1 : K) else 0) = 1
    rw [msbIndex_msbBits 12 j.val (by have := j.isLt; omega), ite_eq_left j.isLt]
  sT0 := fun c hc => by
    show (if msbIndex 12 c < 256 then (1 : K) else 0) = 0
    refine ite_eq_right (fun hlt => hc ⟨⟨msbIndex 12 c, hlt⟩, msbBits_msbIndex 12 c⟩)
  tv_pos := fun g j => by
    show ((msbIndex 12 (msbBits 12 j.val) : ℕ) : K) + g = _
    rw [msbIndex_msbBits 12 j.val (by have := j.isLt; omega)]

end Lay

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **Stage OUT-C's committed data at a view**: the `A_out` planes at header index `iA` and `B_out`'s verdict row. -/
noncomputable def shdOutcData (O : OutcPub) (iA rX ipos row : ℕ) (w : StgVw Lq) : OutCData 1 12 12 12 12 where
  D := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff ocC_D) 1 w
  Dsq := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff ocC_DSQ) 1 w
  limb := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff ocC_LIMB) 12 w
  pl := fun p => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff (ocC_X + p.val)) 12 w
  mult := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e 76 iA ((outcLay O 14).aOff ocC_MULT) 12 w
  bout := fun c => Exec.Block.Join.W16.piB K (Exec.Block.Join.planeZ U 14 rX 256 (bxUxV tag Lq h64 rX ipos w)
    ⟨.a, [(0, Fp2.one)], 19, [], 0, 0⟩ (Fin.append (msbBits 7 row) c))

/-- **`OutCSat` from the slot facts**: OUTC-00's equation, TZC's four facts (item 3, the one input not yet derived from
the slots), DZC's clauses at the live channels, the margin and `AllBytes`. -/
theorem shd_outC_of_parts (O : OutcPub) (iA rX ipos row : ℕ) (w : StgVw Lq) {d : ℕ} (P : OutCPublic d) (b : ℕ)
    (hd : d ≤ 4096) (hlim : 32 + P.limbs ≤ 4096)
    (hio : ∀ c, (shdOutcData U tag h64 O iA rX ipos row w).pl 0 c = (shdOutcData U tag h64 O iA rX ipos row w).bout c)
    (htzc : let Dt := shdOutcData U tag h64 O iA rX ipos row w
      let L := shdOutcLay (algebraMap GF K) P b hd hlim
      Dt.Dsq L.z0 - Dt.D L.z0 * Dt.D L.z0 = 0 ∧
      Dt.D L.z0 - l3 (tzcLimbs (algebraMap GF K) P b Dt L 0) = 0 ∧
      2 * Dt.D L.z0 - l3 (tzcLimbs (algebraMap GF K) P b Dt L 1) - l3 (tzcLimbs (algebraMap GF K) P b Dt L 2) = 0 ∧
      Dt.Dsq L.z0 + l3 (tzcLimbs (algebraMap GF K) P b Dt L 1) - (P.ceps : GF)
        = ∑ i, liveW (algebraMap GF K) P b Dt L 0 i * liveW (algebraMap GF K) P b Dt L 0 i)
    (hdz : ∀ (i : Fin d) (j : Fin 3), dzcCB P (shdOutcData U tag h64 O iA rX ipos row w)
      ((shdOutcData U tag h64 O iA rX ipos row w).D (fun _ => false)) j (msbBits 12 i.val) = 0)
    (hmar : sigOf b * limbSum (fun j : Fin P.limbs =>
        (shdOutcData U tag h64 O iA rX ipos row w).limb (msbBits 12 (32 + j.val))) + ((b : GF) + (P.c : GF))
      = ∑ i : Fin d, (shdOutcData U tag h64 O iA rX ipos row w).pl 3 (msbBits 12 i.val) * (P.wΔ i : GF))
    (hB : AllBytes (shdOutcData U tag h64 O iA rX ipos row w).limb (outcP1 (shdOutcData U tag h64 O iA rX ipos row w))
      (outcP2 (shdOutcData U tag h64 O iA rX ipos row w))) :
    OutCSat P (fun i => (shdOutcData U tag h64 O iA rX ipos row w).bout (msbBits 12 i.val)) b := by
  obtain ⟨t1, t2, t3, t4⟩ := htzc
  exact outC_of_facts (algebraMap GF K) P b (shdOutcData U tag h64 O iA rX ipos row w)
    (shdOutcLay (algebraMap GF K) P b hd hlim) hB
    ⟨fun c => hio c, t1, t2, t3, t4, fun i j => hdz i j, hmar⟩

end Data

end ZK60.ProtocolClassify
