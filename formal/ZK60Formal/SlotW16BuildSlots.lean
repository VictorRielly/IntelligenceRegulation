/-
D63 step L13, part 3: **each W16R2 slot's polynomial, evaluated** (the ports of `SlotW16Build.lean`, the template of
`SlotW16BuildEval.lean`). For a commutative ring and coefficient constants with `one = 1`, `negOne = −1`, `zero = 0`
(`Cst.Std`: the code's words read in `K` are such, `cstW_map_std`), at ANY terminal values `v`:

* every host slot's polynomial is `hostTerms`: `eq(τ)·Z + ν₀·eq(p₁)·(gate·host₁) + ν₁·eq(p₂)·(gate·host₂)`, the
  integrand of `SlotW16Sound.hostPoly`, with `Z = logupSem + [the slot's tuple relation] + padSem + gate·Σ_k μ_k·c_k`
  and the clauses `c_k` and the hosts named here (`dzcClauses`, `fzcClauses`, `qzcClauses`, `szcClauses`,
  `tzcClauses`; `reqV`, the requantization host `2^s·x + limbs − 2^(s−1)`);
* the standalone zero-checks (`SC_LZC`, `SC_TAB`, `SC_IO_*`) are `eq(τ)·Z`;
* the private slots are their summands (`supp·eq·x²`, `supp·eq·(mask·e + λ·zsel)`, `a·w`, `eq(r_g)·a·b`, `ones·u`).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`): `ssIr_eval`, `rsIr_eval`, `mmIr_eval`, `bilIr_eval`,
`zsIr_eval`, `ioIr_eval`, `tzcIr_eval`, `lzcIr_eval`, `tabIr_eval`, **`dzcIr_eval`**, **`fzcIr_eval`**,
**`qzcIr_eval`**, **`szcIr_eval`**, and `post2_vals`, `threeTerms_eval` on the way.
-/
import ZK60Formal.SlotW16BuildEval

-- The evaluation proofs try a short list of simp sets (`first | … | …`) and use broad simp sets; Mathlib's style
-- linters flag the alternatives not taken and the simp arguments a branch did not need. Style warnings only.
set_option linter.unusedSimpArgs false
set_option linter.unreachableTactic false
set_option linter.unusedTactic false
set_option linter.unnecessarySeqFocus false


namespace ZK60.Exec.Slot.Build

open ZK60.Exec ZK60.Exec.Slot

variable {R : Type} [CommRing R]

/-- The constants of a ring are standard: `one = 1`, `negOne = −1`, `zero = 0`. -/
structure Cst.Std (c : Cst R) : Prop where
  one : c.one = 1
  negOne : c.negOne = -1
  zero : c.zero = 0

/-! ## Named values -/

/-- A 16-bit limb decomposition's value `Σ_k 2^(16k)·t_k`. -/
def L16 (c : Cst R) (v : List R) (ix : List ℕ) : R := (ix.zipIdx.map fun q => c.p16 q.2 * v.getD q.1 0).sum

/-- A byte limb decomposition's value `Σ_k 256^k·t_k`. -/
def L256 (c : Cst R) (v : List R) (ix : List ℕ) : R := (ix.zipIdx.map fun q => c.p256 q.2 * v.getD q.1 0).sum

/-- A gate's value: the support table's, or `1` without one. -/
def gV (v : List R) (g : Option ℕ) : R := (g.toList.map fun t => v.getD t 0).prod

/-- **A requantization host** `2^s·x + limbs − 2^(s−1)`. -/
def reqV (c : Cst R) (v : List R) (s x : ℕ) (l : List ℕ) : R :=
  c.base (2 ^ s) * v.getD x 0 + L16 c v l + c.base (-(2 ^ (s - 1) : ℤ))

/-- A batch `Σ_k μ_k·c_k`. -/
def batchV (mu : List R) (cs : List R) : R := (cs.zipIdx.map fun q => mu.getD q.2 0 * q.1).sum

/-- **The three host terms** (`three_terms`; `SlotW16Sound.hostPoly`'s integrand): `eq(τ)·Z + ν₀·eq(p₁)·(gate·h₁) +
ν₁·eq(p₂)·(gate·h₂)`. -/
def hostTerms (v : List R) (tau p1 p2 : ℕ) (g₁ g₂ : Option ℕ) (nu : List R) (z h₁ h₂ : R) : R :=
  v.getD tau 0 * z + nu.getD 0 0 * (v.getD p1 0 * (gV v g₁ * h₁)) + nu.getD 1 0 * (v.getD p2 0 * (gV v g₂ * h₂))

/-! ## Evaluation helpers -/

section Help

theorem bodyVal_affine (v nv : List R) (k : R) (ts : List (R × ℕ)) :
    bodyVal v nv (.affine k ts) = k + (ts.map fun p => p.1 * v.getD p.2 0).sum := rfl

theorem gV_some (v : List R) (t : ℕ) : gV v (some t) = v.getD t 0 := by simp [gV]

theorem gV_none (v : List R) : gV v none = 1 := by simp [gV]

theorem prod_gate (v : List R) (g : Option ℕ) (x : R) :
    ((g.toList.map fun t => v.getD t 0) ++ [x]).prod = gV v g * x := by
  cases g <;> simp [gV]

theorem bodyVal_limbs16 (c : Cst R) (hc : c.Std) (v nv : List R) (ix : List ℕ) :
    bodyVal v nv (limbs16B c ix) = L16 c v ix := by
  simp [limbs16B, bodyVal_sum, bodyVal_affine, stVal, L16, List.map_map, hc.zero, Function.comp_def]

theorem bodyVal_limbs256 (c : Cst R) (hc : c.Std) (v nv : List R) (ix : List ℕ) :
    bodyVal v nv (limbsB c ix) = L256 c v ix := by
  simp [limbsB, bodyVal_sum, bodyVal_affine, stVal, L256, List.map_map, hc.zero, Function.comp_def]

theorem bodyVal_req (c : Cst R) (hc : c.Std) (v nv : List R) (s x l : ℕ) :
    bodyVal v nv (reqB c s x l) = c.base (2 ^ s) * v.getD x 0 + nv.getD l 0 + c.base (-(2 ^ (s - 1) : ℤ)) := by
  simp [reqB, bodyVal_sum, bodyVal_affine, stVal, st, fval, hc.one]
  ring

/-- **A node's value is its body's at the values of the nodes before it.** -/
theorem nodeVals_getD (v : List R) (bs : List (Body R)) (i : ℕ) (hi : i < bs.length) :
    (nodeVals v bs []).getD i 0 = bodyVal v (nodeVals v (bs.take i) []) bs[i] := by
  have hs : bs = bs.take i ++ [bs[i]] ++ bs.drop (i + 1) := by
    rw [List.append_assoc, List.singleton_append, List.cons_getElem_drop_succ, List.take_append_drop]
  have hl : (nodeVals v (bs.take i) []).length = i := by
    rw [nodeVals_length]; simp; omega
  conv_lhs => rw [hs]
  rw [nodeVals_append, nodeVals_append]
  obtain ⟨t, ht, -⟩ := nodeVals_ext v (bs.drop (i + 1)) (nodeVals v [bs[i]] (nodeVals v (bs.take i) []))
  rw [ht]
  have e := getD_len (nodeVals v (bs.take i) []) ([bodyVal v (nodeVals v (bs.take i) []) bs[i]] ++ t) (0 : R)
  rw [hl] at e
  simp only [nodeVals]
  rw [List.append_assoc, e]
  rfl

/-- A gated subterm's value: `gate·node`. -/
theorem stVal_gated (c : Cst R) (hc : c.Std) (v nv : List R) (g : Option ℕ) (n : ℕ) :
    stVal v nv (gatedSt c g n) = gV v g * nv.getD n 0 := by
  cases g <;> simp [stVal, gatedSt, st, fval, gV, hc.one]

/-- **The two requantization hosts after the zero-check node** (`dzc_w16`, `fzc_w16`, `qzc_w16`'s host nodes). -/
theorem post2_vals (c : Cst R) (hc : c.Std) (v A : List R) (z : R) (l₁ : List ℕ) (s₁ x₁ : ℕ) (l₂ : List ℕ)
    (s₂ x₂ : ℕ) :
    nodeVals v [limbs16B c l₁, reqB c s₁ x₁ (A.length + 1), limbs16B c l₂, reqB c s₂ x₂ (A.length + 1 + 2)] (A ++ [z])
      = A ++ [z, L16 c v l₁, reqV c v s₁ x₁ l₁, L16 c v l₂, reqV c v s₂ x₂ l₂] := by
  simp only [nodeVals, bodyVal_limbs16 c hc, bodyVal_req c hc, List.append_assoc, List.singleton_append,
    List.cons_append, List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, reqV]

/-- **The three terms, evaluated** against the node values `A ++ [z, _, h₁, _, h₂]`. -/
theorem threeTerms_eval (c : Cst R) (hc : c.Std) (v A : List R) (eqs : ℕ × ℕ × ℕ) (g : Option ℕ) (nu : List R)
    (z y₁ h₁ y₂ h₂ : R) :
    ((threeTerms c eqs g A.length nu (A.length + 2) (A.length + 4)).map
        (termVal v (A ++ [z, y₁, h₁, y₂, h₂]))).sum
      = hostTerms v eqs.1 eqs.2.1 eqs.2.2 g g nu z h₁ h₂ := by
  simp only [threeTerms, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, termVal, fval, getD_len,
    getD_len_add, List.getD_cons_zero, List.getD_cons_succ, List.prod_cons, List.prod_nil, hc.one, hc.zero,
    hostTerms]
  cases g <;> simp [gV] <;> ring

/-- The three terms when the two hosts follow the zero-check node directly (`SC_TZC`). -/
theorem threeTerms_eval2 (c : Cst R) (hc : c.Std) (v A : List R) (eqs : ℕ × ℕ × ℕ) (g : Option ℕ) (nu : List R)
    (z h₁ h₂ : R) :
    ((threeTerms c eqs g A.length nu (A.length + 1) (A.length + 2)).map (termVal v (A ++ [z, h₁, h₂]))).sum
      = hostTerms v eqs.1 eqs.2.1 eqs.2.2 g g nu z h₁ h₂ := by
  simp only [threeTerms, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, termVal, fval, getD_len,
    getD_len_add, List.getD_cons_zero, List.getD_cons_succ, List.prod_cons, List.prod_nil, hc.one, hc.zero,
    hostTerms]
  cases g <;> simp [gV] <;> ring

end Help

/-! ## The private and standalone slots of the generic arm -/

theorem ssIr_eval (c : Cst R) (hc : c.Std) (v : List R) (eq a : ℕ) (g : Option ℕ) :
    irEval (ssIr c eq a g) v = gV v g * (v.getD eq 0 * (v.getD a 0 * v.getD a 0)) := by
  cases g <;> simp [ssIr, irEval, termVal, fval, gV, hc.one] <;> ring

theorem rsIr_eval (c : Cst R) (hc : c.Std) (v : List R) (eq mask e z : ℕ) (g : Option ℕ) (lam : R) :
    irEval (rsIr c eq mask e z g lam) v
      = gV v g * (v.getD eq 0 * (v.getD mask 0 * v.getD e 0 + lam * v.getD z 0)) := by
  cases g <;> simp [rsIr, irEval, termVal, fval, gV, hc.one, nodeVals, bodyVal_sum, bodyVal_affine, stVal, st] <;> ring

theorem mmIr_eval (c : Cst R) (hc : c.Std) (v : List R) (a w : ℕ) :
    irEval (mmIr c a w) v = v.getD a 0 * v.getD w 0 := by
  simp [mmIr, irEval, termVal, fval, hc.one]

theorem bilIr_eval (c : Cst R) (hc : c.Std) (v : List R) (geq : Option ℕ) (a b : ℕ) :
    irEval (bilIr c geq a b) v = gV v geq * (v.getD a 0 * v.getD b 0) := by
  cases geq <;> simp [bilIr, irEval, termVal, fval, gV, hc.one] <;> ring

theorem zsIr_eval (c : Cst R) (hc : c.Std) (v : List R) (ones u : ℕ) :
    irEval (zsIr c ones u) v = v.getD ones 0 * v.getD u 0 := by
  simp [zsIr, irEval, termVal, fval, hc.one]

theorem ioIr_eval (c : Cst R) (hc : c.Std) (v : List R) (tau a ep : ℕ) :
    irEval (ioIr c tau a ep) v = v.getD tau 0 * (v.getD a 0 - v.getD ep 0) := by
  simp [ioIr, irEval, termVal, fval, hc.one, hc.negOne, nodeVals, bodyVal_sum, bodyVal_affine, stVal, st]
  ring

/-! ## `SC_DZC` -/

/-- **`dzc_w16`'s six clauses** (argument_accuracy.rs:483-488): `c0 = 2cn·γ_a·x + 2^tn·d − 2^(tn+1)·y·d − nr`,
`c1 = nr + ns + 1 − 2^(tn+1)·d`, `c2 = x1 − x − ao`, `c3`, `c4` the same for the second norm, `c5 = x2 − x1 − z`. -/
def dzcClauses (c : Cst R) (Rr : DzcR) (K : DzcK) (v : List R) : List R :=
  [c.base K.num * (v.getD Rr.ig 0 * v.getD Rr.x 0) + c.base K.dv * v.getD Rr.id 0
      + c.base (-K.den) * (v.getD Rr.y 0 * v.getD Rr.id 0) - L16 c v Rr.nr,
    L16 c v Rr.nr + L16 c v Rr.ns + 1 + c.base (-K.den) * v.getD Rr.id 0,
    v.getD Rr.x1 0 - v.getD Rr.x 0 - v.getD Rr.ao 0,
    c.base K.numM * (v.getD Rr.igm 0 * v.getD Rr.x1 0) + c.base K.dv * v.getD Rr.idm 0
      + c.base (-K.den) * (v.getD Rr.ym 0 * v.getD Rr.idm 0) - L16 c v Rr.mr,
    L16 c v Rr.mr + L16 c v Rr.ms + 1 + c.base (-K.den) * v.getD Rr.idm 0,
    v.getD Rr.x2 0 - v.getD Rr.x1 0 - v.getD Rr.z 0]

/-- **`SC_DZC`'s polynomial** (`dzc_w16`): the host terms with `Z = logup + pad + gate·Σ_k μ_k·c_k` and the hosts
`SC_WO` (`2^ao·ao + ral − 2^(ao−1)`), `SC_DMM` (`2^down·z + rdl − 2^(down−1)`). -/
theorem dzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : DzcR) (K : DzcK) (lks : List (LkD R)) (mu nu : List R)
    (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (dzcIr c Rr K lks mu nu zp groups) v
      = hostTerms v Rr.tau Rr.pa Rr.pz Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (6 + k) 0) 0 lks
            + padSem c v (mu.getD (6 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (dzcClauses c Rr K v))
          (reqV c v K.sao Rr.ao Rr.ral) (reqV c v K.sdown Rr.z Rr.rdl) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (dzcPre c Rr K mu) lks Rr.h0 (fun k => mu.getD (6 + k) c.zero) []
    (mu.getD (6 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gate 10] (dzcPost c Rr K)
    (fun o => threeTerms c (Rr.tau, Rr.pa, Rr.pz) Rr.gate o nu (o + 2) (o + 4))
  have h10 : A.getD 10 0 = batchV mu (dzcClauses c Rr K v) := by
    rw [hAt, getD_lt _ _ _ (by rw [nodeVals_length]; simp [dzcPre])]
    first
    | (simp only [dzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        batchV, dzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [dzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, dzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [dzcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, batchV, dzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
  unfold dzcIr irEval
  rw [hnv, ht]
  simp only [dzcPost]
  rw [post2_vals c hc v A _ Rr.ral K.sao Rr.ao Rr.rdl K.sdown Rr.z, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h10, hc.zero]

/-! ## `SC_FZC` -/

/-- **`fzc_w16`'s product clause** (`f0 = a·u − 2^r·h − rh + 2^(r−1)`) and **its ACT tuple's relation**
(`fact·(α − 2048 − g_act − g − β·a − β²·group) − 1`). -/
def fzcClauses (c : Cst R) (Rr : FzcR) (K : FzcK) (v : List R) : List R :=
  [v.getD Rr.a 0 * v.getD Rr.u 0 + c.base (-(2 ^ K.r : ℤ)) * v.getD Rr.h 0 - L16 c v Rr.rh + c.base (2 ^ (K.r - 1))]

def fzcAct (v : List R) (Rr : FzcR) (amqK nb nb2 : R) : R :=
  v.getD Rr.fact 0 * (amqK - v.getD Rr.g 0 + nb * v.getD Rr.a 0 + nb2 * v.getD Rr.group 0) - 1

theorem fzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : FzcR) (K : FzcK) (lks : List (LkD R)) (mu nu : List R)
    (amqK nb nb2 : R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (fzcIr c Rr K lks mu nu amqK nb nb2 zp groups) v
      = hostTerms v Rr.tau Rr.pg Rr.pu Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (2 + k) 0) 0 lks + mu.getD 1 0 * fzcAct v Rr amqK nb nb2
            + padSem c v (mu.getD (2 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (fzcClauses c Rr K v))
          (reqV c v K.sgate Rr.g Rr.rg) (reqV c v K.sup Rr.u Rr.ru) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (fzcPre c Rr K mu amqK nb nb2) lks Rr.h0
    (fun k => mu.getD (2 + k) c.zero) [st (mu.getD 1 c.zero) [.node 3]]
    (mu.getD (2 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gate 4] (fzcPost c Rr K)
    (fun o => threeTerms c (Rr.tau, Rr.pg, Rr.pu) Rr.gate o nu (o + 2) (o + 4))
  have hlen : (nodeVals v (fzcPre c Rr K mu amqK nb nb2) []).length = 5 := by
    rw [nodeVals_length]; simp [fzcPre]
  have h3 : A.getD 3 0 = fzcAct v Rr amqK nb nb2 := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [fzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        fzcAct, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [fzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, fzcAct, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [fzcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, fzcAct, hc.one, hc.negOne, hc.zero] <;> ring)
  have h4 : A.getD 4 0 = batchV mu (fzcClauses c Rr K v) := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [fzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        batchV, fzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [fzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, fzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [fzcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, batchV, fzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
  unfold fzcIr irEval
  rw [hnv, ht]
  simp only [fzcPost]
  rw [post2_vals c hc v A _ Rr.rg K.sgate Rr.g Rr.ru K.sup Rr.u, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h4, hc.zero]
  simp only [stVal, st, fval, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one, h3, hc.zero]

/-! ## `SC_QZC` / `SC_KVZC` -/

/-- **`qzc_w16`'s RoPE clause** `cos·src + sin·flip − 2^7·rot − rr + 2^6`. -/
def qzcClauses (c : Cst R) (Rr : QzcR) (K : QzcK) (v : List R) : List R :=
  [v.getD Rr.cos 0 * v.getD Rr.src 0 + v.getD Rr.sin 0 * v.getD Rr.flip 0 + c.base (-(2 ^ K.rope : ℤ)) * v.getD Rr.rot 0
    - L16 c v Rr.rr + c.base (2 ^ (K.rope - 1))]

theorem qzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : QzcR) (K : QzcK) (lks : List (LkD R)) (mu nu : List R)
    (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (qzcIr c Rr K lks mu nu zp groups) v
      = hostTerms v Rr.tau Rr.p1 Rr.p2 Rr.gate Rr.gate nu
          (logupSem c v Rr.h0 (fun k => mu.getD (1 + k) 0) 0 lks
            + padSem c v (mu.getD (1 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gate * batchV mu (qzcClauses c Rr K v))
          (reqV c v K.s1 Rr.src Rr.r1) (reqV c v K.s2 Rr.oth Rr.r2) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (qzcPre c Rr K mu) lks Rr.h0 (fun k => mu.getD (1 + k) c.zero) []
    (mu.getD (1 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gate 2] (qzcPost c Rr K)
    (fun o => threeTerms c (Rr.tau, Rr.p1, Rr.p2) Rr.gate o nu (o + 2) (o + 4))
  have h2 : A.getD 2 0 = batchV mu (qzcClauses c Rr K v) := by
    rw [hAt, getD_lt _ _ _ (by rw [nodeVals_length]; simp [qzcPre])]
    first
    | (simp only [qzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        batchV, qzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [qzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, qzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [qzcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, batchV, qzcClauses, hc.one, hc.negOne, hc.zero] <;> ring)
  unfold qzcIr irEval
  rw [hnv, ht]
  simp only [qzcPost]
  rw [post2_vals c hc v A _ Rr.r1 K.s1 Rr.src Rr.r2 K.s2 Rr.oth, threeTerms_eval c hc]
  simp only [List.map_nil, List.sum_nil, add_zero, List.map_cons, List.sum_cons, stVal_gated c hc, h2, hc.zero]

/-! ## `SC_SZC` -/

/-- `δ = mx − mask·s8 + 127·mask − 127`, written as the code writes it (`ms = −MASK_SCORE`). -/
def szcDelta (c : Cst R) (Rr : SzcR) (K : SzcK) (v : List R) : R :=
  v.getD Rr.mx 0 - v.getD Rr.mask 0 * v.getD Rr.s8 0 + c.base (-K.ms) * v.getD Rr.mask 0 + c.base K.ms

/-- **`szc_w16`'s four softmax clauses** (`c0 = zsel² − zsel`, `c1 = zsel·δ`, `c2 = 2^f_p·mask·e − p·sum − sr`,
`c3 = sg + sr + 1 − sum`). -/
def szcClauses (c : Cst R) (Rr : SzcR) (K : SzcK) (v : List R) : List R :=
  [v.getD Rr.zsel 0 * v.getD Rr.zsel 0 - v.getD Rr.zsel 0, v.getD Rr.zsel 0 * szcDelta c Rr K v,
    c.base (2 ^ K.fp) * (v.getD Rr.mask 0 * v.getD Rr.e 0) - v.getD Rr.p 0 * v.getD Rr.sum 0 - L16 c v Rr.sr,
    L16 c v Rr.sg + L16 c v Rr.sr + 1 - v.getD Rr.sum 0]

/-- **The exp tuple's relation** `hx·(α − g_exp − δ − β·e) − 1`. -/
def szcExp (c : Cst R) (Rr : SzcR) (K : SzcK) (v : List R) (amdK nb : R) : R :=
  v.getD Rr.hx 0 * (amdK - szcDelta c Rr K v + nb * v.getD Rr.e 0) - 1

theorem szcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : SzcR) (K : SzcK) (lks : List (LkD R)) (mu nu : List R)
    (amdK nb lam : R) (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (szcIr c Rr K lks mu nu amdK nb lam zp groups) v
      = hostTerms v Rr.tau Rr.pht Rr.ps Rr.gHt Rr.gS nu
          (logupSem c v Rr.h0 (fun k => mu.getD (4 + k) 0) 0 lks
            + mu.getD (4 + (lks.length + 1) / 2) 0 * szcExp c Rr K v amdK nb
            + padSem c v (mu.getD (5 + (lks.length + 1) / 2) 0) zp 0 groups
            + gV v Rr.gS * batchV mu (szcClauses c Rr K v))
          (v.getD Rr.sum 0 + lam) (reqV c v K.score Rr.s8 Rr.rsl) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (szcPre c Rr K mu amdK nb) lks Rr.h0
    (fun k => mu.getD (4 + k) c.zero) [st (mu.getD (4 + (lks.length + 1) / 2) c.zero) [.node 8]]
    (mu.getD (5 + (lks.length + 1) / 2) c.zero) zp groups [gatedSt c Rr.gS 9] (szcPost c Rr K lam)
    (fun o => [⟨c.one, [Rr.tau], [.node o]⟩, ⟨nu.getD 0 c.zero, Rr.pht :: Rr.gHt.toList, [.node (o + 1)]⟩,
      ⟨nu.getD 1 c.zero, Rr.ps :: Rr.gS.toList, [.node (o + 3)]⟩])
  have hlen : (nodeVals v (szcPre c Rr K mu amdK nb) []).length = 10 := by
    rw [nodeVals_length]; simp [szcPre]
  have h8 : A.getD 8 0 = szcExp c Rr K v amdK nb := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [szcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        szcExp, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [szcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, szcExp, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [szcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, szcExp, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
  have h9 : A.getD 9 0 = batchV mu (szcClauses c Rr K v) := by
    rw [hAt, getD_lt _ _ _ (by omega)]
    first
    | (simp only [szcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons,
        List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil,
        batchV, szcClauses, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [szcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil,
        List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, szcClauses, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp [szcPre, nodeVals, bodyVal_limbs16 c hc, bodyVal_sum, bodyVal_affine, stVal, batchB, st, fval, batchV, szcClauses, szcDelta, hc.one, hc.negOne, hc.zero] <;> ring)
  have hpost : ∀ z : R, nodeVals v (szcPost c Rr K lam (A.length + 1)) (A ++ [z])
      = A ++ [z, v.getD Rr.sum 0 + lam, L16 c v Rr.rsl, reqV c v K.score Rr.s8 Rr.rsl] := by
    intro z
    simp only [szcPost, nodeVals, bodyVal_limbs16 c hc, bodyVal_req c hc, List.append_assoc, List.singleton_append,
      List.cons_append, List.nil_append, Nat.add_assoc, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, reqV,
      bodyVal_sum, bodyVal_affine, stVal, st, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, fval,
      hc.one, mul_one, one_mul, add_zero]
  unfold szcIr irEval
  rw [hnv, ht, hpost]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal_gated c hc, h9, hc.zero, add_zero]
  simp only [stVal, st, fval, List.map_cons, List.map_nil, List.prod_cons, List.prod_nil, mul_one, h8, hc.zero]
  simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, termVal, fval, getD_len, getD_len_add,
    List.getD_cons_zero, List.getD_cons_succ, List.prod_cons, List.prod_nil, hc.one, hc.zero, hostTerms]
  cases Rr.gHt <;> cases Rr.gS <;> simp [gV] <;> ring

/-! ## `SC_TZC` -/

/-- **`SC_TZC`'s six clauses** (argument.rs:1020-1025): `dsq − d²`, `d − dl`, `2d − a1 − a2` and the same for the
second norm (`dl`, `a1`, `a2` the byte limbs `Σ 256^k·limb_k` of the nine sub-slices). -/
def tzcClauses (c : Cst R) (Rr : TzcR) (v : List R) : List R :=
  [v.getD Rr.dsq 0 - v.getD Rr.d 0 * v.getD Rr.d 0,
    v.getD Rr.d 0 - L256 c v [Rr.dsq + 1, Rr.dsq + 1 + 1, Rr.dsq + 1 + 2],
    c.base 2 * v.getD Rr.d 0 - L256 c v [Rr.dsq + 1 + 3, Rr.dsq + 1 + 4, Rr.dsq + 1 + 5]
      - L256 c v [Rr.dsq + 1 + 6, Rr.dsq + 1 + 7, Rr.dsq + 1 + 8],
    v.getD Rr.dsqm 0 - v.getD Rr.dm 0 * v.getD Rr.dm 0,
    v.getD Rr.dm 0 - L256 c v [Rr.dsqm + 1, Rr.dsqm + 1 + 1, Rr.dsqm + 1 + 2],
    c.base 2 * v.getD Rr.dm 0 - L256 c v [Rr.dsqm + 1 + 3, Rr.dsqm + 1 + 4, Rr.dsqm + 1 + 5]
      - L256 c v [Rr.dsqm + 1 + 6, Rr.dsqm + 1 + 7, Rr.dsqm + 1 + 8]]

theorem tzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (Rr : TzcR) (ceps : ℤ) (mu nu : List R) (zp : ℕ → R)
    (groups : List (ℕ × List ℕ)) :
    irEval (tzcIr c Rr ceps mu nu zp groups) v
      = hostTerms v Rr.tau Rr.rt Rr.rt2 Rr.gate Rr.gate nu
          (batchV mu (tzcClauses c Rr v) + padSem c v (mu.getD 6 0) zp 0 groups)
          (v.getD Rr.dsq 0 + L256 c v [Rr.dsq + 1 + 3, Rr.dsq + 1 + 4, Rr.dsq + 1 + 5] + c.base (-ceps))
          (v.getD Rr.dsqm 0 + L256 c v [Rr.dsqm + 1 + 3, Rr.dsqm + 1 + 4, Rr.dsqm + 1 + 5] + c.base (-ceps)) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (tzcPre c Rr) [] 0 (fun _ => c.zero) (tzcExtra c mu)
    (mu.getD 6 c.zero) zp groups [] (tzcPost c Rr ceps)
    (fun o => threeTerms c (Rr.tau, Rr.rt, Rr.rt2) Rr.gate o nu (o + 1) (o + 2))
  have hlen : (nodeVals v (tzcPre c Rr) []).length = 12 := by
    rw [nodeVals_length]; simp [tzcPre]
  have hv : ∀ (B : List R) (i : ℕ), i < 12 → (A ++ B).getD i 0 = (nodeVals v (tzcPre c Rr) []).getD i 0 := by
    intro B i hi
    rw [hAt, List.append_assoc, getD_lt _ _ _ (by omega)]
  have hv0 : ∀ (i : ℕ), i < 12 → A.getD i 0 = (nodeVals v (tzcPre c Rr) []).getD i 0 := by
    intro i hi
    simpa using hv [] i hi
  have P1 : (nodeVals v (tzcPre c Rr) []).getD 1 0 = L256 c v [Rr.dsq + 1 + 3, Rr.dsq + 1 + 4, Rr.dsq + 1 + 5] := by
    first
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval,
        List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons,
        List.zipIdx_nil, L256, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, List.map_cons, List.map_nil, List.sum_cons,
        List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, L256, hc.one,
        hc.negOne, hc.zero] <;> ring)
    | (simp [tzcPre, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, L256,
        hc.one, hc.negOne, hc.zero] <;> ring)
  have P4 : (nodeVals v (tzcPre c Rr) []).getD 4 0
      = L256 c v [Rr.dsqm + 1 + 3, Rr.dsqm + 1 + 4, Rr.dsqm + 1 + 5] := by
    first
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval,
        List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons,
        List.zipIdx_nil, L256, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, List.map_cons, List.map_nil, List.sum_cons,
        List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, L256, hc.one,
        hc.negOne, hc.zero] <;> ring)
    | (simp [tzcPre, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, L256,
        hc.one, hc.negOne, hc.zero] <;> ring)
  have PZ : ((tzcExtra c mu).map (stVal v A)).sum = batchV mu (tzcClauses c Rr v) := by
    simp only [tzcExtra, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal, st, fval, List.prod_cons,
      List.prod_nil, mul_one, add_zero, hc.zero]
    rw [hv0 6 (by norm_num), hv0 7 (by norm_num), hv0 8 (by norm_num), hv0 9 (by norm_num), hv0 10 (by norm_num),
      hv0 11 (by norm_num)]
    first
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_cons_succ, List.getD_cons_zero, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval,
        List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons,
        List.zipIdx_nil, batchV, tzcClauses, L256, hc.one, hc.negOne, hc.zero] <;> ring)
    | (simp only [tzcPre, nodeVals, List.nil_append, List.append_assoc, List.singleton_append, List.cons_append,
        List.getD_eq_getElem?_getD, List.getElem?_cons_succ, List.getElem?_cons_zero, Option.getD_some,
        bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, List.map_cons, List.map_nil, List.sum_cons,
        List.sum_nil, List.prod_cons, List.prod_nil, List.zipIdx_cons, List.zipIdx_nil, batchV, tzcClauses, L256, hc.one,
        hc.negOne, hc.zero] <;> ring)
    | (simp [tzcPre, nodeVals, bodyVal_limbs256 c hc, bodyVal_sum, bodyVal_affine, stVal, st, fval, batchV, tzcClauses, L256,
        hc.one, hc.negOne, hc.zero] <;> ring)
  have hpost : ∀ z : R, nodeVals v (tzcPost c Rr ceps (A.length + 1)) (A ++ [z])
      = A ++ [z, v.getD Rr.dsq 0 + L256 c v [Rr.dsq + 1 + 3, Rr.dsq + 1 + 4, Rr.dsq + 1 + 5] + c.base (-ceps),
          v.getD Rr.dsqm 0 + L256 c v [Rr.dsqm + 1 + 3, Rr.dsqm + 1 + 4, Rr.dsqm + 1 + 5] + c.base (-ceps)] := by
    intro z
    simp only [tzcPost, nodeVals, bodyVal_sum, stVal, st, fval, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, List.prod_cons, List.prod_nil, List.append_assoc, List.singleton_append, List.cons_append,
      List.nil_append, hc.one, mul_one, one_mul, add_zero]
    rw [hv _ 1 (by norm_num), hv _ 4 (by norm_num), P1, P4]
    simp only [add_assoc]
  unfold tzcIr irEval
  rw [hnv, ht, hpost, threeTerms_eval2 c hc, PZ]
  simp only [List.map_nil, List.sum_nil, add_zero, logupSem, zero_add, hc.zero]

/-! ## `SC_LZC` and `SC_TAB` -/

theorem lzcIr_eval (c : Cst R) (hc : c.Std) (v : List R) (tau h0 : ℕ) (lks : List (LkD R)) (muPad : R) (zp : ℕ → R)
    (groups : List (ℕ × List ℕ)) :
    irEval (lzcIr c tau h0 lks muPad zp groups) v
      = v.getD tau 0 * (logupSem c v h0 (fun _ => c.one) 0 lks + padSem c v muPad zp 0 groups) := by
  obtain ⟨A, -, hnv, ht⟩ := zcIr_vals c v [] lks h0 (fun _ => c.one) [] muPad zp groups [] (fun _ => [])
    (fun o => [⟨c.one, [tau], [.node o]⟩])
  unfold lzcIr irEval
  rw [hnv, ht]
  simp only [nodeVals, termVal, fval, getD_len, List.getD_cons_zero, List.map_cons, List.map_nil, List.sum_cons,
    List.sum_nil, List.prod_cons, List.prod_nil, hc.one, add_zero, zero_add, one_mul, mul_one] <;> ring

/-- **`SC_TAB`'s relations, batched**: `Σ_k μ_k·(h_k·(α − t_k) − m_k)`. -/
def tabSem (v : List R) (alpha : R) (mu : List R) : ℕ → List (ℕ × ℕ × ℕ) → R
  | _, [] => 0
  | k, (m, h, tv) :: ts => mu.getD k 0 * (v.getD h 0 * (alpha - v.getD tv 0) - v.getD m 0) + tabSem v alpha mu (k + 1) ts

theorem tabGo_spec (c : Cst R) (hc : c.Std) (v : List R) (alpha : R) (mu : List R) :
    ∀ (k : ℕ) (ts : List (ℕ × ℕ × ℕ)) (acc t : List R),
      (((tabGo c alpha mu k acc.length ts).1).map
          (stVal v (nodeVals v (tabGo c alpha mu k acc.length ts).2 acc ++ t))).sum
        = tabSem v alpha mu k ts
  | _, [], _, _ => rfl
  | k, (m, h, tv) :: ts, acc, t => by
    have ih := tabGo_spec c hc v alpha mu (k + 1) ts (nodeVals v ([.affine alpha [(c.negOne, tv)],
      .sum [st c.one [.tab h, .node acc.length], st c.negOne [.tab m]]] : List (Body R)) acc) t
    have hl : (nodeVals v ([.affine alpha [(c.negOne, tv)],
        .sum [st c.one [.tab h, .node acc.length], st c.negOne [.tab m]]] : List (Body R)) acc).length
          = acc.length + 2 := by
      rw [nodeVals_length]; rfl
    rw [hl] at ih
    simp only [tabGo]
    rw [nodeVals_append, List.map_cons, List.sum_cons, ih]
    obtain ⟨t', ht', -⟩ := nodeVals_ext v (tabGo c alpha mu (k + 1) (acc.length + 2) ts).2
      (nodeVals v ([.affine alpha [(c.negOne, tv)],
        .sum [st c.one [.tab h, .node acc.length], st c.negOne [.tab m]]] : List (Body R)) acc)
    rw [ht']
    simp only [nodeVals, bodyVal_sum, bodyVal_affine, stVal, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, stVal, st, fval,
      List.prod_cons, List.prod_nil, List.append_assoc, List.singleton_append, List.cons_append, List.nil_append,
      getD_len, getD_len_add, List.getD_cons_succ, List.getD_cons_zero, tabSem, hc.one, hc.negOne, hc.zero]
    ring

theorem tabIr_eval (c : Cst R) (hc : c.Std) (v : List R) (tau : ℕ) (alpha : R) (ts : List (ℕ × ℕ × ℕ)) (mu : List R)
    (zp : ℕ → R) (groups : List (ℕ × List ℕ)) :
    irEval (tabIr c tau alpha ts mu zp groups) v
      = v.getD tau 0 * (tabSem v alpha mu 0 ts + padSem c v (mu.getD ts.length c.zero) zp 0 groups) := by
  obtain ⟨A, ⟨t, hAt⟩, hnv, ht⟩ := zcIr_vals c v (tabGo c alpha mu 0 0 ts).2 [] 0 (fun _ => c.zero)
    (tabGo c alpha mu 0 0 ts).1 (mu.getD ts.length c.zero) zp groups [] (fun _ => [])
    (fun o => [⟨c.one, [tau], [.node o]⟩])
  have hs := tabGo_spec c hc v alpha mu 0 ts [] t
  simp only [List.length_nil] at hs
  have hx : ((tabGo c alpha mu 0 0 ts).1.map (stVal v A)).sum = tabSem v alpha mu 0 ts := by rw [hAt]; exact hs
  unfold tabIr irEval
  rw [hnv, ht, hx]
  simp only [nodeVals, termVal, fval, getD_len, List.getD_cons_zero, List.map_cons, List.map_nil, List.sum_cons,
    List.sum_nil, List.prod_cons, List.prod_nil, hc.one, hc.zero, logupSem, add_zero, zero_add, one_mul, mul_one] <;> ring

end ZK60.Exec.Slot.Build
