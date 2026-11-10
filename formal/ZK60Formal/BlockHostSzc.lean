/-
D63 lane L44 (2026-11-10), host `SC_SZC` (slot 17), part 1: **the program at the rung, the value list on the cube,
the batch's entries past the named clauses (`xcSzc`), and the slot's polynomial at a cube point**.

* `tabs17`, `tabs4`, `tabs8`, **`slot17_eq`**, **`slot4_eq`**, **`slot8_eq`**: slots `SC_SZC`, `SC_RS`, `SC_SCORE` of
  lane L35's program at the rung, as explicit tables, IR and hosted list (by evaluation);
* `restS`: `SC_SZC`'s entries from position `3` on (the mask, the ten `Dom::S` planes, `MX`, `SUM`, the five LogUp
  helpers and the exp helper); **`szc_vals`**: the value list at a cube point with the zero extension;
* **`xcSzc`**: the batch's entries `4 … 9` (the five LogUp helper relations and the exp tuple's relation) on the value
  list without the draws;
* **`szc_point`**: `SC_SZC`'s polynomial at a cube point is `eq(τ)·Σ_κ μ_κ·c_κ + ν₀·eq(p_ht)·(SUM + λ) + ν₁·eq(P₁)·h₁`
  with `c_κ` the named relations (`relCl 17`) and `xcSzc`, `h₁ = relGh 17 1`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockHostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Szc

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi hostPhi_eq batched SlotPoly segAt mle2 mleAt_append mleAt_rowOnly
  mleAt_lin2 mleAt_one rs_cubeSum rs_host_cubeSum eqPoly_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV L16 reqV batchV szcIr szcClauses szcDelta szcExp szcIr_eval SzcR
  SzcK rsIr rsIr_eval bilIr bilIr_eval LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (szcIr_map rsIr_map bilIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Exec.Slot.W16R2 (segLn segOff segSum shRungW16)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The three slots at the rung -/

/-- The draws `a … a + n − 1` of slot `s`, as expressions. -/
def drs (s a n : ℕ) : List Sym := (List.range n).map fun i => Sym.dr s (a + i)

theorem drs_length (ev : Sym → Fp2) (s a n : ℕ) : ((drs s a n).map ev).length = n := by
  simp [drs]

theorem drs_getD (ev : Sym → Fp2) (s a n i : ℕ) (hi : i < n) :
    ((drs s a n).map ev).getD i Fp2.zero = ev (.dr s (a + i)) := by
  unfold drs
  rw [List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hi]
  rfl

/-- An `A` table on its own coordinates. -/
def taA (off log m : ℕ) : TabS := .priv ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, 0⟩

/-- An `H` table (`re + u·im`) on `Dom::S`'s `14` coordinates. -/
def taH (re im m : ℕ) : TabS := .priv ⟨.h, [(re, false), (im, true)], 14, DefW16.rhoC 0 14, m, 0⟩

/-- `SC_SZC`'s tables: `eq(τ)`, `eq(p_ht)`, `eq(P_score)`, the mask, the ten `Dom::S` planes, `MX`, `SUM`, the five
LogUp helpers, the exp helper. -/
def tabs17 : List TabS :=
  [.eq (drs 17 0 14) 0, .eq (drs 4 0 9) 0, .eq (drs 8 0 14) 0, .pub 0,
   taA 737280 14 238, taA 753664 14 240, taA 770048 14 242, taA 786432 14 244, taA 802816 14 246,
   taA 819200 14 248, taA 835584 14 250, taA 851968 14 252, taA 868352 14 254, taA 884736 14 256,
   taA 65536 9 258, taA 81920 9 260,
   taH 655360 671744 142, taH 688128 704512 144, taH 720896 737280 146, taH 753664 770048 148,
   taH 786432 802816 150, taH 819200 835584 152]

/-- `SC_SZC`'s table positions. -/
def RSz : SzcR := ⟨0, 1, 2, 3, 4, 7, 8, 9, [10, 11], [12, 13], [5, 6], 14, 15, 16, 21, none, none⟩

theorem RSz_gS : RSz.gS = none := rfl

/-- `SC_SZC`'s constants: `−MASK_SCORE = 127`, `f_p = 12`, the score shift `18`. -/
def KSz : SzcK := ⟨127, 12, 18⟩

/-- The plane-to-table map of `SC_SZC` (`Dom::S`'s planes start at id `39`). -/
def shapedS (q : ℕ) : ℕ := 4 + (q - 39)

/-- `SC_SZC`'s lookups (`lookups_w16` on `Dom::S`). -/
abbrev lksS17 : List (LkD Sym) := DefW16.lksS DefW16.cfgRungW16 shapedS .S

theorem lksS17_length : lksS17.length = 9 := by decide

def muS : List Sym := drs 17 14 10
def nuS : List Sym := [.dr 17 24, .dr 17 25]
def amdS : Sym := .sub .alpha (.gtag 129)
def nbS : Sym := .neg .beta

/-- `SC_SZC`'s IR at the rung. -/
def irS : ZK60.Exec.Slot.Ir Sym :=
  szcIr DefW16.cstS RSz KSz lksS17 muS nuS amdS nbS (.dr 4 9) (fun j => Sym.pow Sym.zero j) []

theorem slot17_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 17 SlotS.empty
    = ⟨tabs17, irS, [(4, .mul (.dr 17 24) (.base 32)), (8, .dr 17 25)], [.dr 17 24, .dr 17 25]⟩ := rfl

/-- `SC_RS`'s tables: `eq(p_ht)` on the first nine variables, the mask, `E`, `ZSEL`. -/
def tabs4 : List TabS := [.eq (drs 4 0 9) 0, .pub 0, taA 802816 14 142, taA 786432 14 144]

theorem slot4_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 4 SlotS.empty
    = ⟨tabs4, rsIr DefW16.cstS 0 1 2 3 none (.dr 4 9), [], []⟩ := rfl

/-- `SC_SCORE`'s tables: `eq(r_g)` on the first three variables, `QR` read at `(r_t, ·, r_hj, ·)`, `KR` read at
`(r_3, ·, ·)` (extension round `1`). -/
def tabs8 : List TabS :=
  [.eq (drs 8 0 3) 0,
   .priv ⟨.a, [(507904, false)], 15,
     (drs 8 4 5).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ (drs 8 3 1).map CoordS.fixed ++ DefW16.rhoC 3 9, 152, 0⟩,
   .priv ⟨.a, [(704512, false)], 14, (drs 8 9 5).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ DefW16.rhoC 3 9, 154, 1⟩]

theorem slot8_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 8 SlotS.empty
    = ⟨tabs8, bilIr DefW16.cstS (some 0) 1 2, [], []⟩ := rfl

/-- The rung's slot shapes of slots `17`, `4`, `8`. -/
theorem slotShape_szc (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots) :
    slotShape P 17 = (14, 1, 4) ∧ slotShape P 4 = (14, 1, 3) ∧ slotShape P 8 = (9, 2, 3) := by
  simp only [slotShape, hsl]
  decide

/-! ## The value list of `SC_SZC` at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The first nine coordinates of a `Dom::S` bit vector (`Dom::Ht`'s). -/
def hd9 (b : Fin 14 → Bool) : Fin 9 → Bool := fun a => b (Fin.castAdd 5 a)

theorem hd9_append (r : Fin 9 → Bool) (j : Fin 5 → Bool) : hd9 (Fin.append r j) = r := by
  funext a
  exact Fin.append_left r j a

/-- **`SC_SZC`'s entries from position `3` on**: the mask, the ten `Dom::S` planes (`S8`, `rs`, `ZSEL`, `E`, `PP`,
`sr`, `sg`), `MX`, `SUM`, the five LogUp helpers and the exp helper. -/
noncomputable def restS (P : BlockParams) (D : CmData K P) (mk : K) (b : Fin 14 → Bool) : List K :=
  [mk, aPl U P D 737280 14 b, aPl U P D 753664 14 b, aPl U P D 770048 14 b, aPl U P D 786432 14 b,
    aPl U P D 802816 14 b, aPl U P D 819200 14 b, aPl U P D 835584 14 b, aPl U P D 851968 14 b,
    aPl U P D 868352 14 b, aPl U P D 884736 14 b, aPl U P D 65536 9 (hd9 b), aPl U P D 81920 9 (hd9 b),
    hPl U P D 655360 671744 14 b, hPl U P D 688128 704512 14 b, hPl U P D 720896 737280 14 b,
    hPl U P D 753664 770048 14 b, hPl U P D 786432 802816 14 b, hPl U P D 819200 835584 14 b]

/-- **`SC_SZC`'s value list at a cube point with the zero extension.** -/
theorem szc_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (e : ℕ) (b : Fin 14 → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (tabs17.map (TabS.eval ev pub)).map (tabK U P D 14 e (cpt 14 e b))
      = eqPoly (fun a : Fin 14 => (((drs 17 0 14).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a))
        :: eqPoly (fun a : Fin 9 => (((drs 4 0 9).map ev).getD a Fp2.zero).toK U) (fun a => bit (hd9 b a))
        :: eqPoly (fun a : Fin 14 => (((drs 8 0 14).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a))
        :: restS U P D (((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U) b := by
  simp only [tabs17, taA, taH, List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, hTab_eval]
  rw [tabK_eqFull_cpt U P D 14 e b _ (drs_length ev 17 0 14),
    tabK_eqHead_cpt U P D 14 e b _ 9 (drs_length ev 4 0 9) (by norm_num),
    tabK_eqFull_cpt U P D 14 e b _ (drs_length ev 8 0 14), tabK_pub_cpt]
  simp only [tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
    tabK_paHead_cpt U P D hrl 14 e b 9 (by norm_num) (by norm_num),
    tabK_ph_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
  rfl

end Vals

/-! ## The batch's entries past the named clauses -/

section Xc

variable {K : Type} [Field K] [Algebra GF K]

/-- The value list without the draws: the `eq` entries `0`, the mask the public one, the planes. -/
noncomputable def valsX (U : K) (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape}
    {Pb : ZK60.Block.BlockPublic S} {Lay : W16Layout S CtW CwW CgW CjW CdW CfW} (B : W16Pub S Pb Lay)
    (b : Fin 14 → Bool) : List K :=
  0 :: 0 :: 0 :: restS U P D (algebraMap GF K (B.mask (splitS b))) b

/-- `SC_SZC`'s lookups read in the field, at `α`, `γ` of `bga = (β, γ, α)`. -/
noncomputable def lksK (U : K) (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  (lksS17.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 []))).map
    (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U))

/-- **The batch's entries of `SC_SZC` past its four named clauses**: entries `4 … 8` LogUp's five helper relations,
entry `9` the exp tuple's relation, on the value list without the draws. -/
noncomputable def xcSzc (U : K) (P : BlockParams) (D : CmData K P) {S : ZK60.Block.BlockShape}
    (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin 14 → Bool) : K :=
  (List.replicate 4 0 ++ lkRels (cstK U) (valsX U P D B b) 16 0 (lksK U bga)
    ++ [szcExp (cstK U) RSz KSz (valsX U P D B b)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] amdS).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] nbS).toK U)]).getD κ 0

