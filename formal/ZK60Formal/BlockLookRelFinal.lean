/-
D63 lane L47 (2026-11-10), part 8 (fork C): **lane L36's `hhr` at the W16R2 rung, PROVED** (deliverable 2).

* `AlkW_real`, `mlkW_real`: the lookups and multiplicities the `A` cut fixes are the real data's (`dofA_aPl`);
* **`hhr_core`**: on any committed data `D`, at canonical `α`, `β`, if every host's LogUp entries, `SC_LZC`'s relation,
  `SC_TAB`'s relations vanish and the code's sum claim and `H_U`'s sum are `0`, the `H` planes are helpers satisfying
  every relation of `HelperRel` for `AlkW`, `TW`, `mlkW`;
* **`hhr_w16`**: lane L36's `hhr` in the exact form of `block_knowledge_host_w16r2_rung_helper`'s premise (with
  `gL := gateLW`, `spT := spTabW`), from `AccT` and `Lk.HGdW`, given the verifier fact
  `hls : P.logupSumClaim = DefW16.logupSumW16 DefW16.cfgRungW16`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookRelW16

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.Join.W16.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn shRungW16)
open ZK60.Circuit (gP GF tagW)
open ZK60.Layout

section Core

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`HelperRel` from the vanishing relations, the sum claim and `H_U`'s sum**, on any committed data. -/
theorem hhr_core (P : BlockParams) (D : CmData K P) (hln : rowLog P .h = 14) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay) (nG : ℕ)
    (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon) (hβ : bga.1.Canon)
    (hD : ∀ κ, 6 ≤ κ → κ < 16 → ∀ b, Dzc.xcDzc U P D Pb Lay B bga κ b = 0)
    (hQ : ∀ κ, 1 ≤ κ → κ < 4 → ∀ b, Qkv.xcQzc U P D Pb Lay B bga κ b = 0)
    (hK : ∀ κ, 1 ≤ κ → κ < 4 → ∀ b, Qkv.xcKvzc U P D Pb Lay B bga κ b = 0)
    (hS : ∀ κ, 4 ≤ κ → κ < 10 → ∀ b, Szc.xcSzc U P D Pb Lay B bga κ b = 0)
    (hF : ∀ κ, 1 ≤ κ → κ < 6 → ∀ b, Fzc.xcFzc U P D Pb Lay B bga κ b = 0)
    (hLz : ∀ b, Lk.cLzc U P D gateLW bga b = 0) (hT : ∀ k b, cTabW U P D Pb nG bga k b = 0)
    (hcl : Link.claimSem U (D.rows .h) (rowLog P .h) (D.Q .h) (D.X .h) (logupSumW16 cfgRungW16) = 0)
    (hzs : ∑ b : Fin 14 → Bool, hPl U P D 1736704 1753088 14 b = 0)
    (Alk : SgIx ⊕ (PrIx ⊕ PrIx) → Tup K) (hA : ∀ l, Alk l = AlkW (L := 0) U P Pb Lay B (fun _ => D) [] l)
    (m : TbIx → K) (hm : ∀ j, m j = mlkW (L := 0) U P (fun _ => D) [] j) :
    ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (Alk l))
      (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TW Pb nG j)) m (bga.2.2.toK U) Hh := by
  refine ⟨⟨fun i => hPl U P D (hOff cfgRungW16 i.1.hp).1 (hOff cfgRungW16 i.1.hp).2 i.1.log i.2,
      fun k => hPl U P D (hOff cfgRungW16 (k.1.fh + k.2.1)).1 (hOff cfgRungW16 (k.1.fh + k.2.1)).2 k.1.log k.2.2,
      fun j => helpTabW U P D j.1 j.2⟩, ?_, ?_, ?_, ?_⟩
  · rintro ⟨s, b⟩
    show _ * (_ - ZK60.Sound.fold _ _ (Alk (.inl ⟨s, b⟩))) = 1
    rw [hA]
    cases s
    · exact relD_single U P D Pb Lay B bga hα b (hD 15 (by omega) (by omega) b)
    · exact relS_single U P D Pb Lay B bga hα b (hS (4 + 4) (by omega) (by omega) b)
    · exact relF_single U P D Pb Lay B bga hα b (hF (2 + 3) (by omega) (by omega) b)
    · exact relExp U P D Pb Lay B bga hα hβ b (hS 9 (by omega) (by omega) b)
    · exact relAct U hU P D Pb Lay B bga hα hβ b (hF 1 (by omega) (by omega) b)
  · rintro ⟨d, j, b⟩
    unfold pairFst pairSnd
    show _ * ((_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
      * (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩)))))
      = (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inl ⟨d, j, b⟩))))
        + (_ - ZK60.Sound.fold _ _ (Alk (.inr (.inr ⟨d, j, b⟩))))
    rw [hA, hA]
    have hj := j.isLt
    cases d
    · have hj0 : (j : ℕ) = 0 := by
        change (j : ℕ) < 1 at hj
        omega
      obtain ⟨j, hj'⟩ := j
      simp only at hj0
      subst hj0
      exact relL_pair U P D bga hα gateLW b (hLz b)
    · exact relD_pair U P D Pb Lay B bga hα b j (by change (j : ℕ) < 9 at hj; exact hj)
        (hD (6 + j) (by omega) (by change (j : ℕ) < 9 at hj; omega) b)
    · exact relQ_pair U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hQ (1 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
    · exact relK_pair U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hK (1 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
    · exact relS_pair U P D Pb Lay B bga hα b j (by change (j : ℕ) < 4 at hj; exact hj)
        (hS (4 + j) (by omega) (by change (j : ℕ) < 4 at hj; omega) b)
    · exact relF_pair U P D Pb Lay B bga hα b j (by change (j : ℕ) < 3 at hj; exact hj)
        (hF (2 + j) (by omega) (by change (j : ℕ) < 3 at hj; omega) b)
  · rintro ⟨k, b⟩
    rw [hm]
    have h := hT k b
    unfold cTabW at h
    show helpTabW U P D k b * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
      (tupK (tabTupW Pb nG k (msbIndex 14 b)))) = multTabW U P D k b
    linear_combination h
  · exact hhr_sum U hU P D hln hcl hzs

end Core

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Lane L36's `hhr` at the W16R2 rung** (`block_knowledge_host_w16r2_rung_helper`'s premise, with `gL := gateLW`,
`spT := spTabW`, `Alk := AlkW`, `T := TW`, `mlk := mlkW`): on every accepting outcome whose helper-layer start claims
hold, the committed `H` planes are helpers satisfying every relation and the sum of `HelperRel`. -/
theorem hhr_w16 [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig)
    (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hls : P.logupSumClaim = DefW16.logupSumW16 DefW16.cfgRungW16) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      Lk.HGdW U P (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78)
        (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78
          (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
          (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
          (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gateLW
        (fun cu rt bga => spTabW U (card_K_gt K) P hP.hdr (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt)
          Pb S.nG bga)
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
            (cutsOf key domain hs hL A G).1 l))
        (fun j => ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) (TW Pb S.nG j))
        (mlkW U P (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
          (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh := by
  intro G bga rs acc hT hG
  obtain ⟨hα, hβ⟩ := bga_canon_of_accT U key domain hs hL P hP.hsl _ pubs hdef hdrLen _ _ _ A G bga rs acc hT
  obtain ⟨hHost, hLz, hTab, hHU⟩ := hG
  have hx : ∀ k, k ∈ algHosts → ∀ κ (hκ : κ < segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .mu
      - segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .zeta), relCount k ≤ κ →
      ∀ b : Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool,
        xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B k
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga κ b = 0 := by
    intro k hk κ hκ hr b
    have e := (hHost k hk).1 ⟨κ, hκ⟩ b
    rwa [dtW_cl_xc Pb Lay B P hP.hdr _ _ _ k _ _ bga ⟨κ, hκ⟩ b hr] at e
  have hD := fun κ (h1 : 6 ≤ κ) (h2 : κ < 16) (b : Fin 14 → Bool) =>
    hx 14 (by decide) κ (by show κ < 16; exact h2) (by show 6 ≤ κ; exact h1) b
  have hQ := fun κ (h1 : 1 ≤ κ) (h2 : κ < 4) (b : Fin 15 → Bool) =>
    hx 15 (by decide) κ (by show κ < 4; exact h2) (by show 1 ≤ κ; exact h1) b
  have hK := fun κ (h1 : 1 ≤ κ) (h2 : κ < 4) (b : Fin 14 → Bool) =>
    hx 16 (by decide) κ (by show κ < 4; exact h2) (by show 1 ≤ κ; exact h1) b
  have hS := fun κ (h1 : 4 ≤ κ) (h2 : κ < 10) (b : Fin 14 → Bool) =>
    hx 17 (by decide) κ (by show κ < 10; exact h2) (by show 4 ≤ κ; exact h1) b
  have hF := fun κ (h1 : 1 ≤ κ) (h2 : κ < 6) (b : Fin 15 → Bool) =>
    hx 18 (by decide) κ (by show κ < 6; exact h2) (by show 1 ≤ κ; exact h1) b
  have hcl0 := hT.2.1.2.2
  rw [hls] at hcl0
  have hcl : Link.claimSem U ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
      (rootsOf (A.run G).2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).Q .h) ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X .h) (logupSumW16 cfgRungW16) = 0 := by
    have e : Link.claimSem U ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)).rows .h) (rowLog P .h) ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).Q .h) ((dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)).X .h) (logupSumW16 cfgRungW16)
        = Link.csRungW16 U tag hL20 csE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) .h
          (logupSumW16 cfgRungW16) :=
      claimSem_cast14 U 202 280 P.logCols hlc
        (Link.xHof tag L (Link.le64_of_le20 hL20) 15 280 8052 202 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        _
    exact e.trans (hcl0.trans (Fp2.toK_zero U))
  have hTab' : (∀ k b, cTabW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
      (rootsOf (A.run G).2)) Pb S.nG bga k b = 0) ∧ ∀ j b, wTabW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) S.nG j b = 0 := hTab
  have hfun : aPl U P (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A
      (cutsOf key domain hs hL A G).1)
      = aPl U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) := by
    funext off log b
    exact dofA_aPl U key domain hs hL tag hL20 P hlc rE QE XE A G off log b
  refine hhr_core U hU P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
    (rootsOf (A.run G).2)) (show P.logCols = 14 from hlc) Pb Lay B S.nG bga hα hβ hD hQ hK hS hF hLz.1 hTab'.1 hcl
    hHU _ (fun l => ?_) _ (fun j => ?_)
  · rcases l with ⟨s, b⟩ | ⟨d, j, b⟩ | ⟨d, j, b⟩
    · cases s <;> (simp only [AlkW, sgTupW, lkAtW, lkTupW, expTupW, actTupW]; rw [hfun])
    · simp only [AlkW, lkAtW, lkTupW]
      rw [hfun]
    · simp only [AlkW, lkAtW, lkTupW]
      rw [hfun]
  · simp only [mlkW, multTabW]
    rw [hfun]

end Final

end ZK60.Exec.Block.Join.W16.Look
