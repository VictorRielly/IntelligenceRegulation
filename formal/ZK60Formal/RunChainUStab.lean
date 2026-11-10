/-
D63 lane L30 (2026-11-09), part 3: **the input endpoint's column test on the run's ONE transcript** (L26's `xKindA`
and `xKindB` with L27's machinery): its two kinds read the run's transcript through a parse of it (`RunChain`), and
L26's stability premises `StabU` are THEOREMS for every extraction that reads the prover's log through cuts.

* `RunChain.toChainU`: L27's parse of the run's transcript as L26's chain data (`ChainU`);
* `CutReads`, `cutReads_of_cut`, `CutReads.comp`: a reader of the prover's log and a header that reads the log only
  through the cuts at the roots the header absorbs (L27's `CutEq`); the extraction "cut the log at the root the header
  shows at position `i`, then read" is one;
* `agreeOn_xACSub`, `agreeOn_xBCSub`: the test's two halves at two logs agree on a chain when the extracted matrix and
  the set of columns that open agree on the first half's header (as L27's `agreeOn_opACSub`, `agreeOn_opBCSub`);
* **`stabU_cA`**, **`stabU_cB`**: L26's `StabU` (L24-2's weak stability at the escaping step) for the test's two
  halves, from `CutReads` of the matrix and of the openable set, by L27's `cutEq_esc`;
* **`xRunA`**, **`xRunB`**: L26's `xKindA`, `xKindB` on a parse of the run's transcript, with NO stability premise;
  `xRunA_ℓ`, `xRunB_ℓ`, `xRunA_lin`, `xRunB_lin`: their chain bound and their linear parts (L26's `xKindA_lin`,
  `xKindB_lin`);
* **`xRun_cover`**: L26's `xKinds_cover` stated on the run's transcript `tr`: the test's chain event on `tr` lies in
  one of the two kinds;
* **`xlink_of_read`**: the test's chain event from its pieces: the windows at steps' ends, the second half alive at
  the end, the test's matrix and openable set at its window being the run extractor's (embedded in the extension
  field), and the BASE-FIELD matrix not close inside the columns that open. The step from the base field to the
  extension field is `BindingUCode.lean`'s `closeIn_enc_ext` (finding L26-3, now a theorem).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainKinds
import ZK60Formal.ProtocolClassifyUEp
import ZK60Formal.BindingUCode

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound Code
open ZK60.Circuit (gP GF)

/-! ## The run's parse as L26's chain data, and cut readers -/

section Chain

variable {Lq : ℕ} {α : Type}

/-- **L27's parse of the run's transcript as L26's chain data**: the same encoding, step parse, steps, heads and
bounds. -/
noncomputable def RunChain.toChainU (RC : RunChain Lq α) : ChainU Lq α where
  It := ItB Lq
  W := RC.W
  hW := RC.hW
  C := RC.C
  toT := fun it => it.1
  S := RC.S
  hS := RC.hS
  heads := RC.heads
  ℓ := RC.ℓ
  hℓ := RC.hℓ
  s := RC.s
  hhd := RC.hhd

/-- Its chain is the parse's chain. -/
theorem RunChain.toChainU_chain (RC : RunChain Lq α) (G : QB Lq → Dig) (o : α) :
    RC.toChainU.chain G o = RC.chain G o :=
  rfl

