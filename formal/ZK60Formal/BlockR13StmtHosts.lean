/-
D63 lane L49 (2026-11-10), part 6: **the six R13 hosts' named identities, assembled, and the R13 block statements with
`hform` discharged** (the R13 counterpart of lane L44's `xcW`, `pwcW`, `formAt_hosts_w16`), at the R13 rung and at every
layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block (at the layer's own shape `shieldShape Ly`).

* `xcR`, `pwcR`: **the batch's entries past the named clauses and the pad planes, DEFINED** per host (the host
  sub-agents' `xcTzcR` (none), `xcDzcR`, `xcQzcR`, `xcKvzcR`, `xcSzcR`, `xcFzcR`, `pwDzcR`, `pwFzcR`: LogUp's helper
  relations, `SC_SZC`'s exp tuple, `SC_FZC`'s ACT tuple, the zero-rule planes times `1 − supp`);
* **`formAt_hostsR`**: lane L36's `hform` at all six hosts, generic in the configuration, for the algebra data `dtR`
  with `xcR`, `pwcR` (`formAt_tzcR`, `formAt_dzcR`, `formAt_qzcR`, `formAt_kvzcR`, `formAt_szcR`, `formAt_fzcR`);
* **`block_knowledge_hosts_r13_rung`**, **`block_knowledge_hosts_r13_shield`**: `BlockR13StmtLook.lean`'s statements with
  `hform`, `xc`, `pwc` gone. The public tables' facts `PubR` are PROVED (`pubR_of_L`), the precision `PrecR` from
  `RungS` at the rung and by definition at every layer, the hosts' configurations PROVED at both.

Left: the slot kinds `hk3`, `hk19`, `hk20` (verifier premises) and LogUp's helper relations `hhr`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13StmtLook
import ZK60Formal.BlockR13HostTzcForm
import ZK60Formal.BlockR13HostDzc
import ZK60Formal.BlockR13HostQkvForm
import ZK60Formal.BlockR13HostQkvCfg
import ZK60Formal.BlockR13HostSzc
import ZK60Formal.BlockR13HostSzcCfg
import ZK60Formal.BlockR13HostFzcForm
import ZK60Formal.BlockR13HostFzcCfg

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H.Help
open ZK60.Exec.Block.Join.R13H.Look
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open scoped ENNReal

/-! ## The batch's other entries and the pad planes -/

section Xc

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) {L : ℕ}
  (Dof : Cuts3 L → RootsO → CmData K P) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- **The batch's entries past the named clauses, per host** (defined; read off the committed planes, the public data
and `α`, `β`, `γ`). -/
noncomputable def xcR : (k : ℕ) → Cuts3 L → RootsO → Fp2 × Fp2 × Fp2 → ℕ → (Fin (tauLen c k) → Bool) → K
  | 2, _, _, bga, κ, b => Tzc.xcTzcR c bga κ b
  | 14, cu, rt, bga, κ, b => Dzc.xcDzcR U G P (Dof cu rt) Pb Lay B bga κ b
  | 15, cu, rt, bga, κ, b => Qkv.xcQzcR U c P (Dof cu rt) bga κ b
  | 16, cu, rt, bga, κ, b => Qkv.xcKvzcR U c P (Dof cu rt) bga κ b
  | 17, cu, rt, bga, κ, b => Szc.xcSzcR U G P (Dof cu rt) B bga κ b
  | 18, cu, rt, bga, κ, b => Fzc.xcFzcR U G P (Dof cu rt) B bga κ b
  | _, _, _, _, _, _ => 0

/-- **The pad planes, per host** (`SC_DZC`'s 39 and `SC_FZC`'s 16 zero-rule planes times `1 − supp`). -/
noncomputable def pwcR : (k : ℕ) → Cuts3 L → RootsO → Fin (mpadR k) → (Fin (tauLen c k) → Bool) → K
  | 14, cu, rt, j, b => Dzc.pwDzcR U G P (Dof cu rt) Pb Lay B j b
  | 18, cu, rt, j, b => Fzc.pwFzcR U G P (Dof cu rt) B j b
  | _, _, _, _, _ => 0

