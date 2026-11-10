/-
D63 lane L34 (2026-11-09), part 2: **the classify run's ONE transcript as a Lean object, and its two parses** (L30 §5.7
items 1 and 2; findings L27-2 and L28-1 at run level).

The run is a run header, then `L + 2` parts (stage IN-C, the blocks, stage OUT-C) on one keyed transcript. Every part
has the same schedule: a phase of single operations (its frame, its roots, its head's challenges, its sumcheck slots),
then `M`'s check, then three regular openings (`A`, `H`, and the commitment the part closes: the input endpoint for
stage IN-C, the previous boundary for a block, `B_out` for stage OUT-C). Here:

* `RtPart`: one part's counts (the PROFILE's: the single phase's operations and squeezes, `M`'s mask-spec count, each
  opening's batching width, group count and index squeezes), its windows (`oA`, `oBA`, `oH`, `oBH`, `oX`, `oBX`), its
  length `len`, its squeeze count `sq` and its squeeze runs `sqs`;
* `RtData`: what the verifier absorbs in a part (the single phase's operations, `M`'s and the three openings' data),
  `rtPartStps`: the part's steps (L22's `mStps`, `pcsStps`), `RtPartOk`: the data has the profile's counts and fits;
* `RtProf`: the run's profile (the header's counts, the parts), `off i` / `sqAt i`: part `i`'s position and squeeze
  counter, `RtProf.Valid`: the bounds a parse needs; `rtStps`: the run's steps; `RtGood`: an output of the profile's
  shape; `rtPre`: the run's steps before part `i`;
* **`rtTr`**: THE RUN'S ONE TRANSCRIPT, `opTrace` of the run's operations for an output of the profile's shape (else
  empty), for every oracle and output;
* **`rtRC1`** (single steps, `W1`: L21's parse) and **`rtRC2`** (wide runs, `rtW` of the profile's runs: L20 / L22's
  parse): the two `RunChain`s, with `StepsOK`, `StepCont`, at most `2^21` items, the header;
  **`rtRC1_chain`**, **`rtRC2_chain`**: each chain IS `rtTr` (`KindRun.htr`), for every oracle and output;
* **`rtStps_facts`**, **`rtPre_facts`**: on an output of the shape, the run's squeeze runs, length and fit are the
  profile's, and part `i` starts at `off i` with `sqAt i` squeezes before it: the windows are fixed positions (L27-2);
* **`rtTr_split`**, **`rtTr_part`**: the transcript cut at any step boundary (a part's start, a window inside a part):
  the prefix is the trace of the steps before, it parses as whole steps under the wide parse, the transcript there has
  the profile's counter, and what follows parses from that counter (so every width at every window is the profile's).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrBase

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

/-! ## One part's schedule -/

/-- **One part's counts** (stage IN-C, a block, stage OUT-C), the PROFILE's: the operations `pre` and squeezes `preSq` of
its single-step phase (its frame, its roots, its head's challenges, its slots), `M`'s mask-spec count `S`, and for each
of its three openings (`A`, `H`, and the commitment it closes, `X`) the batching run's width (claims plus rows), the
number of group vectors and the index squeezes. -/
structure RtPart where
  pre : ℕ
  preSq : ℕ
  S : ℕ
  wA : ℕ
  gA : ℕ
  mA : ℕ
  wH : ℕ
  gH : ℕ
  mH : ℕ
  wX : ℕ
  gX : ℕ
  mX : ℕ
  deriving Inhabited

namespace RtPart

variable (p : RtPart)

/-- `A`'s window in the part (after the single phase and `M`'s `2S + 69` items). -/
def oA : ℕ := p.pre + (2 * p.S + 69)
/-- `A`'s second window (after the batching run and the group vectors). -/
def oBA : ℕ := p.oA + (p.wA + p.gA)
/-- `H`'s window. -/
def oH : ℕ := p.oBA + (1 + p.mA)
/-- `H`'s second window. -/
def oBH : ℕ := p.oH + (p.wH + p.gH)
/-- The closing opening's window. -/
def oX : ℕ := p.oBH + (1 + p.mH)
/-- The closing opening's second window. -/
def oBX : ℕ := p.oX + (p.wX + p.gX)
/-- The part's operations. -/
def len : ℕ := p.oBX + (1 + p.mX)
/-- The part's squeezes. -/
def sq : ℕ := p.preSq + (2 * p.S + 67) + (p.wA + p.mA) + (p.wH + p.mH) + (p.wX + p.mX)
/-- The part's squeeze runs, in order. -/
def sqs : List ℕ := List.replicate p.preSq 1 ++ [1, 2 * p.S + 2, 64, p.wA, p.mA, p.wH, p.mH, p.wX, p.mX]

