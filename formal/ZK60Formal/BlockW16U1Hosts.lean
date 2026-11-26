/-
D63 W16R2 Shieldstral port, Item (5e) (`BlockW16U1Hosts.lean`):
**all six hosts' named identities joined at `export_u1` (`SC_TZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`,
`SC_SZC`, `SC_FZC`)**:

* `xcU1`, `pwcU1`: the batch entries past the named clauses and the pad planes (`19` at `SC_DZC`,
  `9` at `SC_FZC`), defined across all six hosts;
* `dtU1_cl_xc`: a host's batch entry at index `κ ≥ relCount k` is `xcU1`;
* **`formAt_hosts_u1`**: on every accepting outcome of a W16R2 Shieldstral (`export_u1`) layer
  `Ly ∈ shieldExportU1`, all six hosts (`k ∈ algHosts`) satisfy `FormAt` for `dtU1` at `xtU1`,
  `xcU1`, `pwcU1`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1HostTzc
import ZK60Formal.BlockW16U1HostDzc
import ZK60Formal.BlockW16U1HostQkv
import ZK60Formal.BlockW16U1HostSzc
import ZK60Formal.BlockW16U1HostFzc

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H (LayR PubR PrecR)
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn)
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.RunShape.ShieldU1 (shieldExportU1)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## 1. The batch entries past the named clauses (`xcU1`) and the pad planes (`pwcU1`) -/

section Data

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
  (Dof : Cuts3 L → RootsO → CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- **The batch entries past the named clauses, per host at `export_u1`**:
LogUp helper relations (`SC_DZC` 6..15, `SC_QZC` 1..3, `SC_KVZC` 1..3, `SC_SZC` 4..7,
`SC_FZC` 2..5), `SC_SZC`'s exp helper (`8`), and `SC_FZC`'s ACT helper (`1`). -/
noncomputable def xcU1 : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauU1 k) → Bool) → K
  | 14, cu, rt, bga, κ, b => Dzc.xcDzcU1 U P (Dof cu rt) Pb Lay B bga κ b
  | 15, cu, rt, bga, κ, b => Qkv.xcQzcU1 U P (Dof cu rt) Pb Lay B bga κ b
  | 16, cu, rt, bga, κ, b => Qkv.xcKvzcU1 U P (Dof cu rt) Pb Lay B bga κ b
  | 17, cu, rt, bga, κ, b => Szc.xcSzcU1 U P (Dof cu rt) Pb Lay B bga κ b
  | 18, cu, rt, bga, κ, b => Fzc.xcFzcU1 U P (Dof cu rt) Pb Lay B bga κ b
  | _, _, _, _, _, _ => 0

/-- **The pad planes, per host at `export_u1`**: `SC_DZC`'s 19 and `SC_FZC`'s 9 zero-rule planes
multiplied by `1 − supp`. -/
noncomputable def pwcU1 : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadU1 k) → (Fin (tauU1 k) → Bool) → K
  | 14, cu, rt, j, b => Dzc.pwDzcU1 U P (Dof cu rt) Pb Lay B j b
  | 18, cu, rt, j, b => Fzc.pwFzcU1 U P (Dof cu rt) Pb Lay B j b
  | _, _, _, _, _ => 0

/-- A host's batch entry past its named clauses (`relCount k ≤ κ`) is `xc`. -/
theorem dtU1_cl_xc (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws)
    (E : Cuts3 L → RootsO → W16Data CtU1 CwU1 CgU1 CjU1 CdU1 CfU1)
    (xc : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauU1 k) → Bool) → K)
    (pwc : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadU1 k) → (Fin (tauU1 k) → Bool) → K)
    (k : ℕ) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (κ : Fin (segLn ((algShapeU1 P hdr).dl k) .mu - segLn ((algShapeU1 P hdr).dl k) .zeta))
    (b : Fin (segLn ((algShapeU1 P hdr).dl k) .tau) → Bool)
    (hκ : relCount k ≤ (κ : ℕ)) :
    (dtU1 Pb Lay B P hdr E xc pwc).cl k cu rt bga κ b = xc k cu rt bga κ b := by
  show (if (κ : ℕ) < relCount k then _ else _) = _
  rw [ite_eq_right (by omega)]

end Data

/-! ## 2. All six hosts' `FormAt` at `export_u1` -/

