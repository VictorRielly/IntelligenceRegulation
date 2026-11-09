/-
D63 Lean lane L29 (2026-11-09), part 8: **the honest slot loop as ONE transcript program, and its refusals covered by
`δ = 0` sites** (the step finding L25-3 names: writing the run's prefix up to each refusal as a transcript program).

`HonestOracleProg.lean` gives, for ANY prefix program ending at a slot's entry, that slot's refusal sites. This file
BUILDS that prefix inside a part (a block's core, a stage): the part's head (a parameter: its frame, roots and
challenges as a program) followed by the earlier honest slots, each slot written as a transcript program with the same
absorbs and squeezes as lane L25's `slotProve` (`define`'s draws, `pb-slot`, the CFS challenge, `pb-scalar`, the honest
rounds, `pb-term`), returning what `slotProve` returns.

The loop is over a FAMILY of slot parameters (`Pf s`, `Df s`): a block's core and stage OUT-C use one `BlockParams` for
every slot (L25's `slotsProve`), stage IN-C reads each slot's IO commitment at its own row width (`stSlotsProve`,
finding L29-1); and the family may depend on the head's data (`Pf x`: stage IN-C's `define` reads `r_emb`, finding
L29-2), which a transcript program must compute from its own squeezes, not from the oracle.

Proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `scPc`, **`final_scPc`**: the honest sumcheck as a program returning its rounds AND challenges is L25's `scProve`
  with L6's `scChal`;
* `slotOut`, `slotProg`, **`final_slotProg`**: one honest slot as a program: whenever `slotProve` returns, the program
  ends on its transcript with its proof, record and accumulator;
* `famProve`, **`slotsProve_eq_fam`**, **`stSlotsProve_eq_fam`**: the honest slot loop over a family, and that L25's
  loop and the stage loop of this lane are instances;
* `famProg`, **`final_famProg`**: the loop as a program; **`famProve_refuses_at`**: the loop refuses only at a slot
  whose state is the one the earlier honest slots LEFT;
* `famPre`, **`final_famPre`**: the prefix of slot `i` of a part (head, then `i` honest slots);
* `depCProg`, **`depCSite`**, **`depCSite_fires`**; `depEProg`, **`depESite`**, **`depESite_fires`**: the CFS and the
  degenerate-extension sites of slot `i` when the slot's parameters depend on the prefix's data;
  **`drawZeroSite_fires_at`**: a zero draw of `define`;
* **`fam_refuse_cover`**: if the honest loop of a part refuses, then at the slot `i` where it does, with the prefix
  `famPre … i` ending on the loop's own state: `define` refused (a zero batching draw, or a deterministic builder
  failure of the instance), or slot `i`'s CFS site fires, or one of its extension-round sites fires, or a deterministic
  schedule check failed. Every site named is a `tprogSite`: `δ = 0`, `k ≤ 2`.
-/
import ZK60Formal.HonestOracleProg

set_option autoImplicit false

namespace ZK60.HonestOracle

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams Hist Acc SlotDef SlotProof SlotRec histOf slotShape slotDefChecks hostedSum tabVals
  oneMinusProd slotAcc labPbSlot labPbScalar labPbTerm)
open ZK60.Exec.StageV (atLog sdAt stSlotsProve)

/-! ## Lists -/

theorem exists_getD_of_mem {α : Type} (d x : α) : ∀ (l : List α), x ∈ l → ∃ m, m < l.length ∧ l.getD m d = x
  | [], h => by cases h
  | y :: l, h => by
    rcases List.mem_cons.mp h with e | h'
    · exact ⟨0, Nat.succ_pos _, by rw [e]; rfl⟩
    · obtain ⟨m, hm, e⟩ := exists_getD_of_mem d x l h'
      exact ⟨m + 1, Nat.succ_lt_succ hm, e⟩

