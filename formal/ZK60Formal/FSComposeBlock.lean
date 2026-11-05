/-
D63, step L3 (soundness): one block, and a run of blocks, of the private-block verifier as ONE composed protocol on one
chain, with the per-round errors of the proved sub-protocols (finding F20).

`FSCompose.lean` proves the composition for any schedule of sub-protocols (`SubProt`). This file supplies the
sub-protocols of a block, each with its PROVED round-by-round soundness on digests and the code's challenge
derivations, and evaluates the largest error at the 8B T128 W16R2 parameters.

**The sub-protocols** (`SubProt` constructors; each reads the composed statement with the transcript before its
window, so its claim may be fixed by earlier rounds):
* `logupSP`: LogUp's two rounds, `(β, γ)` then `α` (`FSLogUp.lean`'s `logup_rbrWide`), error `luEps`;
* `sumcheckSP`: a slot's sumcheck, one `challenge_fp2` squeeze per round (`FSSumcheck.lean`'s `sumcheck_rbr`, carried
  to digests by `rbrWide_of_rbrSound`), error `d/|F|·(1 + p/2^128)²`;
* `mleSP`: a random evaluation point read by `challenge_fp2_vec` (a zero-check's `τ`; the same lemma covers any slot
  point at which two tables' multilinear extensions are compared), error `ℓ/|F|·(1 + p/2^128)^(2ℓ)` (`mle_zero_prob`);
* `batchSP`: a batching vector (`μ`, `ν`), error `1/|F|·(1 + p/2^128)^(2k)` (`batch_prob`);
* `freeSP`: a challenge on which the state does not depend (the CFS coefficient `c`, whose masked claim `S + c·G` is
  false exactly when `S` is, for every `c`, once `G` is `M`'s claim), error `0`;
* `openingSP`: a regular PCS opening, `(λ, ρ)` then `J` (`FSOpening.lean`'s `opening_rbrWide` with the code's
  `lrCode`, `idxCode`), error `max(A/|E|·(1 + p/2^128)^(2·w0), ((N − (e + 1))/N)^Q)`. These are the soundness rounds for
  the matrix the statement names; the knowledge version (the matrix extracted from the log) is `FSOpening.lean`'s and is
  not composed here.
* `M`'s opening is NOT among them: its Fiat–Shamir rounds wait on the F12 fix, which changes `combined_weights`. It
  enters as ANY sub-protocol whose error is at most `2^-106` (`Kind8B.mask`), an assumption at the count's figure
  (`M`'s whole interactive term is `2^-106.248`).

**What is proved.**
* `rbrWide_of_rbrSound`, `sumcheck_rbrWide_code`, `mle_rbrWide`, `batch_rbrWide`, `free_rbrWide`: the rounds above on
  digests.
* `Kind8B`: the sub-protocols at the 8B T128 W16R2 parameters (`|F| = p²`, `p = 2^64 − 2^32 + 1`; LogUp with
  `N_lk = 34,897,920` lookups and `T_d = 127,668` table tuples; the openings with `N = 2^15`, `e = 8,052`, `Q = 280`,
  `A ≤ N`; sumcheck degree, point length and batch width at most `2^20`; `(λ, ρ)` width at most `2^40`), and `M` with
  error at most `2^-106`. `Kind8B.eps_le`: each has error at most `εRate8B = 135/2^110 ≈ 2^-102.92`; LogUp's is the
  largest (`luEps_8B_le`, `(N_lk + 2·T_d − 1)/p²·(1 + p/2^128)^4 ≈ 2^-102.933`).
* `fs_block_sound_8B`: **one block** (`blockSched`: LogUp, the slots' sub-protocols, `M`, the openings, in the code's
  order) on the chain: a false statement is accepted with probability at most
  `T·εRate8B + collBound T + collBound (T + 1)`, `T = q + ℓW + 1`. Per hash query: `2^-102.92`, under the approved
  `2^-100`.
* `fs_run_sound_8B`: **a run** of any number of blocks on one chain (`List.flatten` of the blocks' schedules): the
  same rate. More blocks only lengthen `ℓW`.
* `sound_le_target`, `fs_run_sound_8B_target`: in the approved target's own form, `εsTarget (max q (ℓW + 1))` for
  `q ≤ 2^76` (with `ℓW + 1 ≤ 2^76`). The verifier's own `ℓW + 1` hash queries count as attempts: below that many prover
  queries the bound is `εsTarget (ℓW + 1)`, not `εsTarget q` (finding F25).

**What is assumed** (premises of `fs_block_sound_8B`, `fs_run_sound_8B`): how the sub-protocols' claims fit together.
* `hframe`: a round never revives a sub-protocol it does not own, unless a later one is already doomed (claims are
  handed on only forward, and a sub-protocol's state before its window, `pend`, never revives);
* `hstart`: a false statement dooms some sub-protocol at the start;
* `hfinal`: the verifier rejects when some sub-protocol is doomed at the end.
These are the arithmetization (`CircuitIff`, step L2) and the extraction of the committed tables, not formalized for
the block. `M`'s error is assumed. The D55 fork-join is not one chain (forks run on transcripts rebuilt from a common
state and joined by absorbing their end states), so it is not covered (finding F26).
-/
import ZK60Formal.FSCompose
import ZK60Formal.FSLogUp
import ZK60Formal.FSOpening
import ZK60Formal.SoundZeroCheck

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset Prob Code

/-! ## One challenge per round, on digests -/

section Bridge

variable {X M Ch Mf D : Type} [Fintype D] [Nonempty D]

/-- **One challenge per round**, read from the round's first digest through `chal`. -/
def chalTr (chal : D → Ch) (d₀ : D) (τ : List (M × List D)) : List (M × Ch) :=
  τ.map (fun e => (e.1, chal (e.2.headD d₀)))

/-- **From one challenge per round to digests.** A protocol that is `RbrSound` with `e` escaping challenges per round,
each challenge read through `chal` (at most `K` digests per value) from a round of one squeeze, is `RbrWide` with
width `1` and error `e·K/|D|`. -/
theorem rbrWide_of_rbrSound [DecidableEq Ch] {n e : ℕ} {L : X → Prop} {accept : X → List (M × Ch) → Mf → Prop}
    {St : X → List (M × Ch) → Prop} (hR : RbrSound n L accept St e) (chal : D → Ch) (K : ℕ)
    (hK : ∀ c, (univ.filter (fun dg : D => chal dg = c)).card ≤ K) (d₀ : D) :
    RbrWide n (fun _ => 1) (fun x τ => St x (chalTr chal d₀ τ)) (((e * K : ℕ) : ℝ≥0∞) / Fintype.card D) where
  round x τ m hτ hns := by
    have hτ' : (chalTr chal d₀ τ).length < n := by rw [chalTr, List.length_map]; exact hτ
    have hE := (hR.round x (chalTr chal d₀ τ) m hτ' hns).comap chal hK
    show (PMF.uniformOfFintype (Fin 1 → D)).toOuterMeasure
      {b | St x (chalTr chal d₀ (τ ++ [(m, List.ofFn b)]))} ≤ _
    have hset : {b : Fin 1 → D | St x (chalTr chal d₀ (τ ++ [(m, List.ofFn b)]))}
        = {b | St x (chalTr chal d₀ τ ++ [(m, chal (Equiv.funUnique (Fin 1) D b))])} := by
      ext b
      simp [chalTr, List.ofFn_succ, Equiv.funUnique_apply, Fin.default_eq_zero]
    rw [hset, prob_equiv_comp (Equiv.funUnique (Fin 1) D) (fun dg => St x (chalTr chal d₀ τ ++ [(m, chal dg)]))]
    exact hE.prob_le

end Bridge

/-! ## The sumcheck, one `challenge_fp2` squeeze per round -/

section SumcheckCode

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {d : ℕ} {X : Type}

/-- **The sumcheck's state on digest transcripts**, the challenges read by the code's `challenge_fp2`. -/
def scStW (p : ℕ) (ι : ZMod p × ZMod p ≃ F) {n : ℕ} (stmt : X → ((Fin n → F) → F) × F) (d₀ : Dg) (x : X)
    (τ : List ((Fin (d + 1) → F) × List Dg)) : Prop :=
  ¬ IndDegLE d (stmt x).1 ∨ scState (chalTr (fp2Field p (2 ^ 128) ι) d₀ τ) n (stmt x).1 (stmt x).2

/-- **The sumcheck on digests**, with the code's `challenge_fp2`: per-round error `d/|F|·(1 + p/2^128)²`. -/
theorem sumcheck_rbrWide_code {n p : ℕ} [NeZero p] (hd : d < ringChar F) (ι : ZMod p × ZMod p ≃ F)
    (stmt : X → ((Fin n → F) → F) × F) (d₀ : Dg) :
    RbrWide n (fun _ => 1) (scStW (d := d) p ι stmt d₀)
      ((d : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2) := by
  have : Nonempty F := ⟨0⟩
  have hF : Fintype.card F = p ^ 2 := by
    rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]
  refine (rbrWide_of_rbrSound (sumcheck_rbr hd stmt) (fp2Field p (2 ^ 128) ι) ((2 ^ 128 / p + 1) ^ 2)
    (card_fp2Field_fiber_le (2 ^ 128) p ι) d₀).mono ?_
  rw [div_card_eq_mul_bias (Ch := F)]
  gcongr
  exact biasFactor_fp2_le (2 ^ 128) p hF

end SumcheckCode

/-! ## One-round sub-protocols: an evaluation point, a batching vector, a free challenge -/

section OneRound

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {Y M : Type}

/-- **An evaluation-point round** (a zero-check's `τ`, or any point at which a table's multilinear extension is
checked): alive before iff the table `P y` vanishes on the cube; after, iff its multilinear extension vanishes at the
point the round's `ℓ` digests derive (`challenge_fp2_vec`). -/
def mleSt (p : ℕ) (ι : ZMod p × ZMod p ≃ F) {ℓ : ℕ} (P : Y → (Fin ℓ → Bool) → F) (d₀ : Dg) (y : Y) :
    List (M × List Dg) → Prop
  | [(_, ds)] => mleAt (P y) (fun j => fp2Field p (2 ^ 128) ι (vecOf d₀ ℓ ds j)) = 0
  | _ => ∀ b, P y b = 0

/-- **The evaluation point is round-by-round sound**: error `ℓ/|F|·(1 + p/2^128)^(2ℓ)` (`mle_zero_prob`). -/
theorem mle_rbrWide (p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F) {ℓ : ℕ} (P : Y → (Fin ℓ → Bool) → F) (d₀ : Dg) :
    RbrWide (M := M) 1 (fun _ => ℓ) (mleSt p ι P d₀)
      ((ℓ : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * ℓ)) where
  round y τ m hτ hns := by
    have : Nonempty F := ⟨0⟩
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    have hP' : ¬ ∀ b, P y b = 0 := hns
    have hP : ∃ b, P y b ≠ 0 := not_forall.mp hP'
    show (PMF.uniformOfFintype (Fin ℓ → Dg)).toOuterMeasure {b | mleSt p ι P d₀ y ([] ++ [(m, List.ofFn b)])} ≤ _
    have hset : {b : Fin ℓ → Dg | mleSt p ι P d₀ y ([] ++ [(m, List.ofFn b)])}
        = {b | (fun c : Fin ℓ → F => mleAt (P y) c = 0) (fun j => fp2Field p (2 ^ 128) ι (b j))} := by
      ext b
      simp only [Set.mem_ofPred_eq, List.nil_append, mleSt, vecOf_ofFn]
    rw [hset]
    exact (prob_fp2_vec_le p ι ℓ _).trans (mul_le_mul' (mle_zero_prob (P y) hP) le_rfl)

/-- **A batching round** (`μ`, `ν`): alive before iff every relation `R y i` vanishes everywhere; after, iff their
combination with the `k` coefficients the round's digests derive vanishes everywhere. -/
def batchSt (p : ℕ) (ι : ZMod p × ZMod p ≃ F) {k : ℕ} {β : Type} (R : Y → Fin k → β → F) (d₀ : Dg) (y : Y) :
    List (M × List Dg) → Prop
  | [(_, ds)] => ∀ z, ∑ i, fp2Field p (2 ^ 128) ι (vecOf d₀ k ds i) * R y i z = 0
  | _ => ∀ i z, R y i z = 0

/-- **The batching round is round-by-round sound**: error `1/|F|·(1 + p/2^128)^(2k)` (`batch_prob`). -/
theorem batch_rbrWide (p : ℕ) [NeZero p] (ι : ZMod p × ZMod p ≃ F) {k : ℕ} {β : Type} (R : Y → Fin k → β → F)
    (d₀ : Dg) :
    RbrWide (M := M) 1 (fun _ => k) (batchSt p ι R d₀)
      ((1 : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * k)) where
  round y τ m hτ hns := by
    classical
    have : Nonempty F := ⟨0⟩
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    have hR' : ¬ ∀ i z, R y i z = 0 := hns
    obtain ⟨i₀, hi₀⟩ := not_forall.mp hR'
    obtain ⟨z₀, hz⟩ := not_forall.mp hi₀
    show (PMF.uniformOfFintype (Fin k → Dg)).toOuterMeasure {b | batchSt p ι R d₀ y ([] ++ [(m, List.ofFn b)])} ≤ _
    have hsub : {b : Fin k → Dg | batchSt p ι R d₀ y ([] ++ [(m, List.ofFn b)])}
        ⊆ {b | (fun c : Fin k → F => ∑ i, c i * R y i z₀ = 0) (fun j => fp2Field p (2 ^ 128) ι (b j))} := by
      intro b hb
      simp only [Set.mem_ofPred_eq, List.nil_append, batchSt, vecOf_ofFn] at hb ⊢
      exact hb z₀
    refine (MeasureTheory.measure_mono hsub).trans ?_
    exact (prob_fp2_vec_le p ι k _).trans (mul_le_mul' (batch_prob (fun i => R y i z₀) ⟨i₀, hz⟩) le_rfl)

/-- **A free challenge**: the state does not depend on the round's digests. -/
def freeSt {D : Type} (P : Y → Prop) (y : Y) (_ : List (M × List D)) : Prop := P y

/-- A free challenge never revives a doomed state: error `0`. -/
theorem free_rbrWide {D : Type} [Fintype D] [Nonempty D] (n : ℕ) (w : ℕ → ℕ) (P : Y → Prop) :
    RbrWide n w (freeSt (M := M) (D := D) P) 0 where
  round y τ m _ hns := by
    have hE : {b : Fin (w τ.length) → D | freeSt (M := M) P y (τ ++ [(m, List.ofFn b)])} = ∅ :=
      Set.eq_empty_iff_forall_notMem.mpr (fun _ hb => hns hb)
    rw [hE, MeasureTheory.measure_empty]

end OneRound

/-! ## The sub-protocols of a block, as schedule components -/

section Components

variable {X M : Type}

/-- **LogUp** in a schedule: two rounds with no message, widths `2` and `1`. -/
noncomputable def logupSP {F : Type} [Field F] [Fintype F] [DecidableEq F] {ι π κ : Type} [Fintype ι] [Fintype π]
    [Fintype κ] (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (T : κ → Tup F)
    (lu : X × List (M × List Dg) → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (pend post : X → List (M × List Dg) → Prop) :
    SubProt X M Dg where
  n := 2
  w := luW
  hasMsg := luMsg
  ε := luEps (ι := ι) (π := π) p T
  St := fun y τ => luSt (fp2Field p (2 ^ 128) eF) T lu (id y) (τ.map (fun e => ((fun _ : M => ()) e.1, e.2)))
  rbr := (logup_rbrWide p eF T lu).comap id (fun _ : M => ())
  pend := pend
  post := post

/-- **A slot's sumcheck** in a schedule: `n` rounds, each a message and one squeeze. -/
noncomputable def sumcheckSP {F : Type} [Field F] [Fintype F] [DecidableEq F] {d n : ℕ} (p : ℕ) [NeZero p]
    (hd : d < ringChar F) (ι : ZMod p × ZMod p ≃ F) (stmt : X × List (M × List Dg) → ((Fin n → F) → F) × F)
    (g : M → (Fin (d + 1) → F)) (d₀ : Dg) (pend post : X → List (M × List Dg) → Prop) : SubProt X M Dg where
  n := n
  w := fun _ => 1
  hasMsg := fun _ => true
  ε := (d : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
  St := fun y τ => scStW (d := d) p ι stmt d₀ (id y) (τ.map (fun e => (g e.1, e.2)))
  rbr := (sumcheck_rbrWide_code hd ι stmt d₀).comap id g
  pend := pend
  post := post

/-- **An evaluation point** in a schedule: one round of `ℓ` squeezes, with or without a message. -/
noncomputable def mleSP {F : Type} [Field F] [Fintype F] [DecidableEq F] {ℓ : ℕ} (p : ℕ) [NeZero p]
    (ι : ZMod p × ZMod p ≃ F) (P : X × List (M × List Dg) → (Fin ℓ → Bool) → F) (d₀ : Dg) (msg : Bool)
    (pend post : X → List (M × List Dg) → Prop) : SubProt X M Dg where
  n := 1
  w := fun _ => ℓ
  hasMsg := fun _ => msg
  ε := (ℓ : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * ℓ)
  St := mleSt p ι P d₀
  rbr := mle_rbrWide p ι P d₀
  pend := pend
  post := post

/-- **A batching vector** in a schedule: one round of `k` squeezes. -/
noncomputable def batchSP {F : Type} [Field F] [Fintype F] [DecidableEq F] {k : ℕ} {β : Type} (p : ℕ) [NeZero p]
    (ι : ZMod p × ZMod p ≃ F) (R : X × List (M × List Dg) → Fin k → β → F) (d₀ : Dg) (msg : Bool)
    (pend post : X → List (M × List Dg) → Prop) : SubProt X M Dg where
  n := 1
  w := fun _ => k
  hasMsg := fun _ => msg
  ε := (1 : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * k)
  St := batchSt p ι R d₀
  rbr := batch_rbrWide p ι R d₀
  pend := pend
  post := post

/-- **Free challenges** in a schedule: rounds whose state does not depend on them. -/
noncomputable def freeSP (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (P : X × List (M × List Dg) → Prop)
    (pend post : X → List (M × List Dg) → Prop) : SubProt X M Dg where
  n := n
  w := w
  hasMsg := hasMsg
  ε := 0
  St := freeSt P
  rbr := free_rbrWide n w P
  pend := pend
  post := post

/-- **A regular opening** in a schedule: `(λ, ρ)` (`w0` squeezes, no message), then the clear vectors and `J` (`m`
squeezes), with the code's derivations, for the matrix `Ux` the statement names (soundness rounds). -/
noncomputable def openingSP {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ]
    [Fintype μ] [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ} (p : ℕ) [NeZero p]
    (eF : ZMod p × ZMod p ≃ F) (hh : h ≤ 64) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F))
    (henc : Function.Injective enc) {dmin e A : ℕ} (hd : MinDist (LinearMap.range enc) dmin) (h2 : 2 * e < dmin)
    (hA : e + 1 ≤ A) (hca : CAOn Unit (LinearMap.range enc) e A)
    (clOf : X × List (M × List Dg) → OClaims Cl G κ μ F) {w0 m nQ : ℕ} (hnQ : nQ ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ)
    (Ux : X × List (M × List Dg) → κ → Fin (2 ^ h) → F) (g : M → OMsg G μ F) (d₀ : Dg)
    (pend post : X → List (M × List Dg) → Prop) : SubProt X M Dg where
  n := 2
  w := opW w0 m
  hasMsg := opMsg
  ε := max ((A : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0))
      ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * 1)
  St := fun y τ => opSt enc e clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) (Ux (id y)) (id y)
    (τ.map (fun e' => (g e'.1, e'.2)))
  rbr := by
    have : Nonempty F := ⟨eF 0⟩
    exact (opening_rbrWide enc henc hd h2 hA hca clOf d₀ w0 m (lrCode p eF eLR) (idxCode h hnQ) _ 1
      (lrCode_prob_le p eF eLR) (idxCode_prob_le hh hnQ) Ux).comap id g
  pend := pend
  post := post

end Components

/-! ## Numbers -/

section Numbers

/-- **Goldilocks**, `p = 2^64 − 2^32 + 1`. -/
abbrev goldP : ℕ := 18446744069414584321

theorem goldP_eq : goldP = 2 ^ 64 - 2 ^ 32 + 1 := by norm_num [goldP]

instance goldP_neZero : NeZero goldP := ⟨by norm_num [goldP]⟩

/-- **The per-query rate** at the 8B T128 W16R2 parameters: `135/2^110 ≈ 2^-102.92`. -/
noncomputable def εRate8B : ℝ≥0∞ := ((135 : ℕ) : ℝ≥0∞) / ((2 ^ 110 : ℕ) : ℝ≥0∞)

/-- Fractions of naturals compare by cross-multiplication. -/
theorem natCast_div_le_div {x y u v : ℕ} (hy : y ≠ 0) (hv : v ≠ 0) (h : x * v ≤ u * y) :
    (x : ℝ≥0∞) / y ≤ (u : ℝ≥0∞) / v := by
  have hy' : (y : ℝ≥0∞) ≠ 0 := by exact_mod_cast hy
  have hv' : (v : ℝ≥0∞) ≠ 0 := by exact_mod_cast hv
  rw [ENNReal.le_div_iff_mul_le (Or.inl hv') (Or.inl (ENNReal.natCast_ne_top v)), ← ENNReal.mul_div_right_comm,
    ENNReal.div_le_iff hy' (ENNReal.natCast_ne_top y)]
  exact_mod_cast h

/-- A product of fractions of naturals. -/
theorem natCast_div_mul_div (x y z w : ℕ) :
    (x : ℝ≥0∞) / y * ((z : ℝ≥0∞) / w) = ((x * z : ℕ) : ℝ≥0∞) / ((y * w : ℕ) : ℝ≥0∞) := by
  rw [div_eq_mul_inv, div_eq_mul_inv, div_eq_mul_inv, Nat.cast_mul, Nat.cast_mul,
    ENNReal.mul_inv (Or.inr (ENNReal.natCast_ne_top w)) (Or.inl (ENNReal.natCast_ne_top y))]
  ring

/-- A power of a fraction of naturals. -/
theorem natCast_div_pow (x y : ℕ) : ∀ k : ℕ,
    ((x : ℝ≥0∞) / y) ^ k = ((x ^ k : ℕ) : ℝ≥0∞) / ((y ^ k : ℕ) : ℝ≥0∞)
  | 0 => by simp
  | k + 1 => by rw [pow_succ, natCast_div_pow x y k, natCast_div_mul_div, pow_succ, pow_succ]

/-- `2^-k` as a fraction. -/
theorem inv_two_pow_eq (k : ℕ) : (2⁻¹ : ℝ≥0∞) ^ k = ((1 : ℕ) : ℝ≥0∞) / ((2 ^ k : ℕ) : ℝ≥0∞) := by
  rw [← ENNReal.inv_pow, Nat.cast_one, one_div, Nat.cast_pow, Nat.cast_ofNat]

/-- `1 + p/N` as a fraction. -/
theorem one_add_div_eq (p N : ℕ) (hN : N ≠ 0) :
    (1 : ℝ≥0∞) + (p : ℝ≥0∞) / (N : ℝ≥0∞) = ((N + p : ℕ) : ℝ≥0∞) / (N : ℝ≥0∞) := by
  have hN0 : (N : ℝ≥0∞) ≠ 0 := by exact_mod_cast hN
  rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 (ENNReal.natCast_ne_top N)]

/-- **A Bernoulli bound from above**: `(1 + x)^k ≤ 1 + 2kx` while `2kx ≤ 1`. -/
theorem one_add_pow_le (x : ℝ≥0∞) : ∀ k : ℕ, 2 * (k : ℝ≥0∞) * x ≤ 1 → (1 + x) ^ k ≤ 1 + 2 * (k : ℝ≥0∞) * x
  | 0, _ => by simp
  | k + 1, h => by
    have hk : 2 * (k : ℝ≥0∞) * x ≤ 1 :=
      le_trans (mul_le_mul' (mul_le_mul' le_rfl (by exact_mod_cast Nat.le_succ k :
        (k : ℝ≥0∞) ≤ ((k + 1 : ℕ) : ℝ≥0∞))) le_rfl) h
    calc (1 + x) ^ (k + 1) = (1 + x) ^ k * (1 + x) := pow_succ _ _
      _ ≤ (1 + 2 * (k : ℝ≥0∞) * x) * (1 + x) := by gcongr; exact one_add_pow_le x k hk
      _ = 1 + 2 * (k : ℝ≥0∞) * x + x + (2 * (k : ℝ≥0∞) * x) * x := by ring
      _ ≤ 1 + 2 * (k : ℝ≥0∞) * x + x + 1 * x := by gcongr
      _ = 1 + 2 * ((k + 1 : ℕ) : ℝ≥0∞) * x := by push_cast; ring

/-- **The code's `challenge_fp2` bias, many times over**: `(1 + p/2^128)^k ≤ 2` for `p ≤ 2^64` and `k ≤ 2^62`. -/
theorem fp2_bias_pow_le_two {p k : ℕ} (hp : p ≤ 2 ^ 64) (hk : k ≤ 2 ^ 62) :
    (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k ≤ 2 := by
  have hx : 2 * (k : ℝ≥0∞) * ((p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ≤ 1 := by
    rw [← mul_div_assoc, show (2 : ℝ≥0∞) * k * p = ((2 * k * p : ℕ) : ℝ≥0∞) by push_cast; ring,
      ENNReal.div_le_iff (by positivity) (ENNReal.natCast_ne_top _), one_mul]
    have : 2 * k * p ≤ 2 ^ 128 := by
      calc 2 * k * p ≤ 2 * 2 ^ 62 * 2 ^ 64 := by gcongr
        _ ≤ 2 ^ 128 := by norm_num
    exact_mod_cast this
  calc (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k
      ≤ 1 + 2 * (k : ℝ≥0∞) * ((p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) := one_add_pow_le _ k hx
    _ ≤ 1 + 1 := by gcongr
    _ = 2 := one_add_one_eq_two

/-- **A small numerator** over `p²` with the bias at most `2`: at most `2^21/p² ≤ εRate8B`. -/
theorem small_eps_le {F : Type} [Fintype F] (hF : Fintype.card F = goldP ^ 2) {a k : ℕ} (ha : a ≤ 2 ^ 20)
    (hk : k ≤ 2 ^ 62) :
    (a : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k ≤ εRate8B := by
  calc (a : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ k
      ≤ ((2 ^ 20 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' (ENNReal.div_le_div_right (by exact_mod_cast ha) _)
          (by exact_mod_cast fp2_bias_pow_le_two (by norm_num [goldP]) hk)
    _ = ((2 ^ 20 * 2 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ εRate8B := natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])

/-- **LogUp at the 8B T128 parameters**: `(N_lk + 2·T_d − 1)/p²·(1 + p/2^128)^4 ≤ 135/2^110`, `N_lk = 34,897,920`,
`T_d = 127,668` (the exact value is `2^-102.933`). -/
theorem luEps_8B_le {F : Type} [Field F] [Fintype F] [DecidableEq F] {ι π κ : Type} [Fintype ι] [Fintype π]
    [Fintype κ] (T : κ → Tup F) (hF : Fintype.card F = goldP ^ 2)
    (hN : Fintype.card ι + 2 * Fintype.card π = 34897920) (hM : (univ.image T).card = 127668) :
    luEps (ι := ι) (π := π) goldP T ≤ εRate8B := by
  rw [luEps, hN, hM, hF, one_add_div_eq goldP (2 ^ 128) (by norm_num), natCast_div_pow, natCast_div_mul_div]
  exact natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])

/-- The column term at W16R2 against the rate, in naturals: `24715^280·2^110 ≤ 135·32768^280` (the exponent is split
so that each power evaluated stays under the elaborator's threshold). -/
theorem col_W16R2_nat : (2 ^ 15 - (8052 + 1)) ^ 280 * 2 ^ 110 ≤ 135 * (2 ^ 15) ^ 280 := by
  rw [show (280 : ℕ) = 140 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- **The regular opening at W16R2** (`N = 2^15`, `e = 8,052`, `Q = 280`, `A ≤ N`, `w0 ≤ 2^40`): field term
`≤ 2^-112`, column term `((2^15 − 8053)/2^15)^280 ≈ 2^-113.93`; both at most `135/2^110`. -/
theorem opening_eps_W16R2_le {F : Type} [Fintype F] (hF : Fintype.card F = goldP ^ 2) {A w0 : ℕ}
    (hA : A ≤ 2 ^ 15) (hw0 : w0 ≤ 2 ^ 40) :
    max ((A : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0))
      ((((Fintype.card (Fin (2 ^ 15)) - (8052 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 15))) ^ 280 * 1)
      ≤ εRate8B := by
  refine max_le (small_eps_le hF (hA.trans (by norm_num)) ((Nat.mul_le_mul_left 2 hw0).trans (by norm_num))) ?_
  rw [mul_one, Fintype.card_fin, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) col_W16R2_nat

/-- `M`'s assumed error, `2^-106`, is under the rate. -/
theorem mask_eps_le : (2⁻¹ : ℝ≥0∞) ^ 106 ≤ εRate8B := by
  rw [inv_two_pow_eq]
  exact natCast_div_le_div (by norm_num) (by norm_num) (by norm_num)

/-- **The rate is under the approved target's** `2^-100` (and under `2^-102`). -/
theorem εRate8B_le : εRate8B ≤ (2⁻¹ : ℝ≥0∞) ^ 102 := by
  rw [inv_two_pow_eq]
  exact natCast_div_le_div (by norm_num) (by norm_num) (by norm_num)

end Numbers

/-! ## The sub-protocols at the 8B T128 W16R2 parameters -/

section Kinds

variable {X M : Type}

/-- **The sub-protocols of a block at the 8B T128 W16R2 parameters.** Each constructor is a proved sub-protocol with
its numeric side conditions; `mask` is `M`'s opening, any sub-protocol with error at most `2^-106` (ASSUMED: its
Fiat–Shamir proof waits on the F12 fix). -/
inductive Kind8B : SubProt X M Dg → Prop
  | logup {F ι π κ : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype ι] [Fintype π] [Fintype κ]
      (eF : ZMod goldP × ZMod goldP ≃ F) (T : κ → Tup F)
      (lu : X × List (M × List Dg) → (ι ⊕ (π ⊕ π) → Tup F) × (κ → F)) (pend post : X → List (M × List Dg) → Prop)
      (hN : Fintype.card ι + 2 * Fintype.card π = 34897920) (hM : (univ.image T).card = 127668) :
      Kind8B (logupSP goldP eF T lu pend post)
  | sumcheck {F : Type} [Field F] [Fintype F] [DecidableEq F] {d n : ℕ} (hd : d < ringChar F)
      (eF : ZMod goldP × ZMod goldP ≃ F) (stmt : X × List (M × List Dg) → ((Fin n → F) → F) × F)
      (g : M → (Fin (d + 1) → F)) (d₀ : Dg) (pend post : X → List (M × List Dg) → Prop) (hd20 : d ≤ 2 ^ 20) :
      Kind8B (sumcheckSP goldP hd eF stmt g d₀ pend post)
  | mle {F : Type} [Field F] [Fintype F] [DecidableEq F] {ℓ : ℕ} (eF : ZMod goldP × ZMod goldP ≃ F)
      (P : X × List (M × List Dg) → (Fin ℓ → Bool) → F) (d₀ : Dg) (msg : Bool)
      (pend post : X → List (M × List Dg) → Prop) (hℓ0 : 0 < ℓ) (hℓ : ℓ ≤ 2 ^ 20) :
      Kind8B (mleSP goldP eF P d₀ msg pend post)
  | batch {F : Type} [Field F] [Fintype F] [DecidableEq F] {k : ℕ} {β : Type} (eF : ZMod goldP × ZMod goldP ≃ F)
      (R : X × List (M × List Dg) → Fin k → β → F) (d₀ : Dg) (msg : Bool)
      (pend post : X → List (M × List Dg) → Prop) (hk0 : 0 < k) (hk : k ≤ 2 ^ 40) :
      Kind8B (batchSP goldP eF R d₀ msg pend post)
  | free (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (P : X × List (M × List Dg) → Prop)
      (pend post : X → List (M × List Dg) → Prop) (hw : ∀ i, 0 < w i) :
      Kind8B (freeSP n w hasMsg P pend post)
  | opening {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
      [Fintype Cl] [DecidableEq Cl] [DecidableEq G] (eF : ZMod goldP × ZMod goldP ≃ F) (hh : 15 ≤ 64)
      (enc : (μ → F) →ₗ[F] (Fin (2 ^ 15) → F)) (henc : Function.Injective enc) {dmin A : ℕ}
      (hd : MinDist (LinearMap.range enc) dmin) (h2 : 2 * 8052 < dmin) (hA : 8052 + 1 ≤ A)
      (hca : CAOn Unit (LinearMap.range enc) 8052 A) (clOf : X × List (M × List Dg) → OClaims Cl G κ μ F)
      {w0 m : ℕ} (hnQ : 280 ≤ m * 4) (eLR : Fin w0 ≃ Cl ⊕ κ) (Ux : X × List (M × List Dg) → κ → Fin (2 ^ 15) → F)
      (g : M → OMsg G μ F) (d₀ : Dg) (pend post : X → List (M × List Dg) → Prop)
      (hA15 : A ≤ 2 ^ 15) (hw0 : w0 ≤ 2 ^ 40) (hw00 : 0 < w0) (hm : 0 < m) :
      Kind8B (openingSP goldP eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post)
  | mask (c : SubProt X M Dg) (hw : ∀ i, 0 < c.w i) (hc : c.ε ≤ (2⁻¹ : ℝ≥0∞) ^ 106) : Kind8B c

/-- A field in bijection with `ZMod p × ZMod p` has `p²` elements. -/
theorem card_eq_of_equiv {F : Type} [Fintype F] {p : ℕ} [NeZero p] (eF : ZMod p × ZMod p ≃ F) :
    Fintype.card F = p ^ 2 := by
  rw [← Fintype.card_congr eF, Fintype.card_prod, ZMod.card, sq]

/-- **Every sub-protocol of a block has error at most `εRate8B`.** -/
theorem Kind8B.eps_le {c : SubProt X M Dg} (h : Kind8B c) : c.ε ≤ εRate8B := by
  cases h with
  | logup eF T lu pend post hN hM => exact luEps_8B_le T (card_eq_of_equiv eF) hN hM
  | sumcheck hd eF stmt g d₀ pend post hd20 => exact small_eps_le (card_eq_of_equiv eF) hd20 (by norm_num)
  | mle eF P d₀ msg pend post hℓ0 hℓ =>
      exact small_eps_le (card_eq_of_equiv eF) hℓ ((Nat.mul_le_mul_left 2 hℓ).trans (by norm_num))
  | batch eF R d₀ msg pend post hk0 hk =>
      have h1 := small_eps_le (a := 1) (card_eq_of_equiv eF) (by norm_num)
        ((Nat.mul_le_mul_left 2 hk).trans (by norm_num))
      rw [Nat.cast_one] at h1
      exact h1
  | free n w hasMsg P pend post hw => exact zero_le
  | opening eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post hA15 hw0 hw00 hm =>
      exact opening_eps_W16R2_le (card_eq_of_equiv eF) hA15 hw0
  | mask c hw hc => exact hc.trans mask_eps_le

/-- **Every sub-protocol of a block squeezes at least once per round.** -/
theorem Kind8B.w_pos {c : SubProt X M Dg} (h : Kind8B c) : ∀ i, 0 < c.w i := by
  cases h with
  | logup eF T lu pend post hN hM => exact luW_pos
  | sumcheck hd eF stmt g d₀ pend post hd20 => exact fun _ => one_pos
  | mle eF P d₀ msg pend post hℓ0 hℓ => exact fun _ => hℓ0
  | batch eF R d₀ msg pend post hk0 hk => exact fun _ => hk0
  | free n w hasMsg P pend post hw => exact hw
  | opening eF hh enc henc hd h2 hA hca clOf hnQ eLR Ux g d₀ pend post hA15 hw0 hw00 hm => exact opW_pos hw00 hm
  | mask c hw hc => exact hw

end Kinds

/-! ## One block and a run, on the chain -/

section BlockRun

variable {X M Q : Type} [Fintype Q] [DecidableEq Q]

/-- **One block's schedule, in the code's order** (`private_block/protocol.rs`, `verify_core`): LogUp's `(β, γ)`
and `α` (after the header and the `A`, `M` roots); the slots, each its own list of sub-protocols (its `define`
challenges, `c`, its sumcheck rounds); `M`'s opening; the openings of `A` and `H`; the endpoint openings (a single
block's `In` and `Out`; in a D12a run the run verifier opens the boundary roots instead). -/
def blockSched (lu : SubProt X M Dg) (slots : List (List (SubProt X M Dg))) (mOpen aOpen hOpen : SubProt X M Dg)
    (ends : List (SubProt X M Dg)) : List (SubProt X M Dg) :=
  lu :: slots.flatten ++ mOpen :: aOpen :: hOpen :: ends

/-- **One block on the chain, at the 8B T128 W16R2 parameters.** If every sub-protocol is one of `Kind8B` (the proved
LogUp, sumcheck, evaluation-point, batching, free and opening rounds, and `M` with its ASSUMED error `≤ 2^-106`), and
the claims fit together (`hframe`, `hstart`, `hfinal`), a prover making at most `q` hash queries gets a false
statement accepted with probability at most `T·εRate8B + collBound T + collBound (T + 1)`, `T = q + ℓW + 1`:
per hash query `135/2^110 ≈ 2^-102.92`. -/
theorem fs_block_sound_8B (cs : List (SubProt X M Dg)) (hk : ∀ c ∈ cs, Kind8B c) {m₀ : M}
    (C : ChainEnc (PItem X M) Q Dg) {Mf : Type} {L : X → Prop} {accept : X → List (M × List Dg) → Mf → Prop}
    (hframe : ∀ k x τ m (b : Fin (wOf cs τ.length) → Dg), τ.length < nOf cs → ownOf cs τ.length ≠ k →
      ¬ SOf cs k x τ → SOf cs k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf cs k' x τ)
    (hstart : ∀ x, ¬ L x → ∃ k, ¬ SOf cs k x [])
    (hfinal : ∀ x τ mf, τ.length = nOf cs → (∃ k, ¬ SOf cs k x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q Dg (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOf cs) (wOf cs) (wOf_pos cs (fun c hc => (hk c hc).w_pos)) (msgOf cs) m₀ accept C H
          (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW (nOf cs) (wOf cs) + 1 : ℕ) : ℝ≥0∞) * εRate8B + collBound (q + ℓW (nOf cs) (wOf cs) + 1) Dg
        + collBound (q + ℓW (nOf cs) (wOf cs) + 1 + 1) Dg :=
  fs_chain_sound_sched cs (fun c hc => (hk c hc).w_pos) C εRate8B (fun c hc => (hk c hc).eps_le) hframe hstart
    hfinal q A hA

/-- The sub-protocols of a run are those of its blocks. -/
theorem Kind8B_flatten (blocks : List (List (SubProt X M Dg))) (hk : ∀ b ∈ blocks, ∀ c ∈ b, Kind8B c) :
    ∀ c ∈ blocks.flatten, Kind8B c := by
  intro c hc
  obtain ⟨b, hb, hcb⟩ := List.mem_flatten.mp hc
  exact hk b hb c hcb

/-- **A run of blocks on one chain** (D12a: one transcript threaded through every stage): the schedules of the blocks
one after the other. The per-query rate is the same as one block's, `εRate8B`; the blocks only lengthen `ℓW`. -/
theorem fs_run_sound_8B (blocks : List (List (SubProt X M Dg))) (hk : ∀ b ∈ blocks, ∀ c ∈ b, Kind8B c) {m₀ : M}
    (C : ChainEnc (PItem X M) Q Dg) {Mf : Type} {L : X → Prop} {accept : X → List (M × List Dg) → Mf → Prop}
    (hframe : ∀ k x τ m (b : Fin (wOf blocks.flatten τ.length) → Dg), τ.length < nOf blocks.flatten →
      ownOf blocks.flatten τ.length ≠ k → ¬ SOf blocks.flatten k x τ →
      SOf blocks.flatten k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf blocks.flatten k' x τ)
    (hstart : ∀ x, ¬ L x → ∃ k, ¬ SOf blocks.flatten k x [])
    (hfinal : ∀ x τ mf, τ.length = nOf blocks.flatten → (∃ k, ¬ SOf blocks.flatten k x τ) → ¬ accept x τ mf)
    (q : ℕ) (A : OC Q Dg (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOf blocks.flatten) (wOf blocks.flatten)
          (wOf_pos blocks.flatten (fun c hc => (Kind8B_flatten blocks hk c hc).w_pos)) (msgOf blocks.flatten) m₀
          accept C H
          (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ ((q + ℓW (nOf blocks.flatten) (wOf blocks.flatten) + 1 : ℕ) : ℝ≥0∞) * εRate8B
        + collBound (q + ℓW (nOf blocks.flatten) (wOf blocks.flatten) + 1) Dg
        + collBound (q + ℓW (nOf blocks.flatten) (wOf blocks.flatten) + 1 + 1) Dg :=
  fs_block_sound_8B blocks.flatten (Kind8B_flatten blocks hk) C hframe hstart hfinal q A hA

end BlockRun

/-! ## In the approved target's form -/

section Target

/-- `collBound` grows with the query count. -/
theorem collBound_mono {D : Type} [Fintype D] {a b : ℕ} (h : a ≤ b) : collBound a D ≤ collBound b D := by
  unfold collBound
  exact ENNReal.div_le_div_right (by exact_mod_cast Nat.div_le_div_right (Nat.mul_le_mul h (Nat.sub_le_sub_right h 1))) _

/-- The two chain terms over 256-bit digests stay under `2^-100` while `T ≤ 2^77`. -/
theorem collBound_pair_le {T : ℕ} (hT : T ≤ 2 ^ 77) :
    collBound T Dg + collBound (T + 1) Dg ≤ (2⁻¹ : ℝ≥0∞) ^ 100 := by
  unfold collBound
  rw [ENNReal.div_add_div_same, ← Nat.cast_add, inv_two_pow_eq,
    show Fintype.card Dg = 2 ^ 128 * 2 ^ 128 by simp [Dg]]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  have h1 : T * (T - 1) / 2 ≤ 2 ^ 77 * 2 ^ 77 :=
    (Nat.div_le_self _ _).trans (Nat.mul_le_mul hT ((Nat.sub_le T 1).trans hT))
  have h2 : (T + 1) * (T + 1 - 1) / 2 ≤ (2 ^ 77 + 1) * 2 ^ 77 :=
    (Nat.div_le_self _ _).trans (Nat.mul_le_mul (Nat.add_le_add_right hT 1) (by rw [Nat.add_sub_cancel]; exact hT))
  calc (T * (T - 1) / 2 + (T + 1) * (T + 1 - 1) / 2) * 2 ^ 100
      ≤ (2 ^ 77 * 2 ^ 77 + (2 ^ 77 + 1) * 2 ^ 77) * 2 ^ 100 := by gcongr
    _ ≤ 1 * (2 ^ 128 * 2 ^ 128) := by norm_num

/-- **The bound in the approved target's form.** For `ℓ + 1 ≤ q ≤ 2^76` (a prover making at least as many hash queries
as the verifier's `ℓ + 1`), `(q + ℓ + 1)·εRate8B + collBound + collBound ≤ q·2^-100 + 2^-100 = εsTarget q`. -/
theorem sound_le_target {q ℓ : ℕ} (hq : ℓ + 1 ≤ q) (hq' : q ≤ 2 ^ 76) :
    ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * εRate8B + collBound (q + ℓ + 1) Dg + collBound (q + ℓ + 1 + 1) Dg
      ≤ εsTarget q := by
  rw [εsTarget]
  refine le_trans (le_of_eq (add_assoc _ _ _)) ?_
  refine add_le_add ?_ (collBound_pair_le (by rw [show (2 : ℕ) ^ 77 = 2 * 2 ^ 76 by norm_num]; omega))
  calc ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * εRate8B ≤ ((2 * q : ℕ) : ℝ≥0∞) * εRate8B :=
        mul_le_mul' (by exact_mod_cast (show q + ℓ + 1 ≤ 2 * q by omega)) le_rfl
    _ = (q : ℝ≥0∞) * ((2 : ℕ) * εRate8B) := by push_cast; ring
    _ ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 := by
        gcongr
        rw [εRate8B, inv_two_pow_eq, show ((2 : ℕ) : ℝ≥0∞) = ((2 : ℕ) : ℝ≥0∞) / ((1 : ℕ) : ℝ≥0∞) by simp,
          natCast_div_mul_div]
        exact natCast_div_le_div (by norm_num) (by norm_num) (by norm_num)

/-- **For every `q ≤ 2^76`**: the bound is at most `εsTarget (max q (ℓ + 1))`. A prover making fewer hash queries than
the verifier's own `ℓ + 1` is charged as if it made `ℓ + 1`. -/
theorem sound_le_target_max {q ℓ : ℕ} (hq : q ≤ 2 ^ 76) (hℓ : ℓ + 1 ≤ 2 ^ 76) :
    ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * εRate8B + collBound (q + ℓ + 1) Dg + collBound (q + ℓ + 1 + 1) Dg
      ≤ εsTarget (max q (ℓ + 1)) := by
  refine le_trans ?_ (sound_le_target (q := max q (ℓ + 1)) (le_max_right _ _) (max_le hq hℓ))
  exact add_le_add (add_le_add (mul_le_mul' (by exact_mod_cast (show q + ℓ + 1 ≤ max q (ℓ + 1) + ℓ + 1 by omega))
    le_rfl)
    (collBound_mono (by omega))) (collBound_mono (by omega))

variable {X M Q : Type} [Fintype Q] [DecidableEq Q]

/-- **A run on one chain, in the approved target's form**: with every sub-protocol of `Kind8B` and the claims fitting
together, a prover making at most `q ≤ 2^76` hash queries gets a false statement accepted with probability at most
`εsTarget (max q (ℓW + 1))`, `εsTarget q = q·2^-100 + 2^-100`, `ℓW` the verifier's chain length. -/
theorem fs_run_sound_8B_target (blocks : List (List (SubProt X M Dg))) (hk : ∀ b ∈ blocks, ∀ c ∈ b, Kind8B c)
    {m₀ : M} (C : ChainEnc (PItem X M) Q Dg) {Mf : Type} {L : X → Prop}
    {accept : X → List (M × List Dg) → Mf → Prop}
    (hframe : ∀ k x τ m (b : Fin (wOf blocks.flatten τ.length) → Dg), τ.length < nOf blocks.flatten →
      ownOf blocks.flatten τ.length ≠ k → ¬ SOf blocks.flatten k x τ →
      SOf blocks.flatten k x (τ ++ [(m, List.ofFn b)]) → ∃ k', k < k' ∧ ¬ SOf blocks.flatten k' x τ)
    (hstart : ∀ x, ¬ L x → ∃ k, ¬ SOf blocks.flatten k x [])
    (hfinal : ∀ x τ mf, τ.length = nOf blocks.flatten → (∃ k, ¬ SOf blocks.flatten k x τ) → ¬ accept x τ mf)
    (hℓ : ℓW (nOf blocks.flatten) (wOf blocks.flatten) + 1 ≤ 2 ^ 76)
    (q : ℕ) (hq : q ≤ 2 ^ 76) (A : OC Q Dg (X × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ L (A.run H).1
        ∧ chainAcceptsW (nOf blocks.flatten) (wOf blocks.flatten)
          (wOf_pos blocks.flatten (fun c hc => (Kind8B_flatten blocks hk c hc).w_pos)) (msgOf blocks.flatten) m₀
          accept C H
          (A.run H).1 (A.run H).2.1 (A.run H).2.2)
      ≤ εsTarget (max q (ℓW (nOf blocks.flatten) (wOf blocks.flatten) + 1)) :=
  (fs_run_sound_8B blocks hk C hframe hstart hfinal q A hA).trans (sound_le_target_max hq hℓ)

end Target

end ZK60.Sound
