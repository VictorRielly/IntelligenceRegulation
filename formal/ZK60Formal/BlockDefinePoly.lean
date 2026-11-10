/-
D63 lane L35 (2026-11-09), part 5: **the tables part of the slot polynomials, for every block whose `define` runs a
slot program** (L31 §6 item 2; L23 §5 item 2).

For `P.define = defineS prog pubs` (`BlockDefineSym.lean`) and committed matrices `D` (one per commitment):

* `histSeen`, `drSeen`, `histSeen_seenOf`, `drSeen_seenOf`: `define`'s inputs at slot `k`, read off what the trace
  shows before the slot's rounds (`Seen`);
* **`polyS`**: the tables part of slot `k`'s polynomial, `irEval` of the slot's IR (read in the field) on its tables'
  extensions at the point (`tabK`, `BlockDefineTab.lean`): a function of what the trace shows and of `D`;
* **`polyS_slotEvalN`** (`hPoly`): at an accepting slot whose claims are TRUE of `D` (`cs` read by L22's `claimSem`),
  `polyS` at the slot's point is `poly(vals)`: L31's `SlotEvalN` with the zero `M` semantics;
* **`polyS_indDeg`** (`hdegP`): its individual degree is the slot's declared degree, from the program's check
  `progOKb` (each private table's coordinates read a challenge at most once; the IR's degree in its tables is at most
  the declared degree);
* **`defineS_polyC`** (`hpolyC`), **`defineS_defCm`** (`hdc`): `define`'s polynomials return canonical words; its
  commitment schedule is the program's count of `A` and `H` tables per slot.

Generic in the profile: W16R2 at any shape, R13 once its slot program exists. Only `propext`, `Classical.choice`,
`Quot.sound`.
-/
import ZK60Formal.BlockDefineSym
import ZK60Formal.BlockInstFinal

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Circuit (gP GF)

/-! ## `define`'s inputs, as the trace shows them -/

/-- The history `define` sees at slot `k`, read off what the trace shows. -/
def histSeen (sn : Seen) (k : ℕ) : Hist := ⟨sn.1.1, sn.1.2.1, sn.1.2.2, (sn.2.take k).map fun r => r.1⟩

/-- Slot `k`'s own draws, read off what the trace shows. -/
def drSeen (sn : Seen) (k : ℕ) : List Fp2 := (sn.2.getD k ([], Fp2.zero, [])).1

theorem take_map_take {α β : Type} (f : α → β) : ∀ (l : List α) (k : ℕ),
    ((l.take (k + 1)).map f).take k = (l.take k).map f
  | [], k => by simp
  | a :: l, 0 => by simp
  | a :: l, k + 1 => by
    simp only [List.take_succ_cons, List.map_cons]
    rw [take_map_take f l k]

theorem histSeen_seenOf (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) :
    histSeen (seenOf bga rs k) k = histOf bga.1 bga.2.1 bga.2.2 (rs.take k) := by
  show (⟨bga.1, bga.2.1, bga.2.2,
      ((((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).take k).map
        fun r => r.1)⟩ : Hist) = ⟨bga.1, bga.2.1, bga.2.2, (rs.take k).map SlotRec.draws⟩
  rw [take_map_take, List.map_map]
  rfl

theorem drSeen_seenOf (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) :
    drSeen (seenOf bga rs k) k = r.draws := by
  show (((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
    ([], Fp2.zero, [])).1 = r.draws
  rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt (Nat.lt_succ_self k), hr]
  rfl

theorem getD_map_dflt {α β : Type} (f : α → β) (d : α) : ∀ (l : List α) (k : ℕ),
    (l.map f).getD k (f d) = f (l.getD k d)
  | [], _ => by simp
  | a :: l, 0 => rfl
  | a :: l, k + 1 => by
    rw [List.map_cons, List.getD_cons_succ, List.getD_cons_succ]
    exact getD_map_dflt f d l k

/-! ## What `define` gives without the challenges' values -/

/-- **`hpolyC`**: a program's definitions return canonical words. -/
theorem defineS_polyC (P : BlockParams) (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs) :
    ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon := by
  intro k hist dr df h vs
  rw [hdef] at h
  obtain ⟨-, rfl⟩ := defineS_ok h
  exact canon_irEvalW _ vs

/-- **`hdc`**: `define`'s commitment schedule is the program's count of `A` and `H` tables per slot. -/
theorem defineS_defCm (P : BlockParams) (prog : List SlotS) (pubs : PubTabs) (hdef : P.define = defineS prog pubs)
    (aC hC : List ℕ) (ha : prog.map (fun s => cmCountS .a s.tabs) = aC)
    (hh : prog.map (fun s => cmCountS .h s.tabs) = hC) : Link.DefCm P aC hC := by
  intro k hist dr df h
  rw [hdef] at h
  obtain ⟨-, rfl⟩ := defineS_ok h
  subst ha
  subst hh
  have ea := getD_map_dflt (fun s : SlotS => cmCountS .a s.tabs) SlotS.empty prog k
  have eh := getD_map_dflt (fun s : SlotS => cmCountS .h s.tabs) SlotS.empty prog k
  refine And.intro ?_ ?_
  · show cmCount .a ((prog.getD k SlotS.empty).tabs.map (TabS.eval (Sym.eval hist k dr) (pubs k hist dr)))
      = (prog.map (fun s => cmCountS .a s.tabs)).getD k 0
    rw [cmCount_eval]
    exact ea.symm
  · show cmCount .h ((prog.getD k SlotS.empty).tabs.map (TabS.eval (Sym.eval hist k dr) (pubs k hist dr)))
      = (prog.map (fun s => cmCountS .h s.tabs)).getD k 0
    rw [cmCount_eval]
    exact eh.symm

/-! ## The tables part of the slot polynomials -/

section Poly

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The tables part of slot `k`'s polynomial**: the slot's IR, its coefficients read in the field, on the slot's
tables' extensions at the point. `define`'s inputs are what the trace shows (`sn`); the private tables read the
committed matrices `D`. -/
def polyS (P : BlockParams) (D : CmData K P) (prog : List SlotS) (pubs : PubTabs) :
    (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K :=
  fun k sn x =>
    irEval (((prog.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))).map (Fp2.toK U))
      (((prog.getD k SlotS.empty).tabs.map
          (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs k (histSeen sn k) (drSeen sn k)))).map
        (tabK U P D (slotShape P k).1 (slotShape P k).2.1 x))

/-- A table list's extensions, entry by entry: individual degree `≤ 1`. -/
theorem tabsK_indDeg (P : BlockParams) (D : CmData K P) (n e : ℕ) {N : ℕ} (tabs : List Tab)
    (h : ∀ t ∈ tabs, TabOK P t) (i : ℕ) :
    IndDegLE 1 (fun x : Fin N → K => (tabs.map (tabK U P D n e x)).getD i 0) := by
  have e1 : (fun x : Fin N → K => (tabs.map (tabK U P D n e x)).getD i 0)
      = fun x => ((tabs[i]?).map (tabK U P D n e x)).getD 0 := by
    funext x
    rw [List.getD_eq_getElem?_getD, List.getElem?_map]
  rw [e1]
  cases ht : tabs[i]? with
  | none => exact ZK60.StageX.IndDegLE.const (0 : K)
  | some t => exact tabK_indDeg U P D n e t (h t (List.mem_of_getElem? ht))

/-- **`hdegP`**: the tables part has the slot's declared individual degree, for a program that passes its check. -/
theorem polyS_indDeg (P : BlockParams) (D : CmData K P) (prog : List SlotS) (pubs : PubTabs)
    (hprog : progOKb (rowLog P) prog P.geom.slots = true) (k : ℕ) (sn : Seen) :
    IndDegLE (slotShape P k).2.2 (polyS U P D prog pubs k sn) := by
  have hk := progOK_getD (rowLog P) prog P.geom.slots hprog k
  unfold slotOKb at hk
  rw [Bool.and_eq_true] at hk
  obtain ⟨htabs, hdeg⟩ := hk
  have hdeg' : irDeg (prog.getD k SlotS.empty).ir ≤ (slotShape P k).2.2 := of_decide_eq_true hdeg
  have hmem := List.all_eq_true.mp htabs
  have hok : ∀ t ∈ (prog.getD k SlotS.empty).tabs.map
      (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs k (histSeen sn k) (drSeen sn k))),
      TabOK P t := by
    intro t ht
    obtain ⟨ts, hts, rfl⟩ := List.mem_map.mp ht
    exact tabOK_eval P _ _ ts (hmem ts hts)
  have h := irEval_indDeg
    (fun x : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K =>
      ((prog.getD k SlotS.empty).tabs.map
        (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs k (histSeen sn k) (drSeen sn k)))).map
        (tabK U P D (slotShape P k).1 (slotShape P k).2.1 x))
    (tabsK_indDeg U P D _ _ _ hok)
    (((prog.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))).map (Fp2.toK U))
  rw [irDeg_map, irDeg_map] at h
  exact ZK60.StageX.IndDegLE.mono h hdeg'

