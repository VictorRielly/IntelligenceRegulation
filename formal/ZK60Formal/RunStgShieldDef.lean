/-
D63 lane L63 (2026-11-16), part 1: **the stages' define polynomials `ΦI`, `ΦO` set to the real ones, and their
vanishing at every reading (`StgDefAtV`) PROVED from the slots' start claims** (finding R1-2; deliverable 1).

A stage slot `k` that draws `y` has, over the data the view extracts, the unmasked cube sum
`Sp_k(y) = Σ_b Poly_k(y)(b)` (`Poly_k` the table side `stgPolyT` of the slot's own `define` at its draws). The real
define polynomial is the slot's unmasked residual (L36's `FormAt`, L57 §5.1): `Sp_k` for a standalone slot,
`Sp_k − Σ_h κ_h·Sp_h` for a host (`κ_h` the coefficient its `define` hosts slot `h` with), `0` for a hosted (private)
slot. On an accepting stage slot phase whose slots' start claims are true (`¬ rtKsl.Dm`) and whose `M` functionals are
true, the CFS unmasking (L23's `unmask_slots`, here over the STAGE's slot loop) makes it vanish at the drawn `y`.

* `ssh_unmask_fns`, `ssh_stage_fns` (namespace `Block`): L23's unmasking over any accepting slot loop's `SlotFns`, and
  those of the stage's slot loop; the standalone half needs `M`'s `fs` only, the host half also `hostFs`;
* `VwLoc`, `vw_take` and the locality of `stgCsv`, `stgRv`, `stgMsv` and both stages' schedule readers: what reads the
  view below a position reads the same at every window after it;
* `stgSnD`, `stgSpT`, **`stgΦB`**, **`stgΦR`**: THE REAL DEFINE POLYNOMIAL over the view (`stgΦR`), guarded by the slots'
  degrees (where a table side has a higher degree than the slot's, the slot's own sumcheck state is vacuous too);
* `StgSlotStartAt`, **`ssh_slotStart`**: every stage slot's start state is true at every reading, from `¬ rtKsl.Dm`;
* `StgHostTrueAt`: `M`'s host functionals true at every reading (the part of `M`'s check `StgTrueAt` leaves out);
* **`ssh_defAtV`**: `StgDefAtV` for `stgΦR` from `StgSlotStartAt`, `StgTrueAt` and (for a stage with hosts)
  `StgHostTrueAt`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgAlgPoly
import ZK60Formal.CoverW16Unmask
import ZK60Formal.RunAliveRed
import ZK60Formal.RunVerdictW

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

section SshUnmask

variable {K : Type} [Field K] [Algebra GF K]

