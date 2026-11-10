/-
D63 lane L44 (2026-11-10), part 1: **the shared tools for the five remaining hosts of the W16R2 rung** (`SC_DZC`,
`SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`), after lane L41's `SC_TZC` (`BlockJoinTzc*.lean`).

* `LayW16`: the layout facts the hosts read (public data): the token, head-dimension, head-slot and group axes do not
  pad, and the RoPE flip is the head dimension's top bit (`Coord::Flip` at the first head-dimension variable);
  **`gQ_one`**, **`gK_one`**, **`gS_one`**, **`gHt_one`**: the gates of the cubes that do not pad are `1` everywhere;
* `splitHQ`, `splitGD`: the head-slot-then-dimension and group-then-dimension axes of a bit vector;
* `PubW16`: **the verifier's public tables, as the block's public data** (the support gates, the norms' `γ`, RoPE's
  `cos` / `sin`, the causal mask, the activation's group column, and the seven matmuls' folded weights, each the fold
  of the public weights by `eq(r_out, ·)`), one field per table; item 2 of the lane defines the tables and proves
  them;
* `hPl`: an `H` plane (`re + u·im`) read at a bit vector; `tabK_ph_cpt`: an `H` table at the zero extension;
* `tabK_fx_cpt`: an `A` table whose first coordinates are fixed values and the rest the slot's variables, at the
  zero extension: `Σ_z eq(r, z)·plane(z ++ b)`;
* **`mm_cube`**: a hosted matmul slot's cube sum: `Σ_c (Σ_z eq(r, z)·A(z ++ c))·W(c)`;
* **`mm_fold`**: with the folded weight `W(c) = Σ_j eq(s, j)·W(c, j)` it is the multilinear extension of the
  contraction at `(r, s)`;
* **`formAt_two`**: lane L36's `FormAt` of a host with two hosted slots from the program's hosted list and the
  host's cube identity (generic in the program).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockJoinFinal
import ZK60Formal.BlockJoinBatch

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16

