/-
D63 lane L69, Milestone A Part 2e-2 (`HonestShieldZKCountInst.lean`):
active-run wire recovery (`rdStageBody_enc_inj`, `rdSegBody_enc_inj`, `incSeg`/`blkSeg`/`blkChain`/
`outcSeg_decode_ptAt_eq`), visibility (`shdP_runVisSpec`), and master `ShdZKCountWitness`
(`shdP_zkCountWitness`) for `shdP_runFixedProg` (`shdP_honestRunP_zk`).

Imports `ZK60Formal.HonestShieldZKCountShape` (Sections 1-3: atomic `.res`/`ptAt`, pure `v`-only
refusal `shdRunRefused`, and unopened-leaf salt invariance `shdP_runFixedProg_setLeaf_outOf`).
Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKCountShape

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun ZK60.ZKHonest
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec Segment SegGeom
  CoreCanon CoreShape HidingCanon HidingShape MaskCanon SlotCanon
  labA labH labM labRows labLogCols labPbSlot labPbScalar labPbTerm)
open ZK60.Circuit (gP GF)

/-! ## 4. Active-Run Wire Recovery, Visibility (`shdP_runVisSpec`), and `shdP_zkCountWitness` -/

section VisibilityAndCountWitness

private theorem list_map_eq_mem {α β : Type} (f g : α → β) :
    ∀ {l : List α}, l.map f = l.map g → ∀ a ∈ l, f a = g a
  | [], _, _, ha => by cases ha
  | x :: xs, h, a, ha => by
    simp only [List.map_cons, List.cons.injEq] at h
    rcases List.mem_cons.mp ha with rfl | hmem
    · exact h.1
    · exact list_map_eq_mem f g h.2 a hmem

private theorem list_append_singleton_inj {α : Type} {a₁ a₂ : List α} {b₁ b₂ : α}
    (h : a₁ ++ [b₁] = a₂ ++ [b₂]) : a₁ = a₂ ∧ b₁ = b₂ := by
  have h1 := congrArg List.reverse h
  simp only [List.reverse_append, List.reverse_singleton, List.singleton_append, List.cons.injEq] at h1
  exact ⟨List.reverse_injective h1.2, h1.1⟩

/-- Stage wire-encoding injectivity via `rdStageBody` (no length/ceiling hypothesis needed). -/
theorem rdStageBody_enc_inj (s : StageGeom) (hgt : s.g.slots.length = s.g.terms.length)
    (hdom : s.g.maskDom ≤ 2 ^ 64) (henc : s.g.blk.encCols ≤ 2 ^ 64) (hmag : s.magic.length = 8)
    (bindg startTag : Dig) (sg₁ sg₂ : StageSeg) (e₁ e₂ : Dig)
    (h1 : CoreCanon sg₁.core ∧ CoreShape s.g sg₁.core ∧ sg₁.bRoot.isSome = s.hasB ∧ List.Forall₂ CloseOk s.closes sg₁.closes)
    (h2 : CoreCanon sg₂.core ∧ CoreShape s.g sg₂.core ∧ sg₂.bRoot.isSome = s.hasB ∧ List.Forall₂ CloseOk s.closes sg₂.closes)
    (heq : encStage s bindg startTag sg₁ e₁ = encStage s bindg startTag sg₂ e₂) :
    sg₁ = sg₂ ∧ e₁ = e₂ := by
  have hr : ∀ sg e, CoreCanon sg.core → CoreShape s.g sg.core → sg.bRoot.isSome = s.hasB →
      List.Forall₂ CloseOk s.closes sg.closes →
      rdStageBody s bindg startTag (encStage s bindg startTag sg e) = .ok ((sg, e), []) := by
    intro sg e hc hs hbr hcl
    unfold rdStageBody
    rw [encStage, Exec.Block.Rd.bnd_of_ok (rdStageHeader_enc s hmag _ _ _),
      Exec.Block.Rd.bnd_of_ok (Exec.Block.rdOpt_enc (P := fun _ => True) (fun a rest _ => Exec.Block.rdDig_enc a rest) sg.bRoot hbr (fun _ _ => trivial) _),
      Exec.Block.Rd.bnd_of_ok (Exec.Block.rdCore_enc s.g hgt hdom henc sg.core hc hs _),
      Exec.Block.Rd.bnd_of_ok (rdCloses_enc s.closes sg.closes _ hcl),
      ← List.append_nil e.toList, Exec.Block.Rd.bnd_of_ok (Exec.Block.rdDig_enc _ _)]
    rfl
  have h := congrArg (rdStageBody s bindg startTag) heq
  rw [hr sg₁ e₁ h1.1 h1.2.1 h1.2.2.1 h1.2.2.2, hr sg₂ e₂ h2.1 h2.2.1 h2.2.2.1 h2.2.2.2] at h
  simp only [Except.ok.injEq, Prod.mk.injEq] at h
  exact h.1

/-- R13 block segment wire-encoding injectivity via `rdSegBody`. -/
theorem rdSegBody_enc_inj (s : SegGeom) (hgt : s.g.slots.length = s.g.terms.length)
    (hdom : s.g.maskDom ≤ 2 ^ 64) (henc : s.g.blk.encCols ≤ 2 ^ 64) (hee : s.ed.encCols ≤ 2 ^ 64)
    (bindg startTag : Dig) (sg₁ sg₂ : Segment) (e₁ e₂ : Dig)
    (h1 : CoreCanon sg₁.core ∧ CoreShape s.g sg₁.core ∧ sg₁.bRoot.isSome = s.commits
      ∧ HidingCanon sg₁.inOpen ∧ HidingShape s.ed s.incoming.1 s.incoming.2 sg₁.inOpen
      ∧ sg₁.outOpen.isSome = s.closes ∧ ∀ o ∈ sg₁.outOpen, HidingCanon o ∧ HidingShape s.ed 1 s.eRows o)
    (h2 : CoreCanon sg₂.core ∧ CoreShape s.g sg₂.core ∧ sg₂.bRoot.isSome = s.commits
      ∧ HidingCanon sg₂.inOpen ∧ HidingShape s.ed s.incoming.1 s.incoming.2 sg₂.inOpen
      ∧ sg₂.outOpen.isSome = s.closes ∧ ∀ o ∈ sg₂.outOpen, HidingCanon o ∧ HidingShape s.ed 1 s.eRows o)
    (heq : Exec.Block.encSeg bindg s.l s.k startTag sg₁ e₁ = Exec.Block.encSeg bindg s.l s.k startTag sg₂ e₂) :
    sg₁ = sg₂ ∧ e₁ = e₂ := by
  have hr : ∀ sg e, CoreCanon sg.core → CoreShape s.g sg.core → sg.bRoot.isSome = s.commits →
      HidingCanon sg.inOpen → HidingShape s.ed s.incoming.1 s.incoming.2 sg.inOpen →
      sg.outOpen.isSome = s.closes → (∀ o ∈ sg.outOpen, HidingCanon o ∧ HidingShape s.ed 1 s.eRows o) →
      Exec.Block.rdSegBody s bindg startTag (Exec.Block.encSeg bindg s.l s.k startTag sg e) = .ok ((sg, e), []) := by
    intro sg e hc hs hbr hic his hos hoc
    have hhid : ∀ (groups rows : ℕ) (o : Exec.Block.OpeningZk) (rest : List UInt8),
        HidingCanon o ∧ HidingShape s.ed groups rows o →
        Exec.Block.rdHiding s.ed groups rows (Exec.Block.encHiding o ++ rest) = .ok (o, rest) := fun groups rows o rest h =>
      Exec.Block.rdHiding_enc s.ed groups rows o h.1 h.2.1 h.2.2.1 h.2.2.2.1 h.2.2.2.2.1 h.2.2.2.2.2 hee rest
    unfold Exec.Block.rdSegBody
    rw [Exec.Block.encSeg, Exec.Block.Rd.bnd_of_ok (Exec.Block.rdSegHeader_enc _ _ _ _ _),
      Exec.Block.Rd.bnd_of_ok (Exec.Block.rdOpt_enc (P := fun _ => True) (fun a rest _ => Exec.Block.rdDig_enc a rest) sg.bRoot hbr (fun _ _ => trivial) _),
      Exec.Block.Rd.bnd_of_ok (Exec.Block.rdCore_enc s.g hgt hdom henc sg.core hc hs _),
      Exec.Block.Rd.bnd_of_ok (hhid _ _ sg.inOpen _ ⟨hic, his⟩),
      Exec.Block.Rd.bnd_of_ok (Exec.Block.rdOpt_enc (P := fun o => HidingCanon o ∧ HidingShape s.ed 1 s.eRows o)
        (fun a rest h => hhid 1 s.eRows a rest h) sg.outOpen hos hoc _),
      ← List.append_nil e.toList, Exec.Block.Rd.bnd_of_ok (Exec.Block.rdDig_enc _ _)]
    rfl
  have h := congrArg (Exec.Block.rdSegBody s bindg startTag) heq
  rw [hr sg₁ e₁ h1.1 h1.2.1 h1.2.2.1 h1.2.2.2.1 h1.2.2.2.2.1 h1.2.2.2.2.2.1 h1.2.2.2.2.2.2,
      hr sg₂ e₂ h2.1 h2.2.1 h2.2.2.1 h2.2.2.2.1 h2.2.2.2.2.1 h2.2.2.2.2.2.1 h2.2.2.2.2.2.2] at h
  simp only [Except.ok.injEq, Prod.mk.injEq] at h
  exact h.1

/-- Generic `SlotCanon` & shape extraction for any active `slotProveFixedProg` using `polySlotData`! -/
theorem slotProveFixedProg_canon_shape (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams)
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → shdP_K) → shdP_K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2)
    (hSc : ∀ s hist acc df c, (scalar s hist acc df c).Canon)
    (hTm : ∀ s hist acc df c rho, (∀ w ∈ terms s hist acc df c rho, w.Canon)
      ∧ (terms s hist acc df c rho).length = (df.tabs.filter Exec.Block.Tab.isPriv).length)
    (s : ℕ) (active : Bool) (hist : Hist) (acc : Acc) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ)
    (sp : SlotProof) (rec_ : SlotRec) (acc' : Acc) (t' : Tr)
    (hres : (slotProveFixedProg Lq hL20 key P (polySlotData P shdP_U shdP_hbij scalar poly terms) s active hist acc t).res H v base
      = (some (sp, rec_, acc'), t')) :
    SlotCanon sp
      ∧ sp.rounds.length = (Exec.Block.slotShape P s).1 + (Exec.Block.slotShape P s).2.1
      ∧ (∀ r ∈ sp.rounds, r.length = (Exec.Block.slotShape P s).2.2 + 1)
      ∧ sp.terms.length = Exec.Block.slotTerms P s := by
  unfold slotProveFixedProg at hres
  rw [PProg.res_andThen H v _ _ (P.draws s) base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P.draws s) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + P.draws s + 1) (trChallengeFp2Keyed_ptLen Lq (by omega) key _), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + P.draws s + 1 + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * slotN P s) (base + P.draws s + 1 + 1 + 1) (scProveFixedProg_ptLen Lq hL20 key _ _ _ _),
      PProg.res_andThen H v _ _ 1 (base + P.draws s + 1 + 1 + 1 + 2 * slotN P s) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res] at hres
  simp only [PProg.res, Prod.mk.injEq] at hres
  have h1 := hres.1
  cases active with
  | false => cases h1
  | true =>
    simp only [↓reduceIte, Bool.true_and] at h1
    cases hdf : P.define s hist ((List.range (P.draws s)).map (fun i => challengeFp2Of (v (base + i)))) with
    | error _ => rw [hdf] at h1; cases h1
    | ok df =>
      rw [hdf] at h1; dsimp only at h1
      cases hc : (challengeFp2Of (v (base + P.draws s + 1))).isZero with
      | true => rw [hc] at h1; cases h1
      | false =>
        rw [hc] at h1; simp only [Bool.not_false, Bool.not_true, ↓reduceIte] at h1
        set scr := (scProveFixedProg Lq hL20 key (slotN P s) true
          ((polySlotData P shdP_U shdP_hbij scalar poly terms).strat s hist acc df (challengeFp2Of (v (base + P.draws s + 1)))) _).res
          H v (base + P.draws s + 1 + 1 + 1)
        by_cases hes : ((scr.2.1.drop (Exec.Block.slotShape P s).1).any (fun x => x.isZero || decide (x = Fp2.one))) = true
        · rw [if_pos hes] at h1; cases h1
        · rw [if_neg hes] at h1
          cases hchk : Exec.Block.slotDefChecks P s acc df with
          | error _ => rw [hchk] at h1; cases h1
          | ok _ =>
            rw [hchk] at h1; dsimp only at h1
            cases hho : Exec.Block.hostedSum acc.scalars _ df.hosted with
            | error _ => rw [hho] at h1; cases h1
            | ok _ =>
              rw [hho] at h1; dsimp only at h1
              cases htv : Exec.Block.tabVals _ _ _ df.tabs 0 with
              | error _ => rw [htv] at h1; cases h1
              | ok _ =>
                rw [htv] at h1; simp only [Option.some.injEq, Prod.mk.injEq] at h1
                obtain ⟨rfl, -, -⟩ := h1
                dsimp only [scr, polySlotData]
                refine ⟨⟨hSc s hist acc df _,
                    fun r hr => (scProveFixedProg_res_honestW_canon Lq hL20 key H v (slotD P s) (slotN P s)
                      (poly s hist acc df (challengeFp2Of (v (base + P.draws s + 1)))) _ (base + P.draws s + 1 + 1 + 1) r hr).2,
                    (hTm s hist acc df _ _).1⟩,
                  (scProveFixedProg_res_spec Lq hL20 key H v (slotN P s) true _ _ (base + P.draws s + 1 + 1 + 1)).1,
                  fun r hr => (scProveFixedProg_res_honestW_canon Lq hL20 key H v (slotD P s) (slotN P s)
                    (poly s hist acc df (challengeFp2Of (v (base + P.draws s + 1)))) _ (base + P.draws s + 1 + 1 + 1) r hr).1, ?_⟩
                rw [(hTm s hist acc df _ _).2, slotDefChecks_nPriv P s acc df hchk]

theorem stSlotsProveFixedProg_canon_shape (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ)
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → shdP_K) → shdP_K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2)
    (hSc : ∀ s hist acc df c, (scalar s hist acc df c).Canon)
    (hTm : ∀ s hist acc df c rho, (∀ w ∈ terms s hist acc df c rho, w.Canon)
      ∧ (terms s hist acc df c rho).length = (df.tabs.filter Exec.Block.Tab.isPriv).length)
    (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      (stSlotsProveFixedProg Lq hL20 key P elog (polySlotData P shdP_U shdP_hbij scalar poly terms) b g a m active recs s acc t).res H v base
        = (some (sps, recs', acc'), t') →
      sps.length = m
        ∧ (∀ p ∈ sps, SlotCanon p)
        ∧ ∀ (i : ℕ) (p : SlotProof) (sh : ℕ × ℕ × ℕ) (tm : ℕ),
            sps[i]? = some p → P.geom.slots[s + i]? = some sh → P.geom.terms[s + i]? = some tm →
            p.rounds.length = sh.1 + sh.2.1 ∧ (∀ r ∈ p.rounds, r.length = sh.2.2 + 1) ∧ p.terms.length = tm
  | 0, active, _, _, _, _, _, sps, _, _, _, h => by
    cases active with
    | false => cases h
    | true =>
      simp only [stSlotsProveFixedProg, PProg.res, ↓reduceIte, Prod.mk.injEq, Option.some.injEq] at h
      obtain ⟨⟨rfl, -, -⟩, -⟩ := h
      exact ⟨rfl, (fun _ hp => by cases hp), (fun _ _ _ _ hp _ _ => by cases hp)⟩
  | m + 1, active, recs, s, acc, t, base, sps, recs', acc', t', h => by
    unfold stSlotsProveFixedProg at h
    have hSL : slotFixedLen (atLog P (elog s)) s = slotFixedLen P s := rfl
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s active _ acc t).congr hSL)] at h
    cases h1 : (slotProveFixedProg Lq hL20 key (atLog P (elog s))
        (sdAt (polySlotData P shdP_U shdP_hbij scalar poly terms) (elog s)) s active (Exec.Block.histOf b g a recs) acc t).res H v base with
    | mk o1 t1 =>
      rw [h1] at h; dsimp only at h
      cases o1 with
      | none =>
        rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog _ b g a m false recs (s + 1) acc t1)] at h
        cases h
      | some v1 =>
        rcases v1 with ⟨sp, rec_, acc1⟩
        rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog _ b g a m true (recs ++ [rec_]) (s + 1) acc1 t1)] at h
        cases h2 : (stSlotsProveFixedProg Lq hL20 key P elog (polySlotData P shdP_U shdP_hbij scalar poly terms) b g a m true (recs ++ [rec_]) (s + 1) acc1 t1).res H v (base + slotFixedLen P s) with
        | mk o2 t2 =>
          rw [h2] at h; dsimp only at h
          cases o2 with
          | none => cases h
          | some v2 =>
            rcases v2 with ⟨sps2, recs2, acc2⟩
            simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h
            obtain ⟨⟨rfl, -, -⟩, -⟩ := h
            have hsd : sdAt (polySlotData P shdP_U shdP_hbij scalar poly terms) (elog s)
                = polySlotData (atLog P (elog s)) shdP_U shdP_hbij scalar poly terms := rfl
            rw [hsd] at h1
            have hc1 := slotProveFixedProg_canon_shape Lq hL20 key (atLog P (elog s)) scalar poly terms hSc hTm s active _ acc t H v base sp rec_ acc1 t1 h1
            have ih := stSlotsProveFixedProg_canon_shape Lq hL20 key P elog scalar poly terms hSc hTm b g a H v m true (recs ++ [rec_]) (s + 1) acc1 t1 (base + slotFixedLen P s) sps2 recs2 acc2 t2 h2
            refine ⟨by simp [ih.1], fun p hp => ?_, fun i p sh tm hp hsh htm => ?_⟩
            · rcases List.mem_cons.mp hp with rfl | hmem
              · exact hc1.1
              · exact ih.2.1 p hmem
            · cases i with
              | zero =>
                simp only [List.getElem?_cons_zero, Option.some.injEq] at hp; subst hp
                rw [Nat.add_zero] at hsh htm
                have hshE : Exec.Block.slotShape (atLog P (elog s)) s = sh := by
                  change P.geom.slots.getD s (0, 0, 0) = sh; rw [List.getD_eq_getElem?_getD, hsh]; rfl
                have htmE : Exec.Block.slotTerms (atLog P (elog s)) s = tm := by
                  change P.geom.terms.getD s 0 = tm; rw [List.getD_eq_getElem?_getD, htm]; rfl
                rw [hshE, htmE] at hc1; exact hc1.2
              | succ j =>
                simp only [List.getElem?_cons_succ] at hp
                rw [show s + (j + 1) = s + 1 + j by omega] at hsh htm
                exact ih.2.2 j p sh tm hp hsh htm

theorem slotsProveFixedProg_canon_shape (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams)
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → shdP_K) → shdP_K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2)
    (hSc : ∀ s hist acc df c, (scalar s hist acc df c).Canon)
    (hTm : ∀ s hist acc df c rho, (∀ w ∈ terms s hist acc df c rho, w.Canon)
      ∧ (terms s hist acc df c rho).length = (df.tabs.filter Exec.Block.Tab.isPriv).length)
    (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (base : ℕ)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      (slotsProveFixedProg Lq hL20 key P (polySlotData P shdP_U shdP_hbij scalar poly terms) b g a m active recs s acc t).res H v base
        = (some (sps, recs', acc'), t') →
      sps.length = m
        ∧ (∀ p ∈ sps, SlotCanon p)
        ∧ ∀ (i : ℕ) (p : SlotProof) (sh : ℕ × ℕ × ℕ) (tm : ℕ),
            sps[i]? = some p → P.geom.slots[s + i]? = some sh → P.geom.terms[s + i]? = some tm →
            p.rounds.length = sh.1 + sh.2.1 ∧ (∀ r ∈ p.rounds, r.length = sh.2.2 + 1) ∧ p.terms.length = tm
  | 0, active, _, _, _, _, _, sps, _, _, _, h => by
    cases active with
    | false => cases h
    | true =>
      simp only [slotsProveFixedProg, PProg.res, ↓reduceIte, Prod.mk.injEq, Option.some.injEq] at h
      obtain ⟨⟨rfl, -, -⟩, -⟩ := h
      exact ⟨rfl, (fun _ hp => by cases hp), (fun _ _ _ _ hp _ _ => by cases hp)⟩
  | m + 1, active, recs, s, acc, t, base, sps, recs', acc', t', h => by
    unfold slotsProveFixedProg at h
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base (slotProveFixedProg_ptLen Lq hL20 key P _ s active _ acc t)] at h
    cases h1 : (slotProveFixedProg Lq hL20 key P (polySlotData P shdP_U shdP_hbij scalar poly terms) s active (Exec.Block.histOf b g a recs) acc t).res H v base with
    | mk o1 t1 =>
      rw [h1] at h; dsimp only at h
      cases o1 with
      | none =>
        rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P _ b g a m false recs (s + 1) acc t1)] at h
        cases h
      | some v1 =>
        rcases v1 with ⟨sp, rec_, acc1⟩
        rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P _ b g a m true (recs ++ [rec_]) (s + 1) acc1 t1)] at h
        cases h2 : (slotsProveFixedProg Lq hL20 key P (polySlotData P shdP_U shdP_hbij scalar poly terms) b g a m true (recs ++ [rec_]) (s + 1) acc1 t1).res H v (base + slotFixedLen P s) with
        | mk o2 t2 =>
          rw [h2] at h; dsimp only at h
          cases o2 with
          | none => cases h
          | some v2 =>
            rcases v2 with ⟨sps2, recs2, acc2⟩
            simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h
            obtain ⟨⟨rfl, -, -⟩, -⟩ := h
            have hc1 := slotProveFixedProg_canon_shape Lq hL20 key P scalar poly terms hSc hTm s active _ acc t H v base sp rec_ acc1 t1 h1
            have ih := slotsProveFixedProg_canon_shape Lq hL20 key P scalar poly terms hSc hTm b g a H v m true (recs ++ [rec_]) (s + 1) acc1 t1 (base + slotFixedLen P s) sps2 recs2 acc2 t2 h2
            refine ⟨by simp [ih.1], fun p hp => ?_, fun i p sh tm hp hsh htm => ?_⟩
            · rcases List.mem_cons.mp hp with rfl | hmem
              · exact hc1.1
              · exact ih.2.1 p hmem
            · cases i with
              | zero =>
                simp only [List.getElem?_cons_zero, Option.some.injEq] at hp; subst hp
                rw [Nat.add_zero] at hsh htm
                have hshE : Exec.Block.slotShape P s = sh := by
                  change P.geom.slots.getD s (0, 0, 0) = sh; rw [List.getD_eq_getElem?_getD, hsh]; rfl
                have htmE : Exec.Block.slotTerms P s = tm := by
                  change P.geom.terms.getD s 0 = tm; rw [List.getD_eq_getElem?_getD, htm]; rfl
                rw [hshE, htmE] at hc1; exact hc1.2
              | succ j =>
                simp only [List.getElem?_cons_succ] at hp
                rw [show s + (j + 1) = s + 1 + j by omega] at hsh htm
                exact ih.2.2 j p sh tm hp hsh htm

