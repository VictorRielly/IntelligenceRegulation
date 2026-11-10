/-
D63 lane L47 (2026-11-10), fork D: **lane L44's host public tables `pubsW16` against the code, by VALUE** (finding
L44-E2: L44's `BlockHelperExportCheck` compared the public tables' lengths only): the supports, the norms' gains, the
causal mask, the seven folded weights at the receipt's own draws, RoPE's `cos` / `sin`, the activation's group column
and its gate (slots 0, 1, 4, 5, 6, 7, 10–18).

Run (through the zk60 resource guard; `results/zk60_lean_l47_20261110/exp_check_host.sh` does it):
  lake -d formal env lean --run formal/ZK60Formal/BlockHostExportCheck.lean <corpus> [neg]

The corpus is written by the test-only `ops/zkp-mvp/gpu-metal/hashline/src/lean_l47_export_tests.rs`
(`lean_l47_export_the_host_tables`) on a REAL W16R2 rung block receipt (the production `prove_core` with
`w16r2_tests`' seeded recipe, accepted by `verify_core`; the production `define` and `run_slot` on the real
transcript): the shape's numbers and head slots, the public data AS THE CODE STORES IT (`gamma_a`, `gamma_m`,
`rope_cos`, `rope_sin`, the ACT group ids, the seven weight matrices in the FULL corpus, the folding multipliers
`accuracy_fold::coefficients`), every slot's draws and table counts, and every public table of the host slots: length,
two fingerprints `Σ_i v_i·ρ^i`, the first and last 64 entries, and every entry (FULL corpus).

