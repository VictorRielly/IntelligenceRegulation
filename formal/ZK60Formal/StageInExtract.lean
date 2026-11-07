/-
D63, Lean lane L12 (2026-11-07): **stage IN and stage IN-C, the L3 part** (ASSEMBLY §4.2 item e, L1L2 findings §16):
from the stage verifier's accepted checks to `InSat` (CircuitTokenRun.lean) on the extracted data.

The code (stage_in_c.rs; stage_in.rs is the same with no template clause and no control column):
* the prover commits `B_in`, `A_in` (`A_TOK` the token words, `A_MULT` the multiplicities) and `M`, THEN the
  challenges `β, γ, α, r_emb` are drawn (`challenges`, stage_in_c.rs:254-262), THEN `H_in` (the helpers);
* the lookup tuple of position `t` is COMPRESSED: `q_t = tok_t + γ·TAG_EMB + β·x~(t, r_emb) + β²·c(t)`, with
  `x~(t, r) = Σ_i eq(r, i)·B_in(t, i)` the row's multilinear extension at `r_emb` (SIC_QZC reads `B_in` at
  `(ρ_t, r_emb)`, :201-206), and the table row `v` is `τ(v) = v + γ·TAG_EMB + β·E~(v, r_emb) + β²·ctl(v)`
  (`tau_table`, :160-164);
* the helper relations `h_q·(α − q) = 1` on the support, `h_tab·(α − τ) = m`, the pads, the BOS and template clauses
  (SIC_QZC, SIC_TZC, :188-230) and the value-0 LogUp sum (`logup_sum_claim`, with the zero-sum row SIC_ZS).

What is proved:
* **`in_lookup_sound`**: for data fixed before the challenges, over uniform `((β, γ), α)` and `r_emb`, the
  probability that SOME helpers pass every LogUp relation while some position's token word, WHOLE `B_in` row or
  control word is not a table row's is at most `((T + 4V − 1) + T·k)/|K|` (`T` positions, `V` table rows,
  `d_pad = 2^k`). Two steps: LogUp on the compressed tuples (`logup_block_bound`, over `β, γ, α`), and the
  Schwartz–Zippel step over `r_emb` that turns "the compressed tuple is the table's" into "the whole row is"
  (`row_sz_prob`, `T·k/|K|`: the run figure's `T·log d_pad`, run.rs:224-226);
* **`inCube_helperRel`**: the code's per-cube-point relations, the pads and the two sum claims give exactly
  `HelperRel` on the logical positions;
* **`in_inSat`**: the lookup's conclusion with the BOS and template clauses is `InSat`, through the stage's column
  layout map;
* `in_endpoint_words`, `canonWord`: SIC_IO's identity ties the input endpoint's words to `A_TOK` on the support (and
  to `0` on the pad words), and the extracted words are canonical (`ZMod.val`).

Modelling boundary: the per-cube-point relations are the zero-check slots' conclusions (`zc_pad_sound`,
`StageExtractCore.lean`); the sum claim is the `H` opening's (lane L10); `B_in` is the extracted boundary plane (the
same commitment block 0 opens as its input, `StageRunExtract.lean`).
-/
import ZK60Formal.StageExtractCore
import ZK60Formal.CircuitTokenRun

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

section InStage

variable {B K : Type} [Field B] [Field K]
variable {ι κ : Type}
variable {k : ℕ}

/-- The data stage IN-C commits before `β, γ, α, r_emb` (stage_in_c.rs:303-323), at the LOGICAL positions: per
position `t : ι` the token word `tok t` (`A_TOK`), the `B_in` row `X t` over the column cube (`d_pad = 2^k`) and the
public control word `cq t` (`c(t) = [ctl_q(t)]`); per table row `v : κ` the public id word `vid v`, the padded
embedding row `E v`, the public control word `ctl v` and the committed multiplicity `m v` (`A_MULT`); the family tag
`TAG_EMB`. Stage IN: `cq = 0`, `ctl = 0` (no control column). -/
structure InData (B : Type) (ι κ : Type) (k : ℕ) where
  tag : B
  tok : ι → B
  X : ι → (Fin k → Bool) → B
  cq : ι → B
  vid : κ → B
  E : κ → (Fin k → Bool) → B
  ctl : κ → B
  m : κ → B

