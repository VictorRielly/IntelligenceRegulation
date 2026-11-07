/-
D63 step L11 (the W16R2 slot arithmetization), part 1: **the slot's terminal identity and its verify arm, executable,
and proved equal to their models.** Generic in the profile: nothing here names a W16R2 slot (those are in
`SlotW16R2.lean`), so W16R3's slots (B2's batched slots, B3's lifted sumcheck) are other values of the same types.

What is mirrored (read 2026-11-07; nothing there is changed):
* `private_block/slot_ir.rs`: the slot expression IR (`SlotIr`: tables, nodes `Affine { konst, terms }` and
  `Sum { subterms }`, top-level terms `coef · Π wrapper · Π inner`) and its interpreter `SlotIr::eval`, which the
  Rust test suite proves equal to every slot's closure at every registered shape
  (`slot_ir_accuracy.rs::the_accuracy_ir_evaluates_to_the_r13_closure_…`), and the L11 corpus checks again at a real
  W16R2 receipt's terminal values (`lean_l11_export_tests.rs`);
* `private_block/argument.rs::run_slot`'s VERIFY arm (lines 1434-1468, with 1171-1178): `pb-slot`, the CFS challenge
  `c` (refused if zero), the terminal count, `pb-scalar`, the claimed sum `scalar + Σ_hosted coef·scalar_hs`,
  `sumcheck::verify` over `n + ext` rounds, the terminal values (`sel·eq_point(point, ρ[start..])`,
  `sel·eval_mle_ext(pub, ρ)`, the masked terminals), `g = (fin − poly(vals))·c⁻¹` (the value of the slot's mask
  functional, which `M`'s test checks), the degenerate-extension refusal, `pb-term`.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`), under `toK U` (`ExecField.lean`) into ANY field
`K ⊇ GF` with `U² = 7`:
* **`toK_irEvalW`**: the IR's word evaluation is the IR's evaluation in `K` with every coefficient and value read in
  `K` (only the coefficients need be canonical words);
* **`toK_claimedW`**: the claimed sum is `scalar + Σ coef·scalar_hs` in `K`;
* **`toK_valsGo`**: each terminal value is `sel·eqPoly(point, ρ-slice)`, `sel·mleAt(pub)(ρ)` or the masked terminal;
* **`gValW_spec`**: `g = (fin − poly)/c`, i.e. the terminal identity `fin = poly(vals) + c·g` (`terminal_iff`);
* **`slotVerifyW_ok`**: an accepting verify arm is: `c` the transcript's challenge after `pb-slot` (nonzero), the
  program's `sumcheck::verify` accepting the claimed sum, the values and `g` as above, `fin = poly(vals) + c·g` in `K`,
  and the transcript `pb-slot, c, pb-scalar, the rounds, pb-term` (`slotVerifyW_tr`).
-/
import ZK60Formal.ExecSumcheck

namespace ZK60.Exec.Slot

open ZK60.Circuit (gP GF)
open ZK60.Sound
open Finset

/-! ## The slot expression IR (`slot_ir.rs`), with the coefficients' values -/

/-- A factor of a product: a table's terminal value (`Factor::Table`) or an earlier node's value (`Factor::Node`). -/
inductive Factor where
  | tab (i : ℕ)
  | node (i : ℕ)
  deriving DecidableEq, Repr

/-- One summand of a `Sum` node: a coefficient times a product of factors. -/
structure SubTerm (α : Type) where
  coef : α
  factors : List Factor

/-- A node's body: `konst + Σ coef·table` or `Σ coef·Π factors`. -/
inductive Body (α : Type) where
  | affine (konst : α) (terms : List (α × ℕ))
  | sum (subs : List (SubTerm α))

/-- A top-level term: `coef · Π_{w ∈ wrapper} table_w · Π inner`. -/
structure Term (α : Type) where
  coef : α
  wrapper : List ℕ
  inner : List Factor

/-- A slot polynomial as data: its nodes (each refers only to earlier nodes) and its top-level terms. -/
structure Ir (α : Type) where
  nodes : List (Body α)
  terms : List (Term α)

section Map

variable {α β : Type} (f : α → β)

def SubTerm.map (s : SubTerm α) : SubTerm β := ⟨f s.coef, s.factors⟩

def Body.map : Body α → Body β
  | .affine k ts => .affine (f k) (ts.map fun p => (f p.1, p.2))
  | .sum ss => .sum (ss.map (SubTerm.map f))

def Term.map (t : Term α) : Term β := ⟨f t.coef, t.wrapper, t.inner⟩

def Ir.map (ir : Ir α) : Ir β := ⟨ir.nodes.map (Body.map f), ir.terms.map (Term.map f)⟩

end Map

/-! ### The model: the IR's value in a commutative ring -/

section Model

variable {R : Type} [CommRing R]

def fval (v nv : List R) : Factor → R
  | .tab i => v.getD i 0
  | .node i => nv.getD i 0

def bodyVal (v nv : List R) : Body R → R
  | .affine k ts => k + (ts.map fun p => p.1 * v.getD p.2 0).sum
  | .sum ss => (ss.map fun s => s.coef * (s.factors.map (fval v nv)).prod).sum

/-- The forward pass over the nodes: node `i`'s value is appended after the values of nodes `0 … i − 1`. -/
def nodeVals (v : List R) : List (Body R) → List R → List R
  | [], nv => nv
  | b :: bs, nv => nodeVals v bs (nv ++ [bodyVal v nv b])

def termVal (v nv : List R) (t : Term R) : R :=
  t.coef * (t.wrapper.map fun w => v.getD w 0).prod * (t.inner.map (fval v nv)).prod

/-- **The slot polynomial's value** at the terminal values `v` (`SlotIr::eval`, read in `R`). -/
def irEval (ir : Ir R) (v : List R) : R :=
  (ir.terms.map (termVal v (nodeVals v ir.nodes []))).sum

end Model

/-! ### The program: `SlotIr::eval` on the code's words -/

def fvalW (v nv : List Fp2) : Factor → Fp2
  | .tab i => v.getD i Fp2.zero
  | .node i => nv.getD i Fp2.zero

/-- `Affine`: `terms.fold(konst, |a, (c, t)| a.add(c.mul(v[t])))`; `Sum`:
`subterms.fold(ZERO, |a, s| a.add(s.factors.fold(s.coef, |p, f| p.mul(f))))`. -/
def bodyValW (v nv : List Fp2) : Body Fp2 → Fp2
  | .affine k ts => ts.foldl (fun a p => a.add (p.1.mul (v.getD p.2 Fp2.zero))) k
  | .sum ss => ss.foldl (fun a s => a.add (s.factors.foldl (fun p f => p.mul (fvalW v nv f)) s.coef)) Fp2.zero

def nodeValsW (v : List Fp2) : List (Body Fp2) → List Fp2 → List Fp2
  | [], nv => nv
  | b :: bs, nv => nodeValsW v bs (nv ++ [bodyValW v nv b])

/-- A term: `p = coef; for w in wrapper { p = p.mul(v[w]) }; for f in inner { p = p.mul(f) }`. -/
def termValW (v nv : List Fp2) (t : Term Fp2) : Fp2 :=
  t.inner.foldl (fun p f => p.mul (fvalW v nv f)) (t.wrapper.foldl (fun p w => p.mul (v.getD w Fp2.zero)) t.coef)

/-- **`SlotIr::eval`**: the terms summed from `ZERO`. -/
def irEvalW (ir : Ir Fp2) (v : List Fp2) : Fp2 :=
  ir.terms.foldl (fun a t => a.add (termValW v (nodeValsW v ir.nodes []) t)) Fp2.zero

/-- Every coefficient is a canonical word (the IR builder's coefficients are field outputs or `from_i64`). -/
def Body.Canon : Body Fp2 → Prop
  | .affine k _ => k.Canon
  | .sum ss => ∀ s ∈ ss, s.coef.Canon

def Ir.Canon (ir : Ir Fp2) : Prop := (∀ b ∈ ir.nodes, b.Canon) ∧ ∀ t ∈ ir.terms, t.coef.Canon

/-- The same, as the checker computes it. -/
def Body.canonB : Body Fp2 → Bool
  | .affine k _ => decide k.Canon
  | .sum ss => ss.all fun s => decide s.coef.Canon

def Ir.canonB (ir : Ir Fp2) : Bool := ir.nodes.all Body.canonB && ir.terms.all fun t => decide t.coef.Canon

theorem Body.canon_of_canonB {b : Body Fp2} (h : b.canonB = true) : b.Canon := by
  cases b with
  | affine k ts => exact (of_decide_eq_true h : k.Canon)
  | sum ss =>
    intro s hs
    exact of_decide_eq_true (List.all_eq_true.mp h s hs)

theorem Ir.canon_of_canonB {ir : Ir Fp2} (h : ir.canonB = true) : ir.Canon := by
  unfold Ir.canonB at h
  rw [Bool.and_eq_true] at h
  exact ⟨fun b hb => Body.canon_of_canonB (List.all_eq_true.mp h.1 b hb),
    fun t ht => of_decide_eq_true (List.all_eq_true.mp h.2 t ht)⟩

/-! ### The program is the model -/

theorem canon_foldl_mul {α : Type} (g : α → Fp2) :
    ∀ (l : List α) (init : Fp2), init.Canon → (l.foldl (fun p a => p.mul (g a)) init).Canon
  | [], _, h => h
  | a :: l, init, _ => by
    simp only [List.foldl_cons]
    exact canon_foldl_mul g l _ (Fp2.canon_mul _ _)

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

omit hU in
theorem toK_fvalW (v nv : List Fp2) (f : Factor) :
    (fvalW v nv f).toK U = fval (v.map (Fp2.toK U)) (nv.map (Fp2.toK U)) f := by
  cases f with
  | tab i => exact (getD_map_toK U v i).symm
  | node i => exact (getD_map_toK U nv i).symm

omit hU in
theorem canon_bodyValW (v nv : List Fp2) (b : Body Fp2) (hb : b.Canon) : (bodyValW v nv b).Canon := by
  cases b with
  | affine k ts => exact canon_foldl_add _ ts k hb
  | sum ss => exact canon_foldl_add _ ss Fp2.zero Fp2.canon_zero

theorem toK_bodyValW (v nv : List Fp2) (b : Body Fp2) (hb : b.Canon) :
    (bodyValW v nv b).toK U = bodyVal (v.map (Fp2.toK U)) (nv.map (Fp2.toK U)) (b.map (Fp2.toK U)) := by
  cases b with
  | affine k ts =>
    simp only [bodyValW, bodyVal, Body.map]
    rw [toK_foldl_add U (fun p : Fp2 × ℕ => p.1.mul (v.getD p.2 Fp2.zero)) ts k hb (fun p _ => Fp2.canon_mul _ _),
      List.map_map]
    refine congrArg₂ (· + ·) rfl (congrArg List.sum (List.map_congr_left fun p _ => ?_))
    simp only [Function.comp_apply, Fp2.toK_mul U hU, getD_map_toK U v p.2]
  | sum ss =>
    simp only [bodyValW, bodyVal, Body.map]
    rw [toK_foldl_add U (fun s : SubTerm Fp2 => s.factors.foldl (fun p f => p.mul (fvalW v nv f)) s.coef) ss
      Fp2.zero Fp2.canon_zero (fun s hs => canon_foldl_mul _ _ _ (hb s hs)), Fp2.toK_zero, zero_add, List.map_map]
    refine congrArg List.sum (List.map_congr_left fun s _ => ?_)
    simp only [Function.comp_apply, SubTerm.map]
    rw [toK_foldl_mul U hU]
    exact congrArg₂ (· * ·) rfl (congrArg List.prod (List.map_congr_left fun f _ => toK_fvalW U v nv f))

theorem nodeValsW_map (v : List Fp2) :
    ∀ (bs : List (Body Fp2)) (nv : List Fp2), (∀ b ∈ bs, b.Canon) →
      (nodeValsW v bs nv).map (Fp2.toK U)
        = nodeVals (v.map (Fp2.toK U)) (bs.map (Body.map (Fp2.toK U))) (nv.map (Fp2.toK U))
  | [], nv, _ => rfl
  | b :: bs, nv, hbs => by
    simp only [nodeValsW, nodeVals, List.map_cons]
    rw [nodeValsW_map v bs _ (fun b' hb' => hbs b' (List.mem_cons_of_mem b hb')), List.map_append, List.map_cons,
      List.map_nil, toK_bodyValW U hU v nv b (hbs b List.mem_cons_self)]

theorem toK_termValW (v nv : List Fp2) (t : Term Fp2) :
    (termValW v nv t).toK U = termVal (v.map (Fp2.toK U)) (nv.map (Fp2.toK U)) (t.map (Fp2.toK U)) := by
  unfold termValW termVal Term.map
  rw [toK_foldl_mul U hU, toK_foldl_mul U hU]
  refine congrArg₂ (· * ·) (congrArg₂ (· * ·) rfl ?_) ?_
  · exact congrArg List.prod (List.map_congr_left fun w _ => (getD_map_toK U v w).symm)
  · exact congrArg List.prod (List.map_congr_left fun f _ => toK_fvalW U v nv f)

omit hU in
theorem canon_termValW (v nv : List Fp2) (t : Term Fp2) (ht : t.coef.Canon) : (termValW v nv t).Canon :=
  canon_foldl_mul _ _ _ (canon_foldl_mul _ _ _ ht)

/-- **The IR's word evaluation is its evaluation in `K`.** Only the coefficients need be canonical: the table values
and node values enter products only. -/
theorem toK_irEvalW (ir : Ir Fp2) (hir : ir.Canon) (v : List Fp2) :
    (irEvalW ir v).toK U = irEval (ir.map (Fp2.toK U)) (v.map (Fp2.toK U)) := by
  unfold irEvalW irEval Ir.map
  dsimp only
  rw [toK_foldl_add U (fun t => termValW v (nodeValsW v ir.nodes []) t) ir.terms Fp2.zero Fp2.canon_zero
      (fun t ht => canon_termValW v _ t (hir.2 t ht)), Fp2.toK_zero, zero_add, List.map_map]
  have hnv := nodeValsW_map U hU v ir.nodes [] hir.1
  rw [List.map_nil] at hnv
  rw [← hnv]
  refine congrArg List.sum (List.map_congr_left fun t _ => ?_)
  exact toK_termValW U hU v _ t

omit hU in
theorem canon_irEvalW (ir : Ir Fp2) (v : List Fp2) : (irEvalW ir v).Canon :=
  canon_foldl_add _ _ _ Fp2.canon_zero

end K

/-! ## The verify arm's arithmetic -/

/-- A slot table as the VERIFIER holds it (`Tab`): an `eq` over a point of challenges starting at variable `start`, a
public table of the slot's cube, or a private table (its value is the next masked terminal). -/
inductive TabV where
  | eq (start : ℕ) (point : List Fp2)
  | pub (vals : List Fp2)
  | priv

def TabV.isPriv : TabV → Bool
  | .priv => true
  | _ => false

/-- `sel = Π_e (1 − e)` over the extension challenges. -/
def selW (es : List Fp2) : Fp2 := es.foldl (fun a e => a.mul (Fp2.one.sub e)) Fp2.one

/-- **The terminal values** (argument.rs:1446-1457): `sel·eq_point(point, ρ[start..start+|point|])`,
`sel·eval_mle_ext(pub, ρ)`, the `k`-th masked terminal. A slice outside `ρ` or a public table of the wrong length is
the code's panic or refusal, here `none`. -/
def valsGo (sel : Fp2) (rho terms : List Fp2) : ℕ → List TabV → Option (List Fp2)
  | _, [] => some []
  | k, .eq start point :: ts =>
    if start + point.length ≤ rho.length then
      (valsGo sel rho terms k ts).map (sel.mul (eqPointBody point ((rho.drop start).take point.length)) :: ·)
    else none
  | k, .pub v :: ts =>
    match evalMleExt v rho with
    | some m => (valsGo sel rho terms k ts).map (sel.mul m :: ·)
    | none => none
  | k, .priv :: ts =>
    match terms[k]? with
    | some x => (valsGo sel rho terms (k + 1) ts).map (x :: ·)
    | none => none

/-- **The claimed sum** (argument.rs:1440): `hosted.fold(scalar, |a, (hs, coef)| a.add(coef.mul(scalars[hs])))`. -/
def claimedW (scalar : Fp2) (hosted : List (ℕ × Fp2)) (scalars : List Fp2) : Fp2 :=
  hosted.foldl (fun a p => a.add (p.2.mul (scalars.getD p.1 Fp2.zero))) scalar

/-- **The mask functional's value** (argument.rs:1458): `g = (fin − poly(vals))·c⁻¹`. -/
def gValW (fin polyVal c : Fp2) : Fp2 := (fin.sub polyVal).mul c.inv

section K2

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

theorem toK_claimedW (scalar : Fp2) (hs : scalar.Canon) (hosted : List (ℕ × Fp2)) (scalars : List Fp2) :
    (claimedW scalar hosted scalars).toK U
      = scalar.toK U + (hosted.map fun p => p.2.toK U * (scalars.getD p.1 Fp2.zero).toK U).sum := by
  unfold claimedW
  rw [toK_foldl_add U (fun p : ℕ × Fp2 => p.2.mul (scalars.getD p.1 Fp2.zero)) hosted scalar hs
    (fun p _ => Fp2.canon_mul _ _)]
  exact congrArg₂ (· + ·) rfl (congrArg List.sum (List.map_congr_left fun p _ => Fp2.toK_mul U hU _ _))

theorem toK_selW : ∀ (es : List Fp2), (∀ e ∈ es, e.Canon) →
    (selW es).toK U = (es.map fun e => 1 - e.toK U).prod := by
  intro es hes
  unfold selW
  rw [toK_foldl_mul U hU, Fp2.toK_one, one_mul]
  refine congrArg List.prod (List.map_congr_left fun e he => ?_)
  rw [Fp2.toK_sub U _ _ Fp2.canon_one (hes e he), Fp2.toK_one]

omit hU in
theorem canon_selW (es : List Fp2) : (selW es).Canon := canon_foldl_mul _ _ _ Fp2.canon_one

/-- **`g` is the terminal identity's solution**: for a nonzero canonical `c` and canonical `fin`, `poly`,
`(g·c = fin − poly)` in `K`. -/
theorem toK_gValW (fin pv c : Fp2) (hf : fin.Canon) (hp : pv.Canon) (hc : c.Canon) (h0 : c ≠ Fp2.zero) :
    (gValW fin pv c).toK U = (fin.toK U - pv.toK U) * (c.toK U)⁻¹ := by
  unfold gValW
  rw [Fp2.toK_mul U hU, Fp2.toK_sub U _ _ hf hp, eq_inv_of_mul_eq_one_left (Fp2.toK_inv U hU c hc h0)]

theorem toK_ne_zero (c : Fp2) (hc : c.Canon) (h0 : c ≠ Fp2.zero) : c.toK U ≠ 0 := by
  intro h
  exact h0 (Fp2.toK_injective U hU hc Fp2.canon_zero (by rw [h, Fp2.toK_zero]))

/-- **The terminal identity**: `g = gValW fin poly c` exactly when `fin = poly + c·g` in `K`. -/
theorem terminal_iff (fin pv c : Fp2) (hf : fin.Canon) (hp : pv.Canon) (hc : c.Canon) (h0 : c ≠ Fp2.zero) (g : K) :
    (gValW fin pv c).toK U = g ↔ fin.toK U = pv.toK U + c.toK U * g := by
  rw [toK_gValW U hU fin pv c hf hp hc h0]
  have hc0 := toK_ne_zero U hU c hc h0
  constructor
  · intro h
    have hm : c.toK U * ((fin.toK U - pv.toK U) * (c.toK U)⁻¹) = fin.toK U - pv.toK U := by
      rw [mul_comm (fin.toK U - pv.toK U), ← mul_assoc, mul_inv_cancel₀ hc0, one_mul]
    rw [← h, hm]
    ring
  · intro h
    rw [h, add_sub_cancel_left, mul_comm, ← mul_assoc, inv_mul_cancel₀ hc0, one_mul]

end K2

/-! ### The terminal values in `K` -/

/-- The verifier's points are canonical words (they are challenges). -/
def TabV.Canon : TabV → Prop
  | .eq _ point => ∀ a ∈ point, a.Canon
  | _ => True

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The model of one terminal value**: `sel·eq(point, ρ[start..])`, `sel·T̃(ρ)` for a public table (its cube values
`b ↦ v[msbIndex b]`), or the masked terminal. -/
def tabValK (sel : K) (rho terms : List Fp2) (k : ℕ) : TabV → K
  | .eq start point =>
    sel * eqPoly (vecK U point.length point) (vecK U point.length ((rho.drop start).take point.length))
  | .pub v => sel * mleAt (fun b => (v.getD (msbIndex rho.length b) Fp2.zero).toK U) (vecK U rho.length rho)
  | .priv => (terms.getD k Fp2.zero).toK U

/-- The private counter before each table. -/
def privIdx : ℕ → List TabV → List ℕ
  | _, [] => []
  | k, t :: ts => k :: privIdx (if t.isPriv then k + 1 else k) ts

/-- **The terminal values are their models**: with canonical challenges and points, every value the program computes
is `tabValK` of its table. -/
theorem toK_valsGo (hU : U ^ 2 = algebraMap GF K 7) (sel : Fp2) (rho terms : List Fp2) (hrho : ∀ a ∈ rho, a.Canon) :
    ∀ (k : ℕ) (ts : List TabV) (out : List Fp2), (∀ t ∈ ts, t.Canon) →
      valsGo sel rho terms k ts = some out →
      out.map (Fp2.toK U) = (ts.zip (privIdx k ts)).map fun p => tabValK U (sel.toK U) rho terms p.2 p.1
  | _, [], out, _, h => by
    simp only [valsGo, Option.some.injEq] at h
    subst h
    rfl
  | k, .eq start point :: ts, out, hts, h => by
    simp only [valsGo] at h
    by_cases hlen : start + point.length ≤ rho.length
    · rw [ite_eq_left hlen] at h
      obtain ⟨rest, hrest, rfl⟩ := Option.map_eq_some_iff.mp h
      have ih := toK_valsGo hU sel rho terms hrho k ts rest (fun t ht => hts t (List.mem_cons_of_mem _ ht)) hrest
      have hp : ∀ a ∈ point, a.Canon := hts (.eq start point) List.mem_cons_self
      have hsl : ∀ a ∈ (rho.drop start).take point.length, a.Canon :=
        fun a ha => hrho a (List.mem_of_mem_drop (List.mem_of_mem_take ha))
      have hl : point.length = ((rho.drop start).take point.length).length := by
        rw [List.length_take, List.length_drop]
        omega
      have hk : privIdx k (TabV.eq start point :: ts) = k :: privIdx k ts := rfl
      rw [hk, List.zip_cons_cons, List.map_cons, List.map_cons, ih, Fp2.toK_mul U hU,
        toK_eqPointBody U hU point _ hp hsl hl]
      rfl
    · rw [ite_eq_right hlen] at h
      cases h
  | k, .pub v :: ts, out, hts, h => by
    simp only [valsGo] at h
    cases hm : evalMleExt v rho with
    | none =>
      rw [hm] at h
      cases h
    | some m =>
      rw [hm] at h
      obtain ⟨rest, hrest, rfl⟩ := Option.map_eq_some_iff.mp h
      have ih := toK_valsGo hU sel rho terms hrho k ts rest (fun t ht => hts t (List.mem_cons_of_mem _ ht)) hrest
      unfold evalMleExt at hm
      by_cases hv : v.length = 2 ^ rho.length
      · rw [ite_eq_left hv, Option.some.injEq] at hm
        subst hm
        have hk : privIdx k (TabV.pub v :: ts) = k :: privIdx k ts := rfl
        rw [hk, List.zip_cons_cons, List.map_cons, List.map_cons, ih, Fp2.toK_mul U hU,
          toK_mleSumExt U hU v rho hrho hv]
        rfl
      · rw [ite_eq_right hv] at hm
        cases hm
  | k, .priv :: ts, out, hts, h => by
    simp only [valsGo] at h
    cases hx : terms[k]? with
    | none =>
      rw [hx] at h
      cases h
    | some x =>
      rw [hx] at h
      obtain ⟨rest, hrest, rfl⟩ := Option.map_eq_some_iff.mp h
      have ih := toK_valsGo hU sel rho terms hrho (k + 1) ts rest (fun t ht => hts t (List.mem_cons_of_mem _ ht))
        hrest
      have hk : privIdx k (TabV.priv :: ts) = k :: privIdx (k + 1) ts := rfl
      have hg : terms.getD k Fp2.zero = x := by
        rw [List.getD_eq_getElem?_getD, hx, Option.getD_some]
      rw [hk, List.zip_cons_cons, List.map_cons, List.map_cons, ih]
      simp only [tabValK, hg]

end Vals

/-! ## The verify arm, executable -/

/-- `b"pb-slot"`, `b"pb-scalar"`, `b"pb-term"` (`L11Check.lean` checks each is `ascii` of its string). -/
def pbSlot : List UInt8 := [112, 98, 45, 115, 108, 111, 116]
def pbScalar : List UInt8 := [112, 98, 45, 115, 99, 97, 108, 97, 114]
def pbTerm : List UInt8 := [112, 98, 45, 116, 101, 114, 109]

/-- **A slot as the verifier defines it** (`SlotDef` plus the schedule's `(main, ext, degree)`): the slot index, the
rounds, the degree, the tables, the hosted private slots with their coefficients, and the polynomial as IR. -/
structure SlotDefW where
  slot : ℕ
  n : ℕ
  ext : ℕ
  degree : ℕ
  tabs : List TabV
  hosted : List (ℕ × Fp2)
  ir : Ir Fp2

/-- **A slot's proof** (`SlotProof`): its published scalar, its sumcheck rounds, its masked terminals. -/
structure SlotProofW where
  scalar : Fp2
  rounds : List (List Fp2)
  terms : List Fp2

/-- What an accepting verify arm hands on: the CFS challenge, the claimed sum, the sumcheck's final claim and
challenges, the terminal values, `poly(vals)`, and `g` (the value of the slot's mask functional for `M`'s test). -/
structure SlotOutW where
  c : Fp2
  claimed : Fp2
  fin : Fp2
  rhoFull : List Fp2
  vals : List Fp2
  polyVal : Fp2
  gVal : Fp2

/-- The verify arm's refusals (each a `return Err(..)` of `run_slot`; the slice and length guards are the code's
panic or `F-6` refusal). -/
inductive SlotErr where
  | cZero
  | termCount
  | sc (e : ScErr)
  | vals
  | degenerate

def privCount (tabs : List TabV) : ℕ := (tabs.filter TabV.isPriv).length

section Arm

variable (H : HIn → Dig)

/-- The transcript after `pb-slot`. -/
def slotT1 (d : SlotDefW) (t : Tr) : Tr := t.absorbU64 H pbSlot (UInt64.ofNat d.slot)

/-- The CFS challenge `c` and the transcript after it. -/
def slotC (d : SlotDefW) (t : Tr) : Fp2 × Tr := (slotT1 H d t).challengeFp2 H

/-- The transcript after `pb-scalar`, where the sumcheck starts. -/
def slotT3 (d : SlotDefW) (p : SlotProofW) (t : Tr) : Tr := (slotC H d t).2.absorbFp2 H pbScalar [p.scalar]

/-- The degenerate-extension test (argument.rs:1465). -/
def degenerate (es : List Fp2) : Bool := es.any fun e => e.isZero || e == Fp2.one

/-- **`run_slot`'s verify arm** (argument.rs:1171-1178, 1434-1468), on the code's transcript. -/
def slotVerifyW (d : SlotDefW) (scalars : List Fp2) (p : SlotProofW) (t : Tr) : Except SlotErr SlotOutW × Tr :=
  if (slotC H d t).1.isZero then (.error .cZero, (slotC H d t).2)
  else if p.terms.length ≠ privCount d.tabs then (.error .termCount, (slotC H d t).2)
  else
    match scVerify H (claimedW p.scalar d.hosted scalars) d.degree (d.n + d.ext) p.rounds (slotT3 H d p t) with
    | (.error e, t4) => (.error (.sc e), t4)
    | (.ok (fin, rhoFull), t4) =>
      match valsGo (selW (rhoFull.drop d.n)) (rhoFull.take d.n) p.terms 0 d.tabs with
      | none => (.error .vals, t4)
      | some vals =>
        if degenerate (rhoFull.drop d.n) then (.error .degenerate, t4)
        else (.ok ⟨(slotC H d t).1, claimedW p.scalar d.hosted scalars, fin, rhoFull, vals, irEvalW d.ir vals,
            gValW fin (irEvalW d.ir vals) (slotC H d t).1⟩, t4.absorbFp2 H pbTerm p.terms)

end Arm

theorem isZero_false {c : Fp2} (h : c.isZero = false) : c ≠ Fp2.zero := by
  rintro rfl
  exact absurd h (by decide)

/-- **An accepting verify arm, unfolded.** The challenge `c` is the transcript's after `pb-slot` and nonzero; the
terminal count is the private table count; the program's `sumcheck::verify` accepts the claimed sum on the transcript
after `pb-scalar`; the values are `valsGo` of the tables at `ρ = rhoFull[..n]`, `sel = Π_{e ∈ rhoFull[n..]} (1 − e)`;
`poly` is the IR's value; `g = (fin − poly)/c`; no extension challenge is `0` or `1`; the transcript ends with
`pb-term`. -/
theorem slotVerifyW_ok (H : HIn → Dig) (d : SlotDefW) (scalars : List Fp2) (p : SlotProofW) (t : Tr) (o : SlotOutW)
    (t' : Tr) (h : slotVerifyW H d scalars p t = (.ok o, t')) :
    o.c = (slotC H d t).1 ∧ o.c ≠ Fp2.zero ∧ p.terms.length = privCount d.tabs ∧
      o.claimed = claimedW p.scalar d.hosted scalars ∧
      (scVerify H o.claimed d.degree (d.n + d.ext) p.rounds (slotT3 H d p t)).1 = .ok (o.fin, o.rhoFull) ∧
      valsGo (selW (o.rhoFull.drop d.n)) (o.rhoFull.take d.n) p.terms 0 d.tabs = some o.vals ∧
      o.polyVal = irEvalW d.ir o.vals ∧ o.gVal = gValW o.fin o.polyVal o.c ∧
      degenerate (o.rhoFull.drop d.n) = false ∧
      t' = (scVerify H o.claimed d.degree (d.n + d.ext) p.rounds (slotT3 H d p t)).2.absorbFp2 H pbTerm p.terms := by
  unfold slotVerifyW at h
  by_cases hc : (slotC H d t).1.isZero = true
  · rw [ite_eq_left hc] at h
    cases h
  rw [ite_eq_right hc] at h
  by_cases hn : p.terms.length ≠ privCount d.tabs
  · rw [ite_eq_left hn] at h
    cases h
  rw [ite_eq_right hn] at h
  rcases hsc : scVerify H (claimedW p.scalar d.hosted scalars) d.degree (d.n + d.ext) p.rounds (slotT3 H d p t)
    with ⟨r, t4⟩
  rw [hsc] at h
  rcases r with e | ⟨fin, rhoFull⟩
  · cases h
  simp only at h
  rcases hv : valsGo (selW (rhoFull.drop d.n)) (rhoFull.take d.n) p.terms 0 d.tabs with _ | vals
  · rw [hv] at h
    cases h
  rw [hv] at h
  simp only at h
  by_cases hdeg : degenerate (rhoFull.drop d.n) = true
  · rw [ite_eq_left hdeg] at h
    cases h
  rw [ite_eq_right hdeg] at h
  simp only [Prod.mk.injEq, Except.ok.injEq] at h
  obtain ⟨rfl, rfl⟩ := h
  exact ⟨rfl, isZero_false (by simpa using hc), by simpa using hn, rfl, congrArg Prod.fst hsc, hv, rfl, rfl,
    by simpa using hdeg,
    (congrArg (fun q : Except ScErr (Fp2 × List Fp2) × Tr => q.2.absorbFp2 H pbTerm p.terms) hsc).symm⟩

/-- **The terminal identity of an accepting slot, in `K`**: `fin = poly(vals) + c·g`. -/
theorem slotVerifyW_terminal {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (H : HIn → Dig) (d : SlotDefW) (hir : d.ir.Canon) (scalars : List Fp2) (p : SlotProofW) (t : Tr) (o : SlotOutW)
    (t' : Tr) (h : slotVerifyW H d scalars p t = (.ok o, t')) (hfin : o.fin.Canon) :
    o.fin.toK U = irEval (d.ir.map (Fp2.toK U)) (o.vals.map (Fp2.toK U)) + o.c.toK U * o.gVal.toK U := by
  obtain ⟨hc, hc0, -, -, -, -, hpv, hg, -, -⟩ := slotVerifyW_ok H d scalars p t o t' h
  have hcc : o.c.Canon := by
    rw [hc]
    exact canon_challengeFp2Of _
  rw [← toK_irEvalW U hU d.ir hir o.vals, ← hpv]
  refine (terminal_iff U hU o.fin o.polyVal o.c hfin (by rw [hpv]; exact canon_irEvalW _ _) hcc hc0 _).mp ?_
  rw [hg]

end ZK60.Exec.Slot
