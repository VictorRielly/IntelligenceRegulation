/-
D63 lane L34 (2026-11-09), part 1: **the step parse of ANY list of verifier steps** (the generic half of the run's
transcript).

L22 and L28 write a block verifier's operations as steps (`Stp`: one absorb, or a run of `n` squeezes) and build the
step parse `W` by hand for one block (`OProf.W`: `wRuns` from `M`'s window, seven runs). The classify run has `L + 2`
parts, each with its own `M` and three openings, so the parse is built here for any step list:

* `rtSqs`: the widths of a step list's squeeze runs, in order (`rtSqs_append`, `rtSqs_opsStps`: single operations give
  runs of width `1`; `rtSqs_mStps`, `rtSqs_pcsStps`: `M`'s `[1, 2S + 2, 64]`, an opening's `[w0, m]`; `rtSqs_sum`);
* `rtW ws`: the parse whose runs have the widths `ws`, back to back from counter `0` (L22's `wRuns`); `rtW_pos`,
  `rtW_le`;
* **`rt_stpOK`**: a step list whose runs have the widths `ws` (all positive, fewer than `2^64` squeezes in all) parses
  under `rtW ws` (`StpOK`). So the run's parse depends only on the squeeze counts of its parts (finding L27-2);
* `rt_stpOK_left`, `rt_stpOK_right`: a parse of `a ++ b` parses `a`, and `b` from the counter after `a`;
* **`rt_trace_take`**, `rt_trace_drop`, **`rt_tRem_take`**: the trace of `a ++ b`, cut after `a`'s operations, is the
  trace of `a`, a sequence of whole steps; what follows is the trace of `b` on the transcript after `a`;
* `rt_stepsOne_cont`: single steps meet L27's `StepCont`;
* `rt_sum_take_le`, `rt_sum_take_succ`: sums of a list's prefixes (the parts' offsets).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainUGate
import ZK60Formal.LinkW16GlueW16

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

/-! ## The squeeze runs' widths of a list of steps -/

/-- **The widths of a step list's squeeze runs**, in order (an absorb has none). -/
def rtSqs : List Stp → List ℕ
  | [] => []
  | .ab _ _ :: ss => rtSqs ss
  | .sq n :: ss => n :: rtSqs ss

theorem rtSqs_append : ∀ (a b : List Stp), rtSqs (a ++ b) = rtSqs a ++ rtSqs b
  | [], _ => rfl
  | .ab _ _ :: a, b => rtSqs_append a b
  | .sq n :: a, b => congrArg (List.cons n) (rtSqs_append a b)

/-- Single operations: every squeeze a run of width `1`. -/
theorem rtSqs_opsStps : ∀ ops : List Op, rtSqs (opsStps ops) = List.replicate (sqN ops) 1
  | [] => rfl
  | .absorb _ _ :: ops => rtSqs_opsStps ops
  | .squeeze :: ops => by
    show 1 :: rtSqs (opsStps ops) = List.replicate (sqN ops + 1) 1
    rw [rtSqs_opsStps ops, List.replicate_succ]

/-- The widths sum to the squeeze count. -/
theorem rtSqs_sum : ∀ ss : List Stp, (rtSqs ss).sum = stpsSq ss
  | [] => rfl
  | .ab l x :: ss => by
    rw [stpsSq_cons]
    show (rtSqs ss).sum = 0 + stpsSq ss
    rw [rtSqs_sum ss, Nat.zero_add]
  | .sq n :: ss => by
    rw [stpsSq_cons]
    show (n :: rtSqs ss).sum = n + stpsSq ss
    rw [List.sum_cons, rtSqs_sum ss]

theorem rtSqs_vecStps : ∀ vs : List (List Fp2), rtSqs (vecStps vs) = []
  | [] => rfl
  | _ :: vs => rtSqs_vecStps vs

/-- `M`'s runs: `θ`, the `2S + 2` row coefficients, the `64` index squeezes. -/
theorem rtSqs_mStps (S : ℕ) (mo : Block.MaskOpening) : rtSqs (mStps S mo) = [1, 2 * S + 2, 64] := rfl

