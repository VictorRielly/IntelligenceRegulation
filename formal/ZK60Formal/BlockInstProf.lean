/-
D63 lane L31 (2026-11-09), part 2: **concrete block profiles** (finding L28-4), `define`'s commitment schedule, and the
reading definitions `csX`, `msX` (L28 §3 items 1, 2, 3, 5, 6).

L28's block theorems hold for every profile `OProf P` meeting four size bounds. Here the profiles are built, with their
bounds proved, for

* the **W16R2 development rung** block that L9's corpus decodes (`profW16Rung`: 23 mask specs, `A` 320 rows and 114
  claims, `H` 202 rows and 47 claims with its LogUp sum claim, 70 index squeezes);
* the **R13 development rung** block of L17's corpus (`profR13Rung`: `A` 437 rows and 148 claims, `H` 248 rows and 55
  claims, 64 index squeezes);
* the **Shieldstral T128 R13** block, the media app's classifier block (`profR13Shield`: `A` 4,577 rows and 146 claims,
  `H` 4,390 rows and 54 claims, 64 index squeezes).

Each is a function of the run's header (its length `hdrLen ≤ 2^19` and squeeze count `hdrSq ≤ 2^63`).

* `shapeLenW`, `shapeSqW`, `shapeLen_eq`, `shapeSq_eq`, `w16r2_rung_counts`, `r13_rung_counts`, `r13_shield_counts`: the
  slot phase's operation and squeeze counts from the draws and the schedule (1,035 / 670, 1,059 / 694, 1,283 / 844);
* `mkProf`, **`profW16Rung`**, **`profR13Rung`**, **`profR13Shield`**: the profiles;
* `DefCm`, `aCntW16Rung` … `hCntR13Shield`, `cnt_sums`, `cnt_terms`, **`hcnt_of_defCm`**: `define`'s commitment schedule
  (how many of each slot's private tables sit in `A` and in `H`), its totals, its agreement with the terminal counts,
  and `hcnt` from it;
* `IsRungW16`, `IsRungR13`, `IsShieldR13`: what makes a `BlockParams` a block verifier of the profile (its schedule,
  group counts, functional count and the opening fields `maskField`, `pcsField` / `pcsFieldR13`);
* `csXof`, `msXof` and the three instances: the semantics that read the extracted matrices and table (`hcsA`, `hcsH`,
  `hms` hold by definition), the endpoint commitments' semantics a parameter of the run.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockInstRead
import ZK60Formal.LinkW16GlueW16T
import ZK60Formal.LinkW16GlueR13

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)

/-! ## The slot phase's counts, from the draws and the schedule -/

/-- `shapeLen` as a function of the draws alone. -/
def shapeLenW (draws : ℕ → ℕ) : ℕ → List (ℕ × ℕ × ℕ) → ℕ
  | _, [] => 0
  | j, s :: ss => draws j + 4 + 2 * (s.1 + s.2.1) + shapeLenW draws (j + 1) ss

/-- `shapeSq` as a function of the draws alone. -/
def shapeSqW (draws : ℕ → ℕ) : ℕ → List (ℕ × ℕ × ℕ) → ℕ
  | _, [] => 0
  | j, s :: ss => draws j + 1 + (s.1 + s.2.1) + shapeSqW draws (j + 1) ss

theorem shapeLen_eq (P : Block.BlockParams) : ∀ (j : ℕ) (ss : List (ℕ × ℕ × ℕ)),
    shapeLen P j ss = shapeLenW P.draws j ss
  | _, [] => rfl
  | j, s :: ss => congrArg (fun x => P.draws j + 4 + 2 * (s.1 + s.2.1) + x) (shapeLen_eq P (j + 1) ss)

theorem shapeSq_eq (P : Block.BlockParams) : ∀ (j : ℕ) (ss : List (ℕ × ℕ × ℕ)),
    shapeSq P j ss = shapeSqW P.draws j ss
  | _, [] => rfl
  | j, s :: ss => congrArg (fun x => P.draws j + 1 + (s.1 + s.2.1) + x) (shapeSq_eq P (j + 1) ss)

/-- The W16R2 rung's slot phase: 1,035 operations, 670 squeezes (351 draws, 23 slots, 296 rounds). -/
theorem w16r2_rung_counts : shapeLenW Block.W16R2.rungDraws 0 Block.W16R2.rungSlots = 1035
    ∧ shapeSqW Block.W16R2.rungDraws 0 Block.W16R2.rungSlots = 670 := by decide

