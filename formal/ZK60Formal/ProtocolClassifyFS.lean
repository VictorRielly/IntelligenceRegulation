/-
D63 lane L18 (2026-11-07), part 2: **the classify run's Fiat–Shamir schedule** — stage IN-C, the `L` blocks and stage
OUT-C as ONE schedule of sub-protocols on the run's one transcript (L8's `fs_code_chain_sound_sched`,
`ExecComposeFS.lean`), the per-block error a PARAMETER (W16R2 or R13).

The run (`verify_classify_run_with`) is one transcript: the run header, stage IN-C's segment, the `L` blocks' segments
(each with its framing absorbs `pb-run-stage`, `pb-run-block`, `B_{k+1}`'s root, then the block's core, then the
boundary opening of `B_k`), stage OUT-C's segment. Each part runs sub-protocols on that one transcript (sumcheck slots,
LogUp challenges, `M`, the openings); the D12a frame puts every part's items after the earlier parts' items, so the
run's schedule is the concatenation of the parts' schedules, each window at its absolute position.

What is proved:
* `runSched`, `mem_runSched`: the run's schedule `IN-C ++ block 0 ++ … ++ block (L − 1) ++ OUT-C`;
* **`classify_run_fs_sound_sched`**: if stage IN-C's sub-protocols are round-by-round sound with errors `≤ εin`, every
  block's with errors `≤ εblk` (the block profile's, a parameter), stage OUT-C's with errors `≤ εout`, and releases go
  forward only (`hframe`), then a prover making `q` hash queries gets SOME part's sub-protocol to enter its window with
  a false claim and yet EVERY sub-protocol of the WHOLE RUN to end alive with probability at most
  `T·max(εin, εblk, εout) + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`: the largest error, no factor `L + 2`;
* `hframe_of_noRelease`: a schedule that releases nothing meets `hframe`;
* `runSlots`, `slotsLen_append`, `slotsLen_runSlots_le`: the run's sumcheck slots (IN-C's, every block's, OUT-C's) as ONE
  run of slots;
* **`classify_run_sumchecks_fs_sound`**: L8's `exec_sumchecks_fs_sound` on the run's slots: a false claim in ANY slot of
  ANY part passes every slot's executable `sumcheck::verify` with probability at most the bound of ONE slot of the
  largest degree at the run's `T` (L9's `block_sumchecks_fs_sound` and L15's `stage_sumchecks_fs_sound` are the same
  bound for one part at its own `T`);
* **`classify_run_sumchecks_fs_sound_le`**: with every degree `≤ 7` (W16R2 blocks reach 5, L9-5; OUT-C 5) and
  `T ≤ 2^64 + 2^20`: at most `2^-61` for the whole run (L9's `block_bound_le`);
* **`sched_le_target`**: the scheduled bound meets the approved `εsTarget q = q·2^-100 + 2^-100` once the largest
  per-step error is `≤ 2^-103` and `q ≥ ℓ + 1` (finding L18-2: below that the query-free part `ℓ·εmax` of the
  code-chain composition can exceed `2^-100`; the path-wise count of D66(4) is what removes it).

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.ExecBlockFS
import ZK60Formal.StageFS

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The run's schedule of sub-protocols -/

section Sched

variable {D : Type}

/-- **The classify run's schedule on its one transcript**: stage IN-C's sub-protocols, then block `0`'s, …, block
`L − 1`'s, then stage OUT-C's (the D12a order), each at its window's absolute position on the run's chain. -/
def runSched (cin : List (CSub D)) (cblk : ℕ → List (CSub D)) (L : ℕ) (cout : List (CSub D)) : List (CSub D) :=
  cin ++ (List.range L).flatMap cblk ++ cout

theorem mem_runSched {cin : List (CSub D)} {cblk : ℕ → List (CSub D)} {L : ℕ} {cout : List (CSub D)} {c : CSub D} :
    c ∈ runSched cin cblk L cout ↔ c ∈ cin ∨ (∃ k, k < L ∧ c ∈ cblk k) ∨ c ∈ cout := by
  simp only [runSched, List.mem_append, List.mem_flatMap, List.mem_range, or_assoc]

/-- **A schedule that releases nothing meets `hframe`** (every slot keeps its terminal check in its state, L8-4). -/
theorem hframe_of_noRelease (W : UInt64 → ℕ) (cs : List (CSub D)) (hrel : ∀ c ∈ cs, ∀ τ, ¬ c.rel τ) :
    ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      cs[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h → ds.length = ks.length + 1 →
      ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) → ∃ k' c', k < k' ∧ cs[k']? = some c' ∧ ¬ subSt W c' τ := by
  intro k c τ h ks ds hc _ _ _ _ hr
  exact absurd hr (hrel c (List.mem_of_getElem? hc) _)

