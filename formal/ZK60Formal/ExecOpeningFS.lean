/-
D63 lane L10 (2026-11-07): **`M`'s opening under Fiat–Shamir** (§4.2 item b of `ZK60_LEAN_ASSEMBLY_20261106.md`,
ASSUMED until now at `2^-106` per round: `FSComposeBlock.lean`'s `Kind8B.mask`), and **finding L8-5's transfer** of a
sub-protocol's round-by-round lemma from `Dg` (a digest's two 128-bit halves) to the code's chain (`Dig`, 32 bytes, and
absorbed bytes), so that it composes with L8's `fs_code_chain_sound_sched`.

**F12's status.** Fixed in the code (D65(1), 2026-11-04): `zk.rs`'s `combined_weights` starts the powers at `θ^1`, for
the prover and the verifier, on one code path; every M-carrying profile moved to a `/2` version string, the old strings
refused by name. `ExecOpeningM.lean` mirrors `θ^(i+1)`. So the bound is proved here for the FIXED test (offset `o = 1`).

**`M`'s rounds** (`mask_verify_tagged`): round 0, no message, ONE squeeze, `θ`; round 1, message `q'` (`"mask-q"`),
`2·S + 2` squeezes, the proximity weights `r`; round 2, message `prox` (`"mask-prox"`), `⌈256/4⌉ = 64` squeezes, the
column indices `J`. The states (`mSt`), for the committed rows the statement names (soundness rounds; the knowledge
version extracts them from the log as `FSOpening.lean` does for the regular opening):
* before: `SoundMProduct.lean`'s `MGood` (close to the code, and the decoded data's residual vanishes);
* after `θ`: some decoding's residual vanishes AT `θ` (`MAlive0`);
* after `r`: (close) `q'` IS the decoded product polynomial and passes the sum check, or (far) `u + Σ r·U` is close
  (`MAlive1`);
* after `J`: every check of `MAccept` at `J`, `q'` of degree `< 2m`, `prox` of degree `≤ K` (`MFinal`).
**`mask_rbrWide`** (PROVED): `RbrWide 3 w mSt ε` for ANY derivations with bounded bias, with the per-round error
`max(k/|E|·β0, (e + 1)/(|E| − 1)·β1, max(((N − (e + 1))/N)^Q, ((e + dd)/N)^Q)·β2)`, from `mopening_sound`'s argument
split at the rounds: round 0 is Schwartz–Zippel on the residual (degree `k`, offset 1; the decoding is unique,
`mDecoded_unique`), round 1 is the affine proximity test (F6, `affine_proximity_third`), round 2 is the column test
(the product test's `mprod_columns_prob`, or the proximity vector's `column_test_sound`).

**The code's derivations** (`maskSt_code`, `mask_rbrWide_code`): `θ = challenge_fp2` of one squeeze, `r` the
`challenge_fp2_vec`, `J = challenge_indices(256, 4096)`, on `Dg` (`fp2Field`, `idxCode`): the biases
`(1 + p/2^128)²`, `(1 + p/2^128)^(2·(2S+2))` and exactly `1`.

**The numbers** (`mask_eps_W16R2_le`, PROVED): at `M`'s parameters (`N = 4096`, `K = 1023`, `m = 512`, `e = 1024`,
`dd = 1534`, `Q = 256`, at most `2^20` functionals and `2^20` base rows, `|E| = p²`) the error is at most `2^-106`, the
figure `Kind8B.mask` assumed: so `M`'s rounds are now a PROVED sub-protocol of `FSComposeBlock.lean`'s kind
(`maskSP`, `maskSP_eps_le`).

