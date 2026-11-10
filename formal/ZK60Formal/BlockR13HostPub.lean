/-
D63 lane L49 (2026-11-10), sub-agent `pub`: **the verifier's public tables at an R13 configuration, from the block's
public data, generic in the configuration** (the R13 counterpart of lane L44's `BlockHostPub.lean`, `pubsW16` and
`pubW16_of`), for the R13 rung (`cfgRungR13`) and every layer of the Shieldstral T128 R13 block (`cfgShieldR13 L`).

The code (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/`, read 2026-11-10; nothing there is changed): the shared
arms of `argument.rs::define` (`SC_SS`, `SC_SSM`, `SC_LZC`, `SC_RS`, the seven matmuls: `r_q` / `r_tf` / `r_row` of
`lt` draws first where the slot draws one, then `r_j` of `lg(outer)` draws, `eq_table_msb(r_j)`, `accuracy_fold::fold`
with the multipliers) and R13's `argument_accuracy.rs` (`dzc`: `γ_a`, `γ_m`, `supp(D)`; `qzc`: `cos`, `sin`; `szc`:
the causal mask; `fzc`: the group column, `supp(F)`); a gate is `B::supp`, `pad::indicator_table` laid over the cube.

* **`pubsR13 c Pb Lay B rest`**: every public table the R13 hosts read, built from `B` in the code's arithmetic
  (`cubeTab`, `foldTab` of L44), at the configuration's widths (`nD c`, `nQ c`, `nK c`, `nS c`, `nF c`, `c.sh.ld`,
  `c.sh.lf`, the head slot `nH c + c.sh.ldh`) and draw offsets (`c.sh.lt` or `0`); the lookup side's slots `3`, `19`,
  `20` from `rest` (`pubsR13_rest`);
* **`pubR_of`**: `PubR U c (pubsR13 c Pb Lay B rest) Pb Lay B`, for every `c` and every `rest` (no fact about `c`);
* `SC_LZC`'s public table (slot `3`, `DefR13.rawSlot c 3`): **`gateLS sh`**, `supp(Dom::L)` (`x / 2^lt < 9`: the
  token axis, which does not pad at R13, and the `3·LIMBS_ISQRT = 9` limb rows); lane L47's `restR13` does NOT carry
  it (`restR13_three`: its slot `3` is `[]`), so **`restR13L c exp act nG`** extends it at slot `3`
  (`restR13L_three`, `restR13L_ne`, `rest3R13L_getD`); `gateLS_rung`: at the rung it IS L47's W16R2 `gateLW`;
* **`PubCfg c`** (`Dom::L` pads under the pad rule), `pubCfg_rung`, `pubCfg_shield`; `zeroPl_L`, `lzc_gate`,
  **`rawSlot3_tabs`**: R13's raw slot `3` reads exactly one public table, its last;
* `pubsR13L`, `pubR_of_L`: the tables with `restR13L` at a block's public data.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostBase
import ZK60Formal.BlockR13JoinTab

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Pub

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (wordGF toK_wordGF cubeTab cubeTab_getD drSeg foldTab fold_eqDr)
open ZK60.Exec.Block.Join.R13T (restR13)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (ShapeW)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## The host slots' public tables -/

section Pubs

variable (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- **The verifier's public tables at an R13 configuration `c`, from the public data `B`**: table `i` of slot `s` at
the history and the slot's draws `dr`; the supports, the norms' gains, the causal mask, RoPE's `cos` / `sin`, the
activation's group column on their domains' cubes, and the seven matmuls' weights folded by `eq` of the slot's output
draws (`r_j` after `lt` row draws at `SC_QMM`, `SC_WO`, `SC_GMM`, `SC_DMM`; from draw `0` at `SC_KMM`, `SC_VMM`,
`SC_UMM`); the lookup side's tables (`SC_LZC`, `SC_TAB`, `SC_ZS`, slots `3`, `19`, `20`) from `rest`. -/
def pubsR13 (rest : PubTabs) : PubTabs := fun s hist dr i =>
  if s = 0 ∨ s = 1 then (if i = 0 then cubeTab (nD c) (fun b => B.gD (splitD c b)) else [])
  else if s = 4 then (if i = 0 then cubeTab (nS c) (fun b => B.mask (splitS c b)) else [])
  else if s = 5 then
    (if i = 0 then foldTab c.sh.ld (nH c + c.sh.ldh) (fun w y => B.Wq w (splitHQ c y))
      (drSeg dr c.sh.lt (nH c + c.sh.ldh)) else [])
  else if s = 6 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wk w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 7 then
    (if i = 0 then foldTab c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wv w (splitGD c y))
      (drSeg dr 0 (c.sh.lkv + c.sh.ldh)) else [])
  else if s = 10 then
    (if i = 0 then foldTab (nH c + c.sh.ldh) c.sh.ld (fun q y => B.Wo (splitHQ c q) y) (drSeg dr c.sh.lt c.sh.ld)
      else [])
  else if s = 11 then
    (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => B.Wg w y) (drSeg dr c.sh.lt c.sh.lf) else [])
  else if s = 12 then (if i = 0 then foldTab c.sh.ld c.sh.lf (fun w y => B.Wu w y) (drSeg dr 0 c.sh.lf) else [])
  else if s = 13 then
    (if i = 0 then foldTab c.sh.lf c.sh.ld (fun f y => B.Wd f y) (drSeg dr c.sh.lt c.sh.ld) else [])
  else if s = 14 then
    (if i = 0 then cubeTab (nD c) (fun b => B.gamA (splitD c b))
      else if i = 1 then cubeTab (nD c) (fun b => B.gamM (splitD c b))
      else if i = 2 then cubeTab (nD c) (fun b => B.gD (splitD c b)) else [])
  else if s = 15 then
    (if i = 0 then cubeTab (nQ c) (fun b => B.cosT (splitQ c b))
      else if i = 1 then cubeTab (nQ c) (fun b => B.sinT (splitQ c b)) else [])
  else if s = 16 then
    (if i = 0 then cubeTab (nK c) (fun b => B.cosK (splitK c b))
      else if i = 1 then cubeTab (nK c) (fun b => B.sinK (splitK c b)) else [])
  else if s = 17 then (if i = 0 then cubeTab (nS c) (fun b => B.mask (splitS c b)) else [])
  else if s = 18 then
    (if i = 0 then cubeTab (nF c) (fun b => B.grpCol (splitF c b))
      else if i = 1 then cubeTab (nF c) (fun b => B.gF (splitF c b)) else [])
  else rest s hist dr i

/-- **The lookup side's slots read `rest`.** -/
theorem pubsR13_rest (rest : PubTabs) (s : ℕ) (hs : s = 3 ∨ s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2)
    (i : ℕ) : pubsR13 c Pb Lay B rest s hist dr i = rest s hist dr i := by
  rcases hs with rfl | rfl | rfl <;> rfl

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The concrete public tables meet `PubR`**, at every configuration `c`, for every `rest`. -/
theorem pubR_of (rest : PubTabs) : PubR U c (pubsR13 c Pb Lay B rest) Pb Lay B where
  ssGate s hs hist dr t w := by
    have h : pubsR13 c Pb Lay B rest s hist dr 0 = cubeTab (nD c) (fun b => B.gD (splitD c b)) := by
      unfold pubsR13; rw [ite_eq_left hs, ite_eq_left rfl]
    rw [h, cubeTab_getD, toK_wordGF, show splitD c (Fin.append t w) = (t, w) from splitD_append c (t, w)]
  rsMask hist dr b := by
    show ((cubeTab (nS c) (fun b => B.mask (splitS c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  wq hist dr hdr w := fold_eqDr U hU c.sh.ld (nH c + c.sh.ldh) (fun w y => B.Wq w (splitHQ c y)) dr hdr c.sh.lt w
  wk hist dr hdr w := fold_eqDr U hU c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wk w (splitGD c y)) dr hdr 0 w
  wv hist dr hdr w := fold_eqDr U hU c.sh.ld (c.sh.lkv + c.sh.ldh) (fun w y => B.Wv w (splitGD c y)) dr hdr 0 w
  wo hist dr hdr q := fold_eqDr U hU (nH c + c.sh.ldh) c.sh.ld (fun q y => B.Wo (splitHQ c q) y) dr hdr c.sh.lt q
  wg hist dr hdr w := fold_eqDr U hU c.sh.ld c.sh.lf (fun w y => B.Wg w y) dr hdr c.sh.lt w
  wu hist dr hdr w := fold_eqDr U hU c.sh.ld c.sh.lf (fun w y => B.Wu w y) dr hdr 0 w
  wd hist dr hdr f := fold_eqDr U hU c.sh.lf c.sh.ld (fun f y => B.Wd f y) dr hdr c.sh.lt f
  dzcGamA hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gamA (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGamM hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gamM (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  dzcGate hist dr b := by
    show ((cubeTab (nD c) (fun b => B.gD (splitD c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcCos hist dr b := by
    show ((cubeTab (nQ c) (fun b => B.cosT (splitQ c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  qzcSin hist dr b := by
    show ((cubeTab (nQ c) (fun b => B.sinT (splitQ c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvCos hist dr b := by
    show ((cubeTab (nK c) (fun b => B.cosK (splitK c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  kvSin hist dr b := by
    show ((cubeTab (nK c) (fun b => B.sinK (splitK c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  szcMask hist dr b := by
    show ((cubeTab (nS c) (fun b => B.mask (splitS c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGrp hist dr b := by
    show ((cubeTab (nF c) (fun b => B.grpCol (splitF c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]
  fzcGate hist dr b := by
    show ((cubeTab (nF c) (fun b => B.gF (splitF c b))).getD _ _).toK U = _
    rw [cubeTab_getD, toK_wordGF]

end Pubs

/-! ## `SC_LZC`'s public table: `supp(Dom::L)` -/

section Lzc

/-- **`supp(Dom::L)` at a shape** (`pad.rs::support_indicator`, the builder's support `lix(k, t) = k·t_pad + t` for
`k < 3·LIMBS_ISQRT = 9`, `t < tokens`; at R13 `tokens = t_pad = 2^lt`, CHECKED by the export): `x / 2^lt < 9`. -/
def gateLS (sh : ShapeW) (b : Fin (sh.logs .L) → Bool) : GF := if msbIndex (sh.logs .L) b / 2 ^ sh.lt < 9 then 1 else 0

/-- **At the R13 rung, `supp(Dom::L)` is L47's W16R2 `gateLW`** (the same `14`-variable cube, the same `32` tokens). -/
theorem gateLS_rung : gateLS ZK60.Exec.Slot.R13.shRungR13 = ZK60.Exec.Block.Join.W16.Tab.gateLW := rfl

/-- **L47's `restR13` does not carry `SC_LZC`'s table** (its slot `3` is empty), which R13's raw slot `3` reads
(`rawSlot3_tabs`). -/
theorem restR13_three (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13 exp act nG 3 hist dr i = [] := rfl

/-- **R13's lookup-side public tables, with `SC_LZC`'s**: `supp(Dom::L)` at slot `3` (table `0`), L47's `restR13`
(`SC_TAB`'s three value columns and two gates, `SC_ZS`'s all-ones table) elsewhere. -/
def restR13L (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : PubTabs := fun s hist dr i =>
  if s = 3 then (if i = 0 then cubeTab (c.sh.logs .L) (gateLS c.sh) else []) else restR13 exp act nG s hist dr i

variable (c : W16Cfg) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)

theorem restR13L_three (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13L c exp act nG 3 hist dr i = if i = 0 then cubeTab (c.sh.logs .L) (gateLS c.sh) else [] := rfl

/-- Outside slot `3`, `restR13L` is L47's `restR13` (so L47's `rest19R13_getD`, `rest19R13_gate_getD`,
`rest20R13_getD` read it). -/
theorem restR13L_ne (s : ℕ) (hs : s ≠ 3) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    restR13L c exp act nG s hist dr i = restR13 exp act nG s hist dr i := by
  show (if s = 3 then _ else _) = _
  rw [ite_eq_right hs]

/-- **`SC_LZC`'s table, read in the field**: `supp(Dom::L)`. -/
theorem rest3R13L_getD {K : Type} [Field K] [Algebra GF K] (U : K) (hist : Hist) (dr : List Fp2)
    (b : Fin (c.sh.logs .L) → Bool) :
    ((restR13L c exp act nG 3 hist dr 0).getD (msbIndex (c.sh.logs .L) b) Fp2.zero).toK U
      = algebraMap GF K (gateLS c.sh b) := by
  show ((cubeTab (c.sh.logs .L) (gateLS c.sh)).getD _ _).toK U = _
  rw [cubeTab_getD, toK_wordGF]

end Lzc

/-! ## R13's raw slot `3` reads one public table -/

section Raw

/-- **The facts about a configuration this file reads**: the pad rule is on and `Dom::L` pads. PROVED at the rung and
at every Shieldstral layer (`pubCfg_rung`, `pubCfg_shield`). -/
structure PubCfg (c : W16Cfg) : Prop where
  padRule : c.sh.padRule = true
  padsL : c.sh.pads .L = true

theorem pubCfg_rung : PubCfg DefR13.cfgRungR13 := ⟨rfl, rfl⟩

theorem pubCfg_shield (L : ZK60.RunShape.Shield.ShieldLayer) : PubCfg (DefR13.cfgShieldR13 L) := ⟨rfl, rfl⟩

/-- `A_E`'s id is `77 + nrd` (`AccuracyIds::new`). -/
theorem idsR13_e (h24 : Bool) (ls : ℕ) : (DefR13.idsR13 h24 ls).e = 77 + (if h24 then 3 else 2) := by
  cases h24 <;> rfl

/-- **`Dom::L`'s zero-rule planes are its two limb planes** (`A_LIMB`, `A_LIMBM`; `A_E` is not on `Dom::L`). -/
theorem zeroPl_L (c : W16Cfg) (hc : PubCfg c) : DefR13.zeroPl c .L = [6, 7] := by
  have he : 79 ≤ (DefR13.ids c).e := by
    show 79 ≤ (DefR13.idsR13 c.p.h24 (DefR13.lsOf c.p)).e
    rw [idsR13_e]
    split <;> omega
  have h6 : (6 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  have h7 : (7 == (DefR13.ids c).e) = false := beq_eq_false_iff_ne.mpr (by omega)
  unfold DefR13.zeroPl
  rw [hc.padRule, hc.padsL]
  show List.filter (fun i => !(i == (DefR13.ids c).e)) [6, 7] = [6, 7]
  simp [List.filter, h6, h7]

/-- **R13's `SC_LZC` reads `supp(Dom::L)`**: the gate of its raw slot is on. -/
theorem lzc_gate (c : W16Cfg) (hc : PubCfg c) :
    (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true := by
  rw [zeroPl_L c hc]
  show (c.sh.padRule && c.sh.pads .L && !([6, 7] : List ℕ).isEmpty) = true
  rw [hc.padRule, hc.padsL]
  rfl

/-- **R13's raw slot `3` (`SC_LZC`)**: the `τ` table, the two limb planes, the helper, and ONE public table, its last
(the numbering makes it public table `0`). -/
theorem rawSlot3_tabs (c : W16Cfg) (hc : PubCfg c) :
    (DefR13.rawSlot c 3).tabs = [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb,
      DefR13.aPlane c (DefR13.ids c).limbm, DefR13.hTab c (DefR13.fh c 0), TabS.pub 0] := by
  show [TabS.eq (DefR13.seg c 3 0) 0, DefR13.aPlane c (DefR13.ids c).limb, DefR13.aPlane c (DefR13.ids c).limbm,
      DefR13.hTab c (DefR13.fh c 0)]
      ++ (if (ZK60.Exec.Block.DefW16.supp c .L && !(DefR13.zeroPl c .L).isEmpty) = true then [TabS.pub 0] else []) = _
  rw [lzc_gate c hc]
  rfl

end Raw

/-! ## The tables at a block's public data -/

section Final

variable (c : W16Cfg) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay) (nG : ℕ)

/-- **Every public table R13's program reads**: the hosts' from `B`, the lookup side's from the public data (`SC_LZC`'s
support, `SC_TAB`'s value columns and gates at the exp table and the scaled ACT tables, `SC_ZS`'s ones). -/
def pubsR13L : PubTabs := pubsR13 c Pb Lay B (restR13L c Pb.exp Pb.act nG)

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
theorem pubR_of_L : PubR U c (pubsR13L c Pb Lay B nG) Pb Lay B := pubR_of c Pb Lay B U hU _

/-- `SC_LZC`'s table of `pubsR13L`, read in the field: `supp(Dom::L)`. -/
theorem pubsR13L_three_getD (hist : Hist) (dr : List Fp2) (b : Fin (c.sh.logs .L) → Bool) :
    ((pubsR13L c Pb Lay B nG 3 hist dr 0).getD (msbIndex (c.sh.logs .L) b) Fp2.zero).toK U
      = algebraMap GF K (gateLS c.sh b) :=
  rest3R13L_getD c Pb.exp Pb.act nG U hist dr b

/-- `SC_TAB`'s and `SC_ZS`'s tables of `pubsR13L` are L47's `restR13`'s. -/
theorem pubsR13L_tab (s : ℕ) (hs : s = 19 ∨ s = 20) (hist : Hist) (dr : List Fp2) (i : ℕ) :
    pubsR13L c Pb Lay B nG s hist dr i = restR13 Pb.exp Pb.act nG s hist dr i := by
  rcases hs with rfl | rfl <;> rfl

end Final

end ZK60.Exec.Block.Join.R13H.Pub
