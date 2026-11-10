/-
D63 lane L31 (2026-11-09), part 6: **the slot polynomial's evaluation interface with the run's facts, and the masked
slot polynomial `Poly + c·mask` over the extracted data** (L23 §5 item 2; finding L31-1).

**Finding L31-1.** L16's `SlotEval` (the premise `hEval` of every block theorem from `block_knowledge` to L28's
`block_knowledge_open_*`) asks its identity `f(ρ) = poly(vals) + c·ms[(k, eval_weights(rhoFull, d))]` for EVERY list
`rhoFull` whose first `n` entries are the slot's `ρ`, of any length. The polynomial `f` only sees the slot's `n + e`
challenges, while the right side reads all of `rhoFull` (the selector `∏(1 − e_i)`, the mask coefficients, the weights
`eval_weights`). So no polynomial meets `SlotEval` at a real block. What the verifier's acceptance gives is one
`rhoFull`: the sumcheck's challenges, exactly `n + e` canonical words. `SlotEvalN` below is `SlotEval` with those
facts as premises, and `blockSlots_terminalN` is L16's `blockSlots_terminal` for it. Nothing here changes an existing
file; the change L16's file needs is in the lane's doc.

* `SlotEvalN`, `SlotEval.toN`: the evaluation interface with the run's facts (the slot is one of the shape's, `rhoFull`
  has `n + e` canonical entries, the slot proof is canonical); L16's form implies it;
* **`blockSlots_terminalN`**: `blockSlots` accepts, the claims and `M`'s functionals are true, and `SlotEvalN` holds ⇒
  every slot's terminal check `fin = f(ρ)` (L9's `BlockWin` premise);
* `seenOf_c`; `maskedF`: **the masked slot polynomial** `Poly + c·mask`, `c` the slot's CFS challenge as the trace
  shows it, `mask` the CFS mask polynomial of the slot's extracted mask row (`SlotPolyInstMask.lean`);
* **`maskedF_indDeg`**: its individual degree is the slot's (`hdeg`), given `Poly`'s;
* **`maskedF_slotEvalN`**: it meets `SlotEvalN` for ANY `M` semantics that is linear on the rows (`MLin`, proved for
  `msXof`), given that `Poly` meets the table side alone (`SlotEvalN` with the zero `M` semantics):
  `Poly(ρ) = poly(vals)`;
* **`maskedF_cubeSum`**, `claimed_unmasked`: its cube sum is `Σ Poly + c·⟨row, sum_weights⟩`, the form
  `unmask_slots` takes (`hcl`);
* `hpolyC_of_ir`: `hpolyC` for any `define` whose polynomials are IR evaluations.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotPolyInstMask

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

section Eval

variable {K : Type} [Field K] [Algebra GF K]