open ZK60.Sound
open ZK60.Sound.SlotW16 (hostPoly hostPhi batched SlotPoly segAt mle2 matmul_sum mleAt_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.DefW16
open ZK60.Circuit (gP GF)
open ZK60.Layout
open Finset

/-! ## The layout facts -/

/-- `Dom::Q`'s head slot and head dimension (`(g ++ j) ++ c`, `10` bits). -/
def splitHQ (c : Fin 10 → Bool) : (CgW × CjW) × CdW :=
  ((fun i => c (Fin.castAdd 6 (Fin.castAdd 1 i)), fun i => c (Fin.castAdd 6 (Fin.natAdd 3 i))),
    fun i => c (Fin.natAdd 4 i))

/-- `Dom::Kv`'s group and head dimension (`g ++ c`, `9` bits). -/
def splitGD (c : Fin 9 → Bool) : CgW × CdW := (fun i => c (Fin.castAdd 6 i), fun i => c (Fin.natAdd 3 i))

theorem splitHQ_append (x : (CgW × CjW) × CdW) : splitHQ (Fin.append (Fin.append x.1.1 x.1.2) x.2) = x := by
  obtain ⟨⟨g, j⟩, c⟩ := x
  simp only [splitHQ, Fin.append_left, Fin.append_right]

theorem splitGD_append (x : CgW × CdW) : splitGD (Fin.append x.1 x.2) = x := by
  obtain ⟨g, c⟩ := x
  simp only [splitGD, Fin.append_left, Fin.append_right]

theorem append_splitHQ (c : Fin 10 → Bool) : Fin.append (Fin.append (splitHQ c).1.1 (splitHQ c).1.2) (splitHQ c).2 = c := by
  funext i
  refine Fin.addCases (fun i4 => ?_) (fun i6 => ?_) i
  · rw [Fin.append_left]
    refine Fin.addCases (fun i3 => ?_) (fun i1 => ?_) i4
    · rw [Fin.append_left]; rfl
    · rw [Fin.append_right]; rfl
  · rw [Fin.append_right]; rfl

theorem append_splitGD (c : Fin 9 → Bool) : Fin.append (splitGD c).1 (splitGD c).2 = c := by
  funext i
  refine Fin.addCases (fun i3 => ?_) (fun i6 => ?_) i
  · rw [Fin.append_left]; rfl
  · rw [Fin.append_right]; rfl

/-- **A sum over the bit vectors of `a + b` coordinates as a double sum** (most significant block first). -/
theorem sum_append {M : Type} [AddCommMonoid M] {a b : ℕ} (F : (Fin (a + b) → Bool) → M) :
    ∑ x : Fin (a + b) → Bool, F x = ∑ t : Fin a → Bool, ∑ c : Fin b → Bool, F (Fin.append t c) := by
  rw [← Fintype.sum_prod_type']
  exact (Fintype.sum_equiv (Fin.appendEquiv a b) (fun p => F (Fin.append p.1 p.2)) F (fun _ => rfl)).symm

/-- The head-slot-and-dimension bits as the product. -/
def eHQ : (Fin 10 → Bool) ≃ (CgW × CjW) × CdW :=
  ⟨splitHQ, fun x => Fin.append (Fin.append x.1.1 x.1.2) x.2, append_splitHQ, splitHQ_append⟩

/-- The group-and-dimension bits as the product. -/
def eGD : (Fin 9 → Bool) ≃ CgW × CdW := ⟨splitGD, fun x => Fin.append x.1 x.2, append_splitGD, splitGD_append⟩

/-- `Dom::Q`'s head-slot-and-dimension sum as a sum over `10` bits. -/
theorem sum_HQ {M : Type} [AddCommMonoid M] (F : (CgW × CjW) × CdW → M) :
    ∑ x, F x = ∑ c : Fin 10 → Bool, F (splitHQ c) :=
  (Fintype.sum_equiv eHQ (fun c => F (splitHQ c)) F (fun _ => rfl)).symm

/-- `Dom::Kv`'s group-and-dimension sum as a sum over `9` bits. -/
theorem sum_GD {M : Type} [AddCommMonoid M] (F : CgW × CdW → M) :
    ∑ x, F x = ∑ c : Fin 9 → Bool, F (splitGD c) :=
  (Fintype.sum_equiv eGD (fun c => F (splitGD c)) F (fun _ => rfl)).symm

/-- **The layout facts the hosts read** (public data of the rung's layout). -/
structure LayW16 {S : ZK60.Block.BlockShape} (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) : Prop where
  tok : Function.Surjective Lay.tok.emb
  hd : Function.Surjective Lay.hd.emb
  slot : Function.Surjective Lay.slot
  grp : Function.Surjective Lay.grp.emb
  /-- the RoPE flip of the head dimension is its top bit (`Coord::Flip` at the head dimension's first variable) -/
  flip : ∀ c : CdW, Lay.flip c = Function.update c 0 (!c 0)

section Gates

variable {S : ZK60.Block.BlockShape} {Pb : ZK60.Block.BlockPublic S} {Lay : W16Layout S CtW CwW CgW CjW CdW CfW}
  (B : W16Pub S Pb Lay) (hL : LayW16 Lay)

include hL

/-- `Dom::Q` does not pad: its gate is `1`. -/
theorem gQ_one (x : CtW × ((CgW × CjW) × CdW)) : B.gQ x = 1 := by
  obtain ⟨t, h, c⟩ := x
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨c0, rfl⟩ := hL.hd c
  exact B.gQ_one (t0, (h0, c0))

/-- `Dom::Kv` does not pad. -/
theorem gK_one (x : CtW × (CgW × CdW)) : B.gK x = 1 := by
  obtain ⟨t, g, c⟩ := x
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨g0, rfl⟩ := hL.grp g
  obtain ⟨c0, rfl⟩ := hL.hd c
  exact B.gK_one (t0, (g0, c0))

/-- `Dom::S` does not pad. -/
theorem gS_one (x : (CgW × CjW) × CtW × CtW) : B.gS x = 1 := by
  obtain ⟨h, t, j⟩ := x
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨t0, rfl⟩ := hL.tok t
  obtain ⟨j0, rfl⟩ := hL.tok j
  exact B.gS_one (h0, t0, j0)

/-- `Dom::Ht` does not pad. -/
theorem gHt_one (x : (CgW × CjW) × CtW) : B.gHt x = 1 := by
  obtain ⟨h, t⟩ := x
  obtain ⟨h0, rfl⟩ := hL.slot h
  obtain ⟨t0, rfl⟩ := hL.tok t
  exact B.gHt_one (h0, t0)

/-- `Dom::T` does not pad. -/
theorem gT_one' (t : CtW) : B.gT t = 1 := by
  obtain ⟨t0, rfl⟩ := hL.tok t
  exact B.gT_one t0

end Gates

/-! ## The public tables -/

section Pub

variable {K : Type} [Field K] [Algebra GF K]

/-- `eq` of a slot's draws `off … off + n − 1` and a bit vector. -/
noncomputable def eqDr (U : K) (dr : List Fp2) (off n : ℕ) (y : Fin n → Bool) : K :=
  eqPoly (fun a : Fin n => (dr.getD (off + a) Fp2.zero).toK U) (fun a => bit (y a))

/-- **The verifier's public tables at the W16R2 rung, as the block's public data.** Table `i` of slot `s`, read at the
slot's cube point `b` (`msbIndex`), is the public value there: the support gates, the norms' `γ`, RoPE's `cos` and
`sin`, the causal mask, the activation's group column; for the seven matmuls the weights folded by `eq` of the
slot's output draws (`fold_rows_i8`, `W̃(c) = Σ_j eq(r_out, j)·W(c, j)`). A field per table the hosts read. -/
structure PubW16 (U : K) (pubs : PubTabs) {S : ZK60.Block.BlockShape} (Pb : ZK60.Block.BlockPublic S)
    (Lay : W16Layout S CtW CwW CgW CjW CdW CfW) (B : W16Pub S Pb Lay) : Prop where
  /-- `SC_SS`, `SC_SSM`: `supp(D)` -/
  ssGate : ∀ s, s = 0 ∨ s = 1 → ∀ hist dr (t : CtW) (c : CwW),
    ((pubs s hist dr 0).getD (msbIndex 14 (Fin.append t c)) Fp2.zero).toK U = algebraMap GF K (B.gD (t, c))
  /-- `SC_RS`: the causal mask on `Dom::S` -/
  rsMask : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 4 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS b))
  /-- `SC_QMM`: `W_q` folded by `eq(r_j)` (draws `5 … 14`) -/
  wq : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 9 → Bool, ((pubs 5 hist dr 0).getD (msbIndex 9 c) Fp2.zero).toK U
    = ∑ y : Fin 10 → Bool, eqDr U dr 5 10 y * algebraMap GF K (B.Wq c (splitHQ y))
  /-- `SC_KMM`: `W_k` folded by `eq(r_j)` (draws `0 … 8`) -/
  wk : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 9 → Bool, ((pubs 6 hist dr 0).getD (msbIndex 9 c) Fp2.zero).toK U
    = ∑ y : Fin 9 → Bool, eqDr U dr 0 9 y * algebraMap GF K (B.Wk c (splitGD y))
  /-- `SC_VMM`: `W_v` folded by `eq(r_j)` (draws `0 … 8`) -/
  wv : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 9 → Bool, ((pubs 7 hist dr 0).getD (msbIndex 9 c) Fp2.zero).toK U
    = ∑ y : Fin 9 → Bool, eqDr U dr 0 9 y * algebraMap GF K (B.Wv c (splitGD y))
  /-- `SC_WO`: `W_o` folded by `eq(r_j)` (draws `5 … 13`) -/
  wo : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 10 → Bool, ((pubs 10 hist dr 0).getD (msbIndex 10 c) Fp2.zero).toK U
    = ∑ y : Fin 9 → Bool, eqDr U dr 5 9 y * algebraMap GF K (B.Wo (splitHQ c) y)
  /-- `SC_GMM`: `W_g` folded by `eq(r_j)` (draws `5 … 14`) -/
  wg : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 9 → Bool, ((pubs 11 hist dr 0).getD (msbIndex 9 c) Fp2.zero).toK U
    = ∑ y : Fin 10 → Bool, eqDr U dr 5 10 y * algebraMap GF K (B.Wg c y)
  /-- `SC_UMM`: `W_u` folded by `eq(r_j)` (draws `0 … 9`) -/
  wu : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 9 → Bool, ((pubs 12 hist dr 0).getD (msbIndex 9 c) Fp2.zero).toK U
    = ∑ y : Fin 10 → Bool, eqDr U dr 0 10 y * algebraMap GF K (B.Wu c y)
  /-- `SC_DMM`: `W_d` folded by `eq(r_j)` (draws `5 … 13`) -/
  wd : ∀ hist dr, (∀ x ∈ dr, x.Canon) → ∀ c : Fin 10 → Bool, ((pubs 13 hist dr 0).getD (msbIndex 10 c) Fp2.zero).toK U
    = ∑ y : Fin 9 → Bool, eqDr U dr 5 9 y * algebraMap GF K (B.Wd c y)
  /-- `SC_DZC`: `γ_a`, `γ_m`, `supp(D)` -/
  dzcGamA : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 14 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamA (splitD b))
  dzcGamM : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 14 hist dr 1).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gamM (splitD b))
  dzcGate : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 14 hist dr 2).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.gD (splitD b))
  /-- `SC_QZC`: RoPE's `cos`, signed `sin` on `Dom::Q` -/
  qzcCos : ∀ hist dr (b : Fin 15 → Bool),
    ((pubs 15 hist dr 0).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.cosT (splitQ b))
  qzcSin : ∀ hist dr (b : Fin 15 → Bool),
    ((pubs 15 hist dr 1).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.sinT (splitQ b))
  /-- `SC_KVZC`: RoPE's `cos`, signed `sin` on `Dom::Kv` -/
  kvCos : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 16 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.cosK (splitK b))
  kvSin : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 16 hist dr 1).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.sinK (splitK b))
  /-- `SC_SZC`: the causal mask on `Dom::S` -/
  szcMask : ∀ hist dr (b : Fin 14 → Bool),
    ((pubs 17 hist dr 0).getD (msbIndex 14 b) Fp2.zero).toK U = algebraMap GF K (B.mask (splitS b))
  /-- `SC_FZC`: the activation's group column, `supp(F)` -/
  fzcGrp : ∀ hist dr (b : Fin 15 → Bool),
    ((pubs 18 hist dr 0).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.grpCol (splitF b))
  fzcGate : ∀ hist dr (b : Fin 15 → Bool),
    ((pubs 18 hist dr 1).getD (msbIndex 15 b) Fp2.zero).toK U = algebraMap GF K (B.gF (splitF b))

