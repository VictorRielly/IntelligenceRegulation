/-
D63 lane L28 (2026-11-07, resumed 2026-11-09), part 4: **the concrete chain of a block verifier, its step parse, the
openings' extractions, and the two deterministic links `hexec` and `hsem`, at a regular opening's geometry** (L22 §5
item 3, the instance half).

A regular opening's geometry is `(h, Q, e)`: the codeword length `2^h` (the coset `7·G_{2^h}`), the `Q` queries and
pads, the decoding radius `e`, with `n = 2^14` message columns and `2e + (2^14 + Q) ≤ 2^h`. W16R2 is `(15, 280, 8052)`,
R13 (the media app's profile) `(16, 256, 24448)`. `M` is the same at both.

For a block profile (`OProf`: the tag keys, `M`'s spec count, `A`'s and `H`'s rows and claim counts, the header's length
and squeeze count, the index squeezes `mI`, the step-parse bounds), the objects L20's chain theorems take:

* `OProf.cM`, `OProf.ns`, `OProf.W`, `W_pos`, `W_le`, **`W_at`**, `W_lt`, `W_r0` .. `W_r6`: the step parse `wRuns` of the
  wide runs (`M`'s `θ`, `2S + 2` row coefficients and `64` indices; each opening's `#claims + rows` batching squeezes and
  `mI` indices), fixed by the counter at `M`'s window, `hdrSq + 3 + shapeSq` (L22-1);
* `vS`, `GoodO`, `heads`, **`heads_len`**, **`heads_hd`**: the heads of the verifier's steps on an output of the
  shape (else none), at most `2^20` items, the first `hdrLen + 8` single;
* `stpOK_mStps`, `stpOK_pcsStps`, **`stpOK_vS`**, `vS_trace`, `mem_vS_ops`, `vS_ops_length`: the parse of the whole run
  under that step rule, and the run's trace split at `M`'s, `A`'s and `H`'s windows;
* `mStps_fit`, `pcsStps_fit`: the openings' operations fit `L ≥ 2^20`;
* `colsM`, `UxW`, `colX_opened`: the extracted `M` table and `A` / `H` matrices (L22's `colX` at the roots' positions
  `hdrLen + 3`, `hdrLen`, `hdrLen + 7`);
* **the kinds** (the per-kind pieces lane L27 composes): `GMW`, `EvMW`, **`evMW_bound`** (`M`); `ptsG`, `encG`, `GOW`,
  `EvOW`, **`evOW_bound`** (a regular opening, any geometry): L20's `mask_knowledge_chain_pos` and
  `opening_knowledge_chain_pos` at the concrete chain, heads, step rule and extraction;
* `pcsOk_named`, `pcs_tr_after`: `PcsOk` with the parameters' numbers named, and the transcript after an opening;
* **`mask_alt`**, **`opening_alt`**: on an accepted opening, its good predicate or its chain event;
* `RunAcc`, **`run_acc`**: what an accepted run with the profile's header gives (the chain IS the verifier's trace,
  split at the windows; the three accepted checks; the counters; the parse at the windows);
* **`hexec_geo`**: `hexec` (L20-3) on `BlockAcc` with the profile's header squeeze count, outside the extraction
  failure;
* **`hsem_geo`**: `hsem` for the block's own part `OpenBlk` (L22-5);
* **`open_cover_geo`**: the two as one inclusion of events, `BlockAcc ∧ header ∧ ¬OpenBlk ⊆ EvM ∪ EvA ∪ EvH ∪ EvX`
  (the per-kind form a run-level count needs, L24-7).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Head
import ZK60Formal.ExtractInstW16
import ZK60Formal.LinkW16Glue

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The profile and its step parse -/

/-- **A block profile's opening data** (L22-1, L22-2): the tag keys, `M`'s mask-spec count, `A`'s and `H`'s row counts,
the number of claims each opening checks (`H`'s with its LogUp sum claim), the header's length and squeeze count (the
run's, fixed by the verifier), the index squeezes of a regular opening, and the bounds the step parse needs. -/
structure OProf (P : Block.BlockParams) where
  tag : MTag
  S : ℕ
  rA : ℕ
  rH : ℕ
  nA : ℕ
  nH : ℕ
  hdrLen : ℕ
  hdrSq : ℕ
  mI : ℕ
  hwA : 0 < nA + rA
  hwH : 0 < nH + rH
  hmI : 0 < mI
  hwA' : nA + rA ≤ 2 ^ 61
  hwH' : nH + rH ≤ 2 ^ 61
  hmI' : mI ≤ 2 ^ 20
  hS : 2 * S + 2 ≤ 2 ^ 20
  hlen : hdrLen + 10 + shapeLen P 0 P.geom.slots + (2 * S + 69) + (nA + rA + P.geom.aGroups + 1 + mI)
    + (nH + rH + P.geom.hGroups + 1 + mI) ≤ 2 ^ 20
  hsq : hdrSq + 3 + shapeSq P 0 P.geom.slots + (2 * S + 67) + (nA + rA) + mI + (nH + rH) + mI < 2 ^ 64

namespace OProf

variable {P : Block.BlockParams} (pr : OProf P)

/-- The counter at `M`'s window. -/
def cM : ℕ := pr.hdrSq + 3 + shapeSq P 0 P.geom.slots

/-- The wide runs' widths, from `M`'s window on. -/
def ns : List ℕ := [1, 2 * pr.S + 2, 64, pr.nA + pr.rA, pr.mI, pr.nH + pr.rH, pr.mI]

/-- **The step parse**: `wRuns` of the wide runs from `M`'s window counter. -/
def W : UInt64 → ℕ := fun k => wRuns pr.cM pr.ns k.toNat

theorem ns_pos : ∀ n ∈ pr.ns, 0 < n := by
  have h1 := pr.hwA
  have h2 := pr.hwH
  have h3 := pr.hmI
  intro n hn
  simp only [ns, List.mem_cons, List.mem_nil_iff, or_false] at hn
  rcases hn with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> omega

theorem W_pos : ∀ k, 0 < pr.W k := fun _ => wRuns_pos _ _ pr.ns_pos _

theorem W_le : ∀ k, pr.W k ≤ 2 ^ 64 := by
  have h1 := pr.hwA'
  have h2 := pr.hwH'
  have h3 := pr.hmI'
  have h4 := pr.hS
  refine fun k => wRuns_le _ _ _ (by norm_num) (fun n hn => ?_) _
  simp only [ns, List.mem_cons, List.mem_nil_iff, or_false] at hn
  rcases hn with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> omega

/-- The widths at the runs' first counters. -/
theorem W_at (i : ℕ) (hi : i < 7) (k : ℕ) (hk : k = pr.cM + (pr.ns.take i).sum) (hk64 : k < 2 ^ 64) :
    pr.W (UInt64.ofNat k) = pr.ns.getD i 1 := by
  unfold W
  rw [u64_ofNat_toNat hk64, hk]
  exact wRuns_at _ _ pr.ns_pos i (by simp [ns]; omega)

/-- Before `M`'s window every width is `1`. -/
theorem W_lt (k : ℕ) (hk : k < pr.cM) : pr.W (UInt64.ofNat k) = 1 := by
  have h := pr.hsq
  unfold W
  rw [u64_ofNat_toNat (by unfold cM at hk; omega)]
  exact wRuns_lt _ _ pr.ns_pos k hk

/-- The width at `M`'s `θ` squeeze. -/
theorem W_r0 (k : ℕ) (hk : k = pr.cM) : pr.W (UInt64.ofNat k) = 1 := by
  have h := pr.hsq
  have e : (pr.ns.take 0).sum = 0 := rfl
  exact pr.W_at 0 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `M`'s row coefficients. -/
theorem W_r1 (k : ℕ) (hk : k = pr.cM + 1) : pr.W (UInt64.ofNat k) = 2 * pr.S + 2 := by
  have h := pr.hsq
  have e : (pr.ns.take 1).sum = 1 + 0 := rfl
  exact pr.W_at 1 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `M`'s indices. -/
theorem W_r2 (k : ℕ) (hk : k = pr.cM + (2 * pr.S + 3)) : pr.W (UInt64.ofNat k) = 64 := by
  have h := pr.hsq
  have e : (pr.ns.take 2).sum = 1 + (2 * pr.S + 2 + 0) := rfl
  exact pr.W_at 2 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `A`'s batching run. -/
theorem W_r3 (k : ℕ) (hk : k = pr.cM + (2 * pr.S + 67)) : pr.W (UInt64.ofNat k) = pr.nA + pr.rA := by
  have h := pr.hsq
  have e : (pr.ns.take 3).sum = 1 + (2 * pr.S + 2 + (64 + 0)) := rfl
  exact pr.W_at 3 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `A`'s indices. -/
theorem W_r4 (k : ℕ) (hk : k = pr.cM + (2 * pr.S + 67) + (pr.nA + pr.rA)) : pr.W (UInt64.ofNat k) = pr.mI := by
  have h := pr.hsq
  have e : (pr.ns.take 4).sum = 1 + (2 * pr.S + 2 + (64 + (pr.nA + pr.rA + 0))) := rfl
  exact pr.W_at 4 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `H`'s batching run. -/
theorem W_r5 (k : ℕ) (hk : k = pr.cM + (2 * pr.S + 67) + (pr.nA + pr.rA) + pr.mI) :
    pr.W (UInt64.ofNat k) = pr.nH + pr.rH := by
  have h := pr.hsq
  have e : (pr.ns.take 5).sum = 1 + (2 * pr.S + 2 + (64 + (pr.nA + pr.rA + (pr.mI + 0)))) := rfl
  exact pr.W_at 5 (by norm_num) k (by omega) (by unfold cM at hk; omega)

/-- The width at `H`'s indices. -/
theorem W_r6 (k : ℕ) (hk : k = pr.cM + (2 * pr.S + 67) + (pr.nA + pr.rA) + pr.mI + (pr.nH + pr.rH)) :
    pr.W (UInt64.ofNat k) = pr.mI := by
  have h := pr.hsq
  have e : (pr.ns.take 6).sum = 1 + (2 * pr.S + 2 + (64 + (pr.nA + pr.rA + (pr.mI + (pr.nH + pr.rH + 0))))) := rfl
  exact pr.W_at 6 (by norm_num) k (by omega) (by unfold cM at hk; omega)

end OProf

section Parse

variable {P : Block.BlockParams} (pr : OProf P) (L : ℕ)

/-- The verifier's steps on an output (`vStps` with the profile's widths). -/
def vS (o : List Op × Block.Core) : List Stp :=
  vStps P pr.S (pr.nA + pr.rA) (pr.nH + pr.rH) pr.mI o.1 o.2

/-- **An output of the profile's shape**: its header has the profile's length and squeeze count, the parse is the
profile's, every operation fits `L`, at most `2^20` operations. -/
def GoodO (o : List Op × Block.Core) : Prop :=
  o.1.length = pr.hdrLen ∧ sqN o.1 = pr.hdrSq ∧ StpOK pr.W 0 (vS pr o) ∧ (∀ op ∈ stpsOps (vS pr o), op.len ≤ L)
    ∧ (stpsOps (vS pr o)).length ≤ 2 ^ 20

/-- **The chain's heads**: the verifier's step heads on an output of the shape, else none. -/
noncomputable def heads (o : List Op × Block.Core) : List (ItB L) :=
  haveI := Classical.propDecidable (GoodO pr L o)
  if GoodO pr L o then liftItems L (stpHeads 0 (vS pr o)) else []

/-- The chain's steps. -/
noncomputable def stB : Steps (ItB L) := stepsB L pr.W pr.W_pos pr.W_le

theorem heads_good (o : List Op × Block.Core) (h : GoodO pr L o) :
    heads pr L o = liftItems L (stpHeads 0 (vS pr o)) := by
  unfold heads
  exact ite_eq_left h

theorem heads_fit (hL64 : L < 2 ^ 64) (o : List Op × Block.Core) (h : GoodO pr L o) :
    ∀ it ∈ stpHeads 0 (vS pr o), it.Ok ∧ it.len ≤ L :=
  fun it hit => opItems_fit L hL64 0 _ h.2.2.2.1 it (stpHeads_mem pr.W 0 _ h.2.2.1 it hit)

/-- **At most `2^20` chain items** on every output (`hℓ` of L20's chain theorems). -/
theorem heads_len (hL64 : L < 2 ^ 64) (o : List Op × Block.Core) :
    ((heads pr L o).flatMap (stB pr L).items).length ≤ 2 ^ 20 := by
  by_cases h : GoodO pr L o
  · rw [heads_good pr L o h]
    have e := flatMap_stpHeads L pr.W pr.W_pos pr.W_le 0 _ h.2.2.1 (heads_fit pr L hL64 o h)
    have hl := congrArg List.length e
    rw [List.length_map, opItems_length] at hl
    unfold stB
    rw [hl]
    exact h.2.2.2.2
  · unfold heads
    rw [ite_eq_right h]
    simp

theorem vS_eq (o : List Op × Block.Core) :
    vS pr o = opsStps (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots)
      ++ (mStps pr.S o.2.maskOpen ++ (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen
        ++ pcsStps (pr.nH + pr.rH) pr.mI o.2.hOpen)) := by
  simp only [vS, vStps, List.append_assoc]

/-- **The first `hdrLen + 8` heads are single items** on every output (`hhd` of L20's chain theorems). -/
theorem heads_hd (hL64 : L < 2 ^ 64) (o : List Op × Block.Core) :
    (((heads pr L o).take (pr.hdrLen + 8)).flatMap (stB pr L).items).length ≤ pr.hdrLen + 8 := by
  by_cases h : GoodO pr L o
  · rw [heads_good pr L o h]
    have hok := h.2.2.1
    have hft := heads_fit pr L hL64 o h
    rw [vS_eq] at hok hft
    rw [vS_eq]
    unfold stB
    exact (heads_single L pr.W pr.W_pos pr.W_le _ _ 0 (pr.hdrLen + 8) (by
      simp only [List.length_append, h.1, rootOps_length]; omega) hok hft).le
  · unfold heads
    rw [ite_eq_right h]
    simp

/-- `M`'s steps parse when the widths at `M`'s three runs are the profile's. -/
theorem stpOK_mStps (W : UInt64 → ℕ) (S c : ℕ) (mo : Block.MaskOpening) (h1 : W (UInt64.ofNat c) = 1)
    (h2 : W (UInt64.ofNat (c + 1)) = 2 * S + 2) (h3 : W (UInt64.ofNat (c + 1 + (2 * S + 2))) = 64) :
    StpOK W (UInt64.ofNat c) (mStps S mo) := by
  unfold mStps
  refine StpOK.append W _ _ _ ⟨h1, Nat.one_pos, ?_, by omega, trivial⟩ ?_
  · rw [u64_ofNat_add]
    exact h2
  · rw [stpsSq_mPre, u64_ofNat_add, show c + (2 * S + 3) = c + 1 + (2 * S + 2) by omega]
    exact ⟨h3, by norm_num, trivial⟩

/-- An opening's steps parse when the widths at its two runs are `w0` and `m`. -/
theorem stpOK_pcsStps (W : UInt64 → ℕ) (c w0 m : ℕ) (o : Block.OpeningZk) (h1 : W (UInt64.ofNat c) = w0)
    (hw0 : 0 < w0) (h2 : W (UInt64.ofNat (c + w0)) = m) (hm : 0 < m) :
    StpOK W (UInt64.ofNat c) (pcsStps w0 m o) := by
  unfold pcsStps
  refine StpOK.append W _ _ _ ⟨h1, hw0, stpOK_vecStps W _ o.groupVecs _ trivial⟩ ?_
  rw [stpsSq_pcsPre, u64_ofNat_add]
  exact ⟨h2, hm, trivial⟩

theorem u64_zero_add (n : ℕ) : (0 : UInt64) + UInt64.ofNat n = UInt64.ofNat n := by
  apply UInt64.toNat_inj.1
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat', UInt64.toNat_zero]
  omega

/-- **The whole run parses** under the profile's step rule, on an output whose header has the profile's squeeze count
and whose slots have the shape's. -/
theorem stpOK_vS (o : List Op × Block.Core) (hsq : sqN o.1 = pr.hdrSq)
    (hsh : fullSq P 0 o.2.slots = shapeSq P 0 P.geom.slots) : StpOK pr.W 0 (vS pr o) := by
  have h64 := pr.hsq
  have hX : sqN (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots) = pr.cM := by
    rw [sqN_append, sqN_append, rootOps_sq, fullOps_sq, hsq, hsh]
    rfl
  rw [vS_eq]
  have hc0 : StpOK pr.W (UInt64.ofNat 0) (opsStps (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots)) :=
    stpOK_opsStps pr.W 0 _ (fun j hj => by rw [Nat.zero_add]; exact pr.W_lt j (by omega))
  refine StpOK.append pr.W 0 _ _ hc0 ?_
  rw [stpsSq_opsStps, hX, u64_zero_add]
  have hM : StpOK pr.W (UInt64.ofNat pr.cM) (mStps pr.S o.2.maskOpen) :=
    stpOK_mStps pr.W pr.S pr.cM _ (pr.W_r0 _ rfl) (pr.W_r1 _ rfl) (pr.W_r2 _ (by omega))
  refine StpOK.append pr.W _ _ _ hM ?_
  rw [stpsSq_mStps, u64_ofNat_add]
  have hA : StpOK pr.W (UInt64.ofNat (pr.cM + (2 * pr.S + 67))) (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen) :=
    stpOK_pcsStps pr.W _ _ _ _ (pr.W_r3 _ rfl) pr.hwA (pr.W_r4 _ rfl) pr.hmI
  refine StpOK.append pr.W _ _ _ hA ?_
  rw [stpsSq_pcsStps, u64_ofNat_add]
  exact stpOK_pcsStps pr.W _ _ _ _ (pr.W_r5 _ (by omega)) pr.hwH (pr.W_r6 _ (by omega)) pr.hmI

/-- **The run's trace, split at the openings' windows**: the slot phase, `M` on the transcript after it, `A` after
`M`, `H` after `A`. -/
theorem vS_trace (H : HIn → Dig) (t0 : Tr) (o : List Op × Block.Core) :
    opTrace H t0 (stpsOps (vS pr o))
      = opTrace H t0 (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots)
        ++ (opTrace H (runOps H t0 (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots))
            (stpsOps (mStps pr.S o.2.maskOpen))
          ++ (opTrace H (runOps H (runOps H t0 (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots))
              (stpsOps (mStps pr.S o.2.maskOpen))) (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen))
            ++ opTrace H (runOps H (runOps H (runOps H t0 (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots))
              (stpsOps (mStps pr.S o.2.maskOpen))) (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen)))
                (stpsOps (pcsStps (pr.nH + pr.rH) pr.mI o.2.hOpen)))) := by
  rw [vS_eq, stpsOps_append, stpsOps_opsStps, stpsOps_append, stpsOps_append,
    Block.opTrace_append H t0 (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots),
    Block.opTrace_append H _ (stpsOps (mStps pr.S o.2.maskOpen)),
    Block.opTrace_append H _ (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen))]

