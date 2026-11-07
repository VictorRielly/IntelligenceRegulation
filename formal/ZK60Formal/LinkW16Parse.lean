/-
D63 lane L22 (2026-11-07), part 1: **the step parse of the verifier's operations, made concrete** (finding L16-2; the
parse half of L20-3's `hexec`).

The theorems of `CountW16Chain.lean` / `OpenKnowChain.lean` read a sub-protocol's rounds off the code's chain under a
FIXED step parse `W` (the width of the step a squeeze with counter `k` starts) and a chain built from step HEADS by
`stepsB`. Here the block verifier's operations are written as steps, and the parse is proved to be the code's:

* `Stp`, `stpsOps`, `stpHeads`, `StpOK`: the operations as steps (one absorb, or a run of `n` squeezes: one challenge
  vector), their heads with the code's counters, and the agreement of `W` with the runs (`W c = n` at a run's first
  counter);
* `opItems_replicate`, `opsCtr_replicate`, `stepsB_items_sq`, **`flatMap_stpHeads`**: the heads, expanded by `stepsB`,
  are exactly the code's items;
* **`cChain_stps`**: so the chain the FS theorems read (`cChain` of `chainEncB` and `stepsB`) IS the executable
  transcript's trace (`opTrace`) of the operations, for every oracle `G`;
* **`tRem_opTrace_stps`**: the trace of whole steps parses as whole steps (`tRem W = some 0`);
* `cRd_run_sq`, `cRdStep_absorb_msg`: the scheduled reader takes a run's digests as one round and an absorb under the
  round's label as its message;
* `sqDs`, **`challengeFp2Vec_sqDs`**, **`challengeIndices_sqDs`**: the code's challenges (`challenge_fp2_vec`,
  `challenge_indices`) are functions of the run's digests on the trace (the challenge half of L20-3 (c)).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.OpenKnowBlock

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## Counters -/

theorem u64_add_ofNat_zero (c : UInt64) : c + UInt64.ofNat 0 = c := by
  apply UInt64.toNat_inj.1
  have hc : c.toNat < 2 ^ 64 := c.toNat_lt_size
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat']
  omega

theorem u64_add_succ (c : UInt64) (j : ℕ) : c + UInt64.ofNat (j + 1) = c + 1 + UInt64.ofNat j := by
  apply UInt64.toNat_inj.1
  have hc : c.toNat < 2 ^ 64 := c.toNat_lt_size
  have hone : (1 : UInt64).toNat = 1 := rfl
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat', hone]
  omega

