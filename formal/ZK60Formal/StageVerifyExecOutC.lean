/-
D63 Lean lane L29 (2026-11-07), part 3: **stage OUT-C's schedule, layout and slot definitions, executable**, as
hashline's `stage_out_c.rs` writes them (read 2026-11-07; nothing there is changed):
* `layout` (:71-102): the eight slots (IO-in, SS, TZC hosting SS, PD, LZC hosting PD, DZC, TAB, ZS), sixteen `A`
  planes (`D, Dsq` on `To`, the limb plane on `Lo`, twelve planes on `Do`, the byte histogram on the table domain),
  nine `H` planes (the `Lo` helper, six `Do` helpers, the byte-table helper with sign `−1`, the zero-sum pair),
  `row_log = [lt, lt, endpoint_log_n, lt]`;
* the LogUp challenges `γ, α` and `g_u8 = γ·TAG_U8` (:685-687);
* `define` (:283-429): each slot's tables in the code's push order, with lane L15's executable closures
  (`StageCheckDefs.lean`'s `ioPoly` … `zsPoly`, checked value for value against a real receipt by L15) and public
  tables (`supp`, `liveTab`, `gTab`, `wTab`, `tvTab`).

`define` reads the head's challenges through L9's history (`(β, γ, α) = (0, γ, α)`, lane L15's `bgaOf` for OUT-C), so
stage OUT-C's `BlockParams` is ONE fixed instance (`outcBP`) and its slot phase is L15's `stageSlots` exactly.

Only definitions here.
-/
import ZK60Formal.StageVerifyExecLay

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block
open ZK60.Exec.StageCheck

/-! ## The public data -/

/-- **Stage OUT-C's public data** (`ClassifierProfile`, the margin vector, the statement's PUBLIC verdict). -/
structure OutcPub where
  d : ℕ
  dPad : ℕ
  tPad : ℕ
  lt : ℕ
  limbs : ℕ
  c : ℤ
  ceps : ℤ
  g0 : ℤ
  cn : ℤ
  tn : ℕ
  wDelta : List ℤ
  wDigest : Dig
  verdictRow : ℕ
  verdict : ℕ

/-- **The run's geometry around stage OUT-C** (`boundary_spec(L)`: `B_out`'s row width, rows, sites, its reserved
pair for OUT-C's claim). -/
structure OutcGeo where
  bLogN : ℕ
  bRows : ℕ
  bDataRows : ℕ
  bSites : ℕ
  bOutRow : ℕ

namespace OutcPub

variable (O : OutcPub)

/-- `LIMBS_ISQRT = 3`, `LAM_BASE = 32`, `U8_LEN = 256`, `TO_LOG = 1`. -/
def limbsIsqrt : ℕ := 3
def lamBase : ℕ := 32
def u8Len : ℕ := 256
def toLog : ℕ := 1

/-- `lo_log()`, `do_log()`, `tab_log()`, `d_bits`, `t_bits`, the lift. -/
def llo : ℕ := max (clog2 (2 * 3 * limbsIsqrt)) O.lt
def ldo : ℕ := max (clog2 O.dPad) O.lt
def ltab : ℕ := max (clog2 u8Len) O.lt
def dBits : ℕ := clog2 O.dPad
def tBits : ℕ := clog2 O.tPad
def lift : ℕ := O.ldo - O.dBits
/-- `(t_pad·d_pad).trailing_zeros()`. -/
def bOutLog : ℕ := Nat.log2 (O.tPad * O.dPad)

end OutcPub

/-! ## The layout -/

def ocC_D : ℕ := 0
def ocC_DSQ : ℕ := 1
def ocC_LIMB : ℕ := 2
def ocC_X : ℕ := 3
def ocC_Y : ℕ := 6
def ocC_MULT : ℕ := 15
def ocH_LO : ℕ := 0
def ocH_D0 : ℕ := 1
def ocH_GU8 : ℕ := 7
def ocH_U : ℕ := 8

/-- `A_GROUPS`, `H_GROUPS` (stage_out_c.rs:68-69). -/
def outcAGroups : ℕ := 16
def outcHGroups : ℕ := 5

/-- **Stage OUT-C's schedule** (stage_out_c.rs:75-90). -/
def outcSched (O : OutcPub) (bLogN : ℕ) : Sched where
  label := "stage OUT-C"
  slots :=
    [⟨"OUTC-00 IO-in: x = B_out at the public verdict row P0+n+S-1 (fixed public row bits; T-1 without pad)", O.dBits, 1,
        2, .standalone, 1, 0, 1⟩,
     ⟨"OUTC-01 SS final-norm row sum (private, hosted by TZC)", O.ldo, 1, 4, .priv, 1, 0, 0⟩,
     ⟨"OUTC-02 TZC isqrt (D, Dsq, 9 limb slices; hosts SS)", OutcPub.toLog, 1, 3, .host, 11, 0, 0⟩,
     ⟨"OUTC-03 PD margin sum_i y(i) w_Delta(i) (private, hosted by LZC)", O.dBits, 1, 2, .priv, 1, 0, 0⟩,
     ⟨"OUTC-04 LZC limb lookups (+pad; isqrt and margin limbs) + host term sigma g limb + u0 (sigma b + c)", O.llo, 1, 4,
        .host, 1, 1, 0⟩,
     ⟨"OUTC-05 DZC final-norm quotient + x limbs + helpers (+pad)", O.ldo, 1, 5, .standalone, 13, 6, 0⟩,
     ⟨"OUTC-06 TAB byte-table helper (+pad)", O.ltab, 1, 3, .standalone, 1, 1, 0⟩,
     ⟨"OUTC-07 ZS zero-sum row", O.lt, 1, 2, .standalone, 0, 1, 0⟩]
  hosts := [(2, [1]), (4, [3])]
  rowLog := [O.lt, O.lt, bLogN, O.lt]

/-- **Stage OUT-C's layout**: `a_log = [1, 1, llo, ldo × 12, ltab]`, `h_log = [llo, ldo × 6, ltab, lt]`, signs `1`
except the byte-table helper's `−1`, `H_U = 8`. -/
def outcLay (O : OutcPub) (bLogN : ℕ) : Lay :=
  ⟨O.lt, [OutcPub.toLog, OutcPub.toLog, O.llo] ++ List.replicate 12 O.ldo ++ [O.ltab],
    [O.llo] ++ List.replicate 6 O.ldo ++ [O.ltab, O.lt], [1, 1, 1, 1, 1, 1, 1, -1, 1], ocH_U, outcSched O bLogN⟩

/-! ## The definitions -/

/-- `TAG_U8` (tables_attn.rs:70). -/
def tagU8 : ℕ := 133

/-- Each slot's draws: IO `τ` (`d_bits`); SS none; TZC `τ` (1), `μ` (4), `ν`, `ζ`; PD none; LZC `τ` (`llo`), `μ` (2),
`ν`; DZC `τ` (`ldo`), `μ` (10), `ζ`; TAB `τ` (`ltab`), `μ` (2), `ζ`; ZS none. -/
def outcDraws (O : OutcPub) : ℕ → ℕ
  | 0 => O.dBits
  | 2 => OutcPub.toLog + 4 + 1 + 1
  | 4 => O.llo + 2 + 1
  | 5 => O.ldo + 10 + 1
  | 6 => O.ltab + 2 + 1
  | _ => 0

section Define

variable (O : OutcPub) (G : OutcGeo)

/-- The `k`-th coordinate after `off`, refused by `nonzero` when zero. -/
def nz1 (dr : List Fp2) (off : ℕ) : Except String Fp2 := (nonzeroE ((dr.drop off).take 1)).map (fun z => z.getD 0 Fp2.zero)

/-- OUTC-00 IO-in: `eq·(x − B_out)`; tables `[eq τ, A x at (0…0, ρ), In B_out at (verdict row bits, ρ)]`. -/
def outcDefIO (dr : List Fp2) : Except String SlotDef :=
  let L := outcLay O G.bLogN
  build (do
    let _ ← eqT (dr.take O.dBits) 0
    let _ ← aAtT L 0 ocC_X (fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits)
    let _ ← ioT .inp O.bOutLog (fixedBits O.verdictRow O.tBits ++ rhoC 0 O.dBits) G.bOutRow
    finishT L 0 ioPoly [])

/-- OUTC-01 SS: `supp·x·x`; tables `[supp_d, A x]`. -/
def outcDefSS : Except String SlotDef :=
  let L := outcLay O G.bLogN
  build (do
    let _ ← pubT (supp O.d (2 ^ O.ldo))
    let _ ← aT L 1 ocC_X
    finishT L 1 ssPoly [])

/-- OUTC-02 TZC (hosts SS with `ν`); tables `[eq τ, u0, A D, A Dsq, the nine limb slices]`. -/
def outcDefTZC (dr : List Fp2) : Except String SlotDef := do
  let L := outcLay O G.bLogN
  let tau := dr.take OutcPub.toLog
  let mu ← nonzeroE ((dr.drop 1).take 4)
  let nu ← nz1 dr 5
  let zeta ← nz1 dr 6
  build (do
    let _ ← eqT tau 0
    let _ ← pubT (supp 1 (2 ^ OutcPub.toLog))
    let _ ← aT L 2 ocC_D
    let _ ← aT L 2 ocC_DSQ
    for kk in List.range (3 * OutcPub.limbsIsqrt) do
      let _ ← aSliceT L 2 (L.aOff ocC_LIMB + 2 * kk) OutcPub.toLog (rhoC 0 OutcPub.toLog)
    finishT L 2 (tzcPoly mu nu zeta (kI O.ceps)) [(1, nu)])

/-- OUTC-03 PD: `y·w_Δ` at `y`'s natural `d_pad`; tables `[A y at (0…0, ρ), w_Δ]`. -/
def outcDefPD : Except String SlotDef :=
  let L := outcLay O G.bLogN
  build (do
    let _ ← aAtT L 3 ocC_Y (fixedC (List.replicate O.lift Fp2.zero) ++ rhoC 0 O.dBits)
    let _ ← pubT (wTab O.dPad (O.wDelta.take O.d))
    finishT L 3 pdPoly [])

/-- OUTC-04 LZC (hosts PD with `ν`); tables `[eq τ, live, G, u0, A limb, H h_lo]`. -/
def outcDefLZC (hist : Hist) (dr : List Fp2) : Except String SlotDef := do
  let L := outcLay O G.bLogN
  let tau := dr.take O.llo
  let mu ← nonzeroE ((dr.drop O.llo).take 2)
  let nu ← nz1 dr (O.llo + 2)
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  let loN := 2 ^ O.llo
  build (do
    let _ ← eqT tau 0
    let _ ← pubT (liveTab loN OutcPub.lamBase O.limbs)
    let _ ← pubT (gTab loN OutcPub.lamBase O.limbs O.verdict)
    let _ ← pubT (supp 1 loN)
    let _ ← aT L 4 ocC_LIMB
    let _ ← hT L 4 ocH_LO
    finishT L 4 (lzcPoly mu nu hist.alpha gU8 ((kI O.verdict).add (kI O.c))) [(3, nu)])

/-- OUTC-05 DZC; tables `[eq τ, supp_d, the twelve Do planes, A D at a fixed point, H d0 … d5]`. -/
def outcDefDZC (hist : Hist) (dr : List Fp2) : Except String SlotDef := do
  let L := outcLay O G.bLogN
  let tau := dr.take O.ldo
  let mu ← nonzeroE ((dr.drop O.ldo).take 10)
  let zeta ← nz1 dr (O.ldo + 10)
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  build (do
    let _ ← eqT tau 0
    let _ ← pubT (supp O.d (2 ^ O.ldo))
    for p in List.range' ocC_X (ocC_MULT - ocC_X) do
      let _ ← aT L 5 p
    let _ ← aAtT L 5 ocC_D (fixedC (List.replicate OutcPub.toLog Fp2.zero))
    for j in List.range 6 do
      let _ ← hT L 5 (ocH_D0 + j)
    finishT L 5 (dzcPoly mu zeta hist.alpha gU8 (kI (2 * O.g0 * O.cn)) (kI (2 ^ O.tn)) (kI (2 ^ (O.tn + 1)))) [])

/-- OUTC-06 TAB; tables `[eq τ, supp_256, tv, A mult, H h_gu8]`. -/
def outcDefTAB (hist : Hist) (dr : List Fp2) : Except String SlotDef := do
  let L := outcLay O G.bLogN
  let tau := dr.take O.ltab
  let mu ← nonzeroE ((dr.drop O.ltab).take 2)
  let zeta ← nz1 dr (O.ltab + 2)
  let gU8 := hist.gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
  build (do
    let _ ← eqT tau 0
    let _ ← pubT (supp OutcPub.u8Len (2 ^ O.ltab))
    let _ ← pubT (tvTab (2 ^ O.ltab) gU8)
    let _ ← aT L 6 ocC_MULT
    let _ ← hT L 6 ocH_GU8
    finishT L 6 (tabPoly mu zeta hist.alpha) [])

/-- OUTC-07 ZS: `1·u`; tables `[ones, H u]`. -/
def outcDefZS : Except String SlotDef :=
  let L := outcLay O G.bLogN
  build (do
    let _ ← pubT (List.replicate (2 ^ L.hLog.getD ocH_U 0) Fp2.one)
    let _ ← hT L 7 ocH_U
    finishT L 7 zsPoly [])

/-- **Stage OUT-C's `define`** (stage_out_c.rs:283-429), from the history (`γ`, `α`) and the slot's draws. -/
def outcDefine (s : ℕ) (hist : Hist) (dr : List Fp2) : Except String SlotDef :=
  match s with
  | 0 => outcDefIO O G dr
  | 1 => outcDefSS O G
  | 2 => outcDefTZC O G dr
  | 3 => outcDefPD O G
  | 4 => outcDefLZC O G hist dr
  | 5 => outcDefDZC O G hist dr
  | 6 => outcDefTAB O G hist dr
  | 7 => outcDefZS O G
  | _ => .error "classifier stage OUT-C: unknown slot"

end Define

end ZK60.Exec.StageV
