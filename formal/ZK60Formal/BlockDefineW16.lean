/-
D63 lane L35 (2026-11-09), part 6: **the W16R2 block's `define`, as a library definition** (L31 §6 item 2, L23 §5
item 2, L13 §3: "the adapter is not written here").

`progW16 c` is the slot program (`BlockDefineSym.lean`) of ONE W16R2 block: its 23 slots' tables, with every private
table's `Priv` (commitment, slices, log size, coordinates, reserved mask pair, extension round), every `eq` point and
every public table's place, and each slot's round polynomial as L13's IR builder (`SlotW16Build.lean`) at the block's
table positions. It is a function of the block's configuration `W16Cfg` alone: the shape facts (`ShapeW`, L11), the
precision (`PrecW`, L13), the range families, the row log and the endpoints' reserved rows. Every coefficient is an
expression in the transcript's values (`Sym`); `defineS (progW16 c) pubs` is the block's `define`.

Mirrored (read 2026-11-09; nothing there is changed), under `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`:
* `argument.rs`: `B` (the table builder: `eq`, `group_eq`, `public`, `a_slice`, `a_at`, `a`, `a_range`, `h`,
  `endpoint`, `supp`, lines 1519-1685), `define`'s arms `SC_SS`, `SC_SSM`, `SC_TZC`, `SC_LZC`, `SC_RS`, the seven
  matmuls, `SC_SCORE`, `SC_PV`, `SC_ZS`, `SC_IO_*` (2029-2344, 2872-2964), `lk_tables` (1746);
* `argument_accuracy.rs`: the W16 arms `dzc_w16`, `fzc_w16`, `qzc_w16`, `szc_w16`, `tab_w16` (461-780);
* `layout.rs`: `Layout::new`'s plane allocation (`a_off`, `h_off`: a plane starts on a row, `rows_of(dom)` rows each,
  an `H` plane's imaginary half right after its real half; the reserved pairs after the data rows, two rows per site
  in slot order, `a_site`, `h_site`; `limb_off`), lines 1316-1407, 1496-1525; `shape.rs::rows_of` (2455);
* `accuracy_layout.rs::new_w16`, `lookups_w16` and `layout.rs::HIds::new`: the plane ids, here as NUMBERS
  (`idsW`, `lookupsN`, `hIdsN`), L13's `aPlanes`, `lookupsW`, `hIds` with the names resolved (the agreement check
  `BlockDefineCheck.lean` compares the two, and both with the code's export).

The slot IRs are L13's builders at the constants `cstS` and the draws as expressions, with the table positions
`SlotW16BuildCheck.build` uses (that function, moved to the library with numbers for names).

No theorem here: the facts about `progW16` at a shape are evaluated in `BlockDefineW16Rung.lean`.
-/
import ZK60Formal.BlockDefineSym
import ZK60Formal.SlotPolyW16Draw
import ZK60Formal.SlotPolyW16Map
import ZK60Formal.SlotW16Build
import ZK60Formal.SlotW16BuildLayout

set_option autoImplicit false

namespace ZK60.Exec.Block.DefW16

open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Exec.Slot.Build
open ZK60.Exec.Slot.Build.Lay (PrecW LkW limbsOf remLks rhWidth fullW)
open ZK60.Exec.Slot.W16R2 (Dom ShapeW scSS scSSM scTZC scLZC scRS scQMM scKMM scVMM scSCORE scPV scWO scGMM scUMM
  scDMM scDZC scQZC scKVZC scSZC scFZC scTAB scZS scIOIN scIOOUT nSlots)

/-- **One W16R2 block's configuration**: its shape facts, its precision, its range families `(width, sub-planes)`
and its row log. -/
structure W16Cfg where
  sh : ShapeW
  p : PrecW
  fams : List (ℕ × ℕ)
  logCols : ℕ

/-- The builders' constants, as expressions. -/
def cstS : Cst Sym := ⟨.one, .negOne, .zero, .base, .p16, .p256⟩

/-! ## The plane ids (`AccuracyIds::new_w16`, non-DD), as numbers -/