end Pub

/-! ## Private tables at the zero extension -/

section Tabs

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **An `H` plane** (`re + u·im`, the real half at `re`, the imaginary half at `im`), read at a bit vector. -/
noncomputable def hPl (P : BlockParams) (D : CmData K P) (re im log : ℕ) (b : Fin log → Bool) : K :=
  planeZ U (rowLog P .h) (D.rows .h) (D.Q .h) (D.X .h) ⟨.h, [(re, Fp2.one), (im, fp2U)], log, [], 0, 0⟩ b

/-- `TabS.eval` of an `H` table on its own coordinates. -/
theorem hTab_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (re im log m : ℕ) :
    TabS.eval ev pub (.priv ⟨.h, [(re, false), (im, true)], log, DefW16.rhoC 0 log, m, 0⟩)
      = .priv ⟨.h, [(re, Fp2.one), (im, fp2U)], log, rhoAll log, m, 0⟩ := by
  show Tab.priv ⟨.h, [(re, if false then fp2U else Fp2.one), (im, if true then fp2U else Fp2.one)], log,
    (DefW16.rhoC 0 log).map (CoordS.eval ev), m, 0⟩ = _
  rw [rhoC_eval, Nat.sub_zero, ← rhoAll_eq]
  rfl

/-- **An `H` table on its own first `L = n` coordinates, at the zero extension.** -/
theorem tabK_ph_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .h) (n e : ℕ) (b : Fin n → Bool) (L : ℕ)
    (hL : 0 < L) (hn : n = L) (re im m : ℕ) :
    tabK U P D n e (cpt n e b) (.priv ⟨.h, [(re, Fp2.one), (im, fp2U)], L, rhoAll L, m, 0⟩)
      = hPl U P D re im L (castB hn b) := by
  rw [tabK_rho_cpt U P D n e b _ (by simp) hL hrl rfl (by show L ≤ n; omega)]
  rfl

