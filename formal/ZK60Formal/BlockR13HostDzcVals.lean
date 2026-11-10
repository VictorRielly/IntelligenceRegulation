/-
D63 lane L49 (2026-11-10), sub-agent dzc, part 3: **`SC_DZC`'s value list at a cube point, the batch's entries past
the named clauses, the pad planes, and the named relations embedded**, generic in the R13 configuration (the R13
counterpart of lane L44's `dzc_vals`, `xcDzc`, `pwDzc`, `relClD_alg`, `dzc_cls`, `dzc_gh`, `dzc_Z`).

* `numTabs_eqc` … `numTabs_nil`: the numbering of a slot's tables, table by table (only the reserved rows change);
* `valsN`, `tailDR`; **`dzc_vals`**: the value list `SC_DZC`'s IR reads at a cube point with the zero extension, for
  any claim sites: `eq(τ)`, `eq(p_WO)`, `eq(p_DMM)`, then `γ_a`, `γ_m`, the 39 planes, `D`, `DM`, the 17 helpers,
  `supp(D)`;
* **`xcDzcR`**: the batch's entries `13 … 29` past the thirteen named clauses, LogUp's helper relations over
  `DefR13.lksS c shD .D` read on the planes and `α`, `γ` only; **`pwDzcR`**: the 39 pad planes `(1 − supp_D)·plane`;
* **`dzc_clauses`**: the gate times each IR clause is `R13Rels`' clause `r13Cl 14 (clIx 14 κ)` of the extracted
  planes, embedded; **`dzc_gh`**: the gate times each IR host is `r13Gh 14 i`;
* **`dzc_irEval`**: `SC_DZC`'s IR read in the field (`r13DzcIr_eval`);
* **`dzc_Z`**: the batched relation (thirteen clauses, seventeen helper relations, pad term) is the IR's zero-check
  term.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostDzcSlot
import ZK60Formal.BlockR13HostBase

set_option autoImplicit false
-- The value-list and clause computations use broad simp sets; Mathlib's style linters flag the simp arguments a
-- branch did not need. Style warnings only (as in `SlotW16BuildSlots.lean`).
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false

namespace ZK60.Exec.Block.Join.R13H.Dzc

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.R13H
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg hPl cstK cstK_base cstK_p256 cstS_map tabK_pa_cpt tabK_paHead_cpt
  eqT_eval pubT_eval hTab_eval tabK_ph_cpt lkRels_congr padPls_congr toK_zpowW)
open ZK60.Exec.Block.DefW16 (W16Cfg cstS rhoC)
open ZK60.Exec.Slot.Build (Cst LkD hostTerms gV gV_some batchV logupSem padSem L256 cstW)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Layout.R13 (lv lv_three)
open Finset

/-! ## Generic facts -/

section Gen

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `Dom::D`'s point `t ++ i`, split and put back. -/
theorem append_splitDR (c : W16Cfg) (y : Fin (nD c) → Bool) : Fin.append (splitD c y).1 (splitD c y).2 = y := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

/-- A head slot and dimension `(g ++ j) ++ c`, split and put back. -/
theorem append_splitHQR (c : W16Cfg) (q : Fin (nH c + c.sh.ldh) → Bool) :
    Fin.append (Fin.append (splitHQ c q).1.1 (splitHQ c q).1.2) (splitHQ c q).2 = q := by
  funext i
  refine Fin.addCases (fun i4 => ?_) (fun i6 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

/-- A plane read through an equality of lengths. -/
theorem aPl_castB (P : BlockParams) (D : CmData K P) (off : ℕ) {n m : ℕ} (h : n = m) (b : Fin n → Bool) :
    aPl U P D off m (castB h b) = aPl U P D off n b := by
  subst h
  rfl

/-- The public tables' index through an equality of lengths. -/
theorem msbIndex_castB {n m : ℕ} (h : n = m) (b : Fin n → Bool) : msbIndex m (castB h b) = msbIndex n b := by
  subst h
  rfl

/-- Two byte limbs. -/
theorem lv_two {C : Type} (l : Fin 2 → C → GF) (x : C) : lv l x = l 0 x + 2 ^ 8 * l 1 x := by
  unfold lv
  rw [Fin.sum_univ_two]
  norm_num

/-- The builders' constants in the field. -/
theorem cK_two (v : ℤ) (h0 : 0 ≤ v) (h1 : v ≤ 2 ^ 24) : (cstK U).base (2 * v) = 2 * (v : K) := by
  rw [cstK_base U (2 * v) (by linarith) (by linarith)]
  simp only [Int.cast_mul, Int.cast_ofNat, map_mul, map_ofNat, map_intCast]

theorem cK_pow (s : ℕ) (hs : s < 63) : (cstK U).base (2 ^ s) = (2 : K) ^ s := by
  have h1 : (0 : ℤ) < 2 ^ s := by positivity
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) (by omega)
  rw [cstK_base U (2 ^ s) (by linarith) h2]
  simp only [Int.cast_pow, map_pow, Int.cast_ofNat, map_ofNat]