/-- The compressed QUERY tuple of position `t` at `r_emb`: `(tok_t, TAG_EMB, x~(t, r), c(t))`, which the code folds
as `tok + γ·TAG_EMB + β·x~(t, r) + β²·c(t)` (`fold`, SIC_QZC's `q`, stage_in_c.rs:206). -/
def qTup (φ : B →+* K) (D : InData B ι κ k) (r : Fin k → K) (t : ι) : Tup K :=
  ⟨φ (D.tok t), φ D.tag, mleAt (fun b => φ (D.X t b)) r, φ (D.cq t)⟩

/-- The compressed TABLE tuple of row `v`: `(v, TAG_EMB, E~(v, r), ctl(v))` (`tau_table`, stage_in_c.rs:160-164). -/
def tTup (φ : B →+* K) (D : InData B ι κ k) (r : Fin k → K) (v : κ) : Tup K :=
  ⟨φ (D.vid v), φ D.tag, mleAt (fun b => φ (D.E v b)) r, φ (D.ctl v)⟩

/-- The lookups as `logup_block_bound` takes them: one single per position, no pairs. -/
def inA (φ : B →+* K) (D : InData B ι κ k) (r : Fin k → K) : ι ⊕ (Empty ⊕ Empty) → Tup K :=
  Sum.elim (qTup φ D r) (Sum.elim Empty.elim Empty.elim)

/-- **What stage IN-C's lookup establishes at the logical level**: every position's token word is some table row's id,
its WHOLE (padded) `B_in` row is that row's (padded) embedding row, and its control word is that row's. -/
def InGood (D : InData B ι κ k) : Prop :=
  ∀ t, ∃ v, D.vid v = D.tok t ∧ D.X t = D.E v ∧ D.ctl v = D.cq t

/-- The stage's challenges drawn before `H_in`: `((β, γ), α)` and `r_emb`. -/
abbrev InChal (K : Type) (k : ℕ) := ((K × K) × K) × (Fin k → K)

/-- The LogUp relations of the stage at the challenges `ω`, for helpers `H` chosen after them. -/
def InLogUp [Fintype ι] [Fintype κ] [DecidableEq K] (φ : B →+* K) (D : InData B ι κ k) (ω : InChal K k) (H : Helpers ι Empty κ K) : Prop :=
  HelperRel (fun l => fold ω.1.1.1 ω.1.1.2 (inA φ D ω.2 l)) (fun v => fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 v))
    (fun v => φ (D.m v)) ω.1.2 H

/-- **The Schwartz–Zippel step over `r_emb`, one position.** Two different rows agree at a uniform `r` with
probability at most `k/|K|`. -/
theorem row_sz_prob [Fintype K] (φ : B →+* K) (X E : (Fin k → Bool) → B) (h : X ≠ E) :
    pr (fun r : Fin k → K => mleAt (fun b => φ (X b)) r = mleAt (fun b => φ (E b)) r)
      ≤ (k : ℝ≥0∞) / Fintype.card K := by
  refine mle_eq_prob _ _ (fun he => h (funext fun b => φ.injective (congrFun he b)))

