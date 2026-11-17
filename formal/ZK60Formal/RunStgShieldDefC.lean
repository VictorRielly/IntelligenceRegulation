/-
D63 lane L63 (2026-11-16), part 16: **the repaired IN-C define polynomial and its vanishing** (finding L63-5; the twins
of deliverable 1 at each slot's own IO width). Written by `results/zk60_lean_l63_20261116/l63_mk_defc.py` from
`RunStgShieldDef.lean`, `RunStgShieldRd.lean` and `RunStgShieldInst.lean` by counted replacements: the table side of
slot `j` is read at `atLog P (elog j)`; every step where the width does not enter is the original's argument.

* `stgSpTC`, `stgSpTC_take`, `stgΦBC`, **`stgΦRC`**: the unmasked slot polynomials and the define polynomial at the
  per-slot widths;
* **`ssh_ΦB_zeroC`**, **`ssh_defAtVC`**: their vanishing at every reading (from the slot start states of `stgFRC`,
  `StgTrueAtC`'s reader and `M` parts);
* **`sshΦIC`**, **`ssh_hDIC`**: `hDI_stg` at the repaired `ΦI` and `FstI`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldC

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV incCtx)
open ZK60.Circuit (gP GF)

section Def

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **Slot `j`'s unmasked slot polynomial** over the data `cs`, on the stage's `stgN P0 j` variables, at the draws
`ds` of the slots `0 … j`. -/
noncomputable def stgSpTC (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (ds : List (List Fp2)) (j : ℕ) : (Fin (stgN P0 j) → K) → K :=
  fun x => stgPolyT U hbij (StageV.atLog P (elog j)) cs j (stgSnD bga ds) x

/-- It reads the draws of slots `0 … j` only. -/
theorem stgSpTC_take (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (ds ds' : List (List Fp2)) (j : ℕ) (h : ds.take (j + 1) = ds'.take (j + 1)) :
    stgSpTC U hbij P0 P elog cs bga ds j = stgSpTC U hbij P0 P elog cs bga ds' j := by
  funext x
  refine stgPolyT_congr U hbij (StageV.atLog P (elog j)) cs j _ _ ?_ ?_ x
  · rw [histSeen_stgSnD, histSeen_stgSnD]
    have e1 : ds.take j = (ds.take (j + 1)).take j := by rw [List.take_take, min_eq_left (Nat.le_succ j)]
    have e2 : ds'.take j = (ds'.take (j + 1)).take j := by rw [List.take_take, min_eq_left (Nat.le_succ j)]
    rw [e1, e2, h]
  · rw [drSeen_stgSnD, drSeen_stgSnD]
    have e1 : ds.getD j [] = (ds.take (j + 1)).getD j [] := by
      rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (Nat.lt_succ_self j)]
    have e2 : ds'.getD j [] = (ds'.take (j + 1)).getD j [] := by
      rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (Nat.lt_succ_self j)]
    rw [e1, e2, h]

open Classical in
/-- **The define polynomial of slot `k` at the history `hd` and the draws `w`** (L36's `FormAt`, the slot's unmasked
residual): for a standalone slot its unmasked cube sum, for a host its unmasked cube sum minus each hosted slot's with
its coefficient, `0` for a hosted (private) slot; `0` where `define` refuses, and where a table side read has a higher
degree than its slot's (where the slot's own sumcheck state is vacuous). -/
noncomputable def stgΦBC (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (hd : List (List Fp2)) (k : ℕ) (w : List Fp2) : K :=
  match P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ w with
  | .ok df =>
    if IndDegLE (Block.slotShape P0 k).2.2 (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) k)
        ∧ ∀ hk ∈ df.hosted, IndDegLE (Block.slotShape P0 hk.1).2.2 (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) hk.1) then
      match P.kind k with
      | .standalone => cubeSum (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) k)
      | .host => cubeSum (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) k)
          - (df.hosted.map (fun hk => hk.2.toK U * cubeSum (stgSpTC U hbij P0 P elog cs bga (hd ++ [w]) hk.1))).sum
      | .priv => 0
    else 0
  | .error _ => 0

