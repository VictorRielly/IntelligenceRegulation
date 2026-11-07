/-
D63 lane L18 (2026-11-07), part 3: **`Complete` (ASSEMBLY §4.3) for the classify run**, via `complete_of_checks`
(`CompleteSub.lean`), in exactly the approved form `1 − εc ≤ prHC …`, with `εc` against `εcTarget = 2^-40`.

The honest receipt is accepted unless the honest prover REFUSES (D65(2): every refusal reads the same outside, and the
receipt is then the constant refusal, which the verifier rejects). Its refusals are challenge-dependent `discard
attempt`s at named SITES of the honest transcript, each a challenge landing in a small bad set:
* per slot: the CFS challenge `c = 0` (`k = 1`); the extension challenge `e ∈ {0, 1}` (`k = 2`, the degenerate-extension
  refusal); a host's `ν` zero (`nonzero(challenge_fp2_vec(2))`, `k = 1` each, L11-4); a zero batching coefficient
  (`k = 1` each, L15-6);
* per LogUp domain: `α` equal to a folded table tuple (`k = M`, the distinct tuples; `logupRefuses_iff`), the IN-C and
  OUT-C `α` refusals (`k = V`, `k = 256`), D66(3)'s dictionary refusal (`k` the admissible tuples, DD profiles);
* per opening (`check_opening_challenges`, protocol.rs:312-322, on a clone): a zero group member coefficient (`k = 1`
  each), the proximity pair's first coefficient zero (`k = 1`), and the pair DEPENDENT over `Fp` (`det = 0` given a
  nonzero first: `k = p`, the `Fp`-line through it; finding L18-3, about `2^-64` per opening, not `2^-111`).
Under Fiat–Shamir a site's challenge is `challenge_fp2` of the oracle's answer at the site's squeeze point: uniform when
the point is FRESH (not asked earlier by the honest computation; `fresh_point_prob_le`).

What is proved:
* `chal_bad_card`: the digests whose challenge lies in a set of `k` values number at most `k·fibC`
  (`card_chal_fiber_le`);
* **`site_refusal_le`**, **`Site.prob_le`**: a site fires with probability at most `k·fibC/|Dig| + δ`, `δ` its
  freshness failure (`fresh_point_prob_le_coins` on the fresh case, the union bound);
* **`classify_complete`**: `Complete (classifyModel S R) (classifyProtocol …) (Σ ε)` from: the verifier's policy
  passing the registered header, every part's completeness contract (`SegComplete`, deterministic), the honest
  prover refusing only when some listed site fires, and each site's bound; the public verdict is the model's by
  construction, and the input commitment opens honestly (`honestIn_opens`); the hidden output (`Unit`) opens trivially;
* **`classify_complete_sites`**: the same with the sites' own bounds, `εc = Σ (k_i·fibC/|Dig| + δ_i)`;
* `fib_le` (for a variable `p > 2^63`, L7-4), **`refusal_total_le_target`**: with `Σ k ≤ 2^85` and `Σ δ ≤ 2^-41`, the
  total is at most `εcTarget = 2^-40`; **`classify_complete_target`**: `Complete … εcTarget`.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ProtocolClassify
import ZK60Formal.ExecComposeFS

set_option autoImplicit false
-- The `constructorNameAsVariable` linter whnf's every hypothesis type; on a membership in `Finset.univ.filter` over
-- the `2^256` digests that unfolds the enumeration and exceeds the recursion limit (the proofs themselves elaborate).
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Complete
open ZK60.Circuit (gP GF)

/-! ## One refusal site under Fiat–Shamir -/

section Sites

/-- The digests whose `challenge_fp2` value lies in a set of `k` field values number at most `k·fibC`. -/
theorem chal_bad_card {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (B : Finset K) :
    (Finset.univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U ∈ B)).card ≤ B.card * fibC := by
  calc (Finset.univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U ∈ B)).card
      ≤ (B.biUnion (fun c => Finset.univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U = c))).card := by
        apply Finset.card_le_card
        intro dg hdg
        simp only [Finset.mem_filter, Finset.mem_univ, true_and] at hdg
        simp only [Finset.mem_biUnion, Finset.mem_filter, Finset.mem_univ, true_and]
        exact ⟨_, hdg, rfl⟩
    _ ≤ ∑ c ∈ B, (Finset.univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U = c)).card := Finset.card_biUnion_le
    _ ≤ ∑ _c ∈ B, fibC := Finset.sum_le_sum fun c _ => card_chal_fiber_le U hbij c
    _ = B.card * fibC := by rw [Finset.sum_const, smul_eq_mul]

