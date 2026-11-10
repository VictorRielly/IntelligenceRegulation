/-
D63 lane L46 (2026-11-10), part 1: **the block cover `hdblk` on the run's transcript, through L27's `block_doom_r13`**
(L39 §5 item 7, finding L39-2: not through the per-block probability statements).

A sub-protocol "enters its window doomed" (`EntD`) when, at its window, the transcript is at a step's end and its
state on the header is false. For the run's squeeze kinds (the define draws, LogUp; L21's single-step parse `W1`) every
position is a step's end (`tRem_W1`), so a doomed entrant is a squeeze run whose header state is false
(`rd_entD_sq`). The block's case analysis then needs no probability:

* **`rd_ksq_cs`**, **`rd_some_sq`**: a squeeze kind's part lists the part's squeeze runs; a squeeze run of a part's
  define or LogUp list whose header state is false is a doomed entrant of `rtKo` in that part (the conclusion `RcSome`
  of the covers, L39);
* **`rd_rootsAt_take`**, **`rd_absAt_take`**: the roots a header shows are the transcript's;
* **`rd_defSq_doom`**: L21's define draw `defSq` of a slot whose start claim `Gd` fails is doomed at entry (its state is
  Schwartz–Zippel's `Φ ≡ 0`, and `Φ ≡ 0` gives `Gd`);
* **`rd_lkSq_doom`**: L21's LogUp run `lkSq` is doomed at entry when a looked-up tuple is outside the table (its state
  before `β` is "every lookup is a table entry");
* **`rd_def_some`**, **`rd_lu_some`**: the two on the run's transcript, at a part's lists;
* **`rd_r13_notGd`**: L36's algebra at R13: if `R13Rels` fails on the extracted planes, some slot of one of the four
  relation layers has a false start claim (`r13Rels_of_algGood` with `R13Spec`, `algGood_of_gd`);
* **`rd_blk_doom`**: THE BLOCK'S DOOM AT ONE OUTCOME: L27's `block_doom_r13` with its four links. `h1`, `h2` are
  vacuous here (the openings' and the claimed sums' links belong to the alive side, `halive`, where L28's `hsem` and the
  slots' final checks enter); `h3` through `rd_r13_notGd` and the define draws; `h4` through L36's `hbr_r13_of_cover`
  and LogUp; the planes `Xin`, `Xout` are the block's extracted ones when the boundary slots `SC_IO_IN`, `SC_IO_OUT`
  hold their start claims (`hIO`), else their define draws are doomed. Every doom lies in block `k`'s own part `k + 1`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunCoverPRk
import ZK60Formal.BlockAlgLkR13
import ZK60Formal.BlockAlgFinal

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic)
open ZK60.Exec.Block (defSq tHistD defPos lkSq AlgShape AlgData algSp algGood_of_gd w16r2DR w16r2RelKs SchedGd
  DefSched histOf SlotRec Hist R13Spec r13Rels_of_algGood hbr_r13_of_cover tupK R13Query rootsAt cuts3 cutO absAt
  Cuts3 RootsO W16Pos)
open ZK60.Layout (W16Layout W16Pub)
open ZK60.Layout.R13 (R13Data R13Rels R13Lookups R13Windows)

/-! ## The squeeze kinds' parts and their doomed entrants -/

