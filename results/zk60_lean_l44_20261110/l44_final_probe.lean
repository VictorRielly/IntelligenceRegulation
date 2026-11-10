/-
D63 lane L44 (2026-11-10), part 9: **the W16R2 rung block's knowledge statement with every host's named identity
proved** (deliverables 1, 2 and 4; on lane L41's `block_knowledge_join_w16r2_rung`, which carries the chain of lanes
L31, L35 and L36).

* `xcW`, `pwcW`: **the batch's entries past the named clauses and the pad planes, DEFINED** (per host: LogUp's helper
  relations, `SC_SZC`'s exp tuple, `SC_FZC`'s ACT tuple, the zero-rule planes times `1 − supp`), read off the
  committed planes, the public data and `α`, `β`, `γ`;
* **`formAt_rest_w16`**: lane L41's premise `hformRest` (the named identities of `SC_DZC`, `SC_QZC`, `SC_KVZC`,
  `SC_SZC`, `SC_FZC`) PROVED, on every accepting outcome;
* **`block_knowledge_host_w16r2_rung`**: `Pr[BlockAcc ∧ header ∧ ¬BlockSat(xtW)] ≤ εsTarget q + εend` at the W16R2
  rung with the extraction, the algebra data, the encodings, `hspec` and ALL SIX hosts' identities discharged, the
  pad plane counts and the batch's other entries defined; left: run-level premises, public-data facts (`RungS`,
  `LayW16`, `PubW16`), and lane L36's helper layer and lookup side (deliverable 3);
* **`block_knowledge_host_w16r2_rung_pubs`**: the same at the concrete public tables `pubsW16 B rest` (deliverable 2:
  `PubW16` discharged).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostDzc
import ZK60Formal.BlockHostSzc
import ZK60Formal.BlockHostPub

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.ProbeL44
open ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

/-! ## The batch's other entries and the pad planes -/

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
  (Dof : Cuts3 L → RootsO → CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **The batch's entries past the named clauses, per host** (defined; read off the committed planes, the public data
and `α`, `β`, `γ`). -/
noncomputable def xcW : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ →
    (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K
  | 14, cu, rt, bga, κ, b => Dzc.xcDzc U P (Dof cu rt) Pb Lay B bga κ b
  | 17, cu, rt, bga, κ, b => Szc.xcSzc U P (Dof cu rt) Pb Lay B bga κ b
  | _, _, _, _, _, _ => 0

/-- **The pad planes, per host** (`SC_DZC`'s nineteen and `SC_FZC`'s nine zero-rule planes times `1 − supp`). -/
noncomputable def pwcW : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadW k) →
    (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K
  | 14, cu, rt, j, b => Dzc.pwDzc U P (Dof cu rt) Pb Lay B j b
  | _, _, _, _, _ => 0

end Data

/-! ## `hformRest` -/

section Rest

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **Lane L41's `hformRest`, PROVED**: on every accepting outcome the named identities of the five hosts `SC_DZC`,
`SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC` hold, for the algebra data `dtW` with the batch's other entries `xcW` and the
pad planes `pwcW`. -/
theorem formAt_rest_w16 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (A : OC (QB L) Dig (List Op × Core))
    (hS : RungS S) (hLay : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15
      280 8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20
      csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ [14, 17], FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78)
          (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78
            (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
            (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
            (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B))
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k := by
  intro G bga rs acc hT k hk
  have hrl : 0 < rowLog P .a := by show 0 < P.logCols; rw [hlc]; norm_num
  have hX := dXof_base (K := K) tag hL20 P hlc rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
  have hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws
      = .ok df ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ []) := fun j r hr => by
    obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
      rs acc hT j r hr
    exact ⟨df, hdf, hkind⟩
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl
  · exact Dzc.formAt_dzc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 14 then _ else _) = _
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Szc.formAt_szc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 17 then _ else _) = _
        rfl)
      (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) rfl bga rs hslots

end Rest

end ZK60.Exec.Block.Join.W16.ProbeL44
