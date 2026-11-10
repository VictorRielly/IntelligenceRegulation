/-
D63 lane L35 (2026-11-09): **the agreement check of the W16R2 block's slot program `DefW16.progW16` against the code.**

Run (through the zk60 resource guard; `results/zk60_lean_l35_20261109/check_l35.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/BlockDefineCheck.lean <L11 corpus.txt> <L9 corpus.txt>

The L11 corpus (`results/zk60_lean_l11_20261107/corpus.txt`) is a real W16R2 rung block receipt's slots, with every
slot's tables (`TAB`), IR (`NODE`, `TERM`) and hosted coefficients (`HOSTED`) as the code builds them; the L9 corpus
(`results/zk60_lean_l9_20261107/corpus.txt`) carries the rung's reserved mask rows (`SITES`).

What it checks, with the Lean definitions only (`DefW16.rawSlot`, `DefW16.progW16` at `DefW16.cfgRungW16`; every
coefficient and challenge word evaluated by `Sym.eval` on the corpus's LogUp challenges and draws):
* per slot (23): the IR's nodes and terms with their coefficient VALUES; the table kinds in order (`eq`, `pub`,
  `priv`); every `eq` table's start and point; the hosted slots with their coefficients; for every table whose code
  label names its plane (`A[p]`, `A[p]_limb_sub-slice_k`, `H[p]`: 156 of the 162 private tables), that the Lean
  table reads that plane (commitment and first slice offset at the Lean layout's offset of plane `p`);
* the reserved mask rows: the rows `[r, r + 1]` of every `A` table of the numbered program, in order, are the
  receipt's `SITES a`; the same for `H` and `SITES h`; the helper `u` plane's rows are `SITES hu`.
It prints the checks per kind and `N checks, F failed`, and exits nonzero on any failure. Not imported by the library
root (it defines `main`).
-/
import ZK60Formal.BlockDefineW16Rung

namespace ZK60.Exec.L35

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Block

/-! ## Parsing (as L13's `SlotW16BuildCheck`) -/

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def f2 (a b : ℕ) : Fp2 := ⟨⟨UInt64.ofNat a⟩, ⟨UInt64.ofNat b⟩⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def f2Str (x : Fp2) : String := s!"{x.c0.v.toNat}:{x.c1.v.toNat}"

def facStr : Factor → String
  | .tab i => s!"t{i}"
  | .node i => s!"n{i}"

def facsStr (fs : List Factor) : String := if fs.isEmpty then "-" else ".".intercalate (fs.map facStr)

def bodyStr : Body Fp2 → String
  | .affine k ts => "A " ++ f2Str k ++ " " ++
      (if ts.isEmpty then "-" else ";".intercalate (ts.map fun p => f2Str p.1 ++ "@t" ++ toString p.2))
  | .sum ss => "S " ++ (if ss.isEmpty then "-" else ";".intercalate (ss.map fun s => f2Str s.coef ++ "@" ++ facsStr s.factors))

def termStr (t : Term Fp2) : String :=
  "T " ++ f2Str t.coef ++ " " ++ (if t.wrapper.isEmpty then "-" else ",".intercalate (t.wrapper.map toString)) ++ " " ++
    facsStr t.inner

def coefStr (s : String) : String :=
  match s.splitOn ":" with
  | a :: b :: _ => a ++ ":" ++ b
  | _ => "?"

def nodeLineStr (w : List String) : String :=
  match w with
  | [_, _, "A", k, ts] =>
    "A " ++ coefStr k ++ " " ++ (if ts = "-" then "-" else ";".intercalate ((ts.splitOn ";").map fun e =>
      match e.splitOn "@" with
      | [c, t] => coefStr c ++ "@" ++ t
      | _ => "?"))
  | [_, _, "S", ss] =>
    "S " ++ (if ss = "-" then "-" else ";".intercalate ((ss.splitOn ";").map fun e =>
      match e.splitOn "@" with
      | [c, f] => coefStr c ++ "@" ++ f
      | _ => "?"))
  | _ => "?"

def termLineStr (w : List String) : String :=
  match w with
  | [_, c, ws, inner] => "T " ++ coefStr c ++ " " ++ ws ++ " " ++ inner
  | _ => "?"

/-- A corpus `TAB` line as `kind`, and for an `eq` table `eq start point`. -/
def tabLineStr (w : List String) : String :=
  match w with
  | [_, _, "eq", st, pt] => "eq " ++ st ++ " " ++ ((pF2s pt).map fun l => ",".intercalate (l.map f2Str)).getD "?"
  | _ :: _ :: "pubv" :: _ => "pub"
  | _ :: _ :: k :: _ => k
  | _ => "?"

/-- A Lean table of the program, in the same form. -/
def tabSStr (ev : Sym → Fp2) : TabS → String
  | .eq pt st => "eq " ++ toString st ++ " " ++ ",".intercalate (pt.map fun s => f2Str (ev s))
  | .pub _ => "pub"
  | .priv _ => "priv"

/-- **The plane a code table reads**, from its `IRTAB` label: `A A[p]_…` (with `_limb_sub-slice_k`), `H H[p]`:
the commitment and the slice's offset by the Lean layout at the code's plane id. `none` for a label without a plane id. -/
def labPlane (c : DefW16.W16Cfg) (k lab : String) : Option String :=
  let num := fun (t : String) => (String.ofList ((t.toList.drop 2).takeWhile Char.isDigit)).toNat?
  if k == "A" && lab.startsWith "A[" then
    match num lab, (lab.splitOn "limb_sub-slice_") with
    | some p, [_, j] => (j.toNat?).map fun j => s!"a {DefW16.aOff c p + j * 2 ^ c.sh.lt}"
    | some p, _ => some s!"a {DefW16.aOff c p}"
    | none, _ => none
  else if k == "H" && lab.startsWith "H[" then
    (num lab).map fun p => s!"h {(DefW16.hOff c p).1}"
  else none

def cmStr : Cm → String
  | .a => "a"
  | .h => "h"
  | .inp => "inp"
  | .out => "out"

/-- The commitment and first slice offset of a Lean table. -/
def tabPlane : TabS → String
  | .priv q => s!"{cmStr q.cm} {(q.slices.headD (0, false)).1}"
  | _ => "-"

/-- A corpus `HOSTED` line's entries. -/
def hostedLine (s : String) : List String := if s = "-" then [] else s.splitOn ";"

/-! ## The checker's state -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 300}" else s.msgs }

def St.cmp (s : St) (kind : String) (what : String) (a b : List String) : St :=
  if a == b then s.check kind true what else
  let i := ((List.range (max a.length b.length)).find? fun i => a.getD i "<none>" != b.getD i "<none>").getD 0
  s.check kind false
    s!"{what}: lengths {a.length}/{b.length}; first difference at {i}: Lean {a.getD i "<none>"} | code {b.getD i "<none>"}"

/-- One slot's record from the corpus. -/
structure SRec where
  s : ℕ := 0
  draws : List Fp2 := []
  tabs : List String := []
  nodes : List String := []
  terms : List String := []
  hosted : List String := []
  irtabs : List (String × String) := []

structure CSt where
  st : St := {}
  logup : Option (Fp2 × Fp2 × Fp2) := none
  prev : List (List Fp2) := []
  cur : SRec := {}
  slots : ℕ := 0
  planes : ℕ := 0

/-- **One slot, Lean against the code.** -/
def CSt.endSlot (c : CSt) : CSt := Id.run do
  let r := c.cur
  let mut st := c.st
  let some (b, g, a) := c.logup | return { c with st := st.check "PARSE" false "no LOGUP" }
  let hist : Hist := ⟨b, g, a, c.prev⟩
  let ev := Sym.eval hist r.s r.draws
  let sl := DefW16.rawSlot DefW16.cfgRungW16 r.s
  let ir := sl.ir.map ev
  let sid := s!"slot {r.s}"
  st := st.cmp "ir-nodes" sid (ir.nodes.map bodyStr) r.nodes
  st := st.cmp "ir-terms" sid (ir.terms.map termStr) r.terms
  st := st.cmp "tables" sid (sl.tabs.map (tabSStr ev)) r.tabs
  st := st.cmp "hosted" sid (sl.hosted.map fun h => s!"{h.1}:{f2Str (ev h.2)}") r.hosted
  let pairs := (sl.tabs.zip r.irtabs).filterMap fun q =>
    (labPlane DefW16.cfgRungW16 q.2.1 q.2.2).map fun e => (tabPlane q.1, e)
  st := st.cmp "planes" sid (pairs.map Prod.fst) (pairs.map Prod.snd)
  st := st.check "planes-aligned" (sl.tabs.length == r.irtabs.length) sid
  return { c with st := st, prev := c.prev ++ [r.draws], slots := c.slots + 1, cur := {}, planes := c.planes + pairs.length }

def CSt.step (c : CSt) (line : String) : CSt :=
  let w := (line.splitOn " ").filter (· ≠ "")
  match w with
  | ["LOGUP", b, g, a] =>
    match pF2 b, pF2 g, pF2 a with
    | some b, some g, some a => { c with logup := some (b, g, a) }
    | _, _, _ => { c with st := c.st.check "PARSE" false line }
  | "SLOT" :: sl :: _ => { c with cur := { s := sl.toNat?.getD 0 } }
  | ["DRAWS", l] =>
    match pF2s l with
    | some v => { c with cur := { c.cur with draws := v } }
    | none => { c with st := c.st.check "PARSE" false line }
  | "TAB" :: _ => { c with cur := { c.cur with tabs := c.cur.tabs ++ [tabLineStr w] } }
  | ["IRTAB", _, k, lab] => { c with cur := { c.cur with irtabs := c.cur.irtabs ++ [(k, lab)] } }
  | "NODE" :: _ => { c with cur := { c.cur with nodes := c.cur.nodes ++ [nodeLineStr w] } }
  | "TERM" :: _ => { c with cur := { c.cur with terms := c.cur.terms ++ [termLineStr w] } }
  | ["HOSTED", h] => { c with cur := { c.cur with hosted := hostedLine h } }
  | ["END", _] => c.endSlot
  | ["DONE", _, _, _] =>
    let msg := s!"{c.planes} tables compared by their plane (the corpus labels 156)"
    { c with st := (c.st.check "slot-count" (c.slots == 23) line).check "planes-count" (c.planes == 156) msg }
  | _ => c

/-! ## The reserved mask rows -/

/-- The rows `[r, r + 1]` of every private table of commitment `cm` in the numbered program, in order. -/
def siteRows (cm : Cm) (prog : List SlotS) : List ℕ :=
  prog.flatMap fun s => s.tabs.flatMap fun t =>
    match t with
    | .priv p => if p.cm = cm then [p.maskRow, p.maskRow + 1] else []
    | _ => []

def checkSites (s0 : St) (lines : List String) : St := Id.run do
  let mut s := s0
  let prog := DefW16.progW16 DefW16.cfgRungW16 0 0
  let some l := lines.find? (·.startsWith "SITES ") | return s.check "PARSE" false "no SITES"
  let w := (l.splitOn " ").filter (· ≠ "")
  match w with
  | ["SITES", "a", la, "h", lh, "hu", u0, u1] =>
    s := s.cmp "sites-a" "SITES a" ((siteRows .a prog).map toString) (((parseCsvNat la).getD []).map toString)
    s := s.cmp "sites-h" "SITES h" ((siteRows .h prog).map toString) (((parseCsvNat lh).getD []).map toString)
    let c := DefW16.cfgRungW16
    let hu := DefW16.hOff c (DefW16.fh c 10)
    s := s.cmp "sites-hu" "SITES hu" [toString (hu.1 / 2 ^ c.logCols), toString (hu.2 / 2 ^ c.logCols)] [u0, u1]
  | _ => s := s.check "PARSE" false l
  return s

end ZK60.Exec.L35

open ZK60.Exec.L35 in
def main (args : List String) : IO UInt32 := do
  let c11 := args.headD "results/zk60_lean_l11_20261107/corpus.txt"
  let c9 := args.getD 1 "results/zk60_lean_l9_20261107/corpus.txt"
  let lines ← IO.FS.lines c11
  let c : CSt := {}
  let c := lines.foldl (fun c l => if l.startsWith "#" || l.all Char.isWhitespace then c else c.step l) c
  let lines9 ← IO.FS.lines c9
  let fin := checkSites c.st lines9.toList
  for (k, n) in fin.kinds do
    IO.println s!"  {k}: {n}"
  for m in fin.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"BlockDefineCheck: {fin.ok + fin.fail} checks, {fin.fail} failed"
  return (if fin.fail = 0 then 0 else 1)
