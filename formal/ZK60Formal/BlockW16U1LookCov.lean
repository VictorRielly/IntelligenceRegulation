/-
D63 W16R2 Shieldstral port (`BlockW16U1LookCov.lean`):
**every logical lookup of the W16R2 Shieldstral (`export_u1`) block is an entry of `AlkU1`
(`cover_xtU1`, `cover_xtU1_query`, `hcov_u1`, `hcov_shieldU1`).**

Mirrors `BlockLookCov.lean` and `BlockLookCov2.lean` at the A29-uniform `export_u1` configuration
`c0 = cfgShieldU1 0 0` (`PrecR (cfgU1 cnA cnM) S`):
* `lenL_u1 .. lenF_u1`: the lookup list lengths (`L:2, D:19, Q:6, Kv:6, S:7, F:7`);
* `exists_lkU1`, `exists_expU1`, `exists_actU1`: every code lookup (`lookupsN c0 d`, at every
  point of its domain's cube), every exp tuple and every ACT tuple is an entry of `AlkU1`;
* `lkAtU1_congr`, `expTupU1_congr`, `actTupU1_congr`: the tuples read only the `A` planes;
* `cov_genU1`, `cov_twoU1`, `covRU1`, `covCU1`, `covNU1`, `covLimbU1`: each code lookup's tuple
  at a cube point is the image of the plane's range query on a base-valued `A` matrix;
* **`cover_xtU1`**, **`cover_xtU1_query`**: every field of `W16LookupsG` (`la`, `lm`, `dW`, `dR`,
  `qW`, `qR`, `kW`, `kR`, `sB`, `sR`, `sExp`, `fR`, `fAct`) — including 1-limb `sr = [45]` and
  `sg = [46]` at `wrho = 16` via `remLk_one` + `remR_lo1`, and `sdown = 22` (`6`-bit hi),
  `score = 19` (`3`-bit hi), `gate = 20` (`4`-bit hi) — asks only tuples that are entries of
  `AlkU1`;
* **`hcov_u1`**, **`hcov_shieldU1`**: `block_knowledge_join_w16r2_shieldU1`'s `hcov` premise,
  PROVED for `AlkU1` on the data the `A` cut fixes (`dofAU1`), on every outcome.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.BlockW16U1LookBase
import ZK60Formal.BlockLookEntry
import ZK60Formal.BlockLookCov

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16U1.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB piB_alg alg_piB aPl_base aPl_alg remR)
open ZK60.Exec.Block.Join.W16.Look (aPl_flat remLk_one remLk_two)
open ZK60.Exec.Block.Join.R13H (PrecR splitD splitQ splitK splitHt splitS splitF
  splitD_append splitQ_append splitK_append splitHt_append splitS_append splitF_append
  plT plD plQ plK plS plH plF plL nD nH nQ nK nS nHt nF)
open ZK60.Exec.Block.Join.W16U1
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct rangeQuery expQuery actQuery)
open ZK60.RunShape.Shield (ShieldLayer shieldShape)
open ZK60.RunShape.ShieldU1 (shieldExportU1)
open ZK60.Layout

/-! ## 1. Lookup list lengths at `export_u1` -/

theorem lenL_u1 : (lookupsN c0 LkDomU1.L.dom).length = 2 := by decide
theorem lenD_u1 : (lookupsN c0 LkDomU1.D.dom).length = 19 := by decide
theorem lenQ_u1 : (lookupsN c0 LkDomU1.Q.dom).length = 6 := by decide
theorem lenK_u1 : (lookupsN c0 LkDomU1.Kv.dom).length = 6 := by decide
theorem lenS_u1 : (lookupsN c0 LkDomU1.S.dom).length = 7 := by decide
theorem lenF_u1 : (lookupsN c0 LkDomU1.F.dom).length = 7 := by decide

/-! ## 2. Every code lookup is an entry of `AlkU1` -/

section Alk

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig))

