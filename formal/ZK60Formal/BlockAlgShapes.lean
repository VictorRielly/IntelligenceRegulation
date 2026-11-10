/-
D63 lane L36 (2026-11-09), part 6: **the shape facts at the three profiles** (the block algebra's `AlgShape` is met
by the code's draw schedules), and **the block's lookup counts** over the padded cubes.

* `ipStd`, `ipStd_inj`, `ipStd_lt`: where a hosted claim point's coordinates sit in the hosted slot's draws: in draw
  order, except `SC_PV`, which draws `(r_h, r_t, r_i)` and publishes `(r_t, r_h, r_i)` (L11's `claimPoint`);
* `r13_host_layout`: the six R13 hosts' draw lists have the layout L23's `hostAt` needs (as `w16r2_host_layout`);
* `algShapeStd`: an `AlgShape` from a draw schedule and its numbers;
* **`algShapeW16Rung`**, **`algShapeR13Rung`**, **`algShapeR13Shield`**: the W16R2 rung's, the R13 rung's and the
  Shieldstral T128 R13 block's shape facts, for any pad plane counts of at most `78` (none where a host draws no
  `ζ`): every hypothesis of `AlgShape` is decided on the recorded draw lists, so the lane's statements are not
  vacuous in their shape premises;
* `lkCount`, **`lkCount_w16r2_rung`**, **`lkCount_r13_rung`**, **`lkCount_r13_shield`**,
  **`lkCount_r13_shield_gt`**: the looked-up tuples of one block over the padded cubes (lookups per position, from
  L17's shape corpus, times positions): `1,015,808`, `2,015,232`, `64,258,048`; the last EXCEEDS the bound
  `35,153,256` of the block statements' premise `he` (finding L36-1) and is within `2^26`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockAlgInst

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Exec.Slot.W16R2 (Seg segOff segLn segSum ShapeW Dom scTZC scDZC scQZC scKVZC scSZC scFZC padOn shRungW16)

/-- The hosted pairs are L11's `hostsOf` (the code's `HOSTS`), in `ν` order. -/
theorem hostedOf_hostsOf : ∀ k ∈ algHosts, [hostedOf k 0, hostedOf k 1] = ZK60.Exec.Slot.W16R2.hostsOf k := by
  decide

/-- **Where coordinate `t` of a hosted claim point sits in the hosted slot's draws**: `SC_PV` (pair 1 of `SC_QZC`)
draws `(r_h, r_t, r_i)` and publishes `(r_t, r_h, r_i)`; every other slot read off its own draws publishes them in
draw order. -/
def ipStd (lt lh : ℕ) (k : ℕ) (i : Fin 2) (t : ℕ) : ℕ :=
  if k = 15 ∧ i = 1 then (if t < lt then lh + t else if t < lt + lh then t - lt else t) else t

theorem ipStd_inj (lt lh : ℕ) (k : ℕ) (i : Fin 2) : Function.Injective (ipStd lt lh k i) := by
  intro a b h
  unfold ipStd at h
  split_ifs at h <;> omega

theorem ipStd_lt (lt lh : ℕ) (k : ℕ) (i : Fin 2) (t D : ℕ) (ht : t < D) (hD : k = 15 ∧ i = 1 → lt + lh ≤ D) :
    ipStd lt lh k i t < D := by
  unfold ipStd
  split_ifs with h1 h2 h3
  · have := hD h1
    omega
  · have := hD h1
    omega
  · exact ht
  · exact ht

/-- **The six R13 hosts' draws**, at every shape: distinct segment kinds, `ν` of length `2`, at most one `ζ`, and `μ`
holds the pad weight where the slot pads (L23's `w16r2_host_layout`, for `SlotR13.draws`). -/
theorem r13_host_layout (sh : ShapeW) (s : ℕ)
    (hs : s = scTZC ∨ s = scDZC ∨ s = scQZC ∨ s = scKVZC ∨ s = scSZC ∨ s = scFZC) :
    ((ZK60.Exec.Slot.R13.draws sh s).map Prod.fst).Nodup ∧ segLn (ZK60.Exec.Slot.R13.draws sh s) .nu = 2
      ∧ segLn (ZK60.Exec.Slot.R13.draws sh s) .zeta ≤ 1
      ∧ segLn (ZK60.Exec.Slot.R13.draws sh s) .zeta ≤ segLn (ZK60.Exec.Slot.R13.draws sh s) .mu := by
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl <;>
  · refine ⟨?_, ?_, ?_, ?_⟩
    all_goals simp [ZK60.Exec.Slot.R13.draws, ZK60.Exec.Slot.W16R2.draws, segLn]
    all_goals (try split_ifs)
    all_goals omega

/-- **An `AlgShape` from a draw schedule and its numbers**: the token log `lt` (the split points' first block), the
head log `lh` (`SC_PV`'s permutation), `cq`, `cf` (the rest of `SC_QMM`'s and `SC_GMM`'s draws), `Dom::Ht`'s log
`nHt` and `Dom::S`'s column log `bS`. -/
def algShapeStd (P : BlockParams) (dl : ℕ → List (Seg × ℕ)) (mpad : ℕ → ℕ) (lt lh cq cf nHt bS : ℕ)
    (hsum : ∀ k ∈ algHosts, segSum (dl k) = P.draws k) (hlay : ∀ k ∈ algHosts, HostLay (dl k))
    (hm0 : ∀ k ∈ algHosts, segLn (dl k) .zeta = 0 → mpad k = 0) (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78)
    (hle : ∀ k ∈ algHosts, ∀ i : Fin 2, ¬ (k = 16 ∨ (k = 18 ∧ i = 1)) → ¬ (k = 17 ∧ i = 0) →
      segLn (dl k) .tau ≤ P.draws (hostedOf k i) ∧ (k = 15 ∧ i = 1 → lt + lh ≤ P.draws (hostedOf k i)))
    (hp16 : ∀ i : Fin 2, segLn (dl 16) .tau = lt + P.draws (hostedOf 16 i))
    (hp18 : segLn (dl 18) .tau = lt + P.draws (hostedOf 18 1))
    (hq5 : lt + cq = P.draws 5) (hq11 : lt + cf = P.draws 11) (hb6 : P.draws 6 ≤ cq) (hb7 : P.draws 7 ≤ cq)
    (hb12 : P.draws 12 ≤ cf) (hrs : nHt + 1 = P.draws 4) (hS17 : segLn (dl 17) .tau = nHt + bS) :
    AlgShape P where
  dl := dl
  mpad := mpad
  pa := lt
  cq := cq
  cf := cf
  nHt := nHt
  bS := bS
  ip := fun k i t => ipStd lt lh k i t
  hsum := hsum
  hlay := hlay
  hm0 := hm0
  hm78 := hm78
  hipLt := fun k hk i h1 h2 t =>
    ipStd_lt lt lh k i t _ (lt_of_lt_of_le t.isLt (hle k hk i h1 h2).1) (hle k hk i h1 h2).2
  hipInj := fun k _ i _ _ a b hab => Fin.ext (ipStd_inj lt lh k i hab)
  hpart := fun k i h => by
    rcases h with rfl | ⟨rfl, rfl⟩
    · exact hp16 i
    · exact hp18
  hq5 := hq5
  hq11 := hq11
  hb6 := hb6
  hb7 := hb7
  hb12 := hb12
  hrs := hrs
  hS := fun k hk => by
    subst hk
    exact hS17

theorem hostLay_w16 (sh : ShapeW) : ∀ k ∈ algHosts, HostLay (ZK60.Exec.Slot.W16R2.draws sh k) := by
  intro k hk
  have h := ZK60.Exec.Slot.W16R2.w16r2_host_layout sh k (by
    simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl | rfl | rfl | rfl | rfl <;> decide)
  exact ⟨h.1, h.2.1, h.2.2.1, h.2.2.2⟩

theorem hostLay_r13 (sh : ShapeW) : ∀ k ∈ algHosts, HostLay (ZK60.Exec.Slot.R13.draws sh k) := by
  intro k hk
  have h := r13_host_layout sh k (by
    simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
    rcases hk with rfl | rfl | rfl | rfl | rfl | rfl <;> decide)
  exact ⟨h.1, h.2.1, h.2.2.1, h.2.2.2⟩

/-- **The W16R2 rung's shape facts** (`lt = 5`, `lh = 4`, `lq = lf = 10`, `Dom::Ht` 9, `Dom::S` 9 + 5). -/
def algShapeW16Rung (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) : AlgShape P :=
  algShapeStd P (ZK60.Exec.Slot.W16R2.draws shRungW16) mpad 5 4 10 10 9 5
    (by rw [hdr]; decide) (hostLay_w16 shRungW16) hm0 hm78 (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by decide)

/-- **The R13 rung's shape facts** (the same block geometry as the W16R2 rung). -/
def algShapeR13Rung (P : BlockParams) (hdr : P.draws = R13.rungDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts, segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shRungR13 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) : AlgShape P :=
  algShapeStd P (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shRungR13) mpad 5 4 10 10 9 5
    (by rw [hdr]; decide) (hostLay_r13 _) hm0 hm78 (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by decide)

/-- **The Shieldstral T128 R13 block's shape facts** (`lt = 7`, `lh = 5`, `lq = 12`, `lf = 14`, `Dom::Ht` 12,
`Dom::S` 12 + 7). -/
def algShapeR13Shield (P : BlockParams) (hdr : P.draws = R13.shieldDraws) (mpad : ℕ → ℕ)
    (hm0 : ∀ k ∈ algHosts,
      segLn (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shShieldR13 k) .zeta = 0 → mpad k = 0)
    (hm78 : ∀ k ∈ algHosts, mpad k ≤ 78) : AlgShape P :=
  algShapeStd P (ZK60.Exec.Slot.R13.draws ZK60.Exec.Slot.R13.shShieldR13) mpad 7 5 12 14 12 7
    (by rw [hdr]; decide) (hostLay_r13 _) hm0 hm78 (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide) (by rw [hdr]; decide)
    (by rw [hdr]; decide) (by decide)

/-! ## The block's lookup counts over the padded cubes -/

/-- **The looked-up tuples of one block**: for each LogUp domain, its lookups per cube position (`per`) times its
`2^log` positions (the LogUp arm is not gated: it runs over the padded cube). -/
def lkCount (sh : ShapeW) (per : Dom → ℕ) : ℕ :=
  2 ^ sh.logs .L * per .L + 2 ^ sh.logs .D * per .D + 2 ^ sh.logs .Q * per .Q + 2 ^ sh.logs .Kv * per .Kv
    + 2 ^ sh.logs .S * per .S + 2 ^ sh.logs .F * per .F

/-- W16R2's lookups per position at the rung (L17's shape corpus, `LOOKUPS L:2,D:19,F:7,Q:6,Kv:6,S:9`). -/
def perW16Rung : Dom → ℕ
  | .L => 2 | .D => 19 | .Q => 6 | .Kv => 6 | .S => 9 | .F => 7 | _ => 0

/-- R13's lookups per position at the rung (`LOOKUPS L:2,D:34,F:14,Q:14,Kv:14,S:17`). -/
def perR13Rung : Dom → ℕ
  | .L => 2 | .D => 34 | .Q => 14 | .Kv => 14 | .S => 17 | .F => 14 | _ => 0

/-- R13's lookups per position at Shieldstral T128 (`LOOKUPS L:2,D:34,F:14,Q:14,Kv:14,S:15`). -/
def perR13Shield : Dom → ℕ
  | .L => 2 | .D => 34 | .Q => 14 | .Kv => 14 | .S => 15 | .F => 14 | _ => 0

/-- The W16R2 rung block looks up `1,015,808` tuples. -/
theorem lkCount_w16r2_rung : lkCount shRungW16 perW16Rung = 1015808 := by decide

/-- The R13 rung block looks up `2,015,232` tuples. -/
theorem lkCount_r13_rung : lkCount ZK60.Exec.Slot.R13.shRungR13 perR13Rung = 2015232 := by decide

/-- **The Shieldstral T128 R13 block looks up `64,258,048` tuples** (D54's 64.3 M words). -/
theorem lkCount_r13_shield : lkCount ZK60.Exec.Slot.R13.shShieldR13 perR13Shield = 64258048 := by decide

/-- **Finding L36-1**: the Shieldstral T128 R13 block's lookups exceed the bound `35,153,256` of the block
statements' premise `he` (the 8B T128 W16R2 count), and are within `2^26` (the bound the run-level chain uses). -/
theorem lkCount_r13_shield_gt : 35153256 < lkCount ZK60.Exec.Slot.R13.shShieldR13 perR13Shield
    ∧ lkCount ZK60.Exec.Slot.R13.shShieldR13 perR13Shield ≤ 2 ^ 26 := by
  rw [lkCount_r13_shield]
  norm_num

end ZK60.Exec.Block