variable {Q Coins : Type} [Fintype Q] [DecidableEq Q] [Fintype Coins] [Nonempty Coins]

/-- **One refusal site, under Fiat–Shamir.** The honest computation up to the site (`G c`, for the prover's coins `c`)
names the squeeze point and the data the bad set depends on; the site fires when the oracle's answer there lands in the
bad set (`m` digests at most). Unless the point was asked before (probability `≤ δ`), the answer is fresh and uniform:
the site fires with probability at most `m/|Dig| + δ`. -/
theorem site_refusal_le {β : Type} (G : Coins → OC Q Dig (Q × β)) (T : β → Finset Dig) (m : ℕ)
    (hT : ∀ b, (T b).card ≤ m) (δ : ℝ≥0∞)
    (hfresh : prHC (fun H c => ((G c).run H).1 ∈ OC.queries H (G c)) ≤ δ) :
    prHC (fun H c => H ((G c).run H).1 ∈ T ((G c).run H).2) ≤ (m : ℝ≥0∞) / Fintype.card Dig + δ := by
  have h1 := fresh_point_prob_le_coins G T m hT
  unfold prHC at h1 hfresh ⊢
  refine le_trans (MeasureTheory.measure_mono (t :=
      {p : (Q → Dig) × Coins | p.1 ((G p.2).run p.1).1 ∈ T ((G p.2).run p.1).2
        ∧ ((G p.2).run p.1).1 ∉ OC.queries p.1 (G p.2)}
      ∪ {p : (Q → Dig) × Coins | ((G p.2).run p.1).1 ∈ OC.queries p.1 (G p.2)}) ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add h1 hfresh))
  intro p hp
  by_cases hq : ((G p.2).run p.1).1 ∈ OC.queries p.1 (G p.2)
  · exact Or.inr hq
  · exact Or.inl ⟨hp, hq⟩

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **A refusal site of the honest run**: the honest computation up to it (`G`), the bad challenge values (`bad`, at
most `k`), and its freshness failure bound `δ` (the probability that the honest computation had already asked the
site's squeeze point; zero when the point's encoding cannot coincide with an earlier query of the honest prover). -/
structure Site (Q Coins K : Type) [Fintype Q] [DecidableEq Q] [Fintype Coins] [Nonempty Coins] where
  β : Type
  G : Coins → OC Q Dig (Q × β)
  bad : β → Finset K
  k : ℕ
  hk : ∀ b, (bad b).card ≤ k
  δ : ℝ≥0∞
  hfresh : prHC (fun H c => ((G c).run H).1 ∈ OC.queries H (G c)) ≤ δ

/-- The site fires: the challenge read at its point (`challenge_fp2`) is a bad value. -/
def Site.fires (U : K) (s : Site Q Coins K) (H : Q → Dig) (c : Coins) : Prop :=
  (challengeFp2Of (H ((s.G c).run H).1)).toK U ∈ s.bad ((s.G c).run H).2

