/-
D63 lane L41 (2026-11-10), part 6: **`SC_TZC`'s named identity at the W16R2 rung** (the first host of lane L36's
`hform`), with its hosted `SC_SS` and `SC_SSM`.

* `tabs0`, `tabs1`, `tabs2`: the three slots' tables at the rung (**`slot0_eq`**, **`slot1_eq`**, **`slot2_eq`**: the
  program's, by evaluation);
* `cstK`: the builders' constants in the field (`cstK_base`, `cstK_p256`, `cstK_p16`);
* **`tzc_vals`**: the value list `SC_TZC`'s IR reads at a cube point with the zero extension: the three `eq`
  tables, then the norms' planes and their isqrt byte limbs (`xtW`'s fields, embedded);
* **`tzc_clauses`**: the IR's six clauses there ARE `W16Rels`' six `SC_TZC` relations of the extracted planes
  (`relCl 2 j`), embedded; **`tzc_hosted`**: its two hosted terms ARE `relGh 2 i` (the token gate is `1`: the token
  axis does not pad);
* **`ss_sum`**: `SC_SS`'s (`SC_SSM`'s) unmasked cube sum is the multilinear extension of `relMm 2 0` (`relMm 2 1`) at
  its point;
* **`tzc_spSum`**: `SC_TZC`'s unmasked cube sum is `Σ_b hostPoly(τ, Σ_j μ_j·relCl 2 j, ν, P, 1, relGh 2)(b)`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinW16
import ZK60Formal.BlockJoinVals
import ZK60Formal.BlockDefineW16Rung
import ZK60Formal.BlockAlgRels

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (Cst cstW hostTerms gV gV_some L256 batchV tzcIr tzcClauses tzcIr_eval TzcR padSem ssIr
  ssIr_eval)
open ZK60.Exec.Slot.Compose (tzcIr_map ssIr_map cstW_map_std)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The three slots at the rung -/

/-- The draws of slot `s` at positions `0 … 4`, as expressions. -/
def dr5 (s : ℕ) : List Sym := [.dr s 0, .dr s 1, .dr s 2, .dr s 3, .dr s 4]

theorem dr5_length (s : ℕ) (ev : Sym → Fp2) : ((dr5 s).map ev).length = 5 := rfl

/-- A private table of one `A` slice on its own first `log` coordinates. -/
def paT (off log m : ℕ) : TabS := .priv ⟨.a, [(off, false)], log, DefW16.rhoC 0 log, m, 0⟩

/-- `SC_SS`'s tables: `eq(r_t)` on the first five variables, the plane `X`, the gate `supp(D)`. -/
def tabs0 : List TabS :=
  [.eq (dr5 0) 0, paT 131072 14 90, .pub 0]

/-- `SC_SSM`'s tables: `eq(r_t2)`, the plane `X1`, the gate. -/
def tabs1 : List TabS :=
  [.eq (dr5 1) 0, paT 278528 14 92, .pub 0]

/-- `SC_TZC`'s tables: `eq(τ)`, `eq(r_t)`, `eq(r_t2)`, `D`, `DSQ`, `D`'s nine byte limbs, `DM`, `DSQM`, `DM`'s nine. -/
def tabs2 : List TabS :=
  [.eq (dr5 2) 0, .eq (dr5 0) 0, .eq (dr5 1) 0,
    paT 0 5 94, paT 16384 5 96,
    paT 98304 5 98, paT 98336 5 100, paT 98368 5 102, paT 98400 5 104, paT 98432 5 106, paT 98464 5 108,
    paT 98496 5 110, paT 98528 5 112, paT 98560 5 114,
    paT 32768 5 116, paT 49152 5 118,
    paT 114688 5 120, paT 114720 5 122, paT 114752 5 124, paT 114784 5 126, paT 114816 5 128, paT 114848 5 130,
    paT 114880 5 132, paT 114912 5 134, paT 114944 5 136]

/-- `SC_TZC`'s table positions. -/
def rrTzc : TzcR := ⟨0, 1, 2, 3, 4, 14, 15, none⟩

