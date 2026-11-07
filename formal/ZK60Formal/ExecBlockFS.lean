/-
D63 step L9, part 3: the block's sumcheck Fiat–Shamir soundness on the REAL schedule of `verify_core`.

`blockSlots` (`ExecBlockVerify.lean`) is the part of `verify_core` up to the end of the slot loop: after any header of
transcript operations, the `A` / `M` / `H` absorbs and the LogUp challenges, then per slot `define`'s draws,
`pb-slot`, the CFS challenge `c`, `pb-scalar`, the sumcheck rounds (L6's `scVerify`) and `pb-term`. This file reads
that run as L8's schedule of `Slot`s and applies `exec_sumchecks_fs_sound`:

* `blockOps`: the verifier's operations as L8's run of slots, per slot its interstitial operations (the header and
  the roots before slot 0; the previous slot's `pb-term` before every other) and its rounds. Every operation is a
  function of the receipt and of the verifier's own counts; each slot's window starts at a FIXED position, `s_k` the
  same for every receipt (`blockSlot`);
* `slotsLoop_ok`, `blockSlots_ok`: an accepting `blockSlots` runs each slot's `scVerify` on EXACTLY the transcript
  `runOps` of the operations before its rounds (`slotPre_blockOps`), so it is one executable transcript;
* `tSeen`, `tSeen_trace`: **each slot's claim is a function of the code's trace before its rounds**. The reader
  `tSeen` reads, off the trace, the LogUp challenges, every slot's `define` draws and `c` (squeeze digests) and every
  slot's scalar (the `pb-scalar` absorb's bytes); `claimOf` then recomputes the claimed sum `scalar + Σ κ·scalar_h`
  with `define`'s hosted list (L7-2: met by the `pb-scalar` absorb and the transcript's `ν`, both in the trace);
* `block_sumchecks_fs_sound`: for ANY slot polynomials `f k` that are functions of what the trace shows (`Seen`), a
  prover making `q` queries gets `blockSlots` to accept with every slot's terminal check (`fin = f(ρ)`, which `M` and
  the openings discharge, L10) while SOME slot's claimed sum is false, with probability at most
  `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ = blockLen`;
* `block_sumchecks_fs_sound_goldilocks`, `block_sumchecks_fs_sound_shape`: at Goldilocks, and with every degree
  `≤ 7` and `T ≤ 2^64 + 2^20` (`block_bound_le`), at most `2^-61`. W16R2's degrees are `≤ 5` (`BASE_DEGREE` plus the
  support indicator; the corpus records the rung's).

W1 (every challenge a single squeeze; `challenge_fp2_vec(n)` is `n` squeezes, pinned by
`w16r2_the_lemmas_load_bearing_invariants_are_pinned`): no counter premise.
-/
import ZK60Formal.ExecBlockVerify

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

section Ops

variable (H : HIn → Dig)

/-! ## The block's operations -/

/-- `n` squeezes (`challenge_fp2_vec(n)`). -/
def drawOps (n : ℕ) : List Op := List.replicate n .squeeze

theorem runOps_drawOps : ∀ (n : ℕ) (t : Tr), runOps H t (drawOps n) = (t.challengeFp2Vec H n).2
  | 0, _ => rfl
  | n + 1, t => runOps_drawOps n (t.squeeze H).2

/-- The `A` root's three absorbs and `M`'s root. -/
def rootOpsA (P : BlockParams) (core : Core) : List Op :=
  [.absorb labA core.aRoot.toList, .absorb labRows (le64 (UInt64.ofNat P.aRows)),
    .absorb labLogCols (le64 (UInt64.ofNat P.logCols)), .absorb labM core.maskRoot.toList]

/-- The `H` root's three absorbs. -/
def rootOpsH (P : BlockParams) (core : Core) : List Op :=
  [.absorb labH core.hRoot.toList, .absorb labRows (le64 (UInt64.ofNat P.hRows)),
    .absorb labLogCols (le64 (UInt64.ofNat P.logCols))]

/-- **The operations before slot 0's `define`**: `A`, `M`, `β`, `γ`, `α`, `H`. -/
def rootOps (P : BlockParams) (core : Core) : List Op :=
  rootOpsA P core ++ ([.squeeze, .squeeze, .squeeze] ++ rootOpsH P core)

/-- Slot `j`'s operations before its rounds: `define`'s draws, `pb-slot`, `c`, `pb-scalar`. -/
def slotPreOps (P : BlockParams) (j : ℕ) (sp : SlotProof) : List Op :=
  drawOps (P.draws j) ++ [.absorb labPbSlot (le64 (UInt64.ofNat j)), .squeeze,
    .absorb labPbScalar ([sp.scalar].flatMap Fp2.toBytes)]

/-- `pb-term`. -/
def termOp (sp : SlotProof) : Op := .absorb labPbTerm (sp.terms.flatMap Fp2.toBytes)

/-- The run of slots as L8 reads it, from slot `j` on, `first` before slot `j`'s own operations. -/
def slotOpsFrom (P : BlockParams) : List Op → ℕ → List SlotProof → List (List Op × List (List Fp2))
  | _, _, [] => []
  | first, j, sp :: sps => (first ++ slotPreOps P j sp, sp.rounds) :: slotOpsFrom P [termOp sp] (j + 1) sps

/-- **The block's run of slots**: the header and the roots before slot 0, then each slot. -/
def blockOps (P : BlockParams) (hdr : List Op) (core : Core) : List (List Op × List (List Fp2)) :=
  slotOpsFrom P (hdr ++ rootOps P core) 0 core.slots

/-- Whole slots `j, j + 1, …`: each one's operations, its rounds and its `pb-term`. -/
def fullOps (P : BlockParams) : ℕ → List SlotProof → List Op
  | _, [] => []
  | j, sp :: sps => slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp] ++ fullOps P (j + 1) sps

theorem slotOpsFrom_length (P : BlockParams) :
    ∀ (first : List Op) (j : ℕ) (sps : List SlotProof), (slotOpsFrom P first j sps).length = sps.length
  | _, _, [] => rfl
  | _, j, _ :: sps => by simp [slotOpsFrom, slotOpsFrom_length P _ (j + 1) sps]

theorem slotOpsFrom_get (P : BlockParams) :
    ∀ (first : List Op) (j : ℕ) (sps : List SlotProof) (k : ℕ) (sp : SlotProof), sps[k]? = some sp →
      (slotOpsFrom P first j sps)[k]? = some ((if k = 0 then first else [termOp (sps.getD (k - 1) sp)])
        ++ slotPreOps P (j + k) sp, sp.rounds)
  | _, _, [], _, _, h => by simp at h
  | first, j, s :: sps, 0, sp, h => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h
    subst h
    simp [slotOpsFrom]
  | first, j, s :: sps, k + 1, sp, h => by
    simp only [List.getElem?_cons_succ] at h
    rw [slotOpsFrom, List.getElem?_cons_succ, slotOpsFrom_get P [termOp s] (j + 1) sps k sp h,
      show j + 1 + k = j + (k + 1) by omega]
    cases k with
    | zero => simp
    | succ k => simp

/-- **The operations before slot `k`'s rounds** are the header, the roots, the whole slots before `k`, and slot `k`'s
own draws, `pb-slot`, `c`, `pb-scalar`. -/
theorem slotPre_from (P : BlockParams) :
    ∀ (first : List Op) (j : ℕ) (sps : List SlotProof) (k : ℕ) (sp : SlotProof)
      (ok : List Op × List (List Fp2)), sps[k]? = some sp → (slotOpsFrom P first j sps)[k]? = some ok →
      slotPre (slotOpsFrom P first j sps) k ok = first ++ fullOps P j (sps.take k) ++ slotPreOps P (j + k) sp
  | _, _, [], _, _, _, h, _ => by simp at h
  | first, j, s :: sps, 0, sp, ok, h, hok => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h
    subst h
    simp only [slotOpsFrom, List.getElem?_cons_zero, Option.some.injEq] at hok
    subst hok
    simp [slotPre, slotsOps, fullOps]
  | first, j, s :: sps, k + 1, sp, ok, h, hok => by
    simp only [List.getElem?_cons_succ] at h
    simp only [slotOpsFrom, List.getElem?_cons_succ] at hok
    have ih := slotPre_from P [termOp s] (j + 1) sps k sp ok h hok
    simp only [slotPre, slotOpsFrom, List.take_succ_cons, slotsOps, fullOps, List.append_assoc,
      List.cons_append] at ih ⊢
    rw [ih, show j + 1 + k = j + (k + 1) by omega]