/-- `TabS.eval` of an `A` table whose first coordinates are fixed draws and the rest the slot's variables. -/
theorem aFx_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (off log : ℕ) (rr : List Sym) (m mrow ext : ℕ) :
    TabS.eval ev pub (.priv ⟨.a, [(off, false)], log, rr.map CoordS.fixed ++ DefW16.rhoC 0 m, mrow, ext⟩)
      = .priv ⟨.a, [(off, Fp2.one)], log, (rr.map ev).map Coord.fixed ++ rhoAll m, mrow, ext⟩ := by
  show Tab.priv ⟨.a, [(off, if false then fp2U else Fp2.one)], log,
    (rr.map CoordS.fixed ++ DefW16.rhoC 0 m).map (CoordS.eval ev), mrow, ext⟩ = _
  rw [List.map_append, rhoC_eval, Nat.sub_zero, ← rhoAll_eq, List.map_map, List.map_map]
  rfl

/-- The claim point of fixed values then the slot's variables. -/
theorem ptK_fx (xr : ℕ → K) (vs : List Fp2) (m i : ℕ) :
    ptK U xr (vs.map Coord.fixed ++ rhoAll m) i
      = if i < vs.length then (vs.getD i Fp2.zero).toK U else if i < vs.length + m then xr (i - vs.length) else 0 := by
  unfold ptK
  by_cases h1 : i < vs.length
  · rw [ite_eq_left h1, List.getElem?_append_left (by rw [List.length_map]; exact h1), List.getElem?_map,
      List.getD_eq_getElem?_getD, List.getElem?_eq_getElem h1]
    rfl
  · rw [ite_eq_right h1, List.getElem?_append_right (by rw [List.length_map]; omega), List.length_map]
    unfold rhoAll
    rw [List.getElem?_map]
    by_cases h2 : i < vs.length + m
    · rw [ite_eq_left h2, List.getElem?_range (by omega)]
      rfl
    · rw [ite_eq_right h2, List.getElem?_eq_none (by rw [List.length_range]; omega)]
      rfl

