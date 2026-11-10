/-
D63 lane L44 (2026-11-10), deliverable 6: **the agreement check of the R13 block's slot program `DefR13.progR13`
against the code**, on L17's REAL R13 rung block receipt (lane L35's `BlockDefineCheck` for R13).

Run (through the zk60 resource guard):
  lake -d formal env lean --run formal/ZK60Formal/BlockR13ProgCheck.lean <slots corpus> <block corpus> [--neg]

The slots corpus (`results/zk60_lean_l17_20261107/slots_corpus.txt`, L11's format, written by the test-only
`lean_l17_export_tests.rs` from the R13 development rung's block core, proved by the production `prove_core` and
accepted by `verify_core`) carries every slot's tables (`TAB`, `IRTAB`), the code's IR (`NODE`, `TERM`; for `SC_TAB`
`IRNONE`: the code does not transcribe it, L17-9), the hosted coefficients, the terminal values (`VALS`) and the verify
arm's results (`RES`: `c`, the claimed sum, the final value, the challenges, `poly(vals)`, `g`). The block corpus
(`block_corpus.txt`) carries the reserved mask rows (`SITES`).

What it checks, with the Lean definitions only (`DefR13.rawSlot` / `progR13` at `DefR13.cfgRungR13`, every coefficient
and challenge word evaluated by `Sym.eval` on the corpus's LogUp challenges and draws):
* per slot (23): the IR's nodes and terms with their coefficient VALUES (22 slots; `SC_TAB` has no code IR); the
  table kinds in order; every `eq` table's start and point; the hosted slots with their coefficients; for every table
  whose code label names its plane (`A[p]`, `A[p]_limb_sub-slice_k`, `H[p]`), that the Lean table reads that plane
  (commitment and first slice offset at the Lean layout's offset of plane `p`);
* **`ir-value`**: the Lean IR evaluated at the slot's terminal values IS the code's `poly(vals)` (23 slots: for
  `SC_TAB` this is the check of the transcribed IR against the code's closure, finding L17-9);
* the reserved mask rows: the rows `[r, r + 1]` of every `A` table of the numbered program, in order, are the
  receipt's `SITES a`; the same for `H` and `SITES h`; the helper `u` plane's rows are `SITES hu`.
With `--neg` it also runs the negative control: single changes to the corpora, each of which must make the check
fail more than on the unchanged corpora. Prints `N checks, F failed` (and `k of k caught`); exits nonzero on any failure. Not imported by the library root
(it defines `main`).
-/
import ZK60Formal.BlockR13Prog

namespace ZK60.Exec.L44R13

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Block

/-! ## Parsing (as L35's `BlockDefineCheck`) -/

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

def tabLineStr (w : List String) : String :=
  match w with
  | [_, _, "eq", st, pt] => "eq " ++ st ++ " " ++ ((pF2s pt).map fun l => ",".intercalate (l.map f2Str)).getD "?"
  | _ :: _ :: "pubv" :: _ => "pub"
  | _ :: _ :: k :: _ => k
  | _ => "?"

def tabSStr (ev : Sym → Fp2) : TabS → String
  | .eq pt st => "eq " ++ toString st ++ " " ++ ",".intercalate (pt.map fun s => f2Str (ev s))
  | .pub _ => "pub"
  | .priv _ => "priv"

/-- **The plane a code table reads**, from its `IRTAB` label, by the R13 Lean layout. -/
def labPlane (c : DefW16.W16Cfg) (k lab : String) : Option String :=
  let num := fun (t : String) => (String.ofList ((t.toList.drop 2).takeWhile Char.isDigit)).toNat?
  if k == "A" && lab.startsWith "A[" then
    match num lab, (lab.splitOn "limb_sub-slice_") with
    | some p, [_, j] => (j.toNat?).map fun j => s!"a {DefR13.aOff c p + j * 2 ^ c.sh.lt}"
    | some p, _ => some s!"a {DefR13.aOff c p}"
    | none, _ => none
  else if k == "H" && lab.startsWith "H[" then
    (num lab).map fun p => s!"h {(DefR13.hOff c p).1}"
  else none

def cmStr : Cm → String
  | .a => "a"
  | .h => "h"
  | .inp => "inp"
  | .out => "out"

def tabPlane : TabS → String
  | .priv q => s!"{cmStr q.cm} {(q.slices.headD (0, false)).1}"
  | _ => "-"

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

structure SRec where
  s : ℕ := 0
  draws : List Fp2 := []
  tabs : List String := []
  nodes : List String := []
  terms : List String := []
  hosted : List String := []
  irtabs : List (String × String) := []
  hasIr : Bool := false
  vals : List Fp2 := []
  pv : Option Fp2 := none

structure CSt where
  st : St := {}
  logup : Option (Fp2 × Fp2 × Fp2) := none
  prev : List (List Fp2) := []
  cur : SRec := {}
  slots : ℕ := 0
  planes : ℕ := 0

def cfg : DefW16.W16Cfg := DefR13.cfgRungR13

/-- **One slot, Lean against the code.** -/
def CSt.endSlot (c : CSt) : CSt := Id.run do
  let r := c.cur
  let mut st := c.st
  let some (b, g, a) := c.logup | return { c with st := st.check "PARSE" false "no LOGUP" }
  let hist : Hist := ⟨b, g, a, c.prev⟩
  let ev := Sym.eval hist r.s r.draws
  let sl := DefR13.rawSlot cfg r.s
  let ir := sl.ir.map ev
  let sid := s!"slot {r.s}"
  if r.hasIr then
    st := st.cmp "ir-nodes" sid (ir.nodes.map bodyStr) r.nodes
    st := st.cmp "ir-terms" sid (ir.terms.map termStr) r.terms
  st := st.cmp "tables" sid (sl.tabs.map (tabSStr ev)) r.tabs
  st := st.cmp "hosted" sid (sl.hosted.map fun h => s!"{h.1}:{f2Str (ev h.2)}") r.hosted
  match r.pv with
  | some pv =>
    let lv := irEvalW ir r.vals
    st := st.check (if r.hasIr then "ir-value" else "ir-value-tab") (lv == pv) s!"{sid}: Lean {f2Str lv} | code {f2Str pv}"
  | none =>
    st := st.check "PARSE" false s!"{sid}: no RES"
  let pairs := (sl.tabs.zip r.irtabs).filterMap fun q =>
    (labPlane cfg q.2.1 q.2.2).map fun e => (tabPlane q.1, e)
  st := st.cmp "planes" sid (pairs.map Prod.fst) (pairs.map Prod.snd)
  st := st.check "planes-aligned" (!r.hasIr || sl.tabs.length == r.irtabs.length) sid
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
  | "IR" :: _ => { c with cur := { c.cur with hasIr := true } }
  | "NODE" :: _ => { c with cur := { c.cur with nodes := c.cur.nodes ++ [nodeLineStr w] } }
  | "TERM" :: _ => { c with cur := { c.cur with terms := c.cur.terms ++ [termLineStr w] } }
  | ["HOSTED", h] => { c with cur := { c.cur with hosted := hostedLine h } }
  | ["VALS", l] =>
    match pF2s l with
    | some v => { c with cur := { c.cur with vals := v } }
    | none => { c with st := c.st.check "PARSE" false line }
  | ["RES", _, _, _, _, pv, _] =>
    match pF2 pv with
    | some x => { c with cur := { c.cur with pv := some x } }
    | none => { c with st := c.st.check "PARSE" false line }
  | ["END", _] => c.endSlot
  | ["DONE", _, _, _] =>
    { c with st := c.st.check "slot-count" (c.slots == 23) line }
  | _ => c

/-! ## The reserved mask rows -/

def siteRows (cm : Cm) (prog : List SlotS) : List ℕ :=
  prog.flatMap fun s => s.tabs.flatMap fun t =>
    match t with
    | .priv p => if p.cm = cm then [p.maskRow, p.maskRow + 1] else []
    | _ => []

def checkSites (s0 : St) (lines : List String) : St := Id.run do
  let mut s := s0
  let prog := DefR13.progR13 cfg 0 0
  let some l := lines.find? (·.startsWith "SITES ") | return s.check "PARSE" false "no SITES"
  let w := (l.splitOn " ").filter (· ≠ "")
  match w with
  | ["SITES", "a", la, "h", lh, "hu", u0, u1] =>
    s := s.cmp "sites-a" "SITES a" ((siteRows .a prog).map toString) (((parseCsvNat la).getD []).map toString)
    s := s.cmp "sites-h" "SITES h" ((siteRows .h prog).map toString) (((parseCsvNat lh).getD []).map toString)
    let hu := DefR13.hOff cfg (DefR13.fh cfg 10)
    s := s.cmp "sites-hu" "SITES hu" [toString (hu.1 / 2 ^ cfg.logCols), toString (hu.2 / 2 ^ cfg.logCols)] [u0, u1]
  | _ => s := s.check "PARSE" false l
  return s

/-- The whole check on two corpora (as line lists). -/
def runAll (slots block : List String) : St × ℕ :=
  let c : CSt := {}
  let c := slots.foldl (fun c l => if l.startsWith "#" || l.all Char.isWhitespace then c else c.step l) c
  (checkSites c.st block, c.planes)

/-! ## The negative control: single changes, each caught -/

/-- Change word `i` of the first line starting with `pfx` inside slot `s`'s record (`SLOT s` … `END s`). -/
def mutSlot (lines : List String) (s : ℕ) (pfx : String) (i : ℕ) (f : String → String) : List String := Id.run do
  let mut out : Array String := #[]
  let mut inS := false
  let mut done := false
  for l in lines do
    if l.startsWith s!"SLOT {s} " then inS := true
    if l.startsWith s!"END {s}" then inS := false
    if inS && !done && l.startsWith pfx then
      let w := (l.splitOn " ")
      out := out.push (" ".intercalate (w.set i (f (w.getD i ""))))
      done := true
    else
      out := out.push l
  return out.toList

/-- Change word `i` of the first line starting with `pfx` anywhere. -/
def mutLine (lines : List String) (pfx : String) (i : ℕ) (f : String → String) : List String := Id.run do
  let mut out : Array String := #[]
  let mut done := false
  for l in lines do
    if !done && l.startsWith pfx then
      let w := (l.splitOn " ")
      out := out.push (" ".intercalate (w.set i (f (w.getD i ""))))
      done := true
    else
      out := out.push l
  return out.toList

/-- Add `1` to the first number of a comma-separated list. -/
def bumpFirst (t : String) : String :=
  match t.splitOn "," with
  | a :: rest => ",".intercalate (toString ((a.toNat?.getD 0) + 1) :: rest)
  | [] => t

/-- Add `1` to the leading number of a `n:...` token. -/
def bumpLead (t : String) : String :=
  match t.splitOn ":" with
  | a :: rest => ":".intercalate (toString ((a.toNat?.getD 0) + 1) :: rest)
  | [] => t

/-- The mutations, each named. -/
def mutations (sl bl : List String) : List (String × List String × List String) :=
  [("slot 14 c0's first coefficient", mutSlot sl 14 "NODE 4 " 3 bumpLead, bl),
   ("slot 15 table 3 a private table", mutSlot sl 15 "TAB 3 " 2 (fun _ => "priv"), bl),
   ("slot 17 eq point of table 1", mutSlot sl 17 "TAB 1 " 4 bumpFirst, bl),
   ("slot 18 hosted coefficient", mutSlot sl 18 "HOSTED" 1 (fun t => ":".intercalate
      (match t.splitOn ":" with | a :: b :: r => a :: toString ((b.toNat?.getD 0) + 1) :: r | x => x)), bl),
   ("slot 16 first term's wrapper", mutSlot sl 16 "TERM " 2 (fun _ => "1"), bl),
   ("slot 19 (SC_TAB) poly(vals)", mutSlot sl 19 "RES" 5 bumpFirst, bl),
   ("slot 19 (SC_TAB) a terminal value", mutSlot sl 19 "VALS" 1 bumpFirst, bl),
   ("slot 14 table 5's plane label", mutSlot sl 14 "IRTAB 5 " 3 (fun _ => "A[9]_on_its_own_domain"), bl),
   ("slot 21 first draw", mutSlot sl 21 "DRAWS" 1 bumpFirst, bl),
   ("slot 2 node 0's first coefficient", mutSlot sl 2 "NODE 0 " 4 bumpLead, bl),
   ("SITES a first row", sl, mutLine bl "SITES " 2 bumpFirst)]

end ZK60.Exec.L44R13

open ZK60.Exec.L44R13 in
def main (args : List String) : IO UInt32 := do
  let cs := args.headD "results/zk60_lean_l17_20261107/slots_corpus.txt"
  let cb := args.getD 1 "results/zk60_lean_l17_20261107/block_corpus.txt"
  let neg := args.contains "--neg"
  let sl := (← IO.FS.lines cs).toList
  let bl := (← IO.FS.lines cb).toList
  let (fin, planes) := runAll sl bl
  for (k, n) in fin.kinds do
    IO.println s!"  {k}: {n}"
  for m in fin.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"  tables compared by their plane: {planes}"
  IO.println s!"BlockR13ProgCheck: {fin.ok + fin.fail} checks, {fin.fail} failed"
  let mut bad := fin.fail != 0
  if neg then
    let ms := mutations sl bl
    let mut caught := 0
    for (name, sl', bl') in ms do
      let (f, _) := runAll sl' bl'
      if f.fail > fin.fail then
        caught := caught + 1
        IO.println s!"  negative control caught ({f.fail} failed): {name}"
      else
        IO.println s!"  NEGATIVE CONTROL MISSED: {name}"
    IO.println s!"BlockR13ProgCheck negative control: {caught} of {ms.length} caught"
    if caught != ms.length then bad := true
  return (if bad then 1 else 0)
