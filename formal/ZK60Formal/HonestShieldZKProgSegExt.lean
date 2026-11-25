/-
D63 lane L69, Milestone B Part 3b (`HonestShieldZKProgSegExt.lean`):
whole-run active trace extraction (`IncSegTrace`, `BlkSegTrace`, `OutcSegTrace`, `FullRunTrace`)
and `(verdict, v)`-only invariance theorems for `HonestShieldZKProgInst`.

Only standard Lean/Mathlib foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKProgHelpers

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound ZK60.Hiding
open ZK60.ZKW16 ZK60.ZKLinks ZK60.ZKHonest ZK60.HonestClassify ZK60.HonestOpen
open ZK60.HonestRun ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifyArithP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec SlotKind Segment SegGeom Tab)
open ZK60.Exec.Block.Join.R13H (progR13_shield_okP progR13_slot numSlot_fields)
open ZK60.Exec.Block.Join.R13H.Pub (pubsR13L)
open ZK60.Exec.Slot.W16R2 (Kind kindOf hostsOf nSlots)


/-! ## 2. Whole-Run Active Trace Extraction (`IN-C`, 26× `Blk`, `OUT-C`) -/

section SegmentExtractors

/-- Pure `vf`-driven Stage IN-C active trace at `(x, c)` (base `4104`). -/
structure IncSegTrace {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins) (vf : ℕ → Dig) where
  ch : List Fp2
  ch_eq : ch = (List.range 15).map (fun j => challengeFp2Of (vf (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + j)))
  hbad : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false
  sps : List SlotProof
  recs : List SlotRec
  acc : Acc
  dfs : Fin 4 → SlotDef
  accs : Fin 4 → Acc
  mO : Exec.Block.MaskOpening
  aO : Exec.Block.OpeningZk
  hO : Exec.Block.OpeningZk
  eO : Exec.Block.OpeningZk
  sps_len : sps.length = 4
  recs_len : recs.length = 4
  cs_len : acc.cs.length = 4
  sl_res :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let bSl := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3
    let D := shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
      (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
      (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c)
    ((stSlotsProveFixedProg (2 ^ 20) le_rfl none P (incElog V.pub 14) D Fp2.zero Fp2.zero Fp2.zero 4
      true [] 0 {} ⟨vf (bSl - 1), 15, none⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc)
  slot_spec : ∀ t : Fin 4,
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let elog := incElog V.pub 14
    let D := shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
      (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
      (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c)
    let bSl := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3
    let bj := bSl + slotsFixedLen P 0 t.val
    let dr := (List.range (P.draws t.val)).map (fun k => challengeFp2Of (vf (bj + k)))
    let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
    let scBase := bj + P.draws t.val + 3
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
    let rho := rhoFull.take (Exec.Block.slotShape P t.val).1
    let es := rhoFull.drop (Exec.Block.slotShape P t.val).1
    let hist := Exec.Block.histOf Fp2.zero Fp2.zero Fp2.zero (recs.take t.val)
    ch0.isZero = false
    ∧ P.define t.val hist dr = .ok (dfs t)
    ∧ (recs[t.val]'(by omega)).draws = dr
    ∧ (sps[t.val]'(by omega)).scalar = D.scalar t.val hist (accs t) (dfs t) ch0
    ∧ (sps[t.val]'(by omega)).rounds =
        ((scProveFixedProg (2 ^ 20) le_rfl none (slotN P t.val) true (D.strat t.val hist (accs t) (dfs t) ch0)
          ⟨vf (bj + P.draws t.val + 2), 0, none⟩).res (fun _ => default) vf scBase).1
    ∧ (sps[t.val]'(by omega)).terms = D.terms t.val hist (accs t) (dfs t) ch0 rhoFull
    ∧ (∀ p, Tab.priv p ∈ (dfs t).tabs →
        let z0 := Exec.Block.buildClaim (atLog P (elog t.val)) p (Exec.Block.claimPoint p rho)
          (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
        match p.cm with
        | .a => ∃ z ∈ acc.claims.a, z.parts = z0.parts
        | .h => ∃ z ∈ acc.claims.h, z.parts = z0.parts
        | .inp => ∃ z ∈ acc.claims.inp, z.parts = z0.parts
        | .out => ∃ z ∈ acc.claims.out, z.parts = z0.parts)
  fs_terms : (acc.fs ++ acc.hostFs).map Exec.Block.MaskFunctional.terms =
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let bSl := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3
    (List.finRange 4).flatMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      let ev := [(t.val, Cfs.evalWeights rhoFull nd.2.2)]
      match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
    ++ (List.finRange 4).filterMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      match P.kind t.val with
      | .host =>
        some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
          (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
            (Exec.Block.slotShape P hk.1).2.2).map
              (fun w => w.mul (hk.2.mul ((accs t).cs.getD hk.1 Fp2.zero)).neg)))
      | _ => none)
  mO_eq :
    let bMo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167
    let θ := challengeFp2Of (vf bMo)
    let rs := (List.range (2 * 4 + 2)).map (fun j => challengeFp2Of (vf (bMo + 2 + j)))
    let sq := (List.range 64).map (fun j => vf (bMo + 2 + (2 * 4 + 2) + 1 + j))
    let idxs := idxOf mDom mQ sq
    let M0 := shdP_incM (shdIncRndOf c)
    let treeM0 := levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)
    mO = ⟨polyWords shdP_U shdP_hbij (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M0 4 ((acc.fs ++ acc.hostFs).map toMF) (θ.toK shdP_U)),
          polyWords shdP_U shdP_hbij (pPoly shdP_U M0 4 rs),
          idxs.map (fun j => ofOCol (j, mCol 4 (cosetPt (rootFp 12)) M0 j, M0.salts j, treeM0.pathD j))⟩
  haudA : auditClaims acc.claims.a (2 ^ 12) 41 (List.range' 33 6) none 39 = .ok ()
  hDetA :
    let bAo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77
    let proxR := (List.range 41).map (fun j => challengeFp2Of (vf (bAo + 3 + j)))
    (Exec.Block.det (proxR.getD 39 Fp2.zero) (proxR.getD 40 Fp2.zero)).v ≠ 0
  hSumA : ((groupZclaims (acc.claims.a.map toZClaim) 41 12).map (fun x => x.2.length)).sum = 3
  aO_eq :
    let bAo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77
    let lams := (List.range 3).map (fun j => challengeFp2Of (vf (bAo + j)))
    let proxR := (List.range 41).map (fun j => challengeFp2Of (vf (bAo + 3 + j)))
    let sq := (List.range 64).map (fun j => vf (bAo + 3 + 41 + 3 + 1 + j))
    let idxs := idxOf shdP_stgPrm.nn shdP_stgPrm.nQ sq
    let TA0 := shdP_incTA x (shdIncRndOf c)
    let treeA0 := levelsOfV vf 14 (4104 + 131071 + 5)
    aO = ⟨(groupRhosAux 41 (pGroups shdP_stgPrm TA0 (acc.claims.a.map toZClaim)) lams).map
            (fun rho => combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) rho TA0.rows),
          combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) proxR TA0.rows,
          idxs.map (fun j => ofOCol (j, TA0.cols j, TA0.salts j, treeA0.pathD j))⟩
  haudH :
    let clH := acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]
    auditClaims clH (2 ^ 12) 76 (List.range' 68 6) (some (66, 67)) 74 = .ok ()
  hLenH : (acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]).length = 4
  hDetH :
    let bHo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77 + 112
    let proxR := (List.range 76).map (fun j => challengeFp2Of (vf (bHo + 4 + j)))
    (Exec.Block.det (proxR.getD 74 Fp2.zero) (proxR.getD 75 Fp2.zero)).v ≠ 0
  hSumH :
    let clH := acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]
    ((groupZclaims (clH.map toZClaim) 76 12).map (fun x => x.2.length)).sum = 4
  hO_eq :
    let bHo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77 + 112
    let lams := (List.range 4).map (fun j => challengeFp2Of (vf (bHo + j)))
    let proxR := (List.range 76).map (fun j => challengeFp2Of (vf (bHo + 4 + j)))
    let sq := (List.range 64).map (fun j => vf (bHo + 4 + 76 + 4 + 1 + j))
    let idxs := idxOf shdP_stgPrm.nn shdP_stgPrm.nQ sq
    let TH0 := shdP_incTH Rp embDigest x (shdIncRndOf c) ch
    let treeH0 := levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)
    let clH := acc.claims.h ++ [(shdVi tag Rp embDigest bInRow).lay.logupSumClaim]
    hO = ⟨(groupRhosAux 76 (pGroups shdP_stgPrm TH0 (clH.map toZClaim)) lams).map
            (fun rho => combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) rho TH0.rows),
          combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) proxR TH0.rows,
          idxs.map (fun j => ofOCol (j, TH0.cols j, TH0.salts j, treeH0.pathD j))⟩
  hhdrE : tokenEpHdrOk acc.claims.inp 1 256 = true
  hDetE :
    let bEo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77 + 112 + 149
    let proxR := (List.range 6).map (fun j => challengeFp2Of (vf (bEo + 1 + j)))
    (Exec.Block.det (proxR.getD 3 Fp2.zero) (proxR.getD 4 Fp2.zero)).v ≠ 0
  eO_eq :
    let bEo := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3 + 167 + 77 + 112 + 149
    let lams := (List.range 1).map (fun j => challengeFp2Of (vf (bEo + j)))
    let proxR := (List.range 6).map (fun j => challengeFp2Of (vf (bEo + 1 + j)))
    let sq := (List.range 64).map (fun j => vf (bEo + 1 + 6 + 1 + 1 + j))
    let idxs := idxOf shdP_epPrm.nn shdP_epPrm.nQ sq
    let TE := shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)
    let treeTE := levelsOfV vf 11 0
    eO = ⟨(groupRhosAux 6 (pGroups shdP_epPrm TE (acc.claims.inp.map toZClaim)) lams).map
            (fun rho => combVec (shdP_epPrm.n + shdP_epPrm.qPad) rho TE.rows),
          combVec (shdP_epPrm.n + shdP_epPrm.qPad) proxR TE.rows,
          idxs.map (fun j => ofOCol (j, TE.cols j, TE.salts j, treeTE.pathD j))⟩
  out_eq : ∀ {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig),
    let V := shdVi tag Rp embDigest bInRow
    let G := rcIncGeom V 28
    let bRoot := (levelsOfV vf 16 4104).getRoot
    let aRoot := (levelsOfV vf 14 (4104 + 131071 + 5)).getRoot
    let mRoot := (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot
    let hRoot := (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot
    let seg : StageSeg := ⟨some bRoot, ⟨aRoot, hRoot, mRoot, sps, mO, aO, hO⟩, [eO]⟩
    ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c (levelsOfV vf 11 0)
        (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).1
      = some (fun e => encStage G (vf 4101) (posTagOfV vf 4102) seg e, ⟨acc.claims.out, bRoot⟩)

private theorem res_fst_andThen_step {Q D α β γ : Type}
    {p : PProg Q D α} {k : α → PProg Q D (β × γ)} {n : ℕ} (hp : p.PtLen n)
    {H : Q → D} {v : ℕ → D} {base base' : ℕ} (hb : base + n = base')
    {a : α} (ha : p.res H v base = a) {rhs : β}
    (hk : ((k a).res H v base').1 = rhs) :
    ((p.andThen k).res H v base).1 = rhs := by
  rw [PProg.res_andThen H v p k n base hp, ha, hb]
  exact hk

private theorem res_snd_fst_andThen_step {Q D α β γ δ : Type}
    {p : PProg Q D α} {k : α → PProg Q D (β × γ × δ)} {n : ℕ} (hp : p.PtLen n)
    {H : Q → D} {v : ℕ → D} {base : ℕ}
    {a : α} (ha : p.res H v base = a) {rhs : γ}
    (hk : ((k a).res H v (base + n)).2.1 = rhs) :
    ((p.andThen k).res H v base).2.1 = rhs := by
  rw [PProg.res_andThen H v p k n base hp, ha]
  exact hk

private theorem res_snd_fst_andThen_forall {Q D α β γ δ : Type}
    {p : PProg Q D α} {k : α → PProg Q D (β × γ × δ)} {n : ℕ} (hp : p.PtLen n)
    {H : Q → D} {v : ℕ → D} {base : ℕ} {rhs : γ}
    (hk : ∀ a, ((k a).res H v (base + n)).2.1 = rhs) :
    ((p.andThen k).res H v base).2.1 = rhs := by
  rw [PProg.res_andThen H v p k n base hp]
  exact hk (p.res H v base)

private theorem res_snd_fst_ite_ret {Q D α β γ : Type} (c : Bool) (x y : α) (b : β) (z : γ)
    (H : Q → D) (v : ℕ → D) (base : ℕ) :
    ((if c then (PProg.ret (x, b, z) : PProg Q D (α × β × γ)) else PProg.ret (y, b, z)).res H v base).2.1 = b := by
  cases c <;> rfl

private theorem res_andThen_pred {Q D α β : Type} (H : Q → D) (v : ℕ → D) (P : β → Prop) :
    ∀ (p : PProg Q D α) (f : α → PProg Q D β) (i : ℕ),
      (∀ a j, P ((f a).res H v j)) → P ((p.andThen f).res H v i)
  | .ret a, _f, i, hf => hf a i
  | .dep z k, f, i, hf => res_andThen_pred H v P (k (H z)) f i hf
  | .pt _ k, f, i, hf => res_andThen_pred H v P (k (v i)) f (i + 1) hf

private theorem res_andThen_pred_first {Q D α β : Type} (H : Q → D) (v : ℕ → D) (P : β → Prop)
    (p : PProg Q D α) (f : α → PProg Q D β) (i : ℕ) (a : α) (ha : p.res H v i = a)
    (hf : ∀ j, P ((f a).res H v j)) : P ((p.andThen f).res H v i) := by
  induction p generalizing i with
  | ret x => cases ha; exact hf i
  | dep z k ih => exact ih (H z) i ha
  | pt _ k ih => exact ih (v i) (i + 1) ha

private theorem res_snd_fst_andThen_first {Q D α β γ δ : Type} {H : Q → D} {v : ℕ → D}
    {p : PProg Q D α} {f : α → PProg Q D (β × γ × δ)} {i : ℕ} {a : α} {rhs : γ}
    (ha : p.res H v i = a) (hf : ∀ j, ((f a).res H v j).2.1 = rhs) :
    ((p.andThen f).res H v i).2.1 = rhs :=
  res_andThen_pred_first H v (fun r => r.2.1 = rhs) p f i a ha hf

private theorem res_snd_fst_andThen_any {Q D α β γ δ : Type} {H : Q → D} {v : ℕ → D}
    {p : PProg Q D α} {f : α → PProg Q D (β × γ × δ)} {i : ℕ} {rhs : γ}
    (hf : ∀ a j, ((f a).res H v j).2.1 = rhs) :
    ((p.andThen f).res H v i).2.1 = rhs :=
  res_andThen_pred H v (fun r => r.2.1 = rhs) p f i hf

private theorem stSlotsProve_res_of_act_eq {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig}
    {P : BlockParams} {elog : ℕ → ℕ} {D : SlotData P} {b g a : Fp2} {vf : ℕ → Dig} {m : ℕ}
    {act₁ act₂ : Bool} (hAct : act₁ = act₂) {rs : List SlotRec} {s : ℕ} {acc : Acc}
    {t : Tr} {base : ℕ} {rhs : Option (List SlotProof × List SlotRec × Acc)}
    (h : ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m act₁ rs s acc t).res (fun _ => default) vf base).1 = rhs) :
    ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m act₂ rs s acc t).res (fun _ => default) vf base).1 = rhs := by
  subst hAct; exact h

private theorem slotsProve_res_of_act_eq {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig}
    {P : BlockParams} {D : SlotData P} {b g a : Fp2} {vf : ℕ → Dig} {m : ℕ}
    {act₁ act₂ : Bool} (hAct : act₁ = act₂) {rs : List SlotRec} {s : ℕ} {acc : Acc}
    {t : Tr} {base : ℕ} {rhs : Option (List SlotProof × List SlotRec × Acc)}
    (h : ((slotsProveFixedProg Lq hL20 key P D b g a m act₁ rs s acc t).res (fun _ => default) vf base).1 = rhs) :
    ((slotsProveFixedProg Lq hL20 key P D b g a m act₂ rs s acc t).res (fun _ => default) vf base).1 = rhs := by
  subst hAct; exact h

private theorem openingAudit_some_extract {c : Bool} {gv : List (List Fp2)} {pv : List Fp2}
    {cols : List Exec.Block.Column} {aO : Exec.Block.OpeningZk}
    (h : some aO = if c then some ⟨if c then gv else [], if c then pv else [], cols⟩ else none) :
    c = true ∧ aO = ⟨gv, pv, cols⟩ := by
  cases hc : c
  · rw [hc] at h; cases h
  · rw [hc] at h; exact ⟨rfl, Option.some.inj h⟩

private theorem openingAudit_res_of_pass {c : Bool} {gv : List (List Fp2)} {pv : List Fp2}
    {cols : List Exec.Block.Column} (hc : c = true) :
    (if c then some (Exec.Block.OpeningZk.mk (if c then gv else []) (if c then pv else []) cols) else none)
    = some ⟨gv, pv, cols⟩ := by
  rw [hc]; rfl

private theorem res_fst_andThen_rel₂ {Q₁ Q₂ D α₁ α₂ γ δ₁ δ₂ : Type}
    {p₁ : PProg Q₁ D α₁} {f₁ : α₁ → PProg Q₁ D (γ × δ₁)}
    {p₂ : PProg Q₂ D α₂} {f₂ : α₂ → PProg Q₂ D (γ × δ₂)}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H₁ : Q₁ → D} {H₂ : Q₂ → D} {v : ℕ → D} {base : ℕ}
    (A : α₁ → α₂ → Prop)
    (ha : A (p₁.res H₁ v base) (p₂.res H₂ v base))
    (hf : ∀ a₁ a₂, A a₁ a₂ → ((f₁ a₁).res H₁ v (base + n)).1 = ((f₂ a₂).res H₂ v (base + n)).1) :
    ((p₁.andThen f₁).res H₁ v base).1 = ((p₂.andThen f₂).res H₂ v base).1 := by
  rw [PProg.res_andThen H₁ v p₁ f₁ n base hp₁, PProg.res_andThen H₂ v p₂ f₂ n base hp₂]
  exact hf _ _ ha

private theorem res_fst_andThen_rel₂_true {Q₁ Q₂ D α₁ α₂ γ δ₁ δ₂ : Type}
    {p₁ : PProg Q₁ D α₁} {f₁ : α₁ → PProg Q₁ D (γ × δ₁)}
    {p₂ : PProg Q₂ D α₂} {f₂ : α₂ → PProg Q₂ D (γ × δ₂)}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H₁ : Q₁ → D} {H₂ : Q₂ → D} {v : ℕ → D} {base : ℕ}
    (hf : ∀ a₁ a₂, ((f₁ a₁).res H₁ v (base + n)).1 = ((f₂ a₂).res H₂ v (base + n)).1) :
    ((p₁.andThen f₁).res H₁ v base).1 = ((p₂.andThen f₂).res H₂ v base).1 :=
  res_fst_andThen_rel₂ hp₁ hp₂ (fun _ _ => True) trivial (fun a₁ a₂ _ => hf a₁ a₂)

private theorem res_fst_andThen_rel₂_fst {Q₁ Q₂ D μ ν₁ ν₂ γ δ₁ δ₂ : Type}
    {p₁ : PProg Q₁ D (μ × ν₁)} {f₁ : μ × ν₁ → PProg Q₁ D (γ × δ₁)}
    {p₂ : PProg Q₂ D (μ × ν₂)} {f₂ : μ × ν₂ → PProg Q₂ D (γ × δ₂)}
    {n : ℕ} (hp₁ : p₁.PtLen n) (hp₂ : p₂.PtLen n)
    {H₁ : Q₁ → D} {H₂ : Q₂ → D} {v : ℕ → D} {base : ℕ}
    (ha : (p₁.res H₁ v base).1 = (p₂.res H₂ v base).1)
    (hf : ∀ a₁ a₂, a₁.1 = a₂.1 → ((f₁ a₁).res H₁ v (base + n)).1 = ((f₂ a₂).res H₂ v (base + n)).1) :
    ((p₁.andThen f₁).res H₁ v base).1 = ((p₂.andThen f₂).res H₂ v base).1 :=
  res_fst_andThen_rel₂ hp₁ hp₂ (fun a₁ a₂ => a₁.1 = a₂.1) ha hf

private theorem uint64_add_1_1_1 (c : UInt64) : c + 1 + 1 + 1 = c + 3 := by
  rw [UInt64.add_assoc, UInt64.add_assoc, show (1 : UInt64) + (1 + 1) = 3 by decide]

