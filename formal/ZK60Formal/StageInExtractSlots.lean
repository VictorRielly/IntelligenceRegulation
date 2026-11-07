/-
D63, Lean lane L12 (2026-11-07): **stage IN-C's slots as the code writes them, and the whole stage in one theorem**
(the interactive form). `StageInExtract.lean` proved the lookup's step (`in_lookup_sound`) and that the code's cube
relations are `HelperRel` (`inCube_helperRel`); `StageExtractCore.lean` proved the generic slots. This file writes
stage IN-C's two zero-check slots and its zero-sum slot as the code's closures on the committed tables' multilinear
extensions (stage_in_c.rs:188-235), and composes the stage:

* `QzcClause`, `QzcTabs`, `qzcQ`, `qzcW`, `qzcPz`: SIC_QZC's three clauses (the LogUp clause
  `h_q·(α − q) − supp`, BOS `u0·(tok − bos)`, the template `π·(tok − κ)`) and its pad planes `(1 − supp)·tok`,
  `(1 − supp)·h_q` (`zeta_fold` with `ζ`), `q = tok + β·B(ρ_t, r_emb) + β²·[ctl_q] + γ·TAG_EMB` (:205-212);
* `TzcTabs`, `tzcW`, `tzcPz`: SIC_TZC's table relation `h_tab·(α − τ) − m` and its pads (:224-228);
* `qzcW_deg`, `qzcPz_deg`, `tzcW_deg`, `tzcPz_deg`: each is of individual degree `≤ 3` (the code declares round
  degree 4 for both slots, stage_in_c.rs:49-50): `IndDegLE.mul`, `IndDegLE.sub`, `IndDegLE.cmul`, `IndDegLE.const`;
* `qzc_cube`, `tzc_cube`: on the cube the clauses are the tables' own values (`mleAt_bitv`);
* **`zc_slot_sound`**, **`zs_sound`**: SIC_QZC / SIC_TZC accept a violated clause or pad with probability at most
  `((m − 1) + 1 + n + 4n)/|K|`, SIC_ZS a nonzero `Σ u` with at most `2n/|K|`;
* `IncLayout`: the public tables and the layout map of the two cubes (`supp`, `u0`, `π`, `κ`, `β²·[ctl_q]`, the
  family tag, the `τ` table, the positions `pos`, `vpos`), with the facts the code's tables satisfy there;
