/-
D63 lane L63 (2026-11-20), L63 leg 16: **the concrete embedding fold `embFoldL`** (the run-data parameter `embFold`
of stage IN-C, computed from the public embedding table) and **the premise `hEmb` (ruling L63-8) for it, PROVED**.

* `embRowL P v`: row `v` of stage IN-C's padded embedding table as `4096` base-field words in the code's index order
  (`eq_table_msb`: the column with MSB index `j < 3072` holds `Fp::from_i64(E[v][j])`, the other `1024` columns `0`);
* **`embFoldL P r`**: for every token `v < V`, `mle::eval_mle_base`'s sum (`mleSumBase`) of row `v` against
  `eq_table_msb(r)` (`eqTableMsb`), the table computed once. Every piece is an executable definition of ExecMle.lean
  (`Fp.fromI64`, `eqTableMsb`, `mleSumBase`); nothing is chosen from an existence statement;
* `embRowL_getD_toGF`: entry `msbIndex 12 b` of row `v` reads `shdEpad P v b` (the `i16` bound from `P.Valid`);
* **`embFoldL_hEmb`**: `hEmb` in exactly the form the top states it, for `embFoldL P`, from `U ^ 2 = 7` and
  `P.Valid` (`toK_mleSumBase`: `eval_mle_base` is `mleAt`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldLuRd

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Sound ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.RunShape.Shield (shieldS0)

/-- **Row `v` of stage IN-C's padded embedding table** as base-field words, index `idx < 4096` in the code's
(`eq_table_msb`) order: `Fp::from_i64(E[v][idx])` for `idx < 3072`, `0` for the `1024` padding columns. -/
def embRowL (P : InPublic shieldS0) (v : ℕ) : List Fp :=
  List.ofFn (fun idx : Fin 4096 =>
    if h : idx.val < 3072 then Fp.fromI64 (P.emb v ⟨idx.val, h⟩) else Fp.zero)

/-- **THE CONCRETE EMBEDDING FOLD**: at the point `r` (the challenge `r_emb`), the list over the tokens `v < V` of
`eval_mle_base(row v, r)`'s sum against `eq_table_msb(r)` (computed once): the multilinear fold of the padded
embedding table at `r`, in `Fp2` arithmetic. -/
def embFoldL (P : InPublic shieldS0) (r : List Fp2) : List Fp2 :=
  let eq := eqTableMsb r
  List.ofFn (fun v : Fin P.V => mleSumBase (embRowL P v) eq)

theorem embRowL_length (P : InPublic shieldS0) (v : ℕ) : (embRowL P v).length = 4096 := by
  simp only [embRowL, List.length_ofFn]

theorem embFoldL_getD (P : InPublic shieldS0) (r : List Fp2) (v : Fin P.V) :
    (embFoldL P r).getD v Fp2.zero = mleSumBase (embRowL P v) (eqTableMsb r) := by
  simp only [embFoldL]
  rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn, dite_eq_left v.isLt, Option.getD_some]

/-- Entry `msbIndex 12 b` of row `v` reads the padded table `shdEpad P v b`. -/
theorem embRowL_getD_toGF (P : InPublic shieldS0) (hP : P.Valid) (v : Fin P.V) (b : Fin 12 → Bool) :
    ((embRowL P v).getD (msbIndex 12 b) Fp.zero).toGF = shdEpad P v b := by
  have hb : msbIndex 12 b < 4096 := msbIndex_lt 12 b
  have e : (embRowL P v).getD (msbIndex 12 b) Fp.zero
      = if h : msbIndex 12 b < 3072 then Fp.fromI64 (P.emb v ⟨msbIndex 12 b, h⟩) else Fp.zero := by
    simp only [embRowL]
    rw [List.getD_eq_getElem?_getD, List.getElem?_ofFn, dite_eq_left hb, Option.getD_some]
  rw [e]
  unfold shdEpad
  split_ifs with h
  · obtain ⟨h1, h2⟩ := hP.emb v ⟨msbIndex 12 b, h⟩
    exact Fp.toGF_fromI64 _ (by linarith) (by linarith)
  · simp [Fp.toGF, Fp.zero]

section K

variable {K : Type} [Field K] [Algebra GF K]

/-- `vecK` at a point of length `n` is the point read coordinate by coordinate (a cast of the cube's dimension). -/
theorem embFoldL_mle_len (U : K) (r : List Fp2) (n : ℕ) (hn : r.length = n) (g : ℕ → GF) :
    mleAt (fun b : Fin r.length → Bool => algebraMap GF K (g (msbIndex r.length b))) (vecK U r.length r)
      = mleAt (fun b : Fin n → Bool => algebraMap GF K (g (msbIndex n b)))
          (fun c : Fin n => (r.getD c Fp2.zero).toK U) := by
  subst hn
  rfl

/-- **THE PREMISE `hEmb` FOR THE CONCRETE FOLD** (ruling L63-8), in exactly the form the top states it: at a
canonical point of length `12`, every token's word of `embFoldL P` is, in `K`, the multilinear extension of the
padded embedding row at the point. -/
theorem embFoldL_hEmb (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : InPublic shieldS0) (hP : P.Valid) :
    ∀ rEmb : List Fp2, rEmb.length = 12 → (∀ a ∈ rEmb, a.Canon) → ∀ v : Fin P.V,
      ((embFoldL P rEmb).getD v Fp2.zero).toK U
        = mleAt (fun c => algebraMap GF K (shdEpad P v c)) (fun c : Fin 12 => (rEmb.getD c Fp2.zero).toK U) := by
  intro r hl hr v
  have hrow : (embRowL P v).length = 2 ^ r.length := by rw [embRowL_length, hl]; norm_num
  rw [embFoldL_getD, toK_mleSumBase U hU (embRowL P v) r hr hrow]
  have hfun : (fun b : Fin 12 → Bool => algebraMap GF K (((embRowL P v).getD (msbIndex 12 b) Fp.zero).toGF))
      = fun c => algebraMap GF K (shdEpad P v c) := by
    funext b
    rw [embRowL_getD_toGF P hP v b]
  rw [← hfun]
  exact embFoldL_mle_len U r 12 hl (fun idx => ((embRowL P v).getD idx Fp.zero).toGF)

end K

end ZK60.ProtocolClassify
