/-
D63 step L19 (Statement 2, zero knowledge), part 5: the R-receipt hybrid with WEIGHTED budgets, so that the other
receipts' honest provers inside each step's context are charged at the rates of their own queries.

L14's `hstep_of_oneStep` charges request `j`'s context `q + j·qp` queries before the request and `q + R·qp` after it,
all at one rate. Here (`ZKCount.WB`, `ZKCountStep.OneStepW`):
* `pre_wb`: everything before request `j` (the distinguisher's `q` queries, each of weight at most `Km`, and `j`
  stand-in provers, each of weighted budget `Wp`) is within `q·Km + j·Wp`;
* `post_wb`: everything after it within `q·KUm + R·Wpa` (the later honest provers at their hidden-hit weights);
* `pre_cont`: request `j`'s continuation stays within the distinguisher's budget, so the context after the request is
  unchanged by a weighted truncation (`ctx₂W`, `ctx₂W_eq`);
* **`hstep_of_oneStepW`**: a weighted one-receipt bound `ε` gives hybrid `j` versus `j + 1` within
  `ε (q·Km + j·Wp) (q·KUm + R·Wpa)`, both ways;
* **`zeroKnowledge_of_oneStepW`**: with a per-step bound `e q R j` uniform over the weight sets, `ZeroKnowledge M P
  (fun q R => Σ_{j<R} e q R j)` with the stand-in simulator.

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKCountStep

namespace ZK60.ZKCount

open scoped ENNReal
open Finset ZK60.ZKW16 ZK60.ZKHybrid

section Hyb

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} (P : Protocol Q D Coins M) [Inhabited M.Input]
  (W : M.Weights) (pOC : M.Input → Coins → OC Q D (P.Stmt × P.Receipt))

