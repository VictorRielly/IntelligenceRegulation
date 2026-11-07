/-
D63 Lean lane L17 (2026-11-07): **the R13 adapter of L11's slot-arithmetic check**, on a REAL R13 block receipt.

The corpus (`results/zk60_lean_l17_20261107/slots_corpus.txt`) is written by the TEST-ONLY Rust export
`hashline/src/private_block/lean_l17_export_tests.rs` (`lean_l17_export_r13_slots`) in L11's format, from the R13
development rung's block core (`hashline-zk-mr1/private-block-rung-lh-t32-dev/2`, LOW + h24, byte limbs, rate 1/4),
proved by the production `prove_core` and accepted by `verify_core`. This file is L11's `L11Check.lean` with the R13
slot list: the draws are `SlotR13.lean`'s `R13.draws` (the six R13 zero-checks' batching vectors); everything else
(`sched`, `kindOf`, `hostsOf`, `eqPoints`, `hostedCoefs`, `slotVerifyW`, the IR checks) is L11's, which R13 shares.
It checks, per slot: the slot list (kind, `Shape::slots` from the shape facts, the terminal count), `define`'s draws
replayed as squeezes and their layout (`R13.drawLen`), the hosted coefficients, the claim points of the `eq` tables,
the IR (shape, degree, the host template, every `μ[k]`, `ν[k]`, `ζ^j` equal to the draws), and the verify arm
(`slotVerifyW`) reproducing `c`, the claimed sum, the final value, the challenges, the terminal values, `poly(vals)`,
`g` and the transcript after `pb-term`. One R13 slot has no IR in the code (`SC_TAB`: `IRNONE`, "the R13 table-helper slot
is not transcribed"); its arm is checked with Rust's polynomial value (`verify-arm-noir`, finding L17-9). Prints
`CheckR13Slots: N checks, F failed`; nonzero exit on a failure. Not
imported by the library root (it defines `main`).
-/
import ZK60Formal.SlotR13

namespace ZK60.Exec.L17Slots

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Slot.W16R2

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

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def f2 (a b : ℕ) : Fp2 := ⟨fpOf a, fpOf b⟩

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

/-- `c0:c1:provenance` -/
def pCoef (s : String) : Option (Fp2 × String) :=
  match s.splitOn ":" with
  | a :: b :: rest => do
    let x ← a.toNat?
    let y ← b.toNat?
    pure (f2 x y, ":".intercalate rest)
  | _ => none

/-- `s` without its first `n` characters. -/
def dropS (s : String) (n : ℕ) : String := String.ofList (s.toList.drop n)

def pFactor (s : String) : Option Factor :=
  if s.startsWith "t" then ((dropS s 1).toNat?).map Factor.tab
  else if s.startsWith "n" then ((dropS s 1).toNat?).map Factor.node
  else none

def pFactors (s : String) : Option (List Factor) := if s = "-" then some [] else (s.splitOn ".").mapM pFactor

/-! ## The checker's state -/

/-- One slot's record, filled line by line. -/
structure Rec where
  s : ℕ := 0
  kind : String := ""
  n : ℕ := 0
  ext : ℕ := 0
  deg : ℕ := 0
  npriv : ℕ := 0
  ntabs : ℕ := 0
  draws : List Fp2 := []
  trb : Option (Dig × ℕ) := none
  scalar : Fp2 := Fp2.zero
  hosted : List (ℕ × Fp2) := []
  rounds : List (List Fp2) := []
  terms : List Fp2 := []
  tabs : List TabV := []
  pubv : List (ℕ × Fp2) := []
  hasPubv : Bool := false
  vals : List Fp2 := []
  irT : ℕ := 0
  nodes : List (Body Fp2) := []
  nodeProv : List (List String) := []
  irTerms : List (Term Fp2) := []
  termProv : List String := []
  hasIr : Bool := false
  res : Option (Fp2 × Fp2 × Fp2 × List Fp2 × Fp2 × Fp2) := none
  tra : Option (Dig × ℕ) := none

def Rec.empty : Rec := {}

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []
  key : Option Dig := none
  sh : Option ShapeW := none
  sched : List (ℕ × ℕ × ℕ) := []
  termsDecl : List ℕ := []
  head : Option (Dig × ℕ) := none
  roots : Option (Dig × ℕ × Dig × Dig × ℕ × ℕ) := none
  logup : Option (Fp2 × Fp2 × Fp2) := none
  tags : Option (Fp2 × Fp2 × Fp2) := none
  prev : Option Tr := none
  scalars : List Fp2 := []
  segs : List (List (Seg × List Fp2)) := []
  cur : Rec := {}
  slots : ℕ := 0
  gaps : Array String := #[]

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 40 then s.msgs.push s!"[{kind}] {msg.take 160}" else s.msgs }

