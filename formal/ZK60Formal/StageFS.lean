/-
D63, Lean lane L15 (2026-11-07): **the token stages' sumcheck slots under Fiat–Shamir, on the code's own stage
schedule**, read as L8's schedule of sub-protocols (`fs_code_chain_sound_sched`, `exec_sumchecks_fs_sound`,
ExecComposeFS.lean), with lane L9's executable slot loop (`slotsLoop`, ExecBlockVerify.lean) and its trace readers
(ExecBlockFS.lean) as the model.

A token stage's verifier (stage_out_c.rs `verify` :658-691, stage_out.rs `verify` :771-) is a block's `verify_core` up
to the end of its slot loop with ONE difference: the head. After any header (the run's earlier stages; the stage's own
`pb-run-stage`, `pb-run-block` absorbs), the stage absorbs the `A` root (three absorbs) and `M`, draws `m` challenges
(stage OUT-C and OUT: `γ, α`, `m = 2`; a block: `β, γ, α`, `m = 3`), absorbs the `H` root (three absorbs), and runs its
slots with `run_stage_slot` (token_io.rs:997-1135), which is `argument::run_slot` line for line: `define`'s draws,
`pb-slot`, `c`, `pb-scalar`, the sumcheck, `pb-term`. So L9's `slotsLoop` IS the stage's slot loop, with the stage's
schedule as `BlockParams` (`geom.slots`: `(main, ext, degree)`; `draws`; `define`; `kind`).

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `stageRootOps`, `stageSlots`, `stageSlots_eq`: the stage's head with `m` challenges, and the stage verifier up to the
  end of its slot loop (the head, then `slotsLoop`), as `runOps` of the head's operations;
* `tRootS`, `tRootS_trace`, `tSeenS`, `tSeenS_trace`, `claimOfS_seenOfS`: each slot's claim is a function of the code's
  trace before its rounds (the head's `m` challenges, every slot's draws, `c` and scalar), L7-2 met on the code;
* `stageSlot`, `stageSched`, `stageLen`, `StageWin`, `stageWin_slotsWin`: the stage's slots as L8's `Slot`s (each a
  `CSub` by `slotSub`: its window at a fixed position, its rounds, `RbrWide` with `d·(⌊2^128/p⌋+1)²/|Dig|`
  by `slotSub_rbr`);
* **`stage_sumchecks_fs_sound`**: a `q`-query prover gets the stage's slot phase to accept, every slot's terminal check
  holding, while SOME slot's claimed sum is false, with probability at most
  `T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ = stageLen`: one slot's bound;
* `outc_stage_len`: stage OUT-C's `ℓ` at the classifier's R1 shape is `hdrLen + 298`; with every degree `≤ 5`, L9's
  `block_bound_le` gives at most `2^-61` for `T ≤ 2^64 + 2^20`;
* `chalSub`, **`chalSub_rbr`**: the stage's OTHER challenges (the LogUp `α`, a host's `ν`, a pad fold's `ζ`, a single
  batching coefficient) as L8 sub-protocols: one round of one squeeze with no message, doomed iff the claim is false,
  alive after the round iff the claim is true or the drawn challenge is one of at most `B` bad values; `RbrWide` with
  `B·(⌊2^128/p⌋+1)²/|Dig|`. In one schedule with the slots, L8's `fs_code_chain_sound_sched` charges the largest error.

Not done here (see the lane's doc): the round-by-round states of the VECTOR draws (`τ`, the batching vector `μ`, `r_j`,
RSEL's `c`) as rounds of L8's schedule (each coordinate a round of error `1/|K|`, its state the partially evaluated
extension being nonzero), and the whole run's schedule (the stages' and the blocks' slots on the run's one transcript).
-/
import ZK60Formal.ExecBlockFS

namespace ZK60.Exec.StageFS

open ZK60.Sound ZK60.Exec ZK60.Exec.Block
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Finset

section Ops

variable (H : HIn → Dig)

/-! ## The stage's head and its slot loop -/

/-- **The stage's head**: the `A` root's three absorbs and `M`'s, the stage's `m` challenges, the `H` root's three. -/
def stageRootOps (P : BlockParams) (core : Core) (m : ℕ) : List Op :=
  rootOpsA P core ++ (drawOps m ++ rootOpsH P core)

