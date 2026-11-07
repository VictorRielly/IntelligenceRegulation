/-
D63 lane L16 (2026-11-07), part 2: **the block's sumcheck slots with polynomials over the EXTRACTED tables**
(finding L10-6 (a) for the slots).

L9's `block_sumchecks_fs_sound` (`ExecBlockFS.lean`) bounds a false claimed sum in any slot of a W16R2 block by `2^-61`,
for slot polynomials `f k` that are functions of what the trace shows (`Seen`). The true slot polynomial is the masked
slot polynomial over the COMMITTED tables (`A`, `H`, `M`), which the trace does not show: under knowledge soundness
they are the tables EXTRACTED from the prover's hash log. This file proves the same bound for polynomials that read the
prover's log, cut at each root's first absorption:

* `SlotX`, `SlotX.at`, `slotsAt`, `slotsLenX`: a slot whose statement reads a log; the run of slots at one log (the
  shapes do not depend on the log);
* `subSt_congr`, `subSt_slotSub_at`, `allSt_slotsAt_congr`: schedules of such slots at two logs agree wherever their
  statements agree;
* **`exec_sumchecks_fs_knowledge`**: L8's `exec_sumchecks_fs_sound` for slots whose statements read the prover's log
  (recovered by replay, `proverLog`), frozen once a chain's first `s` entries are logged: the same bound,
  `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`;
* `absAt`, `rootsAt`, `rootsOf`, `cutO`, `cuts3`, `absOfC`: the block's three roots as the trace shows them (the `A`
  absorb after the header, `M`'s three later, `H`'s seven later), the prover's log cut at each root's first
  absorption, the absorbed bytes a query links; `rootsAt_trace`: on the verifier's trace they are the core's roots;
* `blockSlotX`, `blockSchedX`, `blockWinX_slotsWin`: the block's schedule with each slot's polynomial
  `F (the three cut logs) (the roots) k (what the trace shows)`; L9's `BlockWin` with that polynomial is the slots'
  win;
* **`block_sumchecks_fs_knowledge`**, **`W16R2.rung_block_fs_knowledge`**: L9's bound for ANY slot polynomials over the
  tables extracted from the prover's log cut at the roots' absorption (`FSOpening.lean`'s extraction rule), for the
  extraction the knowledge statement's extractor runs (it reads the prover's own log): at the rung `2^-61`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Chain
import ZK60Formal.ExecBlockFS

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## Slots whose statements read a log -/