/-- Equal `OpeningZk` outputs of active `openingAuditFixedProg` imply equal `.cols` and `.salts` on every opened column! -/
theorem openingAuditFixedProg_cols_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : prm.nQ = 256)
    (g : OpenGeom) (T₁ T₂ : Table) (tree₁ tree₂ : MerkleLevels depth) (a₁ a₂ h₁ h₂ : Bool)
    (cl₁ cl₂ : List Exec.Block.ZClaim) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ)
    (o : Exec.Block.OpeningZk)
    (ho1 : ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₁ tree₁ a₁ h₁ cl₁ t).res H v base).1 = some o)
    (ho2 : ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T₂ tree₂ a₂ h₂ cl₂ t).res H v base).1 = some o) :
    ∀ r ∈ idxOf (2 ^ depth) 256 ((List.range 64).map (fun k => v (base + nClaims + rows + nGroups + 1 + k))),
      T₁.cols r = T₂.cols r ∧ T₁.salts r = T₂.salts r := by
  unfold openingAuditFixedProg at ho1 ho2
  rw [PProg.res_andThen H v _ _ nClaims base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ rows (base + nClaims) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ nGroups (base + nClaims + rows) (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _), trAbsorbVecsFixed_res,
      PProg.res_andThen H v _ _ 1 (base + nClaims + rows + nGroups) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((prm.nQ + 3) / 4) (base + nClaims + rows + nGroups + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at ho1 ho2
  simp only [PProg.res] at ho1 ho2
  split at ho1; swap; · cases ho1
  simp only [Option.some.injEq] at ho1
  split at ho2; swap; · cases ho2
  simp only [Option.some.injEq] at ho2
  have hcolEq := (congrArg Exec.Block.OpeningZk.columns ho1).trans (congrArg Exec.Block.OpeningZk.columns ho2).symm
  dsimp only at hcolEq
  rw [hnn, hnQ] at hcolEq
  have h64 : (256 + 3) / 4 = 64 := rfl
  rw [h64] at hcolEq
  intro r hr
  have hmem := list_map_eq_mem _ _ hcolEq r hr
  exact ⟨congrArg Exec.Block.Column.col hmem, congrArg Exec.Block.Column.salt hmem⟩

/-- Equal `MaskOpening` outputs of `zkBMaskFixedProg` imply equal `mTab.cols` and `mTab.salts` on every opened column! -/
theorem zkBMaskFixedProg_cols_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (M₁ M₂ : MTable) (S : ℕ) (tree₁ tree₂ : MerkleLevels 12) (fs₁ fs₂ : List Exec.Block.MaskFunctional)
    (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ)
    (hEq : ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₁ S tree₁ fs₁ t).res H v base).1
        = ((zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M₂ S tree₂ fs₂ t).res H v base).1) :
    ∀ r ∈ idxOf (2 ^ 12) 256 ((List.range 64).map (fun k => v (base + 2 * S + 5 + k))),
      (mTab S (cosetPt (rootFp 12)) M₁).cols r = (mTab S (cosetPt (rootFp 12)) M₂).cols r
        ∧ (mTab S (cosetPt (rootFp 12)) M₁).salts r = (mTab S (cosetPt (rootFp 12)) M₂).salts r := by
  unfold zkBMaskFixedProg at hEq
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at hEq
  rw [PProg.res_andThen H v _ _ 1 base (trChallengeFp2Keyed_ptLen Lq (by omega) key t), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ (2 * S + 2) (base + 1 + 1) (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 (base + 1 + 1 + (2 * S + 2)) (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ ((mQ + 3) / 4) (base + 1 + 1 + (2 * S + 2) + 1) (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _), trSqueezeVecKeyed_res] at hEq
  simp only [PProg.res] at hEq
  have hcolEq := congrArg Exec.Block.MaskOpening.columns hEq
  dsimp only at hcolEq
  have hmDom : mDom = 2 ^ 12 := by decide
  have hmQ : mQ = 256 := rfl
  have h64 : (256 + 3) / 4 = 64 := rfl
  have hidx : base + 1 + 1 + (2 * S + 2) + 1 = base + 2 * S + 5 := by omega
  rw [hmDom, hmQ, h64, hidx] at hcolEq
  intro r hr
  have hmem := list_map_eq_mem _ _ hcolEq r hr
  exact ⟨congrArg Exec.Block.Column.col hmem, congrArg Exec.Block.Column.salt hmem⟩

private theorem ptAt_of_ge {Q D α : Type} (H : Q → D) (v : ℕ → D) (p : PProg Q D α) (n i j : ℕ)
    (hle : p.PtLE n) (hge : i + n ≤ j) : p.ptAt H v i j = none := by
  cases hp : p.ptAt H v i j with
  | none => rfl
  | some z => exact absurd (PProg.ptAt_some_lt H v p n i j z hle hp) (by omega)

/-- **`merkleTableProg` `ptAt` equality**: internal nodes ALWAYS match (depend only on `v`), and any leaf
`j = base + r` matches whenever `T₁.cols r = T₂.cols r ∧ T₁.salts r = T₂.salts r`! -/
theorem merkleTableProg_ptAt_eq (Lq : ℕ) (h64 : 64 ≤ Lq) (tag : MTag) (d rows : ℕ) (hrows : 8 * rows ≤ Lq)
    (T₁ T₂ : Table) (hT₁ : ∀ r : Fin (2 ^ d), (T₁.cols r.val).length = rows)
    (hT₂ : ∀ r : Fin (2 ^ d), (T₂.cols r.val).length = rows)
    (H : QB Lq → Dig) (v : ℕ → Dig) (base j : ℕ)
    (hLeaf : ∀ r : Fin (2 ^ d), j = base + r.val → T₁.cols r.val = T₂.cols r.val ∧ T₁.salts r.val = T₂.salts r.val) :
    (merkleTableProg Lq h64 tag d rows hrows T₁ hT₁).ptAt H v base j
      = (merkleTableProg Lq h64 tag d rows hrows T₂ hT₂).ptAt H v base j := by
  by_cases hlt : j < base
  · rw [PProg.ptAt_lt H v _ base j hlt, PProg.ptAt_lt H v _ base j hlt]
  · by_cases hge : base + (2 ^ d + (2 ^ d - 1)) ≤ j
    · rw [ptAt_of_ge H v _ _ base j (merkleTableProg_ptLen Lq h64 tag d rows hrows T₁ hT₁).toPtLE hge,
          ptAt_of_ge H v _ _ base j (merkleTableProg_ptLen Lq h64 tag d rows hrows T₂ hT₂).toPtLE hge]
    · by_cases hleaf : j < base + 2 ^ d
      · let r : Fin (2 ^ d) := ⟨j - base, by omega⟩
        have hjEq : j = base + r.val := by dsimp [r]; omega
        obtain ⟨hc, hs⟩ := hLeaf r hjEq
        rw [hjEq]
        unfold merkleTableProg
        rw [merkleTreeProg_ptAt_leaf, merkleTreeProg_ptAt_leaf]
        simp only [hc, hs]
      · have hk : j - (base + 2 ^ d) < 2 ^ d - 1 := by omega
        have hjEq : j = base + 2 ^ d + (j - (base + 2 ^ d)) := by omega
        rw [hjEq]
        unfold merkleTableProg
        rw [merkleTreeProg_ptAt_node Lq h64 tag d _ _ _ H v base (j - (base + 2 ^ d)) hk,
            merkleTreeProg_ptAt_node Lq h64 tag d _ _ _ H v base (j - (base + 2 ^ d)) hk]

theorem stSlotsProveFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D₁ D₂ : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (recs₁ recs₂ : List SlotRec) (s : ℕ) (acc₁ acc₂ : Acc) (t : Tr) (base j : ℕ)
      (sps : List SlotProof) (r₁ r₂ : List SlotRec) (a₁ a₂ : Acc) (t₁ t₂ : Tr),
      (stSlotsProveFixedProg Lq hL20 key P elog D₁ b g a m true recs₁ s acc₁ t).res H v base = (some (sps, r₁, a₁), t₁) →
      (stSlotsProveFixedProg Lq hL20 key P elog D₂ b g a m true recs₂ s acc₂ t).res H v base = (some (sps, r₂, a₂), t₂) →
      (stSlotsProveFixedProg Lq hL20 key P elog D₁ b g a m true recs₁ s acc₁ t).ptAt H v base j
        = (stSlotsProveFixedProg Lq hL20 key P elog D₂ b g a m true recs₂ s acc₂ t).ptAt H v base j
  | 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ => rfl
  | m + 1, recs₁, recs₂, s, acc₁, acc₂, t, base, j, sps, r₁, r₂, a₁, a₂, t₁, t₂, h1, h2 => by
    unfold stSlotsProveFixedProg at h1 h2 ⊢
    have hSL : slotFixedLen (atLog P (elog s)) s = slotFixedLen P s := rfl
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₁ t).congr hSL)] at h1
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₂ t).congr hSL)] at h2
    cases hs1 : (slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₁ (elog s)) s true (Exec.Block.histOf b g a recs₁) acc₁ t).res H v base with
    | mk o1 t1' =>
      cases hs2 : (slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D₂ (elog s)) s true (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base with
      | mk o2 t2' =>
        rw [hs1] at h1; rw [hs2] at h2; dsimp only at h1 h2
        cases o1 with
        | none => rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m false recs₁ (s + 1) acc₁ t1')] at h1; cases h1
        | some v1 =>
          cases o2 with
          | none => rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m false recs₂ (s + 1) acc₂ t2')] at h2; cases h2
          | some v2 =>
            rcases v1 with ⟨sp₁, rec₁, acc₁'⟩
            rcases v2 with ⟨sp₂, rec₂, acc₂'⟩
            rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t1')] at h1
            rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t2')] at h2
            cases hr1 : (stSlotsProveFixedProg Lq hL20 key P elog D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t1').res H v (base + slotFixedLen P s) with
            | mk or1 tr1 =>
              cases hr2 : (stSlotsProveFixedProg Lq hL20 key P elog D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t2').res H v (base + slotFixedLen P s) with
              | mk or2 tr2 =>
                rw [hr1] at h1; rw [hr2] at h2; dsimp only at h1 h2
                cases or1 with
                | none => cases h1
                | some vr1 =>
                  cases or2 with
                  | none => cases h2
                  | some vr2 =>
                    rcases vr1 with ⟨sps₁, recs₁', acc₁''⟩
                    rcases vr2 with ⟨sps₂, recs₂', acc₂''⟩
                    simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1 h2
                    obtain ⟨⟨hsp1, -, -⟩, -⟩ := h1
                    obtain ⟨⟨hsp2, -, -⟩, -⟩ := h2
                    have hCons := hsp1.trans hsp2.symm
                    simp only [List.cons.injEq] at hCons
                    obtain ⟨hspEq, hspsEq⟩ := hCons
                    subst hspEq; subst hspsEq
                    have htEq : t1' = t2' := by
                      have e1 := congrArg Prod.snd hs1
                      have e2 := congrArg Prod.snd hs2
                      rw [slotProveFixedProg_res_tr] at e1 e2
                      exact e1.symm.trans e2
                    subst htEq
                    by_cases hj : j < base + slotFixedLen P s
                    · rw [PProg.ptAt_andThen_left H v _ _ (slotFixedLen P s) base j ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₁ t).congr hSL) hj,
                          PProg.ptAt_andThen_left H v _ _ (slotFixedLen P s) base j ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₂ t).congr hSL) hj]
                      exact slotProveFixedProg_ptAt_eq Lq hL20 key _ _ _ _ s rfl rfl _ _ acc₁ acc₂ t H v base j sp₁ rec₁ rec₂ acc₁' acc₂' t1' t1' hs1 hs2
                    · rw [PProg.ptAt_andThen_right H v _ _ (slotFixedLen P s) base j ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₁ t).congr hSL) (by omega),
                          PProg.ptAt_andThen_right H v _ _ (slotFixedLen P s) base j ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s true _ acc₂ t).congr hSL) (by omega),
                          hs1, hs2]
                      dsimp only
                      by_cases hj2 : j < base + slotFixedLen P s + slotsFixedLen P (s + 1) m
                      · rw [PProg.ptAt_andThen_left H v _ _ (slotsFixedLen P (s + 1) m) _ j (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m true _ (s + 1) acc₁' t1') hj2,
                            PProg.ptAt_andThen_left H v _ _ (slotsFixedLen P (s + 1) m) _ j (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m true _ (s + 1) acc₂' t1') hj2]
                        exact stSlotsProveFixedProg_ptAt_eq Lq hL20 key P elog D₁ D₂ b g a H v m _ _ (s + 1) acc₁' acc₂' t1' (base + slotFixedLen P s) j sps₁ recs₁' recs₂' acc₁'' acc₂'' tr1 tr2 hr1 hr2
                      · rw [PProg.ptAt_andThen_right H v _ _ (slotsFixedLen P (s + 1) m) _ j (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₁ b g a m true _ (s + 1) acc₁' t1') (by omega),
                            PProg.ptAt_andThen_right H v _ _ (slotsFixedLen P (s + 1) m) _ j (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D₂ b g a m true _ (s + 1) acc₂' t1') (by omega),
                            hr1, hr2]
                        rfl

