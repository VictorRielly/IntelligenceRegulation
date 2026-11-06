/-
D63, step L1: the value-for-value test of the Lean integer model (ModelInt.lean) and of the Lean constraints
(CircuitRequant / CircuitNorm / CircuitSoftmax) against the Rust witness builder.

Run (from the repository root; a guarded `cpu` job):
  lake -d formal env lean --run formal/ZK60Formal/L1Check.lean \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_fixture_t32.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_trace_low_h24_t32.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_trace_low_t32.tsv \
    results/zk60_lean_l1l2_20261106/rust_fixture_trace.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/r13_requant_vectors.tsv

Inputs:
* the R13 trace fixture (`block_fixture_t32.tsv`: 32 tokens, width 16, hidden 32, 4 query heads of 4 over 2 KV
  heads; public synthetic weights, gains, RoPE and exp tables, multipliers, groups);
* the independent oracle's word traces of both export stacks (`block_trace_low{,_h24}_t32.tsv`, which the Rust test
  `both_export_stacks_match_the_independent_full_block_oracle` holds equal to the builder);
* the WHOLE Rust witness of the same fixture, every word, remainder, isqrt witness and softmax internal, exported by
  the test `lean_l1_export_the_fixture_trace` (`private_block/lean_l1_export_tests.rs`);
* `r13_requant_vectors.tsv`, the requantization's independent rational vectors (accuracy.rs:74-83).

What is checked, per stack (LowH24 = the W16R2 stack, and Low):
1. SPEC: every stage is recomputed in Lean from the previous stage's Rust words (matmuls, RoPE, scores, softmax, PV,
   residuals, both norms) and the Lean words AND remainders must equal Rust's, and the words the oracle's.
2. CONSTRAINTS: every family's Lean constraint is evaluated in `GF` on Rust's witness and must hold: the host relation
   `HostRel` (`hostRes = 0`), the word class lookups (`Word16`, `WordS8`, `Word24`, `GateWord`) and remainder lookups
   (`RemW16` in its limbs) through `inRangeB` (`inRangeB_iff`), the residual clause, the isqrt clauses, the norm
   division clauses, the softmax division clauses, the argmax clauses and the row sums.
The public activation table (SiLU) is not recomputed: its values are taken from the Rust trace, and only its
functionality (same `(group, gate)`, same value) is checked.

The rung (second lane, 2026-11-06): an optional sixth argument, the trace of the test
`lean_l1_export_the_t128_rung_trace` (both stacks, tags `t128-h24` and `t128-low`), runs the same check at `T = 128`
with the RoPE rows and the input the export prints; no oracle trace exists there, so the oracle comparisons are skipped.
-/
import ZK60Formal.CircuitNorm
import ZK60Formal.CircuitSoftmax

namespace ZK60.L1

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

/-- `HostRel` as a residual: it holds iff this is zero (`hostRes_zero_iff`). -/
def hostRes (s : ℕ) (a q R : GF) : GF := 2 ^ s * q + R - 2 ^ (s - 1) - a

theorem hostRes_zero_iff (s : ℕ) (a q R : GF) : hostRes s a q R = 0 ↔ HostRel s a q R := by
  unfold hostRes HostRel; exact sub_eq_zero

/-- `RemW16 b` decided on an integer remainder, through its W16 limbs and `inRangeB`. -/
def remB (b : ℕ) (r : Int) : Bool :=
  if b ≤ 16 then inRangeB b (gf r)
  else inRangeB 16 (gf (r % 2 ^ 16)) && inRangeB (b - 16) (gf (r / 2 ^ 16)) &&
    decide (gf r = gf (r % 2 ^ 16) + 2 ^ 16 * gf (r / 2 ^ 16))

/-- The word class lookups, decided in the field as the code looks them up. -/
def word16B (q : Int) : Bool := inRangeB 16 (gf q + 32768)
def wordS8B (q : Int) : Bool := inRangeB 8 (gf q + 127) && inRangeB 8 (-gf q + 127)
def word24B (h : Int) : Bool :=
  let top := (h + 2 ^ 23) / 2 ^ 16 - 128
  inRangeB 16 (gf h - 2 ^ 16 * gf top) && inRangeB 8 (gf top + 128)
