/-
D63 lane L49 (2026-11-10), sub-agent `szc`, part 4: **the tables of `SC_SZC`, `SC_RS` and `SC_SCORE` at the cube
points, and the cube sums of `SC_RS` and `SC_SCORE`**, generic in the configuration (no geometry fact beyond the
hypotheses named).

* `numTabs_cpt`: numbering a slot's private tables (the reserved rows) changes no table's value at the zero extension;
* `hdB`, `restTR`, **`szcR_vals`**: `SC_SZC`'s value list at a cube point with the zero extension (the three `eq`
  entries, the mask, the `11 + 2·ls` `Dom::S` planes, `MX`, `SUM` on the first `Dom::Ht` variables, the `7 + ls`
  LogUp helpers, the exp helper); `vR_pl`, `vR_mx`, `vR_sum`, `vR_L256`: its entries;
* `L256_range'`: byte limbs over a run of positions;
* `appendV`, `ptK_app`, `ptK_fix`, `ptK_rho`, `ptQR`, `ptKR`: `SC_SCORE`'s claim points, coordinate by coordinate;
  `mleAt_qrG`, `mleAt_krG`: the extensions at points made of blocks;
* **`rs_cubeR`**: `SC_RS`'s cube sum `(Σ_j mask·E)~(p_ht) + λ·(Σ_j ZSEL)~(p_ht)`;
* **`score_cubeR`**: `SC_SCORE`'s cube sum `Σ_g Σ_c eq(r_g, g)·Q̃R(r_t, g, r_hj, c)·K̃R(r_3, g, c)`;
* `batchR`, `lksSR_eval`, `lksSR_pos`, `expR_cons3`, `basePow`, `baseNegPow`: the batch's pieces.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockR13HostSzcProg
import ZK60Formal.BlockHostSzc
import ZK60Formal.BlockAlgKinds

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.R13H.Szc

open ZK60.Sound
open ZK60.Sound.SlotW16 (mle2 mleAt_append rs_cubeSum eqPoly_append)
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16 (aPl cstK cstK_p256 tabK_pa_cpt tabK_paHead_cpt eqT_eval pubT_eval hPl hTab_eval
  tabK_ph_cpt cstS_map sum_append mleAt_append_bits)
open ZK60.Exec.Block.DefW16 (W16Cfg)
open ZK60.Exec.Slot.Build (Cst cstW gV L256 LkD rsIr rsIr_eval bilIr bilIr_eval)
open ZK60.Exec.Slot.Compose (cstW_map_std rsIr_map bilIr_map)
open ZK60.Exec.Slot (irEval)
open ZK60.Circuit (gP GF)
open Finset

/-! ## Numbering the private tables -/

section Num

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **Numbering a list of private tables keeps their values at the zero extension** (the numbering sets the reserved
mask rows only, which a table's value on the cube never reads). -/
theorem numTabs_cpt (P : BlockParams) (D : CmData K P) (aB hB ioIn ioOut n e : ℕ) (b : Fin n → Bool)
    (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    ∀ (ts : List TabS) (ak hk pk : ℕ), (∀ t ∈ ts, ∃ p : PrivS, t = .priv p ∧ p.slices ≠ []) →
      ((DefW16.numTabs aB hB ioIn ioOut ak hk pk ts).map (TabS.eval ev pub)).map (tabK U P D n e (cpt n e b))
        = (ts.map (TabS.eval ev pub)).map (tabK U P D n e (cpt n e b))
  | [], _, _, _, _ => rfl
  | t :: ts, ak, hk, pk, h => by
    obtain ⟨p, rfl, hp⟩ := h t (by simp)
    have ih := numTabs_cpt P D aB hB ioIn ioOut n e b ev pub ts (ak + (if p.cm = Cm.a then 1 else 0))
      (hk + (if p.cm = Cm.h then 1 else 0)) pk (fun t' ht' => h t' (by simp [ht']))
    simp only [DefW16.numTabs, List.map_cons]
    rw [ih]
    congr 1
    have hs : (p.eval ev).slices ≠ [] := by simpa [PrivS.eval] using hp
    show tabK U P D n e (cpt n e b) (.priv ((DefW16.setRow aB hB ioIn ioOut ak hk p).eval ev))
      = tabK U P D n e (cpt n e b) (.priv (p.eval ev))
    rw [tabK_priv_sel U P D n e _ ((DefW16.setRow aB hB ioIn ioOut ak hk p).eval ev) hs (selK_cpt n e b)
        (cmK_cpt n e b _),
      tabK_priv_sel U P D n e _ (p.eval ev) hs (selK_cpt n e b) (cmK_cpt n e b _)]
    rfl

/-- `SC_SZC`'s private tables are private, each of one slice at least. -/
theorem tail_priv (c : W16Cfg) (ls : ℕ) : ∀ t ∈ tabs17Tail c ls, ∃ p : PrivS, t = .priv p ∧ p.slices ≠ [] := by
  intro t ht
  unfold tabs17Tail at ht
  rw [List.mem_append, List.mem_append, List.mem_append] at ht
  rcases ht with ((h | h) | h) | h
  · obtain ⟨i, -, rfl⟩ := List.mem_map.mp h
    exact ⟨_, rfl, List.cons_ne_nil _ _⟩
  · simp only [List.mem_cons, List.not_mem_nil, or_false] at h
    rcases h with rfl | rfl <;> exact ⟨_, rfl, List.cons_ne_nil _ _⟩
  · obtain ⟨j, -, rfl⟩ := List.mem_map.mp h
    exact ⟨_, rfl, List.cons_ne_nil _ _⟩
  · rw [List.mem_singleton] at h
    subst h
    exact ⟨_, rfl, List.cons_ne_nil _ _⟩

/-- Two `Dom::S` planes are private tables of one slice. -/
theorem pair_priv (c : W16Cfg) (q q' : ℕ) : ∀ t ∈ [tS c q, tS c q'], ∃ p : PrivS, t = .priv p ∧ p.slices ≠ [] := by
  intro t ht
  simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
  rcases ht with rfl | rfl <;> exact ⟨_, rfl, List.cons_ne_nil _ _⟩

/-- `SC_SCORE`'s two private tables. -/
theorem score_priv (c : W16Cfg) : ∀ t ∈ [tQR c, tKR c], ∃ p : PrivS, t = .priv p ∧ p.slices ≠ [] := by
  intro t ht
  simp only [List.mem_cons, List.not_mem_nil, or_false] at ht
  rcases ht with rfl | rfl <;> exact ⟨_, rfl, List.cons_ne_nil _ _⟩

end Num

/-! ## Planes and draws -/

section Planes

variable {K : Type} [Field K] [Algebra GF K] (U : K) (P : BlockParams) (D : CmData K P)

/-- A plane read through an equality of lengths. -/
theorem aPl_castB {m n : ℕ} (h : m = n) (off : ℕ) (b : Fin m → Bool) :
    aPl U P D off n (castB h b) = aPl U P D off m b := by
  subst h
  rfl

/-- A plane read at two bit vectors equal index by index. -/
theorem aPl_ext {m n : ℕ} (h : m = n) (off : ℕ) (f : Fin m → Bool) (g : Fin n → Bool)
    (hfg : ∀ i : Fin m, f i = g (Fin.cast h i)) : aPl U P D off m f = aPl U P D off n g := by
  subst h
  congr 1
  funext i
  exact hfg i

