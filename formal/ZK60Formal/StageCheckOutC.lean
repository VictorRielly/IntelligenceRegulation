/-
D63, Lean lane L15 (2026-11-07): **the agreement check of stage OUT-C's verifier arithmetic against a REAL classifier
receipt.**

Run (through the zk60 resource guard; `results/zk60_lean_l15_20261107/check_l15.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/StageCheckOutC.lean results/zk60_lean_l15_20261107/corpus.txt

The corpus is written by `hashline/src/private_block/token_io/lean_l15_export_tests.rs` (test only) from an honest
classifier run on the development rung that the production `verify_classify_run` accepts with the run capture's
recorder attached: the profile facts, the margin vector, stage OUT-C's LogUp challenges and its eight slot records.
With the executable closures and public tables of `StageCheckDefs.lean` this file checks, per slot:
* `schedule`: the slot's kind, `main`, extension rounds and declared degree are stage OUT-C's (`layout`,
  stage_out_c.rs:75-87), computed from the profile's domain logs;
* `draws`: the definition draws as many challenges as `define` does (`τ`, `μ`, `ν`, `ζ`);
* `tables`: the slot's tables are the code's list (kinds in order), and as many terminals as private tables;
* `eq-point`: every `eq` table is at `τ` (the slot's first draws) from coordinate 0;
* `public-len`: every public table has the length of the Lean table built from the profile;
* `hosted`: the hosted slot and coefficient are the code's (TZC hosts SS with `ν = draws[5]`, LZC hosts PD with
  `ν = draws[llo + 2]`);
* `claimed`: the claimed sum is the scalar plus the hosted scalars times their coefficients;
* `sumcheck`: the rounds' arithmetic on the recorded challenges, from Lean's claimed sum, ends at the recorded final value;
* `verify-arm`: Lean's terminal values (`sel·eq(τ, ρ)`, `sel·mle(pub)(ρ)` of LEAN's public tables, the masked terminals)
  through Lean's closure give the Rust verifier's `poly(vals)` (the recorded `fin − c·g`), and `(fin − poly)·c⁻¹` is
  the recorded mask value `g`;
and for the stage: `slot-count` (eight slots) and `logup` (two challenges, `γ` and `α`).
It prints the checks per kind and `StageCheckOutC: N checks, F failed`, and exits nonzero on any failure. Not imported
by the library root (it defines `main`).
-/
import Lean.Data.Json
import ZK60Formal.StageCheckDefs

namespace ZK60.Exec.StageCheckOutC

open Lean (Json)
open ZK60.Exec ZK60.Exec.StageCheck

/-! ## Parsing -/

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def f2 (a b : ℕ) : Fp2 := ⟨fpOf a, fpOf b⟩

def jget (j : Json) (k : String) : Option Json := (j.getObjVal? k).toOption

def jnat (j : Json) (k : String) : Option ℕ := jget j k >>= fun x => x.getNat?.toOption

def jstr (j : Json) (k : String) : Option String := jget j k >>= fun x => x.getStr?.toOption

def jarr (j : Json) : Option (List Json) := (j.getArr?.toOption).map Array.toList

def jfp2 (j : Json) : Option Fp2 := do
  match ← jarr j with
  | [a, b] => pure (f2 (← a.getNat?.toOption) (← b.getNat?.toOption))
  | _ => none

def jfp2s (j : Json) : Option (List Fp2) := jarr j >>= fun l => l.mapM jfp2

def jfp2k (j : Json) (k : String) : Option Fp2 := jget j k >>= jfp2

def jfp2sk (j : Json) (k : String) : Option (List Fp2) := jget j k >>= jfp2s

/-- A table of the record: `eq` (start, point), `public` (len), `private`. -/
inductive TabJ
  | eq (start : ℕ) (point : List Fp2)
  | pub (len : ℕ)
  | priv

def jtab (j : Json) : Option TabJ := do
  match ← jstr j "kind" with
  | "eq" => pure (.eq (← jnat j "start") (← jfp2sk j "point"))
  | "public" => pure (.pub (← jnat j "len"))
  | "private" => pure .priv
  | _ => none

/-- One slot record (`run_capture::stage_slot`). -/
structure SlotJ where
  slot : ℕ
  kind : String
  main : ℕ
  ext : ℕ
  degree : ℕ
  draws : List Fp2
  c : Fp2
  scalar : Fp2
  claimed : Fp2
  rho : List Fp2
  fin : Fp2
  gval : Fp2
  tpoly : Fp2
  terms : List Fp2
  rounds : List (List Fp2)
  hosted : List (ℕ × Fp2)
  tabs : List TabJ

def jslot (j : Json) : Option SlotJ := do
  let hosted ← (jget j "hosted" >>= jarr) >>= fun l => l.mapM fun h => do
    pure ((← jnat h "slot"), (← jfp2k h "coefficient"))
  let rounds ← (jget j "rounds" >>= jarr) >>= fun l => l.mapM jfp2s
  let tabs ← (jget j "tables" >>= jarr) >>= fun l => l.mapM jtab
  pure { slot := ← jnat j "slot", kind := ← jstr j "kind", main := ← jnat j "main", ext := ← jnat j "extension",
         degree := ← jnat j "degree", draws := ← jfp2sk j "definition_challenges", c := ← jfp2k j "c",
         scalar := ← jfp2k j "scalar", claimed := ← jfp2k j "claimed_sum", rho := ← jfp2sk j "rho",
         fin := ← jfp2k j "sumcheck_final", gval := ← jfp2k j "mask_eval", tpoly := ← jfp2k j "terminal_polynomial",
         terms := ← jfp2sk j "terminals", rounds := rounds, hosted := hosted, tabs := tabs }

/-- The profile facts (`PROFILE k=v ...`). -/
structure Prof where
  d : ℕ
  dpad : ℕ
  lt : ℕ
  llo : ℕ
  ldo : ℕ
  ltab : ℕ
  limbs : ℕ
  lam : ℕ
  verdict : ℕ
  c : ℤ
  ceps : ℤ
  g0 : ℤ
  cn : ℤ
  tn : ℕ
  tag : ℕ

def dropS (s : String) (n : ℕ) : String := String.ofList (s.toList.drop n)

def kv (ws : List String) (k : String) : Option String :=
  (ws.find? (fun w => w.startsWith (k ++ "="))).map (fun w => dropS w (k.length + 1))

def parseProf (ws : List String) : Option Prof := do
  let n := fun k => kv ws k >>= String.toNat?
  let i := fun k => kv ws k >>= String.toInt?
  pure { d := ← n "d", dpad := ← n "dpad", lt := ← n "lt", llo := ← n "llo", ldo := ← n "ldo", ltab := ← n "ltab",
         limbs := ← n "limbs", lam := ← n "lambase", verdict := ← n "verdict", c := ← i "c", ceps := ← i "ceps",
         g0 := ← i "g0", cn := ← i "cn", tn := ← n "tn", tag := ← n "tag" }

/-! ## The code's schedule of stage OUT-C, from the profile -/

/-- `clog2` of a power of two. -/
def lg (x : ℕ) : ℕ := Nat.log2 x

/-- `(kind, main, ext, degree)` of slot `s` (stage_out_c.rs:75-87; `TO_LOG = 1`). -/
def sched (p : Prof) : ℕ → String × ℕ × ℕ × ℕ
  | 0 => ("Standalone", lg p.dpad, 1, 2)
  | 1 => ("Private", p.ldo, 1, 4)
  | 2 => ("Host", 1, 1, 3)
  | 3 => ("Private", lg p.dpad, 1, 2)
  | 4 => ("Host", p.llo, 1, 4)
  | 5 => ("Standalone", p.ldo, 1, 5)
  | 6 => ("Standalone", p.ltab, 1, 3)
  | _ => ("Standalone", p.lt, 1, 2)

/-- The number of challenges each `define` draws. -/
def drawCount (p : Prof) : ℕ → ℕ
  | 0 => lg p.dpad
  | 2 => 1 + 4 + 1 + 1
  | 4 => p.llo + 2 + 1
  | 5 => p.ldo + 10 + 1
  | 6 => p.ltab + 2 + 1
  | _ => 0

/-- The slot's tables, as the code pushes them: `e` an `eq` table, `p` a public one, `a` a private one. -/
def tabShape : ℕ → String
  | 0 => "eaa"
  | 1 => "pa"
  | 2 => "ep" ++ String.ofList (List.replicate 11 'a')
  | 3 => "ap"
  | 4 => "epppaa"
  | 5 => "ep" ++ String.ofList (List.replicate 19 'a')
  | 6 => "eppaa"
  | _ => "pa"

def tabCode : TabJ → Char
  | .eq _ _ => 'e'
  | .pub _ => 'p'
  | .priv => 'a'

/-- The slot's public tables built from the profile (in push order). -/
def pubTabs (p : Prof) (w : List ℤ) (g : Fp2) : ℕ → List (List Fp2)
  | 1 => [supp p.d (2 ^ p.ldo)]
  | 2 => [supp 1 2]
  | 3 => [wTab p.dpad w]
  | 4 => [liveTab (2 ^ p.llo) p.lam p.limbs, gTab (2 ^ p.llo) p.lam p.limbs p.verdict, supp 1 (2 ^ p.llo)]
  | 5 => [supp p.d (2 ^ p.ldo)]
  | 6 => [supp 256 (2 ^ p.ltab), tvTab (2 ^ p.ltab) g]
  | 7 => [List.replicate (2 ^ p.lt) Fp2.one]
  | _ => []

/-- The `τ` of a slot (its first draws). -/
def tauOf (p : Prof) (s : ℕ) (draws : List Fp2) : List Fp2 :=
  match s with
  | 0 => draws.take (lg p.dpad)
  | 2 => draws.take 1
  | 4 => draws.take p.llo
  | 5 => draws.take p.ldo
  | 6 => draws.take p.ltab
  | _ => []

/-- The hosted list the code builds (`b.finish(.., vec![(SOC_SS, nu)])`, `vec![(SOC_PD, nu)]`). -/
def hostedOf (p : Prof) (s : ℕ) (draws : List Fp2) : List (ℕ × Fp2) :=
  match s with
  | 2 => [(1, vg draws 5)]
  | 4 => [(3, vg draws (p.llo + 2))]
  | _ => []

/-- The slot's closure with its draws and the stage's constants. -/
def polyOf (p : Prof) (alpha g : Fp2) (s : ℕ) (draws v : List Fp2) : Fp2 :=
  match s with
  | 0 => ioPoly v
  | 1 => ssPoly v
  | 2 => tzcPoly ((draws.drop 1).take 4) (vg draws 5) (vg draws 6) (kI p.ceps) v
  | 3 => pdPoly v
  | 4 => lzcPoly ((draws.drop p.llo).take 2) (vg draws (p.llo + 2)) alpha g ((kI p.verdict).add (kI p.c)) v
  | 5 => dzcPoly ((draws.drop p.ldo).take 10) (vg draws (p.ldo + 10)) alpha g (kI (2 * p.g0 * p.cn))
      (kI (2 ^ p.tn)) (kI (2 ^ (p.tn + 1))) v
  | 6 => tabPoly ((draws.drop p.ltab).take 2) (vg draws (p.ltab + 2)) alpha v
  | _ => zsPoly v

/-! ## The checker's state -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []

def St.check (s : St) (kind : String) (b : Bool) (what : String) : St :=
  let kinds := match s.kinds.find? (·.1 == kind) with
    | some _ => s.kinds.map (fun e => if e.1 == kind then (e.1, e.2 + 1) else e)
    | none => s.kinds ++ [(kind, 1)]
  if b then { s with ok := s.ok + 1, kinds := kinds }
  else { s with fail := s.fail + 1, kinds := kinds, msgs := s.msgs.push s!"FAILED {kind}: {what}" }

/-- Lean's tables of the slot: the record's kinds, with LEAN's public tables in place of the code's. -/
def leanTabs (pubs : List (List Fp2)) : List TabJ → Option (List TabR)
  | [] => some []
  | .eq start _ :: ts => (leanTabs pubs ts).map (TabR.eq start :: ·)
  | .pub _ :: ts => do
    let v ← pubs.head?
    let rest ← leanTabs pubs.tail ts
    pure (TabR.pub v :: rest)
  | .priv :: ts => (leanTabs pubs ts).map (TabR.priv :: ·)

def checkSlot (p : Prof) (w : List ℤ) (alpha g : Fp2) (scalars : List Fp2) (s : St) (r : SlotJ) : St :=
  let sid := s!"slot {r.slot}"
  let (knd, n, ext, deg) := sched p r.slot
  let s := s.check "schedule" (r.kind == knd && r.main == n && r.ext == ext && r.degree == deg) sid
  let s := s.check "draws" (r.draws.length == drawCount p r.slot) sid
  let shape := String.ofList (r.tabs.map tabCode)
  let nPriv := (r.tabs.filter (fun t => match t with | .priv => true | _ => false)).length
  let s := s.check "tables" (shape == tabShape r.slot && r.terms.length == nPriv) s!"{sid}: {shape}"
  let tau := tauOf p r.slot r.draws
  let s := r.tabs.foldl (fun s t => match t with
    | .eq start pt => s.check "eq-point" (start == 0 && pt == tau) sid
    | _ => s) s
  let pubs := pubTabs p w g r.slot
  let recLens := r.tabs.filterMap (fun t => match t with | .pub len => some len | _ => none)
  let s := (recLens.zip pubs).foldl (fun s e => s.check "public-len" (e.1 == e.2.length) sid) s
  let s := s.check "public-len" (recLens.length == pubs.length) s!"{sid}: public table count"
  let s := s.check "hosted" (r.hosted == hostedOf p r.slot r.draws) sid
  let claimedL := claimedOf r.scalar r.hosted scalars
  let s := s.check "claimed" (r.claimed == claimedL) sid
  let s := s.check "sumcheck" (r.rounds.length == n + ext && r.rho.length == n + ext
    && scArith deg r.rounds r.rho claimedL && scFinalExec r.rounds r.rho claimedL == r.fin) sid
  let rho := r.rho.take n
  let es := r.rho.drop n
  let ok := match leanTabs pubs r.tabs >>= fun lt => stageVals tau rho es r.terms lt 0 with
    | some vals =>
      let pv := polyOf p alpha g r.slot r.draws vals
      pv == r.tpoly && (r.fin.sub pv).mul r.c.inv == r.gval
    | none => false
  s.check "verify-arm" ok sid

end ZK60.Exec.StageCheckOutC

open ZK60.Exec ZK60.Exec.StageCheck ZK60.Exec.StageCheckOutC in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l15_20261107/corpus.txt"
  let txt ← IO.FS.readFile path
  let lines := (txt.splitOn "\n").filter (· ≠ "")
  let word := fun (l : String) => (l.splitOn " ").headD ""
  let rest := fun (l : String) => ((l.splitOn " ").drop 1)
  let some pl := lines.find? (word · == "PROFILE") | do IO.println "no PROFILE line"; return 2
  let some p := parseProf (rest pl) | do IO.println "bad PROFILE line"; return 2
  let some wl := lines.find? (word · == "WDELTA") | do IO.println "no WDELTA line"; return 2
  let some w := ((rest wl).headD "").splitOn "," |>.mapM String.toInt? | do IO.println "bad WDELTA line"; return 2
  let some ll := lines.find? (word · == "LOGUP") | do IO.println "no LOGUP line"; return 2
  let some lj := (Lean.Json.parse (" ".intercalate (rest ll))).toOption | do IO.println "bad LOGUP json"; return 2
  let some logup := jfp2s lj | do IO.println "bad LOGUP values"; return 2
  let slotLines := lines.filter (word · == "SLOT")
  let some recs := slotLines.mapM (fun l => (Lean.Json.parse (" ".intercalate (rest l))).toOption >>= jslot)
    | do IO.println "bad SLOT record"; return 2
  let gamma := vg logup 0
  let alpha := vg logup 1
  let g := gamma.mulBase (Fp.new (UInt64.ofNat p.tag))
  let s : St := {}
  let s := s.check "logup" (logup.length == 2) "two LogUp challenges"
  let s := s.check "slot-count" (recs.length == 8 && (recs.map (·.slot)) == List.range 8) "eight slots in order"
  let (s, _) := recs.foldl (fun (acc : St × List Fp2) r =>
    (checkSlot p w alpha g acc.2 acc.1 r, acc.2 ++ [r.scalar])) (s, [])
  for m in s.msgs do
    IO.println m
  for (k, c) in s.kinds do
    IO.println s!"  {k}: {c}"
  IO.println s!"StageCheckOutC: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)
