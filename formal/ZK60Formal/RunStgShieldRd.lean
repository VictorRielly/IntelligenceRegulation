/-
D63 lane L63 (2026-11-16), part 2: **`StgDefAtV` for the real define polynomials at every reading of a stage**
(deliverable 1, finding R1-2).

* `ssh_chalVec`, **`ssh_rd_facts`**: at a reading, every slot's functionals (`SlotFns`), its draws canonical and of the
  schedule's count, and the trace before its rounds reads as its record shows;
* `StgSlotStartAt`, **`ssh_slotStart`**: every stage slot's sumcheck state is true where its window starts, at every
  reading, when the run's slot kind has no doomed entrant (`¬ rtKsl.Dm`) and part `i`'s slots are the stage's;
* `StgHostTrueAt`: `M`'s host functionals (`acc.hostFs`) true at every reading;
* **`ssh_defAtV`**: THE REAL DEFINE POLYNOMIAL `stgΦR` VANISHES AT EVERY READING (`StgDefAtV`), from the slots' start
  states, `StgTrueAt` (the schedule the reader reads, `M`'s functionals) and, for a stage that hosts, `StgHostTrueAt`;
  the reads of the reader, the claims' semantics and `M` below the head (`VwLoc`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldDef

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section Rd

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- A challenge vector's words are canonical and as many as asked. -/
theorem ssh_chalVec (H : HIn → Dig) (n : ℕ) (t : Tr) :
    (∀ a ∈ (t.challengeFp2Vec H n).1, a.Canon) ∧ (t.challengeFp2Vec H n).1.length = n := by
  obtain ⟨ks, ds, -, -, h3, h4⟩ := opTrace_drawOps H n t
  rw [← h4]
  refine ⟨fun a ha => ?_, by rw [List.length_map, h3]⟩
  obtain ⟨d, -, rfl⟩ := List.mem_map.mp ha
  exact canon_challengeFp2Of d

/-- **What a reading of a stage shows, slot by slot**: the slots' functionals, their draws (canonical, the schedule's
count), and the trace before each slot's rounds read as its record shows. -/
theorem ssh_rd_facts (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op)
    (core : Block.Core) (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs)
    (hgt : (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t')) :
    rs.length = core.slots.length
    ∧ (∀ j q r, core.slots[j]? = some q → rs[j]? = some r →
        Block.SlotFns (Pof ch) j (Block.histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take j)) (rs.take j) q r
          acc)
    ∧ (∀ j r, rs[j]? = some r → (∀ a ∈ r.draws, a.Canon) ∧ r.draws.length = (Pof ch).draws j)
    ∧ (∀ j q, core.slots[j]? = some q → StageFS.tSeenS (Pof ch) hdrLen m j
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (hdr ++ StageFS.stageRootOps (Pof ch) core m
          ++ Block.fullOps (Pof ch) 0 (core.slots.take j) ++ Block.slotPreOps (Pof ch) j q))
        = some (StageFS.seenOfS ch rs j, []))
    ∧ (∀ r ∈ rs, r.scalar.Canon) := by
  obtain ⟨hhl, -, hcan, hsh, -, -⟩ := hrd
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  obtain ⟨hlenF, hallF⟩ := Block.ssh_stage_fns (liftH G) (Pof ch) m bgaOf core _ ch rs acc t' hacc
  have hacc2 := hacc
  rw [StageFS.stageSlots_eq] at hacc2
  simp only [← runOps_append] at hacc2
  split at hacc2
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc2
    obtain ⟨hch, hres⟩ := hacc2
    subst hres
    have hd1 : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape (Pof ch) (0 + i)).2.2 := fun i hi => by
      rw [Nat.zero_add]
      exact hd i (by omega)
    obtain ⟨rs', hrs', hlen, hall⟩ := Block.slotsLoop_ok (liftH G) (Pof ch) _ _ _ core.slots [] 0 {} _ rs acc t' hd1
      hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    have hch' : ch = ((runOps (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ Block.rootOpsA (Pof ch) core)).challengeFp2Vec (liftH G) m).1 := hch.symm
    have hround : ∀ i q, core.slots[i]? = some q →
        q.rounds.length = (Block.slotShape (Pof ch) i).1 + (Block.slotShape (Pof ch) i).2.1 := by
      intro i q hq
      have hi : i < (Pof ch).geom.slots.length := by rw [← hslen]; exact (List.getElem?_eq_some_iff.mp hq).1
      obtain ⟨s, hs⟩ : ∃ s, (Pof ch).geom.slots[i]? = some s := ⟨_, List.getElem?_eq_getElem hi⟩
      obtain ⟨tt, htt⟩ : ∃ tt, (Pof ch).geom.terms[i]? = some tt := ⟨_, List.getElem?_eq_getElem (by omega)⟩
      have := (hsh.2 i q s tt hq hs htt).1
      rw [this, Block.slotShape, List.getD_eq_getElem?_getD, hs, Option.getD_some]
    have hscal : ∀ r' ∈ rs, r'.scalar.Canon := by
      intro r' hr'
      obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hr'
      obtain ⟨q, hq⟩ : ∃ q, core.slots[i]? = some q :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hi).1)⟩
      rw [(hall i q r' hq hi).2.1]
      exact (hcan.1 q (List.mem_of_getElem? hq)).1
    refine ⟨hlenF, hallF, ?_, ?_, hscal⟩
    · intro j r hr
      have hj : j < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr).1
      obtain ⟨q, hq⟩ : ∃ q, core.slots[j]? = some q := ⟨_, List.getElem?_eq_getElem hj⟩
      have h1 := congrArg Prod.fst (hall j q r hq hr).1
      rw [Nat.zero_add] at h1
      dsimp only at h1
      rw [h1]
      exact ssh_chalVec (liftH G) _ _
    · intro j q hq
      rw [← hhl]
      exact StageFS.tSeenS_trace (liftH G) (Pof ch) m core hdr (Tr.newKeyed (liftH G) domain key) j q hq hround ch
        rs hch' hlen (fun i q' r' h1 h2 => by simpa using (hall i q' r' h1 h2).1)
  · cases hacc2

/-- **Every stage slot's sumcheck state is true where its window starts, at every reading.** -/
def StgSlotStartAt (U : K) (key : Option Dig) (domain : List UInt8) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (F : StgVw L → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ k q, core.slots[k]? = some q →
      (slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at Lg) (stgDefPos P0 m hdrLen k + (P0.draws k + 3))).St
        (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)) []

