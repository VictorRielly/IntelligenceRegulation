/-
D63 lane L33 (2026-11-09), part 6: **the question and point bounds of a transcript program as a prover program**
(`zk_of_prog`'s premises `hq` and `hk` for the programs of lanes L25 / L29).

* `qle_mono`, `ptLE_mono`, **`ptLE_of_qle`**: the bounds are monotone, and a program of at most `n` questions has at
  most `n` points;
* `askP_qle`: one tagged question;
* `TOps`: a transcript program (`TProg`) with at most `n` operations (absorbs, squeezes, outside questions) on every
  path;
* **`ofT_qle`**, **`ofT_ptLE`**, **`ofStart_qle`**, **`ofStart_ptLE`**: a transcript program of at most `n` operations
  is, as a prover program, an `n`-question program of at most `n` points (`n + 1` with the transcript's creation).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKHonestRun

set_option autoImplicit false

namespace ZK60.ZKHonest

open ZK60 ZK60.Exec
open ZK60.HonestClassify (TProg)

namespace PProg

variable {Q D α : Type}

/-- The question bound can be raised. -/
theorem qle_mono : ∀ (p : PProg Q D α) (m n : ℕ), QLE p m → m ≤ n → QLE p n
  | .ret _, _, _, _, _ => trivial
  | .dep _ k, m, n, h, hmn =>
    ⟨lt_of_lt_of_le h.1 hmn, fun d => qle_mono (k d) (m - 1) (n - 1) (h.2 d) (Nat.sub_le_sub_right hmn 1)⟩
  | .pt _ k, m, n, h, hmn =>
    ⟨lt_of_lt_of_le h.1 hmn, fun d => qle_mono (k d) (m - 1) (n - 1) (h.2 d) (Nat.sub_le_sub_right hmn 1)⟩

/-- The point bound can be raised. -/
theorem ptLE_mono : ∀ (p : PProg Q D α) (m n : ℕ), PtLE p m → m ≤ n → PtLE p n
  | .ret _, _, _, _, _ => trivial
  | .dep _ k, m, n, h, hmn => fun d => ptLE_mono (k d) m n (h d) hmn
  | .pt _ k, m, n, h, hmn =>
    ⟨lt_of_lt_of_le h.1 hmn, fun d => ptLE_mono (k d) (m - 1) (n - 1) (h.2 d) (Nat.sub_le_sub_right hmn 1)⟩

/-- **A program of at most `n` questions has at most `n` points.** -/
theorem ptLE_of_qle : ∀ (p : PProg Q D α) (n : ℕ), QLE p n → PtLE p n
  | .ret _, _, _ => trivial
  | .dep _ k, n, h => fun d => ptLE_mono (k d) (n - 1) n (ptLE_of_qle (k d) (n - 1) (h.2 d)) (Nat.sub_le n 1)
  | .pt _ k, n, h => ⟨h.1, fun d => ptLE_of_qle (k d) (n - 1) (h.2 d)⟩

end PProg

section Bridge

variable (Lq : ℕ)

/-- One tagged question, then a program of at most `n − 1` questions: at most `n` questions. -/
theorem askP_qle {γ : Type} (isDep : Bool) (q : HIn) (k : Dig → PProg (QB Lq) Dig γ) (n : ℕ) (hn : 0 < n)
    (hk : ∀ d, (k d).QLE (n - 1)) : (askP Lq isDep q k).QLE n := by
  unfold askP
  split_ifs
  · exact ⟨hn, hk⟩
  · exact ⟨hn, hk⟩
  · exact PProg.qle_mono _ (n - 1) n (hk zeroDig) (Nat.sub_le n 1)

variable {β : Type}

/-- **At most `n` operations** (absorbs, squeezes, outside questions) on every path of a transcript program. -/
def TOps : TProg β → ℕ → Prop
  | .done _, _ => True
  | .absorb _ _ k, n => 0 < n ∧ TOps k (n - 1)
  | .squeeze k, n => 0 < n ∧ ∀ dg, TOps (k dg) (n - 1)
  | .ext _ k, n => 0 < n ∧ ∀ dg, TOps (k dg) (n - 1)

/-- **A transcript program of at most `n` operations is an `n`-question prover program.** -/
theorem ofT_qle : ∀ (p : TProg β) (t : Tr) (nd n : ℕ), TOps p n → (ofT Lq p t nd).QLE n
  | .done _, _, _, _, _ => trivial
  | .absorb _ _ k, _, _, n, h => by
    show (askP Lq _ _ _).QLE n
    exact askP_qle Lq _ _ _ n h.1 (fun _ => ofT_qle k _ _ (n - 1) h.2)
  | .squeeze k, _, _, n, h => by
    show (askP Lq _ _ _).QLE n
    exact askP_qle Lq _ _ _ n h.1 (fun dg => ofT_qle (k dg) _ _ (n - 1) (h.2 dg))
  | .ext _ k, t, nd, n, h => by
    show (askP Lq _ _ _).QLE n
    exact askP_qle Lq _ _ _ n h.1 (fun dg => ofT_qle (k dg) t nd (n - 1) (h.2 dg))

/-- … and has at most `n` points. -/
theorem ofT_ptLE (p : TProg β) (t : Tr) (nd n : ℕ) (h : TOps p n) : (ofT Lq p t nd).PtLE n :=
  PProg.ptLE_of_qle _ n (ofT_qle Lq p t nd n h)

/-- From the transcript's creation: `n + 1` questions. -/
theorem ofStart_qle (key : Option Dig) (domain : List UInt8) (p : TProg β) (nd n : ℕ) (h : TOps p n) :
    (ofStart Lq key domain p nd).QLE (n + 1) := by
  unfold ofStart
  refine askP_qle Lq _ _ _ (n + 1) (Nat.succ_pos n) (fun dg => ?_)
  rw [Nat.add_sub_cancel]
  exact ofT_qle Lq p _ nd n h

/-- … and at most `n + 1` points. -/
theorem ofStart_ptLE (key : Option Dig) (domain : List UInt8) (p : TProg β) (nd n : ℕ) (h : TOps p n) :
    (ofStart Lq key domain p nd).PtLE (n + 1) :=
  PProg.ptLE_of_qle _ (n + 1) (ofStart_qle Lq key domain p nd n h)

end Bridge

end ZK60.ZKHonest
