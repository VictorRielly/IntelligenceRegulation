/-
D63 lane L53 (2026-11-10), part 2: **the stage parts' slots, define draws and LogUp run alive at the end of any
extension of the stage's trace** (deliverable 2, the stage-level half; L50's `ra_blk_slots_alive`, `ra_def_blk`,
`ra_lk_blk` for a stage).

A stage's verifier, up to the end of its slot loop, is L15's `stageSlots`: the stage's head (`stageRootOps`: `A`, `M`,
the head's `m` challenges, `H`), then L9's `slotsLoop` under the stage's schedule `P`. The lists of `RunStgList.lean`
are written at a schedule `P0` with the same draws and slot shapes as `P` (`StgSame`: stage IN-C's schedule depends on
the head's challenges through `define` only, finding L43-6). This file proves, for ANY stage header `hdr` and core:

* `stg_tSeenS`, `stg_tHistS`, `stg_slotShape`, …: the lists' readers depend on the schedule only through its draws and
  slot shapes;
* `stgClaim_seenOfS`: on the verifier's own records, the claimed sum the lists read is the one the slot loop handed its
  sumcheck, when `define`'s hosting is the lists' (`hhost`);
* **`stg_slotsAcc`**: an accepted stage slot phase whose slots meet their terminal identities over the extracted tables
  meets L50's `RaSlotsAcc` for the lists' slots (`stgSchedX P0 …`) and the stage's grouped operations (L15's
  `stageWin_slotsWin` without its false slot, at the lists' statements);
* **`stg_slots_alive`**: hence every slot of the lists is alive at the end of the stage's trace followed by any
  operations that fit (L50's `ra_slots_alive`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgList

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## The lists read the schedule only through its draws and slot shapes -/

section Same

/-- **Two stage schedules with the same draws and slot shapes** (stage IN-C's at any two contexts; the lists' schedule
and the verifier's). -/
def StgSame (P0 P : Block.BlockParams) : Prop := P0.draws = P.draws ∧ P0.geom.slots = P.geom.slots

variable {P0 P : Block.BlockParams}

theorem stg_slotShape (h : StgSame P0 P) (k : ℕ) : Block.slotShape P0 k = Block.slotShape P k := by
  simp only [Block.slotShape, h.2]

theorem stg_stgN (h : StgSame P0 P) (k : ℕ) : stgN P0 k = stgN P k := by
  simp only [stgN, stg_slotShape h]

theorem stg_tSlotPre (h : StgSame P0 P) (j : ℕ) : Block.tSlotPre P0 j = Block.tSlotPre P j := by
  simp only [Block.tSlotPre, h.1]

theorem stg_tSlots (h : StgSame P0 P) : ∀ (m j : ℕ), Block.tSlots P0 j m = Block.tSlots P j m
  | 0, _ => rfl
  | m + 1, j => by
    simp only [Block.tSlots, stg_tSlotPre h, stg_slotShape h, stg_tSlots h m (j + 1)]

theorem stg_tSeenS (h : StgSame P0 P) (hdrLen m k : ℕ) :
    StageFS.tSeenS P0 hdrLen m k = StageFS.tSeenS P hdrLen m k := by
  simp only [StageFS.tSeenS, stg_tSlots h, stg_tSlotPre h]

theorem stg_tHistS (h : StgSame P0 P) (hdrLen m k : ℕ) : tHistS P0 hdrLen m k = tHistS P hdrLen m k := by
  simp only [tHistS, stg_tSlots h]

theorem stg_defOff (h : StgSame P0 P) : ∀ (j n : ℕ), Block.defOff P0 j n = Block.defOff P j n
  | _, 0 => rfl
  | j, n + 1 => by
    simp only [Block.defOff, stg_defOff h (j + 1) n, stg_slotShape h, h.1]

theorem stg_stgDefPos (h : StgSame P0 P) (m hdrLen k : ℕ) : stgDefPos P0 m hdrLen k = stgDefPos P m hdrLen k := by
  simp only [stgDefPos, stg_defOff h]

end Same

/-! ## The claimed sum the lists read is the verifier's -/

/-- **The claim is the trace's** (L9's `claimOf_seenOf` with the stage's hosting as data). -/
theorem stgClaim_seenOfS (hostOf : ℕ → List (ℕ × ℕ)) (ch : List Fp2) (rs : List Block.SlotRec) (k : ℕ)
    (r : Block.SlotRec) (hr : rs[k]? = some r) (hcan : ∀ r' ∈ rs, r'.scalar.Canon)
    (hcl : Block.hostedSum ((rs.take k).map Block.SlotRec.scalar) r.scalar
      ((hostOf k).map (fun x => (x.1, r.draws.getD x.2 Fp2.zero))) = .ok r.claimed) :
    stgClaim hostOf k (StageFS.seenOfS ch rs k) = r.claimed := by
  have htake : ((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).take k
      = (rs.take k).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes)) := by
    rw [← List.map_take, List.take_take, min_eq_left (Nat.le_succ k)]
  have hget : ((rs.take (k + 1)).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).getD k
      ([], Fp2.zero, []) = (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes) := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_take_of_lt (Nat.lt_succ_self k), hr]
    rfl
  have hsc : ((rs.take k).map (fun r => (r.draws, r.c, [r.scalar].flatMap Fp2.toBytes))).map
      (fun v => Fp2.fromBytes v.2.2) = (rs.take k).map Block.SlotRec.scalar := by
    rw [List.map_map]
    refine List.map_congr_left (fun r' hr' => ?_)
    simp only [Function.comp_apply, Block.flatMap_singleton_toBytes]
    exact Fp2.fromBytes_toBytes _ (hcan r' (List.mem_of_mem_take hr'))
  have hcur : Fp2.fromBytes ([r.scalar].flatMap Fp2.toBytes) = r.scalar := by
    rw [Block.flatMap_singleton_toBytes]
    exact Fp2.fromBytes_toBytes _ (hcan r (List.mem_of_getElem? hr))
  unfold stgClaim StageFS.seenOfS
  simp only
  rw [htake, hget]
  simp only
  rw [hsc, hcur, hcl]

