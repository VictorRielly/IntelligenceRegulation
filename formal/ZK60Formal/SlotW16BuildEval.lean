/-
D63 step L13, part 2: **what the W16R2 slot polynomials evaluate to** (`SlotW16Build.lean`'s ports of the code's
builders), in any commutative ring, for any coefficient constants.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `nodeVals_append`, `nodeVals_ext`, `getD_len_add`: a node's value is fixed when it is pushed (`IrB`'s numbering);
* `logupGo_spec`: the LogUp segment's subterms sum to `logupSem`, `Σ_k μ_k·(h_k·d_{2k}·d_{2k+1} − d_{2k} − d_{2k+1})`
  (`h·d − 1` for an odd last lookup), `d = konst + Σ coef·table` the lookup's denominator;
* `padGo_spec`: the pad segment's to `padSem`, `Σ_groups μ_pad·(1 − supp)·Σ_j ζ^j·plane_j` with the powers running on;
* **`zcIr_vals`**: the zero-check template's node values: the slot's own nodes, then the zero-check node's value
  `logupSem + extra + padSem + last`, then the host nodes;
* the naturality of the builders (`Ir.map` of a builder at the code's words is the builder at the images), so the
  theorems below, stated in a ring for ANY constants, apply to the code's IR read in `K` (`toK_irEvalW`).
-/
import ZK60Formal.SlotW16Build

namespace ZK60.Exec.Slot.Build

open ZK60.Exec ZK60.Exec.Slot

section Vals

variable {R : Type} [CommRing R]

/-! ## Node values -/

theorem nodeVals_append (v : List R) : ∀ (as bs : List (Body R)) (acc : List R),
    nodeVals v (as ++ bs) acc = nodeVals v bs (nodeVals v as acc)
  | [], _, _ => rfl
  | _ :: as, bs, _ => nodeVals_append v as bs _

theorem nodeVals_ext (v : List R) : ∀ (bs : List (Body R)) (acc : List R),
    ∃ t, nodeVals v bs acc = acc ++ t ∧ t.length = bs.length
  | [], acc => ⟨[], by simp [nodeVals]⟩
  | b :: bs, acc => by
    obtain ⟨t, ht, hl⟩ := nodeVals_ext v bs (acc ++ [bodyVal v acc b])
    exact ⟨bodyVal v acc b :: t, by simp [nodeVals, ht], by simp [hl]⟩

theorem nodeVals_length (v : List R) (bs : List (Body R)) (acc : List R) :
    (nodeVals v bs acc).length = acc.length + bs.length := by
  obtain ⟨t, ht, hl⟩ := nodeVals_ext v bs acc
  rw [ht, List.length_append, hl]

theorem getD_len_add {β : Type} (A B : List β) (j : ℕ) (d : β) : (A ++ B).getD (A.length + j) d = B.getD j d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_right (by omega),
    Nat.add_sub_cancel_left]

theorem getD_len {β : Type} (A B : List β) (d : β) : (A ++ B).getD A.length d = B.getD 0 d := by
  simpa using getD_len_add A B 0 d

theorem getD_lt {β : Type} (A B : List β) (i : ℕ) (hi : i < A.length) (d : β) : (A ++ B).getD i d = A.getD i d := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_append_left hi]

/-! ## The semantic pieces -/

/-- A subterm's value against node values `nv`. -/
def stVal (v nv : List R) (s : SubTerm R) : R := s.coef * (s.factors.map (fval v nv)).prod

theorem bodyVal_sum (v nv : List R) (ss : List (SubTerm R)) : bodyVal v nv (.sum ss) = (ss.map (stVal v nv)).sum := rfl

/-- A lookup's denominator `konst + Σ coef·table`. -/
def denV (v : List R) (l : LkD R) : R := l.konst + (l.terms.map fun p => p.1 * v.getD p.2 0).sum

/-- **LogUp's helper relations, batched**: `Σ_k μ_k·(h_k·d₁·d₂ − d₁ − d₂)`, an odd last `μ_k·(h_k·d − 1)`. -/
def logupSem (c : Cst R) (v : List R) (h0 : ℕ) (mu : ℕ → R) : ℕ → List (LkD R) → R
  | _, [] => 0
  | k, [l] => mu k * (c.one * (v.getD (h0 + k) 0 * denV v l) + c.negOne)
  | k, l₁ :: l₂ :: ls => mu k * (c.one * (v.getD (h0 + k) 0 * (denV v l₁ * denV v l₂)) + c.negOne * denV v l₁
      + c.negOne * denV v l₂) + logupSem c v h0 mu (k + 1) ls