/-- `SC_TZC`'s batch draws `μ` and hosted draws `ν`. -/
def muTzc : List Sym := [.dr 2 5, .dr 2 6, .dr 2 7, .dr 2 8, .dr 2 9, .dr 2 10]
def nuTzc : List Sym := [.dr 2 11, .dr 2 12]

theorem slot2_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 2 SlotS.empty
    = ⟨tabs2, tzcIr DefW16.cstS rrTzc 1 muTzc nuTzc (fun j => Sym.pow Sym.zero j) [],
        [(0, .dr 2 11), (1, .dr 2 12)], [.dr 2 11, .dr 2 12]⟩ := rfl

theorem slot0_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 0 SlotS.empty
    = ⟨tabs0, ssIr DefW16.cstS 0 1 (some 2), [], []⟩ := rfl

theorem slot1_eq (ioIn ioOut : ℕ) : (progW16 cfgRungW16 ioIn ioOut).getD 1 SlotS.empty
    = ⟨tabs1, ssIr DefW16.cstS 0 1 (some 2), [], []⟩ := rfl

/-! ## The builders' constants in the field -/

section Cst

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The builders' constants read in the field. -/
abbrev cstK : Cst K := cstW.map (Fp2.toK U)

theorem cstS_map (hist : Hist) (k : ℕ) (dr : List Fp2) : DefW16.cstS.map (Sym.eval hist k dr) = cstW := rfl

theorem cstK_base (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) : (cstK U).base v = algebraMap GF K (v : GF) := by
  show (Fp2.fromBase (Fp.fromI64 v)).toK U = _
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 v h1 h2]

theorem cstK_p256 (j : ℕ) (hj : j < 8) : (cstK U).p256 j = (256 : K) ^ j := by
  show (Fp2.fromU64 (UInt64.ofNat (2 ^ (8 * j)))).toK U = _
  have hlt : 2 ^ (8 * j) < 2 ^ 64 := Nat.pow_lt_pow_right (by norm_num) (by omega)
  rw [Fp2.toK_fromU64_ofNat U _ hlt, pow_mul]
  push_cast
  norm_num

theorem cstK_p16 (j : ℕ) (hj : j < 4) : (cstK U).p16 j = algebraMap GF K ((2 : GF) ^ (16 * j)) := by
  show (Fp2.fromBase (Fp.new (UInt64.ofNat (2 ^ (16 * j))))).toK U = _
  have hlt : 2 ^ (16 * j) < 2 ^ 64 := Nat.pow_lt_pow_right (by norm_num) (by omega)
  rw [Fp2.toK_fromBase, Fp.new_toGF_ofNat _ hlt]
  push_cast
  rfl

end Cst

/-! ## The value list of `SC_TZC` at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **An `A` slice on its own first `L` coordinates, at the zero extension of a cube of `n = L` main variables.** -/
theorem tabK_pa_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool) (L : ℕ)
    (hL : 0 < L) (hn : n = L) (off m ext : ℕ) :
    tabK U P D n e (cpt n e b) (.priv ⟨.a, [(off, Fp2.one)], L, rhoAll L, m, ext⟩)
      = aPl U P D off L (castB hn b) := by
  rw [tabK_rho_cpt U P D n e b _ (by simp) hL hrl rfl (by show L ≤ n; omega)]
  rfl

/-- **An `A` slice on the first `L` of `n` main variables, at the zero extension.** -/
theorem tabK_paHead_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (L : ℕ) (hL : 0 < L) (hle : L ≤ n) (off m ext : ℕ) :
    tabK U P D n e (cpt n e b) (.priv ⟨.a, [(off, Fp2.one)], L, rhoAll L, m, ext⟩)
      = aPl U P D off L (fun a => b ⟨a, by omega⟩) := by
  rw [tabK_rho_cpt U P D n e b _ (by simp) hL hrl rfl (by show L ≤ n; exact hle)]
  rfl

/-- `TabS.eval` of an `eq` table. -/
theorem eqT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (pt : List Sym) (st : ℕ) :
    TabS.eval ev pub (.eq pt st) = .eq (pt.map ev) st := rfl

