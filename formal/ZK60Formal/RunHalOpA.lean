/-
D63 lane L43 (2026-11-10), part 6: **`hal_opA` given no `opB` doomed** (L39 §5 item 4: L20's `opening_split`).

The third ordered cover premise: on an accepted run, if no opening's second half (`opB`) entered its window doomed,
every opening's first half (`opA`) is alive at the end. L20's `opening_split` gives, for one opening, "`opA` alive at the
end, or `opB`'s header state fails"; `opB`'s header state failing at a window that is a step's end inside the chain IS
`opB` entering doomed. So the premise needs only the LAYOUT of the run's transcript: each opening's two windows are step
ends of the wide parse, inside the transcript. The layout holds on every output of the profile's shape (`RtGood`), which
every accepted output is (`RtRun.accept`); no part's verifier semantics is used, so this holds for EVERY part (stage IN-C,
the blocks, stage OUT-C) and every kinds data `D`:

* `rh_forall₂_get`, `rh_partI`: the profile's part `i` and the output's data at part `i`;
* **`rh_cut`**: the run's transcript at any step boundary inside a part is a step's end and inside the transcript;
* **`rh_win`**: so at all six windows of a part's three openings (`rtOps`);
* **`rh_KA_al`**: `opA`'s kind is alive at the end when `opB`'s kind has no doomed entrant and the windows are step ends;
* **`rh_hal_opA`**: `hal_opA`'s conclusion `(rtKA … D hD).Al n lg τ` on the run's transcript of any output of the
  profile's shape with no doomed `opB` entrant (for `n ≥` the number of parts), for EVERY `D`.

D63 lane L48 (2026-11-10), edited in place under its brief's exception: `rh_KA_al` splits each opening at its own
width (`encGL`, finding L45-2).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunKindsData

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

theorem rh_forall₂_get {β γ : Type} {R : β → γ → Prop} : ∀ {l₁ : List β} {l₂ : List γ},
    List.Forall₂ R l₁ l₂ → ∀ (i : ℕ) (hi : i < l₁.length), ∃ b, l₂[i]? = some b ∧ R (l₁[i]'hi) b
  | _, _, .nil, _, hi => absurd hi (Nat.not_lt_zero _)
  | _, _, .cons (b := b) hab _, 0, _ => ⟨b, rfl, hab⟩
  | _, _, .cons _ t, i + 1, hi => rh_forall₂_get t i (by simpa using hi)

theorem rh_partI (pf : RtProf) (i : ℕ) (hi : i < pf.parts.length) :
    pf.parts[i]? = some (pf.part i) ∧ pf.part i = pf.parts[i] := by
  have e : pf.part i = pf.parts[i] := by
    unfold RtProf.part
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi]
    rfl
  exact ⟨by rw [e]; exact List.getElem?_eq_getElem hi, e⟩

section Win

variable (key : Option Dig) (domain : List UInt8) (Lq : ℕ) {α : Type} (pf : RtProf)
  (rd : α → List Op × List RtData)

/-- **A step boundary inside a part is a step's end inside the run's transcript**: for a split `u ++ v` of part `i`'s
steps with `|ops u| = n`, the transcript cut at `off i + n` is a step's end of the wide parse, and `off i + n` is at most
the transcript's length. -/
theorem rh_cut (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (i : ℕ) (p : RtPart) (d : RtData)
    (hp : pf.parts[i]? = some p) (hd : (rd o).2[i]? = some d) (u v : List Stp) (huv : rtPartStps p d = u ++ v)
    (n : ℕ) (hn : (stpsOps u).length = n) :
    tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take (pf.off i + n)) = some 0
      ∧ pf.off i + n ≤ (rtTr key domain Lq pf rd G o).length := by
  obtain ⟨tk, -, trem, -, -⟩ := rtTr_part key domain Lq pf rd hv G o h i p d hp hd u v huv
  rw [hn] at tk trem
  refine ⟨trem, ?_⟩
  have hl := congrArg List.length tk
  rw [List.length_take, Block.opTrace_length, stpsOps_append, List.length_append,
    (rtPre_facts Lq pf (rd o) h i).2.1, hn] at hl
  omega

