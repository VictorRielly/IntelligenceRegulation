/-
D63 lane L47 (2026-11-10), part 6 (fork C): **every host's LogUp relation, vanishing, as `HelperRel`'s relation** (for
`hhr`), at a cube point of the host's domain, on L44's batch entries (`xcDzc`, `xcQzc`, `xcKvzc`, `xcSzc`, `xcFzc`) and
`SC_LZC`'s `cLzc`.

* `PairR`, `SingleR`: `HelperRel`'s pair and single relations at `(β, γ, α)`;
* **`relL_pair`**, **`relD_pair`**, **`relD_single`**, **`relQ_pair`**, **`relK_pair`**, **`relS_pair`**,
  **`relS_single`**, **`relF_pair`**, **`relF_single`**, **`relExp`**, **`relAct`**.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookRelHost

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (LkD denV Cst logupSem szcExp szcDelta fzcAct)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW tagExp tagAct)
open ZK60.Layout
open ZK60.Exec.Slot.Compose (cstW_map_std)

section Forms

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `HelperRel`'s pair relation at `bga = (β, γ, α)`. -/
def PairR (bga : Fp2 × Fp2 × Fp2) (hp : K) (a c : Tup K) : Prop :=
  hp * ((bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) a)
      * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) c))
    = (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) a)
      + (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) c)

/-- `HelperRel`'s single relation at `bga = (β, γ, α)`. -/
def SingleR (bga : Fp2 × Fp2 × Fp2) (hp : K) (a : Tup K) : Prop :=
  hp * (bga.2.2.toK U - ZK60.Sound.fold (bga.1.toK U) (bga.2.1.toK U) a) = 1

end Forms

section Lists

variable {R : Type} [CommRing R]

theorem getD_rep4 (L : List R) (e : R) (j : ℕ) (hj : j < L.length) :
    (List.replicate 4 0 ++ L ++ [e]).getD (4 + j) 0 = L.getD j 0 := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD,
    List.getElem?_append_left (by simp only [List.length_append, List.length_replicate]; omega),
    List.getElem?_append_right (by simp only [List.length_replicate]; omega)]
  simp

theorem getD_rep9 (L : List R) (e : R) (hL : L.length = 5) :
    (List.replicate 4 0 ++ L ++ [e]).getD 9 0 = e := by
  rw [List.getD_eq_getElem?_getD,
    List.getElem?_append_right (by simp only [List.length_append, List.length_replicate, hL]; omega)]
  simp [hL]

theorem logupSem_two (c : Cst R) (v : List R) (h0 : ℕ) (mu : ℕ → R) (lks : List (LkD R)) (h : lks.length = 2) :
    logupSem c v h0 mu 0 lks = mu 0 * (lkRels c v h0 0 lks).getD 0 0 := by
  match lks, h with
  | [a, b], _ => simp [logupSem, lkRels]

end Lists

section Per

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams)
  (D : CmData K P)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)
variable (bga : Fp2 × Fp2 × Fp2) (hα : bga.2.2.Canon)

theorem lenL : (lookupsN cfgRungW16 .L).length = 2 := by decide
theorem lenD : (lookupsN cfgRungW16 .D).length = 19 := by decide
theorem lenQ : (lookupsN cfgRungW16 .Q).length = 6 := by decide
theorem lenK : (lookupsN cfgRungW16 .Kv).length = 6 := by decide
theorem lenS : (lookupsN cfgRungW16 .S).length = 9 := by decide
theorem lenF : (lookupsN cfgRungW16 .F).length = 7 := by decide

theorem lenRelS (bga : Fp2 × Fp2 × Fp2) (v : List K) : (lkRels (cstK U) v 16 0 (Szc.lksK U bga)).length = 5 := by
  rw [lkRels_length]
  unfold Szc.lksK
  simp only [List.length_map]
  decide

include hα

/-- **`SC_LZC`'s relation**: the limb pair. -/
theorem relL_pair (gL : (Fin 14 → Bool) → GF) (b : Fin 14 → Bool) (h0 : Lk.cLzc U P D gL bga b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (0 + 0)).1 (hOff cfgRungW16 (0 + 0)).2 14 b)
      (lkAtW U P D .L (2 * 0) b) (lkAtW U P D .L (2 * 0 + 1) b) := by
  unfold Lk.cLzc at h0
  have hlen : (Lk.lksLK U bga).length = 2 := by
    unfold Lk.lksLK
    simp only [List.length_map]
    decide
  rw [logupSem_two _ _ _ _ _ hlen] at h0
  simp only [(cstW_map_std U).one, one_mul] at h0
  exact host_pair U bga hα 3 Lk.shapedL (lookupsN cfgRungW16 .L) _ (plA U P D 14 b) 3 _ 0 (by rw [lenL]; omega)
    (lkOK_all .L) (lzc_planes U P D gL b) (lzc_help U P D gL b) h0

