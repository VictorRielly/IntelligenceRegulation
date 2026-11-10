/-
D63 lane L57 (2026-11-10), part 6: **the stage slot polynomials set to the real ones** (deliverable 1, `FstI`, `FstO`)
**and their terminal identities reduced to the claims' truth** (deliverable 2, `StgTermAtV`).

A stage slot's final value, at an accepted slot, is `poly(vals) + c·g` (L11 / L16): `poly` the definition's polynomial,
`vals` its tables' values at the sumcheck's point (eq and public tables computed by the verifier, private ones the
prover's terminal values, each the value of a claim the verifier hands to `A`, `H` or an IO commitment), `c` the slot's
CFS challenge, `g` the value of the slot's `M` functional. The REAL slot polynomial over the extracted data is that
expression with the private tables' values and `g` read off the extracted data instead of the proof:

* `stgWords`: the canonical words of a point of `K^N` (`ofK`); `stgWords_toK`: of a canonical word list, itself;
* `stgPrivVals`: the private tables' values over the data `cs` (each private table's claim, as the verifier builds it at
  the point, read by `cs`);
* **`stg_tabVals_data`**: at a point where every claim the slot builds is true of the data, the verifier's table values
  from the data are the ones from the proof;
* `stgPolyT`: **the table side** at a point: the slot's `define` from what the trace shows, its tables at the point's
  words, the private ones the data's, through `poly` (the code's own evaluation; any `BlockParams`);