**The L8-5 transfer** (PROVED): `RbrWide.mapDig` (any bijection of digest types keeps the error: `prob_equiv_comp`
coordinatewise), `halvesEquiv : Dig ≃ Dg` (L7's `halves`, injective, `|Dig| = |Dg|`), and `rbrWide_toCode`: a
`Dg` sub-protocol, its statement read off the code chain's header and its messages decoded from the absorbed bytes, is
`RbrWide` on the code's raw rounds with the same error: exactly the `hR` premise of `fs_code_chain_sound_sched`
(`toCSub`). Instances: `maskCSub` (`M`, its messages decoded by `decPoly`, the code's `absorb_fp2` encoding,
`decPoly_enc`), and the regular opening's two-sub-protocol split (finding L10-3).
-/
import ZK60Formal.ExecOpeningM
import ZK60Formal.ExecComposeFS

set_option autoImplicit false

namespace ZK60.Exec

open Polynomial Finset
open ZK60.Sound Prob Code
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The L8-5 transfer: from `Dg` to the code's digests and bytes -/

section Transfer

variable {X M D D' : Type} [Fintype D] [Nonempty D] [Fintype D'] [Nonempty D']

/-- **Any bijection of digest types keeps round-by-round soundness**, with the same error: the state reads the
digests through the bijection. -/
theorem _root_.ZK60.Sound.RbrWide.mapDig (e : D' ≃ D) {n : ℕ} {w : ℕ → ℕ} {St : X → List (M × List D) → Prop} {ε : ℝ≥0∞}
    (h : RbrWide n w St ε) : RbrWide n w (fun x τ => St x (τ.map (fun p => (p.1, p.2.map e)))) ε where
  round x τ m hτ hns := by
    have hl : (τ.map (fun p : M × List D' => (p.1, p.2.map e))).length = τ.length := List.length_map _
    have h1 := h.round x (τ.map (fun p : M × List D' => (p.1, p.2.map e))) m (by rw [hl]; exact hτ) hns
    rw [prob_ofFn_congr (D := D) (congrArg w hl) (fun l => St x (τ.map (fun p : M × List D' => (p.1, p.2.map e)) ++ [(m, l)]))]
      at h1
    have hset : {b : Fin (w τ.length) → D' | St x ((τ ++ [(m, List.ofFn b)]).map (fun p => (p.1, p.2.map e)))}
        = {b | (fun c : Fin (w τ.length) → D =>
            St x (τ.map (fun p : M × List D' => (p.1, p.2.map e)) ++ [(m, List.ofFn c)]))
              ((Equiv.arrowCongr (Equiv.refl _) e) b)} := by
      ext b
      simp only [Set.mem_setOf_eq, List.map_append, List.map_cons, List.map_nil, List.map_ofFn]
      exact Iff.rfl
    show (PMF.uniformOfFintype (Fin (w τ.length) → D')).toOuterMeasure
      {b | St x ((τ ++ [(m, List.ofFn b)]).map (fun p => (p.1, p.2.map e)))} ≤ ε
    rw [hset, prob_equiv_comp (Equiv.arrowCongr (Equiv.refl _) e)
      (fun c : Fin (w τ.length) → D => St x (τ.map (fun p : M × List D' => (p.1, p.2.map e)) ++ [(m, List.ofFn c)]))]
    exact h1

/-- A protocol whose state is pointwise equal to a round-by-round sound one is round-by-round sound. -/
theorem _root_.ZK60.Sound.RbrWide.congr {n : ℕ} {w : ℕ → ℕ} {St St' : X → List (M × List D) → Prop} {ε : ℝ≥0∞}
    (h : RbrWide n w St ε) (he : ∀ x τ, St x τ ↔ St' x τ) : RbrWide n w St' ε where
  round x τ m hτ hns := by
    have := h.round x τ m hτ (fun h' => hns ((he x τ).mp h'))
    refine le_trans (le_of_eq ?_) this
    congr 1
    ext b
    exact (he x _).symm

end Transfer

/-- **`Dig ≃ Dg`**: a digest's two little-endian halves, a bijection (`halves_injective`, `|Dig| = |Dg|`). -/
noncomputable def halvesEquiv : Dig ≃ Dg :=
  Equiv.ofBijective halves ((Fintype.bijective_iff_injective_and_card halves).mpr ⟨halves_injective, card_dig⟩)

theorem halvesEquiv_apply (d : Dig) : halvesEquiv d = halves d := rfl

section ToCode

variable {X M : Type}

/-- **A `Dg` sub-protocol on the code's chain** (L8's `CSub`): its window at `a`, its round schedule `R` (labels and
widths), its statement read off the header (`xOf`), its messages decoded from the absorbed bytes (`dec`), its digests
read as halves; a release `rel`. -/
noncomputable def toCSub (a : ℕ) (R : Rounds) (ε : ℝ≥0∞) (St : X → List (M × List Dg) → Prop)
    (xOf : List (TItem × Dig) → X) (dec : List UInt8 → M) (rel : List (TItem × Dig) → Prop) : CSub Dig where
  a := a
  R := R
  ε := ε
  St hdr τ := St (xOf hdr) (τ.map (fun p => (dec p.1, p.2.map halves)))
  rel := rel

/-- **The L8-5 transfer.** A sub-protocol round-by-round sound on `Dg` (FSComposeBlock's kind) is round-by-round sound
on the code's raw rounds with the same error: the `hR` premise of `fs_code_chain_sound_sched`. -/
theorem rbrWide_toCode (a : ℕ) (R : Rounds) (ε : ℝ≥0∞) (St : X → List (M × List Dg) → Prop)
    (xOf : List (TItem × Dig) → X) (dec : List UInt8 → M) (rel : List (TItem × Dig) → Prop)
    (h : RbrWide R.n R.w St ε) :
    RbrWide (toCSub a R ε St xOf dec rel).R.n (toCSub a R ε St xOf dec rel).R.w
      (toCSub a R ε St xOf dec rel).St (toCSub a R ε St xOf dec rel).ε := by
  have h1 := (h.comap xOf dec).mapDig halvesEquiv
  refine h1.congr fun hdr τ => ?_
  simp only [toCSub, List.map_map, Function.comp_def]
  exact Iff.rfl

end ToCode

/-! ## `M`'s opening, round by round -/

section MRounds

variable {X E ι σ κ : Type} [Field E] [Fintype E] [DecidableEq E] [Fintype ι] [DecidableEq ι] [Nonempty ι]
  [Fintype σ] [Fintype κ] [DecidableEq κ]

/-- The data a statement names for `M`'s opening: the functionals (weights, values), the committed base rows `Ub`, the
proximity mask `u`, and the product test's fixed combinations `La`, `Lb` (`a_{s,re} + U·a_{s,im}`, `b_re + U·b_im`). -/
structure MData (E ι σ κ : Type) (k m : ℕ) where
  wt : Fin k → σ → Fin m → E
  val : Fin k → E
  Ub : κ → ι → E
  u : ι → E
  La : σ → κ → E
  Lb : κ → E

variable {k m : ℕ}

/-- **A decoding of the rows**: outside at most `e` columns they agree with polynomials of degree `≤ K`. -/
def MDec (dom : ι ↪ E) (e K : ℕ) (Ub : κ → ι → E) (u : ι → E) (Rh : κ → E[X]) : Prop :=
  ∃ (S : Finset ι) (uh : E[X]), Fintype.card ι ≤ S.card + e ∧ uh.natDegree ≤ K ∧ (∀ i, (Rh i).natDegree ≤ K)
    ∧ (∀ j ∈ S, u j = uh.eval (dom j)) ∧ (∀ j ∈ S, ∀ i, Ub i j = (Rh i).eval (dom j))

/-- The residual of a decoding (`SoundMProduct.lean`, offset `o = 1`). -/
noncomputable def mRes (ω : E) (D : MData E ι σ κ k m) (Rh : κ → E[X]) : E[X] :=
  mResidual 1 D.val (mTrue ω D.wt (mDecA D.La Rh)) (mOff m ω (mDecB D.Lb Rh))

/-- After `θ`: some decoding's residual vanishes at `θ`. -/
def MAlive0 (dom : ι ↪ E) (ω : E) (e K : ℕ) (D : MData E ι σ κ k m) (θ : E) : Prop :=
  ∃ Rh, MDec dom e K D.Ub D.u Rh ∧ (mRes ω D Rh).eval θ = 0

/-- After `r`: (close) `q'` is a decoding's product polynomial and passes the sum check; or (far) `u + Σ r·U` is
close. -/
def MAlive1 (dom : ι ↪ E) (ω : E) (e K : ℕ) (D : MData E ι σ κ k m) (θ : E) (q : Option E[X]) (r : κ → E) :
    Prop :=
  (∃ Rh qq, q = some qq ∧ MDec dom e K D.Ub D.u Rh ∧ qq.natDegree < 2 * m
      ∧ (m : E) * (qq.coeff 0 + qq.coeff m) = mV 1 D.val θ ∧ qq = mProduct ω 1 D.wt (mDecA D.La Rh) (mDecB D.Lb Rh) θ)
    ∨ (¬ Close (rsCode dom K) e (withFirst D.u D.Ub) ∧ Close (rsCode dom K) e (fun _ : Unit => D.u + comb D.Ub r))

/-- After `J`: every check of `M`'s verifier at `J` (`MAccept`), with `q'` of degree `< 2m` and `prox` of degree
`≤ K` (the wire lengths). -/
def MFinal (dom : ι ↪ E) (ω : E) (K : ℕ) (D : MData E ι σ κ k m) (θ : E) (q : Option E[X]) (r : κ → E)
    (pr : Option E[X]) {Q : ℕ} (J : Fin Q → ι) : Prop :=
  ∃ qq pp, q = some qq ∧ pr = some pp ∧ qq.natDegree < 2 * m ∧ pp.natDegree ≤ K
    ∧ MAccept dom ω 1 D.wt D.val D.Ub D.u D.La D.Lb (fun _ => qq) (fun _ _ => pp) θ r J

variable {Dd : Type} [Fintype Dd] [Nonempty Dd]

/-- **`M`'s state on digest transcripts** (the three rounds), for the data the statement names. -/
def mSt (dom : ι ↪ E) (ω : E) (e K : ℕ) (dat : X → MData E ι σ κ k m) (d₀ : Dd) (w0 w1 w2 : ℕ) {Q : ℕ}
    (chal0 : (Fin w0 → Dd) → E) (chalR : (Fin w1 → Dd) → (κ → E)) (chalJ : (Fin w2 → Dd) → (Fin Q → ι))
    (x : X) : List (Option E[X] × List Dd) → Prop
  | [] => MGood dom ω 1 e K (dat x).wt (dat x).val (dat x).Ub (dat x).u (dat x).La (dat x).Lb
  | [(_, ds0)] => MAlive0 dom ω e K (dat x) (chal0 (vecOf d₀ w0 ds0))
  | [(_, ds0), (q, ds1)] => MAlive1 dom ω e K (dat x) (chal0 (vecOf d₀ w0 ds0)) q (chalR (vecOf d₀ w1 ds1))
  | [(_, ds0), (q, ds1), (pr, ds2)] =>
    MFinal dom ω K (dat x) (chal0 (vecOf d₀ w0 ds0)) q (chalR (vecOf d₀ w1 ds1)) pr (chalJ (vecOf d₀ w2 ds2))
  | _ => MGood dom ω 1 e K (dat x).wt (dat x).val (dat x).Ub (dat x).u (dat x).La (dat x).Lb

/-- `M`'s round widths: `w0` (`θ`), `w1` (`r`), `w2` (`J`). -/
def mW3 (w0 w1 w2 : ℕ) : ℕ → ℕ := fun i => if i = 0 then w0 else if i = 1 then w1 else w2

/-- A decoding makes the rows close. -/
theorem MDec.close {dom : ι ↪ E} {e K : ℕ} {Ub : κ → ι → E} {u : ι → E} {Rh : κ → E[X]}
    (h : MDec dom e K Ub u Rh) : Close (rsCode dom K) e (withFirst u Ub) := by
  obtain ⟨S, uh, hS, huh, hRh, hu, hUb⟩ := h
  refine ⟨S, hS, fun o => ?_⟩
  rcases o with _ | i
  · exact mem_agreeOn.mpr ⟨fun j => uh.eval (dom j), mem_rsCode.mpr ⟨uh, huh, fun _ => rfl⟩, fun j hj => hu j hj⟩
  · exact mem_agreeOn.mpr ⟨fun j => (Rh i).eval (dom j), mem_rsCode.mpr ⟨Rh i, hRh i, fun _ => rfl⟩,
      fun j hj => hUb j hj i⟩

/-- A close table decodes. -/
theorem MDec.of_close {dom : ι ↪ E} {e K : ℕ} {Ub : κ → ι → E} {u : ι → E}
    (hc : Close (rsCode dom K) e (withFirst u Ub)) : ∃ Rh, MDec dom e K Ub u Rh := by
  obtain ⟨V, S, hV, hS, hUV⟩ := hc.exists_table
  choose Rh hRh hVR using fun o' => mem_rsCode.mp (hV o')
  refine ⟨fun i => Rh (some i), S, Rh none, hS, hRh none, fun i => hRh (some i), fun j hj => ?_, fun j hj i => ?_⟩
  · rw [show u j = withFirst u Ub none j from rfl, hUV j hj none, hVR none j]
  · rw [show Ub i j = withFirst u Ub (some i) j from rfl, hUV j hj (some i), hVR (some i) j]

/-- **Decodings are unique** (`mDecoded_unique`, for `2e + K < N`). -/
theorem MDec.unique {dom : ι ↪ E} {e K : ℕ} (h2 : 2 * e + K < Fintype.card ι) {Ub : κ → ι → E} {u : ι → E}
    {Rh Rh' : κ → E[X]} (h : MDec dom e K Ub u Rh) (h' : MDec dom e K Ub u Rh') : Rh = Rh' := by
  obtain ⟨S, -, hS, -, hR, -, hU⟩ := h
  obtain ⟨S', -, hS', -, hR', -, hU'⟩ := h'
  exact mDecoded_unique dom h2 hS hS' hR hR' hU hU'

theorem mGood_iff {dom : ι ↪ E} {ω : E} {e K : ℕ} (D : MData E ι σ κ k m) :
    MGood dom ω 1 e K D.wt D.val D.Ub D.u D.La D.Lb ↔ ∃ Rh, MDec dom e K D.Ub D.u Rh ∧ mRes ω D Rh = 0 := by
  constructor
  · rintro ⟨S, uh, Rh, hS, huh, hRh, hu, hUb, hres⟩
    exact ⟨Rh, ⟨S, uh, hS, huh, hRh, hu, hUb⟩, hres⟩
  · rintro ⟨Rh, ⟨S, uh, hS, huh, hRh, hu, hUb⟩, hres⟩
    exact ⟨S, uh, Rh, hS, huh, hRh, hu, hUb, hres⟩

theorem mRes_natDegree_le (hk : 0 < k) (ω : E) (D : MData E ι σ κ k m) (Rh : κ → E[X]) :
    (mRes ω D Rh).natDegree ≤ k := by
  have := mResidual_natDegree_le 1 D.val (mTrue ω D.wt (mDecA D.La Rh)) (mOff m ω (mDecB D.Lb Rh))
  unfold mRes
  omega

/-- **Round 0 (`θ`)**: from a bad opening, the residual vanishes at a uniform `θ` with probability `≤ k/|E|`. -/
theorem mask_round0 (hk : 0 < k) (dom : ι ↪ E) (ω : E) {e K : ℕ} (h2 : 2 * e + K < Fintype.card ι) (D : MData E ι σ κ k m)
    (hng : ¬ MGood dom ω 1 e K D.wt D.val D.Ub D.u D.La D.Lb) :
    (PMF.uniformOfFintype E).toOuterMeasure {θ | MAlive0 dom ω e K D θ} ≤ (k : ℝ≥0∞) / Fintype.card E := by
  classical
  by_cases hc : Close (rsCode dom K) e (withFirst D.u D.Ub)
  · obtain ⟨Rh0, h0⟩ := MDec.of_close hc
    have hres : mRes ω D Rh0 ≠ 0 := fun h => hng ((mGood_iff D).mpr ⟨Rh0, h0, h⟩)
    refine le_trans (MeasureTheory.measure_mono (fun θ hθ => ?_)) (schwartzZippel hres (mRes_natDegree_le hk ω D Rh0))
    obtain ⟨Rh, hRh, hz⟩ := hθ
    rw [MDec.unique h2 hRh h0] at hz
    exact hz
  · exact prob_le_of_forall_not (fun θ (hθ : MAlive0 dom ω e K D θ) => hc hθ.choose_spec.1.close) _

/-- **Round 1 (`r`)**: from a bad `θ`, whatever `q'`, a uniform `r` revives the opening with probability
`≤ (e + 1)/(|E| − 1)` (`3e < N − K`). -/
theorem mask_round1 (dom : ι ↪ E) {ω : E} (hm : 0 < m) (hω : IsPrimitiveRoot ω m) {e K : ℕ}
    (h3 : 3 * e < Fintype.card ι - K) (D : MData E ι σ κ k m) (θ : E) (hbad : ¬ MAlive0 dom ω e K D θ)
    (q : Option E[X]) :
    (PMF.uniformOfFintype (κ → E)).toOuterMeasure {r | MAlive1 dom ω e K D θ q r}
      ≤ ((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ) := by
  classical
  have h2 : 2 * e + K < Fintype.card ι := by omega
  by_cases hc : Close (rsCode dom K) e (withFirst D.u D.Ub)
  · obtain ⟨Rh0, h0⟩ := MDec.of_close hc
    have hempty : {r : κ → E | MAlive1 dom ω e K D θ q r} = ∅ := by
      ext r
      simp only [Set.mem_setOf_eq, Set.mem_empty_iff_false, iff_false]
      rintro (⟨Rh, qq, -, hRh, hdeg, hsum, hP⟩ | ⟨hnc, -⟩)
      · apply hbad
        refine ⟨Rh, hRh, ?_⟩
        exact mResidual_root hm hω 1 D.wt D.val _ _ θ qq hdeg hP hsum
      · exact hnc hc
    rw [hempty, MeasureTheory.measure_empty]
    exact zero_le
  · refine le_trans (MeasureTheory.measure_mono (fun r hr => ?_))
      (affine_proximity_third (minDist_rsCode dom K) h3 D.u D.Ub hc)
    rcases hr with ⟨Rh, qq, -, hRh, -⟩ | ⟨-, hr⟩
    · exact absurd hRh.close hc
    · exact hr

/-- **Round 2 (`J`)**: from a bad `(θ, r)`, whatever `prox`, uniform indices pass every check with probability
`≤ max(((N − (e + 1))/N)^Q, ((e + dd)/N)^Q)`. -/
theorem mask_round2 (dom : ι ↪ E) {ω : E} (hm : 0 < m) (hω : IsPrimitiveRoot ω m) {e K dd : ℕ}
    (h3 : 3 * e < Fintype.card ι - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd) (D : MData E ι σ κ k m)
    (θ : E) (q : Option E[X]) (r : κ → E) (hbad : ¬ MAlive1 dom ω e K D θ q r) (pr : Option E[X]) (Q : ℕ) :
    (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {J | MFinal dom ω K D θ q r pr J}
      ≤ max ((((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q)
          ((((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q) := by
  classical
  have h2 : 2 * e + K < Fintype.card ι := by omega
  by_cases hc : Close (rsCode dom K) e (withFirst D.u D.Ub)
  · refine le_trans ?_ (le_max_right _ _)
    obtain ⟨Rh0, h0⟩ := MDec.of_close hc
    obtain ⟨S, uh, hS, huh, hRh, hu, hUb⟩ := h0
    rcases q with _ | qq
    · exact prob_le_of_forall_not (fun J (hJ : MFinal dom ω K D θ none r pr J) => by
        obtain ⟨qq, -, hqq, -⟩ := hJ
        exact absurd hqq (by simp)) _
    · by_cases hgood : qq.natDegree < 2 * m ∧ (m : E) * (qq.coeff 0 + qq.coeff m) = mV 1 D.val θ
      · have hne : qq ≠ mProduct ω 1 D.wt (mDecA D.La Rh0) (mDecB D.Lb Rh0) θ := fun hP =>
          hbad (Or.inl ⟨Rh0, qq, rfl, ⟨S, uh, hS, huh, hRh, hu, hUb⟩, hgood.1, hgood.2, hP⟩)
        have haS : ∀ s, ∀ j ∈ S, comb D.Ub (D.La s) j = (mDecA D.La Rh0 s).eval (dom j) :=
          fun s => comb_eval_dec dom D.Ub Rh0 (D.La s) hUb
        have hAh : ∀ s, (mDecA D.La Rh0 s).natDegree ≤ K := fun s => dec_natDegree_le Rh0 hRh _
        have hB : (mDecB D.Lb Rh0).natDegree ≤ K := dec_natDegree_le Rh0 hRh _
        refine le_trans (MeasureTheory.measure_mono (fun J hJ => ?_))
          (mprod_columns_prob hm hω dom dom.injective 1 D.wt (fun s => comb D.Ub (D.La s)) (comb D.Ub D.Lb)
            (mDecA D.La Rh0) (mDecB D.Lb Rh0) hAh hB S hS (fun j hj s => haS s j hj)
            (comb_eval_dec dom D.Ub Rh0 D.Lb hUb) hdd hdq θ qq hgood.1 hne (Q := Q))
        obtain ⟨qq', pp, hqq', -, -, -, hacc⟩ := hJ
        obtain rfl := Option.some.inj hqq'
        exact hacc.1.2
      · exact prob_le_of_forall_not (fun J (hJ : MFinal dom ω K D θ (some qq) r pr J) => by
          obtain ⟨qq', pp, hqq', -, hdeg, -, hacc⟩ := hJ
          obtain rfl := Option.some.inj hqq'
          exact hgood ⟨hdeg, hacc.1.1⟩) _
  · refine le_trans ?_ (le_max_left _ _)
    have hρ : ¬ Close (rsCode dom K) e (fun _ : Unit => D.u + comb D.Ub r) := fun h => hbad (Or.inr ⟨hc, h⟩)
    rcases pr with _ | pp
    · exact prob_le_of_forall_not (fun J (hJ : MFinal dom ω K D θ q r none J) => by
        obtain ⟨-, pp, -, hpp, -⟩ := hJ
        exact absurd hpp (by simp)) _
    · by_cases hpd : pp.natDegree ≤ K
      · have hw : (fun j => pp.eval (dom j)) ∈ rsCode dom K := mem_rsCode.mpr ⟨pp, hpd, fun _ => rfl⟩
        have ht : e + 1 ≤ (univ.filter (fun j => pp.eval (dom j) ≠ (D.u + comb D.Ub r) j)).card := by
          by_contra hlt
          exact hρ (close_of_card_ne_le hw (by omega))
        refine le_trans (MeasureTheory.measure_mono (fun J hJ => ?_)) (column_test_sound _ _ ht Q)
        obtain ⟨-, pp', -, hpp', -, -, hacc⟩ := hJ
        obtain rfl := Option.some.inj hpp'
        intro t
        exact (hacc.2 t).symm
      · exact prob_le_of_forall_not (fun J (hJ : MFinal dom ω K D θ q r (some pp) J) => by
          obtain ⟨-, pp', -, hpp', -, hdeg, -⟩ := hJ
          obtain rfl := Option.some.inj hpp'
          exact hpd hdeg) _

/-- **`M`'s opening is round-by-round sound** (three rounds, vector challenges), for any derivations with bounded bias,
per-round error `max(k/|E|·β0, (e + 1)/(|E| − 1)·β1, colMax·β2)`. -/
theorem mask_rbrWide (hk : 0 < k) (dom : ι ↪ E) {ω : E} (hm : 0 < m) (hω : IsPrimitiveRoot ω m) {e K dd : ℕ}
    (h3 : 3 * e < Fintype.card ι - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (dat : X → MData E ι σ κ k m) (d₀ : Dd) (w0 w1 w2 : ℕ) {Q : ℕ}
    (chal0 : (Fin w0 → Dd) → E) (chalR : (Fin w1 → Dd) → (κ → E)) (chalJ : (Fin w2 → Dd) → (Fin Q → ι))
    (β0 β1 β2 : ℝ≥0∞)
    (h0 : ∀ Ev : E → Prop, (PMF.uniformOfFintype (Fin w0 → Dd)).toOuterMeasure {b | Ev (chal0 b)}
      ≤ (PMF.uniformOfFintype E).toOuterMeasure {y | Ev y} * β0)
    (h1 : ∀ Ev : (κ → E) → Prop, (PMF.uniformOfFintype (Fin w1 → Dd)).toOuterMeasure {b | Ev (chalR b)}
      ≤ (PMF.uniformOfFintype (κ → E)).toOuterMeasure {y | Ev y} * β1)
    (h2 : ∀ Ev : (Fin Q → ι) → Prop, (PMF.uniformOfFintype (Fin w2 → Dd)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin Q → ι)).toOuterMeasure {y | Ev y} * β2) :
    RbrWide 3 (mW3 w0 w1 w2) (mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ)
      (max ((k : ℝ≥0∞) / Fintype.card E * β0)
        (max (((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card E - 1 : ℕ) * β1)
          (max ((((Fintype.card ι - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q)
            ((((e + dd : ℕ) : ℝ≥0∞) / Fintype.card ι) ^ Q) * β2))) where
  round x τ msg hτ hns := by
    have h2e : 2 * e + K < Fintype.card ι := by omega
    rcases τ with _ | ⟨⟨m0, ds0⟩, _ | ⟨⟨q, ds1⟩, _ | ⟨e3, τ⟩⟩⟩
    · rw [prob_ofFn_congr (show mW3 w0 w1 w2 ([] : List (Option E[X] × List Dd)).length = w0 from rfl)
        (fun ds => mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([] ++ [(msg, ds)]))]
      have hset : {b : Fin w0 → Dd | mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([] ++ [(msg, List.ofFn b)])}
          = {b | (fun θ => MAlive0 dom ω e K (dat x) θ) (chal0 b)} := by
        ext b
        simp only [Set.mem_setOf_eq, List.nil_append, mSt, vecOf_ofFn]
      rw [hset]
      refine (h0 _).trans (le_trans ?_ (le_max_left _ _))
      exact mul_le_mul' (mask_round0 hk dom ω h2e (dat x) hns) le_rfl
    · rw [prob_ofFn_congr (show mW3 w0 w1 w2 ([(m0, ds0)] : List (Option E[X] × List Dd)).length = w1 from rfl)
        (fun ds => mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([(m0, ds0)] ++ [(msg, ds)]))]
      have hset : {b : Fin w1 → Dd |
            mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([(m0, ds0)] ++ [(msg, List.ofFn b)])}
          = {b | (fun r => MAlive1 dom ω e K (dat x) (chal0 (vecOf d₀ w0 ds0)) msg r) (chalR b)} := by
        ext b
        simp only [Set.mem_setOf_eq, List.cons_append, List.nil_append, mSt, vecOf_ofFn]
      rw [hset]
      refine (h1 _).trans (le_trans ?_ (le_trans (le_max_left _ _) (le_max_right _ _)))
      exact mul_le_mul' (mask_round1 dom hm hω h3 (dat x) (chal0 (vecOf d₀ w0 ds0)) hns msg) le_rfl
    · rw [prob_ofFn_congr
        (show mW3 w0 w1 w2 ([(m0, ds0), (q, ds1)] : List (Option E[X] × List Dd)).length = w2 from rfl)
        (fun ds => mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([(m0, ds0), (q, ds1)] ++ [(msg, ds)]))]
      have hset : {b : Fin w2 → Dd |
            mSt dom ω e K dat d₀ w0 w1 w2 chal0 chalR chalJ x ([(m0, ds0), (q, ds1)] ++ [(msg, List.ofFn b)])}
          = {b | (fun J => MFinal dom ω K (dat x) (chal0 (vecOf d₀ w0 ds0)) q (chalR (vecOf d₀ w1 ds1)) msg J)
              (chalJ b)} := by
        ext b
        simp only [Set.mem_setOf_eq, List.cons_append, List.nil_append, mSt, vecOf_ofFn]
      rw [hset]
      refine (h2 _).trans (le_trans ?_ (le_trans (le_max_right _ _) (le_max_right _ _)))
      exact mul_le_mul' (mask_round2 dom hm hω h3 hdd hdq (dat x) (chal0 (vecOf d₀ w0 ds0)) q (chalR (vecOf d₀ w1 ds1)) hns msg Q) le_rfl
    · exact absurd hτ (by simp only [List.length_cons]; omega)

end MRounds

/-! ## `M` with the code's derivations, and its numbers -/

section MCode

variable {F : Type} [Field F] [Fintype F] [DecidableEq F] {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ]

/-- **The code's `θ`**: `challenge_fp2` of the round's one squeeze. -/
def chalTheta (p : ℕ) (eF : ZMod p × ZMod p ≃ F) (b : Fin 1 → Dg) : F := fp2Field p (2 ^ 128) eF (b 0)

/-- **The code's `r`**: `challenge_fp2_vec(rows)`, entry `i` of the rows' order `eR`. -/
def chalRows (p : ℕ) (eF : ZMod p × ZMod p ≃ F) {w1 : ℕ} (eR : κ ≃ Fin w1) (b : Fin w1 → Dg) : κ → F :=
  fun i => fp2Field p (2 ^ 128) eF (b (eR i))

theorem chalTheta_prob_le (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) (Ev : F → Prop) :
    (PMF.uniformOfFintype (Fin 1 → Dg)).toOuterMeasure {b | Ev (chalTheta p eF b)}
      ≤ (PMF.uniformOfFintype F).toOuterMeasure {y | Ev y} * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2 := by
  have : Nonempty F := ⟨eF 0⟩
  have h := prob_fp2_vec_le p eF 1 (fun c => Ev (c 0))
  rw [show (2 : ℕ) * 1 = 2 from rfl] at h
  refine le_trans (le_of_eq ?_) (le_trans h (le_of_eq ?_))
  · rfl
  · congr 1
    have := prob_equiv_comp (Equiv.funUnique (Fin 1) F) Ev
    simpa [Equiv.funUnique_apply, Fin.default_eq_zero] using this

theorem chalRows_prob_le (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) {w1 : ℕ} (eR : κ ≃ Fin w1)
    (Ev : (κ → F) → Prop) :
    (PMF.uniformOfFintype (Fin w1 → Dg)).toOuterMeasure {b | Ev (chalRows p eF eR b)}
      ≤ (PMF.uniformOfFintype (κ → F)).toOuterMeasure {y | Ev y}
        * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w1) := by
  have : Nonempty F := ⟨eF 0⟩
  have h := prob_fp2_vec_le p eF w1 (fun c => Ev (fun i => c (eR i)))
  refine le_trans (le_of_eq rfl) (le_trans h (le_of_eq ?_))
  congr 1
  exact prob_equiv_comp (Equiv.arrowCongr eR.symm (Equiv.refl F)) Ev

variable {X Mm : Type}

/-- **`M`'s opening with the code's derivations**: `θ` (one squeeze), `r` (`w1 = 2S + 2` squeezes), `J`
(`challenge_indices(Q, 2^h)`, `m2` squeezes), for the data the statement names, `dom` the `2^h` coset points. -/
def maskStCode (p : ℕ) (eF : ZMod p × ZMod p ≃ F) {h : ℕ} (dom : Fin (2 ^ h) ↪ F) (ω : F) {k m : ℕ} (e K : ℕ)
    (dat : X → MData F (Fin (2 ^ h)) σ κ k m) (d₀ : Dg) {w1 : ℕ} (eR : κ ≃ Fin w1) {m2 nQ : ℕ} (hnQ : nQ ≤ m2 * 4) :
    X → List (Option F[X] × List Dg) → Prop :=
  mSt dom ω e K dat d₀ 1 w1 m2 (chalTheta p eF) (chalRows p eF eR) (idxCode h hnQ)

/-- **`M`'s opening is round-by-round sound with the code's derivations**: the biases `(1 + p/2^128)²`,
`(1 + p/2^128)^(2·w1)` and exactly `1`. -/
theorem mask_rbrWide_code (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) {h : ℕ} (hh : h ≤ 64)
    (dom : Fin (2 ^ h) ↪ F) {ω : F} {k m : ℕ} (hk : 0 < k) (hm : 0 < m) (hω : IsPrimitiveRoot ω m) {e K dd : ℕ}
    (h3 : 3 * e < Fintype.card (Fin (2 ^ h)) - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (dat : X → MData F (Fin (2 ^ h)) σ κ k m) (d₀ : Dg) {w1 : ℕ} (eR : κ ≃ Fin w1) {m2 nQ : ℕ}
    (hnQ : nQ ≤ m2 * 4) :
    RbrWide 3 (mW3 1 w1 m2) (maskStCode p eF dom ω e K dat d₀ eR hnQ)
      (max ((k : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
        (max (((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card F - 1 : ℕ) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w1))
          (max ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ)
            ((((e + dd : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ) * 1))) :=
  mask_rbrWide hk dom hm hω h3 hdd hdq dat d₀ 1 w1 m2 (chalTheta p eF) (chalRows p eF eR) (idxCode h hnQ) _ _ _
    (chalTheta_prob_le p eF) (chalRows_prob_le p eF eR) (idxCode_prob_le hh hnQ)

/-- **`M`'s opening in a schedule** (`FSComposeBlock.lean`'s `SubProt`, on `Dg`): three rounds, widths `1`, `w1`, `m2`,
messages decoded by `g`. -/
noncomputable def maskSP (p : ℕ) [NeZero p] (eF : ZMod p × ZMod p ≃ F) {h : ℕ} (hh : h ≤ 64) (dom : Fin (2 ^ h) ↪ F)
    {ω : F} {k m : ℕ} (hk : 0 < k) (hm : 0 < m) (hω : IsPrimitiveRoot ω m) {e K dd : ℕ}
    (h3 : 3 * e < Fintype.card (Fin (2 ^ h)) - K) (hdd : K + (m - 1) ≤ dd) (hdq : 2 * m - 1 ≤ dd)
    (dat : X × List (Mm × List Dg) → MData F (Fin (2 ^ h)) σ κ k m) (d₀ : Dg) {w1 : ℕ} (eR : κ ≃ Fin w1)
    {m2 nQ : ℕ} (hnQ : nQ ≤ m2 * 4) (g : Mm → Option F[X]) (pend post : X → List (Mm × List Dg) → Prop) :
    SubProt X Mm Dg where
  n := 3
  w := mW3 1 w1 m2
  hasMsg := fun i => i != 0
  ε := max ((k : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
        (max (((e + 1 : ℕ) : ℝ≥0∞) / (Fintype.card F - 1 : ℕ) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w1))
          (max ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ)
            ((((e + dd : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ) * 1))
  St := fun y τ => maskStCode p eF dom ω e K dat d₀ eR hnQ (id y) (τ.map (fun e' => (g e'.1, e'.2)))
  rbr := (mask_rbrWide_code p eF hh dom hk hm hω h3 hdd hdq dat d₀ eR hnQ).comap id g
  pend := pend
  post := post

end MCode

/-! ### The numbers at `M`'s parameters -/

section MNumbers

/-- `(3071/4096)^256 ≤ 2^-106` (`(N − (e + 1))/N` at `N = 4096`, `e = 1024`, `Q = 256`: `2^-106.37`). -/
theorem mask_col_far_nat : (4096 - (1024 + 1)) ^ 256 * 2 ^ 106 ≤ 1 * 4096 ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- `(2558/4096)^256 ≤ 2^-106` (`(e + dd)/N`, `dd = 1534`). -/
theorem mask_col_close_nat : (1024 + 1534) ^ 256 * 2 ^ 106 ≤ 1 * 4096 ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- **`M`'s per-round error at its parameters is at most `2^-106`** (the figure `Kind8B.mask` assumed): `|F| = p²`,
`N = 4096`, `e = 1024`, `dd = 1534`, `Q = 256`, at most `2^20` functionals and `2^20` base rows. -/
theorem mask_eps_W16R2_le {F : Type} [Fintype F] (hF : Fintype.card F = goldP ^ 2) {k w1 : ℕ} (hk : k ≤ 2 ^ 20)
    (hw1 : w1 ≤ 2 ^ 20) :
    max ((k : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
        (max (((1024 + 1 : ℕ) : ℝ≥0∞) / (Fintype.card F - 1 : ℕ)
            * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w1))
          (max ((((Fintype.card (Fin (2 ^ 12)) - (1024 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 12))) ^ 256)
            ((((1024 + 1534 : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 12))) ^ 256) * 1))
      ≤ (2⁻¹ : ℝ≥0∞) ^ 106 := by
  have hb : ∀ j : ℕ, j ≤ 2 ^ 62 → (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ j ≤ ((2 : ℕ) : ℝ≥0∞) :=
    fun j hj => by exact_mod_cast fp2_bias_pow_le_two (by norm_num [goldP]) hj
  rw [inv_two_pow_eq]
  refine max_le ?_ (max_le ?_ ?_)
  · calc (k : ℝ≥0∞) / Fintype.card F * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        ≤ ((2 ^ 20 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
          rw [hF]
          exact mul_le_mul' (ENNReal.div_le_div_right (by exact_mod_cast hk) _) (hb 2 (by norm_num))
      _ = ((2 ^ 20 * 2 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
          rw [← natCast_div_mul_div, Nat.cast_one, div_one]
      _ ≤ _ := natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])
  · calc ((1024 + 1 : ℕ) : ℝ≥0∞) / (Fintype.card F - 1 : ℕ) * (1 + (goldP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w1)
        ≤ ((1025 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 - 1 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
          rw [hF]
          exact mul_le_mul' le_rfl (hb _ ((Nat.mul_le_mul_left 2 hw1).trans (by norm_num)))
      _ = ((1025 * 2 : ℕ) : ℝ≥0∞) / ((goldP ^ 2 - 1) * 1 : ℕ) := by
          rw [← natCast_div_mul_div, Nat.cast_one, div_one]
      _ ≤ _ := natCast_div_le_div (by norm_num [goldP]) (by norm_num) (by norm_num [goldP])
  · rw [mul_one, Fintype.card_fin]
    refine max_le ?_ ?_
    · rw [natCast_div_pow]
      exact natCast_div_le_div (by positivity) (by norm_num) mask_col_far_nat
    · rw [natCast_div_pow]
      exact natCast_div_le_div (by positivity) (by norm_num) mask_col_close_nat

/-- **`M`'s opening is a PROVED sub-protocol of the 8B block's kind**: at `M`'s parameters (`h = 12`, `m = 512`,
`K = 1023`, `e = 1024`, `dd = 1534`, `Q = 256`, `m2 = 64`), `maskSP` is `Kind8B.mask` with no assumption left: its
rounds are `M`'s, its error at most `2^-106`. -/
theorem maskSP_kind8B {F : Type} [Field F] [Fintype F] [DecidableEq F] {σ κ X Mm : Type} [Fintype σ] [Fintype κ]
    [DecidableEq κ] (eF : ZMod goldP × ZMod goldP ≃ F) (dom : Fin (2 ^ 12) ↪ F) {ω : F}
    (hω : IsPrimitiveRoot ω 512) {k : ℕ} (hk0 : 0 < k) (hk : k ≤ 2 ^ 20)
    (dat : X × List (Mm × List Dg) → MData F (Fin (2 ^ 12)) σ κ k 512) (d₀ : Dg) {w1 : ℕ} (eR : κ ≃ Fin w1)
    (hw1 : w1 ≤ 2 ^ 20) (hw10 : 0 < w1) (g : Mm → Option F[X]) (pend post : X → List (Mm × List Dg) → Prop) :
    Kind8B (maskSP goldP eF (h := 12) (by norm_num) dom hk0 (by norm_num) hω (e := 1024) (K := 1023) (dd := 1534)
      (by simp only [Fintype.card_fin]; norm_num) (by norm_num) (by norm_num) dat d₀ eR (m2 := 64) (nQ := 256)
      (by norm_num) g pend post) := by
  refine Kind8B.mask _ (fun i => ?_) ?_
  · show 0 < mW3 1 w1 64 i
    unfold mW3
    split_ifs <;> omega
  · exact mask_eps_W16R2_le (card_eq_of_equiv eF) hk hw1

end MNumbers

/-! ## `M` on the code's chain (`CSub`) -/

section MChain

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **The polynomial of an absorbed vector** of `len` words (the bytes of `absorb_fp2`): `Σ_i v_i X^i` read in `K`;
`none` unless the bytes number `16·len` (the verifier's length check). -/
noncomputable def decPoly (len : ℕ) (b : List UInt8) : Option K[X] :=
  if b.length = 16 * len then some (coefPoly (fun i : Fin len => (Fp2.fromBytes (b.drop (16 * (i : ℕ)))).toK U))
  else none

/-- **On the bytes the verifier absorbs**, `decPoly` is the polynomial of the sent coefficients. -/
theorem decPoly_enc (len : ℕ) (q : List Fp2) (hq : ∀ a ∈ q, a.Canon) (hl : q.length = len) :
    decPoly U len (q.flatMap Fp2.toBytes) = some (coefPoly (vecK U len q)) := by
  unfold decPoly
  rw [if_pos (by rw [flatMap_toBytes_length, hl])]
  congr 2
  funext i
  have hi : (i : ℕ) < q.length := by rw [hl]; exact i.isLt
  rw [drop_flatMap_toBytes, List.drop_eq_getElem_cons hi, List.flatMap_cons,
    Fp2.fromBytes_append _ _ (Fp2.toBytes_length _), Fp2.fromBytes_toBytes _ (hq _ (List.getElem_mem hi))]
  simp only [vecK]
  rw [getD_eq_get q i Fp2.zero hi]

/-- **`M`'s round schedule on the code's chain** (`mask_verify_tagged`): `θ` (no message, one squeeze); `"mask-q"` then
`2S + 2` squeezes; `"mask-prox"` then `64` squeezes. -/
def maskRounds (S : ℕ) : Rounds :=
  ⟨3, mW3 1 (2 * S + 2) 64, fun i => i != 0, fun i => if i = 1 then maskQLabel else maskProxLabel⟩

/-- A default digest pair. -/
def dg0 : Dg := (0, 0)

/-- **`M`'s error at its parameters** (`mask_eps_W16R2_le`'s left side, `S` masks). -/
noncomputable def maskEps (k S : ℕ) : ℝ≥0∞ :=
  max ((k : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2)
    (max (((1024 + 1 : ℕ) : ℝ≥0∞) / (Fintype.card K - 1 : ℕ)
        * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (2 * S + 2)))
      (max ((((Fintype.card (Fin (2 ^ 12)) - (1024 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 12))) ^ 256)
        ((((1024 + 1534 : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 12))) ^ 256) * 1))

/-- **`M` as a sub-protocol of L8's schedule on the code's chain**: its window at entry `a` (just before `θ`'s squeeze),
its statement the header (the chain before the window), the data the header names (`dat`: the functionals the
verifier computed from the slots, the committed rows), its messages decoded by `decPoly`, its digests read as halves;
never released. -/
noncomputable def maskCSub (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) (ω : K) {σ κ : Type} [Fintype σ]
    [Fintype κ] [DecidableEq κ] {k : ℕ} (S : ℕ) (a : ℕ) (dat : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) : CSub Dig :=
  toCSub a (maskRounds S) (maskEps (K := K) k S)
    (maskStCode gP eF dom ω 1024 1023 dat dg0 eR (m2 := 64) (nQ := 256) (by norm_num)) id (decPoly U 1024)
    (fun _ => False)

/-- **`M` is round-by-round sound on the code's chain** (the `hR` premise of `fs_code_chain_sound_sched`), with error
`maskEps ≤ 2^-106` (`maskEps_le`). -/
theorem maskCSub_rbr (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) {ω : K} (hω : IsPrimitiveRoot ω 512)
    {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ] {k : ℕ} (hk : 0 < k) (S : ℕ) (a : ℕ)
    (dat : List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512) (eR : κ ≃ Fin (2 * S + 2)) :
    RbrWide (maskCSub U eF dom ω S a dat eR).R.n (maskCSub U eF dom ω S a dat eR).R.w
      (maskCSub U eF dom ω S a dat eR).St (maskCSub U eF dom ω S a dat eR).ε :=
  rbrWide_toCode a (maskRounds S) _ _ id (decPoly U 1024) (fun _ => False)
    (mask_rbrWide_code gP eF (h := 12) (by norm_num) dom hk (by norm_num) hω (e := 1024) (K := 1023) (dd := 1534)
      (by simp only [Fintype.card_fin]; norm_num) (by norm_num) (by norm_num) dat dg0 eR (m2 := 64) (nQ := 256)
      (by norm_num))

theorem maskEps_le (hK : Fintype.card K = gP ^ 2) {k S : ℕ} (hk : k ≤ 2 ^ 20) (hS : 2 * S + 2 ≤ 2 ^ 20) :
    maskEps (K := K) k S ≤ (2⁻¹ : ℝ≥0∞) ^ 106 :=
  mask_eps_W16R2_le hK hk hS

end MChain

/-! ## The regular opening on the code's chain: its two rounds as two sub-protocols (finding L10-3)

The code absorbs the opening's round-1 message as `G + 1` items (`"pcs-vec"` per group, then `"pcs-prox"`), and L8's
reader takes ONE absorb per round. So the opening enters the code's schedule as TWO sub-protocols: `opA` (round 0, the
`(λ, ρ)` squeezes) and `opB` (round 1, its window after the group vectors: they are in its header; its message is the
proximity vector). Each is round-by-round sound on `Dg` (below) and so on the code's chain (`rbrWide_toCode`). Their
coupling (`opB`'s `(λ, ρ)` and group vectors read off the header at `opA`'s positions, and `opA` released one step
after `opB`'s window opens, L8-4's pattern) is the schedule's (L9). -/

section OpeningSplit

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {X Mm : Type} {h : ℕ}

/-- **The opening's round 0 alone** (`(λ, ρ)`): before, every claim holds of the decoded matrix; after, `Alive1`. -/
def opASt (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : X → OClaims Cl G κ μ F)
    (Ux : X → κ → Fin (2 ^ h) → F) (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (x : X) :
    List (Mm × List Dg) → Prop
  | [(_, ds)] => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
      (chalLR (vecOf d₀ w0 ds)).1 (chalLR (vecOf d₀ w0 ds)).2
  | _ => GroupsGood enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val

theorem opA_rbrWide (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) {d e A : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (clOf : X → OClaims Cl G κ μ F) (Ux : X → κ → Fin (2 ^ h) → F)
    (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR) :
    RbrWide (M := Mm) 1 (fun _ => w0) (opASt enc e clOf Ux d₀ w0 chalLR) ((A : ℝ≥0∞) / Fintype.card F * βLR) where
  round x τ msg hτ hns := by
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    have hset : {b : Fin w0 → Dg | opASt enc e clOf Ux d₀ w0 chalLR x ([] ++ [(msg, List.ofFn b)])}
        = {b | (fun y : (Cl → F) × (κ → F) => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp
            (clOf x).val y.1 y.2) (chalLR b)} := by
      ext b
      simp only [Set.mem_setOf_eq, List.nil_append, opASt, vecOf_ofFn]
    show (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure
      {b | opASt enc e clOf Ux d₀ w0 chalLR x ([] ++ [(msg, List.ofFn b)])} ≤ _
    rw [hset]
    exact (hLR _).trans (mul_le_mul' (opening_round0 enc hd h2 hA hca (Ux x) _ _ _ _ hns) le_rfl)

/-- **The opening's round 1 alone** (`J`), its window after the group vectors: its statement gives the matrix, the
claims, the `(λ, ρ)` and the group vectors (`lrOf`, `vOf`, read off the header); its message is the proximity vector
(`none`: malformed). Before, `Alive1`; after, every check at the indices. -/
def opBSt (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ) (clOf : X → OClaims Cl G κ μ F)
    (Ux : X → κ → Fin (2 ^ h) → F) (lrOf : X → (Cl → F) × (κ → F)) (vOf : X → G → μ → F) (d₀ : Dg) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (x : X) : List (Option (μ → F) × List Dg) → Prop
  | [(w, ds)] => ∃ wv, w = some wv ∧ GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
      (fun g _ _ => vOf x g) (fun _ _ => wv) (lrOf x).1 (lrOf x).2 (chalJ (vecOf d₀ m ds))
  | _ => Alive1 enc e (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val (lrOf x).1 (lrOf x).2

theorem opB_rbrWide (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (henc : Function.Injective enc) {d e : ℕ}
    (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (clOf : X → OClaims Cl G κ μ F)
    (Ux : X → κ → Fin (2 ^ h) → F) (lrOf : X → (Cl → F) × (κ → F)) (vOf : X → G → μ → F) (d₀ : Dg) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ) :
    RbrWide 1 (fun _ => m) (opBSt enc e clOf Ux lrOf vOf d₀ m chalJ)
      ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ) where
  round x τ msg hτ hns := by
    obtain rfl : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    show (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure
      {b | opBSt enc e clOf Ux lrOf vOf d₀ m chalJ x ([] ++ [(msg, List.ofFn b)])} ≤ _
    rcases msg with _ | wv
    · refine le_trans (le_of_eq ?_) zero_le
      rw [show {b : Fin m → Dg | opBSt enc e clOf Ux lrOf vOf d₀ m chalJ x ([] ++ [(none, List.ofFn b)])} = ∅ by
        ext b
        simp [opBSt]]
      exact MeasureTheory.measure_empty
    · have hset : {b : Fin m → Dg | opBSt enc e clOf Ux lrOf vOf d₀ m chalJ x ([] ++ [(some wv, List.ofFn b)])}
          = {b | (fun J => GroupsAccept enc (Ux x) (clOf x).rw (clOf x).cw (clOf x).grp (clOf x).val
              (fun g _ _ => vOf x g) (fun _ _ => wv) (lrOf x).1 (lrOf x).2 J) (chalJ b)} := by
        ext b
        simp [opBSt, vecOf_ofFn]
      rw [hset]
      exact (hJ _).trans (mul_le_mul' (opening_round1 enc henc hd h2 (Ux x) _ _ _ _ _ _ hns (vOf x) wv nQ) le_rfl)

end OpeningSplit

end ZK60.Exec