end Xc

/-! ## Generic list facts -/

section Lists

variable {R : Type} [CommRing R]

theorem getD_cons3 (e0 e1 e2 : R) (rest : List R) (i : ℕ) (hi : 3 ≤ i) :
    (e0 :: e1 :: e2 :: rest).getD i 0 = (0 :: 0 :: 0 :: rest).getD i 0 := by
  obtain ⟨j, rfl⟩ : ∃ j, i = j + 3 := ⟨i - 3, by omega⟩
  simp only [List.getD_cons_succ]

/-- **The batch of ten**: four named clauses, five LogUp entries and one more, against the code's form. -/
theorem batch10 (mu : ℕ → R) (cl : ℕ → R) (xs : List R) (hxs : xs.length = 5) (e : R) :
    ∑ κ : Fin 10, mu κ * (if (κ : ℕ) < 4 then cl κ else (List.replicate 4 0 ++ xs ++ [e]).getD κ 0)
      = wsum (fun k => mu (4 + k)) 0 xs + mu 9 * e + (mu 0 * cl 0 + mu 1 * cl 1 + mu 2 * cl 2 + mu 3 * cl 3) := by
  rcases xs with _ | ⟨x0, _ | ⟨x1, _ | ⟨x2, _ | ⟨x3, _ | ⟨x4, _ | ⟨x5, xs⟩⟩⟩⟩⟩⟩ <;>
    simp only [List.length_cons, List.length_nil] at hxs <;> try omega
  rw [Fin.sum_univ_eq_sum_range (fun κ : ℕ => mu κ * (if κ < 4 then cl κ
    else (List.replicate 4 (0 : R) ++ [x0, x1, x2, x3, x4] ++ [e]).getD κ (0 : R))) 10]
  simp (config := { decide := true }) only [Finset.sum_range_succ, Finset.sum_range_zero, wsum, List.replicate_succ, List.replicate_zero,
    List.cons_append, List.nil_append, List.getD_cons_succ, List.getD_cons_zero, ite_true, ite_false]
  ring

end Lists

/-! ## The named relations at a cube point of `Dom::S` -/

theorem append_splitS (b : Fin 14 → Bool) :
    Fin.append (Fin.append (splitS b).1.1 (splitS b).1.2) (Fin.append (splitS b).2.1 (splitS b).2.2) = b := by
  funext i
  refine Fin.addCases (fun i4 => ?_) (fun i10 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun i5 => ?_) (fun i5' => ?_) i10
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl

theorem append_splitS_hd (b : Fin 14 → Bool) :
    Fin.append (Fin.append (splitS b).1.1 (splitS b).1.2) (splitS b).2.1 = hd9 b := by
  funext i
  refine Fin.addCases (fun i4 => ?_) (fun i5 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

theorem append_splitHt (r : Fin 9 → Bool) :
    Fin.append (Fin.append (splitHt r).1.1 (splitHt r).1.2) (splitHt r).2 = r := by
  funext i
  refine Fin.addCases (fun i4 => ?_) (fun i5 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

/-- **A point of `Dom::S` from a point of `Dom::Ht` and a key token.** -/
theorem splitS_app9 (r : Fin 9 → Bool) (j : Fin 5 → Bool) :
    splitS (Fin.append r j) = ((splitHt r).1, (splitHt r).2, j) := by
  refine Prod.ext (Prod.ext ?_ ?_) (Prod.ext ?_ ?_)
  · funext i
    exact Fin.append_left r j (Fin.castAdd 5 (Fin.castAdd 1 i))
  · funext i
    exact Fin.append_left r j (Fin.castAdd 5 (Fin.natAdd 3 i))
  · funext i
    exact Fin.append_left r j (Fin.natAdd 4 i)
  · funext i
    show Fin.append r j (Fin.natAdd 4 (Fin.natAdd 5 i)) = j i
    rw [show (Fin.natAdd 4 (Fin.natAdd 5 i) : Fin 14) = Fin.natAdd 9 i from
      Fin.ext (by simp only [Fin.val_natAdd]; omega)]
    exact Fin.append_right r j i

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX

theorem alg_plS (off : ℕ) (b : Fin 14 → Bool) : algebraMap GF K (plS U P D off (splitS b)) = aPl U P D off 14 b := by
  unfold plS
  rw [aPl_alg U P D hX, append_splitS]

theorem alg_plH (off : ℕ) (b : Fin 14 → Bool) :
    algebraMap GF K (plH U P D off ((splitS b).1, (splitS b).2.1)) = aPl U P D off 9 (hd9 b) := by
  unfold plH
  rw [aPl_alg U P D hX]
  simp only
  rw [append_splitS_hd]

omit hX in
/-- A base constant of the builders, read in the field. -/
theorem cK (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) : (cstK U).base v = (v : K) := by
  rw [cstK_base U v h1 h2, map_intCast]

omit hX in
theorem cP (j : ℕ) (hj : j < 4) : (cstK U).p16 j = (2 : K) ^ (16 * j) := by
  rw [cstK_p16 U j hj, map_pow, map_ofNat]

omit hX in
theorem remR2_lo {C : Type} (pl : ℕ → C → GF) (a c : ℕ) : (remR pl [a, c]).lo = pl a := rfl

omit hX in
theorem remR2_hi {C : Type} (pl : ℕ → C → GF) (a c : ℕ) : (remR pl [a, c]).hi = pl c := rfl

omit hX in
theorem remVal_gt (s : ℕ) (hs : 16 < s) (lo hi : GF) : remVal s lo hi = lo + 2 ^ 16 * hi := by
  unfold remVal
  rw [ite_eq_right (by omega)]

/-- **`SC_SZC`'s four relations, embedded**, in the planes (the gate `gS` is `1`: `Dom::S` does not pad). -/
theorem relCl17_alg (hS : RungS S) (hL : LayW16 Lay) (b : Fin 14 → Bool) :
    [algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 0 (.s (splitS b))),
      algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 1 (.s (splitS b))),
      algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 2 (.s (splitS b))),
      algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 3 (.s (splitS b)))]
    = [aPl U P D 786432 14 b * aPl U P D 786432 14 b - aPl U P D 786432 14 b,
       aPl U P D 786432 14 b * (aPl U P D 65536 9 (hd9 b)
         - algebraMap GF K (B.mask (splitS b)) * (aPl U P D 737280 14 b + 127) + 127),
       algebraMap GF K (B.mask (splitS b)) * aPl U P D 802816 14 b * 2 ^ 12
         - aPl U P D 819200 14 b * aPl U P D 81920 9 (hd9 b)
         - (aPl U P D 835584 14 b + 2 ^ 16 * aPl U P D 851968 14 b),
       (aPl U P D 868352 14 b + 2 ^ 16 * aPl U P D 884736 14 b)
         + (aPl U P D 835584 14 b + 2 ^ 16 * aPl U P D 851968 14 b) + 1 - aPl U P D 81920 9 (hd9 b)] := by
  simp only [relCl, gS_one B hL, one_mul, hS.wrho, hS.fp, xtW, remR2_lo, remR2_hi,
    remVal_gt 17 (by norm_num), map_sub, map_mul, map_add, map_pow,
    map_ofNat, map_one, alg_plS U P D hX, alg_plH U P D hX]

/-- **`SC_SZC`'s second hosted relation (`SC_SCORE`'s requantization), embedded.** -/
theorem relGh171_alg (hS : RungS S) (hL : LayW16 Lay) (b : Fin 14 → Bool) :
    algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b)))
      = 2 ^ 18 * aPl U P D 737280 14 b + (aPl U P D 753664 14 b + 2 ^ 16 * aPl U P D 770048 14 b) - 2 ^ 17 := by
  simp only [relGh, gS_one B hL, one_mul, hS.ss, xtW, remR2_lo, remR2_hi, remVal_gt 18 (by norm_num),
    map_sub, map_mul, map_add, map_pow, map_ofNat, alg_plS U P D hX]