/-- **`M`'s host functionals true at every reading** (the part of `M`'s check that `StgTrueAt` leaves out: the code
checks `M` on `acc.fs ++ acc.hostFs`). -/
def StgHostTrueAt (U : K) (key : Option Dig) (domain : List UInt8) (Pof : List Fp2 → Block.BlockParams)
    (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (absOf : QB L → Option (List UInt8))
    (msv : StgVw L → List (ℕ × List Fp2) → K)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig)) : Prop :=
  ∀ hdr core ch rs, StgRd key domain L Pof m hdrLen bgaOf G τ hdr core ch rs →
    ∀ acc t', StageFS.stageSlots (liftH G) (Pof ch) m bgaOf core
        (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t') →
    ∀ k q, core.slots[k]? = some q →
      Block.MTrue U (msv (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k)
            ++ Block.slotPreOps (Pof ch) k q)))) acc.hostFs

end Rd

section Start

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)

/-- **NO DOOMED SLOT ENTRANT: EVERY STAGE SLOT STARTS FROM A TRUE CLAIM.** When part `i`'s slots are the stage's
(`hS`) and the run's slot kind has no doomed entrant among its first `n > i` parts, every stage slot's sumcheck state is
true where its window starts, at every reading. -/
theorem ssh_slotStart (n i : ℕ) (hi : i < pf.parts.length) (hin : i < n) (P0 : Block.BlockParams)
    (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2)
    (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB Lq → Option (List UInt8))
    (F : StgVw Lq → (k : ℕ) → StageFS.SeenS → (Fin (stgN P0 k) → K) → K)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hS : D.sls i = stgSchedV P0 m hdrLen hostOf absOf F)
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ) :
    StgSlotStartAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf F G lg τ := by
  intro hdr core ch rs hrd k q hq
  by_contra hn
  apply hns
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hrd.2.2.2.1.1
  have hkl : k < core.slots.length := (List.getElem?_eq_some_iff.mp hq).1
  have hk0 : k < P0.geom.slots.length := by rw [(hP ch).2, ← hslen]; exact hkl
  obtain ⟨h1, h2⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
  have hsl : (D.sls i)[k]? = some (stgSlotV P0 m hdrLen hostOf absOf F k) := by
    rw [hS]
    exact (stgSchedV_get P0 m hdrLen hostOf absOf F k _).mpr ⟨hk0, rfl⟩
  have hwin : slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s
      = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
    rw [hS, stgV_win P0 m hdrLen hostOf absOf F k hk0.le, stg_stgDefPos (hP ch), (hP ch).1]
  have hwin0 : stgDefPos P0 m hdrLen k + (P0.draws k + 3)
      = stgDefPos (Pof ch) m hdrLen k + ((Pof ch).draws k + 3) := by
    rw [stg_stgDefPos (hP ch), (hP ch).1]
  refine ⟨i, hin, slotSub U ((stgSlotV P0 m hdrLen hostOf absOf F k).at lg)
    (slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s), ?_, ?_, tRem_W1 _, ?_⟩
  · rw [ra_ksl_cs key domain hs Lq hL pf rd hL64 hv U hbij D hD i hi]
    exact List.mem_of_getElem? (by rw [rt_slotSubs_getElem?, hsl]; rfl)
  · show slotsLenX ((D.sls i).take k) + (stgSlotV P0 m hdrLen hostOf absOf F k).s ≤ τ.length
    rw [hwin]
    exact h2
  · rw [hwin, slotSub_a, h1, ← hwin0]
    exact hn