/-- The extension of a plane at a point, through an equality of lengths. -/
theorem mleAt_aPl_cast {m n : ℕ} (h : m = n) (off : ℕ) (pf : ℕ → K) :
    mleAt (fun z : Fin m → Bool => aPl U P D off m z) (fun a : Fin m => pf a)
      = mleAt (fun z : Fin n → Bool => aPl U P D off m (castB h.symm z)) (fun t : Fin n => pf t) := by
  subst h
  rfl

omit [Field K] [Algebra GF K] in
theorem drsR_len (s a n : ℕ) : (drsR s a n).length = n := by simp [drsR]

omit [Field K] [Algebra GF K] in
theorem drsR_map_len (ev : Sym → Fp2) (s a n : ℕ) : ((drsR s a n).map ev).length = n := by simp [drsR]

theorem drsR_getD (ev : Sym → Fp2) (s a n i : ℕ) (hi : i < n) :
    ((drsR s a n).map ev).getD i Fp2.zero = ev (.dr s (a + i)) :=
  W16.Szc.drs_getD ev s a n i hi

theorem drsR_ptv (ev : Sym → Fp2) (s a n : ℕ) :
    (fun i : Fin n => (((drsR s a n).map ev).getD i Fp2.zero).toK U) = W16.Szc.ptv U ev s a n :=
  W16.Szc.drs_ptv U ev s a n

theorem drsRK_getD (ev : Sym → Fp2) (s a n i : ℕ) (hi : i < n) :
    (((drsR s a n).map ev).map (Fp2.toK U)).getD i 0 = (ev (.dr s (a + i))).toK U :=
  W16.Szc.drsK_getD U ev s a n i hi

end Planes

/-! ## The value list of `SC_SZC` at a cube point -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- The first `m` bits of a bit vector (`false` past its end). -/
def hdB {n : ℕ} (m : ℕ) (b : Fin n → Bool) : Fin m → Bool := fun a => if h : (a : ℕ) < n then b ⟨a, h⟩ else false

omit [Field K] [Algebra GF K] in
theorem hdB_eq {n m : ℕ} (hm : m ≤ n) (b : Fin n → Bool) :
    hdB m b = fun a : Fin m => b ⟨a, by have := a.isLt; omega⟩ := by
  funext a
  unfold hdB
  rw [dite_eq_left (by have := a.isLt; omega)]

omit [Field K] [Algebra GF K] in
/-- A value of an appended vector, by its index. -/
theorem appendV {α : Type} {m n : ℕ} (r : Fin m → α) (s : Fin n → α) (k : Fin (m + n)) :
    Fin.append r s k = if h : (k : ℕ) < m then r ⟨k, h⟩ else s ⟨k - m, by omega⟩ := by
  refine Fin.addCases (fun a => ?_) (fun a => ?_) k
  · rw [Fin.append_left, dite_eq_left (by simp)]
    rfl
  · rw [Fin.append_right, dite_eq_right (by simp)]
    congr 1
    ext
    simp

omit [Field K] [Algebra GF K] in
/-- The first bits of a cube point made of a row and a column are the row. -/
theorem hdB_castB_append {m n N : ℕ} (h : m + n = N) (r : Fin m → Bool) (j : Fin n → Bool) :
    hdB m (castB h (Fin.append r j)) = r := by
  funext a
  unfold hdB castB
  rw [dite_eq_left (by have := a.isLt; omega), appendV, dite_eq_left (by simp)]
  rfl

/-- **`SC_SZC`'s entries from position `4` on**: the `11 + 2·ls` `Dom::S` planes (ids `75 …`), `MX`, `SUM`, the
`7 + ls` LogUp helpers, the exp helper. -/
noncomputable def restTR (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P) (b : Fin (c.sh.logs .S) → Bool) :
    List K :=
  (List.range (11 + 2 * ls)).map (fun i => aPl U P D (DefR13.aOff c (75 + i)) (c.sh.logs .S) b)
    ++ (aPl U P D (DefR13.aOff c 4) (c.sh.logs .Ht) (hdB _ b) :: aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b)
      :: ((List.range (7 + ls)).map (fun j => hPl U P D (DefR13.hOff c (DefR13.fh c 4 + j)).1
          (DefR13.hOff c (DefR13.fh c 4 + j)).2 (c.sh.logs .S) b)
        ++ [hPl U P D (DefR13.hOff c (DefR13.fh c 5)).1 (DefR13.hOff c (DefR13.fh c 5)).2 (c.sh.logs .S) b]))

