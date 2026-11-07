/-
D63 lane L20 (2026-11-07), part 3: **the openings' knowledge on the code's chain, with the per-position count**.

* **`mask_knowledge_chain_pos`**: L16's `mask_knowledge_chain` (`M`'s three rounds with the mask rows and functionals
  EXTRACTED from the prover's log) with `CountW16Chain.lean`'s count: `q·maskEps + 3·maskEps + collisions`, instead of
  `(q + ℓ + 1)·maskEps + collisions` (`maskEps ≤ 2^-106`).
* **The regular `A` / `H` opening as two schedules** (L16-3's route for L10-3; no release needed). L10 split the opening
  into `opA` (round 0: the `(λ, ρ)` squeezes, no message) and `opB` (round 1: its window after the group vectors, its
  message the proximity vector, then the column indices). Here:
  - `opACSub`: `opA` on the code's chain, its matrix EXTRACTED (`Ux`, any function of the prover's log and the header,
    e.g. the columns extracted from the log cut at the root's first absorption, decoded);
  - `opARead`, `opBLR`, `opBCSub`: `opB` reads `opA`'s `(λ, ρ)` digests off its own header, by `opA`'s reader (and is
    doomed when that reader has not completed `opA`'s round);
  - `RbrWide.and_left`, `opACSub_rbr`, `opBCSub_rbr`: each round-by-round sound (`opA_rbrWide`, `opB_rbrWide`, carried
    to the code's chain by `rbrWide_toCode`);
  - **`opening_split`** (deterministic): if `opA` enters its window with a claim false of the extracted matrix
    (`¬ GroupsGood`) and `opB` is alive at the end, then `opA` is alive at the end, or `opB` entered its window doomed;
  - **`opening_knowledge_chain_pos`**: so the opening accepts at the end while some claim is false of the extracted,
    decoded matrix with probability at most `(q·εA + εA + coll) + (q·εB + εB + coll)`: the two one-sub-protocol
    schedules' bounds added (`opA`'s error `εA = A/|F|·βLR`, `opB`'s `εB = ((N − (e + 1))/N)^Q·βJ`).
* The numbers (`opA_eps_w16r2`, `opB_eps_w16r2`): at W16R2's opening geometry (`N = 2^15`, `e = 8052`, `Q = 280`,
  `A = N` at the δ/2 radius, `|F| = p²`, at most `2^61` `(λ, ρ)` squeezes): `εA ≤ 2^-111`, `εB ≤ 2^-113`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CountW16Chain
import ZK60Formal.ExtractW16Open

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound Code
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## `M`, per position -/

section MaskPos

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)

/-- **`M`'s rounds with the EXTRACTED data on the code's chain, with the per-position count** (D63 lane L20): the
probability that `M` enters its window with its claim false of the extracted data and is alive at the end is at most
`q·maskEps + 3·maskEps + collBound T + collBound (T + 1)` (`maskEps ≤ 2^-106`): the verifier's chain is charged `M`'s
three rounds once each, not `ℓ + 1` times. -/
theorem mask_knowledge_chain_pos (eF : ZMod gP × ZMod gP ≃ K) (dom : Fin (2 ^ 12) ↪ K) {ω : K}
    (hω : IsPrimitiveRoot ω 512) {σ κ : Type} [Fintype σ] [Fintype κ] [DecidableEq κ] {k : ℕ} (hk : 0 < k) (S : ℕ)
    (a : ℕ) {L : ℕ} (Dm : List (QB L × Dig) → List (TItem × Dig) → MData K (Fin (2 ^ 12)) σ κ k 512)
    (eR : κ ≃ Fin (2 * S + 2)) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) {It' : Type} (C : ChainEnc It' (QB L) Dig)
    (toT : It' → TItem) (St : Steps It') (hS : StepsOK W toT St) {α : Type} (heads : α → List It') (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap St.items).length ≤ ℓ) (s : ℕ) (hsa : s < a)
    (hhd : ∀ o, (((heads o).take s).flatMap St.items).length ≤ s) (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q)
    (hstab : ∀ (H : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (It' × Dig)) (qs : List (QB L)),
      C.Chain H τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × Dig), Dm (proverLog A P) ((τ.map (toTE toT) ++ ext).take a)
          = Dm (proverLog A P') ((τ.map (toTE toT) ++ ext).take a)) :
    prH (fun H => (a ≤ (cChain C toT St H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT St H (heads (A.run H))).take a) = some 0
          ∧ ¬ MGood dom ω 1 1024 1023
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).wt
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).val
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).Ub
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).u
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).La
              (Dm (A.runLog H).2 ((cChain C toT St H (heads (A.run H))).take a)).Lb)
        ∧ subSt W (maskCSubX U eF dom ω S a (Dm (A.runLog H).2) eR (fun _ => False))
            (cChain C toT St H (heads (A.run H))))
      ≤ (q : ℝ≥0∞) * maskEps (K := K) k S + 3 * maskEps (K := K) k S + collBound (q + ℓ + 1) Dig
        + collBound (q + ℓ + 1 + 1) Dig := by
  have hfull : ∀ H, proverLog A ((C.stepRun St heads A).runLog H).2 = (A.runLog H).2 := fun H => by
    rw [ChainEnc.stepRun, OC.runLog_bind]
    exact proverLog_runLog A H _
  have hmem : ∀ P c, c ∈ maskCsAt U eF dom ω S a Dm eR A P →
      c = maskCSubX U eF dom ω S a (Dm (proverLog A P)) eR (fun _ => False) := by
    intro P c hc
    exact List.mem_singleton.mp hc
  have hmain := fs_code_chain_sound_sched_log_pos W hW (maskCsAt U eF dom ω S a Dm eR A)
    [(maskCSubX U eF dom ω S a (Dm []) eR (fun _ => False)).sk] (fun _ => rfl) (maskEps (K := K) k S)
    (fun P c hc => by
      rw [hmem P c hc]
      exact maskCSubX_rbr U eF dom hω hk S a _ eR _)
    (fun P c hc => by
      rw [hmem P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmem P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmem P c hc]
      exact hsa) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [maskCsAt, maskCsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      have he := hstab H P P' τ qs hc hl hq hpre hans ext
      simp only [maskCSubX, toCSub, he]) q A hA
  have hcharge : ([(maskCSubX U eF dom ω S a (Dm []) eR (fun _ => False)).sk].map
      (fun k' => (k'.R.n : ℝ≥0∞) * k'.ε)).sum = 3 * maskEps (K := K) k S := by
    simp [CSub.sk, maskCSubX, toCSub, maskRounds]
  rw [hcharge] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro H hH
  rw [Set.mem_ofPred_eq] at hH ⊢
  rw [maskCsAt, hfull H, allSt_singleton]
  obtain ⟨⟨h1, h2, h3⟩, h4⟩ := hH
  exact ⟨⟨0, _, rfl, h1, h2, h3, id⟩, h4⟩

end MaskPos

/-! ## What the good predicates say about the claims (the semantic half of the bridge) -/

section Good

/-- **`M`'s good case makes every functional true of the decoded mask polynomials** (offset `o = 1`, the fixed
code): when `MGood` holds of the extracted data, there is a decoding `Rh` of the extracted rows (unique when
`2e + K < N`, `MDec.unique`) under which every functional's claimed value is its true value
`Σ_s Σ_j w_{i,s,j}·Ah_s(ω^j)`, `Ah = Σ La·Rh` (`mResidual_ne_zero_shift`: a nonzero coefficient would make the residual
nonzero). -/
theorem mGood_val_eq_true {E ι σ κ : Type} [Field E] [Fintype E] [Fintype ι] [Fintype σ] [Fintype κ] {k m : ℕ}
    (dom : ι ↪ E)
    (ω : E) {e K : ℕ} (D : MData E ι σ κ k m) (hg : MGood dom ω 1 e K D.wt D.val D.Ub D.u D.La D.Lb) :
    ∃ Rh, MDec dom e K D.Ub D.u Rh ∧ ∀ i, D.val i = mTrue ω D.wt (mDecA D.La Rh) i := by
  obtain ⟨Rh, hdec, hres⟩ := (mGood_iff D).mp hg
  refine ⟨Rh, hdec, fun i => ?_⟩
  by_contra hne
  exact mResidual_ne_zero_shift D.val _ _ ⟨i, hne⟩ hres

