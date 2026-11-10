/-
D63 lane L50 (2026-11-10), part 2: **the slots are alive at the end of any transcript that extends their accepting
verifier's trace** (the alive half of L8's `slotsWin_event`, without its false slot), and **a block's slots accept
exactly as L16's `blockWinX_slotsWin` reads them**, given each slot's terminal identity.

* `ra_opTrace_chain`: the code's trace of operations that fit `L` bytes is the chain of their items (L21's
  `cChain_trace` with the single-step parse unfolded);
* `RaSlotsAcc`: L8's `SlotsWin` without its last conjunct (per slot: its interstitial count, the fit, canonical
  rounds and claimed sum, `sumcheck::verify` accepting on the code's transcript with the caller's terminal check);
* **`ra_slots_alive`**: on `RaSlotsAcc`, EVERY slot of the run is alive (`allSt W1 (slotSubs U slots)`) at the end of
  the trace of `slotsOps o ++ Q`, for ANY later operations `Q` that fit (L8's `slot_alive` per slot);
* `ra_fullOps_split`: a block's operations are its slots' operations (as L8 reads them) followed by more operations;
* **`ra_blk_slotsAcc`**: a block whose slot phase accepted (`SlotsAcc`) and whose every slot meets its terminal identity
  `fin = F(cuts, roots, k, seen)(ρ ‖ es)` meets `RaSlotsAcc` for L16's schedule over the extracted tables
  (`blockSchedX P hdrLen absOf F` at the log `Lg`) and the block's grouped operations (`blockOps`);
* **`ra_blk_slots_alive`**: the two together: every slot of that schedule is alive at the end of the trace of the
  block's operations (`allOps`) followed by ANY operations that fit, e.g. the rest of the classify run.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunAliveRed

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The trace is the chain of its items -/

/-- **The code's trace of operations that fit is the chain of their items** (L21's `cChain_trace`, the single-step
parse unfolded: the form L8's `slot_alive` reads). -/
theorem ra_opTrace_chain (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    {L : ℕ} (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (ops : List Op) (G : QB L → Dig)
    (hfit : ∀ op ∈ ops, op.len ≤ L) :
    opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) ops
      = ((chainEncB key domain hs L hL).chainFrom G [] (liftItems L (opItems 0 ops))).map entB := by
  have hfitI : ∀ it ∈ opItems 0 ops, it.Ok ∧ it.len ≤ L := opItems_fit L hL64 0 ops hfit
  have hlen : (liftItems L (opItems 0 ops)).length = ops.length := by
    have h := congrArg List.length (liftItems_val L _ hfitI)
    rw [List.length_map, opItems_length] at h
    exact h
  rw [← cChain_trace key domain hs hL hL64 ops G hfit ops.length le_rfl]
  have hTE : (toTE (fun it : ItB L => it.1) : ItB L × Dig → TItem × Dig) = entB := rfl
  unfold cChain
  rw [List.take_of_length_le hlen.le, flatMap_stepsOne, hTE]

/-! ## A run of accepting slots is alive on every extension -/

section Slots

variable {K : Type} [Field K] [Algebra GF K]

/-- **A run of slots accepted with its terminal checks** (L8's `SlotsWin` without its false slot): per slot, its
interstitial operations (`s` of them, each within `L` bytes), canonical rounds, a canonical claimed sum, and the
executable `sumcheck::verify` accepting on the code's transcript after the operations before its rounds, with the
caller's terminal check `fin = f(rs)`. -/
def RaSlotsAcc (U : K) (key : Option Dig) (domain : List UInt8) (L : ℕ) (slots : List (Slot K)) (G : QB L → Dig)
    (o : List (List Op × List (List Fp2))) : Prop :=
  o.length = slots.length
  ∧ ∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl → o[k]? = some ok →
      ok.1.length = sl.s ∧ (∀ op ∈ ok.1, op.len ≤ L) ∧ (∀ r ∈ ok.2, ∀ a ∈ r, a.Canon)
      ∧ (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).2.Canon
      ∧ ∃ fin rs, (scVerify (liftH G) (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (slotPre o k ok))).2 sl.d sl.n ok.2 (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
              (slotPre o k ok))).1 = .ok (fin, rs)
        ∧ fin.toK U = (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1
            (fun i => (rs.getD i Fp2.zero).toK U)

/-- **EVERY SLOT OF AN ACCEPTED RUN IS ALIVE ON EVERY EXTENSION** (L8's `slotsWin_event`, its second half, with later
operations `Q` after the run): on `RaSlotsAcc`, every slot's state read off the trace of `slotsOps o ++ Q` is alive. -/
theorem ra_slots_alive (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (L : ℕ) (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (slots : List (Slot K))
    (hsl : ∀ sl ∈ slots, 1 ≤ sl.d ∧ sl.d < gP ∧ 56 + 16 * (sl.d + 1) ≤ L)
    (G : QB L → Dig) (o : List (List Op × List (List Fp2))) (hacc : RaSlotsAcc U key domain L slots G o)
    (Q : List Op) (hQ : ∀ op ∈ Q, op.len ≤ L) :
    allSt W1 (slotSubs U slots) (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotsOps o ++ Q)) := by
  obtain ⟨hlen, hall⟩ := hacc
  have hget : ∀ (k : ℕ) (ok : List Op × List (List Fp2)), o[k]? = some ok → ∃ sl, slots[k]? = some sl := by
    intro k ok h
    have hk := (List.getElem?_eq_some_iff.mp h).1
    exact ⟨_, List.getElem?_eq_getElem (l := slots) (i := k) (by omega)⟩
  have hgetO : ∀ (k : ℕ) (sl : Slot K), slots[k]? = some sl → ∃ ok, o[k]? = some ok := by
    intro k sl h
    have hk := (List.getElem?_eq_some_iff.mp h).1
    exact ⟨_, List.getElem?_eq_getElem (l := o) (i := k) (by omega)⟩
  have hfacts : ∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl → o[k]? = some ok →
      (∀ r ∈ ok.2, r.length = sl.d + 1) ∧ ok.2.length = sl.n := by
    intro k sl ok h1 h2
    obtain ⟨-, -, hrc, hcc, fin, rs, hok, hterm⟩ := hall k sl ok h1 h2
    have hsl1 := hsl sl (List.mem_of_getElem? h1)
    obtain ⟨hls, hrs, hsc⟩ := (scVerify_accept_iff U (liftH G) hU sl.d sl.n hsl1.1 hsl1.2.1
      (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).2 hcc ok.2 hrc
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))
      (sl.stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (slotPre o k ok))).1 rs).mp ⟨fin, hok, hterm⟩
    refine ⟨hls, ?_⟩
    have h3 := scAccept_length _ _ _ _ hsc
    rw [scTau_length, hrs, scChal_length, min_self] at h3
    exact h3
  have hfitAll : ∀ op ∈ slotsOps o, op.len ≤ L := by
    refine slotsOps_fit L o (fun ok hok => ?_)
    obtain ⟨k, hk⟩ := List.mem_iff_getElem?.mp hok
    obtain ⟨sl, hsl'⟩ := hget k ok hk
    exact ⟨(hall k sl ok hsl' hk).2.1,
      scOps_len L sl.d (hsl sl (List.mem_of_getElem? hsl')).2.2 ok.2 (hfacts k sl ok hsl' hk).1⟩
  have hpre_len : ∀ (k : ℕ) (sl : Slot K) (ok : List Op × List (List Fp2)), slots[k]? = some sl →
      o[k]? = some ok → (slotPre o k ok).length = slotsLen (slots.take k) + sl.s := by
    intro k sl ok h1 h2
    rw [slotPre, List.length_append, (hall k sl ok h1 h2).1]
    congr 1
    refine slotsOps_length (o.take k) (slots.take k) (by simp [hlen]) (fun i sl' ok' e1 e2 => ?_)
    rw [List.getElem?_take] at e1 e2
    split_ifs at e1 e2 with hi
    · exact ⟨(hall i sl' ok' e1 e2).1, (hfacts i sl' ok' e1 e2).2⟩
  have hfitSplit : ∀ (k : ℕ) (ok : List Op × List (List Fp2)), o[k]? = some ok → ∀ op ∈ slotPre o k ok,
      op.len ≤ L := by
    intro k ok h op hop
    exact hfitAll op (by rw [slotsOps_split o k ok h]; exact List.mem_append_left _ (List.mem_append_left _ hop))
  have hfitOQ : ∀ op ∈ slotsOps o ++ Q, op.len ≤ L := by
    intro op hop
    rcases List.mem_append.mp hop with h | h
    · exact hfitAll op h
    · exact hQ op h
  intro k c hc
  rw [slotSubs_getElem?] at hc
  obtain ⟨sl, hsl', rfl⟩ := Option.map_eq_some_iff.mp hc
  obtain ⟨ok, hok⟩ := hgetO k sl hsl'
  have hsl1 := hsl sl (List.mem_of_getElem? hsl')
  obtain ⟨-, -, hrc, hcc, hacc⟩ := hall k sl ok hsl' hok
  right
  left
  rw [ra_opTrace_chain key domain hs hL hL64 (slotsOps o ++ Q) G hfitOQ, ← hpre_len k sl ok hsl' hok,
    slotsOps_split o k ok hok, List.append_assoc (slotPre o k ok ++ scOps ok.2)]
  exact slot_alive U hU key domain hs L hL hL64 sl hsl1.1 hsl1.2.1 hsl1.2.2 (slotPre o k ok)
    (slotsOps (o.drop (k + 1)) ++ Q) ok.2 G (hfitSplit k ok hok) hrc hcc hacc

end Slots

namespace Block

/-! ## A block's operations, as its slots and more -/

/-- **A block's operations are its slots' operations, as L8 reads them, and more** (the last slot's `pb-term`, or the
header and roots when there is no slot). -/
theorem ra_fullOps_split (P : BlockParams) :
    ∀ (first : List Op) (j : ℕ) (sps : List SlotProof),
      ∃ Q0, first ++ fullOps P j sps = slotsOps (slotOpsFrom P first j sps) ++ Q0
  | first, _, [] => ⟨first, by simp [fullOps, slotOpsFrom, slotsOps]⟩
  | first, j, sp :: sps => by
    obtain ⟨Q0, h⟩ := ra_fullOps_split P [termOp sp] (j + 1) sps
    refine ⟨Q0, ?_⟩
    simp only [fullOps, slotOpsFrom, slotsOps, List.append_assoc]
    rw [← h]

/-- The block's operations up to the end of its slot loop (`allOps`) as its grouped slots' operations and more. -/
theorem ra_allOps_split (P : BlockParams) (hdr : List Op) (core : Core) :
    ∃ Q0, allOps P (hdr, core) = slotsOps (blockOps P hdr core) ++ Q0 :=
  ra_fullOps_split P (hdr ++ rootOps P core) 0 core.slots

/-! ## A block's slots accept as L16's schedule reads them -/

section BlkSl

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A BLOCK'S SLOTS MEET `RaSlotsAcc`** for L16's schedule over the extracted tables (`blockSchedX P hdrLen absOf F` at
the log `Lg`) and the block's grouped operations, when the block's slot phase accepted (`SlotsAcc`) and every slot meets
its terminal identity `fin = F(cuts, roots, k, seen)(ρ ‖ es)` (L16's `blockWinX_slotsWin`, without its false slot). -/
theorem ra_blk_slotsAcc (U : K) (key : Option Dig) (domain : List UInt8) (P : BlockParams)
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Cuts3 L → RootsO → (k : ℕ) → Seen → (Fin ((slotShape P k).1 + (slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (slotShape P k).2.2 ∧ 55 + 16 * slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Core) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc)
    (hacc : SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (hterm : ∀ k r, rs[k]? = some r → r.fin.toK U = F (cuts3 absOf Lg (rootsOf core)) (rootsOf core) k
      (seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)) :
    RaSlotsAcc U key domain L (slotsAt (blockSchedX P hdrLen absOf F) Lg) G (blockOps P hdr core) := by
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
    have hslot : ∀ k sl, (slotsAt (blockSchedX P hdrLen absOf F) Lg)[k]? = some sl →
        k < core.slots.length ∧ sl = (blockSlotX P hdrLen absOf F k).at Lg := by
      intro k sl h
      simp only [slotsAt, blockSchedX, List.map_map, List.getElem?_map] at h
      obtain ⟨k', hk', rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp hk'
      rw [List.getElem_range] at hget
      subst hget
      exact ⟨by rw [hslen]; simpa using hlt, rfl⟩
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        ((blockSlotX P hdrLen absOf F k).at Lg).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q))
          = (F (cuts3 absOf Lg (rootsOf core)) (rootsOf core) k (seenOf bga rs k), r.claimed) := by
      intro k q r hq hr
      have htr := tSeen_trace (liftH G) P core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround bga rs hbga' hlen
        (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      have hrt : rootsAt hdr.length (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ rootOps P core ++ fullOps P 0 (core.slots.take k) ++ slotPreOps P k q)) = rootsOf core := by
        rw [List.append_assoc (hdr ++ rootOps P core)]
        exact rootsAt_trace _ _ _ _ _ _
      have hhl' : hdr.length = hdrLen := hhl
      simp only [SlotX.at, blockSlotX]
      rw [← hhl', htr]
      simp only
      rw [hrt]
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
    · rw [blockOps, slotOpsFrom_length, slotsAt, List.length_map, blockSchedX, List.length_map, List.length_range,
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
      · simp only [SlotX.at, blockSlotX, List.length_append, slotPreOps_length]
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

end BlkSl

end Block

end ZK60.Exec

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section BlkAlive

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A BLOCK'S SLOTS ARE ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE.** When the block's slot phase accepted on the
code's transcript after the header `hdr` (`SlotsAcc`), and every slot meets its terminal identity over the extracted
tables (`F`, read at the log `Lg`), every slot of L16's schedule `blockSchedX P hdrLen absOf F` is alive at the end of
the trace of the block's operations (`allOps`) followed by any operations `T` that fit `L` bytes. -/
theorem ra_blk_slots_alive (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P : Block.BlockParams)
    (hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (F : Block.Cuts3 L → Block.RootsO → (k : ℕ) → Block.Seen →
      (Fin ((Block.slotShape P k).1 + (Block.slotShape P k).2.1) → K) → K)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2 ∧ (Block.slotShape P k).2.2 < gP
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (hacc : Block.SlotsAcc key domain P hdrLen G (hdr, core) bga rs acc)
    (hterm : ∀ k r, rs[k]? = some r → r.fin.toK U = F (Block.cuts3 absOf Lg (Block.rootsOf core))
      (Block.rootsOf core) k (Block.seenOf bga rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U))
    (T : List Op) (hT : ∀ op ∈ T, op.len ≤ L) :
    allSt W1 (slotSubs U (slotsAt (Block.blockSchedX P hdrLen absOf F) Lg))
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (Block.allOps P (hdr, core) ++ T)) := by
  have hsa := Block.ra_blk_slotsAcc U key domain P hdrLen absOf F
    (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G Lg hdr core bga rs acc hacc hterm
  obtain ⟨Q0, hQ0⟩ := Block.ra_allOps_split P hdr core
  have hsl : ∀ sl ∈ slotsAt (Block.blockSchedX P hdrLen absOf F) Lg, 1 ≤ sl.d ∧ sl.d < gP
      ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [slotsAt, Block.blockSchedX, List.map_map, List.mem_map, List.mem_range] at hsl
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

end BlkAlive

end ZK60.ProtocolClassify