/-- A member of `l.drop a` is `l`'s entry at an index `m` with `a ≤ m < |l|`. -/
theorem exists_getD_of_mem_drop {α : Type} (d x : α) : ∀ (l : List α) (a : ℕ), x ∈ l.drop a →
    ∃ m, a ≤ m ∧ m < l.length ∧ l.getD m d = x
  | l, 0, h => by
    obtain ⟨m, hm, e⟩ := exists_getD_of_mem d x l h
    exact ⟨m, Nat.zero_le _, hm, e⟩
  | [], _ + 1, h => by cases h
  | _ :: l, a + 1, h => by
    obtain ⟨m, ha, hm, e⟩ := exists_getD_of_mem_drop d x l a h
    exact ⟨m + 1, Nat.succ_le_succ ha, Nat.succ_lt_succ hm, e⟩

/-! ## The honest sumcheck as a program that also returns its challenges -/

section Sc

variable {β : Type} (H : HIn → Dig)

/-- **The honest sumcheck as a program** whose continuation reads the rounds and their challenges. -/
def scPc : (n : ℕ) → WProver n → (List (List Fp2) → List Fp2 → TProg β) → TProg β
  | 0, _, k => k [] []
  | n + 1, p, k => .absorb scLabel (p.1.flatMap Fp2.toBytes)
      (.squeeze (fun dg => scPc n (p.2 (challengeFp2Of dg)) (fun rs cs => k (p.1 :: rs) (challengeFp2Of dg :: cs))))

/-- **It is L25's `scProve`**: the rounds are the prover's, the challenges the verifier's walk over them (`scChal`). -/
theorem final_scPc : ∀ (n : ℕ) (p : WProver n) (k : List (List Fp2) → List Fp2 → TProg β) (t : Tr),
    (scPc n p k).final H t
      = (k (scProve H n p t).1 (scChal H (scProve H n p t).1 t).1).final H (scProve H n p t).2
  | 0, _, _, _ => rfl
  | n + 1, p, k, t =>
    final_scPc n (p.2 (challengeFp2Of ((t.absorb H scLabel (p.1.flatMap Fp2.toBytes)).squeeze H).1))
      (fun rs cs => k (p.1 :: rs)
        (challengeFp2Of ((t.absorb H scLabel (p.1.flatMap Fp2.toBytes)).squeeze H).1 :: cs))
      ((t.absorb H scLabel (p.1.flatMap Fp2.toBytes)).squeeze H).2

theorem sep_scPc (key : Option Dig) : ∀ (n : ℕ) (p : WProver n) (k : List (List Fp2) → List Fp2 → TProg β),
    (∀ rs cs, TProg.Sep key (k rs cs)) → TProg.Sep key (scPc n p k)
  | 0, _, _, hk => hk [] []
  | n + 1, _, _, hk => fun _ => sep_scPc key n _ _ (fun _ _ => hk _ _)

end Sc

/-! ## One honest slot as a transcript program -/

section Slot

variable (H : HIn → Dig) (P : BlockParams)

