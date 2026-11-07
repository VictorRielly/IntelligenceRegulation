/-
D63 step L13: the agreement check of the Lean ports of the W16R2 slot builders (`SlotW16Build.lean`) and of the W16R2
layout (`SlotW16BuildLayout.lean`) against the code.

Run (through the zk60 resource guard; `results/zk60_lean_l13_20261107/check_l13.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/SlotW16BuildCheck.lean <layout.txt> <L11 corpus.txt>

`layout.txt` is written by `hashline/src/private_block/lean_l13_export_tests.rs` (test only): the layout facts of the
W16R2 rung, Shieldstral T128 and 8B T128 shapes. The L11 corpus (`results/zk60_lean_l11_20261107/corpus.txt`) is a
real W16R2 rung block receipt's slots, with every slot's table list and IR as the code builds them.

What it checks, with the Lean definitions only:
* per shape: the `A` plane list (`aPlanes`), the `H` plane list and helper ids (`hPlanes`, `hIds`), every lookup of
  every lookup domain with its helper count (`lookupsW`, `nHelp`), the zero-rule planes (`zeroPlanes`), the range
  widths and families (`widthsW`, `famsW`), and that the product fold's shift is `foldShift` (rung) and the stack
  LowH24 (all three);
* per slot of the rung receipt: Lean builds the slot's table list (kind and label, as `IrB` pushes them) and its IR
  (every node and term, with the coefficient VALUES) from the shape facts, the precision, the head's challenges and the
  slot's own and earlier draws ONLY, and compares them with the code's (`IRTAB`, `NODE`, `TERM`); and the table kinds
  with the verifier's tables (`TAB`: `eq` ↔ eq, `pub` ↔ public and support, the rest private).
It prints the checks per kind and `N checks, F failed`, and exits nonzero on any failure. Not imported by the library
root (it defines `main`).
-/
import ZK60Formal.SlotW16Build
import ZK60Formal.SlotW16BuildLayout

namespace ZK60.Exec.L13

open ZK60.Exec ZK60.Exec.Slot ZK60.Exec.Slot.W16R2 ZK60.Exec.Slot.Build ZK60.Exec.Slot.Build.Lay

/-! ## Parsing -/

def dropS (s : String) (n : ℕ) : String := String.ofList (s.toList.drop n)

def kv (w : List String) (k : String) : Option String :=
  (w.find? (·.startsWith (k ++ "="))).map fun x => dropS x (k.length + 1)

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def fpOf (n : ℕ) : Fp := ⟨UInt64.ofNat n⟩

def f2 (a b : ℕ) : Fp2 := ⟨fpOf a, fpOf b⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

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

def parsePrec (w : List String) : Option PrecW := do
  let g := fun k => (kv w k) >>= String.toNat?
  let gi := fun k => (kv w k) >>= String.toInt?
  let h24 ← g "h24"
  let fold := (g "fold").getD 0
  pure { h24 := h24 == 1, tn := ← g "tn", cnA := ← gi "cna", cnM := ← gi "cnm", ceps := ← gi "ceps", q := ← g "q",
         k := ← g "k", v := ← g "v", score := ← g "score", pv := ← g "pv", ao := ← g "ao", gate := ← g "gate",
         up := ← g "up", prodbits := ← g "prodbits", down := ← g "down", fp := ← g "fp", wrho := ← g "wrho",
         rope := ← g "rope", fold := fold }

/-! ## Canonical strings (the coefficient VALUES, no provenance labels) -/

def f2Str (x : Fp2) : String := s!"{x.c0.v.toNat}:{x.c1.v.toNat}"

def facStr : Factor → String
  | .tab i => s!"t{i}"
  | .node i => s!"n{i}"

def facsStr (fs : List Factor) : String := if fs.isEmpty then "-" else ".".intercalate (fs.map facStr)

def bodyStr : Body Fp2 → String
  | .affine k ts => "A " ++ f2Str k ++ " " ++ (if ts.isEmpty then "-" else ";".intercalate (ts.map fun p => f2Str p.1 ++ "@t" ++ toString p.2))
  | .sum ss => "S " ++ (if ss.isEmpty then "-" else ";".intercalate (ss.map fun s => f2Str s.coef ++ "@" ++ facsStr s.factors))

def termStr (t : Term Fp2) : String :=
  "T " ++ f2Str t.coef ++ " " ++ (if t.wrapper.isEmpty then "-" else ",".intercalate (t.wrapper.map toString)) ++ " " ++ facsStr t.inner

/-- A corpus coefficient `c0:c1:provenance` as `c0:c1`. -/
def coefStr (s : String) : String :=
  match s.splitOn ":" with
  | a :: b :: _ => a ++ ":" ++ b
  | _ => "?"

/-- A corpus `NODE` line's body, canonical. -/
def nodeLineStr (w : List String) : String :=
  match w with
  | [_, _, "A", k, ts] =>
    "A " ++ coefStr k ++ " " ++ (if ts = "-" then "-" else ";".intercalate ((ts.splitOn ";").map fun e =>
      match e.splitOn "@" with
      | [c, t] => coefStr c ++ "@" ++ t
      | _ => "?"))
  | [_, _, "S", ss] =>
    "S " ++ (if ss = "-" then "-" else ";".intercalate ((ss.splitOn ";").map fun e =>
      match e.splitOn "@" with
      | [c, f] => coefStr c ++ "@" ++ f
      | _ => "?"))
  | _ => "?"

def termLineStr (w : List String) : String :=
  match w with
  | [_, c, ws, inner] => "T " ++ coefStr c ++ " " ++ ws ++ " " ++ inner
  | _ => "?"

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
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 300}" else s.msgs }

/-- Compare two lists of strings; on a mismatch report the first difference. -/
def St.cmp (s : St) (kind : String) (what : String) (a b : List String) : St :=
  if a == b then s.check kind true what else
  let i := ((List.range (max a.length b.length)).find? fun i => a.getD i "<none>" != b.getD i "<none>").getD 0
  s.check kind false s!"{what}: lengths {a.length}/{b.length}; first difference at {i}: Lean {a.getD i "<none>"} | code {b.getD i "<none>"}"

/-! ## Part 1: the layout facts at three shapes -/

def domName : Dom → String
  | .T => "T" | .Ht => "Ht" | .L => "L" | .D => "D" | .Q => "Q" | .Kv => "Kv" | .S => "S" | .F => "F" | .Tab => "Tab"

def domOfName (s : String) : Option Dom :=
  [Dom.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab].find? fun d => domName d == s

def tagStr (w : ℕ) : String := if w = 8 then "U8" else s!"R{w}"

def lkStr (l : LkW) : String :=
  s!"{l.cst}:{tagStr l.tag}:" ++ "+".intercalate (l.terms.map fun t => s!"{t.1}*{t.2}")

structure LayRec where
  name : String := ""
  padRule : Bool := false
  pads : List ℕ := []
  logCols : ℕ := 14
  prec : Option PrecW := none
  lines : List (List String) := []

/-- The per-shape layout checks. -/
def checkLayout (s0 : St) (r : LayRec) : St := Id.run do
  let mut s := s0
  let some p := r.prec | return s.check "PARSE" false s!"{r.name}: no PREC"
  let get := fun (k : String) => (r.lines.find? fun w => w.head? == some k)
  let ws := widthsW p
  let fams := famsW ws r.logCols
  let pl := aPlanes p fams
  -- the stack and the fold
  s := s.check "stack" p.h24 s!"{r.name}: LowH24"
  if p.fold != 0 then
    s := s.check "fold-shift" (p.fold == foldShift p.h24) s!"{r.name}: fold {p.fold}"
  s := s.check "rh-width" (rhWidth p.h24 == foldShift p.h24) r.name
  -- widths and families
  match get "WIDTHS" with
  | some [_, l] => s := s.cmp "widths" r.name (ws.map toString) (l.splitOn ",")
  | _ => s := s.check "PARSE" false s!"{r.name}: WIDTHS"
  match get "FAMS" with
  | some [_, l] => s := s.cmp "families" r.name (fams.map fun f => s!"{f.1}:{f.2}") (l.splitOn ",")
  | _ => s := s.check "PARSE" false s!"{r.name}: FAMS"
  -- the A planes
  match get "APLANES" with
  | some [_, l] => s := s.cmp "a-planes" r.name (pl.map fun e => domName e.1 ++ ":" ++ e.2) (l.splitOn ",")
  | _ => s := s.check "PARSE" false s!"{r.name}: APLANES"
  let nRange := (fams.map Prod.snd).sum
  match get "HPLANES" with
  | some [_, l] => s := s.cmp "h-planes" r.name ((hPlanes p pl nRange).map domName) (l.splitOn ",")
  | _ => s := s.check "PARSE" false s!"{r.name}: HPLANES"
  match get "HIDS" with
  | some (_ :: rest) =>
    let code := rest.map fun e => (e.splitOn "=").getD 1 ""
    s := s.cmp "h-ids" r.name ((hIds p pl nRange).map toString) code
  | _ => s := s.check "PARSE" false s!"{r.name}: HIDS"
  -- the lookups
  for w in r.lines do
    match w with
    | ["LK", dn, h, l] =>
      match domOfName dn with
      | some d =>
        let lean := (lookupsW p pl d).map lkStr
        let code := if l = "-" then [] else l.splitOn ";"
        s := s.cmp "lookups" s!"{r.name} {dn}" lean code
        s := s.check "helpers" (toString (nHelp p pl d) == h) s!"{r.name} {dn}: {nHelp p pl d} vs {h}"
      | none => s := s.check "PARSE" false s!"{r.name}: LK {dn}"
    | ["ZERO", dn, l] =>
      match domOfName dn with
      | some d =>
        let pads := fun (e : Dom) => r.pads.getD e.idx 0 == 1
        let lean := (zeroPlanes pl fams r.logCols r.padRule pads d).map toString
        s := s.cmp "zero-planes" s!"{r.name} {dn}" lean (if l = "-" then [] else l.splitOn ",")
      | none => s := s.check "PARSE" false s!"{r.name}: ZERO {dn}"
    | _ => pure ()
  return s

/-! ## Part 2: every slot's tables and IR at the rung receipt -/

/-- What a slot's builder reads: the shape facts, the precision, the layout, the head's challenges, every slot's
draws (the slot's own and the earlier ones). -/
structure Ctx where
  sh : ShapeW
  p : PrecW
  pl : List (Dom × String)
  fams : List (ℕ × ℕ)
  logCols : ℕ
  hid : List ℕ
  alpha : Fp2
  beta : Fp2
  gu8 : Fp2
  gexp : Fp2
  gact : Fp2
  segs : ℕ → List (Seg × List Fp2)

def Ctx.supp (x : Ctx) (d : Dom) : Bool := x.sh.padRule && x.sh.pads d

def eqT (len : ℕ) (lab : String) : String := s!"eq:0:{len} eq({lab})"
def pubT (lab : String) : String := "pub " ++ lab
def suppT (d : Dom) : String := s!"supp:{domName d} supp({domName d})"
def aT (p : ℕ) : String := s!"A A[{p}]_on_its_own_domain"
def aSl (lab : String) : String := "A " ++ lab
def aFx (p : ℕ) (lab : String) : String := s!"A A[{p}]_at_{lab}"
def hT (p : ℕ) : String := s!"H H[{p}]"
def geqT (b : ℕ) : String := s!"geq:{b} eq(r_g)_over_the_leading_{b}_variables"

def zpow (z : Fp2) (j : ℕ) : Fp2 := (List.range j).foldl (fun a _ => a.mul z) Fp2.one

def gOf (gu8 : Fp2) (w : ℕ) : Fp2 :=
  if w = 8 then gu8 else gu8.mulBase ((Fp.new (UInt64.ofNat (200 + w))).mul (Fp.new 133).inv)

/-- `logup_subterms`' lookups, read through the slot's plane → table map. -/
def lksD (x : Ctx) (shaped : ℕ → ℕ) (d : Dom) : List (LkD Fp2) :=
  (lookupsW x.p x.pl d).map fun l =>
    ⟨x.alpha.sub ((Fp2.fromBase (Fp.fromI64 l.cst)).add (gOf x.gu8 l.tag)),
      l.terms.map fun t => (Fp2.fromBase (Fp.fromI64 (-t.2)), shaped t.1)⟩

def zeroOf (x : Ctx) (d : Dom) : List ℕ := zeroPlanes x.pl x.fams x.logCols x.sh.padRule x.sh.pads d

def optIx (b : Bool) (i : ℕ) : Option ℕ := if b then some i else none

/-- A slot's tables and IR, as Lean builds them. -/
def build (x : Ctx) (s : ℕ) : List String × Ir Fp2 := Id.run do
  let sh := x.sh
  let p := x.p
  let pl := x.pl
  let P := pIx pl
  let G := gIx pl
  let sg := x.segs s
  let mu := segOf .mu sg
  let nu := segOf .nu sg
  let zeta := (segOf .zeta sg).getD 0 Fp2.zero
  let zp := zpow zeta
  let lt := sh.lt
  let h := hIds p pl ((x.fams.map Prod.snd).sum)
  let fh := fun (k : ℕ) => h.getD k 0
  -- the planes of a domain from table `start` on, and their map
  let range := fun (d : Dom) (start : ℕ) =>
    let ps := domPlanes pl d
    (ps.map aT, fun (q : ℕ) => start + ps.idxOf q)
  if s = scSS ∨ s = scSSM then
    let g := x.supp .D
    return ([eqT lt (if s = scSS then "r_t" else "r_t2"), aT (P (if s = scSS then "X" else "X1"))] ++
      (if g then [suppT .D] else []), ssIr cstW 0 1 (optIx g 2))
  if s = scTZC then
    let g := x.supp .T
    let lim := P "LIMB"
    let limm := P "LIMBM"
    let tabs := [eqT lt "tau", eqT lt "r_t", eqT lt "r_t2", aT (P "D"), aT (P "DSQ")] ++
      (List.range 9).map (fun k => aSl s!"A[{lim}]_limb_sub-slice_{k}") ++ [aT (P "DM"), aT (P "DSQM")] ++
      (List.range 9).map (fun k => aSl s!"A[{limm}]_limb_sub-slice_{k}") ++ (if g then [suppT .T] else [])
    let tmap := fun (q : ℕ) => if q = P "D" then 3 else if q = P "DSQ" then 4 else if q = P "DM" then 14 else 15
    let groups := if g && !(zeroOf x .T).isEmpty then [(25, (zeroOf x .T).map tmap)] else []
    return (tabs, tzcIr cstW ⟨0, 1, 2, 3, 4, 14, 15, optIx g 25⟩ p.ceps mu nu zp groups)
  if s = scLZC then
    let g := x.supp .L
    let tabs := [eqT (sh.logs .L) "tau", aT (P "LIMB"), aT (P "LIMBM"), hT (fh 0)] ++ (if g then [suppT .L] else [])
    let shaped := fun (q : ℕ) => if q = P "LIMB" then 1 else 2
    let groups := if g && !(zeroOf x .L).isEmpty then [(4, (zeroOf x .L).map shaped)] else []
    return (tabs, lzcIr cstW 0 3 (lksD x shaped .L) ((segOf .muPad sg).getD 0 Fp2.zero) zp groups)
  if s = scRS then
    let g := x.supp .S
    let lam := (segOf .lam sg).getD 0 Fp2.zero
    return ([eqT (sh.logs .Ht) "p_ht", pubT "causal_mask_over_the_Dom::S_cube", aT (P "E"), aT (P "ZSEL")] ++
      (if g then [suppT .S] else []), rsIr cstW 0 1 2 3 (optIx g 4) lam)
  if s = scQMM ∨ s = scKMM ∨ s = scVMM ∨ s = scWO then
    return ([aFx (P (if s = scWO then "O" else "Y")) "(r_q_fixed,_rho)", pubT "fold_rows_i8(W,_eq(r_j))"], mmIr cstW 0 1)
  if s = scGMM ∨ s = scUMM ∨ s = scDMM then
    return ([aFx (P (if s = scDMM then "H" else "YM")) "(row_point_fixed,_rho)", pubT "fold_cols_i8(W,_eq(r_j))"],
      mmIr cstW 0 1)
  if s = scSCORE ∨ s = scPV then
    let gq := 0 < sh.lkv
    let o := if gq then 1 else 0
    let ab := if s = scSCORE then
        [aFx (P "QR") "(r_t_fixed_|_group_summed_|_r_hj_fixed_|_c)", aFx (P "KR") "(r_j_fixed_|_group_summed_|_c)"]
      else [aFx (P "P") "(group_summed_|_r_hj_fixed_|_r_t_fixed_|_s)", aFx (P "V") "(s_|_group_summed_|_r_i_fixed)"]
    return ((if gq then [geqT sh.lkv] else []) ++ ab, bilIr cstW (optIx gq 0) o (o + 1))
  if s = scDZC then
    let (pls, shaped) := range .D 5
    let n := pls.length
    let nh := nHelp p pl .D
    let g := x.supp .D
    let tabs := [eqT (sh.logs .D) "tau", eqT (lt + sh.ld) "p_a", eqT (lt + sh.ld) "p_z",
      pubT "gamma_a_on_the_padded_width", pubT "gamma_m_on_the_padded_width"] ++ pls ++
      [aSl "A_D_read_on_the_row_axis", aSl "A_DM_read_on_the_row_axis"] ++ (List.range nh).map (fun j => hT (fh 1 + j)) ++
      (if g then [suppT .D] else [])
    let gi := 7 + n + nh
    let R : DzcR := ⟨0, 1, 2, 3, 4, shaped (P "X"), shaped (P "Y"), shaped (P "AO"), shaped (P "X1"), shaped (P "YM"),
      shaped (P "Z"), shaped (P "X2"), (G "NR" 2).map shaped, (G "NS" 2).map shaped, (G "MR" 2).map shaped,
      (G "MS" 2).map shaped, (G "RAL" (limbsOf p.ao)).map shaped, (G "RDL" (limbsOf p.down)).map shaped, 5 + n, 6 + n,
      7 + n, optIx g gi⟩
    let K : DzcK := ⟨2 * p.cnA, 2 * p.cnM, 2 ^ p.tn, 2 ^ (p.tn + 1), p.ao, p.down⟩
    let groups := if g && !(zeroOf x .D).isEmpty then [(gi, (zeroOf x .D).map shaped)] else []
    return (tabs, dzcIr cstW R K (lksD x shaped .D) mu nu zp groups)
  if s = scQZC ∨ s = scKVZC then
    let q := s = scQZC
    let d : Dom := if q then .Q else .Kv
    let (pls, shaped) := range d 5
    let n := pls.length
    let nh := nHelp p pl d
    let g := x.supp d
    let p1 := if q then lt + sh.ld else lt + sh.lkvw
    let p2 := if q then lt + sh.lh + sh.ldh else lt + sh.lkvw
    let src := P (if q then "Q" else "K")
    let tabs := [eqT (sh.logs d) "tau", eqT p1 (if q then "pq" else "pk"), eqT p2 (if q then "p_o" else "pv"),
      pubT "the_RoPE_cos_table", pubT "the_RoPE_sin_table"] ++ pls ++
      [aFx src "the_RoPE_partner_half_(Coord::Flip_at_log_-_log2(head_dim))"] ++
      (List.range nh).map (fun j => hT (fh (if q then 2 else 3) + j)) ++ (if g then [suppT d] else [])
    let gi := 6 + n + nh
    let R : QzcR := ⟨0, 1, 2, 3, 4, shaped src, shaped (P (if q then "QR" else "KR")), shaped (P (if q then "O" else "V")),
      5 + n, (G (if q then "RQRL" else "RKRL") (limbsOf p.rope)).map shaped,
      (G (if q then "RQL" else "RKL") (limbsOf (if q then p.q else p.k))).map shaped,
      (G (if q then "RO" else "RVL") (limbsOf (if q then p.pv else p.v))).map shaped, 6 + n, optIx g gi⟩
    let K : QzcK := ⟨p.rope, if q then p.q else p.k, if q then p.pv else p.v⟩
    let groups := if g && !(zeroOf x d).isEmpty then [(gi, (zeroOf x d).map shaped)] else []
    return (tabs, qzcIr cstW R K (lksD x shaped d) mu nu zp groups)
  if s = scSZC then
    let (pls, shaped) := range .S 4
    let n := pls.length
    let nh := nHelp p pl .S
    let gh := x.supp .Ht
    let gs := x.supp .S
    let tabs := [eqT (sh.logs .S) "tau", eqT (sh.logs .Ht) "p_ht", eqT (sh.lh + lt + lt) "p_s", pubT "the_causal_mask"] ++
      pls ++ [aSl "A_MX_on_Dom::Ht", aSl "A_SUM_on_Dom::Ht"] ++ (List.range nh).map (fun j => hT (fh 4 + j)) ++
      [hT (fh 5)] ++ (if gh then [suppT .Ht] else []) ++ (if gs then [suppT .S] else [])
    let hx := 6 + n + nh
    let ghi := hx + 1
    let gsi := if gh then hx + 2 else hx + 1
    let R : SzcR := ⟨0, 1, 2, 3, shaped (P "S"), shaped (P "ZSEL"), shaped (P "E"), shaped (P "P"),
      (G "SR" (limbsOf p.wrho)).map shaped, (G "SG" (limbsOf p.wrho)).map shaped,
      (G "RSL" (limbsOf p.score)).map shaped, 4 + n, 5 + n, 6 + n, hx, optIx gh ghi, optIx gs gsi⟩
    let K : SzcK := ⟨127, p.fp, p.score⟩
    let lam := (segOf .lam (x.segs scRS)).getD 0 Fp2.zero
    let gHt := if gh && !(zeroOf x .Ht).isEmpty then [(ghi, [4 + n, 5 + n])] else []
    let gS := if gs && !(zeroOf x .S).isEmpty then [(gsi, (zeroOf x .S).map shaped)] else []
    return (tabs, szcIr cstW R K (lksD x shaped .S) mu nu (x.alpha.sub x.gexp) x.beta.neg lam zp (gHt ++ gS))
  if s = scFZC then
    let (pls, shaped) := range .F 3
    let n := pls.length
    let nh := nHelp p pl .F
    let g := x.supp .F
    let tabs := [eqT (sh.logs .F) "tau", eqT (lt + sh.lf) "p_g", eqT (lt + sh.lf) "p_u"] ++ pls ++
      (List.range nh).map (fun j => hT (fh 6 + j)) ++ [hT (fh 7), pubT "the_activation_group_column_(public_accuracy_data)"]
      ++ (if g then [suppT .F] else [])
    let gi := 5 + n + nh
    let R : FzcR := ⟨0, 1, 2, shaped (P "G"), shaped (P "A_SCALED"), shaped (P "U"), shaped (P "H"),
      (G "RGL" (limbsOf p.gate)).map shaped, (G "RU" (limbsOf p.up)).map shaped,
      (G "RH" (limbsOf (rhWidth p.h24))).map shaped, 3 + n, 3 + n + nh, 4 + n + nh, optIx g gi⟩
    let K : FzcK := ⟨p.fold, p.gate, p.up⟩
    let groups := if g && !(zeroOf x .F).isEmpty then [(gi, (zeroOf x .F).map shaped)] else []
    let amqK := (x.alpha.sub (Fp2.fromBase (Fp.fromI64 2048))).sub x.gact
    return (tabs, fzcIr cstW R K (lksD x shaped .F) mu nu amqK x.beta.neg (x.beta.mul x.beta).neg zp groups)
  if s = scTAB then
    let nr := (x.fams.map Prod.snd).sum
    let rp := (List.range nr).map fun j => P' j
    let gu := fh 8
    let tri := [(aT (P "MU8"), hT gu, pubT "the_U8_table's_value_column"),
      (aT (P "MEXP"), hT (gu + 1), pubT "the_exp_table's_value_column"),
      (aT (P "MACT"), hT (gu + 2), pubT "the_activation_table's_value_column")] ++
      (List.range nr).map (fun j => (aT (rp.getD j 0), hT (gu + 3 + j), pubT "a_W16_range_sub-plane's_value_column"))
    let padOn := !(zeroOf x .Tab).isEmpty
    let narrow := (List.range nr).filter fun j => !(narrowOf j)
    let gb := x.supp .Tab
    let base := 1 + 3 * (3 + nr)
    let actI := if gb then base + 1 else base
    let tabs := [eqT (sh.logs .Tab) "tau"] ++ tri.flatMap (fun t => [t.1, t.2.1, t.2.2]) ++
      (if padOn then (if gb then [suppT .Tab] else []) ++ [pubT "the_activation_table's_support_column"] ++
        narrow.map (fun _ => pubT "a_narrow_W16_range_family's_support_column") else [])
    let ts := (List.range (3 + nr)).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k)
    let t := fun (k : ℕ) => ts.getD k (0, 0, 0)
    let groups := if padOn then
        (if gb then [(base, [(t 0).1, (t 1).1]), (base, [(t 0).2.1, (t 1).2.1])] else []) ++
        [(actI, [(t 2).1]), (actI, [(t 2).2.1])] ++
        (narrow.zipIdx.flatMap fun q => [(actI + 1 + q.2, [(t (3 + q.1)).1]), (actI + 1 + q.2, [(t (3 + q.1)).2.1])])
      else []
    return (tabs, tabIr cstW 0 x.alpha ts mu zp groups)
  if s = scZS then
    return ([pubT "the_all-ones_vector_over_Dom::Tab", hT (fh 10)], zsIr cstW 0 1)
  if s = scIOIN ∨ s = scIOOUT then
    return ([eqT (sh.logs .D) "tau", aT (P (if s = scIOIN then "X" else "X2")),
      if s = scIOIN then "EP endpoint_in" else "EP endpoint_out"], ioIr cstW 0 1 2)
  return ([], ⟨[], []⟩)
where
  /-- the `j`-th range sub-plane's id (after the Tab words) -/
  P' (j : ℕ) : ℕ := pIx x.pl "MACT" + 1 + j
  /-- is the `j`-th range sub-plane's family full? -/
  narrowOf (j : ℕ) : Bool :=
    let subs := x.fams.flatMap fun f => (List.range f.2).map fun _ => f.1
    fullW (subs.getD j 0) x.logCols

/-- One slot's record from the corpus. -/
structure SRec where
  s : ℕ := 0
  draws : List Fp2 := []
  tabs : List String := []
  vtabs : List String := []
  nodes : List String := []
  terms : List String := []

structure CSt where
  st : St := {}
  sh : Option ShapeW := none
  logup : Option (Fp2 × Fp2 × Fp2) := none
  tags : Option (Fp2 × Fp2 × Fp2) := none
  segs : List (List (Seg × List Fp2)) := []
  cur : SRec := {}
  slots : ℕ := 0

def CSt.endSlot (c : CSt) (p : PrecW) (logCols : ℕ) : CSt := Id.run do
  let r := c.cur
  let mut st := c.st
  let some sh := c.sh | return { c with st := st.check "PARSE" false "no SHAPE" }
  let some (b, _, a) := c.logup | return { c with st := st.check "PARSE" false "no LOGUP" }
  let some (gu, ge, ga) := c.tags | return { c with st := st.check "PARSE" false "no TAGS" }
  let segsNow := splitDraws (draws sh r.s) r.draws
  let segsAll := c.segs ++ [segsNow]
  let ws := widthsW p
  let fams := famsW ws logCols
  let pl := aPlanes p fams
  let x : Ctx := ⟨sh, p, pl, fams, logCols, [], a, b, gu, ge, ga, fun j => segsAll.getD j []⟩
  let (tabs, ir) := build x r.s
  let sid := s!"slot {r.s}"
  st := st.cmp "ir-tables" sid tabs r.tabs
  let kindOk := (tabs.zip r.vtabs).all fun q =>
    let k := (q.1.splitOn " ").headD ""
    if k.startsWith "eq" || k.startsWith "geq" then q.2 == "eq"
    else if k == "pub" || k.startsWith "supp" then q.2 == "pub"
    else q.2 == "priv"
  st := st.check "table-kinds" (kindOk && tabs.length == r.vtabs.length) sid
  st := st.cmp "ir-nodes" sid (ir.nodes.map bodyStr) r.nodes
  st := st.cmp "ir-terms" sid (ir.terms.map termStr) r.terms
  return { c with st := st, segs := segsAll, slots := c.slots + 1, cur := {} }

def CSt.step (c : CSt) (p : PrecW) (logCols : ℕ) (line : String) : CSt :=
  let w := (line.splitOn " ").filter (· ≠ "")
  match w with
  | "SHAPE" :: rest =>
    match parseShape rest with
    | some sh => { c with sh := some sh }
    | none => { c with st := c.st.check "PARSE" false line }
  | ["LOGUP", b, g, a] =>
    match pF2 b, pF2 g, pF2 a with
    | some b, some g, some a => { c with logup := some (b, g, a) }
    | _, _, _ => { c with st := c.st.check "PARSE" false line }
  | ["TAGS", u, e, a] =>
    match pF2 u, pF2 e, pF2 a with
    | some u, some e, some a => { c with tags := some (u, e, a) }
    | _, _, _ => { c with st := c.st.check "PARSE" false line }
  | "SLOT" :: sl :: _ => { c with cur := { s := sl.toNat?.getD 0 } }
  | ["DRAWS", l] =>
    match pF2s l with
    | some v => { c with cur := { c.cur with draws := v } }
    | none => { c with st := c.st.check "PARSE" false line }
  | "TAB" :: _ :: k :: _ => { c with cur := { c.cur with vtabs := c.cur.vtabs ++ [if k == "pubv" then "pub" else k] } }
  | ["IRTAB", _, k, lab] => { c with cur := { c.cur with tabs := c.cur.tabs ++ [k ++ " " ++ lab] } }
  | "NODE" :: _ => { c with cur := { c.cur with nodes := c.cur.nodes ++ [nodeLineStr w] } }
  | "TERM" :: _ => { c with cur := { c.cur with terms := c.cur.terms ++ [termLineStr w] } }
  | ["END", _] => c.endSlot p logCols
  | ["DONE", _, _, _] => { c with st := c.st.check "slot-count" (c.slots == nSlots) line }
  | _ => c

end ZK60.Exec.L13

open ZK60.Exec ZK60.Exec.L13 in
def main (args : List String) : IO UInt32 := do
  let layPath := args.headD "results/zk60_lean_l13_20261107/layout.txt"
  let corpus := args.getD 1 "results/zk60_lean_l11_20261107/corpus.txt"
  let layLines ← IO.FS.lines layPath
  -- part 1: the layout facts, shape by shape
  let mut recs : Array LayRec := #[]
  let mut cur : LayRec := {}
  for l in layLines do
    let w := (l.splitOn " ").filter (· ≠ "")
    match w with
    | ["L13", nm] => cur := { name := nm }
    | "DOMS" :: rest =>
      cur := { cur with padRule := (kv rest "pad_rule") == some "1",
                        pads := ((kv rest "pads") >>= parseCsvNat).getD [],
                        logCols := (((kv rest "log_cols") >>= String.toNat?).getD 14) }
    | "PREC" :: rest => cur := { cur with prec := parsePrec rest }
    | ["LEND"] => recs := recs.push cur; cur := {}
    | _ => cur := { cur with lines := cur.lines ++ [w] }
  let mut s : St := {}
  s := s.check "shape-count" (recs.size == 3) s!"{recs.size} shapes"
  for r in recs do
    s := checkLayout s r
  -- part 2: the rung receipt's slots, with the rung's precision
  let some rung := recs[0]? | do IO.println "no rung"; return 1
  let some p := rung.prec | do IO.println "no rung PREC"; return 1
  let lines ← IO.FS.lines corpus
  let c : CSt := { st := s }
  let c := lines.foldl (fun c l => if l.startsWith "#" || l.all Char.isWhitespace then c else c.step p rung.logCols l) c
  let fin := c.st
  for (k, n) in fin.kinds do
    IO.println s!"  {k}: {n}"
  for m in fin.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"SlotW16BuildCheck: {fin.ok + fin.fail} checks, {fin.fail} failed"
  return (if fin.fail = 0 then 0 else 1)
