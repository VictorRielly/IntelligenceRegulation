/-
D63 lane L31 (2026-11-09), part 1: **the accumulator's reader on the verifier's own trace, and the claims' counts**
(findings L22-7 / L28-2, `hRd`; L22-2 / L28-3, `hcnt`), for ANY block shape.

L28's block theorems (`block_knowledge_open_w16r2`, `_r13`) take a reader `accRd` of the slot phase's trace with the
premise `hRd` ("on the verifier's own accepting trace, the reader returns the verifier's functional list and its `A`
and `H` claim lists"), and the premise `hcnt` ("`A` carries `nA` claims and `H` `nH`"). Both are proved here.

The reader is explicit. The slot loop's accumulator is a function of what the trace shows: the three LogUp challenges;
per slot, `define`'s draws, `c`, the scalar's bytes, each round's message bytes and challenge, and the terminals'
bytes. `define` is the verifier's own function of the history and the draws, so the reader re-runs it.

* `decAll`, `decAll_toBytes`, `decAll_rounds`: an absorbed vector's bytes decode to the vector (canonical words);
* `tRounds`, `tRounds_trace`: the rounds' reader (each message's bytes, each challenge);
* `SlotRead`, `slotReadOf`, `tSlotFull`, `tSlotFull_trace`: one whole slot, read off its own trace;
* `accStepCore`, `accStep`, **`slotStep_read`**: an accepting `slotStep`'s accumulator is `accStep` of what the trace
  shows (and the acceptance fixes the number of rounds);
* `tAccLoop`, **`slotsLoop_read`**: the slot loop;
* `tAccRd`, **`tAccRd_trace`**, **`accRd_slotTrace`**: the block's reader returns the WHOLE accumulator on the
  verifier's own trace (`hRd`, for every `BlockParams` whose slot degrees are at least `1`);
* `cmCount`, `slotClaims_length`, `sumFrom`, `slotsLoop_claims`, `blockSlots_claims`, **`hcnt_of_define`**: when
  `define`'s private tables sit in fixed commitments per slot (`cmCount cm df.tabs = cnt k`), the accumulator's claim
  lists have the schedule's lengths (`hcnt`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16GlueW16

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## Decoding absorbed vectors -/

/-- Every 16-byte piece of an absorbed vector, decoded (`Fp2::from_bytes`). -/
def decAll (b : List UInt8) : List Fp2 := Link.decFp2s (b.length / 16) b

/-- On the bytes of canonical words it returns the words. -/
theorem decAll_toBytes (v : List Fp2) (h : ∀ x ∈ v, x.Canon) : decAll (v.flatMap Fp2.toBytes) = v := by
  unfold decAll
  rw [flatMap_toBytes_length, Nat.mul_div_cancel_left _ (by norm_num : 0 < 16)]
  exact Link.decFp2s_toBytes v h

theorem decAll_rounds : ∀ (rs : List (List Fp2)), (∀ r ∈ rs, ∀ x ∈ r, x.Canon) →
    (rs.map (fun x => x.flatMap Fp2.toBytes)).map decAll = rs
  | [], _ => rfl
  | r :: rs, h => by
    rw [List.map_cons, List.map_cons, decAll_toBytes r (h r List.mem_cons_self),
      decAll_rounds rs (fun r' hr' => h r' (List.mem_cons_of_mem _ hr'))]

/-! ## Reading one whole slot -/

