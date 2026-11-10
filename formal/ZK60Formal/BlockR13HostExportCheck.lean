/-
D63 lane L49 (2026-11-10), sub-agent `pub`: **the R13 host public tables `pubsR13` and `SC_LZC`'s `restR13L` against
the code, by VALUE** (the R13 counterpart of lane L47's `BlockHostExportCheck.lean`, which closed finding L44-E2 at the
W16R2 rung): the supports, the norms' gains, the causal mask, the seven folded weights at the receipt's own draws,
RoPE's `cos` / `sin`, the activation's group column and its gate (slots 0, 1, 4, 5, 6, 7, 10–18), and `SC_LZC`'s
`supp(Dom::L)` (slot 3), on two kinds of corpus:
* the R13 RUNG receipt (header `L49H`; `cfgRungR13`), with the Shieldstral T128 R13 shape's `supp(Dom::L)`;
* ONE BLOCK OF THE APP'S SHIELDSTRAL-1.0-3B T128 R13 EXPORT (header `L49S`, deliverable 4, gap GB-6;
  `cfgShieldR13 L` at the layer's entry `L` of `shieldExport`), with its LogUp sum claim against
  `R13H.Look.logupSumR13 (cfgShieldR13 L)`.

Run (through the zk60 resource guard; a `run` line of `results/zk60_lean_l49_20261110/iter.sh`):
  lake -d formal env lean --run formal/ZK60Formal/BlockR13HostExportCheck.lean <corpus> [neg]

The corpora are written by the test-only `ops/zkp-mvp/gpu-metal/hashline/src/lean_l49_export_tests.rs`: the rung
(`lean_l49_export_the_r13_host_tables`: `rung_case`, the production `prove_core` with `w16r2_tests`' seeded recipe,
accepted by `verify_core`) and the Shieldstral block (`lean_l49_export_a_shieldstral_block`: the production loader on the
app's export, one layer proved by the production `prove_core` at `R13_SHIELD_T128_H24`, accepted by `verify_core`); in
both the production `define` and `run_slot` on the real transcript. Each carries the shape's numbers and head slots, the
public data AS THE CODE STORES IT (`gamma_a`, `gamma_m`, `rope_cos`, `rope_sin`, the ACT group ids, the folding
multipliers; the rung's seven weight matrices whole in the FULL corpus, the Shieldstral block's weight columns that its
sampled fold entries read), every slot's draws and table counts, and every public table of every slot but 19 and 20
(length, two fingerprints `Σ_i v_i·ρ^i`, the first and last 64 entries, every entry in the FULL corpus).

**How a table is built here: with this lane's own recipe, generic in the configuration.** `pubsRF c F rest` is
`pubsR13`'s body over a record `F` of the seventeen fields it reads, and **`pubsR13_pubsRF`** proves
`pubsR13 c Pb Lay B rest = pubsRF c (ofBR B) rest` by `rfl`, for EVERY `c` and `B`; `pubsRFast` replaces `foldTab` by
`foldTabR` (the same sum with the `eq` table computed once) and **`pubsRFast_eq`** proves it equal to `pubsRF`. Each
table compared is `pubsR13 c Pb Lay B (restR13L c exp act nG) s hist dr i` at the corpus's configuration `c`, for every
`B` whose fields are the record `natF` built here, at the slot's own draws `dr` (slot 3's table does not read `exp`,
`act`, `nG`: `restR13L_three`). At the Shieldstral block the seven folded weights are compared at sampled indices (the
first 64, the last 64 before the padding, the last 64): **`foldSampleR_eq`** proves that `foldSampleR c F s e idx`, with
`e` the `eq` table of the slot's fold draws, IS entry `idx` of `pubsRF c F rest s hist dr 0`. The record `natF c` reads
the code's stored arrays at the NATURAL embedding of the logical axes into the cubes of `c` (a token `t`, a width column
`i`, a hidden channel `f`, a key-value group `g`, a head dimension `i` at `msbIndex`; a head slot `s = 2^(lh − lkv)·g +
j`), the code's padded positions as the code fills them. A pass shows the recipe, the split maps, the configuration's
widths and draw offsets and that embedding agree with the code's flat tables; a failure is a finding about one of them.
The rung corpus's Shieldstral `supp(Dom::L)` is compared with `cubeTab (shShieldR13.logs .L) (gateLS shShieldR13)`,
which IS `restR13L (cfgShieldR13 L)`'s slot-3 table at every layer `L` (`shieldTab_eq`, `rfl`).

It also checks, on the stored data, the pad facts `W16Pub` asks of any `B` at that embedding (`Wq_pad` … `Wd_pad`; at
the Shieldstral block on the sampled columns), that the corpus's paddings are the configuration's (`t_pad = 2^lt`, …;
`tokens = t_pad`, which `gateLS` reads), that every slot's count of tables and of public tables is the program's
(`DefR13.progR13 c`), and at the Shieldstral block that the header's gate shift is the layer's (`shieldExport`).