def gateB (g : Int) : Bool := inRangeB 12 (gf g + 2048)

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

/-- One requantization site: the spec on the Lean accumulators, against Rust's words and remainders; the host
relation, the word class and the remainder's limbs on Rust's witness. -/
def reqSite (r : IO.Ref Tally) (name : String) (acc : Array Int) (mult : Nat → Nat) (s : Nat) (lo hi : Int)
    (cls : Int → Bool) (words rho : Array Int) : IO Unit := do
  site r s!"{name} spec (word, remainder)" acc.size fun i =>
    match requantIn lo hi (acc.getD i 0) (mult i) s with
    | some (w, q) => w == words.getD i 0 && q == rho.getD i 0
    | none => false
  site r s!"{name} constraints (HostRel, word lookup, remainder limbs)" acc.size fun i =>
    let a := acc.getD i 0 * (mult i : Int)
    decide (hostRes s (gf a) (gf (words.getD i 0)) (gf (rho.getD i 0)) = 0) && cls (words.getD i 0) &&
      remB s (rho.getD i 0)

def T : Nat := 32
def Dm : Nat := 16
def Hd : Nat := 32
def HQ : Nat := 4
def HKV : Nat := 2
def DH : Nat := 4

/-- The whole check of one export stack at `T` tokens (32 at the fixture, 128 at the rung of the second lane), with
the RoPE rows and the input the export used; the oracle comparisons run only when `oracle` (the oracle traces exist at
the fixture only). -/
def checkStack (r : IO.Ref Tally) (F O R : Tbl) (stack : String) (T : Nat) (cosT sinT inputT : Array Int)
    (oracle : Bool) : IO Unit := do
  let g := fun (k : String) => get R s!"{stack}/{k}"
  let sh := g "shifts"
  let (tn, sq, sk, sv, ss, spv, sao, sup, sdown, fp, sgate, sprod, wrho) :=
    (sh.getD 0 0, sh.getD 1 0, sh.getD 2 0, sh.getD 3 0, sh.getD 4 0, sh.getD 5 0, sh.getD 6 0, sh.getD 7 0,
      sh.getD 8 0, sh.getD 9 0, sh.getD 10 0, sh.getD 11 0, sh.getD 12 0)
  let n := fun (v : Int) => v.toNat
  let gamma := (get F "gamma").toList
  let x := g "x"
  site r s!"{stack} input = fixture" x.size fun i => x.getD i 0 == inputT.getD i 0
  -- the two norms
  let normCheck : String → Int → Array Int → String → IO Unit := fun tag cn xin oname => do
    let words := g s!"{tag}.words"; let rho := g s!"{tag}.rho"; let sig := g s!"{tag}.sigma"
    let dd := g s!"{tag}.d"; let dsq := g s!"{tag}.dsq"; let a1 := g s!"{tag}.a1"; let a2 := g s!"{tag}.a2"
    site r s!"{stack} {tag} spec (isqrt witness, word, remainder, slack)" T fun t =>
      let row := (List.range Dm).map fun i => xin.getD (t * Dm + i) 0
      match normRow 123 (n tn) cn gamma row with
      | some ((d, b1, b2), es) =>
        d == dd.getD t 0 && b1 == a1.getD t 0 && b2 == a2.getD t 0 &&
          ((List.range Dm).zip es).all fun ⟨i, (q, rr, s)⟩ =>
            q == words.getD (t * Dm + i) 0 && rr == rho.getD (t * Dm + i) 0 && s == sig.getD (t * Dm + i) 0
      | none => false
    if oracle then
      site r s!"{stack} {tag} = oracle" words.size fun i => words.getD i 0 == (get O oname).getD i 0
    site r s!"{stack} {tag} isqrt constraints (IsqrtRel, 24-bit facts)" T fun t =>
      let ssv := 123 + ((List.range Dm).map fun i => xin.getD (t * Dm + i) 0 ^ 2).foldl (· + ·) 0
      let (d, q, b1, b2) := (dd.getD t 0, dsq.getD t 0, a1.getD t 0, a2.getD t 0)
      decide (gf q - gf d * gf d = 0) && decide (2 * gf d - gf b1 - gf b2 = 0) && decide (gf q + gf b1 = gf ssv) &&
        inRangeB 24 (gf d) && inRangeB 24 (gf b1) && inRangeB 24 (gf b2)
    site r s!"{stack} {tag} division constraints (NormDivRel, 24-bit remainders, int16 word)" (T * Dm) fun j =>
      let t := j / Dm; let i := j % Dm
      let (gm, xv, d, y, nr, ns) :=
        (gf (gamma.getD i 0), gf (xin.getD j 0), gf (dd.getD t 0), gf (words.getD j 0), rho.getD j 0, sig.getD j 0)
      decide (gm * xv * (2 * gf cn) + d * 2 ^ (n tn) - 2 ^ (n tn + 1) * d * y - gf nr = 0) &&
        decide (gf nr + gf ns + 1 - 2 ^ (n tn + 1) * d = 0) && remB 24 nr && remB 24 ns && word16B (words.getD j 0)
  normCheck "na" 200 x "y"
  let y := g "na.words"
  -- Q, K, V
  let wq := get F "w_q"; let wk := get F "w_k"; let wv := get F "w_v"; let wo := get F "w_o"
  let mq := get F "m_q"; let mk := get F "m_k"; let mv := get F "m_v"; let mo := get F "m_o"
  let qacc := matmulIO T Dm 16 y wq
  reqSite r s!"{stack} Q" qacc (fun i => n (mq.getD (i % 16) 1)) (n sq) (-32768) 32767 word16B (g "q.words") (g "q.rho")
  let kacc := matmulIO T Dm 8 y wk
  reqSite r s!"{stack} K" kacc (fun i => n (mk.getD (i % 8) 1)) (n sk) (-32768) 32767 word16B (g "k.words") (g "k.rho")
  let vacc := matmulIO T Dm 8 y wv
  reqSite r s!"{stack} V" vacc (fun i => n (mv.getD (i % 8) 1)) (n sv) (-32768) 32767 word16B (g "v.words") (g "v.rho")
  -- RoPE
  let cos := cosT; let sin := sinT
  let qracc := rope T HQ DH 16 cos sin (g "q.words")
  reqSite r s!"{stack} QR" qracc (fun _ => 1) 7 (-32768) 32767 word16B (g "qr.words") (g "qr.rho")
  let kracc := rope T HKV DH 8 cos sin (g "k.words")
  reqSite r s!"{stack} KR" kracc (fun _ => 1) 7 (-32768) 32767 word16B (g "kr.words") (g "kr.rho")
  -- scores
  let qr := g "qr.words"; let kr := g "kr.words"
  let sacc : Array Int := Id.run do
    let mut out := #[]
    for h in [0:HQ] do
      for t in [0:T] do
        for j in [0:T] do
          let mut a : Int := 0
          for i in [0:DH] do
            a := a + qr.getD (t * 16 + h * DH + i) 0 * kr.getD (j * 8 + (h / 2) * DH + i) 0
          out := out.push a
    return out
  reqSite r s!"{stack} score" sacc (fun _ => 1) (n ss) (-127) 127 wordS8B (g "s.words") (g "s.rho")
  -- softmax
  let sw := g "s.words"; let exp := get F "exp"
  let (mx, sum, zsel, e, p, sr, sg) := (g "mx", g "sum", g "zsel", g "e", g "p", g "sr", g "sg")
  site r s!"{stack} softmax spec (max, total, zsel, e, P, sr, sg)" (HQ * T) fun ht =>
    let row := (List.range T).map fun j => sw.getD (ht * T + j) 0
    match softmaxRow (n fp) (n wrho) exp (ht % T) row with
    | some (best, _, total, cols) =>
      best == mx.getD ht 0 && total == sum.getD ht 0 &&
        ((List.range T).zip cols).all fun ⟨j, (z, ev, pv, srv, sgv)⟩ =>
          let k := ht * T + j
          z == zsel.getD k 0 && ev == e.getD k 0 && pv == p.getD k 0 && srv == sr.getD k 0 && sgv == sg.getD k 0
    | none => false
  site r s!"{stack} softmax division constraints (c2, c3, P direct, sr/sg limbs)" (HQ * T * T) fun k =>
    let t := (k / T) % T; let j := k % T
    let num : Int := if j ≤ t then e.getD k 0 * 2 ^ (n fp) else 0
    let su := sum.getD (k / T) 0
    decide (gf num - gf (p.getD k 0) * gf su - gf (sr.getD k 0) = 0) &&
      decide (gf (sg.getD k 0) + gf (sr.getD k 0) + 1 - gf su = 0) && inRangeB (n fp + 1) (gf (p.getD k 0)) &&
      remB (n wrho) (sr.getD k 0) && remB (n wrho) (sg.getD k 0)
  site r s!"{stack} argmax constraints (row sum of zsel = 1, zsel·δ = 0, δ an exp index, c0)" (HQ * T) fun ht =>
    let t := ht % T
    let live := (List.range (t + 1)).map fun j => ht * T + j
    decide (((live.map fun k => gf (zsel.getD k 0)).foldl (· + ·) 0) = 1) &&
      live.all fun k =>
        let δ := gf (mx.getD ht 0) - gf (sw.getD k 0)
        decide (gf (zsel.getD k 0) * δ = 0) && inRangeB 8 δ &&
          decide (gf (zsel.getD k 0) * gf (zsel.getD k 0) - gf (zsel.getD k 0) = 0)
  site r s!"{stack} exp tuple (δ, e) is a table tuple" (HQ * T * T) fun k =>
    let t := (k / T) % T; let j := k % T
    let masked := if j ≤ t then sw.getD k 0 else maskScore
    let δ := mx.getD (k / T) 0 - masked
    decide (0 ≤ δ ∧ δ < 256) && e.getD k 0 == exp.getD δ.toNat 0
  -- PV
  let vw := g "v.words"
  let oacc : Array Int := Id.run do
    let mut out : Array Int := Array.replicate (T * 16) 0
    for h in [0:HQ] do
      for t in [0:T] do
        for i in [0:DH] do
          let mut a : Int := 0
          for j in [0:t + 1] do
            a := a + p.getD ((h * T + t) * T + j) 0 * vw.getD (j * 8 + (h / 2) * DH + i) 0
          out := out.set! (t * 16 + h * DH + i) a
    return out
  reqSite r s!"{stack} O (PV)" oacc (fun _ => 1) (n spv) (-32768) 32767 word16B (g "o.words") (g "o.rho")
  -- output projection, residual 1
  let aoacc := matmulIO T 16 Dm (g "o.words") wo
  reqSite r s!"{stack} AO" aoacc (fun i => n (mo.getD (i % Dm) 1)) (n sao) (-32768) 32767 word16B (g "ao.words")
    (g "ao.rho")
  let ao := g "ao.words"; let x1 := g "x1"
  site r s!"{stack} residual 1 spec and constraint" (T * Dm) fun i =>
    ZK60.Model.residual (x.getD i 0) (ao.getD i 0) == some (x1.getD i 0) &&
      decide (gf (x1.getD i 0) - gf (x.getD i 0) - gf (ao.getD i 0) = 0) && word16B (x1.getD i 0)
  normCheck "nm" 180 x1 "nm"
  -- gate, up, product, down, residual 2
  let nm := g "nm.words"
  let gm := g "gate_mult"; let mu := get F "m_u"; let md := get F "m_d"
  let gacc := matmulIO T Dm Hd nm (get F "w_g")
  reqSite r s!"{stack} gate" gacc (fun i => n (gm.getD (i % Hd) 1)) (n sgate) (-2048) 2047 gateB (g "gate.words")
    (g "gate.rho")
  let uacc := matmulIO T Dm Hd nm (get F "w_u")
  reqSite r s!"{stack} up" uacc (fun i => n (mu.getD (i % Hd) 1)) (n sup) (-32768) 32767 word16B (g "up.words")
    (g "up.rho")
  let asc := g "a_scaled"; let gw := g "gate.words"; let grp := get F "groups"
  site r s!"{stack} activation table is a function of (group, gate)" (T * Hd) fun i =>
    (List.range (T * Hd)).all fun k =>
      !(grp.getD (k % Hd) 0 == grp.getD (i % Hd) 0 && gw.getD k 0 == gw.getD i 0) || asc.getD k 0 == asc.getD i 0
  let uw := g "up.words"
  let hacc := (List.range (T * Hd)).toArray.map fun i => asc.getD i 0 * uw.getD i 0
  -- the LowH24 stack (its 24-bit product word) at the fixture (`low-h24`) and at the rung (`t128-h24`)
  let h24 := stack == "low-h24" || stack == "t128-h24"
  let hb : Int := if h24 then 2 ^ 23 else 2 ^ 15
  reqSite r s!"{stack} product H" hacc (fun _ => 1) (n sprod) (-hb) (hb - 1) (if h24 then word24B else word16B)
    (g "h.words") (g "h.rho")
  let zacc := matmulIO T Hd Dm (g "h.words") (get F "w_d")
  reqSite r s!"{stack} down Z" zacc (fun i => n (md.getD (i % Dm) 1)) (n sdown) (-32768) 32767 word16B (g "z.words")
    (g "z.rho")
  let z := g "z.words"; let x2 := g "x2"
  site r s!"{stack} residual 2 spec and constraint" (T * Dm) fun i =>
    ZK60.Model.residual (x1.getD i 0) (z.getD i 0) == some (x2.getD i 0) &&
      decide (gf (x2.getD i 0) - gf (x1.getD i 0) - gf (z.getD i 0) = 0) && word16B (x2.getD i 0)
  -- every word site against the independent oracle
  if oracle then
    for (rk, ok) in [("q.words", "q"), ("k.words", "k"), ("v.words", "v"), ("qr.words", "qr"), ("kr.words", "kr"),
        ("s.words", "s"), ("p", "p"), ("o.words", "o8"), ("ao.words", "ao"), ("x1", "x1"), ("gate.words", "gate"),
        ("a_scaled", "a_scaled"), ("up.words", "u16"), ("h.words", "h16"), ("z.words", "z16"), ("x2", "x2")] do
      let a := g rk; let b := get O ok
      site r s!"{stack} {rk} = oracle {ok}" (max a.size b.size) fun i => a.getD i 0 == b.getD i 1