theorem u64_add_add (c : UInt64) (a b : ℕ) : c + UInt64.ofNat a + UInt64.ofNat b = c + UInt64.ofNat (a + b) := by
  apply UInt64.toNat_inj.1
  have hc : c.toNat < 2 ^ 64 := c.toNat_lt_size
  simp only [UInt64.toNat_add, UInt64.toNat_ofNat']
  omega

theorem u64_ofNat_toNat {n : ℕ} (h : n < 2 ^ 64) : (UInt64.ofNat n).toNat = n := by
  rw [UInt64.toNat_ofNat']
  exact Nat.mod_eq_of_lt h

/-- `n` squeezes' items: the counters `c, c + 1, …`. -/
theorem opItems_replicate : ∀ (n : ℕ) (c : UInt64),
    opItems c (List.replicate n Op.squeeze) = (List.range n).map (fun j => TItem.squeeze (c + UInt64.ofNat j))
  | 0, _ => rfl
  | n + 1, c => by
    rw [List.replicate_succ, opItems, opItems_replicate n (c + 1), List.range_succ_eq_map, List.map_cons,
      List.map_map, u64_add_ofNat_zero]
    congr 1
    refine List.map_congr_left (fun j _ => ?_)
    simp only [Function.comp_apply, u64_add_succ]

/-- `n` squeezes advance the counter by `n`. -/
theorem opsCtr_replicate : ∀ (n : ℕ) (c : UInt64), opsCtr c (List.replicate n Op.squeeze) = c + UInt64.ofNat n
  | 0, c => (u64_add_ofNat_zero c).symm
  | n + 1, c => by
    rw [List.replicate_succ, opsCtr, opsCtr_replicate n (c + 1), u64_add_succ]

/-! ## The verifier's operations as steps -/

/-- **A step of the verifier's operations**: one absorb, or a run of `n` squeezes (one challenge, or a vector). -/
inductive Stp
  | ab (l x : List UInt8)
  | sq (n : ℕ)

/-- A step's operations. -/
def Stp.ops : Stp → List Op
  | .ab l x => [.absorb l x]
  | .sq n => List.replicate n .squeeze

/-- The squeezes of a step. -/
def Stp.nsq : Stp → ℕ
  | .ab _ _ => 0
  | .sq n => n

/-- The operations of a list of steps. -/
def stpsOps (ss : List Stp) : List Op := ss.flatMap Stp.ops

/-- The squeezes of a list of steps. -/
def stpsSq (ss : List Stp) : ℕ := (ss.map Stp.nsq).sum

theorem stpsOps_nil : stpsOps [] = [] := rfl

theorem stpsOps_cons (s : Stp) (ss : List Stp) : stpsOps (s :: ss) = s.ops ++ stpsOps ss := by
  simp [stpsOps]

theorem stpsOps_append (a b : List Stp) : stpsOps (a ++ b) = stpsOps a ++ stpsOps b := by
  simp [stpsOps]

theorem stpsSq_cons (s : Stp) (ss : List Stp) : stpsSq (s :: ss) = s.nsq + stpsSq ss := by
  simp [stpsSq]

theorem stpsSq_append (a b : List Stp) : stpsSq (a ++ b) = stpsSq a + stpsSq b := by
  simp [stpsSq]

/-- **The step heads**, the squeezes carrying the code's counter from `c` on: an absorb, or a run's FIRST squeeze. -/
def stpHeads : UInt64 → List Stp → List TItem
  | _, [] => []
  | c, .ab l x :: ss => .absorb l x :: stpHeads c ss
  | c, .sq n :: ss => .squeeze c :: stpHeads (c + UInt64.ofNat n) ss

/-- **The widths agree with the steps**: each run of `n ≥ 1` squeezes starting at counter `c` has `W c = n`. -/
def StpOK (W : UInt64 → ℕ) : UInt64 → List Stp → Prop
  | _, [] => True
  | c, .ab _ _ :: ss => StpOK W c ss
  | c, .sq n :: ss => W c = n ∧ 0 < n ∧ StpOK W (c + UInt64.ofNat n) ss

theorem opsCtr_stpsOps : ∀ (c : UInt64) (ss : List Stp), opsCtr c (stpsOps ss) = c + UInt64.ofNat (stpsSq ss)
  | c, [] => (u64_add_ofNat_zero c).symm
  | c, .ab l x :: ss => by
    rw [stpsOps_cons, opsCtr_append, stpsSq_cons]
    show opsCtr c (stpsOps ss) = c + UInt64.ofNat (0 + stpsSq ss)
    rw [opsCtr_stpsOps c ss, Nat.zero_add]
  | c, .sq n :: ss => by
    rw [stpsOps_cons, opsCtr_append, stpsSq_cons]
    show opsCtr (opsCtr c (List.replicate n Op.squeeze)) (stpsOps ss) = c + UInt64.ofNat (n + stpsSq ss)
    rw [opsCtr_replicate, opsCtr_stpsOps, u64_add_add]

theorem StpOK.append (W : UInt64 → ℕ) : ∀ (c : UInt64) (a b : List Stp), StpOK W c a →
    StpOK W (c + UInt64.ofNat (stpsSq a)) b → StpOK W c (a ++ b)
  | c, [], b, _, hb => by
    rw [show stpsSq [] = 0 from rfl, u64_add_ofNat_zero] at hb
    exact hb
  | c, .ab l x :: a, b, ha, hb => by
    rw [stpsSq_cons] at hb
    exact StpOK.append W c a b ha (by simpa [Stp.nsq] using hb)
  | c, .sq n :: a, b, ha, hb => by
    obtain ⟨h1, h2, h3⟩ := ha
    rw [stpsSq_cons] at hb
    refine ⟨h1, h2, StpOK.append W (c + UInt64.ofNat n) a b h3 ?_⟩
    rw [u64_add_add]
    simpa [Stp.nsq] using hb

/-- Every head is one of the code's items. -/
theorem stpHeads_mem (W : UInt64 → ℕ) : ∀ (c : UInt64) (ss : List Stp), StpOK W c ss →
    ∀ it ∈ stpHeads c ss, it ∈ opItems c (stpsOps ss)
  | _, [], _, it, hit => by simp [stpHeads] at hit
  | c, .ab l x :: ss, hok, it, hit => by
    rw [stpsOps_cons]
    simp only [stpHeads, List.mem_cons] at hit
    show it ∈ opItems c (.absorb l x :: stpsOps ss)
    rw [opItems, List.mem_cons]
    rcases hit with rfl | hit
    · exact Or.inl rfl
    · exact Or.inr (stpHeads_mem W c ss hok it hit)
  | c, .sq n :: ss, hok, it, hit => by
    obtain ⟨-, hn, hok'⟩ := hok
    rw [stpsOps_cons, opItems_append]
    simp only [stpHeads, List.mem_cons] at hit
    rcases hit with rfl | hit
    · refine List.mem_append_left _ ?_
      show TItem.squeeze c ∈ opItems c (List.replicate n Op.squeeze)
      obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
      rw [List.replicate_succ, opItems]
      exact List.mem_cons_self
    · refine List.mem_append_right _ ?_
      show it ∈ opItems (opsCtr c (List.replicate n Op.squeeze)) (stpsOps ss)
      rw [opsCtr_replicate]
      exact stpHeads_mem W (c + UInt64.ofNat n) ss hok' it hit

/-! ## The heads, expanded, are the code's items; the chain is the trace -/

section Chain

variable (L : ℕ) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64)

/-- A squeeze head's step is the run of squeezes with the counters `k, k + 1, …` (`stepsB`'s continuation). -/
theorem stepsB_items_sq (k : UInt64) (h : (TItem.squeeze k).Ok ∧ (TItem.squeeze k).len ≤ L) :
    ((stepsB L W hW hW64).items ⟨.squeeze k, h⟩).map Subtype.val
      = opItems k (List.replicate (W k) Op.squeeze) := by
  rw [opItems_replicate]
  simp only [Steps.items, stepsB, tWd, List.map_map]
  refine List.map_congr_left (fun j _ => ?_)
  cases j with
  | zero =>
    show TItem.squeeze k = TItem.squeeze (k + UInt64.ofNat 0)
    rw [u64_add_ofNat_zero]
  | succ j =>
    show TItem.squeeze (k + 1 + UInt64.ofNat j) = TItem.squeeze (k + UInt64.ofNat (j + 1))
    rw [u64_add_succ]