/-! ## The stage's slots accept as the lists read them -/

section SlotsAcc

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **AN ACCEPTED STAGE SLOT PHASE MEETS `RaSlotsAcc` FOR THE LISTS' SLOTS.** When L15's `stageSlots` (the stage's
head, then L9's slot loop under the schedule `P`) accepts after the header `hdr`, `define`'s hosting is the lists'
(`hhost`), and every slot's final value is its polynomial `F` over the cuts the trace before its rounds shows
(`hterm`), the lists' slots (`stgSchedX P0 m hdr.length hostOf absOf F`, `P0` with `P`'s draws and slot shapes) and the
stage's grouped operations (`StageFS.stageOps`) meet L50's `RaSlotsAcc`. -/
theorem stg_slotsAcc (U : K) (key : Option Dig) (domain : List UInt8) (P0 P : Block.BlockParams)
    (hP : StgSame P0 P) (m : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2 ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (hL : 81 ≤ L) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Block.Core) (hhfit : ∀ op ∈ hdr, op.len ≤ L)
    (hcan : ∀ p ∈ core.slots, Block.SlotCanon p) (hsh : StageFS.SlotsShape P.geom core)
    (ch : List Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) P m bgaOf core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
      = .ok (ch, rs, acc, t'))
    (hhost : ∀ k hist dr df, P.define k hist dr = .ok df →
      df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hterm : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
      r.fin.toK U = F (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k) ++ Block.slotPreOps P k q)))
        k (StageFS.seenOfS ch rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U)) :
    RaSlotsAcc U key domain L (slotsAt (stgSchedX P0 m hdr.length hostOf absOf F) Lg) G
      (StageFS.stageOps P m hdr core) := by
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [StageFS.stageSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]; exact (hgeom i (by omega)).1
    obtain ⟨rs', hrs', hlen, hall⟩ := Block.slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hch' : ch = ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core)).challengeFp2Vec
        (liftH G) m).1 := hch.symm
    have hcanS : ∀ i q, core.slots[i]? = some q → Block.SlotCanon q := fun i q h => hcan q (List.mem_of_getElem? h)
    have hround : ∀ i q, core.slots[i]? = some q → q.rounds.length = (Block.slotShape P i).1 + (Block.slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs htt).1
      rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs, Option.getD_some]
    have hterms : ∀ i q, core.slots[i]? = some q → q.terms.length = Block.slotTerms P i := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs htt).2.2
      rw [this, Block.slotTerms, List.getD_eq_getElem?_getD, htt, Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall i q r' hq hi).2.1]
      exact (hcanS i q hq).1
    have hslot : ∀ k sl, (slotsAt (stgSchedX P0 m hdr.length hostOf absOf F) Lg)[k]? = some sl →
        k < core.slots.length ∧ sl = (stgSlotX P0 m hdr.length hostOf absOf F k).at Lg := by
      intro k sl h
      simp only [slotsAt, List.getElem?_map] at h
      obtain ⟨sx, hsx, rfl⟩ := Option.map_eq_some_iff.mp h
      obtain ⟨hk, rfl⟩ := (stgSchedX_get P0 m hdr.length hostOf absOf F k sx).mp hsx
      refine ⟨?_, rfl⟩
      rw [hslen, ← hP.2]
      exact hk
    have hstmt : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
        ((stgSlotX P0 m hdr.length hostOf absOf F k).at Lg).stmt (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k) ++ Block.slotPreOps P k q))
          = (F (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
              (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k)
                ++ Block.slotPreOps P k q))) k (StageFS.seenOfS ch rs k), r.claimed) := by
      intro k q r hq hr
      have htr := StageFS.tSeenS_trace (liftH G) P m core hdr (Tr.newKeyed (liftH G) domain key) k q hq hround ch rs
        hch' hlen (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
      obtain ⟨-, -, ⟨df, hdf, hcl⟩, -⟩ := hall k q r hq hr
      have hcl' : Block.hostedSum ((rs.take k).map Block.SlotRec.scalar) r.scalar
          ((hostOf k).map (fun x => (x.1, r.draws.getD x.2 Fp2.zero))) = .ok r.claimed := by
        have hsc : r.scalar = q.scalar := (hall k q r hq hr).2.1
        rw [Nat.zero_add] at hdf
        rw [hsc, ← hhost k _ r.draws df hdf]
        simpa using hcl
      show (match StageFS.tSeenS P0 hdr.length m k _ with
        | some (sn, _) => (F _ k sn, stgClaim hostOf k sn)
        | none => (fun _ => 0, Fp2.zero)) = _
      rw [stg_tSeenS hP, htr]
      simp only
      rw [stgClaim_seenOfS hostOf ch rs k r hr hscal hcl']
    have hpre : ∀ k q ok, core.slots[k]? = some q → (StageFS.stageOps P m hdr core)[k]? = some ok →
        slotPre (StageFS.stageOps P m hdr core) k ok = hdr ++ StageFS.stageRootOps P core m
          ++ Block.fullOps P 0 (core.slots.take k) ++ Block.slotPreOps P k q :=
      fun k q ok h1 h2 => StageFS.slotPre_stageOps P m hdr core k q ok h1 h2
    have hok : ∀ k q, core.slots[k]? = some q →
        (StageFS.stageOps P m hdr core)[k]? = some ((if k = 0 then hdr ++ StageFS.stageRootOps P core m
          else [Block.termOp (core.slots.getD (k - 1) q)]) ++ Block.slotPreOps P k q, q.rounds) := by
      intro k q hq
      rw [StageFS.stageOps, Block.slotOpsFrom_get P _ 0 core.slots k q hq, Nat.zero_add]
    refine ⟨?_, ?_⟩
    · rw [StageFS.stageOps, Block.slotOpsFrom_length, slotsAt, List.length_map, stgSchedX, List.length_map,
        List.length_range, hslen, hP.2]
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
      · simp only [SlotX.at, stgSlotX, stgS, List.length_append, Block.slotPreOps_length, hP.1]
        split_ifs with hk0
        · simp only [List.length_append, StageFS.stageRootOps_length]
        · rfl
      · intro op hop
        simp only [List.mem_append] at hop
        rcases hop with hop | hop
        · split_ifs at hop with hk0
          · simp only [List.mem_append] at hop
            rcases hop with hop | hop
            · exact hhfit op hop
            · exact StageFS.stageRootOps_len P core m L hL op hop
          · simp only [List.mem_singleton] at hop
            subst hop
            have hkm : k - 1 < core.slots.length := by omega
            have hq' : core.slots[k - 1]? = some (core.slots.getD (k - 1) q) := by
              rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hkm, Option.getD_some]
            exact Block.termOp_len _ (Block.slotTerms P (k - 1)) L (hterms _ _ hq') (hgeom (k - 1) (by omega)).2
        · exact Block.slotPreOps_len P k q L hL op hop
      · exact (hcanS k q hq).2.1
      · obtain ⟨-, -, ⟨df, -, hcl⟩, -⟩ := hall k q r hq hr
        exact Block.hostedSum_canon _ q.scalar _ _ (hcanS k q hq).1 hcl
      · obtain ⟨-, -, -, hsv⟩ := hall k q r hq hr
        simp only [Nat.zero_add] at hsv
        refine ⟨r.fin, r.rho ++ r.es, ?_, hterm k q r hq hr⟩
        have hT : runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
              (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k) ++ Block.slotPreOps P k q)
            = runOps (liftH G) (Block.slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
                (hdr ++ StageFS.stageRootOps P core m)) 0 core.slots k) (Block.slotPreOps P k q) := by
          rw [runOps_append, runOps_append]
          rfl
        rw [hT]
        show (scVerify (liftH G) r.claimed (Block.slotShape P0 k).2.2 (stgN P0 k) q.rounds _).1 = _
        rw [stg_stgN hP, stg_slotShape hP]
        exact hsv
  · cases hacc

