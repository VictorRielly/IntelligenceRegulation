/-
D63 lane L21 (2026-11-07), part 7: **`hRel` and `hLk` with L20's per-position count, on the block verifier's
acceptance, against the approved target** (finding L20-5; L21-5 closed).

`RelW16Chain.fs_sq_knowledge` composes the define draws and LogUp's `β, γ, α` with L8's count, which charges every
verifier position the largest escape count: LogUp's constant term alone is then about `2^-82.9`, above the target. This
file redoes the composition with L20's `fs_code_chain_sound_sched_log_pos` (`CountW16Chain.lean`), which charges the
verifier's own positions only the rounds they start, and puts the pieces together on L20's `BlockAcc`:

* `sqND`, `sqSk`, `sqAt_sk`, `sqSk_charge`: the squeeze-run sub-protocols' skeleton is the same at every log, and its
  charge is `Σ n·e·fibC/|Dig|`;
* **`fs_sq_knowledge_pos`**: `fs_sq_knowledge` with the per-position count:
  `(q·emax + Σ n·e)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`;
* `defND`, `sqND_defSq`, **`block_defines_fs_knowledge_pos`**: the define draws of any slots `ks`, per position:
  `(q·dmax + Σ_k draws_k·dg_k)/|K|·…`; `defND_le`, `rung_draws_sum`, `rung_defND_le`: at the W16R2 rung
  `Σ_k draws_k·dg_k ≤ 351·dmax`;
