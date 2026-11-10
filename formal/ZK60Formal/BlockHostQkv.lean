/-
D63 lane L44 (2026-11-10), part 3a: **`SC_QZC`'s named identity at the W16R2 rung** (host `15` of lane L36's `hform`),
with its hosted `SC_QMM` (a matmul) and `SC_PV` (the bilinear `eq(r_g)·PP·V`), by lane L41's `formAt_tzc` pattern.

* `drs`, `flC`, `flT`, `flipB`: the program's draw runs, the RoPE source table with one coordinate flipped
  (`Coord::Flip`), the bit vector with that bit flipped; **`tabK_fl_cpt`**: the flipped table at the zero extension
  is the plane at the flipped bit vector;
* `tabs15`, `tabs5`, `tabs9`, **`slot15_eq`**, **`slot5_eq`**, **`slot9_eq`**: the three slots at the rung, as explicit
  tables and IR (by evaluation);
* **`qzc_vals`**: `SC_QZC`'s value list at a cube point; `planesQ`: its entries past the three `eq` tables;
* **`xcQzc`**: the batch's entries past the RoPE clause, LogUp's three helper relations, read without the draws;
* **`qzc_Z`**: `SC_QZC`'s batched relation at a cube point is `Σ_κ μ_κ·(clause or LogUp relation)_κ` (the gate is `1`);
* **`qzc_gh`**: its two hosted terms are `relGh 15 i`;
* **`mm_spSum`**: a hosted matmul slot's unmasked sum is the extension of the contraction at its point;
* **`pv_spSum`**: `SC_PV`'s unmasked sum is the extension of `Σ_j PP·V` at its point;
* **`formAt_qzc`**: L36's `FormAt` at host `15`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Qkv

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt mleAt_append eqPoly_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some gV_none L16 reqV batchV qzcIr qzcClauses qzcIr_eval QzcR
  QzcK mmIr mmIr_eval bilIr bilIr_eval LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (qzcIr_map mmIr_map bilIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Exec.Slot.W16R2 (segLn segOff shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## Draw runs, the flipped table -/

/-- The draws `off … off + n − 1` of slot `s`, as expressions. -/
def drs (s off n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (off + i)

theorem drs_length (s off n : ℕ) (ev : Sym → Fp2) : ((drs s off n).map ev).length = n := by
  simp [drs]

theorem drs_getD (ev : Sym → Fp2) (s off n i : ℕ) (hi : i < n) :
    ((drs s off n).map ev).getD i Fp2.zero = ev (.dr s (off + i)) := by
  unfold drs
  simp [List.getD_eq_getElem?_getD, hi]

/-- A draw of the slot itself. -/
theorem eval_self (hist : Hist) (k : ℕ) (dr : List Fp2) (i : ℕ) : Sym.eval hist k dr (.dr k i) = dr.getD i Fp2.zero := by
  show drawAt hist k dr k i = _
  unfold drawAt
  rw [ite_eq_left rfl]

/-- A draw of an earlier slot, read off the history. -/
theorem eval_hist (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k j i : ℕ) (dr : List Fp2) (r : SlotRec) (hjk : j < k)
    (hr : rs[j]? = some r) :
    Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k dr (.dr j i) = r.draws.getD i Fp2.zero := by
  show drawAt _ k dr j i = _
  unfold drawAt
  rw [ite_eq_right (by omega)]
  have e : ((rs.take k).map SlotRec.draws).getD j [] = r.draws := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt hjk, hr]
    rfl
  show (((rs.take k).map SlotRec.draws).getD j []).getD i Fp2.zero = _
  rw [e]

/-- An earlier slot's draw run, read at a later slot, is that slot's run read at itself. -/
theorem drs_map_hist (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k j : ℕ) (dr : List Fp2) (r : SlotRec)
    (hjk : j < k) (hr : rs[j]? = some r) (off n : ℕ) (h0 : Hist) :
    (drs j off n).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k dr)
      = (drs j off n).map (Sym.eval h0 j r.draws) := by
  unfold drs
  simp only [List.map_map]
  refine List.map_congr_left (fun i _ => ?_)
  simp only [Function.comp_apply]
  rw [eval_hist bga rs k j (off + i) dr r hjk hr, eval_self]

/-- Coordinates `0 … log − 1` with the `k`-th flipped (`Coord::Flip`). -/
def flC (log k : ℕ) : List Coord := (List.range log).map fun j => if j = k then Coord.flip j else Coord.rho j

/-- The RoPE source table: an `A` plane on its own coordinates, the `k`-th flipped. -/
def flT (off log k m : ℕ) : TabS :=
  .priv ⟨.a, [(off, false)], log, (List.range log).map (fun j => if j = k then CoordS.flip j else CoordS.rho j), m, 0⟩

theorem flT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off log k m : ℕ) :
    TabS.eval ev pub (flT off log k m) = .priv ⟨.a, [(off, Fp2.one)], log, flC log k, m, 0⟩ := by
  have hc : ((List.range log).map (fun j => if j = k then CoordS.flip j else CoordS.rho j)).map (CoordS.eval ev)
      = flC log k := by
    unfold flC
    rw [List.map_map]
    refine List.map_congr_left (fun j _ => ?_)
    by_cases h : j = k
    · simp [h, CoordS.eval]
    · simp [h, CoordS.eval]
  show Tab.priv ⟨.a, [(off, if false then fp2U else Fp2.one)], log,
    ((List.range log).map (fun j => if j = k then CoordS.flip j else CoordS.rho j)).map (CoordS.eval ev), m, 0⟩ = _
  rw [hc]
  rfl

/-- A bit vector with bit `k` flipped. -/
def flipB {n : ℕ} (k : ℕ) (b : Fin n → Bool) : Fin n → Bool := fun i => if (i : ℕ) = k then !(b i) else b i

/-- An `H` table on its own coordinates, as the program writes it. -/
def hT (re im log m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩

/-- A matmul's `A` table: fixed draws, then the slot's variables. -/
def fxT (off log : ℕ) (rr : List Sym) (m mrow ext : ℕ) : TabS :=
  .priv ⟨.a, [(off, false)], log, rr.map CoordS.fixed ++ DefW16.rhoC 0 m, mrow, ext⟩

section Flip

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem ptK_flC (xr : ℕ → K) (log k a : ℕ) :
    ptK U xr (flC log k) a = if a < log then (if a = k then 1 - xr a else xr a) else 0 := by
  unfold ptK flC
  rw [List.getElem?_map]
  by_cases h : a < log
  · rw [List.getElem?_range h, ite_eq_left h]
    by_cases hk : a = k
    · simp [hk, coordK]
    · simp [hk, coordK]
  · rw [List.getElem?_eq_none (by rw [List.length_range]; omega), ite_eq_right h]
    rfl

/-- **The flipped table at the zero extension is the plane at the flipped bit vector.** -/
theorem tabK_fl_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (k : ℕ) (hn : 0 < n) (off m : ℕ) :
    tabK U P D n e (cpt n e b) (.priv ⟨.a, [(off, Fp2.one)], n, flC n k, m, 0⟩) = aPl U P D off n (flipB k b) := by
  rw [tabK_priv_cpt U P D n e b _ (by simp) hn hrl]
  have hpt : (fun a : Fin n => ptK U (xrK n (cpt (K := K) n e b)) (flC n k) a) = fun a => bit (flipB k b a) := by
    funext a
    rw [ptK_flC, ite_eq_left a.isLt, xrK_cpt, dite_eq_left a.isLt]
    show (if (a : ℕ) = k then 1 - bit (b a) else bit (b a)) = bit (if (a : ℕ) = k then !(b a) else b a)
    by_cases h : (a : ℕ) = k
    · rw [ite_eq_left h, ite_eq_left h]
      cases b a <;> simp [bit]
    · rw [ite_eq_right h, ite_eq_right h]
  show mleAt _ (fun a : Fin n => ptK U (xrK n (cpt (K := K) n e b)) (flC n k) a) = _
  rw [hpt, mleAt_bit]
  rfl

end Flip

/-! ## The three slots at the rung -/

/-- `SC_QZC`'s table positions and shifts. -/
def rQ : QzcR := ⟨0, 1, 2, 3, 4, 5, 7, 9, 11, [8], [6], [10], 12, none⟩
def kQ : QzcK := ⟨7, 15, 12⟩
def shQ : ℕ → ℕ := fun q => 5 + (q - 27)

/-- `SC_QZC`'s tables: `eq(τ)`, `eq(SC_QMM's point)`, `eq(SC_PV's point)`, `cos`, `sin`, the six `Dom::Q` planes, the
flipped source, the three helpers. -/
def tabs15 : List TabS :=
  [.eq (drs 15 6 15) 0, .eq (drs 5 0 15) 0, .eq (drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6) 0, .pub 0, .pub 1,
    paT 442368 15 210, paT 475136 15 212, paT 507904 15 214, paT 540672 15 216, paT 573440 15 218,
    paT 606208 15 220, flT 442368 15 9 222, hT 360448 393216 15 130, hT 425984 458752 15 132,
    hT 491520 524288 15 134]

theorem slot15_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 15 SlotS.empty
    = ⟨tabs15, qzcIr DefW16.cstS rQ kQ (lksS cfgRungW16 shQ .Q) (drs 15 0 4) (drs 15 4 2)
        (fun j => Sym.pow Sym.zero j) [],
      [(5, .dr 15 4), (9, .dr 15 5)], [.dr 15 4, .dr 15 5]⟩ := rfl

/-- `SC_QMM`'s tables: `Y` with `r_q` fixed, the folded `W_q`. -/
def tabs5 : List TabS := [fxT 147456 14 (drs 5 0 5) 9 146 0, .pub 0]

theorem slot5_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 5 SlotS.empty
    = ⟨tabs5, mmIr DefW16.cstS 0 1, [], []⟩ := rfl

/-- `SC_PV`'s claim coordinates of `PP` (`ρ0..2`, fixed `r_hj`, fixed `r_t`, `ρ3..7`) and of `V` (`ρ3..7`, `ρ0..2`,
fixed `r_i`). -/
def ppCS : List CoordS := DefW16.rhoC 0 3 ++ (drs 9 3 1).map CoordS.fixed ++ (drs 9 4 5).map CoordS.fixed ++ DefW16.rhoC 3 8
def vCS : List CoordS := DefW16.rhoC 3 8 ++ DefW16.rhoC 0 3 ++ (drs 9 9 6).map CoordS.fixed

