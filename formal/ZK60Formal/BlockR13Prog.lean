/-
D63 lane L44 (2026-11-10), deliverable 6: **the R13 block's slot program `progR13`**, beside lane L35's W16R2
`DefW16.progW16` (`BlockDefineW16.lean`), and its commitment counts at the R13 rung and at the Shieldstral T128 R13
block (finding L31-3).

R13 and W16R2 run the same 23 slots (L17, `SlotR13.lean`). They differ in
* the `A` plane list (`accuracy_layout.rs::AccuracyIds::new`, lines 51-110: byte limb groups, the RDL / HL / RH counts
  by stack, the softmax division's `PL`, `SR`, `SG` at `limbs_sigma_s`): `idsR13`;
* the lookups (`accuracy_layout.rs::lookups`, 213-276: a byte lookup per limb plane and a top-bit pin per shifted
  group): `lookupsR13`;
* the six zero-checks 14-19, whose relations are `argument_accuracy.rs`'s `dzc`, `fzc`, `qzc`, `szc` (48-222) and
  `tab` (416-444); their IRs are the code's `slot_ir_accuracy.rs` builders `dzc`, `fzc`, `qzc`, `szc` (124-428),
  transcribed here node for node with L13's builder pieces (`limbsB`, `reqB`, `batchB`, `gatedSt`, `threeTerms`,
  `zcIr`); **`SC_TAB`'s IR is NOT in the code** (`slot_ir_accuracy.rs:55`, finding L17-9): it is transcribed here
  from the relation itself, `argument_accuracy.rs:416-444` (`tab`): three LogUp table identities
  `h_k·(α − t_k) − m_k` at `μ_0, μ_1, μ_2` on the triples `(1, 2, 3)`, `(4, 5, 6)`, `(7, 8, 9)`, and the pad term at
  `μ_3` with the groups `(supp(Tab), [1, 4])`, `(supp(Tab), [2, 5])`, `(act support, [7])`, `(act support, [8])`
  (`PadTerm::add`, powers of `ζ` continuing across groups, argument.rs:1801-1835), which is L13's `tabIr` at those
  positions;