/-- **`SC_DZC`'s relation `6 + j`**: pair `j` of `Dom::D`. -/
theorem relD_pair (b : Fin 14 → Bool) (j : ℕ) (hj : j < 9) (h0 : Dzc.xcDzc U P D Pb Lay B bga (6 + j) b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (1 + j)).1 (hOff cfgRungW16 (1 + j)).2 14 b)
      (lkAtW U P D .D (2 * j) b) (lkAtW U P D .D (2 * j + 1) b) := by
  unfold Dzc.xcDzc at h0
  rw [show 6 + j - 6 = j by omega] at h0
  exact host_pair U bga hα 14 Dzc.shD (lookupsN cfgRungW16 .D) _ (plA U P D 14 b) 26 _ j (by rw [lenD]; omega)
    (lkOK_all .D) (dzc_planes U P D Pb Lay B b) (dzc_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_DZC`'s relation `15`**: `Dom::D`'s odd last lookup. -/
theorem relD_single (b : Fin 14 → Bool) (h0 : Dzc.xcDzc U P D Pb Lay B bga 15 b = 0) :
    SingleR U bga (hPl U P D (hOff cfgRungW16 (1 + 9)).1 (hOff cfgRungW16 (1 + 9)).2 14 b) (lkAtW U P D .D (2 * 9) b) := by
  unfold Dzc.xcDzc at h0
  exact host_single U bga hα 14 Dzc.shD (lookupsN cfgRungW16 .D) _ (plA U P D 14 b) 26 _ 9 lenD
    (lkOK_all .D) (dzc_planes U P D Pb Lay B b) (dzc_help U P D Pb Lay B b 9 (by omega)) h0

/-- **`SC_QZC`'s relation `1 + j`**: pair `j` of `Dom::Q`. -/
theorem relQ_pair (b : Fin 15 → Bool) (j : ℕ) (hj : j < 3) (h0 : Qkv.xcQzc U P D Pb Lay B bga (1 + j) b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (11 + j)).1 (hOff cfgRungW16 (11 + j)).2 15 b)
      (lkAtW U P D .Q (2 * j) b) (lkAtW U P D .Q (2 * j + 1) b) := by
  unfold Qkv.xcQzc at h0
  rw [Nat.add_comm 1 j, List.getD_cons_succ] at h0
  exact host_pair U bga hα 15 Qkv.shQ (lookupsN cfgRungW16 .Q) _ (plA U P D 15 b) 12 _ j (by rw [lenQ]; omega)
    (lkOK_all .Q) (qzc_planes U P D Pb Lay B b) (qzc_help U P D Pb Lay B b j hj) h0

/-- **`SC_KVZC`'s relation `1 + j`**: pair `j` of `Dom::Kv`. -/
theorem relK_pair (b : Fin 14 → Bool) (j : ℕ) (hj : j < 3) (h0 : Qkv.xcKvzc U P D Pb Lay B bga (1 + j) b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (14 + j)).1 (hOff cfgRungW16 (14 + j)).2 14 b)
      (lkAtW U P D .Kv (2 * j) b) (lkAtW U P D .Kv (2 * j + 1) b) := by
  unfold Qkv.xcKvzc at h0
  rw [Nat.add_comm 1 j, List.getD_cons_succ] at h0
  exact host_pair U bga hα 16 Qkv.shK (lookupsN cfgRungW16 .Kv) _ (plA U P D 14 b) 12 _ j (by rw [lenK]; omega)
    (lkOK_all .Kv) (kvzc_planes U P D Pb Lay B b) (kvzc_help U P D Pb Lay B b j hj) h0

/-- **`SC_SZC`'s relation `4 + j`**: pair `j` of `Dom::S`. -/
theorem relS_pair (b : Fin 14 → Bool) (j : ℕ) (hj : j < 4) (h0 : Szc.xcSzc U P D Pb Lay B bga (4 + j) b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (17 + j)).1 (hOff cfgRungW16 (17 + j)).2 14 b)
      (lkAtW U P D .S (2 * j) b) (lkAtW U P D .S (2 * j + 1) b) := by
  unfold Szc.xcSzc at h0
  rw [getD_rep4 _ _ j (by rw [lenRelS U bga]; omega)] at h0
  exact host_pair U bga hα 17 Szc.shapedS (lookupsN cfgRungW16 .S) _ (plA U P D 14 b) 16 _ j (by rw [lenS]; omega)
    (lkOK_all .S) (szc_planes U P D Pb Lay B b) (szc_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_SZC`'s relation `8`**: `Dom::S`'s odd last lookup. -/
theorem relS_single (b : Fin 14 → Bool) (h0 : Szc.xcSzc U P D Pb Lay B bga (4 + 4) b = 0) :
    SingleR U bga (hPl U P D (hOff cfgRungW16 (17 + 4)).1 (hOff cfgRungW16 (17 + 4)).2 14 b) (lkAtW U P D .S (2 * 4) b) := by
  unfold Szc.xcSzc at h0
  rw [getD_rep4 _ _ 4 (by rw [lenRelS U bga]; omega)] at h0
  exact host_single U bga hα 17 Szc.shapedS (lookupsN cfgRungW16 .S) _ (plA U P D 14 b) 16 _ 4 lenS
    (lkOK_all .S) (szc_planes U P D Pb Lay B b) (szc_help U P D Pb Lay B b 4 (by omega)) h0

/-- **`SC_FZC`'s relation `2 + j`**: pair `j` of `Dom::F`. -/
theorem relF_pair (b : Fin 15 → Bool) (j : ℕ) (hj : j < 3) (h0 : Fzc.xcFzc U P D Pb Lay B bga (2 + j) b = 0) :
    PairR U bga (hPl U P D (hOff cfgRungW16 (23 + j)).1 (hOff cfgRungW16 (23 + j)).2 15 b)
      (lkAtW U P D .F (2 * j) b) (lkAtW U P D .F (2 * j + 1) b) := by
  unfold Fzc.xcFzc at h0
  rw [ite_eq_right (show ¬ (2 + j = 1) by omega), show 2 + j - 2 = j by omega] at h0
  exact host_pair U bga hα 18 Fzc.shF (lookupsN cfgRungW16 .F) _ (plA U P D 15 b) 12 _ j (by rw [lenF]; omega)
    (lkOK_all .F) (fzc_planes U P D Pb Lay B b) (fzc_help U P D Pb Lay B b j (by omega)) h0

/-- **`SC_FZC`'s relation `5`**: `Dom::F`'s odd last lookup. -/
theorem relF_single (b : Fin 15 → Bool) (h0 : Fzc.xcFzc U P D Pb Lay B bga (2 + 3) b = 0) :
    SingleR U bga (hPl U P D (hOff cfgRungW16 (23 + 3)).1 (hOff cfgRungW16 (23 + 3)).2 15 b) (lkAtW U P D .F (2 * 3) b) := by
  unfold Fzc.xcFzc at h0
  rw [ite_eq_right (show ¬ (2 + 3 = 1) by omega), show 2 + 3 - 2 = 3 by omega] at h0
  exact host_single U bga hα 18 Fzc.shF (lookupsN cfgRungW16 .F) _ (plA U P D 15 b) 12 _ 3 lenF
    (lkOK_all .F) (fzc_planes U P D Pb Lay B b) (fzc_help U P D Pb Lay B b 3 (by omega)) h0

/-- **`SC_SZC`'s relation `9`**: the exp tuple. -/
theorem relExp (hβ : bga.1.Canon) (b : Fin 14 → Bool) (h0 : Szc.xcSzc U P D Pb Lay B bga 9 b = 0) :
    SingleR U bga (hPl U P D (hOff cfgRungW16 22).1 (hOff cfgRungW16 22).2 14 b) (expTupW U P D Pb Lay B b) := by
  unfold Szc.xcSzc at h0
  rw [getD_rep9 _ _ (lenRelS U bga _)] at h0
  have hamd : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] Szc.amdS).toK U
      = bga.2.2.toK U - bga.2.1.toK U * 129 := by
    show (Fp2.sub bga.2.2 (bga.2.1.mulBase (Fp.new (UInt64.ofNat 129)))).toK U = _
    rw [Fp2.toK_sub U _ _ hα (Fp2.canon_mulBase _ _), Fp2.toK_mulBase, Fp.new_toGF_ofNat 129 (by norm_num),
      map_natCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] Szc.nbS).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hb1 : (cstK U).base (-127) = -127 := by
    rw [cstK_base U (-127) (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) (-127)).trans (by norm_num)
  have hb2 : (cstK U).base 127 = 127 := by
    rw [cstK_base U 127 (by norm_num) (by norm_num)]
    exact (map_intCast (algebraMap GF K) 127).trans (by norm_num)
  have hhx : (Szc.valsX U P D B b).getD 21 0 = hPl U P D (hOff cfgRungW16 22).1 (hOff cfgRungW16 22).2 14 b := by
    rw [show hOff cfgRungW16 22 = (819200, 835584) by decide +kernel]
    rfl
  unfold szcExp szcDelta at h0
  simp only [Szc.RSz, Szc.KSz] at h0
  rw [hamd, hnb, hb1, hb2, hhx] at h0
  unfold SingleR expTupW ZK60.Sound.fold
  have e3 : (Szc.valsX U P D B b).getD 3 0 = algebraMap GF K (B.mask (splitS b)) := rfl
  have e4 : (Szc.valsX U P D B b).getD 4 0 = aPl U P D 737280 14 b := rfl
  have e8 : (Szc.valsX U P D B b).getD 8 0 = aPl U P D 802816 14 b := rfl
  have e14 : (Szc.valsX U P D B b).getD 14 0 = aPl U P D 65536 9 (Szc.hd9 b) := rfl
  rw [e3, e4, e8, e14] at h0
  have ht : ((tagExp : ℕ) : K) = 129 := by norm_num
  rw [ht]
  linear_combination h0