variable [Fintype D] [Nonempty D] [DecidableEq D] {It' Q : Type} [Fintype Q] [DecidableEq Q]

/-- **Fiat–Shamir soundness of the WHOLE classify run's schedule** (D63, lane L18), on the code's own chain. The run's
sub-protocols are stage IN-C's (`cin`), block `k`'s (`cblk k`, the block profile's: W16R2 or R13) and stage OUT-C's
(`cout`), at their absolute windows. With every part's sub-protocols round-by-round sound (`RbrWide`) with errors at
most `εin`, `εblk`, `εout`, and releases handed only forward (`hframe`, on the run's schedule), a prover making at most
`q` queries gets SOME sub-protocol of SOME part to enter its window with a false claim (not released) and yet EVERY
sub-protocol of the run to end alive with probability at most `T·max(εin, εblk, εout) + collBound T + collBound (T + 1)`,
`T = q + ℓ + 1`: the per-query rate is the LARGEST part error, with no factor of the `L + 2` parts. -/
theorem classify_run_fs_sound_sched (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (cin : List (CSub D))
    (cblk : ℕ → List (CSub D)) (L : ℕ) (cout : List (CSub D)) (εin εblk εout : ℝ≥0∞)
    (hin : ∀ c ∈ cin, RbrWide c.R.n c.R.w c.St c.ε ∧ c.ε ≤ εin)
    (hblk : ∀ k, k < L → ∀ c ∈ cblk k, RbrWide c.R.n c.R.w c.St c.ε ∧ c.ε ≤ εblk)
    (hout : ∀ c ∈ cout, RbrWide c.R.n c.R.w c.St c.ε ∧ c.ε ≤ εout)
    (hframe : ∀ (k : ℕ) (c : CSub D) (τ : List (TItem × D)) (h : TItem) (ks : List UInt64) (ds : List D),
      (runSched cin cblk L cout)[k]? = some c → tRem W τ = some 0 → ks.length + 1 = tWd W h →
      ds.length = ks.length + 1 → ¬ subSt W c τ → c.rel (τ ++ stE h ks ds) →
        ∃ k' c', k < k' ∧ (runSched cin cblk L cout)[k']? = some c' ∧ ¬ subSt W c' τ)
    (C : ChainEnc It' Q D) (toT : It' → TItem) (S : Steps It') (hS : StepsOK W toT S)
    {α : Type} (heads : α → List It') (ℓ : ℕ) (hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ)
    (q : ℕ) (A : OC Q D α) (hA : A.Bounded q) :
    prH (fun H => (∃ (k : ℕ) (c : CSub D), (runSched cin cblk L cout)[k]? = some c
          ∧ c.a ≤ (cChain C toT S H (heads (A.run H))).length
          ∧ tRem W ((cChain C toT S H (heads (A.run H))).take c.a) = some 0
          ∧ ¬ c.St ((cChain C toT S H (heads (A.run H))).take c.a) []
          ∧ ¬ c.rel ((cChain C toT S H (heads (A.run H))).take c.a))
        ∧ allSt W (runSched cin cblk L cout) (cChain C toT S H (heads (A.run H))))
      ≤ ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * max εin (max εblk εout) + collBound (q + ℓ + 1) D
        + collBound (q + ℓ + 1 + 1) D := by
  have hR : ∀ c ∈ runSched cin cblk L cout, RbrWide c.R.n c.R.w c.St c.ε := by
    intro c hc
    rcases mem_runSched.mp hc with h | ⟨k, hk, h⟩ | h
    · exact (hin c h).1
    · exact (hblk k hk c h).1
    · exact (hout c h).1
  have hε : ∀ c ∈ runSched cin cblk L cout, c.ε ≤ max εin (max εblk εout) := by
    intro c hc
    rcases mem_runSched.mp hc with h | ⟨k, hk, h⟩ | h
    · exact (hin c h).2.trans (le_max_left _ _)
    · exact (hblk k hk c h).2.trans ((le_max_left _ _).trans (le_max_right _ _))
    · exact (hout c h).2.trans ((le_max_right _ _).trans (le_max_right _ _))
  exact fs_code_chain_sound_sched W hW (runSched cin cblk L cout) _ hR hε hframe C toT S hS heads ℓ hℓ q A hA

end Sched

/-! ## The run's sumcheck slots as ONE run of slots -/

section Slots

variable {K : Type} [Field K] [Algebra GF K]

/-- **The classify run's sumcheck slots**: stage IN-C's, every block's (the block profile's), stage OUT-C's, in the
run's order, as one run of L8 `Slot`s on the run's one transcript (each slot's `s` its interstitial operations since
the previous slot's rounds: for a part's first slot, the earlier part's openings and the run's framing included; its
statement read off the run's trace before its rounds). -/
def runSlots (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (L : ℕ) (sout : List (Slot K)) : List (Slot K) :=
  sin ++ (List.range L).flatMap sblk ++ sout

omit [Field K] [Algebra GF K] in
theorem slotsLen_append (a b : List (Slot K)) : slotsLen (a ++ b) = slotsLen a + slotsLen b := by
  simp [slotsLen, List.map_append, List.sum_append]

omit [Field K] [Algebra GF K] in
theorem slotsLen_flatMap_le (f : ℕ → List (Slot K)) (b : ℕ) (hb : ∀ k, slotsLen (f k) ≤ b) :
    ∀ L, slotsLen ((List.range L).flatMap f) ≤ L * b
  | 0 => by simp [slotsLen]
  | L + 1 => by
    rw [List.range_succ, List.flatMap_append, slotsLen_append]
    have h1 := slotsLen_flatMap_le f b hb L
    have h2 : slotsLen ([L].flatMap f) ≤ b := by
      simpa [List.flatMap_cons, List.flatMap_nil, List.append_nil] using hb L
    calc slotsLen ((List.range L).flatMap f) + slotsLen ([L].flatMap f) ≤ L * b + b := Nat.add_le_add h1 h2
      _ = (L + 1) * b := by ring

omit [Field K] [Algebra GF K] in
/-- **The run's item count from its parts'**: at most `a + L·b + c` when stage IN-C's slots have at most `a` items,
every block's at most `b` and stage OUT-C's at most `c`. -/
theorem slotsLen_runSlots_le (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (L : ℕ) (sout : List (Slot K))
    (a b c : ℕ) (ha : slotsLen sin ≤ a) (hb : ∀ k, slotsLen (sblk k) ≤ b) (hc : slotsLen sout ≤ c) :
    slotsLen (runSlots sin sblk L sout) ≤ a + L * b + c := by
  unfold runSlots
  rw [slotsLen_append, slotsLen_append]
  exact Nat.add_le_add (Nat.add_le_add ha (slotsLen_flatMap_le sblk b hb L)) hc

omit [Field K] [Algebra GF K] in
/-- The run's slot facts from the parts': degrees `≥ 1`, below `p`, at most the parts' largest, and each round's hash
input within `Lq` bytes. -/
theorem runSlots_facts (Lq : ℕ) (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (L : ℕ) (sout : List (Slot K))
    (dmax : ℕ) (hdp : dmax < gP)
    (hsl : ∀ sl, (sl ∈ sin ∨ (∃ k, k < L ∧ sl ∈ sblk k) ∨ sl ∈ sout) →
      1 ≤ sl.d ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ Lq) :
    ∀ sl ∈ runSlots sin sblk L sout, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ Lq := by
  intro sl hsl'
  have hm : sl ∈ sin ∨ (∃ k, k < L ∧ sl ∈ sblk k) ∨ sl ∈ sout := by
    simpa only [runSlots, List.mem_append, List.mem_flatMap, List.mem_range, or_assoc] using hsl'
  obtain ⟨h1, h2, h3⟩ := hsl sl hm
  exact ⟨h1, lt_of_le_of_lt h2 hdp, h2, h3⟩

/-- **Fiat–Shamir soundness of the WHOLE classify run's sumcheck slots** (D63, lane L18): L8's
`exec_sumchecks_fs_sound` on the run's slots (IN-C's, every block's, OUT-C's) on ONE transcript. A false claimed sum in
ANY slot of ANY part passes every slot's executable `sumcheck::verify` (with its terminal check) with probability at
most `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ` the run's items, `dmax` the
largest degree of any part (the block profile's degree a parameter): the bound of ONE slot. -/
theorem classify_run_sumchecks_fs_sound [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (Lq : ℕ) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (L : ℕ) (sout : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ runSlots sin sblk L sout, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ Lq)
    (q : ℕ) (A : OC (QB Lq) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q) :
    prH (fun G : QB Lq → Dig => SlotsWin U key domain Lq (runSlots sin sblk L sout) G (A.run G))
      ≤ (((q + slotsLen (runSlots sin sblk L sout) + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + slotsLen (runSlots sin sblk L sout) + 1) Dig
        + collBound (q + slotsLen (runSlots sin sblk L sout) + 1 + 1) Dig :=
  exec_sumchecks_fs_sound U hU hK2 key domain hs Lq hL hL64 _ dmax hsl q A hA

/-- **The whole run's sumcheck bound, numerically**: with every slot's degree at most `dmax ≤ 7` and
`T = q + ℓ + 1 ≤ 2^64 + 2^20` (e.g. `q ≤ 2^64` and a run of under a million slot items: 26 blocks of a few thousand
items each and the two stages), a false claim in ANY slot of the classify run passes with probability at most `2^-61`:
the bound of one block's slots (L9's `rung_block_fs_sound`), not `L + 2` times it. -/
theorem classify_run_sumchecks_fs_sound_le [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (Lq : ℕ) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (L : ℕ) (sout : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ runSlots sin sblk L sout, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ Lq)
    (q : ℕ) (A : OC (QB Lq) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q)
    (hd7 : dmax ≤ 7) (hT : q + slotsLen (runSlots sin sblk L sout) + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB Lq → Dig => SlotsWin U key domain Lq (runSlots sin sblk L sout) G (A.run G))
      ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (classify_run_sumchecks_fs_sound U hU hK2 key domain hs Lq hL hL64 sin sblk L sout dmax hsl q A hA).trans ?_
  rw [hF]
  exact ZK60.Exec.Block.block_bound_le gP _ dmax (by norm_num [gP]) (by norm_num [gP]) hT hd7

end Slots

/-! ## The scheduled bound against the approved soundness target -/

section Target

/-- **The scheduled bound meets the approved target** `εsTarget q = q·2^-100 + 2^-100` when the largest per-step error
is at most `2^-103` and the prover's queries are at least the verifier's items (`q ≥ ℓ + 1`), for `T ≤ 2^76`. The
first condition holds at W16R2's parameters for every sub-protocol but `M`'s column round (`2^-106.4`, L10) and LogUp's
`α` round (about `2^-103` to `2^-108`, FSPathBlock's `εLU8B`); the second is finding L18-2: for `q < ℓ` the
query-free part `ℓ·εmax` of the code-chain composition is above `2^-100` once `ℓ·εmax > 2^-100` (at `ℓ ≈ 2^16` items
and `εmax ≈ 2^-106`, about `2^-90`), and only the path-wise count of D66(4) (one block zone, FSPathBlock.lean, on the
MODEL chain today) brings the query-free part under `2^-100`. -/
theorem sched_le_target (q ℓ : ℕ) (ε : ℝ≥0∞) (hε : ε ≤ (2⁻¹ : ℝ≥0∞) ^ 103) (hq : ℓ + 1 ≤ q)
    (hT : q + ℓ + 1 + 1 ≤ 2 ^ 76) :
    ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε + collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ εsTarget q := by
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 256 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
    norm_num
  have hcoll : ∀ t : ℕ, t ≤ 2 ^ 76 → collBound t Dig ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) := by
    intro t ht
    unfold collBound
    rw [hcard]
    refine natCast_div_le_div (by positivity) (by positivity) ?_
    calc t * (t - 1) / 2 * 2 ^ 104 ≤ t * t * 2 ^ 104 :=
          Nat.mul_le_mul_right _ ((Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _)))
      _ ≤ 2 ^ 76 * 2 ^ 76 * 2 ^ 104 := Nat.mul_le_mul_right _ (Nat.mul_le_mul ht ht)
      _ = 1 * 2 ^ 256 := by norm_num
  have hlin : ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 102 := by
    calc ((q + ℓ + 1 : ℕ) : ℝ≥0∞) * ε ≤ ((2 * q : ℕ) : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 103 :=
          mul_le_mul' (by exact_mod_cast (by omega : q + ℓ + 1 ≤ 2 * q)) hε
      _ = (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 102 := by
          rw [pow_succ, Nat.cast_mul, Nat.cast_ofNat]
          calc (2 : ℝ≥0∞) * (q : ℝ≥0∞) * ((2⁻¹ : ℝ≥0∞) ^ 102 * 2⁻¹)
              = (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 102 * (2 * 2⁻¹) := by ring
            _ = (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 102 := by
                rw [ENNReal.mul_inv_cancel two_ne_zero ENNReal.ofNat_ne_top, mul_one]
  have h102 : (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 102 ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 100 :=
    mul_le_mul' le_rfl (pow_le_pow_right_of_le_one' (by norm_num) (by norm_num))
  have hc2 : collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig ≤ (2⁻¹ : ℝ≥0∞) ^ 100 := by
    calc collBound (q + ℓ + 1) Dig + collBound (q + ℓ + 1 + 1) Dig
        ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) :=
          add_le_add (hcoll _ (by omega)) (hcoll _ hT)
      _ = ((2 : ℕ) : ℝ≥0∞) / ((2 ^ 104 : ℕ) : ℝ≥0∞) := by rw [ENNReal.div_add_div_same]; norm_num
      _ ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 100 : ℕ) : ℝ≥0∞) := natCast_div_le_div (by positivity) (by positivity) (by norm_num)
      _ = (2⁻¹ : ℝ≥0∞) ^ 100 := (inv_two_pow_eq 100).symm
  rw [εsTarget, add_assoc]
  exact add_le_add (hlin.trans h102) hc2

end Target

end ZK60.ProtocolClassify