section Sq

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **A squeeze kind's part `i` lists the part's squeeze runs** at the log. -/
theorem rd_ksq_cs (emax ND : ℕ) (sxs : ℕ → List (SqX K Lq))
    (hsx : RtSqOk (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf emax ND sxs) (i : ℕ)
    (hi : i < pf.parts.length) (P : List (QB Lq × Dig)) :
    (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij emax ND sxs hsx).cs i P = (sxs i).map (fun sx => sqSub U sx P) := by
  unfold rtKsq rtKind1
  simp only [hi, ↓reduceDIte]
  rfl

omit [Fintype K] [DecidableEq K] in
/-- **A squeeze run whose header state is false enters its window doomed** on the single-step parse (every position is
a step's end there, `tRem_W1`). -/
theorem rd_entD_sq (sx : SqX K Lq) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (ha : sx.a ≤ τ.length)
    (hn : ¬ sx.St lg (τ.take sx.a) []) : EntD W1 (sqSub U sx lg) τ :=
  ⟨ha, tRem_W1 _, hn⟩

variable (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **A squeeze run of part `i`'s define or LogUp lists with a false header state is a doomed entrant of the run's
kinds** (`RcSome`, L39's some-part form, here at part `i` itself). -/
theorem rd_some_sq (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (sx : SqX K Lq)
    (hsx : sx ∈ D.r0 i ∨ sx ∈ D.r1 i ∨ sx ∈ D.h0 i ∨ sx ∈ D.h1 i ∨ sx ∈ D.lu i)
    (ha : sx.a ≤ τ.length) (hn : ¬ sx.St lg (τ.take sx.a) []) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have he := rd_entD_sq Lq U sx lg τ ha hn
  rcases hsx with h | h | h | h | h
  · refine ⟨rtKR0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin, sqSub U sx lg, ?_, he⟩
    · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        List.mem_cons_self)))
    · show sqSub U sx lg ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r0 hD.r0).cs i lg
      rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
      exact List.mem_map_of_mem h
  · refine ⟨rtKR1 key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin, sqSub U sx lg, ?_, he⟩
    · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        (List.mem_cons_of_mem _ List.mem_cons_self))))
    · show sqSub U sx lg ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.r1 hD.r1).cs i lg
      rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
      exact List.mem_map_of_mem h
  · refine ⟨rtKH0 key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin, sqSub U sx lg, ?_, he⟩
    · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self)))))
    · show sqSub U sx lg ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h0 hD.h0).cs i lg
      rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
      exact List.mem_map_of_mem h
  · refine ⟨rtKH1 key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin, sqSub U sx lg, ?_, he⟩
    · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self))))))
    · show sqSub U sx lg ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij 80 (80 * 451) D.h1 hD.h1).cs i lg
      rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
      exact List.mem_map_of_mem h
  · refine ⟨rtKLU key domain hs Lq hL pf rd hL64 hv U hbij D hD, ?_, i, hin, sqSub U sx lg, ?_, he⟩
    · exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
        (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _ (List.mem_cons_of_mem _
          List.mem_cons_self)))))))
    · show sqSub U sx lg ∈ (rtKsq key domain hs Lq hL pf rd hL64 hv U hbij D.eL (3 * D.eL) D.lu hD.lu).cs i lg
      rw [rd_ksq_cs key domain hs Lq hL pf rd hL64 hv U hbij _ _ _ _ i hi]
      exact List.mem_map_of_mem h

end Sq

/-! ## The block's define draws and LogUp, doomed at entry -/

section Entry

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- A header longer than `i` shows the transcript's absorb at `i`. -/
theorem rd_absAt_take (τ : List (TItem × Dig)) (a i : ℕ) (h : i < a) : absAt (τ.take a) i = absAt τ i := by
  unfold absAt
  rw [List.getElem?_take_of_lt h]

/-- **The roots a header shows are the transcript's** once the header passes the three root absorbs. -/
theorem rd_rootsAt_take (τ : List (TItem × Dig)) (hdrLen a : ℕ) (h : hdrLen + 8 ≤ a) :
    rootsAt hdrLen (τ.take a) = rootsAt hdrLen τ := by
  unfold rootsAt
  rw [rd_absAt_take τ a hdrLen (by omega), rd_absAt_take τ a (hdrLen + 3) (by omega),
    rd_absAt_take τ a (hdrLen + 7) (by omega)]

