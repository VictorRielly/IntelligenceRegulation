/-
D63 lane L68c, part 3c (`HonestShieldRunProg.lean`):
1. Generic `buildClaim` / `logupSumClaim` / `BndCarryOk` audit master theorems and unified
   `CollPlan` / `symCollFamily` / `openAuditOk_of_symSpec` engine discharging `OpenAuditOk`
   for all non-boundary commitment openings.
2. Whole-run deterministic witness (`ShdRunWitness`) and 28-segment transcript program
   (`shdP_incEndProg`, `shdP_blkBodyProg`, `shdP_runPreBlk`, `shdP_runProg`) with `TProg.Sep`
   and exact `SqLE` bounds (`515`, `515 + k * 10359`, `270492`), recursive in `k : ℕ` (never unrolled).
3. Stage IN-C `OpenCollFamily` (`shdP_incCollA`, `shdP_incCollH`) and `shdP_inc_audit_and_carry`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); never unfolds
`clog2 131072`, `embFoldL`, `tauTable`, `shdVi`, `shdVo`, `shdP_Pk0`, or `pubsR13L`.
-/
import ZK60Formal.HonestShieldSegRefusal

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.TokenRun
open ZK60.Exec.StageCheck (kI)
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestOracle ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldExport shieldExport_l17 shieldCal shieldS0 shieldShape ShieldRun)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec SlotKind SlotS Tab TabS Priv PrivS
  Coord CoordS Sym Claims4 histOf slotShape slotTerms slotDefChecks hostedSum tabVals
  maskCoef oneMinusProd buildClaim claimPoint rowLog fp2U labA labH labM absorbRoot defineS defineS_ok)

/-! ## 1. Generic Round-Prefix Programs, `famProve` Claims, `buildClaim` Audit & `CollPlan` Engine -/

section GenericAudit

def rec0 : SlotRec := ⟨[], Fp2.zero, Fp2.zero, Fp2.zero, [], [], [], Fp2.zero⟩
def zpart0 : Exec.Block.ZPart := ⟨0, 0, Fp2.zero, []⟩
def zclaim0 : Exec.Block.ZClaim := ⟨[], Fp2.zero⟩

def claimsCm (cl : Claims4) : Cm → List Exec.Block.ZClaim
  | .a => cl.a | .h => cl.h | .inp => cl.inp | .out => cl.out

def privsCm (cm : Cm) : List Tab → List Priv
  | [] => []
  | .priv p :: ts => if p.cm = cm then p :: privsCm cm ts else privsCm cm ts
  | _ :: ts => privsCm cm ts

def privsCmS (cm : Cm) : List TabS → List PrivS
  | [] => []
  | .priv p :: ts => if p.cm = cm then p :: privsCmS cm ts else privsCmS cm ts
  | _ :: ts => privsCmS cm ts

theorem flatMap_congr_eq {α β : Type} {l : List α} {f g : α → List β} (h : ∀ x ∈ l, f x = g x) :
    l.flatMap f = l.flatMap g := by
  induction l with
  | nil => rfl
  | cons a tl ih =>
    rw [List.flatMap_cons, List.flatMap_cons, h a List.mem_cons_self,
      ih (fun x hx => h x (List.mem_cons_of_mem a hx))]

theorem privsCm_map_eval (ev : Sym → Fp2) (pub : ℕ → List Fp2) (cm : Cm) :
    ∀ ts : List TabS, privsCm cm (ts.map (TabS.eval ev pub)) = (privsCmS cm ts).map (PrivS.eval ev)
  | [] => rfl
  | .eq _ _ :: ts => privsCm_map_eval ev pub cm ts
  | .pub _ :: ts => privsCm_map_eval ev pub cm ts
  | .priv p :: ts => by
    show (if p.cm = cm then p.eval ev :: privsCm cm (ts.map (TabS.eval ev pub))
        else privsCm cm (ts.map (TabS.eval ev pub)))
      = (if p.cm = cm then p :: privsCmS cm ts else privsCmS cm ts).map (PrivS.eval ev)
    by_cases h : p.cm = cm
    · rw [ite_eq_left h, ite_eq_left h, List.map_cons, privsCm_map_eval ev pub cm ts]
    · rw [ite_eq_right h, ite_eq_right h, privsCm_map_eval ev pub cm ts]

theorem claimsCm_push (cl : Claims4) (cm₁ cm₂ : Cm) (z : Exec.Block.ZClaim) :
    claimsCm (cl.push cm₁ z) cm₂ = if cm₁ = cm₂ then claimsCm cl cm₂ ++ [z] else claimsCm cl cm₂ := by
  cases cm₁ <;> cases cm₂ <;> rfl

theorem slotClaims_parts (P : BlockParams) (rho es terms : List Fp2) (cm : Cm) :
    ∀ (ts : List Tab) (k : ℕ) (cl : Claims4),
      (claimsCm (Block.slotClaims P rho es terms ts k cl) cm).map Exec.Block.ZClaim.parts
        = (claimsCm cl cm).map Exec.Block.ZClaim.parts
          ++ (privsCm cm ts).map (fun p =>
              (buildClaim P p (claimPoint p rho) (oneMinusProd es) (maskCoef es p.extRound) Fp2.zero).parts)
  | [], _, _ => by simp [Block.slotClaims, privsCm]
  | .eq _ _ :: ts, k, cl => slotClaims_parts P rho es terms cm ts k cl
  | .pub _ :: ts, k, cl => slotClaims_parts P rho es terms cm ts k cl
  | .priv p :: ts, k, cl => by
    unfold Block.slotClaims privsCm
    rw [slotClaims_parts P rho es terms cm ts (k + 1) (cl.push p.cm _), claimsCm_push]
    by_cases h : p.cm = cm
    · rw [ite_eq_left h, ite_eq_left h, List.map_append, List.map_singleton, List.map_cons,
        List.append_assoc, List.singleton_append]; rfl
    · rw [ite_eq_right h, ite_eq_right h]