theorem slotPre_blockOps (P : BlockParams) (hdr : List Op) (core : Core) (k : ℕ) (sp : SlotProof)
    (ok : List Op × List (List Fp2)) (h : core.slots[k]? = some sp) (hok : (blockOps P hdr core)[k]? = some ok) :
    slotPre (blockOps P hdr core) k ok
      = hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp := by
  rw [blockOps, slotPre_from P _ 0 core.slots k sp ok h hok, Nat.zero_add]

/-! ## The slot loop runs on `runOps` of these operations -/

theorem ex_bind_ok {ε α β : Type} {e : Except ε α} {f : α → Except ε β} {b : β} (h : (e >>= f) = .ok b) :
    ∃ a, e = .ok a ∧ f a = .ok b := by
  cases e with
  | error err => cases h
  | ok a => exact ⟨a, rfl, h⟩

theorem scCheck_ok {s : ℕ} {nm : String} {x : Except ScErr (Fp2 × List Fp2)} {r : Fp2 × List Fp2}
    (h : scCheck s nm x = .ok r) : x = .ok r := by
  cases x with
  | ok a =>
    cases h
    rfl
  | error e => cases h

theorem ex_ite_ok {ε : Type} {c : Prop} [Decidable c] {m : ε} {u : Unit}
    (h : (if c then (throw m : Except ε Unit) else pure ()) = .ok u) : ¬ c := by
  split at h
  · cases h
  · assumption

/-- The operations of a slot's prefix run as `slotStep` runs them. -/
theorem runOps_slotPreOps (P : BlockParams) (j : ℕ) (sp : SlotProof) (t : Tr) :
    runOps H t (slotPreOps P j sp)
      = ((((t.challengeFp2Vec H (P.draws j)).2.absorbU64 H labPbSlot (UInt64.ofNat j)).challengeFp2 H).2).absorbFp2 H
          labPbScalar [sp.scalar] := by
  rw [slotPreOps, runOps_append, runOps_drawOps]
  rfl

theorem slotStep_ok (P : BlockParams) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (t : Tr) (r : SlotRec)
    (acc' : Acc) (t' : Tr) (h : slotStep H P s hist sp acc t = .ok (r, acc', t')) :
    ∃ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df
      ∧ hostedSum acc.scalars sp.scalar df.hosted = .ok r.claimed
      ∧ (scVerify H r.claimed (slotShape P s).2.2 ((slotShape P s).1 + (slotShape P s).2.1) sp.rounds
          (runOps H t (slotPreOps P s sp))).1 = .ok (r.fin, r.rho ++ r.es)
      ∧ t' = (scVerify H r.claimed (slotShape P s).2.2 ((slotShape P s).1 + (slotShape P s).2.1) sp.rounds
          (runOps H t (slotPreOps P s sp))).2.absorb H labPbTerm (sp.terms.flatMap Fp2.toBytes)
      ∧ r.draws = (t.challengeFp2Vec H (P.draws s)).1
      ∧ r.c = ((((t.challengeFp2Vec H (P.draws s)).2).absorbU64 H labPbSlot (UInt64.ofNat s)).challengeFp2 H).1
      ∧ r.scalar = sp.scalar
      ∧ acc'.scalars = acc.scalars ++ [sp.scalar] := by
  unfold slotStep at h
  obtain ⟨df, hdf, h⟩ := ex_bind_ok h
  obtain ⟨u1, -, h⟩ := ex_bind_ok h
  obtain ⟨u2, -, h⟩ := ex_bind_ok h
  obtain ⟨u3, -, h⟩ := ex_bind_ok h
  obtain ⟨claimed, hcl, h⟩ := ex_bind_ok h
  obtain ⟨fr, hfr, h⟩ := ex_bind_ok h
  have hsv := scCheck_ok hfr
  obtain ⟨fin, rhoFull⟩ := fr
  obtain ⟨vals, -, h⟩ := ex_bind_ok h
  obtain ⟨u4, -, h⟩ := ex_bind_ok h
  simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  refine ⟨df, hdf, hcl, ?_, ?_, rfl, rfl, rfl, rfl⟩
  · rw [runOps_slotPreOps]
    simp only [List.take_append_drop]
    exact hsv
  · rw [runOps_slotPreOps]
    rfl

theorem runOps_fullOps_cons (P : BlockParams) (j : ℕ) (sp : SlotProof) (sps : List SlotProof) (t : Tr) :
    runOps H t (fullOps P j (sp :: sps))
      = runOps H (runOps H (runOps H t (slotPreOps P j sp ++ scOps sp.rounds)) [termOp sp]) (fullOps P (j + 1) sps) := by
  rw [fullOps, runOps_append, runOps_append]

