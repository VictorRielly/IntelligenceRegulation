/-
D63 Lean lane L17 (2026-11-07): **the R13 adapter of L10's opening check**, on a REAL R13 block receipt.

The corpus (written OUTSIDE the repository: it is large; its sha256 is in `results/zk60_lean_l17_20261107/
large_files.sha256`) is written by the TEST-ONLY Rust export `hashline/src/private_block/lean_l17_export_tests.rs`
(`lean_l17_export_r13_openings`) in L10's format, from the R13 development rung's block core (rate 1/4, `Q = 256`,
`N = 2^16`), proved by the crate, its verifier body replayed step by step: for `M`, `A`, `H` and `check_opening`, the
transcript before, the functionals or claims, the opening, the crate's verdict and transcript after; honest and
tampered. This file is L10's `ExecOpeningCheck.lean` with R13's field: `A` and `H` are checked by `OpeningR13.lean`'s
`pcsFieldR13` (`pcsVerify` at R13's parameters, the coset `7·G_{2^16}`), the parameters required to be R13's, the
transcript contract `pcsTranscript` at `Q = 256`, `nn = 2^16`; `M` by L10's `maskField` (profile-independent) and
`check_opening` by L10's `checkField` (row width `2^14`). Prints `CheckR13Open: N checks, F failed`; nonzero exit on a
failure. Not imported by the library root (it defines `main`).
-/
import ZK60Formal.OpeningR13

namespace ZK60.Exec.L17Open

open ZK60.Circuit (gP GF)

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

def parseHex (s : String) : Option (List UInt8) := if s = "-" then some [] else hexPairs s.toList

def parseDig (s : String) : Option Dig := parseHex s >>= digOf?

def parseOptDig (s : String) : Option (Option Dig) := if s = "-" then some none else (parseDig s).map some

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def parseNatCsv (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def parseFpCsv (s : String) : Option (List Fp) :=
  if s = "-" then some [] else (s.splitOn ",").mapM (fun t => t.toNat?.map fpOf)

def parseFp2 (s : String) : Option Fp2 :=
  match s.splitOn ":" with
  | [a, b] => do pure ⟨fpOf (← a.toNat?), fpOf (← b.toNat?)⟩
  | _ => none

def parseFp2Csv (s : String) : Option (List Fp2) := if s = "-" then some [] else (s.splitOn ",").mapM parseFp2

def parseDigCsv (s : String) : Option (List Dig) := if s = "-" then some [] else (s.splitOn ",").mapM parseDig

def words (l : String) : List String := (l.splitOn " ").filter (· ≠ "")

def parseTr (ws : List String) : Option Tr :=
  match ws with
  | [st, ctr, k] => do pure ⟨← parseDig st, UInt64.ofNat (← ctr.toNat?), ← parseOptDig k⟩
  | _ => none

def parseCol (ws : List String) : Option Block.Column :=
  match ws with
  | [j, col, salt, path] => do pure ⟨← j.toNat?, ← parseFpCsv col, ← parseDig salt, ← parseDigCsv path⟩
  | _ => none

/-! ## Records -/

structure MRec where
  name : String
  S : ℕ
  root : Dig
  ok : Bool
  err : String
  before : Tr
  fs : List Block.MaskFunctional
  op : Block.MaskOpening
  after : Option Tr

structure PRec where
  name : String
  prm : PcsPrm
  rows : ℕ
  cmLogCols : ℕ
  root : Dig
  ok : Bool
  err : String
  before : Tr
  claims : List Block.ZClaim
  op : Block.OpeningZk
  after : Option Tr

structure CRec where
  name : String
  logN : ℕ
  geom : OpenGeom
  ok : Bool
  err : String
  before : Tr
  claims : List Block.ZClaim

inductive Rec
  | root (k : ℕ) (w : Fp)
  | tag (t : MTag)
  | m (r : MRec)
  | p (r : PRec)
  | c (r : CRec)
  | other

def takeErrTr (ls : List String) : Option (String × Tr × List String) :=
  match ls with
  | l :: rest =>
    if l.startsWith "L10ERR " then
      match rest with
      | l2 :: rest2 => do
        let t ← parseTr ((words l2).drop 1)
        pure ((l.drop 7).toString, t, rest2)
      | [] => none
    else do
      let t ← parseTr ((words l).drop 1)
      pure ("", t, rest)
  | [] => none

partial def takeMany {α : Type} (pre : String) (f : List String → Option α) : List String → Option (List α × List String)
  | l :: rest =>
    if l.startsWith pre then do
      let a ← f (words l)
      let r ← takeMany pre f rest
      pure (a :: r.1, r.2)
    else some ([], l :: rest)
  | [] => some ([], [])

def parseEnd (l : String) : Option (Option Tr) :=
  let ws := (words l).drop 1
  if ws = ["-"] then some none else (parseTr ws).map some

partial def takeFunctionals : List String → Option (List Block.MaskFunctional × List String)
  | l :: rest =>
    if l.startsWith "L10F " then
      match words l with
      | [_, v, nt] => do
        let value ← parseFp2 v
        let k ← nt.toNat?
        let terms ← (rest.take k).mapM (fun t => match words t with
          | [_, s, w] => do pure (← s.toNat?, ← parseFp2Csv w)
          | _ => none)
        let r ← takeFunctionals (rest.drop k)
        pure (⟨terms, value⟩ :: r.1, r.2)
      | _ => none
    else some ([], l :: rest)
  | [] => some ([], [])

partial def takeClaims : List String → Option (List Block.ZClaim × List String)
  | l :: rest =>
    if l.startsWith "L10CLAIM " then
      match words l with
      | [_, v, np] => do
        let value ← parseFp2 v
        let k ← np.toNat?
        let parts ← (rest.take k).mapM (fun t => match words t with
          | [_, off, ls, c, pt] => do pure ⟨← off.toNat?, ← ls.toNat?, ← parseFp2 c, ← parseFp2Csv pt⟩
          | _ => none)
        let r ← takeClaims (rest.drop k)
        pure (⟨parts, value⟩ :: r.1, r.2)
      | _ => none
    else some ([], l :: rest)
  | [] => some ([], [])

def parseM (hdr : List String) (ls : List String) : Option (MRec × List String) := do
  let (name, S, root, ok) ← match hdr with
    | [_, n, s, r, v] => do pure (n, ← s.toNat?, ← parseDig r, v == "1")
    | _ => none
  let (err, before, ls) ← takeErrTr ls
  let (fs, ls) ← takeFunctionals ls
  let (q, ls) ← match ls with
    | l :: r => do pure (← parseFp2Csv ((words l).getD 1 "-"), r)
    | [] => none
  let (prox, ls) ← match ls with
    | l :: r => do pure (← parseFp2Csv ((words l).getD 1 "-"), r)
    | [] => none
  let (cols, ls) ← takeMany "L10C " (fun ws => parseCol (ws.drop 1)) ls
  match ls with
  | l :: r => do pure (⟨name, S, root, ok, err, before, fs, ⟨q, prox, cols⟩, ← parseEnd l⟩, r)
  | [] => none

def parseP (hdr : List String) (ls : List String) : Option (PRec × List String) := do
  let (name, prm, rows, cml, root, ok) ← match hdr with
    | [_, n, lc, ir, nq, qp, rw, cl, r, v] =>
      do pure (n, (⟨← lc.toNat?, ← ir.toNat?, ← nq.toNat?, ← qp.toNat?⟩ : PcsPrm), ← rw.toNat?, ← cl.toNat?,
        ← parseDig r, v == "1")
    | _ => none
  let (err, before, ls) ← takeErrTr ls
  let (claims, ls) ← takeClaims ls
  let (gvs, ls) ← takeMany "L10G " (fun ws => parseFp2Csv (ws.getD 1 "-")) ls
  let (prox, ls) ← match ls with
    | l :: r => do pure (← parseFp2Csv ((words l).getD 1 "-"), r)
    | [] => none
  let (cols, ls) ← takeMany "L10C " (fun ws => parseCol (ws.drop 1)) ls
  match ls with
  | l :: r => do pure (⟨name, prm, rows, cml, root, ok, err, before, claims, ⟨gvs, prox, cols⟩, ← parseEnd l⟩, r)
  | [] => none

def parseC (hdr : List String) (ls : List String) : Option (CRec × List String) := do
  let (name, logN, g, ok) ← match hdr with
    | [_, n, ln, rw, sites, sums, px, gr, v] => do
      let sr ← parseNatCsv sums
      let sumRows : Option (ℕ × ℕ) := match sr with
        | [a, b] => some (a, b)
        | _ => none
      pure (n, ← ln.toNat?, (⟨← rw.toNat?, ← parseNatCsv sites, sumRows, ← px.toNat?, ← gr.toNat?⟩ : OpenGeom),
        v == "1")
    | _ => none
  let (err, before, ls) ← takeErrTr ls
  let (claims, ls) ← takeClaims ls
  match ls with
  | _ :: r => pure (⟨name, logN, g, ok, err, before, claims⟩, r)
  | [] => none

partial def parseAll : List String → Except String (List Rec)
  | [] => .ok []
  | l :: rest =>
    let ws := words l
    match ws with
    | "L10ROOT" :: k :: w :: _ =>
      match k.toNat?, w.toNat? with
      | some k, some w => do pure (.root k (fpOf w) :: (← parseAll rest))
      | _, _ => .error s!"bad root line: {l}"
    | ["L10TAG", c, lf, nd, _] =>
      match parseOptDig c, parseOptDig lf, parseOptDig nd with
      | some c, some lf, some nd => do pure (.tag ⟨c, lf, nd⟩ :: (← parseAll rest))
      | _, _, _ => .error "bad tag line"
    | "L10M" :: _ =>
      match parseM ws rest with
      | some (r, rest') => do pure (.m r :: (← parseAll rest'))
      | none => .error s!"bad M record at: {l.take 80}"
    | "L10PCS" :: _ =>
      match parseP ws rest with
      | some (r, rest') => do pure (.p r :: (← parseAll rest'))
      | none => .error s!"bad PCS record at: {l.take 80}"
    | "L10CHK" :: _ =>
      match parseC ws rest with
      | some (r, rest') => do pure (.c r :: (← parseAll rest'))
      | none => .error s!"bad check record at: {l.take 80}"
    | _ => do pure (.other :: (← parseAll rest))

