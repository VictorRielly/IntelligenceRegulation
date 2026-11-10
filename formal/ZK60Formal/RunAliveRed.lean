/-
D63 lane L50 (2026-11-10), part 1: **the six remaining ordered alive premises, reduced to their sub-protocols** (for
any kinds data `D` and any run; L43's `rh_KB_al` pattern).

The app's top theorem (`og_productionReadyL_epP_exec_blk`, lane L48) still assumes, kind by kind, that on an accepted
run outside the extraction event the slots (`hal_slots`), the four define schedules (`hal_R0`, `hal_R1`, `hal_H0`,
`hal_H1`) and LogUp (`hal_LU`) are alive at the end of the run's transcript, when no earlier kind of the order
(`opB`, `M`, `opA`, the slots, `r0`, `r1`, `h0`, `h1`) has a doomed entrant. This file takes those statements apart:

* `ra_ksl_cs`, `ra_ksl_cs_out`, `ra_ksq_cs_out`: a kind's part `i` lists the part's sub-protocols (none past the
  profile's parts);
* **`ra_Ksl_al`**, **`ra_Ksq_al`**, `ra_KR0_al` … `ra_KLU_al`: a kind is alive at the end when every one of its
  sub-protocols in every part of the profile is (`subSt` of the slot / squeeze run on the transcript);
* **`ra_Ksl_ent`**, `ra_slot_ent_iff`: no doomed slot means every slot whose window the transcript reaches entered
  with a TRUE claimed sum (or a polynomial over its degree);
* **`ra_Ksq_ent`**, **`ra_defSq_ent`**: no doomed squeeze run means every squeeze run whose window the transcript reaches
  entered with a true state; for L21's define draw `defSq`, its polynomial `Φ` vanishes identically on the history the
  header shows (and so, by a certified polynomial's `hΦ`, its start claim holds);
* **`ra_sq_end`**, `ra_sq_short`: a squeeze run is alive at the end when its window lies past the transcript, or when
  the transcript shows its `n` squeezes from its window and its state holds at the challenges `challenge_fp2` reads off
  them (L21's `cRd_sq`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunDoomBlk

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## A squeeze run's state at the end of a transcript -/

section End

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **A squeeze run whose window lies past the transcript is alive** (it has not started). -/
theorem ra_sq_short (U : K) (sx : SqX K Lq) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : τ.length < sx.a) : subSt W1 (sqSub U sx lg) τ :=
  Or.inl h

/-- **A squeeze run read to its end.** From its window the transcript shows its `n` squeezes (digests `ds`); its state
at the end of the transcript is its state at the challenges `challenge_fp2` reads off those digests. -/
theorem ra_sq_end (U : K) (sx : SqX K Lq) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (ks : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)) (hk : ks.length = sx.n)
    (hd : ks.length = ds.length) (hdrop : τ.drop sx.a = (ks.map TItem.squeeze).zip ds ++ rest)
    (hst : sx.St lg (τ.take sx.a) (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))) :
    subSt W1 (sqSub U sx lg) τ := by
  refine Or.inr (Or.inl ⟨tRem_W1 _, ?_⟩)
  have hr := cRd_sq sx.n ks ds [] rest (by rw [List.length_nil, zero_add, hk]) hd
  show liftC ((sqSub U sx lg).St (τ.take sx.a))
    ((τ.drop sx.a).foldl (cRdStep (sqR sx.n) W1) (some ([], none, [])))
  rw [hdrop, hr, liftC_some, List.nil_append]
  show sx.St lg (τ.take sx.a)
    (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 (ds.map (fun d => (([] : List UInt8), [d]))))
  rw [chalTr_sq]
  exact hst

/-- **A slot's entry state**: its polynomial is over its degree, or its claimed sum is the cube sum. -/
theorem ra_slot_ent_iff (U : K) (sl : Slot K) (a : ℕ) (hdr : List (TItem × Dig)) :
    (slotSub U sl a).St hdr [] ↔ (¬ IndDegLE sl.d (sl.stmt hdr).1 ∨ (sl.stmt hdr).2.toK U = cubeSum (sl.stmt hdr).1) :=
  Iff.rfl

end End

/-! ## The kinds' parts, alive and not doomed -/

section Kinds

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **The slots' kind's part `i` is the part's slots** at the log. -/
theorem ra_ksl_cs (i : ℕ) (hi : i < pf.parts.length) (P : List (QB Lq × Dig)) :
    (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).cs i P = slotSubs U (slotsAt (D.sls i) P) := by
  unfold rtKsl rtKind1
  simp only [hi, ↓reduceDIte]
  rfl

/-- Past the profile's parts the slots' kind has none. -/
theorem ra_ksl_cs_out (i : ℕ) (hi : ¬ i < pf.parts.length) (P : List (QB Lq × Dig)) :
    (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).cs i P = [] := by
  unfold rtKsl rtKind1
  simp only [hi, ↓reduceDIte]
  rfl

/-- Past the profile's parts a squeeze kind has none. -/
theorem ra_ksq_cs_out (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs) (i : ℕ)
    (hi : ¬ i < pf.parts.length) (P : List (QB Lq × Dig)) :
    (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx).cs i P = [] := by
  unfold rtKsq rtKind1
  simp only [hi, ↓reduceDIte]
  rfl

/-- **The slots' kind is alive at the end** when every slot of every part of the profile is (at its window
`slotsLenX (earlier slots) + s`). -/
theorem ra_Ksl_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ (k : ℕ) (sl : SlotX K Lq), (D.sls i)[k]? = some sl →
      subSt W1 (slotSub U (sl.at lg) (slotsLenX ((D.sls i).take k) + sl.s)) τ) :
    (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ := by
  intro i _ k c hc
  by_cases hi : i < pf.parts.length
  · rw [ra_ksl_cs key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi, rt_slotSubs_getElem?] at hc
    obtain ⟨sl, hsl, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact h i hi k sl hsl
  · rw [ra_ksl_cs_out key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi] at hc
    simp at hc

/-- **A squeeze kind is alive at the end** when every squeeze run of every part of the profile is. -/
theorem ra_Ksq_al (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ sxs i, subSt W1 (sqSub U sx lg) τ) :
    (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx).Al n lg τ := by
  intro i _ k c hc
  by_cases hi : i < pf.parts.length
  · rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx i hi] at hc
    obtain ⟨sx, hsx', rfl⟩ := List.mem_map.mp (List.mem_of_getElem? hc)
    exact h i hi sx hsx'
  · rw [ra_ksq_cs_out key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx i hi] at hc
    simp at hc

