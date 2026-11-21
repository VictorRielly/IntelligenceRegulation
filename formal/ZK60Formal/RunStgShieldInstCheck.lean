/-
D63 lane L63 (2026-11-21), L63 leg 19: **the Shield run's instance constants against the code's exports.**

Run (through the zk60 resource guard; `results/zk60_lean_l63_20261116/check_l63merge.sh` does it as a regression):
  lake -d formal env lean --run formal/ZK60Formal/RunStgShieldInstCheck.lean \
    results/zk60_lean_l17_20261107/shape_corpus.txt results/zk60_lean_l49_20261110/pub_shield_short.txt \
    results/zk60_lean_l17_20261107/segment_corpus.txt

Why (findings L68b-1 and L68b-2): two constants of the committed Shield block instance were wrong for days because no
proof read them and no check compared them with the code. This file closes that gap for every instance constant that a
committed code-side export carries. It has two halves, both run on every regression:

* **the ties (theorems, elaborated on every run):** each field of the instances the top `sshC_productionReadyL_epP_blkEF`
  reaches (`shdP_blkParams`, `shdP_rowsOf`, `shdP_slotKind`, `shdP_rtBlk`, `shdP_sgeom`, `shdP_incPub`, `shdP_outcPub`,
  `shdP_bitLay`'s cube widths through `cfgShieldR13`, `r13Prm`) IS a named definition (`R13.shieldSlots`,
  `numsR13Shield.rA`, `shShieldR13`, `cbBndRows`, `kindOf`, …), for EVERY tag, layer, public data and run;
* **the comparison (`main`):** those named definitions against the committed exports of the production code: L17's shape
  corpus (`lean_l17_export_r13_shapes`: the registered `R13_SHIELD_T128_H24` shape's own constructors), L49's Shieldstral
  block export (`lean_l49_export_a_shieldstral_block`: the production `Shape` and `define` of one layer proved by the
  production `prove_core` and accepted by `verify_core`) and L17's segment corpus (the R13 rung's segment shape, for the
  one R13-generic constant it carries, the wire ceiling).

A change to an instance constant now breaks a tie (the file no longer elaborates), and a change to a named definition
or to the code's export fails a comparison. Prints the checks per kind and `RunStgShieldInstCheck: N checks, F failed`;
exits nonzero on any failure. Not imported by the library root (it defines `main`).

Only `propext`, `Classical.choice`, `Quot.sound` (the `#print axioms` lines below; the check script audits them).
-/
import ZK60Formal.RunShieldBlkInst
import ZK60Formal.RunCloseBGeo
import ZK60Formal.BlockInstProf
import ZK60Formal.SlotR13

set_option autoImplicit false

namespace ZK60.ProtocolClassify.ShdInstCheck

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.ProtocolClassify
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm SlotKind)
open ZK60.RunShape (ClassifyRunPublicP RunBlock)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldS0 shieldShape)

/-! ## 1. The ties: every instance field IS a named definition (checked by the kernel on every run) -/

section Ties

variable (tag : MTag) (ioIn ioOut : ℕ)
  (co : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
  (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))

/-- The block instance's schedule, terminal counts and draws are the R13 Shieldstral lists. -/
theorem shdIC_lists :
    (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.slots = Exec.Block.R13.shieldSlots
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.terms = Exec.Block.R13.shieldTerms
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).draws = Exec.Block.R13.shieldDraws :=
  ⟨rfl, rfl, rfl⟩