/-- **The Schwartz–Zippel step over `r_emb`, every position.** For fixed data with injective ids, the probability
over `r` that some position's row differs from the row of the table entry its token word names, and yet their
compressed values at `r` agree, is at most `T·k/|K|`. -/
theorem rows_sz_prob [Fintype K] [Fintype ι] (φ : B →+* K) (D : InData B ι κ k) (hvid : Function.Injective D.vid) :
    pr (fun r : Fin k → K => ∃ t v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
        mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v b)) r)
      ≤ ((Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  refine (pr_exists_le (fun t (r : Fin k → K) => ∃ v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
    mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v b)) r)).trans ?_
  have hslot : ∀ t, pr (fun r : Fin k → K => ∃ v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
      mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v b)) r) ≤ (k : ℝ≥0∞) / Fintype.card K := by
    intro t
    by_cases hv : ∃ v₀, D.vid v₀ = D.tok t
    · obtain ⟨v₀, hv₀⟩ := hv
      by_cases hX : D.X t = D.E v₀
      · refine pr_le_of_not _ (fun r ⟨v, hv1, hv2, _⟩ => hv2 ?_) _
        rw [hvid (hv1.trans hv₀.symm)]
        exact hX
      · refine (pr_mono (E' := fun r => mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v₀ b)) r)
          (fun r ⟨v, hv1, _, hv3⟩ => ?_)).trans (row_sz_prob φ (D.X t) (D.E v₀) hX)
        rw [← hvid (hv1.trans hv₀.symm)]
        exact hv3
    · exact pr_le_of_not _ (fun r ⟨v, hv1, _⟩ => hv ⟨v, hv1⟩) _
  calc ∑ t, pr (fun r : Fin k → K => ∃ v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
        mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v b)) r)
      ≤ ∑ _t : ι, (k : ℝ≥0∞) / Fintype.card K := Finset.sum_le_sum (fun t _ => hslot t)
    _ = ((Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K := by
        rw [Finset.sum_const, Finset.card_univ, nsmul_eq_mul, ← mul_div_assoc, Nat.cast_mul]

/-- **Stage IN / IN-C's lookup, sound (the compressed embedding row and the LogUp together).** Let the data be fixed
before the challenges (the code commits `B_in`, `A_in`, `M` first), the ids injective (the table's ids `0, …, V − 1`
below `p`) and fewer positions than the characteristic. Over uniform `((β, γ), α)` and `r_emb`, the probability that
SOME helpers (chosen after the challenges) pass every LogUp relation and the sum claim while the lookup's conclusion
`InGood` FAILS is at most `((T + 4V − 1) + T·k)/|K|`. -/
theorem in_lookup_sound [Fintype K] [DecidableEq K] [Fintype ι] [Fintype κ] (φ : B →+* K) (D : InData B ι κ k) (hvid : Function.Injective D.vid)
    (hN : Fintype.card ι < ringChar K) :
    pr (fun ω : InChal K k => (∃ H, InLogUp φ D ω H) ∧ ¬ InGood D)
      ≤ (((Fintype.card ι + 4 * Fintype.card κ - 1) + Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K := by
  classical
  -- the two bad events: a compressed tuple outside the table (LogUp), or a row that differs but compresses equal
  have hsub : ∀ ω : InChal K k, ((∃ H, InLogUp φ D ω H) ∧ ¬ InGood D) →
      ((∃ t, ∀ v, tTup φ D ω.2 v ≠ qTup φ D ω.2 t) ∧ ∃ H, InLogUp φ D ω H) ∨
      (∃ t v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
        mleAt (fun b => φ (D.X t b)) ω.2 = mleAt (fun b => φ (D.E v b)) ω.2) := by
    rintro ω ⟨hH, hbad⟩
    by_cases hout : ∃ t, ∀ v, tTup φ D ω.2 v ≠ qTup φ D ω.2 t
    · exact Or.inl ⟨hout, hH⟩
    · push Not at hout
      refine Or.inr ?_
      unfold InGood at hbad
      push Not at hbad
      obtain ⟨t, ht⟩ := hbad
      obtain ⟨v, hv⟩ := hout t
      have h1 : φ (D.vid v) = φ (D.tok t) := congrArg Tup.x hv
      have h3 : mleAt (fun b => φ (D.E v b)) ω.2 = mleAt (fun b => φ (D.X t b)) ω.2 := congrArg Tup.y hv
      have h4 : φ (D.ctl v) = φ (D.cq t) := congrArg Tup.z hv
      have hid : D.vid v = D.tok t := φ.injective h1
      have hctl : D.ctl v = D.cq t := φ.injective h4
      refine ⟨t, v, hid, fun hX => ht v hid hX hctl, h3.symm⟩
  refine (pr_mono hsub).trans ((pr_or_le _ _).trans ?_)
  -- the LogUp term, at every `r_emb`
  have h1 : pr (fun ω : InChal K k => (∃ t, ∀ v, tTup φ D ω.2 v ≠ qTup φ D ω.2 t) ∧ ∃ H, InLogUp φ D ω H)
      ≤ ((Fintype.card ι + 4 * Fintype.card κ - 1 : ℕ) : ℝ≥0∞) / Fintype.card K := by
    refine pr_prod_le_right _ (fun r => ?_)
    by_cases hout : ∃ t, ∀ v, tTup φ D r v ≠ qTup φ D r t
    · obtain ⟨t, ht⟩ := hout
      have hcard : Fintype.card ι + 2 * Fintype.card (Empty) < ringChar K := by simpa using hN
      have hb := logup_block_bound (inA φ D r) (tTup φ D r) (fun v => φ (D.m v)) hcard (.inl t)
        (fun v => ht v)
      refine (pr_mono (E' := fun a : (K × K) × K => ∃ H, HelperRel (fun l => fold a.1.1 a.1.2 (inA φ D r l))
        (fun v => fold a.1.1 a.1.2 (tTup φ D r v)) (fun v => φ (D.m v)) a.2 H) (fun a ha => ha.2)).trans
        (hb.trans (ENNReal.div_le_div_right ?_ _))
      have him : (univ.image (tTup φ D r)).card ≤ Fintype.card κ := card_image_le.trans (by simp)
      have he : Fintype.card Empty = 0 := Fintype.card_eq_zero
      exact_mod_cast (show Fintype.card ι + 2 * Fintype.card Empty + 4 * (univ.image (tTup φ D r)).card - 1
        ≤ Fintype.card ι + 4 * Fintype.card κ - 1 by omega)
    · exact pr_le_of_not _ (fun a ha => hout ha.1) _
  -- the Schwartz–Zippel term, a function of `r_emb` alone
  have h2 : pr (fun ω : InChal K k => ∃ t v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
        mleAt (fun b => φ (D.X t b)) ω.2 = mleAt (fun b => φ (D.E v b)) ω.2)
      ≤ ((Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K :=
    (pr_snd_le (fun r : Fin k → K => ∃ t v, D.vid v = D.tok t ∧ D.X t ≠ D.E v ∧
      mleAt (fun b => φ (D.X t b)) r = mleAt (fun b => φ (D.E v b)) r)).trans (rows_sz_prob φ D hvid)
  calc _ ≤ ((Fintype.card ι + 4 * Fintype.card κ - 1 : ℕ) : ℝ≥0∞) / Fintype.card K
        + ((Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K := add_le_add h1 h2
    _ = _ := by rw [ENNReal.div_add_div_same, ← Nat.cast_add]

/-- **Stage IN / IN-C, both phases.** The prover chooses its helpers `h ω` after the pre-`H` challenges `ω`; then
the slots draw their challenges `ω₂` and accept (`acc`, with the prover's later messages folded in). If the slots,
with the `H` opening's sum claim, accept helpers that FAIL the LogUp relations with probability at most `ε₂` (each
zero-check slot's `zc_pad_sound` and `zc_batched_sound`, `inCube_helperRel`), then the stage accepts while
`InGood` fails with probability at most `((T + 4V − 1) + T·k)/|K| + ε₂`. -/
theorem in_stage_sound [Fintype K] [DecidableEq K] [Fintype ι] [Fintype κ] (φ : B →+* K) (D : InData B ι κ k) (hvid : Function.Injective D.vid)
    (hN : Fintype.card ι < ringChar K) {Ω₂ : Type} [Fintype Ω₂] [Nonempty Ω₂]
    (acc : InChal K k → Helpers ι Empty κ K → Ω₂ → Prop) (h : InChal K k → Helpers ι Empty κ K) {ε₂ : ℝ≥0∞}
    (hslots : ∀ ω H, ¬ InLogUp φ D ω H → pr (fun b => acc ω H b) ≤ ε₂) :
    pr (fun ω : InChal K k × Ω₂ => acc ω.1 (h ω.1) ω.2 ∧ ¬ InGood D)
      ≤ (((Fintype.card ι + 4 * Fintype.card κ - 1) + Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K + ε₂ :=
  two_phase_sound (InLogUp φ D) (InGood D) acc h (in_lookup_sound φ D hvid hN) hslots

/-! ## From the code's cube relations to `HelperRel` -/

/-- **The code's relations on the two cubes** (`Cq` the position domain `Ti`, `Cv` the vocabulary domain `Voc`, both
lifted to the row width), with the layout maps `pos`, `vpos` of the logical positions and rows into them:
* SIC_QZC's LogUp clause on the support, `h_q·(α − q) = 1`, and its pad clause off it (`h_q = 0`; the pad also gives
  `tok = 0`, which `InSat` does not need);
* SIC_TZC's table relation `h_tab·(α − τ) = m` on the live rows and its pad off them (`m = 0`, `h_tab = 0`);
* the `H` opening's value-0 LogUp sum `Σ h_q − Σ h_tab + Σ u = 0` and SIC_ZS's `Σ u = 0`. -/
structure InCube (Cq Cv U : Type) [Fintype Cq] [Fintype Cv] [Fintype U] (pos : ι → Cq) (vpos : κ → Cv)
    (look : ι → K) (tab : κ → K) (m : κ → K) (α : K) where
  hq : Cq → K
  ht : Cv → K
  u : U → K
  logup : ∀ t, hq (pos t) * (α - look t) = 1
  qpad : ∀ b, b ∉ Set.range pos → hq b = 0
  table : ∀ v, ht (vpos v) * (α - tab v) = m v
  tpad : ∀ c, c ∉ Set.range vpos → ht c = 0
  sum : ∑ b, hq b - ∑ c, ht c + ∑ j, u j = 0
  zs : ∑ j, u j = 0

/-- **The cube relations are `HelperRel` at the logical positions** (the pads drop the lifted entries from the sum
claim, `cube_sum_of_pad`). -/
theorem inCube_helperRel [Fintype ι] [Fintype κ] [DecidableEq K] {Cq Cv U : Type} [Fintype Cq] [Fintype Cv] [Fintype U] [DecidableEq Cq] [DecidableEq Cv]
    {pos : ι → Cq} {vpos : κ → Cv} (hpos : Function.Injective pos) (hvpos : Function.Injective vpos)
    {look : ι → K} {tab m : κ → K} {α : K} (C : InCube Cq Cv U pos vpos look tab m α) :
    HelperRel (Sum.elim look (Sum.elim Empty.elim Empty.elim)) tab m α
      ⟨fun t => C.hq (pos t), Empty.elim, fun v => C.ht (vpos v)⟩ := by
  refine ⟨fun t => C.logup t, fun e => e.elim, fun v => C.table v, ?_⟩
  have hs := C.sum
  rw [C.zs, add_zero, cube_sum_of_pad pos hpos C.hq C.qpad, cube_sum_of_pad vpos hvpos C.ht C.tpad] at hs
  simpa using hs

/-! ## From the lookup's conclusion to `InSat` -/

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.TokenRun

variable {S : BlockShape}

/-- **The stage's data, built from the extracted planes and the public tables** (B = `GF`): the token words, the
extracted `B_in` plane `Xc` at the column bits, the control words `ctlPos`; the table rows `v < V` with ids `v`, the
padded embedding `Epad` and `ctl(v)`; the multiplicities `m`. -/
def inDataOf (P : InPublic S) (k : ℕ) (tag : GF) (tok : S.Tok → GF) (Xc : S.Tok → (Fin k → Bool) → GF)
    (Epad : Fin P.V → (Fin k → Bool) → GF) (m : Fin P.V → GF) : InData GF S.Tok (Fin P.V) k where
  tag := tag
  tok := tok
  X := Xc
  cq t := (ctlPos P t : GF)
  vid v := ((v : ℕ) : GF)
  E := Epad
  ctl v := (ctl P v : GF)
  m := m

/-- The table's ids `0, …, V − 1` are distinct field words (`V ≤ 2^17 < p`). -/
theorem inDataOf_vid_injective (P : InPublic S) (hP : P.Valid) (k : ℕ) (tag : GF) (tok : S.Tok → GF)
    (Xc : S.Tok → (Fin k → Bool) → GF) (Epad : Fin P.V → (Fin k → Bool) → GF) (m : Fin P.V → GF) :
    Function.Injective (inDataOf P k tag tok Xc Epad m).vid := by
  intro v w h
  exact Fin.ext (natCast_inj_lt (lt_gP_of_V hP v.isLt) (lt_gP_of_V hP w.isLt) h)

/-- **The lookup's conclusion with the BOS and template clauses is `InSat`.** Through the column layout map
`col : S.Wid → (Fin k → Bool)` (the channel `i` of a row sits at the column bits `col i`; the padded embedding row
holds `E[v][i]` there), the plane `X (t, i) = Xc t (col i)` satisfies stage IN's relation. -/
theorem in_inSat (P : InPublic S) (k : ℕ) (tag : GF) (tok : S.Tok → GF)
    (Xc : S.Tok → (Fin k → Bool) → GF) (Epad : Fin P.V → (Fin k → Bool) → GF) (m : Fin P.V → GF)
    (col : S.Wid → (Fin k → Bool)) (hE : ∀ (v : Fin P.V) i, Epad v (col i) = (P.emb v i : GF))
    (hgood : InGood (inDataOf P k tag tok Xc Epad m))
    (hbos : ∀ t : S.Tok, (t : ℕ) = 0 → tok t = (P.bos : GF))
    (htmpl : ∀ t, P.isT t = true → tok t = (P.kap t : GF)) :
    InSat P tok (fun p => Xc p.1 (col p.2)) := by
  refine ⟨fun t => ?_, hbos, htmpl⟩
  obtain ⟨v, hid, hX, hctl⟩ := hgood t
  refine ⟨v, v.isLt, hid.symm, fun i => ?_, hctl.symm⟩
  show Xc t (col i) = _
  have hX' : Xc t = Epad v := hX
  rw [hX', hE]

/-- The lookup also pins the row's PAD columns: they are the padded table's, i.e. zero. -/
theorem in_pad_cols (P : InPublic S) (k : ℕ) (tag : GF) (tok : S.Tok → GF)
    (Xc : S.Tok → (Fin k → Bool) → GF) (Epad : Fin P.V → (Fin k → Bool) → GF) (m : Fin P.V → GF)
    (col : S.Wid → (Fin k → Bool)) (hEpad : ∀ (v : Fin P.V) b, b ∉ Set.range col → Epad v b = 0)
    (hgood : InGood (inDataOf P k tag tok Xc Epad m)) : ∀ t b, b ∉ Set.range col → Xc t b = 0 := by
  intro t b hb
  obtain ⟨v, -, hX, -⟩ := hgood t
  have hX' : Xc t = Epad v := hX
  rw [hX']
  exact hEpad v b hb

/-! ## The input endpoint (SIC_IO) and canonical words -/

/-- **SIC_IO's identity** (`end − supp·tok`, stage_in_c.rs:174-185, over the endpoint's whole padded plane): at every
word `w` of the endpoint plane, `end(w) = supp(w)·tok(w)`. With the layout map `epos` of the positions into the
endpoint's words (the support), the endpoint's word at `epos t` is `A_TOK`'s, and every other word is zero. -/
theorem in_endpoint_words {ι' W : Type} (epos : ι' → W) (ep tokw : W → GF) (supp : W → GF)
    (hsupp1 : ∀ t, supp (epos t) = 1) (hsupp0 : ∀ w, w ∉ Set.range epos → supp w = 0)
    (hio : ∀ w, ep w - supp w * tokw w = 0) :
    (∀ t, ep (epos t) = tokw (epos t)) ∧ (∀ w, w ∉ Set.range epos → ep w = 0) := by
  constructor
  · intro t
    have h := hio (epos t)
    rw [hsupp1, one_mul] at h
    exact sub_eq_zero.mp h
  · intro w hw
    have h := hio w
    rw [hsupp0 w hw, zero_mul, sub_zero] at h
    exact h

/-- The extractor's input ids are the endpoint's words read CANONICALLY (`ZMod.val`): each is below `p` and is the
word again as a field element, which is `tokenArith`'s / `classifyArith`'s canonical-word condition. -/
def canonWord (w : GF) : ℕ := w.val

theorem canonWord_lt (w : GF) : canonWord w < gP := ZMod.val_lt w

theorem canonWord_cast (w : GF) : ((canonWord w : ℕ) : GF) = w := ZMod.natCast_zmod_val w

end InStage

end ZK60.StageX
