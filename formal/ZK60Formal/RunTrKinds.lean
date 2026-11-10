/-
D63 lane L34 (2026-11-09), part 5: **the nine kinds' lists on the run's transcript, part by part, as L27's `KindRun`s,
with their forms** (L30 §5.7 item 3; the premises `Ksl … KLU`, `hℓ`, `hnp`, `hsl … hLU` and `RCx`, `htrx`, `hℓx`,
`hwA`, `hwB` of `classifyU_productionReady_run_r13_token`).

Every part of the run (stage IN-C, a block, stage OUT-C) has the same checks: its sumcheck slots, its `M` check, three
regular openings (`A`, `H`, and the commitment it closes), the define draws of its slot relations and hosts, its LogUp
challenges. So every kind's list in part `i` is one constructor at the profile's windows (`RunTrSched.lean`):

* `RtKPart`: one part of one kind (its sub-protocols at a log, between the part's offsets, with every fact `KindRun`
  asks); `RtKPart.nil`; **`RtKPart.ofMap`** (a list of sub-protocols given by descriptors: the facts descriptor by
  descriptor);
* **`rtKind1`**, **`rtKind2`**: a kind from its parts, on the single-step parse `rtRC1` or the wide parse `rtRC2` of
  the run's transcript `rtTr`: an L27 `KindRun` (`htr` is `rtRC1_chain` / `rtRC2_chain`, the offsets are the profile's
  `off`, `np` the number of parts, the header before part `0`); `rtKind1_sqForm`, `rtKind2_powForm`;