* `incCube`: the slots' conclusions on the cubes, the pads and the two sum claims are `InCube`;
* **`inc_stage_sound`**: the WHOLE stage. Over the pre-`H` challenges, then SIC_QZC's, SIC_TZC's and SIC_ZS's
  challenges, for ANY helpers the prover commits and ANY sumcheck provers, the stage accepts (the three slots and the
  `H` opening's value-0 sum claim) while the lookup's conclusion `InGood`, the BOS fact or the template facts fail
  with probability at most the lookup's term plus the three slots' terms.

Modelling boundary (as for every slot lemma): the slots' terminal values are the true tables' extensions (the
openings, lane L10), the CFS mask and the extension round are `sumcheck_sound_masked` / `sumcheck_sound_extended`,
SIC_IO is `zc_batched_sound` on its own cube, and Fiat–Shamir is L7 / L8's.
-/
import ZK60Formal.StageInExtract

namespace ZK60.StageX

open scoped ENNReal
open Polynomial Finset ZK60.Sound

/-! ## Degrees -/

section Deg

variable {K : Type} [Field K]

theorem IndDegLE.mul {n a b : ℕ} {f g : (Fin n → K) → K} (hf : IndDegLE a f) (hg : IndDegLE b g) :
    IndDegLE (a + b) (fun x => f x * g x) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := hf i x
  obtain ⟨q, hq, hqe⟩ := hg i x
  exact ⟨p * q, natDegree_mul_le.trans (Nat.add_le_add hp hq), fun t => by simp only [eval_mul, hpe, hqe]⟩

theorem IndDegLE.const {n d : ℕ} (c : K) : IndDegLE d (fun _ : Fin n → K => c) := by
  intro i x
  exact ⟨C c, by rw [natDegree_C]; exact Nat.zero_le d, fun t => by simp only [eval_C]⟩

theorem IndDegLE.sub {n d : ℕ} {f g : (Fin n → K) → K} (hf : IndDegLE d f) (hg : IndDegLE d g) :
    IndDegLE d (fun x => f x - g x) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := hf i x
  obtain ⟨q, hq, hqe⟩ := hg i x
  exact ⟨p - q, (natDegree_sub_le p q).trans (max_le hp hq), fun t => by simp only [eval_sub, hpe, hqe]⟩

theorem IndDegLE.cmul {n d : ℕ} {f : (Fin n → K) → K} (c : K) (hf : IndDegLE d f) :
    IndDegLE d (fun x => c * f x) := by
  intro i x
  obtain ⟨p, hp, hpe⟩ := hf i x
  exact ⟨C c * p, (natDegree_C_mul_le c p).trans hp, fun t => by simp only [eval_mul, eval_C, hpe]⟩

theorem mle_deg {n : ℕ} (T : (Fin n → Bool) → K) {d : ℕ} (hd : 1 ≤ d) : IndDegLE d (fun x => mleAt T x) :=
  IndDegLE.mono (indDegLE_mleAt T) hd

theorem mleAt_bitv {n : ℕ} (P : (Fin n → Bool) → K) (b : Fin n → Bool) : mleAt P (bitv b) = P b :=
  mleAt_bit P b

end Deg

/-! ## The slots as the code writes them -/

/-- SIC_QZC's three clauses (stage_in_c.rs:205-212). -/
inductive QzcClause
  | logup
  | bos
  | tmpl
  deriving DecidableEq

instance : Fintype QzcClause :=
  ⟨{.logup, .bos, .tmpl}, fun x => by cases x <;> simp⟩

/-- The cube tables SIC_QZC reads on the position domain (`2^n` entries): the token words `A_TOK`, the helper
`H_Q`, `B_in` read at `(ρ_t, r_emb)`, and the public columns `supp`, `u0`, `π` (the template indicator), `κ` and
`β²·[ctl_q]`. -/
structure QzcTabs (K : Type) (n : ℕ) where
  tok : (Fin n → Bool) → K
  hq : (Fin n → Bool) → K
  bq : (Fin n → Bool) → K
  supp : (Fin n → Bool) → K
  u0 : (Fin n → Bool) → K
  pt : (Fin n → Bool) → K
  kap : (Fin n → Bool) → K
  cq : (Fin n → Bool) → K

/-- The cube tables SIC_TZC reads on the vocabulary domain: the multiplicities `A_MULT`, the helper `H_TAB`, the
public `supp` and the table `τ` (`tau_table`). -/
structure TzcTabs (K : Type) (n : ℕ) where
  m : (Fin n → Bool) → K
  ht : (Fin n → Bool) → K
  supp : (Fin n → Bool) → K
  tau : (Fin n → Bool) → K

section Slots

variable {K : Type} [Field K]

/-- The folded query `q = tok + β·B + β²·[ctl_q] + g` as the code forms it (`q` in SIC_QZC). -/
def qzcQ {n : ℕ} (T : QzcTabs K n) (β g : K) (x : Fin n → K) : K :=
  mleAt T.tok x + β * mleAt T.bq x + mleAt T.cq x + g

/-- SIC_QZC's clauses on the tables' extensions. -/
def qzcW {n : ℕ} (T : QzcTabs K n) (α β g bos : K) : QzcClause → (Fin n → K) → K
  | .logup => fun x => mleAt T.hq x * (α - qzcQ T β g x) - mleAt T.supp x
  | .bos => fun x => mleAt T.u0 x * (mleAt T.tok x - bos)
  | .tmpl => fun x => mleAt T.pt x * (mleAt T.tok x - mleAt T.kap x)

/-- SIC_QZC's pad planes, folded by `ζ` as `(1 − supp)·(tok + ζ·h_q)`. -/
def qzcPz {n : ℕ} (T : QzcTabs K n) : Fin 2 → (Fin n → K) → K :=
  fun i x => (1 - mleAt T.supp x) * (if (i : ℕ) = 0 then mleAt T.tok x else mleAt T.hq x)

/-- SIC_TZC's table relation on the tables' extensions. -/
def tzcW {n : ℕ} (T : TzcTabs K n) (α : K) : Unit → (Fin n → K) → K :=
  fun _ x => mleAt T.ht x * (α - mleAt T.tau x) - mleAt T.m x

/-- SIC_TZC's pad planes, folded as `(1 − supp)·(m + ζ·h_tab)`. -/
def tzcPz {n : ℕ} (T : TzcTabs K n) : Fin 2 → (Fin n → K) → K :=
  fun i x => (1 - mleAt T.supp x) * (if (i : ℕ) = 0 then mleAt T.m x else mleAt T.ht x)

theorem qzcQ_deg {n : ℕ} (T : QzcTabs K n) (β g : K) : IndDegLE 1 (qzcQ T β g) :=
  IndDegLE.add (IndDegLE.add (IndDegLE.add (mle_deg T.tok le_rfl) (IndDegLE.cmul β (mle_deg T.bq le_rfl)))
    (mle_deg T.cq le_rfl)) (IndDegLE.const g)

theorem qzcW_deg {n : ℕ} (T : QzcTabs K n) (α β g bos : K) : ∀ j, IndDegLE 3 (qzcW T α β g bos j)
  | .logup => by
      show IndDegLE 3 (fun x => mleAt T.hq x * (α - qzcQ T β g x) - mleAt T.supp x)
      exact IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (mle_deg T.hq le_rfl)
        (IndDegLE.sub (IndDegLE.const α) (qzcQ_deg T β g))) (by norm_num)) (mle_deg T.supp (by norm_num))
  | .bos => by
      show IndDegLE 3 (fun x => mleAt T.u0 x * (mleAt T.tok x - bos))
      exact IndDegLE.mono (IndDegLE.mul (mle_deg T.u0 le_rfl)
        (IndDegLE.sub (mle_deg T.tok le_rfl) (IndDegLE.const bos))) (by norm_num)
  | .tmpl => by
      show IndDegLE 3 (fun x => mleAt T.pt x * (mleAt T.tok x - mleAt T.kap x))
      exact IndDegLE.mono (IndDegLE.mul (mle_deg T.pt le_rfl)
        (IndDegLE.sub (mle_deg T.tok le_rfl) (mle_deg T.kap le_rfl))) (by norm_num)

