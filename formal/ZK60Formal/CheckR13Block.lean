/-
D63 Lean lane L17 (2026-11-07): **the R13 adapter of L9's block-verifier check**, on a REAL R13 block, and the
D12a SEGMENT decoder on a REAL R13 run segment.

Run (through the zk60 resource guard; `results/zk60_lean_l17_20261107/check_l17.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/CheckR13Block.lean <block_corpus.txt> <fork_frame.bin>
    <segment_corpus.txt> <segment.bin>

The corpora come from the TEST-ONLY hashline export `lean_l17_export_tests.rs`:
* `lean_l17_export_r13_block` (L9's format): the R13 development rung's block core
  (`hashline-zk-mr1/private-block-rung-lh-t32-dev/2`, LOW + h24, byte limbs, rate 1/4, `Q = 256`), proved by the
  production `prove_core`, framed by the production `encode_fork` (`HLPFORK1`) and accepted by the production
  `decode_fork` / `verify_core`; every challenge `verify_core` draws, phase by phase (each phase asserted on the Rust
  side to end in the production transcript), thirteen single changes with the production verdict. This file is L9's
  `ExecBlockCheck.lean` with R13's schedule (`R13.rungSlots`, `rungTerms`, `rungDrawList`), R13's geometry
  (`Q = 256` at rate 1/4) and the same stand-in for the sub-checks L10 / L11 own (their R13 adapters are
  `CheckR13Open.lean` and `CheckR13Slots.lean`);
* `lean_l17_export_r13_segment`: a one-stage R13 D12a run (the frame the R13 classifier run carries) on the public
  loader fixture `r13-h24-wide`, proved by the production `run::prove_run` and accepted by `run::verify_run`; this file
  decodes it with `ExecBlockR13.lean`'s `decodeSegment` at `R13.segGeom` (the geometry from the stage's own shape),
  checks the end tag, the re-encoding byte for byte, every decoded field's BLAKE3, and fourteen single changes, each
  decoded (or refused) as the production `wire::decode_segment` did, message for message.
Prints the checks per kind and `CheckR13Block: N checks, F failed`; nonzero exit on any failure. Not imported by the
library root (it defines `main`).
-/
import ZK60Formal.ExecBlockR13

namespace ZK60.Exec.Block.CheckR13

open ZK60.Exec.Block

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

def parseHex (s : String) : Option (List UInt8) := if s = "-" ∨ s = "" then some [] else hexPairs s.toList

def parseDig (s : String) : Option Dig := parseHex s >>= digOf?

def hexOf (b : List UInt8) : String :=
  String.join (b.map fun x =>
    let d := "0123456789abcdef".toList
    String.ofList [d.getD (x.toNat / 16) '0', d.getD (x.toNat % 16) '0'])

def parseNats (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (⟨fpOf a, fpOf b⟩ :: ·)

def pF2s (s : String) : Option (List Fp2) := parseNats s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def f2Str (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

/-- `key value` pairs of a record's fields. -/
def kv : List String → List (String × String)
  | k :: v :: rest => (k, v) :: kv rest
  | _ => []

def look (l : List (String × String)) (k : String) : String := (l.lookup k).getD ""

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
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 40 then s.msgs.push s!"[{kind}] {msg.take 200}" else s.msgs }

def H : HIn → Dig := blake3H

/-! ## The corpus -/

structure SlotRow where
  n : ℕ
  e : ℕ
  d : ℕ
  terms : ℕ
  kind : SlotKind
  name : String

structure SlotRecRow where
  draws : List Fp2
  c : Fp2
  scalar : Fp2
  hosted : List (ℕ × Fp2)
  claimed : Fp2
  rho : List Fp2
  fin : Fp2
  terms : List Fp2
  state : Dig
  ctr : ℕ

def parseKind : String → Option SlotKind
  | "Private" => some .priv
  | "Standalone" => some .standalone
  | "Host" => some .host
  | _ => none

def parseHosted (s : String) : Option (List (ℕ × Fp2)) :=
  if s = "-" then some []
  else (s.splitOn ";").mapM fun h =>
    match h.splitOn ":" with
    | [a, b] => do
      let i ← a.toNat?
      let x ← pF2 b
      pure (i, x)
    | _ => none

def parseSlotRec (w : List String) : Option SlotRecRow := do
  let l := kv (w.drop 2)
  let st ← parseDig ((w.reverse.drop 1).headD "")
  let ctr ← (w.getLast?.getD "").toNat?
  let draws ← pF2s (look l "draws")
  let c ← pF2 (look l "c")
  let scalar ← pF2 (look l "scalar")
  let hosted ← parseHosted (look l "hosted")
  let claimed ← pF2 (look l "claimed")
  let rho ← pF2s (look l "rho")
  let fin ← pF2 (look l "fin")
  let terms ← pF2s (look l "terms")
  pure ⟨draws, c, scalar, hosted, claimed, rho, fin, terms, st, ctr⟩

/-! ## The transcript stand-in for the sub-checks L10 / L11 own -/

/-- A private table that only counts (the stand-in's slot definitions carry the code's private-table COUNT). -/
def dummyPriv : Tab := .priv ⟨.a, [(0, Fp2.one)], 0, [], 0, 0⟩

/-- **The stand-in parameters**: the geometry and counts are the corpus's shape; `define` returns the code's hosted
list and private-table count with a zero polynomial; `M` and the openings move the transcript as the code. -/
def standIn (g : Geom) (logCols aRows hRows aProx hProx q encCols nSpecs nFun : ℕ) (rows : List SlotRow)
    (recs : List SlotRecRow) (aCounts hCounts : List ℕ) : BlockParams where
  geom := g
  logCols := logCols
  endpointLogN := logCols
  aRows := aRows
  hRows := hRows
  aPath := g.blk.path
  hPath := g.blk.path
  maskPath := g.maskPath
  preChecks := .ok ()
  kind s := (rows.getD s ⟨0, 0, 0, 0, .priv, ""⟩).kind
  name s := (rows.getD s ⟨0, 0, 0, 0, .priv, ""⟩).name
  draws s := (recs.getD s ⟨[], Fp2.zero, Fp2.zero, [], Fp2.zero, [], Fp2.zero, [], dig0, 0⟩).draws.length
  define s _ _ :=
    let r := rows.getD s ⟨0, 0, 0, 0, .priv, ""⟩
    let rc := recs.getD s ⟨[], Fp2.zero, Fp2.zero, [], Fp2.zero, [], Fp2.zero, [], dig0, 0⟩
    .ok ⟨List.replicate r.terms dummyPriv, fun _ => Fp2.zero, rc.hosted⟩
  nFunctionals := nFun
  logupSumClaim := ⟨[], Fp2.zero⟩
  maskVerify H' _ _ mo t := (maskTranscript H' nSpecs W16R2.maskQ W16R2.maskDom mo t).map (·.2.2.2)
  checkOpening H' cm _ t :=
    match cm with
    | .a => openingChallenges H' aCounts aRows aProx t
    | _ => openingChallenges H' hCounts hRows hProx t
  pcsVerify H' cm _ _ o t :=
    match cm with
    | .a => (pcsTranscript H' aCounts aRows q encCols o t).map (·.2.2.2)
    | _ => (pcsTranscript H' hCounts hRows q encCols o t).map (·.2.2.2)

/-- Apply a recorded change (`i:b,…` byte values, or `len:N`) to the frame. -/
def applyDiff (frame : List UInt8) (diff : String) : Option (List UInt8) :=
  if diff = "-" then some frame
  else if diff.startsWith "len:" then do
    let n ← (diff.drop 4).toNat?
    pure (if n ≤ frame.length then frame.take n else frame ++ List.replicate (n - frame.length) 0)
  else do
    let ps ← (diff.splitOn ",").mapM fun p =>
      match p.splitOn ":" with
      | [a, b] => do
        let i ← a.toNat?
        let v ← b.toNat?
        pure (i, UInt8.ofNat v)
      | _ => none
    pure (ps.foldl (fun (f : Array UInt8) (iv : ℕ × UInt8) => f.set! iv.1 iv.2) frame.toArray).toList

/-- Whether a coefficient is `ν·κ` for one of the slot's draws `ν` and a public integer `κ < 2^32`. -/
def isDrawTimesInt (draws : List Fp2) (coef : Fp2) : Bool :=
  draws.any fun nu => !nu.isZero && (let kap := coef.mul nu.inv; kap.c1.v = 0 && kap.c0.v.toNat < 2 ^ 32)

def main (args : List String) : IO UInt32 := do
  let cpath := args.headD "results/zk60_lean_l17_20261107/block_corpus.txt"
  let fpath := args.getD 1 "fork_frame.bin"
  let lines ← IO.FS.lines cpath
  let frame := (← IO.FS.readBinFile fpath).toList
  let words : List (List String) := (lines.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let recsOf (k : String) : List (List String) := words.filter (fun w => w.headD "" = k)
  let mut s : St := {}
  -- the label literals
  for (lab, txt) in [(labA, "A"), (labH, "H"), (labM, "M"), (labRows, "rows"), (labLogCols, "log-cols"),
      (labPbSlot, "pb-slot"), (labPbScalar, "pb-scalar"), (labPbTerm, "pb-term"), (labMaskQ, "mask-q"),
      (labMaskProx, "mask-prox"), (labPcsVec, "pcs-vec"), (labPcsProx, "pcs-prox"), (forkMagic, "HLPFORK1")] do
    s := s.check "ASCII" (ascii txt == lab) txt
  -- the shape
  let sh := kv ((rec1 "SHAPE").drop 1)
  let nat (k : String) : ℕ := (look sh k).toNat?.getD 0
  let rows : List SlotRow := (recsOf "SLOTSHAPE").filterMap fun w =>
    match w with
    | _ :: _ :: n :: e :: d :: t :: k :: name => do
      let n ← n.toNat?
      let e ← e.toNat?
      let d ← d.toNat?
      let t ← t.toNat?
      let k ← parseKind k
      pure (⟨n, e, d, t, k, " ".intercalate name⟩ : SlotRow)
    | _ => none
  let logCols := nat "log_cols"
  let q := nat "q"
  let encCols := nat "enc_cols"
  let blkDim : Dim := ⟨q, 2 ^ logCols + q, encCols, Nat.log2 encCols⟩
  let g : Geom := ⟨rows.map (fun r => (r.n, r.e, r.d)), rows.map (·.terms), W16R2.maskVec, W16R2.maskQ,
    W16R2.maskDom, W16R2.maskPath, nat "m_rows", blkDim, nat "a_groups", nat "a_rows", nat "h_groups", nat "h_rows",
    R13.ceiling⟩
  s := s.check "SHAPE" (rows.length = nat "n_slots" && rows.length > 0) s!"{rows.length} slot rows"
  s := s.check "SCHEDULE" (rows.map (fun r => (r.n, r.e, r.d)) == R13.rungSlots) "the slot schedule is R13.rungSlots"
  s := s.check "SCHEDULE" (rows.map (·.terms) == R13.rungTerms) "the terminal counts are R13.rungTerms"
  s := s.check "SCHEDULE" (q = R13.openedCols && nat "inv_rate" = R13.invRate && logCols = R13.logCols
    && blkDim.checks = R13.blkDim.checks && blkDim.vec = R13.blkDim.vec && blkDim.encCols = R13.blkDim.encCols
    && blkDim.path = R13.blkDim.path) "Q = 256 at rate 1/4: the block Dim is R13.blkDim"
  -- the frame
  let fr := rec1 "FRAME"
  s := s.check "FRAME" (frame.length = (fr.getD 1 "").toNat?.getD 0) s!"length {frame.length}"
  s := s.check "FRAME" (g.forkLen = frame.length) s!"forkLen {g.forkLen} vs {frame.length}"
  s := s.check "FRAME" (hexOf (blake3H ⟨none, frame⟩).toList = fr.getD 2 "") "BLAKE3 of the frame"
  -- the start transcript and its tag
  let stw := rec1 "START"
  let some st0 := parseDig (stw.getD 1 "") | do IO.println "FAILED parse START"; return 1
  let some key := (if stw.getD 3 "-" = "-" then some none else (parseDig (stw.getD 3 "")).map some) | do
    IO.println "FAILED parse key"; return 1
  let t0 : Tr := ⟨st0, UInt64.ofNat ((stw.getD 2 "").toNat?.getD 0), key⟩
  let tags := rec1 "TAGS"
  let some startTag := parseDig (tags.getD 1 "") | do IO.println "FAILED parse TAGS"; return 1
  let some endTag := parseDig (tags.getD 2 "") | do IO.println "FAILED parse TAGS"; return 1
  let some bindg := parseDig ((rec1 "BINDING").getD 1 "") | do IO.println "FAILED parse BINDING"; return 1
  s := s.check "TAG" (posTag H t0 == startTag) "the start position tag"
  s := s.check "TAG" (bindg == st0) "the binding is the header state"
  -- the decoder
  match decodeFork g bindg 1 0 startTag frame with
  | .error e =>
    s := s.check "DECODE" false s!"decodeFork refused: {e}"
  | .ok (core, et) =>
    s := s.check "DECODE" true "decodeFork accepts the frame"
    s := s.check "DECODE" (et == endTag) "the end tag"
    s := s.check "DECODE" ((encFork bindg 1 0 startTag core et).toArray == frame.toArray) "the re-encoding is the frame byte for byte"
    let roots := rec1 "ROOTS"
    s := s.check "FIELDS" (hexOf core.aRoot.toList = roots.getD 1 "" && hexOf core.hRoot.toList = roots.getD 2 ""
      && hexOf core.maskRoot.toList = roots.getD 3 "") "the three roots"
    let fw := (rec1 "FIELDS")
    let dig (b : List UInt8) : String := hexOf (blake3H ⟨none, b⟩).toList
    s := s.check "FIELDS" (dig (core.slots.flatMap encSlot) = fw.getD 3 "" && (core.slots.flatMap encSlot).length = (fw.getD 2 "").toNat?.getD 0) "the slots"
    s := s.check "FIELDS" (dig (encMask core.maskOpen) = fw.getD 6 "") "M's opening"
    s := s.check "FIELDS" (dig (encHiding core.aOpen) = fw.getD 9 "") "A's opening"
    s := s.check "FIELDS" (dig (encHiding core.hOpen) = fw.getD 12 "") "H's opening"
    -- the stand-in
    let srecs : List SlotRecRow := (recsOf "SLOT").filterMap parseSlotRec
    s := s.check "SLOT" (srecs.length = rows.length) s!"{srecs.length} slot records"
    s := s.check "SCHEDULE" (srecs.map (·.draws.length) == R13.rungDrawList) "define's draw counts are R13.rungDrawList"
    let pcsRec (nm : String) : List String := ((recsOf "PCS").find? (fun w => w.getD 1 "" = nm)).getD []
    let counts (nm : String) : List ℕ := (parseNats (look (kv ((pcsRec nm).drop 2)) "counts")).getD []
    let P := standIn g logCols (nat "a_rows") (nat "h_rows") (nat "a_prox") (nat "h_prox") q encCols (nat "mask_specs")
      (((rec1 "FUNCTIONALS").getD 1 "").toNat?.getD 0) rows srecs (counts "A") (counts "H")
    -- the slot phase
    match blockSlots H P core t0 with
    | .error e => s := s.check "SLOTS" false s!"blockSlots refused: {e}"
    | .ok ((b, gm, a), recs, acc, tS) =>
      let lu := rec1 "LOGUP"
      s := s.check "LOGUP" (f2Str b = lu.getD 1 "" && f2Str gm = lu.getD 2 "" && f2Str a = lu.getD 3 "") "β, γ, α"
      s := s.check "SLOTS" (recs.length = srecs.length) "every slot verified"
      for (r, rr) in recs.zip srecs do
        s := s.check "SLOT-DRAWS" (r.draws == rr.draws) s!"define's draws {r.draws.length}"
        s := s.check "SLOT-C" (r.c == rr.c) "c"
        s := s.check "SLOT-SCALAR" (r.scalar == rr.scalar) "scalar"
        s := s.check "SLOT-CLAIMED" (r.claimed == rr.claimed) "the claimed sum"
        s := s.check "SLOT-RHO" (r.rho ++ r.es == rr.rho) s!"the round challenges ({rr.rho.length})"
        s := s.check "SLOT-FIN" (r.fin == rr.fin) "the final value"
        s := s.check "SLOT-TERMS" (r.terms == rr.terms) "the terminals"
        s := s.check "SLOT-HOSTED" (rr.hosted.all (fun h => isDrawTimesInt r.draws h.2)) "each hosted coefficient is ν·κ"
      -- the state after each slot, from `blockOps`' operations (`slotsLoop_ok`: the loop runs on them)
      let mut tt := runOps H t0 (rootOps P core)
      let mut j := 0
      for (sp, rr) in core.slots.zip srecs do
        tt := runOps H tt (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp])
        s := s.check "SLOT-STATE" (tt.state == rr.state && tt.counter.toNat = rr.ctr) s!"the state after slot {j}"
        j := j + 1
      s := s.check "FUNCTIONALS" ((acc.fs ++ acc.hostFs).length = P.nFunctionals) s!"{(acc.fs ++ acc.hostFs).length}"
      let lastSt := (srecs.getLast?.map (·.state)).getD dig0
      s := s.check "SLOTS" (tS.state == lastSt && tS.counter.toNat = (srecs.getLast?.map (·.ctr)).getD 0)
        "the transcript after the last slot"
      -- M
      let mk := rec1 "MASK"
      let ml := kv (mk.drop 1)
      match maskTranscript H (nat "mask_specs") W16R2.maskQ W16R2.maskDom core.maskOpen tS with
      | .error e => s := s.check "MASK" false s!"refused: {e}"
      | .ok (th, rs, idx, tM) =>
        s := s.check "MASK" (some th == pF2 (look ml "theta")) "θ"
        s := s.check "MASK" (some rs == pF2s (look ml "rs")) s!"the {rs.length} row coefficients"
        s := s.check "MASK" (some idx == parseNats (look ml "idx")) s!"the {idx.length} column indices"
        s := s.check "MASK" (some tM.state == parseDig (mk.getD (mk.length - 2) "")) "the state after M"
        -- A and H
        let mut tP := tM
        for (nm, cnts, rws, prx, op) in [("A", counts "A", nat "a_rows", nat "a_prox", core.aOpen),
            ("H", counts "H", nat "h_rows", nat "h_prox", core.hOpen)] do
          let pr := pcsRec nm
          let pl := kv (pr.drop 2)
          s := s.check "OPEN" (openingChallenges H cnts rws prx tP matches .ok _) s!"{nm}: the opening-challenge refusals"
          match pcsTranscript H cnts rws q encCols op tP with
          | .error e => s := s.check "PCS" false s!"{nm} refused: {e}"
          | .ok (lams, prox, idx, t') =>
            s := s.check "PCS" (some lams == pF2s (look pl "lambdas")) s!"{nm}: the {lams.length} λs"
            s := s.check "PCS" (some prox == pF2s (look pl "prox")) s!"{nm}: the {prox.length} proximity coefficients"
            s := s.check "PCS" (some idx == parseNats (look pl "idx")) s!"{nm}: the {idx.length} column indices"
            s := s.check "PCS" (some t'.state == parseDig (pr.getD (pr.length - 2) "")) s!"{nm}: the state after"
            tP := t'
        let en := rec1 "END"
        s := s.check "END" (some tP.state == parseDig (en.getD 1 "") && tP.counter.toNat = (en.getD 2 "").toNat?.getD 0)
          "the end state"
    -- the whole verifier
    match forkVerify H P bindg 1 0 t0 frame with
    | .error e => s := s.check "FORK" false s!"forkVerify refused the honest frame: {e}"
    | .ok (_, tF) =>
      s := s.check "FORK" true "forkVerify accepts the honest frame"
      s := s.check "FORK" (posTag H tF == endTag) "the end position tag"
    -- the single changes
    for w in recsOf "TAMPER" do
      let nm := w.getD 1 ""
      let diff := w.getD 2 ""
      let verdict := " ".intercalate (w.drop 3)
      match applyDiff frame diff with
      | none => s := s.check "TAMPER" false s!"{nm}: parse"
      | some bytes =>
        let lean := match forkVerify H P bindg 1 0 t0 bytes with
          | .ok _ => "OK"
          | .error e => s!"ERR {e}"
        s := s.check "TAMPER" (lean = verdict) s!"{nm}: Lean {lean} / Rust {verdict}"
  -- the D12a segment (the R13 classifier run's frame)
  let spath := args.getD 2 "results/zk60_lean_l17_20261107/segment_corpus.txt"
  let bpath := args.getD 3 ""
  if bpath ≠ "" then
    let slines ← IO.FS.lines spath
    let seg := (← IO.FS.readBinFile bpath).toList
    let sw : List (List String) := (slines.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
      (fun l => (l.splitOn " ").filter (· ≠ ""))
    let srec1 (k : String) : List String := (sw.find? (fun w => w.headD "" = k)).getD []
    let srecs (k : String) : List (List String) := sw.filter (fun w => w.headD "" = k)
    let ssh := kv ((srec1 "SEGSHAPE").drop 1)
    let snat (k : String) : ℕ := (look ssh k).toNat?.getD 0
    let srows : List ((ℕ × ℕ × ℕ) × ℕ) := (srecs "SLOTSHAPE").filterMap fun w =>
      match w with
      | [_, _, n, e, d, t] => do
        let n ← n.toNat?
        let e ← e.toNat?
        let d ← d.toNat?
        let t ← t.toNat?
        pure ((n, e, d), t)
      | _ => none
    let sg0 := R13.geom (srows.map Prod.fst) (srows.map Prod.snd) (snat "m_rows") (snat "a_groups") (snat "a_rows")
      (snat "h_groups") (snat "h_rows")
    let sgeo := R13.segGeom sg0 (snat "e_rows") (snat "l") (snat "k") 0 0
    s := s.check "SEG-SHAPE" (srows.map Prod.fst == R13.rungSlots && srows.map Prod.snd == R13.rungTerms)
      "the segment's stage schedule is the R13 rung's"
    s := s.check "SEG-SHAPE" (snat "log_cols" = R13.logCols && snat "inv_rate" = R13.invRate && snat "q" = R13.openedCols
      && snat "e_log_n" = R13.logCols && snat "e_inv_rate" = R13.invRate && snat "ceiling" = R13.ceiling)
      "R13's PCS geometry; the endpoints' is the block's"
    let sf := srec1 "SEGMENT"
    s := s.check "SEG-FRAME" (seg.length = (sf.getD 1 "").toNat?.getD 0 && sgeo.len = seg.length)
      s!"segment_len {sgeo.len} vs {seg.length}"
    s := s.check "SEG-FRAME" (hexOf (blake3H ⟨none, seg⟩).toList = sf.getD 2 "") "BLAKE3 of the segment"
    let some sb := parseDig ((srec1 "BINDING").getD 1 "") | do IO.println "FAILED parse segment BINDING"; return 1
    let stg := srec1 "TAGS"
    let some sst := parseDig (stg.getD 1 "") | do IO.println "FAILED parse segment TAGS"; return 1
    let some sen := parseDig (stg.getD 2 "") | do IO.println "FAILED parse segment TAGS"; return 1
    match decodeSegment sgeo sb sst seg with
    | .error e => s := s.check "SEG-DECODE" false s!"decodeSegment refused: {e}"
    | .ok (sgm, et) =>
      s := s.check "SEG-DECODE" true "decodeSegment accepts the segment"
      s := s.check "SEG-DECODE" (et == sen) "the end tag"
      s := s.check "SEG-DECODE" ((encSeg sb (snat "l") (snat "k") sst sgm et).toArray == seg.toArray)
        "the re-encoding is the segment byte for byte"
      s := s.check "SEG-DECODE" (sgm.bRoot.isNone && sgm.outOpen.isSome)
        "no boundary root and the output endpoint's opening (L = 1)"
      let rr := srec1 "ROOTS"
      s := s.check "SEG-FIELDS" (hexOf sgm.core.aRoot.toList = rr.getD 1 "" && hexOf sgm.core.hRoot.toList = rr.getD 2 ""
        && hexOf sgm.core.maskRoot.toList = rr.getD 3 "") "the three roots"
      let fw := srec1 "FIELDS"
      let dig (b : List UInt8) : String := hexOf (blake3H ⟨none, b⟩).toList
      s := s.check "SEG-FIELDS" (dig (sgm.core.slots.flatMap encSlot) = fw.getD 3 "") "the slots"
      s := s.check "SEG-FIELDS" (dig (encMask sgm.core.maskOpen) = fw.getD 6 "") "M's opening"
      s := s.check "SEG-FIELDS" (dig (encHiding sgm.core.aOpen) = fw.getD 9 "") "A's opening"
      s := s.check "SEG-FIELDS" (dig (encHiding sgm.core.hOpen) = fw.getD 12 "") "H's opening"
      s := s.check "SEG-FIELDS" (dig (encHiding sgm.inOpen) = fw.getD 15 "") "the input endpoint's opening"
      s := s.check "SEG-FIELDS" (dig (encOpt encHiding sgm.outOpen) = fw.getD 18 "") "the output endpoint's opening"
    for w in srecs "TAMPER" do
      let nm := w.getD 1 ""
      let diff := w.getD 2 ""
      let verdict := " ".intercalate (w.drop 3)
      match applyDiff seg diff with
      | none => s := s.check "SEG-TAMPER" false s!"{nm}: parse"
      | some bytes =>
        let lean := match decodeSegment sgeo sb sst bytes with
          | .ok (_, e) => s!"OK {hexOf e.toList}"
          | .error e => s!"ERR {e}"
        s := s.check "SEG-TAMPER" (lean = verdict) s!"{nm}: Lean {lean} / Rust {verdict}"
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"CheckR13Block: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)

end ZK60.Exec.Block.CheckR13

def main (args : List String) : IO UInt32 := ZK60.Exec.Block.CheckR13.main args