theorem sqs_sum : p.sqs.sum = p.sq := by
  simp only [sqs, sq, List.sum_append, List.sum_replicate, smul_eq_mul, mul_one, List.sum_cons, List.sum_nil]
  omega

end RtPart

/-- **What the verifier absorbs in one part**: the single phase's operations, `M`'s opening, the three openings. -/
structure RtData where
  pre : List Op
  mo : Block.MaskOpening
  aO : Block.OpeningZk
  hO : Block.OpeningZk
  xO : Block.OpeningZk

/-- **One part's steps**: the single phase, `M`, `A`, `H`, the closing opening (L22's `mStps`, `pcsStps`, with the
profile's widths). -/
def rtPartStps (p : RtPart) (d : RtData) : List Stp :=
  opsStps d.pre ++ (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO ++ (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO)))

/-- **A part's data of the profile's shape**: the single phase's operation and squeeze counts, the openings' group
counts, and every operation within `Lq` bytes. -/
def RtPartOk (Lq : ℕ) (p : RtPart) (d : RtData) : Prop :=
  d.pre.length = p.pre ∧ sqN d.pre = p.preSq ∧ d.aO.groupVecs.length = p.gA ∧ d.hO.groupVecs.length = p.gH
    ∧ d.xO.groupVecs.length = p.gX ∧ ∀ op ∈ stpsOps (rtPartStps p d), op.len ≤ Lq

/-- A part's operations: the single phase's, then `M`'s and the three openings'. -/
theorem rtPartStps_ops (p : RtPart) (d : RtData) :
    stpsOps (rtPartStps p d) = d.pre ++ stpsOps (mStps p.S d.mo ++ (pcsStps p.wA p.mA d.aO
      ++ (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO))) := by
  unfold rtPartStps
  rw [stpsOps_append, stpsOps_opsStps]

theorem rtSqs_partStps (p : RtPart) (d : RtData) (hsq : sqN d.pre = p.preSq) : rtSqs (rtPartStps p d) = p.sqs := by
  unfold rtPartStps RtPart.sqs
  rw [rtSqs_append, rtSqs_append, rtSqs_append, rtSqs_append, rtSqs_opsStps, rtSqs_mStps, rtSqs_pcsStps, rtSqs_pcsStps,
    rtSqs_pcsStps, hsq]
  rfl

theorem rtPartStps_length (p : RtPart) (d : RtData) (h1 : d.pre.length = p.pre) (hA : d.aO.groupVecs.length = p.gA)
    (hH : d.hO.groupVecs.length = p.gH) (hX : d.xO.groupVecs.length = p.gX) :
    (stpsOps (rtPartStps p d)).length = p.len := by
  unfold rtPartStps
  rw [stpsOps_append, stpsOps_append, stpsOps_append, stpsOps_append, stpsOps_opsStps]
  simp only [List.length_append, stpsOps_mStps_length, stpsOps_pcsStps_length, h1, hA, hH, hX, RtPart.len,
    RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
  omega

/-! ## The run's profile and steps -/

/-- **The run's profile**: the run header's operations and squeezes, and the parts in the run's order (stage IN-C,
block `0`, …, block `L − 1`, stage OUT-C). -/
structure RtProf where
  hdrLen : ℕ
  hdrSq : ℕ
  parts : List RtPart

namespace RtProf

variable (pf : RtProf)

