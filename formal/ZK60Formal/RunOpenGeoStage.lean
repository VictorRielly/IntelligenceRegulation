/-
D63 lane L48 (2026-11-10), part 5: **the stages' and the input endpoint's opening premises MET by the real stage
verifiers** (finding L45-2; the premises `hIA`, `hIH`, `hOA`, `hOH` of the app's top theorem, and part `0`'s closing
opening).

L45's stage lemmas asked `RkPcsR13` of the stages' `A` and `H` verifiers (`log_cols 14`, `N = 2^16`); the real ones are
at `2^12`. With the width a parameter (part 1), the premise is `RkPcsAt U tag g`, and here it is PROVED at the real
stage verifiers for the geometries of part 2:

* **`rcPcsAt_stage`**: L29's `pcsAt` (the code's `pcs::verify_zk_tagged`) at `log_cols 12`, rate `2^-2`, `256`
  queries and pads meets `RkPcsAt` at `ogStage` (its column evaluator meets `ColEncSpec` at `RWL 12`: L10's
  `colEncLag_spec` with the roots of `G_{2^12}` and `G_{2^14}`); **`rcPcsAt_ep`**: at `log_cols 8`, rate `2^-3`,
  `256`, it meets `RkPcsAt` at `ogEp`;
* **`rcIncAt_pA_stage`**, **`rcIncAt_pH_stage`**: stage IN-C's contract `rcIncAt` (L39, at L29's `incVAt`) at the tier's
  numbers (`pub.lt = 12`, `lr = 2`, `q = 256`) has `A` and `H` at `ogStage`; **`rcIncAt_pX_ep`**: its closing opening
  (the input token endpoint, at `pub.epLogN = 8`, `elr = 3`, `eq = 256`) at `ogEp`;
* **`rcOutcAt_pA_stage`**, **`rcOutcAt_pH_stage`**: stage OUT-C's contract `rcOutcAt` at `O.lt = 12`, `lr = 2`,
  `q = 256`.

The numbers `pub.lt = 12`, `lr = 2`, `q = 256`, `pub.epLogN = 8`, `elr = 3`, `eq = 256` are the ones L29's verifier
`incVAt` was run with on a real classifier receipt (the corpus fields `INP 7`, `INPCS 1`, `INPCS 3`, `INP 8`,
`INPCS 2`, `INPCS 4`), CHECKED against the code by `RunOpenGeoCheck.lean`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoTier
import ZK60Formal.RunHalBlk
import ZK60Formal.RunCoverStage

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section Stage

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)

/-- **L29's `pcsAt` at the stage geometry meets `RkPcsAt ogStage`** (`log_cols 12`, rate `1/4`, `256` checks and pads:
`N = 2^14`, the coset `7·G_{2^14}`, the column evaluator `colEncLag (rootFp 12) (2^12) 256` meeting `ColEncSpec` at
`RWL 12`). -/
theorem rcPcsAt_stage {ι : Type}
    (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) (logN rows : ℕ)
    (hV : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr),
      V i H root cl o t = pcsAt tag logN 2 256 H root rows cl o t)
    (hq : 0 < 256) (h15 : 2 ^ logN + 256 ≤ 2 ^ 15) (hl : logN = 12) :
    RkPcsAt U tag ogStage (rcPcsAt V tag logN 2 256 rows hV hq h15) := by
  subst hl
  exact
    { hQ := rfl
      hN := by
        show 2 ^ 12 * 2 ^ 2 = 2 ^ 14
        norm_num
      hlc := rfl
      hlc' := rfl
      hpt := rfl
      hspec := by
        show ColEncSpec U (RWL (K := K) 12) 256 (cosetPt (rootFp 14)) (colEncLag (rootFp 12) (2 ^ 12) 256)
        rw [RWL_of_le 12 (by norm_num)]
        exact colEncLag_spec U (Nat.two_pow_pos 12) (by norm_num) (pow_dvd_pow 2 (by norm_num : 12 ≤ 14)) rfl
          (by norm_num) _ _ (rootFp_isPrimitiveRoot (by norm_num)) (rootFp_isPrimitiveRoot (by norm_num))
      htag := rfl }

