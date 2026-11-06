/-
D63, step L1, the run's last stage: the value-for-value test of stage OUT (the next token) and stage OUT-C (the
classifier's verdict) against the Rust token-I/O code, on the R13 trace fixture's output plane.

Run (from the repository root; a guarded `cpu` job):
  lake -d formal env lean --run formal/ZK60Formal/L1CheckOut.lean \
    results/zk60_lean_l2d_20261106/rust_token_out.tsv results/zk60_lean_l1l2_20261106/rust_fixture_trace.tsv

Inputs:
* the export of the Rust test `lean_l1_export_the_token_out_stages` (`private_block/lean_l1_export_tests.rs`): the
  fixture block's output plane `x2` (the LowH24 stack, 32 rows of 16 words), two public synthetic heads over
  `V = 300` (a generic one, and a TIE head whose rows `2k` and `2k + 1` are equal), two final norms (one admitting every
  row, one refusing some), and for every row the code's `out_values` (`d`, `a1`, `a2`, every `y`, `ρ`, `σ`, the token
  and its logit, or the refusal) and the honest witness `witness_from_values` builds (`A_TOK`, `A_M`, the selector `e`
  and the keyed difference `δ` recomposed from its byte limbs); for stage OUT-C, the margin, the verdict and
  `delta_of` under the development policy (`c = 0`);
* the second lane's fixture trace (`rust_fixture_trace.tsv`), to tie `x2` to the block output L1 already checks.

