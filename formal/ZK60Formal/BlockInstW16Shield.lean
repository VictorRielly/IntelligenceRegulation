/-
D63 W16R2 Shieldstral port, Item (5a) (`BlockInstW16Shield.lean`):
**one installed W16R2 Shieldstral-1.0-3B T128 (`export_u1`, `W16R2_SHIELD_T128_H24`) block's
knowledge statement at LogUp's bound `e ≤ 2^26`, through the relation algebra and lookup cover bridge.**

This file mirrors `BlockInstProf.lean` + `BlockInstShield.lean` + `LinkW16GlueW16T.lean` +
`BlockAlgLk26.lean` + `BlockAlgLkFinal.lean` at the W16R2 Shieldstral (`export_u1`) geometry:
* `W16R2` opening geometry `(h, Q, e) = (15, 280, 8052)`, `mI = 70`, opening exponents
  `M ≤ 2^-106`, `opA ≤ 2^-111`, `opB ≤ 2^-113`;
* `shShieldW16U1`: `shShield` with `nRange := 13` and `helpers := L:1, D:10, Q:3, Kv:3, S:4, F:4`
  (`wrho = 16`, 1-limb `SR`/`SG`, 9 range families `[3,4,5,6,7,12,13,15,16]`);
* `W16R2.shieldSlots` (`= R13.shieldSlots`, `blockND = 1159`), `W16R2.shieldTerms`,
  `W16R2.shieldDrawList` (426 draws; `shapeLenW = 1258`, `shapeSqW = 819`,
  `blockLen = hdrLen + 1267`, `defLen = hdrLen + 1268`);
* `Link.profW16Shield` (`A`: 2,504 rows, 111 claims in 36 groups; `H`: 2,606 rows, 45 claims in
  9 groups; 23 mask specs, 34 functionals, 70 index squeezes), `Link.IsShieldW16`,
  `Link.aCntW16Shield`, `Link.hCntW16Shield`, `Link.csShieldW16`;
* `shield_budget_w16_26`: `54,255,600 ≤ 2^26 = 67,108,864` (12,853,264 headroom);
* **`block_knowledge_open_w16r2_shieldN26`**, **`block_knowledge_final_w16r2_shield26`**,
  **`block_knowledge_alg_w16r2_shield_lk26`**: for EVERY `q`,
  `Pr[BlockAcc ∧ sqN header = hdrSq ∧ ¬BlockSat] ≤ εsTarget q + εend`, at `he ≤ 2^26`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockAlgLkFinal

set_option autoImplicit false

namespace ZK60.Exec.Block.W16R2

/-- **The W16R2 Shieldstral T128 (`export_u1`) slot schedule** (`Shape::slots`, identical to
`R13.shieldSlots`: 23 slots, 370 sumcheck rounds, degrees in `[2, 5]`). -/
def shieldSlots : List (ℕ × ℕ × ℕ) := ZK60.Exec.Block.R13.shieldSlots

/-- Its terminal counts per slot (`slot_terms` at `wrho = 16`, `nRange = 13`):
`aCnt[k] + hCnt[k] + [k ∈ {21, 22}]`. -/
def shieldTerms : List ℕ :=
  [1, 1, 22, 3, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 31, 10, 10, 15, 14, 32, 1, 2, 2]

/-- Its challenge draws per slot (`Slot.W16R2.drawLen shShieldW16U1`: 426 draws in all). -/
def shieldDrawList : List ℕ :=
  [7, 7, 15, 16, 13, 19, 10, 10, 19, 19, 19, 21, 14, 19, 39, 25, 23, 30, 31, 32, 0, 19, 19]

def shieldDraws (k : ℕ) : ℕ := shieldDrawList.getD k 0

/-- **The W16R2 Shieldstral T128 block's item count**: `ℓ = hdrLen + 1267` (10 root operations,
426 draws, 69 slot prefixes, 22 `pb-term` absorbs, 370 rounds of two items). -/
theorem shield_len (h : ℕ) : blockLen shieldDraws shieldSlots h = h + 1267 := by
  simp [blockLen, shieldSlots, ZK60.Exec.Block.R13.shieldSlots, shieldDraws, shieldDrawList, List.range_succ]

