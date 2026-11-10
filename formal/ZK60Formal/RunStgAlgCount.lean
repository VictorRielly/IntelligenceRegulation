/-
D63 lane L57 (2026-11-10), part 5: **stage IN-C's LogUp run at the app's profile: its squeeze count and `hD`'s count
condition** (deliverable 3; finding L53-2).

`hD` asks every LogUp run of a part `n · e ≤ 3 · eL` and `e ≤ eL` (`RkPart.Ok.lu`: `RkSqOk … eL (3 · eL)`), `n` the run's
squeezes, `e` its per-round escape count, `eL` the run's LogUp bound. Stage IN-C's head is ONE run of `3 + clog2(d_pad)`
squeezes (`β, γ, α, r_emb`; lane L53's list). At the app's profile (the R13 Shieldstral T128 block: `width = 3072`,
`d_pad = 4096`; CHECKED against hashline's shape.rs and stage_in_c.rs by `l57_count_check.py`, no receipt at that
profile existing) the head is 15 squeezes (`stgShield_m`).

The escape count is the one of IN-C's LogUp state in the code's order (`α` drawn BEFORE `r_emb`, finding L29-3): the
state "the cleared-denominator LogUp identity is a non-zero polynomial in the challenges not yet drawn" (doc §5). Each
query tuple (`tok + β·x~(t, r) + β²·c(t) + γ·TAG`) and table tuple is of degree `≤ 2` in `β`, `1` in `γ` and in each
`r_j`, so the cleared identity has degree `≤ 2·(N + M)` in every one challenge (`N = 2^tiLog` queries, `M = 2^vocLog`
table rows), and `α`'s escape (its roots, with the bad poles of L12-1) is within the same bound: `e = 2·(N + M)`
(`stgInEsc`, an ESTIMATE of the model's per-round degree; the model's round-by-round proof is LEFT).

* **`stgShield_m`**: `incHeadDraws = 15` at `d_pad = 4096`;
* **`stgShield_count`**: at `tiLog = 12`, `vocLog = 17` (`e = 270,336`) and `eL = 2^26` (the run-level LogUp bound,
  lane L36-1): `15 · 270,336 = 4,055,040 ≤ 3 · 2^26` and `270,336 ≤ 2^26`; the condition holds with room
  (`stgShield_count_room`: up to `e ≤ 13,421,772`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.StageVerifyExecInC

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60.Exec ZK60.Exec.StageV

/-- `clog2 4096 = 12`. -/
theorem stgClog2_4096 : clog2 4096 = 12 := by
  have h : Nat.log2 4095 = 11 := (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  simp [clog2, h]

/-- **Stage IN-C's head at the app's profile is 15 squeezes** (`β, γ, α` and the 12 coordinates of `r_emb`). -/
theorem stgShield_m (I : IncPub) (hd : I.dPad = 4096) : incHeadDraws I = 15 := by
  unfold incHeadDraws IncPub.rBits
  rw [hd, stgClog2_4096]

/-- **The per-round escape count of IN-C's LogUp state** (the polynomial-identity model): `2·(2^tiLog + 2^vocLog)`. -/
def stgInEsc (tiLog vocLog : ℕ) : ℕ := 2 * (2 ^ tiLog + 2 ^ vocLog)

/-- **`hD`'s count condition for IN-C's LogUp run at the app's profile**: `15 · e ≤ 3 · 2^26` and `e ≤ 2^26` at
`e = stgInEsc 12 17 = 270,336`. -/
theorem stgShield_count : stgInEsc 12 17 = 270336 ∧ 15 * stgInEsc 12 17 ≤ 3 * 2 ^ 26 ∧ stgInEsc 12 17 ≤ 2 ^ 26 := by
  unfold stgInEsc
  norm_num

/-- **The room**: the condition holds for every escape count up to `13,421,772` (`3 · 2^26 / 15`). -/
theorem stgShield_count_room (e : ℕ) (he : e ≤ 13421772) : 15 * e ≤ 3 * 2 ^ 26 ∧ e ≤ 2 ^ 26 := by
  have h26 : (2 : ℕ) ^ 26 = 67108864 := by norm_num
  rw [h26]
  constructor <;> omega

end ZK60.ProtocolClassify
