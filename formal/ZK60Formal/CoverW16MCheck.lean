/-
D63 lane L23 (2026-11-07): **the agreement check of `M`'s functionals, WEIGHTS and values, against a REAL W16R2
receipt** (finding L23-1: L9's and L17's agreement checks count the functionals but never compare their weights, so a
wrong weight vector in `ExecBlockVerify.slotAcc` went unseen).

The receipt is the W16R2 development rung's block (`hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2`), the SAME
receipt in two committed exports: L9's corpus (`results/zk60_lean_l9_20261107/corpus.txt` with its frame, the core the
Lean block verifier runs on) and L10's corpus (`corpus_w16r2.txt`, outside the repository, its sha256 in
`results/zk60_lean_l10_20261107/corpus.sha256`), whose honest `M` record lists the functionals the CODE's verifier
handed to `zk::mask_verify_tagged` (`acc.fs ++ acc.host_fs`, argument.rs:1478-1502). The two exports share the `M` root
(checked).

This checker runs L9's executable block verifier (`blockSlots`, with `ExecBlockCheck`'s stand-in parameters: the
corpus's geometry, kinds and hosted lists; `slotAcc` is the model's, unchanged) on the decoded core, and compares its
`acc.fs ++ acc.hostFs` with the code's list: the count, every term's slot and EVERY weight word, and the value of every
`Γ` functional (an evaluation functional's value `g` needs the slot polynomial, which the stand-in does not carry; its
weights `eval_weights(ρ, d)` are compared). As a negative control it also forms the host functionals with the HOST's sum
weights for the hosted slots (the model before L23-1's fix) and requires each of them to differ from the code's.

Run (through the zk60 resource guard, `results/zk60_lean_l23_20261107/check_l23.sh`), with the stack raised as for
`ExecBlockCheck`:
  L23_L9_CORPUS=<L9 corpus> L23_L9_FRAME=<frame> L23_L10_CORPUS=<L10 corpus> lake -d formal env lean <this file>
It prints `MFunCheck: N checks, F failed` and fails (an error of the `#eval`) on any failure. Not imported by the library
root (it imports `ExecBlockCheck`, which defines `main`).
-/
import ZK60Formal.ExecBlockCheck
import ZK60Formal.CoverW16Unmask

namespace ZK60.Exec.Block.MCheck

open ZK60.Exec.Block
open ZK60.Exec.Block.Check

/-- A record's words. -/
def wordsOf (l : String) : List String := (l.splitOn " ").filter (· ≠ "")

/-- `a:b`, L10's `Fp2` word. -/
def pC (s : String) : Option Fp2 :=
  match s.splitOn ":" with
  | [a, b] => do pure ⟨fpOf (← a.toNat?), fpOf (← b.toNat?)⟩
  | _ => none

def pCs (s : String) : Option (List Fp2) := if s = "-" then some [] else (s.splitOn ",").mapM pC

/-- L10's functionals: `L10F value nterms`, then `nterms` lines `L10T slot weights`. -/
partial def takeFs : List String → List MaskFunctional
  | l :: rest =>
    match wordsOf l with
    | ["L10F", v, nt] =>
      match pC v, nt.toNat? with
      | some value, some k =>
        let terms := (rest.take k).filterMap fun t => match wordsOf t with
          | [_, s, w] => do pure ((← s.toNat?), (← pCs w))
          | _ => none
        ⟨terms, value⟩ :: takeFs (rest.drop k)
      | _, _ => []
    | _ => []
  | [] => []

/-- The code's functionals of the honest `M` record (the line after its header is the transcript). -/
def codeFs (lines : List String) : Option (String × List MaskFunctional) :=
  match lines.dropWhile (fun l => !(l.startsWith "L10M m-honest ")) with
  | hdr :: _tr :: rest => some ((wordsOf hdr).getD 3 "", takeFs rest)
  | _ => none

/-- A host functional with the HOST's sum weights on its hosted terms (the model before L23-1's fix): every term
re-weighted by the first term's slot shape, with its own scale `w[1]` (sum weights have `1` at index 1). -/
def hostWeighted (P : BlockParams) (f : MaskFunctional) : MaskFunctional :=
  match f.terms with
  | (s, w) :: hs => ⟨(s, w) :: hs.map (fun t => (t.1, (swk P s).map (fun x => x.mul (t.2.getD 1 Fp2.zero)))), f.value⟩
  | [] => f