omit [Algebra GF K] in
/-- **L21's define draw of a slot with a false start claim is doomed at entry**: its state before any challenge is
`Φ ≡ 0` of the slot's polynomial on the history the header shows, and `Φ ≡ 0` gives the start claim (`hΦ`, a
certified polynomial's `SlotPoly.hΦ`). -/
theorem rd_defSq_doom {P : ZK60.Exec.Block.BlockParams} {hdrLen : ℕ} {absOf : QB Lq → Option (List UInt8)}
    {Φ : Cuts3 Lq → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K} {dg : ℕ → ℕ} {k : ℕ}
    (Gd : Cuts3 Lq → RootsO → ℕ → Hist → Prop) (hΦ : ∀ cu rt h, (∀ y, Φ cu rt k h y = 0) → Gd cu rt k h)
    (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig)) (h : Hist) (rest : List (TItem × Dig))
    (hh : tHistD P hdrLen k hdr = some (h, rest))
    (hg : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen hdr)) (rootsAt hdrLen hdr) k h) :
    ¬ (defSq P hdrLen absOf Φ dg k).St lg hdr [] := by
  intro hst
  unfold defSq at hst
  simp only [hh] at hst
  exact hg (hΦ _ _ _ ((szSt_nil _).mp hst))

omit [Algebra GF K] in
/-- **L21's LogUp run is doomed at entry when a looked-up tuple is outside the table**: its state before `β` is "every
lookup is a table entry". -/
theorem rd_lkSq_doom [DecidableEq K] {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (hdrLen : ℕ)
    (absOf : QB Lq → Option (List UInt8)) (Alk : List (QB Lq × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB Lq × Dig) → κ → K) (lg : List (QB Lq × Dig)) (hdr : List (TItem × Dig))
    (h : ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt hdr hdrLen) lg) l) :
    ¬ (lkSq hdrLen absOf Alk T mlk).St lg hdr [] := by
  obtain ⟨l, hl⟩ := h
  intro hst
  obtain ⟨j, hj⟩ := hst l
  exact hl j hj

end Entry

/-! ## The two dooms on the run's transcript -/