/-- **A slot whose statement reads a log** (the prover's, for the extracted tables): its interstitial count, degree and
rounds are the schedule's (independent of the log); its statement is a function of the log and of the code's trace
before its rounds. -/
structure SlotX (K : Type) (L : ℕ) where
  s : ℕ
  d : ℕ
  n : ℕ
  stmt : List (QB L × Dig) → List (TItem × Dig) → ((Fin n → K) → K) × Fp2

section SlotsX

variable {K : Type} {L : ℕ}

/-- The slot at one log: L8's `Slot`. -/
def SlotX.at (sl : SlotX K L) (Lg : List (QB L × Dig)) : Slot K := ⟨sl.s, sl.d, sl.n, sl.stmt Lg⟩

/-- The run of slots at one log. -/
def slotsAt (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) : List (Slot K) := slots.map (fun sl => sl.at Lg)

/-- The run's items (independent of the log). -/
def slotsLenX (slots : List (SlotX K L)) : ℕ := (slots.map (fun sl => sl.s + 2 * sl.n)).sum

theorem slotsLen_at (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) :
    slotsLen (slotsAt slots Lg) = slotsLenX slots := by
  simp only [slotsLen, slotsAt, slotsLenX, List.map_map]
  rfl

theorem slotsAt_take (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) (k : ℕ) :
    (slotsAt slots Lg).take k = slotsAt (slots.take k) Lg := by
  simp [slotsAt, List.map_take]

theorem slotsLen_take_at (slots : List (SlotX K L)) (Lg : List (QB L × Dig)) (k : ℕ) :
    slotsLen ((slotsAt slots Lg).take k) = slotsLenX (slots.take k) := by
  rw [slotsAt_take, slotsLen_at]

end SlotsX

/-! ## Two schedules that agree wherever their statements agree -/

section Congr

/-- Two sub-protocols with the same window, rounds and release, and the same state of the window's header, have the
same state on the chain. -/
theorem subSt_congr {D : Type} (W : UInt64 → ℕ) (c c' : CSub D) (τ : List (TItem × D)) (ha : c.a = c'.a)
    (hR : c.R = c'.R) (hrel : c.rel τ ↔ c'.rel τ) (hS : c.St (τ.take c.a) = c'.St (τ.take c.a)) :
    subSt W c τ ↔ subSt W c' τ := by
  unfold subSt rdAlive
  rw [hS, ha, hR, hrel]

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- A slot at two logs whose statements agree on the window's header has the same state. -/
theorem subSt_slotSub_at (U : K) (W : UInt64 → ℕ) (sl : SlotX K L) (Lg Lg' : List (QB L × Dig)) (a : ℕ)
    (τ : List (TItem × Dig)) (h : sl.stmt Lg (τ.take a) = sl.stmt Lg' (τ.take a)) :
    subSt W (slotSub U (sl.at Lg) a) τ ↔ subSt W (slotSub U (sl.at Lg') a) τ := by
  refine subSt_congr W _ _ τ rfl rfl Iff.rfl ?_
  rw [slotSub_a]
  funext τr
  simp only [slotSub_St, SlotX.at, scSt, h]

/-- **The run of slots at two logs**: the combined states agree wherever every slot's statement agrees on its window's
header. -/
theorem allSt_slotsAt_congr (U : K) (W : UInt64 → ℕ) (slots : List (SlotX K L)) (Lg Lg' : List (QB L × Dig))
    (τ : List (TItem × Dig))
    (h : ∀ (k : ℕ) (sl : SlotX K L), slots[k]? = some sl → sl.stmt Lg (τ.take (slotsLenX (slots.take k) + sl.s))
      = sl.stmt Lg' (τ.take (slotsLenX (slots.take k) + sl.s))) :
    allSt W (slotSubs U (slotsAt slots Lg)) τ ↔ allSt W (slotSubs U (slotsAt slots Lg')) τ := by
  have hget : ∀ Lg₀ k, (slotSubs U (slotsAt slots Lg₀))[k]?
      = slots[k]?.map (fun sl => slotSub U (sl.at Lg₀) (slotsLenX (slots.take k) + sl.s)) := by
    intro Lg₀ k
    rw [slotSubs_getElem?, slotsLen_take_at, slotsAt, List.getElem?_map, Option.map_map]
    rfl
  constructor
  · intro hall k c hc
    rw [hget] at hc
    obtain ⟨sl, hsl, rfl⟩ := Option.map_eq_some_iff.mp hc
    have h1 := hall k _ (by rw [hget, hsl]; rfl)
    exact (subSt_slotSub_at U W sl Lg Lg' _ τ (h k sl hsl)).mp h1
  · intro hall k c hc
    rw [hget] at hc
    obtain ⟨sl, hsl, rfl⟩ := Option.map_eq_some_iff.mp hc
    have h1 := hall k _ (by rw [hget, hsl]; rfl)
    exact (subSt_slotSub_at U W sl Lg Lg' _ τ (h k sl hsl)).mpr h1

end Congr

/-! ## The run of slots, knowledge version -/

section Knowledge

variable {K : Type} [Field K] [Algebra GF K]

/-- The slots' schedule at the prover's log recovered (by replay) from a log `P`. -/
noncomputable def csAt (U : K) {L : ℕ} (slots : List (SlotX K L)) {β : Type} (A : OC (QB L) Dig β)
    (P : List (QB L × Dig)) : List (CSub Dig) :=
  slotSubs U (slotsAt slots (proverLog A P))

/-- **Fiat–Shamir soundness of a run of executable sumcheck slots whose statements read the PROVER'S LOG** (D63 lane
L16; the knowledge version of L8's `exec_sumchecks_fs_sound`). Each slot's statement (a polynomial `f` of individual
degree `≤ d` and a claimed sum) is a function of the prover's log (as the extractor reads it, `proverLog`: e.g. the
tables extracted from it) and of the code's trace before its rounds; every window starts after `s` entries, and the
statements are frozen once a chain's first `s` entries are logged (`hstab`). The probability that SOME slot's claim is
false of the polynomial at the prover's own log and yet EVERY slot's executable `sumcheck::verify` accepts with its
terminal check is at most `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`: L8's bound,
unchanged. -/
theorem exec_sumchecks_fs_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
      ≤ (((q + slotsLenX slots + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
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
  have hmain := fs_code_chain_sound_sched_log W1 (fun _ => Nat.one_pos)
    (csAt U slots A) _ hR hε hframe
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
    rw [← mul_div_assoc, ← Nat.cast_mul, ← mul_assoc]
    exact dig_bound_le gP hF _

end Knowledge

/-! ## The block's slots over the extracted tables -/

namespace Block

/-- An entry's absorbed bytes, if it is an absorb. -/
def absAt (τ : List (TItem × Dig)) (i : ℕ) : Option (List UInt8) :=
  match τ[i]? with
  | some (.absorb _ x, _) => some x
  | _ => none

/-- The block's three roots as bytes, when present. -/
abbrev RootsO := Option (List UInt8) × Option (List UInt8) × Option (List UInt8)

/-- **The roots the trace shows**: the `A` absorb (right after the header), `M`'s (three later) and `H`'s (seven
later), as `rootOps` absorbs them. -/
def rootsAt (hdrLen : ℕ) (τ : List (TItem × Dig)) : RootsO :=
  (absAt τ hdrLen, absAt τ (hdrLen + 3), absAt τ (hdrLen + 7))

/-- The core's roots. -/
def rootsOf (core : Core) : RootsO := (some core.aRoot.toList, some core.maskRoot.toList, some core.hRoot.toList)

/-- The log cut at a root's first absorption (nothing, when no root is shown). -/
def cutO {Q D : Type} (absOf : Q → Option (List UInt8)) : Option (List UInt8) → List (Q × D) → List (Q × D)
  | some x, P => cutAt absOf x P
  | none, _ => []

/-- The prover's log cut at each of the three roots' first absorption. -/
abbrev Cuts3 (L : ℕ) := List (QB L × Dig) × List (QB L × Dig) × List (QB L × Dig)

def cuts3 {L : ℕ} (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (rt : RootsO) : Cuts3 L :=
  (cutO absOf rt.1 Lg, cutO absOf rt.2.1 Lg, cutO absOf rt.2.2 Lg)

/-- **The bytes a query absorbs**, on a chain encoding of the code's items: its link's item, if an absorb. -/
def absOfC {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (y : Q) : Option (List UInt8) :=
  match C.ldec y with
  | some (_, it) =>
    match it.1 with
    | .absorb _ x => some x
    | .squeeze _ => none
  | none => none

theorem absOfC_link {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (d : Dig) (it : ItB L) (lab x : List UInt8)
    (h : it.1 = .absorb lab x) : absOfC C (C.link d it) = some x := by
  unfold absOfC
  rw [C.ldec_link]
  simp only [h]

/-- **On the verifier's trace the roots are the core's**: the header, then `rootOps`. -/
theorem rootsAt_trace (H : HIn → Dig) (P : BlockParams) (core : Core) (hdr X : List Op) (t : Tr) :
    rootsAt hdr.length (opTrace H t (hdr ++ rootOps P core ++ X)) = rootsOf core := by
  have hl : (opTrace H t hdr).length = hdr.length := opTrace_length H t hdr
  have h0 : (opTrace H t hdr).length ≤ hdr.length := by rw [hl]
  have h3 : (opTrace H t hdr).length ≤ hdr.length + 3 := by rw [hl]; omega
  have h7 : (opTrace H t hdr).length ≤ hdr.length + 7 := by rw [hl]; omega
  rw [List.append_assoc, opTrace_append]
  unfold rootsAt absAt rootsOf
  rw [List.getElem?_append_right h0, List.getElem?_append_right h3, List.getElem?_append_right h7, hl]
  simp [rootOps, rootOpsA, rootOpsH, opTrace]

/-- The roots read off a prefix of at least `hdrLen + 8` entries do not change with what follows. -/
theorem rootsAt_append (hdrLen : ℕ) (l ext : List (TItem × Dig)) (hl : hdrLen + 8 ≤ l.length) :
    rootsAt hdrLen (l ++ ext) = rootsAt hdrLen l := by
  have h0 : hdrLen < l.length := by omega
  have h3 : hdrLen + 3 < l.length := by omega
  have h7 : hdrLen + 7 < l.length := by omega
  unfold rootsAt absAt
  rw [List.getElem?_append_left h0, List.getElem?_append_left h3, List.getElem?_append_left h7]

/-- **A logged chain logs its roots' absorptions**: if entry `i` of a chain whose queries are logged in `P` absorbs `x`,
then `P` holds a query absorbing `x`. -/
theorem absAt_logged {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (G : Q → Dig) (τ : List (ItB L × Dig))
    (qs : List Q) (hc : C.Chain G τ qs) (P : List (Q × Dig)) (hq : ∀ y ∈ qs, y ∈ P.map Prod.fst) (i : ℕ)
    (x : List UInt8) (hx : absAt (τ.map entB) i = some x) : ∃ e ∈ P, absOfC C e.1 = some x := by
  unfold absAt at hx
  rw [List.getElem?_map] at hx
  rcases hti : τ[i]? with _ | p
  · rw [hti] at hx
    simp at hx
  · rw [hti] at hx
    obtain ⟨hi, hpi⟩ := List.getElem?_eq_some_iff.mp hti
    obtain ⟨⟨it, hit⟩, d⟩ := p
    simp only [Option.map_some, entB] at hx
    cases it with
    | squeeze c => simp at hx
    | absorb lab x' =>
      simp only [Option.some.injEq] at hx
      subst hx
      have hmem := chain_link_mem C G hc i hi
      obtain ⟨e, he, he1⟩ := List.mem_map.mp (hq _ hmem)
      refine ⟨e, he, ?_⟩
      rw [he1]
      exact absOfC_link C _ _ lab x' (by rw [hpi])

/-- **The cut at a root the chain shows is frozen** once the chain is logged. -/
theorem cutO_stable {L : ℕ} {Q : Type} (C : ChainEnc (ItB L) Q Dig) (G : Q → Dig)
    (τ : List (ItB L × Dig)) (qs : List Q) (hc : C.Chain G τ qs) (P P' : List (Q × Dig))
    (hq : ∀ y ∈ qs, y ∈ P.map Prod.fst) (hpre : P <+: P') {γ : Type} (A : OC Q Dig γ) (i : ℕ) :
    cutO (absOfC C) (absAt (τ.map entB) i) (proverLog A P) = cutO (absOfC C) (absAt (τ.map entB) i) (proverLog A P') := by
  rcases hx : absAt (τ.map entB) i with _ | x
  · rfl
  · exact (cutAt_proverLog_stable A (absOfC C) x P P' hpre (absAt_logged C G τ qs hc P hq i x hx)).symm

section Sched

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Slot `k` of the block's schedule, its polynomial over the extracted tables**: L9's `blockSlot` whose polynomial
`F (the three cut logs) (the roots) k (what the trace shows)` reads the log cut at the roots the trace shows. -/
def blockSlotX (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (k : ℕ) :
    SlotX K L where
  s := (if k = 0 then hdrLen + 10 else 1) + (P.draws k + 3)
  d := (slotShape P k).2.2
  n := (slotShape P k).1 + (slotShape P k).2.1
  stmt Lg τ :=
    match tSeen P hdrLen k τ with
    | some (sn, _) => (F (cuts3 absOf Lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) k sn, claimOf P k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- The block's schedule over the extracted tables. -/
def blockSchedX (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    List (SlotX K L) :=
  (List.range P.geom.slots.length).map (blockSlotX P hdrLen absOf F)

omit [Algebra GF K] in
theorem slotsLenX_blockSchedX (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    slotsLenX (blockSchedX P hdrLen absOf F) = blockLen P.draws P.geom.slots hdrLen := by
  simp only [slotsLenX, blockSchedX, blockLen, List.map_map]
  rfl

/-- **L9's `BlockWin` with the polynomial over the extracted tables is the slots' win at that log** (the knowledge
form of `blockWin_slotsWin`). -/
theorem blockWinX_slotsWin (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams)
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (out : List Op × Core)
    (hwin : BlockWin U key domain L P hdrLen (fun k sn => F (cuts3 absOf Lg (rootsOf out.2)) (rootsOf out.2) k sn) G out) :
    SlotsWin U key domain L (slotsAt (blockSchedX P hdrLen absOf F) Lg) G (blockOps P out.1 out.2) := by
  obtain ⟨hdr, core⟩ := out
  obtain ⟨hhl, hhfit, hcan, hsh, bga, rs, acc, t', hacc, hterm, kf, rf, hrf, hdeg, hfalse⟩ := hwin
  simp only at hhl hhfit hcan hsh hacc
  have hslen : core.slots.length = P.geom.slots.length := by
    rw [hsh.1]
  rw [blockSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact (hgeom i (by omega)).1
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hbga' : bga = (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).1,
        (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1,
        ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1) :=
      hbga.symm
    have hcanS : ∀ i q, core.slots[i]? = some q → SlotCanon q := fun i q h => hcan.1 q (List.mem_of_getElem? h)
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs, Option.getD_some]
    have hterms : ∀ i q, core.slots[i]? = some q → q.terms.length = slotTerms P i := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs htt).2.2
      rw [this, slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall i q r' hq hi).2.1]
      exact (hcanS i q hq).1
    have hslot : ∀ k sl, (slotsAt (blockSchedX P hdrLen absOf F) Lg)[k]? = some sl →
        k < core.slots.length ∧ sl = (blockSlotX P hdrLen absOf F k).at Lg := by
      intro k sl h
      simp only [slotsAt, blockSchedX, List.map_map, List.getElem?_map] at h
      obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
      rw [List.getElem_range] at hget
      subst hget
      exact ⟨by rw [hslen]; simpa using hlt, rfl⟩
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        ((blockSlotX P hdrLen absOf F k).at Lg).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q))
          = (F (cuts3 absOf Lg (rootsOf core)) (rootsOf core) k (seenOf bga rs k), r.claimed) := by
      intro k q r hq hr
      have htr := tSeen_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround bga rs hbga' hlen
        (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      have hrt : rootsAt hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)) = rootsOf core := by
        rw [List.append_assoc (hdr ++ rootOps P core)]
        exact rootsAt_trace _ _ _ _ _ _
      have hhl' : hdr.length = hdrLen := hhl
      simp only [SlotX.at, blockSlotX]
      rw [← hhl', htr]
      simp only
      rw [hrt]
      obtain ⟨-, hsc, ⟨df, hdf, hcl⟩, -⟩ := hall k q r hq hr
      rw [claimOf_seenOf P bga rs k r hr hscal df (by rw [hbga']; simpa [histOf] using hdf)
        (by rw [hsc]; simpa using hcl)]
    have hpre : ∀ k q ok, core.slots[k]? = some q → (blockOps P hdr core)[k]? = some ok →
        slotPre (blockOps P hdr core) k ok = hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)
          ++ slotPreOps P k q := fun k q ok h1 h2 => slotPre_blockOps P hdr core k q ok h1 h2
    have hok : ∀ k q, core.slots[k]? = some q →
        (blockOps P hdr core)[k]? = some ((if k = 0 then hdr ++ rootOps P core else [termOp (core.slots.getD (k - 1) q)])
          ++ slotPreOps P k q, q.rounds) := by
      intro k q hq
      rw [blockOps, slotOpsFrom_get P _ 0 core.slots k q hq, Nat.zero_add]
    refine ⟨?_, ?_, ?_⟩
    · rw [blockOps, slotOpsFrom_length, slotsAt, List.length_map, blockSchedX, List.length_map, List.length_range,
        hslen]
    · intro k sl ok h1 h2
      obtain ⟨hk, rfl⟩ := hslot k sl h1
      obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
      obtain ⟨r, hr⟩ : ∃ r, rs[k]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      rw [hok k q hq, Option.some.injEq] at h2
      subst h2
      have hst := hstmt k q r hq hr
      rw [hpre k q _ hq (hok k q hq)]
      rw [hst]
      refine ⟨?_, ?_, ?_, ?_, ?_⟩
      · simp only [SlotX.at, blockSlotX, List.length_append, slotPreOps_length]
        split_ifs with hk0
        · simp only [List.length_append, hhl]
          rfl
        · rfl
      · intro op hop
        simp only [List.mem_append] at hop
        rcases hop with hop | hop
        · split_ifs at hop with hk0
          · simp only [List.mem_append] at hop
            rcases hop with hop | hop
            · exact hhfit op hop
            · exact rootOps_len P core L hL op hop
          · simp only [List.mem_singleton] at hop
            subst hop
            have hkm : k - 1 < core.slots.length := by omega
            have hq' : core.slots[k - 1]? = some (core.slots.getD (k - 1) q) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hkm, Option.getD_some]
            exact termOp_len _ (slotTerms P (k - 1)) L (hterms _ _ hq') (hgeom (k - 1) (by omega)).2
        · exact slotPreOps_len P k q L hL op hop
      · exact (hcanS k q hq).2.1
      · obtain ⟨-, -, ⟨df, -, hcl⟩, -⟩ := hall k q r hq hr
        exact hostedSum_canon _ q.scalar _ _ (hcanS k q hq).1 hcl
      · obtain ⟨-, -, -, hsv⟩ := hall k q r hq hr
        simp only [Nat.zero_add] at hsv
        refine ⟨r.fin, r.rho ++ r.es, ?_, hterm k r hr⟩
        have hT : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)
            = runOps (liftH G) (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core)) 0 core.slots k) (slotPreOps P k q) := by
          rw [runOps_append, runOps_append]
          rfl
        rw [hT]
        exact hsv
    · obtain ⟨hk, -⟩ : kf < core.slots.length ∧ True := ⟨by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hrf).1, trivial⟩
      obtain ⟨q, hq⟩ : ∃ q, core.slots[kf]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
      refine ⟨kf, (blockSlotX P hdrLen absOf F kf).at Lg, _, ?_, hok kf q hq, ?_⟩
      · have hk' : kf < (List.range P.geom.slots.length).length := by rw [List.length_range, ← hslen]; exact hk
        rw [slotsAt, blockSchedX, List.map_map, List.getElem?_map, List.getElem?_eq_getElem hk', List.getElem_range]
        rfl
      · rw [hpre kf q _ hq (hok kf q hq), hstmt kf q rf hq hrf]
        exact ⟨hdeg, hfalse⟩
  · cases hacc

/-- **Fiat–Shamir soundness of the block's slots, the KNOWLEDGE version** (D63 lane L16; L10-6 (a) for the slots).
In the random-oracle model on the hash inputs of at most `L` bytes, a prover making at most `q` queries outputs a
header of `hdrLen` operations and a block core. Let each slot's polynomial be ANY function `F` of the prover's own log
cut at the first absorption of each of the core's three roots (`cuts3`: the data the extractor reads, as
`FSOpening.lean`'s extraction rule), of the roots, and of what the trace shows (`Seen`): e.g. the masked slot polynomial
over the tables extracted from that log. The probability that `blockSlots` accepts, every slot's terminal check
`fin = f(ρ)` holds for that polynomial, and yet SOME slot's claimed sum is false of it, is at most L9's bound
`T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ = blockLen`. -/
theorem block_sumchecks_fs_knowledge [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
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
      ≤ (((q + blockLen P.draws P.geom.slots hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
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
  have hmain := exec_sumchecks_fs_knowledge U hU hK2 key domain hs L hL hL64
    (blockSchedX P hdrLen (absOfC (chainEncB key domain hs L hL)) F) dmax hsl (hdrLen + 8) hwin q A' hA' hstab
  rw [slotsLenX_blockSchedX] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hwinG
  rw [Set.mem_ofPred_eq] at hwinG ⊢
  rw [hlog G, hrun G]
  exact blockWinX_slotsWin U key domain P hdrLen (absOfC (chainEncB key domain hs L hL)) F
    (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G (A.runLog G).2 (A.run G) hwinG

/-- **At the block's shape**: with Goldilocks' `|K| = p²`, every round degree `≤ dmax ≤ 7` and
`T = q + ℓ + 1 ≤ 2^64 + 2^20`, a false claimed sum in ANY slot, of polynomials over the tables extracted from the
prover's log, passes `blockSlots` with every terminal check with probability at most `2^-61`. -/
theorem block_sumchecks_fs_knowledge_shape [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (dmax : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (hd7 : dmax ≤ 7) (hT : q + blockLen P.draws P.geom.slots hdrLen + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen
        (fun k sn => F (cuts3 (absOfC (chainEncB key domain hs L hL)) (A.runLog G).2 (rootsOf (A.run G).2))
          (rootsOf (A.run G).2) k sn) G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  have hdp : dmax < gP := lt_of_le_of_lt hd7 (by norm_num [gP])
  refine (block_sumchecks_fs_knowledge U hU hK2 key domain hs hL hL64 hL81 P hdrLen F dmax hdp hgeom hgt q A hA).trans ?_
  rw [hF]
  exact block_bound_le gP _ dmax (by norm_num [gP]) (by norm_num [gP]) hT hd7

end Sched

namespace W16R2

/-- **The W16R2 rung block's sumcheck bound, knowledge version** (D63 lane L16). For a block verifier with the rung's
schedule, a header of at most `2^19` operations, hash inputs of at most `L ≥ 2^20` bytes and a prover making at most
`q ≤ 2^64` queries: for ANY slot polynomials over the tables extracted from the prover's log (cut at the roots'
absorption), a false claimed sum in any of the 23 slots passes `blockSlots` with every terminal check with
probability at most `2^-61`. -/
theorem rung_block_fs_knowledge {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hdr : P.draws = rungDraws) (hsl : P.geom.slots = rungSlots)
    (htm : P.geom.terms = rungTerms) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (q : ℕ) (hq : q ≤ 2 ^ 64) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen
        (fun k sn => F (cuts3 (absOfC (chainEncB key domain hs L hL)) (A.runLog G).2 (rootsOf (A.run G).2))
          (rootsOf (A.run G).2) k sn) G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  refine block_sumchecks_fs_knowledge_shape U hU hK2 key domain hs hL hL64 (by omega) P hdrLen F 5 ?_ ?_ q A hA
    (by norm_num) ?_
  · intro k hk
    rw [hsl] at hk
    have hk' : k < 23 := by simpa [rungSlots] using hk
    obtain ⟨h1, h2, h3, h4⟩ := rung_slot_facts k hk'
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  · rw [hsl, htm]
    rfl
  · rw [hdr, hsl, rung_len]
    have h1 : hdrLen + 1044 + 1 ≤ 2 ^ 20 :=
      le_trans (Nat.add_le_add_right (Nat.add_le_add_right hh 1044) 1) (by norm_num)
    calc q + (hdrLen + 1044) + 1 = q + (hdrLen + 1044 + 1) := by rw [Nat.add_assoc]
      _ ≤ 2 ^ 64 + 2 ^ 20 := Nat.add_le_add hq h1

end W16R2

end Block

end ZK60.Exec