/-- `SC_PV`'s tables: `eq(r_g)`, `PP`, `V`. -/
def tabs9 : List TabS :=
  [.eq (drs 9 0 3) 0, .priv ⟨.a, [(819200, false)], 14, ppCS, 156, 0⟩, .priv ⟨.a, [(671744, false)], 14, vCS, 158, 1⟩]

theorem slot9_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 9 SlotS.empty
    = ⟨tabs9, bilIr DefW16.cstS (some 0) 1 2, [], []⟩ := rfl

/-! ## Multilinear extensions at points made of blocks -/

section Mle

variable {K : Type} [Field K]

/-- **The extension at two blocks is the iterated extension.** -/
theorem mleAt_app' {a b : ℕ} (f : (Fin (a + b) → Bool) → K) (p : Fin a → K) (q : Fin b → K) :
    mleAt f (Fin.append p q) = mleAt (fun z => mleAt (fun w => f (Fin.append z w)) q) p := by
  rw [mleAt_append]
  unfold SlotW16.mle2 mleAt
  refine Finset.sum_congr rfl (fun z _ => ?_)
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl (fun w _ => ?_)
  ring

/-- Bits first: the extension at `(c, r)` with `c` a bit vector. -/
theorem mleAt_bits_append {a m : ℕ} (f : (Fin (a + m) → Bool) → K) (c : Fin a → Bool) (r : Fin m → K) :
    mleAt f (Fin.append (fun i => bit (c i)) r) = ∑ z : Fin m → Bool, eqPoly r (fun i => bit (z i)) * f (Fin.append c z) := by
  rw [mleAt_app', mleAt_bit]
  rfl

end Mle

/-! ## The value list of `SC_QZC` at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_QZC`'s private entries at a cube point: the six `Dom::Q` planes, the flipped source, the three helpers. -/
noncomputable def planesQ (P : BlockParams) (D : CmData K P) (b : Fin 15 → Bool) : List K :=
  [aPl U P D 442368 15 b, aPl U P D 475136 15 b, aPl U P D 507904 15 b, aPl U P D 540672 15 b,
    aPl U P D 573440 15 b, aPl U P D 606208 15 b, aPl U P D 442368 15 (flipB 9 b),
    hPl U P D 360448 393216 15 b, hPl U P D 425984 458752 15 b, hPl U P D 491520 524288 15 b]

/-- An `eq` table's entry at a cube point. -/
noncomputable def eqv (pt : List Sym) (ev : Sym → Fp2) (n : ℕ) (b : Fin n → Bool) : K :=
  eqPoly (fun a : Fin n => ((pt.map ev).getD a Fp2.zero).toK U) (fun a => bit (b a))

/-- **`SC_QZC`'s value list at a cube point with the zero extension.** -/
theorem qzc_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 15 → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e b))
      = eqv U (drs 15 6 15) ev 15 b :: eqv U (drs 5 0 15) ev 15 b
        :: eqv U (drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6) ev 15 b
        :: ((pub 0).getD (msbIndex 15 b) Fp2.zero).toK U :: ((pub 1).getD (msbIndex 15 b) Fp2.zero).toK U
        :: planesQ U P D b := by
  have l0 : ((drs 15 6 15).map ev).length = 15 := drs_length _ _ _ ev
  have l1 : ((drs 5 0 15).map ev).length = 15 := drs_length _ _ _ ev
  have l2 : ((drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6).map ev).length = 15 := by simp [drs]
  simp only [tabs15, hT, List.map_cons, List.map_nil, eqT_eval, pubT_eval, paT_eval, flT_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 15 e b _ l0, tabK_eqFull_cpt U P D 15 e b _ l1, tabK_eqFull_cpt U P D 15 e b _ l2,
    tabK_pub_cpt U P D 15 e b, tabK_pub_cpt U P D 15 e b, tabK_fl_cpt U P D hrl 15 e b 9 (by norm_num)]
  simp only [tabK_pa_cpt U P D hrl 15 e b 15 (by norm_num) rfl, tabK_ph_cpt U P D hrl 15 e b 15 (by norm_num) rfl,
    castB_rfl]
  rfl

end Vals

/-! ## `SC_QZC`'s IR read in the field -/

