/-
D63 lane L47 (2026-11-10), part 5 (fork B): **every logical lookup of the W16R2 rung block is an entry of the code's
lookup list** (lane L36's `hcov`, PROVED).

* **`cover_xtW`**: every field of `W16Lookups` (`la`, `lm`, `dW`, `dR`, `qW`, `qR`, `kW`, `kR`, `sB`, `sR`, `sExp`, `fR`,
  `fAct`) asks, at every position, a tuple that IS an entry of `AlkW` (read on data whose `A` planes are the extracted
  ones), on a base-valued `A` matrix at the rung's precision (`RungS`) and row log `14`;
* **`hcov_w16`**: lane L36's `hcov` in the form of L44's `block_knowledge_host_w16r2_rung_helper`, for `AlkW` on the data
  the `A` cut fixes (`dofA`): on every outcome, every logical query of the extracted planes `xtW` is an entry of the list.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookCov

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF tagW tagExp tagAct rangeQuery expQuery actQuery)
open ZK60.Layout

section Cover

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) {L : ℕ}
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (Dof : List (QB L × Dig) → CmData K P) (cut : List (QB L × Dig)) (D : CmData K P)
  (hD : ∀ off log b, aPl U P (Dof cut) off log b = aPl U P D off log b)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hD hX in
/-- An isqrt limb of `Dom::L` (a 32-entry sub-slice) is the code's 14-bit `Dom::L` lookup at the same entry. -/
theorem covLimb (hlc : P.logCols = 14) (j : ℕ) (hj : j < 2) (q off : ℕ) (hoff : aOff cfgRungW16 q = off)
    (hl : (lookupsN cfgRungW16 LkDom.L.dom).getD j ⟨[], 0, 0⟩ = ⟨[(q, 1)], 0, 8⟩) (hoffr : off = 98304 ∨ off = 114688)
    (i k : Fin 3) (t : CtW) :
    ∃ l, AlkW U P Pb Lay B Dof cut l
      = tupK (rangeQuery (tagW 8) (piB K (aPl U P D (off + 32 * (3 * (i : ℕ) + k)) 5 t))) := by
  have hr0 : rowLog P .a = 14 := hlc
  have hi := i.isLt
  have hk := k.isLt
  have ht := msbIndex_lt 5 t
  have h32 : (2 : ℕ) ^ 5 = 32 := by norm_num
  have h14 : (2 : ℕ) ^ 14 = 16384 := by norm_num
  have hlt : 32 * (3 * (i : ℕ) + k) + msbIndex 5 t < 2 ^ 14 := by rw [h14]; rw [h32] at ht; omega
  have hLlen : (lookupsN cfgRungW16 LkDom.L.dom).length = 2 := by decide +kernel
  refine cov_gen U P Pb Lay B Dof cut D hD .L j (by omega) q off hoff 1 0 8 hl
    (msbBits 14 (32 * (3 * (i : ℕ) + k) + msbIndex 5 t)) _ ?_
  show algebraMap GF K (piB K (aPl U P D (off + 32 * (3 * (i : ℕ) + k)) 5 t))
    = ((1 : ℤ) : K) * aPl U P D off 14 (msbBits 14 (32 * (3 * (i : ℕ) + k) + msbIndex 5 t)) + ((0 : ℤ) : K)
  rw [aPl_alg U P D hX]
  rw [aPl_flat U P D (off + 32 * (3 * (i : ℕ) + k)) 5 off 14 t _
    (by rw [hr0, h14, h32]; rcases hoffr with rfl | rfl <;> omega)
    (by rw [hr0, h14]; rcases hoffr with rfl | rfl <;> omega)
    (by rw [hr0, h14]; rcases hoffr with rfl | rfl <;> omega)
    (by rw [hr0, h14, msbIndex_msbBits 14 _ hlt]; rcases hoffr with rfl | rfl <;> omega)]
  push_cast
  ring