section RunEntry

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **A slot of part `i`'s define lists with a false start claim is a doomed entrant of the run's kinds**: the define
draw `defSq` of slot `s` (block header length `hdrLen`) is in one of part `i`'s four define lists, its window is on the
transcript, and the transcript before it reads as the history `h` (`tHistD`); its start claim `Gd` fails on the cuts at
the roots the transcript shows. -/
theorem rd_def_some (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) {P : ZK60.Exec.Block.BlockParams} {hdrLen : ℕ} {absOf : QB Lq → Option (List UInt8)}
    (Φ : Cuts3 Lq → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (s : ℕ)
    (Gd : Cuts3 Lq → RootsO → ℕ → Hist → Prop) (hΦ : ∀ cu rt h, (∀ y, Φ cu rt s h y = 0) → Gd cu rt s h)
    (hmem : defSq P hdrLen absOf Φ dg s ∈ D.r0 i ∨ defSq P hdrLen absOf Φ dg s ∈ D.r1 i
      ∨ defSq P hdrLen absOf Φ dg s ∈ D.h0 i ∨ defSq P hdrLen absOf Φ dg s ∈ D.h1 i)
    (hlen : defPos P hdrLen s ≤ τ.length) (h : Hist) (rest : List (TItem × Dig))
    (hh : tHistD P hdrLen s (τ.take (defPos P hdrLen s)) = some (h, rest))
    (hg : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) s h) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hr : rootsAt hdrLen (τ.take (defPos P hdrLen s)) = rootsAt hdrLen τ :=
    rd_rootsAt_take τ hdrLen _ (by unfold defPos; omega)
  have hg' : ¬ Gd (cuts3 absOf lg (rootsAt hdrLen (τ.take (defPos P hdrLen s))))
      (rootsAt hdrLen (τ.take (defPos P hdrLen s))) s h := by
    rw [hr]
    exact hg
  have hn : ¬ (defSq P hdrLen absOf Φ dg s).St lg (τ.take (defPos P hdrLen s)) [] :=
    rd_defSq_doom (dg := dg) Gd hΦ lg _ h rest hh hg'
  refine rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ _ ?_ hlen hn
  rcases hmem with h' | h' | h' | h'
  · exact Or.inl h'
  · exact Or.inr (Or.inl h')
  · exact Or.inr (Or.inr (Or.inl h'))
  · exact Or.inr (Or.inr (Or.inr (Or.inl h')))

/-- **LogUp of part `i` with a looked-up tuple outside the table is a doomed entrant of the run's kinds**: L21's `lkSq`
(block header length `hdrLen`) is in part `i`'s LogUp list, its window is on the transcript, and some lookup read off
the cut at the `A` root the transcript shows is no table entry. -/
theorem rd_lu_some {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ] (n i : ℕ) (hi : i < pf.parts.length)
    (hin : i < n) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) (hdrLen : ℕ)
    (absOf : QB Lq → Option (List UInt8)) (Alk : List (QB Lq × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K)
    (mlk : List (QB Lq × Dig) → κ → K) (hmem : lkSq hdrLen absOf Alk T mlk ∈ D.lu i)
    (hlen : hdrLen + 4 ≤ τ.length) (hout : ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt τ hdrLen) lg) l) :
    RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  have hn : ¬ (lkSq hdrLen absOf Alk T mlk).St lg (τ.take (lkSq hdrLen absOf Alk T mlk).a) [] := by
    refine rd_lkSq_doom hdrLen absOf Alk T mlk lg _ ?_
    show ∃ l, ∀ j, T j ≠ Alk (cutO absOf (absAt (τ.take (hdrLen + 4)) hdrLen) lg) l
    rw [rd_absAt_take τ (hdrLen + 4) hdrLen (by omega)]
    exact hout
  exact rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n i hi hin lg τ _
    (Or.inr (Or.inr (Or.inr (Or.inr hmem)))) hlen hn

end RunEntry

/-! ## L36's algebra at R13: a failing `R13Rels` is a false start claim -/

section Alg

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}
variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] {ls : ℕ}

/-- **A failing `R13Rels` on the extracted planes is a false start claim of a relation layer**: by L36's reindexing
(`r13Rels_of_algGood`, from `R13Spec` and the two axes that do not pad) and `algGood_of_gd`, if every slot of the four
relation layers held its start claim at the outcome's history, `R13Rels` would hold. -/
theorem rd_r13_notGd (U : K) {P : ZK60.Exec.Block.BlockParams} (sh : AlgShape P) (dt : AlgData K Lq sh)
    (hcard : 78 < Fintype.card K) (Pb : BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay)
    (xtE : Cuts3 Lq → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls)
    (enc : (k : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf) (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb) (cu : Cuts3 Lq) (rt : RootsO)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (hn : ¬ R13Rels S Pb Lay B (xtE cu rt)) :
    ∃ i, i < 4 ∧ ∃ s ∈ w16r2RelKs i,
      ¬ (algSp U sh dt hcard i cu rt s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))).Gd := by
  by_contra hc
  apply hn
  refine r13Rels_of_algGood sh dt Pb Lay B xtE enc encHt hspec hTok hHd cu rt bga
    (algGood_of_gd U sh dt hcard cu rt bga rs ?_)
  intro i hi s hs
  by_contra hgs
  exact hc ⟨i, hi, s, hs, hgs⟩

end Alg

/-! ## The block's doom at one outcome -/

section Blk

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **A slot's define draw sits in part `i` of the run** at its run position: `sx` is in one of part `i`'s four define
lists, its window `defPos P hdrLen s` is on the transcript, and the transcript before it reads as `define`'s history
of the outcome's LogUp challenges `bga` and slot records `rs` (L21's `tHistD`; on the verifier's own trace this is
L21's `tHistD_trace`). -/
def RdDefAt {Lq : ℕ} (D : RtKData K Lq) (i : ℕ) (τ : List (TItem × Dig)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (sx : SqX K Lq) (P : ZK60.Exec.Block.BlockParams) (hdrLen s : ℕ) : Prop :=
  (sx ∈ D.r0 i ∨ sx ∈ D.r1 i ∨ sx ∈ D.h0 i ∨ sx ∈ D.h1 i) ∧ defPos P hdrLen s ≤ τ.length
    ∧ ∃ rest, tHistD P hdrLen s (τ.take (defPos P hdrLen s)) = some (histOf bga.1 bga.2.1 bga.2.2 (rs.take s), rest)

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **BLOCK `k`'S DOOM ON THE RUN'S TRANSCRIPT, AT ONE OUTCOME** (L27's `block_doom_r13`, its links discharged as far as
the block's objects allow). Block `k` is part `k + 1` of the run. Given, at the outcome (the prover's log `lg`, the
run's transcript `τ`):
* block `k`'s R13 objects (layout `Lay`, gates `B`, windows `hWr`, the extracted planes `xtE` at the cuts the
  transcript shows, L36's `R13Spec` with the two axes that do not pad: L36 / L47's premises in L36's form);
* the relation layers' define draws in part `k + 1` (`hdefR`), with the history the transcript shows;
* the boundary slots `SC_IO_IN`, `SC_IO_OUT` as a define schedule `DIO` in part `k + 1` (`hdefIO`), whose start claims
  make the run's planes `Xin`, `Xout` the block's extracted `X`, `X2` (`hIO`);
* LogUp in part `k + 1` (`hlu`), with L36's `hTtab` and `hcov` (L47's premises in L36's form);
`BlockOn` failing on `Xin`, `Xout` gives a doomed entrant of the run's kinds in part `k + 1`: a boundary slot's or a
relation slot's define draw (a false start claim), or LogUp (a lookup outside the table). -/
theorem rd_blk_doom (n k : ℕ) (hi : k + 1 < pf.parts.length) (hn : k + 1 < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (absOf : QB Lq → Option (List UInt8))
    {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
    [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
    [DecidableEq Cf] {ls : ℕ}
    (Pb : BlockPublic S) (Lay : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S Pb Lay) (hWr : R13Windows S ls)
    (h24 : S.h24 = true) (P : ZK60.Exec.Block.BlockParams) (hdrLen : ℕ) (sh : AlgShape P) (dt : AlgData K Lq sh)
    (hcard : 78 < Fintype.card K) (xtE : Cuts3 Lq → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls)
    (enc : (k : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf) (hspec : R13Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hdefR : ∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
      RdDefAt D (k + 1) τ bga rs (defSq P hdrLen absOf (w16r2DR P (algSp U sh dt hcard) i).Φ (fun _ => 80) s)
        P hdrLen s)
    (DIO : DefSched K Lq P)
    (hIOΦ : ∀ cu rt s h, s ∈ DIO.ks → (∀ y, DIO.Φ cu rt s h y = 0) → DIO.Gd cu rt s h)
    (hdefIO : ∀ s ∈ DIO.ks, RdDefAt D (k + 1) τ bga rs (defSq P hdrLen absOf DIO.Φ DIO.dg s) P hdrLen s)
    (Xin Xout : S.Pos → GF)
    (hIO : (∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) s
        (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))) →
      Xin = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X (Lay.dPos p))
        ∧ Xout = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X2 (Lay.dPos p)))
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB Lq × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB Lq × Dig) → κ → K)
    (hlu : lkSq hdrLen absOf Alk T mlk ∈ D.lu (k + 1)) (hlen : hdrLen + 4 ≤ τ.length)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ q, R13Query Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) q →
      ∃ l, Alk (cutO absOf (absAt τ hdrLen) lg) l = tupK q) :
    ¬ BlockOn Pb Xin Xout → RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  intro hno
  by_cases hio : ∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) s
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))
  · obtain ⟨hin, hout⟩ := hIO hio
    refine block_doom_r13 Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) hWr h24 Xin Xout
      hin hout (Op := True) (Cl := True) (fun h => absurd trivial h) (fun _ h => absurd trivial h) ?_ ?_ hno
    · intro _ _ hrel
      obtain ⟨j, hj, s, hs', hg⟩ := rd_r13_notGd U sh dt hcard Pb Lay B xtE enc encHt hspec hTok hHd
        (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) bga rs hrel
      obtain ⟨hmem, hl, rest, hh⟩ := hdefR j hj s hs'
      exact rd_def_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ
        (w16r2DR P (algSp U sh dt hcard) j).Φ (fun _ => 80) s (w16r2DR P (algSp U sh dt hcard) j).Gd
        (fun cu' rt' h' hy => (algSp U sh dt hcard j cu' rt' s h').hΦ hy) hmem hl _ rest hh hg
    · intro _ _ _ hlk
      exact rd_lu_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ hdrLen absOf Alk T mlk
        hlu hlen (hbr_r13_of_cover (Alk (cutO absOf (absAt τ hdrLen) lg)) T hTtab hcov hlk)
  · obtain ⟨s, hs', hg⟩ : ∃ s ∈ DIO.ks, ¬ DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) s
        (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) := by
      by_contra hc
      exact hio (fun s hs' => by
        by_contra hg
        exact hc ⟨s, hs', hg⟩)
    obtain ⟨hmem, hl, rest, hh⟩ := hdefIO s hs'
    exact rd_def_some key domain hs Lq hL pf rd hL64 hv U hbij D hD n (k + 1) hi hn lg τ DIO.Φ DIO.dg s DIO.Gd
      (fun cu' rt' h' hy => hIOΦ cu' rt' s h' hs' hy) hmem hl _ rest hh hg

end Blk

/-! ## Block `k`'s objects and links as one object, and `hdblk` -/

section Hdblk

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **Block `k`'s R13 objects and links at one outcome**: the premises of `rd_blk_doom` bundled, with the block's layout
types and LogUp's index types as fields (at the per-block-shape model they differ from block to block). Part `k + 1`
of the run is block `k`. The fields, by kind:
* the block's R13 objects: `Lay`, `B`, `hWr`, `h24`, the block profile `P`, its run position `hdrLen`, L36's `sh`, `dt`,
  the extracted planes `xtE`, the encodings and `hspec` (`R13Spec`), `hTok`, `hHd`;
* the outcome's reading: the LogUp challenges `bga` and slot records `rs` the transcript shows;
* the run's lists: `hdefR` (the four relation layers' define draws in part `k + 1`), `DIO`, `hIOΦ`, `hdefIO`, `hIO` (the
  boundary slots' define draws, and their start claims making the run's planes the block's), `hlu`, `hlen` (LogUp);
* the lookup side: `Alk`, `T`, `mlk`, `hTtab`, `hcov` (L36's form). -/
structure RdBlkR13 {Lq : ℕ} (U : K) (D : RtKData K Lq) (k : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K) {S : BlockShape} (Pb : BlockPublic S)
    (Xin Xout : S.Pos → GF) : Type 1 where
  Ct : Type
  Cw : Type
  Cg : Type
  Cj : Type
  Cd : Type
  Cf : Type
  [fCt : Fintype Ct]
  [fCw : Fintype Cw]
  [fCg : Fintype Cg]
  [fCj : Fintype Cj]
  [fCd : Fintype Cd]
  [fCf : Fintype Cf]
  [dCt : DecidableEq Ct]
  [dCw : DecidableEq Cw]
  [dCg : DecidableEq Cg]
  [dCj : DecidableEq Cj]
  [dCd : DecidableEq Cd]
  [dCf : DecidableEq Cf]
  ls : ℕ
  Lay : W16Layout S Ct Cw Cg Cj Cd Cf
  B : W16Pub S Pb Lay
  hWr : R13Windows S ls
  h24 : S.h24 = true
  P : ZK60.Exec.Block.BlockParams
  hdrLen : ℕ
  sh : AlgShape P
  dt : AlgData K Lq sh
  xtE : Cuts3 Lq → RootsO → R13Data Ct Cw Cg Cj Cd Cf ls
  enc : (j : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl j) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf
  encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf
  hspec : R13Spec sh dt Pb Lay B xtE enc encHt
  hTok : Function.Surjective Lay.tok.emb
  hHd : Function.Surjective Lay.hd.emb
  bga : Fp2 × Fp2 × Fp2
  rs : List SlotRec
  hdefR : ∀ i, i < 4 → ∀ s ∈ w16r2RelKs i,
    RdDefAt D (k + 1) τ bga rs (defSq P hdrLen absOf (w16r2DR P (algSp U sh dt hcard) i).Φ (fun _ => 80) s)
      P hdrLen s
  DIO : DefSched K Lq P
  hIOΦ : ∀ cu rt s h, s ∈ DIO.ks → (∀ y, DIO.Φ cu rt s h y = 0) → DIO.Gd cu rt s h
  hdefIO : ∀ s ∈ DIO.ks, RdDefAt D (k + 1) τ bga rs (defSq P hdrLen absOf DIO.Φ DIO.dg s) P hdrLen s
  hIO : (∀ s ∈ DIO.ks, DIO.Gd (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) s
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take s))) →
    Xin = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X (Lay.dPos p))
      ∧ Xout = (fun p => (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)).X2 (Lay.dPos p))
  ι : Type
  π : Type
  κ : Type
  [fι : Fintype ι]
  [fπ : Fintype π]
  [fκ : Fintype κ]
  Alk : List (QB Lq × Dig) → ι ⊕ (π ⊕ π) → Tup K
  T : κ → Tup K
  mlk : List (QB Lq × Dig) → κ → K
  hlu : lkSq hdrLen absOf Alk T mlk ∈ D.lu (k + 1)
  hlen : hdrLen + 4 ≤ τ.length
  hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable ZK60.Layout.R13.r13Fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0
  hcov : ∀ q, R13Query Pb Lay B (xtE (cuts3 absOf lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ)) q →
    ∃ l, Alk (cutO absOf (absAt τ hdrLen) lg) l = tupK q

