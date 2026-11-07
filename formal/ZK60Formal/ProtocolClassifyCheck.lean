/-
D63 lane L18 (2026-11-07): **the agreement check of the classify run's FRAMING** (`ProtocolClassify.lean`) against a
REAL classifier receipt.

Run (through the zk60 resource guard; `results/zk60_lean_l18_20261107/check_l18.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/ProtocolClassifyCheck.lean results/zk60_lean_l18_20261107/corpus.txt

The corpus is written by `hashline/src/lean_l18_export_tests.rs` (test only): an honest classifier run on the
development rung (two blocks), accepted by the production `verify_classify_run`, and `verify_classify_run_with`'s loop
replayed beside it with the production pieces (every segment's start tag compared by its decoder, every end tag
asserted equal to the replay's own position tag). With the Lean definitions the theorems are about (L9's `posTag`, this
lane's `blockFrame`, the labels), this file checks:
* `LABELS`: `labRunStage`, `labRunBlock`, `labB` are `ascii` of `"pb-run-stage"`, `"pb-run-block"`, `"B"`;
* `SHAPE`: the run has `L + 2` segments, in the order stage IN-C, `L` blocks, stage OUT-C (`RunV.parts`);
* `BINDING`, `START`: the binding is the run header's state, and segment 0 starts from the run header's transcript;
* `TAG-START`, `TAG-END` (per segment): Lean's `posTag` (BLAKE3 in Lean) of the recorded transcript before the part is
  the start tag the code computed, and after the part the end tag the segment carries (`segStep`);
* `CONTINUITY` (per boundary): each segment starts from the transcript the previous one ended on (`runSegs`);
* `FRAME` (per block): Lean's `blockFrame` (the `pb-run-stage` and `pb-run-block` absorbs and `absorb_root("B")`) of the
  block's start transcript, with the block's digest and boundary root, is the code's transcript before `verify_core`;
* `CARRY`: each block opens the previous boundary's root with the claims the previous segment left pending, and hands
  on its own root and outgoing claims; stage OUT-C opens the last boundary with the last block's claims (`Carry`).
It prints the checks per kind and `N checks, F failed`, and exits nonzero on any failure. Not imported by the library
root (it defines `main`).
-/
import ZK60Formal.ProtocolClassify

namespace ZK60.ProtocolClassify.Check

open ZK60.Exec ZK60.ProtocolClassify
open ZK60.Exec.Block (posTag)

/-! ## Parsing -/

def hexDigit (c : Char) : Option ℕ :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

def hexPairs : List Char → Option (List UInt8)
  | [] => some []
  | [_] => none
  | a :: b :: rest => do
    let x ← hexDigit a
    let y ← hexDigit b
    let r ← hexPairs rest
    pure (UInt8.ofNat (16 * x + y) :: r)

def parseDig (s : String) : Option Dig := hexPairs s.toList >>= digOf?

/-- One segment's record: index, kind, byte length, the transcript before the part, the start tag, the end tag, the
transcript after the part. -/
structure SegRec where
  j : ℕ
  kind : String
  len : ℕ
  s0 : Dig
  c0 : ℕ
  start : Dig
  fin : Dig
  s1 : Dig
  c1 : ℕ

/-- One block's framing record: the digest, the boundary root, its rows and log size, the transcript after. -/
structure FrameRec where
  k : ℕ
  digest : Dig
  root : Dig
  rows : ℕ
  logn : ℕ
  s : Dig
  c : ℕ

structure CarryRec where
  j : ℕ
  kv : List (String × String)

def CarryRec.get (c : CarryRec) (k : String) : Option String := (c.kv.find? (·.1 == k)).map (·.2)

structure Corpus where
  L : Option ℕ := none
  nseg : Option ℕ := none
  key : Option (Option Dig) := none
  header : Option (Dig × ℕ) := none
  binding : Option Dig := none
  segs : List SegRec := []
  frames : List FrameRec := []
  carries : List CarryRec := []
  endN : Option ℕ := none
  bad : List String := []

def valOf (pre s : String) : Option ℕ := if s.startsWith pre then (s.drop pre.length).toNat? else none

def kvOf (s : String) : Option (String × String) :=
  match s.splitOn "=" with
  | [a, b] => some (a, b)
  | _ => none

def parseLine (c : Corpus) (line : String) : Corpus :=
  match line.splitOn " " with
  | ["L18", "FRAMING", _, l, n] => { c with L := valOf "L=" l, nseg := valOf "segments=" n }
  | ["KEY", "-"] => { c with key := some none }
  | ["KEY", k] => match parseDig k with
    | some d => { c with key := some (some d) }
    | none => { c with bad := c.bad ++ [line] }
  | ["HEADER", s, n] => match parseDig s, n.toNat? with
    | some d, some m => { c with header := some (d, m) }
    | _, _ => { c with bad := c.bad ++ [line] }
  | ["BINDING", s] => match parseDig s with
    | some d => { c with binding := some d }
    | none => { c with bad := c.bad ++ [line] }
  | ["SEG", j, kind, len, s0, c0, st, fin, s1, c1] =>
    match j.toNat?, len.toNat?, parseDig s0, c0.toNat?, parseDig st, parseDig fin, parseDig s1, c1.toNat? with
    | some j, some len, some s0, some c0, some st, some fin, some s1, some c1 =>
      { c with segs := c.segs ++ [⟨j, kind, len, s0, c0, st, fin, s1, c1⟩] }
    | _, _, _, _, _, _, _, _ => { c with bad := c.bad ++ [line] }
  | ["FRAME", k, dg, rt, rows, logn, s, n] =>
    match k.toNat?, parseDig dg, parseDig rt, rows.toNat?, logn.toNat?, parseDig s, n.toNat? with
    | some k, some dg, some rt, some rows, some logn, some s, some n =>
      { c with frames := c.frames ++ [⟨k, dg, rt, rows, logn, s, n⟩] }
    | _, _, _, _, _, _, _ => { c with bad := c.bad ++ [line] }
  | "CARRY" :: j :: rest => match j.toNat?, rest.mapM kvOf with
    | some j, some kv => { c with carries := c.carries ++ [⟨j, kv⟩] }
    | _, _ => { c with bad := c.bad ++ [line] }
  | ["END", n] => { c with endN := n.toNat? }
  | _ => { c with bad := c.bad ++ [line] }

/-! ## The checks -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  kinds : List (String × ℕ) := []
  msgs : List String := []

def St.bump (kinds : List (String × ℕ)) (k : String) : List (String × ℕ) :=
  if kinds.any (·.1 == k) then kinds.map (fun p => if p.1 == k then (p.1, p.2 + 1) else p) else kinds ++ [(k, 1)]

def St.check (s : St) (kind : String) (b : Bool) (what : String) : St :=
  let s := { s with kinds := St.bump s.kinds kind }
  if b then { s with ok := s.ok + 1 } else { s with fail := s.fail + 1, msgs := s.msgs ++ [s!"{kind}: {what}"] }

/-- A recorded transcript, as Lean's `Tr`. -/
def mkTr (key : Option Dig) (st : Dig) (ctr : ℕ) : Tr := ⟨st, UInt64.ofNat ctr, key⟩

/-- A block profile that only answers `blockFrame`'s three questions with the recorded values. -/
def frameProf (dg : Dig) (rows logn : ℕ) : BlockProfV Unit where
  Seg := Unit
  check _ _ := .ok ()
  decode _ _ _ _ _ := .error "frame stub"
  paths _ _ := .ok ()
  bRoot _ := none
  digest _ _ := dg
  bRows _ := rows
  bLogN _ := logn
  core _ _ _ _ _ := .error "frame stub"
  bndCheck _ _ _ _ := .ok ()
  bndOpen _ _ _ _ _ _ _ := .error "frame stub"

def trEq (t : Tr) (s : Dig) (c : ℕ) : Bool := t.state == s && t.counter == UInt64.ofNat c

def runChecks (c : Corpus) : St := Id.run do
  let mut s : St := {}
  s := s.check "LABELS" (labRunStage == ascii "pb-run-stage") "pb-run-stage"
  s := s.check "LABELS" (labRunBlock == ascii "pb-run-block") "pb-run-block"
  s := s.check "LABELS" (labB == ascii "B") "B"
  s := s.check "PARSE" c.bad.isEmpty s!"unparsed lines: {c.bad}"
  let L := c.L.getD 0
  let key := c.key.getD none
  s := s.check "SHAPE" (c.nseg == some (L + 2) && c.segs.length == L + 2 && c.endN == some (L + 2))
    s!"segments {c.nseg} {c.segs.length} {c.endN}, L = {L}"
  s := s.check "SHAPE" (c.segs.map (·.kind) == ["IN-C"] ++ List.replicate L "BLOCK" ++ ["OUT-C"]
      && c.segs.map (·.j) == List.range (L + 2))
    "the kinds and order IN-C, BLOCK^L, OUT-C"
  match c.header, c.binding with
  | some (hs, hc), some b =>
    s := s.check "BINDING" (hs == b) "the binding is the run header's state"
    match c.segs.head? with
    | some g => s := s.check "START" (g.s0 == hs && g.c0 == hc) "segment 0 starts at the run header's transcript"
    | none => s := s.check "START" false "no segment"
  | _, _ => s := s.check "BINDING" false "no header or binding"
  for g in c.segs do
    s := s.check "TAG-START" (posTag blake3H (mkTr key g.s0 g.c0) == g.start) s!"segment {g.j}"
    s := s.check "TAG-END" (posTag blake3H (mkTr key g.s1 g.c1) == g.fin) s!"segment {g.j}"
  for (g, g') in c.segs.zip c.segs.tail do
    s := s.check "CONTINUITY" (g'.s0 == g.s1 && g'.c0 == g.c1 && g'.start == g.fin) s!"segments {g.j} -> {g'.j}"
  for fr in c.frames do
    match c.segs.find? (·.j == fr.k + 1) with
    | some g =>
      let t := blockFrame (frameProf fr.digest fr.rows fr.logn) blake3H () fr.k fr.root (mkTr key g.s0 g.c0)
      s := s.check "FRAME" (trEq t fr.s fr.c) s!"block {fr.k}"
    | none => s := s.check "FRAME" false s!"block {fr.k}: no segment"
  s := s.check "FRAME" (c.frames.map (·.k) == List.range L) "one framing record per block"
  -- the carry: block k opens the previous boundary with the previous segment's outgoing claims
  for j in List.range' 1 (L + 1) do
    match c.carries.find? (·.j == j - 1), c.carries.find? (·.j == j) with
    | some p, some q =>
      s := s.check "CARRY" (q.get "pending" == p.get "out" && q.get "pending" != none) s!"segment {j}: pending claims"
      s := s.check "CARRY" (q.get "opened" == p.get "root" && q.get "opened" != none) s!"segment {j}: the opened root"
      match c.frames.find? (·.k + 1 == j), q.get "root" with
      | some fr, some r => s := s.check "CARRY" (parseDig r == some fr.root) s!"segment {j}: the root handed on"
      | _, _ => s := s.check "CARRY" (j > L) s!"segment {j}: the root handed on"
    | _, _ => s := s.check "CARRY" false s!"segment {j}: no carry record"
  return s

end ZK60.ProtocolClassify.Check

open ZK60.ProtocolClassify.Check in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l18_20261107/corpus.txt"
  let lines ← IO.FS.lines path
  let c := lines.foldl (fun c l => if l.startsWith "#" || l.all Char.isWhitespace then c else parseLine c l) ({} : Corpus)
  let s := runChecks c
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"ProtocolClassifyCheck: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)