theorem cK_negpow (s : ℕ) (hs : s < 63) : (cstK U).base (-(2 ^ s)) = -(2 : K) ^ s := by
  have h1 : (0 : ℤ) < 2 ^ s := by positivity
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) (by omega)
  rw [cstK_base U (-(2 ^ s)) (by linarith) (by linarith)]
  simp only [Int.cast_neg, map_neg, Int.cast_pow, map_pow, Int.cast_ofNat, map_ofNat]

theorem cK_word : (cstK U).base 32768 = 32768 := by
  rw [cstK_base U 32768 (by norm_num) (by norm_num)]
  simp only [Int.cast_ofNat, map_ofNat]

theorem cK_p256 : (cstK U).p256 0 = 1 ∧ (cstK U).p256 1 = 256 ∧ (cstK U).p256 2 = 65536 := by
  refine ⟨?_, ?_, ?_⟩
  · rw [cstK_p256 U 0 (by norm_num)]; norm_num
  · rw [cstK_p256 U 1 (by norm_num)]; norm_num
  · rw [cstK_p256 U 2 (by norm_num)]; norm_num

omit [Algebra GF K] in
theorem getD3 (a b c a' b' c' : K) (T : List K) (p : ℕ) (hp : 3 ≤ p) :
    (a :: b :: c :: T).getD p 0 = (a' :: b' :: c' :: T).getD p 0 := by
  obtain ⟨q, rfl⟩ : ∃ q, p = q + 1 + 1 + 1 := ⟨p - 3, by omega⟩
  simp only [List.getD_cons_succ]

theorem pos_mapR {α β : Type} (f : α → β) (lks : List (LkD α)) (Q : ℕ → Prop) (h : ∀ l ∈ lks, ∀ t ∈ l.terms, Q t.2) :
    ∀ l ∈ lks.map (LkD.map f), ∀ t ∈ l.terms, Q t.2 := by
  intro l hl t ht
  obtain ⟨l0, hl0, rfl⟩ := List.mem_map.mp hl
  obtain ⟨t0, ht0, rfl⟩ := List.mem_map.mp ht
  exact h l0 hl0 t0 ht0

/-- **R13's lookups read only `α` and `γ`.** -/
theorem lksSR_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : ZK60.Exec.Slot.W16R2.Dom) (h h' : Hist) (k k' : ℕ)
    (dr dr' : List Fp2) (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h k dr))
      = (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h' k' dr')) := by
  unfold DefR13.lksS
  simp only [List.map_map]
  refine List.map_congr_left (fun l _ => ?_)
  simp only [Function.comp_def, LkD.map, Sym.eval, ha, hg, List.map_map]

/-- Every lookup term of `Dom::D` reads a table at position `≥ 5`. -/
theorem lksSR_pos (c : W16Cfg) : ∀ l ∈ DefR13.lksS c shD .D, ∀ t ∈ l.terms, 5 ≤ t.2 := by
  intro l hl t ht
  unfold DefR13.lksS at hl
  obtain ⟨l0, -, rfl⟩ := List.mem_map.mp hl
  obtain ⟨t0, -, rfl⟩ := List.mem_map.mp ht
  show 5 ≤ shD t0.1
  unfold shD
  omega

end Gen

/-! ## The numbering, table by table -/

section Num

theorem numTabs_nil (aB hB ioIn ioOut ak hk pk : ℕ) : DefW16.numTabs aB hB ioIn ioOut ak hk pk [] = [] := rfl

theorem numTabs_eqc (aB hB ioIn ioOut ak hk pk : ℕ) (pt : List Sym) (st : ℕ) (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.eq pt st :: ts)
      = .eq pt st :: DefW16.numTabs aB hB ioIn ioOut ak hk pk ts := rfl

theorem numTabs_pubc (aB hB ioIn ioOut ak hk pk i : ℕ) (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.pub i :: ts)
      = .pub pk :: DefW16.numTabs aB hB ioIn ioOut ak hk (pk + 1) ts := rfl

theorem numTabs_ac (aB hB ioIn ioOut ak hk pk : ℕ) (sl : List (ℕ × Bool)) (log : ℕ) (co : List CoordS) (m ex : ℕ)
    (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.priv ⟨.a, sl, log, co, m, ex⟩ :: ts)
      = .priv ⟨.a, sl, log, co, aB + 2 * ak, ex⟩ :: DefW16.numTabs aB hB ioIn ioOut (ak + 1) hk pk ts := rfl

theorem numTabs_hc (aB hB ioIn ioOut ak hk pk : ℕ) (sl : List (ℕ × Bool)) (log : ℕ) (co : List CoordS) (m ex : ℕ)
    (ts : List TabS) :
    DefW16.numTabs aB hB ioIn ioOut ak hk pk (.priv ⟨.h, sl, log, co, m, ex⟩ :: ts)
      = .priv ⟨.h, sl, log, co, hB + 2 * hk, ex⟩ :: DefW16.numTabs aB hB ioIn ioOut ak (hk + 1) pk ts := rfl

end Num

/-! ## The value list at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K]

/-- A plane of `Dom::D` read at a cube point. -/
noncomputable def pDz (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P) (q : ℕ) (b : Fin (c.sh.logs .D) → Bool) :
    K :=
  aPl U P D (DefR13.aOff c q) (c.sh.logs .D) b

/-- `Dom::D`'s LogUp helper `j` read at a cube point. -/
noncomputable def hDz (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P) (j : ℕ) (b : Fin (c.sh.logs .D) → Bool) :
    K :=
  hPl U P D (DefR13.hOff c (DefR13.fh c 1 + j)).1 (DefR13.hOff c (DefR13.fh c 1 + j)).2 (c.sh.logs .D) b

/-- **`SC_DZC`'s value list** at a point, for claim sites `ak`, `hk`. -/
noncomputable def valsN (U : K) (c : W16Cfg) (P : BlockParams) (D : CmData K P) (aB hB ioIn ioOut ak hk : ℕ)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) (n e : ℕ) (x : Fin (n + e) → K) : List K :=
  ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabsDz c)).map (TabS.eval ev pub)).map (tabK U P D n e x)

