/-
D63 lane L44 (2026-11-10), deliverable 6: **the R13 rung's slot program `DefR13.progR13` against every table the code
builds, table by table, and the layout's plane offsets**: deliverable 5's export check (`BlockHelperExportCheck`, the
W16R2 program against the W16R2 export) on the R13 export `results/zk60_lean_l44_20261110/l44_r13_corpus.txt` (the same
test-only `lean_l44_export_tests.rs`, on a REAL R13 rung block receipt), with `progR13`, `cfgRungR13`, `R13.rungSlots`
and R13's layout (`DefR13.aOff`, `hOff`, `hDoms`, `domEnd`).

Run (through the zk60 resource guard):
  lake -d formal env lean --run formal/ZK60Formal/BlockR13ProgExportCheck.lean <corpus> [neg]

What it checks (every challenge word evaluated by `Sym.eval` on the corpus's LogUp challenges and draws): the header
(slots, `A` and `H` plane counts, row log), every domain's `rows_of`, every `a_off`, every `h_off` pair; per slot the
schedule and table count, and per table its kind, an `eq` table's start and point, a public table's length, a private
table's commitment, slices, log size, coordinates, reserved mask row and extension round, and the claim the code pushed
for it against the library's `buildClaim` (every part's offset, log size, coefficient and point, and the value). The
public tables' VALUES are not compared. With `neg` it runs the negative controls (single changes, each caught). Not
imported by the library root (it defines `main`).
-/
import ZK60Formal.BlockR13Prog

namespace ZK60.Exec.L44R13Exp

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Block

/-! ## Parsing -/

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

/-- A word as the corpus writes it: `c0,c1`. -/
def w2 (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

def w2s (l : List Fp2) : String := if l.isEmpty then "-" else ",".intercalate (l.map w2)

def cmStr : Cm → String
  | .a => "a"
  | .h => "h"
  | .inp => "inp"
  | .out => "out"

def coordStr : Coord → String
  | .rho k => s!"r{k}"
  | .flip k => s!"f{k}"
  | .fixed v => s!"x{v.c0.v.toNat}:{v.c1.v.toNat}"

def slicesStr (l : List (ℕ × Fp2)) : String := ";".intercalate (l.map fun q => s!"{q.1}:{w2 q.2}")

def coordsStr (l : List Coord) : String := if l.isEmpty then "-" else ",".intercalate (l.map coordStr)

def partStr (p : ZK60.Exec.Block.ZPart) : String := s!"{p.offset}:{p.logSize}:{w2 p.coef}:{w2s p.point}"

def claimStr (c : ZK60.Exec.Block.ZClaim) : String := "|".intercalate (c.parts.map partStr)

/-! ## The checker's state (as `BlockDefineCheck`'s) -/

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
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 400}" else s.msgs }

def St.eqS (s : St) (kind what lean code : String) : St :=
  s.check kind (lean == code) s!"{what}: Lean {lean.take 180} | code {code.take 180}"

def St.cmp (s : St) (kind : String) (what : String) (a b : List String) : St :=
  if a == b then s.check kind true what else
  let i := ((List.range (max a.length b.length)).find? fun i => a.getD i "<none>" != b.getD i "<none>").getD 0
  s.check kind false
    s!"{what}: lengths {a.length}/{b.length}; first difference at {i}: Lean {a.getD i "<none>"} | code {b.getD i "<none>"}"

/-- One table line of the corpus. -/
inductive CTab
  | eq (i : ℕ) (start : String) (pt : String)
  | pub (i : ℕ) (len : ℕ)
  | priv (i : ℕ) (cm log row ext slices coords : String)

/-- One slot's record. -/
structure SRec where
  s : ℕ := 0
  n : ℕ := 0
  ext : ℕ := 0
  nTabs : ℕ := 0
  draws : List Fp2 := []
  terms : List Fp2 := []
  rho : List Fp2 := []
  es : List Fp2 := []
  tabs : List CTab := []
  claims : List (ℕ × String × String × String) := []

structure CSt where
  st : St := {}
  logup : Option (Fp2 × Fp2 × Fp2) := none
  io : ℕ × ℕ := (0, 0)
  eLog : ℕ := 0
  prog : List SlotS := []
  prev : List (List Fp2) := []
  cur : SRec := {}
  slots : ℕ := 0
  privs : ℕ := 0