/-- An absorb head's step is itself. -/
theorem stepsB_items_ab (l x : List UInt8) (h : (TItem.absorb l x).Ok ∧ (TItem.absorb l x).len ≤ L) :
    (stepsB L W hW hW64).items ⟨.absorb l x, h⟩ = [⟨.absorb l x, h⟩] := by
  simp [Steps.items, stepsB, tWd, stepItem]

omit hW hW64 in
theorem liftItems_cons_fit (it : TItem) (its : List TItem) (h : it.Ok ∧ it.len ≤ L) :
    liftItems L (it :: its) = ⟨it, h⟩ :: liftItems L its := by
  rw [liftItems, dite_eq_left h]

/-- **The heads, expanded by `stepsB`, are exactly the code's items** (each run's first squeeze starts a step of the
run's width). -/
theorem flatMap_stpHeads : ∀ (c : UInt64) (ss : List Stp), StpOK W c ss →
    (∀ it ∈ stpHeads c ss, it.Ok ∧ it.len ≤ L) →
    ((liftItems L (stpHeads c ss)).flatMap (stepsB L W hW hW64).items).map Subtype.val = opItems c (stpsOps ss)
  | _, [], _, _ => rfl
  | c, .ab l x :: ss, hok, hfit => by
    have h0 : (TItem.absorb l x).Ok ∧ (TItem.absorb l x).len ≤ L := hfit _ List.mem_cons_self
    rw [stpHeads, liftItems_cons_fit L _ _ h0, List.flatMap_cons, List.map_append, stepsB_items_ab L W hW hW64 l x h0,
      flatMap_stpHeads c ss hok (fun it hit => hfit it (List.mem_cons_of_mem _ hit)), stpsOps_cons]
    rfl
  | c, .sq n :: ss, hok, hfit => by
    obtain ⟨hWc, hn, hok'⟩ := hok
    have h0 : (TItem.squeeze c).Ok ∧ (TItem.squeeze c).len ≤ L := hfit _ List.mem_cons_self
    rw [stpHeads, liftItems_cons_fit L _ _ h0, List.flatMap_cons, List.map_append, stepsB_items_sq L W hW hW64 c h0,
      flatMap_stpHeads (c + UInt64.ofNat n) ss hok' (fun it hit => hfit it (List.mem_cons_of_mem _ hit)),
      stpsOps_cons, opItems_append, hWc]
    show _ = opItems c (List.replicate n Op.squeeze) ++ opItems (opsCtr c (List.replicate n Op.squeeze)) (stpsOps ss)
    rw [opsCtr_replicate]

