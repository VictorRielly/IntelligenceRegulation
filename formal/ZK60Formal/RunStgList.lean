/-
D63 lane L53 (2026-11-10), part 1: **the stage parts' sub-protocol lists** (deliverable 1; finding L50-1).

The kinds data `rkData` lists, part by part, the sumcheck slots (`sls`), the define draws of four define kinds (`r0`,
`r1`, `h0`, `h1`) and the LogUp runs (`lu`). The block parts' lists are L16's and L21's (lanes L46, L50); the two stage
parts' (`base 0`: stage IN-C; `base (Lb + 1)`: stage OUT-C) were a free choice (finding L50-1). This file makes the one
choice that matches the code's stage verifiers (`stage_in_c::verify`, `stage_out_c::verify`: the frame, `A`, `M`, the
head's `m` challenges, `H`, then `run_stage_slot` per slot: `define`'s draws, `pb-slot`, `c`, `pb-scalar`, the
sumcheck, `pb-term`):

* `sls`: EVERY slot of the stage, in order (`stgSchedX`: IN-C's 4, OUT-C's 8), each at its window on the run's
  transcript (`stgS`: before slot `0` the stage's header, its head of `7 + m` operations and the slot's own
  `draws + 3`); its statement read off the trace (L15's `tSeenS`), with the claimed sum the verifier's (`stgClaim`: the
  scalar plus the hosted scalars times their coefficients, the stage's hosting as data `hostOf`) and the slot polynomial
  over the extracted tables a parameter (as L50's `Fsl` for the blocks);
* `r0`: the define draws of every slot that draws (`stgDefs`: IN-C's slots 0, 1, 2; OUT-C's 0, 2, 4, 5, 6), each at its
  window (`stgDefPos`), with Schwartz–Zippel's state on a polynomial of the draws over the extracted tables (L21's form,
  the history read by `tHistS`);
* `lu`: the head's `m` challenges as ONE squeeze run (`stgLkSq`: IN-C `β, γ, α, r_emb`, `m = 3 + clog2 d_pad`; OUT-C
  `γ, α`, `m = 2`), at the first head squeeze;
* `r1`, `h0`, `h1`: empty.

PROVED here: the numbers (`stg_len_win`: slot `k`'s window is its define draws' window plus `draws k + 3`); the windows
are where the code's operations are (`stg_ops_slot`: on the stage's operations `frame ++ stageRootOps ++ fullOps`, the
operations the run's transcript is the trace of by lanes L29, L34, L45, the define window is the first of slot `k`'s
draws and the slot window the first of its rounds; `stg_ops_head`: the LogUp window is the first head challenge); the
lists' side conditions that do not depend on the polynomials (`stgSlotX_cut`, `stgDefSq_cut`, `stgLkSq_cut`,
`stgDefSq_rbr`); the kinds data's stage parts are `base 0`'s and `base (Lb + 1)`'s lists (`stg_rxPs_0`,
`stg_rxPs_out`). CHECKED against a real classifier receipt by `RunStgCheck.lean` (not imported).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveHal

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The numbers: windows and counts (no field) -/

section Num

/-- **Stage slot `k`'s interstitial count**: before slot `0`, the stage's header (`hdrLen`: the run before the part and
the stage's frame), its head (`7 + m`: `A`'s three absorbs, `M`, the `m` challenges, `H`'s three) and the slot's own
`draws k + 3` (`define`'s draws, `pb-slot`, `c`, `pb-scalar`); after slot `0`, the previous slot's `pb-term` and its own
`draws k + 3`. A block's is the instance `m = 3` (L16's `blockSlotX`). -/
def stgS (P : Block.BlockParams) (m hdrLen k : ℕ) : ℕ := (if k = 0 then hdrLen + (7 + m) else 1) + (P.draws k + 3)

/-- Stage slot `k`'s rounds (`main + ext`). -/
def stgN (P : Block.BlockParams) (k : ℕ) : ℕ := (Block.slotShape P k).1 + (Block.slotShape P k).2.1

/-- The operations of stage slots `0 … k − 1`, the stage's header and head included. -/
def stgLen (P : Block.BlockParams) (m hdrLen k : ℕ) : ℕ :=
  ((List.range k).map (fun j => stgS P m hdrLen j + 2 * stgN P j)).sum

/-- **The window of stage slot `k`'s define draws**: after the header, the head and the whole slots before `k`. A
block's is the instance `m = 3` (L21's `defPos`). -/
def stgDefPos (P : Block.BlockParams) (m hdrLen k : ℕ) : ℕ := hdrLen + (7 + m) + Block.defOff P 0 k