/-- **The parameters `buildClaim` reads** (its row logs: `logCols` for `A` and `H`, the endpoint's for the IO
commitments); every other field is a stand-in that `buildClaim` does not read. -/
def pChk (eLog : ℕ) : BlockParams where
  geom := ⟨ZK60.Exec.Block.R13.rungSlots, [], 0, 0, 0, 0, 0, ⟨0, 0, 0, 0⟩, 0, 0, 0, 0, 0⟩
  logCols := DefR13.cfgRungR13.logCols
  endpointLogN := eLog
  aRows := 0
  hRows := 0
  aPath := 0
  hPath := 0
  maskPath := 0
  preChecks := .ok ()
  kind _ := .priv
  name _ := ""
  draws _ := 0
  define _ _ _ := .error "stand-in"
  nFunctionals := 0
  logupSumClaim := ⟨[], Fp2.zero⟩
  maskVerify _ _ _ _ t := .ok t
  checkOpening _ _ _ _ := .ok ()
  pcsVerify _ _ _ _ _ t := .ok t

/-- **One slot, Lean against the code.** -/
def CSt.endSlot (c : CSt) : CSt := Id.run do
  let r := c.cur
  let mut st := c.st
  let some (b, g, a) := c.logup | return { c with st := st.check "PARSE" false "no LOGUP" }
  let hist : Hist := ⟨b, g, a, c.prev⟩
  let ev := Sym.eval hist r.s r.draws
  let sl := c.prog.getD r.s SlotS.empty
  let tabs := sl.tabs.map (TabS.eval ev (fun _ => []))
  let sid := s!"slot {r.s}"
  let shp := ZK60.Exec.Block.R13.rungSlots.getD r.s (0, 0, 0)
  st := st.eqS "schedule" sid s!"{shp.1} {shp.2.1}" s!"{r.n} {r.ext}"
  st := st.eqS "table-count" sid (toString tabs.length) (toString r.nTabs)
  st := st.eqS "table-lines" sid (toString tabs.length) (toString r.tabs.length)
  let P := pChk c.eLog
  let cd := oneMinusProd r.es
  let mut k := 0
  let mut privs := 0
  for (t, ct) in tabs.zip r.tabs do
    match t, ct with
    | .eq pt start, .eq i cs cp =>
      st := st.eqS "eq-start" s!"{sid} table {i}" (toString start) cs
      st := st.eqS "eq-point" s!"{sid} table {i}" (w2s pt) cp
    | .pub _, .pub i len =>
      st := st.eqS "pub-length" s!"{sid} table {i}" (toString (2 ^ shp.1)) (toString len)
    | .priv p, .priv i ccm clog crow cext csl cco =>
      let w := s!"{sid} table {i}"
      st := st.eqS "priv-cm" w (cmStr p.cm) ccm
      st := st.eqS "priv-log" w (toString p.log) clog
      st := st.eqS "priv-maskrow" w (toString p.maskRow) crow
      st := st.eqS "priv-extround" w (toString p.extRound) cext
      st := st.eqS "priv-slices" w (slicesStr p.slices) csl
      st := st.eqS "priv-coords" w (coordsStr p.coords) cco
      let cl := buildClaim P p (claimPoint p r.rho) cd (maskCoef r.es p.extRound) (r.terms.getD k Fp2.zero)
      match r.claims.find? (·.1 == i) with
      | some (_, ccm2, cval, cparts) =>
        st := st.eqS "claim-cm" w (cmStr p.cm) ccm2
        st := st.eqS "claim-value" w (w2 cl.value) cval
        st := st.eqS "claim-parts" w (claimStr cl) cparts
      | none => st := st.check "claim-parts" false s!"{w}: no CLAIM line"
      k := k + 1
      privs := privs + 1
    | _, _ => st := st.check "table-kind" false s!"{sid}: a table of another kind"
  st := st.eqS "claim-count" sid (toString k) (toString r.claims.length)
  st := st.eqS "terminal-count" sid (toString k) (toString r.terms.length)
  return { c with st := st, prev := c.prev ++ [r.draws], slots := c.slots + 1, cur := {}, privs := c.privs + privs }

