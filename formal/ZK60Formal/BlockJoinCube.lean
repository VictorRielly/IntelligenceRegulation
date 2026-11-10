/-
D63 lane L41 (2026-11-10), part 2: **the tables' extensions on the Boolean cube** (lane L35's "Not finished" item 1).

L35 defined each table's extension `tabK` at a point `x` of a slot's `n` main and `e` extension variables. The hosts'
named sums (lane L36's `hform`) read the slot polynomials on the whole Boolean cube. This file evaluates the tables
there:

* **`eq_mleAt_of_affAt`**: a function affine in each variable IS the multilinear extension of its cube values;
* **`cubeSum_split`**: a cube sum over `n + e` variables is a double sum over the main bits `b` and the extension
  bits `y`;
* `cpt n e b`: the cube point with main bits `b` and extension bits `0`; there `sel = 1` and every mask coefficient
  is `0` (**`selK_cpt`**, **`cmK_cpt`**), and off it (`y ≠ 0`) `sel = 0` (**`selK_off`**);
* `privZ`: a private table's claim functional at a point `z` without its mask parts; **`tabK_priv_sel`**: where
  `sel = 1` and the mask coefficient is `0`, a private table's extension IS `privZ` at its claim point;
* `planeZ`: **a private table's plane**, its claim functional at the Boolean points; **`privZ_mle`**: at ANY point
  `privZ` is the plane's multilinear extension (the claim functional is affine in each coordinate, L35's
  `affAt_privTab`);
* **`tabK_eq_cpt`**, **`tabK_pub_cpt`**, **`tabK_priv_cpt`**: at `cpt n e b` an `eq` table is `eq(point, bits)`, a
  public table is its entry `v[msbIndex b]`, a private table is its plane's extension at its claim point (the plane's
  entry where every coordinate is a bit); **`tabK_eq_off`**, **`tabK_pub_off`**: off the zero extension both are `0`;
* **`planeZ_base`**: a plane of base-field slices on a base-field matrix is a base-field value (`algebraMap`'s range,
  a subring).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineUnfold
import ZK60Formal.BlockJoinGF

set_option autoImplicit false

namespace ZK60.Exec.Block.Join

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Circuit (gP GF)
open Finset

/-! ## Multilinear uniqueness -/

section Mle

variable {K : Type} [Field K]

theorem bit_false : (bit false : K) = 0 := rfl

theorem bit_true : (bit true : K) = 1 := rfl

theorem bit_cons {n : ℕ} (bb : Bool) (b : Fin n → Bool) :
    (fun i => (bit ((Fin.cons bb b : Fin (n + 1) → Bool) i) : K)) = Fin.cons (bit bb) (fun i => bit (b i)) := by
  funext i
  refine Fin.cases ?_ (fun j => ?_) i
  · rfl
  · rfl