omit [Algebra GF K] in
/-- A point made of `a` values then `m` bits is `Fin.append` of the two. -/
theorem pt_append {a m : ℕ} (r : Fin a → K) (c : Fin m → Bool) (f : Fin (a + m) → K)
    (hf : ∀ i : Fin (a + m), f i = if h : (i : ℕ) < a then r ⟨i, h⟩ else bit (c ⟨i - a, by omega⟩)) :
    f = Fin.append r (fun i => bit (c i)) := by
  funext i
  rw [hf]
  refine Fin.addCases (fun j => ?_) (fun j => ?_) i
  · rw [Fin.append_left, dite_eq_left (by simp)]
    rfl
  · rw [Fin.append_right, dite_eq_right (by simp)]
    congr 2
    ext
    simp

omit [Algebra GF K] in
/-- **The multilinear extension at `a` values then `m` bits** is the partial extension in the first block. -/
theorem mleAt_append_bits {a m : ℕ} (f : (Fin (a + m) → Bool) → K) (r : Fin a → K) (c : Fin m → Bool) :
    mleAt f (Fin.append r (fun i => bit (c i)))
      = ∑ z : Fin a → Bool, eqPoly r (fun i => bit (z i)) * f (Fin.append z c) := by
  classical
  rw [mleAt_append]
  unfold mle2
  refine Finset.sum_congr rfl (fun z _ => ?_)
  rw [Fintype.sum_eq_single c (fun j hj => by rw [eqPoly_bit, ite_eq_right (Ne.symm hj)]; ring)]
  rw [eqPoly_bit, ite_eq_left rfl, mul_one]