With the argument `neg` it then runs the negative controls: one change to one entry of every table compared, and one
change to every public array (a weight of each matrix, a gain of each norm, a `cos` and a `sin` entry, a group id, a
folding multiplier, a head slot's truth, a draw of a fold, the token count; at the Shieldstral block also a sampled fold
entry, a sampled weight, the sum claim's value and a part), each of which must be caught. Not imported by the library
root (it defines `main`).
-/
import Std.Data.HashMap
import ZK60Formal.BlockR13HostPub
import ZK60Formal.BlockR13LookLk

namespace ZK60.Exec.Block.Join.R13H.Pub.Chk

open ZK60.Exec ZK60.Exec.Block ZK60.Exec.Block.Join.R13H ZK60.Exec.Block.Join.R13H.Pub
open ZK60.Exec.Block.Join.W16 (wordGF cubeTab drSeg foldTab wsumF)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (GF)

/-! ## `pubsR13`'s body over a record of its fields -/

/-- The seventeen fields of `W16Pub` that `pubsR13` reads, at the configuration `c`. -/
structure PubFR (c : W16Cfg) where
  gD : CtR c × CwR c → GF
  mask : (CgR c × CjR c) × CtR c × CtR c → GF
  Wq : CwR c → (CgR c × CjR c) × CdR c → GF
  Wk : CwR c → CgR c × CdR c → GF
  Wv : CwR c → CgR c × CdR c → GF
  Wo : (CgR c × CjR c) × CdR c → CwR c → GF
  Wg : CwR c → CfR c → GF
  Wu : CwR c → CfR c → GF
  Wd : CfR c → CwR c → GF
  gamA : CtR c × CwR c → GF
  gamM : CtR c × CwR c → GF
  cosT : CtR c × ((CgR c × CjR c) × CdR c) → GF
  sinT : CtR c × ((CgR c × CjR c) × CdR c) → GF
  cosK : CtR c × (CgR c × CdR c) → GF
  sinK : CtR c × (CgR c × CdR c) → GF
  grpCol : CtR c × CfR c → GF
  gF : CtR c × CfR c → GF

/-- A `W16Pub`'s fields. -/
def ofBR {c : W16Cfg} {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : ZK60.Layout.W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : ZK60.Layout.W16Pub S Pb Lay) :
    PubFR c :=
  ⟨B.gD, B.mask, B.Wq, B.Wk, B.Wv, B.Wo, B.Wg, B.Wu, B.Wd, B.gamA, B.gamM, B.cosT, B.sinT, B.cosK, B.sinK, B.grpCol,
    B.gF⟩

/-- **`pubsR13`'s body**, word for word, over the record. -/
def pubsRF (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTab c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTab (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => F.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => F.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTab c.sh.lf c.sh.ld (fun f y => F.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => F.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => F.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => F.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => F.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => F.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => F.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => F.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => F.gF (splitF c b)) else [])
  else rest s hist dr i

/-- **The tables compared ARE `pubsR13`'s**, for every configuration and every `B` (by `rfl`). -/
theorem pubsR13_pubsRF (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : ZK60.Layout.W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : ZK60.Layout.W16Pub S Pb Lay)
    (rest : PubTabs) : pubsR13 c Pb Lay B rest = pubsRF c (ofBR B) rest := rfl

/-- `foldTab` with its `eq` table computed once (the same sum). -/
def foldTabR (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) : List Fp2 :=
  let e := (eqTableMsb r).toArray
  (List.range (2 ^ m)).map fun idx =>
    wsumF ((List.range (2 ^ n)).map fun j =>
      (e[j]?.getD Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

theorem foldTabR_eq (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) :
    foldTabR m n W r = foldTab m n W r := by
  unfold foldTabR foldTab
  simp only [List.getElem?_toArray, List.getD_eq_getElem?_getD]

/-- `pubsRF` with `foldTabR`. -/
def pubsRFast (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTabR c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTabR c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTabR c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTabR (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTabR c.sh.ld c.sh.lf (fun w y => F.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTabR c.sh.ld c.sh.lf (fun w y => F.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTabR c.sh.lf c.sh.ld (fun f y => F.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => F.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => F.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => F.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => F.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => F.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => F.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => F.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => F.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => F.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => F.gF (splitF c b)) else [])
  else rest s hist dr i

theorem pubsRFast_eq (c : W16Cfg) (F : PubFR c) (rest : PubTabs) : pubsRFast c F rest = pubsRF c F rest := by
  unfold pubsRFast pubsRF
  simp only [foldTabR_eq]

/-! ## One entry of a folded table -/

/-- **Entry `idx` of `foldTab m n W r`**: `Σ_j eq_table_msb(r)[j]·W(idx, j)` in the code's arithmetic. -/
def foldEntry (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) (idx : ℕ) : Fp2 :=
  wsumF ((List.range (2 ^ n)).map fun j => ((eqTableMsb r).getD j Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

theorem foldTab_getD_entry (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) (idx : ℕ)
    (h : idx < 2 ^ m) : (foldTab m n W r).getD idx Fp2.zero = foldEntry m n W r idx := by
  unfold foldTab foldEntry
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  simp only [Option.map_some, Option.getD_some]

/-- `foldEntry` with the `eq` table given (computed once per table). -/
def foldEntryA (e : Array Fp2) (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (idx : ℕ) : Fp2 :=
  wsumF ((List.range (2 ^ n)).map fun j => (e[j]?.getD Fp2.zero).mul (wordGF (W (msbBits m idx) (msbBits n j))))

theorem foldEntryA_eq (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) (idx : ℕ) :
    foldEntryA (eqTableMsb r).toArray m n W idx = foldEntry m n W r idx := by
  unfold foldEntryA foldEntry
  simp only [List.getElem?_toArray, List.getD_eq_getElem?_getD]

theorem fold_entry_of (m n : ℕ) (W : (Fin m → Bool) → (Fin n → Bool) → GF) (r : List Fp2) (idx : ℕ)
    (h : idx < 2 ^ m) : (foldTab m n W r).getD idx Fp2.zero = foldEntryA (eqTableMsb r).toArray m n W idx := by
  rw [foldEntryA_eq]
  exact foldTab_getD_entry m n W r idx h

/-- A folded table's log length at slot `s`. -/
def foldM (c : W16Cfg) (s : ℕ) : ℕ := if s = 10 then nH c + c.sh.ldh else if s = 13 then c.sh.lf else c.sh.ld

/-- A fold's draws at slot `s` (`pubsR13`'s `drSeg`). -/
def foldDrawsR (c : W16Cfg) (s : ℕ) (dr : List Fp2) : List Fp2 :=
  if s = 5 then drSeg dr c.sh.lt (nH c + c.sh.ldh)
  else if s = 6 ∨ s = 7 then drSeg dr 0 (c.sh.lkv + c.sh.ldh)
  else if s = 10 ∨ s = 13 then drSeg dr c.sh.lt c.sh.ld
  else if s = 11 then drSeg dr c.sh.lt c.sh.lf
  else drSeg dr 0 c.sh.lf

/-- **Entry `idx` of slot `s`'s folded table**, `pubsRF`'s fold at the `eq` table `e`. -/
def foldSampleR (c : W16Cfg) (F : PubFR c) (s : ℕ) (e : Array Fp2) (idx : ℕ) : Fp2 :=
  if s = 5 then foldEntryA e c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y)) idx
  else if s = 6 then foldEntryA e c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y)) idx
  else if s = 7 then foldEntryA e c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y)) idx
  else if s = 10 then foldEntryA e (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) idx
  else if s = 11 then foldEntryA e c.sh.ld c.sh.lf (fun w y => F.Wg w y) idx
  else if s = 12 then foldEntryA e c.sh.ld c.sh.lf (fun w y => F.Wu w y) idx
  else foldEntryA e c.sh.lf c.sh.ld (fun f y => F.Wd f y) idx

/-- **A sampled fold entry IS `pubsRF`'s (so `pubsR13`'s) table entry**, at every configuration. -/
theorem foldSampleR_eq (c : W16Cfg) (F : PubFR c) (rest : PubTabs) (hist : Hist) (dr : List Fp2) (s : ℕ)
    (hs : s = 5 ∨ s = 6 ∨ s = 7 ∨ s = 10 ∨ s = 11 ∨ s = 12 ∨ s = 13) (idx : ℕ) (h : idx < 2 ^ foldM c s) :
    (pubsRF c F rest s hist dr 0).getD idx Fp2.zero = foldSampleR c F s (eqTableMsb (foldDrawsR c s dr)).toArray idx := by
  rcases hs with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact fold_entry_of c.sh.ld (nH c + c.sh.ldh) (fun w y => F.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) idx h
  · exact fold_entry_of c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) idx h
  · exact fold_entry_of c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => F.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) idx h
  · exact fold_entry_of (nH c + c.sh.ldh) c.sh.ld (fun q y => F.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld) idx h
  · exact fold_entry_of c.sh.ld c.sh.lf (fun w y => F.Wg w y) (drSeg dr c.sh.lt c.sh.lf) idx h
  · exact fold_entry_of c.sh.ld c.sh.lf (fun w y => F.Wu w y) (drSeg dr 0 c.sh.lf) idx h
  · exact fold_entry_of c.sh.lf c.sh.ld (fun f y => F.Wd f y) (drSeg dr c.sh.lt c.sh.ld) idx h