/-- The run's squeeze runs. -/
def sqs : List ℕ := List.replicate pf.hdrSq 1 ++ pf.parts.flatMap RtPart.sqs
/-- **Part `i`'s position** on the run's transcript. -/
def off (i : ℕ) : ℕ := pf.hdrLen + ((pf.parts.map RtPart.len).take i).sum
/-- The squeezes before part `i`. -/
def sqAt (i : ℕ) : ℕ := pf.hdrSq + ((pf.parts.map RtPart.sq).take i).sum
/-- The run's operations. -/
def len : ℕ := pf.hdrLen + (pf.parts.map RtPart.len).sum
/-- Part `i`. -/
def part (i : ℕ) : RtPart := pf.parts.getD i default

/-- **The bounds a parse needs**: a nonempty header, every squeeze run positive and at most `2^61` wide, fewer than
`2^64` squeezes, at most `2^21` operations in all. -/
structure Valid : Prop where
  hdr : 0 < pf.hdrLen
  pos : ∀ n ∈ pf.sqs, 0 < n
  le : ∀ n ∈ pf.sqs, n ≤ 2 ^ 61
  sq : pf.sqs.sum < 2 ^ 64
  len : pf.len ≤ 2 ^ 21

theorem off_le (i : ℕ) : pf.off i ≤ pf.off (i + 1) := Nat.add_le_add_left (rt_sum_take_le _ i) _

theorem off_zero : pf.off 0 = pf.hdrLen := by simp [off]

theorem off_length : pf.off pf.parts.length = pf.len := by
  unfold off len
  rw [List.take_of_length_le (by simp)]

end RtProf

/-- The profile's widths are positive. -/
theorem RtProf.Valid.wpos {pf : RtProf} (hv : pf.Valid) : ∀ k, 0 < rtW pf.sqs k := rtW_pos pf.sqs hv.pos

/-- The profile's widths are at most `2^64`. -/
theorem RtProf.Valid.wle {pf : RtProf} (hv : pf.Valid) : ∀ k, rtW pf.sqs k ≤ 2 ^ 64 :=
  rtW_le pf.sqs (fun n hn => (hv.le n hn).trans (by norm_num))

theorem rt_getD_map {β γ : Type} (f : β → γ) (l : List β) (i : ℕ) (a : β) (b : γ) (hi : i < l.length) :
    (l.map f).getD i b = f (l.getD i a) := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_getElem hi]
  rfl

theorem RtProf.off_succ (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length) :
    pf.off (i + 1) = pf.off i + (pf.part i).len := by
  unfold RtProf.off RtProf.part
  rw [rt_sum_take_succ, rt_getD_map RtPart.len pf.parts i default 0 hi]
  omega

theorem RtProf.sqAt_succ (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length) :
    pf.sqAt (i + 1) = pf.sqAt i + (pf.part i).sq := by
  unfold RtProf.sqAt RtProf.part
  rw [rt_sum_take_succ, rt_getD_map RtPart.sq pf.parts i default 0 hi]
  omega

/-- The parts' steps, part by part. -/
def rtPartsStps : List RtPart → List RtData → List Stp
  | [], _ => []
  | _ :: _, [] => []
  | p :: ps, d :: ds => rtPartStps p d ++ rtPartsStps ps ds

theorem rtPartsStps_nil_right : ∀ ps : List RtPart, rtPartsStps ps [] = []
  | [] => rfl
  | _ :: _ => rfl

/-- **The run's steps**: the header's operations as single steps, then the parts'. -/
def rtStps (pf : RtProf) (o : List Op × List RtData) : List Stp := opsStps o.1 ++ rtPartsStps pf.parts o.2

/-- The run's steps before part `i`. -/
def rtPre (pf : RtProf) (o : List Op × List RtData) (i : ℕ) : List Stp :=
  opsStps o.1 ++ rtPartsStps (pf.parts.take i) (o.2.take i)

