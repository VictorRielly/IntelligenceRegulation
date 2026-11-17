/-
D63 lane L63 (2026-11-16), part 28: **`hdzero`'s positions in stage IN-C's own word indexing** (step B, first piece).

The code's input plane is `in_ep_words` words, row-major in rows of `2^8` (`input_plane`, classify.rs:911-917: word `t`
is token `t` for `t < T`, zero after; `input_endpoint_spec`, classify.rs:906-909, one plane row of `in_ep_words`
values at row width `2^ep_log_n`; `data_rows = len >> log_n`, endpoint_g.rs:182-184). INC-00 binds every word of that
plane (`main = clog2(in_ep_words)`, stage_in_c.rs:48, :174-183; `supp(T, words)`). Here:

* `StgInLay`: the top theorem's free layout (`dR`, `pos`) is the code's: `dR · 2^8` words, and a position is a token's
  exactly when its word index `k · 2^8 + i` is below `T`;
* **`ssh_dzero_word`**: under it, a decoded plane non-zero off the token positions is non-zero at some word
  `x = k · 2^8 + i` with `T ≤ x` (and `x < dR · 2^8`): the words INC-00's `supp_T` zeroes.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutTie

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60.Circuit (GF)

/-- **The input plane's layout is the code's** (`input_plane`): `dR` data rows of `2^8` words make `words` words, and
the token positions are exactly the word indices below `tokens`. -/
def StgInLay {T : Type} {dR : ℕ} (pos : T → Fin dR × Fin (2 ^ 8)) (tokens words : ℕ) : Prop :=
  dR * 2 ^ 8 = words ∧ ∀ (k : Fin dR) (i : Fin (2 ^ 8)), (∃ t, pos t = (k, i)) ↔ k.val * 2 ^ 8 + i.val < tokens

/-- **A plane non-zero off the token positions is non-zero at a word past the tokens.** -/
theorem ssh_dzero_word {T : Type} {dR : ℕ} (pos : T → Fin dR × Fin (2 ^ 8)) (tokens words : ℕ)
    (D : Fin dR → Fin (2 ^ 8) → GF) (hLay : StgInLay pos tokens words)
    (h : ¬ ∀ (k : Fin dR) (i : Fin (2 ^ 8)), (¬ ∃ t, pos t = (k, i)) → D k i = 0) :
    ∃ (k : Fin dR) (i : Fin (2 ^ 8)), tokens ≤ k.val * 2 ^ 8 + i.val ∧ k.val * 2 ^ 8 + i.val < words ∧ D k i ≠ 0 := by
  obtain ⟨hdR, hocc⟩ := hLay
  by_contra hno
  apply h
  intro k i hk
  by_contra hD
  apply hno
  refine ⟨k, i, ?_, ?_, hD⟩
  · by_contra hlt
    exact hk ((hocc k i).mpr (Nat.lt_of_not_le hlt))
  · have hk' := k.isLt
    have hi' := i.isLt
    rw [← hdR]
    calc k.val * 2 ^ 8 + i.val < k.val * 2 ^ 8 + 2 ^ 8 := by omega
      _ = (k.val + 1) * 2 ^ 8 := by ring
      _ ≤ dR * 2 ^ 8 := Nat.mul_le_mul_right _ hk'

end ZK60.ProtocolClassify