What is checked:
1. SPEC: the Lean model (`ModelOut.lean`: `fnormRowL`, `logitsL`, `firstArgmax`, `outTokenL`, `marginL`,
   `verdictOf`) recomputes every row from `x2`: the refusal exactly when Rust refuses; otherwise the isqrt witness,
   every word, remainder and slack, the token (numpy's first maximum) and its logit; the margin and the verdict.
2. CONSTRAINTS: the clauses of `CircuitOut.lean` are evaluated in `GF` on Rust's witness: the final norm's
   (`IsqrtRel`, the 24-bit isqrt facts, `NormDivRel` with 32-bit remainders, `WordS8`, the input's int16 limbs), the
   keyed argmax's (`ArgRel`: `e(1 − e) = 0`, `δ` in `8·limbs` bits, the host term `M + 2^{−v}(z − tok − δ) = l_z` on the
   LEAN logits, the three selector sums), and the verdict identity (`VerdictRel`).
This file is not imported by the library root (both it and `L1Check.lean` define `main`); `lean --run` elaborates
it in full.
-/
import ZK60Formal.ModelOut
import ZK60Formal.CircuitField

namespace ZK60.L1Out

open ZK60.Model ZK60.Circuit

abbrev Tbl := List (String × Array Int)

def loadTsv (path : System.FilePath) (keyCols : Nat) : IO Tbl := do
  let lines ← IO.FS.lines path
  let mut out : Tbl := []
  for l in lines do
    let cells := l.splitOn "\t"
    if cells.length > keyCols then
      let key := "/".intercalate (cells.take keyCols)
      let vals := (cells.drop keyCols).filterMap String.toInt?
      out := (key, vals.toArray) :: out
  return out

def get (t : Tbl) (k : String) : Array Int := (t.lookup k).getD #[]

def gf (v : Int) : GF := (v : GF)

structure Tally where
  checks : Nat := 0
  fails : Nat := 0
  lines : Array String := #[]

def site (r : IO.Ref Tally) (name : String) (n : Nat) (ok : Nat → Bool) : IO Unit := do
  let mut bad := 0
  let mut first : Option Nat := none
  for i in [0:n] do
    if !ok i then
      bad := bad + 1
      if first.isNone then first := some i
  let line := s!"{name}: {n} checked, {bad} failed" ++ (match first with | some i => s!" (first at {i})" | none => "")
  r.modify fun t => { checks := t.checks + n, fails := t.fails + bad, lines := t.lines.push line }
  if n == 0 then
    r.modify fun t => { t with fails := t.fails + 1, lines := t.lines.push s!"{name}: EMPTY (no data)" }

def wordS8B (q : Int) : Bool := inRangeB 8 (gf q + 127) && inRangeB 8 (-gf q + 127)

def T : Nat := 32
def Dm : Nat := 16

/-- Stage OUT for one (head, norm) case over the 32 rows. -/
def checkOut (r : IO.Ref Tally) (R : Tbl) (x2 : Array Int) (tt nt : String) : IO Unit := do
  let head := get R s!"OUT/{tt}/head"
  let mult := get R s!"OUT/{tt}/mult"
  let case := s!"{tt}-{nt}"
  let p := get R s!"OUT/{case}/params"
  let (g0, cn, tn, ceps, wrho, vlog, limbs, V) :=
    (p.getD 0 0, p.getD 1 0, (p.getD 2 0).toNat, p.getD 3 0, (p.getD 4 0).toNat, (p.getD 5 0).toNat,
      (p.getD 6 0).toNat, (p.getD 7 0).toNat)
  let row := fun (t : Nat) => (List.range Dm).map fun i => x2.getD (t * Dm + i) 0
  let okOf := fun (t : Nat) => (get R s!"OUT/{case}-{t}/ok").getD 0 0
  let rows := (List.range T).filter fun t => okOf t == 1
  let refused := (List.range T).filter fun t => okOf t == 0
  if refused.length > 0 then
    site r s!"OUT {case}: the rows Rust refuses are refused by Lean" refused.length fun k =>
      (outTokenL ceps tn cn g0 wrho V Dm head mult (row (refused.getD k 0))).isNone
  -- the TIE head: rows `2k` and `2k + 1` are equal, so numpy's first maximum is always the even one of its pair
  if tt == "tie" then
    site r s!"OUT {case} tie rule: the token is the even index of an equal pair, the odd one ties it" rows.length fun k =>
      let t := rows.getD k 0
      let tk := (get R s!"OUT/{case}-{t}/tok").getD 0 0
      match fnormRowL ceps tn cn g0 wrho (row t) with
      | none => false
      | some (_, es) =>
        let lg := logitsL V Dm head mult (es.map fun e => e.1)
        tk % 2 == 0 && lg.getD tk.toNat 0 == lg.getD (tk.toNat + 1) 0
  -- the spec, row by row
  site r s!"OUT {case} spec ({rows.length} admitted, {refused.length} refused): isqrt witness, every (y, rho, sigma), token, its logit"
    rows.length fun k =>
    let t := rows.getD k 0
    let g := fun (nm : String) => get R s!"OUT/{case}-{t}/{nm}"
    let iq := g "isqrt"; let y := g "y"; let rho := g "rho"; let sig := g "sigma"; let tk := g "tok"
    match fnormRowL ceps tn cn g0 wrho (row t) with
    | none => false
    | some ((d, a1, a2), es) =>
      let lg := logitsL V Dm head mult (es.map fun e => e.1)
      let tok := firstArgmax lg
      d == iq.getD 0 0 && a1 == iq.getD 1 0 && a2 == iq.getD 2 0 && es.length == Dm &&
        ((List.range Dm).all fun i =>
          let e := es.getD i (0, 0, 0)
          e.1 == y.getD i 0 && e.2.1 == rho.getD i 0 && e.2.2 == sig.getD i 0) &&
        (tok : Int) == tk.getD 0 0 && lg.getD tok 0 == tk.getD 3 0 &&
        outTokenL ceps tn cn g0 wrho V Dm head mult (row t) == some tok
  -- the constraints on Rust's witness
  site r s!"OUT {case} constraints: final norm (IsqrtRel, 24-bit isqrt facts, x int16 limbs, NormDivRel, 32-bit remainders, WordS8)"
    rows.length fun k =>
    let t := rows.getD k 0
    let g := fun (nm : String) => get R s!"OUT/{case}-{t}/{nm}"
    let iq := g "isqrt"; let y := g "y"; let rho := g "rho"; let sig := g "sigma"
    let x := row t
    let d := gf (iq.getD 0 0); let a1 := gf (iq.getD 1 0); let a2 := gf (iq.getD 2 0)
    let ss := gf ceps + (x.map fun v => gf v * gf v).foldl (· + ·) 0
    decide (d * d - d * d = 0 ∧ 2 * d - a1 - a2 = 0 ∧ d * d + a1 = ss) && inRangeB 24 d && inRangeB 24 a1 &&
      inRangeB 24 a2 &&
      (List.range Dm).all fun i =>
        let xi := gf (x.getD i 0); let yi := gf (y.getD i 0); let nr := gf (rho.getD i 0); let ns := gf (sig.getD i 0)
        inRangeB 16 (xi + 32768) &&
        decide (gf g0 * xi * (2 * gf cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * yi - nr = 0 ∧
          nr + ns + 1 - 2 ^ (tn + 1) * d = 0) &&
        inRangeB 32 nr && inRangeB 32 ns && wordS8B (y.getD i 0)
  site r s!"OUT {case} constraints: keyed argmax (e boolean, delta in 8*limbs bits, host term on the Lean logits, three selector sums)"
    rows.length fun k =>
    let t := rows.getD k 0
    let g := fun (nm : String) => get R s!"OUT/{case}-{t}/{nm}"
    let y := g "y"; let tk := g "tok"; let e := g "e"; let δ := g "delta"
    let lg := logitsL V Dm head mult ((List.range Dm).map fun i => y.getD i 0)
    let tokW := gf (tk.getD 1 0); let M := gf (tk.getD 2 0)
    let inv := ((2 : GF) ^ vlog)⁻¹
    (List.range V).all (fun z =>
        let ez := gf (e.getD z 0); let dz := gf (δ.getD z 0)
        decide (ez * (1 - ez) = 0) && inRangeB (8 * limbs) dz &&
          decide (M + inv * ((z : GF) - tokW - dz) = gf (lg.getD z 0))) &&
      decide ((List.range V).foldl (fun a z => a + gf (e.getD z 0)) 0 = 1) &&
      decide ((List.range V).foldl (fun a z => a + gf (e.getD z 0) * (z : GF)) 0 = tokW) &&
      decide ((List.range V).foldl (fun a z => a + gf (e.getD z 0) * gf (δ.getD z 0)) 0 = 0)

/-- Stage OUT-C for one norm over the 32 rows. -/
def checkOutC (r : IO.Ref Tally) (R : Tbl) (x2 : Array Int) (nt : String) : IO Unit := do
  let w := (get R "OUTC/w/w_delta").toList
  let p := get R s!"OUTC/{nt}/params"
  let (g0, cn, tn, ceps, wrho, limbs, c) :=
    (p.getD 0 0, p.getD 1 0, (p.getD 2 0).toNat, p.getD 3 0, (p.getD 4 0).toNat, (p.getD 5 0).toNat, p.getD 6 0)
  let row := fun (t : Nat) => (List.range Dm).map fun i => x2.getD (t * Dm + i) 0
  let okOf := fun (t : Nat) => (get R s!"OUTC/{nt}-{t}/ok").getD 0 0
  let rows := (List.range T).filter fun t => okOf t == 1
  let refused := (List.range T).filter fun t => okOf t == 0
  if refused.length > 0 then
    site r s!"OUT-C {nt}: the rows Rust refuses are refused by Lean" refused.length fun k =>
      (fnormRowL ceps tn cn g0 wrho (row (refused.getD k 0))).isNone
  site r s!"OUT-C {nt} spec ({rows.length} admitted, {refused.length} refused): every y, the margin, the verdict" rows.length fun k =>
    let t := rows.getD k 0
    let y := get R s!"OUTC/{nt}-{t}/y"; let vd := get R s!"OUTC/{nt}-{t}/verdict"
    match fnormRowL ceps tn cn g0 wrho (row t) with
    | none => false
    | some (_, es) =>
      let ys := es.map fun e => e.1
      ((List.range Dm).all fun i => ys.getD i 0 == y.getD i 0) && marginL w ys == vd.getD 0 0 &&
        (verdictOf (marginL w ys) c : Int) == vd.getD 1 0
  site r s!"OUT-C {nt} constraints: VerdictRel (the margin identity, delta in 8*limbs bits)" rows.length fun k =>
    let t := rows.getD k 0
    let vd := get R s!"OUTC/{nt}-{t}/verdict"
    let b := vd.getD 1 0; let dl := gf (vd.getD 2 0)
    let sig : GF := if b == 1 then 1 else -1
    inRangeB (8 * limbs) dl && decide (gf (vd.getD 0 0) = sig * dl + (gf b + gf c))

def main (args : List String) : IO UInt32 := do
  match args with
  | [out, fixture] =>
    let R ← loadTsv out 3
    let F ← loadTsv fixture 2
    let r ← IO.mkRef ({} : Tally)
    let x2 := get R "OUT/fixture/x2"
    let fx2 := get F "low-h24/x2"
    site r "OUT input: the export's x2 = the L1 fixture trace's low-h24 x2" (max x2.size fx2.size) fun i =>
      x2.getD i 0 == fx2.getD i 1 && x2.size == T * Dm
    for tt in ["gen", "tie"] do
      for nt in ["n1", "n2"] do
        checkOut r R x2 tt nt
    for nt in ["n1", "n2"] do
      checkOutC r R x2 nt
    let t ← r.get
    for l in t.lines do IO.println l
    IO.println s!"L1 OUT TOTAL: {t.checks} checks, {t.fails} failed"
    return (if t.fails == 0 then 0 else 1)
  | _ =>
    IO.println "usage: L1CheckOut <rust_token_out.tsv> <rust_fixture_trace.tsv>"
    return 2

end ZK60.L1Out

def main (args : List String) : IO UInt32 := ZK60.L1Out.main args
