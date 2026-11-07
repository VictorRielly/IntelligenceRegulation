/-
D63 lane L27 (2026-11-07), part 3: **the Merkle extraction failure at the classify run's queries** (L16-8, deliverable 3):
L16's `extract_fail_run` at the run verifier's own Merkle work, ONE event for every commitment of the run.

L22 instantiated `extract_fail_run` at ONE block verifier (`extract_fail_block`, three roots). The run's extraction
(`classify_productionReady_joint_target`'s `Ex`, `hEx`, `hx`) needs it once for the whole run: every block's `A`, `H` and
`M` and the boundary and stage commitments, at the queries of the run's verifier. Here:

* `blocksV`, `blocksV_bounded`, `blocksV_queries`: the blocks' Merkle work in the run's order (block `k`'s L22 `blockV` on
  the columns its segment carries), at most `n·m` queries, `m = nA(dA + 2) + nH(dH + 2) + nM(dM + 2)` per block;
* `runV`, `runV_bounded`: then the boundary and stage openings' Merkle work `Vx` (any computation of at most `nx`
  queries);
* `length_runCat_le`, `runRoots`, `runRoots_length`: the run's roots, every block's three and the extra ones `rx`;
* `EvXR`, **`extract_fail_classify_run`**: the extraction failure at the run's queries (an opened column verifies
  against one of the run's roots, all its queries asked by the prover or by the run verifier's Merkle work, and it is not
  the column extracted from the prover's log cut at that root's first absorption): at most
  `collBound T + (2T² + (1 + 3n + nrx)·T)/|Dig|`, `T = q + n·m + nx`;
* **`opened_eq_extracted_run`**: outside it, every column of block `k`'s openings that block `k`'s Merkle work checks
  IS the extracted one;
* **`extract_fail_run_u126`**, `xfail_run_w16r2`, `xfail_run_r13`, **`extract_fail_run_w16r2`**,
  **`extract_fail_run_r13`**: the number, `≤ (q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102` (L24's `cx`): the 26
  blocks' work `26·13,104 = 340,704` (W16R2) or `26·12,800 = 332,800` (R13) queries, plus `nx ≤ 3,800,000` for the
  boundaries and stages, and at most `2^99` extra roots.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainSched
import ZK60Formal.ExtractInstW16

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Sound ZK60.Exec.Link

/-! ## The run verifier's Merkle work -/

section Work

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) {α : Type}

/-- **The blocks' Merkle work in the run's order**: block `0`'s L22 `blockV`, …, block `n − 1`'s, each on the opened
columns of the block's segment (`coreOf o k`: block `k`'s operations and core read off the prover's output). -/
noncomputable def blocksV (nA nH nM dA dH dM : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (o : α) :
    ℕ → OC (QB L) Dig Unit
  | 0 => .ret ()
  | n + 1 => (blocksV nA nH nM dA dH dM coreOf o n).bind (fun _ => blockV tag L h64 nA nH nM dA dH dM (coreOf o n))

theorem blocksV_bounded (nA nH nM dA dH dM : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (o : α) :
    ∀ n, (blocksV tag L h64 nA nH nM dA dH dM coreOf o n).Bounded
      (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))))
  | 0 => by
    show OC.Bounded (OC.ret ()) _
    trivial
  | n + 1 => by
    have h := OC.Bounded.bind (blocksV_bounded nA nH nM dA dH dM coreOf o n)
      (fun _ => blockV_bounded tag L h64 nA nH nM dA dH dM (coreOf o n))
    rw [show (n + 1) * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2)))
      = n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2)))
      by ring]
    exact h