variable (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- **`SC_DZC`'s values past its three `eq` tables at a cube point** (positions `3 … 63`). -/
noncomputable def tailDR (b : Fin (c.sh.logs .D) → Bool) : List K :=
  [algebraMap GF K (B.gamA (splitD c (castB G.logD b))), algebraMap GF K (B.gamM (splitD c (castB G.logD b))),
    pDz U c P D 8 b, pDz U c P D 9 b, pDz U c P D 10 b, pDz U c P D 11 b, pDz U c P D 12 b, pDz U c P D 13 b,
    pDz U c P D 14 b, pDz U c P D 15 b, pDz U c P D 16 b, pDz U c P D 17 b, pDz U c P D 18 b, pDz U c P D 19 b,
    pDz U c P D 20 b, pDz U c P D 21 b, pDz U c P D 22 b, pDz U c P D 23 b, pDz U c P D 24 b, pDz U c P D 25 b,
    pDz U c P D 26 b, pDz U c P D 27 b, pDz U c P D 28 b, pDz U c P D 29 b, pDz U c P D 30 b, pDz U c P D 31 b,
    pDz U c P D 32 b, pDz U c P D 33 b, pDz U c P D 34 b, pDz U c P D 35 b, pDz U c P D 36 b, pDz U c P D 37 b,
    pDz U c P D 38 b, pDz U c P D 39 b, pDz U c P D 40 b, pDz U c P D 41 b, pDz U c P D 42 b, pDz U c P D 43 b,
    pDz U c P D 44 b, pDz U c P D 45 b, pDz U c P D 46 b,
    aPl U P D (DefR13.aOff c 0) c.sh.lt (splitD c (castB G.logD b)).1,
    aPl U P D (DefR13.aOff c 2) c.sh.lt (splitD c (castB G.logD b)).1,
    hDz U c P D 0 b, hDz U c P D 1 b, hDz U c P D 2 b, hDz U c P D 3 b, hDz U c P D 4 b, hDz U c P D 5 b,
    hDz U c P D 6 b, hDz U c P D 7 b, hDz U c P D 8 b, hDz U c P D 9 b, hDz U c P D 10 b, hDz U c P D 11 b,
    hDz U c P D 12 b, hDz U c P D 13 b, hDz U c P D 14 b, hDz U c P D 15 b, hDz U c P D 16 b,
    algebraMap GF K (B.gD (splitD c (castB G.logD b)))]

theorem tailDR_length (b : Fin (c.sh.logs .D) → Bool) : (tailDR U G P D Pb Lay B b).length = 61 := rfl

include G in
/-- The `Dom::D` cube's width is positive and holds the token axis. -/
theorem logD_pos : 0 < c.sh.logs .D := by
  rw [G.logD]
  exact Nat.lt_of_lt_of_le G.lt_pos (Nat.le_add_right _ _)

include G in
theorem lt_le_logD : c.sh.lt ≤ c.sh.logs .D := by
  rw [G.logD]
  exact Nat.le_add_right _ _

/-- An `A` plane of `Dom::T` on the first variables of `Dom::D`'s cube, at the zero extension. -/
theorem tabK_headR (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin (c.sh.logs .D) → Bool) (off m ext : ℕ) :
    tabK U P D (c.sh.logs .D) e (cpt (c.sh.logs .D) e b)
        (.priv ⟨.a, [(off, Fp2.one)], c.sh.lt, rhoAll c.sh.lt, m, ext⟩)
      = aPl U P D off c.sh.lt (splitD c (castB G.logD b)).1 := by
  rw [tabK_paHead_cpt U P D hrl _ e b c.sh.lt G.lt_pos (lt_le_logD G) off m ext]
  rfl

/-- **`SC_DZC`'s value list at a cube point with the zero extension**, for any claim sites. -/
theorem dzc_vals (hrl : 0 < rowLog P .a) (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin (c.sh.logs .D) → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2)
    (hp0 : ((pub 0).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gamA (splitD c (castB G.logD b))))
    (hp1 : ((pub 1).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gamM (splitD c (castB G.logD b))))
    (hp2 : ((pub 2).getD (msbIndex (c.sh.logs .D) b) Fp2.zero).toK U
      = algebraMap GF K (B.gD (splitD c (castB G.logD b)))) :
    valsN U c P D aB hB ioIn ioOut ak hk ev pub (c.sh.logs .D) e (cpt (c.sh.logs .D) e b)
      = eqPoly (fun a : Fin (c.sh.logs .D) => (((drR 14 34 (c.sh.logs .D)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin (c.sh.logs .D) => (((drR 10 0 (c.sh.logs .D)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin (c.sh.logs .D) => (((drR 13 0 (c.sh.logs .D)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: tailDR U G P D Pb Lay B b := by
  have hN := logD_pos G
  unfold valsN
  simp only [tabsDz, aPD, aPT, hPD, numTabs_eqc, numTabs_pubc, numTabs_ac, numTabs_hc, numTabs_nil, List.map_cons,
    List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D _ e b _ (drR_length 14 34 _ ev), tabK_eqFull_cpt U P D _ e b _ (drR_length 10 0 _ ev),
    tabK_eqFull_cpt U P D _ e b _ (drR_length 13 0 _ ev)]
  simp only [tabK_pa_cpt U P D hrl _ e b _ hN rfl, castB_rfl, tabK_headR U G P D hrl e b,
    tabK_ph_cpt U P D hrl _ e b _ hN rfl, tabK_pub_cpt, hp0, hp1, hp2, tailDR, pDz, hDz]

/-- Off the zero extension, `SC_DZC`'s three `eq` tables vanish. -/
theorem dzc_off (aB hB ioIn ioOut ak hk e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin (c.sh.logs .D) → Bool)
    (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    (valsN U c P D aB hB ioIn ioOut ak hk ev pub (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y)).getD 0 0 = 0
      ∧ (valsN U c P D aB hB ioIn ioOut ak hk ev pub (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y)).getD 1 0 = 0
      ∧ (valsN U c P D aB hB ioIn ioOut ak hk ev pub (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y)).getD 2 0 = 0 := by
  refine ⟨?_, ?_, ?_⟩
  · show tabK U P D (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y) (.eq ((drR 14 34 (c.sh.logs .D)).map ev) 0) = 0
    exact tabK_eq_off U P D _ e b y hy _ _
  · show tabK U P D (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y) (.eq ((drR 10 0 (c.sh.logs .D)).map ev) 0) = 0
    exact tabK_eq_off U P D _ e b y hy _ _
  · show tabK U P D (c.sh.logs .D) e (bpt (c.sh.logs .D) e b y) (.eq ((drR 13 0 (c.sh.logs .D)).map ev) 0) = 0
    exact tabK_eq_off U P D _ e b y hy _ _

/-! ### The batch's entries past the named clauses, and the pad planes -/

/-- The value list without the draws: the `eq` entries `0`. -/
noncomputable def valsXD (b : Fin (c.sh.logs .D) → Bool) : List K := 0 :: 0 :: 0 :: tailDR U G P D Pb Lay B b

/-- R13's `Dom::D` lookups at `(β, γ, α)` with no draws. -/
noncomputable def lksXR (U : K) (c : W16Cfg) (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  ((DefR13.lksS c shD .D).map (LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []))).map
    (LkD.map (Fp2.toK U))

/-- **`SC_DZC`'s batch entry `κ` past its thirteen named clauses** (`13 ≤ κ < 30`): LogUp's helper relation `κ − 13` of
`Dom::D` over `DefR13.lksS c shD .D` at the cube point `b`, read on the committed planes and `α`, `γ` only. -/
noncomputable def xcDzcR (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin (tauLen c 14) → Bool) : K :=
  (lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga)).getD (κ - 13) 0

/-- **`SC_DZC`'s pad plane `j`** (`j < 39`): `(1 − supp_D(b))·plane_j(b)` over the 39 zero-rule planes of `Dom::D`. -/
noncomputable def pwDzcR (j : ℕ) (b : Fin (tauLen c 14) → Bool) : K :=
  (padPls (valsXD U G P D Pb Lay B b) grpDz).getD j 0

end Vals

/-! ## The named relations, embedded -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

/-- `SC_DZC`'s cube encoding at a cube point. -/
theorem encR_14 (b : Fin (c.sh.logs .D) → Bool) : encR G 14 b = .d (splitD c (castB G.logD b)) := rfl

include hX in
/-- A `Dom::D` plane at the encoded point is the committed plane at the cube point. -/
theorem alg_plDR (off : ℕ) (b : Fin (c.sh.logs .D) → Bool) :
    algebraMap GF K (plD U c P D off (splitD c (castB G.logD b))) = aPl U P D off (c.sh.logs .D) b := by
  unfold plD
  rw [append_splitDR, aPl_alg U P D hX, aPl_castB]

include hX in
theorem alg_plTR (off : ℕ) (t : CtR c) : algebraMap GF K (plT U c P D off t) = aPl U P D off c.sh.lt t :=
  aPl_alg U P D hX off c.sh.lt t

include hX in
/-- **`SC_DZC`'s thirteen clauses, embedded**: the gate times the IR's clause `κ` (batch order) is `R13Rels`'
clause `r13Cl 14 (clIx 14 κ)` of the extracted planes at the encoded point. -/
theorem dzc_clauses (hS : PrecR c S) (hcfg : DzcCfg c ls) (b : Fin (c.sh.logs .D) → Bool) (e0 e1 e2 : K) :
    (ZK60.Exec.Block.Join.R13H.Dzc.r13DzcClauses (cstK U) RDz (KDz c) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b)).map
        (fun x => algebraMap GF K (B.gD (splitD c (castB G.logD b))) * x)
      = [0, 1, 6, 7, 8, 9, 2, 3, 4, 10, 11, 12, 5].map
          (fun j => algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 j (encR G 14 b))) := by
  have k1 := cK_two U c.p.cnA hcfg.cnA.1 hcfg.cnA.2
  have k2 := cK_two U c.p.cnM hcfg.cnM.1 hcfg.cnM.2
  have k3 := cK_pow U c.p.tn (by have := hcfg.tn; omega)
  have k4 := cK_negpow U (c.p.tn + 1) (by have := hcfg.tn; omega)
  have k5 := cK_word U
  obtain ⟨p0, p1, p2⟩ := cK_p256 U
  simp only [ZK60.Exec.Block.Join.R13H.Dzc.r13DzcClauses, List.map_cons, List.map_nil, List.cons.injEq,
    eq_self_iff_true, and_true]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  all_goals
    (simp only [encR_14, r13Cl, xtR, offR, lv_two, lv_three, Fin.val_zero, Fin.val_one, Fin.val_two, Nat.add_zero,
      map_mul, map_add, map_sub, map_pow, map_ofNat, map_intCast, map_one, alg_plDR U G P D hX, alg_plTR U P D hX,
      hS.cnA, hS.cnM, hS.tn, RDz, KDz, tailDR, pDz, hDz, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons,
      List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, k1, k2, k3, k4, k5, p0, p1,
      p2] <;> ring)

include hX in
/-- **`SC_DZC`'s two hosted terms, embedded**: the gate times the IR's requantization hosts (`SC_WO`, `SC_DMM`, byte
limbs) are `r13Gh 14 0`, `r13Gh 14 1`. -/
theorem dzc_gh (hS : PrecR c S) (hcfg : DzcCfg c ls) (b : Fin (c.sh.logs .D) → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) (some 63)
        * reqV8 (cstK U) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) c.p.ao 17 [20, 21, 22]
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 14 0 (encR G 14 b))
    ∧ gV (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) (some 63)
        * reqV8 (cstK U) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) c.p.down 35 [38, 39, 40]
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 14 1 (encR G 14 b)) := by
  have k1 := cK_pow U c.p.ao (by have := hcfg.ao.2; omega)
  have k2 := cK_negpow U (c.p.ao - 1) (by have := hcfg.ao.2; omega)
  have k3 := cK_pow U c.p.down (by have := hcfg.down.2; omega)
  have k4 := cK_negpow U (c.p.down - 1) (by have := hcfg.down.2; omega)
  obtain ⟨p0, p1, p2⟩ := cK_p256 U
  refine ⟨?_, ?_⟩
  all_goals
    (simp only [encR_14, r13Gh, xtR, offR, lv_three, Fin.val_zero, Fin.val_one, Fin.val_two, Nat.add_zero, map_mul,
      map_add, map_sub, map_pow, map_ofNat, map_one, alg_plDR U G P D hX, hS.sao, hS.sdown, gV_some, reqV8,
      tailDR, pDz, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
      List.getD_cons_succ, List.getD_cons_zero, k1, k2, k3, k4, p0, p1, p2] <;> ring)

end Rels

/-! ## The IR read in the field, and the batched relation -/

section Z

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- **`SC_DZC`'s zero-check term**: LogUp's helper relations, the pad term and the gated clauses. -/
noncomputable def zD (c : W16Cfg) (hist : Hist) (dr : List Fp2) (v : List K) : K :=
  logupSem (cstK U) v 46 (fun k => (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (13 + k) 0) 0
      (((DefR13.lksS c shD .D).map (LkD.map (Sym.eval hist 14 dr))).map (LkD.map (Fp2.toK U)))
    + padSem (cstK U) v ((((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 30 0)
        (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 33) j)) 0 grpDz
    + gV v (some 63) * batchV (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
        (ZK60.Exec.Block.Join.R13H.Dzc.r13DzcClauses (cstK U) RDz (KDz c) v)

/-- **`SC_DZC`'s IR read in the field** (`r13DzcIr_eval` at the code's words). -/
theorem dzc_irEval {c : W16Cfg} {ls : ℕ} (hcfg : DzcCfg c ls) (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((irDz c).map (Sym.eval hist 14 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 (some 63) (some 63) (((drR 14 31 2).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (zD U c hist dr v) (reqV8 (cstK U) v c.p.ao 17 [20, 21, 22])
          (reqV8 (cstK U) v c.p.down 35 [38, 39, 40]) := by
  unfold irDz
  rw [r13DzcIr_map, r13DzcIr_map, cstS_map, r13DzcIr_eval _ (cstW_map_std U)]
  rw [List.length_map, List.length_map, hcfg.lks]
  first | done | rfl

/-- The weights `μ_k` of the IR, read off the draws. -/
theorem muR_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 31) :
    (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD k 0 = (dr.getD k Fp2.zero).toK U := by
  unfold drR
  rw [List.map_map, List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hk]
  simp [Sym.eval, drawAt]

omit [Algebra GF K] in
/-- `gate·Σ_k μ_k·c_k = Σ_k μ_k·(gate·c_k)`. -/
theorem batchV_mul (mu : List K) (g : K) : ∀ (n : ℕ) (cs : List K),
    g * ((cs.zipIdx n).map fun q => mu.getD q.2 0 * q.1).sum
      = (((cs.map (g * ·)).zipIdx n).map fun q => mu.getD q.2 0 * q.1).sum
  | _, [] => by simp
  | n, x :: xs => by
    have ih := batchV_mul mu g (n + 1) xs
    calc g * (((x :: xs).zipIdx n).map fun q => mu.getD q.2 0 * q.1).sum
        = g * (mu.getD n 0 * x + ((xs.zipIdx (n + 1)).map fun q => mu.getD q.2 0 * q.1).sum) := by
          rw [List.zipIdx_cons, List.map_cons, List.sum_cons]
      _ = mu.getD n 0 * (g * x) + g * ((xs.zipIdx (n + 1)).map fun q => mu.getD q.2 0 * q.1).sum := by ring
      _ = (((((x :: xs).map (g * ·))).zipIdx n).map fun q => mu.getD q.2 0 * q.1).sum := by
          rw [ih, List.map_cons, List.zipIdx_cons, List.map_cons, List.sum_cons]

/-- `SC_DZC`'s batch order. -/
theorem clIx_14 (κ : ℕ) : clIx 14 κ = [0, 1, 6, 7, 8, 9, 2, 3, 4, 10, 11, 12, 5].getD κ κ := by
  unfold clIx
  exact ite_eq_left rfl

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)

include hX in
/-- **The gated clauses**: the gate times the IR's batch of the thirteen clauses is the weighted sum of `R13Rels`'
clauses `r13Cl 14 (clIx 14 κ)`, embedded. -/
theorem dzc_cls (hS : PrecR c S) (hcfg : DzcCfg c ls) (hist : Hist) (dr : List Fp2) (b : Fin (c.sh.logs .D) → Bool)
    (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) (some 63)
        * batchV (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U))
          (ZK60.Exec.Block.Join.R13H.Dzc.r13DzcClauses (cstK U) RDz (KDz c) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b))
      = ∑ κ ∈ range 13, (dr.getD κ Fp2.zero).toK U
          * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b)) := by
  have hg : gV (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) (some 63)
      = algebraMap GF K (B.gD (splitD c (castB G.logD b))) := by
    rw [gV_some]
    rfl
  unfold batchV
  rw [hg, batchV_mul, dzc_clauses U G P D hX Pb Lay B hS hcfg b e0 e1 e2]
  simp only [List.map_cons, List.map_nil, List.zipIdx_cons, List.zipIdx_nil, List.sum_cons, List.sum_nil,
    Finset.sum_range_succ, Finset.sum_range_zero, clIx_14, List.getD_cons_succ, List.getD_cons_zero, zero_add]
  rw [muR_getD U hist dr 0 (by norm_num), muR_getD U hist dr 1 (by norm_num), muR_getD U hist dr 2 (by norm_num),
    muR_getD U hist dr 3 (by norm_num), muR_getD U hist dr 4 (by norm_num), muR_getD U hist dr 5 (by norm_num),
    muR_getD U hist dr 6 (by norm_num), muR_getD U hist dr 7 (by norm_num), muR_getD U hist dr 8 (by norm_num),
    muR_getD U hist dr 9 (by norm_num), muR_getD U hist dr 10 (by norm_num), muR_getD U hist dr 11 (by norm_num),
    muR_getD U hist dr 12 (by norm_num)]
  ring

include hU hX in
/-- **`SC_DZC`'s batched relation is the IR's zero-check term**: the thirteen gated clauses (`r13Cl 14` in the IR's
batch order), the seventeen LogUp helper relations (`xcDzcR`) and the pad term (`pwDzcR`, weights `ζ^j`). -/
theorem dzc_Z (hS : PrecR c S) (hcfg : DzcCfg c ls) (hist : Hist) (dr : List Fp2) (bga : Fp2 × Fp2 × Fp2)
    (hα : hist.alpha = bga.2.2) (hγ : hist.gamma = bga.2.1) (b : Fin (c.sh.logs .D) → Bool) (e0 e1 e2 : K) :
    (∑ κ ∈ range 30, (dr.getD κ Fp2.zero).toK U
        * (if κ < 13 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b))
          else xcDzcR U G P D Pb Lay B bga κ b))
      + (dr.getD 30 Fp2.zero).toK U
        * ∑ j ∈ range 39, ((dr.getD 33 Fp2.zero).toK U) ^ j * pwDzcR U G P D Pb Lay B j b
    = zD U c hist dr (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) := by
  -- the LogUp helpers read only positions `≥ 3`
  have hlks : ((DefR13.lksS c shD .D).map (LkD.map (Sym.eval hist 14 dr))).map (LkD.map (Fp2.toK U))
      = lksXR U c bga := by
    unfold lksXR
    rw [lksSR_eval c shD .D hist (histOf bga.1 bga.2.1 bga.2.2 []) 14 14 dr [] hα hγ]
  have hlk : lkRels (cstK U) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) 46 0 (lksXR U c bga)
      = lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga) := by
    refine lkRels_congr (cstK U) _ _ 46 0 (lksXR U c bga) (fun l hl tt htt => ?_) (fun i _ => ?_)
    · have h5 : 5 ≤ tt.2 := pos_mapR (Fp2.toK U) _ (fun q => 5 ≤ q)
        (pos_mapR (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 14 []) (DefR13.lksS c shD .D) (fun q => 5 ≤ q)
          (lksSR_pos c)) l hl tt htt
      exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
    · exact getD3 e0 e1 e2 0 0 0 _ _ (by omega)
  have hlkl : (lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga)).length = 17 := by
    rw [lkRels_length]
    unfold lksXR
    rw [List.length_map, List.length_map, hcfg.lks]
  have hpd : padPls (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) grpDz = padPls (valsXD U G P D Pb Lay B b) grpDz := by
    refine padPls_congr _ _ grpDz (fun g hg => ?_)
    simp only [grpDz, List.mem_cons, List.not_mem_nil, or_false] at hg
    subst hg
    refine ⟨getD3 e0 e1 e2 0 0 0 _ _ (by norm_num), fun p hp => getD3 e0 e1 e2 0 0 0 _ _ ?_⟩
    have := (List.mem_range'_1.mp hp).1
    omega
  have hpdl : (padPls (valsXD U G P D Pb Lay B b) grpDz).length = 39 := by
    simp [grpDz, padPls]
  -- the three parts
  have hA := dzc_cls U G P D hX Pb Lay B hS hcfg hist dr b e0 e1 e2
  have hLg : logupSem (cstK U) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b) 46
      (fun k => (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD (13 + k) 0) 0
      (((DefR13.lksS c shD .D).map (LkD.map (Sym.eval hist 14 dr))).map (LkD.map (Fp2.toK U)))
      = ∑ x ∈ range 17, (dr.getD (13 + x) Fp2.zero).toK U
          * (lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga)).getD x 0 := by
    rw [logupSem_eq_wsum, hlks, hlk, wsum_eq_sum,
      Fin.sum_univ_eq_sum_range (fun i => (((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD
        (13 + (0 + i)) 0 * (lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga)).getD i 0), hlkl]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    rw [Nat.zero_add, muR_getD U hist dr (13 + i) (by have := Finset.mem_range.mp hi; omega)]
  have hP : padSem (cstK U) (e0 :: e1 :: e2 :: tailDR U G P D Pb Lay B b)
      ((((drR 14 0 31).map (Sym.eval hist 14 dr)).map (Fp2.toK U)).getD 30 0)
      (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 33) j)) 0 grpDz
      = (dr.getD 30 Fp2.zero).toK U * ∑ j ∈ range 39, ((dr.getD 33 Fp2.zero).toK U) ^ j
          * pwDzcR U G P D Pb Lay B j b := by
    rw [padSem_eq_wsum _ (cstW_map_std U), hpd, wsum_eq_sum, muR_getD U hist dr 30 (by norm_num)]
    refine congrArg (fun z => (dr.getD 30 Fp2.zero).toK U * z) ?_
    rw [Fin.sum_univ_eq_sum_range (fun j => (Fp2.toK U ∘ (Sym.eval hist 14 dr ∘ fun j => Sym.pow (Sym.dr 14 33) j))
      (0 + j) * (padPls (valsXD U G P D Pb Lay B b) grpDz).getD j 0), hpdl]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval hist 14 dr (Sym.dr 14 33)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    simp [Sym.eval, drawAt, pwDzcR]
  -- assemble
  unfold zD
  rw [hLg, hP, hA]
  have h30 := Finset.sum_range_add (fun κ => (dr.getD κ Fp2.zero).toK U
      * (if κ < 13 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b))
        else xcDzcR U G P D Pb Lay B bga κ b)) 13 17
  beta_reduce at h30
  rw [show 13 + 17 = 30 from rfl] at h30
  rw [h30]
  have hc : ∀ κ ∈ range 13, (dr.getD κ Fp2.zero).toK U
      * (if κ < 13 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b))
        else xcDzcR U G P D Pb Lay B bga κ b)
      = (dr.getD κ Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 κ) (encR G 14 b)) :=
    fun κ hκ => by rw [ite_eq_left (Finset.mem_range.mp hκ)]
  have hn : ∀ x ∈ range 17, (dr.getD (13 + x) Fp2.zero).toK U
      * (if 13 + x < 13 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 14 (clIx 14 (13 + x)) (encR G 14 b))
        else xcDzcR U G P D Pb Lay B bga (13 + x) b)
      = (dr.getD (13 + x) Fp2.zero).toK U
          * (lkRels (cstK U) (valsXD U G P D Pb Lay B b) 46 0 (lksXR U c bga)).getD x 0 :=
    fun x _ => by
      rw [ite_eq_right (by omega)]
      unfold xcDzcR
      rw [Nat.add_sub_cancel_left]
  rw [Finset.sum_congr rfl hc, Finset.sum_congr rfl hn]
  ring

end Z

end ZK60.Exec.Block.Join.R13H.Dzc