/-- **What the honest slot returns**, from the values its transcript gave it (`define`'s draws `dr` and definition
`df`, the CFS challenge `c`, the slot proof `sp`, the rounds' challenges `rho`): the body of L25's `slotProve` after
`define`, without the transcript. -/
def slotOut (s : ℕ) (acc : Acc) (dr : List Fp2) (df : SlotDef) (c : Fp2) (sp : SlotProof) (rho : List Fp2) :
    Except Unit (SlotProof × SlotRec × Acc) :=
  if c.isZero = true then .error ()
  else if (rho.drop (slotShape P s).1).any (fun x => x.isZero || decide (x = Fp2.one)) = true then .error ()
  else
    match slotDefChecks P s acc df with
    | .error _ => .error ()
    | .ok _ =>
    match hostedSum acc.scalars sp.scalar df.hosted with
    | .error _ => .error ()
    | .ok claimed =>
    match tabVals (oneMinusProd (rho.drop (slotShape P s).1)) (rho.take (slotShape P s).1) sp.terms df.tabs 0 with
    | .error _ => .error ()
    | .ok vals =>
      .ok (sp,
        ⟨dr, c, sp.scalar, claimed, rho.take (slotShape P s).1, rho.drop (slotShape P s).1, sp.terms,
          scFinalExec sp.rounds rho claimed⟩,
        slotAcc P s acc df c sp.scalar (((scFinalExec sp.rounds rho claimed).sub (df.poly vals)).mul c.inv) rho sp.terms)

/-- The slot's program after its CFS challenge `c`, at what `define` returned: `pb-scalar`, the honest rounds,
`pb-term`, and the slot's result. -/
def slotAfterC (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (dr : List Fp2) (c : Fp2) :
    Except String SlotDef → TProg (Except Unit (SlotProof × SlotRec × Acc))
  | .error _ => .done (.error ())
  | .ok df => .absorb labPbScalar ([D.scalar s hist acc df c].flatMap Fp2.toBytes)
      (scPc (slotN P s) (D.strat s hist acc df c) (fun rounds rho =>
        .absorb labPbTerm ((D.terms s hist acc df c rho).flatMap Fp2.toBytes)
          (.done (slotOut P s acc dr df c ⟨D.scalar s hist acc df c, rounds, D.terms s hist acc df c rho⟩ rho))))

/-- **One honest slot as a transcript program** (`run_slot`, `Side::Prove`), from its history and accumulator:
`define`'s draws, `absorb_u64("pb-slot", s)`, the CFS challenge, then `slotAfterC`. -/
def slotProg (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) : TProg (Except Unit (SlotProof × SlotRec × Acc)) :=
  drawsP (P.draws s) (fun dr => .absorb labPbSlot (le64 (UInt64.ofNat s)) (.squeeze (fun dgc =>
    slotAfterC P D s hist acc dr (challengeFp2Of dgc) (P.define s hist dr))))

/-- **The slot's program is L25's `slotProve`**: whenever the honest slot prover returns, the program ends on its
transcript, with its slot proof, record and accumulator. -/
theorem final_slotProg (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof) (r : SlotRec)
    (acc' : Acc) (t' : Tr) (h : slotProve H P D s hist acc t = .ok (sp, r, acc', t')) :
    (slotProg P D s hist acc).final H t = (t', .ok (sp, r, acc')) := by
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
          unfold slotProg
          rw [final_drawsP]
          show TProg.final H (slotAfterC P D s hist acc (t.challengeFp2Vec H (P.draws s)).1 (slotC H P s t)
            (P.define s hist (t.challengeFp2Vec H (P.draws s)).1)) ((slotT2 H P s t).squeeze H).2 = _
          rw [hdf]
          show TProg.final H (scPc (slotN P s) (D.strat s hist acc df (slotC H P s t)) _)
            (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t))) = _
          rw [final_scPc]
          show ((scProve H (slotN P s) (D.strat s hist acc df (slotC H P s t))
              (slotT4 H P s t (slotSP H P D s hist acc t df).scalar)).2.absorbFp2 H labPbTerm
                (slotSP H P D s hist acc t df).terms,
            slotOut P s acc (t.challengeFp2Vec H (P.draws s)).1 df (slotC H P s t) (slotSP H P D s hist acc t df)
              (slotRho H P D s hist acc t df)) = _
          unfold slotOut
          simp only [hc, hes, hchk, hhost, htab, Bool.false_eq_true, ↓reduceIte]

theorem sep_slotAfterC (key : Option Dig) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (dr : List Fp2) (c : Fp2) :
    ∀ r : Except String SlotDef, TProg.Sep key (slotAfterC P D s hist acc dr c r)
  | .error _ => trivial
  | .ok _ => sep_scPc key _ _ _ (fun _ _ => trivial)

theorem sep_slotProg (key : Option Dig) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) :
    TProg.Sep key (slotProg P D s hist acc) :=
  sep_drawsP key _ _ (fun _ _ => sep_slotAfterC P key D s hist acc _ _ _)

/-- The honest slot's challenges are one per round. -/
theorem slotRho_length (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (df : SlotDef) :
    (slotRho H P D s hist acc t df).length = slotN P s := by
  unfold slotRho
  rw [scChal_length]
  exact scProve_length H _ _ _

end Slot

/-! ## The honest slot loop over a family of slot parameters -/

section Loop

variable (H : HIn → Dig) (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s))