def St.bad (s : St) (line : String) : St := s.check "PARSE" false line

def H : HIn → Dig := blake3H

def mkTr (st : Dig) (ctr : ℕ) (key : Option Dig) : Tr := ⟨st, UInt64.ofNat ctr, key⟩

/-! ## The shape line -/

def kv (w : List String) (k : String) : Option String :=
  (w.find? (·.startsWith (k ++ "="))).map fun x => dropS x (k.length + 1)

def domOf (l : List ℕ) (d : Dom) : ℕ := l.getD d.idx 0

def parseShape (w : List String) : Option ShapeW := do
  let g := fun k => (kv w k) >>= String.toNat?
  let lt ← g "lt"
  let lh ← g "lh"
  let ldh ← g "ldh"
  let ld ← g "ld"
  let lf ← g "lf"
  let lq ← g "lq"
  let lkvw ← g "lkvw"
  let lkv ← g "lkv"
  let pr ← g "pad_rule"
  let nr ← g "n_range"
  let perRow ← g "per_row"
  let logs ← (kv w "logs") >>= parseCsvNat
  let pads ← (kv w "pads") >>= parseCsvNat
  let helpers ← (kv w "helpers") >>= parseCsvNat
  let zr ← (kv w "zero_rule") >>= parseCsvNat
  pure { lt := lt, lh := lh, ldh := ldh, ld := ld, lf := lf, lq := lq, lkvw := lkvw, lkv := lkv,
         padRule := pr == 1, nRange := nr, perRow := perRow,
         logs := domOf logs, pads := fun d => domOf pads d == 1, helpers := domOf helpers,
         zeroRule := fun d => domOf zr d == 1 }

/-! ## The per-slot checks -/

def kindCode : Kind → String
  | .priv => "P"
  | .standalone => "S"
  | .host => "H"

/-- The IR's challenge coefficients against the draws: `chal:mu[k]`, `chal:nu[k]`, `chal:zeta^j`. -/
def provValue (segs : List (Seg × List Fp2)) (prov : String) : Option Fp2 :=
  let idx := fun (pre : String) => if prov.startsWith pre then
      (let t := (dropS prov pre.length).toList; (String.ofList (t.take (t.length - 1))).toNat?) else none
  match idx "chal:mu[", idx "chal:nu[" with
  | some k, _ => some ((segOf .mu segs).getD k Fp2.zero)
  | _, some k => some ((segOf .nu segs).getD k Fp2.zero)
  | none, none =>
    if prov.startsWith "chal:zeta^" then
      ((dropS prov 10).toNat?).map fun j =>
        (List.range j).foldl (fun p _ => p.mul ((segOf .zeta segs).getD 0 Fp2.zero)) Fp2.one
    else none

/-- The eq tables, in order. -/
def eqTabs (tabs : List TabV) : List (List Fp2) :=
  tabs.filterMap fun t => match t with
    | .eq _ p => some p
    | _ => none

/-- Every node refers only to earlier nodes and to tables in range. -/
def irWellFormed (ntabs : ℕ) (nodes : List (Body Fp2)) (terms : List (Term Fp2)) : Bool :=
  let fok := fun (upto : ℕ) (f : Factor) => match f with
    | .tab i => decide (i < ntabs)
    | .node i => decide (i < upto)
  let nodeOk := (List.range nodes.length).all fun i => match nodes.getD i (.sum []) with
    | .affine _ ts => ts.all fun p => decide (p.2 < ntabs)
    | .sum ss => ss.all fun s => s.factors.all (fok i)
  nodeOk && terms.all fun t => t.wrapper.all (fun w => decide (w < ntabs)) && t.inner.all (fok nodes.length)