* the draws of those six slots: L17's `R13.draws`.
Every other slot's arm is `argument.rs`'s shared code (L35's `rawSlot` arms) at R13's plane ids.

`BlockR13ProgCheck.lean` compares the program with L17's R13 rung corpora (`results/zk60_lean_l17_20261107/`).

What is proved here (only `propext`, `Classical.choice`, `Quot.sound`): `progR13_cm`, `progR13_okb` (the numbering
keeps the counts and the check). The facts by evaluation are in `BlockR13ProgCnt.lean`: the rung's plane ids, the
helper counts, the `A` / `H` tables per slot at the R13 rung (L31's `aCntR13Rung` / `hCntR13Rung`, 148 / 54) and at
the Shieldstral T128 R13 block at each of the export's 26 layers (`aCntR13Shield` / `hCntR13Shield`, 146 / 53, finding
L31-3), and `progOKb` against R13's schedules.
-/
import ZK60Formal.BlockDefineW16Rung
import ZK60Formal.SlotR13
import ZK60Formal.BlockInstProf
import ZK60Formal.RunShapeShield

namespace ZK60.Exec.Block.DefR13

open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Exec.Slot.Build
open ZK60.Exec.Slot.Build.Lay (PrecW LkW)
open ZK60.Exec.Slot.W16R2 (Dom ShapeW scSS scSSM scTZC scLZC scRS scQMM scKMM scVMM scSCORE scPV scWO scGMM scUMM
  scDMM scDZC scQZC scKVZC scSZC scFZC scTAB scZS scIOIN scIOOUT nSlots)
open ZK60.Exec.Block.DefW16 (W16Cfg cstS rhoC aTab supp optIx epTab numProg rowsOf allDoms)

/-! ## The `A` plane ids (`AccuracyIds::new`, non-DD) -/

/-- **R13's `A` plane ids**, by role (words, and limb groups low limb first). -/
structure IdsR13 where
  d : ℕ
  dsq : ℕ
  dm : ℕ
  dsqm : ℕ
  mx : ℕ
  sum : ℕ
  limb : ℕ
  limbm : ℕ
  x : ℕ
  xl : List ℕ
  y : ℕ
  yl : List ℕ
  nr : List ℕ
  ns : List ℕ
  ao : ℕ
  al : List ℕ
  ral : List ℕ
  x1 : ℕ
  x1l : List ℕ
  ym : ℕ
  yml : List ℕ
  mr : List ℕ
  ms : List ℕ
  z : ℕ
  zl : List ℕ
  rdl : List ℕ
  x2 : ℕ
  x2l : List ℕ
  q : ℕ
  ql : List ℕ
  rql : List ℕ
  qr : ℕ
  qrl : List ℕ
  rqrl : List ℕ
  o : ℕ
  ol : List ℕ
  ro : List ℕ
  k : ℕ
  kl : List ℕ
  rkl : List ℕ
  v : ℕ
  vl : List ℕ
  rvl : List ℕ
  kr : ℕ
  krl : List ℕ
  rkrl : List ℕ
  s : ℕ
  rsl : List ℕ
  zsel : ℕ
  e : ℕ
  p : ℕ
  pl : List ℕ
  sr : List ℕ
  sg : List ℕ
  g : ℕ
  rgl : List ℕ
  a : ℕ
  u : ℕ
  ul : List ℕ
  ru : List ℕ
  h : ℕ
  hl : List ℕ
  rh : List ℕ
  mu8 : ℕ
  mexp : ℕ
  mact : ℕ
  q0 : ℕ
  k0 : ℕ
  s0 : ℕ
  f0 : ℕ
  t0 : ℕ

/-- `limbs_sigma_s`: the softmax remainders' byte limbs, `⌈wrho_s / 8⌉`. -/
def lsOf (p : PrecW) : ℕ := (p.wrho + 7) / 8

/-- **The ids at a stack and softmax limb count** (accuracy_layout.rs:51-110, the non-DD branch). -/
def idsR13 (h24 : Bool) (ls : ℕ) : IdsR13 :=
  let nrd := if h24 then 3 else 2
  let nhl := if h24 then 3 else 2
  let nrh := if h24 then 2 else 3
  let x2 := 41 + nrd
  let q0 := x2 + 3
  let k0 := q0 + 14
  let s0 := k0 + 14
  let f0 := s0 + 9 + 2 * ls
  let t0 := f0 + 11 + nhl + nrh
  { d := 0, dsq := 1, dm := 2, dsqm := 3, mx := 4, sum := 5, limb := 6, limbm := 7,
    x := 8, xl := [9, 10], y := 11, yl := [12, 13], nr := [14, 15, 16], ns := [17, 18, 19], ao := 20, al := [21, 22],
    ral := [23, 24, 25], x1 := 26, x1l := [27, 28], ym := 29, yml := [30, 31], mr := [32, 33, 34], ms := [35, 36, 37],
    z := 38, zl := [39, 40], rdl := List.range' 41 nrd, x2 := x2, x2l := [x2 + 1, x2 + 2],
    q := q0, ql := [q0 + 1, q0 + 2], rql := [q0 + 3, q0 + 4], qr := q0 + 5, qrl := [q0 + 6, q0 + 7], rqrl := [q0 + 8],
    o := q0 + 9, ol := [q0 + 10, q0 + 11], ro := [q0 + 12, q0 + 13],
    k := k0, kl := [k0 + 1, k0 + 2], rkl := [k0 + 3, k0 + 4], v := k0 + 5, vl := [k0 + 6, k0 + 7], rvl := [k0 + 8, k0 + 9],
    kr := k0 + 10, krl := [k0 + 11, k0 + 12], rkrl := [k0 + 13],
    s := s0, rsl := [s0 + 1, s0 + 2, s0 + 3], zsel := s0 + 4, e := s0 + 5, p := s0 + 6, pl := [s0 + 7, s0 + 8],
    sr := List.range' (s0 + 9) ls, sg := List.range' (s0 + 9 + ls) ls,
    g := f0, rgl := [f0 + 1, f0 + 2, f0 + 3], a := f0 + 4, u := f0 + 5, ul := [f0 + 6, f0 + 7], ru := [f0 + 8, f0 + 9],
    h := f0 + 10, hl := List.range' (f0 + 11) nhl, rh := List.range' (f0 + 11 + nhl) nrh,
    mu8 := t0, mexp := t0 + 1, mact := t0 + 2, q0 := q0, k0 := k0, s0 := s0, f0 := f0, t0 := t0 }

section Layout

variable (c : W16Cfg)

/-- The configuration's ids. -/
def ids : IdsR13 := idsR13 c.p.h24 (lsOf c.p)

def domStart (d : Dom) : ℕ :=
  match d with
  | .T => 0 | .Ht => 4 | .L => 6 | .D => 8 | .Q => (ids c).q0 | .Kv => (ids c).k0 | .S => (ids c).s0
  | .F => (ids c).f0 | .Tab => (ids c).t0

def domEnd (d : Dom) : ℕ :=
  match d with
  | .T => 4 | .Ht => 6 | .L => 8 | .D => (ids c).q0 | .Q => (ids c).k0 | .Kv => (ids c).s0 | .S => (ids c).f0
  | .F => (ids c).t0 | .Tab => (ids c).t0 + 3

/-- A domain's `A` planes, in plane order. -/
def domPl (d : Dom) : List ℕ := List.range' (domStart c d) (domEnd c d - domStart c d)

/-- The domain of an `A` plane. -/
def planeDom (q : ℕ) : Dom := (allDoms.find? fun d => decide (q < domEnd c d)).getD .Tab

/-- The first row of a domain's `A` planes. -/
def domRow (d : Dom) : ℕ :=
  ((allDoms.takeWhile fun d' => d' != d).map fun d' => (domEnd c d' - domStart c d') * rowsOf c d').sum

/-- **`a_off`** at R13. -/
def aOff (q : ℕ) : ℕ :=
  (domRow c (planeDom c q) + (q - domStart c (planeDom c q)) * rowsOf c (planeDom c q)) * 2 ^ c.logCols

/-- `A`'s data rows. -/
def aDataRows : ℕ := (allDoms.map fun d => (domEnd c d - domStart c d) * rowsOf c d).sum

/-- The log size of an `A` plane (its domain's). -/
def logOf (q : ℕ) : ℕ := c.sh.logs (planeDom c q)

/-! ### The lookups (`AccuracyIds::lookups`) and the helper planes (`HIds::new`) -/

/-- A limb group's byte lookups and, for a shifted group, the top limb's pin `2^(8·count − bits)·top`. -/
def bytes (g : List ℕ) (bits : Option ℕ) : List LkW :=
  g.map (fun q => (⟨[(q, 1)], 0, 8⟩ : LkW))
    ++ (match bits with
      | some b => [⟨[(g.getLastD 0, 2 ^ (8 * g.length - b))], 0, 8⟩]
      | none => [])

/-- **The lookups of a domain**, in order (accuracy_layout.rs:213-276). -/
def lookups (d : Dom) : List LkW :=
  let I := ids c
  let p := c.p
  match d with
  | .L => [⟨[(I.limb, 1)], 0, 8⟩, ⟨[(I.limbm, 1)], 0, 8⟩]
  | .D =>
    bytes I.xl none ++ bytes I.yl none ++ bytes I.nr none ++ bytes I.ns none ++ bytes I.al none
      ++ bytes I.ral (some p.ao) ++ bytes I.x1l none ++ bytes I.yml none ++ bytes I.mr none ++ bytes I.ms none
      ++ bytes I.zl none ++ bytes I.rdl (some p.down) ++ bytes I.x2l none
  | .Q => bytes I.ql none ++ bytes I.rql (some p.q) ++ bytes I.qrl none ++ bytes I.rqrl (some p.rope)
      ++ bytes I.ol none ++ bytes I.ro (some p.pv)
  | .Kv => bytes I.kl none ++ bytes I.rkl (some p.k) ++ bytes I.vl none ++ bytes I.rvl (some p.v)
      ++ bytes I.krl none ++ bytes I.rkrl (some p.rope)
  | .F => bytes I.rgl (some p.gate) ++ bytes I.ul none ++ bytes I.ru (some p.up) ++ bytes I.hl none ++ bytes I.rh none
  | .S => [⟨[(I.s, 1)], 127, 8⟩, ⟨[(I.s, -1)], 127, 8⟩] ++ bytes I.rsl (some p.score) ++ bytes I.pl (some (p.fp + 1))
      ++ bytes I.sr (some p.wrho) ++ bytes I.sg (some p.wrho)
  | _ => []

/-- A domain's LogUp helpers: one per pair of lookups. -/
def nHelp (d : Dom) : ℕ := ((lookups c d).length + 1) / 2

/-- `(first_l, first_d, first_q, first_kv, first_s, sexp, first_f, fact, gu8, n_range, u)` (no range sub-plane). -/
def hIdsN : List ℕ :=
  let fd := nHelp c .L
  let fq := fd + nHelp c .D
  let fkv := fq + nHelp c .Q
  let fs := fkv + nHelp c .Kv
  let sexp := fs + nHelp c .S
  let ff := sexp + 1
  let fact := ff + nHelp c .F
  let gu8 := fact + 1
  [0, fd, fq, fkv, fs, sexp, ff, fact, gu8, 0, gu8 + 3]

def fh (k : ℕ) : ℕ := (hIdsN c).getD k 0

/-- The `H` planes' domains, in plane order. -/
def hDoms : List Dom :=
  List.replicate (nHelp c .L) .L ++ List.replicate (nHelp c .D) .D ++ List.replicate (nHelp c .Q) .Q
    ++ List.replicate (nHelp c .Kv) .Kv ++ List.replicate (nHelp c .S) .S ++ [.S]
    ++ List.replicate (nHelp c .F) .F ++ [.F] ++ List.replicate 3 .Tab ++ [.Tab]

/-- **`h_off`**: an `H` plane's real half and its imaginary half. -/
def hOff (hp : ℕ) : ℕ × ℕ :=
  let row := (((hDoms c).take hp).map fun d => 2 * rowsOf c d).sum
  let d := (hDoms c).getD hp .Tab
  (row * 2 ^ c.logCols, (row + rowsOf c d) * 2 ^ c.logCols)

/-- `H`'s data rows. -/
def hDataRows : ℕ := ((hDoms c).map fun d => 2 * rowsOf c d).sum

/-- **The zero-rule planes of a domain** (`pad::zero_rule_a_planes`: every plane of a padded domain but `E`; R13 has no
range sub-plane). -/
def zeroPl (d : Dom) : List ℕ :=
  if c.sh.padRule && c.sh.pads d then (domPl c d).filter fun i => !(i == (ids c).e) else []

/-! ### The tables -/

def aPlane (q : ℕ) : TabS := aTab (aOff c q) (logOf c q) (rhoC 0 (logOf c q)) 0

def hTab (hp : ℕ) : TabS :=
  .priv ⟨.h, [((hOff c hp).1, false), ((hOff c hp).2, true)], c.sh.logs ((hDoms c).getD hp .Tab),
    rhoC 0 (c.sh.logs ((hDoms c).getD hp .Tab)), 0, 0⟩

/-! ### The draws (L17's `R13.draws`) -/

def seg (s j : ℕ) : List Sym :=
  let ds := (ZK60.Exec.Slot.R13.draws c.sh s).map Prod.snd
  (List.range (ds.getD j 0)).map fun i => Sym.dr s ((ds.take j).sum + i)

def claimPt (s : ℕ) : List Sym :=
  if s = scSS ∨ s = scSSM ∨ s = scRS then seg c s 0
  else if s = scQMM ∨ s = scWO ∨ s = scGMM ∨ s = scDMM then seg c s 0 ++ seg c s 1
  else if s = scKMM ∨ s = scVMM then seg c scQMM 0 ++ seg c s 0
  else if s = scUMM then seg c scGMM 0 ++ seg c s 0
  else if s = scSCORE then seg c s 0 ++ seg c s 1 ++ seg c s 2
  else if s = scPV then seg c s 1 ++ seg c s 0 ++ seg c s 2
  else []

def lksS (shaped : ℕ → ℕ) (d : Dom) : List (LkD Sym) :=
  (lookups c d).map fun l =>
    ⟨.sub .alpha (.add (.base l.cst) (.gtag (ZK60.Circuit.tagW l.tag))),
      l.terms.map fun t => (Sym.base (-t.2), shaped t.1)⟩

def padGroup (d : Dom) (gi : ℕ) (shaped : ℕ → ℕ) : List (ℕ × List ℕ) :=
  if supp c d && !(zeroPl c d).isEmpty then [(gi, (zeroPl c d).map shaped)] else []

end Layout

/-! ## The R13 zero-checks' IRs (`slot_ir_accuracy.rs`) -/

section Builders

variable {α : Type} (c : Cst α)

/-- `int16`: `x + 32768 − limbs`, its limbs node at `l` (slot_ir_accuracy.rs:94-97). -/
def int16B (x l : ℕ) : Body α := .sum [st c.one [.tab x], st (c.base 32768) [], st c.negOne [.node l]]

/-- `SC_DZC`'s tables the IR reads. -/
structure DzcR13 where
  ig : ℕ
  igm : ℕ
  x : ℕ
  y : ℕ
  ao : ℕ
  x1 : ℕ
  ym : ℕ
  z : ℕ
  x2 : ℕ
  id : ℕ
  idm : ℕ
  h0 : ℕ
  nr : List ℕ
  ns : List ℕ
  mr : List ℕ
  ms : List ℕ
  xl : List ℕ
  yl : List ℕ
  al : List ℕ
  ral : List ℕ
  x1l : List ℕ
  yml : List ℕ
  zl : List ℕ
  rdl : List ℕ
  x2l : List ℕ
  gate : Option ℕ

/-- `dzc`'s own nodes (slot_ir_accuracy.rs:170-190): the four norm remainders' limbs, `c0 … c12` (each int16 clause
after its limbs node), the batch. -/
def r13DzcPre (R : DzcR13) (K : DzcK) (mu : List α) : List (Body α) :=
  [limbsB c R.nr, limbsB c R.ns, limbsB c R.mr, limbsB c R.ms,
    .sum [st (c.base K.num) [.tab R.ig, .tab R.x], st (c.base K.dv) [.tab R.id], st (c.base (-K.den)) [.tab R.y, .tab R.id],
      st c.negOne [.node 0]],
    .sum [st c.one [.node 0], st c.one [.node 1], st c.one [], st (c.base (-K.den)) [.tab R.id]],
    limbsB c R.xl, int16B c R.x 6,
    limbsB c R.yl, int16B c R.y 8,
    limbsB c R.al, int16B c R.ao 10,
    limbsB c R.x1l, int16B c R.x1 12,
    .sum [st c.one [.tab R.x1], st c.negOne [.tab R.x], st c.negOne [.tab R.ao]],
    .sum [st (c.base K.numM) [.tab R.igm, .tab R.x1], st (c.base K.dv) [.tab R.idm],
      st (c.base (-K.den)) [.tab R.ym, .tab R.idm], st c.negOne [.node 2]],
    .sum [st c.one [.node 2], st c.one [.node 3], st c.one [], st (c.base (-K.den)) [.tab R.idm]],
    limbsB c R.yml, int16B c R.ym 17,
    limbsB c R.zl, int16B c R.z 19,
    limbsB c R.x2l, int16B c R.x2 21,
    .sum [st c.one [.tab R.x2], st c.negOne [.tab R.x1], st c.negOne [.tab R.z]],
    batchB c mu [4, 5, 7, 9, 11, 13, 14, 15, 16, 18, 20, 22, 23]]

/-- `dzc`'s host nodes: `requant(SC_WO)`, `requant(SC_DMM)` with byte limbs. -/
def r13DzcPost (R : DzcR13) (K : DzcK) (o : ℕ) : List (Body α) :=
  [limbsB c R.ral, reqB c K.sao R.ao o, limbsB c R.rdl, reqB c K.sdown R.z (o + 2)]

/-- **R13 `SC_DZC`** (slot_ir_accuracy.rs:124-192). -/
def r13DzcIr (R : DzcR13) (K : DzcK) (lks : List (LkD α)) (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    Ir α :=
  zcIr c (r13DzcPre c R K mu) lks R.h0 (fun k => mu.getD (13 + k) c.zero) [] (mu.getD (13 + (lks.length + 1) / 2) c.zero)
    zp groups [gatedSt c R.gate 24] (r13DzcPost c R K) (fun o => threeTerms c (0, 1, 2) R.gate o nu (o + 2) (o + 4))

structure QzcR13 where
  cos : ℕ
  sin : ℕ
  src : ℕ
  rot : ℕ
  oth : ℕ
  flip : ℕ
  h0 : ℕ
  rr : List ℕ
  wl : List ℕ
  rwl : List ℕ
  ol : List ℕ
  r1 : List ℕ
  r2 : List ℕ
  gate : Option ℕ

/-- `qzc`'s own nodes (slot_ir_accuracy.rs:282-300). -/
def r13QzcPre (R : QzcR13) (rope : ℕ) (mu : List α) : List (Body α) :=
  [limbsB c R.rr,
    .sum [st c.one [.tab R.cos, .tab R.src], st c.one [.tab R.sin, .tab R.flip], st (c.base (-(2 ^ rope : ℤ))) [.tab R.rot],
      st c.negOne [.node 0], st (c.base (2 ^ (rope - 1))) []],
    limbsB c R.wl, int16B c R.src 2,
    limbsB c R.rwl, int16B c R.rot 4,
    limbsB c R.ol, int16B c R.oth 6,
    batchB c mu [1, 3, 5, 7]]

def r13QzcPost (R : QzcR13) (s1 s2 : ℕ) (o : ℕ) : List (Body α) :=
  [limbsB c R.r1, reqB c s1 R.src o, limbsB c R.r2, reqB c s2 R.oth (o + 2)]

/-- **R13 `SC_QZC` / `SC_KVZC`** (slot_ir_accuracy.rs:243-307). -/
def r13QzcIr (R : QzcR13) (rope s1 s2 : ℕ) (lks : List (LkD α)) (mu nu : List α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (r13QzcPre c R rope mu) lks R.h0 (fun k => mu.getD (4 + k) c.zero) [] (mu.getD (4 + (lks.length + 1) / 2) c.zero)
    zp groups [gatedSt c R.gate 8] (r13QzcPost c R s1 s2) (fun o => threeTerms c (0, 1, 2) R.gate o nu (o + 2) (o + 4))

structure SzcR13 where
  mask : ℕ
  s8 : ℕ
  zsel : ℕ
  e : ℕ
  p : ℕ
  mx : ℕ
  sum : ℕ
  h0 : ℕ
  hx : ℕ
  sr : List ℕ
  sg : List ℕ
  pl : List ℕ
  rsl : List ℕ
  gHt : Option ℕ
  gS : Option ℕ

/-- `szc`'s own nodes (slot_ir_accuracy.rs:376-405): `δ`, `sr`, `sg`, `pl`, `c0 … c4`, `α − δ − β·e − g_exp`, `cx`, the
batch. `amdK = α − g_exp`, `nb = −β`. -/
def r13SzcPre (R : SzcR13) (fp : ℕ) (mu : List α) (amdK nb : α) : List (Body α) :=
  [.sum [st c.one [.tab R.mx], st c.negOne [.tab R.mask, .tab R.s8], st (c.base (-127)) [.tab R.mask], st (c.base 127) []],
    limbsB c R.sr, limbsB c R.sg, limbsB c R.pl,
    .sum [st c.one [.tab R.zsel, .tab R.zsel], st c.negOne [.tab R.zsel]],
    .sum [st c.one [.tab R.zsel, .node 0]],
    .sum [st (c.base (2 ^ fp)) [.tab R.mask, .tab R.e], st c.negOne [.tab R.p, .tab R.sum], st c.negOne [.node 1]],
    .sum [st c.one [.node 2], st c.one [.node 1], st c.one [], st c.negOne [.tab R.sum]],
    .sum [st c.one [.tab R.p], st c.negOne [.node 3]],
    .sum [st amdK [], st c.negOne [.node 0], st nb [.tab R.e]],
    .sum [st c.one [.tab R.hx, .node 9], st c.negOne []],
    batchB c mu [4, 5, 6, 7, 8]]

/-- `szc`'s host nodes: `sum + λ`, `rsl`, `2^score·s8 + rsl − 2^(score−1)` (slot_ir_accuracy.rs:412-419). -/
def r13SzcPost (R : SzcR13) (score : ℕ) (lam : α) (o : ℕ) : List (Body α) :=
  [.sum [st c.one [.tab R.sum], st lam []], limbsB c R.rsl, reqB c score R.s8 (o + 1)]

/-- **R13 `SC_SZC`**, non-DD (slot_ir_accuracy.rs:311-428). -/
def r13SzcIr (R : SzcR13) (fp score : ℕ) (lks : List (LkD α)) (mu nu : List α) (amdK nb lam : α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (r13SzcPre c R fp mu amdK nb) lks R.h0 (fun k => mu.getD (5 + k) c.zero)
    [st (mu.getD (5 + (lks.length + 1) / 2) c.zero) [.node 10]] (mu.getD (6 + (lks.length + 1) / 2) c.zero) zp groups
    [gatedSt c R.gS 11] (r13SzcPost c R score lam)
    (fun o => [⟨c.one, [0], [.node o]⟩, ⟨nu.getD 0 c.zero, 1 :: R.gHt.toList, [.node (o + 1)]⟩,
      ⟨nu.getD 1 c.zero, 2 :: R.gS.toList, [.node (o + 3)]⟩])

structure FzcR13 where
  g : ℕ
  a : ℕ
  u : ℕ
  h : ℕ
  fact : ℕ
  group : ℕ
  h0 : ℕ
  rh : List ℕ
  hl : List ℕ
  ul : List ℕ
  rg : List ℕ
  ru : List ℕ
  gate : Option ℕ

/-- `fzc`'s own nodes (slot_ir_accuracy.rs:226-238): `rh`, `hl`, `f0`, `f1` (after its limbs), `f2`, `α − query`,
`fa`, the batch. `amqK = α − 2048 − g_act`, `nb = −β`, `nb2 = −β²`. -/
def r13FzcPre (R : FzcR13) (r pb : ℕ) (mu : List α) (amqK nb nb2 : α) : List (Body α) :=
  [limbsB c R.rh, limbsB c R.hl,
    .sum [st c.one [.tab R.a, .tab R.u], st (c.base (-(2 ^ r : ℤ))) [.tab R.h], st c.negOne [.node 0],
      st (c.base (2 ^ (r - 1))) []],
    limbsB c R.ul, int16B c R.u 3,
    .sum [st c.one [.tab R.h], st (c.base (2 ^ (pb - 1))) [], st c.negOne [.node 1]],
    .affine amqK [(c.negOne, R.g), (nb, R.a), (nb2, R.group)],
    .sum [st c.one [.tab R.fact, .node 6], st c.negOne []],
    batchB c mu [2, 4, 5]]

def r13FzcPost (R : FzcR13) (sgate sup : ℕ) (o : ℕ) : List (Body α) :=
  [limbsB c R.rg, reqB c sgate R.g o, limbsB c R.ru, reqB c sup R.u (o + 2)]

/-- **R13 `SC_FZC`** (slot_ir_accuracy.rs:196-240). -/
def r13FzcIr (R : FzcR13) (r pb sgate sup : ℕ) (lks : List (LkD α)) (mu nu : List α) (amqK nb nb2 : α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) : Ir α :=
  zcIr c (r13FzcPre c R r pb mu amqK nb nb2) lks R.h0 (fun k => mu.getD (4 + k) c.zero) [st (mu.getD 3 c.zero) [.node 7]]
    (mu.getD (4 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c R.gate 8] (r13FzcPost c R sgate sup)
    (fun o => threeTerms c (0, 1, 2) R.gate o nu (o + 2) (o + 4))

end Builders

/-! ## The slots -/

section Slots

variable (c : W16Cfg)

/-- **Slot `s`'s R13 program**, before the reserved pairs and the public tables are numbered. -/
def rawSlot (s : ℕ) : SlotS :=
  let I := ids c
  let sh := c.sh
  let p := c.p
  let lt := sh.lt
  if s = scSS ∨ s = scSSM then
    let g := supp c .D
    ⟨[TabS.eq (seg c s 0) 0, aPlane c (if s = scSS then I.x else I.x1)] ++ (if g then [TabS.pub 0] else []),
      ssIr cstS 0 1 (optIx g 2), [], []⟩
  else if s = scTZC then
    let mu := seg c s 1
    let nu := seg c s 2
    let zeta := (seg c s 3).getD 0 .zero
    let g := supp c .T
    let tmap := fun (q : ℕ) => if q = I.d then 3 else if q = I.dsq then 4 else if q = I.dm then 14 else 15
    ⟨[TabS.eq (seg c s 0) 0, TabS.eq (claimPt c scSS) 0, TabS.eq (claimPt c scSSM) 0, aPlane c I.d, aPlane c I.dsq]
        ++ (List.range 9).map (fun k => aTab (aOff c I.limb + k * 2 ^ lt) lt (rhoC 0 lt) 0)
        ++ [aPlane c I.dm, aPlane c I.dsqm]
        ++ (List.range 9).map (fun k => aTab (aOff c I.limbm + k * 2 ^ lt) lt (rhoC 0 lt) 0)
        ++ (if g then [TabS.pub 0] else []),
      tzcIr cstS ⟨0, 1, 2, 3, 4, 14, 15, optIx g 25⟩ p.ceps mu nu (fun j => .pow zeta j) (padGroup c .T 25 tmap),
      [(scSS, nu.getD 0 .zero), (scSSM, nu.getD 1 .zero)], nu ++ seg c s 3⟩
  else if s = scLZC then
    let zeta := (seg c s 2).getD 0 .zero
    let g := supp c .L && !(zeroPl c .L).isEmpty
    let shaped := fun (q : ℕ) => if q = I.limb then 1 else 2
    ⟨[TabS.eq (seg c s 0) 0, aPlane c I.limb, aPlane c I.limbm, hTab c (fh c 0)] ++ (if g then [TabS.pub 0] else []),
      lzcIr cstS 0 3 (lksS c shaped .L) ((seg c s 1).getD 0 .zero) (fun j => .pow zeta j) (padGroup c .L 4 shaped),
      [], seg c s 2⟩
  else if s = scRS then
    let g := supp c .S
    ⟨[TabS.eq (seg c s 0) 0, TabS.pub 0, aPlane c I.e, aPlane c I.zsel] ++ (if g then [TabS.pub 0] else []),
      rsIr cstS 0 1 2 3 (optIx g 4) ((seg c s 1).getD 0 .zero), [], []⟩
  else if s = scQMM ∨ s = scKMM ∨ s = scVMM ∨ s = scWO then
    let rq := if s = scQMM ∨ s = scWO then seg c s 0 else seg c scQMM 0
    let plane := if s = scWO then I.o else I.y
    let inner := if s = scWO then sh.lq else sh.ld
    ⟨[aTab (aOff c plane) (logOf c plane) (rq.map CoordS.fixed ++ rhoC 0 inner) 0, TabS.pub 0], mmIr cstS 0 1, [], []⟩
  else if s = scGMM ∨ s = scUMM ∨ s = scDMM then
    let rrow := if s = scUMM then seg c scGMM 0 else seg c s 0
    let plane := if s = scDMM then I.h else I.ym
    let inner := if s = scDMM then sh.lf else sh.ld
    ⟨[aTab (aOff c plane) (logOf c plane) (rrow.map CoordS.fixed ++ rhoC 0 inner) 0, TabS.pub 0], mmIr cstS 0 1, [],
      []⟩
  else if s = scSCORE ∨ s = scPV then
    let lkv := sh.lkv
    let gq := decide (0 < lkv)
    let o := if gq then 1 else 0
    let rh := seg c s 0
    let rg := rh.take lkv
    let rhj := rh.drop lkv
    let rt := seg c s 1
    let r3 := seg c s 2
    let ab :=
      if s = scSCORE then
        [aTab (aOff c I.qr) (logOf c I.qr)
            (rt.map CoordS.fixed ++ rhoC 0 lkv ++ rhj.map CoordS.fixed ++ rhoC lkv (lkv + sh.ldh)) 0,
          aTab (aOff c I.kr) (logOf c I.kr) (r3.map CoordS.fixed ++ rhoC 0 lkv ++ rhoC lkv (lkv + sh.ldh)) 1]
      else
        [aTab (aOff c I.p) (logOf c I.p)
            (rhoC 0 lkv ++ rhj.map CoordS.fixed ++ rt.map CoordS.fixed ++ rhoC lkv (lkv + lt)) 0,
          aTab (aOff c I.v) (logOf c I.v) (rhoC lkv (lkv + lt) ++ rhoC 0 lkv ++ r3.map CoordS.fixed) 1]
    ⟨(if gq then [TabS.eq rg 0] else []) ++ ab, bilIr cstS (optIx gq 0) o (o + 1), [], []⟩
  else if s = scDZC then
    let mu := seg c s 0
    let nu := seg c s 1
    let zeta := (seg c s 2).getD 0 .zero
    let pls := domPl c .D
    let n := pls.length
    let nh := nHelp c .D
    let g := supp c .D
    let shaped := fun (q : ℕ) => 5 + (q - 8)
    let gi := 7 + n + nh
    ⟨[TabS.eq (seg c s 3) 0, TabS.eq (claimPt c scWO) 0, TabS.eq (claimPt c scDMM) 0, TabS.pub 0, TabS.pub 0]
        ++ pls.map (aPlane c)
        ++ [aTab (aOff c I.d) lt (rhoC 0 lt) 0, aTab (aOff c I.dm) lt (rhoC 0 lt) 0]
        ++ (List.range nh).map (fun j => hTab c (fh c 1 + j)) ++ (if g then [TabS.pub 0] else []),
      r13DzcIr cstS
        ⟨3, 4, shaped I.x, shaped I.y, shaped I.ao, shaped I.x1, shaped I.ym, shaped I.z, shaped I.x2, 5 + n, 6 + n,
          7 + n, I.nr.map shaped, I.ns.map shaped, I.mr.map shaped, I.ms.map shaped, I.xl.map shaped, I.yl.map shaped,
          I.al.map shaped, I.ral.map shaped, I.x1l.map shaped, I.yml.map shaped, I.zl.map shaped, I.rdl.map shaped,
          I.x2l.map shaped, optIx g gi⟩
        ⟨2 * p.cnA, 2 * p.cnM, 2 ^ p.tn, 2 ^ (p.tn + 1), p.ao, p.down⟩ (lksS c shaped .D) mu nu
        (fun j => .pow zeta j) (padGroup c .D gi shaped),
      [(scWO, nu.getD 0 .zero), (scDMM, nu.getD 1 .zero)], nu ++ seg c s 2⟩
  else if s = scQZC ∨ s = scKVZC then
    let isq := decide (s = scQZC)
    let d : Dom := if isq then .Q else .Kv
    let mu := seg c s 0
    let nu := seg c s 1
    let zeta := (seg c s 2).getD 0 .zero
    let pls := domPl c d
    let n := pls.length
    let nh := nHelp c d
    let g := supp c d
    let st := domStart c d
    let shaped := fun (q : ℕ) => 5 + (q - st)
    let src := if isq then I.q else I.k
    let log := sh.logs d
    let cf := (List.range log).map fun k => if k = log - sh.ldh then CoordS.flip k else CoordS.rho k
    let gi := 6 + n + nh
    ⟨[TabS.eq (seg c s 3) 0, TabS.eq (claimPt c (if isq then scQMM else scKMM)) 0,
          TabS.eq (claimPt c (if isq then scPV else scVMM)) 0, TabS.pub 0, TabS.pub 0] ++ pls.map (aPlane c)
        ++ [aTab (aOff c src) (logOf c src) cf 0]
        ++ (List.range nh).map (fun j => hTab c (fh c (if isq then 2 else 3) + j)) ++ (if g then [TabS.pub 0] else []),
      r13QzcIr cstS
        ⟨3, 4, shaped src, shaped (if isq then I.qr else I.kr), shaped (if isq then I.o else I.v), 5 + n, 6 + n,
          (if isq then I.rqrl else I.rkrl).map shaped, (if isq then I.ql else I.kl).map shaped,
          (if isq then I.qrl else I.krl).map shaped, (if isq then I.ol else I.vl).map shaped,
          (if isq then I.rql else I.rkl).map shaped, (if isq then I.ro else I.rvl).map shaped, optIx g gi⟩
        p.rope (if isq then p.q else p.k) (if isq then p.pv else p.v) (lksS c shaped d) mu nu
        (fun j => .pow zeta j) (padGroup c d gi shaped),
      (if isq then [(scQMM, nu.getD 0 .zero), (scPV, nu.getD 1 .zero)]
        else [(scKMM, nu.getD 0 .zero), (scVMM, nu.getD 1 .zero)]), nu ++ seg c s 2⟩
  else if s = scSZC then
    let mu := seg c s 1
    let nu := seg c s 2
    let zeta := (seg c s 3).getD 0 .zero
    let pls := domPl c .S
    let n := pls.length
    let nh := nHelp c .S
    let gh := supp c .Ht
    let gs := supp c .S
    let shaped := fun (q : ℕ) => 4 + (q - I.s0)
    let lht := sh.logs .Ht
    let hx := 6 + n + nh
    let ghi := hx + 1
    let gsi := if gh then hx + 2 else hx + 1
    let gHt := if gh && !(zeroPl c .Ht).isEmpty then [(ghi, [4 + n, 5 + n])] else []
    ⟨[TabS.eq (seg c s 0) 0, TabS.eq (claimPt c scRS) 0, TabS.eq (claimPt c scSCORE) 0, TabS.pub 0]
        ++ pls.map (aPlane c)
        ++ [aTab (aOff c I.mx) lht (rhoC 0 lht) 0, aTab (aOff c I.sum) lht (rhoC 0 lht) 0]
        ++ (List.range nh).map (fun j => hTab c (fh c 4 + j)) ++ [hTab c (fh c 5)]
        ++ (if gh then [TabS.pub 0] else []) ++ (if gs then [TabS.pub 0] else []),
      r13SzcIr cstS
        ⟨3, shaped I.s, shaped I.zsel, shaped I.e, shaped I.p, 4 + n, 5 + n, 6 + n, hx, I.sr.map shaped,
          I.sg.map shaped, I.pl.map shaped, I.rsl.map shaped, optIx gh ghi, optIx gs gsi⟩
        p.fp p.score (lksS c shaped .S) mu nu (.sub .alpha (.gtag 129)) (.neg .beta) ((seg c scRS 1).getD 0 .zero)
        (fun j => .pow zeta j) (gHt ++ padGroup c .S gsi shaped),
      [(scRS, .mul (nu.getD 0 .zero) (.base sh.perRow)), (scSCORE, nu.getD 1 .zero)], nu ++ seg c s 3⟩
  else if s = scFZC then
    let mu := seg c s 0
    let nu := seg c s 1
    let zeta := (seg c s 2).getD 0 .zero
    let pls := domPl c .F
    let n := pls.length
    let nh := nHelp c .F
    let g := supp c .F
    let shaped := fun (q : ℕ) => 3 + (q - I.f0)
    let gi := 5 + n + nh
    ⟨[TabS.eq (seg c s 3) 0, TabS.eq (claimPt c scGMM) 0, TabS.eq (claimPt c scUMM) 0] ++ pls.map (aPlane c)
        ++ (List.range nh).map (fun j => hTab c (fh c 6 + j)) ++ [hTab c (fh c 7), TabS.pub 0]
        ++ (if g then [TabS.pub 0] else []),
      r13FzcIr cstS
        ⟨shaped I.g, shaped I.a, shaped I.u, shaped I.h, 3 + n + nh, 4 + n + nh, 3 + n, I.rh.map shaped,
          I.hl.map shaped, I.ul.map shaped, I.rgl.map shaped, I.ru.map shaped, optIx g gi⟩
        p.fold p.prodbits p.gate p.up (lksS c shaped .F) mu nu (.sub (.sub .alpha (.base 2048)) (.gtag 134))
        (.neg .beta) (.neg (.mul .beta .beta)) (fun j => .pow zeta j) (padGroup c .F gi shaped),
      [(scGMM, nu.getD 0 .zero), (scUMM, nu.getD 1 .zero)], nu ++ seg c s 2⟩
  else if s = scTAB then
    -- `argument_accuracy.rs:416-444` (`tab`): the code has no IR for it (finding L17-9); L13's `tabIr` at its tables
    let mu := seg c s 1
    let zeta := (seg c s 2).getD 0 .zero
    let gu := fh c 8
    let padOn := !(zeroPl c .Tab).isEmpty
    let gb := supp c .Tab
    let base := 10
    let actI := if gb then base + 1 else base
    let ts : List (ℕ × ℕ × ℕ) := [(1, 2, 3), (4, 5, 6), (7, 8, 9)]
    let groups := if padOn then (if gb then [(base, [1, 4]), (base, [2, 5])] else []) ++ [(actI, [7]), (actI, [8])]
      else []
    ⟨[TabS.eq (seg c s 0) 0]
        ++ [aPlane c I.mu8, hTab c gu, TabS.pub 0, aPlane c I.mexp, hTab c (gu + 1), TabS.pub 0,
          aPlane c I.mact, hTab c (gu + 2), TabS.pub 0]
        ++ (if padOn then (if gb then [TabS.pub 0] else []) ++ [TabS.pub 0] else []),
      tabIr cstS 0 .alpha ts mu (fun j => .pow zeta j) groups, [], seg c s 2⟩
  else if s = scZS then ⟨[TabS.pub 0, hTab c (fh c 10)], zsIr cstS 0 1, [], []⟩
  else if s = scIOIN ∨ s = scIOOUT then
    ⟨[TabS.eq (seg c s 0) 0, aPlane c (if s = scIOIN then I.x else I.x2), epTab c (if s = scIOIN then .inp else .out)],
      ioIr cstS 0 1 2, [], []⟩
  else SlotS.empty

/-- The slots in order, before the numbering. -/
def rawProg : List SlotS := (List.range nSlots).map (rawSlot c)

/-- **The R13 block's slot program**, with the reserved pairs numbered (`a_site`, `h_site`, `io_mask_row`) as L35's
`progW16` numbers them. -/
def progR13 (ioIn ioOut : ℕ) : List SlotS := numProg (aDataRows c) (hDataRows c) ioIn ioOut 0 0 (rawProg c)

end Slots

/-! ## The configurations -/

/-- **The R13 development rung** (`R13_RUNG_H24`; its precision is the W16R2 rung's: the corpus's IR constants
`2·cn = 8000`, `2^tn = 4`, the hosts' shifts `21, 20, 15, 12, 15, 16, 18, 19, 12`, the product fold `16`, `f_p = 12`,
`wrho = 17`, all checked by `BlockR13ProgCheck` against the code's IR). -/
def cfgRungR13 : W16Cfg := ⟨ZK60.Exec.Slot.R13.shRungR13, DefW16.precRungW16, [], 14⟩

/-- **One layer of the Shieldstral T128 R13 block** at the precision `derive` gives it (`RunShapeShield.shieldCal`:
`tn = 1`, `ceps = 2439`, the layer's `cn_a`, `cn_m`, `score = sh_s + 12`, `ao = sh_ao + 14`, `down = sh_z + 14`, the
gate fold's shift, `wrho = 16`). -/
def precShieldR13 (L : ZK60.RunShape.Shield.ShieldLayer) : PrecW :=
  { h24 := true, tn := 1, cnA := L.cnA, cnM := L.cnM, ceps := 2439, q := 15, k := 15, v := 16, score := L.s + 12,
    pv := 12, ao := L.ao + 14, gate := L.gate, up := 12, prodbits := 24, down := L.z + 14, fp := 12, wrho := 16, rope := 7,
    fold := 16 }

def cfgShieldR13 (L : ZK60.RunShape.Shield.ShieldLayer) : W16Cfg :=
  ⟨ZK60.Exec.Slot.R13.shShieldR13, precShieldR13 L, [], 14⟩

/-! ## The numbering keeps the counts and the check -/

/-- The numbering keeps the counts. -/
theorem progR13_cm (c : W16Cfg) (cm : Cm) (ioIn ioOut : ℕ) :
    (progR13 c ioIn ioOut).map (fun s => cmCountS cm s.tabs) = (rawProg c).map (fun s => cmCountS cm s.tabs) := by
  unfold progR13
  rw [DefW16.numProg_cm]

/-- The numbering keeps the check. -/
theorem progR13_okb (c : W16Cfg) (rl : Cm → ℕ) (sl : List (ℕ × ℕ × ℕ)) (ioIn ioOut : ℕ) :
    progOKb rl (progR13 c ioIn ioOut) sl = progOKb rl (rawProg c) sl := by
  unfold progR13
  rw [DefW16.numProg_ok]

end ZK60.Exec.Block.DefR13
