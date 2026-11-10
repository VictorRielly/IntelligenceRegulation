/-
D63 lane L49 (2026-11-10), sub-agent `help`, part 2: **the helper layer at R13 assembled** (lane L36's helper premises
of `block_knowledge_join_r13_rung` / `_shield`: `HGd`, `spH`, `hdgH`, `hformH`, `hgdH`), generic in the configuration
`c` (facts `HelpCfg c`) and the verifier (facts `HelpProf P`), for ANY algebra shape `sh` (the lane's
`algShapeR c P hc`, `BlockR13LookHelpR13.lean`) and any algebra data `dt : AlgData K L sh`, by lane L44's W16R2 pattern
(`BlockLkGd.lean`).

* `spXkR`, `spXR`: **the helper layer's polynomials off the hosts**: `SC_LZC` (`spLzcR`), `SC_TAB` (lane L47's
  `spTabR`, read at `(β, γ, α)`), `SC_ZS` (`spZsR`);
* **`spHR`**: lane L44's `spHW` on them (at the six hosts the relation layer's `algSp … 0`);
* **`HGdR`**: what the helper layer's start claims say, read at `(β, γ, α)` only: every host's batch and pad planes
  vanish on its cube; `SC_LZC`'s limb relation and pad planes vanish; `SC_TAB`'s three table relations and six pad
  planes vanish; the zero-sum row sums to `0`;
* **`hgdR_of`** (`hgdH`), **`helperR_dg`** (`hdgH`: degrees `≤ 80`; `SC_LZC` `4`, `SC_TAB` `8`, `SC_ZS` `0`, the hosts by
  `algSp_dg`), **`helperR_formAt`** (`hformH`, from the six hosts' named identities taken as a hypothesis exactly as
  lane L44's `helper_formAt` takes them; `lzcR_formAt`, lane L47's `tabR_formAt`, `zsR_formAt`; the slot kinds `hk3`,
  `hk19`, `hk20` and the public tables of slots `3`, `19`, `20` are named premises).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13LookHelpSlot

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Help

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Circuit (gP GF)

section Layer

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}

/-- **The helper layer's polynomials off the hosts at R13**: `SC_LZC`, `SC_TAB` (read at `(β, γ, α)`), `SC_ZS`. -/
noncomputable def spXkR (U : K) (hcard : 78 < Fintype.card K) (c : W16Cfg) (P : BlockParams) (hpr : HelpProf P)
    (D : CmData K P) (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) :
    (k : ℕ) → Hist → SlotPoly K (P.draws k)
  | 3, h => spLzcR U hcard c P hpr.d3 D gL h
  | 19, h => R13T.spTabR U c hcard P hpr.d19 D exp act nG (h.beta, h.gamma, h.alpha)
  | 20, _ => spZsR U c P hpr.d20 D
  | k, _ => SlotPoly.triv (P.draws k)

/-- The same on the extraction's cuts and roots. -/
noncomputable def spXR (U : K) (hcard : 78 < Fintype.card K) (c : W16Cfg) (P : BlockParams) (hpr : HelpProf P)
    (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) :
    Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  fun cu rt k h => spXkR U hcard c P hpr (Dof cu rt) gL exp act nG k h

/-- **The helper layer's certified polynomials at R13** (lane L36's `spH`): at the six hosts the relation layer's
(`algSp … 0`), at `SC_LZC`, `SC_TAB`, `SC_ZS` R13's own. -/
noncomputable def spHR (U : K) (hcard : 78 < Fintype.card K) (c : W16Cfg) (P : BlockParams) (hpr : HelpProf P)
    (sh : AlgShape P) (dt : AlgData K L sh) (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF)
    (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) : Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  Lk.spHW U sh dt hcard (spXR U hcard c P hpr Dof gL exp act nG)

/-- **What the helper layer's start claims say at R13** (lane L36's `HGd`; read at `bga = (β, γ, α)` only). -/
def HGdR (U : K) (c : W16Cfg) (P : BlockParams) (sh : AlgShape P) (dt : AlgData K L sh)
    (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) : Prop :=
  (∀ k ∈ algHosts, (∀ κ b, dt.cl k cu rt bga κ b = 0) ∧ ∀ j b, dt.pw k cu rt j b = 0)
  ∧ ((∀ b, cLzcR U c P (Dof cu rt) gL bga b = 0) ∧ ∀ j b, wLzcR U c P (Dof cu rt) gL j b = 0)
  ∧ ((∀ k b, R13T.cTabR U c P (Dof cu rt) exp act nG bga k b = 0) ∧ ∀ j b, R13T.wTabR U c P (Dof cu rt) nG j b = 0)
  ∧ ∑ b : Fin 14 → Bool,
      hPl U P (Dof cu rt) (DefR13.hOff c (DefR13.fh c 10)).1 (DefR13.hOff c (DefR13.fh c 10)).2 14 b = 0

variable (U : K) (hcard : 78 < Fintype.card K) (c : W16Cfg) (P : BlockParams) (hpr : HelpProf P) (sh : AlgShape P)
  (dt : AlgData K L sh) (Dof : Cuts3 L → RootsO → CmData K P) (gL : (Fin 14 → Bool) → GF) (exp : ℤ → ℤ)
  (act : ℕ → ℤ → ℤ) (nG : ℕ)

