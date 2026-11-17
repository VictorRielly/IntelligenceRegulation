/-
D63 lane L63 (2026-11-16), part 23: **the tie of stage IN-C's two IO-claims forms** (`StgClaimsIOC` ⇒ `StgClaimsIOS`).

* `StageV.ssh_stSlotsLoop_mem`: the code's slot loop (`stSlotsLoop`, each slot at its own IO width) keeps every claim it
  held and, for every accepted slot, holds every claim that slot builds at its width (the twin of L13's
  `slotsLoop_terminal` claims part);
* `ssh_inc_link_code`: at every reading, the code's slot loop accepts on the reading's records (`stSlotsLoop_strip` via
  `incSlots_model`) and the run's IN-C reader (`rsAccInc`) at the slot phase's end returns its accumulator;
* **`ssh_iosOfIOC`**: the accumulator form `StgClaimsIOC` (every IO claim of the code's accumulator true) gives the
  per-slot form `StgClaimsIOS` that `stgFR_termAtC` consumes.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldC

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block

section Mem

variable (H : HIn → Dig)

/-- **The code's slot loop holds every claim each accepted slot builds at its own IO width.** -/
theorem ssh_stSlotsLoop_mem (P : BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    ∀ (sps : List SlotProof) (recs : List SlotRec) (j : ℕ) (acc : Acc) (t : Tr) (recs' : List SlotRec) (acc' : Acc)
      (t' : Tr), stSlotsLoop H P elog b g a recs j sps acc t = .ok (recs', acc', t') →
      (∀ (cm : Block.Cm) (x : Block.ZClaim), x ∈ acc.claims.get cm → x ∈ acc'.claims.get cm)
      ∧ ∃ rs, recs' = recs ++ rs
        ∧ ∀ (i : ℕ) (sp : SlotProof) (r : SlotRec), sps[i]? = some sp → rs[i]? = some r →
          ∃ df, P.define (j + i) (histOf b g a (recs ++ rs.take i)) r.draws = .ok df
            ∧ ∀ q ∈ slotClaimList (atLog P (elog (j + i))) r.rho r.es sp.terms df.tabs 0, q.2 ∈ acc'.claims.get q.1
  | [], recs, j, acc, t, recs', acc', t', h => by
    simp only [stSlotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, -⟩ := h
    exact ⟨fun _ _ hx => hx, [], by simp, fun i sp r h1 _ => by simp at h1⟩
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', h => by
    simp only [stSlotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, vals, rhoFull, hdf, -, -, -, hrho, hes, -, hacc0⟩ :=
        slotStep_ok_terminal H (atLog P (elog j)) j _ sp0 acc t r0 acc0 t0 hstep
      obtain ⟨hcl, rs, hrs, hall⟩ :=
        ssh_stSlotsLoop_mem P elog b g a sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' h
      have hcl0 : ∀ (cm : Block.Cm) (x : Block.ZClaim), x ∈ acc.claims.get cm → x ∈ acc0.claims.get cm := by
        rw [hacc0, slotAcc_claims]
        exact fun cm x hx => slotClaims_mono _ _ _ sp0.terms df.tabs 0 acc.claims cm x hx
      refine ⟨fun cm x hx => hcl cm x (hcl0 cm x hx), r0 :: rs,
        by rw [hrs, List.append_assoc, List.singleton_append], ?_⟩
      intro i sp r h1 h2
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
        subst sp r
        have hdf' : P.define j (histOf b g a recs) r0.draws = .ok df := hdf
        refine ⟨df, by simpa [histOf] using hdf', ?_⟩
        intro q hq
        rw [Nat.add_zero] at hq
        refine hcl q.1 q.2 ?_
        rw [hacc0, slotAcc_claims, ← hrho, ← hes]
        exact slotClaims_mem (atLog P (elog j)) r0.rho r0.es sp0.terms df.tabs 0 acc.claims q hq
      | succ i =>
        simp only [List.getElem?_cons_succ] at h1 h2
        obtain ⟨df', hdf', hcl'⟩ := hall i sp r h1 h2
        have hji : j + (i + 1) = j + 1 + i := by omega
        rw [hji]
        exact ⟨df', by simpa [histOf, List.append_assoc] using hdf', hcl'⟩

end Mem

end ZK60.Exec.StageV

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV incHeadDraws incCtx incElog)
open ZK60.Circuit (gP GF)

section Link

variable {L : ℕ}

/-- **At a reading, the code's slot loop accepts on the reading's records, and the run's IN-C reader at the slot
phase's end returns its accumulator.** -/
theorem ssh_inc_link_code (key : Option Dig) (domain : List UInt8) (V : IncV) (m hdrLen e : ℕ)
    (hm : incHeadDraws V.pub = m) (G : QB L → Dig) (τ : List (TItem × Dig)) (hdr : List Op) (core : Block.Core)
    (ch : List Fp2) (rs : List Block.SlotRec)
    (hrd : StgRd key domain L (fun ch => V.bp (incCtx V.pub ch)) m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) G
      τ hdr core ch rs)
    (hgt : V.geom.slots.length = V.geom.terms.length)
    (hd : ∀ cx k, k < V.geom.slots.length → 1 ≤ (Block.slotShape (V.bp cx) k).2.2)
    (he : ∀ cx, e = hdrLen + (7 + m) + shapeLen (V.bp cx) 0 V.geom.slots)
    (acc : Block.Acc) (t' : Tr)
    (hacc : StageFS.stageSlots (liftH G) (V.bp (incCtx V.pub ch)) m (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core
      (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr) = .ok (ch, rs, acc, t')) :
    ∃ accr t4, StageV.stSlotsLoop (liftH G) (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero
        Fp2.zero [] 0 core.slots {}
        (V.slotT (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)) = .ok (rs, accr, t4)
      ∧ rsAccInc V hdrLen (τ.take e) = accr := by
  subst hm
  have htk := ssh_stage_take key domain (fun ch => V.bp (incCtx V.pub ch)) (incHeadDraws V.pub) hdrLen _ G τ hdr core
    ch rs hrd hgt
  obtain ⟨hhl, -, hcan, hsh, -, -⟩ := hrd
  have htk' : τ.take e = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
      (hdr ++ StageFS.stageRootOps (V.bp (incCtx V.pub ch)) core (incHeadDraws V.pub)
        ++ Block.fullOps (V.bp (incCtx V.pub ch)) 0 core.slots) := by
    rw [he (incCtx V.pub ch)]
    exact htk
  rw [htk']
  have hch : (V.headCh (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)).1 = ch := by
    have h := hacc
    unfold StageFS.stageSlots at h
    dsimp only at h
    split at h
    · simp only [Except.ok.injEq, Prod.mk.injEq] at h
      exact h.1
    · cases h
  subst hch
  have hm2 := StageV.incSlots_model (liftH G) V core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)
  rw [hacc] at hm2
  obtain ⟨⟨recs, accr, t4⟩, hs, hy⟩ := (StageV.map_ok_iff _ _ _).mp hm2
  have hrec : recs = rs := by
    have h := congrArg (fun x => x.1.2) hy
    simpa using h
  subst hrec
  have hr := ZK60.ProtocolClassify.rs_accInc_trace (liftH G) V core hdr (Tr.newKeyed (liftH G) domain key) recs accr
    t4 (incCtx V.pub (V.headCh (liftH G) core (runOps (liftH G) (Tr.newKeyed (liftH G) domain key) hdr)).1) hcan.1
    hsh.1 hd hs
  rw [hhl] at hr
  exact ⟨accr, t4, hs, hr⟩

end Link

section Tie

variable {K : Type} [Field K] [Algebra GF K] {L : ℕ}

/-- **THE TIE: STAGE IN-C'S IO CLAIMS OVER THE CODE'S ACCUMULATOR GIVE THEM PER SLOT AT THE CODE'S WIDTHS**
(`StgClaimsIOC` ⇒ `StgClaimsIOS`, for any reader width `elogv` that reads the stage's `incElog`). -/
theorem ssh_iosOfIOC (U : K) (key : Option Dig) (domain : List UInt8) (V : IncV) (m hdrLen e : ℕ)
    (hm : incHeadDraws V.pub = m) (absOf : QB L → Option (List UInt8)) (elogv : StgVw L → ℕ → ℕ)
    (hel : ∀ v k, elogv v k = incElog V.pub V.geo.bLogN k)
    (csv : StgVw L → Block.Cm → Block.ZClaim → K) (G : QB L → Dig) (Lg : List (QB L × Dig)) (τ : List (TItem × Dig))
    (hgt : V.geom.slots.length = V.geom.terms.length)
    (hd : ∀ cx k, k < V.geom.slots.length → 1 ≤ (Block.slotShape (V.bp cx) k).2.2)
    (he : ∀ cx, e = hdrLen + (7 + m) + shapeLen (V.bp cx) 0 V.geom.slots)
    (hIOC : StgClaimsIOC U key domain V m hdrLen e absOf csv G Lg τ) :
    StgClaimsIOS U key domain (fun ch => V.bp (incCtx V.pub ch)) m hdrLen (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero))
      absOf elogv csv G Lg τ := by
  intro hdr core ch rs hrd k q hq r df hr hdf q' hq' hio
  obtain ⟨hI, hO⟩ := hIOC hdr core ch rs hrd k q hq
  obtain ⟨acc, t', hacc⟩ := hrd.2.2.2.2.1
  obtain ⟨accr, t4, hs, hra⟩ := ssh_inc_link_code key domain V m hdrLen e hm G τ hdr core ch rs hrd hgt hd he acc t'
    hacc
  obtain ⟨-, rs', hrs', hall⟩ := StageV.ssh_stSlotsLoop_mem (liftH G) _ _ _ _ _ core.slots [] 0 {} _ rs accr t4 hs
  rw [List.nil_append] at hrs'
  subst hrs'
  obtain ⟨df', hdf', hmem⟩ := hall k q r hq hr
  rw [Nat.zero_add, List.nil_append] at hdf'
  rw [Nat.zero_add] at hmem
  have hdd : (Except.ok df' : Except String Block.SlotDef) = .ok df := hdf'.symm.trans hdf
  cases hdd
  rw [hel] at hq'
  have hz := hmem q' hq'
  rw [← hra] at hz
  obtain ⟨c1, z1⟩ := q'
  cases c1 with
  | a => rcases hio with h | h <;> cases h
  | h => rcases hio with h | h <;> cases h
  | inp => exact hI z1 hz
  | out => exact hO z1 hz

end Tie

end ZK60.ProtocolClassify
