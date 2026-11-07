/-
D63 lane L23 (2026-11-07), part 8: **naturality and canonicity of L13's builders, at every W16R2 slot** (L13's
"What is left" item 3, L16-4).

L13 proved `dzcIr_map` and `dzc_code_eval` for `SC_DZC`: the builder commutes with `Ir.map`, so the word the executable
verify arm computes (`irEvalW`) on the IR built at the code's words, read in `K`, IS the named form of
`SlotW16BuildSlots.lean`. This file does the same for the other builders and proves that the built IR is canonical
(`Ir.Canon`, the premise of `toK_irEvalW` and of L16's `hpolyC` through `canon_irEvalW`):

* `ssIr_map`, `rsIr_map`, `mmIr_map`, `bilIr_map`, `zsIr_map`, `ioIr_map`, `tzcIr_map`, `lzcIr_map`, `tabGo_map1`,
  `tabGo_map2`, `tabIr_map`, `fzcIr_map`, `qzcIr_map`, `szcIr_map`: every builder commutes with `Ir.map`;
* **`ss_code_eval`**, **`rs_code_eval`**, **`mm_code_eval`**, **`bil_code_eval`**, **`zs_code_eval`**,
  **`io_code_eval`**, **`tzc_code_eval`**, **`lzc_code_eval`**, **`tab_code_eval`**, **`fzc_code_eval`**,
  **`qzc_code_eval`**, **`szc_code_eval`**: at every slot, the verify arm's `poly(vals)` read in `K` is the named form
  (`hostTerms` with the slot's clause list for the hosts; `eq(τ)·(LogUp + pad)` for `SC_LZC`; …);
* `CanonW`, `cstC`, `cstC_map`, `canon_map_val`, `lks_lift`, **`dzcIr_canon`**, **`tzcIr_canon`**, **`fzcIr_canon`**,
  **`qzcIr_canon`**, **`szcIr_canon`**, **`lzcIr_canon`**, **`tabIr_canon`**, `ssIr_canon`, `rsIr_canon`,
  `mmIr_canon`, `bilIr_canon`, `zsIr_canon`, `ioIr_canon`: the IR built at the code's words from canonical draws (and
  canonical LogUp constants) is canonical: build it over the canonical words and read it back (naturality).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.SlotW16Compose

set_option autoImplicit false

namespace ZK60.Exec.Slot.Compose

open ZK60.Exec.Slot.Build

/-! ## Naturality -/

section MapAll

variable {α β : Type} (f : α → β)

theorem ssIr_map (c : Cst α) (eq a : ℕ) (g : Option ℕ) : (ssIr c eq a g).map f = ssIr (c.map f) eq a g := rfl

theorem rsIr_map (c : Cst α) (eq mask e z : ℕ) (g : Option ℕ) (lam : α) :
    (rsIr c eq mask e z g lam).map f = rsIr (c.map f) eq mask e z g (f lam) := rfl

theorem mmIr_map (c : Cst α) (a w : ℕ) : (mmIr c a w).map f = mmIr (c.map f) a w := rfl

theorem bilIr_map (c : Cst α) (geq : Option ℕ) (a b : ℕ) : (bilIr c geq a b).map f = bilIr (c.map f) geq a b := rfl

theorem zsIr_map (c : Cst α) (ones u : ℕ) : (zsIr c ones u).map f = zsIr (c.map f) ones u := rfl

theorem ioIr_map (c : Cst α) (tau a ep : ℕ) : (ioIr c tau a ep).map f = ioIr (c.map f) tau a ep := rfl

theorem tzcIr_map (c : Cst α) (Rr : TzcR) (ceps : ℤ) (mu nu : List α) (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (tzcIr c Rr ceps mu nu zp groups).map f = tzcIr (c.map f) Rr ceps (mu.map f) (nu.map f) (f ∘ zp) groups := by
  unfold tzcIr
  rw [zcIr_map]
  simp only [tzcPre, tzcPost, tzcExtra, threeTerms, limbsB, st, List.map_cons, List.map_nil, Body.map, SubTerm.map,
    Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f]
  rfl

theorem lzcIr_map (c : Cst α) (tau h0 : ℕ) (lks : List (LkD α)) (muPad : α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) :
    (lzcIr c tau h0 lks muPad zp groups).map f = lzcIr (c.map f) tau h0 (lks.map (LkD.map f)) (f muPad) (f ∘ zp) groups := by
  unfold lzcIr
  rw [zcIr_map]
  simp only [List.map_cons, List.map_nil, Term.map, Cst.map, Function.comp_def]

theorem tabGo_map1 (c : Cst α) (alpha : α) (mu : List α) : ∀ (k o : ℕ) (ts : List (ℕ × ℕ × ℕ)),
    (tabGo c alpha mu k o ts).1.map (SubTerm.map f) = (tabGo (c.map f) (f alpha) (mu.map f) k o ts).1
  | _, _, [] => rfl
  | k, o, (m, h, tv) :: ts => by
    simp only [tabGo, List.map_cons]
    rw [tabGo_map1 c alpha mu (k + 1) (o + 2) ts]
    simp only [st, SubTerm.map, Cst.map]
    rw [← getD_map_f f mu k c.zero]

theorem tabGo_map2 (c : Cst α) (alpha : α) (mu : List α) : ∀ (k o : ℕ) (ts : List (ℕ × ℕ × ℕ)),
    (tabGo c alpha mu k o ts).2.map (Body.map f) = (tabGo (c.map f) (f alpha) (mu.map f) k o ts).2
  | _, _, [] => rfl
  | k, o, (m, h, tv) :: ts => by
    simp only [tabGo, List.map_append]
    rw [tabGo_map2 c alpha mu (k + 1) (o + 2) ts]
    rfl

theorem tabIr_map (c : Cst α) (tau : ℕ) (alpha : α) (ts : List (ℕ × ℕ × ℕ)) (mu : List α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) :
    (tabIr c tau alpha ts mu zp groups).map f = tabIr (c.map f) tau (f alpha) ts (mu.map f) (f ∘ zp) groups := by
  unfold tabIr
  rw [zcIr_map, tabGo_map1, tabGo_map2]
  simp only [List.map_cons, List.map_nil, Term.map, Cst.map, Function.comp_def]
  rw [← getD_map_f f mu ts.length c.zero]

theorem fzcIr_map (c : Cst α) (Rr : FzcR) (K' : FzcK) (lks : List (LkD α)) (mu nu : List α) (amqK nb nb2 : α)
    (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (fzcIr c Rr K' lks mu nu amqK nb nb2 zp groups).map f
      = fzcIr (c.map f) Rr K' (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f amqK) (f nb) (f nb2) (f ∘ zp) groups := by
  unfold fzcIr
  rw [zcIr_map]
  simp only [fzcPre, fzcPost, threeTerms, gatedSt, limbs16B, reqB, batchB, st, List.map_cons, List.map_nil,
    Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f, List.length_map]
  rfl

theorem qzcIr_map (c : Cst α) (Rr : QzcR) (K' : QzcK) (lks : List (LkD α)) (mu nu : List α) (zp : ℕ → α)
    (groups : List (ℕ × List ℕ)) :
    (qzcIr c Rr K' lks mu nu zp groups).map f
      = qzcIr (c.map f) Rr K' (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f ∘ zp) groups := by
  unfold qzcIr
  rw [zcIr_map]
  simp only [qzcPre, qzcPost, threeTerms, gatedSt, limbs16B, reqB, batchB, st, List.map_cons, List.map_nil,
    Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f, List.length_map]
  rfl

theorem szcIr_map (c : Cst α) (Rr : SzcR) (K' : SzcK) (lks : List (LkD α)) (mu nu : List α) (amdK nb lam : α)
    (zp : ℕ → α) (groups : List (ℕ × List ℕ)) :
    (szcIr c Rr K' lks mu nu amdK nb lam zp groups).map f
      = szcIr (c.map f) Rr K' (lks.map (LkD.map f)) (mu.map f) (nu.map f) (f amdK) (f nb) (f lam) (f ∘ zp) groups := by
  unfold szcIr
  rw [zcIr_map]
  simp only [szcPre, szcPost, gatedSt, limbs16B, reqB, batchB, st, List.map_cons, List.map_nil,
    Body.map, SubTerm.map, Term.map, Cst.map, List.map_map, Function.comp_def, getD_map_f, List.length_map]
  rfl

end MapAll

/-! ## At the code's words, read in `K`: the named forms -/

section Code

open ZK60.Exec ZK60.Exec.Slot
open ZK60.Circuit (GF)

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

include hU

theorem ss_code_eval (eq a : ℕ) (g : Option ℕ) (hir : (ssIr cstW eq a g).Canon) (v : List Fp2) :
    (irEvalW (ssIr cstW eq a g) v).toK U = let w := v.map (Fp2.toK U)
      gV w g * (w.getD eq 0 * (w.getD a 0 * w.getD a 0)) := by
  rw [toK_irEvalW U hU _ hir, ssIr_map, ssIr_eval _ (cstW_map_std U)]

theorem rs_code_eval (eq mask e z : ℕ) (g : Option ℕ) (lam : Fp2) (hir : (rsIr cstW eq mask e z g lam).Canon)
    (v : List Fp2) :
    (irEvalW (rsIr cstW eq mask e z g lam) v).toK U = let w := v.map (Fp2.toK U)
      gV w g * (w.getD eq 0 * (w.getD mask 0 * w.getD e 0 + lam.toK U * w.getD z 0)) := by
  rw [toK_irEvalW U hU _ hir, rsIr_map, rsIr_eval _ (cstW_map_std U)]

theorem mm_code_eval (a w' : ℕ) (hir : (mmIr cstW a w').Canon) (v : List Fp2) :
    (irEvalW (mmIr cstW a w') v).toK U = let w := v.map (Fp2.toK U)
      w.getD a 0 * w.getD w' 0 := by
  rw [toK_irEvalW U hU _ hir, mmIr_map, mmIr_eval _ (cstW_map_std U)]

theorem bil_code_eval (geq : Option ℕ) (a b : ℕ) (hir : (bilIr cstW geq a b).Canon) (v : List Fp2) :
    (irEvalW (bilIr cstW geq a b) v).toK U = let w := v.map (Fp2.toK U)
      gV w geq * (w.getD a 0 * w.getD b 0) := by
  rw [toK_irEvalW U hU _ hir, bilIr_map, bilIr_eval _ (cstW_map_std U)]

theorem zs_code_eval (ones u : ℕ) (hir : (zsIr cstW ones u).Canon) (v : List Fp2) :
    (irEvalW (zsIr cstW ones u) v).toK U = let w := v.map (Fp2.toK U)
      w.getD ones 0 * w.getD u 0 := by
  rw [toK_irEvalW U hU _ hir, zsIr_map, zsIr_eval _ (cstW_map_std U)]

theorem io_code_eval (tau a ep : ℕ) (hir : (ioIr cstW tau a ep).Canon) (v : List Fp2) :
    (irEvalW (ioIr cstW tau a ep) v).toK U = let w := v.map (Fp2.toK U)
      w.getD tau 0 * (w.getD a 0 - w.getD ep 0) := by
  rw [toK_irEvalW U hU _ hir, ioIr_map, ioIr_eval _ (cstW_map_std U)]

/-- **`SC_TZC`'s `poly(vals)` read in `K`** is `hostTerms` with `tzcClauses` and the pad term. -/
theorem tzc_code_eval (Rr : TzcR) (ceps : ℤ) (mu nu : List Fp2) (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ))
    (hir : (tzcIr cstW Rr ceps mu nu zp groups).Canon) (v : List Fp2) :
    (irEvalW (tzcIr cstW Rr ceps mu nu zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        hostTerms w Rr.tau Rr.rt Rr.rt2 Rr.gate Rr.gate (nu.map (Fp2.toK U))
          (batchV m (tzcClauses c Rr w) + padSem c w (m.getD 6 0) (Fp2.toK U ∘ zp) 0 groups)
          (w.getD Rr.dsq 0 + L256 c w [Rr.dsq + 1 + 3, Rr.dsq + 1 + 4, Rr.dsq + 1 + 5] + c.base (-ceps))
          (w.getD Rr.dsqm 0 + L256 c w [Rr.dsqm + 1 + 3, Rr.dsqm + 1 + 4, Rr.dsqm + 1 + 5] + c.base (-ceps)) := by
  rw [toK_irEvalW U hU _ hir, tzcIr_map, tzcIr_eval _ (cstW_map_std U)]

/-- **`SC_LZC`'s `poly(vals)` read in `K`**: `eq(τ)·(LogUp at the all-ones weight + pad)`. -/
theorem lzc_code_eval (tau h0 : ℕ) (lks : List (LkD Fp2)) (muPad : Fp2) (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ))
    (hir : (lzcIr cstW tau h0 lks muPad zp groups).Canon) (v : List Fp2) :
    (irEvalW (lzcIr cstW tau h0 lks muPad zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        w.getD tau 0 * (logupSem c w h0 (fun _ => c.one) 0 (lks.map (LkD.map (Fp2.toK U)))
          + padSem c w (muPad.toK U) (Fp2.toK U ∘ zp) 0 groups) := by
  rw [toK_irEvalW U hU _ hir, lzcIr_map, lzcIr_eval _ (cstW_map_std U)]

/-- **`SC_TAB`'s `poly(vals)` read in `K`**: `eq(τ)·(Σ_k μ_k·(h_k·(α − t_k) − m_k) + pad)`. -/
theorem tab_code_eval (tau : ℕ) (alpha : Fp2) (ts : List (ℕ × ℕ × ℕ)) (mu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (hir : (tabIr cstW tau alpha ts mu zp groups).Canon) (v : List Fp2) :
    (irEvalW (tabIr cstW tau alpha ts mu zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        w.getD tau 0 * (tabSem w (alpha.toK U) m 0 ts + padSem c w (m.getD ts.length c.zero) (Fp2.toK U ∘ zp) 0 groups) := by
  rw [toK_irEvalW U hU _ hir, tabIr_map, tabIr_eval _ (cstW_map_std U)]

/-- **`SC_FZC`'s `poly(vals)` read in `K`**: `hostTerms` with the ACT tuple, the product clause and the pad term. -/
theorem fzc_code_eval (Rr : FzcR) (K' : FzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (amqK nb nb2 : Fp2)
    (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ)) (hir : (fzcIr cstW Rr K' lks mu nu amqK nb nb2 zp groups).Canon)
    (v : List Fp2) :
    (irEvalW (fzcIr cstW Rr K' lks mu nu amqK nb nb2 zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        hostTerms w Rr.tau Rr.pg Rr.pu Rr.gate Rr.gate (nu.map (Fp2.toK U))
          (logupSem c w Rr.h0 (fun k => m.getD (2 + k) 0) 0 (lks.map (LkD.map (Fp2.toK U)))
            + m.getD 1 0 * fzcAct w Rr (amqK.toK U) (nb.toK U) (nb2.toK U)
            + padSem c w (m.getD (2 + ((lks.map (LkD.map (Fp2.toK U))).length + 1) / 2) 0) (Fp2.toK U ∘ zp) 0 groups
            + gV w Rr.gate * batchV m (fzcClauses c Rr K' w))
          (reqV c w K'.sgate Rr.g Rr.rg) (reqV c w K'.sup Rr.u Rr.ru) := by
  rw [toK_irEvalW U hU _ hir, fzcIr_map, fzcIr_eval _ (cstW_map_std U)]

/-- **`SC_QZC` / `SC_KVZC`'s `poly(vals)` read in `K`**: `hostTerms` with the RoPE clause and the pad term. -/
theorem qzc_code_eval (Rr : QzcR) (K' : QzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (hir : (qzcIr cstW Rr K' lks mu nu zp groups).Canon) (v : List Fp2) :
    (irEvalW (qzcIr cstW Rr K' lks mu nu zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        hostTerms w Rr.tau Rr.p1 Rr.p2 Rr.gate Rr.gate (nu.map (Fp2.toK U))
          (logupSem c w Rr.h0 (fun k => m.getD (1 + k) 0) 0 (lks.map (LkD.map (Fp2.toK U)))
            + padSem c w (m.getD (1 + ((lks.map (LkD.map (Fp2.toK U))).length + 1) / 2) 0) (Fp2.toK U ∘ zp) 0 groups
            + gV w Rr.gate * batchV m (qzcClauses c Rr K' w))
          (reqV c w K'.s1 Rr.src Rr.r1) (reqV c w K'.s2 Rr.oth Rr.r2) := by
  rw [toK_irEvalW U hU _ hir, qzcIr_map, qzcIr_eval _ (cstW_map_std U)]

/-- **`SC_SZC`'s `poly(vals)` read in `K`**: `hostTerms` with the exp tuple, the softmax clauses, the pad term, and its
two gated hosts (`sum + λ` under `supp(Ht)`, the score's requantization under `supp(S)`). -/
theorem szc_code_eval (Rr : SzcR) (K' : SzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (amdK nb lam : Fp2)
    (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ)) (hir : (szcIr cstW Rr K' lks mu nu amdK nb lam zp groups).Canon)
    (v : List Fp2) :
    (irEvalW (szcIr cstW Rr K' lks mu nu amdK nb lam zp groups) v).toK U
      = let c := cstW.map (Fp2.toK U)
        let w := v.map (Fp2.toK U)
        let m := mu.map (Fp2.toK U)
        hostTerms w Rr.tau Rr.pht Rr.ps Rr.gHt Rr.gS (nu.map (Fp2.toK U))
          (logupSem c w Rr.h0 (fun k => m.getD (4 + k) 0) 0 (lks.map (LkD.map (Fp2.toK U)))
            + m.getD (4 + ((lks.map (LkD.map (Fp2.toK U))).length + 1) / 2) 0
              * szcExp c Rr K' w (amdK.toK U) (nb.toK U)
            + padSem c w (m.getD (5 + ((lks.map (LkD.map (Fp2.toK U))).length + 1) / 2) 0) (Fp2.toK U ∘ zp) 0 groups
            + gV w Rr.gS * batchV m (szcClauses c Rr K' w))
          (w.getD Rr.sum 0 + lam.toK U) (reqV c w K'.score Rr.s8 Rr.rsl) := by
  rw [toK_irEvalW U hU _ hir, szcIr_map, szcIr_eval _ (cstW_map_std U)]

end Code

/-! ## Canonicity: build over the canonical words, read back -/

section Canon

open ZK60.Exec ZK60.Exec.Slot

/-- The canonical words. -/
abbrev CanonW : Type := {x : Fp2 // x.Canon}

/-- **The code's constants as canonical words** (`Fp2::ONE`, its negation, `ZERO`, `from_i64`, `from_base(Fp::new)`,
`from_u64`: each a reduced word). -/
def cstC : Cst CanonW :=
  ⟨⟨Fp2.one, Fp2.canon_one⟩, ⟨Fp2.one.neg, Fp.neg_canon _ Fp2.canon_one.1, Fp.neg_canon _ Fp2.canon_one.2⟩,
    ⟨Fp2.zero, Fp2.canon_zero⟩,
    fun v => ⟨Fp2.fromBase (Fp.fromI64 v), Fp2.canon_fromBase _ (by unfold Fp.fromI64; split_ifs <;> exact Fp.new_canon _)⟩,
    fun k => ⟨Fp2.fromBase (Fp.new (UInt64.ofNat (2 ^ (16 * k)))), Fp2.canon_fromBase _ (Fp.new_canon _)⟩,
    fun k => ⟨Fp2.fromU64 (UInt64.ofNat (2 ^ (8 * k))), Fp2.canon_fromU64 _⟩⟩

theorem cstC_map : cstC.map Subtype.val = cstW := rfl

/-- An IR read back from canonical words is canonical. -/
theorem canon_map_val (ir : Ir CanonW) : (ir.map Subtype.val).Canon := by
  refine ⟨fun b hb => ?_, fun t ht => ?_⟩
  · obtain ⟨b', -, rfl⟩ := List.mem_map.mp hb
    cases b' with
    | affine k ts => exact k.2
    | sum ss =>
      intro s hs
      obtain ⟨s', -, rfl⟩ := List.mem_map.mp hs
      exact s'.coef.2
  · obtain ⟨t', -, rfl⟩ := List.mem_map.mp ht
    exact t'.coef.2

/-- A list of canonical words, as canonical words. -/
def liftL (l : List Fp2) (h : ∀ x ∈ l, x.Canon) : List CanonW := l.attach.map fun x => ⟨x.1, h x.1 x.2⟩

theorem liftL_val (l : List Fp2) (h : ∀ x ∈ l, x.Canon) : (liftL l h).map Subtype.val = l := by
  unfold liftL
  rw [List.map_map]
  conv_rhs => rw [← List.attach_map_subtype_val l]
  rfl

/-- A LogUp lookup with canonical words, as canonical words. -/
def liftLk (l : LkD Fp2) (h : l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon) : LkD CanonW :=
  ⟨⟨l.konst, h.1⟩, l.terms.attach.map fun t => (⟨t.1.1, h.2 t.1 t.2⟩, t.1.2)⟩

theorem liftLk_val (l : LkD Fp2) (h : l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon) :
    LkD.map Subtype.val (liftLk l h) = l := by
  obtain ⟨k, ts⟩ := l
  unfold liftLk LkD.map
  simp only [List.map_map]
  congr 1
  conv_rhs => rw [← List.attach_map_subtype_val ts]
  rfl

/-- The block's lookups with canonical words, as canonical words. -/
def lks_lift (lks : List (LkD Fp2)) (h : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon) : List (LkD CanonW) :=
  lks.attach.map fun l => liftLk l.1 (h l.1 l.2)

theorem lks_lift_val (lks : List (LkD Fp2)) (h : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon) :
    (lks_lift lks h).map (LkD.map Subtype.val) = lks := by
  unfold lks_lift
  rw [List.map_map]
  conv_rhs => rw [← List.attach_map_subtype_val lks]
  refine List.map_congr_left fun l _ => ?_
  exact liftLk_val l.1 (h l.1 l.2)

/-- **`SC_DZC`'s IR at the code's words is canonical** for canonical draws and LogUp constants. -/
theorem dzcIr_canon (Rr : DzcR) (K' : DzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (hl : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon)
    (hmu : ∀ x ∈ mu, x.Canon) (hnu : ∀ x ∈ nu, x.Canon) (hzp : ∀ j, (zp j).Canon) :
    (dzcIr cstW Rr K' lks mu nu zp groups).Canon := by
  have h := canon_map_val (dzcIr cstC Rr K' (lks_lift lks hl) (liftL mu hmu) (liftL nu hnu) (fun j => ⟨zp j, hzp j⟩)
    groups)
  rw [dzcIr_map, cstC_map, lks_lift_val, liftL_val, liftL_val] at h
  exact h

theorem tzcIr_canon (Rr : TzcR) (ceps : ℤ) (mu nu : List Fp2) (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ))
    (hmu : ∀ x ∈ mu, x.Canon) (hnu : ∀ x ∈ nu, x.Canon) (hzp : ∀ j, (zp j).Canon) :
    (tzcIr cstW Rr ceps mu nu zp groups).Canon := by
  have h := canon_map_val (tzcIr cstC Rr ceps (liftL mu hmu) (liftL nu hnu) (fun j => ⟨zp j, hzp j⟩) groups)
  rw [tzcIr_map, cstC_map, liftL_val, liftL_val] at h
  exact h

theorem fzcIr_canon (Rr : FzcR) (K' : FzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (amqK nb nb2 : Fp2)
    (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ)) (hl : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon)
    (hmu : ∀ x ∈ mu, x.Canon) (hnu : ∀ x ∈ nu, x.Canon) (ha : amqK.Canon) (hb : nb.Canon) (hb2 : nb2.Canon)
    (hzp : ∀ j, (zp j).Canon) : (fzcIr cstW Rr K' lks mu nu amqK nb nb2 zp groups).Canon := by
  have h := canon_map_val (fzcIr cstC Rr K' (lks_lift lks hl) (liftL mu hmu) (liftL nu hnu) ⟨amqK, ha⟩ ⟨nb, hb⟩
    ⟨nb2, hb2⟩ (fun j => ⟨zp j, hzp j⟩) groups)
  rw [fzcIr_map, cstC_map, lks_lift_val, liftL_val, liftL_val] at h
  exact h

theorem qzcIr_canon (Rr : QzcR) (K' : QzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (hl : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon)
    (hmu : ∀ x ∈ mu, x.Canon) (hnu : ∀ x ∈ nu, x.Canon) (hzp : ∀ j, (zp j).Canon) :
    (qzcIr cstW Rr K' lks mu nu zp groups).Canon := by
  have h := canon_map_val (qzcIr cstC Rr K' (lks_lift lks hl) (liftL mu hmu) (liftL nu hnu) (fun j => ⟨zp j, hzp j⟩)
    groups)
  rw [qzcIr_map, cstC_map, lks_lift_val, liftL_val, liftL_val] at h
  exact h

theorem szcIr_canon (Rr : SzcR) (K' : SzcK) (lks : List (LkD Fp2)) (mu nu : List Fp2) (amdK nb lam : Fp2)
    (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ)) (hl : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon)
    (hmu : ∀ x ∈ mu, x.Canon) (hnu : ∀ x ∈ nu, x.Canon) (ha : amdK.Canon) (hb : nb.Canon) (hlam : lam.Canon)
    (hzp : ∀ j, (zp j).Canon) : (szcIr cstW Rr K' lks mu nu amdK nb lam zp groups).Canon := by
  have h := canon_map_val (szcIr cstC Rr K' (lks_lift lks hl) (liftL mu hmu) (liftL nu hnu) ⟨amdK, ha⟩ ⟨nb, hb⟩
    ⟨lam, hlam⟩ (fun j => ⟨zp j, hzp j⟩) groups)
  rw [szcIr_map, cstC_map, lks_lift_val, liftL_val, liftL_val] at h
  exact h

theorem lzcIr_canon (tau h0 : ℕ) (lks : List (LkD Fp2)) (muPad : Fp2) (zp : ℕ → Fp2) (groups : List (ℕ × List ℕ))
    (hl : ∀ l ∈ lks, l.konst.Canon ∧ ∀ t ∈ l.terms, t.1.Canon) (hm : muPad.Canon) (hzp : ∀ j, (zp j).Canon) :
    (lzcIr cstW tau h0 lks muPad zp groups).Canon := by
  have h := canon_map_val (lzcIr cstC tau h0 (lks_lift lks hl) ⟨muPad, hm⟩ (fun j => ⟨zp j, hzp j⟩) groups)
  rw [lzcIr_map, cstC_map, lks_lift_val] at h
  exact h

theorem tabIr_canon (tau : ℕ) (alpha : Fp2) (ts : List (ℕ × ℕ × ℕ)) (mu : List Fp2) (zp : ℕ → Fp2)
    (groups : List (ℕ × List ℕ)) (ha : alpha.Canon) (hmu : ∀ x ∈ mu, x.Canon) (hzp : ∀ j, (zp j).Canon) :
    (tabIr cstW tau alpha ts mu zp groups).Canon := by
  have h := canon_map_val (tabIr cstC tau ⟨alpha, ha⟩ ts (liftL mu hmu) (fun j => ⟨zp j, hzp j⟩) groups)
  rw [tabIr_map, cstC_map, liftL_val] at h
  exact h

theorem ssIr_canon (eq a : ℕ) (g : Option ℕ) : (ssIr cstW eq a g).Canon := by
  have h := canon_map_val (ssIr cstC eq a g)
  rwa [ssIr_map, cstC_map] at h

theorem rsIr_canon (eq mask e z : ℕ) (g : Option ℕ) (lam : Fp2) (hl : lam.Canon) :
    (rsIr cstW eq mask e z g lam).Canon := by
  have h := canon_map_val (rsIr cstC eq mask e z g ⟨lam, hl⟩)
  rwa [rsIr_map, cstC_map] at h

theorem mmIr_canon (a w : ℕ) : (mmIr cstW a w).Canon := by
  have h := canon_map_val (mmIr cstC a w)
  rwa [mmIr_map, cstC_map] at h

theorem bilIr_canon (geq : Option ℕ) (a b : ℕ) : (bilIr cstW geq a b).Canon := by
  have h := canon_map_val (bilIr cstC geq a b)
  rwa [bilIr_map, cstC_map] at h

theorem zsIr_canon (ones u : ℕ) : (zsIr cstW ones u).Canon := by
  have h := canon_map_val (zsIr cstC ones u)
  rwa [zsIr_map, cstC_map] at h

theorem ioIr_canon (tau a ep : ℕ) : (ioIr cstW tau a ep).Canon := by
  have h := canon_map_val (ioIr cstC tau a ep)
  rwa [ioIr_map, cstC_map] at h

end Canon

end ZK60.Exec.Slot.Compose