/-- An operation of the run is one of the slot phase's, `M`'s, `A`'s or `H`'s. -/
theorem mem_vS_ops (o : List Op × Block.Core) (op : Op) (h : op ∈ stpsOps (vS pr o)) :
    op ∈ o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots ∨ op ∈ stpsOps (mStps pr.S o.2.maskOpen)
      ∨ op ∈ stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen)
      ∨ op ∈ stpsOps (pcsStps (pr.nH + pr.rH) pr.mI o.2.hOpen) := by
  rw [vS_eq, stpsOps_append, stpsOps_opsStps, stpsOps_append, stpsOps_append] at h
  rcases List.mem_append.mp h with h | h
  · exact Or.inl h
  · rcases List.mem_append.mp h with h | h
    · exact Or.inr (Or.inl h)
    · exact Or.inr (Or.inr (List.mem_append.mp h))

/-- The run's length: the slot phase, `M`'s `2S + 69` items, and each opening's. -/
theorem vS_ops_length (o : List Op × Block.Core) :
    (stpsOps (vS pr o)).length = (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots).length
      + ((2 * pr.S + 69) + ((pr.nA + pr.rA + o.2.aOpen.groupVecs.length + 1 + pr.mI)
        + (pr.nH + pr.rH + o.2.hOpen.groupVecs.length + 1 + pr.mI))) := by
  rw [vS_eq, stpsOps_append, stpsOps_opsStps, stpsOps_append, stpsOps_append]
  simp only [List.length_append, stpsOps_mStps_length, stpsOps_pcsStps_length]

end Parse

/-! ## The openings' operations fit -/

section Fit

theorem flatMap_toBytes_len (v : List Fp2) : (v.flatMap Fp2.toBytes).length = 16 * v.length := by
  induction v with
  | nil => rfl
  | cons a v ih =>
    rw [List.flatMap_cons, List.length_append, Block.fp2_toBytes_length, ih, List.length_cons]
    ring

theorem mStps_fit (S : ℕ) (mo : Block.MaskOpening) (hq : mo.q.length ≤ 2 ^ 15) (hp : mo.prox.length ≤ 2 ^ 15)
    (L : ℕ) (hL : 2 ^ 20 ≤ L) : ∀ op ∈ stpsOps (mStps S mo), op.len ≤ L := by
  intro op hop
  rw [stpsOps_mStps_cons, List.mem_cons, List.mem_cons, List.mem_append, List.mem_cons] at hop
  rcases hop with h | h | h | h | h
  · rw [h]; simp only [Op.len]; omega
  · rw [h]; simp only [Op.len, Block.labMaskQ, List.length_cons, List.length_nil, flatMap_toBytes_len]; omega
  · rw [(List.mem_replicate.mp h).2]; simp only [Op.len]; omega
  · rw [h]; simp only [Op.len, Block.labMaskProx, List.length_cons, List.length_nil, flatMap_toBytes_len]; omega
  · rw [(List.mem_replicate.mp h).2]; simp only [Op.len]; omega

theorem mem_stpsOps_vecStps : ∀ (vs : List (List Fp2)) (op : Op), op ∈ stpsOps (vecStps vs) →
    ∃ v ∈ vs, op = Op.absorb Block.labPcsVec (v.flatMap Fp2.toBytes)
  | [], op, h => by simp [vecStps, stpsOps] at h
  | v :: vs, op, h => by
    rw [vecStps, List.map_cons, stpsOps_cons, ← vecStps, List.mem_append] at h
    rcases h with h | h
    · simp only [Stp.ops, List.mem_singleton] at h
      exact ⟨v, List.mem_cons_self, h⟩
    · obtain ⟨w, hw, he⟩ := mem_stpsOps_vecStps vs op h
      exact ⟨w, List.mem_cons_of_mem _ hw, he⟩

theorem pcsStps_fit (w0 m : ℕ) (o : Block.OpeningZk) (hv : ∀ v ∈ o.groupVecs, v.length ≤ 2 ^ 15)
    (hp : o.proxVec.length ≤ 2 ^ 15) (L : ℕ) (hL : 2 ^ 20 ≤ L) : ∀ op ∈ stpsOps (pcsStps w0 m o), op.len ≤ L := by
  intro op hop
  rw [stpsOps_pcsStps_split, List.mem_append, List.mem_append, List.mem_cons] at hop
  rcases hop with (h | h) | h | h
  · rw [(List.mem_replicate.mp h).2]; simp only [Op.len]; omega
  · obtain ⟨v, hvm, rfl⟩ := mem_stpsOps_vecStps _ op h
    have := hv v hvm
    simp only [Op.len, Block.labPcsVec, List.length_cons, List.length_nil, flatMap_toBytes_len]; omega
  · rw [h]; simp only [Op.len, Block.labPcsProx, List.length_cons, List.length_nil, flatMap_toBytes_len]; omega
  · rw [(List.mem_replicate.mp h).2]; simp only [Op.len]; omega

end Fit

/-! ## The openings' extractions -/

section Extract

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)

/-- **The extracted `M` table**: the column at each index, extracted for the root the header absorbs at `hdrLen + 3`
(L22's `colX`, depth 12). -/
noncomputable def colsM (hdrLen : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) : Fin (2 ^ 12) → List Fp :=
  fun j => ((colX tag L h64 key domain hs hL 12 (hdrLen + 3) log hdr j).map Subtype.val).getD []

variable {K : Type} [Field K] [Algebra GF K]

/-- **An extracted regular opening's matrix**: row `r` at column `j`, extracted for the root the header absorbs at `i`
(depth `d`). -/
noncomputable def UxW (d i rows : ℕ) {N : ℕ} (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) :
    Fin rows → Fin N → K :=
  fun r j => algebraMap GF K ((((colX tag L h64 key domain hs hL d i log hdr j).map Subtype.val).getD []).getD r
    Fp.zero).toGF

/-- **An accepted opened column, outside the extraction failure, is the extracted one** (L22's
`opened_eq_extracted` read through `colX` at the root's position). -/
theorem colX_opened (nA nH nM dA dH dM : ℕ) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (hX : ¬ EvXB tag L h64 key domain hs hL nA nH nM dA dH dM A G) (r : Dig) (hr : r ∈ rootsV (A.run G)) (d i j : ℕ)
    (o : MerkleOpening Dig Dig (ColV L)) (hop : (merkleEncV tag L h64).Opens G d r j o)
    (hq : ∀ v ∈ (merkleEncV tag L h64).openQs G j o,
      v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM)))
    (hdr : List (TItem × Dig)) (habs : Block.absAt hdr i = some r.toList) :
    colX tag L h64 key domain hs hL d i (A.runLog G).2 hdr j = some o.col := by
  rw [colX_root tag L h64 key domain hs hL d i _ hdr r habs]
  exact opened_eq_extracted tag L h64 key domain hs hL nA nH nM dA dH dM A G hX r hr d j o hop hq

end Extract

/-! ## The kinds on the concrete chain: `M`, a regular opening, and their per-position bounds -/

namespace OProf

variable {P : Block.BlockParams} (pr : OProf P)

/-- `M`'s window (after the header, the roots and the slots). -/
def aM : ℕ := pr.hdrLen + 10 + shapeLen P 0 P.geom.slots

/-- `A`'s window (after `M`'s `2S + 69` items). -/
def aA : ℕ := pr.aM + (2 * pr.S + 69)

/-- `A`'s `opB` window (after the batching run and the group vectors). -/
def aBA : ℕ := pr.aA + (pr.nA + pr.rA + P.geom.aGroups)

/-- `H`'s window (after `A`'s proximity absorb and index squeezes). -/
def aH : ℕ := pr.aBA + (1 + pr.mI)

/-- `H`'s `opB` window. -/
def aBH : ℕ := pr.aH + (pr.nH + pr.rH + P.geom.hGroups)

end OProf

/-- The verifier's own trace up to the slots' end (the accumulator's readers read it). -/
noncomputable def slotTrace {L : ℕ} (P : Block.BlockParams) (key : Option Dig) (domain : List UInt8) (G : QB L → Dig)
    (o : List Op × Block.Core) : List (TItem × Dig) :=
  opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots)

section Kinds

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
variable {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
  (accRd : List (TItem × Dig) → Block.Acc)

/-- **The chain the FS theorems read**, on an oracle and an output. -/
noncomputable def chW (G : QB L → Dig) (o : List Op × Block.Core) : List (TItem × Dig) :=
  cChain (chainEncB key domain hs L hL) (fun it : ItB L => it.1) (stB pr L) G (heads pr L o)

omit [Fintype K] [DecidableEq K] in
theorem mOmega_prim : IsPrimitiveRoot (mOmega (K := K)) 512 := by
  have h := (rootFp_isPrimitiveRoot (k := 9) (by norm_num)).map_of_injective (algebraMap GF K).injective
  rw [show (2 : ℕ) ^ 9 = 512 by norm_num] at h
  exact h

/-- **`M`'s data at its window**: the functionals the accumulator's reader reads, the extracted table. -/
noncomputable def DmW (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) :
    MData K (Fin (2 ^ 12)) (Fin pr.S) (Fin (2 * pr.S + 2)) P.nFunctionals 512 :=
  mDataOf U pr.S P.nFunctionals ((accRd hdr).fs ++ (accRd hdr).hostFs)
    (colsM pr.tag L h64 key domain hs hL pr.hdrLen log hdr)

/-- **`M`'s good predicate** on the extracted data (`GM` of L20's `block_open_knowledge`). -/
def GMW (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig) : Prop :=
  MGood (mEtaE (K := K)) (mOmega (K := K)) 1 1024 1023
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).wt
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).val
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).Ub
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).u
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).La
    (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take pr.aM)).Lb

/-- **`M`'s chain event** (`EvM`): its window at a step's end with a claim false of the extracted data, `M` alive at the
end of the chain. -/
def EvMW (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig) : Prop :=
  (pr.aM ≤ (chW pr L key domain hs hL G (A.run G)).length
      ∧ tRem pr.W ((chW pr L key domain hs hL G (A.run G)).take pr.aM) = some 0
      ∧ ¬ GMW U pr L h64 key domain hs hL accRd A G)
    ∧ subSt pr.W (maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega pr.S pr.aM
        (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2) (Equiv.refl _) (fun _ => False))
      (chW pr L key domain hs hL G (A.run G))