/-- **The slots that draw** (`draws k > 0`), in order: their `define` draws are the stage's define sub-protocols. -/
def stgDrawing (P : Block.BlockParams) : List ℕ := (List.range P.geom.slots.length).filter (fun k => decide (0 < P.draws k))

theorem stg_defOff_snoc (P : Block.BlockParams) :
    ∀ (n j : ℕ), Block.defOff P j (n + 1) = Block.defOff P j n + (P.draws (j + n) + 4 + 2 * stgN P (j + n))
  | 0, j => by simp [Block.defOff, stgN]
  | n + 1, j => by
    have ih := stg_defOff_snoc P n (j + 1)
    rw [Block.defOff, ih, Block.defOff, show j + 1 + n = j + (n + 1) by omega]
    omega

theorem stgLen_succ (P : Block.BlockParams) (m hdrLen k : ℕ) :
    stgLen P m hdrLen (k + 1) = stgLen P m hdrLen k + (stgS P m hdrLen k + 2 * stgN P k) := by
  simp [stgLen, List.range_succ, List.sum_append]

/-- **Slot `k`'s window is its define draws' window plus `draws k + 3`** (`define`'s draws, `pb-slot`, `c`,
`pb-scalar`): the two lists' windows agree with each other. -/
theorem stg_len_win (P : Block.BlockParams) (m hdrLen : ℕ) :
    ∀ k, stgLen P m hdrLen k + stgS P m hdrLen k = stgDefPos P m hdrLen k + (P.draws k + 3)
  | 0 => by simp [stgLen, stgS, stgDefPos, Block.defOff]
  | k + 1 => by
    have ih := stg_len_win P m hdrLen k
    have hS : stgS P m hdrLen (k + 1) = 1 + (P.draws (k + 1) + 3) := by simp [stgS]
    rw [stgLen_succ, hS, stgDefPos, stg_defOff_snoc P k 0, Nat.zero_add]
    simp only [stgDefPos] at ih
    omega

end Num

/-! ## The stage's operations: where the windows are -/

section Ops