/-- **The `A` planes' ids**: the words and the limb groups in plane order, and where each domain's planes start. -/
structure IdsW where
  d : ℕ
  dsq : ℕ
  dm : ℕ
  dsqm : ℕ
  mx : ℕ
  sum : ℕ
  limb : ℕ
  limbm : ℕ
  x : ℕ
  y : ℕ
  nr : List ℕ
  ns : List ℕ
  ao : ℕ
  ral : List ℕ
  x1 : ℕ
  ym : ℕ
  mr : List ℕ
  ms : List ℕ
  z : ℕ
  rdl : List ℕ
  x2 : ℕ
  q : ℕ
  rql : List ℕ
  qr : ℕ
  rqrl : List ℕ
  o : ℕ
  ro : List ℕ
  k : ℕ
  rkl : List ℕ
  v : ℕ
  rvl : List ℕ
  kr : ℕ
  rkrl : List ℕ
  s : ℕ
  rsl : List ℕ
  zsel : ℕ
  e : ℕ
  pp : ℕ
  sr : List ℕ
  sg : List ℕ
  g : ℕ
  rgl : List ℕ
  a : ℕ
  u : ℕ
  ru : List ℕ
  h : ℕ
  ht : List ℕ
  rh : List ℕ
  q0 : ℕ
  k0 : ℕ
  s0 : ℕ
  f0 : ℕ
  t0 : ℕ

/-- The ids at a precision (the limb counts move them). -/
def idsW (p : PrecW) : IdsW :=
  let la := limbsOf p.ao
  let ld := limbsOf p.down
  let lq := limbsOf p.q
  let lr := limbsOf p.rope
  let lpv := limbsOf p.pv
  let lk := limbsOf p.k
  let lv := limbsOf p.v
  let lsc := limbsOf p.score
  let lw := limbsOf p.wrho
  let lg := limbsOf p.gate
  let lu := limbsOf p.up
  let lht := if p.h24 then 1 else 0
  let lrh := limbsOf (rhWidth p.h24)
  let q0 := 23 + la + ld
  let k0 := q0 + 3 + lq + lr + lpv
  let s0 := k0 + 3 + lk + lv + lr
  let f0 := s0 + 4 + lsc + lw + lw
  let t0 := f0 + 4 + lg + lu + lht + lrh
  { d := 0, dsq := 1, dm := 2, dsqm := 3, mx := 4, sum := 5, limb := 6, limbm := 7, x := 8, y := 9, nr := [10, 11],
    ns := [12, 13], ao := 14, ral := List.range' 15 la, x1 := 15 + la, ym := 16 + la, mr := [17 + la, 18 + la],
    ms := [19 + la, 20 + la], z := 21 + la, rdl := List.range' (22 + la) ld, x2 := 22 + la + ld, q := q0,
    rql := List.range' (q0 + 1) lq, qr := q0 + 1 + lq, rqrl := List.range' (q0 + 2 + lq) lr, o := q0 + 2 + lq + lr,
    ro := List.range' (q0 + 3 + lq + lr) lpv, k := k0, rkl := List.range' (k0 + 1) lk, v := k0 + 1 + lk,
    rvl := List.range' (k0 + 2 + lk) lv, kr := k0 + 2 + lk + lv, rkrl := List.range' (k0 + 3 + lk + lv) lr, s := s0,
    rsl := List.range' (s0 + 1) lsc, zsel := s0 + 1 + lsc, e := s0 + 2 + lsc, pp := s0 + 3 + lsc,
    sr := List.range' (s0 + 4 + lsc) lw, sg := List.range' (s0 + 4 + lsc + lw) lw, g := f0,
    rgl := List.range' (f0 + 1) lg, a := f0 + 1 + lg, u := f0 + 2 + lg, ru := List.range' (f0 + 3 + lg) lu,
    h := f0 + 3 + lg + lu, ht := List.range' (f0 + 4 + lg + lu) lht, rh := List.range' (f0 + 4 + lg + lu + lht) lrh,
    q0 := q0, k0 := k0, s0 := s0, f0 := f0, t0 := t0 }

/-- The nine domains, in `ALL_DOMS` order. -/
def allDoms : List Dom := [.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab]