/-- **L29's `pcsAt` at the input endpoint geometry meets `RkPcsAt ogEp`** (`log_cols 8`, rate `1/8`, `256` checks and
pads: `N = 2^11`, the coset `7·G_{2^11}`). -/
theorem rcPcsAt_ep {ι : Type}
    (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) (logN rows : ℕ)
    (hV : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr),
      V i H root cl o t = pcsAt tag logN 3 256 H root rows cl o t)
    (hq : 0 < 256) (h15 : 2 ^ logN + 256 ≤ 2 ^ 15) (hl : logN = 8) :
    RkPcsAt U tag ogEp (rcPcsAt V tag logN 3 256 rows hV hq h15) := by
  subst hl
  exact
    { hQ := rfl
      hN := by
        show 2 ^ 8 * 2 ^ 3 = 2 ^ 11
        norm_num
      hlc := rfl
      hlc' := rfl
      hpt := rfl
      hspec := by
        show ColEncSpec U (RWL (K := K) 8) 256 (cosetPt (rootFp 11)) (colEncLag (rootFp 8) (2 ^ 8) 256)
        rw [RWL_of_le 8 (by norm_num)]
        exact colEncLag_spec U (Nat.two_pow_pos 8) (by norm_num) (pow_dvd_pow 2 (by norm_num : 8 ≤ 11)) rfl
          (by norm_num) _ _ (rootFp_isPrimitiveRoot (by norm_num)) (rootFp_isPrimitiveRoot (by norm_num))
      htag := rfl }

variable {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)

/-- **Stage IN-C's `A` at the real stage verifier** (`rcIncAt` at L29's `incVAt`, the tier's `pub.lt = 12`, `lr = 2`,
`q = 256`): `RkPcsAt ogStage`. -/
theorem rcIncAt_pA_stage (pub : IncPub) (geo : IncGeo) (blk ed : Block.Dim) (elr eq total : ℕ) (hq : 0 < 256)
    (heq : 0 < eq) (h15 : 2 ^ pub.lt + 256 ≤ 2 ^ 15) (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) (hlt : pub.lt = 12) :
    RkPcsAt U tag ogStage
      (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed 2 elr 256 eq total hq heq h15 he15).pA :=
  rcPcsAt_stage U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hq h15 hlt

/-- **Stage IN-C's `H` at the real stage verifier**: `RkPcsAt ogStage`. -/
theorem rcIncAt_pH_stage (pub : IncPub) (geo : IncGeo) (blk ed : Block.Dim) (elr eq total : ℕ) (hq : 0 < 256)
    (heq : 0 < eq) (h15 : 2 ^ pub.lt + 256 ≤ 2 ^ 15) (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) (hlt : pub.lt = 12) :
    RkPcsAt U tag ogStage
      (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed 2 elr 256 eq total hq heq h15 he15).pH :=
  rcPcsAt_stage U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hq h15 hlt

/-- **Stage IN-C's closing opening (the classifier's input token endpoint) at the real stage verifier** (`pub.epLogN =
8`, `elr = 3`, `eq = 256`): `RkPcsAt ogEp`. -/
theorem rcIncAt_pX_ep (pub : IncPub) (geo : IncGeo) (blk ed : Block.Dim) (lr q total : ℕ) (hq : 0 < q)
    (heq : 0 < 256) (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ pub.epLogN + 256 ≤ 2 ^ 15) (hep : pub.epLogN = 8) :
    RkPcsAt U tag ogEp
      (rcIncAt (Hdr := Hdr) Lq hL20 tag pub geo blk ed lr 3 q 256 total hq heq h15 he15).pX :=
  rcPcsAt_ep U tag _ _ _ (fun _ _ _ _ _ _ => rfl) heq he15 hep

/-- **Stage OUT-C's `A` at the real stage verifier** (`rcOutcAt` at L29's `outcVAt`, `O.lt = 12`, `lr = 2`,
`q = 256`): `RkPcsAt ogStage`. -/
theorem rcOutcAt_pA_stage (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx blr bq total pend : ℕ)
    (hq : 0 < 256) (hbq : 0 < bq) (h15 : 2 ^ O.lt + 256 ≤ 2 ^ 15) (hb15 : 2 ^ geo.bLogN + bq ≤ 2 ^ 15)
    (hlt : O.lt = 12) :
    RkPcsAt U tag ogStage
      (rcOutcAt (Hdr := Hdr) Lq hL20 tag O geo blk bd idx 2 blr 256 bq total pend hq hbq h15 hb15).pA :=
  rcPcsAt_stage U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hq h15 hlt

/-- **Stage OUT-C's `H` at the real stage verifier**: `RkPcsAt ogStage`. -/
theorem rcOutcAt_pH_stage (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx blr bq total pend : ℕ)
    (hq : 0 < 256) (hbq : 0 < bq) (h15 : 2 ^ O.lt + 256 ≤ 2 ^ 15) (hb15 : 2 ^ geo.bLogN + bq ≤ 2 ^ 15)
    (hlt : O.lt = 12) :
    RkPcsAt U tag ogStage
      (rcOutcAt (Hdr := Hdr) Lq hL20 tag O geo blk bd idx 2 blr 256 bq total pend hq hbq h15 hb15).pH :=
  rcPcsAt_stage U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hq h15 hlt

end Stage

end ZK60.ProtocolClassify