/-- Helper: `scProveFixedProg.res.1` is independent of `(Lq, hL20, key, t)` (depends ONLY on `n, active, wp, vf, base`)! -/
theorem scProveFixedProg_res_indep_key {Lq₁ Lq₂ : ℕ} (h1 : 2 ^ 20 ≤ Lq₁) (h2 : 2 ^ 20 ≤ Lq₂)
    (key₁ key₂ : Option Dig) (vf : ℕ → Dig) :
    ∀ (n : ℕ) (active : Bool) (wp : WProver n) (t₁ t₂ : Tr) (base : ℕ),
      ((scProveFixedProg Lq₁ h1 key₁ n active wp t₁).res (fun _ => default) vf base).1
        = ((scProveFixedProg Lq₂ h2 key₂ n active wp t₂).res (fun _ => default) vf base).1
  | 0, _, _, _, _, _ => rfl
  | n + 1, active, (msg, next), t₁, t₂, base => by
    simp only [scProveFixedProg]
    refine res_fst_andThen_rel₂_true
      (trAbsorbFp2Keyed_ptLen Lq₁ h1 key₁ t₁ scLabel (by decide) _)
      (trAbsorbFp2Keyed_ptLen Lq₂ h2 key₂ t₂ scLabel (by decide) _)
      fun t₁' t₂' => ?_
    refine res_fst_andThen_rel₂_fst
      (trChallengeFp2Keyed_ptLen Lq₁ (by omega) key₁ t₁')
      (trChallengeFp2Keyed_ptLen Lq₂ (by omega) key₂ t₂')
      ((congrArg Prod.fst (trChallengeFp2Keyed_res Lq₁ (by omega) key₁ t₁' _ vf (base + 1))).trans
        (congrArg Prod.fst (trChallengeFp2Keyed_res Lq₂ (by omega) key₂ t₂' _ vf (base + 1))).symm)
      fun rt₁ rt₂ hrt => ?_
    rcases rt₁ with ⟨c₁, s₁⟩; rcases rt₂ with ⟨c₂, s₂⟩
    dsimp only at hrt; subst hrt
    refine res_fst_andThen_rel₂_fst
      (scProveFixedProg_ptLen Lq₁ h1 key₁ n active (next c₁) s₁)
      (scProveFixedProg_ptLen Lq₂ h2 key₂ n active (next c₁) s₂)
      (scProveFixedProg_res_indep_key h1 h2 key₁ key₂ vf n active (next c₁) s₁ s₂ (base + 1 + 1))
      fun rest₁ rest₂ hrest => ?_
    exact congrArg ((if active then msg else []) :: ·) hrest

private theorem scProve_zero_add {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (j : ℕ) (hist : Hist) (acc : Acc) (df : SlotDef)
    (ch0 : Fp2) (tr1 tr2 : Tr) (vf : ℕ → Dig) (base : ℕ) :
    ((scProveFixedProg Lq hL20 key (slotN P (0 + j)) true (D.strat (0 + j) hist acc df ch0) tr1).res (fun _ => default) vf base).1
    = ((scProveFixedProg (2 ^ 20) le_rfl none (slotN P j) true (D.strat j hist acc df ch0) tr2).res (fun _ => default) vf base).1 := by
  have h : ∀ s, s = j →
      ((scProveFixedProg Lq hL20 key (slotN P s) true (D.strat s hist acc df ch0) tr1).res (fun _ => default) vf base).1
      = ((scProveFixedProg (2 ^ 20) le_rfl none (slotN P j) true (D.strat j hist acc df ch0) tr2).res (fun _ => default) vf base).1 := by
    rintro s rfl
    exact scProveFixedProg_res_indep_key hL20 le_rfl key none vf (slotN P s) true _ tr1 tr2 base
  exact h (0 + j) (Nat.zero_add j)

private theorem trChallengeFp2VecKeyed_res_pos (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig)
    (H : QB Lq → Dig) (v : ℕ → Dig) (n : ℕ) (hn : n ≠ 0) (t : Tr) (c : UInt64)
    (hc : t.counter = c) (u : UInt64) (hu : UInt64.ofNat n = u) (base : ℕ) :
    (trChallengeFp2VecKeyed Lq h47 key n t).res H v base =
      ((List.range n).map (fun k => challengeFp2Of (v (base + k))),
        ⟨v (base + n - 1), c + u, key⟩) := by
  rw [trChallengeFp2VecKeyed_res, ite_eq_right hn, hc, hu]

/-- Helper: `slotProveFixedProg.res.1` is independent of `(Lq, hL20, key, t)`. -/
private theorem slotProveFixedProg_res_indep_key {Lq₁ Lq₂ : ℕ} (h1 : 2 ^ 20 ≤ Lq₁) (h2 : 2 ^ 20 ≤ Lq₂)
    (key₁ key₂ : Option Dig) (P : BlockParams) (D : SlotData P) (s : ℕ) (active : Bool)
    (hist : Hist) (acc : Acc) (t₁ t₂ : Tr) (vf : ℕ → Dig) (base : ℕ) :
    ((slotProveFixedProg Lq₁ h1 key₁ P D s active hist acc t₁).res (fun _ => default) vf base).1
      = ((slotProveFixedProg Lq₂ h2 key₂ P D s active hist acc t₂).res (fun _ => default) vf base).1 := by
  unfold slotProveFixedProg
  refine res_fst_andThen_rel₂_fst
    (trChallengeFp2VecKeyed_ptLen Lq₁ (by omega) key₁ (P.draws s) t₁)
    (trChallengeFp2VecKeyed_ptLen Lq₂ (by omega) key₂ (P.draws s) t₂)
    ((congrArg Prod.fst (trChallengeFp2VecKeyed_res Lq₁ (by omega) key₁ _ vf (P.draws s) t₁ base)).trans
      (congrArg Prod.fst (trChallengeFp2VecKeyed_res Lq₂ (by omega) key₂ _ vf (P.draws s) t₂ base)).symm)
    fun dr₁ dr₂ hdr => ?_
  rcases dr₁ with ⟨dv₁, dt₁⟩; rcases dr₂ with ⟨dv₂, dt₂⟩
  dsimp only at hdr; subst hdr
  refine res_fst_andThen_rel₂_true
    (trAbsorbKeyed_ptLen Lq₁ h1 key₁ dt₁ _ _ _)
    (trAbsorbKeyed_ptLen Lq₂ h2 key₂ dt₂ _ _ _)
    fun t₂₁ t₂₂ => ?_
  refine res_fst_andThen_rel₂_fst
    (trChallengeFp2Keyed_ptLen Lq₁ (by omega) key₁ t₂₁)
    (trChallengeFp2Keyed_ptLen Lq₂ (by omega) key₂ t₂₂)
    ((congrArg Prod.fst (trChallengeFp2Keyed_res Lq₁ (by omega) key₁ t₂₁ _ vf _)).trans
      (congrArg Prod.fst (trChallengeFp2Keyed_res Lq₂ (by omega) key₂ t₂₂ _ vf _)).symm)
    fun ct₁ ct₂ hct => ?_
  rcases ct₁ with ⟨cv₁, cTr₁⟩; rcases ct₂ with ⟨cv₂, cTr₂⟩
  dsimp only at hct; subst hct
  refine res_fst_andThen_rel₂_true
    (trAbsorbFp2Keyed_ptLen Lq₁ h1 key₁ cTr₁ _ _ _)
    (trAbsorbFp2Keyed_ptLen Lq₂ h2 key₂ cTr₂ _ _ _)
    fun t₄₁ t₄₂ => ?_
  refine res_fst_andThen_rel₂
    (scProveFixedProg_ptLen Lq₁ h1 key₁ _ _ _ t₄₁)
    (scProveFixedProg_ptLen Lq₂ h2 key₂ _ _ _ t₄₂)
    (fun a₁ a₂ => a₁.1 = a₂.1 ∧ a₁.2.1 = a₂.2.1)
    ⟨scProveFixedProg_res_indep_key h1 h2 key₁ key₂ vf _ _ _ t₄₁ t₄₂ _,
     (scProveFixedProg_res_spec Lq₁ h1 key₁ (fun _ => default) vf _ _ _ t₄₁ _).2.1.trans
       (scProveFixedProg_res_spec Lq₂ h2 key₂ (fun _ => default) vf _ _ _ t₄₂ _).2.1.symm⟩
    fun scr₁ scr₂ hscr => ?_
  rcases scr₁ with ⟨rd₁, rh₁, st₁⟩; rcases scr₂ with ⟨rd₂, rh₂, st₂⟩
  dsimp only at hscr; rcases hscr with ⟨rfl, rfl⟩
  refine res_fst_andThen_rel₂_true
    (trAbsorbFp2Keyed_ptLen Lq₁ h1 key₁ st₁ _ _ _)
    (trAbsorbFp2Keyed_ptLen Lq₂ h2 key₂ st₂ _ _ _)
    fun _ _ => rfl

/-- Helper: `stSlotsProveFixedProg.res.1` is independent of `(Lq, hL20, key, t)`. -/
private theorem stSlotsProveFixedProg_res_indep_key {Lq₁ Lq₂ : ℕ} (h1 : 2 ^ 20 ≤ Lq₁) (h2 : 2 ^ 20 ≤ Lq₂)
    (key₁ key₂ : Option Dig) (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (act : Bool) (rs : List SlotRec) (s0 : ℕ) (a0 : Acc) (t₁ t₂ : Tr) (base : ℕ),
      ((stSlotsProveFixedProg Lq₁ h1 key₁ P elog D b g a m act rs s0 a0 t₁).res (fun _ => default) vf base).1
        = ((stSlotsProveFixedProg Lq₂ h2 key₂ P elog D b g a m act rs s0 a0 t₂).res (fun _ => default) vf base).1
  | 0, _, _, _, _, _, _, _ => rfl
  | m + 1, act, rs, s0, a0, t₁, t₂, base => by
    simp only [stSlotsProveFixedProg]
    refine res_fst_andThen_rel₂_fst
      (slotProveFixedProg_ptLen Lq₁ h1 key₁ (atLog P (elog s0)) (sdAt D (elog s0)) s0 act _ a0 t₁)
      (slotProveFixedProg_ptLen Lq₂ h2 key₂ (atLog P (elog s0)) (sdAt D (elog s0)) s0 act _ a0 t₂)
      (slotProveFixedProg_res_indep_key h1 h2 key₁ key₂ (atLog P (elog s0)) (sdAt D (elog s0)) s0 act _ a0 t₁ t₂ vf base)
      fun r₁ r₂ hr => ?_
    rcases r₁ with ⟨o₁, u₁⟩; rcases r₂ with ⟨o₂, u₂⟩
    dsimp only at hr; subst hr
    cases o₁ with
    | none =>
      refine res_fst_andThen_rel₂_true
        (stSlotsProveFixedProg_ptLen Lq₁ h1 key₁ P elog D b g a m false rs (s0 + 1) a0 u₁)
        (stSlotsProveFixedProg_ptLen Lq₂ h2 key₂ P elog D b g a m false rs (s0 + 1) a0 u₂)
        fun _ _ => rfl
    | some v1 =>
      refine res_fst_andThen_rel₂_fst
        (stSlotsProveFixedProg_ptLen Lq₁ h1 key₁ P elog D b g a m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₁)
        (stSlotsProveFixedProg_ptLen Lq₂ h2 key₂ P elog D b g a m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₂)
        (stSlotsProveFixedProg_res_indep_key h1 h2 key₁ key₂ P elog D b g a vf m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₁ u₂ _)
        fun rest₁ rest₂ hrest => ?_
      rcases rest₁ with ⟨ro₁, _⟩; rcases rest₂ with ⟨ro₂, _⟩
      dsimp only at hrest; subst hrest; cases ro₁ <;> rfl

/-- Helper: `incSegFixedProg.res.2.1` is ALWAYS `levelsOfV vf 16 base`. -/
private theorem incSegFixedProg_res_tree {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ) :
    ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t).res
      (fun _ => default) vf base).2.1 = levelsOfV vf 16 base := by
  unfold incSegFixedProg; dsimp only
  refine res_snd_fst_andThen_first (a := levelsOfV vf 16 base) ?_ fun _ => ?_
  · exact merkleTableProg_res Lq (by omega) tag 16 38 (by omega) _ _ _ vf base
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun slR _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun aR _ => ?_
  refine res_snd_fst_andThen_any fun hR _ => ?_
  refine res_snd_fst_andThen_any fun eR _ => ?_
  rcases slR with ⟨_ | ⟨_, _, _⟩, _⟩ <;> rcases aR with ⟨_ | _, _⟩ <;>
    rcases hR with ⟨_ | _, _⟩ <;> rcases eR with ⟨_ | _, _⟩ <;>
    first | exact res_snd_fst_ite_ret _ _ _ _ _ _ _ _ | rfl

/-- Helper: `blkSegFixedProg.res.2.1` is ALWAYS `levelsOfV vf 16 base`. -/
private theorem blkSegFixedProg_res_tree {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ) :
    ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k active cr treeBPrev bnd startTag t).res (fun _ => default) vf base).2.1
      = levelsOfV vf 16 base := by
  unfold blkSegFixedProg; dsimp only
  refine res_snd_fst_andThen_first (a := levelsOfV vf 16 base) ?_ fun _ => ?_
  · exact merkleTableProg_res Lq (by omega) tag 16 38 (by omega) _ _ _ vf base
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun slR _ => ?_
  refine res_snd_fst_andThen_any fun _ _ => ?_
  refine res_snd_fst_andThen_any fun aOR _ => ?_
  refine res_snd_fst_andThen_any fun hOR _ => ?_
  refine res_snd_fst_andThen_any fun bOR _ => ?_
  rcases slR with ⟨_ | ⟨_, _, _⟩, _⟩ <;> rcases aOR with ⟨_ | _, _⟩ <;>
    rcases hOR with ⟨_ | _, _⟩ <;> rcases bOR with ⟨_ | _, _⟩ <;>
    first | exact res_snd_fst_ite_ret _ _ _ _ _ _ _ _ | rfl

/-- Extract `IncSegTrace` whenever `incSegFixedProg` is active (`isSome = true`) at `vf`. -/
noncomputable def incSeg_extract {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins) (vf : ℕ → Dig)
    (hAct : ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c
        (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).1.isSome = true) :
    IncSegTrace (Hdr := Hdr) tag Rp embDigest bInRow x c vf := by
  classical
  let V := shdVi tag Rp embDigest bInRow
  let ch := (List.range 15).map (fun j => challengeFp2Of (vf (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + j)))
  let P := V.bp (incCtx V.pub ch)
  have hSlLen : slotsFixedLen P 0 4 = 167 := shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow (incCtx V.pub ch)
  obtain ⟨hAR, hAS, hAP, hHR, hHS, hHU, hHP⟩ := shdP_incOpenGeom_eq tag Rp embDigest bInRow
  let bSl := 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3
  have hEv : ∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig)
      (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
      (hsl : (stSlotsProveFixedProg Lq' hL20' key' P (incElog V.pub 14)
          (shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
            (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
            (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
          Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub ch)) [] 0 {}
          ⟨vf (bSl - 1), 15, key'⟩).res (fun _ => default) vf bSl = slR)
      (mR : Exec.Block.MaskOpening × Tr)
      (hm : (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
          (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
          (shdP_incM (shdIncRndOf c)) 4 (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3))
          (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 167) = mR)
      (aR : Option Exec.Block.OpeningZk × Tr)
      (ha : (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V)
          (shdP_incTA x (shdIncRndOf c)) (levelsOfV vf 14 (4104 + 131071 + 5))
          (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
          (openingHdrOk (shdP_incOpenGeomA V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
          (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 167 + 77) = aR)
      (hR : Option Exec.Block.OpeningZk × Tr)
      (hh : (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V)
          (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))
          ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR.1.isSome)
          (openingHdrOk (shdP_incOpenGeomH V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
          (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aR.2).res (fun _ => default) vf (bSl + 167 + 77 + 112) = hR)
      (eR : Option Exec.Block.OpeningZk × Tr)
      (he : (openingAuditFixedProg Lq' hL20' key' shdP_epPrm 11 1 6 1 shdP_epOpenGeom
          (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) (levelsOfV vf 11 0)
          (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR.1.isSome) && hR.1.isSome)
          (tokenEpHdrOk (match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []) 1 256)
          (match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []) hR.2).res (fun _ => default) vf (bSl + 167 + 77 + 112 + 149) = eR),
      ((incSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp embDigest bInRow x c
          (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key'⟩).res (fun _ => default) vf 4104).1 =
      match slR.1, aR.1, hR.1, eR.1 with
      | some (sps, _, acc), some aO, some hO, some eO =>
        if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR.1.isSome) && hR.1.isSome then
          some (
            let seg : StageSeg := ⟨some (levelsOfV vf 16 4104).getRoot,
              ⟨(levelsOfV vf 14 (4104 + 131071 + 5)).getRoot,
               (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot,
               (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot,
               sps, mR.1, aO, hO⟩, [eO]⟩
            (fun e => encStage (rcIncGeom V 28) (vf 4101) (posTagOfV vf 4102) seg e,
             ⟨acc.claims.out, (levelsOfV vf 16 4104).getRoot⟩))
        else none
      | _, _, _, _ => none := by
    intro Lq' hL20' key' slR hsl mR hm aR ha hR hh eR he
    unfold incSegFixedProg
    refine res_fst_andThen_step (merkleTableProg_ptLen Lq' (by omega) tag 16 38 (by omega) _ _)
      (by norm_num : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) = 4104 + 131071)
      (merkleTableProg_res Lq' (by omega) tag 16 38 (by omega) _ _ _ vf 4104) ?_
    refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq' hL20' key' _ _ _ _) rfl
      (trAbsorbKeyed_res Lq' hL20' key' _ _ _ _ _ vf _) ?_
    refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq' hL20' key' _ _ _ _) rfl
      (trAbsorbKeyed_res Lq' hL20' key' _ _ _ _ _ vf _) ?_
    refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq' hL20' key' _ _ _ _ _ _)
      (by norm_num : 4104 + 131071 + 1 + 1 + 3 = 4104 + 131071 + 5)
      (absorbRootKeyed_res Lq' hL20' key' _ _ _ _ _ _ _ vf _) ?_
    refine res_fst_andThen_step (merkleTableProg_ptLen Lq' (by omega) tag 14 41 (by omega) _ _)
      (by norm_num : 4104 + 131071 + 5 + (2 ^ 14 + (2 ^ 14 - 1)) = 4104 + 131071 + 5 + 32767)
      (merkleTableProg_res Lq' (by omega) tag 14 41 (by omega) _ _ _ vf _) ?_
    refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq' hL20' key' _ _ _ _ _ _) rfl
      (absorbRootKeyed_res Lq' hL20' key' _ _ _ _ _ _ _ vf _) ?_
    refine res_fst_andThen_step (merkleTableProg_ptLen Lq' (by omega) tag 12 (2 * 4 + 4) (by omega) _ _)
      (by norm_num : 4104 + 131071 + 5 + 32767 + 3 + (2 ^ 12 + (2 ^ 12 - 1)) = 4104 + 131071 + 5 + 32767 + 3 + 8191)
      (merkleTableProg_res Lq' (by omega) tag 12 (2 * 4 + 4) (by omega) _ _ _ vf _) ?_
    refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq' hL20' key' _ _ _ _) rfl
      (trAbsorbKeyed_res Lq' hL20' key' _ _ _ _ _ vf _) ?_
    refine res_fst_andThen_step (trChallengeFp2VecKeyed_ptLen Lq' (by omega) key' 15 _) rfl
      ((trChallengeFp2VecKeyed_res Lq' (by omega) key' _ vf 15 _ _).trans
        (congrArg (Prod.mk ch)
          ((ite_eq_right (by decide : (15 : ℕ) ≠ 0)).trans
            (congrArg (fun u => Tr.mk (vf (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 - 1)) u key')
              (by decide : (0 : UInt64) + UInt64.ofNat 15 = 15))))) ?_
    refine res_fst_andThen_step (merkleTableProg_ptLen Lq' (by omega) tag 14 76 (by omega) _ _)
      (by norm_num : 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) = 4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767)
      (merkleTableProg_res Lq' (by omega) tag 14 76 (by omega) _ _ _ vf _) ?_
    refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq' hL20' key' _ _ _ _ _ _) (rfl : _ = bSl)
      ((absorbRootKeyed_res Lq' hL20' key' _ _ _ _ _ _ _ vf _).trans
        (congrArg (fun idx => Tr.mk (vf idx) 15 key')
          (Nat.add_sub_assoc (by decide : 1 ≤ 3) _).symm)) ?_
    refine res_fst_andThen_step ((stSlotsProveFixedProg_ptLen Lq' hL20' key' _ _ _ _ _ _ 4 _ [] 0 {} _).congr hSlLen)
      rfl hsl ?_
    refine res_fst_andThen_step (zkBMaskFixedProg_ptLen Lq' hL20' key' shdP_U shdP_hbij _ _ 4 _ _ _)
      (congrArg (bSl + 167 + ·) (by decide : zkBMaskFixedLen 4 = 77))
      hm ?_
    refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq' hL20' key' shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _)
      (congrArg (bSl + 167 + 77 + ·) (by decide : openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ = 112))
      ha ?_
    refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq' hL20' key' shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _)
      (congrArg (bSl + 167 + 77 + 112 + ·) (by decide : openingAuditFixedLen 4 76 4 shdP_stgPrm.nQ = 149))
      hh ?_
    refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq' hL20' key' shdP_epPrm 11 1 6 1 _ _ _ _ _ _ _)
      rfl he ?_
    rcases slR with ⟨_ | ⟨sps, recs, acc⟩, tSl⟩ <;> rcases aR with ⟨_ | aO, tA⟩ <;>
      rcases hR with ⟨_ | hO, tH⟩ <;> rcases eR with ⟨_ | eO, tE⟩
    all_goals first
      | rfl
      | (dsimp only [Option.isSome_some, Bool.and_true, V]
         split_ifs <;> rfl)
  obtain ⟨slR, hslDef⟩ : { slR // (stSlotsProveFixedProg Lq hL20 key P (incElog V.pub 14)
      (shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
        (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
        (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
      Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub ch)) [] 0 {} ⟨vf (bSl - 1), 15, key⟩).res (fun _ => default) vf bSl = slR } := ⟨_, rfl⟩
  obtain ⟨mR, hmDef⟩ : { mR // (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
      (shdP_incM (shdIncRndOf c)) 4 (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3))
      (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 167) = mR } := ⟨_, rfl⟩
  obtain ⟨aR, haDef⟩ : { aR // (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V)
      (shdP_incTA x (shdIncRndOf c)) (levelsOfV vf 14 (4104 + 131071 + 5))
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
      (openingHdrOk (shdP_incOpenGeomA V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 167 + 77) = aR } := ⟨_, rfl⟩
  obtain ⟨hR, hhDef⟩ : { hR // (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V)
      (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))
      ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR.1.isSome)
      (openingHdrOk (shdP_incOpenGeomH V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aR.2).res (fun _ => default) vf (bSl + 167 + 77 + 112) = hR } := ⟨_, rfl⟩
  obtain ⟨eR, heDef⟩ : { eR // (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1 shdP_epOpenGeom
      (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) (levelsOfV vf 11 0)
      (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR.1.isSome) && hR.1.isSome)
      (tokenEpHdrOk (match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []) 1 256)
      (match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []) hR.2).res (fun _ => default) vf (bSl + 167 + 77 + 112 + 149) = eR } := ⟨_, rfl⟩
  have hEv0 := hEv hL20 key slR hslDef mR hmDef aR haDef hR hhDef eR heDef
  have hAct' := (congrArg Option.isSome hEv0).symm.trans hAct
  rcases hSl : slR.1 with _ | ⟨sps, recs, acc⟩; · rw [hSl] at hAct'; cases hAct'
  rcases hA : aR.1 with _ | aO; · rw [hSl, hA] at hAct'; cases hAct'
  rcases hH : hR.1 with _ | hO; · rw [hSl, hA, hH] at hAct'; cases hAct'
  rcases hE : eR.1 with _ | eO; · rw [hSl, hA, hH, hE] at hAct'; cases hAct'
  simp only [hSl, hA, hH, hE, Option.isSome_some, Bool.and_true] at hAct'
  have hAct4 : decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) = true := by
    by_cases hc : decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) = true
    · exact hc
    · rw [ite_eq_right hc] at hAct'; cases hAct'
  have hSlVal : ((stSlotsProveFixedProg Lq hL20 key P (incElog V.pub 14)
      (shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
        (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
        (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
      Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub ch)) [] 0 {} ⟨vf (bSl - 1), 15, key⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc) :=
    (congrArg Prod.fst hslDef).trans hSl
  have hSlEx := stSlotsProveFixedProg_extract Lq hL20 key P (incElog V.pub 14) _ Fp2.zero Fp2.zero Fp2.zero
    (fun _ => default) vf 4 (!incAlphaBad (incCtx V.pub ch)) [] 0 {} ⟨vf (bSl - 1), 15, key⟩ bSl sps recs acc rfl rfl hSlVal
  obtain ⟨hNotBad, hspsLen, hrecsLen, _, hcsLen, _, _, _, _, _, hexDfs⟩ := hSlEx
  have hbadF : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch) = false := by
    change (!incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch)) = true at hNotBad
    cases hb : incAlphaBad (incCtx (shdP_incPub Rp embDigest (embFoldL Rp.inp)) ch)
    · rfl
    · rw [hb] at hNotBad; cases hNotBad
  let dfs := Classical.choose hexDfs
  let vals := Classical.choose (Classical.choose_spec hexDfs)
  let accs := Classical.choose (Classical.choose_spec (Classical.choose_spec hexDfs))
  have hDfsSpec := Classical.choose_spec (Classical.choose_spec (Classical.choose_spec hexDfs))
  simp only [hSl, hA, hH, Option.isSome_some, Bool.and_true] at hmDef haDef hhDef heDef
  let clH := acc.claims.h ++ [V.lay.logupSumClaim]
  rw [hAct4] at hmDef
  have hmOEq := (congrArg Prod.fst hmDef).symm.trans
    (zkBMaskFixedProg_res_eq Lq hL20 key (shdP_incM (shdIncRndOf c)) 4
      (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)) (acc.fs ++ acc.hostFs) slR.2 (fun _ => default) vf (bSl + 167))
  have haRes := openingAuditFixedProg_res_eq Lq hL20 key shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V)
    (shdP_incTA x (shdIncRndOf c)) (levelsOfV vf 14 (4104 + 131071 + 5)) true
    (openingHdrOk (shdP_incOpenGeomA V) 12 acc.claims.a) acc.claims.a mR.2 (fun _ => default) vf (bSl + 167 + 77)
  rw [hAct4] at haDef
  rw [(congrArg Prod.fst haDef).trans hA] at haRes; dsimp only at haRes
  obtain ⟨haPass, haOEq⟩ := openingAudit_some_extract haRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at haPass
  have haudA : auditClaims acc.claims.a (2 ^ 12) 41 (List.range' 33 6) none 39 = .ok () := by
    have h0 := auditClaims_ok_of_openingHdrOk haPass.1.1.1.2
    simpa only [shdP_incOpenGeomA, V, hAR, hAS, hAP] using h0
  have hDetA :
      (Exec.Block.det
        (((List.range 41).map (fun j => challengeFp2Of (vf (bSl + 167 + 77 + 3 + j)))).getD 39 Fp2.zero)
        (((List.range 41).map (fun j => challengeFp2Of (vf (bSl + 167 + 77 + 3 + j)))).getD 40 Fp2.zero)).v ≠ 0 := by
    have h0 := det_ne_zero_of_openingAuditOk haPass.2
    simpa only [shdP_incOpenGeomA, V, hAR, hAP] using h0
  have hSumA : ((groupZclaims (acc.claims.a.map toZClaim) 41 12).map (fun x => x.2.length)).sum = 3 := by
    simpa only [pGroups, shdP_incTA_rows_len, shdP_stgPrm] using haPass.1.1.2
  have hhRes := openingAuditFixedProg_res_eq Lq hL20 key shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V)
    (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)) true
    (openingHdrOk (shdP_incOpenGeomH V) 12 clH) clH aR.2 (fun _ => default) vf (bSl + 167 + 77 + 112)
  rw [hAct4] at hhDef
  rw [(congrArg Prod.fst hhDef).trans hH] at hhRes; dsimp only at hhRes
  obtain ⟨hhPass, hhOEq⟩ := openingAudit_some_extract hhRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hhPass
  have haudH : auditClaims clH (2 ^ 12) 76 (List.range' 68 6) (some (66, 67)) 74 = .ok () := by
    have h0 := auditClaims_ok_of_openingHdrOk hhPass.1.1.1.2
    simpa only [shdP_incOpenGeomH, V, hHR, hHS, hHU, hHP] using h0
  have hLenH : clH.length = 4 :=
    auditClaims_length_some_last acc.claims.h V.lay.logupSumClaim
      (List.all_eq_true.mpr fun p hp => List.isEmpty_iff.mpr ((shdP_inc_logupSumClaim_shape tag Rp embDigest bInRow).2.2 p hp).1)
      (2 ^ 12) 76 68 3 66 67 74 (by omega) haudH
  have hDetH :
      (Exec.Block.det
        (((List.range 76).map (fun j => challengeFp2Of (vf (bSl + 167 + 77 + 112 + 4 + j)))).getD 74 Fp2.zero)
        (((List.range 76).map (fun j => challengeFp2Of (vf (bSl + 167 + 77 + 112 + 4 + j)))).getD 75 Fp2.zero)).v ≠ 0 := by
    have h0 := det_ne_zero_of_openingAuditOk hhPass.2
    simpa only [shdP_incOpenGeomH, V, hHR, hHP] using h0
  have hSumH : ((groupZclaims (clH.map toZClaim) 76 12).map (fun x => x.2.length)).sum = 4 := by
    simpa only [pGroups, shdP_incTH_rows_len, shdP_stgPrm] using hhPass.1.1.2
  have heRes := openingAuditFixedProg_res_eq Lq hL20 key shdP_epPrm 11 1 6 1 shdP_epOpenGeom
    (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) (levelsOfV vf 11 0) true
    (tokenEpHdrOk acc.claims.inp 1 256) acc.claims.inp hR.2 (fun _ => default) vf (bSl + 167 + 77 + 112 + 149)
  rw [hAct4] at heDef
  rw [(congrArg Prod.fst heDef).trans hE] at heRes; dsimp only at heRes
  obtain ⟨hePass, heOEq⟩ := openingAudit_some_extract heRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hePass
  have hSlInd : ∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig),
      ((stSlotsProveFixedProg Lq' hL20' key' P (incElog V.pub 14) _ Fp2.zero Fp2.zero Fp2.zero 4
        true [] 0 {} ⟨vf (bSl - 1), 15, key'⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc) := fun hL20' key' =>
    stSlotsProve_res_of_act_eq hNotBad
      ((stSlotsProveFixedProg_res_indep_key hL20' hL20 key' key P (incElog V.pub 14) _ Fp2.zero Fp2.zero Fp2.zero vf 4 _ [] 0 {} _ _ bSl).trans hSlVal)
  exact
    { ch := ch, ch_eq := rfl, hbad := hbadF, sps := sps, recs := recs, acc := acc,
      dfs := dfs, accs := accs, mO := mR.1, aO := aO, hO := hO, eO := eO,
      sps_len := hspsLen, recs_len := hrecsLen, cs_len := hcsLen,
      sl_res := hSlInd le_rfl none,
      slot_spec := fun t => by
        have ht := hDfsSpec.1 t
        dsimp only at ht
        simp only [Nat.zero_add] at ht
        refine ⟨ht.1, ht.2.1, ht.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.1, ?_, ht.2.2.2.2.2.2.2.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.2.2.2⟩
        exact ht.2.2.2.2.2.2.2.2.2.2.2.1.trans (scProve_zero_add hL20 key _ _ _ _ _ _ _ _ _ vf _)
      fs_terms := by
        rw [List.map_append, hDfsSpec.2.1, hDfsSpec.2.2]; simp only [Nat.zero_add]; rfl
      mO_eq := hmOEq, haudA := haudA, hDetA := hDetA, hSumA := hSumA, aO_eq := haOEq,
      haudH := haudH, hLenH := hLenH, hDetH := hDetH, hSumH := hSumH, hO_eq := hhOEq,
      hhdrE := hePass.1.1.1.2, hDetE := det_ne_zero_of_openingAuditOk hePass.2, eO_eq := heOEq,
      out_eq := fun {Lq'} hL20' key' => by
        dsimp only
        obtain ⟨slR', hsl'⟩ : ∃ slR', (stSlotsProveFixedProg Lq' hL20' key' P (incElog V.pub 14)
            (shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
              (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
              (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
            Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub ch)) [] 0 {} ⟨vf (bSl - 1), 15, key'⟩).res (fun _ => default) vf bSl = slR' := ⟨_, rfl⟩
        obtain ⟨mR', hm'⟩ : ∃ mR', (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
            (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
            (shdP_incM (shdIncRndOf c)) 4 (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3))
            (match slR'.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR'.2).res (fun _ => default) vf (bSl + 167) = mR' := ⟨_, rfl⟩
        obtain ⟨aR', ha'⟩ : ∃ aR', (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V)
            (shdP_incTA x (shdIncRndOf c)) (levelsOfV vf 14 (4104 + 131071 + 5))
            (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false)
            (openingHdrOk (shdP_incOpenGeomA V) 12 (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []))
            (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []) mR'.2).res (fun _ => default) vf (bSl + 167 + 77) = aR' := ⟨_, rfl⟩
        obtain ⟨hR', hh'⟩ : ∃ hR', (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V)
            (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15))
            ((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR'.1.isSome)
            (openingHdrOk (shdP_incOpenGeomH V) 12 (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
            (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aR'.2).res (fun _ => default) vf (bSl + 167 + 77 + 112) = hR' := ⟨_, rfl⟩
        obtain ⟨eR', he'⟩ : ∃ eR', (openingAuditFixedProg Lq' hL20' key' shdP_epPrm 11 1 6 1 shdP_epOpenGeom
            (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) (levelsOfV vf 11 0)
            (((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals) | none => false) && aR'.1.isSome) && hR'.1.isSome)
            (tokenEpHdrOk (match slR'.1 with | some (_, _, acc) => acc.claims.inp | none => []) 1 256)
            (match slR'.1 with | some (_, _, acc) => acc.claims.inp | none => []) hR'.2).res (fun _ => default) vf (bSl + 167 + 77 + 112 + 149) = eR' := ⟨_, rfl⟩
        rw [hEv hL20' key' slR' hsl' mR' hm' aR' ha' hR' hh' eR' he']
        have hSlSame : slR'.1 = some (sps, recs, acc) :=
          (congrArg Prod.fst hsl').symm.trans (stSlotsProve_res_of_act_eq hNotBad.symm (hSlInd hL20' key'))
        simp only [hSlSame, hAct4] at hm' ha' hh' he' ⊢
        have hmSame : mR'.1 = mR.1 := by
          rw [← hm', zkBMaskFixedProg_res_eq]; exact hmOEq.symm
        have haSame : aR'.1 = some aO := by
          rw [← ha', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact haPass), haOEq]
        simp only [haSame, Option.isSome_some, Bool.and_true] at hh' he' ⊢
        have hhSame : hR'.1 = some hO := by
          rw [← hh', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact hhPass), hhOEq]
        simp only [hhSame, Option.isSome_some, Bool.and_true] at he' ⊢
        have heSame : eR'.1 = some eO := by
          rw [← he', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact hePass), heOEq]
        rw [heSame, hmSame]; rfl }

/-- Two active `IncSegTrace`s at the same `vf` have identical `ch`, `dfs`, `acc.claims.*.map parts`,
and `(acc.fs ++ acc.hostFs).map terms`! -/
theorem incSegTrace_invar {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x₁ x₂ : shieldS0.Tok → ℕ) (c₁ c₂ : ShdCoins) (vf : ℕ → Dig)
    (T₁ : IncSegTrace (Hdr := Hdr) tag Rp embDigest bInRow x₁ c₁ vf)
    (T₂ : IncSegTrace (Hdr := Hdr) tag Rp embDigest bInRow x₂ c₂ vf) :
    T₁.ch = T₂.ch
      ∧ T₁.dfs = T₂.dfs
      ∧ T₁.acc.claims.a.map Block.ZClaim.parts = T₂.acc.claims.a.map Block.ZClaim.parts
      ∧ T₁.acc.claims.h.map Block.ZClaim.parts = T₂.acc.claims.h.map Block.ZClaim.parts
      ∧ T₁.acc.claims.inp.map Block.ZClaim.parts = T₂.acc.claims.inp.map Block.ZClaim.parts
      ∧ T₁.acc.claims.out.map Block.ZClaim.parts = T₂.acc.claims.out.map Block.ZClaim.parts
      ∧ (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
  have hCh : T₁.ch = T₂.ch := T₁.ch_eq.trans T₂.ch_eq.symm
  have hDr : ∀ t : Fin 4, (T₁.recs[t.val]'(by rw [T₁.recs_len]; exact t.isLt)).draws = (T₂.recs[t.val]'(by rw [T₂.recs_len]; exact t.isLt)).draws := fun t => by
    have h1 := (T₁.slot_spec t).2.2.1; have h2 := (T₂.slot_spec t).2.2.1; rw [h1, h2, hCh]
  have hHist : ∀ m ≤ 4, (T₁.recs.take m).map SlotRec.draws = (T₂.recs.take m).map SlotRec.draws := fun m hm => by
    refine List.ext_getElem (by simp [T₁.recs_len, T₂.recs_len, hm]) fun i hi1 hi2 => ?_
    simp only [List.getElem_map, List.getElem_take]
    exact hDr ⟨i, by simp [T₁.recs_len] at hi1; omega⟩
  have hDfs : T₁.dfs = T₂.dfs := funext fun t => by
    have h1 := (T₁.slot_spec t).2.1; have h2 := (T₂.slot_spec t).2.1
    have hHistEq : Exec.Block.histOf Fp2.zero Fp2.zero Fp2.zero (T₁.recs.take t.val)
        = Exec.Block.histOf Fp2.zero Fp2.zero Fp2.zero (T₂.recs.take t.val) := by
      unfold Exec.Block.histOf; rw [hHist t.val (Nat.le_of_lt t.isLt)]
    rw [hCh, hHistEq] at h1
    exact Except.ok.inj (h1.symm.trans h2)
  have hFs : (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
      = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
    rw [T₁.fs_terms, T₂.fs_terms, hCh, hDfs]
    exact congrArg (_ ++ ·) (List.filterMap_congr fun t _ => by
      have hk := (inc_slotShape_eq_L2 tag Rp embDigest bInRow T₂.ch t).2.2
      rw [hk])
  have hStShape := stSlotsProveFixedProg_shape_indep (2 ^ 20) le_rfl none
    ((shdVi tag Rp embDigest bInRow).bp (incCtx (shdVi tag Rp embDigest bInRow).pub T₁.ch))
    (incElog (shdVi tag Rp embDigest bInRow).pub 14)
    (shdP_incSlotData tag Rp embDigest bInRow T₁.ch (shdP_incTA x₁ (shdIncRndOf c₁))
      (shdP_incTH Rp embDigest x₁ (shdIncRndOf c₁) T₁.ch) (shdP_epTable (Hdr := Hdr) tag x₁ (shdEpBase c₁))
      (shdP_incTB Rp x₁ (shdIncRndOf c₁)) (shdIncRndOf c₁))
    (shdP_incSlotData tag Rp embDigest bInRow T₁.ch (shdP_incTA x₂ (shdIncRndOf c₂))
      (shdP_incTH Rp embDigest x₂ (shdIncRndOf c₂) T₁.ch) (shdP_epTable (Hdr := Hdr) tag x₂ (shdEpBase c₂))
      (shdP_incTB Rp x₂ (shdIncRndOf c₂)) (shdIncRndOf c₂))
    Fp2.zero Fp2.zero Fp2.zero (fun _ => default) vf 4 true [] [] 0 {} {}
    ⟨vf ((4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3) - 1), 15, none⟩
    (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15 + 32767 + 3)
    rfl ⟨rfl, rfl, rfl, rfl, ⟨rfl, rfl, rfl, rfl⟩⟩
  dsimp only at hStShape
  have hS1 := T₁.sl_res
  have hS2 := T₂.sl_res
  dsimp only at hS1 hS2
  rw [← hCh] at hS2
  rw [hS1, hS2] at hStShape
  have hAccEq : AccShapeEq T₁.acc T₂.acc := hStShape.2
  exact ⟨hCh, hDfs, hAccEq.2.2.2.2.1, hAccEq.2.2.2.2.2.1, hAccEq.2.2.2.2.2.2.1, hAccEq.2.2.2.2.2.2.2, hFs⟩


/-- Helper: `slotsProveFixedProg.res.1` is independent of `(Lq, hL20, key, t)`. -/
theorem slotsProveFixedProg_res_indep_key {Lq₁ Lq₂ : ℕ} (h1 : 2 ^ 20 ≤ Lq₁) (h2 : 2 ^ 20 ≤ Lq₂)
    (key₁ key₂ : Option Dig) (P : BlockParams) (D : SlotData P) (b g a : Fp2) (vf : ℕ → Dig) :
    ∀ (m : ℕ) (act : Bool) (rs : List SlotRec) (s0 : ℕ) (a0 : Acc) (t₁ t₂ : Tr) (base : ℕ),
      ((slotsProveFixedProg Lq₁ h1 key₁ P D b g a m act rs s0 a0 t₁).res (fun _ => default) vf base).1
        = ((slotsProveFixedProg Lq₂ h2 key₂ P D b g a m act rs s0 a0 t₂).res (fun _ => default) vf base).1
  | 0, _, _, _, _, _, _, _ => rfl
  | m + 1, act, rs, s0, a0, t₁, t₂, base => by
    simp only [slotsProveFixedProg]
    refine res_fst_andThen_rel₂_fst
      (slotProveFixedProg_ptLen Lq₁ h1 key₁ P D s0 act _ a0 t₁)
      (slotProveFixedProg_ptLen Lq₂ h2 key₂ P D s0 act _ a0 t₂)
      (slotProveFixedProg_res_indep_key h1 h2 key₁ key₂ P D s0 act _ a0 t₁ t₂ vf base)
      fun r₁ r₂ hr => ?_
    rcases r₁ with ⟨o₁, u₁⟩; rcases r₂ with ⟨o₂, u₂⟩
    dsimp only at hr; subst hr
    cases o₁ with
    | none =>
      refine res_fst_andThen_rel₂_true
        (slotsProveFixedProg_ptLen Lq₁ h1 key₁ P D b g a m false rs (s0 + 1) a0 u₁)
        (slotsProveFixedProg_ptLen Lq₂ h2 key₂ P D b g a m false rs (s0 + 1) a0 u₂)
        fun _ _ => rfl
    | some v1 =>
      refine res_fst_andThen_rel₂_fst
        (slotsProveFixedProg_ptLen Lq₁ h1 key₁ P D b g a m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₁)
        (slotsProveFixedProg_ptLen Lq₂ h2 key₂ P D b g a m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₂)
        (slotsProveFixedProg_res_indep_key h1 h2 key₁ key₂ P D b g a vf m true (rs ++ [v1.2.1]) (s0 + 1) v1.2.2 u₁ u₂ _)
        fun rest₁ rest₂ hrest => ?_
      rcases rest₁ with ⟨ro₁, _⟩; rcases rest₂ with ⟨ro₂, _⟩
      dsimp only at hrest; subst hrest; cases ro₁ <;> rfl

/-- Base point index in `[0, shdP_zkPts)` of interior block `k : Fin 26`. -/
def blkBase (k : Fin 26) : ℕ := 209507 + blkStepFixedLen * k.val

/-- Pure `vf`-driven interior R13 block `k : Fin 26` active trace at `(x, c, cr)`. -/
structure BlkSegTrace (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (vf : ℕ → Dig) where
  bga : Fp2 × Fp2 × Fp2
  bga_eq :
    let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
    bga = (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
  hbad : blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga = false
  sps : List SlotProof
  recs : List SlotRec
  acc : Acc
  dfs : Fin 23 → SlotDef
  accs : Fin 23 → Acc
  mO : Exec.Block.MaskOpening
  aO : Exec.Block.OpeningZk
  hO : Exec.Block.OpeningZk
  bO : Exec.Block.OpeningZk
  sps_len : sps.length = 23
  recs_len : recs.length = 23
  cs_len : acc.cs.length = 23
  sl_res :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    let rnd := shdBlkRndOf c k
    let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
    let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
    let D := blkSlotData P w (blkTA w rnd) TBprev TBnext rnd
    ((slotsProveFixedProg (2 ^ 20) le_rfl none P D bga.1 bga.2.1 bga.2.2 23
      true [] 0 {} ⟨vf (bSl - 1), 3, none⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc)
  slot_spec : ∀ t : Fin 23,
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    let rnd := shdBlkRndOf c k
    let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
    let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
    let D := blkSlotData P w (blkTA w rnd) TBprev TBnext rnd
    let bj := bSl + slotsFixedLen P 0 t.val
    let dr := (List.range (P.draws t.val)).map (fun j => challengeFp2Of (vf (bj + j)))
    let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
    let scBase := bj + P.draws t.val + 3
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
    let rho := rhoFull.take (Exec.Block.slotShape P t.val).1
    let es := rhoFull.drop (Exec.Block.slotShape P t.val).1
    let hist := Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (recs.take t.val)
    ch0.isZero = false
    ∧ P.define t.val hist dr = .ok (dfs t)
    ∧ (accs t).cs = acc.cs.take t.val
    ∧ (recs[t.val]'(by omega)).draws = dr
    ∧ (acc.cs[t.val]'(by omega)) = ch0
    ∧ (sps[t.val]'(by omega)).scalar = D.scalar t.val hist (accs t) (dfs t) ch0
    ∧ (sps[t.val]'(by omega)).rounds =
        ((scProveFixedProg (2 ^ 20) le_rfl none (slotN P t.val) true (D.strat t.val hist (accs t) (dfs t) ch0)
          ⟨vf (bj + P.draws t.val + 2), 0, none⟩).res (fun _ => default) vf scBase).1
    ∧ (sps[t.val]'(by omega)).terms = D.terms t.val hist (accs t) (dfs t) ch0 rhoFull
    ∧ (∀ p, Tab.priv p ∈ (dfs t).tabs →
        let z0 := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
          (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
        match p.cm with
        | .a => ∃ z ∈ acc.claims.a, z.parts = z0.parts
        | .h => ∃ z ∈ acc.claims.h, z.parts = z0.parts
        | .inp => ∃ z ∈ acc.claims.inp, z.parts = z0.parts
        | .out => ∃ z ∈ acc.claims.out, z.parts = z0.parts)
  fs_terms : (acc.fs ++ acc.hostFs).map Exec.Block.MaskFunctional.terms =
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
    (List.finRange 23).flatMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      let ev := [(t.val, Cfs.evalWeights rhoFull nd.2.2)]
      match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
    ++ (List.finRange 23).filterMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      match P.kind t.val with
      | .host =>
        some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
          (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
            (Exec.Block.slotShape P hk.1).2.2).map
              (fun w => w.mul (hk.2.mul ((accs t).cs.getD hk.1 Fp2.zero)).neg)))
      | _ => none)
  mO_eq :
    let bMo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283
    let θ := challengeFp2Of (vf bMo)
    let rs := (List.range (2 * 23 + 2)).map (fun j => challengeFp2Of (vf (bMo + 2 + j)))
    let sq := (List.range 64).map (fun j => vf (bMo + 2 + (2 * 23 + 2) + 1 + j))
    let idxs := idxOf mDom mQ sq
    let M := blkTM (shdBlkRndOf c k)
    let treeM := levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)
    mO = ⟨polyWords shdP_U shdP_hbij (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M 23 ((acc.fs ++ acc.hostFs).map toMF) (θ.toK shdP_U)),
          polyWords shdP_U shdP_hbij (pPoly shdP_U M 23 rs),
          idxs.map (fun j => ofOCol (j, mCol 23 (cosetPt (rootFp 12)) M j, M.salts j, treeM.pathD j))⟩
  haudA : auditClaims acc.claims.a (2 ^ 14) 4577 (List.range' 4283 292) none 4575 = .ok ()
  hDetA :
    let bAo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115
    let proxR := (List.range 4577).map (fun j => challengeFp2Of (vf (bAo + 146 + j)))
    (Exec.Block.det (proxR.getD 4575 Fp2.zero) (proxR.getD 4576 Fp2.zero)).v ≠ 0
  hSumA : ((groupZclaims (acc.claims.a.map toZClaim) 4577 14).map (fun x => x.2.length)).sum = 146
  aO_eq :
    let bAo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115
    let lams := (List.range 146).map (fun j => challengeFp2Of (vf (bAo + j)))
    let proxR := (List.range 4577).map (fun j => challengeFp2Of (vf (bAo + 146 + j)))
    let sq := (List.range 64).map (fun j => vf (bAo + 146 + 4577 + 36 + 1 + j))
    let idxs := idxOf Exec.R13.r13Prm.nn Exec.R13.r13Prm.nQ sq
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    let TA := blkTA w (shdBlkRndOf c k)
    let treeA := levelsOfV vf 16 (blkBase k + 131071 + 5)
    aO = ⟨(groupRhosAux 4577 (pGroups Exec.R13.r13Prm TA (acc.claims.a.map toZClaim)) lams).map
            (fun rho => combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) rho TA.rows),
          combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) proxR TA.rows,
          idxs.map (fun j => ofOCol (j, TA.cols j, TA.salts j, treeA.pathD j))⟩
  haudH :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let clH := acc.claims.h ++ [P.logupSumClaim]
    auditClaims clH (2 ^ 14) 4390 (List.range' 4282 106) (some (4280, 4281)) 4388 = .ok ()
  hLenH :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    (acc.claims.h ++ [P.logupSumClaim]).length = 54
  hDetH :
    let bHo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824
    let proxR := (List.range 4390).map (fun j => challengeFp2Of (vf (bHo + 54 + j)))
    (Exec.Block.det (proxR.getD 4388 Fp2.zero) (proxR.getD 4389 Fp2.zero)).v ≠ 0
  hSumH :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let clH := acc.claims.h ++ [P.logupSumClaim]
    ((groupZclaims (clH.map toZClaim) 4390 14).map (fun x => x.2.length)).sum = 54
  hO_eq :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    let bHo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824
    let lams := (List.range 54).map (fun j => challengeFp2Of (vf (bHo + j)))
    let proxR := (List.range 4390).map (fun j => challengeFp2Of (vf (bHo + 54 + j)))
    let sq := (List.range 64).map (fun j => vf (bHo + 54 + 4390 + 9 + 1 + j))
    let idxs := idxOf Exec.R13.r13Prm.nn Exec.R13.r13Prm.nQ sq
    let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
    let TH := blkTH w (shdBlkRndOf c k) bga
    let treeH := levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)
    let clH := acc.claims.h ++ [P.logupSumClaim]
    hO = ⟨(groupRhosAux 4390 (pGroups Exec.R13.r13Prm TH (clH.map toZClaim)) lams).map
            (fun rho => combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) rho TH.rows),
          combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) proxR TH.rows,
          idxs.map (fun j => ofOCol (j, TH.cols j, TH.salts j, treeH.pathD j))⟩
  haudB : auditClaims (cr.pending ++ acc.claims.inp) (2 ^ 14) 38 (List.range' 32 4) none 36 = .ok ()
  hDetB :
    let bBo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824 + 4518
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bBo + 2 + j)))
    (Exec.Block.det (proxR.getD 36 Fp2.zero) (proxR.getD 37 Fp2.zero)).v ≠ 0
  hSumB : ((groupZclaims ((cr.pending ++ acc.claims.inp).map toZClaim) 38 14).map (fun x => x.2.length)).sum = 2
  bO_eq :
    let bBo := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3 + 1283 + 115 + 4824 + 4518
    let lams := (List.range 2).map (fun j => challengeFp2Of (vf (bBo + j)))
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bBo + 2 + j)))
    let sq := (List.range 64).map (fun j => vf (bBo + 2 + 38 + 2 + 1 + j))
    let idxs := idxOf Exec.R13.r13Prm.nn Exec.R13.r13Prm.nQ sq
    let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
    let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
    bO = ⟨(groupRhosAux 38 (pGroups Exec.R13.r13Prm TBprev ((cr.pending ++ acc.claims.inp).map toZClaim)) lams).map
            (fun rho => combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) rho TBprev.rows),
          combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) proxR TBprev.rows,
          idxs.map (fun j => ofOCol (j, TBprev.cols j, TBprev.salts j, treeBPrev.pathD j))⟩
  out_eq : ∀ {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
      (blkDig : Fin 26 → Dig) (startTag : Dig) (t : Tr),
    ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c k true cr (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))) (vf 4101) startTag t).res (fun _ => default) vf (blkBase k)).1
      = some (fun e => Exec.Block.encSeg (vf 4101)
          (Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2).l
          (Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2).k
          startTag
          ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
            ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
             (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
             (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
             sps, mO, aO, hO⟩, bO, none⟩ e,
        ⟨acc.claims.out, (levelsOfV vf 16 (blkBase k)).getRoot⟩)

private theorem blkSeg_eval_half1 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams) (stageIdx : ℕ) (blkDig : Dig)
    (labB labA : List UInt8) (hlabB : labB.length ≤ 64) (hlabA : labA.length ≤ 64)
    (TBnext TA : Table) (hTBnc : ∀ j : Fin (2 ^ 16), (TBnext.cols j.val).length = 38)
    (hTAc : ∀ j : Fin (2 ^ 16), (TA.cols j.val).length = 4577) (M : MTable)
    (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    {β γ : Type}
    (cont : MerkleLevels 16 → MerkleLevels 16 → Tr → MerkleLevels 12 → PProg (QB Lq) Dig (β × γ)) :
    let treeBNext := levelsOfV vf 16 base
    let treeA := levelsOfV vf 16 (base + 131071 + 5)
    let tA : Tr := Tr.mk (vf (base + 131071 + 5 + 131071 + 2)) t.counter key
    let treeM := levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)
    (((merkleTableProg Lq (by omega) tag 16 38 (by omega) TBnext hTBnc).andThen fun treeBNext =>
      (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat stageIdx))).andThen fun tf1 =>
        (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) blkDig.toList).andThen fun tf2 =>
          (absorbRootKeyed Lq hL20 key tf2 labB hlabB treeBNext.getRoot 38 14).andThen fun tFrame =>
            (merkleTableProg Lq (by omega) tag 16 4577 (by omega) TA hTAc).andThen fun treeA =>
              (absorbRootKeyed Lq hL20 key tFrame labA hlabA treeA.getRoot P.aRows P.logCols).andThen fun tA =>
                (merkleTableProg Lq (by omega) tag 12 (2 * 23 + 4) (by omega) (mTab 23 (cosetPt (rootFp 12)) M)
                    (fun j => mCol_length 23 _ M j.val)).andThen fun treeM =>
                  cont treeBNext treeA tA treeM).res (fun _ => default) vf base).1
    = ((cont treeBNext treeA tA treeM).res (fun _ => default) vf (base + 131071 + 5 + 131071 + 3 + 8191)).1 := by
  intro treeBNext treeA tA treeM
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _)
    (congrArg (base + ·) (by decide : 2 ^ 16 + (2 ^ 16 - 1) = 131071))
    (merkleTableProg_res Lq (by omega) tag 16 38 (by omega) _ _ _ vf base) ?_
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) rfl
    (trAbsorbKeyed_res Lq hL20 key _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) rfl
    (trAbsorbKeyed_res Lq hL20 key _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _)
    (by omega : base + 131071 + 1 + 1 + 3 = base + 131071 + 5)
    (absorbRootKeyed_res Lq hL20 key _ _ _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _)
    (congrArg (base + 131071 + 5 + ·) (by decide : 2 ^ 16 + (2 ^ 16 - 1) = 131071))
    (merkleTableProg_res Lq (by omega) tag 16 4577 (by omega) _ _ _ vf _) ?_
  refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) rfl
    (a := tA) ?_ ?_
  · rw [absorbRootKeyed_res]
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 12 (2 * 23 + 4) (by omega) _ _)
    (congrArg (base + 131071 + 5 + 131071 + 3 + ·) (by decide : 2 ^ 12 + (2 ^ 12 - 1) = 8191))
    (merkleTableProg_res Lq (by omega) tag 12 (2 * 23 + 4) (by omega) _ _ _ vf _) ?_
  rfl

private theorem blkSeg_eval_half2 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (labM : List UInt8) (hlabM : labM.length ≤ 64)
    (sA : Dig) (cA : UInt64) (treeM : MerkleLevels 12)
    (TH : Fp2 × Fp2 × Fp2 → Table) (hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390)
    (vf : ℕ → Dig) (bM : ℕ)
    {β γ : Type}
    (cont : Fp2 → Fp2 → Fp2 → Tr → MerkleLevels 16 → PProg (QB Lq) Dig (β × γ)) :
    let bM1 := bM + 1
    let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
    let tCh : Tr := Tr.mk (vf (bM1 + 2)) (cA + 3) key
    let treeH := levelsOfV vf 16 (bM1 + 3)
    (((trAbsorbKeyed Lq hL20 key (Tr.mk sA cA key) labM hlabM treeM.getRoot.toList).andThen fun tM =>
      (trChallengeFp2Keyed Lq (by omega) key tM).andThen fun bR =>
        (trChallengeFp2Keyed Lq (by omega) key bR.2).andThen fun gR =>
          (trChallengeFp2Keyed Lq (by omega) key gR.2).andThen fun aR =>
            let bga := (bR.1, gR.1, aR.1)
            (merkleTableProg Lq (by omega) tag 16 4390 (by omega) (TH bga) (hTHc bga)).andThen fun treeH =>
              cont bR.1 gR.1 aR.1 aR.2 treeH).res (fun _ => default) vf bM).1
    = ((cont bga.1 bga.2.1 bga.2.2 tCh treeH).res (fun _ => default) vf (bM1 + 3 + 131071)).1 := by
  intro bM1 bga tCh treeH
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (rfl : _ = bM1)
    (a := Tr.mk (vf bM) cA key) ?_ ?_
  · rw [trAbsorbKeyed_res]
  refine res_fst_andThen_step (trChallengeFp2Keyed_ptLen Lq (by omega) key _) rfl
    (trChallengeFp2Keyed_res Lq (by omega) key _ _ vf bM1) ?_
  refine res_fst_andThen_step (trChallengeFp2Keyed_ptLen Lq (by omega) key _)
    (by omega : bM1 + 1 + 1 = bM1 + 2)
    (trChallengeFp2Keyed_res Lq (by omega) key _ _ vf (bM1 + 1)) ?_
  refine res_fst_andThen_step (trChallengeFp2Keyed_ptLen Lq (by omega) key _) rfl
    (a := (bga.2.2, tCh)) ?_ ?_
  · rw [trChallengeFp2Keyed_res]
    exact congrArg (fun ctr => (bga.2.2, Tr.mk (vf (bM1 + 2)) ctr key)) (uint64_add_1_1_1 cA)
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _)
    (congrArg (bM1 + 3 + ·) (by decide : 2 ^ 16 + (2 ^ 16 - 1) = 131071))
    (merkleTableProg_res Lq (by omega) tag 16 4390 (by omega) _ _ _ vf _) ?_
  rfl

private theorem blkSeg_eval_half3 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (P : BlockParams) (labH : List UInt8) (hlabH : labH.length ≤ 64)
    (TA TH TBprev : Table) (M : MTable) (Dslot : SlotData P) (hSlLen : slotsFixedLen P 0 23 = 1283)
    (sg : SegGeom) (active1 : Bool) (cr : Carry)
    (treeBPrev treeBNext treeA : MerkleLevels 16) (treeM : MerkleLevels 12) (treeH : MerkleLevels 16)
    (bga : Fp2 × Fp2 × Fp2) (sCh : Dig) (cCh : UInt64) (bnd startTag : Dig) (vf : ℕ → Dig) (bH : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let bSl := bH + 3
      (slotsProveFixedProg Lq hL20 key P Dslot bga.1 bga.2.1 bga.2.2 23 active1 [] 0 {}
        ⟨vf (bSl - 1), cCh, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := bH + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        M 23 treeM
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 1283) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA treeA
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        (openingHdrOk shdP_blkOpenGeomA 14 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 1283 + 115) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH treeH
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome)
        (openingHdrOk shdP_blkOpenGeomH 14 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res
        (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR) :
    (((absorbRootKeyed Lq hL20 key (Tr.mk sCh cCh key) labH hlabH treeH.getRoot P.hRows P.logCols).andThen fun t3 =>
      (slotsProveFixedProg Lq hL20 key P Dslot bga.1 bga.2.1 bga.2.2 23 active1 [] 0 {} t3).andThen fun slR =>
        let active2 := match slR.1 with
          | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals)
          | none => false
        let fs := match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []
        (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 23 treeM fs slR.2).andThen fun mR =>
          let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
          (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
              shdP_blkOpenGeomA TA treeA active2 (openingHdrOk shdP_blkOpenGeomA 14 clA) clA mR.2).andThen fun aOR =>
            let active3 := active2 && aOR.1.isSome
            let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []
            (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
                shdP_blkOpenGeomH TH treeH active3 (openingHdrOk shdP_blkOpenGeomH 14 clH) clH aOR.2).andThen fun hOR =>
              let active4 := active3 && hOR.1.isSome
              let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
              (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                  shdP_bndOpenGeom TBprev treeBPrev active4 (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                match slR.1, aOR.1, hOR.1, bOR.1 with
                | some (sps, _, acc), some aO, some hO, some bO =>
                  if active4 then
                    let core : Exec.Block.Core := ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩
                    let seg : Segment := ⟨some treeBNext.getRoot, core, bO, none⟩
                    .ret (some (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
                      Carry.mk acc.claims.out treeBNext.getRoot), treeBNext, bOR.2)
                  else .ret (none, treeBNext, bOR.2)
                | _, _, _, _ => .ret (none, treeBNext, bOR.2)).res (fun _ => default) vf bH).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, acc), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let core : Exec.Block.Core := ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩
          let seg : Segment := ⟨some treeBNext.getRoot, core, bO, none⟩
          (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
           Carry.mk acc.claims.out treeBNext.getRoot))
      else none
    | _, _, _, _ => none := by
  let bSl := bH + 3
  refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (rfl : _ = bSl)
    (a := Tr.mk (vf (bSl - 1)) cCh key) ?_ ?_
  · rw [absorbRootKeyed_res]
    exact congrArg (fun idx => Tr.mk (vf idx) cCh key) (Nat.add_sub_assoc (by decide : 1 ≤ 3) _).symm
  refine res_fst_andThen_step ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr hSlLen)
    rfl hsl ?_
  refine res_fst_andThen_step (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _)
    (congrArg (bSl + 1283 + ·) (by decide : zkBMaskFixedLen 23 = 115))
    hm ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _)
    (congrArg (bSl + 1283 + 115 + ·) (by decide : openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ = 4824))
    ha ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _)
    (congrArg (bSl + 1283 + 115 + 4824 + ·) (by decide : openingAuditFixedLen 54 4390 9 Exec.R13.r13Prm.nQ = 4518))
    hh ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ _ _ _ _ _)
    rfl hb ?_
  rcases slR with ⟨_ | ⟨sps, recs, acc⟩, tSl⟩ <;> rcases aOR with ⟨_ | aO, tA⟩ <;>
    rcases hOR with ⟨_ | hO, tH⟩ <;> rcases bOR with ⟨_ | bO, tB⟩
  all_goals first
    | rfl
    | (dsimp only [Option.isSome_some, Bool.and_true]
       split_ifs <;> rfl)

private noncomputable def blkTailProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (P : BlockParams) (labH : List UInt8) (hlabH : labH.length ≤ 64)
    (TA TBprev : Table) (M : MTable) (TH : Fp2 × Fp2 × Fp2 → Table)
    (Dslot : SlotData P) (sg : SegGeom) (active1Fn : Fp2 × Fp2 × Fp2 → Bool)
    (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig)
    (treeBNext treeA : MerkleLevels 16) (treeM : MerkleLevels 12)
    (b g a : Fp2) (tCh : Tr) (treeH : MerkleLevels 16) :=
  (absorbRootKeyed Lq hL20 key tCh labH hlabH treeH.getRoot P.hRows P.logCols).andThen fun t3 =>
    (slotsProveFixedProg Lq hL20 key P Dslot b g a 23 (active1Fn (b, g, a)) [] 0 {} t3).andThen fun slR =>
      let active2 := match slR.1 with
        | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals)
        | none => false
      let fs := match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 23 treeM fs slR.2).andThen fun mR =>
        let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
        (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
            shdP_blkOpenGeomA TA treeA active2 (openingHdrOk shdP_blkOpenGeomA 14 clA) clA mR.2).andThen fun aOR =>
          let active3 := active2 && aOR.1.isSome
          let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []
          (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
              shdP_blkOpenGeomH (TH (b, g, a)) treeH active3 (openingHdrOk shdP_blkOpenGeomH 14 clH) clH aOR.2).andThen fun hOR =>
            let active4 := active3 && hOR.1.isSome
            let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
            (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                shdP_bndOpenGeom TBprev treeBPrev active4 (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
              match slR.1, aOR.1, hOR.1, bOR.1 with
              | some (sps, _, acc), some aO, some hO, some bO =>
                if active4 then
                  let core : Exec.Block.Core := ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩
                  let seg : Segment := ⟨some treeBNext.getRoot, core, bO, none⟩
                  .ret (some (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
                    Carry.mk acc.claims.out treeBNext.getRoot), treeBNext, bOR.2)
                else .ret (none, treeBNext, bOR.2)
              | _, _, _, _ => .ret (none, treeBNext, bOR.2)

private noncomputable def blkMidProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams)
    (labM labH : List UInt8) (hlabM : labM.length ≤ 64) (hlabH : labH.length ≤ 64)
    (TA TBprev : Table) (M : MTable) (TH : Fp2 × Fp2 × Fp2 → Table)
    (hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390)
    (Dslot : SlotData P) (sg : SegGeom) (active1Fn : Fp2 × Fp2 × Fp2 → Bool)
    (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig)
    (treeBNext treeA : MerkleLevels 16) (tA : Tr) (treeM : MerkleLevels 12) :=
  (trAbsorbKeyed Lq hL20 key tA labM hlabM treeM.getRoot.toList).andThen fun tM =>
    (trChallengeFp2Keyed Lq (by omega) key tM).andThen fun bR =>
      (trChallengeFp2Keyed Lq (by omega) key bR.2).andThen fun gR =>
        (trChallengeFp2Keyed Lq (by omega) key gR.2).andThen fun aR =>
          let bga := (bR.1, gR.1, aR.1)
          (merkleTableProg Lq (by omega) tag 16 4390 (by omega) (TH bga) (hTHc bga)).andThen fun treeH =>
            blkTailProg Lq hL20 key P labH hlabH TA TBprev M TH Dslot sg active1Fn cr treeBPrev bnd startTag
              treeBNext treeA treeM bR.1 gR.1 aR.1 aR.2 treeH

private theorem blkSeg_eval_half3' (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (P : BlockParams)
    {labH : List UInt8} {hlabH : labH.length ≤ 64}
    (TA TBprev : Table) (M : MTable) (TH : Fp2 × Fp2 × Fp2 → Table)
    (Dslot : SlotData P) (hSlLen : slotsFixedLen P 0 23 = 1283)
    (sg : SegGeom) (active1Fn : Fp2 × Fp2 × Fp2 → Bool)
    (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (slotsProveFixedProg Lq hL20 key P Dslot bga.1 bga.2.1 bga.2.2 23 (active1Fn bga) [] 0 {}
        ⟨vf (bSl - 1), t.counter + 3, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        M 23 (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3))
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 1283) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
        (levelsOfV vf 16 (base + 131071 + 5))
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        (openingHdrOk shdP_blkOpenGeomA 14 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 1283 + 115) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH (TH bga)
        (levelsOfV vf 16 (base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome)
        (openingHdrOk shdP_blkOpenGeomH 14 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res
        (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR) :
    let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
    let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
    let tCh : Tr := Tr.mk (vf (bM1 + 2)) (t.counter + 3) key
    ((blkTailProg Lq hL20 key P labH hlabH TA TBprev M TH Dslot sg active1Fn cr treeBPrev bnd startTag
        (levelsOfV vf 16 base) (levelsOfV vf 16 (base + 131071 + 5)) (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3))
        bga.1 bga.2.1 bga.2.2 tCh (levelsOfV vf 16 (bM1 + 3))).res
      (fun _ => default) vf (bM1 + 3 + 131071)).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, acc), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let core : Exec.Block.Core := ⟨(levelsOfV vf 16 (base + 131071 + 5)).getRoot,
            (levelsOfV vf 16 (bM1 + 3)).getRoot,
            (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)).getRoot, sps, mR.1, aO, hO⟩
          let seg : Segment := ⟨some (levelsOfV vf 16 base).getRoot, core, bO, none⟩
          (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
           Carry.mk acc.claims.out (levelsOfV vf 16 base).getRoot))
      else none
    | _, _, _, _ => none := by
  dsimp only [blkTailProg]
  let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
  let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
  exact blkSeg_eval_half3 Lq hL20 key P labH hlabH TA (TH bga) TBprev M Dslot hSlLen sg (active1Fn bga) cr treeBPrev
    (levelsOfV vf 16 base) (levelsOfV vf 16 (base + 131071 + 5)) (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3))
    (levelsOfV vf 16 (bM1 + 3)) bga (vf (bM1 + 2)) (t.counter + 3) bnd startTag vf (bM1 + 3 + 131071)
    slR hsl mR hm aOR ha hOR hh bOR hb

private theorem blkSeg_eval_half2' (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams)
    {labM labH : List UInt8} {hlabM : labM.length ≤ 64} {hlabH : labH.length ≤ 64}
    (TA TBprev : Table) (M : MTable) (TH : Fp2 × Fp2 × Fp2 → Table)
    {hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390}
    (Dslot : SlotData P) (sg : SegGeom) (active1Fn : Fp2 × Fp2 × Fp2 → Bool)
    (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ) :
    let treeBNext := levelsOfV vf 16 base
    let treeA := levelsOfV vf 16 (base + 131071 + 5)
    let tA : Tr := Tr.mk (vf (base + 131071 + 5 + 131071 + 2)) t.counter key
    let treeM := levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)
    let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
    let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
    let tCh : Tr := Tr.mk (vf (bM1 + 2)) (t.counter + 3) key
    let treeH := levelsOfV vf 16 (bM1 + 3)
    ((blkMidProg Lq hL20 tag key P labM labH hlabM hlabH TA TBprev M TH hTHc Dslot sg active1Fn cr treeBPrev bnd startTag
        treeBNext treeA tA treeM).res (fun _ => default) vf (base + 131071 + 5 + 131071 + 3 + 8191)).1 =
    ((blkTailProg Lq hL20 key P labH hlabH TA TBprev M TH Dslot sg active1Fn cr treeBPrev bnd startTag
        treeBNext treeA treeM bga.1 bga.2.1 bga.2.2 tCh treeH).res (fun _ => default) vf (bM1 + 3 + 131071)).1 := by
  dsimp only [blkMidProg]
  exact blkSeg_eval_half2 Lq hL20 tag key labM hlabM (vf (base + 131071 + 5 + 131071 + 2)) t.counter
    (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)) TH hTHc vf (base + 131071 + 5 + 131071 + 3 + 8191)
    (blkTailProg Lq hL20 key P labH hlabH TA TBprev M TH Dslot sg active1Fn cr treeBPrev bnd startTag
      (levelsOfV vf 16 base) (levelsOfV vf 16 (base + 131071 + 5)) (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)))

private theorem blkSeg_eval_full (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams) (stageIdx : ℕ) (blkDig : Dig)
    {labB labA labM labH : List UInt8}
    {hlabB : labB.length ≤ 64} {hlabA : labA.length ≤ 64} {hlabM : labM.length ≤ 64} {hlabH : labH.length ≤ 64}
    (TBnext TA TBprev : Table)
    {hTBnc : ∀ j : Fin (2 ^ 16), (TBnext.cols j.val).length = 38}
    {hTAc : ∀ j : Fin (2 ^ 16), (TA.cols j.val).length = 4577}
    (M : MTable) (TH : Fp2 × Fp2 × Fp2 → Table)
    {hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390}
    (Dslot : SlotData P) (hSlLen : slotsFixedLen P 0 23 = 1283)
    (sg : SegGeom) (active1Fn : Fp2 × Fp2 × Fp2 → Bool)
    (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (slotsProveFixedProg Lq hL20 key P Dslot bga.1 bga.2.1 bga.2.2 23 (active1Fn bga) [] 0 {}
        ⟨vf (bSl - 1), t.counter + 3, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        M 23 (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3))
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 1283) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
        (levelsOfV vf 16 (base + 131071 + 5))
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        (openingHdrOk shdP_blkOpenGeomA 14 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 1283 + 115) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let bM1 := base + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH (TH bga)
        (levelsOfV vf 16 (base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome)
        (openingHdrOk shdP_blkOpenGeomH 14 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res
        (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR) :
    (((merkleTableProg Lq (by omega) tag 16 38 (by omega) TBnext hTBnc).andThen fun treeBNext =>
      (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat stageIdx))).andThen fun tf1 =>
        (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) blkDig.toList).andThen fun tf2 =>
          (absorbRootKeyed Lq hL20 key tf2 labB hlabB treeBNext.getRoot 38 14).andThen fun tFrame =>
            (merkleTableProg Lq (by omega) tag 16 4577 (by omega) TA hTAc).andThen fun treeA =>
              (absorbRootKeyed Lq hL20 key tFrame labA hlabA treeA.getRoot P.aRows P.logCols).andThen fun tA =>
                (merkleTableProg Lq (by omega) tag 12 (2 * 23 + 4) (by omega) (mTab 23 (cosetPt (rootFp 12)) M)
                    (fun j => mCol_length 23 _ M j.val)).andThen fun treeM =>
                  blkMidProg Lq hL20 tag key P labM labH hlabM hlabH TA TBprev M TH hTHc Dslot sg active1Fn cr treeBPrev bnd startTag
                    treeBNext treeA tA treeM).res (fun _ => default) vf base).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, acc), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let core : Exec.Block.Core := ⟨(levelsOfV vf 16 (base + 131071 + 5)).getRoot,
            (levelsOfV vf 16 (base + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
            (levelsOfV vf 12 (base + 131071 + 5 + 131071 + 3)).getRoot, sps, mR.1, aO, hO⟩
          let seg : Segment := ⟨some (levelsOfV vf 16 base).getRoot, core, bO, none⟩
          (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
           Carry.mk acc.claims.out (levelsOfV vf 16 base).getRoot))
      else none
    | _, _, _, _ => none :=
  (blkSeg_eval_half1 Lq hL20 tag key P stageIdx blkDig labB labA hlabB hlabA TBnext TA hTBnc hTAc M t vf base
    (blkMidProg Lq hL20 tag key P labM labH hlabM hlabH TA TBprev M TH hTHc Dslot sg active1Fn cr treeBPrev bnd startTag)).trans <|
    (blkSeg_eval_half2' Lq hL20 tag key P TA TBprev M TH Dslot sg active1Fn cr treeBPrev bnd startTag t vf base).trans <|
      blkSeg_eval_half3' Lq hL20 key P TA TBprev M TH Dslot hSlLen sg active1Fn cr treeBPrev bnd startTag t vf base
        slR hsl mR hm aOR ha hOR hh bOR hb

private theorem blkSegFixedProg_eval {Hdr' : Type} {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq')
    (tag : MTag) (key' : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig' : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (st' : Dig) (t' : Tr) (vf : ℕ → Dig)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let rnd := shdBlkRndOf c k
      let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
      let TA := blkTA w rnd
      let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (slotsProveFixedProg Lq' hL20' key' P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2 23
        (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga) [] 0 {}
        ⟨vf (bSl - 1), t'.counter + 3, key'⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let M := blkTM (shdBlkRndOf c k)
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        M 23 (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3))
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 1283) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let TA := blkTA w (shdBlkRndOf c k)
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
        (levelsOfV vf 16 (blkBase k + 131071 + 5))
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
        (openingHdrOk shdP_blkOpenGeomA 14 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res
        (fun _ => default) vf (bSl + 1283 + 115) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let TH := blkTH w (shdBlkRndOf c k) bga
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH
        (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome)
        (openingHdrOk shdP_blkOpenGeomH 14 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res
        (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR) :
    ((blkSegFixedProg (Hdr := Hdr') Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c k true cr (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))
        (vf 4101) st' t').res (fun _ => default) vf (blkBase k)).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, acc), some aO, some hO, some bO =>
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
          let core : Exec.Block.Core := ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
            (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
            (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot, sps, mR.1, aO, hO⟩
          let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot, core, bO, none⟩
          (fun e => Exec.Block.encSeg (vf 4101) sg.l sg.k st' seg e,
           ⟨acc.claims.out, (levelsOfV vf 16 (blkBase k)).getRoot⟩))
      else none
    | _, _, _, _ => none := by
  let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
  let rnd := shdBlkRndOf c k
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TA := blkTA w rnd
  let M := blkTM rnd
  let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
  have hSlLen : slotsFixedLen P 0 23 = 1283 := shdP_blk_slotsFixedLen tag ioIn ioOut _ Rp hR k.val k.isLt
  unfold blkSegFixedProg; dsimp only
  exact blkSeg_eval_full Lq' hL20' tag key' P (k.val + 1) (blkDig' k)
    TBnext TA TBprev
    (hTBnc := fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)
    (hTAc := fun j => by rw [blkTA_cols_len, blkTA_rows_len])
    M (fun b => blkTH w rnd b) (hTHc := fun _ j => by rw [blkTH_cols_len, blkTH_rows_len])
    (blkSlotData P w TA TBprev TBnext rnd) hSlLen
    (Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2)
    (fun b => true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) b)
    cr treeBPrev (vf 4101) st' t' vf (blkBase k) slR hsl mR hm aOR ha hOR hh bOR hb

private theorem blkSeg_extract_out_eq {Hdr' : Type} {Lq Lq' : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (hL20' : 2 ^ 20 ≤ Lq')
    (tag : MTag) (key key' : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig' : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (st' : Dig) (t t' tM tA tH tB : Tr) (vf : ℕ → Dig)
    (sps : List SlotProof) (recs : List SlotRec) (acc : Acc)
    (mO : Exec.Block.MaskOpening) (aO hO bO : Exec.Block.OpeningZk)
    (hSlVal :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let rnd := shdBlkRndOf c k
      let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
      let TA := blkTA w rnd
      let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      ((slotsProveFixedProg Lq hL20 key P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2 23
          (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga) [] 0 {}
          ⟨vf (bSl - 1), t.counter + 3, key⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc))
    (hAct4 : decide ((acc.fs ++ acc.hostFs).length = (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).nFunctionals) = true)
    (hmVal :
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      let M := blkTM (shdBlkRndOf c k)
      ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M 23
          (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)) (acc.fs ++ acc.hostFs) tM).res (fun _ => default) vf (bSl + 1283)).1 = mO)
    (haVal :
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let TA := blkTA w (shdBlkRndOf c k)
      ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
          (levelsOfV vf 16 (blkBase k + 131071 + 5)) true (openingHdrOk shdP_blkOpenGeomA 14 acc.claims.a) acc.claims.a tA).res
          (fun _ => default) vf (bSl + 1283 + 115)).1 = some aO)
    (hhVal :
      let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
      let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
      let TH := blkTH w (shdBlkRndOf c k) bga
      let clH := acc.claims.h ++ [P.logupSumClaim]
      ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH
          (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)) true
          (openingHdrOk shdP_blkOpenGeomH 14 clH) clH tH).res
          (fun _ => default) vf (bSl + 1283 + 115 + 4824)).1 = some hO)
    (hbVal :
      let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
      let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
      let clB := cr.pending ++ acc.claims.inp
      ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev true
          (openingHdrOk shdP_bndOpenGeom 14 clB) clB tB).res
          (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518)).1 = some bO) :
    ((blkSegFixedProg (Hdr := Hdr') Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c k true cr (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))) (vf 4101) st' t').res (fun _ => default) vf (blkBase k)).1
      = some (fun e => Exec.Block.encSeg (vf 4101)
          (Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2).l
          (Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2).k
          st'
          ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
            ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
             (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
             (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
             sps, mO, aO, hO⟩, bO, none⟩ e,
        ⟨acc.claims.out, (levelsOfV vf 16 (blkBase k)).getRoot⟩) := by
  let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
  let rnd := shdBlkRndOf c k
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TA := blkTA w rnd
  let M := blkTM rnd
  let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
  let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
  let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
  let TH := blkTH w rnd bga
  let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
  obtain ⟨slR', hsl'⟩ : ∃ slR', (slotsProveFixedProg Lq' hL20' key' P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2 23
      (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga) [] 0 {}
      ⟨vf (bSl - 1), t'.counter + 3, key'⟩).res (fun _ => default) vf bSl = slR' := ⟨_, rfl⟩
  obtain ⟨mR', hm'⟩ : ∃ mR', (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
      (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
      M 23 (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3))
      (match slR'.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR'.2).res (fun _ => default) vf (bSl + 1283) = mR' := ⟨_, rfl⟩
  obtain ⟨aOR', ha'⟩ : ∃ aOR', (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
      (levelsOfV vf 16 (blkBase k + 131071 + 5))
      (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
      (openingHdrOk shdP_blkOpenGeomA 14 (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []))
      (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []) mR'.2).res
      (fun _ => default) vf (bSl + 1283 + 115) = aOR' := ⟨_, rfl⟩
  obtain ⟨hOR', hh'⟩ : ∃ hOR', (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH
      (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
      ((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR'.1.isSome)
      (openingHdrOk shdP_blkOpenGeomH 14 (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
      (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR'.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR' := ⟨_, rfl⟩
  obtain ⟨bOR', hb'⟩ : ∃ bOR', (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
      (((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR'.1.isSome) && hOR'.1.isSome)
      (openingHdrOk shdP_bndOpenGeom 14 (match slR'.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
      (match slR'.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR'.2).res
      (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR' := ⟨_, rfl⟩
  rw [blkSegFixedProg_eval (Hdr' := Hdr') hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig' x c k cr st' t' vf slR' hsl' mR' hm' aOR' ha' hOR' hh' bOR' hb']
  have hSlSame : slR'.1 = some (sps, recs, acc) :=
    (congrArg Prod.fst hsl').symm.trans
      ((slotsProveFixedProg_res_indep_key hL20' hL20 key' key P _ bga.1 bga.2.1 bga.2.2 vf 23 _ [] 0 {} _ _ bSl).trans hSlVal)
  dsimp only [P] at hm' ha' hh' hb'
  simp only [hSlSame, hAct4] at hm' ha' hh' hb' ⊢
  have hmSame : mR'.1 = mO :=
    ((congrArg Prod.fst hm').symm.trans
      (zkBMaskFixedProg_res_eq Lq' hL20' key' M 23 _ (acc.fs ++ acc.hostFs) slR'.2 (fun _ => default) vf (bSl + 1283))).trans
      ((zkBMaskFixedProg_res_eq Lq hL20 key M 23 _ (acc.fs ++ acc.hostFs) tM (fun _ => default) vf (bSl + 1283)).symm.trans hmVal)
  have haSame : aOR'.1 = some aO :=
    ((congrArg Prod.fst ha').symm.trans
      (openingAuditFixedProg_res_eq Lq' hL20' key' Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA _ true _ acc.claims.a mR'.2 (fun _ => default) vf (bSl + 1283 + 115))).trans
      ((openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA _ true _ acc.claims.a tA (fun _ => default) vf (bSl + 1283 + 115)).symm.trans haVal)
  simp only [haSame, Option.isSome_some, Bool.and_true] at hh' hb' ⊢
  have hhSame : hOR'.1 = some hO :=
    ((congrArg Prod.fst hh').symm.trans
      (openingAuditFixedProg_res_eq Lq' hL20' key' Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH _ true _ (acc.claims.h ++ [P.logupSumClaim]) aOR'.2 (fun _ => default) vf (bSl + 1283 + 115 + 4824))).trans
      ((openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH _ true _ (acc.claims.h ++ [P.logupSumClaim]) tH (fun _ => default) vf (bSl + 1283 + 115 + 4824)).symm.trans hhVal)
  simp only [hhSame, Option.isSome_some, Bool.and_true] at hb' ⊢
  have hbSame : bOR'.1 = some bO :=
    ((congrArg Prod.fst hb').symm.trans
      (openingAuditFixedProg_res_eq Lq' hL20' key' Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev true _ (cr.pending ++ acc.claims.inp) hOR'.2 (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518))).trans
      ((openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev true _ (cr.pending ++ acc.claims.inp) tB (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518)).symm.trans hbVal)
  rw [hbSame, hmSame]; simp only [ite_true]

private theorem blkSeg_extract_ex {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (startTag : Dig) (t : Tr) (vf : ℕ → Dig)
    (hAct : ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c k true cr (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))
        (vf 4101) startTag t).res (fun _ => default) vf (blkBase k)).1.isSome = true) :
    Nonempty (BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k cr vf) := by
  classical
  let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x.1 x.2 k.val k.isLt
  let rnd := shdBlkRndOf c k
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TA := blkTA w rnd
  let M := blkTM rnd
  let treeBPrev := levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩))
  let bM1 := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1
  let bga := (challengeFp2Of (vf bM1), challengeFp2Of (vf (bM1 + 1)), challengeFp2Of (vf (bM1 + 2)))
  let TH := blkTH w rnd bga
  let bSl := blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3
  obtain ⟨slR, hslDef⟩ : { slR // (slotsProveFixedProg Lq hL20 key P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2 23
      (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga) [] 0 {}
      ⟨vf (bSl - 1), t.counter + 3, key⟩).res (fun _ => default) vf bSl = slR } := ⟨_, rfl⟩
  obtain ⟨mR, hmDef⟩ : { mR // (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
      M 23 (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3))
      (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 1283) = mR } := ⟨_, rfl⟩
  obtain ⟨aOR, haDef⟩ : { aOR // (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
      (levelsOfV vf 16 (blkBase k + 131071 + 5))
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false)
      (openingHdrOk shdP_blkOpenGeomA 14 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res
      (fun _ => default) vf (bSl + 1283 + 115) = aOR } := ⟨_, rfl⟩
  obtain ⟨hOR, hhDef⟩ : { hOR // (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH
      (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3))
      ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome)
      (openingHdrOk shdP_blkOpenGeomH 14 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 1283 + 115 + 4824) = hOR } := ⟨_, rfl⟩
  obtain ⟨bOR, hbDef⟩ : { bOR // (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
      (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) | none => false) && aOR.1.isSome) && hOR.1.isSome)
      (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
      (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res
      (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518) = bOR } := ⟨_, rfl⟩
  have hEv0 := blkSegFixedProg_eval (Hdr' := Hdr) hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x c k cr startTag t vf slR hslDef mR hmDef aOR haDef hOR hhDef bOR hbDef
  have hAct' := (congrArg Option.isSome hEv0).symm.trans hAct
  rcases hSl : slR.1 with _ | ⟨sps, recs, acc⟩; · rw [hSl] at hAct'; cases hAct'
  rcases hA : aOR.1 with _ | aO; · rw [hSl, hA] at hAct'; cases hAct'
  rcases hH : hOR.1 with _ | hO; · rw [hSl, hA, hH] at hAct'; cases hAct'
  rcases hB : bOR.1 with _ | bO; · rw [hSl, hA, hH, hB] at hAct'; cases hAct'
  simp only [hSl, hA, hH, hB, Option.isSome_some, Bool.and_true] at hAct'
  have hAct4 : decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) = true := by
    by_cases hc : decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals) = true
    · exact hc
    · rw [ite_eq_right hc] at hAct'; cases hAct'
  have hSlVal : ((slotsProveFixedProg Lq hL20 key P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2 23
      (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga) [] 0 {}
      ⟨vf (bSl - 1), t.counter + 3, key⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc) :=
    (congrArg Prod.fst hslDef).trans hSl
  have hSlEx := slotsProveFixedProg_extract Lq hL20 key P (blkSlotData P w TA TBprev TBnext rnd) bga.1 bga.2.1 bga.2.2
    (fun _ => default) vf 23 (true && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga)
    [] 0 {} ⟨vf (bSl - 1), t.counter + 3, key⟩ bSl sps recs acc rfl rfl hSlVal
  obtain ⟨hNotBad, hspsLen, hrecsLen, _, hcsLen, _, _, _, _, _, hexDfs⟩ := hSlEx
  have hbadF : blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga = false := by
    cases hb : blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) bga
    · rfl
    · rw [hb] at hNotBad; simp at hNotBad
  let dfs := Classical.choose hexDfs
  let vals := Classical.choose (Classical.choose_spec hexDfs)
  let accs := Classical.choose (Classical.choose_spec (Classical.choose_spec hexDfs))
  have hDfsSpec := Classical.choose_spec (Classical.choose_spec (Classical.choose_spec hexDfs))
  simp only [hSl, hA, hH, Option.isSome_some, Bool.and_true] at hmDef haDef hhDef hbDef
  let clH := acc.claims.h ++ [P.logupSumClaim]
  let clB := cr.pending ++ acc.claims.inp
  rw [hAct4] at hmDef
  have hmOEq := (congrArg Prod.fst hmDef).symm.trans
    (zkBMaskFixedProg_res_eq Lq hL20 key M 23
      (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)) (acc.fs ++ acc.hostFs) slR.2 (fun _ => default) vf (bSl + 1283))
  have haRes := openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA TA
    (levelsOfV vf 16 (blkBase k + 131071 + 5)) true (openingHdrOk shdP_blkOpenGeomA 14 acc.claims.a) acc.claims.a mR.2
    (fun _ => default) vf (bSl + 1283 + 115)
  rw [hAct4] at haDef
  rw [(congrArg Prod.fst haDef).trans hA] at haRes; dsimp only at haRes
  obtain ⟨haPass, haOEq⟩ := openingAudit_some_extract haRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at haPass
  have hhRes := openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH TH
    (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)) true
    (openingHdrOk shdP_blkOpenGeomH 14 clH) clH aOR.2 (fun _ => default) vf (bSl + 1283 + 115 + 4824)
  rw [hAct4] at hhDef
  rw [(congrArg Prod.fst hhDef).trans hH] at hhRes; dsimp only at hhRes
  obtain ⟨hhPass, hhOEq⟩ := openingAudit_some_extract hhRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hhPass
  have haudH : auditClaims clH (2 ^ 14) 4390 (List.range' 4282 106) (some (4280, 4281)) 4388 = .ok () := by
    simpa only [shdP_blkOpenGeomH] using auditClaims_ok_of_openingHdrOk hhPass.1.1.1.2
  have hbRes := openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TBprev treeBPrev
    true (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2 (fun _ => default) vf (bSl + 1283 + 115 + 4824 + 4518)
  rw [hAct4] at hbDef
  rw [(congrArg Prod.fst hbDef).trans hB] at hbRes; dsimp only at hbRes
  obtain ⟨hbPass, hbOEq⟩ := openingAudit_some_extract hbRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hbPass
  have hTBprevRows : TBprev.rows.length = 38 :=
    (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows_len
  exact
    ⟨{ bga := bga, bga_eq := rfl, hbad := hbadF, sps := sps, recs := recs, acc := acc,
       dfs := dfs, accs := accs, mO := mR.1, aO := aO, hO := hO, bO := bO,
       sps_len := hspsLen, recs_len := hrecsLen, cs_len := hcsLen,
       sl_res :=
         slotsProve_res_of_act_eq hNotBad
           ((slotsProveFixedProg_res_indep_key le_rfl hL20 none key P _ bga.1 bga.2.1 bga.2.2 vf 23 _ [] 0 {} _ _ bSl).trans hSlVal),
       slot_spec := fun t' => by
         have ht := hDfsSpec.1 t'
         dsimp only at ht
         simp only [Nat.zero_add] at ht
         refine ⟨ht.1, ht.2.1, ht.2.2.2.2.1, ht.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.1, ?_,
           ht.2.2.2.2.2.2.2.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.2.2.2⟩
         exact ht.2.2.2.2.2.2.2.2.2.2.2.1.trans (scProve_zero_add hL20 key _ _ _ _ _ _ _ _ _ vf _)
       fs_terms := by rw [List.map_append, hDfsSpec.2.1, hDfsSpec.2.2]; simp only [Nat.zero_add]; rfl
       mO_eq := hmOEq,
       haudA := by simpa only [shdP_blkOpenGeomA] using auditClaims_ok_of_openingHdrOk haPass.1.1.1.2,
       hDetA := by simpa only [shdP_blkOpenGeomA] using det_ne_zero_of_openingAuditOk haPass.2,
       hSumA := by simpa only [pGroups, TA, blkTA_rows_len, Exec.R13.r13Prm] using haPass.1.1.2,
       aO_eq := haOEq,
       haudH := haudH,
       hLenH := auditClaims_length_some_last acc.claims.h P.logupSumClaim
         (List.all_eq_true.mpr fun p hp => List.isEmpty_iff.mpr ((shdP_blk_logupSumClaim_shape tag ioIn ioOut Rp hR k).2.2 p hp).1)
         (2 ^ 14) 4390 4282 53 4280 4281 4388 (by omega) haudH,
       hDetH := by simpa only [shdP_blkOpenGeomH] using det_ne_zero_of_openingAuditOk hhPass.2,
       hSumH := by simpa only [pGroups, TH, blkTH_rows_len, Exec.R13.r13Prm] using hhPass.1.1.2,
       hO_eq := hhOEq,
       haudB := by
         rw [show List.range' 32 4 = [32, 33, 34, 35] from rfl]
         simpa only [shdP_bndOpenGeom] using auditClaims_ok_of_openingHdrOk hbPass.1.1.1.2,
       hDetB := by simpa only [shdP_bndOpenGeom] using det_ne_zero_of_openingAuditOk hbPass.2,
       hSumB := by simpa only [pGroups, hTBprevRows, Exec.R13.r13Prm] using hbPass.1.1.2,
       bO_eq := hbOEq,
       out_eq := fun {Hdr'} {Lq'} hL20' key' blkDig' st' t' =>
         blkSeg_extract_out_eq (Hdr' := Hdr') hL20 hL20' tag key key' Rp hR hweights hinPub ioIn ioOut blkDig'
           x c k cr st' t t' slR.2 mR.2 aOR.2 hOR.2 vf sps recs acc mR.1 aO hO bO hSlVal hAct4
           (congrArg Prod.fst hmDef) ((congrArg Prod.fst haDef).trans hA)
           ((congrArg Prod.fst hhDef).trans hH) ((congrArg Prod.fst hbDef).trans hB) }⟩

/-- Extract `BlkSegTrace` whenever `blkSegFixedProg` is active at `vf` and `blkBase k`. -/
noncomputable def blkSeg_extract {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (startTag : Dig) (t : Tr) (vf : ℕ → Dig)
    (hAct : ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c k true cr (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)))
        (vf 4101) startTag t).res (fun _ => default) vf (blkBase k)).1.isSome = true) :
    BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k cr vf :=
  Classical.choice (blkSeg_extract_ex (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x c k cr startTag t vf hAct)

/-- Two active `BlkSegTrace`s at block `k` and the same `vf` have identical `bga`, `dfs`, `acc.claims.*.map parts`,
and `(acc.fs ++ acc.hostFs).map terms`! -/
theorem blkSegTrace_invar (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (x₁ x₂ : {x // (classifyModelP Rp).admissible x}) (c₁ c₂ : ShdCoins)
    (k : Fin 26) (cr₁ cr₂ : Carry) (vf : ℕ → Dig)
    (T₁ : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x₁ c₁ k cr₁ vf)
    (T₂ : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x₂ c₂ k cr₂ vf) :
    T₁.bga = T₂.bga
      ∧ T₁.dfs = T₂.dfs
      ∧ T₁.acc.claims.a.map Block.ZClaim.parts = T₂.acc.claims.a.map Block.ZClaim.parts
      ∧ T₁.acc.claims.h.map Block.ZClaim.parts = T₂.acc.claims.h.map Block.ZClaim.parts
      ∧ T₁.acc.claims.inp.map Block.ZClaim.parts = T₂.acc.claims.inp.map Block.ZClaim.parts
      ∧ T₁.acc.claims.out.map Block.ZClaim.parts = T₂.acc.claims.out.map Block.ZClaim.parts
      ∧ (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
  have hBga : T₁.bga = T₂.bga := T₁.bga_eq.trans T₂.bga_eq.symm
  have hDr : ∀ t : Fin 23, (T₁.recs[t.val]'(by rw [T₁.recs_len]; exact t.isLt)).draws = (T₂.recs[t.val]'(by rw [T₂.recs_len]; exact t.isLt)).draws := fun t => by
    have h1 := (T₁.slot_spec t).2.2.2.1; have h2 := (T₂.slot_spec t).2.2.2.1; exact h1.trans h2.symm
  have hHist : ∀ m ≤ 23, (T₁.recs.take m).map SlotRec.draws = (T₂.recs.take m).map SlotRec.draws := fun m hm => by
    refine List.ext_getElem (by simp [T₁.recs_len, T₂.recs_len, hm]) fun i hi1 hi2 => ?_
    simp only [List.getElem_map, List.getElem_take]
    exact hDr ⟨i, by simp [T₁.recs_len] at hi1; omega⟩
  have hDfs : T₁.dfs = T₂.dfs := funext fun t => by
    have h1 := (T₁.slot_spec t).2.1; have h2 := (T₂.slot_spec t).2.1
    have hHistEq : Exec.Block.histOf T₁.bga.1 T₁.bga.2.1 T₁.bga.2.2 (T₁.recs.take t.val)
        = Exec.Block.histOf T₂.bga.1 T₂.bga.2.1 T₂.bga.2.2 (T₂.recs.take t.val) := by
      unfold Exec.Block.histOf; rw [hBga, hHist t.val (Nat.le_of_lt t.isLt)]
    rw [hHistEq] at h1
    exact Except.ok.inj (h1.symm.trans h2)
  have hCsEq : T₁.acc.cs = T₂.acc.cs := by
    refine List.ext_getElem (by rw [T₁.cs_len, T₂.cs_len]) fun i hi1 hi2 => ?_
    have hi : i < 23 := by rw [← T₁.cs_len]; exact hi1
    exact (T₁.slot_spec ⟨i, hi⟩).2.2.2.2.1.trans (T₂.slot_spec ⟨i, hi⟩).2.2.2.2.1.symm
  have hFs : (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
      = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
    rw [T₁.fs_terms, T₂.fs_terms, hDfs]
    exact congrArg (_ ++ ·) (List.filterMap_congr fun t _ => by
      have hAccCs : (T₁.accs t).cs = (T₂.accs t).cs := by
        rw [(T₁.slot_spec t).2.2.1, (T₂.slot_spec t).2.2.1, hCsEq]
      rw [hAccCs])
  have hShape := slotsProveFixedProg_shape_indep (2 ^ 20) le_rfl none
    (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
    (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
    (blkSlotData (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
      (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x₁.1 x₁.2 k.val k.isLt)
      (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x₁.1 x₁.2 k.val k.isLt) (shdBlkRndOf c₁ k))
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁.1 x₁.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁.1 x₁.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
      (shdBlkRndOf c₁ k))
    (blkSlotData (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
      (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x₂.1 x₂.2 k.val k.isLt)
      (blkTA (shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x₂.1 x₂.2 k.val k.isLt) (shdBlkRndOf c₂ k))
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂.1 x₂.2 ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂.1 x₂.2 ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
      (shdBlkRndOf c₂ k))
    (fun _ => rfl) rfl rfl rfl rfl
    (fun s hist dr => by cases (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val).define s hist dr <;> simp [TabsShapeEq.refl])
    T₁.bga.1 T₁.bga.2.1 T₁.bga.2.2 (fun _ => default) vf 23 true [] [] 0 {} {}
    ⟨vf ((blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3) - 1), 3, none⟩
    (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3 + 131071 + 3)
    rfl ⟨rfl, rfl, rfl, rfl, ⟨rfl, rfl, rfl, rfl⟩⟩
  dsimp only at hShape
  have hS1 := T₁.sl_res
  have hS2 := T₂.sl_res
  dsimp only at hS1 hS2
  rw [← hBga] at hS2
  rw [hS1, hS2] at hShape
  have hAccEq : AccShapeEq T₁.acc T₂.acc := hShape.2
  exact ⟨hBga, hDfs, hAccEq.2.2.2.2.1, hAccEq.2.2.2.2.2.1, hAccEq.2.2.2.2.2.2.1, hAccEq.2.2.2.2.2.2.2, hFs⟩

/-- Base point index in `[0, shdP_zkPts)` of Stage OUT-C (kernel-opaque to avoid reducing `5.55M` in `whnf`). -/
noncomputable def outcBase : ℕ :=
  Classical.choose (⟨209507 + blkStepFixedLen * 26, rfl⟩ : ∃ n : ℕ, n = 209507 + blkStepFixedLen * 26)

theorem outcBase_eq : outcBase = 209507 + blkStepFixedLen * 26 :=
  Classical.choose_spec (⟨209507 + blkStepFixedLen * 26, rfl⟩ : ∃ n : ℕ, n = 209507 + blkStepFixedLen * 26)

/-- Pure `vf`-driven Stage OUT-C active trace at `(x, c, cr26)`. -/
structure OutcSegTrace (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (cr26 : Carry) (vf : ℕ → Dig) where
  ch : List Fp2
  ch_eq : ch = (List.range 2).map (fun j => challengeFp2Of (vf (outcBase + 2 + 32767 + 3 + 8191 + 1 + j)))
  hbad : outcAlphaBad ch = false
  sps : List SlotProof
  recs : List SlotRec
  acc : Acc
  dfs : Fin 8 → SlotDef
  accs : Fin 8 → Acc
  mO : Exec.Block.MaskOpening
  aO : Exec.Block.OpeningZk
  hO : Exec.Block.OpeningZk
  bO : Exec.Block.OpeningZk
  sps_len : sps.length = 8
  recs_len : recs.length = 8
  cs_len : acc.cs.length = 8
  sl_res :
    let v := (classifySpecP Rp x.1).getD 0
    let V := shdVo tag Rp wDigest bOutRow v
    let bSl := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
    let w := outcWitness_of_adm Rp houtPub x.1 x.2
    let rnd := shdOutcRndOf c
    let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨26, by omega⟩
    let D := shdP_outcSlotData tag Rp wDigest bOutRow v w (shdP_outcTA Rp w rnd) TB26 rnd
    let bga := OutcV.bga ch
    ((slotsProveFixedProg (2 ^ 20) le_rfl none V.bp D bga.1 bga.2.1 bga.2.2 8
      true [] 0 {} ⟨vf (bSl - 1), 2, none⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc)
  slot_spec : ∀ t : Fin 8,
    let v := (classifySpecP Rp x.1).getD 0
    let V := shdVo tag Rp wDigest bOutRow v
    let P := V.bp
    let bSl := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
    let w := outcWitness_of_adm Rp houtPub x.1 x.2
    let rnd := shdOutcRndOf c
    let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨26, by omega⟩
    let D := shdP_outcSlotData tag Rp wDigest bOutRow v w (shdP_outcTA Rp w rnd) TB26 rnd
    let bga := OutcV.bga ch
    let bj := bSl + slotsFixedLen P 0 t.val
    let dr := (List.range (P.draws t.val)).map (fun j => challengeFp2Of (vf (bj + j)))
    let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
    let scBase := bj + P.draws t.val + 3
    let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (scBase + 2 * r + 1)))
    let rho := rhoFull.take (Exec.Block.slotShape P t.val).1
    let es := rhoFull.drop (Exec.Block.slotShape P t.val).1
    let hist := Exec.Block.histOf bga.1 bga.2.1 bga.2.2 (recs.take t.val)
    ch0.isZero = false
    ∧ P.define t.val hist dr = .ok (dfs t)
    ∧ (accs t).cs = acc.cs.take t.val
    ∧ (recs[t.val]'(by omega)).draws = dr
    ∧ (acc.cs[t.val]'(by omega)) = ch0
    ∧ (sps[t.val]'(by omega)).scalar = D.scalar t.val hist (accs t) (dfs t) ch0
    ∧ (sps[t.val]'(by omega)).rounds =
        ((scProveFixedProg (2 ^ 20) le_rfl none (slotN P t.val) true (D.strat t.val hist (accs t) (dfs t) ch0)
          ⟨vf (bj + P.draws t.val + 2), 0, none⟩).res (fun _ => default) vf scBase).1
    ∧ (sps[t.val]'(by omega)).terms = D.terms t.val hist (accs t) (dfs t) ch0 rhoFull
    ∧ (∀ p, Tab.priv p ∈ (dfs t).tabs →
        let z0 := Exec.Block.buildClaim P p (Exec.Block.claimPoint p rho)
          (Exec.Block.oneMinusProd es) (Exec.Block.maskCoef es p.extRound) Fp2.zero
        match p.cm with
        | .a => ∃ z ∈ acc.claims.a, z.parts = z0.parts
        | .h => ∃ z ∈ acc.claims.h, z.parts = z0.parts
        | .inp => ∃ z ∈ acc.claims.inp, z.parts = z0.parts
        | .out => ∃ z ∈ acc.claims.out, z.parts = z0.parts)
  fs_terms : (acc.fs ++ acc.hostFs).map Exec.Block.MaskFunctional.terms =
    let P := (shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x.1).getD 0)).bp
    let bSl := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
    (List.finRange 8).flatMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let rhoFull := (List.range (slotN P t.val)).map (fun r => challengeFp2Of (vf (bj + P.draws t.val + 3 + 2 * r + 1)))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      let ev := [(t.val, Cfs.evalWeights rhoFull nd.2.2)]
      match P.kind t.val with | .standalone => [[(t.val, sw)], ev] | _ => [ev])
    ++ (List.finRange 8).filterMap (fun t =>
      let bj := bSl + slotsFixedLen P 0 t.val
      let ch0 := challengeFp2Of (vf (bj + P.draws t.val + 1))
      let nd := Exec.Block.slotShape P t.val
      let sw := (Cfs.sumWeights (nd.1 + nd.2.1) nd.2.2).map (fun w => w.mul ch0)
      match P.kind t.val with
      | .host =>
        some ((t.val, sw) :: (dfs t).hosted.map fun hk =>
          (hk.1, (Cfs.sumWeights ((Exec.Block.slotShape P hk.1).1 + (Exec.Block.slotShape P hk.1).2.1)
            (Exec.Block.slotShape P hk.1).2.2).map
              (fun w => w.mul (hk.2.mul ((accs t).cs.getD hk.1 Fp2.zero)).neg)))
      | _ => none)
  mO_eq :
    let bMo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290
    let θ := challengeFp2Of (vf bMo)
    let rs := (List.range (2 * 8 + 2)).map (fun j => challengeFp2Of (vf (bMo + 2 + j)))
    let sq := (List.range 64).map (fun j => vf (bMo + 2 + (2 * 8 + 2) + 1 + j))
    let idxs := idxOf mDom mQ sq
    let M := shdP_outcM (shdOutcRndOf c)
    let treeM := levelsOfV vf 12 (outcBase + 2 + 32767 + 3)
    mO = ⟨polyWords shdP_U shdP_hbij (qPoly shdP_U (algebraMap GF shdP_K (rootFp 9).toGF) M 8 ((acc.fs ++ acc.hostFs).map toMF) (θ.toK shdP_U)),
          polyWords shdP_U shdP_hbij (pPoly shdP_U M 8 rs),
          idxs.map (fun j => ofOCol (j, mCol 8 (cosetPt (rootFp 12)) M j, M.salts j, treeM.pathD j))⟩
  haudA : auditClaims acc.claims.a (2 ^ 12) 76 (List.range' 16 58) none 74 = .ok ()
  hDetA :
    let bAo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85
    let proxR := (List.range 76).map (fun j => challengeFp2Of (vf (bAo + 29 + j)))
    (Exec.Block.det (proxR.getD 74 Fp2.zero) (proxR.getD 75 Fp2.zero)).v ≠ 0
  hSumA : ((groupZclaims (acc.claims.a.map toZClaim) 76 12).map (fun x => x.2.length)).sum = 29
  aO_eq :
    let bAo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85
    let lams := (List.range 29).map (fun j => challengeFp2Of (vf (bAo + j)))
    let proxR := (List.range 76).map (fun j => challengeFp2Of (vf (bAo + 29 + j)))
    let sq := (List.range 64).map (fun j => vf (bAo + 29 + 76 + 16 + 1 + j))
    let idxs := idxOf shdP_stgPrm.nn shdP_stgPrm.nQ sq
    let w := outcWitness_of_adm Rp houtPub x.1 x.2
    let TA := shdP_outcTA Rp w (shdOutcRndOf c)
    let treeA := levelsOfV vf 14 (outcBase + 2)
    aO = ⟨(groupRhosAux 76 (pGroups shdP_stgPrm TA (acc.claims.a.map toZClaim)) lams).map
            (fun rho => combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) rho TA.rows),
          combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) proxR TA.rows,
          idxs.map (fun j => ofOCol (j, TA.cols j, TA.salts j, treeA.pathD j))⟩
  haudH :
    let V := shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x.1).getD 0)
    let clH := acc.claims.h ++ [V.lay.logupSumClaim]
    auditClaims clH (2 ^ 12) 38 (List.range' 18 18) (some (16, 17)) 36 = .ok ()
  hLenH :
    let V := shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x.1).getD 0)
    (acc.claims.h ++ [V.lay.logupSumClaim]).length = 10
  hDetH :
    let bHo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bHo + 10 + j)))
    (Exec.Block.det (proxR.getD 36 Fp2.zero) (proxR.getD 37 Fp2.zero)).v ≠ 0
  hSumH :
    let V := shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x.1).getD 0)
    let clH := acc.claims.h ++ [V.lay.logupSumClaim]
    ((groupZclaims (clH.map toZClaim) 38 12).map (fun x => x.2.length)).sum = 10
  hO_eq :
    let V := shdVo tag Rp wDigest bOutRow ((classifySpecP Rp x.1).getD 0)
    let bHo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186
    let lams := (List.range 10).map (fun j => challengeFp2Of (vf (bHo + j)))
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bHo + 10 + j)))
    let sq := (List.range 64).map (fun j => vf (bHo + 10 + 38 + 5 + 1 + j))
    let idxs := idxOf shdP_stgPrm.nn shdP_stgPrm.nQ sq
    let w := outcWitness_of_adm Rp houtPub x.1 x.2
    let TH := shdP_outcTH Rp w (shdOutcRndOf c) (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
    let treeH := levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)
    let clH := acc.claims.h ++ [V.lay.logupSumClaim]
    hO = ⟨(groupRhosAux 38 (pGroups shdP_stgPrm TH (clH.map toZClaim)) lams).map
            (fun rho => combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) rho TH.rows),
          combVec (shdP_stgPrm.n + shdP_stgPrm.qPad) proxR TH.rows,
          idxs.map (fun j => ofOCol (j, TH.cols j, TH.salts j, treeH.pathD j))⟩
  haudB : auditClaims (cr26.pending ++ acc.claims.inp) (2 ^ 14) 38 (List.range' 32 4) none 36 = .ok ()
  hDetB :
    let bBo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186 + 118
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bBo + 2 + j)))
    (Exec.Block.det (proxR.getD 36 Fp2.zero) (proxR.getD 37 Fp2.zero)).v ≠ 0
  hSumB : ((groupZclaims ((cr26.pending ++ acc.claims.inp).map toZClaim) 38 14).map (fun x => x.2.length)).sum = 2
  bO_eq :
    let bBo := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3 + 290 + 85 + 186 + 118
    let lams := (List.range 2).map (fun j => challengeFp2Of (vf (bBo + j)))
    let proxR := (List.range 38).map (fun j => challengeFp2Of (vf (bBo + 2 + j)))
    let sq := (List.range 64).map (fun j => vf (bBo + 2 + 38 + 2 + 1 + j))
    let idxs := idxOf Exec.R13.r13Prm.nn Exec.R13.r13Prm.nQ sq
    let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨26, by omega⟩
    let treeB26 := levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by omega⟩))
    bO = ⟨(groupRhosAux 38 (pGroups Exec.R13.r13Prm TB26 ((cr26.pending ++ acc.claims.inp).map toZClaim)) lams).map
            (fun rho => combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) rho TB26.rows),
          combVec (Exec.R13.r13Prm.n + Exec.R13.r13Prm.qPad) proxR TB26.rows,
          idxs.map (fun j => ofOCol (j, TB26.cols j, TB26.salts j, treeB26.pathD j))⟩
  out_eq : ∀ {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (startTag : Dig) (t : Tr),
    let G := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
    let treeB26 := levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by omega⟩))
    let aRoot := (levelsOfV vf 14 (outcBase + 2)).getRoot
    let mRoot := (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot
    let hRoot := (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot
    let seg : StageSeg := ⟨none, ⟨aRoot, hRoot, mRoot, sps, mO, aO, hO⟩, [bO]⟩
    ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x.1 x.2 c true cr26 treeB26 (vf 4101) startTag t).res (fun _ => default) vf outcBase).1
      = some (fun e => encStage G (vf 4101) startTag seg e)

private theorem outcSeg_eval_half1 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : OutcV) (wDigest : Dig)
    (labA labM : List UInt8) (hlabA : labA.length ≤ 64) (hlabM : labM.length ≤ 64)
    (TA : Table) (hTAc : ∀ j : Fin (2 ^ 14), (TA.cols j.val).length = 76)
    (M : MTable) (TH : List Fp2 → Table) (hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 38)
    (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    {β γ : Type}
    (cont : MerkleLevels 14 → MerkleLevels 12 → List Fp2 → Tr → MerkleLevels 14 → PProg (QB Lq) Dig (β × γ)) :
    let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
    let treeA := levelsOfV vf 14 (base + 2)
    let treeM := levelsOfV vf 12 (base + 2 + 32767 + 3)
    let treeH := levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2)
    let tCh : Tr := Tr.mk (vf (base + 2 + 32767 + 3 + 8191 + 1 + 2 - 1)) (t.counter + 2) key
    (((trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat V.stageIndex))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) wDigest.toList).andThen fun tFrame =>
        (merkleTableProg Lq (by omega) tag 14 76 (by omega) TA hTAc).andThen fun treeA =>
          (absorbRootKeyed Lq hL20 key tFrame labA hlabA treeA.getRoot V.bp.aRows V.bp.logCols).andThen fun tA =>
            (merkleTableProg Lq (by omega) tag 12 (2 * 8 + 4) (by omega) (mTab 8 (cosetPt (rootFp 12)) M)
                (fun j => mCol_length 8 _ M j.val)).andThen fun treeM =>
              (trAbsorbKeyed Lq hL20 key tA labM hlabM treeM.getRoot.toList).andThen fun tM =>
                (trChallengeFp2VecKeyed Lq (by omega) key 2 tM).andThen fun chR =>
                  (merkleTableProg Lq (by omega) tag 14 38 (by omega) (TH chR.1) (hTHc chR.1)).andThen fun treeH =>
                    cont treeA treeM chR.1 chR.2 treeH).res (fun _ => default) vf base).1
    = ((cont treeA treeM ch tCh treeH).res (fun _ => default) vf (base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767)).1 := by
  intro ch treeA treeM treeH tCh
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) rfl
    (trAbsorbKeyed_res Lq hL20 key _ _ _ _ _ vf base) ?_
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _)
    (by omega : base + 1 + 1 = base + 2)
    (trAbsorbKeyed_res Lq hL20 key _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _)
    (congrArg (base + 2 + ·) (by decide : 2 ^ 14 + (2 ^ 14 - 1) = 32767))
    (merkleTableProg_res Lq (by omega) tag 14 76 (by omega) _ _ _ vf (base + 2)) ?_
  refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) rfl
    (absorbRootKeyed_res Lq hL20 key _ _ _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 12 (2 * 8 + 4) (by omega) _ _)
    (congrArg (base + 2 + 32767 + 3 + ·) (by decide : 2 ^ 12 + (2 ^ 12 - 1) = 8191))
    (merkleTableProg_res Lq (by omega) tag 12 (2 * 8 + 4) (by omega) _ _ _ vf _) ?_
  refine res_fst_andThen_step (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) rfl
    (trAbsorbKeyed_res Lq hL20 key _ _ _ _ _ vf _) ?_
  refine res_fst_andThen_step (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 2 _) rfl
    (a := (ch, tCh)) ?_ ?_
  · exact trChallengeFp2VecKeyed_res_pos Lq (by omega) key _ vf 2 (by decide) _ t.counter rfl 2 (by decide) _
  refine res_fst_andThen_step (merkleTableProg_ptLen Lq (by omega) tag 14 38 (by omega) _ _)
    (congrArg (base + 2 + 32767 + 3 + 8191 + 1 + 2 + ·) (by decide : 2 ^ 14 + (2 ^ 14 - 1) = 32767))
    (merkleTableProg_res Lq (by omega) tag 14 38 (by omega) _ _ _ vf _) ?_
  rfl

private theorem outcSeg_eval_half2 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G : StageGeom)
    (labH : List UInt8) (hlabH : labH.length ≤ 64)
    (TA TB26 : Table) (M : MTable) (TH : Table)
    (Dslot : SlotData V.bp) (hSlLen : slotsFixedLen V.bp 0 8 = 290)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig)
    (treeA : MerkleLevels 14) (treeM : MerkleLevels 12) (ch : List Fp2) (sCh : Dig) (cCh : UInt64) (treeH : MerkleLevels 14)
    (vf : ℕ → Dig) (bH : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let bSl := bH + 3
      let bga := OutcV.bga ch
      (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {}
        ⟨vf (bSl - 1), cCh, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := bH + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        M 8 treeM
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 290) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA treeA
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        (openingHdrOk gA 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 290 + 85) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH TH treeH
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome)
        (openingHdrOk gH 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := bH + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR) :
    (((absorbRootKeyed Lq hL20 key (Tr.mk sCh cCh key) labH hlabH treeH.getRoot V.bp.hRows V.bp.logCols).andThen fun t3 =>
      let bga := OutcV.bga ch
      (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} t3).andThen fun slR =>
        let active2 := match slR.1 with
          | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
          | none => false
        let fs := match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []
        (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 8 treeM fs slR.2).andThen fun mR =>
          let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
          (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA treeA active2 (openingHdrOk gA 12 clA) clA mR.2).andThen fun aOR =>
            let active3 := active2 && aOR.1.isSome
            let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
            (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH TH treeH active3 (openingHdrOk gH 12 clH) clH aOR.2).andThen fun hOR =>
              let active4 := active3 && hOR.1.isSome
              let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
              (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26 active4 (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                match slR.1, aOR.1, hOR.1, bOR.1 with
                | some (sps, _, _), some aO, some hO, some bO =>
                  if active4 then
                    let seg : StageSeg := ⟨none, ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
                    .ret (some (fun e => encStage G bnd startTag seg e), bOR.2)
                  else .ret (none, bOR.2)
                | _, _, _, _ => .ret (none, bOR.2)).res (fun _ => default) vf bH).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, _), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let seg : StageSeg := ⟨none, ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
          fun e => encStage G bnd startTag seg e)
      else none
    | _, _, _, _ => none := by
  let bSl := bH + 3
  refine res_fst_andThen_step (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (rfl : _ = bSl)
    (a := Tr.mk (vf (bSl - 1)) cCh key) ?_ ?_
  · rw [absorbRootKeyed_res]
    exact congrArg (fun idx => Tr.mk (vf idx) cCh key) (Nat.add_sub_assoc (by decide : 1 ≤ 3) _).symm
  refine res_fst_andThen_step ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr hSlLen)
    rfl hsl ?_
  refine res_fst_andThen_step (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _)
    (congrArg (bSl + 290 + ·) (by decide : zkBMaskFixedLen 8 = 85))
    hm ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _)
    (congrArg (bSl + 290 + 85 + ·) (by decide : openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ = 186))
    ha ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _)
    (congrArg (bSl + 290 + 85 + 186 + ·) (by decide : openingAuditFixedLen 10 38 5 shdP_stgPrm.nQ = 118))
    hh ?_
  refine res_fst_andThen_step (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ _ _ _ _ _)
    rfl hb ?_
  rcases slR with ⟨_ | ⟨sps, recs, acc⟩, tSl⟩ <;> rcases aOR with ⟨_ | aO, tA⟩ <;>
    rcases hOR with ⟨_ | hO, tH⟩ <;> rcases bOR with ⟨_ | bO, tB⟩
  all_goals first
    | rfl
    | (dsimp only [Option.isSome_some, Bool.and_true]
       split_ifs <;> rfl)