/-- **Every lookup of a domain at `export_u1`, at every point of its cube, is an entry of `AlkU1`.** -/
theorem exists_lkU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (b : Fin d.log → Bool) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = lkAtU1 U P (Dof cut) d i b := by
  by_cases h2 : i < 2 * d.np
  · obtain ⟨j, rfl | rfl⟩ := Nat.even_or_odd' i
    · exact ⟨.inr (.inl ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
    · exact ⟨.inr (.inr ⟨d, ⟨j, by omega⟩, b⟩), rfl⟩
  · cases d with
    | L =>
      have h := lenL_u1
      exact absurd (show i < 2 * 1 by omega) h2
    | D =>
      have h := lenD_u1
      obtain rfl : i = 18 := by simp only [LkDomU1.np] at h2; omega
      exact ⟨.inl ⟨SgKindU1.D, b⟩, rfl⟩
    | Q =>
      have h := lenQ_u1
      exact absurd (show i < 2 * 3 by omega) h2
    | Kv =>
      have h := lenK_u1
      exact absurd (show i < 2 * 3 by omega) h2
    | S =>
      have h := lenS_u1
      obtain rfl : i = 6 := by simp only [LkDomU1.np] at h2; omega
      exact ⟨.inl ⟨SgKindU1.S, b⟩, rfl⟩
    | F =>
      have h := lenF_u1
      obtain rfl : i = 6 := by simp only [LkDomU1.np] at h2; omega
      exact ⟨.inl ⟨SgKindU1.F, b⟩, rfl⟩

/-- Every exp tuple at `export_u1` is an entry of `AlkU1`. -/
theorem exists_expU1 (b : Fin 19 → Bool) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = expTupU1 U P (Dof cut) Pb Lay B b :=
  ⟨.inl ⟨SgKindU1.Exp, b⟩, rfl⟩

/-- Every ACT tuple at `export_u1` is an entry of `AlkU1`. -/
theorem exists_actU1 (b : Fin 21 → Bool) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = actTupU1 U P (Dof cut) Pb Lay B b :=
  ⟨.inl ⟨SgKindU1.Act, b⟩, rfl⟩

end Alk

/-! ## 3. The tuples read only the `A` planes -/

section Congr

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D1 D2 : CmData K P)
  (h : ∀ off log b, aPl U P D1 off log b = aPl U P D2 off log b)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)

include h

theorem lkAtU1_congr (d : LkDomU1) (i : ℕ) (b : Fin d.log → Bool) :
    lkAtU1 U P D1 d i b = lkAtU1 U P D2 d i b := by
  unfold lkAtU1 lkTupU1
  simp only [h]

theorem expTupU1_congr (b : Fin 19 → Bool) :
    expTupU1 U P D1 Pb Lay B b = expTupU1 U P D2 Pb Lay B b := by
  unfold expTupU1
  simp only [h]

theorem actTupU1_congr (b : Fin 21 → Bool) :
    actTupU1 U P D1 Pb Lay B b = actTupU1 U P D2 Pb Lay B b := by
  unfold actTupU1
  simp only [h]

end Congr

/-! ## 4. A code lookup's tuple is its plane's range query -/

section Cov

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hD in
/-- **A one-term lookup of `lookupsN c0` covers the range query of the value it reads.** -/
theorem cov_genU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (q : ℕ)
    (cf cst : ℤ) (w : ℕ)
    (hl : (lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, cf)], cst, w⟩) (b : Fin d.log → Bool) (x : GF)
    (hx : algebraMap GF K x = (cf : K) * aPl U P D (offU1 q) d.log b + (cst : K)) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) x) := by
  obtain ⟨l, hl'⟩ := exists_lkU1 U P Pb Lay B Dof cut d i hi b
  refine ⟨l, ?_⟩
  rw [hl', lkAtU1_congr U P (Dof cut) D hD]
  unfold lkAtU1 lkTupU1
  rw [hl]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, tupK, rangeQuery, hx,
    map_natCast, map_zero]

