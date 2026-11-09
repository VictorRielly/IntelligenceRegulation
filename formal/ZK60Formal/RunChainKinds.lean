/-
D63 lane L27 (2026-11-07), part 5: **the nine kinds' sub-protocols on the run's chain** (deliverable 1, concretely):
each kind's sub-protocols of a block, at the block's ABSOLUTE windows on the run's chain, meet `KindRun`'s premises.

The blocks' sub-protocols are L16/L20/L21's (`slotSub`, `maskCSubX`, `opACSub`, `opBCSub`, `sqSub` of `defSq` and
`lkSq`). Each takes its window as a parameter, and each round-by-round lemma holds at EVERY window and for every header
reader (`slotSub_rbr`, `maskCSubX_rbr`, `opACSub_rbr`, `opBCSub_rbr`, `sqSub_rbr` with `defSq_rbr` / `lkSq_rbr`; the
stages' `chalSub_rbr`): so the rbr lemmas carry to the run's chain unchanged once the windows are the run's positions.
For a block whose run prefix (the run header, stage IN-C, the earlier blocks, its frame) has `h` entries, L9's block
model with `hdrLen := h` places every window at its run position (`defPos P h k`, LogUp's `h + 4`, the slots'
`slotsLen` from `h + 10`). What a kind needs beyond that is `KindRun`'s `hcut`: its states read the prover's log only
through the cuts at the roots their headers absorb. Proved here for every extraction of the code:

* `forall₂_map_map`: two lists mapped from one list agree when every pair does;
* `cuts3_cutEq`, `colX_cutEq`: L16's three cuts and L22's extracted column read the log through such cuts;
* `defSq_cutEq`, `lkSq_cutEq`: the define draws' and LogUp's states (L21);
* **`agreeOn_sqSub`**, **`sqPart_cut`**, `sqPart_facts`: a list of squeeze-run sub-protocols (`sqSub`) at two logs,
  their states cut readers: `hcut`; and the rest of `KindRun`'s premises (rbr, `ε ≤ emax·fibC/|Dig|`,
  `n·ε ≤ ND·fibC/|Dig|`, no release) from L21's facts: the four define kinds and LogUp;