/-- The extracted `M` table is frozen once the chain's first `hdrLen + 8` entries are logged. -/
theorem colsM_stable (G : QB L → Dig) (τ : List (ItB L × Dig)) (qs : List (QB L))
    (hc : (chainEncB key domain hs L hL).Chain G τ qs) (hτ : τ.length = pr.hdrLen + 8) (Pl Pl' : List (QB L × Dig))
    (hq : ∀ y ∈ qs, y ∈ Pl.map Prod.fst) (hpre : Pl <+: Pl') {γ : Type} (A : OC (QB L) Dig γ)
    (ext : List (TItem × Dig)) (a : ℕ) (ha : pr.hdrLen + 8 ≤ a) :
    colsM pr.tag L h64 key domain hs hL pr.hdrLen (proverLog A Pl) ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a)
      = colsM pr.tag L h64 key domain hs hL pr.hdrLen (proverLog A Pl')
          ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a) := by
  funext j
  unfold colsM
  rw [colX_stable pr.tag L h64 key domain hs hL 12 (pr.hdrLen + 3) (pr.hdrLen + 8) (by omega) G τ qs hc hτ Pl Pl' hq
    hpre A ext a ha j]

/-- **`M`'s chain bound** (L20's `mask_knowledge_chain_pos` at the concrete chain, heads, step rule and extraction):
`q·maskEps + 3·maskEps + coll`, `maskEps ≤ 2^-106` (`maskEps_le`). -/
theorem evMW_bound (hL64 : L < 2 ^ 64) (hk : 0 < P.nFunctionals) (hsa : pr.hdrLen + 8 < pr.aM) (q : ℕ)
    (A : OC (QB L) Dig (List Op × Block.Core)) (hA : A.Bounded q) :
    prH (EvMW U hbij pr L h64 key domain hs hL accRd A)
      ≤ (q : ℝ≥0∞) * maskEps (K := K) P.nFunctionals pr.S + 3 * maskEps (K := K) P.nFunctionals pr.S
        + collBound (q + 2 ^ 20 + 1) Dig + collBound (q + 2 ^ 20 + 1 + 1) Dig :=
  mask_knowledge_chain_pos U (Equiv.ofBijective _ hbij) mEtaE mOmega_prim hk pr.S pr.aM
    (DmW U pr L h64 key domain hs hL accRd) (Equiv.refl _) pr.W pr.W_pos (chainEncB key domain hs L hL)
    (fun it : ItB L => it.1) (stB pr L) (stepsB_ok L pr.W pr.W_pos pr.W_le) (heads pr L) (2 ^ 20)
    (heads_len pr L hL64) (pr.hdrLen + 8) hsa (heads_hd pr L hL64) q A hA
    (fun G Pl Pl' τ qs hc hl hq hpre _ ext => by
      unfold DmW
      rw [colsM_stable pr L h64 key domain hs hL G τ qs hc hl Pl Pl' hq hpre A ext pr.aM (le_of_lt hsa)])

/-! ### A regular opening at a geometry `(h, Q, e)` -/

/-- **The opened points in `K`**: the coset `7·G_{2^h}`, `η_j = 7·ω_{2^h}^j` (W16R2 `h = 15`, R13 `h = 16`). -/
noncomputable def ptsG (h : ℕ) : Fin (2 ^ h) → K := fun j => algebraMap GF K (cosetPt (rootFp h) j).toGF

omit [Fintype K] [DecidableEq K] in
theorem ptsG_injective (h : ℕ) (hh : h ≤ 32) : Function.Injective (ptsG (K := K) h) := by
  intro a b hab
  have ha : (a : ℕ) < 2 ^ 64 := lt_of_lt_of_le a.isLt (Nat.pow_le_pow_right (by norm_num) (by omega))
  have hb : (b : ℕ) < 2 ^ 64 := lt_of_lt_of_le b.isLt (Nat.pow_le_pow_right (by norm_num) (by omega))
  have hab' : algebraMap GF K (cosetPt (rootFp h) a).toGF = algebraMap GF K (cosetPt (rootFp h) b).toGF := hab
  have h' := (algebraMap GF K).injective hab'
  rw [cosetPt_toGF _ _ ha, cosetPt_toGF _ _ hb] at h'
  have hω : IsPrimitiveRoot (rootFp h).toGF (2 ^ h) := rootFp_isPrimitiveRoot hh
  exact cosetPts_injective (N := 2 ^ h) seven_ne_zero_GF hω h'

/-- The row form in `K` (the interpolant on `G_{2^14}`, `w16r2_colEnc_spec`'s and `r13_colEnc_spec`'s). -/
noncomputable def RW : RowForm K (2 ^ 14) :=
  lagForm (by norm_num) ((rootFp_isPrimitiveRoot (k := 14) (by norm_num)).map_of_injective (algebraMap GF K).injective)

/-- **The row encoder at the geometry** (L10's `encLin`, `n = 2^14`, `Q` pads, at the coset `7·G_{2^h}`). -/
noncomputable def encG (h Q : ℕ) : (Fin (2 ^ 14 + Q) → K) →ₗ[K] (Fin (2 ^ h) → K) := encLin (Q := Q) (ptsG h) RW

omit [Fintype K] [DecidableEq K] in
theorem encG_injective (h Q : ℕ) (hh : h ≤ 32) (hN : 2 ^ 14 + Q ≤ 2 ^ h) : Function.Injective (encG (K := K) h Q) :=
  encLin_injective (ptsG_injective h hh) RW (by norm_num) hN

/-- **A regular opening's claims at its window**: `oclOf` of `group_zclaims` of the claims the reader reads. -/
noncomputable def clOfO (Q rows nC : ℕ) (sel : Block.Acc → List Block.ZClaim) (hdr : List (TItem × Dig)) :
    OClaims (Fin nC) ℕ (Fin rows) (Fin (2 ^ 14 + Q)) K :=
  oclOf U rows 14 Q nC (groupZclaims ((sel (accRd (hdr.take pr.aM))).map toZClaim) rows 14)

/-- **A regular opening's good predicate** (`GA` / `GH`): the extracted matrix is `e`-close to the code and every claim
the reader reads holds of the decoded rows. -/
def GOW (h Q e rows nC ipos aO : ℕ) (sel : Block.Acc → List Block.ZClaim) (A : OC (QB L) Dig (List Op × Block.Core))
    (G : QB L → Dig) : Prop :=
  GroupsGood (encG (K := K) h Q) e
    (UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2 ((chW pr L key domain hs hL G (A.run G)).take aO))
    (clOfO U pr accRd Q rows nC sel ((chW pr L key domain hs hL G (A.run G)).take aO)).rw
    (clOfO U pr accRd Q rows nC sel ((chW pr L key domain hs hL G (A.run G)).take aO)).cw
    (clOfO U pr accRd Q rows nC sel ((chW pr L key domain hs hL G (A.run G)).take aO)).grp
    (clOfO U pr accRd Q rows nC sel ((chW pr L key domain hs hL G (A.run G)).take aO)).val

/-- **A regular opening's chain event** (L20's `opening_knowledge_chain_pos`'s), its windows `aO` and `aB`, its
matrix extracted for the root at `ipos`, the group vectors read at `vpos`. -/
def EvOW (h Q e : ℕ) (hQm : Q ≤ pr.mI * 4) (rows nC ipos vpos aO aB : ℕ) (sel : Block.Acc → List Block.ZClaim)
    (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig) : Prop :=
  tRem pr.W ((chW pr L key domain hs hL G (A.run G)).take aO) = some 0
    ∧ ¬ GOW U pr L h64 key domain hs hL accRd h Q e rows nC ipos aO sel A G
    ∧ aB ≤ (chW pr L key domain hs hL G (A.run G)).length
    ∧ tRem pr.W ((chW pr L key domain hs hL G (A.run G)).take aB) = some 0
    ∧ subSt pr.W (opBCSub pr.W aO (nC + rows) (encG (K := K) h Q) e (clOfO U pr accRd Q rows nC sel)
        (UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2) (vRd U (2 ^ 14 + Q) vpos) dg0
        (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows)) pr.mI
        (idxCode h hQm) Block.labPcsProx (proxDec U (2 ^ 14 + Q)) aB
        ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ Q * 1))
      (chW pr L key domain hs hL G (A.run G))

omit [Fintype K] [DecidableEq K] in
/-- An extracted opening matrix is frozen once the chain's first `hdrLen + 8` entries are logged (`ipos` among them). -/
theorem UxW_stable (d rows ipos : ℕ) {N : ℕ} (hi : ipos < pr.hdrLen + 8) (G : QB L → Dig) (τ : List (ItB L × Dig))
    (qs : List (QB L)) (hc : (chainEncB key domain hs L hL).Chain G τ qs) (hτ : τ.length = pr.hdrLen + 8)
    (Pl Pl' : List (QB L × Dig)) (hq : ∀ y ∈ qs, y ∈ Pl.map Prod.fst) (hpre : Pl <+: Pl') {γ : Type}
    (A : OC (QB L) Dig γ) (ext : List (TItem × Dig)) (a : ℕ) (ha : pr.hdrLen + 8 ≤ a) :
    UxW (K := K) (N := N) pr.tag L h64 key domain hs hL d ipos rows (proverLog A Pl)
        ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a)
      = UxW pr.tag L h64 key domain hs hL d ipos rows (proverLog A Pl')
        ((τ.map (toTE (fun it : ItB L => it.1)) ++ ext).take a) := by
  funext r j
  unfold UxW
  rw [colX_stable pr.tag L h64 key domain hs hL d ipos (pr.hdrLen + 8) hi G τ qs hc hτ Pl Pl' hq hpre A ext a ha j]

/-- **A regular opening's chain bound at a geometry `(h, Q, e)`** (L20's `opening_knowledge_chain_pos` at the concrete
chain, with the code facts of `encLin` at `2e + (2^14 + Q) ≤ 2^h` (minimum distance `2^h − (2^14 + Q − 1)`, correlated
agreement with `A = 2^h`), the code's `(λ, ρ)` derivation `lrCode` and indices `idxCode`):
`(q·εA + εA + coll) + (q·εB + εB + coll)`, `εA = 2^h/|K|·bias`, `εB = ((2^h − e − 1)/2^h)^Q`. -/
theorem evOW_bound (hL64 : L < 2 ^ 64) (h Q e : ℕ) (hh : h ≤ 32) (hQ0 : 0 < Q) (he : 2 * e + (2 ^ 14 + Q) ≤ 2 ^ h)
    (hQm : Q ≤ pr.mI * 4) (rows nC ipos vpos aO aB : ℕ) (hi : ipos < pr.hdrLen + 8)
    (hsa : pr.hdrLen + 8 < aO) (hab : aO ≤ aB) (sel : Block.Acc → List Block.ZClaim) (q : ℕ)
    (A : OC (QB L) Dig (List Op × Block.Core)) (hA : A.Bounded q) :
    prH (EvOW U hbij pr L h64 key domain hs hL accRd h Q e hQm rows nC ipos vpos aO aB sel A)
      ≤ ((q : ℝ≥0∞) * (((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞))
            ^ (2 * (nC + rows)))
          + ((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card K * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * (nC + rows))
          + collBound (q + 2 ^ 20 + 1) Dig + collBound (q + 2 ^ 20 + 1 + 1) Dig)
        + ((q : ℝ≥0∞) * ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h)))
            ^ Q * 1)
          + (((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ Q * 1
          + collBound (q + 2 ^ 20 + 1) Dig + collBound (q + 2 ^ 20 + 1 + 1) Dig) := by
  have hpts := ptsG_injective (K := K) h hh
  have hd := encLin_minDist (Q := Q) (ptsG (K := K) h) hpts RW (by norm_num)
  have hca := encLin_caOn (Q := Q) (e := e) (ptsG (K := K) h) hpts RW (by norm_num) (by omega)
  exact opening_knowledge_chain_pos (encG (K := K) h Q) (encG_injective h Q hh (by omega)) hd (by omega) (by omega) hca
    (clOfO U pr accRd Q rows nC sel) (UxW pr.tag L h64 key domain hs hL h ipos rows) (vRd U (2 ^ 14 + Q) vpos) dg0
    (nC + rows) (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows)) _
    (lrCode_prob_le gP (Equiv.ofBijective _ hbij) _) pr.mI (idxCode h hQm) 1
    (idxCode_prob_le (by omega) hQm) Block.labPcsProx (proxDec U (2 ^ 14 + Q)) aO aB hab pr.W pr.W_pos
    (chainEncB key domain hs L hL) (fun it : ItB L => it.1) (stB pr L) (stepsB_ok L pr.W pr.W_pos pr.W_le)
    (heads pr L) (2 ^ 20) (heads_len pr L hL64) (pr.hdrLen + 8) hsa (heads_hd pr L hL64) q A hA
    (fun G Pl Pl' τ qs hc hl hq hpre _ ext =>
      UxW_stable pr L h64 key domain hs hL h rows ipos hi G τ qs hc hl Pl Pl' hq hpre A ext aO (le_of_lt hsa))

end Kinds


/-! ## `hexec`'s pieces: each opening's good predicate or its chain event, on an accepted run -/

section Alt

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

omit [DecidableEq K] in
include hU in
/-- L22's `mask_subSt_of_ok` with the functional count named (`fs.length = k`). -/
theorem mask_subSt_of_ok' (H : HIn → Dig) (tag : MTag) (root : Dig) (S : ℕ) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (hcan : Block.MaskCanon mo) (tM tA : Tr)
    (hok : MaskOk H tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) tM tA) (W : UInt64 → ℕ)
    (h1 : W tM.counter = 1) (h2 : W (tM.squeeze H).2.counter = 2 * S + 2)
    (h3 : W (runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
      (List.replicate (2 * S + 2) Op.squeeze)).counter = 64)
    (pre rest : List (TItem × Dig)) (hpre : tRem W pre = some 0) (k : ℕ) (hk : fs.length = k)
    (Dm : List (TItem × Dig) → MData K (Fin (2 ^ 12)) (Fin S) (Fin (2 * S + 2)) k 512)
    (cols : Fin (2 ^ 12) → List Fp) (hDm : Dm pre = mDataOf U S k fs cols)
    (hcols : ∀ (j : Fin mQ) (hj : (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD j 0 < 2 ^ 12),
      cols ⟨(idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD j 0, hj⟩
        = (mo.columns.getD j ⟨0, [], zeroDig, []⟩).col) :
    pre.length ≤ (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).length
      ∧ tRem W ((pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).take pre.length) = some 0
      ∧ subSt W (maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega S pre.length Dm (Equiv.refl _) (fun _ => False))
        (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest) := by
  subst hk
  exact mask_subSt_of_ok U hU hbij H tag root S fs mo hcan tM tA hok W h1 h2 h3 pre rest hpre Dm cols hDm hcols

omit [DecidableEq K] in
include hU in
/-- **`M`'s alternative on an accepted run** (`hexec` for `M`): its good predicate, or its chain event. Given the chain
as the slot phase's trace `pre` (`M`'s window), `M`'s steps and the rest, `M`'s accepted checks, the widths, the reader of
the functionals and the extracted table agreeing with the opened columns (`colX_opened` outside the extraction
failure). -/
theorem mask_alt {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (accRd : List (TItem × Dig) → Block.Acc) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (pre rest : List (TItem × Dig)) (tM tA : Tr) (hpl : pre.length = pr.aM)
    (hch : chW pr L key domain hs hL G (A.run G)
      = pre ++ opTrace (liftH G) tM (stpsOps (mStps pr.S (A.run G).2.maskOpen)) ++ rest)
    (fs : List Block.MaskFunctional) (hcan : Block.MaskCanon (A.run G).2.maskOpen)
    (hok : MaskOk (liftH G) pr.tag (rootFp 9) (rootFp 12) (A.run G).2.maskRoot pr.S (fs.map toMF)
      (toMO (A.run G).2.maskOpen) tM tA)
    (h1 : pr.W tM.counter = 1) (h2 : pr.W (tM.squeeze (liftH G)).2.counter = 2 * pr.S + 2)
    (h3 : pr.W (runOps (liftH G) ((tM.squeeze (liftH G)).2.absorb (liftH G) Block.labMaskQ
      ((A.run G).2.maskOpen.q.flatMap Fp2.toBytes)) (List.replicate (2 * pr.S + 2) Op.squeeze)).counter = 64)
    (hpre : tRem pr.W pre = some 0) (hfs : fs.length = P.nFunctionals)
    (hrd : (accRd pre).fs ++ (accRd pre).hostFs = fs)
    (hcols : ∀ (j : Fin mQ)
      (hj : (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre pr.S (A.run G).2.maskOpen))) 64)).getD
        j 0 < 2 ^ 12),
      colsM pr.tag L h64 key domain hs hL pr.hdrLen (A.runLog G).2 pre
          ⟨(idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre pr.S (A.run G).2.maskOpen))) 64)).getD
            j 0, hj⟩
        = ((A.run G).2.maskOpen.columns.getD j ⟨0, [], zeroDig, []⟩).col) :
    GMW U pr L h64 key domain hs hL accRd A G ∨ EvMW U hbij pr L h64 key domain hs hL accRd A G := by
  by_cases hg : GMW U pr L h64 key domain hs hL accRd A G
  · exact Or.inl hg
  right
  have hDm : DmW U pr L h64 key domain hs hL accRd (A.runLog G).2 pre
      = mDataOf U pr.S P.nFunctionals fs (colsM pr.tag L h64 key domain hs hL pr.hdrLen (A.runLog G).2 pre) := by
    unfold DmW
    rw [hrd]
  obtain ⟨r1, r2, r3⟩ := mask_subSt_of_ok' U hU hbij (liftH G) pr.tag (A.run G).2.maskRoot pr.S fs (A.run G).2.maskOpen
    hcan tM tA hok pr.W h1 h2 h3 pre rest hpre P.nFunctionals hfs (DmW U pr L h64 key domain hs hL accRd (A.runLog G).2)
    _ hDm hcols
  rw [hpl] at r1 r2 r3
  refine ⟨⟨by rw [hch]; exact r1, by rw [hch]; exact r2, hg⟩, ?_⟩
  rw [hch]
  exact r3

