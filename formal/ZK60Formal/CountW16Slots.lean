/-
D63 lane L20 (2026-11-07), part 2: **the block's slots, knowledge version, with the per-position count** (L16-1's
fix for the slots' part).

L16's `exec_sumchecks_fs_knowledge` / `block_sumchecks_fs_knowledge` (`ExtractW16Slots.lean`) bound the slots' win by
`(q + ℓ + 1)·dmax/|K|·(1 + p/2^128)² + collisions`: every verifier position is charged the largest degree. With
`CountW16Chain.lean`'s per-position composition each of the verifier's own positions is charged only the round it
starts: the bound becomes `(q·dmax + Σ_k n_k·d_k)/|K|·(1 + p/2^128)² + collisions`, where `Σ_k n_k·d_k` (`slotsND`,
`blockND`) is the slots' rounds weighted by their degrees: `924` at the W16R2 rung, against L16's `(hdrLen + 1045)·5`.

* `slotsND`, `slotSubs_sk_at`, `slotSubs_charge`, `sum_n_div`: the slots' skeleton is the same at every log; its
  charge is `slotsND·fibC/|Dig|`;
* **`exec_sumchecks_fs_knowledge_pos`**: L16's `exec_sumchecks_fs_knowledge` with the per-position count;
* `blockND`, `slotsND_blockSchedX`, **`block_sumchecks_fs_knowledge_pos`**: the block's slots, any shape;
* **`block_terminal_knowledge_pos`**: L16's `block_terminal_knowledge` (the slots' win with the claims and `M`
  functionals true of the extracted data) with the per-position count;
* `W16R2.rung_nd`: `blockND rungSlots = 924`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CountW16Chain
import ZK60Formal.ExtractW16Block

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The slots' skeleton and its charge -/

section Skeleton

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The slots' rounds weighted by their degrees**: `Σ_k n_k·d_k`. -/
def slotsND (slots : List (SlotX K L)) : ℕ := (slots.map (fun sl => sl.n * sl.d)).sum

