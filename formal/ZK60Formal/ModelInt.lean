/-
D63, step L1: the discretized (integer) model, in EXECUTABLE Lean, family by family, as the Rust integer reference
computes it (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/witness_accuracy.rs`, the R13/W16 accuracy stack that
the W16R2 profile proves; `accuracy.rs` for the requantization).

Every function here is computable and total. A function that can REFUSE returns `Option`: `none` is exactly the
honest prover's refusal of an inadmissible trace (the builder's `Err(range(..))`), so `admissible` of the statement
`CircuitIff` is "no stage returns `none`".

The families, with the Rust source of each:
* `requant` — `accuracy::requant` (accuracy.rs:12-27): `n = acc·m + 2^(s−1)`, word `⌊n / 2^s⌋`, remainder
  `n mod 2^s` (the arithmetic shift and the low `s` bits). `requantIn` adds the class check of
  `witness_accuracy::quantized` (witness_accuracy.rs:373-391): the word must lie in `[lo, hi]`.
* `residual` — `witness_accuracy::residual` (witness_accuracy.rs:459-469): `x + y`, refused outside int16.
* `normRow` — `witness_accuracy::normalized` (witness_accuracy.rs:414-457), one token row: `ss = ceps + Σ x²`,
  `d = isqrt ss` with `a1 = ss − d²`, `a2 = 2d − a1`, each in `[0, 2^24)` and `d ≠ 0`; then per element
  `num = 2·x·γ·cn + d·2^tn`, `den = 2·d·2^tn`, `q = ⌊num/den⌋`, `r = num mod den`, `s = den − 1 − r`, refused unless
  `q ∈ int16`, `r < 2^24`, `s < 2^24`.
* `softmaxRow` — the softmax loop of `build_with` (witness_accuracy.rs:869-904, the sequential reference): the row
  maximum over `j ≤ t`, the first argmax, `total = Σ_{j≤t} exp[best − s_j]`, and per `j` the masked score, `e`, the
  quotient `P = (e·2^f_p)/total` (zero when masked), `sr`, `sg = total − 1 − sr` (refused when `sg ≥ 2^wrho_s`).
* the block's linear maps (`matmulIO`, `rope`), used by the L1 check (`L1Check.lean`) to rebuild each stage from the
  trace's own inputs: `witness.rs:837-905` (`matmul`, `matmul_in_out`) and `witness.rs:944-958` (`rotate`).

Lean's `Int` division `/` and `%` are the Euclidean ones (`Int.ediv`, `Int.emod`); for a positive divisor they are
the floor and the nonnegative remainder, which is what Rust's `div_euclid` / `rem_euclid` and the arithmetic shift
compute (accuracy.rs:20-26, `requant_shift_form_equals_euclid`).
-/

namespace ZK60.Model

/-! ## Requantization -/

/-- `accuracy::requant` without its class check: `(⌊(acc·m + 2^(s−1)) / 2^s⌋, (acc·m + 2^(s−1)) mod 2^s)`. -/
def requant (acc : Int) (m : Nat) (s : Nat) : Int × Int :=
  let n := acc * (m : Int) + 2 ^ (s - 1)
  (n / 2 ^ s, n % 2 ^ s)

/-- The requantization with the word class `[lo, hi]` of `quantized` (the honest prover refuses outside it). -/
def requantIn (lo hi : Int) (acc : Int) (m : Nat) (s : Nat) : Option (Int × Int) :=
  let r := requant acc m s
  if lo ≤ r.1 ∧ r.1 ≤ hi then some r else none

/-- int16, the class of every W16 word: `[-2^15, 2^15 − 1]`. -/
def int16Lo : Int := -32768
def int16Hi : Int := 32767

/-! ## Residual -/

/-- `witness_accuracy::residual` at one position: `x + y`, refused outside int16. -/
def residual (x y : Int) : Option Int :=
  if int16Lo ≤ x + y ∧ x + y ≤ int16Hi then some (x + y) else none

/-! ## RMSNorm (one token row) -/

/-- The isqrt witness of one row: `d = isqrt ss`, `a1 = ss − d²`, `a2 = 2d − a1`. -/
def isqrtWitness (ss : Int) : Int × Int × Int :=
  let d : Int := (Nat.sqrt ss.toNat : Int)
  (d, ss - d * d, 2 * d - (ss - d * d))

/-- The window `[0, 2^24)` of the three isqrt values (`LIMBS_ISQRT = 3` bytes, shape.rs:29). -/
def inIsqrtWindow (v : Int) : Bool := decide (0 ≤ v ∧ v < 2 ^ 24)

/-- One element of a norm row, given the row's `d`: `(q, r, s)` or the refusal. -/
def normElem (tn : Nat) (cn : Int) (d : Int) (x g : Int) : Option (Int × Int × Int) :=
  let dv := d * 2 ^ tn
  let den := 2 * dv
  let num := 2 * x * g * cn + dv
  let q := num / den
  let r := num % den
  let s := den - 1 - r
  if int16Lo ≤ q ∧ q ≤ int16Hi ∧ r < 2 ^ 24 ∧ s < 2 ^ 24 then some (q, r, s) else none

/-- One norm row (`normalized`'s loop body at token `t`): the isqrt witness `(d, a1, a2)` and each element's
`(q, r, s)`, or the refusal. -/
def normRow (ceps : Int) (tn : Nat) (cn : Int) (gamma row : List Int) :
    Option ((Int × Int × Int) × List (Int × Int × Int)) :=
  let ss := ceps + (row.map fun v => v * v).foldl (· + ·) 0
  if ss < 0 then none else
  let w := isqrtWitness ss
  let d := w.1
  if d = 0 ∨ !(inIsqrtWindow d && inIsqrtWindow w.2.1 && inIsqrtWindow w.2.2) then none else
  match (List.zipWith (normElem tn cn d) row gamma).mapM id with
  | some es => some (w, es)
  | none => none

/-! ## Softmax (one score row) -/

/-- The masked score of `softmax`: `MASK_SCORE = −127` beyond the causal row (layout.rs:75). -/
def maskScore : Int := -127

/-- One softmax row at token `t` over `T` columns, from the int8 scores `s` of the row (length `T`), the public exp
table `exp` (indexed by `0 ≤ δ < 256`), `f_p` and the window `wrho_s`. Returns the row maximum, the first argmax,
the total, and per column `(zsel, e, P, sr, sg)`; or the refusal. -/
def softmaxRow (fp wrho : Nat) (exp : Array Int) (t : Nat) (s : List Int) :
    Option (Int × Nat × Int × List (Int × Int × Int × Int × Int)) :=
  let live := s.take (t + 1)
  match live.max? with
  | none => none
  | some best =>
    let arg := (live.findIdx? (· == best)).getD 0
    let ex := fun (δ : Int) => if 0 ≤ δ ∧ δ < 256 then some (exp.getD δ.toNat 0) else none
    match (live.map fun sj => ex (best - sj)).mapM id with
    | none => none
    | some es =>
      let total := es.foldl (· + ·) 0
      if total ≤ 0 then none else
      let col := fun (j : Nat) (sj : Int) =>
        let masked := if j ≤ t then sj else maskScore
        match ex (best - masked) with
        | none => none
        | some e =>
          let num := if j ≤ t then e * 2 ^ fp else 0
          let p := num / total
          let sr := num % total
          let sg := total - 1 - sr
          if sg ≥ 2 ^ wrho then none
          else some ((if j = arg then (1 : Int) else 0), e, p, sr, sg)
      match ((List.range s.length).zip s |>.map fun js => col js.1 js.2).mapM id with
      | none => none
      | some cols => some (best, arg, total, cols)

/-! ## Linear maps of the block (for the L1 check) -/

/-- `out[t][j] = Σ_i x[t][i] · W[i][j]`, `x` dense `T × inner` and `W` input-major `inner × outer`
(`matmul_in_out`, witness.rs:870; `matmul` reads the transposed copy and gives the same sums). -/
def matmulIO (T inner outer : Nat) (x w : Array Int) : Array Int := Id.run do
  let mut out : Array Int := Array.mkEmpty (T * outer)
  for t in [0:T] do
    for j in [0:outer] do
      let mut acc : Int := 0
      for i in [0:inner] do
        acc := acc + x.getD (t * inner + i) 0 * w.getD (i * outer + j) 0
      out := out.push acc
  return out

/-- `rotate` (witness.rs:944-958) before its requantization: per token `t`, head `h` and `i < half`,
`(c·a − s·b, s·a + c·b)` of the pair `(x[i], x[half + i])`, with the per-token tables `cos`, `sin`. -/
def rope (T heads dh width : Nat) (cos sin x : Array Int) : Array Int := Id.run do
  let half := dh / 2
  let mut out : Array Int := Array.replicate (T * width) 0
  for t in [0:T] do
    for h in [0:heads] do
      let base := t * width + h * dh
      for i in [0:half] do
        let c := cos.getD (t * half + i) 0
        let s := sin.getD (t * half + i) 0
        let a := x.getD (base + i) 0
        let b := x.getD (base + half + i) 0
        out := out.set! (base + i) (c * a - s * b)
        out := out.set! (base + half + i) (s * a + c * b)
  return out

end ZK60.Model