include hD in
/-- **A two-term lookup** (`H − 2^16·Htop`). -/
theorem cov_twoU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (q1 q2 : ℕ)
    (c1 c2 cst : ℤ) (w : ℕ)
    (hl : (lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q1, c1), (q2, c2)], cst, w⟩) (b : Fin d.log → Bool)
    (x : GF)
    (hx : algebraMap GF K x = (c1 : K) * aPl U P D (offU1 q1) d.log b + (c2 : K) * aPl U P D (offU1 q2) d.log b + (cst : K)) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) x) := by
  obtain ⟨l, hl'⟩ := exists_lkU1 U P Pb Lay B Dof cut d i hi b
  refine ⟨l, ?_⟩
  rw [hl', lkAtU1_congr U P (Dof cut) D hD]
  unfold lkAtU1 lkTupU1
  rw [hl]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero, tupK, rangeQuery, hx,
    map_natCast, map_zero, add_assoc]

include hD hX in
/-- A remainder limb (`cst = 0`): the range query of the plane's value. -/
theorem covRU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (q w : ℕ)
    (hl : (lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, 1)], 0, w⟩) (b : Fin d.log → Bool) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (piB K (aPl U P D (offU1 q) d.log b))) :=
  cov_genU1 U P Pb Lay B Dof cut D hD d i hi q 1 0 w hl b _ (by
    rw [aPl_alg U P D hX]
    push_cast
    ring)

include hD hX in
/-- A word or byte with a constant (`plane + k`). -/
theorem covCU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (q : ℕ) (cst : ℤ) (w : ℕ)
    (hl : (lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, 1)], cst, w⟩) (b : Fin d.log → Bool) (k : GF)
    (hk : algebraMap GF K k = (cst : K)) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (piB K (aPl U P D (offU1 q) d.log b) + k)) :=
  cov_genU1 U P Pb Lay B Dof cut D hD d i hi q 1 cst w hl b _ (by
    rw [map_add, aPl_alg U P D hX, hk]
    push_cast
    ring)

include hD hX in
/-- A negated byte with a constant (`−plane + k`). -/
theorem covNU1 (d : LkDomU1) (i : ℕ) (hi : i < (lookupsN c0 d.dom).length) (q : ℕ) (cst : ℤ) (w : ℕ)
    (hl : (lookupsN c0 d.dom).getD i ⟨[], 0, 0⟩ = ⟨[(q, -1)], cst, w⟩) (b : Fin d.log → Bool) (k : GF)
    (hk : algebraMap GF K k = (cst : K)) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK (rangeQuery (tagW w) (-piB K (aPl U P D (offU1 q) d.log b) + k)) :=
  cov_genU1 U P Pb Lay B Dof cut D hD d i hi q (-1) cst w hl b _ (by
    rw [map_add, map_neg, aPl_alg U P D hX, hk]
    push_cast
    ring)

include hD hX in
/-- **An isqrt limb of `Dom::L` at `export_u1`** (a `128`-entry sub-slice, `lt = 7`) is the code's
`14`-bit `Dom::L` lookup at the same flat index. -/
theorem covLimbU1 (hlc : P.logCols = 14) (j : ℕ) (hj : j < 2) (q : ℕ)
    (hl : (lookupsN c0 LkDomU1.L.dom).getD j ⟨[], 0, 0⟩ = ⟨[(q, 1)], 0, 8⟩)
    (i k : Fin 3) (t : CtU1) :
    ∃ l, AlkU1 U P Pb Lay B Dof cut l
      = tupK (rangeQuery (tagW 8) (piB K (aPl U P D (offU1 q + (3 * (i : ℕ) + k) * 2 ^ 7) 7 t))) := by
  have hr0 : rowLog P .a = 14 := hlc
  let t7 : Fin 7 → Bool := t
  have hi := i.isLt
  have hk := k.isLt
  have ht := msbIndex_lt 7 t7
  have h7 : (2 : ℕ) ^ 7 = 128 := by norm_num
  have h14 : (2 : ℕ) ^ 14 = 16384 := by norm_num
  have hlt : (3 * (i : ℕ) + k) * 2 ^ 7 + msbIndex 7 t7 < 2 ^ 14 := by rw [h14, h7]; rw [h7] at ht; omega
  obtain ⟨X, hX0⟩ : ∃ X, offU1 q = X * 2 ^ 14 := ⟨_, rfl⟩
  rw [h14] at hX0
  have hLlen := lenL_u1
  refine cov_genU1 U P Pb Lay B Dof cut D hD .L j (by omega) q 1 0 8 hl
    (msbBits 14 ((3 * (i : ℕ) + k) * 2 ^ 7 + msbIndex 7 t7)) _ ?_
  show algebraMap GF K (piB K (aPl U P D (offU1 q + (3 * (i : ℕ) + k) * 2 ^ 7) 7 t7))
    = ((1 : ℤ) : K) * aPl U P D (offU1 q) 14 (msbBits 14 ((3 * (i : ℕ) + k) * 2 ^ 7 + msbIndex 7 t7)) + ((0 : ℤ) : K)
  rw [aPl_alg U P D hX]
  rw [aPl_flat U P D (offU1 q + (3 * (i : ℕ) + k) * 2 ^ 7) 7 (offU1 q) 14 t7
    (msbBits 14 ((3 * (i : ℕ) + k) * 2 ^ 7 + msbIndex 7 t7))
    (by rw [hr0, hX0, h14, h7]; omega)
    (by rw [hr0, hX0, h14]; omega)
    (by rw [hr0, hX0, h14, h7]; omega)
    (by rw [hr0, msbIndex_msbBits 14 _ hlt, hX0, h14, h7]; omega)]
  push_cast
  ring