/-- Item 3: the layout's plane offsets and rows. -/
def CSt.layout (c : CSt) (w : List String) : CSt :=
  let cfg := DefR13.cfgRungR13
  match w with
  | ["ROWS", l] =>
    let lean := DefW16.allDoms.map (fun d => toString (DefW16.rowsOf cfg d))
    let code := ((parseCsvNat l).getD []).map toString
    { c with st := c.st.cmp "rows-of" "ROWS" lean code }
  | ["AOFF", l] =>
    let nA := DefR13.domEnd cfg .Tab
    let lean := (List.range nA).map (fun q => toString (DefR13.aOff cfg q))
    let code := ((parseCsvNat l).getD []).map toString
    { c with st := c.st.cmp "a-off" "AOFF" lean code }
  | ["HOFF", l] =>
    let nH := (DefR13.hDoms cfg).length
    let lean := (List.range nH).flatMap (fun h => [toString (DefR13.hOff cfg h).1, toString (DefR13.hOff cfg h).2])
    let code := ((parseCsvNat l).getD []).map toString
    { c with st := c.st.cmp "h-off" "HOFF" lean code }
  | _ => { c with st := c.st.check "PARSE" false (" ".intercalate w) }

def CSt.step (c : CSt) (line : String) : CSt :=
  let w := (line.splitOn " ").filter (· ≠ "")
  let bad := fun (c : CSt) => { c with st := c.st.check "PARSE" false (line.take 200).toString }
  match w with
  | ["L44", _, ns, na, nh, lc, el] =>
    let cfg := DefR13.cfgRungR13
    let st := c.st.eqS "header" "slot count" (toString ZK60.Exec.Slot.W16R2.nSlots) ns
    let st := st.eqS "header" "A planes" (toString (DefR13.domEnd cfg .Tab)) na
    let st := st.eqS "header" "H planes" (toString (DefR13.hDoms cfg).length) nh
    let st := st.eqS "header" "row log" (toString cfg.logCols) lc
    { c with st := st, eLog := el.toNat?.getD 0 }
  | "ROWS" :: _ | "AOFF" :: _ | "HOFF" :: _ => c.layout w
  | ["IO", i, o] =>
    let io := (i.toNat?.getD 0, o.toNat?.getD 0)
    { c with io := io, prog := DefR13.progR13 DefR13.cfgRungR13 io.1 io.2 }
  | ["LOGUP", b, g, a] =>
    match pF2 b, pF2 g, pF2 a with
    | some b, some g, some a => { c with logup := some (b, g, a) }
    | _, _, _ => bad c
  | ["SLOT", s, n, e, nt] =>
    { c with cur := { s := s.toNat?.getD 0, n := n.toNat?.getD 0, ext := e.toNat?.getD 0, nTabs := nt.toNat?.getD 0 } }
  | ["DRAWS", l] =>
    match pF2s l with
    | some v => { c with cur := { c.cur with draws := v } }
    | none => bad c
  | ["TERMS", l] =>
    match pF2s l with
    | some v => { c with cur := { c.cur with terms := v } }
    | none => bad c
  | ["RHO", r, e] =>
    match pF2s r, pF2s e with
    | some r, some e => { c with cur := { c.cur with rho := r, es := e } }
    | _, _ => bad c
  | ["EQ", i, st, pt] => { c with cur := { c.cur with tabs := c.cur.tabs ++ [.eq (i.toNat?.getD 0) st pt] } }
  | "PUB" :: i :: len :: _ =>
    { c with cur := { c.cur with tabs := c.cur.tabs ++ [.pub (i.toNat?.getD 0) (len.toNat?.getD 0)] } }
  | ["PRIV", i, cm, lg, row, ext, sl, co] =>
    { c with cur := { c.cur with tabs := c.cur.tabs ++ [.priv (i.toNat?.getD 0) cm lg row ext sl co] } }
  | ["CLAIM", i, cm, v, parts] =>
    { c with cur := { c.cur with claims := c.cur.claims ++ [(i.toNat?.getD 0, cm, v, parts)] } }
  | ["END", _] => c.endSlot
  | ["DONE", ns, np, _, _, _] =>
    let st := c.st.eqS "slot-count" "DONE" (toString c.slots) ns
    { c with st := st.eqS "priv-count" "DONE" (toString c.privs) np }
  | _ => bad c