end Xc

/-! ## `hform` at all six hosts -/

section Hosts

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}

/-- **Lane L36's `hform` at R13, PROVED, generic in the configuration**: on every outcome whose verified slots are
hosts exactly when their definitions host slots, the six hosts' named identities hold for the algebra data `dtR` with
the batch's other entries `xcR` and the pad planes `pwcR`. -/
theorem formAt_hostsR (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P)
    (htz : Tzc.TzcCfg c) (hdz : Dzc.DzcCfg c ls) (hqk : Qkv.QkvCfg c ls) (hsz : Szc.SzcCfg c ls)
    (hfz : Fzc.FzcCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (Dof : Cuts3 L → RootsO → CmData K P) (hX : ∀ cu rt i t, (Dof cu rt).X .a i t ∈ baseR K)
    (hrl : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hS : PrecR c S) (hW : ZK60.Layout.R13.R13Windows S ls) (hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (hpr : 0 < c.sh.perRow ∧ c.sh.perRow < gP)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    ∀ k ∈ algHosts, FormAt U P (polyS U P (Dof cu rt) (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc)
        (dtR G Pb Lay B P hc (fun cu rt => xtR U c P (Dof cu rt) ls) hpr (xcR U G P Dof Pb Lay B)
          (pwcR U G P Dof Pb Lay B)) hcard 0 cu rt k h).Φ) bga rs k := by
  intro k hk
  simp only [algHosts, List.mem_cons, List.not_mem_nil, or_false] at hk
  rcases hk with rfl | rfl | rfl | rfl | rfl | rfl
  · exact Tzc.formAt_tzcR U hU hcard Pb G Lay B P hc hpf htz ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hS hW
      hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Dzc.formAt_dzcR U hU hcard Pb G Lay B P hc hpf hdz ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hS hW
      hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_qzcR U hU hcard Pb G Lay B P hc hpf hqk ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hrlH hS
      hW hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Qkv.formAt_kvzcR U hU hcard Pb G Lay B P hc hpf hqk ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hrlH hS
      hW hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots
  · exact Szc.formAt_szcR U hU hcard Pb G Lay B P hc hpf hsz ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hS hW
      hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) (fun _ => rfl) (fun _ => rfl) rfl bga rs
      hslots
  · exact Fzc.formAt_fzcR U hU hcard Pb G Lay B P hc hpf hfz ioIn ioOut pubs hdef (Dof cu rt) (hX cu rt) hrl hS hW
      hLay hpub _ cu rt (fun _ _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) (fun _ _ => rfl) bga rs hslots

end Hosts