/-! ## Checking -/

structure Tally where
  checks : ℕ := 0
  failed : ℕ := 0
  log : List String := []

def Tally.add (t : Tally) (ok : Bool) (what : String) : Tally :=
  { checks := t.checks + 1, failed := t.failed + (if ok then 0 else 1),
    log := if ok then t.log else s!"FAIL {what}" :: t.log }

def sameTr (a b : Tr) : Bool := a.state == b.state && a.counter == b.counter

def verdict (name : String) (ok : Bool) (err : String) (after : Option Tr) : Except String Tr → Bool × String
  | .ok t' =>
    match ok, after with
    | true, some a => (sameTr t' a, s!"{name}: accepted, transcript {if sameTr t' a then "equal" else "DIFFERS"}")
    | _, _ => (false, s!"{name}: Lean accepted, the crate refused ({err})")
  | .error e => (!ok && e == err, s!"{name}: Lean refused ({e}), the crate: {if ok then "accepted" else err}")

def checkM (tag : MTag) (r : MRec) : Bool × String :=
  verdict r.name r.ok r.err r.after (maskField tag r.S blake3H r.root r.fs r.op r.before)

def checkMContract (r : MRec) : Bool × String :=
  match Block.maskTranscript blake3H r.S mQ mDom r.op r.before, r.after with
  | .ok (_, _, _, t'), some a => (sameTr t' a, s!"{r.name}: L9's maskTranscript ends where the crate's verifier does")
  | _, _ => (false, s!"{r.name}: L9's maskTranscript refused an honest opening")

