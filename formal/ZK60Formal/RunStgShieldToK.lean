/-
D63 lane L65 (2026-11-17), part 1: **stage table/claim `toK` semantics, individual degree `≤ 1` of `claimSem` on private
stage tables, and generic `OffZero` engines for standalone and host stage slots** (including the L63-5 per-slot IO-width
twin `stgΦBC` / `sshΦIC`).

* `sshDegI`, `sshDgI`, `sshDegO`, `sshDgO`, **`ssh_inc_dg_count`**, **`ssh_outc_dg_count`**: the concrete stage define
  degrees (`e = d + 1`: `2` on IN-C slots `0..2`, `1` on `3`; `[2, 1, 2, 1, 2, 12, 2, 1]` on OUT-C slots `0..7`) and
  their R13 budget bounds (`e ≤ 80`, `n·e ≤ 80·451`);
* `tHistS_spec`, **`stgDefSqV_rbrZ_canon`**, `ssh_rbrIC_canon`, `ssh_rbrO_canon`: canonical challenge/length invariants
  from `tHistS` at every non-vacuous `stgDefSqV` trace prefix;
* `stgTabK`, `tabVals_stgTabK`, `claimSem_priv_words`, **`indDegLE_claimSem_priv`**, `stgTabK_indDeg`: exact `toK`
  bridge for `Tab.eq`, `Tab.pub`, and `Tab.priv` (narrow and wide planes, `lc ≤ p.log` and `p.log < lc`) and proof that
  every stage table evaluation has individual degree `≤ 1` in the sumcheck variables `x`;
* **`offZero_standalone_draw`**, **`offZero_standalone_drawC`**, **`offZero_host_draw`**: generic `OffZero` + `IndDegLE`
  engines for standalone and host stage define draws.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldRbr
import ZK60Formal.RunStgShieldDefC

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)

/-! ## 1. Concrete stage define degrees (`d` and `dg = d + 1`) -/

def sshDegI : ℕ → ℕ
  | 0 | 1 | 2 => 1
  | _ => 0

def sshDgI (k : ℕ) : ℕ := sshDegI k + 1

def sshDegO : ℕ → ℕ
  | 0 | 2 | 4 | 6 => 1
  | 5 => 11
  | _ => 0

def sshDgO (k : ℕ) : ℕ := sshDegO k + 1

-- Specialises `RunStgShieldRbr.ssh_inc_count` / `ssh_outc_count` at the per-slot degree lists `sshDgI` / `sshDgO`.
theorem ssh_inc_dg_count (I : IncPub) (h0 : clog2 I.inEpWords ≤ 64) (h1 : I.tiLog ≤ 64) (h2 : I.vocLog ≤ 64) :
    ∀ k, sshDgI k ≤ 80 ∧ incDraws I k * sshDgI k ≤ 80 * 451 := by
  intro k
  rcases k with _ | _ | _ | k <;> simp only [sshDgI, sshDegI, incDraws] <;> omega

theorem ssh_outc_dg_count (O : OutcPub) (h0 : O.dBits ≤ 64) (h1 : O.llo ≤ 64) (h2 : O.ldo ≤ 64) (h3 : O.ltab ≤ 64) :
    ∀ k, sshDgO k ≤ 80 ∧ outcDraws O k * sshDgO k ≤ 80 * 451 := by
  intro k
  have hle : sshDegO k ≤ 11 := by
    rcases k with _ | _ | _ | _ | _ | _ | _ | k <;> simp [sshDegO]
  exact ssh_outc_count O h0 h1 h2 h3 (sshDegO k) hle k

/-! ## 2. Trace history invariants (`tHistS`) and canonical `Rbr` -/

theorem challengeFp2Of_canon (d : Dig) : (challengeFp2Of d).Canon :=
  ⟨Fp.new_canon _, Fp.new_canon _⟩

theorem tChal_canon {τ rest : List (TItem × Dig)} {a : Fp2}
    (h : Block.tChal τ = some (a, rest)) : a.Canon := by
  unfold Block.tChal at h
  split at h
  · simp only [Option.some.injEq, Prod.mk.injEq] at h
    rw [← h.1]; exact challengeFp2Of_canon _
  · cases h