include hU in
/-- **`SC_FZC`'s relation `1`**: the ACT tuple. -/
theorem relAct (hβ : bga.1.Canon) (b : Fin 15 → Bool) (h0 : Fzc.xcFzc U P D Pb Lay B bga 1 b = 0) :
    SingleR U bga (hPl U P D (hOff cfgRungW16 27).1 (hOff cfgRungW16 27).2 15 b) (actTupW U P D Pb Lay B b) := by
  unfold Fzc.xcFzc at h0
  rw [ite_eq_left rfl] at h0
  have hamq : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Fzc.amqS).toK U
      = bga.2.2.toK U - 2048 - bga.2.1.toK U * 134 := by
    show (Fp2.sub (Fp2.sub bga.2.2 (Fp2.fromBase (Fp.fromI64 2048)))
      (bga.2.1.mulBase (Fp.new (UInt64.ofNat 134)))).toK U = _
    rw [Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ hα (Fp2.canon_fromBase _ (fromI64_canon _))) (Fp2.canon_mulBase _ _),
      Fp2.toK_sub U _ _ hα (Fp2.canon_fromBase _ (fromI64_canon _)), Fp2.toK_fromBase,
      Fp.toGF_fromI64 2048 (by norm_num) (by norm_num), Fp2.toK_mulBase, Fp.new_toGF_ofNat 134 (by norm_num),
      map_natCast, map_intCast]
    norm_num
  have hnb : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Fzc.nbS).toK U = -bga.1.toK U := by
    show (Fp2.neg bga.1).toK U = _
    rw [Fp2.toK_neg U _ hβ]
  have hnb2 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 18 [] Fzc.nb2S).toK U = -(bga.1.toK U * bga.1.toK U) := by
    show (Fp2.neg (Fp2.mul bga.1 bga.1)).toK U = _
    rw [Fp2.toK_neg U _ (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
  have hfx : (Fzc.valsF U P D Pb Lay B b).getD 16 0
      = hPl U P D (hOff cfgRungW16 27).1 (hOff cfgRungW16 27).2 15 b := by
    rw [show hOff cfgRungW16 27 = (1114112, 1146880) by decide +kernel]
    rfl
  unfold fzcAct at h0
  simp only [Fzc.rrF] at h0
  rw [hamq, hnb, hnb2, hfx] at h0
  have e3 : (Fzc.valsF U P D Pb Lay B b).getD 3 0 = aPl U P D 901120 15 b := rfl
  have e6 : (Fzc.valsF U P D Pb Lay B b).getD 6 0 = aPl U P D 999424 15 b := rfl
  have e17 : (Fzc.valsF U P D Pb Lay B b).getD 17 0 = algebraMap GF K (B.grpCol (splitF b)) := rfl
  rw [e3, e6, e17] at h0
  unfold SingleR actTupW ZK60.Sound.fold
  have ht : ((tagAct : ℕ) : K) = 134 := by norm_num
  rw [ht]
  linear_combination h0

end Per

end ZK60.Exec.Block.Join.W16.Look