def main (args : List String) : IO UInt32 := do
  match args with
  | fixture :: oH24 :: oLow :: rust :: vectors :: rest =>
    let F ← loadTsv fixture 1
    let OH ← loadTsv oH24 1
    let OL ← loadTsv oLow 1
    let R ← loadTsv rust 2
    let r ← IO.mkRef ({} : Tally)
    checkStack r F OH R "low-h24" T (get F "cos") (get F "sin") (get F "input") true
    checkStack r F OL R "low" T (get F "cos") (get F "sin") (get F "input") true
    -- the second lane's rung at the 8B token count, T = 128 (its RoPE rows and input come with the trace; no oracle)
    match rest with
    | [rung] =>
      let RR ← loadTsv rung 2
      for tag in ["t128-h24", "t128-low"] do
        checkStack r F [] RR tag 128 (get RR s!"{tag}/cos") (get RR s!"{tag}/sin") (get RR s!"{tag}/input") false
    | _ => pure ()
    -- the requantization's independent rational vectors: (acc, m, shift, word)
    let vl ← IO.FS.lines vectors
    let rows := vl.toList.map fun l => (l.splitOn "\t").filterMap String.toInt?
    site r "r13_requant_vectors (accuracy.rs:74-83)" rows.length fun i =>
      match rows.getD i [] with
      | [a, m, s, w] => (requant a m.toNat s.toNat).1 == w
      | _ => false
    let t ← r.get
    for l in t.lines do IO.println l
    IO.println s!"L1 TOTAL: {t.checks} checks, {t.fails} failed"
    return (if t.fails == 0 then 0 else 1)
  | _ =>
    IO.println ("usage: L1Check <fixture.tsv> <oracle_low_h24.tsv> <oracle_low.tsv> <rust_trace.tsv> " ++
      "<requant_vectors.tsv> [<rung_t128_trace.tsv>]")
    return 2

end ZK60.L1

def main (args : List String) : IO UInt32 := ZK60.L1.main args
