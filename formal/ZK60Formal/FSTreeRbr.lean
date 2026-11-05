/-
D63, step L3 (soundness): round-by-round protocols laid out on a TREE of chains, the D55 shape (finding F26).

`FSTree.lean` proves the hash-chain argument for any family of chains. This file lays protocols on the D55 tree:
* the **trunk**: the run statement `x`, one item (`PItem.stmt (inl x)`). In the code it is the fork run's header and
  every boundary root, absorbed before `pb-fork-s0`; its end is `S0` (`run_fork.rs`, `s0`, `absorb_commit`);
* **`nf` forks**: fork `k`'s chain is the trunk, then its head `fkHead k` (`PItem.stmt (inr j)`; the code absorbs
  `pb-run-fork k` and `pb-run-fork-block`, `absorb_fork_start`), then the rounds of fork `k`'s schedule;
* **the join**: the trunk, then a head computed from the FORKS' CHAINS (`joinOf`: in D55 each fork's index, end
  state, squeeze counter and IO claims, then `pb-fork-s1`, `absorb_join` and `close_join`), then the join's rounds (the
  boundary and endpoint openings).
Each branch is a round-by-round protocol (`RbrWide`) with its own rounds, widths and messages, on the statement
`(x, head)`. The verifier hashes every fork chain from the start query, computes the join's head from them, and hashes
the join chain (`Tree.verOC`); it accepts when every fork and the join accept (`Tree.Accepts`).

**What is proved.**
* `liftT`, `liftT_round`: the branches' states on chains (a chain is in the state of the branch its head names, read
  with that branch's schedule); from a doomed path, a step of the path's branch escapes with that branch's round error.
  The proof is `FSWideRbr.lean`'s `liftStW_round` for the branch, after the trunk item.
