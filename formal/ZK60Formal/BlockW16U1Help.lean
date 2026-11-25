/-
D63 W16R2 Shieldstral port, Item (5f) (`BlockW16U1Help.lean`):
**the helper layer (`SC_LZC` slot `3`, `SC_TAB` slot `19`, `SC_ZS` slot `20`, and the six hosts)
at the installed W16R2 Shieldstral export `export_u1`**, parametric in `(cnA, cnM)`.

Because `rawSlot (cfgU1 cnA cnM) s = rawSlot c0 s` by `rfl` for `s ∈ {3, 19, 20}`, all 26 layers
of `export_u1` share the exact same helper-layer slot structure:
* `SC_ZS` (slot `20`): zero-sum row `H_U` at `H` plane `fh c0 10 = 43` (`hOffU1 43`), certified
  polynomial `spZsU1` (degree `0`), and standalone named identity `formAt_zsU1`;
* `SC_LZC` (slot `3`): limb planes `A` `6`, `7` (`offU1 6`, `offU1 7`), helper `H` `0`
  (`hOffU1 0`), gate `gateLU1`, relations `cLzcU1` / `wLzcU1`, certified polynomial `spLzcU1`
  (degree `4`), and standalone named identity `formAt_lzcU1`;
* `SC_TAB` (slot `19`): `spTabU1` (degree `22`) and `hTform_u1` (from `formAt_tabU1` +
  `pubsU1_rest` + `rest19U1_getD` + `rest19U1_gate_getD`);
* Assembled helper layer: `spXkU1`, `spXU1`, `spHU1`, `HGdU1`, `hgdU1_of`, `helperU1_dg` (`≤ 80`),
  `helperU1_formAt`, and `helperU1_formAt_pubs`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1TabForm
import ZK60Formal.BlockLkBase
import ZK60Formal.BlockLkLzc
import ZK60Formal.BlockLkGd

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Help

open ZK60.Sound
open ZK60.Sound.SlotW16 (SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl hPl hTab_eval tabK_ph_cpt tabK_pa_cpt eqT_eval pubT_eval
  cstS_map cstK toK_zpowW lksS_eval)
open ZK60.Exec.Block.Join.W16.Lk (shapedL drL drL_length drL_getD ir3 lzc_irEval lksLK secL
  spHW spHW_host spHW_rest relKs0_rest spHW_dg spHW_formAt)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.Join.W16U1.Tab
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (zsIr zsIr_eval logupSem padSem)
open ZK60.Exec.Slot.Compose (zsIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout

/-! ## 1. `SC_ZS` (slot `20`) at `export_u1`: `H_U` at `H` plane `fh c0 10 = 43` -/

/-- `SC_ZS`'s zero-sum row `H_U` at `export_u1` is `H` plane `fh c0 10 = 43`. -/
theorem fhU_u1 : DefW16.fh c0 10 = 43 := by decide +kernel

/-- `SC_ZS`'s tables at `export_u1` with mask row `m`: the all-ones public table and `H_U` (`hOffU1 43`). -/
def rawTabs20U1 (m : ℕ) : List TabS :=
  [.pub 0, .priv ⟨.h, [((hOffU1 43).1, false), ((hOffU1 43).2, true)], 14, DefW16.rhoC 0 14, m, 0⟩]

/-- Raw slot `20` is independent of `(cnA, cnM)` by `rfl`. -/
theorem rawSlot20_cfgU1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 20 = DefW16.rawSlot c0 20 :=
  DefW16.rawSlot_shieldU1_ne14 cnA cnM 20 (by decide)

/-- Raw slot `20` at `c0`, by evaluation. -/
theorem rawSlot20_c0 : DefW16.rawSlot c0 20 = ⟨rawTabs20U1 0, zsIr DefW16.cstS 0 1, [], []⟩ := rfl

/-- **Raw slot `20` at `cfgU1 cnA cnM`** for every `(cnA, cnM)`. -/
theorem rawSlot20_u1 (cnA cnM : ℕ) :
    DefW16.rawSlot (cfgU1 cnA cnM) 20 = ⟨rawTabs20U1 0, zsIr DefW16.cstS 0 1, [], []⟩ :=
  (rawSlot20_cfgU1 cnA cnM).trans rawSlot20_c0

/-- Numbering sets the mask row of slot `20`'s `H` table only. -/
theorem numTabs20U1 (aB hB ioIn ioOut ak hk : ℕ) :
    DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabs20U1 0) = rawTabs20U1 (hB + 2 * hk) := rfl