theorem tChals_canon : ∀ (m : ℕ) {τ rest : List (TItem × Dig)} {ch : List Fp2},
    Block.tChals m τ = some (ch, rest) → (∀ a ∈ ch, a.Canon) ∧ ch.length = m
  | 0, _, _, _, h => by
    simp only [Block.tChals, Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
    rcases h with ⟨rfl, rfl⟩
    exact ⟨fun _ hm => absurd hm List.not_mem_nil, rfl⟩
  | m + 1, τ, rest, ch, h => by
    unfold Block.tChals at h
    simp only [Block.TRd.bnd] at h
    split at h
    · rename_i a rest1 ha
      split at h
      · rename_i as rest2 has
        simp only [Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
        rcases h with ⟨rfl, rfl⟩
        obtain ⟨hcan, hlen⟩ := tChals_canon m has
        refine ⟨fun x hx => ?_, by simp [hlen]⟩
        rcases List.mem_cons.mp hx with rfl | hx
        · exact tChal_canon ha
        · exact hcan x hx
      · cases h
    · cases h

theorem tSlots_length (P : Block.BlockParams) :
    ∀ (k j : ℕ) {τ rest : List (TItem × Dig)} {vs : List (List Fp2 × Fp2 × List UInt8)},
    Block.tSlots P j k τ = some (vs, rest) → vs.length = k
  | 0, _, _, _, _, h => by
    simp only [Block.tSlots, Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
    rw [← h.1]; rfl
  | k + 1, j, τ, rest, vs, h => by
    unfold Block.tSlots at h
    simp only [Block.TRd.bnd] at h
    split at h
    · rename_i v rest1 _
      split at h
      · rename_i _ rest2 _
        split at h
        · rename_i vs' rest3 hvs
          simp only [Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
          rcases h with ⟨rfl, rfl⟩
          simp [tSlots_length P k (j + 1) hvs]
        · cases h
      · cases h
    · cases h

theorem tRootS_canon {hdrLen m : ℕ} {τ rest : List (TItem × Dig)} {ch : List Fp2}
    (h : StageFS.tRootS hdrLen m τ = some (ch, rest)) :
    (∀ a ∈ ch, a.Canon) ∧ ch.length = m := by
  unfold StageFS.tRootS at h
  simp only [Block.TRd.bnd] at h
  split at h
  · split at h
    · rename_i ch' rest1 hch
      split at h
      · simp only [Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
        rcases h with ⟨rfl, rfl⟩
        exact tChals_canon m hch
      · cases h
    · cases h
  · cases h

theorem tHistS_spec {P : Block.BlockParams} {hdrLen m k : ℕ} {τ rest : List (TItem × Dig)}
    {hh : List Fp2 × List (List Fp2)}
    (h : tHistS P hdrLen m k τ = some (hh, rest)) :
    (∀ a ∈ hh.1, a.Canon) ∧ hh.1.length = m ∧ hh.2.length = k := by
  unfold tHistS at h
  simp only [Block.TRd.bnd] at h
  split at h
  · rename_i ch rest1 hroot
    split at h
    · rename_i vs rest2 hslots
      simp only [Block.TRd.ret, Option.some.injEq, Prod.mk.injEq] at h
      rcases h with ⟨⟨rfl, rfl⟩, rfl⟩
      obtain ⟨hcan, hlen1⟩ := tRootS_canon hroot
      exact ⟨hcan, hlen1, by simp [tSlots_length P k 0 hslots]⟩
    · cases h
  · cases h

section RbrCanon

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}

omit [Algebra GF K] in
theorem stgDefSqV_rbrZ_canon (P0 : Block.BlockParams) (m hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (k d : ℕ) (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, (∀ a ∈ hh.1, a.Canon) → hh.1.length = m → hh.2.length = k →
      ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp ∧ OffZero Z (Φ v k hh) Pp) :
    (stgDefSqV P0 m hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ mg hτ hns
  simp only [stgDefSqV] at hns ⊢
  split at hns
  · rename_i hh rest hhist
    obtain ⟨hcan, hm, hk⟩ := tHistS_spec hhist
    obtain ⟨Pp, hP, ho⟩ := hoff _ hh hcan hm hk
    rw [hdg]
    exact szSt_escape_offZero Z _ Pp hP ho τ mg hτ hns
  · exact absurd trivial hns

variable (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (h64 : 64 ≤ L)

theorem ssh_rbrI_canon (P0 : Block.BlockParams) (Vi : StageV.IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8)) (dg : ℕ → ℕ) (k d : ℕ)
    (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, (∀ a ∈ hh.1, a.Canon) → hh.1.length = m → hh.2.length = k →
      ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp
        ∧ OffZero Z (sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO v k hh) Pp) :
    (stgDefSqV P0 m hdrLen absOf (sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) dg k).Rbr :=
  stgDefSqV_rbrZ_canon P0 m hdrLen absOf _ dg k d Z hdg hoff

theorem ssh_rbrIC_canon (P0 : Block.BlockParams) (Vi : StageV.IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8)) (dg : ℕ → ℕ) (k d : ℕ)
    (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, (∀ a ∈ hh.1, a.Canon) → hh.1.length = m → hh.2.length = k →
      ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp
        ∧ OffZero Z (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO v k hh) Pp) :
    (stgDefSqV P0 m hdrLen absOf (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) dg k).Rbr :=
  stgDefSqV_rbrZ_canon P0 m hdrLen absOf _ dg k d Z hdg hoff

theorem ssh_rbrO_canon (P0 : Block.BlockParams) (F : ℕ → StageV.OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8)) (dg : ℕ → ℕ) (k d : ℕ)
    (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, (∀ a ∈ hh.1, a.Canon) → hh.1.length = 2 → hh.2.length = k →
      ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp
        ∧ OffZero Z (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO v k hh) Pp) :
    (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) dg k).Rbr :=
  stgDefSqV_rbrZ_canon P0 2 hdrLen absOf _ dg k d Z hdg hoff

end RbrCanon

/-! ## 3. Multivariate degree combinators -/

section PolyHelpers

variable {K : Type} [Field K]

-- Right-scalar wrapper around `StageInExtractSlots.IndDegLE.cmul`.
theorem IndDegLE_mulc {n d : ℕ} {f : (Fin n → K) → K} (hf : IndDegLE d f) (c : K) :
    IndDegLE d (fun x => f x * c) := by
  simpa [mul_comm] using IndDegLE.cmul c hf

theorem indDegLE_finset_sum {ι : Type} {M d : ℕ} (s : Finset ι) (f : ι → (Fin M → K) → K)
    (hf : ∀ b ∈ s, IndDegLE d (f b)) :
    IndDegLE d (fun y => ∑ b ∈ s, f b y) := by
  classical
  induction s using Finset.induction_on with
  | empty =>
    simpa using IndDegLE.const (n := M) (d := d) (0 : K)
  | @insert a s ha ih =>
    have h1 : IndDegLE d (f a) := hf a (Finset.mem_insert_self a s)
    have h2 : IndDegLE d (fun y => ∑ b ∈ s, f b y) :=
      ih (fun b hb => hf b (Finset.mem_insert_of_mem hb))
    have hsum : (fun y => ∑ b ∈ insert a s, f b y) = (fun y => f a y + ∑ b ∈ s, f b y) := by
      funext y; exact Finset.sum_insert ha
    rw [hsum]
    exact IndDegLE.add h1 h2

theorem indDegLE_cubeSum {M N d : ℕ} (F : (Fin M → K) → (Fin N → K) → K)
    (hF : ∀ x : Fin N → K, IndDegLE d (fun y => F y x)) :
    IndDegLE d (fun y => cubeSum (F y)) := by
  unfold cubeSum
  exact indDegLE_finset_sum Finset.univ (fun (b : Fin N → Bool) y => F y (fun i => bit (b i)))
    (fun b _ => hF _)

theorem indDegLE_mul_disjoint {M d : ℕ} (f g : (Fin M → K) → K)
    (hf : IndDegLE d f) (hg : IndDegLE d g)
    (hdisj : ∀ i : Fin M, Block.ConstAt i f ∨ Block.ConstAt i g) :
    IndDegLE d (fun y => f y * g y) := by
  intro i y
  rcases hdisj i with hcf | hcg
  · obtain ⟨q, hqd, hq⟩ := hg i y
    refine ⟨Polynomial.C (f y) * q, ?_, fun t => ?_⟩
    · exact (Polynomial.natDegree_C_mul_le (f y) q).trans hqd
    · simp only [Polynomial.eval_mul, Polynomial.eval_C]
      rw [hcf y t, hq t]
  · obtain ⟨p, hpd, hp⟩ := hf i y
    refine ⟨p * Polynomial.C (g y), ?_, fun t => ?_⟩
    · exact (Polynomial.natDegree_mul_C_le p (g y)).trans hpd
    · simp only [Polynomial.eval_mul, Polynomial.eval_C]
      rw [hp t, hcg y t]

theorem indDegLE_coord {M : ℕ} (j : Fin M) : IndDegLE 1 (fun y : Fin M → K => y j) :=
  Block.indDegLE_one_of_affAt (fun i => Block.affAt_coord i j)

omit [Field K] in
theorem constAt_coord_ne {M : ℕ} (i j : Fin M) (h : i ≠ j) :
    Block.ConstAt i (fun y : Fin M → K => y j) :=
  Block.constAt_coord i j h.symm

theorem indDegLE_pow_coord {M : ℕ} (j : Fin M) (m d : ℕ) (hm : m ≤ d) :
    IndDegLE d (fun y : Fin M → K => (y j) ^ m) := by
  intro i y
  by_cases hij : i = j
  · subst hij
    refine ⟨Polynomial.X ^ m, ?_, fun t => ?_⟩
    · rw [Polynomial.natDegree_X_pow]; exact hm
    · simp [Function.update_self]
  · refine ⟨Polynomial.C ((y j) ^ m), ?_, fun t => ?_⟩
    · exact (Polynomial.natDegree_C _).trans_le (Nat.zero_le d)
    · simp [Function.update_of_ne (Ne.symm hij)]

theorem indDegLE_zfold {M : ℕ} (j : Fin M) (c : ℕ → K) :
    IndDegLE 11 (fun y : Fin M → K => ∑ r ∈ Finset.range 12, c r * (y j) ^ r) := by
  refine indDegLE_finset_sum (Finset.range 12) (fun r y => c r * (y j) ^ r) (fun r hr => ?_)
  have hr11 : r ≤ 11 := by rw [Finset.mem_range] at hr; omega
  exact IndDegLE.cmul (c r) (indDegLE_pow_coord j r 11 hr11)

theorem constAt_zfold_ne {M : ℕ} (i j : Fin M) (h : i ≠ j) (c : ℕ → K) :
    Block.ConstAt i (fun y : Fin M → K => ∑ r ∈ Finset.range 12, c r * (y j) ^ r) := by
  intro y t
  simp [Function.update_of_ne (Ne.symm h)]

def eqDrawK {M N : ℕ} (m n e : ℕ) (hm : m ≤ M) (y : Fin M → K) (x : Fin N → K) : K :=
  Block.selK n e x * ∏ a : Fin m,
    (y ⟨a.val, Nat.lt_of_lt_of_le a.isLt hm⟩ * Block.xrK n x a.val
      + (1 - y ⟨a.val, Nat.lt_of_lt_of_le a.isLt hm⟩) * (1 - Block.xrK n x a.val))

theorem indDegLE_eqDrawK {M N : ℕ} (m n e : ℕ) (hm : m ≤ M) (x : Fin N → K) :
    IndDegLE 1 (fun y : Fin M → K => eqDrawK m n e hm y x) := by
  refine Block.indDegLE_one_of_affAt (fun i => ?_)
  unfold eqDrawK
  refine Block.AffAt.const_mul (Block.constAt_const i (Block.selK n e x)) ?_
  by_cases hi : i.val < m
  · refine Block.AffAt.prod_one
      (fun (a : Fin m) (y : Fin M → K) =>
        y ⟨a.val, Nat.lt_of_lt_of_le a.isLt hm⟩ * Block.xrK n x a.val
          + (1 - y ⟨a.val, Nat.lt_of_lt_of_le a.isLt hm⟩) * (1 - Block.xrK n x a.val))
      ⟨i.val, hi⟩
      (Block.eqFactor_affAt (Block.affAt_coord i _) _)
      (fun a hne => Block.eqFactor_constAt (Block.constAt_coord i _ (fun he => hne (Fin.ext (by
        have := congrArg Fin.val he; simpa using this)))) _)
  · exact (Block.ConstAt.prod _ (fun a =>
      Block.eqFactor_constAt (Block.constAt_coord i _ (fun he => hi (by
        have := congrArg Fin.val he; dsimp only at this; omega))) _)).affAt

theorem constAt_eqDrawK_ge {M N : ℕ} (m n e : ℕ) (hm : m ≤ M) (x : Fin N → K)
    (i : Fin M) (hi : m ≤ i.val) :
    Block.ConstAt i (fun y : Fin M → K => eqDrawK m n e hm y x) := by
  unfold eqDrawK
  refine (Block.constAt_const i (Block.selK n e x)).mul (Block.ConstAt.prod _ (fun a => ?_))
  exact Block.eqFactor_constAt (Block.constAt_coord i _ (fun he => by
    have := congrArg Fin.val he; dsimp only at this; omega)) _

end PolyHelpers

/-! ## 4. Words, `nonzeroE` / `nz1`, and folds in `K` -/

section WordsAndFolds

variable {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

def Z_range (M off len : ℕ) : Finset (Fin M) :=
  Finset.univ.filter (fun i : Fin M => off ≤ i.val ∧ i.val < off + len)

theorem kI_canon (v : ℤ) : (kI v).Canon := by
  unfold kI Fp.fromI64
  refine Fp2.canon_fromBase _ ?_
  split_ifs <;> exact Fp.new_canon _

theorem fp2_isZero_iff (w : Fp2) : w.isZero = true ↔ w = Fp2.zero := by
  rcases w with ⟨⟨c0⟩, ⟨c1⟩⟩
  simp [Fp2.isZero, Fp2.zero, Fp.zero]

theorem ofK_isZero_iff (hU : U ^ 2 = algebraMap GF K 7) (a : K) :
    (ZK60.HonestClassify.ofK U hbij a).isZero = true ↔ a = 0 := by
  rw [fp2_isZero_iff]
  constructor
  · intro h
    have h1 := congrArg (Fp2.toK U) h
    rw [ZK60.HonestClassify.toK_ofK U hbij a, Fp2.toK_zero U] at h1
    exact h1
  · intro h
    subst h
    refine Fp2.toK_injective U hU (ZK60.HonestClassify.ofK_canon U hbij 0) Fp2.canon_zero ?_
    rw [ZK60.HonestClassify.toK_ofK U hbij 0, Fp2.toK_zero U]

theorem stgWords_canon {M : ℕ} (y : Fin M → K) :
    ∀ a ∈ stgWords U hbij y, a.Canon := by
  intro a ha
  simp only [stgWords, List.mem_ofFn] at ha
  obtain ⟨i, rfl⟩ := ha
  exact ZK60.HonestClassify.ofK_canon U hbij (y i)

theorem stgWords_getD_toK {M : ℕ} (y : Fin M → K) (i : ℕ) (hi : i < M) :
    ((stgWords U hbij y).getD i Fp2.zero).toK U = y ⟨i, hi⟩ := by
  simp only [stgWords, List.getD_eq_getElem?_getD, List.getElem?_ofFn]
  rw [dite_eq_left hi, Option.getD_some, ZK60.HonestClassify.toK_ofK U hbij]

theorem xOf_stgWords {N : ℕ} (x : Fin N → K) :
    (Block.xOf U (stgWords U hbij x) : Fin N → K) = x := by
  funext i
  exact stgWords_getD_toK U hbij x i.val i.isLt

theorem xOf_take_drop_stgWords {N : ℕ} (n : ℕ) (x : Fin N → K) :
    (Block.xOf U ((stgWords U hbij x).take n ++ (stgWords U hbij x).drop n) : Fin N → K) = x := by
  rw [List.take_append_drop]
  exact xOf_stgWords U hbij x

theorem nonzeroE_stgWords_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (off len : ℕ)
    (hle : off + len ≤ M) (y : Fin M → K)
    (hZ : ∀ i ∈ Z_range M off len, y i ≠ 0) :
    StageV.nonzeroE (((stgWords U hbij y).drop off).take len)
      = .ok (((stgWords U hbij y).drop off).take len) := by
  unfold StageV.nonzeroE
  have hany : (((stgWords U hbij y).drop off).take len).any Fp2.isZero = false := by
    rw [List.any_eq_false]
    intro w hw
    have hw_len : (((stgWords U hbij y).drop off).take len).length = len := by
      rw [List.length_take, List.length_drop, stgWords_length]; omega
    obtain ⟨j, hj, rfl⟩ := List.getElem_of_mem hw
    have hj_lt : off + j < M := by omega
    have hget : (((stgWords U hbij y).drop off).take len)[j]
        = ZK60.HonestClassify.ofK U hbij (y ⟨off + j, hj_lt⟩) := by
      simp [stgWords, List.getElem_take, List.getElem_drop]
    rw [hget]
    intro hz
    exact hZ ⟨off + j, hj_lt⟩ (by simp [Z_range]; omega) ((ofK_isZero_iff U hbij hU _).mp hz)
  simp [hany]

theorem nonzeroE_stgWords_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (off len : ℕ)
    (y : Fin M → K) (i : Fin M) (hi : i ∈ Z_range M off len) (hy : y i = 0) :
    StageV.nonzeroE (((stgWords U hbij y).drop off).take len)
      = .error "zero batching challenge; discard attempt" := by
  unfold StageV.nonzeroE
  have hi' : off ≤ i.val ∧ i.val < off + len := (Finset.mem_filter.mp hi).2
  have hlen : i.val - off < (((stgWords U hbij y).drop off).take len).length := by
    rw [List.length_take, List.length_drop, stgWords_length]; omega
  have hmem : ZK60.HonestClassify.ofK U hbij (y i) ∈ (((stgWords U hbij y).drop off).take len) := by
    have hget : (((stgWords U hbij y).drop off).take len)[i.val - off]'hlen
        = ZK60.HonestClassify.ofK U hbij (y i) := by
      simp only [stgWords, List.getElem_take, List.getElem_drop, List.getElem_ofFn]
      congr 2; ext; simp; omega
    rw [← hget]
    exact List.getElem_mem hlen
  have hany : (((stgWords U hbij y).drop off).take len).any Fp2.isZero = true :=
    List.any_eq_true.mpr ⟨_, hmem, (ofK_isZero_iff U hbij hU (y i)).mpr hy⟩
  simp [hany]

theorem nz1_stgWords_ok (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (off : ℕ)
    (hle : off + 1 ≤ M) (y : Fin M → K)
    (hZ : ∀ i ∈ Z_range M off 1, y i ≠ 0) :
    StageV.nz1 (stgWords U hbij y) off = .ok ((stgWords U hbij y).getD off Fp2.zero) := by
  unfold StageV.nz1
  rw [nonzeroE_stgWords_ok U hbij hU off 1 hle y hZ]
  change Except.ok ((((stgWords U hbij y).drop off).take 1).getD 0 Fp2.zero) = _
  rw [getD_take_lt _ 1 0 (by norm_num), getD_drop, Nat.add_zero]

theorem nz1_stgWords_err (hU : U ^ 2 = algebraMap GF K 7) {M : ℕ} (off : ℕ)
    (y : Fin M → K) (i : Fin M) (hi : i ∈ Z_range M off 1) (hy : y i = 0) :
    StageV.nz1 (stgWords U hbij y) off = .error "zero batching challenge; discard attempt" := by
  unfold StageV.nz1
  rw [nonzeroE_stgWords_err U hbij hU off 1 y i hi hy]
  rfl

theorem vg_drop_take_toK {M : ℕ} (y : Fin M → K) (off len j : ℕ) (hj : j < len) (h : off + len ≤ M) :
    (vg (((stgWords U hbij y).drop off).take len) j).toK U = y ⟨off + j, by omega⟩ := by
  unfold vg
  rw [getD_take_lt _ len j hj, getD_drop, stgWords_getD_toK U hbij y (off + j) (by omega)]

theorem foldl_range_add_toK (f : ℕ → Fp2) (hf : ∀ j, (f j).Canon) :
    ∀ (m : ℕ),
      ((List.range m).foldl (fun acc j => acc.add (f j)) Fp2.zero).Canon
      ∧ ((List.range m).foldl (fun acc j => acc.add (f j)) Fp2.zero).toK U
          = ∑ j ∈ Finset.range m, (f j).toK U
  | 0 => ⟨Fp2.canon_zero, by simp [Fp2.toK_zero]⟩
  | m + 1 => by
    obtain ⟨hc, heq⟩ := foldl_range_add_toK f hf m
    rw [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    refine ⟨Fp2.canon_add _ _, ?_⟩
    rw [Fp2.toK_add U _ _ hc (hf m), heq, Finset.sum_range_succ]

theorem zfoldW_toK (hU : U ^ 2 = algebraMap GF K 7) (v : List Fp2) (zeta : Fp2) :
    (zfoldW v zeta).Canon
    ∧ (zfoldW v zeta).toK U = ∑ j ∈ Finset.range 12, (vg v (2 + j)).toK U * (zeta.toK U) ^ j := by
  unfold zfoldW
  suffices h : ∀ m : ℕ,
      let st := (List.range m).foldl
        (fun (st : Fp2 × Fp2) j => (st.1.add (st.2.mul (vg v (2 + j))), st.2.mul zeta))
        (Fp2.zero, Fp2.one)
      st.1.Canon ∧ st.2.Canon
        ∧ st.1.toK U = ∑ j ∈ Finset.range m, (vg v (2 + j)).toK U * (zeta.toK U) ^ j
        ∧ st.2.toK U = (zeta.toK U) ^ m by
    obtain ⟨h1, _, h3, _⟩ := h 12
    exact ⟨h1, h3⟩
  intro m
  induction m with
  | zero =>
    exact ⟨Fp2.canon_zero, Fp2.canon_one, by simp [Fp2.toK_zero], by simp [Fp2.toK_one]⟩
  | succ m ih =>
    obtain ⟨hc1, hc2, he1, he2⟩ := ih
    simp only [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil]
    refine ⟨Fp2.canon_add _ _, Fp2.canon_mul _ _, ?_, ?_⟩
    · rw [Fp2.toK_add U _ _ hc1 (Fp2.canon_mul _ _), Fp2.toK_mul U hU, he1, he2,
          Finset.sum_range_succ, mul_comm ((zeta.toK U) ^ m)]
    · rw [Fp2.toK_mul U hU, he2, pow_succ]

end WordsAndFolds

/-! ## 5. Coordinate `varsOKb` and total SBM builder steppers -/

theorem coordVar_fixedC {c : Block.Coord} {l : List Fp2} (hc : c ∈ StageV.fixedC l) :
    Block.coordVar c = none := by
  unfold StageV.fixedC at hc
  obtain ⟨_, _, rfl⟩ := List.mem_map.mp hc
  rfl

theorem coordVar_fixedBits {c : Block.Coord} {val bits : ℕ} (hc : c ∈ StageV.fixedBits val bits) :
    Block.coordVar c = none := by
  unfold StageV.fixedBits at hc
  obtain ⟨_, _, rfl⟩ := List.mem_map.mp hc
  rfl

theorem varsOKb_fixed_rho_fixed (pre post : List Block.Coord) (lo hi : ℕ)
    (hpre : ∀ c ∈ pre, Block.coordVar c = none)
    (hpost : ∀ c ∈ post, Block.coordVar c = none) :
    Block.varsOKb ((pre ++ StageV.rhoC lo hi ++ post).map Block.coordVar) = true := by
  unfold Block.varsOKb
  rw [List.all_eq_true]
  intro q hq
  rw [List.all_eq_true]
  intro q' hq'
  simp only [Bool.or_eq_true, decide_eq_true_eq]
  by_cases heq : q = q'
  · exact Or.inl (Or.inl heq)
  · by_cases hnone : ((pre ++ StageV.rhoC lo hi ++ post).map Block.coordVar).getD q none = none
    · exact Or.inl (Or.inr hnone)
    · refine Or.inr (fun hsame => ?_)
      have hget : ∀ idx, idx < (pre ++ StageV.rhoC lo hi ++ post).length →
          ((pre ++ StageV.rhoC lo hi ++ post).map Block.coordVar).getD idx none ≠ none →
          pre.length ≤ idx ∧ idx < pre.length + (hi - lo) ∧
            ((pre ++ StageV.rhoC lo hi ++ post).map Block.coordVar).getD idx none
              = some (lo + (idx - pre.length)) := by
        intro idx hidx hn
        have hlenR : (StageV.rhoC lo hi).length = hi - lo := by simp [StageV.rhoC]
        rw [List.getD_eq_getElem?_getD, List.getElem?_map] at hn ⊢
        by_cases h1 : idx < pre.length
        · rw [List.append_assoc, List.getElem?_append_left h1] at hn
          obtain ⟨c, hc⟩ : ∃ c, pre[idx]? = some c := ⟨_, List.getElem?_eq_getElem h1⟩
          rw [hc] at hn
          exact absurd (hpre c (List.mem_of_getElem? hc)) hn
        · by_cases h2 : idx < pre.length + (hi - lo)
          · refine ⟨by omega, h2, ?_⟩
            have hlt1 : idx < (pre ++ StageV.rhoC lo hi).length := by
              rw [List.length_append, hlenR]; omega
            rw [List.getElem?_append_left hlt1, List.getElem?_append_right (by omega)]
            unfold StageV.rhoC
            rw [List.getElem?_map, List.getElem?_range' (show idx - pre.length < hi - lo by omega)]
            simp [Block.coordVar]
          · have hge : (pre ++ StageV.rhoC lo hi).length ≤ idx := by
              rw [List.length_append, hlenR]; omega
            rw [List.getElem?_append_right hge] at hn
            have hlt2 : idx - (pre ++ StageV.rhoC lo hi).length < post.length := by
              rw [List.length_append] at hidx; omega
            obtain ⟨c, hc⟩ : ∃ c, post[idx - (pre ++ StageV.rhoC lo hi).length]? = some c :=
              ⟨_, List.getElem?_eq_getElem hlt2⟩
            rw [hc] at hn
            exact absurd (hpost c (List.mem_of_getElem? hc)) hn
      rw [List.mem_range, List.length_map] at hq hq'
      obtain ⟨_, _, hv1⟩ := hget q hq hnone
      obtain ⟨_, _, hv2⟩ := hget q' hq' (by rw [← hsame]; exact hnone)
      rw [hv1, hv2, Option.some.injEq] at hsame
      exact heq (by omega)

theorem build_of_run_ex {m : SBM Block.SlotDef} {df : Block.SlotDef}
    (h : ∃ b', m.run {} = .ok (df, b')) : build m = .ok df := by
  obtain ⟨b', hb'⟩ := h
  unfold build; rw [hb']; rfl

theorem sbm_bind_ok {α β : Type} (m : SBM α) (f : α → SBM β) (b b1 : SBS) (a : α) (c : β)
    (h1 : m.run b = .ok (a, b1)) (h2 : ∃ b2, (f a).run b1 = .ok (c, b2)) :
    ∃ b2, (m >>= f).run b = .ok (c, b2) := by
  obtain ⟨b2, hb2⟩ := h2
  exact ⟨b2, by rw [StateT.run_bind, h1]; exact hb2⟩

theorem sbm_eqT (pt : List Fp2) (s : ℕ) (b : SBS) :
    (eqT pt s).run b = .ok (b.tabs.length, { b with tabs := b.tabs ++ [.eq pt s] }) := rfl

theorem sbm_pubT (pv : List Fp2) (b : SBS) :
    (pubT pv).run b = .ok (b.tabs.length, { b with tabs := b.tabs ++ [.pub pv] }) := rfl

theorem sbm_aSliceT (L : Lay) (slot off log : ℕ) (coords : List Block.Coord) (b : SBS)
    (hak : b.ak < (L.spec slot).aSites) :
    (aSliceT L slot off log coords).run b = .ok (b.tabs.length,
      { b with tabs := b.tabs ++ [.priv ⟨.a, [(off, Fp2.one)], log, coords,
          L.aMaskBase + 2 * (L.prefixA slot + b.ak), 0⟩], ak := b.ak + 1 }) := by
  unfold aSliceT pushT Lay.aSite
  have hle : ¬ ((L.spec slot).aSites ≤ b.ak) := by omega
  simp [StateT.run_bind, hle]

theorem sbm_aAtT (L : Lay) (slot plane : ℕ) (coords : List Block.Coord) (b : SBS)
    (hak : b.ak < (L.spec slot).aSites) :
    (aAtT L slot plane coords).run b = .ok (b.tabs.length,
      { b with tabs := b.tabs ++ [.priv ⟨.a, [(L.aOff plane, Fp2.one)], L.aLog.getD plane 0, coords,
          L.aMaskBase + 2 * (L.prefixA slot + b.ak), 0⟩], ak := b.ak + 1 }) :=
  sbm_aSliceT L slot _ _ coords b hak

theorem sbm_aT (L : Lay) (slot plane : ℕ) (b : SBS) (hak : b.ak < (L.spec slot).aSites) :
    (aT L slot plane).run b = .ok (b.tabs.length,
      { b with tabs := b.tabs ++ [.priv ⟨.a, [(L.aOff plane, Fp2.one)], L.aLog.getD plane 0,
          rhoC 0 (L.aLog.getD plane 0),
          L.aMaskBase + 2 * (L.prefixA slot + b.ak), 0⟩], ak := b.ak + 1 }) :=
  sbm_aAtT L slot plane _ b hak

theorem sbm_hT (L : Lay) (slot plane : ℕ) (b : SBS) (hhk : b.hk < (L.spec slot).hSites) :
    (hT L slot plane).run b = .ok (b.tabs.length,
      { b with tabs := b.tabs ++ [.priv ⟨.h, [((L.hOff plane).1, Fp2.one), ((L.hOff plane).2, Block.fp2U)],
          L.hLog.getD plane 0, rhoC 0 (L.hLog.getD plane 0),
          L.hMaskBase + 2 * (L.prefixH slot + b.hk), 0⟩], hk := b.hk + 1 }) := by
  unfold hT pushT Lay.hSite
  have hle : ¬ ((L.spec slot).hSites ≤ b.hk) := by omega
  simp [StateT.run_bind, hle]

theorem sbm_ioT (cm : Block.Cm) (log : ℕ) (coords : List Block.Coord) (mr : ℕ) (b : SBS) :
    (ioT cm log coords mr).run b = .ok (b.tabs.length,
      { b with tabs := b.tabs ++ [.priv ⟨cm, [(0, Fp2.one)], log, coords, mr, 0⟩], iok := b.iok + 1 }) := rfl

theorem sbm_finishT (L : Lay) (slot : ℕ) (poly : List Fp2 → Fp2) (hosted : List (ℕ × Fp2)) (b : SBS)
    (hak : b.ak = (L.spec slot).aSites) (hhk : b.hk = (L.spec slot).hSites) (hiok : b.iok = (L.spec slot).ioSites) :
    ∃ b', (finishT L slot poly hosted).run b = .ok (⟨b.tabs, poly, hosted⟩, b') := by
  refine ⟨b, ?_⟩
  unfold finishT
  rw [StateT.run_bind, StateT.run_get]
  dsimp only [Pure.pure, Bind.bind, Except.bind, Except.pure]
  have hcond : ¬ (b.ak ≠ (L.spec slot).aSites ∨ b.hk ≠ (L.spec slot).hSites ∨ b.iok ≠ (L.spec slot).ioSites) := by
    omega
  rw [ite_eq_right hcond]
  rfl

theorem sbm_forIn_aSlice (L : Lay) (slot : ℕ) (offOf logOf : ℕ → ℕ) (coordsOf : ℕ → List Block.Coord) :
    ∀ (ks : List ℕ) (b : SBS),
      b.ak + ks.length ≤ (L.spec slot).aSites →
      (forIn (m := SBM) ks PUnit.unit (fun kk _ => do
        let _ ← aSliceT L slot (offOf kk) (logOf kk) (coordsOf kk)
        pure (ForInStep.yield PUnit.unit))).run b
      = .ok (PUnit.unit, { b with
          tabs := b.tabs ++ (ks.zipIdx b.ak).map (fun p =>
            Block.Tab.priv ⟨.a, [(offOf p.1, Fp2.one)], logOf p.1, coordsOf p.1,
              L.aMaskBase + 2 * (L.prefixA slot + p.2), 0⟩),
          ak := b.ak + ks.length })
  | [], b, _ => by simp; rfl
  | k :: ks, b, hle => by
    have hak0 : b.ak < (L.spec slot).aSites := by simp at hle; omega
    rw [List.forIn_cons, StateT.run_bind, StateT.run_bind,
        sbm_aSliceT L slot (offOf k) (logOf k) (coordsOf k) b hak0]
    let b1 : SBS := { b with tabs := b.tabs ++ [.priv ⟨.a, [(offOf k, Fp2.one)], logOf k, coordsOf k,
        L.aMaskBase + 2 * (L.prefixA slot + b.ak), 0⟩], ak := b.ak + 1 }
    have hb1 : b1.ak + ks.length ≤ (L.spec slot).aSites := by simp [b1] at hle ⊢; omega
    change (forIn (m := SBM) ks PUnit.unit (fun kk _ => do
        let _ ← aSliceT L slot (offOf kk) (logOf kk) (coordsOf kk)
        pure (ForInStep.yield PUnit.unit))).run b1 = _
    rw [sbm_forIn_aSlice L slot offOf logOf coordsOf ks b1 hb1]
    simp only [b1, List.zipIdx_cons, List.map_cons, List.append_assoc, List.singleton_append, List.length_cons]
    have hak_eq : b.ak + 1 + ks.length = b.ak + (ks.length + 1) := by omega
    rw [hak_eq]

theorem sbm_forIn_aT (L : Lay) (slot : ℕ) :
    ∀ (ks : List ℕ) (b : SBS),
      b.ak + ks.length ≤ (L.spec slot).aSites →
      (forIn (m := SBM) ks PUnit.unit (fun p _ => do
        let _ ← aT L slot p
        pure (ForInStep.yield PUnit.unit))).run b
      = .ok (PUnit.unit, { b with
          tabs := b.tabs ++ (ks.zipIdx b.ak).map (fun p =>
            Block.Tab.priv ⟨.a, [(L.aOff p.1, Fp2.one)], L.aLog.getD p.1 0, rhoC 0 (L.aLog.getD p.1 0),
              L.aMaskBase + 2 * (L.prefixA slot + p.2), 0⟩),
          ak := b.ak + ks.length }) :=
  sbm_forIn_aSlice L slot (fun p => L.aOff p) (fun p => L.aLog.getD p 0) (fun p => rhoC 0 (L.aLog.getD p 0))

theorem sbm_forIn_hT (L : Lay) (slot : ℕ) (planeOf : ℕ → ℕ) :
    ∀ (ks : List ℕ) (b : SBS),
      b.hk + ks.length ≤ (L.spec slot).hSites →
      (forIn (m := SBM) ks PUnit.unit (fun j _ => do
        let _ ← hT L slot (planeOf j)
        pure (ForInStep.yield PUnit.unit))).run b
      = .ok (PUnit.unit, { b with
          tabs := b.tabs ++ (ks.zipIdx b.hk).map (fun p =>
            let pl := planeOf p.1
            Block.Tab.priv ⟨.h, [((L.hOff pl).1, Fp2.one), ((L.hOff pl).2, Block.fp2U)],
              L.hLog.getD pl 0, rhoC 0 (L.hLog.getD pl 0),
              L.hMaskBase + 2 * (L.prefixH slot + p.2), 0⟩),
          hk := b.hk + ks.length })
  | [], b, _ => by simp; rfl
  | k :: ks, b, hle => by
    have hhk0 : b.hk < (L.spec slot).hSites := by simp at hle; omega
    rw [List.forIn_cons, StateT.run_bind, StateT.run_bind,
        sbm_hT L slot (planeOf k) b hhk0]
    let b1 : SBS := { b with tabs := b.tabs ++ [.priv ⟨.h, [((L.hOff (planeOf k)).1, Fp2.one),
        ((L.hOff (planeOf k)).2, Block.fp2U)], L.hLog.getD (planeOf k) 0, rhoC 0 (L.hLog.getD (planeOf k) 0),
        L.hMaskBase + 2 * (L.prefixH slot + b.hk), 0⟩], hk := b.hk + 1 }
    have hb1 : b1.hk + ks.length ≤ (L.spec slot).hSites := by simp [b1] at hle ⊢; omega
    change (forIn (m := SBM) ks PUnit.unit (fun j _ => do
        let _ ← hT L slot (planeOf j)
        pure (ForInStep.yield PUnit.unit))).run b1 = _
    rw [sbm_forIn_hT L slot planeOf ks b1 hb1]
    simp only [b1, List.zipIdx_cons, List.map_cons, List.append_assoc, List.singleton_append, List.length_cons]
    have hhk_eq : b.hk + 1 + ks.length = b.hk + (ks.length + 1) := by omega
    rw [hhk_eq]

/-! ## 6. Table evaluations (`stgTabK`), `claimSem` degree, and `OffZero` engines -/

section TabAndClaim

variable {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

def stgTabW (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
    (n e : ℕ) {N : ℕ} (x : Fin N → K) (rho es : List Fp2) : Block.Tab → K
  | .eq point start =>
    if start + point.length ≤ n then
      Block.selK n e x * eqPoly (fun a : Fin point.length => (point.getD a Fp2.zero).toK U)
        (fun a : Fin point.length => Block.xrK n x (start + a))
    else 0
  | .pub pv =>
    if pv.length = 2 ^ n then
      Block.selK n e x * mleAt (fun b : Fin n → Bool => (pv.getD (msbIndex n b) Fp2.zero).toK U)
        (fun a : Fin n => Block.xrK n x a)
    else 0
  | .priv p =>
    cs p.cm (Block.buildClaim P p (Block.claimPoint p rho)
      (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero)

noncomputable def stgTabK (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
    (n e : ℕ) {N : ℕ} (x : Fin N → K) : Block.Tab → K :=
  stgTabW U P cs n e x ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n)

def tabFit (n : ℕ) : Block.Tab → Prop
  | .eq pt s => s + pt.length ≤ n
  | .pub pv => pv.length = 2 ^ n
  | .priv _ => True

def tabsFit (n : ℕ) (tabs : List Block.Tab) : Prop :=
  ∀ t ∈ tabs, tabFit n t

theorem tabVals_cons_eq (sel : Fp2) (rho W : List Fp2) (t : Block.Tab) (ts : List Block.Tab) (idx : ℕ) :
    Block.tabVals sel rho W (t :: ts) idx =
      match Block.tabVal sel rho W t idx with
      | .error e => .error e
      | .ok (v, k') =>
        match Block.tabVals sel rho W ts k' with
        | .error e => .error e
        | .ok vs => .ok (v :: vs) := rfl

theorem tabVals_err_of_not_fit {n : ℕ} {rho : List Fp2} (hrho : rho.length = n) (sel : Fp2) :
    ∀ (tabs : List Block.Tab) (W : List Fp2) (idx : ℕ),
      ¬ tabsFit n tabs → ∃ msg, Block.tabVals sel rho W tabs idx = .error msg
  | [], _, _, hnf => absurd (fun _ h => absurd h List.not_mem_nil) hnf
  | t :: ts, W, idx, hnf => by
    classical
    by_cases ht : tabFit n t
    · have hts : ¬ tabsFit n ts := fun h => hnf (fun t' ht' => by
        rcases List.mem_cons.mp ht' with rfl | hm
        · exact ht
        · exact h t' hm)
      rw [tabVals_cons_eq]
      cases hv : Block.tabVal sel rho W t idx with
      | error msg => exact ⟨msg, rfl⟩
      | ok pair =>
        rcases pair with ⟨v, k'⟩
        obtain ⟨msg, hmsg⟩ := tabVals_err_of_not_fit hrho sel ts W k' hts
        exact ⟨msg, by dsimp only; rw [hmsg]⟩
    · cases t with
      | eq pt s =>
        have hns : ¬ (s + pt.length ≤ rho.length) := by rw [hrho]; exact ht
        exact ⟨"panic: rho slice out of range", by
          rw [tabVals_cons_eq]
          change (match if s + pt.length ≤ rho.length then
              match eqPoint pt ((rho.drop s).take pt.length) with
              | some v => Except.ok (sel.mul v, idx)
              | none => Except.error "panic: eq_point lengths"
            else Except.error "panic: rho slice out of range" with
            | Except.error e => Except.error e
            | Except.ok (v, k') => _) = _
          rw [ite_eq_right hns]⟩
      | pub pv =>
        have hnp : ¬ (pv.length = 2 ^ rho.length) := by rw [hrho]; exact ht
        exact ⟨"panic: eval_mle_ext length", by
          rw [tabVals_cons_eq]
          change (match match evalMleExt pv rho with
              | some x => Except.ok (sel.mul x, idx)
              | none => Except.error "panic: eval_mle_ext length" with
            | Except.error e => Except.error e
            | Except.ok (v, k') => _) = _
          unfold evalMleExt
          rw [ite_eq_right hnp]⟩
      | priv _ => exact absurd trivial ht

theorem tabVals_ok_of_fit_words (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams)
    (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (n e : ℕ) (rho es : List Fp2)
    (hrho : rho.length = n) (hes : es.length = e) (hleN : (rho ++ es).length ≤ N)
    (hrc : ∀ a ∈ rho, a.Canon) (hec : ∀ a ∈ es, a.Canon) :
    ∀ (tabs : List Block.Tab) (W : List Fp2) (idx : ℕ),
      tabsFit n tabs →
      (∀ t ∈ tabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon) →
      (∀ j, W.getD (idx + j) Fp2.zero = (stgPrivVals U hbij P cs rho es tabs).getD j Fp2.zero) →
      ∃ vals, Block.tabVals (Block.oneMinusProd es) rho W tabs idx = .ok vals
        ∧ (∀ a ∈ vals, a.Canon)
        ∧ vals.map (Fp2.toK U) = tabs.map (stgTabW U P cs n e (Block.xOf U (rho ++ es) : Fin N → K) rho es)
  | [], _, _, _, _, _ => ⟨[], rfl, fun _ h => absurd h List.not_mem_nil, rfl⟩
  | t :: ts, W, idx, hfit, hcan, hW => by
    have hsel := Block.toK_oneMinusProd (N := N) U hU n e rho es hrho hes hleN hec
    have hfit_t : tabFit n t := hfit t List.mem_cons_self
    have hfit_ts : tabsFit n ts := fun t' ht' => hfit t' (List.mem_cons_of_mem _ ht')
    have hcan_ts : ∀ t' ∈ ts, ∀ pt s, t' = .eq pt s → ∀ a ∈ pt, a.Canon :=
      fun t' ht' => hcan t' (List.mem_cons_of_mem _ ht')
    cases t with
    | eq pt s =>
      have hs : s + pt.length ≤ n := hfit_t
      have hs' : s + pt.length ≤ rho.length := by omega
      have hlen_eq : pt.length = ((rho.drop s).take pt.length).length := by
        rw [List.length_take, List.length_drop]; omega
      have hptc : ∀ a ∈ pt, a.Canon := hcan (.eq pt s) List.mem_cons_self pt s rfl
      have hsc : ∀ a ∈ (rho.drop s).take pt.length, a.Canon :=
        fun a ha => hrc a (List.mem_of_mem_drop (List.mem_of_mem_take ha))
      have hv_ok : Block.tabVal (Block.oneMinusProd es) rho W (.eq pt s) idx
          = .ok ((Block.oneMinusProd es).mul (eqPointBody pt ((rho.drop s).take pt.length)), idx) := by
        change (if s + pt.length ≤ rho.length then
            match eqPoint pt ((rho.drop s).take pt.length) with
            | some v => Except.ok ((Block.oneMinusProd es).mul v, idx)
            | none => Except.error "panic: eq_point lengths"
          else Except.error "panic: rho slice out of range") = _
        rw [ite_eq_left hs']
        unfold eqPoint
        rw [ite_eq_left hlen_eq]
      obtain ⟨vs, hvs, hvsc, hvsm⟩ := tabVals_ok_of_fit_words hU P cs n e rho es hrho hes hleN hrc hec
        ts W idx hfit_ts hcan_ts hW
      refine ⟨(Block.oneMinusProd es).mul (eqPointBody pt ((rho.drop s).take pt.length)) :: vs, ?_, ?_, ?_⟩
      · rw [tabVals_cons_eq, hv_ok]; dsimp only; rw [hvs]
      · intro a ha
        rcases List.mem_cons.mp ha with rfl | ha
        · exact Fp2.canon_mul _ _
        · exact hvsc a ha
      · rw [List.map_cons, List.map_cons, hvsm]
        refine congrArg (· :: _) ?_
        simp only [stgTabW, ite_eq_left hs]
        have he2 : vecK U pt.length ((rho.drop s).take pt.length)
            = fun a : Fin pt.length => Block.xrK n (Block.xOf U (rho ++ es) : Fin N → K) (s + a) := by
          funext a
          show (((rho.drop s).take pt.length).getD a Fp2.zero).toK U = _
          rw [getD_take_lt _ _ _ a.isLt, getD_drop, Block.xrK_xOf U n rho es hrho hleN]
        rw [Fp2.toK_mul U hU, hsel, toK_eqPointBody U hU pt _ hptc hsc hlen_eq, he2]
        rfl
    | pub pv =>
      have hpv : pv.length = 2 ^ n := hfit_t
      have hpv' : pv.length = 2 ^ rho.length := by rw [hrho]; exact hpv
      have hv_ok : Block.tabVal (Block.oneMinusProd es) rho W (.pub pv) idx
          = .ok ((Block.oneMinusProd es).mul (mleSumExt pv (eqTableMsb rho)), idx) := by
        change (match evalMleExt pv rho with
          | some x => Except.ok ((Block.oneMinusProd es).mul x, idx)
          | none => Except.error "panic: eval_mle_ext length") = _
        unfold evalMleExt
        rw [ite_eq_left hpv']
      obtain ⟨vs, hvs, hvsc, hvsm⟩ := tabVals_ok_of_fit_words hU P cs n e rho es hrho hes hleN hrc hec
        ts W idx hfit_ts hcan_ts hW
      refine ⟨(Block.oneMinusProd es).mul (mleSumExt pv (eqTableMsb rho)) :: vs, ?_, ?_, ?_⟩
      · rw [tabVals_cons_eq, hv_ok]; dsimp only; rw [hvs]
      · intro a ha
        rcases List.mem_cons.mp ha with rfl | ha
        · exact Fp2.canon_mul _ _
        · exact hvsc a ha
      · rw [List.map_cons, List.map_cons, hvsm]
        refine congrArg (· :: _) ?_
        simp only [stgTabW, ite_eq_left hpv]
        subst hrho
        have he2 : vecK U rho.length rho
            = fun a : Fin rho.length => Block.xrK rho.length (Block.xOf U (rho ++ es) : Fin N → K) a := by
          funext a
          show (rho.getD a Fp2.zero).toK U = _
          rw [Block.xrK_xOf U rho.length rho es rfl hleN]
        rw [Fp2.toK_mul U hU, hsel, toK_mleSumExt U hU pv rho hrc hpv', he2]
    | priv p =>
      have hv_ok : Block.tabVal (Block.oneMinusProd es) rho W (.priv p) idx
          = .ok (W.getD idx Fp2.zero, idx + 1) := rfl
      have hW0 : W.getD idx Fp2.zero = ZK60.HonestClassify.ofK U hbij
          (cs p.cm (Block.buildClaim P p (Block.claimPoint p rho)
            (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero)) := by
        have e0 := hW 0
        rw [Nat.add_zero] at e0
        exact e0
      have hW' : ∀ j, W.getD ((idx + 1) + j) Fp2.zero = (stgPrivVals U hbij P cs rho es ts).getD j Fp2.zero := by
        intro j
        have ej := hW (j + 1)
        rw [show idx + (j + 1) = (idx + 1) + j by omega] at ej
        exact ej
      obtain ⟨vs, hvs, hvsc, hvsm⟩ := tabVals_ok_of_fit_words hU P cs n e rho es hrho hes hleN hrc hec
        ts W (idx + 1) hfit_ts hcan_ts hW'
      refine ⟨W.getD idx Fp2.zero :: vs, ?_, ?_, ?_⟩
      · rw [tabVals_cons_eq, hv_ok]; dsimp only; rw [hvs]
      · intro a ha
        rcases List.mem_cons.mp ha with rfl | ha
        · rw [hW0]; exact ZK60.HonestClassify.ofK_canon U hbij _
        · exact hvsc a ha
      · rw [List.map_cons, List.map_cons, hvsm]
        refine congrArg (· :: _) ?_
        simp only [stgTabW]
        rw [hW0, ZK60.HonestClassify.toK_ofK U hbij]

theorem tabVals_stgTabK (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams)
    (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (n e : ℕ) (hN : N = n + e) (x : Fin N → K)
    (tabs : List Block.Tab) (hfit : tabsFit n tabs)
    (hcan : ∀ t ∈ tabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon) :
    ∃ vals, Block.tabVals (Block.oneMinusProd ((stgWords U hbij x).drop n))
        ((stgWords U hbij x).take n)
        (stgPrivVals U hbij P cs ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n) tabs) tabs 0 = .ok vals
      ∧ (∀ a ∈ vals, a.Canon)
      ∧ vals.map (Fp2.toK U) = tabs.map (stgTabK U hbij P cs n e x) := by
  have hrho : ((stgWords U hbij x).take n).length = n := by simp [stgWords_length, hN]
  have hes : ((stgWords U hbij x).drop n).length = e := by simp [stgWords_length, hN]
  have hleN : ((stgWords U hbij x).take n ++ (stgWords U hbij x).drop n).length ≤ N := by
    rw [List.take_append_drop, stgWords_length]
  have hrc : ∀ a ∈ (stgWords U hbij x).take n, a.Canon :=
    fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_take ha)
  have hec : ∀ a ∈ (stgWords U hbij x).drop n, a.Canon :=
    fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_drop ha)
  obtain ⟨vals, hv, hvc, hvm⟩ := tabVals_ok_of_fit_words U hbij hU P cs n e
    ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n) hrho hes hleN hrc hec tabs
    (stgPrivVals U hbij P cs ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n) tabs) 0 hfit hcan
    (fun j => by rw [Nat.zero_add])
  rw [xOf_take_drop_stgWords U hbij n x] at hvm
  exact ⟨vals, hv, hvc, hvm⟩

theorem stgTabK_eq_draw {M N : ℕ} (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
    (m n e : ℕ) (hm : m ≤ M) (hmn : m ≤ n) (y : Fin M → K) (x : Fin N → K) :
    stgTabK U hbij P cs n e x (.eq ((stgWords U hbij y).take m) 0) = eqDrawK m n e hm y x := by
  have hlen : ((stgWords U hbij y).take m).length = m := by simp [stgWords_length, hm]
  have hs : 0 + ((stgWords U hbij y).take m).length ≤ n := by omega
  unfold stgTabK stgTabW eqDrawK
  dsimp only
  rw [ite_eq_left hs]
  congr 1
  unfold eqPoly
  rw [← Fin.prod_congr' _ hlen]
  refine Finset.prod_congr rfl (fun a _ => ?_)
  dsimp only [Fin.cast]
  rw [getD_take_lt _ m a.val (by omega), stgWords_getD_toK U hbij y a.val (by omega), Nat.zero_add]

theorem vg_toK_map (vals : List Fp2) (i : ℕ) :
    (vg vals i).toK U = (vals.map (Fp2.toK U)).getD i 0 := by
  unfold vg
  rw [← Fp2.toK_zero U, Block.getD_map_dflt (Fp2.toK U) Fp2.zero vals i]

theorem vg_canon {vals : List Fp2} (hv : ∀ a ∈ vals, a.Canon) (i : ℕ) : (vg vals i).Canon :=
  Fp2.canon_getD hv i

omit [Field K] [Algebra GF K] in
def narrowRowC [Zero K] [One K] (off ls lc R row : ℕ) : K :=
  if lc ≤ ls then
    if off / 2 ^ lc ≤ row ∧ row < off / 2 ^ lc + 1 ∧ row < R then 1 else 0
  else
    if row = off / 2 ^ lc ∧ off / 2 ^ lc < R then 1 else 0

theorem zpart_row_narrow_toK (hU : U ^ 2 = algebraMap GF K 7) (q : ZK60.Exec.ZPart) (R lc : ℕ)
    (hls : q.logSize ≤ lc) (hcc : q.coef.Canon) (row : ℕ) :
    ((zpartWeights q R lc).1.getD row Fp2.zero).toK U
      = q.coef.toK U * narrowRowC q.offset q.logSize lc R row := by
  have hsub : q.logSize - lc = 0 := Nat.sub_eq_zero_of_le hls
  unfold zpartWeights narrowRowC
  dsimp only
  by_cases hemp : q.point.isEmpty = true
  · rw [ite_eq_left hemp]
    by_cases hle : lc ≤ q.logSize
    · rw [ite_eq_left hle, ite_eq_left hle]
      dsimp only
      rw [hsub, pow_zero,
          (Block.foldAdd_getD (fun _ => q.coef) (q.offset / 2 ^ lc) (List.replicate R Fp2.zero) 1 row).2,
          List.length_replicate, Block.getD_replicate_zero]
      split_ifs
      · rw [Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · rw [Fp2.toK_zero, mul_zero]
    · rw [ite_eq_right hle, ite_eq_right hle]
      dsimp only
      rw [Block.addAt_getD, List.length_replicate, Block.getD_replicate_zero]
      split_ifs
      · rw [Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · rw [Fp2.toK_zero, mul_zero]
  · rw [ite_eq_right hemp]
    by_cases hle : lc ≤ q.logSize
    · rw [ite_eq_left hle, ite_eq_left hle]
      have htk : q.point.take (q.logSize - lc) = [] := by rw [hsub]; rfl
      have heq0 : eqTableMsb ([] : List Fp2) = [Fp2.one] := rfl
      rw [htk, heq0]
      dsimp only [List.length_cons, List.length_nil, Nat.zero_add]
      rw [(Block.foldAdd_getD (fun i => q.coef.mul (([Fp2.one] : List Fp2).getD i Fp2.zero))
            (q.offset / 2 ^ lc) (List.replicate R Fp2.zero) 1 row).2,
          List.length_replicate, Block.getD_replicate_zero]
      split_ifs with hr
      · have hi0 : row - q.offset / 2 ^ lc = 0 := by omega
        rw [hi0, List.getD_cons_zero, Fp2.toK_add U _ _ Fp2.canon_zero (Fp2.canon_mul _ _),
            Fp2.toK_zero, zero_add, Fp2.toK_mul U hU, Fp2.toK_one]
      · rw [Fp2.toK_zero, mul_zero]
    · rw [ite_eq_right hle, ite_eq_right hle]
      dsimp only
      rw [Block.addAt_getD, List.length_replicate, Block.getD_replicate_zero]
      split_ifs
      · rw [Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · rw [Fp2.toK_zero, mul_zero]

omit [Algebra GF K] in
def dataRowK (off ls lc m : ℕ) (pt : ℕ → K) (row : ℕ) : K :=
  if m = 0 then
    if lc ≤ ls then
      if off / 2 ^ lc ≤ row ∧ row < off / 2 ^ lc + 2 ^ (ls - lc) then 1 else 0
    else
      if row = off / 2 ^ lc then 1 else 0
  else
    if lc ≤ ls then
      if off / 2 ^ lc ≤ row ∧ row < off / 2 ^ lc + 2 ^ (min (ls - lc) m) then
        eqPoly (fun a : Fin (min (ls - lc) m) => pt a) (Block.bitsK (min (ls - lc) m) (row - off / 2 ^ lc))
      else 0
    else
      if row = off / 2 ^ lc then 1 else 0

theorem zpart_row_data_toK (hU : U ^ 2 = algebraMap GF K 7) (q : ZK60.Exec.ZPart) (R lc m : ℕ)
    (hm : q.point.length = m) (hpc : ∀ a ∈ q.point, a.Canon) (hcc : q.coef.Canon)
    (row : ℕ) (hrow : row < R) :
    ((zpartWeights q R lc).1.getD row Fp2.zero).toK U
      = q.coef.toK U * dataRowK q.offset q.logSize lc m (fun a => (q.point.getD a Fp2.zero).toK U) row := by
  by_cases hm0 : m = 0
  · subst hm0
    have hemp : q.point.isEmpty = true := by simp [List.length_eq_zero_iff.mp hm]
    unfold zpartWeights dataRowK
    simp only [↓reduceIte, hemp]
    by_cases hle : lc ≤ q.logSize
    · rw [ite_eq_left hle, ite_eq_left hle]
      dsimp only
      rw [(Block.foldAdd_getD (fun _ => q.coef) (q.offset / 2 ^ lc) (List.replicate R Fp2.zero)
            (2 ^ (q.logSize - lc)) row).2, List.length_replicate, Block.getD_replicate_zero]
      by_cases hr : q.offset / 2 ^ lc ≤ row ∧ row < q.offset / 2 ^ lc + 2 ^ (q.logSize - lc)
      · have hr' : q.offset / 2 ^ lc ≤ row ∧ row < q.offset / 2 ^ lc + 2 ^ (q.logSize - lc) ∧ row < R :=
          ⟨hr.1, hr.2, hrow⟩
        rw [ite_eq_left hr', ite_eq_left hr, Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · have hr' : ¬ (q.offset / 2 ^ lc ≤ row ∧ row < q.offset / 2 ^ lc + 2 ^ (q.logSize - lc) ∧ row < R) :=
          fun h => hr ⟨h.1, h.2.1⟩
        rw [ite_eq_right hr', ite_eq_right hr, Fp2.toK_zero, mul_zero]
    · rw [ite_eq_right hle, ite_eq_right hle]
      dsimp only
      rw [Block.addAt_getD, List.length_replicate, Block.getD_replicate_zero]
      by_cases hr : row = q.offset / 2 ^ lc
      · have hr' : row = q.offset / 2 ^ lc ∧ q.offset / 2 ^ lc < R := ⟨hr, by omega⟩
        rw [ite_eq_left hr', ite_eq_left hr, Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · have hr' : ¬ (row = q.offset / 2 ^ lc ∧ q.offset / 2 ^ lc < R) := fun h => hr h.1
        rw [ite_eq_right hr', ite_eq_right hr, Fp2.toK_zero, mul_zero]
  · have hpos : 0 < q.point.length := by omega
    have hemp : q.point.isEmpty = false := Block.isEmpty_false_of_length q.point hpos
    rw [Block.zpartWeights_getD q R lc hemp row hrow]
    unfold dataRowK
    rw [ite_eq_right hm0]
    by_cases hle : lc ≤ q.logSize
    · rw [ite_eq_left hle, ite_eq_left hle]
      have htk_len : (q.point.take (q.logSize - lc)).length = min (q.logSize - lc) m := by
        rw [List.length_take, hm]
      have htk_can : ∀ a ∈ q.point.take (q.logSize - lc), a.Canon :=
        fun a ha => hpc a (List.mem_of_mem_take ha)
      obtain ⟨hlenE, hE⟩ := Block.eqMsb_toK U hU (q.point.take (q.logSize - lc))
        (min (q.logSize - lc) m) htk_len htk_can
      rw [hlenE]
      by_cases hr : q.offset / 2 ^ lc ≤ row ∧ row < q.offset / 2 ^ lc + 2 ^ min (q.logSize - lc) m
      · rw [ite_eq_left hr, ite_eq_left hr, Fp2.toK_add U _ _ Fp2.canon_zero (Fp2.canon_mul _ _),
            Fp2.toK_zero, zero_add, Fp2.toK_mul U hU, hE (row - q.offset / 2 ^ lc) (by omega)]
        congr 1
        have he : (fun a : Fin (min (q.logSize - lc) m) => ((q.point.take (q.logSize - lc)).getD a Fp2.zero).toK U)
            = fun a : Fin (min (q.logSize - lc) m) => (q.point.getD a Fp2.zero).toK U := by
          funext a
          exact congrArg (Fp2.toK U) (getD_take_lt q.point (q.logSize - lc) a (by omega) Fp2.zero)
        rw [he]
      · rw [ite_eq_right hr, ite_eq_right hr, Fp2.toK_zero, mul_zero]
    · rw [ite_eq_right hle, ite_eq_right hle]
      by_cases hr : row = q.offset / 2 ^ lc
      · rw [ite_eq_left hr, ite_eq_left hr, Fp2.toK_add U _ _ Fp2.canon_zero hcc, Fp2.toK_zero, zero_add, mul_one]
      · rw [ite_eq_right hr, ite_eq_right hr, Fp2.toK_zero, mul_zero]

omit [Algebra GF K] in
def dataKeyColK (off ls lc m : ℕ) (pt : ℕ → K) (t : ℕ) : K :=
  let c0 := if lc ≤ ls then 0 else off % 2 ^ lc
  let len := if lc ≤ ls then 2 ^ lc else 2 ^ ls
  let sh := if lc ≤ ls then ls - lc else 0
  let mK := m - sh
  if c0 ≤ t ∧ t < c0 + len then
    if mK = 0 then 1
    else if t - c0 < 2 ^ mK then
      eqPoly (fun a : Fin mK => pt (sh + a)) (Block.bitsK mK (t - c0))
    else 0
  else 0

theorem zkey_col_data_toK (hU : U ^ 2 = algebraMap GF K 7) (q : ZK60.Exec.ZPart) (R lc m : ℕ)
    (hm : q.point.length = m) (hpc : ∀ a ∈ q.point, a.Canon) (t : ℕ) (ht : t < 2 ^ lc) :
    ((zkeyWeights (zpartWeights q R lc).2 lc).getD t Fp2.zero).toK U
      = dataKeyColK q.offset q.logSize lc m (fun a => (q.point.getD a Fp2.zero).toK U) t := by
  rw [Block.zkeyWeights_getD _ lc t ht]
  let sh := if lc ≤ q.logSize then q.logSize - lc else 0
  let c0 := if lc ≤ q.logSize then 0 else q.offset % 2 ^ lc
  let len := if lc ≤ q.logSize then 2 ^ lc else 2 ^ q.logSize
  have hkey : (zpartWeights q R lc).2 = ⟨q.point.drop sh, c0, len⟩ := by
    by_cases hm0 : m = 0
    · have hp0 : q.point = [] := List.length_eq_zero_iff.mp (hm.trans hm0)
      unfold zpartWeights
      rw [hp0]
      simp only [List.isEmpty_nil, ↓reduceIte, List.drop_nil]
      by_cases hle : lc ≤ q.logSize <;> simp [hle, c0, len]
    · have hemp : q.point.isEmpty = false := Block.isEmpty_false_of_length q.point (by omega)
      rw [Block.zpartWeights_nonempty q R lc hemp]
      by_cases hle : lc ≤ q.logSize <;> simp [hle, sh, c0, len]
  rw [hkey]
  dsimp only
  unfold dataKeyColK
  change (if c0 ≤ t ∧ t < c0 + len then _ else Fp2.zero).toK U
    = if c0 ≤ t ∧ t < c0 + len then _ else 0
  by_cases htr : c0 ≤ t ∧ t < c0 + len
  · rw [ite_eq_left htr, ite_eq_left htr]
    have hdl : (q.point.drop sh).length = m - sh := by rw [List.length_drop, hm]
    by_cases hmK : m - sh = 0
    · have hemp : (q.point.drop sh).isEmpty = true :=
        List.isEmpty_iff.mpr (List.length_eq_zero_iff.mp (hdl.trans hmK))
      rw [ite_eq_left hemp, ite_eq_left hmK, Fp2.toK_one]
    · have hemp : ¬ ((q.point.drop sh).isEmpty = true) := by
        rw [Block.isEmpty_false_of_length (q.point.drop sh) (by omega)]
        exact Bool.false_ne_true
      rw [ite_eq_right hemp, ite_eq_right hmK]
      have hdc : ∀ a ∈ q.point.drop sh, a.Canon := fun a ha => hpc a (List.mem_of_mem_drop ha)
      obtain ⟨_, hE⟩ := Block.eqMsb_toK U hU (q.point.drop sh) (m - sh) hdl hdc
      by_cases hlt : t - c0 < 2 ^ (m - sh)
      · rw [ite_eq_left hlt, hE (t - c0) hlt]
        have he : (fun a : Fin (m - sh) => ((q.point.drop sh).getD a Fp2.zero).toK U)
            = fun a : Fin (m - sh) => (q.point.getD (sh + a) Fp2.zero).toK U := by
          funext a
          rw [getD_drop]
        rw [he]
      · rw [ite_eq_right hlt, Block.getD_ge_zero _ _ (by omega), Fp2.toK_zero]
  · rw [ite_eq_right htr, ite_eq_right htr, Fp2.toK_zero]

theorem claimSem_priv_words (hU : U ^ 2 = algebraMap GF K 7)
    (P : Block.BlockParams) (R lc Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K)
    {N : ℕ} (n e : ℕ) (rho es : List Fp2)
    (hrho : rho.length = n) (hes : es.length = e) (hleN : (rho ++ es).length ≤ N)
    (hrc : ∀ a ∈ rho, a.Canon) (hec : ∀ a ∈ es, a.Canon)
    (p : Block.Priv) (sc0 : ℕ × Fp2) (rest : List (ℕ × Fp2)) (hs : p.slices = sc0 :: rest)
    (hmin : min p.log (Block.rowLog P p.cm) ≤ lc)
    (hcan : ∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon) :
    Link.claimSem U R lc Q X (Block.buildClaim P p
      (Block.claimPoint p rho) (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero) =
    let x : Fin N → K := Block.xOf U (rho ++ es)
    let m := p.coords.length
    let lsM := min p.log (Block.rowLog P p.cm)
    let off1 := p.maskRow * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
    let off2 := (p.maskRow + 1) * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
    ∑ row : Fin R,
      (((p.slices.map fun sc => (sc.2.toK U * Block.selK n e x) *
          dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row).sum)
        + ((Block.cmK n e x p.extRound * Fp2.one.toK U) * narrowRowC off1 lsM lc R row
           + (Block.cmK n e x p.extRound * Block.fp2U.toK U) * narrowRowC off2 lsM lc R row))
      * ∑ t : Fin (2 ^ lc + Q), X row t *
        (if (t : ℕ) < 2 ^ lc then
          dataKeyColK sc0.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) t
        else 0) := by
  let x : Fin N → K := Block.xOf U (rho ++ es)
  let m := p.coords.length
  let lsM := min p.log (Block.rowLog P p.cm)
  let off1 := p.maskRow * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
  let off2 := (p.maskRow + 1) * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
  let pt := Block.claimPoint p rho
  have hpt_len : pt.length = m := by simp [pt, Block.claimPoint, m]
  have hpt_can : ∀ a ∈ pt, a.Canon := by
    intro a ha
    obtain ⟨c, hc, rfl⟩ := List.mem_map.mp ha
    cases c with
    | rho j => exact Fp2.canon_getD hrc j
    | flip j => exact Fp2.canon_sub _ _ Fp2.canon_one (Fp2.canon_getD hrc j)
    | fixed w => exact hcan _ hc w rfl
  have hxr : ∀ j, Block.xrK n x j = (rho.getD j Fp2.zero).toK U :=
    fun j => Block.xrK_xOf U n rho es hrho hleN j
  have hptK : (fun a => (pt.getD a Fp2.zero).toK U) = Block.ptK U (Block.xrK n x) p.coords := by
    funext a; exact Block.claimPoint_getD_toK U p rho hrc _ hxr a
  have hsel : (Block.oneMinusProd es).toK U = Block.selK n e x :=
    Block.toK_oneMinusProd U hU n e rho es hrho hes hleN hec
  have hcm : (Block.maskCoef es p.extRound).toK U = Block.cmK n e x p.extRound :=
    Block.toK_maskCoef U hU n e rho es hrho hes hleN hec p.extRound
  let z := Block.buildClaim P p pt (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero
  let b0 : Block.ZPart := ⟨sc0.1, p.log, sc0.2.mul (Block.oneMinusProd es), pt⟩
  let bm1 : Block.ZPart := ⟨off1, lsM, (Block.maskCoef es p.extRound).mul Fp2.one, pt.drop (p.log - lsM)⟩
  let bm2 : Block.ZPart := ⟨off2, lsM, (Block.maskCoef es p.extRound).mul Block.fp2U, pt.drop (p.log - lsM)⟩
  let bs : List Block.ZPart :=
    rest.map (fun sc => (⟨sc.1, p.log, sc.2.mul (Block.oneMinusProd es), pt⟩ : Block.ZPart)) ++ [bm1, bm2]
  have hz : z.parts = b0 :: bs := by
    show (Block.buildClaim P p pt (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero).parts = _
    rw [Block.buildClaim_parts, hs]; rfl
  have hcw : claimWeights (toZClaim z) R lc =
      ((bs.map toZPart).foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q R lc).1)
        (zpartWeights (toZPart b0) R lc).1, (zpartWeights (toZPart b0) R lc).2) := by
    unfold toZClaim; rw [hz]; rfl
  unfold Link.claimSem
  refine Finset.sum_congr rfl (fun row _ => ?_)
  have hrw : Link.claimRw U R lc z row =
      (((p.slices.map fun sc => (sc.2.toK U * Block.selK n e x) *
          dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row).sum)
        + ((Block.cmK n e x p.extRound * Fp2.one.toK U) * narrowRowC off1 lsM lc R row
           + (Block.cmK n e x p.extRound * Block.fp2U.toK U) * narrowRowC off2 lsM lc R row)) := by
    unfold Link.claimRw
    rw [hcw]
    dsimp only
    rw [Block.foldZip_toK U R lc row row.isLt (bs.map toZPart) _
          (Link.zpartWeights_length _ R lc) (Fp2.canon_getD (Block.zpartWeights_canon (toZPart b0) R lc) row)]
    have hb0_eq : ((zpartWeights (toZPart b0) R lc).1.getD row Fp2.zero).toK U
        = (sc0.2.toK U * Block.selK n e x) * dataRowK sc0.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row := by
      have h1 := zpart_row_data_toK U hU (toZPart b0) R lc m hpt_len hpt_can (Fp2.canon_mul _ _) row row.isLt
      dsimp only [b0, toZPart] at h1 ⊢
      rw [h1, Fp2.toK_mul U hU, hsel, hptK]
    have hbs_eq : ((bs.map toZPart).map fun q => ((zpartWeights q R lc).1.getD row Fp2.zero).toK U).sum
        = ((rest.map fun sc => (sc.2.toK U * Block.selK n e x) *
              dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row).sum)
          + ((Block.cmK n e x p.extRound * Fp2.one.toK U) * narrowRowC off1 lsM lc R row
             + (Block.cmK n e x p.extRound * Block.fp2U.toK U) * narrowRowC off2 lsM lc R row) := by
      simp only [bs, List.map_append, List.sum_append, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        add_zero, List.map_map]
      congr 1
      · congr 1
        refine List.map_congr_left (fun sc _ => ?_)
        have h1 := zpart_row_data_toK U hU (toZPart (⟨sc.1, p.log, sc.2.mul (Block.oneMinusProd es), pt⟩ : Block.ZPart))
          R lc m hpt_len hpt_can (Fp2.canon_mul _ _) row row.isLt
        dsimp only [toZPart, Function.comp_apply] at h1 ⊢
        rw [h1, Fp2.toK_mul U hU, hsel, hptK]
      · have hm1 := zpart_row_narrow_toK U hU (toZPart bm1) R lc hmin (Fp2.canon_mul _ _) row
        have hm2 := zpart_row_narrow_toK U hU (toZPart bm2) R lc hmin (Fp2.canon_mul _ _) row
        dsimp only [bm1, bm2, toZPart, Function.comp_apply] at hm1 hm2 ⊢
        rw [hm1, hm2, Fp2.toK_mul U hU, Fp2.toK_mul U hU, hcm]
    rw [hb0_eq, hbs_eq, hs, List.map_cons, List.sum_cons, add_assoc]
  have hcol : ∀ t : Fin (2 ^ lc + Q), Link.claimCw U R lc Q z t =
      (if (t : ℕ) < 2 ^ lc then
        dataKeyColK sc0.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) t
      else 0) := by
    intro t
    unfold Link.claimCw Link.cwK
    rw [hcw]
    dsimp only
    by_cases ht : (t : ℕ) < 2 ^ lc
    · rw [ite_eq_left ht, ite_eq_left ht]
      have h1 := zkey_col_data_toK U hU (toZPart b0) R lc m hpt_len hpt_can t ht
      dsimp only [b0, toZPart] at h1 ⊢
      rw [h1, hptK]
    · rw [ite_eq_right ht, ite_eq_right ht]
  rw [hrw]
  refine congrArg (_ * ·) (Finset.sum_congr rfl (fun t _ => by rw [hcol t]))

theorem indDegLE_claimSem_priv (hU : U ^ 2 = algebraMap GF K 7)
    (P : Block.BlockParams) (R lc Q : ℕ) (X : Fin R → Fin (2 ^ lc + Q) → K)
    {N : ℕ} (n e : ℕ) (hN : N = n + e) (p : Block.Priv)
    (hsl : p.slices ≠ [])
    (hmin : min p.log (Block.rowLog P p.cm) ≤ lc)
    (hvars : Block.varsOKb (p.coords.map Block.coordVar) = true)
    (hcan : ∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon) :
    IndDegLE 1 (fun x : Fin N → K =>
      Link.claimSem U R lc Q X (Block.buildClaim P p
        (Block.claimPoint p ((stgWords U hbij x).take n))
        (Block.oneMinusProd ((stgWords U hbij x).drop n))
        (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) Fp2.zero)) := by
  obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
  let m := p.coords.length
  let lsM := min p.log (Block.rowLog P p.cm)
  let off1 := p.maskRow * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
  let off2 := (p.maskRow + 1) * 2 ^ Block.rowLog P p.cm + Block.privC0 P p
  have heq_fn : (fun x : Fin N → K =>
      Link.claimSem U R lc Q X (Block.buildClaim P p
        (Block.claimPoint p ((stgWords U hbij x).take n))
        (Block.oneMinusProd ((stgWords U hbij x).drop n))
        (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) Fp2.zero)) =
    fun x : Fin N → K =>
      ∑ row : Fin R,
        (((p.slices.map fun sc => (sc.2.toK U * Block.selK n e x) *
            dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row).sum)
          + ((Block.cmK n e x p.extRound * Fp2.one.toK U) * narrowRowC off1 lsM lc R row
             + (Block.cmK n e x p.extRound * Block.fp2U.toK U) * narrowRowC off2 lsM lc R row))
        * ∑ t : Fin (2 ^ lc + Q), X row t *
          (if (t : ℕ) < 2 ^ lc then
            dataKeyColK sc0.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) t
          else 0) := by
    funext x
    have hrho : ((stgWords U hbij x).take n).length = n := by simp [stgWords_length, hN]
    have hes : ((stgWords U hbij x).drop n).length = e := by simp [stgWords_length, hN]
    have hleN : ((stgWords U hbij x).take n ++ (stgWords U hbij x).drop n).length ≤ N := by
      rw [List.take_append_drop, stgWords_length]
    have hrc : ∀ a ∈ (stgWords U hbij x).take n, a.Canon :=
      fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_take ha)
    have hec : ∀ a ∈ (stgWords U hbij x).drop n, a.Canon :=
      fun a ha => stgWords_canon U hbij x a (List.mem_of_mem_drop ha)
    have h1 := claimSem_priv_words U hU P R lc Q X (N := N) n e
      ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n) hrho hes hleN hrc hec p sc0 rest hs hmin hcan
    dsimp only at h1
    rw [xOf_take_drop_stgWords U hbij n x] at h1
    exact h1
  rw [heq_fn]
  refine Block.indDegLE_one_of_affAt (fun i => ?_)
  have hfam := Block.ptFam_ptK (N := N) U n p.coords hvars i
  refine Block.AffAt.sum _ (fun row => ?_)
  refine Block.AffAt.mul_or ?_ ?_ ?_
  · refine Block.AffAt.add ?_ (Block.AffAt.add ?_ ?_)
    · refine Block.AffAt.listSum (fun (sc : ℕ × Fp2) (x : Fin N → K) =>
        (sc.2.toK U * Block.selK n e x) * dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row) _
        (fun sc _ => ?_)
      by_cases hi : n ≤ (i : ℕ)
      · refine (Block.AffAt.const_mul (Block.constAt_const i (sc.2.toK U)) (Block.affAt_selK n e i)).mul_const ?_
        unfold dataRowK
        exact Block.ConstAt.ite _ (Block.constAt_const i _)
          (Block.ConstAt.ite _ (Block.ConstAt.ite _
            (Block.constAt_eqFam (min (p.log - lc) m) _ (fun a => Block.constAt_ptK U n p.coords i a (Or.inl hi)))
            (Block.constAt_const i 0)) (Block.constAt_const i _))
      · refine Block.AffAt.const_mul
          ((Block.constAt_const i (sc.2.toK U)).mul (Block.constAt_selK n e i (by omega))) ?_
        unfold dataRowK
        exact Block.AffAt.ite _ (Block.constAt_const i _).affAt
          (Block.AffAt.ite _ (Block.AffAt.ite _
            (Block.affAt_eqFam hfam (min (p.log - lc) m) _) (Block.constAt_const i 0).affAt)
            (Block.constAt_const i _).affAt)
    · exact ((Block.affAt_cmK n e i p.extRound).mul_const (Block.constAt_const i _)).mul_const
        (Block.constAt_const i _)
    · exact ((Block.affAt_cmK n e i p.extRound).mul_const (Block.constAt_const i _)).mul_const
        (Block.constAt_const i _)
  · refine Block.AffAt.sum _ (fun t => Block.AffAt.const_mul (Block.constAt_const i (X row t)) ?_)
    refine Block.AffAt.ite _ ?_ (Block.constAt_const i 0).affAt
    unfold dataKeyColK
    exact Block.AffAt.ite _ (Block.AffAt.ite _ (Block.constAt_const i 1).affAt
      (Block.AffAt.ite _ (Block.affAt_eqFam (hfam.shift _) _ _) (Block.constAt_const i 0).affAt))
      (Block.constAt_const i 0).affAt
  · by_cases hi : n ≤ (i : ℕ)
    · refine Or.inr (Block.ConstAt.sum _ (fun t => (Block.constAt_const i (X row t)).mul ?_))
      refine Block.ConstAt.ite _ ?_ (Block.constAt_const i 0)
      unfold dataKeyColK
      exact Block.ConstAt.ite _ (Block.ConstAt.ite _ (Block.constAt_const i 1)
        (Block.ConstAt.ite _ (Block.constAt_eqFam
          (g := fun x a => Block.ptK U (Block.xrK n x) p.coords ((if lc ≤ p.log then p.log - lc else 0) + a)) _ _
          (fun a => Block.constAt_ptK U n p.coords i _ (Or.inl hi)))
          (Block.constAt_const i 0))) (Block.constAt_const i 0)
    · have hi' : (i : ℕ) < n := by omega
      by_cases hq : lc ≤ p.log ∧ ∃ q, q < min (p.log - lc) m ∧ (p.coords.map Block.coordVar).getD q none = some (i : ℕ)
      · obtain ⟨hlc, q, hq1, hq2⟩ := hq
        refine Or.inr (Block.ConstAt.sum _ (fun t => (Block.constAt_const i (X row t)).mul ?_))
        refine Block.ConstAt.ite _ ?_ (Block.constAt_const i 0)
        unfold dataKeyColK
        refine Block.ConstAt.ite _ (Block.ConstAt.ite _ (Block.constAt_const i 1)
          (Block.ConstAt.ite _ (Block.constAt_eqFam
            (g := fun x a => Block.ptK U (Block.xrK n x) p.coords ((if lc ≤ p.log then p.log - lc else 0) + a)) _ _
            (fun a => ?_)) (Block.constAt_const i 0)))
          (Block.constAt_const i 0)
        have hq_lt : q < p.log - lc := lt_of_lt_of_le hq1 (Nat.min_le_left _ _)
        let av : ℕ := a.val
        have hne_qa : q ≠ (if lc ≤ p.log then p.log - lc else 0) + av := by
          rw [ite_eq_left hlc]; omega
        exact Block.constAt_ptK U n p.coords i _ (Or.inr (Block.varsOK_spec _ hvars q _ i hne_qa hq2))
      · refine Or.inl (Block.ConstAt.add ?_ (Block.ConstAt.add ?_ ?_))
        · refine Block.ConstAt.listSum (fun (sc : ℕ × Fp2) (x : Fin N → K) =>
            (sc.2.toK U * Block.selK n e x) * dataRowK sc.1 p.log lc m (Block.ptK U (Block.xrK n x) p.coords) row) _
            (fun sc _ => ((Block.constAt_const i (sc.2.toK U)).mul (Block.constAt_selK n e i hi')).mul ?_)
          unfold dataRowK
          refine Block.ConstAt.ite _ (Block.constAt_const i _) ?_
          by_cases hlc : lc ≤ p.log
          · simp only [hlc, ↓reduceIte]
            exact Block.ConstAt.ite _ (Block.constAt_eqFam (min (p.log - lc) m) _ (fun a =>
              Block.constAt_ptK U n p.coords i a (Or.inr (fun hv => hq ⟨hlc, a.val, a.isLt, hv⟩))))
              (Block.constAt_const i 0)
          · simp only [hlc, ↓reduceIte]
            exact Block.constAt_const i _
        · exact ((Block.constAt_cmK n e i p.extRound hi').mul (Block.constAt_const i _)).mul
            (Block.constAt_const i _)
        · exact ((Block.constAt_cmK n e i p.extRound hi').mul (Block.constAt_const i _)).mul
            (Block.constAt_const i _)

def StgCsIODeg {L : ℕ} (eLog : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) : Prop :=
  ∀ (v : StgVw L) (P : Block.BlockParams), P.endpointLogN = eLog →
    ∀ {N : ℕ} (n e : ℕ), N = n + e → ∀ (p : Block.Priv),
      (p.cm = .inp ∨ p.cm = .out) → pOk p →
      p.slices ≠ [] →
      Block.varsOKb (p.coords.map Block.coordVar) = true →
      (∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon) →
      IndDegLE 1 (fun x : Fin N → K =>
        csIO v p.cm (Block.buildClaim P p
          (Block.claimPoint p ((stgWords U hbij x).take n))
          (Block.oneMinusProd ((stgWords U hbij x).drop n))
          (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) Fp2.zero))

theorem stgCsIODeg_of_claimSem {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7)
    (eLog : ℕ) (R lcIO Q : Block.Cm → ℕ)
    (X : StgVw L → (cm : Block.Cm) → Fin (R cm) → Fin (2 ^ lcIO cm + Q cm) → K)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K)
    (hcs : ∀ v cm z, (cm = .inp ∨ cm = .out) →
      csIO v cm z = Link.claimSem U (R cm) (lcIO cm) (Q cm) (X v cm) z) :
    StgCsIODeg U hbij eLog (fun p => min p.log eLog ≤ lcIO p.cm) csIO := by
  intro v P heLog N n e hN p hcm hmin hsl hvars hcan
  have heq : (fun x : Fin N → K => csIO v p.cm (Block.buildClaim P p
      (Block.claimPoint p ((stgWords U hbij x).take n))
      (Block.oneMinusProd ((stgWords U hbij x).drop n))
      (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) Fp2.zero)) =
    fun x => Link.claimSem U (R p.cm) (lcIO p.cm) (Q p.cm) (X v p.cm)
      (Block.buildClaim P p (Block.claimPoint p ((stgWords U hbij x).take n))
        (Block.oneMinusProd ((stgWords U hbij x).drop n))
        (Block.maskCoef ((stgWords U hbij x).drop n) p.extRound) Fp2.zero) := by
    funext x; exact hcs v p.cm _ hcm
  rw [heq]
  have hmin' : min p.log (Block.rowLog P p.cm) ≤ lcIO p.cm := by
    rcases hcm with h1 | h1 <;> simpa [Block.rowLog, h1, heLog] using hmin
  exact indDegLE_claimSem_priv U hbij hU P (R p.cm) (lcIO p.cm) (Q p.cm) (X v p.cm) n e hN p hsl hmin' hvars hcan

omit [Field K] [Algebra GF K] in
def TabPrivOK (pOk : Block.Priv → Prop) (t : Block.Tab) : Prop :=
  ∀ p, t = .priv p →
    ((p.cm = .inp ∨ p.cm = .out) → pOk p) ∧
    p.slices ≠ [] ∧ Block.varsOKb (p.coords.map Block.coordVar) = true
      ∧ (∀ c ∈ p.coords, ∀ w, c = Block.Coord.fixed w → w.Canon)

theorem stgTabK_indDeg {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P : Block.BlockParams) (lc h Q eC rA rH iA iH : ℕ)
    (pOk : Block.Priv → Prop) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    {N : ℕ} (n e : ℕ) (hN : N = n + e) (tab : Block.Tab)
    (hok : TabPrivOK pOk tab) :
    IndDegLE 1 (fun x : Fin N → K =>
      stgTabK U hbij P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x tab) := by
  cases tab with
  | eq pt s =>
    unfold stgTabK stgTabW
    by_cases hs : s + pt.length ≤ n
    · simp only [hs, ↓reduceIte]
      exact Block.indDegLE_one_of_affAt (Block.affAt_eqTab U n e pt s)
    · simp only [hs, ↓reduceIte]
      exact IndDegLE.const 0
  | pub pv =>
    unfold stgTabK stgTabW
    by_cases hpv : pv.length = 2 ^ n
    · simp only [hpv, ↓reduceIte]
      exact Block.indDegLE_one_of_affAt (Block.affAt_pubTab n e _)
    · simp only [hpv, ↓reduceIte]
      exact IndDegLE.const 0
  | priv p =>
    obtain ⟨hpok, hsl, hvars, hcan⟩ := hok p rfl
    unfold stgTabK stgTabW stgCsv
    cases hcm : p.cm with
    | a =>
      have hmin : min p.log (Block.rowLog P p.cm) ≤ lc := by
        rw [hcm]; exact (Nat.min_le_right p.log P.logCols).trans hlc
      simpa [hcm] using indDegLE_claimSem_priv U hbij hU P rA lc Q _ n e hN p hsl hmin hvars hcan
    | h =>
      have hmin : min p.log (Block.rowLog P p.cm) ≤ lc := by
        rw [hcm]; exact (Nat.min_le_right p.log P.logCols).trans hlc
      simpa [hcm] using indDegLE_claimSem_priv U hbij hU P rH lc Q _ n e hN p hsl hmin hvars hcan
    | inp =>
      have hd := hIOd v P rfl n e hN p (Or.inl hcm) (hpok (Or.inl hcm)) hsl hvars hcan
      simpa [hcm] using hd
    | out =>
      have hd := hIOd v P rfl n e hN p (Or.inr hcm) (hpok (Or.inr hcm)) hsl hvars hcan
      simpa [hcm] using hd

theorem tabsK_getD_indDeg {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P : Block.BlockParams) (lc h Q eC rA rH iA iH : ℕ)
    (pOk : Block.Priv → Prop) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    {N : ℕ} (n e : ℕ) (hN : N = n + e) (tabs : List Block.Tab)
    (hok : ∀ t ∈ tabs, TabPrivOK pOk t) (idx : ℕ) :
    IndDegLE 1 (fun x : Fin N → K =>
      (tabs.map (stgTabK U hbij P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD idx 0) := by
  have heq : (fun x : Fin N → K =>
      (tabs.map (stgTabK U hbij P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD idx 0) =
    fun x => ((tabs[idx]?).map (stgTabK U hbij P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) n e x)).getD 0 := by
    funext x; rw [List.getD_eq_getElem?_getD, List.getElem?_map]
  rw [heq]
  cases ht : tabs[idx]? with
  | none => exact IndDegLE.const 0
  | some t =>
    exact stgTabK_indDeg U hbij hU tag h64 P lc h Q eC rA rH iA iH pOk csIO v hlc hIOd n e hN t
      (hok t (List.mem_of_getElem? ht))

open Classical in
theorem stgSpT_eval_and_deg {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (ds : List (List Fp2)) (j n e sdeg : ℕ)
    (hsh : Block.slotShape P j = (n, e, sdeg))
    (tabs : List Block.Tab) (poly : List Fp2 → Fp2) (hosted : List (ℕ × Fp2))
    (hdef : P.define j ⟨bga.1, bga.2.1, bga.2.2, ds.take j⟩ (ds.getD j []) = .ok ⟨tabs, poly, hosted⟩)
    (hok : ∀ t ∈ tabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ tabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyK : (ℕ → K) → K)
    (hpK : ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (poly vals).toK U = polyK (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDeg : ∀ g : ℕ → (Fin (stgN P0 j) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyK (fun idx => g idx x))) :
    let cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v
    stgSpT U hbij P0 P cs bga ds j =
      (fun x => if tabsFit n tabs then polyK (fun idx => (tabs.map (stgTabK U hbij P cs n e x)).getD idx 0) else 0)
    ∧ IndDegLE (Block.slotShape P0 j).2.2 (stgSpT U hbij P0 P cs bga ds j) := by
  intro cs
  have hsh0 : Block.slotShape P0 j = (n, e, sdeg) := (stg_slotShape hP j).trans hsh
  have hN : stgN P0 j = n + e := by unfold stgN; rw [hsh0]
  have hnP : (Block.slotShape P j).1 = n := by rw [hsh]
  have heq : stgSpT U hbij P0 P cs bga ds j =
      fun x => if tabsFit n tabs then polyK (fun idx => (tabs.map (stgTabK U hbij P cs n e x)).getD idx 0) else 0 := by
    funext x
    unfold stgSpT stgPolyT
    rw [histSeen_stgSnD, drSeen_stgSnD, hdef, hnP]
    dsimp only
    by_cases hfit : tabsFit n tabs
    · obtain ⟨vals, hv, hvc, hvm⟩ := tabVals_stgTabK U hbij hU P cs n e hN x tabs hfit hcan
      rw [hv]; dsimp only
      rw [ite_eq_left hfit, hpK vals hvc, hvm]
    · have hrho : ((stgWords U hbij x).take n).length = n := by simp [stgWords_length, hN]
      obtain ⟨msg, hmsg⟩ := tabVals_err_of_not_fit hrho
        (Block.oneMinusProd ((stgWords U hbij x).drop n)) tabs
        (stgPrivVals U hbij P cs ((stgWords U hbij x).take n) ((stgWords U hbij x).drop n) tabs) 0 hfit
      rw [hmsg]; dsimp only
      rw [ite_eq_right hfit]
  refine ⟨heq, ?_⟩
  rw [heq, hsh0]
  by_cases hfit : tabsFit n tabs
  · simp only [hfit, ↓reduceIte]
    exact hpDeg _ (tabsK_getD_indDeg U hbij hU tag h64 P lc h Q eC rA rH iA iH pOk csIO v hlc hIOd n e hN tabs hok)
  · simp only [hfit, ↓reduceIte]
    exact IndDegLE.const 0

open Classical in
theorem offZero_standalone_draw {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg m d : ℕ)
    (hhd : hd.length = k) (hm : m ≤ P0.draws k) (hmn : m ≤ n)
    (hkind : P.kind k = .standalone) (hsh : Block.slotShape P k = (n, e, sdeg))
    (Z : Finset (Fin (P0.draws k)))
    (restTabs : List Block.Tab) (polyOf : (Fin (P0.draws k) → K) → List Fp2 → Fp2)
    (hdef_ok : ∀ y, (∀ i ∈ Z, y i ≠ 0) →
      P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
        = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, polyOf y, []⟩)
    (hdef_err : ∀ y, (∃ i ∈ Z, y i = 0) →
      ∃ msg, P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y) = .error msg)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyYK : (Fin (P0.draws k) → K) → (ℕ → K) → K)
    (hpK : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (polyOf y vals).toK U = polyYK y (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDegX : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyYK y (fun idx => g idx x)))
    (hpDegY : ∀ (x : Fin (stgN P0 k) → K) (rt : ℕ → K),
      IndDegLE d (fun y => polyYK y (fun idx => match idx with
        | 0 => eqDrawK m n e hm y x
        | j + 1 => rt j))) :
    let cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v
    ∃ Pp : (Fin (P0.draws k) → K) → K,
      IndDegLE d Pp ∧ OffZero Z (fun y => stgΦB U hbij P0 P cs bga hd k (stgWords U hbij y)) Pp := by
  intro cs
  let Pp : (Fin (P0.draws k) → K) → K := fun y =>
    if tabsFit n restTabs then
      cubeSum (fun x : Fin (stgN P0 k) → K =>
        polyYK y (fun idx => match idx with
          | 0 => eqDrawK m n e hm y x
          | j + 1 => (restTabs.map (stgTabK U hbij P cs n e x)).getD j 0))
    else 0
  refine ⟨Pp, ?_, fun y => ⟨fun hZ => ?_, fun ⟨i, hi, hy0⟩ => ?_⟩⟩
  · unfold Pp
    by_cases hfit : tabsFit n restTabs
    · simp only [hfit, ↓reduceIte]
      exact indDegLE_cubeSum _ (fun x => hpDegY x _)
    · simp only [hfit, ↓reduceIte]
      exact IndDegLE.const 0
  · have hdef := hdef_ok y hZ
    have htake : (hd ++ [stgWords U hbij y]).take k = hd := by
      rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
    have hgetD : (hd ++ [stgWords U hbij y]).getD k [] = stgWords U hbij y := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
      simp [hhd]
    have hdef' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [stgWords U hbij y]).take k⟩
        ((hd ++ [stgWords U hbij y]).getD k [])
        = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, polyOf y, []⟩ := by
      rw [htake, hgetD]; exact hdef
    have hok' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), TabPrivOK pOk t := by
      intro t ht; rcases List.mem_cons.mp ht with rfl | ht
      · intro p hp; cases hp
      · exact hok t ht
    have hcan' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
      intro t ht pt s he; rcases List.mem_cons.mp ht with rfl | ht
      · cases he; exact fun a ha => stgWords_canon U hbij y a (List.mem_of_mem_take ha)
      · exact hcan t ht pt s he
    obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 P hP lc h Q eC rA rH iA iH pOk csIO v
      hlc hIOd bga (hd ++ [stgWords U hbij y]) k n e sdeg hsh _ _ _ hdef' hok' hcan' (polyYK y)
      (hpK y hZ) (hpDegX y hZ)
    have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) k)
        ∧ ∀ hk ∈ ([] : List (ℕ × Fp2)), IndDegLE (Block.slotShape P0 hk.1).2.2
            (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hk.1) :=
      ⟨hdegSp, fun _ hm => absurd hm List.not_mem_nil⟩
    dsimp only
    unfold stgΦB
    rw [hdef]
    dsimp only
    rw [ite_eq_left hguard, hkind, heqSp]
    have hfit_iff : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) ↔ tabsFit n restTabs := by
      constructor
      · exact fun hf t ht => hf t (List.mem_cons_of_mem _ ht)
      · intro hf t ht
        rcases List.mem_cons.mp ht with rfl | ht
        · show 0 + ((stgWords U hbij y).take m).length ≤ n
          rw [List.length_take, stgWords_length]; omega
        · exact hf t ht
    unfold Pp
    by_cases hfit : tabsFit n restTabs
    · have hfit' : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := hfit_iff.mpr hfit
      simp only [hfit, hfit', ↓reduceIte]
      congr 1; funext x; congr 1; funext idx
      cases idx with
      | zero =>
        exact stgTabK_eq_draw U hbij P cs m n e hm hmn y x
      | succ j =>
        rfl
    · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
      simp only [hfit, hfit', ↓reduceIte]
      unfold cubeSum; simp
  · obtain ⟨msg, hmsg⟩ := hdef_err y ⟨i, hi, hy0⟩
    dsimp only
    unfold stgΦB
    rw [hmsg]

open Classical in
/-- **`OffZero` for a standalone slot under `stgΦBC`** (finding L63-5: slot `k` read at `StageV.atLog P (elog k)`). -/
theorem offZero_standalone_drawC {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k n e sdeg m d : ℕ)
    (hIOd : StgCsIODeg U hbij (elog k) pOk csIO)
    (hhd : hd.length = k) (hm : m ≤ P0.draws k) (hmn : m ≤ n)
    (hkind : P.kind k = .standalone) (hsh : Block.slotShape P k = (n, e, sdeg))
    (Z : Finset (Fin (P0.draws k)))
    (restTabs : List Block.Tab) (polyOf : (Fin (P0.draws k) → K) → List Fp2 → Fp2)
    (hdef_ok : ∀ y, (∀ i ∈ Z, y i ≠ 0) →
      P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
        = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, polyOf y, []⟩)
    (hdef_err : ∀ y, (∃ i ∈ Z, y i = 0) →
      ∃ msg, P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y) = .error msg)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyYK : (Fin (P0.draws k) → K) → (ℕ → K) → K)
    (hpK : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (polyOf y vals).toK U = polyYK y (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDegX : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyYK y (fun idx => g idx x)))
    (hpDegY : ∀ (x : Fin (stgN P0 k) → K) (rt : ℕ → K),
      IndDegLE d (fun y => polyYK y (fun idx => match idx with
        | 0 => eqDrawK m n e hm y x
        | j + 1 => rt j))) :
    let cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v
    ∃ Pp : (Fin (P0.draws k) → K) → K,
      IndDegLE d Pp ∧ OffZero Z (fun y => stgΦBC U hbij P0 P elog cs bga hd k (stgWords U hbij y)) Pp := by
  intro cs
  obtain ⟨Pp, hPdeg, ho⟩ := offZero_standalone_draw U hbij hU tag h64 P0 (StageV.atLog P (elog k)) hP
    lc h Q eC rA rH iA iH pOk csIO v hlc hIOd bga hd k n e sdeg m d hhd hm hmn hkind hsh Z restTabs polyOf
    hdef_ok hdef_err hok hcan polyYK hpK hpDegX hpDegY
  refine ⟨Pp, hPdeg, fun y => ?_⟩
  have heq : stgΦBC U hbij P0 P elog cs bga hd k (stgWords U hbij y)
      = stgΦB U hbij P0 (StageV.atLog P (elog k)) cs bga hd k (stgWords U hbij y) := by
    by_cases hZ : ∀ i ∈ Z, y i ≠ 0
    · have hd1 := hdef_ok y hZ
      unfold stgΦBC stgΦB
      rw [hd1]
      dsimp only
      have hsp : stgSpTC U hbij P0 P elog cs bga (hd ++ [stgWords U hbij y]) k
          = stgSpT U hbij P0 (StageV.atLog P (elog k)) cs bga (hd ++ [stgWords U hbij y]) k := rfl
      rw [hkind]
      simp only [List.not_mem_nil, IsEmpty.forall_iff, implies_true, and_true, hsp]
    · have hZ' : ∃ i ∈ Z, y i = 0 := by
        simp only [not_forall, not_not] at hZ
        obtain ⟨i, hi, hy⟩ := hZ
        exact ⟨i, hi, hy⟩
      obtain ⟨msg, hmsg⟩ := hdef_err y hZ'
      unfold stgΦBC stgΦB
      rw [hmsg]
  dsimp only
  rw [heq]
  exact ho y

open Classical in
theorem offZero_host_draw {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 P : Block.BlockParams) (hP : StgSame P0 P)
    (lc h Q eC rA rH iA iH : ℕ) (pOk : Block.Priv → Prop)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : P.logCols ≤ lc) (hIOd : StgCsIODeg U hbij P.endpointLogN pOk csIO)
    (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2)) (k hSlot nuIdx n e sdeg m d : ℕ)
    (hhd : hd.length = k) (hhSlot : hSlot < k) (hnu : nuIdx < P0.draws k)
    (hd1 : 1 ≤ d) (hm : m ≤ P0.draws k) (hmn : m ≤ n)
    (hkind : P.kind k = .host) (hsh : Block.slotShape P k = (n, e, sdeg))
    (hdegH : IndDegLE (Block.slotShape P0 hSlot).2.2
      (stgSpT U hbij P0 P (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) bga hd hSlot))
    (Z : Finset (Fin (P0.draws k)))
    (restTabs : List Block.Tab) (polyOf : (Fin (P0.draws k) → K) → List Fp2 → Fp2)
    (hdef_ok : ∀ y, (∀ i ∈ Z, y i ≠ 0) →
      P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y)
        = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, polyOf y,
            [(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)]⟩)
    (hdef_err : ∀ y, (∃ i ∈ Z, y i = 0) →
      ∃ msg, P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ (stgWords U hbij y) = .error msg)
    (hok : ∀ t ∈ restTabs, TabPrivOK pOk t)
    (hcan : ∀ t ∈ restTabs, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon)
    (polyYK : (Fin (P0.draws k) → K) → (ℕ → K) → K)
    (hpK : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ vals : List Fp2, (∀ a ∈ vals, a.Canon) →
      (polyOf y vals).toK U = polyYK y (fun idx => (vals.map (Fp2.toK U)).getD idx 0))
    (hpDegX : ∀ y, (∀ i ∈ Z, y i ≠ 0) → ∀ g : ℕ → (Fin (stgN P0 k) → K) → K,
      (∀ idx, IndDegLE 1 (g idx)) → IndDegLE sdeg (fun x => polyYK y (fun idx => g idx x)))
    (hpDegY : ∀ (x : Fin (stgN P0 k) → K) (rt : ℕ → K),
      IndDegLE d (fun y => polyYK y (fun idx => match idx with
        | 0 => eqDrawK m n e hm y x
        | j + 1 => rt j))) :
    let cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v
    ∃ Pp : (Fin (P0.draws k) → K) → K,
      IndDegLE d Pp ∧ OffZero Z (fun y => stgΦB U hbij P0 P cs bga hd k (stgWords U hbij y)) Pp := by
  intro cs
  let cHosted : K := cubeSum (stgSpT U hbij P0 P cs bga hd hSlot)
  let Pp : (Fin (P0.draws k) → K) → K := fun y =>
    (if tabsFit n restTabs then
      cubeSum (fun x : Fin (stgN P0 k) → K =>
        polyYK y (fun idx => match idx with
          | 0 => eqDrawK m n e hm y x
          | j + 1 => (restTabs.map (stgTabK U hbij P cs n e x)).getD j 0))
    else 0) - y ⟨nuIdx, hnu⟩ * cHosted
  refine ⟨Pp, ?_, fun y => ⟨fun hZ => ?_, fun ⟨i, hi, hy0⟩ => ?_⟩⟩
  · unfold Pp
    refine IndDegLE.sub ?_ ?_
    · by_cases hfit : tabsFit n restTabs
      · simp only [hfit, ↓reduceIte]
        exact indDegLE_cubeSum _ (fun x => hpDegY x _)
      · simp only [hfit, ↓reduceIte]
        exact IndDegLE.const 0
    · have hlin : IndDegLE 1 (fun y : Fin (P0.draws k) → K => y ⟨nuIdx, hnu⟩ * cHosted) :=
        IndDegLE_mulc (indDegLE_coord (K := K) ⟨nuIdx, hnu⟩) cHosted
      exact IndDegLE.mono hlin hd1
  · have hdef := hdef_ok y hZ
    have htake : (hd ++ [stgWords U hbij y]).take k = hd := by
      rw [List.take_append_of_le_length (by omega), List.take_of_length_le (by omega)]
    have hgetD : (hd ++ [stgWords U hbij y]).getD k [] = stgWords U hbij y := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega)]
      simp [hhd]
    have hdef' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (hd ++ [stgWords U hbij y]).take k⟩
        ((hd ++ [stgWords U hbij y]).getD k [])
        = .ok ⟨.eq ((stgWords U hbij y).take m) 0 :: restTabs, polyOf y,
            [(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)]⟩ := by
      rw [htake, hgetD]; exact hdef
    have hok' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), TabPrivOK pOk t := by
      intro t ht; rcases List.mem_cons.mp ht with rfl | ht
      · intro p hp; cases hp
      · exact hok t ht
    have hcan' : ∀ t ∈ (.eq ((stgWords U hbij y).take m) 0 :: restTabs), ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
      intro t ht pt s he; rcases List.mem_cons.mp ht with rfl | ht
      · cases he; exact fun a ha => stgWords_canon U hbij y a (List.mem_of_mem_take ha)
      · exact hcan t ht pt s he
    obtain ⟨heqSp, hdegSp⟩ := stgSpT_eval_and_deg U hbij hU tag h64 P0 P hP lc h Q eC rA rH iA iH pOk csIO v
      hlc hIOd bga (hd ++ [stgWords U hbij y]) k n e sdeg hsh _ _ _ hdef' hok' hcan' (polyYK y)
      (hpK y hZ) (hpDegX y hZ)
    have hSpH : stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hSlot
        = stgSpT U hbij P0 P cs bga hd hSlot :=
      stgSpT_take U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hd hSlot
        (List.take_append_of_le_length (by omega))
    have hguard : IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) k)
        ∧ ∀ hk ∈ ([(hSlot, (stgWords U hbij y).getD nuIdx Fp2.zero)] : List (ℕ × Fp2)),
            IndDegLE (Block.slotShape P0 hk.1).2.2
              (stgSpT U hbij P0 P cs bga (hd ++ [stgWords U hbij y]) hk.1) := by
      refine ⟨hdegSp, fun hk hmem => ?_⟩
      rw [List.mem_singleton] at hmem; subst hmem
      dsimp only
      rw [hSpH]; exact hdegH
    dsimp only
    unfold stgΦB
    rw [hdef]
    dsimp only
    rw [ite_eq_left hguard, hkind, heqSp]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
      hSpH, stgWords_getD_toK U hbij y nuIdx hnu]
    have hfit_iff : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) ↔ tabsFit n restTabs := by
      constructor
      · exact fun hf t ht => hf t (List.mem_cons_of_mem _ ht)
      · intro hf t ht
        rcases List.mem_cons.mp ht with rfl | ht
        · show 0 + ((stgWords U hbij y).take m).length ≤ n
          rw [List.length_take, stgWords_length]; omega
        · exact hf t ht
    unfold Pp cHosted
    congr 1
    by_cases hfit : tabsFit n restTabs
    · have hfit' : tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := hfit_iff.mpr hfit
      simp only [hfit, hfit', ↓reduceIte]
      congr 1; funext x; congr 1; funext idx
      cases idx with
      | zero =>
        exact stgTabK_eq_draw U hbij P cs m n e hm hmn y x
      | succ j =>
        rfl
    · have hfit' : ¬ tabsFit n (.eq ((stgWords U hbij y).take m) 0 :: restTabs) := fun hf => hfit (hfit_iff.mp hf)
      simp only [hfit, hfit', ↓reduceIte]
      unfold cubeSum; simp
  · obtain ⟨msg, hmsg⟩ := hdef_err y ⟨i, hi, hy0⟩
    dsimp only
    unfold stgΦB
    rw [hmsg]

end TabAndClaim

end ZK60.ProtocolClassify