section Layout

variable (c : W16Cfg)

/-- The range sub-planes' count. -/
def nRange : ℕ := (c.fams.map Prod.snd).sum

/-- Each range sub-plane's width. -/
def subW : List ℕ := c.fams.flatMap fun f => List.replicate f.2 f.1

def domStart (d : Dom) : ℕ :=
  match d with
  | .T => 0 | .Ht => 4 | .L => 6 | .D => 8 | .Q => (idsW c.p).q0 | .Kv => (idsW c.p).k0 | .S => (idsW c.p).s0
  | .F => (idsW c.p).f0 | .Tab => (idsW c.p).t0

def domEnd (d : Dom) : ℕ :=
  match d with
  | .T => 4 | .Ht => 6 | .L => 8 | .D => (idsW c.p).q0 | .Q => (idsW c.p).k0 | .Kv => (idsW c.p).s0
  | .S => (idsW c.p).f0 | .F => (idsW c.p).t0 | .Tab => (idsW c.p).t0 + 3 + nRange c

/-- A domain's `A` planes, in plane order. -/
def domPl (d : Dom) : List ℕ := List.range' (domStart c d) (domEnd c d - domStart c d)

/-- The domain of an `A` plane. -/
def planeDom (q : ℕ) : Dom := (allDoms.find? fun d => decide (q < domEnd c d)).getD .Tab

/-- `Shape::rows_of`: the rows one plane of a domain takes. -/
def rowsOf (d : Dom) : ℕ := max 1 (2 ^ c.sh.logs d / 2 ^ c.logCols)

/-- The first row of a domain's `A` planes. -/
def domRow (d : Dom) : ℕ :=
  ((allDoms.takeWhile fun d' => d' != d).map fun d' => (domEnd c d' - domStart c d') * rowsOf c d').sum

/-- **`a_off`**: an `A` plane's first element. -/
def aOff (q : ℕ) : ℕ :=
  (domRow c (planeDom c q) + (q - domStart c (planeDom c q)) * rowsOf c (planeDom c q)) * 2 ^ c.logCols

/-- `A`'s data rows (the reserved pairs start here). -/
def aDataRows : ℕ := (allDoms.map fun d => (domEnd c d - domStart c d) * rowsOf c d).sum

