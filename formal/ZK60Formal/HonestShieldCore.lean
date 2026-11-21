/-
D63 lane L68c, shared core infrastructure (`HonestShieldCore.lean`):
self-contained, zero-`sorry` bridges shared by Shieldstral T128 R13 stage completeness
(`HonestShieldStages.lean`) and 26-layer block completeness (`HonestShieldBlock.lean`),
with zero edits to upstream L25/L29/L32 files.

What this file proves (only at most `propext`, `Classical.choice`, `Quot.sound`):
1. **Bounded slot-loop & block completeness (`L68b-3` fix without upstream edits):**
   `stSlotsLoop_of_prove_bd`, `slotsLoop_of_prove_bd`, `blockVerify_of_prove_bd` (replacing
   L25/L29's vacuous unbounded `∀ s, 1 ≤ slotD P s` with `∀ j < m, 1 ≤ slotD P (s + j) ∧ ...`).
2. **Universal wire-encoding length lemmas:**
   `encFp2s_length`, `encColumn_length`, `encHiding_length`, `encMask_length`,
   `encSlot_length`, `encSlots_length`, `encCore_length`, `encSeg_length`, `encStage_length`
   (discharges the byte-length clause of `decodeSegment` and `decodeStage` from `CoreShape` / `HidingShape`).
3. **Opening group-count bridge (`checkOpeningExec` → `groupZclaims`):**
   `auditClaims_parts_nonempty`, `partKeyAt_eq_zpartKey`, `openingGroupsAt_length_eq_groupZclaims`,
   `groupZclaims_length_of_checkOpeningExec`, `groupZclaims_length_singleton`.
4. **Slot proof shape & canonicity extraction:**
   `slotProve_shape_canon`, `stSlotsProve_shape_canon`, `slotsProve_shape_canon`.
5. **Generic honest PCS `Table` builder (`mkPcsTable`) & concrete Shieldstral input-endpoint table (`shdP_epTable`):**
   `mkPcsTable_cols_canon`, `mkPcsTable_cols_length`, `mkPcsTable_colsHonest`,
   `shdP_epTable_rows_length`, `shdP_epTable_cols_length`, `shdP_epTable_cols_canon`,
   `shdP_epTable_root`, `shdP_epTable_colsHonest`.
-/
import ZK60Formal.HonestRunStageIn
import ZK60Formal.HonestRunStageOut
import ZK60Formal.RunShieldBlkInst
import ZK60Formal.RunCoverStage

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (Core SlotProof Column Dim Geom BlockParams Hist SlotRec Acc SlotDef
  Segment SegGeom slotsLoop slotStep histOf absorbRoot pathsDepth labA labH labM posTag
  CoreCanon CoreShape HidingCanon HidingShape MaskCanon SlotCanon Cm
  encSeg encCore encHiding encMask encSlot encColumn encFp2s encOpt slotShape slotTerms slotLen)

/-! ## 1. Bounded slot-loop & block completeness (resolves `L68b-3` with zero upstream edits) -/

section BoundedLoops

variable (H : HIn → Dig) (P : BlockParams) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- Bounded stage slot-loop completeness (`stSlotsLoop_of_prove` with `j < m` degree bound). -/
theorem stSlotsLoop_of_prove_bd (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof)
      (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      (∀ j, j < m → 1 ≤ slotD P (s + j) ∧ slotD P (s + j) < gP) →
      StSlotsSum H P elog U D b g a m recs s acc t →
      stSlotsProve H P elog D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      stSlotsLoop H P elog b g a recs s sps acc t = .ok (recs', acc', t')
  | 0, recs, s, acc, t, sps, recs', acc', t', _, _, h => by
    simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, rfl, rfl⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hdeg, hS, h => by
    obtain ⟨hs1, hs2⟩ := hS
    simp only [stSlotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl, rfl⟩ := h
        have hd0 := hdeg 0 (Nat.zero_lt_succ m)
        rw [Nat.add_zero] at hd0
        have hstep := slotStep_of_prove H (atLog P (elog s)) U hU (sdAt D (elog s)) s
          (histOf b g a recs) acc t sp r acc₁ t₁ hd0.1 hd0.2 hs1 hsp
        simp only [stSlotsLoop, hstep]
        exact stSlotsLoop_of_prove_bd elog D b g a m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (fun j hj => by
            have h' := hdeg (j + 1) (by omega)
            rwa [show s + (j + 1) = s + 1 + j by omega] at h')
          (hs2 sp r acc₁ t₁ hsp) hrest

/-- Bounded block/OUT-C slot-loop completeness (`slotsLoop_of_prove` with `j < m` degree bound). -/
theorem slotsLoop_of_prove_bd (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof)
      (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      (∀ j, j < m → 1 ≤ slotD P (s + j) ∧ slotD P (s + j) < gP) →
      SlotsSum H P U D b g a m recs s acc t →
      slotsProve H P D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      slotsLoop H P b g a recs s sps acc t = .ok (recs', acc', t')
  | 0, recs, s, acc, t, sps, recs', acc', t', _, _, h => by
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, rfl, rfl⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hdeg, hS, h => by
    obtain ⟨hs1, hs2⟩ := hS
    simp only [slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl, rfl⟩ := h
        have hd0 := hdeg 0 (Nat.zero_lt_succ m)
        rw [Nat.add_zero] at hd0
        have hstep := slotStep_of_prove H P U hU D s (histOf b g a recs) acc t sp r acc₁ t₁
          hd0.1 hd0.2 hs1 hsp
        simp only [slotsLoop, hstep]
        exact slotsLoop_of_prove_bd D b g a m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (fun j hj => by
            have h' := hdeg (j + 1) (by omega)
            rwa [show s + (j + 1) = s + 1 + j by omega] at h')
          (hs2 sp r acc₁ t₁ hsp) hrest

/-- Bounded block core completeness (`blockVerify_of_prove` with `s < P.geom.slots.length` degree bound). -/
theorem blockVerify_of_prove_bd (D : CoreData P) (t : Tr) (R : CoreRun) (h : coreProve H P D t = .ok R)
    (hdeg : ∀ s, s < P.geom.slots.length → 1 ≤ slotD P s ∧ slotD P s < gP)
    (hpre : P.preChecks = .ok ())
    (hpA : pathsDepth "A" P.aPath 0 R.core.aOpen.columns = .ok ())
    (hpH : pathsDepth "H" P.hPath 0 R.core.hOpen.columns = .ok ())
    (hpM : pathsDepth "M" P.maskPath 0 R.core.maskOpen.columns = .ok ())
    (hslots : SlotsSum H P U D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
      P.geom.slots.length [] 0 {} (coreT3 H P D t))
    (hM : P.maskVerify H D.maskRoot (R.acc.fs ++ R.acc.hostFs) R.core.maskOpen R.t4 = .ok R.t5)
    (hA : P.pcsVerify H .a D.aRoot R.acc.claims.a R.core.aOpen R.t5 = .ok R.t6)
    (hH : P.pcsVerify H .h R.core.hRoot (R.acc.claims.h ++ [P.logupSumClaim]) R.core.hOpen R.t6 = .ok R.t7) :
    Exec.Block.blockVerify H P R.core t = .ok ((R.acc.claims.inp, R.acc.claims.out), R.t7) := by
  obtain ⟨hs, hfs, hcA, hcH, haR, hmR, hhR, -, -, -, -⟩ := coreProve_ok H P D t R h
  have hloop := slotsLoop_of_prove_bd H P U hU D.slot _ _ _ _ _ _ _ _ _ _ _ _
    (fun j hj => by simpa using hdeg j hj) hslots hs
  rcases R with ⟨⟨aR, hR, mR, sl, mo, ao, ho⟩, bga, recs, acc, t3, t4, t5, t6, t7⟩
  have haR' : aR = D.aRoot := haR
  have hmR' : mR = D.maskRoot := hmR
  have hhR' : hR = D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1 := hhR
  subst haR' hmR' hhR'
  have hM' : P.maskVerify H D.maskRoot (acc.fs ++ acc.hostFs) mo t4 = .ok t5 := hM
  have hA' : P.pcsVerify H .a D.aRoot acc.claims.a ao t5 = .ok t6 := hA
  have hH' : P.pcsVerify H .h (D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1)
      (acc.claims.h ++ [P.logupSumClaim]) ho t6 = .ok t7 := hH
  have hcA' : P.checkOpening H .a acc.claims.a t5 = .ok () := hcA
  have hcH' : P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim]) t6 = .ok () := hcH
  have hfs' : (acc.fs ++ acc.hostFs).length = P.nFunctionals := hfs
  have hbs : Exec.Block.blockSlots H P ⟨D.aRoot, D.hRoot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1,
      D.maskRoot, sl, mo, ao, ho⟩ t = .ok (((coreB H P D t).1, (coreG H P D t).1, (coreA H P D t).1), recs, acc, t4) :=
    congrArg (fun z : Except String (List SlotRec × Acc × Tr) => match z with
      | .ok r => (.ok (((coreB H P D t).1, (coreG H P D t).1, (coreA H P D t).1), r) :
          Except String ((Fp2 × Fp2 × Fp2) × List SlotRec × Acc × Tr))
      | .error e => .error e) hloop
  unfold Exec.Block.blockVerify
  refine bind_ok_of hpre ?_
  refine bind_ok_of hpA ?_
  refine bind_ok_of hpH ?_
  refine bind_ok_of hpM ?_
  refine bind_ok_of hbs ?_
  dsimp only
  simp only [hfs', ne_eq, not_true_eq_false, ↓reduceIte, pure_bind]
  simp only [hM']
  refine bind_ok_of hcA' ?_
  simp only [hA']
  refine bind_ok_of hcH' ?_
  simp only [hH']
  all_goals rfl

end BoundedLoops

/-! ## 2. Universal wire-encoding length lemmas -/

section WireLengths

private theorem length_flatMap_const {α β : Type} (f : α → List β) (k : ℕ) :
    ∀ (l : List α), (∀ a ∈ l, (f a).length = k) → (l.flatMap f).length = l.length * k
  | [], _ => by simp
  | a :: l, h => by
    have ha := h a List.mem_cons_self
    have ih := length_flatMap_const f k l (fun x hx => h x (List.mem_cons_of_mem _ hx))
    simp only [List.flatMap_cons, List.length_append, List.length_cons, ha, ih]
    ring

theorem encFp2s_length (v : List Fp2) : (encFp2s v).length = v.length * 16 :=
  length_flatMap_const Fp2.toBytes 16 v (fun a _ => Exec.Block.fp2_toBytes_length a)

theorem encColumn_length (c : Column) (rows path : ℕ) (hr : c.col.length = rows) (hp : c.path.length = path) :
    (encColumn c).length = 8 + rows * 8 + 32 + path * 32 := by
  have h1 : (c.col.flatMap Fp.toBytes).length = rows * 8 := by
    rw [← hr]
    exact length_flatMap_const Fp.toBytes 8 c.col (fun a _ => by simp [Fp.toBytes, le64_length])
  have h2 : (c.path.flatMap (fun d : Dig => d.toList)).length = path * 32 := by
    rw [← hp]
    exact length_flatMap_const (fun d : Dig => d.toList) 32 c.path (fun d _ => by simp)
  simp only [encColumn, List.length_append, le64_length, List.Vector.toList_length, h1, h2]
  ring

theorem encHiding_length (d : Dim) (groups rows : ℕ) (o : Exec.Block.OpeningZk) (h : HidingShape d groups rows o) :
    (encHiding o).length = d.openingLen groups rows := by
  obtain ⟨hg, hgv, hpv, hcl, hcols⟩ := h
  have h1 : (o.groupVecs.flatMap encFp2s).length = groups * (d.vec * 16) := by
    rw [← hg]
    exact length_flatMap_const encFp2s (d.vec * 16) o.groupVecs (fun v hv => by rw [encFp2s_length, hgv v hv])
  have h2 : (encFp2s o.proxVec).length = d.vec * 16 := by rw [encFp2s_length, hpv]
  have h3 : (o.columns.flatMap encColumn).length = d.checks * (8 + rows * 8 + 32 + d.path * 32) := by
    rw [← hcl]
    exact length_flatMap_const encColumn _ o.columns (fun c hc =>
      encColumn_length c rows d.path (hcols c hc).2.1 (hcols c hc).2.2)
  simp only [encHiding, Dim.openingLen, List.length_append, h1, h2, h3]
  ring

theorem encMask_length (g : Geom) (m : Exec.Block.MaskOpening) (hq : m.q.length = g.maskVec) (hp : m.prox.length = g.maskVec)
    (hc : m.columns.length = g.maskChecks)
    (hcols : ∀ col ∈ m.columns, col.j < g.maskDom ∧ col.col.length = g.mRows ∧ col.path.length = g.maskPath) :
    (encMask m).length = g.maskLen := by
  have h1 : (encFp2s m.q).length = g.maskVec * 16 := by rw [encFp2s_length, hq]
  have h2 : (encFp2s m.prox).length = g.maskVec * 16 := by rw [encFp2s_length, hp]
  have h3 : (m.columns.flatMap encColumn).length = g.maskChecks * (8 + g.mRows * 8 + 32 + g.maskPath * 32) := by
    rw [← hc]
    exact length_flatMap_const encColumn _ m.columns (fun col hcol =>
      encColumn_length col g.mRows g.maskPath (hcols col hcol).2.1 (hcols col hcol).2.2)
  simp only [encMask, Geom.maskLen, List.length_append, h1, h2, h3]
  ring

theorem encSlot_length (p : SlotProof) (s : ℕ × ℕ × ℕ) (t : ℕ)
    (hr : p.rounds.length = s.1 + s.2.1) (hrr : ∀ r ∈ p.rounds, r.length = s.2.2 + 1) (ht : p.terms.length = t) :
    (encSlot p).length = slotLen (s, t) := by
  have h1 : (p.rounds.flatMap encFp2s).length = (s.1 + s.2.1) * ((s.2.2 + 1) * 16) := by
    rw [← hr]
    exact length_flatMap_const encFp2s ((s.2.2 + 1) * 16) p.rounds (fun r hr' => by rw [encFp2s_length, hrr r hr'])
  have h2 : (encFp2s p.terms).length = t * 16 := by rw [encFp2s_length, ht]
  simp only [encSlot, slotLen, List.length_append, Exec.Block.fp2_toBytes_length, h1, h2]
  ring

private theorem encSlots_length_aux :
    ∀ (ps : List SlotProof) (ss : List (ℕ × ℕ × ℕ)) (ts : List ℕ),
      ps.length = ss.length → ss.length = ts.length →
      (∀ (i : ℕ) (p : SlotProof) (s : ℕ × ℕ × ℕ) (t : ℕ),
        ps[i]? = some p → ss[i]? = some s → ts[i]? = some t →
        p.rounds.length = s.1 + s.2.1 ∧ (∀ r ∈ p.rounds, r.length = s.2.2 + 1) ∧ p.terms.length = t) →
      (ps.flatMap encSlot).length = ((ss.zip ts).map slotLen).sum
  | [], [], [], _, _, _ => rfl
  | p :: ps, s :: ss, t :: ts, h1, h2, h => by
    have h0 := h 0 p s t rfl rfl rfl
    have ih := encSlots_length_aux ps ss ts (by simpa using h1) (by simpa using h2)
      (fun i p' s' t' hp hs ht => h (i + 1) p' s' t' hp hs ht)
    simp only [List.flatMap_cons, List.length_append, List.zip_cons_cons, List.map_cons, List.sum_cons,
      encSlot_length p s t h0.1 h0.2.1 h0.2.2, ih]
  | [], _ :: _, _, h1, _, _ => by simp at h1
  | _ :: _, [], _, h1, _, _ => by simp at h1
  | _ :: _, _ :: _, [], _, h2, _ => by simp at h2

theorem encSlots_length (g : Geom) (hgt : g.slots.length = g.terms.length) (c : Core) (hsh : CoreShape g c) :
    (c.slots.flatMap encSlot).length = g.slotsLen :=
  encSlots_length_aux c.slots g.slots g.terms hsh.1 hgt hsh.2.1

theorem encCore_length (g : Geom) (hgt : g.slots.length = g.terms.length) (c : Core) (hsh : CoreShape g c) :
    (encCore c).length = 3 * 32 + g.slotsLen + g.maskLen
      + g.blk.openingLen g.aGroups g.aRows + g.blk.openingLen g.hGroups g.hRows := by
  have hsl := encSlots_length g hgt c hsh
  have hm := encMask_length g c.maskOpen hsh.2.2.1 hsh.2.2.2.1 hsh.2.2.2.2.1 hsh.2.2.2.2.2.1
  have ha0 := hsh.2.2.2.2.2.2.1 c.aOpen (by simp)
  have hh0 := hsh.2.2.2.2.2.2.1 c.hOpen (by simp)
  have haS : HidingShape g.blk g.aGroups g.aRows c.aOpen :=
    ⟨hsh.2.2.2.2.2.2.2.1, ha0.2.1, ha0.1, ha0.2.2.1,
      fun col hcol => ⟨(ha0.2.2.2 col hcol).1, hsh.2.2.2.2.2.2.2.2.2.1 col hcol, (ha0.2.2.2 col hcol).2⟩⟩
  have hhS : HidingShape g.blk g.hGroups g.hRows c.hOpen :=
    ⟨hsh.2.2.2.2.2.2.2.2.1, hh0.2.1, hh0.1, hh0.2.2.1,
      fun col hcol => ⟨(hh0.2.2.2 col hcol).1, hsh.2.2.2.2.2.2.2.2.2.2 col hcol, (hh0.2.2.2 col hcol).2⟩⟩
  have ha := encHiding_length g.blk g.aGroups g.aRows c.aOpen haS
  have hh := encHiding_length g.blk g.hGroups g.hRows c.hOpen hhS
  simp only [encCore, List.length_append, List.Vector.toList_length, hsl, hm, ha, hh]
  ring

private theorem encOpt_dig_length (o : Option Dig) (b : Bool) (hb : o.isSome = b) :
    (encOpt (fun d : Dig => d.toList) o).length = if b then 32 else 0 := by
  cases o with
  | none => subst hb; rfl
  | some d => subst hb; simp [encOpt]

private theorem encCloses_length :
    ∀ (cs : List (Dim × ℕ × ℕ)) (os : List Exec.Block.OpeningZk),
      List.Forall₂ CloseOk cs os →
      (os.flatMap encHiding).length = (cs.map (fun c => c.1.openingLen c.2.1 c.2.2)).sum
  | [], [], _ => rfl
  | c :: cs, o :: os, h => by
    obtain ⟨⟨_, hs, _⟩, hrest⟩ := List.forall₂_cons.mp h
    simp only [List.flatMap_cons, List.length_append, List.map_cons, List.sum_cons,
      encHiding_length c.1 c.2.1 c.2.2 o hs, encCloses_length cs os hrest]
  | [], _ :: _, h => by cases h
  | _ :: _, [], h => by cases h

/-- **Universal byte-length theorem for stage segment encodings** (`decodeStage_enc`'s length clause). -/
theorem encStage_length (s : StageGeom) (hgt : s.g.slots.length = s.g.terms.length) (hmag : s.magic.length = 8)
    (bindg startTag : Dig) (sg : StageSeg) (e : Dig)
    (hsh : CoreShape s.g sg.core) (hbr : sg.bRoot.isSome = s.hasB)
    (hcl : List.Forall₂ CloseOk s.closes sg.closes) :
    (encStage s bindg startTag sg e).length = s.len := by
  have hb := encOpt_dig_length sg.bRoot s.hasB hbr
  have hc := encCore_length s.g hgt sg.core hsh
  have hcs := encCloses_length s.closes sg.closes hcl
  simp only [encStage, StageGeom.len, List.length_append, hmag, le64_length, List.Vector.toList_length, hb, hc, hcs]
  ring

/-- **Universal byte-length theorem for block segment encodings** (`decodeSegment`'s length clause, `closes = false`). -/
theorem encSeg_length (s : SegGeom) (hgt : s.g.slots.length = s.g.terms.length)
    (bindg startTag : Dig) (sg : Segment) (e : Dig)
    (hsh : CoreShape s.g sg.core) (hbr : sg.bRoot.isSome = s.commits)
    (his : HidingShape s.ed s.incoming.1 s.incoming.2 sg.inOpen)
    (hcl : s.closes = false) (hoo : sg.outOpen = none) :
    (encSeg bindg s.l s.k startTag sg e).length = s.len := by
  have hb := encOpt_dig_length sg.bRoot s.commits hbr
  have hc := encCore_length s.g hgt sg.core hsh
  have hi := encHiding_length s.ed s.incoming.1 s.incoming.2 sg.inOpen his
  have ho : (encOpt encHiding sg.outOpen).length = 0 := by rw [hoo]; rfl
  simp only [encSeg, SegGeom.len, hcl, List.length_append, Exec.Block.runMagic_length, le64_length,
    List.Vector.toList_length, hb, hc, hi, ho, Bool.false_eq_true, ↓reduceIte]
  ring

end WireLengths

/-! ## 3. Opening group-count bridge (`checkOpeningExec` → `groupZclaims`) -/

section GroupBridge

private theorem claimTouched_nil (n prox : ℕ) (siteRows : List ℕ) (v : Fp2) :
    claimTouched n prox siteRows ⟨[], v⟩ = .ok [] := rfl

private theorem auditOne_parts_nonempty (n rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (nClaims ci : ℕ) (c : Exec.Block.ZClaim) (uses uses' : List ℕ)
    (h : auditOne n rows prox siteRows sumRows nClaims ci c uses = .ok uses') :
    c.parts ≠ [] := by
  intro hemp
  rcases c with ⟨ps, v⟩
  dsimp only at hemp
  subst hemp
  unfold auditOne at h
  simp only [claimTouched_nil, List.all_nil, List.isEmpty_nil, List.any_nil, Bool.not_false,
    Bool.not_true, Bool.false_or, Bool.true_or, Bind.bind, Except.bind, pure, Except.pure,
    auditFail] at h
  cases sumRows with
  | none => cases h
  | some p =>
    rcases p with ⟨u0, u1⟩
    dsimp only at h
    split_ifs at h

private theorem auditLoop_parts_nonempty (n rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (nClaims : ℕ) :
    ∀ (ci : ℕ) (cs : List Exec.Block.ZClaim) (uses uses' : List ℕ),
      auditLoop n rows prox siteRows sumRows nClaims ci cs uses = .ok uses' →
      ∀ c ∈ cs, c.parts ≠ []
  | _, [], _, _, _, _, hc => by cases hc
  | ci, c :: cs, uses, uses', h, c', hc' => by
    unfold auditLoop at h
    cases h1 : auditOne n rows prox siteRows sumRows nClaims ci c uses with
    | error e =>
      simp [h1, Bind.bind, Except.bind] at h
    | ok u =>
      simp only [h1, Bind.bind, Except.bind] at h
      rcases List.mem_cons.mp hc' with hEq | hmem
      · rw [hEq]
        exact auditOne_parts_nonempty n rows prox siteRows sumRows nClaims ci c uses u h1
      · exact auditLoop_parts_nonempty n rows prox siteRows sumRows nClaims (ci + 1) cs u uses' h c' hmem

theorem auditClaims_parts_nonempty (claims : List Exec.Block.ZClaim) (n rows : ℕ) (siteRows : List ℕ)
    (sumRows : Option (ℕ × ℕ)) (prox : ℕ) (h : auditClaims claims n rows siteRows sumRows prox = .ok ()) :
    ∀ c ∈ claims, c.parts ≠ [] := by
  unfold auditClaims at h
  simp only [Bind.bind, Except.bind, pure, Except.pure, auditFail] at h
  split_ifs at h
  cases hl : auditLoop n rows prox siteRows sumRows claims.length 0 claims (List.replicate rows 0) with
  | error e =>
    rw [hl] at h
    cases h
  | ok uses =>
    exact auditLoop_parts_nonempty n rows prox siteRows sumRows claims.length 0 claims _ uses hl

private def toZKey (k : List Fp2 × ℕ × ℕ) : ZKey := ⟨k.1, k.2.1, k.2.2⟩

private theorem toZKey_injective : Function.Injective toZKey := by
  rintro ⟨a1, b1, c1⟩ ⟨a2, b2, c2⟩ h
  simp only [toZKey, ZKey.mk.injEq] at h
  obtain ⟨rfl, rfl, rfl⟩ := h
  rfl

theorem partKeyAt_eq_zpartKey (p : Exec.Block.ZPart) (rows logN : ℕ) :
    (zpartWeights (toZPart p) rows logN).2 = toZKey (partKeyAt p logN) := by
  unfold zpartWeights partKeyAt toZPart toZKey
  dsimp only
  by_cases hemp : p.point.isEmpty = true <;> by_cases hle : logN ≤ p.logSize
  · simp [hemp, hle]
  · simp [hemp, hle]
  · simp [hemp, hle]
  · have hsub : p.logSize - logN = 0 := by omega
    simp [hemp, hle, hsub]

private theorem bumpKey_map_fst (key : List Fp2 × ℕ × ℕ) :
    ∀ (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      (bumpKey key gs).map Prod.fst =
        if key ∈ gs.map Prod.fst then gs.map Prod.fst else gs.map Prod.fst ++ [key]
  | [] => rfl
  | (k, c) :: rest => by
    by_cases heq : k = key
    · subst heq
      simp [bumpKey]
    · have ih := bumpKey_map_fst key rest
      simp only [bumpKey, heq, ↓reduceIte, List.map_cons, List.mem_cons, Ne.symm heq, false_or, ih]
      split_ifs <;> rfl

private theorem pushAt_length {α β : Type} :
    ∀ (l : List (α × List β)) (i : ℕ) (m : β), (pushAt l i m).length = l.length
  | [], _, _ => rfl
  | _ :: _, 0, _ => rfl
  | _ :: l, i + 1, m => by simp [pushAt, pushAt_length l i m]

private theorem keyIdx_isSome_iff (keys : List ZKey) (k : ZKey) :
    (keyIdx keys k).isSome ↔ k ∈ keys := by
  unfold keyIdx
  constructor
  · intro h
    cases hfi : keys.findIdx? (fun k' => decide (k' = k)) with
    | none => rw [hfi] at h; cases h
    | some i =>
      have ⟨hi, hp⟩ := List.findIdx?_eq_some_iff_getElem.mp hfi
      have heq : keys[i] = k := of_decide_eq_true hp.1
      rw [← heq]
      exact List.getElem_mem hi
  · intro h
    rw [List.findIdx?_isSome, List.any_eq_true]
    exact ⟨k, h, decide_eq_true rfl⟩

private theorem openingGroupsAt_foldl_inv (rows logN : ℕ) :
    ∀ (cs : List Exec.Block.ZClaim)
      (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (gs' : List ((List Fp2 × ℕ × ℕ) × ℕ))
      (st : List ZKey × List (List Fp2 × List (List Fp2 × Fp2))),
      (∀ c ∈ cs, c.parts ≠ []) →
      gs.map (fun x => toZKey x.1) = st.1 →
      st.1.length = st.2.length →
      (cs.foldlM (m := Except String) (fun acc c =>
        let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
        if c.parts.any (fun p => partKeyAt p logN ≠ key) then
          throw "private block: claim parts with different column weights"
        else pure (bumpKey key acc)) gs) = Except.ok gs' →
      gs'.length = ((cs.map toZClaim).foldl (groupStep rows logN) st).2.length
  | [], gs, gs', st, _, hmap, hlen, h => by
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h
    have h1 := congrArg List.length hmap
    rw [List.length_map] at h1
    exact h1.trans hlen
  | c :: cs, gs, gs', st, hne, hmap, hlen, h => by
    rw [List.foldlM_cons] at h
    dsimp only at h
    split_ifs at h with hdiff
    · simp [throw, throwThe, MonadExceptOf.throw, Bind.bind, Except.bind] at h
    · simp only [pure, Except.pure, Bind.bind, Except.bind] at h
      have hcne : c.parts ≠ [] := hne c List.mem_cons_self
      cases hp : c.parts with
      | nil => exact absurd hp hcne
      | cons p0 ps =>
        have hw2 : (claimWeights (toZClaim c) rows logN).2 =
            toZKey (partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN) := by
          simp only [claimWeights, toZClaim, hp, List.map_cons, List.headD_cons]
          exact partKeyAt_eq_zpartKey p0 rows logN
        set key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
        have hmem_iff : toZKey key ∈ st.1 ↔ key ∈ gs.map Prod.fst := by
          rw [← hmap]
          constructor
          · intro hm
            obtain ⟨x, hmem, heq⟩ := List.mem_map.mp hm
            exact List.mem_map.mpr ⟨x, hmem, toZKey_injective heq⟩
          · intro hm
            obtain ⟨x, hmem, heq⟩ := List.mem_map.mp hm
            exact List.mem_map.mpr ⟨x, hmem, congrArg toZKey heq⟩
        have hbmap : (bumpKey key gs).map (fun x => toZKey x.1) =
            if key ∈ gs.map Prod.fst then st.1 else st.1 ++ [toZKey key] := by
          have hcomp : (bumpKey key gs).map (fun x => toZKey x.1) =
              ((bumpKey key gs).map Prod.fst).map toZKey := by rw [List.map_map]; rfl
          rw [hcomp, bumpKey_map_fst]
          split_ifs with hm
          · rw [List.map_map]; exact hmap
          · rw [List.map_append, List.map_singleton, List.map_map]; exact congrArg (· ++ [toZKey key]) hmap
        have hstep_eq : (groupStep rows logN st (toZClaim c)).1 = (bumpKey key gs).map (fun x => toZKey x.1)
            ∧ (groupStep rows logN st (toZClaim c)).1.length = (groupStep rows logN st (toZClaim c)).2.length := by
          unfold groupStep
          dsimp only
          rw [hw2]
          cases hki : keyIdx st.1 (toZKey key) with
          | none =>
            have hnot : key ∉ gs.map Prod.fst := by
              intro hm
              have hsome := (keyIdx_isSome_iff st.1 (toZKey key)).mpr (hmem_iff.mpr hm)
              rw [hki] at hsome
              simp at hsome
            rw [hbmap, ite_eq_right hnot]
            exact ⟨rfl, by simp [hlen]⟩
          | some gi =>
            have hhas : key ∈ gs.map Prod.fst :=
              hmem_iff.mp ((keyIdx_isSome_iff st.1 (toZKey key)).mp (by rw [hki]; rfl))
            rw [hbmap, ite_eq_left hhas]
            exact ⟨rfl, by rw [pushAt_length, hlen]⟩
        rw [List.map_cons, List.foldl_cons]
        exact openingGroupsAt_foldl_inv rows logN cs (bumpKey key gs) gs' (groupStep rows logN st (toZClaim c))
          (fun c' hc' => hne c' (List.mem_cons_of_mem _ hc')) hstep_eq.1.symm hstep_eq.2 h

theorem openingGroupsAt_length_eq_groupZclaims (claims : List Exec.Block.ZClaim) (rows logN : ℕ)
    (gs : List ((List Fp2 × ℕ × ℕ) × ℕ)) (hne : ∀ c ∈ claims, c.parts ≠ [])
    (h : openingGroupsAt claims logN = .ok gs) :
    (groupZclaims (claims.map toZClaim) rows logN).length = gs.length :=
  (openingGroupsAt_foldl_inv rows logN claims [] gs ([], []) hne rfl rfl h).symm

/-- **Group-count bridge**: `checkOpeningExec H g logN cl t = .ok ()` implies `(groupZclaims ...).length = g.groups`. -/
theorem groupZclaims_length_of_checkOpeningExec (H : HIn → Dig) (g : OpenGeom) (logN rows : ℕ)
    (cl : List Exec.Block.ZClaim) (t : Tr) (h : checkOpeningExec H g logN cl t = .ok ()) :
    (groupZclaims (cl.map toZClaim) rows logN).length = g.groups := by
  unfold checkOpeningExec at h
  cases ha : auditClaims cl (2 ^ logN) g.rows g.siteRows g.sumRows g.prox with
  | error e => simp [ha, Bind.bind, Except.bind] at h
  | ok u =>
    cases u
    simp only [ha, Bind.bind, Except.bind] at h
    cases hg : openingGroupsAt cl logN with
    | error e => simp [hg] at h
    | ok gs =>
      simp only [hg] at h
      by_cases hne : gs.length ≠ g.groups
      · simp [hne, throw, throwThe, MonadExceptOf.throw] at h
      · have hlen := openingGroupsAt_length_eq_groupZclaims cl rows logN gs
          (auditClaims_parts_nonempty cl (2 ^ logN) g.rows g.siteRows g.sumRows g.prox ha) hg
        omega

/-- Singleton claim list always produces exactly 1 PCS opening group. -/
theorem groupZclaims_length_singleton (c : Exec.Block.ZClaim) (rows logN : ℕ) :
    (groupZclaims ([c].map toZClaim) rows logN).length = 1 := rfl

end GroupBridge

/-! ## 4. Slot proof shape & canonicity extraction -/

section SlotCodec

private theorem slotDefChecks_terms (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef)
    (h : Exec.Block.slotDefChecks P s acc df = .ok ()) :
    (df.tabs.filter Exec.Block.Tab.isPriv).length = slotTerms P s := by
  unfold Exec.Block.slotDefChecks at h
  dsimp only at h
  by_cases h1 : (decide (s ≠ acc.cs.length) || decide ((df.tabs.filter Exec.Block.Tab.isPriv).length ≠ slotTerms P s)
      || (decide (P.kind s = Exec.Block.SlotKind.host) == df.hosted.isEmpty)) = true
  · rw [ite_eq_left h1] at h; cases h
  · simp only [Bool.or_eq_true, decide_eq_true_eq, not_or] at h1
    exact not_not.mp h1.1.2

theorem slotProve_shape_canon (H : HIn → Dig) (P : BlockParams) {K : Type} [Field K] [Algebra GF K] (U : K)
    (D : SlotData P) (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (sp : SlotProof) (r : SlotRec) (acc' : Acc) (t' : Tr)
    (hSc : ∀ df c, (D.scalar s hist acc df c).Canon)
    (hTm : ∀ df c rho, ∀ x ∈ D.terms s hist acc df c rho, x.Canon)
    (hsum : ∀ df, P.define s hist (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
      SlotSum P U D s hist acc df (slotC H P s t))
    (h : slotProve H P D s hist acc t = .ok (sp, r, acc', t')) :
    SlotCanon sp
      ∧ sp.rounds.length = (slotShape P s).1 + (slotShape P s).2.1
      ∧ (∀ rd ∈ sp.rounds, rd.length = (slotShape P s).2.2 + 1)
      ∧ sp.terms.length = slotTerms P s := by
  unfold slotProve at h
  split at h
  · cases h
  · rename_i df hdf
    split_ifs at h with hc hes
    cases hchk : Exec.Block.slotDefChecks P s acc df with
    | error e => simp [hchk] at h
    | ok u =>
      cases hhost : Exec.Block.hostedSum acc.scalars (slotSP H P D s hist acc t df).scalar df.hosted with
      | error e => simp [hchk, hhost] at h
      | ok claimed =>
        cases htab : Exec.Block.tabVals (Exec.Block.oneMinusProd ((slotRho H P D s hist acc t df).drop (slotShape P s).1))
            ((slotRho H P D s hist acc t df).take (slotShape P s).1) (slotSP H P D s hist acc t df).terms df.tabs 0 with
        | error e => simp [hchk, hhost, htab] at h
        | ok vals =>
          simp only [hchk, hhost, htab, Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, -, -, -⟩ := h
          cases u
          obtain ⟨F, -, hW, -, hcnt⟩ := hsum df hdf
          have hrds := whonest_rounds U H (slotD P s) (slotN P s) (D.strat s hist acc df (slotC H P s t)) F
            (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t))) hW
          have hlen := scProve_length H (slotN P s) (D.strat s hist acc df (slotC H P s t))
            (slotT4 H P s t (D.scalar s hist acc df (slotC H P s t)))
          have htlen := (hcnt (slotRho H P D s hist acc t df)).trans (slotDefChecks_terms P s acc df hchk)
          exact ⟨⟨hSc df (slotC H P s t), fun rd hrd => (hrds rd hrd).2, hTm df (slotC H P s t) _⟩,
            hlen, fun rd hrd => (hrds rd hrd).1, htlen⟩

/-- Extract `SlotCanon`, `sps.length = m`, and per-slot `CoreShape` from `stSlotsProve` + `StSlotsSum`. -/
theorem stSlotsProve_shape_canon (H : HIn → Dig) (P : BlockParams) (elog : ℕ → ℕ)
    {K : Type} [Field K] [Algebra GF K] (U : K) (D : SlotData P) (b g a : Fp2)
    (hSc : ∀ s hist acc df c, (D.scalar s hist acc df c).Canon)
    (hTm : ∀ s hist acc df c rho, ∀ x ∈ D.terms s hist acc df c rho, x.Canon) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof)
      (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      StSlotsSum H P elog U D b g a m recs s acc t →
      stSlotsProve H P elog D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      sps.length = m
        ∧ (∀ p ∈ sps, SlotCanon p)
        ∧ ∀ (i : ℕ) (p : SlotProof) (sh : ℕ × ℕ × ℕ) (tm : ℕ),
            sps[i]? = some p → P.geom.slots[s + i]? = some sh → P.geom.terms[s + i]? = some tm →
            p.rounds.length = sh.1 + sh.2.1 ∧ (∀ r ∈ p.rounds, r.length = sh.2.2 + 1) ∧ p.terms.length = tm
  | 0, _, _, _, _, _, _, _, _, _, h => by
    simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -, -, -⟩ := h
    exact ⟨rfl, (fun _ hp => by cases hp), (fun _ _ _ _ hp => by cases hp)⟩
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hS, h => by
    obtain ⟨hs1, hs2⟩ := hS
    simp only [stSlotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl, rfl⟩ := h
        have h0 := slotProve_shape_canon H (atLog P (elog s)) U (sdAt D (elog s)) s (histOf b g a recs) acc t
          sp r acc₁ t₁ (fun df c => hSc s _ _ df c) (fun df c rho => hTm s _ _ df c rho) hs1 hsp
        have ih := stSlotsProve_shape_canon H P elog U D b g a hSc hTm m (recs ++ [r]) (s + 1) acc₁ t₁
          sps₁ recs₁ acc₂ t₂ (hs2 sp r acc₁ t₁ hsp) hrest
        refine ⟨by simp [ih.1], ?_, ?_⟩
        · intro p hp
          rcases List.mem_cons.mp hp with rfl | hmem
          · exact h0.1
          · exact ih.2.1 p hmem
        · intro i p sh tm hp hsh htm
          cases i with
          | zero =>
            simp only [List.getElem?_cons_zero, Option.some.injEq] at hp
            subst hp
            rw [Nat.add_zero] at hsh htm
            have hsh_eq : slotShape (atLog P (elog s)) s = sh := by
              change P.geom.slots.getD s (0, 0, 0) = sh
              rw [List.getD_eq_getElem?_getD, hsh]; rfl
            have htm_eq : slotTerms (atLog P (elog s)) s = tm := by
              change P.geom.terms.getD s 0 = tm
              rw [List.getD_eq_getElem?_getD, htm]; rfl
            rw [hsh_eq, htm_eq] at h0
            exact ⟨h0.2.1, h0.2.2.1, h0.2.2.2⟩
          | succ j =>
            simp only [List.getElem?_cons_succ] at hp
            rw [show s + (j + 1) = s + 1 + j by omega] at hsh htm
            exact ih.2.2 j p sh tm hp hsh htm

/-- Extract `SlotCanon`, `sps.length = m`, and per-slot `CoreShape` from `slotsProve` + `SlotsSum`. -/
theorem slotsProve_shape_canon (H : HIn → Dig) (P : BlockParams)
    {K : Type} [Field K] [Algebra GF K] (U : K) (D : SlotData P) (b g a : Fp2)
    (hSc : ∀ s hist acc df c, (D.scalar s hist acc df c).Canon)
    (hTm : ∀ s hist acc df c rho, ∀ x ∈ D.terms s hist acc df c rho, x.Canon) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof)
      (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      SlotsSum H P U D b g a m recs s acc t →
      slotsProve H P D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      sps.length = m
        ∧ (∀ p ∈ sps, SlotCanon p)
        ∧ ∀ (i : ℕ) (p : SlotProof) (sh : ℕ × ℕ × ℕ) (tm : ℕ),
            sps[i]? = some p → P.geom.slots[s + i]? = some sh → P.geom.terms[s + i]? = some tm →
            p.rounds.length = sh.1 + sh.2.1 ∧ (∀ r ∈ p.rounds, r.length = sh.2.2 + 1) ∧ p.terms.length = tm
  | 0, _, _, _, _, _, _, _, _, _, h => by
    simp only [slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -, -, -⟩ := h
    exact ⟨rfl, (fun _ hp => by cases hp), (fun _ _ _ _ hp => by cases hp)⟩
  | m + 1, recs, s, acc, t, sps, recs', acc', t', hS, h => by
    obtain ⟨hs1, hs2⟩ := hS
    simp only [slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl, rfl, rfl⟩ := h
        have h0 := slotProve_shape_canon H P U D s (histOf b g a recs) acc t
          sp r acc₁ t₁ (fun df c => hSc s _ _ df c) (fun df c rho => hTm s _ _ df c rho) hs1 hsp
        have ih := slotsProve_shape_canon H P U D b g a hSc hTm m (recs ++ [r]) (s + 1) acc₁ t₁
          sps₁ recs₁ acc₂ t₂ (hs2 sp r acc₁ t₁ hsp) hrest
        refine ⟨by simp [ih.1], ?_, ?_⟩
        · intro p hp
          rcases List.mem_cons.mp hp with rfl | hmem
          · exact h0.1
          · exact ih.2.1 p hmem
        · intro i p sh tm hp hsh htm
          cases i with
          | zero =>
            simp only [List.getElem?_cons_zero, Option.some.injEq] at hp
            subst hp
            rw [Nat.add_zero] at hsh htm
            have hsh_eq : slotShape P s = sh := by
              change P.geom.slots.getD s (0, 0, 0) = sh
              rw [List.getD_eq_getElem?_getD, hsh]; rfl
            have htm_eq : slotTerms P s = tm := by
              change P.geom.terms.getD s 0 = tm
              rw [List.getD_eq_getElem?_getD, htm]; rfl
            rw [hsh_eq, htm_eq] at h0
            exact ⟨h0.2.1, h0.2.2.1, h0.2.2.2⟩
          | succ j =>
            simp only [List.getElem?_cons_succ] at hp
            rw [show s + (j + 1) = s + 1 + j by omega] at hsh htm
            exact ih.2.2 j p sh tm hp hsh htm

end SlotCodec

/-! ## 5. Generic honest PCS `Table` builder (`mkPcsTable`) & concrete endpoint table (`shdP_epTable`) -/

section HonestTables

/-- Base-field Lagrange row form on `G_{2^logN}` at `rootFp logN`. -/
noncomputable def lagGF (logN : ℕ) (h : logN ≤ 32) : RowForm GF (2 ^ logN) :=
  lagForm (Nat.two_pow_pos logN) (rootFp_isPrimitiveRoot h)

/-- Honest PCS `Table` constructed from any list of base-field rows (`n + q` entries each) and leaf salts. -/
noncomputable def mkPcsTable (logN lr q : ℕ) (h : logN ≤ 32) (rows : List (List Fp)) (salts : ℕ → Dig) : Table where
  rows := rows
  cols j := rows.map fun r =>
    Fp.ofGF ((encPoly (lagGF logN h) (fun t : Fin (2 ^ logN) => (r.getD t Fp.zero).toGF)
      (fun k : Fin q => (r.getD (2 ^ logN + k) Fp.zero).toGF)).eval (cosetPt (rootFp (logN + lr)) j).toGF)
  salts := salts

theorem mkPcsTable_cols_canon (logN lr q : ℕ) (h : logN ≤ 32) (rows : List (List Fp)) (salts : ℕ → Dig) :
    ∀ j, ∀ x ∈ (mkPcsTable logN lr q h rows salts).cols j, x.Canon := by
  intro j x hx
  obtain ⟨_, -, rfl⟩ := List.mem_map.mp hx
  exact Fp.ofGF_canon _

theorem mkPcsTable_cols_length (logN lr q : ℕ) (h : logN ≤ 32) (rows : List (List Fp)) (salts : ℕ → Dig) (j : ℕ) :
    ((mkPcsTable logN lr q h rows salts).cols j).length = (mkPcsTable logN lr q h rows salts).rows.length := by
  simp [mkPcsTable]

theorem mkPcsTable_colsHonest {K : Type} [Field K] [Algebra GF K] (U : K)
    (logN lr q : ℕ) (h : logN ≤ 32) (rows : List (List Fp)) (salts : ℕ → Dig) :
    ColsHonest U (lagK logN h) q (cosetPt (rootFp (logN + lr))) (2 ^ logN * 2 ^ lr)
      (mkPcsTable logN lr q h rows salts) := by
  intro j _
  refine ⟨by simp [mkPcsTable], fun i hi => ?_⟩
  have hget : ((mkPcsTable logN lr q h rows salts).cols j).getD i Fp.zero =
      Fp.ofGF ((encPoly (lagGF logN h) (fun t : Fin (2 ^ logN) => ((rows.getD i []).getD t Fp.zero).toGF)
        (fun k : Fin q => ((rows.getD i []).getD (2 ^ logN + k) Fp.zero).toGF)).eval
          (cosetPt (rootFp (logN + lr)) j).toGF) :=
    getD_map_lt' _ rows i hi [] Fp.zero
  rw [hget, Fp.toGF_ofGF]
  have hext : RowFormExt (lagGF logN h) (lagK (K := K) logN h) :=
    lagForm_ext (Nat.two_pow_pos logN) (rootFp_isPrimitiveRoot h)
  have hmp := encPoly_map_base (lagGF logN h) (lagK (K := K) logN h) hext
    (fun t : Fin (2 ^ logN) => ((rows.getD i []).getD t Fp.zero).toGF)
    (fun k : Fin q => ((rows.getD i []).getD (2 ^ logN + k) Fp.zero).toGF)
  have hv : vecK U (2 ^ logN) (liftRow (rows.getD i [])) =
      fun t : Fin (2 ^ logN) => algebraMap GF K (((rows.getD i []).getD t Fp.zero).toGF) := by
    funext t
    exact toK_liftRow U (rows.getD i []) t
  have hp : padK U (2 ^ logN) q (liftRow (rows.getD i [])) =
      fun k : Fin q => algebraMap GF K (((rows.getD i []).getD (2 ^ logN + k) Fp.zero).toGF) := by
    funext k
    exact toK_liftRow U (rows.getD i []) (2 ^ logN + k)
  unfold encK
  change _ = (encPoly (lagK logN h) (vecK U (2 ^ logN) (liftRow (rows.getD i [])))
    (padK U (2 ^ logN) q (liftRow (rows.getD i [])))).eval (algebraMap GF K (cosetPt (rootFp (logN + lr)) j).toGF)
  rw [hv, hp, hmp, Polynomial.eval_map_apply]

/-- Concrete Shieldstral input-endpoint `Table` matching `shdP_cin Hdr tag` on `(x, epBase c)`. -/
noncomputable def shdP_epTable {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) : Table where
  rows := List.ofFn fun i : Fin 6 =>
    List.ofFn (fun t : Fin (2 ^ 8) => Fp.ofGF (epxMsg 6 1 shdP_epPlace shdP_epPos x r i t))
      ++ List.ofFn (fun k : Fin 256 => Fp.ofGF (r.pads i k))
  cols j := if hj : j < 2 ^ 11 then ((shdP_cin Hdr tag).column x r ⟨j, hj⟩).1 else List.replicate 6 Fp.zero
  salts j := if hj : j < 2 ^ 11 then r.salts ⟨j, hj⟩ else zeroDig

theorem shdP_epTable_rows_length {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) :
    (shdP_epTable (Hdr := Hdr) tag x r).rows.length = 6 :=
  List.length_ofFn

theorem shdP_epTable_cols_length {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) (j : ℕ) :
    ((shdP_epTable (Hdr := Hdr) tag x r).cols j).length = (shdP_epTable (Hdr := Hdr) tag x r).rows.length := by
  rw [shdP_epTable_rows_length]
  dsimp only [shdP_epTable]
  split_ifs with hj
  · exact ((shdP_cin Hdr tag).column x r ⟨j, hj⟩).2
  · simp

theorem shdP_epTable_cols_canon {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) :
    ∀ j, ∀ w ∈ (shdP_epTable (Hdr := Hdr) tag x r).cols j, w.Canon := by
  intro j w hw
  dsimp only [shdP_epTable] at hw
  split_ifs at hw with hj
  · change w ∈ List.ofFn (fun i : Fin 6 => Fp.ofGF ((shdP_cin Hdr tag).word x r i ⟨j, hj⟩)) at hw
    obtain ⟨i, rfl⟩ := List.mem_ofFn.mp hw
    exact Fp.ofGF_canon _
  · obtain ⟨_, rfl⟩ := List.mem_replicate.mp hw
    exact Fp2.canon_zero.1

private theorem treeRoot_liftH_eq (tag : MTag) (Lq rows : ℕ) (h64 : 64 ≤ Lq) (hr : 8 * rows ≤ Lq)
    (G : QB Lq → Dig) :
    ∀ (d : ℕ) (v₁ v₂ : ℕ → Dig), (∀ i, i < 2 ^ d → v₁ i = v₂ i) →
      ZK60.Complete.treeRoot (merkleEnc tag) (liftH G) d v₁ =
        ZK60.Complete.treeRoot (merkleEncB tag Lq rows h64 hr) G d v₂
  | 0, v₁, v₂, hv => hv 0 (by norm_num)
  | d + 1, v₁, v₂, hv => by
    simp only [ZK60.Complete.treeRoot]
    refine treeRoot_liftH_eq tag Lq rows h64 hr G d _ _ (fun i hi => ?_)
    have h2 : 2 ^ (d + 1) = 2 * 2 ^ d := by ring
    have he1 : v₁ (2 * i) = v₂ (2 * i) := hv (2 * i) (by omega)
    have he2 : v₁ (2 * i + 1) = v₂ (2 * i + 1) := hv (2 * i + 1) (by omega)
    rw [he1, he2]
    exact liftH_eq G tag.node ((v₂ (2 * i)).toList ++ (v₂ (2 * i + 1)).toList)
      (by rw [digPair_length]; exact h64)

/-- **Endpoint Merkle-root agreement**: `rootOf (liftH G) tag 11 (shdP_epTable tag x r)` equals
`honestRoot (shdP_cin Hdr tag) Lq ... G x r` verbatim. -/
theorem shdP_epTable_root {Hdr : Type} (tag : MTag) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (G : QB Lq → Dig) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) :
    rootOf (liftH G) tag 11 (shdP_epTable (Hdr := Hdr) tag x r) =
      honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr (Hdr := Hdr) tag hL20) G x r := by
  unfold rootOf honestRoot
  refine treeRoot_liftH_eq tag Lq 6 (le64_of_le20 hL20) (shdP_hr (Hdr := Hdr) tag hL20) G 11 _ _ (fun i hi => ?_)
  have hi' : i < (shdP_cin Hdr tag).N := hi
  unfold leafAt saltLeaf colDigest planeLeaves MerkleEnc.leafDigest
  simp only [shdP_epTable, hi, hi', ↓reduceDIte]
  have hcolLen : (colBytes ((shdP_cin Hdr tag).column x r ⟨i, hi'⟩).1).length ≤ Lq := by
    rw [colBytes_length, ((shdP_cin Hdr tag).column x r ⟨i, hi'⟩).2]
    exact shdP_hr (Hdr := Hdr) tag hL20
  have hcol : liftH G ⟨tag.col, colBytes ((shdP_cin Hdr tag).column x r ⟨i, hi'⟩).1⟩ =
      G ((merkleEncB tag Lq 6 (le64_of_le20 hL20) (shdP_hr (Hdr := Hdr) tag hL20)).colQ ((shdP_cin Hdr tag).column x r ⟨i, hi'⟩)) :=
    liftH_eq G tag.col _ hcolLen
  rw [hcol]
  exact liftH_eq G tag.leaf _ (by rw [digPair_length]; exact le64_of_le20 hL20)

private theorem cosetPt_rootFp11_eq_epPts (j : ℕ) (hj : j < 2 ^ 11) :
    (cosetPt (rootFp 11) j).toGF = epPts ⟨j, hj⟩ := by
  unfold cosetPt epPts cosetPts
  rw [Fp.toGF_mul, seven_toGF, Fp.toGF_pow, UInt64.toNat_ofNat',
    Nat.mod_eq_of_lt (lt_trans hj (by norm_num)), rootFp_toGF (by norm_num)]

/-- **Endpoint `ColsHonest`**: `shdP_epTable` satisfies `ColsHonest` at `lagK 8`, `Q = 256`, `cosetPt (rootFp 11)`. -/
theorem shdP_epTable_colsHonest {Hdr : Type} (tag : MTag) (x : shieldS0.Tok → ℕ) (r : EpxSalt 6) :
    ColsHonest shdP_U (lagK 8 (by norm_num)) 256 (cosetPt (rootFp 11)) (2 ^ 8 * 2 ^ 3)
      (shdP_epTable (Hdr := Hdr) tag x r) := by
  intro j hj
  have hj11 : j < 2 ^ 11 := by omega
  refine ⟨shdP_epTable_cols_length (Hdr := Hdr) tag x r j, fun i hi => ?_⟩
  rw [shdP_epTable_rows_length] at hi
  have hgetCol : ((shdP_epTable (Hdr := Hdr) tag x r).cols j).getD i Fp.zero =
      Fp.ofGF ((shdP_cin Hdr tag).word x r ⟨i, hi⟩ ⟨j, hj11⟩) := by
    simp only [shdP_epTable, hj11, ↓reduceDIte]
    exact ofFn_getD (fun r_i : Fin 6 => Fp.ofGF ((shdP_cin Hdr tag).word x r r_i ⟨j, hj11⟩)) i hi Fp.zero
  rw [hgetCol, Fp.toGF_ofGF]
  have hlag : lagK (K := shdP_K) 8 (by norm_num) = rowFormK8 shdP_K := by
    unfold lagK rowFormK8
    exact og_lagForm_congr shdP_K (Nat.two_pow_pos 8)
      (congrArg (algebraMap GF shdP_K) (rootFp_toGF (by norm_num))) _ _
  have hrowGet : (shdP_epTable (Hdr := Hdr) tag x r).rows.getD i [] =
      List.ofFn (fun t : Fin (2 ^ 8) => Fp.ofGF (epxMsg 6 1 shdP_epPlace shdP_epPos x r ⟨i, hi⟩ t))
        ++ List.ofFn (fun k : Fin 256 => Fp.ofGF (r.pads ⟨i, hi⟩ k)) := by
    show (List.ofFn _).getD i [] = _
    exact ofFn_getD _ i hi []
  have hvec : vecK shdP_U (2 ^ 8) (liftRow ((shdP_epTable (Hdr := Hdr) tag x r).rows.getD i [])) =
      fun t : Fin (2 ^ 8) => algebraMap GF shdP_K (epxMsg 6 1 shdP_epPlace shdP_epPos x r ⟨i, hi⟩ t) := by
    funext t
    rw [vecK, toK_liftRow, hrowGet, List.getD_eq_getElem?_getD,
      List.getElem?_append_left (by rw [List.length_ofFn]; exact t.isLt),
      List.getElem?_ofFn, dite_eq_left t.isLt, Option.getD_some, Fp.toGF_ofGF]
  have hpad : padK shdP_U (2 ^ 8) 256 (liftRow ((shdP_epTable (Hdr := Hdr) tag x r).rows.getD i [])) =
      fun k : Fin 256 => algebraMap GF shdP_K (r.pads ⟨i, hi⟩ k) := by
    funext k
    rw [padK, toK_liftRow, hrowGet, List.getD_eq_getElem?_getD,
      List.getElem?_append_right (by rw [List.length_ofFn]; exact Nat.le_add_right _ _),
      List.length_ofFn, Nat.add_sub_cancel_left,
      List.getElem?_ofFn, dite_eq_left k.isLt, Option.getD_some, Fp.toGF_ofGF]
  unfold encK
  rw [hlag, hvec, hpad, cosetPt_rootFp11_eq_epPts j hj11]
  have hmp := encPoly_map_base epForm (rowFormK8 shdP_K) (rowFormK8_ext_ep shdP_K)
    (epxMsg 6 1 shdP_epPlace shdP_epPos x r ⟨i, hi⟩) (r.pads ⟨i, hi⟩)
  rw [hmp, Polynomial.eval_map_apply]
  rfl

end HonestTables

end ZK60.HonestShield