end Rels

/-! ## `SC_SZC`'s IR and its polynomial at a cube point -/

section Point

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_SZC`'s IR read in the field**: L13's host terms with the batch (LogUp, the exp tuple, the four clauses) and
the two hosted terms (`SUM + λ`, the score's requantization). -/
theorem szc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval ((irS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
          (logupSem (cstK U) v 16 (fun k => ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD (4 + k) 0) 0
              ((lksS17.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 17 dr))).map
                (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U)))
            + ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 9 0
              * szcExp (cstK U) RSz KSz v ((Sym.eval hist 17 dr amdS).toK U) ((Sym.eval hist 17 dr nbS).toK U)
            + batchV ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)) (szcClauses (cstK U) RSz KSz v))
          (v.getD 15 0 + (Sym.eval hist 17 dr (.dr 4 9)).toK U) (reqV (cstK U) v 18 4 [5, 6]) := by
  unfold irS
  rw [szcIr_map, szcIr_map, cstS_map, szcIr_eval _ (cstW_map_std U)]
  simp only [List.length_map, lksS17_length, padSem, add_zero, RSz_gS, gV, Option.toList_none, List.map_nil,
    List.prod_nil, one_mul]
  rfl

omit [Field K] [Algebra GF K] in
/-- The lookups' table positions are past the three `eq` tables. -/
theorem lksS17_pos (f : Sym → Fp2) (g : Fp2 → K) :
    ∀ l ∈ (lksS17.map (ZK60.Exec.Slot.Build.LkD.map f)).map (ZK60.Exec.Slot.Build.LkD.map g), ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [List.mem_map] at hl
  obtain ⟨l1, ⟨l0, hl0, rfl⟩, rfl⟩ := hl
  simp only [ZK60.Exec.Slot.Build.LkD.map, List.map_map, List.mem_map] at ht
  obtain ⟨t0, ht0, rfl⟩ := ht
  simp only [lksS17, DefW16.lksS, List.mem_map] at hl0
  obtain ⟨lw, -, rfl⟩ := hl0
  simp only [List.mem_map] at ht0
  obtain ⟨tw, -, rfl⟩ := ht0
  simp only [Function.comp, shapedS]
  omega

theorem lkRels_cons3 (e0 e1 e2 : K) (rest : List K) (lks : List (LkD K)) (hp : ∀ l ∈ lks, ∀ t ∈ l.terms, 3 ≤ t.2) :
    lkRels (cstK U) (e0 :: e1 :: e2 :: rest) 16 0 lks = lkRels (cstK U) (0 :: 0 :: 0 :: rest) 16 0 lks :=
  lkRels_congr (cstK U) _ _ 16 0 lks (fun l hl t ht => getD_cons3 e0 e1 e2 rest t.2 (hp l hl t ht))
    (fun i _ => getD_cons3 e0 e1 e2 rest _ (by omega))

variable (P : BlockParams) (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX in
/-- **`SC_SZC`'s polynomial at a cube point with the zero extension**: `eq(τ)·Σ_κ μ_κ·c_κ + ν₀·eq(p_ht)·(SUM + λ)
+ ν₁·eq(P₁)·h₁`, with `c_κ` the named relations for `κ < 4` and `xcSzc` past them. -/
theorem szc_point (hS : RungS S) (hL : LayW16 Lay) (hist : Hist) (dr : List Fp2) (e0 e1 e2 : K)
    (b : Fin 14 → Bool) :
    irEval ((irS.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
        (e0 :: e1 :: e2 :: restS U P D (algebraMap GF K (B.mask (splitS b))) b)
      = e0 * ∑ κ : Fin 10, ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 κ (.s (splitS b)))
            else xcSzc U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b)
        + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (e1 * (aPl U P D 81920 9 (hd9 b) + (Sym.eval hist 17 dr (.dr 4 9)).toK U))
        + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (e2 * algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b)))) := by
  rw [szc_irEval]
  have hlk := lkRels_cons3 U e0 e1 e2 (restS U P D (algebraMap GF K (B.mask (splitS b))) b)
    _ (lksS17_pos (Sym.eval hist 17 dr) (Fp2.toK U))
  have hlks : (lksS17.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist 17 dr)))
      = lksS17.map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1
          (hist.beta, hist.gamma, hist.alpha).2.1 (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [])) :=
    lksS_eval DefW16.cfgRungW16 shapedS .S hist _ 17 17 dr [] rfl rfl
  have hex : szcExp (cstK U) RSz KSz (e0 :: e1 :: e2 :: restS U P D (algebraMap GF K (B.mask (splitS b))) b)
      ((Sym.eval hist 17 dr amdS).toK U) ((Sym.eval hist 17 dr nbS).toK U)
      = szcExp (cstK U) RSz KSz (valsX U P D B b)
        ((Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1 (hist.beta, hist.gamma, hist.alpha).2.1
          (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [] amdS).toK U)
        ((Sym.eval (histOf (hist.beta, hist.gamma, hist.alpha).1 (hist.beta, hist.gamma, hist.alpha).2.1
          (hist.beta, hist.gamma, hist.alpha).2.2 []) 17 [] nbS).toK U) := rfl
  have hlen : (lkRels (cstK U) (valsX U P D B b) 16 0 (lksK U (hist.beta, hist.gamma, hist.alpha))).length = 5 := by
    rw [lkRels_length]
    simp only [lksK, List.length_map, lksS17_length]
  unfold xcSzc
  rw [batch10 (fun q => ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD q 0)
    (fun q => algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 q (.s (splitS b)))) _ hlen]
  have hcl := relCl17_alg U P D hX Pb Lay B hS hL b
  simp only [List.cons.injEq, and_true] at hcl
  obtain ⟨c0, c1, c2, c3⟩ := hcl
  simp only [c0, c1, c2, c3]
  rw [relGh171_alg U P D hX Pb Lay B hS hL b, logupSem_eq_wsum, hlk, hlks, hex]
  unfold lksK valsX hostTerms
  simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul, List.getD_cons_zero,
    List.getD_cons_succ, restS]
  simp only [batchV, szcClauses, szcDelta, RSz, KSz, reqV, L16, List.zipIdx_cons, List.zipIdx_nil,
    List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ]
  simp (disch := norm_num) only [cK U, cP U, Int.cast_pow, Int.cast_neg, Int.cast_ofNat,
    show (18 - 1 : ℕ) = 17 from rfl]
  ring

end Point

/-! ## Multilinear extensions at points made of blocks -/

section Mle

variable {K : Type} [Field K]

theorem bits_append {a b : ℕ} (x : Fin a → Bool) (y : Fin b → Bool) :
    (fun i => (bit (Fin.append x y i) : K)) = Fin.append (fun i => bit (x i)) (fun i => bit (y i)) := by
  funext i
  refine Fin.addCases (fun i => ?_) (fun i => ?_) i
  · simp only [Fin.append_left]
  · simp only [Fin.append_right]

/-- A sum against the `eq` of a Boolean point picks the point. -/
theorem sum_eq_bits {n : ℕ} (c : Fin n → Bool) (F : (Fin n → Bool) → K) :
    ∑ w : Fin n → Bool, eqPoly (fun i => (bit (c i) : K)) (fun i => bit (w i)) * F w = F c := by
  classical
  rw [Fintype.sum_eq_single c (fun w hw => by rw [eqPoly_bit, ite_eq_right (Ne.symm hw), zero_mul])]
  rw [eqPoly_bit, ite_eq_left rfl, one_mul]

/-- **The extension at a point of four blocks** is the sum over the four blocks' cubes. -/
theorem mleAt_eq4 {a b c d : ℕ} (f : (Fin ((a + b) + (c + d)) → Bool) → K) (p1 : Fin a → K) (p2 : Fin b → K)
    (p3 : Fin c → K) (p4 : Fin d → K) :
    mleAt f (Fin.append (Fin.append p1 p2) (Fin.append p3 p4))
      = ∑ z1 : Fin a → Bool, ∑ z2 : Fin b → Bool, ∑ z3 : Fin c → Bool, ∑ z4 : Fin d → Bool,
          eqPoly p1 (fun i => bit (z1 i)) * eqPoly p2 (fun i => bit (z2 i)) * eqPoly p3 (fun i => bit (z3 i))
            * eqPoly p4 (fun i => bit (z4 i)) * f (Fin.append (Fin.append z1 z2) (Fin.append z3 z4)) := by
  rw [mleAt_append]
  unfold mle2
  rw [sum_append]
  refine Finset.sum_congr rfl (fun z1 _ => Finset.sum_congr rfl (fun z2 _ => ?_))
  rw [sum_append]
  refine Finset.sum_congr rfl (fun z3 _ => Finset.sum_congr rfl (fun z4 _ => ?_))
  rw [bits_append, bits_append, eqPoly_append, eqPoly_append]
  ring

/-- **The extension at `(r, (g, s), c)` with `g`, `c` Boolean** (`SC_SCORE`'s `QR` table). -/
theorem mleAt_qr (f : (Fin (5 + ((3 + 1) + 6)) → Bool) → K) (r : Fin 5 → K) (g : Fin 3 → Bool) (s : Fin 1 → K)
    (c : Fin 6 → Bool) :
    mleAt f (Fin.append r (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i))))
      = ∑ t : Fin 5 → Bool, ∑ j : Fin 1 → Bool, eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (j i))
          * f (Fin.append t (Fin.append (Fin.append g j) c)) := by
  rw [mleAt_append]
  unfold mle2
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have e1 : ∀ w1 : Fin (3 + 1) → Bool, ∑ w2 : Fin 6 → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i)))
        (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
      = eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (w1 i))
        * f (Fin.append t (Fin.append w1 c)) := by
    intro w1
    have h : ∀ w2 : Fin 6 → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (Fin.append (fun i => bit (g i)) s) (fun i => bit (c i)))
          (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
        = eqPoly (fun i => (bit (c i) : K)) (fun i => bit (w2 i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (w1 i)) * f (Fin.append t (Fin.append w1 w2))) := by
      intro w2
      rw [bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun w2 _ => h w2), sum_eq_bits]
  have e2 : ∀ j : Fin 1 → Bool, ∑ g' : Fin 3 → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (Fin.append g' j i))
        * f (Fin.append t (Fin.append (Fin.append g' j) c))
      = eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (j i))
        * f (Fin.append t (Fin.append (Fin.append g j) c)) := by
    intro j
    have h : ∀ g' : Fin 3 → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (fun i => bit (g i)) s) (fun i => bit (Fin.append g' j i))
          * f (Fin.append t (Fin.append (Fin.append g' j) c))
        = eqPoly (fun i => (bit (g i) : K)) (fun i => bit (g' i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly s (fun i => bit (j i)) * f (Fin.append t (Fin.append (Fin.append g' j) c))) := by
      intro g'
      rw [bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun g' _ => h g'), sum_eq_bits]
  rw [sum_append, Finset.sum_congr rfl (fun w1 _ => e1 w1), sum_append, Finset.sum_comm]
  exact Finset.sum_congr rfl (fun j _ => e2 j)

/-- **The extension at `(r, g, c)` with `g`, `c` Boolean** (`SC_SCORE`'s `KR` table). -/
theorem mleAt_kr (f : (Fin (5 + (3 + 6)) → Bool) → K) (r : Fin 5 → K) (g : Fin 3 → Bool) (c : Fin 6 → Bool) :
    mleAt f (Fin.append r (Fin.append (fun i => bit (g i)) (fun i => bit (c i))))
      = ∑ t : Fin 5 → Bool, eqPoly r (fun i => bit (t i)) * f (Fin.append t (Fin.append g c)) := by
  rw [← bits_append g c]
  exact mleAt_append_bits f r (Fin.append g c)

/-- The extension of a function plus a constant. -/
theorem mleAt_add_c {n : ℕ} (F : (Fin n → Bool) → K) (c : K) (p : Fin n → K) :
    mleAt (fun r => F r + c) p = mleAt F p + c := by
  have h1 : mleAt (fun r => F r + c) p = mleAt F p + c * mleAt (fun _ : Fin n → Bool => (1 : K)) p := by
    unfold mleAt
    rw [Finset.mul_sum, ← Finset.sum_add_distrib]
    exact Finset.sum_congr rfl (fun b _ => by ring)
  rw [h1, mleAt_one, mul_one]

/-- The extension of a constant minus a function. -/
theorem mleAt_c_sub {n : ℕ} (F : (Fin n → Bool) → K) (p : Fin n → K) :
    mleAt (fun r => 1 - F r) p = 1 - mleAt F p := by
  have h1 : mleAt (fun r => 1 - F r) p = mleAt (fun _ : Fin n → Bool => (1 : K)) p - mleAt F p := by
    unfold mleAt
    rw [← Finset.sum_sub_distrib]
    exact Finset.sum_congr rfl (fun b _ => by ring)
  rw [h1, mleAt_one]

theorem mleAt_sub' {n : ℕ} (F G : (Fin n → Bool) → K) (p : Fin n → K) :
    mleAt (fun r => F r - G r) p = mleAt F p - mleAt G p := by
  unfold mleAt
  rw [← Finset.sum_sub_distrib]
  exact Finset.sum_congr rfl (fun b _ => by ring)

/-- **The reordering of a bilinear sum**, over abstract index types: `Σ_g Σ_c e_g·(Σ_t Σ_j e_t·e_j·Q)·(Σ_t' e_t'·R)`
is the sum over `(g, j, t, t')` of the four weights times the contraction `Σ_c Q·R`. -/
theorem score_gen {G J T C : Type} [Fintype G] [Fintype J] [Fintype T] [Fintype C] (eg : G → K) (ej : J → K)
    (et et' : T → K) (Q : G → J → T → C → K) (R : G → T → C → K) :
    ∑ g, ∑ c, eg g * ((∑ t, ∑ j, et t * ej j * Q g j t c) * (∑ t', et' t' * R g t' c))
      = ∑ g, ∑ j, ∑ t, ∑ t', eg g * ej j * et t * et' t' * ∑ c, Q g j t c * R g t' c := by
  refine Finset.sum_congr rfl (fun g _ => ?_)
  have h1 : ∀ c, eg g * ((∑ t, ∑ j, et t * ej j * Q g j t c) * (∑ t', et' t' * R g t' c))
      = ∑ t, ∑ j, ∑ t', eg g * ej j * et t * et' t' * (Q g j t c * R g t' c) := by
    intro c
    rw [Finset.sum_mul, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun t _ => ?_)
    rw [Finset.sum_mul, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun j _ => ?_)
    rw [Finset.mul_sum, Finset.mul_sum]
    refine Finset.sum_congr rfl (fun t' _ => ?_)
    ring
  rw [Finset.sum_congr rfl (fun c _ => h1 c)]
  calc ∑ c, ∑ t, ∑ j, ∑ t', eg g * ej j * et t * et' t' * (Q g j t c * R g t' c)
      = ∑ t, ∑ c, ∑ j, ∑ t', eg g * ej j * et t * et' t' * (Q g j t c * R g t' c) := Finset.sum_comm
    _ = ∑ t, ∑ j, ∑ c, ∑ t', eg g * ej j * et t * et' t' * (Q g j t c * R g t' c) :=
        Finset.sum_congr rfl (fun t _ => Finset.sum_comm)
    _ = ∑ t, ∑ j, ∑ t', ∑ c, eg g * ej j * et t * et' t' * (Q g j t c * R g t' c) :=
        Finset.sum_congr rfl (fun t _ => Finset.sum_congr rfl (fun j _ => Finset.sum_comm))
    _ = ∑ j, ∑ t, ∑ t', ∑ c, eg g * ej j * et t * et' t' * (Q g j t c * R g t' c) := Finset.sum_comm
    _ = ∑ j, ∑ t, ∑ t', eg g * ej j * et t * et' t' * ∑ c, Q g j t c * R g t' c :=
        Finset.sum_congr rfl (fun j _ => Finset.sum_congr rfl (fun t _ => Finset.sum_congr rfl
          (fun t' _ => (Finset.mul_sum _ _ _).symm)))

/-- **The reordering of `SC_SCORE`'s sum**: `Σ_g Σ_c eq_g·(Σ_t Σ_j eq_t·eq_j·QR)·(Σ_t' eq_t'·KR)` is the sum over
`(g, j, t, t')` of the four `eq`s times the contraction `Σ_c QR·KR`. -/
theorem score_eq (QR : (Fin (5 + ((3 + 1) + 6)) → Bool) → K) (KR : (Fin (5 + (3 + 6)) → Bool) → K)
    (rg : Fin 3 → K) (rj : Fin 1 → K) (rt r3 : Fin 5 → K) :
    ∑ g : Fin 3 → Bool, ∑ c : Fin 6 → Bool, eqPoly rg (fun i => bit (g i))
      * ((∑ t : Fin 5 → Bool, ∑ j : Fin 1 → Bool, eqPoly rt (fun i => bit (t i)) * eqPoly rj (fun i => bit (j i))
          * QR (Fin.append t (Fin.append (Fin.append g j) c)))
        * (∑ t' : Fin 5 → Bool, eqPoly r3 (fun i => bit (t' i)) * KR (Fin.append t' (Fin.append g c))))
    = ∑ g : Fin 3 → Bool, ∑ j : Fin 1 → Bool, ∑ t : Fin 5 → Bool, ∑ t' : Fin 5 → Bool,
        eqPoly rg (fun i => bit (g i)) * eqPoly rj (fun i => bit (j i)) * eqPoly rt (fun i => bit (t i))
          * eqPoly r3 (fun i => bit (t' i))
          * ∑ c : Fin 6 → Bool, QR (Fin.append t (Fin.append (Fin.append g j) c)) * KR (Fin.append t' (Fin.append g c)) :=
  score_gen (fun g : Fin 3 → Bool => eqPoly rg (fun i => bit (g i))) (fun j : Fin 1 → Bool => eqPoly rj (fun i => bit (j i)))
    (fun t : Fin 5 → Bool => eqPoly rt (fun i => bit (t i))) (fun t : Fin 5 → Bool => eqPoly r3 (fun i => bit (t i)))
    (fun g j t (c : Fin 6 → Bool) => QR (Fin.append t (Fin.append (Fin.append g j) c)))
    (fun g t (c : Fin 6 → Bool) => KR (Fin.append t (Fin.append g c)))

end Mle

/-! ## The three slots' cube sums -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- A slot's draws `a … a + n − 1`, read in the field. -/
noncomputable def ptv (ev : Sym → Fp2) (s a n : ℕ) : Fin n → K := fun i => (ev (.dr s (a + i))).toK U

theorem drs_ptv (ev : Sym → Fp2) (s a n : ℕ) :
    (fun i : Fin n => (((drs s a n).map ev).getD i Fp2.zero).toK U) = ptv U ev s a n := by
  funext i
  rw [drs_getD ev s a n i i.isLt]
  rfl

include hX hrl in
/-- **`SC_SZC`'s cube sum** (`n = 14`): `Z̃(τ) + ν₀·32·(S̃UM(p_ht) + λ) + ν₁·h̃₁(P₁)`, the batch `Z` the named
relations and `xcSzc`. -/
theorem szc_cube (hS : RungS S) (hL : LayW16 Lay) (n e : ℕ) (hn : n = 14) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2)
    (hmask : ∀ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval ((irS.map (Sym.eval hist 17 dr)).map (Fp2.toK U))
      ((tabs17.map (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = mleAt (fun b : Fin 14 → Bool => ∑ κ : Fin 10,
          ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 κ (.s (splitS b)))
            else xcSzc U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b))
        (ptv U (Sym.eval hist 17 dr) 17 0 14)
      + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (32 * (mleAt (fun r : Fin 9 → Bool => aPl U P D 81920 9 r) (ptv U (Sym.eval hist 17 dr) 4 0 9)
          + (Sym.eval hist 17 dr (.dr 4 9)).toK U))
      + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin 14 → Bool => algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
          (ptv U (Sym.eval hist 17 dr) 8 0 14) := by
  subst hn
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 14 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (ptv U (Sym.eval hist 17 dr) 17 0 14) (fun i => bit (b i))
          * (∑ κ : Fin 10, ((muS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
            * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 κ (.s (splitS b)))
              else xcSzc U P D Pb Lay B (hist.beta, hist.gamma, hist.alpha) κ b))
        + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 9) (fun i => bit (hd9 b i)) * (aPl U P D 81920 9 (hd9 b) + ((Sym.eval hist 17 dr) (.dr 4 9)).toK U))
        + ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (eqPoly (ptv U (Sym.eval hist 17 dr) 8 0 14) (fun i => bit (b i))
            * algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b)))) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 14 e b) = _
      rw [hf, szc_vals U P D hrl e b (Sym.eval hist 17 dr) pub, hmask b, szc_point U P D hX Pb Lay B hS hL hist dr, drs_ptv, drs_ptv,
        drs_ptv]
    · show f (bpt 14 e b y) = 0
      have z0 : ((tabs17.map (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 0 0 = 0 :=
        tabK_eq_off U P D 14 e b y hy _ _
      have z1 : ((tabs17.map (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 1 0 = 0 :=
        tabK_eq_off U P D 14 e b y hy _ _
      have z2 : ((tabs17.map (TabS.eval (Sym.eval hist 17 dr) pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 2 0 = 0 :=
        tabK_eq_off U P D 14 e b y hy _ _
      rw [hf, szc_irEval]
      unfold hostTerms
      rw [z0, z1, z2]
      ring
  simp only [hrow]
  rw [Finset.sum_add_distrib, Finset.sum_add_distrib]
  have hB : ∑ b : Fin 14 → Bool, ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 9) (fun i => bit (hd9 b i)) * (aPl U P D 81920 9 (hd9 b) + ((Sym.eval hist 17 dr) (.dr 4 9)).toK U))
      = ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
        * (32 * (mleAt (fun r : Fin 9 → Bool => aPl U P D 81920 9 r) (ptv U (Sym.eval hist 17 dr) 4 0 9) + ((Sym.eval hist 17 dr) (.dr 4 9)).toK U)) := by
    rw [← Finset.mul_sum]
    congr 1
    have h1 := sum_append (a := 9) (b := 5) (fun b => eqPoly (ptv U (Sym.eval hist 17 dr) 4 0 9) (fun i => bit (hd9 b i))
      * (aPl U P D 81920 9 (hd9 b) + ((Sym.eval hist 17 dr) (.dr 4 9)).toK U))
    refine h1.trans ?_
    simp only [hd9_append]
    have h2 := rs_host_cubeSum (b := 5) (ptv U (Sym.eval hist 17 dr) 4 0 9) (fun _ => (1 : K)) (fun r => aPl U P D 81920 9 r)
      (((Sym.eval hist 17 dr) (.dr 4 9)).toK U)
    simp only [one_mul] at h2
    rw [h2, mleAt_add_c]
    norm_num
  have hC : ∑ b : Fin 14 → Bool, ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * (eqPoly (ptv U (Sym.eval hist 17 dr) 8 0 14) (fun i => bit (b i))
          * algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
      = ((nuS.map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
        * mleAt (fun b : Fin 14 → Bool => algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
          (ptv U (Sym.eval hist 17 dr) 8 0 14) := by
    rw [← Finset.mul_sum]
    rfl
  rw [hB, hC]
  rfl

include hrl in
/-- **`SC_RS`'s cube sum** (`n = 14`): `(Σ_j mask·E)~(p_ht) + λ·(Σ_j ZSEL)~(p_ht)`. -/
theorem rs_cube (n e : ℕ) (hn : n = 14) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hmask : ∀ b : Fin 14 → Bool, ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS b)))
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 9)).map (Sym.eval hist 4 dr)).map (Fp2.toK U))
      ((tabs4.map (TabS.eval (Sym.eval hist 4 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = mleAt (fun r : Fin 9 → Bool => ∑ j : Fin 5 → Bool,
          algebraMap GF K (B.mask (splitS (Fin.append r j))) * aPl U P D 802816 14 (Fin.append r j))
        (ptv U (Sym.eval hist 4 dr) 4 0 9)
      + (Sym.eval hist 4 dr (.dr 4 9)).toK U
        * mleAt (fun r : Fin 9 → Bool => ∑ j : Fin 5 → Bool, aPl U P D 786432 14 (Fin.append r j))
          (ptv U (Sym.eval hist 4 dr) 4 0 9) := by
  subst hn
  have hir : ∀ v : List K, irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 9)).map (Sym.eval hist 4 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0 + ((Sym.eval hist 4 dr) (.dr 4 9)).toK U * v.getD 3 0) := by
    intro v
    rw [rsIr_map, rsIr_map, cstS_map, rsIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul]
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 14 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (ptv U (Sym.eval hist 4 dr) 4 0 9) (fun i => bit (hd9 b i))
        * (algebraMap GF K (B.mask (splitS b)) * aPl U P D 802816 14 b
          + ((Sym.eval hist 4 dr) (.dr 4 9)).toK U * aPl U P D 786432 14 b) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 14 e b) = _
      rw [hf, hir]
      simp only [tabs4, taA, List.map_cons, List.map_nil, eqT_eval, pubT_eval, aTab_eval, List.getD_cons_zero,
        List.getD_cons_succ]
      rw [tabK_eqHead_cpt U P D 14 e b _ 9 (drs_length (Sym.eval hist 4 dr) 4 0 9) (by norm_num), tabK_pub_cpt, hmask b,
        tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl,
        castB_rfl, drs_ptv]
      rfl
    · show f (bpt 14 e b y) = 0
      rw [hf, hir]
      have z0 : ((tabs4.map (TabS.eval (Sym.eval hist 4 dr) pub)).map (tabK U P D 14 e (bpt 14 e b y))).getD 0 0 = 0 :=
        tabK_eq_off U P D 14 e b y hy _ _
      rw [z0, zero_mul]
  simp only [hrow]
  have h1 := sum_append (a := 9) (b := 5) (fun b => eqPoly (ptv U (Sym.eval hist 4 dr) 4 0 9) (fun i => bit (hd9 b i))
    * (algebraMap GF K (B.mask (splitS b)) * aPl U P D 802816 14 b + ((Sym.eval hist 4 dr) (.dr 4 9)).toK U * aPl U P D 786432 14 b))
  refine h1.trans ?_
  simp only [hd9_append]
  have h2 := rs_cubeSum (ptv U (Sym.eval hist 4 dr) 4 0 9) (fun _ _ => (1 : K))
    (fun (r : Fin 9 → Bool) (j : Fin 5 → Bool) => algebraMap GF K (B.mask (splitS (Fin.append r j))))
    (fun r j => aPl U P D 802816 14 (Fin.append r j)) (fun r j => aPl U P D 786432 14 (Fin.append r j))
    (((Sym.eval hist 4 dr) (.dr 4 9)).toK U)
  simp only [one_mul] at h2
  exact h2

/-- The coordinates of `SC_SCORE`'s `QR` table, evaluated. -/
def coordsQ (ev : Sym → Fp2) : List Coord :=
  ((drs 8 4 5).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ (drs 8 3 1).map CoordS.fixed ++ DefW16.rhoC 3 9).map
    (CoordS.eval ev)

/-- The coordinates of `SC_SCORE`'s `KR` table, evaluated. -/
def coordsK (ev : Sym → Fp2) : List Coord :=
  ((drs 8 9 5).map CoordS.fixed ++ DefW16.rhoC 0 3 ++ DefW16.rhoC 3 9).map (CoordS.eval ev)

theorem tabs8_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabs8.map (TabS.eval ev pub)
      = [.eq ((drs 8 0 3).map ev) 0, .priv ⟨.a, [(507904, Fp2.one)], 15, coordsQ ev, 152, 0⟩,
        .priv ⟨.a, [(704512, Fp2.one)], 14, coordsK ev, 154, 1⟩] := rfl

include hrl in
theorem score_qr (ev : Sym → Fp2) (g : Fin 3 → Bool) (c : Fin 6 → Bool) :
    tabK U P D 9 2 (cpt 9 2 (Fin.append g c)) (.priv ⟨.a, [(507904, Fp2.one)], 15, coordsQ ev, 152, 0⟩)
      = ∑ t : Fin 5 → Bool, ∑ j : Fin 1 → Bool, eqPoly (ptv U ev 8 4 5) (fun i => bit (t i))
          * eqPoly (ptv U ev 8 3 1) (fun i => bit (j i))
          * aPl U P D 507904 15 (Fin.append t (Fin.append (Fin.append g j) c)) := by
  rw [tabK_priv_cpt U P D 9 2 _ _ (by simp) (by norm_num) hrl]
  have hpt : (fun a : Fin 15 => ptK U (xrK 9 (cpt (K := K) 9 2 (Fin.append g c))) (coordsQ ev) a)
      = (Fin.append (ptv U ev 8 4 5) (Fin.append (Fin.append (fun i => (bit (g i) : K)) (ptv U ev 8 3 1))
          (fun i => (bit (c i) : K))) : Fin 15 → K) := by
    funext a
    fin_cases a <;> rfl
  show mleAt (aPl U P D 507904 15)
    (fun a : Fin 15 => ptK U (xrK 9 (cpt (K := K) 9 2 (Fin.append g c))) (coordsQ ev) a) = _
  rw [hpt]
  exact mleAt_qr (aPl U P D 507904 15) _ g _ c

include hrl in
theorem score_kr (ev : Sym → Fp2) (g : Fin 3 → Bool) (c : Fin 6 → Bool) :
    tabK U P D 9 2 (cpt 9 2 (Fin.append g c)) (.priv ⟨.a, [(704512, Fp2.one)], 14, coordsK ev, 154, 1⟩)
      = ∑ t : Fin 5 → Bool, eqPoly (ptv U ev 8 9 5) (fun i => bit (t i))
          * aPl U P D 704512 14 (Fin.append t (Fin.append g c)) := by
  rw [tabK_priv_cpt U P D 9 2 _ _ (by simp) (by norm_num) hrl]
  have hpt : (fun a : Fin 14 => ptK U (xrK 9 (cpt (K := K) 9 2 (Fin.append g c))) (coordsK ev) a)
      = (Fin.append (ptv U ev 8 9 5) (Fin.append (fun i => (bit (g i) : K)) (fun i => (bit (c i) : K)))
          : Fin 14 → K) := by
    funext a
    fin_cases a <;> rfl
  show mleAt (aPl U P D 704512 14)
    (fun a : Fin 14 => ptK U (xrK 9 (cpt (K := K) 9 2 (Fin.append g c))) (coordsK ev) a) = _
  rw [hpt]
  exact mleAt_kr (aPl U P D 704512 14) _ g c

include hrl in
/-- **`SC_SCORE`'s cube sum** (`n = 9`, `e = 2`): `Σ_g Σ_c eq(r_g, g)·Q̃R(r_t, g, r_hj, c)·K̃R(r_3, g, c)`. -/
theorem score_cube (n e : ℕ) (hn : n = 9) (he : e = 2) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U))
      ((tabs8.map (TabS.eval (Sym.eval hist 8 dr) pub)).map (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin 3 → Bool, ∑ c : Fin 6 → Bool,
      eqPoly (ptv U (Sym.eval hist 8 dr) 8 0 3) (fun i => bit (g i))
      * ((∑ t : Fin 5 → Bool, ∑ j : Fin 1 → Bool, eqPoly (ptv U (Sym.eval hist 8 dr) 8 4 5) (fun i => bit (t i))
          * eqPoly (ptv U (Sym.eval hist 8 dr) 8 3 1) (fun i => bit (j i))
          * aPl U P D 507904 15 (Fin.append t (Fin.append (Fin.append g j) c)))
        * (∑ t' : Fin 5 → Bool, eqPoly (ptv U (Sym.eval hist 8 dr) 8 9 5) (fun i => bit (t' i))
          * aPl U P D 704512 14 (Fin.append t' (Fin.append g c)))) := by
  subst hn
  subst he
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_some, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one]
  rw [cubeSum_split]
  refine (sum_append (a := 3) (b := 6) _).trans
    (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun c _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt 9 2 (Fin.append g c)) = _
    rw [hf, hir, tabs8_eval]
    simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [tabK_eqHead_cpt U P D 9 2 _ _ 3 (drs_length (Sym.eval hist 8 dr) 8 0 3) (by norm_num), score_qr U P D hrl (Sym.eval hist 8 dr) g c,
      score_kr U P D hrl (Sym.eval hist 8 dr) g c, drs_ptv]
    congr 2
    funext i
    exact congrArg bit (Fin.append_left g c i)
  · show f (bpt 9 2 (Fin.append g c) y) = 0
    rw [hf, hir]
    have z0 : ((tabs8.map (TabS.eval (Sym.eval hist 8 dr) pub)).map (tabK U P D 9 2 (bpt 9 2 (Fin.append g c) y))).getD 0 0 = 0 :=
      tabK_eq_off U P D 9 2 (Fin.append g c) y hy _ _
    rw [z0, zero_mul]

end Cube

/-! ## `SC_RS`'s row differences and `SC_SCORE`'s contraction, in the planes -/

section Rows

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX

theorem alg_plHt (off : ℕ) (r : Fin 9 → Bool) : algebraMap GF K (plH U P D off (splitHt r)) = aPl U P D off 9 r := by
  unfold plH
  rw [aPl_alg U P D hX, append_splitHt]

/-- **`SC_RS`'s first row difference, embedded**: `SUM − Σ_j mask·E` (the gates are `1`). -/
theorem rsA_alg (hL : LayW16 Lay) (r : Fin 9 → Bool) :
    algebraMap GF K (relRsA Pb Lay B (xtW U P D) (.ht (splitHt r)))
      = aPl U P D 81920 9 r - ∑ j : Fin 5 → Bool,
          algebraMap GF K (B.mask (splitS (Fin.append r j))) * aPl U P D 802816 14 (Fin.append r j) := by
  simp only [relRsA, gHt_one B hL, gS_one B hL, one_mul, map_sub, map_sum, map_mul, xtW, alg_plHt U P D hX]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [← splitS_app9 r j, alg_plS U P D hX]

/-- **`SC_RS`'s second row difference, embedded**: `1 − Σ_j ZSEL`. -/
theorem rsB_alg (hL : LayW16 Lay) (r : Fin 9 → Bool) :
    algebraMap GF K (relRsB Pb Lay B (xtW U P D) (.ht (splitHt r)))
      = 1 - ∑ j : Fin 5 → Bool, aPl U P D 786432 14 (Fin.append r j) := by
  simp only [relRsB, gHt_one B hL, gS_one B hL, one_mul, map_sub, map_sum, map_one, xtW]
  congr 1
  refine Finset.sum_congr rfl (fun j _ => ?_)
  rw [← splitS_app9 r j, alg_plS U P D hX]

/-- **`SC_SCORE`'s contraction, embedded**, at a point of `Dom::S` made of its four blocks. -/
theorem relMm171_alg (g : Fin 3 → Bool) (j : Fin 1 → Bool) (t t' : Fin 5 → Bool) :
    algebraMap GF K (relMm Pb Lay B (xtW U P D) 17 1
        (.s (splitS (Fin.append (Fin.append g j) (Fin.append t t')))))
      = ∑ c : Fin 6 → Bool, aPl U P D 507904 15 (Fin.append t (Fin.append (Fin.append g j) c))
          * aPl U P D 704512 14 (Fin.append t' (Fin.append g c)) := by
  have hs := splitS_append ((g, j), t, t')
  simp only at hs
  rw [hs]
  simp only [relMm, map_sum, map_mul, xtW]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  unfold plQ plK
  rw [aPl_alg U P D hX, aPl_alg U P D hX]

end Rows

/-! ## `SC_SZC`'s certified polynomial at its draws -/

section Host

/-- `SC_SZC` is a host. -/
theorem mem17 : (17 : ℕ) ∈ algHosts := by simp [algHosts]

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)
  {L : ℕ} (P : BlockParams) (hdr : P.draws = W16R2.rungDraws)

include hcard in
/-- **`SC_SZC`'s certified polynomial at its draws**: `Z̃(τ) + ν₀·h̃₀(P₀) + ν₁·(h̃₁(P₁) − M̃₁(P₁))` over the block's
tables (`hostPhi_eq`), the batch's weights read off the draws. -/
theorem szc_hostPhi (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L)
    (rt : RootsO) (hist : Hist) (dr : List Fp2) :
    (hostSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 17 mem17 cu rt hist).Φ
        (fun i => (dr.getD i.val Fp2.zero).toK U)
      = mleAt (fun b : Fin 14 → Bool => ∑ κ : Fin 10, (dr.getD (14 + κ) Fp2.zero).toK U
            * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b)
          (fun t : Fin 14 => (dr.getD t Fp2.zero).toK U)
        + (dr.getD 24 Fp2.zero).toK U
          * mleAt (algH U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt hist 0)
            (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 0)
        + (dr.getD 25 Fp2.zero).toK U
          * (mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 1)
            - mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 1)) := by
  have hk : (17 : ℕ) ∈ algHosts := mem17
  have hseg : ∀ (g : ZK60.Exec.Slot.W16R2.Seg) (i : ℕ), segOff ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) g + i < segSum ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) →
      segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
        (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) g i = (dr.getD (segOff ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) g + i) Fp2.zero).toK U := by
    intro g i hi
    unfold segAt
    rw [dite_eq_left hi]
    rfl
  have hz : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .zeta = 0 := rfl
  have hM0 : mleAt (algM (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt 0) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 0) = 0 := by
    unfold algM mleAt
    simp
  rw [hostSp_Φ, hostPhi_eq, Fin.sum_univ_two, hM0, algH_gh U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt hist 1 (by decide),
    algM_mm (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt 1 (by decide)]
  have hbat : batched (dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha)) (dt.pw 17 cu rt)
      ((if segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .zeta = 1 then segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) =>
          (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .zeta 0 else 0,
        if segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .zeta = 1 then segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) =>
          (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .mu
            (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .mu - segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .zeta) else 0),
        fun κ => segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
          (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .mu κ)
      = fun b : Fin 14 → Bool => ∑ κ : Fin 10, (dr.getD (14 + κ) Fp2.zero).toK U
          * dt.cl 17 cu rt (hist.beta, hist.gamma, hist.alpha) κ b := by
    funext b
    unfold batched
    simp only [hz, zero_ne_one, ite_false, zero_mul, add_zero]
    refine Finset.sum_congr rfl (fun κ _ => ?_)
    have hmu : segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .mu = 10 := rfl
    have hκ := κ.isLt
    rw [hseg .mu κ (by show 14 + (κ : ℕ) < 26; omega)]
    rfl
  have htau : (fun t : Fin (segLn ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) .tau) => segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17)
      (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U) (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .tau t)
      = fun t : Fin 14 => (dr.getD t Fp2.zero).toK U := by
    funext t
    have ht : (t : ℕ) < 14 := t.isLt
    rw [hseg .tau t (by show 0 + (t : ℕ) < 26; omega)]
    show (dr.getD (0 + (t : ℕ)) Fp2.zero).toK U = _
    rw [Nat.zero_add]
  have hnu0 : segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
      (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .nu ((0 : Fin 2) : ℕ) = (dr.getD 24 Fp2.zero).toK U :=
    hseg .nu 0 (by show 24 + 0 < 26; omega)
  have hnu1 : segAt ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).dl 17) (fun j => (fun i : Fin (P.draws 17) => (dr.getD i.val Fp2.zero).toK U)
      (Fin.cast ((algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78).hsum 17 hk) j)) .nu ((1 : Fin 2) : ℕ) = (dr.getD 25 Fp2.zero).toK U :=
    hseg .nu 1 (by show 24 + 1 < 26; omega)
  rw [hbat, htau, hnu0, hnu1]
  simp only [one_mul, sub_zero]
  exact (add_assoc _ _ _).symm

omit [Fintype K] [DecidableEq K] in
/-- `SC_SCORE`'s claim point, read off the history. -/
theorem algPt_score (hist : Hist) (t : Fin 14) :
    algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 1 t = algDrawAt U hist 8 t := by
  unfold algPt
  rw [ite_eq_right (by decide), ite_eq_right (by decide)]
  rfl

omit [Fintype K] [DecidableEq K] in
/-- **`SC_SZC`'s hosted `SC_RS` function at its claim point**: `32·(Ã(p_ht) + λ·B̃(p_ht))`. -/
theorem algH0_mle (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L)
    (rt : RootsO) (hist : Hist) (hsc : dt.rsScale = 32) (A B : (Fin 9 → Bool) → K)
    (hA : ∀ b, dt.rsA cu rt b = A b) (hB : ∀ b, dt.rsB cu rt b = B b) (p : Fin 9 → K)
    (hp : ∀ t : Fin 9, algDrawAt U hist 4 t = p t) :
    mleAt (algH U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt hist 0)
        (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 0)
      = 32 * (mleAt A p + algDrawAt U hist 4 9 * mleAt B p) := by
  have e1 : (algH U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt hist 0
      : (Fin (9 + 5) → Bool) → K)
      = fun z : Fin (9 + 5) → Bool => (fun r => 32 * (A r + algDrawAt U hist 4 9 * B r)) (fun i => z (Fin.castAdd 5 i)) := by
    funext z
    unfold algH
    rw [dite_eq_left ⟨rfl, rfl⟩, hsc, hA, hB]
    rfl
  have e2 : (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 hist 0 : Fin (9 + 5) → K)
      = Fin.append p (fun _ : Fin 5 => (0 : K)) := by
    funext t
    unfold algPt
    rw [ite_eq_left ⟨rfl, rfl⟩]
    refine Fin.addCases (m := 9) (n := 5) (fun i => ?_) (fun i => ?_) t
    · rw [Fin.append_left]
      split_ifs with h
      · exact hp i
      · exact absurd i.isLt h
    · rw [Fin.append_right]
      split_ifs with h
      · exact absurd h (by show ¬ (9 + (i : ℕ) < 9); omega)
      · rfl
  rw [e1, e2]
  exact (mleAt_rowOnly (fun r => 32 * (A r + algDrawAt U hist 4 9 * B r)) p (fun _ : Fin 5 => 0)).trans
    (mleAt_lin2 A B 32 (algDrawAt U hist 4 9) p)

end Host

/-! ## The draws, read off the records -/

section Draws

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem ev_mul (h : Hist) (k : ℕ) (dr : List Fp2) (a b : Sym) :
    Sym.eval h k dr (.mul a b) = (Sym.eval h k dr a).mul (Sym.eval h k dr b) := rfl

theorem ev_base (h : Hist) (k : ℕ) (dr : List Fp2) (v : ℤ) :
    Sym.eval h k dr (.base v) = Fp2.fromBase (Fp.fromI64 v) := rfl

theorem ev_own (h : Hist) (k : ℕ) (dr : List Fp2) (i : ℕ) : Sym.eval h k dr (.dr k i) = dr.getD i Fp2.zero := by
  show drawAt h k dr k i = _
  unfold drawAt
  rw [ite_eq_left rfl]

theorem ev_hist (b g a : Fp2) (rs : List SlotRec) (k j i : ℕ) (rj : SlotRec) (hjk : j < k) (hr : rs[j]? = some rj)
    (dr : List Fp2) :
    (Sym.eval (histOf b g a (rs.take k)) k dr (.dr j i)).toK U = (rj.draws.getD i Fp2.zero).toK U := by
  show (drawAt (histOf b g a (rs.take k)) k dr j i).toK U = _
  unfold drawAt
  rw [ite_eq_right (by omega)]
  exact algDrawAt_hist U b g a rs k j i rj hjk hr

theorem ptv_own (h : Hist) (k : ℕ) (dr : List Fp2) (a n : ℕ) :
    ptv U (Sym.eval h k dr) k a n = fun i : Fin n => (dr.getD (a + (i : ℕ)) Fp2.zero).toK U := by
  funext i
  unfold ptv
  rw [ev_own]

theorem ptv_hist (b g a : Fp2) (rs : List SlotRec) (k j : ℕ) (rj : SlotRec) (hjk : j < k) (hr : rs[j]? = some rj)
    (dr : List Fp2) (o n : ℕ) :
    ptv U (Sym.eval (histOf b g a (rs.take k)) k dr) j o n
      = fun i : Fin n => (rj.draws.getD (o + (i : ℕ)) Fp2.zero).toK U := by
  funext i
  exact ev_hist U b g a rs k j (o + i) rj hjk hr dr

theorem drsK_getD (ev : Sym → Fp2) (s a n i : ℕ) (hi : i < n) :
    (((drs s a n).map ev).map (Fp2.toK U)).getD i 0 = (ev (.dr s (a + i))).toK U := by
  unfold drs
  rw [List.map_map, List.map_map, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hi]
  rfl

end Draws

/-! ## `SC_SZC`'s named identity -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K]

/-- **`SC_SZC`'s named identity at the W16R2 rung** (lane L36's `FormAt` at host `17`): for every algebra data whose
`SC_SZC` tables are the relation tables of the extracted planes (`relCl 17`, `xcSzc`, `relGh 17 1`, `relMm 17 1`,
`SC_RS`'s row differences, the scale `32`), on every outcome whose verified slots are hosts exactly when their
definitions host slots, `SC_SZC`'s certified polynomial at the drawn challenges is its unmasked residual
`Σ Poly₁₇ − (32·ν₀·Σ Poly₄ + ν₁·Σ Poly₈)`. -/
theorem formAt_szc (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hcard : 78 < Fintype.card K) {L : ℕ}
    {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
    (B : W16Pub S Pb Lay)
    (P : BlockParams) (hdr : P.draws = W16R2.rungDraws) (hsl : P.geom.slots = W16R2.rungSlots)
    (ioIn ioOut : ℕ) (pubs : PubTabs) (hdef : P.define = defineS (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
    (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
    (hS : RungS S) (hL : LayW16 Lay) (hpub : PubW16 U pubs Pb Lay B)
    (dt : AlgData K L (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78)) (cu : Cuts3 L) (rt : RootsO)
    (hcl : ∀ bga (κ : Fin 10) (b : Fin 14 → Bool), dt.cl 17 cu rt bga κ b
      = if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 κ (.s (splitS b)))
        else xcSzc U P D Pb Lay B bga κ b)
    (hgh : ∀ b : Fin 14 → Bool, dt.gh 17 cu rt 1 b = algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
    (hmm : ∀ b : Fin 14 → Bool, dt.mm 17 cu rt 1 b = algebraMap GF K (relMm Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
    (hrsA : ∀ b : Fin 9 → Bool, dt.rsA cu rt b = algebraMap GF K (relRsA Pb Lay B (xtW U P D) (.ht (splitHt b))))
    (hrsB : ∀ b : Fin 9 → Bool, dt.rsB cu rt b = algebraMap GF K (relRsB Pb Lay B (xtW U P D) (.ht (splitHt b))))
    (hsc : dt.rsScale = 32)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ [])) :
    FormAt U P (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs)
      (fun k h => (algSp U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt hcard 0 cu rt k h).Φ) bga rs 17 := by
  obtain ⟨hs17, hs4, hs8⟩ := slotShape_szc P hsl
  have hk : (17 : ℕ) ∈ algHosts := mem17
  refine formAt_two U hcard P (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs hdef D _ dt cu rt bga rs 17 hk 4 8
    (.mul (.dr 17 24) (.base 32)) (.dr 17 25) (by rw [slot17_eq]) (by rw [slot4_eq]) (by rw [slot8_eq])
    (by decide) (by decide) hslots (fun r hr => ?_)
  have hlen : 17 < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨r4, hr4⟩ : ∃ r4, rs[4]? = some r4 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨r8, hr8⟩ : ∃ r8, rs[8]? = some r8 := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  -- the three slots' sums
  have hsp17 := szc_cube U P D hX hrl Pb Lay B hS hL (slotShape P 17).1 (slotShape P 17).2.1 (by rw [hs17])
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) r.draws
    (pubs 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) r.draws) (hpub.szcMask _ _)
    (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 17 (seenOf bga rs 17))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 17 r hr x, slot17_eq])
  have hsp4 := rs_cube U P D hrl Pb Lay B (slotShape P 4).1 (slotShape P 4).2.1 (by rw [hs4])
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws
    (pubs 4 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) r4.draws) (hpub.rsMask _ _)
    (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 4 (seenOf bga rs 4))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 4 r4 hr4 x, slot4_eq])
  have hsp8 := score_cube U P D hrl (slotShape P 8).1 (slotShape P 8).2.1 (by rw [hs8]) (by rw [hs8])
    (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws
    (pubs 8 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) r8.draws)
    (polyS U P D (DefW16.progW16 DefW16.cfgRungW16 ioIn ioOut) pubs 8 (seenOf bga rs 8))
    (fun x => by rw [polyS_seenOf U P D _ pubs bga rs 8 r8 hr8 x, slot8_eq])
  rw [szc_hostPhi U hcard P hdr dt cu rt _ r.draws]
  unfold spSum
  rw [hsp17, hsp4, hsp8]
  -- the batch
  have eZ : mleAt (fun b : Fin 14 → Bool => ∑ κ : Fin 10, (r.draws.getD (14 + κ) Fp2.zero).toK U
        * dt.cl 17 cu rt ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b) (fun t : Fin 14 => (r.draws.getD t Fp2.zero).toK U)
      = mleAt (fun b : Fin 14 → Bool => ∑ κ : Fin 10,
          ((muS.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD κ 0
          * (if (κ : ℕ) < 4 then algebraMap GF K (relCl Pb Lay B (xtW U P D) 17 κ (.s (splitS b)))
            else xcSzc U P D Pb Lay B ((histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).beta, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).gamma, (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)).alpha) κ b))
        (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 17 0 14) := by
    rw [ptv_own]
    congr 1
    · funext b
      refine Finset.sum_congr rfl (fun κ _ => ?_)
      rw [hcl, muS, drsK_getD U _ 17 14 10 κ κ.isLt, ev_own]
    · funext t
      rw [Nat.zero_add]
  -- `SC_RS`'s hosted function
  have eH0 : mleAt (algH U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) dt 17 cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 0)
      = 32 * ((mleAt (fun r : Fin 9 → Bool => aPl U P D 81920 9 r) (fun i => (r4.draws.getD i Fp2.zero).toK U)
          - mleAt (fun r : Fin 9 → Bool => ∑ j : Fin 5 → Bool,
              algebraMap GF K (B.mask (splitS (Fin.append r j))) * aPl U P D 802816 14 (Fin.append r j))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))
        + (r4.draws.getD 9 Fp2.zero).toK U
          * (1 - mleAt (fun r : Fin 9 → Bool => ∑ j : Fin 5 → Bool, aPl U P D 786432 14 (Fin.append r j))
            (fun i => (r4.draws.getD i Fp2.zero).toK U))) := by
    rw [algH0_mle U P hdr dt cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) hsc
      (fun r : Fin 9 → Bool => aPl U P D 81920 9 r - ∑ j : Fin 5 → Bool,
        algebraMap GF K (B.mask (splitS (Fin.append r j))) * aPl U P D 802816 14 (Fin.append r j))
      (fun r : Fin 9 → Bool => 1 - ∑ j : Fin 5 → Bool, aPl U P D 786432 14 (Fin.append r j))
      (fun b => (hrsA b).trans (rsA_alg U P D hX Pb Lay B hL b))
      (fun b => (hrsB b).trans (rsB_alg U P D hX Pb Lay B hL b))
      (fun i => (r4.draws.getD i Fp2.zero).toK U)
      (fun t => algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 t r4 (by decide) hr4),
      algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 9 r4 (by decide) hr4,
      mleAt_sub' (fun r : Fin 9 → Bool => aPl U P D 81920 9 r), mleAt_c_sub]
  -- `SC_SCORE`'s claim point and the hosted terms
  have hP8 : (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1 : Fin 14 → K)
      = fun t : Fin 14 => (r8.draws.getD t Fp2.zero).toK U := by
    funext t
    rw [algPt_score U P hdr (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) t, algDrawAt_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 t r8 (by decide) hr8]
  have eH1 : mleAt (dt.gh 17 cu rt 1) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = mleAt (fun b : Fin 14 → Bool => algebraMap GF K (relGh Pb Lay B (xtW U P D) 17 1 (.s (splitS b))))
        (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 8 0 14) := by
    rw [hP8, ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 8 r8 (by decide) hr8]
    exact congrArg₂ mleAt (funext hgh) (funext fun t => by rw [Nat.zero_add])
  have hpt8 : (fun t : Fin 14 => (r8.draws.getD t Fp2.zero).toK U)
      = (Fin.append (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
          (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 1))
        (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 4 5)
          (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 9 5)) : Fin 14 → K) := by
    rw [ptv_own, ptv_own, ptv_own, ptv_own]
    funext t
    fin_cases t <;> rfl
  have eM1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
      = ∑ g : Fin 3 → Bool, ∑ c : Fin 6 → Bool,
        eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3) (fun i => bit (g i))
        * ((∑ t : Fin 5 → Bool, ∑ j : Fin 1 → Bool,
            eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 4 5) (fun i => bit (t i))
            * eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 1)
              (fun i => bit (j i))
            * aPl U P D 507904 15 (Fin.append t (Fin.append (Fin.append g j) c)))
          * (∑ t' : Fin 5 → Bool,
            eqPoly (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 9 5) (fun i => bit (t' i))
            * aPl U P D 704512 14 (Fin.append t' (Fin.append g c)))) := by
    refine Eq.trans ?_ (score_eq (aPl U P D 507904 15) (aPl U P D 704512 14)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 1)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 4 5)
      (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 9 5)).symm
    have e1 : mleAt (dt.mm 17 cu rt 1) (algPt U (algShapeW16Rung P hdr mpadW mpadW_hm0 mpadW_hm78) 17 (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 1)
        = mleAt (fun z : Fin ((3 + 1) + (5 + 5)) → Bool =>
            algebraMap GF K (relMm Pb Lay B (xtW U P D) 17 1 (.s (splitS z))))
          (Fin.append (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 0 3)
              (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 3 1))
            (Fin.append (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 4 5)
              (ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 8)) 8 r8.draws) 8 9 5))) := by
      rw [hP8]
      exact congrArg₂ mleAt (funext hmm) hpt8
    rw [e1, mleAt_eq4]
    refine Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun j _ => Finset.sum_congr rfl
      (fun t _ => Finset.sum_congr rfl (fun t' _ => ?_))))
    rw [relMm171_alg U P D hX Pb Lay B g j t t']
  -- the weights and `λ`
  have es0 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.mul (.dr 17 24) (.base 32))).toK U = (r.draws.getD 24 Fp2.zero).toK U * 32 := by
    rw [ev_mul, Fp2.toK_mul U hU, ev_own, ev_base, Fp2.toK_fromBase, Fp.toGF_fromI64 32 (by norm_num) (by norm_num),
      map_intCast]
    norm_num
  have es1 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 25)).toK U = (r.draws.getD 25 Fp2.zero).toK U := by rw [ev_own]
  have enu0 : ((nuS.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD 0 0 = (r.draws.getD 24 Fp2.zero).toK U := by
    show (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 24)).toK U = _
    rw [ev_own]
  have enu1 : ((nuS.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws)).map (Fp2.toK U)).getD 1 0 = (r.draws.getD 25 Fp2.zero).toK U := by
    show (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 17 25)).toK U = _
    rw [ev_own]
  have el17 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws (.dr 4 9)).toK U = (r4.draws.getD 9 Fp2.zero).toK U :=
    ev_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 9 r4 (by decide) hr4 r.draws
  have el4 : (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws (.dr 4 9)).toK U
      = (r4.draws.getD 9 Fp2.zero).toK U := by rw [ev_own]
  have ep4 : ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 17)) 17 r.draws) 4 0 9 = fun i : Fin 9 => (r4.draws.getD i Fp2.zero).toK U := by
    rw [ptv_hist U bga.1 bga.2.1 bga.2.2 rs 17 4 r4 (by decide) hr4]
    funext i
    rw [Nat.zero_add]
  have ep4' : ptv U (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take 4)) 4 r4.draws) 4 0 9
      = fun i : Fin 9 => (r4.draws.getD i Fp2.zero).toK U := by
    rw [ptv_own]
    funext i
    rw [Nat.zero_add]
  rw [eZ, eH0, eH1, eM1, es0, es1, enu0, enu1, el17, el4, ep4, ep4']
  ring

end Form

end ZK60.Exec.Block.Join.W16.Szc