/-- **The chain the FS theorems read is the executable trace** (L16-2 made concrete): for every oracle `G`, the
`cChain` of `chainEncB` with `stepsB`'s widths `W`, built from the step heads, is `opTrace` of the operations on the
code's transcript `Tr.newKeyed`, when the widths agree with the runs and every operation fits `L`. -/
theorem cChain_stps (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (G : QB L → Dig) (ss : List Stp) (hok : StpOK W 0 ss)
    (hfit : ∀ op ∈ stpsOps ss, op.len ≤ L) :
    cChain (chainEncB key domain hs L hL) (fun it => it.1) (stepsB L W hW hW64) G (liftItems L (stpHeads 0 ss))
      = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps ss) := by
  have hits : ∀ it ∈ opItems 0 (stpsOps ss), it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 _ hfit
  have hheads : ∀ it ∈ stpHeads 0 ss, it.Ok ∧ it.len ≤ L := fun it hit => hits it (stpHeads_mem W 0 ss hok it hit)
  have hflat : (liftItems L (stpHeads 0 ss)).flatMap (stepsB L W hW hW64).items
      = liftItems L (opItems 0 (stpsOps ss)) := by
    apply List.map_injective_iff.mpr Subtype.val_injective
    rw [flatMap_stpHeads L W hW hW64 0 ss hok hheads, liftItems_val L _ hits]
  have hv : ((liftItems L (opItems 0 (stpsOps ss))).map ItB.toIt).map Subtype.val = opItems 0 (stpsOps ss) := by
    rw [List.map_map]
    exact liftItems_val L _ hits
  have htr := opTrace_chainFrom (liftH G) key domain hs (stpsOps ss) (Tr.newKeyed (liftH G) domain key) []
    ((liftItems L (opItems 0 (stpsOps ss))).map ItB.toIt) rfl rfl hv
  simp only [List.length_nil, List.drop_zero] at htr
  have hcl := chainFrom_liftH key domain hs L hL G (liftItems L (opItems 0 (stpsOps ss))) []
  rw [List.map_nil] at hcl
  unfold cChain
  rw [hflat, htr, hcl, List.map_map]
  rfl

end Chain

/-! ## The parse of a trace of whole steps -/

section Parse

variable (W : UInt64 → ℕ) (H : HIn → Dig)

/-- A run of squeezes' trace: squeezes only. -/
theorem opTrace_rep_sq : ∀ (n : ℕ) (t : Tr), ∀ e ∈ opTrace H t (List.replicate n Op.squeeze), ∃ k, e.1 = .squeeze k
  | 0, _, e, he => by simp [opTrace] at he
  | n + 1, t, e, he => by
    rw [List.replicate_succ, opTrace, List.mem_cons] at he
    rcases he with rfl | he
    · exact ⟨_, rfl⟩
    · exact opTrace_rep_sq n _ e he

/-- A nonempty run's trace starts with the squeeze at the transcript's counter. -/
theorem opTrace_rep_succ (n : ℕ) (t : Tr) :
    opTrace H t (List.replicate (n + 1) Op.squeeze)
      = (.squeeze t.counter, (t.squeeze H).1) :: opTrace H (t.squeeze H).2 (List.replicate n Op.squeeze) := by
  rw [List.replicate_succ, opTrace]