/-- The block instance's counts are `numsR13Shield`'s (the numbers `BlockInstCheck` and `main` compare with the code):
rows, groups, functionals; the mask's rows are `2·S + 4` for the `S` mask specs `maskField` reads. -/
theorem shdIC_counts :
    (shdP_blkParams tag ioIn ioOut co Ly Pb).aRows = numsR13Shield.rA
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).hRows = numsR13Shield.rH
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.aRows = numsR13Shield.rA
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.hRows = numsR13Shield.rH
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.aGroups = numsR13Shield.aGroups
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.hGroups = numsR13Shield.hGroups
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).nFunctionals = numsR13Shield.nFun
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.mRows = 2 * numsR13Shield.S + 4
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).maskVerify = maskField tag numsR13Shield.S :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- The block instance's opening geometry is R13's: the row width, the endpoint row width, the block `Dim`, the `A` /
`H` Merkle depths (the block `Dim`'s), `M`'s constants (`zk.rs`'s, profile-independent), the wire ceiling, the PCS field
at `shdP_rowsOf`. -/
theorem shdIC_geometry :
    (shdP_blkParams tag ioIn ioOut co Ly Pb).logCols = Exec.Block.R13.logCols
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).endpointLogN = Exec.Block.R13.logCols
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.blk = Exec.Block.R13.blkDim
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).aPath = Exec.Block.R13.blkDim.path
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).hPath = Exec.Block.R13.blkDim.path
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).maskPath = Exec.Block.W16R2.maskPath
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.maskPath = Exec.Block.W16R2.maskPath
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.maskVec = Exec.Block.W16R2.maskVec
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.maskChecks = Exec.Block.W16R2.maskQ
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.maskDom = Exec.Block.W16R2.maskDom
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).geom.ceiling = Exec.Block.R13.ceiling
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).pcsVerify = ZK60.Exec.R13.pcsFieldR13 tag shdP_rowsOf
    ∧ (shdP_blkParams tag ioIn ioOut co Ly Pb).kind = shdP_slotKind :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- The layer's cube widths (the types of `shdP_bitLay Ly`: `CtR`, `CwR`, `CgR`, `CjR`, `CdR`, `CfR` of
`cfgShieldR13 Ly`) are `shShieldR13`'s, at every layer. -/
theorem shdIC_cube : (Exec.Block.DefR13.cfgShieldR13 Ly).sh = Exec.Slot.R13.shShieldR13 := rfl

end Ties

/-- `shdP_rowsOf`: `A` and `H` at `numsR13Shield`'s rows; the endpoint commitments at a boundary's rows
(`cbBndRows` at `t_pad 128`, `d_pad 4096`, `endpoint_log_n 14`, two sites; `RunCloseBGeoCheck` checks the formula). -/
theorem shdIC_rowsOf :
    shdP_rowsOf .a = numsR13Shield.rA ∧ shdP_rowsOf .h = numsR13Shield.rH
    ∧ shdP_rowsOf .inp = cbBndRows 128 4096 14 2 ∧ shdP_rowsOf .out = cbBndRows 128 4096 14 2 := by
  refine ⟨rfl, rfl, ?_, ?_⟩ <;> rw [cbBndRows_r13] <;> rfl

/-- A slot kind as a number (`priv 0`, `standalone 1`, `host 2`), for both kind types. -/
def kcB : SlotKind → ℕ
  | .priv => 0
  | .standalone => 1
  | .host => 2

def kcW : Exec.Slot.W16R2.Kind → ℕ
  | .priv => 0
  | .standalone => 1
  | .host => 2

/-- **The instance's slot kinds are `kindOf`'s** (layout.rs `SLOT_KINDS`; `CheckR13Slots` checks `kindOf` slot by slot
on the R13 rung's receipt, and the 23-slot kinds are the same at every R13 / W16R2 shape). -/
theorem shdIC_kinds : ∀ s, s < 23 → kcB (shdP_slotKind s) = kcW (Exec.Slot.W16R2.kindOf s) := by decide

section RunTies

variable (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
  {dPos0 : shieldS0.Pos → (Fin 7 → Bool) × (Fin 12 → Bool)}
  {Pk0 : ℕ → BlockParams} {blks : List (RunBlock shieldS0)}
  (hPk0 : ShieldRunAtD tag dPos0 Pk0 blks 26) (k : ℕ)

/-- `shdP_rtBlk`'s data fields are `numsR13Shield`'s and R13's opening parameters. -/
theorem shdIC_rtBlk :
    (shdP_rtBlk Lq hL20 tag hPk0 k).S = numsR13Shield.S
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).nA = numsR13Shield.nA
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).nH = numsR13Shield.nH
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.rows = numsR13Shield.rA
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pH.rows = numsR13Shield.rH
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.prm = ZK60.Exec.R13.r13Prm
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pH.prm = ZK60.Exec.R13.r13Prm
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.lc = Exec.Block.R13.logCols
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.Q = Exec.Block.R13.openedCols
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.N = Exec.Block.R13.blkDim.encCols
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pA.m = numsR13Shield.mI
    ∧ (shdP_rtBlk Lq hL20 tag hPk0 k).pH.m = numsR13Shield.mI :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

end RunTies

