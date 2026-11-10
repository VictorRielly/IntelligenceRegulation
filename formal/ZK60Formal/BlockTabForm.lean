/-
D63 lane L47 (2026-11-10), part 4: **`SC_TAB`'s named identity at the W16R2 rung** (deliverable 1: L44's premises
`spT`, `hTdeg`, `hTform` of `block_knowledge_host_w16r2_rung_helper`).

* **`tab_formAt`**: `spTabW` (BlockTabBase.lean) meets lane L36's `FormAt` at slot `19`, for a verifier whose slot `19` is
  standalone (the code's `SLOT_KINDS`, L44-K1), on the concrete public tables `pubsW16 B (restW16 Pb nG)`, on every
  outcome;
* **`hTdeg_w16`**: `hTdeg`, the certified polynomial's degree `24 ≤ 80`;
* **`hTform_w16`**: `hTform` in the exact form of `block_knowledge_host_w16r2_rung_helper`, at
  `spT := spTabW … (dXof … cu rt) Pb S.nG`, `gL := gateLW`, `pubs := pubsW16 Pb Lay B (restW16 Pb S.nG)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockTabSlot
import ZK60Formal.BlockHostFinal

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Tab

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF)
open ZK60.Layout

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_TAB`'s standalone named identity** at slot `19`: a polynomial family whose value at slot `19` is `spTabW`'s
at the history's `(β, γ, α)` meets `FormAt` there, for a verifier whose slot `19` is standalone, on the public tables
`pubsW16 B (restW16 Pb nG)`. -/
theorem tab_formAt (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots) (ioIn ioOut : ℕ)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay) (nG : ℕ) (D : CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hkind : P.kind 19 = SlotKind.standalone) (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 19 hist x = (spTabW U hcard P hdr D Pb nG (hist.beta, hist.gamma, hist.alpha)).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb nG))) Φ bga rs 19 := by
  intro r df hr _
  refine Or.inl ⟨hkind, ?_⟩
  rw [hΦ]
  have hs19 : slotShape P 19 = (14, 1, 3) := by
    simp only [slotShape, hsl]
    decide
  unfold spSum
  rw [tab_cube U hU P D hrlA hrlH Pb Lay B nG (histOf bga.1 bga.2.1 bga.2.2 (rs.take 19)) r.draws
    (slotShape P 19).1 (slotShape P 19).2.1 (by rw [hs19]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 19 r hr x]; simp only [slot19_eq])]
  rfl

/-- **`hTdeg`**: `SC_TAB`'s certified polynomial has degree `24 ≤ 80`. -/
theorem hTdeg_w16 (U : K) (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) {L : ℕ}
    (Dof : Cuts3 L → RootsO → CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) :
    ∀ cu rt bga, (spTabW U (card_K_gt K) P hdr (Dof cu rt) Pb nG bga).dg ≤ 80 := by
  intro cu rt bga
  rw [spTabW_dg]
  norm_num

/-- **`hTform`** of `block_knowledge_host_w16r2_rung_helper`, PROVED at `spT := spTabW`, `gL := gateLW` and the concrete
public tables `pubsW16 Pb Lay B (restW16 Pb S.nG)`, given that the verifier's slot `19` is standalone. -/
theorem hTform_w16 {L : ℕ} (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf) (ioIn ioOut : ℕ)
    (hlc : P.logCols = 14) (hdrLen : ℕ) (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay) (A : OC (QB L) Dig (List Op × Core)) (hk19 : P.kind 19 = SlotKind.standalone) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG))))
      (Link.csRungW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      FormAt U P (polyS U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B (restW16 Pb S.nG)))
        (fun k h => (Lk.spXW U (card_K_gt K) P hP.hdr
          (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gateLW
          (fun cu rt bga => spTabW U (card_K_gt K) P hP.hdr (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)
            Pb S.nG bga)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs 19 := by
  intro G bga rs acc _
  have hrl : 0 < P.logCols := by rw [hlc]; norm_num
  exact tab_formAt U hU (card_K_gt K) P hP.hdr hP.hsl ioIn ioOut Pb Lay B S.nG _ hrl hrl hk19 _ (fun _ _ => rfl) bga rs

end Form

end ZK60.Exec.Block.Join.W16.Tab