/-- A `Dom::S` plane at a cube point of `Dom::S`. -/
theorem tS_cpt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (hlS : 0 < c.sh.logs .S)
    (e : ℕ) (b : Fin (c.sh.logs .S) → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (q : ℕ) :
    tabK U P D (c.sh.logs .S) e (cpt (c.sh.logs .S) e b) (TabS.eval ev pub (tS c q))
      = aPl U P D (DefR13.aOff c q) (c.sh.logs .S) b := by
  show tabK U P D _ e (cpt _ e b) (TabS.eval ev pub (.priv ⟨.a, [(DefR13.aOff c q, false)], c.sh.logs .S,
    DefW16.rhoC 0 (c.sh.logs .S), 0, 0⟩)) = _
  rw [aTab_eval, tabK_pa_cpt U P D hrl _ e b _ hlS rfl]
  rfl

/-- A `Dom::Ht` plane at a cube point of `Dom::S`, on its first variables. -/
theorem tHt_cpt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (hlH : 0 < c.sh.logs .Ht)
    (hHS : c.sh.logs .Ht ≤ c.sh.logs .S) (e : ℕ) (b : Fin (c.sh.logs .S) → Bool) (ev : Sym → Fp2)
    (pub : ℕ → List Fp2) (q : ℕ) :
    tabK U P D (c.sh.logs .S) e (cpt (c.sh.logs .S) e b) (TabS.eval ev pub (tHt c q))
      = aPl U P D (DefR13.aOff c q) (c.sh.logs .Ht) (hdB _ b) := by
  show tabK U P D _ e (cpt _ e b) (TabS.eval ev pub (.priv ⟨.a, [(DefR13.aOff c q, false)], c.sh.logs .Ht,
    DefW16.rhoC 0 (c.sh.logs .Ht), 0, 0⟩)) = _
  rw [aTab_eval, tabK_paHead_cpt U P D hrl _ e b _ hlH hHS, hdB_eq hHS]

/-- An `H` plane on `Dom::S` at a cube point of `Dom::S`. -/
theorem tHS_cpt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (hlS : 0 < c.sh.logs .S)
    (e : ℕ) (b : Fin (c.sh.logs .S) → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) (hp : ℕ) :
    tabK U P D (c.sh.logs .S) e (cpt (c.sh.logs .S) e b) (TabS.eval ev pub (tHS c hp))
      = hPl U P D (DefR13.hOff c hp).1 (DefR13.hOff c hp).2 (c.sh.logs .S) b := by
  show tabK U P D _ e (cpt _ e b) (TabS.eval ev pub (.priv ⟨.h, [((DefR13.hOff c hp).1, false),
    ((DefR13.hOff c hp).2, true)], c.sh.logs .S, DefW16.rhoC 0 (c.sh.logs .S), 0, 0⟩)) = _
  rw [hTab_eval, tabK_ph_cpt U P D hrl _ e b _ hlS rfl]
  rfl

/-- **`SC_SZC`'s value list at a cube point with the zero extension**, for any claim sites of the numbering. -/
theorem szcR_vals (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hlS : 0 < c.sh.logs .S) (hlH : 0 < c.sh.logs .Ht) (hHS : c.sh.logs .Ht ≤ c.sh.logs .S)
    (aB hB ioIn ioOut ak hk e : ℕ) (b : Fin (c.sh.logs .S) → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    ((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (tabs17R c ls)).map (TabS.eval ev pub)).map
        (tabK U P D (c.sh.logs .S) e (cpt (c.sh.logs .S) e b))
      = eqPoly (fun a : Fin (c.sh.logs .S) => (((drsR 17 0 (c.sh.logs .S)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: eqPoly (fun a : Fin (c.sh.logs .Ht) => (((drsR 4 0 (c.sh.logs .Ht)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (hdB _ b a))
        :: eqPoly (fun a : Fin (c.sh.logs .S) => (((drsR 8 0 (c.sh.logs .S)).map ev).getD a Fp2.zero).toK U)
            (fun a => bit (b a))
        :: ((pub 0).getD (msbIndex (c.sh.logs .S) b) Fp2.zero).toK U :: restTR U c ls P D b := by
  unfold tabs17R
  simp only [List.cons_append, List.nil_append, DefW16.numTabs, List.map_cons]
  rw [numTabs_cpt U P D aB hB ioIn ioOut _ e b ev pub (tabs17Tail c ls) _ _ _ (tail_priv c ls)]
  simp only [eqT_eval, pubT_eval]
  rw [tabK_eqFull_cpt U P D _ e b _ (drsR_map_len ev 17 0 _),
    tabK_eqHead_cpt U P D _ e b _ _ (drsR_map_len ev 4 0 _) hHS,
    tabK_eqFull_cpt U P D _ e b _ (drsR_map_len ev 8 0 _), tabK_pub_cpt, hdB_eq hHS]
  unfold tabs17Tail restTR
  simp only [List.map_append, List.map_map, List.map_cons, List.map_nil, Function.comp_def,
    tS_cpt U c P D hrl hlS e b ev pub, tHt_cpt U c P D hrl hlH hHS e b ev pub, tHS_cpt U c P D hrl hlS e b ev pub,
    List.append_assoc, List.cons_append, List.nil_append, hdB_eq hHS]

/-- The mask entry. -/
theorem vR_mk (e0 e1 e2 mk : K) (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P)
    (b : Fin (c.sh.logs .S) → Bool) : (e0 :: e1 :: e2 :: mk :: restTR U c ls P D b).getD 3 0 = mk := rfl

/-- **A `Dom::S` plane's entry**: position `4 + i` is plane `75 + i`. -/
theorem vR_pl (e0 e1 e2 mk : K) (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P)
    (b : Fin (c.sh.logs .S) → Bool) (i : ℕ) (hi : i < 11 + 2 * ls) :
    (e0 :: e1 :: e2 :: mk :: restTR U c ls P D b).getD (4 + i) 0
      = aPl U P D (DefR13.aOff c (75 + i)) (c.sh.logs .S) b := by
  rw [show 4 + i = i + 1 + 1 + 1 + 1 by omega, List.getD_cons_succ, List.getD_cons_succ, List.getD_cons_succ,
    List.getD_cons_succ]
  unfold restTR
  rw [List.getD_eq_getElem?_getD, List.getElem?_append_left (by rw [List.length_map, List.length_range]; exact hi),
    List.getElem?_map, List.getElem?_range hi]
  rfl

/-- `MX`'s entry, at position `15 + 2·ls`. -/
theorem vR_mx (e0 e1 e2 mk : K) (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P)
    (b : Fin (c.sh.logs .S) → Bool) :
    (e0 :: e1 :: e2 :: mk :: restTR U c ls P D b).getD (15 + 2 * ls) 0
      = aPl U P D (DefR13.aOff c 4) (c.sh.logs .Ht) (hdB _ b) := by
  rw [show 15 + 2 * ls = 11 + 2 * ls + 1 + 1 + 1 + 1 by omega, List.getD_cons_succ, List.getD_cons_succ,
    List.getD_cons_succ, List.getD_cons_succ]
  unfold restTR
  rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by rw [List.length_map, List.length_range]),
    List.length_map, List.length_range, Nat.sub_self]
  rfl

/-- `SUM`'s entry, at position `16 + 2·ls`. -/
theorem vR_sum (e0 e1 e2 mk : K) (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P)
    (b : Fin (c.sh.logs .S) → Bool) :
    (e0 :: e1 :: e2 :: mk :: restTR U c ls P D b).getD (16 + 2 * ls) 0
      = aPl U P D (DefR13.aOff c 5) (c.sh.logs .Ht) (hdB _ b) := by
  rw [show 16 + 2 * ls = 11 + 2 * ls + 1 + 1 + 1 + 1 + 1 by omega, List.getD_cons_succ, List.getD_cons_succ,
    List.getD_cons_succ, List.getD_cons_succ]
  unfold restTR
  rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (by rw [List.length_map, List.length_range]; omega),
    List.length_map, List.length_range, show 11 + 2 * ls + 1 - (11 + 2 * ls) = 1 by omega]
  rfl

end Vals

/-! ## Byte limbs over a run of positions -/

section Limbs

variable {R : Type} [CommRing R]

theorem L256_gen (cs : Cst R) (v : List R) : ∀ (m s j : ℕ),
    (((List.range' s m).zipIdx j).map fun q => cs.p256 q.2 * v.getD q.1 0).sum
      = ∑ k : Fin m, cs.p256 (j + k) * v.getD (s + k) 0
  | 0, s, j => by simp
  | m + 1, s, j => by
    rw [List.range'_succ, List.zipIdx_cons, List.map_cons, List.sum_cons, L256_gen cs v m (s + 1) (j + 1),
      Fin.sum_univ_succ]
    simp only [Fin.val_zero, Nat.add_zero, Fin.val_succ]
    congr 1
    refine Finset.sum_congr rfl (fun k _ => ?_)
    rw [show j + 1 + (k : ℕ) = j + ((k : ℕ) + 1) by omega, show s + 1 + (k : ℕ) = s + ((k : ℕ) + 1) by omega]

/-- **Byte limbs over a run of positions** `Σ_k 256^k·v_{s+k}` (the builders' `limbs_node` on `s, s + 1, …`). -/
theorem L256_range' (cs : Cst R) (v : List R) (s m : ℕ) :
    L256 cs v (List.range' s m) = ∑ k : Fin m, cs.p256 k * v.getD (s + k) 0 := by
  unfold L256
  rw [L256_gen cs v m s 0]
  simp only [Nat.zero_add]

end Limbs

section LimbsK

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A run of `Dom::S` plane entries as byte limbs**: positions `s … s + m − 1` (planes `o …`). -/
theorem vR_L256 (e0 e1 e2 mk : K) (c : W16Cfg) (ls : ℕ) (P : BlockParams) (D : CmData K P)
    (b : Fin (c.sh.logs .S) → Bool) (s m o : ℕ) (hs : 4 ≤ s) (hsm : s + m ≤ 15 + 2 * ls) (ho : o + 4 = 75 + s)
    (hm : m ≤ 8) :
    L256 (cstK U) (e0 :: e1 :: e2 :: mk :: restTR U c ls P D b) (List.range' s m)
      = ∑ k : Fin m, (256 : K) ^ (k : ℕ) * aPl U P D (DefR13.aOff c (o + k)) (c.sh.logs .S) b := by
  rw [L256_range']
  refine Finset.sum_congr rfl (fun k _ => ?_)
  have hk := k.isLt
  rw [cstK_p256 U k (by omega)]
  congr 1
  have h := vR_pl U e0 e1 e2 mk c ls P D b (s - 4 + k) (by omega)
  rw [show 4 + (s - 4 + (k : ℕ)) = s + k by omega, show 75 + (s - 4 + (k : ℕ)) = o + k by omega] at h
  exact h

end LimbsK

/-! ## `SC_SCORE`'s claim points, coordinate by coordinate -/

section Pts

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- `ptK` on two appended coordinate lists. -/
theorem ptK_app (xr : ℕ → K) (cs1 cs2 : List Coord) (i : ℕ) :
    ptK U xr (cs1 ++ cs2) i = if i < cs1.length then ptK U xr cs1 i else ptK U xr cs2 (i - cs1.length) := by
  unfold ptK
  by_cases h : i < cs1.length
  · rw [ite_eq_left h, List.getElem?_append_left h]
  · rw [ite_eq_right h, List.getElem?_append_right (by omega)]

theorem ptK_fix (xr : ℕ → K) (vs : List Fp2) (i : ℕ) (hi : i < vs.length) :
    ptK U xr (vs.map Coord.fixed) i = (vs.getD i Fp2.zero).toK U := by
  unfold ptK
  rw [List.getElem?_map, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi]
  rfl

theorem ptK_rho (xr : ℕ → K) (a m i : ℕ) (hi : i < m) :
    ptK U xr ((List.range' a m).map Coord.rho) i = xr (a + i) := by
  unfold ptK
  rw [List.getElem?_map, List.getElem?_range' hi, Nat.one_mul]
  rfl

/-- `SC_SCORE`'s `QR` coordinates, evaluated. -/
def cQR (ev : Sym → Fp2) (c : W16Cfg) : List Coord :=
  ((drsR 8 c.sh.lh c.sh.lt).map CoordS.fixed ++ DefW16.rhoC 0 c.sh.lkv
    ++ (drsR 8 c.sh.lkv (c.sh.lh - c.sh.lkv)).map CoordS.fixed ++ DefW16.rhoC c.sh.lkv (c.sh.lkv + c.sh.ldh)).map
    (CoordS.eval ev)

/-- `SC_SCORE`'s `KR` coordinates, evaluated. -/
def cKR (ev : Sym → Fp2) (c : W16Cfg) : List Coord :=
  ((drsR 8 (c.sh.lh + c.sh.lt) c.sh.lt).map CoordS.fixed ++ DefW16.rhoC 0 c.sh.lkv
    ++ DefW16.rhoC c.sh.lkv (c.sh.lkv + c.sh.ldh)).map (CoordS.eval ev)

theorem fixed_eval (ev : Sym → Fp2) (xs : List Sym) :
    (xs.map CoordS.fixed).map (CoordS.eval ev) = (xs.map ev).map Coord.fixed := by
  rw [List.map_map, List.map_map]
  rfl

theorem cQR_eq (ev : Sym → Fp2) (c : W16Cfg) :
    cQR ev c = (((drsR 8 c.sh.lh c.sh.lt).map ev).map Coord.fixed ++ (List.range' 0 c.sh.lkv).map Coord.rho
      ++ ((drsR 8 c.sh.lkv (c.sh.lh - c.sh.lkv)).map ev).map Coord.fixed) ++ (List.range' c.sh.lkv c.sh.ldh).map Coord.rho := by
  unfold cQR
  rw [List.map_append, List.map_append, List.map_append, fixed_eval, fixed_eval, rhoC_eval, rhoC_eval, Nat.sub_zero,
    Nat.add_sub_cancel_left]

theorem cKR_eq (ev : Sym → Fp2) (c : W16Cfg) :
    cKR ev c = (((drsR 8 (c.sh.lh + c.sh.lt) c.sh.lt).map ev).map Coord.fixed ++ (List.range' 0 c.sh.lkv).map Coord.rho)
      ++ (List.range' c.sh.lkv c.sh.ldh).map Coord.rho := by
  unfold cKR
  rw [List.map_append, List.map_append, fixed_eval, rhoC_eval, rhoC_eval, Nat.sub_zero, Nat.add_sub_cancel_left]

/-- **`SC_SCORE`'s `QR` claim point at a cube point** `g ++ c` is `(r_t, g, r_hj, c)`. -/
theorem ptQR (c : W16Cfg) (ev : Sym → Fp2) (gb : Fin c.sh.lkv → Bool) (cb : Fin c.sh.ldh → Bool) (e : ℕ)
    (t : Fin (c.sh.lt + ((c.sh.lkv + (c.sh.lh - c.sh.lkv)) + c.sh.ldh))) :
    ptK U (xrK (c.sh.lkv + c.sh.ldh) (cpt (K := K) (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb))) (cQR ev c) t
      = Fin.append (W16.Szc.ptv U ev 8 c.sh.lh c.sh.lt)
          (Fin.append (Fin.append (fun i => bit (gb i)) (W16.Szc.ptv U ev 8 c.sh.lkv (c.sh.lh - c.sh.lkv)))
            (fun i => bit (cb i))) t := by
  rw [cQR_eq, ptK_app, ptK_app, ptK_app]
  simp only [List.length_append, List.length_map, drsR_len, List.length_range']
  refine Fin.addCases (fun t1 => ?_) (fun t2 => ?_) t
  · rw [Fin.append_left]
    simp only [Fin.val_castAdd]
    have h1 := t1.isLt
    rw [ite_eq_left (by omega), ite_eq_left (by omega), ite_eq_left (by omega),
      ptK_fix U _ _ _ (by rw [List.length_map, drsR_len]; exact h1), drsR_getD _ _ _ _ _ h1]
    rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun t3 => ?_) (fun t4 => ?_) t2
    · rw [Fin.append_left]
      refine Fin.addCases (fun t5 => ?_) (fun t6 => ?_) t3
      · rw [Fin.append_left]
        simp only [Fin.val_natAdd, Fin.val_castAdd]
        have h5 := t5.isLt
        rw [ite_eq_left (by omega), ite_eq_left (by omega), ite_eq_right (by omega),
          ptK_rho U _ _ _ _ (by omega), xrK_cpt, dite_eq_left (by omega)]
        congr 1
        rw [appendV, dite_eq_left (by simp only []; omega)]
        congr 1
        ext
        simp only []
        omega
      · rw [Fin.append_right]
        simp only [Fin.val_natAdd, Fin.val_castAdd]
        have h6 := t6.isLt
        rw [ite_eq_left (by omega), ite_eq_right (by omega),
          ptK_fix U _ _ _ (by rw [List.length_map, drsR_len]; omega), drsR_getD _ _ _ _ _ (by omega)]
        show _ = (ev (.dr 8 (c.sh.lkv + (t6 : ℕ)))).toK U
        congr 3
        omega
    · rw [Fin.append_right]
      simp only [Fin.val_natAdd]
      have h4 := t4.isLt
      rw [ite_eq_right (by omega), ptK_rho U _ _ _ _ (by omega), xrK_cpt, dite_eq_left (by omega)]
      congr 1
      rw [appendV, dite_eq_right (by simp only []; omega)]
      congr 1
      ext
      simp only []
      omega

/-- **`SC_SCORE`'s `KR` claim point at a cube point** `g ++ c` is `(r_3, g, c)`. -/
theorem ptKR (c : W16Cfg) (ev : Sym → Fp2) (gb : Fin c.sh.lkv → Bool) (cb : Fin c.sh.ldh → Bool) (e : ℕ)
    (t : Fin (c.sh.lt + (c.sh.lkv + c.sh.ldh))) :
    ptK U (xrK (c.sh.lkv + c.sh.ldh) (cpt (K := K) (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb))) (cKR ev c) t
      = Fin.append (W16.Szc.ptv U ev 8 (c.sh.lh + c.sh.lt) c.sh.lt)
          (Fin.append (fun i => bit (gb i)) (fun i => bit (cb i))) t := by
  rw [cKR_eq, ptK_app, ptK_app]
  simp only [List.length_append, List.length_map, drsR_len, List.length_range']
  refine Fin.addCases (fun t1 => ?_) (fun t2 => ?_) t
  · rw [Fin.append_left]
    simp only [Fin.val_castAdd]
    have h1 := t1.isLt
    rw [ite_eq_left (by omega), ite_eq_left (by omega),
      ptK_fix U _ _ _ (by rw [List.length_map, drsR_len]; exact h1), drsR_getD _ _ _ _ _ h1]
    rfl
  · rw [Fin.append_right]
    refine Fin.addCases (fun t5 => ?_) (fun t6 => ?_) t2
    · rw [Fin.append_left]
      simp only [Fin.val_natAdd, Fin.val_castAdd]
      have h5 := t5.isLt
      rw [ite_eq_left (by omega), ite_eq_right (by omega), ptK_rho U _ _ _ _ (by omega), xrK_cpt,
        dite_eq_left (by omega)]
      congr 1
      rw [appendV, dite_eq_left (by simp only []; omega)]
      congr 1
      ext
      simp only []
      omega
    · rw [Fin.append_right]
      simp only [Fin.val_natAdd]
      have h6 := t6.isLt
      rw [ite_eq_right (by omega), ptK_rho U _ _ _ _ (by omega), xrK_cpt, dite_eq_left (by omega)]
      congr 1
      rw [appendV, dite_eq_right (by simp only []; omega)]
      congr 1
      ext
      simp only []
      omega

end Pts

/-! ## Extensions at points made of blocks -/

section Mle

variable {K : Type} [Field K]

/-- **The extension at `(r, (g, s), c)` with `g`, `c` Boolean** (`SC_SCORE`'s `QR` table), any block widths. -/
theorem mleAt_qrG {a g j d : ℕ} (f : (Fin (a + ((g + j) + d)) → Bool) → K) (r : Fin a → K) (gb : Fin g → Bool)
    (s : Fin j → K) (cb : Fin d → Bool) :
    mleAt f (Fin.append r (Fin.append (Fin.append (fun i => bit (gb i)) s) (fun i => bit (cb i))))
      = ∑ t : Fin a → Bool, ∑ jj : Fin j → Bool, eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (jj i))
          * f (Fin.append t (Fin.append (Fin.append gb jj) cb)) := by
  rw [mleAt_append]
  unfold mle2
  refine Finset.sum_congr rfl (fun t _ => ?_)
  have e1 : ∀ w1 : Fin (g + j) → Bool, ∑ w2 : Fin d → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (Fin.append (fun i => bit (gb i)) s) (fun i => bit (cb i)))
        (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
      = eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (gb i)) s) (fun i => bit (w1 i))
        * f (Fin.append t (Fin.append w1 cb)) := by
    intro w1
    have h : ∀ w2 : Fin d → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (Fin.append (fun i => bit (gb i)) s) (fun i => bit (cb i)))
          (fun i => bit (Fin.append w1 w2 i)) * f (Fin.append t (Fin.append w1 w2))
        = eqPoly (fun i => (bit (cb i) : K)) (fun i => bit (w2 i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly (Fin.append (fun i => bit (gb i)) s) (fun i => bit (w1 i)) * f (Fin.append t (Fin.append w1 w2))) := by
      intro w2
      rw [W16.Szc.bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun w2 _ => h w2), W16.Szc.sum_eq_bits]
  have e2 : ∀ jj : Fin j → Bool, ∑ g' : Fin g → Bool,
      eqPoly r (fun i => bit (t i)) * eqPoly (Fin.append (fun i => bit (gb i)) s) (fun i => bit (Fin.append g' jj i))
        * f (Fin.append t (Fin.append (Fin.append g' jj) cb))
      = eqPoly r (fun i => bit (t i)) * eqPoly s (fun i => bit (jj i))
        * f (Fin.append t (Fin.append (Fin.append gb jj) cb)) := by
    intro jj
    have h : ∀ g' : Fin g → Bool, eqPoly r (fun i => bit (t i))
        * eqPoly (Fin.append (fun i => bit (gb i)) s) (fun i => bit (Fin.append g' jj i))
          * f (Fin.append t (Fin.append (Fin.append g' jj) cb))
        = eqPoly (fun i => (bit (gb i) : K)) (fun i => bit (g' i)) * (eqPoly r (fun i => bit (t i))
          * eqPoly s (fun i => bit (jj i)) * f (Fin.append t (Fin.append (Fin.append g' jj) cb))) := by
      intro g'
      rw [W16.Szc.bits_append, eqPoly_append]
      ring
    rw [Finset.sum_congr rfl (fun g' _ => h g'), W16.Szc.sum_eq_bits]
  rw [sum_append, Finset.sum_congr rfl (fun w1 _ => e1 w1), sum_append, Finset.sum_comm]
  exact Finset.sum_congr rfl (fun jj _ => e2 jj)

/-- **The extension at `(r, g, c)` with `g`, `c` Boolean** (`SC_SCORE`'s `KR` table), any block widths. -/
theorem mleAt_krG {a g d : ℕ} (f : (Fin (a + (g + d)) → Bool) → K) (r : Fin a → K) (gb : Fin g → Bool)
    (cb : Fin d → Bool) :
    mleAt f (Fin.append r (Fin.append (fun i => bit (gb i)) (fun i => bit (cb i))))
      = ∑ t : Fin a → Bool, eqPoly r (fun i => bit (t i)) * f (Fin.append t (Fin.append gb cb)) := by
  rw [← W16.Szc.bits_append gb cb]
  exact mleAt_append_bits f r (Fin.append gb cb)

end Mle

/-! ## The cube sums of `SC_RS` and `SC_SCORE` -/

section Cube

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **`SC_SCORE`'s `QR` table at a cube point** `g ++ c`: `Σ_t Σ_j eq(r_t, t)·eq(r_hj, j)·QR(t, g, j, c)`. -/
theorem tQR_cpt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hQ : c.sh.logs .Q = c.sh.lt + ((c.sh.lkv + (c.sh.lh - c.sh.lkv)) + c.sh.ldh)) (hlQ : 0 < c.sh.logs .Q)
    (e : ℕ) (gb : Fin c.sh.lkv → Bool) (cb : Fin c.sh.ldh → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D (c.sh.lkv + c.sh.ldh) e (cpt (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb)) (TabS.eval ev pub (tQR c))
      = ∑ t : Fin c.sh.lt → Bool, ∑ jj : Fin (c.sh.lh - c.sh.lkv) → Bool,
          eqPoly (W16.Szc.ptv U ev 8 c.sh.lh c.sh.lt) (fun i => bit (t i))
          * eqPoly (W16.Szc.ptv U ev 8 c.sh.lkv (c.sh.lh - c.sh.lkv)) (fun i => bit (jj i))
          * aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) (castB hQ.symm (Fin.append t (Fin.append (Fin.append gb jj) cb))) := by
  rw [show TabS.eval ev pub (tQR c)
      = Tab.priv ⟨.a, [(DefR13.aOff c 52, Fp2.one)], c.sh.logs .Q, cQR ev c, 0, 0⟩ from rfl,
    tabK_priv_cpt U P D _ e _ _ (by simp) (by exact hlQ) (by exact hrl)]
  have e1 : mleAt (fun z : Fin (c.sh.logs .Q) → Bool => aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) z)
      (fun a : Fin (c.sh.logs .Q) =>
        ptK U (xrK (c.sh.lkv + c.sh.ldh) (cpt (K := K) (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb))) (cQR ev c) a)
      = mleAt (fun z : Fin (c.sh.lt + ((c.sh.lkv + (c.sh.lh - c.sh.lkv)) + c.sh.ldh)) → Bool =>
          aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) (castB hQ.symm z))
        (Fin.append (W16.Szc.ptv U ev 8 c.sh.lh c.sh.lt)
          (Fin.append (Fin.append (fun i => bit (gb i)) (W16.Szc.ptv U ev 8 c.sh.lkv (c.sh.lh - c.sh.lkv)))
            (fun i => bit (cb i)))) := by
    rw [mleAt_aPl_cast U P D hQ]
    congr 1
    funext t
    exact ptQR U c ev gb cb e t
  exact e1.trans (mleAt_qrG _ _ _ _ _)

/-- **`SC_SCORE`'s `KR` table at a cube point** `g ++ c`: `Σ_t eq(r_3, t)·KR(t, g, c)`. -/
theorem tKR_cpt (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hK : c.sh.logs .Kv = c.sh.lt + (c.sh.lkv + c.sh.ldh)) (hlK : 0 < c.sh.logs .Kv)
    (e : ℕ) (gb : Fin c.sh.lkv → Bool) (cb : Fin c.sh.ldh → Bool) (ev : Sym → Fp2) (pub : ℕ → List Fp2) :
    tabK U P D (c.sh.lkv + c.sh.ldh) e (cpt (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb)) (TabS.eval ev pub (tKR c))
      = ∑ t : Fin c.sh.lt → Bool, eqPoly (W16.Szc.ptv U ev 8 (c.sh.lh + c.sh.lt) c.sh.lt) (fun i => bit (t i))
          * aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) (castB hK.symm (Fin.append t (Fin.append gb cb))) := by
  rw [show TabS.eval ev pub (tKR c)
      = Tab.priv ⟨.a, [(DefR13.aOff c 71, Fp2.one)], c.sh.logs .Kv, cKR ev c, 0, 1⟩ from rfl,
    tabK_priv_cpt U P D _ e _ _ (by simp) (by exact hlK) (by exact hrl)]
  have e1 : mleAt (fun z : Fin (c.sh.logs .Kv) → Bool => aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) z)
      (fun a : Fin (c.sh.logs .Kv) =>
        ptK U (xrK (c.sh.lkv + c.sh.ldh) (cpt (K := K) (c.sh.lkv + c.sh.ldh) e (Fin.append gb cb))) (cKR ev c) a)
      = mleAt (fun z : Fin (c.sh.lt + (c.sh.lkv + c.sh.ldh)) → Bool =>
          aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) (castB hK.symm z))
        (Fin.append (W16.Szc.ptv U ev 8 (c.sh.lh + c.sh.lt) c.sh.lt)
          (Fin.append (fun i => bit (gb i)) (fun i => bit (cb i)))) := by
    rw [mleAt_aPl_cast U P D hK]
    congr 1
    funext t
    exact ptKR U c ev gb cb e t
  exact e1.trans (mleAt_krG _ _ _ _)

/-- **`SC_SCORE`'s cube sum** (`n = lkv + ldh`): `Σ_g Σ_c eq(r_g, g)·Q̃R(r_t, g, r_hj, c)·K̃R(r_3, g, c)`, for any
claim sites of the numbering. -/
theorem score_cubeR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a)
    (hQ : c.sh.logs .Q = c.sh.lt + ((c.sh.lkv + (c.sh.lh - c.sh.lkv)) + c.sh.ldh)) (hlQ : 0 < c.sh.logs .Q)
    (hK : c.sh.logs .Kv = c.sh.lt + (c.sh.lkv + c.sh.ldh)) (hlK : 0 < c.sh.logs .Kv)
    (aB hB ioIn ioOut ak hk n e : ℕ) (hn : n = c.sh.lkv + c.sh.ldh) (hist : Hist) (dr : List Fp2)
    (pub : ℕ → List Fp2) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawScR c).tabs).map (TabS.eval (Sym.eval hist 8 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = ∑ g : Fin c.sh.lkv → Bool, ∑ d : Fin c.sh.ldh → Bool,
      eqPoly (W16.Szc.ptv U (Sym.eval hist 8 dr) 8 0 c.sh.lkv) (fun i => bit (g i))
      * ((∑ t : Fin c.sh.lt → Bool, ∑ jj : Fin (c.sh.lh - c.sh.lkv) → Bool,
          eqPoly (W16.Szc.ptv U (Sym.eval hist 8 dr) 8 c.sh.lh c.sh.lt) (fun i => bit (t i))
          * eqPoly (W16.Szc.ptv U (Sym.eval hist 8 dr) 8 c.sh.lkv (c.sh.lh - c.sh.lkv)) (fun i => bit (jj i))
          * aPl U P D (DefR13.aOff c 52) (c.sh.logs .Q) (castB hQ.symm (Fin.append t (Fin.append (Fin.append g jj) d))))
        * (∑ t' : Fin c.sh.lt → Bool,
          eqPoly (W16.Szc.ptv U (Sym.eval hist 8 dr) 8 (c.sh.lh + c.sh.lt) c.sh.lt) (fun i => bit (t' i))
          * aPl U P D (DefR13.aOff c 71) (c.sh.logs .Kv) (castB hK.symm (Fin.append t' (Fin.append g d))))) := by
  subst hn
  have hir : ∀ v : List K, irEval (((bilIr DefW16.cstS (some 0) 1 2).map (Sym.eval hist 8 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0) := by
    intro v
    rw [bilIr_map, bilIr_map, cstS_map, bilIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_some, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one]
  have htabs : DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawScR c).tabs
      = TabS.eq (drsR 8 0 c.sh.lkv) 0 :: DefW16.numTabs aB hB ioIn ioOut ak hk 0 [tQR c, tKR c] := rfl
  rw [cubeSum_split]
  refine (sum_append (a := c.sh.lkv) (b := c.sh.ldh) _).trans
    (Finset.sum_congr rfl (fun g _ => Finset.sum_congr rfl (fun d _ => ?_)))
  rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
  · show f (cpt _ e (Fin.append g d)) = _
    rw [hf, hir, htabs]
    simp only [List.map_cons]
    rw [numTabs_cpt U P D aB hB ioIn ioOut _ e _ _ pub [tQR c, tKR c] _ _ _ (score_priv c)]
    simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ, eqT_eval]
    rw [tabK_eqHead_cpt U P D _ e _ _ c.sh.lkv (drsR_map_len _ 8 0 _) (by omega),
      tQR_cpt U c P D hrl hQ hlQ e g d _ pub, tKR_cpt U c P D hrl hK hlK e g d _ pub]
    congr 1
    rw [← drsR_ptv U]
    congr 1
    funext i
    congr 1
    exact Fin.append_left g d i
  · show f (bpt _ e (Fin.append g d) y) = 0
    rw [hf, hir, htabs]
    simp only [List.map_cons, List.getD_cons_zero, eqT_eval]
    rw [tabK_eq_off U P D _ e _ y hy, zero_mul]

/-- **`SC_RS`'s cube sum** (`n = lS`, `lS = lH + lt`): `(Σ_j mask·E)~(p_ht) + λ·(Σ_j ZSEL)~(p_ht)`, `M` the mask table's
values, for any claim sites of the numbering. -/
theorem rs_cubeR (c : W16Cfg) (P : BlockParams) (D : CmData K P) (hrl : 0 < rowLog P .a) (hlS : 0 < c.sh.logs .S)
    (hS : c.sh.logs .S = c.sh.logs .Ht + c.sh.lt) (aB hB ioIn ioOut ak hk n e : ℕ)
    (hn : n = c.sh.logs .S) (hist : Hist) (dr : List Fp2) (pub : ℕ → List Fp2) (M : (Fin (c.sh.logs .S) → Bool) → K)
    (hmask : ∀ b, ((pub 0).getD (msbIndex (c.sh.logs .S) b) Fp2.zero).toK U = M b) (f : (Fin (n + e) → K) → K)
    (hf : ∀ x, f x = irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 (c.sh.logs .Ht))).map (Sym.eval hist 4 dr)).map
        (Fp2.toK U))
      (((DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawRsR c).tabs).map (TabS.eval (Sym.eval hist 4 dr) pub)).map
        (tabK U P D n e x))) :
    cubeSum f = mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => ∑ j : Fin c.sh.lt → Bool,
          M (castB hS.symm (Fin.append r j)) * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) (castB hS.symm (Fin.append r j)))
        (W16.Szc.ptv U (Sym.eval hist 4 dr) 4 0 (c.sh.logs .Ht))
      + (Sym.eval hist 4 dr (.dr 4 (c.sh.logs .Ht))).toK U
        * mleAt (fun r : Fin (c.sh.logs .Ht) → Bool => ∑ j : Fin c.sh.lt → Bool,
            aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) (castB hS.symm (Fin.append r j)))
          (W16.Szc.ptv U (Sym.eval hist 4 dr) 4 0 (c.sh.logs .Ht)) := by
  subst hn
  have hHS : c.sh.logs .Ht ≤ c.sh.logs .S := by omega
  have hir : ∀ v : List K, irEval (((rsIr DefW16.cstS 0 1 2 3 none (.dr 4 (c.sh.logs .Ht))).map
        (Sym.eval hist 4 dr)).map (Fp2.toK U)) v
      = v.getD 0 0 * (v.getD 1 0 * v.getD 2 0 + (Sym.eval hist 4 dr (.dr 4 (c.sh.logs .Ht))).toK U * v.getD 3 0) := by
    intro v
    rw [rsIr_map, rsIr_map, cstS_map, rsIr_eval _ (cstW_map_std U)]
    simp only [gV, Option.toList_none, List.map_nil, List.prod_nil, one_mul]
  have htabs : DefW16.numTabs aB hB ioIn ioOut ak hk 0 (rawRsR c).tabs
      = TabS.eq (drsR 4 0 (c.sh.logs .Ht)) 0 :: TabS.pub 0 :: DefW16.numTabs aB hB ioIn ioOut ak hk 1 [tS c 80, tS c 79] :=
    rfl
  rw [cubeSum_split]
  have hrow : ∀ b : Fin (c.sh.logs .S) → Bool, ∑ y : Fin e → Bool, f (fun i => bit (Fin.append b y i))
      = eqPoly (W16.Szc.ptv U (Sym.eval hist 4 dr) 4 0 (c.sh.logs .Ht)) (fun i => bit (hdB _ b i))
        * (M b * aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) b
          + (Sym.eval hist 4 dr (.dr 4 (c.sh.logs .Ht))).toK U * aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) b) := by
    intro b
    rw [Fintype.sum_eq_single (fun _ => false) (fun y hy => ?_)]
    · show f (cpt _ e b) = _
      rw [hf, hir, htabs]
      simp only [List.map_cons]
      rw [numTabs_cpt U P D aB hB ioIn ioOut _ e _ _ pub [tS c 80, tS c 79] _ _ _ (pair_priv c 80 79)]
      simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ, eqT_eval, pubT_eval]
      rw [tabK_eqHead_cpt U P D _ e _ _ _ (drsR_map_len _ 4 0 _) hHS, tabK_pub_cpt,
        hmask, tS_cpt U c P D hrl hlS e b _ pub, tS_cpt U c P D hrl hlS e b _ pub, hdB_eq hHS, ← drsR_ptv U]
    · show f (bpt _ e b y) = 0
      rw [hf, hir, htabs]
      simp only [List.map_cons, List.getD_cons_zero, eqT_eval]
      rw [tabK_eq_off U P D _ e _ y hy, zero_mul]
  simp only [hrow]
  rw [sum_bool_cast hS, sum_append]
  simp only [hdB_castB_append]
  have h2 := rs_cubeSum (W16.Szc.ptv U (Sym.eval hist 4 dr) 4 0 (c.sh.logs .Ht)) (fun _ _ => (1 : K))
    (fun (r : Fin (c.sh.logs .Ht) → Bool) (j : Fin c.sh.lt → Bool) => M (castB hS.symm (Fin.append r j)))
    (fun r j => aPl U P D (DefR13.aOff c 80) (c.sh.logs .S) (castB hS.symm (Fin.append r j)))
    (fun r j => aPl U P D (DefR13.aOff c 79) (c.sh.logs .S) (castB hS.symm (Fin.append r j)))
    ((Sym.eval hist 4 dr (.dr 4 (c.sh.logs .Ht))).toK U)
  simp only [one_mul] at h2
  exact h2

end Cube

/-! ## The batch's pieces -/

section Lists

variable {R : Type} [CommRing R]

/-- **The batch of `6 + m`**: five named clauses, `m` LogUp entries and one more, against the code's form. -/
theorem batchR (mu : ℕ → R) (cl : ℕ → R) (xs : List R) (e : R) :
    ∑ κ ∈ Finset.range (5 + xs.length + 1),
        mu κ * (if κ < 5 then cl κ else (List.replicate 5 0 ++ xs ++ [e]).getD κ 0)
      = wsum (fun k => mu (5 + k)) 0 xs + mu (5 + xs.length) * e
        + (mu 0 * cl 0 + mu 1 * cl 1 + mu 2 * cl 2 + mu 3 * cl 3 + mu 4 * cl 4) := by
  rw [Finset.sum_range_succ, Finset.sum_range_add]
  have hl5 : (List.replicate 5 (0 : R) ++ xs).length = 5 + xs.length := by
    rw [List.length_append, List.length_replicate]
  have hlast : (List.replicate 5 (0 : R) ++ xs ++ [e]).getD (5 + xs.length) 0 = e := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_right (Nat.le_of_eq hl5), hl5, Nat.sub_self]
    rfl
  have hmid : ∀ k, k < xs.length → (List.replicate 5 (0 : R) ++ xs ++ [e]).getD (5 + k) 0 = xs.getD k 0 := by
    intro k hk
    rw [List.getD_eq_getElem?_getD, List.getElem?_append_left (by rw [hl5]; omega),
      List.getElem?_append_right (by rw [List.length_replicate]; omega), List.length_replicate,
      Nat.add_sub_cancel_left, List.getD_eq_getElem?_getD]
  rw [ite_eq_right (by omega), hlast]
  have h5 : ∑ x ∈ Finset.range 5, mu x * (if x < 5 then cl x else (List.replicate 5 0 ++ xs ++ [e]).getD x 0)
      = mu 0 * cl 0 + mu 1 * cl 1 + mu 2 * cl 2 + mu 3 * cl 3 + mu 4 * cl 4 := by
    simp only [Finset.sum_range_succ, Finset.sum_range_zero, zero_add]
    norm_num
  have hx : ∑ x ∈ Finset.range xs.length,
        mu (5 + x) * (if 5 + x < 5 then cl (5 + x) else (List.replicate 5 0 ++ xs ++ [e]).getD (5 + x) 0)
      = wsum (fun k => mu (5 + k)) 0 xs := by
    rw [wsum_eq_sum, ← Fin.sum_univ_eq_sum_range]
    refine Finset.sum_congr rfl (fun k _ => ?_)
    rw [ite_eq_right (by omega), hmid k k.isLt, Nat.zero_add]
  rw [h5, hx]
  ring

end Lists

section Lks

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The LogUp lookups' expressions read only `α` and `γ`** (R13's `lksS`). -/
theorem lksSR_eval (c : W16Cfg) (shaped : ℕ → ℕ) (d : ZK60.Exec.Slot.W16R2.Dom) (h h' : Hist) (k k' : ℕ)
    (dr dr' : List Fp2) (ha : h.alpha = h'.alpha) (hg : h.gamma = h'.gamma) :
    (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h k dr))
      = (DefR13.lksS c shaped d).map (LkD.map (Sym.eval h' k' dr')) := by
  unfold DefR13.lksS
  simp only [List.map_map]
  refine List.map_congr_left (fun l _ => ?_)
  simp only [Function.comp_def, LkD.map, Sym.eval, ha, hg, List.map_map]

omit [Field K] [Algebra GF K] in
/-- The lookups' table positions are past the three `eq` tables. -/
theorem lksSR_pos (c : W16Cfg) (f : Sym → Fp2) (g : Fp2 → K) :
    ∀ l ∈ ((DefR13.lksS c shapedR .S).map (LkD.map f)).map (LkD.map g), ∀ t ∈ l.terms, 3 ≤ t.2 := by
  intro l hl t ht
  simp only [List.mem_map] at hl
  obtain ⟨l1, ⟨l0, hl0, rfl⟩, rfl⟩ := hl
  simp only [LkD.map, List.map_map, List.mem_map] at ht
  obtain ⟨t0, ht0, rfl⟩ := ht
  simp only [DefR13.lksS, List.mem_map] at hl0
  obtain ⟨lw, -, rfl⟩ := hl0
  simp only [List.mem_map] at ht0
  obtain ⟨tw, -, rfl⟩ := ht0
  simp only [Function.comp, shapedR]
  omega

/-- LogUp's helper relations read no `eq` entry (helpers from table `h0 ≥ 3`). -/
theorem lkRels_cons3R (h0 : ℕ) (e0 e1 e2 : K) (rest : List K) (lks : List (LkD K))
    (hp : ∀ l ∈ lks, ∀ t ∈ l.terms, 3 ≤ t.2) (hh : 3 ≤ h0) :
    lkRels (cstK U) (e0 :: e1 :: e2 :: rest) h0 0 lks = lkRels (cstK U) (0 :: 0 :: 0 :: rest) h0 0 lks :=
  W16.lkRels_congr (cstK U) _ _ h0 0 lks (fun l hl t ht => W16.Szc.getD_cons3 e0 e1 e2 rest t.2 (hp l hl t ht))
    (fun i _ => W16.Szc.getD_cons3 e0 e1 e2 rest _ (by omega))

omit [Algebra GF K] in
/-- The exp tuple's relation reads no `eq` entry. -/
theorem expR_cons3 (cs : Cst K) (ls : ℕ) (e0 e1 e2 : K) (rest : List K) (a nb : K) :
    r13SzcExp cs (RSzR ls) (e0 :: e1 :: e2 :: rest) a nb = r13SzcExp cs (RSzR ls) (0 :: 0 :: 0 :: rest) a nb := by
  unfold r13SzcExp r13SzcDelta
  rw [W16.Szc.getD_cons3 e0 e1 e2 rest (RSzR ls).hx (by show 3 ≤ 24 + 3 * ls; omega),
    W16.Szc.getD_cons3 e0 e1 e2 rest (RSzR ls).mx (by show 3 ≤ 15 + 2 * ls; omega),
    W16.Szc.getD_cons3 e0 e1 e2 rest (RSzR ls).mask (by show 3 ≤ 3; omega),
    W16.Szc.getD_cons3 e0 e1 e2 rest (RSzR ls).s8 (by show 3 ≤ 4; omega),
    W16.Szc.getD_cons3 e0 e1 e2 rest (RSzR ls).e (by show 3 ≤ 9; omega)]

/-- A base constant of the builders, read in the field: a power of two. -/
theorem basePow (n : ℕ) (hn : n < 64) : (cstK U).base (2 ^ n) = (2 : K) ^ n := by
  rw [W16.Szc.cK U _ (by have : (0 : ℤ) < 2 ^ n := by positivity
                         linarith) (pow_lt_pow_right₀ (by norm_num) hn)]
  push_cast
  rfl

/-- A base constant of the builders, read in the field: a negated power of two. -/
theorem baseNegPow (n : ℕ) (hn : n < 64) : (cstK U).base (-(2 ^ n : ℤ)) = -(2 : K) ^ n := by
  rw [W16.Szc.cK U _ (by have : (2 : ℤ) ^ n < 2 ^ 64 := pow_lt_pow_right₀ (by norm_num) hn
                         linarith) (by have : (0 : ℤ) < 2 ^ n := by positivity
                                       linarith)]
  push_cast
  rfl

end Lks

end ZK60.Exec.Block.Join.R13H.Szc
