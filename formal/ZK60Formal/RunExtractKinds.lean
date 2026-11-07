/-
D63 lane L24 (2026-11-07), part 3: **the run's extraction from KINDS of sub-protocols, each counted jointly over the
run with the first-doom count** (`ZoneCodeFirst.lean`), and the arithmetic against the approved target.

A run-level extraction event (accepted, and a part's conclusion fails on the extracted data) is covered, through the
deterministic links of the parts (named premises), by finitely many KINDS of sub-protocols: the slots, `M`, the regular
openings' two halves, the define draws of the slot relations and of the helpers, LogUp. One kind is ONE schedule on the
run's chain holding that kind's sub-protocols of EVERY block (and, in the joint form, of the stages): its first-doom
count charges the prover's queries the kind's largest error and the verifier's chain ONE sub-protocol's rounds. The
union over the kinds is then a union over a handful of schedules, not over the 26 blocks: the run costs what one block
costs (finding L18-2 resolved for the blocks).

* `FirstKind`, `FirstKind.Ev`, `FirstKind.bnd`, **`FirstKind.prob_le`**: a kind (its chain encoding, step parse, heads,
  log-indexed schedule and the premises of `fs_code_chain_first_log`, for every prover of the run); its event (some
  sub-protocol entered doomed, every one alive at the end); its bound `q·εmax + B + collBound T + collBound (T + 1)`;
* `prH_exists_list`, **`ext_of_kinds`**, `ext_of_kinds_min`: any event covered by a list of kinds and one extra event
  (the Merkle extraction failure) is at most the extra bound plus the kinds' bounds (and at most `1`);
* `coll_le_u126_102`, `FirstKind.bnd_le_u126`, `kinds_le_u126`: each kind within `(q + 1)·(c + 2^17)/2^126` for
  `q + 1 ≤ 2^102`, a chain of at most `2^21` items and its linear part `q·εmax + B ≤ (q + 1)·c/2^126`;
* `half_eq`, `u126_le_half`, `xfail_le_u126_102`: the half target `q·2^-101 + 2^-101 = (q + 1)/2^101` and the Merkle
  extraction failure in the same units;
* `lin_kind_le`, `sched_kind_le`, `logup_kind_le`, `lk_main_le_u126_r13`: the kinds' linear parts at their forms (one
  error per round; `(q·d + ND)/p²·(1 + p/2^128)²`; LogUp's `(q·e + 3e)/p²·(1 + p/2^128)²`, at W16R2 `e ≤ 35,153,256`
  and at R13 `e ≤ 2^26`).

