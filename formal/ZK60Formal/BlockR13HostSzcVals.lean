/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 5: **`SC_SZC`'s named relations in the planes, the batch's entries
past the named clauses (`xcSzcR`), and the slot's polynomial at a cube point**, generic in the configuration `c` and
the softmax limb count `ls`, on the lane's foundation (`BlockR13HostBase.lean`).

* `xS`: the point of `Dom::S` at a cube point (`encR G 17`'s); `append_splitS`, `headS`: its blocks;
* `alg_plS_R`, `alg_plHt_R`, `alg_lvS`: the extracted planes `xtR` at that point are the tables' entries;
* `r13Cl17_alg`, `r13Gh171_alg`: `SC_SZC`'s five clauses `s0 … s4` and its second hosted term, embedded;
* `valsR`: the value list at a cube point; **`xcSzcR`**: the batch's entries `5 … 12 + ls` (LogUp's `7 + ls` helper
  relations over `DefR13.lksS c shaped .S`, then the exp tuple's relation) on the value list without the draws, as
  lane L44's `xcSzc`;
* **`szcR_point`**: `SC_SZC`'s polynomial at a cube point is
  `eq(τ)·Σ_κ μ_κ·c_κ + ν₀·eq(p_ht)·(SUM + λ) + ν₁·eq(P₁)·h₁` with `c_κ` the named relations (`r13Cl 17`) for `κ < 5`
  and `xcSzcR` past them, `h₁ = r13Gh 17 1`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcTabs
import ZK60Formal.BlockR13HostBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl piB aPl_alg cstK cstS_map)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV L256 batchV LkD logupSem padSem)
open ZK60.Exec.Slot.Compose (cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open ZK60.Layout.R13 (R13Data lv)
open Finset

/-! ## The point of `Dom::S` and the planes there -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P)

/-- **The point of `Dom::S` at a cube point of `SC_SZC`** (`encR G 17`'s). -/
def xS (b : Fin (c.sh.logs .S) → Bool) : (CgR c × CjR c) × CtR c × CtR c := splitS c (castB G.logS b)

theorem encR17 (b : Fin (tauLen c 17) → Bool) : encR G 17 b = .s (xS G b) := rfl

include G in
/-- `Dom::Ht` fits in `Dom::S`. -/
theorem hHtS : nHt c ≤ c.sh.logs .S := by
  rw [G.logS]
  show nH c + c.sh.lt ≤ nH c + (c.sh.lt + c.sh.lt)
  omega

include G in
theorem hHS_logs : c.sh.logs .Ht ≤ c.sh.logs .S := by
  rw [G.logHt]
  exact hHtS G

omit [Field K] [Algebra GF K] in
/-- `Dom::S`'s bit vector from its four blocks. -/
theorem append_splitS (y : Fin (nS c) → Bool) :
    Fin.append (Fin.append (splitS c y).1.1 (splitS c y).1.2) (Fin.append (splitS c y).2.1 (splitS c y).2.2) = y := by
  funext i
  refine Fin.addCases (m := nH c) (n := c.sh.lt + c.sh.lt) (fun i4 => ?_) (fun i10 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (m := c.sh.lkv) (n := c.sh.lh - c.sh.lkv) (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]
    refine Fin.addCases (m := c.sh.lt) (n := c.sh.lt) (fun i5 => ?_) (fun i5' => ?_) i10
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl

omit [Field K] [Algebra GF K] in
/-- **The first `Dom::Ht` bits of `Dom::S`'s point** are the cube point's first bits. -/
theorem headS (b : Fin (c.sh.logs .S) → Bool) (i : Fin (nHt c)) :
    Fin.append (Fin.append (xS G b).1.1 (xS G b).1.2) (xS G b).2.1 i
      = b ⟨i, lt_of_lt_of_le i.isLt (hHtS G)⟩ := by
  unfold xS
  refine Fin.addCases (m := nH c) (n := c.sh.lt) (fun i4 => ?_) (fun i5 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (m := c.sh.lkv) (n := c.sh.lh - c.sh.lkv) (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]
      exact congrArg b (Fin.ext (by simp))
    · rw [Fin.append_right]
      exact congrArg b (Fin.ext (by simp))
  · rw [Fin.append_right]
    exact congrArg b (Fin.ext (by simp))

variable (hX : ∀ i t, D.X .a i t ∈ baseR K)

include hX in
/-- **A `Dom::S` plane at `Dom::S`'s point is the table's entry.** -/
theorem alg_plS_R (off : ℕ) (b : Fin (c.sh.logs .S) → Bool) :
    algebraMap GF K (plS U c P D off (xS G b)) = aPl U P D off (c.sh.logs .S) b := by
  unfold plS
  rw [show Fin.append (Fin.append (xS G b).1.1 (xS G b).1.2) (Fin.append (xS G b).2.1 (xS G b).2.2)
      = castB G.logS b from append_splitS _, aPl_alg U P D hX, aPl_castB]

include hX in
/-- **A `Dom::Ht` plane at `Dom::S`'s row** is the table's entry on the first `Dom::Ht` variables. -/
theorem alg_plHt_R (off : ℕ) (b : Fin (c.sh.logs .S) → Bool) :
    algebraMap GF K (plH U c P D off ((xS G b).1, (xS G b).2.1)) = aPl U P D off (c.sh.logs .Ht) (hdB _ b) := by
  unfold plH
  rw [aPl_alg U P D hX]
  refine aPl_ext U P D G.logHt.symm off _ _ (fun i => ?_)
  rw [headS G b i]
  have hi : ((Fin.cast G.logHt.symm i : Fin (c.sh.logs .Ht)) : ℕ) < c.sh.logs .S := lt_of_lt_of_le i.isLt (hHtS G)
  unfold hdB
  exact (dite_eq_left (t := fun h => b ⟨((Fin.cast G.logHt.symm i : Fin (c.sh.logs .Ht)) : ℕ), h⟩)
    (e := fun _ => false) hi).symm

include hX in
/-- **Byte limbs of `Dom::S` planes at `Dom::S`'s point.** -/
theorem alg_lvS {m : ℕ} (o : ℕ) (b : Fin (c.sh.logs .S) → Bool) :
    algebraMap GF K (lv (fun k : Fin m => plS U c P D (offR c (o + k))) (xS G b))
      = ∑ k : Fin m, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (o + k)) (c.sh.logs .S) b := by
  unfold lv
  rw [map_sum]
  refine Finset.sum_congr rfl (fun k _ => ?_)
  rw [map_mul, map_pow, map_ofNat, alg_plS_R U G P D hX]

end Rels

/-! ## The named relations, embedded -/

section Named

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include hX in
/-- **`SC_SZC`'s five clauses, embedded**, in the planes (the gate is `1`: `Dom::S` does not pad). -/
theorem r13Cl17_alg (hLay : LayR Lay) (hS : PrecR c S) (b : Fin (c.sh.logs .S) → Bool) :
    [algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 0 (.s (xS G b))),
      algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))),
      algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 2 (.s (xS G b))),
      algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 3 (.s (xS G b))),
      algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 4 (.s (xS G b)))]
    = [aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b * aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b
          - aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b,
        aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b * (aPl U P D (DefR13.aOff c 4) (c.sh.logs .Ht) (hdB _ b)
          - algebraMap GF K (B.mask (xS G b)) * (aPl U P D (DefR13.aOff c 75) (c.sh.logs .S) b + 127) + 127),
        algebraMap GF K (B.mask (xS G b)) * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) b * 2 ^ c.p.fp
          - aPl U P D (DefR13.aOff c 81) (c.sh.logs .S) b * aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b)
          - ∑ k : Fin (ls + 1), (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (84 + k)) (c.sh.logs .S) b,
        ∑ k : Fin (ls + 1), (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (84 + (ls + 1) + k)) (c.sh.logs .S) b
          + ∑ k : Fin (ls + 1), (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (84 + k)) (c.sh.logs .S) b + 1
          - aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b),
        aPl U P D (DefR13.aOff c 81) (c.sh.logs .S) b
          - ∑ k : Fin 2, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (82 + k)) (c.sh.logs .S) b] := by
  have hg : B.gS (xS G b) = 1 := gS_oneR B hLay _
  have e0 : r13Cl Pb Lay B (xtR U c P D ls) 17 0 (.s (xS G b))
      = B.gS (xS G b) * (plS U c P D (offR c 79) (xS G b) * plS U c P D (offR c 79) (xS G b)
        - plS U c P D (offR c 79) (xS G b)) := rfl
  have e1 : r13Cl Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))
      = B.gS (xS G b) * (plS U c P D (offR c 79) (xS G b) * (plH U c P D (offR c 4) ((xS G b).1, (xS G b).2.1)
        - B.mask (xS G b) * (plS U c P D (offR c 75) (xS G b) + 127) + 127)) := rfl
  have e2 : r13Cl Pb Lay B (xtR U c P D ls) 17 2 (.s (xS G b))
      = B.gS (xS G b) * (B.mask (xS G b) * plS U c P D (offR c 80) (xS G b) * 2 ^ S.fp
        - plS U c P D (offR c 81) (xS G b) * plH U c P D (offR c 5) ((xS G b).1, (xS G b).2.1)
        - lv (fun k : Fin (ls + 1) => plS U c P D (offR c (84 + k))) (xS G b)) := rfl
  have e3 : r13Cl Pb Lay B (xtR U c P D ls) 17 3 (.s (xS G b))
      = B.gS (xS G b) * (lv (fun k : Fin (ls + 1) => plS U c P D (offR c (84 + (ls + 1) + k))) (xS G b)
        + lv (fun k : Fin (ls + 1) => plS U c P D (offR c (84 + k))) (xS G b) + 1
        - plH U c P D (offR c 5) ((xS G b).1, (xS G b).2.1)) := rfl
  have e4 : r13Cl Pb Lay B (xtR U c P D ls) 17 4 (.s (xS G b))
      = B.gS (xS G b) * (plS U c P D (offR c 81) (xS G b)
        - lv (fun k : Fin 2 => plS U c P D (offR c (82 + k))) (xS G b)) := rfl
  rw [e0, e1, e2, e3, e4, hg, hS.fp]
  simp only [one_mul, map_sub, map_mul, map_add, map_pow, map_ofNat, map_one, alg_plS_R U G P D hX,
    alg_plHt_R U G P D hX, alg_lvS U G P D hX]

