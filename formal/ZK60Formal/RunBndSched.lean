/-
D63 lane L56 (2026-11-10), part 1: **a block schedule whose slot polynomials also see the run's boundary data**
(the repair of finding L54-1, block level).

Lane L16's schedule `blockSchedX P hdrLen absOf F` hands each slot polynomial `F` the prover's log cut at the block's
own three roots (`A`, `M`, `H`) and those roots only. Two slots of every R13 block (`SC_IO_IN`, `SC_IO_OUT`) read the
run's boundary commitments, whose roots the run's transcript absorbs BEFORE the block's roots (in the previous part's
frame and in the block's own frame, classify_run.rs:424-428, stage_in_c.rs:422-424). So `F` gets one more argument
here: for every position `i` of the block's header (the run's transcript before the block's roots), the bytes the
header absorbs there and the log cut at their first absorption (`hdrX`). That is every root the run showed before the
block, the boundary roots among them; the statement still reads the log only through cuts at roots the header shows
(a cut reader, `blockSlotXB_cut`), so it is frozen as soon as those roots are logged.

* `HdrX`, **`hdrX`**: the header's roots and the cuts at them, position by position (nothing past the header);
* `blockSlotXB`, **`blockSchedXB`**: lane L16's slot and schedule with `F (cuts3) (roots) (hdrX) k seen`;
* `blockSchedXB_s`, `_d`, `_n`, `slotsLenX_blockSchedXB`: the shapes are lane L16's (so `hD`'s slot windows and
  degrees are unchanged); **`blockSlotXB_cut`**: every statement is a cut reader (`hD`'s `slCut`);
* `hdrX_opTrace_pre`, `hdrX_allOps`: the header's data is the same on every extension of the header's trace;
* **`ra_blk_slotsAccB`**, **`ra_blk_slots_aliveB`**: lane L50's `ra_blk_slotsAcc`, `ra_blk_slots_alive` for the new
  schedule: a block whose slot phase accepted and whose every slot meets its terminal identity
  `fin = F(cuts, roots, hdrX, k, seen)(ρ ‖ es)` has every slot alive at the end of the block's operations followed by
  ANY operations that fit.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveSl

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

namespace Block

/-! ## The header's roots and the cuts at them -/

/-- **What a block's header shows, position by position**: the bytes it absorbs at `i` and the prover's log cut at
their first absorption. -/
abbrev HdrX (L : ℕ) := ℕ → Option (List UInt8) × List (QB L × Dig)

/-- **The header's roots and cuts** (positions `< hdrLen` of the transcript `τ`; nothing past the header). -/
def hdrX {L : ℕ} (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (hdrLen : ℕ)
    (τ : List (TItem × Dig)) : HdrX L :=
  fun i => if i < hdrLen then (absAt τ i, cutO absOf (absAt τ i) Lg) else (none, [])

/-- A position of a trace's prefix reads the same on the trace of any extension. -/
theorem absAt_opTrace_pre (H : HIn → Dig) (t : Tr) (a b : List Op) (i : ℕ) (hi : i < a.length) :
    absAt (opTrace H t (a ++ b)) i = absAt (opTrace H t a) i := by
  have hl : (opTrace H t a).length = a.length := opTrace_length H t a
  unfold absAt
  rw [opTrace_append H t a b, List.getElem?_append_left (by rw [hl]; exact hi)]

/-- **The header's data is the same on every extension of the header's trace.** -/
theorem hdrX_opTrace_pre {L : ℕ} (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (H : HIn → Dig)
    (t : Tr) (a b : List Op) (hdrLen : ℕ) (ha : a.length = hdrLen) :
    hdrX absOf Lg hdrLen (opTrace H t (a ++ b)) = hdrX absOf Lg hdrLen (opTrace H t a) := by
  funext i
  by_cases hi : i < hdrLen
  · simp only [hdrX, ite_eq_left hi]
    rw [absAt_opTrace_pre H t a b i (by omega)]
  · simp only [hdrX, ite_eq_right hi]

/-- On a block's trace (its header, roots, slots, then anything) the header's data is the header's. -/
theorem hdrX_allOps {L : ℕ} (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (H : HIn → Dig)
    (t : Tr) (P : BlockParams) (hdr : List Op) (core : Core) (T : List Op) (hdrLen : ℕ) (ha : hdr.length = hdrLen) :
    hdrX absOf Lg hdrLen (opTrace H t (allOps P (hdr, core) ++ T)) = hdrX absOf Lg hdrLen (opTrace H t hdr) := by
  have e : allOps P (hdr, core) ++ T = hdr ++ (rootOps P core ++ fullOps P 0 core.slots ++ T) := by
    simp [allOps, List.append_assoc]
  rw [e]
  exact hdrX_opTrace_pre absOf Lg H t hdr _ hdrLen ha

/-! ## The schedule -/

section SchedB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **Slot `k` of the block's schedule, its polynomial over the extracted tables and the header's roots**: L16's
`blockSlotX` whose polynomial `F (the three cut logs) (the roots) (the header's roots and cuts) k (what the trace shows)`
also sees every root the run absorbed before the block (the boundary roots among them). -/
def blockSlotXB (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (k : ℕ) : SlotX K L where
  s := (if k = 0 then hdrLen + 10 else 1) + (P.draws k + 3)
  d := (slotShape P k).2.2
  n := (slotShape P k).1 + (slotShape P k).2.1
  stmt Lg τ :=
    match tSeen P hdrLen k τ with
    | some (sn, _) => (F (cuts3 absOf Lg (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf Lg hdrLen τ) k sn,
        claimOf P k sn)
    | none => (fun _ => 0, Fp2.zero)

/-- **The block's schedule over the extracted tables and the header's roots.** -/
def blockSchedXB (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    List (SlotX K L) :=
  (List.range P.geom.slots.length).map (blockSlotXB P hdrLen absOf F)

omit [Algebra GF K] in
/-- Its slots' interstitial counts are L16's. -/
theorem blockSchedXB_s (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (k : ℕ) : (blockSlotXB P hdrLen absOf F k).s = (if k = 0 then hdrLen + 10 else 1) + (P.draws k + 3) := rfl

omit [Algebra GF K] in
/-- Its slots' degrees are L16's (the shape's). -/
theorem blockSchedXB_d (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (k : ℕ) : (blockSlotXB P hdrLen absOf F k).d = (slotShape P k).2.2 := rfl

omit [Algebra GF K] in
/-- Its slots' round counts are L16's (the shape's). -/
theorem blockSchedXB_n (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (k : ℕ) : (blockSlotXB P hdrLen absOf F k).n = (slotShape P k).1 + (slotShape P k).2.1 := rfl

omit [Algebra GF K] in
/-- **Its length on the transcript is L16's** (`blockLen`), so `hD`'s slot windows read as for `blockSchedX`. -/
theorem slotsLenX_blockSchedXB (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    slotsLenX (blockSchedXB P hdrLen absOf F) = blockLen P.draws P.geom.slots hdrLen := by
  simp only [slotsLenX, blockSchedXB, blockLen, List.map_map]
  rfl

omit [Algebra GF K] in
/-- **Every statement of the schedule is a cut reader** (`RtKData.Valid`'s `slCut`): two logs cut alike at every root
the header shows give the same statement. -/
theorem blockSlotXB_cut (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (k : ℕ) : ZK60.ProtocolClassify.CutReads absOf (blockSlotXB P hdrLen absOf F k).stmt := by
  intro P1 P2 τ h
  have e3 : cuts3 absOf P1 (rootsAt hdrLen τ) = cuts3 absOf P2 (rootsAt hdrLen τ) := by
    simp only [cuts3, rootsAt, h hdrLen, h (hdrLen + 3), h (hdrLen + 7)]
  have eX : hdrX absOf P1 hdrLen τ = hdrX absOf P2 hdrLen τ := by
    funext i
    by_cases hi : i < hdrLen
    · simp only [hdrX, ite_eq_left hi, h i]
    · simp only [hdrX, ite_eq_right hi]
  show (match tSeen P hdrLen k τ with
    | some (sn, _) => (F (cuts3 absOf P1 (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf P1 hdrLen τ) k sn,
        claimOf P k sn)
    | none => (fun _ => 0, Fp2.zero)) = (match tSeen P hdrLen k τ with
    | some (sn, _) => (F (cuts3 absOf P2 (rootsAt hdrLen τ)) (rootsAt hdrLen τ) (hdrX absOf P2 hdrLen τ) k sn,
        claimOf P k sn)
    | none => (fun _ => 0, Fp2.zero))
  rw [e3, eX]

omit [Algebra GF K] in
/-- Every slot of the schedule is a cut reader. -/
theorem blockSchedXB_cut (P : BlockParams) (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K) :
    ∀ sl ∈ blockSchedXB P hdrLen absOf F, ZK60.ProtocolClassify.CutReads absOf sl.stmt := by
  intro sl hsl
  simp only [blockSchedXB, List.mem_map, List.mem_range] at hsl
  obtain ⟨k, -, rfl⟩ := hsl
  exact blockSlotXB_cut P hdrLen absOf F k

end SchedB

/-! ## A block's slots accept as the new schedule reads them -/

section BlkSlB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A BLOCK'S SLOTS MEET `RaSlotsAcc` FOR THE NEW SCHEDULE** (lane L50's `ra_blk_slotsAcc`): when the block's slot
phase accepted after the header `hdr` (`SlotsAcc`) and every slot meets its terminal identity
`fin = F(cuts, roots, the header's roots and cuts, k, seen)(ρ ‖ es)`, the slots of `blockSchedXB` at the log `Lg` meet
`RaSlotsAcc` on the block's grouped operations. -/
theorem ra_blk_slotsAccB (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams)
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → HdrX L → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hacc : SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (hterm : ∀ k r, rs[k]? = some r → r.fin.toK U = F (cuts3 absOf Lg (rootsOf core)) (rootsOf core)
      (hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)) k
      (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)) :
    ZK60.Exec.RaSlotsAcc U key domain L (slotsAt (blockSchedXB P hdrLen absOf F) Lg) G (blockOps P hdr core) := by
  obtain ⟨hhl, hhfit, hcan, hsh, t', hbs⟩ := hacc
  simp only at hhl hhfit hcan hsh hbs
  have hslen : core.slots.length = P.geom.slots.length := by
    rw [hsh.1]
  rw [blockSlots_eq] at hbs
  simp only [← runOps_append] at hbs
  split at hbs
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hbs
    obtain ⟨hbga, hres⟩ := hbs
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
    have hslot : ∀ k sl, (slotsAt (blockSchedXB P hdrLen absOf F) Lg)[k]? = some sl →
        k < core.slots.length ∧ sl = (blockSlotXB P hdrLen absOf F k).at Lg := by
      intro k sl h
      simp only [slotsAt, blockSchedXB, List.map_map, List.getElem?_map] at h
      obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
      rw [List.getElem_range] at hget
      subst hget
      exact ⟨by rw [hslen]; simpa using hlt, rfl⟩
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        ((blockSlotXB P hdrLen absOf F k).at Lg).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q))
          = (F (cuts3 absOf Lg (rootsOf core)) (rootsOf core)
              (hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)) k (seenOf bga rs k),
            r.claimed) := by
      intro k q r hq hr
      have htr := tSeen_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround bga rs hbga' hlen
        (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      have hrt : rootsAt hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)) = rootsOf core := by
        rw [List.append_assoc (hdr ++ rootOps P core)]
        exact rootsAt_trace _ _ _ _ _ _
      have hhl' : hdr.length = hdrLen := hhl
      have hX : hdrX absOf Lg hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q))
          = hdrX absOf Lg hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) := by
        rw [List.append_assoc (hdr ++ rootOps P core), List.append_assoc hdr]
        exact hdrX_opTrace_pre absOf Lg (liftH G) _ hdr _ hdr.length rfl
      simp only [SlotX.at, blockSlotXB]
      rw [← hhl', htr]
      simp only
      rw [hrt, hX]
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
    refine ⟨?_, ?_⟩
    · rw [blockOps, slotOpsFrom_length, slotsAt, List.length_map, blockSchedXB, List.length_map, List.length_range,
        hslen]
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
      · simp only [SlotX.at, blockSlotXB, List.length_append, slotPreOps_length]
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
  · cases hbs

end BlkSlB

end Block

end ZK60.Exec

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section BlkAliveB

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A BLOCK'S SLOTS ARE ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE, FOR THE NEW SCHEDULE** (lane L50's
`ra_blk_slots_alive` for `blockSchedXB`): when the block's slot phase accepted after the header `hdr` and every slot
meets its terminal identity over the extracted tables and the header's roots and cuts, every slot of
`blockSchedXB P hdrLen absOf F` is alive at the end of the trace of the block's operations followed by any operations
`T` that fit `L` bytes. -/
theorem ra_blk_slots_aliveB (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : Block.BlockParams)
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → Block.HdrX L → (k : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P k).1 + (Block.slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2 ∧ (Block.slotShape P k).2.2 < gP
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (hacc : Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (hterm : ∀ k r, rs[k]? = some r → r.fin.toK U = F (Block.cuts3 absOf Lg (Block.rootsOf core))
      (Block.rootsOf core) (Block.hdrX absOf Lg hdrLen (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)) k
      (Block.seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U))
    (T : List Op) (hT : ∀ op ∈ T, op.len ≤ L) :
    allSt W1 (slotSubs U (slotsAt (Block.blockSchedXB P hdrLen absOf F) Lg))
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T)) := by
  have hsa := Block.ra_blk_slotsAccB U key domain P hdrLen absOf F
    (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G Lg hdr core bga rs acc hacc hterm
  obtain ⟨Q0, hQ0⟩ := Block.ra_allOps_split P hdr core
  have hsl : ∀ sl ∈ slotsAt (Block.blockSchedXB P hdrLen absOf F) Lg, 1 ≤ sl.d ∧ sl.d < gP
      ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [slotsAt, Block.blockSchedXB, List.map_map, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, hk, rfl⟩ := hsl
    obtain ⟨h1, h2, h3, -⟩ := hgeom k hk
    exact ⟨h1, h2, h3⟩
  -- every operation of the block fits
  have hfitB : ∀ op ∈ Block.allOps P (hdr, core), op.len ≤ L := by
    obtain ⟨hhl, hhfit, -, hsh, t', hbs⟩ := hacc
    simp only at hhl hhfit hsh hbs
    have hslen : core.slots.length = P.geom.slots.length := hsh.1
    intro op hop
    simp only [Block.allOps, List.mem_append] at hop
    rcases hop with (hop | hop) | hop
    · exact hhfit op hop
    · exact Block.rootOps_len P core L hL81 op hop
    · refine Block.fullOps_fit P L 0 core.slots (fun i q hq => ?_) op hop
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨h1, h2, h3⟩ := hsh.2.1 i q s tt hq hs' htt
      have e1 : Block.slotShape P i = s := by
        rw [Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
      have e2 : Block.slotTerms P i = tt := by
        rw [Block.slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
      obtain ⟨-, -, hLr, hLt⟩ := hgeom i hi
      have hrl : ∀ r ∈ q.rounds, r.length = (Block.slotShape P i).2.2 + 1 := by
        rw [e1]
        exact h2
      have htl : q.terms.length = Block.slotTerms P i := by
        rw [e2]
        exact h3
      exact ⟨Block.slotPreOps_len P (0 + i) q L hL81, scOps_len L _ hLr q.rounds hrl, Block.termOp_len q _ L htl hLt⟩
  have hQT : ∀ op ∈ Q0 ++ T, op.len ≤ L := by
    intro op hop
    rcases List.mem_append.mp hop with h | h
    · exact hfitB op (by rw [hQ0]; exact List.mem_append_right _ h)
    · exact hT op h
  rw [hQ0, List.append_assoc]
  exact ra_slots_alive U hU key domain hs L hL hL64 _ hsl G _ hsa (Q0 ++ T) hQT

end BlkAliveB

end ZK60.ProtocolClassify