/-- `r13Prm` is R13's row width, rate and opened columns. -/
theorem shdIC_r13Prm :
    ZK60.Exec.R13.r13Prm = ⟨Exec.Block.R13.logCols, Exec.Block.R13.invRate, Exec.Block.R13.openedCols,
      Exec.Block.R13.openedCols⟩ := rfl

/-- The block segments' geometry: R13's endpoint `Dim`, `L = 26 + 2`, a boundary's rows (`cbBndRows`), two sites. -/
theorem shdIC_sgeom (Hdr : Type) (Pk : ℕ → BlockParams) (st : ClsStmt Hdr) (k : ℕ) :
    (shdP_sgeom Hdr Pk st k).ed = Exec.Block.R13.blkDim ∧ (shdP_sgeom Hdr Pk st k).l = 26 + 2
    ∧ (shdP_sgeom Hdr Pk st k).k = k + 1 ∧ (shdP_sgeom Hdr Pk st k).boundaryRows = cbBndRows 128 4096 14 2
    ∧ (shdP_sgeom Hdr Pk st k).sites = 2 := by
  refine ⟨rfl, rfl, rfl, ?_, rfl⟩
  rw [cbBndRows_r13]
  rfl

/-- The stages' token and width axes: `shieldS0`'s `T` and `d`, padded to the cube widths of `shShieldR13`. -/
theorem shdIC_stageAxes (Rp : ClassifyRunPublicP shieldS0) (embDigest wDigest : Dig) (embFold : List Fp2 → List Fp2) :
    (shdP_incPub Rp embDigest embFold).tokens = shieldS0.T
    ∧ (shdP_incPub Rp embDigest embFold).tPad = 2 ^ Exec.Slot.R13.shShieldR13.lt
    ∧ (shdP_incPub Rp embDigest embFold).dPad = 2 ^ Exec.Slot.R13.shShieldR13.ld
    ∧ (shdP_outcPub Rp wDigest).d = shieldS0.d
    ∧ (shdP_outcPub Rp wDigest).tPad = 2 ^ Exec.Slot.R13.shShieldR13.lt
    ∧ (shdP_outcPub Rp wDigest).dPad = 2 ^ Exec.Slot.R13.shShieldR13.ld :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

#print axioms shdIC_lists
#print axioms shdIC_counts
#print axioms shdIC_geometry
#print axioms shdIC_cube
#print axioms shdIC_rowsOf
#print axioms shdIC_kinds
#print axioms shdIC_rtBlk
#print axioms shdIC_r13Prm
#print axioms shdIC_sgeom
#print axioms shdIC_stageAxes

/-! ## 2. The comparison with the code's exports -/

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
  else { s with fail := s.fail + 1, msgs := s.msgs.push s!"[{kind}] {msg}" }

def natOf (s : String) : ℕ := s.toNat?.getD 0

def natsOf (s : String) : List ℕ := if s = "-" ∨ s = "" then [] else (s.splitOn ",").map natOf

def wordsOf (ls : Array String) : List (List String) :=
  (ls.toList.filter (fun l => !(l.startsWith "#") && !(l.all Char.isWhitespace))).map
    (fun l => (l.splitOn " ").filter (· ≠ ""))

def recOf (lines : List (List String)) (k : String) : List String := (lines.find? (fun w => w.headD "" = k)).getD []

/-- The word after the first occurrence of the key `k`. -/
def kvOf : List String → String → String
  | a :: b :: rest, k => if a = k then b else kvOf (b :: rest) k
  | _, _ => ""

/-- The value of the first `k=value` word. -/
def eqOf (w : List String) (k : String) : String :=
  match w.find? (fun x => x.startsWith (k ++ "=")) with
  | some x => (x.splitOn "=").getD 1 ""
  | none => ""

/-- The records of one profile of the shape corpus (after its `PROFILE` line, up to the next). -/
def profLines (lines : List (List String)) (name : String) : List (List String) :=
  ((lines.dropWhile (fun w => !(w.headD "" = "PROFILE" && w.getD 1 "" = name))).drop 1).takeWhile
    (fun w => w.headD "" ≠ "PROFILE")

def parseSched (s : String) : List (ℕ × ℕ × ℕ) :=
  (s.splitOn ",").map fun x =>
    match x.splitOn ":" with
    | [a, b, c] => (natOf a, natOf b, natOf c)
    | _ => (0, 0, 0)

