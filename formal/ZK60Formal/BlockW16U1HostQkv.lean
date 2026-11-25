/-
D63 W16R2 Shieldstral port (`BlockW16U1HostQkv.lean`):
**`SC_QZC` (host `15`) and `SC_KVZC` (host `16`) and their hosted slots (`SC_QMM` 5, `SC_PV` 9,
`SC_KMM` 6, `SC_VMM` 7) at the installed Shieldstral export `export_u1` (`W16R2_SHIELD_T128_H24`).**

Mirrors `BlockHostQkv.lean` at the A29-uniform `export_u1` geometry (`lt = 7`, `ld = 12`, `lkv = 3`,
`lh = 5`, `lh - lkv = 2`, `ldh = 7`, `lq = 12`, `lkvw = 10`, `nQ = 19`, `nK = 17`), parameterized
by per-layer `(cnA, cnM)` (none of slots `5, 6, 7, 9, 15, 16` read `cnA` or `cnM`, so `rawSlot
(cfgU1 cnA cnM) s = rawSlot c0 s` holds by `rfl`):
* `tabs15_u1`, `raw15_u1`, `tabs16_u1`, `raw16_u1`, `rawMm_u1`, `rawPv_u1`, `prog_mm_u1`,
  `prog_pv_u1`: the six slots at `export_u1` via `progW16_slot` and `DefW16.numSlot` (parametric in
  `(cnA, cnM, ioIn, ioOut)` without hardcoded mask-row indices);
* `planesQ_u1`, `valsXQ_u1`, `lksQ_u1`, **`xcQzcU1`**: `SC_QZC`'s value list and LogUp batch entries
  past the RoPE clause (`6` `Dom::Q` planes `27..32`, RoPE flip bit `19 - 7 = 12`, `3` pair helpers
  at `H` planes `11, 12, 13`, shifts `(q=15, rope=7, pv=12)`, no pad group);
* `planesK_u1`, `valsXK_u1`, `lksK_u1`, **`xcKvzcU1`**: `SC_KVZC`'s value list and LogUp batch
  entries past the RoPE clause (`6` `Dom::Kv` planes `33..38`, RoPE flip bit `17 - 7 = 10`, `3` pair
  helpers at `H` planes `14, 15, 16`, shifts `(k=15, v=16, rope=7)`, no pad group);
* `qmm_spSum_u1`, `pv_spSum_u1`, `kvmm_spSum_u1`: the four hosted slots' unmasked sums as multilinear
  extensions of `relMm` at their published claim points (`SC_PV` with `ipStd 7 5 15 1`);
* **`formAt_qzcU1`**, **`formAt_kvzcU1`**: lane L36's `FormAt` at hosts `15` and `16` for every
  `export_u1` layer `(cnA, cnM)`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1Base
import ZK60Formal.BlockHostQkv

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt mleAt_append eqPoly_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg hPl hTab_eval tabK_ph_cpt tabK_pa_cpt eqT_eval pubT_eval paT paT_eval
  cstK cstS_map lkRels_congr lksS_eval sum_append formAt_two eqDr mleAt_append_bits)
open ZK60.Exec.Block.Join.W16.Qkv (drs drs_length drs_getD eval_self eval_hist drs_map_hist
  flC flT flT_eval flipB hT fxT tabK_fl_cpt rQ kQ shQ rK kK shK mleAt_app' mleAt_bits_append
  eqv cstK_pow cstK_negpow cstK_p16_zero mm_spSum pv_sum)
open ZK60.Exec.Block.Join.R13H (plD plQ plK plS splitHQ splitGD splitQ splitK splitQ_append
  LayR gQ_oneR gK_oneR PubR PrecR)
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some gV_none L16 reqV batchV qzcIr qzcClauses qzcIr_eval QzcR
  QzcK mmIr mmIr_eval bilIr bilIr_eval LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (qzcIr_map mmIr_map bilIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Exec.Slot.W16R2 (segLn segOff shShieldW16U1)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## 1. Numbered table evaluation helpers and the six raw slots at `export_u1` -/

private theorem evA (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk off log m ext : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, ext⟩))
      = .priv ⟨.a, [(off, Fp2.one)], log, rhoAll log, aB + 2 * ak, ext⟩ :=
  aTab_eval ev pub off log ext (aB + 2 * ak)

private theorem evH (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk re im log m : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
        ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩))
      = .priv ⟨.h, [(re, Fp2.one), (im, fp2U)], log, rhoAll log, hB + 2 * hk, 0⟩ :=
  hTab_eval ev pub re im log (hB + 2 * hk)

private theorem evF (ev : Sym → Fp2) (pub : ℕ → List Fp2) (aB hB ioIn ioOut ak hk off log k m : ℕ) :
    TabS.eval ev pub (.priv (DefW16.setRow aB hB ioIn ioOut ak hk
        ⟨.a, [(off, false)], log, (List.range log).map (fun j => if j = k then CoordS.flip j else CoordS.rho j), m, 0⟩))
      = .priv ⟨.a, [(off, Fp2.one)], log, flC log k, aB + 2 * ak, 0⟩ :=
  flT_eval ev pub off log k (aB + 2 * ak)