/-- **L23's unmasking over any accepting slot loop's functionals** (`unmask_slots` with `blockSlots_fns` replaced by its
conclusion, so that the stage's slot loop can use it): the standalone half needs `M`'s functionals `acc.fs` only; the
host half also `acc.hostFs`. -/
theorem ssh_unmask_fns (U : K) (hU : U ^ 2 = algebraMap GF K 7) (P : BlockParams) (core : Core)
    (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (hcan : CoreCanon core)
    (hlen : rs.length = core.slots.length)
    (hall : ∀ k sp r, core.slots[k]? = some sp → rs[k]? = some r →
      SlotFns P k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (rs.take k) sp r acc)
    (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) (hlin : MLin U ms R Wd)
    (hm : MTrue U ms acc.fs) (Sp : ℕ → K)
    (hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U = Sp k + r.c.toK U * mdot U R Wd (k, swk P k))
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) (df : SlotDef)
    (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df) :
    (P.kind k = SlotKind.standalone → Sp k = 0)
    ∧ (P.kind k = SlotKind.host → MTrue U ms acc.hostFs → (∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host) →
        Sp k = (df.hosted.map (fun hk => hk.2.toK U * Sp hk.1)).sum) := by
  have hk : k < rs.length := (List.getElem?_eq_some_iff.mp hr).1
  obtain ⟨sp, hsp⟩ : ∃ sp, core.slots[k]? = some sp :=
    ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact hk)⟩
  obtain ⟨df', hdf', -, hhs, hsc, hkind, hstd, hhost⟩ := hall k sp r hsp hr
  have hdd : df' = df := by
    rw [hdf] at hdf'
    exact (Except.ok.inj hdf').symm
  rw [hdd] at hhs hkind hhost
  have hspc : sp.scalar.Canon := (hcan.1 sp (List.mem_of_getElem? hsp)).1
  obtain ⟨hlt, hcs⟩ := hostedSum_spec U hU _ _ _ _ hspc hhs
  refine ⟨fun hst => ?_, fun hho hmH hpriv => ?_⟩
  · have hne : df.hosted = [] := by
      by_contra hne
      have := hkind.mpr hne
      rw [hst] at this
      cases this
    have hΓ := hm _ (hstd hst)
    rw [hlin] at hΓ
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero] at hΓ
    rw [mdot_scale U hU] at hΓ
    rw [hne] at hcs
    simp only [List.map_nil, List.sum_nil, add_zero] at hcs
    have h1 := hcl k r hr
    rw [hcs] at h1
    linear_combination -h1 - hΓ
  · have hΓ := hmH _ (hhost hho)
    rw [hlin] at hΓ
    simp only [List.map_cons, List.sum_cons] at hΓ
    have hterm : (df.hosted.map (fun hk => (hk.1, (swk P hk.1).map (fun w => w.mul
        (hk.2.mul (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero)).neg)))).map (mdot U R Wd)
        = df.hosted.map (fun hk => -(hk.2.toK U * (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero).toK U)
          * mdot U R Wd (hk.1, swk P hk.1)) := by
      rw [List.map_map]
      refine List.map_congr_left (fun hk _ => ?_)
      simp only [Function.comp]
      rw [mdot_scale U hU, Fp2.toK_neg U _ (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
    rw [mdot_scale U hU, hterm] at hΓ
    have hsub : ∀ hk ∈ df.hosted, ((rs.take k).map SlotRec.scalar).getD hk.1 Fp2.zero
        = ((rs.take k).map SlotRec.claimed).getD hk.1 Fp2.zero := by
      intro hk hmem
      have hlt' := hlt hk hmem
      rw [List.length_map, List.length_take] at hlt'
      have hhr : hk.1 < rs.length := lt_of_lt_of_le hlt' (min_le_right _ _)
      have hh : hk.1 < k := lt_of_lt_of_le hlt' (min_le_left _ _)
      obtain ⟨sph, hsph⟩ : ∃ sp, core.slots[hk.1]? = some sp :=
        ⟨_, List.getElem?_eq_getElem (by rw [← hlen]; exact hhr)⟩
      have hrh : rs[hk.1]? = some rs[hk.1] := List.getElem?_eq_getElem hhr
      obtain ⟨dfh, -, -, hhsh, hsch, hkindh, -, -⟩ := hall hk.1 sph rs[hk.1] hsph hrh
      have hne : dfh.hosted = [] := by
        by_contra hne
        exact hpriv hk hmem (hkindh.mpr hne)
      rw [hne] at hhsh
      simp only [hostedSum, Except.ok.injEq] at hhsh
      have e1 : ((rs.take k).map SlotRec.scalar).getD hk.1 Fp2.zero = rs[hk.1].scalar := by
        rw [getD_eq_get _ _ _ (by simp; omega)]
        simp
      have e2 : ((rs.take k).map SlotRec.claimed).getD hk.1 Fp2.zero = rs[hk.1].claimed := by
        rw [getD_eq_get _ _ _ (by simp; omega)]
        simp
      rw [e1, e2, hsch]
      exact hhsh
    have hcl2 : ∀ hk ∈ df.hosted, (((rs.take k).map SlotRec.claimed).getD hk.1 Fp2.zero).toK U
        = Sp hk.1 + (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero).toK U * mdot U R Wd (hk.1, swk P hk.1) := by
      intro hk hmem
      have hlt' := hlt hk hmem
      rw [List.length_map, List.length_take] at hlt'
      have hh : hk.1 < k := lt_of_lt_of_le hlt' (min_le_left _ _)
      have hhr : hk.1 < rs.length := lt_of_lt_of_le hlt' (min_le_right _ _)
      have e1 : ((rs.take k).map SlotRec.claimed).getD hk.1 Fp2.zero = rs[hk.1].claimed := by
        rw [getD_eq_get _ _ _ (by simp; omega)]
        simp
      have e2 : ((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero = rs[hk.1].c := by
        rw [getD_eq_get _ _ _ (by simp; omega)]
        simp
      rw [e1, e2]
      exact hcl hk.1 rs[hk.1] (List.getElem?_eq_getElem hhr)
    have hcs' : r.claimed.toK U = sp.scalar.toK U + (df.hosted.map (fun hk => hk.2.toK U
        * (Sp hk.1 + (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero).toK U * mdot U R Wd (hk.1, swk P hk.1)))).sum := by
      rw [hcs]
      congr 1
      refine congrArg List.sum (List.map_congr_left fun hk hmem => ?_)
      rw [hsub hk hmem, hcl2 hk hmem]
    have h1 := hcl k r hr
    rw [hcs'] at h1
    have hsplit : ∀ l : List (ℕ × Fp2), (l.map (fun hk => hk.2.toK U * Sp hk.1)).sum
        = (l.map (fun hk => hk.2.toK U * (Sp hk.1 + (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero).toK U
            * mdot U R Wd (hk.1, swk P hk.1)))).sum
          + (l.map (fun hk => -(hk.2.toK U * (((rs.take k).map SlotRec.c).getD hk.1 Fp2.zero).toK U)
            * mdot U R Wd (hk.1, swk P hk.1))).sum := by
      intro l
      induction l with
      | nil => simp
      | cons x l ih => simp only [List.map_cons, List.sum_cons, ih]; ring
    rw [hsplit]
    linear_combination -h1 - hΓ

end SshUnmask

section SshStage

variable (H : HIn → Dig)

/-- **Every slot's functionals on an accepting STAGE slot phase** (L23's `blockSlots_fns` for L15's `stageSlots`: the
head's challenges `ch`, `define`'s history `bgaOf ch`). -/
theorem ssh_stage_fns (P : BlockParams) (m : ℕ) (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (core : Core) (t : Tr)
    (ch : List Fp2) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hacc : StageFS.stageSlots H P m bgaOf core t = .ok (ch, rs, acc, t')) :
    rs.length = core.slots.length ∧ ∀ k sp r, core.slots[k]? = some sp → rs[k]? = some r →
      SlotFns P k (histOf (bgaOf ch).1 (bgaOf ch).2.1 (bgaOf ch).2.2 (rs.take k)) (rs.take k) sp r acc := by
  rw [StageFS.stageSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hch, hres⟩ := hacc
    subst hres
    rw [hch] at hloop
    obtain ⟨-, -, rs', hrs', hlen, hall⟩ := slotsLoop_fns H P _ _ _ core.slots [] 0 {} _ rs acc t' rfl rfl hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    refine ⟨hlen, fun k sp r hsp hr => ?_⟩
    have := hall k sp r hsp hr
    simpa using this
  · cases hacc

end SshStage

end ZK60.Exec.Block

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## Reading the view below a position -/

section Loc

variable {L : ℕ}

/-- **`f` reads the view only below position `n`**: the cuts at positions `< n` and the trace's first `n` entries. -/
def VwLoc {β : Type} (n : ℕ) (f : StgVw L → β) : Prop :=
  ∀ v v' : StgVw L, (∀ i, i < n → v.1 i = v'.1 i) → v.2.take n = v'.2.take n → f v = f v'

theorem ssh_absAt_take (τ : List (TItem × Dig)) (n i : ℕ) (hi : i < n) :
    Block.absAt (τ.take n) i = Block.absAt τ i := by
  unfold Block.absAt
  rw [List.getElem?_take_of_lt hi]

/-- **A reader below `n` reads the same at every window after `n`.** -/
theorem vw_take {β : Type} (absOf : QB L → Option (List UInt8)) (Lg : List (QB L × Dig)) (n a : ℕ) (hna : n ≤ a)
    (f : StgVw L → β) (hf : VwLoc n f) (τ : List (TItem × Dig)) :
    f (stgVw absOf Lg (τ.take a)) = f (stgVw absOf Lg τ) := by
  apply hf
  · intro i hi
    show Block.cutO absOf (Block.absAt (τ.take a) i) Lg = Block.cutO absOf (Block.absAt τ i) Lg
    rw [ssh_absAt_take τ a i (by omega)]
  · show (τ.take a).take n = τ.take n
    rw [List.take_take, min_eq_left hna]

theorem vwLoc_const {β : Type} (n : ℕ) (b : β) : VwLoc (L := L) n (fun _ => b) :=
  fun _ _ _ _ => rfl

/-- The absorbed bytes at position `i < n`, from the first `n` entries. -/
theorem ssh_absAt_eq (v v' : List (TItem × Dig)) (n i : ℕ) (hi : i < n) (h : v.take n = v'.take n) :
    Block.absAt v i = Block.absAt v' i := by
  rw [← ssh_absAt_take v n i hi, ← ssh_absAt_take v' n i hi, h]

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (h64 : 64 ≤ L)

/-- **The claims' semantics reads the view below `n`** when its roots' positions are below `n` and its IO part does. -/
theorem vwLoc_stgCsv (lc h Q e rA rH iA iH n : ℕ) (hA : iA < n) (hH : iH < n)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (hIO : VwLoc n csIO) :
    VwLoc n (stgCsv U tag h64 lc h Q e rA rH iA iH csIO) := by
  intro v v' h1 h2
  funext cm z
  cases cm with
  | a =>
    show claimSem U rA lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rA (v.1 iA) (Block.absAt v.2 iA))) z
      = claimSem U rA lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rA (v'.1 iA) (Block.absAt v'.2 iA))) z
    rw [h1 iA hA, ssh_absAt_eq v.2 v'.2 n iA hA h2]
  | h =>
    show claimSem U rH lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rH (v.1 iH) (Block.absAt v.2 iH))) z
      = claimSem U rH lc Q (decodeRows (encGL (K := K) lc h Q) e (UxC tag L h64 h rH (v'.1 iH) (Block.absAt v'.2 iH))) z
    rw [h1 iH hH, ssh_absAt_eq v.2 v'.2 n iH hH h2]
  | inp =>
    show csIO v .inp z = csIO v' .inp z
    rw [hIO v v' h1 h2]
  | out =>
    show csIO v .out z = csIO v' .out z
    rw [hIO v v' h1 h2]

/-- **The extracted mask rows read the view below `n`** (their root at `iM < n`). -/
theorem vwLoc_stgRv (S iM n : ℕ) (hM : iM < n) : VwLoc n (stgRv U tag h64 (L := L) S iM) := by
  intro v v' h1 h2
  show mRowX U S (colsC tag L h64 (v.1 iM) (Block.absAt v.2 iM)) = mRowX U S (colsC tag L h64 (v'.1 iM) (Block.absAt v'.2 iM))
  rw [h1 iM hM, ssh_absAt_eq v.2 v'.2 n iM hM h2]

/-- **`M`'s semantics reads the view below `n`** (its root at `iM < n`). -/
theorem vwLoc_stgMsv (S iM n : ℕ) (hM : iM < n) : VwLoc n (stgMsv U tag h64 (L := L) S iM) := by
  intro v v' h1 h2
  show msOfTab U S (colsC tag L h64 (v.1 iM) (Block.absAt v.2 iM)) = msOfTab U S (colsC tag L h64 (v'.1 iM) (Block.absAt v'.2 iM))
  rw [h1 iM hM, ssh_absAt_eq v.2 v'.2 n iM hM h2]

/-- **Stage OUT-C's schedule reader reads the view below `7`** (the verdict byte at position `6`). -/
theorem vwLoc_vdWout (F : ℕ → StageV.OutcV) (n0 n : ℕ) (hn : 6 < n) :
    VwLoc (L := L) n (fun v (_ : List Fp2) => ((vdWout F (v.2.take n0)).bp)) := by
  intro v v' _ h2
  have e : Block.absAt (v.2.take n0) 6 = Block.absAt (v'.2.take n0) 6 := by
    unfold Block.absAt
    rw [List.getElem?_take, List.getElem?_take]
    split_ifs
    · have := ssh_absAt_eq v.2 v'.2 n 6 hn h2
      unfold Block.absAt at this
      rw [this]
    · rfl
  show (fun (_ : List Fp2) => (F (vdByte (v.2.take n0))).bp) = (fun _ => (F (vdByte (v'.2.take n0))).bp)
  unfold vdByte
  rw [e]

/-- **Stage IN-C's schedule reader is constant** (`vdWin`). -/
theorem vwLoc_vdWin (Vi : StageV.IncV) (n0 n : ℕ) :
    VwLoc (L := L) n (fun v ch => (vdWin Vi (v.2.take n0)).bp (StageV.incCtx (vdWin Vi (v.2.take n0)).pub ch)) :=
  fun _ _ _ _ => rfl

end Loc

/-! ## The real define polynomial -/

section Def

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  {L : ℕ}

/-- **What the table side of slot `j` reads, built from the draws alone** (the table side reads `define`'s history and
the slot's own draws only, never `c` or the scalar). -/
def stgSnD (bga : Fp2 × Fp2 × Fp2) (ds : List (List Fp2)) : Block.Seen :=
  (bga, ds.map (fun d => (d, Fp2.zero, ([] : List UInt8))))

theorem histSeen_stgSnD (bga : Fp2 × Fp2 × Fp2) (ds : List (List Fp2)) (j : ℕ) :
    Block.histSeen (stgSnD bga ds) j = ⟨bga.1, bga.2.1, bga.2.2, ds.take j⟩ := by
  simp [Block.histSeen, stgSnD, List.map_take, List.map_map, Function.comp_def]

theorem drSeen_stgSnD (bga : Fp2 × Fp2 × Fp2) (ds : List (List Fp2)) (j : ℕ) :
    Block.drSeen (stgSnD bga ds) j = ds.getD j [] := by
  unfold Block.drSeen stgSnD
  rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map]
  cases ds[j]? <;> rfl

/-- The table side depends on what the trace shows only through `define`'s history and the slot's draws. -/
theorem stgPolyT_congr (P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (j : ℕ) (sn sn' : Block.Seen)
    (h1 : Block.histSeen sn j = Block.histSeen sn' j) (h2 : Block.drSeen sn j = Block.drSeen sn' j)
    {N : ℕ} (x : Fin N → K) : stgPolyT U hbij P cs j sn x = stgPolyT U hbij P cs j sn' x := by
  unfold stgPolyT
  rw [h1, h2]

/-- **Slot `j`'s unmasked slot polynomial** over the data `cs`, on the stage's `stgN P0 j` variables, at the draws
`ds` of the slots `0 … j`. -/
noncomputable def stgSpT (P0 P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (ds : List (List Fp2)) (j : ℕ) : (Fin (stgN P0 j) → K) → K :=
  fun x => stgPolyT U hbij P cs j (stgSnD bga ds) x

/-- It reads the draws of slots `0 … j` only. -/
theorem stgSpT_take (P0 P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (ds ds' : List (List Fp2)) (j : ℕ) (h : ds.take (j + 1) = ds'.take (j + 1)) :
    stgSpT U hbij P0 P cs bga ds j = stgSpT U hbij P0 P cs bga ds' j := by
  funext x
  refine stgPolyT_congr U hbij P cs j _ _ ?_ ?_ x
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
noncomputable def stgΦB (P0 P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K) (bga : Fp2 × Fp2 × Fp2)
    (hd : List (List Fp2)) (k : ℕ) (w : List Fp2) : K :=
  match P.define k ⟨bga.1, bga.2.1, bga.2.2, hd⟩ w with
  | .ok df =>
    if IndDegLE (Block.slotShape P0 k).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [w]) k)
        ∧ ∀ hk ∈ df.hosted, IndDegLE (Block.slotShape P0 hk.1).2.2 (stgSpT U hbij P0 P cs bga (hd ++ [w]) hk.1) then
      match P.kind k with
      | .standalone => cubeSum (stgSpT U hbij P0 P cs bga (hd ++ [w]) k)
      | .host => cubeSum (stgSpT U hbij P0 P cs bga (hd ++ [w]) k)
          - (df.hosted.map (fun hk => hk.2.toK U * cubeSum (stgSpT U hbij P0 P cs bga (hd ++ [w]) hk.1))).sum
      | .priv => 0
    else 0
  | .error _ => 0

/-- **THE REAL STAGE DEFINE POLYNOMIAL over the view** (the real `ΦI`, `ΦO`): `stgΦB` at the schedule the header reader
`Pv` reads at the head's challenges, over the claims' semantics `csv` the view gives, at the draws' words. -/
noncomputable def stgΦR (P0 : Block.BlockParams) (Pv : StgVw L → List Fp2 → Block.BlockParams)
    (bgaOf : List Fp2 → Fp2 × Fp2 × Fp2) (csv : StgVw L → Block.Cm → Block.ZClaim → K) :
    StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K :=
  fun v k h y => stgΦB U hbij P0 (Pv v h.1) (csv v) (bgaOf h.1) h.2 k (stgWords U hbij y)

end Def

/-! ## The define polynomial vanishes on an accepting slot loop whose claims are true -/

section Zero

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

open Classical in
/-- **ON AN ACCEPTING SLOT LOOP, `stgΦB` VANISHES AT EVERY SLOT'S DRAWS**, when `M`'s functionals are true (`hm`; the
host functionals `hmH` where a slot hosts), every hosted slot hosts nothing (`hhost`, `hhost2`), and every slot whose
table side has its slot's degree has its claimed sum the cube sum of its masked slot polynomial (`hclG`). -/
theorem ssh_ΦB_zero (hU : U ^ 2 = algebraMap GF K 7) (P0 P : Block.BlockParams) (cs : Block.Cm → Block.ZClaim → K)
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
      IndDegLE (Block.slotShape P0 j).2.2 (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j) →
      r'.claimed.toK U = cubeSum (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j)
        + r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j))
    (k : ℕ) (r : Block.SlotRec) (hr : rs[k]? = some r) :
    stgΦB U hbij P0 P cs bga ((rs.take k).map Block.SlotRec.draws) k r.draws = 0 := by
  -- the unmasked sums, with the claimed sum where a slot's table side has a higher degree
  let Sp : ℕ → K := fun j => if IndDegLE (Block.slotShape P0 j).2.2 (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j)
    then cubeSum (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j)
    else (rs[j]?.map (fun r' => r'.claimed.toK U - r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j))).getD 0
  have hcl : ∀ j r', rs[j]? = some r' → r'.claimed.toK U = Sp j + r'.c.toK U * Block.mdot U R Wd (j, Block.swk P j) := by
    intro j r' hr'
    by_cases hg : IndDegLE (Block.slotShape P0 j).2.2 (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j)
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
  have hSp : ∀ j, j ≤ k → stgSpT U hbij P0 P cs bga ((rs.take k).map Block.SlotRec.draws ++ [r.draws]) j
      = stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) j := by
    intro j hj
    refine stgSpT_take U hbij P0 P cs bga _ _ j ?_
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
  unfold stgΦB
  rw [hdf']
  simp only
  split_ifs with hg
  · obtain ⟨hgk, hgh⟩ := hg
    have hSpk : Sp k = cubeSum (stgSpT U hbij P0 P cs bga (rs.map Block.SlotRec.draws) k) := by
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
            * cubeSum (stgSpT U hbij P0 P cs bga ((rs.take k).map Block.SlotRec.draws ++ [r.draws]) hk.1))
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

end ZK60.ProtocolClassify