/-- Block `k`'s Merkle queries are among the blocks' (`k < n`). -/
theorem blocksV_queries (nA nH nM dA dH dM : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (o : α) (G : QB L → Dig) :
    ∀ n k, k < n → ∀ v ∈ OC.queries G (blockV tag L h64 nA nH nM dA dH dM (coreOf o k)),
      v ∈ OC.queries G (blocksV tag L h64 nA nH nM dA dH dM coreOf o n)
  | 0, _, hk, _, _ => absurd hk (Nat.not_lt_zero _)
  | n + 1, k, hk, v, hv => by
    show v ∈ OC.queries G ((blocksV tag L h64 nA nH nM dA dH dM coreOf o n).bind
      (fun _ => blockV tag L h64 nA nH nM dA dH dM (coreOf o n)))
    rw [OC.queries_bind, List.mem_append]
    by_cases h : k < n
    · exact Or.inl (blocksV_queries nA nH nM dA dH dM coreOf o G n k h v hv)
    · obtain rfl : k = n := by omega
      exact Or.inr hv

/-- **The run verifier's Merkle work**: the blocks', then the boundary and stage openings' `Vx`. -/
noncomputable def runV (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (o : α) : OC (QB L) Dig Unit :=
  (blocksV tag L h64 nA nH nM dA dH dM coreOf o n).bind (fun _ => Vx o)

theorem runV_bounded (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx) (o : α) :
    (runV tag L h64 nA nH nM dA dH dM n coreOf Vx o).Bounded
      (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx) :=
  OC.Bounded.bind (blocksV_bounded tag L h64 nA nH nM dA dH dM coreOf o n) (fun _ => hVx o)

/-- Block `k`'s Merkle queries are among the run's (prover and run verifier). -/
theorem runV_queries (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (A : OC (QB L) Dig α) (G : QB L → Dig) (k : ℕ) (hk : k < n)
    (v : QB L) (hv : v ∈ OC.queries G (blockV tag L h64 nA nH nM dA dH dM (coreOf (A.run G) k))) :
    v ∈ OC.queries G (A.bind (runV tag L h64 nA nH nM dA dH dM n coreOf Vx)) := by
  rw [OC.queries_bind, List.mem_append]
  refine Or.inr ?_
  show v ∈ OC.queries G ((blocksV tag L h64 nA nH nM dA dH dM coreOf (A.run G) n).bind (fun _ => Vx (A.run G)))
  rw [OC.queries_bind, List.mem_append]
  exact Or.inl (blocksV_queries tag L h64 nA nH nM dA dH dM coreOf (A.run G) G n k hk v hv)

end Work

/-! ## The run's roots -/

section Roots

theorem length_runCat_le {β : Type _} (f : ℕ → List β) (m : ℕ) (hf : ∀ i, (f i).length ≤ m) :
    ∀ n, (runCat f n).length ≤ n * m
  | 0 => by simp [runCat]
  | n + 1 => by
    rw [runCat, List.length_append, show (n + 1) * m = n * m + m by ring]
    exact Nat.add_le_add (length_runCat_le f m hf n) (hf n)

variable {α : Type}

/-- **The run's roots**: every block's three (`A`, `H`, `M`), then the extra ones (boundaries, stages). -/
def runRoots (n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (rx : α → List Dig) (o : α) : List Dig :=
  runCat (fun k => rootsV (coreOf o k)) n ++ rx o

theorem runRoots_length (n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (rx : α → List Dig) (nrx : ℕ)
    (hrx : ∀ o, (rx o).length ≤ nrx) (o : α) : (runRoots n coreOf rx o).length ≤ 3 * n + nrx := by
  unfold runRoots
  rw [List.length_append]
  exact Nat.add_le_add ((length_runCat_le _ 3 (fun _ => le_rfl) n).trans_eq (Nat.mul_comm _ _)) (hrx o)

theorem mem_runRoots (n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core) (rx : α → List Dig) (o : α) (k : ℕ)
    (hk : k < n) (r : Dig) (hr : r ∈ rootsV (coreOf o k)) : r ∈ runRoots n coreOf rx o :=
  List.mem_append_left _ ((mem_runCat _ r n).mpr ⟨k, hk, hr⟩)

end Roots

/-! ## The extraction failure at the run's queries -/

section Fail

variable (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) {α : Type}

/-- **The extraction failure at the run's queries** (L16-8 at the run): an opened column verifies against one of the
run's roots, all its queries were asked by the prover or by the run verifier's Merkle work, and it is not the column
extracted from the prover's log cut at that root's first absorption on the run's chain `C`. -/
def EvXR (C : ChainEnc (ItB L) (QB L) Dig) (nA nH nM dA dH dM n : ℕ) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig) (A : OC (QB L) Dig α) (G : QB L → Dig) : Prop :=
  ∃ r ∈ runRoots n coreOf rx (A.run G), ∃ (h j : ℕ) (o : MerkleOpening Dig Dig (ColV L)),
    (merkleEncV tag L h64).Opens G h r j o
    ∧ (∀ v ∈ (merkleEncV tag L h64).openQs G j o,
        v ∈ OC.queries G (A.bind (runV tag L h64 nA nH nM dA dH dM n coreOf Vx)))
    ∧ (merkleEncV tag L h64).extractCol (cutAt (absD C) r (A.runLog G).2) h j r ≠ some o.col

/-- **The extraction failure at the run's queries is rare** (`extract_fail_run` at the run verifier's Merkle work, ONE
event for every root of the run): at most `collBound T + (2T² + (1 + 3n + nrx)·T)/|Dig|`, `T = q + n·m + nx`. -/
theorem extract_fail_classify_run (C : ChainEnc (ItB L) (QB L) Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Exec.Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx) (q : ℕ) (A : OC (QB L) Dig α)
    (hA : A.Bounded q) :
    prH (EvXR tag L h64 C nA nH nM dA dH dM n coreOf Vx rx A)
      ≤ collBound (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) Dig
        + ((2 * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
            * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx))
          + (1 + (3 * n + nrx)) * (q + (n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx)) : ℕ) : ℝ≥0∞)
          / Fintype.card Dig := by
  classical
  exact extract_fail_run (merkleEncV tag L h64) (absD C) A (runRoots n coreOf rx) (3 * n + nrx)
    (runRoots_length n coreOf rx nrx hrx) (runV tag L h64 nA nH nM dA dH dM n coreOf Vx) _
    (OC.Bounded.bind hA (runV_bounded tag L h64 nA nH nM dA dH dM n coreOf Vx nx hVx))

/-- **Outside the run's extraction failure, every column block `k`'s Merkle work checks IS the extracted one** (for
each of block `k`'s roots, `k < n`). -/
theorem opened_eq_extracted_run (C : ChainEnc (ItB L) (QB L) Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Exec.Block.Core) (Vx : α → OC (QB L) Dig Unit) (rx : α → List Dig)
    (A : OC (QB L) Dig α) (G : QB L → Dig) (hX : ¬ EvXR tag L h64 C nA nH nM dA dH dM n coreOf Vx rx A G)
    (k : ℕ) (hk : k < n) (r : Dig) (hr : r ∈ rootsV (coreOf (A.run G) k)) (d j : ℕ)
    (o : MerkleOpening Dig Dig (ColV L)) (hop : (merkleEncV tag L h64).Opens G d r j o)
    (hq : ∀ v ∈ (merkleEncV tag L h64).openQs G j o,
      v ∈ OC.queries G (blockV tag L h64 nA nH nM dA dH dM (coreOf (A.run G) k))) :
    (merkleEncV tag L h64).extractCol (cutAt (absD C) r (A.runLog G).2) d j r = some o.col := by
  by_contra hne
  exact hX ⟨r, mem_runRoots n coreOf rx (A.run G) k hk r hr, d, j, o, hop,
    fun v hv => runV_queries tag L h64 nA nH nM dA dH dM n coreOf Vx A G k hk v (hq v hv), hne⟩

/-- **The run's extraction failure in the target's units** (L24's `xfail_le_u126_102`): for `q + 1 ≤ 2^102`, the run
verifier's Merkle work within `2^22` queries and at most `2^100` roots, at most `(q + 1)·(2^16 + 2^18)/2^126`. -/
theorem extract_fail_run_u126 (C : ChainEnc (ItB L) (QB L) Dig) (nA nH nM dA dH dM n : ℕ)
    (coreOf : α → ℕ → List Op × Exec.Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hT : n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx ≤ 2 ^ 22) (hnr : 3 * n + nrx ≤ 2 ^ 100)
    (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXR tag L h64 C nA nH nM dA dH dM n coreOf Vx rx A) ≤ u126 q (2 ^ 16 + 2 ^ 18) :=
  (extract_fail_classify_run tag L h64 C nA nH nM dA dH dM n coreOf Vx nx hVx rx nrx hrx q A hA).trans
    (xfail_le_u126_102 q _ _ hq (by
      have h := hT
      generalize n * (nA * (dA + 2) + (nH * (dH + 2) + nM * (dM + 2))) + nx = X at h ⊢
      omega) hnr)

/-- The 26 blocks' Merkle work at W16R2 (`A`, `H`: 280 columns of depth 15; `M`: 256 of depth 12): `340,704` queries;
with the boundaries' and stages' `nx ≤ 3,800,000`, within `2^22`. -/
theorem xfail_run_w16r2 (nx : ℕ) (hnx : nx ≤ 3800000) :
    26 * (280 * (15 + 2) + (280 * (15 + 2) + 256 * (12 + 2))) + nx ≤ 2 ^ 22 := by
  omega

/-- The 26 blocks' Merkle work at R13 (`A`, `H`: 256 columns of depth 16; `M` as at W16R2): `332,800` queries. -/
theorem xfail_run_r13 (nx : ℕ) (hnx : nx ≤ 3800000) :
    26 * (256 * (16 + 2) + (256 * (16 + 2) + 256 * (12 + 2))) + nx ≤ 2 ^ 22 := by
  omega

/-- **The run's extraction failure at W16R2, 26 blocks**: at most `(q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102`,
with the boundaries' and stages' Merkle work within `3,800,000` queries and at most `2^99` extra roots. -/
theorem extract_fail_run_w16r2 (C : ChainEnc (ItB L) (QB L) Dig) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx) (hnx : nx ≤ 3800000)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx) (hnrx : nrx ≤ 2 ^ 99)
    (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXR tag L h64 C 280 280 256 15 15 12 26 coreOf Vx rx A) ≤ u126 q (2 ^ 16 + 2 ^ 18) :=
  extract_fail_run_u126 tag L h64 C 280 280 256 15 15 12 26 coreOf Vx nx hVx rx nrx hrx (xfail_run_w16r2 nx hnx)
    (by have : (2 : ℕ) ^ 99 + 78 ≤ 2 ^ 100 := by norm_num
        omega) q hq A hA

/-- **The run's extraction failure at R13 (the app), 26 blocks**: the same bound at R13's opening geometry. -/
theorem extract_fail_run_r13 (C : ChainEnc (ItB L) (QB L) Dig) (coreOf : α → ℕ → List Op × Exec.Block.Core)
    (Vx : α → OC (QB L) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx) (hnx : nx ≤ 3800000)
    (rx : α → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx) (hnrx : nrx ≤ 2 ^ 99)
    (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXR tag L h64 C 256 256 256 16 16 12 26 coreOf Vx rx A) ≤ u126 q (2 ^ 16 + 2 ^ 18) :=
  extract_fail_run_u126 tag L h64 C 256 256 256 16 16 12 26 coreOf Vx nx hVx rx nrx hrx (xfail_run_r13 nx hnx)
    (by have : (2 : ℕ) ^ 99 + 78 ≤ 2 ^ 100 := by norm_num
        omega) q hq A hA

end Fail

end ZK60.ProtocolClassify