/-- **What the trace shows of one whole slot**: its prefix (`define`'s draws, `c`, the scalar's bytes), its rounds (each
message's bytes, each challenge) and the terminals' bytes. -/
structure SlotRead where
  pre : List Fp2 × Fp2 × List UInt8
  rds : List (List UInt8) × List Fp2
  terms : List UInt8

/-- `n` sumcheck rounds: each message's bytes and the challenge squeezed after it. -/
def tRounds : ℕ → TRd (List (List UInt8) × List Fp2)
  | 0 => TRd.ret ([], [])
  | n + 1 => TRd.bnd tAbs fun x => TRd.bnd tChal fun c => TRd.bnd (tRounds n) fun r => TRd.ret (x :: r.1, c :: r.2)

/-- One whole slot: its prefix, its `n + e` rounds, `pb-term`. -/
def tSlotFull (P : BlockParams) (j : ℕ) : TRd SlotRead :=
  TRd.bnd (tSlotPre P j) fun v => TRd.bnd (tRounds ((slotShape P j).1 + (slotShape P j).2.1)) fun r =>
  TRd.bnd tAbs fun x => TRd.ret ⟨v, r, x⟩

section Read

variable (H : HIn → Dig)

/-- **The rounds' trace reads as the rounds**: the messages' bytes and the transcript's challenges. -/
theorem tRounds_trace : ∀ (ss : List (List Fp2)) (t : Tr) (rest : List (TItem × Dig)),
    tRounds ss.length (opTrace H t (scOps ss) ++ rest)
      = some ((ss.map (fun x => x.flatMap Fp2.toBytes), (scChal H ss t).1), rest)
  | [], _, _ => rfl
  | s :: ss, t, rest => by
    have ih := tRounds_trace ss ((t.absorbFp2 H scLabel s).challengeFp2 H).2 rest
    have e : opTrace H t (scOps (s :: ss)) ++ rest
        = (TItem.absorb scLabel (s.flatMap Fp2.toBytes), (t.absorbFp2 H scLabel s).state)
          :: (TItem.squeeze (t.absorbFp2 H scLabel s).counter, ((t.absorbFp2 H scLabel s).squeeze H).1)
          :: (opTrace H ((t.absorbFp2 H scLabel s).challengeFp2 H).2 (scOps ss) ++ rest) := rfl
    rw [List.length_cons, e]
    show TRd.bnd tAbs (fun x => TRd.bnd tChal fun c => TRd.bnd (tRounds ss.length) fun r =>
      TRd.ret (x :: r.1, c :: r.2)) _ = _
    rw [TRd.bnd_def, tAbs_cons]
    dsimp only
    rw [TRd.bnd_def, tChal_cons]
    dsimp only
    rw [TRd.bnd_def, ih]
    rfl

/-- What a whole slot's own trace shows. -/
def slotReadOf (P : BlockParams) (t : Tr) (j : ℕ) (sp : SlotProof) : SlotRead :=
  ⟨preVals H P t j sp, (sp.rounds.map (fun x => x.flatMap Fp2.toBytes),
    (scChal H sp.rounds (runOps H t (slotPreOps P j sp))).1), sp.terms.flatMap Fp2.toBytes⟩

theorem opTrace_termOp (sp : SlotProof) (t : Tr) (rest : List (TItem × Dig)) :
    opTrace H t [termOp sp] ++ rest
      = (TItem.absorb labPbTerm (sp.terms.flatMap Fp2.toBytes),
          (t.absorb H labPbTerm (sp.terms.flatMap Fp2.toBytes)).state) :: rest := rfl

/-- **A whole slot's trace reads as the slot**, when it has the shape's number of rounds. -/
theorem tSlotFull_trace (P : BlockParams) (j : ℕ) (sp : SlotProof) (t : Tr) (rest : List (TItem × Dig))
    (hr : sp.rounds.length = (slotShape P j).1 + (slotShape P j).2.1) :
    tSlotFull P j (opTrace H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp]) ++ rest)
      = some (slotReadOf H P t j sp, rest) := by
  have hsplit : opTrace H t (slotPreOps P j sp ++ scOps sp.rounds ++ [termOp sp]) ++ rest
      = opTrace H t (slotPreOps P j sp) ++ (opTrace H (runOps H t (slotPreOps P j sp)) (scOps sp.rounds)
        ++ (opTrace H (runOps H (runOps H t (slotPreOps P j sp)) (scOps sp.rounds)) [termOp sp] ++ rest)) := by
    simp only [opTrace_append, List.append_assoc]
  unfold tSlotFull
  rw [hsplit, TRd.bnd_def, tSlotPre_trace]
  dsimp only
  rw [TRd.bnd_def, ← hr, tRounds_trace]
  dsimp only
  rw [TRd.bnd_def, opTrace_termOp, tAbs_cons]
  rfl

/-! ## The accumulator after a slot, from what the trace shows -/

/-- **The accumulator after slot `s`**, from the history, the accumulator before it, and the slot's draws, `c`, scalar,
round messages, round challenges and terminals: `define`, the hosted sum, the final claim of the rounds
(`scFinalExec`), the terminal values, `g = (fin − poly(vals))·c⁻¹`, and `slotAcc`. (On an input no accepting slot
produces it returns the accumulator unchanged.) -/
def accStepCore (P : BlockParams) (hist : Hist) (s : ℕ) (acc : Acc) (draws : List Fp2) (c scalar : Fp2)
    (rounds : List (List Fp2)) (chals terms : List Fp2) : Acc :=
  match P.define s hist draws with
  | .error _ => acc
  | .ok df =>
    match hostedSum acc.scalars scalar df.hosted with
    | .error _ => acc
    | .ok claimed =>
      match tabVals (oneMinusProd (chals.drop (slotShape P s).1)) (chals.take (slotShape P s).1) terms df.tabs 0 with
      | .error _ => acc
      | .ok vals =>
        slotAcc P s acc df c scalar (((scFinalExec rounds chals claimed).sub (df.poly vals)).mul c.inv) chals terms