theorem pad2_deg {n : ℕ} (s a h : (Fin n → Bool) → K) :
    ∀ i : Fin 2, IndDegLE 3 (fun x => (1 - mleAt s x) * (if (i : ℕ) = 0 then mleAt a x else mleAt h x)) := by
  intro i
  by_cases hi : (i : ℕ) = 0
  · simp only [hi, ↓reduceIte]
    exact IndDegLE.mono (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (mle_deg s le_rfl)) (mle_deg a le_rfl))
      (by norm_num)
  · simp only [hi, ↓reduceIte]
    exact IndDegLE.mono (IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (mle_deg s le_rfl)) (mle_deg h le_rfl))
      (by norm_num)

theorem qzcPz_deg {n : ℕ} (T : QzcTabs K n) : ∀ i, IndDegLE 3 (qzcPz T i) :=
  pad2_deg T.supp T.tok T.hq

theorem tzcW_deg {n : ℕ} (T : TzcTabs K n) (α : K) : ∀ j, IndDegLE 3 (tzcW T α j) := fun _ =>
  IndDegLE.sub (IndDegLE.mono (IndDegLE.mul (mle_deg T.ht le_rfl)
    (IndDegLE.sub (IndDegLE.const α) (mle_deg T.tau le_rfl))) (by norm_num)) (mle_deg T.m (by norm_num))

theorem tzcPz_deg {n : ℕ} (T : TzcTabs K n) : ∀ i, IndDegLE 3 (tzcPz T i) :=
  pad2_deg T.supp T.m T.ht

/-- SIC_QZC's clauses and pads vanish on the whole cube. -/
def QzcHolds {n : ℕ} (T : QzcTabs K n) (α β g bos : K) : Prop :=
  (∀ j, ∀ b : Fin n → Bool, qzcW T α β g bos j (bitv b) = 0) ∧ ∀ i, ∀ b : Fin n → Bool, qzcPz T i (bitv b) = 0

/-- SIC_TZC's relation and pads vanish on the whole cube. -/
def TzcHolds {n : ℕ} (T : TzcTabs K n) (α : K) : Prop :=
  (∀ j, ∀ b : Fin n → Bool, tzcW T α j (bitv b) = 0) ∧ ∀ i, ∀ b : Fin n → Bool, tzcPz T i (bitv b) = 0