/-! ## The statements -/

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The R13 rung block's knowledge statement with every host's named identity proved**: left of the block-level
premises, LogUp's helper relations `hhr`; the verifier facts `hk3`, `hk19`, `hk20` (slot kinds); the public-data facts
`hS` (the rung's precision), `hLay`, `hnG`. -/
theorem block_knowledge_hosts_r13_rung {S : ZK60.Block.BlockShape} [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsRungR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S (CtR DefR13.cfgRungR13) (CwR DefR13.cfgRungR13) (CgR DefR13.cfgRungR13)
      (CjR DefR13.cfgRungR13) (CdR DefR13.cfgRungR13) (CfR DefR13.cfgRungR13))
    (B : W16Pub S Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
      (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csRungR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    (hS : W16.RungS S) (hLay : LayR Lay) (hnG : 0 < S.nG)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 437 248 rE QE XE (DefR13.progR13 DefR13.cfgRungR13 ioIn ioOut)
        (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG))) (Link.csRungR13 U tag hL20 csE)
      (Link.msRung U tag hL20) A G bga rs acc →
      HGdR U DefR13.cfgRungR13 P (algShapeR DefR13.cfgRungR13 P (shOk_rung P hP.hdr))
        (dtR geoRung Pb Lay B P (shOk_rung P hP.hdr)
          (fun cu rt => xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) 2)
          perRow_rung
          (xcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B)
          (pwcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) (Pub.gateLS DefR13.cfgRungR13.sh)
        Pb.exp Pb.act S.nG (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel
        (fun l => fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U DefR13.cfgRungR13 P Pb Lay B geoRung (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U) (TR13 (K := K) Pb.exp Pb.act S.nG j))
        (mlkR13 U DefR13.cfgRungR13 P (dofAR tag hL20 P hlc 16 256 24448 437 248 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X (Lay.dPos p))
          (fun p => (xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U DefR13.cfgRungR13 P (dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 2).toW16 S)))
      ≤ εsTarget q + εend :=
  block_knowledge_look_r13_rung U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef hlc hep
    hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hS hLay hnG
    (xcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B)
    (pwcR U geoRung P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt) Pb Lay B)
    (fun G bga rs acc hT => formAt_hostsR U hU (card_K_gt K) Pb geoRung Lay B P (shOk_rung P hP.hdr)
      (profR_rung P hP.hdr hP.hsl) Tzc.tzcCfg_rung Dzc.dzcCfg_rung Qkv.qkvCfg_rung Szc.szcCfg_rung Fzc.fzcCfg_rung
      ioIn ioOut (Pub.pubsR13L DefR13.cfgRungR13 Pb Lay B S.nG) hdef
      (fun cu rt => dXof tag hL20 P hlc 16 256 24448 437 248 rE QE XE cu rt)
      (fun cu rt => dXof_base_r13 tag hL20 P hlc 437 248 rE QE XE cu rt)
      (by show 0 < P.logCols; rw [hlc]; norm_num) (by show 0 < P.logCols; rw [hlc]; norm_num)
      (precR_rung hS) (windows_rung hS) hLay (Pub.pubR_of_L DefR13.cfgRungR13 Pb Lay B S.nG U hU) perRow_rung
      (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs
      (fun j r hr => by
        obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
          rs acc hT j r hr
        exact ⟨df, hdf, hkind⟩))
    hhr

/-- **One layer `Ly ∈ shieldExport` of the app's Shieldstral T128 R13 block, with every host's named identity
proved**, at the layer's own program, shape and calibration: left of the block-level premises, LogUp's helper relations
`hhr`; the verifier facts `hk3`, `hk19`, `hk20`; the layout facts `hLay`. -/
theorem block_knowledge_hosts_r13_shield [Fintype K] [DecidableEq K] (Ly : ZK60.RunShape.Shield.ShieldLayer)
    (hLy : Ly ∈ ZK60.RunShape.Shield.shieldExport) (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams)
    (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldR13 P tag rowsOf)
    (Pb : ZK60.Block.BlockPublic (ZK60.RunShape.Shield.shieldShape Ly))
    (Lay : W16Layout (ZK60.RunShape.Shield.shieldShape Ly) (CtR (DefR13.cfgShieldR13 Ly))
      (CwR (DefR13.cfgShieldR13 Ly)) (CgR (DefR13.cfgShieldR13 Ly)) (CjR (DefR13.cfgShieldR13 Ly))
      (CdR (DefR13.cfgShieldR13 Ly)) (CfR (DefR13.cfgShieldR13 Ly)))
    (B : W16Pub (ZK60.RunShape.Shield.shieldShape Ly) Pb Lay) (ioIn ioOut : ℕ)
    (hdef : P.define = defineS (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
      (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG))
    (hlc : P.logCols = 14) (hep : 0 < P.endpointLogN)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hdrLen hdrSq : ℕ) (hh : hdrLen ≤ 2 ^ 19) (hq : hdrSq ≤ 2 ^ 63)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (hcsE : ∀ (cu : Cuts3 L) (rt : RootsO) (cm : Cm) (z : ZClaim), (cm = .inp ∨ cm = .out) →
      csE cu rt cm z = Link.claimSem U (rE cm) (rowLog P cm) (QE cm) (XE cu rt cm) z)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (εend : ℝ≥0∞)
    (hEnd : prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
      ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ EndTrue U ((Link.csShieldR13 U tag hL20 csE) (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2)) acc) ≤ εend)
    (hLay : LayR Lay)
    (hhr : ∀ G bga rs acc, AccT U key domain hs hL P hdrLen (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 16 256
      24448 4577 4390 rE QE XE (DefR13.progR13 (DefR13.cfgShieldR13 Ly) ioIn ioOut)
        (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG)))
      (Link.csShieldR13 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      HGdR U (DefR13.cfgShieldR13 Ly) P (algShapeR (DefR13.cfgShieldR13 Ly) P (shOk_shield Ly P hP.hdr))
        (dtR (geoShield Ly) Pb Lay B P (shOk_shield Ly P hP.hdr)
          (fun cu rt => xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) 1)
          (perRow_shield Ly)
          (xcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B)
          (pwcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B))
        (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt)
        (Pub.gateLS (DefR13.cfgShieldR13 Ly).sh) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga →
      ∃ Hh, HelperRel
        (fun l => fold (bga.1.toK U) (bga.2.1.toK U)
          (AlkR13 U (DefR13.cfgShieldR13 Ly) P Pb Lay B (geoShield Ly) (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE
            QE XE (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1 l))
        (fun j => fold (bga.1.toK U) (bga.2.1.toK U)
          (TR13 (K := K) Pb.exp Pb.act (ZK60.RunShape.Shield.shieldShape Ly).nG j))
        (mlkR13 U (DefR13.cfgShieldR13 Ly) P (dofAR tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
          (absOfC (chainEncB key domain hs L hL)) A) (cutsOf key domain hs hL A G).1) (bga.2.2.toK U) Hh) :
    prH (fun G : QB L → Dig => ∃ bga rs acc, BlockAcc key domain P hdrLen G (A.run G) bga rs acc
        ∧ Link.sqN (A.run G).1 = hdrSq ∧ ¬ ZK60.Block.BlockSat Pb
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X (Lay.dPos p))
          (fun p => (xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).X2 (Lay.dPos p))
          (ZK60.Layout.toWit Lay ((xtR U (DefR13.cfgShieldR13 Ly) P (dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE
            XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) 1).toW16 (ZK60.RunShape.Shield.shieldShape Ly))))
      ≤ εsTarget q + εend :=
  block_knowledge_look_r13_shield Ly hLy U hU hK2 key domain hs hL hL64 hL20 P tag rowsOf hP Pb Lay B ioIn ioOut hdef
    hlc hep hk3 hk19 hk20 hdrLen hdrSq hh hq csE rE QE XE hcsE q A hA εend hEnd hLay
    (xcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B)
    (pwcR U (geoShield Ly) P (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt) Pb Lay B)
    (fun G bga rs acc hT => formAt_hostsR U hU (card_K_gt K) Pb (geoShield Ly) Lay B P (shOk_shield Ly P hP.hdr)
      (profR_shield Ly P hP.hdr hP.hsl) (Tzc.tzcCfg_shield Ly) (Dzc.dzcCfg_shield Ly hLy)
      (Qkv.qkvCfg_shieldExport Ly hLy) (Szc.szcCfg_shield Ly hLy) (Fzc.fzcCfg_shield Ly hLy)
      ioIn ioOut (Pub.pubsR13L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG) hdef
      (fun cu rt => dXof tag hL20 P hlc 16 256 24448 4577 4390 rE QE XE cu rt)
      (fun cu rt => dXof_base_r13 tag hL20 P hlc 4577 4390 rE QE XE cu rt)
      (by show 0 < P.logCols; rw [hlc]; norm_num) (by show 0 < P.logCols; rw [hlc]; norm_num)
      (precR_shield Ly) (shieldWindows Ly hLy) hLay
      (Pub.pubR_of_L (DefR13.cfgShieldR13 Ly) Pb Lay B (ZK60.RunShape.Shield.shieldShape Ly).nG U hU)
      (perRow_shield Ly) (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) bga rs
      (fun j r hr => by
        obtain ⟨sp, df, hdf, -, -, -, hkind, -, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen _ _ _ A G bga
          rs acc hT j r hr
        exact ⟨df, hdf, hkind⟩))
    hhr

end ZK60.Exec.Block.Join.R13H