end SlotsAcc

/-! ## The stage's slots alive at the end of any extension -/

section SlotsAlive

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **THE STAGE'S SLOTS ARE ALIVE AT THE END OF ANY EXTENSION OF ITS TRACE.** Under `stg_slotsAcc`'s hypotheses, every
slot of the lists (`stgSchedX P0 m hdr.length hostOf absOf F`) is alive at the end of the trace of the stage's
operations (the header, the head, the slots) followed by any operations `T` that fit `L` bytes. -/
theorem stg_slots_alive (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ L) (hL64 : L < 2 ^ 64) (hL81 : 81 ≤ L) (P0 P : Block.BlockParams)
    (hP : StgSame P0 P) (m : ℕ) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : (ℕ → List (QB L × Dig)) → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2 ∧ (Block.slotShape P k).2.2 < gP
      ∧ 56 + 16 * ((Block.slotShape P k).2.2 + 1) ≤ L ∧ 55 + 16 * Block.slotTerms P k ≤ L)
    (hgt : P.geom.slots.length = P.geom.terms.length) (G : QB L → Dig) (Lg : List (QB L × Dig))
    (hdr : List Op) (core : Block.Core) (hhfit : ∀ op ∈ hdr, op.len ≤ L)
    (hcan : ∀ p ∈ core.slots, Block.SlotCanon p) (hsh : StageFS.SlotsShape P.geom core)
    (ch : List Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) P m bgaOf core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
      = .ok (ch, rs, acc, t'))
    (hhost : ∀ k hist dr df, P.define k hist dr = .ok df →
      df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hterm : ∀ k q r, core.slots[k]? = some q → rs[k]? = some r →
      r.fin.toK U = F (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k) ++ Block.slotPreOps P k q)))
        k (StageFS.seenOfS ch rs k) (fun i => ((r.rho ++ r.es).getD i Fp2.zero).toK U))
    (T : List Op) (hT : ∀ op ∈ T, op.len ≤ L) :
    allSt W1 (slotSubs U (slotsAt (stgSchedX P0 m hdr.length hostOf absOf F) Lg))
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots ++ T)) := by
  have hsa := stg_slotsAcc U key domain P0 P hP m hostOf absOf F bgaOf
    (fun k hk => ⟨(hgeom k hk).1, (hgeom k hk).2.2.2⟩) hgt hL81 G Lg hdr core hhfit hcan hsh ch rs acc t' hacc hhost
    hterm
  obtain ⟨Q0, hQ0⟩ := Block.ra_fullOps_split P (hdr ++ StageFS.stageRootOps P core m) 0 core.slots
  have hsl : ∀ sl ∈ slotsAt (stgSchedX P0 m hdr.length hostOf absOf F) Lg, 1 ≤ sl.d ∧ sl.d < gP
      ∧ 56 + 16 * (sl.d + 1) ≤ L := by
    intro sl hsl
    simp only [slotsAt, stgSchedX, List.map_map, List.mem_map, List.mem_range] at hsl
    obtain ⟨k, hk, rfl⟩ := hsl
    rw [hP.2] at hk
    obtain ⟨h1, h2, h3, -⟩ := hgeom k hk
    show 1 ≤ (Block.slotShape P0 k).2.2 ∧ (Block.slotShape P0 k).2.2 < gP ∧ 56 + 16 * ((Block.slotShape P0 k).2.2 + 1) ≤ L
    rw [stg_slotShape hP]
    exact ⟨h1, h2, h3⟩
  -- every operation of the stage fits
  have hfitB : ∀ op ∈ hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots, op.len ≤ L := by
    have hslen : core.slots.length = P.geom.slots.length := hsh.1
    intro op hop
    simp only [List.mem_append] at hop
    rcases hop with (hop | hop) | hop
    · exact hhfit op hop
    · exact StageFS.stageRootOps_len P core m L hL81 op hop
    · refine Block.fullOps_fit P L 0 core.slots (fun i q hq => ?_) op hop
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨h1, h2, h3⟩ := hsh.2 i q s tt hq hs' htt
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

