/-
D63 Lean lane L25 (2026-11-07), part 2: **the block core's honest prover as a specification, and its completeness
against L9's executable `verify_core`** (`blockVerify`), generic in the block's `BlockParams` (W16R2 and R13 are
instances: L9's / L17's parameters).

The code (hashline `src/private_block/protocol.rs` `prove_core_after_with` :2434-2790 and `argument.rs` `run_slot`
:1153-1505, `argument_with` :3000-3075, read 2026-11-07; nothing there is changed). The prover and the verifier share
one transcript and one slot routine (`run_slot`'s `Side::Prove` / `Side::Verify`): the prover makes EXACTLY the
verifier's absorbs and squeezes, in the verifier's order:
* `absorb_root("A")`, `absorb("M", mask_root)`, the LogUp challenges `β, γ, α`, then the LogUp helpers and
  `absorb_root("H")` (the helper commitment's root is a function of `β, γ, α`: `CoreData.hRoot`);
* per slot (`run_slot`): `define`'s draws and the definition (the same public function on both sides), the schedule
  checks, `absorb_u64("pb-slot", s)`, the CFS challenge `c` (REFUSED when zero: "zero CFS mask challenge; discard
  attempt"), the scalar (`absorb_fp2("pb-scalar")`), the masked sumcheck's rounds (`HonestClassifySum.lean`'s
  `scProve`), the terminals, the degenerate-extension refusal ("degenerate terminal mask challenge; discard attempt"),
  `absorb_fp2("pb-term")`; the accumulator (`slotAcc`) by the shared code;
* the hosts' functionals after the slots and the functional count (`argument_with`, both sides);
* `M`'s opening (`zk::mask_open`), `check_opening` of `A` (the schedule audit and the challenge refusals on a clone:
  refused by the prover too), `A`'s opening (`pcs::open_zk`), the same for `H` (closed by `logup_sum_claim`).

What is proved (every premise a hypothesis):
* `SlotData`, `slotSP`, **`slotProve`**: one slot's honest prover (its scalar, its round strategy, its terminals as
  data; its two challenge refusals and the shared bookkeeping as the code's);
* `SlotSum`: the slot's ONE arithmetic obligation: a polynomial `F` of individual degree `≤ d` whose honest strategy
  the round words are, with the claimed sum (`scalar + Σ κ·scalar_h`, from the accumulator) equal to `Σ F` and the
  terminal count the schedule's;
* **`slotStep_of_prove`**: whenever the honest slot prover does not refuse and `SlotSum` holds, L9's `slotStep`
  ACCEPTS its slot proof, with the prover's record, accumulator and transcript (`scVerify_honest`);
* `slotsProve`, `SlotsSum`, **`slotsLoop_of_prove`**: the same for the slot loop, slot by slot along the honest run;
* `CoreData`, `CoreRun`, **`coreProve`**: the block core's honest prover (`prove_core_after_with`);
* **`blockVerify_of_prove`**: `verify_core` (L9's `blockVerify`) ACCEPTS the honest core and returns its IO claims and
  the prover's final transcript, given the profile's pre-checks, the honest openings' path depths, `SlotsSum` along the
  run, and the completeness of the three openings (`M`'s `mask_verify_tagged`, `A`'s and `H`'s `verify_zk_tagged`) on
  the run's own functionals and claims (L10's components, named premises);
* **`slotProve_refuses`**, **`coreProve_refuses`**: the honest core prover refuses ONLY at: a slot's `define` refusal,
  `c = 0`, a degenerate extension challenge, a deterministic schedule failure (`slotDefChecks`, the hosted index, a
  table length, the functional count), or `check_opening`'s refusal of `A` or `H` (O9 for a block, at the prover's
  own states).
-/
import ZK60Formal.HonestClassifySum
import ZK60Formal.ExecBlockVerify

set_option autoImplicit false

namespace ZK60.HonestClassify

open ZK60 ZK60.Exec ZK60.Exec.Block ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## `Except` steps -/

theorem bind_ok_of {ε α β : Type} {e : Except ε α} {f : α → Except ε β} {a : α} {b : β} (he : e = .ok a)
    (hf : f a = .ok b) : (e >>= f) = .ok b := by
  subst he
  exact hf

theorem exGuard_ok_of {b : Bool} {m : String} (h : b = false) : exGuard b m = .ok () := by
  subst h
  rfl

theorem ff_of_not {b : Bool} (h : ¬ b = true) : b = false := by
  cases b
  · rfl
  · exact absurd rfl h

theorem scCheck_ok_of {s : ℕ} {nm : String} {x : Except ScErr (Fp2 × List Fp2)} {r : Fp2 × List Fp2} (h : x = .ok r) :
    scCheck s nm x = .ok r := by
  subst h
  rfl

/-- A sub-check's verdict re-thrown under a prefix (`match … with | .ok t => pure t | .error e => throw …`). -/
theorem match_ok_of {ε ε' α : Type} {x : Except ε α} {a : α} (g : ε → ε') (h : x = .ok a) :
    (match x with
      | .ok t => (pure t : Except ε' α)
      | .error e => throw (g e)) = .ok a := by
  subst h
  rfl

/-- The final value of an accepting sumcheck run is the program's `scFinalExec` along the transcript's challenges. -/
theorem scVerify_fin_eq (H : HIn → Dig) (claimed : Fp2) (d n : ℕ) (hd : 1 ≤ d) (rounds : List (List Fp2)) (t : Tr)
    (fin : Fp2) (rs : List Fp2) (h : (scVerify H claimed d n rounds t).1 = .ok (fin, rs)) :
    fin = scFinalExec rounds (scChal H rounds t).1 claimed ∧ rs = (scChal H rounds t).1 := by
  unfold scVerify at h
  split at h
  · simp at h
  · obtain ⟨-, hrs, hfin⟩ := (scLoop_ok_iff H d hd rounds 0 claimed [] t fin rs).mp h
    exact ⟨hfin, by simpa using hrs⟩

/-! ## One slot -/

/-- A slot's round count `n + e` and round degree `d` (`Layout::slots`). -/
abbrev slotN (P : BlockParams) (s : ℕ) : ℕ := (slotShape P s).1 + (slotShape P s).2.1
abbrev slotD (P : BlockParams) (s : ℕ) : ℕ := (slotShape P s).2.2

/-- **One slot's honest data** (the prover's `pd`, its masks and its tables, read as functions of what the slot sees):
the published scalar (`total + c·G` private, `c·G` standalone, `c·G − Σ κ·c_h·G_h` host, argument.rs:1262-1266), the
strategy of the masked sumcheck's round words, and the terminals at the challenges. -/
structure SlotData (P : BlockParams) where
  scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2
  strat : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → WProver (slotN P s)
  terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2

section Slot

variable (H : HIn → Dig) (P : BlockParams)

/-- The transcript after `define`'s draws and `absorb_u64("pb-slot", s)`. -/
def slotT2 (s : ℕ) (t : Tr) : Tr := (t.challengeFp2Vec H (P.draws s)).2.absorbU64 H labPbSlot (UInt64.ofNat s)

/-- The slot's CFS challenge `c`. -/
def slotC (s : ℕ) (t : Tr) : Fp2 := ((slotT2 H P s t).challengeFp2 H).1

/-- The transcript after `absorb_fp2("pb-scalar", [scalar])`. -/
def slotT4 (s : ℕ) (t : Tr) (sc : Fp2) : Tr := ((slotT2 H P s t).challengeFp2 H).2.absorbFp2 H labPbScalar [sc]

/-- **The honest slot proof** for the definition `df` (`SlotProof { scalar, sc: rounds, terms }`, argument.rs:1417). -/
def slotSP (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (df : SlotDef) : SlotProof :=
  ⟨D.scalar s hist acc df (slotC H P s t),
    (scProve H (slotN P s) (D.strat s hist acc df (slotC H P s t))
      (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t)))).1,
    D.terms s hist acc df (slotC H P s t)
      (scChal H (scProve H (slotN P s) (D.strat s hist acc df (slotC H P s t))
        (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t)))).1
        (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t)))).1⟩