* **`agreeOn_slotSub`**, `slotSub_facts`: one slot at two logs, its statement a cut reader (the slots' kind);
* **`agreeOn_toCSub`**, **`agreeOn_maskCSubX`**, **`agreeOn_opACSub`**, **`agreeOn_opBCSub`**: `M` and the openings'
  two halves at two logs, their readers (the mask rows and functionals, the extracted matrix) agreeing on the header;
  `mask_facts`: `M`'s error `≤ 2^-106` in three rounds (`PowForm 3 106`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainSched
import ZK60Formal.ExtractInstW16
import ZK60Formal.StageFS

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## Lists mapped from one list -/

theorem forall₂_map_map {β γ δ : Type _} {R : γ → δ → Prop} (l : List β) (f : β → γ) (g : β → δ)
    (h : ∀ x ∈ l, R (f x) (g x)) : List.Forall₂ R (l.map f) (l.map g) := by
  induction l with
  | nil => exact List.Forall₂.nil
  | cons a l ih =>
    exact List.Forall₂.cons (h a List.mem_cons_self) (ih (fun x hx => h x (List.mem_cons_of_mem _ hx)))

/-! ## The code's extractions read the log through cuts -/

section Cuts

variable {L : ℕ} {Q : Type}

/-- **L16's three cuts are cut readers**: on a header whose roots two logs cut alike, the three cuts agree. -/
theorem cuts3_cutEq (absOf : QB L → Option (List UInt8)) (hdr : List (TItem × Dig)) (P P' : List (QB L × Dig))
    (h : CutEq absOf hdr P P') (hdrLen : ℕ) :
    Exec.Block.cuts3 absOf P (Exec.Block.rootsAt hdrLen hdr) = Exec.Block.cuts3 absOf P' (Exec.Block.rootsAt hdrLen hdr) := by
  simp only [Exec.Block.cuts3, Exec.Block.rootsAt, h hdrLen, h (hdrLen + 3), h (hdrLen + 7)]

/-- **L22's extracted column is a cut reader** (`colX`: the root at a header position and the log cut at it). -/
theorem colX_cutEq (tag : MTag) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (d i : ℕ)
    (hdr : List (TItem × Dig)) (P P' : List (QB L × Dig))
    (h : CutEq (Exec.Block.absOfC (chainEncB key domain hs L hL)) hdr P P') (j : ℕ) :
    Exec.Link.colX tag L h64 key domain hs hL d i P hdr j = Exec.Link.colX tag L h64 key domain hs hL d i P' hdr j := by
  unfold Exec.Link.colX
  cases Exec.Link.rootAt hdr i with
  | none => rfl
  | some r =>
    simp only
    rw [h i]

variable {K : Type} [Field K] [Algebra GF K]

omit [Algebra GF K] in
/-- **The define draws' states are cut readers** (L21's `defSq`: the polynomial of the cuts at the roots the header
shows, and what the header shows). -/
theorem defSq_cutEq (P0 : Exec.Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Exec.Block.Cuts3 L → Exec.Block.RootsO → (k : ℕ) → Exec.Block.Hist → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) (hdr : List (TItem × Dig)) (P P' : List (QB L × Dig)) (h : CutEq absOf hdr P P')
    (τr : List (List UInt8 × K)) :
    (Exec.Block.defSq P0 hdrLen absOf Φ dg k).St P hdr τr ↔ (Exec.Block.defSq P0 hdrLen absOf Φ dg k).St P' hdr τr := by
  simp only [Exec.Block.defSq, cuts3_cutEq absOf hdr P P' h hdrLen]

variable [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

omit [Algebra GF K] in
/-- **LogUp's state is a cut reader** (L21's `lkSq`: the lookups and multiplicities of the log cut at the `A` root the
header shows). -/
theorem lkSq_cutEq (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB L × Dig) → κ → K) (hdr : List (TItem × Dig)) (P P' : List (QB L × Dig)) (h : CutEq absOf hdr P P')
    (τr : List (List UInt8 × K)) :
    (Exec.Block.lkSq hdrLen absOf Alk T mlk).St P hdr τr ↔ (Exec.Block.lkSq hdrLen absOf Alk T mlk).St P' hdr τr := by
  simp only [Exec.Block.lkSq, h hdrLen]

end Cuts

/-! ## Squeeze-run sub-protocols: the define kinds and LogUp -/

section Sq

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- A squeeze-run sub-protocol's state reads the log through cuts. -/
def SqCut (absOf : QB L → Option (List UInt8)) (sx : SqX K L) : Prop :=
  ∀ (P P' : List (QB L × Dig)) (hdr : List (TItem × Dig)), CutEq absOf hdr P P' →
    ∀ τr, sx.St P hdr τr ↔ sx.St P' hdr τr

/-- **One squeeze-run sub-protocol at two logs cut alike agrees on the chain.** -/
theorem agreeOn_sqSub (U : K) (absOf : QB L → Option (List UInt8)) (sx : SqX K L) (hsx : SqCut absOf sx)
    (W : UInt64 → ℕ) (τ : List (TItem × Dig)) (P P' : List (QB L × Dig)) (h : CutEq absOf τ P P') :
    AgreeOn W τ (sqSub U sx P) (sqSub U sx P') :=
  agreeOn_of_st W τ _ _ rfl rfl (fun _ => hsx P P' _ (cutEq_take absOf τ P P' h sx.a) _) Iff.rfl

/-- The part of a kind made of squeeze runs (a block's define draws, its LogUp), at a log. -/
noncomputable def sqPart (U : K) (sxs : List (SqX K L)) (P : List (QB L × Dig)) : List (CSub Dig) :=
  sxs.map (fun sx => sqSub U sx P)

/-- **`hcut` for a part of squeeze runs.** -/
theorem sqPart_cut (U : K) (absOf : QB L → Option (List UInt8)) (sxs : List (SqX K L))
    (hsx : ∀ sx ∈ sxs, SqCut absOf sx) (W : UInt64 → ℕ) (P P' : List (QB L × Dig)) (τ : List (TItem × Dig))
    (h : CutEq absOf τ P P') : List.Forall₂ (AgreeOn W τ) (sqPart U sxs P) (sqPart U sxs P') :=
  forall₂_map_map sxs _ _ (fun sx hx => agreeOn_sqSub U absOf sx (hsx sx hx) W τ P P' h)

variable [Fintype K] [DecidableEq K]

/-- **The other premises of `KindRun` for a part of squeeze runs** (L21's facts): each sub-protocol round-by-round sound
(`sqSub_rbr`), its error `e·fibC/|Dig| ≤ emax·fibC/|Dig|`, its rounds' errors `n·e·fibC/|Dig| ≤ ND·fibC/|Dig|`, never
released. -/
theorem sqPart_facts (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (sxs : List (SqX K L))
    (hR : ∀ sx ∈ sxs, sx.Rbr) (emax ND : ℕ) (he : ∀ sx ∈ sxs, sx.e ≤ emax) (hnd : ∀ sx ∈ sxs, sx.n * sx.e ≤ ND)
    (P : List (QB L × Dig)) :
    ∀ c ∈ sqPart U sxs P, RbrWide c.R.n c.R.w c.St c.ε
      ∧ c.ε ≤ ((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ (c.R.n : ℝ≥0∞) * c.ε ≤ ((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ ∀ τ, ¬ c.rel τ := by
  intro c hc
  obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
  refine ⟨sqSub_rbr U hbij sx (hR sx hsx) P, ?_, ?_, fun _ h => h⟩
  · show ((sx.e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ _
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ (he sx hsx))) _
  · show ((sx.n : ℕ) : ℝ≥0∞) * (((sx.e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) ≤ _
    rw [← mul_div_assoc, ← Nat.cast_mul]
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (by
      calc sx.n * (sx.e * fibC) = (sx.n * sx.e) * fibC := by ring
        _ ≤ ND * fibC := Nat.mul_le_mul_right _ (hnd sx hsx))) _

/-- The draws' offsets grow with the slot count. -/
theorem defOff_succ_le (P0 : Exec.Block.BlockParams) :
    ∀ (m j : ℕ), Exec.Block.defOff P0 j m ≤ Exec.Block.defOff P0 j (m + 1)
  | 0, _ => Nat.zero_le _
  | m + 1, j => Nat.add_le_add_left (defOff_succ_le P0 m (j + 1)) _

omit [Fintype K] [DecidableEq K] in
/-- **A block's define part has its windows in order** (slot `k`'s draws at `defPos P h k`, the slots in increasing
order): `KindRun.hsort` for the define kinds' block parts. -/
theorem defPart_sorted (U : K) (P0 : Exec.Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Exec.Block.Cuts3 L → Exec.Block.RootsO → (k : ℕ) → Exec.Block.Hist → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (ks : List ℕ) (hks : ks.Pairwise (· ≤ ·)) (Lg : List (QB L × Dig)) :
    (sqPart U (ks.map (Exec.Block.defSq P0 hdrLen absOf Φ dg)) Lg).Pairwise (fun c c' => c.a ≤ c'.a) := by
  unfold sqPart
  rw [List.map_map, List.pairwise_map]
  refine hks.imp (fun {k k'} h => ?_)
  show hdrLen + 10 + Exec.Block.defOff P0 0 k ≤ hdrLen + 10 + Exec.Block.defOff P0 0 k'
  exact Nat.add_le_add_left (off_mono _ (fun i => defOff_succ_le P0 i 0) k k' h) _

omit [Fintype K] [DecidableEq K] in
/-- **A block's define part lies inside the block** (between its run prefix `h` and the end of its slot loop
`defLen P h`): `KindRun.hseg` for the define kinds' block parts, with the block's offsets around these. -/
theorem defPart_seg (U : K) (P0 : Exec.Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Exec.Block.Cuts3 L → Exec.Block.RootsO → (k : ℕ) → Exec.Block.Hist → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (ks : List ℕ) (hks : ∀ k ∈ ks, k ≤ P0.geom.slots.length) (Lg : List (QB L × Dig)) :
    ∀ c ∈ sqPart U (ks.map (Exec.Block.defSq P0 hdrLen absOf Φ dg)) Lg,
      hdrLen ≤ c.a ∧ c.a ≤ Exec.Block.defLen P0 hdrLen := by
  intro c hc
  unfold sqPart at hc
  rw [List.map_map] at hc
  obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hc
  show hdrLen ≤ hdrLen + 10 + Exec.Block.defOff P0 0 k
    ∧ hdrLen + 10 + Exec.Block.defOff P0 0 k ≤ hdrLen + 10 + Exec.Block.defOff P0 0 P0.geom.slots.length
  exact ⟨by omega, Nat.add_le_add_left (off_mono _ (fun i => defOff_succ_le P0 i 0) k _ (hks k hk)) _⟩

omit [Fintype K] in
/-- **A block's LogUp part** (one squeeze run at `h + 4`, after the header and the `A` and `M` absorbs) lies inside the
block and is trivially in order. -/
theorem lkPart_seg {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (U : K) (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8)) (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB L × Dig) → κ → K) (Lg : List (QB L × Dig)) :
    (∀ c ∈ sqPart U [Exec.Block.lkSq hdrLen absOf Alk T mlk] Lg, hdrLen ≤ c.a ∧ c.a ≤ hdrLen + 4)
      ∧ (sqPart U [Exec.Block.lkSq hdrLen absOf Alk T mlk] Lg).Pairwise (fun c c' => c.a ≤ c'.a) := by
  refine ⟨fun c hc => ?_, List.pairwise_singleton _ _⟩
  simp only [sqPart, List.map_cons, List.map_nil, List.mem_singleton] at hc
  subst hc
  show hdrLen ≤ hdrLen + 4 ∧ hdrLen + 4 ≤ hdrLen + 4
  omega

omit [Algebra GF K] [Fintype K] [DecidableEq K] in
/-- **The define draws are cut readers** (`defSq_cutEq`), so every define kind's block part meets `hcut`. -/
theorem defSq_sqCut (P0 : Exec.Block.BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Exec.Block.Cuts3 L → Exec.Block.RootsO → (k : ℕ) → Exec.Block.Hist → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqCut absOf (Exec.Block.defSq P0 hdrLen absOf Φ dg k) :=
  fun P P' hdr h τr => defSq_cutEq P0 hdrLen absOf Φ dg k hdr P P' h τr

omit [Algebra GF K] [Fintype K] in
/-- **LogUp is a cut reader** (`lkSq_cutEq`). -/
theorem lkSq_sqCut {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8)) (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K)
    (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K) :
    SqCut absOf (Exec.Block.lkSq hdrLen absOf Alk T mlk) :=
  fun P P' hdr h τr => lkSq_cutEq hdrLen absOf Alk T mlk hdr P P' h τr

end Sq

/-! ## Slots -/

section Slots

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **One slot at two logs agrees on the chain** when its statement reads the log through cuts. -/
theorem agreeOn_slotSub (U : K) (absOf : QB L → Option (List UInt8)) (sl : SlotX K L)
    (hsl : ∀ (P P' : List (QB L × Dig)) (hdr : List (TItem × Dig)), CutEq absOf hdr P P' → sl.stmt P hdr = sl.stmt P' hdr)
    (a : ℕ) (W : UInt64 → ℕ) (τ : List (TItem × Dig)) (P P' : List (QB L × Dig)) (h : CutEq absOf τ P P') :
    AgreeOn W τ (slotSub U (sl.at P) a) (slotSub U (sl.at P') a) := by
  refine agreeOn_of_st W τ _ _ rfl rfl (fun τr => ?_) Iff.rfl
  show scSt U sl.d sl.n (sl.stmt P) (τ.take a) _ ↔ scSt U sl.d sl.n (sl.stmt P') (τ.take a) _
  have he : sl.stmt P (τ.take a) = sl.stmt P' (τ.take a) := hsl P P' _ (cutEq_take absOf τ P P' h a)
  unfold scSt
  rw [he]
  exact Iff.rfl

omit [Field K] [Algebra GF K] in
/-- A run of slots' prefix grows by the next slot's items. -/
theorem slotsLen_take_succ (slots : List (Slot K)) (i : ℕ) (hi : i < slots.length) :
    slotsLen (slots.take (i + 1)) = slotsLen (slots.take i) + (slots[i]'hi).len := by
  unfold slotsLen
  rw [List.take_add_one, List.getElem?_eq_getElem hi, List.map_append, List.sum_append]
  simp only [Option.toList_some, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]

omit [Field K] [Algebra GF K] in
theorem slotsLen_take_mono (slots : List (Slot K)) (i j : ℕ) (hij : i ≤ j) :
    slotsLen (slots.take i) ≤ slotsLen (slots.take j) := by
  have h : slots.take j = slots.take i ++ (slots.take j).drop i := by
    conv_lhs => rw [← List.take_append_drop i (slots.take j)]
    rw [List.take_take, min_eq_left hij]
  rw [h]
  simp only [slotsLen, List.map_append, List.sum_append]
  exact Nat.le_add_right _ _

/-- **A block's slot part has its windows in order** (L8's `slotSubs`: slot `k`'s window after the earlier slots' items
and its own interstitial operations): `KindRun.hsort` for the slots' block parts. -/
theorem slotSubs_sorted (U : K) (slots : List (Slot K)) :
    (slotSubs U slots).Pairwise (fun c c' => c.a ≤ c'.a) := by
  refine List.pairwise_iff_getElem.mpr (fun i j hi hj hij => ?_)
  have hi' : i < slots.length := by simpa [slotSubs] using hi
  have hj' : j < slots.length := by simpa [slotSubs] using hj
  simp only [slotSubs, List.getElem_mapIdx]
  show slotsLen (slots.take i) + (slots[i]'hi').s ≤ slotsLen (slots.take j) + (slots[j]'hj').s
  have h1 := slotsLen_take_succ slots i hi'
  have h2 := slotsLen_take_mono slots (i + 1) j hij
  have h3 : (slots[i]'hi').s ≤ (slots[i]'hi').len := by
    unfold Slot.len
    omega
  omega

variable [Fintype K] [DecidableEq K]

/-- **A slot's other premises** (L8's facts): round-by-round sound (`slotSub_rbr`, degree `< p`), its error
`d·fibC/|Dig| ≤ dmax·fibC/|Dig|`, its rounds' errors `n·d·fibC/|Dig| ≤ ND·fibC/|Dig|`, never released. -/
theorem slotSub_facts (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (sl : Slot K)
    (hdp : sl.d < gP) (a dmax ND : ℕ) (hd : sl.d ≤ dmax) (hnd : sl.n * sl.d ≤ ND) :
    RbrWide (slotSub U sl a).R.n (slotSub U sl a).R.w (slotSub U sl a).St (slotSub U sl a).ε
      ∧ (slotSub U sl a).ε ≤ ((dmax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ ((slotSub U sl a).R.n : ℝ≥0∞) * (slotSub U sl a).ε ≤ ((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ ∀ τ, ¬ (slotSub U sl a).rel τ := by
  refine ⟨slotSub_rbr U hbij sl hdp a, ?_, ?_, fun _ h => h⟩
  · show ((sl.d * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ _
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ hd)) _
  · show ((sl.n : ℕ) : ℝ≥0∞) * (((sl.d * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) ≤ _
    rw [← mul_div_assoc, ← Nat.cast_mul]
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (by
      calc sl.n * (sl.d * fibC) = (sl.n * sl.d) * fibC := by ring
        _ ≤ ND * fibC := Nat.mul_le_mul_right _ hnd)) _

end Slots

/-! ## `M` and the openings' two halves -/

section Readers

/-- **A sub-protocol of L10's form (`toCSub`) at two header readers agrees on the chain** when the readers agree on
its header. -/
theorem agreeOn_toCSub {X M : Type} (a : ℕ) (R : Rounds) (ε : ℝ≥0∞) (St : X → List (M × List Dg) → Prop)
    (xOf xOf' : List (TItem × Dig) → X) (dec : List UInt8 → M) (rel : List (TItem × Dig) → Prop)
    (W : UInt64 → ℕ) (τ : List (TItem × Dig)) (h : xOf (τ.take a) = xOf' (τ.take a)) :
    AgreeOn W τ (toCSub a R ε St xOf dec rel) (toCSub a R ε St xOf' dec rel) :=
  agreeOn_of_st W τ _ _ rfl rfl (fun τr => by
    show St (xOf (τ.take a)) _ ↔ St (xOf' (τ.take a)) _
    rw [h]) Iff.rfl

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)

omit [DecidableEq K] in
/-- **`M` at two logs agrees on the chain** when the extracted mask data agree on its header. -/
theorem agreeOn_maskCSubX (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) (ω : K) {σ κ : Type} [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k : ℕ} (S : ℕ) (a : ℕ) (xOf xOf' : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) (rel : List (TItem × Dig) → Prop) (W : UInt64 → ℕ) (τ : List (TItem × Dig))
    (h : xOf (τ.take a) = xOf' (τ.take a)) :
    AgreeOn W τ (maskCSubX U eF dom ω S a xOf eR rel) (maskCSubX U eF dom ω S a xOf' eR rel) := by
  unfold maskCSubX
  exact agreeOn_toCSub _ _ _ _ _ _ _ _ W τ h

/-- **`M`'s other premises** (L10/L16): round-by-round sound (`maskCSubX_rbr`), three rounds, its error
`maskEps ≤ 2^-106` (`maskEps_le`, `|K| = p²`, at most `2^20` functionals and rows), never released (`rel = False`). -/
theorem mask_facts (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) {ω : K} (hω : IsPrimitiveRoot ω 512)
    {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ] {k : ℕ} (hk : 0 < k) (S : ℕ) (a : ℕ)
    (xOf : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512) (eR : κ ≃ Fin (2 * S + 2))
    (hK : Fintype.card K = gP ^ 2) (hk20 : k ≤ 2 ^ 20) (hS : 2 * S + 2 ≤ 2 ^ 20) :
    RbrWide (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).R.n (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).R.w
        (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).St (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).ε
      ∧ (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).ε ≤ (2⁻¹ : ℝ≥0∞) ^ 106
      ∧ ((maskCSubX U eF dom ω S a xOf eR (fun _ => False)).R.n : ℝ≥0∞)
          * (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).ε ≤ (3 : ℕ) * (2⁻¹ : ℝ≥0∞) ^ 106
      ∧ ∀ τ, ¬ (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).rel τ := by
  have hε : (maskCSubX U eF dom ω S a xOf eR (fun _ => False)).ε ≤ (2⁻¹ : ℝ≥0∞) ^ 106 :=
    maskEps_le (K := K) hK hk20 hS
  refine ⟨maskCSubX_rbr U eF dom hω hk S a xOf eR _, hε, ?_, fun _ h => h⟩
  show ((3 : ℕ) : ℝ≥0∞) * _ ≤ _
  exact mul_le_mul' le_rfl hε

end Readers

section Openings

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ}

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **The openings' `opA` at two logs agrees on the chain** when the extracted matrices agree on its header. -/
theorem agreeOn_opACSub (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux Ux' : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) (W : UInt64 → ℕ)
    (τ : List (TItem × Dig)) (hU : Ux (τ.take aA) = Ux' (τ.take aA)) :
    AgreeOn W τ (opACSub enc e clOf Ux d₀ w0 chalLR aA εA) (opACSub enc e clOf Ux' d₀ w0 chalLR aA εA) := by
  unfold opACSub
  exact agreeOn_toCSub _ _ _ _ _ _ _ _ W τ (by simp only [hU])

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **The openings' `opB` at two logs agrees on the chain** when the extracted matrices agree on `opA`'s header. -/
theorem agreeOn_opBCSub (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux Ux' : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ : List (TItem × Dig)) (hU : Ux ((τ.take aB).take aA) = Ux' ((τ.take aB).take aA)) :
    AgreeOn W τ (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB)
      (opBCSub W aA w0 enc e clOf Ux' vOf d₀ chalLR m chalJ labB decB aB εB) := by
  unfold opBCSub
  exact agreeOn_toCSub _ _ _ _ _ _ _ _ W τ (by simp only [hU])

end Openings

/-! ## The stages' single challenges -/

section Chal

variable {K : Type} [Field K] [Algebra GF K]

/-- **A stage's single challenge at two logs agrees on the chain** (L15's `chalSub`: LogUp's `α`, the hosts' `ν`, the
pads' `ζ`) when its good and bad predicates agree on its header. -/
theorem agreeOn_chalSub (U : K) (a : ℕ) (Good Good' : List (TItem × Dig) → Prop)
    (Bad Bad' : List (TItem × Dig) → K → Prop) (Bn : ℕ) (W : UInt64 → ℕ) (τ : List (TItem × Dig))
    (hG : Good (τ.take a) ↔ Good' (τ.take a)) (hB : ∀ x, Bad (τ.take a) x ↔ Bad' (τ.take a) x) :
    AgreeOn W τ (Exec.StageFS.chalSub U a Good Bad Bn) (Exec.StageFS.chalSub U a Good' Bad' Bn) := by
  refine agreeOn_of_st W τ _ _ rfl rfl (fun τr => ?_) Iff.rfl
  show Exec.StageFS.chalSt Good Bad (τ.take a) _ ↔ Exec.StageFS.chalSt Good' Bad' (τ.take a) _
  unfold Exec.StageFS.chalSt
  simp only [hG, hB]

variable [Fintype K] [DecidableEq K]

/-- **A stage's single challenge's other premises** (L15): round-by-round sound (`chalSub_rbr`), one round, its error
`B·fibC/|Dig|`, never released: a squeeze-run kind's `SqForm` with `emax ≥ B` and `ND ≥ B`. -/
theorem chalSub_facts (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (a : ℕ)
    (Good : List (TItem × Dig) → Prop) (Bad : List (TItem × Dig) → K → Prop) (Bn : ℕ)
    (hBn : ∀ x, ¬ Good x → EscapesWithin (Bad x) Bn) (emax ND : ℕ) (he : Bn ≤ emax) (hnd : Bn ≤ ND) :
    RbrWide (Exec.StageFS.chalSub U a Good Bad Bn).R.n (Exec.StageFS.chalSub U a Good Bad Bn).R.w
        (Exec.StageFS.chalSub U a Good Bad Bn).St (Exec.StageFS.chalSub U a Good Bad Bn).ε
      ∧ (Exec.StageFS.chalSub U a Good Bad Bn).ε ≤ ((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ ((Exec.StageFS.chalSub U a Good Bad Bn).R.n : ℝ≥0∞) * (Exec.StageFS.chalSub U a Good Bad Bn).ε
          ≤ ((ND * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ∧ ∀ τ, ¬ (Exec.StageFS.chalSub U a Good Bad Bn).rel τ := by
  refine ⟨Exec.StageFS.chalSub_rbr U hbij a Good Bad Bn hBn, ?_, ?_, fun _ h => h⟩
  · show ((Bn * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ _
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ he)) _
  · show ((1 : ℕ) : ℝ≥0∞) * (((Bn * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig) ≤ _
    rw [Nat.cast_one, one_mul]
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ hnd)) _

end Chal

end ZK60.ProtocolClassify
