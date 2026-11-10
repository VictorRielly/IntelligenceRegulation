/-
D63 lane L55 (2026-11-10), part 4: **the closing openings of parts `1` on: their verifiers' numbers at the boundary
geometry, met by the real objects** (the brief's deliverable 2; L50 §5 item 4: "`bndOpen` is abstract, so it needs an
`RkPcsAt` premise at the boundary geometry").

The run's boundary openings are `pcs::verify_zk_tagged` at the boundary spec's params, rows and `log_n`
(classify_run.rs:439-441 for block `k`'s opening of the previous boundary; stage_out_c.rs:722-725 for `B_out`), the
spec at R13 Shieldstral T128 being `log_n 14`, rate `1/4`, `256` checks, `38` rows (`RunCloseBGeo.lean`, CHECKED by
`RunCloseBGeoCheck.lean`). L29's `pcsAt` is the Lean `pcs::verify_zk_tagged`. Here:

* **`rcPcsAt_bnd`**: `pcsAt` at `log_cols 14`, rate `2^-2`, `256` checks and pads meets `RkPcsAt` at `ogR13` (its
  column evaluator meets `ColEncSpec` at `RWL 14`) and L43's `RkPcsR13`;
* **`rcOutcAt_pX_bnd`**: stage OUT-C's closing opening (`B_out`) at the real OUT-C contract `rcOutcAt` (L29's
  `outcVAt`, `geo.bLogN = 14`, `blr = 2`, `bq = 256`) meets `RkPcsAt ogR13`: the premise the OUT-C instance of `hopX`
  needs, PROVED at the real stage;
* **`cbBndOpen`**: the code's boundary opening as the run's `bndOpen` (block `k` opens the previous boundary at the
  boundary spec: `pcsAt tag 14 2 256 · root rows`); **`cbBndPcs`**, **`cbBndPcs_at`**, **`cbBndPcs_r13`**, **`cbBndPcs_rows`**:
  its contract `RtPcs` (the one `rcRunClassifyAt` takes as each block's `pX`) and its numbers at `ogR13`, with `38`
  rows at R13 Shieldstral T128: the premise the blocks' instances of `hopX` need, PROVED at the code's `bndOpen`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoStage
import ZK60Formal.RunCloseBGeo

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV
open ZK60.Circuit (gP GF)

section Bnd

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)

/-- **L29's `pcsAt` at the boundary geometry meets `RkPcsAt ogR13`** (`log_cols 14`, rate `1/4`, `256` checks and pads:
`N = 2^16`, the coset `7·G_{2^16}`, the column evaluator `colEncLag (rootFp 14) (2^14) 256` meeting `ColEncSpec` at
`RWL 14`). -/
theorem rcPcsAt_bnd {ι : Type}
    (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) (logN rows : ℕ)
    (hV : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr),
      V i H root cl o t = pcsAt tag logN 2 256 H root rows cl o t)
    (hq : 0 < 256) (h15 : 2 ^ logN + 256 ≤ 2 ^ 15) (hl : logN = 14) :
    RkPcsAt U tag ogR13 (rcPcsAt V tag logN 2 256 rows hV hq h15) := by
  subst hl
  exact
    { hQ := rfl
      hN := by
        show 2 ^ 14 * 2 ^ 2 = 2 ^ 16
        norm_num
      hlc := rfl
      hlc' := rfl
      hpt := rfl
      hspec := by
        show ColEncSpec U (RWL (K := K) 14) 256 (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256)
        rw [RWL_of_le 14 (by norm_num)]
        exact colEncLag_spec U (Nat.two_pow_pos 14) (by norm_num) (pow_dvd_pow 2 (by norm_num : 14 ≤ 16)) rfl
          (by norm_num) _ _ (rootFp_isPrimitiveRoot (by norm_num)) (rootFp_isPrimitiveRoot (by norm_num))
      htag := rfl }