section Zs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_ZS`'s cube sum at `export_u1`** (`n = 14`), for any mask row `m`:
`Σ_b ones(b)·H_U(b)`; off the zero extension the public table is `0`. -/
theorem zsU1_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (m n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U))
      (((rawTabs20U1 m).map (TabS.eval (Sym.eval hist 20 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U
      * hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b := by
  subst hn
  have hir : ∀ v : List K, irEval (((zsIr DefW16.cstS 0 1).map (Sym.eval hist 20 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * v.getD 1 0 := by
    intro v
    rw [zsIr_map, zsIr_map, cstS_map, zsIr_eval _ (cstW_map_std U)]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, hir]
    simp only [rawTabs20U1, List.map_cons, List.map_nil, pubT_eval, hTab_eval, List.getD_cons_zero,
      List.getD_cons_succ]
    rw [tabK_pub_cpt, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  · show f (bpt 14 e b y) = 0
    rw [hf, hir]
    simp only [rawTabs20U1, List.map_cons, List.map_nil, pubT_eval, List.getD_cons_zero]
    rw [tabK_pub_off U P D 14 e b y hy, zero_mul]

/-- **`SC_ZS`'s certified polynomial at `export_u1`** (no draws, degree `0`): its start claim is
that the zero-sum row `H_U` (`hOffU1 43`) sums to `0`. -/
noncomputable def spZsU1 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P) :
    SlotPoly K (P.draws 20) :=
  SlotPoly.cast (by rw [hdr]; decide)
    (SlotPoly.zs (fun b : Fin 14 → Bool => hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b))

theorem spZsU1_dg (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P) :
    (spZsU1 U P hdr D).dg = 0 := rfl

theorem spZsU1_Gd (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P) :
    (spZsU1 U P hdr D).Gd = (∑ b : Fin 14 → Bool, hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b = 0) := rfl

/-- **`SC_ZS`'s standalone named identity at `export_u1`** (slot `20`, parametric in `(cnA, cnM)`):
a polynomial family whose value at slot `20` is `Σ_b H_U(b)` meets `FormAt` there, for a verifier
with `W16R2.shieldSlots` whose slot `20` is standalone and whose slot-`20` public table is the
all-ones table. -/
theorem formAt_zsU1 (P : BlockParams) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hones : ∀ hist dr (b : Fin 14 → Bool), ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 20 hist x = ∑ b : Fin 14 → Bool, hPl U P D (hOffU1 43).1 (hOffU1 43).2 14 b)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) Φ bga rs 20 := by
  intro r df hr _
  refine Or.inl ⟨hk20, ?_⟩
  rw [hΦ]
  have hs20 : slotShape P 20 = (14, 1, 2) := by
    simp only [slotShape, hsl]
    decide
  obtain ⟨ak, hk, hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 20 (by norm_num)
  unfold spSum
  rw [zsU1_cube U P D hrl (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws
    (pubs 20 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20)) r.draws)
    (DefW16.hDataRows (cfgU1 cnA cnM) + 2 * hk) (slotShape P 20).1 (slotShape P 20).2.1 (by rw [hs20]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 20 r hr x, hslot, rawSlot20_u1]; rfl)]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [hones, one_mul]

end Zs

/-! ## 2. `SC_LZC` (slot `3`) at `export_u1`: `limb = 6`, `limbm = 7`, `h = 0`, `gateLU1` -/

/-- `SC_LZC`'s tables at `export_u1` with mask rows `m1 m2 m3`: `eq(τ)` (draws `0 .. 13`), limb
planes `A` `6` and `7`, limb helper `H` `0`, and `supp(Dom::L)`. -/
def rawTabs3U1 (m1 m2 m3 : ℕ) : List TabS :=
  [.eq (drL 3 14) 0,
    .priv ⟨.a, [(offU1 6, false)], 14, DefW16.rhoC 0 14, m1, 0⟩,
    .priv ⟨.a, [(offU1 7, false)], 14, DefW16.rhoC 0 14, m2, 0⟩,
    .priv ⟨.h, [((hOffU1 0).1, false), ((hOffU1 0).2, true)], 14, DefW16.rhoC 0 14, m3, 0⟩,
    .pub 0]

/-- Raw slot `3` is independent of `(cnA, cnM)` by `rfl`. -/
theorem rawSlot3_cfgU1 (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 3 = DefW16.rawSlot c0 3 :=
  DefW16.rawSlot_shieldU1_ne14 cnA cnM 3 (by decide)

/-- Raw slot `3` at `c0`, by evaluation (IR is `BlockLkLzc.ir3` verbatim). -/
theorem rawSlot3_c0 : DefW16.rawSlot c0 3 = ⟨rawTabs3U1 0 0 0, ir3, [], [.dr 3 15]⟩ := rfl

/-- **Raw slot `3` at `cfgU1 cnA cnM`** for every `(cnA, cnM)`. -/
theorem rawSlot3_u1 (cnA cnM : ℕ) :
    DefW16.rawSlot (cfgU1 cnA cnM) 3 = ⟨rawTabs3U1 0 0 0, ir3, [], [.dr 3 15]⟩ :=
  (rawSlot3_cfgU1 cnA cnM).trans rawSlot3_c0

/-- Numbering sets the mask rows of slot `3`'s three private tables only. -/
theorem numTabs3U1 (aB hB ioIn ioOut ak hk : ℕ) :
    DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawTabs3U1 0 0 0)
      = rawTabs3U1 (aB + 2 * ak) (aB + 2 * (ak + 1)) (hB + 2 * hk) := rfl

section LzcVals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_LZC`'s value list at `export_u1` at a cube point with the zero extension**, for any mask rows. -/
theorem lzcU1_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ)
    (b : Fin 14 → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (m1 m2 m3 : ℕ) :
    ((rawTabs3U1 m1 m2 m3).map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e b))
      = [eqPoly (fun a : Fin 14 => (((drL 3 14).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         aPl U P D (offU1 6) 14 b, aPl U P D (offU1 7) 14 b,
         hPl U P D (hOffU1 0).1 (hOffU1 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] := by
  have hlen : ((drL 3 14).map ev).length = 14 := drL_length ev 3 14
  simp only [rawTabs3U1, List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 14 e b _ hlen, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    tabK_pub_cpt, castB_rfl]

/-- `SC_LZC`'s value list without the draws at `export_u1`: `eq` entry `0`, limb planes `6` and `7`,
helper `H` `0`, and `gateLU1`. -/
noncomputable def valsLU1 (P : BlockParams) (D : CmData K P) (b : Fin 14 → Bool) : List K :=
  [0, aPl U P D (offU1 6) 14 b, aPl U P D (offU1 7) 14 b,
    hPl U P D (hOffU1 0).1 (hOffU1 0).2 14 b, algebraMap GF K (gateLU1 b)]

/-- **`SC_LZC`'s helper relation at `export_u1`**: LogUp's pair relation `h·d₁·d₂ − d₁ − d₂` of
the two limb lookups (weight `1`), read at `bga = (β, γ, α)`. -/
noncomputable def cLzcU1 (P : BlockParams) (D : CmData K P) (bga : Fp2 × Fp2 × Fp2) (b : Fin 14 → Bool) : K :=
  logupSem (cstK U) (valsLU1 U P D b) 3 (fun _ => (cstK U).one) 0 (lksLK U bga)

/-- **`SC_LZC`'s pad planes at `export_u1`**: `(1 − gateLU1)·limb`, `(1 − gateLU1)·limbm`. -/
noncomputable def wLzcU1 (P : BlockParams) (D : CmData K P) (j : Fin 2) (b : Fin 14 → Bool) : K :=
  (1 - algebraMap GF K (gateLU1 b))
    * (if (j : ℕ) = 0 then aPl U P D (offU1 6) 14 b else aPl U P D (offU1 7) 14 b)

end LzcVals

section LzcCube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **`SC_LZC`'s cube sum at `export_u1`** (`n = 14`), for any mask rows `m1 m2 m3`:
`Σ_b eq(τ, b)·(cLzcU1(b) + μ_pad·Σ_j ζ^j·wLzcU1_j(b))`, `τ` draws `0 .. 13`, `μ_pad` draw `14`,
`ζ` draw `15`. -/
theorem lzcU1_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hgate : ∀ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateLU1 b))
    (m1 m2 m3 n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir3.map (Sym.eval hist 3 dr)).map (Fp2.toK U))
      (((rawTabs3U1 m1 m2 m3).map (TabS.eval (Sym.eval hist 3 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a))
      * (cLzcU1 U P D (hist.beta, hist.gamma, hist.alpha) b
        + (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzcU1 U P D j b) := by
  subst hn
  have hlks : ((DefW16.lksS DefW16.cfgRungW16 shapedL .L).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 3 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)) = lksLK U (hist.beta, hist.gamma, hist.alpha) := by
    unfold lksLK
    rw [lksS_eval DefW16.cfgRungW16 shapedL .L hist (histOf hist.beta hist.gamma hist.alpha []) 3 3 dr [] rfl rfl]
  have heq : eqPoly (fun a : Fin 14 => (((drL 3 14).map (Sym.eval hist 3 dr)).getD a Fp2.zero).toK U)
      = eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) := by
    congr 1
    funext a
    rw [drL_getD]
    simp [Sym.eval, drawAt]
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun b _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 14 e b) = _
    rw [hf, lzc_irEval, lzcU1_vals U P D hrl e b (Sym.eval hist 3 dr) pub m1 m2 m3, hlks, heq]
    have hL : logupSem (cstK U) [eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)),
          aPl U P D (offU1 6) 14 b, aPl U P D (offU1 7) 14 b,
          hPl U P D (hOffU1 0).1 (hOffU1 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U] 3
          (fun _ => (cstK U).one) 0 (lksLK U (hist.beta, hist.gamma, hist.alpha))
        = cLzcU1 U P D (hist.beta, hist.gamma, hist.alpha) b := by
      unfold cLzcU1
      rw [logupSem_eq_wsum, logupSem_eq_wsum]
      congr 1
    have hP : padSem (cstK U) [eqPoly (fun a : Fin 14 => (dr.getD a Fp2.zero).toK U) (fun a => bit (b a)),
          aPl U P D (offU1 6) 14 b, aPl U P D (offU1 7) 14 b,
          hPl U P D (hOffU1 0).1 (hOffU1 0).2 14 b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U]
          ((Sym.eval hist 3 dr (.dr 3 14)).toK U) (fun j => (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U) 0
          [(4, [1, 2])]
        = (dr.getD 14 Fp2.zero).toK U * ∑ j : Fin 2, ((dr.getD 15 Fp2.zero).toK U) ^ (j : ℕ) * wLzcU1 U P D j b := by
      rw [padSem_eq_wsum _ (cstW_map_std U)]
      simp only [padPls, List.map_cons, List.map_nil, List.append_nil, wsum, List.getD_cons_zero,
        List.getD_cons_succ, Fin.sum_univ_two, wLzcU1, Fin.val_zero, Fin.val_one, Fin.isValue, one_ne_zero, ↓reduceIte,
        add_zero, Nat.zero_add]
      rw [hgate b]
      have h14 : Sym.eval hist 3 dr (.dr 3 14) = dr.getD 14 Fp2.zero := by simp [Sym.eval, drawAt]
      have hz : ∀ j, (Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j)).toK U = ((dr.getD 15 Fp2.zero).toK U) ^ j := by
        intro j
        rw [show Sym.eval hist 3 dr (Sym.pow (.dr 3 15) j) = zpowW (dr.getD 15 Fp2.zero) j by simp [Sym.eval, drawAt],
          toK_zpowW U hU]
      rw [h14, hz 0, hz 1]
    simp only [List.getD_cons_zero]
    rw [hL, hP]
  · show f (bpt 14 e b y) = 0
    rw [hf, lzc_irEval]
    simp only [rawTabs3U1, List.map_cons, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D 14 e b y hy, zero_mul]

