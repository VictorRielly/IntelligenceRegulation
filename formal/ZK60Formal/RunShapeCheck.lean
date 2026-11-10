/-
D63 lane L40 (2026-11-10): **the approved integer block RUN on the committed R13 trace fixture** (gap audit GB-8), not
imported by the library root (it defines `main`).

`blockSpecC` (RunShapeExec.lean) is PROVED equal to the approved `blockSpec` (`blockSpecC_eq`), so running it runs the
approved model. This checker builds the fixture's `BlockShape` and `BlockPublic` at both export stacks (LowH24 and
Low) from the committed fixture and the code's documented rules, runs every stage with the twin's pieces, and compares
every plane with the Rust witness builder's words (L1's trace) and with the independent oracle's, then runs
`blockSpecC` whole and `runSpecPC` on the one-block run.

Run (from the repository root; a guarded `cpu` job):
  lake -d formal env lean --run formal/ZK60Formal/RunShapeCheck.lean \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_fixture_t32.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_trace_low_h24_t32.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/block_trace_low_t32.tsv \
    results/zk60_lean_l1l2_20261106/rust_fixture_trace.tsv \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/silu_-4_-13.bin \
    ops/zkp-mvp/gpu-metal/hashline/src/private_block/r13_vectors/silu_-1_-11.bin

The public data, from the fixture (`lean_l1_export_tests.rs:55-119`, the fixture's own builder): 32 tokens, width 16,
hidden 32, 4 query heads of 4 (`half = 2`) over 2 key-value heads (`grp h = h / 2`); `norm_ceps 123`, `cn_a 200`,
`cn_m 180`; the base calibration `(tn 10, qkv 8, s 6, o 9, ao 7, g 8, up 0, h 14, z 6)`, base member `(-3, -11)`; the
shifts are L17's `derive` of that base (CHECKED equal to the trace's `shifts` line); the gate's folded multipliers are
`group_folds_for`'s (accuracy_groups.rs:48-60) of `m_g` (CHECKED equal to the trace's `gate_mult`); the scaled ACT words
are the committed SiLU tables times `2^(24 − 14 + e_out + 11)` (accuracy_aligned.rs:37-46; the product multipliers
CHECKED equal to the trace's `product_mult`). Nothing is read from the trace to BUILD the model: the trace is only
compared with.

A negative control re-runs `blockSpecC` with one single change each (a weight, a shift, a norm constant, an input
word, an exp entry, an ACT word, a gain) and requires each to be caught.
-/
import ZK60Formal.RunShapeExec
import ZK60Formal.ShapeR13

namespace ZK60.RunShape.Check

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.RunShape ZK60.RunShape.Exec
open ZK60.Layout.R13.Shape (Base Prec derive)

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

/-- A little-endian int16 table. -/
def loadI16 (path : System.FilePath) : IO (Array Int) := do
  let b ← IO.FS.readBinFile path
  let n := b.size / 2
  let mut out : Array Int := Array.mkEmpty n
  for k in [0:n] do
    let lo := (b.get! (2 * k)).toNat
    let hi := (b.get! (2 * k + 1)).toNat
    let u := lo + 256 * hi
    out := out.push (if u ≥ 32768 then (u : Int) - 65536 else (u : Int))
  return out

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

/-! ## The fixture's shape and public data -/

/-- The fixture's base calibration (`lean_l1_export_tests.rs:104`). -/
def fixBase : Base := ⟨10, 8, 6, 9, 7, 8, 0, 14, 6⟩

/-- The fixture's group members `(e_in, e_out)` and its base member. -/
def members : List (Int × Int) := [(-4, -13), (-1, -11)]
def baseIn : Int := -3
def baseOut : Int := -11

/-- The gate fold's per-group shift and common shift (accuracy_groups.rs:48-50), at `sh_g = 8`. -/
def gateShiftOf (g : Nat) : Int := 8 + 10 + ((members.getD g (0, 0)).1 - baseIn)
def gateShift : Int := max 17 (max (gateShiftOf 0) (gateShiftOf 1))
/-- The aligned product coefficient's exponent (accuracy_aligned.rs:37), at `sh_h = 14`. -/
def prodExp (g : Nat) : Int := 24 - 14 + ((members.getD g (0, 0)).2 - baseOut)

/-- The shape at a stack, from `derive`'s precision, the gate fold's shift and the aligned product shift. -/
def mkShape (h24 : Bool) (p : Prec) : BlockShape where
  T := 32
  d := 16
  H := 4
  G := 2
  half := 2
  f := 32
  grp h := ⟨h.val / 2, Nat.div_lt_of_lt_mul (by have := h.isLt; omega)⟩
  ceps := 123
  cnA := 200
  cnM := 180
  tn := p.tn
  sq := p.q
  sk := p.k
  sv := p.v
  ss := p.score
  spv := p.pv
  sao := p.ao
  sgate := gateShift.toNat
  sup := p.up
  sprod := if h24 then 16 else 24
  sdown := p.down
  fp := p.fp
  fe := 9
  wrho := 14
  nG := 2
  h24 := h24

/-- A query-width column `(head, (top bit, index))` as the dense layout's index `h·4 + i` (the RoPE pair is
`(i, i + half)`, ModelInt.rope). -/
def qIdx (h : ℕ) (b : Bool) (j : ℕ) : ℕ := h * 4 + (if b then 2 else 0) + j