/-- Per-slot degree and hash-input bounds at the W16R2 Shieldstral T128 schedule. -/
theorem shield_slot_facts : ∀ k, k < 23 → 1 ≤ (shieldSlots.getD k (0, 0, 0)).2.2
    ∧ (shieldSlots.getD k (0, 0, 0)).2.2 ≤ 5
    ∧ 56 + 16 * ((shieldSlots.getD k (0, 0, 0)).2.2 + 1) ≤ 2 ^ 20
    ∧ 55 + 16 * shieldTerms.getD k 0 ≤ 2 ^ 20 := by
  decide

end ZK60.Exec.Block.W16R2

namespace ZK60.Exec.Slot.W16R2

/-- **The installed W16R2 Shieldstral T128 (`export_u1`) shape facts**: `shShield` with `13` range
sub-planes (`widths = [3,4,5,6,7,12,13,15,16]`) and helper counts `L:1, D:10, Q:3, Kv:3, S:4, F:4`
(`wrho = 16`, 7 lookups on `Dom::S` → 4 helpers). -/
def shShieldW16U1 : ShapeW := { shShield with
  nRange := 13
  helpers := fun d => match d with
    | .L => 1 | .D => 10 | .Q => 3 | .Kv => 3 | .S => 4 | .F => 4
    | _ => 0 }

/-- `drawLen shShieldW16U1` agrees with `W16R2.shieldDrawList` on all 23 slots. -/
theorem shieldDraws_eq_w16 :
    (List.range nSlots).map (drawLen shShieldW16U1) = ZK60.Exec.Block.W16R2.shieldDrawList := by
  decide

/-- `sched shShieldW16U1` agrees with `W16R2.shieldSlots` on all 23 slots. -/
theorem shieldSched_eq_w16 :
    (List.range nSlots).map (sched shShieldW16U1) = ZK60.Exec.Block.W16R2.shieldSlots := by
  decide

/-- Slot by slot: `W16R2.shieldDraws k = drawLen shShieldW16U1 k` for every `k < 23`. -/
theorem shieldDraws_drawLen (k : ℕ) (hk : k < nSlots) :
    ZK60.Exec.Block.W16R2.shieldDraws k = drawLen shShieldW16U1 k := by
  have h := congrArg (fun l => l.getD k 0) shieldDraws_eq_w16
  rw [ZK60.Exec.Block.W16R2.shieldDraws, ← h, List.getD_eq_getElem?_getD, List.getElem?_map,
    List.getElem?_range hk]
  rfl

end ZK60.Exec.Slot.W16R2

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)

/-- The W16R2 Shieldstral T128 (`export_u1`) slot phase: 1,258 operations, 819 squeezes (426 draws,
370 rounds). -/
theorem w16r2_shield_counts :
    shapeLenW Block.W16R2.shieldDraws 0 Block.W16R2.shieldSlots = 1258
    ∧ shapeSqW Block.W16R2.shieldDraws 0 Block.W16R2.shieldSlots = 819 := by
  decide

/-- **The W16R2 Shieldstral T128 (`export_u1`) block's profile**: 23 mask specs; `A` 2,504 rows
(2,280 data + 222 site + 2 prox), 111 claims in 36 groups; `H` 2,606 rows (2,516 data + 88 site
+ 2 prox), 45 claims (44 sites + 1 LogUp sum claim) in 9 groups; 70 index squeezes per regular
opening. The whole run is `hdrLen + 6,836` chain items and `hdrSq + 6,341` squeezes. -/
def profW16Shield (P : Block.BlockParams) (hdr : P.draws = Block.W16R2.shieldDraws)
    (hsl : P.geom.slots = Block.W16R2.shieldSlots) (hag : P.geom.aGroups = 36) (hhg : P.geom.hGroups = 9)
    (tag : MTag) (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63) : OProf P :=
  mkProf P tag 23 2504 2606 111 45 hdrLen hdrSq 70 1258 819
    (by rw [shapeLen_eq, hdr, hsl]; exact w16r2_shield_counts.1)
    (by rw [shapeSq_eq, hdr, hsl]; exact w16r2_shield_counts.2) (by norm_num)
    (by rw [hag, hhg]; omega) (by omega)

/-- The W16R2 Shieldstral T128 (`export_u1`) profile numbers. -/
def numsW16Shield : ProfNums := ⟨23, 2504, 2606, 111, 45, 70, 280, 36, 9, 34⟩