/-- **The honest slot loop over a family** (slot `s` at `Pf s`, `Df s`): L25's `slotsProve` at a constant family, this
lane's `stSlotsProve` at the stage's per-slot IO row widths. -/
def famProve (b g a : Fp2) :
    ℕ → List SlotRec → ℕ → Acc → Tr → Except Unit (List SlotProof × List SlotRec × Acc × Tr)
  | 0, recs, _, acc, t => .ok ([], recs, acc, t)
  | m + 1, recs, s, acc, t =>
    match slotProve H (Pf s) (Df s) s (histOf b g a recs) acc t with
    | .error _ => .error ()
    | .ok (sp, r, acc', t') =>
      match famProve b g a m (recs ++ [r]) (s + 1) acc' t' with
      | .error _ => .error ()
      | .ok (sps, recs', acc'', t'') => .ok (sp :: sps, recs', acc'', t'')

/-- **The loop as a transcript program**: each slot's program, the next slot from the record and accumulator it
returned (after a refused slot the program goes on from the unchanged state: the honest prover has stopped, and no
statement here reads a program past its first refusal). -/
def famProg (b g a : Fp2) : ℕ → List SlotRec → ℕ → Acc → TProg (List SlotRec × Acc)
  | 0, recs, _, acc => .done (recs, acc)
  | m + 1, recs, s, acc => bindP (slotProg (Pf s) (Df s) s (histOf b g a recs) acc) (fun r =>
      match r with
      | .ok x => famProg b g a m (recs ++ [x.2.1]) (s + 1) x.2.2
      | .error _ => famProg b g a m recs (s + 1) acc)

