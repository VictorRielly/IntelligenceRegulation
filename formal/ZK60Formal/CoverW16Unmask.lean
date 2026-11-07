/-
D63 lane L23 (2026-11-07), part 2: **the CFS unmasking on the block verifier's acceptance** (generic in the block
shape), the step of `hcoverR` / `hcoverH` that turns the claimed sums and `M`'s functionals into the slots' unmasked
identities.

`RelW16Host.unmask_host` / `unmask_standalone` (L21) are the algebra for ONE slot with its scalars, masks and `Γ`
functional given. This file reads them off an accepting slot loop:

* `slotStep_ok_fns`, `slotDefChecks_ok`: an accepting slot exposes its definition, the schedule check (its index is
  the count of the slots before it; it is a host exactly when its hosted list is nonempty), its claimed sum as the
  hosted sum of the earlier scalars, and the accumulator after it;
* `SlotFns`, **`slotsLoop_fns`**, **`blockSlots_fns`**: on an accepting slot loop, every slot's definition, claimed
  sum, kind, and its `Γ` functional in the final lists (a standalone's in `acc.fs`, a host's in `acc.hostFs`, the
  hosted slots weighted by THEIR `c` from the records before the host and by THEIR sum weights);
* `hostedSum_spec`: the claimed sum read in the field is `scalar + Σ κ·scalar_h`, every hosted index earlier;
* `mdot`, `MLin`, `mdot_scale`, `list_sum_map_mul`: `M`'s functional on the extracted mask rows `R` is linear in its
  weights (the reading `msX` must have: `Σ_terms Σ_j w_j·R_{slot}(j)`);
* **`unmask_slots`**: with `M`'s functionals true (`OpenTrue`'s `MTrue`), `msX` linear, and every claimed sum the cube
  sum of `Sp_k + c_k·mask_k` (the masked slot polynomial; `mask_k`'s cube sum is `mdot` at the slot's `sum_weights`),
  a standalone slot's unmasked sum is `0` and a host's is `Σ_h κ_h·Sp_h` over its hosted private slots: every scalar
  and every mask drops out;
* `unmask_slots_eq`: the host half, stated alone.

**Finding L23-1** (the doc, §4), fixed in `ExecBlockVerify.slotAcc` (2026-11-07, authorised by the coordinator): the
host's `Γ` weights each hosted slot's mask with THAT slot's sum weights `sum_weights(sh, hs)` (argument.rs:1500). With
the earlier weighting (the host's own `sumWeights (n_s + e_s) d_s`) the unmasking left the extra terms
`c_h·(mdot_h(sw_h) − mdot_h(sw_host))`; with the code's they cancel, and the conclusion is `unmask_host`'s.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.CoverW16

set_option autoImplicit false

namespace ZK60.Exec.Block

open ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## One accepting slot, with its functionals -/

/-- A slot's sum weights (`sum_weights(sh, s)`: `Cfs.sumWeights (n + e) d` of the slot's own shape). -/
def swk (P : BlockParams) (s : ℕ) : List Fp2 :=
  Cfs.sumWeights ((slotShape P s).1 + (slotShape P s).2.1) (slotShape P s).2.2