def checkP (tag : MTag) (r : PRec) : Bool × String :=
  verdict r.name r.ok r.err r.after (R13.pcsFieldR13 tag (fun _ => r.rows) blake3H .a r.root r.claims r.op r.before)

/-- The record's PCS parameters are R13's (the field fixes them). -/
def checkPrm (r : PRec) : Bool × String :=
  (r.prm.logCols == 14 && r.prm.invRate == 4 && r.prm.nQ == 256 && r.prm.qPad == 256 && r.cmLogCols == 14,
    s!"{r.name}: the crate's parameters are R13's (log_cols 14, rate 1/4, 256 columns, 256 pads)")

def checkPContract (r : PRec) : Bool × String :=
  let counts := (groupZclaims (r.claims.map toZClaim) r.rows 14).map (·.2.length)
  match Block.pcsTranscript blake3H counts r.rows R13.r13Prm.nQ R13.r13Prm.nn r.op r.before, r.after with
  | .ok (_, _, _, t'), some a => (sameTr t' a, s!"{r.name}: L9's pcsTranscript ends where the crate's verifier does")
  | _, _ => (false, s!"{r.name}: L9's pcsTranscript refused an honest opening")

def checkC (r : CRec) : Bool × String :=
  match (if r.logN = 14 then checkField (fun _ => r.geom) blake3H .a r.claims r.before
         else .error s!"the record's row width is 2^{r.logN}, not R13's 2^14") with
  | .ok () => (r.ok, s!"{r.name}: Lean's check_opening accepts{if r.ok then "" else s!", the crate refused ({r.err})"}")
  | .error e => (!r.ok && e == r.err, s!"{r.name}: Lean refused ({e}), the crate: {if r.ok then "accepted" else r.err}")

