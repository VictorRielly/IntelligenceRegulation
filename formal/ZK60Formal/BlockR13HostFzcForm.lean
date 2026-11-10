/-
D63 lane L49 (2026-11-10), sub-agent `fzc`, part 2: **`SC_FZC`'s named identity at R13** (lane L36's `FormAt` at
host `18`), with its hosted matmuls `SC_GMM` (slot `11`) and `SC_UMM` (slot `12`, split claim point: `SC_GMM`'s
first `lt` draws, then its own), generic in the configuration (the R13 counterpart of lane L44's `formAt_fzc`).

* `aPl_castB`, `msbIndex_castB`, `mleAt_castB`, `append_splitFR`, `alg_plFR`, `encR18_cast`: casts between `Dom::F`'s
  cube `Fin |Dom::F|` and the product `t ++ f`;
* `cstK_pow`, `cstK_npow`: the IR's shift constants `±2^s` read in the field (`s < 64`);
* **`fzcR_cls`**, **`fzcR_gh0`**, **`fzcR_gh1`**: the gated batch of the three IR clauses and the two gated
  requantization hosts ARE `r13Cl 18 0 … 2`, `r13Gh 18 0`, `r13Gh 18 1` of the extracted planes `xtR` (constants from
  `PrecR`);
* **`fzcR_batch`**: the host's batch over the algebra data's tables IS the IR's zero-check sum (three clauses, the ACT
  relation, LogUp, the pad term);
* **`gmmR_sum`**, **`ummR_sum`**: the hosted matmuls' cube sums are the multilinear extensions of `r13Mm 18 0`,
  `r13Mm 18 1` at their claim points (the folded weights `PubR.wg`, `PubR.wu`);
* **`formAt_fzcR`**: lane L36's `FormAt` at host `18`, for any configuration meeting `FzcCfg`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostFzc

set_option autoImplicit false
set_option linter.unusedSimpArgs false

namespace ZK60.Exec.Block.Join.R13H.Fzc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched segAt)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl aPl_alg piB aFx_eval mm_cube mm_fold cstK cstK_base cstK_p256 toK_zpowW
  lkRels_congr padPls_congr formAt_two)
open ZK60.Exec.Block.Join.W16.Fzc (drR drR_length drR_getD amqS nbS nb2S getD_cons3 getD_app getD_app_right
  mmSlot_eval)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum)
open ZK60.Exec.Slot.Build (Cst cstW gV gV_some L256 batchV LkD logupSem padSem mmIr)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Layout.R13 (lv)
open Finset

/-! ## Casts between `Dom::F`'s cube and its product -/

section Casts

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- An `A` plane read through a cast of its bit vector. -/
theorem aPl_castB (P : BlockParams) (D : CmData K P) {m n : ℕ} (h : m = n) (off : ℕ) (b : Fin m → Bool) :
    aPl U P D off n (castB h b) = aPl U P D off m b := by
  subst h
  rfl

/-- A public table's index through a cast of the bit vector. -/
theorem msbIndex_castB {m n : ℕ} (h : m = n) (b : Fin m → Bool) : msbIndex n (castB h b) = msbIndex m b := by
  subst h
  rfl

omit [Algebra GF K] in
/-- A multilinear extension through a cast of its cube. -/
theorem mleAt_castB {m n : ℕ} (h : m = n) (g : (Fin m → Bool) → K) (p : Fin m → K) :
    mleAt g p = mleAt (fun y : Fin n → Bool => g (castB h.symm y)) (fun t => p (Fin.cast h.symm t)) := by
  subst h
  rfl