/-- **THE REAL STAGE DEFINE POLYNOMIAL over the view** (the real `ΦI`, `ΦO`): `stgΦB` at the schedule the header reader
`Pv` reads at the head's challenges, over the claims' semantics `csv` the view gives, at the draws' words. -/
noncomputable def stgΦRC (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)
    (elogv : StgVw L → ℕ → ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (csv : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  fun v k h y => stgΦBC U hbij P0 (Pv v h.1) (elogv v) (csv v) (bgaOf h.1) h.2 k (stgWords U hbij y)

end Def

section Zero

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **ON AN ACCEPTING SLOT LOOP, `stgΦB` VANISHES AT EVERY SLOT'S DRAWS**, when `M`'s functionals are true (`hm`; the
host functionals `hmH` where a slot hosts), every hosted slot hosts nothing (`hhost`, `hhost2`), and every slot whose
table side has its slot's degree has its claimed sum the cube sum of its masked slot polynomial (`hclG`). -/
theorem ssh_ΦB_zeroC (hU : U ^ 2 = algebraMap GF K 7) (P0 P : Block.BlockParams) (elog : ℕ → ℕ) (cs : Block.Cm → Block.ZClaim → K)
    (core : Block.Core) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec) (acc : Block.Acc)
    (hcan : Block.CoreCanon core) (hlen : rs.length = core.slots.length)
    (hall : ∀ k sp r, core.slots[k]? = some sp → rs[k]? = some r →
      Block.SlotFns P k (Block.histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (rs.take k) sp r acc)
    (hostOf : ℕ → List (ℕ × ℕ))
    (hhost : ∀ k hist dr df, P.define k hist dr = .ok df → df.hosted = (hostOf k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hhost2 : ∀ k, ∀ x ∈ hostOf k, hostOf x.1 = [])
    (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) (hlin : Block.MLin U ms R Wd)
    (hm : Block.MTrue U ms acc.fs) (hmH : (∀ k, hostOf k = []) ∨ Block.MTrue U ms acc.hostFs)
    (hclG : ∀ j r', rs[j]? = some r' →
      IndDegLE (Block.slotShape P0 j).2.2 (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j) →
      r'.claimed.toK U = cubeSum (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j)
        + r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j))
    (k : ℕ) (r : Block.SlotRec) (hr : rs[k]? = some r) :
    stgΦBC U hbij P0 P elog cs bga ((rs.take k).map Block.SlotRec.draws) k r.draws = 0 := by
  -- the unmasked sums, with the claimed sum where a slot's table side has a higher degree
  let Sp : ℕ → K := fun j => if IndDegLE (Block.slotShape P0 j).2.2 (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j)
    then cubeSum (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j)
    else (rs[j]?.map (fun r' => r'.claimed.toK U - r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j))).getD 0
  have hcl : ∀ j r', rs[j]? = some r' → r'.claimed.toK U = Sp j + r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j) := by
    intro j r' hr'
    by_cases hg : IndDegLE (Block.slotShape P0 j).2.2 (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j)
    · show _ = (if _ then _ else _) + _
      simp only [hg, ↓reduceIte]
      exact hclG j r' hr' hg
    · show _ = (if _ then _ else _) + _
      simp only [hg, ↓reduceIte, hr', Option.map_some, Option.getD_some]
      ring
  have hk : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨sp, hsp⟩ : ∃ sp, core.slots[k]? = some sp := ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact hk)⟩
  obtain ⟨df, hdf, -, -, -, hkind, -, -⟩ := hall k sp r hsp hr
  have hdf' : P.define k ⟨bga.1, bga.2.1, bga.2.2, (rs.take k).map Block.SlotRec.draws⟩ r.draws = .ok df := hdf
  obtain ⟨hst, hho⟩ := Block.ssh_unmask_fns U hU P core bga rs acc hcan hlen hall ms R Wd hlin hm Sp hcl k r hr df hdf
  -- the draws of slots `0 … k`
  have hds : (rs.take k).map Block.SlotRec.draws ++ [r.draws] = (rs.take (k + 1)).map Block.SlotRec.draws := by
    rw [List.take_add_one, List.map_append, hr]
    rfl
  have hSp : ∀ j, j ≤ k → stgSpTC U hbij P0 P elog cs bga ((rs.take k).map Block.SlotRec.draws ++ [r.draws]) j
      = stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) j := by
    intro j hj
    refine stgSpTC_take U hbij P0 P elog cs bga _ _ j ?_
    rw [hds, ← List.map_take, ← List.map_take, List.take_take, min_eq_left (by omega)]
  have hspc : sp.scalar.Canon := (hcan.1 sp (List.mem_of_getElem? hsp)).1
  obtain ⟨df2, hdf2, -, hhs2, -⟩ := hall k sp r hsp hr
  have hdd : df2 = df := by
    rw [hdf] at hdf2
    exact (Except.ok.inj hdf2).symm
  rw [hdd] at hhs2
  have hlt : ∀ hk ∈ df.hosted, hk.1 < k := by
    intro hk hmem
    have := (Block.hostedSum_spec U hU _ _ _ _ hspc hhs2).1 hk hmem
    rw [List.length_map, List.length_take] at this
    exact lt_of_lt_of_le this (min_le_left _ _)
  unfold stgΦBC
  rw [hdf']
  simp only
  split_ifs with hg
  · obtain ⟨hgk, hgh⟩ := hg
    have hSpk : Sp k = cubeSum (stgSpTC U hbij P0 P elog cs bga (rs.map Block.SlotRec.draws) k) := by
      rw [hSp k le_rfl] at hgk
      show (if _ then _ else _) = _
      simp only [hgk, ↓reduceIte]
    rw [hSp k le_rfl]
    cases hkk : P.kind k with
    | priv => rfl
    | standalone =>
      simp only
      rw [← hSpk]
      exact hst hkk
    | host =>
      simp only
      have hpriv : ∀ hk ∈ df.hosted, P.kind hk.1 ≠ Block.SlotKind.host := by
        intro hk hmem hkh
        have hk1 := hlt hk hmem
        have hhk : rs[hk.1]? = some rs[hk.1] := List.getElem?_eq_getElem (by omega)
        obtain ⟨sph, hsph⟩ : ∃ sp, core.slots[hk.1]? = some sp :=
          ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; omega)⟩
        obtain ⟨dfh, hdfh, -, -, -, hkindh, -, -⟩ := hall hk.1 sph rs[hk.1] hsph hhk
        have hne := hkindh.mp hkh
        apply hne
        rw [hhost _ _ _ _ hdfh]
        have hmemO : ∃ x ∈ hostOf k, hk.1 = x.1 := by
          rw [hhost _ _ _ _ hdf] at hmem
          obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hmem
          exact ⟨x, hx, rfl⟩
        obtain ⟨x, hx, hxe⟩ := hmemO
        have h2 : hostOf hk.1 = [] := by rw [hxe]; exact hhost2 k x hx
        rw [h2]
        rfl
      have hmH' : Block.MTrue U ms acc.hostFs := by
        rcases hmH with h0 | h0
        · exfalso
          have hne := hkind.mp hkk
          apply hne
          rw [hhost _ _ _ _ hdf, h0 k]
          rfl
        · exact h0
      have he := hho hkk hmH' hpriv
      rw [← hSpk, he]
      have hmap : df.hosted.map (fun hk => hk.2.toK U
            * cubeSum (stgSpTC U hbij P0 P elog cs bga ((rs.take k).map Block.SlotRec.draws ++ [r.draws]) hk.1))
          = df.hosted.map (fun hk => hk.2.toK U * Sp hk.1) := by
        refine List.map_congr_left (fun hk hmem => ?_)
        have hk1 := hlt hk hmem
        rw [hSp hk.1 hk1.le]
        have hg1 := hgh hk hmem
        rw [hSp hk.1 hk1.le] at hg1
        show _ = hk.2.toK U * (if _ then _ else _)
        simp only [hg1, ↓reduceIte]
      rw [hmap, sub_self]
  · rfl