/-- **An output of the profile's shape**: the header's operation and squeeze counts, every header operation within `Lq`
bytes, and every part's data of the profile's shape. -/
def RtGood (Lq : ℕ) (pf : RtProf) (o : List Op × List RtData) : Prop :=
  o.1.length = pf.hdrLen ∧ sqN o.1 = pf.hdrSq ∧ (∀ op ∈ o.1, op.len ≤ Lq) ∧ List.Forall₂ (RtPartOk Lq) pf.parts o.2

theorem rt_forall₂_take {β γ : Type} {R : β → γ → Prop} : ∀ (i : ℕ) {l₁ : List β} {l₂ : List γ},
    List.Forall₂ R l₁ l₂ → List.Forall₂ R (l₁.take i) (l₂.take i)
  | 0, _, _, _ => List.Forall₂.nil
  | _ + 1, _, _, .nil => List.Forall₂.nil
  | i + 1, _, _, .cons h t => List.Forall₂.cons h (rt_forall₂_take i t)

theorem rt_sum_flatMap_sqs : ∀ ps : List RtPart, (ps.flatMap RtPart.sqs).sum = (ps.map RtPart.sq).sum
  | [] => rfl
  | p :: ps => by
    rw [List.flatMap_cons, List.sum_append, List.map_cons, List.sum_cons, p.sqs_sum, rt_sum_flatMap_sqs ps]

/-- **The parts' steps on data of the profile's shape**: the squeeze runs, the length and the fit are the profile's. -/
theorem rtPartsStps_facts (Lq : ℕ) {ps : List RtPart} {ds : List RtData} (h : List.Forall₂ (RtPartOk Lq) ps ds) :
    rtSqs (rtPartsStps ps ds) = ps.flatMap RtPart.sqs
      ∧ (stpsOps (rtPartsStps ps ds)).length = (ps.map RtPart.len).sum
      ∧ ∀ op ∈ stpsOps (rtPartsStps ps ds), op.len ≤ Lq := by
  induction h with
  | nil => exact ⟨rfl, rfl, fun op hop => absurd hop List.not_mem_nil⟩
  | @cons p d ps ds hpd _ ih =>
    obtain ⟨h1, h2, h3, h4, h5, h6⟩ := hpd
    refine ⟨?_, ?_, ?_⟩
    · show rtSqs (rtPartStps p d ++ rtPartsStps ps ds) = _
      rw [rtSqs_append, rtSqs_partStps p d h2, ih.1, List.flatMap_cons]
    · show (stpsOps (rtPartStps p d ++ rtPartsStps ps ds)).length = _
      rw [stpsOps_append, List.length_append, rtPartStps_length p d h1 h3 h4 h5, ih.2.1, List.map_cons, List.sum_cons]
    · intro op hop
      have hop' : op ∈ stpsOps (rtPartStps p d) ++ stpsOps (rtPartsStps ps ds) := by
        rw [← stpsOps_append]
        exact hop
      rcases List.mem_append.mp hop' with hh | hh
      · exact h6 op hh
      · exact ih.2.2 op hh

/-- The parts' steps, split after the first `i` parts. -/
theorem rtPartsStps_split : ∀ (i : ℕ) (ps : List RtPart) (ds : List RtData),
    rtPartsStps ps ds = rtPartsStps (ps.take i) (ds.take i) ++ rtPartsStps (ps.drop i) (ds.drop i)
  | 0, ps, ds => by simp [rtPartsStps]
  | i + 1, [], ds => by simp [rtPartsStps]
  | i + 1, p :: ps, [] => by simp [rtPartsStps, rtPartsStps_nil_right]
  | i + 1, p :: ps, d :: ds => by
    simp only [List.take_succ_cons, List.drop_succ_cons, rtPartsStps, List.append_assoc]
    rw [← rtPartsStps_split i ps ds]