Facts about the literal Goldilocks prime are stated for a variable `p` within `2^32` below `2^64` (L7-4). Only
`propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ZoneCodeFirst
import ZK60Formal.AssembleClassify
import ZK60Formal.RelW16Pos

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound

/-! ## A kind of sub-protocol on the run's chain -/

section Kind

variable {Lq : ℕ} {α : Type}

/-- **One kind of sub-protocol, jointly over the run** (D63 lane L24): one log-indexed schedule on one chain encoding of
the run's transcript, with every premise of `fs_code_chain_first_log`, for every prover whose output is `α` (the run's
statement and receipt). Its sub-protocols are that kind's sub-protocols of every part (every block's, and in the joint
form the stages'), their windows in the run's order. -/
structure FirstKind (Lq : ℕ) (α : Type) : Type 1 where
  It : Type
  W : UInt64 → ℕ
  hW : ∀ k, 0 < W k
  C : ChainEnc It (QB Lq) Dig
  toT : It → TItem
  S : Steps It
  hS : StepsOK W toT S
  heads : α → List It
  ℓ : ℕ
  hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ
  s : ℕ
  hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s
  cs : List (QB Lq × Dig) → List (CSub Dig)
  hsort : ∀ P, SortedA (cs P)
  εmax : ℝ≥0∞
  hR : ∀ P, ∀ c ∈ cs P, RbrWide c.R.n c.R.w c.St c.ε
  hε : ∀ P, ∀ c ∈ cs P, c.ε ≤ εmax
  hnorel : ∀ P, ∀ c ∈ cs P, ∀ τ, ¬ c.rel τ
  B : ℝ≥0∞
  hB : ∀ P, ∀ c ∈ cs P, (c.R.n : ℝ≥0∞) * c.ε ≤ B
  hwin : ∀ P, ∀ c ∈ cs P, s < c.a
  hstab : ∀ (A : OC (QB Lq) Dig α) (H : QB Lq → Dig) (L : List (QB Lq × Dig)) (t : ℕ) (τ : List (It × Dig))
    (qs : List (QB Lq)) (it : It) (e2 : Dig),
    C.Chain H τ qs → s ≤ τ.length → (∃ hs : List It, τ.map Prod.fst = hs.flatMap S.items) →
    (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
    L[t]? = some (C.link (C.lastD H τ) it, e2) → C.link (C.lastD H τ) it ∉ (L.take t).map Prod.fst →
    ∀ ext : List (It × Dig), (ext = [] ∨ ∃ ds, ext = S.ents it ds) →
    ∀ τ' : List (TItem × Dig), τ' <+: (τ ++ ext).map (toTE toT) →
      (firstSt W (cs (proverLog A (L.take t))) τ' ↔ firstSt W (cs (proverLog A L)) τ')

/-- **The kind's event** for a prover `A`: some sub-protocol of the kind entered its window with a false claim (of the
data extracted from `A`'s log) and every sub-protocol of the kind is alive at the end of the run's chain. -/
def FirstKind.Ev (K : FirstKind Lq α) (A : OC (QB Lq) Dig α) (G : QB Lq → Dig) : Prop :=
  (∃ (k : ℕ) (c : CSub Dig), (K.cs (A.runLog G).2)[k]? = some c
      ∧ EntD K.W c (cChain K.C K.toT K.S G (K.heads (A.run G))))
    ∧ allSt K.W (K.cs (A.runLog G).2) (cChain K.C K.toT K.S G (K.heads (A.run G)))

/-- **The kind's bound**: `q·εmax + B + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`. -/
noncomputable def FirstKind.bnd (K : FirstKind Lq α) (q : ℕ) : ℝ≥0∞ :=
  (q : ℝ≥0∞) * K.εmax + K.B + collBound (q + K.ℓ + 1) Dig + collBound (q + K.ℓ + 1 + 1) Dig

/-- **A kind's event has probability at most its bound** (`fs_code_chain_first_log`). -/
theorem FirstKind.prob_le (K : FirstKind Lq α) (q : ℕ) (A : OC (QB Lq) Dig α) (hA : A.Bounded q) :
    prH (K.Ev A) ≤ K.bnd q :=
  fs_code_chain_first_log K.W K.hW A K.cs K.hsort K.εmax K.hR K.hε K.hnorel K.B K.hB K.C K.toT K.S K.hS K.heads K.ℓ
    K.hℓ K.s K.hwin K.hhd (K.hstab A) q hA

end Kind

/-! ## The union over a list of kinds -/

section Union

/-- Sums of lists in `ℝ≥0∞`, termwise (L20's `lsum_le_lsum` for lists of any universe). -/
theorem lsum_le_lsum_univ {β : Type _} {l : List β} {f g : β → ℝ≥0∞} (h : ∀ x ∈ l, f x ≤ g x) :
    (l.map f).sum ≤ (l.map g).sum := by
  induction l with
  | nil => simp
  | cons a l ih =>
    simp only [List.map_cons, List.sum_cons]
    exact add_le_add (h a List.mem_cons_self) (ih (fun x hx => h x (List.mem_cons_of_mem _ hx)))

/-- The union bound over a list. -/
theorem prH_exists_list {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] {β : Type _}
    (E : β → (Q → D) → Prop) : ∀ l : List β, prH (fun H => ∃ b ∈ l, E b H) ≤ (l.map (fun b => prH (E b))).sum
  | [] => by
    have h0 : prH (fun H : Q → D => ∃ b ∈ ([] : List β), E b H) = 0 := by
      unfold prH
      have he : {H : Q → D | ∃ b ∈ ([] : List β), E b H} = ∅ :=
        Set.eq_empty_iff_forall_notMem.mpr (fun H hH => by simp at hH)
      rw [he, MeasureTheory.measure_empty]
    rw [h0]
    exact zero_le
  | b :: l => by
    refine le_trans (prH_mono (B := fun H => E b H ∨ ∃ b' ∈ l, E b' H) (fun H hH => ?_)) ?_
    · obtain ⟨b', hb', h⟩ := hH
      rcases List.mem_cons.mp hb' with rfl | hb''
      · exact Or.inl h
      · exact Or.inr ⟨b', hb'', h⟩
    · refine (prH_or_le _ _).trans ?_
      rw [List.map_cons, List.sum_cons]
      exact add_le_add le_rfl (prH_exists_list E l)

variable {Lq : ℕ} {α : Type}

/-- **A run-level extraction event from kinds**: if, for every prover and oracle, the event `Ev` lies in the extra
event `Ex` (the Merkle extraction failure) or in some kind's event, its probability is at most `Ex`'s bound plus the
kinds' bounds. -/
theorem ext_of_kinds (Ks : List (FirstKind Lq α)) (Ev Ex : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop)
    (εx : ℕ → ℝ≥0∞) (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig α), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Ev A G → Ex A G ∨ ∃ K ∈ Ks, K.Ev A G)
    (q : ℕ) (A : OC (QB Lq) Dig α) (hA : A.Bounded q) :
    prH (Ev A) ≤ εx q + (Ks.map (fun K => K.bnd q)).sum := by
  refine le_trans (prH_mono (B := fun G => Ex A G ∨ ∃ K ∈ Ks, K.Ev A G) (fun G hG => hcover A G hG)) ?_
  refine (prH_or_le _ _).trans (add_le_add (hEx q A hA) ?_)
  refine (prH_exists_list (fun K : FirstKind Lq α => K.Ev A) Ks).trans ?_
  exact lsum_le_lsum_univ (fun (K : FirstKind Lq α) _ => K.prob_le q A hA)

/-- **The same, capped at `1`**: the bound used as a field of `ClassifyOpen` (a probability is at most `1`). -/
noncomputable def εKinds (Ks : List (FirstKind Lq α)) (εx : ℕ → ℝ≥0∞) (q : ℕ) : ℝ≥0∞ :=
  min 1 (εx q + (Ks.map (fun K => K.bnd q)).sum)

theorem ext_of_kinds_min (Ks : List (FirstKind Lq α)) (Ev Ex : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop)
    (εx : ℕ → ℝ≥0∞) (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig α), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Ev A G → Ex A G ∨ ∃ K ∈ Ks, K.Ev A G)
    (q : ℕ) (A : OC (QB Lq) Dig α) (hA : A.Bounded q) : prH (Ev A) ≤ εKinds Ks εx q :=
  le_min (prH_le_one _) (ext_of_kinds Ks Ev Ex εx hEx hcover q A hA)

end Union

/-! ## The arithmetic, in L20's units `(q + 1)·c/2^126` -/

section Numbers

variable {Lq : ℕ} {α : Type}

/-- **A collision term for `q + 1 ≤ 2^102`**: `collBound t ≤ (q + 1)·2^16/2^126` for `t ≤ 2^22·(q + 1)` (L20's
`coll_le_u126` covers `q < 2^100` with `2^14`). -/
theorem coll_le_u126_102 (q t : ℕ) (hq : q + 1 ≤ 2 ^ 102) (ht : t ≤ 2 ^ 22 * (q + 1)) :
    collBound t Dig ≤ u126 q (2 ^ 16) := by
  unfold collBound u126
  rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  calc t * (t - 1) / 2 * 2 ^ 126 ≤ t * t * 2 ^ 126 := by
        gcongr
        exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
    _ ≤ (2 ^ 22 * (q + 1)) * (2 ^ 22 * (q + 1)) * 2 ^ 126 := by gcongr
    _ = (q + 1) * ((q + 1) * 2 ^ 170) := by ring
    _ ≤ (q + 1) * (2 ^ 102 * 2 ^ 170) := by gcongr
    _ = (q + 1) * 2 ^ 16 * (2 ^ 128 * 2 ^ 128) := by ring

/-- **A kind within `(q + 1)·(c + 2^17)/2^126`** for `q + 1 ≤ 2^102`, its chain of at most `2^21` items and its linear
part `q·εmax + B ≤ (q + 1)·c/2^126`. -/
theorem FirstKind.bnd_le_u126 (K : FirstKind Lq α) (q c : ℕ) (hq : q + 1 ≤ 2 ^ 102) (hℓ : K.ℓ ≤ 2 ^ 21)
    (hlin : (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q c) : K.bnd q ≤ u126 q (c + 2 ^ 17) := by
  unfold FirstKind.bnd
  have h1 := coll_le_u126_102 q (q + K.ℓ + 1) hq (by omega)
  have h2 := coll_le_u126_102 q (q + K.ℓ + 1 + 1) hq (by omega)
  calc _ ≤ u126 q c + u126 q (2 ^ 16) + u126 q (2 ^ 16) := add_le_add (add_le_add hlin h1) h2
    _ = u126 q (c + 2 ^ 17) := by
        rw [u126_add, u126_add, show c + 2 ^ 16 + 2 ^ 16 = c + 2 ^ 17 by omega]

/-- **A list of kinds**: the sum of their bounds within `(q + 1)·Σ (c_K + 2^17)/2^126`. -/
theorem kinds_le_u126 (c : FirstKind Lq α → ℕ) (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) :
    ∀ Ks : List (FirstKind Lq α), (∀ K ∈ Ks, K.ℓ ≤ 2 ^ 21) →
      (∀ K ∈ Ks, (q : ℝ≥0∞) * K.εmax + K.B ≤ u126 q (c K)) →
      (Ks.map (fun K => K.bnd q)).sum ≤ u126 q (Ks.map (fun K => c K + 2 ^ 17)).sum
  | [], _, _ => by simp
  | K :: Ks, hℓ, hlin => by
    rw [List.map_cons, List.sum_cons, List.map_cons, List.sum_cons, ← u126_add]
    exact add_le_add (K.bnd_le_u126 q (c K) hq (hℓ K List.mem_cons_self) (hlin K List.mem_cons_self))
      (kinds_le_u126 c q hq Ks (fun K' h => hℓ K' (List.mem_cons_of_mem _ h))
        (fun K' h => hlin K' (List.mem_cons_of_mem _ h)))

/-- **The half target** `q·2^-101 + 2^-101 = (q + 1)/2^101`. -/
theorem half_eq (q : ℕ) :
    (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 = ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 101 : ℕ) : ℝ≥0∞) := by
  rw [inv_two_pow_eq, Nat.cast_one, ← mul_div_assoc, mul_one, ENNReal.div_add_div_same, Nat.cast_add, Nat.cast_one]

/-- `(q + 1)·c/2^126` is within the half target when `c ≤ 2^25`. -/
theorem u126_le_half (q c : ℕ) (hc : c ≤ 2 ^ 25) :
    u126 q c ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 := by
  rw [half_eq]
  unfold u126
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  calc (q + 1) * c * 2 ^ 101 ≤ (q + 1) * 2 ^ 25 * 2 ^ 101 := by gcongr
    _ = (q + 1) * 2 ^ 126 := by ring

/-- The half target is at least `1` from `2^101 − 1` queries on. -/
theorem one_le_half {q : ℕ} (hq : 2 ^ 101 ≤ q + 1) :
    (1 : ℝ≥0∞) ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 := by
  rw [half_eq, ENNReal.le_div_iff_mul_le (Or.inl (by positivity)) (Or.inl (ENNReal.natCast_ne_top _)), one_mul]
  exact_mod_cast hq

/-- The approved target is at least `4` beyond `2^102` queries. -/
theorem four_le_target {q : ℕ} (hq : 2 ^ 102 ≤ q + 1) : (4 : ℝ≥0∞) ≤ εsTarget q := by
  rw [εsTarget_eq, ENNReal.le_div_iff_mul_le (Or.inl (by positivity)) (Or.inl (ENNReal.natCast_ne_top _))]
  have h : (4 : ℝ≥0∞) * ((2 ^ 100 : ℕ) : ℝ≥0∞) = ((4 * 2 ^ 100 : ℕ) : ℝ≥0∞) := by push_cast; ring
  rw [h]
  exact_mod_cast (show 4 * 2 ^ 100 ≤ q + 1 by
    calc 4 * 2 ^ 100 = 2 ^ 102 := by norm_num
      _ ≤ q + 1 := hq)

/-- **The Merkle extraction failure** (`extract_fail_run`'s bound) for `q + 1 ≤ 2^102`, a run of `T' ≤ 2^22·(q + 1)`
queries and at most `2^100` roots: at most `(q + 1)·(2^16 + 2^18)/2^126`. -/
theorem xfail_le_u126_102 (q T' nr : ℕ) (hq : q + 1 ≤ 2 ^ 102) (hT : T' ≤ 2 ^ 22 * (q + 1)) (hnr : nr ≤ 2 ^ 100) :
    collBound T' Dig + ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig
      ≤ u126 q (2 ^ 16 + 2 ^ 18) := by
  have hc := coll_le_u126_102 q T' hq hT
  have hf : ((2 * T' * T' + (1 + nr) * T' : ℕ) : ℝ≥0∞) / Fintype.card Dig ≤ u126 q (2 ^ 18) := by
    unfold u126
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
    refine natCast_div_le_div (by positivity) (by positivity) ?_
    have hsq : T' * T' ≤ 2 ^ 146 * (q + 1) := by
      calc T' * T' ≤ (2 ^ 22 * (q + 1)) * (2 ^ 22 * (q + 1)) := Nat.mul_le_mul hT hT
        _ = 2 ^ 44 * (q + 1) * (q + 1) := by ring
        _ ≤ 2 ^ 44 * (q + 1) * 2 ^ 102 := Nat.mul_le_mul_left _ hq
        _ = 2 ^ 146 * (q + 1) := by ring
    have hlin : (1 + nr) * T' ≤ 2 ^ 146 * (q + 1) := by
      calc (1 + nr) * T' ≤ (2 * 2 ^ 100) * (2 ^ 22 * (q + 1)) :=
            Nat.mul_le_mul (by have : 1 ≤ 2 ^ 100 := Nat.one_le_two_pow; omega) hT
        _ = 2 ^ 123 * (q + 1) := by ring
        _ ≤ 2 ^ 146 * (q + 1) := Nat.mul_le_mul_right _ (Nat.pow_le_pow_right (by norm_num) (by norm_num))
    calc (2 * T' * T' + (1 + nr) * T') * 2 ^ 126 ≤ (2 * (2 ^ 146 * (q + 1)) + 2 ^ 146 * (q + 1)) * 2 ^ 126 := by
          rw [mul_assoc 2 T' T']
          exact Nat.mul_le_mul_right _ (Nat.add_le_add (Nat.mul_le_mul_left 2 hsq) hlin)
      _ = (q + 1) * (3 * (2 ^ 146 * 2 ^ 126)) := by ring
      _ ≤ (q + 1) * (4 * (2 ^ 146 * 2 ^ 126)) := Nat.mul_le_mul_left _ (Nat.mul_le_mul_right _ (by norm_num))
      _ = (q + 1) * 2 ^ 18 * (2 ^ 128 * 2 ^ 128) := by ring
  calc _ ≤ u126 q (2 ^ 16) + u126 q (2 ^ 18) := add_le_add hc hf
    _ = _ := u126_add _ _ _

/-- **A kind whose sub-protocols have one error per round** (`M`, the openings' halves): `εmax ≤ 2^-j` and
`B ≤ n·εmax` give a linear part within `(q + 1)·n·2^(126 − j)/2^126` (L20's `lin_le_u126`). -/
theorem lin_kind_le (q n j : ℕ) (hj : j ≤ 126) (hn : 1 ≤ n) (εmax B : ℝ≥0∞) (hε : εmax ≤ (2⁻¹ : ℝ≥0∞) ^ j)
    (hB : B ≤ (n : ℝ≥0∞) * εmax) : (q : ℝ≥0∞) * εmax + B ≤ u126 q (n * 2 ^ (126 - j)) :=
  (add_le_add le_rfl hB).trans (lin_le_u126 q n j hj hn εmax hε)

/-- **A kind of slots or define draws** (`εmax = d·β/p²`, `B ≤ ND·β/p²`, `β = (1 + p/2^128)²`): a linear part within
`(q + 1)·(d + ND)/2^126` (L20's `slots_le_u126`). -/
theorem sched_kind_le (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q d ND : ℕ) (B : ℝ≥0∞)
    (hB : B ≤ (ND : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2) :
    (q : ℝ≥0∞) * ((d : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2) + B
      ≤ u126 q (d + ND) := by
  refine le_trans ?_ (slots_le_u126 p hp1 hp2 q d ND)
  refine le_trans (add_le_add le_rfl hB) (le_of_eq ?_)
  push_cast
  simp only [div_eq_mul_inv]
  ring

/-- **LogUp's kind** (`εmax = e·β/p²`, `B ≤ 3·εmax`): its linear part is `(q·e + 3e)·β/p²`, so within any bound of
that (L21's `lk_main_le_u126`: `(q + 1)·26,370,000/2^126` for `e ≤ 35,153,256`, W16R2 8B T128;
`lk_main_le_u126_r13`: `(q + 1)·50,331,700/2^126` for `e ≤ 2^26`, R13). -/
theorem logup_kind_le (p : ℕ) (q e : ℕ) (B : ℝ≥0∞)
    (hB : B ≤ 3 * ((e : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2))
    (c : ℕ) (hc : ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q c) :
    (q : ℝ≥0∞) * ((e : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2) + B
      ≤ u126 q c := by
  refine le_trans ?_ hc
  refine le_trans (add_le_add le_rfl hB) (le_of_eq ?_)
  push_cast
  simp only [div_eq_mul_inv]
  ring

/-- **LogUp's linear part at R13** (`e = N + 2M ≤ 2^26`; the Shieldstral T128 R13 block's lookups read about 64.3 M
words of `A`, D54): `(q·e + 3e)/p²·(1 + p/2^128)² ≤ (q + 1)·50,331,700/2^126` (about `3e/4`). -/
theorem lk_main_le_u126_r13 (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (q e : ℕ) (he : e ≤ 2 ^ 26) :
    ((q * e + 3 * e : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ u126 q 50331700 := by
  have hp0 : p ≠ 0 := by omega
  rw [Block.bias_frac, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
  unfold u126
  refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
  have h1 : q * e + 3 * e ≤ 3 * (q + 1) * 2 ^ 26 := by
    calc q * e + 3 * e = (q + 3) * e := by ring
      _ ≤ (q + 3) * 2 ^ 26 := Nat.mul_le_mul_left _ he
      _ ≤ 3 * (q + 1) * 2 ^ 26 := Nat.mul_le_mul_right _ (by omega)
  calc (q * e + 3 * e) * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 126
      ≤ (3 * (q + 1) * 2 ^ 26) * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126 := by gcongr
    _ = (q + 1) * (3 * 2 ^ 26 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126) := by ring
    _ ≤ (q + 1) * (50331700 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128))) := Nat.mul_le_mul_left _ (by norm_num)
    _ ≤ (q + 1) * (50331700 * (p ^ 2 * (2 ^ 128 * 2 ^ 128))) := by gcongr
    _ = (q + 1) * 50331700 * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by ring

end Numbers

end ZK60.ProtocolClassify