/-- **The slots' skeleton does not depend on the log** (the windows, rounds and errors are the schedule's). -/
theorem slotSubs_sk_at (U : K) (slots : List (SlotX K L)) (Lg Lg' : List (QB L × Dig)) :
    (slotSubs U (slotsAt slots Lg)).map CSub.sk = (slotSubs U (slotsAt slots Lg')).map CSub.sk := by
  apply List.ext_getElem?
  intro k
  simp only [List.getElem?_map, slotSubs_getElem?, slotsLen_take_at]
  simp only [slotsAt, List.getElem?_map, Option.map_map]
  rfl

/-- The charges of the slots: per slot `n·(d·fibC/|Dig|)`. -/
theorem slotSubs_charge_list (U : K) (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) :
    ((slotSubs U (slotsAt slots Lg)).map CSub.sk).map (fun k => (k.R.n : ℝ≥0∞) * k.ε)
      = slots.map (fun sl => (sl.n : ℝ≥0∞) * (((sl.d * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)) := by
  apply List.ext_getElem?
  intro k
  simp only [List.getElem?_map, slotSubs_getElem?, slotsLen_take_at]
  simp only [slotsAt, List.getElem?_map, Option.map_map]
  rfl

omit [Field K] [Algebra GF K] in
/-- `Σ_sl n·(d·fibC/|Dig|) = slotsND·fibC/|Dig|`. -/
theorem sum_n_div (l : List (SlotX K L)) :
    (l.map (fun sl => (sl.n : ℝ≥0∞) * (((sl.d * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig))).sum
      = ((slotsND l * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
  induction l with
  | nil => simp only [slotsND, List.map_nil, List.sum_nil, zero_mul, Nat.cast_zero, ENNReal.zero_div]
  | cons sl l ih =>
    have hnd : slotsND (sl :: l) = sl.n * sl.d + slotsND l := by
      simp only [slotsND, List.map_cons, List.sum_cons]
    rw [List.map_cons, List.sum_cons, ih, hnd, ← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul,
      ← Nat.cast_add]
    congr 2
    ring

theorem slotSubs_charge (U : K) (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) :
    (((slotSubs U (slotsAt slots Lg)).map CSub.sk).map (fun k => (k.R.n : ℝ≥0∞) * k.ε)).sum
      = ((slotsND slots * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
  rw [slotSubs_charge_list, sum_n_div]

end Skeleton

/-! ## The run of slots, knowledge version, per position -/

section KnowledgePos

variable {K : Type} [Field K] [Algebra GF K]

/-- **Fiat–Shamir soundness of a run of executable sumcheck slots whose statements read the prover's log, with the
per-position count** (D63 lane L20; L16's `exec_sumchecks_fs_knowledge` with `fs_code_chain_sound_sched_log_pos`).
The probability that SOME slot's claim is false of the polynomial at the prover's own log and yet EVERY slot's
executable `sumcheck::verify` accepts with its terminal check is at most
`(q·dmax + Σ_k n_k·d_k)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`: the verifier's own
positions are charged only the rounds they start. -/
theorem exec_sumchecks_fs_knowledge_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (SlotX K L)) (dmax : ℕ)
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (s : ℕ) (hwin : ∀ k sl, slots[k]? = some sl → s < slotsLenX (slots.take k) + sl.s)
    (q : ℕ) (A : OC (QB L) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q)
    (hstab : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ sl ∈ slots, ∀ ext : List (TItem × Dig),
        sl.stmt (proverLog A P) (τ.map entB ++ ext) = sl.stmt (proverLog A P') (τ.map entB ++ ext)) :
    prH (fun G : QB L → Dig => SlotsWin U key domain L (slotsAt slots (A.runLog G).2) G (A.run G))
      ≤ (((q * dmax + slotsND slots) : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + slotsLenX slots + 1) Dig + collBound (q + slotsLenX slots + 1 + 1) Dig := by
  have : Nonempty K := ⟨0⟩
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  let A' : OC (QB L) Dig (List (ItB L)) := A.bind (fun o => .ret (liftItems L (opItems 0 (slotsOps o))))
  have hA' : A'.Bounded q :=
    (hA.bind (fun o => (show (OC.ret (liftItems L (opItems 0 (slotsOps o))) : OC (QB L) Dig (List (ItB L))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = liftItems L (opItems 0 (slotsOps (A.run G))) := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hlog : ∀ G, (A'.runLog G).2 = (A.runLog G).2 := fun G => by
    simp only [A']
    rw [OC.runLog_bind]
    simp [OC.runLog]
  have hmemAt : ∀ (Lg : List (QB L × Dig)) (sl : Slot K), sl ∈ slotsAt slots Lg → ∃ slx ∈ slots, sl = slx.at Lg := by
    intro Lg sl h
    obtain ⟨slx, hx, rfl⟩ := List.mem_map.mp h
    exact ⟨slx, hx, rfl⟩
  have hR : ∀ P, ∀ c ∈ slotSubs U (slotsAt slots (proverLog A P)), RbrWide c.R.n c.R.w c.St c.ε := by
    intro P c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    rw [slotSubs_getElem?] at hk
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hk
    obtain ⟨slx, hx, rfl⟩ := hmemAt _ sl (List.mem_of_getElem? hsl')
    exact slotSub_rbr U hbij (slx.at _) (hsl slx hx).2.1 _
  have hε : ∀ P, ∀ c ∈ slotSubs U (slotsAt slots (proverLog A P)),
      c.ε ≤ ((dmax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
    intro P c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    rw [slotSubs_getElem?] at hk
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hk
    obtain ⟨slx, hx, rfl⟩ := hmemAt _ sl (List.mem_of_getElem? hsl')
    exact ENNReal.div_le_div_right (Nat.cast_le.mpr (Nat.mul_le_mul_right _ (hsl slx hx).2.2.1)) _
  have hframe : ∀ (P : List (QB L × Dig)) (k : ℕ) (c : CSub Dig) (τ : List (TItem × Dig)) (h : TItem)
      (ks : List UInt64) (ds : List Dig), (slotSubs U (slotsAt slots (proverLog A P)))[k]? = some c →
      tRem W1 τ = some 0 → ks.length + 1 = tWd W1 h → ds.length = ks.length + 1 → ¬ subSt W1 c τ →
      c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ (slotSubs U (slotsAt slots (proverLog A P)))[k']? = some c'
        ∧ ¬ subSt W1 c' τ := by
    intro P k c τ h ks ds hc _ _ _ _ hrel
    rw [slotSubs_getElem?] at hc
    obtain ⟨sl, -, rfl⟩ := Option.map_eq_some_iff.mp hc
    exact absurd hrel id
  have hwin' : ∀ P, ∀ c ∈ slotSubs U (slotsAt slots (proverLog A P)), s < c.a := by
    intro P c hc
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hc
    rw [slotSubs_getElem?] at hk
    obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hk
    rw [slotsAt, List.getElem?_map] at hsl'
    obtain ⟨slx, hx, rfl⟩ := Option.map_eq_some_iff.mp hsl'
    rw [slotSub_a, slotsLen_take_at]
    exact hwin k slx hx
  have hstab' : ∀ (G : QB L → Dig) (P P' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = s → (∀ y ∈ qs, y ∈ P.map Prod.fst) → P <+: P' →
      (∀ e ∈ P', e.2 = G e.1) → ∀ ext : List (TItem × Dig),
        allSt W1 (slotSubs U (slotsAt slots (proverLog A P))) (τ.map (toTE (fun it : ItB L => it.1)) ++ ext)
          ↔ allSt W1 (slotSubs U (slotsAt slots (proverLog A P'))) (τ.map (toTE (fun it : ItB L => it.1)) ++ ext) := by
    intro G P P' τ qs hc hl hq hpre hans ext
    refine allSt_slotsAt_congr U W1 slots _ _ _ (fun k sl hsl => ?_)
    have hlt := hwin k sl hsl
    have hτl : (τ.map (toTE (fun it : ItB L => it.1))).length = s := by rw [List.length_map, hl]
    have e : (τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take (slotsLenX (slots.take k) + sl.s)
        = τ.map (toTE (fun it : ItB L => it.1)) ++ ext.take (slotsLenX (slots.take k) + sl.s - s) := by
      rw [List.take_append, List.take_of_length_le (by omega), hτl]
    rw [e]
    exact hstab G P P' τ qs hc hl hq hpre hans sl (List.mem_of_getElem? hsl) _
  have hmain := fs_code_chain_sound_sched_log_pos W1 (fun _ => Nat.one_pos)
    (csAt U slots A) ((slotSubs U (slotsAt slots [])).map CSub.sk)
    (fun P => slotSubs_sk_at U slots _ []) _ hR hε hframe
    (chainEncB key domain hs L hL) (fun it => it.1) (stepsOne (ItB L)) (stepsOne_ok _)
    (fun l => l.take (slotsLenX slots)) (slotsLenX slots)
    (fun l => by
      show ((l.take (slotsLenX slots)).flatMap (stepsOne (ItB L)).items).length ≤ slotsLenX slots
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) s hwin'
    (fun o => by
      show (((o.take (slotsLenX slots)).take s).flatMap (stepsOne (ItB L)).items).length ≤ s
      rw [flatMap_stepsOne, List.length_take]
      exact min_le_left _ _) hstab' q A' hA'
  rw [slotSubs_charge] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) (hmain.trans ?_)
  · intro G hwinG
    rw [Set.mem_ofPred_eq] at hwinG ⊢
    have hfull : proverLog A (((chainEncB key domain hs L hL).stepRun (stepsOne (ItB L))
        (fun l => l.take (slotsLenX slots)) A').runLog G).2 = (A.runLog G).2 := by
      rw [ChainEnc.stepRun, OC.runLog_bind, hlog]
      exact proverLog_runLog A G _
    rw [csAt, hfull, hrun G]
    exact slotsWin_event U hU key domain hs L hL hL64 (slotsAt slots (A.runLog G).2)
      (fun sl h => by
        obtain ⟨slx, hx, rfl⟩ := hmemAt _ sl h
        exact ⟨(hsl slx hx).1, (hsl slx hx).2.1, (hsl slx hx).2.2.2⟩)
      G (A.run G) _ (by rw [slotsLen_at]) hwinG
  · refine add_le_add (add_le_add ?_ le_rfl) le_rfl
    have harith : (q : ℝ≥0∞) * (((dmax * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig)
        + ((slotsND slots * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
        = (((q * dmax + slotsND slots) * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig := by
      rw [← mul_div_assoc, ENNReal.div_add_div_same, ← Nat.cast_mul, ← Nat.cast_add]
      congr 2
      ring
    rw [harith]
    exact dig_bound_le gP hF _

end KnowledgePos

/-! ## The block's slots, per position -/

namespace Block

section SchedPos

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The block's slot rounds weighted by their degrees**, `Σ_k (n_k + e_k)·d_k`, from the shape. -/
def blockND (slots : List (ℕ × ℕ × ℕ)) : ℕ :=
  ((List.range slots.length).map (fun k => ((slots.getD k (0, 0, 0)).1 + (slots.getD k (0, 0, 0)).2.1)
    * (slots.getD k (0, 0, 0)).2.2)).sum

omit [Algebra GF K] in
theorem slotsND_blockSchedX (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    slotsND (blockSchedX P hdrLen absOf F) = blockND P.geom.slots := by
  simp only [slotsND, blockSchedX, blockND, List.map_map]
  rfl

/-- **Fiat–Shamir soundness of the block's slots, knowledge version, with the per-position count** (D63 lane L20).
L16's `block_sumchecks_fs_knowledge`, for ANY block shape and any slot polynomials over the tables extracted from the
prover's log (cut at the roots' first absorption): at most
`(q·dmax + blockND)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`. -/
theorem block_sumchecks_fs_knowledge_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen
        (fun k sn => F (cuts3 (absOfC (chainEncB key domain hs L hL)) (A.runLog G).2 (rootsOf (A.run G).2))
          (rootsOf (A.run G).2) k sn) G (A.run G))
      ≤ (((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  let A' : OC (QB L) Dig (List (List Op × List (List Fp2))) := A.bind (fun out => .ret (blockOps P out.1 out.2))
  have hA' : A'.Bounded q :=
    (hA.bind (fun out => (show (OC.ret (blockOps P out.1 out.2) : OC (QB L) Dig (List (List Op × List (List Fp2)))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = blockOps P (A.run G).1 (A.run G).2 := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hlog : ∀ G, (A'.runLog G).2 = (A.runLog G).2 := fun G => by
    simp only [A']
    rw [OC.runLog_bind]
    simp [OC.runLog]
  have hsl : ∀ sl ∈ blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F,
      1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [blockSchedX, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, hk, rfl⟩ := hsl
    obtain ⟨h1, h2, h3, -⟩ := hgeom k hk
    exact ⟨h1, lt_of_le_of_lt h2 hdp, h2, h3⟩
  have hwin : ∀ k sl, (blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F)[k]? = some sl →
      hdrLen + 8 < slotsLenX ((blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F).take k) + sl.s := by
    intro k sl h
    have h0 : (blockSlotX (K := K) P hdrLen (absOfC (chainEncB key domain hs L hL)) F 0).s
        = hdrLen + 10 + (P.draws 0 + 3) := by
      simp [blockSlotX]
    simp only [blockSchedX, List.getElem?_map] at h
    obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
    obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
    rw [List.getElem_range] at hget
    subst k'
    rw [List.length_range] at hlt
    rcases Nat.eq_zero_or_pos k with hk0 | hpos
    · subst hk0
      rw [List.take_zero, h0]
      show hdrLen + 8 < 0 + (hdrLen + 10 + (P.draws 0 + 3))
      omega
    · obtain ⟨m, hm⟩ : ∃ m, P.geom.slots.length = m + 1 := ⟨P.geom.slots.length - 1, by omega⟩
      obtain ⟨k'', rfl⟩ : ∃ k'', k = k'' + 1 := ⟨k - 1, by omega⟩
      rw [blockSchedX, hm, List.range_succ_eq_map, List.map_cons, List.take_succ_cons]
      simp only [slotsLenX, List.map_cons, List.sum_cons]
      rw [h0]
      omega
  have hstab : ∀ (G : QB L → Dig) (P1 P1' : List (QB L × Dig)) (τ : List (ItB L × Dig)) (qs : List (QB L)),
      (chainEncB key domain hs L hL).Chain G τ qs → τ.length = hdrLen + 8 → (∀ y ∈ qs, y ∈ P1.map Prod.fst) →
      P1 <+: P1' → (∀ e ∈ P1', e.2 = G e.1) →
      ∀ sl ∈ blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F, ∀ ext : List (TItem × Dig),
        sl.stmt (proverLog A' P1) (τ.map entB ++ ext) = sl.stmt (proverLog A' P1') (τ.map entB ++ ext) := by
    intro G P1 P1' τ qs hc hl hq hpre _ sl hsl ext
    simp only [blockSchedX, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, -, rfl⟩ := hsl
    have hrt : rootsAt hdrLen (τ.map entB ++ ext) = rootsAt hdrLen (τ.map entB) :=
      rootsAt_append hdrLen _ ext (by rw [List.length_map, hl])
    have hcut : cuts3 (absOfC (chainEncB key domain hs L hL)) (proverLog A' P1) (rootsAt hdrLen (τ.map entB))
        = cuts3 (absOfC (chainEncB key domain hs L hL)) (proverLog A' P1') (rootsAt hdrLen (τ.map entB)) := by
      unfold cuts3 rootsAt
      simp only
      rw [cutO_stable _ G τ qs hc P1 P1' hq hpre A' hdrLen, cutO_stable _ G τ qs hc P1 P1' hq hpre A' (hdrLen + 3),
        cutO_stable _ G τ qs hc P1 P1' hq hpre A' (hdrLen + 7)]
    simp only [blockSlotX]
    rw [hrt, hcut]
  have hmain := exec_sumchecks_fs_knowledge_pos U hU hK2 key domain hs L hL hL64
    (blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F) dmax hsl (hdrLen + 8) hwin q A' hA' hstab
  rw [slotsLenX_blockSchedX, slotsND_blockSchedX] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hwinG
  rw [Set.mem_ofPred_eq] at hwinG ⊢
  rw [hlog G, hrun G]
  exact blockWinX_slotsWin U key domain P hdrLen (absOfC (chainEncB key domain hs L hL)) F
    (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G (A.runLog G).2 (A.run G) hwinG

/-- **The block's slots with the claims' and `M`'s truth, per position** (L16's `block_terminal_knowledge` with the
per-position count): for slot polynomials, claim and `M` semantics over the extracted tables, at most
`(q·dmax + blockND)/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`. -/
theorem block_terminal_knowledge_pos [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEval U P (csX cu rt) (msX cu rt) (F cu rt)) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWinT U key domain P hdrLen
        (F (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (msX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) G (A.run G))
      ≤ (((q * dmax + blockND P.geom.slots) : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  refine le_trans (MeasureTheory.measure_mono ?_)
    (block_sumchecks_fs_knowledge_pos U hU hK2 key domain hs hL hL64 hL81 P hdrLen F dmax hdp hgeom hgt q A hA)
  intro G hG
  rw [Set.mem_ofPred_eq] at hG ⊢
  exact blockWinT_blockWin U hU key domain P hdrLen _ _ _ hpolyC (hEval _ _) (fun k hk => (hgeom k hk).1) G (A.run G) hG

end SchedPos

namespace W16R2

/-- **The rung's slot rounds weighted by their degrees**: `Σ_k (n_k + e_k)·d_k = 924` (296 rounds of degree 2 to 5). -/
theorem rung_nd : blockND rungSlots = 924 := by decide

end W16R2

end Block

end ZK60.Exec