/-- The R13 rung's slot phase: 1,059 operations, 694 squeezes (375 draws). -/
theorem r13_rung_counts : shapeLenW Block.R13.rungDraws 0 Block.R13.rungSlots = 1059
    ∧ shapeSqW Block.R13.rungDraws 0 Block.R13.rungSlots = 694 := by decide

/-- The Shieldstral T128 R13 block's slot phase: 1,283 operations, 844 squeezes (451 draws, 370 rounds). -/
theorem r13_shield_counts : shapeLenW Block.R13.shieldDraws 0 Block.R13.shieldSlots = 1283
    ∧ shapeSqW Block.R13.shieldDraws 0 Block.R13.shieldSlots = 844 := by decide

/-! ## The profiles -/

/-- **A block profile from its numbers**: the slot phase's counts `sl`, `sq`, and the size bounds. -/
def mkProf (P : Block.BlockParams) (tag : MTag) (S rA rH nA nH hdrLen hdrSq mI sl sq : ℕ)
    (esl : shapeLen P 0 P.geom.slots = sl) (esq : shapeSq P 0 P.geom.slots = sq)
    (hb : 0 < nA + rA ∧ 0 < nH + rH ∧ 0 < mI ∧ nA + rA ≤ 2 ^ 61 ∧ nH + rH ≤ 2 ^ 61 ∧ mI ≤ 2 ^ 20
      ∧ 2 * S + 2 ≤ 2 ^ 20)
    (blen : hdrLen + 10 + sl + (2 * S + 69) + (nA + rA + P.geom.aGroups + 1 + mI)
      + (nH + rH + P.geom.hGroups + 1 + mI) ≤ 2 ^ 20)
    (bsq : hdrSq + 3 + sq + (2 * S + 67) + (nA + rA) + mI + (nH + rH) + mI < 2 ^ 64) : OProf P where
  tag := tag
  S := S
  rA := rA
  rH := rH
  nA := nA
  nH := nH
  hdrLen := hdrLen
  hdrSq := hdrSq
  mI := mI
  hwA := hb.1
  hwH := hb.2.1
  hmI := hb.2.2.1
  hwA' := hb.2.2.2.1
  hwH' := hb.2.2.2.2.1
  hmI' := hb.2.2.2.2.2.1
  hS := hb.2.2.2.2.2.2
  hlen := by
    rw [esl]
    exact blen
  hsq := by
    rw [esq]
    exact bsq

/-- **The W16R2 development rung's profile** (the block L9's corpus decodes): 23 mask specs; `A` 320 rows, 114 claims
in 36 groups; `H` 202 rows, 47 claims (its LogUp sum claim among them) in 9 groups; 70 index squeezes per regular
opening. The whole run is `hdrLen + 2,030` chain items and `hdrSq + 1,609` squeezes. -/
def profW16Rung (P : Block.BlockParams) (hdr : P.draws = Block.W16R2.rungDraws)
    (hsl : P.geom.slots = Block.W16R2.rungSlots) (hag : P.geom.aGroups = 36) (hhg : P.geom.hGroups = 9) (tag : MTag)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63) : OProf P :=
  mkProf P tag 23 320 202 114 47 hdrLen hdrSq 70 1035 670
    (by rw [shapeLen_eq, hdr, hsl]; exact w16r2_rung_counts.1)
    (by rw [shapeSq_eq, hdr, hsl]; exact w16r2_rung_counts.2) (by norm_num)
    (by rw [hag, hhg]; omega) (by omega)

/-- **The R13 development rung's profile** (the block L17's corpus decodes): `A` 437 rows, 148 claims; `H` 248 rows,
55 claims; 64 index squeezes. The whole run is `hdrLen + 2,247` chain items and `hdrSq + 1,826` squeezes. -/
def profR13Rung (P : Block.BlockParams) (hdr : P.draws = Block.R13.rungDraws)
    (hsl : P.geom.slots = Block.R13.rungSlots) (hag : P.geom.aGroups = 36) (hhg : P.geom.hGroups = 9) (tag : MTag)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63) : OProf P :=
  mkProf P tag 23 437 248 148 55 hdrLen hdrSq 64 1059 694
    (by rw [shapeLen_eq, hdr, hsl]; exact r13_rung_counts.1)
    (by rw [shapeSq_eq, hdr, hsl]; exact r13_rung_counts.2) (by norm_num)
    (by rw [hag, hhg]; omega) (by omega)