end Cov

/-! ## 5. The full cover at `export_u1` -/

section Cover

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
  (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hD hX in
/-- **Every logical lookup of `xtU1` is an entry of `AlkU1`**, on a base-valued `A` matrix at
`export_u1`'s precision (`PrecR (cfgU1 cnA cnM) S`) and row log `14`. -/
theorem cover_xtU1 {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S) (hlc : P.logCols = 14) :
    W16LookupsG (fun u => ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK u) Pb Lay B (xtU1 U P D) := by
  have hsao : S.sao = 21 := hS.sao
  have hsdown : S.sdown = 22 := hS.sdown
  have hsq : S.sq = 15 := hS.sq
  have hspv : S.spv = 12 := hS.spv
  have hsk : S.sk = 15 := hS.sk
  have hsv : S.sv = 16 := hS.sv
  have hss : S.ss = 19 := hS.ss
  have hfp : S.fp = 12 := hS.fp
  have hwrho : S.wrho = 16 := hS.wrho
  have hsgate : S.sgate = 20 := hS.sgate
  have hsup : S.sup = 12 := hS.sup
  have hsprod : S.sprod = 16 := hS.sprod
  exact
    { la := fun t i k =>
        covLimbU1 U P Pb Lay B Dof cut D hD hX hlc 0 (by norm_num) 6 rfl i k (Lay.tok.emb t)
      lm := fun t i k =>
        covLimbU1 U P Pb Lay B Dof cut D hD hX hlc 1 (by norm_num) 7 rfl i k (Lay.tok.emb t)
      dW := fun p w hw => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
        rcases hw with rfl | rfl | rfl | rfl | rfl | rfl | rfl
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 0 (by rw [lenD_u1]; norm_num) 8 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 1 (by rw [lenD_u1]; norm_num) 9 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 6 (by rw [lenD_u1]; norm_num) 14 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 9 (by rw [lenD_u1]; norm_num) 17 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 10 (by rw [lenD_u1]; norm_num) 18 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 15 (by rw [lenD_u1]; norm_num) 23 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .D 18 (by rw [lenD_u1]; norm_num) 26 32768 16 rfl
            (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
      dR := fun p =>
        ⟨remLk_two 24 8 (by norm_num) rfl _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 2 (by rw [lenD_u1]; norm_num) 10 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 3 (by rw [lenD_u1]; norm_num) 11 8 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
          remLk_two 24 8 (by norm_num) rfl _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 4 (by rw [lenD_u1]; norm_num) 12 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 5 (by rw [lenD_u1]; norm_num) 13 8 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
          remLk_two 24 8 (by norm_num) rfl _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 11 (by rw [lenD_u1]; norm_num) 19 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 12 (by rw [lenD_u1]; norm_num) 20 8 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
          remLk_two 24 8 (by norm_num) rfl _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 13 (by rw [lenD_u1]; norm_num) 21 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 14 (by rw [lenD_u1]; norm_num) 22 8 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
          remLk_two S.sao 5 (by rw [hsao]; norm_num) (by rw [hsao]) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 7 (by rw [lenD_u1]; norm_num) 15 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 8 (by rw [lenD_u1]; norm_num) 16 5 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
          remLk_two S.sdown 6 (by rw [hsdown]; norm_num) (by rw [hsdown]) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 16 (by rw [lenD_u1]; norm_num) 24 16 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .D 17 (by rw [lenD_u1]; norm_num) 25 6 rfl
              (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))⟩
      qW := fun p w hw => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
        rcases hw with rfl | rfl | rfl
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Q 0 (by rw [lenQ_u1]; norm_num) 27 32768 16 rfl
            (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
            32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Q 2 (by rw [lenQ_u1]; norm_num) 29 32768 16 rfl
            (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
            32768 (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Q 4 (by rw [lenQ_u1]; norm_num) 31 32768 16 rfl
            (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
            32768 (by simp only [map_ofNat, Int.cast_ofNat])
      qR := fun p =>
        ⟨remLk_one S.sq (by rw [hsq]; norm_num) _ _ (by
            rw [hsq]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .Q 1 (by rw [lenQ_u1]; norm_num) 28 15 rfl
              (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))),
          remLk_one 7 (by norm_num) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .Q 3 (by rw [lenQ_u1]; norm_num) 30 7 rfl
              (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))),
          remLk_one S.spv (by rw [hspv]; norm_num) _ _ (by
            rw [hspv]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .Q 5 (by rw [lenQ_u1]; norm_num) 32 12 rfl
              (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2)))⟩
      kW := fun p w hw => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
        rcases hw with rfl | rfl | rfl
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Kv 0 (by rw [lenK_u1]; norm_num) 33 32768 16 rfl
            (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768
            (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Kv 2 (by rw [lenK_u1]; norm_num) 35 32768 16 rfl
            (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768
            (by simp only [map_ofNat, Int.cast_ofNat])
        · exact covCU1 U P Pb Lay B Dof cut D hD hX .Kv 4 (by rw [lenK_u1]; norm_num) 37 32768 16 rfl
            (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768
            (by simp only [map_ofNat, Int.cast_ofNat])
      kR := fun p =>
        ⟨remLk_one S.sk (by rw [hsk]; norm_num) _ _ (by
            rw [hsk]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .Kv 1 (by rw [lenK_u1]; norm_num) 34 15 rfl
              (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))),
          remLk_one S.sv (by rw [hsv]) _ _ (by
            rw [hsv]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .Kv 3 (by rw [lenK_u1]; norm_num) 36 16 rfl
              (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))),
          remLk_one 7 (by norm_num) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .Kv 5 (by rw [lenK_u1]; norm_num) 38 7 rfl
              (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)))⟩
      sB := fun p =>
        ⟨covCU1 U P Pb Lay B Dof cut D hD hX .S 0 (by rw [lenS_u1]; norm_num) 39 127 8 rfl
            (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
            127 (by simp only [map_ofNat, Int.cast_ofNat]),
          covNU1 U P Pb Lay B Dof cut D hD hX .S 1 (by rw [lenS_u1]; norm_num) 39 127 8 rfl
            (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
            127 (by simp only [map_ofNat, Int.cast_ofNat])⟩
      sR := fun p =>
        ⟨remLk_two S.ss 3 (by rw [hss]; norm_num) (by rw [hss]) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .S 2 (by rw [lenS_u1]; norm_num) 40 16 rfl
              (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))
            (covRU1 U P Pb Lay B Dof cut D hD hX .S 3 (by rw [lenS_u1]; norm_num) 41 3 rfl
              (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))),
          by
            rw [hfp]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .S 4 (by rw [lenS_u1]; norm_num) 44 13 rfl
              (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)),
          -- `wrho = 16`: `sr = [45]` is single-limb!
          remLk_one S.wrho (by rw [hwrho]) _ _ (by
            rw [hwrho]
            dsimp only [xtU1]
            rw [remR_lo1]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .S 5 (by rw [lenS_u1]; norm_num) 45 16 rfl
              (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))),
          -- `wrho = 16`: `sg = [46]` is single-limb (lookup 6 = `SgKindU1.S`)!
          remLk_one S.wrho (by rw [hwrho]) _ _ (by
            rw [hwrho]
            dsimp only [xtU1]
            rw [remR_lo1]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .S 6 (by rw [lenS_u1]; norm_num) 46 16 rfl
              (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))⟩
      sExp := fun p => by
        let bS : Fin 19 → Bool :=
          Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)
        let bHt : Fin 12 → Bool := Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Lay.sPos p).2.1
        obtain ⟨l, hl⟩ := exists_expU1 U P Pb Lay B Dof cut bS
        refine ⟨l, ?_⟩
        rw [hl, expTupU1_congr U P (Dof cut) D hD]
        have hs : splitS c0 bS = Lay.sPos p := splitS_append c0 (Lay.sPos p)
        have hh : hd12 bS = bHt := by
          rw [← append_splitS_hd12 bS, hs]
        unfold expTupU1
        rw [hs, hh]
        refine Tup.ext' ?_ ?_ ?_ ?_
        · show _ = algebraMap GF K (piB K (aPl U P D (offU1 4) 12 bHt)
            - B.mask (Lay.sPos p) * (piB K (aPl U P D (offU1 39) 19 bS) + 127) + 127)
          simp only [map_add, map_sub, map_mul, map_ofNat, aPl_alg U P D hX]
          ring
        · exact (map_natCast (algebraMap GF K) tagExp).symm
        · show _ = algebraMap GF K (piB K (aPl U P D (offU1 43) 19 bS))
          rw [aPl_alg U P D hX]
        · show _ = algebraMap GF K 0
          rw [map_zero]
      fR := fun p =>
        ⟨remLk_two S.sgate 4 (by rw [hsgate]; norm_num) (by rw [hsgate]) _ _
            (covRU1 U P Pb Lay B Dof cut D hD hX .F 0 (by rw [lenF_u1]; norm_num) 48 16 rfl
              (Fin.append (Lay.fPos p).1 (Lay.fPos p).2))
            (covRU1 U P Pb Lay B Dof cut D hD hX .F 1 (by rw [lenF_u1]; norm_num) 49 4 rfl
              (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)),
          covCU1 U P Pb Lay B Dof cut D hD hX .F 2 (by rw [lenF_u1]; norm_num) 51 32768 16 rfl
            (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat]),
          remLk_one S.sup (by rw [hsup]; norm_num) _ _ (by
            rw [hsup]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .F 3 (by rw [lenF_u1]; norm_num) 52 12 rfl
              (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)),
          cov_twoU1 U P Pb Lay B Dof cut D hD .F 4 (by rw [lenF_u1]; norm_num) 53 54 1 (-65536) 0 16 rfl
            (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) _ (by
              let bF : Fin 21 → Bool := Fin.append (Lay.fPos p).1 (Lay.fPos p).2
              show algebraMap GF K (piB K (aPl U P D (offU1 53) 21 bF)
                - 2 ^ 16 * piB K (aPl U P D (offU1 54) 21 bF))
                = ((1 : ℤ) : K) * aPl U P D (offU1 53) 21 bF
                  + ((-65536 : ℤ) : K) * aPl U P D (offU1 54) 21 bF
                  + ((0 : ℤ) : K)
              simp only [map_sub, map_mul, map_pow, map_ofNat, aPl_alg U P D hX]
              push_cast
              ring),
          covCU1 U P Pb Lay B Dof cut D hD hX .F 5 (by rw [lenF_u1]; norm_num) 54 128 8 rfl
            (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) 128 (by simp only [map_ofNat, Int.cast_ofNat]),
          remLk_one S.sprod (by rw [hsprod]) _ _ (by
            rw [hsprod]
            exact covRU1 U P Pb Lay B Dof cut D hD hX .F 6 (by rw [lenF_u1]; norm_num) 55 16 rfl
              (Fin.append (Lay.fPos p).1 (Lay.fPos p).2))⟩
      fAct := fun p => by
        let bF : Fin 21 → Bool := Fin.append (Lay.fPos p).1 (Lay.fPos p).2
        obtain ⟨l, hl⟩ := exists_actU1 U P Pb Lay B Dof cut bF
        refine ⟨l, ?_⟩
        rw [hl, actTupU1_congr U P (Dof cut) D hD]
        unfold actTupU1
        rw [show splitF c0 bF = Lay.fPos p from splitF_append c0 (Lay.fPos p), B.grpCol_emb p]
        refine Tup.ext' ?_ ?_ ?_ ?_
        · show _ = algebraMap GF K (piB K (aPl U P D (offU1 47) 21 bF) + 2048)
          simp only [map_add, map_ofNat, aPl_alg U P D hX]
        · exact (map_natCast (algebraMap GF K) tagAct).symm
        · show _ = algebraMap GF K (piB K (aPl U P D (offU1 50) 21 bF))
          rw [aPl_alg U P D hX]
        · rfl }