/-- **Stage slot `k`'s operations.** The stage's operations from its frame on (the frame, the head, the slots: what
lanes L29, L34 and L45 PROVED the run's transcript at the stage is the trace of) are the operations up to slot `k`'s
draws (`stgDefPos` of them, the frame's length being the header's), then its `define` draws (squeezes), `pb-slot`, `c`,
`pb-scalar`, its rounds (an `sc-round` absorb and a squeeze each), `pb-term`, and the later slots. -/
theorem stg_ops_slot (P : Block.BlockParams) (m : ℕ) (frame : List Op) (core : Block.Core) (k : ℕ)
    (q : Block.SlotProof) (hq : core.slots[k]? = some q)
    (hr : ∀ i q', core.slots[i]? = some q' → q'.rounds.length = stgN P i) :
    ∃ X : List Op, X.length = stgDefPos P m frame.length k
      ∧ frame ++ (StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)
        = X ++ (Block.drawOps (P.draws k) ++ [.absorb Block.labPbSlot (le64 (UInt64.ofNat k)), .squeeze,
          .absorb Block.labPbScalar ([q.scalar].flatMap Fp2.toBytes)] ++ scOps q.rounds ++ [Block.termOp q]
          ++ Block.fullOps P (k + 1) (core.slots.drop (k + 1))) := by
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hqk : core.slots[k] = q := (List.getElem?_eq_some_iff.mp hq).2
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hdrop : core.slots.drop k = q :: core.slots.drop (k + 1) := by rw [List.drop_eq_getElem_cons hk, hqk]
  refine ⟨frame ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k), ?_, ?_⟩
  · rw [List.length_append, List.length_append, StageFS.stageRootOps_length,
      Block.fullOps_length P 0 _ (fun i sp hsp => by
        rw [Nat.zero_add]
        rw [List.getElem?_take] at hsp
        split_ifs at hsp
        exact hr i sp hsp), hlenk]
    rfl
  · conv_lhs => rw [← List.take_append_drop k core.slots]
    rw [Block.fullOps_append, hlenk, Nat.zero_add, hdrop]
    simp only [Block.fullOps, Block.slotPreOps, List.append_assoc]

/-- **The stage's head.** The stage's operations from its frame on are the frame and `A`'s and `M`'s four absorbs
(`frame.length + 4` operations), then the head's `m` challenges (squeezes), `H`'s three absorbs, and the rest. -/
theorem stg_ops_head (P : Block.BlockParams) (m : ℕ) (frame : List Op) (core : Block.Core) (rest : List Op) :
    frame ++ (StageFS.stageRootOps P core m ++ rest)
        = (frame ++ Block.rootOpsA P core) ++ (Block.drawOps m ++ (Block.rootOpsH P core ++ rest))
      ∧ (frame ++ Block.rootOpsA P core).length = frame.length + 4 := by
  refine ⟨by simp [StageFS.stageRootOps, List.append_assoc], ?_⟩
  rw [List.length_append]
  rfl

end Ops

/-! ## The lists -/

section Lists

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **The cuts a header shows**: at each position, the prover's log cut at what the header absorbs there (nothing where
it absorbs nothing). Every extraction of the code reads the log this way (L16's cuts, L22's `colX`, L51's `colXM`). -/
def stgCuts (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (hdr : List (TItem × Dig)) :
    ℕ → List (QB L × Dig) :=
  fun i => Block.cutO absOf (Block.absAt hdr i) Lg

theorem stgCuts_cutEq {absOf : QB L → Option (List UInt8)} {P P' : List (QB L × Dig)} {hdr : List (TItem × Dig)}
    (h : CutEq absOf hdr P P') : stgCuts absOf P hdr = stgCuts absOf P' hdr :=
  funext h

/-- **A stage slot's claimed sum from what the trace shows** (L9's `run_slot`, as the stage verifier runs it): the
slot's scalar plus, for each slot `j` it hosts, slot `j`'s scalar times the coefficient at index `i` of its own draws
(`hostOf k` lists the pairs `(j, i)`: IN-C hosts nothing; OUT-C's TZC hosts SS with `ν`, LZC hosts PD with `ν`). -/
def stgClaim (hostOf : ℕ → List (ℕ × ℕ)) (k : ℕ) (sn : StageFS.SeenS) : Fp2 :=
  match Block.hostedSum ((sn.2.take k).map (fun v => Fp2.fromBytes v.2.2))
      (Fp2.fromBytes (sn.2.getD k ([], Fp2.zero, [])).2.2)
      ((hostOf k).map (fun x => (x.1, (sn.2.getD k ([], Fp2.zero, [])).1.getD x.2 Fp2.zero))) with
  | .ok c => c
  | .error _ => Fp2.zero

/-- **Stage slot `k` as a slot of the kinds data**: its window (`stgS`), its degree and rounds the stage's, its
statement read off the trace before its rounds: the slot polynomial `F` (over the cuts the header shows, at what the
trace shows), and the claimed sum the verifier hands its sumcheck (`stgClaim`). -/
def stgSlotX (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) : SlotX K L where
  s := stgS P m hdrLen k
  d := (Block.slotShape P k).2.2
  n := stgN P k
  stmt Lg τ :=
    match StageFS.tSeenS P hdrLen m k τ with
    | some (sn, _) => (F (stgCuts absOf Lg τ) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- **The stage's slots**: one per slot of the stage's schedule, in order. -/
def stgSchedX (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) : List (SlotX K L) :=
  (List.range P.geom.slots.length).map (stgSlotX P m hdrLen hostOf absOf F)

/-- What slot `k`'s `define` sees, read off the trace before its draws: the head's challenges and the earlier slots'
draws (L21's `tHistD` with the stage's head). -/
def tHistS (P : Block.BlockParams) (hdrLen m k : ℕ) : Block.TRd (List Fp2 × List (List Fp2)) :=
  Block.TRd.bnd (StageFS.tRootS hdrLen m) fun ch => Block.TRd.bnd (Block.tSlots P 0 k) fun vs =>
    Block.TRd.ret (ch, vs.map (·.1))

/-- **Stage slot `k`'s define draws as a squeeze run**: its window `stgDefPos`, its `draws k` squeezes, its state
Schwartz–Zippel's for the polynomial `Φ` of the draws (over the cuts the header shows, at what `define` sees); a header
that does not parse is never doomed (L21's `defSq` with the stage's head). -/
def stgDefSq (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqX K L where
  a := stgDefPos P m hdrLen k
  n := P.draws k
  e := dg k
  St Lg hdr τ :=
    match tHistS P hdrLen m k hdr with
    | some (h, _) => szSt (Φ (stgCuts absOf Lg hdr) k h) τ
    | none => True

/-- **The stage's define draws**: one per slot that draws, in order. -/
def stgDefs (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) : List (SqX K L) :=
  (stgDrawing P).map (stgDefSq P m hdrLen absOf Φ dg)

/-- **The stage's head as its LogUp run**: its window right after `A`'s and `M`'s absorbs (`hdrLen + 4`), its `m`
squeezes, its state a function `Λ` of the cuts the header shows and the challenges. -/
def stgLkSq (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop) : SqX K L where
  a := hdrLen + 4
  n := m
  e := e
  St Lg hdr τ := Λ (stgCuts absOf Lg hdr) τ

/-! ### Their side conditions that do not depend on the polynomials -/

omit [Algebra GF K] in
/-- A stage slot's statement reads the log only through the cuts the header shows (`RtKData.Valid.slCut`). -/
theorem stgSlotX_cut (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) :
    CutReads absOf (stgSlotX P m hdrLen hostOf absOf F k).stmt := by
  intro P1 P2 hdr h
  show (match StageFS.tSeenS P hdrLen m k hdr with
    | some (sn, _) => (F (stgCuts absOf P1 hdr) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero)) = (match StageFS.tSeenS P hdrLen m k hdr with
    | some (sn, _) => (F (stgCuts absOf P2 hdr) k sn, stgClaim hostOf k sn)
    | none => (fun _ => 0, Fp2.zero))
  rw [stgCuts_cutEq h]

omit [Algebra GF K] in
/-- A stage define draw's state reads the log only through the cuts the header shows (`RkSqOk`'s `SqCut`). -/
theorem stgDefSq_cut (P : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) : SqCut absOf (stgDefSq P m hdrLen absOf Φ dg k) := by
  intro P1 P2 hdr h τr
  show (match tHistS P hdrLen m k hdr with
    | some (hh, _) => szSt (Φ (stgCuts absOf P1 hdr) k hh) τr
    | none => True) ↔ (match tHistS P hdrLen m k hdr with
    | some (hh, _) => szSt (Φ (stgCuts absOf P2 hdr) k hh) τr
    | none => True)
  rw [stgCuts_cutEq h]

omit [Field K] [Algebra GF K] in
/-- The stage's LogUp state reads the log only through the cuts the header shows. -/
theorem stgLkSq_cut (m hdrLen e : ℕ) (absOf : QB L → Option (List UInt8))
    (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop) : SqCut absOf (stgLkSq m hdrLen e absOf Λ) := by
  intro P1 P2 hdr h τr
  show Λ (stgCuts absOf P1 hdr) τr ↔ Λ (stgCuts absOf P2 hdr) τr
  rw [stgCuts_cutEq h]

omit [Algebra GF K] in
/-- **A stage define draw is round-by-round sound** (Schwartz–Zippel's, from the degree; `RkSqOk`'s `Rbr`). -/
theorem stgDefSq_rbr [Fintype K] [DecidableEq K] (P : Block.BlockParams) (m hdrLen : ℕ)
    (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P.draws k) → K) → K)
    (dg : ℕ → ℕ) (k : ℕ) (hdeg : ∀ cu h, IndDegLE (dg k) (Φ cu k h)) : (stgDefSq P m hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ mg hτ hns
  simp only [stgDefSq] at hns ⊢
  split at hns
  · exact szSt_escape _ (hdeg _ _) τ mg hτ hns
  · exact absurd trivial hns

/-! ### The slots' windows -/

omit [Algebra GF K] in
/-- The stage's slot `k` (below the slot count) is `stgSlotX … k`. -/
theorem stgSchedX_get (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ) (sl : SlotX K L) :
    (stgSchedX P m hdrLen hostOf absOf F)[k]? = some sl ↔
      k < P.geom.slots.length ∧ sl = stgSlotX P m hdrLen hostOf absOf F k := by
  simp only [stgSchedX, List.getElem?_map]
  constructor
  · intro h
    obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
    obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
    rw [List.getElem_range] at hget
    subst hget
    exact ⟨by simpa using hlt, rfl⟩
  · rintro ⟨hk, rfl⟩
    rw [List.getElem?_range hk]
    rfl

omit [Algebra GF K] in
/-- **Stage slot `k`'s window in the kinds data** (`slotsLenX` of the slots before it plus its own interstitial
count, the window `slotSubs` gives it) is its define draws' window plus `draws k + 3`: by `stg_ops_slot`, the first of
its rounds' operations. -/
theorem stg_win (P : Block.BlockParams) (m hdrLen : ℕ) (hostOf : ℕ → List (ℕ × ℕ))
    (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P k) → K) → K) (k : ℕ)
    (hk : k ≤ P.geom.slots.length) :
    slotsLenX ((stgSchedX P m hdrLen hostOf absOf F).take k) + (stgSlotX P m hdrLen hostOf absOf F k).s
      = stgDefPos P m hdrLen k + (P.draws k + 3) := by
  have htake : (stgSchedX P m hdrLen hostOf absOf F).take k
      = (List.range k).map (stgSlotX P m hdrLen hostOf absOf F) := by
    rw [stgSchedX, ← List.map_take, List.take_range, min_eq_left hk]
  rw [htake, ← stg_len_win P m hdrLen k]
  simp only [slotsLenX, List.map_map, stgLen]
  rfl

/-! ### The parts -/

/-- **A stage part's lists** (THE CHOICE of this lane, finding L50-1): the stage's slots `sls`, the define draws of its
slots that draw `defs` in the first define kind, its head as its one LogUp run `lk`, and nothing in the other three
define kinds. -/
structure StgLists (p : RkPart K L) (sls : List (SlotX K L)) (defs : List (SqX K L)) (lk : SqX K L) : Prop where
  hsls : p.sls = sls
  hr0 : p.r0 = defs
  hr1 : p.r1 = []
  hh0 : p.h0 = []
  hh1 : p.h1 = []
  hlu : p.lu = [lk]

/-- A stage part with those lists, from any part data (its `M`, openings and counts kept). -/
def stgPart (b : RkPart K L) (sls : List (SlotX K L)) (defs : List (SqX K L)) (lk : SqX K L) : RkPart K L :=
  { b with sls := sls, r0 := defs, r1 := [], h0 := [], h1 := [], lu := [lk] }

omit [Field K] [Algebra GF K] in
theorem stgPart_lists (b : RkPart K L) (sls : List (SlotX K L)) (defs : List (SqX K L)) (lk : SqX K L) :
    StgLists (stgPart b sls defs lk) sls defs lk :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

omit [Field K] [Algebra GF K] in
/-- **The kinds data's part `0` has `base 0`'s lists** (L45's `rxPs` sets only `M`, `A`, `H`). -/
theorem stg_rxPs_0 (base : ℕ → RkPart K L) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) :
    (rxPs base Lb din dblk dout 0).sls = (base 0).sls ∧ (rxPs base Lb din dblk dout 0).r0 = (base 0).r0
      ∧ (rxPs base Lb din dblk dout 0).r1 = (base 0).r1 ∧ (rxPs base Lb din dblk dout 0).h0 = (base 0).h0
      ∧ (rxPs base Lb din dblk dout 0).h1 = (base 0).h1 ∧ (rxPs base Lb din dblk dout 0).lu = (base 0).lu :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

omit [Field K] [Algebra GF K] in
/-- **The kinds data's part `Lb + 1` has `base (Lb + 1)`'s lists.** -/
theorem stg_rxPs_out (base : ℕ → RkPart K L) (Lb : ℕ) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH) :
    (rxPs base Lb din dblk dout (Lb + 1)).sls = (base (Lb + 1)).sls
      ∧ (rxPs base Lb din dblk dout (Lb + 1)).r0 = (base (Lb + 1)).r0
      ∧ (rxPs base Lb din dblk dout (Lb + 1)).r1 = (base (Lb + 1)).r1
      ∧ (rxPs base Lb din dblk dout (Lb + 1)).h0 = (base (Lb + 1)).h0
      ∧ (rxPs base Lb din dblk dout (Lb + 1)).h1 = (base (Lb + 1)).h1
      ∧ (rxPs base Lb din dblk dout (Lb + 1)).lu = (base (Lb + 1)).lu := by
  have e : rxPs base Lb din dblk dout (Lb + 1) = rxSet (base (Lb + 1)) dout := by
    simp only [rxPs, lt_irrefl, ↓reduceIte]
  rw [e]
  exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

end Lists

end ZK60.ProtocolClassify