variable {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

omit [Field K] [Algebra GF K] in
/-- `Dom::F`'s product split, undone. -/
theorem append_splitFR (b : Fin (nF c) → Bool) : Fin.append (splitF c b).1 (splitF c b).2 = b := by
  funext i
  refine Fin.addCases (fun i1 => ?_) (fun i2 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

include hX in
/-- **A `Dom::F` plane of the extracted data, mapped to the field, IS the committed plane at the cube point.** -/
theorem alg_plFR (q : ℕ) (b : Fin (c.sh.logs .F) → Bool) :
    algebraMap GF K (plF U c P D (offR c q) (splitF c (castB G.logF b))) = aPl U P D (DefR13.aOff c q) (c.sh.logs .F) b := by
  unfold plF
  rw [aPl_alg U P D hX, append_splitFR, aPl_castB U P D G.logF]

omit [Field K] [Algebra GF K] in
/-- `SC_FZC`'s cube encoding of a product bit vector cast to the cube. -/
theorem encR18_cast (y : Fin (nF c) → Bool) : encR G 18 (castB G.logF.symm y) = W16Pos.f (splitF c y) := by
  show W16Pos.f (splitF c (castB ((tau18 c).trans G.logF) (castB ((tau18 c).trans G.logF).symm y))) = _
  rw [castB_castB]

/-- **A segment's entry of a slot's draw vector** (`x i = (dr_i).toK U`), at a known offset. -/
theorem segAt_dr (l : List (ZK60.Exec.Slot.W16R2.Seg × ℕ)) {N N' : ℕ} (hN : N = N') (dr : List Fp2)
    (g : ZK60.Exec.Slot.W16R2.Seg) (i q : ℕ) (hq : segOff l g + i = q) (h : segOff l g + i < N) :
    segAt l (fun j : Fin N => (fun t : Fin N' => (dr.getD t.val Fp2.zero).toK U) (Fin.cast hN j)) g i
      = (dr.getD q Fp2.zero).toK U := by
  subst hq
  unfold segAt
  exact (dite_eq_left h).trans rfl

/-- **The IR's shift constants in the field**: `2^s` for `s < 64`. -/
theorem cstK_pow (s : ℕ) (hs : s < 64) : (cstK U).base (2 ^ s) = (2 : K) ^ s := by
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := by exact_mod_cast Nat.pow_lt_pow_right (by norm_num) hs
  have h0 : (0 : ℤ) < 2 ^ s := by positivity
  rw [cstK_base U _ (by linarith) h2]
  simp only [Int.cast_pow, Int.cast_ofNat, map_pow, map_ofNat]

/-- **The IR's shift constants in the field**: `−2^s` for `s < 64`. -/
theorem cstK_npow (s : ℕ) (hs : s < 64) : (cstK U).base (-(2 ^ s : ℤ)) = -(2 : K) ^ s := by
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := by exact_mod_cast Nat.pow_lt_pow_right (by norm_num) hs
  have h0 : (0 : ℤ) < 2 ^ s := by positivity
  rw [cstK_base U _ (by linarith) (by linarith)]
  simp only [Int.cast_neg, Int.cast_pow, Int.cast_ofNat, map_neg, map_pow, map_ofNat]

end Casts

/-! ## The clauses and the hosted terms are the named relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include hX in
/-- **The gated batch of the three IR clauses IS `Σ_{j<3} μ_j·r13Cl 18 j`** (`f0` with the product fold `S.sprod`,
`f1` the 16-bit word `U`, `f2` the 24-bit product word `H`). -/
theorem fzcR_cls (hS : PrecR c S) (hfold : c.p.fold < 64) (b : Fin (c.sh.logs .F) → Bool) (e0 e1 e2 : K)
    (mu : List K) :
    gV (e0 :: e1 :: e2 :: restFR U G P D B b) (some 28)
        * batchV mu (r13FzcClauses (cstK U) rrFR c.p.fold c.p.prodbits (e0 :: e1 :: e2 :: restFR U G P D B b))
      = mu.getD 0 0 * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 b))
        + mu.getD 1 0 * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 b))
        + mu.getD 2 0 * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 2 (encR G 18 b)) := by
  have hx : encR G 18 b = W16Pos.f (splitF c (castB G.logF b)) := rfl
  have h0 : r13Cl Pb Lay B (xtR U c P D ls) 18 0 (W16Pos.f (splitF c (castB G.logF b)))
      = B.gF (splitF c (castB G.logF b))
        * (plF U c P D (offR c (86 + 2 * ls + 4)) (splitF c (castB G.logF b))
            * plF U c P D (offR c (86 + 2 * ls + 5)) (splitF c (castB G.logF b))
          - 2 ^ c.p.fold * plF U c P D (offR c (86 + 2 * ls + 10)) (splitF c (castB G.logF b))
          - (256 ^ 0 * plF U c P D (offR c (86 + 2 * ls + 14)) (splitF c (castB G.logF b))
            + 256 ^ 1 * plF U c P D (offR c (86 + 2 * ls + 14 + 1)) (splitF c (castB G.logF b)))
          + 2 ^ (c.p.fold - 1)) := by
    simp only [r13Cl, lv, Fin.sum_univ_two, hS.sprod]
    rfl
  have h1 : r13Cl Pb Lay B (xtR U c P D ls) 18 1 (W16Pos.f (splitF c (castB G.logF b)))
      = B.gF (splitF c (castB G.logF b))
        * (plF U c P D (offR c (86 + 2 * ls + 5)) (splitF c (castB G.logF b)) + 32768
          - (256 ^ 0 * plF U c P D (offR c (86 + 2 * ls + 6)) (splitF c (castB G.logF b))
            + 256 ^ 1 * plF U c P D (offR c (86 + 2 * ls + 6 + 1)) (splitF c (castB G.logF b)))) := by
    simp only [r13Cl, lv, Fin.sum_univ_two]
    rfl
  have h2 : r13Cl Pb Lay B (xtR U c P D ls) 18 2 (W16Pos.f (splitF c (castB G.logF b)))
      = B.gF (splitF c (castB G.logF b))
        * (plF U c P D (offR c (86 + 2 * ls + 10)) (splitF c (castB G.logF b)) + 2 ^ 23
          - (256 ^ 0 * plF U c P D (offR c (86 + 2 * ls + 11)) (splitF c (castB G.logF b))
            + 256 ^ 1 * plF U c P D (offR c (86 + 2 * ls + 11 + 1)) (splitF c (castB G.logF b))
            + 256 ^ 2 * plF U c P D (offR c (86 + 2 * ls + 11 + 2)) (splitF c (castB G.logF b)))) := by
    simp only [r13Cl, lv, Fin.sum_univ_three]
    rfl
  rw [hx, h0, h1, h2, hS.pb]
  simp (disch := norm_num) only [gV_some, batchV, r13FzcClauses, rrFR, L256, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restFR,
    add_zero, cstK_npow U _ hfold, cstK_pow U (c.p.fold - 1) (by omega), cstK_base U, cstK_p256 U, map_mul,
    map_add, map_sub, map_pow, map_ofNat, map_one, alg_plFR U G P D hX]
  push_cast
  simp only [map_ofNat]
  ring

include hX in
/-- **The gated first requantization host IS `r13Gh 18 0`** (the gate's shift, three byte limbs). -/
theorem fzcR_gh0 (hS : PrecR c S) (hgate : c.p.gate < 64) (b : Fin (c.sh.logs .F) → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restFR U G P D B b) (some 28)
        * reqBV (cstK U) (e0 :: e1 :: e2 :: restFR U G P D B b) c.p.gate 3 [4, 5, 6]
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 b)) := by
  have hx : encR G 18 b = W16Pos.f (splitF c (castB G.logF b)) := rfl
  have h0 : r13Gh Pb Lay B (xtR U c P D ls) 18 0 (W16Pos.f (splitF c (castB G.logF b)))
      = B.gF (splitF c (castB G.logF b))
        * (2 ^ c.p.gate * plF U c P D (offR c (86 + 2 * ls)) (splitF c (castB G.logF b))
          + (256 ^ 0 * plF U c P D (offR c (86 + 2 * ls + 1)) (splitF c (castB G.logF b))
            + 256 ^ 1 * plF U c P D (offR c (86 + 2 * ls + 1 + 1)) (splitF c (castB G.logF b))
            + 256 ^ 2 * plF U c P D (offR c (86 + 2 * ls + 1 + 2)) (splitF c (castB G.logF b)))
          - 2 ^ (c.p.gate - 1)) := by
    simp only [r13Gh, lv, Fin.sum_univ_three, hS.sgate]
    rfl
  rw [hx, h0]
  simp (disch := norm_num) only [gV_some, reqBV, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons,
    List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restFR, add_zero,
    cstK_pow U _ hgate, cstK_npow U (c.p.gate - 1) (by omega), cstK_p256 U, map_mul, map_add, map_sub, map_pow,
    map_ofNat, alg_plFR U G P D hX]
  push_cast
  ring