/-- `hal_R0`'s conclusion from every `r0` squeeze run's. -/
theorem ra_KR0_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ D.r0 i, subSt W1 (sqSub U sx lg) τ) :
    (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ :=
  ra_Ksq_al key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r0 hD.r0 n lg τ h

/-- `hal_R1`'s conclusion from every `r1` squeeze run's. -/
theorem ra_KR1_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ D.r1 i, subSt W1 (sqSub U sx lg) τ) :
    (rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ :=
  ra_Ksq_al key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r1 hD.r1 n lg τ h

/-- `hal_H0`'s conclusion from every `h0` squeeze run's. -/
theorem ra_KH0_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ D.h0 i, subSt W1 (sqSub U sx lg) τ) :
    (rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ :=
  ra_Ksq_al key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h0 hD.h0 n lg τ h

/-- `hal_H1`'s conclusion from every `h1` squeeze run's. -/
theorem ra_KH1_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ D.h1 i, subSt W1 (sqSub U sx lg) τ) :
    (rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ :=
  ra_Ksq_al key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h1 hD.h1 n lg τ h

/-- `hal_LU`'s conclusion from every LogUp run's. -/
theorem ra_KLU_al (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length → ∀ sx ∈ D.lu i, subSt W1 (sqSub U sx lg) τ) :
    (rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ :=
  ra_Ksq_al key domain hs Lq hL pf rd hL64 hv U hbij D.eL (3 * D.eL) D.lu hD.lu n lg τ h

/-- **No doomed slot**: every slot of a part (among the first `n`) whose window the transcript reaches entered with a
true state (`ra_slot_ent_iff`: a true claimed sum, or a polynomial over its degree). -/
theorem ra_Ksl_ent (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hnd : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) (i : ℕ) (hin : i < n)
    (hi : i < pf.parts.length) (k : ℕ) (sl : SlotX K Lq) (hk : (D.sls i)[k]? = some sl)
    (ha : slotsLenX ((D.sls i).take k) + sl.s ≤ τ.length) :
    (slotSub U (sl.at lg) (slotsLenX ((D.sls i).take k) + sl.s)).St
      (τ.take (slotsLenX ((D.sls i).take k) + sl.s)) [] := by
  by_contra hn
  apply hnd
  refine ⟨i, hin, slotSub U (sl.at lg) (slotsLenX ((D.sls i).take k) + sl.s), ?_, ha, tRem_W1 _, hn⟩
  rw [ra_ksl_cs key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi]
  exact List.mem_of_getElem? (by rw [rt_slotSubs_getElem?, hk]; rfl)

/-- **No doomed squeeze run**: every squeeze run of a part (among the first `n`) whose window the transcript reaches
entered with a true state. -/
theorem ra_Ksq_ent (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hnd : ¬ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx).Dm n lg τ) (i : ℕ) (hin : i < n)
    (hi : i < pf.parts.length) (sx : SqX K Lq) (hmem : sx ∈ sxs i) (ha : sx.a ≤ τ.length) :
    sx.St lg (τ.take sx.a) [] := by
  by_contra hn
  apply hnd
  refine ⟨i, hin, sqSub U sx lg, ?_, ha, tRem_W1 _, hn⟩
  rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx i hi]
  exact List.mem_map_of_mem hmem

omit [Fintype K] [DecidableEq K] [Algebra GF K] in
/-- **A define draw that entered alive**: on a header that reads as `define`'s history `h`, its polynomial vanishes
identically (L21's state before any challenge, `szSt_nil`). -/
theorem ra_defSq_ent {P : Exec.Block.BlockParams} {hdrLen : ℕ} {absOf : QB Lq → Option (List UInt8)}
    {Φ : Exec.Block.Cuts3 Lq → Exec.Block.RootsO → (k : ℕ) → Exec.Block.Hist → (Fin (P.draws k) → K) → K}
    {dg : ℕ → ℕ} {s : ℕ} (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) (h : Exec.Block.Hist)
    (rest : List (TItem × Dig)) (hh : Exec.Block.tHistD P hdrLen s hdr = some (h, rest))
    (hst : (Exec.Block.defSq P hdrLen absOf Φ dg s).St lg hdr []) :
    ∀ y, Φ (Exec.Block.cuts3 absOf lg (Exec.Block.rootsAt hdrLen hdr)) (Exec.Block.rootsAt hdrLen hdr) s h y = 0 := by
  simp only [Exec.Block.defSq, hh] at hst
  exact (szSt_nil _).mp hst

end Kinds

end ZK60.ProtocolClassify