end LzcCube

section LzcPoly

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)

include hcard in
/-- **`SC_LZC`'s certified polynomial at `export_u1`** (`SlotPoly.lzc`, degree `4`, draws `τ`
`0 .. 13`, `μ_pad` `14`, `ζ` `15`): its start claim is that the limb helper relation and the two
pad planes vanish on the cube. -/
noncomputable def spLzcU1 (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P)
    (h : Hist) : SlotPoly K (P.draws 3) :=
  SlotPoly.cast (by rw [hdr]; decide)
    (SlotPoly.lzc (n := 14) (m := 2) (D := 16) (cLzcU1 U P D (h.beta, h.gamma, h.alpha)) (wLzcU1 U P D)
      (fun x => x 15) (fun x => x 14) (fun i => Fin.castLE (by norm_num) i)
      (ZK60.Sound.SlotW16.indDeg_coord 15) (ZK60.Sound.SlotW16.indDeg_coord 14)
      (Fin.castLE_injective (by norm_num : 14 ≤ 16)) (by omega)
      (fun ζ μp τ _ => ⟨secL ζ μp τ, rfl, funext fun i => by simp [secL]⟩))

theorem spLzcU1_dg (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P) (h : Hist) :
    (spLzcU1 U hcard P hdr D h).dg = 4 := rfl

