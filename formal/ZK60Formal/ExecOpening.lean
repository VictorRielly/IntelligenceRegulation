/-
D63 lane L10 (2026-11-07): **the hiding PCS opening's verifier, executable** (`zkp-core/src/pcs.rs`
`verify_zk_tagged`, read 2026-11-07; nothing there is changed), on L5's field, transcript and Merkle check, with the
encoder of `ExecOpeningCode.lean` evaluated at the sampled columns.

**What is mirrored** (`pcsVerify`, in the code's order):
* `log_cols` and `q_pad ≥ Q` (`PcsErr.logCols`, `.fewPads`); every opened path has `log2(N)` entries, FIRST (T-4, F9);
* `group_zclaims` (`zpartWeights`, `zkeyWeights`, `groupZclaims`: first-occurrence grouping by column key, row weights
  through `eq_table_msb`); the code's assertions on the claims' shapes (the verifier's own claims) are not mirrored;
* `zk_rhos` (`zkRhos`): per group `challenge_fp2_vec(members)` and `ρ_g = Σ λ_c·rw_c` (the code's skip of zero
  entries), `want_g = Σ λ_c·val_c`; then `challenge_fp2_vec(rows)`, the proximity weights;
* per group, in order: the vector has `n + q` entries, and `⟨v[..n], c_g⟩ = want_g` on the words;
* `absorb_fp2("pcs-vec", v_g)` per group; the proximity vector's length; `absorb_fp2("pcs-prox", w)`;
  `challenge_indices(Q, N)`; the column count;
* per column, in order: the index, the length, the salted leaf and the path (`ExecMerkle.lean`'s keyed `verifyPath`),
  then for each combination (the groups' `ρ_g`, then the proximity `ρ`) the WORD equality
  `Σ_i ρ_i·col_i = enc(v)(η_j)`.

**The encoder at a column** is computed directly, not by a full NTT: for a clear vector `v` (message `v[..n]`, pads
`v[n..]`) at the point `η_j = 7·ω_N^j`, `f(η_j) = rowPoly(v[..n])(η_j) + (η_j^n − 1)·Σ_k v_{n+k}·η_j^k`.
* W16R2 (`colEncLag`): the interpolant by its barycentric form (`ExecOpeningCode.lean`'s `bary_eval`), the weights
  `ω^i·(η − ω^i)⁻¹` shared by every vector of the column, with ONE field inversion (`batchInv`, Montgomery's trick);
* W16R3, B1 (`colEncCoef`): the coefficients against the powers of `η`.
The code computes the same values with `encode_row_zk` (inverse NTT, coset powers, forward NTT); that the two agree on
the code's words is TESTED by the corpus (`ExecOpeningCheck.lean`), not proved (finding L10-1).

**What is proved** (only `propext`, `Classical.choice`, `Quot.sound`):
* the arithmetic: `toK_dotB` (a dot product of words is the field's), `powList_getD`, `batchInv_spec` (Montgomery's
  trick is the field inverse, entry by entry), `baryW_spec`, `toGF_baryScale`;
* **`toK_encLag`**, **`toK_encCoef`**: the executable column evaluation IS the encoder's polynomial `encPoly` of the row
  form (`lagForm`, `coefForm`) at the point, in any field `K ⊇ GF`; hence (`colEncLag_spec`, `colEncCoef_spec`) they
  meet the specification `ColEncSpec` that `pcsVerify` is proved against;
* **`pcsVerify_ok_iff`**: `pcsVerify` returns `ok t'` EXACTLY WHEN every listed check holds: the parameters, the
  path depths, the group count, each group's length and claim check, the proximity vector's length, the indices
  (`t'` the transcript after them), the column count, and for every column its index, its length, its Merkle path
  (`verifyColumn`, hence `MerkleEnc.Opens` by `verifyColumn_iff`) and every combination's word equality;
* **`colEq_iff_K`**: under `ColEncSpec`, a column's word equality is the field equation
  `Σ_i ρ_i·col_i = (encPoly form (v[..n]) (v[n..])).eval η_j` in `K` (`toK_injective`: both words are canonical);
  `opening_columns_K` assembles it: an accepted opening's every column satisfies `SoundGroups.lean`'s column checks
  for the encoder `encLin` (`ExecOpeningCode.lean`).
-/
import ZK60Formal.ExecOpeningCode
import ZK60Formal.ExecMerkle
import ZK60Formal.ExecMle

set_option autoImplicit false

namespace ZK60.Exec

open Polynomial Finset
open ZK60.Circuit (gP GF)
open ZK60.Sound (mPts mInterp)

/-! ## Word arithmetic: powers, dot products, Montgomery's batch inversion -/

section Arith

/-- `c, c·x, c·x², …` (`k` entries). -/
def powListAux (x : Fp) : Fp → ℕ → List Fp
  | _, 0 => []
  | c, k + 1 => c :: powListAux x (c.mul x) k

/-- `1, x, …, x^(k−1)`. -/
def powList (x : Fp) (k : ℕ) : List Fp := powListAux x Fp.one k

theorem powListAux_length (x : Fp) : ∀ (c : Fp) (k : ℕ), (powListAux x c k).length = k
  | _, 0 => rfl
  | c, k + 1 => by simp [powListAux, powListAux_length x (c.mul x) k]

theorem powList_length (x : Fp) (k : ℕ) : (powList x k).length = k := powListAux_length x _ k

theorem powListAux_getD (x : Fp) : ∀ (c : Fp) (k i : ℕ), i < k →
    ((powListAux x c k).getD i Fp.zero).toGF = c.toGF * x.toGF ^ i
  | _, 0, _, h => absurd h (Nat.not_lt_zero _)
  | c, k + 1, 0, _ => by simp [powListAux]
  | c, k + 1, i + 1, h => by
    rw [powListAux, List.getD_cons_succ, powListAux_getD x (c.mul x) k i (by omega), Fp.toGF_mul, pow_succ]
    ring

theorem Fp.toGF_one : Fp.one.toGF = 1 := by simp [Fp.one, Fp.toGF]

theorem powList_getD (x : Fp) (k i : ℕ) (h : i < k) : ((powList x k).getD i Fp.zero).toGF = x.toGF ^ i := by
  rw [powList, powListAux_getD x Fp.one k i h, Fp.toGF_one, one_mul]

/-- A dot product of `Fp2` words with base-field words: `Σ_i v_i·w_i`, left to right from zero (`fold(ZERO, add)`). -/
def dotB (v : List Fp2) (w : List Fp) : Fp2 := (v.zip w).foldl (fun acc p => acc.add (p.1.mulBase p.2)) Fp2.zero

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem foldl_dotB (l : List (Fp2 × Fp)) : ∀ acc : Fp2, acc.Canon →
    (l.foldl (fun acc p => acc.add (p.1.mulBase p.2)) acc).toK U
      = acc.toK U + (l.map (fun p => p.1.toK U * algebraMap GF K p.2.toGF)).sum := by
  induction l with
  | nil => intro acc _; simp
  | cons p l ih =>
    intro acc hacc
    rw [List.foldl_cons, ih _ (Fp2.canon_add _ _), Fp2.toK_add U _ _ hacc (Fp2.canon_mulBase _ _),
      Fp2.toK_mulBase, List.map_cons, List.sum_cons]
    ring

omit [Algebra GF K] in
theorem sum_zip_range (f : Fp2 → Fp → K) : ∀ (v : List Fp2) (w : List Fp), w.length = v.length →
    ((v.zip w).map (fun p => f p.1 p.2)).sum
      = ∑ i ∈ Finset.range v.length, f (v.getD i Fp2.zero) (w.getD i Fp.zero)
  | [], _, _ => by simp
  | a :: v, [], h => by simp at h
  | a :: v, b :: w, h => by
    rw [List.zip_cons_cons, List.map_cons, List.sum_cons, sum_zip_range f v w (by simpa using h), List.length_cons,
      Finset.sum_range_succ']
    simp only [List.getD_cons_succ, List.getD_cons_zero]
    ring

/-- **A dot product of words is the field's**: `Σ_{i < m} v_i·w_i` for lists of `m` entries (no canonicity premise:
every partial sum is an output of `add`, every product of `mulBase`). -/
theorem toK_dotB (v : List Fp2) (w : List Fp) (m : ℕ) (hv : v.length = m) (hw : w.length = m) :
    (dotB v w).toK U = ∑ i : Fin m, (v.getD i Fp2.zero).toK U * algebraMap GF K (w.getD i Fp.zero).toGF := by
  subst hv
  unfold dotB
  rw [foldl_dotB U _ _ Fp2.canon_zero, Fp2.toK_zero, zero_add,
    sum_zip_range (fun a b => a.toK U * algebraMap GF K b.toGF) v w hw,
    Finset.sum_range (fun i => (v.getD i Fp2.zero).toK U * algebraMap GF K (w.getD i Fp.zero).toGF)]

end K

theorem canon_dotB (v : List Fp2) (w : List Fp) : (dotB v w).Canon :=
  canon_foldl_add (fun p : Fp2 × Fp => p.1.mulBase p.2) _ _ Fp2.canon_zero

/-- Products of the entries after each position (and the product of all): `sufAux [x₀, …] = (Π x, [Π_{k>0}, Π_{k>1}, …,
1])`. -/
def sufAux : List Fp → Fp × List Fp
  | [] => (Fp.one, [])
  | x :: xs => let r := sufAux xs; (x.mul r.1, r.1 :: r.2)

/-- The back-substitution of Montgomery's trick. -/
def binvGo : List Fp → List Fp → Fp → List Fp
  | x :: xs, s :: ss, a => a.mul s :: binvGo xs ss (a.mul x)
  | _, _, _ => []

/-- **Montgomery's batch inversion**: every entry's inverse with one field inversion. -/
def batchInv (l : List Fp) : List Fp := let r := sufAux l; binvGo l r.2 r.1.inv

theorem sufAux_fst (l : List Fp) : (sufAux l).1.toGF = (l.map Fp.toGF).prod := by
  induction l with
  | nil => simp [sufAux, Fp.toGF_one]
  | cons x xs ih => simp [sufAux, Fp.toGF_mul, ih]

theorem sufAux_snd_length (l : List Fp) : (sufAux l).2.length = l.length := by
  induction l with
  | nil => rfl
  | cons x xs ih => simp [sufAux, ih]

theorem binvGo_spec : ∀ (l : List Fp) (a : Fp), (∀ x ∈ l, x.toGF ≠ 0) → a.toGF = ((l.map Fp.toGF).prod)⁻¹ →
    (binvGo l (sufAux l).2 a).length = l.length
      ∧ ∀ i, i < l.length → ((binvGo l (sufAux l).2 a).getD i Fp.zero).toGF = ((l.getD i Fp.zero).toGF)⁻¹
  | [], _, _, _ => ⟨rfl, fun i h => absurd h (Nat.not_lt_zero _)⟩
  | x :: xs, a, hnz, ha => by
    have hx : x.toGF ≠ 0 := hnz x List.mem_cons_self
    have hxs : (xs.map Fp.toGF).prod ≠ 0 := by
      refine List.prod_ne_zero (fun h0 => ?_)
      obtain ⟨y, hy, hy0⟩ := List.mem_map.mp h0
      exact hnz y (List.mem_cons_of_mem _ hy) hy0
    have ha' : (a.mul x).toGF = ((xs.map Fp.toGF).prod)⁻¹ := by
      rw [Fp.toGF_mul, ha, List.map_cons, List.prod_cons, mul_inv, mul_comm, ← mul_assoc, mul_inv_cancel₀ hx,
        one_mul]
    have ih := binvGo_spec xs (a.mul x) (fun y hy => hnz y (List.mem_cons_of_mem _ hy)) ha'
    simp only [sufAux, binvGo]
    refine ⟨by simp [ih.1], fun i hi => ?_⟩
    rcases i with _ | i
    · simp only [List.getD_cons_zero]
      rw [Fp.toGF_mul, ha, sufAux_fst, List.map_cons, List.prod_cons, mul_inv, mul_assoc, inv_mul_cancel₀ hxs,
        mul_one]
    · simp only [List.getD_cons_succ]
      exact ih.2 i (by simpa using hi)

/-- **Montgomery's trick is the field inverse**, entry by entry, when no entry is zero. -/
theorem batchInv_spec (l : List Fp) (hnz : ∀ x ∈ l, x.toGF ≠ 0) :
    (batchInv l).length = l.length
      ∧ ∀ i, i < l.length → ((batchInv l).getD i Fp.zero).toGF = ((l.getD i Fp.zero).toGF)⁻¹ :=
  binvGo_spec l _ hnz (by rw [Fp.toGF_inv', sufAux_fst])

theorem getD_map_lt' {α β : Type} (f : α → β) (l : List α) (i : ℕ) (h : i < l.length) (d : α) (d' : β) :
    (l.map f).getD i d' = f (l.getD i d) := by
  rw [getD_eq_get _ _ _ (by simpa using h), getD_eq_get _ _ _ h, List.getElem_map]

theorem getD_take_lt {α : Type} (l : List α) (n i : ℕ) (h : i < n) (d : α) : (l.take n).getD i d = l.getD i d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt h]

theorem getD_drop {α : Type} (l : List α) (n i : ℕ) (d : α) : (l.drop n).getD i d = l.getD (n + i) d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_drop]

/-- Entrywise products of two lists (`zip(..).map(mul)`). -/
def mulPair : List Fp → List Fp → List Fp
  | [], _ => []
  | _ :: _, [] => []
  | a :: as, b :: bs => a.mul b :: mulPair as bs

theorem mulPair_cons (a b : Fp) (as bs : List Fp) : mulPair (a :: as) (b :: bs) = a.mul b :: mulPair as bs := rfl

theorem mulPair_spec : ∀ (l l' : List Fp), l.length = l'.length →
    (mulPair l l').length = l.length ∧ ∀ i, i < l.length →
      ((mulPair l l').getD i Fp.zero).toGF = (l.getD i Fp.zero).toGF * (l'.getD i Fp.zero).toGF
  | [], [], _ => ⟨rfl, fun i h => absurd h (Nat.not_lt_zero _)⟩
  | [], _ :: _, h => absurd h (by rw [List.length_nil, List.length_cons]; omega)
  | _ :: _, [], h => absurd h (by rw [List.length_nil, List.length_cons]; omega)
  | a :: as, b :: bs, h => by
    have ih := mulPair_spec as bs (by rw [List.length_cons, List.length_cons] at h; omega)
    rw [mulPair_cons]
    refine ⟨by rw [List.length_cons, List.length_cons, ih.1], fun i hi => ?_⟩
    rcases i with _ | i
    · rw [List.getD_cons_zero, List.getD_cons_zero, List.getD_cons_zero, Fp.toGF_mul]
    · rw [List.getD_cons_succ, List.getD_cons_succ, List.getD_cons_succ]
      exact ih.2 i (by rw [List.length_cons] at hi; omega)

theorem powListAux_canon (x : Fp) : ∀ (c : Fp) (k : ℕ), c.Canon → ∀ w ∈ powListAux x c k, w.Canon
  | _, 0, _, _, hw => by simp [powListAux] at hw
  | c, k + 1, hc, w, hw => by
    simp only [powListAux, List.mem_cons] at hw
    rcases hw with rfl | hw
    · exact hc
    · exact powListAux_canon x (c.mul x) k (Fp.mul_canon _ _) w hw

theorem powList_canon (x : Fp) (k : ℕ) : ∀ w ∈ powList x k, w.Canon :=
  powListAux_canon x Fp.one k (by decide)

/-- **The barycentric weights at a point**: `ω^i·(x − ω^i)⁻¹` for the powers `pw` of `ω`. -/
def baryW (pw : List Fp) (x : Fp) : List Fp := mulPair pw (batchInv (pw.map (fun w => x.sub w)))

/-- The vanishing polynomial of `G_n` at `x`: `x^n − 1`. -/
def zAt (n : ℕ) (x : Fp) : Fp := (x.pow (UInt64.ofNat n)).sub Fp.one

/-- The barycentric scale `(x^n − 1)·n⁻¹`. -/
def baryScale (n : ℕ) (x : Fp) : Fp := (zAt n x).mul (Fp.new (UInt64.ofNat n)).inv

theorem Fp.one_canon : Fp.one.Canon := by decide

theorem toGF_zAt (n : ℕ) (hn : n < 2 ^ 64) (x : Fp) : (zAt n x).toGF = x.toGF ^ n - 1 := by
  rw [zAt, Fp.toGF_sub _ _ (Fp.pow_canon _ _) Fp.one_canon, Fp.toGF_pow, UInt64.toNat_ofNat',
    Nat.mod_eq_of_lt hn, Fp.toGF_one]

theorem toGF_baryScale (n : ℕ) (hn : n < 2 ^ 64) (x : Fp) :
    (baryScale n x).toGF = (x.toGF ^ n - 1) * (n : GF)⁻¹ := by
  rw [baryScale, Fp.toGF_mul, toGF_zAt n hn, Fp.toGF_inv', Fp.new_toGF_ofNat n hn]

theorem baryW_spec {n : ℕ} (ωF x : Fp) (hx : x.Canon) (hω : IsPrimitiveRoot ωF.toGF n) (hxn : x.toGF ^ n ≠ 1) :
    (baryW (powList ωF n) x).length = n
      ∧ ∀ i, i < n → ((baryW (powList ωF n) x).getD i Fp.zero).toGF
          = ωF.toGF ^ i * (x.toGF - ωF.toGF ^ i)⁻¹ := by
  set pw := powList ωF n with hpw
  have hlen : pw.length = n := powList_length ωF n
  have hsub : ∀ i, i < n → ((pw.map (fun w => x.sub w)).getD i Fp.zero).toGF = x.toGF - ωF.toGF ^ i := by
    intro i hi
    have hi' : i < pw.length := by rw [hlen]; exact hi
    have hmem : pw.getD i Fp.zero ∈ pw := by
      rw [getD_eq_get _ _ _ hi']
      exact List.getElem_mem _
    rw [getD_map_lt' _ pw i hi' Fp.zero, Fp.toGF_sub _ _ hx (powList_canon ωF n _ hmem), powList_getD ωF n i hi]
  have hnz : ∀ y ∈ pw.map (fun w => x.sub w), y.toGF ≠ 0 := by
    intro y hy
    obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hy
    have hi' : i < n := by simpa [hlen] using hi
    have := hsub i hi'
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi, Option.getD_some] at this
    rw [this, sub_ne_zero]
    intro hxw
    apply hxn
    rw [hxw, ← pow_mul, mul_comm, pow_mul, hω.pow_eq_one, one_pow]
  obtain ⟨hbl, hbi⟩ := batchInv_spec _ hnz
  have hml := mulPair_spec pw (batchInv (pw.map (fun w => x.sub w))) (by rw [hbl, List.length_map])
  refine ⟨by rw [baryW, hml.1, hlen], fun i hi => ?_⟩
  rw [baryW, hml.2 i (by rw [hlen]; exact hi), powList_getD ωF n i hi,
    hbi i (by rw [List.length_map, hlen]; exact hi), hsub i hi]

end Arith

/-! ## The encoder at a column, executable, and its specification -/

section Enc

/-- **W16R2's column evaluation of one clear vector** (prepared weights `bw`, scale `sc`, `z = η^n − 1`, the powers
`px` of `η`): `(Σ_i v_i·bw_i)·sc + (Σ_k v_{n+k}·η^k)·z`. -/
def encLagAt (n : ℕ) (bw : List Fp) (sc z : Fp) (px : List Fp) (v : List Fp2) : Fp2 :=
  ((dotB (v.take n) bw).mulBase sc).add ((dotB (v.drop n) px).mulBase z)

/-- **W16R2's column evaluation** of all of a column's clear vectors at its point `x` (the barycentric weights
computed once, with one inversion). -/
def colEncLag (ωF : Fp) (n Q : ℕ) (x : Fp) (vs : List (List Fp2)) : List Fp2 :=
  let bw := baryW (powList ωF n) x
  let sc := baryScale n x
  let z := zAt n x
  let px := powList x Q
  vs.map (encLagAt n bw sc z px)

/-- **W16R3's column evaluation (B1)**: the message symbols are coefficients, `Σ_i v_i·η^i + (Σ_k v_{n+k}·η^k)·z`. -/
def encCoefAt (n : ℕ) (pn : List Fp) (z : Fp) (px : List Fp) (v : List Fp2) : Fp2 :=
  (dotB (v.take n) pn).add ((dotB (v.drop n) px).mulBase z)

def colEncCoef (n Q : ℕ) (x : Fp) (vs : List (List Fp2)) : List Fp2 :=
  let pn := powList x n
  let z := zAt n x
  let px := powList x Q
  vs.map (encCoefAt n pn z px)

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The pad part of a clear vector, read in `K`. -/
def padK (n Q : ℕ) (v : List Fp2) : Fin Q → K := fun k => (v.getD (n + k) Fp2.zero).toK U

/-- **The model's encoded value** of a clear vector at a point: `encPoly form (v[..n]) (v[n..])` at `x`. -/
noncomputable def encK {n : ℕ} (R : RowForm K n) (Q : ℕ) (v : List Fp2) (x : K) : K :=
  (encPoly R (vecK U n v) (padK U n Q v)).eval x

omit [Algebra GF K] in
theorem eval_coefPoly {k : ℕ} (g : Fin k → K) (x : K) : (coefPoly g).eval x = ∑ i, g i * x ^ (i : ℕ) := by
  rw [coefPoly_apply, eval_finsetSum]
  simp [eval_monomial]

/-- The pad part of the executable evaluation: `Σ_k v_{n+k}·x^k`. -/
theorem toK_dotB_pad (n Q : ℕ) (v : List Fp2) (hv : v.length = n + Q) (x : Fp) :
    (dotB (v.drop n) (powList x Q)).toK U = ∑ k : Fin Q, padK U n Q v k * (algebraMap GF K x.toGF) ^ (k : ℕ) := by
  rw [toK_dotB U _ _ Q (by rw [List.length_drop, hv]; omega) (powList_length x Q)]
  refine Finset.sum_congr rfl fun k _ => ?_
  rw [getD_drop, powList_getD x Q k k.isLt, map_pow]
  rfl

theorem algebraMap_ne_one {x : GF} (h : x ≠ 1) : algebraMap GF K x ≠ 1 := by
  intro h'
  apply h
  exact (algebraMap GF K).injective (by rw [h', map_one])

/-- **W16R2's executable column evaluation is the encoder** (`lagForm` rows): at a canonical point `x` off `G_n`, with
`ω` a primitive `n`-th root and a clear vector of `n + Q` entries. -/
theorem toK_encLag {n Q : ℕ} (hn : 0 < n) (hn64 : n < 2 ^ 64) (ωF : Fp) (hω : IsPrimitiveRoot ωF.toGF n) (x : Fp)
    (hx : x.Canon) (hxn : x.toGF ^ n ≠ 1) (v : List Fp2) (hv : v.length = n + Q) :
    (encLagAt n (baryW (powList ωF n) x) (baryScale n x) (zAt n x) (powList x Q) v).toK U
      = encK U (lagForm hn (hω.map_of_injective (algebraMap GF K).injective)) Q v (algebraMap GF K x.toGF) := by
  obtain ⟨hbl, hbi⟩ := baryW_spec ωF x hx hω hxn
  have hx' : (algebraMap GF K x.toGF) ^ n ≠ 1 := by rw [← map_pow]; exact algebraMap_ne_one hxn
  unfold encLagAt encK encPoly
  rw [eval_add, eval_mul, lagForm_poly, bary_eval hn (hω.map_of_injective (algebraMap GF K).injective) _ _ hx', eval_coefPoly,
    Fp2.toK_add U _ _ (Fp2.canon_mulBase _ _) (Fp2.canon_mulBase _ _), Fp2.toK_mulBase, Fp2.toK_mulBase,
    toK_dotB_pad U n Q v hv x,
    toK_dotB U _ _ n (by rw [List.length_take, hv]; omega) hbl, toGF_baryScale n hn64, toGF_zAt n hn64]
  have hs : ∑ i : Fin n, ((v.take n).getD i Fp2.zero).toK U
        * algebraMap GF K ((baryW (powList ωF n) x).getD i Fp.zero).toGF
      = ∑ i : Fin n, vecK U n v i * ((algebraMap GF K ωF.toGF) ^ (i : ℕ)
          * (algebraMap GF K x.toGF - (algebraMap GF K ωF.toGF) ^ (i : ℕ))⁻¹) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [getD_take_lt _ _ _ i.isLt, hbi i i.isLt, map_mul, map_inv₀, map_sub, map_pow]
    rfl
  rw [hs]
  simp only [map_mul, map_sub, map_pow, map_one, map_inv₀, map_natCast, eval_sub, eval_pow, eval_X, eval_one]
  ring

/-- **W16R3's executable column evaluation is the encoder** (`coefForm` rows, B1). -/
theorem toK_encCoef {n Q : ℕ} (hn : 0 < n) (hn64 : n < 2 ^ 64) (x : Fp) (v : List Fp2) (hv : v.length = n + Q) :
    (encCoefAt n (powList x n) (zAt n x) (powList x Q) v).toK U
      = encK U (coefForm (F := K) hn) Q v (algebraMap GF K x.toGF) := by
  unfold encCoefAt encK encPoly
  rw [eval_add, eval_mul, show (coefForm (F := K) hn).poly = coefPoly from rfl, eval_coefPoly, eval_coefPoly,
    Fp2.toK_add U _ _ (canon_dotB _ _) (Fp2.canon_mulBase _ _), Fp2.toK_mulBase,
    toK_dotB_pad U n Q v hv x, toK_dotB U _ _ n (by rw [List.length_take, hv]; omega) (powList_length x n),
    toGF_zAt n hn64]
  have hs : ∑ i : Fin n, ((v.take n).getD i Fp2.zero).toK U * algebraMap GF K ((powList x n).getD i Fp.zero).toGF
      = ∑ i : Fin n, vecK U n v i * (algebraMap GF K x.toGF) ^ (i : ℕ) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [getD_take_lt _ _ _ i.isLt, powList_getD x n i i.isLt, map_pow]
    rfl
  rw [hs]
  simp only [map_sub, map_pow, map_one, eval_sub, eval_pow, eval_X, eval_one]
  ring

end Enc

/-! ## The claims and their groups (`group_zclaims`), executable -/

section Claims

/-- `ZPart`: `coef·MLE(slice)(point)`, or with an empty point `coef·Σ slice`. -/
structure ZPart where
  offset : ℕ
  logSize : ℕ
  coef : Fp2
  point : List Fp2

/-- `ZClaim`: `value = Σ parts`. -/
structure ZClaim where
  parts : List ZPart
  value : Fp2

/-- The column-weight key of a part (`ZKey`): the point tail on the column range `[c0, c0 + len)`. -/
structure ZKey where
  tail : List Fp2
  c0 : ℕ
  len : ℕ
  deriving DecidableEq

/-- `row_w[i] = row_w[i].add(a)` (an index past the end leaves the list unchanged; the code's indices are in range). -/
def addAt : List Fp2 → ℕ → Fp2 → List Fp2
  | [], _, _ => []
  | x :: l, 0, a => x.add a :: l
  | x :: l, i + 1, a => x :: addAt l i a

/-- **`zpart_weights`**: a part's row weights over the commitment's `rows` rows and its column key. -/
def zpartWeights (p : ZPart) (rows logCols : ℕ) : List Fp2 × ZKey :=
  let n := 2 ^ logCols
  let rw0 := List.replicate rows Fp2.zero
  let ls := p.logSize
  let r0 := p.offset / n
  if p.point.isEmpty then
    if logCols ≤ ls then
      ((List.range (2 ^ (ls - logCols))).foldl (fun rw i => addAt rw (r0 + i) p.coef) rw0, ⟨[], 0, n⟩)
    else (addAt rw0 r0 p.coef, ⟨[], p.offset % n, 2 ^ ls⟩)
  else
    if logCols ≤ ls then
      let lr := ls - logCols
      let eqR := eqTableMsb (p.point.take lr)
      ((List.range eqR.length).foldl (fun rw i => addAt rw (r0 + i) (p.coef.mul (eqR.getD i Fp2.zero))) rw0,
        ⟨p.point.drop lr, 0, n⟩)
    else (addAt rw0 r0 p.coef, ⟨p.point, p.offset % n, 2 ^ ls⟩)

/-- **`zkey_weights`**: a key's column weights over the `2^logCols` columns. -/
def zkeyWeights (k : ZKey) (logCols : ℕ) : List Fp2 :=
  let eqC := eqTableMsb k.tail
  (List.range (2 ^ logCols)).map (fun c =>
    if k.c0 ≤ c ∧ c < k.c0 + k.len then (if k.tail.isEmpty then Fp2.one else eqC.getD (c - k.c0) Fp2.zero)
    else Fp2.zero)

/-- A claim's row weights (its parts' weights added) and its key (the first part's; the code asserts the others
agree). -/
def claimWeights (c : ZClaim) (rows logCols : ℕ) : List Fp2 × ZKey :=
  match c.parts with
  | [] => (List.replicate rows Fp2.zero, ⟨[], 0, 0⟩)
  | p :: ps =>
    let w0 := zpartWeights p rows logCols
    (ps.foldl (fun rw q => List.zipWith Fp2.add rw (zpartWeights q rows logCols).1) w0.1, w0.2)

/-- The position of a key in a list of keys. -/
def keyIdx (keys : List ZKey) (k : ZKey) : Option ℕ := keys.findIdx? (fun k' => decide (k' = k))

/-- `groups[gi].1.push(m)`. -/
def pushAt {α β : Type} : List (α × List β) → ℕ → β → List (α × List β)
  | [], _, _ => []
  | x :: l, 0, m => (x.1, x.2 ++ [m]) :: l
  | x :: l, i + 1, m => x :: pushAt l i m

/-- One claim's step of `group_zclaims`. -/
def groupStep (rows logCols : ℕ) (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))) (c : ZClaim) :
    List ZKey × List (List Fp2 × List (List Fp2 × Fp2)) :=
  let w := claimWeights c rows logCols
  match keyIdx st.1 w.2 with
  | some gi => (st.1, pushAt st.2 gi (w.1, c.value))
  | none => (st.1 ++ [w.2], st.2 ++ [(zkeyWeights w.2 logCols, [(w.1, c.value)])])

/-- **`group_zclaims`**: the groups, in first-occurrence order of their keys: (column weights, [(row weights,
value)]). -/
def groupZclaims (claims : List ZClaim) (rows logCols : ℕ) : List (List Fp2 × List (List Fp2 × Fp2)) :=
  (claims.foldl (groupStep rows logCols) ([], [])).2

/-- One member's contribution to its group's row weights: `ρ_i += λ·rw_i` where `rw_i ≠ 0` (the code skips zero
entries). -/
def rhoAdd (lam : Fp2) (rho rw : List Fp2) : List Fp2 :=
  List.zipWith (fun r w => if w.isZero then r else r.add (lam.mul w)) rho rw

/-- One group's combined row weights and claimed value under its `λ`s. -/
def groupComb (rows : ℕ) (members : List (List Fp2 × Fp2)) (lams : List Fp2) : List Fp2 × Fp2 :=
  (members.zip lams).foldl (fun acc p => (rhoAdd p.2 acc.1 p.1.1, acc.2.add (p.2.mul p.1.2)))
    (List.replicate rows Fp2.zero, Fp2.zero)

variable (H : HIn → Dig)

/-- **`zk_rhos`**: per group `challenge_fp2_vec(members)` and its combination; then `challenge_fp2_vec(rows)`, the
proximity weights. Returns (the groups' `ρ` then the proximity `ρ`, the groups' wanted values, the transcript). -/
def zkRhosAux (rows : ℕ) : List (List Fp2 × List (List Fp2 × Fp2)) → Tr → List (List Fp2) × List Fp2 × Tr
  | [], t => let r := t.challengeFp2Vec H rows; ([r.1], [], r.2)
  | g :: gs, t =>
    let l := t.challengeFp2Vec H g.2.length
    let c := groupComb rows g.2 l.1
    let rest := zkRhosAux rows gs l.2
    (c.1 :: rest.1, c.2 :: rest.2.1, rest.2.2)

theorem zkRhosAux_length (rows : ℕ) : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
    (zkRhosAux H rows gs t).1.length = gs.length + 1 ∧ (zkRhosAux H rows gs t).2.1.length = gs.length
  | [], _ => ⟨rfl, rfl⟩
  | g :: gs, t => by
    have ih := zkRhosAux_length rows gs (t.challengeFp2Vec H g.2.length).2
    simp only [zkRhosAux, List.length_cons, ih.1, ih.2, and_self]

end Claims

/-! ## The opening's verifier -/

section Verify

/-- An opened column: (index, the column's `rows` entries, the leaf salt, the Merkle path). -/
abbrev OCol := ℕ × List Fp × Dig × List Dig

/-- **`OpeningZk`**: one clear vector per group (`n` message entries then `Q` pad entries), the proximity vector, the
opened columns. -/
structure OpeningZk where
  groupVecs : List (List Fp2)
  proxVec : List Fp2
  columns : List OCol

/-- The opening's parameters (`PcsParams`, `ZkOpts`): `log_cols`, the inverse rate, `Q` opened columns, `q_pad` pad
symbols. -/
structure PcsPrm where
  logCols : ℕ
  invRate : ℕ
  nQ : ℕ
  qPad : ℕ

def PcsPrm.n (p : PcsPrm) : ℕ := 2 ^ p.logCols
def PcsPrm.nn (p : PcsPrm) : ℕ := 2 ^ p.logCols * p.invRate

/-- The refusals of `verify_zk_tagged`, in the code's order. -/
inductive PcsErr
  | logCols
  | fewPads
  | pathLen (at_ : ℕ)
  | nGroups
  | vecLen (g : ℕ)
  | claim (g : ℕ)
  | proxLen
  | indices
  | nCols
  | colIndex (j want : ℕ)
  | colLen
  | merkle (j : ℕ)
  | colVec (j g : ℕ)
  deriving DecidableEq, Repr

/-- `"pcs-vec"`, `"pcs-prox"`. -/
def pcsVecLabel : List UInt8 := [112, 99, 115, 45, 118, 101, 99]
def pcsProxLabel : List UInt8 := [112, 99, 115, 45, 112, 114, 111, 120]

/-- The claim check's dot product `⟨v[..n], c⟩` (`fold(ZERO, add(x.mul(y)))`). -/
def dotF (v c : List Fp2) : Fp2 := (v.zip c).foldl (fun a p => a.add (p.1.mul p.2)) Fp2.zero

/-- Each group, in order: its vector has `n + q` entries, and `⟨v[..n], c_g⟩ = want_g`; the first failure. -/
def groupCheck (n q : ℕ) : ℕ → List (List Fp2) → List Fp2 → List (List Fp2) → Option PcsErr
  | g, cw :: cws, w :: ws, v :: vs =>
    if v.length ≠ n + q then some (.vecLen g)
    else if dotF (v.take n) cw ≠ w then some (.claim g)
    else groupCheck n q (g + 1) cws ws vs
  | _, _, _, _ => none

/-- The first combination `g` whose column check fails: `Σ_i ρ_{g,i}·col_i ≠ enc(v_g)(η_j)`. -/
def firstBad (col : List Fp) : ℕ → List (List Fp2) → List Fp2 → Option ℕ
  | g, rho :: rhos, e :: es => if dotB rho col ≠ e then some g else firstBad col (g + 1) rhos es
  | _, _, _ => none

variable (H : HIn → Dig) (tag : MTag)

/-- Each opened column, in order: its index, its length, its Merkle path, every combination; the first failure.
`evAt j` is the clear vectors' encodings at column `j`. -/
def colsCheck (root : Dig) (rows : ℕ) (rhos : List (List Fp2)) (evAt : ℕ → List Fp2) :
    List OCol → List ℕ → Option PcsErr
  | (j, col, salt, path) :: cs, wj :: ws =>
    if j ≠ wj then some (.colIndex j wj)
    else if col.length ≠ rows then some .colLen
    else if verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = false then some (.merkle j)
    else match firstBad col 0 rhos (evAt j) with
      | some g => some (.colVec j g)
      | none => colsCheck root rows rhos evAt cs ws
  | _, _ => none

/-- Absorb every group vector under `"pcs-vec"`. -/
def absorbVecs (vs : List (List Fp2)) (t : Tr) : Tr := vs.foldl (fun t v => t.absorbFp2 H pcsVecLabel v) t

/-- The opened paths whose length is not the tree's depth: the first such position. -/
def badPath (depth : ℕ) (cs : List OCol) : Option ℕ := cs.findIdx? (fun c => decide (c.2.2.2.length ≠ depth))

/-- **`pcs::verify_zk_tagged`**, executable. `pt j` is column `j`'s evaluation point (`η_j = 7·ω_N^j`), `ev x vs` the
encodings of the clear vectors `vs` at a point (`colEncLag` at W16R2, `colEncCoef` at W16R3); `root`, `rows`,
`cmLogCols` the commitment. On acceptance, the transcript after the call. -/
def pcsVerify (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2) (root : Dig) (rows cmLogCols : ℕ)
    (claims : List ZClaim) (op : OpeningZk) (t : Tr) : Except PcsErr Tr :=
  if cmLogCols ≠ prm.logCols then .error .logCols
  else if prm.qPad < prm.nQ then .error .fewPads
  else match badPath (Nat.log2 prm.nn) op.columns with
  | some at_ => .error (.pathLen at_)
  | none =>
    let groups := groupZclaims claims rows prm.logCols
    if op.groupVecs.length ≠ groups.length then .error .nGroups
    else
      let r := zkRhosAux H rows groups t
      match groupCheck prm.n prm.qPad 0 (groups.map (·.1)) r.2.1 op.groupVecs with
      | some e => .error e
      | none =>
        let t1 := absorbVecs H op.groupVecs r.2.2
        if op.proxVec.length ≠ prm.n + prm.qPad then .error .proxLen
        else
          let t2 := t1.absorbFp2 H pcsProxLabel op.proxVec
          match t2.challengeIndices H prm.nQ prm.nn with
          | none => .error .indices
          | some (idx, t3) =>
            if op.columns.length ≠ idx.length then .error .nCols
            else match colsCheck H tag root rows r.1 (fun j => ev (pt j) (op.groupVecs ++ [op.proxVec]))
                op.columns idx with
              | some e => .error e
              | none => .ok t3

/-! ### The checks, one by one -/

theorem groupCheck_cons (n q g : ℕ) (cw : List Fp2) (cws : List (List Fp2)) (w : Fp2) (ws : List Fp2) (v : List Fp2)
    (vs : List (List Fp2)) :
    groupCheck n q g (cw :: cws) (w :: ws) (v :: vs)
      = if v.length ≠ n + q then some (.vecLen g)
        else if dotF (v.take n) cw ≠ w then some (.claim g)
        else groupCheck n q (g + 1) cws ws vs := rfl

theorem firstBad_cons (col : List Fp) (g : ℕ) (rho : List Fp2) (rhos : List (List Fp2)) (e : Fp2) (es : List Fp2) :
    firstBad col g (rho :: rhos) (e :: es) = if dotB rho col ≠ e then some g else firstBad col (g + 1) rhos es := rfl

theorem colsCheck_cons (root : Dig) (rows : ℕ) (rhos : List (List Fp2)) (evAt : ℕ → List Fp2) (j : ℕ)
    (col : List Fp) (salt : Dig) (path : List Dig) (cs : List OCol) (wj : ℕ) (ws : List ℕ) :
    colsCheck H tag root rows rhos evAt ((j, col, salt, path) :: cs) (wj :: ws)
      = if j ≠ wj then some (.colIndex j wj)
        else if col.length ≠ rows then some .colLen
        else if verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = false then some (.merkle j)
        else match firstBad col 0 rhos (evAt j) with
          | some g => some (.colVec j g)
          | none => colsCheck H tag root rows rhos evAt cs ws := rfl

theorem groupCheck_none_iff (n q : ℕ) : ∀ (g : ℕ) (cws : List (List Fp2)) (ws : List Fp2) (vs : List (List Fp2)),
    cws.length = vs.length → ws.length = vs.length →
    (groupCheck n q g cws ws vs = none
      ↔ ∀ i, i < vs.length → (vs.getD i []).length = n + q
          ∧ dotF ((vs.getD i []).take n) (cws.getD i []) = ws.getD i Fp2.zero)
  | g, [], [], [], _, _ => ⟨fun _ i hi => absurd hi (Nat.not_lt_zero _), fun _ => rfl⟩
  | g, cw :: cws, w :: ws, v :: vs, h1, h2 => by
    have ih := groupCheck_none_iff n q (g + 1) cws ws vs (by simpa using h1) (by simpa using h2)
    rw [groupCheck_cons]
    by_cases ha : v.length = n + q
    · by_cases hb : dotF (v.take n) cw = w
      · rw [ite_eq_right (not_not.mpr ha), ite_eq_right (not_not.mpr hb), ih]
        constructor
        · intro h i hi
          rcases i with _ | i
          · simpa using ⟨ha, hb⟩
          · simpa using h i (by simpa using hi)
        · intro h i hi
          simpa using h (i + 1) (by simpa using hi)
      · rw [ite_eq_right (not_not.mpr ha), ite_eq_left hb]
        simp only [reduceCtorEq, false_iff, not_forall]
        exact ⟨0, by simp, fun h => hb (by simpa using h.2)⟩
    · rw [ite_eq_left ha]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h => ha (by simpa using h.1)⟩
  | _, [], _ :: _, _, h1, h2 => by simp at h1 h2; omega
  | _, _ :: _, [], _, h1, h2 => by simp at h1 h2; omega
  | _, [], [], _ :: _, h1, _ => by simp at h1
  | _, _ :: _, _ :: _, [], h1, _ => by simp at h1

theorem firstBad_none_iff (col : List Fp) : ∀ (g : ℕ) (rhos : List (List Fp2)) (es : List Fp2),
    rhos.length = es.length →
    (firstBad col g rhos es = none ↔ ∀ i, i < rhos.length → dotB (rhos.getD i []) col = es.getD i Fp2.zero)
  | g, [], [], _ => ⟨fun _ i hi => absurd hi (Nat.not_lt_zero _), fun _ => rfl⟩
  | g, rho :: rhos, e :: es, h => by
    have ih := firstBad_none_iff col (g + 1) rhos es (by simpa using h)
    rw [firstBad_cons]
    by_cases ha : dotB rho col = e
    · rw [ite_eq_right (not_not.mpr ha), ih]
      constructor
      · intro hall i hi
        rcases i with _ | i
        · simpa using ha
        · simpa using hall i (by simpa using hi)
      · intro hall i hi
        simpa using hall (i + 1) (by simpa using hi)
    · rw [ite_eq_left ha]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h => ha (by simpa using h)⟩
  | _, [], _ :: _, h => by simp at h
  | _, _ :: _, [], h => by simp at h

/-- **One column's checks**, as the code runs them. -/
def ColOk (root : Dig) (rows : ℕ) (rhos : List (List Fp2)) (evAt : ℕ → List Fp2) (c : OCol) (wj : ℕ) : Prop :=
  c.1 = wj ∧ c.2.1.length = rows
    ∧ verifyPath H tag root c.1 (saltLeaf H tag (colDigest H tag c.2.1) c.2.2.1) c.2.2.2 = true
    ∧ ∀ g, g < rhos.length → dotB (rhos.getD g []) c.2.1 = (evAt c.1).getD g Fp2.zero

theorem colsCheck_none_iff (root : Dig) (rows : ℕ) (rhos : List (List Fp2)) (evAt : ℕ → List Fp2)
    (hev : ∀ j, (evAt j).length = rhos.length) :
    ∀ (cs : List OCol) (ws : List ℕ), cs.length = ws.length →
      (colsCheck H tag root rows rhos evAt cs ws = none
        ↔ ∀ k, k < cs.length → ColOk H tag root rows rhos evAt (cs.getD k (0, [], zeroDig, [])) (ws.getD k 0))
  | [], [], _ => ⟨fun _ k hk => absurd hk (Nat.not_lt_zero _), fun _ => rfl⟩
  | (j, col, salt, path) :: cs, wj :: ws, h => by
    have ih := colsCheck_none_iff root rows rhos evAt hev cs ws (by simpa using h)
    have hfb := firstBad_none_iff col 0 rhos (evAt j) (hev j).symm
    rw [colsCheck_cons]
    by_cases ha : j = wj
    · by_cases hb : col.length = rows
      · by_cases hc : verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = true
        · rw [ite_eq_right (not_not.mpr ha), ite_eq_right (not_not.mpr hb), ite_eq_right (by simp [hc])]
          cases hf : firstBad col 0 rhos (evAt j) with
          | some g =>
            simp only [reduceCtorEq, false_iff, not_forall]
            refine ⟨0, by simp, fun h0 => ?_⟩
            have := hfb.mpr (by simpa [ColOk] using h0.2.2.2)
            rw [hf] at this
            exact absurd this (by simp)
          | none =>
            simp only
            rw [ih]
            constructor
            · intro hall k hk
              rcases k with _ | k
              · simpa [ColOk] using ⟨ha, hb, hc, hfb.mp hf⟩
              · simpa using hall k (by simpa using hk)
            · intro hall k hk
              simpa using hall (k + 1) (by simpa using hk)
        · rw [ite_eq_right (not_not.mpr ha), ite_eq_right (not_not.mpr hb), ite_eq_left (by simpa using hc)]
          simp only [reduceCtorEq, false_iff, not_forall]
          exact ⟨0, by simp, fun h0 => hc (by simpa [ColOk] using h0.2.2.1)⟩
      · rw [ite_eq_right (not_not.mpr ha), ite_eq_left hb]
        simp only [reduceCtorEq, false_iff, not_forall]
        exact ⟨0, by simp, fun h0 => hb (by simpa [ColOk] using h0.2.1)⟩
    · rw [ite_eq_left ha]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => ha (by simpa [ColOk] using h0.1)⟩
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h

theorem badPath_none_iff (depth : ℕ) (cs : List OCol) :
    badPath depth cs = none ↔ ∀ c ∈ cs, c.2.2.2.length = depth := by
  unfold badPath
  rw [List.findIdx?_eq_none_iff]
  simp

/-- **Everything `pcs::verify_zk_tagged` checks**, given the transcript `t` before the call: the conjunction
`pcsVerify_ok_iff` proves equal to acceptance. `t'` is the transcript after the call. -/
def PcsOk (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2) (root : Dig) (rows cmLogCols : ℕ)
    (claims : List ZClaim) (op : OpeningZk) (t t' : Tr) : Prop :=
  cmLogCols = prm.logCols ∧ prm.nQ ≤ prm.qPad
    ∧ (∀ c ∈ op.columns, c.2.2.2.length = Nat.log2 prm.nn)
    ∧ op.groupVecs.length = (groupZclaims claims rows prm.logCols).length
    ∧ (∀ g, g < op.groupVecs.length → (op.groupVecs.getD g []).length = prm.n + prm.qPad
        ∧ dotF ((op.groupVecs.getD g []).take prm.n) (((groupZclaims claims rows prm.logCols).map (·.1)).getD g [])
          = (zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).2.1.getD g Fp2.zero)
    ∧ op.proxVec.length = prm.n + prm.qPad
    ∧ ∃ idx, ((absorbVecs H op.groupVecs (zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).2.2).absorbFp2
          H pcsProxLabel op.proxVec).challengeIndices H prm.nQ prm.nn = some (idx, t')
      ∧ op.columns.length = idx.length
      ∧ ∀ k, k < op.columns.length →
          ColOk H tag root rows (zkRhosAux H rows (groupZclaims claims rows prm.logCols) t).1
            (fun j => ev (pt j) (op.groupVecs ++ [op.proxVec])) (op.columns.getD k (0, [], zeroDig, [])) (idx.getD k 0)

/-- **The executable opening verifier accepts EXACTLY when every check holds** (for every hash function), for an
encoder that returns one value per clear vector. -/
theorem pcsVerify_ok_iff (prm : PcsPrm) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2)
    (hev : ∀ x vs, (ev x vs).length = vs.length) (root : Dig) (rows cmLogCols : ℕ) (claims : List ZClaim)
    (op : OpeningZk) (t t' : Tr) :
    pcsVerify H tag prm pt ev root rows cmLogCols claims op t = .ok t'
      ↔ PcsOk H tag prm pt ev root rows cmLogCols claims op t t' := by
  set groups := groupZclaims claims rows prm.logCols with hgroups
  set r := zkRhosAux H rows groups t with hr
  have hlen : r.1.length = groups.length + 1 ∧ r.2.1.length = groups.length := zkRhosAux_length H rows groups t
  unfold pcsVerify PcsOk
  rw [← hgroups, ← hr]
  by_cases h1 : cmLogCols = prm.logCols
  swap
  · simp [h1]
  rw [ite_eq_right (not_not.mpr h1)]
  by_cases h2 : prm.qPad < prm.nQ
  · simp [h2]
  rw [ite_eq_right h2]
  cases hp : badPath (Nat.log2 prm.nn) op.columns with
  | some at_ =>
    simp only [reduceCtorEq, false_iff, not_and]
    intro _ _ hall
    have := (badPath_none_iff _ _).mpr hall
    rw [hp] at this
    exact absurd this (by simp)
  | none =>
    have hpaths := (badPath_none_iff _ _).mp hp
    simp only
    by_cases h3 : op.groupVecs.length = groups.length
    swap
    · rw [ite_eq_left h3]
      simp only [reduceCtorEq, false_iff, not_and]
      intro _ _ _ h3'
      exact absurd h3' h3
    rw [ite_eq_right (not_not.mpr h3)]
    have hgc := groupCheck_none_iff prm.n prm.qPad 0 (groups.map (·.1)) r.2.1 op.groupVecs
      (by rw [List.length_map, h3]) (by rw [hlen.2, h3])
    cases hg : groupCheck prm.n prm.qPad 0 (groups.map (·.1)) r.2.1 op.groupVecs with
    | some e =>
      simp only [reduceCtorEq, false_iff, not_and]
      intro _ _ _ _ hall
      have := hgc.mpr hall
      rw [hg] at this
      exact absurd this (by simp)
    | none =>
      have hall := hgc.mp hg
      simp only
      by_cases h4 : op.proxVec.length = prm.n + prm.qPad
      swap
      · rw [ite_eq_left h4]
        simp only [reduceCtorEq, false_iff, not_and]
        intro _ _ _ _ _ h4'
        exact absurd h4' h4
      rw [ite_eq_right (not_not.mpr h4)]
      cases hi : ((absorbVecs H op.groupVecs r.2.2).absorbFp2 H pcsProxLabel op.proxVec).challengeIndices H
          prm.nQ prm.nn with
      | none =>
        simp only [reduceCtorEq, false_iff, not_and, not_exists]
        intro _ _ _ _ _ _ idx hidx
        exact absurd hidx (by simp)
      | some it =>
        obtain ⟨idx, t3⟩ := it
        simp only [Option.some.injEq, Prod.mk.injEq]
        by_cases h5 : op.columns.length = idx.length
        swap
        · rw [ite_eq_left h5]
          simp only [reduceCtorEq, false_iff, not_and, not_exists]
          intro _ _ _ _ _ _ idx' hidx h5'
          obtain ⟨rfl, -⟩ := hidx
          exact absurd h5' h5
        rw [ite_eq_right (not_not.mpr h5)]
        have hcc := colsCheck_none_iff H tag root rows r.1 (fun j => ev (pt j) (op.groupVecs ++ [op.proxVec]))
          (fun j => by rw [hev, List.length_append, h3, hlen.1]; rfl) op.columns idx h5
        cases hc : colsCheck H tag root rows r.1 (fun j => ev (pt j) (op.groupVecs ++ [op.proxVec])) op.columns idx with
        | some e =>
          simp only [reduceCtorEq, false_iff, not_and, not_exists]
          intro _ _ _ _ _ _ idx' hidx _ hall'
          obtain ⟨rfl, -⟩ := hidx
          have := hcc.mpr hall'
          rw [hc] at this
          exact absurd this (by simp)
        | none =>
          simp only [Except.ok.injEq]
          constructor
          · rintro rfl
            exact ⟨h1, not_lt.mp h2, hpaths, h3, hall, h4, idx, ⟨rfl, rfl⟩, h5, hcc.mp hc⟩
          · rintro ⟨-, -, -, -, -, -, idx', ⟨rfl, rfl⟩, -, -⟩
            rfl

end Verify

/-! ## The column check in the field -/

section ColK

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The specification of an encoder at a column** (`pt j` the column's point): one canonical value per clear vector,
the model's `encK` of the row form at the point, for every clear vector of `n + Q` entries. -/
def ColEncSpec {n : ℕ} (R : RowForm K n) (Q : ℕ) (pt : ℕ → Fp) (ev : Fp → List (List Fp2) → List Fp2) : Prop :=
  ∀ (j : ℕ) (vs : List (List Fp2)), (∀ v ∈ vs, v.length = n + Q) →
    (ev (pt j) vs).length = vs.length
      ∧ ∀ g, g < vs.length → ((ev (pt j) vs).getD g Fp2.zero).Canon
          ∧ ((ev (pt j) vs).getD g Fp2.zero).toK U = encK U R Q (vs.getD g []) (algebraMap GF K (pt j).toGF)

theorem mem_of_getD_lt {α : Type} (l : List α) (g : ℕ) (hg : g < l.length) (d : α) : l.getD g d ∈ l := by
  rw [getD_eq_get _ _ _ hg]
  exact List.getElem_mem _

/-- The code's coset points: `η_j = 7·ω_N^j`. -/
def cosetPt (ωN : Fp) (j : ℕ) : Fp := seven.mul (ωN.pow (UInt64.ofNat j))

/-- **W16R2's column evaluator meets the specification** at the coset points `η_j = 7·ω_N^j` (`n ∣ N = 2^k`,
`k ≤ 31`, `ω_N` of order `N`, `ω_n` of order `n`). -/
theorem colEncLag_spec {n Q N k : ℕ} (hn : 0 < n) (hn64 : n < 2 ^ 64) (hnN : n ∣ N) (hN : N = 2 ^ k) (hk : k ≤ 31)
    (ωF ωN : Fp) (hω : IsPrimitiveRoot ωF.toGF n) (hωN : IsPrimitiveRoot ωN.toGF N) :
    ColEncSpec U (lagForm hn (hω.map_of_injective (algebraMap GF K).injective)) Q (cosetPt ωN)
      (colEncLag ωF n Q) := by
  intro j vs hvs
  have hxn : (cosetPt ωN j).toGF ^ n ≠ 1 := by
    rw [cosetPt, Fp.toGF_mul, Fp.toGF_pow, seven_toGF]
    exact coset_pow_ne_one hnN hN hk hωN _
  refine ⟨by simp [colEncLag], fun g hg => ?_⟩
  simp only [colEncLag]
  rw [getD_map_lt' _ vs g hg []]
  refine ⟨Fp2.canon_add _ _, ?_⟩
  exact toK_encLag U hn hn64 ωF hω _ (Fp.mul_canon _ _) hxn _ (hvs _ (mem_of_getD_lt vs g hg []))

/-- **W16R3's column evaluator (B1) meets the specification** at any points. -/
theorem colEncCoef_spec {n Q : ℕ} (hn : 0 < n) (hn64 : n < 2 ^ 64) (pt : ℕ → Fp) :
    ColEncSpec U (coefForm (F := K) hn) Q pt (colEncCoef n Q) := by
  intro j vs hvs
  refine ⟨by simp [colEncCoef], fun g hg => ?_⟩
  simp only [colEncCoef]
  rw [getD_map_lt' _ vs g hg []]
  refine ⟨Fp2.canon_add _ _, ?_⟩
  exact toK_encCoef U hn hn64 _ _ (hvs _ (mem_of_getD_lt vs g hg []))

/-- **A column's word check is the field equation**: `Σ_i ρ_i·col_i = e` in `K`, for a combination and a column of
`rows` entries and a canonical `e` (`toK_injective`). -/
theorem colEq_iff_K (hU : U ^ 2 = algebraMap GF K 7) (rows : ℕ) (rho : List Fp2) (col : List Fp) (e : Fp2)
    (he : e.Canon) (hr : rho.length = rows) (hc : col.length = rows) :
    dotB rho col = e ↔ ∑ i : Fin rows, (rho.getD i Fp2.zero).toK U * algebraMap GF K (col.getD i Fp.zero).toGF
      = e.toK U := by
  rw [← toK_dotB U rho col rows hr hc]
  exact ⟨fun h => by rw [h], fun h => Fp2.toK_injective U hU (canon_dotB _ _) he h⟩

/-- **An accepted opening's columns, in the field.** Under `ColEncSpec` (every clear vector of `n + Q` entries) and
with the combinations of `rows` entries, every opened column `k` with point `η = pt (j_k)` satisfies, for every
combination `g` (the groups' `ρ_g`, then the proximity `ρ`): `Σ_i ρ_{g,i}·col_{k,i} = (encPoly form v_g[..n]
v_g[n..])(η)` in `K`: `SoundGroups.lean`'s column checks for the encoder `encPoly` (`encLin`). -/
theorem opening_columns_K (hU : U ^ 2 = algebraMap GF K 7) {n : ℕ} (R : RowForm K n) (Q : ℕ) (pt : ℕ → Fp)
    (ev : Fp → List (List Fp2) → List Fp2) (hspec : ColEncSpec U R Q pt ev) (rows : ℕ) (rhos : List (List Fp2))
    (vs : List (List Fp2)) (hvs : ∀ v ∈ vs, v.length = n + Q) (hrl : rhos.length = vs.length)
    (hrr : ∀ rho ∈ rhos, rho.length = rows) (H : HIn → Dig) (tag : MTag) (root : Dig) (c : OCol) (wj : ℕ)
    (hok : ColOk H tag root rows rhos (fun j => ev (pt j) vs) c wj) :
    ∀ g, g < vs.length →
      ∑ i : Fin rows, ((rhos.getD g []).getD i Fp2.zero).toK U * algebraMap GF K (c.2.1.getD i Fp.zero).toGF
        = encK U R Q (vs.getD g []) (algebraMap GF K (pt c.1).toGF) := by
  intro g hg
  obtain ⟨hl, hge⟩ := hspec c.1 vs hvs
  obtain ⟨hcan, hval⟩ := hge g hg
  rw [← hval]
  exact (colEq_iff_K U hU rows _ _ _ hcan (hrr _ (mem_of_getD_lt rhos g (by rw [hrl]; exact hg) [])) hok.2.1).mp
    (hok.2.2.2 g (by rw [hrl]; exact hg))

end ColK

/-! ## The W16R2 instance: the roots, the parameters, the check function -/

section W16R2Open

/-- **The two-adic root of order `2^k` as a word**: `7^((p − 1)/2^k)` (the code's `NttTables::roots[k]`; the corpus
checks the values for `k = 9, 12, 14, 15`). -/
def rootFp (k : ℕ) : Fp := seven.pow (UInt64.ofNat ((gP - 1) / 2 ^ k))

theorem rootFp_toGF {k : ℕ} (hk : k ≤ 32) : (rootFp k).toGF = rootGF k := by
  have hlt : (gP - 1) / 2 ^ k < 2 ^ 64 := by
    rw [gP_div_two_pow hk]
    calc 2 ^ (32 - k) * 4294967295 ≤ 2 ^ 32 * 4294967295 :=
          Nat.mul_le_mul_right _ (Nat.pow_le_pow_right (by norm_num) (by omega))
      _ < 2 ^ 64 := by norm_num
  rw [rootFp, Fp.toGF_pow, seven_toGF, UInt64.toNat_ofNat', Nat.mod_eq_of_lt hlt, rootGF]

theorem rootFp_isPrimitiveRoot {k : ℕ} (hk : k ≤ 32) : IsPrimitiveRoot (rootFp k).toGF (2 ^ k) := by
  rw [rootFp_toGF hk]
  exact rootGF_isPrimitiveRoot hk

/-- W16R2's regular-opening parameters (`log_cols 14`, rate `1/2`, `Q = q_pad = 280`; the endpoints' are the same). -/
def w16r2Prm : PcsPrm := ⟨14, 2, 280, 280⟩

/-- **W16R2's opening check** (`pcs::verify_zk_tagged` at W16R2): the executable verifier with the interpolant row form
evaluated at the coset `7·G_{2^15}`. Type: `(HIn → Dig) → MTag → Dig → ℕ → ℕ → List ZClaim → OpeningZk → Tr → Except
PcsErr Tr` (hash, tag keys, root, rows, the commitment's `log_cols`, claims, opening, transcript). -/
def w16r2OpenCheck (H : HIn → Dig) (tag : MTag) : Dig → ℕ → ℕ → List ZClaim → OpeningZk → Tr → Except PcsErr Tr :=
  pcsVerify H tag w16r2Prm (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280)

/-- **W16R3's opening check (B1, the instance swap)**: the same verifier with the coefficient row form. -/
def w16r3OpenCheck (H : HIn → Dig) (tag : MTag) : Dig → ℕ → ℕ → List ZClaim → OpeningZk → Tr → Except PcsErr Tr :=
  pcsVerify H tag w16r2Prm (cosetPt (rootFp 15)) (colEncCoef (2 ^ 14) 280)

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **W16R2's column evaluator meets the specification**, with the code's roots. -/
theorem w16r2_colEnc_spec :
    ColEncSpec U (lagForm (by norm_num) ((rootFp_isPrimitiveRoot (k := 14) (by norm_num)).map_of_injective
        (algebraMap GF K).injective)) 280 (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280) :=
  colEncLag_spec U (by norm_num) (by norm_num) (show 2 ^ 14 ∣ 2 ^ 15 from pow_dvd_pow 2 (by norm_num)) rfl
    (by norm_num) _ _ (rootFp_isPrimitiveRoot (by norm_num)) (rootFp_isPrimitiveRoot (by norm_num))

theorem w16r2_colEnc_length (x : Fp) (vs : List (List Fp2)) : (colEncLag (rootFp 14) (2 ^ 14) 280 x vs).length = vs.length := by
  simp [colEncLag]

/-- **W16R2's opening check accepts EXACTLY when every check holds** (`pcsVerify_ok_iff` at W16R2). -/
theorem w16r2OpenCheck_ok_iff (H : HIn → Dig) (tag : MTag) (root : Dig) (rows cmLogCols : ℕ) (claims : List ZClaim)
    (op : OpeningZk) (t t' : Tr) :
    w16r2OpenCheck H tag root rows cmLogCols claims op t = .ok t'
      ↔ PcsOk H tag w16r2Prm (cosetPt (rootFp 15)) (colEncLag (rootFp 14) (2 ^ 14) 280) root rows cmLogCols claims op
          t t' :=
  pcsVerify_ok_iff H tag w16r2Prm _ _ w16r2_colEnc_length root rows cmLogCols claims op t t'

end W16R2Open

end ZK60.Exec