theorem slotsProveFixedProg_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D₁ D₂ : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (recs₁ recs₂ : List SlotRec) (s : ℕ) (acc₁ acc₂ : Acc) (t : Tr) (base j : ℕ)
      (sps : List SlotProof) (r₁ r₂ : List SlotRec) (a₁ a₂ : Acc) (t₁ t₂ : Tr),
      (slotsProveFixedProg Lq hL20 key P D₁ b g a m true recs₁ s acc₁ t).res H v base = (some (sps, r₁, a₁), t₁) →
      (slotsProveFixedProg Lq hL20 key P D₂ b g a m true recs₂ s acc₂ t).res H v base = (some (sps, r₂, a₂), t₂) →
      (slotsProveFixedProg Lq hL20 key P D₁ b g a m true recs₁ s acc₁ t).ptAt H v base j
        = (slotsProveFixedProg Lq hL20 key P D₂ b g a m true recs₂ s acc₂ t).ptAt H v base j
  | 0, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _ => rfl
  | m + 1, recs₁, recs₂, s, acc₁, acc₂, t, base, j, sps, r₁, r₂, a₁, a₂, t₁, t₂, h1, h2 => by
    unfold slotsProveFixedProg at h1 h2 ⊢
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base (slotProveFixedProg_ptLen Lq hL20 key P D₁ s true _ acc₁ t)] at h1
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base (slotProveFixedProg_ptLen Lq hL20 key P D₂ s true _ acc₂ t)] at h2
    cases hs1 : (slotProveFixedProg Lq hL20 key P D₁ s true (Exec.Block.histOf b g a recs₁) acc₁ t).res H v base with
    | mk o1 t1' =>
      cases hs2 : (slotProveFixedProg Lq hL20 key P D₂ s true (Exec.Block.histOf b g a recs₂) acc₂ t).res H v base with
      | mk o2 t2' =>
        rw [hs1] at h1; rw [hs2] at h2; dsimp only at h1 h2
        cases o1 with
        | none => rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P D₁ b g a m false recs₁ (s + 1) acc₁ t1')] at h1; cases h1
        | some v1 =>
          cases o2 with
          | none => rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P D₂ b g a m false recs₂ (s + 1) acc₂ t2')] at h2; cases h2
          | some v2 =>
            rcases v1 with ⟨sp₁, rec₁, acc₁'⟩
            rcases v2 with ⟨sp₂, rec₂, acc₂'⟩
            rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t1')] at h1
            rw [PProg.res_andThen H v _ _ (slotsFixedLen P (s + 1) m) _ (slotsProveFixedProg_ptLen Lq hL20 key P D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t2')] at h2
            cases hr1 : (slotsProveFixedProg Lq hL20 key P D₁ b g a m true (recs₁ ++ [rec₁]) (s + 1) acc₁' t1').res H v (base + slotFixedLen P s) with
            | mk or1 tr1 =>
              cases hr2 : (slotsProveFixedProg Lq hL20 key P D₂ b g a m true (recs₂ ++ [rec₂]) (s + 1) acc₂' t2').res H v (base + slotFixedLen P s) with
              | mk or2 tr2 =>
                rw [hr1] at h1; rw [hr2] at h2; dsimp only at h1 h2
                cases or1 with
                | none => cases h1
                | some vr1 =>
                  cases or2 with
                  | none => cases h2
                  | some vr2 =>
                    rcases vr1 with ⟨sps₁, recs₁', acc₁''⟩
                    rcases vr2 with ⟨sps₂, recs₂', acc₂''⟩
                    simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1 h2
                    obtain ⟨⟨hsp1, -, -⟩, -⟩ := h1
                    obtain ⟨⟨hsp2, -, -⟩, -⟩ := h2
                    have hCons := hsp1.trans hsp2.symm
                    simp only [List.cons.injEq] at hCons
                    obtain ⟨hspEq, hspsEq⟩ := hCons
                    subst hspEq; subst hspsEq
                    have htEq : t1' = t2' := by
                      have e1 := congrArg Prod.snd hs1
                      have e2 := congrArg Prod.snd hs2
                      rw [slotProveFixedProg_res_tr] at e1 e2
                      exact e1.symm.trans e2
                    subst htEq
                    by_cases hj : j < base + slotFixedLen P s
                    · rw [PProg.ptAt_andThen_left H v _ _ (slotFixedLen P s) base j (slotProveFixedProg_ptLen Lq hL20 key P D₁ s true _ acc₁ t) hj,
                          PProg.ptAt_andThen_left H v _ _ (slotFixedLen P s) base j (slotProveFixedProg_ptLen Lq hL20 key P D₂ s true _ acc₂ t) hj]
                      exact slotProveFixedProg_ptAt_eq Lq hL20 key P P D₁ D₂ s rfl rfl _ _ acc₁ acc₂ t H v base j sp₁ rec₁ rec₂ acc₁' acc₂' t1' t1' hs1 hs2
                    · rw [PProg.ptAt_andThen_right H v _ _ (slotFixedLen P s) base j (slotProveFixedProg_ptLen Lq hL20 key P D₁ s true _ acc₁ t) (by omega),
                          PProg.ptAt_andThen_right H v _ _ (slotFixedLen P s) base j (slotProveFixedProg_ptLen Lq hL20 key P D₂ s true _ acc₂ t) (by omega),
                          hs1, hs2]
                      dsimp only
                      by_cases hj2 : j < base + slotFixedLen P s + slotsFixedLen P (s + 1) m
                      · rw [PProg.ptAt_andThen_left H v _ _ (slotsFixedLen P (s + 1) m) _ j (slotsProveFixedProg_ptLen Lq hL20 key P D₁ b g a m true _ (s + 1) acc₁' t1') hj2,
                            PProg.ptAt_andThen_left H v _ _ (slotsFixedLen P (s + 1) m) _ j (slotsProveFixedProg_ptLen Lq hL20 key P D₂ b g a m true _ (s + 1) acc₂' t1') hj2]
                        exact slotsProveFixedProg_ptAt_eq Lq hL20 key P D₁ D₂ b g a H v m _ _ (s + 1) acc₁' acc₂' t1' (base + slotFixedLen P s) j sps₁ recs₁' recs₂' acc₁'' acc₂'' tr1 tr2 hr1 hr2
                      · rw [PProg.ptAt_andThen_right H v _ _ (slotsFixedLen P (s + 1) m) _ j (slotsProveFixedProg_ptLen Lq hL20 key P D₁ b g a m true _ (s + 1) acc₁' t1') (by omega),
                            PProg.ptAt_andThen_right H v _ _ (slotsFixedLen P (s + 1) m) _ j (slotsProveFixedProg_ptLen Lq hL20 key P D₂ b g a m true _ (s + 1) acc₂' t1') (by omega),
                            hr1, hr2]
                        rfl

/-- Helper: `blkChainFixedSched` at block `k` (`startIdx ≤ k < startIdx + count`) evaluates to
`blkSegFixedSched (Pk k) ⟨k, _⟩ (209507 + blkStepFixedLen * k)`! -/
private theorem blkChainFixedSched_at (Pk : ℕ → BlockParams) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26) (tip : ℕ) (k : Fin 26) (j : ℕ),
      startIdx ≤ k.val → k.val < startIdx + count →
      209507 + blkStepFixedLen * k.val ≤ j → j < 209507 + blkStepFixedLen * k.val + blkSegFixedLen →
      ∃ tip', blkChainFixedSched Pk startIdx count hEnd (209507 + blkStepFixedLen * startIdx) tip j
        = blkSegFixedSched (Pk k.val) k (209507 + blkStepFixedLen * k.val) tip' j
  | _, 0, _, _, k, _, h1, h2, _, _ => by omega
  | startIdx, count + 1, hEnd, tip, k, j, h1, h2, hj1, hj2 => by
    unfold blkChainFixedSched spliceSched; dsimp only
    by_cases hk : k.val = startIdx
    · have hst : startIdx < 26 := by omega
      have hkFin : k = ⟨startIdx, hst⟩ := Fin.ext hk
      subst hkFin
      rw [ite_eq_left hj2]
      exact ⟨tip, rfl⟩
    · have hgt : startIdx + 1 ≤ k.val := by omega
      have hMul1 : blkStepFixedLen * startIdx + blkStepFixedLen ≤ blkStepFixedLen * k.val := by
        rw [← Nat.mul_succ]; exact Nat.mul_le_mul_left _ hgt
      have hMul2 : blkStepFixedLen * k.val + blkStepFixedLen ≤ blkStepFixedLen * startIdx + blkStepFixedLen + blkStepFixedLen * count := by
        have hm := Nat.mul_le_mul_left blkStepFixedLen (show k.val + 1 ≤ startIdx + 1 + count by omega)
        simp only [Nat.mul_add, Nat.mul_one] at hm; omega
      have hgeSeg : ¬ j < 209507 + blkStepFixedLen * startIdx + blkSegFixedLen := by
        unfold blkStepFixedLen at *; omega
      have hgeStep : ¬ j < 209507 + blkStepFixedLen * startIdx + blkStepFixedLen := by
        unfold blkStepFixedLen at *; omega
      have hltEnd : j < 209507 + blkStepFixedLen * startIdx + blkStepFixedLen + blkStepFixedLen * count := by
        unfold blkStepFixedLen at *; omega
      rw [ite_eq_right hgeSeg, ite_eq_right hgeStep, ite_eq_left hltEnd]
      have hbase : 209507 + blkStepFixedLen * startIdx + blkStepFixedLen = 209507 + blkStepFixedLen * (startIdx + 1) := by ring
      rw [hbase]
      exact blkChainFixedSched_at Pk (startIdx + 1) count (by omega) _ k j hgt (by omega) hj1 hj2

/-- **Exact 112-tree leaf-schedule location**: for EVERY tree `tid : ShdTreeId` and leaf `r : Fin (2 ^ shdTreeDepthOf tid)`,
`shdP_runFixedSched` at `shdTreeBase tid + r.val` equals `.leaf ⟨tid, r⟩`! -/
theorem shdP_runFixedSched_leaf_at (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ)
    (tid : ShdTreeId) (r : Fin (2 ^ shdTreeDepthOf tid)) :
    shdP_runFixedSched tag Rp ioIn ioOut embDigest bInRow wDigest bOutRow (shdTreeBase tid + r.val)
      = .leaf ⟨tid, r⟩ := by
  have hr := r.isLt
  have hmk : ∀ (t : ShdTreeId) (base : ℕ) (r' : Fin (2 ^ shdTreeDepthOf t)),
      merkleTreeSched t base (base + r'.val) = .leaf ⟨t, r'⟩ := fun t base r' => by
    unfold merkleTreeSched; dsimp only
    have hlt : base + r'.val - base < 2 ^ shdTreeDepthOf t := by rw [Nat.add_sub_cancel_left]; exact r'.isLt
    rw [dite_eq_left hlt]
    congr 1; exact Sigma.ext rfl (heq_of_eq (Fin.ext (Nat.add_sub_cancel_left base r'.val)))
  unfold shdP_runFixedSched spliceSched
  cases tid with
  | te =>
    have h4095 : shdTreeBase .te + r.val < 4095 := by unfold shdTreeBase; unfold shdTreeDepthOf at hr; dsimp only at hr ⊢; omega
    rw [ite_eq_left h4095]; exact hmk .te 0 r
  | bnd k =>
    by_cases hk0 : k.val = 0
    · have hkFin : k = ⟨0, by decide⟩ := Fin.ext hk0
      subst hkFin
      have hbase : shdTreeBase (.bnd ⟨0, by decide⟩) = 4104 := rfl
      rw [hbase]
      have hr16 : r.val < 2 ^ 16 := hr
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_left (by unfold incSegFixedLen; omega)]
      unfold incSegFixedSched spliceSched
      rw [ite_eq_left (by omega)]
      exact hmk (.bnd ⟨0, by decide⟩) 4104 r
    · let k' : Fin 26 := ⟨k.val - 1, by have := k.isLt; omega⟩
      have hbase : shdTreeBase (.bnd k) = 209507 + blkStepFixedLen * k'.val := by
        unfold shdTreeBase; dsimp only; rw [ite_eq_right hk0]
      rw [hbase]
      have hr16 : r.val < 2 ^ 16 := hr
      have hPosB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
          ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega), hPosB0]
      obtain ⟨tip', hblk⟩ := blkChainFixedSched_at _ 0 26 (by omega) _ k' (209507 + blkStepFixedLen * k'.val + r.val)
        (Nat.zero_le _) k'.isLt (by omega) (by unfold blkSegFixedLen; omega)
      rw [hblk]
      unfold blkSegFixedSched spliceSched
      rw [ite_eq_left (by omega)]
      have hkf : (⟨k'.val + 1, by omega⟩ : Fin 27) = k := Fin.ext (by dsimp [k']; omega)
      rw [hkf]; exact hmk (.bnd k) (209507 + blkStepFixedLen * k'.val) r
  | a s =>
    by_cases hs0 : s.val = 0
    · have hsFin : s = ⟨0, by decide⟩ := Fin.ext hs0
      subst hsFin
      have hr14 : r.val < 2 ^ 14 := hr
      have hbase : shdTreeBase (.a ⟨0, by decide⟩) = 4104 + 131071 + 5 := rfl
      rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_left (by unfold incSegFixedLen; omega)]
      unfold incSegFixedSched spliceSched
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by omega), ite_eq_left (by omega)]
      exact hmk (.a ⟨0, by decide⟩) (4104 + 131071 + 1 + 1 + 3) r
    · by_cases hs27 : s.val = 27
      · have hsFin : s = ⟨27, by decide⟩ := Fin.ext hs27
        subst hsFin
        have hr14 : r.val < 2 ^ 14 := hr
        have hbase : shdTreeBase (.a ⟨27, by decide⟩) = 209507 + blkStepFixedLen * 26 + 2 := rfl
        rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_right (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen outcSegFixedLen; omega)]
        have hBlks : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = 209507 + blkStepFixedLen * 26 := by unfold incSegFixedLen; omega
        rw [hBlks]; unfold outcSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
        exact hmk (.a ⟨27, by decide⟩) (209507 + blkStepFixedLen * 26 + 1 + 1) r
      · let k' : Fin 26 := ⟨s.val - 1, by have := s.isLt; omega⟩
        have hd16 : shdTreeDepthOf (.a s) = 16 := by unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
        have hr16 : r.val < 2 ^ 16 := Nat.lt_of_lt_of_eq r.isLt (congrArg (2 ^ ·) hd16)
        have hbase : shdTreeBase (.a s) = 209507 + blkStepFixedLen * k'.val + 131071 + 5 := by
          unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
        rw [hbase]
        have hPosB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega), hPosB0]
        obtain ⟨tip', hblk⟩ := blkChainFixedSched_at _ 0 26 (by omega) _ k' (209507 + blkStepFixedLen * k'.val + 131071 + 5 + r.val)
          (Nat.zero_le _) k'.isLt (by omega) (by unfold blkSegFixedLen; omega)
        rw [hblk]; unfold blkSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_left (by omega)]
        have hsf : (⟨k'.val + 1, by omega⟩ : Fin 28) = s := Fin.ext (by dsimp [k']; omega)
        rw [hsf, show 209507 + blkStepFixedLen * k'.val + 131071 + 5 + r.val
          = (209507 + blkStepFixedLen * k'.val + 131071 + 1 + 1 + 3) + r.val by omega]
        exact hmk (.a s) _ r
  | m s =>
    by_cases hs0 : s.val = 0
    · have hsFin : s = ⟨0, by decide⟩ := Fin.ext hs0
      subst hsFin
      have hr12 : r.val < 2 ^ 12 := hr
      have hbase : shdTreeBase (.m ⟨0, by decide⟩) = 4104 + 131071 + 5 + 32767 + 3 := rfl
      rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_left (by unfold incSegFixedLen; omega)]
      unfold incSegFixedSched spliceSched
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
      exact hmk (.m ⟨0, by decide⟩) _ r
    · by_cases hs27 : s.val = 27
      · have hsFin : s = ⟨27, by decide⟩ := Fin.ext hs27
        subst hsFin
        have hr12 : r.val < 2 ^ 12 := hr
        have hbase : shdTreeBase (.m ⟨27, by decide⟩) = 209507 + blkStepFixedLen * 26 + 2 + 32767 + 3 := rfl
        rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_right (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen outcSegFixedLen; omega)]
        have hBlks : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = 209507 + blkStepFixedLen * 26 := by unfold incSegFixedLen; omega
        rw [hBlks]; unfold outcSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_left (by omega)]
        exact hmk (.m ⟨27, by decide⟩) _ r
      · let k' : Fin 26 := ⟨s.val - 1, by have := s.isLt; omega⟩
        have hr12 : r.val < 2 ^ 12 := hr
        have hbase : shdTreeBase (.m s) = 209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 := by
          unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
        rw [hbase]
        have hPosB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega), hPosB0]
        obtain ⟨tip', hblk⟩ := blkChainFixedSched_at _ 0 26 (by omega) _ k' (209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 + r.val)
          (Nat.zero_le _) k'.isLt (by omega) (by unfold blkSegFixedLen; omega)
        rw [hblk]; unfold blkSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
        have hsf : (⟨k'.val + 1, by omega⟩ : Fin 28) = s := Fin.ext (by dsimp [k']; omega)
        rw [hsf, show 209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 + r.val
          = (209507 + blkStepFixedLen * k'.val + 131071 + 1 + 1 + 3 + 131071 + 3) + r.val by omega]
        exact hmk (.m s) _ r
  | h s =>
    by_cases hs0 : s.val = 0
    · have hsFin : s = ⟨0, by decide⟩ := Fin.ext hs0
      subst hsFin
      have hr14 : r.val < 2 ^ 14 := hr
      have hbase : shdTreeBase (.h ⟨0, by decide⟩) = 4104 + 131071 + 5 + 32767 + 3 + 8191 + 16 := rfl
      rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_left (by unfold incSegFixedLen; omega)]
      unfold incSegFixedSched spliceSched
      rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
          ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
      exact hmk (.h ⟨0, by decide⟩) _ r
    · by_cases hs27 : s.val = 27
      · have hsFin : s = ⟨27, by decide⟩ := Fin.ext hs27
        subst hsFin
        have hr14 : r.val < 2 ^ 14 := hr
        have hbase : shdTreeBase (.h ⟨27, by decide⟩) = 209507 + blkStepFixedLen * 26 + 2 + 32767 + 3 + 8191 + 3 := rfl
        rw [hbase, ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_right (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen outcSegFixedLen; omega)]
        have hBlks : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = 209507 + blkStepFixedLen * 26 := by unfold incSegFixedLen; omega
        rw [hBlks]; unfold outcSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_left (by omega)]
        exact hmk (.h ⟨27, by decide⟩) _ r
      · let k' : Fin 26 := ⟨s.val - 1, by have := s.isLt; omega⟩
        have hd16 : shdTreeDepthOf (.h s) = 16 := by unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
        have hr16 : r.val < 2 ^ 16 := Nat.lt_of_lt_of_eq r.isLt (congrArg (2 ^ ·) hd16)
        have hbase : shdTreeBase (.h s) = 209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 + 8191 + 4 := by
          unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
        rw [hbase]
        have hPosB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by unfold incSegFixedLen; omega), ite_eq_right (by unfold incSegFixedLen; omega),
            ite_eq_left (by unfold incSegFixedLen blkStepFixedLen blkSegFixedLen; omega), hPosB0]
        obtain ⟨tip', hblk⟩ := blkChainFixedSched_at _ 0 26 (by omega) _ k' (209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 + 8191 + 4 + r.val)
          (Nat.zero_le _) k'.isLt (by omega) (by unfold blkSegFixedLen; omega)
        rw [hblk]; unfold blkSegFixedSched spliceSched
        rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
            ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_left (by omega)]
        have hsf : (⟨k'.val + 1, by omega⟩ : Fin 28) = s := Fin.ext (by dsimp [k']; omega)
        rw [hsf, show 209507 + blkStepFixedLen * k'.val + 131071 + 5 + 131071 + 3 + 8191 + 4 + r.val
          = (209507 + blkStepFixedLen * k'.val + 131071 + 1 + 1 + 3 + 131071 + 3 + 8191 + 1 + 1 + 1 + 1) + r.val by omega]
        exact hmk (.h s) _ r

/-- Inactive `slotProveFixedProg` always returns `none` in `.res`. -/
private theorem slotProveFixedProg_res_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (H : QB Lq → Dig) (v : ℕ → Dig) (base : ℕ) :
    ((slotProveFixedProg Lq hL20 key P D s false hist acc t).res H v base).1 = none := by
  unfold slotProveFixedProg
  rw [PProg.res_andThen H v _ _ _ base (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t), trChallengeFp2VecKeyed_res,
      PProg.res_andThen H v _ _ 1 _ (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _), trAbsorbKeyed_res,
      PProg.res_andThen H v _ _ 1 _ (trChallengeFp2Keyed_ptLen Lq (by omega) key _), trChallengeFp2Keyed_res,
      PProg.res_andThen H v _ _ 1 _ (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res,
      PProg.res_andThen H v _ _ _ _ (scProveFixedProg_ptLen Lq hL20 key _ _ _ _),
      PProg.res_andThen H v _ _ 1 _ (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _), trAbsorbFp2Keyed_res]
  rfl

/-- Inactive `stSlotsProveFixedProg` always returns `none` in `.res`. -/
private theorem stSlotsProveFixedProg_res_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (base : ℕ),
      ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m false recs s acc t).res H v base).1 = none
  | 0, _, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t, base => by
    unfold stSlotsProveFixedProg
    have hSL : slotFixedLen (atLog P (elog s)) s = slotFixedLen P s := rfl
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base ((slotProveFixedProg_ptLen Lq hL20 key (atLog P (elog s)) _ s false _ acc t).congr hSL)]
    have hs0 := slotProveFixedProg_res_inactive Lq hL20 key (atLog P (elog s)) (sdAt D (elog s)) s (Exec.Block.histOf b g a recs) acc t H v base
    cases h0 : (slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D (elog s)) s false (Exec.Block.histOf b g a recs) acc t).res H v base with
    | mk o0 t0 =>
      rw [h0] at hs0; dsimp only at hs0; subst hs0; dsimp only
      rw [PProg.res_andThen H v _ _ _ _ (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m false recs (s + 1) acc t0)]
      rfl