theorem spLzcU1_Gd (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P) (h : Hist) :
    (spLzcU1 U hcard P hdr D h).Gd
      = ((∀ b, cLzcU1 U P D (h.beta, h.gamma, h.alpha) b = 0) ∧ ∀ j b, wLzcU1 U P D j b = 0) := rfl

include hcard in
/-- **`SC_LZC`'s standalone named identity at `export_u1`** (slot `3`, parametric in `(cnA, cnM)`),
for a verifier with `W16R2.shieldDraws` / `W16R2.shieldSlots` whose slot `3` is standalone and
whose slot-`3` public table is `gateLU1`. -/
theorem formAt_lzcU1 (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (D : CmData K P)
    (hrl : 0 < rowLog P .a) (hk3 : P.kind 3 = SlotKind.standalone)
    (hgate : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateLU1 b))
    (Φ : (k : ℕ) → Hist → (Fin (P.draws k) → K) → K)
    (hΦ : ∀ hist x, Φ 3 hist x = (spLzcU1 U hcard P hdr D hist).Φ x)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) Φ bga rs 3 := by
  intro r df hr _
  refine Or.inl ⟨hk3, ?_⟩
  rw [hΦ]
  have hs3 : slotShape P 3 = (14, 1, 4) := by
    simp only [slotShape, hsl]
    decide
  obtain ⟨ak, hk, hslot⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 3 (by norm_num)
  unfold spSum
  rw [lzcU1_cube U hU P D hrl (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws
    (pubs 3 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 3)) r.draws) (hgate _ _)
    (DefW16.aDataRows (cfgU1 cnA cnM) + 2 * ak) (DefW16.aDataRows (cfgU1 cnA cnM) + 2 * (ak + 1))
    (DefW16.hDataRows (cfgU1 cnA cnM) + 2 * hk) (slotShape P 3).1 (slotShape P 3).2.1 (by rw [hs3]) _
    (fun x => by rw [polyS_seenOf U P D _ _ bga rs 3 r hr x, hslot, rawSlot3_u1]; rfl)]
  rfl