/-- **An opening's good case makes every claim true of the decoded extracted matrix** (`GroupsGood`'s second half). -/
theorem groupsGood_claims {E ι κ μ G Cl : Type} [Field E] [Fintype ι] [Fintype κ] [Fintype μ]
    (enc : (μ → E) →ₗ[E] (ι → E)) (e : ℕ) (U : κ → ι → E) (rw : Cl → κ → E) (cw : G → μ → E) (grp : Cl → G)
    (val : Cl → E) (hg : GroupsGood enc e U rw cw grp val) :
    ∀ c, claimValue rw cw grp (decodeRows enc e U) c = val c :=
  hg.2

end Good

/-! ## The regular opening: `opA` and `opB` as two schedules -/

section OpeningPos

/-- A state guarded by a condition on the statement is round-by-round sound with the same error. -/
theorem _root_.ZK60.Sound.RbrWide.and_left {X M D : Type} [Fintype D] [Nonempty D] {n : ℕ} {w : ℕ → ℕ}
    {St : X → List (M × List D) → Prop} {ε : ℝ≥0∞} (ok : X → Prop) (h : RbrWide n w St ε) :
    RbrWide n w (fun x τ => ok x ∧ St x τ) ε where
  round x τ m hτ hns := by
    by_cases hx : ok x
    · exact le_trans (MeasureTheory.measure_mono (fun b hb => hb.2)) (h.round x τ m hτ (fun h' => hns ⟨hx, h'⟩))
    · have he : {b : Fin (w τ.length) → D | ok x ∧ St x (τ ++ [(m, List.ofFn b)])} = ∅ :=
        Set.eq_empty_iff_forall_notMem.mpr (fun b hb => hx hb.1)
      rw [he, MeasureTheory.measure_empty]
      exact zero_le