/-- **The run's steps on an output of the profile's shape**: the squeeze runs are the profile's, there are
`pf.len` operations, each within `Lq` bytes. -/
theorem rtStps_facts (Lq : ℕ) (pf : RtProf) (o : List Op × List RtData) (h : RtGood Lq pf o) :
    rtSqs (rtStps pf o) = pf.sqs ∧ (stpsOps (rtStps pf o)).length = pf.len
      ∧ ∀ op ∈ stpsOps (rtStps pf o), op.len ≤ Lq := by
  obtain ⟨h1, h2, h3, h4⟩ := h
  obtain ⟨f1, f2, f3⟩ := rtPartsStps_facts Lq h4
  refine ⟨?_, ?_, ?_⟩
  · unfold rtStps RtProf.sqs
    rw [rtSqs_append, rtSqs_opsStps, f1, h2]
  · unfold rtStps RtProf.len
    rw [stpsOps_append, stpsOps_opsStps, List.length_append, f2, h1]
  · intro op hop
    have hop' : op ∈ o.1 ++ stpsOps (rtPartsStps pf.parts o.2) := by
      rw [← stpsOps_opsStps o.1, ← stpsOps_append]
      exact hop
    rcases List.mem_append.mp hop' with hh | hh
    · exact h3 op hh
    · exact f3 op hh

/-- **Part `i` starts at the profile's position** (finding L27-2): on an output of the shape, the run's steps are those
before part `i` followed by the later parts', there are `off i` operations and `sqAt i` squeezes before part `i`. -/
theorem rtPre_facts (Lq : ℕ) (pf : RtProf) (o : List Op × List RtData) (h : RtGood Lq pf o) (i : ℕ) :
    rtStps pf o = rtPre pf o i ++ rtPartsStps (pf.parts.drop i) (o.2.drop i)
      ∧ (stpsOps (rtPre pf o i)).length = pf.off i ∧ stpsSq (rtPre pf o i) = pf.sqAt i := by
  obtain ⟨f1, f2, -⟩ := rtPartsStps_facts Lq (rt_forall₂_take i h.2.2.2)
  refine ⟨?_, ?_, ?_⟩
  · unfold rtStps rtPre
    rw [List.append_assoc, ← rtPartsStps_split i pf.parts o.2]
  · unfold rtPre RtProf.off
    rw [stpsOps_append, stpsOps_opsStps, List.length_append, f2, h.1, List.map_take]
  · unfold rtPre RtProf.sqAt
    rw [stpsSq_append, stpsSq_opsStps, h.2.1, ← rtSqs_sum, f1, rt_sum_flatMap_sqs, List.map_take]

/-- Part `i`'s steps head the later parts' steps. -/
theorem rtPartsStps_drop (ps : List RtPart) (ds : List RtData) (i : ℕ) (p : RtPart) (d : RtData)
    (hp : ps[i]? = some p) (hd : ds[i]? = some d) :
    rtPartsStps (ps.drop i) (ds.drop i) = rtPartStps p d ++ rtPartsStps (ps.drop (i + 1)) (ds.drop (i + 1)) := by
  obtain ⟨hi, rfl⟩ := List.getElem?_eq_some_iff.mp hp
  obtain ⟨hj, rfl⟩ := List.getElem?_eq_some_iff.mp hd
  rw [List.drop_eq_getElem_cons hi, List.drop_eq_getElem_cons hj]
  rfl

/-! ## The run's transcript and its two parses -/

section Run

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)

/-- **The run verifier's steps on an output** (`rd` reads the header's operations and the parts' data off the statement
and the receipt): the run's steps when the output has the profile's shape, else none. -/
noncomputable def rtS (o : α) : List Stp :=
  haveI := Classical.propDecidable (RtGood Lq pf (rd o))
  if RtGood Lq pf (rd o) then rtStps pf (rd o) else []

theorem rtS_good (o : α) (h : RtGood Lq pf (rd o)) : rtS Lq pf rd o = rtStps pf (rd o) := by
  unfold rtS
  exact ite_eq_left h

theorem rtS_bad (o : α) (h : ¬ RtGood Lq pf (rd o)) : rtS Lq pf rd o = [] := by
  unfold rtS
  exact ite_eq_right h

/-- **THE RUN'S ONE TRANSCRIPT**: the executable trace of the run verifier's operations, on the keyed transcript of
the profile's domain, for every oracle and every output. -/
noncomputable def rtTr (G : QB Lq → Dig) (o : α) : List (TItem × Dig) :=
  opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtS Lq pf rd o))