/-- **A cut reader**: a function of the prover's log and a header that reads the log only through the cuts at the
roots the header absorbs (two logs cut alike at those roots give the same value). -/
def CutReads {β : Type} (absOf : QB Lq → Option (List UInt8))
    (g : List (QB Lq × Dig) → List (TItem × Dig) → β) : Prop :=
  ∀ (P P' : List (QB Lq × Dig)) (hdr : List (TItem × Dig)), CutEq absOf hdr P P' → g P hdr = g P' hdr

/-- **Reading the log cut at the root the header shows at position `i` is a cut reader** (the form of every
extraction of the code: L16's cuts, L22's `colX`). -/
theorem cutReads_of_cut {β : Type} (absOf : QB Lq → Option (List UInt8)) (i : ℕ)
    (g₀ : List (QB Lq × Dig) → List (TItem × Dig) → β) :
    CutReads absOf (fun P hdr => g₀ (Exec.Block.cutO absOf (Exec.Block.absAt hdr i) P) hdr) :=
  fun _ _ hdr h => congrArg (fun c => g₀ c hdr) (h i)

/-- A function of a cut reader is a cut reader. -/
theorem CutReads.comp {β γ : Type} {absOf : QB Lq → Option (List UInt8)}
    {g : List (QB Lq × Dig) → List (TItem × Dig) → β} (hg : CutReads absOf g) (f : β → γ) :
    CutReads absOf (fun P hdr => f (g P hdr)) :=
  fun P P' hdr h => congrArg f (hg P P' hdr h)

end Chain

/-! ## The test's two halves at two logs -/

section Agree

variable {F κ μ Cl : Type} [Field F] {h : ℕ}

/-- **The test's first half at two logs agrees on the chain** when the extracted matrices and the sets of columns
that open agree on its header. -/
theorem agreeOn_xACSub [Fintype κ] (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux Ux' : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx Xx' : List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) (W : UInt64 → ℕ)
    (τ : List (TItem × Dig)) (hU : Ux (τ.take aA) = Ux' (τ.take aA)) (hX : Xx (τ.take aA) = Xx' (τ.take aA)) :
    AgreeOn W τ (xACSub enc e Ux Xx d₀ w0 chalLR aA εA) (xACSub enc e Ux' Xx' d₀ w0 chalLR aA εA) := by
  unfold xACSub
  exact agreeOn_toCSub _ _ _ _ _ _ _ _ W τ (by simp only [hU, hX])

/-- **The test's second half at two logs agrees on the chain** when the extracted matrices and the sets of columns
that open agree on the first half's header. -/
theorem agreeOn_xBCSub [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl] [DecidableEq Cl]
    (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (Ux Ux' : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx Xx' : List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ}
    (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) (τ : List (TItem × Dig))
    (hU : Ux ((τ.take aB).take aA) = Ux' ((τ.take aB).take aA))
    (hX : Xx ((τ.take aB).take aA) = Xx' ((τ.take aB).take aA)) :
    AgreeOn W τ (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB)
      (xBCSub W aA w0 enc e Ux' Xx' d₀ chalLR m chalJ labB decB aB εB) := by
  unfold xBCSub
  exact agreeOn_toCSub _ _ _ _ _ _ _ _ W τ (by simp only [hU, hX])

end Agree

/-! ## L26's stability premises, proved for cut readers -/

section Stab

variable {Lq : ℕ} {α : Type}
variable {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
  [DecidableEq Cl] {h : ℕ}

/-- **L26's `StabU` for the test's first half** (D63 lane L30): when the extracted matrix and the set of columns that
open read the prover's log through cuts, the first half's first-doom state is the same at the log before the
escaping step and at the whole log (L27's `cutEq_esc`). -/
theorem stabU_cA (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) :
    StabU RC.toChainU (T.cA Ux Xx) := by
  intro A H L t τ qs it e2 hc _ _ hq _ ht _ ext hext τ' hτ'
  have hce : CutEq (Exec.Block.absOfC RC.C) τ' (proverLog A (L.take t)) (proverLog A L) :=
    cutEq_esc RC.C RC.S RC.hcont A H L t τ qs it e2 hc hq ht ext hext τ' hτ'
  have hce' : CutEq (Exec.Block.absOfC RC.C) (τ'.take T.aA) (proverLog A (L.take t)) (proverLog A L) :=
    cutEq_take _ τ' _ _ hce T.aA
  exact firstSt_congr RC.W τ' (List.Forall₂.cons
    (agreeOn_xACSub T.enc T.e (Ux (proverLog A (L.take t))) (Ux (proverLog A L)) (Xx (proverLog A (L.take t)))
      (Xx (proverLog A L)) T.d₀ T.w0 T.chalLR T.aA T.εA RC.W τ' (hU _ _ _ hce') (hX _ _ _ hce'))
    List.Forall₂.nil)

/-- **L26's `StabU` for the test's second half**: the same (its matrix and openable set are read at the first half's
header, a prefix of its own). -/
theorem stabU_cB (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) :
    StabU RC.toChainU (T.cB RC.toChainU.W Ux Xx) := by
  intro A H L t τ qs it e2 hc _ _ hq _ ht _ ext hext τ' hτ'
  have hce : CutEq (Exec.Block.absOfC RC.C) τ' (proverLog A (L.take t)) (proverLog A L) :=
    cutEq_esc RC.C RC.S RC.hcont A H L t τ qs it e2 hc hq ht ext hext τ' hτ'
  have hce' : CutEq (Exec.Block.absOfC RC.C) ((τ'.take T.aB).take T.aA) (proverLog A (L.take t))
      (proverLog A L) :=
    cutEq_take _ _ _ _ (cutEq_take _ τ' _ _ hce T.aB) T.aA
  exact firstSt_congr RC.W τ' (List.Forall₂.cons
    (agreeOn_xBCSub RC.W T.aA T.w0 T.enc T.e (Ux (proverLog A (L.take t))) (Ux (proverLog A L))
      (Xx (proverLog A (L.take t))) (Xx (proverLog A L)) T.d₀ T.chalLR T.m T.chalJ T.labB T.decB T.aB T.εB τ'
      (hU _ _ _ hce') (hX _ _ _ hce'))
    List.Forall₂.nil)

/-- **The column test's first half as a kind on the run's transcript** (L26's `xKindA` on L27's parse): no stability
premise; the extraction is a cut reader. -/
noncomputable def xRunA (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aA)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) : FirstKind Lq α :=
  xKindA RC.toChainU T Ux Xx hwin (stabU_cA RC T Ux Xx hU hX)

/-- **The column test's second half as a kind on the run's transcript** (L26's `xKindB` on L27's parse). -/
noncomputable def xRunB (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aB)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) : FirstKind Lq α :=
  xKindB RC.toChainU T Ux Xx hwin (stabU_cB RC T Ux Xx hU hX)