section Hosts

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}
variable {S : ZK60.Block.BlockShape}

/-- **All six hosts' named identities (`SC_TZC`, `SC_DZC`, `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`)
at `export_u1`**, on every accepting outcome for any `(cnA, cnM)` below `2^63` and `PrecR (cfgU1 cnA cnM) S`. -/
theorem formAt_hosts_u1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (cnA cnM : ℕ) (hcnA : cnA < 2 ^ 63) (hcnM : cnM < 2 ^ 63)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (A : OC (QB L) Dig (List Op × Core))
    (hS : PrecR (cfgU1 cnA cnM) S) (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeU1 P hP.hdr)
          (dtU1 Pb Lay B P hP.hdr
            (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
            (xcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B)
            (pwcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B))
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k := by
  intro G bga rs acc hT k hk
  have hrl : 0 < rowLog P .a := by show 0 < P.logCols; rw [hlc]; norm_num
  have hX := dXof_base_w16U1 (K := K) tag hL20 P hlc rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)
  have hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws
      = .ok df ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ []) := fun j r hr => by
    obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
      rs acc hT j r hr
    exact ⟨df, hdf, hkind⟩
  simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
  · exact Tzc.formAt_tzcU1 U (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM ioIn ioOut pubs hdef _ hX hrl hS hLay
      hpub _ _ _
      (fun bga κ t => by
        show (if (κ : ℕ) < relCount 2 then _ else _) = _
        rw [ite_eq_left (by have := κ.isLt; show (κ : ℕ) < 6; omega)]
        rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Dzc.formAt_dzcU1 U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM hcnA hcnM ioIn ioOut pubs hdef _ hX
      hrl hS hLay hpub _ _ _
      (fun bga κ b => by show (if (κ : ℕ) < relCount 14 then _ else _) = _; rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_qzcU1 U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM ioIn ioOut pubs hdef _ hX hrl hS hLay
      hpub _ _ _
      (fun bga κ b => by show (if (κ : ℕ) < relCount 15 then _ else _) = _; rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_kvzcU1 U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM ioIn ioOut pubs hdef _ hX hrl hS hLay
      hpub _ _ _
      (fun bga κ b => by show (if (κ : ℕ) < relCount 16 then _ else _) = _; rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Szc.formAt_szcU1 U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM ioIn ioOut pubs hdef _ hX hrl hS hLay
      hpub _ _ _
      (fun bga κ b => by show (if (κ : ℕ) < relCount 17 then _ else _) = _; rfl)
      (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) (fun _ => rfl) rfl bga rs hslots
  · exact Fzc.formAt_fzcU1 U hU (card_K_gt K) Pb Lay B P hP.hdr hP.hsl cnA cnM ioIn ioOut pubs hdef _ hX hrl hS hLay
      hpub _ _ _
      (fun bga κ b => by show (if (κ : ℕ) < relCount 18 then _ else _) = _; rfl)
      (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots

/-- Specialization of `formAt_hosts_u1` to any layer `Ly ∈ shieldExportU1`. -/
theorem formAt_hosts_shieldU1 (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1)
    (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
    (hlc : P.logCols = 14) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub (shieldShape Ly) Pb Lay)
    (A : OC (QB L) Dig (List Op × Core))
    (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      ∀ k ∈ algHosts, FormAt U P
        ((polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
          (DefW16.progW16 (cfgU1 Ly.cnA Ly.cnM) ioIn ioOut) pubs)
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
        (fun k h => (algSp U (algShapeU1 P hP.hdr)
          (dtU1 Pb Lay B P hP.hdr
            (fun cu rt => xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt))
            (xcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B)
            (pwcU1 U P (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb Lay B))
          (card_K_gt K) 0 (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ)
        bga rs k :=
  formAt_hosts_u1 U hU key domain hs hL hL20 P tag rowsOf hP Ly.cnA Ly.cnM
    (Dzc.shieldExportU1_cn_lt Ly hLy).1 (Dzc.shieldExportU1_cn_lt Ly hLy).2 ioIn ioOut pubs hdef hlc hdrLen csE
    rE QE XE Pb Lay B A (precR_shieldU1 Ly hLy) hLay hpub

end Hosts

end ZK60.Exec.Block.Join.W16U1