include hX in
/-- **`SC_SZC`'s second hosted term (`SC_SCORE`'s requantization), embedded.** -/
theorem r13Gh171_alg (hLay : LayR Lay) (hS : PrecR c S) (b : Fin (c.sh.logs .S) → Bool) :
    algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b)))
      = 2 ^ c.p.score * aPl U P D (DefR13.aOff c 75) (c.sh.logs .S) b
        + ∑ k : Fin 3, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (76 + k)) (c.sh.logs .S) b
        - 2 ^ (c.p.score - 1) := by
  have hg : B.gS (xS G b) = 1 := gS_oneR B hLay _
  have e1 : r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))
      = B.gS (xS G b) * (2 ^ S.ss * plS U c P D (offR c 75) (xS G b)
        + lv (fun k : Fin 3 => plS U c P D (offR c (76 + k))) (xS G b) - 2 ^ (S.ss - 1)) := rfl
  rw [e1, hg, hS.ss]
  simp only [one_mul, map_sub, map_mul, map_add, map_pow, map_ofNat, alg_plS_R U G P D hX, alg_lvS U G P D hX]

end Named

/-! ## The value list and the batch's entries past the named clauses -/

section Xc

variable {K : Type} [Field K] [Algebra GF K]

/-- **`SC_SZC`'s value list at a cube point**: the three `eq` entries, the public mask, the planes. -/
noncomputable def valsR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay) (e0 e1 e2 : K)
    (b : Fin (c.sh.logs .S) → Bool) : List K :=
  e0 :: e1 :: e2 :: algebraMap GF K (B.mask (xS G b)) :: restTR U c ls P D b