def termsEq (a b : List (ℕ × List Fp2)) : Bool := a.length == b.length && (a.zip b).all fun p => p.1.1 == p.2.1 && p.1.2 == p.2.2

def run (cpath fpath lpath : String) : IO UInt32 := do
  let lines ← IO.FS.lines cpath
  let frame := (← IO.FS.readBinFile fpath).toList
  let words : List (List String) := (lines.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))
  let rec1 (k : String) : List String := (words.find? (fun w => w.headD "" = k)).getD []
  let recsOf (k : String) : List (List String) := words.filter (fun w => w.headD "" = k)
  let mut s : St := {}
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
    W16R2.ceiling⟩
  let fr := rec1 "FRAME"
  s := s.check "FRAME" (hexOf (blake3H ⟨none, frame⟩).toList = fr.getD 2 "") "BLAKE3 of the frame"
  let stw := rec1 "START"
  let some st0 := parseDig (stw.getD 1 "") | do IO.println "FAILED parse START"; return 1
  let some key := (if stw.getD 3 "-" = "-" then some none else (parseDig (stw.getD 3 "")).map some) | do
    IO.println "FAILED parse key"; return 1
  let t0 : Tr := ⟨st0, UInt64.ofNat ((stw.getD 2 "").toNat?.getD 0), key⟩
  let tags := rec1 "TAGS"
  let some startTag := parseDig (tags.getD 1 "") | do IO.println "FAILED parse TAGS"; return 1
  let some bindg := parseDig ((rec1 "BINDING").getD 1 "") | do IO.println "FAILED parse BINDING"; return 1
  let llines ← IO.FS.lines lpath
  let some (mroot, cfs) := codeFs llines.toList | do IO.println "FAILED parse the L10 honest M record"; return 1
  match decodeFork g bindg 1 0 startTag frame with
  | .error e => s := s.check "DECODE" false s!"decodeFork refused: {e}"
  | .ok (core, _) =>
    s := s.check "RECEIPT" (hexOf core.maskRoot.toList = mroot) "the two exports carry the same M root"
    let srecs : List SlotRecRow := (recsOf "SLOT").filterMap parseSlotRec
    let pcsRec (nm : String) : List String := ((recsOf "PCS").find? (fun w => w.getD 1 "" = nm)).getD []
    let counts (nm : String) : List ℕ := (parseNats (look (kv ((pcsRec nm).drop 2)) "counts")).getD []
    let P := standIn g logCols (nat "a_rows") (nat "h_rows") (nat "a_prox") (nat "h_prox") q encCols (nat "mask_specs")
      (((rec1 "FUNCTIONALS").getD 1 "").toNat?.getD 0) rows srecs (counts "A") (counts "H")
    match blockSlots H P core t0 with
    | .error e => s := s.check "SLOTS" false s!"blockSlots refused: {e}"
    | .ok (_, _, acc, _) =>
      let lfs := acc.fs ++ acc.hostFs
      s := s.check "COUNT" (lfs.length = cfs.length) s!"{lfs.length} Lean functionals, {cfs.length} code functionals"
      let mut i := 0
      for (lf, cf) in lfs.zip cfs do
        s := s.check "TERMS" (termsEq lf.terms cf.terms) s!"functional {i}: slots and weights"
        let isEval := lf.terms.length == 1 && ((lf.terms.headD (0, [])).2.headD Fp2.zero) == Fp2.one
        if !isEval then
          s := s.check "VALUE" (lf.value == cf.value) s!"functional {i}: value"
        i := i + 1
      -- the negative control: the host functionals with the host's weights on the hosted terms
      let hostCode := cfs.drop acc.fs.length
      for (lf, cf) in acc.hostFs.zip hostCode do
        s := s.check "NEG-HOST-WEIGHTS" (!(termsEq (hostWeighted P lf).terms cf.terms))
          s!"the host's own weights on the hosted terms differ from the code's (slot {(lf.terms.headD (0, [])).1})"
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"MFunCheck: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)

end ZK60.Exec.Block.MCheck

#eval show IO Unit from do
  let c := (← IO.getEnv "L23_L9_CORPUS").getD "results/zk60_lean_l9_20261107/corpus.txt"
  let f := (← IO.getEnv "L23_L9_FRAME").getD "results/zk60_lean_l9_20261107/fork_frame.bin"
  let l := (← IO.getEnv "L23_L10_CORPUS").getD "corpus_w16r2.txt"
  let r ← ZK60.Exec.Block.MCheck.run c f l
  if r ≠ 0 then throw (IO.userError "MFunCheck failed")