private theorem stSlotsProveFixedProg_active_true {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig}
    {P : BlockParams} {elog : ℕ → ℕ} {D : SlotData P} {b g a : Fp2} {H : QB Lq → Dig} {v : ℕ → Dig}
    {m : ℕ} {act : Bool} {recs : List SlotRec} {s : ℕ} {acc : Acc} {t : Tr} {base : ℕ}
    {val : List SlotProof × List SlotRec × Acc} {t' : Tr}
    (h : (stSlotsProveFixedProg Lq hL20 key P elog D b g a m act recs s acc t).res H v base = (some val, t')) :
    act = true := by
  cases act with
  | true => rfl
  | false =>
    have := stSlotsProveFixedProg_res_inactive Lq hL20 key P elog D b g a H v m recs s acc t base
    rw [h] at this; cases this

/-- **Stage IN-C active wire recovery & `ptAt` equality**:
from equal encoded Stage IN-C bytes `enc₁ eIn = enc₂ eIn`, extracts equal `TE` opened cols/salts AND
proves `incSegFixedProg.ptAt` equality at every visible index `j`! -/
theorem incSegFixedProg_decode_ptAt_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ)
    (x₁ x₂ : shieldS0.Tok → ℕ) (c₁ c₂ : ShdCoins)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr)
    (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (eIn : Dig)
    (enc₁ enc₂ : Dig → List UInt8) (cr₁ cr₂ : Carry) (tr₁ tr₂ : MerkleLevels 16) (t₁ t₂ : Tr)
    (h1 : (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₁ c₁ treeTE bnd startTag t).res H (shdExtV v) 4104
      = (some (enc₁, cr₁), tr₁, t₁))
    (h2 : (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₂ c₂ treeTE bnd startTag t).res H (shdExtV v) 4104
      = (some (enc₂, cr₂), tr₂, t₂))
    (hBytes : enc₁ eIn = enc₂ eIn) :
    (∀ r ∈ shdOpenedCols v .te,
      (shdP_epTable (Hdr := Hdr) tag x₁ (shdEpBase c₁)).cols r = (shdP_epTable (Hdr := Hdr) tag x₂ (shdEpBase c₂)).cols r
        ∧ (shdP_epTable (Hdr := Hdr) tag x₁ (shdEpBase c₁)).salts r = (shdP_epTable (Hdr := Hdr) tag x₂ (shdEpBase c₂)).salts r)
    ∧ ∀ (j : ℕ),
        (∀ tid (r : Fin (2 ^ shdTreeDepthOf tid)), j = shdTreeBase tid + r.val → r.val ∈ shdOpenedCols v tid) →
        (∀ r ∈ shdOpenedCols v (.bnd ⟨0, by decide⟩),
          (shdP_incTB Rp x₁ (shdIncRndOf c₁)).cols r = (shdP_incTB Rp x₂ (shdIncRndOf c₂)).cols r
            ∧ (shdP_incTB Rp x₁ (shdIncRndOf c₁)).salts r = (shdP_incTB Rp x₂ (shdIncRndOf c₂)).salts r) →
        (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₁ c₁ treeTE bnd startTag t).ptAt H (shdExtV v) 4104 j
          = (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₂ c₂ treeTE bnd startTag t).ptAt H (shdExtV v) 4104 j := by
  let V := shdVi tag Rp embDigest bInRow
  let G := rcIncGeom V 28
  let vf := shdExtV v
  have h167 := shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow
  have hV_aR : V.lay.aRows = 41 := (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).1
  have hV_hR : V.lay.hRows = 76 := (shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.1
  have hV_ns : V.lay.ns = 4 := rfl
  have hV_mR : V.lay.mRows = 12 := by unfold Lay.mRows; rw [hV_ns]
  unfold incSegFixedProg at h1 h2
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 41 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 12 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 15 _) (trChallengeFp2VecKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  obtain ⟨⟨osl1, tsl1⟩, hsl1, h1⟩ := res_andThen_hyp_bind ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _)) h1
  obtain ⟨⟨mO₁, tm1⟩, hm1, h1⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _) h1
  obtain ⟨⟨oa1, ta1⟩, ha1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _) h1
  obtain ⟨⟨oh1, th1⟩, hh1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _) h1
  obtain ⟨⟨oe1, te1⟩, he1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _) h1
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 41 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 12 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 15 _) (trChallengeFp2VecKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  obtain ⟨⟨osl2, tsl2⟩, hsl2, h2⟩ := res_andThen_hyp_bind ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _).congr (h167 _)) h2
  obtain ⟨⟨mO₂, tm2⟩, hm2, h2⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _) h2
  obtain ⟨⟨oa2, ta2⟩, ha2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _) h2
  obtain ⟨⟨oh2, th2⟩, hh2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _) h2
  obtain ⟨⟨oe2, te2⟩, he2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _) h2
  cases osl1 with | none => cases h1 | some vsl1 =>
  cases osl2 with | none => cases h2 | some vsl2 =>
  rcases vsl1 with ⟨sps₁, recs₁, acc₁⟩
  rcases vsl2 with ⟨sps₂, recs₂, acc₂⟩
  cases oa1 with | none => cases h1 | some aO₁ =>
  cases oa2 with | none => cases h2 | some aO₂ =>
  cases oh1 with | none => cases h1 | some hO₁ =>
  cases oh2 with | none => cases h2 | some hO₂ =>
  cases oe1 with | none => cases h1 | some eO₁ =>
  cases oe2 with | none => cases h2 | some eO₂ =>
  simp only [Option.isSome_some, Bool.and_true] at h1 h2 hm1 hm2 ha1 ha2 hh1 hh2 he1 he2
  split at h1; swap; · simp only [PProg.res, Prod.mk.injEq] at h1; cases h1.1
  rename_i hact1'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1
  split at h2; swap; · simp only [PProg.res, Prod.mk.injEq] at h2; cases h2.1
  rename_i hact2'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h2
  obtain ⟨⟨hEnc1, -⟩, -⟩ := h1; obtain ⟨⟨hEnc2, -⟩, -⟩ := h2
  rw [hact1'] at hm1 ha1 hh1 he1; rw [hact2'] at hm2 ha2 hh2 he2
  have hsegOk : ∀ (x : shieldS0.Tok → ℕ) (c : ShdCoins) (ch : List Fp2) (actSl : Bool) (tSl0 : Tr) (bSl : ℕ)
      (trM : MerkleLevels 12) (bM : ℕ) (gA : OpenGeom) (trA : MerkleLevels 14) (hdrA : Bool) (bA : ℕ)
      (gH : OpenGeom) (trH : MerkleLevels 14) (hdrH : Bool) (bH : ℕ) (gE : OpenGeom) (hdrE : Bool) (bE : ℕ)
      (bRoot aRoot hRoot mRoot : Dig)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc)
      (tsl tm ta th te : Tr) (mO : Exec.Block.MaskOpening) (aO hO eO : Exec.Block.OpeningZk),
      (stSlotsProveFixedProg Lq hL20 key (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN)
        (shdP_incSlotData tag Rp embDigest bInRow ch (shdP_incTA x (shdIncRndOf c))
          (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
          (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
        Fp2.zero Fp2.zero Fp2.zero 4 actSl [] 0 {} tSl0).res H vf bSl = (some (sps, recs, acc), tsl) →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true (shdP_incM (shdIncRndOf c)) 4 trM (acc.fs ++ acc.hostFs) tsl).res H vf bM = (mO, tm) →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3 gA (shdP_incTA x (shdIncRndOf c)) trA true hdrA acc.claims.a tm).res H vf bA = (some aO, ta) →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4 gH (shdP_incTH Rp embDigest x (shdIncRndOf c) ch) trH true hdrH (acc.claims.h ++ [V.lay.logupSumClaim]) ta).res H vf bH = (some hO, th) →
      (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1 gE (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) treeTE true hdrE acc.claims.inp th).res H vf bE = (some eO, te) →
      let sg : StageSeg := ⟨some bRoot, ⟨aRoot, hRoot, mRoot, sps, mO, aO, hO⟩, [eO]⟩
      CoreCanon sg.core ∧ CoreShape G.g sg.core ∧ sg.bRoot.isSome = G.hasB ∧ List.Forall₂ CloseOk G.closes sg.closes := by
    intro x c ch actSl tSl0 bSl trM bM gA trA hdrA bA gH trH hdrH bH gE hdrE bE bRoot aRoot hRoot mRoot
      sps recs acc tsl tm ta th te mO aO hO eO hsl hm ha hh he
    have hSlCS := stSlotsProveFixedProg_canon_shape Lq hL20 key (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN)
      _ _ _ (fun _ _ _ _ _ => ofK_canon shdP_U shdP_hbij _)
      (fun s _ _ df _ rho => ⟨stgPrivVals_canon shdP_U shdP_hbij _ _ _ _ df.tabs, stgPrivVals_length shdP_U shdP_hbij _ _ _ _ df.tabs⟩)
      Fp2.zero Fp2.zero Fp2.zero H vf 4 actSl [] 0 {} tSl0 bSl sps recs acc tsl hsl
    have hmSp := zkBMaskFixedProg_res_spec Lq hL20 key shdP_U shdP_hbij (shdP_incM (shdIncRndOf c)) 4 trM (acc.fs ++ acc.hostFs) tsl H vf bM
    rw [hm] at hmSp; dsimp only at hmSp
    have haSp := openingAuditFixedProg_res_spec Lq hL20 key shdP_stgPrm 14 3 41 3
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gA (shdP_incTA x (shdIncRndOf c))
      (shdP_incTA_rows_len x (shdIncRndOf c))
      (fun j => (mkPcsTable_cols_length ..).trans (shdP_incTA_rows_len x (shdIncRndOf c)))
      (mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _) trA true hdrA acc.claims.a tm H vf bA aO (congrArg Prod.fst ha)
    have hhSp := openingAuditFixedProg_res_spec Lq hL20 key shdP_stgPrm 14 4 76 4
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gH (shdP_incTH Rp embDigest x (shdIncRndOf c) ch)
      (shdP_incTH_rows_len Rp embDigest x (shdIncRndOf c) ch)
      (fun j => (mkPcsTable_cols_length ..).trans (shdP_incTH_rows_len Rp embDigest x (shdIncRndOf c) ch))
      (mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _) trH true hdrH _ ta H vf bH hO (congrArg Prod.fst hh)
    have heSp := openingAuditFixedProg_res_spec Lq hL20 key shdP_epPrm 11 1 6 1
      (by norm_num [shdP_epPrm, PcsPrm.nn]) rfl gE (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
      (shdP_epTable_rows_length (Hdr := Hdr) tag x (shdEpBase c))
      (fun j => by rw [shdP_epTable_cols_length, shdP_epTable_rows_length])
      (shdP_epTable_cols_canon (Hdr := Hdr) tag x (shdEpBase c)) treeTE true hdrE _ th H vf bE eO (congrArg Prod.fst he)
    refine ⟨⟨hSlCS.2.1, hmSp.1, haSp.1, hhSp.1⟩, ?_, rfl, ?_⟩
    · refine ⟨hSlCS.1.trans (by
          change 4 = (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).geomSlots.length
          rw [(shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.2.2]; rfl),
        fun i p sh tm hp hsh htm => hSlCS.2.2 i p sh tm hp (by rwa [Nat.zero_add]) (by rwa [Nat.zero_add]),
        hmSp.2.2.1, hmSp.2.2.2.1, hmSp.2.2.2.2.1,
        fun col hcol => ⟨(hmSp.2.2.2.2.2 col hcol).1, (hmSp.2.2.2.2.2 col hcol).2.1.trans hV_mR.symm, (hmSp.2.2.2.2.2 col hcol).2.2⟩,
        fun o ho => by
          simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl
          · exact ⟨haSp.2.2.2.1, haSp.2.2.1, haSp.2.2.2.2.1, fun col hcol => ⟨(haSp.2.2.2.2.2 col hcol).1, (haSp.2.2.2.2.2 col hcol).2.2⟩⟩
          · exact ⟨hhSp.2.2.2.1, hhSp.2.2.1, hhSp.2.2.2.2.1, fun col hcol => ⟨(hhSp.2.2.2.2.2 col hcol).1, (hhSp.2.2.2.2.2 col hcol).2.2⟩⟩,
        haSp.2.1, hhSp.2.1,
        fun col hcol => (haSp.2.2.2.2.2 col hcol).2.1.trans hV_aR.symm,
        fun col hcol => (hhSp.2.2.2.2.2 col hcol).2.1.trans hV_hR.symm⟩
    · exact List.Forall₂.cons ⟨heSp.1, ⟨heSp.2.1, heSp.2.2.1, heSp.2.2.2.1, heSp.2.2.2.2.1, heSp.2.2.2.2.2⟩,
        by dsimp only [V]; unfold shdVi shdP_incV incVAt; dsimp only; decide⟩ List.Forall₂.nil
  have htrSlEq : tsl1 = tsl2 := by
    have e1 : _ = tsl1 := congrArg Prod.snd hsl1
    have e2 : _ = tsl2 := congrArg Prod.snd hsl2
    rw [← e1, ← e2]
    exact (stSlotsProveFixedProg_shape_indep Lq hL20 key _ _ _ _ Fp2.zero Fp2.zero Fp2.zero H vf 4 _ [] [] 0 {} {} _ _ rfl ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩).1
  have hgt : G.g.slots.length = G.g.terms.length := by
    change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).geomSlots.length
      = (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).geomTerms.length
    rw [(shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)).2.2.2]; rfl
  rw [← hEnc1, ← hEnc2] at hBytes
  have hSegEq := (rdStageBody_enc_inj G hgt
    (by dsimp only [G, V]; unfold rcIncGeom shdVi shdP_incV incVAt IncV.geom mGeom; dsimp only; decide)
    (by dsimp only [G, V]; unfold rcIncGeom shdVi shdP_incV incVAt IncV.geom mGeom; dsimp only; decide)
    rfl bnd startTag _ _ eIn eIn
    (hsegOk x₁ c₁ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₁ recs₁ acc₁ tsl1 tm1 ta1 th1 te1 mO₁ aO₁ hO₁ eO₁ hsl1 hm1 ha1 hh1 he1)
    (hsegOk x₂ c₂ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₂ recs₂ acc₂ tsl2 tm2 ta2 th2 te2 mO₂ aO₂ hO₂ eO₂ hsl2 hm2 ha2 hh2 he2)
    hBytes).1
  have hspsEq : sps₁ = sps₂ := congrArg (fun sg => sg.core.slots) hSegEq
  have hmOEq' : mO₁ = mO₂ := congrArg (fun sg => sg.core.maskOpen) hSegEq
  have haOEq : aO₁ = aO₂ := congrArg (fun sg => sg.core.aOpen) hSegEq
  have hhOEq : hO₁ = hO₂ := congrArg (fun sg => sg.core.hOpen) hSegEq
  have heOEq : eO₁ = eO₂ := by
    have := congrArg StageSeg.closes hSegEq; simpa using this
  subst hspsEq hmOEq' haOEq hhOEq heOEq htrSlEq
  have htmEq : tm1 = tm2 := by
    have e1 := congrArg Prod.snd hm1; have e2 := congrArg Prod.snd hm2
    rw [zkBMaskFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htmEq
  have htaEq : ta1 = ta2 := by
    have e1 := congrArg Prod.snd ha1; have e2 := congrArg Prod.snd ha2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htaEq
  have hthEq : th1 = th2 := by
    have e1 := congrArg Prod.snd hh1; have e2 := congrArg Prod.snd hh2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst hthEq
  have hmOEq := (congrArg Prod.fst hm1).trans (congrArg Prod.fst hm2).symm
  have hTECols := openingAuditFixedProg_cols_eq Lq hL20 key shdP_epPrm 11 1 6 1
    (by norm_num [shdP_epPrm, PcsPrm.nn]) rfl _ _ _ treeTE treeTE true true _ _ _ _ th1 H vf _ eO₁
    (congrArg Prod.fst he1) (congrArg Prod.fst he2)
  have hACols := openingAuditFixedProg_cols_eq Lq hL20 key shdP_stgPrm 14 3 41 3
    (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ tm1 H vf _ aO₁
    (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)
  have hHCols := openingAuditFixedProg_cols_eq Lq hL20 key shdP_stgPrm 14 4 76 4
    (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ ta1 H vf _ hO₁
    (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)
  have hMCols := zkBMaskFixedProg_cols_eq Lq hL20 key _ _ 4 _ _ _ _ tsl1 H vf _ hmOEq
  refine ⟨fun r hr => hTECols r (by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at hr; dsimp only at hr
      have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ + openingAuditFixedLen 4 76 4 shdP_stgPrm.nQ + 1 + 6 + 1 + 1
          = 4104 + 205401 - 64 := by norm_num [zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm]
      simpa only [hidx] using hr),
    fun j hVis hB0Cols => ?_⟩
  unfold incSegFixedProg
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 16 38 (by omega) _ _ _ _ H vf 4104 j fun r hr =>
      hB0Cols r.val (hVis (.bnd ⟨0, by decide⟩) r hr)) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 14 41 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 14 41 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 14 41 (by omega) _ _ _ _ H vf _ j fun r hr =>
      hACols r.val (by
        have ho := hVis (.a ⟨0, by decide⟩) r (by unfold shdTreeBase; exact hr)
        unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase at ho; dsimp only at ho; simp only [↓reduceIte] at ho
        have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + 3 + 41 + 3 + 1
            = 4104 + 205401 - 73 - 149 - 64 := by norm_num [zkBMaskFixedLen]
        simpa only [hidx] using ho)) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 12 12 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 12 12 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 12 12 (by omega) _ _ _ _ H vf _ j fun r hr =>
      hMCols r.val (by
        have ho := hVis (.m ⟨0, by decide⟩) r (by unfold shdTreeBase; exact hr)
        unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at ho; dsimp only at ho; simp only [↓reduceIte] at ho
        have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + 2 * 4 + 5
            = 4104 + 205401 - 73 - 149 - 112 - 64 := by norm_num
        simpa only [hidx] using ho)) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 15 _) (trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 14 76 (by omega) _ _ _ _ H vf _ j fun r hr =>
      hHCols r.val (by
        have ho := hVis (.h ⟨0, by decide⟩) r (by unfold shdTreeBase; exact hr)
        unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase at ho; dsimp only at ho; simp only [↓reduceIte] at ho
        have hidx : 4104 + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 15 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 167 + zkBMaskFixedLen 4 + openingAuditFixedLen 3 41 3 shdP_stgPrm.nQ + 4 + 76 + 4 + 1
            = 4104 + 205401 - 73 - 64 := by norm_num [zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm]
        simpa only [hidx] using ho)) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  have hact1_ok := stSlotsProveFixedProg_active_true hsl1
  rw [hact1_ok] at hsl1 hsl2 ⊢
  refine ptAt_andThen_step_res ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 true [] 0 {} _).congr (h167 _))
    ((stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 true [] 0 {} _).congr (h167 _)) hsl1 hsl2
    (fun _ => stSlotsProveFixedProg_ptAt_eq Lq hL20 key _ _ _ _ Fp2.zero Fp2.zero Fp2.zero H vf 4 [] [] 0 {} {} _ _ j sps₁ recs₁ recs₂ acc₁ acc₂ tsl1 tsl1 hsl1 hsl2) fun _ => ?_
  dsimp only; simp only [hact1', hact2']
  refine ptAt_andThen_step_res (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 4 _ _ tsl1)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 4 _ _ tsl1) hm1 hm2
    (fun _ => zkBMaskFixedProg_ptAt_eq Lq hL20 key _ _ 4 _ _ _ _ tsl1 H vf _ j hmOEq) fun _ => ?_
  dsimp only
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ true _ _ tm1)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ true _ _ tm1) ha1 ha2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ true true _ _ _ _ tm1 H vf _ j aO₁ (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ true _ _ ta1)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ true _ _ ta1) hh1 hh2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ true true _ _ _ _ ta1 H vf _ j hO₁ (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE true _ _ th1)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE true _ _ th1) he1 he2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key shdP_epPrm 11 1 6 1 _ _ _ treeTE treeTE true true _ _ _ _ th1 H vf _ j eO₁ (congrArg Prod.fst he1) (congrArg Prod.fst he2)) fun _ => ?_
  dsimp only; split <;> rfl

/-- Inactive `slotsProveFixedProg` always returns `none` in `.res`. -/
private theorem slotsProveFixedProg_res_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (H : QB Lq → Dig) (v : ℕ → Dig) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (base : ℕ),
      ((slotsProveFixedProg Lq hL20 key P D b g a m false recs s acc t).res H v base).1 = none
  | 0, _, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t, base => by
    unfold slotsProveFixedProg
    rw [PProg.res_andThen H v _ _ (slotFixedLen P s) base (slotProveFixedProg_ptLen Lq hL20 key P D s false _ acc t)]
    have hs0 := slotProveFixedProg_res_inactive Lq hL20 key P D s (Exec.Block.histOf b g a recs) acc t H v base
    cases h0 : (slotProveFixedProg Lq hL20 key P D s false _ acc t).res H v base with
    | mk o0 t0 =>
      rw [h0] at hs0; dsimp only at hs0; subst hs0; dsimp only
      rw [PProg.res_andThen H v _ _ _ _ (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m false recs (s + 1) acc t0)]
      rfl