/-- The same in L43's form `RkPcsR13` (`RWL 14 = RW`). -/
theorem rcPcsAt_bnd_r13 {ι : Type}
    (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) (logN rows : ℕ)
    (hV : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr),
      V i H root cl o t = pcsAt tag logN 2 256 H root rows cl o t)
    (hq : 0 < 256) (h15 : 2 ^ logN + 256 ≤ 2 ^ 15) (hl : logN = 14) :
    RkPcsR13 U tag (rcPcsAt V tag logN 2 256 rows hV hq h15) := by
  have h := rcPcsAt_bnd U tag V logN rows hV hq h15 hl
  exact
    { hQ := h.hQ
      hN := h.hN
      hlc := h.hlc
      hlc' := h.hlc'
      hpt := h.hpt
      hspec := by
        have hs := h.hspec
        rw [show ogR13.lc = 14 from rfl, RWL_14] at hs
        exact hs
      htag := h.htag }

variable {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)

/-- **Stage OUT-C's closing opening (`B_out`) at the real stage verifier** (`rcOutcAt` at L29's `outcVAt`,
`geo.bLogN = 14`, `blr = 2`, `bq = 256`: the boundary spec at R13 Shieldstral T128): `RkPcsAt ogR13`. -/
theorem rcOutcAt_pX_bnd (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx lr q total pend : ℕ) (hq : 0 < q)
    (hbq : 0 < 256) (h15 : 2 ^ O.lt + q ≤ 2 ^ 15) (hb15 : 2 ^ geo.bLogN + 256 ≤ 2 ^ 15) (hb : geo.bLogN = 14) :
    RkPcsAt U tag ogR13
      (rcOutcAt (Hdr := Hdr) Lq hL20 tag O geo blk bd idx lr 2 q 256 total pend hq hbq h15 hb15).pX :=
  rcPcsAt_bnd U tag _ _ _ (fun _ _ _ _ _ _ => rfl) hbq hb15 hb

/-- **The code's boundary opening as the run's `bndOpen`**: block `k` opens the previous boundary (root `root`) at the
boundary spec, `pcs::verify_zk_tagged` at `log_n 14`, rate `1/4`, `256` checks, `rows` rows (classify_run.rs:439-441;
the spec CHECKED by `RunCloseBGeoCheck.lean`). -/
def cbBndOpen {St : Type} (rows : ℕ) : (HIn → Dig) → St → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr →
    Except String Tr :=
  fun H _ _ root cl o t => pcsAt tag 14 2 256 H root rows cl o t

/-- **Its contract** (`RtPcs`, the `pX` that `rtBlock_holds` / `rcRunClassifyAt` take for block `k`). -/
def cbBndPcs {St : Type} (rows k : ℕ) :
    RtPcs (fun (s : St) H root cl o t => cbBndOpen tag rows H s k root cl o t) :=
  rcPcsAt _ tag 14 2 256 rows (fun _ _ _ _ _ _ => rfl) (by norm_num) (by norm_num)

/-- **Its numbers at the boundary geometry**: `RkPcsAt ogR13`. -/
theorem cbBndPcs_at {St : Type} (rows k : ℕ) : RkPcsAt U tag ogR13 (cbBndPcs (St := St) tag rows k) :=
  rcPcsAt_bnd U tag _ 14 rows (fun _ _ _ _ _ _ => rfl) (by norm_num) (by norm_num) rfl

/-- **And in L43's form `RkPcsR13`.** -/
theorem cbBndPcs_r13 {St : Type} (rows k : ℕ) : RkPcsR13 U tag (cbBndPcs (St := St) tag rows k) :=
  rcPcsAt_bnd_r13 U tag _ 14 rows (fun _ _ _ _ _ _ => rfl) (by norm_num) (by norm_num) rfl

/-- **Its rows at R13 Shieldstral T128 are the boundary's `38`** (`cbBndRows_r13`), and `8·38` fits any `Lq ≥ 2^20`. -/
theorem cbBndPcs_rows {St : Type} (k : ℕ) :
    (cbBndPcs (St := St) tag (cbBndRows 128 4096 14 2) k).rows = 38 ∧ 8 * 38 ≤ 2 ^ 20 :=
  ⟨cbBndRows_r13, by norm_num⟩

end Bnd

end ZK60.ProtocolClassify