end Alt

/-! ## `PcsOk` with the parameters' numbers named, and the transcript after an opening -/

section Named

theorem seqTr_eq (H : HIn → Dig) : ∀ (counts : List ℕ) (t : Tr),
    seqTr H counts t = runOps H t (List.replicate counts.sum Op.squeeze)
  | [], _ => rfl
  | c :: cs, t => by
    show seqTr H cs (t.challengeFp2Vec H c).2 = _
    rw [seqTr_eq H cs, challengeFp2Vec_sqDs, List.sum_cons, List.replicate_add, runOps_append]

/-- `zk_rhos`' transcript after the batching run. -/
theorem zkRhosAux_tr' (H : HIn → Dig) (rows : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr) :
    (zkRhosAux H rows gs t).2.2 = runOps H t (List.replicate (nMem gs + rows) Op.squeeze) := by
  rw [zkRhosAux_tr, seqTr_eq, challengeFp2Vec_sqDs, List.replicate_add, runOps_append]
  rfl

/-- **`PcsOk` with the parameters' numbers named** (`Q` queries and pads, codeword length `N`, `m` index squeezes):
the path lengths, the group vectors' count and lengths, the proximity vector's length, the transcript after the index
draw, and each opened column's checks at the index the run's digests give. -/
theorem pcsOk_named (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2)
    (root : Dig) (rows lc : ℕ) (claims : List ZClaim) (op : OpeningZk) (t t' : Tr)
    (hok : PcsOk H tag prm pt ev root rows lc claims op t t') (Q N m : ℕ) (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q)
    (hnn : prm.nn = N) (hpow : isPow2 N = true) (hQ0 : 0 < Q) (hm : (Q + 3) / 4 = m) :
    (∀ c ∈ op.columns, c.2.2.2.length = Nat.log2 N)
      ∧ op.groupVecs.length = (groupZclaims claims rows lc).length
      ∧ (∀ g, g < op.groupVecs.length → (op.groupVecs.getD g []).length = 2 ^ lc + Q)
      ∧ op.proxVec.length = 2 ^ lc + Q
      ∧ t' = runOps H ((absorbVecs H op.groupVecs (zkRhosAux H rows (groupZclaims claims rows lc) t).2.2).absorbFp2 H
          pcsProxLabel op.proxVec) (List.replicate m Op.squeeze)
      ∧ op.columns.length = Q
      ∧ ∀ k, k < Q → ColOk H tag root rows (zkRhosAux H rows (groupZclaims claims rows lc) t).1
          (fun j => ev (pt j) (op.groupVecs ++ [op.proxVec])) (op.columns.getD k (0, [], zeroDig, []))
          ((idxOf N Q (sqDs H ((absorbVecs H op.groupVecs
            (zkRhosAux H rows (groupZclaims claims rows lc) t).2.2).absorbFp2 H pcsProxLabel op.proxVec) m)).getD k 0) := by
  obtain ⟨h1, -, h3, h4, hgrp, h5, idx, hidx, hlen, hcols⟩ := hok
  subst h1 hqp hnn hm
  rw [hnQ, challengeIndices_sqDs H prm.qPad prm.nn _ hpow hQ0] at hidx
  simp only [Option.some.injEq, Prod.mk.injEq] at hidx
  obtain ⟨hi1, hi2⟩ := hidx
  have hl : op.columns.length = prm.qPad := by
    rw [hlen, ← hi1, idxOf_length, sqDs_length]
    omega
  refine ⟨h3, h4, fun g hg => (hgrp g hg).1, h5, hi2.symm, hl, fun k hk => ?_⟩
  rw [hi1]
  exact hcols k (by rw [hl]; exact hk)

/-- **The transcript after an opening is `runOps` of the opening's steps** (the `nC + rows` batching squeezes, the
group vectors, `"pcs-prox"`, the `m` index squeezes). -/
theorem pcs_tr_after (H : HIn → Dig) (rows nC m : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2)))
    (hnC : nMem gs = nC) (o : Block.OpeningZk) (t : Tr) :
    runOps H ((absorbVecs H (toOZ o).groupVecs (zkRhosAux H rows gs t).2.2).absorbFp2 H pcsProxLabel (toOZ o).proxVec)
        (List.replicate m Op.squeeze)
      = runOps H t (stpsOps (pcsStps (nC + rows) m o)) := by
  rw [stpsOps_pcsStps_split, runOps_append, runOps_append, runOps_vecStps, zkRhosAux_tr', hnC]
  rfl

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- Every group of `oclOf`'s draw positions is a group of the list (the claims' count named). -/
theorem oclOf_grp_lt' (rows lc Q nC : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2))) (hnC : nMem gs = nC)
    (p : Fin nC) : (oclOf U rows lc Q nC gs).grp p < gs.length := by
  subst hnC
  exact oclOf_grp_lt U rows lc Q gs p