private theorem slotsProveFixedProg_active_true {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig}
    {P : BlockParams} {D : SlotData P} {b g a : Fp2} {H : QB Lq → Dig} {v : ℕ → Dig}
    {m : ℕ} {act : Bool} {recs : List SlotRec} {s : ℕ} {acc : Acc} {t : Tr} {base : ℕ}
    {val : List SlotProof × List SlotRec × Acc} {t' : Tr}
    (h : (slotsProveFixedProg Lq hL20 key P D b g a m act recs s acc t).res H v base = (some val, t')) :
    act = true := by
  cases act with
  | true => rfl
  | false =>
    have := slotsProveFixedProg_res_inactive Lq hL20 key P D b g a H v m recs s acc t base
    rw [h] at this; cases this

/-- **Interior R13 Block `k : Fin 26` active wire recovery & `ptAt` equality**:
from equal encoded block bytes `enc₁ endTag = enc₂ endTag`, extracts equal `B_k` opened cols/salts AND
proves `blkSegFixedProg.ptAt` equality at every visible index `j`! -/
theorem blkSegFixedProg_decode_ptAt_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (c₁ c₂ : ShdCoins) (k : Fin 26) (cr₁ cr₂ : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (endTag : Dig)
    (enc₁ enc₂ : Dig → List UInt8) (cr₁' cr₂' : Carry) (tr₁ tr₂ : MerkleLevels 16) (t₁ t₂ : Tr)
    (h1 : (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x₁ hx₁ c₁ k true cr₁ treeBPrev bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * k.val)
      = (some (enc₁, cr₁'), tr₁, t₁))
    (h2 : (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x₂ hx₂ c₂ k true cr₂ treeBPrev bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * k.val)
      = (some (enc₂, cr₂'), tr₂, t₂))
    (hBytes : enc₁ endTag = enc₂ endTag) :
    (∀ r ∈ shdOpenedCols v (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩),
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).cols r
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).cols r
      ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).salts r
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).salts r)
    ∧ ∀ (j : ℕ),
        (∀ tid (r : Fin (2 ^ shdTreeDepthOf tid)), j = shdTreeBase tid + r.val → r.val ∈ shdOpenedCols v tid) →
        (∀ r ∈ shdOpenedCols v (.bnd ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩),
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols r
          ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).salts r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).salts r) →
        (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₁ hx₁ c₁ k true cr₁ treeBPrev bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * k.val) j
        = (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₂ hx₂ c₂ k true cr₂ treeBPrev bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * k.val) j := by
  let base := 209507 + blkStepFixedLen * k.val
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  have hs0 : s.val ≠ 0 := by dsimp [s]; omega
  have hs27 : s.val ≠ 27 := by dsimp [s]; omega
  let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
  let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
  let vf := shdExtV v
  have h1283 := shdP_blk_slotsFixedLen tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  have hgeom50 := shdP_Pk0_geom50 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k.val k.isLt
  unfold blkSegFixedProg at h1 h2
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h1
  replace h1 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h1
  replace h1 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  obtain ⟨⟨osl1, tsl1⟩, hsl1, h1⟩ := res_andThen_hyp_bind ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283) h1
  obtain ⟨⟨mO₁, tm1⟩, hm1, h1⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _) h1
  obtain ⟨⟨oa1, ta1⟩, ha1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) h1
  obtain ⟨⟨oh1, th1⟩, hh1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) h1
  obtain ⟨⟨ob1, tb1⟩, hb1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _) h1
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h2
  replace h2 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h2
  replace h2 := res_andThen_hyp (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  obtain ⟨⟨osl2, tsl2⟩, hsl2, h2⟩ := res_andThen_hyp_bind ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283) h2
  obtain ⟨⟨mO₂, tm2⟩, hm2, h2⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _) h2
  obtain ⟨⟨oa2, ta2⟩, ha2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) h2
  obtain ⟨⟨oh2, th2⟩, hh2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) h2
  obtain ⟨⟨ob2, tb2⟩, hb2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _) h2
  cases osl1 with | none => cases h1 | some vsl1 =>
  cases osl2 with | none => cases h2 | some vsl2 =>
  rcases vsl1 with ⟨sps₁, recs₁, acc₁⟩
  rcases vsl2 with ⟨sps₂, recs₂, acc₂⟩
  cases oa1 with | none => cases h1 | some aO₁ =>
  cases oa2 with | none => cases h2 | some aO₂ =>
  cases oh1 with | none => cases h1 | some hO₁ =>
  cases oh2 with | none => cases h2 | some hO₂ =>
  cases ob1 with | none => cases h1 | some bO₁ =>
  cases ob2 with | none => cases h2 | some bO₂ =>
  simp only [Option.isSome_some, Bool.and_true] at h1 h2 hm1 hm2 ha1 ha2 hh1 hh2 hb1 hb2
  split at h1; swap; · simp only [PProg.res, Prod.mk.injEq] at h1; cases h1.1
  rename_i hact1'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1
  split at h2; swap; · simp only [PProg.res, Prod.mk.injEq] at h2; cases h2.1
  rename_i hact2'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h2
  obtain ⟨⟨hEnc1, -⟩, -⟩ := h1; obtain ⟨⟨hEnc2, -⟩, -⟩ := h2
  rw [hact1'] at hm1 ha1 hh1 hb1; rw [hact2'] at hm2 ha2 hh2 hb2
  have hsegOk : ∀ (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (cr : Carry)
      (b g a : Fp2) (actSl : Bool) (tSl0 : Tr) (bSl : ℕ)
      (trM : MerkleLevels 12) (bM : ℕ) (gA : OpenGeom) (trA : MerkleLevels 16) (hdrA : Bool) (bA : ℕ)
      (gH : OpenGeom) (trH : MerkleLevels 16) (hdrH : Bool) (bH : ℕ) (gB : OpenGeom) (hdrB : Bool) (bB : ℕ)
      (bRoot aRoot hRoot mRoot : Dig)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (tsl tm ta th tb : Tr)
      (mO : Exec.Block.MaskOpening) (aO hO bO : Exec.Block.OpeningZk),
      let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
      let TBp := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
      let TBn := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
      (slotsProveFixedProg Lq hL20 key P (blkSlotData P w (blkTA w (shdBlkRndOf c k)) TBp TBn (shdBlkRndOf c k)) b g a 23 actSl [] 0 {} tSl0).res H vf bSl = (some (sps, recs, acc), tsl) →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true (blkTM (shdBlkRndOf c k)) 23 trM (acc.fs ++ acc.hostFs) tsl).res H vf bM = (mO, tm) →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 gA (blkTA w (shdBlkRndOf c k)) trA true hdrA acc.claims.a tm).res H vf bA = (some aO, ta) →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 gH (blkTH w (shdBlkRndOf c k) (b, g, a)) trH true hdrH (acc.claims.h ++ [P.logupSumClaim]) ta).res H vf bH = (some hO, th) →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB TBp treeBPrev true hdrB (cr.pending ++ acc.claims.inp) th).res H vf bB = (some bO, tb) →
      let seg : Segment := ⟨some bRoot, ⟨aRoot, hRoot, mRoot, sps, mO, aO, hO⟩, bO, none⟩
      CoreCanon seg.core ∧ CoreShape sg.g seg.core ∧ seg.bRoot.isSome = sg.commits
        ∧ HidingCanon seg.inOpen ∧ HidingShape sg.ed sg.incoming.1 sg.incoming.2 seg.inOpen
        ∧ seg.outOpen.isSome = sg.closes ∧ ∀ o ∈ seg.outOpen, HidingCanon o ∧ HidingShape sg.ed 1 sg.eRows o := by
    intro x hx c cr b g a actSl tSl0 bSl trM bM gA trA hdrA bA gH trH hdrH bH gB hdrB bB bRoot aRoot hRoot mRoot
      sps recs acc tsl tm ta th tb mO aO hO bO w TBp TBn hsl hm ha hh hb
    have hSlCS := slotsProveFixedProg_canon_shape Lq hL20 key P _ _ _
      (fun s _ _ _ _ => by cases P.kind s <;> exact ofK_canon shdP_U shdP_hbij _)
      (fun s _ _ df _ rho => ⟨stgPrivVals_canon shdP_U shdP_hbij _ _ _ _ df.tabs, stgPrivVals_length shdP_U shdP_hbij _ _ _ _ df.tabs⟩)
      b g a H vf 23 actSl [] 0 {} tSl0 bSl sps recs acc tsl hsl
    have hmSp := zkBMaskFixedProg_res_spec Lq hL20 key shdP_U shdP_hbij (blkTM (shdBlkRndOf c k)) 23 trM (acc.fs ++ acc.hostFs) tsl H vf bM
    rw [hm] at hmSp; dsimp only at hmSp
    have haSp := openingAuditFixedProg_res_spec Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gA (blkTA w (shdBlkRndOf c k)) (blkTA_rows_len w _)
      (fun j => by rw [blkTA_cols_len, blkTA_rows_len]) (blkTA_cols_canon w _) trA true hdrA acc.claims.a tm H vf bA aO (congrArg Prod.fst ha)
    have hhSp := openingAuditFixedProg_res_spec Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gH (blkTH w (shdBlkRndOf c k) (b, g, a)) (blkTH_rows_len w _ _)
      (fun j => by rw [blkTH_cols_len, blkTH_rows_len]) (blkTH_cols_canon w _ _) trH true hdrH _ ta H vf bH hO (congrArg Prod.fst hh)
    have hTBsp := shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
    have hbSp := openingAuditFixedProg_res_spec Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gB TBp hTBsp.rows_len hTBsp.cols_len hTBsp.cols_canon
      treeBPrev true hdrB _ th H vf bB bO (congrArg Prod.fst hb)
    refine ⟨⟨hSlCS.2.1, hmSp.1, haSp.1, hhSp.1⟩, ?_, by unfold sg Exec.Block.R13.segGeom Exec.Block.SegGeom.commits; simp; omega,
      hbSp.1, ?_, by unfold sg Exec.Block.R13.segGeom Exec.Block.SegGeom.closes; simp; omega, fun _ ho => by cases ho⟩
    · refine ⟨hSlCS.1.trans (by unfold sg Exec.Block.R13.segGeom; dsimp only; decide),
        fun i p sh tm hp hsh htm => hSlCS.2.2 i p sh tm hp (by rw [Nat.zero_add, hgeom50]; exact hsh) (by rw [Nat.zero_add, hgeom50]; exact htm),
        hmSp.2.2.1, hmSp.2.2.2.1, hmSp.2.2.2.2.1, hmSp.2.2.2.2.2,
        fun o ho => by
          simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl
          · exact ⟨haSp.2.2.2.1, haSp.2.2.1, haSp.2.2.2.2.1, fun col hcol => ⟨(haSp.2.2.2.2.2 col hcol).1, (haSp.2.2.2.2.2 col hcol).2.2⟩⟩
          · exact ⟨hhSp.2.2.2.1, hhSp.2.2.1, hhSp.2.2.2.2.1, fun col hcol => ⟨(hhSp.2.2.2.2.2 col hcol).1, (hhSp.2.2.2.2.2 col hcol).2.2⟩⟩,
        haSp.2.1, hhSp.2.1, fun col hcol => (haSp.2.2.2.2.2 col hcol).2.1, fun col hcol => (hhSp.2.2.2.2.2 col hcol).2.1⟩
    · exact ⟨hbSp.2.1, hbSp.2.2.1, hbSp.2.2.2.1, hbSp.2.2.2.2.1, hbSp.2.2.2.2.2⟩
  have htrSlEq : tsl1 = tsl2 := by
    have e1 : _ = tsl1 := congrArg Prod.snd hsl1
    have e2 : _ = tsl2 := congrArg Prod.snd hsl2
    rw [← e1, ← e2]
    exact (slotsProveFixedProg_shape_indep Lq hL20 key P P _ _ (fun _ => rfl) rfl rfl rfl rfl
      (fun s' hist dr => by cases P.define s' hist dr <;> simp [TabsShapeEq.refl])
      _ _ _ H vf 23 _ [] [] 0 {} {} _ _ rfl ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩).1
  rw [← hEnc1, ← hEnc2] at hBytes
  have hSegEq := (rdSegBody_enc_inj sg
    (by unfold sg Exec.Block.R13.segGeom; dsimp only; decide)
    (by unfold sg Exec.Block.R13.segGeom; dsimp only; decide)
    (by unfold sg Exec.Block.R13.segGeom; dsimp only; decide)
    (by unfold sg Exec.Block.R13.segGeom; dsimp only; decide)
    bnd startTag _ _ endTag endTag
    (hsegOk x₁ hx₁ c₁ cr₁ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₁ recs₁ acc₁ tsl1 tm1 ta1 th1 tb1 mO₁ aO₁ hO₁ bO₁ hsl1 hm1 ha1 hh1 hb1)
    (hsegOk x₂ hx₂ c₂ cr₂ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₂ recs₂ acc₂ tsl2 tm2 ta2 th2 tb2 mO₂ aO₂ hO₂ bO₂ hsl2 hm2 ha2 hh2 hb2)
    hBytes).1
  have hspsEq : sps₁ = sps₂ := congrArg (fun x => x.core.slots) hSegEq
  have hmOEq' : mO₁ = mO₂ := congrArg (fun x => x.core.maskOpen) hSegEq
  have haOEq : aO₁ = aO₂ := congrArg (fun x => x.core.aOpen) hSegEq
  have hhOEq : hO₁ = hO₂ := congrArg (fun x => x.core.hOpen) hSegEq
  have hbOEq : bO₁ = bO₂ := congrArg Segment.inOpen hSegEq
  subst hspsEq hmOEq' haOEq hhOEq hbOEq htrSlEq
  have htmEq : tm1 = tm2 := by
    have e1 := congrArg Prod.snd hm1; have e2 := congrArg Prod.snd hm2
    rw [zkBMaskFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htmEq
  have htaEq : ta1 = ta2 := by
    have e1 := congrArg Prod.snd ha1; have e2 := congrArg Prod.snd ha2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htaEq
  have hthEq : th1 = th2 := by
    have e1 := congrArg Prod.snd hh1; have e2 := congrArg Prod.snd hh2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst hthEq
  have hmOEq := (congrArg Prod.fst hm1).trans (congrArg Prod.fst hm2).symm
  have hBPrevCols := openingAuditFixedProg_cols_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2
    (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl _ _ _ treeBPrev treeBPrev true true _ _ _ _ th1 H vf _ bO₁
    (congrArg Prod.fst hb1) (congrArg Prod.fst hb2)
  have hACols := openingAuditFixedProg_cols_eq Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
    (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ tm1 H vf _ aO₁
    (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)
  have hHCols := openingAuditFixedProg_cols_eq Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
    (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ ta1 H vf _ hO₁
    (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)
  have hMCols := zkBMaskFixedProg_cols_eq Lq hL20 key _ _ 23 _ _ _ _ tsl1 H vf _ hmOEq
  refine ⟨fun r hr => hBPrevCols r (by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at hr; dsimp only at hr; rw [ite_eq_left k.isLt] at hr
      have hidx : 209507 + blkStepFixedLen * k.val + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ + openingAuditFixedLen 54 4390 9 Exec.R13.r13Prm.nQ + 2 + 38 + 2 + 1
          = 209507 + blkStepFixedLen * k.val + blkSegFixedLen - 64 := by
        simp only [blkSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, Exec.R13.r13Prm]; omega
      rw [hidx]; exact hr),
    fun j hVis hBNextCols => ?_⟩
  unfold blkSegFixedProg
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 16 38 (by omega) _ _ _ _ H vf base j fun r hr =>
      hBNextCols r.val (hVis (.bnd ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩) r (by
        unfold shdTreeBase; dsimp only; rw [ite_eq_right (by omega)]; simp only [base, Nat.add_sub_cancel] at hr ⊢; exact hr))) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 16 4577 (by omega) _ _ _ _ H vf _ j fun r hr => by
      have hdA : shdTreeDepthOf (.a s) = 16 := by unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
      have ho := hVis (.a s) (Fin.cast (by rw [hdA]) r) (by
        unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]; simp only [s, base, Nat.add_sub_cancel, Fin.val_cast] at hr ⊢; omega)
      refine hACols r.val ?_
      dsimp only [Fin.val_cast] at ho
      unfold shdOpenedCols shdTreeSqBase at ho; dsimp only at ho; rw [hdA, ite_eq_right hs0, ite_eq_right hs27] at ho
      have hidx : 209507 + blkStepFixedLen * k.val + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + 146 + 4577 + 36 + 1
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 64 := by
        simp only [s, Nat.add_sub_cancel, blkSegFixedLen, zkBMaskFixedLen]; omega
      rw [hidx]; exact ho) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 12 50 (by omega) _ _ _ _ H vf _ j fun r hr => by
      have ho := hVis (.m s) r (by
        unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]; simp only [s, base, Nat.add_sub_cancel] at hr ⊢; omega)
      refine hMCols r.val ?_
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at ho; dsimp only at ho; rw [ite_eq_right hs0, ite_eq_right hs27] at ho
      have hidx : 209507 + blkStepFixedLen * k.val + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + 2 * 23 + 5
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 4824 - 64 := by
        simp only [s, Nat.add_sub_cancel, blkSegFixedLen]; omega
      rw [hidx]; exact ho) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (trChallengeFp2Keyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 16 4390 (by omega) _ _ _ _ H vf _ j fun r hr => by
      have hdH : shdTreeDepthOf (.h s) = 16 := by unfold shdTreeDepthOf shdAHDepth; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]
      have ho := hVis (.h s) (Fin.cast (by rw [hdH]) r) (by
        unfold shdTreeBase; dsimp only; rw [ite_eq_right hs0, ite_eq_right hs27]; simp only [s, base, Nat.add_sub_cancel, Fin.val_cast] at hr ⊢; omega)
      refine hHCols r.val ?_
      dsimp only [Fin.val_cast] at ho
      unfold shdOpenedCols shdTreeSqBase at ho; dsimp only at ho; rw [hdH, ite_eq_right hs0, ite_eq_right hs27] at ho
      have hidx : 209507 + blkStepFixedLen * k.val + (2 ^ 16 + (2 ^ 16 - 1)) + 1 + 1 + 3 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 1 + 1 + 1 + (2 ^ 16 + (2 ^ 16 - 1)) + 3 + 1283 + zkBMaskFixedLen 23 + openingAuditFixedLen 146 4577 36 Exec.R13.r13Prm.nQ + 54 + 4390 + 9 + 1
          = 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 64 := by
        simp only [s, Nat.add_sub_cancel, blkSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, Exec.R13.r13Prm]; omega
      rw [hidx]; exact ho) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  have hact1_ok := slotsProveFixedProg_active_true hsl1
  rw [hact1_ok] at hsl1 hsl2 ⊢
  refine ptAt_andThen_step_res ((slotsProveFixedProg_ptLen Lq hL20 key P _ _ _ _ 23 true [] 0 {} _).congr h1283)
    ((slotsProveFixedProg_ptLen Lq hL20 key P _ _ _ _ 23 true [] 0 {} _).congr h1283) hsl1 hsl2
    (fun _ => slotsProveFixedProg_ptAt_eq Lq hL20 key P _ _ _ _ _ H vf 23 [] [] 0 {} {} _ _ j sps₁ recs₁ recs₂ acc₁ acc₂ tsl1 tsl1 hsl1 hsl2) fun _ => ?_
  dsimp only; simp only [hact1', hact2']
  refine ptAt_andThen_step_res (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 23 _ _ tsl1)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 23 _ _ tsl1) hm1 hm2
    (fun _ => zkBMaskFixedProg_ptAt_eq Lq hL20 key _ _ 23 _ _ _ _ tsl1 H vf _ j hmOEq) fun _ => ?_
  dsimp only
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ true _ _ tm1)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ true _ _ tm1) ha1 ha2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ true true _ _ _ _ tm1 H vf _ j aO₁ (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ true _ _ ta1)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ true _ _ ta1) hh1 hh2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ true true _ _ _ _ ta1 H vf _ j hO₁ (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev true _ _ th1)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev true _ _ th1) hb1 hb2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ _ treeBPrev treeBPrev true true _ _ _ _ th1 H vf _ j bO₁ (congrArg Prod.fst hb1) (congrArg Prod.fst hb2)) fun _ => ?_
  dsimp only; split <;> rfl

private def BlkSegSndEq (a b : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) : Prop :=
  a.2 = b.2

private theorem blkSegFixedProg_snd_cr_indep {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k0 : Fin 26) (cr₁ cr₂ : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr)
    (H : QB Lq → Dig) (vf : ℕ → Dig) (base : ℕ) :
    BlkSegSndEq
      ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c k0 true cr₁ treeB bnd startTag t).res H vf base)
      ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c k0 true cr₂ treeB bnd startTag t).res H vf base) := by
  unfold blkSegFixedProg
  have h1283 := shdP_blk_slotsFixedLen tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR k0.val k0.isLt
  refine res_andThen_self (B := BlkSegSndEq) (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trChallengeFp2Keyed_ptLen Lq (by omega) key _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trChallengeFp2Keyed_ptLen Lq (by omega) key _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (trChallengeFp2Keyed_ptLen Lq (by omega) key _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _).congr h1283) fun slR => ?_
  refine res_andThen_self (B := BlkSegSndEq) (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _) fun _ => ?_
  refine res_andThen_self (B := BlkSegSndEq) (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) fun aR => ?_
  refine res_andThen_self (B := BlkSegSndEq) (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) fun hR => ?_
  refine res_andThen_rel (A := fun (a b : Option Exec.Block.OpeningZk × Tr) => a.2 = b.2) (B := BlkSegSndEq)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB _ _ _ _)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB _ _ _ _)
    (by rw [openingAuditFixedProg_res_tr, openingAuditFixedProg_res_tr])
    fun bR₁ bR₂ hbTr => ?_
  rcases slR with ⟨so, _⟩; rcases aR with ⟨ao, _⟩; rcases hR with ⟨ho, _⟩
  rcases bR₁ with ⟨bo₁, bt₁⟩; rcases bR₂ with ⟨bo₂, bt₂⟩; dsimp only at hbTr; subst hbTr
  cases so with
  | none => rfl
  | some _ =>
    cases ao with
    | none => rfl
    | some _ =>
      cases ho with
      | none => rfl
      | some _ =>
        cases bo₁ <;> cases bo₂ <;> simp only [BlkSegSndEq, PProg.res] <;> (try split) <;> (try split) <;> rfl

private theorem seg_snd_trans
    {a b c : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr}
    {o₁ o₂ : Option ((Dig → List UInt8) × Carry)} {tr₁ tr₂ : MerkleLevels 16} {t₁ t₂ : Tr}
    (hs1 : SegShapeRel a b) (hs2 : BlkSegSndEq b c)
    (ha : a = (o₁, tr₁, t₁)) (hc : c = (o₂, tr₂, t₂)) :
    tr₁ = tr₂ ∧ t₁ = t₂ := by
  subst ha; subst hc
  exact ⟨hs1.1.trans (congrArg Prod.fst hs2), hs1.2.1.trans (congrArg Prod.snd hs2)⟩