/-- The IR's computed degree (`SlotIr::max_term_degree`): a table has degree `1`, an affine node `1` (`0` with no table
term), a sum node the largest sum of its factors' degrees, a term its wrapper's length plus its inner factors'. -/
def irDegree (nodes : List (Body Fp2)) (terms : List (Term Fp2)) : ℕ :=
  let nd := nodes.foldl (fun (acc : List ℕ) b =>
    let fd := fun (f : Factor) => match f with
      | .tab _ => 1
      | .node i => acc.getD i 0
    acc ++ [match b with
      | .affine _ ts => if ts.isEmpty then 0 else 1
      | .sum ss => ss.foldl (fun m sb => max m ((sb.factors.map fd).sum)) 0]) []
  let fd := fun (f : Factor) => match f with
    | .tab _ => 1
    | .node i => nd.getD i 0
  terms.foldl (fun m t => max m (t.wrapper.length + (t.inner.map fd).sum)) 0

/-- A host slot's three-term template (`three_terms`): coefficients `1, ν_0, ν_1`, wrappers led by `eq` tables 0, 1, 2. -/
def hostTemplate (nu : List Fp2) (terms : List (Term Fp2)) : Bool :=
  match terms with
  | [t0, t1, t2] =>
    t0.coef == Fp2.one && t1.coef == nu.getD 0 Fp2.zero && t2.coef == nu.getD 1 Fp2.zero &&
      t0.wrapper.head? == some 0 && t1.wrapper.head? == some 1 && t2.wrapper.head? == some 2
  | _ => false