/-- **The six windows of a part's three openings are step ends inside the run's transcript** on every output of the
profile's shape. -/
theorem rh_win {F : Type} (hv : pf.Valid) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o)) (D : RtKData F Lq)
    (i : ℕ) (hi : i < pf.parts.length) :
    ∀ x ∈ rtOps pf D i, tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take x.2.1) = some 0
      ∧ x.2.2 ≤ (rtTr key domain Lq pf rd G o).length
      ∧ tRem (rtW pf.sqs) ((rtTr key domain Lq pf rd G o).take x.2.2) = some 0 := by
  obtain ⟨hp, -⟩ := rh_partI pf i hi
  obtain ⟨d, hd, hpd⟩ := rh_forall₂_get h.2.2.2 i hi
  rw [← (rh_partI pf i hi).2] at hpd
  set p := pf.part i with hpDef
  obtain ⟨h1, -, h3, h4, h5, -⟩ := hpd
  have l0 : (stpsOps (opsStps d.pre ++ mStps p.S d.mo)).length = p.oA := by
    rw [stpsOps_append, List.length_append, stpsOps_opsStps, stpsOps_mStps_length, h1]
    rfl
  have lsq : ∀ (w : ℕ) (vs : List (List Fp2)), (stpsOps (Stp.sq w :: vecStps vs)).length = w + vs.length := by
    intro w vs
    rw [stpsOps_cons, List.length_append, stpsOps_vecStps_length]
    simp [Stp.ops]
  have lpcs : ∀ (w m : ℕ) (oz : Block.OpeningZk), (stpsOps (pcsStps w m oz)).length = w + oz.groupVecs.length + 1 + m :=
    stpsOps_pcsStps_length
  -- A
  have cA := rh_cut key domain Lq pf rd hv G o h i p d hp hd (opsStps d.pre ++ mStps p.S d.mo)
    (pcsStps p.wA p.mA d.aO ++ (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO))
    (by simp only [rtPartStps, List.append_assoc]) p.oA l0
  have cBA := rh_cut key domain Lq pf rd hv G o h i p d hp hd
    ((opsStps d.pre ++ mStps p.S d.mo) ++ (Stp.sq p.wA :: vecStps d.aO.groupVecs))
    (Stp.ab Block.labPcsProx (d.aO.proxVec.flatMap Fp2.toBytes) :: Stp.sq p.mA
      :: (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO))
    (by simp [rtPartStps, pcsStps, pcsPre, List.append_assoc]) p.oBA
    (by rw [stpsOps_append, List.length_append, l0, lsq, h3]; rfl)
  -- H
  have l1 : (stpsOps ((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO)).length = p.oH := by
    rw [stpsOps_append, List.length_append, l0, lpcs, h3]
    simp only [RtPart.oH, RtPart.oBA]
    omega
  have cH := rh_cut key domain Lq pf rd hv G o h i p d hp hd
    ((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO) (pcsStps p.wH p.mH d.hO ++ pcsStps p.wX p.mX d.xO)
    (by simp only [rtPartStps, List.append_assoc]) p.oH l1
  have cBH := rh_cut key domain Lq pf rd hv G o h i p d hp hd
    (((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO) ++ (Stp.sq p.wH :: vecStps d.hO.groupVecs))
    (Stp.ab Block.labPcsProx (d.hO.proxVec.flatMap Fp2.toBytes) :: Stp.sq p.mH :: pcsStps p.wX p.mX d.xO)
    (by simp [rtPartStps, pcsStps, pcsPre, List.append_assoc]) p.oBH
    (by rw [stpsOps_append, List.length_append, l1, lsq, h4]; rfl)
  -- X
  have l2 : (stpsOps (((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO)
      ++ pcsStps p.wH p.mH d.hO)).length = p.oX := by
    rw [stpsOps_append, List.length_append, l1, lpcs, h4]
    simp only [RtPart.oX, RtPart.oBH]
    omega
  have cX := rh_cut key domain Lq pf rd hv G o h i p d hp hd
    (((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO) ++ pcsStps p.wH p.mH d.hO)
    (pcsStps p.wX p.mX d.xO) (by simp only [rtPartStps, List.append_assoc]) p.oX l2
  have cBX := rh_cut key domain Lq pf rd hv G o h i p d hp hd
    ((((opsStps d.pre ++ mStps p.S d.mo) ++ pcsStps p.wA p.mA d.aO) ++ pcsStps p.wH p.mH d.hO)
      ++ (Stp.sq p.wX :: vecStps d.xO.groupVecs))
    [Stp.ab Block.labPcsProx (d.xO.proxVec.flatMap Fp2.toBytes), Stp.sq p.mX]
    (by simp [rtPartStps, pcsStps, pcsPre, List.append_assoc]) p.oBX
    (by rw [stpsOps_append, List.length_append, l2, lsq, h5]; rfl)
  intro x hx
  simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
  rcases hx with rfl | rfl | rfl
  · exact ⟨cA.1, cBA.2, cBA.1⟩
  · exact ⟨cH.1, cBH.2, cBH.1⟩
  · exact ⟨cX.1, cBX.2, cBX.1⟩

end Win

/-! ## `hal_opA` -/

section Hal

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **`opA`'s kind is alive** when every opening's windows are step ends inside the transcript and `opB`'s kind has no
doomed entrant among the first `n ≥` (number of parts) parts (L20's `opening_split`, opening by opening). -/
theorem rh_KA_al (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (hn : pf.parts.length ≤ n) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hw : ∀ i, i < pf.parts.length → ∀ x ∈ rtOps pf D i, tRem (rtW pf.sqs) (τ.take x.2.1) = some 0
      ∧ x.2.2 ≤ τ.length ∧ tRem (rtW pf.sqs) (τ.take x.2.2) = some 0)
    (hB : ¬ (rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) :
    (rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ := by
  intro i _ k c hc
  by_cases hi : i < pf.parts.length
  · have hc' : ((rtOps pf D i).map (fun x => x.1.opA U hbij x.2.1 lg))[k]? = some c := by
      simpa [rtKA, rtKind2, hi, RtKPart.ofOpA, RtKPart.ofMap] using hc
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (List.mem_of_getElem? hc')
    obtain ⟨hA1, hB0, hB1⟩ := hw i hi x hx
    have hab : x.2.1 ≤ x.2.2 := ((rtOps_win pf D i hi).1 x hx).2.1
    rcases opening_split (rtW pf.sqs) x.2.1 x.2.2 hab (encGL (K := K) x.1.lc x.1.h x.1.Q) x.1.e x.1.cl (x.1.Ux lg)
        (vRd U (2 ^ x.1.lc + x.1.Q) x.1.vpos) dg0 (x.1.nC + x.1.rows)
        (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (x.1.nC + x.1.rows) ≃ Fin x.1.nC ⊕ Fin x.1.rows))
        x.1.mI (idxCode x.1.h x.1.hQm) Block.labPcsProx (proxDec U (2 ^ x.1.lc + x.1.Q))
        (((2 ^ x.1.h : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞))
          ^ (2 * (x.1.nC + x.1.rows)))
        ((((Fintype.card (Fin (2 ^ x.1.h)) - (x.1.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ x.1.h))) ^ x.1.Q * 1)
        τ hA1 hB0 with hal | hdoom
    · exact hal
    · exfalso
      apply hB
      refine ⟨i, lt_of_lt_of_le hi hn, x.1.opB U hbij (rtW pf.sqs) x.2.1 x.2.2 lg, ?_, hB0, hB1, hdoom⟩
      have hm : x.1.opB U hbij (rtW pf.sqs) x.2.1 x.2.2 lg
          ∈ (rtOps pf D i).map (fun y => y.1.opB U hbij (rtW pf.sqs) y.2.1 y.2.2 lg) :=
        List.mem_map.mpr ⟨x, hx, rfl⟩
      simpa [rtKB, rtKind2, hi, RtKPart.ofOpB, RtKPart.ofMap] using hm
  · simp [rtKA, rtKind2, hi, RtKPart.nil] at hc

/-- **`hal_opA`** (the third ordered cover premise's conclusion, for EVERY kinds data `D`): on the run's transcript of
any output of the profile's shape (every accepted output is: `RtRun.accept`), if `opB`'s kind has no doomed entrant,
`opA`'s kind is alive at the end. -/
theorem rh_hal_opA (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (hn : pf.parts.length ≤ n) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (o : α) (h : RtGood Lq pf (rd o))
    (hB : ¬ (rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg (rtTr key domain Lq pf rd G o)) :
    (rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg (rtTr key domain Lq pf rd G o) :=
  rh_KA_al key domain hs Lq hL pf rd hL64 hv U hbij D hD n hn lg _
    (fun i hi => rh_win key domain Lq pf rd hv G o h D i hi) hB

end Hal

end ZK60.ProtocolClassify