/-- **The pad term**: `Σ_groups μ_pad·(1 − supp)·Σ_j ζ^j·plane_j`, the powers continuing across the groups. -/
def padSem (c : Cst R) (v : List R) (mu : R) (zp : ℕ → R) : ℕ → List (ℕ × List ℕ) → R
  | _, [] => 0
  | j, (s, ps) :: gs => mu * ((c.one + c.negOne * v.getD s 0) *
      (c.zero + (ps.zipIdx.map fun q => zp (j + q.2) * v.getD q.1 0).sum)) + padSem c v mu zp (j + ps.length) gs

theorem logupGo_len (c : Cst R) (h0 : ℕ) (mu : ℕ → R) :
    ∀ (k o : ℕ) (ls : List (LkD R)), (logupGo c h0 mu k o ls).2.length = 3 * (ls.length / 2) + 2 * (ls.length % 2)
  | _, _, [] => by simp [logupGo]
  | _, _, [_] => by simp [logupGo]
  | k, o, _ :: _ :: ls => by
    have ih := logupGo_len c h0 mu (k + 1) (o + 3) ls
    simp only [logupGo, List.length_append, ih, List.length_cons, List.length_nil]
    omega

/-- **The LogUp segment's value.** With its first node at id `o = acc.length`, its subterms, read against the node
values of any later list, sum to `logupSem`. -/
theorem logupGo_spec (c : Cst R) (v : List R) (h0 : ℕ) (mu : ℕ → R) :
    ∀ (k : ℕ) (ls : List (LkD R)) (acc : List R) (ext : List (Body R)),
      (((logupGo c h0 mu k acc.length ls).1).map
          (stVal v (nodeVals v ext (nodeVals v (logupGo c h0 mu k acc.length ls).2 acc)))).sum
        = logupSem c v h0 mu k ls
  | _, [], _, _ => rfl
  | k, [l], acc, ext => by
    obtain ⟨t, ht, -⟩ := nodeVals_ext v ext (nodeVals v (logupGo c h0 mu k acc.length [l]).2 acc)
    rw [ht]
    simp only [logupGo, nodeVals, denB, bodyVal, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal, st,
      fval, List.prod_cons, List.prod_nil, List.append_assoc, List.singleton_append, List.cons_append,
      List.nil_append, getD_len, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, logupSem, denV]
    ring
  | k, l₁ :: l₂ :: ls, acc, ext => by
    have ih := logupGo_spec c v h0 mu (k + 1) ls (nodeVals v ([denB l₁, denB l₂,
      .sum [st c.one [.tab (h0 + k), .node acc.length, .node (acc.length + 1)], st c.negOne [.node acc.length],
        st c.negOne [.node (acc.length + 1)]]] : List (Body R)) acc) ext
    have hl : (nodeVals v ([denB l₁, denB l₂,
        .sum [st c.one [.tab (h0 + k), .node acc.length, .node (acc.length + 1)], st c.negOne [.node acc.length],
          st c.negOne [.node (acc.length + 1)]]] : List (Body R)) acc).length = acc.length + 3 := by
      rw [nodeVals_length]; rfl
    rw [hl] at ih
    simp only [logupGo]
    rw [nodeVals_append, List.map_cons, List.sum_cons, ih]
    obtain ⟨t, ht, -⟩ := nodeVals_ext v ext (nodeVals v (logupGo c h0 mu (k + 1) (acc.length + 3) ls).2
      (nodeVals v ([denB l₁, denB l₂, .sum [st c.one [.tab (h0 + k), .node acc.length, .node (acc.length + 1)],
        st c.negOne [.node acc.length], st c.negOne [.node (acc.length + 1)]]] : List (Body R)) acc))
    obtain ⟨t', ht', -⟩ := nodeVals_ext v (logupGo c h0 mu (k + 1) (acc.length + 3) ls).2
      (nodeVals v ([denB l₁, denB l₂, .sum [st c.one [.tab (h0 + k), .node acc.length, .node (acc.length + 1)],
        st c.negOne [.node acc.length], st c.negOne [.node (acc.length + 1)]]] : List (Body R)) acc)
    rw [ht, ht']
    simp only [nodeVals, denB, bodyVal, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal, st,
      fval, List.prod_cons, List.prod_nil, List.append_assoc, List.singleton_append, List.cons_append,
      List.nil_append, getD_len, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, logupSem, denV]
    ring

theorem padGo_len (c : Cst R) (mu : R) (zp : ℕ → R) :
    ∀ (j o : ℕ) (gs : List (ℕ × List ℕ)), (padGo c mu zp j o gs).2.length = 2 * gs.length
  | _, _, [] => rfl
  | j, o, (s, ps) :: gs => by
    simp only [padGo, List.length_append, padGo_len c mu zp _ _ gs, List.length_cons, List.length_nil]
    omega

/-- **The pad segment's value**, the same way. -/
theorem padGo_spec (c : Cst R) (v : List R) (mu : R) (zp : ℕ → R) :
    ∀ (j : ℕ) (gs : List (ℕ × List ℕ)) (acc : List R) (ext : List (Body R)),
      (((padGo c mu zp j acc.length gs).1).map
          (stVal v (nodeVals v ext (nodeVals v (padGo c mu zp j acc.length gs).2 acc)))).sum
        = padSem c v mu zp j gs
  | _, [], _, _ => rfl
  | j, (s, ps) :: gs, acc, ext => by
    have ih := padGo_spec c v mu zp (j + ps.length) gs (nodeVals v ([.affine c.one [(c.negOne, s)],
      .affine c.zero (ps.zipIdx.map fun q => (zp (j + q.2), q.1))] : List (Body R)) acc) ext
    have hl : (nodeVals v ([.affine c.one [(c.negOne, s)],
        .affine c.zero (ps.zipIdx.map fun q => (zp (j + q.2), q.1))] : List (Body R)) acc).length = acc.length + 2 := by
      rw [nodeVals_length]; rfl
    rw [hl] at ih
    simp only [padGo]
    rw [nodeVals_append, List.map_cons, List.sum_cons, ih]
    obtain ⟨t, ht, -⟩ := nodeVals_ext v ext (nodeVals v (padGo c mu zp (j + ps.length) (acc.length + 2) gs).2
      (nodeVals v ([.affine c.one [(c.negOne, s)],
        .affine c.zero (ps.zipIdx.map fun q => (zp (j + q.2), q.1))] : List (Body R)) acc))
    obtain ⟨t', ht', -⟩ := nodeVals_ext v (padGo c mu zp (j + ps.length) (acc.length + 2) gs).2
      (nodeVals v ([.affine c.one [(c.negOne, s)],
        .affine c.zero (ps.zipIdx.map fun q => (zp (j + q.2), q.1))] : List (Body R)) acc)
    rw [ht, ht']
    simp only [nodeVals, bodyVal, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal, st, fval,
      List.prod_cons, List.prod_nil, List.append_assoc, List.singleton_append, List.cons_append, List.nil_append,
      getD_len, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, padSem, List.map_map, Function.comp_def]
    ring

/-- **The zero-check template's node values.** With `P` the slot's own nodes' values, there is a list `A` (`P`, then
the LogUp and pad segments' values) whose first entries are `P`'s, such that the whole node list's values are the
host nodes `post (|A| + 1)` evaluated after `A` and the zero-check node `logupSem + extra + padSem + last`, the terms
being `terms |A|`. -/
theorem zcIr_vals (c : Cst R) (v : List R) (pre : List (Body R)) (lks : List (LkD R)) (h0 : ℕ) (muL : ℕ → R)
    (extra : List (SubTerm R)) (padMu : R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) (last : List (SubTerm R))
    (post : ℕ → List (Body R)) (terms : ℕ → List (Term R)) :
    ∃ A : List R, (∃ t, A = nodeVals v pre [] ++ t) ∧
      nodeVals v (zcIr c pre lks h0 muL extra padMu zp groups last post terms).nodes []
        = nodeVals v (post (A.length + 1)) (A ++ [logupSem c v h0 muL 0 lks + (extra.map (stVal v A)).sum
            + padSem c v padMu zp 0 groups + (last.map (stVal v A)).sum])
      ∧ (zcIr c pre lks h0 muL extra padMu zp groups last post terms).terms = terms A.length := by
  unfold zcIr
  simp only
  have hP : (nodeVals v pre []).length = pre.length := by rw [nodeVals_length]; simp
  have hlg := logupGo_spec c v h0 muL 0 lks (nodeVals v pre [])
  rw [hP] at hlg
  generalize logupGo c h0 muL 0 pre.length lks = lg at hlg ⊢
  have hQ : (nodeVals v lg.2 (nodeVals v pre [])).length = pre.length + lg.2.length := by rw [nodeVals_length, hP]
  have hpd := padGo_spec c v padMu zp 0 groups (nodeVals v lg.2 (nodeVals v pre [])) []
  rw [hQ] at hpd
  simp only [nodeVals] at hpd
  generalize padGo c padMu zp 0 (pre.length + lg.2.length) groups = pd at hpd ⊢
  have hA : (nodeVals v pd.2 (nodeVals v lg.2 (nodeVals v pre []))).length
      = pre.length + lg.2.length + pd.2.length := by rw [nodeVals_length, hQ]
  refine ⟨nodeVals v pd.2 (nodeVals v lg.2 (nodeVals v pre [])), ?_, ?_, ?_⟩
  · obtain ⟨t, ht, -⟩ := nodeVals_ext v lg.2 (nodeVals v pre [])
    obtain ⟨t', ht', -⟩ := nodeVals_ext v pd.2 (nodeVals v lg.2 (nodeVals v pre []))
    exact ⟨t ++ t', by rw [ht', ht, List.append_assoc]⟩
  · rw [hA, nodeVals_append, nodeVals_append, nodeVals_append, nodeVals_append]
    congr 1
    simp only [nodeVals, bodyVal_sum, List.map_append, List.sum_append]
    rw [hlg pd.2, hpd]
  · rw [hA]

end Vals

/-! ## Naturality: the code's IR read in another coefficient type -/

section Map

variable {α β : Type} (f : α → β)

/-- A lookup's image. -/
def LkD.map (l : LkD α) : LkD β := ⟨f l.konst, l.terms.map fun p => (f p.1, p.2)⟩

theorem logupGo_map1 (c : Cst α) (h0 : ℕ) (mu : ℕ → α) : ∀ (k o : ℕ) (ls : List (LkD α)),
    (logupGo c h0 mu k o ls).1.map (SubTerm.map f) = (logupGo (c.map f) h0 (f ∘ mu) k o (ls.map (LkD.map f))).1
  | _, _, [] => rfl
  | _, _, [_] => rfl
  | k, o, _ :: _ :: ls => by
    simp only [List.map_cons, logupGo]
    rw [logupGo_map1 c h0 mu (k + 1) (o + 3) ls]
    rfl

theorem logupGo_map2 (c : Cst α) (h0 : ℕ) (mu : ℕ → α) : ∀ (k o : ℕ) (ls : List (LkD α)),
    (logupGo c h0 mu k o ls).2.map (Body.map f) = (logupGo (c.map f) h0 (f ∘ mu) k o (ls.map (LkD.map f))).2
  | _, _, [] => rfl
  | _, _, [_] => rfl
  | k, o, _ :: _ :: ls => by
    simp only [List.map_cons, logupGo, List.map_append]
    rw [logupGo_map2 c h0 mu (k + 1) (o + 3) ls]
    rfl

theorem padGo_map1 (c : Cst α) (mu : α) (zp : ℕ → α) : ∀ (j o : ℕ) (gs : List (ℕ × List ℕ)),
    (padGo c mu zp j o gs).1.map (SubTerm.map f) = (padGo (c.map f) (f mu) (f ∘ zp) j o gs).1
  | _, _, [] => rfl
  | j, o, (s, ps) :: gs => by
    simp only [List.map_cons, padGo]
    rw [padGo_map1 c mu zp (j + ps.length) (o + 2) gs]
    rfl

theorem padGo_map2 (c : Cst α) (mu : α) (zp : ℕ → α) : ∀ (j o : ℕ) (gs : List (ℕ × List ℕ)),
    (padGo c mu zp j o gs).2.map (Body.map f) = (padGo (c.map f) (f mu) (f ∘ zp) j o gs).2
  | _, _, [] => rfl
  | j, o, (s, ps) :: gs => by
    simp only [List.map_cons, padGo, List.map_append]
    rw [padGo_map2 c mu zp (j + ps.length) (o + 2) gs]
    simp only [List.map_cons, List.map_nil, Body.map, Cst.map, List.map_map]
    rfl

/-- **The template commutes with `Ir.map`.** -/
theorem zcIr_map (c : Cst α) (pre : List (Body α)) (lks : List (LkD α)) (h0 : ℕ) (muL : ℕ → α)
    (extra : List (SubTerm α)) (padMu : α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) (last : List (SubTerm α))
    (post : ℕ → List (Body α)) (terms : ℕ → List (Term α)) :
    (zcIr c pre lks h0 muL extra padMu zp groups last post terms).map f
      = zcIr (c.map f) (pre.map (Body.map f)) (lks.map (LkD.map f)) h0 (f ∘ muL) (extra.map (SubTerm.map f)) (f padMu)
          (f ∘ zp) groups (last.map (SubTerm.map f)) (fun o => (post o).map (Body.map f))
          (fun o => (terms o).map (Term.map f)) := by
  unfold zcIr Ir.map
  simp only [List.length_map]
  rw [← logupGo_map2 f c h0 muL 0 pre.length lks, ← logupGo_map1 f c h0 muL 0 pre.length lks, List.length_map,
    ← padGo_map2 f c padMu zp 0 (pre.length + (logupGo c h0 muL 0 pre.length lks).2.length) groups,
    ← padGo_map1 f c padMu zp 0 (pre.length + (logupGo c h0 muL 0 pre.length lks).2.length) groups, List.length_map]
  simp only [List.map_append, List.map_cons, List.map_nil, Body.map]

end Map

end ZK60.Exec.Slot.Build