/-! ## Parsing (tail-recursive: a Shieldstral table has `2^21` entries) -/

def parseNats (s : String) : Option (Array ℕ) := Id.run do
  if s = "-" then return some #[]
  let mut out : Array ℕ := #[]
  for w in s.splitOn "," do
    match w.toNat? with
    | some v => out := out.push v
    | none => return none
  return some out

def parseInts (s : String) : Option (Array ℤ) := Id.run do
  if s = "-" then return some #[]
  let mut out : Array ℤ := #[]
  for w in s.splitOn "," do
    match w.toInt? with
    | some v => out := out.push v
    | none => return none
  return some out

def f2 (a b : ℕ) : Fp2 := ⟨⟨UInt64.ofNat a⟩, ⟨UInt64.ofNat b⟩⟩

def pairUp (a : Array ℕ) : Option (Array Fp2) :=
  if a.size % 2 = 1 then none
  else some ((Array.range (a.size / 2)).map fun i => f2 (a.getD (2 * i) 0) (a.getD (2 * i + 1) 0))

def pF2a (s : String) : Option (Array Fp2) := parseNats s >>= pairUp

def pF2s (s : String) : Option (List Fp2) := (pF2a s).map Array.toList

def pF2 (s : String) : Option Fp2 :=
  match pF2s s with
  | some [x] => some x
  | _ => none

def w2 (x : Fp2) : String := s!"{x.c0.v.toNat},{x.c1.v.toNat}"

def w2s (l : List Fp2) : String := if l.isEmpty then "-" else ",".intercalate (l.map w2)

/-- **The fingerprint `Σ_i v_i·ρ^i`** in the code's word arithmetic (Horner from the last entry, as the export). -/
def fprint (v : List Fp2) (ρ : Fp2) : Fp2 := v.foldr (fun x acc => Fp2.add (Fp2.mul acc ρ) x) Fp2.zero

/-- One table's summary line (`PUB s i n FP … HEAD … TAIL …`, or `SHIELDL n FP …`). -/
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
  shield : Bool := false
  layer : ℕ := 0
  gate : ℕ := 0
  nSlots : ℕ := 0
  logCols : ℕ := 0
  rho1 : Fp2 := Fp2.zero
  rho2 : Fp2 := Fp2.zero
  shape : List ℕ := []
  lSize : ℕ := 0
  headSlot : Array ℕ := #[]
  trueSlot : Array ℕ := #[]
  gamA : Array ℤ := #[]
  gamM : Array ℤ := #[]
  ropeCos : Array ℤ := #[]
  ropeSin : Array ℤ := #[]
  groupIds : Array ℤ := #[]
  coef : List (String × Array ℤ) := []
  weight : List (String × Array ℤ) := []
  /-- the Shieldstral block's sampled weight columns: name, first flat index, stride, values -/
  wcols : Array (String × ℕ × ℕ × Array ℤ) := #[]
  /-- the same, as one map per matrix (`Corp.finish`) -/
  wmap : List (String × Std.HashMap ℕ ℤ) := []
  fsamples : Array (ℕ × List ℕ × List Fp2) := #[]
  beta : Fp2 := Fp2.zero
  gamma : Fp2 := Fp2.zero
  alpha : Fp2 := Fp2.zero
  sumN : ℕ := 0
  sumVal : Fp2 := Fp2.zero
  parts : Array (ℕ × ℕ × Fp2 × List Fp2) := #[]
  slots : List (ℕ × ℕ × ℕ) := []
  draws : List (ℕ × List Fp2) := []
  pubs : Array PubRec := #[]
  full : Array (ℕ × ℕ × Array Fp2) := #[]
  shieldShape : List String := []
  shieldL : Option PubRec := none
  shieldFull : Option (Array Fp2) := none
  done : Option (ℕ × ℕ) := none
  bad : List String := []

def Corp.err (c : Corp) (l : String) : Corp := { c with bad := c.bad ++ [s!"{l.take 160}"] }

def between (ws : List String) (a b : String) : List String :=
  ((ws.dropWhile (· != a)).drop 1).takeWhile (· != b)

/-- An array line `NAME n v0,v1,…`. -/
def arr (c : Corp) (l n vs : String) (k : Array ℤ → Corp) : Corp :=
  match n.toNat?, parseInts vs with
  | some m, some v => if v.size = m then k v else c.err l
  | _, _ => c.err l

/-- A table's summary from its words after the key (`n FP a b HEAD … TAIL …`). -/
def sumRec (si ii : ℕ) (ws : List String) (n a b : String) : Option PubRec :=
  match n.toNat?, pF2 a, pF2 b, pF2s ((between ws "HEAD" "TAIL").headD ""), pF2s ((between ws "TAIL" "").headD "") with
  | some k, some x, some y, some h, some t => some ⟨si, ii, k, x, y, h, t⟩
  | _, _, _, _, _ => none