include hU in
/-- `pcsOk_groupsAccept` with the claims' count, the queries' count and the index squeezes named. -/
theorem pcsOk_groupsAccept' (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (pt : ℕ → Fp)
    (ev : Fp → List (List Fp2) → List Fp2) (lc Q N rows m : ℕ) (hlc : prm.logCols = lc) (hQ : prm.qPad = Q)
    (hnQ : prm.nQ = Q) (hm : (Q + 3) / 4 = m) (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q) (R : RowForm K (2 ^ lc))
    (hspec : ColEncSpec U R Q pt ev) (root : Dig) (claims : List ZClaim) (op : OpeningZk) (t t' : Tr)
    (hok : PcsOk H tag prm pt ev root rows lc claims op t t') (pts : Fin N → K)
    (hpts : ∀ j : Fin N, pts j = algebraMap GF K (pt j).toGF) (J : Fin Q → Fin N)
    (hJ : ∀ k : Fin Q, (J k : ℕ) = (idxOf prm.nn Q (sqDs H ((absorbVecs H op.groupVecs
      (zkRhosAux H rows (groupZclaims claims rows lc) t).2.2).absorbFp2 H pcsProxLabel op.proxVec) m)).getD k 0)
    (Ux : Fin rows → Fin N → K)
    (hUx : ∀ (k : Fin Q) (i : Fin rows),
      Ux i (J k) = algebraMap GF K (((op.columns.getD k (0, [], zeroDig, [])).2.1).getD i Fp.zero).toGF)
    (nC : ℕ) (hnC : nMem (groupZclaims claims rows lc) = nC) :
    GroupsAccept (encLin (Q := Q) pts R) Ux
      (oclOf U rows lc Q nC (groupZclaims claims rows lc)).rw (oclOf U rows lc Q nC (groupZclaims claims rows lc)).cw
      (oclOf U rows lc Q nC (groupZclaims claims rows lc)).grp (oclOf U rows lc Q nC (groupZclaims claims rows lc)).val
      (fun g _ _ => vecK U (2 ^ lc + Q) (op.groupVecs.getD g [])) (fun _ _ => vecK U (2 ^ lc + Q) op.proxVec)
      (fun p => chK U (sqDs H t (nC + rows)) p) (fun i => chK U (sqDs H t (nC + rows)) (nC + i)) J := by
  subst hnC hnQ hm
  exact pcsOk_groupsAccept U hU H tag prm pt ev lc prm.nQ N rows hlc hQ hpow hQ0 R hspec root claims op t t' hok pts hpts
    J hJ Ux hUx

end Named

section AltO

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

include hU in
/-- **A regular opening's alternative on an accepted run** (`hexec` for `A` / `H`, at a geometry `(h, Q, e)`): its good
predicate, or its chain event. Given the chain as `pre` (the opening's window), the opening's steps and the rest, the
opening's accepted checks (`PcsOk` at parameters with `log_cols 14`, `Q` queries and pads, codeword length `2^h`, a
column evaluator meeting `ColEncSpec` at the coset), the widths, the claims' reader, and the extracted matrix agreeing
with the opened columns at the sampled indices. -/
theorem opening_alt {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (accRd : List (TItem × Dig) → Block.Acc) (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (prm : PcsPrm) (ev : Fp → List (List Fp2) → List Fp2) (h Q e : ℕ) (hlc : prm.logCols = 14)
    (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q) (hnn : prm.nn = 2 ^ h) (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q)
    (hm : (Q + 3) / 4 = pr.mI) (hQm : Q ≤ pr.mI * 4)
    (hspec : ColEncSpec U (RW (K := K)) Q (cosetPt (rootFp h)) ev)
    (rows nC ipos vpos aO aB : ℕ) (sel : Block.Acc → List Block.ZClaim) (pre rest : List (TItem × Dig))
    (tA tH : Tr) (o : Block.OpeningZk) (hpl : pre.length = aO) (hvpos : vpos = aO + (nC + rows))
    (haB : aB = aO + (nC + rows + o.groupVecs.length))
    (hch : chW pr L key domain hs hL G (A.run G)
      = pre ++ opTrace (liftH G) tA (stpsOps (pcsStps (nC + rows) pr.mI o)) ++ rest)
    (hpre : tRem pr.W pre = some 0) (hw0 : 0 < nC + rows) (hW1 : pr.W tA.counter = nC + rows)
    (hW2 : pr.W ((runOps (liftH G) (runOps (liftH G) tA (List.replicate (nC + rows) Op.squeeze))
      (stpsOps (vecStps o.groupVecs))).absorb (liftH G) Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)).counter = pr.mI)
    (cl : List Block.ZClaim) (root : Dig)
    (hok : PcsOk (liftH G) pr.tag prm (cosetPt (rootFp h)) ev root rows 14 (cl.map toZClaim) (toOZ o) tA tH)
    (hcnt : cl.length = nC) (hrd : sel (accRd (pre.take pr.aM)) = cl) (hcan : Block.HidingCanon o)
    (hcolX : ∀ (k : ℕ), k < Q → k < o.columns.length →
      ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.2.2.length = h →
      verifyPath (liftH G) pr.tag root ((toOZ o).columns.getD k (0, [], zeroDig, [])).1
        (saltLeaf (liftH G) pr.tag (colDigest (liftH G) pr.tag ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.1)
          ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.2.1) ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.2.2
        = true →
      ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.1.length = rows →
      (colX pr.tag L h64 key domain hs hL h ipos (A.runLog G).2 pre
        ((toOZ o).columns.getD k (0, [], zeroDig, [])).1).map Subtype.val
        = some ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.1) :
    GOW U pr L h64 key domain hs hL accRd h Q e rows nC ipos aO sel A G
      ∨ EvOW U hbij pr L h64 key domain hs hL accRd h Q e hQm rows nC ipos vpos aO aB sel A G := by
  by_cases hg : GOW U pr L h64 key domain hs hL accRd h Q e rows nC ipos aO sel A G
  · exact Or.inl hg
  right
  set tP := (runOps (liftH G) (runOps (liftH G) tA (List.replicate (nC + rows) Op.squeeze))
    (stpsOps (vecStps o.groupVecs))).absorb (liftH G) Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes) with htP
  have hnC : nMem (groupZclaims (cl.map toZClaim) rows 14) = nC := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hcnt]
  have htP' : (absorbVecs (liftH G) (toOZ o).groupVecs (zkRhosAux (liftH G) rows
      (groupZclaims (cl.map toZClaim) rows 14) tA).2.2).absorbFp2 (liftH G) pcsProxLabel (toOZ o).proxVec = tP := by
    rw [htP, zkRhosAux_tr', hnC, runOps_vecStps]
    rfl
  -- the opening's checks, with the numbers named
  obtain ⟨hpath, h3, hgl, h4, -, hcl, hco⟩ := pcsOk_named (liftH G) pr.tag prm _ _ root rows 14 _ (toOZ o) tA tH hok
    Q (2 ^ h) pr.mI hqp hnQ hnn (by rw [← hnn]; exact hpow) hQ0 hm
  rw [htP'] at hco
  have hJ : ∀ k : Fin Q, ((idxCode h hQm (vecOf dg0 pr.mI ((sqDs (liftH G) tP pr.mI).map halves)) k : Fin (2 ^ h)) : ℕ)
        = (idxOf prm.nn Q (sqDs (liftH G) ((absorbVecs (liftH G) (toOZ o).groupVecs
          (zkRhosAux (liftH G) rows (groupZclaims (cl.map toZClaim) rows 14) tA).2.2).absorbFp2 (liftH G) pcsProxLabel
            (toOZ o).proxVec) pr.mI)).getD k 0 := by
    intro k
    rw [htP', hnn]
    exact idxCode_sqDs h hQm (sqDs (liftH G) tP pr.mI) (sqDs_length _ _ _) k
  have hcols : ∀ (k : Fin Q) (r : Fin rows),
      UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2 pre r
          (idxCode h hQm (vecOf dg0 pr.mI ((sqDs (liftH G) tP pr.mI).map halves)) k)
        = algebraMap GF K ((((toOZ o).columns.getD k (0, [], zeroDig, [])).2.1).getD r Fp.zero).toGF := by
    intro k r
    have hkl : (k : ℕ) < (toOZ o).columns.length := by rw [hcl]; exact k.isLt
    have hkl' : (k : ℕ) < o.columns.length := by
      have e : (toOZ o).columns.length = o.columns.length := List.length_map _
      rw [← e]; exact hkl
    have hc := hco k k.isLt
    have hk1 : ((toOZ o).columns.getD k (0, [], zeroDig, [])).1
        = ((idxCode h hQm (vecOf dg0 pr.mI ((sqDs (liftH G) tP pr.mI).map halves)) k : Fin (2 ^ h)) : ℕ) := by
      rw [hc.1]
      exact (idxCode_sqDs h hQm (sqDs (liftH G) tP pr.mI) (sqDs_length _ _ _) k).symm
    have hp : ((toOZ o).columns.getD k (0, [], zeroDig, [])).2.2.2.length = h := by
      rw [hpath _ (mem_of_getD_lt _ _ hkl _), Nat.log2_two_pow]
    have hx := hcolX k k.isLt hkl' hp hc.2.2.1 hc.2.1
    unfold UxW
    rw [← hk1, hx]
    rfl
  have hGA := pcsOk_groupsAccept' U hU (liftH G) pr.tag prm (cosetPt (rootFp h)) ev 14 Q (2 ^ h) rows pr.mI hlc hqp hnQ
    hm hpow hQ0 RW hspec root (cl.map toZClaim) (toOZ o) tA tH hok (ptsG h) (fun _ => rfl)
    (idxCode h hQm (vecOf dg0 pr.mI ((sqDs (liftH G) tP pr.mI).map halves))) hJ
    (UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2 pre) hcols nC hnC
  have hlr := lrCode_sqDs U hbij nC rows (sqDs (liftH G) tA (nC + rows)) (sqDs_length _ _ _)
  have hdec := proxDec_enc U o.proxVec hcan.2.1 (2 ^ 14 + Q) h4
  have hcl' : clOfO U pr accRd Q rows nC sel pre = oclOf U rows 14 Q nC (groupZclaims (cl.map toZClaim) rows 14) := by
    unfold clOfO
    rw [hrd]
  have hv : ∀ g ∈ Set.range (oclOf U rows 14 Q nC (groupZclaims (cl.map toZClaim) rows 14)).grp,
      (fun (g : ℕ) (_ : Fin nC → K) (_ : Fin rows → K) => vecK U (2 ^ 14 + Q) ((toOZ o).groupVecs.getD g [])) g
        = (fun (g : ℕ) (_ : Fin nC → K) (_ : Fin rows → K) => vRd U (2 ^ 14 + Q) vpos
          (pre ++ opTrace (liftH G) tA (List.replicate (nC + rows) Op.squeeze ++ stpsOps (vecStps o.groupVecs))) g) g := by
    rintro g ⟨p, rfl⟩
    have hgp : (oclOf U rows 14 Q nC (groupZclaims (cl.map toZClaim) rows 14)).grp p < o.groupVecs.length :=
      lt_of_lt_of_eq (oclOf_grp_lt' U rows 14 Q nC _ hnC p) h3.symm
    funext _ _
    have hvt := vRd_trace U (liftH G) pre [] tA (nC + rows) o.groupVecs _ hgp
      (hcan.1 _ (mem_of_getD_lt _ _ hgp _)) (2 ^ 14 + Q) (hgl _ hgp)
    rw [List.append_nil, hpl, ← hvpos] at hvt
    exact hvt.symm
  have hacc := groupsAccept_congr_v _ _ _ _ _ _ _ _ _ _ _ _ hv hGA
  rw [← hcl'] at hacc
  have hacc' : GroupsAccept (encG (K := K) h Q) (UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2 pre)
      (clOfO U pr accRd Q rows nC sel pre).rw (clOfO U pr accRd Q rows nC sel pre).cw
      (clOfO U pr accRd Q rows nC sel pre).grp (clOfO U pr accRd Q rows nC sel pre).val
      (fun g _ _ => vRd U (2 ^ 14 + Q) vpos
        (pre ++ opTrace (liftH G) tA (List.replicate (nC + rows) Op.squeeze ++ stpsOps (vecStps o.groupVecs))) g)
      (fun _ _ => vecK U (2 ^ 14 + Q) o.proxVec)
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows)
        (vecOf dg0 (nC + rows) ((sqDs (liftH G) tA (nC + rows)).map halves))).1
      (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows)
        (vecOf dg0 (nC + rows) ((sqDs (liftH G) tA (nC + rows)).map halves))).2
      (idxCode h hQm (vecOf dg0 pr.mI ((sqDs (liftH G) tP pr.mI).map halves))) := by
    rw [hlr]
    exact hacc
  obtain ⟨s1, s2, s3⟩ := pcs_subSt_of_acc (liftH G) pr.W (nC + rows) pr.mI hw0 pr.hmI o tA hW1 hW2 pre rest hpre
    (encG (K := K) h Q) e (clOfO U pr accRd Q rows nC sel) (UxW pr.tag L h64 key domain hs hL h ipos rows (A.runLog G).2)
    (vRd U (2 ^ 14 + Q) vpos) dg0
    (lrCode gP (Equiv.ofBijective _ hbij) (finSumFinEquiv.symm : Fin (nC + rows) ≃ Fin nC ⊕ Fin rows))
    (idxCode h hQm) (proxDec U (2 ^ 14 + Q))
    ((((Fintype.card (Fin (2 ^ h)) - (e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ Q * 1)
    (vecK U (2 ^ 14 + Q) o.proxVec) hdec hacc'
  rw [hpl, ← haB] at s1 s2 s3
  have htk : (chW pr L key domain hs hL G (A.run G)).take aO = pre := by
    rw [hch, ← hpl, List.append_assoc, List.take_left' rfl]
  refine ⟨by rw [htk]; exact hpre, hg, by rw [hch]; exact s1, by rw [hch]; exact s2, by rw [hch]; exact s3⟩

end AltO


/-! ## The accepted run, as the chain theorems read it -/

section Run

theorem sqN_stpsOps : ∀ ss : List Stp, sqN (stpsOps ss) = stpsSq ss
  | [] => rfl
  | .ab l x :: ss => by
    rw [stpsOps_cons, sqN_append, sqN_stpsOps ss, stpsSq_cons]
    simp [Stp.ops, Stp.nsq, sqN]
  | .sq n :: ss => by
    rw [stpsOps_cons, sqN_append, sqN_stpsOps ss, stpsSq_cons]
    simp [Stp.ops, Stp.nsq, sqN_replicate]

theorem opsCtr_eq (c : UInt64) (ops : List Op) : opsCtr c ops = c + UInt64.ofNat (sqN ops) := by
  have h := opsCtr_stpsOps c (opsStps ops)
  rwa [stpsOps_opsStps, stpsSq_opsStps] at h

theorem ctr_runOps (H : HIn → Dig) (t : Tr) (ops : List Op) (c : ℕ) (hc : t.counter = UInt64.ofNat c) :
    (runOps H t ops).counter = UInt64.ofNat (c + sqN ops) := by
  rw [runOps_counter, opsCtr_eq, hc, u64_ofNat_add]

theorem ctr_squeeze (H : HIn → Dig) (t : Tr) (c : ℕ) (hc : t.counter = UInt64.ofNat c) :
    (t.squeeze H).2.counter = UInt64.ofNat (c + 1) := by
  show t.counter + 1 = _
  rw [hc, ← u64_ofNat_add]
  rfl

/-- The slot phase's operations fit `L` (as L21's `allOps`, `RelW16Define.lean`). -/
theorem slots_fit (P : Block.BlockParams) (o : List Op × Block.Core) (L : ℕ) (hL81 : 81 ≤ L)
    (hh : ∀ op ∈ o.1, op.len ≤ L) (hsh : Block.CoreShape P.geom o.2)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ k, k < P.geom.slots.length → 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L
      ∧ 55 + 16 * Block.slotTerms P k ≤ L) :
    ∀ op ∈ o.1 ++ Block.rootOps P o.2 ++ Block.fullOps P 0 o.2.slots, op.len ≤ L := by
  intro op hop
  simp only [List.mem_append] at hop
  rcases hop with (hop | hop) | hop
  · exact hh op hop
  · exact Block.rootOps_len P o.2 L hL81 op hop
  · refine Block.fullOps_fit P L 0 o.2.slots (fun i q hq => ?_) op hop
    have hi : i < P.geom.slots.length := by rw [← hsh.1]; exact (List.getElem?_eq_some_iff.mp hq).1
    obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
    obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
    obtain ⟨-, h2, h3⟩ := hsh.2.1 i q s tt hq hs' htt
    have e1 : Block.slotShape P i = s := by rw [Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have e2 : Block.slotTerms P i = tt := by rw [Block.slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
    obtain ⟨hLr, hLt⟩ := hgeomL i hi
    rw [e1] at hLr
    rw [e2] at hLt
    exact ⟨Block.slotPreOps_len P (0 + i) q L hL81, scOps_len L _ hLr q.rounds h2, Block.termOp_len q _ L h3 hLt⟩

/-- The slot phase's shape: its length and squeeze count are the shape's. -/
theorem slots_shape (P : Block.BlockParams) (o : List Op × Block.Core) (hsh : Block.CoreShape P.geom o.2)
    (hgt : P.geom.slots.length = P.geom.terms.length) :
    fullLen P 0 o.2.slots = shapeLen P 0 P.geom.slots ∧ fullSq P 0 o.2.slots = shapeSq P 0 P.geom.slots := by
  refine full_shape P 0 o.2.slots P.geom.slots hsh.1 (fun i sp s hsp hs => ?_)
  have hi : i < P.geom.slots.length := (List.getElem?_eq_some_iff.mp hs).1
  obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  exact (hsh.2.1 i sp s tt hsp hs htt).1

end Run

/-! ## Helpers for the accepted run -/

section Help

theorem getD_toOZ (o : Block.OpeningZk) (k : ℕ) :
    (toOZ o).columns.getD k (0, [], zeroDig, []) = toOCol (o.columns.getD k ⟨0, [], zeroDig, []⟩) := by
  show (o.columns.map toOCol).getD k (toOCol ⟨0, [], zeroDig, []⟩) = _
  rw [getD_map']

/-- An accepted opened column of the block's Merkle work, outside the extraction failure, is the extracted one. -/
theorem colX_of_col (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (nA nH nM dA dH dM : ℕ)
    (A : OC (QB L) Dig (List Op × Block.Core)) (G : QB L → Dig)
    (hX : ¬ EvXB tag L h64 key domain hs hL nA nH nM dA dH dM A G) (root : Dig) (hr : root ∈ rootsV (A.run G))
    (d ipos : ℕ) (hdr : List (TItem × Dig)) (habs : Block.absAt hdr ipos = some root.toList) (c : Block.Column)
    (hfit : 8 * c.col.length ≤ L) (hpath : c.path.length = d)
    (hv : verifyPath (liftH G) tag root c.j (saltLeaf (liftH G) tag (colDigest (liftH G) tag c.col) c.salt) c.path = true)
    (hq : ∀ v ∈ (merkleEncV tag L h64).openQs G c.j ⟨⟨c.col, hfit⟩, c.salt, c.path⟩,
      v ∈ OC.queries G (A.bind (blockV tag L h64 nA nH nM dA dH dM))) :
    (colX tag L h64 key domain hs hL d ipos (A.runLog G).2 hdr c.j).map Subtype.val = some c.col := by
  rw [colX_opened tag L h64 key domain hs hL nA nH nM dA dH dM A G hX root hr d ipos c.j ⟨⟨c.col, hfit⟩, c.salt, c.path⟩
    (opensV_of_exec tag L h64 G d root c.j c.col hfit c.salt c.path hpath hv) hq hdr habs]
  rfl

theorem runOps_mPre (H : HIn → Dig) (S : ℕ) (mo : Block.MaskOpening) (t : Tr) :
    runOps H t (stpsOps (mPre S mo))
      = (((t.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
          maskProxLabel mo.prox := by
  rw [stpsOps_mPre_split, runOps_append, runOps_append, challengeFp2Vec_sqDs]
  rfl

end Help

/-! ## The accepted run with the profile's header -/

section Acc

/-- **What an accepted run with the profile's header gives**: the chain the FS theorems read is the verifier's own
trace, split at `M`'s, `A`'s and `H`'s windows; the three accepted checks; the counters at the windows; the parse at
the windows. -/
structure RunAcc {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (prm : PcsPrm) (h : ℕ)
    (ev : Fp → List (List Fp2) → List Fp2) (o : List Op × Block.Core) (G : QB L → Dig) (acc : Block.Acc)
    (tM tA tH tF : Tr) : Prop where
  chain : chW pr L key domain hs hL G o
      = slotTrace P key domain G o ++ (opTrace (liftH G) tM (stpsOps (mStps pr.S o.2.maskOpen))
        ++ (opTrace (liftH G) tA (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen))
          ++ opTrace (liftH G) tH (stpsOps (pcsStps (pr.nH + pr.rH) pr.mI o.2.hOpen))))
  len : (slotTrace P key domain G o).length = pr.aM
  nf : (acc.fs ++ acc.hostFs).length = P.nFunctionals
  mok : MaskOk (liftH G) pr.tag (rootFp 9) (rootFp 12) o.2.maskRoot pr.S ((acc.fs ++ acc.hostFs).map toMF)
    (toMO o.2.maskOpen) tM tA
  aok : PcsOk (liftH G) pr.tag prm (cosetPt (rootFp h)) ev o.2.aRoot pr.rA 14 (acc.claims.a.map toZClaim)
    (toOZ o.2.aOpen) tA tH
  hok : PcsOk (liftH G) pr.tag prm (cosetPt (rootFp h)) ev o.2.hRoot pr.rH 14
    ((acc.claims.h ++ [P.logupSumClaim]).map toZClaim) (toOZ o.2.hOpen) tH tF
  cM : tM.counter = UInt64.ofNat pr.cM
  cA : tA.counter = UInt64.ofNat (pr.cM + (2 * pr.S + 67))
  cH : tH.counter = UInt64.ofNat (pr.cM + (2 * pr.S + 67) + (pr.nA + pr.rA + pr.mI))
  remM : tRem pr.W (slotTrace P key domain G o) = some 0
  remA : tRem pr.W (slotTrace P key domain G o ++ opTrace (liftH G) tM (stpsOps (mStps pr.S o.2.maskOpen))) = some 0
  remH : tRem pr.W (slotTrace P key domain G o ++ opTrace (liftH G) tM (stpsOps (mStps pr.S o.2.maskOpen))
    ++ opTrace (liftH G) tA (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI o.2.aOpen))) = some 0

/-- **An accepted run with the profile's header** (L22's `cChain_stps` and `blockVerify_ok` at the concrete heads:
the run parses, fits and has at most `2^20` items). Given the profile's fields (`maskField`; `pcsVerify` accepting only
when `PcsOk` holds at parameters with `Q` queries and pads and codeword length `2^h`), the claims' counts (L22-2), the
slots' geometry and `L ≥ 2^20`. -/
theorem run_acc {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (hL20 : 2 ^ 20 ≤ L) (hL64 : L < 2 ^ 64)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (rowsOf : Block.Cm → ℕ) (prm : PcsPrm) (h Q : ℕ)
    (ev : Fp → List (List Fp2) → List Fp2) (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q) (hnn : prm.nn = 2 ^ h)
    (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q) (hQ15 : 2 ^ 14 + Q ≤ 2 ^ 15) (hm : (Q + 3) / 4 = pr.mI)
    (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : ∀ (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag prm (cosetPt (rootFp h)) ev root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t t')
    (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (A : OC (QB L) Dig (List Op × Block.Core))
    (hcnt : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (hacc : Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc) (hsq : sqN (A.run G).1 = pr.hdrSq) :
    ∃ tM tA tH tF, RunAcc pr L key domain hs hL prm h ev (A.run G) G acc tM tA tH tF := by
  obtain ⟨hcA, hcH⟩ := hcnt G bga rs acc hacc
  obtain ⟨⟨hlen, hfitH, hcan, hshape, t'', hbs⟩, io, tF, hbv⟩ := hacc
  have hd1 : ∀ i, i < (A.run G).2.slots.length → 1 ≤ (Block.slotShape P i).2.2 :=
    fun i hi => (hgeomL i (by rw [← hshape.1]; exact hi)).1
  -- the verifier's run, decomposed
  obtain ⟨bga', rs', acc', tM, tA, tH, hbs', hnf, hmv, hpa, hph⟩ := blockVerify_ok (liftH G) P (A.run G).2 _ io tF hbv
  have hsame := hbs.symm.trans hbs'
  simp only [Except.ok.injEq, Prod.mk.injEq] at hsame
  obtain ⟨rfl, rfl, rfl, rfl⟩ := hsame
  have htM : t'' = runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      ((A.run G).1 ++ Block.rootOps P (A.run G).2 ++ Block.fullOps P 0 (A.run G).2.slots) := by
    rw [blockSlots_tr (liftH G) P (A.run G).2 _ _ _ _ _ hbs' hd1, ← runOps_append, List.append_assoc]
  rw [hPm] at hmv
  have hMok : MaskOk (liftH G) pr.tag (rootFp 9) (rootFp 12) (A.run G).2.maskRoot pr.S
      ((acc.fs ++ acc.hostFs).map toMF) (toMO (A.run G).2.maskOpen) t'' tA := by
    have h1 := hmv
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h1
    exact h1
  obtain ⟨th, rs'', idx, hmt⟩ := maskField_transcript pr.tag pr.S (liftH G) _ _ _ _ _ hmv
  have htA := (maskTranscript_runOps (liftH G) pr.S (A.run G).2.maskOpen _ th rs'' idx tA hmt).2.2.2.1
  have hAok := hPp (liftH G) .a _ _ _ _ _ hpa
  have hHok := hPp (liftH G) .h _ _ _ _ _ hph
  rw [hrA] at hAok
  rw [hrH] at hHok
  have hnA : nMem (groupZclaims (acc.claims.a.map toZClaim) pr.rA 14) = pr.nA := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hcA]
  have hnH : nMem (groupZclaims ((acc.claims.h ++ [P.logupSumClaim]).map toZClaim) pr.rH 14) = pr.nH := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hcH]
  obtain ⟨-, -, hAgl, hA4, htH, -, -⟩ := pcsOk_named (liftH G) pr.tag prm _ _ _ pr.rA 14 _ _ tA tH hAok Q (2 ^ h) pr.mI
    hqp hnQ hnn (by rw [← hnn]; exact hpow) hQ0 hm
  rw [pcs_tr_after (liftH G) pr.rA pr.nA pr.mI _ hnA] at htH
  obtain ⟨-, -, hHgl, hH4, -, -, -⟩ := pcsOk_named (liftH G) pr.tag prm _ _ _ pr.rH 14 _ _ tH tF hHok Q (2 ^ h) pr.mI
    hqp hnQ hnn (by rw [← hnn]; exact hpow) hQ0 hm
  -- the shape
  obtain ⟨hfl, hfs⟩ := slots_shape P (A.run G) hshape hgt
  have hX0 : ((A.run G).1 ++ Block.rootOps P (A.run G).2 ++ Block.fullOps P 0 (A.run G).2.slots).length = pr.aM := by
    simp only [List.length_append, hlen, rootOps_length, fullOps_length, hfl, OProf.aM]
  have hsqX : sqN ((A.run G).1 ++ Block.rootOps P (A.run G).2 ++ Block.fullOps P 0 (A.run G).2.slots) = pr.cM := by
    rw [sqN_append, sqN_append, rootOps_sq, fullOps_sq, hsq, hfs]
    rfl
  -- every operation fits, the run parses, at most `2^20` items
  have hfit : ∀ op ∈ stpsOps (vS pr (A.run G)), op.len ≤ L := by
    intro op hop
    rcases mem_vS_ops pr (A.run G) op hop with hop | hop | hop | hop
    · exact slots_fit P (A.run G) L (by omega) hfitH hshape hgt (fun k hk => (hgeomL k hk).2) op hop
    · have hq : (A.run G).2.maskOpen.q.length ≤ 2 ^ 15 := by
        have e : (A.run G).2.maskOpen.q.length = 2 * mMsg := hMok.1
        rw [e]
        norm_num [mMsg]
      have hp : (A.run G).2.maskOpen.prox.length ≤ 2 ^ 15 := by
        have e : (A.run G).2.maskOpen.prox.length = 2 * mMsg := hMok.2.2.1
        rw [e]
        norm_num [mMsg]
      exact mStps_fit pr.S _ hq hp L hL20 op hop
    · refine pcsStps_fit _ _ _ (fun v hv => ?_) ?_ L hL20 op hop
      · obtain ⟨g, hg, rfl⟩ := List.getElem_of_mem hv
        have e : ((A.run G).2.aOpen.groupVecs.getD g []).length = 2 ^ 14 + Q := hAgl g hg
        rw [getD_eq_get _ _ _ hg] at e
        rw [e]
        exact hQ15
      · have e : (A.run G).2.aOpen.proxVec.length = 2 ^ 14 + Q := hA4
        rw [e]
        exact hQ15
    · refine pcsStps_fit _ _ _ (fun v hv => ?_) ?_ L hL20 op hop
      · obtain ⟨g, hg, rfl⟩ := List.getElem_of_mem hv
        have e : ((A.run G).2.hOpen.groupVecs.getD g []).length = 2 ^ 14 + Q := hHgl g hg
        rw [getD_eq_get _ _ _ hg] at e
        rw [e]
        exact hQ15
      · have e : (A.run G).2.hOpen.proxVec.length = 2 ^ 14 + Q := hH4
        rw [e]
        exact hQ15
  have hgA : (A.run G).2.aOpen.groupVecs.length = P.geom.aGroups := hshape.2.2.2.2.2.2.2.1
  have hgH : (A.run G).2.hOpen.groupVecs.length = P.geom.hGroups := hshape.2.2.2.2.2.2.2.2.1
  have hlen20 : (stpsOps (vS pr (A.run G))).length ≤ 2 ^ 20 := by
    have := pr.hlen
    rw [vS_ops_length, hX0, hgA, hgH]
    unfold OProf.aM
    omega
  have hokv := stpOK_vS pr (A.run G) hsq hfs
  have hch : chW pr L key domain hs hL G (A.run G)
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (vS pr (A.run G))) := by
    unfold chW
    rw [heads_good pr L (A.run G) ⟨hlen, hsq, hokv, hfit, hlen20⟩]
    exact cChain_stps L pr.W pr.W_pos pr.W_le key domain hs hL hL64 G _ hokv hfit
  rw [vS_trace, ← htM, ← htA, ← htH] at hch
  -- the counters
  have ht0 : (Tr.newKeyed (liftH G) domain key).counter = UInt64.ofNat 0 := rfl
  have hkM : t''.counter = UInt64.ofNat pr.cM := by
    rw [htM, ctr_runOps _ _ _ 0 ht0, Nat.zero_add, hsqX]
  have hkA : tA.counter = UInt64.ofNat (pr.cM + (2 * pr.S + 67)) := by
    rw [htA, ctr_runOps _ _ _ _ hkM, sqN_stpsOps, stpsSq_mStps]
  have hkH : tH.counter = UInt64.ofNat (pr.cM + (2 * pr.S + 67) + (pr.nA + pr.rA + pr.mI)) := by
    rw [htH, ctr_runOps _ _ _ _ hkA, sqN_stpsOps, stpsSq_pcsStps]
  -- the parse at the windows
  have hokX : StpOK pr.W (UInt64.ofNat 0)
      (opsStps ((A.run G).1 ++ Block.rootOps P (A.run G).2 ++ Block.fullOps P 0 (A.run G).2.slots)) :=
    stpOK_opsStps pr.W 0 _ (fun j hj => by rw [Nat.zero_add]; exact pr.W_lt j (by omega))
  have hpreM : tRem pr.W (slotTrace P key domain G (A.run G)) = some 0 := by
    have := tRem_opTrace_stps_nil pr.W (liftH G) _ (Tr.newKeyed (liftH G) domain key) hokX
    rwa [stpsOps_opsStps] at this
  have hokM : StpOK pr.W t''.counter (mStps pr.S (A.run G).2.maskOpen) := by
    rw [hkM]
    exact stpOK_mStps pr.W pr.S pr.cM _ (pr.W_r0 _ rfl) (pr.W_r1 _ rfl) (pr.W_r2 _ (by omega))
  have hpreA := tRem_opTrace_stps pr.W (liftH G) _ t'' _ hokM hpreM
  have hokA : StpOK pr.W tA.counter (pcsStps (pr.nA + pr.rA) pr.mI (A.run G).2.aOpen) := by
    rw [hkA]
    exact stpOK_pcsStps pr.W _ _ _ _ (pr.W_r3 _ rfl) pr.hwA (pr.W_r4 _ rfl) pr.hmI
  have hpreH := tRem_opTrace_stps pr.W (liftH G) _ tA _ hokA hpreA
  have hXl : (slotTrace P key domain G (A.run G)).length = pr.aM := by
    unfold slotTrace
    rw [Block.opTrace_length]
    exact hX0
  exact ⟨t'', tA, tH, tF, ⟨hch, hXl, hnf, hMok, hAok, hHok, hkM, hkA, hkH, hpreM, hpreA, hpreH⟩⟩

end Acc

/-! ## `hexec` at a geometry -/

section Hexec

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

include hU in
/-- **`hexec` at a geometry `(h, Q, e)`** (L20-3, deterministic): on the block verifier's acceptance with the profile's
header (the run's restriction, L22-1) and outside the extraction failure at the verifier's queries, each opening's and
`M`'s good predicate holds or its chain event does. Given the profile's fields (`maskField`; `pcsVerify` accepting only
when `PcsOk` holds), the claims' counts (L22-2), the accumulator's reader on the verifier's own trace (L22-7), the
slots' geometry, and `L ≥ 2^20`. -/
theorem hexec_geo {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (hL20 : 2 ^ 20 ≤ L) (hL64 : L < 2 ^ 64)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (accRd : List (TItem × Dig) → Block.Acc) (rowsOf : Block.Cm → ℕ)
    (prm : PcsPrm) (h Q e : ℕ) (ev : Fp → List (List Fp2) → List Fp2) (hlc : prm.logCols = 14)
    (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q) (hnn : prm.nn = 2 ^ h) (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q)
    (hQ15 : 2 ^ 14 + Q ≤ 2 ^ 15) (hm : (Q + 3) / 4 = pr.mI) (hQm : Q ≤ pr.mI * 4)
    (hspec : ColEncSpec U (RW (K := K)) Q (cosetPt (rootFp h)) ev)
    (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : ∀ (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag prm (cosetPt (rootFp h)) ev root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t t')
    (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hrows : 8 * pr.rA ≤ L ∧ 8 * pr.rH ≤ L ∧ 8 * (2 * pr.S + 4) ≤ L)
    (A : OC (QB L) Dig (List Op × Block.Core))
    (hcnt : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (hRd : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      sqN (A.run G).1 = pr.hdrSq →
        (accRd (slotTrace P key domain G (A.run G))).fs ++ (accRd (slotTrace P key domain G (A.run G))).hostFs
          = acc.fs ++ acc.hostFs
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.a = acc.claims.a
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.h = acc.claims.h) :
    ∀ G, (∃ bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc) → sqN (A.run G).1 = pr.hdrSq →
      ¬ EvXB pr.tag L (by omega) key domain hs hL Q Q 256 h h 12 A G →
      (GOW U pr L (by omega) key domain hs hL accRd h Q e pr.rA pr.nA pr.hdrLen pr.aA (fun acc => acc.claims.a) A G
          ∨ EvOW U hbij pr L (by omega) key domain hs hL accRd h Q e hQm pr.rA pr.nA pr.hdrLen
            (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (fun acc => acc.claims.a) A G)
        ∧ (GOW U pr L (by omega) key domain hs hL accRd h Q e pr.rH pr.nH (pr.hdrLen + 7) pr.aH
              (fun acc => acc.claims.h ++ [P.logupSumClaim]) A G
          ∨ EvOW U hbij pr L (by omega) key domain hs hL accRd h Q e hQm pr.rH pr.nH (pr.hdrLen + 7)
            (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim]) A G)
        ∧ (GMW U pr L (by omega) key domain hs hL accRd A G ∨ EvMW U hbij pr L (by omega) key domain hs hL accRd A G) := by
  have h64 : 64 ≤ L := by omega
  intro G hacc0 hsq hX
  obtain ⟨bga, rs, acc, hacc⟩ := hacc0
  obtain ⟨hcA, hcH⟩ := hcnt G bga rs acc hacc
  obtain ⟨hrd1, hrd2, hrd3⟩ := hRd G bga rs acc hacc hsq
  obtain ⟨tM, tA, tH, tF, R⟩ := run_acc pr L hL20 hL64 key domain hs hL rowsOf prm h Q ev hqp hnQ hnn hpow hQ0 hQ15 hm
    hPm hPp hrA hrH hgt hgeomL A hcnt G bga rs acc hacc hsq
  obtain ⟨⟨hlen, -, hcan, hshape, -⟩, -⟩ := hacc
  have hgA : (A.run G).2.aOpen.groupVecs.length = P.geom.aGroups := hshape.2.2.2.2.2.2.2.1
  have hgH : (A.run G).2.hOpen.groupVecs.length = P.geom.hGroups := hshape.2.2.2.2.2.2.2.2.1
  have hroots := Block.rootsAt_trace (liftH G) P (A.run G).2 (A.run G).1 (Block.fullOps P 0 (A.run G).2.slots)
    (Tr.newKeyed (liftH G) domain key)
  simp only [Block.rootsAt, Block.rootsOf, hlen, Prod.mk.injEq] at hroots
  have habsA : Block.absAt (slotTrace P key domain G (A.run G)) pr.hdrLen = some (A.run G).2.aRoot.toList := hroots.1
  have habsM : Block.absAt (slotTrace P key domain G (A.run G)) (pr.hdrLen + 3) = some (A.run G).2.maskRoot.toList :=
    hroots.2.1
  have habsH : Block.absAt (slotTrace P key domain G (A.run G)) (pr.hdrLen + 7) = some (A.run G).2.hRoot.toList :=
    hroots.2.2
  have hhd : pr.hdrLen + 7 < (slotTrace P key domain G (A.run G)).length := by
    rw [R.len]
    unfold OProf.aM
    omega
  refine ⟨?_, ?_, ?_⟩
  · -- `A`
    refine opening_alt U hU hbij pr L h64 key domain hs hL accRd A G prm ev h Q e hlc hqp hnQ hnn hpow hQ0 hm hQm hspec
      pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (fun acc => acc.claims.a)
      (slotTrace P key domain G (A.run G) ++ opTrace (liftH G) tM (stpsOps (mStps pr.S (A.run G).2.maskOpen)))
      (opTrace (liftH G) tH (stpsOps (pcsStps (pr.nH + pr.rH) pr.mI (A.run G).2.hOpen))) tA tH (A.run G).2.aOpen
      (by rw [List.length_append, R.len, Block.opTrace_length, stpsOps_mStps_length]; rfl) rfl
      (by unfold OProf.aBA; rw [hgA]) (by rw [R.chain]; simp only [List.append_assoc]) R.remA pr.hwA
      (by rw [R.cA]; exact pr.W_r3 _ rfl) ?_ acc.claims.a (A.run G).2.aRoot R.aok hcA ?_ hcan.2.2.1 ?_
    · show pr.W (runOps (liftH G) (runOps (liftH G) tA (List.replicate (pr.nA + pr.rA) Op.squeeze))
        (stpsOps (vecStps (A.run G).2.aOpen.groupVecs))).counter = pr.mI
      rw [ctr_runOps _ _ _ _ (ctr_runOps _ _ _ _ R.cA), sqN_replicate, sqN_stpsOps, stpsSq_vecStps, Nat.add_zero]
      exact pr.W_r4 _ rfl
    · rw [List.take_left' R.len]
      exact hrd2
    · intro k hk hkl hp hv hcl
      rw [getD_toOZ] at hp hv hcl ⊢
      have hcl2 : ((A.run G).2.aOpen.columns.getD k ⟨0, [], zeroDig, []⟩).col.length = pr.rA := hcl
      have hfit : 8 * ((A.run G).2.aOpen.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L := by
        rw [hcl2]
        exact hrows.1
      exact colX_of_col pr.tag L h64 key domain hs hL Q Q 256 h h 12 A G hX _ (by simp [rootsV]) h pr.hdrLen _
        (by rw [absAt_append_left _ _ _ (by omega)]; exact habsA) _ hfit hp hv
        (blockV_queries_A pr.tag L h64 Q Q 256 h h 12 A G _ (mem_colsV L Q _ k hk hkl hfit) hp)
  · -- `H`
    refine opening_alt U hU hbij pr L h64 key domain hs hL accRd A G prm ev h Q e hlc hqp hnQ hnn hpow hQ0 hm hQm hspec
      pr.rH pr.nH (pr.hdrLen + 7) (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim])
      (slotTrace P key domain G (A.run G) ++ opTrace (liftH G) tM (stpsOps (mStps pr.S (A.run G).2.maskOpen))
        ++ opTrace (liftH G) tA (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI (A.run G).2.aOpen))) [] tH tF
      (A.run G).2.hOpen ?_ rfl (by unfold OProf.aBH; rw [hgH])
      (by rw [R.chain]; simp only [List.append_assoc, List.append_nil]) R.remH pr.hwH
      (by rw [R.cH]; exact pr.W_r5 _ (by omega)) ?_ (acc.claims.h ++ [P.logupSumClaim]) (A.run G).2.hRoot R.hok hcH ?_
      hcan.2.2.2 ?_
    · rw [List.length_append, List.length_append, R.len, Block.opTrace_length, Block.opTrace_length,
        stpsOps_mStps_length, stpsOps_pcsStps_length, hgA]
      unfold OProf.aH OProf.aBA OProf.aA
      omega
    · show pr.W (runOps (liftH G) (runOps (liftH G) tH (List.replicate (pr.nH + pr.rH) Op.squeeze))
        (stpsOps (vecStps (A.run G).2.hOpen.groupVecs))).counter = pr.mI
      rw [ctr_runOps _ _ _ _ (ctr_runOps _ _ _ _ R.cH), sqN_replicate, sqN_stpsOps, stpsSq_vecStps, Nat.add_zero]
      exact pr.W_r6 _ (by omega)
    · simp only [List.append_assoc]
      rw [List.take_left' R.len]
      show (accRd (slotTrace P key domain G (A.run G))).claims.h ++ [P.logupSumClaim] = _
      rw [hrd3]
    · intro k hk hkl hp hv hcl
      rw [getD_toOZ] at hp hv hcl ⊢
      have hcl2 : ((A.run G).2.hOpen.columns.getD k ⟨0, [], zeroDig, []⟩).col.length = pr.rH := hcl
      have hfit : 8 * ((A.run G).2.hOpen.columns.getD k ⟨0, [], zeroDig, []⟩).col.length ≤ L := by
        rw [hcl2]
        exact hrows.2.1
      exact colX_of_col pr.tag L h64 key domain hs hL Q Q 256 h h 12 A G hX _ (by simp [rootsV]) h (pr.hdrLen + 7) _
        (by simp only [List.append_assoc]; rw [absAt_append_left _ _ _ hhd]; exact habsH) _ hfit hp hv
        (blockV_queries_H pr.tag L h64 Q Q 256 h h 12 A G _ (mem_colsV L Q _ k hk hkl hfit) hp)
  · -- `M`
    refine mask_alt U hU hbij pr L h64 key domain hs hL accRd A G (slotTrace P key domain G (A.run G))
      (opTrace (liftH G) tA (stpsOps (pcsStps (pr.nA + pr.rA) pr.mI (A.run G).2.aOpen))
        ++ opTrace (liftH G) tH (stpsOps (pcsStps (pr.nH + pr.rH) pr.mI (A.run G).2.hOpen))) tM tA R.len
      (by rw [R.chain]; simp only [List.append_assoc]) (acc.fs ++ acc.hostFs) hcan.2.1 R.mok
      (by rw [R.cM]; exact pr.W_r0 _ rfl)
      (by rw [ctr_squeeze _ _ _ R.cM]; exact pr.W_r1 _ rfl)
      (by rw [ctr_runOps _ _ _ (pr.cM + 1) (ctr_squeeze _ _ _ R.cM), sqN_replicate]; exact pr.W_r2 _ (by omega))
      R.remM R.nf hrd1 ?_
    intro j hj
    obtain ⟨-, -, -, idx', hidx', hcl', hco'⟩ := R.mok
    have hidxe : idx' = idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM
        (stpsOps (mPre pr.S (A.run G).2.maskOpen))) 64) := by
      rw [runOps_mPre]
      rw [challengeIndices_sqDs (liftH G) mQ mDom _ (by decide) (by decide)] at hidx'
      simp only [Option.some.injEq, Prod.mk.injEq] at hidx'
      exact hidx'.1.symm
    have hjl : (j : ℕ) < (toMO (A.run G).2.maskOpen).columns.length := by
      rw [hcl', hidxe, idxOf_length, sqDs_length]
      have := j.isLt
      have e : mQ = 256 := rfl
      omega
    have hjl' : (j : ℕ) < (A.run G).2.maskOpen.columns.length := by
      have e : (toMO (A.run G).2.maskOpen).columns.length = (A.run G).2.maskOpen.columns.length := List.length_map _
      rw [← e]
      exact hjl
    have hc := hco' j hjl
    rw [getD_toMO] at hc
    have hj1 : ((A.run G).2.maskOpen.columns.getD j ⟨0, [], zeroDig, []⟩).j
        = (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre pr.S (A.run G).2.maskOpen))) 64)).getD j
          0 := by
      rw [← hidxe]
      exact hc.1
    have hcl2 : ((A.run G).2.maskOpen.columns.getD j ⟨0, [], zeroDig, []⟩).col.length = 2 * pr.S + 4 := hc.2.1
    have hfitM : 8 * ((A.run G).2.maskOpen.columns.getD j ⟨0, [], zeroDig, []⟩).col.length ≤ L := by
      rw [hcl2]
      exact hrows.2.2
    have hx := colX_of_col pr.tag L h64 key domain hs hL Q Q 256 h h 12 A G hX _ (by simp [rootsV]) 12 (pr.hdrLen + 3)
      (slotTrace P key domain G (A.run G)) habsM _ hfitM hc.2.2.1 hc.2.2.2.1
      (blockV_queries_M pr.tag L h64 Q Q 256 h h 12 A G _
        (mem_colsV L 256 _ j (by have := j.isLt; have e : mQ = 256 := rfl; omega) hjl' hfitM) hc.2.2.1)
    show ((colX pr.tag L h64 key domain hs hL 12 (pr.hdrLen + 3) (A.runLog G).2 (slotTrace P key domain G (A.run G))
      ((idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre pr.S (A.run G).2.maskOpen))) 64)).getD j
        0)).map Subtype.val).getD [] = _
    rw [← hj1, hx]
    rfl

end Hexec

/-! ## `hsem` at a geometry: the good predicates make the block's own claims and functionals true -/

section Sem

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L)

/-- **The column extracted from a cut log** for the root a statement shows (its bytes read as a digest). -/
noncomputable def colXc (d : ℕ) (cut : List (QB L × Dig)) (rb : Option (List UInt8)) (j : ℕ) : Option (ColV L) :=
  match rb.bind digOf? with
  | some r => (merkleEncV tag L h64).extractCol cut d j r
  | none => none

variable {K : Type} [Field K] [Algebra GF K]

/-- **The extracted matrix of a statement** (its cut log and root): what `csX` reads for `A` and `H`. -/
noncomputable def UxC (d rows : ℕ) {N : ℕ} (cut : List (QB L × Dig)) (rb : Option (List UInt8)) :
    Fin rows → Fin N → K :=
  fun r j => algebraMap GF K ((((colXc tag L h64 d cut rb j).map Subtype.val).getD []).getD r Fp.zero).toGF

/-- **The extracted `M` table of a statement**: what `msX` reads. -/
noncomputable def colsC (cut : List (QB L × Dig)) (rb : Option (List UInt8)) : Fin (2 ^ 12) → List Fp :=
  fun j => ((colXc tag L h64 12 cut rb j).map Subtype.val).getD []

/-- On a header showing the root `r` at position `i`, the chain-side extraction is the statement-side one. -/
theorem colX_eq_colXc (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (d i : ℕ) (log : List (QB L × Dig)) (hdr : List (TItem × Dig)) (r : Dig)
    (hr : Block.absAt hdr i = some r.toList) (j : ℕ) :
    colX tag L h64 key domain hs hL d i log hdr j
      = colXc tag L h64 d (Block.cutO (Block.absOfC (chainEncB key domain hs L hL)) (some r.toList) log)
          (some r.toList) j := by
  rw [colX_root tag L h64 key domain hs hL d i log hdr r hr, cutAt_absD]
  unfold colXc
  rw [Option.bind_some, digOf?_toList]
  rfl

end Sem

section Hsem

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K)

omit [DecidableEq K] in
theorem mGood_mTrue' (S : ℕ) (fs : List Block.MaskFunctional) (k : ℕ) (hk : fs.length = k)
    (cols : Fin (2 ^ 12) → List Fp)
    (hg : MGood (mEtaE (K := K)) (mOmega (K := K)) 1 1024 1023 (mDataOf U S k fs cols).wt
      (mDataOf U S k fs cols).val (mDataOf U S k fs cols).Ub (mDataOf U S k fs cols).u
      (mDataOf U S k fs cols).La (mDataOf U S k fs cols).Lb) :
    ∀ mf ∈ fs, msOfTab U S cols mf.terms = mf.value.toK U := by
  subst hk
  exact mGood_mTrue U S fs cols hg

/-- **`hsem` at a geometry `(h, Q, e)`** (L20-3, deterministic): on the block verifier's acceptance with the profile's
header, the openings' and `M`'s good predicates make the block's own part `OpenBlk` true of the extracted data: every
claim of `A` and of `H` (its LogUp sum claim included, L21-3) and every functional `M` received (the hosts' included,
L21-2), for the semantics `csX`, `msX` that read the extracted matrices and table (`hcsA`, `hcsH`, `hms`). -/
theorem hsem_geo {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (hL20 : 2 ^ 20 ≤ L) (hL64 : L < 2 ^ 64)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (accRd : List (TItem × Dig) → Block.Acc) (rowsOf : Block.Cm → ℕ)
    (prm : PcsPrm) (h Q e : ℕ) (ev : Fp → List (List Fp2) → List Fp2)
    (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q) (hnn : prm.nn = 2 ^ h) (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q)
    (hQ15 : 2 ^ 14 + Q ≤ 2 ^ 15) (hm : (Q + 3) / 4 = pr.mI)
    (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : ∀ (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag prm (cosetPt (rootFp h)) ev root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t t')
    (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (A : OC (QB L) Dig (List Op × Block.Core))
    (hcnt : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (hRd : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      sqN (A.run G).1 = pr.hdrSq →
        (accRd (slotTrace P key domain G (A.run G))).fs ++ (accRd (slotTrace P key domain G (A.run G))).hostFs
          = acc.fs ++ acc.hostFs
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.a = acc.claims.a
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.h = acc.claims.h)
    (csX : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K)
    (msX : Block.Cuts3 L → Block.RootsO → List (ℕ × List Fp2) → K)
    (hcsA : ∀ cu rt z, csX cu rt .a z = claimSem U pr.rA 14 Q
      (decodeRows (encG (K := K) h Q) e (UxC pr.tag L (by omega) h pr.rA (N := 2 ^ h) cu.1 rt.1)) z)
    (hcsH : ∀ cu rt z, csX cu rt .h z = claimSem U pr.rH 14 Q
      (decodeRows (encG (K := K) h Q) e (UxC pr.tag L (by omega) h pr.rH (N := 2 ^ h) cu.2.2 rt.2.2)) z)
    (hms : ∀ cu rt ts, msX cu rt ts = msOfTab U pr.S (colsC pr.tag L (by omega) cu.2.1 rt.2.1) ts) :
    ∀ G, (∃ bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc ∧ sqN (A.run G).1 = pr.hdrSq
        ∧ ¬ Block.OpenBlk U P (csX (Block.cutsOf key domain hs hL A G) (Block.rootsOf (A.run G).2))
          (msX (Block.cutsOf key domain hs hL A G) (Block.rootsOf (A.run G).2)) acc) →
      ¬ (GOW U pr L (by omega) key domain hs hL accRd h Q e pr.rA pr.nA pr.hdrLen pr.aA (fun acc => acc.claims.a) A G
        ∧ GOW U pr L (by omega) key domain hs hL accRd h Q e pr.rH pr.nH (pr.hdrLen + 7) pr.aH
          (fun acc => acc.claims.h ++ [P.logupSumClaim]) A G
        ∧ GMW U pr L (by omega) key domain hs hL accRd A G) := by
  have h64 : 64 ≤ L := by omega
  rintro G ⟨bga, rs, acc, hacc, hsq, hnb⟩ ⟨ga, gh, gm⟩
  apply hnb
  obtain ⟨hcA, hcH⟩ := hcnt G bga rs acc hacc
  obtain ⟨hrd1, hrd2, hrd3⟩ := hRd G bga rs acc hacc hsq
  obtain ⟨tM, tA, tH, tF, R⟩ := run_acc pr L hL20 hL64 key domain hs hL rowsOf prm h Q ev hqp hnQ hnn hpow hQ0 hQ15 hm
    hPm hPp hrA hrH hgt hgeomL A hcnt G bga rs acc hacc hsq
  have hlen := hacc.1.1
  have hroots := Block.rootsAt_trace (liftH G) P (A.run G).2 (A.run G).1 (Block.fullOps P 0 (A.run G).2.slots)
    (Tr.newKeyed (liftH G) domain key)
  simp only [Block.rootsAt, Block.rootsOf, hlen, Prod.mk.injEq] at hroots
  have habsA : Block.absAt (slotTrace P key domain G (A.run G)) pr.hdrLen = some (A.run G).2.aRoot.toList := hroots.1
  have habsM : Block.absAt (slotTrace P key domain G (A.run G)) (pr.hdrLen + 3) = some (A.run G).2.maskRoot.toList :=
    hroots.2.1
  have habsH : Block.absAt (slotTrace P key domain G (A.run G)) (pr.hdrLen + 7) = some (A.run G).2.hRoot.toList :=
    hroots.2.2
  -- the chain's prefixes
  have hXl := R.len
  have hrest := R.chain
  have htk : ∀ a, pr.aM ≤ a → ((chW pr L key domain hs hL G (A.run G)).take a).take pr.aM
      = slotTrace P key domain G (A.run G) := by
    intro a ha
    rw [List.take_take, min_eq_left ha, hrest, List.take_left' hXl]
  have habs : ∀ a i, pr.aM ≤ a → i < pr.aM →
      Block.absAt ((chW pr L key domain hs hL G (A.run G)).take a) i
        = Block.absAt (slotTrace P key domain G (A.run G)) i := by
    intro a i ha hi
    rw [← htk a ha, absAt_take _ _ _ hi]
  have haA : pr.aM ≤ pr.aA := by unfold OProf.aA; omega
  have haH : pr.aM ≤ pr.aH := by unfold OProf.aH OProf.aBA OProf.aA; omega
  have hhd : pr.hdrLen + 7 < pr.aM := by unfold OProf.aM; omega
  have hUA : UxW (K := K) pr.tag L h64 key domain hs hL h pr.hdrLen pr.rA (N := 2 ^ h) (A.runLog G).2
      ((chW pr L key domain hs hL G (A.run G)).take pr.aA)
      = UxC pr.tag L h64 h pr.rA (Block.cutsOf key domain hs hL A G).1 (Block.rootsOf (A.run G).2).1 := by
    funext r j
    unfold UxW UxC
    rw [colX_eq_colXc pr.tag L h64 key domain hs hL h pr.hdrLen _ _ (A.run G).2.aRoot
      (by rw [habs _ _ haA (by omega)]; exact habsA)]
    rfl
  have hUH : UxW (K := K) pr.tag L h64 key domain hs hL h (pr.hdrLen + 7) pr.rH (N := 2 ^ h) (A.runLog G).2
      ((chW pr L key domain hs hL G (A.run G)).take pr.aH)
      = UxC pr.tag L h64 h pr.rH (Block.cutsOf key domain hs hL A G).2.2 (Block.rootsOf (A.run G).2).2.2 := by
    funext r j
    unfold UxW UxC
    rw [colX_eq_colXc pr.tag L h64 key domain hs hL h (pr.hdrLen + 7) _ _ (A.run G).2.hRoot
      (by rw [habs _ _ haH hhd]; exact habsH)]
    rfl
  unfold GOW clOfO at ga gh
  beta_reduce at ga gh
  rw [htk _ haA, hrd2, hUA] at ga
  rw [htk _ haH, hrd3, hUH] at gh
  refine ⟨fun c hc => ?_, fun c hc => ?_, fun mf hmf => ?_, ?_⟩
  · -- `A`'s claims
    rw [hcsA]
    exact groupsGood_claimSem U pr.rA 14 Q _ _ _ acc.claims.a pr.nA hcA ga c hc
  · -- `H`'s claims
    rw [hcsH]
    exact groupsGood_claimSem U pr.rH 14 Q _ _ _ (acc.claims.h ++ [P.logupSumClaim]) pr.nH hcH gh c
      (List.mem_append_left _ hc)
  · -- `M`'s functionals
    have htkM : (chW pr L key domain hs hL G (A.run G)).take pr.aM = slotTrace P key domain G (A.run G) := by
      rw [hrest, List.take_left' hXl]
    have hc' : colsM pr.tag L h64 key domain hs hL pr.hdrLen (A.runLog G).2 (slotTrace P key domain G (A.run G))
        = colsC pr.tag L h64 (Block.cutsOf key domain hs hL A G).2.1 (Block.rootsOf (A.run G).2).2.1 := by
      funext j
      unfold colsM colsC
      rw [colX_eq_colXc pr.tag L h64 key domain hs hL 12 (pr.hdrLen + 3) _ _ (A.run G).2.maskRoot habsM]
      rfl
    unfold GMW DmW at gm
    rw [htkM, hrd1, hc'] at gm
    rw [hms]
    exact mGood_mTrue' U pr.S _ P.nFunctionals R.nf _ gm mf hmf
  · -- `H`'s LogUp sum claim
    rw [hcsH]
    exact groupsGood_claimSem U pr.rH 14 Q _ _ _ (acc.claims.h ++ [P.logupSumClaim]) pr.nH hcH gh _
      (List.mem_append_right _ (List.mem_singleton_self _))

end Hsem

/-! ## The per-kind cover (for the run-level count) -/

section Cover

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

include hU in
/-- **The per-kind cover at a geometry `(h, Q, e)`** (`hsem_geo` and `hexec_geo` together, as an inclusion of events;
the form a run-level count over the blocks' kinds needs, L24-7): on the block verifier's acceptance with the profile's
header, if the block's own part `OpenBlk` fails of the extracted data, then `M`'s chain event holds, or `A`'s, or
`H`'s, or the extraction failure at the verifier's queries. Each of the four has its own bound (`evMW_bound`,
`evOW_bound` twice, L22's `extract_fail_block`). -/
theorem open_cover_geo {P : Block.BlockParams} (pr : OProf P) (L : ℕ) (hL20 : 2 ^ 20 ≤ L) (hL64 : L < 2 ^ 64)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (accRd : List (TItem × Dig) → Block.Acc) (rowsOf : Block.Cm → ℕ)
    (prm : PcsPrm) (h Q e : ℕ) (ev : Fp → List (List Fp2) → List Fp2) (hlc : prm.logCols = 14)
    (hqp : prm.qPad = Q) (hnQ : prm.nQ = Q) (hnn : prm.nn = 2 ^ h) (hpow : isPow2 prm.nn = true) (hQ0 : 0 < Q)
    (hQ15 : 2 ^ 14 + Q ≤ 2 ^ 15) (hm : (Q + 3) / 4 = pr.mI) (hQm : Q ≤ pr.mI * 4)
    (hspec : ColEncSpec U (RW (K := K)) Q (cosetPt (rootFp h)) ev)
    (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : ∀ (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag prm (cosetPt (rootFp h)) ev root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t t')
    (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hrows : 8 * pr.rA ≤ L ∧ 8 * pr.rH ≤ L ∧ 8 * (2 * pr.S + 4) ≤ L)
    (A : OC (QB L) Dig (List Op × Block.Core))
    (hcnt : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (hRd : ∀ G bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      sqN (A.run G).1 = pr.hdrSq →
        (accRd (slotTrace P key domain G (A.run G))).fs ++ (accRd (slotTrace P key domain G (A.run G))).hostFs
          = acc.fs ++ acc.hostFs
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.a = acc.claims.a
        ∧ (accRd (slotTrace P key domain G (A.run G))).claims.h = acc.claims.h)
    (csX : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K)
    (msX : Block.Cuts3 L → Block.RootsO → List (ℕ × List Fp2) → K)
    (hcsA : ∀ cu rt z, csX cu rt .a z = claimSem U pr.rA 14 Q
      (decodeRows (encG (K := K) h Q) e (UxC pr.tag L (by omega) h pr.rA (N := 2 ^ h) cu.1 rt.1)) z)
    (hcsH : ∀ cu rt z, csX cu rt .h z = claimSem U pr.rH 14 Q
      (decodeRows (encG (K := K) h Q) e (UxC pr.tag L (by omega) h pr.rH (N := 2 ^ h) cu.2.2 rt.2.2)) z)
    (hms : ∀ cu rt ts, msX cu rt ts = msOfTab U pr.S (colsC pr.tag L (by omega) cu.2.1 rt.2.1) ts) :
    ∀ G, (∃ bga rs acc, Block.BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc ∧ sqN (A.run G).1 = pr.hdrSq
        ∧ ¬ Block.OpenBlk U P (csX (Block.cutsOf key domain hs hL A G) (Block.rootsOf (A.run G).2))
          (msX (Block.cutsOf key domain hs hL A G) (Block.rootsOf (A.run G).2)) acc) →
      EvMW U hbij pr L (by omega) key domain hs hL accRd A G
        ∨ EvOW U hbij pr L (by omega) key domain hs hL accRd h Q e hQm pr.rA pr.nA pr.hdrLen
          (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (fun acc => acc.claims.a) A G
        ∨ EvOW U hbij pr L (by omega) key domain hs hL accRd h Q e hQm pr.rH pr.nH (pr.hdrLen + 7)
          (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim]) A G
        ∨ EvXB pr.tag L (by omega) key domain hs hL Q Q 256 h h 12 A G := by
  intro G hG
  by_cases hX : EvXB pr.tag L (by omega) key domain hs hL Q Q 256 h h 12 A G
  · exact Or.inr (Or.inr (Or.inr hX))
  obtain ⟨bga, rs, acc, hacc, hsq, hnb⟩ := hG
  obtain ⟨ha, hh', hm'⟩ := hexec_geo U hU hbij pr L hL20 hL64 key domain hs hL accRd rowsOf prm h Q e ev hlc hqp hnQ hnn
    hpow hQ0 hQ15 hm hQm hspec hPm hPp hrA hrH hgt hgeomL hrows A hcnt hRd G ⟨bga, rs, acc, hacc⟩ hsq hX
  have hns := hsem_geo U pr L hL20 hL64 key domain hs hL accRd rowsOf prm h Q e ev hqp hnQ hnn hpow hQ0 hQ15 hm hPm hPp
    hrA hrH hgt hgeomL A hcnt hRd csX msX hcsA hcsH hms G ⟨bga, rs, acc, hacc, hsq, hnb⟩
  rcases hm' with gm | em
  · rcases ha with ga | ea
    · rcases hh' with gh | eh
      · exact absurd ⟨ga, gh, gm⟩ hns
      · exact Or.inr (Or.inr (Or.inl eh))
    · exact Or.inr (Or.inl ea)
  · exact Or.inl em

end Cover

end ZK60.Exec.Link
