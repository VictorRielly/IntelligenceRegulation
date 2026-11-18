/-
D63 lane L63 (2026-11-18), part 54: **`hLI_stg` from the IN-C slots' conclusions at every reading** (item 4b, the
algebraic half: `incCube` at the run).

* `ShdIncSlotsAt`: at every reading of stage IN-C (`m = 15`), with the layout `Lof v` and the committed helpers
  `hdOf v` (`h_q`, `h_tab`, `u` read at the head's view), SIC_QZC's and SIC_TZC's clauses and pads vanish on their
  cubes at the drawn challenges, the `H` opening's value-0 sum claim holds and the zero-sum row sums to `0` (defined,
  not assumed: the exact statement item 4b still has to prove from "no doomed R0 / sl / H entrant");
* **`shdLuInAtK_of_slots`**: it gives `ShdLuInAtK` (`incCube`: the helpers read at the logical positions satisfy the
  stage's LogUp relation);
* **`shd_hLI_of_slots`**: at the concrete layout `shdIncLay`, it gives `hLI_stg`'s conclusion `StgLkAtV … shd_ΛI …`
  (through `shdLuInAt_of_K`, the planes being base values, and `stgLkAtV_of_luIn`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuBase
import ZK60Formal.RunStgShieldIncLay

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.Exec.StageV (IncPub)
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

section Slots

variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K] {Lq : ℕ}

/-- The challenges `((β, γ), α), r_emb` a reading draws at the head (`ch`'s first `15` words). -/
noncomputable def incChalOf (U : K) (ch : List Fp2) : InChal K 12 :=
  ((((ch.getD 0 Fp2.zero).toK U, (ch.getD 1 Fp2.zero).toK U), (ch.getD 2 Fp2.zero).toK U),
    fun c : Fin 12 => (ch.getD (3 + c.val) Fp2.zero).toK U)

/-- **The IN-C slots' conclusions at every reading** (defined, not assumed). -/
def ShdIncSlotsAt {V nu : ℕ} (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (Dof : StgVw Lq → InData K shieldS0.Tok (Fin V) 12)
    (Lof : (v : StgVw Lq) → IncLayout (RingHom.id K) (Dof v) 12 17)
    (hdOf : StgVw Lq → IncHelpers K 12 17 nu)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain Lq Pof 15 hdrLen bgaOf G τ hdr core ch rs →
    ch.length = 15 ∧
    QzcHolds (incQ (Lof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)))) (incChalOf U ch)
        (hdOf (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Block.rootOpsA (Pof ch) core)))))
      (incChalOf U ch).1.2 (incChalOf U ch).1.1.1
      ((Lof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)))).g (incChalOf U ch))
      (Lof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)))).bos
    ∧ TzcHolds (incT (Lof (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)))) (incChalOf U ch)
        (hdOf (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ Block.rootOpsA (Pof ch) core)))))
      (incChalOf U ch).1.2
    ∧ IncSum (hdOf (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core))))
    ∧ ∑ j, (hdOf (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)))).2.2 j = 0

/-- **The slots' conclusions give the stage's LogUp relation at every reading** (`incCube`). -/
theorem shdLuInAtK_of_slots {V nu : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (absOf : QB Lq → Option (List UInt8)) (Dof : StgVw Lq → InData K shieldS0.Tok (Fin V) 12)
    (Lof : (v : StgVw Lq) → IncLayout (RingHom.id K) (Dof v) 12 17) (hdOf : StgVw Lq → IncHelpers K 12 17 nu)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdIncSlotsAt U key domain Pof hdrLen bgaOf absOf Dof Lof hdOf G Lg τ) :
    ShdLuInAtK U key domain Pof hdrLen bgaOf absOf Dof G Lg τ := by
  intro hdr core ch rs hrd
  obtain ⟨hl, hq, ht, hs, hz⟩ := h hdr core ch rs hrd
  exact ⟨hl, _, (incCube (RingHom.id K) _ (Lof _) (incChalOf U ch) _ hq ht hs hz).1⟩

/-- **`hLI_stg`'s conclusion at `shd_ΛI` from the slots' conclusions at the concrete layout.** -/
theorem shd_hLI_of_slots {nu : ℕ} (U : K) (tag : MTag) (h64 : 64 ≤ Lq) (P : InPublic shieldS0) (I : IncPub)
    (Epad : Fin P.V → (Fin 12 → Bool) → GF) (iB iA : ℕ)
    (hv : I.v = P.V) (hV : P.V ≤ 2 ^ 17) (htok : I.tokens = 128)
    (hcq : ∀ t : shieldS0.Tok, I.ctlQ t.val = decide (ctlPos P t = 1))
    (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB Lq → Option (List UInt8))
    (hdOf : StgVw Lq → IncHelpers K 12 17 nu)
    (G : QB Lq → Dig) (Lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ShdIncSlotsAt U key domain Pof hdrLen bgaOf absOf (shdIncDataK U tag h64 P I Epad iB iA)
      (fun v => shdIncLay U tag h64 P I Epad iB iA v hv hV htok hcq) hdOf G Lg τ) :
    StgLkAtV U key domain Pof 15 hdrLen bgaOf absOf (shd_ΛI U tag h64 P I Epad iB iA) G Lg τ :=
  stgLkAtV_of_luIn U key domain Pof hdrLen bgaOf absOf (shdIncData U tag h64 P I Epad iB iA) G Lg τ
    (shdLuInAt_of_K U tag h64 P I Epad iB iA key domain Pof hdrLen bgaOf absOf G Lg τ
      (shdLuInAtK_of_slots U key domain Pof hdrLen bgaOf absOf _ _ hdOf G Lg τ h))

end Slots

end ZK60.ProtocolClassify