/-- The nine domains in `ALL_DOMS` order (the corpus's `logs`, `pads`, `helpers`, `zero_rule` order). -/
def doms : List Exec.Slot.W16R2.Dom := [.T, .Ht, .L, .D, .Q, .Kv, .S, .F, .Tab]

def bnat (b : Bool) : ℕ := if b then 1 else 0

/-- The `H` schedule the shape's helper counts give (`BlockInstCheck.hFromHelpers`). -/
def hFromHelpers (helpers : List ℕ) (nRange : ℕ) : List ℕ :=
  [0, 0, 0, helpers.getD 2 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, helpers.getD 3 0, helpers.getD 4 0, helpers.getD 5 0,
    helpers.getD 6 0 + 1, helpers.getD 7 0 + 1, 3 + nRange, 1, 0, 0]

def ioCnt (k : ℕ) : ℕ := if k = 21 ∨ k = 22 then 1 else 0

def shieldProfile : String := "hashline-zk-mr1/private-block-shieldstral-3b-t128-lowh24-blocks/2"

/-- One layer's shape facts (`cfgShieldR13 Ly`'s, `shdIC_cube`) against the corpus's `SHAPE` line. -/
def checkFacts (s0 : St) (i : ℕ) (Ly : ShieldLayer) (shp : List String) : St := Id.run do
  let mut s := s0
  let sh := (Exec.Block.DefR13.cfgShieldR13 Ly).sh
  let g (k : String) : ℕ := natOf (eqOf shp k)
  let ax := [sh.lt, sh.lh, sh.ldh, sh.ld, sh.lf, sh.lq, sh.lkvw, sh.lkv, bnat sh.padRule, sh.nRange, sh.perRow]
  let axC := [g "lt", g "lh", g "ldh", g "ld", g "lf", g "lq", g "lkvw", g "lkv", g "pad_rule", g "n_range",
    g "per_row"]
  s := s.check "SHAPE-AXES" (ax == axC) s!"layer {i}: lt lh ldh ld lf lq lkvw lkv pad_rule n_range per_row {ax} against {axC}"
  s := s.check "SHAPE-DOMS" (doms.map sh.logs == natsOf (eqOf shp "logs")
      && doms.map (fun d => bnat (sh.pads d)) == natsOf (eqOf shp "pads")
      && doms.map sh.helpers == natsOf (eqOf shp "helpers")
      && doms.map (fun d => bnat (sh.zeroRule d)) == natsOf (eqOf shp "zero_rule"))
    s!"layer {i}: the nine domains' logs, pads, helpers, zero rules"
  return s

/-- One layer's block shape (`shieldShape Ly`) and its cube's paddings (`cfgShieldR13 Ly`) against L49's `SHAPE`
line (`tokens width hidden q_heads head_dim kv_heads t_pad d_pad f_pad h_pad q_pad`). -/
def checkLayer (s0 : St) (i : ℕ) (Ly : ShieldLayer) (v : List ℕ) : St := Id.run do
  let mut s := s0
  let S := shieldShape Ly
  let sh := (Exec.Block.DefR13.cfgShieldR13 Ly).sh
  let lv := [S.T, S.d, S.f, S.H, 2 * S.half, S.G]
  s := s.check "LAYER-SHAPE" (lv == v.take 6) s!"layer {i}: T d f H 2·half G {lv} against {v.take 6}"
  let pv := [2 ^ sh.lt, 2 ^ sh.ld, 2 ^ sh.lf, 2 ^ sh.lh, 2 ^ sh.lq, 2 ^ sh.ldh, 2 ^ sh.lkv]
  let pc := [v.getD 6 0, v.getD 7 0, v.getD 8 0, v.getD 9 0, v.getD 10 0, v.getD 4 0, v.getD 5 0]
  s := s.check "LAYER-CUBE" (pv == pc) s!"layer {i}: 2^lt 2^ld 2^lf 2^lh 2^lq 2^ldh 2^lkv {pv} against {pc}"
  return s