/-- **On the cube, SIC_QZC's clauses are the tables' own values.** -/
theorem qzc_cube {n : ℕ} {T : QzcTabs K n} {α β g bos : K} (h : QzcHolds T α β g bos) (b : Fin n → Bool) :
    T.hq b * (α - (T.tok b + β * T.bq b + T.cq b + g)) - T.supp b = 0 ∧ T.u0 b * (T.tok b - bos) = 0 ∧
      T.pt b * (T.tok b - T.kap b) = 0 ∧ (1 - T.supp b) * T.tok b = 0 ∧ (1 - T.supp b) * T.hq b = 0 := by
  obtain ⟨hW, hP⟩ := h
  have e1 := hW .logup b
  have e2 := hW .bos b
  have e3 := hW .tmpl b
  have e4 := hP 0 b
  have e5 := hP 1 b
  simp only [qzcW, qzcQ, qzcPz, mleAt_bitv] at e1 e2 e3 e4 e5
  simp only [Fin.isValue, Fin.val_zero, Fin.val_one, ↓reduceIte, one_ne_zero] at e4 e5
  exact ⟨e1, e2, e3, e4, e5⟩

/-- **On the cube, SIC_TZC's relation and pads are the tables' own values.** -/
theorem tzc_cube {n : ℕ} {T : TzcTabs K n} {α : K} (h : TzcHolds T α) (b : Fin n → Bool) :
    T.ht b * (α - T.tau b) - T.m b = 0 ∧ (1 - T.supp b) * T.m b = 0 ∧ (1 - T.supp b) * T.ht b = 0 := by
  obtain ⟨hW, hP⟩ := h
  have e1 := hW () b
  have e4 := hP 0 b
  have e5 := hP 1 b
  simp only [tzcW, tzcPz, mleAt_bitv] at e1 e4 e5
  simp only [Fin.isValue, Fin.val_zero, Fin.val_one, ↓reduceIte, one_ne_zero] at e4 e5
  exact ⟨e1, e4, e5⟩

/-- A zero-check slot's challenges: the pad fold `ζ`, the batching `μ`, the point `τ`, the rounds `ρ`. -/
abbrev ZcChal (ι K : Type) (n : ℕ) := K × ((Option ι → K) × ((Fin n → K) × (Fin n → K)))