/-- The same from a slot's read. -/
def accStep (P : BlockParams) (hist : Hist) (s : ℕ) (acc : Acc) (v : SlotRead) : Acc :=
  accStepCore P hist s acc v.pre.1 v.pre.2.1 (Fp2.fromBytes v.pre.2.2) (v.rds.1.map decAll) v.rds.2 (decAll v.terms)

/-- **An accepting slot's accumulator is `accStep` of what its trace shows.** The acceptance also fixes the number of
rounds (`sumcheck::verify` refuses another count), and `define` saw the draws the trace shows. -/
theorem slotStep_read (P : BlockParams) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (t : Tr) (r : SlotRec)
    (acc' : Acc) (t' : Tr) (hcan : SlotCanon sp) (hd : 1 ≤ (slotShape P s).2.2)
    (h : slotStep H P s hist sp acc t = .ok (r, acc', t')) :
    sp.rounds.length = (slotShape P s).1 + (slotShape P s).2.1
      ∧ (slotReadOf H P t s sp).pre.1 = r.draws
      ∧ accStep P hist s acc (slotReadOf H P t s sp) = acc' := by
  obtain ⟨df, hdf, hcl, hsv, -, hdr, hc, -, -⟩ := slotStep_ok H P s hist sp acc t r acc' t' h
  obtain ⟨df', vals, rhoFull, hdf', -, -, -, hrho, hes, hvals, hacc⟩ :=
    slotStep_ok_terminal H P s hist sp acc t r acc' t' h
  have hdd : df = df' := by
    have h1 := hdf'
    rw [hdr] at h1
    exact Except.ok.inj (hdf.symm.trans h1)
  rw [hdd] at hcl
  have hsv' := hsv
  unfold scVerify at hsv'
  split at hsv'
  · simp at hsv'
  · rename_i hlen'
    have hlen : sp.rounds.length = (slotShape P s).1 + (slotShape P s).2.1 := not_not.mp hlen'
    obtain ⟨-, hrs, hfin⟩ := (scLoop_ok_iff H _ hd sp.rounds 0 r.claimed [] _ r.fin (r.rho ++ r.es)).mp hsv'
    rw [List.nil_append] at hrs
    have hrf : rhoFull = (scChal H sp.rounds (runOps H t (slotPreOps P s sp))).1 := by
      rw [← hrs, hrho, hes, List.take_append_drop]
    have hfin' : r.fin = scFinalExec sp.rounds rhoFull r.claimed := by
      rw [hrf]
      exact hfin
    have hval' : tabVals (oneMinusProd (rhoFull.drop (slotShape P s).1)) (rhoFull.take (slotShape P s).1) sp.terms
        df'.tabs 0 = .ok vals := by
      rw [← hrho, ← hes]
      exact hvals
    have hscal : Fp2.fromBytes ([sp.scalar].flatMap Fp2.toBytes) = sp.scalar := by
      rw [flatMap_singleton_toBytes]
      exact Fp2.fromBytes_toBytes _ hcan.1
    have key : accStepCore P hist s acc r.draws r.c sp.scalar sp.rounds rhoFull sp.terms = acc' := by
      unfold accStepCore
      rw [hdf']
      dsimp only
      rw [hcl]
      dsimp only
      rw [hval']
      dsimp only
      rw [← hfin']
      exact hacc.symm
    refine ⟨hlen, hdr.symm, ?_⟩
    show accStepCore P hist s acc (t.challengeFp2Vec H (P.draws s)).1
      ((((t.challengeFp2Vec H (P.draws s)).2).absorbU64 H labPbSlot (UInt64.ofNat s)).challengeFp2 H).1
      (Fp2.fromBytes ([sp.scalar].flatMap Fp2.toBytes))
      ((sp.rounds.map (fun x => x.flatMap Fp2.toBytes)).map decAll)
      (scChal H sp.rounds (runOps H t (slotPreOps P s sp))).1 (decAll (sp.terms.flatMap Fp2.toBytes)) = acc'
    rw [← hdr, ← hc, hscal, decAll_rounds sp.rounds hcan.2.1, ← hrf, decAll_toBytes sp.terms hcan.2.2]
    exact key

/-! ## The slot loop -/

/-- **The slot loop's reader**: `m` whole slots from slot `j`, the accumulator and the draws' history growing as the
verifier's do. -/
def tAccLoop (P : BlockParams) (b g a : Fp2) : List (List Fp2) → ℕ → ℕ → Acc → TRd Acc
  | _, _, 0, acc => TRd.ret acc
  | ds, j, m + 1, acc => TRd.bnd (tSlotFull P j) fun v =>
      tAccLoop P b g a (ds ++ [v.pre.1]) (j + 1) m (accStep P ⟨b, g, a, ds⟩ j acc v)

/-- **An accepting slot loop's accumulator is the reader's**, on the loop's own trace (canonical slot proofs, slot
degrees at least `1`). -/
theorem slotsLoop_read (P : BlockParams) (b g a : Fp2) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr) (rest : List (TItem × Dig)), (∀ sp ∈ sps, SlotCanon sp) →
      (∀ i, i < sps.length → 1 ≤ (slotShape P (j + i)).2.2) →
      slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') →
      tAccLoop P b g a (recs.map SlotRec.draws) j sps.length acc (opTrace H t (fullOps P j sps) ++ rest)
        = some (acc', rest)
  | [], recs, j, acc, t, recs', acc', t', rest, _, _, h => by
    simp only [slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, -⟩ := h
    rfl
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', rest, hcan, hd1, h => by
    simp only [slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      have hd0 : 1 ≤ (slotShape P j).2.2 := by simpa using hd1 0 (by simp)
      obtain ⟨hlen0, hdr0, hacc0⟩ :=
        slotStep_read H P j _ sp0 acc t r0 acc0 t0 (hcan sp0 List.mem_cons_self) hd0 hstep
      have hacc0' : accStep P ⟨b, g, a, recs.map SlotRec.draws⟩ j acc (slotReadOf H P t j sp0) = acc0 := hacc0
      obtain ⟨df, -, -, hsv, ht0, -, -, -, -⟩ := slotStep_ok H P j _ sp0 acc t r0 acc0 t0 hstep
      have ht0' : t0 = runOps H t (slotPreOps P j sp0 ++ scOps sp0.rounds ++ [termOp sp0]) := by
        rw [ht0, slot_after H P j sp0 t r0.claimed r0.fin (r0.rho ++ r0.es) hd0 hsv]
      have ih := slotsLoop_read P b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' rest
        (fun sp hsp => hcan sp (List.mem_cons_of_mem _ hsp))
        (fun i hi => by
          have := hd1 (i + 1) (by simp; omega)
          rwa [show j + (i + 1) = j + 1 + i by omega] at this) h
      have hsplit : opTrace H t (fullOps P j (sp0 :: sps)) ++ rest
          = opTrace H t (slotPreOps P j sp0 ++ scOps sp0.rounds ++ [termOp sp0])
            ++ (opTrace H t0 (fullOps P (j + 1) sps) ++ rest) := by
        rw [ht0']
        simp only [fullOps, opTrace_append, runOps_append, List.append_assoc]
      have e : recs.map SlotRec.draws ++ [r0.draws] = (recs ++ [r0]).map SlotRec.draws := by
        rw [List.map_append]
        rfl
      rw [List.length_cons, hsplit]
      show TRd.bnd (tSlotFull P j) (fun v => tAccLoop P b g a (recs.map SlotRec.draws ++ [v.pre.1]) (j + 1) sps.length
        (accStep P ⟨b, g, a, recs.map SlotRec.draws⟩ j acc v)) _ = _
      rw [TRd.bnd_def, tSlotFull_trace H P j sp0 t _ hlen0]
      dsimp only
      rw [hacc0', hdr0, e]
      exact ih

/-! ## The block's reader -/

/-- The accumulator a reader's result holds (the empty one when the trace does not parse). -/
def accOfRd (o : Option (Acc × List (TItem × Dig))) : Acc :=
  match o with
  | some (acc, _) => acc
  | none => {}

/-- **The accumulator's reader**: the header and the roots (`tRoot`: `β`, `γ`, `α`), then every slot of the shape. -/
def tAccRd (P : BlockParams) (hdrLen : ℕ) (τ : List (TItem × Dig)) : Acc :=
  accOfRd (TRd.bnd (tRoot hdrLen) (fun bga => tAccLoop P bga.1 bga.2.1 bga.2.2 [] 0 P.geom.slots.length {}) τ)

/-- **On the verifier's own accepting trace the reader returns the verifier's accumulator** (L22-7, L28-2): the whole
accumulator, so in particular `acc.fs ++ acc.hostFs`, `acc.claims.a` and `acc.claims.h`. For any `BlockParams`, a
canonical core with the shape's number of slots, and slot degrees at least `1`. -/
theorem tAccRd_trace (P : BlockParams) (core : Core) (hdr : List Op) (t0 : Tr) (bga : Fp2 × Fp2 × Fp2)
    (rs : List SlotRec) (acc : Acc) (t' : Tr) (hcan : CoreCanon core)
    (hsh : core.slots.length = P.geom.slots.length)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2)
    (h : blockSlots H P core (runOps H t0 hdr) = .ok (bga, rs, acc, t')) :
    tAccRd P hdr.length (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) = acc := by
  rw [blockSlots_eq] at h
  simp only [← runOps_append] at h
  split at h
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, hres⟩ := h
    subst hres
    have hrd := slotsLoop_read H P _ _ _ core.slots [] 0 {} _ rs acc t' [] (fun sp hsp => hcan.1 sp hsp)
      (fun i hi => by
        rw [Nat.zero_add]
        exact hd i (by rw [← hsh]; exact hi)) hloop
    rw [List.append_nil, hsh] at hrd
    have hfinal : TRd.bnd (tRoot hdr.length)
        (fun bga => tAccLoop P bga.1 bga.2.1 bga.2.2 [] 0 P.geom.slots.length {})
        (opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)) = some (acc, []) := by
      have hs : opTrace H t0 (hdr ++ rootOps P core ++ fullOps P 0 core.slots)
          = opTrace H t0 (hdr ++ rootOps P core)
            ++ opTrace H (runOps H t0 (hdr ++ rootOps P core)) (fullOps P 0 core.slots) :=
        opTrace_append H t0 (hdr ++ rootOps P core) (fullOps P 0 core.slots)
      rw [hs, TRd.bnd_def, tRoot_trace H P core hdr t0 _]
      exact hrd
    unfold tAccRd
    rw [hfinal]
    rfl
  · cases h

end Read

/-- **`hRd`, for every block shape** (L28-2): on an accepting slot phase the reader of the verifier's own trace up to
the slots' end returns the verifier's accumulator. -/
theorem accRd_slotTrace {L : ℕ} (P : BlockParams) (hdrLen : ℕ) (key : Option Dig) (domain : List UInt8)
    (hd : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2) (G : QB L → Dig) (o : List Op × Core)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (h : SlotsAcc key domain P hdrLen G o bga rs acc) :
    tAccRd P hdrLen (Link.slotTrace P key domain G o) = acc := by
  obtain ⟨hlen, -, hcan, hsh, t', hbs⟩ := h
  rw [← hlen]
  exact tAccRd_trace (liftH G) P o.2 o.1 (Tr.newKeyed (liftH G) domain key) bga rs acc t' hcan hsh.1 hd hbs

/-! ## The claims' counts -/

/-- How many of a definition's private tables sit in commitment `cm`. -/
def cmCount (cm : Cm) : List Tab → ℕ
  | [] => 0
  | .priv p :: ts => (if p.cm = cm then 1 else 0) + cmCount cm ts
  | .eq _ _ :: ts => cmCount cm ts
  | .pub _ :: ts => cmCount cm ts

theorem push_get_length (c : Claims4) (cm cm' : Cm) (z : ZClaim) :
    ((c.push cm z).get cm').length = (c.get cm').length + (if cm = cm' then 1 else 0) := by
  cases cm <;> cases cm' <;> simp [Claims4.push, Claims4.get]

/-- A slot adds one claim per private table, to the table's commitment. -/
theorem slotClaims_length (P : BlockParams) (rho es terms : List Fp2) (cm : Cm) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Claims4),
      ((slotClaims P rho es terms ts k cl).get cm).length = (cl.get cm).length + cmCount cm ts
  | [], _, _ => rfl
  | .priv p :: ts, k, cl => by
    show ((slotClaims P rho es terms ts (k + 1) (cl.push p.cm (buildClaim P p (claimPoint p rho) (oneMinusProd es)
      (maskCoef es p.extRound) (terms.getD k Fp2.zero)))).get cm).length
        = (cl.get cm).length + ((if p.cm = cm then 1 else 0) + cmCount cm ts)
    rw [slotClaims_length P rho es terms cm ts (k + 1), push_get_length, Nat.add_assoc]
  | .eq _ _ :: ts, k, cl => slotClaims_length P rho es terms cm ts k cl
  | .pub _ :: ts, k, cl => slotClaims_length P rho es terms cm ts k cl

/-- `f j + f (j + 1) + … + f (j + m − 1)`. -/
def sumFrom (f : ℕ → ℕ) : ℕ → ℕ → ℕ
  | _, 0 => 0
  | j, m + 1 => f j + sumFrom f (j + 1) m

section Counts

variable (H : HIn → Dig)

/-- **The slot loop's claim counts**: when every definition of slot `k` has `cnt k` private tables in `cm`, the loop
adds `cnt j + … + cnt (j + m − 1)` claims to `cm`. -/
theorem slotsLoop_claims (P : BlockParams) (b g a : Fp2) (cm : Cm) (cnt : ℕ → ℕ)
    (hdef : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      cmCount cm df.tabs = cnt k) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr), slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') →
      (acc'.claims.get cm).length = (acc.claims.get cm).length + sumFrom cnt j sps.length
  | [], recs, j, acc, t, recs', acc', t', h => by
    simp only [slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, -⟩ := h
    rfl
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', h => by
    simp only [slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, vals, rhoFull, hdf, -, -, -, -, -, -, hacc0⟩ :=
        slotStep_ok_terminal H P j _ sp0 acc t r0 acc0 t0 hstep
      have ih := slotsLoop_claims P b g a cm cnt hdef sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' h
      have h1 : (acc0.claims.get cm).length = (acc.claims.get cm).length + cnt j := by
        rw [hacc0, slotAcc_claims, slotClaims_length, hdef j _ _ df hdf]
      rw [ih, h1, List.length_cons]
      show _ = _ + (cnt j + sumFrom cnt (j + 1) sps.length)
      omega

/-- **The block's claim counts**: an accepting slot phase leaves `cnt 0 + … + cnt (slots − 1)` claims on `cm`. -/
theorem blockSlots_claims (P : BlockParams) (core : Core) (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (acc : Acc) (t' : Tr) (cm : Cm) (cnt : ℕ → ℕ)
    (hdef : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      cmCount cm df.tabs = cnt k)
    (hsh : core.slots.length = P.geom.slots.length) (h : blockSlots H P core t = .ok (bga, rs, acc, t')) :
    (acc.claims.get cm).length = sumFrom cnt 0 P.geom.slots.length := by
  rw [blockSlots_eq] at h
  split at h
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, hres⟩ := h
    subst hres
    have h1 := slotsLoop_claims H P _ _ _ cm cnt hdef core.slots [] 0 {} _ rs acc t' hloop
    have h0 : ((({} : Acc).claims).get cm).length = 0 := by cases cm <;> rfl
    rw [h1, h0, hsh, Nat.zero_add]
  · cases h

end Counts

/-- **`hcnt`, from `define`'s commitment schedule** (L22-2, L28-3): when every definition of slot `k` has `aC k`
private tables in `A` and `hC k` in `H`, an accepting slot phase gives `A` exactly `Σ aC` claims and `H`, with its
LogUp sum claim, `Σ hC + 1`. -/
theorem hcnt_of_define {L : ℕ} (P : BlockParams) (hdrLen : ℕ) (key : Option Dig) (domain : List UInt8)
    (aC hC : ℕ → ℕ)
    (hdefA : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      cmCount .a df.tabs = aC k)
    (hdefH : ∀ (k : ℕ) (hist : Hist) (dr : List Fp2) (df : SlotDef), P.define k hist dr = .ok df →
      cmCount .h df.tabs = hC k)
    (G : QB L → Dig) (o : List Op × Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (h : SlotsAcc key domain P hdrLen G o bga rs acc) :
    acc.claims.a.length = sumFrom aC 0 P.geom.slots.length
      ∧ (acc.claims.h ++ [P.logupSumClaim]).length = sumFrom hC 0 P.geom.slots.length + 1 := by
  obtain ⟨-, -, -, hsh, t', hbs⟩ := h
  refine ⟨blockSlots_claims (liftH G) P o.2 _ bga rs acc t' .a aC hdefA hsh.1 hbs, ?_⟩
  rw [List.length_append, List.length_singleton]
  exact congrArg (· + 1) (blockSlots_claims (liftH G) P o.2 _ bga rs acc t' .h hC hdefH hsh.1 hbs)

end ZK60.Exec.Block