def main (args : List String) : IO UInt32 := do
  let pSh := args.headD "results/zk60_lean_l17_20261107/shape_corpus.txt"
  let pL49 := args.getD 1 "results/zk60_lean_l49_20261110/pub_shield_short.txt"
  let pSeg := args.getD 2 "results/zk60_lean_l17_20261107/segment_corpus.txt"
  let lsh := wordsOf (← IO.FS.lines pSh)
  let l49 := wordsOf (← IO.FS.lines pL49)
  let lseg := wordsOf (← IO.FS.lines pSeg)
  let pl := profLines lsh shieldProfile
  let shp := recOf pl "SHAPE"
  let cn := recOf pl "COUNTS"
  let g (k : String) : ℕ := natOf (kvOf cn k)
  let mut s : St := {}
  -- ======================================================= the corpora are the ones named
  s := s.check "CORPUS" (shp ≠ [] && cn ≠ []) s!"the shape corpus carries {shieldProfile}"
  let hd := recOf l49 "L49S"
  s := s.check "CORPUS" (hd.getD 1 "" == "R13_SHIELD_T128_H24") s!"L49's export is the R13 Shieldstral block ({hd})"
  -- ======================================================= the 26 layers: shape facts, block shape, cube paddings
  let v49 := natsOf (String.intercalate "," ((recOf l49 "SHAPE").drop 1))
  s := s.check "CORPUS" (v49.length == 11) s!"L49's SHAPE line has 11 numbers ({v49})"
  s := s.check "RUN" (shieldExport.length == 26) s!"the run's layers: {shieldExport.length}"
  for (Ly, i) in shieldExport.zipIdx do
    s := checkFacts s i Ly shp
    s := checkLayer s i Ly v49
  s := s.check "HEADER" (natOf (hd.getD 2 "") == Exec.Block.R13.shieldSlots.length)
    s!"slots {hd.getD 2 ""} against {Exec.Block.R13.shieldSlots.length}"
  s := s.check "HEADER" (natOf (hd.getD 3 "") == Exec.Block.R13.logCols) s!"log_cols {hd.getD 3 ""}"
  s := s.check "HEADER" (match shieldExport[natOf (hd.getD 4 "")]? with
      | some L => L.gate == natOf (hd.getD 5 "")
      | none => false) s!"layer {hd.getD 4 ""}'s gate shift {hd.getD 5 ""} is shieldExport's"
  -- ======================================================= the stages' axes (shdIC_stageAxes)
  let sh := Exec.Slot.R13.shShieldR13
  let stg := [shieldS0.T, shieldS0.d, 2 ^ sh.lt, 2 ^ sh.ld]
  let stgC := [v49.getD 0 0, v49.getD 1 0, v49.getD 6 0, v49.getD 7 0]
  s := s.check "STAGE-AXES" (stg == stgC) s!"tokens, d, t_pad, d_pad {stg} against {stgC}"
  -- ======================================================= the block instance's lists (shdIC_lists)
  s := s.check "SCHEDULE" (parseSched ((recOf pl "SCHED").getD 1 "") == Exec.Block.R13.shieldSlots)
    "the slot schedule (n, e, d) of the 23 slots"
  let terms := natsOf ((recOf pl "TERMSDECL").getD 1 "")
  s := s.check "TERMS" (terms == Exec.Block.R13.shieldTerms) s!"the terminal counts {terms}"
  let drawRecs := l49.filter (fun w => w.headD "" = "DRAWS")
  s := s.check "DRAWS" (drawRecs.length == 23) s!"{drawRecs.length} slots' draws in L49's export"
  for w in drawRecs do
    let k := natOf (w.getD 1 "")
    let n := (natsOf (w.getD 2 "")).length / 2
    s := s.check "DRAWS" (n == Exec.Block.R13.shieldDraws k) s!"slot {k}: {n} draws against {Exec.Block.R13.shieldDraws k}"
  -- ======================================================= the block instance's counts (shdIC_counts, shdIC_rtBlk)
  let N := numsR13Shield
  s := s.check "COUNTS" (g "a_rows" == N.rA) s!"a_rows {g "a_rows"} against {N.rA}"
  s := s.check "COUNTS" (g "h_rows" == N.rH) s!"h_rows {g "h_rows"} against {N.rH}"
  s := s.check "COUNTS" (g "m_rows" == 2 * N.S + 4) s!"m_rows {g "m_rows"} against 2·{N.S} + 4"
  s := s.check "COUNTS" (g "a_groups" == N.aGroups) s!"a_groups {g "a_groups"} against {N.aGroups}"
  s := s.check "COUNTS" (g "h_groups" == N.hGroups) s!"h_groups {g "h_groups"} against {N.hGroups}"
  s := s.check "COUNTS" (g "functionals" == N.nFun) s!"functionals {g "functionals"} against {N.nFun}"
  s := s.check "COUNTS" (g "mask_specs" == N.S) s!"mask_specs {g "mask_specs"} against {N.S}"
  s := s.check "COUNTS" (g "range16" == sh.nRange) s!"range16 {g "range16"} against nRange {sh.nRange}"
  -- ======================================================= the opening geometry (shdIC_geometry, shdIC_r13Prm)
  let lc := g "log_cols"
  let ir := g "inv_rate"
  let q := g "q"
  let p := ZK60.Exec.R13.r13Prm
  s := s.check "OPENING" (lc == Exec.Block.R13.logCols && p.logCols == lc) s!"log_cols {lc}"
  s := s.check "OPENING" (ir == Exec.Block.R13.invRate && p.invRate == ir) s!"inv_rate {ir}"
  s := s.check "OPENING" (q == Exec.Block.R13.openedCols && p.nQ == q && p.qPad == q && N.Q == q) s!"q {q}"
  s := s.check "OPENING" (g "e_log_n" == Exec.Block.R13.logCols) s!"e_log_n {g "e_log_n"} (endpointLogN)"
  s := s.check "OPENING" (g "e_inv_rate" == Exec.Block.R13.invRate) s!"e_inv_rate {g "e_inv_rate"}"
  let d := Exec.Block.R13.blkDim
  let dC : List ℕ := [q, 2 ^ lc + q, 2 ^ lc * ir, lc + Nat.log2 ir]
  s := s.check "OPENING" ([d.checks, d.vec, d.encCols, d.path] == dC)
    s!"the block Dim (checks, vec, encCols, path) {[d.checks, d.vec, d.encCols, d.path]} against {dC}"
  s := s.check "OPENING" (N.mI == (q + 3) / 4) s!"index squeezes {N.mI} against ⌈{q}/4⌉"
  -- the wire ceiling: R13-generic (`MAX_WIRE_BYTES_TRAINED`), carried by the R13 rung's segment shape
  let seg := recOf lseg "SEGSHAPE"
  s := s.check "OPENING" (natOf (kvOf seg "ceiling") == Exec.Block.R13.ceiling)
    s!"ceiling {kvOf seg "ceiling"} (the R13 rung's segment shape) against {Exec.Block.R13.ceiling}"
  -- ======================================================= the commitment schedules (`A`, `H`, the endpoints)
  let hh := hFromHelpers (natsOf (eqOf shp "helpers")) (natOf (eqOf shp "n_range"))
  s := s.check "SCHEDULE-H" (hh == hCntR13Shield) s!"the H schedule from the helpers {hh}"
  s := s.check "SCHEDULE-H" (hCntR13Shield.sum == g "h_planes" && hCntR13Shield.sum + 1 == N.nH)
    s!"H planes {g "h_planes"}, H claims {N.nH}"
  let aC := (List.range 23).map (fun k => terms.getD k 0 - hh.getD k 0 - ioCnt k)
  s := s.check "SCHEDULE-A" (aC == aCntR13Shield && aCntR13Shield.sum == N.nA) s!"the A schedule {aC}, A claims {N.nA}"
  -- ======================================================= the endpoint rows in a run (shdIC_rowsOf, shdIC_sgeom)
  let bnd := cbBndRows (v49.getD 6 0) (v49.getD 7 0) (g "e_log_n") 2
  s := s.check "IO-ROWS" (shdP_rowsOf .inp == bnd && shdP_rowsOf .out == bnd && bnd == g "e_rows" + 1)
    s!"inp / out rows {shdP_rowsOf .inp} / {shdP_rowsOf .out} against cbBndRows {bnd} = e_rows {g "e_rows"} + 1"
  for (k, n) in s.kinds do
    IO.println s!"  {k}: {n}"
  for m in s.msgs do
    IO.println s!"FAILED {m}"
  IO.println s!"RunStgShieldInstCheck: {s.ok + s.fail} checks, {s.fail} failed"
  return (if s.fail = 0 then 0 else 1)

end ZK60.ProtocolClassify.ShdInstCheck

def main (args : List String) : IO UInt32 := ZK60.ProtocolClassify.ShdInstCheck.main args
