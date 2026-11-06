/-
D63, step L1, the run's ends: the token-I/O stages of the integer model in EXECUTABLE Lean, as the Rust reference
computes them (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/`). The block's families are in
`ModelInt.lean`; this file adds the stages before the first block and after the last.

* `fnormElem` — one element of the FINAL norm (`stage_out::out_values`, stage_out.rs:207-235; OUT-C's copy,
  stage_out_c.rs:170-198): `num = 2·x·g0·cn + d·2^tn`, `den = 2·d·2^tn`, `q = ⌊num/den⌋`, `r = num mod den`,
  `s = den − 1 − r`, refused unless `q ∈ [−127, 127]` and `r, s < 2^wrho`. The gain is UNIFORM (`g0`), the word is a
  symmetric int8, and the window is the token profile's `wrho`, which the door pins at exactly 32 bits
  (token_io.rs:502-507, `NORM_LIMBS = 4`).
* `fnormRowL` — the final norm on one int16 row: the isqrt witness of `ss = ceps + Σ x²` (the block's
  `isqrtWitness`), refused when an input word leaves int16 or `d ∉ [1, 2^24)`, `a1, a2 ∉ [0, 2^24)`
  (stage_out.rs:209-214); then every element.
* `argmaxN` / `firstArgmax` — numpy's argmax, the lowest index among equal maxima, exactly the loop of
  `first_argmax` (stage_out.rs:193-201): `best` starts at 0 and moves to `i` only on a STRICT increase. The loop's
  first step (`i = 0`) compares `l[0]` with itself and changes nothing, so starting the fold at 0 is the Rust loop
  `for i in 1..len`.
* `logitsL` — the raw-integer logits `l_j = m_j·Σ_i W'[j][i]·y_i` (`TokenTables::logits`, token_io.rs:668-671; no
  requantization).
* `outTokenL` — stage OUT's integer semantics on one row: the final norm, the logits, the first argmax.
* `marginL`, `verdictOf` — stage OUT-C's margin `Δ = Σ_i w_Δ[i]·y_i` (`ClassifierTables::margin`,
  classify.rs:509-511) and the verdict `1` exactly when `Δ > c` (`u8::from(margin > c)`, stage_out_c.rs:195).
* `embedL` — stage IN's integer semantics (`stage_in::honest_inputs`, stage_in.rs:72-106; IN-C's,
  stage_in_c.rs:72-104): every id below `V`, position 0 the BOS id, every template position its public id and no
  content position a control id (IN-C only), then the embedding rows.
-/
import ZK60Formal.ModelInt

namespace ZK60.Model

/-! ## The final norm -/

/-- One element of the final norm, given the row's `d` (stage_out.rs:217-229): `(q, r, s)` or the refusal. -/
def fnormElem (tn : Nat) (cn g0 : Int) (wrho : Nat) (d x : Int) : Option (Int × Int × Int) :=
  let dv := d * 2 ^ tn
  let den := 2 * dv
  let num := 2 * x * g0 * cn + dv
  let q := num / den
  let r := num % den
  let s := den - 1 - r
  if -127 ≤ q ∧ q ≤ 127 ∧ r < 2 ^ wrho ∧ s < 2 ^ wrho then some (q, r, s) else none

/-- The final norm on one row (stage_out.rs:209-229): the isqrt witness and every element's `(q, r, s)`, or the
refusal. -/
def fnormRowL (ceps : Int) (tn : Nat) (cn g0 : Int) (wrho : Nat) (row : List Int) :
    Option ((Int × Int × Int) × List (Int × Int × Int)) :=
  let ss := ceps + (row.map fun v => v * v).foldl (· + ·) 0
  if ss < 0 then none else
  let w := isqrtWitness ss
  let d := w.1
  if row.any (fun v => !(decide (-32768 ≤ v) && decide (v ≤ 32767))) || d = 0 ||
      !(inIsqrtWindow d && inIsqrtWindow w.2.1 && inIsqrtWindow w.2.2) then none else
  match (row.map (fnormElem tn cn g0 wrho d)).mapM id with
  | some es => some (w, es)
  | none => none

/-! ## The greedy choice -/

/-- `first_argmax` (stage_out.rs:193-201) over `f 0, …, f (n − 1)`: `best` moves to `i` only when `f i > f best`. -/
def argmaxN (f : Nat → Int) (n : Nat) : Nat :=
  (List.range n).foldl (fun b i => if f b < f i then i else b) 0

/-- `first_argmax` on a list (`0` on the empty list, as the Rust loop). -/
def firstArgmax (l : List Int) : Nat := argmaxN (fun i => l.getD i 0) l.length

/-- The raw-integer logits `l_j = m_j·Σ_i W'[j][i]·y_i` (token_io.rs:668-671), `head` row-major `V × d`. -/
def logitsL (V d : Nat) (head mult : Array Int) (y : List Int) : List Int :=
  (List.range V).map fun j =>
    mult.getD j 0 * ((List.range d).foldl (fun a i => a + head.getD (j * d + i) 0 * y.getD i 0) 0)

/-- Stage OUT on one row: the final norm, the logits, the first argmax (`out_values`, stage_out.rs:207-235). -/
def outTokenL (ceps : Int) (tn : Nat) (cn g0 : Int) (wrho V d : Nat) (head mult : Array Int) (row : List Int) :
    Option Nat :=
  (fnormRowL ceps tn cn g0 wrho row).map fun r =>
    firstArgmax (logitsL V d head mult (r.2.map fun e => e.1))

/-! ## The classifier's verdict -/

/-- The margin `Δ = Σ_i w_Δ[i]·y_i` (classify.rs:509-511). -/
def marginL (w : List Int) (y : List Int) : Int := (List.zipWith (· * ·) w y).foldl (· + ·) 0

/-- The verdict: `1` exactly when `Δ > c` (stage_out_c.rs:195). -/
def verdictOf (margin c : Int) : Nat := if c < margin then 1 else 0

/-! ## The embedding -/

/-- Stage IN / IN-C on a prompt (stage_in.rs:72-106, stage_in_c.rs:72-104): the refusals, then `E[tok_t]` row by
row. `isT t` and `kap t` are the classifier's template positions and ids (none for the next-token run), `ns` the
control-id class `[0, ns)` (`ctl(v) = 1` exactly for `v < num_special`, classify.rs:107; `0` for the next-token run). -/
def embedL (V bos ns d : Nat) (isT : Nat → Bool) (kap : Nat → Nat) (emb : Array Int) (toks : List Nat) :
    Option (List (List Int)) :=
  if toks.any (fun t => decide (V ≤ t)) || toks.head? != some bos ||
      ((List.range toks.length).any fun t => isT t && toks.getD t 0 != kap t) ||
      ((List.range toks.length).any fun t => !isT t && decide (toks.getD t 0 < ns)) then none
  else some (toks.map fun v => (List.range d).map fun i => emb.getD (v * d + i) 0)

end ZK60.Model
