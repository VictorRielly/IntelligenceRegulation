/-
D63, step L3 (soundness): the D55 fork-join run at the 8B T128 W16R2 parameters, per hash query (finding F26).

`FSTreeRbr.lean` puts a tree of protocols on the code's chains. This file is the D55 instance, as
`private_block/run_fork.rs` builds it (read for this file; no Rust changed):
* **the trunk** (`ForkRun::s0`): the fork run's header (`transcript`: its own constructor, `run-shape`, `expected-IO`,
  `public-statement`, `parameters`, `calibration`, `schedule`), every boundary root in boundary order
  (`absorb_commit`: `pb-fork-commit-root k` and `B`, `rows`, `log-cols`), then `pb-fork-s0 L`. No squeeze: `S0`'s
  counter is `0`. Here: the statement `x`, which carries the roots.
* **fork `k`** (`ForkRun::fork`, `absorb_fork_start`): `S0` rebuilt from the same header and roots, then
  `pb-run-fork k` and `pb-run-fork-block` (block `k`'s public digest), then `verify_core` on fork `k`'s frame alone.
  Here: the head `D55Head.fork k`, then block `k`'s schedule `cs (some k)`.
* **the join** (`verify_run_with_forks`, phase 3): from `S0` on the run transcript, for each fork in block order
  `pb-join-fork k`, `pb-join-state` (the fork's end state and squeeze counter), `pb-join-in-claims`,
  `pb-join-out-claims` (the claims the fork's verifier computed, `absorb_join`), then `pb-fork-s1 L` (`close_join`),
  then the boundary openings and the endpoint openings. Here: the head `D55Head.join es L` computed from the forks'
  chains by the verifier (`d55JoinOf`: each fork's index, last digest, number of squeezes and claims), then the
  join's schedule `cs none`.

**What is proved.**
* `d55Tree`: the D55 tree (forks `some k`, the join `none`).
* `fs_d55_sound_8B`: with every sub-protocol of every branch one of `FSComposeBlock.lean`'s `Kind8B` (the proved
  rounds, and `M`'s opening ASSUMED at error `≤ 2^-106`), a prover making at most `q` hash queries gets a false run
  statement accepted by the D55 verifier with probability at most
  `(q + ℓT)·135/2^110 + collBound (q + ℓT) + collBound (q + ℓT + 1)`, `ℓT` the verifier's query budget (every fork
  chain, the join chain). **Per hash query `135/2^110 ≈ 2^-102.92`, as for the D12a run, whatever the number of
  forks**; the union over `L = 32` forks was `2^-97.93`.
* `fs_d55_sound_8B_target`: in the approved target's form, `εsTarget (max q ℓT)` for `q, ℓT ≤ 2^76`.

**The hand-off through the join** is two premises, about the claims the join absorbs:
* `hclaims`: a fork that ends doomed and is accepted has false claims (`ClaimsTrue` is false of them): its sumcheck
  terminals handed their claims to the boundary data;
* `hjoin`: a join head that carries a false claim dooms the join's openings at their start.
The rest are premises as for the D12a run (`hframe` per branch, `hstart`: a false run statement dooms some block's
fork, the arithmetization; `hfinal`: the join's verifier rejects when it ends doomed). `M`'s error is assumed. The
trunk and the heads are one item each (the code's several absorbs change only `ℓT`).
-/
import ZK60Formal.FSTreeRbr
import ZK60Formal.FSComposeBlock

set_option autoImplicit false

namespace ZK60.Sound

open scoped ENNReal
open Finset

/-! ## The D55 tree -/

/-- **A D55 branch head.** -/
inductive D55Head (D Cl : Type) where
  /-- fork `k`: `pb-run-fork k`, then `pb-run-fork-block` (block `k`'s public digest) -/
  | fork : ℕ → D55Head D Cl
  /-- the join: for each fork in block order, its index, end state, squeeze counter and IO claims (`pb-join-fork`,
  `pb-join-state`, `pb-join-in-claims`, `pb-join-out-claims`); then `pb-fork-s1 L` -/
  | join : List (ℕ × D × ℕ × Cl) → ℕ → D55Head D Cl

/-- The branch a D55 head names: fork `k` is `some k`, the join is `none`. -/
def D55Head.br {D Cl : Type} : D55Head D Cl → Option ℕ
  | .fork k => some k
  | .join _ _ => none

/-- A chain's end state: its last digest (`d₀` for the empty chain). -/
def endD {It D : Type} (d₀ : D) (τ : List (It × D)) : D := (τ.getLast?.map Prod.snd).getD d₀

/-- Whether an item is a squeeze. -/
def isSq {X M : Type} : PItem X M → Bool
  | .sq _ => true
  | _ => false

/-- A chain's squeeze counter: its number of squeezes (the trunk has none, so this is the code's `counter()`). -/
def sqCount {X M D : Type} (τ : List (PItem X M × D)) : ℕ := (τ.filter (fun e => isSq e.1)).length

section D55

variable {X M Cl : Type}

/-- **The D55 join head**, computed by the verifier from the forks' chains: for each fork `k < L` in block order, its
index, end state, squeeze counter and claims (`cl k x τ`: the claims its verifier computes from its chain); then `L`. -/
def d55JoinOf (L : ℕ) (d₀ : Dg) (cl : ℕ → X → List (TItem X (D55Head Dg Cl) M × Dg) → Cl) (x : X)
    (τs : List (List (TItem X (D55Head Dg Cl) M × Dg))) : D55Head Dg Cl :=
  .join ((List.range L).map
    (fun k => (k, endD d₀ (τs.getD k []), sqCount (τs.getD k []), cl k x (τs.getD k [])))) L

/-- **The D55 tree**: `L` forks (branch `some k`, head `fork k`, schedule `cs (some k)`) and the join (branch `none`,
head `d55JoinOf`, schedule `cs none`). -/
def d55Tree (L : ℕ) (d₀ : Dg) (cl : ℕ → X → List (TItem X (D55Head Dg Cl) M × Dg) → Cl)
    (cs : Option ℕ → List (SubProt (X × D55Head Dg Cl) M Dg)) (hwpos : ∀ b, ∀ c ∈ cs b, ∀ i, 0 < c.w i)
    (m₀ : M) : Tree X (D55Head Dg Cl) M Dg (Option ℕ) where
  nf := L
  fk := some
  jn := none
  fkHead := D55Head.fork
  joinOf := d55JoinOf L d₀ cl
  brOf := D55Head.br
  br_fk _ := rfl
  br_jn _ _ := rfl
  n b := nOf (cs b)
  w b := wOf (cs b)
  w_pos b := wOf_pos (cs b) (hwpos b)
  hasMsg b := msgOf (cs b)
  m₀ := m₀

variable {Q : Type} [Fintype Q] [DecidableEq Q]

/-- **The D55 run on the code's chains, at the 8B T128 W16R2 parameters.** Every sub-protocol of every fork and of the
join is one of `Kind8B` (the proved LogUp, sumcheck, evaluation-point, batching, free and opening rounds, and `M` with
its ASSUMED error `≤ 2^-106`). The claims fit together: `hframe` per branch, a false statement dooms some fork
(`hstart`), a fork that ends doomed and is accepted has false claims (`hclaims`), a join head with a false claim dooms
the join (`hjoin`), the join's verifier rejects when it ends doomed (`hfinal`). Then a prover making at most `q` hash
queries gets a false statement accepted with probability at most
`(q + ℓT)·135/2^110 + collBound (q + ℓT) + collBound (q + ℓT + 1)`: per hash query `2^-102.92`, for any number of
forks. -/
theorem fs_d55_sound_8B (L : ℕ) (d₀ : Dg) (cl : ℕ → X → List (TItem X (D55Head Dg Cl) M × Dg) → Cl)
    (cs : Option ℕ → List (SubProt (X × D55Head Dg Cl) M Dg)) (hk : ∀ b, ∀ c ∈ cs b, Kind8B c)
    (hwpos : ∀ b, ∀ c ∈ cs b, ∀ i, 0 < c.w i) (m₀ : M) (C : ChainEnc (TItem X (D55Head Dg Cl) M) Q Dg)
    {Mf : Type} {Lg : X → Prop} (accF : ℕ → X × D55Head Dg Cl → List (M × List Dg) → Mf → Prop)
    (accJ : X × D55Head Dg Cl → List (M × List Dg) → Mf → Prop) (ClaimsTrue : X → ℕ → Cl → Prop)
    (hframe : ∀ b, ∀ k xj τ m (bb : Fin (wOf (cs b) τ.length) → Dg), τ.length < nOf (cs b) →
      ownOf (cs b) τ.length ≠ k → ¬ SOf (cs b) k xj τ → SOf (cs b) k xj (τ ++ [(m, List.ofFn bb)]) →
        ∃ k', k < k' ∧ ¬ SOf (cs b) k' xj τ)
    (hstart : ∀ x, ¬ Lg x → ∃ k < L, ∃ i, ¬ SOf (cs (some k)) i (x, D55Head.fork k) [])
    (hclaims : ∀ x k (τ : List (TItem X (D55Head Dg Cl) M × Dg)) ptr mf, k < L →
      rDecodeW (nOf (cs (some k))) (wOf (cs (some k))) (msgOf (cs (some k))) m₀ (τ.drop 2) = some (ptr, none, []) →
      ptr.length = nOf (cs (some k)) → (∃ i, ¬ SOf (cs (some k)) i (x, D55Head.fork k) ptr) →
      accF k (x, D55Head.fork k) ptr mf → ¬ ClaimsTrue x k (cl k x τ))
    (hjoin : ∀ x (es : List (ℕ × Dg × ℕ × Cl)) (l : ℕ), (∃ e ∈ es, ¬ ClaimsTrue x e.1 e.2.2.2) →
      ∃ i, ¬ SOf (cs none) i (x, D55Head.join es l) [])
    (hfinal : ∀ x j ptr mf, ptr.length = nOf (cs none) → (∃ i, ¬ SOf (cs none) i (x, j) ptr) → ¬ accJ (x, j) ptr mf)
    (q : ℕ) (A : OC Q Dg (X × (ℕ → List M) × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ Lg (A.run H).1 ∧ (d55Tree L d₀ cl cs hwpos m₀).Accepts C accF accJ H
        (A.run H).1 (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2)
      ≤ ((q + (d55Tree L d₀ cl cs hwpos m₀).ℓT : ℕ) : ℝ≥0∞) * εRate8B
        + collBound (q + (d55Tree L d₀ cl cs hwpos m₀).ℓT) Dg
        + collBound (q + (d55Tree L d₀ cl cs hwpos m₀).ℓT + 1) Dg := by
  refine (d55Tree L d₀ cl cs hwpos m₀).fs_tree_sound_sched C cs (fun _ => rfl) (fun _ => rfl) accF accJ εRate8B
    (fun b c hc => (hk b c hc).eps_le) hframe hstart ?_ hfinal q A hA
  intro x τs k τ ptr mf hkL hτ hdec hlen hdoom hacc
  have hcl := hclaims x k τ ptr mf hkL hdec hlen hdoom hacc
  have hg : τs.getD k [] = τ := by simp [List.getD_eq_getElem?_getD, hτ]
  refine hjoin x _ L ⟨(k, endD d₀ (τs.getD k []), sqCount (τs.getD k []), cl k x (τs.getD k [])), ?_, ?_⟩
  · exact List.mem_map.mpr ⟨k, List.mem_range.mpr hkL, rfl⟩
  · show ¬ ClaimsTrue x k (cl k x (τs.getD k []))
    rw [hg]
    exact hcl

/-- **The D55 run in the approved target's form**: for `q ≤ 2^76` and a verifier budget `ℓT ≤ 2^76`, the bound is at
most `εsTarget (max q ℓT) = max(q, ℓT)·2^-100 + 2^-100`. -/
theorem fs_d55_sound_8B_target (L : ℕ) (d₀ : Dg) (cl : ℕ → X → List (TItem X (D55Head Dg Cl) M × Dg) → Cl)
    (cs : Option ℕ → List (SubProt (X × D55Head Dg Cl) M Dg)) (hk : ∀ b, ∀ c ∈ cs b, Kind8B c)
    (hwpos : ∀ b, ∀ c ∈ cs b, ∀ i, 0 < c.w i) (m₀ : M) (C : ChainEnc (TItem X (D55Head Dg Cl) M) Q Dg)
    {Mf : Type} {Lg : X → Prop} (accF : ℕ → X × D55Head Dg Cl → List (M × List Dg) → Mf → Prop)
    (accJ : X × D55Head Dg Cl → List (M × List Dg) → Mf → Prop) (ClaimsTrue : X → ℕ → Cl → Prop)
    (hframe : ∀ b, ∀ k xj τ m (bb : Fin (wOf (cs b) τ.length) → Dg), τ.length < nOf (cs b) →
      ownOf (cs b) τ.length ≠ k → ¬ SOf (cs b) k xj τ → SOf (cs b) k xj (τ ++ [(m, List.ofFn bb)]) →
        ∃ k', k < k' ∧ ¬ SOf (cs b) k' xj τ)
    (hstart : ∀ x, ¬ Lg x → ∃ k < L, ∃ i, ¬ SOf (cs (some k)) i (x, D55Head.fork k) [])
    (hclaims : ∀ x k (τ : List (TItem X (D55Head Dg Cl) M × Dg)) ptr mf, k < L →
      rDecodeW (nOf (cs (some k))) (wOf (cs (some k))) (msgOf (cs (some k))) m₀ (τ.drop 2) = some (ptr, none, []) →
      ptr.length = nOf (cs (some k)) → (∃ i, ¬ SOf (cs (some k)) i (x, D55Head.fork k) ptr) →
      accF k (x, D55Head.fork k) ptr mf → ¬ ClaimsTrue x k (cl k x τ))
    (hjoin : ∀ x (es : List (ℕ × Dg × ℕ × Cl)) (l : ℕ), (∃ e ∈ es, ¬ ClaimsTrue x e.1 e.2.2.2) →
      ∃ i, ¬ SOf (cs none) i (x, D55Head.join es l) [])
    (hfinal : ∀ x j ptr mf, ptr.length = nOf (cs none) → (∃ i, ¬ SOf (cs none) i (x, j) ptr) → ¬ accJ (x, j) ptr mf)
    (hℓ : (d55Tree L d₀ cl cs hwpos m₀).ℓT ≤ 2 ^ 76)
    (q : ℕ) (hq : q ≤ 2 ^ 76) (A : OC Q Dg (X × (ℕ → List M) × List M × Mf)) (hA : A.Bounded q) :
    prH (fun H => ¬ Lg (A.run H).1 ∧ (d55Tree L d₀ cl cs hwpos m₀).Accepts C accF accJ H
        (A.run H).1 (A.run H).2.1 (A.run H).2.2.1 (A.run H).2.2.2)
      ≤ εsTarget (max q (d55Tree L d₀ cl cs hwpos m₀).ℓT) := by
  refine (fs_d55_sound_8B L d₀ cl cs hk hwpos m₀ C accF accJ ClaimsTrue hframe hstart hclaims hjoin hfinal q A
    hA).trans ?_
  have h1 := (d55Tree L d₀ cl cs hwpos m₀).join_le_ℓT
  obtain ⟨ℓ, hℓeq⟩ : ∃ ℓ, (d55Tree L d₀ cl cs hwpos m₀).ℓT = ℓ + 1 :=
    ⟨(d55Tree L d₀ cl cs hwpos m₀).ℓT - 1, by omega⟩
  rw [hℓeq, show q + (ℓ + 1) = q + ℓ + 1 by omega]
  exact sound_le_target_max hq (by omega)

end D55

end ZK60.Sound