/-- `TabS.eval` of a public table. -/
theorem pubT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (i : ℕ) : TabS.eval ev pub (.pub i) = .pub (pub i) := rfl

/-- `TabS.eval` of `paT`. -/
theorem paT_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off log m : ℕ) :
    TabS.eval ev pub (paT off log m) = .priv ⟨.a, [(off, Fp2.one)], log, rhoAll log, m, 0⟩ :=
  aTab_eval ev pub off log 0 m

/-- **`SC_TZC`'s value list at a cube point with the zero extension** (`n = 5` main variables). -/
theorem tzc_vals (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (hn : n = 5) (b : Fin n → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    (tabs2.map (TabS.eval ev pub)).map (tabK U P D n e (cpt n e b))
      = [eqPoly (fun a : Fin n => (((dr5 2).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         eqPoly (fun a : Fin n => (((dr5 0).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         eqPoly (fun a : Fin n => (((dr5 1).map ev).getD a Fp2.zero).toK U) (fun a => bit (b a)),
         aPl U P D 0 5 (castB hn b), aPl U P D 16384 5 (castB hn b),
         aPl U P D 98304 5 (castB hn b), aPl U P D 98336 5 (castB hn b), aPl U P D 98368 5 (castB hn b),
         aPl U P D 98400 5 (castB hn b), aPl U P D 98432 5 (castB hn b), aPl U P D 98464 5 (castB hn b),
         aPl U P D 98496 5 (castB hn b), aPl U P D 98528 5 (castB hn b), aPl U P D 98560 5 (castB hn b),
         aPl U P D 32768 5 (castB hn b), aPl U P D 49152 5 (castB hn b),
         aPl U P D 114688 5 (castB hn b), aPl U P D 114720 5 (castB hn b), aPl U P D 114752 5 (castB hn b),
         aPl U P D 114784 5 (castB hn b), aPl U P D 114816 5 (castB hn b), aPl U P D 114848 5 (castB hn b),
         aPl U P D 114880 5 (castB hn b), aPl U P D 114912 5 (castB hn b), aPl U P D 114944 5 (castB hn b)] := by
  have hlen : ∀ s, ((dr5 s).map ev).length = n := fun s => by rw [dr5_length, hn]
  simp only [tabs2, List.map_cons, List.map_nil, paT_eval, eqT_eval]
  simp only [tabK_pa_cpt U P D hrl n e b 5 (by norm_num) hn]
  rw [tabK_eqFull_cpt U P D n e b _ (hlen 2), tabK_eqFull_cpt U P D n e b _ (hlen 0),
    tabK_eqFull_cpt U P D n e b _ (hlen 1)]

end Vals

/-! ## The clauses and the hosted terms are the named relations -/

section Rels

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX

theorem alg_plT (off : ℕ) (t : CtW) : algebraMap GF K (plT U P D off t) = aPl U P D off 5 t :=
  aPl_alg U P D hX off 5 t

theorem alg_plL (off : ℕ) (i k : Fin 3) (t : CtW) :
    algebraMap GF K (plL U P D off i k t) = aPl U P D (off + 32 * (3 * (i : ℕ) + k)) 5 t :=
  aPl_alg U P D hX _ 5 t

theorem alg_plD (off : ℕ) (x : CtW × CwW) :
    algebraMap GF K (plD U P D off x) = aPl U P D off 14 (Fin.append x.1 x.2) :=
  aPl_alg U P D hX off 14 _

/-- **`SC_TZC`'s six relations, embedded**, in the planes. -/
theorem relCl2_alg (t : CtW) :
    [algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 0 (.t t)), algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 1 (.t t)),
      algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 2 (.t t)), algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 3 (.t t)),
      algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 4 (.t t)), algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 5 (.t t))]
    = [aPl U P D 16384 5 t - aPl U P D 0 5 t * aPl U P D 0 5 t,
       aPl U P D 0 5 t - (aPl U P D 98304 5 t + 2 ^ 8 * aPl U P D 98336 5 t + 2 ^ 16 * aPl U P D 98368 5 t),
       2 * aPl U P D 0 5 t - (aPl U P D 98400 5 t + 2 ^ 8 * aPl U P D 98432 5 t + 2 ^ 16 * aPl U P D 98464 5 t)
         - (aPl U P D 98496 5 t + 2 ^ 8 * aPl U P D 98528 5 t + 2 ^ 16 * aPl U P D 98560 5 t),
       aPl U P D 49152 5 t - aPl U P D 32768 5 t * aPl U P D 32768 5 t,
       aPl U P D 32768 5 t - (aPl U P D 114688 5 t + 2 ^ 8 * aPl U P D 114720 5 t + 2 ^ 16 * aPl U P D 114752 5 t),
       2 * aPl U P D 32768 5 t - (aPl U P D 114784 5 t + 2 ^ 8 * aPl U P D 114816 5 t + 2 ^ 16 * aPl U P D 114848 5 t)
         - (aPl U P D 114880 5 t + 2 ^ 8 * aPl U P D 114912 5 t + 2 ^ 16 * aPl U P D 114944 5 t)] := by
  simp only [relCl, map_sub, map_mul, map_add, map_pow, map_ofNat]
  simp only [xtW, alg_plT U P D hX, alg_plL U P D hX]
  norm_num

/-- **`SC_TZC`'s hosted relations, embedded**, at a layout whose token axis does not pad (the gate `gT` is `1`). -/
theorem relGh2_alg (hTok : Function.Surjective Lay.tok.emb) (hc : S.ceps = 1) (t : CtW) :
    [algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 0 (.t t)), algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 1 (.t t))]
    = [aPl U P D 16384 5 t + (aPl U P D 98400 5 t + 2 ^ 8 * aPl U P D 98432 5 t + 2 ^ 16 * aPl U P D 98464 5 t) - 1,
       aPl U P D 49152 5 t + (aPl U P D 114784 5 t + 2 ^ 8 * aPl U P D 114816 5 t + 2 ^ 16 * aPl U P D 114848 5 t)
         - 1] := by
  obtain ⟨t0, ht0⟩ := hTok t
  have hg : B.gT t = 1 := by rw [← ht0]; exact B.gT_one t0
  simp only [relGh, hg, hc, one_mul, map_sub, map_add, map_mul, map_pow, map_ofNat, Int.cast_one, map_one]
  simp only [xtW, alg_plT U P D hX, alg_plL U P D hX]
  norm_num

