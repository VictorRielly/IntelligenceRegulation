/-
D63 lane L44 (2026-11-10), part 3: **`SC_DZC`'s named identity (`FormAt`) at the W16R2 rung** (slot `14`, lane L36's
`hform` for the host of `Dom::D`), with its hosted matmuls `SC_WO` (slot `10`) and `SC_DMM` (slot `13`), by lane L41's
`formAt_tzc` pattern on the shared tools of `BlockHostBase.lean`.

* `tabs14`, `R14`, `K14`, `ir14`; **`slot14_eq`**, **`slot10_eq`**, **`slot13_eq`**: the three slots of L35's program
  at the rung, as explicit tables, IR and hosted list (by evaluation);
* `tailD`: the value list `SC_DZC`'s IR reads at a cube point past its three `eq` tables (the norms' `γ`, the 19
  planes of `Dom::D`, the two norms' `Dom::T` planes, the 10 LogUp helpers of `H`, the support gate); **`dzc_vals`**;
* **`xcDzc`**: the batch's entries past the six named clauses, LogUp's helper relations read WITHOUT the draws (only
  `α`, `γ` and the planes); **`pwDzc`**: the 19 pad planes `(1 − supp_D)·plane`;
* **`relClD_alg`**, **`relGhD_alg`**: `W16Rels`' `SC_DZC` relations of the extracted planes, embedded;
* **`dzc_irEval`**, **`dzc_cube`**: `SC_DZC`'s polynomial on the cube (L13's `dzcIr_eval`, L41's `cubeSum_host`);
* **`dzc_Z`**: the batched relation of lane L36's host polynomial IS the IR's zero-check term;
* **`mm_wo`**, **`mm_dmm`**: the hosted matmuls' cube sums are the multilinear extensions of `relMm 14 0` / `relMm 14 1`
  at their claim points (the public folded weights `PubW16.wo`, `.wd`);
* **`formAt_dzc`**: L36's `FormAt` at host `14`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false
-- The value-list and constant computations use broad simp sets; Mathlib's style linters flag the simp arguments a
-- branch did not need. Style warnings only (as in `SlotW16BuildSlots.lean`).
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

namespace ZK60.Exec.Block.Join.W16.Dzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt mle2)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some L16 batchV dzcIr DzcR DzcK dzcClauses dzcIr_eval reqV
  logupSem padSem LkD mmIr mmIr_eval)