attribute [local instance] RdBlkR13.fCt RdBlkR13.fCw RdBlkR13.fCg RdBlkR13.fCj RdBlkR13.fCd RdBlkR13.fCf
  RdBlkR13.dCt RdBlkR13.dCw RdBlkR13.dCg RdBlkR13.dCj RdBlkR13.dCd RdBlkR13.dCf RdBlkR13.fι RdBlkR13.fπ RdBlkR13.fκ

variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **Block `k`'s doom from its bundle** (`rd_blk_doom`). -/
theorem rd_blk_doom_of (n k : ℕ) (hi : k + 1 < pf.parts.length) (hn : k + 1 < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K) {S : BlockShape}
    (Pb : BlockPublic S) (Xin Xout : S.Pos → GF) (bd : RdBlkR13 U D k lg τ absOf hcard Pb Xin Xout) :
    ¬ BlockOn Pb Xin Xout → RcSome (rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD) n lg τ := by
  exact rd_blk_doom key domain hs Lq hL pf rd hL64 hv U hbij D hD n k hi hn lg τ absOf Pb bd.Lay bd.B bd.hWr bd.h24
    bd.P bd.hdrLen bd.sh bd.dt hcard bd.xtE bd.enc bd.encHt bd.hspec bd.hTok bd.hHd bd.bga bd.rs bd.hdefR bd.DIO
    bd.hIOΦ bd.hdefIO Xin Xout bd.hIO bd.Alk bd.T bd.mlk bd.hlu bd.hlen bd.hTtab bd.hcov

