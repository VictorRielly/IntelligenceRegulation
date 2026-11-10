/-
D63 Lean lane L51 (2026-11-10): **the classify run's header (`RunAbsHdr.lean`'s `clsHdrOps`), checked against the
code on a REAL classifier receipt, and where it absorbs the input root.**

Run (through the zk60 resource guard; `results/zk60_lean_l51_20261110/check_l51.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/RunAbsCheck.lean <l51_corpus.txt> <ops/zkp-mvp/gpu-metal>

The corpus comes from the TEST-ONLY hashline test `lean_l51_export_the_classify_header`
(`src/lean_l51_export_tests.rs`): an honest classifier run on the development rung (one block), accepted by the
production `verify_classify_run`; the run header rebuilt absorb by absorb from the statement's public words and
ASSERTED (in Rust) to end on the production header's state, the run binding. With the SAME definitions the theorems
are about (`clsHdrOps`, `abExpMsg`, `Tr.newKeyed`, `runOps`, `opTrace`, `Block.absAt`, `rootAt`, under BLAKE3 in Lean),
it checks:
* `CORPUS`: the export is L51's; eight header absorbs;
* `LABELS`: the model's labels are the source's strings' bytes, and the corpus's, in order;
* `MODEL`: the Lean header `clsHdrOps w r v`, built from the corpus's public words, the statement's input root and its
  verdict, IS the corpus's list of (label, data), and its `expected-IO` data is `abExpMsg` of the input endpoint spec's
  digest and the input root (84 bytes);
* `REPLAY`: from the keyed transcript of the run profile (`Tr.newKeyed blake3H domain key`, its state the corpus's
  fresh state), the Lean header lands on the run binding with no squeeze;
* `POS`: on the header's trace, position `1` absorbs `abExpMsg …` (`ab_inAbs`); NO header position absorbs the 32-byte
  input root (L48's `hInAbs` is false at every header position on this receipt); `rootAt` at position `1` is none
  (`ab_rootAt_none`); stage IN-C's 32-byte absorbs before its endpoint opening (its embedding digest, the `B_in`, `A`,
  `M`, `H` roots) are not the input root either;
* `FIX`: the repaired header (`clsHdrOpsFix`) absorbs the 32-byte root at position `2` and is ANOTHER binding (a
  protocol change);
* `SOURCE`: the production text: `ClassifyRunStatement::transcript`'s eight absorbs in this order, `expected_bytes`'
  three parts, the classify verifier handing `st.in_root()` to stage IN-C, and stage IN-C absorbing no endpoint root
  (its uses of `ep_root`: the parameter, the commitment the endpoint opening is checked against, a test-only capture
  hook).
It prints the checks per kind and `RunAbsCheck: N checks, F failed`, and exits nonzero on any failure. The negative
control (`results/zk60_lean_l51_20261110/l51_negative.py`) runs it on single-change copies of the corpus and the
sources and requires every copy to be refused. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.RunAbsHdr

namespace ZK60.ProtocolClassify.AbsCheck

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.ProtocolClassify

def hexDigit (c : Char) : Option ℕ :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else none

def hexPairs : List Char → Option (List UInt8)
  | [] => some []
  | [_] => none
  | a :: b :: rest => do
    let x ← hexDigit a
    let y ← hexDigit b
    let r ← hexPairs rest
    pure (UInt8.ofNat (16 * x + y) :: r)

def hexB (s : String) : Option (List UInt8) := hexPairs s.toList

def parseDig (s : String) : Option Dig := hexB s >>= digOf?

def hexOf (b : List UInt8) : String :=
  String.join (b.map fun x =>
    let d := "0123456789abcdef".toList
    String.ofList [d.getD (x.toNat / 16) '0', d.getD (x.toNat % 16) '0'])

def nat (s : String) : ℕ := s.toNat?.getD 0

structure St where
  n : ℕ := 0
  failed : ℕ := 0
  kinds : List (String × ℕ × ℕ) := []
  log : List String := []

def St.check (s : St) (kind : String) (ok : Bool) (what : String) : St :=
  let upd := fun (l : List (String × ℕ × ℕ)) =>
    if l.any (·.1 == kind) then l.map (fun e => if e.1 == kind then (e.1, e.2.1 + 1, e.2.2 + if ok then 0 else 1) else e)
    else l ++ [(kind, 1, if ok then 0 else 1)]
  { s with
    n := s.n + 1
    failed := s.failed + (if ok then 0 else 1)
    kinds := upd s.kinds
    log := s.log ++ [s!"{if ok then "ok  " else "FAIL"} {kind}: {what}"] }

def has (src key : String) : Bool := (src.splitOn key).length > 1

/-- The position of the first occurrence of `key` in `src` (its length if absent). -/
def posOf (src key : String) : ℕ := ((src.splitOn key).headD src).length

/-- The text of `src` from `start` to the first `stop` after it. -/
def between (src start stop : String) : String :=
  match src.splitOn start with
  | _ :: rest :: _ => (rest.splitOn stop).headD ""
  | _ => ""

def opPair : Op → List UInt8 × List UInt8
  | .absorb l x => (l, x)
  | .squeeze => ([], [])

def H : HIn → Dig := blake3H

def main (args : List String) : IO UInt32 := do
  let cpath := args.getD 0 "l51_corpus.txt"
  let root := args.getD 1 "ops/zkp-mvp/gpu-metal"
  let lines ← IO.FS.lines cpath
  let words : List (List String) := (lines.toList.filter (fun l => !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let recsOf (k : String) : List (List String) := words.filter (fun w => w.headD "" = k)
  let w (k : String) (i : ℕ) : String := (rec1 k).getD i ""
  let mut s : St := {}
  -- ================================================================ CORPUS
  s := s.check "CORPUS" ((rec1 "L51").getD 1 "" == "HEADER") s!"the corpus is L51's export ({w "L51" 2})"
  let hdrs := recsOf "HDR"
  s := s.check "CORPUS" (nat (w "HDRN" 1) == 8 && hdrs.length == 8) s!"{hdrs.length} header absorbs (HDRN {w "HDRN" 1})"
  let item (i : ℕ) : List UInt8 × List UInt8 :=
    match hdrs.find? (fun r => r.getD 1 "" == toString i) with
    | some r => ((hexB (r.getD 2 "")).getD [], (hexB (r.getD 3 "")).getD [])
    | none => ([], [])
  let some inRoot := parseDig (w "INROOT" 1) | do IO.println "FAILED parse INROOT"; return 1
  let some inDig := parseDig (w "INSPECDIG" 1) | do IO.println "FAILED parse INSPECDIG"; return 1
  let some bind := parseDig (w "BINDING" 1) | do IO.println "FAILED parse BINDING"; return 1
  let some fresh := parseDig (w "FRESH" 1) | do IO.println "FAILED parse FRESH"; return 1
  let some domain := hexB (w "DOMAIN" 1) | do IO.println "FAILED parse DOMAIN"; return 1
  let key : Option Dig := if w "KEY" 1 = "-" then none else parseDig (w "KEY" 1)
  s := s.check "CORPUS" (w "KEY" 1 == "-" || key.isSome) s!"the Fiat-Shamir key {w "KEY" 1}"
  let verdict := nat (w "VERDICT" 1)
  -- ================================================================ LABELS
  let labs : List (String × List UInt8) := [("run-shape", abLabShape), ("expected-IO", abLabExp),
    ("public-statement", abLabPub), ("parameters", abLabPar), ("calibration", abLabCal), ("schedule", abLabSch),
    ("classify-verdict", abLabVer), ("classify-chunk", abLabChk)]
  s := s.check "LABELS" (labs.all (fun p => ascii p.1 == p.2)) "the model's eight labels are the source strings' bytes"
  s := s.check "LABELS" (ascii "classify-expected/v1" == abExpTag && ascii "input-root" == abLabInRoot)
    "the expected-IO tag and the repair's label are the strings' bytes"
  s := s.check "LABELS" ((List.range 8).all (fun i => (item i).1 == (labs.getD i ("", [])).2))
    s!"the corpus's labels in order: {(List.range 8).map (fun i => String.ofList ((item i).1.map (fun b => Char.ofNat b.toNat)))}"
  -- ================================================================ MODEL
  let some pubSt := digOf? (item 2).2 | do IO.println "FAILED public-statement is not 32 bytes"; return 1
  let some calib := digOf? (item 4).2 | do IO.println "FAILED calibration is not 32 bytes"; return 1
  let some sched := digOf? (item 5).2 | do IO.println "FAILED schedule is not 32 bytes"; return 1
  let hw : ClsHdrW := ⟨(item 0).2, inDig, pubSt, (item 3).2, calib, sched, (item 7).2⟩
  let ops := clsHdrOps hw inRoot verdict
  s := s.check "MODEL" (ops.map opPair == (List.range 8).map item)
    "clsHdrOps (the statement's words, input root, verdict) is the corpus's eight (label, data)"
  s := s.check "MODEL" ((item 1).2 == abExpMsg inDig inRoot && (item 1).2.length == 84)
    s!"expected-IO's data is abExpMsg (in_spec digest, input root): {(item 1).2.length} bytes"
  s := s.check "MODEL" ((item 0).2.length == 88 && (item 7).2.length == 56 && (item 6).2 == [UInt8.ofNat verdict])
    s!"run-shape {(item 0).2.length} bytes (11 u64), chunk {(item 7).2.length} bytes (7 u64), verdict byte {verdict}"
  s := s.check "MODEL" (64 + (hw.shape.length + hw.params.length + hw.chunk.length + 84) ≤ 2 ^ 20)
    s!"clsHdrOps_fit's bound at Lq = 2^20: 64 + {hw.shape.length} + {hw.params.length} + {hw.chunk.length} + 84"
  -- ================================================================ REPLAY (BLAKE3 in Lean)
  let t0 := Tr.newKeyed H domain key
  s := s.check "REPLAY" (t0.state == fresh) "Tr.newKeyed (the run profile, the key) is the code's fresh transcript"
  let t8 := runOps H t0 ops
  s := s.check "REPLAY" (t8.state == bind && t8.counter.toNat == nat (w "BINDING" 2) && t8.counter.toNat == 0)
    s!"the Lean header lands on the run binding {hexOf bind.toList} (counter {t8.counter.toNat})"
  s := s.check "REPLAY" ((clsStart domain key (fun (_ : Unit) => hw) H ⟨(), inRoot, verdict⟩).state == bind)
    "clsStart (st.transcript() in Lean) is the binding"
  -- ================================================================ POS
  let tr := opTrace H t0 ops
  s := s.check "POS" (Block.absAt tr 1 == some (abExpMsg inDig inRoot)) "position 1 absorbs abExpMsg (ab_inAbs)"
  s := s.check "POS" ((List.range 8).all (fun i => Block.absAt tr i != some inRoot.toList))
    "no header position absorbs the 32-byte input root (L48's hInAbs false at 0..7 on this receipt)"
  s := s.check "POS" (rootAt tr 1 == none) "rootAt at position 1 is none (ab_rootAt_none)"
  s := s.check "POS" (Block.absAt tr 6 == some [UInt8.ofNat verdict]) "position 6 absorbs the verdict byte (ab_verdictAbs)"
  let inc32 : List (String × String) := [("embedding digest", w "INEMBDIG" 1), ("B_in root", w "INROOTS" 1),
    ("A root", w "INROOTS" 2), ("H root", w "INROOTS" 3), ("M root", w "INROOTS" 4)]
  s := s.check "POS" (inc32.all (fun p => (parseDig p.2).isSome && parseDig p.2 != some inRoot))
    "stage IN-C's 32-byte absorbs before the endpoint opening (embedding digest, B_in, A, H, M roots) are not the input root"
  -- ================================================================ FIX (the repair, finding L51-1)
  let fix := clsHdrOpsFix hw inRoot verdict
  let trF := opTrace H t0 fix
  s := s.check "FIX" (Block.absAt trF 2 == some inRoot.toList && rootAt trF 2 == some inRoot)
    "the repaired header absorbs the 32-byte input root at position 2 (ab_inAbs_fix)"
  s := s.check "FIX" ((runOps H t0 fix).state != bind) "the repaired header is another binding (a protocol change)"
  -- ================================================================ SOURCE (the production code's text)
  let cls ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/classify.rs")
  let crun ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/classify_run.rs")
  let sic ← IO.FS.readFile (root ++ "/hashline/src/private_block/token_io/stage_in_c.rs")
  let body := between cls "pub(crate) fn transcript(&self) -> Result<Transcript, String> {" "Ok(tr)"
  s := s.check "SOURCE" (body != "") "classify.rs: ClassifyRunStatement::transcript is found"
  let absorbs := ["tr.absorb(b\"run-shape\", &shape_bytes);", "tr.absorb(b\"expected-IO\", &self.expected_bytes());",
    "tr.absorb(b\"public-statement\", &self.public_statement());",
    "tr.absorb(b\"parameters\", self.parameter_line()?.as_bytes());",
    "tr.absorb(b\"calibration\", &self.calibration());", "tr.absorb(b\"schedule\", &self.schedule_digest()?);",
    "tr.absorb(b\"classify-verdict\", &[self.verdict]);", "tr.absorb(b\"classify-chunk\", &self.chunk.bytes());"]
  s := s.check "SOURCE" (absorbs.all (has body)) "transcript(): the eight absorbs"
  let ps := absorbs.map (posOf body)
  s := s.check "SOURCE" (ps.zip (ps.drop 1) |>.all (fun p => p.1 < p.2)) s!"transcript(): in this order (at {ps})"
  s := s.check "SOURCE" ((body.splitOn "absorb").length == 9 && !has body "challenge" && !has body "squeeze")
    "transcript(): exactly eight absorbs, no challenge"
  s := s.check "SOURCE" (has body "protocol::tagged_transcript(sh, self.rs.profile().as_bytes())")
    "transcript(): on the tagged transcript of the run profile"
  let eb := between cls "fn expected_bytes(&self) -> Vec<u8> {" "\n    }"
  s := s.check "SOURCE" (has eb "v.extend_from_slice(b\"classify-expected/v1\");" &&
      posOf eb "b\"classify-expected/v1\"" < posOf eb "v.extend_from_slice(&self.in_spec.digest());" &&
      posOf eb "v.extend_from_slice(&self.in_spec.digest());" < posOf eb "v.extend_from_slice(&self.in_root);" &&
      (eb.splitOn "extend_from_slice").length == 4)
    "expected_bytes(): the tag, the input endpoint spec's digest, the input root, nothing else"
  let vr := between crun "pub(crate) fn verify_classify_run_with(" "\n}\n"
  s := s.check "SOURCE" (has vr "    let mut tr = st.transcript()?;" &&
      has vr "&st.in_spec, &st.in_root(), &ntt, &mut tr, &tag)?;" &&
      posOf vr "    let mut tr = st.transcript()?;" < posOf vr "&st.in_spec, &st.in_root(), &ntt, &mut tr, &tag)?;")
    "classify_run.rs verify_classify_run_with: the run starts on st.transcript(), then hands st.in_root() to stage IN-C"
  let sv := between sic "pub(crate) fn verify(" "\n}\n"
  s := s.check "SOURCE" (sv != "" && (sv.splitOn "ep_root").length == 4 && has sv "    ep_root: &Digest," &&
      has sv "&protocol::commitment(*ep_root, ep_spec.commitment_rows(), cp.tier.ep_log_n)" &&
      has sv "    #[cfg(test)]\n    super::super::run_capture::pcs(capture_ep_geom(\"E-token-in\", ep_spec, *ep_root,")
    "stage_in_c.rs verify: ep_root is the parameter, the endpoint commitment's root, and a test-only capture hook (no absorb)"
  s := s.check "SOURCE" (!has sv "absorb_root(tr, b\"In\"" && !has sv "tr.absorb(b\"input" && !has sv "ep_root)")
    "stage_in_c.rs verify: no absorb of the input root"
  for l in s.log do
    IO.println l
  for (k, n, f) in s.kinds do
    IO.println s!"{k}: {n} checks, {f} failed"
  IO.println s!"RunAbsCheck: {s.n} checks, {s.failed} failed"
  return (if s.failed = 0 then 0 else 1)

end ZK60.ProtocolClassify.AbsCheck

def main (args : List String) : IO UInt32 := ZK60.ProtocolClassify.AbsCheck.main args
