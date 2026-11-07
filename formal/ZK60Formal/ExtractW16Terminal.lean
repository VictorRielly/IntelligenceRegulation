/-
D63 lane L16 (2026-11-07), part 3: **the slots' terminal identity on the extracted tables** (finding L10-6 (b) and (c);
L11-2: the verify arm does not check it, `M`'s test and the openings do).

`blockSlots` (L9) computes per slot the terminal values `vals` (the `eq` and public tables' values at `ρ`, and the
prover's masked terminals for the private tables), `g = (fin − poly(vals))·c⁻¹`, and hands on: each private table's
claim `build_claim` (to `A`, `H` or an endpoint), whose value is the masked terminal, and `M`'s functional
`⟨[(s, evalWeights(ρ, d))], g⟩`. Neither is checked here. This file proves that the checks downstream ENFORCE the
terminal identity on whatever data they are checked against:

* `slotStep_ok_terminal`, `slotsLoop_terminal`: an accepting slot exposes its definition, `vals`, `c ≠ 0`, and puts
  its `M` functional into the accumulator's functional list and every claim it builds (`slotClaimList`) into the
  accumulator's claims, which only grow (`slotAcc_fs_mono`, `slotClaims_mono`);
* `fin_identity`: `fin = poly(vals) + c·g` in `K` (L11's `terminal_iff`);
* `scVerify_fin_canon`: the sumcheck's final value is a canonical word;
* **`blockSlots_terminal`**: if every claim of the accumulator is TRUE of some data (`cs`: the claims' values on the
  extracted tables) and every `M` functional is TRUE of some data (`ms`: the functionals on the extracted `M`), and the
  slot polynomial `f` evaluates, at a slot's point, to `poly` of the slot's true terminal values plus `c` times the
  slot's `M` functional on that data (`hEval`: the masked slot polynomial over the extracted tables, the interface L11 /
  L13's builders must meet), then EVERY slot's terminal check `fin = f(ρ)` holds: L9's `BlockWin` premise.

So the premise L10-6 named reduces exactly to: the claims handed to `A`, `H` and the endpoints, and the functionals
handed to `M`, are true of the extracted data. That is what the openings' and `M`'s knowledge soundness give
(`ExtractW16Block.lean` composes it). Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExtractW16Slots
import ZK60Formal.SlotW16Ir

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The claims a slot builds -/

/-- The claims of one commitment. -/
def Claims4.get (c : Claims4) : Cm → List ZClaim
  | .a => c.a
  | .h => c.h
  | .inp => c.inp
  | .out => c.out

theorem Claims4.get_push_self (c : Claims4) (cm : Cm) (z : ZClaim) : z ∈ (c.push cm z).get cm := by
  cases cm <;> simp [Claims4.push, Claims4.get]

theorem Claims4.get_push_mono (c : Claims4) (cm cm' : Cm) (z x : ZClaim) (hx : x ∈ c.get cm') :
    x ∈ (c.push cm z).get cm' := by
  cases cm <;> cases cm' <;> simp_all [Claims4.push, Claims4.get]

/-- **The claims a slot pushes** (`slotClaims`), with their commitments: per private table, `build_claim` at the slot's
claim point, the masked terminal its value. -/
def slotClaimList (P : BlockParams) (rho es terms : List Fp2) : List Tab → ℕ → List (Cm × ZClaim)
  | [], _ => []
  | .priv p :: ts, k => (p.cm, buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
      (terms.getD k Fp2.zero)) :: slotClaimList P rho es terms ts (k + 1)
  | .eq _ _ :: ts, k => slotClaimList P rho es terms ts k
  | .pub _ :: ts, k => slotClaimList P rho es terms ts k

/-- Claims already held stay held. -/
theorem slotClaims_mono (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Claims4) (cm : Cm) (x : ZClaim), x ∈ cl.get cm →
      x ∈ (slotClaims P rho es terms ts k cl).get cm
  | [], _, _, _, _, h => h
  | .priv p :: ts, k, cl, cm, x, h =>
    slotClaims_mono P rho es terms ts (k + 1) _ cm x (Claims4.get_push_mono cl p.cm cm _ x h)
  | .eq _ _ :: ts, k, cl, cm, x, h => slotClaims_mono P rho es terms ts k cl cm x h
  | .pub _ :: ts, k, cl, cm, x, h => slotClaims_mono P rho es terms ts k cl cm x h

/-- Every claim a slot builds is among the claims after it. -/
theorem slotClaims_mem (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Claims4), ∀ q ∈ slotClaimList P rho es terms ts k,
      q.2 ∈ (slotClaims P rho es terms ts k cl).get q.1
  | [], _, _, q, hq => by simp [slotClaimList] at hq
  | .priv p :: ts, k, cl, q, hq => by
    simp only [slotClaimList, List.mem_cons] at hq
    rcases hq with rfl | hq
    · exact slotClaims_mono P rho es terms ts (k + 1) _ _ _ (Claims4.get_push_self cl p.cm _)
    · exact slotClaims_mem P rho es terms ts (k + 1) _ q hq
  | .eq _ _ :: ts, k, cl, q, hq => slotClaims_mem P rho es terms ts k cl q hq
  | .pub _ :: ts, k, cl, q, hq => slotClaims_mem P rho es terms ts k cl q hq

/-! ## The accumulator after a slot -/

theorem slotAcc_claims (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (c scalar g : Fp2) (rhoFull terms : List Fp2) :
    (slotAcc P s acc df c scalar g rhoFull terms).claims
      = slotClaims P (rhoFull.take (slotShape P s).1) (rhoFull.drop (slotShape P s).1) terms df.tabs 0 acc.claims :=
  rfl

theorem slotAcc_fs_mono (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (c scalar g : Fp2)
    (rhoFull terms : List Fp2) (x : MaskFunctional) (hx : x ∈ acc.fs) :
    x ∈ (slotAcc P s acc df c scalar g rhoFull terms).fs := by
  unfold slotAcc
  simp only
  apply List.mem_append_left
  split
  · exact List.mem_append_left _ hx
  · exact hx

/-- **A slot's `M` functional** (`⟨[(s, evalWeights(ρ, d))], g⟩`, argument.rs:1494) is in the functional list after it. -/
theorem slotAcc_fs_eval (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (c scalar g : Fp2)
    (rhoFull terms : List Fp2) :
    (⟨[(s, Cfs.evalWeights rhoFull (slotShape P s).2.2)], g⟩ : MaskFunctional)
      ∈ (slotAcc P s acc df c scalar g rhoFull terms).fs := by
  unfold slotAcc
  simp only
  exact List.mem_append_right _ (List.mem_singleton_self _)

/-! ## An accepting slot, with its terminal values -/

theorem exGuard_ok {b : Bool} {m : String} {u : Unit} (h : exGuard b m = .ok u) : b = false := by
  cases b
  · rfl
  · simp [exGuard] at h

section Steps

variable (H : HIn → Dig)

/-- **An accepting slot, unfolded to its terminal values**: its definition, `c ≠ 0` (a canonical challenge), its
masked terminals, the values `vals`, and the accumulator after it with `g = (fin − poly(vals))·c⁻¹`. -/
theorem slotStep_ok_terminal (P : BlockParams) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (t : Tr)
    (r : SlotRec) (acc' : Acc) (t' : Tr) (h : slotStep H P s hist sp acc t = .ok (r, acc', t')) :
    ∃ df vals rhoFull, P.define s hist r.draws = .ok df ∧ r.c ≠ Fp2.zero ∧ r.c.Canon ∧ r.terms = sp.terms
      ∧ r.rho = rhoFull.take (slotShape P s).1 ∧ r.es = rhoFull.drop (slotShape P s).1
      ∧ tabVals (oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals
      ∧ acc' = slotAcc P s acc df r.c sp.scalar ((r.fin.sub (df.poly vals)).mul r.c.inv) rhoFull sp.terms := by
  unfold slotStep at h
  obtain ⟨df, hdf, h⟩ := ex_bind_ok h
  obtain ⟨u1, -, h⟩ := ex_bind_ok h
  obtain ⟨u2, hu2, h⟩ := ex_bind_ok h
  obtain ⟨u3, -, h⟩ := ex_bind_ok h
  obtain ⟨claimed, -, h⟩ := ex_bind_ok h
  obtain ⟨fr, -, h⟩ := ex_bind_ok h
  obtain ⟨fin, rhoFull⟩ := fr
  obtain ⟨vals, hvals, h⟩ := ex_bind_ok h
  obtain ⟨u4, -, h⟩ := ex_bind_ok h
  simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  exact ⟨df, vals, rhoFull, hdf, Slot.isZero_false (exGuard_ok hu2), canon_challengeFp2Of _, rfl, rfl, rfl, hvals,
    rfl⟩

/-- **The slot loop, with its terminal values**: the functionals and claims only grow; slot `j + i`'s definition (from
the history of the records before it), `c ≠ 0`, its values, its `M` functional in the final list, and every claim it
builds among the final claims. -/
theorem slotsLoop_terminal (P : BlockParams) (b g a : Fp2) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr), slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') →
      (∀ x ∈ acc.fs, x ∈ acc'.fs) ∧ (∀ (cm : Cm) (x : ZClaim), x ∈ acc.claims.get cm → x ∈ acc'.claims.get cm)
      ∧ ∃ rs, recs' = recs ++ rs ∧ rs.length = sps.length
        ∧ ∀ (i : ℕ) (sp : SlotProof) (r : SlotRec), sps[i]? = some sp → rs[i]? = some r →
          ∃ df vals rhoFull, P.define (j + i) (histOf b g a (recs ++ rs.take i)) r.draws = .ok df
            ∧ r.c ≠ Fp2.zero ∧ r.c.Canon ∧ r.terms = sp.terms
            ∧ r.rho = rhoFull.take (slotShape P (j + i)).1 ∧ r.es = rhoFull.drop (slotShape P (j + i)).1
            ∧ tabVals (oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals
            ∧ (⟨[(j + i, Cfs.evalWeights rhoFull (slotShape P (j + i)).2.2)], (r.fin.sub (df.poly vals)).mul r.c.inv⟩
                : MaskFunctional) ∈ acc'.fs
            ∧ ∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, q.2 ∈ acc'.claims.get q.1
  | [], recs, j, acc, t, recs', acc', t', h => by
    simp only [slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, -⟩ := h
    exact ⟨fun x hx => hx, fun _ _ hx => hx, [], by simp, rfl, fun i sp r h1 _ => by simp at h1⟩
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', h => by
    simp only [slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, vals, rhoFull, hdf, hc0, hcc, hterms, hrho, hes, hvals, hacc0⟩ :=
        slotStep_ok_terminal H P j _ sp0 acc t r0 acc0 t0 hstep
      obtain ⟨hfs, hcl, rs, hrs, hlen, hall⟩ :=
        slotsLoop_terminal P b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' h
      have hfs0 : ∀ x ∈ acc.fs, x ∈ acc0.fs := by
        rw [hacc0]
        exact fun x hx => slotAcc_fs_mono P j acc df _ _ _ rhoFull sp0.terms x hx
      have hcl0 : ∀ (cm : Cm) (x : ZClaim), x ∈ acc.claims.get cm → x ∈ acc0.claims.get cm := by
        rw [hacc0, slotAcc_claims]
        exact fun cm x hx => slotClaims_mono P _ _ sp0.terms df.tabs 0 acc.claims cm x hx
      refine ⟨fun x hx => hfs x (hfs0 x hx), fun cm x hx => hcl cm x (hcl0 cm x hx), r0 :: rs,
        by rw [hrs, List.append_assoc, List.singleton_append], by simp [hlen], ?_⟩
      intro i sp r h1 h2
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
        subst sp r
        refine ⟨df, vals, rhoFull, by simpa [histOf] using hdf, hc0, hcc, hterms, by simpa using hrho,
          by simpa using hes, hvals, ?_, ?_⟩
        · have hm := slotAcc_fs_eval P j acc df r0.c sp0.scalar ((r0.fin.sub (df.poly vals)).mul r0.c.inv) rhoFull
            sp0.terms
          rw [← hacc0] at hm
          simpa using hfs _ hm
        · intro q hq
          refine hcl q.1 q.2 ?_
          rw [hacc0, slotAcc_claims, ← hrho, ← hes]
          exact slotClaims_mem P r0.rho r0.es sp0.terms df.tabs 0 acc.claims q hq
      | succ i =>
        simp only [List.getElem?_cons_succ] at h1 h2
        obtain ⟨df', vals', rhoFull', hdf', hc', hcc', ht', hrho', hes', hv', hm', hcl'⟩ := hall i sp r h1 h2
        have hji : j + (i + 1) = j + 1 + i := by omega
        rw [hji]
        exact ⟨df', vals', rhoFull', by simpa [histOf, List.append_assoc] using hdf', hc', hcc', ht', hrho', hes', hv',
          hm', hcl'⟩

end Steps

/-- The sumcheck's final value of an accepting run is a canonical word (for a canonical claimed sum). -/
theorem scVerify_fin_canon (H : HIn → Dig) (claimed : Fp2) (hc : claimed.Canon) (d n : ℕ) (hd : 1 ≤ d)
    (rounds : List (List Fp2)) (t : Tr) (fin : Fp2) (rs : List Fp2)
    (h : (scVerify H claimed d n rounds t).1 = .ok (fin, rs)) : fin.Canon := by
  unfold scVerify at h
  split at h
  · simp at h
  · obtain ⟨-, -, hfin⟩ := (scLoop_ok_iff H d hd rounds 0 claimed [] t fin rs).mp h
    rw [hfin]
    exact canon_scFinalExec _ _ _ hc

/-! ## The terminal identity, in the field -/

section K

variable {K : Type} [Field K] [Algebra GF K]

/-- **`fin = poly(vals) + c·g`** for `g = (fin − poly)·c⁻¹` (L11's `terminal_iff`). -/
theorem fin_identity (U : K) (hU : U ^ 2 = algebraMap GF K 7) (fin pv c : Fp2) (hf : fin.Canon) (hp : pv.Canon)
    (hc : c.Canon) (h0 : c ≠ Fp2.zero) :
    fin.toK U = pv.toK U + c.toK U * ((fin.sub pv).mul c.inv).toK U :=
  (Slot.terminal_iff U hU fin pv c hf hp hc h0 _).mp rfl

/-- **The claims true of some data**: every claim the accumulator holds for commitment `cm` has, on that data, the
value it claims (`cs cm c`: the claim's functional on the data, e.g. the extracted committed table). -/
def ClaimsTrue (U : K) (cs : Cm → ZClaim → K) (cl : Claims4) : Prop :=
  ∀ (cm : Cm) (c : ZClaim), c ∈ cl.get cm → cs cm c = c.value.toK U

/-- **The `M` functionals true of some data** (`ms ts`: the functional `ts` on the data, e.g. the extracted mask
rows). -/
def MTrue (U : K) (ms : List (ℕ × List Fp2) → K) (fs : List MaskFunctional) : Prop :=
  ∀ mf ∈ fs, ms mf.terms = mf.value.toK U

/-- **The evaluation interface of a slot polynomial over some data** (`cs` for the tables, `ms` for the masks): at an
accepting slot `k` (record `r`, definition `df`, values `vals`) whose claims are true of the data, `f` at the slot's
point is `poly(vals) + c·(the slot's M functional on the data)`. This is what the masked slot polynomial over the
committed tables satisfies (CFS: `f = poly(tables) + c·mask`, the private tables' extension values the claims'
functionals); L11 / L13's builders must meet it. -/
def SlotEval (U : K) (P : BlockParams) (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) : Prop :=
  ∀ (core : Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec) (sp : SlotProof) (df : SlotDef)
    (vals rhoFull : List Fp2), core.slots[k]? = some sp → rs[k]? = some r →
    P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df →
    r.rho = rhoFull.take (slotShape P k).1 → r.es = rhoFull.drop (slotShape P k).1 →
    tabVals (oneMinusProd r.es) r.rho sp.terms df.tabs 0 = .ok vals →
    (∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U) →
    f k (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)
      = (df.poly vals).toK U + r.c.toK U * ms [(k, Cfs.evalWeights rhoFull (slotShape P k).2.2)]

/-- **The terminal premise is discharged by the claims' and `M`'s truth** (finding L10-6 (b), (c); L11-2). If
`blockSlots` accepts, every claim the slots handed on is true of the data `cs` reads, every `M` functional is true of
the data `ms` reads, every definition's polynomial returns canonical words, every final value is canonical, and `f` is
the slot polynomial over that data (`SlotEval`), then every slot's terminal check `fin = f(ρ)` holds: the premise of
L9's `BlockWin`. -/
theorem blockSlots_terminal (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (P : BlockParams) (core : Core)
    (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hacc : blockSlots H P core t = .ok (bga, rs, acc, t')) (cs : Cm → ZClaim → K) (ms : List (ℕ × List Fp2) → K)
    (hcl : ClaimsTrue U cs acc.claims) (hm : MTrue U ms acc.fs)
    (hpolyC : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      ∀ vs, (df.poly vs).Canon)
    (hfin : ∀ r ∈ rs, r.fin.Canon)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (hEval : SlotEval U P cs ms f) :
    ∀ k r, rs[k]? = some r →
      r.fin.toK U = f k (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U) := by
  intro k r hr
  rw [blockSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    subst hbga
    obtain ⟨-, -, rs', hrs', hlen, hall⟩ := slotsLoop_terminal H P _ _ _ core.slots [] 0 {} _ rs acc t' hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    obtain ⟨sp, hsp⟩ : ∃ sp, core.slots[k]? = some sp :=
      ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr).1)⟩
    obtain ⟨df, vals, rhoFull, hdf, hc0, hcc, -, hrho, hes, hvals, hev, hclk⟩ := hall k sp r hsp hr
    simp only [Nat.zero_add, List.nil_append] at hdf hrho hes hev
    have htrue : ∀ q ∈ slotClaimList P r.rho r.es sp.terms df.tabs 0, cs q.1 q.2 = q.2.value.toK U :=
      fun q hq => hcl q.1 q.2 (hclk q hq)
    have hmk := hm _ hev
    simp only at hmk
    rw [hEval core _ rs k r sp df vals rhoFull hsp hr hdf hrho hes hvals htrue, hmk]
    exact fin_identity U hU r.fin (df.poly vals) r.c (hfin r (List.mem_of_getElem? hr)) (hpolyC k _ _ df hdf vals)
      hcc hc0
  · cases hacc

end K

end ZK60.Exec.Block