open ZK60.Exec.Slot.Compose (dzcIr_map mmIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The slots `SC_DZC`, `SC_WO`, `SC_DMM` at the rung -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drS (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drS_length (s off n : ℕ) (ev : Sym → Fp2) : ((drS s off n).map ev).length = n := by simp [drS]

theorem drS_getD (ev : Sym → Fp2) (s off n a : ℕ) (h : a < n) :
    ((drS s off n).map ev).getD a Fp2.zero = ev (.dr s (off + a)) := by
  unfold drS
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  first | done | rfl

theorem drS_getDK {K : Type} [Field K] [Algebra GF K] (U : K) (ev : Sym → Fp2) (s off n a : ℕ) (h : a < n) :
    (((drS s off n).map ev).map (Fp2.toK U)).getD a 0 = (ev (.dr s (off + a))).toK U := by
  unfold drS
  rw [List.map_map, List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range h]
  first | done | rfl

/-- An `H` table on its own coordinates. -/
def hT (re im log m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩

/-- **`SC_DZC`'s tables at the rung**: `eq(τ)`, `eq` of `SC_WO`'s and `SC_DMM`'s claim points, `γ_a`, `γ_m`, the 19
planes of `Dom::D`, `D` and `DM` on `Dom::T`, the 10 LogUp helpers, `supp(D)`. -/
def tabs14 : List TabS :=
  [.eq (drS 14 20 14) 0, .eq (drS 10 0 14) 0, .eq (drS 13 0 14) 0, .pub 0, .pub 1,
    paT 131072 14 168, paT 147456 14 170, paT 163840 14 172, paT 180224 14 174, paT 196608 14 176,
    paT 212992 14 178, paT 229376 14 180, paT 245760 14 182, paT 262144 14 184, paT 278528 14 186,
    paT 294912 14 188, paT 311296 14 190, paT 327680 14 192, paT 344064 14 194, paT 360448 14 196,
    paT 376832 14 198, paT 393216 14 200, paT 409600 14 202, paT 425984 14 204,
    paT 0 5 206, paT 32768 5 208,
    hT 32768 49152 14 110, hT 65536 81920 14 112, hT 98304 114688 14 114, hT 131072 147456 14 116,
    hT 163840 180224 14 118, hT 196608 212992 14 120, hT 229376 245760 14 122, hT 262144 278528 14 124,
    hT 294912 311296 14 126, hT 327680 344064 14 128, .pub 2]

/-- `SC_DZC`'s table positions. -/
def R14 : DzcR := ⟨0, 1, 2, 3, 4, 5, 6, 11, 14, 15, 20, 23, [7, 8], [9, 10], [16, 17], [18, 19], [12, 13], [21, 22],
  24, 25, 26, some 36⟩

/-- `SC_DZC`'s constants at the rung: `2·cn_a`, `2·cn_m`, `2^tn`, `2^(tn+1)`, the two shifts. -/
def K14 : DzcK := ⟨8000, 8000, 4, 8, 21, 20⟩

/-- The plane-to-table map of `Dom::D`. -/
def shD : ℕ → ℕ := fun q => 5 + (q - 8)

/-- `Dom::D`'s lookups. -/
def lks14 : List (LkD Sym) := lksS cfgRungW16 shD .D

/-- `Dom::D`'s pad group. -/
def grp14 : List (ℕ × List ℕ) := padGroup cfgRungW16 .D 36 shD

/-- `SC_DZC`'s IR at the rung. -/
def ir14 := dzcIr DefW16.cstS R14 K14 lks14 (drS 14 0 17) (drS 14 17 2) (fun j => Sym.pow (Sym.dr 14 19) j) grp14

theorem slot14_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 14 SlotS.empty
    = ⟨tabs14, ir14, [(10, .dr 14 17), (13, .dr 14 18)], [.dr 14 17, .dr 14 18, .dr 14 19]⟩ := rfl

theorem slot10_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 10 SlotS.empty
    = ⟨[.priv ⟨.a, [(573440, false)], 15, (drS 10 0 5).map CoordS.fixed ++ DefW16.rhoC 0 10, 160, 0⟩, .pub 0],
        mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem slot13_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 13 SlotS.empty
    = ⟨[.priv ⟨.a, [(1097728, false)], 15, (drS 13 0 5).map CoordS.fixed ++ DefW16.rhoC 0 10, 166, 0⟩, .pub 0],
        mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem grp14_eq : grp14 = [(36, List.range' 5 19)] := by decide

theorem lks14_length : lks14.length = 19 := by decide

/-- Every lookup term of `Dom::D` reads a plane at position `≥ 5`. -/
theorem lks14_pos : ∀ l ∈ lks14, ∀ t ∈ l.terms, 5 ≤ t.2 := by
  intro l hl t ht
  unfold lks14 lksS at hl
  obtain ⟨l0, -, rfl⟩ := List.mem_map.mp hl
  obtain ⟨t0, -, rfl⟩ := List.mem_map.mp ht
  show 5 ≤ shD t0.1
  unfold shD
  omega

theorem pos_map {α β : Type} (f : α → β) (lks : List (LkD α)) (P : ℕ → Prop) (h : ∀ l ∈ lks, ∀ t ∈ l.terms, P t.2) :
    ∀ l ∈ lks.map (ZK60.Exec.Slot.Build.LkD.map f), ∀ t ∈ l.terms, P t.2 := by
  intro l hl t ht
  obtain ⟨l0, hl0, rfl⟩ := List.mem_map.mp hl
  obtain ⟨t0, ht0, rfl⟩ := List.mem_map.mp ht
  exact h l0 hl0 t0 ht0

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s values past its three `eq` tables at a cube point.** -/
noncomputable def tailD (b : Fin 14 → Bool) : List K :=
  [algebraMap GF K (B.gamA (splitD b)), algebraMap GF K (B.gamM (splitD b)),
    aPl U P D 131072 14 b, aPl U P D 147456 14 b, aPl U P D 163840 14 b, aPl U P D 180224 14 b,
    aPl U P D 196608 14 b, aPl U P D 212992 14 b, aPl U P D 229376 14 b, aPl U P D 245760 14 b,
    aPl U P D 262144 14 b, aPl U P D 278528 14 b, aPl U P D 294912 14 b, aPl U P D 311296 14 b,
    aPl U P D 327680 14 b, aPl U P D 344064 14 b, aPl U P D 360448 14 b, aPl U P D 376832 14 b,
    aPl U P D 393216 14 b, aPl U P D 409600 14 b, aPl U P D 425984 14 b,
    aPl U P D 0 5 (splitD b).1, aPl U P D 32768 5 (splitD b).1,
    hPl U P D 32768 49152 14 b, hPl U P D 65536 81920 14 b, hPl U P D 98304 114688 14 b,
    hPl U P D 131072 147456 14 b, hPl U P D 163840 180224 14 b, hPl U P D 196608 212992 14 b,
    hPl U P D 229376 245760 14 b, hPl U P D 262144 278528 14 b, hPl U P D 294912 311296 14 b,
    hPl U P D 327680 344064 14 b,
    algebraMap GF K (B.gD (splitD b))]

/-- The value list without the draws: the `eq` entries `0`. -/
noncomputable def valsXD (b : Fin 14 → Bool) : List K := 0 :: 0 :: 0 :: tailD U P D Pb Lay B b

/-- The lookups' expressions at `(β, γ, α)` with no draws. -/
noncomputable def lksX (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  (lks14.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_DZC`'s batch entry `κ` past its six named clauses** (`6 ≤ κ < 16`): LogUp's helper relation `κ − 6` of
`Dom::D` at the cube point `b`, read on the planes, `α` and `γ` only. -/
noncomputable def xcDzc (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 14 → Bool) : K :=
  (lkRels (cstK U) (valsXD U P D Pb Lay B b) 26 0 (lksX U bga)).getD (κ - 6) 0

/-- **`SC_DZC`'s pad plane `j`** (`j < 19`): `(1 − supp_D(b))·plane_j(b)` over the zero-rule planes of `Dom::D`. -/
noncomputable def pwDzc (j : ℕ) (b : Fin 14 → Bool) : K := (padPls (valsXD U P D Pb Lay B b) grp14).getD j 0

/-- The real value list at a cube point (generic in the extension). -/
noncomputable def valsF (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2) (e : ℕ) (x : Fin (14 + e) → K) : List K :=
  (tabs14.map (TabS.eval (Sym.eval hist 14 dr) pub)).map (tabK U P D 14 e x)

theorem hT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (re im log m : ℕ) :
    TabS.eval ev pub (hT re im log m) = .priv ⟨.h, [(re, Fp2.one), (im, fp2U)], log, rhoAll log, m, 0⟩ :=
  hTab_eval ev pub re im log m

/-- An `A` plane of `Dom::T` on the first five variables of `Dom::D`'s cube. -/
theorem tabK_head14 (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 14 → Bool) (off m ext : ℕ) :
    tabK U P D 14 e (cpt 14 e b) (.priv ⟨.a, [(off, Fp2.one)], 5, rhoAll 5, m, ext⟩) = aPl U P D off 5 (splitD b).1 := by
  rw [tabK_paHead_cpt U P D hrl 14 e b 5 (by norm_num) (by norm_num)]
  first | done | rfl

/-- **`SC_DZC`'s value list at a cube point with the zero extension.** -/
theorem dzc_vals (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 14 → Bool) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hp0 : ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD b)))
    (hp1 : ((pub 1).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD b)))
    (hp2 : ((pub 2).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD b))) :
    valsF U P D hist dr pub e (cpt 14 e b)
      = eqPoly (fun a : Fin 14 => (((drS 14 20 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin 14 => (((drS 10 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin 14 => (((drS 13 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: tailD U P D Pb Lay B b := by
  unfold valsF
  simp only [tabs14, List.map_cons, List.map_nil, paT_eval, eqT_eval, pubT_eval, hT_eval]
  rw [tabK_eqFull_cpt U P D 14 e b _ (drS_length 14 20 14 _), tabK_eqFull_cpt U P D 14 e b _ (drS_length 10 0 14 _),
    tabK_eqFull_cpt U P D 14 e b _ (drS_length 13 0 14 _)]
  simp only [tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl, tabK_head14 U P D hrl e b,
    tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, tabK_pub_cpt, hp0, hp1, hp2, tailD]

end Vals

/-! ## The named relations, embedded -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- A remainder wider than 16 bits is its two limbs. -/
theorem remVal_gt (b : ℕ) (hb : 16 < b) (lo hi : GF) : remVal b lo hi = lo + 2 ^ 16 * hi := by
  unfold remVal
  exact ite_eq_right (by omega)

/-- A two-limb remainder's planes. -/
theorem remR_lo2 {C : Type} (pl : ℕ → C → GF) (a b : ℕ) (x : C) : (remR pl [a, b]).lo x = pl a x := rfl

theorem remR_hi2 {C : Type} (pl : ℕ → C → GF) (a b : ℕ) (x : C) : (remR pl [a, b]).hi x = pl b x := rfl

theorem append_splitD (t : Fin 14 → Bool) : Fin.append (splitD t).1 (splitD t).2 = t := by
  funext i
  refine Fin.addCases (fun i5 => ?_) (fun i9 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

include hX

/-- **`SC_DZC`'s six relations, embedded**, in the planes at the cube point `t` (constants at the rung). -/
theorem relClD_alg (hS : RungS S) (t : Fin 14 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 0 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (algebraMap GF K (B.gamA (splitD t)) * aPl U P D 131072 14 t * 8000
          + aPl U P D 0 5 (splitD t).1 * 4 - 8 * aPl U P D 0 5 (splitD t).1 * aPl U P D 147456 14 t
          - (aPl U P D 163840 14 t + 65536 * aPl U P D 180224 14 t))
    ∧ algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 1 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (aPl U P D 163840 14 t + 65536 * aPl U P D 180224 14 t
          + (aPl U P D 196608 14 t + 65536 * aPl U P D 212992 14 t) + 1 - 8 * aPl U P D 0 5 (splitD t).1)
    ∧ algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 2 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (aPl U P D 278528 14 t - aPl U P D 131072 14 t - aPl U P D 229376 14 t)
    ∧ algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 3 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (algebraMap GF K (B.gamM (splitD t)) * aPl U P D 278528 14 t * 8000
          + aPl U P D 32768 5 (splitD t).1 * 4 - 8 * aPl U P D 32768 5 (splitD t).1 * aPl U P D 294912 14 t
          - (aPl U P D 311296 14 t + 65536 * aPl U P D 327680 14 t))
    ∧ algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 4 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (aPl U P D 311296 14 t + 65536 * aPl U P D 327680 14 t
          + (aPl U P D 344064 14 t + 65536 * aPl U P D 360448 14 t) + 1 - 8 * aPl U P D 32768 5 (splitD t).1)
    ∧ algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 5 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (aPl U P D 425984 14 t - aPl U P D 278528 14 t - aPl U P D 376832 14 t) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  all_goals (simp only [relCl, xtW, remR_lo2, remR_hi2, remVal_gt 24 (by norm_num), map_sub, map_mul, map_add,
    map_pow, map_ofNat, map_intCast, map_one, alg_plT U P D hX, alg_plD U P D hX, append_splitD, hS.cnA, hS.cnM, hS.tn] <;> push_cast <;> ring)

/-- **`SC_DZC`'s two hosted relations, embedded** (`SC_WO`'s and `SC_DMM`'s requantizations). -/
theorem relGhD_alg (hS : RungS S) (t : Fin 14 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 14 0 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (2097152 * aPl U P D 229376 14 t
          + (aPl U P D 245760 14 t + 65536 * aPl U P D 262144 14 t) - 1048576)
    ∧ algebraMap GF K (relGh Pb Lay B (xtW U P D) 14 1 (.d (splitD t)))
        = algebraMap GF K (B.gD (splitD t)) * (1048576 * aPl U P D 376832 14 t
          + (aPl U P D 393216 14 t + 65536 * aPl U P D 409600 14 t) - 524288) := by
  refine ⟨?_, ?_⟩
  all_goals (simp only [relGh, xtW, remR_lo2, remR_hi2, hS.sao, hS.sdown, remVal_gt 21 (by norm_num),
    remVal_gt 20 (by norm_num), map_sub, map_mul, map_add, map_pow,
    map_ofNat, map_intCast, map_one, alg_plD U P D hX, append_splitD] <;> push_cast <;> ring)

end Rels

/-! ## The IR on the cube -/

section Ir

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The builders' constants read in the field. -/
theorem cK_base (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) : (cstK U).base v = (v : K) := by
  rw [cstK_base U v h1 h2, map_intCast]

theorem cK_p16 (j : ℕ) (hj : j < 4) : (cstK U).p16 j = (2 : K) ^ (16 * j) := by
  rw [cstK_p16 U j hj, map_pow, map_ofNat]

/-- **`SC_DZC`'s zero-check term**: LogUp's helper relations, the pad term and the gated clauses. -/
noncomputable def zD (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 26 (fun k => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (6 + k) 0) 0
      ((lks14.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map
        (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
    + padSem (cstK U) v ((((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 16 0)
        (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j)) 0 grp14
    + gV v (some 36) * batchV (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
        (dzcClauses (cstK U) R14 K14 v)

/-- **`SC_DZC`'s IR read in the field** (L13's `dzcIr_eval`). -/
theorem dzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((ir14.map (Sym.eval hist 14 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 36) (some 36) (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (zD U hist dr v) (reqV (cstK U) v 21 11 [12, 13]) (reqV (cstK U) v 20 20 [21, 22]) := by
  unfold ir14
  rw [dzcIr_map, dzcIr_map, cstS_map, dzcIr_eval _ (cstW_map_std U)]
  rw [List.length_map, List.length_map, lks14_length]
  first | done | rfl

end Ir

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s cube sum** (L41's `cubeSum_host`), at `n = 14` main variables. -/
theorem dzc_cube (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 14) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hp0 : ∀ b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD b)))
    (hp1 : ∀ b, ((pub 1).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD b)))
    (hp2 : ∀ b, ((pub 2).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((ir14.map (Sym.eval hist 14 dr)).map (Fp2.toK U))
      ((tabs14.map (TabS.eval (Sym.eval hist 14 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ b : Fin 14 → Bool, hostPoly
      (fun a : Fin 14 => (((drS 14 20 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
      (fun b => zD U hist dr (valsF U P D hist dr pub e (cpt 14 e b)))
      ![(((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 0 0,
        (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 1 0]
      ![fun a : Fin 14 => (((drS 10 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
        fun a : Fin 14 => (((drS 13 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
      (fun _ => 1)
      (fun i b => if i = 0
        then gV (valsF U P D hist dr pub e (cpt 14 e b)) (some 36)
          * reqV (cstK U) (valsF U P D hist dr pub e (cpt 14 e b)) 21 11 [12, 13]
        else gV (valsF U P D hist dr pub e (cpt 14 e b)) (some 36)
          * reqV (cstK U) (valsF U P D hist dr pub e (cpt 14 e b)) 20 20 [21, 22]) b := by
  subst hn
  have hv := fun b => dzc_vals U P D Pb Lay B hrl e b hist dr pub (hp0 b) (hp1 b) (hp2 b)
  rw [cubeSum_host 14 e (valsF U P D hist dr pub e) 0 1 2 (some 36) (some 36)
    (((drS 14 17 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U)) (zD U hist dr)
    (fun v => reqV (cstK U) v 21 11 [12, 13]) (fun v => reqV (cstK U) v 20 20 [21, 22]) f
    (fun x => by rw [hf x, dzc_irEval U hist dr]; first | done | rfl)
    (fun b y hy => by
      simp only [valsF, tabs14, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
      exact ⟨tabK_eq_off U P D 14 e b y hy _ _, tabK_eq_off U P D 14 e b y hy _ _, tabK_eq_off U P D 14 e b y hy _ _⟩)
    (fun a : Fin 14 => (((drS 14 20 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U)
    ![fun a : Fin 14 => (((drS 10 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U,
      fun a : Fin 14 => (((drS 13 0 14).map (Sym.eval hist 14 dr)).getD a Fp2.zero).toK U]
    (fun b => by rw [hv b]; first | done | rfl) (fun b => by rw [hv b]; first | done | rfl)
    (fun b => by rw [hv b]; first | done | rfl)]

end Cube

/-! ## The batched relation is the IR's zero-check term -/

section Z

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

omit [Algebra GF K] in
theorem getD3 (a b c a' b' c' : K) (T : List K) (p : ℕ) (hp : 3 ≤ p) :
    (a :: b :: c :: T).getD p 0 = (a' :: b' :: c' :: T).getD p 0 := by
  obtain ⟨q, rfl⟩ : ∃ q, p = q + 1 + 1 + 1 := ⟨p - 3, by omega⟩
  simp only [List.getD_cons_succ]

/-- The weights `μ_k` of the IR, read off the draws. -/
theorem muK_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 17) :
    (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD k 0 = (dr.getD k Fp2.zero).toK U := by
  rw [drS_getDK U _ 14 0 17 k hk, Nat.zero_add]
  simp [Sym.eval, drawAt]

include hX in
/-- **The gated clauses**: the gate times the IR's batch of `dzc_w16`'s six clauses is the weighted sum of the
embedded `W16Rels` clauses. -/
theorem dzc_cls (hS : RungS S) (hist : Hist) (dr : List Fp2) (t : Fin 14 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) (some 36)
        * batchV (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (dzcClauses (cstK U) R14 K14 (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t))
      = ∑ i : Fin 6, (dr.getD i Fp2.zero).toK U * algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 i (.d (splitD t))) := by
  rw [Fin.sum_univ_eq_sum_range (fun i => (dr.getD i Fp2.zero).toK U
    * algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 i (.d (splitD t)))) 6]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
  obtain ⟨h0, h1, h2, h3, h4, h5⟩ := relClD_alg U P D hX Pb Lay B hS t
  rw [h0, h1, h2, h3, h4, h5]
  simp only [gV_some, batchV, dzcClauses, R14, K14, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons,
    List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ, tailD]
  rw [muK_getD U hist dr 0 (by norm_num), muK_getD U hist dr 1 (by norm_num), muK_getD U hist dr 2 (by norm_num),
    muK_getD U hist dr 3 (by norm_num), muK_getD U hist dr 4 (by norm_num), muK_getD U hist dr 5 (by norm_num)]
  simp (disch := norm_num) only [cK_base, cK_p16] <;> push_cast <;> ring

include hX in
/-- **The hosted terms**: the gate times the IR's requantization hosts are the embedded `W16Rels` hosted terms. -/
theorem dzc_gh (hS : RungS S) (t : Fin 14 → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) (some 36)
        * reqV (cstK U) (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) 21 11 [12, 13]
      = algebraMap GF K (relGh Pb Lay B (xtW U P D) 14 0 (.d (splitD t)))
    ∧ gV (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) (some 36)
        * reqV (cstK U) (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) 20 20 [21, 22]
      = algebraMap GF K (relGh Pb Lay B (xtW U P D) 14 1 (.d (splitD t))) := by
  obtain ⟨h0, h1⟩ := relGhD_alg U P D hX Pb Lay B hS t
  rw [h0, h1]
  refine ⟨?_, ?_⟩
  all_goals (simp only [gV_some, reqV, L16, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
    List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ, tailD] <;>
    simp (disch := norm_num) only [cK_base, cK_p16] <;> push_cast <;> ring)

include hU hX in
/-- **`SC_DZC`'s batched relation is the IR's zero-check term**: the six gated clauses (`relCl 14`), the ten LogUp
helper relations (`xcDzc`) and the pad term (`pwDzc`, weights `ζ^j`). -/
theorem dzc_Z (hS : RungS S) (hist : Hist) (dr : List Fp2) (bga : Fp2 × Fp2 × Fp2) (hα : hist.alpha = bga.2.2)
    (hγ : hist.gamma = bga.2.1) (t : Fin 14 → Bool) (e0 e1 e2 : K) :
    (∑ κ : Fin (6 + 10), (dr.getD κ Fp2.zero).toK U
        * (if (κ : ℕ) < 6 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 κ (.d (splitD t)))
          else xcDzc U P D Pb Lay B bga κ t))
      + (dr.getD 16 Fp2.zero).toK U * ∑ j : Fin 19, ((dr.getD 19 Fp2.zero).toK U) ^ (j : ℕ) * pwDzc U P D Pb Lay B j t
    = zD U hist dr (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) := by
  -- the LogUp helpers read only positions `≥ 3`
  have hlks : (lks14.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map
      (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)) = lksX U bga := by
    unfold lksX lks14
    rw [lksS_eval cfgRungW16 shD .D hist (histOf bga.1 bga.2.1 bga.2.2 []) 14 14 dr [] hα hγ]
  have hlk : lkRels (cstK U) (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) 26 0 (lksX U bga)
      = lkRels (cstK U) (valsXD U P D Pb Lay B t) 26 0 (lksX U bga) := by
    refine lkRels_congr (cstK U) _ _ 26 0 (lksX U bga) (fun l hl tt htt => ?_) (fun i _ => ?_)
    · have h5 : 5 ≤ tt.2 := pos_map (Fp2.toK U) _ (fun q => 5 ≤ q)
        (pos_map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []) lks14 (fun q => 5 ≤ q) lks14_pos) l hl tt htt
      exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
    · exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
  have hlkl : (lkRels (cstK U) (valsXD U P D Pb Lay B t) 26 0 (lksX U bga)).length = 10 := by
    rw [lkRels_length]
    unfold lksX
    rw [List.length_map, List.length_map, lks14_length]
    first | done | rfl
  have hpd : padPls (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) grp14 = padPls (valsXD U P D Pb Lay B t) grp14 := by
    refine padPls_congr _ _ grp14 (fun g hg => ?_)
    rw [grp14_eq] at hg
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hg
    subst hg
    refine ⟨getD3 e0 e1 e2 0 0 0 _ _ (by norm_num), fun p hp => getD3 e0 e1 e2 0 0 0 _ _ ?_⟩
    have := (List.mem_range'_1.mp hp).1
    omega
  have hpdl : (padPls (valsXD U P D Pb Lay B t) grp14).length = 19 := by
    rw [grp14_eq]
    simp [padPls]
  -- the three parts
  have hA := dzc_cls U P D hX Pb Lay B hS hist dr t e0 e1 e2
  have hLg : logupSem (cstK U) (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t) 26
      (fun k => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (6 + k) 0) 0
      ((lks14.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 14 dr))).map (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
      = ∑ i : Fin 10, (dr.getD (6 + i) Fp2.zero).toK U
          * (lkRels (cstK U) (valsXD U P D Pb Lay B t) 26 0 (lksX U bga)).getD i 0 := by
    rw [logupSem_eq_wsum, hlks, hlk, wsum_eq_sum,
      Fin.sum_univ_eq_sum_range (fun i => (((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD
        (6 + (0 + i)) 0 * (lkRels (cstK U) (valsXD U P D Pb Lay B t) 26 0 (lksX U bga)).getD i 0), hlkl,
      Fin.sum_univ_eq_sum_range (fun i => (dr.getD (6 + i) Fp2.zero).toK U
        * (lkRels (cstK U) (valsXD U P D Pb Lay B t) 26 0 (lksX U bga)).getD i 0) 10]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    rw [Nat.zero_add, muK_getD U hist dr (6 + i) (by have := Finset.mem_range.mp hi; omega)]
  have hP : padSem (cstK U) (e0 :: e1 :: e2 :: tailD U P D Pb Lay B t)
      ((((drS 14 0 17).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 16 0)
      (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j)) 0 grp14
      = (dr.getD 16 Fp2.zero).toK U * ∑ j : Fin 19, ((dr.getD 19 Fp2.zero).toK U) ^ (j : ℕ)
          * pwDzc U P D Pb Lay B j t := by
    rw [padSem_eq_wsum _ (cstW_map_std U), hpd, wsum_eq_sum, muK_getD U hist dr 16 (by norm_num)]
    refine congrArg (fun z => (dr.getD 16 Fp2.zero).toK U * z) ?_
    rw [Fin.sum_univ_eq_sum_range (fun j => (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 19) j))
      (0 + j) * (padPls (valsXD U P D Pb Lay B t) grp14).getD j 0), hpdl,
      Fin.sum_univ_eq_sum_range (fun j => ((dr.getD 19 Fp2.zero).toK U) ^ j * pwDzc U P D Pb Lay B j t) 19]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval hist 14 dr (Sym.dr 14 19)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    simp [Sym.eval, drawAt, pwDzc]
  -- assemble
  unfold zD
  rw [hLg, hP, hA, Fin.sum_univ_add]
  have hc : ∀ i : Fin 6, (i : ℕ) < 6 := fun i => i.isLt
  have hn : ∀ i : Fin 10, ¬ (6 + (i : ℕ) < 6) := fun i => by omega
  simp only [Fin.val_castAdd, Fin.val_natAdd, hc, hn, ↓reduceIte]
  unfold xcDzc
  simp only [Nat.add_sub_cancel_left]
  ring

end Z

/-! ## The hosted matmuls -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- A point of `a + b` coordinates read off one draw list. -/
theorem append_draws (dr : List Fp2) :
    Fin.append (fun i : Fin 5 => (dr.getD i Fp2.zero).toK U) (fun a : Fin 9 => (dr.getD (5 + a) Fp2.zero).toK U)
      = fun t : Fin (5 + 9) => (dr.getD t Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left, Fin.val_castAdd]
  · rw [Fin.append_right, Fin.val_natAdd]

include hX in
/-- **`SC_WO`'s cube sum** (slot `10`): the multilinear extension of `relMm 14 0` (`Σ_c O(t, c)·W_o(c, w)`) at its
claim point `(r_q, r_j)`, with the public folded weight `PubW16.wo`. -/
theorem mm_wo (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubW16 U pubs Pb Lay B) (ioIn ioOut : ℕ)
    (hs10 : slotShape P 10 = (10, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r10 : SlotRec)
    (hr10 : rs[10]? = some r10) (hc10 : ∀ x ∈ r10.draws, x.Canon) :
    spSum P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs) bga rs 10
      = mleAt (fun y : Fin (5 + 9) → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 14 0 (.d (splitD y))))
          (fun t : Fin (5 + 9) => (r10.draws.getD t Fp2.zero).toK U) := by
  unfold spSum
  have hvs : ((drS 10 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)).length = 5 :=
    drS_length 10 0 5 _
  rw [mm_cube U P D hrl (slotShape P 10).1 (slotShape P 10).2.1
    ((drS 10 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10 r10.draws)) 5 10 hvs (by rw [hs10])
    (by norm_num) 573440 160 (pubs 10 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) r10.draws 0)
    (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 10 (seenOf bga rs 10))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 10 r10 hr10 x, slot10_eq, mmIr_map, mmIr_map, cstS_map,
        mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ])]
  have hr : (fun i : Fin 5 => (((drS 10 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 10)) 10
      r10.draws)).getD i Fp2.zero).toK U) = fun i : Fin 5 => (r10.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drS_getD _ 10 0 5 i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  simp only [hpub.wo _ _ hc10, eqDr]
  refine (mm_fold (fun z c => aPl U P D 573440 (5 + 10) (Fin.append z c))
    (fun c y => algebraMap GF K (B.Wo (splitHQ c) y)) (fun i : Fin 5 => (r10.draws.getD i Fp2.zero).toK U)
    (fun a : Fin 9 => (r10.draws.getD (5 + a) Fp2.zero).toK U)).trans ?_
  rw [append_draws U r10.draws]
  congr 1
  funext y
  simp only [relMm, map_sum, map_mul]
  rw [sum_HQ]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  show _ = algebraMap GF K (plQ U P D 573440 ((splitD y).1, splitHQ c)) * _
  rw [show algebraMap GF K (plQ U P D 573440 ((splitD y).1, splitHQ c))
      = aPl U P D 573440 15 (Fin.append (splitD y).1 (Fin.append (Fin.append (splitHQ c).1.1 (splitHQ c).1.2)
        (splitHQ c).2)) from aPl_alg U P D hX _ 15 _, append_splitHQ]
  first | done | rfl

include hX in
/-- **`SC_DMM`'s cube sum** (slot `13`): the multilinear extension of `relMm 14 1` (`Σ_f H(t, f)·W_d(f, w)`) at its
claim point `(r_row, r_j)`, with the public folded weight `PubW16.wd`. -/
theorem mm_dmm (hrl : 0 < rowLog P .a) (pubs : PubTabs) (hpub : PubW16 U pubs Pb Lay B) (ioIn ioOut : ℕ)
    (hs13 : slotShape P 13 = (10, 1, 2)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r13 : SlotRec)
    (hr13 : rs[13]? = some r13) (hc13 : ∀ x ∈ r13.draws, x.Canon) :
    spSum P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs) bga rs 13
      = mleAt (fun y : Fin (5 + 9) → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 14 1 (.d (splitD y))))
          (fun t : Fin (5 + 9) => (r13.draws.getD t Fp2.zero).toK U) := by
  unfold spSum
  have hvs : ((drS 13 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)).length = 5 :=
    drS_length 13 0 5 _
  rw [mm_cube U P D hrl (slotShape P 13).1 (slotShape P 13).2.1
    ((drS 13 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13 r13.draws)) 5 10 hvs (by rw [hs13])
    (by norm_num) 1097728 166 (pubs 13 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) r13.draws 0)
    (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs 13 (seenOf bga rs 13))
    (fun x => by
      rw [polyS_seenOf U P D _ pubs bga rs 13 r13 hr13 x, slot13_eq, mmIr_map, mmIr_map, cstS_map,
        mmIr_eval _ (cstW_map_std U)]
      simp only [List.map_cons, List.map_nil, aFx_eval, pubT_eval, List.getD_cons_zero, List.getD_cons_succ])]
  have hr : (fun i : Fin 5 => (((drS 13 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 13)) 13
      r13.draws)).getD i Fp2.zero).toK U) = fun i : Fin 5 => (r13.draws.getD i Fp2.zero).toK U := by
    funext i
    rw [drS_getD _ 13 0 5 i i.isLt, Nat.zero_add]
    simp [Sym.eval, drawAt]
  rw [hr]
  simp only [hpub.wd _ _ hc13, eqDr]
  refine (mm_fold (fun z c => aPl U P D 1097728 (5 + 10) (Fin.append z c))
    (fun c y => algebraMap GF K (B.Wd c y)) (fun i : Fin 5 => (r13.draws.getD i Fp2.zero).toK U)
    (fun a : Fin 9 => (r13.draws.getD (5 + a) Fp2.zero).toK U)).trans ?_
  rw [append_draws U r13.draws]
  congr 1
  funext y
  simp only [relMm, map_sum, map_mul]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  show _ = algebraMap GF K (plF U P D 1097728 ((splitD y).1, c)) * _
  rw [show algebraMap GF K (plF U P D 1097728 ((splitD y).1, c))
      = aPl U P D 1097728 15 (Fin.append (splitD y).1 c) from aPl_alg U P D hX _ 15 _]
  first | done | rfl

end Mm

/-! ## `SC_DZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_DZC`'s named identity at the rung** (lane L36's `FormAt` at host `14`): for every algebra data `dt` whose
host-14 tables are `W16Rels`' relation tables of the extracted planes (`relCl 14`, `relGh 14`, `relMm 14`, embedded),
the LogUp entries `xcDzc` and the pad planes `pwDzc`, on every outcome whose verified slots passed their checks,
`SC_DZC`'s certified polynomial at the drawn challenges IS its unmasked residual. -/
theorem formAt_dzc (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : RungS S) (_hL : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 16) (b : Fin 14 → Bool), dt.cl 14 cu rt bga κ b
      = if (κ : ℕ) < 6 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 14 κ (.d (splitD b)))
        else xcDzc U P D Pb Lay B bga κ b)
    (hpw : ∀ (j : Fin 19) (b : Fin 14 → Bool), dt.pw 14 cu rt j b = pwDzc U P D Pb Lay B j b)
    (hgh : ∀ (i : Fin 2) (b : Fin 14 → Bool),
      dt.gh 14 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtW U P D) 14 i (.d (splitD b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 14 → Bool),
      dt.mm 14 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtW U P D) 14 i (.d (splitD b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 0 cu rt k h).Φ) bga rs 14 := by
  have hs14 : slotShape P 14 = (14, 1, 5) := by simp only [slotShape, hsl]; decide
  have hs10 : slotShape P 10 = (10, 1, 2) := by simp only [slotShape, hsl]; decide
  have hs13 : slotShape P 13 = (10, 1, 2) := by simp only [slotShape, hsl]; decide
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, x.Canon := by
    intro j rj hrj
    obtain ⟨dfj, hdfj, -⟩ := hslots j rj hrj
    have h' : defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs j
        (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws = .ok dfj := hdef ▸ hdfj
    have hc := (defineS_ok h').1
    unfold HistCanon at hc
    exact hc.2.2.2
  refine formAt_two U hcard P (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs hdef D _ dt cu rt bga rs 14
    (by decide) 10 13 (.dr 14 17) (.dr 14 18) (by rw [slot14_eq]; first | done | rfl) (by rw [slot10_eq]; first | done | rfl)
    (by rw [slot13_eq]; first | done | rfl)
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 14 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r10, hr10⟩ : ∃ r10, rs[10]? = some r10 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r13, hr13⟩ : ∃ r13, rs[13]? = some r13 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  set hist := histOf bga.1 bga.2.1 bga.2.2 (rs.take 14) with hhist
  -- the hosted slots
  rw [mm_wo U P D hX Pb Lay B hrl pubs hpub ioIn ioOut hs10 bga rs r10 hr10 (hcan 10 r10 hr10),
    mm_dmm U P D hX Pb Lay B hrl pubs hpub ioIn ioOut hs13 bga rs r13 hr13 (hcan 13 r13 hr13)]
  -- the host
  unfold spSum
  rw [dzc_cube U P D Pb Lay B hrl (slotShape P 14).1 (slotShape P 14).2.1 (by rw [hs14]) hist r.draws
    (pubs 14 hist r.draws) (hpub.dzcGamA _ _) (hpub.dzcGamM _ _) (hpub.dzcGate _ _)
    (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 14 (seenOf bga rs 14))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 14 r hr x, slot14_eq]; first | done | rfl)]
  rw [hostSp_Φ]
  unfold hostPhi
  refine congrArg₂ (· - ·) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    have hv := dzc_vals U P D Pb Lay B hrl (slotShape P 14).2.1 t hist r.draws (pubs 14 hist r.draws)
      (hpub.dzcGamA _ _ t) (hpub.dzcGamM _ _ t) (hpub.dzcGate _ _ t)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · -- τ
      have ha : (a : ℕ) < 14 := a.isLt
      unfold segAt
      rw [dite_eq_left (by show 20 + (a : ℕ) < 34; omega), drS_getD _ 14 20 14 a ha]
      simp only [Fin.val_cast, Sym.eval, drawAt, ite_true]
      first | done | rfl
    · -- the batch
      show batched _ _ _ t = zD U hist r.draws (valsF U P D hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1
        (cpt 14 (slotShape P 14).2.1 t))
      rw [hv, ← dzc_Z U hU P D hX Pb Lay B hS hist r.draws (hist.beta, hist.gamma, hist.alpha) rfl rfl t]
      unfold batched
      have hz : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 14) .zeta = 1 := rfl
      rw [ite_eq_left hz, ite_eq_left hz]
      dsimp only
      refine congrArg₂ (· + ·) (Finset.sum_congr rfl (fun κ _ => ?_))
        (congrArg₂ (· * ·) ?_ (Finset.sum_congr rfl (fun j _ => ?_)))
      · have hκ : (κ : ℕ) < 16 := κ.isLt
        rw [hcl _ κ t]
        refine congrArg (· * _) ?_
        unfold segAt
        rw [dite_eq_left (by show 0 + (κ : ℕ) < 34; omega)]
        simp only [Fin.val_cast]
        rw [show segOff ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 14) .mu = 0 from rfl, Nat.zero_add]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 0 + 16 < 34; omega)]
        first | done | rfl
      · rw [hpw j t]
        refine congrArg (fun z => z ^ (j : ℕ) * pwDzc U P D Pb Lay B j t) ?_
        unfold segAt
        rw [dite_eq_left (by show 19 + 0 < 34; omega)]
        first | done | rfl
    · -- ν
      fin_cases i
      · show segAt _ _ .nu 0 = (((drS 14 17 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 0 0
        unfold segAt
        rw [dite_eq_left (by show 17 + 0 < 34; omega)]
        first | done | rfl
      · show segAt _ _ .nu 1 = (((drS 14 17 2).map (Sym.eval hist 14 r.draws)).map (Fp2.toK U)).getD 1 0
        unfold segAt
        rw [dite_eq_left (by show 17 + 1 < 34; omega)]
        first | done | rfl
    · -- the hosted claim points
      have hj : (j : ℕ) < 14 := j.isLt
      fin_cases i
      · show algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 14 hist 0 j
          = (((drS 10 0 14).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drS_getD _ 10 0 14 j hj, Nat.zero_add]
        first | done | rfl
      · show algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 14 hist 1 j
          = (((drS 13 0 14).map (Sym.eval hist 14 r.draws)).getD j Fp2.zero).toK U
        rw [drS_getD _ 13 0 14 j hj, Nat.zero_add]
        first | done | rfl
    · -- the hosted terms
      rw [algH_gh U _ dt 14 cu rt hist i (fun h => absurd h.1 (by decide)), hgh i t]
      fin_cases i
      · show _ = gV (valsF U P D hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1
          (cpt 14 (slotShape P 14).2.1 t)) (some 36) * reqV (cstK U) (valsF U P D hist r.draws (pubs 14 hist r.draws)
          (slotShape P 14).2.1 (cpt 14 (slotShape P 14).2.1 t)) 21 11 [12, 13]
        rw [hv, (dzc_gh U P D hX Pb Lay B hS t _ _ _).1]
        first | done | rfl
      · show _ = gV (valsF U P D hist r.draws (pubs 14 hist r.draws) (slotShape P 14).2.1
          (cpt 14 (slotShape P 14).2.1 t)) (some 36) * reqV (cstK U) (valsF U P D hist r.draws (pubs 14 hist r.draws)
          (slotShape P 14).2.1 (cpt 14 (slotShape P 14).2.1 t)) 20 20 [21, 22]
        rw [hv, (dzc_gh U P D hX Pb Lay B hS t _ _ _).2]
        first | done | rfl
  · -- the hosted slots' sums
    have hM : ∀ i : Fin 2, algM (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 14 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtW U P D) 14 i (.d (splitD b))) := fun i => by
      rw [algM_mm _ dt 14 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hP0 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 14 hist 0
        = fun t : Fin (5 + 9) => (r10.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 10 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 10 t r10 (by decide) hr10]
      first | done | rfl
    have hP1 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 14 hist 1
        = fun t : Fin (5 + 9) => (r13.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 13 t = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 14 13 t r13 (by decide) hr13]
      first | done | rfl
    rw [Fin.sum_univ_two, hM 0, hM 1, hP0, hP1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ ?_) (congrArg₂ (· * ·) ?_ ?_)
    all_goals first | rfl | (unfold segAt; rw [dite_eq_left (by decide)]; rfl)

end Form

end ZK60.Exec.Block.Join.W16.Dzc