/-- **Inductive 26-block chain active wire recovery & `ptAt` equality**. -/
theorem blkChainFixedProg_decode_ptAt_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (c₁ c₂ : ShdCoins) (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (cr₁ cr₂ : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr)
      (bs : List (List UInt8)) (cr₁' cr₂' : Carry) (tr₁ tr₂ : MerkleLevels 16) (t₁ t₂ : Tr) (e₁ e₂ : Dig),
      (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x₁ hx₁ c₁ startIdx count hEnd true cr₁ treeB bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * startIdx)
        = (some (bs, cr₁'), tr₁, t₁, e₁) →
      (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x₂ hx₂ c₂ startIdx count hEnd true cr₂ treeB bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * startIdx)
        = (some (bs, cr₂'), tr₂, t₂, e₂) →
      (∀ (k : Fin 26), startIdx ≤ k.val → k.val < startIdx + count →
        ∀ r ∈ shdOpenedCols v (.bnd ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩),
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).cols r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).cols r
          ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).salts r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).salts r)
      ∧ ∀ (j : ℕ),
          (∀ tid (r : Fin (2 ^ shdTreeDepthOf tid)), j = shdTreeBase tid + r.val → r.val ∈ shdOpenedCols v tid) →
          (∀ r ∈ shdOpenedCols v (.bnd ⟨startIdx + count, by omega⟩),
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨startIdx + count, by omega⟩).cols r
              = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨startIdx + count, by omega⟩).cols r
            ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨startIdx + count, by omega⟩).salts r
              = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨startIdx + count, by omega⟩).salts r) →
          (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
            x₁ hx₁ c₁ startIdx count hEnd true cr₁ treeB bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * startIdx) j
          = (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
            x₂ hx₂ c₂ startIdx count hEnd true cr₂ treeB bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * startIdx) j := by
  intro startIdx count
  induction count generalizing startIdx with
  | zero =>
    intro hEnd cr₁ cr₂ treeB bnd startTag t bs cr₁' cr₂' tr₁ tr₂ t₁ t₂ e₁ e₂ _ _
    exact ⟨fun k h1 h2 => by omega, fun _ _ _ => by simp only [blkChainFixedProg, PProg.ptAt]⟩
  | succ count ihRec =>
    intro hEnd cr₁ cr₂ treeB bnd startTag t bs cr₁' cr₂' tr₁ tr₂ t₁ t₂ e₁ e₂ h1 h2
    let base := 209507 + blkStepFixedLen * startIdx
    let vf := shdExtV v
    let k0 : Fin 26 := ⟨startIdx, by omega⟩
    unfold blkChainFixedProg at h1 h2
    obtain ⟨⟨ob1, trb1, tb1⟩, hb1, h1⟩ := res_andThen_hyp_bind (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ k0 true cr₁ treeB bnd startTag t) h1
    replace h1 := res_andThen_hyp (posTagKeyed_ptLen Lq (by omega) key _) (posTagKeyed_res ..) h1
    obtain ⟨⟨ob2, trb2, tb2⟩, hb2, h2⟩ := res_andThen_hyp_bind (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ k0 true cr₂ treeB bnd startTag t) h2
    replace h2 := res_andThen_hyp (posTagKeyed_ptLen Lq (by omega) key _) (posTagKeyed_res ..) h2
    cases ob1 with
    | none =>
      obtain ⟨_, _, h1⟩ := res_andThen_hyp_bind (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ (startIdx + 1) count (by omega) false _ trb1 bnd _ tb1) h1
      cases h1
    | some vb1 =>
    cases ob2 with
    | none =>
      obtain ⟨_, _, h2⟩ := res_andThen_hyp_bind (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ (startIdx + 1) count (by omega) false _ trb2 bnd _ tb2) h2
      cases h2
    | some vb2 =>
    rcases vb1 with ⟨enc₁, cr1'⟩; rcases vb2 with ⟨enc₂, cr2'⟩
    have hstep : base + blkSegFixedLen + 2 = 209507 + blkStepFixedLen * (startIdx + 1) := by dsimp [base]; unfold blkStepFixedLen; ring
    rw [hstep] at h1 h2
    obtain ⟨⟨orc1, trc1, tc1, ec1⟩, hrc1, h1⟩ := res_andThen_hyp_bind (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ (startIdx + 1) count (by omega) true cr1' trb1 bnd _ tb1) h1
    obtain ⟨⟨orc2, trc2, tc2, ec2⟩, hrc2, h2⟩ := res_andThen_hyp_bind (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ (startIdx + 1) count (by omega) true cr2' trb2 bnd _ tb2) h2
    cases orc1 with | none => cases h1 | some vc1 =>
    cases orc2 with | none => cases h2 | some vc2 =>
    rcases vc1 with ⟨bs₁, cro1⟩; rcases vc2 with ⟨bs₂, cro2⟩
    simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1 h2
    have hCons := h1.1.1.trans h2.1.1.symm
    simp only [List.cons.injEq] at hCons
    obtain ⟨hBytes, hbsEq⟩ := hCons
    subst hbsEq
    have hTrEq : trb1 = trb2 ∧ tb1 = tb2 :=
      seg_snd_trans
        (blkSegFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₁ x₂ hx₁ hx₂ c₁ c₂ k0 true cr₁ cr₁ rfl treeB bnd startTag t H (shdExtV v) (209507 + blkStepFixedLen * startIdx))
        (blkSegFixedProg_snd_cr_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x₂ hx₂ c₂ k0 cr₁ cr₂ treeB bnd startTag t H (shdExtV v) (209507 + blkStepFixedLen * startIdx))
        hb1 hb2
    obtain ⟨htrbEq, htbEq⟩ := hTrEq
    subst htrbEq htbEq
    have hBlk0 := blkSegFixedProg_decode_ptAt_eq (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x₁ x₂ hx₁ hx₂ c₁ c₂ k0 cr₁ cr₂ treeB bnd startTag t H v (posTagOfV vf (base + blkSegFixedLen))
      enc₁ enc₂ cr1' cr2' trb1 trb1 tb1 tb1 hb1 hb2 hBytes
    have ih := ihRec (startIdx + 1) (by omega) cr1' cr2' trb1 bnd (posTagOfV vf (base + blkSegFixedLen)) tb1
      bs₁ cro1 cro2 trc1 trc2 tc1 tc2 ec1 ec2 hrc1 hrc2
    refine ⟨fun k hk1 hk2 => ?_, fun j hVis hBEnd => ?_⟩
    · by_cases hk : k.val = startIdx
      · have hkf : k = k0 := Fin.ext hk; subst hkf; exact hBlk0.1
      · exact ih.1 k (by omega) (by omega)
    · have hBNext : ∀ r ∈ shdOpenedCols v (.bnd ⟨startIdx + 1, by omega⟩),
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨startIdx + 1, by omega⟩).cols r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨startIdx + 1, by omega⟩).cols r
          ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨startIdx + 1, by omega⟩).salts r
            = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨startIdx + 1, by omega⟩).salts r := by
        cases count with
        | zero => exact hBEnd
        | succ c' => exact ih.1 ⟨startIdx + 1, by omega⟩ le_rfl (by dsimp only; omega)
      unfold blkChainFixedProg
      refine ptAt_andThen_step_res
        (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ k0 true cr₁ treeB bnd startTag t)
        (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ k0 true cr₂ treeB bnd startTag t)
        hb1 hb2 (fun _ => hBlk0.2 j hVis hBNext) fun _ => ?_
      dsimp only [Option.isSome_some]
      refine ptAt_andThen_self (posTagKeyed_ptLen Lq (by omega) key tb1) (posTagKeyed_res ..) fun _ => ?_
      rw [show 209507 + blkStepFixedLen * startIdx + blkSegFixedLen + 2 = 209507 + blkStepFixedLen * (startIdx + 1) by unfold blkStepFixedLen; ring]
      refine ptAt_andThen_step_res
        (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁ hx₁ c₁ (startIdx + 1) count (by omega) true cr1' trb1 bnd _ tb1)
        (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂ hx₂ c₂ (startIdx + 1) count (by omega) true cr2' trb1 bnd _ tb1)
        hrc1 hrc2
        (fun _ => by
          have hfin : (⟨startIdx + 1 + count, by omega⟩ : Fin 27) = ⟨startIdx + (count + 1), by omega⟩ := Fin.ext (by dsimp only; omega)
          rw [← hfin] at hBEnd
          exact ih.2 j hVis hBEnd)
        fun _ => rfl

/-- **Stage OUT-C active wire recovery & `ptAt` equality** (when `verdict₁ = verdict₂`):
from equal encoded Stage OUT-C bytes `enc₁ eOut = enc₂ eOut`, extracts equal `B_26` opened cols/salts AND
proves `outcSegFixedProg.ptAt` equality at every visible index `j`! -/
theorem outcSegFixedProg_decode_ptAt_eq (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x₁ x₂ : shieldS0.Tok → ℕ) (hx₁ : (classifyModelP Rp).admissible x₁) (hx₂ : (classifyModelP Rp).admissible x₂)
    (hVerd : (classifySpecP Rp x₁).getD 0 = (classifySpecP Rp x₂).getD 0)
    (c₁ c₂ : ShdCoins) (cr₁ cr₂ : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (eOut : Dig)
    (enc₁ enc₂ : Dig → List UInt8) (t₁ t₂ : Tr)
    (h1 : (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x₁ hx₁ c₁ true cr₁ treeB26 bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * 26)
      = (some enc₁, t₁))
    (h2 : (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x₂ hx₂ c₂ true cr₂ treeB26 bnd startTag t).res H (shdExtV v) (209507 + blkStepFixedLen * 26)
      = (some enc₂, t₂))
    (hBytes : enc₁ eOut = enc₂ eOut) :
    (∀ r ∈ shdOpenedCols v (.bnd ⟨26, by omega⟩),
      (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨26, by omega⟩).cols r
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨26, by omega⟩).cols r
      ∧ (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₁) (shdBlkRndOf c₁) x₁ hx₁ ⟨26, by omega⟩).salts r
        = (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c₂) (shdBlkRndOf c₂) x₂ hx₂ ⟨26, by omega⟩).salts r)
    ∧ ∀ (j : ℕ),
        (∀ tid (r : Fin (2 ^ shdTreeDepthOf tid)), j = shdTreeBase tid + r.val → r.val ∈ shdOpenedCols v tid) →
        (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          x₁ hx₁ c₁ true cr₁ treeB26 bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * 26) j
        = (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          x₂ hx₂ c₂ true cr₂ treeB26 bnd startTag t).ptAt H (shdExtV v) (209507 + blkStepFixedLen * 26) j := by
  let base := 209507 + blkStepFixedLen * 26
  let s : Fin 28 := ⟨27, by decide⟩
  let vf := shdExtV v
  set vd := (classifySpecP Rp x₂).getD 0
  let V := shdVo tag Rp wDigest bOutRow vd
  let G := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
  have hLay0 : V.lay = (shdVo tag Rp wDigest bOutRow 0).lay := by
    change outcLay (rcVerdict (shdP_outcPub Rp wDigest) vd) 14 = outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14
    rw [rc_outcLay_verdict, rc_outcLay_verdict]
  have hBlk0 : V.blk = (shdVo tag Rp wDigest bOutRow 0).blk := rfl
  have hGeom0 : V.geom = (shdVo tag Rp wDigest bOutRow 0).geom := by
    change mGeom V.lay V.blk _ _ = mGeom (shdVo tag Rp wDigest bOutRow 0).lay (shdVo tag Rp wDigest bOutRow 0).blk _ _; rw [hLay0, hBlk0]
  have h290 := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow vd
  have hV_aR : V.lay.aRows = 76 := by rw [hLay0]; exact (shdP_outcLay_nums Rp wDigest).1
  have hV_hR : V.lay.hRows = 38 := by rw [hLay0]; exact (shdP_outcLay_nums Rp wDigest).2.1
  have hV_mR : V.lay.mRows = 20 := by
    have hns : V.lay.ns = 8 := by rw [hLay0]; rfl
    unfold Lay.mRows; rw [hns]
  unfold outcSegFixedProg at h1 h2
  rw [hVerd] at h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 20 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h1
  replace h1 := res_andThen_hyp (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 2 _) (trChallengeFp2VecKeyed_res ..) h1
  replace h1 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 38 (by omega) _ _) (merkleTableProg_res ..) h1
  replace h1 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h1
  obtain ⟨⟨osl1, tsl1⟩, hsl1, h1⟩ := res_andThen_hyp_bind ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr h290) h1
  obtain ⟨⟨mO₁, tm1⟩, hm1, h1⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _) h1
  obtain ⟨⟨oa1, ta1⟩, ha1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _) h1
  obtain ⟨⟨oh1, th1⟩, hh1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _) h1
  obtain ⟨⟨ob1, tb1⟩, hb1, h1⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _) h1
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 12 20 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) h2
  replace h2 := res_andThen_hyp (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 2 _) (trChallengeFp2VecKeyed_res ..) h2
  replace h2 := res_andThen_hyp (merkleTableProg_ptLen Lq (by omega) tag 14 38 (by omega) _ _) (merkleTableProg_res ..) h2
  replace h2 := res_andThen_hyp (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) h2
  obtain ⟨⟨osl2, tsl2⟩, hsl2, h2⟩ := res_andThen_hyp_bind ((slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _).congr h290) h2
  obtain ⟨⟨mO₂, tm2⟩, hm2, h2⟩ := res_andThen_hyp_bind (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _) h2
  obtain ⟨⟨oa2, ta2⟩, ha2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _) h2
  obtain ⟨⟨oh2, th2⟩, hh2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _) h2
  obtain ⟨⟨ob2, tb2⟩, hb2, h2⟩ := res_andThen_hyp_bind (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 _ _ _ _) h2
  cases osl1 with | none => cases h1 | some vsl1 =>
  cases osl2 with | none => cases h2 | some vsl2 =>
  rcases vsl1 with ⟨sps₁, recs₁, acc₁⟩
  rcases vsl2 with ⟨sps₂, recs₂, acc₂⟩
  cases oa1 with | none => cases h1 | some aO₁ =>
  cases oa2 with | none => cases h2 | some aO₂ =>
  cases oh1 with | none => cases h1 | some hO₁ =>
  cases oh2 with | none => cases h2 | some hO₂ =>
  cases ob1 with | none => cases h1 | some bO₁ =>
  cases ob2 with | none => cases h2 | some bO₂ =>
  simp only [Option.isSome_some, Bool.and_true] at h1 h2 hm1 hm2 ha1 ha2 hh1 hh2 hb1 hb2
  split at h1; swap; · simp only [PProg.res, Prod.mk.injEq] at h1; cases h1.1
  rename_i hact1'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h1
  split at h2; swap; · simp only [PProg.res, Prod.mk.injEq] at h2; cases h2.1
  rename_i hact2'; simp only [PProg.res, Prod.mk.injEq, Option.some.injEq] at h2
  have h1_1 := h1.1; have h2_1 := h2.1
  rw [hact1'] at hm1 ha1 hh1 hb1; rw [hact2'] at hm2 ha2 hh2 hb2
  have hsegOk : ∀ (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (cr : Carry)
      (b g a : Fp2) (actSl : Bool) (tSl0 : Tr) (bSl : ℕ)
      (trM : MerkleLevels 12) (bM : ℕ) (gA : OpenGeom) (trA : MerkleLevels 14) (hdrA : Bool) (bA : ℕ)
      (gH : OpenGeom) (trH : MerkleLevels 14) (hdrH : Bool) (bH : ℕ) (gB : OpenGeom) (hdrB : Bool) (bB : ℕ)
      (aRoot hRoot mRoot : Dig)
      (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (tsl tm ta th tb : Tr)
      (mO : Exec.Block.MaskOpening) (aO hO bO : Exec.Block.OpeningZk),
      let w := outcWitness_of_adm Rp houtPub x hx
      let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩
      (slotsProveFixedProg Lq hL20 key V.bp (shdP_outcSlotData tag Rp wDigest bOutRow vd w (shdP_outcTA Rp w (shdOutcRndOf c)) TB26 (shdOutcRndOf c)) b g a 8 actSl [] 0 {} tSl0).res H vf bSl = (some (sps, recs, acc), tsl) →
      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true (shdP_outcM (shdOutcRndOf c)) 8 trM (acc.fs ++ acc.hostFs) tsl).res H vf bM = (mO, tm) →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA (shdP_outcTA Rp w (shdOutcRndOf c)) trA true hdrA acc.claims.a tm).res H vf bA = (some aO, ta) →
      (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (shdP_outcTH Rp w (shdOutcRndOf c) g a) trH true hdrH (acc.claims.h ++ [V.lay.logupSumClaim]) ta).res H vf bH = (some hO, th) →
      (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 gB TB26 treeB26 true hdrB (cr.pending ++ acc.claims.inp) th).res H vf bB = (some bO, tb) →
      let seg : StageSeg := ⟨none, ⟨aRoot, hRoot, mRoot, sps, mO, aO, hO⟩, [bO]⟩
      CoreCanon seg.core ∧ CoreShape G.g seg.core ∧ seg.bRoot.isSome = G.hasB ∧ List.Forall₂ CloseOk G.closes seg.closes := by
    intro x hx c cr b g a actSl tSl0 bSl trM bM gA trA hdrA bA gH trH hdrH bH gB hdrB bB aRoot hRoot mRoot
      sps recs acc tsl tm ta th tb mO aO hO bO w TB26 hsl hm ha hh hb
    have hSlCS := slotsProveFixedProg_canon_shape Lq hL20 key V.bp _ _ _
      (fun s' _ _ _ _ => by cases V.bp.kind s' <;> exact ofK_canon shdP_U shdP_hbij _)
      (fun s' _ _ df _ rho => ⟨stgPrivVals_canon shdP_U shdP_hbij _ _ _ _ df.tabs, stgPrivVals_length shdP_U shdP_hbij _ _ _ _ df.tabs⟩)
      b g a H vf 8 actSl [] 0 {} tSl0 bSl sps recs acc tsl hsl
    have hmSp := zkBMaskFixedProg_res_spec Lq hL20 key shdP_U shdP_hbij (shdP_outcM (shdOutcRndOf c)) 8 trM (acc.fs ++ acc.hostFs) tsl H vf bM
    rw [hm] at hmSp; dsimp only at hmSp
    have haSp := openingAuditFixedProg_res_spec Lq hL20 key shdP_stgPrm 14 29 76 16
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gA (shdP_outcTA Rp w (shdOutcRndOf c))
      (shdP_outcTA_rows_len Rp w _) (fun j => (mkPcsTable_cols_length ..).trans (shdP_outcTA_rows_len Rp w _))
      (mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _) trA true hdrA acc.claims.a tm H vf bA aO (congrArg Prod.fst ha)
    have hhSp := openingAuditFixedProg_res_spec Lq hL20 key shdP_stgPrm 14 10 38 5
      (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl gH (shdP_outcTH Rp w (shdOutcRndOf c) g a)
      (shdP_outcTH_rows_len Rp w _ g a) (fun j => (mkPcsTable_cols_length ..).trans (shdP_outcTH_rows_len Rp w _ g a))
      (mkPcsTable_cols_canon 12 2 256 (by norm_num) _ _) trH true hdrH _ ta H vf bH hO (congrArg Prod.fst hh)
    have hTBsp := shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩
    have hbSp := openingAuditFixedProg_res_spec Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl gB TB26 hTBsp.rows_len hTBsp.cols_len hTBsp.cols_canon
      treeB26 true hdrB _ th H vf bB bO (congrArg Prod.fst hb)
    refine ⟨⟨hSlCS.2.1, hmSp.1, haSp.1, hhSp.1⟩, ?_, rfl, ?_⟩
    · change CoreShape (shdVo tag Rp wDigest bOutRow 0).geom _
      rw [← hGeom0]
      refine ⟨hSlCS.1.trans (by
          change 8 = V.lay.geomSlots.length
          rw [hLay0]
          change 8 = (outcLay (shdP_outcPub Rp wDigest) 14).geomSlots.length
          rw [(shdP_outcLay_nums Rp wDigest).2.2.2]; rfl),
        fun i p sh tm hp hsh htm => hSlCS.2.2 i p sh tm hp (by rwa [Nat.zero_add]) (by rwa [Nat.zero_add]),
        hmSp.2.2.1, hmSp.2.2.2.1, hmSp.2.2.2.2.1,
        fun col hcol => ⟨(hmSp.2.2.2.2.2 col hcol).1, (hmSp.2.2.2.2.2 col hcol).2.1.trans hV_mR.symm, (hmSp.2.2.2.2.2 col hcol).2.2⟩,
        fun o ho => by
          simp only [List.mem_cons, List.not_mem_nil, or_false] at ho
          rcases ho with rfl | rfl
          · exact ⟨haSp.2.2.2.1, haSp.2.2.1, haSp.2.2.2.2.1, fun col hcol => ⟨(haSp.2.2.2.2.2 col hcol).1, (haSp.2.2.2.2.2 col hcol).2.2⟩⟩
          · exact ⟨hhSp.2.2.2.1, hhSp.2.2.1, hhSp.2.2.2.2.1, fun col hcol => ⟨(hhSp.2.2.2.2.2 col hcol).1, (hhSp.2.2.2.2.2 col hcol).2.2⟩⟩,
        haSp.2.1, hhSp.2.1,
        fun col hcol => (haSp.2.2.2.2.2 col hcol).2.1.trans hV_aR.symm,
        fun col hcol => (hhSp.2.2.2.2.2 col hcol).2.1.trans hV_hR.symm⟩
    · exact List.Forall₂.cons ⟨hbSp.1, ⟨hbSp.2.1, hbSp.2.2.1, hbSp.2.2.2.1, hbSp.2.2.2.2.1, hbSp.2.2.2.2.2⟩,
        by unfold shdVo shdP_outcV outcVAt; dsimp only; decide⟩ List.Forall₂.nil
  have htrSlEq : tsl1 = tsl2 := by
    have e1 : _ = tsl1 := congrArg Prod.snd hsl1
    have e2 : _ = tsl2 := congrArg Prod.snd hsl2
    rw [← e1, ← e2]
    exact (slotsProveFixedProg_shape_indep Lq hL20 key V.bp V.bp _ _ (fun _ => rfl) rfl rfl rfl rfl
      (fun s' hist dr => by cases V.bp.define s' hist dr <;> simp [TabsShapeEq.refl])
      _ _ _ H vf 8 _ [] [] 0 {} {} _ _ rfl ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩).1
  have hgt : G.g.slots.length = G.g.terms.length := by
    change (outcLay (shdP_outcPub Rp wDigest) 14).geomSlots.length
      = (outcLay (shdP_outcPub Rp wDigest) 14).geomTerms.length
    rw [(shdP_outcLay_nums Rp wDigest).2.2.2]; rfl
  rw [← h1_1, ← h2_1] at hBytes
  have hSegEq := (rdStageBody_enc_inj G hgt
    (by dsimp only [G]; unfold rcOutcGeom shdVo shdP_outcV outcVAt OutcV.geom mGeom; dsimp only; decide)
    (by dsimp only [G]; unfold rcOutcGeom shdVo shdP_outcV outcVAt OutcV.geom mGeom; dsimp only; decide)
    rfl bnd startTag _ _ eOut eOut
    (hsegOk x₁ hx₁ c₁ cr₁ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₁ recs₁ acc₁ tsl1 tm1 ta1 th1 tb1 mO₁ aO₁ hO₁ bO₁ hsl1 hm1 ha1 hh1 hb1)
    (hsegOk x₂ hx₂ c₂ cr₂ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ sps₂ recs₂ acc₂ tsl2 tm2 ta2 th2 tb2 mO₂ aO₂ hO₂ bO₂ hsl2 hm2 ha2 hh2 hb2)
    hBytes).1
  clear hsegOk
  have hspsEq : sps₁ = sps₂ := congrArg (fun x => x.core.slots) hSegEq
  have hmOEq' : mO₁ = mO₂ := congrArg (fun x => x.core.maskOpen) hSegEq
  have haOEq : aO₁ = aO₂ := congrArg (fun x => x.core.aOpen) hSegEq
  have hhOEq : hO₁ = hO₂ := congrArg (fun x => x.core.hOpen) hSegEq
  have hbOEq : bO₁ = bO₂ := by
    have := congrArg StageSeg.closes hSegEq; simpa using this
  subst hspsEq hmOEq' haOEq hhOEq hbOEq htrSlEq
  have htmEq : tm1 = tm2 := by
    have e1 := congrArg Prod.snd hm1; have e2 := congrArg Prod.snd hm2
    rw [zkBMaskFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htmEq
  have htaEq : ta1 = ta2 := by
    have e1 := congrArg Prod.snd ha1; have e2 := congrArg Prod.snd ha2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst htaEq
  have hthEq : th1 = th2 := by
    have e1 := congrArg Prod.snd hh1; have e2 := congrArg Prod.snd hh2
    rw [openingAuditFixedProg_res_tr] at e1 e2
    exact e1.symm.trans e2
  subst hthEq
  have hmOEq := (congrArg Prod.fst hm1).trans (congrArg Prod.fst hm2).symm
  have hB26Cols := openingAuditFixedProg_cols_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2
    (by norm_num [Exec.R13.r13Prm, PcsPrm.nn]) rfl _ _ _ treeB26 treeB26 true true _ _ _ _ th1 H vf _ bO₁
    (congrArg Prod.fst hb1) (congrArg Prod.fst hb2)
  have hACols := openingAuditFixedProg_cols_eq Lq hL20 key shdP_stgPrm 14 29 76 16
    (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ tm1 H vf _ aO₁
    (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)
  have hHCols := openingAuditFixedProg_cols_eq Lq hL20 key shdP_stgPrm 14 10 38 5
    (by norm_num [shdP_stgPrm, PcsPrm.nn]) rfl _ _ _ _ _ true true _ _ _ _ ta1 H vf _ hO₁
    (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)
  have hMCols := zkBMaskFixedProg_cols_eq Lq hL20 key _ _ 8 _ _ _ _ tsl1 H vf _ hmOEq
  refine ⟨fun r hr => hB26Cols r (by
      unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at hr; dsimp only at hr; rw [ite_eq_right (by omega)] at hr
      have hidx : 209507 + blkStepFixedLen * 26 + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ + openingAuditFixedLen 10 38 5 shdP_stgPrm.nQ + 2 + 38 + 2 + 1
          = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 64 := by
        simp only [outcSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm, Exec.R13.r13Prm]; omega
      rw [hidx]; exact hr),
    fun j hVis => ?_⟩
  unfold outcSegFixedProg
  rw [hVerd]
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 14 76 (by omega) _ _ _ _ H vf _ j fun r hr =>
      hACols r.val (by
        have ho := hVis (.a s) r (by unfold shdTreeBase; dsimp only [s, base] at hr ⊢; simp only [Nat.reduceEqDiff, ↓reduceIte]; omega)
        unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase at ho; dsimp only [s] at ho; simp only [Nat.reduceEqDiff, ↓reduceIte] at ho
        have hidx : 209507 + blkStepFixedLen * 26 + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + 29 + 76 + 16 + 1
            = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 64 := by
          simp only [outcSegFixedLen, zkBMaskFixedLen]; omega
        rw [hidx]; exact ho)) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (Nat.le_trans (by decide) hL20) tag 12 20 (Nat.le_trans (by decide) hL20) _ _)
    (merkleTableProg_ptLen Lq (Nat.le_trans (by decide) hL20) tag 12 20 (Nat.le_trans (by decide) hL20) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (Nat.le_trans (by decide) hL20) tag 12 20 (Nat.le_trans (by decide) hL20) _ _ _ _ H vf _ j fun r hr =>
      hMCols r.val (by
        have ho := hVis (.m s) r (by unfold shdTreeBase; dsimp only [s]; simp only [Nat.reduceEqDiff, ↓reduceIte]; rw [hr]; simp only [Nat.add_assoc]; rw [show 1 + (1 + (2 ^ 14 + (2 ^ 14 - 1 + (3 + r.val)))) = 2 + (32767 + (3 + r.val)) by omega])
        unfold shdOpenedCols shdTreeDepthOf shdTreeSqBase at ho; dsimp only [s] at ho; simp only [Nat.reduceEqDiff, ↓reduceIte] at ho
        have hidx : 209507 + blkStepFixedLen * 26 + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + 2 * 8 + 5
            = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 186 - 64 := by
          simp only [outcSegFixedLen]; omega
        rw [hidx]; exact ho)) fun _ => ?_
  refine ptAt_andThen_self (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (trAbsorbKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_self (trChallengeFp2VecKeyed_ptLen Lq (Nat.le_trans (by decide) hL20) key 2 _) (trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (Nat.le_trans (by decide) hL20) tag 14 38 (Nat.le_trans (by decide) hL20) _ _)
    (merkleTableProg_ptLen Lq (Nat.le_trans (by decide) hL20) tag 14 38 (Nat.le_trans (by decide) hL20) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (Nat.le_trans (by decide) hL20) tag 14 38 (Nat.le_trans (by decide) hL20) _ _ _ _ H vf _ j fun r hr =>
      hHCols r.val (by
        have ho := hVis (.h s) r (by unfold shdTreeBase; dsimp only [s]; simp only [Nat.reduceEqDiff, ↓reduceIte]; rw [hr]; simp only [Nat.add_assoc]; rw [show 1 + (1 + (2 ^ 14 + (2 ^ 14 - 1 + (3 + (2 ^ 12 + (2 ^ 12 - 1 + (1 + (2 + r.val)))))))) = 2 + (32767 + (3 + (8191 + (3 + r.val)))) by omega])
        unfold shdOpenedCols shdTreeDepthOf shdAHDepth shdTreeSqBase at ho; dsimp only [s] at ho; simp only [Nat.reduceEqDiff, ↓reduceIte] at ho
        have hidx : 209507 + blkStepFixedLen * 26 + 1 + 1 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + (2 ^ 12 + (2 ^ 12 - 1)) + 1 + 2 + (2 ^ 14 + (2 ^ 14 - 1)) + 3 + 290 + zkBMaskFixedLen 8 + openingAuditFixedLen 29 76 16 shdP_stgPrm.nQ + 10 + 38 + 5 + 1
            = 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 64 := by
          simp only [outcSegFixedLen, zkBMaskFixedLen, openingAuditFixedLen, shdP_stgPrm]; omega
        rw [hidx]; exact ho)) fun _ => ?_
  refine ptAt_andThen_self (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (absorbRootKeyed_res ..) fun _ => ?_
  have hact1_ok := slotsProveFixedProg_active_true hsl1
  rw [hact1_ok] at hsl1 hsl2 ⊢
  refine ptAt_andThen_step_res ((slotsProveFixedProg_ptLen Lq hL20 key V.bp _ _ _ _ 8 true [] 0 {} _).congr h290)
    ((slotsProveFixedProg_ptLen Lq hL20 key V.bp _ _ _ _ 8 true [] 0 {} _).congr h290) hsl1 hsl2
    (fun _ => slotsProveFixedProg_ptAt_eq Lq hL20 key V.bp _ _ _ _ _ H vf 8 [] [] 0 {} {} _ _ j sps₁ recs₁ recs₂ acc₁ acc₂ tsl1 tsl1 hsl1 hsl2) fun _ => ?_
  dsimp only; simp only [hact1', hact2']
  refine ptAt_andThen_step_res (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 8 _ _ tsl1)
    (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij true _ 8 _ _ tsl1) hm1 hm2
    (fun _ => zkBMaskFixedProg_ptAt_eq Lq hL20 key _ _ 8 _ _ _ _ tsl1 H vf _ j hmOEq) fun _ => ?_
  dsimp only
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ true _ _ tm1)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ true _ _ tm1) ha1 ha2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ true true _ _ _ _ tm1 H vf _ j aO₁ (congrArg Prod.fst ha1) (congrArg Prod.fst ha2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ true _ _ ta1)
    (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ true _ _ ta1) hh1 hh2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ true true _ _ _ _ ta1 H vf _ j hO₁ (congrArg Prod.fst hh1) (congrArg Prod.fst hh2)) fun _ => ?_
  simp only [Option.isSome_some, Bool.and_self]
  refine ptAt_andThen_step_res (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 true _ _ th1)
    (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeB26 true _ _ th1) hb1 hb2
    (fun _ => openingAuditFixedProg_ptAt_eq Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ _ treeB26 treeB26 true true _ _ _ _ th1 H vf _ j bO₁ (congrArg Prod.fst hb1) (congrArg Prod.fst hb2)) fun _ => ?_
  dsimp only; split <;> rfl

private theorem scProveFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig) :
    ∀ (n : ℕ) (act : Bool) (wp : WProver n) (t : Tr),
      PProgResIndepH (scProveFixedProg Lq hL20 key n act wp t)
  | 0, _, _, _ => .ret _
  | n + 1, act, wp, t => by
    unfold scProveFixedProg
    refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => ?_
    refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
    refine .andThen (scProveFixedProg_ptLen Lq hL20 key n _ _ _) (scProveFixedProg_resIndepH Lq hL20 key n _ _ _) fun _ => .ret _

private theorem slotProveFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (s : ℕ) (act : Bool) (hist : Hist) (acc : Acc) (t : Tr) :
    PProgResIndepH (slotProveFixedProg Lq hL20 key P D s act hist acc t) := by
  unfold slotProveFixedProg
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => ?_
  refine .andThen (scProveFixedProg_ptLen Lq hL20 key _ _ _ _) (scProveFixedProg_resIndepH Lq hL20 key _ _ _ _) fun _ => ?_
  refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => .ret _

private theorem stSlotsProveFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (act : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      PProgResIndepH (stSlotsProveFixedProg Lq hL20 key P elog D b g a m act recs s acc t)
  | 0, _, _, _, _, _ => fun _ _ _ _ => rfl
  | m + 1, act, recs, s, acc, t => by
    unfold stSlotsProveFixedProg
    refine .andThen (slotProveFixedProg_ptLen Lq hL20 key _ _ s act _ acc t) (slotProveFixedProg_resIndepH Lq hL20 key _ _ s act _ acc t) fun r => ?_
    cases r.1 with
    | none =>
      refine .andThen (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m false recs (s + 1) acc r.2)
        (stSlotsProveFixedProg_resIndepH Lq hL20 key P elog D b g a m false recs (s + 1) acc r.2) fun _ => .ret _
    | some _ =>
      refine .andThen (stSlotsProveFixedProg_ptLen Lq hL20 key P elog D b g a m true _ (s + 1) _ r.2)
        (stSlotsProveFixedProg_resIndepH Lq hL20 key P elog D b g a m true _ (s + 1) _ r.2) fun r2 => by cases r2.1 <;> exact .ret _

private theorem slotsProveFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (act : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      PProgResIndepH (slotsProveFixedProg Lq hL20 key P D b g a m act recs s acc t)
  | 0, _, _, _, _, _ => fun _ _ _ _ => rfl
  | m + 1, act, recs, s, acc, t => by
    unfold slotsProveFixedProg
    refine .andThen (slotProveFixedProg_ptLen Lq hL20 key P D s act _ acc t) (slotProveFixedProg_resIndepH Lq hL20 key P D s act _ acc t) fun r => ?_
    cases r.1 with
    | none =>
      refine .andThen (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m false recs (s + 1) acc r.2)
        (slotsProveFixedProg_resIndepH Lq hL20 key P D b g a m false recs (s + 1) acc r.2) fun _ => .ret _
    | some _ =>
      refine .andThen (slotsProveFixedProg_ptLen Lq hL20 key P D b g a m true _ (s + 1) _ r.2)
        (slotsProveFixedProg_resIndepH Lq hL20 key P D b g a m true _ (s + 1) _ r.2) fun r2 => by cases r2.1 <;> exact .ret _

private theorem zkBMaskFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (act : Bool) (M : MTable) (S : ℕ) (tr : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr) :
    PProgResIndepH (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij act M S tr fs t) := by
  unfold zkBMaskFixedProg
  refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key t) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (.of_eq fun _ _ _ => trSqueezeVecKeyed_res ..) fun _ => .ret _

private theorem openingAuditFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (d nc rw ng : ℕ) (g : OpenGeom) (T : Table) (tr : MerkleLevels d)
    (act hdr : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) :
    PProgResIndepH (openingAuditFixedProg Lq hL20 key prm d nc rw ng g T tr act hdr cl t) := by
  unfold openingAuditFixedProg
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ t) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key _ _) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbVecsFixed_ptLen Lq hL20 key _ _ _) (.of_eq fun _ _ _ => trAbsorbVecsFixed_res ..) fun _ => ?_
  refine .andThen (trAbsorbFp2Keyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trSqueezeVecKeyed_ptLen Lq (by omega) key _ _) (.of_eq fun _ _ _ => trSqueezeVecKeyed_res ..) fun _ => .ret _