private noncomputable def outcTailProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G : StageGeom)
    (labH : List UInt8) (hlabH : labH.length ≤ 64)
    (TA TB26 : Table) (M : MTable) (TH : List Fp2 → Table)
    (Dslot : SlotData V.bp) (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig)
    (treeA : MerkleLevels 14) (treeM : MerkleLevels 12) (ch : List Fp2) (tCh : Tr) (treeH : MerkleLevels 14) :=
  (absorbRootKeyed Lq hL20 key tCh labH hlabH treeH.getRoot V.bp.hRows V.bp.logCols).andThen fun t3 =>
    let bga := OutcV.bga ch
    (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} t3).andThen fun slR =>
      let active2 := match slR.1 with
        | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
        | none => false
      let fs := match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 8 treeM fs slR.2).andThen fun mR =>
        let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
        (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA treeA active2 (openingHdrOk gA 12 clA) clA mR.2).andThen fun aOR =>
          let active3 := active2 && aOR.1.isSome
          let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
          (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (TH ch) treeH active3 (openingHdrOk gH 12 clH) clH aOR.2).andThen fun hOR =>
            let active4 := active3 && hOR.1.isSome
            let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
            (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26 active4 (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
              match slR.1, aOR.1, hOR.1, bOR.1 with
              | some (sps, _, _), some aO, some hO, some bO =>
                if active4 then
                  let seg : StageSeg := ⟨none, ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
                  .ret (some (fun e => encStage G bnd startTag seg e), bOR.2)
                else .ret (none, bOR.2)
              | _, _, _, _ => .ret (none, bOR.2)

private theorem outcSeg_eval_half2' (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G : StageGeom)
    {labH : List UInt8} {hlabH : labH.length ≤ 64}
    (TA TB26 : Table) (M : MTable) (TH : List Fp2 → Table)
    (Dslot : SlotData V.bp) (hSlLen : slotsFixedLen V.bp 0 8 = 290)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      let bga := OutcV.bga ch
      (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {}
        ⟨vf (bSl - 1), t.counter + 2, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        M 8 (levelsOfV vf 12 (base + 2 + 32767 + 3))
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 290) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA (levelsOfV vf 14 (base + 2))
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        (openingHdrOk gA 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 290 + 85) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (TH ch) (levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2))
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome)
        (openingHdrOk gH 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR) :
    let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
    let treeA := levelsOfV vf 14 (base + 2)
    let treeM := levelsOfV vf 12 (base + 2 + 32767 + 3)
    let treeH := levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2)
    let tCh : Tr := Tr.mk (vf (base + 2 + 32767 + 3 + 8191 + 1 + 2 - 1)) (t.counter + 2) key
    ((outcTailProg Lq hL20 key V gA gH G labH hlabH TA TB26 M TH Dslot cr treeB26 bnd startTag treeA treeM ch tCh treeH).res
      (fun _ => default) vf (base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767)).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, _), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let seg : StageSeg := ⟨none, ⟨treeA.getRoot, treeH.getRoot, treeM.getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
          fun e => encStage G bnd startTag seg e)
      else none
    | _, _, _, _ => none := by
  dsimp only [outcTailProg]
  exact outcSeg_eval_half2 Lq hL20 key V gA gH G labH hlabH TA TB26 M
    (TH ((List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))))
    Dslot hSlLen cr treeB26 bnd startTag
    (levelsOfV vf 14 (base + 2)) (levelsOfV vf 12 (base + 2 + 32767 + 3))
    ((List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j))))
    (vf (base + 2 + 32767 + 3 + 8191 + 1 + 2 - 1)) (t.counter + 2)
    (levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2)) vf
    (base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767) slR hsl mR hm aOR ha hOR hh bOR hb