**How a table is built here: with lane L44's own recipe.** `pubsF F rest` is `pubsW16`'s body over a record `F` of the
seventeen fields `pubsW16` reads, and **`pubsW16_pubsF`** proves `pubsW16 Pb Lay B rest = pubsF (ofB B) rest` by `rfl`,
for EVERY `B`; `pubsFast` replaces `foldTab` by `foldTabA` (the same sum with the `eq` table computed once) and
**`pubsFast_eq`** proves it equal to `pubsF`. So each table compared is `pubsW16 Pb Lay B rest s hist dr i` for every
`B : W16Pub` whose fields are the record `natF` built here, at the slot's own draws `dr`: `cubeTab n (g ∘ split)` and
`foldTab m n W (drSeg dr off n)` with the split maps `splitD`, `splitS`, `splitQ`, `splitK`, `splitF`, `splitHQ`,
`splitGD` of `pubsW16`. The record `natF` reads the code's stored arrays at the NATURAL embedding of the logical axes
into the cubes (a token `t`, a width column `i`, a hidden channel `f`, a key-value group `g`, a head dimension `i` at
`msbIndex t`, … ; a head slot `s = 2g + j`; a `Dom::Q` / `Dom::Kv` head-dimension index `i`, its top bit RoPE's flip),
the code's padded positions as the code fills them (zero, or the indicator). A pass shows the recipe, the split maps
and that embedding agree with the code's flat tables; a failure is a finding about one of them.

It also checks, on the stored data, the pad facts `W16Pub` asks of any `B` at that embedding: every weight entry that
reads a padded input (a width column `≥ width`, a hidden channel `≥ hidden`) is zero (`Wq_pad` … `Wd_pad`), and every
slot's count of public tables is the program's (`DefW16.progW16 cfgRungW16`).

With the argument `neg` it then runs the negative controls: one change to one entry of every host table, and one change
to every public array (a weight of each matrix, a gain of each norm, a `cos` and a `sin` entry, a group id, a folding
multiplier, a head slot's truth, a draw of a fold), each of which must be caught. Not imported by the library root (it
defines `main`).
-/
import ZK60Formal.BlockHostFinal

namespace ZK60.Exec.L47H

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.DefW16 ZK60.Exec.Block.Join.W16
open ZK60.Circuit (GF)

/-! ## `pubsW16`'s body over a record of its fields -/

/-- The seventeen fields of `W16Pub` that `pubsW16` reads. -/
structure PubF where
  gD : CtW × CwW → GF
  mask : (CgW × CjW) × CtW × CtW → GF
  Wq : CwW → (CgW × CjW) × CdW → GF
  Wk : CwW → CgW × CdW → GF
  Wv : CwW → CgW × CdW → GF
  Wo : (CgW × CjW) × CdW → CwW → GF
  Wg : CwW → CfW → GF
  Wu : CwW → CfW → GF
  Wd : CfW → CwW → GF
  gamA : CtW × CwW → GF
  gamM : CtW × CwW → GF
  cosT : CtW × ((CgW × CjW) × CdW) → GF
  sinT : CtW × ((CgW × CjW) × CdW) → GF
  cosK : CtW × (CgW × CdW) → GF
  sinK : CtW × (CgW × CdW) → GF
  grpCol : CtW × CfW → GF
  gF : CtW × CfW → GF

/-- A `W16Pub`'s fields. -/
def ofB {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S} {Lay : ZK60.Layout.W16Layout S CtW CwW CgW CjW CdW CfW}
    (B : ZK60.Layout.W16Pub S Pb Lay) : PubF :=
  ⟨B.gD, B.mask, B.Wq, B.Wk, B.Wv, B.Wo, B.Wg, B.Wu, B.Wd, B.gamA, B.gamM, B.cosT, B.sinT, B.cosK, B.sinK, B.grpCol,
    B.gF⟩

/-- **`pubsW16`'s body**, word for word, over the record. -/
def pubsF (F : PubF) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab 14 (fun b => F.gD (splitD b)) else [])
  else if s = 4 then (if i = 0 then cubeTab 14 (fun b => F.mask (splitS b)) else [])
  else if s = 5 then (if i = 0 then foldTab 9 10 (fun c y => F.Wq c (splitHQ y)) (drSeg dr 5 10) else [])
  else if s = 6 then (if i = 0 then foldTab 9 9 (fun c y => F.Wk c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 7 then (if i = 0 then foldTab 9 9 (fun c y => F.Wv c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 10 then (if i = 0 then foldTab 10 9 (fun c y => F.Wo (splitHQ c) y) (drSeg dr 5 9) else [])
  else if s = 11 then (if i = 0 then foldTab 9 10 (fun c y => F.Wg c y) (drSeg dr 5 10) else [])
  else if s = 12 then (if i = 0 then foldTab 9 10 (fun c y => F.Wu c y) (drSeg dr 0 10) else [])
  else if s = 13 then (if i = 0 then foldTab 10 9 (fun c y => F.Wd c y) (drSeg dr 5 9) else [])
  else if s = 14 then
    (if i = 0 then cubeTab 14 (fun b => F.gamA (splitD b))
      else if i = 1 then cubeTab 14 (fun b => F.gamM (splitD b))
      else if i = 2 then cubeTab 14 (fun b => F.gD (splitD b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab 15 (fun b => F.cosT (splitQ b))
      else if i = 1 then cubeTab 15 (fun b => F.sinT (splitQ b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab 14 (fun b => F.cosK (splitK b))
      else if i = 1 then cubeTab 14 (fun b => F.sinK (splitK b)) else [])
  else if s = 17 then (if i = 0 then cubeTab 14 (fun b => F.mask (splitS b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab 15 (fun b => F.grpCol (splitF b))
      else if i = 1 then cubeTab 15 (fun b => F.gF (splitF b)) else [])
  else rest s hist dr i

/-- **The tables compared ARE `pubsW16`'s**, for every `B` (by `rfl`). -/
theorem pubsW16_pubsF {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : ZK60.Layout.W16Layout S CtW CwW CgW CjW CdW CfW) (B : ZK60.Layout.W16Pub S Pb Lay) (rest : PubTabs) :
    pubsW16 Pb Lay B rest = pubsF (ofB B) rest := rfl

/-- `foldTab` with its `eq` table computed once (the same sum). -/
def foldTabA (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) : List Fp2 :=
  let e := (eqTableMsb r).toArray
  (List.range (2 ^ m)).map fun idx =>
    wsumF ((List.range (2 ^ n)).map fun j =>
      (e[j]?.getD Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

theorem foldTabA_eq (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) :
    foldTabA m n W r = foldTab m n W r := by
  unfold foldTabA foldTab
  simp only [List.getElem?_toArray, List.getD_eq_getElem?_getD]

/-- `pubsF` with `foldTabA`. -/
def pubsFast (F : PubF) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab 14 (fun b => F.gD (splitD b)) else [])
  else if s = 4 then (if i = 0 then cubeTab 14 (fun b => F.mask (splitS b)) else [])
  else if s = 5 then (if i = 0 then foldTabA 9 10 (fun c y => F.Wq c (splitHQ y)) (drSeg dr 5 10) else [])
  else if s = 6 then (if i = 0 then foldTabA 9 9 (fun c y => F.Wk c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 7 then (if i = 0 then foldTabA 9 9 (fun c y => F.Wv c (splitGD y)) (drSeg dr 0 9) else [])
  else if s = 10 then (if i = 0 then foldTabA 10 9 (fun c y => F.Wo (splitHQ c) y) (drSeg dr 5 9) else [])
  else if s = 11 then (if i = 0 then foldTabA 9 10 (fun c y => F.Wg c y) (drSeg dr 5 10) else [])
  else if s = 12 then (if i = 0 then foldTabA 9 10 (fun c y => F.Wu c y) (drSeg dr 0 10) else [])
  else if s = 13 then (if i = 0 then foldTabA 10 9 (fun c y => F.Wd c y) (drSeg dr 5 9) else [])
  else if s = 14 then
    (if i = 0 then cubeTab 14 (fun b => F.gamA (splitD b))
      else if i = 1 then cubeTab 14 (fun b => F.gamM (splitD b))
      else if i = 2 then cubeTab 14 (fun b => F.gD (splitD b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab 15 (fun b => F.cosT (splitQ b))
      else if i = 1 then cubeTab 15 (fun b => F.sinT (splitQ b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab 14 (fun b => F.cosK (splitK b))
      else if i = 1 then cubeTab 14 (fun b => F.sinK (splitK b)) else [])
  else if s = 17 then (if i = 0 then cubeTab 14 (fun b => F.mask (splitS b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab 15 (fun b => F.grpCol (splitF b))
      else if i = 1 then cubeTab 15 (fun b => F.gF (splitF b)) else [])
  else rest s hist dr i

theorem pubsFast_eq (F : PubF) (rest : PubTabs) : pubsFast F rest = pubsF F rest := by
  unfold pubsFast pubsF
  simp only [foldTabA_eq]

/-! ## Parsing -/

def parseCsvNat (s : String) : Option (List ℕ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toNat?

def parseCsvInt (s : String) : Option (List ℤ) := if s = "-" then some [] else (s.splitOn ",").mapM String.toInt?

def f2 (a b : ℕ) : Fp2 := ⟨⟨UInt64.ofNat a⟩, ⟨UInt64.ofNat b⟩⟩

def pairUp : List ℕ → Option (List Fp2)
  | [] => some []
  | [_] => none
  | a :: b :: r => (pairUp r).map (f2 a b :: ·)

def pF2s (s : String) : Option (List Fp2) := parseCsvNat s >>= pairUp

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def w2 (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

/-- **The fingerprint `Σ_i v_i·ρ^i`** in the code's word arithmetic (Horner from the last entry, as the export). -/
def fprint (v : List Fp2) (ρ : Fp2) : Fp2 := v.foldr (fun x acc => Fp2.add (Fp2.mul acc ρ) x) Fp2.zero

structure PubRec where
  s : ℕ
  i : ℕ
  n : ℕ
  fp1 : Fp2
  fp2 : Fp2
  head : List Fp2
  tail : List Fp2

structure Corp where
  name : String := ""
  nSlots : ℕ := 0
  logCols : ℕ := 0
  rho1 : Fp2 := Fp2.zero
  rho2 : Fp2 := Fp2.zero
  shape : List ℕ := []
  headSlot : Array ℕ := #[]
  trueSlot : Array ℕ := #[]
  gamA : Array ℤ := #[]
  gamM : Array ℤ := #[]
  ropeCos : Array ℤ := #[]
  ropeSin : Array ℤ := #[]
  groupIds : Array ℤ := #[]
  coef : List (String × Array ℤ) := []
  weight : List (String × Array ℤ) := []
  beta : Fp2 := Fp2.zero
  gamma : Fp2 := Fp2.zero
  alpha : Fp2 := Fp2.zero
  slots : List (ℕ × ℕ × ℕ) := []
  draws : List (ℕ × List Fp2) := []
  pubs : Array PubRec := #[]
  full : Array (ℕ × ℕ × Array Fp2) := #[]
  done : Option (ℕ × ℕ) := none
  bad : List String := []

def Corp.err (c : Corp) (l : String) : Corp := { c with bad := c.bad ++ [s!"{l.take 160}"] }

def between (ws : List String) (a b : String) : List String :=
  ((ws.dropWhile (· != a)).drop 1).takeWhile (· != b)

/-- An array line `NAME n v0,v1,…`. -/
def arr (c : Corp) (l n vs : String) (k : Array ℤ → Corp) : Corp :=
  match n.toNat?, parseCsvInt vs with
  | some m, some v => if v.length = m then k v.toArray else c.err l
  | _, _ => c.err l

def parseLine (c : Corp) (l : String) : Corp :=
  let ws := (l.splitOn " ").filter (· ≠ "")
  match ws with
  | ["L47H", nm, ns, lc] =>
    match ns.toNat?, lc.toNat? with
    | some a, some b => { c with name := nm, nSlots := a, logCols := b }
    | _, _ => c.err l
  | ["RHO", a, b] =>
    match pF2 a, pF2 b with
    | some x, some y => { c with rho1 := x, rho2 := y }
    | _, _ => c.err l
  | "SHAPE" :: rest =>
    match rest.mapM String.toNat? with
    | some v => if v.length = 11 then { c with shape := v } else c.err l
    | none => c.err l
  | ["HEADSLOT", v] =>
    match parseCsvNat v with
    | some x => { c with headSlot := x.toArray }
    | none => c.err l
  | ["TRUESLOT", v] =>
    match parseCsvNat v with
    | some x => { c with trueSlot := x.toArray }
    | none => c.err l
  | ["GAMA", n, vs] => arr c l n vs fun a => { c with gamA := a }
  | ["GAMM", n, vs] => arr c l n vs fun a => { c with gamM := a }
  | ["ROPECOS", n, vs] => arr c l n vs fun a => { c with ropeCos := a }
  | ["ROPESIN", n, vs] => arr c l n vs fun a => { c with ropeSin := a }
  | ["GROUPIDS", n, vs] => arr c l n vs fun a => { c with groupIds := a }
  | ["COEF", nm, n, vs] => arr c l n vs fun a => { c with coef := c.coef ++ [(nm, a)] }
  | ["WEIGHT", nm, n, vs] => arr c l n vs fun a => { c with weight := c.weight ++ [(nm, a)] }
  | ["LOGUP", a, b, g] =>
    match pF2 a, pF2 b, pF2 g with
    | some x, some y, some z => { c with beta := x, gamma := y, alpha := z }
    | _, _, _ => c.err l
  | ["SLOT", s, nt, np] =>
    match s.toNat?, nt.toNat?, np.toNat? with
    | some a, some b, some d => { c with slots := c.slots ++ [(a, b, d)] }
    | _, _, _ => c.err l
  | ["DRAWS", s, v] =>
    match s.toNat?, pF2s v with
    | some a, some d => { c with draws := c.draws ++ [(a, d)] }
    | _, _ => c.err l
  | "PUB" :: s :: i :: n :: "FP" :: a :: b :: _ =>
    match s.toNat?, i.toNat?, n.toNat?, pF2 a, pF2 b, pF2s ((between ws "HEAD" "TAIL").headD ""),
        pF2s ((between ws "TAIL" "").headD "") with
    | some si, some ii, some k, some x, some y, some h, some t =>
      { c with pubs := c.pubs.push ⟨si, ii, k, x, y, h, t⟩ }
    | _, _, _, _, _, _, _ => c.err l
  | ["FULL", s, i, n, vs] =>
    match s.toNat?, i.toNat?, n.toNat?, pF2s vs with
    | some si, some ii, some k, some v =>
      if v.length = k then { c with full := c.full.push (si, ii, v.toArray) } else c.err l
    | _, _, _, _ => c.err l
  | ["DONE", a, b] =>
    match a.toNat?, b.toNat? with
    | some x, some y => { c with done := some (x, y) }
    | _, _ => c.err l
  | [] => c
  | _ => c.err l

/-! ## The record read off the code's stored data at the natural embedding -/

def Corp.sh (c : Corp) (k : ℕ) : ℕ := c.shape.getD k 0
def Corp.tokens (c : Corp) : ℕ := c.sh 0
def Corp.width (c : Corp) : ℕ := c.sh 1
def Corp.hidden (c : Corp) : ℕ := c.sh 2
def Corp.headDim (c : Corp) : ℕ := c.sh 4
def Corp.kvHeads (c : Corp) : ℕ := c.sh 5
def Corp.dPad (c : Corp) : ℕ := c.sh 7
def Corp.fPad (c : Corp) : ℕ := c.sh 8
def Corp.hPad (c : Corp) : ℕ := c.sh 9
def Corp.qPad (c : Corp) : ℕ := c.sh 10

def Corp.coefOf (c : Corp) (nm : String) : Array ℤ := ((c.coef.find? (·.1 == nm)).map (·.2)).getD #[]
def Corp.weightOf (c : Corp) (nm : String) : Array ℤ := ((c.weight.find? (·.1 == nm)).map (·.2)).getD #[]

/-- The index of a cube point (`eq_table_msb`'s order). -/
abbrev ix (n : ℕ) (b : Fin n → Bool) : ℕ := msbIndex n b

/-- A head slot from its group and its index in the group (`(g ++ j)`). -/
def slotOf (g : CgW) (j : CjW) : ℕ := 2 * ix 3 g + ix 1 j

def zint (a : Array ℤ) (k : ℕ) : GF := ((a.getD k 0 : ℤ) : GF)

/-- RoPE at `(t, i)` of a domain whose head index is live: `cos[t·half + i mod half]`, and `∓ sin` by the half. -/
def ropeC (c : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then zint c.ropeCos (t * (c.headDim / 2) + i % (c.headDim / 2)) else 0

def ropeS (c : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then
    (if i < c.headDim / 2 then -zint c.ropeSin (t * (c.headDim / 2) + i % (c.headDim / 2))
      else zint c.ropeSin (t * (c.headDim / 2) + i % (c.headDim / 2)))
  else 0

/-- **The record of the code's stored public data at the natural embedding.** -/
def natF (c : Corp) : PubF where
  gD p := if ix 5 p.1 < c.tokens ∧ ix 9 p.2 < c.width then 1 else 0
  mask p := if ix 5 p.2.2 ≤ ix 5 p.2.1 then 1 else 0
  Wq x y := let row := slotOf y.1.1 y.1.2 * c.headDim + ix 6 y.2
    zint (c.weightOf "Q") (row * c.dPad + ix 9 x) * zint (c.coefOf "Q") row
  Wk x y := let row := ix 3 y.1 * c.headDim + ix 6 y.2
    zint (c.weightOf "K") (row * c.dPad + ix 9 x) * zint (c.coefOf "K") row
  Wv x y := let row := ix 3 y.1 * c.headDim + ix 6 y.2
    zint (c.weightOf "V") (row * c.dPad + ix 9 x) * zint (c.coefOf "V") row
  Wo x y := let col := slotOf x.1.1 x.1.2 * c.headDim + ix 6 x.2
    zint (c.weightOf "O") (ix 9 y * c.qPad + col) * zint (c.coefOf "O") (ix 9 y)
  Wg x f := zint (c.weightOf "G") (ix 9 x * c.fPad + ix 10 f) * zint (c.coefOf "G") (ix 10 f)
  Wu x f := zint (c.weightOf "U") (ix 9 x * c.fPad + ix 10 f) * zint (c.coefOf "U") (ix 10 f)
  Wd f y := zint (c.weightOf "D") (ix 10 f * c.dPad + ix 9 y) * zint (c.coefOf "D") (ix 9 y)
  gamA p := zint c.gamA (ix 9 p.2)
  gamM p := zint c.gamM (ix 9 p.2)
  cosT p := ropeC c (decide (ix 5 p.1 < c.tokens) && c.trueSlot.getD (slotOf p.2.1.1 p.2.1.2) 0 == 1) (ix 5 p.1) (ix 6 p.2.2)
  sinT p := ropeS c (decide (ix 5 p.1 < c.tokens) && c.trueSlot.getD (slotOf p.2.1.1 p.2.1.2) 0 == 1) (ix 5 p.1) (ix 6 p.2.2)
  cosK p := ropeC c (decide (ix 5 p.1 < c.tokens)) (ix 5 p.1) (ix 6 p.2.2)
  sinK p := ropeS c (decide (ix 5 p.1 < c.tokens)) (ix 5 p.1) (ix 6 p.2.2)
  grpCol p := if ix 5 p.1 < c.tokens ∧ ix 10 p.2 < c.hidden then zint c.groupIds (ix 10 p.2) else 0
  gF p := if ix 5 p.1 < c.tokens ∧ ix 10 p.2 < c.hidden then 1 else 0

/-- The host slots' public tables. -/
def hostKeys : List (ℕ × ℕ) :=
  [(0, 0), (1, 0), (4, 0), (5, 0), (6, 0), (7, 0), (10, 0), (11, 0), (12, 0), (13, 0), (14, 0), (14, 1), (14, 2),
    (15, 0), (15, 1), (16, 0), (16, 1), (17, 0), (18, 0), (18, 1)]

def isFold (k : ℕ × ℕ) : Bool := [5, 6, 7, 10, 11, 12, 13].contains k.1

def histC (c : Corp) : Hist := ⟨c.beta, c.gamma, c.alpha, []⟩

def drawsOf (c : Corp) (s : ℕ) : List Fp2 := ((c.draws.find? (·.1 == s)).map (·.2)).getD []

structure LTab where
  key : ℕ × ℕ
  vals : Array Fp2
  fp1 : Fp2
  fp2 : Fp2

/-- One Lean table: `pubsW16`'s (through `pubsFast_eq`, `pubsW16_pubsF`) at `natF` and the slot's draws. -/
def leanTab (c : Corp) (k : ℕ × ℕ) : LTab :=
  let v := pubsFast (natF c) (fun _ _ _ _ => []) k.1 (histC c) (drawsOf c k.1) k.2
  ⟨k, v.toArray, fprint v c.rho1, fprint v c.rho2⟩

/-! ## The checks -/

structure St where
  ok : ℕ := 0
  fail : ℕ := 0
  skipped : ℕ := 0
  msgs : Array String := #[]
  kinds : List (String × ℕ) := []

def bump : List (String × ℕ) → String → List (String × ℕ)
  | [], k => [(k, 1)]
  | (k', n) :: rest, k => if k' = k then (k', n + 1) :: rest else (k', n) :: bump rest k

def St.check (s : St) (kind : String) (b : Bool) (msg : String) : St :=
  let s := { s with kinds := bump s.kinds kind }
  if b then { s with ok := s.ok + 1 }
  else { s with fail := s.fail + 1, msgs := if s.msgs.size < 60 then s.msgs.push s!"[{kind}] {msg.take 400}" else s.msgs }

def firstDiff (a b : Array Fp2) : Option ℕ :=
  if a.size ≠ b.size then some (min a.size b.size)
  else (List.range a.size).find? fun i => a.getD i Fp2.zero != b.getD i Fp2.zero

/-- Every entry of a stored weight matrix that reads a padded input is zero. -/
def padZero (a : Array ℤ) (rows cols : ℕ) (live : ℕ → ℕ → Bool) : Bool :=
  (List.range rows).all fun r => (List.range cols).all fun q => live r q || a.getD (r * cols + q) 0 == 0

def hasWeights (c : Corp) : Bool := c.weight.length == 7

def checkAll (c : Corp) (lt : List LTab) : St := Id.run do
  let mut st : St := {}
  st := st.check "parse" c.bad.isEmpty s!"unparsed lines: {c.bad}"
  st := st.check "header" (c.nSlots == W16R2.rungSlots.length ∧ c.logCols == cfgRungW16.logCols)
    s!"slots {c.nSlots}, log_cols {c.logCols}"
  st := st.check "shape" (c.shape == [32, 384, 768, 16, 64, 8, 32, 512, 1024, 16, 1024]) s!"shape {c.shape}"
  st := st.check "data" (c.gamA.size == c.dPad ∧ c.gamM.size == c.dPad ∧ c.groupIds.size == c.hidden
      ∧ c.ropeCos.size == c.tokens * (c.headDim / 2) ∧ c.ropeSin.size == c.tokens * (c.headDim / 2)
      ∧ c.trueSlot.size == c.hPad ∧ c.coef.length == 7)
    "the public arrays' lengths"
  -- every slot's count of public tables is the program's
  for s in List.range c.nSlots do
    let sl := (progW16 cfgRungW16 0 0).getD s SlotS.empty
    let np := (sl.tabs.filter fun t => match t with | .pub _ => true | _ => false).length
    let code := (c.slots.find? fun q => q.1 == s).getD (0, 0, 0)
    st := st.check "slots" (code.2.1 == sl.tabs.length ∧ code.2.2 == np)
      s!"slot {s}: code {code.2.1} tables / {code.2.2} public, Lean {sl.tabs.length} / {np}"
  -- the pad facts `W16Pub` asks of the weights at the natural embedding
  if hasWeights c then
    let (w, d, f, q) := (c.width, c.dPad, c.fPad, c.qPad)
    st := st.check "pad" (padZero (c.weightOf "Q") q d fun _ col => decide (col < w)) "Wq_pad"
    st := st.check "pad" (padZero (c.weightOf "K") (c.kvHeads * c.headDim) d fun _ col => decide (col < w)) "Wk_pad"
    st := st.check "pad" (padZero (c.weightOf "V") (c.kvHeads * c.headDim) d fun _ col => decide (col < w)) "Wv_pad"
    st := st.check "pad" (padZero (c.weightOf "G") d f fun row _ => decide (row < w)) "Wg_pad"
    st := st.check "pad" (padZero (c.weightOf "U") d f fun row _ => decide (row < w)) "Wu_pad"
    st := st.check "pad" (padZero (c.weightOf "D") f d fun row _ => decide (row < c.hidden)) "Wd_pad"
    st := st.check "pad" (padZero (c.weightOf "O") d q fun _ col => c.trueSlot.getD (col / c.headDim) 0 == 1) "Wo_pad"
  -- the public tables
  st := st.check "tables" (c.pubs.size == hostKeys.length) s!"public tables {c.pubs.size} vs {hostKeys.length}"
  for t in lt do
    if isFold t.key && !hasWeights c then
      st := { st with skipped := st.skipped + 1 }
    else
      match c.pubs.find? (fun r => r.s == t.key.1 ∧ r.i == t.key.2) with
      | none => st := st.check "tables" false s!"slot {t.key.1} table {t.key.2}: not in the corpus"
      | some r =>
        let tag := s!"slot {t.key.1} table {t.key.2}"
        st := st.check "length" (r.n == t.vals.size) s!"{tag}: code {r.n}, Lean {t.vals.size}"
        st := st.check "fingerprint" (r.fp1 == t.fp1) s!"{tag}: rho1 code {w2 r.fp1}, Lean {w2 t.fp1}"
        st := st.check "fingerprint" (r.fp2 == t.fp2) s!"{tag}: rho2 code {w2 r.fp2}, Lean {w2 t.fp2}"
        let e := min 64 t.vals.size
        st := st.check "ends" (r.head == (t.vals.toList.take e)) s!"{tag}: head"
        st := st.check "ends" (r.tail == (t.vals.toList.drop (t.vals.size - e))) s!"{tag}: tail"
      match c.full.find? (fun r => r.1 == t.key.1 ∧ r.2.1 == t.key.2) with
      | none => pure ()
      | some r =>
        match firstDiff r.2.2 t.vals with
        | none => st := st.check "entries" true ""
        | some i =>
          st := st.check "entries" false
            s!"slot {t.key.1} table {t.key.2}: first difference at {i}: code {w2 (r.2.2.getD i Fp2.zero)}, Lean {w2 (t.vals.getD i Fp2.zero)}"
  st := st.check "done" (c.done.map (·.1) == some hostKeys.length) s!"done {c.done}"
  return st

/-! ## The negative controls -/

def setFull (c : Corp) (s i idx : ℕ) : Corp :=
  { c with full := c.full.map fun r =>
      if r.1 == s ∧ r.2.1 == i then (r.1, r.2.1, r.2.2.modify idx (fun x => Fp2.add x Fp2.one)) else r }

def setPubFp (c : Corp) (s i : ℕ) : Corp :=
  { c with pubs := c.pubs.map fun r => if r.s == s ∧ r.i == i then { r with fp1 := Fp2.add r.fp1 Fp2.one } else r }

def modW (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with weight := c.weight.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

def modC (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with coef := c.coef.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

/-- One change: its name, the tables it concerns, whether the Lean side's inputs change (those tables recomputed),
the changed corpus. -/
def muts (c : Corp) : List (String × List (ℕ × ℕ) × Bool × Corp) :=
  let full := !c.full.isEmpty
  let tabMut (k : ℕ × ℕ) : Corp :=
    if full then setFull c k.1 k.2 (if isFold k then 7 else 1000) else setPubFp c k.1 k.2
  (hostKeys.map fun k => (s!"the code's table {k}, one entry", [k], false, tabMut k))
  ++ [("a weight of Wq (row 3, column 5)", [(5, 0)], true, modW c "Q" (3 * c.dPad + 5)),
      ("a weight of Wk (row 3, column 5)", [(6, 0)], true, modW c "K" (3 * c.dPad + 5)),
      ("a weight of Wv (row 3, column 5)", [(7, 0)], true, modW c "V" (3 * c.dPad + 5)),
      ("a weight of Wo (row 3, column 5)", [(10, 0)], true, modW c "O" (3 * c.qPad + 5)),
      ("a weight of Wg (input 5, output 3)", [(11, 0)], true, modW c "G" (5 * c.fPad + 3)),
      ("a weight of Wu (input 5, output 3)", [(12, 0)], true, modW c "U" (5 * c.fPad + 3)),
      ("a weight of Wd (input 5, output 3)", [(13, 0)], true, modW c "D" (5 * c.dPad + 3)),
      ("a folding multiplier of Q (row 10)", [(5, 0)], true, modC c "Q" 10),
      ("a folding multiplier of the gate (channel 10)", [(11, 0)], true, modC c "G" 10),
      ("gamma_a[5]", [(14, 0)], true, { c with gamA := c.gamA.modify 5 (· + 1) }),
      ("gamma_m[7]", [(14, 1)], true, { c with gamM := c.gamM.modify 7 (· + 1) }),
      ("rope_cos[3]", [(15, 0), (16, 0)], true, { c with ropeCos := c.ropeCos.modify 3 (· + 1) }),
      ("rope_sin[9]", [(15, 1), (16, 1)], true, { c with ropeSin := c.ropeSin.modify 9 (· + 1) }),
      ("a group id (channel 4)", [(18, 0)], true, { c with groupIds := c.groupIds.modify 4 (· + 1) }),
      ("head slot 1 not a true head", [(15, 0), (15, 1)], true, { c with trueSlot := c.trueSlot.set! 1 0 }),
      ("a draw of SC_QMM's fold (draw 7)", [(5, 0)], true,
        { c with draws := c.draws.map fun q => if q.1 == 5 then (q.1, q.2.modify 7 (fun x => Fp2.add x Fp2.one)) else q }),
      ("slot 14's count of public tables", [], false,
        { c with slots := c.slots.map fun q => if q.1 == 14 then (q.1, q.2.1, q.2.2 + 1) else q })]

def report (st : St) : IO Unit := do
  for (k, n) in st.kinds do
    IO.println s!"  {k}: {n}"
  for m in st.msgs do
    IO.println s!"  FAIL {m}"

end ZK60.Exec.L47H

open ZK60.Exec.L47H in
def main (args : List String) : IO UInt32 := do
  let path := args.headD ""
  let txt ← IO.FS.readFile path
  let c := (txt.splitOn "\n").foldl parseLine {}
  IO.println s!"corpus {path}: {c.name}, {c.pubs.size} host tables, {c.full.size} in full, weights {hasWeights c}"
  let lt := hostKeys.map fun k => if isFold k && !hasWeights c then (⟨k, #[], ZK60.Exec.Fp2.zero, ZK60.Exec.Fp2.zero⟩ : LTab) else leanTab c k
  let st := checkAll c lt
  IO.println s!"checks: {st.ok} passed, {st.fail} failed, {st.skipped} fold tables skipped (no weights in this corpus)"
  report st
  let mut rc : UInt32 := if st.fail = 0 then 0 else 1
  if args.contains "neg" then
    let ms := (muts c).filter fun m => hasWeights c || !(m.2.1.any isFold)
    let mut caught := 0
    for (nm, keys, recompute, c') in ms do
      let lt' := lt.map fun t => if recompute && keys.contains t.key then leanTab c' t.key else t
      let st' := checkAll c' lt'
      if st'.fail > 0 then
        caught := caught + 1
        IO.println s!"negative control CAUGHT ({st'.fail} failed): {nm}"
      else
        IO.println s!"negative control MISSED: {nm}"
    IO.println s!"negative controls: {caught} of {ms.length} caught"
    if caught ≠ ms.length then rc := 1
  return rc
