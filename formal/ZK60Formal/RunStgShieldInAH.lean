/-
D63 lane L63 (2026-11-16), part 12: **stage IN-C's `A`/`H` claims: the code and L15's model agree on them**
(item (iv), step A).

L29's `incSlots_model` equates the code's IN-C slot loop (`stSlotsLoop`, each slot at its own IO width) with L15's model
(`slotsLoop` at one width) only up to `accStrip`, which drops the claims (finding L63-5). The `A` and `H` claims do not
depend on the IO width (`rowLog` of `.a`, `.h` is `logCols`), so the two loops agree on them too:

* `ssh_sc_a`, `ssh_sc_h`: a slot's `A` (`H`) claims are the incoming ones followed by those its tables build, at any
  `BlockParams` with the same `logCols`;
* `ahR`, `ahL`, **`ssh_slotStep_ah`**, **`ssh_stSlotsLoop_ah`**: one slot, and the whole loop, keep `accStrip` AND the
  `A`, `H` claims (`stSlotsLoop_strip` with the `A`, `H` claims kept);
* **`ssh_inc_claims_ah`**: the code's `IncV.slots` and L15's model have the same `A` and `H` claims.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldClaimsRun

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60.Exec ZK60.Exec.Block

section AH

/-- A slot's `A` claims at any `BlockParams` `Q` with `P`'s column log: the incoming ones, then those its tables build. -/
theorem ssh_sc_a (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (tabs : List Tab) (Q : BlockParams) (k : ℕ) (cl : Claims4), Q.logCols = P.logCols →
      (slotClaims Q rho es terms tabs k cl).a = cl.a ++ (slotClaims P rho es terms tabs k {}).a
  | [], _, _, cl, _ => by simp [slotClaims]
  | .priv p :: ts, Q, k, cl, hQ => by
    show (slotClaims Q rho es terms ts (k + 1) (cl.push p.cm (buildClaim Q p (claimPoint p rho) (oneMinusProd es)
        (maskCoef es p.extRound) (terms.getD k Fp2.zero)))).a
      = cl.a ++ (slotClaims P rho es terms ts (k + 1) (({} : Claims4).push p.cm (buildClaim P p (claimPoint p rho)
        (oneMinusProd es) (maskCoef es p.extRound) (terms.getD k Fp2.zero)))).a
    conv_rhs => rw [ssh_sc_a P rho es terms ts P (k + 1) _ rfl]
    rw [ssh_sc_a P rho es terms ts Q (k + 1) _ hQ]
    have hb : p.cm = .a → buildClaim Q p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero) = buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero) := by
      intro hc
      unfold buildClaim
      simp only [hc, rowLog, hQ]
    cases hc : p.cm with
    | a => simp only [Claims4.push, hb hc, List.append_assoc, List.nil_append]
    | h => simp [Claims4.push]
    | inp => simp [Claims4.push]
    | out => simp [Claims4.push]
  | .eq pt st :: ts, Q, k, cl, hQ => ssh_sc_a P rho es terms ts Q k cl hQ
  | .pub w :: ts, Q, k, cl, hQ => ssh_sc_a P rho es terms ts Q k cl hQ