/-- **The trace of whole steps parses as whole steps**, after any whole-step prefix. -/
theorem tRem_opTrace_stps : ∀ (ss : List Stp) (t : Tr) (π : List (TItem × Dig)), StpOK W t.counter ss →
    tRem W π = some 0 → tRem W (π ++ opTrace H t (stpsOps ss)) = some 0
  | [], _, π, _, h => by simpa [stpsOps, opTrace] using h
  | .ab l x :: ss, t, π, hok, h => by
    rw [stpsOps_cons, Block.opTrace_append, ← List.append_assoc]
    refine tRem_opTrace_stps ss _ _ hok ?_
    show tRem W (π ++ [(TItem.absorb l x, (t.absorb H l x).state)]) = some 0
    rw [tRem_append, h]
    rfl
  | .sq n :: ss, t, π, hok, h => by
    obtain ⟨hWc, hn, hok'⟩ := hok
    rw [stpsOps_cons, Block.opTrace_append, ← List.append_assoc]
    refine tRem_opTrace_stps ss _ _ ?_ ?_
    · rw [runOps_counter, Stp.ops, opsCtr_replicate]
      exact hok'
    · obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
      show tRem W (π ++ opTrace H t (List.replicate (m + 1) Op.squeeze)) = some 0
      rw [tRem_append, h, opTrace_rep_succ, List.foldl_cons]
      show (opTrace H (t.squeeze H).2 (List.replicate m Op.squeeze)).foldl (fun o x => tRemStep W o x.1)
        (tRemStep W (some 0) (TItem.squeeze t.counter)) = some 0
      rw [tRemStep_zero_sq, hWc, Nat.add_sub_cancel,
        foldl_tRemStep_sq W _ m (opTrace_rep_sq H m _) (by rw [Block.opTrace_length, List.length_replicate]),
        Block.opTrace_length, List.length_replicate, Nat.sub_self]

/-- The trace of whole steps from a fresh transcript parses as whole steps. -/
theorem tRem_opTrace_stps_nil (ss : List Stp) (t : Tr) (hok : StpOK W t.counter ss) :
    tRem W (opTrace H t (stpsOps ss)) = some 0 := by
  have := tRem_opTrace_stps W H ss t [] hok rfl
  rwa [List.nil_append] at this

end Parse

/-! ## The scheduled reader on a trace of steps -/

section Reader

variable (H : HIn → Dig)

/-- **The digests of a run of `n` squeezes** on the transcript `t`. -/
def sqDs (t : Tr) (n : ℕ) : List Dig := (opTrace H t (List.replicate n Op.squeeze)).map Prod.snd

theorem sqDs_length (t : Tr) (n : ℕ) : (sqDs H t n).length = n := by
  rw [sqDs, List.length_map, Block.opTrace_length, List.length_replicate]

theorem sqDs_succ (t : Tr) (n : ℕ) : sqDs H t (n + 1) = (t.squeeze H).1 :: sqDs H (t.squeeze H).2 n := by
  rw [sqDs, opTrace_rep_succ, List.map_cons]
  rfl

/-- **A round's squeezes, read**: from between rounds (or a pending message), a run of the round's width at a counter
where `W` gives that width completes the round with exactly the run's digests. -/
theorem cRd_run_sq (R : Rounds) (W : UInt64 → ℕ) (t : Tr) (n : ℕ) (ptr : List (List UInt8 × List Dig))
    (pm : Option (List UInt8)) (hlt : ptr.length < R.n) (hm : R.hasMsg ptr.length = pm.isSome)
    (hn : n = R.w ptr.length) (hn0 : 0 < n) (hWc : W t.counter = n) :
    (opTrace H t (List.replicate n Op.squeeze)).foldl (cRdStep R W) (some (ptr, pm, []))
      = some (ptr ++ [(pm.getD [], sqDs H t n)], none, []) := by
  obtain ⟨m, rfl⟩ : ∃ m, n = m + 1 := ⟨n - 1, by omega⟩
  have h := cRd_sqRun R W ptr pm hlt hm (opTrace H t (List.replicate (m + 1) Op.squeeze)) []
    (by rw [opTrace_rep_succ]; exact List.cons_ne_nil _ _) (opTrace_rep_sq H (m + 1) t)
    (by rw [List.length_nil, Nat.zero_add, Block.opTrace_length, List.length_replicate]; exact hn)
    (by
      intro _ k dg rest hes
      rw [opTrace_rep_succ, List.cons.injEq, Prod.mk.injEq, TItem.squeeze.injEq] at hes
      rw [← hes.1.1, hWc, hn])
  rw [h, List.nil_append]
  rfl

/-- **A round's message, read**: between rounds, an absorb under the round's label is its message. -/
theorem cRdStep_absorb_msg (R : Rounds) (W : UInt64 → ℕ) (ptr : List (List UInt8 × List Dig)) (l x : List UInt8)
    (d : Dig) (hlt : ptr.length < R.n) (hm : R.hasMsg ptr.length = true) (hl : l = R.lab ptr.length) :
    cRdStep R W (some (ptr, none, [])) (.absorb l x, d) = some (ptr, some x, []) := by
  simp [cRdStep, not_le.mpr hlt, hm, hl]

end Reader

/-! ## The code's challenges are functions of the trace's digests -/

