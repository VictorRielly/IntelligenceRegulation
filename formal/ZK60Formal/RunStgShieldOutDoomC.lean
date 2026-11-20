/-
D63 lane L63 (2026-11-20), L63 leg 15, part 98: **`hdoutC`'s doom from a failing `OutCSat`** (the bridge from the
assembly lemma to `hdoutC`'s conclusion, step 3 of HANDOFF_20261120_1.md section 7, its generic half).

`hdoutC`'s conclusion is `StgDoomAtV … (OUT-C)`: at every OUT-C reading one of three doom disjuncts holds. If none
held at some reading, the drawing slots would be alive and the LogUp state alive at the head, and
`shd_outc_sat_rd` would give `OutCSat` at `τ`'s view on `B_out`'s verdict row; a vector `X` equal to that row at every
reading (at the top: the extractor's `xC`, `epxIO_xC` and `bndPlanes_tau`) then satisfies `OutCSat`.

* **`shd_outc_doomAt`**: `¬ OutCSat P X b` and the tie `X = B_out(row, ·)` at every reading give `StgDoomAtV … (OUT-C)`;
* `shdP_outcV_pub`, `shdP_outc_tB`, `shdP_outc_bo`, `shdP_outc_lift`: stage OUT-C's numbers at the concrete schedule.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutSat

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic OutCSat)

section Doom

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) {Lq : ℕ}

/-- **`hdoutC`'S DOOM FROM A FAILING `OutCSat`**: if `X` is `B_out`'s verdict row at `τ`'s view at every OUT-C reading
and `OutCSat P X b` fails, every OUT-C reading has a doomed entrant. -/
theorem shd_outc_doomAt (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (absOf : QB Lq → Option (List UInt8)) (tag : MTag) (h64 : 64 ≤ Lq) (O : OutcPub) (P0 : Block.BlockParams)
    (F : ℕ → OutcV) (b n0 hdrLen rA rH e rX ipos : ℕ) (XO : StgVw Lq → Fin 0 → Fin (2 ^ 0 + 0) → K)
    (hIOl : VwLoc (hdrLen + (7 + 2)) (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (hIO : StgCsIODeg U hbij (F b).bp.endpointLogN (OutcPrivIO (F b).pub)
      (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
    (hostOf : ℕ → List (ℕ × ℕ)) (Fst : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (hrA : rA = 76)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hP : StgSame P0 (F b).bp) (hgt : (F b).bp.geom.slots.length = (F b).bp.geom.terms.length)
    (hgeom : ∀ k, k < (F b).bp.geom.slots.length → 1 ≤ (Block.slotShape (F b).bp k).2.2)
    (hsl : 7 ≤ P0.geom.slots.length) (hW : vdWout F (τ.take n0) = F b)
    (hGb : (F b).geo.bLogN = 14) (hOL : outcLay (F b).pub 14 = outcLay O 14)
    (hllo : (F b).pub.llo = 12) (hldo : (F b).pub.ldo = 12) (hdB : (F b).pub.dBits = 12)
    (hlift : (F b).pub.lift = 0) (htB : (F b).pub.tBits = 7) (hbo : (F b).pub.bOutLog = 19)
    (hdPad : (F b).pub.dPad = 4096) (hlt : (F b).pub.lt ≤ ogStage.lc) (hlc : 0 < (F b).bp.logCols)
    (hOlt : O.lt = 12)
    {d : ℕ} (P : OutCPublic d) (hPv : P.Valid) (hb : b ≤ 1) (hverd : (F b).pub.verdict = b)
    (hcc : (F b).pub.c = P.c) (hlim : (F b).pub.limbs = P.limbs) (hdd : (F b).pub.d = d) (hd4 : d ≤ 4096)
    (hwl : d ≤ (F b).pub.wDelta.length) (hwD : ∀ i : Fin d, (F b).pub.wDelta.getD i.val 0 = P.wΔ i)
    (hg0 : P.g0 = (F b).pub.g0) (hcn : P.cn = (F b).pub.cn) (htn : P.tn = (F b).pub.tn)
    (hceps : (F b).pub.ceps = P.ceps)
    (X : Fin d → GF) (hnot : ¬ OutCSat P X b)
    (htie : ∀ hdr core ch rs, StgRd key domain Lq (fun _ => (F b).bp) 2 hdrLen OutcV.bga G τ hdr core ch rs →
      X = fun i => (shdOutcData U tag h64 O hdrLen rX ipos (F b).pub.verdictRow (stgVw absOf lg τ)).bout
        (msbBits 12 i.val)) :
    StgDoomAtV U key domain P0 (fun _ => (F b).bp) 2 hdrLen OutcV.bga hostOf absOf Fst
      (sshΦO U hbij tag h64 P0 F n0 hdrLen ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH
        (stgCsIOm U rX 14 256 0 0 0 (bxUxV tag Lq h64 rX ipos) XO))
      sshDgO e (shd_ΛO U tag h64 O hdrLen) G lg τ := by
  subst hrA
  intro hdr core ch rs hrd
  by_contra hcon
  rcases not_or.mp hcon with ⟨h1, h23⟩
  rcases not_or.mp h23 with ⟨h2, -⟩
  simp only [not_exists, not_and, not_not] at h1
  rw [not_not] at h2
  apply hnot
  rw [htie hdr core ch rs hrd]
  exact shd_outc_sat_rd U hbij hU key domain absOf tag h64 O P0 F b n0 hdrLen rH e rX ipos XO hIOl hIO G lg τ hdr core
    ch rs hrd hP hgt hgeom hsl hW hGb hOL hllo hldo hdB hlift htB hbo hdPad hlt hlc hOlt P hPv hb hverd hcc hlim hdd hd4
    hwl hwD hg0 hcn htn hceps h1 h2

end Doom

section Nums

variable (tag : MTag) (Rp : ZK60.RunShape.ClassifyRunPublicP RunShape.Shield.shieldS0) (wDigest : Dig) (bOutRow : ℕ)

theorem shdP_outcV_pub (v : ℕ) : (shdP_outcV tag Rp wDigest bOutRow v).pub = rcVerdict (shdP_outcPub Rp wDigest) v :=
  rfl

theorem shdP_outc_tB (v : ℕ) : (shdP_outcV tag Rp wDigest bOutRow v).pub.tBits = 7 := by
  show clog2 128 = 7
  exact shdP_clog2_128

theorem shdP_outc_bo (v : ℕ) : (shdP_outcV tag Rp wDigest bOutRow v).pub.bOutLog = 19 := by
  show Nat.log2 (128 * 4096) = 19
  rw [show 128 * 4096 = 2 ^ 19 by norm_num]
  exact Nat.log2_two_pow

theorem shdP_outc_lift (v : ℕ) : (shdP_outcV tag Rp wDigest bOutRow v).pub.lift = 0 := by
  show (shdP_outcPub Rp wDigest).ldo - (shdP_outcPub Rp wDigest).dBits = 0
  rw [(shdP_outcPub_logs Rp wDigest).2.1, (shdP_outcPub_logs Rp wDigest).2.2.2]

end Nums

end ZK60.ProtocolClassify