/-- `SC_QZC`'s raw tables at `export_u1`: `eq(τ)`, `eq(SC_QMM's point)`, `eq(SC_PV's point)`, `cos`, `sin`,
the six `Dom::Q` planes (`27..32`), the flipped source (`flip` at bit `12`), and the three helpers (`11..13`). -/
def tabs15_u1 : List TabS :=
  [.eq (drs 15 6 19) 0, .eq (drs 5 0 19) 0, .eq (drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7) 0, .pub 0, .pub 0,
    paT (offU1 27) 19 0, paT (offU1 28) 19 0, paT (offU1 29) 19 0, paT (offU1 30) 19 0, paT (offU1 31) 19 0,
    paT (offU1 32) 19 0, flT (offU1 27) 19 12 0,
    hT (hOffU1 11).1 (hOffU1 11).2 19 0, hT (hOffU1 12).1 (hOffU1 12).2 19 0, hT (hOffU1 13).1 (hOffU1 13).2 19 0]

/-- `SC_QZC`'s raw slot at `export_u1`. -/
def raw15_u1 : SlotS :=
  ⟨tabs15_u1, qzcIr DefW16.cstS rQ kQ (lksS c0 shQ .Q) (drs 15 0 4) (drs 15 4 2)
      (fun j => Sym.pow Sym.zero j) [],
    [(5, .dr 15 4), (9, .dr 15 5)], [.dr 15 4, .dr 15 5]⟩

theorem raw15_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 15 = raw15_u1 := by
  rw [DefW16.rawSlot_shieldU1_ne14 cnA cnM 15 (by decide)]
  rfl

/-- `SC_QMM`'s, `SC_KMM`'s, and `SC_VMM`'s raw slot at `export_u1`: `Y` (plane `9`, log `19`) with `SC_QMM`'s
`r_q` (`7` draws) fixed and `12` inner variables, plus the folded weight table. -/
def rawMm_u1 : SlotS :=
  ⟨[fxT (offU1 9) 19 (drs 5 0 7) 12 0 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩

theorem raw5_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 5 = rawMm_u1 := rfl
theorem raw6_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 6 = rawMm_u1 := rfl
theorem raw7_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 7 = rawMm_u1 := rfl

theorem prog_mm_u1 (cnA cnM ioIn ioOut s : ℕ) (hs : s = 5 ∨ s = 6 ∨ s = 7) :
    ∃ mrow, (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD s SlotS.empty
      = ⟨[fxT (offU1 9) 19 (drs 5 0 7) 12 mrow 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := by
  obtain ⟨ak, hk, h⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut s (by omega)
  have hr : DefW16.rawSlot (cfgU1 cnA cnM) s = rawMm_u1 := by
    rcases hs with rfl | rfl | rfl
    · exact raw5_u1_eq cnA cnM
    · exact raw6_u1_eq cnA cnM
    · exact raw7_u1_eq cnA cnM
  rw [h, hr]
  exact ⟨_, rfl⟩

/-- `SC_PV`'s claim coordinates of `PP` at `export_u1`: `ρ0..2`, fixed `r_hj` (`2` draws), fixed `r_t` (`7` draws),
`ρ3..9`. -/
def ppCS_u1 : List CoordS :=
  DefW16.rhoC 0 3 ++ (drs 9 3 2).map CoordS.fixed ++ (drs 9 5 7).map CoordS.fixed ++ DefW16.rhoC 3 10

/-- `SC_PV`'s claim coordinates of `V` at `export_u1`: `ρ3..9`, `ρ0..2`, fixed `r_i` (`7` draws). -/
def vCS_u1 : List CoordS :=
  DefW16.rhoC 3 10 ++ DefW16.rhoC 0 3 ++ (drs 9 12 7).map CoordS.fixed

/-- `SC_PV`'s raw slot at `export_u1`: `eq(r_g)`, `PP` (plane `44`, log `19`), `V` (plane `35`, log `17`). -/
def rawPv_u1 : SlotS :=
  ⟨[.eq (drs 9 0 3) 0, .priv ⟨.a, [(offU1 44, false)], 19, ppCS_u1, 0, 0⟩,
      .priv ⟨.a, [(offU1 35, false)], 17, vCS_u1, 0, 1⟩],
    bilIr DefW16.cstS (some 0) 1 2, [], []⟩

theorem raw9_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 9 = rawPv_u1 := rfl

theorem prog_pv_u1 (cnA cnM ioIn ioOut : ℕ) :
    ∃ m1 m2, (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 9 SlotS.empty
      = ⟨[.eq (drs 9 0 3) 0, .priv ⟨.a, [(offU1 44, false)], 19, ppCS_u1, m1, 0⟩,
          .priv ⟨.a, [(offU1 35, false)], 17, vCS_u1, m2, 1⟩],
        bilIr DefW16.cstS (some 0) 1 2, [], []⟩ := by
  obtain ⟨ak, hk, h⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 9 (by norm_num)
  rw [h, raw9_u1_eq]
  exact ⟨_, _, rfl⟩

/-- `SC_KVZC`'s raw tables at `export_u1`: `eq(τ)`, `eq(SC_KMM's point)`, `eq(SC_VMM's point)`, `cos`, `sin`,
the six `Dom::Kv` planes (`33..38`), the flipped source (`flip` at bit `10`), and the three helpers (`14..16`). -/
def tabs16_u1 : List TabS :=
  [.eq (drs 16 6 17) 0, .eq (drs 5 0 7 ++ drs 6 0 10) 0, .eq (drs 5 0 7 ++ drs 7 0 10) 0, .pub 0, .pub 0,
    paT (offU1 33) 17 0, paT (offU1 34) 17 0, paT (offU1 35) 17 0, paT (offU1 36) 17 0, paT (offU1 37) 17 0,
    paT (offU1 38) 17 0, flT (offU1 33) 17 10 0,
    hT (hOffU1 14).1 (hOffU1 14).2 17 0, hT (hOffU1 15).1 (hOffU1 15).2 17 0, hT (hOffU1 16).1 (hOffU1 16).2 17 0]

/-- `SC_KVZC`'s raw slot at `export_u1`. -/
def raw16_u1 : SlotS :=
  ⟨tabs16_u1, qzcIr DefW16.cstS rK kK (lksS c0 shK .Kv) (drs 16 0 4) (drs 16 4 2)
      (fun j => Sym.pow Sym.zero j) [],
    [(6, .dr 16 4), (7, .dr 16 5)], [.dr 16 4, .dr 16 5]⟩

theorem raw16_u1_eq (cnA cnM : ℕ) : DefW16.rawSlot (cfgU1 cnA cnM) 16 = raw16_u1 := by
  rw [DefW16.rawSlot_shieldU1_ne14 cnA cnM 16 (by decide)]
  rfl

/-! ## 2. `SC_QZC` (host `15`): value list, IR, named relations, batch, and cube sum -/

section QVals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_QZC`'s private entries at a cube point (`export_u1`): the six `Dom::Q` planes (`27..32`), the flipped
source (`flip` at bit `12`), and the three LogUp pair helpers (`11..13`). -/
noncomputable def planesQ_u1 (P : BlockParams) (D : CmData K P) (b : Fin 19 → Bool) : List K :=
  [aPl U P D (offU1 27) 19 b, aPl U P D (offU1 28) 19 b, aPl U P D (offU1 29) 19 b, aPl U P D (offU1 30) 19 b,
    aPl U P D (offU1 31) 19 b, aPl U P D (offU1 32) 19 b, aPl U P D (offU1 27) 19 (flipB 12 b),
    hPl U P D (hOffU1 11).1 (hOffU1 11).2 19 b, hPl U P D (hOffU1 12).1 (hOffU1 12).2 19 b,
    hPl U P D (hOffU1 13).1 (hOffU1 13).2 19 b]

/-- **`SC_QZC`'s numbered value list at a cube point with the zero extension (`export_u1`).** -/
theorem qzc_vals_u1 (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin 19 → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map (tabK U P D 19 e (cpt 19 e b))
      = eqv U (drs 15 6 19) ev 19 b :: eqv U (drs 5 0 19) ev 19 b
        :: eqv U (drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7) ev 19 b
        :: ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U :: ((pub 1).getD (msbIndex 19 b) Fp2.zero).toK U
        :: planesQ_u1 U P D b := by
  have l0 : ((drs 15 6 19).map ev).length = 19 := drs_length _ _ _ ev
  have l1 : ((drs 5 0 19).map ev).length = 19 := drs_length _ _ _ ev
  have l2 : ((drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7).map ev).length = 19 := by simp [drs]
  simp only [tabs15_u1, paT, flT, hT, DefW16.numTabs, List.map_cons, List.map_nil, evA, evH, evF, eqT_eval,
    pubT_eval, Nat.zero_add]
  rw [tabK_eqFull_cpt U P D 19 e b _ l0, tabK_eqFull_cpt U P D 19 e b _ l1, tabK_eqFull_cpt U P D 19 e b _ l2,
    tabK_pub_cpt U P D 19 e b, tabK_pub_cpt U P D 19 e b, tabK_fl_cpt U P D hrl 19 e b 12 (by norm_num)]
  simp only [tabK_pa_cpt U P D hrl 19 e b 19 (by norm_num) rfl, tabK_ph_cpt U P D hrl 19 e b 19 (by norm_num) rfl,
    castB_rfl]
  rfl

/-- Off the zero extension the three `eq` entries of `SC_QZC` are `0`. -/
theorem qzc_off_u1 (P : BlockParams) (D : CmData K P) (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (b : Fin 19 → Bool) (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
        (tabK U P D 19 e (bpt 19 e b y))).getD 0 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
        (tabK U P D 19 e (bpt 19 e b y))).getD 1 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
        (tabK U P D 19 e (bpt 19 e b y))).getD 2 0 = 0 := by
  simp only [tabs15_u1, DefW16.numTabs, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D 19 e b y hy _ _, tabK_eq_off U P D 19 e b y hy _ _, tabK_eq_off U P D 19 e b y hy _ _⟩

/-- `SC_QZC`'s lookups at `export_u1`, read at a history and draws, in the field. -/
noncomputable def lksQ_u1 (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS c0 shQ .Q).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 15 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_QZC`'s IR read in the field (`export_u1`).** -/
theorem qzc_irEval_u1 (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((qzcIr DefW16.cstS rQ kQ (lksS c0 shQ .Q) (drs 15 0 4) (drs 15 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 15 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 12 (fun k => (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD (1 + k) 0)
              0 (lksQ_u1 U hist dr)
            + gV v none * batchV (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U))
              (qzcClauses (cstK U) rQ kQ v))
          (reqV (cstK U) v 15 5 [6]) (reqV (cstK U) v 12 9 [10]) := by
  rw [qzcIr_map, qzcIr_map, cstS_map, qzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

theorem lksQ_u1_pos (hist : Hist) (dr : List Fp2) : ∀ l ∈ lksQ_u1 U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  unfold lksQ_u1 lksS at hl
  simp only [List.map_map, List.mem_map, Function.comp] at hl
  obtain ⟨l0, -, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map, Function.comp] at ht
  obtain ⟨t0, -, rfl⟩ := ht
  simp only [shQ]
  omega

theorem lksQ_u1_length (hist : Hist) (dr : List Fp2) : (lksQ_u1 U hist dr).length = 6 := by
  unfold lksQ_u1 lksS
  simp only [List.length_map]
  decide

end QVals

/-- **`SC_QZC`'s value list without the draws (`export_u1`)**: the `eq` entries `0`, the public entries `B`'s,
then the six `Dom::Q` planes, the flipped source, and the three helpers. -/
noncomputable def valsXQ_u1 {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (b : Fin 19 → Bool) : List K :=
  0 :: 0 :: 0 :: algebraMap GF K (B.cosT (splitQ c0 b)) :: algebraMap GF K (B.sinT (splitQ c0 b))
    :: planesQ_u1 U P D b

/-- **`SC_QZC`'s batch entries past the RoPE clause (`export_u1`)**: LogUp's three pair-helper relations at the
cube point, read without the draws (entry `κ` for `1 ≤ κ < 4`). -/
noncomputable def xcQzcU1 {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 19 → Bool) : K :=
  (0 :: lkRels (cstK U) (valsXQ_u1 U P D Pb Lay B b) 12 0
    (lksQ_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD κ 0

private theorem append_splitQ_gen (b : Fin (R13H.nQ c0) → Bool) :
    Fin.append (splitQ c0 b).1 (Fin.append (Fin.append (splitQ c0 b).2.1.1 (splitQ c0 b).2.1.2) (splitQ c0 b).2.2)
      = b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · exact Fin.append_left _ _ i1
  · refine (Fin.append_right _ _ i2).trans ?_
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · refine (Fin.append_left _ _ i3).trans ?_
      refine Fin.addCases (fun i5 => ?_) (fun i6 => ?_) i3
      · exact Fin.append_left _ _ i5
      · exact Fin.append_right _ _ i6
    · exact Fin.append_right _ _ i4

theorem append_splitQ_u1 (b : Fin 19 → Bool) :
    Fin.append (splitQ c0 b).1 (Fin.append (Fin.append (splitQ c0 b).2.1.1 (splitQ c0 b).2.1.2) (splitQ c0 b).2.2)
      = b :=
  append_splitQ_gen b

private theorem append_flipQ_gen (b : Fin (R13H.nQ c0) → Bool) :
    Fin.append (splitQ c0 b).1 (Fin.append (Fin.append (splitQ c0 b).2.1.1 (splitQ c0 b).2.1.2)
      (Function.update (splitQ c0 b).2.2 ⟨0, by decide⟩ (!(splitQ c0 b).2.2 ⟨0, by decide⟩))) = flipB 12 b := by
  have hlt : c0.sh.lt = 7 := rfl
  have hkv : c0.sh.lkv = 3 := rfl
  have hlh : c0.sh.lh = 5 := rfl
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    have := i1.isLt
    unfold flipB
    rw [Fin.val_castAdd, ite_eq_right (by omega)]
    rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · rw [Fin.append_left]
      refine Fin.addCases (fun i5 => ?_) (fun i6 => ?_) i3
      · rw [Fin.append_left]
        have := i5.isLt
        unfold flipB
        simp only [Fin.val_natAdd, Fin.val_castAdd]
        rw [ite_eq_right (by omega)]
        rfl
      · rw [Fin.append_right]
        have := i6.isLt
        unfold flipB
        simp only [Fin.val_natAdd, Fin.val_castAdd]
        rw [ite_eq_right (by omega)]
        rfl
    · rw [Fin.append_right, Function.update_apply]
      unfold flipB
      simp only [Fin.val_natAdd]
      by_cases h : i4 = ⟨0, by decide⟩
      · subst h
        have h12 : c0.sh.lt + (R13H.nH c0 + (⟨0, by decide⟩ : Fin c0.sh.ldh).val) = 12 := rfl
        rw [ite_eq_left rfl, ite_eq_left h12]
        rfl
      · have hv : (i4 : ℕ) ≠ 0 := fun hv => h (Fin.ext hv)
        rw [ite_eq_right h, ite_eq_right (by omega)]
        rfl

theorem append_flipQ_u1 (b : Fin 19 → Bool) :
    Fin.append (splitQ c0 b).1 (Fin.append (Fin.append (splitQ c0 b).2.1.1 (splitQ c0 b).2.1.2)
      (Function.update (splitQ c0 b).2.2 ⟨0, by decide⟩ (!(splitQ c0 b).2.2 ⟨0, by decide⟩))) = flipB 12 b :=
  append_flipQ_gen b

section QRels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hX in
theorem alg_plD_u1 (off : ℕ) (x : CtU1 × CwU1) :
    algebraMap GF K (plD U c0 P D off x) = aPl U P D off 19 (Fin.append x.1 x.2) :=
  aPl_alg U P D hX off 19 _

include hX in
theorem alg_plQ_u1 (off : ℕ) (x : CtU1 × ((CgU1 × CjU1) × CdU1)) :
    algebraMap GF K (plQ U c0 P D off x)
      = aPl U P D off 19 (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)) :=
  aPl_alg U P D hX off 19 _

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hX hL

/-- **`SC_QZC`'s RoPE clause, embedded (`export_u1`).** -/
theorem qzc_relCl_u1 (b : Fin 19 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 0 (.q (splitQ c0 b)))
      = algebraMap GF K (B.cosT (splitQ c0 b)) * aPl U P D (offU1 27) 19 b
        + algebraMap GF K (B.sinT (splitQ c0 b)) * aPl U P D (offU1 27) 19 (flipB 12 b)
        - 2 ^ 7 * aPl U P D (offU1 29) 19 b - aPl U P D (offU1 30) 19 b + 2 ^ 6 := by
  have hg := gQ_oneR B hL (splitQ c0 b)
  have hfl : Lay.flip (splitQ c0 b).2.2
      = Function.update (splitQ c0 b).2.2 ⟨0, by decide⟩ (!(splitQ c0 b).2.2 ⟨0, by decide⟩) :=
    hL.flip (by decide) (splitQ c0 b).2.2
  simp only [relCl, xtU1, hg, one_mul, hfl, remVal_le16 7 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ_u1 U P D hX, append_splitQ_u1, append_flipQ_u1]

/-- `SC_QZC`'s first hosted term, embedded (`export_u1`). -/
theorem qzc_relGh0_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 19 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 0 (.q (splitQ c0 b)))
      = 2 ^ 15 * aPl U P D (offU1 27) 19 b + aPl U P D (offU1 28) 19 b - 2 ^ 14 := by
  have hg := gQ_oneR B hL (splitQ c0 b)
  have hsq : S.sq = 15 := hS.sq
  have h14 : 15 - 1 = 14 := rfl
  simp only [relGh, xtU1, hg, one_mul, hsq, h14, remVal_le16 15 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ_u1 U P D hX, append_splitQ_u1]

/-- `SC_QZC`'s second hosted term, embedded (`export_u1`). -/
theorem qzc_relGh1_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 19 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 1 (.q (splitQ c0 b)))
      = 2 ^ 12 * aPl U P D (offU1 31) 19 b + aPl U P D (offU1 32) 19 b - 2 ^ 11 := by
  have hg := gQ_oneR B hL (splitQ c0 b)
  have hspv : S.spv = 12 := hS.spv
  have h11 : 12 - 1 = 11 := rfl
  simp only [relGh, xtU1, hg, one_mul, hspv, h11, remVal_le16 12 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ_u1 U P D hX, append_splitQ_u1]

/-- **`SC_QZC`'s IR clause is the named RoPE relation (`export_u1`).** -/
theorem qzc_clause_u1 (e0 e1 e2 : K) (b : Fin 19 → Bool) :
    qzcClauses (cstK U) rQ kQ (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c0 b))
      :: algebraMap GF K (B.sinT (splitQ c0 b)) :: planesQ_u1 U P D b)
      = [algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 0 (.q (splitQ c0 b)))] := by
  rw [qzc_relCl_u1 U P D hX Pb Lay B hL b]
  unfold qzcClauses
  rw [show kQ.rope = 7 from rfl, cstK_negpow U 7 (by norm_num), show 7 - 1 = 6 from rfl, cstK_pow U 6 (by norm_num)]
  simp only [rQ, L16, planesQ_u1, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  congr 1
  ring

/-- **`SC_QZC`'s IR hosted terms are the named requantizations (`export_u1`).** -/
theorem qzc_gh_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (e0 e1 e2 c s : K) (b : Fin 19 → Bool) :
    reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesQ_u1 U P D b) 15 5 [6]
        = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 0 (.q (splitQ c0 b)))
      ∧ reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesQ_u1 U P D b) 12 9 [10]
        = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 1 (.q (splitQ c0 b))) := by
  rw [qzc_relGh0_u1 U P D hX Pb Lay B hL cnA cnM hS b, qzc_relGh1_u1 U P D hX Pb Lay B hL cnA cnM hS b]
  unfold reqV
  rw [cstK_pow U 15 (by norm_num), cstK_pow U 12 (by norm_num), show 15 - 1 = 14 from rfl,
    show 12 - 1 = 11 from rfl, cstK_negpow U 14 (by norm_num), cstK_negpow U 11 (by norm_num)]
  simp only [L16, planesQ_u1, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  constructor <;> ring

/-- **`SC_QZC`'s batched relation at a cube point (`export_u1`).** -/
theorem qzc_Z_u1 (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (mu : List K) (e0 e1 e2 : K) (b : Fin 19 → Bool) :
    logupSem (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c0 b))
          :: algebraMap GF K (B.sinT (splitQ c0 b)) :: planesQ_u1 U P D b) 12 (fun k => mu.getD (1 + k) 0) 0
          (lksQ_u1 U hist dr)
        + gV (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c0 b))
          :: algebraMap GF K (B.sinT (splitQ c0 b)) :: planesQ_u1 U P D b) none
          * batchV mu (qzcClauses (cstK U) rQ kQ (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c0 b))
            :: algebraMap GF K (B.sinT (splitQ c0 b)) :: planesQ_u1 U P D b))
      = ∑ κ : Fin 4, mu.getD κ 0 * (if (κ : ℕ) < 1
          then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 κ (.q (splitQ c0 b)))
          else xcQzcU1 U P D Pb Lay B bga κ b) := by
  have hlk : lksQ_u1 U hist dr = lksQ_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksQ_u1
    rw [lksS_eval c0 shQ .Q hist (histOf bga.1 bga.2.1 bga.2.2 []) 15 15 dr [] ha hgm]
  have hcg : lkRels (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ c0 b))
        :: algebraMap GF K (B.sinT (splitQ c0 b)) :: planesQ_u1 U P D b) 12 0 (lksQ_u1 U hist dr)
      = lkRels (cstK U) (valsXQ_u1 U P D Pb Lay B b) 12 0 (lksQ_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) []) := by
    rw [hlk]
    refine lkRels_congr (cstK U) _ _ 12 0 _ (fun l hl t ht => ?_) (fun i _ => ?_)
    · have h3 := lksQ_u1_pos U _ _ l hl t ht
      obtain ⟨j, hj⟩ : ∃ j, t.2 = j + 3 := ⟨t.2 - 3, by omega⟩
      rw [hj]
      simp only [valsXQ_u1, List.getD_cons_succ]
    · rw [show 12 + (0 + i) = (9 + i) + 3 by omega]
      simp only [valsXQ_u1, List.getD_cons_succ]
  have hlen : (lkRels (cstK U) (valsXQ_u1 U P D Pb Lay B b) 12 0
      (lksQ_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 3 := by
    simp [lkRels_length, lksQ_u1_length]
  obtain ⟨x1, x2, x3, hx⟩ := List.length_eq_three.mp hlen
  have hxc : ∀ κ, xcQzcU1 U P D Pb Lay B bga κ b = ([0, x1, x2, x3] : List K).getD κ 0 := by
    intro κ
    unfold xcQzcU1
    rw [hx]
  rw [logupSem_eq_wsum, hcg, hx, qzc_clause_u1 U P D hX Pb Lay B hL, gV_none]
  rw [Fin.sum_univ_eq_sum_range (fun κ => mu.getD κ 0 * (if κ < 1
    then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 κ (.q (splitQ c0 b)))
    else xcQzcU1 U P D Pb Lay B bga κ b)) 4]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add, hxc, wsum, batchV, List.zipIdx_cons,
    List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ,
    List.getD_cons_zero, add_zero, one_mul]
  norm_num
  ring