/-- The first half's chain bound is the parse's. -/
theorem xRunA_ℓ (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aA)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) :
    (xRunA RC T Ux Xx hwin hU hX).ℓ = RC.ℓ :=
  rfl

/-- The second half's chain bound is the parse's. -/
theorem xRunB_ℓ (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aB)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) :
    (xRunB RC T Ux Xx hwin hU hX).ℓ = RC.ℓ :=
  rfl

/-- The first half's linear part: `εA ≤ 2^-j` gives `≤ (q + 1)·2^(126 − j)/2^126` (L26's `xKindA_lin`). -/
theorem xRunA_lin (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aA)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) (q j : ℕ)
    (hj : j ≤ 126) (hε : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * (xRunA RC T Ux Xx hwin hU hX).εmax + (xRunA RC T Ux Xx hwin hU hX).B
      ≤ u126 q (1 * 2 ^ (126 - j)) :=
  xKindA_lin RC.toChainU T Ux Xx hwin (stabU_cA RC T Ux Xx hU hX) q j hj hε

/-- The second half's linear part (L26's `xKindB_lin`). -/
theorem xRunB_lin (RC : RunChain Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : RC.s < T.aB)
    (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx) (q j : ℕ)
    (hj : j ≤ 126) (hε : T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * (xRunB RC T Ux Xx hwin hU hX).εmax + (xRunB RC T Ux Xx hwin hU hX).B
      ≤ u126 q (1 * 2 ^ (126 - j)) :=
  xKindB_lin RC.toChainU T Ux Xx hwin (stabU_cB RC T Ux Xx hU hX) q j hj hε

/-- **The column test's chain event on the run's transcript lies in one of its two kinds** (D63 lane L30; L26's
`xKinds_cover` on L27's parse, whose chain IS the run's transcript `tr`): the first half's window at a step's end with
the matrix NOT close inside the openable set, the second half's window in the transcript at a step's end and the
second half alive at the end ⇒ the first kind's event or the second's. -/
theorem xRun_cover (RC : RunChain Lq α) (tr : (QB Lq → Dig) → α → List (TItem × Dig))
    (htr : ∀ G o, RC.chain G o = tr G o) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwA : RC.s < T.aA)
    (hwB : RC.s < T.aB) (hU : CutReads (Exec.Block.absOfC RC.C) Ux) (hX : CutReads (Exec.Block.absOfC RC.C) Xx)
    (A : OC (QB Lq) Dig α) (G : QB Lq → Dig)
    (hev : tRem RC.W ((tr G (A.run G)).take T.aA) = some 0
      ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA))
          (Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA))
      ∧ T.aB ≤ (tr G (A.run G)).length
      ∧ tRem RC.W ((tr G (A.run G)).take T.aB) = some 0
      ∧ subSt RC.W (T.cB RC.W Ux Xx (A.runLog G).2) (tr G (A.run G))) :
    (xRunA RC T Ux Xx hwA hU hX).Ev A G ∨ (xRunB RC T Ux Xx hwB hU hX).Ev A G := by
  have hch : RC.toChainU.chain G (A.run G) = tr G (A.run G) := htr G (A.run G)
  refine xKinds_cover RC.toChainU T Ux Xx hwA hwB (stabU_cA RC T Ux Xx hU hX) (stabU_cB RC T Ux Xx hU hX) A G ?_
  rw [hch]
  exact hev