/-- The changes of the negative control. -/
inductive Mut where
  | none | wq | sq | cnA | input | exp | act | gamma
  deriving BEq, Repr

def mkPub (S : BlockShape) (F : Tbl) (silu : Array (Array Int)) (m : Mut) : BlockPublic S :=
  let gam := get F "gamma"
  let wq := get F "w_q"; let wk := get F "w_k"; let wv := get F "w_v"; let wo := get F "w_o"
  let wg := get F "w_g"; let wu := get F "w_u"; let wd := get F "w_d"
  let mq := get F "m_q"; let mk := get F "m_k"; let mv := get F "m_v"; let mo := get F "m_o"
  let mg := get F "m_g"; let mu := get F "m_u"; let md := get F "m_d"
  let cosT := get F "cos"; let sinT := get F "sin"; let expT := get F "exp"; let grp := get F "groups"
  { gA := fun i => gam.getD i.val 0 + (if m == .gamma && i.val == 0 then 1 else 0)
    gM := fun i => gam.getD i.val 0
    wq := fun i c => wq.getD (i.val * 16 + qIdx c.1.val c.2.1 c.2.2.val) 0
      + (if m == .wq && i.val == 0 && qIdx c.1.val c.2.1 c.2.2.val == 0 then 7 else 0)
    mq := fun c => (mq.getD (qIdx c.1.val c.2.1 c.2.2.val) 1).toNat
    wk := fun i c => wk.getD (i.val * 8 + qIdx c.1.val c.2.1 c.2.2.val) 0
    mK := fun c => (mk.getD (qIdx c.1.val c.2.1 c.2.2.val) 1).toNat
    wv := fun i c => wv.getD (i.val * 8 + qIdx c.1.val c.2.1 c.2.2.val) 0
    mv := fun c => (mv.getD (qIdx c.1.val c.2.1 c.2.2.val) 1).toNat
    wo := fun c j => wo.getD (qIdx c.1.val c.2.1 c.2.2.val * 16 + j.val) 0
    mo := fun j => (mo.getD j.val 1).toNat
    wg := fun i k => wg.getD (i.val * 32 + k.val) 0
    mg := fun k =>
      let g := (grp.getD k.val 0).toNat
      ((mg.getD k.val 1) * 2 ^ (gateShift - gateShiftOf g).toNat).toNat
    wu := fun i k => wu.getD (i.val * 32 + k.val) 0
    mu := fun k => (mu.getD k.val 1).toNat
    wd := fun k j => wd.getD (k.val * 16 + j.val) 0
    md := fun j => (md.getD j.val 1).toNat
    cos := fun t j => cosT.getD (t.val * 2 + j.val) 0
    sin := fun t j => sinT.getD (t.val * 2 + j.val) 0
    exp := fun i => (if 0 ≤ i ∧ i < 256 then expT.getD i.toNat 0 else 0) + (if m == .exp && i == 1 then 3 else 0)
    act := fun g w => (if 0 ≤ w ∧ w < 4096 then (silu.getD g #[]).getD w.toNat 0 * 2 ^ (prodExp g).toNat else 0)
      + (if m == .act && g == 0 && w == 2048 then 5 else 0)
    grpF := fun k => (grp.getD k.val 0).toNat }

/-- The input plane. -/
def mkInput (S : BlockShape) (F : Tbl) (m : Mut) : S.Pos → ℤ :=
  fun p => (get F "input").getD (p.1.val * 16 + p.2.val) 0 + (if m == .input && p.1.val == 3 && p.2.val == 0 then 1 else 0)

/-! ## The check of one stack -/

def checkStack (r : IO.Ref Tally) (F O R : Tbl) (silu : Array (Array Int)) (stack : String) (h24 : Bool) : IO Unit := do
  let g := fun (k : String) => get R s!"{stack}/{k}"
  -- the precision is L17's `derive` of the fixture's base; the trace's shifts line must agree
  let some p := derive h24 fixBase
    | site r s!"{stack} derive accepts the fixture's base" 1 fun _ => false
  let S := mkShape h24 p
  let sh := g "shifts"
  site r s!"{stack} shape = the trace's shifts line (tn q k v score pv ao up down fp gate prod wrho)" 13 fun i =>
    sh.getD i 0 == ([S.tn, S.sq, S.sk, S.sv, S.ss, S.spv, S.sao, S.sup, S.sdown, S.fp, S.sgate, S.sprod, S.wrho].getD i 0
      : Int)
  site r s!"{stack} folded gate multipliers = the trace's gate_mult" 32 fun k =>
    let P := mkPub S F silu .none
    (g "gate_mult").getD k 0 == ((P.mg ⟨k % 32, Nat.mod_lt _ (by norm_num)⟩ : ℕ) : Int)
  site r s!"{stack} product coefficients = the trace's product_mult" 32 fun k =>
    let grp := (get F "groups").getD k 0
    (g "product_mult").getD k 0 == 2 ^ (prodExp grp.toNat).toNat
  let P := mkPub S F silu .none
  let x := mkInput S F .none
  site r s!"{stack} input = trace x" 512 fun i => (g "x").getD i 0 == x (⟨(i / 16) % 32, Nat.mod_lt _ (by norm_num)⟩,
    ⟨i % 16, Nat.mod_lt _ (by norm_num)⟩)
  -- every stage with the twin's pieces, in the block's order
  let fin32 := fun (i : Nat) => (⟨i % 32, Nat.mod_lt _ (by norm_num)⟩ : Fin 32)
  let fin16 := fun (i : Nat) => (⟨i % 16, Nat.mod_lt _ (by norm_num)⟩ : Fin 16)
  let fin4 := fun (i : Nat) => (⟨i % 4, Nat.mod_lt _ (by norm_num)⟩ : Fin 4)
  let fin2 := fun (i : Nat) => (⟨i % 2, Nat.mod_lt _ (by norm_num)⟩ : Fin 2)
  -- a dense query-width index back to `(head, (top bit, j))`
  let qc := fun (c : Nat) => (fin4 (c / 4), (decide ((c % 4) ≥ 2), fin2 (c % 2)))
  let kc := fun (c : Nat) => (fin2 (c / 4), (decide ((c % 4) ≥ 2), fin2 (c % 2)))
  let some na := liftOM (normAC P x) | site r s!"{stack} norm_a accepts" 1 fun _ => false
  site r s!"{stack} norm_a words = trace na.words" 512 fun i => (g "na.words").getD i 0 == (na (fin32 (i / 16))).2 (fin16 i)
  site r s!"{stack} norm_a d = trace na.d" 32 fun t => (g "na.d").getD t 0 == (na (fin32 t)).1
  let some q := liftOM (qSpec P (rowY na)) | site r s!"{stack} Q accepts" 1 fun _ => false
  site r s!"{stack} Q = trace q.words" 512 fun i => (g "q.words").getD i 0 == q (fin32 (i / 16), qc (i % 16))
  let some k := liftOM (kSpec P (rowY na)) | site r s!"{stack} K accepts" 1 fun _ => false
  site r s!"{stack} K = trace k.words" 256 fun i => (g "k.words").getD i 0 == k (fin32 (i / 8), kc (i % 8))
  let some v := liftOM (vSpec P (rowY na)) | site r s!"{stack} V accepts" 1 fun _ => false
  site r s!"{stack} V = trace v.words" 256 fun i => (g "v.words").getD i 0 == v (fin32 (i / 8), kc (i % 8))
  let some qr := liftOM (qrSpec P q) | site r s!"{stack} QR accepts" 1 fun _ => false
  site r s!"{stack} QR = trace qr.words" 512 fun i => (g "qr.words").getD i 0 == qr (fin32 (i / 16), qc (i % 16))
  let some kr := liftOM (krSpec P k) | site r s!"{stack} KR accepts" 1 fun _ => false
  site r s!"{stack} KR = trace kr.words" 256 fun i => (g "kr.words").getD i 0 == kr (fin32 (i / 8), kc (i % 8))
  let some sc := liftOM (sSpec qr kr) | site r s!"{stack} scores accept" 1 fun _ => false
  site r s!"{stack} scores = trace s.words" 4096 fun i =>
    (g "s.words").getD i 0 == sc (fin4 (i / 1024), fin32 (i / 32), fin32 i)
  let some pr := liftOM (smSpecC P sc) | site r s!"{stack} softmax accepts" 1 fun _ => false
  site r s!"{stack} softmax P = trace p" 4096 fun i => (g "p").getD i 0 == pr (fin4 (i / 1024), fin32 (i / 32)) (fin32 i)
  let some o := liftOM (oSpec pr v) | site r s!"{stack} PV accepts" 1 fun _ => false
  site r s!"{stack} O = trace o.words" 512 fun i => (g "o.words").getD i 0 == o (fin32 (i / 16), qc (i % 16))
  let some ao := liftOM (aoSpec P o) | site r s!"{stack} AO accepts" 1 fun _ => false
  site r s!"{stack} AO = trace ao.words" 512 fun i => (g "ao.words").getD i 0 == ao (fin32 (i / 16), fin16 i)
  let some x1 := liftOM (x1Spec x ao) | site r s!"{stack} residual 1 accepts" 1 fun _ => false
  site r s!"{stack} X1 = trace x1" 512 fun i => (g "x1").getD i 0 == x1 (fin32 (i / 16), fin16 i)
  let some nm := liftOM (normMC P x1) | site r s!"{stack} norm_m accepts" 1 fun _ => false
  site r s!"{stack} norm_m words = trace nm.words" 512 fun i => (g "nm.words").getD i 0 == (nm (fin32 (i / 16))).2 (fin16 i)
  let some gt := liftOM (gSpec P (rowY nm)) | site r s!"{stack} gate accepts" 1 fun _ => false
  site r s!"{stack} gate = trace gate.words" 1024 fun i => (g "gate.words").getD i 0 == gt (fin32 (i / 32), fin32 i)
  site r s!"{stack} scaled ACT word = trace a_scaled" 1024 fun i =>
    (g "a_scaled").getD i 0 == actOf P gt (fin32 (i / 32), fin32 i)
  let some u := liftOM (uSpec P (rowY nm)) | site r s!"{stack} up accepts" 1 fun _ => false
  site r s!"{stack} up = trace up.words" 1024 fun i => (g "up.words").getD i 0 == u (fin32 (i / 32), fin32 i)
  let some hh := liftOM (hSpec P gt u) | site r s!"{stack} product accepts" 1 fun _ => false
  site r s!"{stack} product H = trace h.words" 1024 fun i => (g "h.words").getD i 0 == hh (fin32 (i / 32), fin32 i)
  let some z := liftOM (zSpec P hh) | site r s!"{stack} down accepts" 1 fun _ => false
  site r s!"{stack} Z = trace z.words" 512 fun i => (g "z.words").getD i 0 == z (fin32 (i / 16), fin16 i)
  let some x2 := liftOM (x2Spec x1 z) | site r s!"{stack} residual 2 accepts" 1 fun _ => false
  site r s!"{stack} X2 = trace x2" 512 fun i => (g "x2").getD i 0 == x2 (fin32 (i / 16), fin16 i)
  -- the independent oracle's words
  for (ok, n, f) in [("q", 512, fun i => q (fin32 (i / 16), qc (i % 16))),
      ("k", 256, fun i => k (fin32 (i / 8), kc (i % 8))), ("v", 256, fun i => v (fin32 (i / 8), kc (i % 8))),
      ("s", 4096, fun i => sc (fin4 (i / 1024), fin32 (i / 32), fin32 i)),
      ("p", 4096, fun i => pr (fin4 (i / 1024), fin32 (i / 32)) (fin32 i)),
      ("o8", 512, fun i => o (fin32 (i / 16), qc (i % 16))), ("ao", 512, fun i => ao (fin32 (i / 16), fin16 i)),
      ("x1", 512, fun i => x1 (fin32 (i / 16), fin16 i)), ("gate", 1024, fun i => gt (fin32 (i / 32), fin32 i)),
      ("u16", 1024, fun i => u (fin32 (i / 32), fin32 i)), ("h16", 1024, fun i => hh (fin32 (i / 32), fin32 i)),
      ("z16", 512, fun i => z (fin32 (i / 16), fin16 i)), ("x2", 512, fun i => x2 (fin32 (i / 16), fin16 i))] do
    site r s!"{stack} {ok} = oracle" n fun i => (get O ok).getD i 1 == f i
  -- the WHOLE approved block (`blockSpecC = blockSpec`, PROVED) and the one-block per-shape run
  match blockSpecC P x with
  | some y => site r s!"{stack} blockSpecC whole = trace x2" 512 fun i => (g "x2").getD i 0 == y (fin32 (i / 16), fin16 i)
  | none => site r s!"{stack} blockSpecC whole accepts" 1 fun _ => false
  match runSpecPC [(⟨BlockCal.ofShape S, P⟩ : RunBlock S)] x with
  | some y => site r s!"{stack} runSpecPC (one block) = trace x2" 512 fun i =>
      (g "x2").getD i 0 == y (fin32 (i / 16), fin16 i)
  | none => site r s!"{stack} runSpecPC accepts" 1 fun _ => false
  -- the negative control: each single change must change the block's output (or refuse)
  for m in [Mut.wq, .sq, .cnA, .input, .exp, .act, .gamma] do
    let S' : BlockShape := { S with sq := S.sq + (if m == .sq then 1 else 0), cnA := S.cnA + (if m == .cnA then 1 else 0) }
    let P' := mkPub S' F silu m
    let x' := mkInput S' F m
    let caught := match blockSpecC P' x' with
      | some y => (List.range 512).any fun i => (g "x2").getD i 0 != y (fin32 (i / 16), fin16 i)
      | none => true
    r.modify fun t => { t with lines := t.lines.push s!"{stack} negative control {repr m}: {if caught then "caught" else "NOT CAUGHT"}" }
    if !caught then r.modify fun t => { t with fails := t.fails + 1 }

def main (args : List String) : IO UInt32 := do
  match args with
  | [fixture, oH24, oLow, rust, silu0, silu1] =>
    let F ← loadTsv fixture 1
    let OH ← loadTsv oH24 1
    let OL ← loadTsv oLow 1
    let R ← loadTsv rust 2
    let s0 ← loadI16 silu0
    let s1 ← loadI16 silu1
    let r ← IO.mkRef ({} : Tally)
    checkStack r F OH R #[s0, s1] "low-h24" true
    checkStack r F OL R #[s0, s1] "low" false
    let t ← r.get
    for l in t.lines do IO.println l
    IO.println s!"RunShapeCheck: {t.checks} checks, {t.fails} failed"
    return (if t.fails == 0 then 0 else 1)
  | _ =>
    IO.println "usage: RunShapeCheck <fixture.tsv> <oracle_low_h24.tsv> <oracle_low.tsv> <rust_trace.tsv> <silu0.bin> <silu1.bin>"
    return 2

end ZK60.RunShape.Check

def main (args : List String) : IO UInt32 := ZK60.RunShape.Check.main args