/-- `SC_SZC`'s lookups read in the field, at `α`, `γ` of `bga = (β, γ, α)`. -/
noncomputable def lksKR (U : K) (c : W16Cfg) (bga : Fp2 × Fp2 × Fp2) : List (LkD K) :=
  ((DefR13.lksS c shapedR .S).map (LkD.map (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 []))).map
    (LkD.map (Fp2.toK U))

/-- **The batch's entries of `SC_SZC` past its five named clauses**: entries `5 … 11 + ls` LogUp's `7 + ls` helper
relations (over `DefR13.lksS c shaped .S`), entry `12 + ls` the exp tuple's relation `hx·(α − g_exp − δ − β·e) − 1`,
on the value list without the draws (lane L44's `xcSzc` at R13). It reads the committed planes, the public mask and
`(α, β, γ) = bga` only. -/
noncomputable def xcSzcR (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams) (D : CmData K P)
    {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S}
    {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)
    (bga : Fp2 × Fp2 × Fp2) (κ : ℕ) (b : Fin (tauLen c 17) → Bool) : K :=
  (List.replicate 5 0 ++ lkRels (cstK U) (valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0 (lksKR U c bga)
    ++ [r13SzcExp (cstK U) (RSzR ls) (valsR U G P D B 0 0 0 b)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.sub .alpha (.gtag 129))).toK U)
      ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 []) 17 [] (.neg .beta)).toK U)]).getD κ 0