include hD hX in
/-- Direct `W16Query` consequence of `cover_xtU1`: every logical query of `xtU1` is hit by `AlkU1`. -/
theorem cover_xtU1_query {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S) (hlc : P.logCols = 14) :
    ∀ q, W16Query Pb Lay B (xtU1 U P D) q → ∃ l, AlkU1 U P Pb Lay B Dof cut l = tupK q := by
  intro q hq
  have hcov := cover_xtU1 U P Pb Lay B Dof cut D hD hX hS hlc
  by_contra hno
  apply hq
  refine w16LookupsG_mono (fun u hu huq => ?_) hcov
  subst huq
  exact hno hu

end Cover

/-! ## 6. `hcov_u1` and `hcov_shieldU1` -/

/-- **`hcov` at `export_u1`, PROVED**: on every outcome, every logical query of the extracted planes
`xtU1` is an entry of `AlkU1` read off the data the `A` cut fixes (`dofAU1`), at any shape with
`export_u1`'s precision (`PrecR (cfgU1 cnA cnM) S`). -/
theorem hcov_u1 {K : Type} [Field K] [Algebra GF K] {L : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtU1 CwU1 CgU1 CjU1 CdU1 CfU1) (B : W16Pub S Pb Lay)
    {cnA cnM : ℕ} (hS : PrecR (cfgU1 cnA cnM) S) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G q, W16Query Pb Lay B (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, AlkU1 U P Pb Lay B (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
        (cutsOf key domain hs hL A G).1 l = tupK q := by
  intro G q hq
  exact cover_xtU1_query U P Pb Lay B
    (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
    (cutsOf key domain hs hL A G).1
    (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
    (fun off log b => dofAU1_aPl U key domain hs hL tag hL20 P hlc rE QE XE A G off log b)
    (dXof_base_w16U1 tag hL20 P hlc rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) hS hlc q hq

/-- **`hcov` at any layer `Ly ∈ shieldExportU1`**, directly matching `block_knowledge_join_w16r2_shieldU1`'s
premise with `precR_shieldU1` already discharged. -/
theorem hcov_shieldU1 {K : Type} [Field K] [Algebra GF K] {L : ℕ} (Ly : ShieldLayer) (hLy : Ly ∈ shieldExportU1)
    (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (Pb : ZK60.Block.BlockPublic (shieldShape Ly))
    (Lay : W16Layout (shieldShape Ly) CtU1 CwU1 CgU1 CjU1 CdU1 CfU1)
    (B : W16Pub (shieldShape Ly) Pb Lay) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G q, W16Query Pb Lay B (xtU1 U P (dXof tag hL20 P hlc 15 280 8052 2504 2606 rE QE XE
        (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))) q →
      ∃ l, AlkU1 U P Pb Lay B (dofAU1 tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
        (cutsOf key domain hs hL A G).1 l = tupK q :=
  hcov_u1 U key domain hs hL tag hL20 P hlc rE QE XE Pb Lay B (precR_shieldU1 Ly hLy) A

end ZK60.Exec.Block.Join.W16U1.Look