/-- The W16R2 Shieldstral T128 (`export_u1`) `A` tables per slot (sum = 111). -/
def aCntW16Shield : List ℕ :=
  [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 21, 7, 7, 10, 9, 16, 0, 1, 1]

/-- The W16R2 Shieldstral T128 (`export_u1`) `H` tables per slot (sum = 44; +1 LogUp sum claim = 45). -/
def hCntW16Shield : List ℕ :=
  [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 3, 3, 5, 5, 16, 1, 0, 0]

theorem cnt_sums_w16_shield :
    Block.sumFrom (fun k => aCntW16Shield.getD k 0) 0 23 = 111
    ∧ Block.sumFrom (fun k => hCntW16Shield.getD k 0) 0 23 + 1 = 45 := by
  decide

theorem cnt_terms_w16_shield :
    ∀ k, k < 23 → aCntW16Shield.getD k 0 + hCntW16Shield.getD k 0 + (if k = 21 ∨ k = 22 then 1 else 0)
      = Block.W16R2.shieldTerms.getD k 0 := by
  decide

/-- **A W16R2 Shieldstral T128 (`export_u1`) block verifier**: its draws, schedule and terminal
counts, 36 `A` and 9 `H` groups, 34 `M` functionals, and W16R2 opening fields (`maskField`,
`pcsField`) with 23 mask specs and rows `A` 2,504, `H` 2,606. -/
structure IsShieldW16 (P : Block.BlockParams) (tag : MTag) (rowsOf : Block.Cm → ℕ) : Prop where
  hdr : P.draws = Block.W16R2.shieldDraws
  hsl : P.geom.slots = Block.W16R2.shieldSlots
  htm : P.geom.terms = Block.W16R2.shieldTerms
  hag : P.geom.aGroups = 36
  hhg : P.geom.hGroups = 9
  hnf : P.nFunctionals = 34
  hPm : P.maskVerify = maskField tag 23
  hPp : P.pcsVerify = pcsField tag rowsOf
  hrA : rowsOf .a = 2504
  hrH : rowsOf .h = 2606

/-- The claims' semantics at the W16R2 Shieldstral T128 (`export_u1`) block:
`(h, Q, e) = (15, 280, 8052)`, rows `2504 / 2606`. -/
noncomputable abbrev csShieldW16 {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ}
    (hL20 : 2 ^ 20 ≤ L) (csE : Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K) :
    Block.Cuts3 L → Block.RootsO → Block.Cm → Block.ZClaim → K :=
  csXof U tag L (le64_of_le20 hL20) 15 280 8052 2504 2606 csE

end ZK60.Exec.Link

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The W16R2 Shieldstral T128 (`export_u1`) schedule's numbers and budget -/

theorem shield_defLen_w16 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws)
    (hsl : P.geom.slots = W16R2.shieldSlots) (h : ℕ) : defLen P h = h + 1268 := by
  have e : defOffW W16R2.shieldDraws W16R2.shieldSlots 0 W16R2.shieldSlots.length = 1258 := by decide
  rw [defLen, defOff_eq, hdr, hsl, e]

theorem shield_draws_sum_w16 : ∑ k ∈ Finset.range 23, W16R2.shieldDraws k = 426 := by decide

theorem shield_defND_le_w16 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (i : ℕ) (hi : i < 4)
    (dg : ℕ → ℕ) (dd : ℕ) (hdg : ∀ k ∈ w16r2RelKs i, dg k ≤ dd) :
    defND P (w16r2RelKs i) dg ≤ dd * 426 := by
  have h := defND_le P _ dg dd 23 hdg (w16r2RelKs_facts i hi).1 (w16r2RelKs_facts i hi).2
  rw [hdr, shield_draws_sum_w16] at h
  exact h

theorem shield_blockND_w16 : blockND W16R2.shieldSlots = 1159 := by decide

theorem w16r2_shield_mask_facts : ∀ k, k < 23 → 1 ≤ (W16R2.shieldSlots.getD k (0, 0, 0)).2.2
    ∧ 0 < (W16R2.shieldSlots.getD k (0, 0, 0)).1 + (W16R2.shieldSlots.getD k (0, 0, 0)).2.1
    ∧ ((W16R2.shieldSlots.getD k (0, 0, 0)).1 + (W16R2.shieldSlots.getD k (0, 0, 0)).2.1)
        * (W16R2.shieldSlots.getD k (0, 0, 0)).2.2 + 2 ≤ 512 := by
  decide