/-- **`hgdH` at R13**: the helper layer's start claims give `HGdR`. -/
theorem hgdR_of (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hG : SchedGd (w16r2DH P (spHR U hcard c P hpr sh dt Dof gL exp act nG) 0) cu rt bga rs) :
    HGdR U c P sh dt Dof gL exp act nG cu rt bga := by
  have hR : SchedGd (w16r2DR P (algSp U sh dt hcard) 0) cu rt bga rs := by
    intro k hk
    by_cases hh : k ∈ algHosts
    · show (algSp U sh dt hcard 0 cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Gd
      rw [← Lk.spHW_host U sh dt hcard (spXR U hcard c P hpr Dof gL exp act nG) cu rt k _ hh]
      exact hG k hk
    · rcases Lk.relKs0_rest k hk hh with rfl | rfl | rfl <;> exact trivial
  refine ⟨fun k hk => ⟨(host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).1,
    (host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).2.1⟩, ?_, ?_, ?_⟩
  · have h3 := hG 3 (show (3 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (Lk.spHW U sh dt hcard (spXR U hcard c P hpr Dof gL exp act nG) cu rt 3 _).Gd at h3
    rw [Lk.spHW_rest U sh dt hcard _ cu rt 3 _ (by decide)] at h3
    exact h3
  · have h19 := hG 19 (show (19 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (Lk.spHW U sh dt hcard (spXR U hcard c P hpr Dof gL exp act nG) cu rt 19 _).Gd at h19
    rw [Lk.spHW_rest U sh dt hcard _ cu rt 19 _ (by decide)] at h19
    exact h19
  · have h20 := hG 20 (show (20 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (Lk.spHW U sh dt hcard (spXR U hcard c P hpr Dof gL exp act nG) cu rt 20
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20))).Gd at h20
    rw [Lk.spHW_rest U sh dt hcard _ cu rt 20 _ (by decide)] at h20
    exact h20

/-- **`hdgH` at R13**: every helper-layer polynomial has degree at most `80` (`SC_LZC` `4`, `SC_TAB` `8`, `SC_ZS` `0`,
the hosts by `algSp_dg`). -/
theorem helperR_dg :
    ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spHR U hcard c P hpr sh dt Dof gL exp act nG cu rt k h).dg ≤ 80 :=
  Lk.spHW_dg U sh dt hcard _ (fun cu rt k h hk => by
    rcases hk with rfl | rfl | rfl
    · show (spLzcR U hcard c P hpr.d3 (Dof cu rt) gL h).dg ≤ 80
      rw [spLzcR_dg]
      norm_num
    · show (R13T.spTabR U c hcard P hpr.d19 (Dof cu rt) exp act nG (h.beta, h.gamma, h.alpha)).dg ≤ 80
      rw [R13T.spTabR_dg]
      norm_num
    · show (spZsR U c P hpr.d20 (Dof cu rt)).dg ≤ 80
      exact Nat.zero_le 80)

/-- **`hformH` at R13** on an outcome: the helper layer's named identities, from the six hosts' (`hhost`, the hosts'
sub-agents' work), `SC_LZC`'s, `SC_TAB`'s and `SC_ZS`'s (proved here, on the configuration's raw slots `hcfg`, the
public-data facts `hgate`, `hrest19`, `hrest20` and the slot kinds `hk3`, `hk19`, `hk20`). -/
theorem helperR_formAt (hU : U ^ 2 = algebraMap GF K 7) (hcfg : HelpCfg c) (ioIn ioOut : ℕ) (pubs : PubTabs)
    (hrl : 0 < rowLog P .a)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gL b))
    (hrest19 : ∀ hist dr i, pubs 19 hist dr i = R13T.restR13 exp act nG 19 hist dr i)
    (hrest20 : ∀ hist dr, pubs 20 hist dr 0 = R13T.restR13 exp act nG 20 hist dr 0)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P (polyS U P (Dof cu rt) (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P (polyS U P (Dof cu rt) (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (spHR U hcard c P hpr sh dt Dof gL exp act nG cu rt k h).Φ) bga rs k :=
  Lk.spHW_formAt U sh dt hcard _ _ cu rt bga rs hhost (fun k hk => by
    rcases hk with rfl | rfl | rfl
    · exact lzcR_formAt U hcard hU c hcfg.raw3 P hpr.d3 hpr.s3 ioIn ioOut pubs (Dof cu rt) hrl hk3 gL hgate _
        (fun _ _ => rfl) bga rs
    · exact R13T.tabR_formAt U hU hcard c hcfg.raw19 P hpr.d19 hpr.s19 ioIn ioOut exp act nG pubs hrest19 (Dof cu rt)
        hrl hrl hk19 _ (fun _ _ => rfl) bga rs
    · exact zsR_formAt U c hcfg.raw20 P hpr.s20 ioIn ioOut pubs (Dof cu rt) hrl hk20
        (fun hist dr b => by rw [hrest20]; exact R13T.rest20R13_getD U exp act nG hist dr b) _ (fun _ _ => rfl) bga rs)

end Layer

end ZK60.Exec.Block.Join.R13H.Help