/-- The same for the `H` claims. -/
theorem ssh_sc_h (P : BlockParams) (rho es terms : List Fp2) :
    ∀ (tabs : List Tab) (Q : BlockParams) (k : ℕ) (cl : Claims4), Q.logCols = P.logCols →
      (slotClaims Q rho es terms tabs k cl).h = cl.h ++ (slotClaims P rho es terms tabs k {}).h
  | [], _, _, cl, _ => by simp [slotClaims]
  | .priv p :: ts, Q, k, cl, hQ => by
    show (slotClaims Q rho es terms ts (k + 1) (cl.push p.cm (buildClaim Q p (claimPoint p rho) (oneMinusProd es)
        (maskCoef es p.extRound) (terms.getD k Fp2.zero)))).h
      = cl.h ++ (slotClaims P rho es terms ts (k + 1) (({} : Claims4).push p.cm (buildClaim P p (claimPoint p rho)
        (oneMinusProd es) (maskCoef es p.extRound) (terms.getD k Fp2.zero)))).h
    conv_rhs => rw [ssh_sc_h P rho es terms ts P (k + 1) _ rfl]
    rw [ssh_sc_h P rho es terms ts Q (k + 1) _ hQ]
    have hb : p.cm = .h → buildClaim Q p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero) = buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound)
        (terms.getD k Fp2.zero) := by
      intro hc
      unfold buildClaim
      simp only [hc, rowLog, hQ]
    cases hc : p.cm with
    | a => simp [Claims4.push]
    | h => simp only [Claims4.push, hb hc, List.append_assoc, List.nil_append]
    | inp => simp [Claims4.push]
    | out => simp [Claims4.push]
  | .eq pt st :: ts, Q, k, cl, hQ => ssh_sc_h P rho es terms ts Q k cl hQ
  | .pub w :: ts, Q, k, cl, hQ => ssh_sc_h P rho es terms ts Q k cl hQ

theorem ssh_sc_a_atLog (P : BlockParams) (e : ℕ) (rho es terms : List Fp2) (tabs : List Tab) (k : ℕ) (cl : Claims4) :
    (slotClaims (atLog P e) rho es terms tabs k cl).a = cl.a ++ (slotClaims P rho es terms tabs k {}).a :=
  ssh_sc_a P rho es terms tabs (atLog P e) k cl rfl

theorem ssh_sc_h_atLog (P : BlockParams) (e : ℕ) (rho es terms : List Fp2) (tabs : List Tab) (k : ℕ) (cl : Claims4) :
    (slotClaims (atLog P e) rho es terms tabs k cl).h = cl.h ++ (slotClaims P rho es terms tabs k {}).h :=
  ssh_sc_h P rho es terms tabs (atLog P e) k cl rfl

/-- What a slot leaves, with its `A` and `H` claims kept. -/
def ahR (x : SlotRec × Acc × Tr) :
    SlotRec × ((List Fp2 × List Fp2 × List Block.MaskFunctional × List Block.MaskFunctional) × List Block.ZClaim × List Block.ZClaim) × Tr :=
  (x.1, (accStrip x.2.1, x.2.1.claims.a, x.2.1.claims.h), x.2.2)

/-- What a slot loop leaves, with its `A` and `H` claims kept. -/
def ahL (x : List SlotRec × Acc × Tr) :
    List SlotRec × ((List Fp2 × List Fp2 × List Block.MaskFunctional × List Block.MaskFunctional) × List Block.ZClaim × List Block.ZClaim) × Tr :=
  (x.1, (accStrip x.2.1, x.2.1.claims.a, x.2.1.claims.h), x.2.2)

variable (H : HIn → Dig)

/-- **A slot's IO width changes neither its `A` nor its `H` claims** (`slotStep_strip` with them kept). -/
theorem ssh_slotStep_ah (P : BlockParams) (e : ℕ) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (cl : Claims4)
    (t : Tr) (ha : cl.a = acc.claims.a) (hh : cl.h = acc.claims.h) :
    ahR <$> slotStep H (atLog P e) s hist sp { acc with claims := cl } t = ahR <$> slotStep H P s hist sp acc t := by
  simp only [slotStep, map_bind, map_pure, ahR, slotAcc, ssh_sc_a_atLog, ssh_sc_h_atLog,
    ssh_sc_a P _ _ _ _ P _ acc.claims rfl, ssh_sc_h P _ _ _ _ P _ acc.claims rfl, ha, hh]
  rfl