/-- **The Shieldstral T128 R13 block's profile** (the media app's classifier block, LowH24): `A` 4,577 rows, 146
claims; `H` 4,390 rows, 54 claims; 64 index squeezes. The whole run is `hdrLen + 10,750` chain items and
`hdrSq + 10,255` squeezes. -/
def profR13Shield (P : Block.BlockParams) (hdr : P.draws = Block.R13.shieldDraws)
    (hsl : P.geom.slots = Block.R13.shieldSlots) (hag : P.geom.aGroups = 36) (hhg : P.geom.hGroups = 9) (tag : MTag)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63) : OProf P :=
  mkProf P tag 23 4577 4390 146 54 hdrLen hdrSq 64 1283 844
    (by rw [shapeLen_eq, hdr, hsl]; exact r13_shield_counts.1)
    (by rw [shapeSq_eq, hdr, hsl]; exact r13_shield_counts.2) (by norm_num)
    (by rw [hag, hhg]; omega) (by omega)

/-- A profile's numbers, as a receipt's shape record shows them (the agreement check `BlockInstCheck.lean` compares
them with the corpora): mask specs, `A` / `H` rows and claim counts, index squeezes, opened columns, groups, functionals. -/
structure ProfNums where
  S : ℕ
  rA : ℕ
  rH : ℕ
  nA : ℕ
  nH : ℕ
  mI : ℕ
  Q : ℕ
  aGroups : ℕ
  hGroups : ℕ
  nFun : ℕ

def numsW16Rung : ProfNums := ⟨23, 320, 202, 114, 47, 70, 280, 36, 9, 34⟩
def numsR13Rung : ProfNums := ⟨23, 437, 248, 148, 55, 64, 256, 36, 9, 34⟩
def numsR13Shield : ProfNums := ⟨23, 4577, 4390, 146, 54, 64, 256, 36, 9, 34⟩

