/-
D63 lane L53 (2026-11-10): **the stage parts' lists CHECKED against a REAL classifier receipt.**

Run (through the zk60 resource guard; `results/zk60_lean_l53_20261110/check_l53.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/RunStgCheck.lean <corpus.txt> <stage_in_c.rs> <stage_out_c.rs>

The corpus is lane L29's (`results/zk60_lean_l29_20261107/corpus.txt`, from the TEST-ONLY export
`lean_l29_export_the_classify_stages`): an honest classifier run on the development rung accepted by the production
`verify_classify_run`, with stage IN-C's and stage OUT-C's verifiers replayed beside it and the code's transcript
recorded (state and squeeze counter) at the stage's start, after `H`'s root (the head), and after each slot. L29's
checker showed that its Lean stage verifiers land on every one of those states; this one checks THE LISTS:

* `LIST`: the stage's slot count, its slots that draw, its head's challenge count, each slot's rounds and degree, as the
  Lean lists take them (`stgSchedX`, `stgDrawing`, `stgN`, `slotShape`, the head `m`), are the code's (the receipt's
  slot proofs: rounds, values per round; the head's recorded challenges);
* `LU`: the LogUp run's window (`hdrLen + 4`) is the first of the head's `m` squeezes, right after `M`'s absorb, and the
  Lean operations up to the end of the head land on the code's transcript after `H` (BLAKE3 in Lean);
* `DEF`: every define draw's window (`stgDefPos`) is the first of its slot's `draws` squeezes, followed by `pb-slot`
  with the slot's index, and the Lean operations before it land on the code's transcript before that slot;
* `SLOT`: every slot's window (`slotsLenX` of the earlier slots plus `stgS`, PROVED equal to `stgLen + stgS`) is the
  first of its rounds (an `sc-round` absorb and a squeeze each), right after `pb-scalar`, its rounds end on `pb-term`,
  and the Lean operations to that `pb-term` land on the code's transcript after that slot;
* `CLAIM`: every slot's claimed sum as the list reads it (`stgClaim` with the stage's hosting `hostOf`) is the one the
  stage's slot loop handed its sumcheck (L29's executable slot walk, which lands on the code's transcripts);
* `SPAN`: the windows lie inside the stage's operations, in order;
* `SOURCE`: the stage verifiers' source: the slot degrees in order, the hosting, `define` before `run_stage_slot`;
* `NEGATIVE`: single changes to the lists' parameters (the block's head `m = 3`; the frame one longer; one slot's draws
  one more; two slots of different shapes swapped; the zero-draw slot listed as drawing; OUT-C with no hosting; one degree one more) are
  each caught.
It prints the checks per kind and `RunStgCheck: N checks, F failed`, and exits nonzero on any failure. Not imported
by the library root (it defines `main`).
-/
import ZK60Formal.RunStgList

namespace ZK60.ProtocolClassify.StgCheck

open ZK60 ZK60.Exec ZK60.Exec.StageV
open ZK60.Exec.Block (Core SlotProof Dim SlotRec Acc slotStep histOf)

/-! ## Parsing (lane L29's checker's, copied) -/

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

def pSlot (sc rs ts : String) : Option SlotProof := do
  let scalar ← pF2 sc
  let rounds ← if rs = "-" then some [] else (rs.splitOn ";").mapM pF2s
  let terms ← pF2s ts
  pure ⟨scalar, rounds, terms⟩

def f2s (x : Fp2) : String := s!"{x.c0.v.toNat}:{x.c1.v.toNat}"
def trStr (t : Tr) : String := s!"{hexOf t.state.toList} {t.counter.toNat}"

def H : HIn → Dig := blake3H

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
  { s with
    n := s.n + 1
    failed := s.failed + (if ok then 0 else 1)
    kinds := upd s.kinds
    log := s.log ++ [s!"{if ok then "ok  " else "FAIL"} {kind}: {what}"] }

/-! ## Operations -/

def isSq : Op → Bool
  | .squeeze => true
  | _ => false

def isAbs (lab : List UInt8) : Op → Bool
  | .absorb l _ => l == lab
  | _ => false

def isAbsD (lab x : List UInt8) : Op → Bool
  | .absorb l y => l == lab && y == x
  | _ => false

def opAt (ops : List Op) (i : ℕ) : Op := ops.getD i .squeeze

/-- `false` when `i` is past the end: an absorb is never read off the end. -/
def absAtOk (ops : List Op) (i : ℕ) (lab : List UInt8) : Bool := i < ops.length && isAbs lab (opAt ops i)

def sqRun (ops : List Op) (a n : ℕ) : Bool := a + n ≤ ops.length && (List.range n).all (fun j => isSq (opAt ops (a + j)))

/-- Replay a stage's slots one by one (`stSlotsLoop`'s recursion, L29's `slotWalk`), keeping the records. -/
def slotWalk (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    List SlotRec → ℕ → List SlotProof → Acc → Tr → Except String (List SlotRec)
  | recs, _, [], _, _ => .ok recs
  | recs, s, sp :: sps, acc, t =>
    match slotStep H (atLog P (elog s)) s (histOf b g a recs) sp acc t with
    | .error e => .error s!"slot {s}: {e}"
    | .ok (r, acc', t') => slotWalk P elog b g a (recs ++ [r]) (s + 1) sps acc' t'

/-! ## One stage's lists against its recorded transcript -/

/-- What the export recorded of one stage: the transcript at the stage's start, after the head, after each slot; the
slot proofs; the head's challenges; the slot loop's records (from L29's walk). -/
structure Rec where
  t0 : Tr
  head : String
  after : List String
  slots : List SlotProof
  ch : List Fp2
  recs : List SlotRec

/-- **The lists' checks for one stage** at the lists' parameters `P` (the stage's schedule: draws, slot shapes), `m`
(the head), `hdrLen` (the frame, relative to the stage's start), `hostOf` (the hosting), on the stage's Lean operations
`ops` (the frame, `stageRootOps`, `fullOps`: what the run's transcript at the stage is the trace of) and the record. -/
def stageChecks (nm : String) (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (ops : List Op)
    (mRoot : Dig) (r : Rec) (wantNs : ℕ) (wantDraw : List ℕ) (wantM : ℕ) : List (String × Bool × String) := Id.run do
  let mut out : List (String × Bool × String) := []
  let ns := P.geom.slots.length
  -- LIST
  out := out ++ [("LIST", ns == wantNs && r.slots.length == ns, s!"{nm}: {ns} slots (the receipt's {r.slots.length})")]
  out := out ++ [("LIST", stgDrawing P == wantDraw, s!"{nm}: the slots that draw {stgDrawing P}")]
  out := out ++ [("LIST", m == wantM && r.ch.length == m, s!"{nm}: the head's {m} challenges (the receipt's {r.ch.length})")]
  for k in List.range ns do
    let q := r.slots.getD k ⟨Fp2.zero, [], []⟩
    let d := (Block.slotShape P k).2.2
    out := out ++ [("LIST", q.rounds.length == stgN P k && q.rounds.all (fun rr => rr.length == d + 1),
      s!"{nm} slot {k}: {stgN P k} rounds of degree {d}")]
  -- LU
  let a := hdrLen + 4
  out := out ++ [("LU", isAbsD Block.labM mRoot.toList (opAt ops (a - 1)) && sqRun ops a m && absAtOk ops (a + m) Block.labH,
    s!"{nm}: LogUp's window {a} is the first of the head's {m} squeezes, after M, before H")]
  out := out ++ [("LU", (runOps H r.t0 (ops.take a)).counter == r.t0.counter && trStr (runOps H r.t0 (ops.take (a + m + 3))) == r.head,
    s!"{nm}: the operations to the head's end land on the code's transcript after H")]
  -- DEF
  for k in stgDrawing P do
    let a := stgDefPos P m hdrLen k
    let before := if k = 0 then r.head else r.after.getD (k - 1) ""
    out := out ++ [("DEF", sqRun ops a (P.draws k)
        && isAbsD Block.labPbSlot (le64 (UInt64.ofNat k)) (opAt ops (a + P.draws k)),
      s!"{nm} slot {k}: its define window {a} is the first of its {P.draws k} draws, then pb-slot {k}")]
    out := out ++ [("DEF", trStr (runOps H r.t0 (ops.take a)) == before,
      s!"{nm} slot {k}: the operations before its draws land on the code's transcript before the slot")]
  -- SLOT
  let mut prev := 0
  for k in List.range ns do
    let w := stgLen P m hdrLen k + stgS P m hdrLen k
    let n := stgN P k
    out := out ++ [("SLOT", w == stgDefPos P m hdrLen k + (P.draws k + 3) && prev ≤ w,
      s!"{nm} slot {k}: window {w} = its define window + draws + 3, after the previous")]
    out := out ++ [("SLOT", absAtOk ops (w - 1) Block.labPbScalar
        && (List.range n).all (fun i => absAtOk ops (w + 2 * i) scLabel && isSq (opAt ops (w + 2 * i + 1)))
        && absAtOk ops (w + 2 * n) Block.labPbTerm,
      s!"{nm} slot {k}: after pb-scalar, {n} rounds (sc-round, squeeze) from {w}, then pb-term")]
    out := out ++ [("SLOT", trStr (runOps H r.t0 (ops.take (w + 2 * n + 1))) == r.after.getD k "",
      s!"{nm} slot {k}: the operations to its pb-term land on the code's transcript after it")]
    prev := w + 2 * n
  -- CLAIM
  for k in List.range ns do
    let rk := r.recs.getD k ⟨[], Fp2.zero, Fp2.zero, Fp2.zero, [], [], [], Fp2.zero⟩
    out := out ++ [("CLAIM", r.recs.length == ns && stgClaim hostOf k (StageFS.seenOfS r.ch r.recs k) == rk.claimed,
      s!"{nm} slot {k}: the claimed sum the list reads is the slot loop's ({f2s rk.claimed})")]
  -- SPAN
  out := out ++ [("SPAN", hdrLen + 4 + m ≤ stgDefPos P m hdrLen 0 && stgLen P m hdrLen ns + 1 == ops.length,
    s!"{nm}: the head before the slots; the operations end on the last pb-term ({ops.length})")]
  return out

/-- One more degree (a negative control). -/
def bumpDeg (x : ℕ × ℕ × ℕ) : ℕ × ℕ × ℕ := (x.1, x.2.1, x.2.2 + 1)

/-- Two slots' shapes swapped (a negative control). -/
def swapAt (l : List (ℕ × ℕ × ℕ)) (i j : ℕ) : List (ℕ × ℕ × ℕ) :=
  (l.set i (l.getD j (0, 0, 0))).set j (l.getD i (0, 0, 0))

/-- A schedule with other slot shapes (a negative control). -/
def withSlots (P : Block.BlockParams) (sl : List (ℕ × ℕ × ℕ)) : Block.BlockParams :=
  { P with geom := { P.geom with slots := sl } }

/-! ## The source text -/

def contains (s pat : String) : Bool := (s.splitOn pat).length > 1

/-- The `degree: N` of each `SlotSpec { … }` line, in order. -/
def degreesOf (src : String) : List ℕ :=
  (src.splitOn "\n").filterMap (fun l =>
    if contains l "SlotSpec { name:" then
      match (l.splitOn "degree: ") with
      | _ :: rest :: _ => (String.ofList (rest.toList.takeWhile Char.isDigit)).toNat?
      | _ => none
    else none)

/-- `a` occurs before `b` in `s`. -/
def before (s a b : String) : Bool :=
  match s.splitOn a with
  | _ :: rest => contains (String.intercalate a rest) b
  | _ => false

def main (args : List String) : IO UInt32 := do
  let cpath := args.headD "corpus.txt"
  let lines ← IO.FS.lines cpath
  let words : List (List String) := (lines.toList.filter (fun l => !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let recsOf (k : String) : List (List String) := words.filter (fun w => w.headD "" = k)
  let w (k : String) (i : ℕ) : String := (rec1 k).getD i ""
  let keyS := w "KEY" 1
  let key : Option Dig := if keyS = "-" then none else parseDig keyS
  let trOf (st ctr : String) : Tr := ⟨(parseDig st).getD zeroDig, UInt64.ofNat (nat ctr), key⟩
  let tagK (i : ℕ) : Option Dig := if w "MTAG" i = "-" then none else parseDig (w "MTAG" i)
  let mtag : MTag := ⟨tagK 1, tagK 2, tagK 3⟩
  let mut s : St := {}
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
  let t0 := trOf (w "INSTART" 1) (w "INSTART" 2)
  let some bRoot := parseDig (w "INROOTS" 1) | do IO.println "FAILED parse INROOTS"; return 1
  let some aRoot := parseDig (w "INROOTS" 2) | do IO.println "FAILED parse INROOTS"; return 1
  let some hRoot := parseDig (w "INROOTS" 3) | do IO.println "FAILED parse INROOTS"; return 1
  let some mRoot := parseDig (w "INROOTS" 4) | do IO.println "FAILED parse INROOTS"; return 1
  let slotsIn : List SlotProof := (recsOf "INSLOT").filterMap (fun x => pSlot (x.getD 2 "") (x.getD 3 "") (x.getD 4 ""))
  let coreIn : Core := ⟨aRoot, hRoot, mRoot, slotsIn, ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩
  let mIn := incHeadDraws pub
  let cx := incCtx pub ch0
  let PIn := V.bp cx
  let frameIn := rtIncFrame pub.embDigest bRoot geo.bRows geo.bLogN
  let opsOf (P : Block.BlockParams) (m : ℕ) (fr : List Op) (c : Core) : List Op :=
    fr ++ (StageFS.stageRootOps P c m ++ Block.fullOps P 0 c.slots)
  let opsIn := opsOf PIn mIn frameIn coreIn
  let recsIn := match slotWalk PIn (incElog pub geo.bLogN) Fp2.zero Fp2.zero Fp2.zero [] 0 slotsIn {}
      (V.slotT H coreIn (V.frame H bRoot t0)) with
    | .ok rs => rs
    | .error _ => []
  s := s.check "LIST" (recsIn.length == 4) s!"IN-C: L29's slot walk accepts the receipt's 4 slots"
  let recIn : Rec := ⟨t0, s!"{w "INHEAD" 1} {w "INHEAD" 2}", (recsOf "INAFTER").map (fun x => s!"{x.getD 2 ""} {x.getD 3 ""}"),
    slotsIn, ch0, recsIn⟩
  let hostIn : ℕ → List (ℕ × ℕ) := fun _ => []
  for (k, ok, what) in stageChecks "IN-C" PIn mIn frameIn.length hostIn opsIn mRoot recIn 4 [0, 1, 2] 12 do
    s := s.check k ok what
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
  let ot0 := trOf (w "OUTSTART" 1) (w "OUTSTART" 2)
  let some oaRoot := parseDig (w "OUTROOTS" 2) | do IO.println "FAILED parse OUTROOTS"; return 1
  let some ohRoot := parseDig (w "OUTROOTS" 3) | do IO.println "FAILED parse OUTROOTS"; return 1
  let some omRoot := parseDig (w "OUTROOTS" 4) | do IO.println "FAILED parse OUTROOTS"; return 1
  let slotsOut : List SlotProof := (recsOf "OUTSLOT").filterMap (fun x => pSlot (x.getD 2 "") (x.getD 3 "") (x.getD 4 ""))
  let coreOut : Core := ⟨oaRoot, ohRoot, omRoot, slotsOut, ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩
  let some och := pF2s ((rec1 "OUTHEAD").getD 3 "") | do IO.println "FAILED parse OUTHEAD"; return 1
  let POut := OV.bp
  let frameOut := rtOutcFrame OV.stageIndex opub.wDigest
  let opsOut := opsOf POut 2 frameOut coreOut
  let ot3 := runOps H ot0 (frameOut ++ StageFS.stageRootOps POut coreOut 2)
  let recsOut := match slotWalk POut (fun _ => ogeo.bLogN) (OutcV.bga och).1 (OutcV.bga och).2.1 (OutcV.bga och).2.2
      [] 0 slotsOut {} ot3 with
    | .ok rs => rs
    | .error _ => []
  s := s.check "LIST" (recsOut.length == 8) s!"OUT-C: L29's slot walk accepts the receipt's 8 slots"
  let recOut : Rec := ⟨ot0, s!"{w "OUTHEAD" 1} {w "OUTHEAD" 2}",
    (recsOf "OUTAFTER").map (fun x => s!"{x.getD 2 ""} {x.getD 3 ""}"), slotsOut, och, recsOut⟩
  -- OUT-C's hosting (stage_out_c.rs `hosts`): TZC (2) hosts SS (1) with `ν`, draw 5 of TZC's (τ 1, μ 4, ν, ζ);
  -- LZC (4) hosts PD (3) with `ν`, draw `llo + 2` of LZC's (τ llo, μ 2, ν)
  let hostOut : ℕ → List (ℕ × ℕ) := fun k => if k = 2 then [(1, 5)] else if k = 4 then [(3, opub.llo + 2)] else []
  for (k, ok, what) in stageChecks "OUT-C" POut 2 frameOut.length hostOut opsOut omRoot recOut 8 [0, 2, 4, 5, 6] 2 do
    s := s.check k ok what
  -- ======================================================== the source
  match args.getD 1 "", args.getD 2 "" with
  | "", _ => s := s.check "SOURCE" false "no source files given"
  | pin, pout =>
    let srcIn ← IO.FS.readFile pin
    let srcOut ← IO.FS.readFile pout
    let degIn := (List.range PIn.geom.slots.length).map (fun k => (Block.slotShape PIn k).2.2)
    let degOut := (List.range POut.geom.slots.length).map (fun k => (Block.slotShape POut k).2.2)
    s := s.check "SOURCE" (degreesOf srcIn == degIn) s!"IN-C's SlotSpec degrees {degreesOf srcIn} are the list's {degIn}"
    s := s.check "SOURCE" (degreesOf srcOut == degOut) s!"OUT-C's SlotSpec degrees {degreesOf srcOut} are the list's {degOut}"
    s := s.check "SOURCE" (contains srcIn "hosts: vec![]," ) "IN-C hosts nothing"
    s := s.check "SOURCE" (contains srcOut "hosts: vec![(SOC_TZC, vec![SOC_SS]), (SOC_LZC, vec![SOC_PD])],")
      "OUT-C: TZC hosts SS, LZC hosts PD"
    s := s.check "SOURCE" (contains srcOut "b.finish(Box::new(poly), vec![(SOC_SS, nu)])"
        && contains srcOut "b.finish(Box::new(poly), vec![(SOC_PD, nu)])"
        && contains srcOut "let mu = nonzero(tr.challenge_fp2_vec(4))?;\n            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];"
        && contains srcOut "let mu = nonzero(tr.challenge_fp2_vec(2))?;\n            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];")
      "OUT-C: TZC's and LZC's host coefficient is the ν drawn after τ and μ"
    s := s.check "SOURCE" (contains srcIn "let def = define(slot, cx, tr)?;\n        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;"
        && contains srcOut "let def = define(slot, cx, tr)?;\n        run_stage_slot(side, &mut acc, def, &cx.lay.sched, tr)?;")
      "both stages: each slot's define draws, then its run_stage_slot"
    s := s.check "SOURCE" (before srcIn "let (beta, alpha, g_emb, r_emb, ef) = challenges(tr, cp, tables);\n    let tau_tab = tau_table(cp, &ef, beta, g_emb);\n    protocol::absorb_root(tr, b\"H\""
        "let acc = run_slots(&mut side, &cx, tr)?;"
      && contains srcIn "let beta = tr.challenge_fp2();\n    let gamma = tr.challenge_fp2();\n    let alpha = tr.challenge_fp2();\n    let r_emb = tr.challenge_fp2_vec(clog2(cp.d_pad));")
      "IN-C's head: beta, gamma, alpha, r_emb after M, before H and the slots"
    s := s.check "SOURCE" (contains srcOut "tr.absorb(b\"M\", &seg.mask_root);\n    let gamma = tr.challenge_fp2();\n    let alpha = tr.challenge_fp2();")
      "OUT-C's head: gamma, alpha after M"
  -- ======================================================== the negative control
  let neg (what : String) (l : List (String × Bool × String)) : St → St := fun st =>
    st.check "NEGATIVE" (l.any (fun x => !x.2.1)) s!"{what} is caught"
  let PInD (f : ℕ → ℕ) : Block.BlockParams := { PIn with draws := f }
  let swapG (P : Block.BlockParams) (i j : ℕ) : Block.BlockParams := withSlots P (swapAt P.geom.slots i j)
  let degG (P : Block.BlockParams) (i : ℕ) : Block.BlockParams :=
    withSlots P (P.geom.slots.set i (bumpDeg (P.geom.slots.getD i (0, 0, 0))))
  s := neg "IN-C at the block's head (m = 3)" (stageChecks "IN-C" PIn 3 frameIn.length hostIn opsIn mRoot recIn 4 [0, 1, 2] 3) s
  s := neg "IN-C with the frame one longer" (stageChecks "IN-C" PIn mIn (frameIn.length + 1) hostIn opsIn mRoot recIn 4 [0, 1, 2] 12) s
  s := neg "IN-C with slot 1's draws one more" (stageChecks "IN-C" (PInD (fun k => if k = 1 then PIn.draws k + 1 else PIn.draws k))
    mIn frameIn.length hostIn opsIn mRoot recIn 4 [0, 1, 2] 12) s
  s := neg "IN-C with slots 0 and 1 swapped" (stageChecks "IN-C" (swapG PIn 0 1) mIn frameIn.length hostIn opsIn mRoot recIn 4
    [0, 1, 2] 12) s
  s := neg "IN-C with the zero-sum slot listed as drawing" (stageChecks "IN-C" (PInD (fun k => if k = 3 then 1 else PIn.draws k))
    mIn frameIn.length hostIn opsIn mRoot recIn 4 [0, 1, 2] 12) s
  s := neg "IN-C with slot 0's degree one more" (stageChecks "IN-C" (degG PIn 0) mIn frameIn.length hostIn opsIn mRoot recIn 4
    [0, 1, 2] 12) s
  s := neg "OUT-C with no hosting" (stageChecks "OUT-C" POut 2 frameOut.length (fun _ => []) opsOut omRoot recOut 8 [0, 2, 4, 5, 6] 2) s
  s := neg "OUT-C at the block's head (m = 3)" (stageChecks "OUT-C" POut 3 frameOut.length hostOut opsOut omRoot recOut 8
    [0, 2, 4, 5, 6] 3) s
  s := neg "OUT-C with slots 4 and 5 swapped" (stageChecks "OUT-C" (swapG POut 4 5) 2 frameOut.length hostOut opsOut omRoot recOut 8
    [0, 2, 4, 5, 6] 2) s
  s := neg "OUT-C with LZC's host coefficient one draw later" (stageChecks "OUT-C" POut 2 frameOut.length
    (fun k => if k = 2 then [(1, 5)] else if k = 4 then [(3, opub.llo + 3)] else []) opsOut omRoot recOut 8 [0, 2, 4, 5, 6] 2) s
  for l in s.log do
    IO.println l
  for (k, n, f) in s.kinds do
    IO.println s!"{k}: {n} checks, {f} failed"
  IO.println s!"RunStgCheck: {s.n} checks, {s.failed} failed"
  return (if s.failed = 0 then 0 else 1)

end ZK60.ProtocolClassify.StgCheck

def main (args : List String) : IO UInt32 := ZK60.ProtocolClassify.StgCheck.main args