/-- A zero-check slot with a two-plane pad accepts (the code's eq-weighted batched closure on the claim `0`). -/
def zcAcc {ι : Type} [Fintype ι] {n : ℕ} (W : ι → (Fin n → K) → K) (Pz : Fin 2 → (Fin n → K) → K)
    (P : K → (Option ι → K) → (Fin n → K) → Prover K (3 + 1) n) (ω : ZcChal ι K n) : Prop :=
  Accepts n (fun x => eqPoly ω.2.2.1 x * batched (withPad W Pz ω.1) ω.2.1 x) 0 (P ω.1 ω.2.1 ω.2.2.1) ω.2.2.2

/-- **SIC_QZC / SIC_TZC, sound.** A slot of the code's form whose clauses or pads do NOT all vanish on the cube
accepts with probability at most `(1 + (1 + n + 4n))/|K|` (`zc_pad_sound` at the code's declared round degree 4). -/
theorem zc_slot_sound [Fintype K] [DecidableEq K] {ι : Type} [Fintype ι] [DecidableEq ι] {n : ℕ}
    (hd : 3 + 1 < ringChar K) (W : ι → (Fin n → K) → K) (Pz : Fin 2 → (Fin n → K) → K)
    (hW : ∀ j, IndDegLE 3 (W j)) (hP : ∀ i, IndDegLE 3 (Pz i))
    (hbad : ¬ ((∀ j, ∀ b : Fin n → Bool, W j (bitv b) = 0) ∧ ∀ i, ∀ b : Fin n → Bool, Pz i (bitv b) = 0))
    (P : K → (Option ι → K) → (Fin n → K) → Prover K (3 + 1) n) :
    pr (fun ω : ZcChal ι K n => zcAcc W Pz P ω) ≤ (((2 - 1) + (1 + (n + n * (3 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K := by
  have hnz : (∃ j, ∃ b : Fin n → Bool, W j (bitv b) ≠ 0) ∨ (∃ i, ∃ b : Fin n → Bool, Pz i (bitv b) ≠ 0) := by
    by_contra hc
    push Not at hc
    exact hbad hc
  exact zc_pad_sound hd W Pz hW hP hnz P

/-- **SIC_ZS, sound.** The zero-sum slot (`1·u` on the claim `0`, declared degree 2): a row whose sum is not zero
passes with probability at most `2n/|K|`. -/
theorem zs_sound [Fintype K] [DecidableEq K] {n : ℕ} (hd : 2 < ringChar K) (u : (Fin n → Bool) → K)
    (hu : ∑ b, u b ≠ 0) (P : Prover K 2 n) :
    pr (fun ρ : Fin n → K => Accepts n (fun x => mleAt (fun _ => (1 : K)) x * mleAt u x) 0 P ρ)
      ≤ ((n * 2 : ℕ) : ℝ≥0∞) / Fintype.card K := by
  have hdeg : IndDegLE 2 (fun x => mleAt (fun _ => (1 : K)) x * mleAt u x) :=
    IndDegLE.mul (mle_deg (fun _ => (1 : K)) le_rfl) (mle_deg u le_rfl)
  have hsum : cubeSum (fun x => mleAt (fun _ => (1 : K)) x * mleAt u x) = ∑ b, u b := by
    simp only [cubeSum, mleAt_bit, one_mul]
  refine sumcheck_sound hd hdeg ?_ P
  rw [hsum]
  exact Ne.symm hu

end Slots

/-! ## The layout of the two cubes, and `InCube` -/

section Stage

variable {B K : Type} [Field B] [Field K]
variable {ι κ : Type}
variable {k : ℕ}

/-- **Stage IN-C's public cube tables and layout map**: the position domain `Ti` (`2^n` entries, the logical positions
at `pos`), the vocabulary domain `Voc` (`2^nv`, the table rows at `vpos`); the token-word table, `B_in` read at
`(ρ_t, r_emb)`, `supp`, `u0`, `π`, `κ`, `β²·[ctl_q]`, the family tag, BOS; the multiplicity table, the table's
`supp` and `τ`; and what the code's tables are at the logical positions (stage_in_c.rs:154-164, 192-221). -/
structure IncLayout (φ : B →+* K) (D : InData B ι κ k) (n nv : ℕ) where
  pos : ι → (Fin n → Bool)
  vpos : κ → (Fin nv → Bool)
  pos_inj : Function.Injective pos
  vpos_inj : Function.Injective vpos
  tok : (Fin n → Bool) → K
  bq : InChal K k → (Fin n → Bool) → K
  supp : (Fin n → Bool) → K
  u0 : (Fin n → Bool) → K
  pt : (Fin n → Bool) → K
  kap : (Fin n → Bool) → K
  cq : InChal K k → (Fin n → Bool) → K
  g : InChal K k → K
  bos : K
  m : (Fin nv → Bool) → K
  suppv : (Fin nv → Bool) → K
  tau : InChal K k → (Fin nv → Bool) → K
  supp1 : ∀ t, supp (pos t) = 1
  supp0 : ∀ b, b ∉ Set.range pos → supp b = 0
  tok_pos : ∀ t, tok (pos t) = φ (D.tok t)
  bq_pos : ∀ ω t, bq ω (pos t) = mleAt (fun c => φ (D.X t c)) ω.2
  cq_pos : ∀ ω t, cq ω (pos t) = ω.1.1.1 ^ 2 * φ (D.cq t)
  g_eq : ∀ ω, g ω = ω.1.1.2 * φ D.tag
  suppv1 : ∀ v, suppv (vpos v) = 1
  suppv0 : ∀ c, c ∉ Set.range vpos → suppv c = 0
  m_pos : ∀ v, m (vpos v) = φ (D.m v)
  tau_pos : ∀ ω v, tau ω (vpos v) = fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 v)

/-- The helper data the prover commits in `H_in` after the pre-`H` challenges: `h_q` on `Ti`, `h_tab` on `Voc`, the
zero-sum row `u`. -/
abbrev IncHelpers (K : Type) (n nv nu : ℕ) := ((Fin n → Bool) → K) × ((Fin nv → Bool) → K) × ((Fin nu → Bool) → K)

/-- SIC_QZC's tables at the challenges `ω` and the helpers `hd`. -/
def incQ {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv) (ω : InChal K k)
    (hd : IncHelpers K n nv nu) : QzcTabs K n :=
  ⟨L.tok, hd.1, L.bq ω, L.supp, L.u0, L.pt, L.kap, L.cq ω⟩

/-- SIC_TZC's tables at the challenges `ω` and the helpers `hd`. -/
def incT {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv) (ω : InChal K k)
    (hd : IncHelpers K n nv nu) : TzcTabs K nv :=
  ⟨L.m, hd.2.1, L.suppv, L.tau ω⟩

/-- The logical helpers of `HelperRel` read off the committed helper planes at the logical positions. -/
def incHelpers {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (hd : IncHelpers K n nv nu) : Helpers ι Empty κ K :=
  ⟨fun t => hd.1 (L.pos t), Empty.elim, fun v => hd.2.1 (L.vpos v)⟩

/-- The `H` opening's value-0 LogUp sum claim (`logup_sum_claim`: `Σ h_q − Σ h_tab + Σ u = 0`). -/
def IncSum {n nv nu : ℕ} (hd : IncHelpers K n nv nu) : Prop :=
  ∑ b, hd.1 b - ∑ c, hd.2.1 c + ∑ j, hd.2.2 j = 0

/-- The BOS and template facts at the logical positions (SIC_QZC's other two clauses read there). -/
def IncBosTmpl {φ : B →+* K} {D : InData B ι κ k} {n nv : ℕ} (L : IncLayout φ D n nv) : Prop :=
  (∀ t, L.u0 (L.pos t) = 1 → φ (D.tok t) = L.bos) ∧ (∀ t, L.pt (L.pos t) = 1 → φ (D.tok t) = L.kap (L.pos t))

theorem incLook_eq [Fintype ι] (φ : B →+* K) (D : InData B ι κ k) (ω : InChal K k) :
    (fun l => fold ω.1.1.1 ω.1.1.2 (inA φ D ω.2 l)) =
      Sum.elim (fun t => fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t)) (Sum.elim Empty.elim Empty.elim) := by
  funext l
  rcases l with t | e | e
  · rfl
  · exact e.elim
  · exact e.elim

/-- **The slots' conclusions give `HelperRel`, BOS and the template facts.** If SIC_QZC's and SIC_TZC's clauses and
pads vanish on their cubes and the two sum claims hold, the committed helpers read at the logical positions satisfy
the stage's LogUp relations `InLogUp`, and the BOS and template facts hold. -/
theorem incCube [Fintype ι] [Fintype κ] [DecidableEq K] (φ : B →+* K) (D : InData B ι κ k) {n nv nu : ℕ}
    (L : IncLayout φ D n nv) (ω : InChal K k) (hd : IncHelpers K n nv nu)
    (hq : QzcHolds (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos) (ht : TzcHolds (incT L ω hd) ω.1.2)
    (hs : IncSum hd) (hz : ∑ j, hd.2.2 j = 0) :
    InLogUp φ D ω (incHelpers L hd) ∧ IncBosTmpl L := by
  classical
  have hlook : ∀ t, hd.1 (L.pos t) * (ω.1.2 - fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t)) = 1 := by
    intro t
    obtain ⟨e1, -⟩ := qzc_cube hq (L.pos t)
    simp only [incQ] at e1
    rw [L.tok_pos t, L.bq_pos ω t, L.cq_pos ω t, L.supp1 t, L.g_eq ω] at e1
    simp only [ZK60.Sound.fold, qTup]
    linear_combination e1
  have hqpad : ∀ b, b ∉ Set.range L.pos → hd.1 b = 0 := by
    intro b hb
    obtain ⟨-, -, -, -, e5⟩ := qzc_cube hq b
    simp only [incQ] at e5
    rw [L.supp0 b hb, sub_zero, one_mul] at e5
    exact e5
  have htab : ∀ v, hd.2.1 (L.vpos v) * (ω.1.2 - fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 v)) = φ (D.m v) := by
    intro v
    obtain ⟨e1, -, -⟩ := tzc_cube ht (L.vpos v)
    simp only [incT] at e1
    rw [L.tau_pos ω v, L.m_pos v] at e1
    exact sub_eq_zero.mp e1
  have htpad : ∀ c, c ∉ Set.range L.vpos → hd.2.1 c = 0 := by
    intro c hc
    obtain ⟨-, -, e5⟩ := tzc_cube ht c
    simp only [incT] at e5
    rw [L.suppv0 c hc, sub_zero, one_mul] at e5
    exact e5
  let C : InCube (Fin n → Bool) (Fin nv → Bool) (Fin nu → Bool) L.pos L.vpos
      (fun t => fold ω.1.1.1 ω.1.1.2 (qTup φ D ω.2 t)) (fun v => fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 v))
      (fun v => φ (D.m v)) ω.1.2 :=
    ⟨hd.1, hd.2.1, hd.2.2, hlook, hqpad, htab, htpad, hs, hz⟩
  refine ⟨?_, ⟨fun t ht0 => ?_, fun t hpt => ?_⟩⟩
  · have hrel := inCube_helperRel L.pos_inj L.vpos_inj C
    exact (congrArg (fun f => HelperRel f (fun v => fold ω.1.1.1 ω.1.1.2 (tTup φ D ω.2 v))
      (fun v => φ (D.m v)) ω.1.2 (incHelpers L hd)) (incLook_eq φ D ω)).mpr hrel
  · obtain ⟨-, e2, -⟩ := qzc_cube hq (L.pos t)
    simp only [incQ] at e2
    rw [L.tok_pos t, ht0, one_mul] at e2
    exact sub_eq_zero.mp e2
  · obtain ⟨-, -, e3, -⟩ := qzc_cube hq (L.pos t)
    simp only [incQ] at e3
    rw [L.tok_pos t, hpt, one_mul] at e3
    exact sub_eq_zero.mp e3

/-! ## The whole stage -/

/-- The three slots' challenges after `H_in`: SIC_QZC's, SIC_TZC's and SIC_ZS's rounds. -/
abbrev IncChal2 (K : Type) (n nv nu : ℕ) := ZcChal QzcClause K n × (ZcChal Unit K nv × (Fin nu → K))

/-- **The stage verifier's acceptance** after the pre-`H` challenges `ω` and the committed helpers `hd`: SIC_QZC,
SIC_TZC and SIC_ZS accept (their provers may depend on everything drawn before their messages) and the `H` opening's
value-0 sum claim holds. -/
def IncAcc {φ : B →+* K} {D : InData B ι κ k} {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (Pq : InChal K k → K → (Option QzcClause → K) → (Fin n → K) → Prover K (3 + 1) n)
    (Pt : InChal K k → ZcChal QzcClause K n → K → (Option Unit → K) → (Fin nv → K) → Prover K (3 + 1) nv)
    (Pz : InChal K k → ZcChal QzcClause K n → ZcChal Unit K nv → Prover K 2 nu)
    (ω : InChal K k) (hd : IncHelpers K n nv nu) (ω₂ : IncChal2 K n nv nu) : Prop :=
  zcAcc (qzcW (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos) (qzcPz (incQ L ω hd)) (Pq ω) ω₂.1 ∧
    zcAcc (tzcW (incT L ω hd) ω.1.2) (tzcPz (incT L ω hd)) (Pt ω ω₂.1) ω₂.2.1 ∧
    Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2 x) 0 (Pz ω ω₂.1 ω₂.2.1) ω₂.2.2 ∧
    IncSum hd

/-- **Stage IN-C (and IN), the whole stage, sound.** For data fixed before the challenges (the code commits `B_in`,
`A_in`, `M` first), injective table ids and fewer positions than the characteristic: over the uniform pre-`H`
challenges `((β, γ), α), r_emb` and then the three slots' challenges, for ANY committed helpers `h ω` and ANY
sumcheck provers, the stage accepts while the lookup's conclusion `InGood`, the BOS fact or the template facts fail
with probability at most the lookup's term `((T + 4V − 1) + T·k)/|K|` plus the three slots'
`(1 + (1 + n + 4n))/|K|`, `(1 + (1 + nv + 4nv))/|K|` and `2·nu/|K|`. -/
theorem inc_stage_sound [Fintype K] [DecidableEq K] [Fintype ι] [Fintype κ] (φ : B →+* K) (D : InData B ι κ k)
    (hvid : Function.Injective D.vid) (hN : Fintype.card ι < ringChar K) (hd4 : 3 + 1 < ringChar K)
    {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (Pq : InChal K k → K → (Option QzcClause → K) → (Fin n → K) → Prover K (3 + 1) n)
    (Pt : InChal K k → ZcChal QzcClause K n → K → (Option Unit → K) → (Fin nv → K) → Prover K (3 + 1) nv)
    (Pz : InChal K k → ZcChal QzcClause K n → ZcChal Unit K nv → Prover K 2 nu)
    (h : InChal K k → IncHelpers K n nv nu) :
    pr (fun ω : InChal K k × IncChal2 K n nv nu =>
        IncAcc L Pq Pt Pz ω.1 (h ω.1) ω.2 ∧ ¬ (InGood D ∧ IncBosTmpl L))
      ≤ (((Fintype.card ι + 4 * Fintype.card κ - 1) + Fintype.card ι * k : ℕ) : ℝ≥0∞) / Fintype.card K
        + ((((2 - 1) + (1 + (n + n * (3 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K
          + (((2 - 1) + (1 + (nv + nv * (3 + 1))) : ℕ) : ℝ≥0∞) / Fintype.card K
          + ((nu * 2 : ℕ) : ℝ≥0∞) / Fintype.card K) := by
  classical
  have hd2 : 2 < ringChar K := lt_trans (by norm_num) hd4
  refine two_phase_sound (fun ω hd => InLogUp φ D ω (incHelpers L hd) ∧ IncBosTmpl L) (InGood D ∧ IncBosTmpl L)
    (IncAcc L Pq Pt Pz) h ?_ ?_
  · -- phase 1: the lookup
    refine (pr_mono (E' := fun ω : InChal K k => (∃ H, InLogUp φ D ω H) ∧ ¬ InGood D) ?_).trans
      (in_lookup_sound φ D hvid hN)
    rintro ω ⟨⟨hd, hrel, hbt⟩, hg⟩
    exact ⟨⟨_, hrel⟩, fun hgood => hg ⟨hgood, hbt⟩⟩
  · -- phase 2: helpers failing the relations, or the BOS / template facts failing, are caught by a slot
    intro ω hd hpre
    have hcase : ¬ QzcHolds (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos ∨ ¬ TzcHolds (incT L ω hd) ω.1.2 ∨
        ¬ (∑ j, hd.2.2 j = 0) ∨ ¬ IncSum hd := by
      by_contra hc
      push Not at hc
      obtain ⟨h1, h2, h3, h4⟩ := hc
      exact hpre (incCube φ D L ω hd h1 h2 h4 h3)
    have eQ := zc_slot_sound hd4 (qzcW (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos) (qzcPz (incQ L ω hd))
    have et := zc_slot_sound hd4 (tzcW (incT L ω hd) ω.1.2) (tzcPz (incT L ω hd))
    rcases hcase with hc | hc | hc | hc
    · -- SIC_QZC catches it
      refine (pr_mono (E' := fun ω₂ : IncChal2 K n nv nu => zcAcc (qzcW (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos)
        (qzcPz (incQ L ω hd)) (Pq ω) ω₂.1) (fun ω₂ hω => hω.1)).trans ?_
      refine (pr_fst_le _).trans ((eQ (qzcW_deg _ _ _ _ _) (qzcPz_deg _) hc (Pq ω)).trans ?_)
      exact le_add_right le_self_add
    · -- SIC_TZC catches it
      refine (pr_mono (E' := fun ω₂ : IncChal2 K n nv nu => zcAcc (tzcW (incT L ω hd) ω.1.2)
        (tzcPz (incT L ω hd)) (Pt ω ω₂.1) ω₂.2.1) (fun ω₂ hω => hω.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => (pr_fst_le (fun b : ZcChal Unit K nv => zcAcc (tzcW (incT L ω hd) ω.1.2)
        (tzcPz (incT L ω hd)) (Pt ω a) b)).trans (et (tzcW_deg _ _) (tzcPz_deg _) hc (Pt ω a)))).trans ?_
      exact le_add_right le_add_self
    · -- SIC_ZS catches it
      refine (pr_mono (E' := fun ω₂ : IncChal2 K n nv nu =>
        Accepts nu (fun x => mleAt (fun _ => (1 : K)) x * mleAt hd.2.2 x) 0 (Pz ω ω₂.1 ω₂.2.1) ω₂.2.2)
        (fun ω₂ hω => hω.2.2.1)).trans ?_
      refine (pr_prod_le _ (fun a => pr_prod_le _ (fun b => zs_sound hd2 hd.2.2 hc (Pz ω a b)))).trans ?_
      exact le_add_self
    · -- the sum claim fails: the `H` opening rejects
      exact pr_le_of_not _ (fun ω₂ hω => hc hω.2.2.2) _

end Stage

end ZK60.StageX