def parseLine (c : Corp) (l : String) : Corp :=
  let ws := (l.splitOn " ").filter (· ≠ "")
  match ws with
  | ["L49H", nm, ns, lc] =>
    match ns.toNat?, lc.toNat? with
    | some a, some b => { c with name := nm, nSlots := a, logCols := b }
    | _, _ => c.err l
  | ["L49S", nm, ns, lc, ly, g] =>
    match ns.toNat?, lc.toNat?, ly.toNat?, g.toNat? with
    | some a, some b, some y, some h => { c with name := nm, shield := true, nSlots := a, logCols := b, layer := y, gate := h }
    | _, _, _, _ => c.err l
  | ["RHO", a, b] =>
    match pF2 a, pF2 b with
    | some x, some y => { c with rho1 := x, rho2 := y }
    | _, _ => c.err l
  | "SHAPE" :: rest =>
    match rest.mapM String.toNat? with
    | some v => if v.length = 11 then { c with shape := v } else c.err l
    | none => c.err l
  | ["LSIZE", n] =>
    match n.toNat? with
    | some v => { c with lSize := v }
    | none => c.err l
  | ["HEADSLOT", v] =>
    match parseNats v with
    | some x => { c with headSlot := x }
    | none => c.err l
  | ["TRUESLOT", v] =>
    match parseNats v with
    | some x => { c with trueSlot := x }
    | none => c.err l
  | ["GAMA", n, vs] => arr c l n vs fun a => { c with gamA := a }
  | ["GAMM", n, vs] => arr c l n vs fun a => { c with gamM := a }
  | ["ROPECOS", n, vs] => arr c l n vs fun a => { c with ropeCos := a }
  | ["ROPESIN", n, vs] => arr c l n vs fun a => { c with ropeSin := a }
  | ["GROUPIDS", n, vs] => arr c l n vs fun a => { c with groupIds := a }
  | ["COEF", nm, n, vs] => arr c l n vs fun a => { c with coef := c.coef ++ [(nm, a)] }
  | ["WEIGHT", nm, n, vs] => arr c l n vs fun a => { c with weight := c.weight ++ [(nm, a)] }
  | ["WCOL", nm, k, st, n, vs] =>
    match k.toNat?, st.toNat? with
    | some a, some b => arr c l n vs fun v => { c with wcols := c.wcols.push (nm, a, b, v) }
    | _, _ => c.err l
  | ["FSAMPLE", s, _, ix, vs] =>
    match s.toNat?, parseNats ix, pF2s vs with
    | some a, some i, some v => if i.size = v.length then { c with fsamples := c.fsamples.push (a, i.toList, v) } else c.err l
    | _, _, _ => c.err l
  | ["LOGUP", a, b, g] =>
    match pF2 a, pF2 b, pF2 g with
    | some x, some y, some z => { c with beta := x, gamma := y, alpha := z }
    | _, _, _ => c.err l
  | ["SUMCLAIM", n, v] =>
    match n.toNat?, pF2 v with
    | some k, some x => { c with sumN := k, sumVal := x }
    | _, _ => c.err l
  | ["PART", j, off, lg, cf, pt] =>
    match j.toNat?, off.toNat?, lg.toNat?, pF2 cf, pF2s pt with
    | some ji, some o, some g, some x, some p =>
      if ji = c.parts.size then { c with parts := c.parts.push (o, g, x, p) } else c.err l
    | _, _, _, _, _ => c.err l
  | ["SLOT", s, nt, np] =>
    match s.toNat?, nt.toNat?, np.toNat? with
    | some a, some b, some d => { c with slots := c.slots ++ [(a, b, d)] }
    | _, _, _ => c.err l
  | ["DRAWS", s, v] =>
    match s.toNat?, pF2s v with
    | some a, some d => { c with draws := c.draws ++ [(a, d)] }
    | _, _ => c.err l
  | "PUB" :: s :: i :: n :: "FP" :: a :: b :: _ =>
    match s.toNat?, i.toNat?, sumRec 0 0 ws n a b with
    | some si, some ii, some r => { c with pubs := c.pubs.push { r with s := si, i := ii } }
    | _, _, _ => c.err l
  | ["FULL", s, i, n, vs] =>
    match s.toNat?, i.toNat?, n.toNat?, pF2a vs with
    | some si, some ii, some k, some v =>
      if v.size = k then { c with full := c.full.push (si, ii, v) } else c.err l
    | _, _, _, _ => c.err l
  | "SHIELDSHAPE" :: rest => { c with shieldShape := rest }
  | "SHIELDL" :: n :: "FP" :: a :: b :: _ =>
    match sumRec 0 0 ws n a b with
    | some r => { c with shieldL := some r }
    | none => c.err l
  | ["FULLSHIELDL", n, vs] =>
    match n.toNat?, pF2a vs with
    | some k, some v => if v.size = k then { c with shieldFull := some v } else c.err l
    | _, _ => c.err l
  | "INPUT" :: _ => c
  | ["DONE", a, b] =>
    match a.toNat?, b.toNat? with
    | some x, some y => { c with done := some (x, y) }
    | _, _ => c.err l
  | [] => c
  | _ => c.err l