/-- **A site fires with probability at most `k·fibC/|Dig| + δ`.** -/
theorem Site.prob_le (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (s : Site Q Coins K) :
    prHC (fun H c => s.fires U H c) ≤ ((s.k * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + s.δ := by
  have h := site_refusal_le s.G (fun b => Finset.univ.filter (fun dg : Dig => (challengeFp2Of dg).toK U ∈ s.bad b))
    (s.k * fibC) (fun b => (chal_bad_card U hbij (s.bad b)).trans (Nat.mul_le_mul_right _ (s.hk b))) s.δ s.hfresh
  refine le_trans (le_of_eq ?_) h
  unfold prHC
  refine congrArg _ (Set.ext fun p => ?_)
  simp only [Set.mem_setOf_eq, Site.fires, Finset.mem_filter, Finset.mem_univ, true_and]

end Sites

/-! ## `Complete` for the classify run -/

section Complete

variable {S : Block.BlockShape} {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins]

/-- **`Complete` for the classify run** (ASSEMBLY §4.3, via `complete_of_checks`). Premises:
* the verifier's own policy passes the registered header (`hpreA`, `hpreB`: finite facts of the registered profile);
* the input commitment's geometry: admissible (canonical) inputs are its values, `N ≤ 2^depth`, its root is the
  statement's `inRoot`;
* **every part's completeness contract** (`hparts`): the honest segment of stage IN-C, of each block (the block
  profile's), of stage OUT-C is accepted by the part's verifier, deterministically;
* **the honest prover refuses only at a listed site** (`hrefuse`): if no site fires, no part refuses;
* each site's failure bound (`hε`).
Then the honest receipt is accepted, carries the model's verdict and opens to the input, except with probability
`Σ ε i`. -/
theorem classify_complete (R : ClassifyRunPublic S) (hR : R.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModel S R).admissible liftH
      (clsStmtOf R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    {ι : Type} [Fintype ι] (Ref : ι → (S.Tok → ℕ) → (QB Lq → Dig) → Coins → Prop) (ε : ι → ℝ≥0∞)
    (hrefuse : ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ Ref i x G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c
        = .ok r)
    (hε : ∀ x, (classifyModel S R).admissible x → ∀ i, prHC (fun G c => Ref i x G c) ≤ ε i) :
    Complete (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base) (∑ i, ε i) := by
  refine complete_of_checks _ (fun i _ x G c => ¬ Ref i x G c) ε ?_ ?_
  · intro W x hx G c hall
    obtain ⟨⟨bs, crf, tf⟩, hseg⟩ := hrefuse x hx G c hall
    have hprove := prove_served R Lq V P Cin h64 hr hon.base G x c hx _ hseg
    have hW : W = () := rfl
    subst hW
    rw [hprove]
    refine ⟨?_, rfl, ?_, ⟨hon.base c, trivial⟩⟩
    · rw [verify_true_iff]
      unfold classifyVerifyE
      simp only [ex_bind_ok_iff, countOk_eq_ok]
      have hlen : bs.length = V.L + 2 := by
        rw [proveSegs_length _ _ _ _ _ (P.parts V.L) carry0 _ bs crf tf hseg, RunP.parts_length]
      have hrun := runSegs_of_proveSegs (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr hon.base)
        G x c _ hx (P.parts V.L) V.parts hparts carry0 _ bs crf tf hseg
      exact ⟨(), hpreA, (), hlen, (), hpreB, (crf, tf), hrun, trivial⟩
    · exact honestIn_opens Cin hon Lq h64 hr G _ x c (hokC x (admissible_canon R hR x hx)) hN (hroot _)
  · intro W x hx i
    simpa only [not_not] using hε x hx i

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **`Complete` with the sites' own bounds**: `εc = Σ_i (k_i·fibC/|Dig| + δ_i)`, the sites the honest prover's
challenge-dependent refusals. -/
theorem classify_complete_sites (R : ClassifyRunPublic S) (hR : R.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModel S R).admissible liftH
      (clsStmtOf R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (hkOf : ∀ x i, (site x i).k ≤ kOf i)
    (δOf : ι → ℝ≥0∞) (hδOf : ∀ x i, (site x i).δ ≤ δOf i)
    (hrefuse : ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c
        = .ok r) :
    Complete (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      (∑ i, (((kOf i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + δOf i)) := by
  refine classify_complete R hR Lq V P Cin h64 hr hon hokC hN hroot hpreA hpreB hparts
    (fun i x G c => (site x i).fires U G c) _ hrefuse (fun x _ i => ?_)
  refine ((site x i).prob_le U hbij).trans (add_le_add ?_ (hδOf x i))
  exact ENNReal.div_le_div_right (by exact_mod_cast Nat.mul_le_mul_right _ (hkOf x i)) _

end Complete

/-! ## The refusal total against `εcTarget = 2^-40` -/

section Target

/-- **The digests per challenge value**, for a variable `p > 2^63` (L7-4): `(⌊2^128/p⌋ + 1)² ≤ 2^130`. -/
theorem fib_le (p : ℕ) (hp : 2 ^ 63 < p) : (2 ^ 128 / p + 1) ^ 2 ≤ 2 ^ 130 := by
  have h1 : 2 ^ 128 / p < 2 ^ 65 := by
    rw [Nat.div_lt_iff_lt_mul (lt_of_le_of_lt (Nat.zero_le _) hp)]
    calc 2 ^ 128 = 2 ^ 65 * 2 ^ 63 := by norm_num
      _ < 2 ^ 65 * p := by gcongr
  calc (2 ^ 128 / p + 1) ^ 2 ≤ (2 ^ 65) ^ 2 := Nat.pow_le_pow_left (Nat.succ_le_of_lt h1) 2
    _ = 2 ^ 130 := by norm_num

theorem fibC_le : fibC ≤ 2 ^ 130 := fib_le gP (by norm_num [gP])

/-- **The refusal total meets the approved completeness target**: sites with `k i` bad challenge values each and
freshness failures `δ i`, with `Σ k ≤ 2^85` and `Σ δ ≤ 2^-41`, total at most `εcTarget = 2^-40`. (At the Shieldstral
classify run the count is dominated by the openings' `det = 0` refusals, about `83·p ≈ 2^70.4`, finding L18-3: far
inside `2^85`.) -/
theorem refusal_total_le_target {ι : Type} [Fintype ι] (k : ι → ℕ) (δ : ι → ℝ≥0∞) (hk : ∑ i, k i ≤ 2 ^ 85)
    (hδ : ∑ i, δ i ≤ (2⁻¹ : ℝ≥0∞) ^ 41) :
    ∑ i, (((k i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig + δ i) ≤ εcTarget := by
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 256 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
    norm_num
  rw [Finset.sum_add_distrib]
  have hsum : ∑ i, k i * fibC ≤ 2 ^ 215 := by
    calc ∑ i, k i * fibC = (∑ i, k i) * fibC := by rw [Finset.sum_mul]
      _ ≤ 2 ^ 85 * 2 ^ 130 := Nat.mul_le_mul hk fibC_le
      _ = 2 ^ 215 := by norm_num
  have h1 : ∑ i, ((k i * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ (2⁻¹ : ℝ≥0∞) ^ 41 := by
    simp only [div_eq_mul_inv]
    rw [← Finset.sum_mul, ← Nat.cast_sum, hcard, ← div_eq_mul_inv]
    calc ((∑ i, k i * fibC : ℕ) : ℝ≥0∞) / ((2 ^ 256 : ℕ) : ℝ≥0∞)
        ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 41 : ℕ) : ℝ≥0∞) :=
          natCast_div_le_div (by positivity) (by positivity)
            (by calc (∑ i, k i * fibC) * 2 ^ 41 ≤ 2 ^ 215 * 2 ^ 41 := Nat.mul_le_mul_right _ hsum
              _ = 1 * 2 ^ 256 := by norm_num)
      _ = (2⁻¹ : ℝ≥0∞) ^ 41 := (inv_two_pow_eq 41).symm
  have h2 : (2⁻¹ : ℝ≥0∞) ^ 41 + (2⁻¹ : ℝ≥0∞) ^ 41 = εcTarget := by
    rw [εcTarget, ← two_mul, pow_succ]
    calc (2 : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 40 * 2⁻¹) = (2⁻¹ : ℝ≥0∞) ^ 40 * (2 * 2⁻¹) := by ring
      _ = (2⁻¹ : ℝ≥0∞) ^ 40 := by rw [ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, mul_one]
  rw [← h2]
  exact add_le_add h1 hδ

variable {S : Block.BlockShape} {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins]
variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]

/-- **`Complete` at the approved target `εcTarget = 2^-40`** for the classify run: `classify_complete_sites` with the
site counts `Σ k ≤ 2^85` and the freshness failures `Σ δ ≤ 2^-41` (`refusal_total_le_target`, `complete_mono`). -/
theorem classify_complete_target (R : ClassifyRunPublic S) (hR : R.Valid) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin)
    (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (hN : Cin.N ≤ 2 ^ Cin.depth) (hroot : ∀ s, Cin.root s = s.inRoot)
    (hpreA : V.preA P.hdr = .ok ()) (hpreB : V.preB P.hdr = .ok ())
    (hparts : List.Forall₂ (SegComplete (classifyModel S R).admissible liftH
      (clsStmtOf R Lq P Cin h64 hr hon.base)) (P.parts V.L) V.parts)
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K)
    (kOf : ι → ℕ) (hkOf : ∀ x i, (site x i).k ≤ kOf i) (δOf : ι → ℝ≥0∞) (hδOf : ∀ x i, (site x i).δ ≤ δOf i)
    (hkT : ∑ i, kOf i ≤ 2 ^ 85) (hδT : ∑ i, δOf i ≤ (2⁻¹ : ℝ≥0∞) ^ 41)
    (hrefuse : ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c
        = .ok r) :
    Complete (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base) εcTarget :=
  Assembly.complete_mono (classify_complete_sites R hR Lq V P Cin h64 hr hon hokC hN hroot hpreA hpreB hparts U hbij
    site kOf hkOf δOf hδOf hrefuse) (refusal_total_le_target kOf δOf hkT hδT)

end Target

end ZK60.ProtocolClassify