* `fs_tree_sound`: **the tree on the chain.** Let every branch be `RbrWide` with error `ε`. Suppose a false statement
  dooms some fork at its start (`hstart`); a fork that ends doomed and is accepted dooms the join at its start
  (`hhand`: its claims, absorbed in the join's head, are false); the join's verifier rejects when it ends doomed
  (`hfinal`). Then a prover making at most `q` hash queries gets a false statement accepted with probability at most
  `(q + ℓT)·ε + collBound (q + ℓT) D + collBound (q + ℓT + 1) D`, `ℓT` the verifier's query budget
  (`Σ_k (ℓW_k + 2) + ℓW_join + 2`). The rate is `ε`, the maximum over all rounds of all branches; it does not grow
  with the number of forks.
* `Tree.ofSched`, `fs_tree_sound_sched`: each branch a schedule of sub-protocols (`FSCompose.lean`'s `SubProt`), its
  state "every sub-protocol alive", with `ε` above every sub-protocol's error of every branch.

**What it assumes.** The premises `hstart`, `hhand`, `hfinal` (and, for schedules, each branch's `hframe`): how the
claims of the branches fit together. The trunk and each head are ONE item here; the code absorbs them as several
labelled absorbs (only `ℓT` changes, as for the header in `FSChainRbr.lean`). The branch head must be the second item
of every branch chain and must name its branch (`br_fk`, `br_jn`). The D55 instance is `FSTreeD55.lean`.
-/
import ZK60Formal.FSTree

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## Two sums over a range -/

/-- A pointwise bound sums over a range. -/
theorem sum_map_range_le (f g : ℕ → ℕ) (h : ∀ k, f k ≤ g k) :
    ∀ m, ((List.range m).map f).sum ≤ ((List.range m).map g).sum
  | 0 => le_rfl
  | m + 1 => by
    rw [List.range_succ, List.map_append, List.map_append, List.sum_append, List.sum_append]
    have h1 := sum_map_range_le f g h m
    have h2 := h m
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
    omega

/-- One term of a sum over a range is at most the sum. -/
theorem le_sum_map_range (g : ℕ → ℕ) : ∀ m k, k < m → g k ≤ ((List.range m).map g).sum
  | 0, _, h => absurd h (Nat.not_lt_zero _)
  | m + 1, k, h => by
    rw [List.range_succ, List.map_append, List.sum_append]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
    rcases Nat.lt_succ_iff_lt_or_eq.mp h with h | rfl
    · have := le_sum_map_range g m k h
      omega
    · omega

/-! ## Items, heads and branches -/

section Items

variable {X J M : Type}

/-- **The items of a tree's chains**: the trunk (`PItem.stmt (inl x)`), a branch head (`PItem.stmt (inr j)`), the
branch's messages and squeezes. -/
abbrev TItem (X J M : Type) : Type := PItem (X ⊕ J) M

/-- **A branch's heads**: the trunk, then `FSWideRbr.lean`'s heads with the branch head as the statement. -/
def tHeads (n : ℕ) (w : ℕ → ℕ) (hasMsg : ℕ → Bool) (x : X) (j : J) (ms : List M) : List (TItem X J M) :=
  PItem.stmt (Sum.inl x) :: pHeadsW n w hasMsg (Sum.inr j) ms

/-- **The branch of an item list**, read off its second item, the branch head. -/
def brT {B : Type} (brOf : J → B) (b₀ : B) : List (TItem X J M) → B
  | _ :: PItem.stmt (Sum.inr j) :: _ => brOf j
  | _ => b₀

theorem brT_heads {B : Type} (brOf : J → B) (b₀ : B) (x : X) (j : J) (its : List (TItem X J M)) :
    brT brOf b₀ (PItem.stmt (Sum.inl x) :: PItem.stmt (Sum.inr j) :: its) = brOf j := rfl

/-- A branch's items: the trunk, the head, the rounds. -/
theorem tHeads_items (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (hasMsg : ℕ → Bool) (x : X) (j : J) (ms : List M) :
    (tHeads n w hasMsg x j ms).flatMap (pSteps n w hw).items
      = PItem.stmt (Sum.inl x) :: PItem.stmt (Sum.inr j)
        :: (roundHeads w hasMsg 0 (ms.take n)).flatMap (pSteps n w hw).items := by
  simp [tHeads, pHeadsW, pSteps_items_stmt]

/-- The first two heads of a branch are the trunk and the head, one item each. -/
theorem tHeads_take_two (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (hasMsg : ℕ → Bool) (x : X) (j : J) (ms : List M) :
    ((tHeads n w hasMsg x j ms).take 2).flatMap (pSteps n w hw).items
      = [PItem.stmt (Sum.inl x), PItem.stmt (Sum.inr j)] := by
  simp [tHeads, pHeadsW, pSteps_items_stmt]

/-- A branch's items number at most its schedule's `ℓW` and the trunk. -/
theorem tHeads_length_le (n : ℕ) (w : ℕ → ℕ) (hw : ∀ i, 0 < w i) (hasMsg : ℕ → Bool) (x : X) (j : J)
    (ms : List M) : ((tHeads n w hasMsg x j ms).flatMap (pSteps n w hw).items).length ≤ ℓW n w + 1 := by
  rw [tHeads, List.flatMap_cons, List.length_append, pSteps_items_stmt, List.length_singleton]
  have := pHeadsW_length_le (X := X ⊕ J) (M := M) (n := n) (w := w) (hasMsg := hasMsg) hw (Sum.inr j) ms
  omega

end Items

/-! ## The branches' states on chains -/

section Lift

variable {X J M D B : Type}

/-- **The tree's state on chains**: a chain that starts with the trunk `x` and a branch head `j` is in the state of
`j`'s branch, `St (brOf j) (x, j)`, of the transcript read off the rest with that branch's schedule; any other chain is
doomed. -/
def liftT (brOf : J → B) (n : B → ℕ) (w : B → ℕ → ℕ) (hasMsg : B → ℕ → Bool) (m₀ : M)
    (St : B → X × J → List (M × List D) → Prop) : List (TItem X J M × D) → Prop
  | (PItem.stmt (Sum.inl x), _) :: (PItem.stmt (Sum.inr j), _) :: rest =>
      liftOfW (St (brOf j)) (x, j) (rDecodeW (n (brOf j)) (w (brOf j)) (hasMsg (brOf j)) m₀ rest)
  | _ => False

/-- The state of a chain with at least two items: it must start with a trunk and a head. -/
theorem liftT_cons_cons (brOf : J → B) (n : B → ℕ) (w : B → ℕ → ℕ) (hasMsg : B → ℕ → Bool) (m₀ : M)
    (St : B → X × J → List (M × List D) → Prop) (e0 e1 : TItem X J M × D) (rest : List (TItem X J M × D)) :
    liftT brOf n w hasMsg m₀ St (e0 :: e1 :: rest) ↔ ∃ x j, e0.1 = PItem.stmt (Sum.inl x)
      ∧ e1.1 = PItem.stmt (Sum.inr j)
      ∧ liftOfW (St (brOf j)) (x, j) (rDecodeW (n (brOf j)) (w (brOf j)) (hasMsg (brOf j)) m₀ rest) := by
  obtain ⟨i0, d0⟩ := e0
  obtain ⟨i1, d1⟩ := e1
  cases i0 with
  | stmt xj0 =>
    cases xj0 with
    | inl x =>
      cases i1 with
      | stmt xj1 =>
        cases xj1 with
        | inl x' => simp [liftT]
        | inr j => simp [liftT]
      | msg m => simp [liftT]
      | sq c => simp [liftT]
    | inr j0 => simp [liftT]
  | msg m => simp [liftT]
  | sq c => simp [liftT]

variable [Fintype D] [Nonempty D]

/-- **The tree's state is round by round, branch by branch.** From a doomed path of at least two items, whole steps of
its own branch's schedule, the next step escapes with probability at most the branch's round error: after the trunk
item, this is `liftStW_round` for the branch. -/
theorem liftT_round (brOf : J → B) (b₀ : B) (n : B → ℕ) (w : B → ℕ → ℕ) (hw : ∀ b i, 0 < w b i)
    (hasMsg : B → ℕ → Bool) (m₀ : M) (St : B → X × J → List (M × List D) → Prop) (ε : ℝ≥0∞)
    (hR : ∀ b, RbrWide (n b) (w b) (St b) ε) {Q : Type} (P : List (Q × D)) (τ : List (TItem X J M × D))
    (it : TItem X J M) (hlen : 2 ≤ τ.length)
    (hbd : ∃ hs : List (TItem X J M), τ.map Prod.fst
      = hs.flatMap (pSteps (n (brT brOf b₀ (τ.map Prod.fst))) (w (brT brOf b₀ (τ.map Prod.fst))) (hw _)).items)
    (hns : ¬ liftT brOf n w hasMsg m₀ St τ) :
    (PMF.uniformOfFintype (Fin ((pSteps (n (brT brOf b₀ (τ.map Prod.fst))) (w (brT brOf b₀ (τ.map Prod.fst)))
        (hw _)).wd it) → D)).toOuterMeasure
      {b | liftT brOf n w hasMsg m₀ St (τ ++ (pSteps (n (brT brOf b₀ (τ.map Prod.fst)))
        (w (brT brOf b₀ (τ.map Prod.fst))) (hw _)).ents it (List.ofFn b))} ≤ ε := by
  obtain ⟨e0, e1, rest, rfl⟩ : ∃ e0 e1 rest, τ = e0 :: e1 :: rest := by
    match τ, hlen with
    | e0 :: e1 :: rest, _ => exact ⟨e0, e1, rest, rfl⟩
  generalize hb : brT brOf b₀ ((e0 :: e1 :: rest).map Prod.fst) = b at hbd ⊢
  by_cases hm : ∃ x j, e0.1 = PItem.stmt (Sum.inl x) ∧ e1.1 = PItem.stmt (Sum.inr j)
  · obtain ⟨x, j, h0, h1⟩ := hm
    obtain ⟨i0, d0⟩ := e0
    obtain ⟨i1, d1⟩ := e1
    simp only at h0 h1
    subst h0 h1
    have hbj : brOf j = b := hb
    subst hbj
    -- the branch's state after the trunk item, as `liftStW` reads it
    let St' : List (Q × D) → (X ⊕ J) → List (M × List D) → Prop :=
      fun _ xj τ' => Sum.elim (fun _ => False) (fun j' => St (brOf j) (x, j') τ') xj
    have hR' : ∀ P', RbrWide (n (brOf j)) (w (brOf j)) (St' P') ε := fun P' => ⟨fun xj τ' m h1 h2 => by
      cases xj with
      | inl x' =>
        have hE : {b' : Fin (w (brOf j) τ'.length) → D | St' P' (Sum.inl x') (τ' ++ [(m, List.ofFn b')])} = ∅ :=
          Set.eq_empty_iff_forall_notMem.mpr (fun _ hb' => hb')
        rw [hE, MeasureTheory.measure_empty]
        exact zero_le
      | inr j' => exact (hR (brOf j)).round (x, j') τ' m h1 h2⟩
    have hbd' : ∃ hs : List (TItem X J M), ((PItem.stmt (Sum.inr j), d1) :: rest).map Prod.fst
        = hs.flatMap (pSteps (n (brOf j)) (w (brOf j)) (hw (brOf j))).items := by
      obtain ⟨hs, hhs⟩ := hbd
      obtain ⟨h0, hs', rfl⟩ : ∃ h0 hs', hs = h0 :: hs' := by
        cases hs with
        | nil => simp at hhs
        | cons h0 hs' => exact ⟨h0, hs', rfl⟩
      obtain ⟨r0, hr0⟩ := (pSteps (X := X ⊕ J) (M := M) (n (brOf j)) (w (brOf j)) (hw (brOf j))).items_cons h0
      rw [List.map_cons, List.flatMap_cons, hr0, List.cons_append, List.cons.injEq] at hhs
      obtain ⟨rfl, hhs⟩ := hhs
      rw [pSteps_items_stmt, List.cons.injEq] at hr0
      rw [← hr0.2, List.nil_append] at hhs
      exact ⟨hs', hhs⟩
    have key := liftStW_round (n := n (brOf j)) (w := w (brOf j)) (hasMsg := hasMsg (brOf j)) (m₀ := m₀)
      (hw (brOf j)) St' ε hR' P ((PItem.stmt (Sum.inr j), d1) :: rest) it (by simp) hbd' (fun h => hns h)
    refine le_of_eq_of_le ?_ key
    congr 1
  · have hE : {b' : Fin ((pSteps (n b) (w b) (hw b)).wd it) → D | liftT brOf n w hasMsg m₀ St
        ((e0 :: e1 :: rest) ++ (pSteps (n b) (w b) (hw b)).ents it (List.ofFn b'))} = ∅ := by
      refine Set.eq_empty_iff_forall_notMem.mpr (fun b' hb' => hm ?_)
      rw [Set.mem_ofPred_eq, List.cons_append, List.cons_append, liftT_cons_cons] at hb'
      obtain ⟨x, j, h0, h1, -⟩ := hb'
      exact ⟨x, j, h0, h1⟩
    rw [hE, MeasureTheory.measure_empty]
    exact zero_le

end Lift

/-! ## The tree and its verifier -/

/-- **A tree of transcripts** (the D55 shape): `nf` forks and a join, each a branch with its own schedule (`n`, `w`,
`hasMsg`). Fork `k` is branch `fk k` with head `fkHead k`; the join is branch `jn`, its head computed from the forks'
chains by `joinOf`. Each head names its branch (`brOf`). -/
structure Tree (X J M D B : Type) where
  nf : ℕ
  fk : ℕ → B
  jn : B
  fkHead : ℕ → J
  joinOf : X → List (List (TItem X J M × D)) → J
  brOf : J → B
  br_fk : ∀ k, brOf (fkHead k) = fk k
  br_jn : ∀ x τs, brOf (joinOf x τs) = jn
  n : B → ℕ
  w : B → ℕ → ℕ
  w_pos : ∀ b i, 0 < w b i
  hasMsg : B → ℕ → Bool
  m₀ : M

namespace Tree

variable {X J M D B : Type} (T : Tree X J M D B)

/-- A branch's steps. -/
noncomputable def steps (b : B) : Steps (TItem X J M) := pSteps (T.n b) (T.w b) (T.w_pos b)

/-- A branch chain's heads. -/
def heads (b : B) (x : X) (j : J) (ms : List M) : List (TItem X J M) := tHeads (T.n b) (T.w b) (T.hasMsg b) x j ms

/-- A branch chain's items. -/
noncomputable def items (b : B) (x : X) (j : J) (ms : List M) : List (TItem X J M) :=
  (T.heads b x j ms).flatMap (T.steps b).items

/-- Reading a branch chain back as the branch's transcript (after the trunk and the head). -/
def decode (b : B) (τ : List (TItem X J M × D)) : RState M D := rDecodeW (T.n b) (T.w b) (T.hasMsg b) T.m₀ (τ.drop 2)

/-- **The verifier's query budget**: per branch, its items, the trunk and the start query. -/
def ℓT : ℕ :=
  ((List.range T.nf).map (fun k => ℓW (T.n (T.fk k)) (T.w (T.fk k)) + 2)).sum + (ℓW (T.n T.jn) (T.w T.jn) + 2)

variable {Q : Type} (C : ChainEnc (TItem X J M) Q D)

/-- The forks' item lists. -/
noncomputable def forkItems (x : X) (msF : ℕ → List M) : List (List (TItem X J M)) :=
  (List.range T.nf).map (fun k => T.items (T.fk k) x (T.fkHead k) (msF k))

/-- Fork `k`'s chain. -/
noncomputable def forkChain (H : Q → D) (x : X) (k : ℕ) (ms : List M) : List (TItem X J M × D) :=
  C.chainFrom H [] (T.items (T.fk k) x (T.fkHead k) ms)

/-- The forks' chains. -/
noncomputable def forkChains (H : Q → D) (x : X) (msF : ℕ → List M) : List (List (TItem X J M × D)) :=
  (T.forkItems x msF).map (C.chainFrom H [])

/-- **The join's head**: computed by the verifier from the forks' chains. -/
noncomputable def joinHead (H : Q → D) (x : X) (msF : ℕ → List M) : J := T.joinOf x (T.forkChains C H x msF)

/-- The join's head names the join. -/
theorem br_joinHead (H : Q → D) (x : X) (msF : ℕ → List M) : T.brOf (T.joinHead C H x msF) = T.jn :=
  T.br_jn _ _

/-- The join's chain. -/
noncomputable def joinChain (H : Q → D) (x : X) (msF : ℕ → List M) (msJ : List M) : List (TItem X J M × D) :=
  C.chainFrom H [] (T.items T.jn x (T.joinHead C H x msF) msJ)

/-- **The verifier's hashing**: every fork chain from the start query, then the join chain, whose head it computes
from the forks' chains. -/
noncomputable def verOC {Mf : Type} (o : X × (ℕ → List M) × List M × Mf) : OC Q D (List (TItem X J M × D)) :=
  (C.chainsOC (T.forkItems o.1 o.2.1)).bind (fun τs => C.chainOC (T.items T.jn o.1 (T.joinOf o.1 τs) o.2.2.1))

/-- **The tree verifier accepts**: every fork `k < nf` reads as a whole transcript of its branch that its verifier
accepts, and so does the join, with the head computed from the forks. -/
def Accepts {Mf : Type} (accF : ℕ → X × J → List (M × List D) → Mf → Prop)
    (accJ : X × J → List (M × List D) → Mf → Prop) (H : Q → D) (x : X) (msF : ℕ → List M) (msJ : List M)
    (mf : Mf) : Prop :=
  (∀ k < T.nf, (msF k).length = T.n (T.fk k)
      ∧ ∃ ptr, T.decode (T.fk k) (T.forkChain C H x k (msF k)) = some (ptr, none, []) ∧ accF k (x, T.fkHead k) ptr mf)
    ∧ msJ.length = T.n T.jn
    ∧ ∃ ptr, T.decode T.jn (T.joinChain C H x msF msJ) = some (ptr, none, []) ∧ accJ (x, T.joinHead C H x msF) ptr mf

/-- A branch chain's items number at most its `ℓW` and the trunk. -/
theorem items_length_le (b : B) (x : X) (j : J) (ms : List M) : (T.items b x j ms).length ≤ ℓW (T.n b) (T.w b) + 1 :=
  tHeads_length_le _ _ (T.w_pos b) _ _ _ _

/-- A fork's budget is part of the verifier's. -/
theorem fork_le_ℓT {k : ℕ} (hk : k < T.nf) : ℓW (T.n (T.fk k)) (T.w (T.fk k)) + 2 ≤ T.ℓT := by
  have := le_sum_map_range (fun k => ℓW (T.n (T.fk k)) (T.w (T.fk k)) + 2) T.nf k hk
  unfold ℓT
  omega

/-- The join's budget is part of the verifier's. -/
theorem join_le_ℓT : ℓW (T.n T.jn) (T.w T.jn) + 2 ≤ T.ℓT := by
  unfold ℓT
  omega

/-- The verifier makes at most `ℓT` queries. -/
theorem verOC_bounded {Mf : Type} (o : X × (ℕ → List M) × List M × Mf) : (T.verOC C o).Bounded T.ℓT := by
  have h1 : ((T.forkItems o.1 o.2.1).map (fun its => its.length + 1)).sum
      ≤ ((List.range T.nf).map (fun k => ℓW (T.n (T.fk k)) (T.w (T.fk k)) + 2)).sum := by
    rw [forkItems, List.map_map]
    refine sum_map_range_le _ _ (fun k => ?_) T.nf
    have := T.items_length_le (T.fk k) o.1 (T.fkHead k) (o.2.1 k)
    simp only [Function.comp]
    omega
  have hJ : ∀ τs, (C.chainOC (T.items T.jn o.1 (T.joinOf o.1 τs) o.2.2.1)).Bounded
      (ℓW (T.n T.jn) (T.w T.jn) + 2) := fun τs =>
    (C.chainOC_bounded _).mono (by have := T.items_length_le T.jn o.1 (T.joinOf o.1 τs) o.2.2.1; omega)
  exact ((C.chainsOC_bounded _).bind hJ).mono (by unfold ℓT; omega)

/-- **A branch chain**: the trunk, the head, then entries for exactly the rounds' items. -/
theorem chain_shape (H : Q → D) (b : B) (x : X) (j : J) (ms : List M) :
    ∃ d0 d1 ext, C.chainFrom H [] (T.items b x j ms)
        = (PItem.stmt (Sum.inl x), d0) :: (PItem.stmt (Sum.inr j), d1) :: ext
      ∧ ext.map Prod.fst = (roundHeads (T.w b) (T.hasMsg b) 0 (ms.take (T.n b))).flatMap (T.steps b).items := by
  obtain ⟨ext', h1, h2⟩ := C.chainFrom_eq_append H (T.items b x j ms) []
  rw [List.nil_append] at h1
  have hit : T.items b x j ms = PItem.stmt (Sum.inl x) :: PItem.stmt (Sum.inr j)
      :: (roundHeads (T.w b) (T.hasMsg b) 0 (ms.take (T.n b))).flatMap (T.steps b).items :=
    tHeads_items (T.n b) (T.w b) (T.w_pos b) (T.hasMsg b) x j ms
  rw [hit] at h2
  rcases ext' with _ | ⟨⟨i0, d0⟩, _ | ⟨⟨i1, d1⟩, ext⟩⟩
  · simp at h2
  · simp at h2
  · simp only [List.map_cons, List.cons.injEq] at h2
    obtain ⟨rfl, rfl, h3⟩ := h2
    exact ⟨d0, d1, ext, h1, h3⟩

/-- **An accepted branch chain reads as a whole transcript**: `n` rounds. -/
theorem decode_length (H : Q → D) (b : B) (x : X) (j : J) (ms : List M) (ptr : List (M × List D))
    (hlen : ms.length = T.n b) (hdec : T.decode b (C.chainFrom H [] (T.items b x j ms)) = some (ptr, none, [])) :
    ptr.length = T.n b := by
  obtain ⟨d0, d1, ext, h1, h2⟩ := T.chain_shape C H b x j ms
  rw [h1] at hdec
  obtain ⟨ptr', h3, h4⟩ := foldl_roundHeads (n := T.n b) (w := T.w b) (hasMsg := T.hasMsg b) (m₀ := T.m₀)
    (T.w_pos b) (ms.take (T.n b)) 0 [] ext rfl (by simp) h2
  have h5 : T.decode b ((PItem.stmt (Sum.inl x), d0) :: (PItem.stmt (Sum.inr j), d1) :: ext)
      = some (ptr', none, []) := h3
  rw [h5, Option.some.injEq, Prod.mk.injEq] at hdec
  rw [← hdec.1, h4, zero_add, List.length_take, hlen, min_self]

/-- The state of a branch chain's first two items (the trunk and the head) is the branch's start state. -/
theorem liftT_two (St : B → X × J → List (M × List D) → Prop) (H : Q → D) (b : B) (x : X) (j : J) (ms : List M) :
    liftT T.brOf T.n T.w T.hasMsg T.m₀ St (C.chainFrom H [] (((T.heads b x j ms).take 2).flatMap (T.steps b).items))
      ↔ St (T.brOf j) (x, j) [] := by
  rw [show ((T.heads b x j ms).take 2).flatMap (T.steps b).items = [PItem.stmt (Sum.inl x), PItem.stmt (Sum.inr j)]
    from tHeads_take_two (T.n b) (T.w b) (T.w_pos b) (T.hasMsg b) x j ms]
  rfl

/-- The state of a whole branch chain is the branch's state of the transcript read off it. -/
theorem liftT_chain (St : B → X × J → List (M × List D) → Prop) (H : Q → D) (b : B) (x : X) (j : J)
    (ms : List M) :
    liftT T.brOf T.n T.w T.hasMsg T.m₀ St (C.chainFrom H [] (T.items b x j ms))
      ↔ liftOfW (St (T.brOf j)) (x, j) (rDecodeW (T.n (T.brOf j)) (T.w (T.brOf j)) (T.hasMsg (T.brOf j)) T.m₀
        ((C.chainFrom H [] (T.items b x j ms)).drop 2)) := by
  obtain ⟨d0, d1, ext, h1, -⟩ := T.chain_shape C H b x j ms
  rw [h1]
  rfl

/-- **Fiat–Shamir soundness of a tree of protocols on the code's chains.** Every branch is round-by-round sound with
vector challenges (`RbrWide`) with error `ε`. A false statement dooms some fork at its start (`hstart`); a fork that
ends doomed and is accepted dooms the join at its start, whose head the verifier computed from the forks' chains
(`hhand`); the join's verifier rejects when the join ends doomed (`hfinal`). A prover making at most `q` hash queries
gets a false statement accepted by the tree verifier with probability at most
`(q + ℓT)·ε + collBound (q + ℓT) D + collBound (q + ℓT + 1) D`: per hash query `ε`, the largest round error over all
branches, not their sum over the forks. -/
theorem fs_tree_sound [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] {Mf : Type}
    {Lg : X → Prop} (accF : ℕ → X × J → List (M × List D) → Mf → Prop)
    (accJ : X × J → List (M × List D) → Mf → Prop) (St : B → X × J → List (M × List D) → Prop) (ε : ℝ≥0∞)
    (hR : ∀ b, RbrWide (T.n b) (T.w b) (St b) ε)
    (hstart : ∀ x, ¬ Lg x → ∃ k < T.nf, ¬ St (T.fk k) (x, T.fkHead k) [])
    (hhand : ∀ x (τs : List (List (TItem X J M × D))) k τ ptr mf, k < T.nf → τs[k]? = some τ →
      T.decode (T.fk k) τ = some (ptr, none, []) → ptr.length = T.n (T.fk k) →
      ¬ St (T.fk k) (x, T.fkHead k) ptr → accF k (x, T.fkHead k) ptr mf → ¬ St T.jn (x, T.joinOf x τs) [])
    (hfinal : ∀ x j ptr mf, ptr.length = T.n T.jn → ¬ St T.jn (x, j) ptr → ¬ accJ (x, j) ptr mf)
    (q : ℕ) (A : OC Q D (X × (ℕ → List M) × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ Lg (A.run H).1
        ∧ T.Accepts C accF accJ H (A.run H).1 (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2)
      ≤ ((q + T.ℓT : ℕ) : ℝ≥0∞) * ε + collBound (q + T.ℓT) D + collBound (q + T.ℓT + 1) D := by
  classical
  -- the chains the verifier hashes: every fork, then the join with the head computed from the forks
  let chains : (Q → D) → (X × (ℕ → List M) × List M × Mf) → List (B × List (TItem X J M)) := fun H o =>
    (List.range T.nf).map (fun k => (T.fk k, T.heads (T.fk k) o.1 (T.fkHead k) (o.2.1 k)))
      ++ [(T.jn, T.heads T.jn o.1 (T.joinHead C H o.1 o.2.1) o.2.2.1)]
  have hmem : ∀ H o c, c ∈ chains H o → (∃ k < T.nf, c = (T.fk k, T.heads (T.fk k) o.1 (T.fkHead k) (o.2.1 k)))
      ∨ c = (T.jn, T.heads T.jn o.1 (T.joinHead C H o.1 o.2.1) o.2.2.1) := by
    intro H o c hc
    rcases List.mem_append.mp hc with hc | hc
    · obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hc
      exact Or.inl ⟨k, List.mem_range.mp hk, rfl⟩
    · exact Or.inr (List.mem_singleton.mp hc)
  have hℓ : ∀ H o, ∀ c ∈ chains H o, (c.2.flatMap (T.steps c.1).items).length ≤ T.ℓT := by
    intro H o c hc
    rcases hmem H o c hc with ⟨k, hk, rfl⟩ | rfl
    · exact le_trans (T.items_length_le (T.fk k) o.1 (T.fkHead k) (o.2.1 k))
        (by have := T.fork_le_ℓT hk; omega)
    · exact le_trans (T.items_length_le T.jn o.1 (T.joinHead C H o.1 o.2.1) o.2.2.1)
        (by have := T.join_le_ℓT; omega)
  have hbr : ∀ H o, ∀ c ∈ chains H o, ∀ its : List (TItem X J M),
      brT T.brOf T.jn ((c.2.take 2).flatMap (T.steps c.1).items ++ its) = c.1 := by
    intro H o c hc its
    rcases hmem H o c hc with ⟨k, hk, rfl⟩ | rfl
    · rw [show ((T.heads (T.fk k) o.1 (T.fkHead k) (o.2.1 k)).take 2).flatMap (T.steps (T.fk k)).items
          = [PItem.stmt (Sum.inl o.1), PItem.stmt (Sum.inr (T.fkHead k))]
        from tHeads_take_two _ _ (T.w_pos _) _ _ _ _]
      exact T.br_fk k
    · rw [show ((T.heads T.jn o.1 (T.joinHead C H o.1 o.2.1) o.2.2.1).take 2).flatMap (T.steps T.jn).items
          = [PItem.stmt (Sum.inl o.1), PItem.stmt (Sum.inr (T.joinHead C H o.1 o.2.1))]
        from tHeads_take_two _ _ (T.w_pos _) _ _ _ _]
      exact T.br_jn _ _
  have hqV : ∀ H o, ∀ c ∈ chains H o, ∀ y ∈ OC.queries H (C.chainOC (c.2.flatMap (T.steps c.1).items)),
      y ∈ OC.queries H (T.verOC C o) := by
    intro H o c hc y hy
    unfold Tree.verOC
    rw [OC.queries_bind]
    rcases hmem H o c hc with ⟨k, hk, rfl⟩ | rfl
    · refine List.mem_append_left _ (C.chainsOC_queries H _ (T.items (T.fk k) o.1 (T.fkHead k) (o.2.1 k)) ?_ y hy)
      exact List.mem_map.mpr ⟨k, List.mem_range.mpr hk, rfl⟩
    · refine List.mem_append_right _ ?_
      rw [C.chainsOC_run]
      exact hy
  have hround : ∀ (P : List (Q × D)) (τ : List (TItem X J M × D)) (it : TItem X J M), 2 ≤ τ.length →
      (∃ hs : List (TItem X J M), τ.map Prod.fst = hs.flatMap (T.steps (brT T.brOf T.jn (τ.map Prod.fst))).items) →
      ¬ liftT T.brOf T.n T.w T.hasMsg T.m₀ St τ →
      (PMF.uniformOfFintype (Fin ((T.steps (brT T.brOf T.jn (τ.map Prod.fst))).wd it) → D)).toOuterMeasure
        {b | liftT T.brOf T.n T.w T.hasMsg T.m₀ St
          (τ ++ (T.steps (brT T.brOf T.jn (τ.map Prod.fst))).ents it (List.ofFn b))} ≤ ε :=
    fun P τ it h1 h2 h3 => liftT_round T.brOf T.jn T.n T.w T.w_pos T.hasMsg T.m₀ St ε hR P τ it h1 h2 h3
  have key := tree_sound_wide C T.steps (brT T.brOf T.jn) T.jn (fun _ => liftT T.brOf T.n T.w T.hasMsg T.m₀ St) 2 ε
    hround (fun _ _ _ _ _ _ _ _ _ _ _ => Iff.rfl) (T.verOC C) T.ℓT (T.verOC_bounded C) chains T.ℓT hℓ hbr hqV q A hA
  refine le_trans (MeasureTheory.measure_mono ?_) key
  rintro H ⟨hL, hF, hlenJ, ptrJ, hdecJ, haccJ⟩
  obtain ⟨k, hk, hk0⟩ := hstart _ hL
  obtain ⟨hlen_k, ptr_k, hdec_k, hacc_k⟩ := hF k hk
  by_cases halive : St (T.fk k) ((A.run H).1, T.fkHead k) ptr_k
  · -- fork `k` was doomed at its start and is not at its end
    refine ⟨(T.fk k, T.heads (T.fk k) (A.run H).1 (T.fkHead k) ((A.run H).2.1 k)),
      List.mem_append_left _ (List.mem_map.mpr ⟨k, List.mem_range.mpr hk, rfl⟩), ?_, ?_⟩
    · exact (T.liftT_two C St H (T.fk k) (A.run H).1 (T.fkHead k) ((A.run H).2.1 k)).not.mpr
        (by rw [T.br_fk k]; exact hk0)
    · have hd : rDecodeW (T.n (T.fk k)) (T.w (T.fk k)) (T.hasMsg (T.fk k)) T.m₀
          ((C.chainFrom H [] (T.items (T.fk k) (A.run H).1 (T.fkHead k) ((A.run H).2.1 k))).drop 2)
          = some (ptr_k, none, []) := hdec_k
      exact (T.liftT_chain C St H (T.fk k) (A.run H).1 (T.fkHead k) ((A.run H).2.1 k)).mpr
        (by rw [T.br_fk k, hd]; exact halive)
  · -- fork `k` ends doomed and is accepted: the join starts doomed, and ends accepted
    have hlp := T.decode_length C H (T.fk k) _ (T.fkHead k) _ ptr_k hlen_k hdec_k
    have hτk : (T.forkChains C H (A.run H).1 (A.run H).2.1)[k]?
        = some (T.forkChain C H (A.run H).1 k ((A.run H).2.1 k)) := by
      simp [Tree.forkChains, Tree.forkItems, Tree.forkChain, hk]
    have hJ0 := hhand _ (T.forkChains C H (A.run H).1 (A.run H).2.1) k _ ptr_k _ hk hτk hdec_k hlp halive hacc_k
    have hlJ := T.decode_length C H T.jn _ _ _ ptrJ hlenJ hdecJ
    have hJalive : St T.jn ((A.run H).1, T.joinHead C H (A.run H).1 (A.run H).2.1) ptrJ := by
      by_contra h
      exact hfinal _ _ _ _ hlJ h haccJ
    refine ⟨(T.jn, T.heads T.jn (A.run H).1 (T.joinHead C H (A.run H).1 (A.run H).2.1) (A.run H).2.2.1),
      List.mem_append_right _ (List.mem_singleton_self _), ?_, ?_⟩
    · exact (T.liftT_two C St H T.jn (A.run H).1 (T.joinHead C H (A.run H).1 (A.run H).2.1)
        (A.run H).2.2.1).not.mpr (by rw [T.br_joinHead C]; exact hJ0)
    · have hd : rDecodeW (T.n T.jn) (T.w T.jn) (T.hasMsg T.jn) T.m₀
          ((C.chainFrom H [] (T.items T.jn (A.run H).1 (T.joinHead C H (A.run H).1 (A.run H).2.1)
            (A.run H).2.2.1)).drop 2) = some (ptrJ, none, []) := hdecJ
      exact (T.liftT_chain C St H T.jn (A.run H).1 (T.joinHead C H (A.run H).1 (A.run H).2.1)
        (A.run H).2.2.1).mpr (by rw [T.br_joinHead C, hd]; exact hJalive)

/-- **A tree of schedules on the code's chains.** Each branch `b` is a schedule `cs b` of sub-protocols
(`FSCompose.lean`), its state "every sub-protocol alive", its `frame` condition a premise. With `ε` above every
sub-protocol's error in every branch, the tree's bound is `fs_tree_sound`'s: per hash query, the largest error. -/
theorem fs_tree_sound_sched [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] [DecidableEq D] {Mf : Type}
    {Lg : X → Prop} (cs : B → List (SubProt (X × J) M D)) (hn : ∀ b, T.n b = nOf (cs b))
    (hw : ∀ b, T.w b = wOf (cs b)) (accF : ℕ → X × J → List (M × List D) → Mf → Prop)
    (accJ : X × J → List (M × List D) → Mf → Prop) (ε : ℝ≥0∞) (hε : ∀ b, ∀ c ∈ cs b, c.ε ≤ ε)
    (hframe : ∀ b, ∀ k xj τ m (bb : Fin (wOf (cs b) τ.length) → D), τ.length < nOf (cs b) →
      ownOf (cs b) τ.length ≠ k → ¬ SOf (cs b) k xj τ → SOf (cs b) k xj (τ ++ [(m, List.ofFn bb)]) →
        ∃ k', k < k' ∧ ¬ SOf (cs b) k' xj τ)
    (hstart : ∀ x, ¬ Lg x → ∃ k < T.nf, ∃ i, ¬ SOf (cs (T.fk k)) i (x, T.fkHead k) [])
    (hhand : ∀ x (τs : List (List (TItem X J M × D))) k τ ptr mf, k < T.nf → τs[k]? = some τ →
      T.decode (T.fk k) τ = some (ptr, none, []) → ptr.length = T.n (T.fk k) →
      (∃ i, ¬ SOf (cs (T.fk k)) i (x, T.fkHead k) ptr) → accF k (x, T.fkHead k) ptr mf →
        ∃ i, ¬ SOf (cs T.jn) i (x, T.joinOf x τs) [])
    (hfinal : ∀ x j ptr mf, ptr.length = T.n T.jn → (∃ i, ¬ SOf (cs T.jn) i (x, j) ptr) → ¬ accJ (x, j) ptr mf)
    (q : ℕ) (A : OC Q D (X × (ℕ → List M) × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ Lg (A.run H).1
        ∧ T.Accepts C accF accJ H (A.run H).1 (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2)
      ≤ ((q + T.ℓT : ℕ) : ℝ≥0∞) * ε + collBound (q + T.ℓT) D + collBound (q + T.ℓT + 1) D := by
  refine T.fs_tree_sound C accF accJ (fun b => AllAlive (SOf (cs b))) ε (fun b => ?_) (fun x hx => ?_)
    (fun x τs k τ ptr mf h1 h2 h3 h4 h5 h6 => ?_) (fun x j ptr mf h1 h2 => hfinal x j ptr mf h1 (not_forall.mp h2))
    q A hA
  · rw [hn b, hw b]
    exact (sched_composed (cs b) ε (hε b) (hframe b)).rbrWide (range (cs b).length) (SOf_doomed_mem (cs b)) ε
      (fun _ _ => le_rfl)
  · obtain ⟨k, hk, i, hi⟩ := hstart x hx
    exact ⟨k, hk, fun h => hi (h i)⟩
  · obtain ⟨i, hi⟩ := hhand x τs k τ ptr mf h1 h2 h3 h4 (not_forall.mp h5) h6
    exact fun h => hi (h i)

end Tree

end ZK60.Sound