/-- The run's steps parse under the profile's wide parse, on EVERY output. -/
theorem rtS_ok (hv : pf.Valid) (o : α) : StpOK (rtW pf.sqs) 0 (rtS Lq pf rd o) := by
  by_cases h : RtGood Lq pf (rd o)
  · rw [rtS_good Lq pf rd o h]
    exact rt_stpOK pf.sqs _ (rtStps_facts Lq pf (rd o) h).1 hv.pos hv.sq
  · rw [rtS_bad Lq pf rd o h]
    trivial

/-- Every operation of the run fits `Lq` bytes, on EVERY output. -/
theorem rtS_fit (o : α) : ∀ op ∈ stpsOps (rtS Lq pf rd o), op.len ≤ Lq := by
  by_cases h : RtGood Lq pf (rd o)
  · rw [rtS_good Lq pf rd o h]
    exact (rtStps_facts Lq pf (rd o) h).2.2
  · rw [rtS_bad Lq pf rd o h]
    exact fun op hop => absurd hop List.not_mem_nil

/-- **At most `2^21` operations**, on EVERY output. -/
theorem rtS_len (hv : pf.Valid) (o : α) : (stpsOps (rtS Lq pf rd o)).length ≤ 2 ^ 21 := by
  by_cases h : RtGood Lq pf (rd o)
  · rw [rtS_good Lq pf rd o h, (rtStps_facts Lq pf (rd o) h).2.1]
    exact hv.len
  · rw [rtS_bad Lq pf rd o h]
    exact Nat.zero_le _

/-- The wide parse's heads expand to the run's operations. -/
theorem rt_heads_len (hL64 : Lq < 2 ^ 64) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64)
    (ss : List Stp) (hok : StpOK W 0 ss) (hfit : ∀ op ∈ stpsOps ss, op.len ≤ Lq) :
    ((liftItems Lq (stpHeads 0 ss)).flatMap (stepsB Lq W hW hW64).items).length = (stpsOps ss).length := by
  have hheads : ∀ it ∈ stpHeads 0 ss, it.Ok ∧ it.len ≤ Lq :=
    fun it hit => opItems_fit Lq hL64 0 _ hfit it (stpHeads_mem W 0 ss hok it hit)
  have e := flatMap_stpHeads Lq W hW hW64 0 ss hok hheads
  have hl := congrArg List.length e
  rw [List.length_map, opItems_length] at hl
  exact hl