end Rels

/-! ## `SC_TZC`'s IR on the cube -/

section Ir

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

/-- **`SC_TZC`'s IR read in the field**: L13's host terms with the six clauses and the two hosted terms. -/
theorem tzc_irEval (hist : Hist) (dr : List Fp2) (v : List K) :
    irEval (((tzcIr DefW16.cstS rrTzc 1 muTzc nuTzc (fun j => Sym.pow Sym.zero j) []).map
        (Sym.eval hist 2 dr)).map (Fp2.toK U)) v
      = hostTerms v 0 1 2 none none ((nuTzc.map (Sym.eval hist 2 dr)).map (Fp2.toK U))
          (batchV ((muTzc.map (Sym.eval hist 2 dr)).map (Fp2.toK U)) (tzcClauses (cstK U) rrTzc v))
          (v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-1))
          (v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-1)) := by
  rw [tzcIr_map, tzcIr_map, cstS_map, tzcIr_eval _ (cstW_map_std U)]
  simp only [padSem, add_zero]
  rfl

/-- The clauses' constants. -/
theorem cstK_tzc : (cstK U).base 2 = 2 ∧ (cstK U).base (-1) = -1 ∧ (cstK U).p256 0 = 1 ∧ (cstK U).p256 1 = 256
    ∧ (cstK U).p256 2 = 65536 := by
  refine ⟨?_, ?_, ?_, ?_, ?_⟩
  · rw [cstK_base U 2 (by norm_num) (by norm_num)]
    simp only [Int.cast_ofNat, map_ofNat]
  · rw [cstK_base U (-1) (by norm_num) (by norm_num)]
    norm_num
  · rw [cstK_p256 U 0 (by norm_num)]
    norm_num
  · rw [cstK_p256 U 1 (by norm_num)]
    norm_num
  · rw [cstK_p256 U 2 (by norm_num)]
    norm_num