/-- `opA`'s round schedule on the code's chain: one round, no message, `w0` squeezes (`zk_rhos`' `(λ, ρ)`). -/
def opARounds (w0 : ℕ) : Rounds := ⟨1, fun _ => w0, fun _ => false, fun _ => []⟩

/-- `opB`'s round schedule: one round, its message absorbed under `lab` (`"pcs-prox"`), then `m` squeezes
(`challenge_indices`). -/
def opBRounds (lab : List UInt8) (m : ℕ) : Rounds := ⟨1, fun _ => m, fun _ => true, fun _ => lab⟩

/-- **`opA`'s digests read off a header** by `opA`'s own reader (from `opA`'s window on): its completed round's
digests, or nothing. -/
def opARead (W : UInt64 → ℕ) (aA w0 : ℕ) (hdr : List (TItem × Dig)) : Option (List Dig) :=
  match cRd (opARounds w0) W (hdr.drop aA) with
  | some ([(_, ds)], _, _) => some ds
  | _ => none

theorem opARead_some {W : UInt64 → ℕ} {aA w0 : ℕ} {hdr : List (TItem × Dig)} {ds : List Dig}
    (h : opARead W aA w0 hdr = some ds) :
    ∃ (x : List UInt8) (pm : Option (List UInt8)) (ds' : List Dig),
      cRd (opARounds w0) W (hdr.drop aA) = some ([(x, ds)], pm, ds') := by
  unfold opARead at h
  rcases hc : cRd (opARounds w0) W (hdr.drop aA) with _ | ⟨ptr, pm, ds'⟩
  · rw [hc] at h
    simp at h
  · rw [hc] at h
    rcases ptr with _ | ⟨⟨x, ds0⟩, _ | ⟨y, rest⟩⟩
    · simp at h
    · simp only [Option.some.injEq] at h
      subst h
      exact ⟨x, pm, ds', rfl⟩
    · simp at h

variable {F κ μ G Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype μ]
  [Fintype Cl] [DecidableEq Cl] [DecidableEq G] {h : ℕ}

/-- The `(λ, ρ)` `opB` reads off its header: `opA`'s digests (as halves) through `opA`'s derivation. -/
def opBLR (W : UInt64 → ℕ) (aA w0 : ℕ) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F))
    (hdr : List (TItem × Dig)) : (Cl → F) × (κ → F) :=
  chalLR (vecOf d₀ w0 (((opARead W aA w0 hdr).getD []).map halves))

/-- A header together with the matrix extracted for it. -/
abbrev HdrX (κ F : Type) (h : ℕ) := List (TItem × Dig) × (κ → Fin (2 ^ h) → F)

/-- **`opA` on the code's chain**, its window at `aA`, its claims read off the header (`clOf`), its matrix the
extracted one `Ux hdr` (`Ux` may read the prover's log). -/
noncomputable def opACSub (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) : CSub Dig :=
  toCSub aA (opARounds w0) εA
    (opASt (Mm := Unit) enc e (fun x : HdrX κ F h => clOf x.1) (fun x : HdrX κ F h => x.2) d₀ w0 chalLR)
    (fun hdr => (hdr, Ux hdr)) (fun _ => ()) (fun _ => False)

/-- **`opB`'s state**: `opA`'s round is complete in the header, and L10's `opBSt` with the claims and the matrix at
`opA`'s window, `opA`'s `(λ, ρ)` read off the header, and the group vectors `vOf` read off the header. -/
def opBSt' (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg)
    (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h)))
    (x : HdrX κ F h) (τ : List (Option (μ → F) × List Dg)) : Prop :=
  (opARead W aA w0 x.1).isSome = true ∧ opBSt enc e (fun y : HdrX κ F h => clOf (y.1.take aA)) (fun y => y.2)
    (fun y => opBLR W aA w0 d₀ chalLR y.1) (fun y => vOf y.1) d₀ m chalJ x τ

/-- **`opB` on the code's chain**, its window at `aB` (after the group vectors), its message decoded by `decB`. -/
noncomputable def opBCSub (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) : CSub Dig :=
  toCSub aB (opBRounds labB m) εB (opBSt' W aA w0 enc e clOf vOf d₀ chalLR m chalJ)
    (fun hdr => (hdr, Ux (hdr.take aA))) decB (fun _ => False)

/-- `opA` is round-by-round sound on the code's chain (L10's `opA_rbrWide`, `rbrWide_toCode`). -/
theorem opACSub_rbr (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) {d e A : ℕ} (hd : MinDist (LinearMap.range enc) d)
    (h2 : 2 * e < d) (hA : e + 1 ≤ A) (hca : CAOn Unit (LinearMap.range enc) e A)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F) (d₀ : Dg)
    (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR) (aA : ℕ) :
    RbrWide (opACSub enc e clOf Ux d₀ w0 chalLR aA ((A : ℝ≥0∞) / Fintype.card F * βLR)).R.n
      (opACSub enc e clOf Ux d₀ w0 chalLR aA ((A : ℝ≥0∞) / Fintype.card F * βLR)).R.w
      (opACSub enc e clOf Ux d₀ w0 chalLR aA ((A : ℝ≥0∞) / Fintype.card F * βLR)).St
      (opACSub enc e clOf Ux d₀ w0 chalLR aA ((A : ℝ≥0∞) / Fintype.card F * βLR)).ε :=
  rbrWide_toCode aA (opARounds w0) _ _ _ _ _
    (opA_rbrWide (Mm := Unit) enc hd h2 hA hca (fun x : HdrX κ F h => clOf x.1) (fun x : HdrX κ F h => x.2) d₀ w0
      chalLR βLR hLR)