theorem rtS_heads_len (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (hW : ∀ k, 0 < rtW pf.sqs k)
    (hW64 : ∀ k, rtW pf.sqs k ≤ 2 ^ 64) (o : α) :
    ((liftItems Lq (stpHeads 0 (rtS Lq pf rd o))).flatMap (stepsB Lq (rtW pf.sqs) hW hW64).items).length ≤ 2 ^ 21 := by
  rw [rt_heads_len Lq hL64 _ hW hW64 _ (rtS_ok Lq pf rd hv o) (rtS_fit Lq pf rd o)]
  exact rtS_len Lq pf rd hv o

/-- **The run header's heads are single items** (`hhd`): the first `hdrLen − 1` heads expand to as many items. -/
theorem rtS_heads_hd (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (hW : ∀ k, 0 < rtW pf.sqs k)
    (hW64 : ∀ k, rtW pf.sqs k ≤ 2 ^ 64) (o : α) :
    (((liftItems Lq (stpHeads 0 (rtS Lq pf rd o))).take (pf.hdrLen - 1)).flatMap
      (stepsB Lq (rtW pf.sqs) hW hW64).items).length ≤ pf.hdrLen - 1 := by
  have hok := rtS_ok Lq pf rd hv o
  have hfit := rtS_fit Lq pf rd o
  by_cases h : RtGood Lq pf (rd o)
  · rw [rtS_good Lq pf rd o h] at hok hfit ⊢
    have hheads : ∀ it ∈ stpHeads 0 (rtStps pf (rd o)), it.Ok ∧ it.len ≤ Lq :=
      fun it hit => opItems_fit Lq hL64 0 _ hfit it (stpHeads_mem _ 0 _ hok it hit)
    exact (heads_single Lq (rtW pf.sqs) hW hW64 (rd o).1 (rtPartsStps pf.parts (rd o).2) 0 (pf.hdrLen - 1)
      (by rw [h.1]; omega) hok hheads).le
  · rw [rtS_bad Lq pf rd o h]
    simp [stpHeads, liftItems]

/-- **The wide parse of the run's transcript** (L20 / L22's: `M`'s and the openings' challenge vectors are steps of
their widths), as L27's `RunChain`: the code's chain encoding, the steps `stepsB` at the profile's widths
(`StepsOK`, `StepCont`), the heads of the run's steps, at most `2^21` items, a header of `hdrLen − 1` single items. -/
noncomputable def rtRC2 (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) : RunChain Lq α where
  W := rtW pf.sqs
  hW := hv.wpos
  C := chainEncB key domain hs Lq hL
  S := stepsB Lq (rtW pf.sqs) hv.wpos hv.wle
  hS := stepsB_ok Lq _ hv.wpos hv.wle
  hcont := stepsB_cont _ hv.wpos hv.wle
  heads := fun o => liftItems Lq (stpHeads 0 (rtS Lq pf rd o))
  ℓ := 2 ^ 21
  hℓ := fun o => rtS_heads_len Lq pf rd hL64 hv hv.wpos hv.wle o
  s := pf.hdrLen - 1
  hhd := fun o => rtS_heads_hd Lq pf rd hL64 hv hv.wpos hv.wle o

/-- **The single-step parse of the run's transcript** (L21's: every squeeze a step of its own, `W1`), as L27's
`RunChain`. -/
noncomputable def rtRC1 : RunChain Lq α where
  W := W1
  hW := fun _ => Nat.one_pos
  C := chainEncB key domain hs Lq hL
  S := stepsOne (ItB Lq)
  hS := stepsOne_ok _
  hcont := rt_stepsOne_cont Lq
  heads := fun o => (liftItems Lq (opItems 0 (stpsOps (rtS Lq pf rd o)))).take (2 ^ 21)
  ℓ := 2 ^ 21
  hℓ := fun o => by
    rw [flatMap_stepsOne]
    exact List.length_take_le _ _
  s := pf.hdrLen - 1
  hhd := fun o => by
    rw [flatMap_stepsOne]
    exact List.length_take_le _ _

/-- **The wide parse's chain IS the run's transcript** (`KindRun.htr`), for every oracle and output. -/
theorem rtRC2_chain (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (G : QB Lq → Dig) (o : α) :
    (rtRC2 key domain hs Lq hL pf rd hL64 hv).chain G o = rtTr key domain Lq pf rd G o :=
  cChain_stps Lq (rtW pf.sqs) hv.wpos hv.wle key domain hs hL hL64 G _ (rtS_ok Lq pf rd hv o) (rtS_fit Lq pf rd o)

/-- **The single-step parse's chain IS the run's transcript** (`KindRun.htr`), for every oracle and output. -/
theorem rtRC1_chain (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (G : QB Lq → Dig) (o : α) :
    (rtRC1 key domain hs Lq hL pf rd).chain G o = rtTr key domain Lq pf rd G o :=
  cChain_trace key domain hs hL hL64 _ G (rtS_fit Lq pf rd o) (2 ^ 21) (rtS_len Lq pf rd hv o)

theorem rtRC1_ℓ : (rtRC1 key domain hs Lq hL pf rd).ℓ = 2 ^ 21 := rfl

theorem rtRC2_ℓ (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) : (rtRC2 key domain hs Lq hL pf rd hL64 hv).ℓ = 2 ^ 21 := rfl

/-! ## The transcript at a step boundary -/

/-- The run's transcript has the profile's length on an output of the shape. -/
theorem rtTr_length (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) :
    (rtTr key domain Lq pf rd G o).length = pf.len := by
  unfold rtTr
  rw [Block.opTrace_length, rtS_good Lq pf rd o h, (rtStps_facts Lq pf (rd o) h).2.1]

/-- **The run's transcript cut at a step boundary.** On an output of the profile's shape whose steps are `a ++ b`:
the transcript's first `|a|` entries are the trace of `a`; what follows is the trace of `b` on the transcript after
`a`; the cut is at a step's end under the wide parse; the transcript there has squeezed `stpsSq a` times; and `b`
parses from that counter (so the widths at the next runs are `b`'s). -/
theorem rtTr_split (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (a b : List Stp)
    (hab : rtStps pf (rd o) = a ++ b) :
    (rtTr key domain Lq pf rd G o).take (stpsOps a).length
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps a)
      ∧ (rtTr key domain Lq pf rd G o).drop (stpsOps a).length
        = opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps a)) (stpsOps b)
      ∧ tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (stpsOps a).length) = some 0
      ∧ (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps a)).counter = UInt64.ofNat (stpsSq a)
      ∧ StpOK (rtW pf.sqs) (UInt64.ofNat (stpsSq a)) b := by
  have hok := rtS_ok Lq pf rd hv o
  rw [rtS_good Lq pf rd o h, hab] at hok
  unfold rtTr
  rw [rtS_good Lq pf rd o h, hab]
  refine ⟨rt_trace_take _ _ a b, rt_trace_drop _ _ a b, rt_tRem_take _ _ _ a b hok, ?_, ?_⟩
  · have hc := ctr_runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps a) 0 rfl
    rw [Nat.zero_add, sqN_stpsOps] at hc
    exact hc
  · have hr := rt_stpOK_right _ 0 a b hok
    rw [u64_zero_add] at hr
    exact hr