theorem stageRootOps_length (P : BlockParams) (core : Core) (m : ℕ) : (stageRootOps P core m).length = 7 + m := by
  simp [stageRootOps, rootOpsA, rootOpsH, drawOps]
  omega

/-- **The stage's run of slots** as L8 reads it: the header and the head before slot 0, then each slot. -/
def stageOps (P : BlockParams) (m : ℕ) (hdr : List Op) (core : Core) : List (List Op × List (List Fp2)) :=
  slotOpsFrom P (hdr ++ stageRootOps P core m) 0 core.slots

theorem slotPre_stageOps (P : BlockParams) (m : ℕ) (hdr : List Op) (core : Core) (k : ℕ) (sp : SlotProof)
    (ok : List Op × List (List Fp2)) (h : core.slots[k]? = some sp) (hok : (stageOps P m hdr core)[k]? = some ok) :
    slotPre (stageOps P m hdr core) k ok
      = hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp := by
  rw [stageOps, slotPre_from P _ 0 core.slots k sp ok h hok, Nat.zero_add]

/-- **The stage verifier up to the end of its slot loop** (stage_out_c.rs:683-691): `A`, `M`, the stage's `m`
challenges, `H`, then `run_stage_slot` per slot (L9's `slotsLoop`; `define` reads the head's challenges through
`bgaOf`, e.g. `(0, γ, α)` for OUT-C). -/
def stageSlots (P : BlockParams) (m : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (core : Core) (t : Tr) :
    Except String (List Fp2 × List SlotRec × Acc × Tr) :=
  let ch := ((absorbRoot H t labA core.aRoot P.aRows P.logCols).absorb H labM core.maskRoot.toList).challengeFp2Vec H m
  match slotsLoop H P (bgaOf ch.1).1 (bgaOf ch.1).2.1 (bgaOf ch.1).2.2 [] 0 core.slots {}
      (absorbRoot H ch.2 labH core.hRoot P.hRows P.logCols) with
  | .ok r => .ok (ch.1, r)
  | .error e => .error e

theorem runOps_stageRootOps (P : BlockParams) (core : Core) (m : ℕ) (t : Tr) :
    runOps H t (stageRootOps P core m)
      = absorbRoot H ((runOps H t (rootOpsA P core)).challengeFp2Vec H m).2 labH core.hRoot P.hRows P.logCols := by
  rw [stageRootOps, runOps_append, runOps_append, runOps_drawOps]
  rfl

/-- `stageSlots` as `runOps` of the head's operations. -/
theorem stageSlots_eq (P : BlockParams) (m : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (core : Core) (t : Tr) :
    stageSlots H P m bgaOf core t =
      match slotsLoop H P (bgaOf ((runOps H t (rootOpsA P core)).challengeFp2Vec H m).1).1
        (bgaOf ((runOps H t (rootOpsA P core)).challengeFp2Vec H m).1).2.1
        (bgaOf ((runOps H t (rootOpsA P core)).challengeFp2Vec H m).1).2.2 [] 0 core.slots {}
        (runOps H t (stageRootOps P core m)) with
      | .ok r => .ok (((runOps H t (rootOpsA P core)).challengeFp2Vec H m).1, r)
      | .error e => .error e := by
  rw [runOps_stageRootOps]
  rfl

/-! ## Reading the trace -/

/-- The header (`hdrLen` entries) and the `A` / `M` absorbs skipped, the head's `m` challenges, the `H` absorbs skipped. -/
def tRootS (hdrLen m : ℕ) : TRd (List Fp2) :=
  TRd.bnd (tSkipN (hdrLen + 4)) fun _ => TRd.bnd (tChals m) fun ch => TRd.bnd (tSkipN 3) fun _ => TRd.ret ch

/-- What the trace before slot `k`'s rounds shows: the head's challenges, and per slot `0 … k` its draws, `c` and
the scalar's bytes. -/
abbrev SeenS := List Fp2 × List (List Fp2 × Fp2 × List UInt8)

/-- **The reader of the trace before slot `k`'s rounds.** -/
def tSeenS (P : BlockParams) (hdrLen m k : ℕ) : TRd SeenS :=
  TRd.bnd (tRootS hdrLen m) fun ch => TRd.bnd (tSlots P 0 k) fun vs => TRd.bnd (tSlotPre P k) fun v =>
    TRd.ret (ch, vs ++ [v])

/-- **Slot `k`'s claimed sum from what the trace shows** (L9's `claimOf` with the head's challenges read by `bgaOf`). -/
def claimOfS (P : BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (k : ℕ) (sn : SeenS) : Fp2 :=
  claimOf P k (bgaOf sn.1, sn.2)

/-- What a verified slot's record shows. -/
def seenOfS (ch : List Fp2) (rs : List SlotRec) (k : ℕ) : SeenS :=
  (ch, (rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)))

/-- The head's part of the trace reads as `stageSlots` draws its challenges. -/
theorem tRootS_trace (P : BlockParams) (core : Core) (m : ℕ) (hdr : List Op) (t : Tr) (rest : List (TItem × Dig)) :
    tRootS hdr.length m (opTrace H t (hdr ++ stageRootOps P core m) ++ rest)
      = some (((runOps H t (hdr ++ rootOpsA P core)).challengeFp2Vec H m).1, rest) := by
  have h4 : (opTrace H t (hdr ++ rootOpsA P core)).length = hdr.length + 4 := by
    rw [opTrace_length, List.length_append]
    rfl
  have h3 : ∀ t' : Tr, (opTrace H t' (rootOpsH P core)).length = 3 := fun t' => by
    rw [opTrace_length]
    rfl
  have hsplit : opTrace H t (hdr ++ stageRootOps P core m) ++ rest = opTrace H t (hdr ++ rootOpsA P core)
      ++ (opTrace H (runOps H t (hdr ++ rootOpsA P core)) (drawOps m)
        ++ (opTrace H (runOps H (runOps H t (hdr ++ rootOpsA P core)) (drawOps m)) (rootOpsH P core) ++ rest)) := by
    simp only [stageRootOps, opTrace_append, runOps_append, List.append_assoc]
  unfold tRootS
  rw [hsplit, TRd.bnd_def, tSkipN_app _ _ _ h4]
  dsimp only
  rw [TRd.bnd_def, tChals_trace]
  dsimp only
  rw [TRd.bnd_def, tSkipN_app _ _ _ (h3 _)]
  rfl

end Ops

/-- **The claim is the trace's.** -/
theorem claimOfS_seenOfS (P : BlockParams) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (ch : List Fp2) (rs : List SlotRec)
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) (hcan : ∀ r' ∈ rs, r'.scalar.Canon) (df : SlotDef)
    (hdf : P.define k (histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k)) r.draws = .ok df)
    (hcl : hostedSum ((rs.take k).map SlotRec.scalar) r.scalar df.hosted = .ok r.claimed) :
    claimOfS P bgaOf k (seenOfS ch rs k) = r.claimed :=
  claimOf_seenOf P (bgaOf ch) rs k r hr hcan df hdf hcl