theorem w16r2_shield_slot64 : ∀ k, k < 23 →
    (W16R2.shieldSlots.getD k (0, 0, 0)).1 + (W16R2.shieldSlots.getD k (0, 0, 0)).2.1 < 64 := by
  decide

/-- **The W16R2 Shieldstral T128 (`export_u1`) block's budget at LogUp's bound `e ≤ 2^26`**
(opening exponents `M` `2^-106`, `opA` `2^-111`, `opB` `2^-113`, four relation layers, one helper layer):
`54,255,600 ≤ 2^26 = 67,108,864`. -/
theorem shield_budget_w16_26 :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14) + (50331700 + 2 ^ 14 + 2 ^ 14))
      ≤ 2 ^ 26 := by
  norm_num

theorem shield_budget_w16_26_val :
    3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5 + 1159
        + 4 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14) + (1 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14) + (50331700 + 2 ^ 14 + 2 ^ 14))
      = 54255600 ∧ 54255600 ≤ 2 ^ 26 := by
  constructor <;> norm_num

section ShieldW16

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

/-- **One W16R2 Shieldstral T128 (`export_u1`) block's knowledge statement with openings discharged,
for `SlotEvalN`, at LogUp's bound `e ≤ 2^26`** (W16R2 twin of `block_knowledge_open_r13_shieldN26`). -/
theorem block_knowledge_open_w16r2_shieldN26 [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (htm : P.geom.terms = W16R2.shieldTerms) (pr : Link.OProf P) (hh : pr.hdrLen ≤ 2 ^ 19)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hEval : ∀ cu rt, SlotEvalN U P (csX cu rt) (msX cu rt) (F cu rt))
    (hdeg : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (F cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (hm70 : pr.mI = 70) (rowsOf : Cm → ℕ) (hPm : P.maskVerify = maskField pr.tag pr.S)
    (hPp : P.pcsVerify = pcsField pr.tag rowsOf) (hrA : rowsOf .a = pr.rA) (hrH : rowsOf .h = pr.rH)
    (hrows : 8 * pr.rA ≤ L ∧ 8 * pr.rH ≤ L ∧ 8 * (2 * pr.S + 4) ≤ L)
    (hk : 0 < P.nFunctionals) (hkF : P.nFunctionals ≤ 2 ^ 20)
    (hcnt : ∀ G bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      acc.claims.a.length = pr.nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = pr.nH)
    (accRd : List (TItem × Dig) → Acc)
    (hRd : ∀ G bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc →
      Link.sqN (A.run G).1 = pr.hdrSq →
        (accRd (Link.slotTrace P key domain G (A.run G))).fs ++ (accRd (Link.slotTrace P key domain G (A.run G))).hostFs
          = acc.fs ++ acc.hostFs
        ∧ (accRd (Link.slotTrace P key domain G (A.run G))).claims.a = acc.claims.a
        ∧ (accRd (Link.slotTrace P key domain G (A.run G))).claims.h = acc.claims.h)
    (hcsA : ∀ cu rt z, csX cu rt .a z = Link.claimSem U pr.rA 14 280
      (decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rA (N := 2 ^ 15) cu.1 rt.1)) z)
    (hcsH : ∀ cu rt z, csX cu rt .h z = Link.claimSem U pr.rH 14 280
      (decodeRows (Link.encG (K := K) 15 280) 8052 (Link.UxC pr.tag L (by omega) 15 pr.rH (N := 2 ^ 15) cu.2.2 rt.2.2)) z)
    (hms : ∀ cu rt ts, msX cu rt ts = Link.msOfTab U pr.S (Link.colsC pr.tag L (by omega) cu.2.1 rt.2.1) ts)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = pr.hdrSq ∧ ¬ EndTrue U (csX (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P pr.hdrLen F csX msX A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P pr.hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = pr.hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend := by
  have hlen : P.geom.slots.length = 23 := by rw [hsl]; rfl
  have hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ 5
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L := by
    intro k hk
    rw [hlen] at hk
    obtain ⟨h1, h2, h3, h4⟩ := W16R2.shield_slot_facts k hk
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  have hgt : P.geom.slots.length = P.geom.terms.length := by rw [hsl, htm]; rfl
  have hℓs : blockLen P.draws P.geom.slots pr.hdrLen ≤ 2 ^ 20 := by
    rw [hdr, hsl, W16R2.shield_len]
    omega
  have hℓd : defLen P pr.hdrLen ≤ 2 ^ 20 := by
    rw [shield_defLen_w16 P hdr hsl]
    omega
  have hℓk : pr.hdrLen + 10 ≤ 2 ^ 20 := by omega
  have hND : blockND P.geom.slots = 1159 := by rw [hsl]; exact shield_blockND_w16
  -- the relation layers
  have hksR : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, k < P.geom.slots.length := fun i hi k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts i hi).2 k hk
  have hdgR' : ∀ i, i < 4 → ∀ k ∈ (w16r2DR P spR i).ks, (w16r2DR P spR i).dg k ≤ 80 := fun _ _ _ _ => le_rfl
  have hfR := fun i (hi : i < 4) => schedOf_facts P (w16r2RelKs i) (spR i) (fun _ => 80) (hdgR i hi)
  have hNDR : ∀ i, i < 4 → defND P (w16r2DR P spR i).ks (w16r2DR P spR i).dg ≤ 80 * 426 := fun i hi =>
    shield_defND_le_w16 P hdr i hi _ 80 (fun _ _ => le_rfl)
  have hcR := hcoverR_layers U key domain hs hL P pr.hdrLen F csX msX Pb Lay B xtE A 4 (w16r2DR P spR) hvR hgdR
  -- the helper layer
  have hksH : ∀ i, i < 1 → ∀ k ∈ (w16r2DH P spH i).ks, k < P.geom.slots.length := fun _ _ k hk => by
    rw [hlen]
    exact (w16r2RelKs_facts 0 (by norm_num)).2 k hk
  have hfH := schedOf_facts P (w16r2RelKs 0) spH (fun _ => 80) hdgH
  have hNDH : ∀ i, i < 1 → defND P (w16r2DH P spH i).ks (w16r2DH P spH i).dg ≤ 80 * 426 := fun _ _ =>
    shield_defND_le_w16 P hdr 0 (by norm_num) _ 80 (fun _ _ => le_rfl)
  have hcH := hcoverH_layers U key domain hs hL P pr.hdrLen F csX msX A HGd 1 (w16r2DH P spH)
    (fun G bga rs acc hT i hi _ => by
      have hi0 : i = 0 := by omega
      subst hi0
      exact hvH G bga rs acc hT)
    (fun G bga rs acc hT hall => hgdH G bga rs acc hT (hall 0 (by norm_num)))
  have hsp := hsplit_two U key domain hs hL P pr.hdrLen F csX msX Pb Lay B fams xtE A HGd Alk T mlk hbr hhr
  have hbud : 3 * 2 ^ (126 - 106) + 2 * (2 ^ (126 - 111) + 2 ^ (126 - 113)) + 2 ^ 18 + 2 ^ 16 + 5
      + blockND P.geom.slots + 4 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14)
      + (1 * (80 + 80 * 426 + 2 ^ 14 + 2 ^ 14) + (50331700 + 2 ^ 14 + 2 ^ 14)) ≤ 2 ^ 26 := by
    rw [hND]
    exact shield_budget_w16_26
  -- the openings at W16R2's geometry `(15, 280, 8052)`
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hF2 : Fintype.card K = gP ^ 2 := card_of_pairs gP (Equiv.ofBijective _ hbij)
  have hp1 : gP ≤ 2 ^ 64 := by norm_num [gP]
  have hp2 : 2 ^ 64 - 2 ^ 32 ≤ gP := by norm_num [gP]
  have h64 : 64 ≤ L := by omega
  have hgeomL : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L :=
    fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.1, (hgeom k hk).2.2.2⟩
  have hm : (280 + 3) / 4 = pr.mI := by omega
  have hQm : 280 ≤ pr.mI * 4 := by omega
  have hnn : w16r2Prm.nn = 2 ^ 15 := by norm_num [PcsPrm.nn, w16r2Prm]
  have hPp' : ∀ (H : HIn → Dig) (cm : Cm) (root : Dig) (cl : List ZClaim) (o : OpeningZk) (t t' : Tr),
      P.pcsVerify H cm root cl o t = .ok t' →
        PcsOk H pr.tag w16r2Prm (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280) root (rowsOf cm) 14
          (cl.map toZClaim) (toOZ o) t t' := by
    intro H cm root cl o t t' h
    rw [hPp, pcsField, mapErr_ok, w16r2OpenCheck_ok_iff] at h
    exact h
  have hM := Link.evMW_bound U hbij pr L h64 key domain hs hL accRd hL64 hk (by unfold Link.OProf.aM; omega) q A hA
  have hEA := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 15 280 8052 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA)) pr.aA pr.aBA (by omega)
    (by unfold Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBA; omega) (fun acc => acc.claims.a) q A hA
  have hEH := Link.evOW_bound U hbij pr L h64 key domain hs hL accRd hL64 15 280 8052 (by norm_num) (by norm_num)
    (by norm_num) hQm pr.rH pr.nH (pr.hdrLen + 7) (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (by omega)
    (by unfold Link.OProf.aH Link.OProf.aBA Link.OProf.aA Link.OProf.aM; omega) (by unfold Link.OProf.aBH; omega)
    (fun acc => acc.claims.h ++ [P.logupSumClaim]) q A hA
  have hX := Link.extract_fail_block pr.tag L h64 key domain hs hL 280 280 256 15 15 12 q A hA
  have hsem := Link.hsem_geo U pr L hL20 hL64 key domain hs hL accRd rowsOf w16r2Prm 15 280 8052
    (colEncLag (rootFp 14) (2 ^ 14) 280) rfl rfl hnn (by decide) (by norm_num) (by norm_num) hm hPm hPp' hrA hrH hgt
    hgeomL A hcnt hRd csX msX hcsA hcsH hms
  have hexec := Link.hexec_geo U hU hbij pr L hL20 hL64 key domain hs hL accRd rowsOf w16r2Prm 15 280 8052
    (colEncLag (rootFp 14) (2 ^ 14) 280) rfl rfl rfl hnn (by decide) (by norm_num) (by norm_num) hm hQm
    (w16r2_colEnc_spec U) hPm hPp' hrA hrH hgt hgeomL hrows A hcnt hRd
  exact block_knowledge_target_RN26 U hU hK2 key domain hs hL hL64 (by omega) P pr.hdrLen F csX msX hpolyC hEval hdeg 5
    (by norm_num) hgeom hgt hℓs hℓd hℓk
    (fun cu rt => ZK60.Layout.W16Rels S Pb Lay B (xtE cu rt))
    (fun cu rt => ZK60.Layout.W16Lookups S Pb Lay B (xtE cu rt) fams)
    (fun cu rt => ZK60.Block.BlockSat Pb (fun p => (xtE cu rt).X (Lay.dPos p)) (fun p => (xtE cu rt).X2 (Lay.dPos p))
      (ZK60.Layout.toWit Lay (xtE cu rt)))
    (fun cu rt hr hl => ZK60.Layout.blockSat_of_slots Pb Lay B _ fams hF hW h24 hr hl) q A hA
    (fun G => Link.sqN (A.run G).1 = pr.hdrSq)
    (Link.GOW U pr L h64 key domain hs hL accRd 15 280 8052 pr.rA pr.nA pr.hdrLen pr.aA (fun acc => acc.claims.a) A)
    (Link.GOW U pr L h64 key domain hs hL accRd 15 280 8052 pr.rH pr.nH (pr.hdrLen + 7) pr.aH
      (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.GMW U pr L h64 key domain hs hL accRd A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 15 280 8052 hQm pr.rA pr.nA pr.hdrLen (pr.aA + (pr.nA + pr.rA))
      pr.aA pr.aBA (fun acc => acc.claims.a) A)
    (Link.EvOW U hbij pr L h64 key domain hs hL accRd 15 280 8052 hQm pr.rH pr.nH (pr.hdrLen + 7)
      (pr.aH + (pr.nH + pr.rH)) pr.aH pr.aBH (fun acc => acc.claims.h ++ [P.logupSumClaim]) A)
    (Link.EvMW U hbij pr L h64 key domain hs hL accRd A)
    (Link.EvXB pr.tag L h64 key domain hs hL 280 280 256 15 15 12 A) (2 ^ 20) le_rfl 106 111 113 (by norm_num)
    (by norm_num) (by norm_num) _ _ _ _ _ (maskEps_le hF2 hkF pr.hS) (opA_eps_w16r2 gP hp1 hp2 hF2 pr.hwA')
    opB_eps_w16r2 (opA_eps_w16r2 gP hp1 hp2 hF2 pr.hwH') opB_eps_w16r2 hM hEA hEH _ 3 (Link.xfail_T_w16r2 q) le_rfl hX
    hsem hexec εend hEnd 80 (80 * 426) 4 1 (w16r2DR P spR) (w16r2DH P spH) hksR hdgR' (fun i hi => (hfR i hi).1)
    (fun i hi => (hfR i hi).2) hNDR hcR Alk T mlk hN he hksH (fun _ _ _ _ => le_rfl) (fun _ _ => hfH.1)
    (fun _ _ => hfH.2) hNDH (EvHlpOf U key domain hs hL P pr.hdrLen F csX msX A HGd) hcH hsp hbud

/-- **One W16R2 Shieldstral T128 (`export_u1`) block's knowledge statement with bookkeeping and mask
half discharged, at LogUp's bound `e ≤ 2^26`** (W16R2 twin of `block_knowledge_final_r13_shield26`). -/
theorem block_knowledge_final_w16r2_shield26 [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 111) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 45)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csShieldW16 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the four relation layers
    (spR : ℕ → Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgR : ∀ i, i < 4 → ∀ cu rt k h, k ∈ w16r2RelKs i → (spR i cu rt k h).dg ≤ 80)
    (hvR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc → ∀ i, i < 4 →
      (∀ j, j < i → SchedGd (w16r2DR P spR j) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      SchedVan U P (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdR : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      (∀ i, i < 4 → SchedGd (w16r2DR P spR i) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs) →
      ZK60.Layout.W16Rels S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)))
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hvH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedVan U P (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hbr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ¬ ZK60.Layout.W16Lookups S Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) fams →
      ∃ l, ∀ j, T j ≠ Alk (cutsOf key domain hs hL A G).1 l)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend := by
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hfacts : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2
      ∧ 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := w16r2_shield_mask_facts k hk
    simp only [slotShape, hP.hsl]
    exact h1
  have hd1 : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 := fun k hk => (hfacts k hk).1
  exact block_knowledge_open_w16r2_shieldN26 U hU hK2 key domain hs hL hL64 hL20 P hP.hdr hP.hsl hP.htm
    (Link.profW16Shield P hP.hdr hP.hsl hP.hag hP.hhg tag hdrLen hdrSq hh hq) hh (maskedFX U tag hL20 P Poly)
    (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) hpolyC
    (fun cu rt => maskedF_slotEvalN U hU hbij P _ _ _ 512 (Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt)
      (fun k hk => (hfacts k hk).2) (Poly cu rt) (hPoly cu rt))
    (fun cu rt k sn => maskedF_indDeg_all U _ P (Poly cu rt) hd1 (hdegP cu rt) k sn)
    Pb Lay B fams hF hW h24 xtE q A hA rfl rowsOf hP.hPm hP.hPp hP.hrA hP.hrH
    ⟨by show 8 * 2504 ≤ L; omega, by show 8 * 2606 ≤ L; omega, by show 8 * (2 * 23 + 4) ≤ L; omega⟩
    (by rw [hP.hnf]; norm_num) (by rw [hP.hnf]; norm_num)
    (fun G bga rs acc hacc => Link.hcnt_of_defCm P hdrLen key domain aC hC 111 45 23 hlen23 hsA hsH hdc G (A.run G)
      bga rs acc hacc.1)
    (tAccRd P hdrLen)
    (fun G bga rs acc hacc _ => by
      rw [accRd_slotTrace P hdrLen key domain hd1 G (A.run G) bga rs acc hacc.1]
      exact ⟨rfl, rfl, rfl⟩)
    (fun _ _ _ => rfl) (fun _ _ _ => rfl) (fun _ _ _ => rfl) εend hEnd spR hdgR hvR hgdR HGd spH hdgH hvH hgdH Alk T
    mlk hN he hbr hhr

/-- **One W16R2 Shieldstral T128 (`export_u1`) block's knowledge statement with the relation layers'
algebra, reindexing, and lookup cover bridge `hbr` discharged, at LogUp's bound `e ≤ 2^26`**
(W16R2 twin of `block_knowledge_alg_r13_shield_lk26`). -/
theorem block_knowledge_alg_w16r2_shield_lk26 [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (aC hC : List ℕ) (hdc : Link.DefCm P aC hC)
    (hsA : sumFrom (fun k => aC.getD k 0) 0 23 = 111) (hsH : sumFrom (fun k => hC.getD k 0) 0 23 + 1 = 45)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (Poly : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hPoly : ∀ cu rt, SlotEvalN U P (Link.csShieldW16 U tag hL20 csE cu rt) (fun _ => 0) (Poly cu rt))
    (hdegP : ∀ cu rt k sn, IndDegLE (slotShape P k).2.2 (Poly cu rt k sn))
    (Pb : ZK60.Block.BlockPublic S) (Lay : ZK60.Layout.W16Layout S Ct Cw Cg Cj Cd Cf) (B : ZK60.Layout.W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : ZK60.Layout.W16Widths S fams) (h24 : S.h24 = true)
    (xtE : Cuts3 L → RootsO → ZK60.Layout.W16Data Ct Cw Cg Cj Cd Cf)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- the block's algebra: the shape facts, the tables, the hosts' named identities, the reindexing
    (sh : AlgShape P) (dt : AlgData K L sh)
    (hform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U sh dt (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k)
    (enc : (k : ℕ) → (Fin (ZK60.Exec.Slot.W16R2.segLn (sh.dl k) .tau) → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (encHt : (Fin sh.nHt → Bool) → W16Pos Ct Cw Cg Cj Cd Cf)
    (hspec : W16Spec sh dt Pb Lay B xtE enc encHt)
    (hTok : Function.Surjective Lay.tok.emb) (hHd : Function.Surjective Lay.hd.emb)
    -- the helper layer and LogUp
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag
      hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P (Poly (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 2 ^ 26)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P Poly) (Link.csShieldW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X (Lay.dPos p))
          (fun p => (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay (xtE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))))
      ≤ εsTarget q + εend := by
  have hbij := ZK60.Hiding.fp2_bijective hK2 hU seven_not_square
  have hlen23 : P.geom.slots.length = 23 := by rw [hP.hsl]; rfl
  have hNs : ∀ k, k < P.geom.slots.length → 0 < (slotShape P k).1 + (slotShape P k).2.1
      ∧ (slotShape P k).1 + (slotShape P k).2.1 < 64
      ∧ ((slotShape P k).1 + (slotShape P k).2.1) * (slotShape P k).2.2 + 2 ≤ 512 := by
    intro k hk
    rw [hlen23] at hk
    have h1 := w16r2_shield_mask_facts k hk
    have h2 := w16r2_shield_slot64 k hk
    simp only [slotShape, hP.hsl]
    exact ⟨h1.2.1, h2, h1.2.2⟩
  have hlin := fun (cu : Cuts3 L) (rt : RootsO) => Link.msXof_mlin U tag L (Link.le64_of_le20 hL20) 23 cu rt
  exact block_knowledge_final_w16r2_shield26 U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP aC hC hdc hsA hsH
    hdrLen hdrSq hh hq Poly csE hpolyC hPoly hdegP Pb Lay B fams hF hW h24 xtE q A hA εend hEnd
    (algSp U sh dt (card_K_gt K)) (algSp_dg U sh dt (card_K_gt K))
    (fun G bga rs acc hT => alg_hvR U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A sh dt
      (card_K_gt K) G bga rs acc hT (hform G bga rs acc hT))
    (fun G bga rs acc _ hall => w16Rels_of_algGood sh dt Pb Lay B xtE enc encHt hspec hTok hHd _ _ bga
      (algGood_of_gd U sh dt (card_K_gt K) _ _ bga rs hall))
    HGd spH hdgH
    (fun G bga rs acc hT => alg_hvH U hU hbij key domain hs hL hdrLen _ 512 Poly _ _ hlin hNs A spH G bga rs acc hT
      (hformH G bga rs acc hT))
    hgdH Alk T mlk hN he
    (fun G _ _ _ _ hn => hbr_w16_of_cover (Alk (cutsOf key domain hs hL A G).1) T hTtab (hcov G) hn) hhr

end ShieldW16

end ZK60.Exec.Block