/-- **The run's transcript cut inside part `i`**, after the part's steps `u` (`rtPartStps p d = u ++ v`): the cut is
at the fixed position `off i + |u|`, with `sqAt i + stpsSq u` squeezes before it. With `u = []` this is the part's
start; with `u` the single phase, `M`'s window; and so on through the openings' windows. -/
theorem rtTr_part (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (i : ℕ) (p : RtPart)
    (d : RtData) (hp : pf.parts[i]? = some p) (hd : (rd o).2[i]? = some d) (u v : List Stp)
    (huv : rtPartStps p d = u ++ v) :
    (rtTr key domain Lq pf rd G o).take (pf.off i + (stpsOps u).length)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre pf (rd o) i ++ u))
      ∧ (rtTr key domain Lq pf rd G o).drop (pf.off i + (stpsOps u).length)
        = opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre pf (rd o) i ++ u)))
            (stpsOps (v ++ rtPartsStps (pf.parts.drop (i + 1)) ((rd o).2.drop (i + 1))))
      ∧ tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + (stpsOps u).length)) = some 0
      ∧ (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre pf (rd o) i ++ u))).counter
        = UInt64.ofNat (pf.sqAt i + stpsSq u)
      ∧ StpOK (rtW pf.sqs) (UInt64.ofNat (pf.sqAt i + stpsSq u))
          (v ++ rtPartsStps (pf.parts.drop (i + 1)) ((rd o).2.drop (i + 1))) := by
  obtain ⟨e1, e2, e3⟩ := rtPre_facts Lq pf (rd o) h i
  have hab : rtStps pf (rd o) = (rtPre pf (rd o) i ++ u)
      ++ (v ++ rtPartsStps (pf.parts.drop (i + 1)) ((rd o).2.drop (i + 1))) := by
    rw [e1, rtPartsStps_drop pf.parts (rd o).2 i p d hp hd, huv]
    simp only [List.append_assoc]
  have hlen : (stpsOps (rtPre pf (rd o) i ++ u)).length = pf.off i + (stpsOps u).length := by
    rw [stpsOps_append, List.length_append, e2]
  have hsq : stpsSq (rtPre pf (rd o) i ++ u) = pf.sqAt i + stpsSq u := by
    rw [stpsSq_append, e3]
  have hm := rtTr_split key domain Lq pf rd hv G o h _ _ hab
  rw [hlen, hsq] at hm
  exact hm

end Run

end ZK60.ProtocolClassify