end Start

section Main

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **THE REAL STAGE DEFINE POLYNOMIAL VANISHES AT EVERY READING** (`StgDefAtV` for `stgΦR`; the premises `hDI_stg`,
`hDO_stg`): from every slot's start state (`hslot`, by `ssh_slotStart` from `¬ rtKsl.Dm`), `StgTrueAt` (the schedule
the reader reads, `M`'s functionals), `M`'s host functionals where the stage hosts (`hmH`), the reader, claims and `M`
read below the head (`VwLoc`), and the schedule's shapes. -/
theorem ssh_defAtV (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (csv : StgVw L → Block.Cm → Block.ZClaim → K)
    (Rv : StgVw L → ℕ → ℕ → K) (msv : StgVw L → List (ℕ × List Fp2) → K) (Wd : ℕ)
    (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hP : ∀ ch, StgSame P0 (Pof ch))
    (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhost2 : ∀ k, ∀ x ∈ hostOf k, hostOf x.1 = [])
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k < 64
      ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ Wd)
    (hlin : ∀ v, Block.MLin U (msv v) (Rv v) Wd)
    (nl : ℕ) (hnl : nl ≤ hdrLen + (7 + m))
    (hlP : VwLoc nl Pv) (hlC : VwLoc nl csv) (hlR : VwLoc nl Rv) (hlM : VwLoc nl msv)
    (hslot : StgSlotStartAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) G Lg τ)
    (htrue : StgTrueAt U key domain Pof m hdrLen bgaOf absOf Pv csv msv G Lg τ)
    (hmH : (∀ k, hostOf k = []) ∨ StgHostTrueAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    StgDefAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgΦR U hbij P0 Pv bgaOf csv) G Lg τ := by
  intro hdr core ch rs hrd k hk
  have hkP0 : k < P0.geom.slots.length := List.mem_range.mp (List.mem_filter.mp hk).1
  obtain ⟨-, -, hcan, hsh, ⟨acc, t', hacc⟩, -⟩ := id hrd
  have hslen : core.slots.length = (Pof ch).geom.slots.length := hsh.1
  obtain ⟨hlen, hall, hdraw, hseen, hscal⟩ :=
    ssh_rd_facts key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) (hd ch) acc t' hacc
  have hkc : k < core.slots.length := by rw [hslen, ← (hP ch).2]; exact hkP0
  obtain ⟨q, hq⟩ : ∃ q, core.slots[k]? = some q := ⟨_, List.getElem?_eq_getElem hkc⟩
  obtain ⟨r, hr⟩ : ∃ r, rs[k]? = some r := ⟨_, List.getElem?_eq_getElem (by omega)⟩
  refine ⟨r, hr, ?_⟩
  -- every window of the stage is a prefix of `τ` at a position at least `nl`
  have hwinS : ∀ j q', core.slots[j]? = some q' → ∀ {β : Type} (f : StgVw L → β), VwLoc nl f →
      f (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take j)
            ++ Block.slotPreOps (Pof ch) j q'))) = f (stgVw absOf Lg τ) := by
    intro j q' hq' β f hf
    obtain ⟨h1, -⟩ := stg_rd_slot key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) j q' hq'
    rw [← h1]
    exact vw_take absOf Lg nl _ (by unfold stgDefPos; omega) f hf τ
  have hwinD : ∀ {β : Type} (f : StgVw L → β), VwLoc nl f →
      f (stgVw absOf Lg (opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
          (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take k))))
        = f (stgVw absOf Lg τ) := by
    intro β f hf
    obtain ⟨h1, -⟩ := stg_rd_def key domain Pof m hdrLen bgaOf G τ hdr core ch rs hrd (hgt ch) k q hq
    rw [← h1]
    exact vw_take absOf Lg nl _ (by unfold stgDefPos; omega) f hf τ
  -- the schedule the reader reads, and `M`'s functionals
  obtain ⟨hPv, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  rw [hwinS k q hq Pv hlP] at hPv
  rw [hwinS k q hq msv hlM] at hMt
  show stgΦB U hbij P0 (Pv _ ch) (csv _) (bgaOf ch) ((rs.take k).map Block.SlotRec.draws) k
      (stgWords U hbij (fun i : Fin (P0.draws k) => (r.draws.getD i.val Fp2.zero).toK U)) = 0
  rw [hwinD Pv hlP, hwinD csv hlC, hPv]
  have hw : stgWords U hbij (fun i : Fin (P0.draws k) => (r.draws.getD i.val Fp2.zero).toK U) = r.draws :=
    stgWords_toK U hbij hU r.draws (hdraw k r hr).1 _ (by rw [(hdraw k r hr).2, (hP ch).1])
  rw [hw]
  refine ssh_ΦB_zero U hbij hU P0 (Pof ch) (csv (stgVw absOf Lg τ)) core (bgaOf ch) rs acc hcan hlen hall hostOf
    (hhost ch) hhost2 (msv (stgVw absOf Lg τ)) (Rv (stgVw absOf Lg τ)) Wd (hlin _) hMt ?_ ?_ k r hr
  · rcases hmH with h0 | h0
    · exact Or.inl h0
    · refine Or.inr ?_
      have h3 := h0 hdr core ch rs hrd acc t' hacc k q hq
      rwa [hwinS k q hq msv hlM] at h3
  · intro j r' hr' hg
    have hj : j < core.slots.length := by rw [← hlen]; exact (List.getElem?_eq_some_iff.mp hr').1
    obtain ⟨q', hq'⟩ : ∃ q', core.slots[j]? = some q' := ⟨_, List.getElem?_eq_getElem hj⟩
    have hjP0 : j < P0.geom.slots.length := by rw [(hP ch).2, ← hslen]; exact hj
    obtain ⟨hN0, hN64, hNW⟩ := hN j hjP0
    have hd0 : 1 ≤ (Block.slotShape P0 j).2.2 := by
      rw [stg_slotShape (hP ch)]
      exact hd ch j (by rw [← hslen]; exact hj)
    obtain ⟨tj, htj⟩ : ∃ tj, tj = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (hdr ++ StageFS.stageRootOps (Pof ch) core m ++ Block.fullOps (Pof ch) 0 (core.slots.take j)
          ++ Block.slotPreOps (Pof ch) j q') := ⟨_, rfl⟩
    have hW : ∀ {β : Type} (f : StgVw L → β), VwLoc nl f → f (stgVw absOf Lg tj) = f (stgVw absOf Lg τ) := by
      intro β f hf
      rw [htj]
      exact hwinS j q' hq' f hf
    have hst := hslot hdr core ch rs hrd j q' hq'
    rw [← htj] at hst
    have hseen' := hseen j q' hq'
    rw [← htj] at hseen'
    have hclj : stgClaim hostOf j (StageFS.seenOfS ch rs j) = r'.claimed := by
      obtain ⟨dfj, hdfj, -, hhsj, hscj, -⟩ := hall j q' r' hq' hr'
      refine stgClaim_seenOfS hostOf ch rs j r' hr' hscal ?_
      rw [hscj, ← hhost ch j _ r'.draws dfj hdfj]
      exact hhsj
    have hstm : ((stgSlotV P0 m hdrLen hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) j).at Lg).stmt tj
        = (stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j), r'.claimed) := by
      show (match StageFS.tSeenS P0 hdrLen m j tj with
        | some (sn, _) => (stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j sn, stgClaim hostOf j sn)
        | none => (fun _ => 0, Fp2.zero)) = _
      rw [stg_tSeenS (hP ch), hseen']
      simp only
      rw [hclj]
    have h0 : scSt U (Block.slotShape P0 j).2.2 (stgN P0 j)
        ((stgSlotV P0 m hdrLen hostOf absOf (stgFR U hbij P0 Pv bgaOf csv Rv) j).at Lg).stmt tj [] := hst
    unfold scSt at h0
    rw [hstm] at h0
    have hF : stgFR U hbij P0 Pv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j)
        = fun x => stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x := by
      funext x
      show stgPolyT U hbij (Pv (stgVw absOf Lg tj) ch) (csv (stgVw absOf Lg tj)) j (Block.seenOf (bgaOf ch) rs j) x
          + (((Block.seenOf (bgaOf ch) rs j).2.getD j ([], Fp2.zero, [])).2.1).toK U
            * maskPoly (Rv (stgVw absOf Lg tj)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x = _
      rw [hW Pv hlP, hW csv hlC, hW Rv hlR, hPv, Block.seenOf_c (bgaOf ch) rs j r' hr']
      congr 1
      refine stgPolyT_congr U hbij (Pof ch) _ j _ _ ?_ ?_ x
      · rw [Block.histSeen_seenOf, histSeen_stgSnD, ← List.map_take]
        rfl
      · rw [Block.drSeen_seenOf (bgaOf ch) rs j r' hr', drSeen_stgSnD, List.getD_eq_getElem?_getD,
          List.getElem?_map, hr']
        rfl
    rw [hF] at h0
    have hdegF : IndDegLE (Block.slotShape P0 j).2.2 (fun x =>
        stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) :=
      IndDegLE.add_smul hg (maskPoly_indDeg _ j _ _ hd0) _
    have hsw : Block.swk (Pof ch) j = Cfs.sumWeights (stgN P0 j) (Block.slotShape P0 j).2.2 := by
      unfold Block.swk stgN
      rw [stg_slotShape (hP ch)]
    rcases h0 with h | h
    · exact absurd hdegF h
    · have h' : r'.claimed.toK U = cubeSum (fun x =>
          stgSpT U hbij P0 (Pof ch) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
            + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) := h
      rw [h', cubeSum_add_smul, hsw, maskPoly_cubeSum U hU hbij _ Wd j (stgN P0 j) _ hN0 hN64 hNW]

end Main

end ZK60.ProtocolClassify