open ZK60.RunShape (ClassifyRunPublicP) in
/-- **`hdblk` OF THE APP'S TOP THEOREM, at the per-block-shape model** (deliverable 1). For any acceptance event `Acc`
(at the app: the run verifier accepts and the run's Merkle extraction did not fail) and any extracted boundary planes
`pl` (at the app: the run extractor's `planes`), if on every accepted outcome every block `k` has its bundle at its own
shape `Rp.blks[k]` (`hlink`), then block `k`'s `BlockOn` failing gives a doomed entrant of the run's kinds: exactly the
premise `hdblk` of `rc_productionReadyL_r13P_exec_rk`, in its unfolded some-part form. -/
theorem rd_hdblk {S : BlockShape} (Rp : ClassifyRunPublicP S) (hnp : pf.parts.length = Rp.blks.length + 2)
    (absOf : QB Lq → Option (List UInt8)) (hcard : 78 < Fintype.card K)
    (Acc : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop) (pl : OC (QB Lq) Dig α → (QB Lq → Dig) → ℕ → S.Pos → GF)
    (hlink : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length), Acc A G →
      Nonempty (RdBlkR13 U D k (A.runLog G).2 (rtTr key domain Lq pf rd G (A.run G)) absOf hcard Rp.blks[k].pub
        (pl A G k) (pl A G (k + 1)))) :
    ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig) (k : ℕ) (hk : k < Rp.blks.length), Acc A G →
      ¬ BlockOn Rp.blks[k].pub (pl A G k) (pl A G (k + 1)) →
      ∃ K' ∈ rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD, ∃ i, i < Rp.blks.length + 2
        ∧ ∃ c ∈ K'.cs i (A.runLog G).2, EntD K'.RC.W c (rtTr key domain Lq pf rd G (A.run G)) := by
  intro A G k hk hacc hno
  obtain ⟨bd⟩ := hlink A G k hk hacc
  exact rd_blk_doom_of key domain hs Lq hL pf rd hL64 hv U hbij D hD (Rp.blks.length + 2) k (by omega) (by omega)
    _ _ absOf hcard _ _ _ bd hno