private theorem incSegFixedProg_resIndepH {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ) (x : shieldS0.Tok → ℕ) (c : ShdCoins)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) :
    PProgResIndepH (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t) := by
  unfold incSegFixedProg
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 14 41 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 12 12 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 15 _) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (stSlotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _) (stSlotsProveFixedProg_resIndepH Lq hL20 key _ _ _ _ _ _ 4 _ [] 0 {} _) fun slR => ?_
  refine .andThen (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 4 _ _ _) (zkBMaskFixedProg_resIndepH Lq hL20 key _ _ 4 _ _ _) fun _ => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key shdP_stgPrm 14 3 41 3 _ _ _ _ _ _ _) fun aOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key shdP_stgPrm 14 4 76 4 _ _ _ _ _ _ _) fun hOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key shdP_epPrm 11 1 6 1 _ _ treeTE _ _ _ _) fun eOR => ?_
  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases eOR.1 <;> (try split_ifs) <;> exact .ret _

private theorem blkSegFixedProg_resIndepH {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (act : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) :
    PProgResIndepH (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c k act cr treeBPrev bnd startTag t) := by
  unfold blkSegFixedProg
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 16 38 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 16 4577 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 12 50 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2Keyed_ptLen Lq (by omega) key _) (.of_eq fun _ _ _ => trChallengeFp2Keyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 16 4390 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _) (slotsProveFixedProg_resIndepH Lq hL20 key _ _ _ _ _ 23 _ [] 0 {} _) fun slR => ?_
  refine .andThen (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 23 _ _ _) (zkBMaskFixedProg_resIndepH Lq hL20 key _ _ 23 _ _ _) fun _ => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 _ _ _ _ _ _ _) fun aOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 _ _ _ _ _ _ _) fun hOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ treeBPrev _ _ _ _) fun bOR => ?_
  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;> exact .ret _