/-- `blockSlots` as `runOps` of the roots' operations. -/
theorem blockSlots_eq (P : BlockParams) (core : Core) (t : Tr) : blockSlots H P core t =
    match slotsLoop H P ((runOps H t (rootOpsA P core)).challengeFp2 H).1
      (((runOps H t (rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).1
      ((((runOps H t (rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1 [] 0 core.slots {}
      (runOps H t (rootOps P core)) with
    | .ok r => .ok ((((runOps H t (rootOpsA P core)).challengeFp2 H).1,
        (((runOps H t (rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).1,
        ((((runOps H t (rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1), r)
    | .error e => .error e := rfl

/-- The values `define`, `c` and `pb-scalar` see, on the transcript `t` (squeeze digests and absorbed bytes). -/
def preVals (P : BlockParams) (t : Tr) (j : ℕ) (sp : SlotProof) : List Fp2 × Fp2 × List UInt8 :=
  ((t.challengeFp2Vec H (P.draws j)).1,
    ((((t.challengeFp2Vec H (P.draws j)).2).absorbU64 H labPbSlot (UInt64.ofNat j)).challengeFp2 H).1,
    [sp.scalar].flatMap Fp2.toBytes)

/-- The transcript entering slot `j + i`: `runOps` of the whole slots `j … j + i − 1`. -/
def slotTr (P : BlockParams) (t : Tr) (j : ℕ) (sps : List SlotProof) (i : ℕ) : Tr :=
  runOps H t (fullOps P j (sps.take i))

/-- After an accepting slot, its rounds and `pb-term` are `runOps` of their operations (L6's `scVerify_tr`). -/
theorem slot_after (P : BlockParams) (j : ℕ) (sp : SlotProof) (t : Tr) (claimed fin : Fp2) (rs : List Fp2)
    (hd : 1 ≤ (slotShape P j).2.2)
    (hsv : (scVerify H claimed (slotShape P j).2.2 ((slotShape P j).1 + (slotShape P j).2.1) sp.rounds
      (runOps H t (slotPreOps P j sp))).1 = .ok (fin, rs)) :
    (scVerify H claimed (slotShape P j).2.2 ((slotShape P j).1 + (slotShape P j).2.1) sp.rounds
      (runOps H t (slotPreOps P j sp))).2.absorb H labPbTerm (sp.terms.flatMap Fp2.toBytes)
      = runOps H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp]) := by
  rw [scVerify_tr H _ _ hd _ _ _ fin rs hsv, runOps_append, runOps_append]
  rfl

/-- **The slot loop, slot by slot**: an accepting loop from slot `j` on transcript `t` verifies slot `j + i` on the
transcript `runOps` of the whole slots before it (`slotTr`); its record's draws, `c` and scalar are `preVals` there;
`define` saw the earlier records' draws; the claimed sum is the hosted sum of the earlier scalars. -/
theorem slotsLoop_ok (P : BlockParams) (b g a : Fp2) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr), (∀ i, i < sps.length → 1 ≤ (slotShape P (j + i)).2.2) →
      slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') →
      ∃ rs, recs' = recs ++ rs ∧ rs.length = sps.length
        ∧ ∀ (i : ℕ) (sp : SlotProof) (r : SlotRec), sps[i]? = some sp → rs[i]? = some r →
          (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes) = preVals H P (slotTr H P t j sps i) (j + i) sp
          ∧ r.scalar = sp.scalar
          ∧ (∃ df, P.define (j + i) (histOf b g a (recs ++ rs.take i)) r.draws = .ok df
              ∧ hostedSum (acc.scalars ++ (rs.take i).map SlotRec.scalar) sp.scalar df.hosted = .ok r.claimed)
          ∧ (scVerify H r.claimed (slotShape P (j + i)).2.2 ((slotShape P (j + i)).1 + (slotShape P (j + i)).2.1)
              sp.rounds (runOps H (slotTr H P t j sps i) (slotPreOps P (j + i) sp))).1 = .ok (r.fin, r.rho ++ r.es)
  | [], recs, j, acc, t, recs', acc', t', _, h => by
    simp only [slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -, -⟩ := h
    exact ⟨[], by simp, rfl, fun i sp r h1 _ => by simp at h1⟩
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', hd1, h => by
    simp only [slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, hdf, hcl, hsv, ht0, hdr, hc, hsc, hacc⟩ := slotStep_ok H P j _ sp0 acc t r0 acc0 t0 hstep
      have hd0 : 1 ≤ (slotShape P j).2.2 := by simpa using hd1 0 (by simp)
      have ht0' : t0 = runOps H t (slotPreOps P j sp0 ++ scOps sp0.rounds ++ [termOp sp0]) := by
        rw [ht0, slot_after H P j sp0 t r0.claimed r0.fin (r0.rho ++ r0.es) hd0 hsv]
      obtain ⟨rs, hrs, hlen, hall⟩ := slotsLoop_ok P b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t'
        (fun i hi => by
          have := hd1 (i + 1) (by simp; omega)
          rwa [show j + (i + 1) = j + 1 + i by omega] at this) h
      refine ⟨r0 :: rs, by rw [hrs, List.append_assoc, List.singleton_append], by simp [hlen], ?_⟩
      intro i sp r h1 h2
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
        subst h1 h2
        refine ⟨?_, hsc, ⟨df, ?_, ?_⟩, ?_⟩
        · simp only [slotTr, List.take_zero, fullOps, runOps, Nat.add_zero, preVals, Prod.mk.injEq]
          exact ⟨hdr, hc, by rw [hsc]⟩
        · simpa [histOf, hdr] using hdf
        · simpa using hcl
        · simpa [slotTr, fullOps, runOps] using hsv
      | succ i =>
        simp only [List.getElem?_cons_succ] at h1 h2
        obtain ⟨hv, hs, ⟨df', hdf', hcl'⟩, hsv'⟩ := hall i sp r h1 h2
        have hT : slotTr H P t j (sp0 :: sps) (i + 1) = slotTr H P t0 (j + 1) sps i := by
          rw [slotTr, slotTr, List.take_succ_cons, runOps_fullOps_cons,
            ← runOps_append H t (slotPreOps P j sp0 ++ scOps sp0.rounds) [termOp sp0], ← ht0']
        have hji : j + (i + 1) = j + 1 + i := by omega
        rw [hT, hji]
        refine ⟨hv, hs, ⟨df', ?_, ?_⟩, hsv'⟩
        · simpa [histOf, List.append_assoc] using hdf'
        · rw [hacc] at hcl'
          simpa [List.append_assoc, hsc] using hcl'

/-! ## Reading the trace -/

/-- A reader of the code's trace. -/
abbrev TRd (α : Type) : Type := List (TItem × Dig) → Option (α × List (TItem × Dig))

def TRd.ret {α : Type} (a : α) : TRd α := fun l => some (a, l)

def TRd.bnd {α β : Type} (r : TRd α) (f : α → TRd β) : TRd β := fun l =>
  match r l with
  | some (a, rest) => f a rest
  | none => none

theorem TRd.ret_apply {α : Type} (a : α) (l : List (TItem × Dig)) : TRd.ret a l = some (a, l) := rfl

/-- Skip `m` entries. -/
def tSkipN (m : ℕ) : TRd Unit := fun l => if m ≤ l.length then some ((), l.drop m) else none

/-- A squeeze entry's challenge (`challenge_fp2` of its digest). -/
def tChal : TRd Fp2 := fun l =>
  match l with
  | (.squeeze _, d) :: rest => some (challengeFp2Of d, rest)
  | _ => none

/-- An absorb entry's bytes. -/
def tAbs : TRd (List UInt8) := fun l =>
  match l with
  | (.absorb _ x, _) :: rest => some (x, rest)
  | _ => none

def tChals : ℕ → TRd (List Fp2)
  | 0 => TRd.ret []
  | n + 1 => TRd.bnd tChal fun a => TRd.bnd (tChals n) fun as => TRd.ret (a :: as)

/-- Slot `j`'s prefix: `define`'s draws, `pb-slot`, `c`, the scalar's bytes. -/
def tSlotPre (P : BlockParams) (j : ℕ) : TRd (List Fp2 × Fp2 × List UInt8) :=
  TRd.bnd (tChals (P.draws j)) fun ds => TRd.bnd (tSkipN 1) fun _ => TRd.bnd tChal fun c => TRd.bnd tAbs fun x =>
  TRd.ret (ds, c, x)

/-- `m` whole slots from slot `j`: each prefix, then its rounds and `pb-term` skipped. -/
def tSlots (P : BlockParams) : ℕ → ℕ → TRd (List (List Fp2 × Fp2 × List UInt8))
  | _, 0 => TRd.ret []
  | j, m + 1 => TRd.bnd (tSlotPre P j) fun v => TRd.bnd (tSkipN (2 * ((slotShape P j).1 + (slotShape P j).2.1) + 1))
      fun _ => TRd.bnd (tSlots P (j + 1) m) fun vs => TRd.ret (v :: vs)

/-- What the trace before slot `k`'s rounds shows: the LogUp challenges, and per slot `0 … k` its draws, `c` and the
scalar's bytes. -/
abbrev Seen := (Fp2 × Fp2 × Fp2) × List (List Fp2 × Fp2 × List UInt8)

/-- The header (`hdrLen` entries) and the `A` / `M` absorbs skipped, `β`, `γ`, `α`, the `H` absorbs skipped. -/
def tRoot (hdrLen : ℕ) : TRd (Fp2 × Fp2 × Fp2) :=
  TRd.bnd (tSkipN (hdrLen + 4)) fun _ => TRd.bnd tChal fun b => TRd.bnd tChal fun g => TRd.bnd tChal fun a =>
  TRd.bnd (tSkipN 3) fun _ => TRd.ret (b, g, a)

/-- **The reader of the trace before slot `k`'s rounds**: the roots' part, the whole slots before `k`, slot `k`'s
prefix. -/
def tSeen (P : BlockParams) (hdrLen k : ℕ) : TRd Seen :=
  TRd.bnd (tRoot hdrLen) fun bga => TRd.bnd (tSlots P 0 k) fun vs => TRd.bnd (tSlotPre P k) fun v => TRd.ret (bga, vs ++ [v])

/-- **Slot `k`'s claimed sum from what the trace shows** (`run_slot`: the scalar plus the hosted scalars times
`define`'s coefficients). -/
def claimOf (P : BlockParams) (k : ℕ) (sn : Seen) : Fp2 :=
  let earlier := sn.2.take k
  let cur := sn.2.getD k ([], Fp2.zero, [])
  match P.define k ⟨sn.1.1, sn.1.2.1, sn.1.2.2, earlier.map (·.1)⟩ cur.1 with
  | .ok df =>
    match hostedSum (earlier.map (fun v => Fp2.fromBytes v.2.2)) (Fp2.fromBytes cur.2.2) df.hosted with
    | .ok c => c
    | .error _ => Fp2.zero
  | .error _ => Fp2.zero

/-! ## The trace lemmas -/

theorem TRd.bnd_def {α β : Type} (r : TRd α) (f : α → TRd β) (l : List (TItem × Dig)) :
    TRd.bnd r f l = (match r l with
      | some (a, rest) => f a rest
      | none => none) := rfl

theorem tChal_cons (c : UInt64) (d : Dig) (rest : List (TItem × Dig)) :
    tChal ((TItem.squeeze c, d) :: rest) = some (challengeFp2Of d, rest) := rfl

theorem tAbs_cons (lab x : List UInt8) (d : Dig) (rest : List (TItem × Dig)) :
    tAbs ((TItem.absorb lab x, d) :: rest) = some (x, rest) := rfl

theorem tSkipN_one (e : TItem × Dig) (rest : List (TItem × Dig)) : tSkipN 1 (e :: rest) = some ((), rest) := by
  simp [tSkipN]

theorem tSkipN_three (e₁ e₂ e₃ : TItem × Dig) (rest : List (TItem × Dig)) :
    tSkipN 3 (e₁ :: e₂ :: e₃ :: rest) = some ((), rest) := by
  simp [tSkipN]

theorem opTrace_append : ∀ (t : Tr) (a b : List Op), opTrace H t (a ++ b) = opTrace H t a ++ opTrace H (runOps H t a) b
  | _, [], _ => rfl
  | t, .absorb l x :: a, b => by
    simp only [List.cons_append, opTrace, runOps]
    rw [opTrace_append (t.absorb H l x) a b]
  | t, .squeeze :: a, b => by
    simp only [List.cons_append, opTrace, runOps]
    rw [opTrace_append (t.squeeze H).2 a b]

theorem opTrace_length : ∀ (t : Tr) (a : List Op), (opTrace H t a).length = a.length
  | _, [] => rfl
  | t, .absorb l x :: a => by simp only [opTrace, List.length_cons, opTrace_length (t.absorb H l x) a]
  | t, .squeeze :: a => by simp only [opTrace, List.length_cons, opTrace_length (t.squeeze H).2 a]

theorem tSkipN_app (m : ℕ) (l₁ l₂ : List (TItem × Dig)) (h : l₁.length = m) : tSkipN m (l₁ ++ l₂) = some ((), l₂) := by
  subst h
  simp [tSkipN]

theorem tChals_trace : ∀ (n : ℕ) (t : Tr) (rest : List (TItem × Dig)),
    tChals n (opTrace H t (drawOps n) ++ rest) = some ((t.challengeFp2Vec H n).1, rest)
  | 0, _, _ => rfl
  | n + 1, t, rest => by
    have ih := tChals_trace n (t.squeeze H).2 rest
    show TRd.bnd tChal (fun a => TRd.bnd (tChals n) fun as => TRd.ret (a :: as))
      ((TItem.squeeze t.counter, (t.squeeze H).1) :: (opTrace H (t.squeeze H).2 (drawOps n) ++ rest)) = _
    rw [TRd.bnd_def, tChal_cons]
    dsimp only
    rw [TRd.bnd_def, ih]
    rfl

theorem tSlotPre_trace (P : BlockParams) (j : ℕ) (sp : SlotProof) (t : Tr) (rest : List (TItem × Dig)) :
    tSlotPre P j (opTrace H t (slotPreOps P j sp) ++ rest) = some (preVals H P t j sp, rest) := by
  unfold tSlotPre
  rw [slotPreOps, opTrace_append, List.append_assoc, TRd.bnd_def, tChals_trace, runOps_drawOps]
  simp only [opTrace, List.cons_append, List.nil_append, TRd.bnd_def, tSkipN_one, tChal_cons, tAbs_cons,
    TRd.ret_apply]
  rfl

/-- The prefixes' values along the transcript, whole slot by whole slot. -/
def walk (P : BlockParams) : Tr → ℕ → List SlotProof → List (List Fp2 × Fp2 × List UInt8)
  | _, _, [] => []
  | t, j, sp :: sps =>
    preVals H P t j sp :: walk P (runOps H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp])) (j + 1) sps

theorem tSlots_trace (P : BlockParams) : ∀ (sps : List SlotProof) (j : ℕ) (t : Tr) (rest : List (TItem × Dig)),
    (∀ i sp, sps[i]? = some sp → sp.rounds.length = (slotShape P (j + i)).1 + (slotShape P (j + i)).2.1) →
    tSlots P j sps.length (opTrace H t (fullOps P j sps) ++ rest) = some (walk H P t j sps, rest)
  | [], _, _, _, _ => rfl
  | sp :: sps, j, t, rest, hr => by
    have h0 := hr 0 sp rfl
    simp only [Nat.add_zero] at h0
    have ih := tSlots_trace P sps (j + 1)
      (runOps H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp])) rest
      (fun i q hq => by
        rw [hr (i + 1) q (by simpa using hq), show j + (i + 1) = j + 1 + i by omega])
    have hl : (opTrace H (runOps H t (slotPreOps P j sp)) (scOps sp.rounds ++ [termOp sp])).length
        = 2 * ((slotShape P j).1 + (slotShape P j).2.1) + 1 := by
      rw [opTrace_length, List.length_append, scOps_length, h0]
      rfl
    have hsplit : opTrace H t (fullOps P j (sp :: sps)) ++ rest
        = opTrace H t (slotPreOps P j sp) ++ (opTrace H (runOps H t (slotPreOps P j sp)) (scOps sp.rounds ++ [termOp sp])
          ++ (opTrace H (runOps H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp])) (fullOps P (j + 1) sps)
            ++ rest)) := by
      simp only [fullOps, opTrace_append, runOps_append, List.append_assoc]
    rw [List.length_cons, hsplit]
    show TRd.bnd (tSlotPre P j) (fun v => TRd.bnd (tSkipN (2 * ((slotShape P j).1 + (slotShape P j).2.1) + 1)) fun _ =>
        TRd.bnd (tSlots P (j + 1) sps.length) fun vs => TRd.ret (v :: vs)) _ = _
    rw [TRd.bnd_def, tSlotPre_trace]
    dsimp only
    rw [TRd.bnd_def, tSkipN_app _ _ _ hl]
    dsimp only
    rw [TRd.bnd_def, ih]
    rfl

/-- The roots' part of the trace reads as `blockSlots` draws `β`, `γ`, `α`. -/
theorem tRoot_trace (P : BlockParams) (core : Core) (hdr : List Op) (t : Tr) (rest : List (TItem × Dig)) :
    tRoot hdr.length (opTrace H t (hdr ++ rootOps P core) ++ rest)
      = some ((((runOps H t (hdr ++ rootOpsA P core)).challengeFp2 H).1,
          (((runOps H t (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).1,
          ((((runOps H t (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1), rest) := by
  have h4 : (opTrace H t (hdr ++ rootOpsA P core)).length = hdr.length + 4 := by
    rw [opTrace_length, List.length_append]
    rfl
  have hsplit : opTrace H t (hdr ++ rootOps P core) ++ rest = opTrace H t (hdr ++ rootOpsA P core)
      ++ (opTrace H (runOps H t (hdr ++ rootOpsA P core)) ([.squeeze, .squeeze, .squeeze] ++ rootOpsH P core) ++ rest) := by
    simp only [rootOps, opTrace_append, runOps_append, List.append_assoc]
  unfold tRoot
  rw [hsplit, TRd.bnd_def, tSkipN_app _ _ _ h4]
  simp only [opTrace, List.cons_append, List.nil_append, rootOpsH, TRd.bnd_def, tChal_cons, tSkipN_three,
    TRd.ret_apply]
  rfl

theorem walk_getElem? (P : BlockParams) : ∀ (sps : List SlotProof) (t : Tr) (j i : ℕ),
    (walk H P t j sps)[i]? = sps[i]?.map (fun sp => preVals H P (slotTr H P t j sps i) (j + i) sp)
  | [], _, _, _ => by simp [walk]
  | sp :: sps, t, j, 0 => by simp [walk, slotTr, fullOps, runOps]
  | sp :: sps, t, j, i + 1 => by
    simp only [walk, List.getElem?_cons_succ]
    rw [walk_getElem? P sps _ (j + 1) i]
    congr 1
    funext q
    rw [show j + (i + 1) = j + 1 + i by omega, slotTr, slotTr, List.take_succ_cons, runOps_fullOps_cons,
      ← runOps_append H t (slotPreOps P j sp ++ scOps sp.rounds) [termOp sp]]

theorem walk_length (P : BlockParams) : ∀ (t : Tr) (j : ℕ) (sps : List SlotProof), (walk H P t j sps).length = sps.length
  | _, _, [] => rfl
  | t, j, _ :: sps => by simp [walk, walk_length P _ (j + 1) sps]

theorem tSlotPre_trace' (P : BlockParams) (j : ℕ) (sp : SlotProof) (t : Tr) :
    tSlotPre P j (opTrace H t (slotPreOps P j sp)) = some (preVals H P t j sp, []) := by
  have h := tSlotPre_trace H P j sp t []
  rwa [List.append_nil] at h

theorem slotTr_take (P : BlockParams) (t : Tr) (j : ℕ) (sps : List SlotProof) (i k : ℕ) (hik : i ≤ k) :
    slotTr H P t j (sps.take k) i = slotTr H P t j sps i := by
  rw [slotTr, slotTr, List.take_take, min_eq_left hik]

end Ops

/-! ## The block's schedule as L8's slots, and the theorem -/

section Theorem

variable {K : Type} [Field K] [Algebra GF K]

/-- **Slot `k` of the block's schedule**: its window opens after a FIXED number of operations (the header's
`hdrLen`, the roots' 10 and its own `draws k + 3` before slot 0; the previous `pb-term` and its own `draws k + 3`
after), its degree and rounds are the shape's, and its statement is read off the trace (`tSeen`): the polynomial `f k`
of what the trace shows, the claimed sum `claimOf`. -/
def blockSlot (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (k : ℕ) : Slot K where
  s := (if k = 0 then hdrLen + 10 else 1) + (P.draws k + 3)
  d := (slotShape P k).2.2
  n := (slotShape P k).1 + (slotShape P k).2.1
  stmt τ :=
    match tSeen P hdrLen k τ with
    | some (sn, _) => (f k sn, claimOf P k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- **The block's schedule**: one slot per slot of the shape. -/
def blockSched (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) : List (Slot K) :=
  (List.range P.geom.slots.length).map (blockSlot P hdrLen f)

/-- **The block's item count `ℓ`** (every slot's interstitial operations and two per round), a function of the
verifier's counts alone. -/
def blockLen (draws : ℕ → ℕ) (slots : List (ℕ × ℕ × ℕ)) (hdrLen : ℕ) : ℕ :=
  ((List.range slots.length).map (fun k => (if k = 0 then hdrLen + 10 else 1) + (draws k + 3)
    + 2 * ((slots.getD k (0, 0, 0)).1 + (slots.getD k (0, 0, 0)).2.1))).sum

omit [Algebra GF K] in
theorem slotsLen_blockSched (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    slotsLen (blockSched P hdrLen f) = blockLen P.draws P.geom.slots hdrLen := by
  simp only [slotsLen, blockSched, blockLen, List.map_map]
  rfl

/-- What a verified slot's record shows, as `tSeen` reads it. -/
def seenOf (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) : Seen :=
  (bga, (rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)))

/-- **The prover wins against the block's slot phase**: it outputs a header of `hdrLen` operations (each hash input
of at most `L` bytes) and a canonical core of the verifier's shape (what the decoder guarantees, `decodeFork_spec`);
`blockSlots` accepts on the code's transcript after the header, every slot's terminal check `fin = f(ρ)` holds (`M`
and the openings discharge it, L10), and SOME slot's claimed sum is false for its polynomial of individual degree
`≤ d`. -/
def BlockWin (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (G : QB L → Dig)
    (out : List Op × Core) : Prop :=
  out.1.length = hdrLen ∧ (∀ op ∈ out.1, op.len ≤ L) ∧ CoreCanon out.2 ∧ CoreShape P.geom out.2
  ∧ ∃ bga rs acc t', blockSlots (liftH G) P out.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) out.1)
        = .ok (bga, rs, acc, t')
    ∧ (∀ k r, rs[k]? = some r →
        r.fin.toK U = f k (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U))
    ∧ ∃ k r, rs[k]? = some r ∧ IndDegLE (slotShape P k).2.2 (f k (seenOf bga rs k))
        ∧ r.claimed.toK U ≠ cubeSum (f k (seenOf bga rs k))

theorem hostedSum_canon : ∀ (scalars : List Fp2) (scalar : Fp2) (hosted : List (ℕ × Fp2)) (c : Fp2),
    scalar.Canon → hostedSum scalars scalar hosted = .ok c → c.Canon
  | _, _, [], c, hs, h => by
    simp only [hostedSum, Except.ok.injEq] at h
    exact h ▸ hs
  | scalars, scalar, (hs, coef) :: rest, c, hsc, h => by
    simp only [hostedSum] at h
    split at h
    · exact hostedSum_canon scalars _ rest c (Fp2.canon_add _ _) h
    · cases h

theorem flatMap_singleton_toBytes (x : Fp2) : [x].flatMap Fp2.toBytes = x.toBytes := by simp

/-- **The claim is the trace's**: on the verifier's own trace before slot `k`'s rounds, `tSeen` reads what the
records show, and `claimOf` of it is the claimed sum `blockSlots` handed to `scVerify`. -/
theorem claimOf_seenOf (P : BlockParams) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (k : ℕ) (r : SlotRec)
    (hr : rs[k]? = some r) (hcan : ∀ r' ∈ rs, r'.scalar.Canon) (df : SlotDef)
    (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df)
    (hcl : hostedSum ((rs.take k).map SlotRec.scalar) r.scalar df.hosted = .ok r.claimed) :
    claimOf P k (seenOf bga rs k) = r.claimed := by
  have hk : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  have hrk : rs[k] = r := (List.getElem?_eq_some_iff.mp hr).2
  have htake : ((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).take k
      = (rs.take k).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)) := by
    rw [← List.map_take, List.take_take, min_eq_left (Nat.le_succ k)]
  have hget : ((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
      ([], Fp2.zero, []) = (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt (Nat.lt_succ_self k), hr]
    rfl
  have hsc : ((rs.take k).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).map
      (fun v => Fp2.fromBytes v.2.2) = (rs.take k).map SlotRec.scalar := by
    rw [List.map_map]
    refine List.map_congr_left (fun r' hr' => ?_)
    simp only [Function.comp_apply, flatMap_singleton_toBytes]
    exact Fp2.fromBytes_toBytes _ (hcan r' (List.mem_of_mem_take hr'))
  have hcur : Fp2.fromBytes ([r.scalar].flatMap Fp2.toBytes) = r.scalar := by
    rw [flatMap_singleton_toBytes]
    exact Fp2.fromBytes_toBytes _ (hcan r (List.mem_of_getElem? hr))
  have hh : (⟨bga.1, bga.2.1, bga.2.2, ((rs.take k).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).map
      (·.1)⟩ : Hist) = histOf bga.1 bga.2.1 bga.2.2 (rs.take k) := by
    simp [histOf, List.map_map, Function.comp_def]
  unfold claimOf seenOf
  simp only
  rw [htake, hget, hh, hdf]
  simp only
  rw [hsc, hcur, hcl]

/-- **The trace before slot `k`'s rounds reads as the records show** (`tSeen` of the verifier's own trace). -/
theorem tSeen_trace (H : HIn → Dig) (P : BlockParams) (core : Core) (hdr : List Op) (t0 : Tr) (k : ℕ) (sp : SlotProof)
    (hsp : core.slots[k]? = some sp)
    (hr : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (hbga : bga = (((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).1,
      (((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).1,
      ((((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2 H).2.challengeFp2 H).2.challengeFp2 H).1))
    (hrs : rs.length = core.slots.length)
    (hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
      (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)
        = preVals H P (slotTr H P (runOps H t0 (hdr ++ rootOps P core)) 0 core.slots i) i q) :
    tSeen P hdr.length k (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp))
      = some (seenOf bga rs k, []) := by
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hsp).1
  obtain ⟨t3, ht3⟩ : ∃ t3, t3 = runOps H t0 (hdr ++ rootOps P core) := ⟨_, rfl⟩
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hsplit : opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp)
      = opTrace H t0 (hdr ++ rootOps P core) ++ (opTrace H t3 (fullOps P 0 (core.slots.take k))
          ++ opTrace H (runOps H t3 (fullOps P 0 (core.slots.take k))) (slotPreOps P k sp)) := by
    rw [ht3]
    simp only [opTrace_append, runOps_append, List.append_assoc]
  have hslots := tSlots_trace H P (core.slots.take k) 0 t3
    (opTrace H (runOps H t3 (fullOps P 0 (core.slots.take k))) (slotPreOps P k sp))
    (fun i q hq => by
      rw [Nat.zero_add]
      rw [List.getElem?_take] at hq
      split_ifs at hq
      exact hr i q hq)
  rw [hlenk] at hslots
  have hpre := tSlotPre_trace' H P k sp (runOps H t3 (fullOps P 0 (core.slots.take k)))
  have hW : walk H P t3 0 (core.slots.take k) ++ [preVals H P (runOps H t3 (fullOps P 0 (core.slots.take k))) k sp]
      = (rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)) := by
    apply List.ext_getElem?
    intro i
    have hwl : (walk H P t3 0 (core.slots.take k)).length = k := by rw [walk_length, hlenk]
    rcases Nat.lt_trichotomy i k with hik | hik | hik
    · obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨r, hr'⟩ : ∃ r, rs[i]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have hq' : (core.slots.take k)[i]? = some q := by rw [List.getElem?_take_of_lt hik, hq]
      have hr'' : (rs.take (k + 1))[i]? = some r := by rw [List.getElem?_take_of_lt (by omega), hr']
      rw [List.getElem?_append_left (by omega), walk_getElem?, hq', List.getElem?_map, hr'']
      simp only [Option.map_some, Option.some.injEq]
      rw [slotTr_take H P t3 0 core.slots i k hik.le, Nat.zero_add, hv i q r hq hr', ← ht3]
    · subst hik
      obtain ⟨r, hr'⟩ : ∃ r, rs[i]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have hr'' : (rs.take (i + 1))[i]? = some r := by rw [List.getElem?_take_of_lt (by omega), hr']
      rw [List.getElem?_append_right (by omega), hwl, Nat.sub_self, List.getElem?_cons_zero, List.getElem?_map, hr'']
      simp only [Option.map_some, Option.some.injEq]
      rw [hv i sp r hsp hr', ← ht3]
      rfl
    · rw [List.getElem?_eq_none_iff.mpr (by simp [hwl]; omega), List.getElem?_eq_none_iff.mpr (by simp; omega)]
  unfold tSeen
  rw [hsplit, TRd.bnd_def, tRoot_trace H P core hdr t0 _]
  dsimp only
  rw [TRd.bnd_def, hslots]
  dsimp only
  rw [TRd.bnd_def, hpre]
  dsimp only
  rw [TRd.ret_apply, ← hbga, hW]
  rfl


/-- The lengths of the roots' operations: each at most `81` bytes. -/
theorem rootOps_len (P : BlockParams) (core : Core) (L : ℕ) (hL : 81 ≤ L) : ∀ op ∈ rootOps P core, op.len ≤ L := by
  intro op hop
  simp only [rootOps, rootOpsA, rootOpsH, List.cons_append, List.nil_append, List.mem_cons,
    List.not_mem_nil, or_false] at hop
  rcases hop with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp only [Op.len, labA, labM, labH, labRows, labLogCols, List.length_cons, List.length_nil,
      List.Vector.toList_length, le64_length] <;> omega

theorem slotPreOps_len (P : BlockParams) (j : ℕ) (sp : SlotProof) (L : ℕ) (hL : 81 ≤ L) :
    ∀ op ∈ slotPreOps P j sp, op.len ≤ L := by
  intro op hop
  simp only [slotPreOps, drawOps, List.mem_append, List.mem_replicate, List.mem_cons, List.not_mem_nil,
    or_false] at hop
  rcases hop with ⟨-, rfl⟩ | rfl | rfl | rfl
  · simp only [Op.len]; omega
  · simp only [Op.len, labPbSlot, List.length_cons, List.length_nil, le64_length]; omega
  · simp only [Op.len]; omega
  · simp only [Op.len, labPbScalar, List.length_cons, List.length_nil, flatMap_singleton_toBytes,
      fp2_toBytes_length]; omega

theorem slotPreOps_length (P : BlockParams) (j : ℕ) (sp : SlotProof) :
    (slotPreOps P j sp).length = P.draws j + 3 := by
  simp [slotPreOps, drawOps]

theorem termOp_len (sp : SlotProof) (m L : ℕ) (hm : sp.terms.length = m) (hL : 55 + 16 * m ≤ L) :
    (termOp sp).len ≤ L := by
  simp only [termOp, Op.len, labPbTerm, List.length_cons, List.length_nil, flatMap_toBytes_length, hm]
  omega

/-- **A win against the block is L8's win against its schedule** (`SlotsWin`) on the verifier's run of slots. -/
theorem blockWin_slotsWin (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (P : BlockParams)
    (hdrLen : ℕ) (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (out : List Op × Core)
    (hwin : BlockWin U key domain L P hdrLen f G out) :
    SlotsWin U key domain L (blockSched P hdrLen f) G (blockOps P out.1 out.2) := by
  obtain ⟨hdr, core⟩ := out
  obtain ⟨hhl, hhfit, hcan, hsh, bga, rs, acc, t', hacc, hterm, kf, rf, hrf, hdeg, hfalse⟩ := hwin
  simp only at hhl hhfit hcan hsh hacc
  -- the slot loop on the roots' transcript
  have hslen : core.slots.length = P.geom.slots.length := by
    rw [hsh.1]
  rw [blockSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact (hgeom i (by omega)).1
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hbga' : bga = (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).1,
        (((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1,
        ((((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).2.challengeFp2 (liftH G)).1) :=
      hbga.symm
    have hcanS : ∀ i q, core.slots[i]? = some q → SlotCanon q := fun i q h => hcan.1 q (List.mem_of_getElem? h)
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs, Option.getD_some]
    have hterms : ∀ i q, core.slots[i]? = some q → q.terms.length = slotTerms P i := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2.1 i q s tt hq hs htt).2.2
      rw [this, slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall i q r' hq hi).2.1]
      exact (hcanS i q hq).1
    -- facts about slot k of the schedule
    have hslot : ∀ k sl, (blockSched P hdrLen f)[k]? = some sl → k < core.slots.length ∧ sl = blockSlot P hdrLen f k := by
      intro k sl h
      simp only [blockSched, List.getElem?_map] at h
      obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
      rw [List.getElem_range] at hget
      subst hget
      exact ⟨by rw [hslen]; simpa using hlt, rfl⟩
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        (blockSlot P hdrLen f k).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)
          ++ slotPreOps P k q)) = (f k (seenOf bga rs k), r.claimed) := by
      intro k q r hq hr
      have htr := tSeen_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround bga rs hbga' hlen
        (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      have hhl' : hdr.length = hdrLen := hhl
      simp only [blockSlot]
      rw [← hhl', htr]
      simp only
      obtain ⟨-, hsc, ⟨df, hdf, hcl⟩, -⟩ := hall k q r hq hr
      rw [claimOf_seenOf P bga rs k r hr hscal df (by rw [hbga']; simpa [histOf] using hdf)
        (by rw [hsc]; simpa using hcl)]
    have hpre : ∀ k q ok, core.slots[k]? = some q → (blockOps P hdr core)[k]? = some ok →
        slotPre (blockOps P hdr core) k ok = hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k)
          ++ slotPreOps P k q := fun k q ok h1 h2 => slotPre_blockOps P hdr core k q ok h1 h2
    have hok : ∀ k q, core.slots[k]? = some q →
        (blockOps P hdr core)[k]? = some ((if k = 0 then hdr ++ rootOps P core else [termOp (core.slots.getD (k - 1) q)])
          ++ slotPreOps P k q, q.rounds) := by
      intro k q hq
      rw [blockOps, slotOpsFrom_get P _ 0 core.slots k q hq, Nat.zero_add]
    refine ⟨?_, ?_, ?_⟩
    · rw [blockOps, slotOpsFrom_length, blockSched, List.length_map, List.length_range, hslen]
    · intro k sl ok h1 h2
      obtain ⟨hk, rfl⟩ := hslot k sl h1
      obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
      obtain ⟨r, hr⟩ : ∃ r, rs[k]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      rw [hok k q hq, Option.some.injEq] at h2
      subst h2
      have hst := hstmt k q r hq hr
      rw [hpre k q _ hq (hok k q hq)]
      rw [hst]
      refine ⟨?_, ?_, ?_, ?_, ?_⟩
      · simp only [blockSlot, List.length_append, slotPreOps_length]
        split_ifs with hk0
        · simp only [List.length_append, hhl]
          rfl
        · rfl
      · intro op hop
        simp only [List.mem_append] at hop
        rcases hop with hop | hop
        · split_ifs at hop with hk0
          · simp only [List.mem_append] at hop
            rcases hop with hop | hop
            · exact hhfit op hop
            · exact rootOps_len P core L hL op hop
          · simp only [List.mem_singleton] at hop
            subst hop
            have hkm : k - 1 < core.slots.length := by omega
            have hq' : core.slots[k - 1]? = some (core.slots.getD (k - 1) q) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hkm, Option.getD_some]
            exact termOp_len _ (slotTerms P (k - 1)) L (hterms _ _ hq') (hgeom (k - 1) (by omega)).2
        · exact slotPreOps_len P k q L hL op hop
      · exact (hcanS k q hq).2.1
      · obtain ⟨-, -, ⟨df, -, hcl⟩, -⟩ := hall k q r hq hr
        exact hostedSum_canon _ q.scalar _ _ (hcanS k q hq).1 hcl
      · obtain ⟨-, -, -, hsv⟩ := hall k q r hq hr
        simp only [Nat.zero_add] at hsv
        refine ⟨r.fin, r.rho ++ r.es, ?_, hterm k r hr⟩
        have hT : runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)
            = runOps (liftH G) (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOps P core)) 0 core.slots k) (slotPreOps P k q) := by
          rw [runOps_append, runOps_append]
          rfl
        rw [hT]
        exact hsv
    · obtain ⟨hk, -⟩ : kf < core.slots.length ∧ True := ⟨by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hrf).1, trivial⟩
      obtain ⟨q, hq⟩ : ∃ q, core.slots[kf]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
      refine ⟨kf, blockSlot P hdrLen f kf, _, ?_, hok kf q hq, ?_⟩
      · have hk' : kf < (List.range P.geom.slots.length).length := by rw [List.length_range, ← hslen]; exact hk
        rw [blockSched, List.getElem?_map, List.getElem?_eq_getElem hk', List.getElem_range]
        rfl
      · rw [hpre kf q _ hq (hok kf q hq), hstmt kf q rf hq hrf]
        exact ⟨hdeg, hfalse⟩
  · cases hacc

/-- **Fiat–Shamir soundness of the block's sumcheck slots on the REAL `verify_core` schedule** (D63 step L9). In
the random-oracle model on the hash inputs of at most `L` bytes, a prover making at most `q` queries outputs a header
of `hdrLen` operations and a block core. The probability that the executable `blockSlots` (`verify_core` up to the
end of its slot loop) accepts, every slot's terminal check holds, and yet SOME slot's claimed sum (the scalar plus
the hosted scalars times `define`'s coefficients, all read off the trace) is false for its polynomial `f k` of
individual degree `≤ d_k` (any function of what the trace shows), is at most
`T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ = blockLen`: the bound of ONE slot
of the largest degree. -/
theorem block_sumchecks_fs_sound [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G))
      ≤ (((q + blockLen P.draws P.geom.slots hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  let A' : OC (QB L) Dig (List (List Op × List (List Fp2))) := A.bind (fun out => .ret (blockOps P out.1 out.2))
  have hA' : A'.Bounded q :=
    (hA.bind (fun out => (show (OC.ret (blockOps P out.1 out.2) : OC (QB L) Dig (List (List Op × List (List Fp2)))).Bounded 0
      from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = blockOps P (A.run G).1 (A.run G).2 := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hsl : ∀ sl ∈ blockSched P hdrLen f, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [blockSched, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, hk, rfl⟩ := hsl
    obtain ⟨h1, h2, h3, -⟩ := hgeom k hk
    exact ⟨h1, lt_of_le_of_lt h2 hdp, h2, h3⟩
  have hmain := exec_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 (blockSched P hdrLen f) dmax hsl q A' hA'
  rw [slotsLen_blockSched] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hwin
  rw [Set.mem_ofPred_eq] at hwin ⊢
  rw [hrun G]
  exact blockWin_slotsWin U key domain L P hdrLen f (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G
    (A.run G) hwin

/-- **At Goldilocks** (`|K| = p²`): the bias `(1 + 2^-64)²`. -/
theorem block_sumchecks_fs_sound_goldilocks [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G))
      ≤ (((q + blockLen P.draws P.geom.slots hdrLen + 1) * dmax : ℕ) : ℝ≥0∞) / ((gP ^ 2 : ℕ) : ℝ≥0∞)
          * (1 + (2⁻¹ : ℝ≥0∞) ^ 64) ^ 2
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1) Dig
        + collBound (q + blockLen P.draws P.geom.slots hdrLen + 1 + 1) Dig := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  refine (block_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 hL81 P hdrLen f dmax hdp hgeom hgt q A hA).trans ?_
  rw [hF]
  exact add_le_add (add_le_add (mul_le_mul' le_rfl (bias_le_two_pow_64 gP (by norm_num))) le_rfl) le_rfl

/-- **The numbers** (stated for a variable `p` within `2^32` below `2^64`, L7-4): with every round degree `≤ 7` and
`T ≤ 2^64 + 2^20`, `T·d/p²·(1 + p/2^128)² + collBound T + collBound (T + 1) ≤ 2^-61` (the first term at most
`15·2^61/2^126`, each collision term at most `2^-126`). -/
theorem block_bound_le (p T d : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p) (hT : T ≤ 2 ^ 64 + 2 ^ 20)
    (hd : d ≤ 7) :
    ((T * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      + collBound T Dig + collBound (T + 1) Dig ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hp0 : p ≠ 0 := by
    intro h
    rw [h] at hp2
    norm_num at hp2
  have hN0 : ((2 ^ 128 : ℕ) : ℝ≥0∞) ≠ 0 := by exact_mod_cast (by positivity : (2 ^ 128 : ℕ) ≠ 0)
  have hone : (1 : ℝ≥0∞) + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)
      = ((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [Nat.cast_add, ENNReal.add_div, ENNReal.div_self hN0 (ENNReal.natCast_ne_top _)]
  have hsq : (((2 ^ 128 + p : ℕ) : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      = (((2 ^ 128 + p) * (2 ^ 128 + p) : ℕ) : ℝ≥0∞) / ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [sq, natFrac_mul _ _ _ _ (by positivity)]
  have hcard : (Fintype.card Dig : ℝ≥0∞) = ((2 ^ 128 * 2 ^ 128 : ℕ) : ℝ≥0∞) := by
    rw [card_dig, Fintype.card_prod, Fintype.card_fin]
  have h1 : ((T * d : ℕ) : ℝ≥0∞) / ((p ^ 2 : ℕ) : ℝ≥0∞) * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
      ≤ ((15 * 2 ^ 61 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
    rw [hone, hsq, natFrac_mul _ _ _ _ (pow_ne_zero 2 hp0)]
    refine natFrac_le (mul_ne_zero (pow_ne_zero 2 hp0) (by positivity)) (by positivity) ?_
    calc T * d * ((2 ^ 128 + p) * (2 ^ 128 + p)) * 2 ^ 126
        ≤ (2 ^ 64 + 2 ^ 20) * 7 * ((2 ^ 128 + 2 ^ 64) * (2 ^ 128 + 2 ^ 64)) * 2 ^ 126 := by gcongr
      _ ≤ 15 * 2 ^ 61 * ((2 ^ 64 - 2 ^ 32) ^ 2 * (2 ^ 128 * 2 ^ 128)) := by norm_num
      _ ≤ 15 * 2 ^ 61 * (p ^ 2 * (2 ^ 128 * 2 ^ 128)) := by gcongr
  have hcoll : ∀ t : ℕ, t ≤ 2 ^ 64 + 2 ^ 20 + 1 →
      collBound t Dig ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
    intro t ht
    unfold collBound
    rw [hcard]
    refine natFrac_le (by positivity) (by positivity) ?_
    calc t * (t - 1) / 2 * 2 ^ 126 ≤ t * t * 2 ^ 126 := by
          gcongr
          exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
      _ ≤ (2 ^ 64 + 2 ^ 20 + 1) * (2 ^ 64 + 2 ^ 20 + 1) * 2 ^ 126 := by gcongr
      _ ≤ 1 * (2 ^ 128 * 2 ^ 128) := by norm_num
  calc _ ≤ ((15 * 2 ^ 61 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞)
        + ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) :=
        add_le_add (add_le_add h1 (hcoll T (by omega))) (hcoll (T + 1) (by omega))
    _ = ((15 * 2 ^ 61 + 1 + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 126 : ℕ) : ℝ≥0∞) := by
        rw [ENNReal.div_add_div_same, ENNReal.div_add_div_same, Nat.cast_add, Nat.cast_add]
    _ ≤ ((1 : ℕ) : ℝ≥0∞) / ((2 ^ 61 : ℕ) : ℝ≥0∞) := natFrac_le (by positivity) (by positivity) (by norm_num)
    _ = (2⁻¹ : ℝ≥0∞) ^ 61 := by
        rw [Nat.cast_one, one_div, Nat.cast_pow, Nat.cast_ofNat, ENNReal.inv_pow]

/-- **At the block's shape**: with Goldilocks' `|K| = p²`, every round degree `≤ dmax ≤ 7` and
`T = q + ℓ + 1 ≤ 2^64 + 2^20`, a false claimed sum in ANY slot of the block passes `blockSlots` with every terminal
check with probability at most `2^-61`. -/
theorem block_sumchecks_fs_sound_shape [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (hdrLen : ℕ)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (dmax : ℕ)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q)
    (hd7 : dmax ≤ 7) (hT : q + blockLen P.draws P.geom.slots hdrLen + 1 ≤ 2 ^ 64 + 2 ^ 20) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hF : Fintype.card K = gP ^ 2 :=
    card_of_pairs gP (Equiv.ofBijective _ (ZK60.Hiding.fp2_bijective hK2 hU seven_not_square))
  have hdp : dmax < gP := lt_of_le_of_lt hd7 (by norm_num [gP])
  refine (block_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 hL81 P hdrLen f dmax hdp hgeom hgt q A hA).trans ?_
  rw [hF]
  exact block_bound_le gP _ dmax (by norm_num [gP]) (by norm_num [gP]) hT hd7

end Theorem

/-! ## W16R2's specifics (named; W16R3 replaces these and `define`, not the theorems above) -/

namespace W16R2

/-- `M`'s two clear vectors' length, `2·2^MASK_LOG_MSG` (`zk.rs`; the same at every profile). -/
def maskVec : ℕ := 1024
/-- `MASK_Q`. -/
def maskQ : ℕ := 256
/-- `2^MASK_LOG_DOM`. -/
def maskDom : ℕ := 4096
/-- `MASK_LOG_DOM`. -/
def maskPath : ℕ := 12
/-- `W16R2_OPENED_COLS`: the opened columns and the pads per row of every regular W16R2 commitment. -/
def openedCols : ℕ := 280
/-- `MAX_WIRE_BYTES_TRAINED` (a W16R2 profile is a trained-calibration profile). -/
def ceiling : ℕ := 256 * 1024 * 1024

/-- **The W16R2 development rung's slot schedule**, `(n, e, d)` per slot (`Layout::slots` at
`hashline-zk-mr1/private-block-rung-lh-t32-w16r2-d/2`, recorded by the corpus and checked by `ExecBlockCheck`). -/
def rungSlots : List (ℕ × ℕ × ℕ) :=
  [(14, 1, 4), (14, 1, 4), (5, 1, 3), (14, 1, 4), (14, 1, 3), (9, 1, 2), (9, 1, 2), (9, 1, 2), (9, 2, 3), (8, 2, 3),
    (10, 1, 2), (9, 1, 2), (9, 1, 2), (10, 1, 2), (14, 1, 5), (15, 1, 4), (14, 1, 4), (14, 1, 4), (15, 1, 5),
    (14, 1, 3), (14, 1, 2), (14, 1, 2), (14, 1, 2)]

/-- The rung's terminal count per slot (`slot_terms`). -/
def rungTerms : List ℕ := [1, 1, 22, 3, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 31, 10, 10, 18, 14, 34, 1, 2, 2]

/-- How many challenges each slot's `define` draws at the rung (counted by the export on the code's transcript). -/
def rungDrawList : List ℕ := [5, 5, 13, 16, 10, 15, 9, 9, 14, 15, 14, 15, 10, 14, 34, 21, 20, 26, 25, 33, 0, 14, 14]

def rungDraws (k : ℕ) : ℕ := rungDrawList.getD k 0

/-- **The rung's item count**: `ℓ = hdrLen + 1044` (the 10 root operations, 351 draws, 23 × 3 slot prefixes, 22
`pb-term` absorbs, and 296 rounds of two items). -/
theorem rung_len (h : ℕ) : blockLen rungDraws rungSlots h = h + 1044 := by
  simp [blockLen, rungSlots, rungDraws, rungDrawList, List.range_succ]

/-- The rung's per-slot facts: every degree in `[1, 5]`, every hash input of a round or a `pb-term` within `2^20`
bytes. -/
theorem rung_slot_facts : ∀ k, k < 23 → 1 ≤ (rungSlots.getD k (0, 0, 0)).2.2 ∧ (rungSlots.getD k (0, 0, 0)).2.2 ≤ 5
    ∧ 56 + 16 * ((rungSlots.getD k (0, 0, 0)).2.2 + 1) ≤ 2 ^ 20 ∧ 55 + 16 * rungTerms.getD k 0 ≤ 2 ^ 20 := by
  decide

/-- **The W16R2 rung block's sumcheck Fiat–Shamir bound, numerically** (D63 step L9). For a block verifier with the
rung's schedule, a header of at most `2^19` operations, hash inputs of at most `L ≥ 2^20` bytes and a prover making
at most `q ≤ 2^64` queries: a false claimed sum in ANY of the 23 slots passes `blockSlots` with every terminal check
with probability at most `2^-61` (at Goldilocks, degree `≤ 5`, `T = q + hdrLen + 1045 ≤ 2^64 + 2^20`). -/
theorem rung_block_fs_sound {K : Type} [Field K] [Algebra GF K] [Fintype K] [DecidableEq K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8)
    (hs : decodeLink (startMsg domain) = none) (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64)
    (hL20 : 2 ^ 20 ≤ L) (P : BlockParams) (hdr : P.draws = rungDraws) (hsl : P.geom.slots = rungSlots)
    (htm : P.geom.terms = rungTerms) (hdrLen : ℕ) (hh : hdrLen ≤ 2 ^ 19)
    (f : (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (q : ℕ) (hq : q ≤ 2 ^ 64) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => BlockWin U key domain L P hdrLen f G (A.run G)) ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  refine block_sumchecks_fs_sound_shape U hU hK2 key domain hs L hL hL64 (by omega) P hdrLen f 5 ?_ ?_ q A hA
    (by norm_num) ?_
  · intro k hk
    rw [hsl] at hk
    have hk' : k < 23 := by simpa [rungSlots] using hk
    obtain ⟨h1, h2, h3, h4⟩ := rung_slot_facts k hk'
    simp only [slotShape, slotTerms, hsl, htm]
    exact ⟨h1, h2, by omega, by omega⟩
  · rw [hsl, htm]
    rfl
  · rw [hdr, hsl, rung_len]
    have h1 : hdrLen + 1044 + 1 ≤ 2 ^ 20 :=
      le_trans (Nat.add_le_add_right (Nat.add_le_add_right hh 1044) 1) (by norm_num)
    calc q + (hdrLen + 1044) + 1 = q + (hdrLen + 1044 + 1) := by rw [Nat.add_assoc]
      _ ≤ 2 ^ 64 + 2 ^ 20 := Nat.add_le_add hq h1

end W16R2

end ZK60.Exec.Block