/-- The profiles hold exactly these numbers. -/
theorem prof_nums (P : Block.BlockParams) (tag : MTag) (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (hq : hdrSq ≤ 2 ^ 63) (hag : P.geom.aGroups = 36) (hhg : P.geom.hGroups = 9) :
    (∀ (hdr : P.draws = Block.W16R2.rungDraws) (hsl : P.geom.slots = Block.W16R2.rungSlots),
      ((profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).S, (profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rA,
        (profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rH, (profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nA,
        (profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nH, (profW16Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).mI)
        = (numsW16Rung.S, numsW16Rung.rA, numsW16Rung.rH, numsW16Rung.nA, numsW16Rung.nH, numsW16Rung.mI))
    ∧ (∀ (hdr : P.draws = Block.R13.rungDraws) (hsl : P.geom.slots = Block.R13.rungSlots),
      ((profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).S, (profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rA,
        (profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rH, (profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nA,
        (profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nH, (profR13Rung P hdr hsl hag hhg tag hdrLen hdrSq hh hq).mI)
        = (numsR13Rung.S, numsR13Rung.rA, numsR13Rung.rH, numsR13Rung.nA, numsR13Rung.nH, numsR13Rung.mI))
    ∧ (∀ (hdr : P.draws = Block.R13.shieldDraws) (hsl : P.geom.slots = Block.R13.shieldSlots),
      ((profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).S,
        (profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rA,
        (profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).rH,
        (profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nA,
        (profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).nH,
        (profR13Shield P hdr hsl hag hhg tag hdrLen hdrSq hh hq).mI)
        = (numsR13Shield.S, numsR13Shield.rA, numsR13Shield.rH, numsR13Shield.nA, numsR13Shield.nH,
          numsR13Shield.mI)) :=
  ⟨fun _ _ => rfl, fun _ _ => rfl, fun _ _ => rfl⟩

/-! ## `define`'s commitment schedule and the claims' counts -/

/-- **`define`'s commitment schedule**: every definition of slot `k` has `aC[k]` private tables in `A` and `hC[k]` in
`H` (the rest sit in the endpoint commitments). A property of the profile's `define`. -/
def DefCm (P : Block.BlockParams) (aC hC : List ℕ) : Prop :=
  ∀ (k : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : Block.SlotDef), P.define k hist dr = .ok df →
    Block.cmCount .a df.tabs = aC.getD k 0 ∧ Block.cmCount .h df.tabs = hC.getD k 0

/-- The W16R2 rung's `A` tables per slot. -/
def aCntW16Rung : List ℕ := [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 21, 7, 7, 12, 9, 17, 0, 1, 1]

/-- The W16R2 rung's `H` tables per slot (the helper planes of `Dom::L`, `D`, `Q`, `Kv`, `S`, `F`, `Tab`, and `SC_ZS`'s
row). -/
def hCntW16Rung : List ℕ := [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 3, 3, 6, 5, 17, 1, 0, 0]

/-- The R13 rung's `A` tables per slot. -/
def aCntR13Rung : List ℕ := [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 41, 15, 15, 17, 16, 3, 0, 1, 1]

/-- The R13 rung's `H` tables per slot. -/
def hCntR13Rung : List ℕ := [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 7, 7, 10, 8, 3, 1, 0, 0]

/-- The Shieldstral T128 R13 block's `A` tables per slot. -/
def aCntR13Shield : List ℕ := [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 41, 15, 15, 15, 16, 3, 0, 1, 1]

/-- The Shieldstral T128 R13 block's `H` tables per slot. -/
def hCntR13Shield : List ℕ := [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 17, 7, 7, 9, 8, 3, 1, 0, 0]

/-- The schedules' totals: `A` 114 / 148 / 146 claims, `H` 46 / 54 / 53 before its LogUp sum claim. -/
theorem cnt_sums :
    Block.sumFrom (fun k => aCntW16Rung.getD k 0) 0 23 = 114
    ∧ Block.sumFrom (fun k => hCntW16Rung.getD k 0) 0 23 + 1 = 47
    ∧ Block.sumFrom (fun k => aCntR13Rung.getD k 0) 0 23 = 148
    ∧ Block.sumFrom (fun k => hCntR13Rung.getD k 0) 0 23 + 1 = 55
    ∧ Block.sumFrom (fun k => aCntR13Shield.getD k 0) 0 23 = 146
    ∧ Block.sumFrom (fun k => hCntR13Shield.getD k 0) 0 23 + 1 = 54 := by decide

/-- **The schedules account for every terminal**: at each slot the `A` and `H` tables, with one endpoint table at
`SC_IO_IN` and at `SC_IO_OUT`, are the slot's declared terminal count. -/
theorem cnt_terms :
    (∀ k, k < 23 → aCntW16Rung.getD k 0 + hCntW16Rung.getD k 0 + (if k = 21 ∨ k = 22 then 1 else 0)
      = Block.W16R2.rungTerms.getD k 0)
    ∧ (∀ k, k < 23 → aCntR13Rung.getD k 0 + hCntR13Rung.getD k 0 + (if k = 21 ∨ k = 22 then 1 else 0)
      = Block.R13.rungTerms.getD k 0)
    ∧ (∀ k, k < 23 → aCntR13Shield.getD k 0 + hCntR13Shield.getD k 0 + (if k = 21 ∨ k = 22 then 1 else 0)
      = Block.R13.shieldTerms.getD k 0) := by decide

/-- **`hcnt` from `define`'s commitment schedule** (L28-3), at a profile of `n` slots with the schedule's totals. -/
theorem hcnt_of_defCm {L : ℕ} (P : Block.BlockParams) (hdrLen : ℕ) (key : Option Dig) (domain : List UInt8)
    (aC hC : List ℕ) (nA nH n : ℕ) (hn : P.geom.slots.length = n)
    (hA : Block.sumFrom (fun k => aC.getD k 0) 0 n = nA) (hH : Block.sumFrom (fun k => hC.getD k 0) 0 n + 1 = nH)
    (hdc : DefCm P aC hC) (G : QB L → Dig) (o : List Op × Block.Core) (bga : Fp2 × Fp2 × Fp2)
    (rs : List Block.SlotRec) (acc : Block.Acc) (h : Block.SlotsAcc key domain P hdrLen G o bga rs acc) :
    acc.claims.a.length = nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = nH := by
  have h1 := Block.hcnt_of_define P hdrLen key domain (fun k => aC.getD k 0) (fun k => hC.getD k 0)
    (fun k hist dr df hd => (hdc k hist dr df hd).1) (fun k hist dr df hd => (hdc k hist dr df hd).2) G o bga rs acc h
  rw [hn, hA, hH] at h1
  exact h1

/-! ## What makes a `BlockParams` a block verifier of the profile -/

/-- **A W16R2 rung block verifier**: the rung's draws, schedule and terminal counts, 36 `A` and 9 `H` groups, 34 `M`
functionals, and L10's opening fields with 23 mask specs and the rows `A` 320, `H` 202. -/
structure IsRungW16 (P : Block.BlockParams) (tag : MTag) (rowsOf : Block.Cm → ℕ) : Prop where
  hdr : P.draws = Block.W16R2.rungDraws
  hsl : P.geom.slots = Block.W16R2.rungSlots
  htm : P.geom.terms = Block.W16R2.rungTerms
  hag : P.geom.aGroups = 36
  hhg : P.geom.hGroups = 9
  hnf : P.nFunctionals = 34
  hPm : P.maskVerify = maskField tag 23
  hPp : P.pcsVerify = pcsField tag rowsOf
  hrA : rowsOf .a = 320
  hrH : rowsOf .h = 202

/-- **An R13 rung block verifier**: the R13 rung's draws, schedule and terminal counts, L17's opening field, the rows
`A` 437, `H` 248. -/
structure IsRungR13 (P : Block.BlockParams) (tag : MTag) (rowsOf : Block.Cm → ℕ) : Prop where
  hdr : P.draws = Block.R13.rungDraws
  hsl : P.geom.slots = Block.R13.rungSlots
  htm : P.geom.terms = Block.R13.rungTerms
  hag : P.geom.aGroups = 36
  hhg : P.geom.hGroups = 9
  hnf : P.nFunctionals = 34
  hPm : P.maskVerify = maskField tag 23
  hPp : P.pcsVerify = ZK60.Exec.R13.pcsFieldR13 tag rowsOf
  hrA : rowsOf .a = 437
  hrH : rowsOf .h = 248

/-- **A Shieldstral T128 R13 block verifier** (the media app's classifier block): its draws, schedule and terminal
counts, L17's opening field, the rows `A` 4,577, `H` 4,390. -/
structure IsShieldR13 (P : Block.BlockParams) (tag : MTag) (rowsOf : Block.Cm → ℕ) : Prop where
  hdr : P.draws = Block.R13.shieldDraws
  hsl : P.geom.slots = Block.R13.shieldSlots
  htm : P.geom.terms = Block.R13.shieldTerms
  hag : P.geom.aGroups = 36
  hhg : P.geom.hGroups = 9
  hnf : P.nFunctionals = 34
  hPm : P.maskVerify = maskField tag 23
  hPp : P.pcsVerify = ZK60.Exec.R13.pcsFieldR13 tag rowsOf
  hrA : rowsOf .a = 4577
  hrH : rowsOf .h = 4390

/-! ## The reading definitions -/

theorem le64_of_le20 {L : ℕ} (h : 2 ^ 20 ≤ L) : 64 ≤ L := by omega

section Reading

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (L : ℕ) (h64 : 64 ≤ L)

/-- **The claims' semantics on the extracted data** at an opening geometry `(h, Q, e)`: a claim on `A` (on `H`) is its
functional on the rows decoded from the matrix extracted for the `A` (`H`) root; a claim on an endpoint commitment is
the run's (`csE`). -/
noncomputable def csXof (h Q e rA rH : ℕ) (csE : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K) :
    Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K :=
  fun cu rt cm z =>
    match cm with
    | .a => claimSem U rA 14 Q (decodeRows (encG (K := K) h Q) e (UxC tag L h64 h rA (N := 2 ^ h) cu.1 rt.1)) z
    | .h => claimSem U rH 14 Q (decodeRows (encG (K := K) h Q) e (UxC tag L h64 h rH (N := 2 ^ h) cu.2.2 rt.2.2)) z
    | _ => csE cu rt cm z

/-- **`M`'s semantics on the extracted mask table** (`S` mask specs). -/
noncomputable def msXof (S : ℕ) : Block.Cuts3 L → Block.RootsO → List (ℕ × List Fp2) → K :=
  fun cu rt ts => msOfTab U S (colsC tag L h64 cu.2.1 rt.2.1) ts

end Reading

section Instances

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (hL20 : 2 ^ 20 ≤ L)

/-- The claims' semantics at the W16R2 rung: `(h, Q, e) = (15, 280, 8052)`, rows 320 / 202. -/
noncomputable abbrev csRungW16 (csE : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K) :
    Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K :=
  csXof U tag L (le64_of_le20 hL20) 15 280 8052 320 202 csE

/-- The claims' semantics at the R13 rung: `(h, Q, e) = (16, 256, 24448)`, rows 437 / 248. -/
noncomputable abbrev csRungR13 (csE : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K) :
    Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K :=
  csXof U tag L (le64_of_le20 hL20) 16 256 24448 437 248 csE

/-- The claims' semantics at the Shieldstral T128 R13 block: rows 4,577 / 4,390. -/
noncomputable abbrev csShieldR13 (csE : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K) :
    Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K :=
  csXof U tag L (le64_of_le20 hL20) 16 256 24448 4577 4390 csE

/-- `M`'s semantics at the three profiles (23 mask specs). -/
noncomputable abbrev msRung : Block.Cuts3 L → Block.RootsO → List (ℕ × List Fp2) → K :=
  msXof U tag L (le64_of_le20 hL20) 23

end Instances

end ZK60.Exec.Link