end Ir

/-! ## `SC_TZC`'s cube sum -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

/-- The value list of `SC_TZC` at a point. -/
noncomputable def valsTzc (n e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (x : Fin (n + e) → K) : List K :=
  (tabs2.map (TabS.eval ev pub)).map (tabK U P D n e x)

/-- Off the zero extension the three `eq` entries are `0`. -/
theorem valsTzc_off (n e : ℕ) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (b : Fin n → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) :
    (valsTzc U P D n e ev pub (bpt n e b y)).getD 0 0 = 0 ∧ (valsTzc U P D n e ev pub (bpt n e b y)).getD 1 0 = 0
      ∧ (valsTzc U P D n e ev pub (bpt n e b y)).getD 2 0 = 0 := by
  simp only [valsTzc, tabs2, List.map_cons, eqT_eval, List.getD_cons_zero, List.getD_cons_succ]
  exact ⟨tabK_eq_off U P D n e b y hy _ _, tabK_eq_off U P D n e b y hy _ _, tabK_eq_off U P D n e b y hy _ _⟩

include hX hrl in
/-- **`SC_TZC`'s cube sum**, at `n = 5` main variables: `Σ_t hostPoly(τ, Σ_j μ_j·relCl 2 j, ν, P, 1, relGh 2)(t)`. -/
theorem tzc_cube (hTok : Function.Surjective Lay.tok.emb) (hc : S.ceps = 1) (n e : ℕ) (hn : n = 5) (hist : Hist)
    (dr : List Fp2) (pub : ℕ → List Fp2) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((tzcIr DefW16.cstS rrTzc 1 muTzc nuTzc (fun j => Sym.pow Sym.zero j) []).map
        (Sym.eval hist 2 dr)).map (Fp2.toK U)) (valsTzc U P D n e (Sym.eval hist 2 dr) pub x)) :
    cubeSum f = ∑ t : CtW, hostPoly (fun a : Fin 5 => (((dr5 2).map (Sym.eval hist 2 dr)).getD a Fp2.zero).toK U)
      (fun t => ∑ j : Fin 6, (((muTzc.map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD j 0)
        * algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 (j : ℕ) (.t t)))
      ![(((nuTzc.map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 0 0),
        (((nuTzc.map (Sym.eval hist 2 dr)).map (Fp2.toK U)).getD 1 0)]
      ![fun a : Fin 5 => (((dr5 0).map (Sym.eval hist 2 dr)).getD a Fp2.zero).toK U,
        fun a : Fin 5 => (((dr5 1).map (Sym.eval hist 2 dr)).getD a Fp2.zero).toK U]
      (fun _ => 1) (fun i t => algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 i (.t t))) t := by
  subst hn
  set ev := Sym.eval hist 2 dr with hev
  rw [cubeSum_host 5 e (valsTzc U P D 5 e ev pub) 0 1 2 none none ((nuTzc.map ev).map (Fp2.toK U))
    (fun v => batchV ((muTzc.map ev).map (Fp2.toK U)) (tzcClauses (cstK U) rrTzc v))
    (fun v => v.getD 4 0 + L256 (cstK U) v [8, 9, 10] + (cstK U).base (-1))
    (fun v => v.getD 15 0 + L256 (cstK U) v [19, 20, 21] + (cstK U).base (-1)) f
    (fun x => by rw [hf x, tzc_irEval U hist dr])
    (fun b y hy => valsTzc_off U P D 5 e ev pub b y hy)
    (fun a : Fin 5 => (((dr5 2).map ev).getD a Fp2.zero).toK U)
    ![fun a : Fin 5 => (((dr5 0).map ev).getD a Fp2.zero).toK U,
      fun a : Fin 5 => (((dr5 1).map ev).getD a Fp2.zero).toK U]
    (fun b => by rw [valsTzc, tzc_vals U P D hrl 5 e rfl b ev pub]; rfl)
    (fun b => by rw [valsTzc, tzc_vals U P D hrl 5 e rfl b ev pub]; rfl)
    (fun b => by rw [valsTzc, tzc_vals U P D hrl 5 e rfl b ev pub]; rfl)]
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have hv : valsTzc U P D 5 e ev pub (cpt 5 e t) = _ := tzc_vals U P D hrl 5 e rfl t ev pub
  have hcl := relCl2_alg U P D hX Pb Lay B t
  have hgh := relGh2_alg U P D hX Pb Lay B hTok hc t
  simp only [List.cons.injEq, and_true] at hcl hgh
  obtain ⟨h0, h1, h2, h3, h4, h5⟩ := hcl
  obtain ⟨g0, g1⟩ := hgh
  obtain ⟨c2, cm1, c0, c1, c2'⟩ := cstK_tzc U
  refine hostPoly_congr _ _ _ _ _ _ _ _ t ?_ ?_
  · -- the batched clauses
    show batchV ((muTzc.map ev).map (Fp2.toK U)) (tzcClauses (cstK U) rrTzc (valsTzc U P D 5 e ev pub (cpt 5 e t)))
      = ∑ j : Fin 6, (((muTzc.map ev).map (Fp2.toK U)).getD j 0)
        * algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 (j : ℕ) (.t t))
    rw [hv, Fin.sum_univ_eq_sum_range (fun j => (((muTzc.map ev).map (Fp2.toK U)).getD j 0)
      * algebraMap GF K (relCl Pb Lay B (xtW U P D) 2 j (.t t))) 6]
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    rw [h0, h1, h2, h3, h4, h5]
    simp only [batchV, tzcClauses, rrTzc, L256, List.zipIdx_cons, List.zipIdx_nil, List.map_cons, List.map_nil,
      List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ, castB_rfl, c2, c0, c1, c2']
    ring
  · -- the hosted terms
    intro i
    fin_cases i
    · show gV (valsTzc U P D 5 e ev pub (cpt 5 e t)) none
          * ((valsTzc U P D 5 e ev pub (cpt 5 e t)).getD 4 0
            + L256 (cstK U) (valsTzc U P D 5 e ev pub (cpt 5 e t)) [8, 9, 10] + (cstK U).base (-1))
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 0 (.t t))
      rw [hv, g0]
      simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul, L256, List.zipIdx_cons,
        List.zipIdx_nil, List.map_cons, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ,
        castB_rfl, c0, c1, c2', cm1]
      ring
    · show gV (valsTzc U P D 5 e ev pub (cpt 5 e t)) none
          * ((valsTzc U P D 5 e ev pub (cpt 5 e t)).getD 15 0
            + L256 (cstK U) (valsTzc U P D 5 e ev pub (cpt 5 e t)) [19, 20, 21] + (cstK U).base (-1))
        = algebraMap GF K (relGh Pb Lay B (xtW U P D) 2 1 (.t t))
      rw [hv, g1]
      simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul, L256, List.zipIdx_cons,
        List.zipIdx_nil, List.map_cons, List.sum_cons, List.sum_nil, List.getD_cons_zero, List.getD_cons_succ,
        castB_rfl, c0, c1, c2', cm1]
      ring

end Cube

/-! ## `SC_SS` and `SC_SSM`: the hosted row sums of squares -/

/-- The bit vectors of `Dom::D`, split into the token and the width bits. -/
theorem sum_append_D {M : Type} [AddCommMonoid M] (F : (Fin 14 → Bool) → M) :
    ∑ b : Fin 14 → Bool, F b = ∑ t : CtW, ∑ c : CwW, F (Fin.append t c) := by
  rw [← Fintype.sum_prod_type']
  exact (Fintype.sum_equiv (Fin.appendEquiv 5 9) (fun p => F (Fin.append p.1 p.2)) F (fun _ => rfl)).symm

theorem append_head5 (t : CtW) (c : CwW) (a : Fin 5) :
    Fin.append t c (⟨(a : ℕ), by omega⟩ : Fin 14) = t a := by
  have : (⟨(a : ℕ), by omega⟩ : Fin 14) = Fin.castAdd 9 a := rfl
  rw [this, Fin.append_left]

section Ss

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)
  (hX : ∀ i t, D.X .a i t ∈ baseR K) (hrl : 0 < rowLog P .a)
variable {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S) (Lay : W16Layout S CtW CwW CgW CjW CdW CfW)
  (B : W16Pub S Pb Lay)

include hX hrl in
/-- **`SC_SS`'s (`SC_SSM`'s) unmasked cube sum** (`n = 14`): the multilinear extension, at the slot's point `r_t`, of
the gated row sums of squares `Σ_c gD(t, c)·X(t, c)²` of its plane. -/
theorem ss_cube (hist : Hist) (s off m : ℕ) (dr : List Fp2) (pub : ℕ → List Fp2)
    (hgD : ∀ (t : CtW) (c : CwW), ((pub 0).getD (msbIndex 14 (Fin.append t c)) Fp2.zero).toK U
      = algebraMap GF K (B.gD (t, c)))
    (n e : ℕ) (hn : n = 14) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((ssIr DefW16.cstS 0 1 (some 2)).map (Sym.eval hist s dr)).map (Fp2.toK U))
      (([TabS.eq (dr5 s) 0, paT off 14 m, .pub 0].map (TabS.eval (Sym.eval hist s dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = mleAt (fun t : CtW => algebraMap GF K (∑ c : CwW, B.gD (t, c) * plD U P D off (t, c)
        * plD U P D off (t, c)))
      (fun a : Fin 5 => (((dr5 s).map (Sym.eval hist s dr)).getD a Fp2.zero).toK U) := by
  subst hn
  set ev := Sym.eval hist s dr with hev
  have hir : ∀ v : List K, irEval (((ssIr DefW16.cstS 0 1 (some 2)).map ev).map (Fp2.toK U)) v
      = v.getD 2 0 * (v.getD 0 0 * (v.getD 1 0 * v.getD 1 0)) := by
    intro v
    rw [ssIr_map, ssIr_map, cstS_map, ssIr_eval _ (cstW_map_std U), gV_some]
  have hlen : ((dr5 s).map ev).length = 5 := rfl
  rw [cubeSum_split]
  have hrow : ∀ b : Fin 14 → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = ((pub 0).getD (msbIndex 14 b) Fp2.zero).toK U
        * (eqPoly (fun a : Fin 5 => (((dr5 s).map ev).getD a Fp2.zero).toK U) (fun a => bit (b ⟨a, by omega⟩))
          * (aPl U P D off 14 b * aPl U P D off 14 b)) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt 14 e b) = _
      rw [hf, hir]
      simp only [List.map_cons, List.map_nil, eqT_eval, pubT_eval, paT_eval, List.getD_cons_zero,
        List.getD_cons_succ]
      rw [tabK_pub_cpt, tabK_eqHead_cpt U P D 14 e b _ 5 hlen (by norm_num),
        tabK_pa_cpt U P D hrl 14 e b 14 (by norm_num) rfl, castB_rfl]
    · show f (bpt 14 e b y) = 0
      rw [hf, hir]
      simp only [List.map_cons, List.map_nil, eqT_eval, List.getD_cons_zero]
      rw [tabK_eq_off U P D 14 e b y hy, zero_mul, mul_zero]
  simp only [hrow]
  rw [sum_append_D]
  unfold mleAt
  refine Finset.sum_congr rfl (fun t _ => ?_)
  simp only [map_sum, Finset.mul_sum]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [hgD t c]
  have he : (fun a : Fin 5 => (bit (Fin.append t c ⟨(a : ℕ), by omega⟩) : K)) = fun a => bit (t a) := by
    funext a
    rw [append_head5]
  rw [he]
  have hx : algebraMap GF K (plD U P D off (t, c)) = aPl U P D off 14 (Fin.append t c) := alg_plD U P D hX off (t, c)
  simp only [map_mul]
  rw [hx]
  ring

end Ss

end ZK60.Exec.Block.Join.W16