private theorem outcSeg_eval_full (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G : StageGeom) (wDigest : Dig)
    {labA labM labH : List UInt8}
    {hlabA : labA.length ≤ 64} {hlabM : labM.length ≤ 64} {hlabH : labH.length ≤ 64}
    (TA TB26 : Table) {hTAc : ∀ j : Fin (2 ^ 14), (TA.cols j.val).length = 76}
    (M : MTable) (TH : List Fp2 → Table) {hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 38}
    (Dslot : SlotData V.bp) (hSlLen : slotsFixedLen V.bp 0 8 = 290)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (vf : ℕ → Dig) (base : ℕ)
    (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
    (hsl :
      let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      let bga := OutcV.bga ch
      (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {}
        ⟨vf (bSl - 1), t.counter + 2, key⟩).res (fun _ => default) vf bSl = slR)
    (mR : Exec.Block.MaskOpening × Tr)
    (hm :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        M 8 (levelsOfV vf 12 (base + 2 + 32767 + 3))
        (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 290) = mR)
    (aOR : Option Exec.Block.OpeningZk × Tr)
    (ha :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA (levelsOfV vf 14 (base + 2))
        (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
        (openingHdrOk gA 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res (fun _ => default) vf (bSl + 290 + 85) = aOR)
    (hOR : Option Exec.Block.OpeningZk × Tr)
    (hh :
      let ch := (List.range 2).map (fun j => challengeFp2Of (vf (base + 2 + 32767 + 3 + 8191 + 1 + j)))
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (TH ch) (levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2))
        ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome)
        (openingHdrOk gH 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
        (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR)
    (bOR : Option Exec.Block.OpeningZk × Tr)
    (hb :
      let bSl := base + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
        (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome)
        (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []))
        (match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []) hOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR) :
    (((trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat V.stageIndex))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) wDigest.toList).andThen fun tFrame =>
        (merkleTableProg Lq (by omega) tag 14 76 (by omega) TA hTAc).andThen fun treeA =>
          (absorbRootKeyed Lq hL20 key tFrame labA hlabA treeA.getRoot V.bp.aRows V.bp.logCols).andThen fun tA =>
            (merkleTableProg Lq (by omega) tag 12 (2 * 8 + 4) (by omega) (mTab 8 (cosetPt (rootFp 12)) M)
                (fun j => mCol_length 8 _ M j.val)).andThen fun treeM =>
              (trAbsorbKeyed Lq hL20 key tA labM hlabM treeM.getRoot.toList).andThen fun tM =>
                (trChallengeFp2VecKeyed Lq (by omega) key 2 tM).andThen fun chR =>
                  (merkleTableProg Lq (by omega) tag 14 38 (by omega) (TH chR.1) (hTHc chR.1)).andThen fun treeH =>
                    outcTailProg Lq hL20 key V gA gH G labH hlabH TA TB26 M TH Dslot cr treeB26 bnd startTag treeA treeM chR.1 chR.2 treeH).res (fun _ => default) vf base).1 =
    match slR.1, aOR.1, hOR.1, bOR.1 with
    | some (sps, _, _), some aO, some hO, some bO =>
      if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome then
        some (
          let seg : StageSeg := ⟨none, ⟨(levelsOfV vf 14 (base + 2)).getRoot,
            (levelsOfV vf 14 (base + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
            (levelsOfV vf 12 (base + 2 + 32767 + 3)).getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
          fun e => encStage G bnd startTag seg e)
      else none
    | _, _, _, _ => none :=
  (outcSeg_eval_half1 Lq hL20 tag key V wDigest labA labM hlabA hlabM TA hTAc M TH hTHc t vf base
    (outcTailProg Lq hL20 key V gA gH G labH hlabH TA TB26 M TH Dslot cr treeB26 bnd startTag)).trans
    (outcSeg_eval_half2' Lq hL20 key V gA gH G TA TB26 M TH Dslot hSlLen cr treeB26 bnd startTag t vf base slR hsl mR hm aOR ha hOR hh bOR hb)

/-- Extract `OutcSegTrace` whenever `outcSegFixedProg` is active at `vf` and `outcBase`. -/
noncomputable def outcSeg_extract (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (cr26 : Carry) (startTag : Dig) (t : Tr) (vf : ℕ → Dig)
    (hAct : ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x.1 x.2 c true cr26 (levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by omega⟩)))
        (vf 4101) startTag t).res (fun _ => default) vf outcBase).1.isSome = true) :
    OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x c cr26 vf := by
  classical
  let v := (classifySpecP Rp x.1).getD 0
  let V := shdVo tag Rp wDigest bOutRow v
  let w := outcWitness_of_adm Rp houtPub x.1 x.2
  let rnd := shdOutcRndOf c
  let TA := shdP_outcTA Rp w rnd
  let M := shdP_outcM rnd
  let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨26, by omega⟩
  let treeB26 := levelsOfV vf 16 (shdTreeBase (.bnd ⟨26, by omega⟩))
  let ch := (List.range 2).map (fun j => challengeFp2Of (vf (outcBase + 2 + 32767 + 3 + 8191 + 1 + j)))
  let TH := shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
  let bSl := outcBase + 2 + 32767 + 3 + 8191 + 1 + 2 + 32767 + 3
  let bga := OutcV.bga ch
  have hSlLen : slotsFixedLen V.bp 0 8 = 290 := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow v
  obtain ⟨hAR, hAS, hAP, hHR, hHS, hHU, hHP⟩ := shdP_outcOpenGeom_eq tag Rp wDigest bOutRow v
  have hEv : ∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig) (st' : Dig) (t' : Tr)
      (slR : Option (List SlotProof × List SlotRec × Acc) × Tr)
      (hsl : (slotsProveFixedProg Lq' hL20' key' V.bp (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd)
          bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} ⟨vf (bSl - 1), t'.counter + 2, key'⟩).res (fun _ => default) vf bSl = slR)
      (mR : Exec.Block.MaskOpening × Tr)
      (hm : (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
          (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
          M 8 (levelsOfV vf 12 (outcBase + 2 + 32767 + 3))
          (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 290) = mR)
      (aOR : Option Exec.Block.OpeningZk × Tr)
      (ha : (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 29 76 16 (shdP_outcOpenGeomA V) TA
          (levelsOfV vf 14 (outcBase + 2))
          (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
          (openingHdrOk (shdP_outcOpenGeomA V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
          (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res
          (fun _ => default) vf (bSl + 290 + 85) = aOR)
      (hOR : Option Exec.Block.OpeningZk × Tr)
      (hh : (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 10 38 5 (shdP_outcOpenGeomH V) TH
          (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))
          ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome)
          (openingHdrOk (shdP_outcOpenGeomH V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
          (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR)
      (bOR : Option Exec.Block.OpeningZk × Tr)
      (hb : (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
          (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome)
          (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []))
          (match slR.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []) hOR.2).res
          (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR),
      ((outcSegFixedProg Lq' hL20' tag key' Rp hR hweights hinPub houtPub wDigest bOutRow
          x.1 x.2 c true cr26 treeB26 (vf 4101) st' t').res (fun _ => default) vf outcBase).1 =
      match slR.1, aOR.1, hOR.1, bOR.1 with
      | some (sps, _, _), some aO, some hO, some bO =>
        if ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome then
          some (
            let G := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
            let seg : StageSeg := ⟨none, ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
              (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
              (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot, sps, mR.1, aO, hO⟩, [bO]⟩
            fun e => encStage G (vf 4101) st' seg e)
        else none
      | _, _, _, _ => none := by
    intro Lq' hL20' key' st' t' slR hsl mR hm aOR ha hOR hh bOR hb
    unfold outcSegFixedProg; dsimp only
    exact outcSeg_eval_full Lq' hL20' tag key' V (shdP_outcOpenGeomA V) (shdP_outcOpenGeomH V)
      (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) wDigest TA TB26 M
      (fun c' => shdP_outcTH Rp w rnd (c'.getD 0 Fp2.zero) (c'.getD 1 Fp2.zero))
      (hTHc := fun c' j => (mkPcsTable_cols_length 12 2 256 (by norm_num) _ _ j.val).trans (shdP_outcTH_rows_len Rp w rnd (c'.getD 0 Fp2.zero) (c'.getD 1 Fp2.zero)))
      (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd) hSlLen
      cr26 treeB26 (vf 4101) st' t' vf outcBase slR hsl mR hm aOR ha hOR hh bOR hb
  obtain ⟨slR, hslDef⟩ : { slR // (slotsProveFixedProg Lq hL20 key V.bp (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd)
      bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} ⟨vf (bSl - 1), t.counter + 2, key⟩).res (fun _ => default) vf bSl = slR } := ⟨_, rfl⟩
  obtain ⟨mR, hmDef⟩ : { mR // (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
      M 8 (levelsOfV vf 12 (outcBase + 2 + 32767 + 3))
      (match slR.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR.2).res (fun _ => default) vf (bSl + 290) = mR } := ⟨_, rfl⟩
  obtain ⟨aOR, haDef⟩ : { aOR // (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 (shdP_outcOpenGeomA V) TA
      (levelsOfV vf 14 (outcBase + 2))
      (match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
      (openingHdrOk (shdP_outcOpenGeomA V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.a | none => []) mR.2).res
      (fun _ => default) vf (bSl + 290 + 85) = aOR } := ⟨_, rfl⟩
  obtain ⟨hOR, hhDef⟩ : { hOR // (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 (shdP_outcOpenGeomH V) TH
      (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))
      ((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome)
      (openingHdrOk (shdP_outcOpenGeomH V) 12 (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
      (match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR } := ⟨_, rfl⟩
  obtain ⟨bOR, hbDef⟩ : { bOR // (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
      (((match slR.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR.1.isSome) && hOR.1.isSome)
      (openingHdrOk shdP_bndOpenGeom 14 (match slR.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []))
      (match slR.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []) hOR.2).res
      (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR } := ⟨_, rfl⟩
  have hEv0 := hEv hL20 key startTag t slR hslDef mR hmDef aOR haDef hOR hhDef bOR hbDef
  have hAct' := (congrArg Option.isSome hEv0).symm.trans hAct
  rcases hSl : slR.1 with _ | ⟨sps, recs, acc⟩; · rw [hSl] at hAct'; cases hAct'
  rcases hA : aOR.1 with _ | aO; · rw [hSl, hA] at hAct'; cases hAct'
  rcases hH : hOR.1 with _ | hO; · rw [hSl, hA, hH] at hAct'; cases hAct'
  rcases hB : bOR.1 with _ | bO; · rw [hSl, hA, hH, hB] at hAct'; cases hAct'
  simp only [hSl, hA, hH, hB, Option.isSome_some, Bool.and_true] at hAct'
  have hAct4 : decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) = true := by
    by_cases hc : decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) = true
    · exact hc
    · rw [ite_eq_right hc] at hAct'; cases hAct'
  have hSlVal : ((slotsProveFixedProg Lq hL20 key V.bp (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd)
      bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} ⟨vf (bSl - 1), t.counter + 2, key⟩).res (fun _ => default) vf bSl).1 = some (sps, recs, acc) :=
    (congrArg Prod.fst hslDef).trans hSl
  have hSlEx := slotsProveFixedProg_extract Lq hL20 key V.bp _ bga.1 bga.2.1 bga.2.2
    (fun _ => default) vf 8 (true && !outcAlphaBad ch) [] 0 {} ⟨vf (bSl - 1), t.counter + 2, key⟩ bSl sps recs acc rfl rfl hSlVal
  obtain ⟨hNotBad, hspsLen, hrecsLen, _, hcsLen, _, _, _, _, _, hexDfs⟩ := hSlEx
  have hbadF : outcAlphaBad ch = false := by
    cases hb : outcAlphaBad ch
    · rfl
    · rw [hb] at hNotBad; simp at hNotBad
  let dfs := Classical.choose hexDfs
  let vals := Classical.choose (Classical.choose_spec hexDfs)
  let accs := Classical.choose (Classical.choose_spec (Classical.choose_spec hexDfs))
  have hDfsSpec := Classical.choose_spec (Classical.choose_spec (Classical.choose_spec hexDfs))
  simp only [hSl, hA, hH, Option.isSome_some, Bool.and_true] at hmDef haDef hhDef hbDef
  let clH := acc.claims.h ++ [V.lay.logupSumClaim]
  let clB := cr26.pending ++ acc.claims.inp
  rw [hAct4] at hmDef
  have hmOEq := (congrArg Prod.fst hmDef).symm.trans
    (zkBMaskFixedProg_res_eq Lq hL20 key M 8
      (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)) (acc.fs ++ acc.hostFs) slR.2 (fun _ => default) vf (bSl + 290))
  have haRes := openingAuditFixedProg_res_eq Lq hL20 key shdP_stgPrm 14 29 76 16 (shdP_outcOpenGeomA V) TA
    (levelsOfV vf 14 (outcBase + 2)) true (openingHdrOk (shdP_outcOpenGeomA V) 12 acc.claims.a) acc.claims.a mR.2
    (fun _ => default) vf (bSl + 290 + 85)
  rw [hAct4] at haDef
  rw [(congrArg Prod.fst haDef).trans hA] at haRes; dsimp only at haRes
  obtain ⟨haPass, haOEq⟩ := openingAudit_some_extract haRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at haPass
  have hhRes := openingAuditFixedProg_res_eq Lq hL20 key shdP_stgPrm 14 10 38 5 (shdP_outcOpenGeomH V) TH
    (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)) true
    (openingHdrOk (shdP_outcOpenGeomH V) 12 clH) clH aOR.2 (fun _ => default) vf (bSl + 290 + 85 + 186)
  rw [hAct4] at hhDef
  rw [(congrArg Prod.fst hhDef).trans hH] at hhRes; dsimp only at hhRes
  obtain ⟨hhPass, hhOEq⟩ := openingAudit_some_extract hhRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hhPass
  have haudH : auditClaims clH (2 ^ 12) 38 (List.range' 18 18) (some (16, 17)) 36 = .ok () := by
    have h0 := auditClaims_ok_of_openingHdrOk hhPass.1.1.1.2
    simpa only [shdP_outcOpenGeomH, V, hHR, hHS, hHU, hHP] using h0
  have hbRes := openingAuditFixedProg_res_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
    true (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2 (fun _ => default) vf (bSl + 290 + 85 + 186 + 118)
  rw [hAct4] at hbDef
  rw [(congrArg Prod.fst hbDef).trans hB] at hbRes; dsimp only at hbRes
  obtain ⟨hbPass, hbOEq⟩ := openingAudit_some_extract hbRes
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hbPass
  have hTB26Rows : TB26.rows.length = 38 :=
    (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨26, by omega⟩).rows_len
  exact
    { ch := ch, ch_eq := rfl, hbad := hbadF, sps := sps, recs := recs, acc := acc,
      dfs := dfs, accs := accs, mO := mR.1, aO := aO, hO := hO, bO := bO,
      sps_len := hspsLen, recs_len := hrecsLen, cs_len := hcsLen,
      sl_res :=
        slotsProve_res_of_act_eq hNotBad
          ((slotsProveFixedProg_res_indep_key le_rfl hL20 none key V.bp _ bga.1 bga.2.1 bga.2.2 vf 8 _ [] 0 {} _ _ bSl).trans hSlVal),
      slot_spec := fun t' => by
        have ht := hDfsSpec.1 t'
        dsimp only at ht
        simp only [Nat.zero_add] at ht
        refine ⟨ht.1, ht.2.1, ht.2.2.2.2.1, ht.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.1, ?_,
          ht.2.2.2.2.2.2.2.2.2.2.2.2.1, ht.2.2.2.2.2.2.2.2.2.2.2.2.2⟩
        exact ht.2.2.2.2.2.2.2.2.2.2.2.1.trans (scProve_zero_add hL20 key _ _ _ _ _ _ _ _ _ vf _)
      fs_terms := by rw [List.map_append, hDfsSpec.2.1, hDfsSpec.2.2]; simp only [Nat.zero_add]; rfl
      mO_eq := hmOEq,
      haudA := by
        have h0 := auditClaims_ok_of_openingHdrOk haPass.1.1.1.2
        simpa only [shdP_outcOpenGeomA, V, hAR, hAS, hAP] using h0,
      hDetA := by
        have h0 := det_ne_zero_of_openingAuditOk haPass.2
        simpa only [shdP_outcOpenGeomA, V, hAR, hAP] using h0,
      hSumA := by simpa only [pGroups, TA, shdP_outcTA_rows_len Rp w rnd, shdP_stgPrm] using haPass.1.1.2,
      aO_eq := haOEq,
      haudH := haudH,
      hLenH := auditClaims_length_some_last acc.claims.h V.lay.logupSumClaim
        (List.all_eq_true.mpr fun p hp => List.isEmpty_iff.mpr ((shdP_outc_logupSumClaim_shape tag Rp wDigest bOutRow v).2.2 p hp).1)
        (2 ^ 12) 38 18 9 16 17 36 (by omega) haudH,
      hDetH := by
        have h0 := det_ne_zero_of_openingAuditOk hhPass.2
        simpa only [shdP_outcOpenGeomH, V, hHR, hHP] using h0,
      hSumH := by simpa only [pGroups, TH, clH, shdP_outcTH_rows_len Rp w rnd _ _, shdP_stgPrm] using hhPass.1.1.2,
      hO_eq := hhOEq,
      haudB := by
        rw [show List.range' 32 4 = [32, 33, 34, 35] from rfl]
        simpa only [shdP_bndOpenGeom] using auditClaims_ok_of_openingHdrOk hbPass.1.1.1.2,
      hDetB := by simpa only [shdP_bndOpenGeom] using det_ne_zero_of_openingAuditOk hbPass.2,
      hSumB := by simpa only [pGroups, hTB26Rows, Exec.R13.r13Prm] using hbPass.1.1.2,
      bO_eq := hbOEq,
      out_eq := fun {Lq'} hL20' key' st' t' => by
        dsimp only
        obtain ⟨slR', hsl'⟩ : ∃ slR', (slotsProveFixedProg Lq' hL20' key' V.bp (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd)
            bga.1 bga.2.1 bga.2.2 8 (true && !outcAlphaBad ch) [] 0 {} ⟨vf (bSl - 1), t'.counter + 2, key'⟩).res (fun _ => default) vf bSl = slR' := ⟨_, rfl⟩
        obtain ⟨mR', hm'⟩ : ∃ mR', (zkBMaskFixedProg Lq' hL20' key' shdP_U shdP_hbij
            (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
            M 8 (levelsOfV vf 12 (outcBase + 2 + 32767 + 3))
            (match slR'.1 with | some (_, _, acc) => acc.fs ++ acc.hostFs | none => []) slR'.2).res (fun _ => default) vf (bSl + 290) = mR' := ⟨_, rfl⟩
        obtain ⟨aOR', ha'⟩ : ∃ aOR', (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 29 76 16 (shdP_outcOpenGeomA V) TA
            (levelsOfV vf 14 (outcBase + 2))
            (match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false)
            (openingHdrOk (shdP_outcOpenGeomA V) 12 (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []))
            (match slR'.1 with | some (_, _, acc) => acc.claims.a | none => []) mR'.2).res
            (fun _ => default) vf (bSl + 290 + 85) = aOR' := ⟨_, rfl⟩
        obtain ⟨hOR', hh'⟩ : ∃ hOR', (openingAuditFixedProg Lq' hL20' key' shdP_stgPrm 14 10 38 5 (shdP_outcOpenGeomH V) TH
            (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2))
            ((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR'.1.isSome)
            (openingHdrOk (shdP_outcOpenGeomH V) 12 (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []))
            (match slR'.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []) aOR'.2).res (fun _ => default) vf (bSl + 290 + 85 + 186) = hOR' := ⟨_, rfl⟩
        obtain ⟨bOR', hb'⟩ : ∃ bOR', (openingAuditFixedProg Lq' hL20' key' Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26
            (((match slR'.1 with | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []) | none => false) && aOR'.1.isSome) && hOR'.1.isSome)
            (openingHdrOk shdP_bndOpenGeom 14 (match slR'.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []))
            (match slR'.1 with | some (_, _, acc) => cr26.pending ++ acc.claims.inp | none => []) hOR'.2).res
            (fun _ => default) vf (bSl + 290 + 85 + 186 + 118) = bOR' := ⟨_, rfl⟩
        rw [hEv hL20' key' st' t' slR' hsl' mR' hm' aOR' ha' hOR' hh' bOR' hb']
        have hSlSame : slR'.1 = some (sps, recs, acc) :=
          (congrArg Prod.fst hsl').symm.trans
            ((slotsProveFixedProg_res_indep_key hL20' hL20 key' key V.bp _ bga.1 bga.2.1 bga.2.2 vf 8 _ [] 0 {} _ _ bSl).trans hSlVal)
        simp only [hSlSame, hAct4] at hm' ha' hh' hb' ⊢
        have hmSame : mR'.1 = mR.1 := by
          rw [← hm', zkBMaskFixedProg_res_eq]; exact hmOEq.symm
        have haSame : aOR'.1 = some aO := by
          rw [← ha', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact haPass), haOEq]
        simp only [haSame, Option.isSome_some, Bool.and_true] at hh' hb' ⊢
        have hhSame : hOR'.1 = some hO := by
          rw [← hh', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact hhPass), hhOEq]
        simp only [hhSame, Option.isSome_some, Bool.and_true] at hb' ⊢
        have hbSame : bOR'.1 = some bO := by
          rw [← hb', openingAuditFixedProg_res_eq, openingAudit_res_of_pass (by simp only [Bool.and_eq_true, decide_eq_true_eq]; exact hbPass), hbOEq]
        rw [hbSame, hmSame]; rfl }

private theorem outc_slots_shape_eq {P : BlockParams} {D₁ D₂ : SlotData P}
    {b g a : Fp2} {vf : ℕ → Dig} {t : Tr} {base : ℕ}
    {sps₁ sps₂ : List SlotProof} {recs₁ recs₂ : List SlotRec} {acc₁ acc₂ : Acc}
    (h1 : ((slotsProveFixedProg (2 ^ 20) le_rfl none P D₁ b g a 8 true [] 0 {} t).res (fun _ => default) vf base).1 = some (sps₁, recs₁, acc₁))
    (h2 : ((slotsProveFixedProg (2 ^ 20) le_rfl none P D₂ b g a 8 true [] 0 {} t).res (fun _ => default) vf base).1 = some (sps₂, recs₂, acc₂)) :
    AccShapeEq acc₁ acc₂ := by
  have hShape := slotsProveFixedProg_shape_indep (2 ^ 20) le_rfl none P P D₁ D₂
    (fun _ => rfl) rfl rfl rfl rfl
    (fun s hist dr => match P.define s hist dr with | .error _ => trivial | .ok _ => ⟨TabsShapeEq.refl _, rfl⟩)
    b g a (fun _ => default) vf 8 true [] [] 0 {} {} t base
    rfl ⟨rfl, rfl, rfl, rfl, ⟨rfl, rfl, rfl, rfl⟩⟩
  dsimp only at hShape
  rw [h1, h2] at hShape
  exact hShape.2

private theorem outc_slots_shape_eq_v {tag : MTag} {Rp : ClassifyRunPublicP shieldS0}
    {wDigest : Dig} {bOutRow v₁ v₂ : ℕ} (hv : v₁ = v₂)
    {D₁ : SlotData (shdVo tag Rp wDigest bOutRow v₁).bp}
    {D₂ : SlotData (shdVo tag Rp wDigest bOutRow v₂).bp}
    {b₁ g₁ a₁ b₂ g₂ a₂ : Fp2} (hb : b₁ = b₂) (hg : g₁ = g₂) (ha : a₁ = a₂)
    {vf : ℕ → Dig} {t : Tr} {base : ℕ}
    {sps₁ sps₂ : List SlotProof} {recs₁ recs₂ : List SlotRec} {acc₁ acc₂ : Acc}
    (h1 : ((slotsProveFixedProg (2 ^ 20) le_rfl none (shdVo tag Rp wDigest bOutRow v₁).bp D₁ b₁ g₁ a₁ 8 true [] 0 {} t).res (fun _ => default) vf base).1 = some (sps₁, recs₁, acc₁))
    (h2 : ((slotsProveFixedProg (2 ^ 20) le_rfl none (shdVo tag Rp wDigest bOutRow v₂).bp D₂ b₂ g₂ a₂ 8 true [] 0 {} t).res (fun _ => default) vf base).1 = some (sps₂, recs₂, acc₂)) :
    AccShapeEq acc₁ acc₂ := by
  subst hv; subst hb; subst hg; subst ha
  exact outc_slots_shape_eq h1 h2

/-- Two active `OutcSegTrace`s with the SAME verdict at `vf` have identical `ch`, `dfs`, `acc.claims.*.map parts`,
and `(acc.fs ++ acc.hostFs).map terms`! -/
theorem outcSegTrace_invar (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) (x₁ x₂ : {x // (classifyModelP Rp).admissible x})
    (hVerd : (classifySpecP Rp x₁.1).getD 0 = (classifySpecP Rp x₂.1).getD 0)
    (c₁ c₂ : ShdCoins) (cr₁ cr₂ : Carry) (vf : ℕ → Dig)
    (T₁ : OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x₁ c₁ cr₁ vf)
    (T₂ : OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x₂ c₂ cr₂ vf) :
    T₁.ch = T₂.ch
      ∧ T₁.dfs = T₂.dfs
      ∧ T₁.acc.claims.a.map Block.ZClaim.parts = T₂.acc.claims.a.map Block.ZClaim.parts
      ∧ T₁.acc.claims.h.map Block.ZClaim.parts = T₂.acc.claims.h.map Block.ZClaim.parts
      ∧ T₁.acc.claims.inp.map Block.ZClaim.parts = T₂.acc.claims.inp.map Block.ZClaim.parts
      ∧ (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
  have hCh : T₁.ch = T₂.ch := T₁.ch_eq.trans T₂.ch_eq.symm
  have hDr : ∀ t : Fin 8, (T₁.recs[t.val]'(by rw [T₁.recs_len]; exact t.isLt)).draws = (T₂.recs[t.val]'(by rw [T₂.recs_len]; exact t.isLt)).draws := fun t => by
    have h1 := (T₁.slot_spec t).2.2.2.1; have h2 := (T₂.slot_spec t).2.2.2.1
    rw [hVerd] at h1; exact h1.trans h2.symm
  have hHist : ∀ m ≤ 8, (T₁.recs.take m).map SlotRec.draws = (T₂.recs.take m).map SlotRec.draws := fun m hm => by
    refine List.ext_getElem (by simp [T₁.recs_len, T₂.recs_len, hm]) fun i hi1 hi2 => ?_
    simp only [List.getElem_map, List.getElem_take]
    exact hDr ⟨i, by simp [T₁.recs_len] at hi1; omega⟩
  have hDfs : T₁.dfs = T₂.dfs := funext fun t => by
    have h1 := (T₁.slot_spec t).2.1; have h2 := (T₂.slot_spec t).2.1
    have hHistEq : Exec.Block.histOf (OutcV.bga T₁.ch).1 (OutcV.bga T₁.ch).2.1 (OutcV.bga T₁.ch).2.2 (T₁.recs.take t.val)
        = Exec.Block.histOf (OutcV.bga T₂.ch).1 (OutcV.bga T₂.ch).2.1 (OutcV.bga T₂.ch).2.2 (T₂.recs.take t.val) := by
      unfold Exec.Block.histOf; rw [hCh, hHist t.val (Nat.le_of_lt t.isLt)]
    rw [hVerd, hHistEq] at h1
    exact Except.ok.inj (h1.symm.trans h2)
  have hCsEq : T₁.acc.cs = T₂.acc.cs := by
    refine List.ext_getElem (by rw [T₁.cs_len, T₂.cs_len]) fun i hi1 hi2 => ?_
    have hi : i < 8 := by rw [← T₁.cs_len]; exact hi1
    have h1 := (T₁.slot_spec ⟨i, hi⟩).2.2.2.2.1; have h2 := (T₂.slot_spec ⟨i, hi⟩).2.2.2.2.1
    rw [hVerd] at h1; exact h1.trans h2.symm
  have hFs : (T₁.acc.fs ++ T₁.acc.hostFs).map Exec.Block.MaskFunctional.terms
      = (T₂.acc.fs ++ T₂.acc.hostFs).map Exec.Block.MaskFunctional.terms := by
    rw [T₁.fs_terms, T₂.fs_terms, hVerd, hDfs]
    exact congrArg (_ ++ ·) (List.filterMap_congr fun t _ => by
      have hAccCs : (T₁.accs t).cs = (T₂.accs t).cs := by
        rw [(T₁.slot_spec t).2.2.1, (T₂.slot_spec t).2.2.1, hCsEq]
      rw [hAccCs])
  have hAccEq : AccShapeEq T₁.acc T₂.acc :=
    outc_slots_shape_eq_v hVerd
      (congrArg (fun c => (OutcV.bga c).1) hCh)
      (congrArg (fun c => (OutcV.bga c).2.1) hCh)
      (congrArg (fun c => (OutcV.bga c).2.2) hCh)
      T₁.sl_res T₂.sl_res
  exact ⟨hCh, hDfs, hAccEq.2.2.2.2.1, hAccEq.2.2.2.2.2.1, hAccEq.2.2.2.2.2.2.1, hFs⟩

/-- Full 28-segment active trace bundle at `(x, c, vf)`. -/
structure FullRunTrace {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (vf : ℕ → Dig) where
  incT : IncSegTrace (Hdr := Hdr) tag Rp embDigest bInRow x.1 c vf
  crAt : Fin 27 → Carry
  crAt_zero : crAt 0 = ⟨incT.acc.claims.out, (levelsOfV vf 16 4104).getRoot⟩
  blkT : (k : Fin 26) → BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k (crAt ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) vf
  crAt_succ : ∀ k : Fin 26, crAt ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩ = ⟨(blkT k).acc.claims.out, (levelsOfV vf 16 (blkBase k)).getRoot⟩
  outcT : OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x c (crAt ⟨26, by omega⟩) vf
  outOf_eq : ∀ {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
      (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
      (refused : ClsStmt Hdr) (blkDig : Fin 26 → Dig) (v : Fin shdP_zkResPts → Dig),
    shdExtV v = vf →
    let G_in := rcIncGeom (shdVi tag Rp embDigest bInRow) 28
    let G_out := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
    let incSeg : StageSeg := ⟨some (levelsOfV vf 16 4104).getRoot,
      ⟨(levelsOfV vf 14 (4104 + 131071 + 5)).getRoot,
       (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot,
       (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot,
       incT.sps, incT.mO, incT.aO, incT.hO⟩, [incT.eO]⟩
    let blkByte : Fin 26 → List UInt8 := fun k =>
      let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
      let stTag := if k.val = 0 then posTagOfV vf (4104 + incSegFixedLen) else posTagOfV vf (blkBase ⟨k.val - 1, by omega⟩ + blkSegFixedLen)
      let eTag := posTagOfV vf (blkBase k + blkSegFixedLen)
      let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
        ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
         (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
         (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
         (blkT k).sps, (blkT k).mO, (blkT k).aO, (blkT k).hO⟩, (blkT k).bO, none⟩
      Exec.Block.encSeg (vf 4101) sg.l sg.k stTag seg eTag
    let outSeg : StageSeg := ⟨none,
      ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
       (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
       (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot,
       outcT.sps, outcT.mO, outcT.aO, outcT.hO⟩, [outcT.bO]⟩
    PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c) v =
      (honestStmt hdr (levelsOfV vf 11 0).getRoot ((classifySpecP Rp x.1).getD 0),
        encStage G_in (vf 4101) (posTagOfV vf 4102) incSeg (posTagOfV vf (4104 + incSegFixedLen)) ::
          (List.ofFn blkByte ++
            [encStage G_out (vf 4101) (posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen))
              outSeg (posTagOfV vf (outcBase + outcSegFixedLen))]))

private theorem shdRunActiveOf_blk_res {α β γ : Type}
    {inc : Option (α × Carry) × MerkleLevels 16 × Tr}
    {blk : Bool → Carry → MerkleLevels 16 → Tr → Option (β × Carry) × MerkleLevels 16 × Tr × Dig}
    {out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option γ × Tr}
    {enc : α} {cr : Carry} {trB : MerkleLevels 16}
    {blkRes : Option (β × Carry) × MerkleLevels 16 × Tr × Dig}
    (hAct : shdRunActiveOf inc blk out)
    (h1 : inc.1 = some (enc, cr)) (h2 : inc.2.1 = trB)
    (hBlkEq : blk true cr trB inc.2.2 = blkRes) :
    blkRes.1.isSome = true := by
  subst hBlkEq
  unfold shdRunActiveOf at hAct
  have hb := hAct.2.1
  rw [h1, h2] at hb
  exact hb

private theorem shdRunActiveOf_out_res {α β γ : Type}
    {inc : Option (α × Carry) × MerkleLevels 16 × Tr}
    {blk : Bool → Carry → MerkleLevels 16 → Tr → Option (β × Carry) × MerkleLevels 16 × Tr × Dig}
    {out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option γ × Tr}
    {enc : α} {cr : Carry} {trB : MerkleLevels 16}
    {blkRes : Option (β × Carry) × MerkleLevels 16 × Tr × Dig}
    {bs : β} {cr26 : Carry} {trB26 : MerkleLevels 16} {st26 : Dig}
    {outRes : Option γ × Tr}
    (hAct : shdRunActiveOf inc blk out)
    (h1 : inc.1 = some (enc, cr)) (h2 : inc.2.1 = trB)
    (hBlkEq : blk true cr trB inc.2.2 = blkRes)
    (hb1 : blkRes.1 = some (bs, cr26))
    (hb2 : blkRes.2.1 = trB26)
    (hb3 : blkRes.2.2.2 = st26)
    (hOutEq : out true cr26 trB26 st26 blkRes.2.2.1 = outRes) :
    outRes.1.isSome = true := by
  subst hOutEq; subst hBlkEq
  unfold shdRunActiveOf at hAct
  have ho := hAct.2.2
  rw [h1, h2] at ho
  dsimp only [Option.isSome_some, carryOf] at ho
  rw [hb1, hb2, hb3] at ho
  exact ho

private def blkTraceCast {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₂ cr₂ vf := by
  subst hk; subst hcr; exact T

private theorem blkTraceCast_fields {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).acc = T.acc ∧ (blkTraceCast hk hcr T).sps = T.sps ∧
    (blkTraceCast hk hcr T).mO = T.mO ∧ (blkTraceCast hk hcr T).aO = T.aO ∧
    (blkTraceCast hk hcr T).hO = T.hO ∧ (blkTraceCast hk hcr T).bO = T.bO := by
  subst hk; subst hcr; exact ⟨rfl, rfl, rfl, rfl, rfl, rfl⟩

private theorem blkTraceCast_sps {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).sps = T.sps := (blkTraceCast_fields hk hcr T).2.1

private theorem blkTraceCast_mO {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).mO = T.mO := (blkTraceCast_fields hk hcr T).2.2.1

private theorem blkTraceCast_aO {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).aO = T.aO := (blkTraceCast_fields hk hcr T).2.2.2.1

private theorem blkTraceCast_hO {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).hO = T.hO := (blkTraceCast_fields hk hcr T).2.2.2.2.1

private theorem blkTraceCast_bO {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {k₁ k₂ : Fin 26} {cr₁ cr₂ : Carry} (hk : k₁ = k₂) (hcr : cr₁ = cr₂)
    (T : BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c k₁ cr₁ vf) :
    (blkTraceCast hk hcr T).bO = T.bO := (blkTraceCast_fields hk hcr T).2.2.2.2.2

private def blkStepCarry {α β : Type} (c0 : β) : Option (α × β) → β
  | some (_, c') => c'
  | none => c0

private def blkStepCombine {E D β γ δ : Type} (eTag : E)
    (bR : Option ((E → D) × β) × γ × δ) (rest : Option (List D × β) × γ × δ × E) :
    Option (List D × β) × γ × δ × E :=
  (match bR.1, rest.1 with
   | some (enc, _), some (bs, crOut) => some (enc eTag :: bs, crOut)
   | _, _ => none, rest.2.1, rest.2.2.1, rest.2.2.2)

private theorem blkStep_fst_active {E D β γ δ : Type} {eTag : E}
    {whole : Option (List D × β) × γ × δ × E}
    {bR : Option ((E → D) × β) × γ × δ} {rest : Option (List D × β) × γ × δ × E}
    (hU : whole = blkStepCombine eTag bR rest)
    (h : whole.1.isSome = true) :
    bR.1.isSome = true := by
  rw [hU] at h; unfold blkStepCombine at h
  rcases bR with ⟨_ | _, _⟩
  · cases h
  · rfl

private theorem blkStep_snd_active_of {E D β γ δ : Type} (c0 : β) {eTag : E}
    {whole : Option (List D × β) × γ × δ × E}
    (bR : Option ((E → D) × β) × γ × δ)
    (rest : Bool → β → γ → δ → Option (List D × β) × γ × δ × E)
    {enc : E → D} {cr1 : β} {tr1 : γ}
    (hU : whole = blkStepCombine eTag bR (rest bR.1.isSome (blkStepCarry c0 bR.1) bR.2.1 bR.2.2))
    (hb1 : bR.1 = some (enc, cr1)) (hb2 : bR.2.1 = tr1)
    (h : whole.1.isSome = true) :
    (rest true cr1 tr1 bR.2.2).1.isSome = true := by
  rw [hU] at h; unfold blkStepCombine at h
  rw [hb1, hb2] at h
  dsimp only [Option.isSome_some, blkStepCarry] at h
  cases hr : (rest true cr1 tr1 bR.2.2).1
  · rw [hr] at h; cases h
  · rfl

private theorem blkStep_out_of {E D β γ δ : Type} (c0 : β) {eTag : E}
    {whole : Option (List D × β) × γ × δ × E}
    (bR : Option ((E → D) × β) × γ × δ)
    (rest : Bool → β → γ → δ → Option (List D × β) × γ × δ × E)
    {enc : E → D} {cr1 : β} {tr1 : γ}
    {bs : List D} {crOut : β} {trOut : γ} {eOut : E}
    (hU : whole = blkStepCombine eTag bR (rest bR.1.isSome (blkStepCarry c0 bR.1) bR.2.1 bR.2.2))
    (hb1 : bR.1 = some (enc, cr1)) (hb2 : bR.2.1 = tr1)
    (hr1 : (rest true cr1 tr1 bR.2.2).1 = some (bs, crOut))
    (hr2 : (rest true cr1 tr1 bR.2.2).2.1 = trOut)
    (hr3 : (rest true cr1 tr1 bR.2.2).2.2.2 = eOut) :
    whole.1 = some (enc eTag :: bs, crOut)
    ∧ whole.2.1 = trOut
    ∧ whole.2.2.2 = eOut := by
  rw [hU]; unfold blkStepCombine
  rw [hb1, hb2]
  dsimp only [Option.isSome_some, blkStepCarry]
  rw [hr1, hr2, hr3]
  exact ⟨rfl, rfl, rfl⟩

private def shdBndIdx (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26) : Fin 27 :=
  ⟨startIdx, by omega⟩

private theorem blkChain_res_eq {Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {tag : MTag} {key : Option Dig} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {blkDig : Fin 26 → Dig}
    {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins} {vf : ℕ → Dig}
    {s cnt : ℕ} {h1 h2 : s + cnt ≤ 26} {act : Bool}
    {cr1 cr2 : Carry} {tr1 tr2 : MerkleLevels 16} {st : Dig} {t1 t2 : Tr} {b1 b2 : ℕ}
    (hcr : cr1 = cr2) (htr : tr1 = tr2) (ht : t1 = t2) (hb : b1 = b2) :
    (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x.1 x.2 c s cnt h1 act cr1 tr1 (vf 4101) st t1).res (fun _ => default) vf b1 =
    (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x.1 x.2 c s cnt h2 act cr2 tr2 (vf 4101) st t2).res (fun _ => default) vf b2 := by
  have hh : h1 = h2 := Subsingleton.elim h1 h2
  subst hh; subst hcr; subst htr; subst ht; subst hb; rfl

private theorem outcSeg_res_eq {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {tag : MTag} {key : Option Dig} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid} {houtPub : Rp.out.Valid}
    {wDigest : Dig} {bOutRow : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins}
    {vf : ℕ → Dig} {cr1 cr2 : Carry} {tr1 tr2 : MerkleLevels 16} {st1 st2 : Dig} {t : Tr} {b1 b2 : ℕ}
    (hcr : cr1 = cr2) (htr : tr1 = tr2) (hst : st1 = st2) (hb : b1 = b2) :
    (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x.1 x.2 c true cr1 tr1 (vf 4101) st1 t).res (fun _ => default) vf b1 =
    (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x.1 x.2 c true cr2 tr2 (vf 4101) st2 t).res (fun _ => default) vf b2 := by
  subst hcr; subst htr; subst hst; subst hb; rfl

private theorem blkChain_step_unfold {Hdr : Type} {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq')
    (tag : MTag) (key' : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig' : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (vf : ℕ → Dig)
    (startIdx m : ℕ) (hEnd : startIdx + (m + 1) ≤ 26) (hNextEnd : startIdx + 1 + m ≤ 26)
    (k0 : Fin 26) (hk0 : k0.val = startIdx)
    (crIn : Carry) (trIn : MerkleLevels 16) (stTag : Dig) (t' : Tr) :
    (blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
      x.1 x.2 c startIdx (m + 1) hEnd true crIn trIn (vf 4101) stTag t').res
      (fun _ => default) vf (209507 + blkStepFixedLen * startIdx) =
    blkStepCombine (posTagOfV vf (blkBase k0 + blkSegFixedLen))
      ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0))
      ((blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c (startIdx + 1) m hNextEnd
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).1.isSome
        (blkStepCarry carry0 ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).1)
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).2.1
        (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen))
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).2.2).res
        (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1))) := by
  have hLhsEq : blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
      x.1 x.2 c startIdx (m + 1) hEnd true crIn trIn (vf 4101) stTag t' =
    (blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t').andThen fun bR =>
      (posTagKeyed Lq' (by omega) key' bR.2.2).andThen fun endTag =>
        let active' := bR.1.isSome
        let cr' := match bR.1 with | some (_, c') => c' | none => carry0
        (blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c (startIdx + 1) m hNextEnd active' cr' bR.2.1 (vf 4101) endTag bR.2.2).andThen fun rest =>
          match bR.1, rest.1 with
          | some (enc, _), some (bs, crOut) =>
            .ret (some (enc endTag :: bs, crOut), rest.2.1, rest.2.2.1, rest.2.2.2)
          | _, _ => .ret (none, rest.2.1, rest.2.2.1, rest.2.2.2) := by
    have hk0' : k0 = ⟨startIdx, Nat.lt_of_lt_of_le (Nat.lt_add_of_pos_right (Nat.succ_pos m)) hEnd⟩ := Fin.ext hk0
    subst hk0'
    conv_lhs => simp only [blkChainFixedProg]
    rfl
  rw [hLhsEq]
  have hb1 : 209507 + blkStepFixedLen * startIdx = blkBase k0 := by unfold blkBase; rw [hk0]
  have hp1 := blkSegFixedProg_ptLen (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
    x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t'
  have hp3 : ∀ act cr tr bnd e t, (blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
      x.1 x.2 c (startIdx + 1) m hNextEnd act cr tr bnd e t).PtLen (blkStepFixedLen * m) :=
    fun act cr tr bnd e t => blkChainFixedProg_ptLen (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
      x.1 x.2 c (startIdx + 1) m hNextEnd act cr tr bnd e t
  generalize blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
    x.1 x.2 c k0 true crIn trIn (vf 4101) stTag t' = p1 at hp1 ⊢
  generalize blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
    x.1 x.2 c (startIdx + 1) m hNextEnd = p3 at hp3 ⊢
  rw [PProg.res_andThen _ _ _ _ _ _ hp1,
      PProg.res_andThen _ _ _ _ _ _ (posTagKeyed_ptLen Lq' (by omega) key' _),
      posTagKeyed_res,
      PProg.res_andThen _ _ _ _ _ _ (hp3 _ _ _ _ _ _)]
  rw [hb1, show blkBase k0 + blkSegFixedLen + 2 = 209507 + blkStepFixedLen * (startIdx + 1) by unfold blkBase blkStepFixedLen; rw [hk0]; ring]
  unfold blkStepCombine
  generalize p1.res (fun _ => default) vf (blkBase k0) = bR
  rcases bR with ⟨_ | ⟨enc, cr1⟩, bRest⟩
  · dsimp only [blkStepCarry]; simp only [Option.isSome_none]
    generalize (p3 false carry0 bRest.1 (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen)) bRest.2).res
      (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1)) = rest
    rcases rest with ⟨_ | ⟨bs, crOut⟩, rRest⟩ <;> rfl
  · dsimp only [blkStepCarry]; simp only [Option.isSome_some]
    generalize (p3 true cr1 bRest.1 (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen)) bRest.2).res
      (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1)) = rest
    rcases rest with ⟨_ | ⟨bs, crOut⟩, rRest⟩ <;> rfl

private theorem shdRunOutOf_eq_some_res {Hdr : Type}
    (hdr : Hdr) (refused : ClsStmt Hdr) (v : Fin shdP_zkResPts → Dig) (verdict : ℕ)
    {inc : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr}
    {blk : Bool → Carry → MerkleLevels 16 → Tr → Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig}
    {out : Bool → Carry → MerkleLevels 16 → Dig → Tr → Option (Dig → List UInt8) × Tr}
    {incEnc : Dig → List UInt8} {cr0 : Carry} {trB0 : MerkleLevels 16}
    {blkRes : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig}
    {blkBs blkBs' : List (List UInt8)} {cr26 : Carry} {trB26 : MerkleLevels 16} {eBlk : Dig}
    {outRes : Option (Dig → List UInt8) × Tr} {outEnc : Dig → List UInt8} {bOut : ℕ}
    (hbOut : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = bOut)
    (hInc1 : inc.1 = some (incEnc, cr0)) (hIncTr : inc.2.1 = trB0)
    (hBlkEq : blk true cr0 trB0 inc.2.2 = blkRes)
    (hBlk1 : blkRes.1 = some (blkBs, cr26))
    (hBlkTr : blkRes.2.1 = trB26)
    (hBlkE : blkRes.2.2.2 = eBlk)
    (hblkBs : blkBs = blkBs')
    (hOutEq : out true cr26 trB26 eBlk blkRes.2.2.1 = outRes)
    (hOut1 : outRes.1 = some outEnc) :
    shdRunOutOf hdr refused v verdict inc blk out =
      (honestStmt hdr (levelsOfV (shdExtV v) 11 0).getRoot verdict,
        incEnc (posTagOfV (shdExtV v) (4104 + incSegFixedLen)) ::
          (blkBs' ++ [outEnc (posTagOfV (shdExtV v) (bOut + outcSegFixedLen))])) := by
  subst hbOut; subst hblkBs; subst hBlkEq; subst hOutEq
  exact shdRunOutOf_eq_some hdr refused v verdict hInc1 hIncTr rfl hBlk1 hBlkTr rfl hBlkE hOut1

private def shdBnd26 : Fin 27 := ⟨26, by decide⟩

private noncomputable def outcSeg_extract_26 (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
    (cr26 : Carry) (startTag : Dig) (t : Tr) (vf : ℕ → Dig)
    (hAct : ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x.1 x.2 c true cr26 (levelsOfV vf 16 (shdTreeBase (.bnd shdBnd26)))
        (vf 4101) startTag t).res (fun _ => default) vf outcBase).1.isSome = true) :
    OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x c cr26 vf :=
  outcSeg_extract Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x c cr26 startTag t vf
    ((congrArg (fun r => r.1.isSome) (outcSeg_res_eq rfl
      (congrArg (fun k : Fin 27 => levelsOfV vf 16 (shdTreeBase (.bnd k))) (Fin.ext rfl)) rfl rfl)).symm.trans hAct)

private theorem OutcSegTrace.out_eq_clean {tag : MTag} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid} {houtPub : Rp.out.Valid}
    {wDigest : Dig} {bOutRow : ℕ} {x : {x // (classifyModelP Rp).admissible x}} {c : ShdCoins}
    {cr26 : Carry} {vf : ℕ → Dig}
    (T : OutcSegTrace tag Rp hR hweights hinPub houtPub wDigest bOutRow x c cr26 vf)
    {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) (startTag : Dig) (t : Tr) :
    ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x.1 x.2 c true cr26 (levelsOfV vf 16 (shdTreeBase (.bnd shdBnd26))) (vf 4101) startTag t).res
        (fun _ => default) vf outcBase).1
      = some (fun e => encStage (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) (vf 4101) startTag
          ⟨none, ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
            (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
            (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot,
            T.sps, T.mO, T.aO, T.hO⟩, [T.bO]⟩ e) :=
  (congrArg Prod.fst (outcSeg_res_eq rfl
    (congrArg (fun k : Fin 27 => levelsOfV vf 16 (shdTreeBase (.bnd k))) (Fin.ext rfl)) rfl rfl)).trans
    (T.out_eq hL20 key startTag t)

/-- Generic inductive extractor over `blkChainFixedProg startIdx count`! -/
private theorem blkChain_extract_ex {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (vf : ℕ → Dig)
    (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
    (crIn : Carry) (stTag : Dig) (tIn : Tr)
    (hCAct :
      ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c startIdx count hEnd true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx count hEnd))))
        (vf 4101) stTag tIn).res (fun _ => default) vf (209507 + blkStepFixedLen * startIdx)).1.isSome = true) :
    Nonempty (Σ' (crs : (j : Fin (count + 1)) → Carry)
      (bTs : (j : Fin count) → BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c ⟨j.val + startIdx, by omega⟩ (crs ⟨j.val, Nat.lt_succ_of_lt j.isLt⟩) vf),
      crs 0 = crIn
      ∧ (∀ j : Fin count, crs ⟨j.val + 1, Nat.succ_lt_succ j.isLt⟩ =
          ⟨(bTs j).acc.claims.out, (levelsOfV vf 16 (blkBase ⟨j.val + startIdx, by omega⟩)).getRoot⟩)
      ∧ (∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig) (blkDig' : Fin 26 → Dig) (t' : Tr),
          let blkByte : Fin count → List UInt8 := fun j =>
            let k : Fin 26 := ⟨j.val + startIdx, by omega⟩
            let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
            let sTag := if j.val = 0 then stTag else posTagOfV vf (blkBase ⟨j.val + startIdx - 1, by omega⟩ + blkSegFixedLen)
            let eTag := posTagOfV vf (blkBase k + blkSegFixedLen)
            let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
              ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
               (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
               (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
               (bTs j).sps, (bTs j).mO, (bTs j).aO, (bTs j).hO⟩, (bTs j).bO, none⟩
            Exec.Block.encSeg (vf 4101) sg.l sg.k sTag seg eTag
          ((blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
            x.1 x.2 c startIdx count hEnd true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx count hEnd))))
            (vf 4101) stTag t').res (fun _ => default) vf (209507 + blkStepFixedLen * startIdx)).1
            = some (List.ofFn blkByte, crs ⟨count, Nat.lt_succ_self _⟩)
          ∧ ((blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
            x.1 x.2 c startIdx count hEnd true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx count hEnd))))
            (vf 4101) stTag t').res (fun _ => default) vf (209507 + blkStepFixedLen * startIdx)).2.1
            = levelsOfV vf 16 (shdTreeBase (.bnd ⟨count + startIdx, by omega⟩))
          ∧ ((blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
            x.1 x.2 c startIdx count hEnd true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx count hEnd))))
            (vf 4101) stTag t').res (fun _ => default) vf (209507 + blkStepFixedLen * startIdx)).2.2.2
            = (if count = 0 then stTag else posTagOfV vf (blkBase ⟨count + startIdx - 1, by omega⟩ + blkSegFixedLen)))) := by
  classical
  induction count generalizing startIdx crIn stTag tIn with
  | zero =>
    refine ⟨⟨fun _ => crIn, fun j => j.elim0, rfl, fun j => j.elim0, fun {Lq'} hL20' key' blkDig' t' => ?_⟩⟩
    dsimp only [blkChainFixedProg, PProg.res]
    rw [ite_eq_left rfl, ite_eq_left rfl, List.ofFn_zero]
    exact ⟨rfl, congrArg (fun k : Fin 27 => levelsOfV vf 16 (shdTreeBase (.bnd k))) (Fin.ext (Nat.zero_add startIdx).symm), rfl⟩
  | succ m ih =>
    let k0 : Fin 26 := ⟨startIdx, by omega⟩
    have hNextEnd : startIdx + 1 + m ≤ 26 := by omega
    have hTreeK0 : shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd)) = shdTreeBase (.bnd ⟨k0.val, Nat.lt_succ_of_lt k0.isLt⟩) := rfl
    have hTreeNext : shdTreeBase (.bnd (shdBndIdx (startIdx + 1) m hNextEnd)) = blkBase k0 := by
      unfold shdTreeBase shdBndIdx blkBase k0; simp
    have hU0 := blkChain_step_unfold (Hdr := Hdr) hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x c vf startIdx m hEnd hNextEnd k0 rfl crIn
      (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd)))) stTag tIn
    have hB0Act : ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd ⟨k0.val, Nat.lt_succ_of_lt k0.isLt⟩)))
        (vf 4101) stTag tIn).res (fun _ => default) vf (blkBase k0)).1.isSome = true := by
      rw [← hTreeK0]
      exact blkStep_fst_active hU0 hCAct
    let bT0 := blkSeg_extract (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x c k0 crIn stTag tIn vf hB0Act
    have hb0Tree : ∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig) (blkDig' : Fin 26 → Dig) (t' : Tr),
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).2.1
          = levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx (startIdx + 1) m hNextEnd))) := fun hL20' key' blkDig' t' =>
      (blkSegFixedProg_res_tree (Hdr := Hdr) _ hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
        (vf 4101) stTag t' vf (blkBase k0)).trans (congrArg (levelsOfV vf 16) hTreeNext.symm)
    have hRestAct : ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c (startIdx + 1) m hNextEnd true
        ⟨bT0.acc.claims.out, (levelsOfV vf 16 (blkBase k0)).getRoot⟩
        (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx (startIdx + 1) m hNextEnd))))
        (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen))
        ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag tIn).res (fun _ => default) vf (blkBase k0)).2.2).res
        (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1))).1.isSome = true := by
      have hB0Eq := bT0.out_eq (Hdr := Hdr) hL20 key blkDig stTag tIn
      rw [← hTreeK0] at hB0Eq
      exact blkStep_snd_active_of carry0
        ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag tIn).res (fun _ => default) vf (blkBase k0))
        (fun act cr' tr' t' => (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x.1 x.2 c (startIdx + 1) m hNextEnd act cr' tr' (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen)) t').res
          (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1)))
        hU0 hB0Eq (hb0Tree hL20 key blkDig tIn) hCAct
    obtain ⟨⟨crsR, bTsR, hCrR0, hCrRSucc, hOutR⟩⟩ :=
      ih (startIdx + 1) hNextEnd
        ⟨bT0.acc.claims.out, (levelsOfV vf 16 (blkBase k0)).getRoot⟩
        (posTagOfV vf (blkBase k0 + blkSegFixedLen))
        ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag tIn).res (fun _ => default) vf (blkBase k0)).2.2
        hRestAct
    let crs : Fin (m + 2) → Carry := Fin.cons crIn crsR
    let bTs : (j : Fin (m + 1)) → BlkSegTrace tag Rp hR hweights hinPub ioIn ioOut x c
        ⟨j.val + startIdx, by omega⟩ (crs ⟨j.val, Nat.lt_succ_of_lt j.isLt⟩) vf :=
      fun j =>
        if h0 : j.val = 0 then
          have hidx : k0 = ⟨j.val + startIdx, by omega⟩ := Fin.ext (by dsimp [k0]; omega)
          have hcr : crIn = crs ⟨j.val, Nat.lt_succ_of_lt j.isLt⟩ := by
            have : (⟨j.val, Nat.lt_succ_of_lt j.isLt⟩ : Fin (m + 2)) = 0 := Fin.ext h0
            rw [this]; rfl
          blkTraceCast hidx hcr bT0
        else
          let j' : Fin m := ⟨j.val - 1, by omega⟩
          have hidx : (⟨j'.val + (startIdx + 1), by omega⟩ : Fin 26) = ⟨j.val + startIdx, by omega⟩ := Fin.ext (by dsimp [j']; omega)
          have hcr : crsR ⟨j'.val, Nat.lt_succ_of_lt j'.isLt⟩ = crs ⟨j.val, Nat.lt_succ_of_lt j.isLt⟩ := by
            have : (⟨j.val, Nat.lt_succ_of_lt j.isLt⟩ : Fin (m + 2)) = (⟨j'.val, Nat.lt_succ_of_lt j'.isLt⟩ : Fin (m + 1)).succ :=
              Fin.ext (by dsimp [j']; omega)
            rw [this]; rfl
          blkTraceCast hidx hcr (bTsR j')
    refine ⟨⟨crs, bTs, rfl, ?_, ?_⟩⟩
    · intro j
      by_cases h0 : j.val = 0
      · have h1 : (⟨j.val + 1, Nat.succ_lt_succ j.isLt⟩ : Fin (m + 2)) = (0 : Fin (m + 1)).succ := Fin.ext (by simp [h0])
        rw [h1]; change crsR 0 = _; rw [hCrR0]
        dsimp -zetaDelta only [bTs]; rw [dite_eq_left h0, (blkTraceCast_fields _ _ bT0).1]
        have hidx : (⟨j.val + startIdx, by omega⟩ : Fin 26) = k0 := Fin.ext (by dsimp [k0]; omega)
        rw [hidx]
      · let j' : Fin m := ⟨j.val - 1, by omega⟩
        have h1 : (⟨j.val + 1, Nat.succ_lt_succ j.isLt⟩ : Fin (m + 2)) = (⟨j'.val + 1, Nat.succ_lt_succ j'.isLt⟩ : Fin (m + 1)).succ :=
          Fin.ext (by simp [j']; omega)
        rw [h1]; change crsR ⟨j'.val + 1, Nat.succ_lt_succ j'.isLt⟩ = _; rw [hCrRSucc j']
        dsimp -zetaDelta only [bTs]; rw [dite_eq_right h0, (blkTraceCast_fields _ _ (bTsR j')).1]
        have hidx : (⟨j.val + startIdx, by omega⟩ : Fin 26) = ⟨j'.val + (startIdx + 1), by omega⟩ := Fin.ext (by dsimp [j']; omega)
        rw [hidx]
    · intro Lq' hL20' key' blkDig' t'
      have hU' := blkChain_step_unfold (Hdr := Hdr) hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x c vf startIdx m hEnd hNextEnd k0 rfl crIn
        (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd)))) stTag t'
      have hB0Eq' := bT0.out_eq (Hdr := Hdr) hL20' key' blkDig' stTag t'
      rw [← hTreeK0] at hB0Eq'
      obtain ⟨hR1, hR2, hR3⟩ := hOutR hL20' key' blkDig'
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0)).2.2
      obtain ⟨hS1, hS2, hS3⟩ := blkStep_out_of carry0
        ((blkSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c k0 true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx (m + 1) hEnd))))
          (vf 4101) stTag t').res (fun _ => default) vf (blkBase k0))
        (fun act cr' tr' t'' => (blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
          x.1 x.2 c (startIdx + 1) m hNextEnd act cr' tr' (vf 4101) (posTagOfV vf (blkBase k0 + blkSegFixedLen)) t'').res
          (fun _ => default) vf (209507 + blkStepFixedLen * (startIdx + 1)))
        hU' hB0Eq' (hb0Tree hL20' key' blkDig' t') hR1 hR2 hR3
      have hbTs0 : (bTs 0).sps = bT0.sps ∧ (bTs 0).mO = bT0.mO ∧ (bTs 0).aO = bT0.aO ∧ (bTs 0).hO = bT0.hO ∧ (bTs 0).bO = bT0.bO := by
        dsimp -zetaDelta only [bTs]; rw [dite_eq_left (Fin.val_zero _)]
        exact (blkTraceCast_fields _ _ bT0).2
      have hbTsS : ∀ (i : Fin m), (bTs i.succ).sps = (bTsR i).sps ∧ (bTs i.succ).mO = (bTsR i).mO
          ∧ (bTs i.succ).aO = (bTsR i).aO ∧ (bTs i.succ).hO = (bTsR i).hO ∧ (bTs i.succ).bO = (bTsR i).bO := fun i => by
        dsimp -zetaDelta only [bTs]; rw [dite_eq_right (show i.succ.val ≠ 0 by simp)]
        rw [blkTraceCast_sps, blkTraceCast_mO, blkTraceCast_aO, blkTraceCast_hO, blkTraceCast_bO]
        have hsub : (⟨i.succ.val - 1, by rw [Fin.val_succ, Nat.add_sub_cancel]; exact i.isLt⟩ : Fin m) = i :=
          Fin.ext (Nat.add_sub_cancel i.val 1)
        exact ⟨congrArg (fun j => (bTsR j).sps) hsub, congrArg (fun j => (bTsR j).mO) hsub,
          congrArg (fun j => (bTsR j).aO) hsub, congrArg (fun j => (bTsR j).hO) hsub,
          congrArg (fun j => (bTsR j).bO) hsub⟩
      refine ⟨hS1.trans ?_, hS2.trans ?_, hS3.trans ?_⟩
      · refine congrArg (fun l => some (l, crsR ⟨m, Nat.lt_succ_self _⟩)) ?_
        rw [List.ofFn_succ]
        refine congrArg₂ List.cons ?_ ?_
        · dsimp -zetaDelta only
          rw [hbTs0.1, hbTs0.2.1, hbTs0.2.2.1, hbTs0.2.2.2.1, hbTs0.2.2.2.2, ite_eq_left (Fin.val_zero _)]
          have hidx : (⟨(0 : Fin (m + 1)).val + startIdx, by omega⟩ : Fin 26) = k0 := Fin.ext (by dsimp [k0]; omega)
          have hidxN : (0 : Fin (m + 1)).val + startIdx = k0.val := by dsimp [k0]; omega
          rw [hidx, hidxN]
        · refine List.ext_getElem (by simp) fun i hi1 hi2 => ?_
          have hi : i < m := by simpa using hi1
          simp only [List.getElem_ofFn]
          have hS := hbTsS ⟨i, hi⟩
          have hne0 : (⟨i, hi⟩ : Fin m).succ.val ≠ 0 := Nat.succ_ne_zero i
          have hidx : (⟨(⟨i, hi⟩ : Fin m).succ.val + startIdx, by omega⟩ : Fin 26) = ⟨i + (startIdx + 1), by omega⟩ := Fin.ext (by dsimp; omega)
          have hsg : Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (i + (startIdx + 1) + 1) 38 2
              = Exec.Block.R13.segGeom shdP_blkGeom50 0 28 ((⟨i, hi⟩ : Fin m).succ.val + startIdx + 1) 38 2 :=
            congrArg (fun n => Exec.Block.R13.segGeom shdP_blkGeom50 0 28 n 38 2) (by simp only [Fin.val_succ]; omega)
          have hst : (if i = 0 then posTagOfV vf (blkBase k0 + blkSegFixedLen)
              else posTagOfV vf (blkBase ⟨i + (startIdx + 1) - 1, by omega⟩ + blkSegFixedLen))
              = posTagOfV vf (blkBase ⟨(⟨i, hi⟩ : Fin m).succ.val + startIdx - 1, by omega⟩ + blkSegFixedLen) := by
            by_cases hi0 : i = 0
            · subst hi0; rw [ite_eq_left rfl]; exact congrArg (fun k : Fin 26 => posTagOfV vf (blkBase k + blkSegFixedLen)) (Fin.ext (by dsimp [k0]; omega))
            · rw [ite_eq_right hi0]; exact congrArg (fun k : Fin 26 => posTagOfV vf (blkBase k + blkSegFixedLen)) (Fin.ext (by dsimp; omega))
          rw [hS.1, hS.2.1, hS.2.2.1, hS.2.2.2.1, hS.2.2.2.2, ite_eq_right hne0, hst, hidx, hsg]
      · exact congrArg (fun k : Fin 27 => levelsOfV vf 16 (shdTreeBase (.bnd k))) (Fin.ext (by dsimp; omega))
      · rw [ite_eq_right (Nat.succ_ne_zero m)]
        cases m with
        | zero => rw [ite_eq_left rfl]; exact congrArg (fun k : Fin 26 => posTagOfV vf (blkBase k + blkSegFixedLen)) (Fin.ext (by dsimp [k0]; omega))
        | succ m' => rw [ite_eq_right (Nat.succ_ne_zero m')]; exact congrArg (fun k : Fin 26 => posTagOfV vf (blkBase k + blkSegFixedLen)) (Fin.ext (by dsimp; omega))