end LzcPoly

/-! ## 3. The helper layer assembled at `export_u1` (`spXU1`, `spHU1`, `HGdU1`, `hTform_u1`) -/

section Sched

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] {L : ℕ}

/-- **The helper layer's polynomials off the hosts at `export_u1`**: `SC_LZC` (`spLzcU1`), `SC_TAB`
(`spTabU1` read at `(β, γ, α)`), and `SC_ZS` (`spZsU1`). -/
noncomputable def spXkU1 (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) :
    (k : ℕ) → Hist → SlotPoly K (P.draws k)
  | 3, h => spLzcU1 U hcard P hdr D h
  | 19, h => spTabU1 U hcard P hdr D Pb nG (h.beta, h.gamma, h.alpha)
  | 20, _ => spZsU1 U P hdr D
  | k, _ => SlotPoly.triv (P.draws k)

/-- The same on the extraction's cuts and roots. -/
noncomputable def spXU1 (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (Dof : Cuts3 L → RootsO → CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) :
    Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  fun cu rt k h => spXkU1 U hcard P hdr (Dof cu rt) Pb nG k h

/-- **`SC_TAB`'s named identity on `spXU1` at the concrete `export_u1` public tables
`pubsU1 Pb Lay B nG`**, proved from `formAt_tabU1` + `pubsU1_rest` + `rest19U1_getD` +
`rest19U1_gate_getD`. -/
theorem hTform_u1 (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (nG : ℕ)
    (Dof : Cuts3 L → RootsO → CmData K P) (hrlA : 0 < rowLog P .a) (hrlH : 0 < rowLog P .h)
    (hk19 : P.kind 19 = SlotKind.standalone)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) :
    FormAt U P (polyS U P (Dof cu rt) (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B nG))
      (fun k h => (spXU1 U hcard P hdr Dof Pb nG cu rt k h).Φ) bga rs 19 :=
  formAt_tabU1 U hU hcard P hdr hsl cnA cnM ioIn ioOut (pubsU1 Pb Lay B nG) Pb nG (Dof cu rt)
    hrlA hrlH hk19
    (fun hist dr k hk b => by
      rw [pubsU1_rest Pb Lay B nG 19 (Or.inr (Or.inl rfl))]
      exact rest19U1_getD U hU Pb nG hist dr k hk b)
    (fun hist dr g hg b => by
      rw [pubsU1_rest Pb Lay B nG 19 (Or.inr (Or.inl rfl)),
        rest19U1_gate_getD U Pb nG hist dr (16 + g) (by omega) (by omega) b,
        show 16 + g - 16 = g by omega])
    _ (fun _ _ => rfl) bga rs

/-- `hTform_u1` wrapped in the `AccT` signature at `dXof` (`(15, 280, 8052, 2504, 2606)`), matching
`BlockTabForm.hTform_w16`. -/
theorem hTform_u1_acc (U : K) (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (tag : MTag) (rowsOf : Cm → ℕ) (hP : Link.IsShieldW16 P tag rowsOf)
    (cnA cnM ioIn ioOut : ℕ) (hlc : P.logCols = 14) (hdrLen : ℕ)
    (csE : Cuts3 L → RootsO → Cm → ZClaim → K)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (A : OC (QB L) Dig (List Op × Core)) (hk19 : P.kind 19 = SlotKind.standalone) :
    ∀ G bga rs acc, AccT U key domain hs hL P hdrLen
      (maskedFX U tag hL20 P (polyXof U tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B S.nG)))
      (Link.csShieldW16 U tag hL20 csE) (Link.msRung U tag hL20) A G bga rs acc →
      FormAt U P
        (polyS U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
            (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
          (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B S.nG))
        (fun k h => (spXU1 U (card_K_gt K) P hP.hdr
          (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) Pb S.nG
          (cutsOf key domain hs hL A G) (rootsOf (A.run G).2) k h).Φ) bga rs 19 := by
  intro G bga rs acc _
  have hrl : 0 < P.logCols := by rw [hlc]; norm_num
  exact hTform_u1 U hU (card_K_gt K) P hP.hdr hP.hsl cnA cnM ioIn ioOut Pb Lay B S.nG
    (fun cu rt => dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE cu rt) hrl hrl hk19 _ _ bga rs

/-- **The helper layer's certified polynomials at `export_u1`** (`spH`): at the six hosts the
relation layer's (`algSp … 0`), at `SC_LZC` (3), `SC_TAB` (19), and `SC_ZS` (20) `spXU1`. -/
noncomputable def spHU1 (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams)
    (hdr : P.draws = W16R2.shieldDraws) (sh : AlgShape P) (dt : AlgData K L sh)
    (Dof : Cuts3 L → RootsO → CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ) :
    Cuts3 L → RootsO → (k : ℕ) → Hist → SlotPoly K (P.draws k) :=
  spHW U sh dt hcard (spXU1 U hcard P hdr Dof Pb nG)

/-- **What the helper layer's start claims say at `export_u1`** (`HGd`, read at `bga = (β, γ, α)`
only): every host's batch and pad planes vanish; `SC_LZC`'s limb relation and two pad planes
vanish; `SC_TAB`'s 16 table relations and 20 pad planes vanish; the zero-sum row `H_U` (`hOffU1 43`)
sums to `0`. -/
def HGdU1 (U : K) (P : BlockParams) (sh : AlgShape P) (dt : AlgData K L sh)
    (Dof : Cuts3 L → RootsO → CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) : Prop :=
  (∀ k ∈ algHosts, (∀ κ b, dt.cl k cu rt bga κ b = 0) ∧ ∀ j b, dt.pw k cu rt j b = 0)
  ∧ ((∀ b, cLzcU1 U P (Dof cu rt) bga b = 0) ∧ ∀ j b, wLzcU1 U P (Dof cu rt) j b = 0)
  ∧ ((∀ k b, cTabU1 U P (Dof cu rt) Pb nG bga k b = 0) ∧ ∀ j b, wTabU1 U P (Dof cu rt) nG j b = 0)
  ∧ ∑ b : Fin 14 → Bool, hPl U P (Dof cu rt) (hOffU1 43).1 (hOffU1 43).2 14 b = 0

variable (U : K) (hcard : 78 < Fintype.card K) (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws)
  (sh : AlgShape P) (dt : AlgData K L sh) (Dof : Cuts3 L → RootsO → CmData K P)
  {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (nG : ℕ)

/-- **`hgdH` at `export_u1`**: the helper layer's start claims give `HGdU1`. -/
theorem hgdU1_of (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hG : SchedGd (w16r2DH P (spHU1 U hcard P hdr sh dt Dof Pb nG) 0) cu rt bga rs) :
    HGdU1 U P sh dt Dof Pb nG cu rt bga := by
  have hR : SchedGd (w16r2DR P (algSp U sh dt hcard) 0) cu rt bga rs := by
    intro k hk
    by_cases hh : k ∈ algHosts
    · show (algSp U sh dt hcard 0 cu rt k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Gd
      rw [← spHW_host U sh dt hcard (spXU1 U hcard P hdr Dof Pb nG) cu rt k _ hh]
      exact hG k hk
    · rcases relKs0_rest k hk hh with rfl | rfl | rfl <;> exact trivial
  refine ⟨fun k hk => ⟨(host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).1,
    (host_gd_of_sched U sh dt hcard cu rt bga rs hR k hk).2.1⟩, ?_, ?_, ?_⟩
  · have h3 := hG 3 (show (3 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXU1 U hcard P hdr Dof Pb nG) cu rt 3 _).Gd at h3
    rw [spHW_rest U sh dt hcard _ cu rt 3 _ (by decide)] at h3
    exact h3
  · have h19 := hG 19 (show (19 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXU1 U hcard P hdr Dof Pb nG) cu rt 19 _).Gd at h19
    rw [spHW_rest U sh dt hcard _ cu rt 19 _ (by decide)] at h19
    exact h19
  · have h20 := hG 20 (show (20 : ℕ) ∈ w16r2RelKs 0 by decide)
    change (spHW U sh dt hcard (spXU1 U hcard P hdr Dof Pb nG) cu rt 20
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 20))).Gd at h20
    rw [spHW_rest U sh dt hcard _ cu rt 20 _ (by decide)] at h20
    exact h20

/-- **`hdgH` at `export_u1`**: every helper-layer polynomial has degree at most `80`
(`SC_LZC` `4`, `SC_TAB` `22`, `SC_ZS` `0`, and the six hosts by `algSp_dg`). -/
theorem helperU1_dg :
    ∀ cu rt k h, k ∈ w16r2RelKs 0 → (spHU1 U hcard P hdr sh dt Dof Pb nG cu rt k h).dg ≤ 80 :=
  spHW_dg U sh dt hcard _ (fun cu rt k h hk => by
    rcases hk with rfl | rfl | rfl
    · show (spLzcU1 U hcard P hdr (Dof cu rt) h).dg ≤ 80
      rw [spLzcU1_dg]
      norm_num
    · show (spTabU1 U hcard P hdr (Dof cu rt) Pb nG (h.beta, h.gamma, h.alpha)).dg ≤ 80
      rw [spTabU1_dg]
      norm_num
    · show (spZsU1 U P hdr (Dof cu rt)).dg ≤ 80
      rw [spZsU1_dg]
      norm_num)

/-- **`hformH` at `export_u1`** on an outcome (parametric in `(cnA, cnM)` and `pubs`): the helper
layer's named identities, from the six hosts' (`hhost`), `SC_LZC`'s (`formAt_lzcU1`), `SC_TAB`'s
(`formAt_tabU1`), and `SC_ZS`'s (`formAt_zsU1`). -/
theorem helperU1_formAt (hU : U ^ 2 = algebraMap GF K 7) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (hrl : 0 < rowLog P .a)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (hgate3 : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 3 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateLU1 b))
    (hcol19 : ∀ hist dr k, k < 16 → ∀ b : Fin 14 → Bool,
      ((pubs 19 hist dr k).getD (msbIndex 14 b) Fp2.zero).toK U
        = ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (tupK (tabTupU1 Pb nG k (msbIndex 14 b))))
    (hgate19 : ∀ hist dr g, g < 9 → ∀ b : Fin 14 → Bool,
      ((pubs 19 hist dr (16 + g)).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (gateTabU1 nG g b))
    (hones20 : ∀ hist dr (b : Fin 14 → Bool),
      ((pubs 20 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = 1)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P (polyS U P (Dof cu rt) (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P (polyS U P (Dof cu rt) (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (spHU1 U hcard P hdr sh dt Dof Pb nG cu rt k h).Φ) bga rs k :=
  spHW_formAt U sh dt hcard _ _ cu rt bga rs hhost (fun k hk => by
    rcases hk with rfl | rfl | rfl
    · exact formAt_lzcU1 U hcard hU P hdr hsl cnA cnM ioIn ioOut pubs (Dof cu rt) hrl hk3 hgate3 _
        (fun _ _ => rfl) bga rs
    · exact formAt_tabU1 U hU hcard P hdr hsl cnA cnM ioIn ioOut pubs Pb nG (Dof cu rt) hrl hrl hk19
        hcol19 hgate19 _ (fun _ _ => rfl) bga rs
    · exact formAt_zsU1 U P hsl cnA cnM ioIn ioOut pubs (Dof cu rt) hrl hk20 hones20 _
        (fun _ _ => rfl) bga rs)

/-- **`hformH` at `export_u1` specialized to the concrete public tables `pubsU1 Pb Lay B nG`**
(discharging slots `3`, `19`, and `20` from `pubsU1_rest`, `rest3U1_getD`, `hTform_u1`, and
`rest20U1_getD`). -/
theorem helperU1_formAt_pubs (hU : U ^ 2 = algebraMap GF K 7) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (hrl : 0 < rowLog P .a)
    (hk3 : P.kind 3 = SlotKind.standalone) (hk19 : P.kind 19 = SlotKind.standalone)
    (hk20 : P.kind 20 = SlotKind.standalone)
    (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hhost : ∀ k ∈ algHosts, FormAt U P
        (polyS U P (Dof cu rt) (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B nG))
      (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k) :
    ∀ k ∈ w16r2RelKs 0, FormAt U P
        (polyS U P (Dof cu rt) (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) (pubsU1 Pb Lay B nG))
      (fun k h => (spHU1 U hcard P hdr sh dt Dof Pb nG cu rt k h).Φ) bga rs k :=
  spHW_formAt U sh dt hcard _ _ cu rt bga rs hhost (fun k hk => by
    rcases hk with rfl | rfl | rfl
    · exact formAt_lzcU1 U hcard hU P hdr hsl cnA cnM ioIn ioOut (pubsU1 Pb Lay B nG) (Dof cu rt) hrl hk3
        (fun hist dr b => by
          rw [pubsU1_rest Pb Lay B nG 3 (Or.inl rfl)]
          exact rest3U1_getD U Pb nG hist dr b)
        _ (fun _ _ => rfl) bga rs
    · exact hTform_u1 U hU hcard P hdr hsl cnA cnM ioIn ioOut Pb Lay B nG Dof hrl hrl hk19 cu rt bga rs
    · exact formAt_zsU1 U P hsl cnA cnM ioIn ioOut (pubsU1 Pb Lay B nG) (Dof cu rt) hrl hk20
        (fun hist dr b => by
          rw [pubsU1_rest Pb Lay B nG 20 (Or.inr (Or.inr rfl))]
          exact rest20U1_getD U Pb nG hist dr b)
        _ (fun _ _ => rfl) bga rs)

end Sched

end ZK60.Exec.Block.Join.W16U1.Help