/-- **`hPoly`**: the tables part meets L31's evaluation interface (the zero `M` semantics): at an accepting slot
whose claims are true of the committed matrices, it is `poly(vals)` at the slot's point. -/
theorem polyS_slotEvalN (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (D : CmData K P) (prog : List SlotS)
    (pubs : PubTabs) (cs : Cm → ZClaim → K)
    (hcs : ∀ cm z, cs cm z = Link.claimSem U (D.rows cm) (rowLog P cm) (D.Q cm) (D.X cm) z)
    (hdef : P.define = defineS prog pubs) (hprog : progOKb (rowLog P) prog P.geom.slots = true) :
    SlotEvalN U P cs (fun _ => 0) (polyS U P D prog pubs) := by
  intro core bga rs k r sp df vals rhoFull hsp hr hk hdf hrl hrc hsc hrho hes hvals htrue
  rw [hdef] at hdf
  obtain ⟨hcan, rfl⟩ := defineS_ok hdf
  rw [mul_zero, add_zero]
  have hlr : r.rho.length = (slotShape P k).1 := by
    rw [hrho, List.length_take, hrl]
    omega
  have hle : r.es.length = (slotShape P k).2.1 := by
    rw [hes, List.length_drop, hrl]
    omega
  have hrcan : ∀ a ∈ r.rho, a.Canon := fun a ha => hrc a (by
    rw [hrho] at ha
    exact List.mem_of_mem_take ha)
  have hecan : ∀ a ∈ r.es, a.Canon := fun a ha => hrc a (by
    rw [hes] at ha
    exact List.mem_of_mem_drop ha)
  have hN : (r.rho ++ r.es).length ≤ (slotShape P k).1 + (slotShape P k).2.1 :=
    le_of_eq (by rw [List.length_append, hlr, hle])
  have hkk := progOK_getD (rowLog P) prog P.geom.slots hprog k
  unfold slotOKb at hkk
  rw [Bool.and_eq_true] at hkk
  have hmem := List.all_eq_true.mp hkk.1
  have hok : ∀ t ∈ (prog.getD k SlotS.empty).tabs.map
      (TabS.eval (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)
        (pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws)), TabOK P t := by
    intro t ht
    obtain ⟨ts, hts, rfl⟩ := List.mem_map.mp ht
    exact tabOK_eval P _ _ ts (hmem ts hts)
  have hcn : ∀ t ∈ (prog.getD k SlotS.empty).tabs.map
      (TabS.eval (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)
        (pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws)), TabCanon t := by
    intro t ht
    obtain ⟨ts, -, rfl⟩ := List.mem_map.mp ht
    exact tabCanon_eval hcan _ ts
  have hT := tabVals_toK (N := (slotShape P k).1 + (slotShape P k).2.1) U hU P D cs hcs (slotShape P k).1
    (slotShape P k).2.1 r.rho r.es sp.terms hlr hle hN hrcan hecan
    ((prog.getD k SlotS.empty).tabs.map
      (TabS.eval (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)
        (pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws))) 0 vals hok hcn hvals htrue
  have hL : polyS U P D prog pubs k (seenOf bga rs k)
        (xOf U (r.rho ++ r.es) : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K)
      = irEval (((prog.getD k SlotS.empty).ir.map
            (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)).map (Fp2.toK U))
          (((prog.getD k SlotS.empty).tabs.map
            (TabS.eval (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)
              (pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws))).map
            (tabK U P D (slotShape P k).1 (slotShape P k).2.1
              (xOf U (r.rho ++ r.es) : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K))) := by
    unfold polyS
    rw [histSeen_seenOf, drSeen_seenOf bga rs k r hr]
  show polyS U P D prog pubs k (seenOf bga rs k)
      (xOf U (r.rho ++ r.es) : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K)
    = (irEvalW ((prog.getD k SlotS.empty).ir.map
        (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)) vals).toK U
  have hirc : ((prog.getD k SlotS.empty).ir.map
      (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)).Canon :=
    Ir.canon_map _ (fun s => Sym.eval_canon hcan s) _
  rw [hL, toK_irEvalW U hU _ hirc vals, hT]

end Poly

end ZK60.Exec.Block
