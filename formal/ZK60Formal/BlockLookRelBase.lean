/-
D63 lane L47 (2026-11-10), part 3 (fork C): **LogUp's helper relations, the generic half** (for `hhr`).

* `relLk_pair`, `relLk_single`: entry `j` of a host's LogUp relation list `lkRels` is the pair relation
  `h·d₁·d₂ − d₁ − d₂` of lookups `2j`, `2j + 1`, and the odd last entry is `h·d − 1`;
* `lkSymW`, `lksS_eq`: a lookup's expression (`logup_subterms`, `DefW16.lksS`), per lookup;
* `lkTupP`, **`denV_lkSym`**: at a canonical `α`, a lookup's denominator, read in the field on a value list whose
  positions hold the lookup's planes, IS `α − fold(β, γ, tuple)` (the tuple `(Σ coef·plane + cst, TAG(width), 0, 0)`);
* `pair_of_rel`, `single_of_rel`: the relations in `HelperRel`'s form;
* **`bga_canon_of_accT`**: on an accepting outcome `α` and `β` are canonical words (the verifier's `define` refuses
  otherwise, `defineS`'s `HistCanon`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockLookBase

set_option autoImplicit false

namespace ZK60.Exec.Block.Join.W16.Look

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Block
open ZK60.Exec.Block.Join
open ZK60.Exec.Block.Join.W16
open ZK60.Exec.Block.DefW16
open ZK60.Exec.Slot.Build (LkD denV Cst)
open ZK60.Exec.Slot.Build.Lay (LkW)
open ZK60.Circuit (gP GF tagW)

/-! ## The LogUp relation list, entry by entry -/

section Rels

variable {R : Type} [CommRing R]

/-- **Entry `j` of `lkRels` is the pair relation of lookups `2j`, `2j + 1`.** -/
theorem relLk_pair (c : Cst R) (v : List R) (h0 : ℕ) (d : LkD R) :
    ∀ (j k : ℕ) (lks : List (LkD R)), 2 * j + 1 < lks.length →
      (lkRels c v h0 k lks).getD j 0
        = c.one * (v.getD (h0 + k + j) 0 * (denV v (lks.getD (2 * j) d) * denV v (lks.getD (2 * j + 1) d)))
          + c.negOne * denV v (lks.getD (2 * j) d) + c.negOne * denV v (lks.getD (2 * j + 1) d)
  | _, _, [], h => absurd h (by simp)
  | _, _, [_], h => absurd h (by simp)
  | 0, k, l₁ :: l₂ :: ls, _ => by
    simp only [lkRels, List.getD_cons_zero, Nat.mul_zero, Nat.zero_add, Nat.add_zero, List.getD_cons_succ]
  | j + 1, k, l₁ :: l₂ :: ls, h => by
    have h' : 2 * j + 1 < ls.length := by simp only [List.length_cons] at h; omega
    rw [lkRels, List.getD_cons_succ, relLk_pair c v h0 d j (k + 1) ls h']
    have e1 : 2 * (j + 1) = 2 * j + 1 + 1 := by ring
    have e3 : h0 + (k + 1) + j = h0 + k + (j + 1) := by ring
    rw [e1, e3]
    simp only [List.getD_cons_succ]

/-- **The odd last entry of `lkRels` is the single relation of the last lookup.** -/
theorem relLk_single (c : Cst R) (v : List R) (h0 : ℕ) (d : LkD R) :
    ∀ (m k : ℕ) (lks : List (LkD R)), lks.length = 2 * m + 1 →
      (lkRels c v h0 k lks).getD m 0 = c.one * (v.getD (h0 + k + m) 0 * denV v (lks.getD (2 * m) d)) + c.negOne
  | _, _, [], h => absurd h (by simp)
  | 0, k, [l], _ => by
    simp only [lkRels, List.getD_cons_zero, Nat.mul_zero, Nat.add_zero]
  | m + 1, _, [_], h => absurd h (by simp)
  | 0, _, _ :: _ :: _, h => absurd h (by simp)
  | m + 1, k, l₁ :: l₂ :: ls, h => by
    have h' : ls.length = 2 * m + 1 := by simp only [List.length_cons] at h; omega
    rw [lkRels, List.getD_cons_succ, relLk_single c v h0 d m (k + 1) ls h']
    have e1 : 2 * (m + 1) = 2 * m + 1 + 1 := by ring
    have e3 : h0 + (k + 1) + m = h0 + k + (m + 1) := by ring
    rw [e1, e3]
    simp only [List.getD_cons_succ]

/-- The pair relation in `HelperRel`'s form. -/
theorem pair_of_rel {h d₁ d₂ : R} (hr : 1 * (h * (d₁ * d₂)) + (-1) * d₁ + (-1) * d₂ = 0) :
    h * (d₁ * d₂) = d₁ + d₂ := by
  linear_combination hr

/-- The single relation in `HelperRel`'s form. -/
theorem single_of_rel {h d : R} (hr : 1 * (h * d) + (-1) = 0) : h * d = 1 := by
  linear_combination hr

end Rels

/-! ## A lookup's denominator -/

/-- **A lookup's expression** (`lksS`, per lookup): `α − (cst + g_tag)` and the terms `−coef·plane`. -/
def lkSymW (shaped : ℕ → ℕ) (l : LkW) : LkD Sym :=
  ⟨.sub .alpha (.add (.base l.cst) (.gtag (tagW l.tag))), l.terms.map fun t => (Sym.base (-t.2), shaped t.1)⟩

theorem lksS_eq (c : W16Cfg) (shaped : ℕ → ℕ) (d : ZK60.Exec.Slot.W16R2.Dom) :
    lksS c shaped d = (lookupsN c d).map (lkSymW shaped) := rfl

/-- A mapped lookup list's entry (any default of the mapped form). -/
theorem lks_getD {K : Type} (f : Sym → Fp2) (g : Fp2 → K) (shaped : ℕ → ℕ) (ls : List LkW) (i : ℕ) :
    (((ls.map (lkSymW shaped)).map (ZK60.Exec.Slot.Build.LkD.map f)).map (ZK60.Exec.Slot.Build.LkD.map g)).getD i
        (ZK60.Exec.Slot.Build.LkD.map g (ZK60.Exec.Slot.Build.LkD.map f (lkSymW shaped ⟨[], 0, 0⟩)))
      = ZK60.Exec.Slot.Build.LkD.map g (ZK60.Exec.Slot.Build.LkD.map f (lkSymW shaped (ls.getD i ⟨[], 0, 0⟩))) := by
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_map,
    List.getElem?_map]
  cases ls[i]? <;> rfl

section Den

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **A lookup's tuple on a plane reader** `pl`: `(Σ coef·pl(plane) + cst, TAG(width), 0, 0)`. -/
noncomputable def lkTupP (pl : ℕ → K) (l : LkW) : Tup K :=
  ⟨(l.terms.map fun t => (t.2 : K) * pl t.1).sum + (l.cst : K), ((tagW l.tag : ℕ) : K), 0, 0⟩

theorem fromI64_canon (v : ℤ) : (Fp.fromI64 v).Canon := by
  unfold Fp.fromI64
  split_ifs <;> exact Fp.new_canon _

theorem toK_baseSym (hist : Hist) (k : ℕ) (dr : List Fp2) (v : ℤ) (h1 : -2 ^ 64 < v) (h2 : v < 2 ^ 64) :
    (Sym.eval hist k dr (.base v)).toK U = (v : K) := by
  show (Fp2.fromBase (Fp.fromI64 v)).toK U = _
  rw [Fp2.toK_fromBase, Fp.toGF_fromI64 v h1 h2, map_intCast]

theorem terms_sum (hist : Hist) (k : ℕ) (dr : List Fp2) (shaped : ℕ → ℕ) (v : List K) (pl : ℕ → K) :
    ∀ ts : List (ℕ × ℤ), (∀ t ∈ ts, -2 ^ 64 < -t.2 ∧ -t.2 < 2 ^ 64) →
      (∀ t ∈ ts, v.getD (shaped t.1) 0 = pl t.1) →
      ((((ts.map fun t => (Sym.base (-t.2), shaped t.1)).map fun p => (Sym.eval hist k dr p.1, p.2)).map
          fun p => (Fp2.toK U p.1, p.2)).map fun p => p.1 * v.getD p.2 0).sum
        = -(ts.map fun t => (t.2 : K) * pl t.1).sum
  | [], _, _ => by simp
  | t :: ts, hb, hv => by
    simp only [List.map_cons, List.sum_cons]
    rw [terms_sum hist k dr shaped v pl ts (fun t ht => hb t (List.mem_cons_of_mem _ ht))
      (fun t ht => hv t (List.mem_cons_of_mem _ ht)),
      toK_baseSym U hist k dr (-t.2) (hb t (by simp)).1 (hb t (by simp)).2,
      hv t (by simp)]
    push_cast
    ring

/-- **A lookup's denominator is `α − fold(β, γ, tuple)`**, at a canonical `α`, on a value list whose positions hold
the lookup's planes. -/
theorem denV_lkSym (hist : Hist) (hα : hist.alpha.Canon) (k : ℕ) (dr : List Fp2) (shaped : ℕ → ℕ) (l : LkW)
    (hc1 : -2 ^ 64 < l.cst) (hc2 : l.cst < 2 ^ 64) (ht : tagW l.tag < 2 ^ 64)
    (hco : ∀ t ∈ l.terms, -2 ^ 64 < -t.2 ∧ -t.2 < 2 ^ 64)
    (v : List K) (pl : ℕ → K) (hv : ∀ t ∈ l.terms, v.getD (shaped t.1) 0 = pl t.1) :
    denV v (ZK60.Exec.Slot.Build.LkD.map (Fp2.toK U) (ZK60.Exec.Slot.Build.LkD.map (Sym.eval hist k dr) (lkSymW shaped l)))
      = hist.alpha.toK U - ZK60.Sound.fold (hist.beta.toK U) (hist.gamma.toK U) (lkTupP pl l) := by
  unfold denV
  have hk : (Sym.eval hist k dr (.sub .alpha (.add (.base l.cst) (.gtag (tagW l.tag))))).toK U
      = hist.alpha.toK U - ((l.cst : K) + hist.gamma.toK U * ((tagW l.tag : ℕ) : K)) := by
    show (Fp2.sub hist.alpha (Fp2.add (Fp2.fromBase (Fp.fromI64 l.cst))
      (hist.gamma.mulBase (Fp.new (UInt64.ofNat (tagW l.tag)))))).toK U = _
    rw [Fp2.toK_sub U _ _ hα (Fp2.canon_add _ _),
      Fp2.toK_add U _ _ (Fp2.canon_fromBase _ (fromI64_canon _)) (Fp2.canon_mulBase _ _),
      Fp2.toK_fromBase, Fp.toGF_fromI64 _ hc1 hc2, map_intCast, Fp2.toK_mulBase, Fp.new_toGF_ofNat _ ht,
      map_natCast]
  have hs := terms_sum U hist k dr shaped v pl l.terms hco hv
  show (Sym.eval hist k dr (.sub .alpha (.add (.base l.cst) (.gtag (tagW l.tag))))).toK U
      + ((((l.terms.map fun t => (Sym.base (-t.2), shaped t.1)).map fun p => (Sym.eval hist k dr p.1, p.2)).map
          fun p => (Fp2.toK U p.1, p.2)).map fun p => p.1 * v.getD p.2 0).sum = _
  rw [hk, hs]
  unfold ZK60.Sound.fold lkTupP
  ring

end Den

/-! ## `α`, `β` are canonical on an accepting outcome -/

section Canon

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **On an accepting outcome `α` and `β` are canonical words**: slot `0` was defined, and the verifier's `define`
(`defineS`) refuses a non-canonical history. -/
theorem bga_canon_of_accT (U : K) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (P : BlockParams) (hsl : P.geom.slots = W16R2.rungSlots)
    (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs) (hdrLen : ℕ)
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (csX : Cuts3 L → RootsO → Cm → ZClaim → K) (msX : Cuts3 L → RootsO → List (ℕ × List Fp2) → K)
    (A : OC (QB L) Dig (List Op × Core)) (G : QB L → Dig) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hT : AccT U key domain hs hL P hdrLen F csX msX A G bga rs acc) : bga.2.2.Canon ∧ bga.1.Canon := by
  have hT' := hT
  obtain ⟨hacc, -, -⟩ := hT'
  obtain ⟨-, -, -, hsh, t', hbs⟩ := hacc.1
  obtain ⟨hlen, -⟩ := blockSlots_fns (liftH G) P (A.run G).2 _ bga rs acc t' hbs
  have h0 : 0 < rs.length := by
    rw [hlen, hsh.1, hsl]
    decide
  obtain ⟨r, hr⟩ : ∃ r, rs[0]? = some r := ⟨_, List.getElem?_eq_getElem h0⟩
  obtain ⟨sp, df, hdf, -⟩ := slotFns_of_accT U key domain hs hL P hdrLen F csX msX A G bga rs acc hT 0 r hr
  rw [hdef] at hdf
  have hc := (defineS_ok hdf).1
  exact ⟨hc.1, hc.2.1⟩

end Canon

end ZK60.Exec.Block.Join.W16.Look
