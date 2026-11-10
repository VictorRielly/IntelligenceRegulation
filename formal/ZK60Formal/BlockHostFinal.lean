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
import ZK60Formal.BlockHostQkv
import ZK60Formal.BlockHostSzc
import ZK60Formal.BlockHostFzc
import ZK60Formal.BlockHostPub
import ZK60Formal.BlockLkGd

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

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
  | 15, cu, rt, bga, κ, b => Qkv.xcQzc U P (Dof cu rt) Pb Lay B bga κ b
  | 16, cu, rt, bga, κ, b => Qkv.xcKvzc U P (Dof cu rt) Pb Lay B bga κ b
  | 17, cu, rt, bga, κ, b => Szc.xcSzc U P (Dof cu rt) Pb Lay B bga κ b
  | 18, cu, rt, bga, κ, b => Fzc.xcFzc U P (Dof cu rt) Pb Lay B bga κ b
  | _, _, _, _, _, _ => 0

/-- **The pad planes, per host** (`SC_DZC`'s nineteen and `SC_FZC`'s nine zero-rule planes times `1 − supp`). -/
noncomputable def pwcW : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadW k) →
    (Fin (segLn (ZK60.Exec.Slot.W16R2.draws shRungW16 k) .tau) → Bool) → K
  | 14, cu, rt, j, b => Dzc.pwDzc U P (Dof cu rt) Pb Lay B j b
  | 18, cu, rt, j, b => Fzc.pwFzc U P (Dof cu rt) Pb Lay B j b
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
      ∀ k ∈ [14, 15, 16, 17, 18], FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
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
  rcases hk with rfl | rfl | rfl | rfl | rfl
  · exact Dzc.formAt_dzc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 14 then _ else _) = _
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_qzc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 15 then _ else _) = _
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_kvzc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 16 then _ else _) = _
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Szc.formAt_szc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 17 then _ else _) = _
        rfl)
      (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) rfl bga rs hslots
  · exact Fzc.formAt_fzc U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef _ hX hrl hS hLay hpub _ _ _
      (fun bga κ b => by
        show (if (κ : ℕ) < relCount 18 then _ else _) = _
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots

/-- **All six hosts' named identities** (`SC_TZC` by lane L41's `formAt_tzc`, the five others by
`formAt_rest_w16`), on every accepting outcome. -/
theorem formAt_hosts_w16 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
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
      ∀ k ∈ algHosts, FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78)
          (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78
            (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
            (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
            (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B))
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k := by
  intro G bga rs acc hT k hk
  by_cases h2 : k = 2
  · subst h2
    have hrl : 0 < rowLog P .a := by show 0 < P.logCols; rw [hlc]; norm_num
    exact formAt_tzc U (card_K_gt K) Pb Lay B P hP.hdr hP.hsl ioIn ioOut pubs hdef
      (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
      (dXof_base tag hL20 P hlc rE QE XE _ _) hrl hLay.tok hS.ceps hpub.ssGate mpadW mpadW_hm0 mpadW_hm78 _ _ _
      (fun bga κ t => by
        show (if (κ : ℕ) < relCount 2 then _ else _) = _
        rw [ite_eq_left (by have := κ.isLt; show (κ : ℕ) < 6; omega)]
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs
      (fun j r hr => by
        obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
          rs acc hT j r hr
        exact ⟨df, hdf, hkind⟩)
  · exact formAt_rest_w16 U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hdrLen csE rE QE XE Pb Lay
      B A hS hLay hpub G bga rs acc hT k (by
        simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
        simp only [List.mem_cons, List.not_mem_nil, or_false]
        omega)

end Rest

/-! ## The statement -/

section Final

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **The W16R2 rung block's knowledge statement with every host's named identity proved** (deliverables 1 and 4):
over lane L41's statement, `hformRest` is gone (`formAt_rest_w16`), the pad plane counts `mpad := mpadW` and the
batch's other entries `xc := xcW`, `pwc := pwcW` are DEFINED, and the public-data facts are collected as `LayW16`
(the axes that do not pad, the RoPE flip) and `PubW16` (the verifier's public tables). -/
theorem block_knowledge_host_w16r2_rung [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : W16Widths S fams) (h24 : S.h24 = true)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data facts: the shape's constants, the layout, the verifier's public tables
    (hS : RungS S) (hLay : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    -- the helper layer and LogUp (lane L36's premises; deliverable 3)
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_join_w16r2_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hep
    hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B fams hF hW h24 q A hA εend hEnd hS hLay.tok hLay.hd hpub.ssGate
    mpadW mpadW_hm0 mpadW_hm78
    (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
    (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)
    (formAt_rest_w16 U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hdrLen csE rE QE XE Pb Lay B A
      hS hLay hpub)
    HGd spH hdgH hformH hgdH Alk T mlk hN he hTtab hcov hhr

/-- **Deliverable 2 joined: the same statement at the concrete public tables** `pubsW16 B rest` (every table the hosts
read built from the public data `B`; `PubW16` discharged by `pubW16_of`). -/
theorem block_knowledge_host_w16r2_rung_pubs [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (ioIn ioOut : ℕ) (rest : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B rest))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : W16Widths S fams) (h24 : S.h24 = true)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data facts: the shape's constants, the layout, the verifier's public tables
    (hS : RungS S) (hLay : LayW16 Lay)
    -- the helper layer and LogUp (lane L36's premises; deliverable 3)
    (HGd : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → Prop)
    (spH : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k))
    (hdgH : ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spH cu rt k h).dg ≤ 80)
    (hformH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B rest))) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ w16r2RelKs 0, FormAt U P ((polyXof U tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B rest)) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (spH (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs k)
    (hgdH : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B rest))) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      SchedGd (w16r2DH P spH 0) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (pubsW16 Pb Lay B rest))) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGd (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_host_w16r2_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut (pubsW16 Pb Lay B rest)
    hdef hlc hep hdrLen hdrSq hh hq csE rE QE XE hcsE Pb Lay B fams hF hW h24 q A hA εend hEnd hS hLay
    (pubW16_of Pb Lay B U hU rest) HGd spH hdgH hformH hgdH Alk T mlk hN he hTtab hcov hhr

/-- **Deliverable 3 joined: the statement with the helper layer discharged** (`HGd := Lk.HGdW`, `spH := Lk.spHW`;
`hdgH`, `hformH`, `hgdH` PROVED, BlockLk*.lean), except `SC_TAB`'s polynomial `spT` and its named identity `hTform`;
new premises: the slot kinds `hk3`, `hk20` (MEASURED against the code's `SLOT_KINDS`) and `SC_LZC`'s, `SC_ZS`'s public
tables (`hgate`, `hones`); left: the lookup side and `hhr`. -/
theorem block_knowledge_host_w16r2_rung_helper [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (fams : List (ℕ × ℕ)) (hF : ZK60.Circuit.FamsOK fams) (hW : W16Widths S fams) (h24 : S.h24 = true)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungW16 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    -- public-data facts: the shape's constants, the layout, the verifier's public tables
    (hS : RungS S) (hLay : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    -- the helper layer: SC_TAB's certified polynomial and named identity, the slot kinds, SC_LZC's and SC_ZS's public
    -- tables (deliverable 3, BlockLk*.lean)
    (gL : (Fin 14 → Bool) → GF)
    (spT : Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → SlotPoly K (P.draws 19))
    (hTdeg : ∀ cu rt bga, (spT cu rt bga).dg ≤ 80)
    (hTform : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      FormAt U P (polyS U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2)) (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
        (fun k h => (Lk.spXW U (card_K_gt K) P hP.hdr (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT (cutsOf key domain hs hL A G)
          (rootsOf (A.run G).2) k h).Φ) bga rs 19)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (hones : ∀ hist dr (b : Fin 14 → Bool), ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    -- the lookup side (lane L36's premises; the helper predicate is Lk.HGdW)
    {ι π κ : Type} [Fintype ι] [Fintype π] [Fintype κ]
    (Alk : List (QB L × Dig) → ι ⊕ (π ⊕ π) → Tup K) (T : κ → Tup K) (mlk : List (QB L × Dig) → κ → K)
    (hN : Fintype.card ι + 2 * Fintype.card π < ringChar K)
    (he : Fintype.card ι + 2 * Fintype.card π + 2 * (Finset.univ.image T).card ≤ 35153256)
    (hTtab : ∀ j, ∃ t0, ZK60.Circuit.CodeTable fams Pb.exp Pb.act S.nG t0 ∧ T j = tupK t0)
    (hcov : ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, Alk (cutsOf key domain hs hL A G).1 l = tupK q)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280
      8052 320 202 rE QE XE (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)) (Link.csRungW16 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      Lk.HGdW U P (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78)
        (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel (fun l => fold (bga.1.toK U) (bga.2.1.toK U) (Alk (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (T j)) (mlk (cutsOf key domain hs hL A G).1) (bga.2.2.toK U)
          Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X (Lay.dPos p))
          (fun p => (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2))).X2 (Lay.dPos p))
          (toWit Lay (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
            (rootsOf (A.run G).2)))))
      ≤ εsTarget q + εend :=
  block_knowledge_host_w16r2_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hep hdrLen
    hdrSq hh hq csE rE QE XE hcsE Pb Lay B fams hF hW h24 q A hA εend hEnd hS hLay hpub
    (Lk.HGdW U P (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78) (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)) (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT)
    (Lk.spHW U (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78) (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)) (card_K_gt K) (Lk.spXW U (card_K_gt K) P hP.hdr (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT))
    (Lk.helper_dg U (card_K_gt K) P hP.hdr (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78) (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)) (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT hTdeg)
    (fun G bga rs acc hT => Lk.helper_formAt U (card_K_gt K) P hP.hdr (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78) (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)) (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT hU hP.hsl ioIn ioOut pubs
      (by show 0 < P.logCols; rw [hlc]; norm_num) hk3 hk20 hgate hones _ _ bga rs
      (formAt_hosts_w16 U hU key domain hs hL hL20 P tag rowsOf hP ioIn ioOut pubs hdef hlc hdrLen csE rE QE XE Pb Lay
        B A hS hLay hpub G bga rs acc hT)
      (hTform G bga rs acc hT))
    (fun G bga rs acc _ hG => Lk.hgd_of U (card_K_gt K) P hP.hdr (algShapeW16Rung P hP.hdr mpadW mpadW_hm0 mpadW_hm78) (dtW Pb Lay B P hP.hdr mpadW mpadW_hm0 mpadW_hm78 (fun cu rt => xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt))
        (xcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B) (pwcW U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) Pb Lay B)) (fun cu rt => dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE cu rt) gL spT _ _ bga rs hG)
    Alk T mlk hN he hTtab hcov hhr

end Final

end ZK60.Exec.Block.Join.W16