* **`block_logup_fs_knowledge_pos`**: LogUp, per position: `(q·e + 3·e)/|K|·…`, `e = N + 2M`;
* **`rel_of_defines_pos`**: `hRel` (or any event) from `nd` define schedules, per position;
* **`lk_of_logup_pos`**: `hLk` (or any event) from LogUp, given that every outcome either fails the helpers' event
  `EvH` (bounded by its own define schedules) or is a win against LogUp (`LkWin`). Unlike `lk_of_logup`, the helpers'
  event is any event, so it can carry `OpenTrue` (finding L21-1 applies to the helpers' zero-checks too);
* `sched_pos_le_u126`, `nsmul_u126`, `lk_main_le_u126`, `lk_pos_le_u126`: the numbers in L20's units `(q + 1)·c/2^126`:
  one define schedule `c = dmax + ND + 2^15`, LogUp `c = 26,370,000 + 2^15` for `N + 2M ≤ 35,153,256`;
* **`block_knowledge_acc_mt`**: L20's `block_knowledge_acc` with `hOpen`, `hRel`, `hLk` in the `OpenTrue` form
  (findings L21-1 … L21-3);
* **`block_knowledge_target_mt`**: everything together: for ANY block shape, with the openings' chain bounds (L20),
  two define schedules covering `hRel`'s event, LogUp with two define schedules covering the helpers' event, and the
  budget, the block verifier accepts while the extracted planes fail `BlockSat` with probability at most
  `εsTarget q = q·2^-100 + 2^-100`, for EVERY `q`;
* `w16r2_rel_lk_budget`, `w16r2_budget_mt`: at W16R2 the relations and LogUp use `26,647,409 ≤ 2^25` of L20's budget
  and the whole block `30,202,737 ≤ 2^26`.

Facts about the literal prime are stated for a variable `p` within `2^32` below `2^64` (L7-4). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RelW16Block
import ZK60Formal.OpenKnowBlock

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The squeeze-run sub-protocols' skeleton and its charge -/

section Skel

variable {K : Type} {L : ℕ}

/-- **The sub-protocols' rounds weighted by their escape counts**: `Σ n·e`. -/
def sqND (sxs : List (SqX K L)) : ℕ := (sxs.map (fun sx => sx.n * sx.e)).sum

/-- **The sub-protocols' skeleton**: windows, rounds and errors (the schedule's, at every log). -/
noncomputable def sqSk (sxs : List (SqX K L)) : List CSk :=
  sxs.map (fun sx => (⟨sx.a, sqR sx.n, ((sx.e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig⟩ : CSk))

/-- Their charge: `Σ n·(e·fibC/|Dig|) = (Σ n·e)·fibC/|Dig|`. -/
theorem sqSk_charge (sxs : List (SqX K L)) :
    ((sqSk sxs).map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum = ((sqND sxs * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
  induction sxs with
  | nil => simp only [sqSk, sqND, List.map_nil, List.sum_nil, zero_mul, Nat.cast_zero, ENNReal.zero_div]
  | cons sx l ih =>
    have hnd : sqND (sx :: l) = sx.n * sx.e + sqND l := by simp only [sqND, List.map_cons, List.sum_cons]
    have e : (sqSk (sx :: l)).map (fun k : CSk => (k.R.n : ℝ≥0∞) * k.ε)
        = ((sx.n : ℝ≥0∞) * (((sx.e * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig))
          :: (sqSk l).map (fun k : CSk => (k.R.n : ℝ≥0∞) * k.ε) := rfl
    rw [e, List.sum_cons, ih, hnd, ← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul, ← Nat.cast_add]
    congr 2
    ring

end Skel

section SqPos

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- The schedule's skeleton at any log is `sqSk`. -/
theorem sqAt_sk (U : K) (sxs : List (SqX K L)) {β : Type} (A : OC (QB L) Dig β) (P : List (QB L × Dig)) :
    (sqAt U sxs A P).map CSub.sk = sqSk sxs := by
  unfold sqAt sqSk
  exact List.map_map.trans rfl

/-- **`fs_sq_knowledge` with the per-position count** (D63 lane L21, finding L20-5): for squeeze-run sub-protocols on
the chain of ANY list of verifier operations, the probability that some sub-protocol enters its window with a false
claim and yet every one's squeeze run is in place with its state holding at its drawn challenges is at most
`(q·emax + Σ n·e)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`: the verifier's own
positions are charged only the rounds they start. -/
theorem fs_sq_knowledge_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (sxs : List (SqX K L)) (emax : ℕ)
    (hR : ∀ sx ∈ sxs, sx.Rbr) (he : ∀ sx ∈ sxs, sx.e ≤ emax)
    {α : Type} (ops : α → List Op) (ℓ s : ℕ) (hwin : ∀ sx ∈ sxs, s < sx.a)
    (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q)
    (hstab : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ sx ∈ sxs, ∀ ext : List (TItem × Dig),
        sx.St (proverLog A P) (τ.map entB ++ ext) = sx.St (proverLog A P') (τ.map entB ++ ext)) :
    prH (fun G : QB L → Dig => (∀ op ∈ ops (A.run G), op.len ≤ L) ∧ (ops (A.run G)).length ≤ ℓ
        ∧ (∃ sx ∈ sxs, sx.a ≤ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).length
            ∧ ¬ sx.St (A.runLog G).2
              ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).take sx.a) [])
        ∧ ∀ sx ∈ sxs, ∃ (ks : List UInt64) (ds : List Dig) (rest : List (TItem × Dig)), ks.length = sx.n
            ∧ ds.length = sx.n
            ∧ (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).drop sx.a
              = (ks.map TItem.squeeze).zip ds ++ rest
            ∧ sx.St (A.runLog G).2
              ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (ops (A.run G))).take sx.a)
              (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))))
      ≤ (((q * emax + sqND sxs) : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig := by
  have : Nonempty K := ⟨0⟩
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  let A' : OC (QB L) Dig (List (ItB L)) := A.bind (fun o => .ret (liftItems L (opItems 0 (ops o))))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (liftItems L (opItems 0 (ops o))) : OC (QB L) Dig (List (ItB L))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = liftItems L (opItems 0 (ops (A.run G))) := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hlog : ∀ G, (A'.runLog G).2 = (A.runLog G).2 := fun G => by
    simp only [A']
    rw [OC.runLog_bind]
    simp [OC.runLog]
  have hRw : ∀ P, ∀ c ∈ sqAt U sxs A P, RbrWide c.R.n c.R.w c.St c.ε := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact sqSub_rbr U hbij sx (hR sx hsx) _
  have hε : ∀ P, ∀ c ∈ sqAt U sxs A P, c.ε ≤ ((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ (he sx hsx))) _
  have hframe : ∀ (P : List (QB L × Dig)) (k : ℕ) (c : CSub Dig) (τ : List (TItem × Dig)) (h : TItem)
      (ks : List UInt64) (ds : List Dig), (sqAt U sxs A P)[k]? = some c → tRem W1 τ = some 0 →
      ks.length + 1 = tWd W1 h → ds.length = ks.length + 1 → ¬ subSt W1 c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (sqAt U sxs A P)[k']? = some c' ∧ ¬ subSt W1 c' τ := by
    intro P k c τ h ks ds hc _ _ _ _ hrel
    rw [sqAt, List.getElem?_map] at hc
    obtain ⟨sx, -, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact absurd hrel id
  have hwin' : ∀ P, ∀ c ∈ sqAt U sxs A P, s < c.a := by
    intro P c hc
    rw [sqAt] at hc
    obtain ⟨sx, hsx, rfl⟩ := List.mem_map.mp hc
    exact hwin sx hsx
  have hstab' : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ ext : List (TItem × Dig),
        allSt W1 (sqAt U sxs A P) (τ.map (toTE (fun it : ItB L => it.1)) ++ ext)
          ↔ allSt W1 (sqAt U sxs A P') (τ.map (toTE (fun it : ItB L => it.1)) ++ ext) := by
    intro G P P' τ qs hc hl hq hpre hans ext
    rw [sqAt, sqAt]
    refine allSt_sq_congr U W1 sxs _ _ _ (fun sx hsx => ?_)
    have hlt := hwin sx hsx
    have hτl : (τ.map (toTE (fun it : ItB L => it.1))).length = s := by rw [List.length_map, hl]
    have e : (τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take sx.a
        = τ.map (toTE (fun it : ItB L => it.1)) ++ ext.take (sx.a - s) := by
      rw [List.take_append, List.take_of_length_le (by omega), hτl]
    rw [e]
    exact hstab G P P' τ qs hc hl hq hpre hans sx hsx _
  have hmain := fs_code_chain_sound_sched_log_pos W1 (fun _ => Nat.one_pos) (sqAt U sxs A) (sqSk sxs)
    (fun P => sqAt_sk U sxs A P) _ hRw hε hframe
    (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) (stepsOne_ok _)
    (fun l => l.take ℓ) ℓ
    (fun l => by
      show ((l.take ℓ).flatMap (stepsOne (ItB L)).items).length ≤ ℓ
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) s hwin'
    (fun o => by
      show (((o.take ℓ).take s).flatMap (stepsOne (ItB L)).items).length ≤ s
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) hstab' q A' hA'
  rw [sqSk_charge] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) (hmain.trans ?_)
  · intro G hG
    rw [Set.mem_ofPred_eq] at hG ⊢
    obtain ⟨hfit, hlen, h1, h2⟩ := hG
    have hfull : proverLog A (((chainEncB key domain hs L hL).stepRun (stepsOne (ItB L))
        (fun l => l.take ℓ) A').runLog G).2 = (A.runLog G).2 := by
      rw [ChainEnc.stepRun, OC.runLog_bind, hlog]
      exact proverLog_runLog A G _
    rw [sqAt, hfull]
    exact sq_event U sxs (A.runLog G).2 _ _
      (by rw [hrun G]; exact cChain_trace key domain hs hL hL64 (ops (A.run G)) G hfit ℓ hlen) h1 h2
  · refine add_le_add (add_le_add ?_ le_rfl) le_rfl
    have harith : (q : ℝ≥0∞) * (((emax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
        + ((sqND sxs * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
        = (((q * emax + sqND sxs) * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
      rw [← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul, ← Nat.cast_add]
      congr 2
      ring
    rw [harith]
    exact dig_bound_le gP hF _

end SqPos

end ZK60.Exec

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The define draws and LogUp, per position -/

section Defines

/-- **The define draws' rounds weighted by their escape counts**: `Σ_{k ∈ ks} draws_k·dg_k`. -/
def defND (P : BlockParams) (ks : List ℕ) (dg : ℕ → ℕ) : ℕ := (ks.map (fun k => P.draws k * dg k)).sum

/-- `Σ_{k ∈ ks} draws_k·dg_k ≤ dmax·Σ_{k < n} draws_k` for distinct slots below `n` with `dg ≤ dmax`. -/
theorem defND_le (P : BlockParams) (ks : List ℕ) (dg : ℕ → ℕ) (dmax n : ℕ) (hdg : ∀ k ∈ ks, dg k ≤ dmax)
    (hnd : ks.Nodup) (hks : ∀ k ∈ ks, k < n) : defND P ks dg ≤ dmax * ∑ k ∈ Finset.range n, P.draws k := by
  calc defND P ks dg = ∑ k ∈ ks.toFinset, P.draws k * dg k := by
        rw [defND, List.sum_toFinset _ hnd]
    _ ≤ ∑ k ∈ ks.toFinset, P.draws k * dmax :=
        Finset.sum_le_sum (fun k hk => Nat.mul_le_mul_left _ (hdg k (List.mem_toFinset.mp hk)))
    _ ≤ ∑ k ∈ Finset.range n, P.draws k * dmax :=
        Finset.sum_le_sum_of_subset (fun k hk => Finset.mem_range.mpr (hks k (List.mem_toFinset.mp hk)))
    _ = dmax * ∑ k ∈ Finset.range n, P.draws k := by
        rw [Finset.mul_sum]
        exact Finset.sum_congr rfl (fun k _ => Nat.mul_comm _ _)

/-- **The W16R2 rung's define draws**: `351` in all (L9's count). -/
theorem rung_draws_sum : ∑ k ∈ Finset.range 23, W16R2.rungDraws k = 351 := by decide

/-- **At the W16R2 rung** any distinct slots' draws weigh at most `351·dmax`. -/
theorem rung_defND_le (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (ks : List ℕ) (dg : ℕ → ℕ) (dmax : ℕ)
    (hdg : ∀ k ∈ ks, dg k ≤ dmax) (hnd : ks.Nodup) (hks : ∀ k ∈ ks, k < 23) : defND P ks dg ≤ dmax * 351 := by
  have h := defND_le P ks dg dmax 23 hdg hnd hks
  rw [hdr, rung_draws_sum] at h
  exact h

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

omit [Algebra GF K] in
theorem sqND_defSq (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (ks : List ℕ) :
    sqND (ks.map (defSq P hdrLen absOf Φ dg)) = defND P ks dg := by
  unfold sqND defND
  exact congrArg List.sum (List.map_map.trans rfl)

/-- **The slots' draws under Fiat–Shamir, knowledge version, per position** (D63 lane L21; L20-5). As
`block_defines_fs_knowledge`, with the bound `(q·dmax + Σ_{k ∈ ks} draws_k·dg_k)/|K|·(1 + p/2^128)² + collBound T +
collBound (T + 1)`, `T = q + defLen + 1`. -/
theorem block_defines_fs_knowledge_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (ks : List ℕ) (hks : ∀ k ∈ ks, k < P.geom.slots.length) (Gd : Cuts3 L → RootsO → ℕ → Hist → Prop)
    (Φ : Cuts3 L → RootsO → (k : ℕ) → Hist → (Fin (P.draws k) → K) → K) (dg : ℕ → ℕ) (dmax : ℕ)
    (hdg : ∀ k ∈ ks, dg k ≤ dmax) (hdeg : ∀ k ∈ ks, ∀ cu rt h, IndDegLE (dg k) (Φ cu rt k h))
    (hΦ : ∀ cu rt k h, k ∈ ks → (∀ x, Φ cu rt k h x = 0) → Gd cu rt k h)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => DefWin U key domain P hdrLen ks Gd Φ (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2) G (A.run G))
      ≤ (((q * dmax + defND P ks dg) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig := by
  have hmain := fs_sq_knowledge_pos U hU hK2 key domain hs hL hL64
    (ks.map (defSq P hdrLen (absOfC (chainEncB key domain hs L hL)) Φ dg)) dmax
    (fun sx hsx => by
      obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
      exact defSq_rbr P hdrLen _ Φ dg k (hdeg k hk))
    (fun sx hsx => by
      obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hsx
      exact hdg k hk)
    (allOps P) (defLen P hdrLen) (hdrLen + 8)
    (fun sx hsx => by
      obtain ⟨k, -, rfl⟩ := List.mem_map.mp hsx
      show hdrLen + 8 < hdrLen + 10 + defOff P 0 k
      omega)
    q A hA (defSq_stab key domain hs hL P hdrLen ks Φ dg A)
  rw [sqND_defSq] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact defWin_event U key domain hs hL hL81 P hdrLen ks hks Gd Φ dg hΦ hgeom hgt G (A.runLog G).2 (A.run G) hG

/-- **`hRel` (or any event) from define schedules, per position** (D63 lane L21). For ANY block shape and ANY event
`Ev` whose every outcome is a win against one of `nd` define schedules (`hcover`), each with escape counts `≤ dmax`
and `Σ draws·dg ≤ ND`, the probability of `Ev` is at most
`nd·((q·dmax + ND)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1))`, `T = q + defLen + 1`. -/
theorem rel_of_defines_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (nd : ℕ) (D : ℕ → DefSched K L P) (dmax ND : ℕ)
    (hks : ∀ i, i < nd → ∀ k ∈ (D i).ks, k < P.geom.slots.length)
    (hdg : ∀ i, i < nd → ∀ k ∈ (D i).ks, (D i).dg k ≤ dmax)
    (hdeg : ∀ i, i < nd → ∀ k ∈ (D i).ks, ∀ cu rt h, IndDegLE ((D i).dg k) ((D i).Φ cu rt k h))
    (hΦ : ∀ i, i < nd → ∀ cu rt k h, k ∈ (D i).ks → (∀ x, (D i).Φ cu rt k h x = 0) → (D i).Gd cu rt k h)
    (hND : ∀ i, i < nd → defND P (D i).ks (D i).dg ≤ ND)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Ev : (QB L → Dig) → Prop)
    (hcover : ∀ G, Ev G → ∃ i, i < nd ∧ DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G)) :
    prH Ev ≤ (nd : ℝ≥0∞) * ((((q * dmax + ND) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig) := by
  have hu := run_blocks_union nd (fun i G => DefWin U key domain P hdrLen (D i).ks (D i).Gd (D i).Φ
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    (fun _ => (((q * dmax + ND) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + defLen P hdrLen + 1) Dig + collBound (q + defLen P hdrLen + 1 + 1) Dig)
    (fun i hi => (block_defines_fs_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen (D i).ks (hks i hi)
      (D i).Gd (D i).Φ (D i).dg dmax (hdg i hi) (hdeg i hi) (hΦ i hi) hgeom hgt q A hA).trans
      (add_le_add (add_le_add (mul_le_mul' (ENNReal.div_le_div_right
        (Nat.cast_le.mpr (Nat.add_le_add_left (hND i hi) _)) _) le_rfl) le_rfl) le_rfl))
  simp only [Finset.sum_const, Finset.card_range, nsmul_eq_mul] at hu
  refine le_trans (MeasureTheory.measure_mono ?_) hu
  intro G hG
  exact hcover G hG

end Defines

section LogUp

variable {K : Type} [Field K] [Algebra GF K] [DecidableEq K] {L : ℕ}
variable {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]

/-- **LogUp under Fiat–Shamir, knowledge version, per position** (D63 lane L21; L20-5): as
`block_logup_fs_knowledge`, with the bound `(q·e + 3·e)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`,
`e = N + 2M`, `T = q + (hdrLen + 10) + 1`: the verifier's three squeezes are charged once each. -/
theorem block_logup_fs_knowledge_pos [Fintype K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G))
      ≤ (((q * (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card)
            + 3 * (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card)) : ℕ) : ℝ≥0∞)
          / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (hdrLen + 10) + 1) Dig + collBound (q + (hdrLen + 10) + 1 + 1) Dig := by
  have hnd : sqND [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk]
      = 3 * (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card) := rfl
  have hmain := fs_sq_knowledge_pos U hU hK2 key domain hs hL hL64
    [lkSq hdrLen (absOfC (chainEncB key domain hs L hL)) Alk T mlk]
    (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      exact lkSq_rbr hdrLen _ Alk T mlk hN)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      exact le_rfl)
    (lkOps P) (hdrLen + 10) (hdrLen + 1)
    (fun sx hsx => by
      rw [List.mem_singleton] at hsx
      subst hsx
      show hdrLen + 1 < hdrLen + 4
      omega)
    q A hA (lkSq_stab key domain hs hL hdrLen Alk T mlk A)
  rw [hnd] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact lkWin_event U key domain hs hL hL81 P hdrLen Alk T mlk A G hG

/-- **`hLk` (or any event) from LogUp, per position** (D63 lane L21). For ANY event `Ev` whose every outcome either
lies in the helpers' event `EvH` (the zero-checks' helper clauses and `H`'s sum row failing on the extracted helpers,
bounded by `εhelp`, e.g. by `rel_of_defines_pos`) or is a win against LogUp (`hsplit`: an extracted looked-up tuple
outside the table while some helpers pass every relation at the transcript's `β, γ, α`), the probability of `Ev` is at
most `εhelp + (q·e + 3·e)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`. -/
theorem lk_of_logup_pos [Fintype K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (Ev EvH : (QB L → Dig) → Prop) (εhelp : ℝ≥0∞)
    (hHelp : prH EvH ≤ εhelp)
    (hsplit : ∀ G, Ev G → EvH G ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G)) :
    prH Ev ≤ εhelp + ((((q * (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card)
            + 3 * (Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card)) : ℕ) : ℝ≥0∞)
          / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + (hdrLen + 10) + 1) Dig + collBound (q + (hdrLen + 10) + 1 + 1) Dig) := by
  refine le_trans (MeasureTheory.measure_mono ?_) ((MeasureTheory.measure_union_le _ _).trans
    (add_le_add hHelp (block_logup_fs_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN q A hA)))
  intro G hG
  exact hsplit G hG

end LogUp

/-! ## The numbers, in L20's units `(q + 1)·c/2^126` -/

section Numbers

/-- **One define schedule (or the slots), per position**: `(q·d + ND)/p²·(1 + p/2^128)² + collBound T +
collBound (T + 1) ≤ (q + 1)·(d + ND + 2^15)/2^126` for a chain of at most `2^20` items and `q < 2^100`. -/
theorem sched_pos_le_u126 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q : ℕ) (hq : q < 2 ^ 100)
    (ℓ : ℕ) (hℓ : ℓ ≤ 2 ^ 20) (d ND : ℕ) :
    ((q * d + ND : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ u126 q (d + ND + 2 ^ 14 + 2 ^ 14) := by
  calc _ ≤ u126 q (d + ND) + u126 q (2 ^ 14) + u126 q (2 ^ 14) :=
        add_le_add (add_le_add (slots_le_u126 p hp1 hp2 q d ND) (coll_le_u126 q _ hq (by omega)))
          (coll_le_u126 q _ hq (by omega))
    _ = _ := by rw [u126_add, u126_add]

theorem nsmul_u126 (q nd c : ℕ) : (nd : ℝ≥0∞) * u126 q c = u126 q (nd * c) := by
  unfold u126
  rw [← mul_div_assoc, ← Nat.cast_mul]
  congr 2
  ring

/-- **LogUp's first term, per position**, at the 8B T128 W16R2 figures (`e = N + 2M ≤ 35,153,256`):
`(q·e + 3·e)/p²·(1 + p/2^128)² ≤ (q + 1)·26,370,000/2^126` (about `3e/4`: at `q = 0` the verifier's three squeezes,
for larger `q` the prover's queries at LogUp's rate `e/p² ≈ 2^-102.9`). -/
theorem lk_main_le_u126 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q e : ℕ) (he : e ≤ 35153256) :
    ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q 26370000 := by
  have hp0 : p ≠ 0 := by omega
  rw [bias_frac, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
  unfold u126
  refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
  have h1 : q * e + 3 * e ≤ 3 * (q + 1) * 35153256 := by
    calc q * e + 3 * e = (q + 3) * e := by ring
      _ ≤ (q + 3) * 35153256 := Nat.mul_le_mul_left _ he
      _ ≤ 3 * (q + 1) * 35153256 := Nat.mul_le_mul_right _ (by omega)
  calc (q * e + 3 * e) * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 126
      ≤ (3 * (q + 1) * 35153256) * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126 := by gcongr
    _ = (q + 1) * (3 * 35153256 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126) := by ring
    _ ≤ (q + 1) * (26370000 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
    _ ≤ (q + 1) * (26370000 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
    _ = (q + 1) * 26370000 * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring

/-- **LogUp's whole term, per position**: at most `(q + 1)·(26,370,000 + 2^15)/2^126` for `e ≤ 35,153,256`, a chain
of at most `2^20` items and `q < 2^100`. -/
theorem lk_pos_le_u126 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q : ℕ) (hq : q < 2 ^ 100)
    (ℓ : ℕ) (hℓ : ℓ ≤ 2 ^ 20) (e : ℕ) (he : e ≤ 35153256) :
    ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ u126 q (26370000 + 2 ^ 14 + 2 ^ 14) := by
  calc _ ≤ u126 q 26370000 + u126 q (2 ^ 14) + u126 q (2 ^ 14) :=
        add_le_add (add_le_add (lk_main_le_u126 p hp1 hp2 q e he) (coll_le_u126 q _ hq (by omega)))
          (coll_le_u126 q _ hq (by omega))
    _ = _ := by rw [u126_add, u126_add]

/-- **W16R2's relations and LogUp within L20's budget** (`dmax + ND + crel + clk ≤ 2^25`): the slots `5 + 924`, two
define schedules for `hRel` (escape counts `≤ 80`, `Σ draws·dg ≤ 80·351`), and LogUp with two such schedules for the
helpers: `26,647,409 ≤ 33,554,432`. -/
theorem w16r2_rel_lk_budget :
    5 + 924 + 2 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14)
      + (2 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 25 := by norm_num

/-- **W16R2's whole block within `2^26`** (`block_knowledge_target_mt`'s `hbud` at `M ≤ 2^-106`, `opA ≤ 2^-111`,
`opB ≤ 2^-113`): `30,202,737 ≤ 67,108,864`. -/
theorem w16r2_budget_mt :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5 + 924
      + 2 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14)
      + (2 * (80 + 80 * 351 + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by norm_num

end Numbers

/-! ## The block's knowledge statement on acceptance, `OpenTrue` form, and the target -/

section Target

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One block's knowledge statement on the block verifier's acceptance, `OpenTrue` form** (D63 lane L21; L20's
`block_knowledge_acc` with findings L21-1 … L21-3). For any block shape: `hOpen` covers everything the openings and `M`
check (`OpenTrue`: the claims, `H`'s LogUp sum claim, and every functional `M` receives, `acc.fs ++ acc.hostFs`),
`hRel`'s event requires `OpenTrue`, and `hLk`'s also the true claimed sums and the slot relations, all on
`BlockAcc`. The bound is `block_knowledge_acc`'s. -/
theorem block_knowledge_acc_mt [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) (εopen εrel εlk : ℝ≥0∞)
    (hOpen : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εopen)
    (hRel : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) ≤ εrel)
    (hLk : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams) ≤ εlk) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εopen + ((((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig) + εrel + εlk := by
  have hsc := block_terminal_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval dmax
    hdp hgeom hgt q A hA
  refine le_trans (MeasureTheory.measure_mono ?_)
    ((MeasureTheory.measure_union_le _ _).trans (add_le_add
      ((MeasureTheory.measure_union_le _ _).trans (add_le_add
        ((MeasureTheory.measure_union_le _ _).trans (add_le_add hOpen hsc)) hRel)) hLk))
  intro G hG
  rw [Set.mem_ofPred_eq] at hG
  obtain ⟨bga, rs, acc, hacc, hns⟩ := hG
  by_cases ho : OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
  · by_cases hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U
        = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k))
    · by_cases hrel : ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      · by_cases hlk : ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams
        · exact absurd (ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hrel hlk) hns
        · exact Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel, hlk⟩
      · exact Or.inl (Or.inr ⟨bga, rs, acc, hacc, ho, hcl, hrel⟩)
    · push Not at hcl
      obtain ⟨k, r, hr, hne⟩ := hcl
      exact Or.inl (Or.inl (Or.inr ⟨bga, rs, acc, hacc.1, ho.1, ho.mfs, k, r, hr, hdeg _ _ _ _, hne⟩))
  · exact Or.inl (Or.inl (Or.inl ⟨bga, rs, acc, hacc, ho⟩))

/-- **One block's knowledge error is at most the approved target, for EVERY `q`, with `hRel` and `hLk` composed per
position** (D63 lane L21; L20's `block_knowledge_target` in the `OpenTrue` form, its `hRel` and `hLk` discharged). For
any block shape whose slots have degree `≤ 7`, with chains of at most `2^20` items: the openings' and `M`'s chain
bounds and links as L20's (`hsem` now for `OpenTrue`); `hRel`'s event covered by two define schedules `DR` (`hcoverR`:
the instance's algebra, unmasking with `M`'s functionals and reindexing to `W16Rels`); `hLk`'s event split
(`hsplit`) into the helpers' event `EvHlp`, covered by two define schedules `DH`, and a win against LogUp; every
schedule with escape counts `≤ dd` and `Σ draws·dg ≤ NDd`; LogUp's `N + 2M ≤ 35,153,256`; and the budget `hbud` (at
W16R2: `w16r2_budget_mt`). Then the block verifier accepts while the extracted planes do not satisfy `BlockSat` with
probability at most `εsTarget q = q·2^-100 + 2^-100`. -/
theorem block_knowledge_target_mt [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn)) (dmax : ℕ) (hd7 : dmax ≤ 7)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hℓs : blockLen P.draws P.geom.slots hdrLen ≤ 2 ^ 20) (hℓd : defLen P hdrLen ≤ 2 ^ 20)
    (hℓk : hdrLen + 10 ≤ 2 ^ 20)
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    -- the openings: their good predicates, chain events and per-position bounds (L20)
    (GA GH GM EvA EvH EvM EvX : (QB L → Dig) → Prop) (ℓo : ℕ) (hℓo : ℓo ≤ 2 ^ 20)
    (jM jA jB : ℕ) (hjM : jM ≤ 126) (hjA : jA ≤ 126) (hjB : jB ≤ 126)
    (maskE εAa εBa εAh εBh : ℝ≥0∞) (hmE : maskE ≤ (2⁻¹ : ℝ≥0∞) ^ jM)
    (hAa : εAa ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBa : εBa ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
    (hAh : εAh ≤ (2⁻¹ : ℝ≥0∞) ^ jA) (hBh : εBh ≤ (2⁻¹ : ℝ≥0∞) ^ jB)
    (hM : prH EvM ≤ (q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
    (hEA : prH EvA ≤ ((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
    (hEH : prH EvH ≤ ((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
    (T' nr : ℕ) (hT' : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 3)
    (hX : prH EvX ≤ collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig)
    (hsem : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) → ¬ (GA G ∧ GH G ∧ GM G))
    (hexec : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc) → ¬ EvX G →
      (GA G ∨ EvA G) ∧ (GH G ∨ EvH G) ∧ (GM G ∨ EvM G))
    -- L13's relations: two define schedules
    (dd NDd : ℕ) (DR DH : ℕ → DefSched K L P)
    (hksR : ∀ i, i < 2 → ∀ k ∈ (DR i).ks, k < P.geom.slots.length)
    (hdgR : ∀ i, i < 2 → ∀ k ∈ (DR i).ks, (DR i).dg k ≤ dd)
    (hdegR : ∀ i, i < 2 → ∀ k ∈ (DR i).ks, ∀ cu rt h, IndDegLE ((DR i).dg k) ((DR i).Φ cu rt k h))
    (hΦR : ∀ i, i < 2 → ∀ cu rt k h, k ∈ (DR i).ks → (∀ x, (DR i).Φ cu rt k h x = 0) → (DR i).Gd cu rt k h)
    (hNDR : ∀ i, i < 2 → defND P (DR i).ks (DR i).dg ≤ NDd)
    (hcoverR : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ¬ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
      → ∃ i, i < 2 ∧ DefWin U key domain P hdrLen (DR i).ks (DR i).Gd (DR i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    -- LogUp, with the helpers' relations by two define schedules
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hksH : ∀ i, i < 2 → ∀ k ∈ (DH i).ks, k < P.geom.slots.length)
    (hdgH : ∀ i, i < 2 → ∀ k ∈ (DH i).ks, (DH i).dg k ≤ dd)
    (hdegH : ∀ i, i < 2 → ∀ k ∈ (DH i).ks, ∀ cu rt h, IndDegLE ((DH i).dg k) ((DH i).Φ cu rt k h))
    (hΦH : ∀ i, i < 2 → ∀ cu rt k h, k ∈ (DH i).ks → (∀ x, (DH i).Φ cu rt k h x = 0) → (DH i).Gd cu rt k h)
    (hNDH : ∀ i, i < 2 → defND P (DH i).ks (DH i).dg ≤ NDd)
    (EvHlp : (QB L → Dig) → Prop)
    (hcoverH : ∀ G, EvHlp G → ∃ i, i < 2 ∧ DefWin U key domain P hdrLen (DH i).ks (DH i).Gd (DH i).Φ
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) G (A.run G))
    (hsplit : ∀ G, (∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc
      ∧ (∀ k r, rs[k]? = some r → r.claimed.toK U
          = cubeSum (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k (seenOf bga rs k)))
      ∧ ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      ∧ ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams)
      → EvHlp G ∨ LkWin U key domain P hdrLen Alk T mlk (cutsOf key domain hs hL A G).1 G (A.run G))
    -- the budget
    (hbud : 3 * 2 ^ (126 - jM) + 2 * (2 ^ (126 - jA) + 2 ^ (126 - jB)) + 2 ^ 18 + 2 ^ 16 + dmax + blockND P.geom.slots
      + 2 * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (2 * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q := by
  by_cases hq : q < 2 ^ 100
  · have hF2 : Fintype.card K = gP ^ 2 :=
      card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
    have hdp : dmax < gP := lt_of_le_of_lt hd7 (by norm_num [gP])
    have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
    have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
    have hgeomD : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
        ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
      fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
    -- `hRel`: two define schedules, per position
    have hR := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt 2 DR dd NDd hksR hdgR hdegR
      hΦR hNDR q A hA _ hcoverR
    rw [hF2] at hR
    have hRu := hR.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q 2 _))
    -- the helpers: two define schedules, per position
    have hH := rel_of_defines_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen hgeomD hgt 2 DH dd NDd hksH hdgH hdegH
      hΦH hNDH q A hA EvHlp hcoverH
    rw [hF2] at hH
    have hHu := hH.trans ((mul_le_mul' le_rfl
      (sched_pos_le_u126 gP hp1 hp2 q hq (defLen P hdrLen) hℓd dd NDd)).trans_eq (nsmul_u126 q 2 _))
    -- `hLk`: LogUp, per position
    have hLk := lk_of_logup_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen Alk T mlk hN q A hA _ EvHlp _ hHu hsplit
    rw [hF2] at hLk
    have hLu := hLk.trans ((add_le_add le_rfl
      (lk_pos_le_u126 gP hp1 hp2 q hq (hdrLen + 10) hℓk _ he)).trans_eq (u126_add _ _ _))
    -- the openings' term
    have hOpen := block_open_knowledge
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc)
      (fun G => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc)
      GA GH GM EvA EvH EvM EvX _ _ _ _
      (fun G _ ha hh hm hb => hsem G hb ⟨ha, hh, hm⟩) hexec hM hEA hEH hX
    have hOpen' : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ ¬ OpenTrue U P (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc)
        ≤ ((q : ℝ≥0∞) * maskE + 3 * maskE + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
          + (((q : ℝ≥0∞) * εAa + εAa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
            + ((q : ℝ≥0∞) * εBa + εBa + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
          + (((q : ℝ≥0∞) * εAh + εAh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig)
            + ((q : ℝ≥0∞) * εBh + εBh + collBound (q + ℓo + 1) Dig + collBound (q + ℓo + 1 + 1) Dig))
          + (collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig) := by
      refine le_trans (MeasureTheory.measure_mono ?_) hOpen
      intro G hG
      rw [Set.mem_ofPred_eq] at hG ⊢
      obtain ⟨bga, rs, acc, hacc, hbad⟩ := hG
      exact ⟨⟨bga, rs, acc, hacc⟩, ⟨bga, rs, acc, hacc, hbad⟩⟩
    refine (block_knowledge_acc_mt U hU hK2 key domain hs hL hL64 hL81 P hdrLen F csX msX hpolyC hEval hdeg dmax hdp
      hgeom hgt Pb Lay B fams hF hW h24 xtE q A hA _ _ _ hOpen' hRu hLu).trans ?_
    rw [hF2]
    exact block_total_le_target gP hp1 hp2 q hq _ ℓo hℓs hℓo dmax (blockND P.geom.slots) jM jA jB hjM hjA hjB
      maskE εAa εBa εAh εBh hmE hAa hBa hAh hBh T' nr hT' hnr _ _ (2 * (dd + NDd + 2 ^ 14 + 2 ^ 14))
      (2 * (dd + NDd + 2 ^ 14 + 2 ^ 14) + (26370000 + 2 ^ 14 + 2 ^ 14)) le_rfl le_rfl hbud
  · refine le_trans ?_ (one_le_εsTarget (not_lt.mp hq))
    calc _ ≤ (PMF.uniformOfFintype (QB L → Dig)).toOuterMeasure Set.univ :=
          MeasureTheory.measure_mono (Set.subset_univ _)
      _ = 1 := (PMF.toOuterMeasure_apply_eq_one_iff _ Set.univ).mpr (Set.subset_univ _)

end Target

end ZK60.Exec.Block