/-- **A function affine in every variable is the multilinear extension of its cube values.** -/
theorem eq_mleAt_of_affAt : ∀ (n : ℕ) (f : (Fin n → K) → K), (∀ i, AffAt i f) →
    ∀ z, f z = mleAt (fun b => f (fun i => bit (b i))) z
  | 0, f, _, z => by
    unfold mleAt
    rw [Fintype.sum_unique]
    have e1 : ∀ w : Fin 0 → K, eqPoly z w = 1 := fun w => Finset.prod_of_isEmpty _
    rw [e1, one_mul]
    congr 1
    funext i
    exact i.elim0
  | n + 1, f, hf, z => by
    have hz : z = Fin.cons (z 0) (Fin.tail z) := (Fin.cons_self_tail z).symm
    have hlin : ∀ (t : K) (τ : Fin n → K),
        f (Fin.cons t τ) = (1 - t) * f (Fin.cons 0 τ) + t * f (Fin.cons 1 τ) := by
      intro t τ
      obtain ⟨a, c, hac⟩ := hf 0 (Fin.cons t τ)
      have e : ∀ s : K, Function.update (Fin.cons t τ : Fin (n + 1) → K) 0 s = Fin.cons s τ := by
        intro s
        funext j
        refine Fin.cases ?_ (fun j => ?_) j
        · simp
        · simp [Function.update, Fin.succ_ne_zero]
      have h1 := hac t
      have h0 := hac 0
      have h1' := hac 1
      rw [e] at h1 h0 h1'
      rw [h1, h0, h1']
      ring
    have hg : ∀ s : K, ∀ i : Fin n, AffAt i (fun τ : Fin n → K => f (Fin.cons s τ)) := by
      intro s i τ
      obtain ⟨a, c, hac⟩ := hf i.succ (Fin.cons s τ)
      refine ⟨a, c, fun u => ?_⟩
      show f (Fin.cons s (Function.update τ i u)) = a + c * u
      rw [Fin.cons_update]
      exact hac u
    rw [hz, mleAt_cons, hlin]
    simp only [bit_cons, bit_false, bit_true]
    rw [← eq_mleAt_of_affAt n _ (hg 0), ← eq_mleAt_of_affAt n _ (hg 1)]

end Mle

/-! ## The cube, split into the main and the extension bits -/

section Split

variable {K : Type} [Field K]

/-- **A cube sum over `n + e` variables, split**: main bits `b`, then extension bits `y`. -/
theorem cubeSum_split (n e : ℕ) (f : (Fin (n + e) → K) → K) :
    cubeSum f = ∑ b : Fin n → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i)) := by
  unfold cubeSum
  rw [← Fintype.sum_prod_type']
  exact (Fintype.sum_equiv (Fin.appendEquiv n e) (fun p => f (fun i => bit (Fin.append p.1 p.2 i)))
    (fun w => f (fun i => bit (w i))) (fun _ => rfl)).symm

/-- **The cube point with main bits `b` and extension bits `y`.** -/
def bpt (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) : Fin (n + e) → K := fun i => bit (Fin.append b y i)

/-- **The cube point with main bits `b` and the extension bits `0`.** -/
def cpt (n e : ℕ) (b : Fin n → Bool) : Fin (n + e) → K := bpt n e b (fun _ => false)

theorem xg_bpt_lt (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) (q : ℕ) (hq : q < n) :
    xg (bpt (K := K) n e b y) q = bit (b ⟨q, hq⟩) := by
  unfold xg bpt
  rw [dite_eq_left (by omega)]
  have : (⟨q, by omega⟩ : Fin (n + e)) = Fin.castAdd e ⟨q, hq⟩ := rfl
  rw [this, Fin.append_left]

theorem xg_bpt_ext (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) (j : ℕ) (hj : j < e) :
    xg (bpt (K := K) n e b y) (n + j) = bit (y ⟨j, hj⟩) := by
  unfold xg bpt
  rw [dite_eq_left (by omega)]
  have : (⟨n + j, by omega⟩ : Fin (n + e)) = Fin.natAdd n ⟨j, hj⟩ := rfl
  rw [this, Fin.append_right]

theorem xg_ge (N : ℕ) (x : Fin N → K) (q : ℕ) (hq : N ≤ q) : xg x q = 0 := by
  unfold xg
  rw [dite_eq_right (by omega)]

/-- Main variable `k` of the cube point. -/
theorem xrK_bpt (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) (k : ℕ) :
    xrK n (bpt (K := K) n e b y) k = if h : k < n then bit (b ⟨k, h⟩) else 0 := by
  unfold xrK
  by_cases h : k < n
  · rw [ite_eq_left h, dite_eq_left h, xg_bpt_lt n e b y k h]
  · rw [ite_eq_right h, dite_eq_right h]

theorem yeK_bpt (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) (j : ℕ) :
    yeK n (bpt (K := K) n e b y) j = if h : j < e then bit (y ⟨j, h⟩) else 0 := by
  unfold yeK
  by_cases h : j < e
  · rw [dite_eq_left h, xg_bpt_ext n e b y j h]
  · rw [dite_eq_right h, xg_ge _ _ _ (by omega)]

/-- **`sel = 1` at the zero extension.** -/
theorem selK_cpt (n e : ℕ) (b : Fin n → Bool) : selK n e (cpt (K := K) n e b) = 1 := by
  unfold selK
  refine Finset.prod_eq_one (fun j hj => ?_)
  unfold cpt
  rw [yeK_bpt, dite_eq_left (Finset.mem_range.mp hj), bit_false, sub_zero]

/-- **Every mask coefficient is `0` at the zero extension.** -/
theorem cmK_cpt (n e : ℕ) (b : Fin n → Bool) (r : ℕ) : cmK n e (cpt (K := K) n e b) r = 0 := by
  unfold cmK cpt
  rw [yeK_bpt]
  by_cases h : r < e
  · rw [dite_eq_left h, bit_false, zero_mul]
  · rw [dite_eq_right h, zero_mul]

/-- **`sel = 0` off the zero extension.** -/
theorem selK_off (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool) (hy : y ≠ fun _ => false) :
    selK n e (bpt (K := K) n e b y) = 0 := by
  obtain ⟨j, hj⟩ : ∃ j, y j = true := by
    by_contra hc
    push Not at hc
    exact hy (funext fun j => by simpa using hc j)
  unfold selK
  refine Finset.prod_eq_zero (Finset.mem_range.mpr j.isLt) ?_
  rw [yeK_bpt, dite_eq_left j.isLt]
  have : (⟨(j : ℕ), j.isLt⟩ : Fin e) = j := rfl
  rw [this, hj, bit_true, sub_self]

theorem xrK_cpt (n e : ℕ) (b : Fin n → Bool) (k : ℕ) :
    xrK n (cpt (K := K) n e b) k = if h : k < n then bit (b ⟨k, h⟩) else 0 :=
  xrK_bpt n e b _ k

end Split

/-! ## A private table without its mask parts, and its plane -/

section Priv

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A private table's claim functional at a point `z`, without its mask parts**: its data slices, each with its
coefficient, on the matrix `X`. -/
def privZ (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (p : Priv) (z : ℕ → K) : K :=
  claimK logN R Q X (p.slices.map fun sc => (⟨sc.1, p.log, sc.2.toK U, z⟩ : PartK K))

omit [Algebra GF K] in
/-- The rows' weight reads the point only below the slice's log size. -/
theorem partRowK_congr (logN off ls : ℕ) (pt pt' : ℕ → K) (h : ∀ a, a < ls → pt a = pt' a) (i : ℕ) :
    partRowK logN off ls pt i = partRowK logN off ls pt' i := by
  unfold partRowK
  by_cases hl : logN ≤ ls
  · rw [ite_eq_left hl, ite_eq_left hl]
    by_cases hc : off / 2 ^ logN ≤ i ∧ i < off / 2 ^ logN + 2 ^ (ls - logN)
    · rw [ite_eq_left hc, ite_eq_left hc]
      congr 1
      funext a
      exact h a (by have := a.isLt; omega)
    · rw [ite_eq_right hc, ite_eq_right hc]
  · rw [ite_eq_right hl, ite_eq_right hl]

omit [Algebra GF K] in
/-- The columns' weight reads the point only below the slice's log size. -/
theorem keyColK_congr (logN off ls : ℕ) (pt pt' : ℕ → K) (h : ∀ a, a < ls → pt a = pt' a) (t : ℕ) :
    keyColK logN off ls pt t = keyColK logN off ls pt' t := by
  unfold keyColK
  by_cases hl : logN ≤ ls
  · rw [ite_eq_left hl, ite_eq_left hl]
    congr 1
    funext a
    exact h _ (by have := a.isLt; omega)
  · rw [ite_eq_right hl, ite_eq_right hl]
    by_cases hc : off % 2 ^ logN ≤ t ∧ t < off % 2 ^ logN + 2 ^ ls
    · rw [ite_eq_left hc, ite_eq_left hc]
      congr 1
      funext a
      exact h a a.isLt
    · rw [ite_eq_right hc, ite_eq_right hc]

/-- **`privZ` reads its point only below the table's log size.** -/
theorem privZ_congr (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (p : Priv) (z z' : ℕ → K)
    (h : ∀ a, a < p.log → z a = z' a) : privZ U logN R Q X p z = privZ U logN R Q X p z' := by
  unfold privZ
  cases hs : p.slices with
  | nil => rfl
  | cons sc0 rest =>
    simp only [List.map_cons, claimK]
    refine Finset.sum_congr rfl (fun i _ => ?_)
    congr 1
    · congr 1
      congr 1
      · rw [partRowK_congr logN sc0.1 p.log z z' h i]
      · rw [List.map_map, List.map_map]
        refine List.map_congr_left (fun sc _ => ?_)
        show sc.2.toK U * partRowK logN sc.1 p.log z i = sc.2.toK U * partRowK logN sc.1 p.log z' i
        rw [partRowK_congr logN sc.1 p.log z z' h i]
    · refine Finset.sum_congr rfl (fun t _ => ?_)
      show X i t * (if (t : ℕ) < 2 ^ logN then keyColK logN sc0.1 p.log z t else 0)
        = X i t * (if (t : ℕ) < 2 ^ logN then keyColK logN sc0.1 p.log z' t else 0)
      rw [keyColK_congr logN sc0.1 p.log z z' h t]

/-- **A private table's extension where `sel = 1` and its mask coefficient is `0`** is its claim functional without
the mask parts, at its claim point. -/
theorem tabK_priv_sel (P : BlockParams) (D : CmData K P) (n e : ℕ) {N : ℕ} (x : Fin N → K) (p : Priv)
    (hsl : p.slices ≠ []) (hsel : selK n e x = 1) (hcm : cmK n e x p.extRound = 0) :
    tabK U P D n e x (.priv p)
      = privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p (ptK U (xrK n x) p.coords) := by
  obtain ⟨sc0, rest, hs⟩ := List.exists_cons_of_ne_nil hsl
  have hspecs : privSpecs (N := N) U P n e p = dataSpec U n e p.log sc0 :: (rest.map (dataSpec U n e p.log)
      ++ [maskSpec n e (p.maskRow * 2 ^ rowLog P p.cm + privC0 P p) (min p.log (rowLog P p.cm))
            (p.log - min p.log (rowLog P p.cm)) p.extRound (Fp2.one.toK U),
          maskSpec n e ((p.maskRow + 1) * 2 ^ rowLog P p.cm + privC0 P p) (min p.log (rowLog P p.cm))
            (p.log - min p.log (rowLog P p.cm)) p.extRound (fp2U.toK U)]) := by
    unfold privSpecs
    rw [hs]
    rfl
  rw [tabK_priv, hspecs, claimK_specs]
  unfold privZ
  rw [hs]
  simp only [List.map_cons, claimK]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  congr 1
  · rw [List.map_append, List.sum_cons, List.sum_cons, List.sum_append]
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.map_map]
    simp only [dataSpec, maskSpec, hsel, hcm, mul_one, zero_mul, add_zero, Nat.zero_add]
    congr 1
    refine congrArg List.sum (List.map_congr_left (fun sc _ => ?_))
    simp only [Function.comp_apply, dataSpec, hsel, mul_one, Nat.zero_add]
  · refine Finset.sum_congr rfl (fun t _ => ?_)
    simp only [dataSpec, Nat.zero_add]

/-- **A private table's plane**: its claim functional at the Boolean points (`0` past its log size). -/
def planeZ (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (p : Priv) (c : Fin p.log → Bool) : K :=
  privZ U logN R Q X p (fun a => if h : a < p.log then bit (c ⟨a, h⟩) else 0)

/-- All of a table's coordinates are the main variables, in order. -/
def rhoAll (m : ℕ) : List Coord := (List.range m).map Coord.rho

theorem rhoAll_vars (m : ℕ) : varsOKb ((rhoAll m).map coordVar) = true := by
  unfold varsOKb rhoAll
  rw [List.map_map, List.length_map, List.length_range]
  refine List.all_eq_true.mpr (fun q hq => List.all_eq_true.mpr (fun q' hq' => ?_))
  have hq1 := List.mem_range.mp hq
  have hq2 := List.mem_range.mp hq'
  have e1 : ((List.range m).map (coordVar ∘ Coord.rho)).getD q none = some q := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hq1]
    rfl
  have e2 : ((List.range m).map (coordVar ∘ Coord.rho)).getD q' none = some q' := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_range hq2]
    rfl
  rw [e1, e2]
  by_cases h : q = q'
  · simp [h]
  · simp [h]

theorem ptK_rhoAll (m : ℕ) (xr : ℕ → K) (a : ℕ) : ptK U xr (rhoAll m) a = if a < m then xr a else 0 := by
  unfold ptK rhoAll
  rw [List.getElem?_map]
  by_cases h : a < m
  · rw [List.getElem?_range h, ite_eq_left h]
    rfl
  · rw [List.getElem?_eq_none (by rw [List.length_range]; omega), ite_eq_right h]
    rfl

/-- **The claim functional at any point is the plane's multilinear extension** (for a table of at least one slice
on a commitment of positive row log). -/
theorem privZ_mle (P : BlockParams) (D : CmData K P) (p : Priv) (hsl : p.slices ≠ []) (hlog : 0 < p.log)
    (hrl : 0 < rowLog P p.cm) (z : ℕ → K) :
    privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p z
      = mleAt (planeZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p) (fun a : Fin p.log => z a) := by
  set p' : Priv := { p with coords := rhoAll p.log } with hp'
  -- the claim functional as a function of the point's first `log` coordinates
  set f : (Fin p.log → K) → K := fun w => tabK U P D p.log 0 w (.priv p') with hf
  have hok : PrivOK P p' := ⟨hsl, hlog, by simp [hp', rhoAll], hrl, rhoAll_vars p.log⟩
  have haff : ∀ i, AffAt i f := fun i => affAt_privTab U P D p.log 0 p' hok i
  have hfz : ∀ w : Fin p.log → K, f w = privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p
      (fun a => if h : a < p.log then w ⟨a, h⟩ else 0) := by
    intro w
    have hsel : selK p.log 0 w = 1 := by simp [selK]
    have hcm : cmK p.log 0 w p'.extRound = 0 := by
      unfold cmK yeK
      rw [xg_ge _ _ _ (by omega), zero_mul]
    rw [hf]
    show tabK U P D p.log 0 w (.priv p') = _
    rw [tabK_priv_sel U P D p.log 0 w p' hsl hsel hcm]
    show privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p' (ptK U (xrK p.log w) (rhoAll p.log)) = _
    have e1 : privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p'
        = privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p := rfl
    rw [e1]
    refine privZ_congr U _ _ _ _ p _ _ (fun a ha => ?_)
    rw [ptK_rhoAll, ite_eq_left ha, dite_eq_left ha]
    unfold xrK xg
    rw [ite_eq_left ha, dite_eq_left ha]
  have h1 := eq_mleAt_of_affAt p.log f haff (fun a : Fin p.log => z a)
  rw [hfz] at h1
  have h2 : privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p z
      = privZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p
          (fun a => if h : a < p.log then (fun a : Fin p.log => z a) ⟨a, h⟩ else 0) :=
    privZ_congr U _ _ _ _ p _ _ (fun a ha => by rw [dite_eq_left ha])
  rw [h2, h1]
  congr 1
  funext c
  rw [hfz]
  rfl

end Priv

/-! ## The tables at the cube points -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **An `eq` table at the zero extension.** -/
theorem tabK_eq_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (point : List Fp2)
    (start : ℕ) :
    tabK U P D n e (cpt n e b) (.eq point start)
      = eqPoly (fun a : Fin point.length => (point.getD a Fp2.zero).toK U)
          (fun a : Fin point.length => xrK n (cpt (K := K) n e b) (start + a)) := by
  rw [tabK_eq, selK_cpt, one_mul]

/-- **An `eq` table off the zero extension is `0`.** -/
theorem tabK_eq_off (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) (point : List Fp2) (start : ℕ) :
    tabK U P D n e (bpt n e b y) (.eq point start) = 0 := by
  rw [tabK_eq, selK_off n e b y hy, zero_mul]

/-- **A public table at the zero extension is its entry.** -/
theorem tabK_pub_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (v : List Fp2) :
    tabK U P D n e (cpt n e b) (.pub v) = (v.getD (msbIndex n b) Fp2.zero).toK U := by
  rw [tabK_pub, selK_cpt, one_mul]
  have e1 : (fun a : Fin n => xrK n (cpt (K := K) n e b) a) = fun a => bit (b a) := by
    funext a
    rw [xrK_cpt, dite_eq_left a.isLt]
  rw [e1, mleAt_bit]

/-- **A public table off the zero extension is `0`.** -/
theorem tabK_pub_off (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (y : Fin e → Bool)
    (hy : y ≠ fun _ => false) (v : List Fp2) :
    tabK U P D n e (bpt n e b y) (.pub v) = 0 := by
  rw [tabK_pub, selK_off n e b y hy, zero_mul]

/-- **A private table at the zero extension is its plane's extension at its claim point.** -/
theorem tabK_priv_cpt (P : BlockParams) (D : CmData K P) (n e : ℕ) (b : Fin n → Bool) (p : Priv)
    (hsl : p.slices ≠ []) (hlog : 0 < p.log) (hrl : 0 < rowLog P p.cm) :
    tabK U P D n e (cpt n e b) (.priv p)
      = mleAt (planeZ U (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm) p)
          (fun a : Fin p.log => ptK U (xrK n (cpt (K := K) n e b)) p.coords a) := by
  rw [tabK_priv_sel U P D n e _ p hsl (selK_cpt n e b) (cmK_cpt n e b _), privZ_mle U P D p hsl hlog hrl]

end Cube

/-! ## Base-field values -/

section Base

variable {K : Type} [Field K] [Algebra GF K]

/-- The base field's image in `K`. -/
abbrev baseR (K : Type) [Field K] [Algebra GF K] : Subring K := (algebraMap GF K).range

theorem bit_mem (b : Bool) : (bit b : K) ∈ baseR K := by
  cases b
  · exact (baseR K).zero_mem
  · exact (baseR K).one_mem

theorem eqPoly_mem {n : ℕ} (τ x : Fin n → K) (hτ : ∀ i, τ i ∈ baseR K) (hx : ∀ i, x i ∈ baseR K) :
    eqPoly τ x ∈ baseR K := by
  unfold eqPoly
  refine Subring.prod_mem _ (fun i _ => ?_)
  exact (baseR K).add_mem ((baseR K).mul_mem (hτ i) (hx i))
    ((baseR K).mul_mem ((baseR K).sub_mem (baseR K).one_mem (hτ i)) ((baseR K).sub_mem (baseR K).one_mem (hx i)))

theorem bitsK_mem (m idx : ℕ) (j : Fin m) : bitsK (K := K) m idx j ∈ baseR K := bit_mem _

theorem partRowK_mem (logN off ls : ℕ) (pt : ℕ → K) (hpt : ∀ a, pt a ∈ baseR K) (i : ℕ) :
    partRowK logN off ls pt i ∈ baseR K := by
  unfold partRowK
  split_ifs
  · exact eqPoly_mem _ _ (fun a => hpt a) (fun j => bitsK_mem _ _ j)
  · exact (baseR K).zero_mem
  · exact (baseR K).one_mem
  · exact (baseR K).zero_mem

theorem keyColK_mem (logN off ls : ℕ) (pt : ℕ → K) (hpt : ∀ a, pt a ∈ baseR K) (t : ℕ) :
    keyColK logN off ls pt t ∈ baseR K := by
  unfold keyColK
  split_ifs
  · exact eqPoly_mem _ _ (fun a => hpt _) (fun j => bitsK_mem _ _ j)
  · exact eqPoly_mem _ _ (fun a => hpt a) (fun j => bitsK_mem _ _ j)
  · exact (baseR K).zero_mem

theorem claimK_mem (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (hX : ∀ i t, X i t ∈ baseR K)
    (ps : List (PartK K)) (hps : ∀ b ∈ ps, b.coef ∈ baseR K ∧ ∀ a, b.pt a ∈ baseR K) :
    claimK logN R Q X ps ∈ baseR K := by
  cases ps with
  | nil => exact (baseR K).zero_mem
  | cons b0 bs =>
    unfold claimK
    refine Subring.sum_mem _ (fun i _ => (baseR K).mul_mem ?_ ?_)
    · refine Subring.list_sum_mem _ (fun y hy => ?_)
      obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hy
      exact (baseR K).mul_mem (hps b hb).1 (partRowK_mem _ _ _ _ (hps b hb).2 _)
    · refine Subring.sum_mem _ (fun t _ => (baseR K).mul_mem (hX i t) ?_)
      split_ifs
      · exact keyColK_mem _ _ _ _ (hps b0 List.mem_cons_self).2 _
      · exact (baseR K).zero_mem

/-- **A plane of base-field slices on a base-field matrix is a base-field value.** -/
theorem planeZ_base (U : K) (logN R Q : ℕ) (X : Fin R → Fin (2 ^ logN + Q) → K) (hX : ∀ i t, X i t ∈ baseR K)
    (p : Priv) (hc : ∀ sc ∈ p.slices, sc.2.toK U ∈ baseR K) (c : Fin p.log → Bool) :
    planeZ U logN R Q X p c ∈ baseR K := by
  unfold planeZ privZ
  refine claimK_mem logN R Q X hX _ (fun b hb => ?_)
  obtain ⟨sc, hsc, rfl⟩ := List.mem_map.mp hb
  refine ⟨hc sc hsc, fun a => ?_⟩
  show (if h : a < p.log then bit (c ⟨a, h⟩) else 0) ∈ baseR K
  split_ifs
  · exact bit_mem _
  · exact (baseR K).zero_mem

end Base

end ZK60.Exec.Block.Join