/-- **The evaluation interface of a slot polynomial, with the run's facts** (finding L31-1). As L16's `SlotEval`, at
an accepting slot `k` of the shape whose `rhoFull` is the sumcheck's `n + e` canonical challenges and whose slot proof
is canonical: `f` at the slot's point is `poly(vals) + c·(the slot's M functional on the data)`. -/
def SlotEvalN (U : K) (P : BlockParams) (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) : Prop :=
  ∀ (core : Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec) (sp : SlotProof) (df : SlotDef)
    (vals rhoFull : List Fp2), core.slots[k]? = some sp → rs[k]? = some r → k < P.geom.slots.length →
    P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df →
    rhoFull.length = (slotShape P k).1 + (slotShape P k).2.1 → (∀ x ∈ rhoFull, x.Canon) → SlotCanon sp →
    r.rho = rhoFull.take (slotShape P k).1 → r.es = rhoFull.drop (slotShape P k).1 →
    tabVals (oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals →
    (∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U) →
    f k (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)
      = (df.poly vals).toK U + r.c.toK U * ms [(k, Cfs.evalWeights rhoFull (slotShape P k).2.2)]

/-- L16's form implies the form with the run's facts. -/
theorem SlotEval.toN {U : K} {P : BlockParams} {cs : Cm → ZClaim → K} {ms : List (ℕ × List Fp2) → K}
    {f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K} (h : SlotEval U P cs ms f) :
    SlotEvalN U P cs ms f :=
  fun core bga rs k r sp df vals rhoFull hsp hr _ hdf _ _ _ hrho hes hvals htrue =>
    h core bga rs k r sp df vals rhoFull hsp hr hdf hrho hes hvals htrue

/-- **What L16's `SlotEval` forces** (finding L31-1): its right side cannot depend on anything the polynomial does not
see. Two readings of slot `k` with the same trace data and the same first `n + e` challenges, each meeting
`SlotEval`'s premises, have the same right side, whatever their `rhoFull` hold beyond the slot's point. (At a real
block the right side does depend on it: `eval_weights` multiplies ALL of `rhoFull`.) -/
theorem slotEval_rhs_indep {U : K} {P : BlockParams} {cs : Cm → ZClaim → K} {ms : List (ℕ × List Fp2) → K}
    {f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K} (h : SlotEval U P cs ms f)
    (core core' : Core) (bga : Fp2 × Fp2 × Fp2) (rs rs' : List SlotRec) (k : ℕ) (r r' : SlotRec) (sp sp' : SlotProof)
    (df df' : SlotDef) (vals vals' rhoFull rhoFull' : List Fp2)
    (hsp : core.slots[k]? = some sp) (hr : rs[k]? = some r)
    (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df)
    (hrho : r.rho = rhoFull.take (slotShape P k).1) (hes : r.es = rhoFull.drop (slotShape P k).1)
    (hvals : tabVals (oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals)
    (htrue : ∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U)
    (hsp' : core'.slots[k]? = some sp') (hr' : rs'[k]? = some r')
    (hdf' : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs'.take k)) r'.draws = .ok df')
    (hrho' : r'.rho = rhoFull'.take (slotShape P k).1) (hes' : r'.es = rhoFull'.drop (slotShape P k).1)
    (hvals' : tabVals (oneMinusProd r'.es) r'.rho sp'.terms df'.tabs 0 = .ok vals')
    (htrue' : ∀ q ∈ slotClaimList P r'.rho r'.es sp'.terms df'.tabs 0, cs q.1 q.2 = q.2.value.toK U)
    (hseen : seenOf bga rs k = seenOf bga rs' k)
    (hx : ∀ i : Fin ((slotShape P k).1 + (slotShape P k).2.1),
      ((r.rho ++ r.es).getD i Fp2.zero).toK U = ((r'.rho ++ r'.es).getD i Fp2.zero).toK U) :
    (df.poly vals).toK U + r.c.toK U * ms [(k, Cfs.evalWeights rhoFull (slotShape P k).2.2)]
      = (df'.poly vals').toK U + r'.c.toK U * ms [(k, Cfs.evalWeights rhoFull' (slotShape P k).2.2)] := by
  rw [← h core bga rs k r sp df vals rhoFull hsp hr hdf hrho hes hvals htrue,
    ← h core' bga rs' k r' sp' df' vals' rhoFull' hsp' hr' hdf' hrho' hes' hvals' htrue', hseen]
  exact congrArg (f k (seenOf bga rs' k)) (funext hx)

/-- **The terminal premise is discharged by the claims' and `M`'s truth, for a slot polynomial that meets the
interface with the run's facts** (L16's `blockSlots_terminal` for `SlotEvalN`): on an accepting slot phase of a
canonical core with the shape's slots and degrees at least `1`, every slot's terminal check `fin = f(ρ)` holds. -/
theorem blockSlots_terminalN (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (P : BlockParams) (core : Core)
    (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hacc : blockSlots H P core t = .ok (bga, rs, acc, t')) (hcan : CoreCanon core)
    (hsh : core.slots.length = P.geom.slots.length)
    (hd : ∀ i, i < P.geom.slots.length → 1 ≤ (slotShape P i).2.2)
    (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hcl : ClaimsTrue U cs acc.claims) (hm : MTrue U ms acc.fs)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hfin : ∀ r ∈ rs, r.fin.Canon)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (hEval : SlotEvalN U P cs ms f) :
    ∀ k r, rs[k]? = some r →
      r.fin.toK U = f k (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U) := by
  intro k r hr
  rw [blockSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    subst hbga
    obtain ⟨-, -, rs', hrs', hlen, hall⟩ := slotsLoop_terminal H P _ _ _ core.slots [] 0 {} _ rs acc t' hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    obtain ⟨rs2, hrs2, -, hall2⟩ := slotsLoop_ok H P _ _ _ core.slots [] 0 {} _ rs acc t'
      (fun i hi => by
        rw [Nat.zero_add]
        exact hd i (by rw [← hsh]; exact hi)) hloop
    simp only [List.nil_append] at hrs2
    subst hrs2
    have hk : k < core.slots.length := by
      rw [← hlen]
      exact (List.getElem?_eq_some_iff.mp hr).1
    obtain ⟨sp, hsp⟩ : ∃ sp, core.slots[k]? = some sp := ⟨_, List.getElem?_eq_getElem hk⟩
    obtain ⟨df, vals, rhoFull, hdf, hc0, hcc, -, hrho, hes, hvals, hev, hclk⟩ := hall k sp r hsp hr
    obtain ⟨-, -, -, hsv⟩ := hall2 k sp r hsp hr
    simp only [Nat.zero_add, List.nil_append] at hdf hrho hes hev hsv
    have hkP : k < P.geom.slots.length := by
      rw [← hsh]
      exact hk
    unfold scVerify at hsv
    split at hsv
    · simp at hsv
    · rename_i hlen'
      obtain ⟨-, hrs3, -⟩ := (scLoop_ok_iff H _ (hd k hkP) sp.rounds 0 r.claimed [] _ r.fin (r.rho ++ r.es)).mp hsv
      rw [List.nil_append] at hrs3
      have hrf : rhoFull = r.rho ++ r.es := by
        rw [hrho, hes, List.take_append_drop]
      have hrl : rhoFull.length = (slotShape P k).1 + (slotShape P k).2.1 := by
        rw [hrf, hrs3, scChal_length]
        exact not_not.mp hlen'
      have hrc : ∀ x ∈ rhoFull, x.Canon := by
        rw [hrf, hrs3]
        exact scChal_canon H _ _
      have htrue : ∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U :=
        fun q hq => hcl q.1 q.2 (hclk q hq)
      have hmk := hm _ hev
      simp only at hmk
      rw [hEval core _ rs k r sp df vals rhoFull hsp hr hkP hdf hrl hrc (hcan.1 sp (List.mem_of_getElem? hsp)) hrho
        hes hvals htrue, hmk]
      exact fin_identity U hU r.fin (df.poly vals) r.c (hfin r (List.mem_of_getElem? hr)) (hpolyC k _ _ df hdf vals)
        hcc hc0
  · cases hacc

/-- The slot's CFS challenge, as the trace before its rounds shows it. -/
theorem seenOf_c (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) :
    ((seenOf bga rs k).2.getD k ([], Fp2.zero, [])).2.1 = r.c := by
  show (((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
    ([], Fp2.zero, [])).2.1 = r.c
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt (Nat.lt_succ_self k), hr]
  rfl

/-- **The masked slot polynomial over the extracted data**: `Poly + c·mask`, with `c` the slot's CFS challenge (read
off what the trace shows) and `mask` the CFS mask polynomial of the slot's extracted mask row `R k`. -/
def maskedF (U : K) (R : ℕ → ℕ → K) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K :=
  fun k sn x => Poly k sn x + ((sn.2.getD k ([], Fp2.zero, [])).2.1).toK U
    * Link.maskPoly R k ((slotShape P k).1 + (slotShape P k).2.1) (slotShape P k).2.2 x

/-- **`hdeg` for the masked slot polynomial**, from the table side's degree. -/
theorem maskedF_indDeg (U : K) (R : ℕ → ℕ → K) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (k : ℕ) (sn : Seen)
    (hd : 1 ≤ (slotShape P k).2.2) (hP : IndDegLE (slotShape P k).2.2 (Poly k sn)) :
    IndDegLE (slotShape P k).2.2 (maskedF U R P Poly k sn) :=
  hP.add_smul (Link.maskPoly_indDeg R k _ _ hd) _

/-- **`hdeg` at every slot index**: past the shape's slots there are no variables. -/
theorem maskedF_indDeg_all (U : K) (R : ℕ → ℕ → K) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (hP : ∀ k sn, IndDegLE (slotShape P k).2.2 (Poly k sn)) (k : ℕ) (sn : Seen) :
    IndDegLE (slotShape P k).2.2 (maskedF U R P Poly k sn) := by
  by_cases hk : k < P.geom.slots.length
  · exact maskedF_indDeg U R P Poly k sn (hd k hk) (hP k sn)
  · intro i
    have h0 : slotShape P k = (0, 0, 0) := by
      unfold slotShape
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none_iff.mpr (not_lt.mp hk), Option.getD_none]
    have hi : (i : ℕ) < (slotShape P k).1 + (slotShape P k).2.1 := i.isLt
    have e : (slotShape P k).1 + (slotShape P k).2.1 = 0 := by simp [h0]
    exfalso
    omega

/-- **The masked slot polynomial meets the evaluation interface** (with the run's facts), for any `M` semantics
linear on the rows `R` (`MLin`; for `msXof` it is `Link.msXof_mlin`) and any table side `Poly` that meets the
interface alone (`SlotEvalN` with the zero `M` semantics: `Poly(ρ) = poly(vals)` at an accepting slot whose claims
are true). Every slot has at least one variable and its `(n + e)·d + 2` mask coefficients fit the row. -/
theorem maskedF_slotEvalN (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (P : BlockParams) (cs : Cm → ZClaim → K)
    (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) (hlin : MLin U ms R Wd)
    (hN : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hPoly : SlotEvalN U P cs (fun _ => 0) Poly) : SlotEvalN U P cs ms (maskedF U R P Poly) := by
  intro core bga rs k r sp df vals rhoFull hsp hr hk hdf hrl hrc hsc hrho hes hvals htrue
  have hP := hPoly core bga rs k r sp df vals rhoFull hsp hr hk hdf hrl hrc hsc hrho hes hvals htrue
  simp only [mul_zero, add_zero] at hP
  have hrf : r.rho ++ r.es = rhoFull := by
    rw [hrho, hes, List.take_append_drop]
  obtain ⟨hN0, hNW⟩ := hN k hk
  have hl := hlin [(k, Cfs.evalWeights rhoFull (slotShape P k).2.2)]
  have hmask : ms [(k, Cfs.evalWeights rhoFull (slotShape P k).2.2)]
      = Link.maskPoly R k ((slotShape P k).1 + (slotShape P k).2.1) (slotShape P k).2.2
          (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U) := by
    rw [hl]
    show mdot U R Wd (k, Cfs.evalWeights rhoFull (slotShape P k).2.2) + 0 = _
    rw [add_zero, hrf]
    exact Link.maskPoly_point U hU hbij R Wd k _ _ hN0 rhoFull hrl hNW
  show Poly k (seenOf bga rs k) _ + (((seenOf bga rs k).2.getD k ([], Fp2.zero, [])).2.1).toK U
    * Link.maskPoly R k _ _ _ = _
  rw [hP, seenOf_c bga rs k r hr, hmask]

/-- **The masked slot polynomial's cube sum**: `Σ Poly + c·⟨row, sum_weights⟩` (`1 ≤ n + e < 64`). -/
theorem maskedF_cubeSum (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd : ℕ) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (k : ℕ) (sn : Seen)
    (hN0 : 0 < (slotShape P k).1 + (slotShape P k).2.1) (hN64 : (slotShape P k).1 + (slotShape P k).2.1 < 64)
    (hNW : ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd) :
    cubeSum (maskedF U R P Poly k sn)
      = cubeSum (Poly k sn) + ((sn.2.getD k ([], Fp2.zero, [])).2.1).toK U * mdot U R Wd (k, swk P k) := by
  rw [show swk P k = Cfs.sumWeights ((slotShape P k).1 + (slotShape P k).2.1) (slotShape P k).2.2 from rfl,
    Link.maskPoly_cubeSum U hU hbij R Wd k _ _ hN0 hN64 hNW]
  exact cubeSum_add_smul _ _ _

/-- **A true claimed sum, unmasked**: at a verified slot whose claimed sum is the masked slot polynomial's cube sum,
it is `Σ Poly + c·⟨row, sum_weights⟩` (the premise `hcl` of `unmask_slots`, with `Sp k = Σ Poly`). -/
theorem claimed_unmasked (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (R : ℕ → ℕ → K) (Wd : ℕ) (P : BlockParams)
    (Poly : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r)
    (hN0 : 0 < (slotShape P k).1 + (slotShape P k).2.1) (hN64 : (slotShape P k).1 + (slotShape P k).2.1 < 64)
    (hNW : ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ Wd)
    (hcl : r.claimed.toK U = cubeSum (maskedF U R P Poly k (seenOf bga rs k))) :
    r.claimed.toK U = cubeSum (Poly k (seenOf bga rs k)) + r.c.toK U * mdot U R Wd (k, swk P k) := by
  rw [hcl, maskedF_cubeSum U hU hbij R Wd P Poly k (seenOf bga rs k) hN0 hN64 hNW, seenOf_c bga rs k r hr]

end Eval

/-- **`hpolyC` for an IR-defined `define`** (L16-4): when every definition's polynomial is the word evaluation of
some slot IR, its values are canonical words. -/
theorem hpolyC_of_ir (P : BlockParams)
    (hir : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∃ ir : Slot.Ir Fp2, df.poly = Slot.irEvalW ir) :
    ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon := by
  intro k hist dr df h vs
  obtain ⟨ir, e⟩ := hir k hist dr df h
  rw [e]
  exact Slot.canon_irEvalW ir vs

end ZK60.Exec.Block