/-- The log size of an `A` plane (its domain's). -/
def logOf (q : ℕ) : ℕ := c.sh.logs (planeDom c q)

/-! ### The lookups (`lookups_w16`) and the helper planes (`HIds::new`) -/

/-- **The lookups of a domain**, in order (L13's `lookupsW` on the numeric ids). -/
def lookupsN (d : Dom) : List LkW :=
  let I := idsW c.p
  let w := fun (q : ℕ) => [(⟨[(q, 1)], 32768, 16⟩ : LkW)]
  match d with
  | .L => [⟨[(I.limb, 1)], 0, 8⟩, ⟨[(I.limbm, 1)], 0, 8⟩]
  | .D =>
    w I.x ++ w I.y ++ remLks I.nr 24 ++ remLks I.ns 24 ++ w I.ao ++ remLks I.ral c.p.ao ++ w I.x1 ++ w I.ym
      ++ remLks I.mr 24 ++ remLks I.ms 24 ++ w I.z ++ remLks I.rdl c.p.down ++ w I.x2
  | .Q => w I.q ++ remLks I.rql c.p.q ++ w I.qr ++ remLks I.rqrl c.p.rope ++ w I.o ++ remLks I.ro c.p.pv
  | .Kv => w I.k ++ remLks I.rkl c.p.k ++ w I.v ++ remLks I.rvl c.p.v ++ w I.kr ++ remLks I.rkrl c.p.rope
  | .F =>
    let bias : ℤ := 2 ^ (c.p.prodbits - 1)
    remLks I.rgl c.p.gate ++ [⟨[(I.u, 1)], 32768, 16⟩] ++ remLks I.ru c.p.up
      ++ (if c.p.h24 then [⟨[(I.h, 1), (I.ht.headD 0, -65536)], bias % 65536, 16⟩,
            ⟨[(I.ht.headD 0, 1)], bias / 65536, 8⟩]
          else [⟨[(I.h, 1)], bias, 16⟩])
      ++ remLks I.rh (rhWidth c.p.h24)
  | .S =>
    [⟨[(I.s, 1)], 127, 8⟩, ⟨[(I.s, -1)], 127, 8⟩] ++ remLks I.rsl c.p.score ++ [⟨[(I.pp, 1)], 0, c.p.fp + 1⟩]
      ++ remLks I.sr c.p.wrho ++ remLks I.sg c.p.wrho
  | _ => []

/-- A domain's LogUp helpers: one per pair of lookups. -/
def nHelp (d : Dom) : ℕ := ((lookupsN c d).length + 1) / 2

/-- `(first_l, first_d, first_q, first_kv, first_s, sexp, first_f, fact, gu8, n_range, u)`. -/
def hIdsN : List ℕ :=
  let fd := nHelp c .L
  let fq := fd + nHelp c .D
  let fkv := fq + nHelp c .Q
  let fs := fkv + nHelp c .Kv
  let sexp := fs + nHelp c .S
  let ff := sexp + 1
  let fact := ff + nHelp c .F
  let gu8 := fact + 1
  [0, fd, fq, fkv, fs, sexp, ff, fact, gu8, nRange c, gu8 + 3 + nRange c]

def fh (k : ℕ) : ℕ := (hIdsN c).getD k 0

/-- The `H` planes' domains, in plane order. -/
def hDoms : List Dom :=
  List.replicate (nHelp c .L) .L ++ List.replicate (nHelp c .D) .D ++ List.replicate (nHelp c .Q) .Q
    ++ List.replicate (nHelp c .Kv) .Kv ++ List.replicate (nHelp c .S) .S ++ [.S]
    ++ List.replicate (nHelp c .F) .F ++ [.F] ++ List.replicate (3 + nRange c) .Tab ++ [.Tab]

/-- **`h_off`**: an `H` plane's real half and, right after it, its imaginary half. -/
def hOff (hp : ℕ) : ℕ × ℕ :=
  let row := (((hDoms c).take hp).map fun d => 2 * rowsOf c d).sum
  let d := (hDoms c).getD hp .Tab
  (row * 2 ^ c.logCols, (row + rowsOf c d) * 2 ^ c.logCols)

/-- `H`'s data rows. -/
def hDataRows : ℕ := ((hDoms c).map fun d => 2 * rowsOf c d).sum

/-- **The zero-rule planes of a domain** (`pad::zero_rule_a_planes`): every plane of a padded domain except `E` and
the sub-planes of a full range family. -/
def zeroPl (d : Dom) : List ℕ :=
  if c.sh.padRule && c.sh.pads d then
    (domPl c d).filter fun i =>
      !(i == (idsW c.p).e)
        && !(decide ((idsW c.p).t0 + 3 ≤ i) && fullW ((subW c).getD (i - ((idsW c.p).t0 + 3)) 0) c.logCols)
  else []

/-! ### The table builder (`argument::B`); the reserved pairs and the public tables are numbered afterwards -/

/-- `rho(a..b)`. -/
def rhoC (a b : ℕ) : List CoordS := (List.range' a (b - a)).map CoordS.rho

/-- `a_slice`. -/
def aTab (off log : ℕ) (coords : List CoordS) (ext : ℕ) : TabS := .priv ⟨.a, [(off, false)], log, coords, 0, ext⟩

/-- `a`: an `A` plane on its own domain. -/
def aPlane (q : ℕ) : TabS := aTab (aOff c q) (logOf c q) (rhoC 0 (logOf c q)) 0

/-- `h`: a helper plane on its own domain, `re + u·im`. -/
def hTab (hp : ℕ) : TabS :=
  .priv ⟨.h, [((hOff c hp).1, false), ((hOff c hp).2, true)], c.sh.logs ((hDoms c).getD hp .Tab),
    rhoC 0 (c.sh.logs ((hDoms c).getD hp .Tab)), 0, 0⟩

/-- `endpoint`. -/
def epTab (cm : Cm) : TabS := .priv ⟨cm, [(0, false)], c.sh.logs .D, rhoC 0 (c.sh.logs .D), 0, 0⟩

/-- `supp(dom)` is a table of the slot exactly when the profile carries the pad rule and the domain pads. -/
def supp (d : Dom) : Bool := c.sh.padRule && c.sh.pads d

def optIx (b : Bool) (i : ℕ) : Option ℕ := if b then some i else none

/-! ### The draws, as expressions -/

/-- The `j`-th run of draws of slot `s`'s `define` (L11's `draws`, by position). -/
def seg (s j : ℕ) : List Sym :=
  let ds := (ZK60.Exec.Slot.W16R2.draws c.sh s).map Prod.snd
  (List.range (ds.getD j 0)).map fun i => Sym.dr s ((ds.take j).sum + i)

/-- **The claim point a private slot publishes** (L11's `claimPoint`). -/
def claimPt (s : ℕ) : List Sym :=
  if s = scSS ∨ s = scSSM ∨ s = scRS then seg c s 0
  else if s = scQMM ∨ s = scWO ∨ s = scGMM ∨ s = scDMM then seg c s 0 ++ seg c s 1
  else if s = scKMM ∨ s = scVMM then seg c scQMM 0 ++ seg c s 0
  else if s = scUMM then seg c scGMM 0 ++ seg c s 0
  else if s = scSCORE then seg c s 0 ++ seg c s 1 ++ seg c s 2
  else if s = scPV then seg c s 1 ++ seg c s 0 ++ seg c s 2
  else []

/-- `logup_subterms`' lookups, through the slot's plane-to-table map. -/
def lksS (shaped : ℕ → ℕ) (d : Dom) : List (LkD Sym) :=
  (lookupsN c d).map fun l =>
    ⟨.sub .alpha (.add (.base l.cst) (.gtag (ZK60.Circuit.tagW l.tag))),
      l.terms.map fun t => (Sym.base (-t.2), shaped t.1)⟩

/-- A pad group, where the slot's domain pads and has zero-rule planes. -/
def padGroup (d : Dom) (gi : ℕ) (shaped : ℕ → ℕ) : List (ℕ × List ℕ) :=
  if supp c d && !(zeroPl c d).isEmpty then [(gi, (zeroPl c d).map shaped)] else []

/-! ### The slots -/

/-- **Slot `s`'s program**, before the reserved pairs and the public tables are numbered. -/
def rawSlot (s : ℕ) : SlotS :=
  let I := idsW c.p
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
        [aTab (aOff c I.pp) (logOf c I.pp)
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
    ⟨[TabS.eq (seg c s 3) 0, TabS.eq (claimPt c scWO) 0, TabS.eq (claimPt c scDMM) 0, TabS.pub 0, TabS.pub 0] ++ pls.map (aPlane c)
        ++ [aTab (aOff c I.d) lt (rhoC 0 lt) 0, aTab (aOff c I.dm) lt (rhoC 0 lt) 0]
        ++ (List.range nh).map (fun j => hTab c (fh c 1 + j)) ++ (if g then [TabS.pub 0] else []),
      dzcIr cstS
        ⟨0, 1, 2, 3, 4, shaped I.x, shaped I.y, shaped I.ao, shaped I.x1, shaped I.ym, shaped I.z, shaped I.x2,
          I.nr.map shaped, I.ns.map shaped, I.mr.map shaped, I.ms.map shaped, I.ral.map shaped, I.rdl.map shaped,
          5 + n, 6 + n, 7 + n, optIx g gi⟩
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
      qzcIr cstS
        ⟨0, 1, 2, 3, 4, shaped src, shaped (if isq then I.qr else I.kr), shaped (if isq then I.o else I.v), 5 + n,
          (if isq then I.rqrl else I.rkrl).map shaped, (if isq then I.rql else I.rkl).map shaped,
          (if isq then I.ro else I.rvl).map shaped, 6 + n, optIx g gi⟩
        ⟨p.rope, if isq then p.q else p.k, if isq then p.pv else p.v⟩ (lksS c shaped d) mu nu
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
    ⟨[TabS.eq (seg c s 0) 0, TabS.eq (claimPt c scRS) 0, TabS.eq (claimPt c scSCORE) 0, TabS.pub 0] ++ pls.map (aPlane c)
        ++ [aTab (aOff c I.mx) lht (rhoC 0 lht) 0, aTab (aOff c I.sum) lht (rhoC 0 lht) 0]
        ++ (List.range nh).map (fun j => hTab c (fh c 4 + j)) ++ [hTab c (fh c 5)]
        ++ (if gh then [TabS.pub 0] else []) ++ (if gs then [TabS.pub 0] else []),
      szcIr cstS
        ⟨0, 1, 2, 3, shaped I.s, shaped I.zsel, shaped I.e, shaped I.pp, I.sr.map shaped, I.sg.map shaped,
          I.rsl.map shaped, 4 + n, 5 + n, 6 + n, hx, optIx gh ghi, optIx gs gsi⟩
        ⟨127, p.fp, p.score⟩ (lksS c shaped .S) mu nu (.sub .alpha (.gtag 129)) (.neg .beta)
        ((seg c scRS 1).getD 0 .zero) (fun j => .pow zeta j) (gHt ++ padGroup c .S gsi shaped),
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
      fzcIr cstS
        ⟨0, 1, 2, shaped I.g, shaped I.a, shaped I.u, shaped I.h, I.rgl.map shaped, I.ru.map shaped,
          I.rh.map shaped, 3 + n, 3 + n + nh, 4 + n + nh, optIx g gi⟩
        ⟨p.fold, p.gate, p.up⟩ (lksS c shaped .F) mu nu (.sub (.sub .alpha (.base 2048)) (.gtag 134)) (.neg .beta)
        (.neg (.mul .beta .beta)) (fun j => .pow zeta j) (padGroup c .F gi shaped),
      [(scGMM, nu.getD 0 .zero), (scUMM, nu.getD 1 .zero)], nu ++ seg c s 2⟩
  else if s = scTAB then
    let mu := seg c s 1
    let zeta := (seg c s 2).getD 0 .zero
    let nr := nRange c
    let gu := fh c 8
    let padOn := !(zeroPl c .Tab).isEmpty
    let gb := supp c .Tab
    let narrow := (List.range nr).filter fun j => !(fullW ((subW c).getD j 0) c.logCols)
    let base := 1 + 3 * (3 + nr)
    let actI := if gb then base + 1 else base
    let ts := (List.range (3 + nr)).map fun k => (1 + 3 * k, 2 + 3 * k, 3 + 3 * k)
    let t := fun (k : ℕ) => ts.getD k (0, 0, 0)
    let groups :=
      if padOn then
        (if gb then [(base, [(t 0).1, (t 1).1]), (base, [(t 0).2.1, (t 1).2.1])] else [])
          ++ [(actI, [(t 2).1]), (actI, [(t 2).2.1])]
          ++ (narrow.zipIdx.flatMap fun q =>
            [(actI + 1 + q.2, [(t (3 + q.1)).1]), (actI + 1 + q.2, [(t (3 + q.1)).2.1])])
      else []
    ⟨[TabS.eq (seg c s 0) 0]
        ++ (List.range (3 + nr)).flatMap (fun k => [aPlane c (I.t0 + k), hTab c (gu + k), TabS.pub 0])
        ++ (if padOn then (if gb then [TabS.pub 0] else []) ++ [TabS.pub 0] ++ narrow.map (fun _ => TabS.pub 0) else []),
      tabIr cstS 0 .alpha ts mu (fun j => .pow zeta j) groups, [], seg c s 2⟩
  else if s = scZS then ⟨[TabS.pub 0, hTab c (fh c 10)], zsIr cstS 0 1, [], []⟩
  else if s = scIOIN ∨ s = scIOOUT then
    ⟨[TabS.eq (seg c s 0) 0, aPlane c (if s = scIOIN then I.x else I.x2), epTab c (if s = scIOIN then .inp else .out)],
      ioIr cstS 0 1 2, [], []⟩
  else SlotS.empty

/-! ### Numbering the reserved pairs (`a_site`, `h_site`, `io_mask_row`) and the public tables -/

/-- The slots of a block in order, before the numbering. -/
def rawProg : List SlotS := (List.range nSlots).map (rawSlot c)

end Layout

/-- A private table with its reserved pair: site `ak` of `A` (`a_site`), site `hk` of `H` (`h_site`), or the
endpoint commitment's own pair (`io_mask_row`). -/
def setRow (aBase hBase ioIn ioOut ak hk : ℕ) (p : PrivS) : PrivS :=
  { p with maskRow := match p.cm with
      | .a => aBase + 2 * ak
      | .h => hBase + 2 * hk
      | .inp => ioIn
      | .out => ioOut }

/-- One slot's tables, with `ak` and `hk` claim sites of `A` and `H` used so far in the block and `pk` public tables
so far in the slot. -/
def numTabs (aBase hBase ioIn ioOut : ℕ) : ℕ → ℕ → ℕ → List TabS → List TabS
  | _, _, _, [] => []
  | ak, hk, pk, .priv p :: ts =>
    TabS.priv (setRow aBase hBase ioIn ioOut ak hk p)
      :: numTabs aBase hBase ioIn ioOut (ak + (if p.cm = Cm.a then 1 else 0)) (hk + (if p.cm = Cm.h then 1 else 0))
        pk ts
  | ak, hk, pk, .pub _ :: ts => TabS.pub pk :: numTabs aBase hBase ioIn ioOut ak hk (pk + 1) ts
  | ak, hk, pk, .eq pt st :: ts => TabS.eq pt st :: numTabs aBase hBase ioIn ioOut ak hk pk ts

/-- One slot, numbered. -/
def numSlot (aBase hBase ioIn ioOut ak hk : ℕ) (s : SlotS) : SlotS :=
  ⟨numTabs aBase hBase ioIn ioOut ak hk 0 s.tabs, s.ir, s.hosted, s.nonzero⟩

/-- The slots in order, the claim sites running through the block. -/
def numProg (aBase hBase ioIn ioOut : ℕ) : ℕ → ℕ → List SlotS → List SlotS
  | _, _, [] => []
  | ak, hk, s :: ss =>
    numSlot aBase hBase ioIn ioOut ak hk s
      :: numProg aBase hBase ioIn ioOut (ak + cmCountS .a s.tabs) (hk + cmCountS .h s.tabs) ss

/-- **The W16R2 block's slot program**, with the reserved pair's first row in the incoming and in the outgoing
endpoint commitment (`Layout::io_mask_row`: one pair per endpoint for a single block, the boundary's derived pairs
for a stage of a run). -/
def progW16 (c : W16Cfg) (ioIn ioOut : ℕ) : List SlotS :=
  numProg (aDataRows c) (hDataRows c) ioIn ioOut 0 0 (rawProg c)

/-! ### The numbering changes no count and no shape -/

theorem numTabs_cm (aBase hBase ioIn ioOut : ℕ) (cm : Cm) : ∀ (ts : List TabS) (ak hk pk : ℕ),
    cmCountS cm (numTabs aBase hBase ioIn ioOut ak hk pk ts) = cmCountS cm ts
  | [], _, _, _ => rfl
  | .priv p :: ts, ak, hk, pk => by
    show (if p.cm = cm then 1 else 0) + cmCountS cm (numTabs aBase hBase ioIn ioOut _ _ pk ts) = _
    rw [numTabs_cm aBase hBase ioIn ioOut cm ts]
    rfl
  | .pub _ :: ts, ak, hk, pk => numTabs_cm aBase hBase ioIn ioOut cm ts ak hk (pk + 1)
  | .eq _ _ :: ts, ak, hk, pk => numTabs_cm aBase hBase ioIn ioOut cm ts ak hk pk

theorem numTabs_ok (aBase hBase ioIn ioOut : ℕ) (rl : Cm → ℕ) : ∀ (ts : List TabS) (ak hk pk : ℕ),
    (numTabs aBase hBase ioIn ioOut ak hk pk ts).all (tabOKb rl) = ts.all (tabOKb rl)
  | [], _, _, _ => rfl
  | .priv p :: ts, ak, hk, pk => by
    show (tabOKb rl (TabS.priv (setRow aBase hBase ioIn ioOut ak hk p))
      && (numTabs aBase hBase ioIn ioOut _ _ pk ts).all (tabOKb rl)) = _
    rw [numTabs_ok aBase hBase ioIn ioOut rl ts]
    rfl
  | .pub _ :: ts, ak, hk, pk => by
    show (true && (numTabs aBase hBase ioIn ioOut ak hk (pk + 1) ts).all (tabOKb rl)) = _
    rw [numTabs_ok aBase hBase ioIn ioOut rl ts]
    rfl
  | .eq _ _ :: ts, ak, hk, pk => by
    show (true && (numTabs aBase hBase ioIn ioOut ak hk pk ts).all (tabOKb rl)) = _
    rw [numTabs_ok aBase hBase ioIn ioOut rl ts]
    rfl

/-- **The numbered program passes the check exactly when the raw one does.** -/
theorem numProg_ok (aBase hBase ioIn ioOut : ℕ) (rl : Cm → ℕ) : ∀ (ss : List SlotS) (slots : List (ℕ × ℕ × ℕ))
    (ak hk : ℕ), progOKb rl (numProg aBase hBase ioIn ioOut ak hk ss) slots = progOKb rl ss slots
  | [], [], _, _ => rfl
  | [], _ :: _, _, _ => rfl
  | _ :: _, [], _, _ => rfl
  | s :: ss, d :: ds, ak, hk => by
    show (slotOKb rl d.2.2 (numSlot aBase hBase ioIn ioOut ak hk s)
      && progOKb rl (numProg aBase hBase ioIn ioOut _ _ ss) ds) = (slotOKb rl d.2.2 s && progOKb rl ss ds)
    rw [numProg_ok aBase hBase ioIn ioOut rl ss ds]
    have e : slotOKb rl d.2.2 (numSlot aBase hBase ioIn ioOut ak hk s) = slotOKb rl d.2.2 s := by
      show ((numTabs aBase hBase ioIn ioOut ak hk 0 s.tabs).all (tabOKb rl) && decide (irDeg s.ir ≤ d.2.2))
        = (s.tabs.all (tabOKb rl) && decide (irDeg s.ir ≤ d.2.2))
      rw [numTabs_ok]
    rw [e]

/-- **The numbered program's counts per commitment are the raw one's.** -/
theorem numProg_cm (aBase hBase ioIn ioOut : ℕ) (cm : Cm) : ∀ (ss : List SlotS) (ak hk : ℕ),
    (numProg aBase hBase ioIn ioOut ak hk ss).map (fun s => cmCountS cm s.tabs)
      = ss.map (fun s => cmCountS cm s.tabs)
  | [], _, _ => rfl
  | s :: ss, ak, hk => by
    show cmCountS cm (numTabs aBase hBase ioIn ioOut ak hk 0 s.tabs)
        :: (numProg aBase hBase ioIn ioOut _ _ ss).map (fun s => cmCountS cm s.tabs)
      = cmCountS cm s.tabs :: ss.map (fun s => cmCountS cm s.tabs)
    rw [numTabs_cm, numProg_cm aBase hBase ioIn ioOut cm ss]

/-- **`protocol::logup_sum_claim`**: every `H` plane with its sign (`−1` for a table helper: the `3 + n_range`
`Dom::Tab` helpers before the zero-sum row), real half then imaginary half, as one pairless sum claim of value `0`. -/
def logupSumW16 (c : W16Cfg) : ZClaim :=
  ⟨(List.range (hDoms c).length).flatMap (fun hp =>
      let sign := if decide (fh c 8 ≤ hp) && decide (hp < fh c 8 + 3 + nRange c) then Fp2.one.neg else Fp2.one
      let ls := c.sh.logs ((hDoms c).getD hp .Tab)
      [⟨(hOff c hp).1, ls, sign, []⟩, ⟨(hOff c hp).2, ls, sign.mul fp2U, []⟩]), Fp2.zero⟩

end ZK60.Exec.Block.DefW16