/-- Slot round-prefix program returning BOTH `(x, recs, acc)` AND slot `i`'s `define` draws `dr`. -/
def depRoundDrProg {α : Type} (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) :
    TProg ((α × List SlotRec × Acc) × List Fp2) :=
  bindP (depCProg Pf pre i) (fun yd => .squeeze (fun dgc =>
    bindP (slotEAfter (Pf yd.1.1 i) i (Df yd.1.1 i) m
      (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.1.2.2 (challengeFp2Of dgc)
      ((Pf yd.1.1 i).define i (histOf (bga yd.1.1).1 (bga yd.1.1).2.1 (bga yd.1.1).2.2 yd.1.2.1) yd.2))
      (fun _ => .done yd)))

theorem sep_depRoundDrProg {α : Type} (key : Option Dig) (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) (hp : TProg.Sep key pre) :
    TProg.Sep key (depRoundDrProg Pf Df bga pre i m) :=
  sep_bindP key _ _ (sep_depCProg Pf key pre i hp) (fun _ _ =>
    sep_bindP key _ _ (sep_slotEAfter _ _ _ key m _ _ _ _) (fun _ => trivial))

theorem sqLE_depRoundDrProg {α : Type} (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i r m dmax : ℕ)
    (hp : SqLE m pre) (hd : ∀ x, (Pf x i).draws i ≤ dmax) :
    SqLE (m + dmax + 1 + r) (depRoundDrProg Pf Df bga pre i r) := by
  unfold depRoundDrProg
  rw [show m + dmax + 1 + r = (m + dmax) + (r + 1) by omega]
  refine sqLE_bindP _ _ (m + dmax) (r + 1) (sqLE_depCProg Pf pre i m dmax hp hd) (fun yd _ => ?_)
  exact sqLE_mono _ (r + 0) r (sqLE_bindP _ _ r 0 (sqLE_slotEAfter _ _ _ _ _ _ _ _) (fun _ => trivial)) (by omega)

theorem final_depRoundDrProg_chal {α : Type} (H : HIn → Dig) (Pf : α → ℕ → BlockParams)
    (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (pre : TProg (α × List SlotRec × Acc)) (i m : ℕ) (t ti : Tr) (x : α)
    (recs : List SlotRec) (acc : Acc) (hY : pre.final H t = (ti, (x, recs, acc)))
    (df : SlotDef)
    (hdf : (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
      (ti.challengeFp2Vec H ((Pf x i).draws i)).1 = .ok df)
    (hm : m < (slotShape (Pf x i) i).1) :
    let F := (depRoundDrProg Pf Df bga pre i m).final H t
    F.2 = ((x, recs, acc), (ti.challengeFp2Vec H ((Pf x i).draws i)).1)
      ∧ challengeFp2Of (H ⟨F.1.key, squeezeMsg F.1.state F.1.counter⟩)
        = ((slotRho H (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).take
            (slotShape (Pf x i) i).1).getD m Fp2.zero := by
  have hF : (depRoundDrProg Pf Df bga pre i m).final H t =
      (((scUpToP (slotN (Pf x i) i) ((Df x i).strat i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df
            (slotC H (Pf x i) i ti)) m).final H
          (slotT4 H (Pf x i) i ti ((Df x i).scalar i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc df
            (slotC H (Pf x i) i ti)))).1,
       ((x, recs, acc), (ti.challengeFp2Vec H ((Pf x i).draws i)).1)) := by
    unfold depRoundDrProg; rw [final_bindP, final_depCProg, hY]
    show TProg.final H (bindP (slotEAfter (Pf x i) i (Df x i) m (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc
        (challengeFp2Of ((slotT2 H (Pf x i) i ti).squeeze H).1)
        ((Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
          (ti.challengeFp2Vec H ((Pf x i).draws i)).1)) (fun _ => TProg.done _))
        ((slotT2 H (Pf x i) i ti).squeeze H).2 = _
    rw [hdf, final_bindP]; rfl
  dsimp only; rw [hF]; refine ⟨rfl, ?_⟩
  have hmN : m < slotN (Pf x i) i := by unfold slotN; omega
  rw [List.getD_eq_getElem?_getD, List.getElem?_take_of_lt hm, ← List.getD_eq_getElem?_getD]
  exact (scUpTo_chal H (slotN (Pf x i) i) _ m _ hmN).symm

theorem famProve_split (H : HIn → Dig) (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s))
    (b g a : Fp2) :
    ∀ (m : ℕ) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t0 : Tr)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      famProve H Pf Df b g a m recs0 s0 acc0 t0 = .ok (sps, recs', acc', t') →
      recs'.length = recs0.length + m
        ∧ recs'.take recs0.length = recs0
        ∧ (∀ i, i < m →
            ∃ sps₁ recs₁ acc₁ t₁ sp r acc₂ t₂,
              famProve H Pf Df b g a i recs0 s0 acc0 t0 = .ok (sps₁, recs₁, acc₁, t₁)
              ∧ recs₁ = recs'.take (recs0.length + i)
              ∧ recs'.getD (recs0.length + i) rec0 = r
              ∧ slotProve H (Pf (s0 + i)) (Df (s0 + i)) (s0 + i) (histOf b g a recs₁) acc₁ t₁ = .ok (sp, r, acc₂, t₂))
  | 0, recs0, _, _, _, _, recs', _, _, h => by
    simp only [famProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, -, -⟩ := h
    exact ⟨by omega, List.take_length, fun _ hi => by cases hi⟩
  | m + 1, recs0, s0, acc0, t0, sps, recs', acc', t', h => by
    simp only [famProve] at h
    split at h
    · cases h
    · rename_i sp0 r0 acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨-, rfl, rfl, rfl⟩ := h
        obtain ⟨hlen, htake1, hslot⟩ := famProve_split H Pf Df b g a m (recs0 ++ [r0]) (s0 + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂ hrest
        have hlen1 : (recs0 ++ [r0]).length = recs0.length + 1 := by simp
        rw [hlen1] at hlen htake1
        have htake0 : recs₁.take recs0.length = recs0 := by
          have hsub : (recs₁.take (recs0.length + 1)).take recs0.length = recs₁.take recs0.length := by
            rw [List.take_take, Nat.min_eq_left (by omega)]
          rw [← hsub, htake1, List.take_append_of_le_length le_rfl, List.take_length]
        refine ⟨by omega, htake0, fun i hi => ?_⟩
        cases i with
        | zero =>
          have hget0 : recs₁.getD recs0.length rec0 = r0 := by
            have hg := congrArg (fun l => l.getD recs0.length rec0) htake1
            rw [List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (by omega), ← List.getD_eq_getElem?_getD] at hg
            rw [hg, List.getD_eq_getElem?_getD, List.getElem?_append_right le_rfl, Nat.sub_self]; rfl
          exact ⟨[], recs0, acc0, t0, sp0, r0, acc₁, t₁, rfl, by rw [Nat.add_zero]; exact htake0.symm,
            by rw [Nat.add_zero]; exact hget0, by rw [Nat.add_zero]; exact hsp⟩
        | succ j =>
          obtain ⟨sps₂, recs₂, acc₃, t₃, sp, r, acc₄, t₄, hfam, hr2, hget, hspj⟩ := hslot j (by omega)
          rw [hlen1] at hr2 hget
          refine ⟨sp0 :: sps₂, recs₂, acc₃, t₃, sp, r, acc₄, t₄, by simp only [famProve, hsp, hfam],
            by rw [hr2, show recs0.length + 1 + j = recs0.length + (j + 1) by omega],
            by rwa [show recs0.length + 1 + j = recs0.length + (j + 1) by omega] at hget,
            by rwa [show s0 + 1 + j = s0 + (j + 1) by omega] at hspj⟩

private theorem slotProve_congr_idx {H : HIn → Dig} {Pf : ℕ → BlockParams} {Df : (s : ℕ) → SlotData (Pf s)}
    {a b : ℕ} (hab : a = b) {hist : Hist} {acc : Acc} {t : Tr}
    {res : Except Unit (SlotProof × SlotRec × Acc × Tr)}
    (h : slotProve H (Pf a) (Df a) a hist acc t = res) :
    slotProve H (Pf b) (Df b) b hist acc t = res := by
  subst hab; exact h

theorem famProve_claims_parts (H : HIn → Dig) (Pf : ℕ → BlockParams) (Df : (s : ℕ) → SlotData (Pf s))
    (b g a : Fp2) (cm : Cm) (slotPrivs : ℕ → List SlotRec → List Fp2 → List Priv) :
    ∀ (m : ℕ) (recs0 : List SlotRec) (s0 : ℕ) (acc0 : Acc) (t0 : Tr)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      famProve H Pf Df b g a m recs0 s0 acc0 t0 = .ok (sps, recs', acc', t') →
      (∀ i, i < m → ∀ recs₁ dr df,
        recs₁.length = recs0.length + i →
        (Pf (s0 + i)).define (s0 + i) (histOf b g a recs₁) dr = .ok df →
        dr.length = (Pf (s0 + i)).draws (s0 + i) → (∀ w ∈ dr, w.Canon) →
        privsCm cm df.tabs = slotPrivs (s0 + i) recs₁ dr) →
      (claimsCm acc'.claims cm).map Exec.Block.ZClaim.parts
        = (claimsCm acc0.claims cm).map Exec.Block.ZClaim.parts
          ++ (List.range m).flatMap (fun i =>
              let r := recs'.getD (recs0.length + i) rec0
              (slotPrivs (s0 + i) (recs'.take (recs0.length + i)) r.draws).map (fun p =>
                (buildClaim (Pf (s0 + i)) p (claimPoint p r.rho)
                  (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts))
  | 0, _, _, _, _, _, _, _, _, h, _ => by
    simp only [famProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, -, rfl, -⟩ := h; simp
  | m + 1, recs0, s0, acc0, t0, sps, recs', acc', t', h, hpriv => by
    simp only [famProve] at h
    split at h
    · cases h
    · rename_i sp0 r0 acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨-, rfl, rfl, rfl⟩ := h
        obtain ⟨df0, hdf0, hdr0, -, -, -, -, -, -, -, hcl1⟩ :=
          slotProve_ok_struct H (Pf s0) (Df s0) s0 _ acc0 t0 sp0 r0 acc₁ t₁ hsp
        have hp0 : privsCm cm df0.tabs = slotPrivs s0 recs0 r0.draws := by
          rw [hdr0]
          have h' := hpriv 0 (Nat.zero_lt_succ m) recs0 (t0.challengeFp2Vec H ((Pf s0).draws s0)).1 df0
            (by omega) (by rw [Nat.add_zero]; exact hdf0) (by rw [Nat.add_zero]; exact chalVec_length H _ _)
            (chalVec_canon H _ _)
          rwa [Nat.add_zero] at h'
        obtain ⟨_, htake1, _⟩ := famProve_split H Pf Df b g a m (recs0 ++ [r0]) (s0 + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂ hrest
        have hlen1 : (recs0 ++ [r0]).length = recs0.length + 1 := by simp
        rw [hlen1] at htake1
        have htake0 : recs₁.take recs0.length = recs0 := by
          have hsub : (recs₁.take (recs0.length + 1)).take recs0.length = recs₁.take recs0.length := by
            rw [List.take_take, Nat.min_eq_left (by omega)]
          rw [← hsub, htake1, List.take_append_of_le_length le_rfl, List.take_length]
        have hget0 : recs₁.getD recs0.length rec0 = r0 := by
          have hg := congrArg (fun l => l.getD recs0.length rec0) htake1
          rw [List.getD_eq_getElem?_getD, List.getElem?_take_of_lt (by omega), ← List.getD_eq_getElem?_getD] at hg
          rw [hg, List.getD_eq_getElem?_getD, List.getElem?_append_right le_rfl, Nat.sub_self]; rfl
        have ih := famProve_claims_parts H Pf Df b g a cm slotPrivs m (recs0 ++ [r0]) (s0 + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂ hrest
          (fun i hi recs2 dr df hlen2 hdf2 hdrLen2 hcan2 => by
            rw [hlen1] at hlen2
            have h' := hpriv (i + 1) (Nat.succ_lt_succ hi) recs2 dr df (by omega)
              (by rwa [show s0 + (i + 1) = s0 + 1 + i by omega])
              (by rwa [show s0 + (i + 1) = s0 + 1 + i by omega]) hcan2
            rwa [show s0 + (i + 1) = s0 + 1 + i by omega] at h')
        rw [ih, hcl1, slotClaims_parts, hp0, List.range_succ_eq_map, List.flatMap_cons, List.flatMap_map,
          List.append_assoc]
        refine congrArg ((claimsCm acc0.claims cm).map Exec.Block.ZClaim.parts ++ ·) (congrArg₂ (· ++ ·) ?_ ?_)
        · dsimp only; rw [Nat.add_zero, Nat.add_zero, hget0, htake0]
        · refine flatMap_congr_eq (fun i _ => ?_)
          dsimp only
          rw [hlen1, show recs0.length + 1 + i = recs0.length + (i + 1) by omega,
            show s0 + 1 + i = s0 + (i + 1) by omega]

/-- `OpenAuditOk` depends ONLY on `claims.map Exec.Block.ZClaim.parts` (never on `Exec.Block.ZClaim.value`). -/
theorem openAuditOk_of_parts_eq {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (g : OpenGeom) (logN n nColl : ℕ) (F : OpenCollFamily Lq Coins nColl)
    (G : QB Lq → Dig) (c : Coins) (cs₁ cs₂ : List Exec.Block.ZClaim)
    (hparts : cs₁.map Exec.Block.ZClaim.parts = cs₂.map Exec.Block.ZClaim.parts)
    (hok : OpenAuditOk g logN n nColl F G c cs₂) :
    OpenAuditOk g logN n nColl F G c cs₁ := by
  have hlen : cs₁.length = cs₂.length := by
    have hl := congrArg List.length hparts; simpa only [List.length_map] using hl
  have hget : ∀ (i : ℕ) (hi₁ : i < cs₁.length) (hi₂ : i < cs₂.length), cs₁[i].parts = cs₂[i].parts := by
    intro i hi₁ hi₂
    have hg := congrArg (fun l => l[i]?) hparts
    rw [List.getElem?_map, List.getElem?_map, List.getElem?_eq_getElem hi₁, List.getElem?_eq_getElem hi₂] at hg
    exact Option.some.inj hg
  have haudLoop : ∀ (nCl : ℕ) (l₁ l₂ : List Exec.Block.ZClaim) (ci : ℕ) (uses : List ℕ), l₁.map Exec.Block.ZClaim.parts = l₂.map Exec.Block.ZClaim.parts →
      auditLoop (2 ^ logN) g.rows g.prox g.siteRows g.sumRows nCl ci l₁ uses
        = auditLoop (2 ^ logN) g.rows g.prox g.siteRows g.sumRows nCl ci l₂ uses := by
    intro nCl l₁; induction l₁ with
    | nil => intro l₂ _ _ hp; cases l₂ with | nil => rfl | cons _ _ => cases hp
    | cons x xs ih =>
      intro l₂ ci uses hp; cases l₂ with
      | nil => cases hp
      | cons y ys =>
        simp only [List.map_cons, List.cons.injEq] at hp
        have h1 : auditOne (2 ^ logN) g.rows g.prox g.siteRows g.sumRows nCl ci x uses
            = auditOne (2 ^ logN) g.rows g.prox g.siteRows g.sumRows nCl ci y uses := by
          unfold auditOne claimTouched claimWeight; rw [hp.1]
        unfold auditLoop; rw [h1]
        cases auditOne (2 ^ logN) g.rows g.prox g.siteRows g.sumRows nCl ci y uses with
        | error _ => rfl
        | ok u => exact ih ys (ci + 1) u hp.2
  have haudEq : auditClaims cs₁ (2 ^ logN) g.rows g.siteRows g.sumRows g.prox
      = auditClaims cs₂ (2 ^ logN) g.rows g.siteRows g.sumRows g.prox := by
    unfold auditClaims; rw [hlen, haudLoop cs₂.length cs₁ cs₂ 0 (List.replicate g.rows 0) hparts]
  let grpStep : List ((List Fp2 × ℕ × ℕ) × ℕ) → Exec.Block.ZClaim → Except String (List ((List Fp2 × ℕ × ℕ) × ℕ)) :=
    fun gs c =>
      let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
      if c.parts.any (fun p => partKeyAt p logN ≠ key) then
        throw "private block: claim parts with different column weights"
      else pure (bumpKey key gs)
  have hgrpLoop : ∀ (l₁ l₂ : List Exec.Block.ZClaim) (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      l₁.map Exec.Block.ZClaim.parts = l₂.map Exec.Block.ZClaim.parts →
      l₁.foldlM grpStep gs = l₂.foldlM grpStep gs := by
    intro l₁; induction l₁ with
    | nil => intro l₂ _ hp; cases l₂ with | nil => rfl | cons _ _ => cases hp
    | cons x xs ih =>
      intro l₂ gs hp; cases l₂ with
      | nil => cases hp
      | cons y ys =>
        simp only [List.map_cons, List.cons.injEq] at hp
        have hstep : grpStep gs x = grpStep gs y := by unfold grpStep; rw [hp.1]
        rw [List.foldlM_cons, List.foldlM_cons, hstep]
        cases grpStep gs y with
        | error _ => rfl
        | ok gs1 => exact ih ys gs1 hp.2
  have hgrpEq : openingGroupsAt cs₁ logN = openingGroupsAt cs₂ logN := hgrpLoop cs₁ cs₂ [] hparts
  refine ⟨hlen.trans hok.1, by rw [haudEq]; exact hok.2.1, fun cl hcl p hp => ?_, fun groups hgr hne => ?_⟩
  · obtain ⟨i, hi, rfl⟩ := List.getElem_of_mem hcl
    have hi₂ : i < cs₂.length := by omega
    have heq := hget i hi hi₂
    have hcl2 := hok.2.2.1 cs₂[i] (List.getElem_mem hi₂) p (by rw [← heq]; exact hp)
    unfold claimKey at hcl2 ⊢; rw [heq]; exact hcl2
  · rw [hgrpEq] at hgr; exact hok.2.2.2 groups hgr hne

theorem range'_mem_iff (a len r : ℕ) : r ∈ List.range' a len ↔ a ≤ r ∧ r < a + len := by
  induction len generalizing a with
  | zero => simp
  | succ len ih => rw [List.range'_succ, List.mem_cons, ih (a + 1)]; omega

theorem countNat_eq_zero_of_notMem (r : ℕ) : ∀ (l : List ℕ), r ∉ l → countNat r l = 0
  | [], _ => rfl
  | x :: xs, h => by
    have hne : r ≠ x := fun he => h (he ▸ List.mem_cons_self)
    simp only [countNat, ite_eq_right hne, Nat.zero_add,
      countNat_eq_zero_of_notMem r xs (fun hm => h (List.mem_cons_of_mem x hm))]

theorem countNat_range'_of_mem (a len r : ℕ) (h : r ∈ List.range' a len) :
    countNat r (List.range' a len) = 1 := by
  induction len generalizing a with
  | zero => cases h
  | succ len ih =>
    rw [List.range'_succ] at h ⊢
    rcases List.mem_cons.mp h with rfl | htl
    · rw [countNat, ite_eq_left rfl,
        countNat_eq_zero_of_notMem r (List.range' (r + 1) len) (by rw [range'_mem_iff]; omega)]
    · have hne : r ≠ a := by rw [range'_mem_iff] at htl; omega
      simp only [countNat, ite_eq_right hne, Nat.zero_add]; exact ih (a + 1) htl

theorem flatMap_pairs_eq_range' (base : ℕ) :
    ∀ k, ((List.range k).map (fun i => base + 2 * i)).flatMap (fun m => [m, m + 1]) = List.range' base (2 * k)
  | 0 => rfl
  | k + 1 => by
    rw [List.range_succ, List.map_append, List.map_singleton, List.flatMap_append, flatMap_pairs_eq_range' base k,
      List.flatMap_singleton, show 2 * (k + 1) = 2 * k + 2 by omega, ← List.range'_append_1]
    rfl

private theorem ceil_two_pow_div_one (m logN : ℕ) (h : m ≤ logN) :
    (2 ^ m + 2 ^ logN - 1) / 2 ^ logN = 1 := by
  have h1 : 1 ≤ 2 ^ m := Nat.one_le_two_pow
  have h2 : 2 ^ m ≤ 2 ^ logN := Nat.pow_le_pow_right (by norm_num) h
  have hpos : 0 < 2 ^ logN := Nat.two_pow_pos logN
  rw [show 2 ^ m + 2 ^ logN - 1 = (2 ^ m - 1) + 1 * 2 ^ logN by omega,
    Nat.add_mul_div_right _ _ hpos, Nat.div_eq_of_lt (by omega), Nat.zero_add]

private theorem partSiteRows_empty_of_hi_le (n base len : ℕ) (p : Exec.Block.ZPart) (hhi : partHi p n ≤ base) :
    partSiteRows n (List.range' base len) p = [] := by
  unfold partSiteRows
  cases hf : ((List.range' (partLo p n) (partHi p n - partLo p n)).filter
      (fun r => decide (r ∈ List.range' base len))) with
  | nil => rfl
  | cons r _ =>
    have hmem : r ∈ (List.range' (partLo p n) (partHi p n - partLo p n)).filter
        (fun r => decide (r ∈ List.range' base len)) := by rw [hf]; exact List.mem_cons_self
    obtain ⟨hm1, hm2⟩ := List.mem_filter.mp hmem
    have hm2' := of_decide_eq_true hm2
    rw [range'_mem_iff] at hm1 hm2'
    have hfalse : False := by omega
    cases hfalse

private theorem partSiteRows_singleton (n base len row : ℕ) (p : Exec.Block.ZPart)
    (hlo : partLo p n = row) (hhi : partHi p n = row + 1) (hmem : row ∈ List.range' base len) :
    partSiteRows n (List.range' base len) p = [row] := by
  unfold partSiteRows
  rw [hlo, hhi, show row + 1 - row = 1 by omega, List.range'_succ, List.range'_zero, List.filter_cons,
    decide_eq_true hmem]
  rfl

/-- **Master Theorem 1 (`buildClaim` uniform `partKeyAt` & exact `claimKey`)**. -/
theorem buildClaim_parts_uniform (P : BlockParams) (p : Priv) (pt es : List Fp2) (val : Fp2)
    (hlogN : 0 < rowLog P p.cm) (hslices : p.slices ≠ []) (hlogPos : 0 < p.log) (hpt : pt.length = p.log)
    (hmod : ∀ sc ∈ p.slices, p.log < rowLog P p.cm →
      sc.1 % 2 ^ rowLog P p.cm = (p.slices.headD (0, Fp2.zero)).1 % 2 ^ rowLog P p.cm) :
    let logN := rowLog P p.cm
    let n := 2 ^ logN
    let c := buildClaim P p pt (oneMinusProd es) (maskCoef es p.extRound) val
    claimKey logN c = (pt.drop (p.log - logN),
        if logN ≤ p.log then 0 else (p.slices.headD (0, Fp2.zero)).1 % n,
        if logN ≤ p.log then n else 2 ^ p.log)
      ∧ ∀ q ∈ c.parts, partKeyAt q logN = claimKey logN c := by
  intro logN n c
  have hlogmPos : 0 < min p.log logN := Nat.lt_min.mpr ⟨hlogPos, hlogN⟩
  have hsubEq : p.log - min p.log logN = p.log - logN := by omega
  have hptNe : pt.isEmpty = false := by cases hpt' : pt with | nil => rw [hpt'] at hpt; simp at hpt; omega | cons _ _ => rfl
  have htailNe : (pt.drop (p.log - min p.log logN)).isEmpty = false := by
    have hlen : (pt.drop (p.log - min p.log logN)).length = min p.log logN := by rw [List.length_drop, hpt]; omega
    cases ht' : pt.drop (p.log - min p.log logN) with | nil => rw [ht'] at hlen; simp at hlen; omega | cons _ _ => rfl
  cases hs0 : p.slices with
  | nil => have hf : False := hslices hs0; cases hf
  | cons s0 _ =>
    have hhead : c.parts.headD ⟨0, 0, Fp2.zero, []⟩ = ⟨s0.1, p.log, s0.2.mul (oneMinusProd es), pt⟩ := by
      simp [c, buildClaim, hs0]
    have hkeyEq : claimKey logN c = (pt.drop (p.log - logN),
        if logN ≤ p.log then 0 else s0.1 % n, if logN ≤ p.log then n else 2 ^ p.log) := by
      unfold claimKey partKeyAt; rw [hhead]; dsimp only
      rw [hptNe, ite_eq_right Bool.false_ne_true]
      by_cases hle : logN ≤ p.log
      · simp only [ite_eq_left hle]; rfl
      · simp only [ite_eq_right hle]; rfl
    refine ⟨by simpa only [hs0, List.headD_cons] using hkeyEq, fun q hq => ?_⟩
    rw [hkeyEq]
    simp only [c, buildClaim, List.mem_append, List.mem_map, List.mem_cons, List.not_mem_nil, or_false] at hq
    rcases hq with ⟨sc, hscMem, rfl⟩ | rfl | rfl
    · unfold partKeyAt; dsimp only; dsimp only [logN, n]; rw [hptNe, ite_eq_right Bool.false_ne_true]
      by_cases hle : rowLog P p.cm ≤ p.log
      · simp only [ite_eq_left hle]
      · have hm := hmod sc hscMem (by omega); rw [hs0] at hm; dsimp only [List.headD_cons] at hm
        simp only [ite_eq_right hle, hm]
    · unfold partKeyAt; dsimp only
      rw [htailNe, ite_eq_right Bool.false_ne_true, show min p.log logN - logN = 0 by omega, List.drop_zero, hsubEq]
      dsimp only [logN, n]
      by_cases hle : rowLog P p.cm ≤ p.log
      · have hle' : rowLog P p.cm ≤ min p.log (rowLog P p.cm) := by omega
        simp only [ite_eq_left hle', ite_eq_left hle]
      · have hlt : p.log < rowLog P p.cm := by omega
        have hmin : min p.log (rowLog P p.cm) = p.log := Nat.min_eq_left (by omega)
        simp only [ite_eq_right hle, ite_eq_left hlt, hs0, List.headD_cons, hmin,
          Nat.mul_add_mod_self_right, Nat.mod_mod]
    · unfold partKeyAt; dsimp only
      rw [htailNe, ite_eq_right Bool.false_ne_true, show min p.log logN - logN = 0 by omega, List.drop_zero, hsubEq]
      dsimp only [logN, n]
      by_cases hle : rowLog P p.cm ≤ p.log
      · have hle' : rowLog P p.cm ≤ min p.log (rowLog P p.cm) := by omega
        simp only [ite_eq_left hle', ite_eq_left hle]
      · have hlt : p.log < rowLog P p.cm := by omega
        have hmin : min p.log (rowLog P p.cm) = p.log := Nat.min_eq_left (by omega)
        simp only [ite_eq_right hle, ite_eq_left hlt, hs0, List.headD_cons, hmin,
          Nat.mul_add_mod_self_right, Nat.mod_mod]

/-- **Master Theorem 2 (`buildClaim` `SurvivingAuditClaim` + exact touched pair `[maskRow, maskRow + 1]`)**. -/
theorem buildClaim_survivingAuditClaim (P : BlockParams) (p : Priv) (pt es : List Fp2) (val : Fp2)
    (maskBase prox nClaims ci : ℕ) (sumRows : Option (ℕ × ℕ))
    (hlogN : 0 < rowLog P p.cm) (hlogPos : 0 < p.log) (hpt : pt.length = p.log)
    (hdata : ∀ sc ∈ p.slices, sc.1 / 2 ^ rowLog P p.cm + (2 ^ p.log + 2 ^ rowLog P p.cm - 1) / 2 ^ rowLog P p.cm ≤ maskBase)
    (hmb : maskBase ≤ p.maskRow) (hmProx : p.maskRow + 2 ≤ prox) (heven : (p.maskRow - maskBase) % 2 = 0)
    (hesCan : ∀ e ∈ es, e.Canon) (hesNoDeg : ∀ e ∈ es, e ≠ Fp2.zero ∧ e ≠ Fp2.one) (hext : p.extRound < es.length) :
    let logN := rowLog P p.cm
    let n := 2 ^ logN
    let siteRows := List.range' maskBase (prox - maskBase)
    let c := buildClaim P p pt (oneMinusProd es) (maskCoef es p.extRound) val
    c.parts.flatMap (partSiteRows n siteRows) = [p.maskRow, p.maskRow + 1]
      ∧ SurvivingAuditClaim logN prox siteRows sumRows nClaims ci c := by
  intro logN n siteRows c
  have hnPos : 0 < n := Nat.two_pow_pos logN
  let logm := min p.log logN
  let c0 := if p.log < logN then (p.slices.headD (0, Fp2.zero)).1 % n else 0
  let tail := pt.drop (p.log - logm)
  let cd := oneMinusProd es
  let cm := maskCoef es p.extRound
  let dParts := p.slices.map (fun sc => (⟨sc.1, p.log, sc.2.mul cd, pt⟩ : Exec.Block.ZPart))
  let m0 : Exec.Block.ZPart := ⟨p.maskRow * n + c0, logm, cm.mul Fp2.one, tail⟩
  let m1 : Exec.Block.ZPart := ⟨(p.maskRow + 1) * n + c0, logm, cm.mul fp2U, tail⟩
  have hcParts : c.parts = dParts ++ [m0, m1] := rfl
  have hc0Lt : c0 < n := by
    unfold c0; by_cases h : p.log < logN
    · rw [ite_eq_left h]; exact Nat.mod_lt _ hnPos
    · rw [ite_eq_right h]; exact hnPos
  have hdiv0 : (p.maskRow * 2 ^ logN + c0) / 2 ^ logN = p.maskRow := by
    rw [Nat.add_comm, Nat.add_mul_div_right _ _ hnPos, Nat.div_eq_of_lt hc0Lt, Nat.zero_add]
  have hdiv1 : ((p.maskRow + 1) * 2 ^ logN + c0) / 2 ^ logN = p.maskRow + 1 := by
    rw [Nat.add_comm, Nat.add_mul_div_right _ _ hnPos, Nat.div_eq_of_lt hc0Lt, Nat.zero_add]
  have hceilm : (2 ^ logm + 2 ^ logN - 1) / 2 ^ logN = 1 := ceil_two_pow_div_one logm logN (Nat.min_le_right _ _)
  have hm0Hi : partHi m0 (2 ^ logN) = p.maskRow + 1 := by unfold partHi; dsimp only [m0, n]; rw [hdiv0, hceilm]
  have hm1Hi : partHi m1 (2 ^ logN) = p.maskRow + 2 := by unfold partHi; dsimp only [m1, n]; rw [hdiv1, hceilm]
  have hdEmpty : ∀ q ∈ dParts, partSiteRows (2 ^ logN) siteRows q = [] := fun q hq => by
    obtain ⟨sc, hsc, rfl⟩ := List.mem_map.mp hq
    exact partSiteRows_empty_of_hi_le (2 ^ logN) maskBase (prox - maskBase) _ (hdata sc hsc)
  have hflat : c.parts.flatMap (partSiteRows (2 ^ logN) siteRows) = [p.maskRow, p.maskRow + 1] := by
    dsimp only [siteRows]
    rw [hcParts, List.flatMap_append, List.flatMap_eq_nil_iff.mpr hdEmpty, List.nil_append,
      List.flatMap_cons, List.flatMap_singleton,
      partSiteRows_singleton (2 ^ logN) maskBase (prox - maskBase) p.maskRow m0 hdiv0 hm0Hi (by rw [range'_mem_iff]; omega),
      partSiteRows_singleton (2 ^ logN) maskBase (prox - maskBase) (p.maskRow + 1) m1 hdiv1 hm1Hi (by rw [range'_mem_iff]; omega)]; rfl
  obtain ⟨hcmC, hcm0⟩ := maskCoef_ne_zero_of_noDeg es p.extRound hext hesCan hesNoDeg
  have hm0Coef : m0.coef = cm := fp2_mul_one cm hcmC
  have htailNe : tail.isEmpty = false := by
    have hlen : tail.length = logm := by unfold tail; rw [List.length_drop, hpt]; omega
    have hpos : 0 < logm := Nat.lt_min.mpr ⟨hlogPos, hlogN⟩
    cases ht' : tail with | nil => rw [ht'] at hlen; simp at hlen; omega | cons _ _ => rfl
  have hallFalse : c.parts.all (fun q => q.point.isEmpty) = false := by
    rw [hcParts, List.all_append, List.all_cons]; simp [m0, htailNe]
  have hsr0 : siteRows.getD 0 0 = maskBase := by
    unfold siteRows; rw [show prox - maskBase = (prox - maskBase - 1) + 1 by omega, List.range'_succ]; rfl
  refine ⟨hflat, ?_, ?_, ?_⟩
  · intro q hq; rw [hcParts, List.mem_append, List.mem_cons, List.mem_singleton] at hq
    rcases hq with hqd | rfl | rfl
    · obtain ⟨sc, hsc, rfl⟩ := List.mem_map.mp hqd; exact (hdata sc hsc).trans (by omega)
    · rw [hm0Hi]; omega
    · rw [hm1Hi]; exact hmProx
  · intro q hq hne; rw [hcParts, List.mem_append, List.mem_cons, List.mem_singleton] at hq
    rcases hq with hqd | rfl | rfl
    · rw [hdEmpty q hqd] at hne; cases hne
    · rw [hm0Coef]; exact hcm0
    · exact fp2_mul_ne_zero cm fp2U hcmC canon_fp2U hcm0 fp2U_ne_zero
  · rw [hallFalse, ite_eq_right Bool.false_ne_true]
    refine ⟨p.maskRow, cm, hflat, by rw [hsr0]; exact heven, hcmC, hcm0, ?_, ?_⟩
    · have hw0 : zpartRowWeight m0 logN p.maskRow = cm := by
        rw [zpartRowWeight_singleRow m0 logN p.maskRow (Nat.min_le_right _ _) hdiv0.symm (Fp2.canon_mul _ _), hm0Coef]
      rw [claimWeight_of_unique_part logN p.maskRow c dParts [m1] m0 hcParts
        (fun q hq => by obtain ⟨sc, hsc, rfl⟩ := List.mem_map.mp hq; exact zpartRowWeight_outside _ logN p.maskRow (Or.inr ((hdata sc hsc).trans hmb)))
        (fun q hq => by rw [List.mem_singleton.mp hq]; exact zpartRowWeight_outside m1 logN p.maskRow (Or.inl (by unfold partLo; rw [hdiv1]; omega)))
        (by rw [hw0]; exact hcmC), hw0]
    · have hw1 : zpartRowWeight m1 logN (p.maskRow + 1) = cm.mul fp2U :=
        zpartRowWeight_singleRow m1 logN (p.maskRow + 1) (Nat.min_le_right _ _) hdiv1.symm (Fp2.canon_mul _ _)
      have hparts1 : c.parts = (dParts ++ [m0]) ++ m1 :: [] := by rw [hcParts, List.append_assoc]; rfl
      rw [claimWeight_of_unique_part logN (p.maskRow + 1) c (dParts ++ [m0]) [] m1 hparts1
        (fun q hq => by
          rcases List.mem_append.mp hq with hqd | hqm0
          · obtain ⟨sc, hsc, rfl⟩ := List.mem_map.mp hqd
            exact zpartRowWeight_outside _ logN (p.maskRow + 1) (Or.inr ((hdata sc hsc).trans (by omega)))
          · rw [List.mem_singleton.mp hqm0]; exact zpartRowWeight_outside m0 logN (p.maskRow + 1) (Or.inr (by rw [hm0Hi])))
        (fun _ hq => by cases hq) (by rw [hw1]; exact Fp2.canon_mul _ _), hw1]

/-- **Master Theorem 3 (`logupSumClaim` `SurvivingAuditClaim`, empty touched rows, and uniform key `([], 0, 2^logN)`)**. -/
theorem sumClaim_audit_of_parts (logN u0 u1 maskBase prox ci : ℕ) (sc : Exec.Block.ZClaim) (pre : List Exec.Block.ZPart)
    (hu1 : u1 = u0 + 1) (hmb : maskBase = u1 + 1) (hprox : maskBase ≤ prox)
    (hparts : sc.parts = pre ++ [⟨u0 * 2 ^ logN, logN, Fp2.one, []⟩, ⟨u1 * 2 ^ logN, logN, Fp2.one.mul fp2U, []⟩])
    (hpre : ∀ q ∈ pre, q.point = [] ∧ logN ≤ q.logSize ∧ partHi q (2 ^ logN) ≤ u0) :
    let n := 2 ^ logN
    let siteRows := List.range' maskBase (prox - maskBase)
    sc.parts.flatMap (partSiteRows n siteRows) = []
      ∧ SurvivingAuditClaim logN prox siteRows (some (u0, u1)) (ci + 1) ci sc
      ∧ claimKey logN sc = ([], 0, n)
      ∧ ∀ q ∈ sc.parts, partKeyAt q logN = ([], 0, n) := by
  intro n siteRows
  have hnPos : 0 < n := Nat.two_pow_pos logN
  let p0 : Exec.Block.ZPart := ⟨u0 * n, logN, Fp2.one, []⟩
  let p1 : Exec.Block.ZPart := ⟨u1 * n, logN, Fp2.one.mul fp2U, []⟩
  have hceil : (2 ^ logN + 2 ^ logN - 1) / 2 ^ logN = 1 := ceil_two_pow_div_one logN logN le_rfl
  have hp0Lo : partLo p0 (2 ^ logN) = u0 := Nat.mul_div_cancel u0 hnPos
  have hp0Hi : partHi p0 (2 ^ logN) = u0 + 1 := by unfold partHi; dsimp only [p0, n]; rw [Nat.mul_div_cancel u0 hnPos, hceil]
  have hp1Lo : partLo p1 (2 ^ logN) = u1 := Nat.mul_div_cancel u1 hnPos
  have hp1Hi : partHi p1 (2 ^ logN) = u1 + 1 := by unfold partHi; dsimp only [p1, n]; rw [Nat.mul_div_cancel u1 hnPos, hceil]
  have hhiAll : ∀ q ∈ sc.parts, partHi q (2 ^ logN) ≤ maskBase := fun q hq => by
    rw [hparts, List.mem_append, List.mem_cons, List.mem_singleton] at hq
    rcases hq with hqp | rfl | rfl
    · exact (hpre q hqp).2.2.trans (by omega)
    · rw [hp0Hi]; omega
    · rw [hp1Hi]; omega
  have hflat : sc.parts.flatMap (partSiteRows (2 ^ logN) siteRows) = [] :=
    List.flatMap_eq_nil_iff.mpr (fun q hq => partSiteRows_empty_of_hi_le (2 ^ logN) maskBase (prox - maskBase) q (hhiAll q hq))
  have hallEmp : sc.parts.all (fun q => q.point.isEmpty) = true := by
    rw [List.all_eq_true]; intro q hq; rw [hparts, List.mem_append, List.mem_cons, List.mem_singleton] at hq
    rcases hq with hqp | rfl | rfl
    · rw [(hpre q hqp).1]; rfl
    · rfl
    · rfl
  have hkeyAll : ∀ q ∈ sc.parts, partKeyAt q logN = ([], 0, n) := fun q hq => by
    rw [hparts, List.mem_append, List.mem_cons, List.mem_singleton] at hq
    rcases hq with hqp | rfl | rfl
    · unfold partKeyAt; dsimp only; rw [(hpre q hqp).1, List.isEmpty_nil, ite_eq_left rfl, ite_eq_left (hpre q hqp).2.1]
    · unfold partKeyAt; dsimp only; rw [List.isEmpty_nil, ite_eq_left rfl, ite_eq_left le_rfl]
    · unfold partKeyAt; dsimp only; rw [List.isEmpty_nil, ite_eq_left rfl, ite_eq_left le_rfl]
  have hckey : claimKey logN sc = ([], 0, n) := by
    unfold claimKey; cases hps : sc.parts with
    | nil => have hl := congrArg List.length (hps.symm.trans hparts); simp at hl
    | cons q0 _ => exact hkeyAll q0 (by rw [hps]; exact List.mem_cons_self)
  refine ⟨hflat, ⟨fun q hq => (hhiAll q hq).trans hprox, (fun q hq hne => by
      unfold siteRows at hne; rw [partSiteRows_empty_of_hi_le (2 ^ logN) maskBase (prox - maskBase) q (hhiAll q hq)] at hne; cases hne), ?_⟩,
    hckey, hkeyAll⟩
  rw [hallEmp, ite_eq_left rfl]
  refine ⟨u0, u1, Fp2.one, rfl, rfl, hflat,
    ⟨p0, by rw [hparts]; exact List.mem_append_right _ List.mem_cons_self, by rw [hp0Lo], by rw [hp0Hi]; omega, fp2_one_ne_zero⟩,
    ⟨p1, by rw [hparts]; exact List.mem_append_right _ (List.mem_cons_of_mem _ List.mem_cons_self), by rw [hp1Lo], by rw [hp1Hi]; omega,
      fp2_mul_ne_zero Fp2.one fp2U Fp2.canon_one canon_fp2U fp2_one_ne_zero fp2U_ne_zero⟩,
    Fp2.canon_one, fp2_one_ne_zero, ?_, ?_⟩
  · have hw0 : zpartRowWeight p0 logN u0 = Fp2.one :=
      zpartRowWeight_emptyPoint p0 logN u0 rfl (by rw [hp0Lo]) (by rw [hp0Hi]; omega)
    rw [claimWeight_of_unique_part logN u0 sc pre [p1] p0 hparts
      (fun q hq => zpartRowWeight_outside q logN u0 (Or.inr (hpre q hq).2.2))
      (fun q hq => by rw [List.mem_singleton.mp hq]; exact zpartRowWeight_outside p1 logN u0 (Or.inl (by rw [hp1Lo]; omega)))
      (by rw [hw0]; exact Fp2.canon_one), hw0]
  · have hw1 : zpartRowWeight p1 logN u1 = Fp2.one.mul fp2U :=
      zpartRowWeight_emptyPoint p1 logN u1 rfl (by rw [hp1Lo]) (by rw [hp1Hi]; omega)
    have hparts1 : sc.parts = (pre ++ [p0]) ++ p1 :: [] := by rw [hparts, List.append_assoc]; rfl
    rw [claimWeight_of_unique_part logN u1 sc (pre ++ [p0]) [] p1 hparts1
      (fun q hq => by
        rcases List.mem_append.mp hq with hqp | hqp0
        · exact zpartRowWeight_outside q logN u1 (Or.inr ((hpre q hqp).2.2.trans (by omega)))
        · rw [List.mem_singleton.mp hqp0]; exact zpartRowWeight_outside p0 logN u1 (Or.inr (by rw [hp0Hi]; omega)))
      (fun _ hq => by cases hq) (by rw [hw1]; exact Fp2.canon_mul _ _), hw1]

/-- Invariant propagated across all 27 boundaries `B_0 .. B_26` for the carried pending claim. -/
def BndCarryOk (r0 : ℕ) (pending : List Exec.Block.ZClaim) : Prop :=
  ∃ cl, pending = [cl]
    ∧ cl.parts.flatMap (partSiteRows (2 ^ 14) [32, 33, 34, 35]) = [r0, r0 + 1]
    ∧ SurvivingAuditClaim 14 36 [32, 33, 34, 35] none 2 0 cl
    ∧ ∀ p ∈ cl.parts, partKeyAt p 14 = claimKey 14 cl

theorem buildClaim_bndCarryOk (P : BlockParams) (p : Priv) (pt es : List Fp2) (val : Fp2) (r0 : ℕ)
    (hlogN : rowLog P p.cm = 14) (hslices : p.slices = [(0, Fp2.one)]) (hlog : p.log = 19)
    (hpt : pt.length = 19) (hmask : p.maskRow = r0) (hr0 : r0 = 32 ∨ r0 = 34)
    (hesCan : ∀ e ∈ es, e.Canon) (hesNoDeg : ∀ e ∈ es, e ≠ Fp2.zero ∧ e ≠ Fp2.one) (hext : p.extRound < es.length) :
    BndCarryOk r0 [buildClaim P p pt (oneMinusProd es) (maskCoef es p.extRound) val] := by
  have hsite : List.range' 32 (36 - 32) = [32, 33, 34, 35] := rfl
  have h1 := buildClaim_survivingAuditClaim P p pt es val 32 36 2 0 none
    (by omega) (by omega) (by omega)
    (fun sc hsc => by rw [hslices, List.mem_singleton] at hsc; rw [hsc]; dsimp only; rw [hlogN, hlog]; norm_num)
    (by omega) (by omega) (by rcases hr0 with rfl | rfl <;> omega) hesCan hesNoDeg hext
  have h2 := buildClaim_parts_uniform P p pt es val (by omega) (by rw [hslices]; intro h; cases h) (by omega)
    (by omega) (fun _ _ hlt => by omega)
  rw [hlogN, hsite, hmask] at h1; rw [hlogN] at h2
  exact ⟨_, rfl, h1.1, h1.2, h2.2⟩

theorem bnd_openAuditOk_of_pair {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (r0 r1 : ℕ) (hpair : (r0 = 32 ∧ r1 = 34) ∨ (r0 = 34 ∧ r1 = 32))
    (pend : List Exec.Block.ZClaim) (hpend : BndCarryOk r0 pend) (c1 : Exec.Block.ZClaim)
    (hflat1 : c1.parts.flatMap (partSiteRows (2 ^ 14) [32, 33, 34, 35]) = [r1, r1 + 1])
    (hsurv1 : SurvivingAuditClaim 14 36 [32, 33, 34, 35] none 2 1 c1)
    (hunif1 : ∀ p ∈ c1.parts, partKeyAt p 14 = claimKey 14 c1)
    (F : OpenCollFamily Lq Coins 1) (G : QB Lq → Dig) (c : Coins)
    (hcoll : claimKey 14 (pend.headD zclaim0) = claimKey 14 c1 → (F.site ⟨0, by norm_num⟩).fires shdP_U G c) :
    OpenAuditOk shdP_bndOpenGeom 14 2 1 F G c (pend ++ [c1]) := by
  obtain ⟨c0, rfl, hflat0, hsurv0, hunif0⟩ := hpend
  have hunif : ∀ cl ∈ [c0, c1], ∀ p ∈ cl.parts, partKeyAt p 14 = claimKey 14 cl := fun cl hcl => by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hcl; rcases hcl with rfl | rfl; exacts [hunif0, hunif1]
  refine ⟨rfl, ?_, hunif, fun groups hgr hne => ?_⟩
  · refine auditClaims_ok_of_surviving [c0, c1] 14 38 [32, 33, 34, 35] none 36 rfl rfl (by decide)
      (fun i hi => by
        have h01 : i = 0 ∨ i = 1 := by simp at hi; omega
        rcases h01 with rfl | rfl
        · exact hsurv0
        · exact hsurv1)
      (fun r hr => by
        simp only [List.flatMap_cons, List.flatMap_nil, List.append_nil, hflat0, hflat1]
        rcases hpair with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> revert r hr <;> decide)
  · let expKey : Fin 2 → List Fp2 × ℕ × ℕ := fun a => if a.val = 0 then claimKey 14 c0 else claimKey 14 c1
    obtain ⟨-, a, b, hlt, heq⟩ := openingGroupsAt_ne_implies_collision [c0, c1] 14 2 groups expKey hgr
      (fun cl hcl => by
        simp only [List.mem_cons, List.not_mem_nil, or_false] at hcl
        rcases hcl with rfl | rfl; exacts [⟨⟨0, by norm_num⟩, rfl⟩, ⟨⟨1, by norm_num⟩, rfl⟩])
      (fun i => by
        have h01 : i.val = 0 ∨ i.val = 1 := by omega
        rcases h01 with h0 | h1
        · exact ⟨c0, List.mem_cons_self, by unfold expKey; rw [ite_eq_left h0]⟩
        · have hne : i.val ≠ 0 := by omega
          exact ⟨c1, List.mem_cons_of_mem _ List.mem_cons_self, by unfold expKey; rw [ite_eq_right hne]⟩) hne
    have ha0 : a.val = 0 := by omega
    have hb0 : b.val ≠ 0 := by omega
    unfold expKey at heq; rw [ite_eq_left ha0, ite_eq_right hb0] at heq
    exact ⟨⟨0, by norm_num⟩, hcoll heq⟩

/-! ### Strict-pair enumeration & unified `CollPlan` collision-site engine -/

def strictPairs : ℕ → List (ℕ × ℕ)
  | 0 => []
  | n + 1 => strictPairs n ++ (List.range n).map (fun a => (a, n))

theorem strictPairs_length : ∀ n, (strictPairs n).length = n * (n - 1) / 2
  | 0 => rfl
  | n + 1 => by
    rw [strictPairs, List.length_append, strictPairs_length n, List.length_map, List.length_range]
    have hdvd : 2 ∣ n * (n - 1) := by
      cases n with
      | zero => simp
      | succ m =>
        simp only [Nat.add_sub_cancel]
        rcases Nat.even_or_odd m with ⟨k, rfl⟩ | ⟨k, rfl⟩
        · exact ⟨(2 * k + 1) * k, by ring⟩
        · exact ⟨(k + 1) * (2 * k + 1), by ring⟩
    obtain ⟨q, hq⟩ := hdvd
    have h1 : (n + 1) * n = 2 * (q + n) := by
      cases n with | zero => simp at hq; omega | succ m => simp only [Nat.add_sub_cancel] at hq; linarith
    rw [Nat.add_sub_cancel, hq, h1, Nat.mul_div_cancel_left _ (by norm_num), Nat.mul_div_cancel_left _ (by norm_num)]

theorem mem_strictPairs : ∀ (n a b : ℕ), a < b → b < n → (a, b) ∈ strictPairs n
  | 0, _, _, _, hb => by cases hb
  | n + 1, a, b, hab, hbn => by
    unfold strictPairs
    by_cases h : b = n
    · subst h; exact List.mem_append_right _ (List.mem_map.mpr ⟨a, List.mem_range.mpr hab, rfl⟩)
    · exact List.mem_append_left _ (mem_strictPairs n a b hab (by omega))

noncomputable def mkPairCollFamily {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (gExp nColl : ℕ) (_hlen : (strictPairs gExp).length = nColl)
    (siteOf : ℕ → ℕ → ProtocolClassify.Site (QB Lq) Coins shdP_K)
    (hk : ∀ a b, (siteOf a b).k ≤ 1) (hδ : ∀ a b, (siteOf a b).δ = 0) :
    OpenCollFamily Lq Coins nColl where
  site j := let p := (strictPairs gExp).getD j.val (0, 0); siteOf p.1 p.2
  hk _ := hk _ _
  hδ _ := hδ _ _

theorem mkPairCollFamily_fires {Lq : ℕ} {Coins : Type} [Fintype Coins] [Nonempty Coins]
    (gExp nColl : ℕ) (hlen : (strictPairs gExp).length = nColl)
    (siteOf : ℕ → ℕ → ProtocolClassify.Site (QB Lq) Coins shdP_K)
    (hk : ∀ a b, (siteOf a b).k ≤ 1) (hδ : ∀ a b, (siteOf a b).δ = 0)
    (G : QB Lq → Dig) (c : Coins) (a b : ℕ) (hab : a < b) (hb : b < gExp)
    (hfire : (siteOf a b).fires shdP_U G c) :
    ∃ j : Fin nColl, ((mkPairCollFamily gExp nColl hlen siteOf hk hδ).site j).fires shdP_U G c := by
  obtain ⟨m, hm, heq⟩ := exists_getD_of_mem (0, 0) (a, b) (strictPairs gExp) (mem_strictPairs gExp a b hab hb)
  refine ⟨⟨m, by omega⟩, ?_⟩
  dsimp only [mkPairCollFamily]; rw [heq]; exact hfire

theorem shdP_two_ne_zero_run : (2 : shdP_K) ≠ 0 := by
  have h2gf : (2 : GF) ≠ 0 := Ring.two_ne_zero (by rw [ZMod.ringChar_zmod_n gP]; norm_num [gP])
  intro h
  have h1 : algebraMap GF shdP_K (2 : GF) = 0 := by rw [map_ofNat]; exact h
  exact h2gf ((RingHom.injective (algebraMap GF shdP_K)) (h1.trans (map_zero _).symm))

theorem fp2_eq_one_sub_self_toK (x : Fp2) (hx : x.Canon) (h : x = Fp2.one.sub x) :
    x.toK shdP_U = (2 : shdP_K)⁻¹ := by
  have h1 : x.toK shdP_U = 1 - x.toK shdP_U := fp2_one_sub_toK_eq shdP_U x x hx h.symm
  have h2 : (2 : shdP_K) * x.toK shdP_U = 1 := by linear_combination h1
  calc x.toK shdP_U = (2 : shdP_K)⁻¹ * ((2 : shdP_K) * x.toK shdP_U) := by
        rw [← mul_assoc, inv_mul_cancel₀ shdP_two_ne_zero_run, one_mul]
    _ = (2 : shdP_K)⁻¹ * 1 := by rw [h2]
    _ = (2 : shdP_K)⁻¹ := mul_one _

inductive KeyCoord where
  | rho (k : ℕ) | flip (k : ℕ) | dr (slot i : ℕ) | zero
  deriving DecidableEq

abbrev SymGroup := ℕ × (List KeyCoord × ℕ × ℕ)

def toKeyCoord : CoordS → Option KeyCoord
  | .rho k => some (.rho k) | .flip k => some (.flip k)
  | .fixed (.dr s i) => some (.dr s i) | .fixed .zero => some .zero | _ => none

def mapMOpt {α β : Type} (f : α → Option β) : List α → Option (List β)
  | [] => some []
  | x :: xs => match f x, mapMOpt f xs with | some y, some ys => some (y :: ys) | _, _ => none

def privSymKey (logN : ℕ) (p : PrivS) : Option (List KeyCoord × ℕ × ℕ) :=
  let n := 2 ^ logN
  let cl : ℕ × ℕ := if logN ≤ p.log then (0, n) else ((p.slices.headD (0, false)).1 % n, 2 ^ p.log)
  (mapMOpt toKeyCoord (p.coords.drop (p.log - logN))).map (fun ks => (ks, cl.1, cl.2))

def evalKeyCoord (recs : List SlotRec) (s : ℕ) : KeyCoord → Fp2
  | .rho k => (recs.getD s rec0).rho.getD k Fp2.zero
  | .flip k => Fp2.one.sub ((recs.getD s rec0).rho.getD k Fp2.zero)
  | .dr s' i => (recs.getD s' rec0).draws.getD i Fp2.zero
  | .zero => Fp2.zero

def evalSymGroup (recs : List SlotRec) (g : SymGroup) : List Fp2 × ℕ × ℕ :=
  (g.2.1.map (evalKeyCoord recs g.1), g.2.2.1, g.2.2.2)

theorem evalKeyCoord_take (recs : List SlotRec) (s cut : ℕ) (hs : s < cut) (kc : KeyCoord)
    (hdr : match kc with | .dr s' _ => s' < cut | _ => True) :
    evalKeyCoord recs s kc = evalKeyCoord (recs.take cut) s kc := by
  have hget : ∀ k, k < cut → recs.getD k rec0 = (recs.take cut).getD k rec0 := fun k hk => by
    rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt hk]
  cases kc with
  | rho _ => simp only [evalKeyCoord, hget s hs]
  | flip _ => simp only [evalKeyCoord, hget s hs]
  | dr s' _ => simp only [evalKeyCoord, hget s' hdr]
  | zero => rfl

theorem evalSymGroup_take (recs : List SlotRec) (g : SymGroup) (cut : ℕ) (hs : g.1 < cut)
    (hdr : g.2.1.all (fun kc => match kc with | .dr s' _ => decide (s' < cut) | _ => true) = true) :
    evalSymGroup recs g = evalSymGroup (recs.take cut) g := by
  unfold evalSymGroup; congr 1
  refine List.map_congr_left (fun kc hkc => evalKeyCoord_take recs g.1 cut hs kc ?_)
  have hall := List.all_eq_true.mp hdr kc hkc
  cases kc with | rho _ | flip _ | zero => trivial | dr _ _ => exact of_decide_eq_true hall

theorem evalKeyCoord_of_coordS (recs : List SlotRec) (b g a : Fp2) (s : ℕ) (hs : s < recs.length)
    (c : CoordS) (kc : KeyCoord) (htk : toKeyCoord c = some kc)
    (hle : match kc with | .dr s' _ => s' ≤ s | _ => True) :
    let r := recs.getD s rec0
    let ev := Sym.eval (histOf b g a (recs.take s)) s r.draws
    (match c.eval ev with
      | .rho k => r.rho.getD k Fp2.zero
      | .flip k => Fp2.one.sub (r.rho.getD k Fp2.zero)
      | .fixed v => v) = evalKeyCoord recs s kc := by
  cases c with
  | rho _ => cases htk; rfl
  | flip _ => cases htk; rfl
  | fixed sy =>
    cases sy with
    | zero => cases htk; rfl
    | dr s' i =>
      cases htk; dsimp only at hle
      change Exec.Block.drawAt (histOf b g a (recs.take s)) s (recs.getD s rec0).draws s' i
        = (recs.getD s' rec0).draws.getD i Fp2.zero
      unfold Exec.Block.drawAt
      by_cases heq : s' = s
      · rw [ite_eq_left heq, heq]
      · rw [ite_eq_right heq]
        have hlt : s' < s := by omega
        have hltLen : s' < recs.length := by omega
        have hget : ((histOf b g a (recs.take s)).draws.getD s' []) = (recs.getD s' rec0).draws := by
          unfold histOf
          rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map,
            List.getElem?_take_of_lt hlt, List.getElem?_eq_getElem hltLen]; rfl
        rw [hget]
    | one | negOne | base _ | p16 _ | p256 _ | u64 _ | alpha | beta | gtag _
    | add _ _ | sub _ _ | mul _ _ | neg _ | pow _ _ => cases htk

theorem mapMOpt_coords_eval (recs : List SlotRec) (b g a : Fp2) (s : ℕ) (hs : s < recs.length) :
    ∀ (cs : List CoordS) (ks : List KeyCoord),
      mapMOpt toKeyCoord cs = some ks →
      ks.all (fun kc => match kc with | .dr s' _ => decide (s' ≤ s) | _ => true) = true →
      let r := recs.getD s rec0
      let ev := Sym.eval (histOf b g a (recs.take s)) s r.draws
      (cs.map (CoordS.eval ev)).map (fun
        | .rho k => r.rho.getD k Fp2.zero
        | .flip k => Fp2.one.sub (r.rho.getD k Fp2.zero)
        | .fixed v => v) = ks.map (evalKeyCoord recs s)
  | [], [], _, _ => rfl
  | [], _ :: _, h, _ => by cases h
  | _ :: _, [], h, _ => by unfold mapMOpt at h; split at h <;> cases h
  | c :: cs, k :: ks, h, hle => by
    unfold mapMOpt at h
    cases hc : toKeyCoord c with
    | none => rw [hc] at h; cases h
    | some k' =>
      cases hcs : mapMOpt toKeyCoord cs with
      | none => rw [hc, hcs] at h; cases h
      | some ks' =>
        rw [hc, hcs] at h; have h1 := Option.some.inj h; simp only [List.cons.injEq] at h1
        obtain ⟨hkEq, hksEq⟩ := h1; rw [hkEq] at hc; rw [hksEq] at hcs
        simp only [List.all_cons, Bool.and_eq_true] at hle
        dsimp only; rw [List.map_cons, List.map_cons, List.map_cons]
        exact congrArg₂ List.cons
          (evalKeyCoord_of_coordS recs b g a s hs c k hc (by cases k with | dr _ _ => exact of_decide_eq_true hle.1 | rho _ | flip _ | zero => trivial))
          (mapMOpt_coords_eval recs b g a s hs cs ks hcs hle.2)

inductive CollPlan where
  | impossible | pinRho (s round coord : ℕ) | pinZeroLeft (s round coord : ℕ)
  | pinDr (s drawIdx prevIdx coord : ℕ) | pinRhoEqDr (s round drawIdx coord : ℕ) | pinHalf (s round coord : ℕ)
  deriving DecidableEq

def checkCollPlan (nSlots : ℕ) (mains draws : ℕ → ℕ) (g₁ g₂ : SymGroup) : CollPlan → Bool
  | .impossible => decide (g₁.2.2 ≠ g₂.2.2)
  | .pinRho s r coord =>
    decide (g₁.1 < s) && decide (g₂.1 = s) && decide (s < nSlots) && decide (r < mains s)
      && decide (coord < g₂.2.1.length) && decide (g₂.2.1.getD coord .zero = .rho r)
      && g₁.2.1.all (fun kc => match kc with | .dr s' _ => decide (s' < s) | _ => true)
  | .pinZeroLeft s r coord =>
    decide (g₁.1 = s) && decide (s < nSlots) && decide (r < mains s)
      && decide (coord < g₁.2.1.length) && decide (coord < g₂.2.1.length)
      && decide (g₁.2.1.getD coord .zero = .rho r) && decide (g₂.2.1.getD coord .zero = .zero)
  | .pinDr s drawIdx prevIdx coord =>
    decide (g₁.1 = s) && decide (g₂.1 = s) && decide (s < nSlots) && decide (prevIdx < drawIdx)
      && decide (drawIdx < draws s) && decide (coord < g₁.2.1.length) && decide (coord < g₂.2.1.length)
      && decide (g₁.2.1.getD coord .zero = .dr s prevIdx) && decide (g₂.2.1.getD coord .zero = .dr s drawIdx)
  | .pinRhoEqDr s r drawIdx coord =>
    decide (g₁.1 = s) && decide (g₂.1 = s) && decide (s < nSlots) && decide (r < mains s)
      && decide (coord < g₁.2.1.length) && decide (coord < g₂.2.1.length)
      && decide (g₁.2.1.getD coord .zero = .rho r) && decide (g₂.2.1.getD coord .zero = .dr s drawIdx)
  | .pinHalf s r coord =>
    decide (g₁.1 = s) && decide (g₂.1 = s) && decide (s < nSlots) && decide (r < mains s)
      && decide (coord < g₁.2.1.length) && decide (coord < g₂.2.1.length)
      && decide (g₁.2.1.getD coord .zero = .rho r) && decide (g₂.2.1.getD coord .zero = .flip r)

def findCollPlan (mains draws : ℕ → ℕ) (g₁ g₂ : SymGroup) : CollPlan :=
  if g₁.2.2 ≠ g₂.2.2 then .impossible
  else if g₁.1 < g₂.1 then
    match (List.range g₂.2.1.length).findSome? (fun c =>
      match g₂.2.1.getD c .zero with | .rho r => if r < mains g₂.1 then some (c, r) else none | _ => none) with
    | some (c, r) => .pinRho g₂.1 r c
    | none =>
      match (List.range (min g₁.2.1.length g₂.2.1.length)).findSome? (fun c =>
        match g₁.2.1.getD c .zero, g₂.2.1.getD c .zero with
        | .rho r, .zero => if r < mains g₁.1 then some (c, r) else none | _, _ => none) with
      | some (c, r) => .pinZeroLeft g₁.1 r c
      | none => .impossible
  else
    let s := g₁.1
    match (List.range (min g₁.2.1.length g₂.2.1.length)).findSome? (fun c =>
      match g₁.2.1.getD c .zero, g₂.2.1.getD c .zero with
      | .dr s₁ i₁, .dr s₂ i₂ => if s₁ = s ∧ s₂ = s ∧ i₁ < i₂ ∧ i₂ < draws s then some (CollPlan.pinDr s i₂ i₁ c) else none
      | .rho r, .dr s₂ i₂ => if s₂ = s ∧ r < mains s then some (CollPlan.pinRhoEqDr s r i₂ c) else none
      | .rho r₁, .flip r₂ => if r₁ = r₂ ∧ r₁ < mains s then some (CollPlan.pinHalf s r₁ c) else none
      | _, _ => none) with
    | some pl => pl
    | none => .impossible

noncomputable def collPlanSite {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (preS : ℕ → Coins → TProg (α × List SlotRec × Acc)) (nSlots mPreS dMax rMax : ℕ)
    (hs : ∀ s, s < nSlots → ∀ c, TProg.Sep key (preS s c))
    (hsq : ∀ s, s < nSlots → ∀ c, SqLE mPreS (preS s c))
    (hd : ∀ s, s < nSlots → ∀ x, (Pf x s).draws s ≤ dMax)
    (hmBound : mPreS + dMax + 1 + rMax < 2 ^ 64)
    (g₁ : SymGroup) (plan : CollPlan) : ProtocolClassify.Site (QB Lq) Coins shdP_K :=
  match plan with
  | .impossible => shdP_emptySite Lq
  | .pinRho s r coord =>
    if h : s < nSlots then
      zkeyCollisionStartSite Lq hLq key domain hdom
        (fun c => depRoundDrProg Pf Df bga (preS s c) s (min r rMax))
        (fun y => ((evalSymGroup y.1.2.1 g₁).1.getD coord Fp2.zero).toK shdP_U)
        (fun c => sep_depRoundDrProg key Pf Df bga (preS s c) s (min r rMax) (hs s h c))
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depRoundDrProg Pf Df bga (preS s c) s (min r rMax) mPreS dMax (hsq s h c) (hd s h)) (by omega) dg)
    else shdP_emptySite Lq
  | .pinZeroLeft s r _ =>
    if h : s < nSlots then
      zkeyCollisionStartSite Lq hLq key domain hdom
        (fun c => depRoundDrProg Pf Df bga (preS s c) s (min r rMax))
        (fun _ => (0 : shdP_K))
        (fun c => sep_depRoundDrProg key Pf Df bga (preS s c) s (min r rMax) (hs s h c))
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depRoundDrProg Pf Df bga (preS s c) s (min r rMax) mPreS dMax (hsq s h c) (hd s h)) (by omega) dg)
    else shdP_emptySite Lq
  | .pinDr s drawIdx prevIdx _ =>
    if h : s < nSlots then
      zkeyCollisionStartSite Lq hLq key domain hdom
        (fun c => drawProg (min drawIdx dMax) (preS s c))
        (fun y => (y.2.getD prevIdx Fp2.zero).toK shdP_U)
        (fun c => sep_drawProg key (min drawIdx dMax) (preS s c) (hs s h c))
        (fun c dg => noWrap_start_of_sqLE (sqLE_drawProg (min drawIdx dMax) mPreS (preS s c) (hsq s h c)) (by omega) dg)
    else shdP_emptySite Lq
  | .pinRhoEqDr s r drawIdx _ =>
    if h : s < nSlots then
      zkeyCollisionStartSite Lq hLq key domain hdom
        (fun c => depRoundDrProg Pf Df bga (preS s c) s (min r rMax))
        (fun y => (y.2.getD drawIdx Fp2.zero).toK shdP_U)
        (fun c => sep_depRoundDrProg key Pf Df bga (preS s c) s (min r rMax) (hs s h c))
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depRoundDrProg Pf Df bga (preS s c) s (min r rMax) mPreS dMax (hsq s h c) (hd s h)) (by omega) dg)
    else shdP_emptySite Lq
  | .pinHalf s r _ =>
    if h : s < nSlots then
      zkeyCollisionStartSite Lq hLq key domain hdom
        (fun c => depRoundDrProg Pf Df bga (preS s c) s (min r rMax))
        (fun _ => (2 : shdP_K)⁻¹)
        (fun c => sep_depRoundDrProg key Pf Df bga (preS s c) s (min r rMax) (hs s h c))
        (fun c dg => noWrap_start_of_sqLE
          (sqLE_depRoundDrProg Pf Df bga (preS s c) s (min r rMax) mPreS dMax (hsq s h c) (hd s h)) (by omega) dg)
    else shdP_emptySite Lq

theorem collPlanSite_k_delta {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (preS : ℕ → Coins → TProg (α × List SlotRec × Acc)) (nSlots mPreS dMax rMax : ℕ)
    (hs : ∀ s, s < nSlots → ∀ c, TProg.Sep key (preS s c))
    (hsq : ∀ s, s < nSlots → ∀ c, SqLE mPreS (preS s c))
    (hd : ∀ s, s < nSlots → ∀ x, (Pf x s).draws s ≤ dMax)
    (hmBound : mPreS + dMax + 1 + rMax < 2 ^ 64)
    (g₁ : SymGroup) (plan : CollPlan) :
    (collPlanSite Lq hLq key domain hdom Pf Df bga preS nSlots mPreS dMax rMax hs hsq hd hmBound g₁ plan).k ≤ 1
      ∧ (collPlanSite Lq hLq key domain hdom Pf Df bga preS nSlots mPreS dMax rMax hs hsq hd hmBound g₁ plan).δ = 0 := by
  cases plan with
  | impossible => exact ⟨by change 0 ≤ 1; omega, rfl⟩
  | pinRho s _ _ | pinZeroLeft s _ _ | pinDr s _ _ _ | pinRhoEqDr s _ _ _ | pinHalf s _ _ =>
    dsimp only [collPlanSite]; by_cases h : s < nSlots
    · rw [dite_eq_left h]; exact ⟨le_rfl, rfl⟩
    · rw [dite_eq_right h]; exact ⟨by change 0 ≤ 1; omega, rfl⟩

theorem collPlanSite_fires {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (hd : Coins → TProg α) (nSlots mPreS dMax rMax : ℕ) (mains draws : ℕ → ℕ)
    (hs : ∀ s, s < nSlots → ∀ c, TProg.Sep key (famPre Pf Df bga (hd c) s))
    (hsq : ∀ s, s < nSlots → ∀ c, SqLE mPreS (famPre Pf Df bga (hd c) s))
    (hdB : ∀ s, s < nSlots → ∀ x, (Pf x s).draws s ≤ dMax)
    (hmBound : mPreS + dMax + 1 + rMax < 2 ^ 64)
    (G : QB Lq → Dig) (c : Coins) (x : α) (t3 : Tr)
    (hF : (hd c).final (liftH G) (Tr.newKeyed (liftH G) domain key) = (t3, x))
    (hmEq : ∀ s, s < nSlots → (slotShape (Pf x s) s).1 = mains s ∧ mains s ≤ rMax)
    (hdEq : ∀ s, s < nSlots → (Pf x s).draws s = draws s)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hfam : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 nSlots [] 0 {} t3
      = .ok (sps, recs, acc, t4))
    (g₁ g₂ : SymGroup) (plan : CollPlan)
    (hchk : checkCollPlan nSlots mains draws g₁ g₂ plan = true)
    (heq : evalSymGroup recs g₁ = evalSymGroup recs g₂) :
    (collPlanSite Lq hLq key domain hdom Pf Df bga (fun s c' => famPre Pf Df bga (hd c') s)
      nSlots mPreS dMax rMax hs hsq hdB hmBound g₁ plan).fires shdP_U G c := by
  let t0 := Tr.newKeyed (liftH G) domain key
  obtain ⟨-, -, hslot⟩ := famProve_split (liftH G) (Pf x) (Df x) _ _ _ nSlots [] 0 {} t3 sps recs acc t4 hfam
  have hslot' : ∀ s, s < nSlots → ∃ ti acc₁ df,
      (famPre Pf Df bga (hd c) s).final (liftH G) t0 = (ti, (x, recs.take s, acc₁))
      ∧ (Pf x s).define s (histOf (bga x).1 (bga x).2.1 (bga x).2.2 (recs.take s))
          (ti.challengeFp2Vec (liftH G) ((Pf x s).draws s)).1 = .ok df
      ∧ (recs.getD s rec0).draws = (ti.challengeFp2Vec (liftH G) ((Pf x s).draws s)).1
      ∧ (recs.getD s rec0).rho =
          (slotRho (liftH G) (Pf x s) (Df x s) s (histOf (bga x).1 (bga x).2.1 (bga x).2.2 (recs.take s)) acc₁ ti df).take
            (slotShape (Pf x s) s).1 := fun s hsLt => by
    obtain ⟨sps₁, recs₁, acc₁, ti, sp, r, acc₂, t₂, hfam1, hr1, hget, hsp⟩ := hslot s hsLt
    simp only [Nat.zero_add, List.length_nil] at hr1 hget; subst hr1
    have hsp' := slotProve_congr_idx (Nat.zero_add s) hsp
    obtain ⟨df, hdf, hdr, hrho, -, -, -, -, -, -, -⟩ :=
      slotProve_ok_struct (liftH G) (Pf x s) (Df x s) s _ acc₁ ti sp r acc₂ t₂ hsp'
    exact ⟨ti, acc₁, df, by rw [final_famPre (liftH G) Pf Df bga (hd c) s t0 sps₁ (recs.take s) acc₁ ti (by rw [hF]; exact hfam1), hF],
      hdf, by rw [hget]; exact hdr, by rw [hget]; exact hrho⟩
  have hcoordEq : ∀ coord, (evalSymGroup recs g₁).1.getD coord Fp2.zero
      = (evalSymGroup recs g₂).1.getD coord Fp2.zero := fun coord => congrArg (fun k => k.1.getD coord Fp2.zero) heq
  have hmapGetD : ∀ (g : SymGroup) (coord : ℕ), coord < g.2.1.length →
      (evalSymGroup recs g).1.getD coord Fp2.zero = evalKeyCoord recs g.1 (g.2.1.getD coord .zero) := fun g coord hlt => by
    unfold evalSymGroup; rw [List.getD_eq_getElem?_getD, List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_getElem hlt]; rfl
  cases plan with
  | impossible =>
    simp only [checkCollPlan, decide_eq_true_eq] at hchk
    have h22 : g₁.2.2 = g₂.2.2 := Prod.ext (congrArg (fun k => k.2.1) heq) (congrArg (fun k => k.2.2) heq)
    have hf : False := hchk h22; cases hf
  | pinRho s r coord =>
    simp only [checkCollPlan, Bool.and_eq_true, decide_eq_true_eq] at hchk
    obtain ⟨⟨⟨⟨⟨⟨hg1s, hg2s⟩, hsLt⟩, hrLt⟩, hcoordLt⟩, hkc⟩, hallDr⟩ := hchk
    obtain ⟨ti, acc₁, df, hpre, hdf, -, hrho⟩ := hslot' s hsLt
    dsimp only [collPlanSite]; rw [dite_eq_left hsLt, zkeyCollisionStartSite_fires]; dsimp only
    have hch := final_depRoundDrProg_chal (liftH G) Pf Df bga (famPre Pf Df bga (hd c) s) s r t0 ti x
      (recs.take s) acc₁ hpre df hdf (by rw [(hmEq s hsLt).1]; exact hrLt)
    rw [Nat.min_eq_left (by have := (hmEq s hsLt).2; omega), hch.1, hch.2, ← hrho]
    have h2 : (evalSymGroup recs g₂).1.getD coord Fp2.zero = (recs.getD s rec0).rho.getD r Fp2.zero := by
      rw [hmapGetD g₂ coord hcoordLt, hkc, hg2s]; rfl
    exact congrArg (Fp2.toK shdP_U) (h2.symm.trans ((hcoordEq coord).symm.trans
      (congrArg (fun k => k.1.getD coord Fp2.zero) (evalSymGroup_take recs g₁ s hg1s hallDr))))
  | pinZeroLeft s r coord =>
    simp only [checkCollPlan, Bool.and_eq_true, decide_eq_true_eq] at hchk
    obtain ⟨⟨⟨⟨⟨⟨hg1s, hsLt⟩, hrLt⟩, hc1⟩, hc2⟩, hk1⟩, hk2⟩ := hchk
    obtain ⟨ti, acc₁, df, hpre, hdf, -, hrho⟩ := hslot' s hsLt
    dsimp only [collPlanSite]; rw [dite_eq_left hsLt, zkeyCollisionStartSite_fires]; dsimp only
    have hch := final_depRoundDrProg_chal (liftH G) Pf Df bga (famPre Pf Df bga (hd c) s) s r t0 ti x
      (recs.take s) acc₁ hpre df hdf (by rw [(hmEq s hsLt).1]; exact hrLt)
    rw [Nat.min_eq_left (by have := (hmEq s hsLt).2; omega), hch.2, ← hrho]
    have h1 : (evalSymGroup recs g₁).1.getD coord Fp2.zero = (recs.getD s rec0).rho.getD r Fp2.zero := by
      rw [hmapGetD g₁ coord hc1, hk1, hg1s]; rfl
    have h2 : (evalSymGroup recs g₂).1.getD coord Fp2.zero = Fp2.zero := by rw [hmapGetD g₂ coord hc2, hk2]; rfl
    rw [h1.symm.trans ((hcoordEq coord).trans h2)]; exact Fp2.toK_zero shdP_U
  | pinDr s drawIdx prevIdx coord =>
    simp only [checkCollPlan, Bool.and_eq_true, decide_eq_true_eq] at hchk
    obtain ⟨⟨⟨⟨⟨⟨⟨⟨-, -⟩, hsLt⟩, hpd⟩, hdLt⟩, hc1⟩, hc2⟩, hk1⟩, hk2⟩ := hchk
    have hdLt' : drawIdx < (Pf x s).draws s := by rw [hdEq s hsLt]; exact hdLt
    obtain ⟨ti, acc₁, -, hpre, -, hdr, -⟩ := hslot' s hsLt
    dsimp only [collPlanSite]; rw [dite_eq_left hsLt, zkeyCollisionStartSite_fires]; dsimp only
    rw [Nat.min_eq_left (by have := hdB s hsLt x; omega), final_drawProg, hpre]; dsimp only
    have hcur : challengeFp2Of (liftH G ⟨(ti.challengeFp2Vec (liftH G) drawIdx).2.key,
        squeezeMsg (ti.challengeFp2Vec (liftH G) drawIdx).2.state (ti.challengeFp2Vec (liftH G) drawIdx).2.counter⟩)
        = (recs.getD s rec0).draws.getD drawIdx Fp2.zero := by
      rw [hdr]; exact (challengeFp2Vec_getD (liftH G) ((Pf x s).draws s) drawIdx ti hdLt').symm
    have hprev : (ti.challengeFp2Vec (liftH G) drawIdx).1.getD prevIdx Fp2.zero
        = (recs.getD s rec0).draws.getD prevIdx Fp2.zero := by
      rw [hdr, challengeFp2Vec_getD (liftH G) drawIdx prevIdx ti hpd,
        challengeFp2Vec_getD (liftH G) ((Pf x s).draws s) prevIdx ti (by omega)]
    rw [hcur, hprev]
    have h1 : (evalSymGroup recs g₁).1.getD coord Fp2.zero = (recs.getD s rec0).draws.getD prevIdx Fp2.zero := by
      rw [hmapGetD g₁ coord hc1, hk1]; rfl
    have h2 : (evalSymGroup recs g₂).1.getD coord Fp2.zero = (recs.getD s rec0).draws.getD drawIdx Fp2.zero := by
      rw [hmapGetD g₂ coord hc2, hk2]; rfl
    exact congrArg (Fp2.toK shdP_U) (h2.symm.trans ((hcoordEq coord).symm.trans h1))
  | pinRhoEqDr s r drawIdx coord =>
    simp only [checkCollPlan, Bool.and_eq_true, decide_eq_true_eq] at hchk
    obtain ⟨⟨⟨⟨⟨⟨⟨hg1s, -⟩, hsLt⟩, hrLt⟩, hc1⟩, hc2⟩, hk1⟩, hk2⟩ := hchk
    obtain ⟨ti, acc₁, df, hpre, hdf, hdr, hrho⟩ := hslot' s hsLt
    dsimp only [collPlanSite]; rw [dite_eq_left hsLt, zkeyCollisionStartSite_fires]; dsimp only
    have hch := final_depRoundDrProg_chal (liftH G) Pf Df bga (famPre Pf Df bga (hd c) s) s r t0 ti x
      (recs.take s) acc₁ hpre df hdf (by rw [(hmEq s hsLt).1]; exact hrLt)
    rw [Nat.min_eq_left (by have := (hmEq s hsLt).2; omega), hch.1, hch.2, ← hrho, ← hdr]
    have h1 : (evalSymGroup recs g₁).1.getD coord Fp2.zero = (recs.getD s rec0).rho.getD r Fp2.zero := by
      rw [hmapGetD g₁ coord hc1, hk1, hg1s]; rfl
    have h2 : (evalSymGroup recs g₂).1.getD coord Fp2.zero = (recs.getD s rec0).draws.getD drawIdx Fp2.zero := by
      rw [hmapGetD g₂ coord hc2, hk2]; rfl
    exact congrArg (Fp2.toK shdP_U) (h1.symm.trans ((hcoordEq coord).trans h2))
  | pinHalf s r coord =>
    simp only [checkCollPlan, Bool.and_eq_true, decide_eq_true_eq] at hchk
    obtain ⟨⟨⟨⟨⟨⟨⟨hg1s, hg2s⟩, hsLt⟩, hrLt⟩, hc1⟩, hc2⟩, hk1⟩, hk2⟩ := hchk
    obtain ⟨ti, acc₁, df, hpre, hdf, -, hrho⟩ := hslot' s hsLt
    dsimp only [collPlanSite]; rw [dite_eq_left hsLt, zkeyCollisionStartSite_fires]; dsimp only
    have hch := final_depRoundDrProg_chal (liftH G) Pf Df bga (famPre Pf Df bga (hd c) s) s r t0 ti x
      (recs.take s) acc₁ hpre df hdf (by rw [(hmEq s hsLt).1]; exact hrLt)
    rw [Nat.min_eq_left (by have := (hmEq s hsLt).2; omega), hch.2, ← hrho]
    have h1 : (evalSymGroup recs g₁).1.getD coord Fp2.zero = (recs.getD s rec0).rho.getD r Fp2.zero := by
      rw [hmapGetD g₁ coord hc1, hk1, hg1s]; rfl
    have h2 : (evalSymGroup recs g₂).1.getD coord Fp2.zero
        = Fp2.one.sub ((recs.getD s rec0).rho.getD r Fp2.zero) := by
      rw [hmapGetD g₂ coord hc2, hk2, hg2s]; rfl
    have hcanR : ((recs.getD s rec0).rho.getD r Fp2.zero).Canon := by
      rw [hrho]; exact Fp2.canon_getD (fun y hy => scChal_canon (liftH G) _ _ y (List.mem_of_mem_take hy)) r
    exact fp2_eq_one_sub_self_toK _ hcanR (h1.symm.trans ((hcoordEq coord).trans h2))

def dedupSymGroupsOrder (l : List SymGroup) : List SymGroup :=
  l.foldl (fun acc g => if g ∈ acc then acc else acc ++ [g]) []

def checkSymPriv (nSlots logN maskBase prox : ℕ) (extOf : ℕ → ℕ) (groups : List SymGroup)
    (sp : ℕ × PrivS) : Bool :=
  let s := sp.1; let p := sp.2; let n := 2 ^ logN; let c0 := (p.slices.headD (0, false)).1 % n
  decide (s < nSlots) && !p.slices.isEmpty && decide (0 < p.log) && decide (p.coords.length = p.log)
    && decide (p.extRound < extOf s)
    && p.slices.all (fun sc => decide (sc.1 / n + (2 ^ p.log + n - 1) / n ≤ maskBase)
        && (decide (logN ≤ p.log) || decide (sc.1 % n = c0)))
    && decide (maskBase ≤ p.maskRow) && decide (p.maskRow + 2 ≤ prox) && decide ((p.maskRow - maskBase) % 2 = 0)
    && match privSymKey logN p with
       | none => false
       | some k => decide ((s, k) ∈ groups) && k.1.all (fun kc => match kc with | .dr s' _ => decide (s' ≤ s) | _ => true)

def checkSymSpec (nSlots logN maskBase prox nClaims : ℕ) (hasSum : Bool)
    (mains exts draws : ℕ → ℕ) (specs : List (ℕ × PrivS)) (groups : List SymGroup) : Bool :=
  let specKeys := specs.filterMap (fun sp => (privSymKey logN sp.2).map (fun k => (sp.1, k)))
  decide (specs.length = nClaims)
    && decide (specs.map (fun sp => sp.2.maskRow) = (List.range nClaims).map (fun i => maskBase + 2 * i))
    && specs.all (checkSymPriv nSlots logN maskBase prox exts groups)
    && groups.all (fun g => (!hasSum || decide (0 < g.2.1.length)) && decide (g ∈ specKeys))
    && (strictPairs groups.length).all (fun ab =>
        let g₁ := groups.getD ab.1 (0, ([], 0, 0))
        let g₂ := groups.getD ab.2 (0, ([], 0, 0))
        checkCollPlan nSlots mains draws g₁ g₂ (findCollPlan mains draws g₁ g₂))

noncomputable def symCollFamily {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (preS : ℕ → Coins → TProg (α × List SlotRec × Acc)) (nSlots mPreS dMax rMax : ℕ)
    (mains draws : ℕ → ℕ) (groups : List SymGroup) (gTotal nColl : ℕ)
    (hlen : (strictPairs gTotal).length = nColl)
    (hs : ∀ s, s < nSlots → ∀ c, TProg.Sep key (preS s c))
    (hsq : ∀ s, s < nSlots → ∀ c, SqLE mPreS (preS s c))
    (hd : ∀ s, s < nSlots → ∀ x, (Pf x s).draws s ≤ dMax)
    (hmBound : mPreS + dMax + 1 + rMax < 2 ^ 64) : OpenCollFamily Lq Coins nColl :=
  mkPairCollFamily gTotal nColl hlen
    (fun a b =>
      if b < groups.length then
        let g₁ := groups.getD a (0, ([], 0, 0)); let g₂ := groups.getD b (0, ([], 0, 0))
        collPlanSite Lq hLq key domain hdom Pf Df bga preS nSlots mPreS dMax rMax hs hsq hd hmBound
          g₁ (findCollPlan mains draws g₁ g₂)
      else shdP_emptySite Lq)
    (fun _ b => by
      by_cases hb : b < groups.length
      · rw [ite_eq_left hb]
        exact (collPlanSite_k_delta Lq hLq key domain hdom Pf Df bga preS nSlots mPreS dMax rMax hs hsq hd hmBound _ _).1
      · rw [ite_eq_right hb]; change 0 ≤ 1; omega)
    (fun _ b => by
      by_cases hb : b < groups.length
      · rw [ite_eq_left hb]
        exact (collPlanSite_k_delta Lq hLq key domain hdom Pf Df bga preS nSlots mPreS dMax rMax hs hsq hd hmBound _ _).2
      · rw [ite_eq_right hb]; rfl)

/-- **Unified `OpenAuditOk` discharge** for ANY non-boundary commitment opening (`A` or `H`) verified by `checkSymSpec`. -/
theorem openAuditOk_of_symSpec {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (Pf : α → ℕ → BlockParams) (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
    (hd : Coins → TProg α) (nSlots logN rows maskBase prox nNonSum gTotal nColl : ℕ)
    (mPreS dMax rMax : ℕ) (mains exts draws : ℕ → ℕ)
    (specs : List (ℕ × PrivS)) (groups : List SymGroup)
    (sumOpt : Option (ℕ × ℕ × Exec.Block.ZClaim × List Exec.Block.ZPart))
    (hlen : (strictPairs gTotal).length = nColl)
    (hs : ∀ s, s < nSlots → ∀ c, TProg.Sep key (famPre Pf Df bga (hd c) s))
    (hsq : ∀ s, s < nSlots → ∀ c, SqLE mPreS (famPre Pf Df bga (hd c) s))
    (hdB : ∀ s, s < nSlots → ∀ x, (Pf x s).draws s ≤ dMax)
    (hmBound : mPreS + dMax + 1 + rMax < 2 ^ 64)
    (hlogN : 0 < logN) (hproxRows : prox + 2 = rows) (hsiteLen : maskBase + 2 * nNonSum = prox)
    (hgTot : gTotal = groups.length + (if sumOpt.isSome then 1 else 0))
    (hcheck : checkSymSpec nSlots logN maskBase prox nNonSum sumOpt.isSome mains exts draws specs groups = true)
    (G : QB Lq → Dig) (c : Coins) (x : α) (t3 : Tr)
    (hF : (hd c).final (liftH G) (Tr.newKeyed (liftH G) domain key) = (t3, x))
    (hShape : ∀ s, s < nSlots → (slotShape (Pf x s) s).1 = mains s ∧ mains s ≤ rMax ∧ (slotShape (Pf x s) s).2.1 = exts s)
    (hdEq : ∀ s, s < nSlots → (Pf x s).draws s = draws s)
    (hRowLog : ∀ sp ∈ specs, rowLog (Pf x sp.1) sp.2.cm = logN)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hfam : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 nSlots [] 0 {} t3
      = .ok (sps, recs, acc, t4))
    (hSumOk : ∀ u0 u1 sc pre, sumOpt = some (u0, u1, sc, pre) →
      u1 = u0 + 1 ∧ maskBase = u1 + 1
      ∧ sc.parts = pre ++ [⟨u0 * 2 ^ logN, logN, Fp2.one, []⟩, ⟨u1 * 2 ^ logN, logN, Fp2.one.mul fp2U, []⟩]
      ∧ ∀ q ∈ pre, q.point = [] ∧ logN ≤ q.logSize ∧ partHi q (2 ^ logN) ≤ u0)
    (claims : List Exec.Block.ZClaim)
    (hclaimsParts : claims.map Exec.Block.ZClaim.parts =
      specs.map (fun sp =>
        let r := recs.getD sp.1 rec0
        let ev := Sym.eval (histOf (bga x).1 (bga x).2.1 (bga x).2.2 (recs.take sp.1)) sp.1 r.draws
        let p := sp.2.eval ev
        (buildClaim (Pf x sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts)
      ++ (match sumOpt with | none => [] | some (_, _, sc, _) => [sc.parts])) :
    OpenAuditOk ⟨rows, List.range' maskBase (prox - maskBase),
        sumOpt.map (fun q => (q.1, q.2.1)), prox, gTotal⟩ logN
      (nNonSum + if sumOpt.isSome then 1 else 0) nColl
      (symCollFamily Lq hLq key domain hdom Pf Df bga (fun s c' => famPre Pf Df bga (hd c') s)
        nSlots mPreS dMax rMax mains draws groups gTotal nColl hlen hs hsq hdB hmBound)
      G c claims := by
  let siteRows := List.range' maskBase (prox - maskBase)
  let sumRows := sumOpt.map (fun q => (q.1, q.2.1))
  let F := symCollFamily Lq hLq key domain hdom Pf Df bga (fun s c' => famPre Pf Df bga (hd c') s)
    nSlots mPreS dMax rMax mains draws groups gTotal nColl hlen hs hsq hdB hmBound
  let mkCl : ℕ × PrivS → Exec.Block.ZClaim := fun sp =>
    let r := recs.getD sp.1 rec0
    let ev := Sym.eval (histOf (bga x).1 (bga x).2.1 (bga x).2.2 (recs.take sp.1)) sp.1 r.draws
    let p := sp.2.eval ev
    buildClaim (Pf x sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero
  let cs2 : List Exec.Block.ZClaim := specs.map mkCl ++ sumOpt.elim [] (fun q => [q.2.2.1])
  have hcs2Parts : claims.map Exec.Block.ZClaim.parts = cs2.map Exec.Block.ZClaim.parts := by
    rw [hclaimsParts]; unfold cs2; rw [List.map_append, List.map_map]; cases sumOpt <;> rfl
  refine openAuditOk_of_parts_eq _ logN _ nColl F G c claims cs2 hcs2Parts ?_
  unfold checkSymSpec at hcheck; simp only [Bool.and_eq_true, decide_eq_true_eq] at hcheck
  obtain ⟨⟨⟨⟨hspLen, hmaskMap⟩, hspAll⟩, hgrAll⟩, hpairAll⟩ := hcheck
  obtain ⟨hrecsLen, -, hslot⟩ := famProve_split (liftH G) (Pf x) (Df x) _ _ _ nSlots [] 0 {} t3 sps recs acc t4 hfam
  rw [List.length_nil, Nat.zero_add] at hrecsLen
  have hrecEs : ∀ s, s < nSlots →
      (∀ e ∈ (recs.getD s rec0).es, e.Canon ∧ e ≠ Fp2.zero ∧ e ≠ Fp2.one)
      ∧ (recs.getD s rec0).es.length = exts s := fun s hsLt => by
    obtain ⟨_, _, _, _, sp, r, _, _, _, _, hget, hsp⟩ := hslot s hsLt
    simp only [Nat.zero_add, List.length_nil] at hget
    have hsp' := slotProve_congr_idx (Nat.zero_add s) hsp
    obtain ⟨_, _, _, _, _, he, heL, _, _, _, _⟩ := slotProve_ok_struct (liftH G) (Pf x s) (Df x s) s _ _ _ sp r _ _ hsp'
    rw [hget]; exact ⟨he, heL.trans (hShape s hsLt).2.2⟩
  have hspProp : ∀ sp ∈ specs,
      (mkCl sp).parts.flatMap (partSiteRows (2 ^ logN) siteRows) = [sp.2.maskRow, sp.2.maskRow + 1]
      ∧ (∀ nCl ci, SurvivingAuditClaim logN prox siteRows sumRows nCl ci (mkCl sp))
      ∧ (∀ q ∈ (mkCl sp).parts, partKeyAt q logN = claimKey logN (mkCl sp))
      ∧ ∃ k, privSymKey logN sp.2 = some k ∧ (sp.1, k) ∈ groups
          ∧ claimKey logN (mkCl sp) = evalSymGroup recs (sp.1, k) := by
    intro sp hspMem
    have h1 := List.all_eq_true.mp hspAll sp hspMem
    unfold checkSymPriv at h1; simp only [Bool.and_eq_true, Bool.not_eq_true', decide_eq_true_eq] at h1
    obtain ⟨⟨⟨⟨⟨⟨⟨⟨⟨hsLt, hneSl⟩, hlogPos⟩, hcoLen⟩, hextLt⟩, hslAll⟩, hmb⟩, hmProx⟩, heven⟩, hsym⟩ := h1
    have hrl := hRowLog sp hspMem; have hes := hrecEs sp.1 hsLt
    let r := recs.getD sp.1 rec0
    let ev := Sym.eval (histOf (bga x).1 (bga x).2.1 (bga x).2.2 (recs.take sp.1)) sp.1 r.draws
    let p := sp.2.eval ev
    have hrl' : rowLog (Pf x sp.1) p.cm = logN := hrl
    have hptLen : (claimPoint p r.rho).length = p.log := by
      unfold claimPoint; rw [List.length_map]; change (sp.2.coords.map (CoordS.eval ev)).length = sp.2.log
      rw [List.length_map]; exact hcoLen
    have hdata : ∀ sc ∈ p.slices, sc.1 / 2 ^ rowLog (Pf x sp.1) p.cm
        + (2 ^ p.log + 2 ^ rowLog (Pf x sp.1) p.cm - 1) / 2 ^ rowLog (Pf x sp.1) p.cm ≤ maskBase := by
      intro sc hsc; obtain ⟨sc0, hsc0, rfl⟩ := List.mem_map.mp hsc
      have ha := List.all_eq_true.mp hslAll sc0 hsc0; simp only [Bool.and_eq_true, decide_eq_true_eq] at ha
      rw [hrl']; exact ha.1
    have hsurv : ∀ nCl ci,
        (mkCl sp).parts.flatMap (partSiteRows (2 ^ logN) siteRows) = [sp.2.maskRow, sp.2.maskRow + 1]
        ∧ SurvivingAuditClaim logN prox siteRows sumRows nCl ci (mkCl sp) := fun nCl ci => by
      have hs' := buildClaim_survivingAuditClaim (Pf x sp.1) p (claimPoint p r.rho) r.es Fp2.zero
        maskBase prox nCl ci sumRows (by rw [hrl']; exact hlogN) hlogPos hptLen hdata hmb hmProx heven
        (fun e he => (hes.1 e he).1) (fun e he => (hes.1 e he).2)
        (by change sp.2.extRound < (recs.getD sp.1 rec0).es.length; rw [hes.2]; exact hextLt)
      dsimp only at hs'; rwa [hrl'] at hs'
    have hunif := buildClaim_parts_uniform (Pf x sp.1) p (claimPoint p r.rho) r.es Fp2.zero
      (by rw [hrl']; exact hlogN)
      (fun hnil => by have h0 : sp.2.slices = [] := List.map_eq_nil_iff.mp hnil; rw [h0] at hneSl; cases hneSl)
      hlogPos hptLen (fun sc hsc hlt => by
        obtain ⟨sc0, hsc0, rfl⟩ := List.mem_map.mp hsc
        have ha := List.all_eq_true.mp hslAll sc0 hsc0
        simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq] at ha
        rw [hrl'] at hlt ⊢
        rcases ha.2 with hge | hmod
        · dsimp only [p, PrivS.eval] at hlt
          have hf : False := by omega
          cases hf
        · dsimp only [p, PrivS.eval]
          cases hs' : sp.2.slices with
          | nil => rw [hs'] at hneSl; cases hneSl
          | cons _ _ => rw [hs'] at hmod; dsimp only [List.map_cons, List.headD_cons] at hmod ⊢; exact hmod)
    dsimp only at hunif; rw [hrl'] at hunif
    cases hsk : privSymKey logN sp.2 with
    | none => rw [hsk] at hsym; cases hsym
    | some k =>
      rw [hsk] at hsym; simp only [Bool.and_eq_true, decide_eq_true_eq] at hsym
      obtain ⟨hkMem, hkDr⟩ := hsym; unfold privSymKey at hsk
      cases hmm : mapMOpt toKeyCoord (sp.2.coords.drop (sp.2.log - logN)) with
      | none => rw [hmm] at hsk; cases hsk
      | some ks =>
        rw [hmm] at hsk; simp only [Option.map_some, Option.some.injEq] at hsk
        have hdrop : (claimPoint p r.rho).drop (p.log - logN) = ks.map (evalKeyCoord recs sp.1) := by
          unfold claimPoint; change ((sp.2.coords.map (CoordS.eval ev)).map _).drop (sp.2.log - logN) = _
          rw [← List.map_drop, ← List.map_drop]
          exact mapMOpt_coords_eval recs (bga x).1 (bga x).2.1 (bga x).2.2 sp.1 (by omega) _ ks hmm (by rw [← hsk] at hkDr; exact hkDr)
        have hheadS : (p.slices.headD (0, Fp2.zero)).1 = (sp.2.slices.headD (0, false)).1 := by
          cases hs' : sp.2.slices with | nil => rw [hs'] at hneSl; cases hneSl | cons _ _ => simp [p, PrivS.eval, hs']
        have hck : claimKey logN (mkCl sp) = evalSymGroup recs (sp.1, k) := by
          dsimp only [mkCl]; rw [hunif.1, hdrop, hheadS, ← hsk]; unfold evalSymGroup
          by_cases hle : logN ≤ sp.2.log
          · have hleP : logN ≤ p.log := hle
            rw [ite_eq_left hleP, ite_eq_left hleP, ite_eq_left hle]
          · have hleP : ¬ logN ≤ p.log := hle
            rw [ite_eq_right hleP, ite_eq_right hleP, ite_eq_right hle]; rfl
        exact ⟨(hsurv 0 0).1, fun nCl ci => (hsurv nCl ci).2, hunif.2, ⟨k, rfl, hkMem, hck⟩⟩
  have hlenCs2 : cs2.length = nNonSum + if sumOpt.isSome then 1 else 0 := by
    unfold cs2; rw [List.length_append, List.length_map, hspLen]; cases sumOpt <;> simp
  have hflatNonSum : (specs.map mkCl).flatMap (fun cl => cl.parts.flatMap (partSiteRows (2 ^ logN) siteRows)) = siteRows := by
    have hmap : (specs.map mkCl).flatMap (fun cl => cl.parts.flatMap (partSiteRows (2 ^ logN) siteRows))
        = (specs.map (fun sp => sp.2.maskRow)).flatMap (fun m => [m, m + 1]) := by
      rw [List.flatMap_map, List.flatMap_map]; exact flatMap_congr_eq (fun sp hsp => (hspProp sp hsp).1)
    rw [hmap, hmaskMap, flatMap_pairs_eq_range' maskBase nNonSum]
    unfold siteRows; rw [show prox - maskBase = 2 * nNonSum by omega]
  have hsiteEven : siteRows.length % 2 = 0 := by unfold siteRows; rw [List.length_range']; omega
  have hsiteLt : ∀ r ∈ siteRows, r < rows := fun r hr => by unfold siteRows at hr; rw [range'_mem_iff] at hr; omega
  have haud : auditClaims cs2 (2 ^ logN) rows siteRows sumRows prox = .ok ()
      ∧ (∀ cl ∈ cs2, ∀ q ∈ cl.parts, partKeyAt q logN = claimKey logN cl)
      ∧ (∀ u0 u1 sc pre, sumOpt = some (u0, u1, sc, pre) → claimKey logN sc = ([], 0, 2 ^ logN)) := by
    cases hso : sumOpt with
    | none =>
      have hcs2Eq : cs2 = specs.map mkCl := by unfold cs2; rw [hso]; exact List.append_nil _
      refine ⟨(by
          rw [hcs2Eq]
          exact auditClaims_ok_of_surviving (specs.map mkCl) logN rows siteRows sumRows prox hproxRows hsiteEven hsiteLt
            (fun i hi => by
              rw [List.length_map] at hi; rw [List.getElem_map]
              exact (hspProp specs[i] (List.getElem_mem hi)).2.1 _ i)
            (fun r hr => by rw [hflatNonSum]; exact countNat_range'_of_mem _ _ r hr)),
        fun cl hcl => by rw [hcs2Eq] at hcl; obtain ⟨sp, hsp, rfl⟩ := List.mem_map.mp hcl; exact (hspProp sp hsp).2.2.1,
        fun _ _ _ _ h => by cases h⟩
    | some q =>
      obtain ⟨u0, u1, sc, pre⟩ := q
      obtain ⟨hu1, hmb, hscParts, hpre⟩ := hSumOk u0 u1 sc pre hso
      have hsumA := sumClaim_audit_of_parts logN u0 u1 maskBase prox nNonSum sc pre hu1 hmb (by omega) hscParts hpre
      have hcs2Eq : cs2 = specs.map mkCl ++ [sc] := by unfold cs2; rw [hso]; rfl
      have hsumRowsEq : sumRows = some (u0, u1) := by simp [sumRows, hso]
      have hlenApp : (specs.map mkCl ++ [sc]).length = nNonSum + 1 := by rw [← hcs2Eq, hlenCs2, hso]; rfl
      refine ⟨(by
          rw [hcs2Eq]
          exact auditClaims_ok_of_surviving (specs.map mkCl ++ [sc]) logN rows siteRows sumRows prox hproxRows hsiteEven hsiteLt
            (fun i hi => by
              by_cases hlt : i < nNonSum
              · have hlt' : i < (specs.map mkCl).length := by rw [List.length_map, hspLen]; exact hlt
                rw [List.getElem_append_left hlt', List.getElem_map]
                exact (hspProp specs[i] (List.getElem_mem (by omega))).2.1 _ i
              · have hieq : i = nNonSum := by rw [hlenApp] at hi; omega
                have hge : (specs.map mkCl).length ≤ i := by rw [List.length_map, hspLen]; omega
                rw [List.getElem_append_right hge]
                have hidx : i - (specs.map mkCl).length = 0 := by rw [List.length_map, hspLen]; omega
                simp only [hidx, List.getElem_singleton]; rw [hlenApp, hieq, hsumRowsEq]; exact hsumA.2.1)
            (fun r hr => by
              rw [List.flatMap_append, hflatNonSum, List.flatMap_singleton, hsumA.1, List.append_nil]
              exact countNat_range'_of_mem _ _ r hr)),
        fun cl hcl => by
          rw [hcs2Eq, List.mem_append, List.mem_singleton] at hcl
          rcases hcl with h1 | rfl
          · obtain ⟨sp, hsp, rfl⟩ := List.mem_map.mp h1; exact (hspProp sp hsp).2.2.1
          · intro q hq; rw [hsumA.2.2.1]; exact hsumA.2.2.2 q hq,
        fun u0' u1' sc' pre' h => by
          have he := Option.some.inj h; simp only [Prod.mk.injEq] at he; obtain ⟨-, -, rfl, -⟩ := he; exact hsumA.2.2.1⟩
  refine ⟨hlenCs2, haud.1, haud.2.1, fun grs hgr hne => ?_⟩
  let expKey : Fin gTotal → List Fp2 × ℕ × ℕ := fun a =>
    if a.val < groups.length then evalSymGroup recs (groups.getD a.val (0, ([], 0, 0))) else ([], 0, 2 ^ logN)
  have hleTot : groups.length ≤ gTotal := by rw [hgTot]; split_ifs <;> omega
  have hsub : ∀ cl ∈ cs2, ∃ a : Fin gTotal, claimKey logN cl = expKey a := fun cl hcl => by
    unfold cs2 at hcl; rw [List.mem_append] at hcl
    rcases hcl with h1 | h2
    · obtain ⟨sp, hsp, rfl⟩ := List.mem_map.mp h1
      obtain ⟨k, -, hkMem, hck⟩ := (hspProp sp hsp).2.2.2
      obtain ⟨m, hm, hget⟩ := exists_getD_of_mem (0, ([], 0, 0)) (sp.1, k) groups hkMem
      exact ⟨⟨m, by omega⟩, by unfold expKey; dsimp only; rw [ite_eq_left hm, hget]; exact hck⟩
    · cases hso : sumOpt with
      | none => rw [hso] at h2; cases h2
      | some q =>
        obtain ⟨u0, u1, sc, pre⟩ := q
        rw [hso] at h2; dsimp only [Option.elim] at h2; rw [List.mem_singleton] at h2; rw [h2]
        exact ⟨⟨groups.length, by rw [hgTot, hso]; simp⟩, by unfold expKey; dsimp only; rw [ite_eq_right (Nat.lt_irrefl _)]; exact haud.2.2 u0 u1 sc pre hso⟩
  have hsurj : ∀ a : Fin gTotal, ∃ cl ∈ cs2, claimKey logN cl = expKey a := fun a => by
    by_cases ha : a.val < groups.length
    · have hgMem : groups.getD a.val (0, ([], 0, 0)) ∈ groups := by
        rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem ha]; exact List.getElem_mem ha
      have hga := List.all_eq_true.mp hgrAll _ hgMem
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hga
      obtain ⟨sp, hspMem, hspMap⟩ := List.mem_filterMap.mp hga.2
      obtain ⟨k, hsk, -, hck⟩ := (hspProp sp hspMem).2.2.2
      rw [hsk] at hspMap; have hpairEq := Option.some.inj hspMap
      refine ⟨mkCl sp, List.mem_append_left _ (List.mem_map.mpr ⟨sp, hspMem, rfl⟩), ?_⟩
      unfold expKey; dsimp only at hpairEq; rw [ite_eq_left ha, hck, hpairEq]
    · cases hso : sumOpt with
      | none =>
        have hgtEq : gTotal = groups.length := by rw [hgTot, hso]; simp
        have haLt := a.isLt
        have hf : False := by omega
        cases hf
      | some q =>
        obtain ⟨u0, u1, sc, pre⟩ := q
        exact ⟨sc, by unfold cs2; rw [hso]; exact List.mem_append_right _ List.mem_cons_self,
          by unfold expKey; rw [ite_eq_right ha]; exact haud.2.2 u0 u1 sc pre hso⟩
  obtain ⟨-, a, b, hlt, heq⟩ := openingGroupsAt_ne_implies_collision cs2 logN gTotal grs expKey hgr hsub hsurj hne
  by_cases hb : b.val < groups.length
  · have ha : a.val < groups.length := by omega
    unfold expKey at heq; rw [ite_eq_left ha, ite_eq_left hb] at heq
    have hchkPair := List.all_eq_true.mp hpairAll (a.val, b.val) (mem_strictPairs groups.length a.val b.val hlt hb)
    have hfire := collPlanSite_fires Lq hLq key domain hdom Pf Df bga hd nSlots mPreS dMax rMax mains draws
      hs hsq hdB hmBound G c x t3 hF (fun s hsLt => ⟨(hShape s hsLt).1, (hShape s hsLt).2.1⟩) hdEq
      sps recs acc t4 hfam _ _ _ hchkPair heq
    refine mkPairCollFamily_fires gTotal nColl hlen _ _ _ G c a.val b.val hlt b.isLt ?_
    dsimp only; rw [ite_eq_left hb]; exact hfire
  · have htot : gTotal ≤ groups.length + 1 := by rw [hgTot]; split_ifs <;> omega
    have ha : a.val < groups.length := by have := b.isLt; have hlt' : a.val < b.val := hlt; omega
    have hsome : sumOpt.isSome = true := by
      cases hso : sumOpt with
      | none =>
        have hgtEq : gTotal = groups.length := by rw [hgTot, hso]; simp
        have hbLt := b.isLt
        have hf : False := by omega
        cases hf
      | some _ => rfl
    unfold expKey at heq; rw [ite_eq_left ha, ite_eq_right hb] at heq
    have hgMem : groups.getD a.val (0, ([], 0, 0)) ∈ groups := by
      rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem ha]; exact List.getElem_mem ha
    have hga := List.all_eq_true.mp hgrAll _ hgMem
    simp only [Bool.and_eq_true, hsome, Bool.not_true, Bool.false_or, decide_eq_true_eq] at hga
    have hlenEq := congrArg (fun k => k.1.length) heq
    simp only [evalSymGroup, List.length_map, List.length_nil] at hlenEq
    have hf : False := by have := hga.1; omega
    cases hf

end GenericAudit

/-! ## 2. Whole-Run Deterministic Witness & 28-Segment Transcript Program (`shdP_runPreBlk`, `shdP_runProg`) -/

section RunProgram

/-- Oracle-independent honest witness tables & slot data for a full 28-segment Shieldstral T128 R13 run
at input `x` and verdict `v := (classifySpecP Rp x).getD 0`. -/
structure ShdRunWitness {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ) where
  TB : ℕ → Coins → Table
  hrB : ∀ k, k ≤ 26 → ∀ c, (TB k c).rows.length ≤ 38
  incTA : Coins → Table
  incM : Coins → MTable
  incTH : Coins → List Fp2 → Table
  incSlot : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
    (incCtx (shdVi tag Rp embDigest bInRow).pub ch))
  hrIncA : ∀ c, (incTA c).rows.length ≤ 41
  hrIncH : ∀ c ch, (incTH c ch).rows.length ≤ 76
  blkTA : ℕ → Coins → Table
  blkM : ℕ → Coins → MTable
  blkTH : ℕ → Coins → Fp2 → Fp2 → Fp2 → Table
  blkSlot : (k : ℕ) → Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k)
  hrBlkA : ∀ k, k < 26 → ∀ c, (blkTA k c).rows.length ≤ 4577
  hrBlkH : ∀ k, k < 26 → ∀ c b g a, (blkTH k c b g a).rows.length ≤ 4390
  outcTA : Coins → Table
  outcM : Coins → MTable
  outcTH : Coins → List Fp2 → Table
  outcSlot : Coins → SlotData (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)).bp
  hrOutcA : ∀ c, (outcTA c).rows.length ≤ 76
  hrOutcH : ∀ c ch, (outcTH c ch).rows.length ≤ 38

noncomputable def ShdRunWitness.incTables {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (H : HIn → Dig) (c : Coins) : IncTables (shdVi tag Rp embDigest bInRow) where
  bRoot := rootOf H tag 16 (W.TB 0 c)
  TA := W.incTA c
  M := W.incM c
  TH := W.incTH c
  TE := shdP_epTable (Hdr := Hdr) tag x (epBase c)
  slot := W.incSlot c

def ShdRunWitness.blkTables {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (c : Coins) : ShdBlkTables (shdP_Pk0 tag ioIn ioOut checkOpening Rp) k where
  TB_prev := W.TB k c
  TB_next := W.TB (k + 1) c
  coreT := ⟨W.blkTA k c, W.blkM k c, W.blkTH k c, W.blkSlot k c⟩

def ShdRunWitness.outcTables {Hdr Coins : Type} {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {embDigest : Dig} {bInRow : ℕ} {wDigest : Dig} {bOutRow ioIn ioOut : ℕ}
    {checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit}
    {epBase : Coins → EpxSalt 6} {x : shieldS0.Tok → ℕ}
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) : OutcTables (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0)) where
  TA := W.outcTA c
  M := W.outcM c
  TH := W.outcTH c
  TB := W.TB 26 c
  slot := W.outcSlot c

/-! ### Stage & Block `Sep` + `SqLE` helpers -/

theorem shdP_incDraws_eq_run (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (s : ℕ) :
    incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s =
      match s with | 0 => 8 | 1 => 17 | 2 => 20 | _ => 0 := by
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  match s with
  | 0 => unfold incDraws; rw [hep, shdP_clog2_256]; rfl
  | 1 => unfold incDraws; rw [hti]; rfl
  | 2 => unfold incDraws; rw [hvoc]; rfl
  | _ + 3 => rfl

theorem shdP_incSlotShape_eq_run (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (bInRow : ℕ) (cx : IncCtx) (s : ℕ) :
    slotShape ((shdVi tag Rp embDigest bInRow).bp cx) s =
      match s with | 0 => (8, 1, 3) | 1 => (12, 1, 4) | 2 => (17, 1, 4) | 3 => (12, 1, 2) | _ => (0, 0, 0) := by
  have hgs' : ((shdVi tag Rp embDigest bInRow).bp cx).geom.slots = [(8, 1, 3), (12, 1, 4), (17, 1, 4), (12, 1, 2)] :=
    (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.2.2
  unfold slotShape; rw [hgs']; match s with | 0 | 1 | 2 | 3 | _ + 4 => rfl

theorem shdP_incSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 4) (c : Coins) :
    TProg.Sep key (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c)
      ∧ SqLE (mPre + 117) (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc i c) := by
  let V := shdVi tag Rp embDigest bInRow
  have hhd : incHeadDraws V.pub = 15 := (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
  refine ⟨sep_famPre _ _ _ key _ (sep_incHeadProg V key c (pre c) _ _ _ _ (hs c)) i,
    sqLE_mono _ ((mPre + 15) + 102) (mPre + 117)
      (sqLE_famPre (incPf V) (incDf V Dc) incBga _ i (mPre + 15) 102
        (by rw [← hhd]; exact sqLE_incHeadProg V c (pre c) _ _ _ _ mPre (hsq c)) (fun x => ?_)) (by omega)⟩
  have hd : ∀ s, (V.bp (incCtx V.pub x.2)).draws s = incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s := fun _ => rfl
  have hsn : ∀ s, slotN (incPf V x s) s = match s with | 0 => 9 | 1 => 13 | 2 => 18 | 3 => 13 | _ => 0 := fun s => by
    unfold slotN; change (slotShape (V.bp (incCtx V.pub x.2)) s).1 + (slotShape (V.bp (incCtx V.pub x.2)) s).2.1 = _
    rw [shdP_incSlotShape_eq_run]; match s with | 0 | 1 | 2 | 3 | _ + 4 => rfl
  have h4 : famSqBound (incPf V x) 4 0 = 102 := by simp only [famSqBound, hd, hsn, shdP_incDraws_eq_run]
  exact (famSqBound_mono _ hi).trans h4.le

theorem shdP_incOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 41) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 76)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 444) (incOpenHProg tag Rp embDigest bInRow pre TB TA M TH Dc c) := by
  have hS := shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq 4 le_rfl c
  have hM : TProg.Sep key (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 192) (incMaskProg tag Rp embDigest bInRow pre TB TA M TH Dc c) :=
    ⟨sep_bMaskProg key 4 _ _ _ hS.1,
     sqLE_mono _ _ (mPre + 192) (sqLE_bMaskProg 4 (mPre + 117) _ _ _ hS.2) (by norm_num [mQ])⟩
  have hA : TProg.Sep key (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c)
      ∧ SqLE (mPre + 300) (incOpenAProg tag Rp embDigest bInRow pre TB TA M TH Dc c) :=
    ⟨sep_bOpenProg key _ 3 _ _ _ hM.1,
     sqLE_mono _ _ (mPre + 300) (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 3 41 (mPre + 192) _ _ _ hM.2 (fun y => hrA y.1.1.1)) (by dsimp only; omega)⟩
  exact ⟨sep_bOpenProg key _ 4 _ _ _ hA.1,
    sqLE_mono _ _ (mPre + 444) (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 4 76 (mPre + 300) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 y.1.1.1.2)) (by dsimp only; omega)⟩

theorem shdP_blkSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 23) (c : Coins) :
    TProg.Sep key (blkSlotEndProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc i c)
      ∧ SqLE (mPre + 847) (blkSlotEndProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc i c) := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  have hDraws : P.draws = Exec.Block.R13.shieldDraws := shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk
  have hSlots : P.geom.slots = Exec.Block.R13.shieldSlots := shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk
  refine ⟨sep_famPre _ _ _ key _ (sep_coreHeadProg P key c _ _ _ _ (sep_blkFrameProg key k dig (pre c) _ (hs c))) i,
    sqLE_mono _ ((mPre + 3) + 844) (mPre + 847)
      (sqLE_famPre (corePf P) (coreDf P Dc) coreBga _ i (mPre + 3) 844
        (sqLE_coreHeadProg P c _ _ _ _ mPre (sqLE_blkFrameProg k dig mPre (pre c) _ (hsq c))) (fun x => ?_)) (by omega)⟩
  have h23 : famSqBound (corePf P x) 23 0 = 844 := by simp only [famSqBound, corePf, slotN, slotShape, hDraws, hSlots]; decide
  exact (famSqBound_mono _ hi).trans h23.le

theorem shdP_blkOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (dig : Dig)
    (mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TB_next TA : Coins → Table) (M : Coins → MTable) (TH : Coins → Fp2 → Fp2 → Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 4577) (hrH : ∀ c b g a, (TH c b g a).rows.length ≤ 4390)
    (Dc : Coins → SlotData (shdP_Pk0 tag ioIn ioOut checkOpening Rp k))
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (blkOpenHProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 10255) (blkOpenHProg tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) k dig pre TB_next TA M TH Dc c) := by
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  have hS := shdP_blkSlotEndProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk dig mPre key pre TB_next TA M TH Dc hs hsq 23 le_rfl c
  have hM : TProg.Sep key (blkMaskProg tag P k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 960) (blkMaskProg tag P k dig pre TB_next TA M TH Dc c) :=
    ⟨sep_bMaskProg key 23 _ _ _ hS.1,
     sqLE_mono _ _ (mPre + 960) (sqLE_bMaskProg 23 (mPre + 847) _ _ _ hS.2) (by norm_num [mQ])⟩
  have hA : TProg.Sep key (blkOpenAProg tag P k dig pre TB_next TA M TH Dc c)
      ∧ SqLE (mPre + 5747) (blkOpenAProg tag P k dig pre TB_next TA M TH Dc c) :=
    ⟨sep_bOpenProg key _ 146 _ _ _ hM.1,
     sqLE_mono _ _ (mPre + 5747)
       (sqLE_bOpenProg Exec.R13.r13Prm 146 4577 (mPre + 960) _ _ _ hM.2 (fun y => hrA y.1.1.1)) (by norm_num [Exec.R13.r13Prm])⟩
  exact ⟨sep_bOpenProg key _ 54 _ _ _ hA.1,
    sqLE_mono _ _ (mPre + 10255)
      (sqLE_bOpenProg Exec.R13.r13Prm 54 4390 (mPre + 5747) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 _ _ _)) (by norm_num [Exec.R13.r13Prm])⟩

theorem shdP_outcDraws_eq_run (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (v s : ℕ) :
    outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s =
      match s with | 0 => 12 | 2 => 7 | 4 => 15 | 5 => 23 | 6 => 15 | _ => 0 := by
  rw [rc_outcDraws_verdict]
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  match s with
  | 0 => exact hdb | 1 => rfl | 2 => rfl | 3 => rfl
  | 4 => unfold outcDraws; rw [hllo]; rfl | 5 => unfold outcDraws; rw [hldo]; rfl | 6 => unfold outcDraws; rw [hltab]; rfl | _ + 7 => rfl

theorem shdP_outcSlotShape_eq_run (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig)
    (bOutRow v s : ℕ) :
    slotShape (shdVo tag Rp wDigest bOutRow v).bp s =
      match s with
      | 0 => (12, 1, 2) | 1 => (12, 1, 4) | 2 => (1, 1, 3) | 3 => (12, 1, 2)
      | 4 => (12, 1, 4) | 5 => (12, 1, 5) | 6 => (12, 1, 3) | 7 => (12, 1, 2) | _ => (0, 0, 0) := by
  have hgs' : (shdVo tag Rp wDigest bOutRow v).bp.geom.slots =
      [(12, 1, 2), (12, 1, 4), (1, 1, 3), (12, 1, 2), (12, 1, 4), (12, 1, 5), (12, 1, 3), (12, 1, 2)] := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).geomSlots = _
    rw [rc_outcLay_verdict]; exact (shdP_outcLay_nums Rp wDigest).2.2.2
  unfold slotShape; rw [hgs']; match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | _ + 8 => rfl

theorem shdP_outcSlotEndProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (i : ℕ) (hi : i ≤ 8) (c : Coins) :
    TProg.Sep key (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c)
      ∧ SqLE (mPre + 175) (outcSlotEndProg tag Rp wDigest bOutRow v pre TA M TH Dc i c) := by
  let V := shdVo tag Rp wDigest bOutRow v
  refine ⟨sep_famPre _ _ _ key _ (sep_outcHeadProg V key c (pre c) _ _ _ (hs c)) i,
    sqLE_mono _ ((mPre + 2) + 173) (mPre + 175)
      (sqLE_famPre (outcPf V) (outcDf V Dc) outcBga _ i (mPre + 2) 173
        (sqLE_outcHeadProg V c (pre c) _ _ _ mPre (hsq c)) (fun x => ?_)) (by omega)⟩
  have hd : ∀ s, (outcPf V x s).draws s = outcDraws (rcVerdict (shdP_outcPub Rp wDigest) v) s := fun _ => rfl
  have hsn : ∀ s, slotN (outcPf V x s) s =
      match s with | 0 => 13 | 1 => 13 | 2 => 2 | 3 => 13 | 4 => 13 | 5 => 13 | 6 => 13 | 7 => 13 | _ => 0 := fun s => by
    unfold slotN; change (slotShape V.bp s).1 + (slotShape V.bp s).2.1 = _
    rw [shdP_outcSlotShape_eq_run]; match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | _ + 8 => rfl
  have h8 : famSqBound (outcPf V x) 8 0 = 173 := by simp only [famSqBound, hd, hsn, shdP_outcDraws_eq_run]
  exact (famSqBound_mono _ hi).trans h8.le

theorem shdP_outcOpenHProg_sep_sq {α Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (wDigest : Dig) (bOutRow v mPre : ℕ) (key : Option Dig) (pre : Coins → TProg α)
    (TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (hrA : ∀ c, (TA c).rows.length ≤ 76) (hrH : ∀ c ch, (TH c ch).rows.length ≤ 38)
    (Dc : Coins → SlotData (shdVo tag Rp wDigest bOutRow v).bp)
    (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c)) (c : Coins) :
    TProg.Sep key (outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 539) (outcOpenHProg tag Rp wDigest bOutRow v pre TA M TH Dc c) := by
  have hS := shdP_outcSlotEndProg_sep_sq tag Rp wDigest bOutRow v mPre key pre TA M TH Dc hs hsq 8 le_rfl c
  have hM : TProg.Sep key (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 258) (outcMaskProg tag Rp wDigest bOutRow v pre TA M TH Dc c) :=
    ⟨sep_bMaskProg key 8 _ _ _ hS.1,
     sqLE_mono _ _ (mPre + 258) (sqLE_bMaskProg 8 (mPre + 175) _ _ _ hS.2) (by norm_num [mQ])⟩
  have hA : TProg.Sep key (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c)
      ∧ SqLE (mPre + 427) (outcOpenAProg tag Rp wDigest bOutRow v pre TA M TH Dc c) :=
    ⟨sep_bOpenProg key _ 29 _ _ _ hM.1,
     sqLE_mono _ _ (mPre + 427) (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 29 76 (mPre + 258) _ _ _ hM.2 (fun y => hrA y.1.1.1)) (by dsimp only; omega)⟩
  exact ⟨sep_bOpenProg key _ 10 _ _ _ hA.1,
    sqLE_mono _ _ (mPre + 539) (sqLE_bOpenProg ⟨12, 4, 256, 256⟩ 10 38 (mPre + 427) _ _ _ hA.2 (fun y => hrH y.1.1.1.1 y.1.1.1.2)) (by dsimp only; omega)⟩

/-! ### Whole-run deterministic program chain (`0 → 515 → 515 + k * 10359 → 270492`) -/

private theorem sep_sqLE_bindP {α β : Type} (key : Option Dig) (m₁ m₂ mOut : ℕ)
    (p : TProg α) (f : α → TProg β)
    (hp : TProg.Sep key p ∧ SqLE m₁ p)
    (hf : ∀ a, TProg.Sep key (f a) ∧ SqLE m₂ (f a))
    (hle : m₁ + m₂ ≤ mOut) :
    TProg.Sep key (bindP p f) ∧ SqLE mOut (bindP p f) :=
  ⟨sep_bindP key p f hp.1 (fun a => (hf a).1),
   sqLE_mono (bindP p f) (m₁ + m₂) mOut (sqLE_bindP p f m₁ m₂ hp.2 (fun a => (hf a).2)) hle⟩

private theorem sep_sqLE_bOpen_done {α β : Type} (key : Option Dig) (prm : PcsPrm)
    (maxCl maxRows mP mOut : ℕ) (T : α → Table) (cl : α → List Exec.Block.ZClaim)
    (f : α × List (List Fp2) × List Dig → β) (p : TProg α)
    (hp : TProg.Sep key p ∧ SqLE mP p)
    (hrows : ∀ a, (T a).rows.length ≤ maxRows)
    (hle : mP + (maxCl + maxRows + (prm.nQ + 3) / 4) ≤ mOut) :
    TProg.Sep key (bindP (bOpenProg prm maxCl T cl p) (fun z => TProg.done (f z)))
      ∧ SqLE mOut (bindP (bOpenProg prm maxCl T cl p) (fun z => TProg.done (f z))) := by
  refine ⟨sep_bindP key _ _ (sep_bOpenProg key prm maxCl T cl p hp.1) (fun _ => trivial), ?_⟩
  have hB : SqLE mOut (bOpenProg prm maxCl T cl p) :=
    sqLE_mono _ _ mOut (sqLE_bOpenProg prm maxCl maxRows mP T cl p hp.2 hrows) hle
  exact sqLE_mono _ (mOut + 0) mOut (sqLE_bindP _ _ mOut 0 hB (fun _ => trivial)) (by omega)

noncomputable def shdP_incEndProg {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) : TProg (List Exec.Block.ZClaim) :=
  let preHdr := fun c' => shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c')
  let pH := incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c
  let pE := bOpenProg ⟨8, 8, 256, 256⟩ 1 (fun _ => shdP_epTable (Hdr := Hdr) tag x (epBase c))
    (fun y => y.1.1.1.2.2.claims.inp) pH
  bindP pE (fun z => TProg.done z.1.1.1.1.2.2.claims.out)

private theorem shdP_incEndProg_sep_sq_aux {Hdr Coins : Type} (tag : MTag) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (preHdr : Coins → TProg Unit)
    (hsPre : ∀ c', TProg.Sep key (preHdr c')) (hsqPre : ∀ c', SqLE 0 (preHdr c')) (c : Coins) :
    let pH := incOpenHProg tag Rp embDigest bInRow preHdr (W.TB 0) W.incTA W.incM W.incTH W.incSlot c
    let pE := bOpenProg ⟨8, 8, 256, 256⟩ 1 (fun _ => shdP_epTable (Hdr := Hdr) tag x (epBase c))
      (fun y => y.1.1.1.2.2.claims.inp) pH
    TProg.Sep key (bindP pE (fun z => TProg.done z.1.1.1.1.2.2.claims.out))
      ∧ SqLE 515 (bindP pE (fun z => TProg.done z.1.1.1.1.2.2.claims.out)) := by
  intro pH pE
  have hH : TProg.Sep key pH ∧ SqLE (0 + 444) pH :=
    shdP_incOpenHProg_sep_sq tag Rp embDigest bInRow 0 key preHdr
      (W.TB 0) W.incTA W.incM W.incTH W.hrIncA W.hrIncH W.incSlot hsPre hsqPre c
  dsimp only [pE]
  exact sep_sqLE_bOpen_done key ⟨8, 8, 256, 256⟩ 1 6 (0 + 444) 515 _ _ _ pH hH
    (fun _ => (shdP_epTable_rows_length (Hdr := Hdr) tag x (epBase c)).le) (by decide)

theorem shdP_incEndProg_sep_sq {Hdr Coins : Type} (tag : MTag) (key : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) :
    TProg.Sep key (shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c)
      ∧ SqLE 515 (shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c) := by
  unfold shdP_incEndProg
  exact shdP_incEndProg_sep_sq_aux tag key Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W
    (fun c' => shdP_hdrProg tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c'))
    (fun c' => @sep_shdP_hdrProg Hdr tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c') key)
    (fun c' => @sqLE_shdP_hdrProg Hdr tag hw hdr ((classifySpecP Rp x).getD 0) x (epBase c')) c

noncomputable def shdP_blkBodyProg {Hdr Coins : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (c : Coins) (pend : List Exec.Block.ZClaim) : TProg (List Exec.Block.ZClaim) :=
  let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
  let pH := blkOpenHProg tag P k (blkDig k) (fun _ : Coins => TProg.done ())
    (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k) (W.blkSlot k) c
  let pB := bOpenProg Exec.R13.r13Prm 2 (fun _ => W.TB k c) (fun y => pend ++ y.1.1.1.2.2.claims.inp) pH
  bindP pB (fun z => TProg.done z.1.1.1.1.2.2.claims.out)

theorem shdP_blkBodyProg_sep_sq {Hdr Coins : Type} (tag : MTag) (key : Option Dig)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (k : ℕ) (hk : k < 26) (c : Coins) (pend : List Exec.Block.ZClaim) :
    TProg.Sep key (shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend)
      ∧ SqLE 10359 (shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend) := by
  unfold shdP_blkBodyProg; dsimp only
  have hH := shdP_blkOpenHProg_sep_sq tag ioIn ioOut checkOpening Rp hR k hk (blkDig k) 0 key
    (fun _ : Coins => TProg.done ()) (W.TB (k + 1)) (W.blkTA k) (W.blkM k) (W.blkTH k)
    (W.hrBlkA k hk) (W.hrBlkH k hk) (W.blkSlot k) (fun _ => trivial) (fun _ => trivial) c
  exact sep_sqLE_bOpen_done key Exec.R13.r13Prm 2 38 (0 + 10255) 10359 _ _ _ _ hH
    (fun _ => W.hrB k (by omega) c) (by decide)

/-- **Pre-Block `k` deterministic transcript program** (`k = 0` = after IN-C; `k = 26` = before OUT-C),
returning the carried pending boundary claims `cr.pending`. Defined by recursion on `k : ℕ` (never unrolled). -/
noncomputable def shdP_runPreBlk {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) :
    ℕ → Coins → TProg (List Exec.Block.ZClaim)
  | 0, c => shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c
  | k + 1, c =>
    if k < 26 then
      bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
        (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend)
    else shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c

private theorem shdP_runPreBlk_sep_sq {Hdr Coins : Type} (tag : MTag) (key : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) :
    ∀ k c,
      TProg.Sep key (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
      ∧ SqLE (515 + min k 26 * 10359)
          (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) := by
  intro k
  induction k with
  | zero =>
    intro c
    rw [show shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W 0 c
          = shdP_incEndProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c from rfl,
        show 515 + min 0 26 * 10359 = 515 from rfl]
    exact shdP_incEndProg_sep_sq tag key hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x W c
  | succ k ih =>
    intro c
    by_cases hk : k < 26
    · have heq : shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W (k + 1) c
          = bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
              (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend) := by
        change (if k < 26 then
            bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
              (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend)
          else shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) = _
        rw [ite_eq_left hk]
      rw [heq]
      exact sep_sqLE_bindP key (515 + min k 26 * 10359) 10359 (515 + min (k + 1) 26 * 10359) _ _
        (ih c)
        (fun pend => shdP_blkBodyProg_sep_sq tag key Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k hk c pend)
        (by omega)
    · have heq : shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W (k + 1) c
          = shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c := by
        change (if k < 26 then
            bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c)
              (fun pend => shdP_blkBodyProg tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c pend)
          else shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) = _
        rw [ite_eq_right hk]
      rw [heq, show min (k + 1) 26 = min k 26 by omega]
      exact ih c

theorem shdP_runPreBlk_sep {Hdr Coins : Type} (tag : MTag) (key : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) :
    ∀ k c, TProg.Sep key
      (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) :=
  fun k c => (shdP_runPreBlk_sep_sq tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c).1

theorem shdP_runPreBlk_sqLE {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x) :
    ∀ k, k ≤ 26 → ∀ c, SqLE (515 + k * 10359)
      (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c) := by
  intro k hk c
  have h := shdP_runPreBlk_sep_sq tag none hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W k c
  rw [Nat.min_eq_left hk] at h
  exact h.2

/-- Full 28-segment Shieldstral T128 R13 deterministic transcript program (`SqLE 270492`). -/
noncomputable def shdP_runProg {Hdr Coins : Type} (tag : MTag) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) : TProg Unit :=
  let v := (classifySpecP Rp x).getD 0
  bindP (shdP_runPreBlk tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W 26 c)
    (fun pend =>
      let pH := outcOpenHProg tag Rp wDigest bOutRow v (fun _ : Coins => TProg.done ()) W.outcTA W.outcM W.outcTH W.outcSlot c
      let pB := bOpenProg Exec.R13.r13Prm 2 (fun _ => W.TB 26 c) (fun y => pend ++ y.1.1.1.2.2.claims.inp) pH
      bindP pB (fun _ => TProg.done ()))

theorem shdP_runProg_sep_sq {Hdr Coins : Type} (tag : MTag) (key : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (blkDig : ℕ → Dig) (epBase : Coins → EpxSalt 6) (x : shieldS0.Tok → ℕ)
    (W : ShdRunWitness (Hdr := Hdr) tag Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening epBase x)
    (c : Coins) :
    TProg.Sep key (shdP_runProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W c)
      ∧ SqLE 270492 (shdP_runProg tag hw hdr Rp embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W c) := by
  unfold shdP_runProg; dsimp only
  have h26 := shdP_runPreBlk_sep_sq tag key hw hdr Rp hR embDigest bInRow wDigest bOutRow ioIn ioOut checkOpening blkDig epBase x W 26 c
  have hH := shdP_outcOpenHProg_sep_sq tag Rp wDigest bOutRow ((classifySpecP Rp x).getD 0) 0 key
    (fun _ : Coins => TProg.done ()) W.outcTA W.outcM W.outcTH W.hrOutcA W.hrOutcH W.outcSlot
    (fun _ => trivial) (fun _ => trivial) c
  exact sep_sqLE_bindP key (515 + min 26 26 * 10359) (539 + 104) 270492 _ _ h26
    (fun _ => sep_sqLE_bOpen_done key Exec.R13.r13Prm 2 38 (0 + 539) (539 + 104) _ _ _ _ hH
      (fun _ => W.hrB 26 le_rfl c) (by decide))
    (by decide)

end RunProgram

/-! ## 3. Stage IN-C `OpenCollFamily` & `OpenAuditOk` + Output Carry (`B_0`) -/

section StageInAudit

private def incPrivsA : List (ℕ × PrivS) :=
  [(0, ⟨.a, [(0, false)], 12, (List.replicate 4 (CoordS.fixed .zero)) ++ Exec.Block.DefW16.rhoC 0 8, 33, 0⟩),
   (1, ⟨.a, [(0, false)], 12, Exec.Block.DefW16.rhoC 0 12, 35, 0⟩),
   (2, ⟨.a, [(4096, false)], 17, Exec.Block.DefW16.rhoC 0 17, 37, 0⟩)]

private def incPrivsH : List (ℕ × PrivS) :=
  [(1, ⟨.h, [(0, false), (4096, true)], 12, Exec.Block.DefW16.rhoC 0 12, 68, 0⟩),
   (2, ⟨.h, [(8192, false), (139264, true)], 17, Exec.Block.DefW16.rhoC 0 17, 70, 0⟩),
   (3, ⟨.h, [(270336, false), (274432, true)], 12, Exec.Block.DefW16.rhoC 0 12, 72, 0⟩)]

private def incGroupsA : List SymGroup :=
  dedupSymGroupsOrder (incPrivsA.filterMap (fun sp => (privSymKey 12 sp.2).map (fun k => (sp.1, k))))

private def incGroupsH : List SymGroup :=
  dedupSymGroupsOrder (incPrivsH.filterMap (fun sp => (privSymKey 12 sp.2).map (fun k => (sp.1, k))))

private def incMains : ℕ → ℕ | 0 => 8 | 1 => 12 | 2 => 17 | 3 => 12 | _ => 0
private def incExts : ℕ → ℕ | 0 => 1 | 1 => 1 | 2 => 1 | 3 => 1 | _ => 0
private def incDrawsF : ℕ → ℕ | 0 => 8 | 1 => 17 | 2 => 20 | _ => 0

private theorem incSpecA_ok :
    incGroupsA.length = 3
      ∧ checkSymSpec 4 12 33 39 3 false incMains incExts incDrawsF incPrivsA incGroupsA = true := by
  decide +kernel

private theorem incSpecH_ok :
    incGroupsH.length = 3
      ∧ checkSymSpec 4 12 68 74 3 true incMains incExts incDrawsF incPrivsH incGroupsH = true := by
  decide +kernel

private theorem shdP_incLay_audit_nums (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (embFold : List Fp2 → List Fp2) :
    let L := incLay (shdP_incPub Rp embDigest embFold) 14
    L.aRows = 41 ∧ L.aProx = 39 ∧ L.aSiteRows = List.range' 33 6
      ∧ L.hRows = 76 ∧ L.hProx = 74 ∧ L.hSiteRows = List.range' 68 6 ∧ L.hURows = (66, 67)
      ∧ L.aOff incA_TOK = 0 ∧ L.aOff incA_MULT = 4096
      ∧ L.hOff incH_Q = (0, 4096) ∧ L.hOff incH_TAB = (8192, 139264) ∧ L.hOff incH_U = (270336, 274432)
      ∧ L.aMaskBase = 33 ∧ L.hMaskBase = 68
      ∧ L.logupSumClaim.parts =
          [⟨0, 12, kI 1, []⟩, ⟨4096, 12, (kI 1).mul fp2U, []⟩,
           ⟨8192, 17, kI (-1), []⟩, ⟨139264, 17, (kI (-1)).mul fp2U, []⟩,
           ⟨66 * 2 ^ 12, 12, Fp2.one, []⟩, ⟨67 * 2 ^ 12, 12, Fp2.one.mul fp2U, []⟩] := by
  intro L
  obtain ⟨hti, hvoc, -, -, -⟩ := shdP_incPub_logs Rp embDigest embFold
  have hlt : (shdP_incPub Rp embDigest embFold).lt = 12 := rfl
  have hlogN : L.logN = 12 := rfl
  have hk1 : kI 1 = Fp2.one := by decide
  have haL : L.aLog = [12, 17] := by change [(shdP_incPub Rp embDigest embFold).tiLog, (shdP_incPub Rp embDigest embFold).vocLog] = _; rw [hti, hvoc]
  have hhL : L.hLog = [12, 17, 12] := by change [(shdP_incPub Rp embDigest embFold).tiLog, (shdP_incPub Rp embDigest embFold).vocLog, (shdP_incPub Rp embDigest embFold).lt] = _; rw [hti, hvoc, hlt]
  have haRL : L.aRowsL = [1, 32] := by unfold Lay.aRowsL; rw [haL, hlogN]; decide
  have hhRL : L.hRowsL = [1, 32, 1] := by unfold Lay.hRowsL; rw [hhL, hlogN]; decide
  have haMb : L.aMaskBase = 33 := by unfold Lay.aMaskBase Lay.aDataRows; rw [haRL]; rfl
  have hhMb : L.hMaskBase = 68 := by unfold Lay.hMaskBase Lay.hDataRows; rw [hhRL]; rfl
  have haPr : L.aProx = 39 := by unfold Lay.aProx; rw [haMb]; rfl
  have hhPr : L.hProx = 74 := by unfold Lay.hProx; rw [hhMb]; rfl
  have haO0 : L.aOff incA_TOK = 0 := by unfold Lay.aOff Lay.n; rw [haRL]; rfl
  have haO1 : L.aOff incA_MULT = 4096 := by unfold Lay.aOff Lay.n; rw [haRL]; rfl
  have hhO0 : L.hOff incH_Q = (0, 4096) := by unfold Lay.hOff Lay.n; rw [hhRL]; rfl
  have hhO1 : L.hOff incH_TAB = (8192, 139264) := by unfold Lay.hOff Lay.n; rw [hhRL]; rfl
  have hhO2 : L.hOff incH_U = (270336, 274432) := by unfold Lay.hOff Lay.n; rw [hhRL]; rfl
  refine ⟨by unfold Lay.aRows; rw [haPr], haPr, by unfold Lay.aSiteRows; rw [haMb, haPr],
    by unfold Lay.hRows; rw [hhPr], hhPr, by unfold Lay.hSiteRows; rw [hhMb, hhPr],
    by unfold Lay.hURows Lay.n; rw [show L.hU = incH_U from rfl, hhO2, hlogN]; decide,
    haO0, haO1, hhO0, hhO1, hhO2, haMb, hhMb, ?_⟩
  unfold Lay.logupSumClaim
  have hlen3 : L.hLog.length = 3 := by rw [hhL]; rfl
  rw [hlen3, show List.range 3 = [0, 1, 2] from rfl, List.flatMap_cons, List.flatMap_cons, List.flatMap_cons,
    List.flatMap_nil, List.append_nil, List.cons_append, List.cons_append, List.nil_append]
  rw [show L.hOff 0 = (0, 4096) from hhO0, show L.hOff 1 = (8192, 139264) from hhO1,
    show L.hOff 2 = (270336, 274432) from hhO2, hhL]
  have hs0 : L.hSign.getD 0 0 = 1 := rfl
  have hs1 : L.hSign.getD 1 0 = -1 := rfl
  have hs2 : L.hSign.getD 2 0 = 1 := rfl
  rw [hs0, hs1, hs2, hk1]; rfl

private theorem shdP_incDefine_privs (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (cx : IncCtx) (s : ℕ) (hs : s < 4) (hist : Hist) (dr : List Fp2) (df : SlotDef)
    (hlen : dr.length = incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s)
    (hcan : ∀ a ∈ dr, a.Canon)
    (hdef : incDefine (shdP_incPub Rp embDigest (embFoldL Rp.inp)) (shdP_incGeo bInRow) cx s hist dr = .ok df)
    (ev : Sym → Fp2) (hev0 : ev .zero = Fp2.zero) :
    privsCm .a df.tabs = (incPrivsA.filter (fun q => decide (q.1 = s))).map (fun q => q.2.eval ev)
      ∧ privsCm .h df.tabs = (incPrivsH.filter (fun q => decide (q.1 = s))).map (fun q => q.2.eval ev)
      ∧ privsCm .inp df.tabs = (if s = 0 then [⟨.inp, [(0, Fp2.one)], 8, StageV.rhoC 0 8, 1, 0⟩] else [])
      ∧ privsCm .out df.tabs = (if s = 1 then [⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC cx.rEmb, bInRow, 0⟩] else []) := by
  let I := shdP_incPub Rp embDigest (embFoldL Rp.inp); let G := shdP_incGeo bInRow; let L := incLay I 14
  obtain ⟨hti, hvoc, hep, -, -⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
  have hti' : I.tiLog = 12 := hti
  have hvoc' : I.vocLog = 17 := hvoc
  have hep' : I.inEpWords = 256 := hep
  have hepc : clog2 I.inEpWords = 8 := by rw [hep', shdP_clog2_256]
  have htbits : I.tBits = 7 := shdP_clog2_128
  have hbin : I.bInLog = 19 := by show Nat.log2 (128 * 4096) = 19; exact (Nat.log2_eq_iff (by norm_num)).mpr ⟨by norm_num, by norm_num⟩
  obtain ⟨-, -, -, -, -, -, -, haO0, haO1, hhO0, hhO1, hhO2, haMb, hhMb, -⟩ :=
    shdP_incLay_audit_nums Rp embDigest (embFoldL Rp.inp)
  have haO0' : L.aOff incA_TOK = 0 := haO0
  have haO1' : L.aOff incA_MULT = 4096 := haO1
  have hhO0' : L.hOff incH_Q = (0, 4096) := hhO0
  have hhO1' : L.hOff incH_TAB = (8192, 139264) := hhO1
  have hhO2' : L.hOff incH_U = (270336, 274432) := hhO2
  have haMb' : L.aMaskBase = 33 := haMb
  have hhMb' : L.hMaskBase = 68 := hhMb
  have h123 : s = 0 ∨ s = 1 ∨ s = 2 ∨ s = 3 := by omega
  rcases h123 with rfl | rfl | rfl | rfl
  · change incDefIO I G dr = .ok df at hdef; rw [incDefIO_ok I G dr] at hdef; cases hdef
    have hlog0 : L.aLog.getD incA_TOK 0 = 12 := hti
    have hpa0 : L.prefixA 0 = 0 := rfl
    refine ⟨?_, rfl, ?_, rfl⟩
    · change ([⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
          fixedC (List.replicate (I.tiLog - clog2 I.inEpWords) Fp2.zero) ++ StageV.rhoC 0 (clog2 I.inEpWords),
          L.aMaskBase + 2 * (L.prefixA 0 + 0), 0⟩] : List Priv) =
        ([⟨.a, [(0, Fp2.one)], 12,
          ((List.replicate 4 (CoordS.fixed .zero)) ++ Exec.Block.DefW16.rhoC 0 8).map (CoordS.eval ev), 33, 0⟩] : List Priv)
      rw [haO0', haMb', hlog0, hpa0, hti', hepc]
      change ([⟨.a, [(0, Fp2.one)], 12,
          [Exec.Block.Coord.fixed Fp2.zero, Exec.Block.Coord.fixed Fp2.zero,
           Exec.Block.Coord.fixed Fp2.zero, Exec.Block.Coord.fixed Fp2.zero] ++ StageV.rhoC 0 8, 33, 0⟩] : List Priv) =
        ([⟨.a, [(0, Fp2.one)], 12,
          [Exec.Block.Coord.fixed (ev .zero), Exec.Block.Coord.fixed (ev .zero),
           Exec.Block.Coord.fixed (ev .zero), Exec.Block.Coord.fixed (ev .zero)] ++ StageV.rhoC 0 8, 33, 0⟩] : List Priv)
      rw [hev0]
    · change ([⟨.inp, [(0, Fp2.one)], clog2 I.inEpWords, StageV.rhoC 0 (clog2 I.inEpWords), 1, 0⟩] : List Priv) = _
      rw [hepc]; rfl
  · change incDefQZC I G cx dr = .ok df at hdef; rw [shdP_incDraws_eq_run] at hlen
    let y : Fin 17 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 17 hlen
    have hne : ∀ j ∈ Z_range 17 I.tiLog 5, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := incDefQZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := incDefQZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hlogA : L.aLog.getD incA_TOK 0 = 12 := hti
    have hlogH : L.hLog.getD incH_Q 0 = 12 := hti
    have hpa1 : L.prefixA 1 = 1 := rfl
    have hph1 : L.prefixH 1 = 0 := rfl
    refine ⟨?_, ?_, rfl, ?_⟩
    · change ([⟨.a, [(L.aOff incA_TOK, Fp2.one)], L.aLog.getD incA_TOK 0,
          StageV.rhoC 0 (L.aLog.getD incA_TOK 0), L.aMaskBase + 2 * (L.prefixA 1 + 0), 0⟩] : List Priv) = _
      rw [haO0', haMb', hlogA, hpa1]; rfl
    · change ([⟨.h, [((L.hOff incH_Q).1, Fp2.one), ((L.hOff incH_Q).2, fp2U)],
          L.hLog.getD incH_Q 0, StageV.rhoC 0 (L.hLog.getD incH_Q 0), L.hMaskBase + 2 * (L.prefixH 1 + 0), 0⟩] : List Priv) = _
      rw [hhO0', hhMb', hlogH, hph1]; rfl
    · change ([⟨.out, [(0, Fp2.one)], I.bInLog, StageV.rhoC (I.tiLog - I.tBits) I.tiLog ++ fixedC cx.rEmb, bInRow, 0⟩] : List Priv) = _
      rw [hbin, hti', htbits]; rfl
  · change incDefTZC I G cx dr = .ok df at hdef; rw [shdP_incDraws_eq_run] at hlen
    let y : Fin 20 → shdP_K := fun j => (dr.getD j.val Fp2.zero).toK shdP_U
    have hw : stgWords shdP_U shdP_hbij y = dr := stgWords_toK shdP_U shdP_hbij shdP_hU dr hcan 20 hlen
    have hne : ∀ j ∈ Z_range 20 I.vocLog 3, y j ≠ 0 := fun j hj hy0 => by
      obtain ⟨_, hm⟩ := incDefTZC_err shdP_U shdP_hbij shdP_hU I G cx y ⟨j, hj, hy0⟩; rw [hw] at hm; rw [hm] at hdef; cases hdef
    have hok := incDefTZC_ok shdP_U shdP_hbij shdP_hU I G cx (by omega) y hne
    rw [hw] at hok; rw [hok] at hdef; cases hdef
    have hlogA : L.aLog.getD incA_MULT 0 = 17 := hvoc
    have hlogH : L.hLog.getD incH_TAB 0 = 17 := hvoc
    have hpa2 : L.prefixA 2 = 2 := rfl
    have hph2 : L.prefixH 2 = 1 := rfl
    refine ⟨?_, ?_, rfl, rfl⟩
    · change ([⟨.a, [(L.aOff incA_MULT, Fp2.one)], L.aLog.getD incA_MULT 0,
          StageV.rhoC 0 (L.aLog.getD incA_MULT 0), L.aMaskBase + 2 * (L.prefixA 2 + 0), 0⟩] : List Priv) = _
      rw [haO1', haMb', hlogA, hpa2]; rfl
    · change ([⟨.h, [((L.hOff incH_TAB).1, Fp2.one), ((L.hOff incH_TAB).2, fp2U)],
          L.hLog.getD incH_TAB 0, StageV.rhoC 0 (L.hLog.getD incH_TAB 0), L.hMaskBase + 2 * (L.prefixH 2 + 0), 0⟩] : List Priv) = _
      rw [hhO1', hhMb', hlogH, hph2]; rfl
  · change incDefZS I G = .ok df at hdef; rw [incDefZS_ok I G] at hdef; cases hdef
    have hlogH : L.hLog.getD incH_U 0 = 12 := rfl
    have hph3 : L.prefixH 3 = 2 := rfl
    refine ⟨rfl, ?_, rfl, rfl⟩
    change ([⟨.h, [((L.hOff incH_U).1, Fp2.one), ((L.hOff incH_U).2, fp2U)],
        L.hLog.getD incH_U 0, StageV.rhoC 0 (L.hLog.getD incH_U 0), L.hMaskBase + 2 * (L.prefixH 3 + 0), 0⟩] : List Priv) = _
    rw [hhO2', hhMb', hlogH, hph3]; rfl

noncomputable def shdP_incCollA {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) : OpenCollFamily Lq Coins 3 :=
  let V := shdVi tag Rp embDigest bInRow
  symCollFamily Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga
    (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc) 4 (mPre + 117) 20 20
    incMains incDrawsF incGroupsA 3 3 rfl
    (fun s hsLt c => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (fun s hsLt _ => by change incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s ≤ 20; rw [shdP_incDraws_eq_run]; interval_cases s <;> norm_num) (by omega)

noncomputable def shdP_incCollH {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch))) : OpenCollFamily Lq Coins 6 :=
  let V := shdVi tag Rp embDigest bInRow
  symCollFamily Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga
    (incSlotEndProg tag Rp embDigest bInRow pre TB TA M TH Dc) 4 (mPre + 117) 20 20
    incMains incDrawsF incGroupsH 4 6 rfl
    (fun s hsLt c => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).1)
    (fun s hsLt c => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c).2)
    (fun s hsLt _ => by change incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s ≤ 20; rw [shdP_incDraws_eq_run]; interval_cases s <;> norm_num) (by omega)

/-- **Stage IN-C `A`, `H` `OpenAuditOk` + `B_0` carry & `inp` length discharge**. -/
theorem shdP_inc_audit_and_carry {α Coins : Type} [Fintype Coins] [Nonempty Coins]
    (Lq : ℕ) (hLq : 47 ≤ Lq) (key : Option Dig) (domain : List UInt8) (hdom : domain.length ≠ 35)
    (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (hbIn : bInRow = 32 ∨ bInRow = 34)
    (pre : Coins → TProg α) (mPre : ℕ) (hs : ∀ c, TProg.Sep key (pre c)) (hsq : ∀ c, SqLE mPre (pre c))
    (hmPre : mPre + 1000 < 2 ^ 64)
    (TB TA : Coins → Table) (M : Coins → MTable) (TH : Coins → List Fp2 → Table)
    (Dc : Coins → (ch : List Fp2) → SlotData ((shdVi tag Rp embDigest bInRow).bp
      (incCtx (shdVi tag Rp embDigest bInRow).pub ch)))
    (G : QB Lq → Dig) (c : Coins) (D : IncData (shdVi tag Rp embDigest bInRow))
    (hB : D.bRoot = rootOf (liftH G) tag 16 (TB c))
    (hA : D.aRoot = rootOf (liftH G) tag 14 (TA c))
    (hM : D.maskRoot = rootOf (liftH G) tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c)))
    (hH : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH c ch))
    (hD : D.slot = Dc c)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr)
    (hsl :
      let V := shdVi tag Rp embDigest bInRow
      let ch := (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).1
      stSlotsProve (liftH G) (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN) (D.slot ch) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
        (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (Tr.newKeyed (liftH G) domain key)).1).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN)
        = .ok (sps, recs, acc, t4)) :
    let V := shdVi tag Rp embDigest bInRow
    OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ 12 3 3
        (shdP_incCollA Lq hLq key domain hdom tag Rp embDigest bInRow pre mPre hs hsq hmPre TB TA M TH Dc) G c acc.claims.a
      ∧ OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ 12 4 6
          (shdP_incCollH Lq hLq key domain hdom tag Rp embDigest bInRow pre mPre hs hsq hmPre TB TA M TH Dc) G c
          (acc.claims.h ++ [V.lay.logupSumClaim])
      ∧ acc.claims.inp.length = 1
      ∧ BndCarryOk bInRow acc.claims.out := by
  let V := shdVi tag Rp embDigest bInRow
  let t0 := Tr.newKeyed (liftH G) domain key
  let tStart := ((pre c).final (liftH G) t0).1
  let ch := (incCh (liftH G) V D tStart).1
  let hd := fun c' => incHeadProg V c' (pre c') (rootOfP tag 16 (TB c')) (rootOfP tag 14 (TA c'))
    (rootOfP tag 12 (mTab 4 (cosetPt (rootFp 12)) (M c'))) (fun ch' => rootOfP tag 14 (TH c' ch'))
  have hF : (hd c).final (liftH G) t0
      = (absorbRoot (liftH G) (incCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN, (c, ch)) := by
    rw [final_incHeadProg, hH]; unfold ch incCh; rw [hB, hA, hM]
  have hfam : famProve (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {}
      (absorbRoot (liftH G) (incCh (liftH G) V D tStart).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN)
      = .ok (sps, recs, acc, t4) := by
    rw [← stSlotsProve_eq_fam, ← hD]; exact hsl
  obtain ⟨haR, haP, haS, hhR, hhP, hhS, hhU, -, -, -, -, -, -, -, hsumParts⟩ :=
    shdP_incLay_audit_nums Rp embDigest (embFoldL Rp.inp)
  have hVlay : V.lay = incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14 := rfl
  have hShape : ∀ s, s < 4 → (slotShape (incPf V (c, ch) s) s).1 = incMains s ∧ incMains s ≤ 20
      ∧ (slotShape (incPf V (c, ch) s) s).2.1 = incExts s := fun s hsLt => by
    change (slotShape (V.bp (incCtx V.pub ch)) s).1 = _ ∧ _ ∧ (slotShape (V.bp (incCtx V.pub ch)) s).2.1 = _
    rw [shdP_incSlotShape_eq_run]; interval_cases s <;> decide
  have hdEq : ∀ s, s < 4 → (incPf V (c, ch) s).draws s = incDrawsF s := fun s hsLt => by
    change incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s = _
    rw [shdP_incDraws_eq_run]; interval_cases s <;> rfl
  have hPartsA : acc.claims.a.map Exec.Block.ZClaim.parts = incPrivsA.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (incPf V (c, ch) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts) ++ [] := by
    have hfp := famProve_claims_parts (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) Fp2.zero Fp2.zero Fp2.zero .a
      (fun s recs1 dr => (incPrivsA.filter (fun q => decide (q.1 = s))).map
        (fun q => q.2.eval (Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero recs1) s dr)))
      4 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_incDefine_privs Rp embDigest bInRow (incCtx V.pub ch) i hi
          (histOf Fp2.zero Fp2.zero Fp2.zero recs1) dr df hdrLen hcan hdf
          (Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero recs1) i dr) rfl).1)
    exact hfp
  have hPartsH : (acc.claims.h ++ [V.lay.logupSumClaim]).map Exec.Block.ZClaim.parts = incPrivsH.map (fun sp =>
      let r := recs.getD sp.1 rec0
      let ev := Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero (recs.take sp.1)) sp.1 r.draws
      let p := sp.2.eval ev
      (buildClaim (incPf V (c, ch) sp.1) p (claimPoint p r.rho) (oneMinusProd r.es) (maskCoef r.es p.extRound) Fp2.zero).parts)
      ++ [V.lay.logupSumClaim.parts] := by
    have hfp := famProve_claims_parts (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) Fp2.zero Fp2.zero Fp2.zero .h
      (fun s recs1 dr => (incPrivsH.filter (fun q => decide (q.1 = s))).map
        (fun q => q.2.eval (Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero recs1) s dr)))
      4 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_incDefine_privs Rp embDigest bInRow (incCtx V.pub ch) i hi
          (histOf Fp2.zero Fp2.zero Fp2.zero recs1) dr df hdrLen hcan hdf
          (Sym.eval (histOf Fp2.zero Fp2.zero Fp2.zero recs1) i dr) rfl).2.1)
    rw [List.map_append, List.map_singleton]
    exact congrArg (· ++ [V.lay.logupSumClaim.parts]) hfp
  have hAudA : OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ 12 3 3
      (shdP_incCollA Lq hLq key domain hdom tag Rp embDigest bInRow pre mPre hs hsq hmPre TB TA M TH Dc) G c acc.claims.a := by
    have h := openAuditOk_of_symSpec Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga hd
      4 12 41 33 39 3 3 3 (mPre + 117) 20 20 incMains incExts incDrawsF incPrivsA incGroupsA none rfl
      (fun s hsLt c' => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
      (fun s hsLt c' => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
      (fun s hsLt _ => by change incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s ≤ 20; rw [shdP_incDraws_eq_run]; interval_cases s <;> norm_num)
      (by omega) (by norm_num) rfl rfl (by rw [incSpecA_ok.1]; rfl) incSpecA_ok.2 G c (c, ch) _ hF
      hShape hdEq (fun sp hsp => by
        simp only [incPrivsA, List.mem_cons, List.not_mem_nil, or_false] at hsp; rcases hsp with rfl | rfl | rfl <;> rfl)
      sps recs acc t4 hfam (fun _ _ _ _ h => by cases h) acc.claims.a hPartsA
    change OpenAuditOk ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ 12 3 3 _ G c acc.claims.a
    rw [hVlay, haR, haP, haS]; exact h
  have hAudH : OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ 12 4 6
      (shdP_incCollH Lq hLq key domain hdom tag Rp embDigest bInRow pre mPre hs hsq hmPre TB TA M TH Dc) G c
      (acc.claims.h ++ [V.lay.logupSumClaim]) := by
    let sumPre : List Exec.Block.ZPart :=
      [⟨0, 12, kI 1, []⟩, ⟨4096, 12, (kI 1).mul fp2U, []⟩, ⟨8192, 17, kI (-1), []⟩, ⟨139264, 17, (kI (-1)).mul fp2U, []⟩]
    have h := openAuditOk_of_symSpec Lq hLq key domain hdom (incPf V) (incDf V Dc) incBga hd
      4 12 76 68 74 3 4 6 (mPre + 117) 20 20 incMains incExts incDrawsF incPrivsH incGroupsH
      (some (66, 67, V.lay.logupSumClaim, sumPre)) rfl
      (fun s hsLt c' => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').1)
      (fun s hsLt c' => (shdP_incSlotEndProg_sep_sq tag Rp embDigest bInRow mPre key pre TB TA M TH Dc hs hsq s (Nat.le_of_lt hsLt) c').2)
      (fun s hsLt _ => by change incDraws (shdP_incPub Rp embDigest (embFoldL Rp.inp)) s ≤ 20; rw [shdP_incDraws_eq_run]; interval_cases s <;> norm_num)
      (by omega) (by norm_num) rfl rfl (by rw [incSpecH_ok.1]; rfl) incSpecH_ok.2 G c (c, ch) _ hF
      hShape hdEq (fun sp hsp => by
        simp only [incPrivsH, List.mem_cons, List.not_mem_nil, or_false] at hsp; rcases hsp with rfl | rfl | rfl <;> rfl)
      sps recs acc t4 hfam (fun u0 u1 sc pre' hso => by
        have he := Option.some.inj hso; simp only [Prod.mk.injEq] at he; obtain ⟨rfl, rfl, rfl, rfl⟩ := he
        refine ⟨rfl, rfl, hsumParts, fun q hq => ?_⟩
        simp only [sumPre, List.mem_cons, List.not_mem_nil, or_false] at hq
        rcases hq with rfl | rfl | rfl | rfl <;> exact ⟨rfl, by norm_num, by unfold partHi; norm_num⟩)
      (acc.claims.h ++ [V.lay.logupSumClaim]) hPartsH
    change OpenAuditOk ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ 12 4 6 _ G c _
    rw [hVlay, hhR, hhP, hhS, hhU]; exact h
  have hInpLen : acc.claims.inp.length = 1 := by
    have hfp := famProve_claims_parts (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) Fp2.zero Fp2.zero Fp2.zero .inp
      (fun s _ _ => if s = 0 then [⟨.inp, [(0, Fp2.one)], 8, StageV.rhoC 0 8, 1, 0⟩] else [])
      4 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_incDefine_privs Rp embDigest bInRow (incCtx V.pub ch) i hi
          (histOf Fp2.zero Fp2.zero Fp2.zero recs1) dr df hdrLen hcan hdf (fun _ => Fp2.zero) rfl).2.2.1)
    have hfp' : acc.claims.inp.map Exec.Block.ZClaim.parts =
        [(buildClaim (incPf V (c, ch) 0) ⟨.inp, [(0, Fp2.one)], 8, StageV.rhoC 0 8, 1, 0⟩
            (claimPoint ⟨.inp, [(0, Fp2.one)], 8, StageV.rhoC 0 8, 1, 0⟩ (recs.getD 0 rec0).rho)
            (oneMinusProd (recs.getD 0 rec0).es) (maskCoef (recs.getD 0 rec0).es 0) Fp2.zero).parts] := hfp
    have hl := congrArg List.length hfp'
    simpa only [List.length_map, List.length_singleton] using hl
  have hOutCarry : BndCarryOk bInRow acc.claims.out := by
    have hfp := famProve_claims_parts (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) Fp2.zero Fp2.zero Fp2.zero .out
      (fun s _ _ => if s = 1 then [⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC (incCtx V.pub ch).rEmb, bInRow, 0⟩] else [])
      4 [] 0 {} _ sps recs acc t4 hfam (fun i hi recs1 dr df _ hdf hdrLen hcan => by
        rw [Nat.zero_add] at hdf hdrLen ⊢
        exact (shdP_incDefine_privs Rp embDigest bInRow (incCtx V.pub ch) i hi
          (histOf Fp2.zero Fp2.zero Fp2.zero recs1) dr df hdrLen hcan hdf (fun _ => Fp2.zero) rfl).2.2.2)
    have hpartsOut : acc.claims.out.map Exec.Block.ZClaim.parts =
        [(buildClaim (incPf V (c, ch) 1)
            ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC (incCtx V.pub ch).rEmb, bInRow, 0⟩
            (claimPoint ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC (incCtx V.pub ch).rEmb, bInRow, 0⟩
              (recs.getD 1 rec0).rho)
            (oneMinusProd (recs.getD 1 rec0).es) (maskCoef (recs.getD 1 rec0).es 0) Fp2.zero).parts] := hfp
    cases hout : acc.claims.out with
    | nil => have hl := congrArg List.length hpartsOut; rw [hout] at hl; simp at hl
    | cons cl rest =>
      cases rest with
      | cons _ _ => have hl := congrArg List.length hpartsOut; rw [hout] at hl; simp at hl
      | nil =>
        rw [hout, List.map_singleton, List.singleton_inj] at hpartsOut
        obtain ⟨_, _, hslot⟩ := famProve_split (liftH G) (incPf V (c, ch)) (incDf V Dc (c, ch)) _ _ _ 4 [] 0 {} _ sps recs acc t4 hfam
        obtain ⟨_, _, _, _, sp1, r1, _, _, _, _, hget1, hsp1⟩ := hslot 1 (by omega)
        simp only [Nat.zero_add, List.length_nil] at hget1
        have hsp1' := slotProve_congr_idx (Nat.zero_add 1) hsp1
        obtain ⟨_, _, _, _, _, he1, he1L, _, _, _, _⟩ := slotProve_ok_struct (liftH G) (incPf V (c, ch) 1) _ 1 _ _ _ sp1 r1 _ _ hsp1'
        have hchLen : ch.length = 15 := by
          unfold ch incCh; rw [chalVec_length]; exact (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
        have hptLen : (claimPoint ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC (incCtx V.pub ch).rEmb, bInRow, 0⟩
            (recs.getD 1 rec0).rho).length = 19 := by
          unfold claimPoint incCtx fixedC StageV.rhoC
          simp only [List.length_map, List.length_append, List.length_range', List.length_drop, hchLen]
        have he1L' : (recs.getD 1 rec0).es.length = 1 := by rw [hget1]; exact he1L.trans (hShape 1 (by omega)).2.2
        have hbc := buildClaim_bndCarryOk (incPf V (c, ch) 1)
          ⟨.out, [(0, Fp2.one)], 19, StageV.rhoC 5 12 ++ fixedC (incCtx V.pub ch).rEmb, bInRow, 0⟩
          _ (recs.getD 1 rec0).es cl.value bInRow rfl rfl rfl hptLen rfl hbIn
          (fun e he => by rw [hget1] at he; exact (he1 e he).1)
          (fun e he => by rw [hget1] at he; exact (he1 e he).2) (by change 0 < (recs.getD 1 rec0).es.length; omega)
        obtain ⟨cl2, hcl2Eq, hfl2, hsu2, hun2⟩ := hbc
        have hpeq : cl.parts = cl2.parts := by rw [hpartsOut, List.singleton_inj.mp hcl2Eq.symm]; rfl
        refine ⟨cl, rfl, by rw [hpeq]; exact hfl2, ?_, fun q hq => by
          have h := hun2 q (by rw [← hpeq]; exact hq); unfold claimKey at h ⊢; rw [hpeq]; exact h⟩
        unfold SurvivingAuditClaim at hsu2 ⊢; unfold claimWeight at hsu2 ⊢; rw [hpeq]; exact hsu2
  exact ⟨hAudA, hAudH, hInpLen, hOutCarry⟩

end StageInAudit

end ZK60.HonestShield
