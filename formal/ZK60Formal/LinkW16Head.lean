/-
D63 lane L28 (2026-11-07), part 2: **the header readers the openings' sub-protocols need** (L22-7, the part that
reads absorbed vectors) and the facts that tie a step parse's heads to the chain.

`opB`'s state reads the group vectors off its header (`vOf`), and its message is the proximity vector (`decB`). Here:

* `decFp2s`, **`decFp2s_toBytes`**: `n` code pairs decoded from bytes (`Fp2::from_bytes`, 16 each); on a canonical
  vector of `n` entries it is the vector;
* `absBytes`, `absAt_append_right`, `absAt_vecStps`: the bytes a trace absorbs at a position;
* **`vRd`**, **`vRd_trace`**: the group-vector reader (the absorb at `pos + g`, decoded, read in `K`); on the verifier's
  own trace it is group `g`'s clear vector;
* **`proxDec`**, `proxDec_enc`: the proximity vector's decoder;
* `groupsAccept_congr_v`: `GroupsAccept` reads the group vectors only at the claims' groups;
* `opsStps_append`, **`heads_single`**: the first `s` heads of a parse whose first `s` steps are single items expand
  to `s` items (`hhd` of L20's chain theorems).

The readers of the slots' accumulator (`acc.fs ++ acc.hostFs`, `acc.claims.a`, `acc.claims.h`) are the remaining part of
L22-7: they enter the assembled theorems as one named premise (`accRd` and its agreement on the verifier's trace).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Pcs

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## Decoding absorbed vectors -/

/-- **`n` code pairs from bytes** (`Fp2::from_bytes` of each 16-byte piece). -/
def decFp2s : ℕ → List UInt8 → List Fp2
  | 0, _ => []
  | n + 1, b => Fp2.fromBytes (b.take 16) :: decFp2s n (b.drop 16)

theorem decFp2s_toBytes : ∀ (v : List Fp2), (∀ x ∈ v, x.Canon) → decFp2s v.length (v.flatMap Fp2.toBytes) = v
  | [], _ => rfl
  | a :: v, h => by
    rw [List.flatMap_cons, List.length_cons, decFp2s, List.take_left' (Block.fp2_toBytes_length a),
      List.drop_left' (Block.fp2_toBytes_length a), Fp2.fromBytes_toBytes a (h a List.mem_cons_self),
      decFp2s_toBytes v (fun x hx => h x (List.mem_cons_of_mem _ hx))]

/-- The bytes a trace absorbs at position `i` (`[]` when it is not an absorb). -/
def absBytes (hdr : List (TItem × Dig)) (i : ℕ) : List UInt8 := (Block.absAt hdr i).getD []

theorem absAt_append_right (l l' : List (TItem × Dig)) (i : ℕ) :
    Block.absAt (l ++ l') (l.length + i) = Block.absAt l' i := by
  unfold Block.absAt
  rw [List.getElem?_append_right (by omega), Nat.add_sub_cancel_left]

theorem absAt_append_right' (l l' : List (TItem × Dig)) (a i : ℕ) (h : l.length = a) :
    Block.absAt (l ++ l') (a + i) = Block.absAt l' i := by
  subst h
  exact absAt_append_right l l' i

theorem absAt_append_left (l l' : List (TItem × Dig)) (i : ℕ) (hi : i < l.length) :
    Block.absAt (l ++ l') i = Block.absAt l i := by
  unfold Block.absAt
  rw [List.getElem?_append_left hi]

theorem absAt_take (l : List (TItem × Dig)) (n i : ℕ) (hi : i < n) : Block.absAt (l.take n) i = Block.absAt l i := by
  unfold Block.absAt
  rw [List.getElem?_take_of_lt hi]

theorem absAt_vecStps (H : HIn → Dig) : ∀ (vs : List (List Fp2)) (t : Tr) (g : ℕ), g < vs.length →
    Block.absAt (opTrace H t (stpsOps (vecStps vs))) g = some ((vs.getD g []).flatMap Fp2.toBytes)
  | [], _, _, hg => absurd hg (by simp)
  | v :: vs, t, g, hg => by
    rw [vecStps, List.map_cons, stpsOps_cons, ← vecStps]
    show Block.absAt ((TItem.absorb Block.labPcsVec (v.flatMap Fp2.toBytes),
      (t.absorb H Block.labPcsVec (v.flatMap Fp2.toBytes)).state)
        :: opTrace H (t.absorb H Block.labPcsVec (v.flatMap Fp2.toBytes)) (stpsOps (vecStps vs))) g = _
    rcases g with _ | g
    · rfl
    · have := absAt_vecStps H vs (t.absorb H Block.labPcsVec (v.flatMap Fp2.toBytes)) g (by simpa using hg)
      simpa [Block.absAt] using this

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The group-vector reader**: group `g`'s clear vector, decoded from the absorb at position `pos + g`, in `K`. -/
noncomputable def vRd (m pos : ℕ) (hdr : List (TItem × Dig)) (g : ℕ) : Fin m → K :=
  vecK U m (decFp2s m (absBytes hdr (pos + g)))

/-- **The proximity vector's decoder** (`opB`'s message). -/
noncomputable def proxDec (m : ℕ) (b : List UInt8) : Option (Fin m → K) := some (vecK U m (decFp2s m b))

theorem proxDec_enc (v : List Fp2) (hv : ∀ x ∈ v, x.Canon) (m : ℕ) (hl : v.length = m) :
    proxDec U m (v.flatMap Fp2.toBytes) = some (vecK U m v) := by
  unfold proxDec
  rw [← hl, decFp2s_toBytes v hv]

/-- **The group-vector reader on the verifier's own trace**: on `pre`, the batching run, the group vectors' absorbs
(and anything after), the reader at `pos = |pre| + w0` returns group `g`'s clear vector. -/
theorem vRd_trace (H : HIn → Dig) (pre rest : List (TItem × Dig)) (tA : Tr) (w0 : ℕ) (vs : List (List Fp2))
    (g : ℕ) (hg : g < vs.length) (hc : ∀ x ∈ vs.getD g [], x.Canon) (m : ℕ) (hl : (vs.getD g []).length = m) :
    vRd U m (pre.length + w0) (pre ++ opTrace H tA (List.replicate w0 Op.squeeze ++ stpsOps (vecStps vs)) ++ rest) g
      = vecK U m (vs.getD g []) := by
  unfold vRd absBytes
  have e1 : pre ++ opTrace H tA (List.replicate w0 Op.squeeze ++ stpsOps (vecStps vs)) ++ rest
      = pre ++ (opTrace H tA (List.replicate w0 Op.squeeze)
        ++ (opTrace H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps vs)) ++ rest)) := by
    rw [Block.opTrace_append]
    simp only [List.append_assoc]
  have hlen : (opTrace H tA (List.replicate w0 Op.squeeze)).length = w0 := by
    rw [Block.opTrace_length, List.length_replicate]
  have hlt : g < (opTrace H (runOps H tA (List.replicate w0 Op.squeeze)) (stpsOps (vecStps vs))).length := by
    rw [Block.opTrace_length, stpsOps_vecStps_length]
    exact hg
  rw [e1, Nat.add_assoc, absAt_append_right, absAt_append_right' _ _ _ _ hlen, absAt_append_left _ _ _ hlt,
    absAt_vecStps H vs _ g hg, Option.getD_some, ← hl, decFp2s_toBytes _ hc]

omit [Algebra GF K] in
/-- `GroupsAccept` reads the group vectors only at the claims' groups. -/
theorem groupsAccept_congr_v {ι κ μ G Cl : Type} [Fintype κ] [Fintype μ] [Fintype Cl] [DecidableEq G]
    (enc : (μ → K) →ₗ[K] (ι → K)) (Ux : κ → ι → K) (rw : Cl → κ → K) (cw : G → μ → K) (grp : Cl → G)
    (val : Cl → K) (v v' : G → (Cl → K) → (κ → K) → μ → K) (w : (Cl → K) → (κ → K) → μ → K) {Q : ℕ}
    (lam : Cl → K) (ρ : κ → K) (J : Fin Q → ι) (hv : ∀ g ∈ Set.range grp, v g = v' g)
    (h : GroupsAccept enc Ux rw cw grp val v w lam ρ J) : GroupsAccept enc Ux rw cw grp val v' w lam ρ J := by
  obtain ⟨h1, h2, h3⟩ := h
  refine ⟨fun g hg => ?_, fun g hg => ?_, h3⟩
  · rw [← hv g hg]
    exact h1 g hg
  · rw [← hv g hg]
    exact h2 g hg

/-! ## The first heads of a parse -/

theorem opsStps_append (a b : List Op) : opsStps (a ++ b) = opsStps a ++ opsStps b := by
  simp [opsStps]

/-- **The first `s` heads of a parse whose first steps are single items expand to `s` items** (`hhd` of L20's chain
theorems, for a parse `opsStps X ++ Y`, `s ≤ |X|`): an absorb's head is its own step, a single squeeze's head a step of
width `W c = 1`. -/
theorem heads_single (L : ℕ) (W : UInt64 → ℕ) (hW : ∀ k, 0 < W k) (hW64 : ∀ k, W k ≤ 2 ^ 64) :
    ∀ (X : List Op) (Y : List Stp) (c : UInt64) (s : ℕ), s ≤ X.length → StpOK W c (opsStps X ++ Y) →
      (∀ it ∈ stpHeads c (opsStps X ++ Y), it.Ok ∧ it.len ≤ L) →
      (((liftItems L (stpHeads c (opsStps X ++ Y))).take s).flatMap (stepsB L W hW hW64).items).length = s
  | _, _, _, 0, _, _, _ => by simp
  | [], _, _, s + 1, hs, _, _ => absurd hs (by simp)
  | .absorb l x :: X, Y, c, s + 1, hs, hok, hfit => by
    have e : stpHeads c (opsStps (.absorb l x :: X) ++ Y) = .absorb l x :: stpHeads c (opsStps X ++ Y) := rfl
    have h0 : (TItem.absorb l x).Ok ∧ (TItem.absorb l x).len ≤ L := hfit _ (by rw [e]; exact List.mem_cons_self)
    rw [e, liftItems_cons_fit L _ _ h0, List.take_succ_cons, List.flatMap_cons, List.length_append,
      stepsB_items_ab L W hW hW64 l x h0, heads_single L W hW hW64 X Y c s (by simpa using hs) hok
        (fun it hit => hfit it (by rw [e]; exact List.mem_cons_of_mem _ hit)), List.length_singleton]
    omega
  | .squeeze :: X, Y, c, s + 1, hs, hok, hfit => by
    have e : stpHeads c (opsStps (.squeeze :: X) ++ Y)
        = .squeeze c :: stpHeads (c + UInt64.ofNat 1) (opsStps X ++ Y) := rfl
    have h0 : (TItem.squeeze c).Ok ∧ (TItem.squeeze c).len ≤ L := hfit _ (by rw [e]; exact List.mem_cons_self)
    obtain ⟨hW1, -, hok'⟩ := hok
    have hl : ((stepsB L W hW hW64).items ⟨.squeeze c, h0⟩).length = 1 := by
      have hl' := congrArg List.length (stepsB_items_sq L W hW hW64 c h0)
      rw [List.length_map, opItems_length, List.length_replicate, hW1] at hl'
      exact hl'
    rw [e, liftItems_cons_fit L _ _ h0, List.take_succ_cons, List.flatMap_cons, List.length_append, hl,
      heads_single L W hW hW64 X Y _ s (by simpa using hs) hok'
        (fun it hit => hfit it (by rw [e]; exact List.mem_cons_of_mem _ hit))]
    omega

end ZK60.Exec.Link