section Challenges

variable (H : HIn → Dig)

/-- **`challenge_fp2_vec(n)` is `challenge_fp2` of the run's digests**, and leaves the transcript where the run does. -/
theorem challengeFp2Vec_sqDs : ∀ (n : ℕ) (t : Tr),
    t.challengeFp2Vec H n = ((sqDs H t n).map challengeFp2Of, runOps H t (List.replicate n Op.squeeze))
  | 0, _ => rfl
  | n + 1, t => by
    have ih := challengeFp2Vec_sqDs n (t.squeeze H).2
    rw [sqDs_succ, List.map_cons, List.replicate_succ, runOps]
    show (challengeFp2Of (t.squeeze H).1 :: ((t.squeeze H).2.challengeFp2Vec H n).1,
      ((t.squeeze H).2.challengeFp2Vec H n).2) = _
    rw [ih]

theorem challengeFp2_sqDs (t : Tr) :
    t.challengeFp2 H = (challengeFp2Of (t.squeeze H).1, runOps H t [Op.squeeze]) := rfl

/-- The index values of one digest (`b.chunks(8)`, each masked by `bound − 1`). -/
def idxVals (bound : ℕ) (d : Dig) : List ℕ := (chunks8 d).map (fun c => leNat c &&& (bound - 1))

theorem idxVals_length (bound : ℕ) (d : Dig) : (idxVals bound d).length = 4 := rfl

/-- The first `n` index values of the digests. -/
def idxOf (bound n : ℕ) (ds : List Dig) : List ℕ := (ds.flatMap (idxVals bound)).take n

/-- `challenge_indices`' loop on `m` squeezes (`4(m − 1) < rem ≤ 4m`). -/
theorem idxLoop_sqDs (bound : ℕ) : ∀ (m fuel : ℕ) (t : Tr) (rem : ℕ) (acc : List ℕ), 0 < rem → rem ≤ 4 * m →
    4 * m < rem + 4 → m ≤ fuel →
    idxLoop H bound fuel t rem acc = (acc ++ idxOf bound rem (sqDs H t m), runOps H t (List.replicate m Op.squeeze))
  | 0, _, _, rem, _, h0, h1, _, _ => absurd h1 (by omega)
  | m + 1, 0, _, _, _, _, _, _, hf => absurd hf (by omega)
  | m + 1, fuel + 1, t, rem, acc, h0, h1, h2, hf => by
    have hr0 : ¬ rem = 0 := by omega
    by_cases h4 : rem ≤ 4
    · have hm : m = 0 := by omega
      subst hm
      simp only [idxLoop, hr0, h4, ↓reduceIte, idxOf, sqDs, opTrace, List.replicate, runOps, List.map,
        List.flatMap_cons, List.flatMap_nil, List.append_nil, idxVals]
    · simp only [idxLoop, hr0, h4, ↓reduceIte]
      rw [idxLoop_sqDs bound m fuel (t.squeeze H).2 (rem - 4) _ (by omega) (by omega) (by omega) (by omega), sqDs_succ,
        List.replicate_succ, runOps, List.append_assoc]
      refine Prod.ext ?_ rfl
      show acc ++ (idxVals bound (t.squeeze H).1 ++ idxOf bound (rem - 4) (sqDs H (t.squeeze H).2 m))
        = acc ++ idxOf bound rem ((t.squeeze H).1 :: sqDs H (t.squeeze H).2 m)
      unfold idxOf
      rw [List.flatMap_cons, List.take_append, idxVals_length,
        List.take_of_length_le (show (idxVals bound (t.squeeze H).1).length ≤ rem by rw [idxVals_length]; omega)]

/-- **`challenge_indices(n, bound)` is the index values of the run's digests** (`⌈n/4⌉` squeezes), for a power-of-two
bound and `n ≥ 1`. -/
theorem challengeIndices_sqDs (n bound : ℕ) (t : Tr) (hb : isPow2 bound = true) (hn : 0 < n) :
    t.challengeIndices H n bound
      = some (idxOf bound n (sqDs H t ((n + 3) / 4)), runOps H t (List.replicate ((n + 3) / 4) Op.squeeze)) := by
  unfold Tr.challengeIndices
  rw [ite_eq_left hb, idxLoop_sqDs H bound ((n + 3) / 4) n t n [] hn (by omega) (by omega) (by omega), List.nil_append]

end Challenges

end ZK60.Exec.Link