include hX in
/-- **The gated second requantization host IS `r13Gh 18 1`** (the up projection's shift, two byte limbs). -/
theorem fzcR_gh1 (hS : PrecR c S) (hup : c.p.up < 64) (b : Fin (c.sh.logs .F) → Bool) (e0 e1 e2 : K) :
    gV (e0 :: e1 :: e2 :: restFR U G P D B b) (some 28)
        * reqBV (cstK U) (e0 :: e1 :: e2 :: restFR U G P D B b) c.p.up 8 [11, 12]
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 b)) := by
  have hx : encR G 18 b = W16Pos.f (splitF c (castB G.logF b)) := rfl
  have h0 : r13Gh Pb Lay B (xtR U c P D ls) 18 1 (W16Pos.f (splitF c (castB G.logF b)))
      = B.gF (splitF c (castB G.logF b))
        * (2 ^ c.p.up * plF U c P D (offR c (86 + 2 * ls + 5)) (splitF c (castB G.logF b))
          + (256 ^ 0 * plF U c P D (offR c (86 + 2 * ls + 8)) (splitF c (castB G.logF b))
            + 256 ^ 1 * plF U c P D (offR c (86 + 2 * ls + 8 + 1)) (splitF c (castB G.logF b)))
          - 2 ^ (c.p.up - 1)) := by
    simp only [r13Gh, lv, Fin.sum_univ_two, hS.sup]
    rfl
  rw [hx, h0]
  simp (disch := norm_num) only [gV_some, reqBV, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons,
    List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ, List.getD_cons_zero, restFR, add_zero,
    cstK_pow U _ hup, cstK_npow U (c.p.up - 1) (by omega), cstK_p256 U, map_mul, map_add, map_sub, map_pow,
    map_ofNat, alg_plFR U G P D hX]
  push_cast
  ring

end Rels

/-! ## The host's batch -/