end Stab

/-! ## The test's second half is alive when the endpoint opening's own second half is -/

section Alive

/-- **The test's second half alive from the opening's `opB`** (D63 lane L30). The endpoint opening is ONE opening of
the code: L20's `opB` and the test's second half read the same round (the window `aB`, the proximity vector, the index
squeezes), the same `ρ` off the header and the same extracted matrix. `opB` alive after its round says, among its
checks, that the proximity vector is consistent with `Σ ρ_i U_i` at every sampled column (`GroupsAccept`'s last
clause). So if that round is read on the transcript (`hrd`), `opB` is alive at the end (`hop`: L28's
`pcs_subSt_of_acc` on an accepted opening) and every sampled column is in the set of columns that open (`hin`: outside
the Merkle extraction failure, an accepted opened column is one the extractor reads), then the test's second half is
alive at the end: the last conjunct of the test's chain event (`xRun_cover`, `xlink_of_read`'s `hBal`). -/
theorem xB_subSt_of_opB {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ]
    [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ} (W : UInt64 → ℕ) (aA w0 : ℕ)
    (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : List (TItem × Dig) → OClaims Cl G κ μ F)
    (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (Xx : List (TItem × Dig) → Finset (Fin (2 ^ h)))
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8)
    (decB : List UInt8 → Option (μ → F)) (aB : ℕ) (εB εB' : ℝ≥0∞) (τ : List (TItem × Dig)) (x : List UInt8)
    (ds : List Dig) (pm : Option (List UInt8)) (ds' : List Dig)
    (hrd : cRd (opBRounds labB m) W (τ.drop aB) = some ([(x, ds)], pm, ds'))
    (hin : ∀ k, chalJ (vecOf d₀ m (ds.map halves)) k ∈ Xx ((τ.take aB).take aA))
    (hop : subSt W (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB') τ) :
    subSt W (xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB) τ := by
  rcases hop with h1 | ⟨htr, hl⟩ | h3
  · exact Or.inl h1
  · refine Or.inr (Or.inl ⟨htr, ?_⟩)
    have hl' : liftC ((opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB').St (τ.take aB))
        (cRd (opBRounds labB m) W (τ.drop aB)) := hl
    rw [hrd] at hl'
    have hl2 : (opARead W aA w0 (τ.take aB)).isSome = true
        ∧ ∃ wv, decB x = some wv
          ∧ GroupsAccept enc (Ux ((τ.take aB).take aA)) (clOf ((τ.take aB).take aA)).rw
              (clOf ((τ.take aB).take aA)).cw (clOf ((τ.take aB).take aA)).grp (clOf ((τ.take aB).take aA)).val
              (fun g _ _ => vOf (τ.take aB) g) (fun _ _ => wv) (opBLR W aA w0 d₀ chalLR (τ.take aB)).1
              (opBLR W aA w0 d₀ chalLR (τ.take aB)).2 (chalJ (vecOf d₀ m (ds.map halves))) := hl'
    obtain ⟨hsome, wv, hw, hacc⟩ := hl2
    show liftC ((xBCSub W aA w0 enc e Ux Xx d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB))
      (cRd (opBRounds labB m) W (τ.drop aB))
    rw [hrd]
    show (opARead W aA w0 (τ.take aB)).isSome = true
      ∧ ∃ wv, decB x = some wv
        ∧ ∀ k, chalJ (vecOf d₀ m (ds.map halves)) k ∈ Xx ((τ.take aB).take aA)
          ∧ enc wv (chalJ (vecOf d₀ m (ds.map halves)) k)
            = comb (Ux ((τ.take aB).take aA)) (opBLR W aA w0 d₀ chalLR (τ.take aB)).2
                (chalJ (vecOf d₀ m (ds.map halves)) k)
    exact ⟨hsome, wv, hw, fun k => ⟨hin k, hacc.2.2 k⟩⟩
  · exact absurd h3 id

end Alive

/-! ## The test's chain event from its pieces, with the base-field matrix -/

section Link

variable {Lq : ℕ} {K Cl : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] [Fintype Cl]
  [DecidableEq Cl] {h n Q Rr : ℕ}

/-- **The test's chain event from its pieces** (D63 lane L30; the premise of `xRun_cover`, with finding L26-3's step
a theorem). The test's code is the base code with scalars extended (`hTenc`, `hext`), its radius is `e`. On a
transcript `τ` and a prover's log `lg`: the test's matrix and openable set at its window are the run extractor's
(`hXr`, `hUr`: the columns `ops` that open, the extracted base-field matrix embedded in `K`), its two windows are at
steps' ends (`hA1`, `hB0`, `hB1`), its second half is alive at the end (`hBal`: every sampled column opens and is
consistent with the proximity vector), and the BASE-FIELD extracted matrix is NOT close inside the columns that open
(`hnc`: the hypothesis of L26's premise `hX`). Then the test's chain event holds. -/
theorem xlink_of_read (pts : Fin (2 ^ h) → GF) (form : RowForm GF n) (RK : RowForm K n)
    (hext : RowFormExt form RK) (T : XTest K (Fin Rr) (Fin (n + Q)) Cl h)
    (hTenc : T.enc = encLin (Q := Q) (fun j => algebraMap GF K (pts j)) RK) (e : ℕ) (hTe : T.e = e)
    (W : UInt64 → ℕ) (Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ h) → K)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (ops : Fin (2 ^ h) → Option (MerkleOpening Dig Dig (ColR Rr)))
    (hXr : Xx lg (τ.take T.aA) = exX ops)
    (hUr : Ux lg (τ.take T.aA) = fun i j => algebraMap GF K (exU ops i j))
    (hA1 : tRem W (τ.take T.aA) = some 0) (hB0 : T.aB ≤ τ.length) (hB1 : tRem W (τ.take T.aB) = some 0)
    (hBal : subSt W (T.cB W Ux Xx lg) τ)
    (hnc : ¬ CloseIn (LinearMap.range (encLin (Q := Q) pts form)) e (exX ops) (exU ops)) :
    tRem W (τ.take T.aA) = some 0
      ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx lg (τ.take T.aA)) (Ux lg (τ.take T.aA))
      ∧ T.aB ≤ τ.length ∧ tRem W (τ.take T.aB) = some 0 ∧ subSt W (T.cB W Ux Xx lg) τ := by
  refine ⟨hA1, ?_, hB0, hB1, hBal⟩
  rw [hXr, hUr, hTenc, hTe]
  exact fun hcl => hnc (closeIn_enc_base pts form RK hext e (exX ops) (exU ops) hcl)

end Link

end ZK60.ProtocolClassify
