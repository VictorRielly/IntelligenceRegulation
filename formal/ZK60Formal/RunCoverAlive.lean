/-
D63 lane L39 (2026-11-10), part 3: **the soundness covers' shapes** (L30 §5.3; findings L30-1, L34-2, GA-7).

L30's gate takes the run's covers as four premises: `halive` (the kinds of the list `Ko` alive in order, `AliveOrd`),
and `hdin`, `hdblk`, `hdout` (a part's conclusion fails ⇒ a sub-protocol of THAT part entered its window doomed). Two
corrections, both proved to cost nothing:

* `halive` is ONE premise over nine kinds. **`rc_aliveOrd9`** splits it into nine premises, one per kind, each
  conditional only on the kinds before it having no doomed entrant (the order L30-1 asks: `opB`, `M`, `opA`, slots,
  relation draws, helper draws, LogUp, as `rtKo` lists them). The next lane proves them one at a time.
* a part's OUTPUT claims are opened by the NEXT part's closing opening (L34-2), so a false endpoint claim of part `i`
  dooms a sub-protocol of part `i + 1`. **`rc_cover3_some`** is L30's `cover3_of_runParts_ord` with `hdin`, `hdblk`,
  `hdout` asking a doomed entrant in SOME part `i < L + 2` (`RcSome`); its conclusion is the same, the premise `h3` of
  L26's gate. **`rc_some_of_part`**: the per-part form implies the some-part form, so the new premises are weaker.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainUOrd

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

section Ord

variable {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **Nine kinds alive in order, kind by kind** (L30's `AliveOrd` from `aliveOrd_cons`): the first kind alive at the
end; each later kind alive at the end provided no earlier kind has a doomed entrant. -/
theorem rc_aliveOrd9 (K₁ K₂ K₃ K₄ K₅ K₆ K₇ K₈ K₉ : KindRun tr) (n : ℕ) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (h₁ : K₁.Al n lg τ) (h₂ : ¬ K₁.Dm n lg τ → K₂.Al n lg τ)
    (h₃ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → K₃.Al n lg τ)
    (h₄ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → K₄.Al n lg τ)
    (h₅ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → ¬ K₄.Dm n lg τ → K₅.Al n lg τ)
    (h₆ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → ¬ K₄.Dm n lg τ → ¬ K₅.Dm n lg τ → K₆.Al n lg τ)
    (h₇ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → ¬ K₄.Dm n lg τ → ¬ K₅.Dm n lg τ → ¬ K₆.Dm n lg τ →
      K₇.Al n lg τ)
    (h₈ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → ¬ K₄.Dm n lg τ → ¬ K₅.Dm n lg τ → ¬ K₆.Dm n lg τ →
      ¬ K₇.Dm n lg τ → K₈.Al n lg τ)
    (h₉ : ¬ K₁.Dm n lg τ → ¬ K₂.Dm n lg τ → ¬ K₃.Dm n lg τ → ¬ K₄.Dm n lg τ → ¬ K₅.Dm n lg τ → ¬ K₆.Dm n lg τ →
      ¬ K₇.Dm n lg τ → ¬ K₈.Dm n lg τ → K₉.Al n lg τ) :
    AliveOrd [K₁, K₂, K₃, K₄, K₅, K₆, K₇, K₈, K₉] n lg τ :=
  aliveOrd_cons K₁ _ n lg τ h₁ fun d₁ =>
  aliveOrd_cons K₂ _ n lg τ (h₂ d₁) fun d₂ =>
  aliveOrd_cons K₃ _ n lg τ (h₃ d₁ d₂) fun d₃ =>
  aliveOrd_cons K₄ _ n lg τ (h₄ d₁ d₂ d₃) fun d₄ =>
  aliveOrd_cons K₅ _ n lg τ (h₅ d₁ d₂ d₃ d₄) fun d₅ =>
  aliveOrd_cons K₆ _ n lg τ (h₆ d₁ d₂ d₃ d₄ d₅) fun d₆ =>
  aliveOrd_cons K₇ _ n lg τ (h₇ d₁ d₂ d₃ d₄ d₅ d₆) fun d₇ =>
  aliveOrd_cons K₈ _ n lg τ (h₈ d₁ d₂ d₃ d₄ d₅ d₆ d₇) fun d₈ =>
  aliveOrd_cons K₉ [] n lg τ (h₉ d₁ d₂ d₃ d₄ d₅ d₆ d₇ d₈) fun _ => aliveOrd_nil n lg τ

/-- **A doomed entrant in SOME part** `i < n` of one of the kinds `Ks`. -/
def RcSome (Ks : List (KindRun tr)) (n : ℕ) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∃ K ∈ Ks, ∃ i, i < n ∧ ∃ c ∈ K.cs i lg, EntD K.RC.W c τ

/-- **The per-part form implies the some-part form**: a doomed entrant in part `j < n` is one in some part. -/
theorem rc_some_of_part (Ks : List (KindRun tr)) (n j : ℕ) (hj : j < n) (lg : List (QB Lq × Dig))
    (τ : List (TItem × Dig)) (h : ∃ K ∈ Ks, ∃ c ∈ K.cs j lg, EntD K.RC.W c τ) : RcSome Ks n lg τ := by
  obtain ⟨K, hK, c, hc, he⟩ := h
  exact ⟨K, hK, j, hj, c, hc, he⟩

end Ord

/-! ## The cover with "some part" -/

section Cover

variable {S : BlockShape} {Lq : ℕ} {Coins : Type}

/-- **THE COVER WITH "SOME PART"** (L30's `cover3_of_runParts_ord` with L34-2's correction, GA-7): on an accepted
receipt outside the extraction failure `Ex`, the kinds of `Ks` alive in order (`halive`), and if stage IN-C's
conclusion, block `k`'s `BlockOn`, or stage OUT-C's conclusion fails, a sub-protocol of SOME part entered its window
doomed. Then an accepted receipt on which one of the three conclusions fails lies in `Ex` or in the event of one of
the kinds: the premise `h3` of L26's gate. -/
theorem rc_cover3_some (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
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
      RcSome Ks (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      RcSome Ks (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true → ¬ Ex A G →
      ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      RcSome Ks (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G))) :
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
    have hev : RcSome Ks (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)) → ∃ K' ∈ Ls, K'.Ev A G := by
      rintro ⟨K, hK, i, hi, hc⟩
      exact kindEv_of_dm_ord Ks (R.Ps.length + 2) hnp Ls hsub A G (halive A G hv hx) ⟨K, hK, i, hi, hc⟩
    by_cases hin : InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
    · by_cases hblk : BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
      · have hout : ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) :=
          fun h => hbad ⟨hin, hblk, h⟩
        exact hev (hdout A G hv hx hout)
      · unfold BlocksOk at hblk
        simp only [not_forall] at hblk
        obtain ⟨k, hk, hk'⟩ := hblk
        exact hev (hdblk A G k hk hv hx hk')
    · exact hev (hdin A G hv hx hin)

end Cover

end ZK60.ProtocolClassify