/-- The sampled weight columns as one map per matrix (flat index to stored value). -/
def Corp.finish (c : Corp) : Corp := Id.run do
  let mut maps : List (String × Std.HashMap ℕ ℤ) := []
  for nm in ["Q", "K", "V", "O", "G", "U", "D"] do
    let mut m : Std.HashMap ℕ ℤ := {}
    for (n', k, st, v) in c.wcols do
      if n' == nm then
        for j in List.range v.size do
          m := m.insert (k + j * st) (v.getD j 0)
    maps := maps ++ [(nm, m)]
  return { c with wmap := maps }

/-! ## The record read off the code's stored data at the natural embedding of a configuration's cubes -/

def Corp.sh (c : Corp) (k : ℕ) : ℕ := c.shape.getD k 0
def Corp.tokens (c : Corp) : ℕ := c.sh 0
def Corp.width (c : Corp) : ℕ := c.sh 1
def Corp.hidden (c : Corp) : ℕ := c.sh 2
def Corp.qHeads (c : Corp) : ℕ := c.sh 3
def Corp.headDim (c : Corp) : ℕ := c.sh 4
def Corp.kvHeads (c : Corp) : ℕ := c.sh 5
def Corp.tPad (c : Corp) : ℕ := c.sh 6
def Corp.dPad (c : Corp) : ℕ := c.sh 7
def Corp.fPad (c : Corp) : ℕ := c.sh 8
def Corp.hPad (c : Corp) : ℕ := c.sh 9
def Corp.qPad (c : Corp) : ℕ := c.sh 10

def Corp.coefOf (c : Corp) (nm : String) : Array ℤ := ((c.coef.find? (·.1 == nm)).map (·.2)).getD #[]
def Corp.weightOf (c : Corp) (nm : String) : Array ℤ := ((c.weight.find? (·.1 == nm)).map (·.2)).getD #[]

def hasWeights (c : Corp) : Bool := c.weight.length == 7

def hasCols (c : Corp) : Bool := !c.wcols.isEmpty

/-- A stored weight at a flat index: the whole matrix (the rung) or the sampled columns (the Shieldstral block). -/
def Corp.wval (c : Corp) (nm : String) (idx : ℕ) : ℤ :=
  if hasWeights c then (c.weightOf nm).getD idx 0
  else
    match c.wmap.find? (fun (q : String × Std.HashMap ℕ ℤ) => q.1 == nm) with
    | some q => q.2.getD idx 0
    | none => 0

/-- The index of a cube point (`eq_table_msb`'s order). -/
abbrev ix (n : ℕ) (b : Fin n → Bool) : ℕ := msbIndex n b

/-- A head slot from its group and its index in the group (`(g ++ j)`: the padded slots are the last of each group). -/
def slotOf (c : W16Cfg) (g : CgR c) (j : CjR c) : ℕ :=
  ix c.sh.lkv g * 2 ^ (c.sh.lh - c.sh.lkv) + ix (c.sh.lh - c.sh.lkv) j

def zint (a : Array ℤ) (k : ℕ) : GF := ((a.getD k 0 : ℤ) : GF)

def zw (k : Corp) (nm : String) (idx : ℕ) : GF := ((k.wval nm idx : ℤ) : GF)

/-- RoPE at `(t, i)` of a domain whose head index is live: `cos[t·half + i mod half]`, and `∓ sin` by the half. -/
def ropeC (k : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then zint k.ropeCos (t * (k.headDim / 2) + i % (k.headDim / 2)) else 0

def ropeS (k : Corp) (live : Bool) (t i : ℕ) : GF :=
  if live then
    (if i < k.headDim / 2 then -zint k.ropeSin (t * (k.headDim / 2) + i % (k.headDim / 2))
      else zint k.ropeSin (t * (k.headDim / 2) + i % (k.headDim / 2)))
  else 0

/-- **The record of the code's stored public data at the natural embedding of `c`'s cubes.** -/
def natF (c : W16Cfg) (k : Corp) : PubFR c where
  gD p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.ld p.2 < k.width then 1 else 0
  mask p := if ix c.sh.lt p.2.2 ≤ ix c.sh.lt p.2.1 then 1 else 0
  Wq x y := let row := slotOf c y.1.1 y.1.2 * k.headDim + ix c.sh.ldh y.2
    zw k "Q" (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "Q") row
  Wk x y := let row := ix c.sh.lkv y.1 * k.headDim + ix c.sh.ldh y.2
    zw k "K" (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "K") row
  Wv x y := let row := ix c.sh.lkv y.1 * k.headDim + ix c.sh.ldh y.2
    zw k "V" (row * k.dPad + ix c.sh.ld x) * zint (k.coefOf "V") row
  Wo x y := let col := slotOf c x.1.1 x.1.2 * k.headDim + ix c.sh.ldh x.2
    zw k "O" (ix c.sh.ld y * k.qPad + col) * zint (k.coefOf "O") (ix c.sh.ld y)
  Wg x f := zw k "G" (ix c.sh.ld x * k.fPad + ix c.sh.lf f) * zint (k.coefOf "G") (ix c.sh.lf f)
  Wu x f := zw k "U" (ix c.sh.ld x * k.fPad + ix c.sh.lf f) * zint (k.coefOf "U") (ix c.sh.lf f)
  Wd f y := zw k "D" (ix c.sh.lf f * k.dPad + ix c.sh.ld y) * zint (k.coefOf "D") (ix c.sh.ld y)
  gamA p := zint k.gamA (ix c.sh.ld p.2)
  gamM p := zint k.gamM (ix c.sh.ld p.2)
  cosT p := ropeC k (decide (ix c.sh.lt p.1 < k.tokens) && k.trueSlot.getD (slotOf c p.2.1.1 p.2.1.2) 0 == 1)
    (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  sinT p := ropeS k (decide (ix c.sh.lt p.1 < k.tokens) && k.trueSlot.getD (slotOf c p.2.1.1 p.2.1.2) 0 == 1)
    (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  cosK p := ropeC k (decide (ix c.sh.lt p.1 < k.tokens)) (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  sinK p := ropeS k (decide (ix c.sh.lt p.1 < k.tokens)) (ix c.sh.lt p.1) (ix c.sh.ldh p.2.2)
  grpCol p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.lf p.2 < k.hidden then zint k.groupIds (ix c.sh.lf p.2) else 0
  gF p := if ix c.sh.lt p.1 < k.tokens ∧ ix c.sh.lf p.2 < k.hidden then 1 else 0

/-- The R13 rung. -/
abbrev cR : W16Cfg := DefR13.cfgRungR13

/-- The Shieldstral layer `L` of the corpus (its entry of `shieldExport`). -/
def shieldL? (c : Corp) : Option ZK60.RunShape.Shield.ShieldLayer := ZK60.RunShape.Shield.shieldExport[c.layer]?

/-- **The corpus's configuration**: the rung, or the Shieldstral layer's `cfgShieldR13 L`. -/
def cfgOf (c : Corp) : W16Cfg :=
  if c.shield then (match shieldL? c with | some L => DefR13.cfgShieldR13 L | none => cR) else cR

/-- The public tables compared: the host slots' and `SC_LZC`'s. -/
def keys : List (ℕ × ℕ) :=
  [(0, 0), (1, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (10, 0), (11, 0), (12, 0), (13, 0), (14, 0), (14, 1),
    (14, 2), (15, 0), (15, 1), (16, 0), (16, 1), (17, 0), (18, 0), (18, 1)]

def foldSlots : List ℕ := [5, 6, 7, 10, 11, 12, 13]

def isFold (k : ℕ × ℕ) : Bool := foldSlots.contains k.1

def histC (c : Corp) : Hist := ⟨c.beta, c.gamma, c.alpha, []⟩

def drawsOf (c : Corp) (s : ℕ) : List Fp2 := ((c.draws.find? (·.1 == s)).map (·.2)).getD []

structure LTab where
  key : ℕ × ℕ
  vals : Array Fp2
  fp1 : Fp2
  fp2 : Fp2

/-- One Lean table: `pubsR13 (cfgOf c) … (restR13L (cfgOf c) …)`'s (through `pubsRFast_eq`, `pubsR13_pubsRF`) at
`natF` and the slot's draws (slot 3's table reads none of `exp`, `act`, `nG`: `restR13L_three`). -/
def leanTab (k : Corp) (key : ℕ × ℕ) : LTab :=
  let cfg := cfgOf k
  let v := pubsRFast cfg (natF cfg k) (restR13L cfg (fun _ => 0) (fun _ _ => 0) 0) key.1 (histC k) (drawsOf k key.1)
    key.2
  ⟨key, v.toArray, fprint v k.rho1, fprint v k.rho2⟩

/-- A fold table's Lean entries at the corpus's sampled indices (`foldSampleR_eq`: they ARE `pubsR13`'s). -/
def leanFold (k : Corp) (s : ℕ) : List Fp2 :=
  let cfg := cfgOf k
  let e := (eqTableMsb (foldDrawsR cfg s (drawsOf k s))).toArray
  let idx := ((k.fsamples.find? (·.1 == s)).map (·.2.1)).getD []
  idx.map (foldSampleR cfg (natF cfg k) s e)

/-- The Shieldstral T128 R13 shape's `supp(Dom::L)`: `restR13L (cfgShieldR13 L)`'s slot-3 table at every layer. -/
def shieldTab (k : Corp) : LTab :=
  let v := cubeTab (ZK60.Exec.Slot.R13.shShieldR13.logs .L) (gateLS ZK60.Exec.Slot.R13.shShieldR13)
  ⟨(3, 0), v.toArray, fprint v k.rho1, fprint v k.rho2⟩

/-- The Shieldstral table compared IS `restR13L (cfgShieldR13 L)`'s slot-3 table, at every layer. -/
theorem shieldTab_eq (L : ZK60.RunShape.Shield.ShieldLayer) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hist : Hist)
    (dr : List Fp2) :
    restR13L (DefR13.cfgShieldR13 L) exp act nG 3 hist dr 0
      = cubeTab (ZK60.Exec.Slot.R13.shShieldR13.logs .L) (gateLS ZK60.Exec.Slot.R13.shShieldR13) := rfl

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

def firstDiff (a b : Array Fp2) : Option ℕ := Id.run do
  if a.size ≠ b.size then return some (min a.size b.size)
  for i in [0:a.size] do
    if a.getD i Fp2.zero != b.getD i Fp2.zero then return some i
  return none

/-- Every entry of a stored weight matrix that reads a padded input is zero. -/
def padZero (a : Array ℤ) (rows cols : ℕ) (live : ℕ → ℕ → Bool) : Bool :=
  (List.range rows).all fun r => (List.range cols).all fun q => live r q || a.getD (r * cols + q) 0 == 0

/-- One table against its summary and (when present) its full entries. -/
def tabChecks (st : St) (tag : String) (r : PubRec) (full : Option (Array Fp2)) (t : LTab) : St := Id.run do
  let mut st := st
  st := st.check "length" (r.n == t.vals.size) s!"{tag}: code {r.n}, Lean {t.vals.size}"
  st := st.check "fingerprint" (r.fp1 == t.fp1) s!"{tag}: rho1 code {w2 r.fp1}, Lean {w2 t.fp1}"
  st := st.check "fingerprint" (r.fp2 == t.fp2) s!"{tag}: rho2 code {w2 r.fp2}, Lean {w2 t.fp2}"
  let e := min 64 t.vals.size
  st := st.check "ends" (r.head == (t.vals.extract 0 e).toList) s!"{tag}: head"
  st := st.check "ends" (r.tail == (t.vals.extract (t.vals.size - e) t.vals.size).toList) s!"{tag}: tail"
  match full with
  | none => pure ()
  | some v =>
    match firstDiff v t.vals with
    | none => st := st.check "entries" true ""
    | some i =>
      st := st.check "entries" false
        s!"{tag}: first difference at {i}: code {w2 (v.getD i Fp2.zero)}, Lean {w2 (t.vals.getD i Fp2.zero)}"
  return st

/-- The Shieldstral block's expected shape: `T = 128`, Shieldstral-1.0-3B's widths and their paddings. -/
def shieldShapeNums : List ℕ := [128, 3072, 9216, 32, 128, 8, 128, 4096, 16384, 32, 4096]

def checkAll (c : Corp) (lt : List LTab) (sl : LTab) (lf : List (ℕ × List Fp2)) : St := Id.run do
  let mut st : St := {}
  let cfg := cfgOf c
  let sh := cfg.sh
  st := st.check "parse" c.bad.isEmpty s!"unparsed lines: {c.bad}"
  st := st.check "header" (c.nSlots == ZK60.Exec.Slot.W16R2.nSlots ∧ c.logCols == cfg.logCols
      ∧ c.name == (if c.shield then "R13_SHIELD_T128_H24" else "R13_RUNG_H24"))
    s!"{c.name}: slots {c.nSlots}, log_cols {c.logCols}"
  if c.shield then
    st := st.check "layer" (match shieldL? c with | some L => c.gate == L.gate | none => false)
      s!"layer {c.layer}, gate shift {c.gate}: not the export's"
  st := st.check "shape" (c.shape == (if c.shield then shieldShapeNums else [32, 384, 768, 16, 64, 8, 32, 512, 1024, 16, 1024]))
    s!"shape {c.shape}"
  -- the corpus's paddings are the configuration's widths, and the token axis does not pad (what `gateLS` reads)
  st := st.check "widths" (c.tPad == 2 ^ sh.lt ∧ c.dPad == 2 ^ sh.ld ∧ c.fPad == 2 ^ sh.lf ∧ c.hPad == 2 ^ sh.lh
      ∧ c.qPad == 2 ^ sh.lq ∧ c.headDim == 2 ^ sh.ldh ∧ c.kvHeads == 2 ^ sh.lkv ∧ c.tokens == c.tPad
      ∧ c.lSize == 2 ^ sh.logs .L)
    s!"shape {c.shape}, L size {c.lSize} against the configuration's widths"
  st := st.check "data" (c.gamA.size == c.dPad ∧ c.gamM.size == c.dPad ∧ c.groupIds.size == c.hidden
      ∧ c.ropeCos.size == c.tokens * (c.headDim / 2) ∧ c.ropeSin.size == c.tokens * (c.headDim / 2)
      ∧ c.trueSlot.size == c.hPad ∧ c.coef.length == 7)
    "the public arrays' lengths"
  -- every slot's count of tables and of public tables is the program's
  let prog := DefR13.progR13 cfg 0 0
  for s in List.range c.nSlots do
    let sl := prog.getD s SlotS.empty
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
  if hasCols c then
    -- on the sampled columns: a column that reads a padded input is zero
    for (nm, k, _, v) in c.wcols do
      let padded :=
        if nm == "Q" ∨ nm == "K" ∨ nm == "V" then decide (c.width ≤ k)
        else if nm == "G" ∨ nm == "U" then decide (c.width ≤ k / c.fPad)
        else if nm == "D" then decide (c.hidden ≤ k / c.dPad) else false
      if padded then
        st := st.check "pad" (v.all (· == 0)) s!"W{nm} column at {k}: a padded input's weight is not zero"
  -- the public tables
  st := st.check "tables" (c.pubs.size == keys.length) s!"public tables {c.pubs.size} vs {keys.length}"
  for t in lt do
    if isFold t.key && !hasWeights c then
      st := { st with skipped := st.skipped + 1 }
    else
      match c.pubs.find? (fun r => r.s == t.key.1 ∧ r.i == t.key.2) with
      | none => st := st.check "tables" false s!"slot {t.key.1} table {t.key.2}: not in the corpus"
      | some r =>
        let full := (c.full.find? (fun q => q.1 == t.key.1 ∧ q.2.1 == t.key.2)).map (·.2.2)
        st := tabChecks st s!"slot {t.key.1} table {t.key.2}" r full t
  -- the folded weights at the sampled indices (the Shieldstral block)
  if c.shield then
    st := st.check "fold samples" (c.fsamples.size == foldSlots.length) s!"{c.fsamples.size} sampled folds"
    if hasCols c then
      for (s, ix, vs) in c.fsamples.toList do
        let ln := (lf.find? (·.1 == s)).map (·.2) |>.getD []
        st := st.check "fold samples" (ix.all (· < 2 ^ foldM cfg s) ∧ ln.length == vs.length)
          s!"slot {s}: sampled indices"
        let cols := c.wcols.size
        st := st.check "fold samples" (cols > 0) s!"slot {s}: no weight columns"
        for ((i, v), w) in (ix.zip vs).zip ln do
          st := st.check "fold samples" (v == w) s!"slot {s} entry {i}: code {w2 v}, Lean {w2 w}"
    else
      st := { st with skipped := st.skipped + c.fsamples.size }
  -- the rung corpus: the Shieldstral T128 R13 shape's `supp(Dom::L)`
  if !c.shield then
    st := st.check "shield" (c.shieldShape.drop 1 == ["128", "128", "16384"]) s!"Shieldstral shape {c.shieldShape}"
    match c.shieldL with
    | none => st := st.check "shield" false "no Shieldstral supp(Dom::L) in the corpus"
    | some r => st := tabChecks st "Shieldstral supp(Dom::L)" r c.shieldFull sl
  -- the Shieldstral block: its LogUp sum claim against `logupSumR13 (cfgShieldR13 L)`
  if c.shield then
    let lc := ZK60.Exec.Block.Join.R13H.Look.logupSumR13 cfg
    st := st.check "sum claim" (2 * (DefR13.hDoms cfg).length == lc.parts.length ∧ c.sumN == lc.parts.length
        ∧ c.parts.size == lc.parts.length)
      s!"parts: code {c.sumN} / {c.parts.size}, Lean {lc.parts.length}"
    st := st.check "sum claim" (c.sumVal == lc.value) s!"value: code {w2 c.sumVal}, Lean {w2 lc.value}"
    for (p, j) in lc.parts.zipIdx do
      let q := c.parts.getD j (0, 0, Fp2.zero, [Fp2.zero])
      st := st.check "sum claim" (q.1 == p.offset ∧ q.2.1 == p.logSize ∧ q.2.2.1 == p.coef ∧ q.2.2.2 == p.point)
        s!"part {j}: code {q.1}:{q.2.1}:{w2 q.2.2.1}:{w2s q.2.2.2} | Lean {p.offset}:{p.logSize}:{w2 p.coef}:{w2s p.point}"
  st := st.check "done" (c.done.map (·.1) == some keys.length) s!"done {c.done}"
  return st

/-! ## The negative controls -/

def setFull (c : Corp) (s i idx : ℕ) : Corp :=
  { c with full := c.full.map fun r =>
      if r.1 == s ∧ r.2.1 == i then (r.1, r.2.1, r.2.2.modify idx (fun x => Fp2.add x Fp2.one)) else r }

def setPubFp (c : Corp) (s i : ℕ) : Corp :=
  { c with pubs := c.pubs.map fun r => if r.s == s ∧ r.i == i then { r with fp1 := Fp2.add r.fp1 Fp2.one } else r }

def modW (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with weight := c.weight.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

/-- A sampled weight column's entry `j` of matrix `nm`'s first sampled column, changed (the maps rebuilt). -/
def modCol (c : Corp) (nm : String) (j : ℕ) : Corp :=
  let i := (c.wcols.findIdx? (·.1 == nm)).getD 0
  ({ c with wcols := c.wcols.modify i fun q => (q.1, q.2.1, q.2.2.1, q.2.2.2.modify j (· + 1)) }).finish

def modC (c : Corp) (nm : String) (k : ℕ) : Corp :=
  { c with coef := c.coef.map fun q => if q.1 == nm then (q.1, q.2.modify k (· + 1)) else q }

def modDraw (c : Corp) (s k : ℕ) : Corp :=
  { c with draws := c.draws.map fun q => if q.1 == s then (q.1, q.2.modify k (fun x => Fp2.add x Fp2.one)) else q }

/-- One change: its name, the tables it concerns, whether the Lean side's inputs change (those tables recomputed),
the changed corpus. -/
def mutsAll (c : Corp) : List (String × List (ℕ × ℕ) × Bool × Corp) :=
  let full := !c.full.isEmpty
  let tabMut (k : ℕ × ℕ) : Corp :=
    if full then setFull c k.1 k.2 (if isFold k then 7 else 1000) else setPubFp c k.1 k.2
  let tables := (keys.filter fun k => !(c.shield && isFold k)).map fun k =>
    (s!"the code's table {k}, one entry", [k], false, tabMut k)
  let common := [("a folding multiplier of Q (row 10)", [(5, 0)], true, modC c "Q" 10),
      ("a folding multiplier of the gate (channel 10)", [(11, 0)], true, modC c "G" 10),
      ("gamma_a[5]", [(14, 0)], true, { c with gamA := c.gamA.modify 5 (· + 1) }),
      ("gamma_m[7]", [(14, 1)], true, { c with gamM := c.gamM.modify 7 (· + 1) }),
      ("rope_cos[3]", [(15, 0), (16, 0)], true, { c with ropeCos := c.ropeCos.modify 3 (· + 1) }),
      ("rope_sin[9]", [(15, 1), (16, 1)], true, { c with ropeSin := c.ropeSin.modify 9 (· + 1) }),
      ("a group id (channel 4)", [(18, 0)], true, { c with groupIds := c.groupIds.modify 4 (· + 1) }),
      ("head slot 1 not a true head", [(15, 0), (15, 1)], true, { c with trueSlot := c.trueSlot.set! 1 0 }),
      ("a draw of SC_QMM's fold (draw 7)", [(5, 0)], true, modDraw c 5 7),
      ("a draw of SC_WO's fold (the first output draw)", [(10, 0)], true, modDraw c 10 (cfgOf c).sh.lt),
      ("one token fewer (tokens < t_pad)", [(0, 0), (1, 0), (14, 2), (18, 0), (18, 1)], !c.shield,
        { c with shape := c.shape.set 0 (c.tokens - 1) }),
      ("slot 3's count of public tables", [], false,
        { c with slots := c.slots.map fun q => if q.1 == 3 then (q.1, q.2.1, q.2.2 + 1) else q }),
      ("slot 14's count of public tables", [], false,
        { c with slots := c.slots.map fun q => if q.1 == 14 then (q.1, q.2.1, q.2.2 + 1) else q })]
  if c.shield then
    tables ++ common.filter (fun m => hasCols c || !(m.2.1.any isFold))
      ++ (if hasCols c then
          [("a sampled entry of SC_GMM's fold (the code's)", [], false,
              { c with fsamples := c.fsamples.map fun q => if q.1 == 11 then (q.1, q.2.1, q.2.2.set 5 (Fp2.add (q.2.2.getD 5 Fp2.zero) Fp2.one)) else q }),
            ("a sampled entry of SC_WO's fold (the code's)", [], false,
              { c with fsamples := c.fsamples.map fun q => if q.1 == 10 then (q.1, q.2.1, q.2.2.set 70 (Fp2.add (q.2.2.getD 70 Fp2.zero) Fp2.one)) else q }),
            ("a weight of Wq's first sampled column (row 3)", [(5, 0)], true, modCol c "Q" 3),
            ("a weight of Wk's first sampled column (row 3)", [(6, 0)], true, modCol c "K" 3),
            ("a weight of Wv's first sampled column (row 3)", [(7, 0)], true, modCol c "V" 3),
            ("a weight of Wo's first sampled column (row 3)", [(10, 0)], true, modCol c "O" 3),
            ("a weight of Wg's first sampled column (channel 3)", [(11, 0)], true, modCol c "G" 3),
            ("a weight of Wu's first sampled column (channel 3)", [(12, 0)], true, modCol c "U" 3),
            ("a weight of Wd's first sampled column (output 3)", [(13, 0)], true, modCol c "D" 3)]
        else [])
      ++ [("the sum claim's value", [], false, { c with sumVal := Fp2.add c.sumVal Fp2.one }),
          ("a sum claim part's offset (part 9)", [], false,
            { c with parts := c.parts.modify 9 fun q => (q.1 + 1, q.2) }),
          ("a sum claim part's coefficient (part 0)", [], false,
            { c with parts := c.parts.modify 0 fun q => (q.1, q.2.1, Fp2.add q.2.2.1 Fp2.one, q.2.2.2) }),
          ("the layer's gate shift", [], false, { c with gate := c.gate + 1 })]
  else
    tables
      ++ [("a weight of Wq (row 3, column 5)", [(5, 0)], true, modW c "Q" (3 * c.dPad + 5)),
          ("a weight of Wk (row 3, column 5)", [(6, 0)], true, modW c "K" (3 * c.dPad + 5)),
          ("a weight of Wv (row 3, column 5)", [(7, 0)], true, modW c "V" (3 * c.dPad + 5)),
          ("a weight of Wo (row 3, column 5)", [(10, 0)], true, modW c "O" (3 * c.qPad + 5)),
          ("a weight of Wg (input 5, output 3)", [(11, 0)], true, modW c "G" (5 * c.fPad + 3)),
          ("a weight of Wu (input 5, output 3)", [(12, 0)], true, modW c "U" (5 * c.fPad + 3)),
          ("a weight of Wd (input 5, output 3)", [(13, 0)], true, modW c "D" (5 * c.dPad + 3)),
          ("the Shieldstral supp(Dom::L), one entry", [], false,
            match c.shieldFull with
            | some v => { c with shieldFull := some (v.modify 1000 (fun x => Fp2.add x Fp2.one)) }
            | none => { c with shieldL := c.shieldL.map fun r => { r with fp1 := Fp2.add r.fp1 Fp2.one } }),
          ("the Shieldstral supp(Dom::L), a head entry", [], false,
            { c with shieldL := c.shieldL.map fun r =>
                { r with head := r.head.mapIdx fun j x => if j = 3 then Fp2.add x Fp2.one else x } })]
      ++ common

/-- The changes this corpus can show: a change that concerns a folded table needs the weights it reads. -/
def muts (c : Corp) : List (String × List (ℕ × ℕ) × Bool × Corp) :=
  (mutsAll c).filter fun m => hasWeights c || hasCols c || !(m.2.1.any isFold)

def report (st : St) : IO Unit := do
  for (k, n) in st.kinds do
    IO.println s!"  {k}: {n}"
  for m in st.msgs do
    IO.println s!"  FAIL {m}"

end ZK60.Exec.Block.Join.R13H.Pub.Chk

open ZK60.Exec.Block.Join.R13H.Pub.Chk in
def main (args : List String) : IO UInt32 := do
  let path := args.headD ""
  let txt ← IO.FS.readFile path
  let c := ((txt.splitOn "\n").foldl parseLine {}).finish
  IO.println s!"corpus {path}: {c.name}{if c.shield then s!" layer {c.layer}" else ""}, {c.pubs.size} tables, {c.full.size} in full, weights {hasWeights c}, sampled columns {c.wcols.size}"
  let lt := keys.map fun k =>
    if isFold k && !hasWeights c then (⟨k, #[], ZK60.Exec.Fp2.zero, ZK60.Exec.Fp2.zero⟩ : LTab) else leanTab c k
  let lf := if c.shield && hasCols c then foldSlots.map fun s => (s, leanFold c s) else []
  let sl := shieldTab c
  let st := checkAll c lt sl lf
  IO.println s!"checks: {st.ok} passed, {st.fail} failed, {st.skipped} fold tables skipped (their weights are not in this corpus)"
  report st
  let mut rc : UInt32 := if st.fail = 0 then 0 else 1
  if args.contains "neg" then
    let ms := muts c
    let mut caught := 0
    for (nm, ks, recompute, c') in ms do
      let lt' := lt.map fun t => if recompute && ks.contains t.key && !(isFold t.key && !hasWeights c') then leanTab c' t.key else t
      let lf' := lf.map fun q => if recompute && ks.contains (q.1, 0) then (q.1, leanFold c' q.1) else q
      let st' := checkAll c' lt' sl lf'
      if st'.fail > 0 then
        caught := caught + 1
        IO.println s!"negative control CAUGHT ({st'.fail} failed): {nm}"
      else
        IO.println s!"negative control MISSED: {nm}"
    IO.println s!"negative controls: {caught} of {ms.length} caught"
    if caught ≠ ms.length then rc := 1
  return rc