def main (args : List String) : IO UInt32 := do
  let path := args.headD "corpus.txt"
  let text ← IO.FS.readFile path
  let lines := text.splitOn "\n"
  match parseAll lines with
  | .error e =>
    IO.println s!"CheckR13Open: parse error: {e}"
    return 2
  | .ok recs =>
    let mut tally : Tally := {}
    let mut tag : MTag := MTag.legacy
    for r in recs do
      let start ← IO.monoMsNow
      match r with
      | .root k w =>
        let ok := rootFp k == w
        tally := tally.add ok s!"root {k}"
        IO.println s!"root 2^{k}: {if ok then "equal" else "DIFFERS"}"
      | .tag t => tag := t
      | .m mr =>
        let (ok, msg) := checkM tag mr
        tally := tally.add ok msg
        IO.println s!"M {msg} [{if ok then "ok" else "FAIL"}] ({(← IO.monoMsNow) - start} ms)"
        if mr.ok then
          let (ok2, msg2) := checkMContract mr
          tally := tally.add ok2 msg2
          IO.println s!"M {msg2} [{if ok2 then "ok" else "FAIL"}]"
      | .p pr =>
        let (ok0, msg0) := checkPrm pr
        tally := tally.add ok0 msg0
        let (ok, msg) := checkP tag pr
        tally := tally.add ok msg
        IO.println s!"PCS {msg} [{if ok && ok0 then "ok" else "FAIL"}] ({(← IO.monoMsNow) - start} ms)"
        if pr.ok then
          let (ok2, msg2) := checkPContract pr
          tally := tally.add ok2 msg2
          IO.println s!"PCS {msg2} [{if ok2 then "ok" else "FAIL"}]"
      | .c cr =>
        let (ok, msg) := checkC cr
        tally := tally.add ok msg
        IO.println s!"CHECK {msg} [{if ok then "ok" else "FAIL"}] ({(← IO.monoMsNow) - start} ms)"
      | .other => pure ()
    for l in tally.log.reverse do
      IO.println l
    IO.println s!"CheckR13Open: {tally.checks} checks, {tally.failed} failed"
    return (if tally.failed = 0 then 0 else 1)

end ZK60.Exec.L17Open

def main (args : List String) : IO UInt32 := ZK60.Exec.L17Open.main args