include hD hX in
/-- **Every logical lookup of the extracted planes is an entry of the list.** -/
theorem cover_xtW (hS : RungS S) (hlc : P.logCols = 14) :
    W16LookupsG (fun u => ∃ l, AlkW U P Pb Lay B Dof cut l = tupK u) Pb Lay B (xtW U P D) where
  la t i k := covLimb U P Pb Lay B Dof cut D hD hX hlc 0 (by norm_num) 6 98304 rfl rfl (Or.inl rfl) i k
    (Lay.tok.emb t)
  lm t i k := covLimb U P Pb Lay B Dof cut D hD hX hlc 1 (by norm_num) 7 114688 rfl rfl (Or.inr rfl) i k
    (Lay.tok.emb t)
  dW p w hw := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact covC U P Pb Lay B Dof cut D hD hX .D 0 (by decide +kernel) 8 131072 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 1 (by decide +kernel) 9 147456 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 6 (by decide +kernel) 14 229376 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 9 (by decide +kernel) 17 278528 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 10 (by decide +kernel) 18 294912 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 15 (by decide +kernel) 23 376832 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .D 18 (by decide +kernel) 26 425984 rfl 32768 16 rfl
        (Fin.append (Lay.dPos p).1 (Lay.dPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
  dR p :=
    ⟨remLk_two 24 8 (by norm_num) rfl _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 2 (by decide +kernel) 10 163840 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 3 (by decide +kernel) 11 180224 rfl 8 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
      remLk_two 24 8 (by norm_num) rfl _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 4 (by decide +kernel) 12 196608 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 5 (by decide +kernel) 13 212992 rfl 8 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
      remLk_two 24 8 (by norm_num) rfl _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 11 (by decide +kernel) 19 311296 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 12 (by decide +kernel) 20 327680 rfl 8 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
      remLk_two 24 8 (by norm_num) rfl _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 13 (by decide +kernel) 21 344064 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 14 (by decide +kernel) 22 360448 rfl 8 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
      remLk_two S.sao 5 (by rw [hS.sao]; norm_num) (by rw [hS.sao]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 7 (by decide +kernel) 15 245760 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 8 (by decide +kernel) 16 262144 rfl 5 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2)),
      remLk_two S.sdown 4 (by rw [hS.sdown]; norm_num) (by rw [hS.sdown]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .D 16 (by decide +kernel) 24 393216 rfl 16 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .D 17 (by decide +kernel) 25 409600 rfl 4 rfl
          (Fin.append (Lay.dPos p).1 (Lay.dPos p).2))⟩
  qW p w hw := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl
    · exact covC U P Pb Lay B Dof cut D hD hX .Q 0 (by decide +kernel) 27 442368 rfl 32768 16 rfl
        (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
        32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .Q 2 (by decide +kernel) 29 507904 rfl 32768 16 rfl
        (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
        32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .Q 4 (by decide +kernel) 31 573440 rfl 32768 16 rfl
        (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))
        32768 (by simp only [map_ofNat, Int.cast_ofNat])
  qR p :=
    ⟨remLk_one S.sq (by rw [hS.sq]; norm_num) _ _ (by
        rw [hS.sq]
        exact covR U P Pb Lay B Dof cut D hD hX .Q 1 (by decide +kernel) 28 475136 rfl 15 rfl
          (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))),
      remLk_one 7 (by norm_num) _ _
        (covR U P Pb Lay B Dof cut D hD hX .Q 3 (by decide +kernel) 30 540672 rfl 7 rfl
          (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2))),
      remLk_one S.spv (by rw [hS.spv]; norm_num) _ _ (by
        rw [hS.spv]
        exact covR U P Pb Lay B Dof cut D hD hX .Q 5 (by decide +kernel) 32 606208 rfl 12 rfl
          (Fin.append (Lay.qPos p).1 (Fin.append (Fin.append (Lay.qPos p).2.1.1 (Lay.qPos p).2.1.2) (Lay.qPos p).2.2)))⟩
  kW p w hw := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl
    · exact covC U P Pb Lay B Dof cut D hD hX .Kv 0 (by decide +kernel) 33 638976 rfl 32768 16 rfl
        (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .Kv 2 (by decide +kernel) 35 671744 rfl 32768 16 rfl
        (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
    · exact covC U P Pb Lay B Dof cut D hD hX .Kv 4 (by decide +kernel) 37 704512 rfl 32768 16 rfl
        (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)) 32768 (by simp only [map_ofNat, Int.cast_ofNat])
  kR p :=
    ⟨remLk_one S.sk (by rw [hS.sk]; norm_num) _ _ (by
        rw [hS.sk]
        exact covR U P Pb Lay B Dof cut D hD hX .Kv 1 (by decide +kernel) 34 655360 rfl 15 rfl
          (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))),
      remLk_one S.sv (by rw [hS.sv]) _ _ (by
        rw [hS.sv]
        exact covR U P Pb Lay B Dof cut D hD hX .Kv 3 (by decide +kernel) 36 688128 rfl 16 rfl
          (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2))),
      remLk_one 7 (by norm_num) _ _
        (covR U P Pb Lay B Dof cut D hD hX .Kv 5 (by decide +kernel) 38 720896 rfl 7 rfl
          (Fin.append (Lay.kPos p).1 (Fin.append (Lay.kPos p).2.1 (Lay.kPos p).2.2)))⟩
  sB p :=
    ⟨covC U P Pb Lay B Dof cut D hD hX .S 0 (by decide +kernel) 39 737280 rfl 127 8 rfl
        (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
        127 (by simp only [map_ofNat, Int.cast_ofNat]),
      covN U P Pb Lay B Dof cut D hD hX .S 1 (by decide +kernel) 39 737280 rfl 127 8 rfl
        (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
        127 (by simp only [map_ofNat, Int.cast_ofNat])⟩
  sR p :=
    ⟨remLk_two S.ss 2 (by rw [hS.ss]; norm_num) (by rw [hS.ss]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .S 2 (by decide +kernel) 40 753664 rfl 16 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))
        (covR U P Pb Lay B Dof cut D hD hX .S 3 (by decide +kernel) 41 770048 rfl 2 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))),
      by
        rw [hS.fp]
        exact covR U P Pb Lay B Dof cut D hD hX .S 4 (by decide +kernel) 44 819200 rfl 13 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)),
      remLk_two S.wrho 1 (by rw [hS.wrho]; norm_num) (by rw [hS.wrho]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .S 5 (by decide +kernel) 45 835584 rfl 16 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))
        (covR U P Pb Lay B Dof cut D hD hX .S 6 (by decide +kernel) 46 851968 rfl 1 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))),
      remLk_two S.wrho 1 (by rw [hS.wrho]; norm_num) (by rw [hS.wrho]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .S 7 (by decide +kernel) 47 868352 rfl 16 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))
        (covR U P Pb Lay B Dof cut D hD hX .S 8 (by decide +kernel) 48 884736 rfl 1 rfl
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))⟩
  sExp p := by
    obtain ⟨l, hl⟩ := exists_exp U P Pb Lay B Dof cut
      (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
    refine ⟨l, ?_⟩
    rw [hl, expTupW_congr U P (Dof cut) D hD]
    have hs := splitS_append (Lay.sPos p)
    have hh : Szc.hd9 (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2)
        (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))
        = Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Lay.sPos p).2.1 := by
      rw [← Szc.append_splitS_hd, hs]
    unfold expTupW
    rw [hs, hh]
    refine Tup.ext' ?_ ?_ ?_ ?_
    · show _ = algebraMap GF K (piB K (aPl U P D 65536 9
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Lay.sPos p).2.1))
        - B.mask (Lay.sPos p) * (piB K (aPl U P D 737280 14
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2)))
          + 127) + 127)
      simp only [map_add, map_sub, map_mul, map_ofNat, aPl_alg U P D hX]
      ring
    · exact (map_natCast (algebraMap GF K) tagExp).symm
    · show _ = algebraMap GF K (piB K (aPl U P D 802816 14
          (Fin.append (Fin.append (Lay.sPos p).1.1 (Lay.sPos p).1.2) (Fin.append (Lay.sPos p).2.1 (Lay.sPos p).2.2))))
      rw [aPl_alg U P D hX]
    · show _ = algebraMap GF K 0
      rw [map_zero]
  fR p :=
    ⟨remLk_two S.sgate 3 (by rw [hS.sgate]; norm_num) (by rw [hS.sgate]) _ _
        (covR U P Pb Lay B Dof cut D hD hX .F 0 (by decide +kernel) 50 933888 rfl 16 rfl
          (Fin.append (Lay.fPos p).1 (Lay.fPos p).2))
        (covR U P Pb Lay B Dof cut D hD hX .F 1 (by decide +kernel) 51 966656 rfl 3 rfl
          (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)),
      covC U P Pb Lay B Dof cut D hD hX .F 2 (by decide +kernel) 53 1032192 rfl 32768 16 rfl
        (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) 32768 (by simp only [map_ofNat, Int.cast_ofNat]),
      remLk_one S.sup (by rw [hS.sup]; norm_num) _ _ (by
        rw [hS.sup]
        exact covR U P Pb Lay B Dof cut D hD hX .F 3 (by decide +kernel) 54 1064960 rfl 12 rfl
          (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)),
      cov_two U P Pb Lay B Dof cut D hD .F 4 (by decide +kernel) 55 1097728 56 1130496 rfl rfl 1 (-65536) 0 16 rfl
        (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) _ (by
          show algebraMap GF K (piB K (aPl U P D 1097728 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2))
            - 2 ^ 16 * piB K (aPl U P D 1130496 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)))
            = ((1 : ℤ) : K) * aPl U P D 1097728 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)
              + ((-65536 : ℤ) : K) * aPl U P D 1130496 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) + ((0 : ℤ) : K)
          simp only [map_sub, map_mul, map_pow, map_ofNat, aPl_alg U P D hX]
          push_cast
          ring),
      covC U P Pb Lay B Dof cut D hD hX .F 5 (by decide +kernel) 56 1130496 rfl 128 8 rfl
        (Fin.append (Lay.fPos p).1 (Lay.fPos p).2) 128 (by simp only [map_ofNat, Int.cast_ofNat]),
      remLk_one S.sprod (by rw [hS.sprod]) _ _ (by
        rw [hS.sprod]
        exact covR U P Pb Lay B Dof cut D hD hX .F 6 (by decide +kernel) 57 1163264 rfl 16 rfl
          (Fin.append (Lay.fPos p).1 (Lay.fPos p).2))⟩
  fAct p := by
    obtain ⟨l, hl⟩ := exists_act U P Pb Lay B Dof cut (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)
    refine ⟨l, ?_⟩
    rw [hl, actTupW_congr U P (Dof cut) D hD]
    unfold actTupW
    rw [splitF_append (Lay.fPos p), B.grpCol_emb p]
    refine Tup.ext' ?_ ?_ ?_ ?_
    · show _ = algebraMap GF K (piB K (aPl U P D 901120 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)) + 2048)
      simp only [map_add, map_ofNat, aPl_alg U P D hX]
    · exact (map_natCast (algebraMap GF K) tagAct).symm
    · show _ = algebraMap GF K (piB K (aPl U P D 999424 15 (Fin.append (Lay.fPos p).1 (Lay.fPos p).2)))
      rw [aPl_alg U P D hX]
    · rfl