omit [Fintype F] [DecidableEq κ] [DecidableEq Cl] in
/-- `opB` is round-by-round sound on the code's chain (L10's `opB_rbrWide`, guarded by `opA`'s completed round). -/
theorem opBCSub_rbr (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F))
    (henc : Function.Injective enc) {d e : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aB : ℕ) :
    RbrWide (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).R.n
      (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).R.w
      (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).St
      (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)).ε :=
  rbrWide_toCode aB (opBRounds labB m) _ _ _ _ _
    (RbrWide.and_left (fun x : HdrX κ F h => (opARead W aA w0 x.1).isSome = true)
      (opB_rbrWide enc henc hd h2 (fun y : HdrX κ F h => clOf (y.1.take aA)) (fun y => y.2)
        (fun y => opBLR W aA w0 d₀ chalLR y.1) (fun y => vOf y.1) d₀ m chalJ βJ hJ))

omit [Fintype F] [DecidableEq F] [DecidableEq κ] [DecidableEq Cl] in
/-- **The opening's split** (deterministic; L16-3's route). If `opA`'s window is at a step's end and `opB`'s window
(after `opA`'s) lies in the chain, then `opA` is alive at the end of the chain, or `opB` enters its window doomed: when
`opB`'s header state holds, `opA`'s round is complete in that header, frozen, and its `(λ, ρ)` are the ones `opB`
reads. -/
theorem opening_split (W : UInt64 → ℕ) (aA aB : ℕ) (hab : aA ≤ aB) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F))
    (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8)
    (decB : List UInt8 → Option (μ → F)) (εA εB : ℝ≥0∞) (τ : List (TItem × Dig))
    (hA1 : tRem W (τ.take aA) = some 0) (hB0 : aB ≤ τ.length) :
    subSt W (opACSub enc e clOf Ux d₀ w0 chalLR aA εA) τ
      ∨ ¬ (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB) [] := by
  by_cases hBst : (opBCSub W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB).St (τ.take aB) []
  · left
    obtain ⟨hsome, hal1⟩ : (opARead W aA w0 (τ.take aB)).isSome = true ∧ _ := hBst
    obtain ⟨ds, hds⟩ := Option.isSome_iff_exists.mp hsome
    obtain ⟨x, pm, ds', hrd⟩ := opARead_some hds
    have hsplit : τ.drop aA = (τ.take aB).drop aA ++ τ.drop aB := by
      conv_lhs => rw [← List.take_append_drop aB τ]
      rw [List.drop_append_of_le_length (by rw [List.length_take]; omega)]
    have hfull : cRd (opARounds w0) W (τ.drop aA) = some ([(x, ds)], pm, ds') := by
      rw [hsplit, cRd, List.foldl_append]
      have h0 : List.foldl (cRdStep (opARounds w0) W) (some ([], none, [])) ((τ.take aB).drop aA)
          = some ([(x, ds)], pm, ds') := hrd
      rw [h0]
      exact foldl_cRdStep_frozen (opARounds w0) W (show (opARounds w0).n ≤ [(x, ds)].length from le_rfl) _
    have htt : (τ.take aB).take aA = τ.take aA := by
      rw [List.take_take, min_eq_left hab]
    right
    left
    refine ⟨hA1, ?_⟩
    have hlr : opBLR W aA w0 d₀ chalLR (τ.take aB) = chalLR (vecOf d₀ w0 (ds.map halves)) := by
      unfold opBLR
      rw [hds]
      rfl
    show liftC (fun τr => opASt (Mm := Unit) enc e (fun x : HdrX κ F h => clOf x.1) (fun x : HdrX κ F h => x.2) d₀ w0
      chalLR (τ.take aA, Ux (τ.take aA)) (τr.map (fun p => ((), p.2.map halves)))) (cRd (opARounds w0) W (τ.drop aA))
    rw [hfull]
    show Alive1 enc e (Ux (τ.take aA)) (clOf (τ.take aA)).rw (clOf (τ.take aA)).cw (clOf (τ.take aA)).grp
      (clOf (τ.take aA)).val (chalLR (vecOf d₀ w0 (ds.map halves))).1 (chalLR (vecOf d₀ w0 (ds.map halves))).2
    have hal1' : Alive1 enc e (Ux ((τ.take aB).take aA)) (clOf ((τ.take aB).take aA)).rw
        (clOf ((τ.take aB).take aA)).cw (clOf ((τ.take aB).take aA)).grp (clOf ((τ.take aB).take aA)).val
        (opBLR W aA w0 d₀ chalLR (τ.take aB)).1 (opBLR W aA w0 d₀ chalLR (τ.take aB)).2 := hal1
    rw [htt, hlr] at hal1'
    exact hal1'
  · right
    exact hBst

variable {L : ℕ}

/-- `opA`'s one-sub-protocol schedule at the prover's log recovered from a log. -/
noncomputable def opACsAt (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (aA : ℕ) (εA : ℝ≥0∞) {α : Type}
    (Pv : OC (QB L) Dig α) (P : List (QB L × Dig)) : List (CSub Dig) :=
  [opACSub enc e clOf (Ux (proverLog Pv P)) d₀ w0 chalLR aA εA]

/-- `opB`'s one-sub-protocol schedule at the prover's log recovered from a log. -/
noncomputable def opBCsAt (W : UInt64 → ℕ) (aA w0 : ℕ) (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (e : ℕ)
    (clOf : List (TItem × Dig) → OClaims Cl G κ μ F) (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (vOf : List (TItem × Dig) → G → μ → F) (d₀ : Dg) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (m : ℕ)
    {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (labB : List UInt8) (decB : List UInt8 → Option (μ → F))
    (aB : ℕ) (εB : ℝ≥0∞) {α : Type} (Pv : OC (QB L) Dig α) (P : List (QB L × Dig)) : List (CSub Dig) :=
  [opBCSub W aA w0 enc e clOf (Ux (proverLog Pv P)) vOf d₀ chalLR m chalJ labB decB aB εB]

/-- **The regular opening's knowledge on the code's chain, with the per-position count** (D63 lane L20; L16-3's
route for L10-3). For any extraction `Ux` of the opening's matrix from the prover's log (frozen once the chain's first
`s` entries are logged, `hUx`), `opA`'s window at `aA > s` and `opB`'s at `aB ≥ aA`: the probability that `opA`'s
window is at a step's end with a claim FALSE of the extracted, decoded matrix (`¬ GroupsGood`) while `opB`'s window is
at a step's end and `opB` is alive at the end (its checks, `GroupsAccept`, at the chain's `(λ, ρ)` and indices) is at
most `(q·εA + εA + coll) + (q·εB + εB + coll)`: the two schedules, each a single sub-protocol. -/
theorem opening_knowledge_chain_pos (enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)) (henc : Function.Injective enc)
    {d e A : ℕ} (hd : MinDist (LinearMap.range enc) d) (h2 : 2 * e < d) (hA : e + 1 ≤ A)
    (hca : CAOn Unit (LinearMap.range enc) e A) (clOf : List (TItem × Dig) → OClaims Cl G κ μ F)
    (Ux : List (QB L × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F) (vOf : List (TItem × Dig) → G → μ → F)
    (d₀ : Dg) (w0 : ℕ) (chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)) (βLR : ℝ≥0∞)
    (hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
      ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR)
    (m : ℕ) {nQ : ℕ} (chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))) (βJ : ℝ≥0∞)
    (hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
      ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ)
    (labB : List UInt8) (decB : List UInt8 → Option (μ → F)) (aA aB : ℕ) (hab : aA ≤ aB)
    (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) {It' : Type} (C : ChainEnc It' (QB L) Dig)
    (toT : It' → TItem) (St : Steps It') (hS : StepsOK W toT St) {α : Type} (heads : α → List It') (ℓ : ℕ)
    (hℓ : ∀ o, ((heads o).flatMap St.items).length ≤ ℓ) (s : ℕ) (hsa : s < aA)
    (hhd : ∀ o, (((heads o).take s).flatMap St.items).length ≤ s) (q : ℕ) (Pv : OC (QB L) Dig α) (hPv : Pv.Bounded q)
    (hUx : ∀ (H : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (It' × Dig)) (qs : List (QB L)),
      C.Chain H τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' → (∀ e ∈ P', e.2 = H e.1) →
        ∀ ext : List (TItem × Dig), Ux (proverLog Pv P) ((τ.map (toTE toT) ++ ext).take aA)
          = Ux (proverLog Pv P') ((τ.map (toTE toT) ++ ext).take aA)) :
    prH (fun H => tRem W ((cChain C toT St H (heads (Pv.run H))).take aA) = some 0
          ∧ ¬ GroupsGood enc e (Ux (Pv.runLog H).2 ((cChain C toT St H (heads (Pv.run H))).take aA))
              (clOf ((cChain C toT St H (heads (Pv.run H))).take aA)).rw
              (clOf ((cChain C toT St H (heads (Pv.run H))).take aA)).cw
              (clOf ((cChain C toT St H (heads (Pv.run H))).take aA)).grp
              (clOf ((cChain C toT St H (heads (Pv.run H))).take aA)).val
          ∧ aB ≤ (cChain C toT St H (heads (Pv.run H))).length
          ∧ tRem W ((cChain C toT St H (heads (Pv.run H))).take aB) = some 0
          ∧ subSt W (opBCSub W aA w0 enc e clOf (Ux (Pv.runLog H).2) vOf d₀ chalLR m chalJ labB decB aB
              ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ))
            (cChain C toT St H (heads (Pv.run H))))
      ≤ ((q : ℝ≥0∞) * ((A : ℝ≥0∞) / Fintype.card F * βLR) + (A : ℝ≥0∞) / Fintype.card F * βLR
          + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ)
          + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ
          + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig) := by
  set εA : ℝ≥0∞ := (A : ℝ≥0∞) / Fintype.card F * βLR with hεA
  set εB : ℝ≥0∞ := (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ nQ * βJ
    with hεB
  have hfull : ∀ H, proverLog Pv ((C.stepRun St heads Pv).runLog H).2 = (Pv.runLog H).2 := fun H => by
    rw [ChainEnc.stepRun, OC.runLog_bind]
    exact proverLog_runLog Pv H _
  have hmA : ∀ P c, c ∈ opACsAt enc e clOf Ux d₀ w0 chalLR aA εA Pv P →
      c = opACSub enc e clOf (Ux (proverLog Pv P)) d₀ w0 chalLR aA εA :=
    fun P c hc => List.mem_singleton.mp hc
  have hmB : ∀ P c, c ∈ opBCsAt W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB Pv P →
      c = opBCSub W aA w0 enc e clOf (Ux (proverLog Pv P)) vOf d₀ chalLR m chalJ labB decB aB εB :=
    fun P c hc => List.mem_singleton.mp hc
  have hA' := fs_code_chain_sound_sched_log_pos W hW (opACsAt enc e clOf Ux d₀ w0 chalLR aA εA Pv)
    [(opACSub enc e clOf (Ux []) d₀ w0 chalLR aA εA).sk] (fun _ => rfl) εA
    (fun P c hc => by
      rw [hmA P c hc]
      exact opACSub_rbr enc hd h2 hA hca clOf _ d₀ w0 chalLR βLR hLR aA)
    (fun P c hc => by
      rw [hmA P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmA P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmA P c hc]
      exact hsa) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [opACsAt, opACsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      have he := hUx H P P' τ qs hc hl hq hpre hans ext
      simp only [opACSub, toCSub, he]) q Pv hPv
  have hB' := fs_code_chain_sound_sched_log_pos W hW
    (opBCsAt W aA w0 enc e clOf Ux vOf d₀ chalLR m chalJ labB decB aB εB Pv)
    [(opBCSub W aA w0 enc e clOf (Ux []) vOf d₀ chalLR m chalJ labB decB aB εB).sk] (fun _ => rfl) εB
    (fun P c hc => by
      rw [hmB P c hc]
      exact opBCSub_rbr W aA w0 enc henc hd h2 clOf _ vOf d₀ chalLR m chalJ βJ hJ labB decB aB)
    (fun P c hc => by
      rw [hmB P c hc]
      exact le_rfl)
    (fun P k' c τ h ks ds hc _ _ _ _ hrel => by
      have hc' := hmB P c (List.mem_of_getElem? hc)
      rw [hc'] at hrel
      exact absurd hrel id)
    C toT St hS heads ℓ hℓ s
    (fun P c hc => by
      rw [hmB P c hc]
      exact lt_of_lt_of_le hsa hab) hhd
    (fun H P P' τ qs hc hl hq hpre hans ext => by
      rw [opBCsAt, opBCsAt, allSt_singleton, allSt_singleton]
      refine subSt_congr W _ _ _ rfl rfl Iff.rfl ?_
      have he := hUx H P P' τ qs hc hl hq hpre hans ext
      have htt : ((τ.map (toTE toT) ++ ext).take aB).take aA = (τ.map (toTE toT) ++ ext).take aA := by
        rw [List.take_take, min_eq_left hab]
      simp only [opBCSub, toCSub, htt, he]) q Pv hPv
  have hcA : ([(opACSub enc e clOf (Ux []) d₀ w0 chalLR aA εA).sk].map (fun k' => (k'.R.n : ℝ≥0∞) * k'.ε)).sum
      = εA := by
    simp [CSub.sk, opACSub, toCSub, opARounds]
  have hcB : ([(opBCSub W aA w0 enc e clOf (Ux []) vOf d₀ chalLR m chalJ labB decB aB εB).sk].map
      (fun k' => (k'.R.n : ℝ≥0∞) * k'.ε)).sum = εB := by
    simp [CSub.sk, opBCSub, toCSub, opBRounds]
  rw [hcA] at hA'
  rw [hcB] at hB'
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans (add_le_add hA' hB'))
  intro H hH
  rw [Set.mem_ofPred_eq] at hH
  obtain ⟨hA1, hng, hB0, hB1, hBal⟩ := hH
  have hA0 : aA ≤ (cChain C toT St H (heads (Pv.run H))).length := le_trans hab hB0
  rcases opening_split W aA aB hab enc e clOf (Ux (Pv.runLog H).2) vOf d₀ w0 chalLR m chalJ labB decB εA εB _ hA1 hB0
    with hAal | hBdoom
  · left
    rw [Set.mem_ofPred_eq, opACsAt, hfull H, allSt_singleton]
    exact ⟨⟨0, _, rfl, hA0, hA1, hng, id⟩, hAal⟩
  · right
    rw [Set.mem_ofPred_eq, opBCsAt, hfull H, allSt_singleton]
    exact ⟨⟨0, _, rfl, hB0, hB1, hBdoom, id⟩, hBal⟩

end OpeningPos

/-! ## The numbers at W16R2's opening geometry -/

section Numbers

/-- `((2^15 − 8053)/2^15)^280 ≤ 2^-113` (W16R2's column term at the δ/2 radius `e = 8052`, `Q = 280`: about
`2^-113.9`). -/
theorem opB_col_w16r2_nat : (2 ^ 15 - (8052 + 1)) ^ 280 * 2 ^ 113 ≤ 1 * (2 ^ 15) ^ 280 := by
  rw [show (280 : ℕ) = 140 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- **`opB`'s error at W16R2** (`N = 2^15`, `e = 8052`, `Q = 280`, the indices exactly uniform): at most `2^-113`. -/
theorem opB_eps_w16r2 :
    (((Fintype.card (Fin (2 ^ 15)) - (8052 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 15))) ^ 280 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 113 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) opB_col_w16r2_nat

/-- **`opA`'s error at W16R2** (`A = N = 2^15` at the δ/2 radius, `|F| = p²` with `p` within `2^32` below `2^64`,
the `(λ, ρ)` bias over at most `2^61` squeezes at most `2`): at most `2^-111`. Stated for a variable `p` (L7-4). -/
theorem opA_eps_w16r2 {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 15 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 111 := by
  have hb : (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ ((2 : ℕ) : ℝ≥0∞) := by
    exact_mod_cast fp2_bias_pow_le_two hp1 (by omega)
  have hp0 : 0 < p := by omega
  calc ((2 ^ 15 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ ((2 ^ 15 : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * ((2 : ℕ) : ℝ≥0∞) := by
        rw [hF]
        exact mul_le_mul' le_rfl hb
    _ = ((2 ^ 15 * 2 : ℕ) : ℝ≥0∞) / ((p ^ 2 * 1 : ℕ) : ℝ≥0∞) := by
        rw [← natCast_div_mul_div, Nat.cast_one, div_one]
    _ ≤ (2⁻¹ : ℝ≥0∞) ^ 111 := by
        rw [inv_two_pow_eq]
        refine natCast_div_le_div (mul_ne_zero (pow_ne_zero 2 (by omega)) one_ne_zero) (by norm_num) ?_
        calc 2 ^ 15 * 2 * 2 ^ 111 = 2 ^ 127 := by norm_num
          _ ≤ (2 ^ 64 - 2 ^ 32) ^ 2 := by norm_num
          _ ≤ p ^ 2 := Nat.pow_le_pow_left hp2 2
          _ = 1 * (p ^ 2 * 1) := by ring

/-- `((2^16 − 16299)/2^16)^256 ≤ 2^-105` (a rate-1/4 opening at the δ/3 radius: `N = 2^16`, `e = 16298`, `Q = 256`,
about `2^-105.6`; R13's geometry as an assumption for L17 to confirm). -/
theorem opB_col_r13_nat : (2 ^ 16 - (16298 + 1)) ^ 256 * 2 ^ 105 ≤ 1 * (2 ^ 16) ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- **`opB`'s error at a rate-1/4, δ/3 geometry** (`N = 2^16`, `e = 16298`, `Q = 256`): at most `2^-105`. -/
theorem opB_eps_r13 :
    (((Fintype.card (Fin (2 ^ 16)) - (16298 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 16))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 105 := by
  rw [mul_one, Fintype.card_fin, inv_two_pow_eq, natCast_div_pow]
  exact natCast_div_le_div (by positivity) (by norm_num) opB_col_r13_nat

/-- **`opA`'s error for any correlated-agreement count `A ≤ 2^15`** (W16R2's δ/2: `A = N = 2^15`; a δ/3 geometry:
`A = e + 1`), `|F| = p²`, the `(λ, ρ)` bias over at most `2^61` squeezes at most `2`: at most `2^-111`. -/
theorem opA_eps_le {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) (A : ℕ) (hA : A ≤ 2 ^ 15) :
    (A : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0) ≤ (2⁻¹ : ℝ≥0∞) ^ 111 :=
  le_trans (mul_le_mul' (ENNReal.div_le_div_right (by exact_mod_cast hA) _) le_rfl) (opA_eps_w16r2 p hp1 hp2 hF hw0)

end Numbers

/-! ## The row encoder's code facts (L20-4) -/

section EncCode

open Code Polynomial

variable {F : Type} [Field F]

/-- **The row encoder's words are Reed–Solomon words of degree `≤ n + Q − 1`** at its points (`encPoly` has degree
`< n + Q`, `encPoly_natDegree_lt`). -/
theorem encLin_range_le {n Q N : ℕ} (pts : Fin N → F) (hpts : Function.Injective pts) (R : RowForm F n) (hn : 0 < n) :
    LinearMap.range (encLin (Q := Q) pts R) ≤ rsCode ⟨pts, hpts⟩ (n + Q - 1) := by
  rintro w ⟨v, rfl⟩
  have hdeg := encPoly_natDegree_lt R hn (fun i => v (Fin.castAdd Q i)) (fun k => v (Fin.natAdd n k))
  exact mem_rsCode.mpr ⟨_, by omega, fun x => encLin_apply pts R v x⟩

/-- **The encoder's code has the RS minimum distance** `N − (n + Q − 1)` (a subcode, `MinDist.anti`). -/
theorem encLin_minDist {n Q N : ℕ} (pts : Fin N → F) (hpts : Function.Injective pts) (R : RowForm F n)
    (hn : 0 < n) : MinDist (LinearMap.range (encLin (Q := Q) pts R)) (N - (n + Q - 1)) := by
  have h := minDist_rsCode (⟨pts, hpts⟩ : Fin N ↪ F) (n + Q - 1)
  rw [Fintype.card_fin] at h
  exact h.anti (encLin_range_le pts hpts R hn)

/-- **Correlated agreement at the δ/2 radius for the encoder's code**, with `A = N` exceptions (`caOn_rsCode`,
BCIKS20 Theorem 4.1, carried to the subcode by `CAOn.subcode`), for `2e + (n + Q − 1) + 1 ≤ N`. -/
theorem encLin_caOn [Finite F] {n Q N e : ℕ} (pts : Fin N → F) (hpts : Function.Injective pts) (R : RowForm F n)
    (hn : 0 < n) (hN : 2 * e + (n + Q - 1) + 1 ≤ N) :
    CAOn Unit (LinearMap.range (encLin (Q := Q) pts R)) e N := by
  have h := caOn_rsCode (⟨pts, hpts⟩ : Fin N ↪ F) (e := e) (K := n + Q - 1) (by rw [Fintype.card_fin]; exact hN)
  rw [Fintype.card_fin] at h
  have hd := minDist_rsCode (⟨pts, hpts⟩ : Fin N ↪ F) (n + Q - 1)
  rw [Fintype.card_fin] at hd
  exact h.subcode hd (by omega) (encLin_range_le pts hpts R hn) (by omega)

/-- **W16R2's opening code facts** (`N = 2^15`, `n = 2^14`, `Q = 280`, `e = 8052`): minimum distance `16105`,
`2e < 16105`, `e + 1 ≤ N`, correlated agreement with `A = N`, exactly the inputs `hd`, `h2`, `hA`, `hca` of
`opening_knowledge_chain_pos` (with `2e + K + 1 = 2^15`: the radius is tight). -/
theorem w16r2_open_code_facts [Finite F] (pts : Fin (2 ^ 15) → F) (hpts : Function.Injective pts)
    (R : RowForm F (2 ^ 14)) :
    MinDist (LinearMap.range (encLin (Q := 280) pts R)) 16105 ∧ 2 * 8052 < 16105 ∧ 8052 + 1 ≤ 2 ^ 15
      ∧ CAOn Unit (LinearMap.range (encLin (Q := 280) pts R)) 8052 (2 ^ 15) := by
  have hd := encLin_minDist (Q := 280) pts hpts R (by norm_num)
  have e1 : (2 : ℕ) ^ 15 - (2 ^ 14 + 280 - 1) = 16105 := by norm_num
  rw [e1] at hd
  exact ⟨hd, by norm_num, by norm_num, encLin_caOn pts hpts R (by norm_num) (by norm_num)⟩

end EncCode

end ZK60.Exec
