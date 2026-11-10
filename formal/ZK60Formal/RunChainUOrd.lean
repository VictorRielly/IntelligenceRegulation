/-
D63 lane L30 (2026-11-09), part 2: **the run's cover with the kinds' aliveness taken IN ORDER** (the adapter between
L27's `cover3_of_runParts` and the premise `h3` of L26's `classifyU_productionReady_ep_target`).

`cover3_of_runParts` fits `h3` as a term (see `RunChainUGate.lean`), but its premise `halive` asks that on EVERY
accepted run outside the extraction failure every sub-protocol of EVERY kind is alive at the end of the transcript.
Acceptance does not give that for the kinds whose final state depends on an earlier check being sound: an opening's
first half (`opA`: alive means the `(λ, ρ)` combination is close, which the verifier does not see; L20's
`opening_split` gives it only when the second half did not enter doomed), the slots (their final claims are true
only when the openings' claimed values are), the define draws and LogUp. A prover that passes a column test by luck
is accepted with a dead first half, so the flat premise cannot be discharged (finding L30-1).

The per-block results of L20 to L23 and L28 are already in the ordered form (`hexec`: good or the chain event;
`hcoverR` and `hsplit` under `OpenTrue` and the claimed sums). This file states the run's cover the same way:

* `KindRun.Dm`, `KindRun.Al`: a kind has a sub-protocol that entered its window doomed; all its sub-protocols are
  alive at the end;
* **`AliveOrd`**: for a list of kinds IN ORDER, each kind is alive at the end PROVIDED no earlier kind of the list has
  a doomed entrant (`opB` and `M` first: alive on acceptance; then `opA`; then the slots; then the relations' draws,
  the helpers' draws, LogUp); `aliveOrd_of_all`: L27's flat premise is the special case; `aliveOrd_nil`,
  **`aliveOrd_cons`**: the order built one kind at a time (the first kind alive, and the rest alive in order if the
  first has no doomed entrant);
* **`exists_dm_al`**: if some kind of the list has a doomed entrant, the FIRST such kind is alive at the end;
* **`kindEv_of_dm_ord`**: so some kind's event (L24's `FirstKind.Ev`) holds;
* **`cover3_of_runParts_ord`**: `cover3_of_runParts` with `halive` replaced by the ordered premise; its conclusion is
  the same, the premise `h3` of L26's gate.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainCover

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

/-! ## Doomed entrants and aliveness, kind by kind -/

section Ord

variable {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **The kind has a doomed entrant** among its first `n` parts: some sub-protocol of the kind entered its window with
a false claim (of the data extracted from the log `lg`) on the transcript `τ`. -/
@[reducible] def KindRun.Dm (K : KindRun tr) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∃ i, i < n ∧ ∃ c ∈ K.cs i lg, EntD K.RC.W c τ

/-- **The kind is alive at the end**: every sub-protocol of its first `n` parts is alive on the transcript `τ`. -/
@[reducible] def KindRun.Al (K : KindRun tr) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ i, i < n → allSt K.RC.W (K.cs i lg) τ

/-- **The kinds are alive IN ORDER** (D63 lane L30): each kind of the list is alive at the end provided no EARLIER kind
of the list has a doomed entrant. The order is the order in which the checks depend on each other: a kind whose final
state the verifier checks directly comes first; a kind whose final state is true only when an earlier kind's claims
are comes after it. -/
@[reducible] def AliveOrd (Ks : List (KindRun tr)) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ (j : ℕ) (K : KindRun tr), Ks[j]? = some K →
    (∀ (j' : ℕ) (K' : KindRun tr), j' < j → Ks[j']? = some K' → ¬ K'.Dm n lg τ) → K.Al n lg τ

/-- L27's flat premise (every kind alive, whatever the others do) is a special case of the ordered one. -/
theorem aliveOrd_of_all (Ks : List (KindRun tr)) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ K ∈ Ks, K.Al n lg τ) : AliveOrd Ks n lg τ :=
  fun _ K hK _ => h K (List.mem_of_getElem? hK)

/-- The empty list of kinds is alive in order. -/
theorem aliveOrd_nil (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) :
    AliveOrd ([] : List (KindRun tr)) n lg τ := by
  intro _ _ hK _
  simp at hK