def St.endSlot (s0 : St) : St := Id.run do
  let r := s0.cur
  let mut s := s0
  let some sh := s.sh | return s.bad "no SHAPE"
  let key := s.key
  let sid := s!"slot {r.s}"
  -- the slot list
  s := s.check "slot-index" (r.s == s.slots) sid
  s := s.check "kind" (r.kind == kindCode (kindOf r.s)) sid
  let sc := ZK60.Exec.Slot.W16R2.sched sh r.s
  s := s.check "schedule" ((r.n, r.ext, r.deg) == sc && s.sched.getD r.s (0, 0, 0) == sc) s!"{sid} {sc}"
  s := s.check "terms" (r.terms.length == r.npriv && s.termsDecl.getD r.s 0 == r.npriv &&
    privCount r.tabs == r.npriv && r.tabs.length == r.ntabs) sid
  -- the definition's draws: replayed squeezes from the previous slot's end
  let some prev := s.prev | return s.bad s!"{sid}: no transcript"
  let some (trbS, trbC) := r.trb | return s.bad s!"{sid}: no TRB"
  let k := trbC - prev.counter.toNat
  let (ds, t) := (List.range k).foldl (fun (acc : List Fp2 × Tr) _ =>
      let ct := acc.2.challengeFp2 H
      (acc.1 ++ [ct.1], ct.2)) ([], prev)
  s := s.check "draws" (ds == r.draws && t.state == trbS && t.counter.toNat == trbC) sid
  s := s.check "draw-layout" (ZK60.Exec.Slot.R13.drawLen sh r.s == r.draws.length)
    s!"{sid}: {ZK60.Exec.Slot.R13.drawLen sh r.s} vs {r.draws.length}"
  let segsNow := splitDraws (ZK60.Exec.Slot.R13.draws sh r.s) r.draws
  let segsAll := s.segs ++ [segsNow]
  let segF := fun (j : ℕ) => segsAll.getD j []
  -- the hand-off of claim points and the hosted coefficients
  s := s.check "hosted" ((r.hosted.map Prod.fst) == hostsOf r.s && r.hosted == hostedCoefs sh segF r.s) sid
  let want := eqPoints sh segF r.s
  if !want.isEmpty || !(eqTabs r.tabs).isEmpty then
    s := s.check "claim-points" (eqTabs r.tabs == want) sid
  -- the IR
  if r.hasIr then
    let ir : Ir Fp2 := ⟨r.nodes, r.irTerms⟩
    s := s.check "ir-shape" (r.irT == r.ntabs && irWellFormed r.ntabs r.nodes r.irTerms && ir.canonB) sid
    let provs := (r.nodeProv.flatten ++ r.termProv)
    let coefs : List Fp2 := (r.nodes.flatMap fun b => match b with
        | .affine kk ts => kk :: ts.map Prod.fst
        | .sum ss => ss.map SubTerm.coef) ++ r.irTerms.map Term.coef
    for (c, pv) in coefs.zip provs do
      match provValue segsNow pv with
      | some v => s := s.check "ir-challenges" (c == v) s!"{sid} {pv}"
      | none => pure ()
    if kindOf r.s == .host then
      s := s.check "ir-template" (hostTemplate (segOf .nu segsNow) r.irTerms) sid
    -- the round messages carry `degree + 1` values: the polynomial's true degree must not exceed the declared one
    let dg := irDegree r.nodes r.irTerms
    s := s.check "ir-degree" (dg ≤ r.deg) s!"{sid}: computed {dg}, declared {r.deg}"
    if dg < r.deg then
      let msg := s!"slot {r.s}: declared degree {r.deg}, computed {dg}"
      s := { s with gaps := s.gaps.push msg }
  -- the verify arm
  let some (c, claimed, fin, rhoFull, pvR, gR) := r.res | return s.bad s!"{sid}: no RES"
  let some (traS, traC) := r.tra | return s.bad s!"{sid}: no TRA"
  let t0 := mkTr trbS trbC key
  let d : SlotDefW := ⟨r.s, r.n, r.ext, r.deg, r.tabs, r.hosted, ⟨r.nodes, r.irTerms⟩⟩
  let pf : SlotProofW := ⟨r.scalar, r.rounds, r.terms⟩
  if !r.hasPubv && r.hasIr then
    match slotVerifyW H d s.scalars pf t0 with
    | (.ok o, t') =>
      s := s.check "verify-arm" (o.c == c && o.claimed == claimed && o.fin == fin && o.rhoFull == rhoFull &&
        o.vals == r.vals && o.polyVal == pvR && o.gVal == gR && t'.state == traS && t'.counter.toNat == traC) sid
    | (.error _, _) => s := s.check "verify-arm" false s!"{sid}: refused"
  else
    -- the arm's parts, with Rust's multilinear value for the tables the corpus does not carry
    let ct := slotC H d t0
    let cl := claimedW r.scalar r.hosted s.scalars
    let (v, t4) := scVerify H cl r.deg (r.n + r.ext) r.rounds (slotT3 H d pf t0)
    match v with
    | .ok (finL, rhoL) =>
      let rho := rhoL.take r.n
      let sel := selW (rhoL.drop r.n)
      let tabsV : List TabV := r.tabs
      let valsL : List Fp2 := (List.range tabsV.length).map fun i =>
        match tabsV.getD i .priv with
        | .eq st p => sel.mul (eqPointBody p ((rho.drop st).take p.length))
        | .pub vv => sel.mul ((evalMleExt vv rho).getD Fp2.zero)
        | .priv => r.vals.getD i Fp2.zero
      let valsL := (List.range valsL.length).map fun i =>
        match List.lookup i r.pubv with
        | some m => sel.mul m
        | none => valsL.getD i Fp2.zero
      -- an R13 slot the code's IR does not transcribe (`SC_TAB`, `IRNONE`): its polynomial value is Rust's closure's
      -- (finding L17-9); every other part of the arm is recomputed
      let pvL := if r.hasIr then irEvalW ⟨r.nodes, r.irTerms⟩ valsL else pvR
      let tA := t4.absorbFp2 H pbTerm r.terms
      s := s.check (if r.hasIr then "verify-arm-parts" else "verify-arm-noir") (ct.1 == c && cl == claimed && finL == fin && rhoL == rhoFull &&
        valsL == r.vals && pvL == pvR && gValW finL pvL ct.1 == gR && tA.state == traS && tA.counter.toNat == traC) sid
    | .error _ => s := s.check "verify-arm-parts" false s!"{sid}: refused"
  let s1 := { s with prev := some (mkTr traS traC key), scalars := s.scalars ++ [r.scalar] }
  let s2 := { s1 with segs := segsAll, slots := s1.slots + 1 }
  { s2 with cur := Rec.empty }

/-! ## One line -/

def step (s : St) (line : String) : St :=
  let w := (line.splitOn " ").filter (· ≠ "")
  match w with
  | ["L11", _, keyH, _] =>
    if keyH = "-" then { s with key := none } else
    match parseDig keyH with
    | some k => { s with key := some k }
    | none => s.bad line
  | "SHAPE" :: rest =>
    match parseShape rest with
    | some sh => { s with sh := some sh }
    | none => s.bad line
  | ["SCHED", l] =>
    match (l.splitOn ",").mapM (fun e => match (e.splitOn ":").mapM String.toNat? with
        | some [a, b, c] => some (a, b, c)
        | _ => none) with
    | some v => { s with sched := v }
    | none => s.bad line
  | ["TERMSDECL", l] =>
    match parseCsvNat l with
    | some v => { s with termsDecl := v }
    | none => s.bad line
  | ["HEAD", st, ctr] =>
    match parseDig st, ctr.toNat? with
    | some d, some c => { s with head := some (d, c) }
    | _, _ => s.bad line
  | ["ROOTS", a, ar, m, h, hr, lc] =>
    match parseDig a, ar.toNat?, parseDig m, parseDig h, hr.toNat?, lc.toNat? with
    | some a, some ar, some m, some h, some hr, some lc => { s with roots := some (a, ar, m, h, hr, lc) }
    | _, _, _, _, _, _ => s.bad line
  | ["LOGUP", b, g, a] =>
    match pF2 b, pF2 g, pF2 a with
    | some b, some g, some a => { s with logup := some (b, g, a) }
    | _, _, _ => s.bad line
  | ["TAGS", u, e, a] =>
    match pF2 u, pF2 e, pF2 a with
    | some u, some e, some a => { s with tags := some (u, e, a) }
    | _, _, _ => s.bad line
  | ["HEADEND", st, ctr] =>
    match parseDig st, ctr.toNat?, s.head, s.roots, s.logup, s.tags with
    | some d, some c, some (hs, hc), some (a, ar, m, h, hr, lc), some (b, g, al), some (gu, ge, ga) =>
      -- `verify_core`'s head (protocol.rs:2827-2837): absorb_root A, M, beta, gamma, alpha, absorb_root H
      let ar' := fun (t : Tr) (lab : List UInt8) (root : Dig) (rows : ℕ) =>
        ((t.absorb H lab root.toList).absorbU64 H (ascii "rows") (UInt64.ofNat rows)).absorbU64 H (ascii "log-cols")
          (UInt64.ofNat lc)
      let t := ar' (mkTr hs hc s.key) (ascii "A") a ar
      let t := t.absorb H (ascii "M") m.toList
      let (bL, t) := t.challengeFp2 H
      let (gL, t) := t.challengeFp2 H
      let (aL, t) := t.challengeFp2 H
      let t := ar' t (ascii "H") h hr
      let s := s.check "head" (bL == b && gL == g && aL == al && t.state == d && t.counter.toNat == c) line
      let s := s.check "tags" (gL.mulBase (Fp.new 133) == gu && gL.mulBase (Fp.new 129) == ge &&
        gL.mulBase (Fp.new 134) == ga) line
      { s with prev := some (mkTr d c s.key) }
    | _, _, _, _, _, _ => s.bad line
  | ["SLOT", sl, k, n, e, dg, np, nt] =>
    match sl.toNat?, n.toNat?, e.toNat?, dg.toNat?, np.toNat?, nt.toNat? with
    | some sl, some n, some e, some dg, some np, some nt =>
      { s with cur := { s := sl, kind := k, n := n, ext := e, deg := dg, npriv := np, ntabs := nt } }
    | _, _, _, _, _, _ => s.bad line
  | ["DRAWS", l] =>
    match pF2s l with
    | some v => { s with cur := { s.cur with draws := v } }
    | none => s.bad line
  | ["TRB", st, ctr] =>
    match parseDig st, ctr.toNat? with
    | some d, some c => { s with cur := { s.cur with trb := some (d, c) } }
    | _, _ => s.bad line
  | ["SCALAR", x] =>
    match pF2 x with
    | some x => { s with cur := { s.cur with scalar := x } }
    | none => s.bad line
  | ["HOSTED", l] =>
    if l = "-" then { s with cur := { s.cur with hosted := [] } } else
    match (l.splitOn ";").mapM (fun e => match (e.splitOn ":").mapM String.toNat? with
        | some [h, a, b] => some (h, f2 a b)
        | _ => none) with
    | some v => { s with cur := { s.cur with hosted := v } }
    | none => s.bad line
  | ["ROUND", _, l] =>
    match pF2s l with
    | some v => { s with cur := { s.cur with rounds := s.cur.rounds ++ [v] } }
    | none => s.bad line
  | ["TERMS", l] =>
    match pF2s l with
    | some v => { s with cur := { s.cur with terms := v } }
    | none => s.bad line
  | ["TAB", _, "eq", st, l] =>
    match st.toNat?, pF2s l with
    | some st, some p => { s with cur := { s.cur with tabs := s.cur.tabs ++ [.eq st p] } }
    | _, _ => s.bad line
  | ["TAB", _, "pub", _, l] =>
    match pF2s l with
    | some v => { s with cur := { s.cur with tabs := s.cur.tabs ++ [.pub v] } }
    | none => s.bad line
  | ["TAB", i, "pubv", _, x] =>
    match i.toNat?, pF2 x with
    | some i, some x =>
      let c := { s.cur with tabs := s.cur.tabs ++ [TabV.pub []], pubv := s.cur.pubv ++ [(i, x)] }
      { s with cur := { c with hasPubv := true } }
    | _, _ => s.bad line
  | ["TAB", _, "priv", _] => { s with cur := { s.cur with tabs := s.cur.tabs ++ [.priv] } }
  | ["VALS", l] =>
    match pF2s l with
    | some v => { s with cur := { s.cur with vals := v } }
    | none => s.bad line
  | ["IR", nt, _, _] =>
    match nt.toNat? with
    | some nt => { s with cur := { s.cur with irT := nt, hasIr := true } }
    | none => s.bad line
  | ["IRTAB", _, _, _] => s
  | ["NODE", _, "A", k, l] =>
    match pCoef k, (if l = "-" then some [] else (l.splitOn ";").mapM fun e =>
        match e.splitOn "@" with
        | [c, t] => do
          let (c, p) ← pCoef c
          let t ← (dropS t 1).toNat?
          pure ((c, t), p)
        | _ => none) with
    | some (k, pk), some ts =>
      let c := { s.cur with nodes := s.cur.nodes ++ [Body.affine k (ts.map Prod.fst)] }
      let c := { c with nodeProv := c.nodeProv ++ [pk :: ts.map Prod.snd] }
      { s with cur := c }
    | _, _ => s.bad line
  | ["NODE", _, "S", l] =>
    match (if l = "-" then some [] else (l.splitOn ";").mapM fun e =>
        match e.splitOn "@" with
        | [c, fs] => do
          let (c, p) ← pCoef c
          let fs ← pFactors fs
          pure (⟨c, fs⟩, p)
        | _ => none) with
    | some ss =>
      let c := { s.cur with nodes := s.cur.nodes ++ [Body.sum (ss.map Prod.fst)] }
      let c := { c with nodeProv := c.nodeProv ++ [ss.map Prod.snd] }
      { s with cur := c }
    | none => s.bad line
  | ["NLABEL", _, _] => s
  | ["TERM", c, ws, inner] =>
    match pCoef c, parseCsvNat ws, pFactors inner with
    | some (c, p), some ws, some fs =>
      { s with cur := { s.cur with irTerms := s.cur.irTerms ++ [⟨c, ws, fs⟩], termProv := s.cur.termProv ++ [p] } }
    | _, _, _ => s.bad line
  | ["IRNONE", _] => s
  | ["RES", c, cl, fin, rho, pv, g] =>
    match pF2 c, pF2 cl, pF2 fin, pF2s rho, pF2 pv, pF2 g with
    | some c, some cl, some fin, some rho, some pv, some g =>
      { s with cur := { s.cur with res := some (c, cl, fin, rho, pv, g) } }
    | _, _, _, _, _, _ => s.bad line
  | ["TRA", st, ctr] =>
    match parseDig st, ctr.toNat? with
    | some d, some c => { s with cur := { s.cur with tra := some (d, c) } }
    | _, _ => s.bad line
  | ["END", _] => s.endSlot
  | ["DONE", _, _, _] => s.check "slot-count" (s.slots == nSlots) line
  | _ => s.bad line

end ZK60.Exec.L17Slots

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.L17Slots in
def main (args : List String) : IO UInt32 := do
  let path := args.headD "results/zk60_lean_l17_20261107/slots_corpus.txt"
  let lines ← IO.FS.lines path
  let s : St := {}
  let s := s.check "ASCII" (ascii "pb-slot" == pbSlot && ascii "pb-scalar" == pbScalar && ascii "pb-term" == pbTerm)
    "the three slot labels"
  let s := lines.foldl (fun s l => if l.startsWith "#" || l.all Char.isWhitespace then s else step s l) s
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for g in s.gaps do
    IO.println s!"DEGREE GAP (info) {g}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"CheckR13Slots: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)