omit [DecidableEq Q] in
/-- **The prefix's weighted budget**: the distinguisher's queries (each of weight at most `Km`) and `j − m` stand-in
provers (each within `Wp`). -/
theorem pre_wb (Kf : Q → ℕ) (Km Wp : ℕ) (hKm : ∀ z, Kf z ≤ Km) (hbd : ∀ x c, WB Kf (pOC x c) Wp) (j : ℕ)
    (d : ℕ → Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r → m ≤ j →
      WB Kf (pre P W pOC j d Dist m) (q * Km + (j - m) * Wp) := by
  intro Dist
  induction Dist with
  | ret b => intros; trivial
  | ask i k ih =>
    intro q r m hW hm
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        show WB Kf (OC.ask z (fun h => pre P W pOC j d (k (.inl h)) m)) ((q + 1) * Km + (j - m) * Wp)
        have hz := hKm z
        refine ⟨?_, fun o => (ih (.inl o) q r m (hW _) hm).mono ?_⟩
        · rw [add_mul, one_mul]
          omega
        · rw [add_mul, one_mul]
          omega
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        by_cases hmj : m < j
        · show WB Kf (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2).bind
            (fun o => pre P W pOC j d (k (.inr o)) (m + 1)) else .ret (.inr (x, k))) (q * Km + (j - m) * Wp)
          rw [ite_eq_left hmj]
          have hb := WB.bind (fun o => ih (.inr o) q r (m + 1) (hW _) hmj)
            (hbd (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2)
          refine hb.mono ?_
          have : j - m = (j - (m + 1)) + 1 := by omega
          rw [this, add_mul, one_mul]
          omega
        · show WB Kf (if m < j then (pOC (standin P W (M.publicPart (M.forward W x), P.leak x)) (d m).2).bind
            (fun o => pre P W pOC j d (k (.inr o)) (m + 1)) else .ret (.inr (x, k))) (q * Km + (j - m) * Wp)
          rw [ite_eq_right hmj]
          trivial

omit [DecidableEq Q] [Inhabited M.Input] in
/-- **The suffix's weighted budget**: the distinguisher's queries (each of weight at most `KUm`) and one prover per
remaining request (each within `Wpa`). -/
theorem post_wb (KUf : Q → ℕ) (KUm Wpa : ℕ) (hKUm : ∀ z, KUf z ≤ KUm) (hbd : ∀ x c, WB KUf (pOC x c) Wpa)
    (d : ℕ → Coins × Coins) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r →
      WB KUf (post P pOC d Dist m) (q * KUm + r * Wpa) := by
  intro Dist
  induction Dist with
  | ret b => intros; trivial
  | ask i k ih =>
    intro q r m hW
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        show WB KUf (OC.ask z (fun h => post P pOC d (k (.inl h)) m)) ((q + 1) * KUm + r * Wpa)
        have hz := hKUm z
        refine ⟨?_, fun o => (ih (.inl o) q r m (hW _)).mono ?_⟩
        · rw [add_mul, one_mul]
          omega
        · rw [add_mul, one_mul]
          omega
    | inr x =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        show WB KUf ((pOC x (d m).1).bind (fun o => post P pOC d (k (.inr o)) (m + 1))) (q * KUm + (r + 1) * Wpa)
        have hb := WB.bind (fun o => ih (.inr o) q r (m + 1) (hW _)) (hbd x (d m).1)
        refine hb.mono ?_
        rw [add_mul, one_mul]
        omega

omit [DecidableEq Q] in
/-- **Request `j`'s continuation stays within the budget**: if the prefix stops at request `j` with input `x` and
continuation `k`, every `k o` is within the distinguisher's budget `(q, r)`. -/
theorem pre_cont (j : ℕ) (d : ℕ → Coins × Coins) (H : Q → D) :
    ∀ (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q r m : ℕ), Dist.Within q r →
      ∀ (x : M.Input) (k : (D ⊕ (P.Stmt × P.Receipt)) → OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool),
        (pre P W pOC j d Dist m).run H = .inr (x, k) → ∀ o, (k o).Within q r := by
  intro Dist
  induction Dist with
  | ret b =>
    intro q r m _ x k h
    have e : (pre P W pOC j d (.ret b) m).run H = (Sum.inl b : PreRes P) := rfl
    rw [e] at h
    cases h
  | ask i k' ih =>
    intro q r m hW x k h
    cases i with
    | inl z =>
      cases q with
      | zero => simp [OC.Within] at hW
      | succ q =>
        simp only [OC.Within] at hW
        have e : (pre P W pOC j d (.ask (.inl z) k') m).run H = (pre P W pOC j d (k' (.inl (H z))) m).run H := rfl
        rw [e] at h
        exact fun o => within_mono (ih (.inl (H z)) q r m (hW _) x k h o) (Nat.le_succ q) le_rfl
    | inr x' =>
      cases r with
      | zero => simp [OC.Within] at hW
      | succ r =>
        simp only [OC.Within] at hW
        by_cases hmj : m < j
        · have e : (pre P W pOC j d (.ask (.inr x') k') m).run H
              = (pre P W pOC j d (k' (.inr ((pOC (standin P W (M.publicPart (M.forward W x'), P.leak x'))
                  (d m).2).run H))) (m + 1)).run H := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x'), P.leak x')) (d m).2).bind
              (fun o => pre P W pOC j d (k' (.inr o)) (m + 1)) else .ret (.inr (x', k'))).run H = _
            rw [ite_eq_left hmj, OC.run_bind]
          rw [e] at h
          exact fun o => within_mono (ih _ q r (m + 1) (hW _) x k h o) le_rfl (Nat.le_succ r)
        · have e : (pre P W pOC j d (.ask (.inr x') k') m).run H = (Sum.inr (x', k') : PreRes P) := by
            show (if m < j then (pOC (standin P W (M.publicPart (M.forward W x'), P.leak x')) (d m).2).bind
              (fun o => pre P W pOC j d (k' (.inr o)) (m + 1)) else .ret (.inr (x', k'))).run H = _
            rw [ite_eq_right hmj]
            rfl
          rw [e] at h
          cases h
          exact fun o => within_mono (hW o) le_rfl (Nat.le_succ r)

/-- **The context after request `j`, weighted-truncated** at the budget `W₂`. -/
noncomputable def ctx₂W (KUf : Q → ℕ) (j N W₂ : ℕ) (d : ℕ → Coins × Coins) (a : PreRes P)
    (o : P.Stmt × P.Receipt) : OC Q D Bool :=
  wtrunc KUf (ctx₂ P pOC j N d a o) W₂

omit [DecidableEq Q] [Inhabited M.Input] in
theorem ctx₂W_wb (KUf : Q → ℕ) (j N W₂ : ℕ) (d : ℕ → Coins × Coins) (a : PreRes P) (o : P.Stmt × P.Receipt) :
    WB KUf (ctx₂W P pOC KUf j N W₂ d a o) W₂ :=
  wtrunc_wb KUf _ W₂

omit [DecidableEq Q] in
/-- **On the hybrid's own prefixes the weighted truncation changes nothing**: request `j`'s continuation is within the
distinguisher's budget, so the suffix is within `q + R·qp` questions and the weighted budget `q·KUm + R·Wpa ≤ W₂`. -/
theorem ctx₂W_eq (qp : ℕ) (hbd : ∀ x c, (pOC x c).Bounded qp) (KUf : Q → ℕ) (KUm Wpa : ℕ)
    (hKUm : ∀ z, KUf z ≤ KUm) (hwba : ∀ x c, WB KUf (pOC x c) Wpa) (j N W₂ : ℕ) (d : ℕ → Coins × Coins)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (q R : ℕ) (hD : Dist.Within q R)
    (hN : q + R * qp ≤ N) (hW₂ : q * KUm + R * Wpa ≤ W₂) (H : Q → D) (o : P.Stmt × P.Receipt) :
    ctx₂W P pOC KUf j N W₂ d ((pre P W pOC j d Dist 0).run H) o = ctx₂ P pOC j N d ((pre P W pOC j d Dist 0).run H) o := by
  unfold ctx₂W
  cases ha : (pre P W pOC j d Dist 0).run H with
  | inl b => rfl
  | inr p =>
    obtain ⟨x, k⟩ := p
    have hk := pre_cont P W pOC j d H Dist q R 0 hD x k ha
    have hb : (post P pOC d (k (.inr o)) (j + 1)).Bounded N :=
      (post_bounded P pOC qp hbd d (k (.inr o)) q R (j + 1) (hk _)).mono hN
    show wtrunc KUf (trunc (post P pOC d (k (.inr o)) (j + 1)) N) W₂ = trunc (post P pOC d (k (.inr o)) (j + 1)) N
    rw [trunc_eq _ N hb]
    exact wtrunc_eq KUf _ W₂ ((post_wb P pOC KUf KUm Wpa hKUm hwba d (k (.inr o)) q R (j + 1) (hk _)).mono hW₂)

variable [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **The hybrid step from one receipt, weighted.** If one receipt in any context of weighted budgets `(W₁, W₂)` costs
at most `ε W₁ W₂` (`OneStepW`), then for every distinguisher with at most `q` hash queries and `R` requests, hybrid `j`
and hybrid `j + 1` of the stand-in simulator differ by at most `ε (q·Km + j·Wp) (q·KUm + R·Wpa)`, both ways. -/
theorem hstep_of_oneStepW (hrun : ∀ H x c, (pOC x c).run H = P.prove H W x c) (qp : ℕ)
    (hbd : ∀ x c, (pOC x c).Bounded qp) (Kf KUf : Q → ℕ) (Km KUm Wp Wpa : ℕ) (hKm : ∀ z, Kf z ≤ Km)
    (hKUm : ∀ z, KUf z ≤ KUm) (hwb : ∀ x c, WB Kf (pOC x c) Wp) (hwba : ∀ x c, WB KUf (pOC x c) Wpa)
    (ε : ℕ → ℕ → ℝ≥0∞) (hone : OneStepW P W Kf KUf ε) (q R : ℕ)
    (Dist : OC (Q ⊕ M.Input) (D ⊕ (P.Stmt × P.Receipt)) Bool) (hD : Dist.Within q R) (j : ℕ) (hj : j < R) :
    hybProb (standinSim P) W (q + R) Dist j
        ≤ hybProb (standinSim P) W (q + R) Dist (j + 1) + ε (q * Km + j * Wp) (q * KUm + R * Wpa)
      ∧ hybProb (standinSim P) W (q + R) Dist (j + 1)
        ≤ hybProb (standinSim P) W (q + R) Dist j + ε (q * Km + j * Wp) (q * KUm + R * Wpa) := by
  classical
  have hjn : j < q + R := by omega
  set N := q + R * qp with hNdef
  set W₂ := q * KUm + R * Wpa with hW₂def
  set c₀ : Coins × Coins := default
  have : Nonempty {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀} := ⟨⟨fun _ => c₀, rfl⟩⟩
  -- re-index both hybrids, then split coordinate `j` off
  have hsplitJ : ∀ J : ℕ, hybProb (standinSim P) W (q + R) Dist J
      = (PMF.uniformOfFintype
          ({d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀} × ((Q → D) × (Coins × Coins)))).toOuterMeasure
          {p | runIdx P W p.2.1 J (Function.update (extend p.1.1) j p.2.2) Dist 0 = true} := by
    intro J
    rw [hybProb_reindex P W J q R Dist hD]
    rw [← Hiding.map_uniform_equiv (splitAt (A := Q → D) ⟨j, hjn⟩ c₀), PMF.toOuterMeasure_map_apply]
    congr 1
    ext p
    simp only [Set.mem_preimage, Set.mem_ofPred_eq]
    have hext : Function.update (extend (Function.update p.2 ⟨j, hjn⟩ c₀)) j (p.2 ⟨j, hjn⟩) = extend p.2 := by
      rw [← extend_update _ hjn, Function.update_idem, Function.update_eq_self]
    show runIdx P W p.1 J (extend p.2) Dist 0 = true
      ↔ runIdx P W p.1 J (Function.update (extend (Function.update p.2 ⟨j, hjn⟩ c₀)) j (p.2 ⟨j, hjn⟩)) Dist 0 = true
    rw [hext]
  rw [hsplitJ j, hsplitJ (j + 1)]
  -- the context for fixed other coordinates, with the weighted truncation
  have hfib : ∀ r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀},
      (PMF.uniformOfFintype ((Q → D) × (Coins × Coins))).toOuterMeasure
          {p | runIdx P W p.1 j (Function.update (extend r.1) j p.2) Dist 0 = true}
        = (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (ctx₂W P pOC KUf j N W₂ (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run p.1)
            (P.prove p.1 W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1)) p.2)).run p.1 = true}
      ∧ (PMF.uniformOfFintype ((Q → D) × (Coins × Coins))).toOuterMeasure
          {p | runIdx P W p.1 (j + 1) (Function.update (extend r.1) j p.2) Dist 0 = true}
        = (PMF.uniformOfFintype ((Q → D) × Coins)).toOuterMeasure
          {p | (ctx₂W P pOC KUf j N W₂ (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run p.1)
            (P.prove p.1 W (standin P W (M.publicPart (M.forward W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1))),
              P.leak (xOf P ((pre P W pOC j (extend r.1) Dist 0).run p.1)))) p.2)).run p.1 = true} := by
    intro r
    have hc : ∀ (H : Q → D) (o : P.Stmt × P.Receipt),
        ctx₂W P pOC KUf j N W₂ (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H) o
          = ctx₂ P pOC j N (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H) o :=
      fun H o => ctx₂W_eq P W pOC qp hbd KUf KUm Wpa hKUm hwba j N W₂ (extend r.1) Dist q R hD le_rfl le_rfl H o
    constructor
    · refine Eq.trans ?_ (prob_coin_fst (C₂ := Coins) (fun H c₁ =>
        (ctx₂W P pOC KUf j N W₂ (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H)
          (P.prove H W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H)) c₁)).run H = true))
      congr 1
      ext p
      simp only [Set.mem_ofPred_eq]
      rw [hc, runIdx_split P W pOC qp hrun hbd p.1 j N (extend r.1) p.2 Dist q R 0 hD le_rfl (Nat.zero_le _)]
    · refine Eq.trans ?_ (prob_coin_snd (C₁ := Coins) (fun H c₂ =>
        (ctx₂W P pOC KUf j N W₂ (extend r.1) ((pre P W pOC j (extend r.1) Dist 0).run H)
          (P.prove H W (standin P W (M.publicPart (M.forward W (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H))),
            P.leak (xOf P ((pre P W pOC j (extend r.1) Dist 0).run H)))) c₂)).run H = true))
      congr 1
      ext p
      simp only [Set.mem_ofPred_eq]
      rw [hc, runIdx_split_succ P W pOC qp hrun hbd p.1 j N (extend r.1) p.2 Dist q R 0 hD le_rfl (Nat.zero_le _)]
  have hA₁ : ∀ r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀},
      WB Kf (pre P W pOC j (extend r.1) Dist 0) (q * Km + j * Wp) := by
    intro r
    have h := pre_wb P W pOC Kf Km Wp hKm hwb j (extend r.1) Dist q R 0 hD (Nat.zero_le _)
    rwa [Nat.sub_zero] at h
  have hA₂ : ∀ (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) a o,
      WB KUf (ctx₂W P pOC KUf j N W₂ (extend r.1) a o) W₂ :=
    fun r a o => ctx₂W_wb P pOC KUf j N W₂ (extend r.1) a o
  constructor
  · refine prob_le_of_forall_fst
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 j (Function.update (extend r.1) j x.2) Dist 0 = true)
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 (j + 1) (Function.update (extend r.1) j x.2) Dist 0 = true) _ (fun r => ?_)
    obtain ⟨h1, h2⟩ := hfib r
    rw [h1, h2]
    exact (hone _ (pre P W pOC j (extend r.1) Dist 0) (q * Km + j * Wp) (hA₁ r) (xOf P)
      (ctx₂W P pOC KUf j N W₂ (extend r.1)) W₂ (hA₂ r)).1
  · refine prob_le_of_forall_fst
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 (j + 1) (Function.update (extend r.1) j x.2) Dist 0 = true)
      (fun (r : {d : Fin (q + R) → Coins × Coins // d ⟨j, hjn⟩ = c₀}) (x : (Q → D) × (Coins × Coins)) =>
        runIdx P W x.1 j (Function.update (extend r.1) j x.2) Dist 0 = true) _ (fun r => ?_)
    obtain ⟨h1, h2⟩ := hfib r
    rw [h1, h2]
    exact (hone _ (pre P W pOC j (extend r.1) Dist 0) (q * Km + j * Wp) (hA₁ r) (xOf P)
      (ctx₂W P pOC KUf j N W₂ (extend r.1)) W₂ (hA₂ r)).2

end Hyb

/-! ## Zero knowledge from the weighted one-receipt step -/

section ZK

variable {Q D Coins : Type} [DecidableEq Q] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
  [Fintype Q] [Fintype D] [Nonempty D] [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

/-- **Zero knowledge from the weighted one-receipt step.** Per weight set `W`, let the honest prover be a
`qp`-question computation within the weighted budgets `Wp W` (weights `Kf W`, before a request) and `Wpa W` (weights
`KUf W`, after it), the distinguisher's single queries weigh at most `Km W` and `KUm W`, and one receipt cost at most
`ε W W₁ W₂` in every weighted context (`OneStepW`). If every resulting step error `ε W (q·Km + j·Wp) (q·KUm + R·Wpa)`
is at most a bound `e q R j` uniform in `W`, the protocol is zero knowledge with the stand-in simulator and error
`Σ_{j<R} e q R j`. -/
theorem zeroKnowledge_of_oneStepW (pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt)) (qp : ℕ)
    (hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c) (hbd : ∀ W x c, (pOC W x c).Bounded qp)
    (Kf KUf : M.Weights → Q → ℕ) (Km KUm Wp Wpa : M.Weights → ℕ) (hKm : ∀ W z, Kf W z ≤ Km W)
    (hKUm : ∀ W z, KUf W z ≤ KUm W) (hwb : ∀ W x c, WB (Kf W) (pOC W x c) (Wp W))
    (hwba : ∀ W x c, WB (KUf W) (pOC W x c) (Wpa W))
    (ε : M.Weights → ℕ → ℕ → ℝ≥0∞) (hone : ∀ W, OneStepW P W (Kf W) (KUf W) (ε W))
    (e : ℕ → ℕ → ℕ → ℝ≥0∞)
    (he : ∀ W q R j, j < R → ε W (q * Km W + j * Wp W) (q * KUm W + R * Wpa W) ≤ e q R j) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, e q R j) :=
  zeroKnowledge_of_hybrid_R (standinSim P) e (fun W q R Dist hD j hj => by
    obtain ⟨h1, h2⟩ := hstep_of_oneStepW P W (pOC W) (hrun W) qp (hbd W) (Kf W) (KUf W) (Km W) (KUm W) (Wp W)
      (Wpa W) (hKm W) (hKUm W) (hwb W) (hwba W) (ε W) (hone W) q R Dist hD j hj
    exact ⟨h1.trans (add_le_add le_rfl (he W q R j hj)), h2.trans (add_le_add le_rfl (he W q R j hj))⟩)

end ZK

end ZK60.ZKCount