/-- **The loop's program is the honest loop**: whenever `m` honest slots return, the program ends on their transcript
with their records and accumulator. -/
theorem final_famProg (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof) (recs' : List SlotRec)
      (acc' : Acc) (t' : Tr), famProve H Pf Df b g a m recs s acc t = .ok (sps, recs', acc', t') →
      (famProg Pf Df b g a m recs s acc).final H t = (t', (recs', acc'))
  | 0, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [famProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, rfl, rfl⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [famProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨-, rfl, rfl, rfl⟩ := h
        show (bindP (slotProg (Pf s) (Df s) s (histOf b g a recs) acc) _).final H t = _
        rw [final_bindP, final_slotProg H (Pf s) (Df s) s (histOf b g a recs) acc t sp r acc₁ t₁ hsp]
        exact final_famProg b g a m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂ hrest

theorem sep_famProg (key : Option Dig) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc), TProg.Sep key (famProg Pf Df b g a m recs s acc)
  | 0, _, _, _ => trivial
  | m + 1, recs, s, acc => sep_bindP key _ _ (sep_slotProg (Pf s) key (Df s) s _ acc) (fun r => by
      cases r with
      | error e => exact sep_famProg key b g a m recs (s + 1) acc
      | ok x => exact sep_famProg key b g a m (recs ++ [x.2.1]) (s + 1) x.2.2)

/-- **The honest loop refuses only at a slot it REACHED**: if `m` slots refuse, then some `i < m` honest slots
returned, and slot `s + i` refuses on the state they left. -/
theorem famProve_refuses_at (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      famProve H Pf Df b g a m recs s acc t = .error () →
      ∃ (i : ℕ) (sps : List SlotProof) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < m
        ∧ famProve H Pf Df b g a i recs s acc t = .ok (sps, recs₁, acc₁, t₁)
        ∧ slotProve H (Pf (s + i)) (Df (s + i)) (s + i) (histOf b g a recs₁) acc₁ t₁ = .error ()
  | 0, _, _, _, _, h => by cases h
  | m + 1, recs, s, acc, t, h => by
    simp only [famProve] at h
    split at h
    · rename_i e he
      cases e
      exact ⟨0, [], recs, acc, t, Nat.succ_pos _, rfl, he⟩
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · rename_i e he
        cases e
        obtain ⟨i, sps, recs₂, acc₂, t₂, hi, hok, hr⟩ := famProve_refuses_at b g a m (recs ++ [r]) (s + 1) acc₁ t₁ he
        refine ⟨i + 1, sp :: sps, recs₂, acc₂, t₂, Nat.succ_lt_succ hi, ?_, ?_⟩
        · simp only [famProve, hsp, hok]
        · rw [show s + (i + 1) = s + 1 + i by omega]
          exact hr
      · cases h

end Loop

/-! ### L25's loop and the stage loop are instances -/

section Instances

variable (H : HIn → Dig) (P : BlockParams)

/-- **L25's `slotsProve` is the loop at the constant family** (a block's core, stage OUT-C). -/
theorem slotsProve_eq_fam (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      slotsProve H P D b g a m recs s acc t = famProve H (fun _ => P) (fun _ => D) b g a m recs s acc t
  | 0, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t => by
    simp only [slotsProve, famProve]
    cases slotProve H P D s (histOf b g a recs) acc t with
    | error e => rfl
    | ok x =>
      obtain ⟨sp, r, acc', t'⟩ := x
      simp only [slotsProve_eq_fam D b g a m (recs ++ [r]) (s + 1) acc' t']
      rfl

/-- **This lane's `stSlotsProve` is the loop at the stage's per-slot IO row widths** (stage IN-C). -/
theorem stSlotsProve_eq_fam (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      stSlotsProve H P elog D b g a m recs s acc t
        = famProve H (fun s => atLog P (elog s)) (fun s => sdAt D (elog s)) b g a m recs s acc t
  | 0, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t => by
    simp only [stSlotsProve, famProve]
    cases slotProve H (atLog P (elog s)) (sdAt D (elog s)) s (histOf b g a recs) acc t with
    | error e => rfl
    | ok x =>
      obtain ⟨sp, r, acc', t'⟩ := x
      simp only [stSlotsProve_eq_fam elog D b g a m (recs ++ [r]) (s + 1) acc' t']
      rfl

end Instances

/-! ## A part's prefix up to slot `i`, and slot `i`'s sites when its parameters depend on the head -/

section Pre

variable {α : Type} (H : HIn → Dig) (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s))
  (bga : α → Fp2 × Fp2 × Fp2)

/-- **The prefix of slot `i` of a part**: the part's head `hd` (its frame, roots and challenges as a program, ending
where the slots start, with the data `x` the slots' parameters and `define` read), then the first `i` honest slots.
Its data: the head's, the records and the accumulator slot `i` starts from. -/
def famPre (hd : TProg α) (i : ℕ) : TProg (α × List SlotRec × Acc) :=
  bindP hd (fun x => bindP (famProg (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 i [] 0 {})
    (fun ra => .done (x, ra)))

/-- **The prefix ends on the honest loop's own state**: when the first `i` honest slots return. -/
theorem final_famPre (hd : TProg α) (i : ℕ) (t : Tr) (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (ti : Tr)
    (h : famProve H (Pf (hd.final H t).2) (Df (hd.final H t).2) (bga (hd.final H t).2).1 (bga (hd.final H t).2).2.1
      (bga (hd.final H t).2).2.2 i [] 0 {} (hd.final H t).1 = .ok (sps, recs, acc, ti)) :
    (famPre Pf Df bga hd i).final H t = (ti, ((hd.final H t).2, recs, acc)) := by
  unfold famPre
  rw [final_bindP, final_bindP, final_famProg H _ _ _ _ _ i [] 0 {} _ sps recs acc ti h]
  rfl

theorem sep_famPre (key : Option Dig) (hd : TProg α) (hh : TProg.Sep key hd) (i : ℕ) :
    TProg.Sep key (famPre Pf Df bga hd i) :=
  sep_bindP key hd _ hh (fun x => sep_bindP key _ _ (sep_famProg (Pf x) (Df x) key _ _ _ i [] 0 {}) (fun _ => trivial))

/-- **Slot `i`'s CFS site program** after a prefix `pre` ending at the slot's entry with the head's data: `define`'s
draws (their number read off the prefix's data) and `pb-slot`; the next squeeze is `c`. -/
def depCProg (pre : TProg (α × List SlotRec × Acc)) (i : ℕ) : TProg ((α × List SlotRec × Acc) × List Fp2) :=
  bindP pre (fun y => drawsP ((Pf y.1 i).draws i) (fun dr =>
    .absorb labPbSlot (le64 (UInt64.ofNat i)) (.done (y, dr))))

theorem final_depCProg (pre : TProg (α × List SlotRec × Acc)) (i : ℕ) (t : Tr) :
    (depCProg Pf pre i).final H t
      = (slotT2 H (Pf (pre.final H t).2.1 i) i (pre.final H t).1,
          ((pre.final H t).2,
            ((pre.final H t).1.challengeFp2Vec H ((Pf (pre.final H t).2.1 i).draws i)).1)) := by
  unfold depCProg
  rw [final_bindP, final_drawsP]
  rfl

theorem sep_depCProg (key : Option Dig) (pre : TProg (α × List SlotRec × Acc)) (i : ℕ) (hp : TProg.Sep key pre) :
    TProg.Sep key (depCProg Pf pre i) :=
  sep_bindP key pre _ hp (fun _ => sep_drawsP key _ _ (fun _ => trivial))

/-- **Slot `i`'s prefix up to round `m`'s words**: the CFS site's program, the CFS challenge, then (at the slot's
definition) `pb-scalar` and the honest rounds up to round `m`'s words; the next squeeze is round `m`'s challenge. -/
def depEProg (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) : TProg Unit :=
  bindP (depCProg Pf pre i) (fun yd => .squeeze (fun dgc =>
    slotEAfter (Pf yd.1.1 i) i (Df yd.1.1 i) m
      (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.1.2.2 (challengeFp2Of dgc)
      ((Pf yd.1.1 i).define i (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.2)))

theorem final_depEProg (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) (t : Tr) (ti : Tr) (x : α)
    (recs : List SlotRec) (acc : Acc) (hY : pre.final H t = (ti, (x, recs, acc))) (df : SlotDef)
    (hdf : (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
      (ti.challengeFp2Vec H ((Pf x i).draws i)).1 = .ok df) :
    ((depEProg Pf Df bga pre i m).final H t).1
      = ((scUpToP (slotN (Pf x i) i) ((Df x i).strat i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df
            (slotC H (Pf x i) i ti)) m).final H
          (slotT4 H (Pf x i) i ti ((Df x i).scalar i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df
            (slotC H (Pf x i) i ti)))).1 := by
  unfold depEProg
  rw [final_bindP, final_depCProg, hY]
  show (TProg.final H (slotEAfter (Pf x i) i (Df x i) m (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc
      (challengeFp2Of ((slotT2 H (Pf x i) i ti).squeeze H).1)
      ((Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
        (ti.challengeFp2Vec H ((Pf x i).draws i)).1))
      ((slotT2 H (Pf x i) i ti).squeeze H).2).1 = _
  rw [hdf]
  rfl

theorem sep_depEProg (key : Option Dig) (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) (hp : TProg.Sep key pre) :
    TProg.Sep key (depEProg Pf Df bga pre i m) :=
  sep_bindP key _ _ (sep_depCProg Pf key pre i hp) (fun _ _ => sep_slotEAfter _ _ _ key m _ _ _ _)

end Pre

/-! ## The sites, and the cover of the honest loop's refusals -/

section Sites

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} (Pf : α → ℕ → BlockParams)
  (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
  {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **Slot `i`'s CFS refusal as L18's `Site`** (`{0}`, `k = 1`, `δ = 0`), the slot's parameters read off the prefix. -/
noncomputable def depCSite (pre : Coins → TProg (α × List SlotRec × Acc)) (i : ℕ) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (depCProg Pf (pre c) i) (t0 c)) :
    Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => depCProg Pf (pre c) i) t0 (fun _ => ({0} : Finset K)) 1 (fun _ => by simp)
    (fun c => sep_depCProg Pf _ (pre c) i (hs c)) hn

/-- **Round `m`'s degenerate value of slot `i` as L18's `Site`** (`{0, 1}`, `k = 2`, `δ = 0`). -/
noncomputable def depESite (pre : Coins → TProg (α × List SlotRec × Acc)) (i m : ℕ) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (depEProg Pf Df bga (pre c) i m) (t0 c)) :
    Site (QB Lq) Coins K :=
  tprogSite Lq hLq (fun c => depEProg Pf Df bga (pre c) i m) t0 (fun _ => ({0, 1} : Finset K)) 2
    (fun _ => Finset.card_le_two) (fun c => sep_depEProg Pf Df bga _ (pre c) i m (hs c)) hn

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

omit [DecidableEq K] in
/-- **The CFS site fires EXACTLY when the honest slot's CFS guard does**, at the state the prefix leaves. -/
theorem depCSite_fires (pre : Coins → TProg (α × List SlotRec × Acc)) (i : ℕ) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (depCProg Pf (pre c) i) (t0 c))
    (G : QB Lq → Dig) (c : Coins) :
    (depCSite Lq hLq Pf pre i t0 hs hn (K := K)).fires U G c
      ↔ (slotC (liftH G) (Pf ((pre c).final (liftH G) (t0 c)).2.1 i) i ((pre c).final (liftH G) (t0 c)).1).isZero
          = true := by
  unfold depCSite
  rw [tprogSite_fires, final_depCProg, slot_c_guard_iff U hU]

/-- **The site of round `m` fires EXACTLY when the honest slot's challenge of round `m` is `0` or `1`**, at the state
the prefix leaves. -/
theorem depESite_fires (pre : Coins → TProg (α × List SlotRec × Acc)) (i m : ℕ) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (depEProg Pf Df bga (pre c) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (ti : Tr) (x : α) (recs : List SlotRec) (acc : Acc)
    (hY : (pre c).final (liftH G) (t0 c) = (ti, (x, recs, acc))) (hm : m < slotN (Pf x i) i) (df : SlotDef)
    (hdf : (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
      (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .ok df) :
    (depESite Lq hLq Pf Df bga pre i m t0 hs hn (K := K)).fires U G c
      ↔ (((slotRho (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).getD m
              Fp2.zero).isZero
          || decide ((slotRho (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti
              df).getD m Fp2.zero = Fp2.one)) = true := by
  unfold depESite
  rw [tprogSite_fires, final_depEProg (liftH G) Pf Df bga (pre c) i m (t0 c) ti x recs acc hY df hdf]
  have hrho : (slotRho (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).getD m
      Fp2.zero = _ :=
    scUpTo_chal (liftH G) (slotN (Pf x i) i)
      ((Df x i).strat i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df (slotC (liftH G) (Pf x i) i ti)) m
      (slotT4 (liftH G) (Pf x i) i ti
        ((Df x i).scalar i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df (slotC (liftH G) (Pf x i) i ti))) hm
  rw [hrho, degenerate_guard_iff U hU _ (canon_challengeFp2Of _)]

omit [DecidableEq K] in
/-- **A zero draw of `define` is a site event**, for any number `n > j` of draws (the dependent form of
`drawZeroSite_fires`: the number of draws may be read off the prefix's data). -/
theorem drawZeroSite_fires_at {γ : Type} (n j : ℕ) (hj : j < n) (pre : Coins → TProg γ) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (hn : ∀ c, TProg.NoWrap (drawProg j (pre c)) (t0 c)) (G : QB Lq → Dig)
    (c : Coins) :
    (drawZeroSite Lq hLq j pre t0 hs hn (K := K)).fires U G c
      ↔ ((((pre c).final (liftH G) (t0 c)).1.challengeFp2Vec (liftH G) n).1.getD j Fp2.zero).isZero = true := by
  unfold drawZeroSite
  rw [tprogSite_fires, final_drawProg, challengeFp2Vec_getD (liftH G) n j _ hj, Finset.mem_singleton,
    isZero_iff_toK U hU _ (canon_challengeFp2Of _)]

/-- **The honest slot loop's refusals are covered by `δ = 0` sites.** For a part whose head is the program `hd c`
(ending where the slots start, with the data the slots read), if the honest loop of `n` slots refuses under the oracle
`G`, then there is a slot `i < n` the earlier honest slots REACHED: the prefix `famPre … i` ends on the loop's own
state there, and at that state
* `define` refused (a zero batching draw: `drawZeroSite_fires_at`; or a deterministic builder failure of the
  instance), or
* slot `i`'s CFS site fires (`c = 0`), or
* the site of one of its rounds fires (a degenerate extension challenge), or
* a deterministic schedule check failed (`slotDefChecks`, the hosted index, a table length; finding L25-4).
Every site named is `tprogSite`'s: freshness `δ = 0`, at most 2 bad values. -/
theorem fam_refuse_cover (hd : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (hd c))
    (hnC : ∀ i c, TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (n : ℕ) (x : α) (t3 : Tr) (hF : (hd c).final (liftH G) (t0 c) = (t3, x))
    (h : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 = .error ()) :
    ∃ (i : ℕ) (ti : Tr) (recs : List SlotRec) (acc : Acc), i < n
      ∧ (famPre Pf Df bga (hd c) i).final (liftH G) (t0 c) = (ti, (x, recs, acc))
      ∧ ((∃ e, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
            (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .error e)
        ∨ (depCSite Lq hLq Pf (fun c => famPre Pf Df bga (hd c) i) i t0
            (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i) (hnC i) (K := K)).fires U G c
        ∨ (∃ m, m < slotN (Pf x i) i ∧ (depESite Lq hLq Pf Df bga (fun c => famPre Pf Df bga (hd c) i) i m t0
            (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i) (hnE i m) (K := K)).fires U G c)
        ∨ ∃ df, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
              (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .ok df
            ∧ ((∃ e, slotDefChecks (Pf x i) i acc df = .error e)
              ∨ (∃ e, hostedSum acc.scalars
                  (slotSP (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).scalar
                  df.hosted = .error e)
              ∨ ∃ e, tabVals
                  (oneMinusProd ((slotRho (liftH G) (Pf x i) (Df x i) i
                    (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).drop (slotShape (Pf x i) i).1))
                  ((slotRho (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti
                    df).take (slotShape (Pf x i) i).1)
                  (slotSP (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).terms
                  df.tabs 0 = .error e)) := by
  obtain ⟨i, sps, recs, acc, ti, hi, hok, hr⟩ :=
    famProve_refuses_at (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 h
  rw [Nat.zero_add] at hr
  have hY : (famPre Pf Df bga (hd c) i).final (liftH G) (t0 c) = (ti, (x, recs, acc)) := by
    have h1 := final_famPre (liftH G) Pf Df bga (hd c) i (t0 c) sps recs acc ti (by rw [hF]; exact hok)
    rw [h1, hF]
  refine ⟨i, ti, recs, acc, hi, hY, ?_⟩
  rcases slotProve_refuses_sites U hU (liftH G) (Pf x i) (Df x i) i _ acc ti hr with
    hdef | ⟨df, hdf, hc | ⟨y, hy, hy'⟩ | hrest⟩
  · exact Or.inl hdef
  · refine Or.inr (Or.inl ?_)
    rw [depCSite_fires Lq hLq Pf U hU, hY]
    exact (slot_c_guard_iff U hU (liftH G) (Pf x i) i ti).mpr hc
  · refine Or.inr (Or.inr (Or.inl ?_))
    obtain ⟨m, -, hm, e⟩ := exists_getD_of_mem_drop Fp2.zero y _ _ hy
    rw [slotRho_length] at hm
    refine ⟨m, hm, ?_⟩
    rw [depESite_fires Lq hLq Pf Df bga U hU _ i m t0 _ _ G c ti x recs acc hY hm df hdf, e]
    exact (degenerate_guard_iff U hU y (scChal_canon (liftH G) _ _ y (List.mem_of_mem_drop hy))).mpr hy'
  · exact Or.inr (Or.inr (Or.inr ⟨df, hdf, hrest⟩))

end Sites

end ZK60.HonestOracle