/-- **The trace before slot `k`'s rounds reads as the records show** (`tSeenS` of the verifier's own trace). -/
theorem tSeenS_trace (H : HIn → Dig) (P : BlockParams) (m : ℕ) (core : Core) (hdr : List Op) (t0 : Tr) (k : ℕ)
    (sp : SlotProof) (hsp : core.slots[k]? = some sp)
    (hr : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1)
    (ch : List Fp2) (rs : List SlotRec)
    (hch : ch = ((runOps H t0 (hdr ++ rootOpsA P core)).challengeFp2Vec H m).1)
    (hrs : rs.length = core.slots.length)
    (hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
      (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)
        = preVals H P (slotTr H P (runOps H t0 (hdr ++ stageRootOps P core m)) 0 core.slots i) i q) :
    tSeenS P hdr.length m k
        (opTrace H t0 (hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp))
      = some (seenOfS ch rs k, []) := by
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hsp).1
  obtain ⟨t3, ht3⟩ : ∃ t3, t3 = runOps H t0 (hdr ++ stageRootOps P core m) := ⟨_, rfl⟩
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hsplit : opTrace H t0 (hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k sp)
      = opTrace H t0 (hdr ++ stageRootOps P core m) ++ (opTrace H t3 (fullOps P 0 (core.slots.take k))
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
  unfold tSeenS
  rw [hsplit, TRd.bnd_def, tRootS_trace H P core m hdr t0 _]
  dsimp only
  rw [TRd.bnd_def, hslots]
  dsimp only
  rw [TRd.bnd_def, hpre]
  dsimp only
  rw [TRd.ret_apply, ← hch, hW]
  rfl

/-- The lengths of the head's operations: each at most `81` bytes. -/
theorem stageRootOps_len (P : BlockParams) (core : Core) (m L : ℕ) (hL : 81 ≤ L) :
    ∀ op ∈ stageRootOps P core m, op.len ≤ L := by
  intro op hop
  simp only [stageRootOps, List.mem_append] at hop
  rcases hop with hop | hop | hop
  · exact rootOps_len P core L hL op (by simp only [rootOps, List.mem_append]; exact Or.inl hop)
  · simp only [drawOps, List.mem_replicate] at hop
    rw [hop.2]
    simp only [Op.len]
    omega
  · exact rootOps_len P core L hL op (by simp only [rootOps, List.mem_append]; exact Or.inr (Or.inr hop))

/-! ## The stage's schedule as L8's slots, and the theorem -/

section Theorem

variable {K : Type} [Field K] [Algebra GF K]

/-- **Slot `k` of the stage's schedule**: its window opens after a FIXED number of operations (the header's
`hdrLen`, the head's `7 + m` and its own `draws k + 3` before slot 0; the previous `pb-term` and its own
`draws k + 3` after), its degree and rounds are the stage's, its statement read off the trace (`tSeenS`). -/
def stageSlot (P : BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (k : ℕ) : Slot K where
  s := (if k = 0 then hdrLen + (7 + m) else 1) + (P.draws k + 3)
  d := (slotShape P k).2.2
  n := (slotShape P k).1 + (slotShape P k).2.1
  stmt τ :=
    match tSeenS P hdrLen m k τ with
    | some (sn, _) => (f k sn, claimOfS P bgaOf k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- **The stage's schedule**: one slot per slot of the stage. Each is a `CSub` of L8 (`slotSubs`). -/
def stageSched (P : BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) : List (Slot K) :=
  (List.range P.geom.slots.length).map (stageSlot P m hdrLen bgaOf f)

/-- **The stage's item count `ℓ`**, a function of the verifier's counts alone. -/
def stageLen (draws : ℕ → ℕ) (slots : List (ℕ × ℕ × ℕ)) (hdrLen m : ℕ) : ℕ :=
  ((List.range slots.length).map (fun k => (if k = 0 then hdrLen + (7 + m) else 1) + (draws k + 3)
    + 2 * ((slots.getD k (0, 0, 0)).1 + (slots.getD k (0, 0, 0)).2.1))).sum

omit [Algebra GF K] in
theorem slotsLen_stageSched (P : BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    slotsLen (stageSched P m hdrLen bgaOf f) = stageLen P.draws P.geom.slots hdrLen m := by
  simp only [slotsLen, stageSched, stageLen, List.map_map]
  rfl

/-- The slots' part of a stage segment's shape (`CoreShape`'s first two conjuncts). -/
def SlotsShape (g : Geom) (c : Core) : Prop :=
  c.slots.length = g.slots.length
  ∧ ∀ (i : ℕ) (p : SlotProof) (s : ℕ × ℕ × ℕ) (t : ℕ), c.slots[i]? = some p → g.slots[i]? = some s →
      g.terms[i]? = some t → p.rounds.length = s.1 + s.2.1 ∧ (∀ r ∈ p.rounds, r.length = s.2.2 + 1) ∧ p.terms.length = t

/-- **The prover wins against the stage's slot phase**: it outputs a header of `hdrLen` operations (each hash input of
at most `L` bytes) and a stage segment with canonical, well-shaped slots; `stageSlots` accepts on the code's transcript
after the header, every slot's terminal check `fin = f(ρ)` holds (`M` and the openings discharge it, L10), and SOME
slot's claimed sum is false for its polynomial of individual degree `≤ d`. -/
def StageWin (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (P : BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (G : QB L → Dig)
    (out : List Op × Core) : Prop :=
  out.1.length = hdrLen ∧ (∀ op ∈ out.1, op.len ≤ L) ∧ (∀ p ∈ out.2.slots, SlotCanon p) ∧ SlotsShape P.geom out.2
  ∧ ∃ ch rs acc t', stageSlots (liftH G) P m bgaOf out.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) out.1)
        = .ok (ch, rs, acc, t')
    ∧ (∀ k r, rs[k]? = some r →
        r.fin.toK U = f k (seenOfS ch rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U))
    ∧ ∃ k r, rs[k]? = some r ∧ IndDegLE (slotShape P k).2.2 (f k (seenOfS ch rs k))
        ∧ r.claimed.toK U ≠ cubeSum (f k (seenOfS ch rs k))

/-- **A win against the stage is L8's win against its schedule** (`SlotsWin`) on the stage's run of slots. -/
theorem stageWin_slotsWin (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (P : BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (out : List Op × Core)
    (hwin : StageWin U key domain L P m hdrLen bgaOf f G out) :
    SlotsWin U key domain L (stageSched P m hdrLen bgaOf f) G (stageOps P m out.1 out.2) := by
  obtain ⟨hdr, core⟩ := out
  obtain ⟨hhl, hhfit, hcan, hsh, ch, rs, acc, t', hacc, hterm, kf, rf, hrf, hdeg, hfalse⟩ := hwin
  simp only at hhl hhfit hcan hsh hacc
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [stageSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact (hgeom i (by omega)).1
    obtain ⟨rs', hrs', hlen, hall⟩ := slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hch' : ch = ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ rootOpsA P core)).challengeFp2Vec
        (liftH G) m).1 := hch.symm
    have hcanS : ∀ i q, core.slots[i]? = some q → SlotCanon q := fun i q h => hcan q (List.mem_of_getElem? h)
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (slotShape P i).1 + (slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs htt).1
      rw [this, slotShape, List.getD_eq_getElem?_getD, hs, Option.getD_some]
    have hterms : ∀ i q, core.slots[i]? = some q → q.terms.length = slotTerms P i := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs htt).2.2
      rw [this, slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall i q r' hq hi).2.1]
      exact (hcanS i q hq).1
    -- facts about slot k of the schedule
    have hslot : ∀ k sl, (stageSched P m hdrLen bgaOf f)[k]? = some sl →
        k < core.slots.length ∧ sl = stageSlot P m hdrLen bgaOf f k := by
      intro k sl h
      simp only [stageSched, List.getElem?_map] at h
      obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
      rw [List.getElem_range] at hget
      subst hget
      exact ⟨by rw [hslen]; simpa using hlt, rfl⟩
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        (stageSlot P m hdrLen bgaOf f k).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q))
          = (f k (seenOfS ch rs k), r.claimed) := by
      intro k q r hq hr
      have htr := tSeenS_trace (liftH G) P m core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround ch rs hch' hlen
        (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      have hhl' : hdr.length = hdrLen := hhl
      simp only [stageSlot]
      rw [← hhl', htr]
      simp only
      obtain ⟨-, hsc, ⟨df, hdf, hcl⟩, -⟩ := hall k q r hq hr
      rw [claimOfS_seenOfS P bgaOf ch rs k r hr hscal df (by rw [hch']; simpa [histOf] using hdf)
        (by rw [hsc]; simpa using hcl)]
    have hpre : ∀ k q ok, core.slots[k]? = some q → (stageOps P m hdr core)[k]? = some ok →
        slotPre (stageOps P m hdr core) k ok = hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k)
          ++ slotPreOps P k q := fun k q ok h1 h2 => slotPre_stageOps P m hdr core k q ok h1 h2
    have hok : ∀ k q, core.slots[k]? = some q →
        (stageOps P m hdr core)[k]? = some ((if k = 0 then hdr ++ stageRootOps P core m
          else [termOp (core.slots.getD (k - 1) q)]) ++ slotPreOps P k q, q.rounds) := by
      intro k q hq
      rw [stageOps, slotOpsFrom_get P _ 0 core.slots k q hq, Nat.zero_add]
    refine ⟨?_, ?_, ?_⟩
    · rw [stageOps, slotOpsFrom_length, stageSched, List.length_map, List.length_range, hslen]
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
      · simp only [stageSlot, List.length_append, slotPreOps_length]
        split_ifs with hk0
        · simp only [List.length_append, hhl, stageRootOps_length]
        · rfl
      · intro op hop
        simp only [List.mem_append] at hop
        rcases hop with hop | hop
        · split_ifs at hop with hk0
          · simp only [List.mem_append] at hop
            rcases hop with hop | hop
            · exact hhfit op hop
            · exact stageRootOps_len P core m L hL op hop
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
        have hT : runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
              (hdr ++ stageRootOps P core m ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)
            = runOps (liftH G) (slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
                (hdr ++ stageRootOps P core m)) 0 core.slots k) (slotPreOps P k q) := by
          rw [runOps_append, runOps_append]
          rfl
        rw [hT]
        exact hsv
    · obtain ⟨hk, -⟩ : kf < core.slots.length ∧ True :=
        ⟨by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hrf).1, trivial⟩
      obtain ⟨q, hq⟩ : ∃ q, core.slots[kf]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
      refine ⟨kf, stageSlot P m hdrLen bgaOf f kf, _, ?_, hok kf q hq, ?_⟩
      · have hk' : kf < (List.range P.geom.slots.length).length := by rw [List.length_range, ← hslen]; exact hk
        rw [stageSched, List.getElem?_map, List.getElem?_eq_getElem hk', List.getElem_range]
        rfl
      · rw [hpre kf q _ hq (hok kf q hq), hstmt kf q rf hq hrf]
        exact ⟨hdeg, hfalse⟩
  · cases hacc

/-- **Fiat–Shamir soundness of a token stage's sumcheck slots on the stage's REAL schedule** (stage OUT-C and OUT:
`m = 2`). In the random-oracle model on the hash inputs of at most `L` bytes, a prover making at most `q` queries
outputs a header of `hdrLen` operations and a stage segment. The probability that the executable `stageSlots` (the
stage verifier up to the end of its slot loop) accepts, every slot's terminal check holds, and yet SOME slot's claimed
sum (its scalar plus the hosted scalars times `define`'s coefficients, read off the trace) is false for its polynomial
`f k` of individual degree `≤ d_k` (any function of what the trace shows), is at most
`T·dmax/|K|·(1 + p/2^128)² + collBound T + collBound (T + 1)`, `T = q + ℓ + 1`, `ℓ = stageLen`: the bound of ONE slot
of the largest degree. -/
theorem stage_sumchecks_fs_sound [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (f : (k : ℕ) → SeenS → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) (dmax : ℕ) (hdp : dmax < gP)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ (slotShape P k).2.2 ≤ dmax
      ∧ 56 + 16 * ((slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (q : ℕ) (A : OC (QB L) Dig (List Op × Core)) (hA : A.Bounded q) :
    prH (fun G : QB L → Dig => StageWin U key domain L P m hdrLen bgaOf f G (A.run G))
      ≤ (((q + stageLen P.draws P.geom.slots hdrLen m + 1) * dmax : ℕ) : ℝ≥0∞) / Fintype.card K
          * (1 + (gP : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ 2
        + collBound (q + stageLen P.draws P.geom.slots hdrLen m + 1) Dig
        + collBound (q + stageLen P.draws P.geom.slots hdrLen m + 1 + 1) Dig := by
  let A' : OC (QB L) Dig (List (List Op × List (List Fp2))) := A.bind (fun out => .ret (stageOps P m out.1 out.2))
  have hA' : A'.Bounded q :=
    (hA.bind (fun out => (show (OC.ret (stageOps P m out.1 out.2) :
      OC (QB L) Dig (List (List Op × List (List Fp2)))).Bounded 0 from trivial))).mono (by simp)
  have hrun : ∀ G, A'.run G = stageOps P m (A.run G).1 (A.run G).2 := fun G => by
    simp only [A', OC.run_bind]
    rfl
  have hsl : ∀ sl ∈ stageSched P m hdrLen bgaOf f, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [stageSched, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, hk, rfl⟩ := hsl
    obtain ⟨h1, h2, h3, -⟩ := hgeom k hk
    exact ⟨h1, lt_of_le_of_lt h2 hdp, h2, h3⟩
  have hmain := exec_sumchecks_fs_sound U hU hK2 key domain hs L hL hL64 (stageSched P m hdrLen bgaOf f) dmax hsl q A'
    hA'
  rw [slotsLen_stageSched] at hmain
  refine le_trans (MeasureTheory.measure_mono ?_) hmain
  intro G hwin
  rw [Set.mem_ofPred_eq] at hwin ⊢
  rw [hrun G]
  exact stageWin_slotsWin U key domain L P m hdrLen bgaOf f (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt
    hL81 G (A.run G) hwin

/-- Stage OUT-C's slot shapes `(main, ext, degree)` at the classifier's R1 shape (every stage domain `2^12`,
`d_pad = 2^12`, `To = 2^1`; stage_out_c.rs:75-87) and its `define` draws (`τ`, `μ`, `ν`, `ζ`). -/
def outcSlotsR1 : List (ℕ × ℕ × ℕ) :=
  [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)]

def outcDrawsR1 (k : ℕ) : ℕ := [12, 0, 7, 0, 15, 23, 15, 0].getD k 0

/-- **Stage OUT-C's item count** at the classifier's R1 shape: `hdrLen + 298`. -/
theorem outc_stage_len (hdrLen : ℕ) : stageLen outcDrawsR1 outcSlotsR1 hdrLen 2 = hdrLen + 298 := by
  simp [stageLen, outcSlotsR1, outcDrawsR1, List.range_succ]

end Theorem

/-! ## The stage's other challenges as sub-protocols of L8's schedule -/

section Chal

variable {K : Type} [Field K] [Algebra GF K]

/-- The one-round protocol of a single challenge: the statement `x` (the trace before the round), alive before the
round iff `Good x`, after it iff `Good x` or the challenge is `Bad x`. -/
def chalSt (Good : List (TItem × Dig) → Prop) (Bad : List (TItem × Dig) → K → Prop)
    (x : List (TItem × Dig)) (τ : List (List UInt8 × K)) : Prop :=
  Good x ∨ ∃ e ∈ τ.head?, Bad x e.2

omit [Field K] [Algebra GF K] in
/-- **A challenge-only round is round-by-round sound**: from a false statement, at most `B` challenges revive it. -/
theorem chal_rbrSound [DecidableEq K] (Good : List (TItem × Dig) → Prop) (Bad : List (TItem × Dig) → K → Prop)
    (B : ℕ) (hB : ∀ x, ¬ Good x → EscapesWithin (Bad x) B) :
    RbrSound 1 Good (fun x τ (_ : Unit) => chalSt Good Bad x τ) (chalSt Good Bad) B where
  start x hx h := by
    rcases h with h | ⟨e, he, -⟩
    · exact hx h
    · simp at he
  round x τ m hτ hns := by
    have hτ0 : τ = [] := List.eq_nil_of_length_eq_zero (by omega)
    subst hτ0
    have hg : ¬ Good x := fun h => hns (Or.inl h)
    obtain ⟨S, hS, hmem⟩ := hB x hg
    refine ⟨S, hS, fun c hc => ?_⟩
    rcases hc with h | ⟨e, he, hb⟩
    · exact absurd h hg
    · simp only [List.nil_append, List.head?_cons, Option.mem_def, Option.some.injEq] at he
      subst he
      exact hmem c hb
  final x τ mf _ hns := hns

/-- **The stage's single challenge as a sub-protocol of L8's schedule** (a `CSub`): its window at `a`, one round of one
squeeze with no message, the challenge read by `challenge_fp2`, never released. -/
noncomputable def chalSub (U : K) (a : ℕ) (Good : List (TItem × Dig) → Prop) (Bad : List (TItem × Dig) → K → Prop)
    (B : ℕ) : CSub Dig where
  a := a
  R := ⟨1, fun _ => 1, fun _ => false, fun _ => []⟩
  ε := ((B * fibC : ℕ) : ℝ≥0∞) / Fintype.card Dig
  St hdr τ := chalSt Good Bad hdr (chalTr (fun dg => (challengeFp2Of dg).toK U) dig0 τ)
  rel _ := False

/-- **The single challenge is `RbrWide`** with `B·(⌊2^128/p⌋+1)²/|Dig|` (`rbrWide_of_rbrSound`, `card_chal_fiber_le`):
L8's `fs_code_chain_sound_sched` composes it with the stage's slots at the largest error. -/
theorem chalSub_rbr [Fintype K] [DecidableEq K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (a : ℕ) (Good : List (TItem × Dig) → Prop) (Bad : List (TItem × Dig) → K → Prop) (B : ℕ)
    (hB : ∀ x, ¬ Good x → EscapesWithin (Bad x) B) :
    RbrWide (chalSub U a Good Bad B).R.n (chalSub U a Good Bad B).R.w (chalSub U a Good Bad B).St
      (chalSub U a Good Bad B).ε :=
  rbrWide_of_rbrSound (chal_rbrSound Good Bad B hB) (fun dg => (challengeFp2Of dg).toK U) fibC
    (card_chal_fiber_le U hbij) dig0

end Chal

end ZK60.Exec.StageFS