end Xc

/-! ## `SC_SZC`'s IR at a cube point -/

section Point

variable {K : Type} [Field K] [Algebra GF K] (U : K) {c : W16Cfg} {ls : ℕ} (G : GeoR c ls) (P : BlockParams)
  (D : CmData K P) (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
  {Lay : W16Layout S (CtR c) (CwR c) (CgR c) (CjR c) (CdR c) (CfR c)} (B : W16Pub S Pb Lay)

include hX in
/-- **`SC_SZC`'s polynomial at a cube point with the zero extension**: `eq(τ)·Σ_κ μ_κ·c_κ + ν₀·eq(p_ht)·(SUM + λ)
+ ν₁·eq(P₁)·h₁`, with `c_κ` the named relations for `κ < 5` and `xcSzcR` past them. -/
theorem szcR_point (hLay : LayR Lay) (hS : PrecR c S) (hls : ls ≤ 2) (hfp : c.p.fp ≤ 15) (hsc : c.p.score ≤ 24)
    (hlk : (DefR13.lookups c .S).length = 13 + 2 * ls) (hist : Hist) (dr : List Fp2) (e0 e1 e2 : K)
    (b : Fin (c.sh.logs .S) → Bool) :
    irEval (((irSzcR c ls).map (Sym.eval hist 17 dr)).map (Fp2.toK U)) (valsR U G P D B e0 e1 e2 b)
      = e0 * ∑ κ ∈ Finset.range (13 + ls),
            (((drsR 17 (c.sh.logs .S) (13 + ls)).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD κ 0
            * (if κ < 5 then algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 κ (.s (xS G b)))
              else xcSzcR U G P D B (hist.beta, hist.gamma, hist.alpha) κ b)
        + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 0 0
          * (e1 * (aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b)
            + (Sym.eval hist 17 dr (.dr 4 (c.sh.logs .Ht))).toK U))
        + (((drsR 17 (c.sh.logs .S + (13 + ls)) 2).map (Sym.eval hist 17 dr)).map (Fp2.toK U)).getD 1 0
          * (e2 * algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b)))) := by
  -- the IR, evaluated
  have hnh : ((((DefR13.lksS c shapedR .S).map (LkD.map (Sym.eval hist 17 dr))).map
      (LkD.map (Fp2.toK U))).length + 1) / 2 = 7 + ls := by
    rw [List.length_map, List.length_map]
    unfold DefR13.lksS
    rw [List.length_map, hlk]
    omega
  unfold irSzcR
  rw [r13SzcIr_map, r13SzcIr_map, cstS_map, r13SzcIr_eval _ (cstW_map_std U), hnh]
  have hgHt : (RSzR ls).gHt = none := rfl
  have hgS : (RSzR ls).gS = none := rfl
  have hh0 : (RSzR ls).h0 = 17 + 2 * ls := rfl
  have hsum : (RSzR ls).sum = 16 + 2 * ls := rfl
  have hs8 : (RSzR ls).s8 = 4 := rfl
  have hrsl : (RSzR ls).rsl = List.range' 5 3 := rfl
  rw [hgHt, hgS, hh0, hsum, hs8, hrsl]
  -- the LogUp part and the exp tuple: as in `xcSzcR`
  have hlk1 : lkRels (cstK U) (valsR U G P D B e0 e1 e2 b) (17 + 2 * ls) 0
        (((DefR13.lksS c shapedR .S).map (LkD.map (Sym.eval hist 17 dr))).map (LkD.map (Fp2.toK U)))
      = lkRels (cstK U) (valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0
        (lksKR U c (hist.beta, hist.gamma, hist.alpha)) := by
    refine (lkRels_cons3R U (17 + 2 * ls) e0 e1 e2 _ _ (lksSR_pos c _ _) (by omega)).trans ?_
    unfold lksKR
    rw [lksSR_eval c shapedR .S hist (histOf hist.beta hist.gamma hist.alpha []) 17 17 dr [] rfl rfl]
    rfl
  have hex : r13SzcExp (cstK U) (RSzR ls) (valsR U G P D B e0 e1 e2 b)
        ((Sym.eval hist 17 dr (.sub .alpha (.gtag 129))).toK U) ((Sym.eval hist 17 dr (.neg .beta)).toK U)
      = r13SzcExp (cstK U) (RSzR ls) (valsR U G P D B 0 0 0 b)
        ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.sub .alpha (.gtag 129))).toK U)
        ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.neg .beta)).toK U) :=
    expR_cons3 (cstK U) ls e0 e1 e2 _ _ _
  have hlkLen : (lkRels (cstK U) (valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0
      (lksKR U c (hist.beta, hist.gamma, hist.alpha))).length = 7 + ls := by
    rw [lkRels_length]
    unfold lksKR DefR13.lksS
    rw [List.length_map, List.length_map, List.length_map, hlk]
    omega
  -- the batch, as `xcSzcR` writes it
  have hbat := batchR (fun q => ((((drsR 17 (c.sh.logs .S) (13 + ls)).map (Sym.eval hist 17 dr)).map
      (Fp2.toK U)).getD q 0))
    (fun q => algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 q (.s (xS G b))))
    (lkRels (cstK U) (valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0 (lksKR U c (hist.beta, hist.gamma, hist.alpha)))
    (r13SzcExp (cstK U) (RSzR ls) (valsR U G P D B 0 0 0 b)
      ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.sub .alpha (.gtag 129))).toK U)
      ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.neg .beta)).toK U))
  rw [hlkLen, show 5 + (7 + ls) + 1 = 13 + ls by omega] at hbat
  have hxc : ∀ κ, xcSzcR U G P D B (hist.beta, hist.gamma, hist.alpha) κ b
      = (List.replicate 5 0 ++ lkRels (cstK U) (valsR U G P D B 0 0 0 b) (17 + 2 * ls) 0
          (lksKR U c (hist.beta, hist.gamma, hist.alpha))
        ++ [r13SzcExp (cstK U) (RSzR ls) (valsR U G P D B 0 0 0 b)
          ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.sub .alpha (.gtag 129))).toK U)
          ((Sym.eval (histOf hist.beta hist.gamma hist.alpha []) 17 [] (.neg .beta)).toK U)]).getD κ 0 :=
    fun κ => rfl
  simp only [hxc]
  rw [hbat]
  -- the named clauses on the value list
  have v3 : (valsR U G P D B e0 e1 e2 b).getD 3 0 = algebraMap GF K (B.mask (xS G b)) := rfl
  have v4 : (valsR U G P D B e0 e1 e2 b).getD 4 0 = aPl U P D (DefR13.aOff c 75) (c.sh.logs .S) b :=
    vR_pl U e0 e1 e2 _ c ls P D b 0 (by omega)
  have v8 : (valsR U G P D B e0 e1 e2 b).getD 8 0 = aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b :=
    vR_pl U e0 e1 e2 _ c ls P D b 4 (by omega)
  have v9 : (valsR U G P D B e0 e1 e2 b).getD 9 0 = aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) b :=
    vR_pl U e0 e1 e2 _ c ls P D b 5 (by omega)
  have v10 : (valsR U G P D B e0 e1 e2 b).getD 10 0 = aPl U P D (DefR13.aOff c 81) (c.sh.logs .S) b :=
    vR_pl U e0 e1 e2 _ c ls P D b 6 (by omega)
  have vmx : (valsR U G P D B e0 e1 e2 b).getD (15 + 2 * ls) 0
      = aPl U P D (DefR13.aOff c 4) (c.sh.logs .Ht) (hdB _ b) := vR_mx U e0 e1 e2 _ c ls P D b
  have vsm : (valsR U G P D B e0 e1 e2 b).getD (16 + 2 * ls) 0
      = aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b) := vR_sum U e0 e1 e2 _ c ls P D b
  have lsr : L256 (cstK U) (valsR U G P D B e0 e1 e2 b) (List.range' 13 (ls + 1))
      = ∑ k : Fin (ls + 1), (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (84 + k)) (c.sh.logs .S) b :=
    vR_L256 U e0 e1 e2 _ c ls P D b 13 (ls + 1) 84 (by omega) (by omega) (by omega) (by omega)
  have lsg : L256 (cstK U) (valsR U G P D B e0 e1 e2 b) (List.range' (14 + ls) (ls + 1))
      = ∑ k : Fin (ls + 1), (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (84 + (ls + 1) + k)) (c.sh.logs .S) b :=
    vR_L256 U e0 e1 e2 _ c ls P D b (14 + ls) (ls + 1) (84 + (ls + 1)) (by omega) (by omega) (by omega) (by omega)
  have lpl : L256 (cstK U) (valsR U G P D B e0 e1 e2 b) (List.range' 11 2)
      = ∑ k : Fin 2, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (82 + k)) (c.sh.logs .S) b :=
    vR_L256 U e0 e1 e2 _ c ls P D b 11 2 82 (by omega) (by omega) (by omega) (by omega)
  have lrsl : L256 (cstK U) (valsR U G P D B e0 e1 e2 b) (List.range' 5 3)
      = ∑ k : Fin 3, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (76 + k)) (c.sh.logs .S) b :=
    vR_L256 U e0 e1 e2 _ c ls P D b 5 3 76 (by omega) (by omega) (by omega) (by omega)
  have hcl := r13Cl17_alg U G P D hX Pb B hLay hS b
  simp only [List.cons.injEq, and_true] at hcl
  obtain ⟨c0, c1, c2, c3, c4⟩ := hcl
  have hgh := r13Gh171_alg U G P D hX Pb B hLay hS b
  have hcls : r13SzcClauses (cstK U) (RSzR ls) c.p.fp (valsR U G P D B e0 e1 e2 b)
      = [algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 0 (.s (xS G b))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 2 (.s (xS G b))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 3 (.s (xS G b))),
        algebraMap GF K (r13Cl Pb Lay B (xtR U c P D ls) 17 4 (.s (xS G b)))] := by
    rw [c0, c1, c2, c3, c4]
    have hzsel : (RSzR ls).zsel = 8 := rfl
    have hmx : (RSzR ls).mx = 15 + 2 * ls := rfl
    have hmask : (RSzR ls).mask = 3 := rfl
    have he : (RSzR ls).e = 9 := rfl
    have hp : (RSzR ls).p = 10 := rfl
    have hpl : (RSzR ls).pl = List.range' 11 2 := rfl
    have hsr : (RSzR ls).sr = List.range' 13 (ls + 1) := rfl
    have hsg : (RSzR ls).sg = List.range' (14 + ls) (ls + 1) := rfl
    unfold r13SzcClauses r13SzcDelta
    rw [hzsel, hmx, hmask, he, hp, hs8, hsum, hpl, hsr, hsg, lsr, lsg, lpl, v3, v4, v8, v9, v10, vmx, vsm,
      basePow U c.p.fp (by omega), W16.Szc.cK U (-127) (by norm_num) (by norm_num),
      W16.Szc.cK U 127 (by norm_num) (by norm_num)]
    have L5 : ∀ {a1 a2 a3 a4 a5 b1 b2 b3 b4 b5 : K}, a1 = b1 → a2 = b2 → a3 = b3 → a4 = b4 → a5 = b5 →
        [a1, a2, a3, a4, a5] = [b1, b2, b3, b4, b5] := by
      intro a1 a2 a3 a4 a5 b1 b2 b3 b4 b5 h1 h2 h3 h4 h5
      rw [h1, h2, h3, h4, h5]
    refine L5 ?_ ?_ ?_ ?_ ?_ <;> (try push_cast) <;> ring
  have hreq : reqV8 (cstK U) (valsR U G P D B e0 e1 e2 b) c.p.score 4 (List.range' 5 3)
      = algebraMap GF K (r13Gh Pb Lay B (xtR U c P D ls) 17 1 (.s (xS G b))) := by
    rw [hgh]
    unfold reqV8
    rw [lrsl, v4, basePow U c.p.score (by omega), baseNegPow U (c.p.score - 1) (by omega)]
    ring
  rw [hcls, hreq, vsm, logupSem_eq_wsum, hlk1, hex]
  have h0 : (valsR U G P D B e0 e1 e2 b).getD 0 0 = e0 := rfl
  have h1 : (valsR U G P D B e0 e1 e2 b).getD 1 0 = e1 := rfl
  have h2 : (valsR U G P D B e0 e1 e2 b).getD 2 0 = e2 := rfl
  simp only [hostTerms, gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul, padSem, add_zero, batchV,
    List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.sum_cons, List.sum_nil, h0, h1, h2]
  ring

end Point

end ZK60.Exec.Block.Join.R13H.Szc