/-- The honest slot's challenges `ρ ‖ e` (the sumcheck's, from the transcript). -/
def slotRho (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (df : SlotDef) : List Fp2 :=
  (scChal H (slotSP H P D s hist acc t df).rounds (slotT4 H P s t (slotSP H P D s hist acc t df).scalar)).1

/-- **One slot of the honest prover** (`run_slot`, `Side::Prove`): `define` (refusing as the shared function
refuses), the CFS challenge (refused when zero), the slot proof, the degenerate-extension refusal, then the code's
shared bookkeeping (the schedule checks, the hosted sum, the terminal values, the accumulator) and the transcript
after `pb-term`. `.error ()` is a refusal (D65(2): every refusal reads the same). -/
def slotProve (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) :
    Except Unit (SlotProof × SlotRec × Acc × Tr) :=
  match P.define s hist (t.challengeFp2Vec H (P.draws s)).1 with
  | .error _ => .error ()
  | .ok df =>
    if (slotC H P s t).isZero = true then .error ()
    else if ((slotRho H P D s hist acc t df).drop (slotShape P s).1).any
        (fun x => x.isZero || decide (x = Fp2.one)) = true then .error ()
    else
      match slotDefChecks P s acc df with
      | .error _ => .error ()
      | .ok _ =>
      match hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
      | .error _ => .error ()
      | .ok claimed =>
      match tabVals (oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
          ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0 with
      | .error _ => .error ()
      | .ok vals =>
        .ok (slotSP H P D s hist acc t df,
          ⟨(t.challengeFp2Vec H (P.draws s)).1, slotC H P s t, (slotSP H P D s hist acc t df).scalar, claimed,
            (slotRho H P D s hist acc t df).take (slotShape P s).1,
            (slotRho H P D s hist acc t df).drop (slotShape P s).1, (slotSP H P D s hist acc t df).terms,
            scFinalExec (slotSP H P D s hist acc t df).rounds (slotRho H P D s hist acc t df) claimed⟩,
          slotAcc P s acc df (slotC H P s t) (slotSP H P D s hist acc t df).scalar
            (((scFinalExec (slotSP H P D s hist acc t df).rounds (slotRho H P D s hist acc t df) claimed).sub
              (df.poly vals)).mul (slotC H P s t).inv)
            (slotRho H P D s hist acc t df) (slotSP H P D s hist acc t df).terms,
          (scProve H (slotN P s) (D.strat s hist acc df (slotC H P s t))
            (slotT4 H P s t (slotSP H P D s hist acc t df).scalar)).2.absorbFp2 H labPbTerm
              (slotSP H P D s hist acc t df).terms)

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The slot's arithmetic obligation** at a state: the round words are the honest strategy of a polynomial `F` of
individual degree `≤ d` (the slot's masked polynomial `f + c·g`), the claimed sum the verifier will compute
(`hostedSum` of the accumulator's scalars, argument.rs:1440) is canonical with value `Σ F`, and the terminal count is
the schedule's. -/
def SlotSum (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef) (c : Fp2) : Prop :=
  ∃ F : (Fin (slotN P s) → K) → K, IndDegLE (slotD P s) F ∧ WHonest U (slotD P s) (slotN P s) (D.strat s hist acc df c) F
    ∧ (∀ claimed, hostedSum acc.scalars (D.scalar s hist acc df c) df.hosted = .ok claimed →
        claimed.Canon ∧ claimed.toK U = cubeSum F)
    ∧ ∀ rho, (D.terms s hist acc df c rho).length = (df.tabs.filter Tab.isPriv).length

/-- **The honest slot data from the slots' masked polynomials**: the round words are `honestW` of the slot's masked
polynomial `f + c·g` (the canonical words of its true round polynomials, `HonestClassifySum.lean`). -/
noncomputable def polySlotData (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → K) → K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2) : SlotData P :=
  ⟨scalar, fun s hist acc df c => honestW U hbij (slotD P s) (slotN P s) (poly s hist acc df c), terms⟩

/-- **With `polySlotData` the slot's obligation is the slot's arithmetic alone**: the masked polynomial's individual
degree, the claimed sum's value (the TRUE sum of the masked polynomial), and the terminal count; the round words'
honesty (`WHonest`) is discharged by construction (`honestW_honest`). -/
theorem slotSum_of_poly (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → K) → K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2) (s : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef)
    (c : Fp2) (hdeg : IndDegLE (slotD P s) (poly s hist acc df c))
    (hcl : ∀ claimed, hostedSum acc.scalars (scalar s hist acc df c) df.hosted = .ok claimed →
      claimed.Canon ∧ claimed.toK U = cubeSum (poly s hist acc df c))
    (hcnt : ∀ rho, (terms s hist acc df c rho).length = (df.tabs.filter Tab.isPriv).length) :
    SlotSum P U (polySlotData P U hbij scalar poly terms) s hist acc df c :=
  ⟨poly s hist acc df c, hdeg, honestW_honest U hbij _ _ _, hcl, hcnt⟩

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The verifier accepts the honest slot** (`slotStep`, L9): whenever the honest slot prover does not refuse and the
slot's arithmetic obligation holds, `slotStep` returns EXACTLY the prover's record, accumulator and transcript. -/
theorem slotStep_of_prove (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof)
    (r : SlotRec) (acc' : Acc) (t' : Tr) (hd : 1 ≤ slotD P s) (hdp : slotD P s < gP)
    (hsum : ∀ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
      SlotSum P U D s hist acc df (slotC H P s t))
    (h : slotProve H P D s hist acc t = .ok (sp, r, acc', t')) :
    slotStep H P s hist sp acc t = .ok (r, acc', t') := by
  unfold slotProve at h
  split at h
  · cases h
  · rename_i df hdf
    split_ifs at h with hc hes
    cases hchk : slotDefChecks P s acc df with
    | error e => simp [hchk] at h
    | ok u =>
      cases hhost : hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
      | error e => simp [hchk, hhost] at h
      | ok claimed =>
        cases htab : tabVals (oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
            ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0
          with
        | error e => simp [hchk, hhost, htab] at h
        | ok vals =>
          simp only [hchk, hhost, htab] at h
          simp only [Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl, rfl, rfl⟩ := h
          cases u
          obtain ⟨F, hF, hW, hcl, hcnt⟩ := hsum df hdf
          obtain ⟨hcc, hcv⟩ := hcl claimed hhost
          obtain ⟨fin, hsv, -, htr⟩ := scVerify_honest U H hU hd hdp (slotN P s)
            (D.strat s hist acc df (slotC H P s t)) F hF hW claimed hcc hcv
            (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t)))
          obtain ⟨hfin, -⟩ := scVerify_fin_eq H claimed _ _ hd _ _ fin _ hsv
          subst hfin
          unfold slotStep
          dsimp only
          refine bind_ok_of hdf ?_
          refine bind_ok_of hchk ?_
          refine bind_ok_of (exGuard_ok_of (ff_of_not hc)) ?_
          refine bind_ok_of (exGuard_ok_of (decide_eq_false (fun hne => hne (hcnt _)))) ?_
          refine bind_ok_of hhost ?_
          refine bind_ok_of (scCheck_ok_of hsv) ?_
          refine bind_ok_of htab ?_
          refine bind_ok_of (exGuard_ok_of (ff_of_not hes)) ?_
          show Except.ok (_, _, _) = Except.ok (_, _, _)
          congr 1
          refine Prod.ext rfl (Prod.ext rfl ?_)
          exact congrArg (fun z : Tr => z.absorbFp2 H labPbTerm (slotSP H P D s hist acc t df).terms) htr

end Slot

/-! ## The slot loop -/

section Loop

variable (H : HIn → Dig) (P : BlockParams)

/-- **The honest slot loop** (`argument_with`'s loop, the prover's side): `m` slots from slot `s`, each on the
transcript, the history and the accumulator the previous one left. -/
def slotsProve (D : SlotData P) (b g a : Fp2) :
    ℕ → List SlotRec → ℕ → Acc → Tr → Except Unit (List SlotProof × List SlotRec × Acc × Tr)
  | 0, recs, _, acc, t => .ok ([], recs, acc, t)
  | m + 1, recs, s, acc, t =>
    match slotProve H P D s (histOf b g a recs) acc t with
    | .error _ => .error ()
    | .ok (sp, r, acc', t') =>
      match slotsProve D b g a m (recs ++ [r]) (s + 1) acc' t' with
      | .error _ => .error ()
      | .ok (sps, recs', acc'', t'') => .ok (sp :: sps, recs', acc'', t'')

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The slots' arithmetic obligations along the honest run** (`SlotSum` at every state the honest loop reaches). -/
def SlotsSum (D : SlotData P) (b g a : Fp2) : ℕ → List SlotRec → ℕ → Acc → Tr → Prop
  | 0, _, _, _, _ => True
  | m + 1, recs, s, acc, t =>
    (∀ df, P.define s (histOf b g a recs) (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
        SlotSum P U D s (histOf b g a recs) acc df (slotC H P s t))
      ∧ ∀ sp r acc' t', slotProve H P D s (histOf b g a recs) acc t = .ok (sp, r, acc', t') →
        SlotsSum D b g a m (recs ++ [r]) (s + 1) acc' t'

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The verifier's slot loop accepts the honest slots** and lands on the prover's records, accumulator and
transcript. -/
theorem slotsLoop_of_prove (D : SlotData P) (b g a : Fp2) (hdeg : ∀ s, 1 ≤ slotD P s ∧ slotD P s < gP) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof) (recs' : List SlotRec)
      (acc' : Acc) (t' : Tr), SlotsSum H P U D b g a m recs s acc t →
      slotsProve H P D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      slotsLoop H P b g a recs s sps acc t = .ok (recs', acc', t')
  | 0, recs, s, acc, t, sps, recs', acc', t', _, h => by
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, rfl, rfl⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hS, h => by
    obtain ⟨hs1, hs2⟩ := hS
    simp only [slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl, rfl⟩ := h
        have hstep := slotStep_of_prove H P U hU D s (histOf b g a recs) acc t sp r acc₁ t₁ (hdeg s).1 (hdeg s).2
          hs1 hsp
        simp only [slotsLoop, hstep]
        exact slotsLoop_of_prove D b g a hdeg m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (hs2 sp r acc₁ t₁ hsp) hrest

end Loop

/-! ## The block core -/

/-- **The block core's honest data**: the roots of `A` and `M` (committed before any challenge), the root of `H` as a
function of `β, γ, α` (the LogUp helpers), the slots' data, and the three openings' honest provers (each returns the
opening and the transcript after it: `zk::mask_open`, `pcs::open_zk` of `A` and of `H`). -/
structure CoreData (P : BlockParams) where
  aRoot : Dig
  maskRoot : Dig
  hRoot : Fp2 → Fp2 → Fp2 → Dig
  slot : SlotData P
  mOpen : List MaskFunctional → Tr → MaskOpening × Tr
  aOpen : List ZClaim → Tr → OpeningZk × Tr
  hOpen : List ZClaim → Tr → OpeningZk × Tr

/-- **What the honest core prover computed**: the core (`CoreProof`'s receipt part), the LogUp challenges, the slot
records and the accumulator, and the transcript before the slots, after them, after `M`, after `A` and after `H`. -/
structure CoreRun where
  core : Core
  bga : Fp2 × Fp2 × Fp2
  recs : List SlotRec
  acc : Acc
  t3 : Tr
  t4 : Tr
  t5 : Tr
  t6 : Tr
  t7 : Tr

section Core

variable (H : HIn → Dig) (P : BlockParams)

/-- The transcript after `absorb_root("A")` and `absorb("M")`. -/
def coreT2 (D : CoreData P) (t : Tr) : Tr :=
  (absorbRoot H t labA D.aRoot P.aRows P.logCols).absorb H labM D.maskRoot.toList

/-- The LogUp challenges `β, γ, α`. -/
def coreB (D : CoreData P) (t : Tr) : Fp2 × Tr := (coreT2 H P D t).challengeFp2 H
def coreG (D : CoreData P) (t : Tr) : Fp2 × Tr := (coreB H P D t).2.challengeFp2 H
def coreA (D : CoreData P) (t : Tr) : Fp2 × Tr := (coreG H P D t).2.challengeFp2 H

/-- The transcript after `absorb_root("H")`: the slots start here. -/
def coreT3 (D : CoreData P) (t : Tr) : Tr :=
  absorbRoot H (coreA H P D t).2 labH (D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1) P.hRows P.logCols

/-- **The block core's honest prover** (`prove_core_after_with`): the roots and the LogUp challenges, the slots, the
functional count (both sides, `argument_with`), `M`'s opening, `check_opening` of `A` (refused as the verifier
refuses), `A`'s opening, the same for `H` with `logup_sum_claim` appended (`finish_claims`). -/
def coreProve (D : CoreData P) (t : Tr) : Except Unit CoreRun :=
  match slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 P.geom.slots.length [] 0 {}
      (coreT3 H P D t) with
  | .error _ => .error ()
  | .ok (sps, recs, acc, t4) =>
    if (acc.fs ++ acc.hostFs).length ≠ P.nFunctionals then .error ()
    else
      match P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | .error _ => .error ()
      | .ok _ =>
        match P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | .error _ => .error ()
        | .ok _ =>
          .ok ⟨⟨D.aRoot, D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1, D.maskRoot, sps,
              (D.mOpen (acc.fs ++ acc.hostFs) t4).1, (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).1,
              (D.hOpen (acc.claims.h ++ [P.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).1⟩,
            ((coreB H P D t).1, (coreG H P D t).1, (coreA H P D t).1), recs, acc, coreT3 H P D t, t4,
            (D.mOpen (acc.fs ++ acc.hostFs) t4).2, (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2,
            (D.hOpen (acc.claims.h ++ [P.logupSumClaim]) (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2⟩

/-- **The honest core run's facts**: the core's roots and slots, the run's LogUp challenges and transcripts, the
slot loop's result, the functional count, and both `check_opening`s passed. -/
theorem coreProve_ok (D : CoreData P) (t : Tr) (R : CoreRun) (h : coreProve H P D t = .ok R) :
    slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 P.geom.slots.length [] 0 {}
        (coreT3 H P D t) = .ok (R.core.slots, R.recs, R.acc, R.t4)
      ∧ (R.acc.fs ++ R.acc.hostFs).length = P.nFunctionals
      ∧ P.checkOpening H .a R.acc.claims.a R.t5 = .ok ()
      ∧ P.checkOpening H .h (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 = .ok ()
      ∧ R.core.aRoot = D.aRoot ∧ R.core.maskRoot = D.maskRoot
      ∧ R.core.hRoot = D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
      ∧ R.t3 = coreT3 H P D t
      ∧ (R.core.maskOpen, R.t5) = D.mOpen (R.acc.fs ++ R.acc.hostFs) R.t4
      ∧ (R.core.aOpen, R.t6) = D.aOpen R.acc.claims.a R.t5
      ∧ (R.core.hOpen, R.t7) = D.hOpen (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 := by
  unfold coreProve at h
  split at h
  · cases h
  · rename_i sps recs acc t4 hs
    split_ifs at h with hfs
    cases hA : P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
    | error e => simp [hA] at h
    | ok u1 =>
      cases hH : P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
          (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
      | error e => simp [hA, hH] at h
      | ok u2 =>
        simp only [hA, hH] at h
        simp only [Except.ok.injEq] at h
        subst h
        cases u1
        cases u2
        exact ⟨hs, not_not.mp hfs, hA, hH, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **`verify_core` accepts the honest core** (completeness of L9's `blockVerify`, generic in `BlockParams`): given
the honest core prover's run `R` (it did not refuse), the profile's pre-checks, the honest openings' path depths
(T-4), the slots' arithmetic obligations along the run (`SlotsSum`), and the completeness of the three openings on the
run's own functionals and claims (`M`, `A`, `H`: L10's components), the verifier returns the core's IO claims and the
prover's final transcript. -/
theorem blockVerify_of_prove (D : CoreData P) (t : Tr) (R : CoreRun) (h : coreProve H P D t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD P s ∧ slotD P s < gP) (hpre : P.preChecks = .ok ())
    (hpA : pathsDepth "A" P.aPath 0 R.core.aOpen.columns = .ok ())
    (hpH : pathsDepth "H" P.hPath 0 R.core.hOpen.columns = .ok ())
    (hpM : pathsDepth "M" P.maskPath 0 R.core.maskOpen.columns = .ok ())
    (hslots : SlotsSum H P U D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 P.geom.slots.length [] 0 {}
      (coreT3 H P D t))
    (hM : P.maskVerify H D.maskRoot (R.acc.fs ++ R.acc.hostFs) R.core.maskOpen R.t4 = .ok R.t5)
    (hA : P.pcsVerify H .a D.aRoot R.acc.claims.a R.core.aOpen R.t5 = .ok R.t6)
    (hH : P.pcsVerify H .h R.core.hRoot (R.acc.claims.h ++ [P.logupSumClaim]) R.core.hOpen R.t6 = .ok R.t7) :
    blockVerify H P R.core t = .ok ((R.acc.claims.inp, R.acc.claims.out), R.t7) := by
  obtain ⟨hs, hfs, hcA, hcH, haR, hmR, hhR, -, -, -, -⟩ := coreProve_ok H P D t R h
  have hloop := slotsLoop_of_prove H P U hU D.slot _ _ _ hdeg _ _ _ _ _ _ _ _ _ hslots hs
  rcases R with ⟨⟨aR, hR, mR, sl, mo, ao, ho⟩, bga, recs, acc, t3, t4, t5, t6, t7⟩
  have haR' : aR = D.aRoot := haR
  have hmR' : mR = D.maskRoot := hmR
  have hhR' : hR = D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 := hhR
  subst haR' hmR' hhR'
  have hM' : P.maskVerify H D.maskRoot (acc.fs ++ acc.hostFs) mo t4 = .ok t5 := hM
  have hA' : P.pcsVerify H .a D.aRoot acc.claims.a ao t5 = .ok t6 := hA
  have hH' : P.pcsVerify H .h (D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1)
      (acc.claims.h ++ [P.logupSumClaim]) ho t6 = .ok t7 := hH
  have hcA' : P.checkOpening H .a acc.claims.a t5 = .ok () := hcA
  have hcH' : P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim]) t6 = .ok () := hcH
  have hfs' : (acc.fs ++ acc.hostFs).length = P.nFunctionals := hfs
  have hbs : blockSlots H P ⟨D.aRoot, D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1, D.maskRoot, sl,
      mo, ao, ho⟩ t = .ok (((coreB H P D t).1, (coreG H P D t).1, (coreA H P D t).1), recs, acc, t4) :=
    congrArg (fun z : Except String (List SlotRec × Acc × Tr) => match z with
      | .ok r => (.ok (((coreB H P D t).1, (coreG H P D t).1, (coreA H P D t).1), r) :
          Except String ((Fp2 × Fp2 × Fp2) × List SlotRec × Acc × Tr))
      | .error e => .error e) hloop
  unfold blockVerify
  refine bind_ok_of hpre ?_
  refine bind_ok_of hpA ?_
  refine bind_ok_of hpH ?_
  refine bind_ok_of hpM ?_
  refine bind_ok_of hbs ?_
  dsimp only
  simp only [hfs', ne_eq, not_true_eq_false, ↓reduceIte, pure_bind]
  -- the do-block put each continuation inside the sub-check's `match`
  simp only [hM']
  refine bind_ok_of hcA' ?_
  simp only [hA']
  refine bind_ok_of hcH' ?_
  simp only [hH']
  all_goals rfl

/-! ## O9 for a block: the honest prover refuses only at the listed sites -/

omit hU in
/-- **A slot of the honest prover refuses only at a listed site**: `define`'s own refusal (`ν` zero, a zero
batching coefficient: the shared public function), the CFS challenge `c = 0`, a degenerate extension challenge
(`e ∈ {0, 1}`), or a deterministic schedule failure (`slotDefChecks`, a hosted index, a table length). -/
theorem slotProve_refuses (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr)
    (h : slotProve H P D s hist acc t = .error ()) :
    (∃ e, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .error e)
      ∨ ∃ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df
        ∧ ((slotC H P s t).isZero = true
          ∨ ((slotRho H P D s hist acc t df).drop (slotShape P s).1).any
              (fun x => x.isZero || decide (x = Fp2.one)) = true
          ∨ (∃ e, slotDefChecks P s acc df = .error e)
          ∨ (∃ e, hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted = .error e)
          ∨ ∃ e, tabVals (oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
              ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0
              = .error e) := by
  unfold slotProve at h
  split at h
  · rename_i e he
    exact Or.inl ⟨e, he⟩
  · rename_i df hdf
    refine Or.inr ⟨df, hdf, ?_⟩
    split_ifs at h with hc hes
    · exact Or.inl hc
    · exact Or.inr (Or.inl hes)
    · right; right
      cases h1 : slotDefChecks P s acc df with
      | error e => exact Or.inl ⟨e, rfl⟩
      | ok u =>
        cases h2 : hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
        | error e => exact Or.inr (Or.inl ⟨e, rfl⟩)
        | ok claimed =>
          cases h3 : tabVals (oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
              ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0
            with
          | error e => exact Or.inr (Or.inr ⟨e, rfl⟩)
          | ok vals => simp [h1, h2, h3] at h

omit hU in
/-- **The honest slot loop refuses only where one of its slots refuses**, at that slot's own state (the state the
earlier honest slots left). -/
theorem slotsProve_refuses (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      slotsProve H P D b g a m recs s acc t = .error () →
      ∃ (i : ℕ) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < m
        ∧ slotProve H P D (s + i) (histOf b g a recs₁) acc₁ t₁ = .error ()
  | 0, _, _, _, _, h => by cases h
  | m + 1, recs, s, acc, t, h => by
    simp only [slotsProve] at h
    split at h
    · rename_i e he
      cases e
      exact ⟨0, recs, acc, t, by omega, by simpa using he⟩
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · rename_i e he
        cases e
        obtain ⟨i, recs₂, acc₂, t₂, hi, hr⟩ := slotsProve_refuses D b g a m (recs ++ [r]) (s + 1) acc₁ t₁ he
        exact ⟨i + 1, recs₂, acc₂, t₂, by omega, by rw [show s + (i + 1) = s + 1 + i by omega]; exact hr⟩
      · cases h

omit hU in
/-- **The honest core prover refuses only at a listed site**: a slot's refusal (`slotProve_refuses`), the functional
count (deterministic), or `check_opening`'s refusal of `A` or of `H` (the schedule audit, the group count, a zero
member coefficient, the proximity pair dependent over `Fp`: protocol.rs:312-322, on a clone). -/
theorem coreProve_refuses (D : CoreData P) (t : Tr) (h : coreProve H P D t = .error ()) :
    (∃ (i : ℕ) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < P.geom.slots.length
        ∧ slotProve H P D.slot i (histOf (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 recs₁) acc₁ t₁ = .error ())
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
        slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 P.geom.slots.length [] 0 {}
          (coreT3 H P D t) = .ok (sps, recs, acc, t4)
        ∧ ((acc.fs ++ acc.hostFs).length ≠ P.nFunctionals
          ∨ (∃ e, P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
          ∨ ∃ e, P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e) := by
  unfold coreProve at h
  split at h
  · rename_i e he
    cases e
    obtain ⟨i, recs₁, acc₁, t₁, hi, hr⟩ := slotsProve_refuses H P D.slot _ _ _ _ [] 0 {} _ he
    exact Or.inl ⟨i, recs₁, acc₁, t₁, hi, by simpa using hr⟩
  · rename_i sps recs acc t4 hs
    refine Or.inr ⟨sps, recs, acc, t4, hs, ?_⟩
    split_ifs at h with hfs
    · exact Or.inl hfs
    · cases hA : P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e => exact Or.inr (Or.inl ⟨e, rfl⟩)
      | ok u1 =>
        cases hH : P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | error e => exact Or.inr (Or.inr ⟨e, rfl⟩)
        | ok u2 => simp [hA, hH] at h

end Core

end ZK60.HonestClassify