end Zero

section Main

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **THE REAL STAGE DEFINE POLYNOMIAL VANISHES AT EVERY READING** (`StgDefAtV` for `stgΦR`; the premises `hDI_stg`,
`hDO_stg`): from every slot's start state (`hslot`, by `ssh_slotStart` from `¬ rtKsl.Dm`), `StgTrueAt` (the schedule
the reader reads, `M`'s functionals), `M`'s host functionals where the stage hosts (`hmH`), the reader, claims and `M`
read below the head (`VwLoc`), and the schedule's shapes. -/
theorem ssh_defAtVC (hU : U ^ 2 = algebraMap GF K 7) (key : Option Dig) (domain : List UInt8)
    (P0 : Block.BlockParams) (Pof : List Fp2 → Block.BlockParams) (m hdrLen : ℕ)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (hostOf : ℕ → List (ℕ × ℕ)) (absOf : QB L → Option (List UInt8))
    (Pv : StgVw L → List Fp2 → Block.BlockParams) (elogv : StgVw L → ℕ → ℕ)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K)
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
    (hlP : VwLoc nl Pv) (hlE : VwLoc nl elogv) (hlC : VwLoc nl csv) (hlR : VwLoc nl Rv) (hlM : VwLoc nl msv)
    (hslot : StgSlotStartAt U key domain P0 Pof m hdrLen bgaOf hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) G Lg τ)
    (htrue : StgTrueAtC U key domain Pof m hdrLen bgaOf absOf Pv elogv csv msv G Lg τ)
    (hmH : (∀ k, hostOf k = []) ∨ StgHostTrueAt U key domain Pof m hdrLen bgaOf absOf msv G Lg τ) :
    StgDefAtV U key domain P0 Pof m hdrLen bgaOf absOf (stgΦRC U hbij P0 Pv elogv bgaOf csv) G Lg τ := by
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
  obtain ⟨hPv, -, -, -, hMt⟩ := htrue hdr core ch rs hrd acc t' hacc k q hq
  rw [hwinS k q hq Pv hlP] at hPv
  rw [hwinS k q hq msv hlM] at hMt
  show stgΦBC U hbij P0 (Pv _ ch) (elogv _) (csv _) (bgaOf ch) ((rs.take k).map Block.SlotRec.draws) k
      (stgWords U hbij (fun i : Fin (P0.draws k) => (r.draws.getD i.val Fp2.zero).toK U)) = 0
  rw [hwinD Pv hlP, hwinD elogv hlE, hwinD csv hlC, hPv]
  have hw : stgWords U hbij (fun i : Fin (P0.draws k) => (r.draws.getD i.val Fp2.zero).toK U) = r.draws :=
    stgWords_toK U hbij hU r.draws (hdraw k r hr).1 _ (by rw [(hdraw k r hr).2, (hP ch).1])
  rw [hw]
  refine ssh_ΦB_zeroC U hbij hU P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) core (bgaOf ch) rs acc hcan hlen hall hostOf
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
    have hstm : ((stgSlotV P0 m hdrLen hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) j).at Lg).stmt tj
        = (stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j), r'.claimed) := by
      show (match StageFS.tSeenS P0 hdrLen m j tj with
        | some (sn, _) => (stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j sn, stgClaim hostOf j sn)
        | none => (fun _ => 0, Fp2.zero)) = _
      rw [stg_tSeenS (hP ch), hseen']
      simp only
      rw [hclj]
    have h0 : scSt U (Block.slotShape P0 j).2.2 (stgN P0 j)
        ((stgSlotV P0 m hdrLen hostOf absOf (stgFRC U hbij P0 Pv elogv bgaOf csv Rv) j).at Lg).stmt tj [] := hst
    unfold scSt at h0
    rw [hstm] at h0
    have hF : stgFRC U hbij P0 Pv elogv bgaOf csv Rv (stgVw absOf Lg tj) j (StageFS.seenOfS ch rs j)
        = fun x => stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x := by
      funext x
      show stgPolyT U hbij (StageV.atLog (Pv (stgVw absOf Lg tj) ch) (elogv (stgVw absOf Lg tj) j))
          (csv (stgVw absOf Lg tj)) j (Block.seenOf (bgaOf ch) rs j) x
          + (((Block.seenOf (bgaOf ch) rs j).2.getD j ([], Fp2.zero, [])).2.1).toK U
            * maskPoly (Rv (stgVw absOf Lg tj)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x = _
      rw [hW Pv hlP, hW elogv hlE, hW csv hlC, hW Rv hlR, hPv, Block.seenOf_c (bgaOf ch) rs j r' hr']
      congr 1
      refine stgPolyT_congr U hbij (StageV.atLog (Pof ch) (elogv (stgVw absOf Lg τ) j)) _ j _ _ ?_ ?_ x
      · rw [Block.histSeen_seenOf, histSeen_stgSnD, ← List.map_take]
        rfl
      · rw [Block.drSeen_seenOf (bgaOf ch) rs j r' hr', drSeen_stgSnD, List.getD_eq_getElem?_getD,
          List.getElem?_map, hr']
        rfl
    rw [hF] at h0
    have hdegF : IndDegLE (Block.slotShape P0 j).2.2 (fun x =>
        stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
          + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) :=
      IndDegLE.add_smul hg (maskPoly_indDeg _ j _ _ hd0) _
    have hsw : Block.swk (Pof ch) j = Cfs.sumWeights (stgN P0 j) (Block.slotShape P0 j).2.2 := by
      unfold Block.swk stgN
      rw [stg_slotShape (hP ch)]
    rcases h0 with h | h
    · exact absurd hdegF h
    · have h' : r'.claimed.toK U = cubeSum (fun x =>
          stgSpTC U hbij P0 (Pof ch) (elogv (stgVw absOf Lg τ)) (csv (stgVw absOf Lg τ)) (bgaOf ch) (rs.map Block.SlotRec.draws) j x
            + r'.c.toK U * maskPoly (Rv (stgVw absOf Lg τ)) j (stgN P0 j) (Block.slotShape P0 j).2.2 x) := h
      rw [h', cubeSum_add_smul, hsw, maskPoly_cubeSum U hU hbij _ Wd j (stgN P0 j) _ hN0 hN64 hNW]

end Main

section Phi

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {L : ℕ} (h64 : 64 ≤ L)

/-- **THE REAL `ΦI`, REPAIRED** (finding L63-5, slot `k` at its own IO width): stage IN-C's define polynomial over the view, at the schedule `Win` reads (as `stgFstI`). -/
noncomputable def sshΦIC (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  stgΦRC U hbij P0 (fun v ch => (vdWin Vi (v.2.take n0)).bp (incCtx (vdWin Vi (v.2.take n0)).pub ch))
    (fun v k => StageV.incElog (vdWin Vi (v.2.take n0)).pub (vdWin Vi (v.2.take n0)).geo.bLogN k)
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO)

end Phi

section Run

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
variable (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
  (tag : MTag) (h64 : 64 ≤ Lq)

/-- **`hDI_stg` AT THE REAL `ΦI`** (stage IN-C, part `0`). -/
theorem ssh_hDIC (hU : U ^ 2 = algebraMap GF K 7) (n : ℕ) (hi : 0 < pf.parts.length) (hin : 0 < n)
    (Pof : List Fp2 → Block.BlockParams) (P0 : Block.BlockParams) (Vi : IncV) (n0 hdrLen m lc h Q e rA rH S : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K)
    (hP : ∀ ch, StgSame P0 (Pof ch)) (hgt : ∀ ch, (Pof ch).geom.slots.length = (Pof ch).geom.terms.length)
    (hd : ∀ ch k, k < (Pof ch).geom.slots.length → 1 ≤ (Block.slotShape (Pof ch) k).2.2)
    (hhost : ∀ ch k hist dr df, (Pof ch).define k hist dr = .ok df →
      df.hosted = (stgHostIn k).map (fun x => (x.1, dr.getD x.2 Fp2.zero)))
    (hN : ∀ k, k < P0.geom.slots.length → 0 < stgN P0 k ∧ stgN P0 k * (Block.slotShape P0 k).2.2 + 2 ≤ 512)
    (hN64 : ∀ k, k < P0.geom.slots.length → stgN P0 k < 64)
    (hIOl : VwLoc (hdrLen + (7 + m)) csIO)
    (G : QB Lq → Dig) (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (hS : D.sls 0 = stgSchedV P0 m hdrLen stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (stgFstIC U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO))
    (hns : ¬ (rtKsl key domain hs Lq hL pf rd hL64 hv U hbij D hD).Dm n lg τ)
    (htrue : StgTrueAtC U key domain Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
      (fun v ch => ((vdWin Vi) (v.2.take n0)).bp (incCtx ((vdWin Vi) (v.2.take n0)).pub ch))
      (fun v k => StageV.incElog ((vdWin Vi) (v.2.take n0)).pub ((vdWin Vi) (v.2.take n0)).geo.bLogN k)
      (stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) csIO) (stgMsv U tag h64 S (hdrLen + 3)) G lg τ) :
    StgDefAtV U key domain P0 Pof m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) (sshΦIC U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO)
      G lg τ := by
  have hslot := ssh_slotStart key domain hs Lq hL pf rd hL64 hv U hbij D hD n 0 hi hin P0 Pof m hdrLen
    (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) stgHostIn (Exec.Block.absOfC (chainEncB key domain hs Lq hL))
    (stgFstIC U hbij tag h64 P0 (vdWin Vi) n0 hdrLen m lc h Q e rA rH S csIO) G lg τ hP hgt hS hns
  exact ssh_defAtVC U hbij hU key domain P0 Pof m hdrLen _ stgHostIn _ _ _ _ (stgRv U tag h64 S (hdrLen + 3))
    (stgMsv U tag h64 S (hdrLen + 3)) 512 G lg τ hP hgt hd hhost (fun _ _ _ => rfl)
    (fun k hk => ⟨(hN k hk).1, hN64 k hk, (hN k hk).2⟩) (stgMsv_mlin U tag h64 S (hdrLen + 3))
    (hdrLen + (7 + m)) le_rfl (vwLoc_vdWin Vi n0 _) (fun _ _ _ _ => rfl)
    (vwLoc_stgCsv U tag h64 lc h Q e rA rH hdrLen (hdrLen + 4 + m) _ (by omega) (by omega) csIO hIOl)
    (vwLoc_stgRv U tag h64 S (hdrLen + 3) _ (by omega)) (vwLoc_stgMsv U tag h64 S (hdrLen + 3) _ (by omega))
    hslot htrue (Or.inl (fun _ => rfl))

end Run

end ZK60.ProtocolClassify