/-- **An `A` table on fixed values then the slot's `m = n` variables, at the zero extension**: the partial extension
`Σ_z eq(r, z)·plane(z ++ b)` of its plane. -/
theorem tabK_fx_cpt (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (b : Fin n → Bool)
    (vs : List Fp2) (a m : ℕ) (hva : vs.length = a) (hn : n = m) (hlog : 0 < a + m) (off mrow ext : ℕ) :
    tabK U P D n e (cpt n e b) (.priv ⟨.a, [(off, Fp2.one)], a + m, vs.map Coord.fixed ++ rhoAll m, mrow, ext⟩)
      = ∑ z : Fin a → Bool, eqPoly (fun i : Fin a => (vs.getD i Fp2.zero).toK U) (fun i => bit (z i))
          * aPl U P D off (a + m) (Fin.append z (castB hn b)) := by
  subst hn
  rw [tabK_priv_cpt U P D n e b _ (by simp) hlog hrl]
  have hpt : (fun i : Fin (a + n) => ptK U (xrK n (cpt (K := K) n e b))
      (vs.map Coord.fixed ++ rhoAll n) i)
      = Fin.append (fun i : Fin a => (vs.getD i Fp2.zero).toK U) (fun i => bit (b i)) := by
    refine pt_append _ b _ (fun i => ?_)
    rw [ptK_fx, hva]
    by_cases h : (i : ℕ) < a
    · rw [ite_eq_left h, dite_eq_left h]
    · rw [ite_eq_right h, dite_eq_right h, ite_eq_left (by omega), xrK_cpt, dite_eq_left (by omega)]
  show mleAt (planeZ U (rowLog P .a) (D.rows .a) (D.Q .a) (D.X .a)
      ⟨.a, [(off, Fp2.one)], a + n, vs.map Coord.fixed ++ rhoAll n, mrow, ext⟩)
      (fun i : Fin (a + n) => ptK U (xrK n (cpt (K := K) n e b)) (vs.map Coord.fixed ++ rhoAll n) i) = _
  rw [hpt, mleAt_append_bits]
  rfl

end Tabs

/-! ## The hosted matmuls -/

section Mm

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A hosted matmul slot's cube sum** (`plane·folded weight`, `mmIr`): its `A` table reads the plane with the first
`a` coordinates fixed at `r`; its public table is the folded weight. Off the zero extension the public table is `0`. -/
theorem mm_cube (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (n e : ℕ) (vs : List Fp2) (a m : ℕ)
    (hva : vs.length = a) (hn : n = m) (hlog : 0 < a + m) (off mrow : ℕ) (pv : List Fp2)
    (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = tabK U P D n e x (.priv ⟨.a, [(off, Fp2.one)], a + m, vs.map Coord.fixed ++ rhoAll m, mrow, 0⟩)
      * tabK U P D n e x (.pub pv)) :
    cubeSum f = ∑ c : Fin m → Bool, (∑ z : Fin a → Bool,
        eqPoly (fun i : Fin a => (vs.getD i Fp2.zero).toK U) (fun i => bit (z i)) * aPl U P D off (a + m) (Fin.append z c))
      * (pv.getD (msbIndex m c) Fp2.zero).toK U := by
  subst hn
  rw [cubeSum_split]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt n e c) = _
    rw [hf, tabK_fx_cpt U P D hrl n e c vs a n hva rfl hlog, tabK_pub_cpt]
    rfl
  · show f (bpt n e c y) = 0
    rw [hf, tabK_pub_off U P D n e c y hy, mul_zero]

omit [Algebra GF K] in
/-- **The folded matmul is the extension of the contraction** at `(r, s)` (L23's `matmul_sum`). -/
theorem mm_fold {a b m : ℕ} (A : (Fin a → Bool) → (Fin m → Bool) → K) (W : (Fin m → Bool) → (Fin b → Bool) → K)
    (r : Fin a → K) (s : Fin b → K) :
    ∑ c, (∑ z, eqPoly r (fun i => bit (z i)) * A z c) * (∑ j, eqPoly s (fun i => bit (j i)) * W c j)
      = mleAt (fun y : Fin (a + b) → Bool =>
          ∑ c, A (fun i => y (Fin.castAdd b i)) c * W c (fun i => y (Fin.natAdd a i))) (Fin.append r s) := by
  rw [matmul_sum, mleAt_append]
  congr 1
  funext z j
  simp only [Fin.append_left, Fin.append_right]

end Mm

/-! ## The batch's entries past the named clauses read no `eq` table -/

section Congr

variable {R : Type} [CommRing R]

open ZK60.Exec.Slot.Build (Cst LkD denV)

/-- A denominator reads only its terms' positions. -/
theorem denV_congr (v v' : List R) (l : LkD R) (h : ∀ t ∈ l.terms, v.getD t.2 0 = v'.getD t.2 0) :
    denV v l = denV v' l := by
  unfold denV
  rw [List.map_congr_left (fun t ht => by rw [h t ht])]

/-- **LogUp's helper relations read only the helpers and the looked-up positions.** -/
theorem lkRels_congr (c : Cst R) (v v' : List R) (h0 : ℕ) : ∀ (k : ℕ) (lks : List (LkD R)),
    (∀ l ∈ lks, ∀ t ∈ l.terms, v.getD t.2 0 = v'.getD t.2 0) →
    (∀ i, i < (lks.length + 1) / 2 → v.getD (h0 + (k + i)) 0 = v'.getD (h0 + (k + i)) 0) →
    lkRels c v h0 k lks = lkRels c v' h0 k lks
  | _, [], _, _ => rfl
  | k, [l], ht, hh => by
    have e := hh 0 (by simp)
    simp only [Nat.add_zero] at e
    simp only [lkRels]
    rw [e, denV_congr v v' l (ht l (by simp))]
  | k, l₁ :: l₂ :: ls, ht, hh => by
    have e := hh 0 (by simp only [List.length_cons]; omega)
    simp only [Nat.add_zero] at e
    simp only [lkRels]
    rw [e, denV_congr v v' l₁ (ht l₁ (by simp)), denV_congr v v' l₂ (ht l₂ (by simp)),
      lkRels_congr c v v' h0 (k + 1) ls (fun l hl => ht l (by simp [hl])) (fun i hi => by
        have := hh (i + 1) (by simp only [List.length_cons]; omega)
        rwa [show k + (i + 1) = k + 1 + i by omega] at this)]

/-- **The pad term's planes read only the gates and the planes.** -/
theorem padPls_congr (v v' : List R) : ∀ gs : List (ℕ × List ℕ),
    (∀ g ∈ gs, v.getD g.1 0 = v'.getD g.1 0 ∧ ∀ p ∈ g.2, v.getD p 0 = v'.getD p 0) → padPls v gs = padPls v' gs
  | [], _ => rfl
  | (s, ps) :: gs, h => by
    simp only [padPls]
    obtain ⟨h1, h2⟩ := h (s, ps) (by simp)
    dsimp only at h1 h2
    rw [padPls_congr v v' gs (fun g hg => h g (by simp [hg]))]
    congr 1
    exact List.map_congr_left (fun p hp => by rw [h1, h2 p hp])

end Congr

section Words

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **The pad weights `ζ^j`**: the code's power word read in the field. -/
theorem toK_zpowW (z : Fp2) : ∀ j : ℕ, (zpowW z j).toK U = (z.toK U) ^ j
  | 0 => by simp [zpowW, Fp2.toK_one]
  | j + 1 => by
    have e : zpowW z (j + 1) = (zpowW z j).mul z := by
      unfold zpowW
      rw [List.range_succ, List.foldl_append]
      rfl
    rw [e, Fp2.toK_mul U hU, toK_zpowW z j, pow_succ]

/-- **The LogUp lookups' expressions read only `α` and `γ`** (their constants are `α − (c + g_tag)` and the terms'
coefficients). -/
theorem lksS_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : ZK60.Exec.Slot.W16R2.Dom) (h h' : Hist) (k k' : ℕ)
    (dr dr' : List Fp2) (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    (lksS c shaped d).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval h k dr))
      = (lksS c shaped d).map (ZK60.Exec.Slot.Build.LkD.map (Sym.eval h' k' dr')) := by
  unfold lksS
  simp only [List.map_map]
  refine List.map_congr_left (fun l _ => ?_)
  simp only [Function.comp_def, ZK60.Exec.Slot.Build.LkD.map, Sym.eval, ha, hg, List.map_map]

end Words

/-! ## A host's named identity, generic in the program -/

section Form

variable {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K) (hcard : 78 < Fintype.card K)
variable {L : ℕ}

include hcard in
/-- **A host's named identity (`FormAt`) from its program's hosted list and its cube identity**: if slot `k`'s
program hosts `(h₀, s₀)`, `(h₁, s₁)`, neither of which hosts slots, and on every outcome the host's certified
polynomial at the drawn challenges is its unmasked sum minus `s₀·Σ Poly_{h₀} + s₁·Σ Poly_{h₁}`, then `FormAt` holds
at `k` (on outcomes whose verified slots are hosts exactly when their definitions host slots). -/
theorem formAt_two (P : BlockParams) (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs)
    (D : CmData K P) (sh : AlgShape P) (dt : AlgData K L sh) (cu : Cuts3 L) (rt : RootsO)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (hk : k ∈ algHosts) (h0 h1 : ℕ) (s0 s1 : Sym)
    (hpk : (prog.getD k SlotS.empty).hosted = [(h0, s0), (h1, s1)])
    (hp0 : (prog.getD h0 SlotS.empty).hosted = []) (hp1 : (prog.getD h1 SlotS.empty).hosted = [])
    (hlt0 : h0 < k) (hlt1 : h1 < k)
    (hslots : ∀ j r, rs[j]? = some r → ∃ df, P.define j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) r.draws = .ok df
      ∧ (P.kind j = SlotKind.host ↔ df.hosted ≠ []))
    (hid : ∀ r, rs[k]? = some r →
      (hostSp U sh dt hcard k hk cu rt (histOf bga.1 bga.2.1 bga.2.2 (rs.take k))).Φ
          (fun i => (r.draws.getD i.val Fp2.zero).toK U)
        = spSum P (polyS U P D prog pubs) bga rs k
          - ((Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws s0).toK U
              * spSum P (polyS U P D prog pubs) bga rs h0
            + (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws s1).toK U
              * spSum P (polyS U P D prog pubs) bga rs h1)) :
    FormAt U P (polyS U P D prog pubs) (fun k h => (algSp U sh dt hcard 0 cu rt k h).Φ) bga rs k := by
  refine formAt_host_of U sh dt hcard _ cu rt bga rs k hk (fun r df hr hdf => ?_)
  have hlen : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  have hdfk : defineS prog pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df := hdef ▸ hdf
  obtain ⟨-, hdfe⟩ := defineS_ok hdfk
  have hhost : df.hosted = [(h0, Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws s0),
      (h1, Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws s1)] := by
    rw [hdfe]
    simp only [hpk, List.map_cons, List.map_nil]
  obtain ⟨df', hdf', hk'⟩ := hslots k r hr
  rw [hdf] at hdf'
  cases hdf'
  have hnot : ∀ j, (j = h0 ∨ j = h1) → P.kind j ≠ SlotKind.host := by
    intro j hj hkj
    have hjl : j < rs.length := by rcases hj with rfl | rfl <;> omega
    obtain ⟨rj, hrj⟩ : ∃ rj, rs[j]? = some rj := ⟨_, List.getElem?_eq_getElem hjl⟩
    obtain ⟨dfj, hdfj, hkj'⟩ := hslots j rj hrj
    have hdfj' : defineS prog pubs j (histOf bga.1 bga.2.1 bga.2.2 (rs.take j)) rj.draws = .ok dfj := hdef ▸ hdfj
    obtain ⟨-, hdfje⟩ := defineS_ok hdfj'
    have hemp : dfj.hosted = [] := by
      rw [hdfje]
      rcases hj with rfl | rfl
      · simp only [hp0, List.map_nil]
      · simp only [hp1, List.map_nil]
    exact hkj'.mp hkj hemp
  refine ⟨hk'.mpr (by rw [hhost]; simp), fun hk2 hmem => ?_, ?_⟩
  · rw [hhost] at hmem
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hmem
    rcases hmem with rfl | rfl
    · exact hnot _ (Or.inl rfl)
    · exact hnot _ (Or.inr rfl)
  · rw [hid r hr, hhost]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]

end Form

end ZK60.Exec.Block.Join.W16