private theorem blkChainFixedProg_resIndepH {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26) (act : Bool) (cr : Carry) (trB : MerkleLevels 16) (bnd st : Dig) (t : Tr),
      PProgResIndepH (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c startIdx count hEnd act cr trB bnd st t)
  | _, 0, _, _, _, _, _, _, _ => fun _ _ _ _ => by simp only [blkChainFixedProg, PProg.res]
  | startIdx, count + 1, hEnd, act, cr, trB, bnd, st, t => by
    unfold blkChainFixedProg
    refine .andThen (blkSegFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c _ act cr trB bnd st t)
      (blkSegFixedProg_resIndepH (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c _ act cr trB bnd st t) fun r => ?_
    refine .andThen (posTagKeyed_ptLen Lq (by omega) key r.2.2) (.of_eq fun _ _ _ => posTagKeyed_res ..) fun eTag => ?_
    refine .andThen (blkChainFixedProg_ptLen (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c (startIdx + 1) count (by omega) _ _ _ bnd eTag r.2.2)
      (blkChainFixedProg_resIndepH (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x hx c (startIdx + 1) count (by omega) _ _ _ bnd eTag r.2.2) fun rest => ?_
    cases r.1 <;> cases rest.1 <;> exact .ret _

private theorem outcSegFixedProg_resIndepH (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (act : Bool) (cr : Carry) (trB26 : MerkleLevels 16) (bnd st : Dig) (t : Tr) :
    PProgResIndepH (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x hx c act cr trB26 bnd st t) := by
  unfold outcSegFixedProg
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 14 76 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 12 20 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (trAbsorbKeyed_ptLen Lq hL20 key _ _ _ _) (.of_eq fun _ _ _ => trAbsorbKeyed_res ..) fun _ => ?_
  refine .andThen (trChallengeFp2VecKeyed_ptLen Lq (by omega) key 2 _) (.of_eq fun _ _ _ => trChallengeFp2VecKeyed_res ..) fun _ => ?_
  refine .andThen (merkleTableProg_ptLen Lq (by omega) tag 14 38 (by omega) _ _) (.of_eq fun _ _ _ => merkleTableProg_res ..) fun _ => ?_
  refine .andThen (absorbRootKeyed_ptLen Lq hL20 key _ _ _ _ _ _) (.of_eq fun _ _ _ => absorbRootKeyed_res ..) fun _ => ?_
  refine .andThen (slotsProveFixedProg_ptLen Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _) (slotsProveFixedProg_resIndepH Lq hL20 key _ _ _ _ _ 8 _ [] 0 {} _) fun slR => ?_
  refine .andThen (zkBMaskFixedProg_ptLen Lq hL20 key shdP_U shdP_hbij _ _ 8 _ _ _) (zkBMaskFixedProg_resIndepH Lq hL20 key _ _ 8 _ _ _) fun _ => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key shdP_stgPrm 14 29 76 16 _ _ _ _ _ _ _) fun aOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key shdP_stgPrm 14 10 38 5 _ _ _ _ _ _ _) fun hOR => ?_
  refine .andThen (openingAuditFixedProg_ptLen Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ trB26 _ _ _ _) (openingAuditFixedProg_resIndepH Lq hL20 key Exec.R13.r13Prm 16 2 38 2 _ _ trB26 _ _ _ _) fun bOR => ?_
  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;> exact .ret _

/-- Static visibility predicate: every non-leaf point is visible, and a leaf `id` is visible iff
its column index lies in `shdOpenedCols v id.1`. -/
def shdIsVisibleAt {Lq : ℕ} (sched : Fin shdP_zkResPts → ShdPtSpec Lq)
    (v : Fin shdP_zkResPts → Dig) (i : Fin shdP_zkResPts) : Prop :=
  match sched i with
  | .leaf id => id.2.val ∈ shdOpenedCols v id.1
  | _ => True

/-- **Whole-run functional visibility theorem**: on any non-refused `v`, equal `outOf` implies equal
`ptsOf` at every visible index `i` (`shdIsVisibleAt sched v i`)! -/
theorem shdP_runFixedProg_ptsOf_eq {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (sched : Fin shdP_zkResPts → ShdPtSpec Lq)
    (hLeafSched : ∀ (tid : ShdTreeId) (r : Fin (2 ^ shdTreeDepthOf tid))
      (hlt : shdTreeBase tid + r.val < shdP_zkResPts),
      sched ⟨shdTreeBase tid + r.val, hlt⟩ = .leaf ⟨tid, r⟩)
    (x₁ x₂ : {x // (classifyModelP Rp).admissible x}) (c₁ c₂ : ShdCoins)
    (H : QB Lq → Dig) (v : Fin shdP_zkResPts → Dig) (i : Fin shdP_zkResPts)
    (hng : ¬ shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig v)
    (hvis : shdIsVisibleAt sched v i)
    (hOutEq : PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₁ c₁) v
      = PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₂ c₂) v) :
    PProg.ptsOf (shdP_zkPad Lq hL20) (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₁ c₁) H v i
      = PProg.ptsOf (shdP_zkPad Lq hL20) (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₂ c₂) H v i := by
  -- Note: `ptsOf pad p H v i = (p.ptAt H vf 0 i.val).getD (pad i.val (v i))`!
  -- So it suffices to prove `p₁.ptAt H vf 0 i.val = p₂.ptAt H vf 0 i.val`!
  suffices hpt : (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₁ c₁).ptAt H (shdExtV v) 0 i.val
      = (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₂ c₂).ptAt H (shdExtV v) 0 i.val by
    unfold PProg.ptsOf
    rw [show extend v = shdExtV v from rfl, hpt]
  let vf := shdExtV v
  have hVisIdx : ∀ tid (r : Fin (2 ^ shdTreeDepthOf tid)), i.val = shdTreeBase tid + r.val → r.val ∈ shdOpenedCols v tid := by
    intro tid r hr
    have hlt : shdTreeBase tid + r.val < shdP_zkResPts := hr ▸ i.isLt
    have hiEq : i = ⟨shdTreeBase tid + r.val, hlt⟩ := Fin.ext hr
    rw [hiEq] at hvis
    unfold shdIsVisibleAt at hvis
    rw [hLeafSched tid r hlt] at hvis
    exact hvis
  -- Active runs for both `(x₁, c₁)` and `(x₂, c₂)`
  have ha1 := not_shdRunRefused_active (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₁ c₁ v hng
  have ha2 := not_shdRunRefused_active (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₂ c₂ v hng
  -- `H`-independence of `.res` for all three segment programs via O(1) `PProgResIndepH`!
  have hIncH : ∀ (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) (H' : QB Lq → Dig),
      (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res H' vf 4104
      = (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩).res (fun _ => default) vf 4104 :=
    fun x c H' => incSegFixedProg_resIndepH Lq hL20 tag key Rp embDigest bInRow x.1 c _ _ _ _ H' (fun _ => default) vf 4104
  have hBlkNoH : ∀ (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
      (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26) (act : Bool) (cr : Carry) (trB : MerkleLevels 16) (bnd st : Dig) (t' : Tr) (base : ℕ),
      (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x.1 x.2 c startIdx count hEnd act cr trB bnd st t').res H vf base
      = (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x.1 x.2 c startIdx count hEnd act cr trB bnd st t').res (fun _ => default) vf base :=
    fun x c startIdx count hEnd act cr trB bnd st t' base =>
      blkChainFixedProg_resIndepH Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x.1 x.2 c startIdx count hEnd act cr trB bnd st t' H (fun _ => default) vf base
  have hOutNoH : ∀ (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins)
      (act : Bool) (cr : Carry) (trB26 : MerkleLevels 16) (bnd st : Dig) (t' : Tr) (base : ℕ),
      (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x.1 x.2 c act cr trB26 bnd st t').res H vf base
      = (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x.1 x.2 c act cr trB26 bnd st t').res (fun _ => default) vf base :=
    fun x c act cr trB26 bnd st t' base =>
      outcSegFixedProg_resIndepH Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x.1 x.2 c act cr trB26 bnd st t' H (fun _ => default) vf base
  -- Extract active segment outputs from `hOutEq` via O(1) `shdRunOutOf_active_eq`!
  rw [shdP_runFixedProg_outOf_eq, shdP_runFixedProg_outOf_eq] at hOutEq
  unfold shdRunActive at ha1 ha2
  obtain ⟨incEnc1, incEnc2, cr0_1, cr0_2, trB0_1, trB0_2, tInc1, tInc2,
    blkBs1, blkBs2, cr26_1, cr26_2, trB26_1, trB26_2, tBlk1, tBlk2, eBlk1, eBlk2,
    outEnc1, outEnc2, tOut1, tOut2,
    hInc1, hInc2, hBlk1, hBlk2, hOut1, hOut2, hVerd, hIncBytes, hBlkBytes, hOutBytes⟩ :=
    shdRunOutOf_active_eq hdr refused v _ _ _ _ _ _ _ _ ha1 ha2 hOutEq
  have hIncSh : (trB0_1 = trB0_2 ∧ tInc1 = tInc2)
      ∧ cr0_1.pending.map Exec.Block.ZClaim.parts = cr0_2.pending.map Exec.Block.ZClaim.parts := by
    have h := incSegFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x₁.1 x₂.1 c₁ c₂
      (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩ (fun _ => default) vf 4104
    exact (fun {a b : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr} (hr : SegShapeRel a b)
      (ha : a = (some (incEnc1, cr0_1), trB0_1, tInc1)) (hb : b = (some (incEnc2, cr0_2), trB0_2, tInc2)) => by
      subst ha; subst hb; exact ⟨⟨hr.1, hr.2.1⟩, hr.2.2⟩) h hInc1 hInc2
  obtain ⟨⟨htrB0Eq, htIncEq⟩, hCr0Parts⟩ := hIncSh
  subst htrB0Eq htIncEq
  have hBlkSh : (trB26_1, tBlk1, eBlk1) = (trB26_2, tBlk2, eBlk2)
      ∧ cr26_1.pending.map Exec.Block.ZClaim.parts = cr26_2.pending.map Exec.Block.ZClaim.parts := by
    have h := blkChainFixedProg_shape_indep (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x₁.1 x₂.1 x₁.2 x₂.2 c₁ c₂ (fun _ => default) vf 0 26 (by omega) true cr0_1 cr0_2 trB0_1 (vf 4101) (posTagOfV vf (4104 + incSegFixedLen)) tInc1 (4104 + incSegFixedLen + 2) hCr0Parts
    exact (fun {a b : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig} (hr : ChainShapeRel a b)
      (ha : a = (some (blkBs1, cr26_1), trB26_1, tBlk1, eBlk1)) (hb : b = (some (blkBs2, cr26_2), trB26_2, tBlk2, eBlk2)) => by
      subst ha; subst hb; exact hr) h hBlk1 hBlk2
  obtain ⟨hBlkTrEq, hCr26Parts⟩ := hBlkSh
  have htrB26Eq : trB26_1 = trB26_2 := congrArg Prod.fst hBlkTrEq
  have htBlkEq : tBlk1 = tBlk2 := congrArg (fun p => p.2.1) hBlkTrEq
  have heBlkEq : eBlk1 = eBlk2 := congrArg (fun p => p.2.2) hBlkTrEq
  subst htrB26Eq htBlkEq heBlkEq
  have htOutEq : tOut1 = tOut2 := by
    have h := outcSegFixedProg_shape_indep Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x₁.1 x₂.1 x₁.2 x₂.2 c₁ c₂ true cr26_1 cr26_2 hCr26Parts trB26_1 (vf 4101) eBlk1 tBlk1 (fun _ => default) vf
      (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26)
    exact (fun {a b : Option (Dig → List UInt8) × Tr} (hr : OutcShapeRel a b)
      (ha : a = (some outEnc1, tOut1)) (hb : b = (some outEnc2, tOut2)) => by
      subst ha; subst hb; exact hr.1) h hOut1 hOut2
  subst htOutEq; subst hBlkBytes
  have hPosB0 : 4104 + incSegFixedLen + 2 = 209507 + blkStepFixedLen * 0 := by unfold incSegFixedLen; norm_num
  have hB26 : 4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 = 209507 + blkStepFixedLen * 26 := by unfold incSegFixedLen; omega
  -- Transport `.res (fun _ => default)` to `.res H`!
  have hInc1H := (hIncH x₁ c₁ H).trans hInc1
  have hInc2H := (hIncH x₂ c₂ H).trans hInc2
  have hBlk1H := (hBlkNoH x₁ c₁ 0 26 (by omega) true cr0_1 trB0_1 (vf 4101) (posTagOfV vf (4104 + incSegFixedLen)) tInc1 (4104 + incSegFixedLen + 2)).trans hBlk1
  have hBlk2H := (hBlkNoH x₂ c₂ 0 26 (by omega) true cr0_2 trB0_1 (vf 4101) (posTagOfV vf (4104 + incSegFixedLen)) tInc1 (4104 + incSegFixedLen + 2)).trans hBlk2
  have hOut1H := (hOutNoH x₁ c₁ true cr26_1 trB26_1 (vf 4101) eBlk1 tBlk1 (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26)).trans hOut1
  have hOut2H := (hOutNoH x₂ c₂ true cr26_2 trB26_1 (vf 4101) eBlk1 tBlk1 (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26)).trans hOut2
  -- Pass 1: wire decode across IN-C, 26 blocks, and OUT-C!
  have hIncDec := incSegFixedProg_decode_ptAt_eq (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow
    x₁.1 x₂.1 c₁ c₂ (levelsOfV vf 11 0) (vf 4101) (posTagOfV vf 4102) ⟨vf 4101, 0, key⟩ H v
    (posTagOfV vf (4104 + incSegFixedLen)) incEnc1 incEnc2 cr0_1 cr0_2 trB0_1 trB0_1 tInc1 tInc1
    hInc1H hInc2H hIncBytes
  have hBlkDec := blkChainFixedProg_decode_ptAt_eq (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
    x₁.1 x₂.1 x₁.2 x₂.2 c₁ c₂ H v 0 26 (by omega) cr0_1 cr0_2 trB0_1 (vf 4101) (posTagOfV vf (4104 + incSegFixedLen)) tInc1
    blkBs1 cr26_1 cr26_2 trB26_1 trB26_1 tBlk1 tBlk1 eBlk1 eBlk1
    (by rw [← hPosB0]; exact hBlk1H) (by rw [← hPosB0]; exact hBlk2H)
  have hOutDec := outcSegFixedProg_decode_ptAt_eq Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
    x₁.1 x₂.1 x₁.2 x₂.2 hVerd c₁ c₂ cr26_1 cr26_2 trB26_1 (vf 4101) eBlk1 tBlk1 H v
    (posTagOfV vf (4104 + incSegFixedLen + 2 + blkStepFixedLen * 26 + outcSegFixedLen))
    outEnc1 outEnc2 tOut1 tOut1 (by rw [← hB26]; exact hOut1H) (by rw [← hB26]; exact hOut2H) hOutBytes
  -- Pass 2: compare `shdP_runFixedProg.ptAt` at `i.val`!
  have ptAt_andThen_step_res : ∀ {α β : Type} {p₁ p₂ : PProg (QB Lq) Dig α} {k₁ k₂ : α → PProg (QB Lq) Dig β}
      {n base j : ℕ} {a₁ a₂ : α},
      p₁.PtLen n → p₂.PtLen n → p₁.res H vf base = a₁ → p₂.res H vf base = a₂ →
      (j < base + n → p₁.ptAt H vf base j = p₂.ptAt H vf base j) →
      (base + n ≤ j → (k₁ a₁).ptAt H vf (base + n) j = (k₂ a₂).ptAt H vf (base + n) j) →
      (p₁.andThen k₁).ptAt H vf base j = (p₂.andThen k₂).ptAt H vf base j := by
    intro α β p₁ p₂ k₁ k₂ n base j a₁ a₂ hp₁ hp₂ hr₁ hr₂ hleft hright
    by_cases h : j < base + n
    · rw [PProg.ptAt_andThen_left H vf p₁ k₁ n base j hp₁ h, PProg.ptAt_andThen_left H vf p₂ k₂ n base j hp₂ h]
      exact hleft h
    · have hge : base + n ≤ j := Nat.le_of_not_lt h
      rw [PProg.ptAt_andThen_right H vf p₁ k₁ n base j hp₁ hge, PProg.ptAt_andThen_right H vf p₂ k₂ n base j hp₂ hge, hr₁, hr₂]
      exact hright hge
  unfold shdP_runFixedProg
  refine ptAt_andThen_same (merkleTableProg_ptLen Lq (by omega) tag 11 6 (by omega) _ _) (merkleTableProg_ptLen Lq (by omega) tag 11 6 (by omega) _ _) (merkleTableProg_res ..) (merkleTableProg_res ..)
    (fun _ => merkleTableProg_ptAt_eq Lq (by omega) tag 11 6 (by omega) _ _ _ _ H vf 0 i.val fun r hr =>
      hIncDec.1 r.val (hVisIdx .te r hr)) fun _ => ?_
  dsimp only
  refine ptAt_andThen_same (shdP_hdrPProgF_ptLen Lq hL20 key (hw hdr) hfit _ _) (shdP_hdrPProgF_ptLen Lq hL20 key (hw hdr) hfit _ _) (shdP_hdrPProgF_res ..) (shdP_hdrPProgF_res ..)
    (fun _ => by rw [hVerd]) fun _ => ?_
  dsimp only
  refine ptAt_andThen_self (posTagKeyed_ptLen Lq (by omega) key _) (posTagKeyed_res ..) fun _ => ?_
  have hBase4104 : 0 + (2 ^ 11 + (2 ^ 11 - 1)) + 7 + 2 = 4104 := by norm_num
  rw [hBase4104]
  refine ptAt_andThen_step_res (incSegFixedProg_ptLen Lq hL20 tag key Rp embDigest bInRow x₁.1 c₁ _ _ _ _)
    (incSegFixedProg_ptLen Lq hL20 tag key Rp embDigest bInRow x₂.1 c₂ _ _ _ _) hInc1H hInc2H
    (fun _ => hIncDec.2 i.val hVisIdx (hBlkDec.1 ⟨0, by decide⟩ le_rfl (by decide))) fun _ => ?_
  dsimp only [Option.isSome_some]
  refine ptAt_andThen_self (posTagKeyed_ptLen Lq (by omega) key tInc1) (posTagKeyed_res ..) fun _ => ?_
  refine ptAt_andThen_step_res (blkChainFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₁.1 x₁.2 c₁ 0 26 (by omega) true cr0_1 trB0_1 _ _ tInc1)
    (blkChainFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig x₂.1 x₂.2 c₂ 0 26 (by omega) true cr0_2 trB0_1 _ _ tInc1) hBlk1H hBlk2H
    (fun _ => by rw [hPosB0]; exact hBlkDec.2 i.val hVisIdx hOutDec.1) fun _ => ?_
  dsimp only [Option.isSome_some]
  refine ptAt_andThen_step_res (outcSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x₁.1 x₁.2 c₁ true cr26_1 trB26_1 _ eBlk1 tBlk1)
    (outcSegFixedProg_ptLen Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow x₂.1 x₂.2 c₂ true cr26_2 trB26_1 _ eBlk1 tBlk1) hOut1H hOut2H
    (fun _ => by rw [hB26]; exact hOutDec.2 i.val hVisIdx) fun _ => ?_
  dsimp only
  refine ptAt_andThen_self (posTagKeyed_ptLen Lq (by omega) key tOut1) (posTagKeyed_res ..) fun _ => ?_
  rfl

open Classical in
/-- **Full-run `ShdRunVisSpec`** for `shdP_runFixedProg` (using `Classical.choose` on the functional
visibility theorem `shdP_runFixedProg_ptsOf_eq`). -/
noncomputable def shdP_runVisSpec {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (sched : Fin shdP_zkResPts → ShdPtSpec Lq)
    (hLeafSched : ∀ (tid : ShdTreeId) (r : Fin (2 ^ shdTreeDepthOf tid))
      (hlt : shdTreeBase tid + r.val < shdP_zkResPts),
      sched ⟨shdTreeBase tid + r.val, hlt⟩ = .leaf ⟨tid, r⟩) :
    ShdRunVisSpec Lq hL20
      (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig) refused where
  G := shdRunRefused (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub houtPub ioIn ioOut embDigest bInRow wDigest bOutRow blkDig
  isVisibleAt := shdIsVisibleAt sched
  vp := fun o H v i =>
    if h : ∃ p : {x // (classifyModelP Rp).admissible x} × ShdCoins,
        PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig p.1 p.2) v = o then
      let p := Classical.choose h
      PProg.ptsOf (shdP_zkPad Lq hL20) (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig p.1 p.2) H v i
    else shdP_zkPad Lq hL20 i.val (v i)
  hvis_ok := fun x c H v i hng hvis => by
    have hex : ∃ p : {x // (classifyModelP Rp).admissible x} × ShdCoins,
        PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig p.1 p.2) v
        = PProg.outOf (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c) v := ⟨(x, c), rfl⟩
    rw [dite_eq_left hex]
    exact shdP_runFixedProg_ptsOf_eq Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig sched hLeafSched x (Classical.choose hex).1 c (Classical.choose hex).2
      H v i hng hvis (Classical.choose_spec hex).symm
  href := fun x c v hg =>
    shdRunRefused_href Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c v hg

open Classical in
/-- **MASTER `ShdZKCountWitness` FOR `shdP_honestRunP_zk` (`shdP_zkCountWitness`)**:
discharges ALL 24 fields of `HonestShieldZK.ShdZKCountWitness` for the concrete 28-segment
Shieldstral T128 R13 honest prover (`shdP_honestRunP_zk`), using `shdP_runFixedProg`! -/
noncomputable def shdP_zkCountWitness {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (hsep : KeySep tag key)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hV131072 : Rp.inp.V = 131072)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (preA preB : Hdr → Except String Unit)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (bndCheckV : ClsStmt Hdr → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (hdig : ∀ r v (k : Fin 26), digest (honestStmt hdr r v) k.val = blkDig k) :
    ShdZKCountWitness Rp Lq hL20 tag key shdP_runDomain (hw hdr).shape
      (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
        (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp) check0 paths digest bndCheckV)
      (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
        (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow check0 digest
        shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf)
      (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag shdEpBase).base :=
  if hne : Nonempty {x // (classifyModelP Rp).admissible x} then
    let x₀ := Classical.choice hne
    let c₀ : ShdCoins := default
    let hSlice := fun x c => shdP_runFixedSliceSpec hL20 hsep Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c
    let rawSched := shdP_runFixedSched tag Rp ioIn ioOut embDigest bInRow wDigest bOutRow
    let sched := finishSched Lq rawSched
      (fun j L R hj hs => let hb := (hSlice x₀ c₀).hnode_bounds j L R (Nat.zero_le _) (by omega) hs; ⟨hb.2.1, hb.2.2⟩)
      (fun j hj htr => (hSlice x₀ c₀).htr_lt j (Nat.zero_le _) (by omega) htr)
    have hLeafSched : ∀ (tid : ShdTreeId) (r : Fin (2 ^ shdTreeDepthOf tid))
        (hlt : shdTreeBase tid + r.val < shdP_zkResPts),
        sched ⟨shdTreeBase tid + r.val, hlt⟩ = .leaf ⟨tid, r⟩ := fun tid r hlt => by
      have hltPts : shdTreeBase tid + r.val < shdP_zkPts := by
        rw [shdP_zkProg_counts.2.2.2.2.2.2.1]
        have hr := r.isLt
        cases tid with
        | te => unfold shdTreeBase; unfold shdTreeDepthOf at hr; dsimp only at hr ⊢; omega
        | bnd k =>
          unfold shdTreeBase; unfold shdTreeDepthOf at hr; dsimp only at hr ⊢
          split_ifs at hr ⊢ <;> (have := k.isLt; (try unfold blkStepFixedLen blkSegFixedLen); omega)
        | a s =>
          unfold shdTreeBase; unfold shdTreeDepthOf shdAHDepth at hr; dsimp only at hr ⊢
          split_ifs at hr ⊢ <;> (have := s.isLt; (try unfold blkStepFixedLen blkSegFixedLen); omega)
        | m s =>
          unfold shdTreeBase; unfold shdTreeDepthOf at hr; dsimp only at hr ⊢
          split_ifs at hr ⊢ <;> (have := s.isLt; (try unfold blkStepFixedLen blkSegFixedLen); omega)
        | h s =>
          unfold shdTreeBase; unfold shdTreeDepthOf shdAHDepth at hr; dsimp only at hr ⊢
          split_ifs at hr ⊢ <;> (have := s.isLt; (try unfold blkStepFixedLen blkSegFixedLen); omega)
      unfold sched finishSched
      rw [dite_eq_left hltPts]
      have hraw := shdP_runFixedSched_leaf_at tag Rp ioIn ioOut embDigest bInRow wDigest bOutRow tid r
      split <;> rename_i hs <;> (dsimp only [rawSched] at hs; rw [hraw] at hs; try cases hs)
      rfl
    let visSpec := shdP_runVisSpec Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig sched hLeafSched
    have hdom35 : shdP_runDomain.length ≠ 35 := by decide
    have hdom37 : shdP_runDomain.length ≠ 37 := by decide
    shdZKCountWitness_of_schedule Rp Lq hL20 tag key shdP_runDomain (hw hdr).shape hsep hdom35 hdom37
      _ _ (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
      (shdP_honestIn (Hdr := Hdr) tag shdEpBase).base
      (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig)
      (shdP_runFixedProg_run Lq hL20 tag key Rp hR hV131072 hweights hinPub houtPub hw preA preB
        check0 paths digest bndCheckV hdr hfit refused ioIn ioOut embDigest bInRow wDigest bOutRow blkDig hdig)
      (fun x c => (hSlice x c).hptLen.toPtLE)
      (fun x c => (hSlice x c).hdepStrict.toDepAbsorbed)
      (fun x c => (hSlice x c).hqLE)
      (fun x c => (hSlice x c).hdepIn)
      visSpec
      (fun x c => (hSlice x c).hkCount)
      sched
      (shdP_runScheduleMatch hL20 hsep Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x₀ c₀)
      (fun v hng i hnv => by
        have hni : ¬ shdIsVisibleAt sched v i := fun hv => hnv ⟨hng, hv⟩
        unfold shdIsVisibleAt at hni
        cases hsi : sched i with
        | leaf id => exact ⟨id, rfl⟩
        | node _ _ _ => rw [hsi] at hni; exact absurd trivial hni
        | tr _ _ _ => rw [hsi] at hni; exact absurd trivial hni)
      (fun x v hng i id hnv hsi c d => by
        have hni : ¬ shdIsVisibleAt sched v i := fun hv => hnv ⟨hng, hv⟩
        unfold shdIsVisibleAt at hni; rw [hsi] at hni
        exact shdP_runFixedProg_setLeaf_outOf Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
          ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c id d v hni)
  else
    { prog := fun x _ => absurd ⟨x⟩ hne
      hprog := fun _ x _ => absurd ⟨x⟩ hne
      hk := fun x _ => absurd ⟨x⟩ hne
      habs := fun x _ => absurd ⟨x⟩ hne
      hq := fun x _ => absurd ⟨x⟩ hne
      hdep := fun x _ => absurd ⟨x⟩ hne
      h512 := shdCoins_h512
      visSpec :=
        { G := fun _ => True
          isVisibleAt := fun _ _ => False
          vp := fun _ _ v i => shdP_zkPad Lq hL20 i.val (v i)
          hvis_ok := fun x _ _ _ _ _ _ => absurd ⟨x⟩ hne
          href := fun x _ _ _ => absurd ⟨x⟩ hne }
      hkCount := fun x _ => absurd ⟨x⟩ hne
      kOf := fun x _ _ => absurd ⟨x⟩ hne
      hkind := fun x _ _ _ => absurd ⟨x⟩ hne
      hcntT := fun x _ => absurd ⟨x⟩ hne
      hcntL := fun x _ => absurd ⟨x⟩ hne
      hcntN := fun x _ => absurd ⟨x⟩ hne
      hcntD := fun x _ => absurd ⟨x⟩ hne
      hfreshT := fun x _ _ _ _ => absurd ⟨x⟩ hne
      hfreshL := fun x _ _ _ _ => absurd ⟨x⟩ hne
      hfreshN := fun x _ _ _ _ => absurd ⟨x⟩ hne
      hpairs := fun x _ _ _ _ => absurd ⟨x⟩ hne
      hdeps := fun x _ _ => absurd ⟨x⟩ hne
      hleaf_hid := fun x _ _ _ _ _ _ => absurd ⟨x⟩ hne
      hhid_card := fun _ hng => absurd trivial hng
      hcond_hid := fun x _ _ _ _ _ _ _ => absurd ⟨x⟩ hne }

end VisibilityAndCountWitness

end ZK60.HonestShield