* **`stgPolyT_eval`**: at the verifier's point of an accepted slot whose claims are true, it is `poly(vals)`;
* **`stgFR`**: THE STAGE SLOT POLYNOMIAL over the view: the table side at the stage schedule the header reader `Pv` reads
  and the claims' semantics `csv` the view gives, plus `c` times the CFS mask polynomial of the extracted mask rows `Rv`
  (L31's `maskPoly`);
* `StgTrueAt`: at every reading of the stage, with its accumulator: the header reader reads the reading's schedule, the
  accumulator's claims are true of the data (`ClaimsTrue`), `M`'s functionals are true (`MTrue`): the run-level link
  lane L50 left for the blocks (§5 item a), at the stages;
* **`stgFR_termAt`**: `StgTrueAt` gives `StgTermAtV` for `stgFR` (L16's `blockSlots_terminal` at the stages), with
  `M`'s semantics linear on the extracted rows (`MLin`);
* `stgCsv`, **`stgCsv_value`**, `stgMsv`, `stgRv`, **`stgMsv_mlin`**: the extracted data at the stage's roots over the
  view (L36's `csXof`, L28's `msOfTab`, L31's `mRowX` at the stage's positions);
* **`stgFstI`**, **`stgFstO`**: the real `FstI`, `FstO`.

`FstI := stgFR … (fun v ch => (Win (v.2.take n0)).bp (incCtx … ch)) …`, `FstO` likewise: the polynomials are the code's
own, over the data the view's extraction gives; what is left is `StgTrueAt` (the openings' and `M`'s truth at the
stages, and the header reader `Win` / `Wout`, lane L55's `hW`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgAlgRun
import ZK60Formal.SlotPolyInstEval
import ZK60Formal.BlockDefinePoly
import ZK60Formal.RunOpenGeo

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Words

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- The canonical words of a point. -/
noncomputable def stgWords {N : ℕ} (x : Fin N → K) : List Fp2 :=
  List.ofFn (fun i => ZK60.HonestClassify.ofK U hbij (x i))

theorem stgWords_length {N : ℕ} (x : Fin N → K) : (stgWords U hbij x).length = N := by
  simp [stgWords]

/-- **The words of a canonical word list's values are the list.** -/
theorem stgWords_toK (hU : U ^ 2 = algebraMap GF K 7) (w : List Fp2) (hw : ∀ a ∈ w, a.Canon) (N : ℕ)
    (hN : w.length = N) : stgWords U hbij (fun i : Fin N => (w.getD i Fp2.zero).toK U) = w := by
  subst hN
  apply List.ext_getElem
  · exact stgWords_length U hbij _
  · intro i h1 h2
    simp only [stgWords, List.getElem_ofFn]
    have hg : w.getD i Fp2.zero = w[i] := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem h2, Option.getD_some]
    rw [hg]
    exact Fp2.toK_injective U hU (ZK60.HonestClassify.ofK_canon U hbij _) (hw _ (List.getElem_mem h2))
      (ZK60.HonestClassify.toK_ofK U hbij _)

/-- **The private tables' values over the data** `cs`: per private table, in order, `cs` of the claim the verifier builds
for it at the point (its value field unread, `hcs` below), as a word. -/
noncomputable def stgPrivVals (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (rho es : List Fp2) :
    List Block.Tab → List Fp2
  | [] => []
  | .priv p :: ts => ZK60.HonestClassify.ofK U hbij (cs p.cm (Block.buildClaim P p (Block.claimPoint p rho)
      (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero)) :: stgPrivVals P cs rho es ts
  | .eq _ _ :: ts => stgPrivVals P cs rho es ts
  | .pub _ :: ts => stgPrivVals P cs rho es ts

/-- An eq table's verifier value does not move the private-table count. -/
theorem stg_tabVal_eq_idx (sel : Fp2) (rho T point : List Fp2) (start k : ℕ) (v : Fp2) (k' : ℕ)
    (h : Block.tabVal sel rho T (.eq point start) k = .ok (v, k')) : k' = k := by
  simp only [Block.tabVal] at h
  split_ifs at h
  split at h
  · exact (Prod.mk.inj (Except.ok.inj h)).2.symm
  · cases h

/-- A public table's verifier value does not move the private-table count. -/
theorem stg_tabVal_pub_idx (sel : Fp2) (rho T w : List Fp2) (k : ℕ) (v : Fp2) (k' : ℕ)
    (h : Block.tabVal sel rho T (.pub w) k = .ok (v, k')) : k' = k := by
  simp only [Block.tabVal] at h
  split at h
  · exact (Prod.mk.inj (Except.ok.inj h)).2.symm
  · cases h

/-- **The verifier's table values from the data are the ones from the proof**, when every claim the slot builds is true
of the data (`cs` reading a claim's functional only, `hcs`) and the proof's terminal values are canonical. -/
theorem stg_tabVals_data (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
    (hcs : ∀ (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2), cs cm { z with value := a } = cs cm z)
    (sel : Fp2) (rho es : List Fp2) :
    ∀ (tabs : List Block.Tab) (k : ℕ) (T W : List Fp2), (∀ j, (T.getD j Fp2.zero).Canon) →
      (∀ q ∈ Block.slotClaimList P rho es T tabs k, cs q.1 q.2 = q.2.value.toK U) →
      (∀ j, W.getD (k + j) Fp2.zero = (stgPrivVals U hbij P cs rho es tabs).getD j Fp2.zero) →
      Block.tabVals sel rho W tabs k = Block.tabVals sel rho T tabs k
  | [], _, _, _, _, _, _ => rfl
  | .priv p :: ts, k, T, W, hT, htrue, hW => by
    have h0 : W.getD k Fp2.zero = T.getD k Fp2.zero := by
      have e1 := hW 0
      rw [Nat.add_zero] at e1
      rw [e1]
      show ZK60.HonestClassify.ofK U hbij (cs p.cm (Block.buildClaim P p (Block.claimPoint p rho)
        (Block.oneMinusProd es) (Block.maskCoef es p.extRound) Fp2.zero)) = T.getD k Fp2.zero
      have ht := htrue _ List.mem_cons_self
      have hz := hcs p.cm (Block.buildClaim P p (Block.claimPoint p rho) (Block.oneMinusProd es)
        (Block.maskCoef es p.extRound) (T.getD k Fp2.zero)) Fp2.zero
      have e2 : cs p.cm (Block.buildClaim P p (Block.claimPoint p rho) (Block.oneMinusProd es)
          (Block.maskCoef es p.extRound) Fp2.zero) = (T.getD k Fp2.zero).toK U := hz.trans ht
      rw [e2]
      exact Fp2.toK_injective U hU (ZK60.HonestClassify.ofK_canon U hbij _) (hT k)
        (ZK60.HonestClassify.toK_ofK U hbij _)
    have ih := stg_tabVals_data hU P cs hcs sel rho es ts (k + 1) T W hT
      (fun q hq => htrue q (List.mem_cons_of_mem _ hq))
      (fun j => by
        have e := hW (j + 1)
        rw [show k + (j + 1) = k + 1 + j by omega] at e
        rw [e]
        rfl)
    show (match Block.tabVal sel rho W (.priv p) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho W ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs)) = (match Block.tabVal sel rho T (.priv p) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho T ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs))
    show (match Block.tabVals sel rho W ts (k + 1) with
      | .error e => Except.error e
      | .ok vs => Except.ok (W.getD k Fp2.zero :: vs)) = (match Block.tabVals sel rho T ts (k + 1) with
      | .error e => Except.error e
      | .ok vs => Except.ok (T.getD k Fp2.zero :: vs))
    rw [ih, h0]
  | .eq point start :: ts, k, T, W, hT, htrue, hW => by
    have ih := stg_tabVals_data hU P cs hcs sel rho es ts k T W hT htrue hW
    have e : Block.tabVal sel rho W (.eq point start) k = Block.tabVal sel rho T (.eq point start) k := rfl
    show (match Block.tabVal sel rho W (.eq point start) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho W ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs)) = (match Block.tabVal sel rho T (.eq point start) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho T ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs))
    rw [e]
    cases h : Block.tabVal sel rho T (.eq point start) k with
    | error e => rfl
    | ok p =>
      obtain ⟨v, k'⟩ := p
      have hk := stg_tabVal_eq_idx sel rho T point start k v k' h
      subst hk
      simp only [ih]
  | .pub w :: ts, k, T, W, hT, htrue, hW => by
    have ih := stg_tabVals_data hU P cs hcs sel rho es ts k T W hT htrue hW
    have e : Block.tabVal sel rho W (.pub w) k = Block.tabVal sel rho T (.pub w) k := rfl
    show (match Block.tabVal sel rho W (.pub w) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho W ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs)) = (match Block.tabVal sel rho T (.pub w) k with
      | .error e => Except.error e
      | .ok (v, k') =>
        match Block.tabVals sel rho T ts k' with
        | .error e => Except.error e
        | .ok vs => Except.ok (v :: vs))
    rw [e]
    cases h : Block.tabVal sel rho T (.pub w) k with
    | error e => rfl
    | ok p =>
      obtain ⟨v, k'⟩ := p
      have hk := stg_tabVal_pub_idx sel rho T w k v k' h
      subst hk
      simp only [ih]

end Words

/-! ## The table side and the stage slot polynomial over the data -/

section Real

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **The table side of slot `k` over the data `cs`, as the code evaluates it**: the slot's `define` from what the trace
shows (`histSeen`, `drSeen`), its tables' values at the point's words (`ρ` the first `main` of them, the extension
challenges the rest), the private tables' values the data's, through the definition's polynomial; `0` where the code
would refuse. -/
noncomputable def stgPolyT (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (k : ℕ) (sn : Block.Seen)
    {N : ℕ} (x : Fin N → K) : K :=
  match P.define k (Block.histSeen sn k) (Block.drSeen sn k) with
  | .ok df =>
    match Block.tabVals (Block.oneMinusProd ((stgWords U hbij x).drop (Block.slotShape P k).1))
        ((stgWords U hbij x).take (Block.slotShape P k).1)
        (stgPrivVals U hbij P cs ((stgWords U hbij x).take (Block.slotShape P k).1)
          ((stgWords U hbij x).drop (Block.slotShape P k).1) df.tabs) df.tabs 0 with
    | .ok vals => (df.poly vals).toK U
    | .error _ => 0
  | .error _ => 0

/-- **At the verifier's point of an accepted slot whose claims are true of the data, the table side is `poly(vals)`.** -/
theorem stgPolyT_eval (hU : U ^ 2 = algebraMap GF K 7) (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
    (hcs : ∀ (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2), cs cm { z with value := a } = cs cm z)
    (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (k : ℕ) (r : Block.SlotRec) (sp : Block.SlotProof)
    (df : Block.SlotDef) (vals rhoFull : List Fp2) (hr : rs[k]? = some r)
    (hdf : P.define k (Block.histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df)
    (hrc : ∀ x ∈ rhoFull, x.Canon) (hsc : Block.SlotCanon sp)
    (hrho : r.rho = rhoFull.take (Block.slotShape P k).1) (hes : r.es = rhoFull.drop (Block.slotShape P k).1)
    (hvals : Block.tabVals (Block.oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals)
    (htrue : ∀ q ∈ Block.slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U)
    (N : ℕ) (hN : rhoFull.length = N) :
    stgPolyT U hbij P cs k (Block.seenOf bga rs k) (fun i : Fin N => ((r.rho ++ r.es).getD i Fp2.zero).toK U)
      = (df.poly vals).toK U := by
  have hrf : r.rho ++ r.es = rhoFull := by rw [hrho, hes, List.take_append_drop]
  have hw : stgWords U hbij (fun i : Fin N => ((r.rho ++ r.es).getD i Fp2.zero).toK U) = rhoFull := by
    rw [hrf]
    exact stgWords_toK U hbij hU rhoFull hrc N hN
  have hT : ∀ j, (sp.terms.getD j Fp2.zero).Canon := by
    intro j
    rw [List.getD_eq_getElem?_getD]
    cases hj : sp.terms[j]? with
    | none => exact Fp2.canon_zero
    | some a => exact hsc.2.2 a (List.mem_of_getElem? hj)
  have hv : Block.tabVals (Block.oneMinusProd r.es) r.rho
      (stgPrivVals U hbij P cs r.rho r.es df.tabs) df.tabs 0 = .ok vals := by
    rw [stg_tabVals_data U hbij hU P cs hcs _ r.rho r.es df.tabs 0 sp.terms
      (stgPrivVals U hbij P cs r.rho r.es df.tabs) hT htrue (fun j => by rw [Nat.zero_add])]
    exact hvals
  unfold stgPolyT
  rw [Block.histSeen_seenOf, Block.drSeen_seenOf bga rs k r hr, hdf]
  simp only [hw, ← hrho, ← hes, hv]

/-- **THE STAGE SLOT POLYNOMIAL OVER THE EXTRACTED DATA** (the real `FstI`, `FstO`): at the view `v`, slot `k`, what the
trace shows `sn` and the point `x`: the table side (`stgPolyT`) at the stage schedule the header reader `Pv` reads from
the view at the head's challenges, over the claims' semantics `csv v`, plus the slot's CFS challenge times the CFS mask
polynomial of the extracted mask rows `Rv v` (L31's `maskPoly`). -/
noncomputable def stgFR (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (csv : StgVw L → Block.Cm → Block.ZClaim → K) (Rv : StgVw L → ℕ → ℕ → K) :
    StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  fun v k sn x => stgPolyT U hbij (Pv v sn.1) (csv v) k (bgaOf sn.1, sn.2) x
    + ((sn.2.getD k ([], Fp2.zero, [])).2.1).toK U * maskPoly (Rv v) k (stgN P0 k) (Block.slotShape P0 k).2.2 x

/-- **The run-level facts at the stage the real polynomial needs**: at every reading of the stage and every slot's
window, with the reading's accumulator, the header reader `Pv` reads the reading's schedule, the accumulator's claims
are true of the data `csv` reads (L16's `ClaimsTrue`) and `M`'s functionals are true of `msv` (`MTrue`). -/
def StgTrueAt (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (msv : StgVw L → List (ℕ × List Fp2) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      Pv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q))) ch = Pof ch
      ∧ Block.ClaimsTrue U (csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) acc.claims
      ∧ Block.MTrue U (msv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) acc.fs

/-- **THE REAL STAGE SLOT POLYNOMIAL MEETS THE TERMINAL IDENTITIES AT EVERY READING** (`StgTermAtV` for `stgFR`), from
the run-level facts (`StgTrueAt`): the stage's schedules have the lists' slot shapes (`hP`), degrees at least `1`, every
slot has a variable and its mask coefficients fit `M`'s rows (`hN`), the definitions' polynomials return canonical
words (`hpolyC`), and the claims' semantics reads a claim's functional only (`hcs`). -/
theorem stgFR_termAt (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (msv : StgVw L → List (ℕ × List Fp2) → K) (Rv : StgVw L → ℕ → ℕ → K) (Wd : ℕ)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ Wd)
    (hpolyC : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df → ∀ vs, (df.poly vs).Canon)
    (hcs : ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2), csv v cm { z with value := a } = csv v cm z)
    (hlin0 : ∀ v, Block.MLin U (msv v) (Rv v) Wd)
    (htrue : StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ) :
    StgTermAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) G Lg τ := by
  intro hdr core ch rs hrd k q r hq hr
  obtain ⟨-, -, hcan, hsh, ⟨acc, t', hacc⟩, -, -, -⟩ := id hrd
  obtain ⟨hPv, hcl, hm⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  have hlin := hlin0 (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
    (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
      ++ Block.slotPreOps (Pof ch) k q)))
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hkP : k < (Pof ch).geom.slots.length := by rw [← hslen]; exact hk
  have hk0 : k < P0.geom.slots.length := by rw [(hP ch).2]; exact hkP
  rw [StageFS.stageSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    rw [hch] at hloop
    obtain ⟨-, -, rs', hrs', -, hall⟩ := Block.slotsLoop_terminal (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs
      acc t' hloop
    simp only [List.nil_append] at hrs'
    subst rs'
    obtain ⟨rs2, hrs2, -, hall2⟩ := Block.slotsLoop_ok (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs acc t'
      (fun i hi => by
        rw [Nat.zero_add]
        exact hd ch i (by rw [← hslen]; exact hi)) hloop
    simp only [List.nil_append] at hrs2
    subst rs2
    obtain ⟨df, vals, rhoFull, hdf, hc0, hcc, -, hrho, hes, hvals, hev, hclk⟩ := hall k q r hq hr
    obtain ⟨-, -, ⟨df', -, hcl'⟩, hsv⟩ := hall2 k q r hq hr
    simp only [Nat.zero_add, List.nil_append] at hdf hrho hes hev hsv hclk hcl'
    have hqc : Block.SlotCanon q := hcan.1 q (List.mem_of_getElem? hq)
    have hclc : r.claimed.Canon := Block.hostedSum_canon _ q.scalar _ _ hqc.1 hcl'
    have hfinc : r.fin.Canon := Block.scVerify_fin_canon (liftH G) r.claimed hclc _ _ (hd ch k hkP) q.rounds _ r.fin
      (r.rho ++ r.es) hsv
    have hrf : rhoFull = r.rho ++ r.es := by rw [hrho, hes, List.take_append_drop]
    unfold scVerify at hsv
    split at hsv
    · simp at hsv
    · rename_i hlen'
      obtain ⟨-, hrs3, -⟩ := (scLoop_ok_iff (liftH G) _ (hd ch k hkP) q.rounds 0 r.claimed [] _ r.fin
        (r.rho ++ r.es)).mp hsv
      rw [List.nil_append] at hrs3
      have hNk : stgN P0 k = (Block.slotShape (Pof ch) k).1 + (Block.slotShape (Pof ch) k).2.1 := by
        rw [stg_stgN (hP ch)]
        rfl
      have hrl : rhoFull.length = stgN P0 k := by
        rw [hrf, hrs3, scChal_length, hNk]
        exact not_not.mp hlen'
      have hrc : ∀ x ∈ rhoFull, x.Canon := by
        rw [hrf, hrs3]
        exact scChal_canon (liftH G) _ _
      have htr : ∀ q' ∈ Block.slotClaimList (Pof ch) r.rho r.es q.terms df.tabs 0,
          csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q))) q'.1 q'.2 = q'.2.value.toK U :=
        fun q' hq' => hcl q'.1 q'.2 (hclk q' hq')
      have hpoly := stgPolyT_eval U hbij hU (Pof ch) (csv (stgVw absOf Lg (opTrace (liftH G)
        (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
          ++ Block.fullOps (Pof ch) 0 (core.slots.take k) ++ Block.slotPreOps (Pof ch) k q)))) (hcs _) (bgaOf ch) rs k r q
        df vals rhoFull hr hdf hrc hqc hrho hes hvals htr (stgN P0 k) hrl
      have hmk := hm _ hev
      simp only at hmk
      have hl := hlin [(k, Cfs.evalWeights rhoFull (Block.slotShape (Pof ch) k).2.2)]
      obtain ⟨hN0, hNW⟩ := hN k hk0
      have hd0 : (Block.slotShape P0 k).2.2 = (Block.slotShape (Pof ch) k).2.2 := by rw [stg_slotShape (hP ch)]
      have hmask : maskPoly (Rv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q)))) k (stgN P0 k) (Block.slotShape P0 k).2.2
            (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)
          = ((r.fin.sub (df.poly vals)).mul r.c.inv).toK U := by
        rw [← hmk, hl]
        show _ = Block.mdot U _ Wd (k, Cfs.evalWeights rhoFull (Block.slotShape (Pof ch) k).2.2) + 0
        rw [add_zero, ← hd0, maskPoly_point U hU hbij _ Wd k (stgN P0 k) _ hN0 rhoFull hrl hNW, hrf]
      show r.fin.toK U = stgPolyT U hbij (Pv _ ch) (csv _) k (bgaOf ch, ((rs.take (k + 1)).map
          (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)))) _
        + ((((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
          ([], Fp2.zero, [])).2.1).toK U * maskPoly (Rv _) k (stgN P0 k) (Block.slotShape P0 k).2.2 _
      rw [hPv]
      have hc : (((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
          ([], Fp2.zero, [])).2.1 = r.c := Block.seenOf_c (bgaOf ch) rs k r hr
      rw [hc, hmask]
      have hp' : stgPolyT U hbij (Pof ch) (csv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
              ++ Block.slotPreOps (Pof ch) k q)))) k (bgaOf ch, ((rs.take (k + 1)).map
            (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))))
            (fun i : Fin (stgN P0 k) => ((r.rho ++ r.es).getD i Fp2.zero).toK U) = (df.poly vals).toK U := hpoly
      rw [hp']
      exact Block.fin_identity U hU r.fin (df.poly vals) r.c hfinc (hpolyC ch k _ _ df hdf vals) hcc hc0
  · cases hacc

end Real

/-! ## The extracted data at the stage's roots, over the view -/

section Sem

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **The stage's claims' semantics over the view** (L36's `csXof` at a stage): a claim on `A` (on `H`) is its
functional on the rows decoded from the matrix extracted for the root the header absorbs at position `iA` (`iH`): the
log cut there (`v.1 iA`) and the root bytes there (`absAt v.2 iA`), at the opening geometry `(lc, h, Q, e)` and the
commitment's rows; a claim on an IO commitment (the input endpoint, `B_in`, `B_out`) is `csIO`'s (lanes L55, L56). -/
noncomputable def stgCsv (lc h Q e rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → Block.Cm → Block.ZClaim → K :=
  fun v cm z =>
    match cm with
    | .a => claimSem U rA lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rA (v.1 iA) (Block.absAt v.2 iA))) z
    | .h => claimSem U rH lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rH (v.1 iH) (Block.absAt v.2 iH))) z
    | cm => csIO v cm z

/-- **The claims' semantics reads a claim's functional only** (`hcs` of `stgFR_termAt`), when the IO part does. -/
theorem stgCsv_value (lc h Q e rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K)
    (hIO : ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2), csIO v cm { z with value := a } = csIO v cm z) :
    ∀ v (cm : Block.Cm) (z : Block.ZClaim) (a : Fp2),
      stgCsv U tag h64 lc h Q e rA rH iA iH csIO v cm { z with value := a }
        = stgCsv U tag h64 lc h Q e rA rH iA iH csIO v cm z := by
  intro v cm z a
  cases cm with
  | a => rfl
  | h => rfl
  | inp => exact hIO v .inp z a
  | out => exact hIO v .out z a

/-- **`M`'s semantics over the view**: L28's `msOfTab` of the mask table extracted for the root the header absorbs at
`iM`. -/
noncomputable def stgMsv (S iM : ℕ) : StgVw L → List (ℕ × List Fp2) → K :=
  fun v => msOfTab U S (colsC tag L h64 (v.1 iM) (Block.absAt v.2 iM))

/-- **The extracted mask rows over the view** (L31's `mRowX`). -/
noncomputable def stgRv (S iM : ℕ) : StgVw L → ℕ → ℕ → K :=
  fun v => mRowX U S (colsC tag L h64 (v.1 iM) (Block.absAt v.2 iM))

/-- **`M`'s semantics over the view is linear on the extracted rows** (`MLin` of `StgTrueAt`, PROVED: L31's
`msOfTab_mlin`). -/
theorem stgMsv_mlin (S iM : ℕ) (v : StgVw L) :
    Block.MLin U (stgMsv U tag h64 S iM v) (stgRv U tag h64 S iM v) 512 :=
  msOfTab_mlin U S _

end Sem

/-! ## The real `FstI`, `FstO` -/

section Inst

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **THE REAL `FstI`**: stage IN-C's slot polynomial over the extracted data. The schedule is the one of the stage
verifier the header reader `Win` reads off the trace before part `0`'s pre-slots (`n0`, as the top theorem's `hW`), at
the head's challenges (`incCtx`); `define`'s history `(0, 0, 0)`; `A`, `M`, `H` extracted at the stage's root positions
(`hdrLen`, `hdrLen + 3`, `hdrLen + 4 + m`, the head of `m` challenges); the IO claims `csIO`'s. -/
noncomputable def stgFstI (P0 : Block.BlockParams) (Win : List (TItem × Dig) → StageV.IncV) (n0 hdrLen m : ℕ)
    (lc h Q e rA rH S : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  stgFR U hbij P0 (fun v ch => (Win (v.2.take n0)).bp (StageV.incCtx (Win (v.2.take n0)).pub ch))
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO)
    (stgRv U tag h64 S (hdrLen + 3))

/-- **THE REAL `FstO`**: stage OUT-C's slot polynomial over the extracted data, its schedule the one of the verifier
`Wout` reads (`n0` the trace before part `Lb + 1`'s pre-slots), `define`'s history `(0, γ, α)` (`OutcV.bga`), the head of
`2` challenges. -/
noncomputable def stgFstO (P0 : Block.BlockParams) (Wout : List (TItem × Dig) → StageV.OutcV) (n0 hdrLen : ℕ)
    (lc h Q e rA rH S : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K :=
  stgFR U hbij P0 (fun v _ => (Wout (v.2.take n0)).bp) StageV.OutcV.bga
    (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + 2) csIO) (stgRv U tag h64 S (hdrLen + 3))

end Inst

end ZK60.ProtocolClassify