/-- **The order, one kind at a time**: the first kind is alive at the end, and IF it has no doomed entrant the rest
of the list is alive in order. This is how the premise `halive` is built: `opB` (alive on acceptance), then `opA`
(alive when no `opB` entered doomed, L20's `opening_split`), and so on. -/
theorem aliveOrd_cons (K : KindRun tr) (Ks : List (KindRun tr)) (n : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (hK : K.Al n lg τ) (hKs : ¬ K.Dm n lg τ → AliveOrd Ks n lg τ) :
    AliveOrd (K :: Ks) n lg τ := by
  intro j K' hj hprev
  cases j with
  | zero =>
    have h0 : K = K' := by simpa using hj
    subst h0
    exact hK
  | succ j =>
    have hj' : Ks[j]? = some K' := by simpa using hj
    exact hKs (hprev 0 K (Nat.succ_pos j) rfl) j K' hj'
      (fun i K'' hi hK'' => hprev (i + 1) K'' (Nat.succ_lt_succ hi) (by simpa using hK''))

/-- **The first kind with a doomed entrant is alive at the end**: if the kinds are alive in order and some kind has a
doomed entrant, then some kind has a doomed entrant AND is alive at the end. -/
theorem exists_dm_al (Ks : List (KindRun tr)) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hal : AliveOrd Ks n lg τ) (hd : ∃ K ∈ Ks, K.Dm n lg τ) : ∃ K ∈ Ks, K.Dm n lg τ ∧ K.Al n lg τ := by
  classical
  obtain ⟨K₀, hK₀, hd₀⟩ := hd
  obtain ⟨j₀, hj₀⟩ := List.mem_iff_getElem?.mp hK₀
  have hex : ∃ j : ℕ, ∃ K : KindRun tr, Ks[j]? = some K ∧ K.Dm n lg τ := ⟨j₀, K₀, hj₀, hd₀⟩
  obtain ⟨K, hK, hdK⟩ := Nat.find_spec hex
  exact ⟨K, List.mem_of_getElem? hK, hdK,
    hal (Nat.find hex) K hK (fun _ K' hj' hK' hd' => Nat.find_min hex hj' ⟨K', hK', hd'⟩)⟩

/-- **A doomed entrant gives a kind's event** (D63 lane L30): the kinds alive in order on the run's transcript, some
kind with a doomed entrant: the event (L24's `FirstKind.Ev`) of some kind holds, read in any list `Ls` that holds the
kinds. -/
theorem kindEv_of_dm_ord (Ks : List (KindRun tr)) (n : ℕ) (hnp : ∀ K ∈ Ks, K.np = n)
    (Ls : List (FirstKind Lq α)) (hsub : ∀ K ∈ Ks, K.toFirstKind ∈ Ls) (A : OC (QB Lq) Dig α) (G : QB Lq → Dig)
    (hal : AliveOrd Ks n (A.runLog G).2 (tr G (A.run G)))
    (hd : ∃ K ∈ Ks, K.Dm n (A.runLog G).2 (tr G (A.run G))) : ∃ K' ∈ Ls, K'.Ev A G := by
  obtain ⟨K, hK, hdK, haK⟩ := exists_dm_al Ks n _ _ hal hd
  obtain ⟨i, hi, hc⟩ := hdK
  exact ⟨K.toFirstKind, hsub K hK, K.ev_of_parts A G ⟨i, by rw [hnp K hK]; exact hi, hc⟩
    (fun j hj => haK j (by rw [← hnp K hK]; exact hj))⟩

end Ord

/-! ## The cover of stage IN-C, the blocks and stage OUT-C, the kinds alive in order -/

section Cover

variable {S : BlockShape} {Lq : ℕ} {Coins : Type}

/-- **The cover of stage IN-C, the blocks and stage OUT-C from per-part covers, the kinds alive IN ORDER** (D63 lane
L30; L27's `cover3_of_runParts` with its flat `halive` replaced). On an accepted receipt outside the extraction
failure `Ex`: (`halive`) the kinds of the list `Ks` are alive in order (`AliveOrd`); (`hdin`, `hdblk`, `hdout`) if
stage IN-C's conclusion, block `k`'s `BlockOn` on the extracted planes `B_k` and `B_{k+1}`, or stage OUT-C's
conclusion for the statement's verdict fails, some kind's sub-protocol of that part entered its window doomed on the
run's transcript. Then an accepted receipt on which one of the three conclusions fails lies in `Ex` or in the event
of one of the kinds, read in any list `Ls` that holds them: the premise `h3` of L26's
`classifyU_productionReady_ep_target`. The protocol is any `Protocol` on the classify model. -/
theorem cover3_of_runParts_ord (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (tr : (QB Lq → Dig) → P.Stmt × P.Receipt → List (TItem × Dig))
    (Ks : List (KindRun tr)) (hnp : ∀ K ∈ Ks, K.np = R.Ps.length + 2)
    (Ls : List (FirstKind Lq (P.Stmt × P.Receipt))) (hsub : ∀ K ∈ Ks, K.toFirstKind ∈ Ls)
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop)
    (halive : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      AliveOrd Ks (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs 0 (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (k + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) →
        Ex A G ∨ ∃ K ∈ Ls, K.Ev A G := by
  intro A G hv hbad
  by_cases hx : Ex A G
  · exact Or.inl hx
  · right
    have hev : ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 → (∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
        → ∃ K' ∈ Ls, K'.Ev A G := by
      intro K hK i hi hc
      exact kindEv_of_dm_ord Ks (R.Ps.length + 2) hnp Ls hsub A G (halive A G hv hx) ⟨K, hK, i, hi, hc⟩
    by_cases hin : InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
    · by_cases hblk : BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      · have hout : ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) :=
          fun h => hbad ⟨hin, hblk, h⟩
        obtain ⟨K, hK, hc⟩ := hdout A G hv hx hout
        exact hev K hK _ (by omega) hc
      · unfold BlocksOk at hblk
        simp only [not_forall] at hblk
        obtain ⟨k, hk, hk'⟩ := hblk
        obtain ⟨K, hK, hc⟩ := hdblk A G k hk hv hx hk'
        exact hev K hK _ (by omega) hc
    · obtain ⟨K, hK, hc⟩ := hdin A G hv hx hin
      exact hev K hK 0 (by omega) hc

end Cover

end ZK60.ProtocolClassify
