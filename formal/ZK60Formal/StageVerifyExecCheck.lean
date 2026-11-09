/-
D63 Lean lane L29 (2026-11-07): **the agreement check of the executable stage IN-C and stage OUT-C verifiers against a
REAL classifier receipt.**

Run (through the zk60 resource guard; `results/zk60_lean_l29_20261107/check_l29.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/StageVerifyExecCheck.lean <corpus.txt> [<seg_in.bin> <seg_out.bin>]

The corpus and the two segments come from the TEST-ONLY hashline test `lean_l29_export_the_classify_stages`
(`src/lean_l29_export_tests.rs`): an honest classifier run on the development rung (one block), accepted by the
production `verify_classify_run`; stage IN-C's and stage OUT-C's verifiers replayed with the production pieces on the
run's transcript (each replay asserted to end on the production verifier's transcript). With the SAME definitions the
theorems are about (`IncV.verify`, `OutcV.verify`, the slot loop `stSlotsLoop` / L15's `stageSlots`, the executable
`define`s, `decodeStage` / `encStage`, the transcript under BLAKE3), it checks, per stage:
* `LABELS`, `DERIV`: the magics; Lean's layout numbers (domain logs, rows, `M` rows, functional count) are the code's;
* `HEAD`: from the recorded start transcript, Lean's frame, roots and challenges land on the code's transcript after
  `absorb_root("H")`, with the code's challenges;
* `SLOT`: slot by slot, L9's `slotStep` with Lean's executable `define` (at the slot's IO row width) accepts the
  recorded slot proof and lands on the code's transcript; the whole slot phase (`IncV.slots`, `stageSlots`) too;
* `CLAIMS`, `FUNS`: every claim the slots leave per commitment and every `M` functional are the code's, value for value;
* `AUDIT`: L10's `check_opening` of `A` and `H`, `check_token_endpoint_opening` (IN-C), `boundary::check_opening`
  (OUT-C) accept at the code's transcripts; `RESULT`: the pending claims' count and `B_in`'s root;
* with the segments' bytes: `DECODE` (`decodeStage` accepts, the end tag, the roots and slots are the corpus's, the
  re-encoding is the bytes, BLAKE3 of the bytes), `VERIFY` (the FULL executable verifier, with L10's executable `M`
  and openings at the tier's parameters, accepts and lands on the code's final transcript; the end tag is its position
  tag);
* `NEGATIVE`: single changes (a slot scalar; a pending claim's value; one byte of a segment) are refused.
It prints the checks per kind and `StageVerifyExecCheck: N checks, F failed`, and exits nonzero on any failure. Not
imported by the library root (it defines `main`).
-/
import ZK60Formal.StageVerifyExec

namespace ZK60.Exec.StageV.Check

open ZK60.Exec ZK60.Exec.StageV
open ZK60.Exec.Block (Core SlotProof Dim SlotRec Acc slotStep histOf posTag)

/-! ## Parsing -/

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

def parseDig (s : String) : Option Dig := hexPairs s.toList >>= digOf?

def hexOf (b : List UInt8) : String :=
  String.join (b.map fun x =>
    let d := "0123456789abcdef".toList
    String.ofList [d.getD (x.toNat / 16) '0', d.getD (x.toNat % 16) '0'])

def nat (s : String) : ℕ := s.toNat?.getD 0

def int (s : String) : ℤ := if s.startsWith "-" then -((s.drop 1).toString.toNat?.getD 0 : ℤ) else (s.toNat?.getD 0 : ℤ)

def pF2 (s : String) : Option Fp2 :=
  match s.splitOn ":" with
  | [a, b] => do pure ⟨⟨UInt64.ofNat (← a.toNat?)⟩, ⟨UInt64.ofNat (← b.toNat?)⟩⟩
  | _ => none

def pF2s (s : String) : Option (List Fp2) := if s = "-" then some [] else (s.splitOn ",").mapM pF2

def pPart (s : String) : Option Block.ZPart :=
  match s.splitOn "/" with
  | [o, l, c, p] => do pure ⟨← o.toNat?, ← l.toNat?, ← pF2 c, ← pF2s p⟩
  | _ => none

/-- A claim `value parts` (parts `offset/log/coef/point;…`). -/
def pClaim (v ps : String) : Option Block.ZClaim := do
  let value ← pF2 v
  let parts ← if ps = "-" then some [] else (ps.splitOn ";").mapM pPart
  pure ⟨parts, value⟩

def pSlot (sc rs ts : String) : Option SlotProof := do
  let scalar ← pF2 sc
  let rounds ← if rs = "-" then some [] else (rs.splitOn ";").mapM pF2s
  let terms ← pF2s ts
  pure ⟨scalar, rounds, terms⟩

/-! ## Printing as the export prints -/

def f2s (x : Fp2) : String := s!"{x.c0.v.toNat}:{x.c1.v.toNat}"
def f2ss (v : List Fp2) : String := if v.isEmpty then "-" else ",".intercalate (v.map f2s)
def claimStr (c : Block.ZClaim) : String :=
  let parts := c.parts.map (fun p => s!"{p.offset}/{p.logSize}/{f2s p.coef}/{f2ss p.point}")
  s!"{f2s c.value} {if parts.isEmpty then "-" else ";".intercalate parts}"
def funStr (f : Block.MaskFunctional) : String :=
  let terms := f.terms.map (fun st => s!"{st.1}/{f2ss st.2}")
  s!"{f2s f.value} {if terms.isEmpty then "-" else ";".intercalate terms}"
def trStr (t : Tr) : String := s!"{hexOf t.state.toList} {t.counter.toNat}"
def claimsAll (c : Block.Claims4) : List (ℕ × Block.ZClaim) :=
  c.a.map (0, ·) ++ c.h.map (1, ·) ++ c.inp.map (2, ·) ++ c.out.map (3, ·)

/-! ## The tally -/

structure St where
  n : ℕ := 0
  failed : ℕ := 0
  kinds : List (String × ℕ × ℕ) := []
  log : List String := []

def St.check (s : St) (kind : String) (ok : Bool) (what : String) : St :=
  let upd := fun (l : List (String × ℕ × ℕ)) =>
    if l.any (·.1 == kind) then l.map (fun e => if e.1 == kind then (e.1, e.2.1 + 1, e.2.2 + if ok then 0 else 1) else e)
    else l ++ [(kind, 1, if ok then 0 else 1)]
  { s with n := s.n + 1, failed := s.failed + (if ok then 0 else 1), kinds := upd s.kinds,
    log := s.log ++ [s!"{if ok then "ok  " else "FAIL"} {kind}: {what}"] }

def okE {ε α : Type} : Except ε α → Bool
  | .ok _ => true
  | .error _ => false

def errOf {α : Type} : Except String α → String
  | .ok _ => "accepted"
  | .error e => e

def H : HIn → Dig := blake3H

/-- Replay a stage's slots one by one (the recursion of `stSlotsLoop`), recording the transcript after each. -/
def slotWalk (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    List SlotRec → ℕ → List SlotProof → Acc → Tr → List Tr → Except String (List SlotRec × Acc × Tr × List Tr)
  | recs, _, [], acc, t, ts => .ok (recs, acc, t, ts)
  | recs, s, sp :: sps, acc, t, ts =>
    match slotStep H (atLog P (elog s)) s (histOf b g a recs) sp acc t with
    | .error e => .error s!"slot {s}: {e}"
    | .ok (r, acc', t') => slotWalk P elog b g a (recs ++ [r]) (s + 1) sps acc' t' (ts ++ [t'])

def main (args : List String) : IO UInt32 := do
  let cpath := args.headD "corpus.txt"
  let lines ← IO.FS.lines cpath
  let words : List (List String) := (lines.toList.filter (fun l => !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let recsOf (k : String) : List (List String) := words.filter (fun w => w.headD "" = k)
  let w (k : String) (i : ℕ) : String := (rec1 k).getD i ""
  let trOf (st ctr : String) (key : Option Dig) : Tr := ⟨(parseDig st).getD zeroDig, UInt64.ofNat (nat ctr), key⟩
  let keyS := w "KEY" 1
  let key : Option Dig := if keyS = "-" then none else parseDig keyS
  let tagK (i : ℕ) : Option Dig := if w "MTAG" i = "-" then none else parseDig (w "MTAG" i)
  let mtag : MTag := ⟨tagK 1, tagK 2, tagK 3⟩
  let some bindg := parseDig (w "BINDING" 1) | do IO.println "FAILED parse BINDING"; return 1
  let mut s : St := {}
  s := s.check "LABELS" (ascii "HLPCLIN1" == magicIn) "HLPCLIN1"
  s := s.check "LABELS" (ascii "HLPCLOT1" == magicOut) "HLPCLOT1"
  s := s.check "LABELS" (ascii "pb-run-stage" == ProtocolClassify.labRunStage && ascii "pb-run-block" ==
    ProtocolClassify.labRunBlock && ascii "B" == ProtocolClassify.labB) "the run labels"
  -- ======================================================== stage IN-C
  let tmpl := (w "INTMPL" 1).toList
  let kap : List ℕ := ((w "INKAPPA" 1).splitOn ",").map nat
  let some ch0 := pF2s ((rec1 "INHEAD").getD 3 "") | do IO.println "FAILED parse INHEAD"; return 1
  let some ef := pF2s (w "INEF" 1) | do IO.println "FAILED parse INEF"; return 1
  let some embDig := parseDig (w "INEMBDIG" 1) | do IO.println "FAILED parse INEMBDIG"; return 1
  let rEmbRec := ch0.drop 3
  let pub : IncPub := ⟨nat (w "INP" 1), nat (w "INP" 2), nat (w "INP" 3), nat (w "INP" 4), nat (w "INP" 5),
    nat (w "INP" 6), fun t => tmpl.getD t '0' == '1', fun t => kap.getD t 0, nat (w "INP" 7), nat (w "INP" 8), embDig,
    fun r => if r == rEmbRec then ef else []⟩
  let geo : IncGeo := ⟨nat (w "INGEO" 1), nat (w "INGEO" 2), nat (w "INGEO" 3), nat (w "INGEO" 4), nat (w "INGEO" 5)⟩
  let blk : Dim := ⟨nat (w "INDIM" 1), nat (w "INDIM" 2), nat (w "INDIM" 3), nat (w "INDIM" 4)⟩
  let ed : Dim := ⟨nat (w "INDIM" 5), nat (w "INDIM" 6), nat (w "INDIM" 7), nat (w "INDIM" 8)⟩
  let V := incVAt mtag pub geo blk ed (nat (w "INPCS" 1)) (nat (w "INPCS" 2)) (nat (w "INPCS" 3)) (nat (w "INPCS" 4))
  let L := V.lay
  s := s.check "DERIV" (pub.tiLog == nat (w "INDERIV" 1) && pub.vocLog == nat (w "INDERIV" 2)
    && pub.inEpWords == nat (w "INDERIV" 3) && pub.bInLog == nat (w "INDERIV" 4))
    s!"IN-C domains: ti {pub.tiLog} voc {pub.vocLog} words {pub.inEpWords} B_in {pub.bInLog}"
  s := s.check "DERIV" (L.aRows == nat (w "INDERIV" 5) && L.hRows == nat (w "INDERIV" 6) && L.mRows == nat (w "INDERIV" 7)
    && L.nFunctionals == nat (w "INDERIV" 8))
    s!"IN-C layout: A rows {L.aRows} H rows {L.hRows} M rows {L.mRows} functionals {L.nFunctionals}"
  let t0 := trOf (w "INSTART" 1) (w "INSTART" 2) key
  let some bRoot := parseDig (w "INROOTS" 1) | do IO.println "FAILED parse INROOTS"; return 1
  let some aRoot := parseDig (w "INROOTS" 2) | do IO.println "FAILED parse INROOTS"; return 1
  let some hRoot := parseDig (w "INROOTS" 3) | do IO.println "FAILED parse INROOTS"; return 1
  let some mRoot := parseDig (w "INROOTS" 4) | do IO.println "FAILED parse INROOTS"; return 1
  let slotsIn : List SlotProof := (recsOf "INSLOT").filterMap (fun x => pSlot (x.getD 2 "") (x.getD 3 "") (x.getD 4 ""))
  s := s.check "PARSE" (slotsIn.length == 4) s!"{slotsIn.length} IN-C slot proofs"
  let coreIn : Core := ⟨aRoot, hRoot, mRoot, slotsIn, ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩
  let t1 := V.frame H bRoot t0
  let hc := V.headCh H coreIn t1
  s := s.check "HEAD" (hc.1 == ch0) s!"IN-C's head challenges (β, γ, α, r_emb: {hc.1.length})"
  s := s.check "HEAD" (trStr (V.slotT H coreIn t1) == s!"{w "INHEAD" 1} {w "INHEAD" 2}") "IN-C's transcript after H"
  let cx := incCtx pub hc.1
  s := s.check "HEAD" (cx.tauTab.length == 2 ^ pub.vocLog) s!"τ table of {cx.tauTab.length} rows"
  let after := recsOf "INAFTER"
  match slotWalk (V.bp cx) (incElog pub geo.bLogN) Fp2.zero Fp2.zero Fp2.zero [] 0 slotsIn {} (V.slotT H coreIn t1) [] with
  | .error e => s := s.check "SLOT" false s!"IN-C slot walk refused: {e}"
  | .ok (_, acc, t4, ts) =>
    for i in List.range 4 do
      let rec := after.getD i []
      s := s.check "SLOT" ((ts.getD i t0 |> trStr) == s!"{rec.getD 2 ""} {rec.getD 3 ""}") s!"IN-C slot {i}'s transcript"
    s := s.check "SLOT" (match V.slots H coreIn t1 with
      | .ok r => trStr r.2.2 == trStr t4 && (claimsAll r.2.1.claims).map (fun c => claimStr c.2)
          == (claimsAll acc.claims).map (fun c => claimStr c.2)
      | .error _ => false) "IN-C's slot phase (IncV.slots) is the slot walk"
    let claimsRec := (recsOf "INCLAIM").map (fun x => s!"{x.getD 1 ""} {x.getD 2 ""} {x.getD 3 ""}")
    let claimsLean := (claimsAll acc.claims).map (fun c => s!"{c.1} {claimStr c.2}")
    s := s.check "CLAIMS" (claimsRec.length == claimsLean.length) s!"IN-C: {claimsLean.length} claims (A, H, In, Out)"
    for i in List.range claimsRec.length do
      s := s.check "CLAIMS" (claimsRec.getD i "" == claimsLean.getD i "") s!"IN-C claim {i}"
    let funsRec := (recsOf "INFUN").map (fun x => s!"{x.getD 1 ""} {x.getD 2 ""}")
    let funsLean := (acc.fs ++ acc.hostFs).map funStr
    s := s.check "FUNS" (funsRec.length == funsLean.length && funsLean.length == L.nFunctionals)
      s!"IN-C: {funsLean.length} functionals"
    for i in List.range funsRec.length do
      s := s.check "FUNS" (funsRec.getD i "" == funsLean.getD i "") s!"IN-C functional {i}"
    let ph (k : String) : Tr :=
      let x := (recsOf "INPHASE").find? (fun x => x.getD 1 "" = k)
      trOf ((x.getD []).getD 2 "") ((x.getD []).getD 3 "") key
    s := s.check "AUDIT" (okE (V.checkOpening H .a acc.claims.a (ph "m"))) s!"IN-C check_opening A: {errOf (V.checkOpening H .a acc.claims.a (ph "m"))}"
    s := s.check "AUDIT" (okE (V.checkOpening H .h (acc.claims.h ++ [L.logupSumClaim]) (ph "a")))
      s!"IN-C check_opening H: {errOf (V.checkOpening H .h (acc.claims.h ++ [L.logupSumClaim]) (ph "a"))}"
    s := s.check "AUDIT" (okE (checkTokenEp H acc.claims.inp geo.epDataRows pub.epN (ph "h")))
      s!"IN-C check_token_endpoint_opening: {errOf (checkTokenEp H acc.claims.inp geo.epDataRows pub.epN (ph "h"))}"
    s := s.check "RESULT" (acc.claims.out.length == nat (w "INRESULT" 1) && hexOf bRoot.toList == w "INRESULT" 2)
      s!"IN-C leaves {acc.claims.out.length} claims on B_in"
  -- negative: slot 0's scalar changed
  let badSlots := slotsIn.set 0 { (slotsIn.getD 0 ⟨Fp2.zero, [], []⟩) with scalar := (slotsIn.getD 0 ⟨Fp2.zero, [], []⟩).scalar.add Fp2.one }
  s := s.check "NEGATIVE" (!okE (V.slots H { coreIn with slots := badSlots } t1)) "IN-C slot 0's scalar + 1 is refused"
  -- ======================================================== stage OUT-C
  let some wdig := parseDig (w "OUTWDIG" 1) | do IO.println "FAILED parse OUTWDIG"; return 1
  let wd : List ℤ := ((w "OUTWD" 1).splitOn ",").map int
  let opub : OutcPub := ⟨nat (w "OUTP" 1), nat (w "OUTP" 2), nat (w "OUTP" 3), nat (w "OUTP" 4), nat (w "OUTP" 5),
    int (w "OUTP" 6), int (w "OUTP" 7), int (w "OUTP" 8), int (w "OUTP" 9), nat (w "OUTP" 10), wd, wdig,
    nat (w "OUTP" 11), nat (w "OUTP" 12)⟩
  let ogeo : OutcGeo := ⟨nat (w "OUTGEO" 1), nat (w "OUTGEO" 2), nat (w "OUTGEO" 3), nat (w "OUTGEO" 4), nat (w "OUTGEO" 5)⟩
  let oblk : Dim := ⟨nat (w "OUTDIM" 1), nat (w "OUTDIM" 2), nat (w "OUTDIM" 3), nat (w "OUTDIM" 4)⟩
  let obd : Dim := ⟨nat (w "OUTDIM" 5), nat (w "OUTDIM" 6), nat (w "OUTDIM" 7), nat (w "OUTDIM" 8)⟩
  let OV := outcVAt mtag opub ogeo oblk obd (nat (w "OUTPCS" 5)) (nat (w "OUTPCS" 1)) (nat (w "OUTPCS" 2))
    (nat (w "OUTPCS" 3)) (nat (w "OUTPCS" 4))
  let OL := OV.lay
  s := s.check "DERIV" (opub.llo == nat (w "OUTDERIV" 1) && opub.ldo == nat (w "OUTDERIV" 2)
    && opub.ltab == nat (w "OUTDERIV" 3) && opub.bOutLog == nat (w "OUTDERIV" 4))
    s!"OUT-C domains: lo {opub.llo} do {opub.ldo} tab {opub.ltab} B_out {opub.bOutLog}"
  s := s.check "DERIV" (OL.aRows == nat (w "OUTDERIV" 5) && OL.hRows == nat (w "OUTDERIV" 6) && OL.mRows == nat (w "OUTDERIV" 7)
    && OL.nFunctionals == nat (w "OUTDERIV" 8) && OL.aOff ocC_LIMB == nat (w "OUTDERIV" 9))
    s!"OUT-C layout: A rows {OL.aRows} H rows {OL.hRows} M rows {OL.mRows} functionals {OL.nFunctionals}"
  let ot0 := trOf (w "OUTSTART" 1) (w "OUTSTART" 2) key
  let some obRoot := parseDig (w "OUTBROOT" 1) | do IO.println "FAILED parse OUTBROOT"; return 1
  let some oaRoot := parseDig (w "OUTROOTS" 2) | do IO.println "FAILED parse OUTROOTS"; return 1
  let some ohRoot := parseDig (w "OUTROOTS" 3) | do IO.println "FAILED parse OUTROOTS"; return 1
  let some omRoot := parseDig (w "OUTROOTS" 4) | do IO.println "FAILED parse OUTROOTS"; return 1
  let pending : List Block.ZClaim := (recsOf "OUTPEND").filterMap (fun x => pClaim (x.getD 1 "") (x.getD 2 ""))
  s := s.check "PARSE" (pending.length == (recsOf "OUTPEND").length) s!"{pending.length} claims pending on B_out"
  let slotsOut : List SlotProof := (recsOf "OUTSLOT").filterMap (fun x => pSlot (x.getD 2 "") (x.getD 3 "") (x.getD 4 ""))
  s := s.check "PARSE" (slotsOut.length == 8) s!"{slotsOut.length} OUT-C slot proofs"
  let coreOut : Core := ⟨oaRoot, ohRoot, omRoot, slotsOut, ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩
  let ot1 := OV.frame H ot0
  let some och := pF2s ((rec1 "OUTHEAD").getD 3 "") | do IO.println "FAILED parse OUTHEAD"; return 1
  let oT2 := (Block.absorbRoot H ot1 Block.labA oaRoot OV.bp.aRows OV.bp.logCols).absorb H Block.labM omRoot.toList
  let oCh := oT2.challengeFp2Vec H 2
  let oT3 := Block.absorbRoot H oCh.2 Block.labH ohRoot OV.bp.hRows OV.bp.logCols
  s := s.check "HEAD" (oCh.1 == och) "OUT-C's head challenges (γ, α)"
  s := s.check "HEAD" (trStr oT3 == s!"{w "OUTHEAD" 1} {w "OUTHEAD" 2}") "OUT-C's transcript after H"
  let oafter := recsOf "OUTAFTER"
  match slotWalk OV.bp (fun _ => ogeo.bLogN) (OutcV.bga oCh.1).1 (OutcV.bga oCh.1).2.1 (OutcV.bga oCh.1).2.2 [] 0 slotsOut {}
      oT3 [] with
  | .error e => s := s.check "SLOT" false s!"OUT-C slot walk refused: {e}"
  | .ok (_, acc, t4, ts) =>
    for i in List.range 8 do
      let rec := oafter.getD i []
      s := s.check "SLOT" ((ts.getD i ot0 |> trStr) == s!"{rec.getD 2 ""} {rec.getD 3 ""}") s!"OUT-C slot {i}'s transcript"
    s := s.check "SLOT" (match StageFS.stageSlots H OV.bp 2 OutcV.bga coreOut ot1 with
      | .ok r => trStr r.2.2.2 == trStr t4 && r.1 == oCh.1
      | .error _ => false) "OUT-C's slot phase (L15's stageSlots) is the slot walk"
    let claimsRec := (recsOf "OUTCLAIM").map (fun x => s!"{x.getD 1 ""} {x.getD 2 ""} {x.getD 3 ""}")
    let claimsLean := (claimsAll acc.claims).map (fun c => s!"{c.1} {claimStr c.2}")
    s := s.check "CLAIMS" (claimsRec.length == claimsLean.length) s!"OUT-C: {claimsLean.length} claims (A, H, In, Out)"
    for i in List.range claimsRec.length do
      s := s.check "CLAIMS" (claimsRec.getD i "" == claimsLean.getD i "") s!"OUT-C claim {i}"
    let funsRec := (recsOf "OUTFUN").map (fun x => s!"{x.getD 1 ""} {x.getD 2 ""}")
    let funsLean := (acc.fs ++ acc.hostFs).map funStr
    s := s.check "FUNS" (funsRec.length == funsLean.length && funsLean.length == OL.nFunctionals)
      s!"OUT-C: {funsLean.length} functionals"
    for i in List.range funsRec.length do
      s := s.check "FUNS" (funsRec.getD i "" == funsLean.getD i "") s!"OUT-C functional {i}"
    let ph (k : String) : Tr :=
      let x := (recsOf "OUTPHASE").find? (fun x => x.getD 1 "" = k)
      trOf ((x.getD []).getD 2 "") ((x.getD []).getD 3 "") key
    s := s.check "AUDIT" (okE (OV.checkOpening H .a acc.claims.a (ph "m")))
      s!"OUT-C check_opening A: {errOf (OV.checkOpening H .a acc.claims.a (ph "m"))}"
    s := s.check "AUDIT" (okE (OV.checkOpening H .h (acc.claims.h ++ [OL.logupSumClaim]) (ph "a")))
      s!"OUT-C check_opening H: {errOf (OV.checkOpening H .h (acc.claims.h ++ [OL.logupSumClaim]) (ph "a"))}"
    s := s.check "AUDIT" (okE (OV.bCheck H (pending ++ acc.claims.inp) (ph "h")))
      s!"OUT-C boundary::check_opening: {errOf (OV.bCheck H (pending ++ acc.claims.inp) (ph "h"))}"
    s := s.check "RESULT" (acc.claims.out.isEmpty) "OUT-C: no claim on an output endpoint"
  -- ======================================================== the segments' bytes (optional)
  match args.getD 1 "", args.getD 2 "" with
  | "", _ => IO.println "(no segment bytes given: DECODE / VERIFY not run)"
  | pin, pout =>
    let binIn := (← IO.FS.readBinFile pin).toList
    let binOut := (← IO.FS.readBinFile pout).toList
    let some stIn := parseDig (w "INTAG" 1) | do IO.println "FAILED parse INTAG"; return 1
    let some enIn := parseDig (w "INTAG" 2) | do IO.println "FAILED parse INTAG"; return 1
    let some stOut := parseDig (w "OUTTAG" 1) | do IO.println "FAILED parse OUTTAG"; return 1
    let some enOut := parseDig (w "OUTTAG" 2) | do IO.println "FAILED parse OUTTAG"; return 1
    let total := nat (w "OUTPCS" 5) + 1
    let gIn : StageGeom := ⟨magicIn, V.geom, true, [(ed, 1, geo.epRows)], total, 0⟩
    let gOut : StageGeom := ⟨magicOut, OV.geom, false, [(obd, ogeo.bSites, ogeo.bRows)], total, total - 1⟩
    s := s.check "DECODE" (binIn.length == nat (w "INSEG" 1) && hexOf (blake3H ⟨none, binIn⟩).toList == w "INSEG" 2)
      s!"IN-C segment: {binIn.length} B, BLAKE3"
    s := s.check "DECODE" (gIn.len == binIn.length) s!"IN-C's counted length {gIn.len}"
    s := s.check "DECODE" (posTag H t0 == stIn) "IN-C's start tag is the position tag of the run header"
    match decodeStage gIn bindg stIn binIn with
    | .error e => s := s.check "DECODE" false s!"IN-C decode refused: {e}"
    | .ok (sg, e) =>
      s := s.check "DECODE" (e == enIn && sg.bRoot == some bRoot && sg.core.aRoot == aRoot && sg.core.hRoot == hRoot
        && sg.core.maskRoot == mRoot && sg.core.slots == slotsIn) "IN-C decoded: the end tag, the roots, the slots"
      s := s.check "DECODE" (encStage gIn bindg stIn sg e == binIn) "IN-C re-encoded: the bytes"
      let some epRoot := parseDig (w "INEPROOT" 1) | do IO.println "FAILED parse INEPROOT"; return 1
      let t1 ← IO.monoMsNow
      match V.verify H epRoot sg t0 with
      | .error e => s := s.check "VERIFY" false s!"IN-C's executable verifier refused: {e}"
      | .ok ((pend, root), tf) =>
        let x := (recsOf "INPHASE").find? (fun x => x.getD 1 "" = "ep")
        s := s.check "VERIFY" (trStr tf == s!"{(x.getD []).getD 2 ""} {(x.getD []).getD 3 ""}" && root == bRoot
          && pend.length == nat (w "INRESULT" 1)) s!"IN-C's executable verifier accepts, on the code's final transcript ({(← IO.monoMsNow) - t1} ms)"
        s := s.check "VERIFY" (posTag H tf == enIn) "IN-C's end tag is the position tag after the stage"
      let flip := binIn.set 300 ((binIn.getD 300 0) + 1)
      s := s.check "NEGATIVE" (match decodeStage gIn bindg stIn flip with
        | .error _ => true
        | .ok (sg', _) => !okE (V.verify H epRoot sg' t0)) "IN-C with one byte of its slots changed is refused"
    s := s.check "DECODE" (binOut.length == nat (w "OUTSEG" 1) && hexOf (blake3H ⟨none, binOut⟩).toList == w "OUTSEG" 2)
      s!"OUT-C segment: {binOut.length} B, BLAKE3"
    s := s.check "DECODE" (gOut.len == binOut.length) s!"OUT-C's counted length {gOut.len}"
    s := s.check "DECODE" (posTag H ot0 == stOut) "OUT-C's start tag is the position tag after the blocks"
    match decodeStage gOut bindg stOut binOut with
    | .error e => s := s.check "DECODE" false s!"OUT-C decode refused: {e}"
    | .ok (sg, e) =>
      s := s.check "DECODE" (e == enOut && sg.bRoot == none && sg.core.aRoot == oaRoot && sg.core.hRoot == ohRoot
        && sg.core.maskRoot == omRoot && sg.core.slots == slotsOut) "OUT-C decoded: the end tag, the roots, the slots"
      s := s.check "DECODE" (encStage gOut bindg stOut sg e == binOut) "OUT-C re-encoded: the bytes"
      let t1 ← IO.monoMsNow
      match OV.verify H obRoot pending sg ot0 with
      | .error e => s := s.check "VERIFY" false s!"OUT-C's executable verifier refused: {e}"
      | .ok tf =>
        s := s.check "VERIFY" (trStr tf == s!"{w "OUTRESULT" 1} {w "OUTRESULT" 2}")
          s!"OUT-C's executable verifier accepts, on the code's final transcript ({(← IO.monoMsNow) - t1} ms)"
        s := s.check "VERIFY" (posTag H tf == enOut) "OUT-C's end tag is the position tag after the stage"
      let badPend := pending.set 0 { (pending.getD 0 ⟨[], Fp2.zero⟩) with value := (pending.getD 0 ⟨[], Fp2.zero⟩).value.add Fp2.one }
      s := s.check "NEGATIVE" (!okE (OV.verify H obRoot badPend sg ot0)) "OUT-C with a pending claim's value + 1 is refused"
  for l in s.log do
    IO.println l
  for (k, n, f) in s.kinds do
    IO.println s!"{k}: {n} checks, {f} failed"
  IO.println s!"StageVerifyExecCheck: {s.n} checks, {s.failed} failed"
  return (if s.failed = 0 then 0 else 1)

end ZK60.Exec.StageV.Check

def main (args : List String) : IO UInt32 := ZK60.Exec.StageV.Check.main args