section Ir

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_QZC`'s lookups, read at a history and draws, in the field. -/
noncomputable def lksQ (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS cfgRungW16 shQ .Q).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 15 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **`SC_QZC`'s IR read in the field**: L13's host terms with LogUp, the RoPE clause and the two requantizations. -/
theorem qzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((qzcIr DefW16.cstS rQ kQ (lksS cfgRungW16 shQ .Q) (drs 15 0 4) (drs 15 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 15 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 12 (fun k => (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD (1 + k) 0)
              0 (lksQ U hist dr)
            + gV v none * batchV (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U)) (qzcClauses (cstK U) rQ kQ v))
          (reqV (cstK U) v 15 5 [6]) (reqV (cstK U) v 12 9 [10]) := by
  rw [qzcIr_map, qzcIr_map, cstS_map, qzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

/-- The lookups' positions are past the three `eq` tables. -/
theorem lksQ_pos (hist : Hist) (dr : List Fp2) : ∀ l ∈ lksQ U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  unfold lksQ lksS at hl
  simp only [List.map_map, List.mem_map, Function.comp] at hl
  obtain ⟨l0, -, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map, Function.comp] at ht
  obtain ⟨t0, -, rfl⟩ := ht
  simp only [shQ]
  omega

theorem lksQ_length (hist : Hist) (dr : List Fp2) : (lksQ U hist dr).length = 6 := by
  unfold lksQ lksS
  simp only [List.length_map]
  decide

end Ir

/-! ## The batch and the hosted terms are the named relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- `SC_QZC`'s value list without the draws: the `eq` entries `0`, the public entries `B`'s. -/
noncomputable def valsXQ (b : Fin 15 → Bool) : List K :=
  0 :: 0 :: 0 :: algebraMap GF K (B.cosT (splitQ b)) :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b

/-- **`SC_QZC`'s batch entries past the RoPE clause**: LogUp's three helper relations at the cube point, read without
the draws (entry `κ` for `1 ≤ κ < 4`). -/
noncomputable def xcQzc (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 15 → Bool) : K :=
  (0 :: lkRels (cstK U) (valsXQ U P D Pb Lay B b) 12 0 (lksQ U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD κ 0

include hX in
/-- `Dom::Q`'s plane, embedded. -/
theorem alg_plQ (off : ℕ) (x : CtW × ((CgW × CjW) × CdW)) :
    algebraMap GF K (plQ U P D off x) = aPl U P D off 15 (Fin.append x.1 (Fin.append (Fin.append x.2.1.1 x.2.1.2) x.2.2)) :=
  aPl_alg U P D hX off 15 _

end Rels

theorem append_splitQ (b : Fin 15 → Bool) :
    Fin.append (splitQ b).1 (Fin.append (Fin.append (splitQ b).2.1.1 (splitQ b).2.1.2) (splitQ b).2.2) = b := by
  funext i
  fin_cases i <;> rfl

theorem append_flipQ (b : Fin 15 → Bool) :
    Fin.append (splitQ b).1 (Fin.append (Fin.append (splitQ b).2.1.1 (splitQ b).2.1.2)
      (Function.update (splitQ b).2.2 0 (!(splitQ b).2.2 0))) = flipB 9 b := by
  funext i
  fin_cases i <;> rfl

/-! ## The RoPE clause and the hosted terms -/

section Consts

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem cstK_pow (s : ℕ) (hs : s < 63) : (cstK U).base (2 ^ s) = (2 : K) ^ s := by
  have h1 : (0 : ℤ) < 2 ^ s := by positivity
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) (by omega)
  rw [cstK_base U (2 ^ s) (by linarith) h2]
  simp only [Int.cast_pow, map_pow, Int.cast_ofNat, map_ofNat]

theorem cstK_negpow (s : ℕ) (hs : s < 63) : (cstK U).base (-(2 ^ s)) = -(2 : K) ^ s := by
  have h1 : (0 : ℤ) < 2 ^ s := by positivity
  have h2 : (2 : ℤ) ^ s < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) (by omega)
  rw [cstK_base U (-(2 ^ s)) (by linarith) (by linarith)]
  simp only [Int.cast_neg, map_neg, Int.cast_pow, map_pow, Int.cast_ofNat, map_ofNat]

theorem cstK_p16_zero : (cstK U).p16 0 = 1 := by
  rw [cstK_p16 U 0 (by norm_num)]
  simp

end Consts

section Rels2

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

include hX hL

/-- **`SC_QZC`'s RoPE clause, embedded** (the gate is `1`, the flip is the head dimension's top bit). -/
theorem qzc_relCl (b : Fin 15 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 0 (.q (splitQ b)))
      = algebraMap GF K (B.cosT (splitQ b)) * aPl U P D 442368 15 b
        + algebraMap GF K (B.sinT (splitQ b)) * aPl U P D 442368 15 (flipB 9 b)
        - 2 ^ 7 * aPl U P D 507904 15 b - aPl U P D 540672 15 b + 2 ^ 6 := by
  have hg := gQ_one B hL (splitQ b)
  simp only [relCl, xtW, remR, remVal, hg, one_mul, List.getD_cons_zero, List.length_cons, List.length_nil,
    hL.flip, (by norm_num : (7 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ U P D hX, append_splitQ, append_flipQ]

/-- `SC_QZC`'s first hosted term, embedded. -/
theorem qzc_relGh0 (hS : RungS S) (b : Fin 15 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 0 (.q (splitQ b)))
      = 2 ^ 15 * aPl U P D 442368 15 b + aPl U P D 475136 15 b - 2 ^ 14 := by
  have hg := gQ_one B hL (splitQ b)
  simp only [relGh, xtW, remR, remVal, hg, one_mul, hS.sq, List.getD_cons_zero, List.length_cons, List.length_nil,
    (by norm_num : (15 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ U P D hX, append_splitQ]
  try norm_num

/-- `SC_QZC`'s second hosted term, embedded. -/
theorem qzc_relGh1 (hS : RungS S) (b : Fin 15 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 1 (.q (splitQ b)))
      = 2 ^ 12 * aPl U P D 573440 15 b + aPl U P D 606208 15 b - 2 ^ 11 := by
  have hg := gQ_one B hL (splitQ b)
  simp only [relGh, xtW, remR, remVal, hg, one_mul, hS.spv, List.getD_cons_zero, List.length_cons, List.length_nil,
    (by norm_num : (12 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plQ U P D hX, append_splitQ]
  try norm_num

/-- **`SC_QZC`'s IR clause is the named RoPE relation.** -/
theorem qzc_clause (e0 e1 e2 : K) (b : Fin 15 → Bool) :
    qzcClauses (cstK U) rQ kQ (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ b))
      :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b)
      = [algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 0 (.q (splitQ b)))] := by
  rw [qzc_relCl U P D hX Pb Lay B hL b]
  unfold qzcClauses
  rw [show kQ.rope = 7 from rfl, cstK_negpow U 7 (by norm_num), show 7 - 1 = 6 from rfl, cstK_pow U 6 (by norm_num)]
  simp only [rQ, L16, planesQ, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  congr 1
  ring

/-- **`SC_QZC`'s IR hosted terms are the named requantizations.** -/
theorem qzc_gh (hS : RungS S) (e0 e1 e2 c s : K) (b : Fin 15 → Bool) :
    reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesQ U P D b) 15 5 [6]
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 0 (.q (splitQ b)))
      ∧ reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesQ U P D b) 12 9 [10]
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 1 (.q (splitQ b))) := by
  rw [qzc_relGh0 U P D hX Pb Lay B hL hS b, qzc_relGh1 U P D hX Pb Lay B hL hS b]
  unfold reqV
  rw [cstK_pow U 15 (by norm_num), cstK_pow U 12 (by norm_num), show 15 - 1 = 14 from rfl,
    show 12 - 1 = 11 from rfl, cstK_negpow U 14 (by norm_num), cstK_negpow U 11 (by norm_num)]
  simp only [L16, planesQ, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  constructor <;> ring

end Rels2

/-! ## `SC_QZC`'s batched relation -/

section Batch

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

include hX hL in
/-- **`SC_QZC`'s batched relation at a cube point is `Σ_κ μ_κ·(the RoPE clause or a LogUp relation)`.** -/
theorem qzc_Z (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (mu : List K) (e0 e1 e2 : K) (b : Fin 15 → Bool) :
    logupSem (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ b))
          :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b) 12 (fun k => mu.getD (1 + k) 0) 0 (lksQ U hist dr)
        + gV (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ b))
          :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b) none
          * batchV mu (qzcClauses (cstK U) rQ kQ (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ b))
            :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b))
      = ∑ κ : Fin 4, mu.getD κ 0 * (if (κ : ℕ) < 1
          then algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 κ (.q (splitQ b)))
          else xcQzc U P D Pb Lay B bga κ b) := by
  have hlk : lksQ U hist dr = lksQ U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksQ
    rw [lksS_eval cfgRungW16 shQ .Q hist (histOf bga.1 bga.2.1 bga.2.2 []) 15 15 dr [] ha hgm]
  have hcg : lkRels (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosT (splitQ b))
        :: algebraMap GF K (B.sinT (splitQ b)) :: planesQ U P D b) 12 0 (lksQ U hist dr)
      = lkRels (cstK U) (valsXQ U P D Pb Lay B b) 12 0 (lksQ U (histOf bga.1 bga.2.1 bga.2.2 []) []) := by
    rw [hlk]
    refine lkRels_congr (cstK U) _ _ 12 0 _ (fun l hl t ht => ?_) (fun i _ => ?_)
    · have h3 := lksQ_pos U _ _ l hl t ht
      obtain ⟨j, hj⟩ : ∃ j, t.2 = j + 3 := ⟨t.2 - 3, by omega⟩
      rw [hj]
      simp only [valsXQ, List.getD_cons_succ]
    · rw [show 12 + (0 + i) = (9 + i) + 3 by omega]
      simp only [valsXQ, List.getD_cons_succ]
  have hlen : (lkRels (cstK U) (valsXQ U P D Pb Lay B b) 12 0
      (lksQ U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 3 := by
    simp [lkRels_length, lksQ_length]
  obtain ⟨x1, x2, x3, hx⟩ := List.length_eq_three.mp hlen
  have hxc : ∀ κ, xcQzc U P D Pb Lay B bga κ b = ([0, x1, x2, x3] : List K).getD κ 0 := by
    intro κ
    unfold xcQzc
    rw [hx]
  rw [logupSem_eq_wsum, hcg, hx, qzc_clause U P D hX Pb Lay B hL, gV_none]
  rw [Fin.sum_univ_eq_sum_range (fun κ => mu.getD κ 0 * (if κ < 1
    then algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 κ (.q (splitQ b))) else xcQzc U P D Pb Lay B bga κ b)) 4]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add, hxc, wsum, batchV, List.zipIdx_cons,
    List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ,
    List.getD_cons_zero, add_zero, one_mul]
  norm_num
  ring

end Batch

/-! ## `SC_QZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem qzc_off (e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin 15 → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) :
    ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 0 0 = 0
      ∧ ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 1 0 = 0
      ∧ ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (bpt 15 e b y))).getD 2 0 = 0 := by
  simp only [tabs15, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D 15 e b y hy _ _, tabK_eq_off U P D 15 e b y hy _ _, tabK_eq_off U P D 15 e b y hy _ _⟩

include hX hrl hL in
/-- **`SC_QZC`'s cube sum**: `Σ_t hostPoly(τ, Σ_κ μ_κ·c_κ, ν, (P₁, P₂), 1, relGh 15)(t)`. -/
theorem qzc_cube (hS : RungS S) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (pub : ℕ → List Fp2)
    (hcos : ∀ b, ((pub 0).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.cosT (splitQ b)))
    (hsin : ∀ b, ((pub 1).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.sinT (splitQ b)))
    (n e : ℕ) (hn : n = 15) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((qzcIr DefW16.cstS rQ kQ (lksS cfgRungW16 shQ .Q) (drs 15 0 4) (drs 15 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 15 dr)).map (Fp2.toK U))
      ((tabs15.map (TabS.eval (Sym.eval hist 15 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin 15 → Bool,
      hostPoly (fun a : Fin 15 => (((drs 15 6 15).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 4, (((drs 15 0 4).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 κ (.q (splitQ t)))
            else xcQzc U P D Pb Lay B bga κ t))
        ![(((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 15 4 2).map (Sym.eval hist 15 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin 15 => (((drs 5 0 15).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U,
          fun a : Fin 15 => (((drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6).map (Sym.eval hist 15 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 i (.q (splitQ t)))) t := by
  subst hn
  set ev := Sym.eval hist 15 dr with hev
  rw [cubeSum_host 15 e (fun x => (tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e x)) 0 1 2 none none
    (((drs 15 4 2).map ev).map (Fp2.toK U))
    (fun v => logupSem (cstK U) v 12 (fun k => (((drs 15 0 4).map ev).map (Fp2.toK U)).getD (1 + k) 0) 0
        (lksQ U hist dr)
      + gV v none * batchV (((drs 15 0 4).map ev).map (Fp2.toK U)) (qzcClauses (cstK U) rQ kQ v))
    (fun v => reqV (cstK U) v 15 5 [6]) (fun v => reqV (cstK U) v 12 9 [10]) f
    (fun x => by rw [hf x, qzc_irEval U hist dr])
    (fun b y hy => qzc_off U P D e ev pub b y hy)
    (fun a : Fin 15 => (((drs 15 6 15).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin 15 => (((drs 5 0 15).map ev).getD a Fp2.zero).toK U,
      fun a : Fin 15 => (((drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6).map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [qzc_vals U P D hrl e b ev pub]; rfl)
    (fun b => by rw [qzc_vals U P D hrl e b ev pub]; rfl)
    (fun b => by rw [qzc_vals U P D hrl e b ev pub]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := qzc_vals U P D hrl e t ev pub
  rw [hcos t, hsin t] at hv
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · show logupSem (cstK U) ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) 12 _ 0 _
        + gV ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) none * _ = _
    rw [hv]
    exact qzc_Z U P D hX Pb Lay B hL bga hist dr ha hgm _ _ _ _ t
  · obtain ⟨g0, g1⟩ := qzc_gh U P D hX Pb Lay B hL hS (eqv U (drs 15 6 15) ev 15 t) (eqv U (drs 5 0 15) ev 15 t)
      (eqv U (drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6) ev 15 t) (algebraMap GF K (B.cosT (splitQ t)))
      (algebraMap GF K (B.sinT (splitQ t))) t
    fin_cases i
    · show gV ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) none
          * reqV (cstK U) ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) 15 5 [6] = _
      rw [hv, gV_none, one_mul, g0]
    · show gV ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) none
          * reqV (cstK U) ((tabs15.map (TabS.eval ev pub)).map (tabK U P D 15 e (cpt 15 e t))) 12 9 [10] = _
      rw [hv, gV_none, one_mul, g1]

end Cube

/-! ## The hosted matmuls -/

section MmSum

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A hosted matmul slot's unmasked sum** (generic in the program): its table is `fxT` (fixed draws `rr`, then `m`
variables), its folded weight's entry `c` is `Σ_y eq(s, y)·W(c, y)`; the sum is the extension of the contraction at
`(rr, s)`. -/
theorem mm_spSum (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (prog : List SlotS) (pubs : PubTabs)
    (s off mrow a m nout : ℕ) (rr : List Sym) (hrr : rr.length = a) (hsh : (slotShape P s).1 = m)
    (hlog : 0 < a + m)
    (hprog : prog.getD s SlotS.empty = ⟨[fxT off (a + m) rr m mrow 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec) (hr : rs[s]? = some r)
    (W : (Fin m → Bool) → (Fin nout → Bool) → K) (so : Fin nout → K)
    (hW : ∀ c, ((pubs s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) r.draws 0).getD (msbIndex m c) Fp2.zero).toK U
      = ∑ y, eqPoly so (fun i => bit (y i)) * W c y) :
    spSum P (polyS U P D prog pubs) bga rs s
      = mleAt (fun y : Fin (a + nout) → Bool => ∑ c : Fin m → Bool,
          aPl U P D off (a + m) (Fin.append (fun i => y (Fin.castAdd nout i)) c) * W c (fun i => y (Fin.natAdd a i)))
        (Fin.append (fun i : Fin a => ((rr.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) s r.draws)).getD i
          Fp2.zero).toK U) so) := by
  unfold spSum
  rw [mm_cube U P D hrl (slotShape P s).1 (slotShape P s).2.1
    (rr.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) s r.draws)) a m (by rw [List.length_map, hrr]) hsh
    hlog off mrow (pubs s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) r.draws 0)
    (polyS U P D prog pubs s (seenOf bga rs s)) (fun x => by
      rw [polyS_seenOf U P D prog pubs bga rs s r hr x, hprog]
      simp only [fxT, List.map_cons, List.map_nil, aFx_eval, pubT_eval, mmIr_map, cstS_map]
      rw [mmIr_eval _ (cstW_map_std U)]
      rfl)]
  simp_rw [hW]
  exact mm_fold (fun z c => aPl U P D off (a + m) (Fin.append z c)) W _ so

end MmSum

section Qmm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX hrl in
/-- **`SC_QMM`'s unmasked sum is the extension of `relMm 15 0` at its point** (`Y·W_q`, `hpub.wq`). -/
theorem qmm_spSum (pubs : PubTabs) (hpub : PubW16 U pubs Pb Lay B) (ioIn ioOut : ℕ) (hsh : slotShape P 5 = (9, 1, 2))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec) (hr : rs[5]? = some r) (hc : ∀ x ∈ r.draws, x.Canon) :
    spSum P (polyS U P D (progW16 cfgRungW16 ioIn ioOut) pubs) bga rs 5
      = mleAt (fun y : Fin (5 + 10) → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 15 0 (.q (splitQ y))))
          (fun t : Fin (5 + 10) => (r.draws.getD t Fp2.zero).toK U) := by
  rw [mm_spSum U P D hrl (progW16 cfgRungW16 ioIn ioOut) pubs 5 147456 146 5 9 10 (drs 5 0 5) (by simp [drs])
    (by rw [hsh]) (by norm_num) (slot5_eq ioIn ioOut) bga rs r hr (fun c y => algebraMap GF K (B.Wq c (splitHQ y)))
    (fun a => (r.draws.getD (5 + a) Fp2.zero).toK U) (fun c => hpub.wq _ _ hc c)]
  have hpt : Fin.append (fun i : Fin 5 => (((drs 5 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 5)) 5
      r.draws)).getD i Fp2.zero).toK U) (fun a : Fin 10 => (r.draws.getD (5 + a) Fp2.zero).toK U)
      = fun t : Fin (5 + 10) => (r.draws.getD t Fp2.zero).toK U := by
    funext t
    refine Fin.addCases (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left, drs_getD _ 5 0 5 i i.isLt, eval_self, Nat.zero_add]
      simp
    · rw [Fin.append_right]
      simp
  rw [hpt]
  congr 1
  funext y
  simp only [relMm, xtW, map_sum, map_mul]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [alg_plD U P D hX]
  rfl

end Qmm

/-! ## `SC_PV` -/

section Pv

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem ptPP (xr : ℕ → K) (ev : Sym → Fp2) :
    (fun a : Fin ((3 + 1) + (5 + 5)) => ptK U xr (ppCS.map (CoordS.eval ev)) a)
      = Fin.append (Fin.append (fun i : Fin 3 => xr i) (fun _ : Fin 1 => (ev (.dr 9 3)).toK U))
          (Fin.append (fun i : Fin 5 => (ev (.dr 9 (4 + i))).toK U) (fun i : Fin 5 => xr (3 + i))) := by
  funext a
  fin_cases a <;> rfl

theorem ptV (xr : ℕ → K) (ev : Sym → Fp2) :
    (fun a : Fin (5 + (3 + 6)) => ptK U xr (vCS.map (CoordS.eval ev)) a)
      = Fin.append (fun i : Fin 5 => xr (3 + i))
          (Fin.append (fun i : Fin 3 => xr i) (fun i : Fin 6 => (ev (.dr 9 (9 + i))).toK U)) := by
  funext a
  fin_cases a <;> rfl

omit [Algebra GF K] in
/-- `PP`'s extension at `(g, r_j, r_t, t')`. -/
theorem mle_pp (f : (Fin ((3 + 1) + (5 + 5)) → Bool) → K) (g : Fin 3 → Bool) (q : Fin 1 → K) (r : Fin 5 → K)
    (t' : Fin 5 → Bool) :
    mleAt f (Fin.append (Fin.append (fun i => bit (g i)) q) (Fin.append r (fun i => bit (t' i))))
      = ∑ z : Fin 1 → Bool, eqPoly q (fun i => bit (z i)) * ∑ w : Fin 5 → Bool, eqPoly r (fun i => bit (w i))
          * f (Fin.append (Fin.append g z) (Fin.append w t')) := by
  rw [mleAt_app', mleAt_bits_append]
  simp only [mleAt_append_bits]

omit [Algebra GF K] in
/-- `V`'s extension at `(t', g, r_i)`. -/
theorem mle_v (f : (Fin (5 + (3 + 6)) → Bool) → K) (t' : Fin 5 → Bool) (g : Fin 3 → Bool) (s : Fin 6 → K) :
    mleAt f (Fin.append (fun i => bit (t' i)) (Fin.append (fun i => bit (g i)) s))
      = ∑ c : Fin 6 → Bool, eqPoly s (fun i => bit (c i)) * f (Fin.append t' (Fin.append g c)) := by
  rw [mleAt_app', mleAt_bit, mleAt_bits_append]

/-- **`SC_PV`'s cube sum**, at `n = 8` main variables: `Σ_{g, t'} eq(r_g, g)·PP̃(g, r_j, r_t, t')·Ṽ(t', g, r_i)`. -/
theorem pv_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 8) (hist : Hist)
    (dr : List Fp2) (pub : ℕ → List Fp2) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 9 dr)).map (Fp2.toK U))
      ((tabs9.map (TabS.eval (Sym.eval hist 9 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin 3 → Bool, ∑ t' : Fin 5 → Bool,
      eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i))
        * ((∑ z : Fin 1 → Bool, eqPoly (fun _ : Fin 1 => (dr.getD 3 Fp2.zero).toK U) (fun i => bit (z i))
            * ∑ w : Fin 5 → Bool, eqPoly (fun i : Fin 5 => (dr.getD (4 + i) Fp2.zero).toK U) (fun i => bit (w i))
              * aPl U P D 819200 14 (Fin.append (Fin.append g z) (Fin.append w t')))
          * (∑ c : Fin 6 → Bool, eqPoly (fun i : Fin 6 => (dr.getD (9 + i) Fp2.zero).toK U) (fun i => bit (c i))
              * aPl U P D 671744 14 (Fin.append t' (Fin.append g c)))) := by
  subst hn
  set ev := Sym.eval hist 9 dr with hev
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map ev).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U), gV_some]
  rw [cubeSum_split]
  refine (sum_append (a := 3) (b := 5) _).trans (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl
    (fun t' _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 8 e (Fin.append g t')) = _
    rw [hf, hir]
    simp only [tabs9, List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
    have hx1 : ∀ i : Fin 3, xrK 8 (cpt (K := K) 8 e (Fin.append g t')) i = bit (g i) := by
      intro i
      rw [xrK_cpt, dite_eq_left (by omega), show (⟨(i : ℕ), by omega⟩ : Fin 8) = Fin.castAdd 5 i from rfl,
        Fin.append_left]
    have hx2 : ∀ i : Fin 5, xrK 8 (cpt (K := K) 8 e (Fin.append g t')) (3 + i) = bit (t' i) := by
      intro i
      rw [xrK_cpt, dite_eq_left (by omega), show (⟨3 + (i : ℕ), by omega⟩ : Fin 8) = Fin.natAdd 3 i from rfl,
        Fin.append_right]
    have h0 : tabK U P D 8 e (cpt 8 e (Fin.append g t')) (.eq ((drs 9 0 3).map ev) 0)
        = eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i)) := by
      rw [tabK_eqHead_cpt U P D 8 e _ _ 3 (drs_length _ _ _ ev) (by norm_num)]
      congr 1
      · funext a
        rw [drs_getD ev 9 0 3 a a.isLt, hev, eval_self, Nat.zero_add]
      · funext a
        rw [show (⟨(a : ℕ), by omega⟩ : Fin 8) = Fin.castAdd 5 a from rfl, Fin.append_left]
    have h1 : tabK U P D 8 e (cpt 8 e (Fin.append g t')) (TabS.eval ev pub (.priv ⟨.a, [(819200, false)], 14, ppCS, 156, 0⟩))
        = ∑ z : Fin 1 → Bool, eqPoly (fun _ : Fin 1 => (dr.getD 3 Fp2.zero).toK U) (fun i => bit (z i))
            * ∑ w : Fin 5 → Bool, eqPoly (fun i : Fin 5 => (dr.getD (4 + i) Fp2.zero).toK U) (fun i => bit (w i))
              * aPl U P D 819200 14 (Fin.append (Fin.append g z) (Fin.append w t')) := by
      show tabK U P D 8 e (cpt 8 e (Fin.append g t')) (.priv ⟨.a, [(819200, Fp2.one)], 14, ppCS.map (CoordS.eval ev), 156, 0⟩) = _
      rw [tabK_priv_cpt U P D 8 e _ _ (by simp) (by norm_num) hrl]
      show mleAt (n := (3 + 1) + (5 + 5)) (aPl U P D 819200 14)
        (fun a : Fin ((3 + 1) + (5 + 5)) => ptK U (xrK 8 (cpt (K := K) 8 e (Fin.append g t'))) (ppCS.map (CoordS.eval ev)) a) = _
      rw [ptPP U (xrK 8 (cpt (K := K) 8 e (Fin.append g t'))) ev]
      simp only [hx1, hx2, hev, eval_self]
      exact mle_pp _ g _ _ t'
    have h2 : tabK U P D 8 e (cpt 8 e (Fin.append g t')) (TabS.eval ev pub (.priv ⟨.a, [(671744, false)], 14, vCS, 158, 1⟩))
        = ∑ c : Fin 6 → Bool, eqPoly (fun i : Fin 6 => (dr.getD (9 + i) Fp2.zero).toK U) (fun i => bit (c i))
            * aPl U P D 671744 14 (Fin.append t' (Fin.append g c)) := by
      show tabK U P D 8 e (cpt 8 e (Fin.append g t')) (.priv ⟨.a, [(671744, Fp2.one)], 14, vCS.map (CoordS.eval ev), 158, 1⟩) = _
      rw [tabK_priv_cpt U P D 8 e _ _ (by simp) (by norm_num) hrl]
      show mleAt (n := 5 + (3 + 6)) (aPl U P D 671744 14)
        (fun a : Fin (5 + (3 + 6)) => ptK U (xrK 8 (cpt (K := K) 8 e (Fin.append g t'))) (vCS.map (CoordS.eval ev)) a) = _
      rw [ptV U (xrK 8 (cpt (K := K) 8 e (Fin.append g t'))) ev]
      simp only [hx1, hx2, hev, eval_self]
      exact mle_v _ t' g _
    rw [h0, h1, h2]
  · show f (bpt 8 e (Fin.append g t') y) = 0
    rw [hf, hir]
    simp only [tabs9, List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero]
    rw [tabK_eq_off U P D 8 e _ y hy, zero_mul]

omit [Algebra GF K] in
/-- **Five sums reordered** (`SC_PV`'s identity is a reordering of the same sum). -/
theorem reorder5 {G T J C : Type} [Fintype G] [Fintype T] [Fintype J] [Fintype C] (X : G → T → J → C → T → K) :
    ∑ t, ∑ g, ∑ j, ∑ c, ∑ t', X g t' j c t = ∑ g, ∑ t', ∑ j, ∑ c, ∑ t, X g t' j c t := by
  calc ∑ t, ∑ g, ∑ j, ∑ c, ∑ t', X g t' j c t = ∑ t, ∑ g, ∑ j, ∑ t', ∑ c, X g t' j c t :=
        Finset.sum_congr rfl fun t _ => Finset.sum_congr rfl fun g _ => Finset.sum_congr rfl fun j _ =>
          Finset.sum_comm
    _ = ∑ t, ∑ g, ∑ t', ∑ j, ∑ c, X g t' j c t :=
        Finset.sum_congr rfl fun t _ => Finset.sum_congr rfl fun g _ => Finset.sum_comm
    _ = ∑ g, ∑ t, ∑ t', ∑ j, ∑ c, X g t' j c t := Finset.sum_comm
    _ = ∑ g, ∑ t', ∑ t, ∑ j, ∑ c, X g t' j c t := Finset.sum_congr rfl fun g _ => Finset.sum_comm
    _ = ∑ g, ∑ t', ∑ j, ∑ t, ∑ c, X g t' j c t :=
        Finset.sum_congr rfl fun g _ => Finset.sum_congr rfl fun t' _ => Finset.sum_comm
    _ = ∑ g, ∑ t', ∑ j, ∑ c, ∑ t, X g t' j c t :=
        Finset.sum_congr rfl fun g _ => Finset.sum_congr rfl fun t' _ => Finset.sum_congr rfl fun j _ =>
          Finset.sum_comm

omit [Algebra GF K] in
/-- **`SC_PV`'s identity as finite sums**: the slot's form equals the extension's. -/
theorem pv_sum {G T J C : Type} [Fintype G] [Fintype T] [Fintype J] [Fintype C] (eg : G → K) (ej : J → K)
    (et : T → K) (ec : C → K) (A : G → J → T → T → K) (V : T → G → C → K) :
    ∑ g, ∑ t', eg g * ((∑ j, ej j * ∑ t, et t * A g j t t') * (∑ c, ec c * V t' g c))
      = ∑ t, et t * ∑ g, eg g * ∑ j, ej j * ∑ c, ec c * ∑ t', A g j t t' * V t' g c := by
  have hL : ∀ g t', eg g * ((∑ j, ej j * ∑ t, et t * A g j t t') * (∑ c, ec c * V t' g c))
      = ∑ j, ∑ c, ∑ t, eg g * ej j * et t * ec c * (A g j t t' * V t' g c) := by
    intro g t'
    rw [Finset.sum_mul_sum, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Finset.mul_sum]
    refine Finset.sum_congr rfl (fun c _ => ?_)
    rw [Finset.mul_sum, Finset.sum_mul, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun t _ => ?_)
    ring
  rw [Finset.sum_congr rfl fun g _ => Finset.sum_congr rfl fun t' _ => hL g t']
  simp only [Finset.mul_sum]
  rw [← reorder5 (fun g t' j c t => eg g * ej j * et t * ec c * (A g j t t' * V t' g c))]
  refine Finset.sum_congr rfl fun t _ => Finset.sum_congr rfl fun g _ => Finset.sum_congr rfl fun j _ =>
    Finset.sum_congr rfl fun c _ => Finset.sum_congr rfl fun t' _ => ?_
  ring

end Pv

section PvT

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

theorem splitQ_app (t : CtW) (g : CgW) (j : CjW) (c : CdW) :
    splitQ (Fin.append t (Fin.append (Fin.append g j) c)) = (t, ((g, j), c)) := splitQ_append (t, ((g, j), c))

include hX in
/-- **`SC_PV`'s target**: the extension of `relMm 15 1` at `SC_PV`'s published point, as five sums. -/
theorem pv_target (dr : List Fp2) :
    mleAt (fun y : Fin (5 + ((3 + 1) + 6)) → Bool =>
        algebraMap GF K (relMm Pb Lay B (xtW U P D) 15 1 (.q (splitQ y))))
      (fun t : Fin (5 + ((3 + 1) + 6)) => (dr.getD (ZK60.Exec.Block.ipStd 5 4 15 1 t) Fp2.zero).toK U)
      = ∑ t : Fin 5 → Bool, eqPoly (fun i : Fin 5 => (dr.getD (4 + i) Fp2.zero).toK U) (fun i => bit (t i))
        * ∑ g : Fin 3 → Bool, eqPoly (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U) (fun i => bit (g i))
          * ∑ j : Fin 1 → Bool, eqPoly (fun _ : Fin 1 => (dr.getD 3 Fp2.zero).toK U) (fun i => bit (j i))
            * ∑ c : Fin 6 → Bool, eqPoly (fun i : Fin 6 => (dr.getD (9 + i) Fp2.zero).toK U) (fun i => bit (c i))
              * ∑ t' : Fin 5 → Bool, aPl U P D 819200 14 (Fin.append (Fin.append g j) (Fin.append t t'))
                * aPl U P D 671744 14 (Fin.append t' (Fin.append g c)) := by
  have hpt : (fun t : Fin (5 + ((3 + 1) + 6)) => (dr.getD (ZK60.Exec.Block.ipStd 5 4 15 1 t) Fp2.zero).toK U)
      = Fin.append (fun i : Fin 5 => (dr.getD (4 + i) Fp2.zero).toK U)
          (Fin.append (Fin.append (fun i : Fin 3 => (dr.getD i Fp2.zero).toK U)
            (fun _ : Fin 1 => (dr.getD 3 Fp2.zero).toK U)) (fun i : Fin 6 => (dr.getD (9 + i) Fp2.zero).toK U)) := by
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
  rw [splitQ_app]
  simp only [relMm, xtW, plS, plK, map_sum, map_mul]
  refine Finset.sum_congr rfl fun t' _ => ?_
  rw [aPl_alg U P D hX, aPl_alg U P D hX]

include hX hrl in
/-- **`SC_PV`'s unmasked sum is the extension of `relMm 15 1` at its published point.** -/
theorem pv_spSum (prog : List SlotS) (pubs : PubTabs)
    (hprog : prog.getD 9 SlotS.empty = ⟨tabs9, bilIr DefW16.cstS (some 0) 1 2, [], []⟩)
    (hsh : slotShape P 9 = (8, 2, 3)) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r : SlotRec)
    (hr : rs[9]? = some r) :
    spSum P (polyS U P D prog pubs) bga rs 9
      = mleAt (fun y : Fin (5 + ((3 + 1) + 6)) → Bool =>
          algebraMap GF K (relMm Pb Lay B (xtW U P D) 15 1 (.q (splitQ y))))
        (fun t : Fin (5 + ((3 + 1) + 6)) => (r.draws.getD (ZK60.Exec.Block.ipStd 5 4 15 1 t) Fp2.zero).toK U) := by
  unfold spSum
  rw [pv_cube U P D hrl (slotShape P 9).1 (slotShape P 9).2.1 (by rw [hsh]) (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9))
    r.draws (pubs 9 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 9)) r.draws) (polyS U P D prog pubs 9 (seenOf bga rs 9))
    (fun x => by rw [polyS_seenOf U P D prog pubs bga rs 9 r hr x, hprog]),
    pv_target U P D hX Pb Lay B r.draws]
  exact pv_sum (fun g : Fin 3 → Bool => eqPoly (fun i : Fin 3 => (r.draws.getD i Fp2.zero).toK U) (fun i => bit (g i)))
    (fun j : Fin 1 → Bool => eqPoly (fun _ : Fin 1 => (r.draws.getD 3 Fp2.zero).toK U) (fun i => bit (j i)))
    (fun t : Fin 5 → Bool => eqPoly (fun i : Fin 5 => (r.draws.getD (4 + i) Fp2.zero).toK U) (fun i => bit (t i)))
    (fun c : Fin 6 → Bool => eqPoly (fun i : Fin 6 => (r.draws.getD (9 + i) Fp2.zero).toK U) (fun i => bit (c i)))
    (fun g j t t' => aPl U P D 819200 14 (Fin.append (Fin.append g j) (Fin.append t t')))
    (fun t' g c => aPl U P D 671744 14 (Fin.append t' (Fin.append g c)))

end PvT

/-! ## `SC_QZC`'s named identity -/

/-- **L36's `FormAt` at host `15` (`SC_QZC`) at the W16R2 rung**: for every algebra data `dt` whose host-15 tables are the
relation tables (the RoPE clause, LogUp's helper relations `xcQzc`, the requantizations, the contractions), on every
outcome whose verified slots passed their checks. -/
theorem formAt_qzc {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : RungS S) (hL : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 4) (b : Fin 15 → Bool), dt.cl 15 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 15 κ (.q (splitQ b)))
        else xcQzc U P D Pb Lay B bga κ b)
    (hgh : ∀ (i : Fin 2) (b : Fin 15 → Bool),
      dt.gh 15 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtW U P D) 15 i (.q (splitQ b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 15 → Bool),
      dt.mm 15 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtW U P D) 15 i (.q (splitQ b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 0 cu rt k h).Φ) bga rs 15 := by
  obtain ⟨hs15, hs5, hs9⟩ : slotShape P 15 = (15, 1, 4) ∧ slotShape P 5 = (9, 1, 2) ∧ slotShape P 9 = (8, 2, 3) := by
    simp only [slotShape, hsl]
    decide
  refine formAt_two U hcard P (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs hdef D _ dt cu rt bga rs 15
    (by decide) 5 9 (.dr 15 4) (.dr 15 5) (by rw [slot15_eq]) (by rw [slot5_eq]) (by rw [slot9_eq])
    (by norm_num) (by norm_num) hslots (fun r hr => ?_)
  have hlen : 15 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r5, hr5⟩ : ∃ r5, rs[5]? = some r5 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r9, hr9⟩ : ∃ r9, rs[9]? = some r9 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  have hcan : ∀ (j : ℕ) (rj : SlotRec), rs[j]? = some rj → ∀ x ∈ rj.draws, Fp2.Canon x := by
    intro j rj hrj
    obtain ⟨df, hdf, -⟩ := hslots j rj hrj
    rw [hdef] at hdf
    exact (defineS_ok hdf).1.2.2.2
  -- the three slots' sums
  have hsp15 := qzc_cube U P D hX hrl Pb Lay B hL hS ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).beta,
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws rfl rfl
    (pubs 15 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws)
    (hpub.qzcCos (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws)
    (hpub.qzcSin (histOf bga.1 bga.2.1 bga.2.2 (rs.take 15)) r.draws) (slotShape P 15).1 (slotShape P 15).2.1
    (by rw [hs15]) (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 15 (seenOf bga rs 15))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 15 r hr x, slot15_eq])
  have hsp5 := qmm_spSum U P D hX hrl Pb Lay B pubs hpub ioIn ioOut hs5 bga rs r5 hr5 (hcan 5 r5 hr5)
  have hsp9 := pv_spSum U P D hX hrl Pb Lay B (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs
    (slot9_eq ioIn ioOut) hs9 bga rs r9 hr9
  -- the host's polynomial
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
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · unfold segAt
      have ha : (a : ℕ) < 15 := a.isLt
      rw [dite_eq_left (by show 6 + (a : ℕ) < 21; omega), drs_getD _ 15 6 15 a ha, eval_self]
      first | done | rfl
    · unfold batched
      have hz : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 15) .zeta = 0 := rfl
      simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      have hκ : (κ : ℕ) < 4 := κ.isLt
      rw [hcl (hist.beta, hist.gamma, hist.alpha) κ t, hmuK κ hκ]
      refine congrArg₂ (· * ·) ?_ rfl
      unfold segAt
      rw [dite_eq_left (by show 0 + (κ : ℕ) < 21; omega)]
      show (r.draws.getD (0 + (κ : ℕ)) Fp2.zero).toK U = _
      rw [Nat.zero_add]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by show 4 + 0 < 21; omega)]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 4 + 1 < 21; omega)]
        first | done | rfl
    · fin_cases i
      · show algDrawAt U hist 5 (ZK60.Exec.Block.ipStd 5 4 15 0 j)
          = (((drs 5 0 15).map (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        rw [show ZK60.Exec.Block.ipStd 5 4 15 0 j = (j : ℕ) from rfl,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5,
          drs_map_hist bga rs 15 5 r.draws r5 (by decide) hr5 0 15 hist, drs_getD _ 5 0 15 j j.isLt, eval_self,
          Nat.zero_add]
      · show algDrawAt U hist 9 (ZK60.Exec.Block.ipStd 5 4 15 1 j)
          = (((drs 9 4 5 ++ drs 9 0 4 ++ drs 9 9 6).map (Sym.eval hist 15 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, List.map_append, drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 4 5 hist,
          drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 0 4 hist,
          drs_map_hist bga rs 15 9 r.draws r9 (by decide) hr9 9 6 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 15 := hj
        interval_cases jv <;> rfl
    · rw [algH_gh U _ dt 15 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 15 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtW U P D) 15 i (.q (splitQ b))) := fun i => by
      rw [algM_mm _ dt 15 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 15 hist 0
        = fun t : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 15) .tau) =>
          (r5.draws.getD t Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 5 (ZK60.Exec.Block.ipStd 5 4 15 0 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 5 _ r5 (by decide) hr5
    have hp1 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 15 hist 1
        = fun t : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 15) .tau) =>
          (r9.draws.getD (ZK60.Exec.Block.ipStd 5 4 15 1 t) Fp2.zero).toK U := by
      funext t
      show algDrawAt U hist 9 (ZK60.Exec.Block.ipStd 5 4 15 1 t) = _
      exact algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 15 9 _ r9 (by decide) hr9
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 0 < 21; omega)]
      first | done | rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 1 < 21; omega)]
      first | done | rfl

/-! ## `SC_KVZC` (host `16`) and its hosted `SC_KMM`, `SC_VMM` -/

/-- `SC_KVZC`'s table positions and shifts. -/
def rK : QzcR := ⟨0, 1, 2, 3, 4, 5, 9, 7, 11, [10], [6], [8], 12, none⟩
def kK : QzcK := ⟨7, 15, 16⟩
def shK : ℕ → ℕ := fun q => 5 + (q - 33)

/-- `SC_KVZC`'s tables: `eq(τ)`, `eq(SC_KMM's point)`, `eq(SC_VMM's point)`, `cos`, `sin`, the six `Dom::Kv` planes, the
flipped source, the three helpers. -/
def tabs16 : List TabS :=
  [.eq (drs 16 6 14) 0, .eq (drs 5 0 5 ++ drs 6 0 9) 0, .eq (drs 5 0 5 ++ drs 7 0 9) 0, .pub 0, .pub 1,
    paT 638976 14 224, paT 655360 14 226, paT 671744 14 228, paT 688128 14 230, paT 704512 14 232,
    paT 720896 14 234, flT 638976 14 8 236, hT 557056 573440 14 136, hT 589824 606208 14 138,
    hT 622592 638976 14 140]

theorem slot16_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 16 SlotS.empty
    = ⟨tabs16, qzcIr DefW16.cstS rK kK (lksS cfgRungW16 shK .Kv) (drs 16 0 4) (drs 16 4 2)
        (fun j => Sym.pow Sym.zero j) [],
      [(6, .dr 16 4), (7, .dr 16 5)], [.dr 16 4, .dr 16 5]⟩ := rfl

theorem slot6_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 6 SlotS.empty
    = ⟨[fxT 147456 14 (drs 5 0 5) 9 148 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

theorem slot7_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 7 SlotS.empty
    = ⟨[fxT 147456 14 (drs 5 0 5) 9 150 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩ := rfl

section KVals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `SC_KVZC`'s private entries at a cube point. -/
noncomputable def planesK (P : BlockParams) (D : CmData K P) (b : Fin 14 → Bool) : List K :=
  [aPl U P D 638976 14 b, aPl U P D 655360 14 b, aPl U P D 671744 14 b, aPl U P D 688128 14 b,
    aPl U P D 704512 14 b, aPl U P D 720896 14 b, aPl U P D 638976 14 (flipB 8 b),
    hPl U P D 557056 573440 14 b, hPl U P D 589824 606208 14 b, hPl U P D 622592 638976 14 b]

/-- **`SC_KVZC`'s value list at a cube point with the zero extension.** -/
theorem kvzc_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 14 → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e b))
      = eqv U (drs 16 6 14) ev 14 b :: eqv U (drs 5 0 5 ++ drs 6 0 9) ev 14 b
        :: eqv U (drs 5 0 5 ++ drs 7 0 9) ev 14 b
        :: ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U :: ((pub 1).getD (msbIndex 14 b) Fp2.zero).toK U
        :: planesK U P D b := by
  have l0 : ((drs 16 6 14).map ev).length = 14 := drs_length _ _ _ ev
  have l1 : ((drs 5 0 5 ++ drs 6 0 9).map ev).length = 14 := by simp [drs]
  have l2 : ((drs 5 0 5 ++ drs 7 0 9).map ev).length = 14 := by simp [drs]
  simp only [tabs16, hT, List.map_cons, List.map_nil, eqT_eval, pubT_eval, paT_eval, flT_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 14 e b _ l0, tabK_eqFull_cpt U P D 14 e b _ l1, tabK_eqFull_cpt U P D 14 e b _ l2,
    tabK_pub_cpt U P D 14 e b, tabK_pub_cpt U P D 14 e b, tabK_fl_cpt U P D hrl 14 e b 8 (by norm_num)]
  simp only [tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    castB_rfl]
  rfl

/-- `SC_KVZC`'s lookups, read at a history and draws, in the field. -/
noncomputable def lksK (hist : Hist) (dr : List Fp2) : List (LkD K) :=
  ((lksS cfgRungW16 shK .Kv).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 16 dr))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

theorem kvzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((qzcIr DefW16.cstS rK kK (lksS cfgRungW16 shK .Kv) (drs 16 0 4) (drs 16 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 16 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none (((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 12 (fun k => (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD (1 + k) 0)
              0 (lksK U hist dr)
            + gV v none * batchV (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U)) (qzcClauses (cstK U) rK kK v))
          (reqV (cstK U) v 15 5 [6]) (reqV (cstK U) v 16 7 [8]) := by
  rw [qzcIr_map, qzcIr_map, cstS_map, qzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

theorem lksK_pos (hist : Hist) (dr : List Fp2) : ∀ l ∈ lksK U hist dr, ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  unfold lksK lksS at hl
  simp only [List.map_map, List.mem_map, Function.comp] at hl
  obtain ⟨l0, -, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map, Function.comp] at ht
  obtain ⟨t0, -, rfl⟩ := ht
  simp only [shK]
  omega

theorem lksK_length (hist : Hist) (dr : List Fp2) : (lksK U hist dr).length = 6 := by
  unfold lksK lksS
  simp only [List.length_map]
  decide

end KVals

section KRels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- `SC_KVZC`'s value list without the draws. -/
noncomputable def valsXK (b : Fin 14 → Bool) : List K :=
  0 :: 0 :: 0 :: algebraMap GF K (B.cosK (splitK b)) :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b

/-- **`SC_KVZC`'s batch entries past the RoPE clause**: LogUp's three helper relations, read without the draws. -/
noncomputable def xcKvzc (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 14 → Bool) : K :=
  (0 :: lkRels (cstK U) (valsXK U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).getD κ 0

include hX in
/-- `Dom::Kv`'s plane, embedded. -/
theorem alg_plK (off : ℕ) (x : CtW × (CgW × CdW)) :
    algebraMap GF K (plK U P D off x) = aPl U P D off 14 (Fin.append x.1 (Fin.append x.2.1 x.2.2)) :=
  aPl_alg U P D hX off 14 _

end KRels

theorem append_splitK (b : Fin 14 → Bool) :
    Fin.append (splitK b).1 (Fin.append (splitK b).2.1 (splitK b).2.2) = b := by
  funext i
  fin_cases i <;> rfl

theorem append_flipK (b : Fin 14 → Bool) :
    Fin.append (splitK b).1 (Fin.append (splitK b).2.1 (Function.update (splitK b).2.2 0 (!(splitK b).2.2 0)))
      = flipB 8 b := by
  funext i
  fin_cases i <;> rfl

section KRels2

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

include hX hL

theorem kvzc_relCl (b : Fin 14 → Bool) :
    algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 0 (.kv (splitK b)))
      = algebraMap GF K (B.cosK (splitK b)) * aPl U P D 638976 14 b
        + algebraMap GF K (B.sinK (splitK b)) * aPl U P D 638976 14 (flipB 8 b)
        - 2 ^ 7 * aPl U P D 704512 14 b - aPl U P D 720896 14 b + 2 ^ 6 := by
  have hg := gK_one B hL (splitK b)
  simp only [relCl, xtW, remR, remVal, hg, one_mul, List.getD_cons_zero, List.length_cons, List.length_nil,
    hL.flip, (by norm_num : (7 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK U P D hX, append_splitK, append_flipK]

theorem kvzc_relGh0 (hS : RungS S) (b : Fin 14 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 0 (.kv (splitK b)))
      = 2 ^ 15 * aPl U P D 638976 14 b + aPl U P D 655360 14 b - 2 ^ 14 := by
  have hg := gK_one B hL (splitK b)
  simp only [relGh, xtW, remR, remVal, hg, one_mul, hS.sk, List.getD_cons_zero, List.length_cons, List.length_nil,
    (by norm_num : (15 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK U P D hX, append_splitK]
  try norm_num

theorem kvzc_relGh1 (hS : RungS S) (b : Fin 14 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 1 (.kv (splitK b)))
      = 2 ^ 16 * aPl U P D 671744 14 b + aPl U P D 688128 14 b - 2 ^ 15 := by
  have hg := gK_one B hL (splitK b)
  simp only [relGh, xtW, remR, remVal, hg, one_mul, hS.sv, List.getD_cons_zero, List.length_cons, List.length_nil,
    (by norm_num : (16 : ℕ) ≤ 16), ↓reduceIte]
  simp only [map_add, map_sub, map_mul, map_pow, map_ofNat, alg_plK U P D hX, append_splitK]
  try norm_num

theorem kvzc_clause (e0 e1 e2 : K) (b : Fin 14 → Bool) :
    qzcClauses (cstK U) rK kK (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK b))
      :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b)
      = [algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 0 (.kv (splitK b)))] := by
  rw [kvzc_relCl U P D hX Pb Lay B hL b]
  unfold qzcClauses
  rw [show kK.rope = 7 from rfl, cstK_negpow U 7 (by norm_num), show 7 - 1 = 6 from rfl, cstK_pow U 6 (by norm_num)]
  simp only [rK, L16, planesK, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  congr 1
  ring

theorem kvzc_gh (hS : RungS S) (e0 e1 e2 c s : K) (b : Fin 14 → Bool) :
    reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesK U P D b) 15 5 [6]
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 0 (.kv (splitK b)))
      ∧ reqV (cstK U) (e0 :: e1 :: e2 :: c :: s :: planesK U P D b) 16 7 [8]
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 1 (.kv (splitK b))) := by
  rw [kvzc_relGh0 U P D hX Pb Lay B hL hS b, kvzc_relGh1 U P D hX Pb Lay B hL hS b]
  unfold reqV
  rw [cstK_pow U 15 (by norm_num), cstK_pow U 16 (by norm_num), show 15 - 1 = 14 from rfl,
    show 16 - 1 = 15 from rfl, cstK_negpow U 14 (by norm_num), cstK_negpow U 15 (by norm_num)]
  simp only [L16, planesK, List.getD_cons_succ, List.getD_cons_zero, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, cstK_p16_zero, one_mul, add_zero]
  constructor <;> ring

end KRels2

section KBatch

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

include hX hL in
theorem kvzc_Z (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (mu : List K) (e0 e1 e2 : K) (b : Fin 14 → Bool) :
    logupSem (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK b))
          :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b) 12 (fun k => mu.getD (1 + k) 0) 0 (lksK U hist dr)
        + gV (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK b))
          :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b) none
          * batchV mu (qzcClauses (cstK U) rK kK (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK b))
            :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b))
      = ∑ κ : Fin 4, mu.getD κ 0 * (if (κ : ℕ) < 1
          then algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 κ (.kv (splitK b)))
          else xcKvzc U P D Pb Lay B bga κ b) := by
  have hlk : lksK U hist dr = lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [] := by
    unfold lksK
    rw [lksS_eval cfgRungW16 shK .Kv hist (histOf bga.1 bga.2.1 bga.2.2 []) 16 16 dr [] ha hgm]
  have hcg : lkRels (cstK U) (e0 :: e1 :: e2 :: algebraMap GF K (B.cosK (splitK b))
        :: algebraMap GF K (B.sinK (splitK b)) :: planesK U P D b) 12 0 (lksK U hist dr)
      = lkRels (cstK U) (valsXK U P D Pb Lay B b) 12 0 (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) []) := by
    rw [hlk]
    refine lkRels_congr (cstK U) _ _ 12 0 _ (fun l hl t ht => ?_) (fun i _ => ?_)
    · have h3 := lksK_pos U _ _ l hl t ht
      obtain ⟨j, hj⟩ : ∃ j, t.2 = j + 3 := ⟨t.2 - 3, by omega⟩
      rw [hj]
      simp only [valsXK, List.getD_cons_succ]
    · rw [show 12 + (0 + i) = (9 + i) + 3 by omega]
      simp only [valsXK, List.getD_cons_succ]
  have hlen : (lkRels (cstK U) (valsXK U P D Pb Lay B b) 12 0
      (lksK U (histOf bga.1 bga.2.1 bga.2.2 []) [])).length = 3 := by
    simp [lkRels_length, lksK_length]
  obtain ⟨x1, x2, x3, hx⟩ := List.length_eq_three.mp hlen
  have hxc : ∀ κ, xcKvzc U P D Pb Lay B bga κ b = ([0, x1, x2, x3] : List K).getD κ 0 := by
    intro κ
    unfold xcKvzc
    rw [hx]
  rw [logupSem_eq_wsum, hcg, hx, kvzc_clause U P D hX Pb Lay B hL, gV_none]
  rw [Fin.sum_univ_eq_sum_range (fun κ => mu.getD κ 0 * (if κ < 1
    then algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 κ (.kv (splitK b))) else xcKvzc U P D Pb Lay B bga κ b)) 4]
  simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add, hxc, wsum, batchV, List.zipIdx_cons,
    List.zipIdx_nil, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_succ,
    List.getD_cons_zero, add_zero, one_mul]
  norm_num
  ring

end KBatch

section KCube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

theorem kvzc_off (e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin 14 → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) :
    ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 0 0 = 0
      ∧ ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 1 0 = 0
      ∧ ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 2 0 = 0 := by
  simp only [tabs16, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D 14 e b y hy _ _, tabK_eq_off U P D 14 e b y hy _ _, tabK_eq_off U P D 14 e b y hy _ _⟩

include hX hrl hL in
/-- **`SC_KVZC`'s cube sum.** -/
theorem kvzc_cube (hS : RungS S) (bga : Fp2 × Fp2 × Fp2) (hist : Hist) (dr : List Fp2) (ha : hist.alpha = bga.2.2)
    (hgm : hist.gamma = bga.2.1) (pub : ℕ → List Fp2)
    (hcos : ∀ b, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.cosK (splitK b)))
    (hsin : ∀ b, ((pub 1).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.sinK (splitK b)))
    (n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((qzcIr DefW16.cstS rK kK (lksS cfgRungW16 shK .Kv) (drs 16 0 4) (drs 16 4 2)
        (fun j => Sym.pow Sym.zero j) []).map (Sym.eval hist 16 dr)).map (Fp2.toK U))
      ((tabs16.map (TabS.eval (Sym.eval hist 16 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ t : Fin 14 → Bool,
      hostPoly (fun a : Fin 14 => (((drs 16 6 14).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U)
        (fun t => ∑ κ : Fin 4, (((drs 16 0 4).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 κ (.kv (splitK t)))
            else xcKvzc U P D Pb Lay B bga κ t))
        ![(((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 0 0,
          (((drs 16 4 2).map (Sym.eval hist 16 dr)).map (Fp2.toK U)).getD 1 0]
        ![fun a : Fin 14 => (((drs 5 0 5 ++ drs 6 0 9).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U,
          fun a : Fin 14 => (((drs 5 0 5 ++ drs 7 0 9).map (Sym.eval hist 16 dr)).getD a Fp2.zero).toK U]
        (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 i (.kv (splitK t)))) t := by
  subst hn
  set ev := Sym.eval hist 16 dr with hev
  rw [cubeSum_host 14 e (fun x => (tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e x)) 0 1 2 none none
    (((drs 16 4 2).map ev).map (Fp2.toK U))
    (fun v => logupSem (cstK U) v 12 (fun k => (((drs 16 0 4).map ev).map (Fp2.toK U)).getD (1 + k) 0) 0
        (lksK U hist dr)
      + gV v none * batchV (((drs 16 0 4).map ev).map (Fp2.toK U)) (qzcClauses (cstK U) rK kK v))
    (fun v => reqV (cstK U) v 15 5 [6]) (fun v => reqV (cstK U) v 16 7 [8]) f
    (fun x => by rw [hf x, kvzc_irEval U hist dr])
    (fun b y hy => kvzc_off U P D e ev pub b y hy)
    (fun a : Fin 14 => (((drs 16 6 14).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin 14 => (((drs 5 0 5 ++ drs 6 0 9).map ev).getD a Fp2.zero).toK U,
      fun a : Fin 14 => (((drs 5 0 5 ++ drs 7 0 9).map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [kvzc_vals U P D hrl e b ev pub]; rfl)
    (fun b => by rw [kvzc_vals U P D hrl e b ev pub]; rfl)
    (fun b => by rw [kvzc_vals U P D hrl e b ev pub]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv := kvzc_vals U P D hrl e t ev pub
  rw [hcos t, hsin t] at hv
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ (fun i => ?_)
  · show logupSem (cstK U) ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) 12 _ 0 _
        + gV ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) none * _ = _
    rw [hv]
    exact kvzc_Z U P D hX Pb Lay B hL bga hist dr ha hgm _ _ _ _ t
  · obtain ⟨g0, g1⟩ := kvzc_gh U P D hX Pb Lay B hL hS (eqv U (drs 16 6 14) ev 14 t)
      (eqv U (drs 5 0 5 ++ drs 6 0 9) ev 14 t) (eqv U (drs 5 0 5 ++ drs 7 0 9) ev 14 t)
      (algebraMap GF K (B.cosK (splitK t))) (algebraMap GF K (B.sinK (splitK t))) t
    fin_cases i
    · show gV ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) none
          * reqV (cstK U) ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) 15 5 [6] = _
      rw [hv, gV_none, one_mul, g0]
    · show gV ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) none
          * reqV (cstK U) ((tabs16.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e t))) 16 7 [8] = _
      rw [hv, gV_none, one_mul, g1]

end KCube

section KMm

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- A split claim point: the first five coordinates `SC_QMM`'s draws, the rest the hosted slot's own. -/
theorem split_pt (d5 dj : List Fp2) :
    Fin.append (fun i : Fin 5 => (d5.getD i Fp2.zero).toK U) (fun a : Fin 9 => (dj.getD (0 + a) Fp2.zero).toK U)
      = fun t : Fin (5 + 9) => if (t : ℕ) < 5 then (d5.getD t Fp2.zero).toK U else (dj.getD (t - 5) Fp2.zero).toK U := by
  funext t
  refine Fin.addCases (fun i => ?_) (fun i => ?_) t
  · rw [Fin.append_left]
    simp
  · rw [Fin.append_right]
    simp

include hX hrl in
/-- **`SC_KMM`'s (`SC_VMM`'s) unmasked sum is the extension of `relMm 16 i` at its split point.** -/
theorem kvmm_spSum (pubs : PubTabs) (s mrow : ℕ) (hs : s = 6 ∨ s = 7) (i : Fin 2)
    (prog : List SlotS)
    (hprog : prog.getD s SlotS.empty = ⟨[fxT 147456 14 (drs 5 0 5) 9 mrow 0, .pub 0], mmIr DefW16.cstS 0 1, [], []⟩)
    (hsh : (slotShape P s).1 = 9) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (r5 r : SlotRec)
    (hr5 : rs[5]? = some r5) (hr : rs[s]? = some r)
    (hW : ∀ c, ((pubs s (histOf bga.1 bga.2.1 bga.2.2 (rs.take s)) r.draws 0).getD (msbIndex 9 c) Fp2.zero).toK U
      = ∑ y : Fin 9 → Bool, eqDr U r.draws 0 9 y
        * algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) c (splitGD y))) :
    spSum P (polyS U P D prog pubs) bga rs s
      = mleAt (fun y : Fin (5 + 9) → Bool => algebraMap GF K (relMm Pb Lay B (xtW U P D) 16 i (.kv (splitK y))))
          (fun t : Fin (5 + 9) => if (t : ℕ) < 5 then (r5.draws.getD t Fp2.zero).toK U
            else (r.draws.getD (t - 5) Fp2.zero).toK U) := by
  rw [mm_spSum U P D hrl prog pubs s 147456 mrow 5 9 9 (drs 5 0 5) (by simp [drs]) hsh (by norm_num) hprog bga rs r hr
    (fun c y => algebraMap GF K ((if (i : ℕ) = 0 then B.Wk else B.Wv) c (splitGD y)))
    (fun a => (r.draws.getD (0 + a) Fp2.zero).toK U) hW]
  have h5s : 5 < s := by omega
  rw [drs_map_hist bga rs s 5 r.draws r5 h5s hr5 0 5 (histOf bga.1 bga.2.1 bga.2.2 [])]
  have hpt : Fin.append (fun i : Fin 5 => (((drs 5 0 5).map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 5
      r5.draws)).getD i Fp2.zero).toK U) (fun a : Fin 9 => (r.draws.getD (0 + a) Fp2.zero).toK U)
      = fun t : Fin (5 + 9) => if (t : ℕ) < 5 then (r5.draws.getD t Fp2.zero).toK U
          else (r.draws.getD (t - 5) Fp2.zero).toK U := by
    refine Eq.trans ?_ (split_pt U r5.draws r.draws)
    congr 1
    funext a
    rw [drs_getD _ 5 0 5 a a.isLt, eval_self, Nat.zero_add]
  rw [hpt]
  congr 1
  funext y
  fin_cases i
  · simp only [relMm, xtW, map_sum, map_mul]
    refine Finset.sum_congr rfl (fun c _ => ?_)
    rw [alg_plD U P D hX]
    rfl
  · simp only [relMm, xtW, map_sum, map_mul]
    refine Finset.sum_congr rfl (fun c _ => ?_)
    rw [alg_plD U P D hX]
    rfl

end KMm

/-- **L36's `FormAt` at host `16` (`SC_KVZC`) at the W16R2 rung.** -/
theorem formAt_kvzc {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (_hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : RungS S) (hL : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 4) (b : Fin 14 → Bool), dt.cl 16 cu rt bga κ b
      = if (κ : ℕ) < 1 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 16 κ (.kv (splitK b)))
        else xcKvzc U P D Pb Lay B bga κ b)
    (hgh : ∀ (i : Fin 2) (b : Fin 14 → Bool),
      dt.gh 16 cu rt i b = algebraMap GF K (relGh Pb Lay B (xtW U P D) 16 i (.kv (splitK b))))
    (hmm : ∀ (i : Fin 2) (b : Fin 14 → Bool),
      dt.mm 16 cu rt i b = algebraMap GF K (relMm Pb Lay B (xtW U P D) 16 i (.kv (splitK b))))
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 0 cu rt k h).Φ) bga rs 16 := by
  obtain ⟨hs16, hs6, hs7⟩ : slotShape P 16 = (14, 1, 4) ∧ slotShape P 6 = (9, 1, 2) ∧ slotShape P 7 = (9, 1, 2) := by
    simp only [slotShape, hsl]
    decide
  refine formAt_two U hcard P (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs hdef D _ dt cu rt bga rs 16
    (by decide) 6 7 (.dr 16 4) (.dr 16 5) (by rw [slot16_eq]) (by rw [slot6_eq]) (by rw [slot7_eq])
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
  have hsp16 := kvzc_cube U P D hX hrl Pb Lay B hL hS ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).beta,
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)).alpha)
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws rfl rfl
    (pubs 16 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws)
    (hpub.kvCos (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws)
    (hpub.kvSin (histOf bga.1 bga.2.1 bga.2.2 (rs.take 16)) r.draws) (slotShape P 16).1 (slotShape P 16).2.1
    (by rw [hs16]) (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 16 (seenOf bga rs 16))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 16 r hr x, slot16_eq])
  have hsp6 := kvmm_spSum U P D hX hrl Pb Lay B pubs 6 148 (Or.inl rfl) 0
    (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (slot6_eq ioIn ioOut) (by rw [hs6]) bga rs r5 r6 hr5 hr6
    (fun c => hpub.wk _ _ (hcan 6 r6 hr6) c)
  have hsp7 := kvmm_spSum U P D hX hrl Pb Lay B pubs 7 150 (Or.inr rfl) 1
    (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) (slot7_eq ioIn ioOut) (by rw [hs7]) bga rs r5 r7 hr5 hr7
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
  · -- the host's sum
    refine Finset.sum_congr rfl (fun t _ => ?_)
    refine hostPoly_ext _ _ _ _ _ _ _ _ _ _ _ t (fun a => ?_) ?_ (fun i => ?_) (fun i j => ?_) (fun i => ?_)
    · unfold segAt
      have ha : (a : ℕ) < 14 := a.isLt
      rw [dite_eq_left (by show 6 + (a : ℕ) < 20; omega), drs_getD _ 16 6 14 a ha, eval_self]
      first | done | rfl
    · unfold batched
      have hz : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 16) .zeta = 0 := rfl
      simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      have hκ : (κ : ℕ) < 4 := κ.isLt
      rw [hcl (hist.beta, hist.gamma, hist.alpha) κ t, hmuK κ hκ]
      refine congrArg₂ (· * ·) ?_ rfl
      unfold segAt
      rw [dite_eq_left (by show 0 + (κ : ℕ) < 20; omega)]
      show (r.draws.getD (0 + (κ : ℕ)) Fp2.zero).toK U = _
      rw [Nat.zero_add]
    · fin_cases i
      · unfold segAt
        rw [dite_eq_left (by show 4 + 0 < 20; omega)]
        first | done | rfl
      · unfold segAt
        rw [dite_eq_left (by show 4 + 1 < 20; omega)]
        first | done | rfl
    · fin_cases i
      · show (if (j : ℕ) < 5 then algDrawAt U hist 5 j else algDrawAt U hist 6 ((j : ℕ) - 5))
          = (((drs 5 0 5 ++ drs 6 0 9).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, drs_map_hist bga rs 16 5 r.draws r5 (by decide) hr5 0 5 hist,
          drs_map_hist bga rs 16 6 r.draws r6 (by decide) hr6 0 9 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 14 := hj
        interval_cases jv <;> rfl
      · show (if (j : ℕ) < 5 then algDrawAt U hist 5 j else algDrawAt U hist 7 ((j : ℕ) - 5))
          = (((drs 5 0 5 ++ drs 7 0 9).map (Sym.eval hist 16 r.draws)).getD j Fp2.zero).toK U
        rw [List.map_append, drs_map_hist bga rs 16 5 r.draws r5 (by decide) hr5 0 5 hist,
          drs_map_hist bga rs 16 7 r.draws r7 (by decide) hr7 0 9 hist,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
          algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7]
        obtain ⟨jv, hj⟩ := j
        have hj' : jv < 14 := hj
        interval_cases jv <;> rfl
    · rw [algH_gh U _ dt 16 cu rt hist i (fun h => absurd h.1 (by decide))]
      exact hgh i t
  · -- the hosted sums
    rw [Fin.sum_univ_two]
    have hM : ∀ i : Fin 2, algM (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 16 cu rt i
        = fun b => algebraMap GF K (relMm Pb Lay B (xtW U P D) 16 i (.kv (splitK b))) := fun i => by
      rw [algM_mm _ dt 16 cu rt i (fun h => absurd h.1 (by decide))]
      exact funext (hmm i)
    have hp0 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 16 hist 0
        = fun t : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 16) .tau) => if (t : ℕ) < 5 then (r5.draws.getD t Fp2.zero).toK U
            else (r6.draws.getD ((t : ℕ) - 5) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < 5 then algDrawAt U hist 5 t else algDrawAt U hist 6 ((t : ℕ) - 5)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 6 _ r6 (by decide) hr6]
    have hp1 : algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 16 hist 1
        = fun t : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 16) .tau) => if (t : ℕ) < 5 then (r5.draws.getD t Fp2.zero).toK U
            else (r7.draws.getD ((t : ℕ) - 5) Fp2.zero).toK U := by
      funext t
      show (if (t : ℕ) < 5 then algDrawAt U hist 5 t else algDrawAt U hist 7 ((t : ℕ) - 5)) = _
      rw [algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 5 _ r5 (by decide) hr5,
        algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 16 7 _ r7 (by decide) hr7]
    rw [hM 0, hM 1, hp0, hp1]
    refine congrArg₂ (· + ·) (congrArg₂ (· * ·) ?_ rfl) (congrArg₂ (· * ·) ?_ rfl)
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 0 < 20; omega)]
      first | done | rfl
    · unfold segAt
      beta_reduce
      rw [dite_eq_left (by show 4 + 1 < 20; omega)]
      first | done | rfl

end ZK60.Exec.Block.Join.W16.Qkv
