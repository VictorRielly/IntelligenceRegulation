/-
D63 lane L35 (2026-11-09), part 11: **the tables part of the slot polynomials as a DEFINITION, with its unfolding
lemmas** (for lane L36's finding L36-2: the hosts' named sums read `Poly` on the whole Boolean cube, so they need its
definition, not only the one-point identity `hPoly`).

* `polyXof_apply`, `polyS_apply`: `Poly cu rt k sn x` is the slot's IR, read in the field, on its tables' extensions;
* **`polyS_seenOf`**: at the trace's own `Seen` of slot `k` (`seenOf bga rs k` with `rs[k]? = some r`), `define`'s
  inputs are the history `histOf β γ α (rs.take k)` and the slot's draws `r.draws`;
* `tabK_eq`, `tabK_pub`, `tabK_priv`: a table's extension by its kind;
* `dXof_rows_a`, `dXof_X_a`, `dXof_X_h`, `dXof_X_inp`, `dXof_X_out`: the committed matrices of `dXof`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BlockDefineFinal

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Exec
open ZK60.Exec.Slot
open ZK60.Circuit (gP GF)

section Unfold

variable {K : Type} [Field K] [Algebra GF K] (U : K)

theorem polyS_apply (P : BlockParams) (D : CmData K P) (prog : List SlotS) (pubs : PubTabs) (k : ℕ) (sn : Seen)
    (x : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) :
    polyS U P D prog pubs k sn x
      = irEval (((prog.getD k SlotS.empty).ir.map (Sym.eval (histSeen sn k) k (drSeen sn k))).map (Fp2.toK U))
          (((prog.getD k SlotS.empty).tabs.map
              (TabS.eval (Sym.eval (histSeen sn k) k (drSeen sn k)) (pubs k (histSeen sn k) (drSeen sn k)))).map
            (tabK U P D (slotShape P k).1 (slotShape P k).2.1 x)) := rfl

/-- **The tables part at the trace's own view of slot `k`.** -/
theorem polyS_seenOf (P : BlockParams) (D : CmData K P) (prog : List SlotS) (pubs : PubTabs)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r)
    (x : Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) :
    polyS U P D prog pubs k (seenOf bga rs k) x
      = irEval (((prog.getD k SlotS.empty).ir.map
            (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)).map (Fp2.toK U))
          (((prog.getD k SlotS.empty).tabs.map
              (TabS.eval (Sym.eval (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) k r.draws)
                (pubs k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws))).map
            (tabK U P D (slotShape P k).1 (slotShape P k).2.1 x)) := by
  rw [polyS_apply, histSeen_seenOf, drSeen_seenOf bga rs k r hr]

theorem polyXof_apply (tag : MTag) {L : ℕ} (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14)
    (h Q e rA rH : ℕ) (rE QE : Cm → ℕ)
    (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
    (prog : List SlotS) (pubs : PubTabs) (cu : Cuts3 L) (rt : RootsO) :
    polyXof U tag hL20 P hlc h Q e rA rH rE QE XE prog pubs cu rt
      = polyS U P (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt) prog pubs := rfl

theorem tabK_eq (P : BlockParams) (D : CmData K P) (n e : ℕ) {N : ℕ} (x : Fin N → K) (point : List Fp2)
    (start : ℕ) :
    tabK U P D n e x (.eq point start)
      = selK n e x * eqPoly (fun a : Fin point.length => (point.getD a Fp2.zero).toK U)
          (fun a : Fin point.length => xrK n x (start + a)) := rfl

theorem tabK_pub (P : BlockParams) (D : CmData K P) (n e : ℕ) {N : ℕ} (x : Fin N → K) (v : List Fp2) :
    tabK U P D n e x (.pub v)
      = selK n e x
        * mleAt (fun b : Fin n → Bool => (v.getD (msbIndex n b) Fp2.zero).toK U) (fun a : Fin n => xrK n x a) := rfl

theorem tabK_priv (P : BlockParams) (D : CmData K P) (n e : ℕ) {N : ℕ} (x : Fin N → K) (p : Priv) :
    tabK U P D n e x (.priv p)
      = claimK (rowLog P p.cm) (D.rows p.cm) (D.Q p.cm) (D.X p.cm)
          ((privSpecs U P n e p).map (specPart (ptK U (xrK n x) p.coords) x)) := rfl

end Unfold

section Matrices

variable {K : Type} [Field K] [Algebra GF K]

variable (tag : MTag) {L : ℕ} (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hlc : P.logCols = 14) (h Q e rA rH : ℕ)
  (rE QE : Cm → ℕ) (XE : Cuts3 L → RootsO → (cm : Cm) → Fin (rE cm) → Fin (2 ^ rowLog P cm + QE cm) → K)
  (cu : Cuts3 L) (rt : RootsO)

theorem dXof_rows_a : (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).rows .a = rA := rfl

theorem dXof_rows_h : (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).rows .h = rH := rfl

theorem dXof_X_a (i : Fin rA) (t : Fin (2 ^ P.logCols + Q)) :
    (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).X .a i t
      = Link.xAof tag L (Link.le64_of_le20 hL20) h Q e rA cu rt i (colCast P hlc Q t) := rfl

theorem dXof_X_h (i : Fin rH) (t : Fin (2 ^ P.logCols + Q)) :
    (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).X .h i t
      = Link.xHof tag L (Link.le64_of_le20 hL20) h Q e rH cu rt i (colCast P hlc Q t) := rfl

theorem dXof_X_inp : (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).X .inp = XE cu rt .inp := rfl

theorem dXof_X_out : (dXof tag hL20 P hlc h Q e rA rH rE QE XE cu rt).X .out = XE cu rt .out := rfl

end Matrices

end ZK60.Exec.Block