end SlotsAlive

/-! ## The stage's define draws and LogUp run alive at the end of any extension -/

section Ops

variable (H : HIn → Dig)

/-- **Stage slot `k`'s draws on the stage's trace** (L21's `def_window` with the stage's head): the header of its window
is the trace of the operations before it, and the entries after it start with the trace of its `challenge_fp2_vec`,
run on the transcript the whole slots before it leave. -/
theorem stg_def_window (P : Block.BlockParams) (m : ℕ) (core : Block.Core) (hdr : List Op) (t0 : Tr) (k : ℕ)
    (q : Block.SlotProof) (hq : core.slots[k]? = some q)
    (hr : ∀ i q', core.slots[i]? = some q' → q'.rounds.length = (Block.slotShape P i).1 + (Block.slotShape P i).2.1) :
    (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)).take
        (stgDefPos P m hdr.length k)
        = opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k))
      ∧ (∃ rest, (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)).drop
          (stgDefPos P m hdr.length k)
        = opTrace H (Block.slotTr H P (runOps H t0 (hdr ++ StageFS.stageRootOps P core m)) 0 core.slots k)
            (Block.drawOps (P.draws k)) ++ rest)
      ∧ stgDefPos P m hdr.length k
        ≤ (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)).length := by
  have hk : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hqk : core.slots[k] = q := (List.getElem?_eq_some_iff.mp hq).2
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hdrop : core.slots.drop k = q :: core.slots.drop (k + 1) := by rw [List.drop_eq_getElem_cons hk, hqk]
  obtain ⟨Y, hY⟩ : ∃ Y : List Op, Y = [.absorb Block.labPbSlot (le64 (UInt64.ofNat k)), .squeeze,
      .absorb Block.labPbScalar ([q.scalar].flatMap Fp2.toBytes)] ++ scOps q.rounds ++ [Block.termOp q]
      ++ Block.fullOps P (k + 1) (core.slots.drop (k + 1)) := ⟨_, rfl⟩
  have hfo : Block.fullOps P 0 core.slots
      = Block.fullOps P 0 (core.slots.take k) ++ (Block.drawOps (P.draws k) ++ Y) := by
    rw [hY]
    conv_lhs => rw [← List.take_append_drop k core.slots]
    rw [Block.fullOps_append, hlenk, Nat.zero_add, hdrop]
    simp only [Block.fullOps, Block.slotPreOps, List.append_assoc]
  obtain ⟨X, hXd⟩ : ∃ X, X = hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k) :=
    ⟨_, rfl⟩
  have hlenX : (opTrace H t0 X).length = stgDefPos P m hdr.length k := by
    show _ = hdr.length + (7 + m) + Block.defOff P 0 k
    rw [Block.opTrace_length, hXd, List.length_append, List.length_append, StageFS.stageRootOps_length,
      Block.fullOps_length P 0 _ (fun i sp hsp => by
        rw [Nat.zero_add]
        rw [List.getElem?_take] at hsp
        split_ifs at hsp
        exact hr i sp hsp), hlenk]
  have htr : opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)
      = opTrace H t0 X ++ (opTrace H (runOps H t0 X) (Block.drawOps (P.draws k))
        ++ opTrace H (runOps H (runOps H t0 X) (Block.drawOps (P.draws k))) Y) := by
    rw [hfo, ← List.append_assoc (hdr ++ StageFS.stageRootOps P core m), ← hXd, Block.opTrace_append, Block.opTrace_append]
  have hst : runOps H t0 X = Block.slotTr H P (runOps H t0 (hdr ++ StageFS.stageRootOps P core m)) 0 core.slots k := by
    rw [hXd, runOps_append]
    rfl
  refine ⟨?_, ⟨opTrace H (runOps H (runOps H t0 X) (Block.drawOps (P.draws k))) Y, ?_⟩, ?_⟩
  · rw [htr, ← hlenX, List.take_left' rfl, hXd]
  · rw [htr, ← hlenX, List.drop_left' rfl, hst]
  · rw [htr, List.length_append, hlenX]
    exact Nat.le_add_right _ _

/-- **On the stage's trace, the header of slot `k`'s draws reads as what `define` saw** (L21's `tHistD_trace` with the
stage's head): the head's challenges and the earlier records' draws. -/
theorem stg_tHistS_trace (P : Block.BlockParams) (m : ℕ) (core : Block.Core) (hdr : List Op) (t0 : Tr) (k : ℕ)
    (hk : k ≤ core.slots.length)
    (hr : ∀ i q, core.slots[i]? = some q → q.rounds.length = (Block.slotShape P i).1 + (Block.slotShape P i).2.1)
    (rs : List Block.SlotRec) (hrs : rs.length = core.slots.length)
    (hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
      r.draws = (Block.preVals H P (Block.slotTr H P (runOps H t0 (hdr ++ StageFS.stageRootOps P core m)) 0
        core.slots i) i q).1) :
    tHistS P hdr.length m k (opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k)))
      = some ((((runOps H t0 (hdr ++ Block.rootOpsA P core)).challengeFp2Vec H m).1,
          (rs.take k).map Block.SlotRec.draws), []) := by
  obtain ⟨t3, ht3⟩ : ∃ t3, t3 = runOps H t0 (hdr ++ StageFS.stageRootOps P core m) := ⟨_, rfl⟩
  have hlenk : (core.slots.take k).length = k := by rw [List.length_take]; omega
  have hsplit : opTrace H t0 (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k))
      = opTrace H t0 (hdr ++ StageFS.stageRootOps P core m) ++ opTrace H t3 (Block.fullOps P 0 (core.slots.take k)) := by
    rw [ht3, Block.opTrace_append]
  have hslots := Block.tSlots_trace H P (core.slots.take k) 0 t3 []
    (fun i q hq => by
      rw [Nat.zero_add]
      rw [List.getElem?_take] at hq
      split_ifs at hq
      exact hr i q hq)
  rw [hlenk, List.append_nil] at hslots
  have hW : (Block.walk H P t3 0 (core.slots.take k)).map (·.1) = (rs.take k).map Block.SlotRec.draws := by
    apply List.ext_getElem?
    intro i
    rw [List.getElem?_map, List.getElem?_map]
    by_cases hik : i < k
    · obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      obtain ⟨r, hr'⟩ : ∃ r, rs[i]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have hq' : (core.slots.take k)[i]? = some q := by rw [List.getElem?_take_of_lt hik, hq]
      rw [Block.walk_getElem?, hq', List.getElem?_take_of_lt hik, hr']
      simp only [Option.map_some, Option.some.injEq]
      rw [Block.slotTr_take H P t3 0 core.slots i k hik.le, Nat.zero_add, hv i q r hq hr', ← ht3]
    · have hwl : (Block.walk H P t3 0 (core.slots.take k)).length = k := by rw [Block.walk_length, hlenk]
      have h1 : (Block.walk H P t3 0 (core.slots.take k)).length ≤ i := by omega
      have h2 : (rs.take k).length ≤ i := by
        rw [List.length_take]
        omega
      rw [List.getElem?_eq_none_iff.mpr h1, List.getElem?_eq_none_iff.mpr h2]
      rfl
  unfold tHistS
  rw [hsplit, Block.TRd.bnd_def]
  rw [show opTrace H t0 (hdr ++ StageFS.stageRootOps P core m) = opTrace H t0 (hdr ++ StageFS.stageRootOps P core m)
    ++ [] by rw [List.append_nil]]
  rw [List.append_assoc, List.nil_append, StageFS.tRootS_trace H P core m hdr t0 _]
  dsimp only
  rw [Block.TRd.bnd_def, hslots]
  dsimp only
  rw [Block.TRd.ret_apply, hW]

end Ops

section SqAlive

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **A STAGE DEFINE DRAW IS ALIVE AT THE END OF ANY EXTENSION OF THE STAGE'S TRACE.** When the stage's slot phase
accepted after the header `hdr` (L15's `stageSlots` under `P`, `P0` with `P`'s draws and slot shapes), slot `k`'s define
draw in the lists (`stgDefSq P0 m hdr.length absOf Φ dg k`) is alive at the end of the stage's trace followed by any
operations `T`, provided its polynomial vanishes at the drawn challenges, over the cuts the trace before its draws shows
and at what `define` saw (`hzero`, L50's `RaDefAt` for a stage). -/
theorem stg_def_alive (U : K) (key : Option Dig) (domain : List UInt8) (P0 P : Block.BlockParams)
    (hP : StgSame P0 P) (m : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : (ℕ → List (QB L × Dig)) → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hgeom : ∀ k, k < P.geom.slots.length → 1 ≤ (Block.slotShape P k).2.2)
    (hgt : P.geom.slots.length = P.geom.terms.length)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (hdr : List Op) (core : Block.Core)
    (hsh : StageFS.SlotsShape P.geom core) (ch : List Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) P m bgaOf core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
      = .ok (ch, rs, acc, t'))
    (T : List Op) (k : ℕ) (r : Block.SlotRec) (hr : rs[k]? = some r)
    (hzero : Φ (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 (core.slots.take k)))) k
        (ch, (rs.take k).map Block.SlotRec.draws) (fun i => (r.draws.getD i.val Fp2.zero).toK U) = 0) :
    subSt W1 (sqSub U (stgDefSq P0 m hdr.length absOf Φ dg k) Lg)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots ++ T)) := by
  have hslen : core.slots.length = P.geom.slots.length := hsh.1
  rw [StageFS.stageSlots_eq] at hacc
  simp only [← runOps_append] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    have hround : ∀ i q, core.slots[i]? = some q →
        q.rounds.length = (Block.slotShape P i).1 + (Block.slotShape P i).2.1 := by
      intro i q hq
      have hi : i < P.geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs'⟩ : ∃ s, P.geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, P.geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs' htt).1
      rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs', Option.getD_some]
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape P (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hgeom i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := Block.slotsLoop_ok (liftH G) P _ _ _ core.slots [] 0 {} _ rs acc t' hd1 hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hv : ∀ i q r, core.slots[i]? = some q → rs[i]? = some r →
        r.draws = (Block.preVals (liftH G) P (Block.slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps P core m)) 0 core.slots i) i q).1 := by
      intro i q r hq hr
      have h1 := congrArg Prod.fst (hall i q r hq hr).1
      rw [Nat.zero_add] at h1
      exact h1
    have hk : k < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr).1
    obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hk⟩
    obtain ⟨hw1, ⟨rest, hw2⟩, hw3⟩ := stg_def_window (liftH G) P m core hdr (Tr.newKeyed (liftH G) domain key) k q hq
      hround
    have hhist := stg_tHistS_trace (liftH G) P m core hdr (Tr.newKeyed (liftH G) domain key) k hk.le hround rs
      (by omega) hv
    obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) (P.draws k)
      (Block.slotTr (liftH G) P (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps P core m)) 0 core.slots k)
    have hext : opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots ++ T)
        = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)
          ++ opTrace (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
            (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)) T :=
      Block.opTrace_append (liftH G) _ _ _
    have hpos : (stgDefSq P0 m hdr.length absOf Φ dg k).a = stgDefPos P m hdr.length k := by
      show stgDefPos P0 m hdr.length k = _
      rw [stg_stgDefPos hP]
    have hn : (stgDefSq P0 m hdr.length absOf Φ dg k).n = P.draws k := by
      show P0.draws k = _
      rw [hP.1]
    rw [hext]
    refine ZK60.ProtocolClassify.ra_sq_end U _ Lg _ ks' ds (rest ++ opTrace (liftH G) (runOps (liftH G)
      (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots)) T)
      (by rw [hn, h2]) (by rw [h2, h3]) ?_ ?_
    · rw [hpos, List.drop_append_of_le_length hw3, hw2, h1, List.append_assoc]
    · rw [hpos, List.take_append_of_le_length hw3, hw1]
      show (match tHistS P0 hdr.length m k _ with
        | some (hh, _) => szSt (Φ (stgCuts absOf Lg _) k hh) _
        | none => True)
      rw [stg_tHistS hP, hhist]
      simp only
      have h4' : ds.map challengeFp2Of = r.draws := by
        rw [hv k q r hq hr]
        exact h4
      have hm : ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))
          = (r.draws.map (Fp2.toK U)).map (fun c => (([] : List UInt8), c)) := by
        rw [← h4']
        simp only [List.map_map, Function.comp_def]
      have hlenr : (r.draws.map (Fp2.toK U)).length = P0.draws k := by
        rw [List.length_map, ← h4', List.length_map, h3, hP.1]
      rw [hm, szSt_full_map _ _ _ hlenr]
      have hf : (fun i : Fin (P0.draws k) => (r.draws.map (Fp2.toK U)).getD i.val 0)
          = (fun i : Fin (P0.draws k) => (r.draws.getD i.val Fp2.zero).toK U) :=
        funext (fun i => Block.getD_map_toK U _ _)
      rw [hf, hch]
      exact hzero
  · cases hacc

/-- **THE STAGE'S LOGUP RUN IS ALIVE AT THE END OF ANY EXTENSION OF THE STAGE'S TRACE.** When the stage's slot phase
accepted after the header `hdr`, the lists' LogUp run (`stgLkSq m hdr.length e absOf Λ`: the head's `m` challenges) is
alive at the end of the stage's trace followed by any operations `T`, provided its state holds at the head's challenges
over the cuts the trace before them shows (`hΛ`, L50's `RaLkAt` for a stage). -/
theorem stg_lk_alive (U : K) (key : Option Dig) (domain : List UInt8) (P : Block.BlockParams) (m e : ℕ)
    (absOf : QB L → Option (List UInt8)) (Λ : (ℕ → List (QB L × Dig)) → List (List UInt8 × K) → Prop)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (Lg : List (QB L × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec) (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) P m bgaOf core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
      = .ok (ch, rs, acc, t'))
    (T : List Op)
    (hΛ : Λ (stgCuts absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core)))
      (ch.map (fun c => (([] : List UInt8), c.toK U)))) :
    subSt W1 (sqSub U (stgLkSq m hdr.length e absOf Λ) Lg)
      (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots ++ T)) := by
  have hch : ch = ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core)).challengeFp2Vec
      (liftH G) m).1 := by
    rw [StageFS.stageSlots_eq] at hacc
    simp only [← runOps_append] at hacc
    split at hacc
    · simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
      exact hacc.1.symm
    · cases hacc
  have hops : hdr ++ StageFS.stageRootOps P core m ++ Block.fullOps P 0 core.slots ++ T = (hdr ++ Block.rootOpsA P core)
      ++ (Block.drawOps m ++ (Block.rootOpsH P core ++ Block.fullOps P 0 core.slots ++ T)) := by
    simp only [StageFS.stageRootOps, List.append_assoc]
  have hlA : (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core)).length
      = hdr.length + 4 := by
    rw [Block.opTrace_length, List.length_append]
    rfl
  obtain ⟨ks', ds, h1, h2, h3, h4⟩ := opTrace_drawOps (liftH G) m
    (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core))
  rw [hops, Block.opTrace_append, Block.opTrace_append (liftH G) _ (Block.drawOps m)]
  refine ZK60.ProtocolClassify.ra_sq_end U _ Lg _ ks' ds
    (opTrace (liftH G) (runOps (liftH G) (runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ Block.rootOpsA P core)) (Block.drawOps m)) (Block.rootOpsH P core ++ Block.fullOps P 0 core.slots ++ T))
    h2 (by rw [h2, h3]) ?_ ?_
  · show (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core) ++ _).drop
      (hdr.length + 4) = _
    rw [← hlA, List.drop_left' rfl, h1]
  · show Λ (stgCuts absOf Lg ((opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ Block.rootOpsA P core)
      ++ _).take (hdr.length + 4))) (ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U)))
    rw [← hlA, List.take_left' rfl]
    have hm : ds.map (fun d => (([] : List UInt8), (challengeFp2Of d).toK U))
        = ch.map (fun c => (([] : List UInt8), c.toK U)) := by
      rw [hch, ← h4]
      simp only [List.map_map, Function.comp_def]
    rw [hm]
    exact hΛ

end SqAlive

end ZK60.ProtocolClassify