/-- **A cover from squeeze runs** (the form `hdin`, `hdout` and `hdzero` reduce to; deliverables 2 and 3): if on
every outcome of an event `Acc` where a conclusion `Bad` fails, some part `j` of the run has a squeeze run in its define
or LogUp lists whose window is on the transcript and whose header state is false, then that is a doomed entrant of
the run's kinds in the cover's form (`∃ K' ∈ rtKo …, K'.Dm …` is the same statement). -/
theorem rd_cover_of_sq (n : ℕ) (Acc Bad : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop)
    (hsq : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Acc A G → Bad A G →
      ∃ j, j < pf.parts.length ∧ j < n ∧ ∃ sx : SqX K Lq,
        (sx ∈ D.r0 j ∨ sx ∈ D.r1 j ∨ sx ∈ D.h0 j ∨ sx ∈ D.h1 j ∨ sx ∈ D.lu j)
        ∧ sx.a ≤ (rtTr key domain Lq pf rd G (A.run G)).length
        ∧ ¬ sx.St (A.runLog G).2 ((rtTr key domain Lq pf rd G (A.run G)).take sx.a) []) :
    ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Acc A G → Bad A G →
      ∃ K' ∈ rtKo key domain hs Lq hL pf rd hL64 hv U hbij D hD,
        K'.Dm n (A.runLog G).2 (rtTr key domain Lq pf rd G (A.run G)) := by
  intro A G hacc hbad
  obtain ⟨j, hj, hjn, sx, hmem, ha, hst⟩ := hsq A G hacc hbad
  exact rd_some_sq key domain hs Lq hL pf rd hL64 hv U hbij D hD n j hj hjn _ _ sx hmem ha hst

end Hdblk

end ZK60.ProtocolClassify