end Cover

/-! ## `hcov` -/

/-- **Lane L36's `hcov` at the W16R2 rung, PROVED** (the form of L44's `block_knowledge_host_w16r2_rung_helper`): on
every outcome, every logical query of the extracted planes `xtW` is an entry of the lookup list `AlkW` read off the
data the `A` cut fixes (`dofA`), at a shape with the rung's precision. -/
theorem hcov_w16 {K : Type} [Field K] [Algebra GF K] {L : ℕ} (U : K) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ L) (tag : MTag) (hL20 : 2 ^ 20 ≤ L)
    (P : BlockParams) (hlc : P.logCols = 14) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay) (hS : RungS S) (A : OC (QB L) Dig (List Op × Core)) :
    ∀ G q, W16Query Pb Lay B (xtW U P (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G)
        (rootsOf (A.run G).2))) q →
      ∃ l, AlkW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
        (cutsOf key domain hs hL A G).1 l = tupK q := by
  intro G q hq
  have hcov := cover_xtW U P Pb Lay B (dofA tag hL20 P hlc rE QE XE (absOfC (chainEncB key domain hs L hL)) A)
    (cutsOf key domain hs hL A G).1
    (dXof tag hL20 P hlc 15 280 8052 320 202 rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2))
    (fun off log b => dofA_aPl U key domain hs hL tag hL20 P hlc rE QE XE A G off log b)
    (dXof_base tag hL20 P hlc rE QE XE (cutsOf key domain hs hL A G) (rootsOf (A.run G).2)) hS hlc
  by_contra hno
  apply hq
  refine w16LookupsG_mono (fun u hu huq => ?_) hcov
  subst huq
  exact hno hu

end ZK60.Exec.Block.Join.W16.Look
