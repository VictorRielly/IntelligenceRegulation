/-
D63 lane L10 (2026-11-07): **the agreement check of the executable opening and `M` verifiers against a REAL W16R2
block receipt.**

Run (through the zk60 resource guard; `results/zk60_lean_l10_20261107/check_l10.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/ExecOpeningCheck.lean <corpus>

The corpus is written by the TEST-ONLY Rust export `hashline/src/lean_l10_export_tests.rs`: the W16R2 development
rung's block core (`W16R2_RUNG_H24`, public synthetic data), proved by the crate, then its verifier body replayed step
by step; for `M` (`zk::mask_verify_tagged`) and for `A` and `H` (`pcs::verify_zk_tagged`) the transcript before the
opening, the functionals or claims the verifier computed, the opening, the crate's verdict and the transcript after;
honest and tampered. For every record this checker runs the Lean verifier (`maskVerify`, `pcsVerify` with W16R2's
column evaluator `colEncLag` at the coset points `cosetPt (rootFp 15)`, the SAME definitions the theorems are about)
and requires the same verdict, on acceptance the same transcript state and counter after the call, and on refusal a
refusal of the same kind (the crate's message names it). It also checks that `rootFp k` is the crate's NTT root of
order `2^k` for `k = 9, 12, 14, 15`. It prints `L10Check: N checks, F failed` and exits nonzero on any failure. Not
imported by the library root (it defines `main`).
-/
import ZK60Formal.ExecOpeningM

namespace ZK60.Exec.L10

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

def parseCol (ws : List String) : Option OCol :=
  match ws with
  | [j, col, salt, path] => do pure (← j.toNat?, ← parseFpCsv col, ← parseDig salt, ← parseDigCsv path)
  | _ => none

/-! ## Records -/

structure MRec where
  name : String
  S : ℕ
  root : Dig
  ok : Bool
  err : String
  before : Tr
  fs : List MaskFunctional
  op : MaskOpening
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
  claims : List ZClaim
  op : OpeningZk
  after : Option Tr

inductive Rec
  | root (k : ℕ) (w : Fp)
  | tag (t : MTag) (trKey : Option Dig)
  | m (r : MRec)
  | p (r : PRec)
  | other

/-- Read lines `L10ERR?`, `L10TR` after a record's header. -/
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

/-- Lines starting with `pre`, parsed by `f`, until the first other line. -/
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

/-- A functional: `L10F value nterms`, then its `L10T slot weights` lines. -/
partial def takeFunctionals : List String → Option (List MaskFunctional × List String)
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

partial def takeClaims : List String → Option (List ZClaim × List String)
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
    | [_, n, s, r, v] => do pure (n, ← s.toNat?, ← parseDig r, v = "1")
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
        ← parseDig r, v = "1")
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

partial def parseAll : List String → Except String (List Rec)
  | [] => .ok []
  | l :: rest =>
    let ws := words l
    match ws with
    | "L10ROOT" :: k :: w :: _ =>
      match k.toNat?, w.toNat? with
      | some k, some w => do pure (.root k (fpOf w) :: (← parseAll rest))
      | _, _ => .error s!"bad root line: {l}"
    | ["L10TAG", c, lf, nd, trk] =>
      match parseOptDig c, parseOptDig lf, parseOptDig nd, parseOptDig trk with
      | some c, some lf, some nd, some trk => do pure (.tag ⟨c, lf, nd⟩ trk :: (← parseAll rest))
      | _, _, _, _ => .error "bad tag line"
    | "L10M" :: _ =>
      match parseM ws rest with
      | some (r, rest') => do pure (.m r :: (← parseAll rest'))
      | none => .error s!"bad M record at: {l.take 80}"
    | "L10PCS" :: _ =>
      match parseP ws rest with
      | some (r, rest') => do pure (.p r :: (← parseAll rest'))
      | none => .error s!"bad PCS record at: {l.take 80}"
    | _ => do pure (.other :: (← parseAll rest))

/-! ## Checking -/

/-- The kind of a refusal, as the crate's message names it. -/
def mErrMatches (e : MErr) (msg : String) : Bool :=
  let has (s : String) : Bool := (msg.splitOn s).length > 1
  match e with
  | .qLen => has "q length"
  | .sum => has "product polynomial's sum"
  | .proxLen => has "prox length"
  | .indices => false
  | .nCols => has "column count"
  | .colIndex _ => has "column index"
  | .colLen _ => has "column length"
  | .pathLen _ => has "deep"
  | .merkle _ => has "Merkle path for column" && has "fails"
  | .product _ => has "disagrees with the product polynomial"
  | .prox _ => has "disagrees with the proximity vector"

def pErrMatches (e : PcsErr) (msg : String) : Bool :=
  let has (s : String) : Bool := (msg.splitOn s).length > 1
  match e with
  | .logCols => has "log_cols mismatch"
  | .fewPads => has "fewer pads"
  | .pathLen _ => has "carries a Merkle path"
  | .nGroups => has "group vectors for"
  | .vecLen _ => has "has length"
  | .claim _ => has "!= combined claim"
  | .proxLen => has "prox vector length"
  | .indices => false
  | .nCols => has "wrong number of columns"
  | .colIndex _ _ => has "column index"
  | .colLen => has "column length"
  | .merkle _ => has "Merkle path for column"
  | .colVec _ _ => has "disagrees with clear vector"

structure Tally where
  checks : ℕ := 0
  failed : ℕ := 0
  log : List String := []

def Tally.add (t : Tally) (ok : Bool) (what : String) : Tally :=
  { checks := t.checks + 1, failed := t.failed + (if ok then 0 else 1),
    log := if ok then t.log else s!"FAIL {what}" :: t.log }

def sameTr (a b : Tr) : Bool := a.state == b.state && a.counter == b.counter

def checkM (tag : MTag) (r : MRec) : Bool × String :=
  match maskVerify blake3H tag (rootFp 9) (rootFp 12) r.root r.S r.fs r.op r.before with
  | .ok t' =>
    match r.ok, r.after with
    | true, some a => (sameTr t' a, s!"{r.name}: accepted, state {if sameTr t' a then "equal" else "DIFFERS"}")
    | _, _ => (false, s!"{r.name}: Lean accepted, the crate refused ({r.err})")
  | .error e => (!r.ok && mErrMatches e r.err, s!"{r.name}: Lean refused {repr e}, the crate: {r.err}")

def checkP (tag : MTag) (r : PRec) : Bool × String :=
  let ev := colEncLag (rootFp r.prm.logCols) (2 ^ r.prm.logCols) r.prm.qPad
  let pt := cosetPt (rootFp (r.prm.logCols + Nat.log2 r.prm.invRate))
  match pcsVerify blake3H tag r.prm pt ev r.root r.rows r.cmLogCols r.claims r.op r.before with
  | .ok t' =>
    match r.ok, r.after with
    | true, some a => (sameTr t' a, s!"{r.name}: accepted, state {if sameTr t' a then "equal" else "DIFFERS"}")
    | _, _ => (false, s!"{r.name}: Lean accepted, the crate refused ({r.err})")
  | .error e => (!r.ok && pErrMatches e r.err, s!"{r.name}: Lean refused {repr e}, the crate: {r.err}")

def main (args : List String) : IO UInt32 := do
  let path := args.headD "corpus.txt"
  let text ← IO.FS.readFile path
  let lines := text.splitOn "\n"
  match parseAll lines with
  | .error e =>
    IO.println s!"L10Check: parse error: {e}"
    return 2
  | .ok recs =>
    let mut tally : Tally := {}
    let mut tag : MTag := MTag.legacy
    for r in recs do
      match r with
      | .root k w =>
        let ok := rootFp k == w
        tally := tally.add ok s!"root {k}"
        IO.println s!"root 2^{k}: {if ok then "equal" else "DIFFERS"}"
      | .tag t _ => tag := t
      | .m mr =>
        let start ← IO.monoMsNow
        let (ok, msg) := checkM tag mr
        tally := tally.add ok msg
        IO.println s!"M {msg} [{if ok then "ok" else "FAIL"}] ({(← IO.monoMsNow) - start} ms)"
      | .p pr =>
        let start ← IO.monoMsNow
        let (ok, msg) := checkP tag pr
        tally := tally.add ok msg
        IO.println s!"PCS {msg} [{if ok then "ok" else "FAIL"}] ({(← IO.monoMsNow) - start} ms)"
      | .other => pure ()
    for l in tally.log.reverse do
      IO.println l
    IO.println s!"L10Check: {tally.checks} checks, {tally.failed} failed"
    return (if tally.failed = 0 then 0 else 1)

end ZK60.Exec.L10

def main (args : List String) : IO UInt32 := ZK60.Exec.L10.main args