/-- **`SC_QZC`'s cube sum at `export_u1`.** -/
theorem qzc_cube_u1 (hrl : 0 < rowLog P .a) (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S)
    (aB hB ioIn ioOut ak hk : ℕ) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2)
    (ha : hist.alpha = bga.2.2) (hgm : hist.gamma = bga.2.1) (pub : ℕ → List Fp2)
    (hcos : ∀ b, ((pub 0).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.cosT (splitQ c0 b)))
    (hsin : ∀ b, ((pub 1).getD (msbIndex 19 b) Fp2.zero).toK U = algebraMap GF K (B.sinT (splitQ c0 b)))
    (n e : ℕ) (hn : n = 19) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((qzcIr DefW16.cstS rQ kQ (lksS c0 shQ .Q) (drs 15 0 4) (drs 15 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 15 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map
        (TabS.eval (Sym.eval hist 15 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin 19 → Bool,
      hostPoly (fun a : Fin 19 => (((drs 15 6 19).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 4, (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 κ (.q (splitQ c0 t)))
            else xcQzcU1 U P D Pb Lay B bga κ t))
        ![(((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin 19 => (((drs 5 0 19).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U,
          fun a : Fin 19 => (((drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 i (.q (splitQ c0 t)))) t := by
  subst hn
  set ev := Sym.eval hist 15 dr with hev
  rw [cubeSum_host 19 e
    (fun x => ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map (tabK U P D 19 e x))
    0 1 2 none none (((drs 15 4 2).map ev).map (Fp2.toK U))
    (fun v => logupSem (cstK U) v 12 (fun k => (((drs 15 0 4).map ev).map (Fp2.toK U)).getD (1 + k) 0) 0
        (lksQ_u1 U hist dr)
      + gV v none * batchV (((drs 15 0 4).map ev).map (Fp2.toK U)) (qzcClauses (cstK U) rQ kQ v))
    (fun v => reqV (cstK U) v 15 5 [6]) (fun v => reqV (cstK U) v 12 9 [10]) f
    (fun x => by rw [hf x, qzc_irEval_u1 U hist dr])
    (fun b y hy => qzc_off_u1 U P D aB hB ioIn ioOut ak hk e ev pub b y hy)
    (fun a : Fin 19 => (((drs 15 6 19).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin 19 => (((drs 5 0 19).map ev).getD a Fp2.zero).toK U,
      fun a : Fin 19 => (((drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7).map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [qzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)
    (fun b => by rw [qzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)
    (fun b => by rw [qzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := qzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e t ev pub
  rw [hcos t, hsin t] at hv
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · show logupSem (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
        (tabK U P D 19 e (cpt 19 e t))) 12 _ 0 _
        + gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
          (tabK U P D 19 e (cpt 19 e t))) none * _ = _
    rw [hv]
    exact qzc_Z_u1 U P D hX Pb Lay B hL bga hist dr ha hgm _ _ _ _ t
  · obtain ⟨g0, g1⟩ := qzc_gh_u1 U P D hX Pb Lay B hL cnA cnM hS
      (eqv U (drs 15 6 19) ev 19 t) (eqv U (drs 5 0 19) ev 19 t)
      (eqv U (drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7) ev 19 t)
      (algebraMap GF K (B.cosT (splitQ c0 t))) (algebraMap GF K (B.sinT (splitQ c0 t))) t
    fin_cases i
    · show gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
          (tabK U P D 19 e (cpt 19 e t))) none
          * reqV (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
            (tabK U P D 19 e (cpt 19 e t))) 15 5 [6] = _
      rw [hv, gV_none, one_mul, g0]
    · show gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
          (tabK U P D 19 e (cpt 19 e t))) none
          * reqV (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs15_u1).map (TabS.eval ev pub)).map
            (tabK U P D 19 e (cpt 19 e t))) 12 9 [10] = _
      rw [hv, gV_none, one_mul, g1]

end QRels

/-! ## 3. Hosted slots of `SC_QZC`: `SC_QMM` (slot `5`) and `SC_PV` (slot `9`) -/

section Qmm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX hrl in
/-- **`SC_QMM`'s unmasked sum is the extension of `relMm 15 0` at its point (`export_u1`).** -/
theorem qmm_spSum_u1 (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubR U c0 pubs Pb Lay B)
    (hsh : slotShape P 5 = (12, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec)
    (hr : rs[5]? = some r) (hc : ∀ x ∈ r.draws, x.Canon) :
    spSum P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) bga rs 5
      = mleAt (fun y : Fin (7 + 12) → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 0 (.q (splitQ c0 y))))
          (fun t : Fin (7 + 12) => (r.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨mrow, hprog⟩ := prog_mm_u1 cnA cnM ioIn ioOut 5 (Or.inl rfl)
  rw [mm_spSum U P D hrl (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 5 (offU1 9) mrow 7 12 12 (drs 5 0 7)
    (by simp [drs]) (by rw [hsh]) (by norm_num) hprog bga rs r hr
    (fun c y => algebraMap GF K (B.Wq c (splitHQ c0 y)))
    (fun a => (r.draws.getD (7 + a) Fp2.zero).toK U) (fun c => hpub.wq _ _ hc c)]
  have hpt : Fin.append (fun i : Fin 7 => (((drs 5 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 5)) 5
      r.draws)).getD i Fp2.zero).toK U) (fun a : Fin 12 => (r.draws.getD (7 + a) Fp2.zero).toK U)
      = fun t : Fin (7 + 12) => (r.draws.getD t Fp2.zero).toK U := by
    funext t
    refine Fin.addCases (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left, drs_getD _ 5 0 7 i i.isLt, eval_self, Nat.zero_add]
      simp
    · rw [Fin.append_right]
      simp
  rw [hpt]
  congr 1
  funext y
  simp only [relMm, xtU1, map_sum, map_mul]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [alg_plD_u1 U P D hX]
  rfl

end Qmm

section Pv

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem ptPP_u1 (xr : ℕ → K) (ev : Sym → Fp2) :
    (fun a : Fin ((3 + 2) + (7 + 7)) => ptK U xr (ppCS_u1.map (CoordS.eval ev)) a)
      = Fin.append (Fin.append (fun i : Fin 3 => xr i) (fun i : Fin 2 => (ev (.dr 9 (3 + i))).toK U))
          (Fin.append (fun i : Fin 7 => (ev (.dr 9 (5 + i))).toK U) (fun i : Fin 7 => xr (3 + i))) := by
  funext a
  fin_cases a <;> rfl

theorem ptV_u1 (xr : ℕ → K) (ev : Sym → Fp2) :
    (fun a : Fin (7 + (3 + 7)) => ptK U xr (vCS_u1.map (CoordS.eval ev)) a)
      = Fin.append (fun i : Fin 7 => xr (3 + i))
          (Fin.append (fun i : Fin 3 => xr i) (fun i : Fin 7 => (ev (.dr 9 (12 + i))).toK U)) := by
  funext a
  fin_cases a <;> rfl

omit [Algebra GF K] in
theorem mle_pp_u1 (f : (Fin ((3 + 2) + (7 + 7)) → Bool) → K) (g : Fin 3 → Bool) (q : Fin 2 → K) (r : Fin 7 → K)
    (t' : Fin 7 → Bool) :
    mleAt f (Fin.append (Fin.append (fun i => bit (g i)) q) (Fin.append r (fun i => bit (t' i))))
      = ∑ z : Fin 2 → Bool, eqPoly q (fun i => bit (z i)) * ∑ w : Fin 7 → Bool, eqPoly r (fun i => bit (w i))
          * f (Fin.append (Fin.append g z) (Fin.append w t')) := by
  rw [mleAt_app', mleAt_bits_append]
  simp only [mleAt_append_bits]

omit [Algebra GF K] in
theorem mle_v_u1 (f : (Fin (7 + (3 + 7)) → Bool) → K) (t' : Fin 7 → Bool) (g : Fin 3 → Bool) (s : Fin 7 → K) :
    mleAt f (Fin.append (fun i => bit (t' i)) (Fin.append (fun i => bit (g i)) s))
      = ∑ c : Fin 7 → Bool, eqPoly s (fun i => bit (c i)) * f (Fin.append t' (Fin.append g c)) := by
  rw [mleAt_app', mleAt_bit, mleAt_bits_append]

/-- **`SC_PV`'s cube sum at `export_u1` (`n = 10` main variables).** -/
theorem pv_cube_u1 (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 10) (hist : Hist)
    (dr : List Fp2) (pub : ℕ → List Fp2) (m1 m2 : ℕ) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 9 dr)).map (Fp2.toK U))
      (([TabS.eq (drs 9 0 3) 0, .priv ⟨.a, [(offU1 44, false)], 19, ppCS_u1, m1, 0⟩,
          .priv ⟨.a, [(offU1 35, false)], 17, vCS_u1, m2, 1⟩].map
        (TabS.eval (Sym.eval hist 9 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin 3 → Bool, ∑ t' : Fin 7 → Bool,
      eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i))
        * ((∑ z : Fin 2 → Bool, eqPoly (fun i : Fin 2 => (dr.getD (3 + i) Fp2.zero).toK U) (fun i => bit (z i))
            * ∑ w : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (5 + i) Fp2.zero).toK U) (fun i => bit (w i))
              * aPl U P D (offU1 44) 19 (Fin.append (Fin.append g z) (Fin.append w t')))
          * (∑ c : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (12 + i) Fp2.zero).toK U) (fun i => bit (c i))
              * aPl U P D (offU1 35) 17 (Fin.append t' (Fin.append g c)))) := by
  subst hn
  set ev := Sym.eval hist 9 dr with hev
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map ev).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U), gV_some]
  rw [cubeSum_split]
  refine (sum_append (a := 3) (b := 7) _).trans (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl
    (fun t' _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 10 e (Fin.append g t')) = _
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
    have hx1 : ∀ i : Fin 3, xrK 10 (cpt (K := K) 10 e (Fin.append g t')) i = bit (g i) := by
      intro i
      rw [xrK_cpt, dite_eq_left (by omega), show (⟨(i : ℕ), by omega⟩ : Fin 10) = Fin.castAdd 7 i from rfl,
        Fin.append_left]
    have hx2 : ∀ i : Fin 7, xrK 10 (cpt (K := K) 10 e (Fin.append g t')) (3 + i) = bit (t' i) := by
      intro i
      rw [xrK_cpt, dite_eq_left (by omega), show (⟨3 + (i : ℕ), by omega⟩ : Fin 10) = Fin.natAdd 3 i from rfl,
        Fin.append_right]
    have h0 : tabK U P D 10 e (cpt 10 e (Fin.append g t')) (.eq ((drs 9 0 3).map ev) 0)
        = eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i)) := by
      rw [tabK_eqHead_cpt U P D 10 e _ _ 3 (drs_length _ _ _ ev) (by norm_num)]
      congr 1
      · funext a
        rw [drs_getD ev 9 0 3 a a.isLt, hev, eval_self, Nat.zero_add]
      · funext a
        rw [show (⟨(a : ℕ), by omega⟩ : Fin 10) = Fin.castAdd 7 a from rfl, Fin.append_left]
    have h1 : tabK U P D 10 e (cpt 10 e (Fin.append g t'))
          (TabS.eval ev pub (.priv ⟨.a, [(offU1 44, false)], 19, ppCS_u1, m1, 0⟩))
        = ∑ z : Fin 2 → Bool, eqPoly (fun i : Fin 2 => (dr.getD (3 + i) Fp2.zero).toK U) (fun i => bit (z i))
            * ∑ w : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (5 + i) Fp2.zero).toK U) (fun i => bit (w i))
              * aPl U P D (offU1 44) 19 (Fin.append (Fin.append g z) (Fin.append w t')) := by
      show tabK U P D 10 e (cpt 10 e (Fin.append g t'))
        (.priv ⟨.a, [(offU1 44, Fp2.one)], 19, ppCS_u1.map (CoordS.eval ev), m1, 0⟩) = _
      rw [tabK_priv_cpt U P D 10 e _ _ (by simp) (by norm_num) hrl]
      show mleAt (n := (3 + 2) + (7 + 7)) (aPl U P D (offU1 44) 19)
        (fun a : Fin ((3 + 2) + (7 + 7)) => ptK U (xrK 10 (cpt (K := K) 10 e (Fin.append g t')))
          (ppCS_u1.map (CoordS.eval ev)) a) = _
      rw [ptPP_u1 U (xrK 10 (cpt (K := K) 10 e (Fin.append g t'))) ev]
      simp only [hx1, hx2, hev, eval_self]
      exact mle_pp_u1 _ g _ _ t'
    have h2 : tabK U P D 10 e (cpt 10 e (Fin.append g t'))
          (TabS.eval ev pub (.priv ⟨.a, [(offU1 35, false)], 17, vCS_u1, m2, 1⟩))
        = ∑ c : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (12 + i) Fp2.zero).toK U) (fun i => bit (c i))
            * aPl U P D (offU1 35) 17 (Fin.append t' (Fin.append g c)) := by
      show tabK U P D 10 e (cpt 10 e (Fin.append g t'))
        (.priv ⟨.a, [(offU1 35, Fp2.one)], 17, vCS_u1.map (CoordS.eval ev), m2, 1⟩) = _
      rw [tabK_priv_cpt U P D 10 e _ _ (by simp) (by norm_num) hrl]
      show mleAt (n := 7 + (3 + 7)) (aPl U P D (offU1 35) 17)
        (fun a : Fin (7 + (3 + 7)) => ptK U (xrK 10 (cpt (K := K) 10 e (Fin.append g t')))
          (vCS_u1.map (CoordS.eval ev)) a) = _
      rw [ptV_u1 U (xrK 10 (cpt (K := K) 10 e (Fin.append g t'))) ev]
      simp only [hx1, hx2, hev, eval_self]
      exact mle_v_u1 _ t' g _
    rw [h0, h1, h2]
  · show f (bpt 10 e (Fin.append g t') y) = 0
    rw [hf, hir]
    simp only [List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D 10 e _ y hy, zero_mul]

end Pv

section PvT

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include hX in
private theorem pv_relMm_u1 (t : CtU1) (g : CgU1) (j : CjU1) (c : CdU1) :
    algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 1 (.q (t, ((g, j), c))))
      = ∑ t' : CtU1, aPl U P D (offU1 44) (R13H.nS c0) (Fin.append (Fin.append g j) (Fin.append t t'))
        * aPl U P D (offU1 35) (R13H.nK c0) (Fin.append t' (Fin.append g c)) := by
  simp only [relMm, xtU1, plS, plK, map_sum, map_mul]
  refine Finset.sum_congr rfl fun t' _ => ?_
  rw [aPl_alg U P D hX, aPl_alg U P D hX]

include hX in
/-- **`SC_PV`'s target at `export_u1`**: the extension of `relMm 15 1` at `SC_PV`'s published point. -/
theorem pv_target_u1 (dr : List Fp2) :
    mleAt (fun y : Fin (7 + ((3 + 2) + 7)) → Bool =>
        algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 1 (.q (splitQ c0 y))))
      (fun t : Fin (7 + ((3 + 2) + 7)) => (dr.getD (ZK60.Exec.Block.ipStd 7 5 15 1 t) Fp2.zero).toK U)
      = ∑ t : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (5 + i) Fp2.zero).toK U) (fun i => bit (t i))
        * ∑ g : Fin 3 → Bool, eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i))
          * ∑ j : Fin 2 → Bool, eqPoly (fun i : Fin 2 => (dr.getD (3 + i) Fp2.zero).toK U) (fun i => bit (j i))
            * ∑ c : Fin 7 → Bool, eqPoly (fun i : Fin 7 => (dr.getD (12 + i) Fp2.zero).toK U) (fun i => bit (c i))
              * ∑ t' : Fin 7 → Bool, aPl U P D (offU1 44) 19 (Fin.append (Fin.append g j) (Fin.append t t'))
                * aPl U P D (offU1 35) 17 (Fin.append t' (Fin.append g c)) := by
  have hpt : (fun t : Fin (7 + ((3 + 2) + 7)) => (dr.getD (ZK60.Exec.Block.ipStd 7 5 15 1 t) Fp2.zero).toK U)
      = Fin.append (fun i : Fin 7 => (dr.getD (5 + i) Fp2.zero).toK U)
          (Fin.append (Fin.append (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U)
            (fun i : Fin 2 => (dr.getD (3 + i) Fp2.zero).toK U))
            (fun i : Fin 7 => (dr.getD (12 + i) Fp2.zero).toK U)) := by
    funext t
    fin_cases t <;> rfl
  rw [hpt]
  simp only [mleAt_app']
  unfold mleAt
  refine Finset.sum_congr rfl fun t _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun g _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun j _ => ?_
  congr 1
  refine Finset.sum_congr rfl fun c _ => ?_
  congr 1
  beta_reduce
  exact (congrArg (fun q => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 1 (.q q)))
    (splitQ_append c0 (t, ((g, j), c)))).trans (pv_relMm_u1 U P D hX Pb Lay B t g j c)

include hX hrl in
/-- **`SC_PV`'s unmasked sum is the extension of `relMm 15 1` at its published point (`export_u1`).** -/
theorem pv_spSum_u1 (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hsh : slotShape P 9 = (10, 2, 3)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec)
    (hr : rs[9]? = some r) :
    spSum P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs) bga rs 9
      = mleAt (fun y : Fin (7 + ((3 + 2) + 7)) → Bool =>
          algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 1 (.q (splitQ c0 y))))
        (fun t : Fin (7 + ((3 + 2) + 7)) => (r.draws.getD (ZK60.Exec.Block.ipStd 7 5 15 1 t) Fp2.zero).toK U) := by
  obtain ⟨m1, m2, hprog⟩ := prog_pv_u1 cnA cnM ioIn ioOut
  unfold spSum
  rw [pv_cube_u1 U P D hrl (slotShape P 9).1 (slotShape P 9).2.1 (by rw [hsh])
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9)) r.draws (pubs 9 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9)) r.draws)
    m1 m2 (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 9 (seenOf bga rs 9))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 9 r hr x, hprog]),
    pv_target_u1 U P D hX Pb Lay B r.draws]
  exact pv_sum
    (fun g : Fin 3 → Bool => eqPoly (fun i : Fin 3 => (r.draws.getD i Fp2.zero).toK U) (fun i => bit (g i)))
    (fun j : Fin 2 → Bool => eqPoly (fun i : Fin 2 => (r.draws.getD (3 + i) Fp2.zero).toK U) (fun i => bit (j i)))
    (fun t : Fin 7 → Bool => eqPoly (fun i : Fin 7 => (r.draws.getD (5 + i) Fp2.zero).toK U) (fun i => bit (t i)))
    (fun c : Fin 7 → Bool => eqPoly (fun i : Fin 7 => (r.draws.getD (12 + i) Fp2.zero).toK U) (fun i => bit (c i)))
    (fun g j t t' => aPl U P D (offU1 44) 19 (Fin.append (Fin.append g j) (Fin.append t t')))
    (fun t' g c => aPl U P D (offU1 35) 17 (Fin.append t' (Fin.append g c)))

end PvT

/-! ## 4. `SC_QZC`'s named identity (`formAt_qzcU1`) -/

/-- **L36's `FormAt` at host `15` (`SC_QZC`) at `export_u1`**, parametric in `(cnA, cnM)`: for every algebra
data `dt` whose host-15 tables are the relation tables (the RoPE clause, LogUp's three pair-helper relations
`xcQzcU1`, the requantizations, and the contractions), on every outcome whose verified slots passed their checks. -/
theorem formAt_qzcU1 {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 4) (b : Fin 19 → Bool), dt.cl 15 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 15 κ (.q (splitQ c0 b)))
        else xcQzcU1 U P D Pb Lay B bga κ b)
    (hgh : ∀ (i : Fin 2) (b : Fin 19 → Bool),
      dt.gh 15 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 15 i (.q (splitQ c0 b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 19 → Bool),
      dt.mm 15 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 i (.q (splitQ c0 b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hcard 0 cu rt k h).Φ) bga rs 15 := by
  obtain ⟨hs15, hs5, hs9⟩ : slotShape P 15 = (19, 1, 4) ∧ slotShape P 5 = (12, 1, 2) ∧ slotShape P 9 = (10, 2, 3) := by
    simp only [slotShape, hsl]
    decide
  obtain ⟨ak, hk', hslot15⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 15 (by norm_num)
  have hprog15 : (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 15 SlotS.empty
      = DefW16.numSlot (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak hk'
        raw15_u1 := by
    rw [hslot15, raw15_u1_eq]
  have hp5 : ((DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 5 SlotS.empty).hosted = [] := by
    obtain ⟨m, hm⟩ := prog_mm_u1 cnA cnM ioIn ioOut 5 (Or.inl rfl)
    exact (congrArg SlotS.hosted hm).trans rfl
  have hp9 : ((DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 9 SlotS.empty).hosted = [] := by
    obtain ⟨m1, m2, hm⟩ := prog_pv_u1 cnA cnM ioIn ioOut
    exact (congrArg SlotS.hosted hm).trans rfl
  refine formAt_two U hcard P (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D _ dt cu rt bga rs 15
    (by decide) 5 9 (.dr 15 4) (.dr 15 5) ((congrArg SlotS.hosted hprog15).trans rfl) hp5 hp9
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 15 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r5, hr5⟩ : ∃ r5, rs[5]? = some r5 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r9, hr9⟩ : ∃ r9, rs[9]? = some r9 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    rw [hdef] at hdf
    exact (defineS_ok hdf).1.2.2.2
  have hsp15 := qzc_cube_u1 U P D hX Pb Lay B hLay hrl cnA cnM hS
    (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak hk'
    ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).beta, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).gamma,
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws rfl rfl
    (pubs 15 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws)
    (hpub.qzcCos (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws)
    (hpub.qzcSin (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws) (slotShape P 15).1 (slotShape P 15).2.1
    (by rw [hs15]) (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 15 (seenOf bga rs 15))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 15 r hr x, hprog15]; rfl)
  have hsp5 := qmm_spSum_u1 U P D hX hrl Pb Lay B cnA cnM ioIn ioOut pubs hpub hs5 bga rs r5 hr5 (hcan 5 r5 hr5)
  have hsp9 := pv_spSum_u1 U P D hX hrl Pb Lay B cnA cnM ioIn ioOut pubs hs9 bga rs r9 hr9
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 15) with hhist
  have hmuK : ∀ j : ℕ, j < 4 → (((drs 15 0 4).map (Sym.eval hist 15 r.draws)).map (Fp2.toK U)).getD j 0
      = (r.draws.getD j Fp2.zero).toK U := by
    intro j hj
    interval_cases j <;> rfl
  rw [hostSp_Φ]
  unfold hostPhi
  rw [hsp5, hsp9]
  unfold spSum
  rw [hsp15]
  refine congrArg₂ (· - ·) ?_ ?_
  · refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · unfold segAt
      have ha : (a : ℕ) < 19 := a.isLt
      rw [dite_eq_left (by show 6 + (a : ℕ) < 25; omega), drs_getD _ 15 6 19 a ha, eval_self]
      first | done | rfl
    · unfold batched
      have hz : segLn ((algShapeU1 P hdr).dl 15) .zeta = 0 := rfl
      simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      have hκ : (κ : ℕ) < 4 := κ.isLt
      rw [hcl (hist.beta, hist.gamma, hist.alpha) κ t, hmuK κ hκ]
      refine congrArg₂ (· * ·) ?_ rfl
      unfold segAt
      rw [dite_eq_left (by show 0 + (κ : ℕ) < 25; omega)]
      show (r.draws.getD (0 + (κ : ℕ)) Fp2.zero).toK U = _
      rw [Nat.zero_add]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by show 4 + 0 < 25; omega)]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 4 + 1 < 25; omega)]
        first | done | rfl
    · fin_cases i
      · show algDrawAt U hist 5 (ZK60.Exec.Block.ipStd 7 5 15 0 j)
          = (((drs 5 0 19).map (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        rw [show ZK60.Exec.Block.ipStd 7 5 15 0 j = (j : ℕ) from rfl,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5,
          drs_map_hist bga rs 15 5 r.draws r5 (by decide) hr5 0 19 hist, drs_getD _ 5 0 19 j j.isLt, eval_self,
          Nat.zero_add]
      · show algDrawAt U hist 9 (ZK60.Exec.Block.ipStd 7 5 15 1 j)
          = (((drs 9 5 7 ++ drs 9 0 5 ++ drs 9 12 7).map (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, List.map_append, drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 5 7 hist,
          drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 0 5 hist,
          drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 12 7 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 19 := hj
        interval_cases jv <;> rfl
    · rw [algH_gh U _ dt 15 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeU1 P hdr) dt 15 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 15 i (.q (splitQ c0 b))) := fun i => by
      rw [algM_mm _ dt 15 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeU1 P hdr) 15 hist 0
        = fun t : Fin (segLn ((algShapeU1 P hdr).dl 15) .tau) => (r5.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 5 (ZK60.Exec.Block.ipStd 7 5 15 0 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5
    have hp1 : algPt U (algShapeU1 P hdr) 15 hist 1
        = fun t : Fin (segLn ((algShapeU1 P hdr).dl 15) .tau) =>
          (r9.draws.getD (ZK60.Exec.Block.ipStd 7 5 15 1 t) Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 9 (ZK60.Exec.Block.ipStd 7 5 15 1 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 0 < 25; omega)]
      first | done | rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 1 < 25; omega)]
      first | done | rfl

/-! ## 5. `SC_KVZC` (host `16`): value list, IR, named relations, batch, cube sum, and hosted matmuls -/

section KVals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_KVZC`'s private entries at a cube point (`export_u1`): the six `Dom::Kv` planes (`33..38`), the flipped
source (`flip` at bit `10`), and the three LogUp pair helpers (`14..16`). -/
noncomputable def planesK_u1 (P : BlockParams) (D : CmData K P) (b : Fin 17 → Bool) : List K :=
  [aPl U P D (offU1 33) 17 b, aPl U P D (offU1 34) 17 b, aPl U P D (offU1 35) 17 b, aPl U P D (offU1 36) 17 b,
    aPl U P D (offU1 37) 17 b, aPl U P D (offU1 38) 17 b, aPl U P D (offU1 33) 17 (flipB 10 b),
    hPl U P D (hOffU1 14).1 (hOffU1 14).2 17 b, hPl U P D (hOffU1 15).1 (hOffU1 15).2 17 b,
    hPl U P D (hOffU1 16).1 (hOffU1 16).2 17 b]

/-- **`SC_KVZC`'s numbered value list at a cube point with the zero extension (`export_u1`).** -/
theorem kvzc_vals_u1 (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin 17 → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map (tabK U P D 17 e (cpt 17 e b))
      = eqv U (drs 16 6 17) ev 17 b :: eqv U (drs 5 0 7 ++ drs 6 0 10) ev 17 b
        :: eqv U (drs 5 0 7 ++ drs 7 0 10) ev 17 b
        :: ((pub 0).getD (msbIndex 17 b) Fp2.zero).toK U :: ((pub 1).getD (msbIndex 17 b) Fp2.zero).toK U
        :: planesK_u1 U P D b := by
  have l0 : ((drs 16 6 17).map ev).length = 17 := drs_length _ _ _ ev
  have l1 : ((drs 5 0 7 ++ drs 6 0 10).map ev).length = 17 := by simp [drs]
  have l2 : ((drs 5 0 7 ++ drs 7 0 10).map ev).length = 17 := by simp [drs]
  simp only [tabs16_u1, paT, flT, hT, DefW16.numTabs, List.map_cons, List.map_nil, evA, evH, evF, eqT_eval,
    pubT_eval, Nat.zero_add]
  rw [tabK_eqFull_cpt U P D 17 e b _ l0, tabK_eqFull_cpt U P D 17 e b _ l1, tabK_eqFull_cpt U P D 17 e b _ l2,
    tabK_pub_cpt U P D 17 e b, tabK_pub_cpt U P D 17 e b, tabK_fl_cpt U P D hrl 17 e b 10 (by norm_num)]
  simp only [tabK_pa_cpt U P D hrl 17 e b 17 (by norm_num) rfl, tabK_ph_cpt U P D hrl 17 e b 17 (by norm_num) rfl,
    castB_rfl]
  rfl

/-- Off the zero extension the three `eq` entries of `SC_KVZC` are `0`. -/
theorem kvzc_off_u1 (P : BlockParams) (D : CmData K P) (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (b : Fin 17 → Bool) (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
        (tabK U P D 17 e (bpt 17 e b y))).getD 0 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
        (tabK U P D 17 e (bpt 17 e b y))).getD 1 0 = 0
      ∧ (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
        (tabK U P D 17 e (bpt 17 e b y))).getD 2 0 = 0 := by
  simp only [tabs16_u1, DefW16.numTabs, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D 17 e b y hy _ _, tabK_eq_off U P D 17 e b y hy _ _, tabK_eq_off U P D 17 e b y hy _ _⟩

/-- `SC_KVZC`'s lookups at `export_u1`, read at a history and draws, in the field. -/
noncomputable def lksK_u1 (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS c0 shK .Kv).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 16 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_KVZC`'s IR read in the field (`export_u1`).** -/
theorem kvzc_irEval_u1 (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((qzcIr DefW16.cstS rK kK (lksS c0 shK .Kv) (drs 16 0 4) (drs 16 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 16 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 12 (fun k => (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD (1 + k) 0)
              0 (lksK_u1 U hist dr)
            + gV v none * batchV (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U))
              (qzcClauses (cstK U) rK kK v))
          (reqV (cstK U) v 15 5 [6]) (reqV (cstK U) v 16 7 [8]) := by
  rw [qzcIr_map, qzcIr_map, cstS_map, qzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

theorem lksK_u1_pos (hist : Hist) (dr : List Fp2) : ∀ l ∈ lksK_u1 U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  unfold lksK_u1 lksS at hl
  simp only [List.map_map, List.mem_map, Function.comp] at hl
  obtain ⟨l0, -, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map, Function.comp] at ht
  obtain ⟨t0, -, rfl⟩ := ht
  simp only [shK]
  omega

theorem lksK_u1_length (hist : Hist) (dr : List Fp2) : (lksK_u1 U hist dr).length = 6 := by
  unfold lksK_u1 lksS
  simp only [List.length_map]
  decide

end KVals

/-- **`SC_KVZC`'s value list without the draws (`export_u1`).** -/
noncomputable def valsXK_u1 {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (b : Fin 17 → Bool) : List K :=
  0 :: 0 :: 0 :: algebraMap GF K (B.cosK (splitK c0 b)) :: algebraMap GF K (B.sinK (splitK c0 b))
    :: planesK_u1 U P D b

/-- **`SC_KVZC`'s batch entries past the RoPE clause (`export_u1`)**: LogUp's three pair-helper relations at the
cube point, read without the draws (entry `κ` for `1 ≤ κ < 4`). -/
noncomputable def xcKvzcU1 {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 17 → Bool) : K :=
  (0 :: lkRels (cstK U) (valsXK_u1 U P D Pb Lay B b) 12 0
    (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD κ 0

private theorem append_splitK_gen (b : Fin (R13H.nK c0) → Bool) :
    Fin.append (splitK c0 b).1 (Fin.append (splitK c0 b).2.1 (splitK c0 b).2.2) = b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · exact Fin.append_left _ _ i1
  · refine (Fin.append_right _ _ i2).trans ?_
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · exact Fin.append_left _ _ i3
    · exact Fin.append_right _ _ i4

theorem append_splitK_u1 (b : Fin 17 → Bool) :
    Fin.append (splitK c0 b).1 (Fin.append (splitK c0 b).2.1 (splitK c0 b).2.2) = b :=
  append_splitK_gen b

private theorem append_flipK_gen (b : Fin (R13H.nK c0) → Bool) :
    Fin.append (splitK c0 b).1 (Fin.append (splitK c0 b).2.1
      (Function.update (splitK c0 b).2.2 ⟨0, by decide⟩ (!(splitK c0 b).2.2 ⟨0, by decide⟩))) = flipB 10 b := by
  have hlt : c0.sh.lt = 7 := rfl
  have hkv : c0.sh.lkv = 3 := rfl
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]
    have := i1.isLt
    unfold flipB
    rw [Fin.val_castAdd, ite_eq_right (by omega)]
    rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun i3 => ?_) (fun i4 => ?_) i2
    · rw [Fin.append_left]
      have := i3.isLt
      unfold flipB
      simp only [Fin.val_natAdd, Fin.val_castAdd]
      rw [ite_eq_right (by omega)]
      rfl
    · rw [Fin.append_right, Function.update_apply]
      unfold flipB
      simp only [Fin.val_natAdd]
      by_cases h : i4 = ⟨0, by decide⟩
      · subst h
        have h10 : c0.sh.lt + (c0.sh.lkv + (⟨0, by decide⟩ : Fin c0.sh.ldh).val) = 10 := rfl
        rw [ite_eq_left rfl, ite_eq_left h10]
        rfl
      · have hv : (i4 : ℕ) ≠ 0 := fun hv => h (Fin.ext hv)
        rw [ite_eq_right h, ite_eq_right (by omega)]
        rfl

theorem append_flipK_u1 (b : Fin 17 → Bool) :
    Fin.append (splitK c0 b).1 (Fin.append (splitK c0 b).2.1
      (Function.update (splitK c0 b).2.2 ⟨0, by decide⟩ (!(splitK c0 b).2.2 ⟨0, by decide⟩))) = flipB 10 b :=
  append_flipK_gen b

section KRels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hX in
theorem alg_plK_u1 (off : ℕ) (x : CtU1 × (CgU1 × CdU1)) :
    algebraMap GF K (plK U c0 P D off x)
      = aPl U P D off 17 (Fin.append x.1 (Fin.append x.2.1 x.2.2)) :=
  aPl_alg U P D hX off 17 _

variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay) (hL : LayR Lay)

include hX hL

theorem kvzc_relCl_u1 (b : Fin 17 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 0 (.kv (splitK c0 b)))
      = algebraMap GF K (B.cosK (splitK c0 b)) * aPl U P D (offU1 33) 17 b
        + algebraMap GF K (B.sinK (splitK c0 b)) * aPl U P D (offU1 33) 17 (flipB 10 b)
        - 2 ^ 7 * aPl U P D (offU1 37) 17 b - aPl U P D (offU1 38) 17 b + 2 ^ 6 := by
  have hg := gK_oneR B hL (splitK c0 b)
  have hfl : Lay.flip (splitK c0 b).2.2
      = Function.update (splitK c0 b).2.2 ⟨0, by decide⟩ (!(splitK c0 b).2.2 ⟨0, by decide⟩) :=
    hL.flip (by decide) (splitK c0 b).2.2
  simp only [relCl, xtU1, hg, one_mul, hfl, remVal_le16 7 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK_u1 U P D hX, append_splitK_u1, append_flipK_u1]

theorem kvzc_relGh0_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 17 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 0 (.kv (splitK c0 b)))
      = 2 ^ 15 * aPl U P D (offU1 33) 17 b + aPl U P D (offU1 34) 17 b - 2 ^ 14 := by
  have hg := gK_oneR B hL (splitK c0 b)
  have hsk : S.sk = 15 := hS.sk
  have h14 : 15 - 1 = 14 := rfl
  simp only [relGh, xtU1, hg, one_mul, hsk, h14, remVal_le16 15 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK_u1 U P D hX, append_splitK_u1]

theorem kvzc_relGh1_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (b : Fin 17 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 1 (.kv (splitK c0 b)))
      = 2 ^ 16 * aPl U P D (offU1 35) 17 b + aPl U P D (offU1 36) 17 b - 2 ^ 15 := by
  have hg := gK_oneR B hL (splitK c0 b)
  have hsv : S.sv = 16 := hS.sv
  have h15 : 16 - 1 = 15 := rfl
  simp only [relGh, xtU1, hg, one_mul, hsv, h15, remVal_le16 16 (by norm_num), remR_lo1]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK_u1 U P D hX, append_splitK_u1]

theorem kvzc_clause_u1 (e0 e1 e2 : K) (b : Fin 17 → Bool) :
    qzcClauses (cstK U) rK kK (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c0 b))
      :: algebraMap GF K (B.sinK (splitK c0 b)) :: planesK_u1 U P D b)
      = [algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 0 (.kv (splitK c0 b)))] := by
  rw [kvzc_relCl_u1 U P D hX Pb Lay B hL b]
  unfold qzcClauses
  rw [show kK.rope = 7 from rfl, cstK_negpow U 7 (by norm_num), show 7 - 1 = 6 from rfl, cstK_pow U 6 (by norm_num)]
  simp only [rK, L16, planesK_u1, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  congr 1
  ring

theorem kvzc_gh_u1 (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S) (e0 e1 e2 c s : K) (b : Fin 17 → Bool) :
    reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesK_u1 U P D b) 15 5 [6]
        = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 0 (.kv (splitK c0 b)))
      ∧ reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesK_u1 U P D b) 16 7 [8]
        = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 1 (.kv (splitK c0 b))) := by
  rw [kvzc_relGh0_u1 U P D hX Pb Lay B hL cnA cnM hS b, kvzc_relGh1_u1 U P D hX Pb Lay B hL cnA cnM hS b]
  unfold reqV
  rw [cstK_pow U 15 (by norm_num), cstK_pow U 16 (by norm_num), show 15 - 1 = 14 from rfl,
    show 16 - 1 = 15 from rfl, cstK_negpow U 14 (by norm_num), cstK_negpow U 15 (by norm_num)]
  simp only [L16, planesK_u1, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  constructor <;> ring

theorem kvzc_Z_u1 (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (mu : List K) (e0 e1 e2 : K) (b : Fin 17 → Bool) :
    logupSem (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c0 b))
          :: algebraMap GF K (B.sinK (splitK c0 b)) :: planesK_u1 U P D b) 12 (fun k => mu.getD (1 + k) 0) 0
          (lksK_u1 U hist dr)
        + gV (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c0 b))
          :: algebraMap GF K (B.sinK (splitK c0 b)) :: planesK_u1 U P D b) none
          * batchV mu (qzcClauses (cstK U) rK kK (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c0 b))
            :: algebraMap GF K (B.sinK (splitK c0 b)) :: planesK_u1 U P D b))
      = ∑ κ : Fin 4, mu.getD κ 0 * (if (κ : ℕ) < 1
          then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 κ (.kv (splitK c0 b)))
          else xcKvzcU1 U P D Pb Lay B bga κ b) := by
  have hlk : lksK_u1 U hist dr = lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksK_u1
    rw [lksS_eval c0 shK .Kv hist (histOf bga.1 bga.2.1 bga.2.2 []) 16 16 dr [] ha hgm]
  have hcg : lkRels (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK c0 b))
        :: algebraMap GF K (B.sinK (splitK c0 b)) :: planesK_u1 U P D b) 12 0 (lksK_u1 U hist dr)
      = lkRels (cstK U) (valsXK_u1 U P D Pb Lay B b) 12 0 (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) []) := by
    rw [hlk]
    refine lkRels_congr (cstK U) _ _ 12 0 _ (fun l hl t ht => ?_) (fun i _ => ?_)
    · have h3 := lksK_u1_pos U _ _ l hl t ht
      obtain ⟨j, hj⟩ : ∃ j, t.2 = j + 3 := ⟨t.2 - 3, by omega⟩
      rw [hj]
      simp only [valsXK_u1, List.getD_cons_succ]
    · rw [show 12 + (0 + i) = (9 + i) + 3 by omega]
      simp only [valsXK_u1, List.getD_cons_succ]
  have hlen : (lkRels (cstK U) (valsXK_u1 U P D Pb Lay B b) 12 0
      (lksK_u1 U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 3 := by
    simp [lkRels_length, lksK_u1_length]
  obtain ⟨x1, x2, x3, hx⟩ := List.length_eq_three.mp hlen
  have hxc : ∀ κ, xcKvzcU1 U P D Pb Lay B bga κ b = ([0, x1, x2, x3] : List K).getD κ 0 := by
    intro κ
    unfold xcKvzcU1
    rw [hx]
  rw [logupSem_eq_wsum, hcg, hx, kvzc_clause_u1 U P D hX Pb Lay B hL, gV_none]
  rw [Fin.sum_univ_eq_sum_range (fun κ => mu.getD κ 0 * (if κ < 1
    then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 κ (.kv (splitK c0 b)))
    else xcKvzcU1 U P D Pb Lay B bga κ b)) 4]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add, hxc, wsum, batchV, List.zipIdx_cons,
    List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ,
    List.getD_cons_zero, add_zero, one_mul]
  norm_num
  ring

/-- **`SC_KVZC`'s cube sum at `export_u1`.** -/
theorem kvzc_cube_u1 (hrl : 0 < rowLog P .a) (cnA cnM : ℕ) (hS : PrecR (cfgU1 cnA cnM) S)
    (aB hB ioIn ioOut ak hk : ℕ) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2)
    (ha : hist.alpha = bga.2.2) (hgm : hist.gamma = bga.2.1) (pub : ℕ → List Fp2)
    (hcos : ∀ b, ((pub 0).getD (msbIndex 17 b) Fp2.zero).toK U = algebraMap GF K (B.cosK (splitK c0 b)))
    (hsin : ∀ b, ((pub 1).getD (msbIndex 17 b) Fp2.zero).toK U = algebraMap GF K (B.sinK (splitK c0 b)))
    (n e : ℕ) (hn : n = 17) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((qzcIr DefW16.cstS rK kK (lksS c0 shK .Kv) (drs 16 0 4) (drs 16 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 16 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map
        (TabS.eval (Sym.eval hist 16 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin 17 → Bool,
      hostPoly (fun a : Fin 17 => (((drs 16 6 17).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 4, (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 κ (.kv (splitK c0 t)))
            else xcKvzcU1 U P D Pb Lay B bga κ t))
        ![(((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin 17 => (((drs 5 0 7 ++ drs 6 0 10).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U,
          fun a : Fin 17 => (((drs 5 0 7 ++ drs 7 0 10).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 i (.kv (splitK c0 t)))) t := by
  subst hn
  set ev := Sym.eval hist 16 dr with hev
  rw [cubeSum_host 17 e
    (fun x => ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map (tabK U P D 17 e x))
    0 1 2 none none (((drs 16 4 2).map ev).map (Fp2.toK U))
    (fun v => logupSem (cstK U) v 12 (fun k => (((drs 16 0 4).map ev).map (Fp2.toK U)).getD (1 + k) 0) 0
        (lksK_u1 U hist dr)
      + gV v none * batchV (((drs 16 0 4).map ev).map (Fp2.toK U)) (qzcClauses (cstK U) rK kK v))
    (fun v => reqV (cstK U) v 15 5 [6]) (fun v => reqV (cstK U) v 16 7 [8]) f
    (fun x => by rw [hf x, kvzc_irEval_u1 U hist dr])
    (fun b y hy => kvzc_off_u1 U P D aB hB ioIn ioOut ak hk e ev pub b y hy)
    (fun a : Fin 17 => (((drs 16 6 17).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin 17 => (((drs 5 0 7 ++ drs 6 0 10).map ev).getD a Fp2.zero).toK U,
      fun a : Fin 17 => (((drs 5 0 7 ++ drs 7 0 10).map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [kvzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)
    (fun b => by rw [kvzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)
    (fun b => by rw [kvzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e b ev pub]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := kvzc_vals_u1 U P D hrl aB hB ioIn ioOut ak hk e t ev pub
  rw [hcos t, hsin t] at hv
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · show logupSem (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
        (tabK U P D 17 e (cpt 17 e t))) 12 _ 0 _
        + gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
          (tabK U P D 17 e (cpt 17 e t))) none * _ = _
    rw [hv]
    exact kvzc_Z_u1 U P D hX Pb Lay B hL bga hist dr ha hgm _ _ _ _ t
  · obtain ⟨g0, g1⟩ := kvzc_gh_u1 U P D hX Pb Lay B hL cnA cnM hS
      (eqv U (drs 16 6 17) ev 17 t) (eqv U (drs 5 0 7 ++ drs 6 0 10) ev 17 t)
      (eqv U (drs 5 0 7 ++ drs 7 0 10) ev 17 t)
      (algebraMap GF K (B.cosK (splitK c0 t))) (algebraMap GF K (B.sinK (splitK c0 t))) t
    fin_cases i
    · show gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
          (tabK U P D 17 e (cpt 17 e t))) none
          * reqV (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
            (tabK U P D 17 e (cpt 17 e t))) 15 5 [6] = _
      rw [hv, gV_none, one_mul, g0]
    · show gV (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
          (tabK U P D 17 e (cpt 17 e t))) none
          * reqV (cstK U) (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 tabs16_u1).map (TabS.eval ev pub)).map
            (tabK U P D 17 e (cpt 17 e t))) 16 7 [8] = _
      rw [hv, gV_none, one_mul, g1]

end KRels

section KMm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

/-- A split claim point at `export_u1`: the first seven coordinates `SC_QMM`'s draws, the rest the hosted slot's own. -/
theorem split_pt_u1 (d5 dj : List Fp2) :
    Fin.append (fun i : Fin 7 => (d5.getD i Fp2.zero).toK U) (fun a : Fin 10 => (dj.getD (0 + a) Fp2.zero).toK U)
      = fun t : Fin (7 + 10) => if (t : ℕ) < 7 then (d5.getD t Fp2.zero).toK U
          else (dj.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left]
    simp
  · rw [Fin.append_right]
    simp

include hX hrl in
/-- **`SC_KMM`'s (`SC_VMM`'s) unmasked sum is the extension of `relMm 16 i` at its split point (`export_u1`).** -/
theorem kvmm_spSum_u1 (pubs : PubTabs) (s mrow : ℕ) (hs : s = 6 ∨ s = 7) (i : Fin 2)
    (prog : List SlotS)
    (hprog : prog.getD s SlotS.empty = ⟨[fxT (offU1 9) 19 (drs 5 0 7) 12 mrow 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩)
    (hsh : (slotShape P s).1 = 12) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r5 r : SlotRec)
    (hr5 : rs[5]? = some r5) (hr : rs[s]? = some r)
    (hW : ∀ c, ((pubs s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) r.draws 0).getD (msbIndex 12 c) Fp2.zero).toK U
      = ∑ y : Fin 10 → Bool, eqDr U r.draws 0 10 y
        * algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) c (splitGD c0 y))) :
    spSum P (polyS U P D prog pubs) bga rs s
      = mleAt (fun y : Fin (7 + 10) → Bool => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 16 i (.kv (splitK c0 y))))
          (fun t : Fin (7 + 10) => if (t : ℕ) < 7 then (r5.draws.getD t Fp2.zero).toK U
            else (r.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U) := by
  rw [mm_spSum U P D hrl prog pubs s (offU1 9) mrow 7 12 10 (drs 5 0 7) (by simp [drs]) hsh (by norm_num) hprog
    bga rs r hr (fun c y => algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) c (splitGD c0 y)))
    (fun a => (r.draws.getD (0 + a) Fp2.zero).toK U) hW]
  have h5s : 5 < s := by omega
  rw [drs_map_hist bga rs s 5 r.draws r5 h5s hr5 0 7 (histOf bga.1 bga.2.1 bga.2.2 [])]
  have hpt : Fin.append (fun i : Fin 7 => (((drs 5 0 7).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 5
      r5.draws)).getD i Fp2.zero).toK U) (fun a : Fin 10 => (r.draws.getD (0 + a) Fp2.zero).toK U)
      = fun t : Fin (7 + 10) => if (t : ℕ) < 7 then (r5.draws.getD t Fp2.zero).toK U
          else (r.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
    refine Eq.trans ?_ (split_pt_u1 U r5.draws r.draws)
    congr 1
    funext a
    rw [drs_getD _ 5 0 7 a a.isLt, eval_self, Nat.zero_add]
  rw [hpt]
  congr 1
  funext y
  fin_cases i
  · simp only [relMm, xtU1, map_sum, map_mul]
    refine Finset.sum_congr rfl (fun c _ => ?_)
    rw [alg_plD_u1 U P D hX]
    rfl
  · simp only [relMm, xtU1, map_sum, map_mul]
    refine Finset.sum_congr rfl (fun c _ => ?_)
    rw [alg_plD_u1 U P D hX]
    rfl

end KMm

/-! ## 6. `SC_KVZC`'s named identity (`formAt_kvzcU1`) -/

/-- **L36's `FormAt` at host `16` (`SC_KVZC`) at `export_u1`**, parametric in `(cnA, cnM)`. -/
theorem formAt_kvzcU1 {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.shieldDraws) (hsl : P.geom.slots = W16R2.shieldSlots)
    (cnA cnM ioIn ioOut : ℕ) (pubs : PubTabs)
    (hdef : P.define = defineS (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR (cfgU1 cnA cnM) S) (hLay : LayR Lay) (hpub : PubR U c0 pubs Pb Lay B)
    (dt : AlgData K L (algShapeU1 P hdr)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 4) (b : Fin 17 → Bool), dt.cl 16 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtU1 U P D) 16 κ (.kv (splitK c0 b)))
        else xcKvzcU1 U P D Pb Lay B bga κ b)
    (hgh : ∀ (i : Fin 2) (b : Fin 17 → Bool),
      dt.gh 16 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtU1 U P D) 16 i (.kv (splitK c0 b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 17 → Bool),
      dt.mm 16 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 16 i (.kv (splitK c0 b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeU1 P hdr) dt hcard 0 cu rt k h).Φ) bga rs 16 := by
  obtain ⟨hs16, hs6, hs7⟩ : slotShape P 16 = (17, 1, 4) ∧ slotShape P 6 = (12, 1, 2) ∧ slotShape P 7 = (12, 1, 2) := by
    simp only [slotShape, hsl]
    decide
  obtain ⟨ak, hk', hslot16⟩ := progW16_slot (cfgU1 cnA cnM) ioIn ioOut 16 (by norm_num)
  have hprog16 : (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut).getD 16 SlotS.empty
      = DefW16.numSlot (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak hk'
        raw16_u1 := by
    rw [hslot16, raw16_u1_eq]
  obtain ⟨m6, hm6⟩ := prog_mm_u1 cnA cnM ioIn ioOut 6 (Or.inr (Or.inl rfl))
  obtain ⟨m7, hm7⟩ := prog_mm_u1 cnA cnM ioIn ioOut 7 (Or.inr (Or.inr rfl))
  refine formAt_two U hcard P (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs hdef D _ dt cu rt bga rs 16
    (by decide) 6 7 (.dr 16 4) (.dr 16 5) ((congrArg SlotS.hosted hprog16).trans rfl)
    ((congrArg SlotS.hosted hm6).trans rfl) ((congrArg SlotS.hosted hm7).trans rfl)
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 16 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r5, hr5⟩ : ∃ r5, rs[5]? = some r5 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r6, hr6⟩ : ∃ r6, rs[6]? = some r6 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r7, hr7⟩ : ∃ r7, rs[7]? = some r7 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    rw [hdef] at hdf
    exact (defineS_ok hdf).1.2.2.2
  have hsp16 := kvzc_cube_u1 U P D hX Pb Lay B hLay hrl cnA cnM hS
    (DefW16.aDataRows (cfgU1 cnA cnM)) (DefW16.hDataRows (cfgU1 cnA cnM)) ioIn ioOut ak hk'
    ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).beta, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).gamma,
      (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws rfl rfl
    (pubs 16 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws)
    (hpub.kvCos (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws)
    (hpub.kvSin (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws) (slotShape P 16).1 (slotShape P 16).2.1
    (by rw [hs16]) (polyS U P D (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) pubs 16 (seenOf bga rs 16))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 16 r hr x, hprog16]; rfl)
  have hsp6 := kvmm_spSum_u1 U P D hX hrl Pb Lay B pubs 6 m6 (Or.inl rfl) 0
    (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) hm6 (by rw [hs6]) bga rs r5 r6 hr5 hr6
    (fun c => hpub.wk _ _ (hcan 6 r6 hr6) c)
  have hsp7 := kvmm_spSum_u1 U P D hX hrl Pb Lay B pubs 7 m7 (Or.inr rfl) 1
    (DefW16.progW16 (cfgU1 cnA cnM) ioIn ioOut) hm7 (by rw [hs7]) bga rs r5 r7 hr5 hr7
    (fun c => hpub.wv _ _ (hcan 7 r7 hr7) c)
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 16) with hhist
  have hmuK : ∀ j : ℕ, j < 4 → (((drs 16 0 4).map (Sym.eval hist 16 r.draws)).map (Fp2.toK U)).getD j 0
      = (r.draws.getD j Fp2.zero).toK U := by
    intro j hj
    interval_cases j <;> rfl
  rw [hostSp_Φ]
  unfold hostPhi
  rw [hsp6, hsp7]
  unfold spSum
  rw [hsp16]
  refine congrArg₂ (· - ·) ?_ ?_
  · refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · unfold segAt
      have ha : (a : ℕ) < 17 := a.isLt
      rw [dite_eq_left (by show 6 + (a : ℕ) < 23; omega), drs_getD _ 16 6 17 a ha, eval_self]
      first | done | rfl
    · unfold batched
      have hz : segLn ((algShapeU1 P hdr).dl 16) .zeta = 0 := rfl
      simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      have hκ : (κ : ℕ) < 4 := κ.isLt
      rw [hcl (hist.beta, hist.gamma, hist.alpha) κ t, hmuK κ hκ]
      refine congrArg₂ (· * ·) ?_ rfl
      unfold segAt
      rw [dite_eq_left (by show 0 + (κ : ℕ) < 23; omega)]
      show (r.draws.getD (0 + (κ : ℕ)) Fp2.zero).toK U = _
      rw [Nat.zero_add]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by show 4 + 0 < 23; omega)]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 4 + 1 < 23; omega)]
        first | done | rfl
    · fin_cases i
      · show (if (j : ℕ) < 7 then algDrawAt U hist 5 j else algDrawAt U hist 6 ((j : ℕ) - 7))
          = (((drs 5 0 7 ++ drs 6 0 10).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, drs_map_hist bga rs 16 5 r.draws r5 (by decide) hr5 0 7 hist,
          drs_map_hist bga rs 16 6 r.draws r6 (by decide) hr6 0 10 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 17 := hj
        interval_cases jv <;> rfl
      · show (if (j : ℕ) < 7 then algDrawAt U hist 5 j else algDrawAt U hist 7 ((j : ℕ) - 7))
          = (((drs 5 0 7 ++ drs 7 0 10).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, drs_map_hist bga rs 16 5 r.draws r5 (by decide) hr5 0 7 hist,
          drs_map_hist bga rs 16 7 r.draws r7 (by decide) hr7 0 10 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 17 := hj
        interval_cases jv <;> rfl
    · rw [algH_gh U _ dt 16 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeU1 P hdr) dt 16 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtU1 U P D) 16 i (.kv (splitK c0 b))) := fun i => by
      rw [algM_mm _ dt 16 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeU1 P hdr) 16 hist 0
        = fun t : Fin (segLn ((algShapeU1 P hdr).dl 16) .tau) => if (t : ℕ) < 7 then (r5.draws.getD t Fp2.zero).toK U
            else (r6.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < 7 then algDrawAt U hist 5 t else algDrawAt U hist 6 ((t : ℕ) - 7)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6]
    have hp1 : algPt U (algShapeU1 P hdr) 16 hist 1
        = fun t : Fin (segLn ((algShapeU1 P hdr).dl 16) .tau) => if (t : ℕ) < 7 then (r5.draws.getD t Fp2.zero).toK U
            else (r7.draws.getD ((t : ℕ) - 7) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < 7 then algDrawAt U hist 5 t else algDrawAt U hist 7 ((t : ℕ) - 7)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7]
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 0 < 23; omega)]
      first | done | rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 1 < 23; omega)]
      first | done | rfl

end ZK60.Exec.Block.Join.W16U1.Qkv