theorem slotDefChecks_ok (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (h : slotDefChecks P s acc df = .ok ()) :
    s = acc.cs.length ∧ ((P.kind s = SlotKind.host) ↔ df.hosted ≠ []) := by
  unfold slotDefChecks at h
  dsimp only at h
  split at h
  · cases h
  · rename_i hc
    simp only [Bool.or_eq_true, decide_eq_true_eq, not_or] at hc
    obtain ⟨⟨h1, -⟩, h3⟩ := hc
    refine ⟨not_not.mp h1, ?_⟩
    cases hk : decide (P.kind s = SlotKind.host) <;> cases he : df.hosted.isEmpty <;> simp_all

section Steps

variable (H : HIn → Dig)

/-- **An accepting slot, with its schedule check and its accumulator.** -/
theorem slotStep_ok_fns (P : BlockParams) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (t : Tr) (r : SlotRec)
    (acc' : Acc) (t' : Tr) (h : slotStep H P s hist sp acc t = .ok (r, acc', t')) :
    ∃ df g rhoFull, P.define s hist r.draws = .ok df ∧ slotDefChecks P s acc df = .ok ()
      ∧ hostedSum acc.scalars sp.scalar df.hosted = .ok r.claimed ∧ r.scalar = sp.scalar
      ∧ acc' = slotAcc P s acc df r.c sp.scalar g rhoFull sp.terms := by
  unfold slotStep at h
  obtain ⟨df, hdf, h⟩ := ex_bind_ok h
  obtain ⟨u1, hu1, h⟩ := ex_bind_ok h
  obtain ⟨u2, -, h⟩ := ex_bind_ok h
  obtain ⟨u3, -, h⟩ := ex_bind_ok h
  obtain ⟨claimed, hcl, h⟩ := ex_bind_ok h
  obtain ⟨fr, -, h⟩ := ex_bind_ok h
  obtain ⟨fin, rhoFull⟩ := fr
  obtain ⟨vals, -, h⟩ := ex_bind_ok h
  obtain ⟨u4, -, h⟩ := ex_bind_ok h
  simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  exact ⟨df, _, rhoFull, hdf, hu1, hcl, rfl, rfl⟩

/-- **What an accepting slot leaves in the final accumulator**: its definition (from the records before it), its index
(their count), its claimed sum (the hosted sum of their scalars), its kind (a host exactly when its hosted list is
nonempty), and its `Γ` functional: a standalone's `⟨[(s, sw·c)], scalar⟩` in `acc.fs`, a host's
`⟨(s, sw_s·c) :: [(h, sw_h·(−κ·c_h))], scalar⟩` in `acc.hostFs` (`sw_t` slot `t`'s own sum weights, argument.rs:1500). -/
def SlotFns (P : BlockParams) (s : ℕ) (hist : Hist) (prev : List SlotRec) (sp : SlotProof) (r : SlotRec)
    (accF : Acc) : Prop :=
  ∃ df, P.define s hist r.draws = .ok df ∧ s = prev.length
    ∧ hostedSum (prev.map SlotRec.scalar) sp.scalar df.hosted = .ok r.claimed ∧ r.scalar = sp.scalar
    ∧ ((P.kind s = SlotKind.host) ↔ df.hosted ≠ [])
    ∧ (P.kind s = SlotKind.standalone →
        (⟨[(s, (swk P s).map (fun w => w.mul r.c))], sp.scalar⟩ : MaskFunctional) ∈ accF.fs)
    ∧ (P.kind s = SlotKind.host →
        (⟨(s, (swk P s).map (fun w => w.mul r.c)) :: df.hosted.map (fun hk => (hk.1,
          (swk P hk.1).map (fun w => w.mul (hk.2.mul ((prev.map SlotRec.c).getD hk.1 Fp2.zero)).neg))), sp.scalar⟩
          : MaskFunctional) ∈ accF.hostFs)

theorem slotAcc_hostFs_mono (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (c scalar g : Fp2)
    (rhoFull terms : List Fp2) (x : MaskFunctional) (hx : x ∈ acc.hostFs) :
    x ∈ (slotAcc P s acc df c scalar g rhoFull terms).hostFs := by
  unfold slotAcc
  simp only
  split
  · exact List.mem_append_left _ hx
  · exact hx

/-- **The slot loop, with every slot's functionals.** -/
theorem slotsLoop_fns (P : BlockParams) (b g a : Fp2) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr), acc.cs = recs.map SlotRec.c → acc.scalars = recs.map SlotRec.scalar →
      slotsLoop H P b g a recs j sps acc t = .ok (recs', acc', t') →
      (∀ x ∈ acc.fs, x ∈ acc'.fs) ∧ (∀ x ∈ acc.hostFs, x ∈ acc'.hostFs)
      ∧ ∃ rs, recs' = recs ++ rs ∧ rs.length = sps.length
        ∧ ∀ (i : ℕ) (sp : SlotProof) (r : SlotRec), sps[i]? = some sp → rs[i]? = some r →
          SlotFns P (j + i) (histOf b g a (recs ++ rs.take i)) (recs ++ rs.take i) sp r acc'
  | [], recs, j, acc, t, recs', acc', t', _, _, h => by
    simp only [slotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, -⟩ := h
    exact ⟨fun x hx => hx, fun x hx => hx, [], by simp, rfl, fun i sp r h1 _ => by simp at h1⟩
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', hcs, hsc, h => by
    simp only [slotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, g0, rhoFull, hdf, hchk, hcl, hs0, hacc0⟩ := slotStep_ok_fns H P j _ sp0 acc t r0 acc0 t0 hstep
      obtain ⟨hidx, hkind⟩ := slotDefChecks_ok P j acc df hchk
      have hcs0 : acc0.cs = (recs ++ [r0]).map SlotRec.c := by
        rw [hacc0, List.map_append, ← hcs]
        rfl
      have hsc0 : acc0.scalars = (recs ++ [r0]).map SlotRec.scalar := by
        rw [hacc0, List.map_append, ← hsc, List.map_singleton, hs0]
        rfl
      obtain ⟨hfs, hhf, rs, hrs, hlen, hall⟩ :=
        slotsLoop_fns P b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' hcs0 hsc0 h
      have hfs0 : ∀ x ∈ acc.fs, x ∈ acc0.fs := by
        rw [hacc0]
        exact fun x hx => slotAcc_fs_mono P j acc df _ _ _ rhoFull sp0.terms x hx
      have hhf0 : ∀ x ∈ acc.hostFs, x ∈ acc0.hostFs := by
        rw [hacc0]
        exact fun x hx => slotAcc_hostFs_mono P j acc df _ _ _ rhoFull sp0.terms x hx
      refine ⟨fun x hx => hfs x (hfs0 x hx), fun x hx => hhf x (hhf0 x hx), r0 :: rs,
        by rw [hrs, List.append_assoc, List.singleton_append], by simp [hlen], ?_⟩
      intro i sp r h1 h2
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
        subst sp r
        simp only [Nat.add_zero, List.take_zero, List.append_nil]
        unfold SlotFns
        refine ⟨df, hdf, by rw [hidx, hcs, List.length_map], by rw [← hsc]; exact hcl, hs0, hkind, ?_, ?_⟩
        · intro hk
          refine hfs _ ?_
          rw [hacc0]
          unfold slotAcc
          simp only [hk]
          exact List.mem_append_left _ (List.mem_append_right _ (List.mem_singleton_self _))
        · intro hk
          refine hhf _ ?_
          rw [hacc0]
          unfold slotAcc
          simp only [hk, ← hcs, swk]
          exact List.mem_append_right _ (List.mem_singleton_self _)
      | succ i =>
        simp only [List.getElem?_cons_succ] at h1 h2
        have hji : j + (i + 1) = j + 1 + i := by omega
        rw [hji]
        have e : recs ++ (r0 :: rs).take (i + 1) = recs ++ [r0] ++ rs.take i := by
          simp [List.take_succ_cons, List.append_assoc]
        rw [e]
        exact hall i sp r h1 h2

/-- **Every slot's functionals, on an accepting block slot phase.** -/
theorem blockSlots_fns (P : BlockParams) (core : Core) (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec)
    (acc : Acc) (t' : Tr) (hacc : blockSlots H P core t = .ok (bga, rs, acc, t')) :
    rs.length = core.slots.length ∧ ∀ k sp r, core.slots[k]? = some sp → rs[k]? = some r →
      SlotFns P k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) (rs.take k) sp r acc := by
  rw [blockSlots_eq] at hacc
  split at hacc
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hacc
    obtain ⟨hbga, hres⟩ := hacc
    subst hres
    subst hbga
    obtain ⟨-, -, rs', hrs', hlen, hall⟩ := slotsLoop_fns H P _ _ _ core.slots [] 0 {} _ rs acc t' rfl rfl hloop
    simp only [List.nil_append] at hrs'
    subst hrs'
    refine ⟨hlen, fun k sp r hsp hr => ?_⟩
    have := hall k sp r hsp hr
    simpa using this
  · cases hacc

end Steps

/-! ## In the field: the hosted sum, `M`'s linear reading, the unmasking -/

section K

variable {K : Type} [Field K] [Algebra GF K]

/-- **The hosted sum in the field**: every hosted index is an earlier slot, and the claimed sum is
`scalar + Σ κ·scalar_h`. -/
theorem hostedSum_spec (U : K) (hU : U ^ 2 = algebraMap GF K 7) :
    ∀ (scalars : List Fp2) (scalar : Fp2) (hosted : List (ℕ × Fp2)) (c : Fp2), scalar.Canon →
      hostedSum scalars scalar hosted = .ok c →
      (∀ hk ∈ hosted, hk.1 < scalars.length)
        ∧ c.toK U = scalar.toK U + (hosted.map (fun hk => hk.2.toK U * (scalars.getD hk.1 Fp2.zero).toK U)).sum
  | _, _, [], c, hs, h => by
    simp only [hostedSum, Except.ok.injEq] at h
    subst h
    simp
  | scalars, scalar, (hs, coef) :: rest, c, hsc, h => by
    simp only [hostedSum] at h
    split at h
    · rename_i hlt
      obtain ⟨h1, h2⟩ := hostedSum_spec U hU scalars _ rest c (Fp2.canon_add _ _) h
      refine ⟨fun hk hk' => ?_, ?_⟩
      · rcases List.mem_cons.mp hk' with rfl | hk'
        · exact hlt
        · exact h1 hk hk'
      · rw [h2, Fp2.toK_add U _ _ hsc (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
        simp only [List.map_cons, List.sum_cons]
        ring
    · cases h

/-- **`M`'s functional term on extracted mask rows** `R` (row width `Wd`): `Σ_{j < Wd} w_j·R_slot(j)`. -/
def mdot (U : K) (R : ℕ → ℕ → K) (Wd : ℕ) (t : ℕ × List Fp2) : K :=
  ((List.range Wd).map (fun j => (t.2.getD j Fp2.zero).toK U * R t.1 j)).sum

/-- **`msX` reads `M`'s functionals linearly on extracted mask rows**: the value of a functional is the sum of its
terms' `mdot`. -/
def MLin (U : K) (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) : Prop :=
  ∀ ts, ms ts = (ts.map (mdot U R Wd)).sum

theorem getD_map_mul_toK (U : K) (hU : U ^ 2 = algebraMap GF K 7) (c : Fp2) :
    ∀ (w : List Fp2) (j : ℕ), ((w.map (fun x => x.mul c)).getD j Fp2.zero).toK U = (w.getD j Fp2.zero).toK U * c.toK U
  | [], _ => by simp [Fp2.toK_zero U]
  | _ :: _, 0 => by simp [Fp2.toK_mul U hU]
  | _ :: w, j + 1 => by simpa using getD_map_mul_toK U hU c w j

omit [Algebra GF K] in
theorem list_sum_map_mul {α : Type} (f : α → K) (a : K) (l : List α) :
    (l.map (fun x => a * f x)).sum = a * (l.map f).sum := by
  induction l with
  | nil => simp
  | cons x l ih => simp only [List.map_cons, List.sum_cons, ih]; ring

/-- Scaling every weight by `c` scales the term by `c`. -/
theorem mdot_scale (U : K) (hU : U ^ 2 = algebraMap GF K 7) (R : ℕ → ℕ → K) (Wd : ℕ) (s : ℕ) (w : List Fp2)
    (c : Fp2) : mdot U R Wd (s, w.map (fun x => x.mul c)) = c.toK U * mdot U R Wd (s, w) := by
  unfold mdot
  simp only
  rw [← list_sum_map_mul]
  refine congrArg List.sum (List.map_congr_left fun j _ => ?_)
  simp only [getD_map_mul_toK U hU c w j]
  ring

/-- **The CFS unmasking on acceptance** (generic in the block shape). On an accepting slot phase of a canonical core,
with `M`'s functionals true of `ms` (`MTrue` over `acc.fs ++ acc.hostFs`, as `OpenTrue` gives), `ms` linear on the
extracted mask rows `R` (`MLin`), and every claimed sum `Sp_k + c_k·mdot_k(sw_k)` (the cube sum of the masked slot
polynomial: its unmasked part `Sp_k` and its mask's cube sum at the slot's own sum weights): a standalone slot's
unmasked sum is `0`, and a host's (whose hosted slots are not hosts) is `Σ_h κ_h·Sp_h`: the scalars and every mask drop
out (each hosted mask weighted by its own sum weights, the corrected model of finding L23-1). -/
theorem unmask_slots (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (P : BlockParams) (core : Core)
    (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hacc : blockSlots H P core t = .ok (bga, rs, acc, t')) (hcan : CoreCanon core)
    (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) (hlin : MLin U ms R Wd)
    (hm : MTrue U ms (acc.fs ++ acc.hostFs)) (Sp : ℕ → K)
    (hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U = Sp k + r.c.toK U * mdot U R Wd (k, swk P k))
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) (df : SlotDef)
    (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df) :
    (P.kind k = SlotKind.standalone → Sp k = 0)
    ∧ (P.kind k = SlotKind.host → (∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host) →
        Sp k = (df.hosted.map (fun hk => hk.2.toK U * Sp hk.1)).sum) := by
  obtain ⟨hlen, hall⟩ := blockSlots_fns H P core t bga rs acc t' hacc
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
  refine ⟨fun hst => ?_, fun hho hpriv => ?_⟩
  · -- a standalone slot: hosted list empty, claimed = scalar = c·Σ mask
    have hne : df.hosted = [] := by
      by_contra hne
      have := hkind.mpr hne
      rw [hst] at this
      cases this
    have hΓ := hm _ (List.mem_append_left _ (hstd hst))
    rw [hlin] at hΓ
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero] at hΓ
    rw [mdot_scale U hU] at hΓ
    rw [hne] at hcs
    simp only [List.map_nil, List.sum_nil, add_zero] at hcs
    have h1 := hcl k r hr
    rw [hcs] at h1
    linear_combination -h1 - hΓ
  · -- a host: its Γ, its hosted private slots' claimed sums
    have hΓ := hm _ (List.mem_append_right _ (hhost hho))
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
    -- each hosted slot is private: its claimed sum is its scalar
    have hsub : ∀ hk ∈ df.hosted, ((rs.take k).map SlotRec.scalar).getD hk.1 Fp2.zero
        = ((rs.take k).map SlotRec.claimed).getD hk.1 Fp2.zero := by
      intro hk hmem
      have hlt' := hlt hk hmem
      rw [List.length_map, List.length_take] at hlt'
      have hh : hk.1 < k := lt_of_lt_of_le hlt' (min_le_left _ _)
      have hhr : hk.1 < rs.length := lt_of_lt_of_le hlt' (min_le_right _ _)
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
    -- `hΓ`: scalar = c·mdot(sw) − Σ κ·c_h·mdot_h(sw_h): the hosted masks cancel
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

/-- **A host's unmasked sum on acceptance**, the host half of `unmask_slots`: `Σ_h κ_h·Sp_h` over its hosted private
slots (`RelW16Host.unmask_host`'s conclusion, on the verifier's acceptance; each hosted mask weighted by its own sum
weights, argument.rs:1500, the corrected model of finding L23-1). -/
theorem unmask_slots_eq (U : K) (hU : U ^ 2 = algebraMap GF K 7) (H : HIn → Dig) (P : BlockParams) (core : Core)
    (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hacc : blockSlots H P core t = .ok (bga, rs, acc, t')) (hcan : CoreCanon core)
    (ms : List (ℕ × List Fp2) → K) (R : ℕ → ℕ → K) (Wd : ℕ) (hlin : MLin U ms R Wd)
    (hm : MTrue U ms (acc.fs ++ acc.hostFs)) (Sp : ℕ → K)
    (hcl : ∀ k r, rs[k]? = some r → r.claimed.toK U = Sp k + r.c.toK U * mdot U R Wd (k, swk P k))
    (k : ℕ) (r : SlotRec) (hr : rs[k]? = some r) (df : SlotDef)
    (hdf : P.define k (histOf bga.1 bga.2.1 bga.2.2 (rs.take k)) r.draws = .ok df)
    (hho : P.kind k = SlotKind.host) (hpriv : ∀ hk ∈ df.hosted, P.kind hk.1 ≠ SlotKind.host) :
    Sp k = (df.hosted.map (fun hk => hk.2.toK U * Sp hk.1)).sum :=
  (unmask_slots U hU H P core t bga rs acc t' hacc hcan ms R Wd hlin hm Sp hcl k r hr df hdf).2 hho hpriv

end K

end ZK60.Exec.Block