* the constructors of the code's sub-protocols at a window:
  - slots: `RtKPart.ofSlots` (L8 / L16's `slotSubs` of a part's slots `SlotX`, their statements cut readers);
  - `M`: `RtMask` (the mask-spec count, the functional count, the reader of `M`'s data), `RtMask.sub` (L16's
    `maskCSubX` at L28's constants), `RtKPart.ofMask`;
  - the openings: `RtOpen` (a regular opening in L28's form: its geometry `(h, Q, e)`, rows, claims, index squeezes,
    the claims' and the extracted matrix's readers), `RtOpen.opA`, `RtOpen.opB` (L20's `opACSub`, `opBCSub` with
    exactly the arguments of L28's `EvOW`), `RtOpen.Valid`, **`RtOpen.opA_rbr`**, **`RtOpen.opB_rbr`**,
    **`RtOpen.opA_eps`** (`≤ 2^-110` for `h ≤ 16`), `rtOpen_r13_epsB` (`≤ 2^-126` at R13's geometry),
    `RtKPart.ofOpA`, `RtKPart.ofOpB`;
  - the define draws and LogUp: `RtKPart.ofSq` (L21's squeeze runs `sqPart` of `SqX`);
* `RtKData`: the run's kinds data, part by part (the slots, `M`, the three openings, the four define schedules,
  LogUp); `RtKData.Valid`: its side conditions (L20 / L21 / L23's per-block conditions, asked for each part, and the
  agreement of `M`'s and the openings' counts with the profile's);
* **`rtKsl`**, **`rtKM`**, **`rtKA`**, **`rtKB`**, **`rtKR0`**, **`rtKR1`**, **`rtKH0`**, **`rtKH1`**, **`rtKLU`**: the
  nine kinds; **`rtK_forms`**: their forms at R13 (slots `SqForm 7 (7·370)`, `M` `PowForm 3 106`, `opA` `PowForm 1 110`,
  `opB` `PowForm 1 126`, the four define schedules `SqForm 80 (80·451)`, LogUp `SqForm e (3e)`); **`rtK_chain`**: each
  kind's chain has at most `2^21` items and `np` is the number of parts;
* `rtRCx_hw`: the column test's parse is `rtRC2`, and its windows are after the header.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrSched
import ZK60Formal.LinkW16GlueR13

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## One part of one kind -/

/-- **One part of one kind**: its sub-protocols at a log, with what L27's `KindRun` asks of a part: windows between
`lo` and `hi` and in order, round-by-round soundness, errors within `εmax`, `n·ε` within `B`, no release, and states
that read the prover's log only through cuts at the roots their headers absorb. -/
structure RtKPart (Lq : ℕ) (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (εmax B : ℝ≥0∞) (lo hi : ℕ) where
  cs : List (QB Lq × Dig) → List (CSub Dig)
  hseg : ∀ P, ∀ c ∈ cs P, lo ≤ c.a ∧ c.a ≤ hi
  hsort : ∀ P, (cs P).Pairwise (fun c c' => c.a ≤ c'.a)
  hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε
  hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ εmax
  hnorel : ∀ P, ∀ c ∈ cs P, ∀ τ, ¬ c.rel τ
  hB : ∀ P, ∀ c ∈ cs P, (c.R.n : ℝ≥0∞) * c.ε ≤ B
  hcut : ∀ (P P' : List (QB Lq × Dig)) (τ : List (TItem × Dig)), CutEq absOf τ P P' →
    List.Forall₂ (AgreeOn W τ) (cs P) (cs P')

/-- The empty part. -/
def RtKPart.nil (Lq : ℕ) (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (εmax B : ℝ≥0∞) (lo hi : ℕ) :
    RtKPart Lq absOf W εmax B lo hi where
  cs := fun _ => []
  hseg := fun _ _ hc => absurd hc List.not_mem_nil
  hsort := fun _ => List.Pairwise.nil
  hR := fun _ _ hc => absurd hc List.not_mem_nil
  hε := fun _ _ hc => absurd hc List.not_mem_nil
  hnorel := fun _ _ hc => absurd hc List.not_mem_nil
  hB := fun _ _ hc => absurd hc List.not_mem_nil
  hcut := fun _ _ _ _ => List.Forall₂.nil

/-- **A part given by descriptors**: the sub-protocols `f x P` of the descriptors `x ∈ l`, with the facts descriptor by
descriptor. -/
def RtKPart.ofMap {ι : Type} (Lq : ℕ) (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (εmax B : ℝ≥0∞)
    (lo hi : ℕ) (l : List ι) (f : ι → List (QB Lq × Dig) → CSub Dig)
    (ha : ∀ x ∈ l, ∀ P, lo ≤ (f x P).a ∧ (f x P).a ≤ hi)
    (hord : ∀ P, l.Pairwise (fun x y => (f x P).a ≤ (f y P).a))
    (hR : ∀ x ∈ l, ∀ P, RbrWide (f x P).R.n (f x P).R.w (f x P).St (f x P).ε)
    (hε : ∀ x ∈ l, ∀ P, (f x P).ε ≤ εmax) (hnorel : ∀ x ∈ l, ∀ P τ, ¬ (f x P).rel τ)
    (hB : ∀ x ∈ l, ∀ P, ((f x P).R.n : ℝ≥0∞) * (f x P).ε ≤ B)
    (hcut : ∀ x ∈ l, ∀ (P P' : List (QB Lq × Dig)) (τ : List (TItem × Dig)), CutEq absOf τ P P' →
      AgreeOn W τ (f x P) (f x P')) : RtKPart Lq absOf W εmax B lo hi where
  cs := fun P => l.map (fun x => f x P)
  hseg := fun P c hc => by
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hc
    exact ha x hx P
  hsort := fun P => by
    rw [List.pairwise_map]
    exact hord P
  hR := fun P c hc => by
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hc
    exact hR x hx P
  hε := fun P c hc => by
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hc
    exact hε x hx P
  hnorel := fun P c hc τ => by
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hc
    exact hnorel x hx P τ
  hB := fun P c hc => by
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hc
    exact hB x hx P
  hcut := fun P P' τ h => forall₂_map_map l _ _ (fun x hx => hcut x hx P P' τ h)

theorem rt_pairwise3 {β : Type} {R : β → β → Prop} (a b c : β) (h12 : R a b) (h13 : R a c) (h23 : R b c) :
    [a, b, c].Pairwise R :=
  List.Pairwise.cons (fun x hx => by
    rcases List.mem_cons.mp hx with h | h
    · rw [h]
      exact h12
    · rw [List.mem_singleton.mp h]
      exact h13)
    (List.Pairwise.cons (fun x hx => by
      rw [List.mem_singleton.mp hx]
      exact h23) (List.pairwise_singleton R c))

theorem rt_forall₂_of_getElem? {β γ : Type} {R : β → γ → Prop} : ∀ (l₁ : List β) (l₂ : List γ),
    l₁.length = l₂.length → (∀ (k : ℕ) (x : β) (y : γ), l₁[k]? = some x → l₂[k]? = some y → R x y) →
    List.Forall₂ R l₁ l₂
  | [], [], _, _ => List.Forall₂.nil
  | [], _ :: _, h, _ => by simp at h
  | _ :: _, [], h, _ => by simp at h
  | x :: l₁, y :: l₂, h, hR =>
    List.Forall₂.cons (hR 0 x y List.getElem?_cons_zero List.getElem?_cons_zero)
      (rt_forall₂_of_getElem? l₁ l₂ (by simpa using h)
        (fun k a b ha hb => hR (k + 1) a b (by simpa using ha) (by simpa using hb)))

/-! ## A kind from its parts -/

section Kind

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)

/-- **A kind on the single-step parse of the run's transcript**, from its parts between the profile's offsets (L21's
squeeze runs: the slots, the define draws, LogUp). -/
noncomputable def rtKind1 (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (εmax B : ℝ≥0∞)
    (parts : ∀ i : ℕ, RtKPart Lq (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) W1 εmax B (pf.off i)
      (pf.off (i + 1))) : KindRun (rtTr key domain Lq pf rd) where
  RC := rtRC1 key domain hs Lq hL pf rd
  htr := rtRC1_chain key domain hs Lq hL pf rd hL64 hv
  np := pf.parts.length
  off := pf.off
  hoff := pf.off_le
  hs0 := by
    show pf.hdrLen - 1 < pf.off 0
    rw [pf.off_zero]
    have h0 := hv.hdr
    omega
  cs := fun i P => (parts i).cs P
  hseg := fun i P => (parts i).hseg P
  hsort := fun i P => (parts i).hsort P
  εmax := εmax
  hR := fun i P => (parts i).hR P
  hε := fun i P => (parts i).hε P
  hnorel := fun i P => (parts i).hnorel P
  B := B
  hB := fun i P => (parts i).hB P
  hcut := fun i P P' τ h => (parts i).hcut P P' τ h

/-- **A kind on the wide parse of the run's transcript**, from its parts between the profile's offsets (L20 / L22's
`M` and openings). -/
noncomputable def rtKind2 (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (εmax B : ℝ≥0∞)
    (parts : ∀ i : ℕ, RtKPart Lq (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (rtW pf.sqs) εmax B (pf.off i)
      (pf.off (i + 1))) : KindRun (rtTr key domain Lq pf rd) where
  RC := rtRC2 key domain hs Lq hL pf rd hL64 hv
  htr := rtRC2_chain key domain hs Lq hL pf rd hL64 hv
  np := pf.parts.length
  off := pf.off
  hoff := pf.off_le
  hs0 := by
    show pf.hdrLen - 1 < pf.off 0
    rw [pf.off_zero]
    have h0 := hv.hdr
    omega
  cs := fun i P => (parts i).cs P
  hseg := fun i P => (parts i).hseg P
  hsort := fun i P => (parts i).hsort P
  εmax := εmax
  hR := fun i P => (parts i).hR P
  hε := fun i P => (parts i).hε P
  hnorel := fun i P => (parts i).hnorel P
  B := B
  hB := fun i P => (parts i).hB P
  hcut := fun i P P' τ h => (parts i).hcut P P' τ h

theorem rtKind1_sqForm (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (emax ND : ℕ)
    (parts : ∀ i : ℕ, RtKPart Lq (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) W1
      (((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) (((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) (pf.off i)
      (pf.off (i + 1))) :
    (rtKind1 key domain hs Lq hL pf rd hL64 hv _ _ parts).SqForm emax ND := ⟨le_rfl, le_rfl⟩

theorem rtKind2_powForm (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (n j : ℕ)
    (parts : ∀ i : ℕ, RtKPart Lq (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (rtW pf.sqs)
      ((2⁻¹ : ℝ≥0∞) ^ j) ((n : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ j) (pf.off i) (pf.off (i + 1))) :
    (rtKind2 key domain hs Lq hL pf rd hL64 hv _ _ parts).PowForm n j := ⟨le_rfl, le_rfl⟩

/-- **The column test's parse** (`RCx` of L30's gate) is the wide parse; a window at or after the header's end is
after the parse's header. -/
theorem rtRCx_hw (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (a : ℕ) (ha : pf.hdrLen ≤ a) :
    (rtRC2 key domain hs Lq hL pf rd hL64 hv).s < a := by
  show pf.hdrLen - 1 < a
  have h0 := hv.hdr
  omega

end Kind

/-! ## The code's sub-protocols at a window -/

section Subs

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-! ### Squeeze runs: the define draws and LogUp -/

/-- **A part of squeeze runs** (L21's `sqPart`: a block's define draws of one relation or host schedule, its LogUp):
each a cut reader, round-by-round sound, with at most `emax` escaping challenges a round and `n·e ≤ ND`, its window in
the part, the windows in order. -/
noncomputable def RtKPart.ofSq [Fintype K] [DecidableEq K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (absOf : QB Lq → Option (List UInt8))
    (emax ND lo hi : ℕ) (sxs : List (SqX K Lq)) (hcutX : ∀ sx ∈ sxs, SqCut absOf sx) (hRb : ∀ sx ∈ sxs, sx.Rbr)
    (he : ∀ sx ∈ sxs, sx.e ≤ emax) (hnd : ∀ sx ∈ sxs, sx.n * sx.e ≤ ND)
    (hwin : ∀ sx ∈ sxs, lo ≤ sx.a ∧ sx.a ≤ hi) (hord : sxs.Pairwise (fun a b => a.a ≤ b.a)) :
    RtKPart Lq absOf W1 (((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      (((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) lo hi :=
  RtKPart.ofMap Lq absOf W1 _ _ lo hi sxs (fun sx P => sqSub U sx P) (fun sx hsx _ => hwin sx hsx)
    (fun _ => hord)
    (fun sx hsx P => (sqPart_facts U hbij sxs hRb emax ND he hnd P (sqSub U sx P) (List.mem_map.mpr ⟨sx, hsx, rfl⟩)).1)
    (fun sx hsx P => (sqPart_facts U hbij sxs hRb emax ND he hnd P (sqSub U sx P) (List.mem_map.mpr ⟨sx, hsx, rfl⟩)).2.1)
    (fun sx hsx P => (sqPart_facts U hbij sxs hRb emax ND he hnd P (sqSub U sx P) (List.mem_map.mpr ⟨sx, hsx, rfl⟩)).2.2.2)
    (fun sx hsx P => (sqPart_facts U hbij sxs hRb emax ND he hnd P (sqSub U sx P) (List.mem_map.mpr ⟨sx, hsx, rfl⟩)).2.2.1)
    (fun sx hsx P P' τ h => agreeOn_sqSub U absOf sx (hcutX sx hsx) W1 τ P P' h)

/-! ### The sumcheck slots -/

theorem rt_slotSubs_getElem? (U : K) (sls : List (SlotX K Lq)) (P : List (QB Lq × Dig)) (k : ℕ) :
    (slotSubs U (slotsAt sls P))[k]?
      = sls[k]?.map (fun sl => slotSub U (sl.at P) (slotsLenX (sls.take k) + sl.s)) := by
  rw [slotSubs_getElem?, slotsLen_take_at, slotsAt, List.getElem?_map, Option.map_map]
  rfl

theorem rt_mem_slotSubs (U : K) (sls : List (SlotX K Lq)) (P : List (QB Lq × Dig)) (c : CSub Dig)
    (hc : c ∈ slotSubs U (slotsAt sls P)) :
    ∃ (k : ℕ) (sl : SlotX K Lq), sls[k]? = some sl ∧ c = slotSub U (sl.at P) (slotsLenX (sls.take k) + sl.s) := by
  obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
  rw [rt_slotSubs_getElem?] at hk
  obtain ⟨sl, hsl, hc'⟩ := Option.map_eq_some_iff.mp hk
  exact ⟨k, sl, hsl, hc'.symm⟩

/-- **A part's slots** (L8 / L16's `slotSubs` of the part's slots at a log; for a block, L16's `blockSchedX` at the
block's run position): each statement a cut reader, degree `≤ dmax` (and `< p`), `n·d ≤ ND`, each window in the
part. -/
noncomputable def RtKPart.ofSlots [Fintype K] [DecidableEq K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (absOf : QB Lq → Option (List UInt8))
    (W : UInt64 → ℕ) (dmax ND lo hi : ℕ) (sls : List (SlotX K Lq))
    (hcutX : ∀ sl ∈ sls, CutReads absOf sl.stmt) (hd : ∀ sl ∈ sls, sl.d < gP ∧ sl.d ≤ dmax ∧ sl.n * sl.d ≤ ND)
    (hwin : ∀ (k : ℕ) (sl : SlotX K Lq), sls[k]? = some sl →
      lo ≤ slotsLenX (sls.take k) + sl.s ∧ slotsLenX (sls.take k) + sl.s ≤ hi) :
    RtKPart Lq absOf W (((dmax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
      (((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) lo hi where
  cs := fun P => slotSubs U (slotsAt sls P)
  hseg := fun P c hc => by
    obtain ⟨k, sl, hk, rfl⟩ := rt_mem_slotSubs U sls P c hc
    exact hwin k sl hk
  hsort := fun P => slotSubs_sorted U (slotsAt sls P)
  hR := fun P c hc => by
    obtain ⟨k, sl, hk, rfl⟩ := rt_mem_slotSubs U sls P c hc
    have hm := hd sl (List.mem_of_getElem? hk)
    exact (slotSub_facts U hbij (sl.at P) hm.1 _ dmax ND hm.2.1 hm.2.2).1
  hε := fun P c hc => by
    obtain ⟨k, sl, hk, rfl⟩ := rt_mem_slotSubs U sls P c hc
    have hm := hd sl (List.mem_of_getElem? hk)
    exact (slotSub_facts U hbij (sl.at P) hm.1 _ dmax ND hm.2.1 hm.2.2).2.1
  hnorel := fun P c hc => by
    obtain ⟨k, sl, hk, rfl⟩ := rt_mem_slotSubs U sls P c hc
    have hm := hd sl (List.mem_of_getElem? hk)
    exact (slotSub_facts U hbij (sl.at P) hm.1 _ dmax ND hm.2.1 hm.2.2).2.2.2
  hB := fun P c hc => by
    obtain ⟨k, sl, hk, rfl⟩ := rt_mem_slotSubs U sls P c hc
    have hm := hd sl (List.mem_of_getElem? hk)
    exact (slotSub_facts U hbij (sl.at P) hm.1 _ dmax ND hm.2.1 hm.2.2).2.2.1
  hcut := fun P P' τ h => by
    refine rt_forall₂_of_getElem? _ _ (by simp [slotSubs, slotsAt]) (fun k x y hx hy => ?_)
    rw [rt_slotSubs_getElem?] at hx hy
    obtain ⟨sl, hsl, hx'⟩ := Option.map_eq_some_iff.mp hx
    rw [hsl] at hy
    have hy' : slotSub U (sl.at P') (slotsLenX (sls.take k) + sl.s) = y := by simpa using hy
    rw [← hx', ← hy']
    exact agreeOn_slotSub U absOf sl (hcutX sl (List.mem_of_getElem? hsl)) _ W τ P P' h

/-! ### `M` -/

/-- **A part's `M` check**: its mask-spec count `S`, its functional count `k`, and the reader `Dm` of `M`'s data (the
functionals the part's slots leave, the extracted mask table) off the prover's log and the header. -/
structure RtMask (K : Type) (Lq : ℕ) where
  S : ℕ
  k : ℕ
  Dm : List (QB Lq × Dig) → List (TItem × Dig) → MData K (Fin (2 ^ 12)) (Fin S) (Fin (2 * S + 2)) k 512

variable [Fintype K] [DecidableEq K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **`M` at a window** (L16's `maskCSubX` at L28's constants, as in L28's `EvMW`). -/
noncomputable def RtMask.sub (m : RtMask K Lq) (a : ℕ) (P : List (QB Lq × Dig)) : CSub Dig :=
  maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega m.S a (m.Dm P) (Equiv.refl _) (fun _ => False)

/-- **A part's `M`**: one sub-protocol at the part's `M` window; three rounds, error `≤ 2^-106`. -/
noncomputable def RtKPart.ofMask (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (lo hi : ℕ)
    (m : RtMask K Lq) (a : ℕ) (hK : Fintype.card K = gP ^ 2) (hk : 0 < m.k) (hk20 : m.k ≤ 2 ^ 20)
    (hS : 2 * m.S + 2 ≤ 2 ^ 20) (hcutX : CutReads absOf m.Dm) (ha : lo ≤ a ∧ a ≤ hi) :
    RtKPart Lq absOf W ((2⁻¹ : ℝ≥0∞) ^ 106) (((3 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 106) lo hi :=
  RtKPart.ofMap Lq absOf W _ _ lo hi [()] (fun _ P => m.sub U hbij a P) (fun _ _ _ => ha)
    (fun _ => List.pairwise_singleton _ _)
    (fun _ _ P => (mask_facts U (Equiv.ofBijective _ hbij) mEtaE mOmega_prim hk m.S a (m.Dm P) (Equiv.refl _) hK
      hk20 hS).1)
    (fun _ _ P => (mask_facts U (Equiv.ofBijective _ hbij) mEtaE mOmega_prim hk m.S a (m.Dm P) (Equiv.refl _) hK
      hk20 hS).2.1)
    (fun _ _ P => (mask_facts U (Equiv.ofBijective _ hbij) mEtaE mOmega_prim hk m.S a (m.Dm P) (Equiv.refl _) hK
      hk20 hS).2.2.2)
    (fun _ _ P => (mask_facts U (Equiv.ofBijective _ hbij) mEtaE mOmega_prim hk m.S a (m.Dm P) (Equiv.refl _) hK
      hk20 hS).2.2.1)
    (fun _ _ P P' τ h => agreeOn_maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega m.S a (m.Dm P) (m.Dm P')
      (Equiv.refl _) (fun _ => False) W τ (hcutX P P' _ (cutEq_take absOf τ P P' h a)))

/-! ### A regular opening -/

/-- **A regular opening of the run, in L28's form**: its geometry `(h, Q, e)` (codewords of `2^h` symbols, `2^14`
message columns, `Q` queries and pads, radius `e`), its rows, its number of claims, its index squeezes, the claims it
checks as a function of its header, the matrix extracted for its root from the prover's log, and the position of its
group vectors. -/
structure RtOpen (K : Type) (Lq : ℕ) where
  h : ℕ
  Q : ℕ
  e : ℕ
  rows : ℕ
  nC : ℕ
  mI : ℕ
  hQm : Q ≤ mI * 4
  cl : List (TItem × Dig) → OClaims (Fin nC) ℕ (Fin rows) (Fin (2 ^ 14 + Q)) K
  Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin rows → Fin (2 ^ h) → K
  vpos : ℕ

/-- **The opening's first half at its window `aO`** (L20's `opACSub`, with the arguments of L28's `evOW_bound`). -/
noncomputable def RtOpen.opA (o : RtOpen K Lq) (aO : ℕ) (P : List (QB Lq × Dig)) : CSub Dig :=
  opACSub (encG (K := K) o.h o.Q) o.e o.cl (o.Ux P) dg0 (o.nC + o.rows)
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (o.nC + o.rows) ≃ Fin o.nC ⊕ Fin o.rows)) aO
    (((2 ^ o.h : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (o.nC + o.rows)))

/-- **The opening's second half at its windows `aO`, `aB`** (L20's `opBCSub`, with the arguments of L28's `EvOW`), read
under the step parse `W`. -/
noncomputable def RtOpen.opB (W : UInt64 → ℕ) (o : RtOpen K Lq) (aO aB : ℕ) (P : List (QB Lq × Dig)) : CSub Dig :=
  opBCSub W aO (o.nC + o.rows) (encG (K := K) o.h o.Q) o.e o.cl (o.Ux P) (vRd U (2 ^ 14 + o.Q) o.vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (o.nC + o.rows) ≃ Fin o.nC ⊕ Fin o.rows)) o.mI
    (idxCode o.h o.hQm) Block.labPcsProx (proxDec U (2 ^ 14 + o.Q)) aB
    ((((Fintype.card (Fin (2 ^ o.h)) - (o.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ o.h))) ^ o.Q * 1)

/-- **An opening's side conditions**: `h ≤ 16`, at least one query, the unique-decoding radius
(`2e + (2^14 + Q) ≤ 2^h`), a batching run of at most `2^61` squeezes, the column round within `2^-126`, and an
extracted matrix that reads the log through cuts. -/
structure RtOpen.Valid (o : RtOpen K Lq) (absOf : QB Lq → Option (List UInt8)) : Prop where
  hh : o.h ≤ 16
  hQ0 : 0 < o.Q
  he : 2 * o.e + (2 ^ 14 + o.Q) ≤ 2 ^ o.h
  hw : o.nC + o.rows ≤ 2 ^ 61
  hεB : (((Fintype.card (Fin (2 ^ o.h)) - (o.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ o.h))) ^ o.Q * 1
    ≤ (2⁻¹ : ℝ≥0∞) ^ 126
  hcut : CutReads absOf o.Ux

/-- **The column round at R13's geometry** `(16, 256, 24448)` is within `2^-126` (L28's `opB_eps_r13u`). -/
theorem rtOpen_r13_epsB :
    (((Fintype.card (Fin (2 ^ 16)) - (24448 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 16))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 126 := opB_eps_r13u

/-- **`opA` is round-by-round sound** (L20's `opACSub_rbr` with L10's code facts at the geometry and the code's
`(λ, ρ)` derivation). -/
theorem RtOpen.opA_rbr (o : RtOpen K Lq) (absOf : QB Lq → Option (List UInt8)) (hv : o.Valid absOf) (aO : ℕ)
    (P : List (QB Lq × Dig)) :
    RbrWide (o.opA U hbij aO P).R.n (o.opA U hbij aO P).R.w (o.opA U hbij aO P).St (o.opA U hbij aO P).ε := by
  have h1 := hv.hh
  have h2 := hv.hQ0
  have h3 := hv.he
  have hpts := ptsG_injective (K := K) o.h (by omega)
  have hd := encLin_minDist (Q := o.Q) (ptsG (K := K) o.h) hpts RW (by norm_num)
  have hca := encLin_caOn (Q := o.Q) (e := o.e) (ptsG (K := K) o.h) hpts RW (by norm_num) (by omega)
  exact opACSub_rbr (encG (K := K) o.h o.Q) hd (by omega) (by omega) hca o.cl (o.Ux P) dg0 (o.nC + o.rows)
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (o.nC + o.rows) ≃ Fin o.nC ⊕ Fin o.rows)) _
    (lrCode_prob_le gP (Equiv.ofBijective _ hbij) _) aO

omit [Fintype K] in
/-- **`opB` is round-by-round sound** (L20's `opBCSub_rbr` with the code's index derivation). -/
theorem RtOpen.opB_rbr (W : UInt64 → ℕ) (o : RtOpen K Lq) (absOf : QB Lq → Option (List UInt8)) (hv : o.Valid absOf)
    (aO aB : ℕ) (P : List (QB Lq × Dig)) :
    RbrWide (o.opB U hbij W aO aB P).R.n (o.opB U hbij W aO aB P).R.w (o.opB U hbij W aO aB P).St
      (o.opB U hbij W aO aB P).ε := by
  have h1 := hv.hh
  have h2 := hv.hQ0
  have h3 := hv.he
  have hpts := ptsG_injective (K := K) o.h (by omega)
  have hd := encLin_minDist (Q := o.Q) (ptsG (K := K) o.h) hpts RW (by norm_num)
  exact opBCSub_rbr W aO (o.nC + o.rows) (encG (K := K) o.h o.Q) (encG_injective o.h o.Q (by omega) (by omega)) hd
    (by omega) o.cl (o.Ux P) (vRd U (2 ^ 14 + o.Q) o.vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (o.nC + o.rows) ≃ Fin o.nC ⊕ Fin o.rows)) o.mI
    (idxCode o.h o.hQm) 1 (idxCode_prob_le (by omega) o.hQm) Block.labPcsProx (proxDec U (2 ^ 14 + o.Q)) aB

omit [Field K] [Algebra GF K] [DecidableEq K] in
/-- **`opA`'s error is within `2^-110`** for `h ≤ 16` (L28's `opA_eps_r13`: `|K| = p²`, at most `2^61` batching
squeezes). -/
theorem RtOpen.opA_eps (o : RtOpen K Lq) (hK : Fintype.card K = gP ^ 2) (hh : o.h ≤ 16)
    (hw : o.nC + o.rows ≤ 2 ^ 61) :
    ((2 ^ o.h : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (o.nC + o.rows))
      ≤ (2⁻¹ : ℝ≥0∞) ^ 110 :=
  le_trans (mul_le_mul' (ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.pow_le_pow_right (by norm_num) hh)) _)
    le_rfl) (opA_eps_r13 gP (by norm_num [gP]) (by norm_num [gP]) hK hw)

/-- **A part's openings, first halves**: the openings `x.1` at their windows `x.2.1` (and second windows `x.2.2`), in
order. One round each, error `≤ 2^-110`. -/
noncomputable def RtKPart.ofOpA (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (lo hi : ℕ)
    (l : List (RtOpen K Lq × ℕ × ℕ)) (hK : Fintype.card K = gP ^ 2)
    (hl : ∀ x ∈ l, x.1.Valid absOf ∧ lo ≤ x.2.1 ∧ x.2.1 ≤ x.2.2 ∧ x.2.2 ≤ hi)
    (hord : l.Pairwise (fun x y => x.2.1 ≤ y.2.1)) :
    RtKPart Lq absOf W ((2⁻¹ : ℝ≥0∞) ^ 110) (((1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 110) lo hi :=
  RtKPart.ofMap Lq absOf W _ _ lo hi l (fun x P => x.1.opA U hbij x.2.1 P)
    (fun x hx _ => ⟨(hl x hx).2.1, (hl x hx).2.2.1.trans (hl x hx).2.2.2⟩) (fun _ => hord)
    (fun x hx P => x.1.opA_rbr U hbij absOf (hl x hx).1 x.2.1 P)
    (fun x hx _ => x.1.opA_eps hK (hl x hx).1.hh (hl x hx).1.hw) (fun _ _ _ _ h => h)
    (fun x hx _ => mul_le_mul' le_rfl (x.1.opA_eps hK (hl x hx).1.hh (hl x hx).1.hw))
    (fun x hx P P' τ h => agreeOn_opACSub _ _ _ _ _ _ _ _ _ _ W τ
      ((hl x hx).1.hcut P P' _ (cutEq_take absOf τ P P' h x.2.1)))

/-- **A part's openings, second halves**, at their second windows, read under the parse `W`. One round each, error
`≤ 2^-126`. -/
noncomputable def RtKPart.ofOpB (absOf : QB Lq → Option (List UInt8)) (W : UInt64 → ℕ) (lo hi : ℕ)
    (l : List (RtOpen K Lq × ℕ × ℕ))
    (hl : ∀ x ∈ l, x.1.Valid absOf ∧ lo ≤ x.2.1 ∧ x.2.1 ≤ x.2.2 ∧ x.2.2 ≤ hi)
    (hord : l.Pairwise (fun x y => x.2.2 ≤ y.2.2)) :
    RtKPart Lq absOf W ((2⁻¹ : ℝ≥0∞) ^ 126) (((1 : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 126) lo hi :=
  RtKPart.ofMap Lq absOf W _ _ lo hi l (fun x P => x.1.opB U hbij W x.2.1 x.2.2 P)
    (fun x hx _ => ⟨(hl x hx).2.1.trans (hl x hx).2.2.1, (hl x hx).2.2.2⟩) (fun _ => hord)
    (fun x hx P => x.1.opB_rbr U hbij W absOf (hl x hx).1 x.2.1 x.2.2 P)
    (fun x hx _ => (hl x hx).1.hεB) (fun _ _ _ _ h => h)
    (fun x hx _ => mul_le_mul' le_rfl (hl x hx).1.hεB)
    (fun x hx P P' τ h => agreeOn_opBCSub W _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ τ
      ((hl x hx).1.hcut P P' _ (cutEq_take absOf _ P P' (cutEq_take absOf τ P P' h x.2.2) x.2.1)))

end Subs

/-! ## The run's kinds data and the nine kinds -/

/-- **The run's kinds data, part by part** (part `0` stage IN-C, part `k + 1` block `k`, the last part stage OUT-C):
the part's slots; its `M`; its three openings (`A`, `H`, and the commitment it closes: the input endpoint, the previous
boundary, `B_out`); the define draws of its two relation schedules (`r0`, `r1`) and two host schedules (`h0`, `h1`); its
LogUp challenges; and LogUp's escape count `eL`. -/
structure RtKData (K : Type) (Lq : ℕ) where
  sls : ℕ → List (SlotX K Lq)
  msk : ℕ → RtMask K Lq
  opA : ℕ → RtOpen K Lq
  opH : ℕ → RtOpen K Lq
  opX : ℕ → RtOpen K Lq
  r0 : ℕ → List (SqX K Lq)
  r1 : ℕ → List (SqX K Lq)
  h0 : ℕ → List (SqX K Lq)
  h1 : ℕ → List (SqX K Lq)
  lu : ℕ → List (SqX K Lq)
  eL : ℕ

section Nine

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- A family of squeeze runs meets a squeeze kind's conditions in every part: cut readers, round-by-round sound, at
most `emax` escaping challenges a round, `n·e ≤ ND`, windows in the part and in order. -/
def RtSqOk {Lq : ℕ} (absOf : QB Lq → Option (List UInt8)) (pf : RtProf) (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq)) : Prop :=
  ∀ i, i < pf.parts.length →
    (∀ sx ∈ sxs i, SqCut absOf sx ∧ sx.Rbr ∧ sx.e ≤ emax ∧ sx.n * sx.e ≤ ND ∧ pf.off i ≤ sx.a ∧ sx.a ≤ pf.off (i + 1))
      ∧ (sxs i).Pairwise (fun a b => a.a ≤ b.a)

/-- **The kinds data's side conditions at a profile** (R13's constants), for every part `i` of the run:
* the slots: statements cut readers, degree `≤ 7` (and `< p`), `n·d ≤ 7·370`, windows in the part;
* `M`: a functional count in `1 … 2^20`, `2S + 2 ≤ 2^20`, the data a cut reader, and `S` the profile's;
* the three openings: `RtOpen.Valid`, and their batching widths and index squeezes the profile's;
* the four define schedules at `(80, 80·451)` and LogUp at `(eL, 3·eL)`, `eL ≤ 2^26`. -/
structure RtKData.Valid {Lq : ℕ} (D : RtKData K Lq) (absOf : QB Lq → Option (List UInt8)) (pf : RtProf) : Prop where
  hK : Fintype.card K = gP ^ 2
  slCut : ∀ i, i < pf.parts.length → ∀ sl ∈ D.sls i, CutReads absOf sl.stmt
  slDeg : ∀ i, i < pf.parts.length → ∀ sl ∈ D.sls i, sl.d < gP ∧ sl.d ≤ 7 ∧ sl.n * sl.d ≤ 7 * 370
  slWin : ∀ i, i < pf.parts.length → ∀ (k : ℕ) (sl : SlotX K Lq), (D.sls i)[k]? = some sl →
    pf.off i ≤ slotsLenX ((D.sls i).take k) + sl.s ∧ slotsLenX ((D.sls i).take k) + sl.s ≤ pf.off (i + 1)
  mK : ∀ i, i < pf.parts.length → 0 < (D.msk i).k ∧ (D.msk i).k ≤ 2 ^ 20 ∧ 2 * (D.msk i).S + 2 ≤ 2 ^ 20
  mCut : ∀ i, i < pf.parts.length → CutReads absOf (D.msk i).Dm
  mS : ∀ i, i < pf.parts.length → (D.msk i).S = (pf.part i).S
  opV : ∀ i, i < pf.parts.length → (D.opA i).Valid absOf ∧ (D.opH i).Valid absOf ∧ (D.opX i).Valid absOf
  opW : ∀ i, i < pf.parts.length →
    ((D.opA i).nC + (D.opA i).rows = (pf.part i).wA ∧ (D.opA i).mI = (pf.part i).mA)
      ∧ ((D.opH i).nC + (D.opH i).rows = (pf.part i).wH ∧ (D.opH i).mI = (pf.part i).mH)
      ∧ ((D.opX i).nC + (D.opX i).rows = (pf.part i).wX ∧ (D.opX i).mI = (pf.part i).mX)
  r0 : RtSqOk absOf pf 80 (80 * 451) D.r0
  r1 : RtSqOk absOf pf 80 (80 * 451) D.r1
  h0 : RtSqOk absOf pf 80 (80 * 451) D.h0
  h1 : RtSqOk absOf pf 80 (80 * 451) D.h1
  lu : RtSqOk absOf pf D.eL (3 * D.eL) D.lu
  heL : D.eL ≤ 2 ^ 26

/-- The three openings of part `i` with their windows on the run's transcript. -/
def rtOps {F : Type} {Lq : ℕ} (pf : RtProf) (D : RtKData F Lq) (i : ℕ) : List (RtOpen F Lq × ℕ × ℕ) :=
  [(D.opA i, pf.off i + (pf.part i).oA, pf.off i + (pf.part i).oBA),
    (D.opH i, pf.off i + (pf.part i).oH, pf.off i + (pf.part i).oBH),
    (D.opX i, pf.off i + (pf.part i).oX, pf.off i + (pf.part i).oBX)]

/-- The windows of part `i`'s openings lie in the part, in order. -/
theorem rtOps_win {F : Type} {Lq : ℕ} (pf : RtProf) (D : RtKData F Lq) (i : ℕ) (hi : i < pf.parts.length) :
    (∀ x ∈ rtOps pf D i, pf.off i ≤ x.2.1 ∧ x.2.1 ≤ x.2.2 ∧ x.2.2 ≤ pf.off (i + 1))
      ∧ (rtOps pf D i).Pairwise (fun x y => x.2.1 ≤ y.2.1) ∧ (rtOps pf D i).Pairwise (fun x y => x.2.2 ≤ y.2.2) := by
  have hs' := pf.off_succ i hi
  refine ⟨fun x hx => ?_, ?_, ?_⟩
  · simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
    rcases hx with rfl | rfl | rfl <;>
      simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA] at hs' ⊢ <;> omega
  · refine rt_pairwise3 _ _ _ ?_ ?_ ?_ <;>
      simp only [RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA] <;> omega
  · refine rt_pairwise3 _ _ _ ?_ ?_ ?_ <;>
      simp only [RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA] <;> omega

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq)

variable (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **The slots' kind**: in each part, `slotSubs` of the part's slots. -/
noncomputable def rtKsl : KindRun (rtTr key domain Lq pf rd) :=
  rtKind1 key domain hs Lq hL pf rd hL64 hv _ _ (fun i =>
    if hi : i < pf.parts.length then
      RtKPart.ofSlots U hbij _ W1 7 (7 * 370) _ _ (D.sls i) (hD.slCut i hi) (hD.slDeg i hi) (hD.slWin i hi)
    else RtKPart.nil Lq _ W1 _ _ _ _)

/-- **`M`'s kind**: in each part, `M` at the part's `M` window. -/
noncomputable def rtKM : KindRun (rtTr key domain Lq pf rd) :=
  rtKind2 key domain hs Lq hL pf rd hL64 hv _ _ (fun i =>
    if hi : i < pf.parts.length then
      RtKPart.ofMask U hbij _ (rtW pf.sqs) _ _ (D.msk i) (pf.off i + (pf.part i).pre) hD.hK (hD.mK i hi).1
        (hD.mK i hi).2.1 (hD.mK i hi).2.2 (hD.mCut i hi)
        ⟨Nat.le_add_right _ _, by
          rw [pf.off_succ i hi]
          simp only [RtPart.len, RtPart.oBX, RtPart.oX, RtPart.oBH, RtPart.oH, RtPart.oBA, RtPart.oA]
          omega⟩
    else RtKPart.nil Lq _ (rtW pf.sqs) _ _ _ _)

/-- **The openings' first halves' kind**: in each part, `opA` of `A`, `H` and the closing opening. -/
noncomputable def rtKA : KindRun (rtTr key domain Lq pf rd) :=
  rtKind2 key domain hs Lq hL pf rd hL64 hv _ _ (fun i =>
    if hi : i < pf.parts.length then
      RtKPart.ofOpA U hbij _ (rtW pf.sqs) _ _ (rtOps pf D i) hD.hK
        (fun x hx => by
          have hw := (rtOps_win pf D i hi).1 x hx
          have hV := hD.opV i hi
          simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
          rcases hx with rfl | rfl | rfl
          · exact ⟨hV.1, hw⟩
          · exact ⟨hV.2.1, hw⟩
          · exact ⟨hV.2.2, hw⟩)
        (rtOps_win pf D i hi).2.1
    else RtKPart.nil Lq _ (rtW pf.sqs) _ _ _ _)

/-- **The openings' second halves' kind**: in each part, `opB` of `A`, `H` and the closing opening, read under the
run's wide parse. -/
noncomputable def rtKB : KindRun (rtTr key domain Lq pf rd) :=
  rtKind2 key domain hs Lq hL pf rd hL64 hv _ _ (fun i =>
    if hi : i < pf.parts.length then
      RtKPart.ofOpB U hbij _ (rtW pf.sqs) _ _ (rtOps pf D i)
        (fun x hx => by
          have hw := (rtOps_win pf D i hi).1 x hx
          have hV := hD.opV i hi
          simp only [rtOps, List.mem_cons, List.mem_nil_iff, or_false] at hx
          rcases hx with rfl | rfl | rfl
          · exact ⟨hV.1, hw⟩
          · exact ⟨hV.2.1, hw⟩
          · exact ⟨hV.2.2, hw⟩)
        (rtOps_win pf D i hi).2.2
    else RtKPart.nil Lq _ (rtW pf.sqs) _ _ _ _)

/-- **A squeeze kind** (a define schedule, or LogUp): in each part, the part's squeeze runs. -/
noncomputable def rtKsq (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs) :
    KindRun (rtTr key domain Lq pf rd) :=
  rtKind1 key domain hs Lq hL pf rd hL64 hv _ _ (fun i =>
    if hi : i < pf.parts.length then
      RtKPart.ofSq U hbij _ emax ND _ _ (sxs i) (fun sx h => ((hsx i hi).1 sx h).1)
        (fun sx h => ((hsx i hi).1 sx h).2.1) (fun sx h => ((hsx i hi).1 sx h).2.2.1)
        (fun sx h => ((hsx i hi).1 sx h).2.2.2.1)
        (fun sx h => ⟨((hsx i hi).1 sx h).2.2.2.2.1, ((hsx i hi).1 sx h).2.2.2.2.2⟩) (hsx i hi).2
    else RtKPart.nil Lq _ W1 _ _ _ _)

/-- The first relation schedule's define draws. -/
noncomputable def rtKR0 : KindRun (rtTr key domain Lq pf rd) :=
  rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r0 hD.r0

/-- The second relation schedule's define draws. -/
noncomputable def rtKR1 : KindRun (rtTr key domain Lq pf rd) :=
  rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r1 hD.r1

/-- The first host schedule's define draws. -/
noncomputable def rtKH0 : KindRun (rtTr key domain Lq pf rd) :=
  rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h0 hD.h0

/-- The second host schedule's define draws. -/
noncomputable def rtKH1 : KindRun (rtTr key domain Lq pf rd) :=
  rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h1 hD.h1

/-- LogUp's kind. -/
noncomputable def rtKLU : KindRun (rtTr key domain Lq pf rd) :=
  rtKsq key domain hs Lq hL pf rd hL64 hv U hbij D.eL (3 * D.eL) D.lu hD.lu

/-- **The nine kinds' forms at R13** (the premises `hsl`, `hM`, `hA`, `hB`, `hR₀`, `hR₁`, `hH₀`, `hH₁`, `hLU` of
`classifyU_productionReady_run_r13_token`): the slots `SqForm 7 (7·370)`, `M` `PowForm 3 106`, `opA` `PowForm 1 110`,
`opB` `PowForm 1 126`, each define schedule `SqForm 80 (80·451)`, LogUp `SqForm eL (3·eL)`. -/
theorem rtK_forms :
    (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm 7 (7 * 370)
      ∧ (rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD).PowForm 3 106
      ∧ (rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD).PowForm 1 110
      ∧ (rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD).PowForm 1 126
      ∧ (rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm 80 (80 * 451)
      ∧ (rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm 80 (80 * 451)
      ∧ (rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm 80 (80 * 451)
      ∧ (rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm 80 (80 * 451)
      ∧ (rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD).SqForm D.eL (3 * D.eL) :=
  ⟨⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩,
    ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩, ⟨le_rfl, le_rfl⟩⟩

/-- **The nine kinds' chains** (the premises `hℓ` and `hnp` of the gate): each kind's parse has at most `2^21` items,
and its parts are the profile's. -/
theorem rtK_chain :
    ∀ K' ∈ [rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD],
      K'.RC.ℓ ≤ 2 ^ 21 ∧ K'.np = pf.parts.length := by
  intro K' hK'
  simp only [List.mem_cons, List.mem_nil_iff, or_false] at hK'
  rcases hK' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact ⟨le_rfl, rfl⟩

/-- **The nine kinds in the order of dependence** (L30 §5.3, finding L30-1; the list `Ko` of the gate's ordered
cover): the openings' second halves, `M`, the openings' first halves, the slots, the relation draws, the host draws,
LogUp. A kind must be alive at the end only when no earlier kind has a doomed entrant. -/
noncomputable def rtKo : List (KindRun (rtTr key domain Lq pf rd)) :=
  [rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD,
    rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD,
    rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
    rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
    rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD]

/-- The ordered list holds exactly the nine kinds (the premise `hKo` of the gate). -/
theorem rtKo_mem :
    ∀ K' ∈ rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD,
      K' ∈ [rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKA key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKB key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD] := by
  intro K' hK'
  simp only [rtKo, List.mem_cons, List.mem_nil_iff, or_false] at hK'
  rcases hK' with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))
  · exact List.mem_cons_of_mem _ List.mem_cons_self
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self)
  · exact List.mem_cons_self
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
      List.mem_cons_self)))
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
      (List.mem_cons_of_mem _ List.mem_cons_self))))
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
      (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self)))))
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
      (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))))))
  · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
      (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        List.mem_cons_self)))))))

end Nine

end ZK60.ProtocolClassify