/-- An opening's runs: the `w0` batching and proximity squeezes, the `m` index squeezes. -/
theorem rtSqs_pcsStps (w0 m : ℕ) (o : Block.OpeningZk) : rtSqs (pcsStps w0 m o) = [w0, m] := by
  have h : pcsStps w0 m o = [Stp.sq w0] ++ (vecStps o.groupVecs
      ++ ([Stp.ab Block.labPcsProx (o.proxVec.flatMap Fp2.toBytes)] ++ [Stp.sq m])) := by
    simp [pcsStps, pcsPre]
  rw [h, rtSqs_append, rtSqs_append, rtSqs_vecStps]
  rfl

/-! ## The parse of a list of steps -/

/-- **The step parse whose squeeze runs have the widths `ws`**, back to back from counter `0` (L22's `wRuns`). -/
def rtW (ws : List ℕ) : UInt64 → ℕ := fun k => wRuns 0 ws k.toNat

theorem rtW_pos (ws : List ℕ) (h : ∀ n ∈ ws, 0 < n) : ∀ k, 0 < rtW ws k := fun _ => wRuns_pos _ _ h _

theorem rtW_le (ws : List ℕ) (h : ∀ n ∈ ws, n ≤ 2 ^ 64) : ∀ k, rtW ws k ≤ 2 ^ 64 :=
  fun _ => wRuns_le _ _ _ (by norm_num) h _

/-- A step list parses from counter `c` under any widths that are `wRuns` of its runs from `c` on. -/
theorem rt_stpOK_gen (W : UInt64 → ℕ) : ∀ (ss : List Stp) (c : ℕ), (∀ n ∈ rtSqs ss, 0 < n) →
    c + (rtSqs ss).sum < 2 ^ 64 → (∀ k, c ≤ k → k < 2 ^ 64 → W (UInt64.ofNat k) = wRuns c (rtSqs ss) k) →
    StpOK W (UInt64.ofNat c) ss
  | [], _, _, _, _ => trivial
  | .ab _ _ :: ss, c, hp, hs, hW => rt_stpOK_gen W ss c hp hs hW
  | .sq n :: ss, c, hp, hs, hW => by
    have hn : 0 < n := hp n List.mem_cons_self
    have hs' : c + (n + (rtSqs ss).sum) < 2 ^ 64 := by
      have e : (rtSqs (Stp.sq n :: ss)).sum = n + (rtSqs ss).sum := List.sum_cons
      rw [e] at hs
      exact hs
    refine ⟨?_, hn, ?_⟩
    · rw [hW c le_rfl (by omega)]
      show wRuns c (n :: rtSqs ss) c = n
      rw [wRuns]
      exact ite_eq_left rfl
    · rw [u64_ofNat_add]
      refine rt_stpOK_gen W ss (c + n) (fun m hm => hp m (List.mem_cons_of_mem _ hm)) (by omega) (fun k hk hk64 => ?_)
      rw [hW k (by omega) hk64]
      show wRuns c (n :: rtSqs ss) k = wRuns (c + n) (rtSqs ss) k
      rw [wRuns]
      exact ite_eq_right (by omega)

/-- **A step list whose squeeze runs have the widths `ws` parses under `rtW ws`** (every width positive, fewer than
`2^64` squeezes in all): the parse depends only on the runs' widths. -/
theorem rt_stpOK (ws : List ℕ) (ss : List Stp) (hss : rtSqs ss = ws) (hp : ∀ n ∈ ws, 0 < n) (hs : ws.sum < 2 ^ 64) :
    StpOK (rtW ws) 0 ss := by
  subst hss
  refine rt_stpOK_gen (rtW (rtSqs ss)) ss 0 hp (by omega) (fun k _ hk => ?_)
  show wRuns 0 (rtSqs ss) (UInt64.ofNat k).toNat = wRuns 0 (rtSqs ss) k
  rw [u64_ofNat_toNat hk]

/-- A parse of `a ++ b` parses `a`. -/
theorem rt_stpOK_left (W : UInt64 → ℕ) : ∀ (c : UInt64) (a b : List Stp), StpOK W c (a ++ b) → StpOK W c a
  | _, [], _, _ => trivial
  | c, .ab _ _ :: a, b, h => rt_stpOK_left W c a b h
  | _, .sq _ :: a, b, h => ⟨h.1, h.2.1, rt_stpOK_left W _ a b h.2.2⟩

/-- A parse of `a ++ b` parses `b` from the counter after `a`. -/
theorem rt_stpOK_right (W : UInt64 → ℕ) : ∀ (c : UInt64) (a b : List Stp), StpOK W c (a ++ b) →
    StpOK W (c + UInt64.ofNat (stpsSq a)) b
  | c, [], b, h => by
    rw [show stpsSq [] = 0 from rfl, u64_add_ofNat_zero]
    exact h
  | c, .ab l x :: a, b, h => by
    have ih := rt_stpOK_right W c a b h
    rw [stpsSq_cons]
    show StpOK W (c + UInt64.ofNat (0 + stpsSq a)) b
    rw [Nat.zero_add]
    exact ih
  | c, .sq n :: a, b, h => by
    have ih := rt_stpOK_right W (c + UInt64.ofNat n) a b h.2.2
    rw [u64_add_add] at ih
    rw [stpsSq_cons]
    exact ih

/-! ## The trace of a list of steps, cut after a prefix -/

/-- **The trace of `a ++ b`, cut after `a`'s operations, is the trace of `a`.** -/
theorem rt_trace_take (H : HIn → Dig) (t : Tr) (a b : List Stp) :
    (opTrace H t (stpsOps (a ++ b))).take (stpsOps a).length = opTrace H t (stpsOps a) := by
  rw [stpsOps_append, Block.opTrace_append, List.take_left' (Block.opTrace_length H t _)]

/-- What follows is the trace of `b` on the transcript after `a`. -/
theorem rt_trace_drop (H : HIn → Dig) (t : Tr) (a b : List Stp) :
    (opTrace H t (stpsOps (a ++ b))).drop (stpsOps a).length = opTrace H (runOps H t (stpsOps a)) (stpsOps b) := by
  rw [stpsOps_append, Block.opTrace_append, List.drop_left' (Block.opTrace_length H t _)]

/-- **The cut is at a step's end**: the trace of `a ++ b` up to `a`'s end parses as whole steps. -/
theorem rt_tRem_take (W : UInt64 → ℕ) (H : HIn → Dig) (t : Tr) (a b : List Stp) (hok : StpOK W t.counter (a ++ b)) :
    tRem W ((opTrace H t (stpsOps (a ++ b))).take (stpsOps a).length) = some 0 := by
  rw [rt_trace_take]
  exact tRem_opTrace_stps_nil W H a t (rt_stpOK_left W _ a b hok)

/-- Single steps meet L27's `StepCont` (a step is its head alone). -/
theorem rt_stepsOne_cont (L : ℕ) : StepCont (stepsOne (ItB L)) := fun _ _ => Or.inl rfl

/-! ## Sums of prefixes (the parts' offsets) -/

theorem rt_sum_take_le : ∀ (l : List ℕ) (i : ℕ), (l.take i).sum ≤ (l.take (i + 1)).sum
  | [], _ => by simp
  | _ :: _, 0 => by simp
  | a :: l, i + 1 => by
    simp only [List.take_succ_cons, List.sum_cons]
    exact Nat.add_le_add_left (rt_sum_take_le l i) a

theorem rt_sum_take_succ : ∀ (l : List ℕ) (i : ℕ), (l.take (i + 1)).sum = (l.take i).sum + l.getD i 0
  | [], _ => by simp
  | _ :: _, 0 => by simp
  | a :: l, i + 1 => by
    simp only [List.take_succ_cons, List.sum_cons, List.getD_cons_succ]
    rw [rt_sum_take_succ l i]
    omega

end ZK60.ProtocolClassify