def run (lines : List String) : St :=
  let c : CSt := {}
  (lines.foldl (fun c l => if l.startsWith "#" || l.all Char.isWhitespace then c else c.step l) c).st

/-! ## The negative controls -/

/-- Replace field `j` (space-separated) of the first line starting with `pre` (and whose second field is `f1`, unless
`f1` is empty) by `f` of it. -/
def mutate (lines : List String) (pre f1 : String) (j : ℕ) (f : String → String) : Option (List String) :=
  let hit := fun (l : String) =>
    l.startsWith pre && (f1.isEmpty || ((l.splitOn " ").getD 1 "") == f1)
  match lines.findIdx? hit with
  | none => none
  | some i =>
    let w := (lines.getD i "").splitOn " "
    let w' := w.set j (f (w.getD j ""))
    some (lines.set i (" ".intercalate w'))

def incN (s : String) : String := toString (s.toNat?.getD 0 + 1)

/-- Change the first number of a `;`/`,`/`:`-separated field. -/
def incFirst (s : String) : String :=
  let digits := s.toList.takeWhile Char.isDigit
  toString ((String.ofList digits).toNat?.getD 0 + 1) ++ String.ofList (s.toList.dropWhile Char.isDigit)

/-- Change the second entry of a comma list (`r1` to `r2`, a number to its successor). -/
def incSecondCoord (s : String) : String :=
  match s.splitOn "," with
  | a :: b :: rest =>
    let b' := if b.startsWith "r" then "r" ++ incN (b.drop 1).toString else if b.startsWith "x" then "x" ++ incFirst (b.drop 1).toString
      else incFirst b
    ",".intercalate (a :: b' :: rest)
  | l => ",".intercalate l

def negControls : List (String × String × String × ℕ × (String → String)) :=
  [("slice offset", "PRIV", "", 6, incFirst),
   ("log size", "PRIV", "", 3, incN),
   ("coordinate", "PRIV", "", 7, incSecondCoord),
   ("mask row", "PRIV", "", 4, fun s => toString (s.toNat?.getD 0 + 2)),
   ("extension round", "PRIV", "", 5, incN),
   ("public length", "PUB", "", 2, fun s => toString (2 * s.toNat?.getD 0)),
   ("a_off", "AOFF", "", 1, incSecondCoord),
   ("h_off", "HOFF", "", 1, incSecondCoord),
   ("rows_of", "ROWS", "", 1, incSecondCoord),
   ("claim part offset", "CLAIM", "", 4, incFirst),
   ("claim value", "CLAIM", "", 3, incFirst),
   ("eq point", "EQ", "", 3, incFirst),
   ("the first private table 5's log size", "PRIV", "5", 3, incN),
   ("table 26's slice", "PRIV", "26", 6, incFirst)]

end ZK60.Exec.L44R13Exp

open ZK60.Exec.L44R13Exp in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l44_20261110/l44_r13_corpus.txt"
  let lines := (← IO.FS.lines path).toList
  let fin := run lines
  for (k, n) in fin.kinds do
    IO.println s!"  {k}: {n}"
  for m in fin.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"BlockR13ProgExportCheck: {fin.ok + fin.fail} checks, {fin.fail} failed"
  let mut rc : UInt32 := if fin.fail = 0 then 0 else 1
  if args.getD 1 "" == "neg" then
    let mut caught := 0
    let mut total := 0
    for (name, pre, f1, j, f) in negControls do
      total := total + 1
      match mutate lines pre f1 j f with
      | none =>
        IO.println s!"NEG {name}: no line to change"
      | some ls =>
        let r := run ls
        if r.fail > 0 then
          caught := caught + 1
          IO.println s!"NEG {name}: caught ({r.fail} failed: {(r.msgs.toList.headD "").take 160})"
        else
          IO.println s!"NEG {name}: NOT caught"
    IO.println s!"BlockR13ProgExportCheck negative controls: {caught} of {total} caught"
    if caught ≠ total then rc := 1
  return rc