/-- **The code's IN-C slot loop and L15's model have the same records, transcript, functionals and `A`, `H` claims.** -/
theorem ssh_stSlotsLoop_ah (P : BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) :
    ∀ (recs : List SlotRec) (s : ℕ) (sps : List SlotProof) (acc : Acc) (cl : Claims4) (t : Tr),
      cl.a = acc.claims.a → cl.h = acc.claims.h →
      ahL <$> stSlotsLoop H P elog b g a recs s sps { acc with claims := cl } t
        = ahL <$> slotsLoop H P b g a recs s sps acc t
  | recs, s, [], acc, cl, t, ha, hh => by
    show Except.ok (recs, (accStrip acc, cl.a, cl.h), t) = Except.ok (recs, (accStrip acc, acc.claims.a, acc.claims.h), t)
    rw [ha, hh]
  | recs, s, sp :: sps, acc, cl, t, ha, hh => by
    have h1 := ssh_slotStep_ah H P (elog s) s (histOf b g a recs) sp acc cl t ha hh
    simp only [stSlotsLoop, slotsLoop]
    rcases hB : slotStep H P s (histOf b g a recs) sp acc t with e | ⟨r₂, ⟨c₂, s₂, l₂, f₂, g₂⟩, t₂⟩
    · rw [hB] at h1
      have hA : slotStep H (atLog P (elog s)) s (histOf b g a recs) sp { acc with claims := cl } t = .error e :=
        (map_error_iff ahR _ e).mp h1
      rw [hA]
    · rw [hB] at h1
      obtain ⟨⟨r, ⟨c₁, s₁, l₁, f₁, g₁⟩, t'⟩, hA, hy⟩ := (map_ok_iff ahR _ _).mp h1
      rw [hA]
      have hy' : (r, ((c₁, s₁, f₁, g₁), l₁.a, l₁.h), t') = (r₂, ((c₂, s₂, f₂, g₂), l₂.a, l₂.h), t₂) := hy
      simp only [Prod.mk.injEq] at hy'
      obtain ⟨rfl, ⟨⟨rfl, rfl, rfl, rfl⟩, hla, hlh⟩, rfl⟩ := hy'
      exact ssh_stSlotsLoop_ah P elog b g a _ _ sps ⟨c₁, s₁, l₂, f₁, g₁⟩ l₁ t' hla hlh

/-- **STAGE IN-C: THE CODE'S SLOT PHASE AND L15'S MODEL HAVE THE SAME `A` AND `H` CLAIMS.** -/
theorem ssh_inc_claims_ah (V : IncV) (core : Core) (t : Tr) (recs : List SlotRec) (accr : Acc) (t4 : Tr)
    (hs : V.slots H core t = .ok (recs, accr, t4)) (rs : List SlotRec) (acc : Acc) (t' : Tr)
    (hm : StageFS.stageSlots H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incHeadDraws V.pub)
      (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core t = .ok ((V.headCh H core t).1, rs, acc, t')) :
    accr.claims.a = acc.claims.a ∧ accr.claims.h = acc.claims.h := by
  have hl := ssh_stSlotsLoop_ah H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN)
    Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {} {} (V.slotT H core t) rfl rfl
  have hl' : ahL <$> stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {} (V.slotT H core t)
      = ahL <$> slotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {}
        (V.slotT H core t) := hl
  have hs' : stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {} (V.slotT H core t) = .ok (recs, accr, t4) := hs
  rw [StageFS.stageSlots_eq] at hm
  split at hm
  · rename_i res hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at hm
    obtain ⟨-, hres⟩ := hm
    subst hres
    have hloop' : slotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {}
        (V.slotT H core t) = .ok (rs, acc, t') := by
      rw [ZK60.ProtocolClassify.rt_incSlotT H V core t (incCtx V.pub (V.headCh H core t).1)]
      exact hloop
    rw [hs', hloop'] at hl'
    have h3 : ahL (recs, accr, t4) = ahL (rs, acc, t') := Except.ok.inj hl'
    simp only [ahL, Prod.mk.injEq] at h3
    obtain ⟨-, ⟨-, ha, hh⟩, -⟩ := h3
    exact ⟨ha, hh⟩
  · cases hm

end AH

end ZK60.Exec.StageV