/-- Generic inductive extractor over `blkChainFixedProg startIdx count`! -/
private noncomputable def blkChain_extract {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (vf : ℕ → Dig)
    (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
    (crIn : Carry) (stTag : Dig) (tIn : Tr)
    (hCAct :
      ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x.1 x.2 c startIdx count hEnd true crIn (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx startIdx count hEnd))))
        (vf 4101) stTag tIn).res (fun _ => default) vf (209507 + blkStepFixedLen * startIdx)).1.isSome = true) :=
  Classical.choice (blkChain_extract_ex (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x c vf startIdx count hEnd crIn stTag tIn hCAct)

private theorem fullRunTrace_of_active_ex {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig)
    (hng : ¬ shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v) :
    Nonempty (FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow x c (shdExtV v)) := by
  classical
  have hAct := not_shdRunRefused_active (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub
    ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c v hng
  generalize shdExtV v = vf at hAct ⊢
  unfold shdRunActive at hAct
  have hIncAct : ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).1.isSome = true :=
    hAct.1
  obtain ⟨incT⟩ : Nonempty _ := ⟨incSeg_extract (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c vf hIncAct⟩
  have hIncRes := incT.out_eq hL20 key
  dsimp -zetaDelta only at hIncRes
  have hIncTr : ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).2.1
      = levelsOfV vf 16 4104 :=
    incSegFixedProg_res_tree (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩ vf 4104
  let tInc : Tr := ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).2.2
  let cr0 : Carry := ⟨incT.acc.claims.out, (levelsOfV vf 16 4104).getRoot⟩
  have hEnd26 : 0 + 26 ≤ 26 := by omega
  have hBase0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
  have hTr0 : levelsOfV vf 16 4104 = levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx 0 26 hEnd26))) := rfl
  have hcr0Def : cr0 = ⟨incT.acc.claims.out, (levelsOfV vf 16 4104).getRoot⟩ := rfl
  have htIncDef : tInc = ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104).2.2 := rfl
  have hBlkEq0 := blkChain_res_eq (Hdr := Hdr) (Lq := Lq) (hL20 := hL20) (tag := tag) (key := key)
    (Rp := Rp) (hR := hR) (hweights := hweights) (hinPub := hinPub) (ioIn := ioIn) (ioOut := ioOut) (blkDig := blkDig)
    (x := x) (c := c) (vf := vf) (s := 0) (cnt := 26) (h1 := by omega) (h2 := hEnd26) (act := true)
    (st := posTagOfV vf (4104 + incSegFixedLen)) hcr0Def.symm hTr0 htIncDef.symm hBase0
  have hBlkAct0 := shdRunActiveOf_blk_res hAct hIncRes hIncTr hBlkEq0
  obtain ⟨crs, bTs, hCr0, hCrSucc, hChainOut⟩ :=
    blkChain_extract (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x c vf
      0 26 hEnd26 cr0 (posTagOfV vf (4104 + incSegFixedLen)) tInc hBlkAct0
  have hChOut := hChainOut hL20 key blkDig tInc
  have hB26 : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = outcBase := by rw [outcBase_eq]; unfold incSegFixedLen; omega
  have hOutEq0 := outcSeg_res_eq (Lq := Lq) (hL20 := hL20) (tag := tag) (key := key)
    (Rp := Rp) (hR := hR) (hweights := hweights) (hinPub := hinPub) (houtPub := houtPub)
    (wDigest := wDigest) (bOutRow := bOutRow) (x := x) (c := c) (vf := vf)
    (t := ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x.1 x.2 c 0 26 hEnd26 true cr0 (levelsOfV vf 16 (shdTreeBase (.bnd (shdBndIdx 0 26 hEnd26))))
      (vf 4101) (posTagOfV vf (4104 + incSegFixedLen)) tInc).res (fun _ => default) vf (209507 + blkStepFixedLen * 0)).2.2.1)
    (congrArg crs (Fin.ext rfl) : crs ⟨26, Nat.lt_succ_self 26⟩ = crs shdBnd26)
    (congrArg (fun k : Fin 27 => levelsOfV vf 16 (shdTreeBase (.bnd k))) (Fin.ext rfl) :
      levelsOfV vf 16 (shdTreeBase (.bnd ⟨26 + 0, by omega⟩)) = levelsOfV vf 16 (shdTreeBase (.bnd shdBnd26)))
    (congrArg (fun k : Fin 26 => posTagOfV vf (blkBase k + blkSegFixedLen)) (Fin.ext rfl) :
      posTagOfV vf (blkBase ⟨26 + 0 - 1, by omega⟩ + blkSegFixedLen) = posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen))
    hB26
  have hOutAct0 := shdRunActiveOf_out_res hAct hIncRes hIncTr hBlkEq0
    hChOut.1 hChOut.2.1 (hChOut.2.2.trans (ite_eq_right (by decide : (26 : ℕ) ≠ 0))) hOutEq0
  obtain ⟨outcT⟩ : Nonempty _ := ⟨outcSeg_extract_26 Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x c
    (crs shdBnd26) (posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen)) _ vf hOutAct0⟩
  have hOutOf : ∀ {Lq' : ℕ} (hL20' : 2 ^ 20 ≤ Lq') (key' : Option Dig) (hw : Hdr → ClsHdrW) (hdr : Hdr)
      (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq')
      (refused : ClsStmt Hdr) (blkDig' : Fin 26 → Dig) (v' : Fin shdP_zkResPts → Dig),
      shdExtV v' = vf →
      let G_in := rcIncGeom (shdVi tag Rp embDigest bInRow) 28
      let G_out := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
      let incSeg : StageSeg := ⟨some (levelsOfV vf 16 4104).getRoot,
        ⟨(levelsOfV vf 14 (4104 + 131071 + 5)).getRoot,
         (levelsOfV vf 14 (4104 + 131071 + 5 + 32767 + 3 + 8191 + 1 + 15)).getRoot,
         (levelsOfV vf 12 (4104 + 131071 + 5 + 32767 + 3)).getRoot,
         incT.sps, incT.mO, incT.aO, incT.hO⟩, [incT.eO]⟩
      let blkByte : Fin 26 → List UInt8 := fun k =>
        let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
        let stTag := if k.val = 0 then posTagOfV vf (4104 + incSegFixedLen) else posTagOfV vf (blkBase ⟨k.val - 1, by omega⟩ + blkSegFixedLen)
        let eTag := posTagOfV vf (blkBase k + blkSegFixedLen)
        let seg : Segment := ⟨some (levelsOfV vf 16 (blkBase k)).getRoot,
          ⟨(levelsOfV vf 16 (blkBase k + 131071 + 5)).getRoot,
           (levelsOfV vf 16 (blkBase k + 131071 + 5 + 131071 + 3 + 8191 + 1 + 3)).getRoot,
           (levelsOfV vf 12 (blkBase k + 131071 + 5 + 131071 + 3)).getRoot,
           (bTs k).sps, (bTs k).mO, (bTs k).aO, (bTs k).hO⟩, (bTs k).bO, none⟩
        Exec.Block.encSeg (vf 4101) sg.l sg.k stTag seg eTag
      let outSeg : StageSeg := ⟨none,
        ⟨(levelsOfV vf 14 (outcBase + 2)).getRoot,
         (levelsOfV vf 14 (outcBase + 2 + 32767 + 3 + 8191 + 1 + 2)).getRoot,
         (levelsOfV vf 12 (outcBase + 2 + 32767 + 3)).getRoot,
         outcT.sps, outcT.mO, outcT.aO, outcT.hO⟩, [outcT.bO]⟩
      PProg.outOf (shdP_runFixedProg Lq' hL20' tag key' Rp hR hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig' x c) v' =
        (honestStmt hdr (levelsOfV vf 11 0).getRoot ((classifySpecP Rp x.1).getD 0),
          encStage G_in (vf 4101) (posTagOfV vf 4102) incSeg (posTagOfV vf (4104 + incSegFixedLen)) ::
            (List.ofFn blkByte ++
              [encStage G_out (vf 4101) (posTagOfV vf (blkBase ⟨25, by decide⟩ + blkSegFixedLen))
                outSeg (posTagOfV vf (outcBase + outcSegFixedLen))])) := by
    intro Lq' hL20' key' hw hdr hfit refused blkDig' v' hv'
    subst hv'
    rw [shdP_runFixedProg_outOf_eq]
    have hInc1' := incT.out_eq hL20' key'
    dsimp -zetaDelta only at hInc1'
    have hIncTr' : ((incSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp embDigest bInRow x.1 c
        (levelsOfV (shdExtV v') 11 0) (shdExtV v' 4101) (posTagOfV (shdExtV v') 4102) ⟨shdExtV v' 4101, 0, key'⟩).res (fun _ => default) (shdExtV v') 4104).2.1
        = levelsOfV (shdExtV v') 16 4104 :=
      incSegFixedProg_res_tree (Hdr := Hdr) Lq' hL20' tag key' Rp embDigest bInRow x.1 c
        (levelsOfV (shdExtV v') 11 0) (shdExtV v' 4101) (posTagOfV (shdExtV v') 4102) ⟨shdExtV v' 4101, 0, key'⟩ (shdExtV v') 4104
    let tInc' : Tr := ((incSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp embDigest bInRow x.1 c
        (levelsOfV (shdExtV v') 11 0) (shdExtV v' 4101) (posTagOfV (shdExtV v') 4102) ⟨shdExtV v' 4101, 0, key'⟩).res (fun _ => default) (shdExtV v') 4104).2.2
    have hChOut' := hChainOut hL20' key' blkDig' tInc'
    have htInc'Def : tInc' = ((incSegFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp embDigest bInRow x.1 c
        (levelsOfV (shdExtV v') 11 0) (shdExtV v' 4101) (posTagOfV (shdExtV v') 4102) ⟨shdExtV v' 4101, 0, key'⟩).res (fun _ => default) (shdExtV v') 4104).2.2 := rfl
    have hBlkEq' := blkChain_res_eq (Hdr := Hdr) (Lq := Lq') (hL20 := hL20') (tag := tag) (key := key')
      (Rp := Rp) (hR := hR) (hweights := hweights) (hinPub := hinPub) (ioIn := ioIn) (ioOut := ioOut) (blkDig := blkDig')
      (x := x) (c := c) (vf := shdExtV v') (s := 0) (cnt := 26) (h1 := by omega) (h2 := hEnd26) (act := true)
      (st := posTagOfV (shdExtV v') (4104 + incSegFixedLen)) hcr0Def.symm hTr0 htInc'Def.symm hBase0
    have hOutEq' := outcSeg_res_eq (Lq := Lq') (hL20 := hL20') (tag := tag) (key := key')
      (Rp := Rp) (hR := hR) (hweights := hweights) (hinPub := hinPub) (houtPub := houtPub)
      (wDigest := wDigest) (bOutRow := bOutRow) (x := x) (c := c) (vf := shdExtV v')
      (t := ((blkChainFixedProg (Hdr := Hdr) Lq' hL20' tag key' Rp hR hweights hinPub ioIn ioOut blkDig'
        x.1 x.2 c 0 26 hEnd26 true cr0 (levelsOfV (shdExtV v') 16 (shdTreeBase (.bnd (shdBndIdx 0 26 hEnd26))))
        (shdExtV v' 4101) (posTagOfV (shdExtV v') (4104 + incSegFixedLen)) tInc').res (fun _ => default) (shdExtV v') (209507 + blkStepFixedLen * 0)).2.2.1)
      (congrArg crs (Fin.ext rfl) : crs ⟨26, Nat.lt_succ_self 26⟩ = crs shdBnd26)
      (congrArg (fun k : Fin 27 => levelsOfV (shdExtV v') 16 (shdTreeBase (.bnd k))) (Fin.ext rfl) :
        levelsOfV (shdExtV v') 16 (shdTreeBase (.bnd ⟨26 + 0, by omega⟩)) = levelsOfV (shdExtV v') 16 (shdTreeBase (.bnd shdBnd26)))
      (congrArg (fun k : Fin 26 => posTagOfV (shdExtV v') (blkBase k + blkSegFixedLen)) (Fin.ext rfl) :
        posTagOfV (shdExtV v') (blkBase ⟨26 + 0 - 1, by omega⟩ + blkSegFixedLen) = posTagOfV (shdExtV v') (blkBase ⟨25, by decide⟩ + blkSegFixedLen))
      hB26
    exact shdRunOutOf_eq_some_res hdr refused v' ((classifySpecP Rp x.1).getD 0)
      hB26 hInc1' hIncTr' hBlkEq' hChOut'.1 hChOut'.2.1
      (hChOut'.2.2.trans (ite_eq_right (by decide : (26 : ℕ) ≠ 0)))
      rfl hOutEq'
      (outcT.out_eq_clean hL20' key' (posTagOfV (shdExtV v') (blkBase ⟨25, by decide⟩ + blkSegFixedLen)) _)
  exact
    ⟨{ incT := incT, crAt := crs, crAt_zero := hCr0,
       blkT := fun k => bTs k, crAt_succ := fun k => hCrSucc k, outcT := outcT,
       outOf_eq := hOutOf }⟩

/-- Extract `FullRunTrace` from `¬ shdRunRefused ... v` for ANY `(x, c)`! -/
noncomputable def fullRunTrace_of_active {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (v : Fin shdP_zkResPts → Dig)
    (hng : ¬ shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v) :
    FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow x c (shdExtV v) :=
  Classical.choice (fullRunTrace_of_active_ex (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c v hng)

/-- Two active `FullRunTrace`s with the SAME verdict at `vf` have identical `ch`/`bga`/`dfs`/`claims.*.map parts`/
`crAt.pending.map parts`/`fs.terms` across ALL 28 segments and ALL 27 boundaries! -/
theorem fullRunTrace_invar {Hdr : Type} (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (x₁ x₂ : {x // (classifyModelP Rp).admissible x})
    (hVerd : (classifySpecP Rp x₁.1).getD 0 = (classifySpecP Rp x₂.1).getD 0)
    (c₁ c₂ : ShdCoins) (vf : ℕ → Dig)
    (F₁ : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow x₁ c₁ vf)
    (F₂ : FullRunTrace (Hdr := Hdr) tag Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow x₂ c₂ vf) :
    (F₁.incT.ch = F₂.incT.ch ∧ F₁.incT.dfs = F₂.incT.dfs
      ∧ F₁.incT.acc.claims.a.map Block.ZClaim.parts = F₂.incT.acc.claims.a.map Block.ZClaim.parts
      ∧ F₁.incT.acc.claims.h.map Block.ZClaim.parts = F₂.incT.acc.claims.h.map Block.ZClaim.parts
      ∧ F₁.incT.acc.claims.inp.map Block.ZClaim.parts = F₂.incT.acc.claims.inp.map Block.ZClaim.parts
      ∧ (F₁.incT.acc.fs ++ F₁.incT.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (F₂.incT.acc.fs ++ F₂.incT.acc.hostFs).map Exec.Block.MaskFunctional.terms)
    ∧ (∀ k : Fin 27, (F₁.crAt k).pending.map Block.ZClaim.parts = (F₂.crAt k).pending.map Block.ZClaim.parts)
    ∧ (∀ k : Fin 26,
        (F₁.blkT k).bga = (F₂.blkT k).bga ∧ (F₁.blkT k).dfs = (F₂.blkT k).dfs
        ∧ (F₁.blkT k).acc.claims.a.map Block.ZClaim.parts = (F₂.blkT k).acc.claims.a.map Block.ZClaim.parts
        ∧ (F₁.blkT k).acc.claims.h.map Block.ZClaim.parts = (F₂.blkT k).acc.claims.h.map Block.ZClaim.parts
        ∧ (F₁.blkT k).acc.claims.inp.map Block.ZClaim.parts = (F₂.blkT k).acc.claims.inp.map Block.ZClaim.parts
        ∧ ((F₁.blkT k).acc.fs ++ (F₁.blkT k).acc.hostFs).map Exec.Block.MaskFunctional.terms
          = ((F₂.blkT k).acc.fs ++ (F₂.blkT k).acc.hostFs).map Exec.Block.MaskFunctional.terms)
    ∧ (F₁.outcT.ch = F₂.outcT.ch ∧ F₁.outcT.dfs = F₂.outcT.dfs
      ∧ F₁.outcT.acc.claims.a.map Block.ZClaim.parts = F₂.outcT.acc.claims.a.map Block.ZClaim.parts
      ∧ F₁.outcT.acc.claims.h.map Block.ZClaim.parts = F₂.outcT.acc.claims.h.map Block.ZClaim.parts
      ∧ F₁.outcT.acc.claims.inp.map Block.ZClaim.parts = F₂.outcT.acc.claims.inp.map Block.ZClaim.parts
      ∧ (F₁.outcT.acc.fs ++ F₁.outcT.acc.hostFs).map Exec.Block.MaskFunctional.terms
        = (F₂.outcT.acc.fs ++ F₂.outcT.acc.hostFs).map Exec.Block.MaskFunctional.terms) := by
  have hInc := incSegTrace_invar tag Rp embDigest bInRow x₁.1 x₂.1 c₁ c₂ vf F₁.incT F₂.incT
  have hBlk : ∀ k : Fin 26, _ := fun k =>
    blkSegTrace_invar tag Rp hR hweights hinPub ioIn ioOut x₁ x₂ c₁ c₂ k _ _ vf (F₁.blkT k) (F₂.blkT k)
  have hOut := outcSegTrace_invar tag Rp hR hweights hinPub houtPub wDigest bOutRow x₁ x₂ hVerd c₁ c₂ _ _ vf F₁.outcT F₂.outcT
  refine ⟨⟨hInc.1, hInc.2.1, hInc.2.2.1, hInc.2.2.2.1, hInc.2.2.2.2.1, hInc.2.2.2.2.2.2⟩,
    fun k => ?_, fun k => ⟨(hBlk k).1, (hBlk k).2.1, (hBlk k).2.2.1, (hBlk k).2.2.2.1, (hBlk k).2.2.2.2.1, (hBlk k).2.2.2.2.2.2⟩,
    hOut⟩
  rcases k with ⟨j, hj⟩
  cases j with
  | zero =>
    change (F₁.crAt 0).pending.map Block.ZClaim.parts = (F₂.crAt 0).pending.map Block.ZClaim.parts
    rw [F₁.crAt_zero, F₂.crAt_zero]; exact hInc.2.2.2.2.2.1
  | succ m =>
    rw [F₁.crAt_succ ⟨m, by omega⟩, F₂.crAt_succ ⟨m, by omega⟩]
    exact (hBlk ⟨m, by omega⟩).2.2.2.2.2.1

end SegmentExtractors


end ZK60.HonestShield
