/-
D63 lane L63 (2026-11-18), part 69: **the BOS and template facts of `A_TOK` at every reading** (a first piece of
item 5, `hdinX`: its split (b) of HANDOFF_20261118_2.md section 5).

* `incBosTmpl_of_qzc`: SIC_QZC's clauses alone give the layout's BOS and template facts (`incCube`'s second
  conjunct, which reads neither SIC_TZC nor the sums);
* **`shd_bosTmpl_of_rd`**: from SIC_QZC's clauses at every reading (as `shd_inc_qt_run` gives them from no doomed
  `rtKR0` entrant, or a reading's alive QZC define state through `stg_def_zero_of_alive`), the stage IN-C data's token
  plane is the public BOS at position `0` and the public template id at every template position
  (`shdIncLay_bosTmpl`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldIncZSRun

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX ZK60.TokenRun
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Q

variable {B K : Type} [Field B] [Field K] {ι κ : Type} {k : ℕ}

/-- **SIC_QZC's clauses alone give the BOS and template facts** (`incCube`'s second conjunct). -/
theorem incBosTmpl_of_qzc (φ : B →+* K) (D : InData B ι κ k) {n nv nu : ℕ} (L : IncLayout φ D n nv)
    (ω : InChal K k) (hd : IncHelpers K n nv nu) (hq : QzcHolds (incQ L ω hd) ω.1.2 ω.1.1.1 (L.g ω) L.bos) :
    IncBosTmpl L := by
  refine ⟨fun t ht0 => ?_, fun t hpt => ?_⟩
  · obtain ⟨-, e2, -⟩ := qzc_cube hq (L.pos t)
    simp only [incQ] at e2
    rw [L.tok_pos t, ht0, one_mul] at e2
    exact sub_eq_zero.mp e2
  · obtain ⟨-, -, e3, -⟩ := qzc_cube hq (L.pos t)
    simp only [incQ] at e3
    rw [L.tok_pos t, hpt, one_mul] at e3
    exact sub_eq_zero.mp e3

end Q

section BT

variable {K : Type} [Field K] [Algebra GF K] {Lq : ℕ}

/-- **THE BOS AND TEMPLATE FACTS OF `A_TOK` AT EVERY READING**, from SIC_QZC's clauses there. -/
theorem shd_bosTmpl_of_rd (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB hdrLen rH iH : ℕ)
    (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1))
    (hbos : I.bos = P.bos) (hT : ∀ t : shieldS0.Tok, I.isTemplate t.val = P.isT t)
    (hk : ∀ t : shieldS0.Tok, I.kappa t.val = P.kap t)
    (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hqt : ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      QzcHolds (incQ (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq) (incChalOf U ch)
          (shdIncHd U tag h64 I ogStage.lc ogStage.h ogStage.Q ogStage.e rH iH (stgVw absOf Lg τ)))
        (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
        ((shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).g (incChalOf U ch))
        (shdIncLay U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq).bos) :
    ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
      (∀ t : shieldS0.Tok, (t : ℕ) = 0 →
          (shdIncDataK U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ)).tok t = ((P.bos : ℕ) : K))
        ∧ (∀ t : shieldS0.Tok, P.isT t = true →
          (shdIncDataK U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ)).tok t = ((P.kap t : ℕ) : K)) := by
  intro hdr core ch rs hrd
  exact shdIncLay_bosTmpl U tag h64 P I Epad iB hdrLen (stgVw absOf Lg τ) hv hV htok hcq hbos hT hk
    (incBosTmpl_of_qzc (RingHom.id K) _ _ (incChalOf U ch) _ (hqt hdr core ch rs hrd))

end BT

end ZK60.ProtocolClassify