section Batch

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) {c : W16Cfg} {ls : ℕ}
  (G : GeoR c ls) (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

/-- The LogUp lookups' expressions read only `α` and `γ`. -/
theorem lksSR_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : ZK60.Exec.Slot.W16R2.Dom) (h h' : Hist) (k k' : ℕ)
    (dr dr' : List Fp2) (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h k dr))
      = (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h' k' dr')) := by
  unfold DefR13.lksS
  simp only [List.map_map]
  refine List.map_congr_left (fun l _ => ?_)
  simp only [Function.comp_def, LkD.map, Sym.eval, ha, hg, List.map_map]

/-- Every LogUp term reads a position past the `eq` tables. -/
theorem lksFR_pos (hist : Hist) (dr : List Fp2) :
    ∀ l ∈ lksFR U c ls hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [lksFR, DefR13.lksS, List.mem_map] at hl
  obtain ⟨l1, ⟨l0, ⟨lw, -, rfl⟩, rfl⟩, rfl⟩ := hl
  simp only [LkD.map, List.mem_map] at ht
  obtain ⟨t1, ⟨t0, ⟨tw, -, rfl⟩, rfl⟩, rfl⟩ := ht
  simp [shFR]

omit [Algebra GF K] in
/-- The ACT relation reads only the positions past the `eq` tables. -/
theorem r13FzcAct_congr (v v' : List K) (h : ∀ i, 3 ≤ i → v.getD i 0 = v'.getD i 0) (a n n2 : K) :
    r13FzcAct v rrFR a n n2 = r13FzcAct v' rrFR a n n2 := by
  unfold r13FzcAct
  simp only [rrFR]
  rw [h 26 (by norm_num), h 3 (by norm_num), h 7 (by norm_num), h 27 (by norm_num)]

/-- The batch weights `μ_k` the IR reads. -/
theorem muFR_getD (hist : Hist) (dr : List Fp2) (k : ℕ) (hk : k < 12) :
    (muFR U hist dr).getD k 0 = (dr.getD k Fp2.zero).toK U := by
  unfold muFR
  rw [ZK60.Exec.Block.Join.W16.Fzc.getD_map_toK U, drR_getD _ 18 0 12 k hk, Nat.zero_add]
  rfl

include hU hX in
/-- **The host's batch over the algebra data's tables IS the IR's zero-check sum**: the three named clauses, the ACT
relation, LogUp's seven helper relations and the pad term, at the drawn weights. -/
theorem fzcR_batch (hS : PrecR c S) (hcfg : FzcCfg c ls) (hc : ShOkR c.sh P) {L : ℕ}
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO) (bga : Fp2 × Fp2 × Fp2)
    (hcl : ∀ κ b, dt.cl 18 cu rt bga κ b = if (κ : ℕ) < r13Count 18
      then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 κ) (encR G 18 b))
      else xcFzcR U G P D B bga κ b)
    (hpw : ∀ j b, dt.pw 18 cu rt j b = pwFzcR U G P D B j b)
    (l : List SlotRec) (dr : List Fp2) (b : Fin (c.sh.logs .F) → Bool) (e0 e1 e2 : K)
    (ω : (K × K) × (Fin (segLn ((algShapeR c P hc).dl 18) .mu - segLn ((algShapeR c P hc).dl 18) .zeta) → K))
    (h1 : ω.1.1 = (dr.getD 14 Fp2.zero).toK U) (h2 : ω.1.2 = (dr.getD 11 Fp2.zero).toK U)
    (h3 : ∀ κ, ω.2 κ = (dr.getD κ Fp2.zero).toK U) :
    batched (dt.cl 18 cu rt bga) (dt.pw 18 cu rt) ω b
      = zIRR U c ls (histOf bga.1 bga.2.1 bga.2.2 l) dr (e0 :: e1 :: e2 :: restFR U G P D B b) := by
  have hN : segLn ((algShapeR c P hc).dl 18) .mu - segLn ((algShapeR c P hc).dl 18) .zeta = 11 :=
    (congrArg (fun l => segLn l .mu - segLn l .zeta) hcfg.dl18).trans rfl
  have m_ : ∀ k, k < 12 → (muFR U (histOf bga.1 bga.2.1 bga.2.2 l) dr).getD k 0 = (dr.getD k Fp2.zero).toK U :=
    fun k hk => muFR_getD U _ dr k hk
  have hv : ∀ i, 3 ≤ i → (e0 :: e1 :: e2 :: restFR U G P D B b).getD i 0 = (valsFR U G P D B b).getD i 0 :=
    fun i hi => getD_cons3 _ _ _ _ _ _ _ i hi
  -- the host side, as sums over ranges
  have hA : (∑ k : Fin (segLn ((algShapeR c P hc).dl 18) .mu - segLn ((algShapeR c P hc).dl 18) .zeta),
        ω.2 k * dt.cl 18 cu rt bga k b)
      = ∑ k ∈ Finset.range 11, (dr.getD k Fp2.zero).toK U
        * (if k < r13Count 18 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 k) (encR G 18 b))
          else xcFzcR U G P D B bga k b) := by
    have key : ∀ (N : ℕ), N = 11 → ∀ g : Fin N → K, (∀ k : Fin N, g k = (dr.getD k Fp2.zero).toK U
        * (if (k : ℕ) < r13Count 18
          then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 k) (encR G 18 b))
          else xcFzcR U G P D B bga k b))
        → ∑ k : Fin N, g k = ∑ k ∈ Finset.range 11, (dr.getD k Fp2.zero).toK U
          * (if k < r13Count 18
            then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 k) (encR G 18 b))
            else xcFzcR U G P D B bga k b) := by
      intro N hN g hg
      subst hN
      rw [Finset.sum_congr rfl (fun k _ => hg k)]
      exact Fin.sum_univ_eq_sum_range (fun k => (dr.getD k Fp2.zero).toK U
        * (if k < r13Count 18
          then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 k) (encR G 18 b))
          else xcFzcR U G P D B bga k b)) 11
    exact key _ hN _ (fun k => by rw [h3 k, hcl k b])
  have hB : (∑ j : Fin ((algShapeR c P hc).mpad 18), ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b)
      = ∑ j ∈ Finset.range 16, ((dr.getD 14 Fp2.zero).toK U) ^ j * pwFzcR U G P D B j b := by
    rw [← Fin.sum_univ_eq_sum_range (fun j => ((dr.getD 14 Fp2.zero).toK U) ^ j * pwFzcR U G P D B j b) 16]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [h1, hpw j b]
  -- the IR side
  have hk : lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 l) dr = lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksFR
    rw [lksSR_eval c (shFR ls) .F (histOf bga.1 bga.2.1 bga.2.2 l) (histOf bga.1 bga.2.1 bga.2.2 []) 18 18 dr []
      rfl rfl]
  have hlenL : (lkRels (cstK U) (valsFR U G P D B b) 19 0
      (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 7 := by
    rw [lkRels_length]
    simp only [lksFR, DefR13.lksS, List.length_map, hcfg.nlk]
  have hlog : logupSem (cstK U) (e0 :: e1 :: e2 :: restFR U G P D B b) 19
      (fun k => (muFR U (histOf bga.1 bga.2.1 bga.2.2 l) dr).getD (4 + k) 0) 0
      (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 l) dr)
      = ∑ i ∈ Finset.range 7, (dr.getD (4 + i) Fp2.zero).toK U
        * (lkRels (cstK U) (valsFR U G P D B b) 19 0 (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0 := by
    rw [logupSem_eq_wsum, hk, lkRels_congr (cstK U) _ (valsFR U G P D B b) 19 0 _
      (fun l hl t ht => hv t.2 (lksFR_pos U _ [] l hl t ht)) (fun i _ => hv _ (by omega)), wsum_eq_sum]
    rw [Fin.sum_univ_eq_sum_range (fun i => (muFR U (histOf bga.1 bga.2.1 bga.2.2 l) dr).getD (4 + (0 + i)) 0
      * (lkRels (cstK U) (valsFR U G P D B b) 19 0 (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0),
      hlenL]
    refine Finset.sum_congr rfl (fun i hi => ?_)
    have hi7 := Finset.mem_range.mp hi
    rw [m_ _ (by omega), Nat.zero_add]
  have hact : r13FzcAct (e0 :: e1 :: e2 :: restFR U G P D B b) rrFR
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr amqS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nbS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr nb2S).toK U) = xcFzcR U G P D B bga 3 b := by
    unfold xcFzcR
    rw [ite_eq_left rfl]
    exact r13FzcAct_congr _ _ hv _ _ _
  have hlenP : (padPls (valsFR U G P D B b) grpFR).length = 16 := by simp [padPls, grpFR]
  have hgrp : ∀ g ∈ grpFR, (e0 :: e1 :: e2 :: restFR U G P D B b).getD g.1 0 = (valsFR U G P D B b).getD g.1 0
      ∧ ∀ p ∈ g.2, (e0 :: e1 :: e2 :: restFR U G P D B b).getD p 0 = (valsFR U G P D B b).getD p 0 := by
    intro g hg
    simp only [grpFR, List.mem_singleton] at hg
    subst hg
    refine ⟨hv 28 (by norm_num), fun p hp => hv p ?_⟩
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
    omega
  have hpad : padSem (cstK U) (e0 :: e1 :: e2 :: restFR U G P D B b)
      ((muFR U (histOf bga.1 bga.2.1 bga.2.2 l) dr).getD 11 0)
      (fun j => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (Sym.pow (.dr 18 14) j)).toK U) 0 grpFR
      = (dr.getD 11 Fp2.zero).toK U
        * ∑ j ∈ Finset.range 16, ((dr.getD 14 Fp2.zero).toK U) ^ j * pwFzcR U G P D B j b := by
    rw [padSem_eq_wsum (cstK U) (cstW_map_std U), m_ 11 (by norm_num),
      padPls_congr _ (valsFR U G P D B b) grpFR hgrp, wsum_eq_sum]
    congr 1
    rw [Fin.sum_univ_eq_sum_range (fun i => (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr
        (Sym.pow (.dr 18 14) (0 + i))).toK U * (padPls (valsFR U G P D B b) grpFR).getD i 0), hlenP]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Nat.zero_add]
    show (zpowW (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 l) 18 dr (.dr 18 14)) j).toK U * _ = _
    rw [toK_zpowW U hU]
    rfl
  have hcla : gV (e0 :: e1 :: e2 :: restFR U G P D B b) (some 28)
      * batchV (muFR U (histOf bga.1 bga.2.1 bga.2.2 l) dr)
        (r13FzcClauses (cstK U) rrFR c.p.fold c.p.prodbits (e0 :: e1 :: e2 :: restFR U G P D B b))
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 b))
        + (dr.getD 1 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 b))
        + (dr.getD 2 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 2 (encR G 18 b)) := by
    rw [fzcR_cls U G P D hX B hS hcfg.fold b e0 e1 e2, m_ 0 (by norm_num), m_ 1 (by norm_num),
      m_ 2 (by norm_num)]
  have hexp : ∑ k ∈ Finset.range 11, (dr.getD k Fp2.zero).toK U
        * (if k < r13Count 18 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 k) (encR G 18 b))
          else xcFzcR U G P D B bga k b)
      = (dr.getD 0 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 b))
        + (dr.getD 1 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 b))
        + (dr.getD 2 Fp2.zero).toK U * algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 2 (encR G 18 b))
        + (dr.getD 3 Fp2.zero).toK U * xcFzcR U G P D B bga 3 b
        + ∑ i ∈ Finset.range 7, (dr.getD (4 + i) Fp2.zero).toK U
          * (lkRels (cstK U) (valsFR U G P D B b) 19 0
            (lksFR U c ls (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD i 0 := by
    rw [show (11 : ℕ) = 4 + 7 from rfl, Finset.sum_range_add]
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    rfl
  -- assemble
  unfold batched
  show (∑ k : Fin (segLn ((algShapeR c P hc).dl 18) .mu - segLn ((algShapeR c P hc).dl 18) .zeta),
        ω.2 k * dt.cl 18 cu rt bga k b)
      + ω.1.2 * (∑ j : Fin ((algShapeR c P hc).mpad 18), ω.1.1 ^ (j : ℕ) * dt.pw 18 cu rt j b) = _
  rw [hA, hB, h2, hexp]
  unfold zIRR
  rw [hlog, hact, hpad, hcla, m_ 3 (by norm_num)]
  ring

end Batch

/-! ## The hosted matmuls -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include hX in
/-- The contraction of `SC_FZC`'s pairs on the product cube, read through the plane `YM`. -/
theorem fzcR_mmfun (y : Fin (nF c) → Bool) (W : CwR c → CfR c → GF) :
    (∑ c' : Fin c.sh.ld → Bool, aPl U P D (DefR13.aOff c 29) (c.sh.lt + c.sh.ld)
        (Fin.append (fun i => y (Fin.castAdd c.sh.lf i)) c') * algebraMap GF K (W c' (fun i => y (Fin.natAdd c.sh.lt i))))
      = algebraMap GF K (∑ c', (xtR U c P D ls).YM ((splitF c y).1, c') * W c' (splitF c y).2) := by
  rw [map_sum]
  refine Finset.sum_congr rfl (fun c' _ => ?_)
  rw [map_mul]
  congr 1
  exact (aPl_alg U P D hX _ _ _).symm

include hX in
/-- **`SC_GMM`'s cube sum is the multilinear extension of `r13Mm 18 0` at its claim point.** -/
theorem gmmR_sum (ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B) (hrl : 0 < rowLog P .a)
    (hcfg : FzcCfg c ls) (hs11 : (slotShape P 11).1 = c.sh.ld) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r11 : SlotRec) (hr11 : rs[11]? = some r11) (hc11 : ∀ x ∈ r11.draws, x.Canon) :
    cubeSum (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 11 (seenOf bga rs 11))
      = mleAt (fun y : Fin (c.sh.logs .F) → Bool =>
          algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 y)))
          (fun t : Fin (c.sh.logs .F) => (r11.draws.getD t Fp2.zero).toK U) := by
  obtain ⟨ak, hk, hslot⟩ := progR13_slot c ioIn ioOut 11 (by norm_num)
  have hf : ∀ x, polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 11 (seenOf bga rs 11) x
      = tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.priv ⟨.a, [(DefR13.aOff c 29, Fp2.one)], c.sh.lt + c.sh.ld, ((drR 11 0 c.sh.lt).map
            (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) 11 r11.draws)).map Coord.fixed
            ++ rhoAll c.sh.ld, DefR13.aDataRows c + 2 * ak, 0⟩)
        * tabK U P D (slotShape P 11).1 (slotShape P 11).2.1 x
          (.pub (pubs 11 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 11 r11 hr11 x, hslot, numSlot_ir, numSlot_tabs, hcfg.ir11, hcfg.tabs11]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U))
      (([TabS.priv ⟨.a, [(DefR13.aOff c 29, false)], c.sh.lt + c.sh.ld,
        (drR 11 0 c.sh.lt).map CoordS.fixed ++ DefW16.rhoC 0 c.sh.ld, DefR13.aDataRows c + 2 * ak, 0⟩,
        TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ c.sh.lt c.sh.ld (by rw [List.length_map, drR_length]) hs11
    (by have := G.lt_pos; omega) (DefR13.aOff c 29) _ _ _ hf]
  simp only [hpub.wg (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) r11.draws hc11, ZK60.Exec.Block.Join.W16.eqDr]
  rw [mm_fold, mleAt_castB G.logF]
  have hfun : ∀ y : Fin (c.sh.lt + c.sh.lf) → Bool, (∑ c' : Fin c.sh.ld → Bool, aPl U P D (DefR13.aOff c 29)
      (c.sh.lt + c.sh.ld) (Fin.append (fun i => y (Fin.castAdd c.sh.lf i)) c')
        * algebraMap GF K (B.Wg c' (fun i => y (Fin.natAdd c.sh.lt i))))
      = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 0 (encR G 18 (castB G.logF.symm y))) := fun y => by
    rw [encR18_cast G y]
    exact fzcR_mmfun U P D hX y B.Wg
  have hpt : ∀ t : Fin (c.sh.lt + c.sh.lf), Fin.append (fun i : Fin c.sh.lt => (((drR 11 0 c.sh.lt).map
      (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 11)) 11 r11.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin c.sh.lf => (r11.draws.getD (c.sh.lt + a) Fp2.zero).toK U) t
      = (r11.draws.getD (t : ℕ) Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 c.sh.lt i i.isLt, Nat.zero_add]
      rfl
    · rw [Fin.append_right]
      rfl
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

include hX in
/-- **`SC_UMM`'s cube sum is the multilinear extension of `r13Mm 18 1` at its split claim point** (`SC_GMM`'s token
coordinates, then its own draws). -/
theorem ummR_sum (ioIn ioOut : ℕ) (pubs : PubTabs) (hpub : PubR U c pubs Pb Lay B) (hrl : 0 < rowLog P .a)
    (hcfg : FzcCfg c ls) (hs12 : (slotShape P 12).1 = c.sh.ld) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (r11 r12 : SlotRec) (hr11 : rs[11]? = some r11) (hr12 : rs[12]? = some r12) (hc12 : ∀ x ∈ r12.draws, x.Canon) :
    cubeSum (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 12 (seenOf bga rs 12))
      = mleAt (fun y : Fin (c.sh.logs .F) → Bool =>
          algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 y)))
          (fun t : Fin (c.sh.logs .F) => if (t : ℕ) < c.sh.lt then (r11.draws.getD t Fp2.zero).toK U
            else (r12.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U) := by
  obtain ⟨ak, hk, hslot⟩ := progR13_slot c ioIn ioOut 12 (by norm_num)
  have hf : ∀ x, polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 12 (seenOf bga rs 12) x
      = tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.priv ⟨.a, [(DefR13.aOff c 29, Fp2.one)], c.sh.lt + c.sh.ld, ((drR 11 0 c.sh.lt).map
            (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) 12 r12.draws)).map Coord.fixed
            ++ rhoAll c.sh.ld, DefR13.aDataRows c + 2 * ak, 0⟩)
        * tabK U P D (slotShape P 12).1 (slotShape P 12).2.1 x
          (.pub (pubs 12 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws 0)) := by
    intro x
    rw [polyS_seenOf U P D _ pubs bga rs 12 r12 hr12 x, hslot, numSlot_ir, numSlot_tabs, hcfg.ir12, hcfg.tabs12]
    show irEval (((mmIr DefW16.cstS 0 1).map _).map (Fp2.toK U))
      (([TabS.priv ⟨.a, [(DefR13.aOff c 29, false)], c.sh.lt + c.sh.ld,
        (drR 11 0 c.sh.lt).map CoordS.fixed ++ DefW16.rhoC 0 c.sh.ld, DefR13.aDataRows c + 2 * ak, 0⟩,
        TabS.pub 0].map (TabS.eval _ _)).map _) = _
    rw [mmSlot_eval, aFx_eval]
  rw [mm_cube U P D hrl _ _ _ c.sh.lt c.sh.ld (by rw [List.length_map, drR_length]) hs12
    (by have := G.lt_pos; omega) (DefR13.aOff c 29) _ _ _ hf]
  simp only [hpub.wu (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) r12.draws hc12, ZK60.Exec.Block.Join.W16.eqDr]
  rw [mm_fold, mleAt_castB G.logF]
  have hfun : ∀ y : Fin (c.sh.lt + c.sh.lf) → Bool, (∑ c' : Fin c.sh.ld → Bool, aPl U P D (DefR13.aOff c 29)
      (c.sh.lt + c.sh.ld) (Fin.append (fun i => y (Fin.castAdd c.sh.lf i)) c')
        * algebraMap GF K (B.Wu c' (fun i => y (Fin.natAdd c.sh.lt i))))
      = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 1 (encR G 18 (castB G.logF.symm y))) := fun y => by
    rw [encR18_cast G y]
    exact fzcR_mmfun U P D hX y B.Wu
  have hpt : ∀ t : Fin (c.sh.lt + c.sh.lf), Fin.append (fun i : Fin c.sh.lt => (((drR 11 0 c.sh.lt).map
      (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 12)) 12 r12.draws)).getD i Fp2.zero).toK U)
      (fun a : Fin c.sh.lf => (r12.draws.getD (0 + a) Fp2.zero).toK U) t
      = if (t : ℕ) < c.sh.lt then (r11.draws.getD (t : ℕ) Fp2.zero).toK U
        else (r12.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U := by
    intro t
    refine Fin.addCases (fun i => ?_) (fun a => ?_) t
    · rw [Fin.append_left, drR_getD _ 11 0 c.sh.lt i i.isLt, Nat.zero_add,
        ite_eq_left (show ((Fin.castAdd c.sh.lf i : Fin (c.sh.lt + c.sh.lf)) : ℕ) < c.sh.lt from i.isLt)]
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 12 11 i r11 (by norm_num) hr11
    · rw [Fin.append_right, ite_eq_right (show ¬ (((Fin.natAdd c.sh.lt a : Fin (c.sh.lt + c.sh.lf)) : ℕ) < c.sh.lt)
        by simp)]
      simp
  exact congr (congrArg mleAt (funext hfun)) (funext hpt)

end Mm

/-! ## `SC_FZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **Lane L36's `FormAt` at host `18` (`SC_FZC`) at R13, for any configuration meeting `FzcCfg`**: on every outcome
whose verified slots are hosts exactly when their definitions host slots, `SC_FZC`'s certified polynomial at the drawn
challenges IS its unmasked residual `Σ Poly₁₈ − (ν₀·Σ Poly₁₁ + ν₁·Σ Poly₁₂)`, for every algebra data whose host-`18`
tables are `R13Rels`' relation tables of the extracted planes `xtR` (in the IR's batch order `clIx`), the batch's
other entries `xcFzcR` and the pad planes `pwFzcR`. -/
theorem formAt_fzcR (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls)
    (Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)) (B : W16Pub S Pb Lay)
    (P : BlockParams) (hc : ShOkR c.sh P) (hpf : ProfR c.sh P) (hcfg : FzcCfg c ls)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefR13.progR13 c ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : PrecR c S) (_hW : ZK60.Layout.R13.R13Windows S ls) (_hLay : LayR Lay) (hpub : PubR U c pubs Pb Lay B)
    (dt : AlgData K L (algShapeR c P hc)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga κ b, dt.cl 18 cu rt bga κ b = if (κ : ℕ) < r13Count 18
        then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 18 (clIx 18 κ) (encR G 18 b))
        else xcFzcR U G P D B bga κ b)
    (hpw : ∀ j b, dt.pw 18 cu rt j b = pwFzcR U G P D B j b)
    (hgh : ∀ i b, dt.gh 18 cu rt i b = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 18 i (encR G 18 b)))
    (hmm : ∀ i b, dt.mm 18 cu rt i b = algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 i (encR G 18 b)))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeR c P hc) dt hcard 0 cu rt k h).Φ) bga rs 18 := by
  -- the slot shapes and the draw list of slot `18`
  have hFw : c.sh.logs .F = c.sh.lt + c.sh.lf := G.logF
  have hs18 : (slotShape P 18).1 = c.sh.logs .F := congrArg Prod.fst (hpf.slots 18 (by norm_num))
  have hs11 : (slotShape P 11).1 = c.sh.ld := congrArg Prod.fst (hpf.slots 11 (by norm_num))
  have hs12 : (slotShape P 12).1 = c.sh.ld := congrArg Prod.fst (hpf.slots 12 (by norm_num))
  have hz1 : segLn ((algShapeR c P hc).dl 18) .zeta = 1 :=
    (congrArg (fun l => segLn l .zeta) hcfg.dl18).trans rfl
  have hlM : segLn ((algShapeR c P hc).dl 18) .mu = 12 :=
    (congrArg (fun l => segLn l .mu) hcfg.dl18).trans rfl
  have hoM : segOff ((algShapeR c P hc).dl 18) .mu = 0 :=
    (congrArg (fun l => segOff l .mu) hcfg.dl18).trans rfl
  have hoN : segOff ((algShapeR c P hc).dl 18) .nu = 12 :=
    (congrArg (fun l => segOff l .nu) hcfg.dl18).trans rfl
  have hoZ : segOff ((algShapeR c P hc).dl 18) .zeta = 14 :=
    (congrArg (fun l => segOff l .zeta) hcfg.dl18).trans rfl
  have hoT : segOff ((algShapeR c P hc).dl 18) .tau = 15 :=
    (congrArg (fun l => segOff l .tau) hcfg.dl18).trans rfl
  have hsS : segSum ((algShapeR c P hc).dl 18) = 15 + c.sh.logs .F := by
    refine (congrArg segSum hcfg.dl18).trans ?_
    simp only [segSum, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil]
    omega
  obtain ⟨ak, hk, hslot⟩ := progR13_slot c ioIn ioOut 18 (by norm_num)
  obtain ⟨_, _, hslot11⟩ := progR13_slot c ioIn ioOut 11 (by norm_num)
  obtain ⟨_, _, hslot12⟩ := progR13_slot c ioIn ioOut 12 (by norm_num)
  refine formAt_two U hcard P (DefR13.progR13 c ioIn ioOut) pubs hdef D (algShapeR c P hc) dt cu rt bga rs 18
    (by decide) 11 12 (.dr 18 12) (.dr 18 13)
    (by rw [hslot, numSlot_hosted, hcfg.host18]) (by rw [hslot11, numSlot_hosted, hcfg.host11])
    (by rw [hslot12, numSlot_hosted, hcfg.host12]) (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 18 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r11, hr11⟩ : ∃ r11, rs[11]? = some r11 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r12, hr12⟩ : ∃ r12, rs[12]? = some r12 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcanon : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    have hdf' : defineS (DefR13.progR13 c ioIn ioOut) pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws
        = .ok df := hdef ▸ hdf
    exact (defineS_ok hdf').1.2.2.2
  -- the public tables of slot `18` on `Dom::F`'s cube
  have hg0 : ∀ b : Fin (c.sh.logs .F) → Bool,
      ((pubs 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws 0).getD (msbIndex (c.sh.logs .F) b)
        Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF c (castB G.logF b))) := fun b => by
    rw [← msbIndex_castB G.logF b]
    exact hpub.fzcGrp _ _ _
  have hg1 : ∀ b : Fin (c.sh.logs .F) → Bool,
      ((pubs 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws 1).getD (msbIndex (c.sh.logs .F) b)
        Fp2.zero).toK U = algebraMap GF K (B.gF (splitF c (castB G.logF b))) := fun b => by
    rw [← msbIndex_castB G.logF b]
    exact hpub.fzcGate _ _ _
  -- the three slots' cube sums
  have hsp18 := fzcR_cube U G P D B hrl hcfg.nlk (slotShape P 18).1 (slotShape P 18).2.1 hs18
    (DefR13.aDataRows c) (DefR13.hDataRows c) ioIn ioOut ak hk (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws
    (pubs 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) r.draws) hg0 hg1
    (polyS U P D (DefR13.progR13 c ioIn ioOut) pubs 18 (seenOf bga rs 18))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 18 r hr x, hslot, numSlot_ir, numSlot_tabs, hcfg.ir18,
      hcfg.tabs18])
  have hsp11 := gmmR_sum U G P D hX B ioIn ioOut pubs hpub hrl hcfg hs11 bga rs r11 hr11 (hcanon 11 r11 hr11)
  have hsp12 := ummR_sum U G P D hX B ioIn ioOut pubs hpub hrl hcfg hs12 bga rs r11 r12 hr11 hr12
    (hcanon 12 r12 hr12)
  have hM : ∀ i : Fin 2, algM (algShapeR c P hc) dt 18 cu rt i
      = fun y => algebraMap GF K (r13Mm Pb Lay B (xtR U c P D ls) 18 i (encR G 18 y)) := fun i => by
    rw [algM_mm (algShapeR c P hc) dt 18 cu rt i (fun h => absurd h.1 (by decide))]
    exact funext (hmm i)
  have hp0 : algPt U (algShapeR c P hc) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0
      = fun t => (r11.draws.getD t.val Fp2.zero).toK U := by
    funext t
    show algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t = _
    exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11
  have hp1 : algPt U (algShapeR c P hc) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1
      = fun t : Fin (segLn ((algShapeR c P hc).dl 18) .tau) => if (t : ℕ) < c.sh.lt
        then (r11.draws.getD t Fp2.zero).toK U else (r12.draws.getD ((t : ℕ) - c.sh.lt) Fp2.zero).toK U := by
    funext t
    show (if (t : ℕ) < c.sh.lt then algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 11 t
      else algDrawAt U (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 12 ((t : ℕ) - c.sh.lt)) = _
    rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 t r11 (by norm_num) hr11,
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12]
  rw [hostSp_Φ]
  unfold hostPhi
  unfold spSum
  rw [hsp18, hsp11, hsp12]
  refine congrArg₂ (fun x y : K => x - y) ?_ ?_
  · -- the host's sum
    refine Finset.sum_congr rfl (fun b _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ b (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · have ha : (a : ℕ) < c.sh.logs .F := a.isLt
      refine (segAt_dr U _ _ r.draws .tau (a : ℕ) (15 + (a : ℕ)) (by omega) (by omega)).trans ?_
      unfold tauFR
      rw [drR_getD _ 18 15 _ a ha]
      rfl
    · refine fzcR_batch U hU G P D hX B hS hcfg hc dt cu rt _ (fun κ b => hcl _ κ b) hpw (rs.take 18) r.draws b
        _ _ _ _ ?_ ?_ (fun κ => ?_)
      · dsimp only
        rw [ite_eq_left hz1]
        exact segAt_dr U _ _ r.draws .zeta 0 14 (by omega) (by omega)
      · dsimp only
        rw [ite_eq_left hz1]
        exact segAt_dr U _ _ r.draws .mu _ 11 (by omega) (by omega)
      · have hκ : (κ : ℕ) < 11 := by
          have := κ.isLt
          omega
        exact segAt_dr U _ _ r.draws .mu (κ : ℕ) (κ : ℕ) (by omega) (by omega)
    · fin_cases i
      · exact (segAt_dr U _ _ r.draws .nu 0 12 (by omega) (by omega)).trans rfl
      · exact (segAt_dr U _ _ r.draws .nu 1 13 (by omega) (by omega)).trans rfl
    · have hj : (j : ℕ) < c.sh.logs .F := j.isLt
      fin_cases i
      · show algPt U (algShapeR c P hc) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 0 j
          = p0FR U c (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws) j
        rw [hp0]
        show (r11.draws.getD j Fp2.zero).toK U = p0FR U c _ j
        unfold p0FR
        rw [List.map_append]
        have hl5 : ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)).length
            = c.sh.lt := by rw [List.length_map, drR_length]
        by_cases h5 : (j : ℕ) < c.sh.lt
        · rw [getD_app ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws))
            ((drR 11 c.sh.lt c.sh.lf).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws))
            Fp2.zero j (by rw [hl5]; exact h5), drR_getD _ 11 0 c.sh.lt j h5, Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
        · rw [getD_app_right ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18
            r.draws)) ((drR 11 c.sh.lt c.sh.lf).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws))
            Fp2.zero j (by rw [hl5]; omega), hl5, drR_getD _ 11 c.sh.lt c.sh.lf ((j : ℕ) - c.sh.lt) (by omega),
            Nat.add_sub_of_le (by omega)]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
      · show algPt U (algShapeR c P hc) 18 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 1 j
          = p1FR U c (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws) j
        rw [hp1]
        show (if (j : ℕ) < c.sh.lt then (r11.draws.getD j Fp2.zero).toK U
          else (r12.draws.getD ((j : ℕ) - c.sh.lt) Fp2.zero).toK U) = p1FR U c _ j
        unfold p1FR
        rw [List.map_append]
        have hl5 : ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws)).length
            = c.sh.lt := by rw [List.length_map, drR_length]
        by_cases h5 : (j : ℕ) < c.sh.lt
        · rw [ite_eq_left h5, getD_app ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18))
            18 r.draws)) ((drR 12 0 c.sh.lf).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18)) 18 r.draws))
            Fp2.zero j (by rw [hl5]; exact h5), drR_getD _ 11 0 c.sh.lt j h5, Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 11 j r11 (by norm_num) hr11).symm
        · rw [ite_eq_right h5, getD_app_right ((drR 11 0 c.sh.lt).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2
            (rs.take 18)) 18 r.draws)) ((drR 12 0 c.sh.lf).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 18))
            18 r.draws)) Fp2.zero j (by rw [hl5]; omega), hl5, drR_getD _ 12 0 c.sh.lf ((j : ℕ) - c.sh.lt)
            (by omega), Nat.zero_add]
          exact (algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 18 12 _ r12 (by norm_num) hr12).symm
    · rw [algH_gh U _ dt 18 cu rt _ i (fun h => absurd h.1 (by decide)), hgh i b]
      fin_cases i
      · exact (fzcR_gh0 U G P D hX B hS hcfg.gate b _ _ _).symm
      · exact (fzcR_gh1 U G P D hX B hS hcfg.up b _ _ _).symm
  · -- the hosted sums
    rw [Fin.sum_univ_two, hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (fun x y : K => x + y) (congrArg₂ (fun x y : K => x * y) ?_ ?_)
      (congrArg₂ (fun x y : K => x * y) ?_ ?_)
    · exact (segAt_dr U _ _ r.draws .nu 0 12 (by omega) (by omega)).trans rfl
    · rfl
    · exact (segAt_dr U _ _ r.draws .nu 1 13 (by omega) (by omega)).trans rfl
    · rfl

end Form

end ZK60.Exec.Block.Join.R13H.Fzc
