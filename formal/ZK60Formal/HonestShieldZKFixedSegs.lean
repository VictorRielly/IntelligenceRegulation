/-
D63 lane L69, Milestone A Part 2c (`HonestShieldZKFixedSegs.lean`):
fixed-schedule `PProg` implementations, exact `.run` equivalence theorems, and `SliceSpec`
discharges for all three segment kinds of the 28-segment Shieldstral T128 R13 honest prover
(`shdP_honestRunP_zk`):
1. **`stSlotsProveFixedProg`** (IN-C `atLog`-indexed slot loop, `167` `.pt`s),
2. **Shared table/audit/fit helpers** (`merkleTableSliceSpec`, `openingGroupsAt_sum_eq_length`,
   `auditClaims_length_none`, `auditClaims_length_some_last`, `polySlotData_fitSc`, `polyWords_fit`,
   `blkSalts_eq_shdLeafSalt`),
3. **`incSegFixedProg`** (Stage `IN-C`: `205,401` `.pt`s = `605` tr + `102,400` leaves + `102,396` nodes;
   `307,801` total queries; trees `B_0`, `A_0`, `M_0`, `H_0`; cached `TE` opening),
4. **`blkSegFixedProg`** (Interior R13 Block `k : Fin 26`: `412,266` `.pt`s = `10,862` tr + `200,704` leaves +
   `200,700` nodes; `612,970` total queries; trees `B_{k+1}`, `A_{k+1}`, `M_{k+1}`, `H_{k+1}`; cached `B_k` opening),
5. **`outcSegFixedProg`** (Stage `OUT-C`: `74,522` `.pt`s = `797` tr + `36,864` leaves + `36,861` nodes;
   `111,386` total queries; trees `A_27`, `M_27`, `H_27`; cached `B_26` opening).

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKFixedOps

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
  labA labH labM labRows labLogCols)
open ZK60.Circuit (gP GF)

/-! ## 1. Fixed-schedule `stSlotsProve` (`IN-C` `atLog`-indexed slot loop) -/

section StSlotsFixed

theorem slotFixedLen_atLog (P : BlockParams) (e s : ℕ) :
    slotFixedLen (atLog P e) s = slotFixedLen P s := rfl

theorem slotFixedSched_atLog (P : BlockParams) (e s base tip : ℕ) :
    slotFixedSched (atLog P e) s base tip = slotFixedSched P s base tip := rfl

theorem slotFixedLen_of_stgSame {P₁ P₂ : BlockParams} (hs : StgSame P₁ P₂) (s : ℕ) :
    slotFixedLen P₁ s = slotFixedLen P₂ s := by
  unfold slotFixedLen slotN Exec.Block.slotShape
  rw [hs.1, hs.2]

theorem slotFixedSched_of_stgSame {P₁ P₂ : BlockParams} (hs : StgSame P₁ P₂) (s base tip : ℕ) :
    slotFixedSched P₁ s base tip = slotFixedSched P₂ s base tip := by
  unfold slotFixedSched slotN Exec.Block.slotShape
  rw [hs.1, hs.2]

theorem slotsFixedLen_of_stgSame {P₁ P₂ : BlockParams} (hs : StgSame P₁ P₂) :
    ∀ (s m : ℕ), slotsFixedLen P₁ s m = slotsFixedLen P₂ s m
  | _, 0 => rfl
  | s, m + 1 => by
    unfold slotsFixedLen
    rw [slotFixedLen_of_stgSame hs s, slotsFixedLen_of_stgSame hs (s + 1) m]

theorem slotsFixedSched_of_stgSame {P₁ P₂ : BlockParams} (hs : StgSame P₁ P₂) :
    ∀ (s m base tip : ℕ), slotsFixedSched P₁ s m base tip = slotsFixedSched P₂ s m base tip
  | _, 0, _, _ => rfl
  | s, m + 1, base, tip => by
    unfold slotsFixedSched; dsimp only
    rw [slotFixedLen_of_stgSame hs s, slotFixedSched_of_stgSame hs s base tip,
      slotsFixedLen_of_stgSame hs (s + 1) m, slotsFixedSched_of_stgSame hs (s + 1) m]

/-- **Fixed-schedule `stSlotsProve` (`m` slots starting at `s` with per-slot IO width `elog s`)**. -/
def stSlotsProveFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ℕ → Bool → List SlotRec → ℕ → Acc → Tr →
      PProg (QB Lq) Dig (Option (List SlotProof × List SlotRec × Acc) × Tr)
  | 0, active, recs, _, acc, t => .ret (if active then some ([], recs, acc) else none, t)
  | m + 1, active, recs, s, acc, t =>
    (slotProveFixedProg Lq hL20 key (atLog P (elog s)) (sdAt D (elog s)) s active
      (Exec.Block.histOf b g a recs) acc t).andThen fun r =>
      match r.1 with
      | none =>
        (stSlotsProveFixedProg Lq hL20 key P elog D b g a m false recs (s + 1) acc r.2).andThen fun rest =>
          .ret (none, rest.2)
      | some (sp, rec_, acc') =>
        (stSlotsProveFixedProg Lq hL20 key P elog D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2).andThen fun rest =>
          match rest.1 with
          | none => .ret (none, rest.2)
          | some (sps, recs', acc'') => .ret (some (sp :: sps, recs', acc''), rest.2)

theorem stSlotsProveFixedProg_run_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m false recs s acc t).run G).1 = none
  | 0, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t => by
    unfold stSlotsProveFixedProg
    rw [PProg.run_andThen, slotProveFixedProg_run_inactive]
    dsimp only; rw [PProg.run_andThen, PProg.run]

theorem stSlotsProve_key (H : HIn → Dig) (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
      (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr),
      stSlotsProve H P elog D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      t'.key = t.key
  | 0, _, _, _, _, _, _, _, _, h => by
    unfold stSlotsProve at h; simp only [Except.ok.injEq, Prod.mk.injEq] at h
    exact congrArg Tr.key h.2.2.2.symm
  | m + 1, recs, s, acc, t, sps, recs', acc', t', h => by
    unfold stSlotsProve at h
    cases h1 : slotProve H (atLog P (elog s)) (sdAt D (elog s)) s (Exec.Block.histOf b g a recs) acc t with
    | error e => rw [h1] at h; cases h
    | ok v1 =>
      rcases v1 with ⟨sp, rec_, acc1, t1⟩
      rw [h1] at h; dsimp only at h
      cases h2 : stSlotsProve H P elog D b g a m (recs ++ [rec_]) (s + 1) acc1 t1 with
      | error e => rw [h2] at h; cases h
      | ok v2 =>
        rcases v2 with ⟨sps2, recs2, acc2, t2⟩
        rw [h2] at h; simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨_, _, _, rfl⟩ := h
        exact (stSlotsProve_key H P elog D b g a m (recs ++ [rec_]) (s + 1) acc1 t1 sps2 recs2 acc2 t2 h2).trans
          (slotProve_key H (atLog P (elog s)) (sdAt D (elog s)) s (Exec.Block.histOf b g a recs) acc t sp rec_ acc1 t1 h1)

theorem stSlotsProveFixedProg_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN (atLog P (elog s)) s)
        ((sdAt D (elog s)).strat s hist acc df (slotC (liftH G) (atLog P (elog s)) s t))
        (slotT4 (liftH G) (atLog P (elog s)) s t
          ((sdAt D (elog s)).scalar s hist acc df (slotC (liftH G) (atLog P (elog s)) s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      Exec.Block.slotDefChecks (atLog P (elog s)) s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length +
        (slotSP (liftH G) (atLog P (elog s)) (sdAt D (elog s)) s hist acc t df).terms.length * 16 ≤ Lq) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr), t.key = key →
      let res := (stSlotsProveFixedProg Lq hL20 key P elog D b g a m true recs s acc t).run G
      match stSlotsProve (liftH G) P elog D b g a m recs s acc t with
      | .ok (sps, recs', acc', t') => res = (some (sps, recs', acc'), t')
      | .error () => res.1 = none
  | 0, _, _, _, _, _ => rfl
  | m + 1, recs, s, acc, t, htKey => by
    dsimp only
    unfold stSlotsProveFixedProg stSlotsProve
    rw [PProg.run_andThen]
    have h1 := slotProveFixedProg_run Lq hL20 key (atLog P (elog s)) (sdAt D (elog s)) s
      (Exec.Block.histOf b g a recs) acc t htKey G (hfitSc s _ acc t) (hfitTerms s _ acc t)
    dsimp only at h1
    cases hsp : slotProve (liftH G) (atLog P (elog s)) (sdAt D (elog s)) s (Exec.Block.histOf b g a recs) acc t with
    | error u =>
      cases u; rw [hsp] at h1; rw [h1]; dsimp only
      rw [PProg.run_andThen, PProg.run]
    | ok v1 =>
      rcases v1 with ⟨sp, rec_, acc', t'⟩
      rw [hsp] at h1; rw [h1]; dsimp only
      rw [PProg.run_andThen]
      have ht'Key : t'.key = key :=
        (slotProve_key (liftH G) (atLog P (elog s)) (sdAt D (elog s)) s
          (Exec.Block.histOf b g a recs) acc t sp rec_ acc' t' hsp).trans htKey
      have h2 := stSlotsProveFixedProg_run Lq hL20 key P elog D b g a G hfitSc hfitTerms m
        (recs ++ [rec_]) (s + 1) acc' t' ht'Key
      dsimp only at h2
      cases hrest : stSlotsProve (liftH G) P elog D b g a m (recs ++ [rec_]) (s + 1) acc' t' with
      | error u =>
        cases u; rw [hrest] at h2; rw [h2]; dsimp only; rfl
      | ok v2 =>
        rcases v2 with ⟨sps, recs', acc'', t''⟩
        rw [hrest] at h2; rw [h2]; dsimp only; rfl


private theorem stSlotsProveFixedProg_run_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN (atLog P (elog s)) s)
        ((sdAt D (elog s)).strat s hist acc df (slotC (liftH G) (atLog P (elog s)) s t))
        (slotT4 (liftH G) (atLog P (elog s)) s t
          ((sdAt D (elog s)).scalar s hist acc df (slotC (liftH G) (atLog P (elog s)) s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      Exec.Block.slotDefChecks (atLog P (elog s)) s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length +
        (slotSP (liftH G) (atLog P (elog s)) (sdAt D (elog s)) s hist acc t df).terms.length * 16 ≤ Lq)
    (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (htKey : t.key = key)
    (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr)
    (hsl : stSlotsProve (liftH G) P elog D b g a m recs s acc t = .ok (sps, recs', acc', t')) :
    (stSlotsProveFixedProg Lq hL20 key P elog D b g a m true recs s acc t).run G = (some (sps, recs', acc'), t') := by
  have h := stSlotsProveFixedProg_run Lq hL20 key P elog D b g a G hfitSc hfitTerms m recs s acc t htKey
  dsimp only at h; rw [hsl] at h; exact h

private theorem stSlotsProveFixedProg_run_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN (atLog P (elog s)) s)
        ((sdAt D (elog s)).strat s hist acc df (slotC (liftH G) (atLog P (elog s)) s t))
        (slotT4 (liftH G) (atLog P (elog s)) s t
          ((sdAt D (elog s)).scalar s hist acc df (slotC (liftH G) (atLog P (elog s)) s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df,
      (atLog P (elog s)).define s hist (t.challengeFp2Vec (liftH G) ((atLog P (elog s)).draws s)).1 = .ok df →
      Exec.Block.slotDefChecks (atLog P (elog s)) s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length +
        (slotSP (liftH G) (atLog P (elog s)) (sdAt D (elog s)) s hist acc t df).terms.length * 16 ≤ Lq)
    (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (htKey : t.key = key)
    (hsl : stSlotsProve (liftH G) P elog D b g a m recs s acc t = .error ()) :
    ((stSlotsProveFixedProg Lq hL20 key P elog D b g a m true recs s acc t).run G).1 = none := by
  have h := stSlotsProveFixedProg_run Lq hL20 key P elog D b g a G hfitSc hfitTerms m recs s acc t htKey
  dsimp only at h; rw [hsl] at h; exact h

private theorem slotsProveFixedProg_run_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
        (D.strat s hist acc df (slotC (liftH G) P s t))
        (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) P D s hist acc t df).terms.length * 16 ≤ Lq)
    (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (htKey : t.key = key)
    (sps : List SlotProof) (recs' : List SlotRec) (acc' : Acc) (t' : Tr)
    (hsl : slotsProve (liftH G) P D b g a m recs s acc t = .ok (sps, recs', acc', t')) :
    (slotsProveFixedProg Lq hL20 key P D b g a m true recs s acc t).run G = (some (sps, recs', acc'), t') := by
  have h := slotsProveFixedProg_run Lq hL20 key P D b g a G hfitSc hfitTerms m recs s acc t htKey
  dsimp only at h; rw [hsl] at h; exact h

private theorem slotsProveFixedProg_run_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (P : BlockParams) (D : SlotData P) (b g a : Fp2) (G : QB Lq → Dig)
    (hfitSc : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
        (D.strat s hist acc df (slotC (liftH G) P s t))
        (slotT4 (liftH G) P s t (D.scalar s hist acc df (slotC (liftH G) P s t)))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t df, P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) P D s hist acc t df).terms.length * 16 ≤ Lq)
    (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (htKey : t.key = key)
    (hsl : slotsProve (liftH G) P D b g a m recs s acc t = .error ()) :
    ((slotsProveFixedProg Lq hL20 key P D b g a m true recs s acc t).run G).1 = none := by
  have h := slotsProveFixedProg_run Lq hL20 key P D b g a G hfitSc hfitTerms m recs s acc t htKey
  dsimp only at h; rw [hsl] at h; exact h

private theorem openingAuditFixedProg_run_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (g : OpenGeom) (T : Table) (hrows : rows = T.rows.length) (hgr : g.rows = rows) (hgg : g.groups = nGroups)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hsumOk : ∀ og, auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox = .ok () →
      openingGroupsAt cl prm.logCols = .ok og → og.length = g.groups → (og.map Prod.snd).sum = nClaims)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j)
    (hchk : checkOpeningExec (liftH G) g prm.logCols cl t = .ok ()) :
    (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree true
      (openingHdrOk g prm.logCols cl) cl t).run G =
      (some (bOpen (liftH G) tag prm depth T cl t).1, (bOpen (liftH G) tag prm depth T cl t).2) := by
  have h := openingAuditFixedProg_run Lq hL20 tag key prm depth nClaims rows nGroups hnn hnQ
    g T hrows hgr hgg tree cl t htKey G hfit hfitP hsumOk htree
  dsimp only at h; rw [hchk] at h; exact h

private theorem openingAuditFixedProg_run_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (g : OpenGeom) (T : Table) (hrows : rows = T.rows.length) (hgr : g.rows = rows) (hgg : g.groups = nGroups)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hsumOk : ∀ og, auditClaims cl (2 ^ prm.logCols) g.rows g.siteRows g.sumRows g.prox = .ok () →
      openingGroupsAt cl prm.logCols = .ok og → og.length = g.groups → (og.map Prod.snd).sum = nClaims)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j)
    (e : String) (hchk : checkOpeningExec (liftH G) g prm.logCols cl t = .error e) :
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree true
      (openingHdrOk g prm.logCols cl) cl t).run G).1 = none := by
  have h := openingAuditFixedProg_run Lq hL20 tag key prm depth nClaims rows nGroups hnn hnQ
    g T hrows hgr hgg tree cl t htKey G hfit hfitP hsumOk htree
  dsimp only at h; rw [hchk] at h; exact h

private theorem openingAuditFixedProg_run_ep_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (data n : ℕ) (g : OpenGeom) (hgr : g.rows = data + Exec.StageV.epMaskRows) (hgp : g.prox = data + 2)
    (T : Table) (hrows : data + Exec.StageV.epMaskRows = T.rows.length)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j)
    (hchk : Exec.StageV.checkTokenEp (liftH G) cl data n t = .ok ()) :
    (openingAuditFixedProg Lq hL20 key prm depth 1 (data + Exec.StageV.epMaskRows) 1 g T tree true
      (tokenEpHdrOk cl data n) cl t).run G =
      (some (bOpen (liftH G) tag prm depth T cl t).1, (bOpen (liftH G) tag prm depth T cl t).2) := by
  have h := openingAuditFixedProg_run_ep Lq hL20 tag key prm depth hnn hnQ data n g hgr hgp T hrows tree cl t htKey G hfit hfitP htree
  dsimp only at h; rw [hchk] at h; exact h

private theorem openingAuditFixedProg_run_ep_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (prm : PcsPrm) (depth : ℕ) (hnn : prm.nn = 2 ^ depth) (hnQ : 0 < prm.nQ)
    (data n : ℕ) (g : OpenGeom) (hgr : g.rows = data + Exec.StageV.epMaskRows) (hgp : g.prox = data + 2)
    (T : Table) (hrows : data + Exec.StageV.epMaskRows = T.rows.length)
    (tree : MerkleLevels depth) (cl : List Exec.Block.ZClaim) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hfit : 48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (hfitP : 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ depth), tree.path j hj = pathOf (liftH G) tag depth T j)
    (e : String) (hchk : Exec.StageV.checkTokenEp (liftH G) cl data n t = .error e) :
    ((openingAuditFixedProg Lq hL20 key prm depth 1 (data + Exec.StageV.epMaskRows) 1 g T tree true
      (tokenEpHdrOk cl data n) cl t).run G).1 = none := by
  have h := openingAuditFixedProg_run_ep Lq hL20 tag key prm depth hnn hnQ data n g hgr hgp T hrows tree cl t htKey G hfit hfitP htree
  dsimp only at h; rw [hchk] at h; exact h

private theorem stageSeg_eq {b1 b2 : Option Dig} {a1 a2 h1 h2 m1 m2 : Dig}
    {sl : List SlotProof} {mO : Exec.Block.MaskOpening} {aO hO : Exec.Block.OpeningZk}
    {cl1 cl2 : List Exec.Block.OpeningZk}
    (hb : b1 = b2) (ha : a1 = a2) (hh : h1 = h2) (hm : m1 = m2) (hcl : cl1 = cl2) :
    (⟨b1, ⟨a1, h1, m1, sl, mO, aO, hO⟩, cl1⟩ : StageSeg) = ⟨b2, ⟨a2, h2, m2, sl, mO, aO, hO⟩, cl2⟩ := by
  subst hb ha hh hm hcl; rfl

private theorem stageSeg_eta (s : StageSeg) :
    (⟨s.bRoot, ⟨s.core.aRoot, s.core.hRoot, s.core.maskRoot, s.core.slots, s.core.maskOpen, s.core.aOpen, s.core.hOpen⟩, s.closes⟩ : StageSeg) = s := by
  cases s with | mk b core cl => cases core; rfl

private theorem core_eq {a1 a2 h1 h2 m1 m2 : Dig}
    {sl : List SlotProof} {mO : Exec.Block.MaskOpening} {aO hO : Exec.Block.OpeningZk}
    (ha : a1 = a2) (hh : h1 = h2) (hm : m1 = m2) :
    (⟨a1, h1, m1, sl, mO, aO, hO⟩ : Exec.Block.Core) = ⟨a2, h2, m2, sl, mO, aO, hO⟩ := by
  subst ha hh hm; rfl

private theorem core_eta (c : Exec.Block.Core) :
    (⟨c.aRoot, c.hRoot, c.maskRoot, c.slots, c.maskOpen, c.aOpen, c.hOpen⟩ : Exec.Block.Core) = c := by
  cases c; rfl

private theorem trChainTip_trTip (base n : ℕ) (hn : 0 < n) :
    (trChainTip base n hn).trTip = base + n - 1 := rfl

private theorem trChainTip_eq {b₁ n₁ b₂ n₂ : ℕ} (h₁ : 0 < n₁) (h₂ : 0 < n₂)
    (heq : b₁ + n₁ = b₂ + n₂) : (trChainTip b₁ n₁ h₁).trTip = (trChainTip b₂ n₂ h₂).trTip :=
  congrArg (· - 1) heq

private theorem sub1_eq_trChainTip {a b n : ℕ} (hn : 0 < n) (heq : a = b + n) :
    a - 1 = (trChainTip b n hn).trTip :=
  congrArg (· - 1) heq

private theorem run_andThen_with {Q R α β : Type} (p : PProg Q R α) (f : α → PProg Q R β)
    (G : Q → R) (a : α) (ha : p.run G = a) :
    (p.andThen f).run G = (f a).run G := by
  rw [PProg.run_andThen, ha]

private theorem merkle_andThen_elim (Lq : ℕ) (hL : 64 ≤ Lq) (tag : MTag) (d m : ℕ)
    (hfit : 8 * m ≤ Lq) (T : Table)
    (hcols : ∀ j : Fin (2 ^ d), (T.cols j.val).length = m) (G : QB Lq → Dig) :
    ∃ tr : MerkleLevels d,
      (merkleTableProg Lq hL tag d m hfit T hcols).run G = tr
      ∧ tr.getRoot = rootOf (liftH G) tag d T
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ d), tr.path j hj = pathOf (liftH G) tag d T j :=
  ⟨_, rfl, merkleTableProg_run Lq hL tag d m hfit T hcols G⟩

private theorem elim_merkle_andThen (Lq : ℕ) (hL : 64 ≤ Lq) (tag : MTag) (d m : ℕ)
    (hfit : 8 * m ≤ Lq) (T : Table)
    (hcols : ∀ j : Fin (2 ^ d), (T.cols j.val).length = m) (G : QB Lq → Dig)
    {P : Prop}
    (k : ∀ tr : MerkleLevels d,
      (merkleTableProg Lq hL tag d m hfit T hcols).run G = tr →
      (tr.getRoot = rootOf (liftH G) tag d T ∧
        ∀ (j : ℕ) (hj : j < 2 ^ d), tr.path j hj = pathOf (liftH G) tag d T j) → P) : P :=
  k _ rfl (merkleTableProg_run Lq hL tag d m hfit T hcols G)

private theorem run_andThen_snd_fst {Q R α β γ δ : Type} (p : PProg Q R α)
    (f : α → PProg Q R (β × γ × δ)) (G : Q → R) (y : γ)
    (h : ∀ a, ((f a).run G).2.1 = y) : ((p.andThen f).run G).2.1 = y := by
  rw [PProg.run_andThen]; exact h (p.run G)

private theorem ret_ite_snd_fst {Q R α β γ : Type} (c : Bool) (a₁ a₂ : α) (b : β) (d : γ) (G : Q → R) :
    ((if c = true then PProg.ret (a₁, b, d) else PProg.ret (a₂, b, d)).run G).2.1 = b := by
  cases c <;> rfl

private theorem run_andThen_fst_none {Q R α β γ : Type} (p : PProg Q R α)
    (f : α → PProg Q R (Option β × γ)) (G : Q → R)
    (h : ∀ a, ((f a).run G).1 = none) : ((p.andThen f).run G).1 = none := by
  rw [PProg.run_andThen]; exact h (p.run G)

private theorem run_andThen_with_fst_none {Q R α β γ δ : Type} (p : PProg Q R (Option α × β))
    (f : Option α × β → PProg Q R (Option γ × δ)) (G : Q → R)
    (hp : (p.run G).1 = none) (hf : ∀ b, ((f (none, b)).run G).1 = none) :
    ((p.andThen f).run G).1 = none := by
  rw [PProg.run_andThen]
  have heq : p.run G = (none, (p.run G).2) := Prod.ext hp rfl
  rw [heq]; exact hf _

private theorem run_andThen_trAbsorb {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig} {t : Tr}
    (htKey : t.key = key) {label : List UInt8} {hlab : label.length ≤ 64} {data : List UInt8}
    (hfit : 48 + label.length + data.length ≤ Lq) {β : Type} (f : Tr → PProg (QB Lq) Dig β)
    (G : QB Lq → Dig) :
    ((trAbsorbKeyed Lq hL20 key t label hlab data).andThen f).run G =
      (f (t.absorb (liftH G) label data)).run G := by
  rw [PProg.run_andThen, trAbsorbKeyed_run Lq hL20 key t htKey label hlab data hfit G]

private theorem run_andThen_absorbRoot {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig} {t : Tr}
    (htKey : t.key = key) {label : List UInt8} {hlab : label.length ≤ 64} {root : Dig}
    {rows logCols : ℕ} {β : Type} (f : Tr → PProg (QB Lq) Dig β) (G : QB Lq → Dig) :
    ((absorbRootKeyed Lq hL20 key t label hlab root rows logCols).andThen f).run G =
      (f (Exec.Block.absorbRoot (liftH G) t label root rows logCols)).run G := by
  rw [PProg.run_andThen, absorbRootKeyed_run Lq hL20 key t htKey label hlab root rows logCols G]

private theorem run_andThen_trChallengeFp2 {Lq : ℕ} {h47 : 47 ≤ Lq} {key : Option Dig} {t : Tr}
    (htKey : t.key = key) {β : Type} (f : Fp2 × Tr → PProg (QB Lq) Dig β) (G : QB Lq → Dig) :
    ((trChallengeFp2Keyed Lq h47 key t).andThen f).run G =
      (f (t.challengeFp2 (liftH G))).run G := by
  rw [PProg.run_andThen, trChallengeFp2Keyed_run Lq h47 key t htKey G]

private theorem run_andThen_trChallengeFp2Vec {Lq : ℕ} {h47 : 47 ≤ Lq} {key : Option Dig}
    {n : ℕ} {t : Tr} (htKey : t.key = key) {β : Type}
    (f : List Fp2 × Tr → PProg (QB Lq) Dig β) (G : QB Lq → Dig) :
    ((trChallengeFp2VecKeyed Lq h47 key n t).andThen f).run G =
      (f (t.challengeFp2Vec (liftH G) n)).run G := by
  rw [PProg.run_andThen, trChallengeFp2VecKeyed_run Lq h47 key G n t htKey]

private theorem tr_absorbFp2_key (H : HIn → Dig) (lab : List UInt8) (xs : List Fp2) (t : Tr) :
    (t.absorbFp2 H lab xs).key = t.key := rfl

private theorem tr_challengeFp2Vec_key_aux (H : HIn → Dig) :
    ∀ (n : ℕ) (t : Tr), (t.challengeFp2Vec H n).2.key = t.key
  | 0, _ => rfl
  | n + 1, t => by
    unfold Tr.challengeFp2Vec
    exact tr_challengeFp2Vec_key_aux H n (t.challengeFp2 H).2

private theorem idxLoop_key (H : HIn → Dig) (bound : ℕ) (key : Option Dig) :
    ∀ (fuel : ℕ) (t : Tr) (rem : ℕ) (acc : List ℕ), t.key = key →
      (idxLoop H bound fuel t rem acc).2.key = key
  | 0, _, _, _, ht => ht
  | fuel + 1, t, rem, acc, ht => by
    unfold idxLoop
    split_ifs
    · exact ht
    · exact ht
    · exact idxLoop_key H bound key fuel (t.squeeze H).2 (rem - 4) _ ht

private theorem tr_challengeIndices_key (H : HIn → Dig) (n bound : ℕ) (t : Tr) (key : Option Dig)
    (ht : t.key = key) :
    ((t.challengeIndices H n bound).getD ([], t)).2.key = key := by
  unfold Tr.challengeIndices
  split_ifs
  · exact idxLoop_key H bound key n t n [] ht
  · exact ht

private theorem absorbVecs_key (H : HIn → Dig) (vs : List (List Fp2)) (t : Tr) (key : Option Dig)
    (ht : t.key = key) : (absorbVecs H vs t).key = key := by
  induction vs generalizing t with
  | nil => exact ht
  | cons v vs ih => exact ih _ ht

private theorem zkRhosAux_key (H : HIn → Dig) (rows : ℕ) (gs : List (List Fp2 × List (List Fp2 × Fp2)))
    (t : Tr) (key : Option Dig) (ht : t.key = key) :
    (zkRhosAux H rows gs t).2.2.key = key := by
  induction gs generalizing t with
  | nil =>
    unfold zkRhosAux
    rw [tr_challengeFp2Vec_key_aux, ht]
  | cons g gs ih =>
    unfold zkRhosAux
    have h1 : (t.challengeFp2Vec H g.2.length).2.key = key := by rw [tr_challengeFp2Vec_key_aux, ht]
    exact ih _ h1

private theorem bOpen_key (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth : ℕ)
    (T : Table) (cl : List Exec.Block.ZClaim) (t : Tr) (key : Option Dig) (ht : t.key = key) :
    (bOpen H tag prm depth T cl t).2.key = key := by
  unfold bOpen pcsProve pIdx pT2 pRhos
  refine tr_challengeIndices_key H prm.nQ prm.nn _ key ?_
  refine absorbVecs_key H _ _ key ?_
  exact zkRhosAux_key H _ _ t key ht

private theorem bMask_key (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K]
    (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (M : MTable) (S : ℕ) (fs : List Exec.Block.MaskFunctional) (t : Tr) (key : Option Dig)
    (ht : t.key = key) :
    (bMask H tag U hbij M S fs t).2.key = key := by
  unfold bMask maskProve mIdx
  exact tr_challengeIndices_key H mQ mDom (mT2 H U hbij (rootFp 9) M S (fs.map toMF) t) key
    (by unfold mT2 mT1; rw [tr_absorbFp2_key, tr_challengeFp2Vec_key_aux, tr_absorbFp2_key]; exact ht)

private theorem decide_eq_true_any {p : Prop} {inst : Decidable p} (h : p) :
    @decide p inst = true :=
  @decide_eq_true p inst h

private theorem run_andThen_snd_key {Q R α β : Type} (p : PProg Q R α)
    (f : α → PProg Q R (β × Tr)) (G : Q → R) (key : Option Dig)
    (h : ∀ a, ((f a).run G).2.key = key) : ((p.andThen f).run G).2.key = key := by
  rw [PProg.run_andThen]; exact h (p.run G)

private theorem run_andThen_snd_key_of_ret {Q R α β : Type} (p : PProg Q R (α × Tr))
    (f : α × Tr → PProg Q R (β × Tr)) (G : Q → R) (key : Option Dig)
    (hf : ∀ sq, ((f sq).run G).2 = sq.2) (hp : (p.run G).2.key = key) :
    ((p.andThen f).run G).2.key = key := by
  rw [PProg.run_andThen, hf]; exact hp

private theorem trSqueezeVecKeyed_run_key_aux (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr), 0 < n → ((trSqueezeVecKeyed Lq h47 key n t).run G).2.key = key
  | 0, _, h => by omega
  | 1, _, _ => by simp only [trSqueezeVecKeyed, trSqueezeKeyed, PProg.run_andThen, PProg.run]
  | n + 2, _, _ => by
    unfold trSqueezeVecKeyed
    rw [PProg.run_andThen, PProg.run_andThen]
    exact trSqueezeVecKeyed_run_key_aux Lq h47 key G (n + 1) _ (Nat.succ_pos n)

private theorem zkBMaskFixedProg_run_key (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr)
    (G : QB Lq → Dig) :
    ((zkBMaskFixedProg Lq hL20 key U hbij active M S tree fs t).run G).2.key = key := by
  unfold zkBMaskFixedProg
  rw [PProg.run_andThen, PProg.run_andThen, PProg.run_andThen, PProg.run_andThen, PProg.run_andThen]
  have hret : ∀ (a : Exec.Block.MaskOpening) (b : Tr),
      ((PProg.ret (a, b) : PProg (QB Lq) Dig _).run G).2 = b := fun _ _ => rfl
  rw [hret]
  generalize hq : (mQ + 3) / 4 = q
  exact trSqueezeVecKeyed_run_key_aux Lq (by omega) key G q _ (by rw [← hq]; unfold mQ; norm_num)

private theorem openingAuditFixedProg_run_key_aux (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (hnQ : 0 < prm.nQ) (depth nClaims rows nGroups : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig) :
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).run G).2.key = key := by
  unfold openingAuditFixedProg
  exact run_andThen_snd_key _ _ G key fun _ =>
    run_andThen_snd_key _ _ G key fun _ =>
      run_andThen_snd_key _ _ G key fun _ =>
        run_andThen_snd_key _ _ G key fun t2 =>
          run_andThen_snd_key_of_ret _ _ G key (fun _ => rfl)
            (trSqueezeVecKeyed_run_key_aux Lq (by omega) key G ((prm.nQ + 3) / 4) t2 (by omega))

theorem stSlotsProveFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (active : Bool) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
      (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false),
    SliceSpec Lq tag key domain shape c
      (stSlotsProveFixedProg Lq hL20 key P elog D b g a m active recs s acc t)
      base (slotsFixedLen P s m) (slotsFixedLen P s m) (slotsFixedLen P s m) (slotsFixedLen P s m) 0 0
      st (trChainAfterVec base st (slotsFixedLen P s m))
      (fun _ => False) (slotsFixedSched P s m base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (trChainAfterVec base st (slotsFixedLen P s m)).trTip)
  | 0, active, recs, s, acc, t, base, st, _, _ =>
    (retSliceSpec (if active then some ([], recs, acc) else none, t) base st
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v st.trTip) (fun _ _ hp => hp)
      (slotsFixedSched P s 0 base st.trTip)).congr
      rfl le_rfl le_rfl le_rfl le_rfl le_rfl
      (by unfold trChainAfterVec slotsFixedLen; rw [dite_eq_left rfl]; exact TrChainState.ext rfl rfl rfl)
      (fun _ h => h) (fun _ _ hp => hp)
      (fun _ _ _ _ hr => by unfold trChainAfterVec slotsFixedLen; rw [dite_eq_left rfl]; exact hr)
  | m + 1, active, recs, s, acc, t, base, st, htip, hnoPos => by
    let len1 := slotFixedLen P s
    let len2 := slotsFixedLen P (s + 1) m
    let st1 := trChainTip base len1 (by unfold len1 slotFixedLen; omega)
    have h1 := slotProveFixedSliceSpec hL20 hsep domain shape c (atLog P (elog s)) (sdAt D (elog s)) s active
      (Exec.Block.histOf b g a recs) acc t base st htip hnoPos
    change SliceSpec Lq tag key domain shape c _ base len1 len1 len1 len1 0 0 st st1 _
      (slotFixedSched P s base st.trTip) _ _ at h1
    have h2 : ∀ r : Option (SlotProof × SlotRec × Acc) × Tr,
        SliceSpec Lq tag key domain shape c
          (match r.1 with
          | none =>
            (stSlotsProveFixedProg Lq hL20 key P elog D b g a m false recs (s + 1) acc r.2).andThen fun rest =>
              .ret (none, rest.2)
          | some (sp, rec_, acc') =>
            (stSlotsProveFixedProg Lq hL20 key P elog D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2).andThen fun rest =>
              match rest.1 with
              | none => .ret (none, rest.2)
              | some (sps, recs', acc'') => .ret (some (sp :: sps, recs', acc''), rest.2))
          (base + len1) len2 len2 len2 len2 0 0 st1 (trChainAfterVec (base + len1) st1 len2)
          (fun _ => False)
          (spliceSched (base + len1 + len2) (slotsFixedSched P (s + 1) m (base + len1) (base + len1 - 1)) (fun _ => .absorb 0))
          (fun _ v => r.2.key = key ∧ r.2.state = v (base + len1 - 1))
          (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) := by
      intro r
      cases hr : r.1 with
      | none =>
        have ih := stSlotsProveFixedSliceSpec hL20 hsep domain shape c P elog D b g a m false recs (s + 1) acc r.2 (base + len1) st1 rfl rfl
        exact (ih.andThen (fun rest => retSliceSpec (none, rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
          (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
          (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp))
          (fun _ hf => False.elim hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega) (TrChainState.ext rfl rfl rfl)
          (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr' => hr')
      | some v1 =>
        rcases v1 with ⟨sp, rec_, acc'⟩
        have ih := stSlotsProveFixedSliceSpec hL20 hsep domain shape c P elog D b g a m true (recs ++ [rec_]) (s + 1) acc' r.2 (base + len1) st1 rfl rfl
        have htail : ∀ rest : Option (List SlotProof × List SlotRec × Acc) × Tr,
            SliceSpec Lq tag key domain shape c
              (match rest.1 with
              | none => .ret (none, rest.2)
              | some (sps, recs', acc'') => .ret (some (sp :: sps, recs', acc''), rest.2))
              (base + len1 + len2) 0 0 0 0 0 0 (trChainAfterVec (base + len1) st1 len2) (trChainAfterVec (base + len1) st1 len2)
              (fun _ => False) (fun _ => .absorb 0)
              (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
              (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) := fun rest => by
          cases rest.1 with
          | none =>
            exact retSliceSpec (none, rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
              (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
              (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp)
          | some v2 =>
            rcases v2 with ⟨sps, recs', acc''⟩
            exact retSliceSpec (some (sp :: sps, recs', acc''), rest.2) (base + len1 + len2) (trChainAfterVec (base + len1) st1 len2)
              (fun _ v => rest.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip)
              (fun _ v res => res.2.state = v (trChainAfterVec (base + len1) st1 len2).trTip) (fun _ _ hp => hp)
        exact (ih.andThen htail (fun _ hf => False.elim hf)).congr
          (by omega) (by omega) (by omega) (by omega) (by omega) (by omega) (TrChainState.ext rfl rfl rfl)
          (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr' => hr')
    have hlen1Pos : 0 < len1 := by unfold len1 slotFixedLen; omega
    have htotEq : slotsFixedLen P s (m + 1) = len1 + len2 := rfl
    have htotNe : slotsFixedLen P s (m + 1) ≠ 0 := by omega
    have htipEq : (trChainAfterVec (base + len1) st1 len2).trTip = (trChainAfterVec base st (slotsFixedLen P s (m + 1))).trTip := by
      unfold trChainAfterVec st1
      rw [dite_eq_right htotNe]
      by_cases h0 : len2 = 0
      · rw [dite_eq_left h0]; exact trChainTip_eq hlen1Pos _ (by omega)
      · rw [dite_eq_right h0]; exact trChainTip_eq _ _ (by omega)
    exact (h1.andThen h2 (fun _ hf => False.elim hf)).congr
      rfl (by omega) (by omega) (by omega) (by omega) (by omega)
      (by
        apply trChainState_heq (by omega)
        · unfold trChainAfterVec trChainTip st1
          rw [dite_eq_right htotNe]
          by_cases h0 : len2 = 0
          · rw [dite_eq_left h0]; rfl
          · rw [dite_eq_right h0]; rfl
        · exact htipEq
        · unfold trChainAfterVec trChainTip st1
          rw [dite_eq_right htotNe]
          by_cases h0 : len2 = 0
          · rw [dite_eq_left h0]; rfl
          · rw [dite_eq_right h0]; rfl)
      (fun _ h => by rcases h with h | h <;> exact h)
      (fun _ _ hp => hp)
      (fun _ _ res _ hr => by rwa [← htipEq])

theorem stSlotsProveFixedSliceSpec_n {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (P : BlockParams) (elog : ℕ → ℕ) (D : SlotData P)
    (beta gamma alpha : Fp2) (m : ℕ) (active : Bool)
    (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
    (base len' : ℕ) (hlen : slotsFixedLen P s m = len') (hpos : 0 < len')
    (st : TrChainState base) (htip : st.hasTip = true) (ha : st.afterPosTag = false)
    (tip : ℕ) (htipEq : st.trTip = tip) :
    SliceSpec Lq tag key domain shape c
      (stSlotsProveFixedProg Lq hL20 key P elog D beta gamma alpha m active recs s acc t)
      base len' len' len' len' 0 0 st (trChainTip base len' hpos)
      (fun _ => False) (slotsFixedSched P s m base tip)
      (fun _ v => t.state = v tip)
      (fun _ v res => res.2.state = v (base + len' - 1)) := by
  subst htipEq
  exact (stSlotsProveFixedSliceSpec hL20 hsep domain shape c P elog D beta gamma alpha m active recs s acc t
    base st htip ha).congr
    hlen (by omega) (by omega) (by omega) le_rfl le_rfl
    (by
      have hne : slotsFixedLen P s m ≠ 0 := by omega
      apply trChainState_heq (by omega)
      · unfold trChainAfterVec; rw [dite_eq_right hne]; rfl
      · unfold trChainAfterVec; rw [dite_eq_right hne]; exact trChainTip_eq _ _ (by omega)
      · unfold trChainAfterVec; rw [dite_eq_right hne]; rfl)
    (fun _ h => h)
    (fun _ _ hp => hp)
    (fun _ _ _ _ hr => by
      have hne : slotsFixedLen P s m ≠ 0 := by omega
      unfold trChainAfterVec at hr
      rw [dite_eq_right hne] at hr
      rw [show (trChainTip base (slotsFixedLen P s m) (Nat.pos_of_ne_zero hne)).trTip = base + len' - 1 from
        congrArg (· - 1) (by omega)] at hr
      exact hr)

theorem slotsProveFixedSliceSpec_n {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (P : BlockParams) (D : SlotData P)
    (beta gamma alpha : Fp2) (m : ℕ) (active : Bool)
    (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr)
    (base len' : ℕ) (hlen : slotsFixedLen P s m = len') (hpos : 0 < len')
    (st : TrChainState base) (htip : st.hasTip = true) (ha : st.afterPosTag = false)
    (tip : ℕ) (htipEq : st.trTip = tip) :
    SliceSpec Lq tag key domain shape c
      (slotsProveFixedProg Lq hL20 key P D beta gamma alpha m active recs s acc t)
      base len' len' len' len' 0 0 st (trChainTip base len' hpos)
      (fun _ => False) (slotsFixedSched P s m base tip)
      (fun _ v => t.state = v tip)
      (fun _ v res => res.2.state = v (base + len' - 1)) := by
  subst htipEq
  exact (slotsProveFixedSliceSpec hL20 hsep domain shape c P D beta gamma alpha m active recs s acc t
    base st htip ha).congr
    hlen (by omega) (by omega) (by omega) le_rfl le_rfl
    (by
      have hne : slotsFixedLen P s m ≠ 0 := by omega
      apply trChainState_heq (by omega)
      · unfold trChainAfterVec; rw [dite_eq_right hne]; rfl
      · unfold trChainAfterVec; rw [dite_eq_right hne]; exact trChainTip_eq _ _ (by omega)
      · unfold trChainAfterVec; rw [dite_eq_right hne]; rfl)
    (fun _ h => h)
    (fun _ _ hp => hp)
    (fun _ _ _ _ hr => by
      have hne : slotsFixedLen P s m ≠ 0 := by omega
      unfold trChainAfterVec at hr
      rw [dite_eq_right hne] at hr
      rw [show (trChainTip base (slotsFixedLen P s m) (Nat.pos_of_ne_zero hne)).trTip = base + len' - 1 from
        congrArg (· - 1) (by omega)] at hr
      exact hr)

end StSlotsFixed

/-! ## 2. Exact static constants, `merkleTableSliceSpec`, audit claim-count & fit helpers -/

section StageConstants

/-- PCS parameters for stages IN-C and OUT-C (`logN = 12`, rate `1/4`, `Q = 256`). -/
def shdP_stgPrm : PcsPrm := ⟨12, 4, 256, 256⟩

/-- PCS parameters for the input token endpoint `TE` (`logN = 8`, rate `1/8`, `Q = 256`). -/
def shdP_epPrm : PcsPrm := ⟨8, 8, 256, 256⟩

/-- OpenGeom for Stage IN-C `A` (`41` rows, `3` groups). -/
def shdP_incOpenGeomA (V : IncV) : OpenGeom :=
  ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩

/-- OpenGeom for Stage IN-C `H` (`76` rows, `4` groups). -/
def shdP_incOpenGeomH (V : IncV) : OpenGeom :=
  ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩

/-- OpenGeom for Stage IN-C `TE` (`6` rows, `1` group, prox `3`). -/
def shdP_epOpenGeom : OpenGeom :=
  ⟨6, [1, 2], none, 3, 1⟩

/-- OpenGeom for Stage OUT-C `A` (`76` rows, `16` groups). -/
def shdP_outcOpenGeomA (V : OutcV) : OpenGeom :=
  ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩

/-- OpenGeom for Stage OUT-C `H` (`38` rows, `5` groups). -/
def shdP_outcOpenGeomH (V : OutcV) : OpenGeom :=
  ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩

/-- Exact relation between `slotsFixedLen` and `RunTrParts.shapeLenW`. -/
theorem slotsFixedLen_eq_shapeLen (P : BlockParams) :
    ∀ (s : ℕ) (sl : List (ℕ × ℕ × ℕ)),
      P.geom.slots.drop s = sl →
      slotsFixedLen P s sl.length = shapeLenW P.draws s sl
  | _, [], _ => rfl
  | s, (nv, ex, dg) :: rest, hdrop => by
    have hget : P.geom.slots[s]? = some (nv, ex, dg) := by
      have := congrArg List.head? hdrop
      simp only [List.head?_drop, List.head?_cons] at this
      exact this
    have hsh : Exec.Block.slotShape P s = (nv, ex, dg) := by
      unfold Exec.Block.slotShape
      rw [List.getD_eq_getElem?_getD, hget]; rfl
    have hdrop' : P.geom.slots.drop (s + 1) = rest := by
      have := congrArg List.tail hdrop
      rw [List.tail_drop] at this
      exact this
    have ih := slotsFixedLen_eq_shapeLen P (s + 1) rest hdrop'
    simp only [List.length_cons]
    unfold slotsFixedLen slotFixedLen slotN shapeLenW
    rw [hsh, ih]

theorem shdP_inc_slotsFixedLen (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (embFold : List Fp2 → List Fp2) (bInRow : ℕ) (cx : IncCtx) :
    slotsFixedLen ((shdP_incV tag Rp embDigest embFold bInRow).bp cx) 0 4 = 167 := by
  have hsame := shdP_hPin (Hdr := Unit) tag Rp embDigest embFold bInRow () cx
  rw [← slotsFixedLen_of_stgSame hsame]
  obtain ⟨hti, hvoc, hep, _, _⟩ := shdP_incPub_logs Rp embDigest embFold
  obtain ⟨_, _, _, hsl⟩ := shdP_incLay_nums Rp embDigest embFold
  have hepc : clog2 (shdP_incPub Rp embDigest embFold).inEpWords = 8 := by rw [hep, shdP_clog2_256]
  have hlen4 : (shdP_P0in tag Rp embDigest embFold bInRow).geom.slots.length = 4 := by
    change (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots.length = 4
    rw [hsl]; rfl
  rw [← hlen4, slotsFixedLen_eq_shapeLen _ 0 _ List.drop_zero]
  change shapeLenW (incDraws (shdP_incPub Rp embDigest embFold)) 0
    (incLay (shdP_incPub Rp embDigest embFold) 14).geomSlots = 167
  rw [hsl]
  simp only [shapeLenW, incDraws, hepc, hti, hvoc]

theorem shdP_outc_slotsFixedLen (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig)
    (bOutRow v : ℕ) :
    slotsFixedLen (shdP_outcV tag Rp wDigest bOutRow v).bp 0 8 = 290 := by
  have hsame := shdP_hPout (Hdr := Unit) tag Rp wDigest bOutRow () v
  rw [← slotsFixedLen_of_stgSame hsame]
  obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
  obtain ⟨_, _, _, hsl⟩ := shdP_outcLay_nums Rp wDigest
  have hlen8 : (shdP_P0out tag Rp wDigest bOutRow).geom.slots.length = 8 := by
    rw [shdP_P0out_slots]; rfl
  rw [← hlen8, slotsFixedLen_eq_shapeLen _ 0 _ List.drop_zero]
  change shapeLenW (outcDraws (rcVerdict (shdP_outcPub Rp wDigest) 0)) 0
    (outcLay (rcVerdict (shdP_outcPub Rp wDigest) 0) 14).geomSlots = 290
  rw [rc_outcDraws_verdict, rc_outcLay_verdict, hsl]
  simp only [shapeLenW, outcDraws, OutcPub.toLog, hdb, hllo, hldo, hltab]

theorem shdP_blk_slotsFixedLen (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    slotsFixedLen (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) 0 23 = 1283 := by
  have hlen23 : (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.length = 23 :=
    shdP_Pk0_slots_length tag ioIn ioOut checkOpening Rp hR k hk
  rw [← hlen23, slotsFixedLen_eq_shapeLen _ 0 _ List.drop_zero]
  rw [shdP_Pk0_draws tag ioIn ioOut checkOpening Rp hR k hk,
      shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk]
  exact r13_shield_counts.1

/-- Static total `.pt` lengths and total `QLE` query counts of the three segment kinds. -/
def incSegFixedLen : ℕ := 205401
def incSegFixedQ : ℕ := 307801
def blkSegFixedLen : ℕ := 412266
def blkSegFixedQ : ℕ := 612970
def outcSegFixedLen : ℕ := 74522
def outcSegFixedQ : ℕ := 111386

/-- **Table-level `merkleTableProg` `SliceSpec` wrapper** around `merkleTreeSliceSpec`:
avoids duplicating `colBytes_length` / `hsalt` rewrites across all 112 Merkle trees. -/
theorem merkleTableSliceSpec {Lq : ℕ} (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (tid : ShdTreeId) (d : ℕ) (hd : shdTreeDepthOf tid = d)
    (rows : ℕ) (hrows : 8 * rows ≤ Lq) (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows)
    (hSalt : ∀ j : Fin (2 ^ d), T.salts j.val = shdLeafSalt c ⟨tid, Fin.cast (by rw [hd]) j⟩)
    (base : ℕ) (st : TrChainState base) (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop) :
    let len := 2 ^ d + (2 ^ d - 1)
    let stOut : TrChainState (base + len) := ⟨st.hasTip, st.trTip,
      fun h => Nat.lt_of_lt_of_le (st.htip_lt h) (Nat.le_add_right base len),
      st.afterPosTag, st.hpos⟩
    SliceSpec Lq tag key domain shape c
      (merkleTableProg Lq h64 tag d rows hrows T hT)
      base len (2 ^ d + 2 ^ d + (2 ^ d - 1)) 0 0 (2 ^ d) (2 ^ d - 1)
      st stOut (fun t => t = tid) (merkleTreeSched tid base) pre
      (fun _ v tr => tr = levelsOfV v d base ∧ tr.getRoot = v (base + len - 1)) := by
  subst hd
  have hsaltEq : (fun j : Fin (2 ^ shdTreeDepthOf tid) => T.salts j.val)
      = (fun j : Fin (2 ^ shdTreeDepthOf tid) => shdLeafSalt c ⟨tid, j⟩) := funext fun j => hSalt j
  unfold merkleTableProg
  rw [hsaltEq]
  exact merkleTreeSliceSpec h64 hsep domain shape c tid base st
    (fun j => colBytes (T.cols j.val))
    (fun j => by rw [colBytes_length, hT j]; exact hrows)
    (fun j => by rw [colBytes_length]; omega) pre

private theorem SliceSpec.andInv {α : Type} {Lq : ℕ} {tag : MTag} {key : Option Dig} {domain shape : List UInt8}
    {c : ShdCoins} {p : PProg (QB Lq) Dig α} {base len nQ nTrK nT nL nN : ℕ}
    {st₀ : TrChainState base} {st₁ : TrChainState (base + len)}
    {trees : ShdTreeId → Prop} {sched : ℕ → RawPtSpec}
    {pre : (QB Lq → Dig) → (ℕ → Dig) → Prop} {post : (QB Lq → Dig) → (ℕ → Dig) → α → Prop}
    (h : SliceSpec Lq tag key domain shape c p base len nQ nTrK nT nL nN st₀ st₁ trees sched pre post)
    (inv : (QB Lq → Dig) → (ℕ → Dig) → Prop) :
    SliceSpec Lq tag key domain shape c p base len nQ nTrK nT nL nN st₀ st₁ trees sched
      (fun H v => pre H v ∧ inv H v) (fun H v a => post H v a ∧ inv H v) :=
  h.congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl rfl (fun _ ht => ht)
    (fun _ _ hp => hp.1) (fun _ _ _ hp hr => ⟨hr, hp.2⟩)

private theorem merkleTableSliceSpec_tree {Lq : ℕ} (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (tid : ShdTreeId) (d : ℕ) (hd : shdTreeDepthOf tid = d)
    (rows : ℕ) (hrows : 8 * rows ≤ Lq) (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows)
    (hSalt : ∀ j : Fin (2 ^ d), T.salts j.val = shdLeafSalt c ⟨tid, Fin.cast (by rw [hd]) j⟩)
    (base len' q' l' n' : ℕ)
    (hlen : 2 ^ d + (2 ^ d - 1) = len') (hq : 2 ^ d + 2 ^ d + (2 ^ d - 1) = q')
    (hl : 2 ^ d = l') (hn : 2 ^ d - 1 = n')
    (st : TrChainState base) (stOut : TrChainState (base + len'))
    (hst : stOut.hasTip = st.hasTip ∧ stOut.trTip = st.trTip ∧ stOut.afterPosTag = st.afterPosTag)
    (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop) :
    SliceSpec Lq tag key domain shape c
      (merkleTableProg Lq h64 tag d rows hrows T hT)
      base len' q' 0 0 l' n' st stOut (fun t => t = tid) (merkleTreeSched tid base) pre
      (fun G v tr => pre G v ∧ tr = levelsOfV v d base) :=
  (merkleTableSliceSpec h64 hsep domain shape c tid d hd rows hrows T hT hSalt base st pre).congr
    hlen (by omega) le_rfl le_rfl (by omega) (by omega)
    (trChainState_heq (by omega) hst.1.symm hst.2.1.symm hst.2.2.symm)
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ hp hr => ⟨hp, hr.1⟩)

private theorem merkleTableSliceSpec_keep {Lq : ℕ} (h64 : 64 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8)
    (c : ShdCoins) (tid : ShdTreeId) (d : ℕ) (hd : shdTreeDepthOf tid = d)
    (rows : ℕ) (hrows : 8 * rows ≤ Lq) (T : Table) (hT : ∀ j : Fin (2 ^ d), (T.cols j.val).length = rows)
    (hSalt : ∀ j : Fin (2 ^ d), T.salts j.val = shdLeafSalt c ⟨tid, Fin.cast (by rw [hd]) j⟩)
    (base len' q' l' n' : ℕ)
    (hlen : 2 ^ d + (2 ^ d - 1) = len') (hq : 2 ^ d + 2 ^ d + (2 ^ d - 1) = q')
    (hl : 2 ^ d = l') (hn : 2 ^ d - 1 = n')
    (st : TrChainState base) (stOut : TrChainState (base + len'))
    (hst : stOut.hasTip = st.hasTip ∧ stOut.trTip = st.trTip ∧ stOut.afterPosTag = st.afterPosTag)
    (pre : (QB Lq → Dig) → (ℕ → Dig) → Prop) :
    SliceSpec Lq tag key domain shape c
      (merkleTableProg Lq h64 tag d rows hrows T hT)
      base len' q' 0 0 l' n' st stOut (fun t => t = tid) (merkleTreeSched tid base) pre
      (fun G v _ => pre G v) :=
  (merkleTableSliceSpec h64 hsep domain shape c tid d hd rows hrows T hT hSalt base st pre).congr
    hlen (by omega) le_rfl le_rfl (by omega) (by omega)
    (trChainState_heq (by omega) hst.1.symm hst.2.1.symm hst.2.2.symm)
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ hp _ => hp)

private theorem trChallengeFp2VecSliceSpec_n {Lq : ℕ} (h47 : 47 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (n : ℕ) (hn : 0 < n) (t : Tr) (base : ℕ) (st : TrChainState base)
    (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (trChallengeFp2VecKeyed Lq h47 key n t)
      base n n n n 0 0 st (trChainTip base n hn)
      (fun _ => False) (squeezeVecSched base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.1 = (List.range n).map (fun k => challengeFp2Of (v (base + k)))
        ∧ res.2.state = v (base + n - 1)) := by
  have hne : n ≠ 0 := by omega
  exact (trChallengeFp2VecSliceSpec h47 hsep domain shape c n t base st htip hnoPos).congr
    rfl le_rfl le_rfl le_rfl le_rfl le_rfl
    (by unfold trChainAfterVec; rw [dite_eq_right hne]; exact TrChainState.ext rfl rfl rfl)
    (fun _ h => h) (fun _ _ hp => hp)
    (fun _ _ _ _ hr => by unfold trChainAfterVec at hr; rw [dite_eq_right hne] at hr; exact hr)

private theorem zkBMaskFixedSliceSpec_n {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (active : Bool) (M : MTable) (S : ℕ) (tree : MerkleLevels 12) (fs : List Exec.Block.MaskFunctional) (t : Tr)
    (base len' : ℕ) (hlen : zkBMaskFixedLen S = len') (hpos : 0 < len')
    (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (zkBMaskFixedProg Lq hL20 key U hbij active M S tree fs t)
      base len' len' len' len' 0 0 st (trChainTip base len' hpos)
      (fun _ => False) (zkBMaskFixedSched S base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + len' - 1)) :=
  (zkBMaskFixedSliceSpec hL20 hsep domain shape c U hbij active M S tree fs t base st htip hnoPos).congr
    hlen (by omega) (by omega) (by omega) le_rfl le_rfl
    (trChainState_heq (by omega) rfl (by dsimp only [trChainTip]; omega) rfl)
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ hr => by rwa [← hlen])

private theorem openingAuditFixedSliceSpec_n {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) {tag : MTag} {key : Option Dig}
    (hsep : KeySep tag key) (domain shape : List UInt8) (c : ShdCoins)
    (prm : PcsPrm) (depth nClaims rows nGroups : ℕ) (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr)
    (base len' : ℕ) (hlen : openingAuditFixedLen nClaims rows nGroups prm.nQ = len') (hpos : 0 < len')
    (st : TrChainState base) (htip : st.hasTip = true) (hnoPos : st.afterPosTag = false) :
    SliceSpec Lq tag key domain shape c
      (openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t)
      base len' len' len' len' 0 0 st (trChainTip base len' hpos)
      (fun _ => False) (openingAuditFixedSched nClaims rows nGroups prm.nQ base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + len' - 1)) :=
  (openingAuditFixedSliceSpec hL20 hsep domain shape c prm depth nClaims rows nGroups g T tree active hdrOk cl t base st htip hnoPos).congr
    hlen (by omega) (by omega) (by omega) le_rfl le_rfl
    (trChainState_heq (by omega) rfl (by dsimp only [trChainTip]; omega) rfl)
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ hr => by rwa [← hlen])

/-! ### Audit claim-count lemmas (`openingGroupsAt_sum_eq_length`, `auditClaims_length_*`) -/

private theorem bumpKey_sum (key : List Fp2 × ℕ × ℕ) :
    ∀ gs : List ((List Fp2 × ℕ × ℕ) × ℕ),
      ((bumpKey key gs).map Prod.snd).sum = (gs.map Prod.snd).sum + 1
  | [] => rfl
  | (k, c) :: rest => by
    unfold bumpKey
    by_cases h : k = key
    · rw [ite_eq_left h]; simp only [List.map_cons, List.sum_cons]; omega
    · rw [ite_eq_right h]; simp only [List.map_cons, List.sum_cons, bumpKey_sum key rest]; omega

private theorem openingGroupsAt_foldl_sum (logN : ℕ) :
    ∀ (cl : List Exec.Block.ZClaim) (gs og : List ((List Fp2 × ℕ × ℕ) × ℕ)),
      cl.foldlM (m := Except String) (fun acc c =>
        let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
        if c.parts.any (fun p => partKeyAt p logN ≠ key) then
          throw "private block: claim parts with different column weights"
        else pure (bumpKey key acc)) gs = .ok og →
      (og.map Prod.snd).sum = (gs.map Prod.snd).sum + cl.length
  | [], gs, og, h => by
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h; simp
  | c :: cs, gs, og, h => by
    rw [List.foldlM_cons] at h; dsimp only at h
    split_ifs at h
    · simp [throw, throwThe, MonadExceptOf.throw, Bind.bind, Except.bind] at h
    · simp only [pure, Except.pure, Bind.bind, Except.bind] at h
      have ih := openingGroupsAt_foldl_sum logN cs (bumpKey _ gs) og h
      rw [ih, bumpKey_sum]; simp only [List.length_cons]; omega

/-- For any accepted `openingGroupsAt cl logN = .ok og`, the sum of group sizes equals `cl.length`. -/
theorem openingGroupsAt_sum_eq_length (cl : List Exec.Block.ZClaim) (logN : ℕ)
    (og : List ((List Fp2 × ℕ × ℕ) × ℕ)) (h : openingGroupsAt cl logN = .ok og) :
    (og.map Prod.snd).sum = cl.length := by
  have hs := openingGroupsAt_foldl_sum logN cl [] og h
  simpa using hs

private theorem incAt_sum_and_len (uses : List ℕ) (r : ℕ) :
    (incAt uses r).length = uses.length
      ∧ (incAt uses r).sum = uses.sum + if r < uses.length then 1 else 0 := by
  induction uses generalizing r with
  | nil => simp [incAt]
  | cons u us ih =>
    cases r with
    | zero => simp [incAt]; omega
    | succ r' =>
      obtain ⟨hl, hs⟩ := ih r'
      simp only [incAt, List.length_cons, List.sum_cons, hl, hs]
      refine ⟨trivial, ?_⟩
      by_cases hlt : r' < us.length
      · rw [ite_eq_left hlt, ite_eq_left (Nat.succ_lt_succ hlt)]; omega
      · rw [ite_eq_right hlt, ite_eq_right (by omega : ¬ r' + 1 < us.length + 1)]; omega

private theorem foldl_incAt_sum_le (ts : List ℕ) :
    ∀ uses : List ℕ, (ts.foldl incAt uses).length = uses.length
      ∧ (ts.foldl incAt uses).sum ≤ uses.sum + ts.length := by
  intro uses
  induction ts generalizing uses with
  | nil => exact ⟨rfl, by simp⟩
  | cons r rs ih =>
    simp only [List.foldl_cons, List.length_cons]
    obtain ⟨hl1, hs1⟩ := incAt_sum_and_len uses r
    obtain ⟨hl2, hs2⟩ := ih (incAt uses r)
    refine ⟨hl2.trans hl1, ?_⟩
    split_ifs at hs1 <;> omega

private theorem foldl_incAt_sum_exact (rows : ℕ) (ts : List ℕ) (hts : ∀ r ∈ ts, r < rows) :
    ∀ uses : List ℕ, uses.length = rows →
      (ts.foldl incAt uses).length = rows ∧ (ts.foldl incAt uses).sum = uses.sum + ts.length
  | uses, hlen => by
    induction ts generalizing uses with
    | nil => exact ⟨hlen, by simp⟩
    | cons r rs ih =>
      simp only [List.foldl_cons, List.length_cons]
      obtain ⟨hl1, hs1⟩ := incAt_sum_and_len uses r
      have hr : r < uses.length := by rw [hlen]; exact hts r List.mem_cons_self
      rw [ite_eq_left hr] at hs1
      obtain ⟨hl2, hs2⟩ := ih (fun x hx => hts x (List.mem_cons_of_mem r hx)) (incAt uses r) (hl1.trans hlen)
      exact ⟨hl2, by omega⟩

private theorem claimTouched_foldlM_subset (n prox : ℕ) (siteRows : List ℕ) :
    ∀ (ps : List Exec.Block.ZPart) (acc ts : List ℕ),
      (∀ r ∈ acc, r ∈ siteRows) →
      ps.foldlM (m := Except String) (fun acc p => do
        if partHi p n > prox then
          throw "private block: mask schedule audit: a claim reaches the proximity pair or leaves the commitment"
        let rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
        if !rs.isEmpty && p.coef.isZero then
          throw "private block: mask schedule audit: zero terminal mask coefficient; discard attempt"
        pure (acc ++ rs)) acc = .ok ts →
      ∀ r ∈ ts, r ∈ siteRows
  | [], acc, ts, hacc, h => by
    simp only [List.foldlM_nil, pure, Except.pure, Except.ok.injEq] at h
    subst h; exact hacc
  | p :: ps, acc, ts, hacc, h => by
    rw [List.foldlM_cons] at h; dsimp only at h
    by_cases h1 : partHi p n > prox
    · rw [ite_eq_left h1] at h; simp [throw, throwThe, MonadExceptOf.throw, Bind.bind, Except.bind] at h
    · rw [ite_eq_right h1] at h; simp only [pure, Except.pure, Bind.bind, Except.bind] at h
      let rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
      by_cases h2 : (!rs.isEmpty && p.coef.isZero) = true
      · change (if (!rs.isEmpty && p.coef.isZero) = true then _ else _) >>= _ = Except.ok ts at h
        rw [ite_eq_left h2] at h; simp [throw, throwThe, MonadExceptOf.throw, Bind.bind, Except.bind] at h
      · change (if (!rs.isEmpty && p.coef.isZero) = true then _ else _) >>= _ = Except.ok ts at h
        rw [ite_eq_right h2] at h; simp only [pure, Except.pure, Bind.bind, Except.bind] at h
        refine claimTouched_foldlM_subset n prox siteRows ps (acc ++ rs) ts ?_ h
        intro r hr
        rcases List.mem_append.mp hr with ha | hb
        · exact hacc r ha
        · exact of_decide_eq_true (List.mem_filter.mp hb).2

private theorem claimTouched_subset_siteRows (n prox : ℕ) (siteRows : List ℕ)
    (c : Exec.Block.ZClaim) (ts : List ℕ) (h : claimTouched n prox siteRows c = .ok ts) :
    ∀ r ∈ ts, r ∈ siteRows :=
  claimTouched_foldlM_subset n prox siteRows c.parts [] ts (fun _ hr => by cases hr) h

private theorem claimTouched_lt_rows (n rows prox : ℕ) (siteRows : List ℕ)
    (hsr : ∀ r ∈ siteRows, r < rows) (c : Exec.Block.ZClaim) (ts : List ℕ)
    (h : claimTouched n prox siteRows c = .ok ts) :
    ∀ r ∈ ts, r < rows :=
  fun r hr => hsr r (claimTouched_subset_siteRows n prox siteRows c ts h r hr)

private theorem auditOne_sum_exact (n rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (hsr : ∀ r ∈ siteRows, r < rows) (nClaims ci : ℕ) (c : Exec.Block.ZClaim) (uses u' : List ℕ)
    (hlen : uses.length = rows)
    (h : auditOne n rows prox siteRows sumRows nClaims ci c uses = .ok u') :
    u'.length = rows
      ∧ u'.sum = uses.sum + (if c.parts.all (fun p => p.point.isEmpty) = true then 0 else 2)
      ∧ (c.parts.all (fun p => p.point.isEmpty) = true → sumRows.isSome = true ∧ ci + 1 = nClaims) := by
  unfold auditOne at h
  cases hct : claimTouched n prox siteRows c with
  | error e => simp [hct, Bind.bind, Except.bind] at h
  | ok ts =>
    simp only [hct, Bind.bind, Except.bind] at h
    have htsLt := claimTouched_lt_rows n rows prox siteRows hsr c ts hct
    cases his : c.parts.all (fun p => p.point.isEmpty) with
    | true =>
      cases hsrOpt : sumRows with
      | none => simp [his, hsrOpt, auditFail, Bind.bind, Except.bind] at h
      | some p =>
        rcases p with ⟨u0, u1⟩
        simp only [his, hsrOpt] at h
        by_cases hci : ci + 1 = nClaims
        · rw [ite_eq_left hci] at h
          by_cases hbad1 : (!ts.isEmpty ||
              !c.parts.any (fun p => decide (partLo p n ≤ u0 ∧ u0 < partHi p n) && !p.coef.isZero) ||
              !c.parts.any (fun p => decide (partLo p n ≤ u1 ∧ u1 < partHi p n) && !p.coef.isZero)) = true
          · rw [ite_eq_left hbad1] at h
            simp [auditFail, Bind.bind, Except.bind] at h
          · rw [ite_eq_right hbad1] at h
            simp only [pure, Except.pure, Bind.bind, Except.bind] at h
            by_cases hdet : (Exec.Block.det (claimWeight (Nat.log2 n) c u0) (claimWeight (Nat.log2 n) c u1)).v = 0
            · rw [ite_eq_left hdet] at h
              simp [auditFail, Bind.bind, Except.bind] at h
            · rw [ite_eq_right hdet] at h
              simp only [pure, Except.pure, Bind.bind, Except.bind, Except.ok.injEq] at h
              subst h
              have hemp : ts = [] := by
                cases ts with
                | nil => rfl
                | cons _ _ => simp at hbad1
              subst hemp
              exact ⟨hlen, by simp, fun _ => ⟨rfl, hci⟩⟩
        · rw [ite_eq_right hci] at h; simp [auditFail, Bind.bind, Except.bind] at h
    | false =>
      simp only [his] at h
      by_cases hbad : ts.length ≠ 2 ∨ ts.getD 1 0 ≠ ts.getD 0 0 + 1 ∨ (ts.getD 0 0 - siteRows.getD 0 0) % 2 ≠ 0
      · rw [ite_eq_left hbad] at h; simp [auditFail, Bind.bind, Except.bind] at h
      · rw [ite_eq_right hbad] at h; simp only [pure, Except.pure, Bind.bind, Except.bind] at h
        by_cases hdet : (Exec.Block.det (claimWeight (Nat.log2 n) c (ts.getD 0 0))
            (claimWeight (Nat.log2 n) c (ts.getD 1 0))).v = 0
        · rw [ite_eq_left hdet] at h; simp [auditFail, Bind.bind, Except.bind] at h
        · rw [ite_eq_right hdet] at h; simp only [pure, Except.pure, Bind.bind, Except.bind, Except.ok.injEq] at h
          subst h
          have htlen2 : ts.length = 2 := by
            by_contra hne; exact hbad (Or.inl hne)
          obtain ⟨hl', hs'⟩ := foldl_incAt_sum_exact rows ts htsLt uses hlen
          exact ⟨hl', by rw [hs', htlen2]; rfl, fun hf => by cases hf⟩

private theorem auditLoop_sum_none (n rows prox : ℕ) (siteRows : List ℕ)
    (hsr : ∀ r ∈ siteRows, r < rows) (nClaims : ℕ) :
    ∀ (ci : ℕ) (cl : List Exec.Block.ZClaim) (uses u' : List ℕ),
      uses.length = rows →
      auditLoop n rows prox siteRows none nClaims ci cl uses = .ok u' →
      u'.length = rows ∧ u'.sum = uses.sum + 2 * cl.length
  | _, [], uses, u', hlen, h => by
    simp only [auditLoop, Except.ok.injEq] at h; subst h; exact ⟨hlen, by simp⟩
  | ci, c :: cs, uses, u', hlen, h => by
    unfold auditLoop at h
    cases h1 : auditOne n rows prox siteRows none nClaims ci c uses with
    | error e => simp [h1, Bind.bind, Except.bind] at h
    | ok u1 =>
      simp only [h1, Bind.bind, Except.bind] at h
      obtain ⟨hl1, hs1, hsum1⟩ := auditOne_sum_exact n rows prox siteRows none hsr nClaims ci c uses u1 hlen h1
      have hff : c.parts.all (fun p => p.point.isEmpty) = false := by
        cases hc : c.parts.all (fun p => p.point.isEmpty) with
        | false => rfl
        | true => have := (hsum1 hc).1; cases this
      rw [hff] at hs1; simp only [Bool.false_eq_true, ↓reduceIte] at hs1
      obtain ⟨hl2, hs2⟩ := auditLoop_sum_none n rows prox siteRows hsr nClaims (ci + 1) cs u1 u' hl1 h
      exact ⟨hl2, by simp only [List.length_cons]; omega⟩

private theorem auditLoop_sum_some (n rows prox : ℕ) (siteRows : List ℕ) (u0 u1 : ℕ)
    (hsr : ∀ r ∈ siteRows, r < rows) (nClaims : ℕ) :
    ∀ (ci : ℕ) (cl : List Exec.Block.ZClaim) (uses u' : List ℕ),
      ci + cl.length = nClaims →
      uses.length = rows →
      auditLoop n rows prox siteRows (some (u0, u1)) nClaims ci cl uses = .ok u' →
      u'.length = rows
        ∧ match cl.getLast? with
          | none => u'.sum = uses.sum
          | some last =>
            u'.sum = uses.sum + 2 * (cl.length - 1) + if last.parts.all (fun p => p.point.isEmpty) then 0 else 2
  | _, [], uses, u', _, hlen, h => by
    simp only [auditLoop, Except.ok.injEq] at h; subst h; exact ⟨hlen, rfl⟩
  | ci, [c], uses, u', hci, hlen, h => by
    unfold auditLoop at h
    cases h1 : auditOne n rows prox siteRows (some (u0, u1)) nClaims ci c uses with
    | error e => simp [h1, Bind.bind, Except.bind] at h
    | ok uMid =>
      simp only [h1, Bind.bind, Except.bind, auditLoop, Except.ok.injEq] at h
      subst h
      obtain ⟨hl1, hs1, _⟩ := auditOne_sum_exact n rows prox siteRows (some (u0, u1)) hsr nClaims ci c uses uMid hlen h1
      exact ⟨hl1, by simpa using hs1⟩
  | ci, c :: c2 :: cs, uses, u', hci, hlen, h => by
    unfold auditLoop at h
    cases h1 : auditOne n rows prox siteRows (some (u0, u1)) nClaims ci c uses with
    | error e => simp [h1, Bind.bind, Except.bind] at h
    | ok uMid =>
      simp only [h1, Bind.bind, Except.bind] at h
      obtain ⟨hl1, hs1, hsum1⟩ := auditOne_sum_exact n rows prox siteRows (some (u0, u1)) hsr nClaims ci c uses uMid hlen h1
      have hff : c.parts.all (fun p => p.point.isEmpty) = false := by
        cases hc : c.parts.all (fun p => p.point.isEmpty) with
        | false => rfl
        | true =>
          have hlast := (hsum1 hc).2
          simp only [List.length_cons] at hci; omega
      rw [hff] at hs1; simp only [Bool.false_eq_true, ↓reduceIte] at hs1
      obtain ⟨hl2, hs2⟩ := auditLoop_sum_some n rows prox siteRows u0 u1 hsr nClaims (ci + 1) (c2 :: cs) uMid u'
        (by simp only [List.length_cons] at hci ⊢; omega) hl1 h
      refine ⟨hl2, ?_⟩
      have hgl : (c :: c2 :: cs).getLast? = (c2 :: cs).getLast? := rfl
      rw [hgl]
      cases hlast : (c2 :: cs).getLast? with
      | none => simp at hlast
      | some last =>
        rw [hlast] at hs2
        simp only [List.length_cons] at hs2 ⊢
        omega

private theorem list_sum_ge_range' (u : List ℕ) (base len : ℕ) (hle : base + len ≤ u.length)
    (h1 : ∀ r ∈ List.range' base len, u.getD r 0 = 1) :
    len ≤ u.sum := by
  have htake : (u.drop base).take len = List.replicate len 1 := by
    refine List.ext_getElem (by simp [List.length_take, List.length_drop]; omega) fun i hi1 hi2 => ?_
    rw [List.getElem_take, List.getElem_drop, List.getElem_replicate]
    have hmem : base + i ∈ List.range' base len := by rw [range'_mem_iff]; simp at hi2; omega
    have hget := h1 (base + i) hmem
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem (by simp at hi2; omega)] at hget
    exact hget
  have hsum_drop : (u.drop base).sum ≤ u.sum := by
    conv_rhs => rw [← List.take_append_drop base u]
    rw [List.sum_append]; omega
  have hsum_take : ((u.drop base).take len).sum ≤ (u.drop base).sum := by
    conv_rhs => rw [← List.take_append_drop len (u.drop base)]
    rw [List.sum_append]; omega
  rw [htake, List.sum_replicate, smul_eq_mul, mul_one] at hsum_take
  omega

private theorem auditLoop_only_siteRows (n rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ)) (nClaims : ℕ) :
    ∀ (ci : ℕ) (cl : List Exec.Block.ZClaim) (uses u' : List ℕ),
      (∀ r, r ∉ siteRows → uses.getD r 0 = 0) →
      auditLoop n rows prox siteRows sumRows nClaims ci cl uses = .ok u' →
      ∀ r, r ∉ siteRows → u'.getD r 0 = 0
  | _, [], uses, u', hz, h => by simp only [auditLoop, Except.ok.injEq] at h; subst h; exact hz
  | ci, c :: cs, uses, u', hz, h => by
    unfold auditLoop at h
    cases h1 : auditOne n rows prox siteRows sumRows nClaims ci c uses with
    | error e => simp [h1, Bind.bind, Except.bind] at h
    | ok uMid =>
      simp only [h1, Bind.bind, Except.bind] at h
      have hinc_ne : ∀ (l : List ℕ) (i j : ℕ), i ≠ j → (incAt l j).getD i 0 = l.getD i 0 := by
        intro l; induction l with
        | nil => intro _ _ _; rfl
        | cons a tl ih =>
          intro i j hij
          cases i with
          | zero => cases j with | zero => exact absurd rfl hij | succ j' => rfl
          | succ i' => cases j with | zero => rfl | succ j' => exact ih i' j' (by omega)
      have hfold_ne : ∀ (ts : List ℕ) (l : List ℕ) (r : ℕ), r ∉ ts → (ts.foldl incAt l).getD r 0 = l.getD r 0 := by
        intro ts; induction ts with
        | nil => intro _ _ _; rfl
        | cons t ts ih =>
          intro l r hr
          rw [List.foldl_cons, ih _ r (fun hm => hr (List.mem_cons_of_mem t hm)),
            hinc_ne l r t (fun heq => hr (heq ▸ List.mem_cons_self))]
      have hzMid : ∀ r, r ∉ siteRows → uMid.getD r 0 = 0 := by
        unfold auditOne at h1
        cases hct : claimTouched n prox siteRows c with
        | error e => simp [hct, Bind.bind, Except.bind] at h1
        | ok ts =>
          simp only [hct, Bind.bind, Except.bind] at h1
          have htsSub : ∀ r ∈ ts, r ∈ siteRows :=
            claimTouched_subset_siteRows n prox siteRows c ts hct
          have huEq : uMid = ts.foldl incAt uses := by
            cases hc : c.parts.all (fun p => p.point.isEmpty) with
            | true =>
              cases hs : sumRows with
              | none => simp [hc, hs, auditFail, Bind.bind, Except.bind] at h1
              | some p =>
                rcases p with ⟨u0, u1⟩
                simp only [hc, hs] at h1
                split_ifs at h1
                all_goals try (simp [auditFail, pure, Except.pure, Bind.bind, Except.bind] at h1; done)
                all_goals (simp only [pure, Except.pure, Bind.bind, Except.bind, Except.ok.injEq] at h1; exact h1.symm)
            | false =>
              simp only [hc] at h1
              split_ifs at h1
              all_goals try (simp [auditFail, pure, Except.pure, Bind.bind, Except.bind] at h1; done)
              all_goals (simp only [pure, Except.pure, Bind.bind, Except.bind, Except.ok.injEq] at h1; exact h1.symm)
          intro r hr
          rw [huEq, hfold_ne ts uses r (fun hm => hr (htsSub r hm)), hz r hr]
      exact auditLoop_only_siteRows n rows prox siteRows sumRows nClaims (ci + 1) cs uMid u' hzMid h

private theorem list_sum_eq_range' (u : List ℕ) (base len : ℕ) (hle : base + len ≤ u.length)
    (h1 : ∀ r ∈ List.range' base len, u.getD r 0 = 1)
    (h0 : ∀ r, r ∉ List.range' base len → u.getD r 0 = 0) :
    u.sum = len := by
  have hsum_all : u.sum = ∑ i : Fin u.length, u.getD i.val 0 := by
    have h1' : u = List.ofFn (fun i : Fin u.length => u.getD i.val 0) := by
      refine List.ext_getElem (by simp) fun i hi _ => ?_
      rw [List.getElem_ofFn, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hi]; rfl
    conv_lhs => rw [h1']
    rw [List.sum_ofFn]
  rw [hsum_all]
  have hval : ∀ i : Fin u.length, u.getD i.val 0 = if i.val ∈ List.range' base len then 1 else 0 := fun i => by
    by_cases hm : i.val ∈ List.range' base len
    · rw [ite_eq_left hm]; exact h1 i.val hm
    · rw [ite_eq_right hm]; exact h0 i.val hm
  simp_rw [hval, Finset.sum_boole, Nat.cast_id]
  conv_rhs => rw [← Finset.card_range len]
  refine Finset.card_bij (fun (i : Fin u.length) _ => i.val - base) ?_ ?_ ?_
  · intro i hi
    have hm := (Finset.mem_filter.mp hi).2
    rw [range'_mem_iff] at hm; exact Finset.mem_range.mpr (by omega)
  · intro i₁ hi₁ i₂ hi₂ heq
    have h1' := range'_mem_iff base len i₁.val |>.mp (Finset.mem_filter.mp hi₁).2
    have h2' := range'_mem_iff base len i₂.val |>.mp (Finset.mem_filter.mp hi₂).2
    exact Fin.ext (by omega)
  · intro k hk
    have hk' := Finset.mem_range.mp hk
    refine ⟨⟨base + k, by omega⟩,
      Finset.mem_filter.mpr ⟨Finset.mem_univ _, (range'_mem_iff base len (base + k)).mpr ⟨by omega, by omega⟩⟩,
      Nat.add_sub_cancel_left base k⟩

/-- **Exact claim-count theorem for `sumRows = none`** (`A` and `B` tables):
if `siteRows = List.range' base (2 * m)` with `base + 2 * m ≤ rows`, any accepted `auditClaims`
forces `cl.length = m`! -/
theorem auditClaims_length_none (cl : List Exec.Block.ZClaim) (n rows base m prox : ℕ)
    (hle : base + 2 * m ≤ rows)
    (h : auditClaims cl n rows (List.range' base (2 * m)) none prox = .ok ()) :
    cl.length = m := by
  unfold auditClaims at h
  by_cases h1 : prox + 2 ≠ rows ∨ (List.range' base (2 * m)).length % 2 ≠ 0
  · rw [ite_eq_left h1] at h
    simp [auditFail, Bind.bind, Except.bind] at h
  · rw [ite_eq_right h1] at h
    simp only [pure, Except.pure, Bind.bind, Except.bind] at h
    cases hp : isPow2 n with
    | false => simp [hp, auditFail, Bind.bind, Except.bind] at h
    | true =>
      simp only [hp, Bool.not_true, Bool.false_eq_true, ↓reduceIte, pure, Except.pure, Bind.bind, Except.bind] at h
      cases hal : auditLoop n rows prox (List.range' base (2 * m)) none cl.length 0 cl (List.replicate rows 0) with
      | error e => simp [hal] at h
      | ok uses =>
        simp only [hal] at h
        by_cases hany : (List.range' base (2 * m)).any (fun r => decide (uses.getD r 0 ≠ 1)) = true
        · rw [ite_eq_left hany] at h; simp [auditFail] at h
        · have hsrLt : ∀ r ∈ List.range' base (2 * m), r < rows := fun r hr => by
            rw [range'_mem_iff] at hr; omega
          obtain ⟨hulen, husum⟩ := auditLoop_sum_none n rows prox (List.range' base (2 * m)) hsrLt cl.length 0 cl
            (List.replicate rows 0) uses (List.length_replicate) hal
          have hrep0 : (List.replicate rows 0).sum = 0 := by simp
          rw [hrep0, Nat.zero_add] at husum
          have h0 : ∀ r, r ∉ List.range' base (2 * m) → uses.getD r 0 = 0 :=
            auditLoop_only_siteRows n rows prox (List.range' base (2 * m)) none cl.length 0 cl
              (List.replicate rows 0) uses (fun r _ => by
                rw [List.getD_eq_getElem?_getD, List.getElem?_replicate]; split_ifs <;> rfl) hal
          have hall1 : ∀ r ∈ List.range' base (2 * m), uses.getD r 0 = 1 := fun r hr => by
            by_contra hne
            have : (List.range' base (2 * m)).any (fun r => decide (uses.getD r 0 ≠ 1)) = true :=
              List.any_eq_true.mpr ⟨r, hr, decide_eq_true hne⟩
            exact hany this
          have hsumEq := list_sum_eq_range' uses base (2 * m) (by omega) hall1 h0
          omega

/-- **Exact claim-count theorem for `sumRows = some (u0, u1)` with trailing empty-point sum claim**
(`H` tables): forces `(cl0 ++ [sumCl]).length = m + 1`! -/
theorem auditClaims_length_some_last (cl0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsum : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (n rows base m u0 u1 prox : ℕ) (hle : base + 2 * m ≤ rows)
    (h : auditClaims (cl0 ++ [sumCl]) n rows (List.range' base (2 * m)) (some (u0, u1)) prox = .ok ()) :
    (cl0 ++ [sumCl]).length = m + 1 := by
  unfold auditClaims at h
  by_cases h1 : prox + 2 ≠ rows ∨ (List.range' base (2 * m)).length % 2 ≠ 0
  · rw [ite_eq_left h1] at h
    simp [auditFail, Bind.bind, Except.bind] at h
  · rw [ite_eq_right h1] at h
    simp only [pure, Except.pure, Bind.bind, Except.bind] at h
    cases hp : isPow2 n with
    | false => simp [hp, auditFail, Bind.bind, Except.bind] at h
    | true =>
      simp only [hp, Bool.not_true, Bool.false_eq_true, ↓reduceIte, pure, Except.pure, Bind.bind, Except.bind] at h
      cases hal : auditLoop n rows prox (List.range' base (2 * m)) (some (u0, u1)) (cl0 ++ [sumCl]).length 0
          (cl0 ++ [sumCl]) (List.replicate rows 0) with
      | error e => rw [hal] at h; cases h
      | ok uses =>
        simp only [hal] at h
        by_cases hany : (List.range' base (2 * m)).any (fun r => decide (uses.getD r 0 ≠ 1)) = true
        · rw [ite_eq_left hany] at h; simp [auditFail] at h
        · have hsrLt : ∀ r ∈ List.range' base (2 * m), r < rows := fun r hr => by
            rw [range'_mem_iff] at hr; omega
          obtain ⟨hulen, husum⟩ := auditLoop_sum_some n rows prox (List.range' base (2 * m)) u0 u1 hsrLt
            (cl0 ++ [sumCl]).length 0 (cl0 ++ [sumCl]) (List.replicate rows 0) uses (Nat.zero_add _)
            List.length_replicate hal
          rw [List.getLast?_append_of_ne_nil _ (List.cons_ne_nil _ _)] at husum
          simp only [List.getLast?_singleton, hsum, ↓reduceIte, List.sum_replicate, smul_eq_mul, mul_zero,
            Nat.zero_add, Nat.add_zero] at husum
          have h0 : ∀ r, r ∉ List.range' base (2 * m) → uses.getD r 0 = 0 :=
            auditLoop_only_siteRows n rows prox (List.range' base (2 * m)) (some (u0, u1)) (cl0 ++ [sumCl]).length
              0 (cl0 ++ [sumCl]) (List.replicate rows 0) uses (fun r _ => by
                rw [List.getD_eq_getElem?_getD, List.getElem?_replicate]; split_ifs <;> rfl) hal
          have hall1 : ∀ r ∈ List.range' base (2 * m), uses.getD r 0 = 1 := fun r hr => by
            by_contra hne
            have : (List.range' base (2 * m)).any (fun r => decide (uses.getD r 0 ≠ 1)) = true :=
              List.any_eq_true.mpr ⟨r, hr, decide_eq_true hne⟩
            exact hany this
          have hsumEq := list_sum_eq_range' uses base (2 * m) (by omega) hall1 h0
          simp only [List.length_append, List.length_singleton] at husum ⊢
          omega

/-! ### Sumcheck / Mask / PCS message-length fit helpers (`≤ 2^20 ≤ Lq`) -/

private theorem scProve_honestW_len (H : HIn → Dig) (d : ℕ) :
    ∀ (n : ℕ) (f : (Fin n → shdP_K) → shdP_K) (t : Tr) (r_list : List Fp2),
      r_list ∈ (scProve H n (honestW shdP_U shdP_hbij d n f) t).1 → r_list.length = d + 1
  | 0, _, _, _, hr => by simp [scProve] at hr
  | n + 1, f, t, r_list, hr => by
    simp only [scProve, honestW, List.mem_cons] at hr
    rcases hr with rfl | hr'
    · exact honestWords_length shdP_U shdP_hbij d f
    · exact scProve_honestW_len H d n _ _ r_list hr'

/-- Any `polySlotData` slot with `slotD P s ≤ 5` emits round messages of length `≤ 6` (fitting `Lq ≥ 2^20`). -/
theorem polySlotData_fitSc {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (P : BlockParams)
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → shdP_K) → shdP_K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2)
    (hd5 : ∀ s, slotD P s ≤ 5) (G : QB Lq → Dig)
    (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (df : SlotDef) :
    ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
      ((polySlotData P shdP_U shdP_hbij scalar poly terms).strat s hist acc df (slotC (liftH G) P s t))
      (slotT4 (liftH G) P s t
        ((polySlotData P shdP_U shdP_hbij scalar poly terms).scalar s hist acc df (slotC (liftH G) P s t)))).1 →
      48 + scLabel.length + r_list.length * 16 ≤ Lq := by
  intro r_list hr
  have hlen := scProve_honestW_len (liftH G) (slotD P s) (slotN P s) _ _ r_list hr
  have hd := hd5 s
  have hscL : scLabel.length = 8 := by decide
  rw [hlen, hscL]; omega

/-- `atLog`-adjusted variant of `polySlotData_fitSc` for `stSlotsProveFixedProg_run`. -/
theorem polySlotData_fitSc_atLog {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (P : BlockParams) (elog : ℕ → ℕ)
    (scalar : ℕ → Hist → Acc → SlotDef → Fp2 → Fp2)
    (poly : (s : ℕ) → Hist → Acc → SlotDef → Fp2 → (Fin (slotN P s) → shdP_K) → shdP_K)
    (terms : ℕ → Hist → Acc → SlotDef → Fp2 → List Fp2 → List Fp2)
    (hd5 : ∀ s, slotD P s ≤ 5) (G : QB Lq → Dig)
    (s : ℕ) (hist : Hist) (acc : Acc) (t : Tr) (df : SlotDef) :
    ∀ r_list, r_list ∈ (scProve (liftH G) (slotN (atLog P (elog s)) s)
      ((sdAt (polySlotData P shdP_U shdP_hbij scalar poly terms) (elog s)).strat s hist acc df
        (slotC (liftH G) (atLog P (elog s)) s t))
      (slotT4 (liftH G) (atLog P (elog s)) s t
        ((sdAt (polySlotData P shdP_U shdP_hbij scalar poly terms) (elog s)).scalar s hist acc df
          (slotC (liftH G) (atLog P (elog s)) s t)))).1 →
      48 + scLabel.length + r_list.length * 16 ≤ Lq := by
  intro r_list hr
  have hlen := scProve_honestW_len (liftH G) (slotD P s) (slotN P s) _ _ r_list hr
  have hd := hd5 s
  have hscL : scLabel.length = 8 := by decide
  rw [hlen, hscL]; omega

theorem polyWords_fit_maskQ {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (p : Polynomial shdP_K) :
    48 + maskQLabel.length + (polyWords shdP_U shdP_hbij p).length * 16 ≤ Lq := by
  have hlen : (polyWords shdP_U shdP_hbij p).length = 2 * mMsg := by unfold polyWords; simp
  have hm : mMsg = 512 := rfl
  have hl : maskQLabel.length = 6 := by decide
  rw [hlen, hm, hl]; omega

theorem polyWords_fit_maskProx {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (p : Polynomial shdP_K) :
    48 + maskProxLabel.length + (polyWords shdP_U shdP_hbij p).length * 16 ≤ Lq := by
  have hlen : (polyWords shdP_U shdP_hbij p).length = 2 * mMsg := by unfold polyWords; simp
  have hm : mMsg = 512 := rfl
  have hl : maskProxLabel.length = 9 := by decide
  rw [hlen, hm, hl]; omega

theorem pcsCombVec_fit {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (prm : PcsPrm) (hprm : prm.n + prm.qPad ≤ 20000) :
    48 + pcsVecLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq
      ∧ 48 + pcsProxLabel.length + (prm.n + prm.qPad) * 16 ≤ Lq := by
  have h1 : pcsVecLabel.length = 7 := by decide
  have h2 : pcsProxLabel.length = 8 := by decide
  rw [h1, h2]; omega

/-- Salt-matching lemma for interior R13 block `k : Fin 26` (`A_{k+1}` and `H_{k+1}`), avoiding `eqRec`. -/
theorem blkSalts_eq_shdLeafSalt (c : ShdCoins) (k : Fin 26) :
    let s : Fin 28 := ⟨k.val + 1, by omega⟩
    have hdA : shdTreeDepthOf (.a s) = 16 := by
      unfold shdTreeDepthOf shdAHDepth; dsimp only [s]; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
    have hdH : shdTreeDepthOf (.h s) = 16 := hdA
    (∀ j : Fin (2 ^ 16), (shdBlkRndOf c k).aSalts j.val = shdLeafSalt c ⟨.a s, Fin.cast (by rw [hdA]) j⟩)
      ∧ (∀ j : Fin (2 ^ 16), (shdBlkRndOf c k).hSalts j.val = shdLeafSalt c ⟨.h s, Fin.cast (by rw [hdH]) j⟩) := by
  intro s hdA hdH
  have hah : shdP_L1Spec.ah s = ⟨shdP_blkASpec, shdP_blkHSpec⟩ := by
    dsimp only [shdP_L1Spec, s]; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  have hdep : shdAHDepth s = 16 := hdA
  have haux : ∀ (P : PcsAHSpec) (d : ℕ) (hP : P = ⟨shdP_blkASpec, shdP_blkHSpec⟩) (hd : d = 16)
      (hS_A : P.A.Salt = (Fin (2 ^ d) → Dig)) (hS_H : P.H.Salt = (Fin (2 ^ d) → Dig))
      (x : PcsAHCoins GF P) (j : Fin (2 ^ 16)),
      extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩).2.1 j.val
        = Equiv.cast hS_A x.2.1 (Fin.cast (by rw [hd]) j)
      ∧ extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_blkASpec, shdP_blkHSpec⟩).2.2 j.val
        = Equiv.cast hS_H x.2.2 (Fin.cast (by rw [hd]) j) := by
    intro P d hP hd hS_A hS_H x j
    subst hP; subst hd
    exact ⟨extSalt_lt x.2.1 j.isLt, extSalt_lt x.2.2 j.isLt⟩
  refine ⟨fun j => ?_, fun j => ?_⟩
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) hah hdep (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).1
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) hah hdep (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).2

/-- Salt-matching lemma for Stage `IN-C` (`A_0` and `H_0`). -/
theorem incSalts_eq_shdLeafSalt (c : ShdCoins) :
    let s : Fin 28 := ⟨0, by decide⟩
    have hdA : shdTreeDepthOf (.a s) = 14 := rfl
    have hdH : shdTreeDepthOf (.h s) = 14 := rfl
    (∀ j : Fin (2 ^ 14), (shdIncRndOf c).aSalts j.val = shdLeafSalt c ⟨.a s, Fin.cast (by rw [hdA]) j⟩)
      ∧ (∀ j : Fin (2 ^ 14), (shdIncRndOf c).hSalts j.val = shdLeafSalt c ⟨.h s, Fin.cast (by rw [hdH]) j⟩) := by
  intro s hdA hdH
  have haux : ∀ (P : PcsAHSpec) (d : ℕ) (hP : P = ⟨shdP_incASpec, shdP_incHSpec⟩) (hd : d = 14)
      (hS_A : P.A.Salt = (Fin (2 ^ d) → Dig)) (hS_H : P.H.Salt = (Fin (2 ^ d) → Dig))
      (x : PcsAHCoins GF P) (j : Fin (2 ^ 14)),
      extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_incASpec, shdP_incHSpec⟩).2.1 j.val
        = Equiv.cast hS_A x.2.1 (Fin.cast (by rw [hd]) j)
      ∧ extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_incASpec, shdP_incHSpec⟩).2.2 j.val
        = Equiv.cast hS_H x.2.2 (Fin.cast (by rw [hd]) j) := by
    intro P d hP hd hS_A hS_H x j
    subst hP; subst hd
    exact ⟨extSalt_lt x.2.1 j.isLt, extSalt_lt x.2.2 j.isLt⟩
  refine ⟨fun j => ?_, fun j => ?_⟩
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) rfl rfl (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).1
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) rfl rfl (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).2

/-- Salt-matching lemma for Stage `OUT-C` (`A_27` and `H_27`). -/
theorem outcSalts_eq_shdLeafSalt (c : ShdCoins) :
    let s : Fin 28 := ⟨27, by decide⟩
    have hdA : shdTreeDepthOf (.a s) = 14 := rfl
    have hdH : shdTreeDepthOf (.h s) = 14 := rfl
    (∀ j : Fin (2 ^ 14), (shdOutcRndOf c).aSalts j.val = shdLeafSalt c ⟨.a s, Fin.cast (by rw [hdA]) j⟩)
      ∧ (∀ j : Fin (2 ^ 14), (shdOutcRndOf c).hSalts j.val = shdLeafSalt c ⟨.h s, Fin.cast (by rw [hdH]) j⟩) := by
  intro s hdA hdH
  have haux : ∀ (P : PcsAHSpec) (d : ℕ) (hP : P = ⟨shdP_outcASpec, shdP_outcHSpec⟩) (hd : d = 14)
      (hS_A : P.A.Salt = (Fin (2 ^ d) → Dig)) (hS_H : P.H.Salt = (Fin (2 ^ d) → Dig))
      (x : PcsAHCoins GF P) (j : Fin (2 ^ 14)),
      extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_outcASpec, shdP_outcHSpec⟩).2.1 j.val
        = Equiv.cast hS_A x.2.1 (Fin.cast (by rw [hd]) j)
      ∧ extSalt (hP ▸ x : PcsAHCoins GF ⟨shdP_outcASpec, shdP_outcHSpec⟩).2.2 j.val
        = Equiv.cast hS_H x.2.2 (Fin.cast (by rw [hd]) j) := by
    intro P d hP hd hS_A hS_H x j
    subst hP; subst hd
    exact ⟨extSalt_lt x.2.1 j.isLt, extSalt_lt x.2.2 j.isLt⟩
  refine ⟨fun j => ?_, fun j => ?_⟩
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) rfl rfl (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).1
  · exact (haux (shdP_L1Spec.ah s) (shdAHDepth s) rfl rfl (shdL1_ah_A_salt_eq s) (shdL1_ah_H_salt_eq s) (c.1.2.2 s) j).2

end StageConstants

/-! ## 3. Fixed-schedule Stage `IN-C` (`incSegFixedProg` + `.run` + `SliceSpec`) -/

section IncSegFixed

private theorem tr_absorb_key (H : HIn → Dig) (t : Tr) (lab d : List UInt8) {k : Option Dig} (h : t.key = k) :
    (t.absorb H lab d).key = k := h

private theorem absorbRoot_key (H : HIn → Dig) (t : Tr) (lab : List UInt8) (r : Dig) (rows lc : ℕ)
    {k : Option Dig} (h : t.key = k) : (Exec.Block.absorbRoot H t lab r rows lc).key = k := h

private theorem tr_challengeFp2_key (H : HIn → Dig) (t : Tr) {k : Option Dig} (h : t.key = k) :
    (t.challengeFp2 H).2.key = k := h

private theorem tr_challengeFp2Vec_key (H : HIn → Dig) :
    ∀ (t : Tr) (n : ℕ), (t.challengeFp2Vec H n).2.key = t.key
  | _, 0 => rfl
  | t, n + 1 => (tr_challengeFp2Vec_key H (t.challengeFp2 H).2 n).trans (tr_challengeFp2_key H t rfl)

private theorem shdP_incTB_cols_len (Rp : ClassifyRunPublicP shieldS0) (x : shieldS0.Tok → ℕ) (rnd : IncRand)
    (j : Fin (2 ^ 16)) : ((shdP_incTB Rp x rnd).cols j.val).length = 38 := by
  rw [show (38 : ℕ) = (shdP_incTB Rp x rnd).rows.length from (shdP_incTB_rows_len Rp x rnd).symm]
  exact mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j.val

private theorem shdP_incTA_cols_len (x : shieldS0.Tok → ℕ) (rnd : IncRand)
    (j : Fin (2 ^ 14)) : ((shdP_incTA x rnd).cols j.val).length = 41 := by
  rw [show (41 : ℕ) = (shdP_incTA x rnd).rows.length from (shdP_incTA_rows_len x rnd).symm]
  exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _ j.val

private theorem shdP_incTH_cols_len (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (x : shieldS0.Tok → ℕ) (rnd : IncRand) (ch : List Fp2)
    (j : Fin (2 ^ 14)) : ((shdP_incTH Rp embDigest x rnd ch).cols j.val).length = 76 := by
  rw [show (76 : ℕ) = (shdP_incTH Rp embDigest x rnd ch).rows.length from (shdP_incTH_rows_len Rp embDigest x rnd ch).symm]
  exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _ j.val

private theorem shdP_inc_slotD_le5 (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig)
    (bInRow : ℕ) (cx : IncCtx) (s : ℕ) :
    slotD ((shdVi tag Rp embDigest bInRow).bp cx) s ≤ 5 := by
  obtain ⟨_, _, _, hsl⟩ := shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)
  change ((incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).geomSlots.getD s (0, 0, 0)).2.2 ≤ 5
  rw [hsl]
  match s with
  | 0 | 1 | 2 | 3 => decide
  | _ + 4 => simp

theorem slotDefChecks_nPriv (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef)
    (h : Exec.Block.slotDefChecks P s acc df = .ok ()) :
    (df.tabs.filter Exec.Block.Tab.isPriv).length = Exec.Block.slotTerms P s := by
  unfold Exec.Block.slotDefChecks at h
  dsimp only at h
  split_ifs at h with h1
  by_contra hne
  exact h1 (by simp [hne])

private theorem shdP_inc_terms_fit {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (ch : List Fp2) (TA TH TE TB : Table) (rnd : IncRand) (G : QB Lq → Dig) :
    let V := shdVi tag Rp embDigest bInRow
    let P := V.bp (incCtx V.pub ch)
    let D := shdP_incSlotData tag Rp embDigest bInRow ch TA TH TE TB rnd
    ∀ s hist acc t df,
      (atLog P (incElog V.pub V.geo.bLogN s)).define s hist
        (t.challengeFp2Vec (liftH G) ((atLog P (incElog V.pub V.geo.bLogN s)).draws s)).1 = .ok df →
      Exec.Block.slotDefChecks (atLog P (incElog V.pub V.geo.bLogN s)) s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length +
        (slotSP (liftH G) (atLog P (incElog V.pub V.geo.bLogN s)) (sdAt D (incElog V.pub V.geo.bLogN s))
          s hist acc t df).terms.length * 16 ≤ Lq := by
  intro V P D s hist acc t df _ hchk
  have hlen : (slotSP (liftH G) (atLog P (incElog V.pub V.geo.bLogN s)) (sdAt D (incElog V.pub V.geo.bLogN s))
      s hist acc t df).terms.length = (df.tabs.filter Exec.Block.Tab.isPriv).length := by
    unfold slotSP sdAt D shdP_incSlotData polySlotData; dsimp only
    exact stgPrivVals_length shdP_U shdP_hbij _ _ _ _ df.tabs
  have hn := slotDefChecks_nPriv (atLog P (incElog V.pub V.geo.bLogN s)) s acc df hchk
  have hst : Exec.Block.slotTerms (atLog P (incElog V.pub V.geo.bLogN s)) s ≤ 16 := by
    change ([2, 3, 2, 1] : List ℕ).getD s 0 ≤ 16
    match s with | 0 | 1 | 2 | 3 => decide | _ + 4 => simp
  have hlab : Exec.Block.labPbTerm.length = 7 := by decide
  rw [hlen, hn, hlab]; omega

/-- **Fixed-schedule Stage `IN-C` (`205,401` `.pt`s, `307,801` total queries)**:
always emits `B_0`, frame, `A_0`, `M_0`, `15` head challenges, `H_0`, `4` `stSlots`, `M_0` opening,
`A_0` opening, `H_0` opening, and cached `TE` opening; always returns `(Option (enc × Carry), treeB0, t_after)`. -/
noncomputable def incSegFixedProg {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (treeTE : MerkleLevels 11)
    (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) :=
  let V := shdVi tag Rp embDigest bInRow
  let G := rcIncGeom V 28
  let rnd := shdIncRndOf c
  let TB0 := shdP_incTB Rp x rnd
  let TA0 := shdP_incTA x rnd
  let M0 := shdP_incM rnd
  let TE := shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)
  (merkleTableProg Lq (by omega) tag 16 38 (by omega) TB0 (shdP_incTB_cols_len Rp x rnd)).andThen fun treeB0 =>
    let bRoot := treeB0.getRoot
    (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat 0))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) embDigest.toList).andThen fun tf2 =>
        (absorbRootKeyed Lq hL20 key tf2 labB (by decide) bRoot V.geo.bRows V.geo.bLogN).andThen fun tf5 =>
          (merkleTableProg Lq (by omega) tag 14 41 (by omega) TA0 (shdP_incTA_cols_len x rnd)).andThen fun treeA0 =>
            let aRoot := treeA0.getRoot
            (absorbRootKeyed Lq hL20 key tf5 labA (by decide) aRoot V.lay.aRows V.lay.logN).andThen fun tA =>
              (merkleTableProg Lq (by omega) tag 12 (2 * 4 + 4) (by omega) (mTab 4 (cosetPt (rootFp 12)) M0)
                  (fun j => mCol_length 4 _ M0 j.val)).andThen fun treeM0 =>
                let mRoot := treeM0.getRoot
                (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
                  (trChallengeFp2VecKeyed Lq (by omega) key 15 tM).andThen fun chR =>
                    let ch := chR.1
                    let TH0 := shdP_incTH Rp embDigest x rnd ch
                    let cx := incCtx V.pub ch
                    let active1 := !incAlphaBad cx
                    (merkleTableProg Lq (by omega) tag 14 76 (by omega) TH0 (shdP_incTH_cols_len Rp embDigest x rnd ch)).andThen fun treeH0 =>
                      let hRoot := treeH0.getRoot
                      (absorbRootKeyed Lq hL20 key chR.2 labH (by decide) hRoot V.lay.hRows V.lay.logN).andThen fun t3 =>
                        let Dslot := shdP_incSlotData tag Rp embDigest bInRow ch TA0 TH0 TE TB0 rnd
                        (stSlotsProveFixedProg Lq hL20 key (V.bp cx) (incElog V.pub V.geo.bLogN)
                            Dslot Fp2.zero Fp2.zero Fp2.zero 4 active1 [] 0 {} t3).andThen fun slR =>
                          let active2 := match slR.1 with
                            | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals)
                            | none => false
                          let fs := match slR.1 with
                            | some (_, _, acc) => acc.fs ++ acc.hostFs
                            | none => []
                          (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M0 4 treeM0 fs slR.2).andThen fun mR =>
                            let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                            (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3
                                (shdP_incOpenGeomA V) TA0 treeA0 active2
                                (openingHdrOk (shdP_incOpenGeomA V) 12 clA) clA mR.2).andThen fun aR =>
                              let active3 := active2 && aR.1.isSome
                              let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
                              (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4
                                  (shdP_incOpenGeomH V) TH0 treeH0 active3
                                  (openingHdrOk (shdP_incOpenGeomH V) 12 clH) clH aR.2).andThen fun hR =>
                                let active4 := active3 && hR.1.isSome
                                let clE := match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []
                                (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1
                                    shdP_epOpenGeom TE treeTE active4
                                    (tokenEpHdrOk clE V.geo.epDataRows V.pub.epN) clE hR.2).andThen fun eR =>
                                  match slR.1, aR.1, hR.1, eR.1 with
                                  | some (sps, _, acc), some aO, some hO, some eO =>
                                    if active4 then
                                      let seg : StageSeg := ⟨some bRoot, ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩, [eO]⟩
                                      .ret (some (fun e => encStage G bnd startTag seg e, ⟨acc.claims.out, bRoot⟩), treeB0, eR.2)
                                    else .ret (none, treeB0, eR.2)
                                  | _, _, _, _ => .ret (none, treeB0, eR.2)

/-- Static point schedule of `incSegFixedProg` (`205,401` queries starting at `base`). -/
def incSegFixedSched (P0in : BlockParams) (base tip : ℕ) : ℕ → RawPtSpec :=
  let b0 := base + 131071
  let b1 := b0 + 1
  let b2 := b1 + 1
  let b5 := b2 + 3
  let bA := b5 + 32767
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bCh := bM1 + 15
  let bH := bCh + 32767
  let bH3 := bH + 3
  let bSl := bH3 + 167
  let bMo := bSl + 77
  let bAo := bMo + 112
  let bHo := bAo + 149
  let bEo := bHo + 73
  spliceSched b0 (merkleTreeSched (.bnd ⟨0, by decide⟩) base)
    (spliceSched b1 (fun _ => .absorb tip)
      (spliceSched b2 (fun _ => .absorb b0)
        (spliceSched b5 (absorbRootSched b2 b1)
          (spliceSched bA (merkleTreeSched (.a ⟨0, by decide⟩) b5)
            (spliceSched bA3 (absorbRootSched bA (b5 - 1))
              (spliceSched bM (merkleTreeSched (.m ⟨0, by decide⟩) bA3)
                (spliceSched bM1 (fun _ => .absorb (bA3 - 1))
                  (spliceSched bCh (squeezeVecSched bM1 bM)
                    (spliceSched bH (merkleTreeSched (.h ⟨0, by decide⟩) bCh)
                      (spliceSched bH3 (absorbRootSched bH (bCh - 1))
                        (spliceSched bSl (slotsFixedSched P0in 0 4 bH3 (bH3 - 1))
                          (spliceSched bMo (zkBMaskFixedSched 4 bSl (bSl - 1))
                            (spliceSched bAo (openingAuditFixedSched 3 41 3 256 bMo (bMo - 1))
                              (spliceSched bHo (openingAuditFixedSched 4 76 4 256 bAo (bAo - 1))
                                (spliceSched bEo (openingAuditFixedSched 1 6 1 256 bHo (bHo - 1))
                                  (fun _ => .absorb 0))))))))))))))))

/-- Trees touched by Stage `IN-C`: `{B_0, A_0, M_0, H_0}`. -/
def incTreeSet (tid : ShdTreeId) : Prop :=
  tid = .bnd ⟨0, by decide⟩ ∨ tid = .a ⟨0, by decide⟩ ∨ tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩

private noncomputable def incSegFixedProg_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : IncV) (G0 : StageGeom) (embDigest : Dig)
    (TB0 TA0 TE : Table)
    (hTB0c : ∀ j : Fin (2 ^ 16), (TB0.cols j.val).length = 38)
    (hTA0c : ∀ j : Fin (2 ^ 14), (TA0.cols j.val).length = 41)
    (M0 : MTable)
    (TH : List Fp2 → Table)
    (hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 76)
    (Dslot : ∀ ch, SlotData (V.bp (incCtx V.pub ch)))
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) :=
  (merkleTableProg Lq (by omega) tag 16 38 (by omega) TB0 hTB0c).andThen fun treeB0 =>
    let bRoot := treeB0.getRoot
    (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat 0))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) embDigest.toList).andThen fun tf2 =>
        (absorbRootKeyed Lq hL20 key tf2 labB (by decide) bRoot V.geo.bRows V.geo.bLogN).andThen fun tf5 =>
          (merkleTableProg Lq (by omega) tag 14 41 (by omega) TA0 hTA0c).andThen fun treeA0 =>
            let aRoot := treeA0.getRoot
            (absorbRootKeyed Lq hL20 key tf5 labA (by decide) aRoot V.lay.aRows V.lay.logN).andThen fun tA =>
              (merkleTableProg Lq (by omega) tag 12 (2 * 4 + 4) (by omega) (mTab 4 (cosetPt (rootFp 12)) M0)
                  (fun j => mCol_length 4 _ M0 j.val)).andThen fun treeM0 =>
                let mRoot := treeM0.getRoot
                (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
                  (trChallengeFp2VecKeyed Lq (by omega) key 15 tM).andThen fun chR =>
                    let ch := chR.1
                    let TH0 := TH ch
                    let cx := incCtx V.pub ch
                    let active1 := !incAlphaBad cx
                    (merkleTableProg Lq (by omega) tag 14 76 (by omega) TH0 (hTHc ch)).andThen fun treeH0 =>
                      let hRoot := treeH0.getRoot
                      (absorbRootKeyed Lq hL20 key chR.2 labH (by decide) hRoot V.lay.hRows V.lay.logN).andThen fun t3 =>
                        (stSlotsProveFixedProg Lq hL20 key (V.bp cx) (incElog V.pub V.geo.bLogN)
                            (Dslot ch) Fp2.zero Fp2.zero Fp2.zero 4 active1 [] 0 {} t3).andThen fun slR =>
                          let active2 := match slR.1 with
                            | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals)
                            | none => false
                          let fs := match slR.1 with
                            | some (_, _, acc) => acc.fs ++ acc.hostFs
                            | none => []
                          (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M0 4 treeM0 fs slR.2).andThen fun mR =>
                            let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                            (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3
                                (shdP_incOpenGeomA V) TA0 treeA0 active2
                                (openingHdrOk (shdP_incOpenGeomA V) 12 clA) clA mR.2).andThen fun aR =>
                              let active3 := active2 && aR.1.isSome
                              let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
                              (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4
                                  (shdP_incOpenGeomH V) TH0 treeH0 active3
                                  (openingHdrOk (shdP_incOpenGeomH V) 12 clH) clH aR.2).andThen fun hR =>
                                let active4 := active3 && hR.1.isSome
                                let clE := match slR.1 with | some (_, _, acc) => acc.claims.inp | none => []
                                (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1
                                    shdP_epOpenGeom TE treeTE active4
                                    (tokenEpHdrOk clE V.geo.epDataRows V.pub.epN) clE hR.2).andThen fun eR =>
                                  match slR.1, aR.1, hR.1, eR.1 with
                                  | some (sps, _, acc), some aO, some hO, some eO =>
                                    if active4 then
                                      let seg : StageSeg := ⟨some bRoot, ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩, [eO]⟩
                                      .ret (some (fun e => encStage G0 bnd startTag seg e, ⟨acc.claims.out, bRoot⟩), treeB0, eR.2)
                                    else .ret (none, treeB0, eR.2)
                                  | _, _, _, _ => .ret (none, treeB0, eR.2)

private theorem incProve_err (H : HIn → Dig) (V : IncV) (D : IncData V) (t : Tr)
    (h : incProve H V D t = .error ()) :
    let ch := (incCh H V D t).1
    let t3 := Exec.Block.absorbRoot H (incCh H V D t).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN
    incAlphaBad (incCtx V.pub ch) = true
    ∨ (incAlphaBad (incCtx V.pub ch) = false
        ∧ (stSlotsProve H (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN)
              (D.slot ch) Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {} t3 = .error ()
          ∨ ∃ sps recs acc t4,
              stSlotsProve H (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN)
                (D.slot ch) Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {} t3 = .ok (sps, recs, acc, t4)
              ∧ ((acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals
                ∨ ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals
                    ∧ ((∃ e, V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
                      ∨ (V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .ok ()
                          ∧ ((∃ e, V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
                            ∨ (V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .ok ()
                                ∧ ∃ e, checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
                                    (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e)))))))) := by
  dsimp only
  unfold incProve at h
  cases hbad : incAlphaBad (incCtx V.pub (incCh H V D t).1) with
  | true => exact Or.inl rfl
  | false =>
    right; refine ⟨rfl, ?_⟩
    simp only [hbad, Bool.false_eq_true, ↓reduceIte] at h
    cases hsl : stSlotsProve H (V.bp (incCtx V.pub (incCh H V D t).1)) (incElog V.pub V.geo.bLogN)
        (D.slot (incCh H V D t).1) Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {}
        (Exec.Block.absorbRoot H (incCh H V D t).2 labH (D.hRoot (incCh H V D t).1) V.lay.hRows V.lay.logN) with
    | error u => cases u; exact Or.inl rfl
    | ok vSl =>
      rcases vSl with ⟨sps, recs, acc, t4⟩
      right; refine ⟨sps, recs, acc, t4, rfl, ?_⟩
      rw [hsl] at h; dsimp only at h
      by_cases hfs : (acc.fs ++ acc.hostFs).length = V.lay.nFunctionals
      · right; refine ⟨hfs, ?_⟩
        rw [ite_eq_right (not_not.mpr hfs)] at h
        cases hcA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inl ⟨e, rfl⟩
        | ok u1 =>
          cases u1; right; refine ⟨rfl, ?_⟩
          rw [hcA] at h; dsimp only at h
          cases hcH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inl ⟨e, rfl⟩
          | ok u2 =>
            cases u2; right; refine ⟨rfl, ?_⟩
            rw [hcH] at h; dsimp only at h
            cases hcE : checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact ⟨e, rfl⟩
            | ok u3 => rw [hcE] at h; cases h
      · exact Or.inl hfs

private theorem incSegFixedProg_run_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : IncV) (G0 : StageGeom) (embDigest : Dig)
    (TB0 TA0 TE : Table)
    (hTB0c : ∀ j : Fin (2 ^ 16), (TB0.cols j.val).length = 38)
    (hTA0c : ∀ j : Fin (2 ^ 14), (TA0.cols j.val).length = 41)
    (hTA0r : 41 = TA0.rows.length)
    (hTEr : 6 = TE.rows.length)
    (M0 : MTable)
    (TH : List Fp2 → Table)
    (hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 76)
    (hTHr : ∀ ch, 76 = (TH ch).rows.length)
    (Dslot : ∀ ch, SlotData (V.bp (incCtx V.pub ch)))
    (t : Tr) (G : QB Lq → Dig)
    (D : IncData V)
    (hDbR : D.bRoot = rootOf (liftH G) tag 16 TB0)
    (hDaR : D.aRoot = rootOf (liftH G) tag 14 TA0)
    (hDmR : D.maskRoot = rootOf (liftH G) tag 12 (mTab 4 (cosetPt (rootFp 12)) M0))
    (hDhR : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH ch))
    (hDslot : ∀ ch, D.slot ch = Dslot ch)
    (hDmOpen : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij M0 4)
    (hDaOpen : D.aOpen = bOpen (liftH G) tag shdP_stgPrm 14 TA0)
    (hDhOpen : D.hOpen = bOpen (liftH G) tag shdP_stgPrm 14 (TH (incCh (liftH G) V D t).1))
    (hDepOpen : D.epOpen = bOpen (liftH G) tag shdP_epPrm 11 TE)
    (hV_aR : V.lay.aRows = 41) (hV_hR : V.lay.hRows = 76)
    (hV_logN : V.lay.logN = 12)
    (hV_ns : V.lay.ns = 4) (hV_hd : incHeadDraws V.pub = 15)
    (hV_emb : V.pub.embDigest = embDigest) (hV_epDR : V.geo.epDataRows = 1)
    (hV_siteA : V.lay.aSiteRows = List.range' 33 6)
    (hV_siteH : V.lay.hSiteRows = List.range' 68 6)
    (hV_sumH : V.lay.logupSumClaim.parts.all (fun p => p.point.isEmpty) = true)
    (hfitSc : ∀ ch s hist acc t' df,
      (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)).define s hist
        (t'.challengeFp2Vec (liftH G) ((atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)).draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) s)
        ((sdAt (Dslot ch) (incElog V.pub V.geo.bLogN s)).strat s hist acc df
          (slotC (liftH G) (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) s t'))
        (slotT4 (liftH G) (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) s t'
          ((sdAt (Dslot ch) (incElog V.pub V.geo.bLogN s)).scalar s hist acc df
            (slotC (liftH G) (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) s t')))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ ch s hist acc t' df,
      (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)).define s hist
        (t'.challengeFp2Vec (liftH G) ((atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)).draws s)).1 = .ok df →
      Exec.Block.slotDefChecks (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length +
        (slotSP (liftH G) (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s))
          (sdAt (Dslot ch) (incElog V.pub V.geo.bLogN s)) s hist acc t' df).terms.length * 16 ≤ Lq)
    (treeTE : MerkleLevels 11) (bnd startTag : Dig) (htKey : t.key = key)
    (hTE : ∀ (j : ℕ) (hj : j < 2 ^ 11), treeTE.path j hj = pathOf (liftH G) tag 11 TE j) :
    let res := (incSegFixedProg_abs Lq hL20 tag key V G0 embDigest TB0 TA0 TE hTB0c hTA0c M0 TH hTHc Dslot treeTE bnd startTag t).run G
    (res.2.1.getRoot = rootOf (liftH G) tag 16 TB0
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), res.2.1.path j hj = pathOf (liftH G) tag 16 TB0 j)
    ∧ (incProve (liftH G) V D t = .error () → res.1 = none)
    ∧ (∀ R, incProve (liftH G) V D t = .ok R →
        res.1 = some (fun e => encStage G0 bnd startTag R.seg e, ⟨R.acc.claims.out, D.bRoot⟩) ∧ res.2.2 = R.t8) := by
  dsimp only
  generalize hres : (incSegFixedProg_abs Lq hL20 tag key V G0 embDigest TB0 TA0 TE hTB0c hTA0c M0 TH hTHc Dslot treeTE bnd startTag t).run G = res
  unfold incSegFixedProg_abs at hres
  dsimp only at hres
  obtain ⟨trB0, htrB0, hTreeB0⟩ := merkle_andThen_elim Lq (by omega) tag 16 38 (by omega) TB0 hTB0c G
  rw [run_andThen_with _ _ G trB0 htrB0] at hres; clear htrB0
  rw [run_andThen_trAbsorb htKey (by rw [le64_length]; change 48 + 12 + 8 ≤ Lq; omega),
      run_andThen_trAbsorb (tr_absorb_key _ _ _ _ htKey) (by rw [List.Vector.toList_length]; change 48 + 12 + 32 ≤ Lq; omega),
      run_andThen_absorbRoot (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))] at hres
  obtain ⟨trA0, htrA0, hTreeA0⟩ := merkle_andThen_elim Lq (by omega) tag 14 41 (by omega) TA0 hTA0c G
  rw [run_andThen_with _ _ G trA0 htrA0] at hres; clear htrA0
  have htf5Key : (Exec.Block.absorbRoot (liftH G)
      ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat 0))).absorb (liftH G) labRunBlock embDigest.toList)
      labB trB0.getRoot V.geo.bRows V.geo.bLogN).key = key :=
    absorbRoot_key _ _ _ _ _ _ (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))
  rw [run_andThen_absorbRoot htf5Key] at hres
  obtain ⟨trM0, htrM0, hTreeM0⟩ := merkle_andThen_elim Lq (by omega) tag 12 (2 * 4 + 4) (by omega)
      (mTab 4 (cosetPt (rootFp 12)) M0) (fun j => mCol_length 4 _ M0 j.val) G
  rw [run_andThen_with _ _ G trM0 htrM0] at hres; clear htrM0
  have htAKey : (Exec.Block.absorbRoot (liftH G)
      (Exec.Block.absorbRoot (liftH G)
        ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat 0))).absorb (liftH G) labRunBlock embDigest.toList)
        labB trB0.getRoot V.geo.bRows V.geo.bLogN)
      labA trA0.getRoot V.lay.aRows V.lay.logN).key = key :=
    absorbRoot_key _ _ _ _ _ _ htf5Key
  rw [run_andThen_trAbsorb htAKey (by rw [List.Vector.toList_length]; change 48 + 1 + 32 ≤ Lq; omega),
      run_andThen_trChallengeFp2Vec (tr_absorb_key _ _ _ _ htAKey)] at hres
  have hChEq :
      ((Exec.Block.absorbRoot (liftH G)
          (Exec.Block.absorbRoot (liftH G)
            (((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat 0))).absorb (liftH G) labRunBlock embDigest.toList))
            labB trB0.getRoot V.geo.bRows V.geo.bLogN)
          labA trA0.getRoot V.lay.aRows V.lay.logN).absorb (liftH G) labM trM0.getRoot.toList).challengeFp2Vec (liftH G) 15
      = incCh (liftH G) V D t := by
    have hU0 : (0 : UInt64) = UInt64.ofNat 0 := rfl
    dsimp only [incCh, IncV.frame, Tr.absorbU64]
    rw [hTreeB0.1, hTreeA0.1, hTreeM0.1, hV_hd, hV_emb, hU0, hDbR, hDaR, hDmR]
  have hChKey : (incCh (liftH G) V D t).2.key = key := by
    rw [← hChEq, tr_challengeFp2Vec_key]; exact tr_absorb_key _ _ _ _ htAKey
  rw [hChEq] at hres
  let ch := (incCh (liftH G) V D t).1
  obtain ⟨trH0, htrH0, hTreeH0⟩ := merkle_andThen_elim Lq (by omega) tag 14 76 (by omega) (TH ch) (hTHc ch) G
  rw [run_andThen_with _ _ G trH0 htrH0] at hres; clear htrH0
  rw [run_andThen_absorbRoot hChKey] at hres
  have ht3Eq : Exec.Block.absorbRoot (liftH G) (incCh (liftH G) V D t).2 labH trH0.getRoot V.lay.hRows V.lay.logN
      = Exec.Block.absorbRoot (liftH G) (incCh (liftH G) V D t).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN := by
    rw [hTreeH0.1, hDhR ch]
  have ht3Key : (Exec.Block.absorbRoot (liftH G) (incCh (liftH G) V D t).2 labH (D.hRoot ch) V.lay.hRows V.lay.logN).key = key :=
    absorbRoot_key _ _ _ _ _ _ hChKey
  refine ⟨?_, ?_⟩
  · have hres_tree : res.2.1 = trB0 := by
      rw [← hres]
      refine run_andThen_snd_fst _ _ G trB0 fun ⟨o1, _⟩ =>
        run_andThen_snd_fst _ _ G trB0 fun ⟨_, _⟩ =>
          run_andThen_snd_fst _ _ G trB0 fun ⟨oA, _⟩ =>
            run_andThen_snd_fst _ _ G trB0 fun ⟨oH, _⟩ =>
              run_andThen_snd_fst _ _ G trB0 fun ⟨oE, _⟩ => ?_
      dsimp only
      cases o1 with
      | none => rfl
      | some v1 =>
        rcases v1 with ⟨sps, _, acc⟩
        cases oA with
        | none => rfl
        | some aO =>
          cases oH with
          | none => rfl
          | some hO =>
            cases oE with
            | none => rfl
            | some eO => exact ret_ite_snd_fst _ _ _ trB0 _ G
    rw [hres_tree]; exact hTreeB0
  · have hStgLog : shdP_stgPrm.logCols = 12 := rfl
    have hStgNN : shdP_stgPrm.nn = 2 ^ 14 := by norm_num [shdP_stgPrm, PcsPrm.nn]
    have hStgNQ : 0 < shdP_stgPrm.nQ := by norm_num [shdP_stgPrm]
    have hStgFit := pcsCombVec_fit hL20 shdP_stgPrm (by norm_num [shdP_stgPrm, PcsPrm.n])
    have hEpFit := pcsCombVec_fit hL20 shdP_epPrm (by norm_num [shdP_epPrm, PcsPrm.n])
    have hEp6 : V.geo.epDataRows + epMaskRows = 6 := by rw [hV_epDR]; rfl
    refine ⟨fun hInc => ?_, fun R hInc => ?_⟩
    · have herr := incProve_err (liftH G) V D t hInc
      dsimp only at herr
      rcases herr with hbad | ⟨hbad, hsl | ⟨sps, recs, acc, t4, hsl, hfs | ⟨hfs, ⟨eA, hcA⟩ | ⟨hcA, ⟨eH, hcH⟩ | ⟨hcH, eE, hcE⟩⟩⟩⟩⟩
      · rw [hbad] at hres; simp only [Bool.not_true] at hres
        rw [← hres]
        exact run_andThen_with_fst_none _ _ G (stSlotsProveFixedProg_run_inactive Lq hL20 key _ _ _ _ _ _ G _ _ _ _ _) fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
            run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · dsimp only [ch] at ht3Eq ht3Key
        rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
        rw [hV_ns, hDslot] at hsl
        have hSlRun := stSlotsProveFixedProg_run_err Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
          (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key hsl
        rw [← hres]
        exact run_andThen_with_fst_none _ _ G hSlRun fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
            run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · dsimp only [ch] at ht3Eq ht3Key
        rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
        rw [hV_ns, hDslot] at hsl
        have hSlRun := stSlotsProveFixedProg_run_ok Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
          (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_false hfs, Bool.false_and, Bool.false_eq_true, ↓reduceIte] at hres
        rw [← hres]
        refine run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun ⟨oA, _⟩ =>
          run_andThen_fst_none _ _ G fun ⟨oH, _⟩ => run_andThen_fst_none _ _ G fun ⟨oE, _⟩ => ?_
        dsimp only; cases oA <;> cases oH <;> cases oE <;> rfl
      · dsimp only [ch] at ht3Eq ht3Key
        rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
        rw [hV_ns, hDslot] at hsl
        have hSlRun := stSlotsProveFixedProg_run_ok Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
          (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_true hfs] at hres
        have ht4Key : t4.key = key := (stSlotsProve_key (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) _ Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
        have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M0 4 trM0 (acc.fs ++ acc.hostFs) t4 ht4Key G
          (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM0.2
        rw [run_andThen_with _ _ G _ hMRun] at hres
        let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4).2
        have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4 key ht4Key
        dsimp only [IncV.checkOpening] at hcA; rw [hDmOpen, hV_logN] at hcA
        have hARun := openingAuditFixedProg_run_err Lq hL20 tag key shdP_stgPrm 14 3 41 3 hStgNN hStgNQ
          (shdP_incOpenGeomA V) TA0 hTA0r hV_aR rfl trA0 acc.claims.a t5 ht5Key G hStgFit.1 hStgFit.2
          (fun og haud hog _ => by
            rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length acc.claims.a 12 og hog]
            have haud' : auditClaims acc.claims.a (2 ^ 12) 41 (List.range' 33 (2 * 3)) none V.lay.aProx = .ok () := by
              rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomA] at haud; rw [hV_aR, hV_siteA] at haud
              rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
            exact auditClaims_length_none acc.claims.a (2 ^ 12) 41 33 3 V.lay.aProx (by norm_num) haud') hTreeA0.2 eA hcA
        rw [hStgLog] at hARun; dsimp only [t5] at hARun; rw [← hres]
        exact run_andThen_with_fst_none _ _ G hARun fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · dsimp only [ch] at ht3Eq ht3Key
        rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
        rw [hV_ns, hDslot] at hsl
        have hSlRun := stSlotsProveFixedProg_run_ok Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
          (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_true hfs] at hres
        have ht4Key : t4.key = key := (stSlotsProve_key (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) _ Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
        have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M0 4 trM0 (acc.fs ++ acc.hostFs) t4 ht4Key G
          (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM0.2
        rw [run_andThen_with _ _ G _ hMRun] at hres
        let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4).2
        have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4 key ht4Key
        dsimp only [IncV.checkOpening] at hcA; rw [hDmOpen, hV_logN] at hcA
        have hARun := openingAuditFixedProg_run_ok Lq hL20 tag key shdP_stgPrm 14 3 41 3 hStgNN hStgNQ
          (shdP_incOpenGeomA V) TA0 hTA0r hV_aR rfl trA0 acc.claims.a t5 ht5Key G hStgFit.1 hStgFit.2
          (fun og haud hog _ => by
            rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length acc.claims.a 12 og hog]
            have haud' : auditClaims acc.claims.a (2 ^ 12) 41 (List.range' 33 (2 * 3)) none V.lay.aProx = .ok () := by
              rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomA] at haud; rw [hV_aR, hV_siteA] at haud
              rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
            exact auditClaims_length_none acc.claims.a (2 ^ 12) 41 33 3 V.lay.aProx (by norm_num) haud') hTreeA0.2 hcA
        rw [hStgLog] at hARun; dsimp only [t5] at hARun
        rw [run_andThen_with _ _ G _ hARun] at hres; dsimp only at hres
        simp only [Option.isSome_some, Bool.true_and] at hres
        let t6 := (bOpen (liftH G) tag shdP_stgPrm 14 TA0 acc.claims.a t5).2
        have ht6Key : t6.key = key := bOpen_key (liftH G) tag shdP_stgPrm 14 TA0 acc.claims.a t5 key ht5Key
        dsimp only [IncV.checkOpening] at hcH; rw [hDaOpen, hDmOpen, hV_logN] at hcH
        have hHRun := openingAuditFixedProg_run_err Lq hL20 tag key shdP_stgPrm 14 4 76 4 hStgNN hStgNQ
          (shdP_incOpenGeomH V) (TH (incCh (liftH G) V D t).1) (hTHr _) hV_hR rfl trH0 (acc.claims.h ++ [V.lay.logupSumClaim]) t6 ht6Key G hStgFit.1 hStgFit.2
          (fun og haud hog _ => by
            rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length _ 12 og hog]
            have haud' : auditClaims (acc.claims.h ++ [V.lay.logupSumClaim]) (2 ^ 12) 76
                (List.range' 68 (2 * 3)) (some V.lay.hURows) V.lay.hProx = .ok () := by
              rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomH] at haud; rw [hV_hR, hV_siteH] at haud
              rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
            exact auditClaims_length_some_last acc.claims.h V.lay.logupSumClaim hV_sumH
              (2 ^ 12) 76 68 3 V.lay.hURows.1 V.lay.hURows.2 V.lay.hProx (by norm_num) haud') hTreeH0.2 eH hcH
        rw [hStgLog] at hHRun; dsimp only [t6, t5] at hHRun; rw [← hres]
        exact run_andThen_with_fst_none _ _ G hHRun fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · dsimp only [ch] at ht3Eq ht3Key
        rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
        rw [hV_ns, hDslot] at hsl
        have hSlRun := stSlotsProveFixedProg_run_ok Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
          (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_true hfs] at hres
        have ht4Key : t4.key = key := (stSlotsProve_key (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
          (incElog V.pub V.geo.bLogN) _ Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
        have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M0 4 trM0 (acc.fs ++ acc.hostFs) t4 ht4Key G
          (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM0.2
        rw [run_andThen_with _ _ G _ hMRun] at hres
        let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4).2
        have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M0 4 (acc.fs ++ acc.hostFs) t4 key ht4Key
        dsimp only [IncV.checkOpening] at hcA; rw [hDmOpen, hV_logN] at hcA
        have hARun := openingAuditFixedProg_run_ok Lq hL20 tag key shdP_stgPrm 14 3 41 3 hStgNN hStgNQ
          (shdP_incOpenGeomA V) TA0 hTA0r hV_aR rfl trA0 acc.claims.a t5 ht5Key G hStgFit.1 hStgFit.2
          (fun og haud hog _ => by
            rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length acc.claims.a 12 og hog]
            have haud' : auditClaims acc.claims.a (2 ^ 12) 41 (List.range' 33 (2 * 3)) none V.lay.aProx = .ok () := by
              rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomA] at haud; rw [hV_aR, hV_siteA] at haud
              rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
            exact auditClaims_length_none acc.claims.a (2 ^ 12) 41 33 3 V.lay.aProx (by norm_num) haud') hTreeA0.2 hcA
        rw [hStgLog] at hARun; dsimp only [t5] at hARun
        rw [run_andThen_with _ _ G _ hARun] at hres; dsimp only at hres
        simp only [Option.isSome_some, Bool.true_and] at hres
        let t6 := (bOpen (liftH G) tag shdP_stgPrm 14 TA0 acc.claims.a t5).2
        have ht6Key : t6.key = key := bOpen_key (liftH G) tag shdP_stgPrm 14 TA0 acc.claims.a t5 key ht5Key
        dsimp only [IncV.checkOpening] at hcH; rw [hDaOpen, hDmOpen, hV_logN] at hcH
        have hHRun := openingAuditFixedProg_run_ok Lq hL20 tag key shdP_stgPrm 14 4 76 4 hStgNN hStgNQ
          (shdP_incOpenGeomH V) (TH (incCh (liftH G) V D t).1) (hTHr _) hV_hR rfl trH0 (acc.claims.h ++ [V.lay.logupSumClaim]) t6 ht6Key G hStgFit.1 hStgFit.2
          (fun og haud hog _ => by
            rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length _ 12 og hog]
            have haud' : auditClaims (acc.claims.h ++ [V.lay.logupSumClaim]) (2 ^ 12) 76
                (List.range' 68 (2 * 3)) (some V.lay.hURows) V.lay.hProx = .ok () := by
              rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomH] at haud; rw [hV_hR, hV_siteH] at haud
              rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
            exact auditClaims_length_some_last acc.claims.h V.lay.logupSumClaim hV_sumH
              (2 ^ 12) 76 68 3 V.lay.hURows.1 V.lay.hURows.2 V.lay.hProx (by norm_num) haud') hTreeH0.2 hcH
        rw [hStgLog] at hHRun; dsimp only [t6, t5] at hHRun
        rw [run_andThen_with _ _ G _ hHRun] at hres; dsimp only at hres
        simp only [Option.isSome_some] at hres
        let t7 := (bOpen (liftH G) tag shdP_stgPrm 14 (TH (incCh (liftH G) V D t).1) (acc.claims.h ++ [V.lay.logupSumClaim]) t6).2
        have ht7Key : t7.key = key := bOpen_key (liftH G) tag shdP_stgPrm 14 (TH (incCh (liftH G) V D t).1) (acc.claims.h ++ [V.lay.logupSumClaim]) t6 key ht6Key
        rw [hDhOpen, hDaOpen, hDmOpen] at hcE
        have hERun := openingAuditFixedProg_run_ep_err Lq hL20 tag key shdP_epPrm 11
          (by norm_num [shdP_epPrm, PcsPrm.nn]) (by norm_num [shdP_epPrm])
          V.geo.epDataRows V.pub.epN shdP_epOpenGeom
          (by rw [hV_epDR]; rfl) (by rw [hV_epDR]; rfl) TE
          (by rw [hV_epDR]; exact hTEr) treeTE acc.claims.inp t7 ht7Key G hEpFit.1 hEpFit.2 hTE eE hcE
        rw [hEp6] at hERun; dsimp only [t7, t6, t5] at hERun; rw [← hres]
        exact run_andThen_with_fst_none _ _ G hERun fun _ => rfl
    · obtain ⟨hbad, hRch, hRt3, hsl, hfs, hcA, hcH, hcE, hRbR, hRaR, hRmR, hRhR, hRmO, hRaO, hRhO, hReC, hRt8⟩ :=
        incProve_ok (liftH G) V D t R hInc
      rw [hRch] at hbad hsl hRhR
      rw [hRt3] at hsl
      dsimp only [ch] at ht3Eq ht3Key
      rw [hbad, ht3Eq] at hres; simp only [Bool.not_false] at hres
      rw [hV_ns, hDslot] at hsl
      have hSlRun := stSlotsProveFixedProg_run_ok Lq hL20 key (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
        (incElog V.pub V.geo.bLogN) (Dslot (incCh (liftH G) V D t).1) Fp2.zero Fp2.zero Fp2.zero G
        (hfitSc _) (hfitTerms _) 4 [] 0 {} _ ht3Key R.seg.core.slots R.recs R.acc R.t4 hsl
      rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
      simp only [decide_eq_true hfs] at hres
      have ht4Key : R.t4.key = key := (stSlotsProve_key (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D t).1))
        (incElog V.pub V.geo.bLogN) _ Fp2.zero Fp2.zero Fp2.zero 4 [] 0 {} _ R.seg.core.slots R.recs R.acc R.t4 hsl).trans ht3Key
      have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M0 4 trM0 (R.acc.fs ++ R.acc.hostFs) R.t4 ht4Key G
        (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM0.2
      rw [hDmOpen] at hRmO
      have hMRun' : (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M0 4 trM0 (R.acc.fs ++ R.acc.hostFs) R.t4).run G = (R.seg.core.maskOpen, R.t5) :=
        hMRun.trans hRmO.symm
      rw [run_andThen_with _ _ G _ hMRun'] at hres; dsimp only at hres
      have ht5Key : R.t5.key = key := (congrArg (fun p => p.2.key) hRmO).trans (bMask_key (liftH G) tag shdP_U shdP_hbij M0 4 (R.acc.fs ++ R.acc.hostFs) R.t4 key ht4Key)
      dsimp only [IncV.checkOpening] at hcA; rw [hV_logN] at hcA
      have hARun := openingAuditFixedProg_run_ok Lq hL20 tag key shdP_stgPrm 14 3 41 3 hStgNN hStgNQ
        (shdP_incOpenGeomA V) TA0 hTA0r hV_aR rfl trA0 R.acc.claims.a R.t5 ht5Key G hStgFit.1 hStgFit.2
        (fun og haud hog _ => by
          rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length R.acc.claims.a 12 og hog]
          have haud' : auditClaims R.acc.claims.a (2 ^ 12) 41 (List.range' 33 (2 * 3)) none V.lay.aProx = .ok () := by
            rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomA] at haud; rw [hV_aR, hV_siteA] at haud
            rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
          exact auditClaims_length_none R.acc.claims.a (2 ^ 12) 41 33 3 V.lay.aProx (by norm_num) haud') hTreeA0.2 hcA
      rw [hStgLog] at hARun
      rw [hDaOpen] at hRaO
      have hARun' : (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V) TA0 trA0 true
          (openingHdrOk (shdP_incOpenGeomA V) 12 R.acc.claims.a) R.acc.claims.a R.t5).run G = (some R.seg.core.aOpen, R.t6) :=
        hARun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRaO.symm) : some _ = some R.seg.core.aOpen) (congrArg Prod.snd hRaO.symm : _ = R.t6))
      rw [run_andThen_with _ _ G _ hARun'] at hres; dsimp only at hres
      simp only [Option.isSome_some, Bool.true_and] at hres
      have ht6Key : R.t6.key = key := (congrArg (fun p => p.2.key) hRaO).trans (bOpen_key (liftH G) tag shdP_stgPrm 14 TA0 R.acc.claims.a R.t5 key ht5Key)
      dsimp only [IncV.checkOpening] at hcH; rw [hV_logN] at hcH
      have hHRun := openingAuditFixedProg_run_ok Lq hL20 tag key shdP_stgPrm 14 4 76 4 hStgNN hStgNQ
        (shdP_incOpenGeomH V) (TH (incCh (liftH G) V D t).1) (hTHr _) hV_hR rfl trH0 (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 ht6Key G hStgFit.1 hStgFit.2
        (fun og haud hog _ => by
          rw [hStgLog] at hog; rw [openingGroupsAt_sum_eq_length _ 12 og hog]
          have haud' : auditClaims (R.acc.claims.h ++ [V.lay.logupSumClaim]) (2 ^ 12) 76
              (List.range' 68 (2 * 3)) (some V.lay.hURows) V.lay.hProx = .ok () := by
            rw [hStgLog] at haud; dsimp only [shdP_incOpenGeomH] at haud; rw [hV_hR, hV_siteH] at haud
            rw [show (2 : ℕ) * 3 = 6 by norm_num]; exact haud
          exact auditClaims_length_some_last R.acc.claims.h V.lay.logupSumClaim hV_sumH
            (2 ^ 12) 76 68 3 V.lay.hURows.1 V.lay.hURows.2 V.lay.hProx (by norm_num) haud') hTreeH0.2 hcH
      rw [hStgLog] at hHRun
      rw [hDhOpen] at hRhO
      have hHRun' : (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V) (TH (incCh (liftH G) V D t).1) trH0 true
          (openingHdrOk (shdP_incOpenGeomH V) 12 (R.acc.claims.h ++ [V.lay.logupSumClaim])) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).run G = (some R.seg.core.hOpen, R.t7) :=
        hHRun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRhO.symm) : some _ = some R.seg.core.hOpen) (congrArg Prod.snd hRhO.symm : _ = R.t7))
      rw [run_andThen_with _ _ G _ hHRun'] at hres; dsimp only at hres
      simp only [Option.isSome_some] at hres
      have ht7Key : R.t7.key = key := (congrArg (fun p => p.2.key) hRhO).trans (bOpen_key (liftH G) tag shdP_stgPrm 14 (TH (incCh (liftH G) V D t).1) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 key ht6Key)
      have hERun := openingAuditFixedProg_run_ep_ok Lq hL20 tag key shdP_epPrm 11
        (by norm_num [shdP_epPrm, PcsPrm.nn]) (by norm_num [shdP_epPrm])
        V.geo.epDataRows V.pub.epN shdP_epOpenGeom
        (by rw [hV_epDR]; rfl) (by rw [hV_epDR]; rfl) TE
        (by rw [hV_epDR]; exact hTEr) treeTE R.acc.claims.inp R.t7 ht7Key G hEpFit.1 hEpFit.2 hTE hcE
      rw [hEp6] at hERun
      rw [hDepOpen] at hReC hRt8
      generalize heO : (bOpen (liftH G) tag shdP_epPrm 11 TE R.acc.claims.inp R.t7).1 = eO at hERun hReC
      have hERun' : (openingAuditFixedProg Lq hL20 key shdP_epPrm 11 1 6 1 shdP_epOpenGeom TE treeTE true
          (tokenEpHdrOk R.acc.claims.inp V.geo.epDataRows V.pub.epN) R.acc.claims.inp R.t7).run G = (some eO, R.t8) :=
        hERun.trans (Prod.ext rfl hRt8.symm)
      rw [run_andThen_with _ _ G _ hERun'] at hres; dsimp only at hres
      rw [ite_eq_left trivial, PProg.run] at hres
      dsimp only [ch] at hTreeH0
      have hsegEq : (⟨some trB0.getRoot, ⟨trA0.getRoot, trH0.getRoot, trM0.getRoot, R.seg.core.slots, R.seg.core.maskOpen, R.seg.core.aOpen, R.seg.core.hOpen⟩,
          [eO]⟩ : StageSeg) = R.seg := by
        refine (stageSeg_eq ?_ ?_ ?_ ?_ ?_).trans (stageSeg_eta R.seg)
        · rw [hRbR, hTreeB0.1, hDbR]
        · rw [hRaR, hTreeA0.1, hDaR]
        · rw [hRhR, hTreeH0.1, hDhR]
        · rw [hRmR, hTreeM0.1, hDmR]
        · exact hReC.symm
      have hbEq : trB0.getRoot = D.bRoot := hTreeB0.1.trans hDbR.symm
      rw [hsegEq, hbEq] at hres
      exact ⟨congrArg Prod.fst hres.symm, congrArg (fun p => p.2.2) hres.symm⟩

private def exceptMapRes {α β₁ β₂ β₃ : Type} (f1 : α → β₁) (f2 : α → β₂) (f3 : α → β₃)
    (e : Except Unit α) : Except Unit (β₁ × β₂ × β₃) :=
  match e with
  | .error _ => .error ()
  | .ok a => .ok (f1 a, f2 a, f3 a)

private theorem inSegP_incP_abs_run {Hdr Coins : Type} (tag : MTag) (V : IncV)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V)
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins)
    (bnd startTag : Dig) (cr0 : Carry) (t : Tr)
    (D : IncData V) (hD : D = incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H st x c) t) :
    (inSegP _ (incP_abs tag V C)).run H st x c bnd startTag cr0 t
      = exceptMapRes (fun (R : IncRun) e => encStage (rcIncGeom V 28) bnd startTag R.seg e)
          (fun (R : IncRun) => ({ pending := R.acc.claims.out, root := D.bRoot } : Carry))
          (fun (R : IncRun) => R.t8) (incProve H V D t) := by
  subst hD
  dsimp only [inSegP, incP_abs, Bind.bind, Except.bind, exceptMapRes]
  cases incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H st x c) t) t <;> rfl

private theorem inSegP_shdP_incP_eq {Hdr Coins : Type} (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow)) :
    inSegP (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))
        (shdP_incP tag Rp embDigest bInRow C)
      = inSegP (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => rcIncGeom (shdVi tag Rp embDigest bInRow) 28))
          (incP_abs tag (shdVi tag Rp embDigest bInRow) C) := rfl

private theorem incDataAt_hOpen_eq (H : HIn → Dig) (tag : MTag) (V : IncV) (C : IncTables V) (t : Tr)
    (hV_lt : V.pub.lt = 12) (TH : List Fp2 → Table) (hTH : C.TH = TH) :
    (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 C t).hOpen =
      bOpen H tag shdP_stgPrm 14 (TH (incCh H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 C t) t).1) := by
  have hch := incChOf_data (K := shdP_K) H tag shdP_U shdP_hbij V 2 3 256 256 C t
  have h12 : (12 : ℕ) + 2 = 14 := rfl
  have h22 : (2 : ℕ) ^ 2 = 4 := by norm_num
  change bOpen H tag ⟨V.pub.lt, 2 ^ 2, 256, 256⟩ (V.pub.lt + 2) (C.TH _) = _
  rw [hch, hTH, hV_lt, h12, h22]; rfl

/-- **Exact `.run` equivalence for `incSegFixedProg`**:
agrees verbatim with `(inSegP _ (shdP_incP ...)).run (liftH G)` AND returns cached `treeB0` matching `TB_0`! -/
theorem incSegFixedProg_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (treeTE : MerkleLevels 11)
    (st : ClsStmt Hdr) (bnd startTag : Dig) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hTE : ∀ (j : ℕ) (hj : j < 2 ^ 11),
      treeTE.path j hj = pathOf (liftH G) tag 11 (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) j) :
    let res := (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t).run G
    (res.2.1.getRoot = rootOf (liftH G) tag 16 (shdP_incTB Rp x (shdIncRndOf c))
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), res.2.1.path j hj = pathOf (liftH G) tag 16 (shdP_incTB Rp x (shdIncRndOf c)) j)
    ∧ match (inSegP _ (shdP_incP tag Rp embDigest bInRow
        (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c')))).run
          (liftH G) st x c bnd startTag carry0 t with
      | .ok (enc, cr, t') => res.1 = some (enc, cr) ∧ res.2.2 = t'
      | .error () => res.1 = none := by
  dsimp only
  let V := shdVi tag Rp embDigest bInRow
  let rnd := shdIncRndOf c
  let TB0 := shdP_incTB Rp x rnd
  let TA0 := shdP_incTA x rnd
  let M0 := shdP_incM rnd
  let TE := shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)
  let D := incDataAt (liftH G) tag shdP_U shdP_hbij V 2 3 256 256
    (shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow (liftH G) x (shdEpBase c) rnd) t
  have hnums := shdP_incLay_nums Rp embDigest (embFoldL Rp.inp)
  have hV_aR : V.lay.aRows = 41 := hnums.1
  have hV_hR : V.lay.hRows = 76 := hnums.2.1
  have hV_lt : V.pub.lt = 12 := rfl
  have hV_lt2 : V.pub.lt + 2 = 14 := rfl
  have hV_ep : V.pub.epLogN = 8 := rfl
  have hV_hd : incHeadDraws V.pub = 15 :=
    (shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)).2.2.2.2
  have hV_siteA : V.lay.aSiteRows = List.range' 33 6 := by
    have haM : V.lay.aMaskBase = 33 := by
      unfold V shdVi shdP_incV; change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).aMaskBase = 33
      obtain ⟨hti, hvoc, hep, _, _⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
      have hepc : clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords = 8 := by rw [hep, shdP_clog2_256]
      have hlt : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).lt = 12 := rfl
      simp only [incLay, incSched, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL, rowsOf, hti, hvoc, hepc, hlt]
      norm_num
    have haP : V.lay.aProx = 39 := by change V.lay.aRows - 2 = 39; omega
    unfold Lay.aSiteRows; rw [haM, haP]
  have hV_siteH : V.lay.hSiteRows = List.range' 68 6 := by
    have hhM : V.lay.hMaskBase = 68 := by
      unfold V shdVi shdP_incV; change (incLay (shdP_incPub Rp embDigest (embFoldL Rp.inp)) 14).hMaskBase = 68
      obtain ⟨hti, hvoc, hep, _, _⟩ := shdP_incPub_logs Rp embDigest (embFoldL Rp.inp)
      have hepc : clog2 (shdP_incPub Rp embDigest (embFoldL Rp.inp)).inEpWords = 8 := by rw [hep, shdP_clog2_256]
      have hlt : (shdP_incPub Rp embDigest (embFoldL Rp.inp)).lt = 12 := rfl
      simp only [incLay, incSched, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL, rowsOf, hti, hvoc, hepc, hlt]
      norm_num
    have hhP : V.lay.hProx = 74 := by change V.lay.hRows - 2 = 74; omega
    unfold Lay.hSiteRows; rw [hhM, hhP]
  have hV_sumH : V.lay.logupSumClaim.parts.all (fun p => p.point.isEmpty) = true := by
    rw [List.all_eq_true]; intro p hp
    unfold Lay.logupSumClaim at hp
    obtain ⟨i, _, hi⟩ := List.mem_flatMap.mp hp
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hi
    rcases hi with rfl | rfl <;> rfl
  have h22 : (2 : ℕ) ^ 2 = 4 := by norm_num
  have h23 : (2 : ℕ) ^ 3 = 8 := by norm_num
  have h12 : (12 : ℕ) + 2 = 14 := rfl
  have h83 : (8 : ℕ) + 3 = 11 := rfl
  have hV_logN : V.lay.logN = 12 := rfl
  have hProg : incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t
      = incSegFixedProg_abs Lq hL20 tag key V (rcIncGeom V 28) embDigest TB0 TA0 TE
          (shdP_incTB_cols_len Rp x rnd) (shdP_incTA_cols_len x rnd)
          M0 (fun ch => shdP_incTH Rp embDigest x rnd ch) (fun ch => shdP_incTH_cols_len Rp embDigest x rnd ch)
          (fun ch => shdP_incSlotData tag Rp embDigest bInRow ch TA0 (shdP_incTH Rp embDigest x rnd ch) TE TB0 rnd)
          treeTE bnd startTag t := rfl
  have hAbs := incSegFixedProg_run_abs Lq hL20 tag key V (rcIncGeom V 28) embDigest
    TB0 TA0 TE (shdP_incTB_cols_len Rp x rnd) (shdP_incTA_cols_len x rnd)
    (shdP_incTA_rows_len x rnd).symm (by rw [shdP_epTable_rows_length])
    M0 (fun ch => shdP_incTH Rp embDigest x rnd ch) (fun ch => shdP_incTH_cols_len Rp embDigest x rnd ch)
    (fun ch => (shdP_incTH_rows_len Rp embDigest x rnd ch).symm)
    (fun ch => shdP_incSlotData tag Rp embDigest bInRow ch TA0 (shdP_incTH Rp embDigest x rnd ch) TE TB0 rnd)
    t G D
    (by dsimp only [D, incDataAt, shdP_incTables])
    (by dsimp only [D, incDataAt, shdP_incTables]; rw [hV_lt2])
    (by dsimp only [D, incDataAt, shdP_incTables])
    (fun _ => by dsimp only [D, incDataAt, shdP_incTables]; rw [hV_lt2])
    (fun _ => rfl)
    (by dsimp only [D, incDataAt, shdP_incTables])
    (by dsimp only [D, incDataAt, shdP_incTables, shdP_stgPrm]; rw [hV_lt, h12, h22])
    (incDataAt_hOpen_eq (liftH G) tag V _ t hV_lt (fun ch => shdP_incTH Rp embDigest x rnd ch) rfl)
    (by dsimp only [D, incDataAt, shdP_incTables, shdP_epPrm]; rw [hV_ep, h83, h23])
    hV_aR hV_hR hV_logN rfl hV_hd rfl rfl hV_siteA hV_siteH hV_sumH
    (fun ch s hist acc t' df _ => polySlotData_fitSc hL20
      (atLog (V.bp (incCtx V.pub ch)) (incElog V.pub V.geo.bLogN s)) _ _ _
      (shdP_inc_slotD_le5 tag Rp embDigest bInRow (incCtx V.pub ch)) G s hist acc t' df)
    (fun ch => shdP_inc_terms_fit hL20 tag Rp embDigest bInRow ch TA0 (shdP_incTH Rp embDigest x rnd ch) TE TB0 rnd G)
    treeTE bnd startTag htKey hTE
  rw [hProg]
  generalize (incSegFixedProg_abs Lq hL20 tag key V (rcIncGeom V 28) embDigest TB0 TA0 TE
    (shdP_incTB_cols_len Rp x rnd) (shdP_incTA_cols_len x rnd)
    M0 (fun ch => shdP_incTH Rp embDigest x rnd ch) (fun ch => shdP_incTH_cols_len Rp embDigest x rnd ch)
    (fun ch => shdP_incSlotData tag Rp embDigest bInRow ch TA0 (shdP_incTH Rp embDigest x rnd ch) TE TB0 rnd)
    treeTE bnd startTag t).run G = res at hAbs ⊢
  refine ⟨hAbs.1, ?_⟩
  have hInSeg :
      inSegP (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))
          (shdP_incP tag Rp embDigest bInRow
            (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c')))
      = inSegP (incStageV (fun _ : Hdr => V) (fun _ => rcIncGeom V 28))
          (incP_abs tag V
            (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c'))) :=
    inSegP_shdP_incP_eq (Hdr := Hdr) tag Rp embDigest bInRow
      (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c'))
  rw [hInSeg, inSegP_incP_abs_run tag V
    (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c'))
    (liftH G) st x c bnd startTag carry0 t D rfl]
  generalize hInc : incProve (liftH G) V D t = eInc
  cases eInc with
  | error u => cases u; dsimp only [exceptMapRes]; exact hAbs.2.1 hInc
  | ok R => dsimp only [exceptMapRes]; exact hAbs.2.2 R hInc

theorem incSegFixedSliceSpec {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (treeTE : MerkleLevels 11)
    (bnd startTag : Dig) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) :
    SliceSpec Lq tag key domain shape c
      (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t)
      base incSegFixedLen incSegFixedQ 605 605 102400 102396
      st (trChainTip base incSegFixedLen (by unfold incSegFixedLen; omega))
      incTreeSet (incSegFixedSched (shdP_P0in tag Rp embDigest (embFoldL Rp.inp) bInRow) base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.1 = levelsOfV v 16 base ∧ res.2.2.state = v (base + incSegFixedLen - 1)) := by
  let V := shdVi tag Rp embDigest bInRow
  let P0in := shdP_P0in tag Rp embDigest (embFoldL Rp.inp) bInRow
  let b0 := base + 131071
  let b1 := b0 + 1
  let b2 := b1 + 1
  let b5 := b2 + 3
  let bA := b5 + 32767
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bCh := bM1 + 15
  let bH := bCh + 32767
  let bH3 := bH + 3
  let bSl := bH3 + 167
  let bMo := bSl + 77
  let bAo := bMo + 112
  let bHo := bAo + 149
  let bEo := bHo + 73
  let st0 : TrChainState b0 := ⟨st.hasTip, st.trTip, fun ht => by have := st.htip_lt ht; omega, st.afterPosTag, st.hpos⟩
  let st1 := trChainTip b0 1 Nat.zero_lt_one
  let st2 := trChainTip b1 1 Nat.zero_lt_one
  let st5 := trChainTip b2 3 (by norm_num)
  let stA : TrChainState bA := ⟨true, b5 - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stA3 := trChainTip bA 3 (by norm_num)
  let stM : TrChainState bM := ⟨true, bA3 - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stM1 := trChainTip bM 1 Nat.zero_lt_one
  let stCh := trChainTip bM1 15 (by norm_num)
  let stH : TrChainState bH := ⟨true, bCh - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stH3 := trChainTip bH 3 (by norm_num)
  let stSl := trChainTip bH3 167 (by norm_num)
  let stMo := trChainTip bSl 77 (by norm_num)
  let stAo := trChainTip bMo 112 (by norm_num)
  let stHo := trChainTip bAo 149 (by norm_num)
  let stEo := trChainTip bHo 73 (by norm_num)
  have hB0s : ∀ j : Fin (2 ^ 16), (shdP_incTB Rp x (shdIncRndOf c)).salts j.val = shdLeafSalt c ⟨.bnd ⟨0, by decide⟩, j⟩ := fun j => by
    dsimp only [shdP_incTB, mkPcsTable, shdIncRndOf, shdBndRndOf, shdLeafSalt]; exact extSalt_lt _ j.isLt
  have hIHs := incSalts_eq_shdLeafSalt c
  have hA0s : ∀ j : Fin (2 ^ 14), (shdP_incTA x (shdIncRndOf c)).salts j.val = shdLeafSalt c ⟨.a ⟨0, by decide⟩, j⟩ :=
    fun j => hIHs.1 j
  have hM0s : ∀ j : Fin (2 ^ 12), (mTab 4 (cosetPt (rootFp 12)) (shdP_incM (shdIncRndOf c))).salts j.val = shdLeafSalt c ⟨.m ⟨0, by decide⟩, j⟩ := fun j => by
    dsimp only [mTab, shdP_incM, mkMTable, shdIncRndOf, shdLeafSalt]; exact extSalt_lt _ j.isLt
  have hH0s : ∀ ch (j : Fin (2 ^ 14)), (shdP_incTH Rp embDigest x (shdIncRndOf c) ch).salts j.val = shdLeafSalt c ⟨.h ⟨0, by decide⟩, j⟩ :=
    fun _ j => hIHs.2 j
  unfold incSegFixedProg incSegFixedSched; dsimp only
  -- Step 1: B_0 (depth 16)
  refine SliceSpec.seq (len₂ := 74330) (nQ₂ := 111194) (nTrK₂ := 605) (nT₂ := 605) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b0 74330 (by norm_num))
    (trees₂ := fun tid => tid = .a ⟨0, by decide⟩ ∨ tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    (merkleTableSliceSpec_tree (Lq := Lq) (by omega) hsep domain shape c (.bnd ⟨0, by decide⟩) 16 rfl 38 (by omega)
      (shdP_incTB Rp x (shdIncRndOf c)) (shdP_incTB_cols_len Rp x (shdIncRndOf c)) hB0s
      base 131071 196607 65536 65535 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      st st0 ⟨rfl, rfl, rfl⟩ (fun _ v => t.state = v st.trTip))
    (fun treeB0 => ?_) (fun _ hb h => by subst hb; rcases h with h | h | h <;> cases h)
    (by unfold incSegFixedLen; omega) (by unfold incSegFixedQ; omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by have : incSegFixedLen = 205401 := rfl; omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 2: labRunStage
  refine SliceSpec.seq (len₂ := 74329) (nQ₂ := 111193) (nTrK₂ := 604) (nT₂ := 604) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b1 74329 (by norm_num))
    (trees₂ := fun tid => tid = .a ⟨0, by decide⟩ ∨ tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    ((trAbsorbSliceSpec hL20 hsep domain shape c t labRunStage (by decide) (by decide) (le64 (UInt64.ofNat 0)) b0 st0 htip).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun tf1 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 3: labRunBlock
  refine SliceSpec.seq (len₂ := 74328) (nQ₂ := 111192) (nTrK₂ := 603) (nT₂ := 603) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b2 74328 (by norm_num))
    (trees₂ := fun tid => tid = .a ⟨0, by decide⟩ ∨ tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    ((trAbsorbSliceSpec hL20 hsep domain shape c tf1 labRunBlock (by decide) (by decide) embDigest.toList b1 st1 rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun tf2 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 4: labB
  refine SliceSpec.seq (len₂ := 74325) (nQ₂ := 111189) (nTrK₂ := 600) (nT₂ := 600) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b5 74325 (by norm_num))
    (trees₂ := fun tid => tid = .a ⟨0, by decide⟩ ∨ tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    ((absorbRootSliceSpec hL20 hsep domain shape c tf2 labB (by decide) (by decide) treeB0.getRoot V.geo.bRows V.geo.bLogN b2 st2 rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun tf5 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 5: A_0 (depth 14)
  refine SliceSpec.seq (len₂ := 41558) (nQ₂ := 62038) (nTrK₂ := 600) (nT₂ := 600) (nL₂ := 20480) (nN₂ := 20478)
    (st₂ := trChainTip bA 41558 (by norm_num))
    (trees₂ := fun tid => tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.a ⟨0, by decide⟩) 14 rfl 41 (by omega)
      (shdP_incTA x (shdIncRndOf c)) (shdP_incTA_cols_len x (shdIncRndOf c)) hA0s
      b5 32767 49151 16384 16383 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      st5 stA ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => tf5.state = v (b5 - 1) ∧ treeB0 = levelsOfV v 16 base))
    (fun treeA0 => ?_) (fun _ ha h => by subst ha; rcases h with h | h <;> cases h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => ⟨by rw [show b5 - 1 = b2 + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 6: labA
  refine SliceSpec.seq (len₂ := 41555) (nQ₂ := 62035) (nTrK₂ := 597) (nT₂ := 597) (nL₂ := 20480) (nN₂ := 20478)
    (st₂ := trChainTip bA3 41555 (by norm_num))
    (trees₂ := fun tid => tid = .m ⟨0, by decide⟩ ∨ tid = .h ⟨0, by decide⟩)
    ((absorbRootSliceSpec hL20 hsep domain shape c tf5 labA (by decide) (by decide) treeA0.getRoot V.lay.aRows V.lay.logN bA stA rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun tA => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 7: M_0 (depth 12)
  refine SliceSpec.seq (len₂ := 33364) (nQ₂ := 49748) (nTrK₂ := 597) (nT₂ := 597) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bM 33364 (by norm_num))
    (trees₂ := fun tid => tid = .h ⟨0, by decide⟩)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.m ⟨0, by decide⟩) 12 rfl (2 * 4 + 4) (by omega)
      (mTab 4 (cosetPt (rootFp 12)) (shdP_incM (shdIncRndOf c))) (fun j => mCol_length 4 _ _ j.val) hM0s
      bA3 8191 12287 4096 4095 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stA3 stM ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => tA.state = v (bA3 - 1) ∧ treeB0 = levelsOfV v 16 base))
    (fun treeM0 => ?_) (fun _ hm hh => by subst hm; cases hh)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => ⟨by rw [show bA3 - 1 = bA + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 8: labM
  refine SliceSpec.seq (len₂ := 33363) (nQ₂ := 49747) (nTrK₂ := 596) (nT₂ := 596) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bM1 33363 (by norm_num))
    (trees₂ := fun tid => tid = .h ⟨0, by decide⟩)
    ((trAbsorbSliceSpec hL20 hsep domain shape c tA labM (by decide) (by decide) treeM0.getRoot.toList bM stM rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun tM => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 9: 15 challenges
  refine SliceSpec.seq (len₂ := 33348) (nQ₂ := 49732) (nTrK₂ := 581) (nT₂ := 581) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bCh 33348 (by norm_num))
    (trees₂ := fun tid => tid = .h ⟨0, by decide⟩)
    ((trChallengeFp2VecSliceSpec_n (Lq := Lq) (by omega) hsep domain shape c 15 (by norm_num) tM bM1 stM1 rfl rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun chR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 10: H_0 (depth 14)
  refine SliceSpec.seq (len₂ := 581) (nQ₂ := 581) (nTrK₂ := 581) (nT₂ := 581) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH 581 (by norm_num))
    (trees₂ := fun _ => False)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.h ⟨0, by decide⟩) 14 rfl 76 (by omega)
      (shdP_incTH Rp embDigest x (shdIncRndOf c) chR.1) (shdP_incTH_cols_len Rp embDigest x (shdIncRndOf c) chR.1)
      (hH0s chR.1) bCh 32767 49151 16384 16383 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stCh stH ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => chR.2.state = v (bCh - 1) ∧ treeB0 = levelsOfV v 16 base))
    (fun treeH0 => ?_) (fun _ _ h => h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with rfl | hf; exact rfl; cases hf) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 11: labH
  refine SliceSpec.seq (len₂ := 578) (nQ₂ := 578) (nTrK₂ := 578) (nT₂ := 578) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH3 578 (by norm_num))
    (trees₂ := fun _ => False)
    ((absorbRootSliceSpec hL20 hsep domain shape c chR.2 labH (by decide) (by decide) treeH0.getRoot V.lay.hRows V.lay.logN bH stH rfl).andInv
      (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun t3 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 12: 4 stSlots
  have hslLen : slotsFixedLen (V.bp (incCtx V.pub chR.1)) 0 4 = 167 :=
    shdP_inc_slotsFixedLen tag Rp embDigest (embFoldL Rp.inp) bInRow (incCtx V.pub chR.1)
  have hslSched : slotsFixedSched (V.bp (incCtx V.pub chR.1)) 0 4 bH3 (bH3 - 1)
      = slotsFixedSched P0in 0 4 bH3 (bH3 - 1) :=
    (slotsFixedSched_of_stgSame (shdP_hPin (Hdr := Unit) tag Rp embDigest (embFoldL Rp.inp) bInRow () (incCtx V.pub chR.1)) 0 4 bH3 (bH3 - 1)).symm
  have hSl : SliceSpec Lq tag key domain shape c
      (stSlotsProveFixedProg Lq hL20 key (V.bp (incCtx V.pub chR.1)) (incElog V.pub V.geo.bLogN)
        (shdP_incSlotData tag Rp embDigest bInRow chR.1 (shdP_incTA x (shdIncRndOf c))
          (shdP_incTH Rp embDigest x (shdIncRndOf c) chR.1) (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c))
          (shdP_incTB Rp x (shdIncRndOf c)) (shdIncRndOf c))
        Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub chR.1)) [] 0 {} t3)
      bH3 167 167 167 167 0 0 stH3 stSl (fun _ => False) (slotsFixedSched P0in 0 4 bH3 (bH3 - 1))
      (fun _ v => t3.state = v (bH3 - 1)) (fun _ v res => res.2.state = v (bH3 + 167 - 1)) := by
    rw [← hslSched]
    exact stSlotsProveFixedSliceSpec_n hL20 hsep domain shape c (V.bp (incCtx V.pub chR.1))
      (incElog V.pub V.geo.bLogN) _ Fp2.zero Fp2.zero Fp2.zero 4 (!incAlphaBad (incCtx V.pub chR.1)) [] 0 {} t3
      bH3 167 hslLen (by norm_num) stH3 rfl rfl (bH3 - 1) (sub1_eq_trChainTip (by norm_num) (by omega)).symm
  refine SliceSpec.seq (len₂ := 411) (nQ₂ := 411) (nTrK₂ := 411) (nT₂ := 411) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bSl 411 (by norm_num))
    (trees₂ := fun _ => False)
    (hSl.andInv (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun slR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf)
    (fun _ _ hp => ⟨by rw [show bH3 - 1 = bH + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 13: M_0 mask opening (77)
  refine SliceSpec.seq (len₂ := 334) (nQ₂ := 334) (nTrK₂ := 334) (nT₂ := 334) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bMo 334 (by norm_num))
    (trees₂ := fun _ => False)
    ((zkBMaskFixedSliceSpec_n hL20 hsep domain shape c shdP_U shdP_hbij _ (shdP_incM (shdIncRndOf c)) 4 treeM0 _ slR.2 bSl 77
      (by unfold zkBMaskFixedLen; norm_num) (by norm_num) stSl rfl rfl).andInv (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun mR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 14: A_0 opening (112)
  refine SliceSpec.seq (len₂ := 222) (nQ₂ := 222) (nTrK₂ := 222) (nT₂ := 222) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bAo 222 (by norm_num))
    (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c shdP_stgPrm 14 3 41 3 (shdP_incOpenGeomA V)
      (shdP_incTA x (shdIncRndOf c)) treeA0 _ _ _ mR.2 bMo 112
      (by unfold openingAuditFixedLen shdP_stgPrm; norm_num) (by norm_num) stMo rfl rfl).andInv (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun aR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 15: H_0 opening (149)
  refine SliceSpec.seq (len₂ := 73) (nQ₂ := 73) (nTrK₂ := 73) (nT₂ := 73) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bHo 73 (by norm_num))
    (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c shdP_stgPrm 14 4 76 4 (shdP_incOpenGeomH V)
      (shdP_incTH Rp embDigest x (shdIncRndOf c) chR.1) treeH0 _ _ _ aR.2 bAo 149
      (by unfold openingAuditFixedLen shdP_stgPrm; norm_num) (by norm_num) stAo rfl rfl).andInv (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun hR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 16: TE opening (73) + ret
  refine SliceSpec.seq (len₂ := 0) (nQ₂ := 0) (nTrK₂ := 0) (nT₂ := 0) (nL₂ := 0) (nN₂ := 0)
    (st₂ := stEo) (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c shdP_epPrm 11 1 6 1 shdP_epOpenGeom
      (shdP_epTable (Hdr := Hdr) tag x (shdEpBase c)) treeTE _ _ _ hR.2 bHo 73
      (by unfold openingAuditFixedLen shdP_epPrm; norm_num) (by norm_num) stHo rfl rfl).andInv (fun _ v => treeB0 = levelsOfV v 16 base))
    (fun eR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, rfl, rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hEoEq : bHo + 73 - 1 = base + incSegFixedLen - 1 := by
    have : incSegFixedLen = 205401 := rfl; omega
  cases slR.1 <;> cases aR.1 <;> cases hR.1 <;> cases eR.1 <;> (try split_ifs) <;>
    exact retSliceSpec _ bEo stEo _ _ (fun _ _ hp => ⟨hp.2, by rw [← hEoEq]; exact hp.1⟩) (fun _ => .absorb 0)

end IncSegFixed

/-! ## 4. Fixed-schedule Interior R13 Block `k : Fin 26` (`blkSegFixedProg` + `.run` + `SliceSpec`) -/

section BlkSegFixed

private theorem shdP_blk_slotD_le5 (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) (s : ℕ) :
    slotD (shdP_Pk0 tag ioIn ioOut checkOpening Rp k) s ≤ 5 := by
  by_cases hs : s < 23
  · obtain ⟨_, h5, _, _⟩ := Exec.Block.R13.shield_slot_facts s hs
    change ((shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.getD s (0, 0, 0)).2.2 ≤ 5
    rw [shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk]; exact h5
  · change ((shdP_Pk0 tag ioIn ioOut checkOpening Rp k).geom.slots.getD s (0, 0, 0)).2.2 ≤ 5
    rw [shdP_Pk0_slots tag ioIn ioOut checkOpening Rp hR k hk,
      List.getD_eq_getElem?_getD, List.getElem?_eq_none (by show 23 ≤ s; omega)]; exact Nat.zero_le 5

private theorem shdP_blk_terms_fit {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26)
    {xIn xOut : shieldS0.Pos → ℤ} (w : BlkWitness (shdP_layer k hk) (shdP_blkPub Rp hR k hk) xIn xOut)
    (TB_prev TB_next : Table) (rnd : BlkRand) (G : QB Lq → Dig) :
    let P := shdP_Pk0 tag ioIn ioOut checkOpening Rp k
    let D := blkSlotData P w (blkTA w rnd) TB_prev TB_next rnd
    ∀ s hist acc t df,
      P.define s hist (t.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) P D s hist acc t df).terms.length * 16 ≤ Lq := by
  intro P D s hist acc t df _ hchk
  have hlen : (slotSP (liftH G) P D s hist acc t df).terms.length = (df.tabs.filter Exec.Block.Tab.isPriv).length := by
    unfold slotSP D; dsimp only
    exact blkSlotData_terms_length P w (blkTA w rnd) TB_prev TB_next rnd s hist acc df _ _
  have hn := slotDefChecks_nPriv P s acc df hchk
  have hst : Exec.Block.slotTerms P s ≤ 100 := by
    unfold Exec.Block.slotTerms P
    rw [shdP_Pk0_geom50 tag ioIn ioOut checkOpening Rp hR k hk]
    change Exec.Block.R13.shieldTerms.getD s 0 ≤ 100
    by_cases hs : s < 23
    · have hbd : ∀ i : Fin 23, Exec.Block.R13.shieldTerms.getD i.val 0 ≤ 100 := by decide
      exact hbd ⟨s, hs⟩
    · rw [List.getD_eq_getElem?_getD, List.getElem?_eq_none (by have : Exec.Block.R13.shieldTerms.length = 23 := (by decide); omega)]
      exact Nat.zero_le 100
  have hlab : Exec.Block.labPbTerm.length = 7 := by decide
  rw [hlen, hn, hlab]; omega

private theorem shdP_blk_logupSumClaim_empty (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp) (k : ℕ) (hk : k < 26) :
    (shdP_Pk0 tag ioIn ioOut checkOpening Rp k).logupSumClaim.parts.all (fun p => p.point.isEmpty) = true := by
  rw [shdP_Pk0_eq_blkParams tag ioIn ioOut checkOpening Rp hR k hk]
  change (Exec.Block.Join.R13H.Look.logupSumR13 (Exec.Block.DefR13.cfgShieldR13 (shdP_layer k hk))).parts.all
    (fun p => p.point.isEmpty) = true
  rw [List.all_eq_true]; intro p hp
  unfold Exec.Block.Join.R13H.Look.logupSumR13 at hp
  obtain ⟨i, _, hi⟩ := List.mem_flatMap.mp hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hi
  rcases hi with rfl | rfl <;> rfl

/-- **Fixed-schedule Interior R13 Block `k : Fin 26` (`412,266` `.pt`s, `612,970` total queries)**:
commits `B_{k+1}` (`2^16`), absorbs `blockFrame` (`5`), commits `A_{k+1}` (`2^16`), absorbs `A_{k+1}` (`3`),
commits `M_{k+1}` (`2^12`), absorbs `M_{k+1}` (`1`), draws `(β, γ, α)` (`3`), checks `blkAlphaBad`,
commits `H_{k+1}` (`2^16`), absorbs `H_{k+1}` (`3`), runs `23` fixed-schedule slots (`1283`), `M_{k+1}`
opening (`115`), `A_{k+1}` opening (`4824`), `H_{k+1}` opening (`4518`), and cached `B_k` opening (`107`). -/
noncomputable def blkSegFixedProg {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) :=
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
  let P := Pk k.val
  let Ly := shdP_layer k.val k.isLt
  let Pb := shdP_blkPub Rp hR k.val k.isLt
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
  let rnd := shdBlkRndOf c k
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TA := blkTA w rnd
  let M := blkTM rnd
  let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
  (merkleTableProg Lq (by omega) tag 16 38 (by omega) TBnext
      (fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)).andThen fun treeBNext =>
    let bRoot := treeBNext.getRoot
    (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat (k.val + 1)))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) (blkDig k).toList).andThen fun tf2 =>
        (absorbRootKeyed Lq hL20 key tf2 labB (by decide) bRoot 38 14).andThen fun tFrame =>
          (merkleTableProg Lq (by omega) tag 16 4577 (by omega) TA
              (fun j => by rw [blkTA_cols_len, blkTA_rows_len])).andThen fun treeA =>
            let aRoot := treeA.getRoot
            (absorbRootKeyed Lq hL20 key tFrame labA (by decide) aRoot P.aRows P.logCols).andThen fun tA =>
              (merkleTableProg Lq (by omega) tag 12 (2 * 23 + 4) (by omega) (mTab 23 (cosetPt (rootFp 12)) M)
                  (fun j => mCol_length 23 _ M j.val)).andThen fun treeM =>
                let mRoot := treeM.getRoot
                (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
                  (trChallengeFp2Keyed Lq (by omega) key tM).andThen fun bR =>
                    (trChallengeFp2Keyed Lq (by omega) key bR.2).andThen fun gR =>
                      (trChallengeFp2Keyed Lq (by omega) key gR.2).andThen fun aR =>
                        let bga := (bR.1, gR.1, aR.1)
                        let TH := blkTH w rnd bga
                        let active1 := active && !blkAlphaBad Ly Pb bga
                        (merkleTableProg Lq (by omega) tag 16 4390 (by omega) TH
                            (fun j => by rw [blkTH_cols_len, blkTH_rows_len])).andThen fun treeH =>
                          let hRoot := treeH.getRoot
                          (absorbRootKeyed Lq hL20 key aR.2 labH (by decide) hRoot P.hRows P.logCols).andThen fun t3 =>
                            let Dslot := blkSlotData P w TA TBprev TBnext rnd
                            (slotsProveFixedProg Lq hL20 key P Dslot bR.1 gR.1 aR.1 23 active1 [] 0 {} t3).andThen fun slR =>
                              let active2 := match slR.1 with
                                | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals)
                                | none => false
                              let fs := match slR.1 with
                                | some (_, _, acc) => acc.fs ++ acc.hostFs
                                | none => []
                              (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 23 treeM fs slR.2).andThen fun mR =>
                                let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                                (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
                                    shdP_blkOpenGeomA TA treeA active2
                                    (openingHdrOk shdP_blkOpenGeomA 14 clA) clA mR.2).andThen fun aOR =>
                                  let active3 := active2 && aOR.1.isSome
                                  let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []
                                  (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
                                      shdP_blkOpenGeomH TH treeH active3
                                      (openingHdrOk shdP_blkOpenGeomH 14 clH) clH aOR.2).andThen fun hOR =>
                                    let active4 := active3 && hOR.1.isSome
                                    let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
                                    (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                                        shdP_bndOpenGeom TBprev treeBPrev active4
                                        (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                                      match slR.1, aOR.1, hOR.1, bOR.1 with
                                      | some (sps, _, acc), some aO, some hO, some bO =>
                                        if active4 then
                                          let core : Exec.Block.Core := ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩
                                          let seg : Segment := ⟨some bRoot, core, bO, none⟩
                                          .ret (some (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
                                            ⟨acc.claims.out, bRoot⟩), treeBNext, bOR.2)
                                        else .ret (none, treeBNext, bOR.2)
                                      | _, _, _, _ => .ret (none, treeBNext, bOR.2)

/-- Static point schedule of `blkSegFixedProg` (`412,266` queries starting at `base`). -/
def blkSegFixedSched (P : BlockParams) (k : Fin 26) (base tip : ℕ) : ℕ → RawPtSpec :=
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  let b0 := base + 131071
  let b1 := b0 + 1
  let b2 := b1 + 1
  let b5 := b2 + 3
  let bA := b5 + 131071
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bB := bM1 + 1
  let bG := bB + 1
  let bAl := bG + 1
  let bH := bAl + 131071
  let bH3 := bH + 3
  let bSl := bH3 + 1283
  let bMo := bSl + 115
  let bAo := bMo + 4824
  let bHo := bAo + 4518
  let bBo := bHo + 107
  spliceSched b0 (merkleTreeSched (.bnd ⟨k.val + 1, by omega⟩) base)
    (spliceSched b1 (fun _ => .absorb tip)
      (spliceSched b2 (fun _ => .absorb b0)
        (spliceSched b5 (absorbRootSched b2 b1)
          (spliceSched bA (merkleTreeSched (.a s) b5)
            (spliceSched bA3 (absorbRootSched bA (b5 - 1))
              (spliceSched bM (merkleTreeSched (.m s) bA3)
                (spliceSched bM1 (fun _ => .absorb (bA3 - 1))
                  (spliceSched bB (spliceSched bB (fun _ => .squeeze bM) (fun _ => .absorb 0))
                    (spliceSched bG (spliceSched bG (fun _ => .squeeze bM1) (fun _ => .absorb 0))
                      (spliceSched bAl (spliceSched bAl (fun _ => .squeeze bB) (fun _ => .absorb 0))
                        (spliceSched bH (merkleTreeSched (.h s) bAl)
                          (spliceSched bH3 (absorbRootSched bH (bAl - 1))
                            (spliceSched bSl (slotsFixedSched P 0 23 bH3 (bH3 - 1))
                              (spliceSched bMo (zkBMaskFixedSched 23 bSl (bSl - 1))
                                (spliceSched bAo (openingAuditFixedSched 146 4577 36 256 bMo (bMo - 1))
                                  (spliceSched bHo (openingAuditFixedSched 54 4390 9 256 bAo (bAo - 1))
                                    (spliceSched bBo (openingAuditFixedSched 2 38 2 256 bHo (bHo - 1))
                                      (fun _ => .absorb 0))))))))))))))))))

/-- Trees touched by interior Block `k : Fin 26`: `{B_{k+1}, A_{k+1}, M_{k+1}, H_{k+1}}`. -/
def blkTreeSet (k : Fin 26) (tid : ShdTreeId) : Prop :=
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  tid = .bnd ⟨k.val + 1, by omega⟩ ∨ tid = .a s ∨ tid = .m s ∨ tid = .h s

theorem blkSegFixedProg_run_inactive {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (G : QB Lq → Dig) :
    ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k false cr treeBPrev bnd startTag t).run G).1 = none := by
  unfold blkSegFixedProg
  repeat rw [PProg.run_andThen]
  simp only [Bool.false_and]
  rw [slotsProveFixedProg_run_inactive]
  dsimp only
  rfl

private theorem blkSeg_openA_run_gen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hg : g = shdP_blkOpenGeomA)
    (TA : Table) (hArows : 4577 = TA.rows.length) (trA : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 16), trA.path j hj = pathOf (liftH G) tag 16 TA j) :
    let res := (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
      g TA trA true (openingHdrOk g 14 cl) cl t5).run G
    match checkOpeningExec (liftH G) g 14 cl t5 with
    | .ok () => res = (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TA cl t5).1,
                       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TA cl t5).2)
    | .error _ => res.1 = none := by
  have hR13Log : Exec.R13.r13Prm.logCols = 14 := rfl
  have hR13nQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
  have hR13Fit := pcsCombVec_fit hL20 Exec.R13.r13Prm (by norm_num [Exec.R13.r13Prm, PcsPrm.n])
  have hgr : g.rows = 4577 := by rw [hg]; rfl
  have hgg : g.groups = 36 := by rw [hg]; rfl
  have hAsum : ∀ og, auditClaims cl (2 ^ Exec.R13.r13Prm.logCols) g.rows
      g.siteRows g.sumRows g.prox = .ok () →
      openingGroupsAt cl Exec.R13.r13Prm.logCols = .ok og →
      og.length = g.groups → (og.map Prod.snd).sum = 146 := by
    intro og haud hog _
    rw [hR13Log] at hog
    rw [openingGroupsAt_sum_eq_length cl 14 og hog]
    have haud' : auditClaims cl (2 ^ 14) 4577 (List.range' 4283 (2 * 146)) none 4575 = .ok () := by
      rw [hR13Log, hg] at haud; dsimp only [shdP_blkOpenGeomA] at haud
      rw [show (2 : ℕ) * 146 = 292 by norm_num]; exact haud
    exact auditClaims_length_none cl (2 ^ 14) 4577 4283 146 4575 (by norm_num) haud'
  have h := openingAuditFixedProg_run Lq hL20 tag key Exec.R13.r13Prm 16 146 4577 36
    Exec.R13.r13Prm_nn hR13nQ g TA hArows hgr hgg trA cl t5 ht5Key G
    hR13Fit.1 hR13Fit.2 hAsum hTreeA
  rw [hR13Log] at h; exact h

private theorem blkSeg_openH_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TH : Table) (hHrows : 4390 = TH.rows.length) (trH : MerkleLevels 16)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 16), trH.path j hj = pathOf (liftH G) tag 16 TH j) :
    let clH := clH0 ++ [sumCl]
    let res := (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
      shdP_blkOpenGeomH TH trH true (openingHdrOk shdP_blkOpenGeomH 14 clH) clH t6).run G
    match checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 clH t6 with
    | .ok () => res = (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TH clH t6).1,
                       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TH clH t6).2)
    | .error _ => res.1 = none := by
  have hR13Log : Exec.R13.r13Prm.logCols = 14 := rfl
  have hR13nQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
  have hR13Fit := pcsCombVec_fit hL20 Exec.R13.r13Prm (by norm_num [Exec.R13.r13Prm, PcsPrm.n])
  have hHsum : ∀ og, auditClaims (clH0 ++ [sumCl]) (2 ^ Exec.R13.r13Prm.logCols) shdP_blkOpenGeomH.rows
      shdP_blkOpenGeomH.siteRows shdP_blkOpenGeomH.sumRows shdP_blkOpenGeomH.prox = .ok () →
      openingGroupsAt (clH0 ++ [sumCl]) Exec.R13.r13Prm.logCols = .ok og →
      og.length = shdP_blkOpenGeomH.groups → (og.map Prod.snd).sum = 54 := by
    intro og haud hog _
    rw [hR13Log] at hog
    rw [openingGroupsAt_sum_eq_length _ 14 og hog]
    have haud' : auditClaims (clH0 ++ [sumCl]) (2 ^ 14) 4390 (List.range' 4282 (2 * 53)) (some (4280, 4281)) 4388 = .ok () := by
      rw [hR13Log] at haud; dsimp only [shdP_blkOpenGeomH] at haud
      rw [show (2 : ℕ) * 53 = 106 by norm_num]; exact haud
    exact auditClaims_length_some_last clH0 sumCl hsumEmpty (2 ^ 14) 4390 4282 53 4280 4281 4388 (by norm_num) haud'
  have h := openingAuditFixedProg_run Lq hL20 tag key Exec.R13.r13Prm 16 54 4390 9
    Exec.R13.r13Prm_nn hR13nQ shdP_blkOpenGeomH TH hHrows rfl rfl trH (clH0 ++ [sumCl]) t6 ht6Key G
    hR13Fit.1 hR13Fit.2 hHsum hTreeH
  rw [hR13Log] at h; exact h

private theorem blkSeg_openB_run (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TB : Table) (hBrows : 38 = TB.rows.length) (trB : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t7 : Tr) (ht7Key : t7.key = key) (G : QB Lq → Dig)
    (hTreeB : ∀ (j : ℕ) (hj : j < 2 ^ 16), trB.path j hj = pathOf (liftH G) tag 16 TB j) :
    let res := (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      shdP_bndOpenGeom TB trB true (openingHdrOk shdP_bndOpenGeom 14 cl) cl t7).run G
    match checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t7 with
    | .ok () => res = (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TB cl t7).1,
                       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TB cl t7).2)
    | .error _ => res.1 = none := by
  have hR13Log : Exec.R13.r13Prm.logCols = 14 := rfl
  have hR13nQ : 0 < Exec.R13.r13Prm.nQ := by norm_num [Exec.R13.r13Prm]
  have hR13Fit := pcsCombVec_fit hL20 Exec.R13.r13Prm (by norm_num [Exec.R13.r13Prm, PcsPrm.n])
  have hBsum : ∀ og, auditClaims cl (2 ^ Exec.R13.r13Prm.logCols) shdP_bndOpenGeom.rows
      shdP_bndOpenGeom.siteRows shdP_bndOpenGeom.sumRows shdP_bndOpenGeom.prox = .ok () →
      openingGroupsAt cl Exec.R13.r13Prm.logCols = .ok og →
      og.length = shdP_bndOpenGeom.groups → (og.map Prod.snd).sum = 2 := by
    intro og haud hog _
    rw [hR13Log] at hog
    rw [openingGroupsAt_sum_eq_length cl 14 og hog]
    have haud' : auditClaims cl (2 ^ 14) 38 (List.range' 32 (2 * 2)) none 36 = .ok () := by
      rw [hR13Log] at haud; dsimp only [shdP_bndOpenGeom] at haud
      rw [show List.range' 32 (2 * 2) = [32, 33, 34, 35] by decide]; exact haud
    exact auditClaims_length_none cl (2 ^ 14) 38 32 2 36 (by norm_num) haud'
  have h := openingAuditFixedProg_run Lq hL20 tag key Exec.R13.r13Prm 16 2 38 2
    Exec.R13.r13Prm_nn hR13nQ shdP_bndOpenGeom TB hBrows rfl rfl trB cl t7 ht7Key G
    hR13Fit.1 hR13Fit.2 hBsum hTreeB
  rw [hR13Log] at h; exact h

private theorem blkSeg_openA_run_gen_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hg : g = shdP_blkOpenGeomA)
    (TA : Table) (hArows : 4577 = TA.rows.length) (trA : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 16), trA.path j hj = pathOf (liftH G) tag 16 TA j)
    (hchk : checkOpeningExec (liftH G) g 14 cl t5 = .ok ()) :
    (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
      g TA trA true (openingHdrOk g 14 cl) cl t5).run G =
      (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TA cl t5).1,
       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TA cl t5).2) := by
  have h := blkSeg_openA_run_gen Lq hL20 tag key g hg TA hArows trA cl t5 ht5Key G hTreeA
  dsimp only at h; rw [hchk] at h; exact h

private theorem blkSeg_openA_run_gen_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hg : g = shdP_blkOpenGeomA)
    (TA : Table) (hArows : 4577 = TA.rows.length) (trA : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 16), trA.path j hj = pathOf (liftH G) tag 16 TA j)
    (e : String) (hchk : checkOpeningExec (liftH G) g 14 cl t5 = .error e) :
    ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
      g TA trA true (openingHdrOk g 14 cl) cl t5).run G).1 = none := by
  have h := blkSeg_openA_run_gen Lq hL20 tag key g hg TA hArows trA cl t5 ht5Key G hTreeA
  dsimp only at h; rw [hchk] at h; exact h

private theorem blkSeg_openH_run_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TH : Table) (hHrows : 4390 = TH.rows.length) (trH : MerkleLevels 16)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 16), trH.path j hj = pathOf (liftH G) tag 16 TH j)
    (hchk : checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 (clH0 ++ [sumCl]) t6 = .ok ()) :
    (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
      shdP_blkOpenGeomH TH trH true (openingHdrOk shdP_blkOpenGeomH 14 (clH0 ++ [sumCl])) (clH0 ++ [sumCl]) t6).run G =
      (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TH (clH0 ++ [sumCl]) t6).1,
       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TH (clH0 ++ [sumCl]) t6).2) := by
  have h := blkSeg_openH_run Lq hL20 tag key TH hHrows trH clH0 sumCl hsumEmpty t6 ht6Key G hTreeH
  dsimp only at h; rw [hchk] at h; exact h

private theorem blkSeg_openH_run_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TH : Table) (hHrows : 4390 = TH.rows.length) (trH : MerkleLevels 16)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 16), trH.path j hj = pathOf (liftH G) tag 16 TH j)
    (e : String) (hchk : checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 (clH0 ++ [sumCl]) t6 = .error e) :
    ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
      shdP_blkOpenGeomH TH trH true (openingHdrOk shdP_blkOpenGeomH 14 (clH0 ++ [sumCl])) (clH0 ++ [sumCl]) t6).run G).1 = none := by
  have h := blkSeg_openH_run Lq hL20 tag key TH hHrows trH clH0 sumCl hsumEmpty t6 ht6Key G hTreeH
  dsimp only at h; rw [hchk] at h; exact h

private theorem blkSeg_openB_run_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TB : Table) (hBrows : 38 = TB.rows.length) (trB : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t7 : Tr) (ht7Key : t7.key = key) (G : QB Lq → Dig)
    (hTreeB : ∀ (j : ℕ) (hj : j < 2 ^ 16), trB.path j hj = pathOf (liftH G) tag 16 TB j)
    (hchk : checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t7 = .ok ()) :
    (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      shdP_bndOpenGeom TB trB true (openingHdrOk shdP_bndOpenGeom 14 cl) cl t7).run G =
      (some (bOpen (liftH G) tag Exec.R13.r13Prm 16 TB cl t7).1,
       (bOpen (liftH G) tag Exec.R13.r13Prm 16 TB cl t7).2) := by
  have h := blkSeg_openB_run Lq hL20 tag key TB hBrows trB cl t7 ht7Key G hTreeB
  dsimp only at h; rw [hchk] at h; exact h

private theorem blkSeg_openB_run_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (TB : Table) (hBrows : 38 = TB.rows.length) (trB : MerkleLevels 16)
    (cl : List Exec.Block.ZClaim) (t7 : Tr) (ht7Key : t7.key = key) (G : QB Lq → Dig)
    (hTreeB : ∀ (j : ℕ) (hj : j < 2 ^ 16), trB.path j hj = pathOf (liftH G) tag 16 TB j)
    (e : String) (hchk : checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t7 = .error e) :
    ((openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
      shdP_bndOpenGeom TB trB true (openingHdrOk shdP_bndOpenGeom 14 cl) cl t7).run G).1 = none := by
  have h := blkSeg_openB_run Lq hL20 tag key TB hBrows trB cl t7 ht7Key G hTreeB
  dsimp only at h; rw [hchk] at h; exact h

private noncomputable def blkSegFixedProg_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams) (k : Fin 26) (blkDigk : Dig)
    (TBprev TBnext TA : Table)
    (hTBnc : ∀ j : Fin (2 ^ 16), (TBnext.cols j.val).length = 38)
    (hTAc : ∀ j : Fin (2 ^ 16), (TA.cols j.val).length = 4577)
    (M : MTable)
    (TH : Fp2 × Fp2 × Fp2 → Table)
    (hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390)
    (Dslot : SlotData P) (alphaBad : Fp2 × Fp2 × Fp2 → Bool)
    (sg : SegGeom) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr) :=
  (merkleTableProg Lq (by omega) tag 16 38 (by omega) TBnext hTBnc).andThen fun treeBNext =>
    let bRoot := treeBNext.getRoot
    (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat (k.val + 1)))).andThen fun tf1 =>
      (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) blkDigk.toList).andThen fun tf2 =>
        (absorbRootKeyed Lq hL20 key tf2 labB (by decide) bRoot 38 14).andThen fun tFrame =>
          (merkleTableProg Lq (by omega) tag 16 4577 (by omega) TA hTAc).andThen fun treeA =>
            let aRoot := treeA.getRoot
            (absorbRootKeyed Lq hL20 key tFrame labA (by decide) aRoot P.aRows P.logCols).andThen fun tA =>
              (merkleTableProg Lq (by omega) tag 12 (2 * 23 + 4) (by omega) (mTab 23 (cosetPt (rootFp 12)) M)
                  (fun j => mCol_length 23 _ M j.val)).andThen fun treeM =>
                let mRoot := treeM.getRoot
                (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
                  (trChallengeFp2Keyed Lq (by omega) key tM).andThen fun bR =>
                    (trChallengeFp2Keyed Lq (by omega) key bR.2).andThen fun gR =>
                      (trChallengeFp2Keyed Lq (by omega) key gR.2).andThen fun aR =>
                        let bga := (bR.1, gR.1, aR.1)
                        let TH0 := TH bga
                        let active1 := true && !alphaBad bga
                        (merkleTableProg Lq (by omega) tag 16 4390 (by omega) TH0 (hTHc bga)).andThen fun treeH =>
                          let hRoot := treeH.getRoot
                          (absorbRootKeyed Lq hL20 key aR.2 labH (by decide) hRoot P.hRows P.logCols).andThen fun t3 =>
                            (slotsProveFixedProg Lq hL20 key P Dslot bR.1 gR.1 aR.1 23 active1 [] 0 {} t3).andThen fun slR =>
                              let active2 := match slR.1 with
                                | some (_, _, acc) => decide ((acc.fs ++ acc.hostFs).length = P.nFunctionals)
                                | none => false
                              let fs := match slR.1 with
                                | some (_, _, acc) => acc.fs ++ acc.hostFs
                                | none => []
                              (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 23 treeM fs slR.2).andThen fun mR =>
                                let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                                (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36
                                    shdP_blkOpenGeomA TA treeA active2
                                    (openingHdrOk shdP_blkOpenGeomA 14 clA) clA mR.2).andThen fun aOR =>
                                  let active3 := active2 && aOR.1.isSome
                                  let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [P.logupSumClaim] | none => []
                                  (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9
                                      shdP_blkOpenGeomH TH0 treeH active3
                                      (openingHdrOk shdP_blkOpenGeomH 14 clH) clH aOR.2).andThen fun hOR =>
                                    let active4 := active3 && hOR.1.isSome
                                    let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
                                    (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                                        shdP_bndOpenGeom TBprev treeBPrev active4
                                        (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                                      match slR.1, aOR.1, hOR.1, bOR.1 with
                                      | some (sps, _, acc), some aO, some hO, some bO =>
                                        if active4 then
                                          let core : Exec.Block.Core := ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩
                                          let seg : Segment := ⟨some bRoot, core, bO, none⟩
                                          .ret (some (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
                                            ⟨acc.claims.out, bRoot⟩), treeBNext, bOR.2)
                                        else .ret (none, treeBNext, bOR.2)
                                      | _, _, _, _ => .ret (none, treeBNext, bOR.2)

private theorem coreProve_err (H : HIn → Dig) (P : BlockParams) (D : CoreData P) (t : Tr)
    (h : coreProve H P D t = .error ()) :
    slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
      P.geom.slots.length [] 0 {} (coreT3 H P D t) = .error ()
    ∨ ∃ sps recs acc t4,
        slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
          P.geom.slots.length [] 0 {} (coreT3 H P D t) = .ok (sps, recs, acc, t4)
        ∧ ((acc.fs ++ acc.hostFs).length ≠ P.nFunctionals
          ∨ ((acc.fs ++ acc.hostFs).length = P.nFunctionals
              ∧ ((∃ e, P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
                ∨ (P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .ok ()
                    ∧ ∃ e, P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
                        (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)))) := by
  unfold coreProve at h
  cases hsl : slotsProve H P D.slot (coreB H P D t).1 (coreG H P D t).1 (coreA H P D t).1
      P.geom.slots.length [] 0 {} (coreT3 H P D t) with
  | error u => cases u; exact Or.inl rfl
  | ok vSl =>
    rcases vSl with ⟨sps, recs, acc, t4⟩
    right; refine ⟨sps, recs, acc, t4, rfl, ?_⟩
    rw [hsl] at h; dsimp only at h
    by_cases hfs : (acc.fs ++ acc.hostFs).length = P.nFunctionals
    · right; refine ⟨hfs, ?_⟩
      rw [ite_eq_right (not_not.mpr hfs)] at h
      cases hcA : P.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e => exact Or.inl ⟨e, rfl⟩
      | ok u1 =>
        cases u1; right; refine ⟨rfl, ?_⟩
        rw [hcA] at h; dsimp only at h
        cases hcH : P.checkOpening H .h (acc.claims.h ++ [P.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | error e => exact ⟨e, rfl⟩
        | ok u2 => rw [hcH] at h; cases h
    · exact Or.inl hfs

private theorem blkSegFixedProg_run_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (P : BlockParams) (k : Fin 26) (blkDigk : Dig)
    (TBprev TBnext TA : Table)
    (hTBnc : ∀ j : Fin (2 ^ 16), (TBnext.cols j.val).length = 38)
    (hTAc : ∀ j : Fin (2 ^ 16), (TA.cols j.val).length = 4577)
    (hTAr : 4577 = TA.rows.length) (hTBpr : 38 = TBprev.rows.length)
    (M : MTable)
    (TH : Fp2 × Fp2 × Fp2 → Table)
    (hTHc : ∀ bga, ∀ j : Fin (2 ^ 16), ((TH bga).cols j.val).length = 4390)
    (hTHr : ∀ bga, 4390 = (TH bga).rows.length)
    (Dslot : SlotData P) (alphaBad : Fp2 × Fp2 × Fp2 → Bool)
    (sg : SegGeom) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (D : CoreData P)
    (tFrame : Tr)
    (htFr : tFrame = Exec.Block.absorbRoot (liftH G)
        ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat (k.val + 1)))).absorb (liftH G) labRunBlock blkDigk.toList)
        labB (rootOf (liftH G) tag 16 TBnext) 38 14)
    (hDaR : D.aRoot = rootOf (liftH G) tag 16 TA)
    (hDmR : D.maskRoot = rootOf (liftH G) tag 12 (mTab 23 (cosetPt (rootFp 12)) M))
    (hDhR : ∀ b g a, D.hRoot b g a = rootOf (liftH G) tag 16 (TH (b, g, a)))
    (hDslot : D.slot = Dslot)
    (hDmOpen : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij M 23)
    (hDaOpen : D.aOpen = bOpen (liftH G) tag Exec.R13.r13Prm 16 TA)
    (hDhOpen : D.hOpen = bOpen (liftH G) tag Exec.R13.r13Prm 16
      (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1)))
    (hP_sl23 : P.geom.slots.length = 23)
    (hP_chkA : ∀ cl t', P.checkOpening (liftH G) .a cl t' = checkOpeningExec (liftH G) shdP_blkOpenGeomA 14 cl t')
    (hP_chkH : ∀ cl t', P.checkOpening (liftH G) .h cl t' = checkOpeningExec (liftH G) shdP_blkOpenGeomH 14 cl t')
    (hP_sumH : P.logupSumClaim.parts.all (fun p => p.point.isEmpty) = true)
    (hfitSc : ∀ s hist acc t' df, P.define s hist (t'.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN P s)
        (Dslot.strat s hist acc df (slotC (liftH G) P s t'))
        (slotT4 (liftH G) P s t' (Dslot.scalar s hist acc df (slotC (liftH G) P s t')))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t' df, P.define s hist (t'.challengeFp2Vec (liftH G) (P.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks P s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) P Dslot s hist acc t' df).terms.length * 16 ≤ Lq)
    (hBPrev : ∀ (j : ℕ) (hj : j < 2 ^ 16), treeBPrev.path j hj = pathOf (liftH G) tag 16 TBprev j) :
    let res := (blkSegFixedProg_abs Lq hL20 tag key P k blkDigk TBprev TBnext TA hTBnc hTAc M TH hTHc Dslot alphaBad sg cr treeBPrev bnd startTag t).run G
    let bga := ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1)
    (res.2.1.getRoot = rootOf (liftH G) tag 16 TBnext
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), res.2.1.path j hj = pathOf (liftH G) tag 16 TBnext j)
    ∧ (alphaBad bga = true → res.1 = none)
    ∧ (alphaBad bga = false → coreProve (liftH G) P D tFrame = .error () → res.1 = none)
    ∧ (∀ R, alphaBad bga = false → coreProve (liftH G) P D tFrame = .ok R →
        (∀ e, checkOpeningExec (liftH G) shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp) R.t7 = .error e → res.1 = none)
        ∧ (checkOpeningExec (liftH G) shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp) R.t7 = .ok () →
            let bO := bOpen (liftH G) tag Exec.R13.r13Prm 16 TBprev (cr.pending ++ R.acc.claims.inp) R.t7
            let seg : Segment := ⟨some (rootOf (liftH G) tag 16 TBnext), R.core, bO.1, none⟩
            res.1 = some (fun e => Exec.Block.encSeg bnd sg.l sg.k startTag seg e,
              ⟨R.acc.claims.out, rootOf (liftH G) tag 16 TBnext⟩) ∧ res.2.2 = bO.2)) := by
  dsimp only
  generalize hres : (blkSegFixedProg_abs Lq hL20 tag key P k blkDigk TBprev TBnext TA hTBnc hTAc M TH hTHc Dslot alphaBad sg cr treeBPrev bnd startTag t).run G = res
  unfold blkSegFixedProg_abs at hres
  dsimp only at hres
  obtain ⟨trBN, htrBN, hTreeBN⟩ := merkle_andThen_elim Lq (by omega) tag 16 38 (by omega) TBnext hTBnc G
  rw [run_andThen_with _ _ G trBN htrBN] at hres; clear htrBN
  rw [run_andThen_trAbsorb htKey (by rw [le64_length]; change 48 + 12 + 8 ≤ Lq; omega),
      run_andThen_trAbsorb (tr_absorb_key _ _ _ _ htKey) (by rw [List.Vector.toList_length]; change 48 + 12 + 32 ≤ Lq; omega),
      run_andThen_absorbRoot (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))] at hres
  obtain ⟨trA, htrA, hTreeA⟩ := merkle_andThen_elim Lq (by omega) tag 16 4577 (by omega) TA hTAc G
  rw [run_andThen_with _ _ G trA htrA] at hres; clear htrA
  have htfKey : (Exec.Block.absorbRoot (liftH G)
      ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat (k.val + 1)))).absorb (liftH G) labRunBlock blkDigk.toList)
      labB trBN.getRoot 38 14).key = key :=
    absorbRoot_key _ _ _ _ _ _ (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))
  rw [run_andThen_absorbRoot htfKey] at hres
  obtain ⟨trM, htrM, hTreeM⟩ := merkle_andThen_elim Lq (by omega) tag 12 (2 * 23 + 4) (by omega)
      (mTab 23 (cosetPt (rootFp 12)) M) (fun j => mCol_length 23 _ M j.val) G
  rw [run_andThen_with _ _ G trM htrM] at hres; clear htrM
  have htAKey : (Exec.Block.absorbRoot (liftH G)
      (Exec.Block.absorbRoot (liftH G)
        ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat (k.val + 1)))).absorb (liftH G) labRunBlock blkDigk.toList)
        labB trBN.getRoot 38 14)
      labA trA.getRoot P.aRows P.logCols).key = key :=
    absorbRoot_key _ _ _ _ _ _ htfKey
  rw [run_andThen_trAbsorb htAKey (by rw [List.Vector.toList_length]; change 48 + 1 + 32 ≤ Lq; omega),
      run_andThen_trChallengeFp2 (tr_absorb_key _ _ _ _ htAKey)] at hres
  have htFrEq : Exec.Block.absorbRoot (liftH G)
      ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat (k.val + 1)))).absorb (liftH G) labRunBlock blkDigk.toList)
      labB trBN.getRoot 38 14 = tFrame := by rw [htFr, hTreeBN.1]
  have htFrKey : tFrame.key = key := by rw [← htFrEq]; exact htfKey
  rw [htFrEq] at hres
  have htM'Eq : (Exec.Block.absorbRoot (liftH G) tFrame labA trA.getRoot P.aRows P.logCols).absorb (liftH G) labM trM.getRoot.toList
      = coreT2 (liftH G) P D tFrame := by
    unfold coreT2; rw [hTreeA.1, hTreeM.1, hDaR, hDmR]
  have htM'Key : (coreT2 (liftH G) P D tFrame).key = key := by
    rw [← htM'Eq]; exact tr_absorb_key _ _ _ _ (absorbRoot_key _ _ _ _ _ _ htFrKey)
  rw [htM'Eq] at hres
  have hbKey : (coreB (liftH G) P D tFrame).2.key = key := tr_challengeFp2_key _ _ htM'Key
  have hgKey : (coreG (liftH G) P D tFrame).2.key = key := tr_challengeFp2_key _ _ hbKey
  have ha2Key : (coreA (liftH G) P D tFrame).2.key = key := tr_challengeFp2_key _ _ hgKey
  rw [show (coreT2 (liftH G) P D tFrame).challengeFp2 (liftH G) = coreB (liftH G) P D tFrame from rfl,
      run_andThen_trChallengeFp2 hbKey,
      show (coreB (liftH G) P D tFrame).2.challengeFp2 (liftH G) = coreG (liftH G) P D tFrame from rfl,
      run_andThen_trChallengeFp2 hgKey,
      show (coreG (liftH G) P D tFrame).2.challengeFp2 (liftH G) = coreA (liftH G) P D tFrame from rfl] at hres
  obtain ⟨trH, htrH, hTreeH⟩ := merkle_andThen_elim Lq (by omega) tag 16 4390 (by omega)
      (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1))
      (hTHc _) G
  rw [run_andThen_with _ _ G trH htrH] at hres; clear htrH
  rw [run_andThen_absorbRoot ha2Key] at hres
  have ht3Eq : Exec.Block.absorbRoot (liftH G) (coreA (liftH G) P D tFrame).2 labH trH.getRoot P.hRows P.logCols
      = coreT3 (liftH G) P D tFrame := by
    unfold coreT3; rw [hTreeH.1, hDhR]
  have ht3Key : (coreT3 (liftH G) P D tFrame).key = key := by
    rw [← ht3Eq]; exact absorbRoot_key _ _ _ _ _ _ ha2Key
  refine ⟨?_, ?_⟩
  · have hres_tree : res.2.1 = trBN := by
      rw [← hres]
      refine run_andThen_snd_fst _ _ G trBN fun ⟨o1, _⟩ =>
        run_andThen_snd_fst _ _ G trBN fun ⟨_, _⟩ =>
          run_andThen_snd_fst _ _ G trBN fun ⟨oA, _⟩ =>
            run_andThen_snd_fst _ _ G trBN fun ⟨oH, _⟩ =>
              run_andThen_snd_fst _ _ G trBN fun ⟨oB, _⟩ => ?_
      dsimp only
      cases o1 with
      | none => rfl
      | some v1 =>
        rcases v1 with ⟨sps, _, acc⟩
        cases oA with
        | none => rfl
        | some aO =>
          cases oH with
          | none => rfl
          | some hO =>
            cases oB with
            | none => rfl
            | some bO => exact ret_ite_snd_fst _ _ _ trBN _ G
    rw [hres_tree]; exact hTreeBN
  · refine ⟨fun hbad => ?_, fun hbad hCp => ?_, fun R hbad hCp => ?_⟩
    · rw [hbad] at hres; simp only [Bool.not_true, Bool.and_false] at hres
      rw [← hres]
      exact run_andThen_with_fst_none _ _ G (slotsProveFixedProg_run_inactive Lq hL20 key _ _ _ _ _ G _ _ _ _ _) fun _ =>
        run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
    · rw [hbad, ht3Eq] at hres; simp only [Bool.not_false, Bool.and_true] at hres
      have herr := coreProve_err (liftH G) P D tFrame hCp
      rcases herr with hsl | ⟨sps, recs, acc, t4, hsl, hfs | ⟨hfs, ⟨eA, hcA⟩ | ⟨hcA, eH, hcH⟩⟩⟩
      · rw [hP_sl23, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_err Lq hL20 key P Dslot
          (coreB (liftH G) P D tFrame).1 (coreG (liftH G) P D tFrame).1 (coreA (liftH G) P D tFrame).1 G
          hfitSc hfitTerms 23 [] 0 {} _ ht3Key hsl
        rw [← hres]
        exact run_andThen_with_fst_none _ _ G hSlRun fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
            run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · rw [hP_sl23, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key P Dslot
          (coreB (liftH G) P D tFrame).1 (coreG (liftH G) P D tFrame).1 (coreA (liftH G) P D tFrame).1 G
          hfitSc hfitTerms 23 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_false hfs, Bool.false_and, Bool.false_eq_true, ↓reduceIte] at hres
        rw [← hres]
        refine run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun ⟨oA, _⟩ =>
          run_andThen_fst_none _ _ G fun ⟨oH, _⟩ => run_andThen_fst_none _ _ G fun ⟨oB, _⟩ => ?_
        dsimp only; cases oA <;> cases oH <;> cases oB <;> rfl
      · rw [hP_sl23, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key P Dslot
          (coreB (liftH G) P D tFrame).1 (coreG (liftH G) P D tFrame).1 (coreA (liftH G) P D tFrame).1 G
          hfitSc hfitTerms 23 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_true hfs] at hres
        have ht4Key : t4.key = key := (slotsProve_key (liftH G) P Dslot _ _ _ 23 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
        have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M 23 trM (acc.fs ++ acc.hostFs) t4 ht4Key G
          (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM.2
        rw [run_andThen_with _ _ G _ hMRun] at hres
        let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M 23 (acc.fs ++ acc.hostFs) t4).2
        have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M 23 (acc.fs ++ acc.hostFs) t4 key ht4Key
        rw [hDmOpen, hP_chkA] at hcA
        generalize hgA : shdP_blkOpenGeomA = gA at hres hcA
        have hARun := blkSeg_openA_run_gen_err Lq hL20 tag key gA hgA.symm TA hTAr trA acc.claims.a t5 ht5Key G hTreeA.2 eA hcA
        dsimp only [t5] at hARun; rw [← hres]
        exact run_andThen_with_fst_none _ _ G hARun fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · rw [hP_sl23, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key P Dslot
          (coreB (liftH G) P D tFrame).1 (coreG (liftH G) P D tFrame).1 (coreA (liftH G) P D tFrame).1 G
          hfitSc hfitTerms 23 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        simp only [decide_eq_true hfs] at hres
        have ht4Key : t4.key = key := (slotsProve_key (liftH G) P Dslot _ _ _ 23 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
        have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M 23 trM (acc.fs ++ acc.hostFs) t4 ht4Key G
          (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM.2
        rw [run_andThen_with _ _ G _ hMRun] at hres
        let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M 23 (acc.fs ++ acc.hostFs) t4).2
        have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M 23 (acc.fs ++ acc.hostFs) t4 key ht4Key
        rw [hDmOpen, hP_chkA] at hcA
        generalize hgA : shdP_blkOpenGeomA = gA at hres hcA
        have hARun := blkSeg_openA_run_gen_ok Lq hL20 tag key gA hgA.symm TA hTAr trA acc.claims.a t5 ht5Key G hTreeA.2 hcA
        dsimp only [t5] at hARun
        rw [run_andThen_with _ _ G _ hARun] at hres; dsimp only at hres
        simp only [Option.isSome_some, Bool.true_and] at hres
        let t6 := (bOpen (liftH G) tag Exec.R13.r13Prm 16 TA acc.claims.a t5).2
        have ht6Key : t6.key = key := bOpen_key (liftH G) tag Exec.R13.r13Prm 16 TA acc.claims.a t5 key ht5Key
        rw [hDaOpen, hDmOpen, hP_chkH] at hcH
        have hHRun := blkSeg_openH_run_err Lq hL20 tag key
          (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1))
          (hTHr _) trH acc.claims.h P.logupSumClaim hP_sumH t6 ht6Key G hTreeH.2 eH hcH
        dsimp only [t6, t5] at hHRun; rw [← hres]
        exact run_andThen_with_fst_none _ _ G hHRun fun _ => run_andThen_fst_none _ _ G fun _ => rfl
    · rw [hbad, ht3Eq] at hres; simp only [Bool.not_false, Bool.and_true] at hres
      obtain ⟨hsl, hfs, hcA, hcH, hRaR, hRmR, hRhR, -, hRmO, hRaO, hRhO⟩ :=
        coreProve_ok (liftH G) P D tFrame R hCp
      rw [hP_sl23, hDslot] at hsl
      have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key P Dslot
        (coreB (liftH G) P D tFrame).1 (coreG (liftH G) P D tFrame).1 (coreA (liftH G) P D tFrame).1 G
        hfitSc hfitTerms 23 [] 0 {} _ ht3Key R.core.slots R.recs R.acc R.t4 hsl
      rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
      simp only [decide_eq_true hfs] at hres
      have ht4Key : R.t4.key = key := (slotsProve_key (liftH G) P Dslot _ _ _ 23 [] 0 {} _ R.core.slots R.recs R.acc R.t4 hsl).trans ht3Key
      have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M 23 trM (R.acc.fs ++ R.acc.hostFs) R.t4 ht4Key G
        (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM.2
      rw [hDmOpen] at hRmO
      have hMRun' : (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M 23 trM (R.acc.fs ++ R.acc.hostFs) R.t4).run G = (R.core.maskOpen, R.t5) :=
        hMRun.trans hRmO.symm
      rw [run_andThen_with _ _ G _ hMRun'] at hres; dsimp only at hres
      have ht5Key : R.t5.key = key := (congrArg (fun p => p.2.key) hRmO).trans (bMask_key (liftH G) tag shdP_U shdP_hbij M 23 (R.acc.fs ++ R.acc.hostFs) R.t4 key ht4Key)
      rw [hP_chkA] at hcA
      generalize hgA : shdP_blkOpenGeomA = gA at hres hcA
      have hARun := blkSeg_openA_run_gen_ok Lq hL20 tag key gA hgA.symm TA hTAr trA R.acc.claims.a R.t5 ht5Key G hTreeA.2 hcA
      rw [hDaOpen] at hRaO
      have hARun' : (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 146 4577 36 gA TA trA true
          (openingHdrOk gA 14 R.acc.claims.a) R.acc.claims.a R.t5).run G = (some R.core.aOpen, R.t6) :=
        hARun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRaO.symm) : some _ = some R.core.aOpen) (congrArg Prod.snd hRaO.symm : _ = R.t6))
      rw [run_andThen_with _ _ G _ hARun'] at hres; dsimp only at hres
      simp only [Option.isSome_some, Bool.true_and] at hres
      have ht6Key : R.t6.key = key := (congrArg (fun p => p.2.key) hRaO).trans (bOpen_key (liftH G) tag Exec.R13.r13Prm 16 TA R.acc.claims.a R.t5 key ht5Key)
      rw [hP_chkH] at hcH
      have hHRun := blkSeg_openH_run_ok Lq hL20 tag key
        (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1))
        (hTHr _) trH R.acc.claims.h P.logupSumClaim hP_sumH R.t6 ht6Key G hTreeH.2 hcH
      rw [hDhOpen] at hRhO
      have hHRun' : (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH
          (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1)) trH true
          (openingHdrOk shdP_blkOpenGeomH 14 (R.acc.claims.h ++ [P.logupSumClaim])) (R.acc.claims.h ++ [P.logupSumClaim]) R.t6).run G
          = (some R.core.hOpen, R.t7) :=
        hHRun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRhO.symm) : some _ = some R.core.hOpen) (congrArg Prod.snd hRhO.symm : _ = R.t7))
      rw [run_andThen_with _ _ G _ hHRun'] at hres; dsimp only at hres
      simp only [Option.isSome_some] at hres
      have ht7Key : R.t7.key = key := (congrArg (fun p => p.2.key) hRhO).trans
        (bOpen_key (liftH G) tag Exec.R13.r13Prm 16
          (TH ((coreB (liftH G) P D tFrame).1, (coreG (liftH G) P D tFrame).1, (coreA (liftH G) P D tFrame).1))
          (R.acc.claims.h ++ [P.logupSumClaim]) R.t6 key ht6Key)
      refine ⟨fun eB hcB => ?_, fun hcB => ?_⟩
      · have hBRun := blkSeg_openB_run_err Lq hL20 tag key TBprev hTBpr treeBPrev (cr.pending ++ R.acc.claims.inp) R.t7 ht7Key G hBPrev eB hcB
        rw [← hres]
        exact run_andThen_with_fst_none _ _ G hBRun fun _ => rfl
      · have hBRun := blkSeg_openB_run_ok Lq hL20 tag key TBprev hTBpr treeBPrev (cr.pending ++ R.acc.claims.inp) R.t7 ht7Key G hBPrev hcB
        generalize hbO1 : (bOpen (liftH G) tag Exec.R13.r13Prm 16 TBprev (cr.pending ++ R.acc.claims.inp) R.t7).1 = bO1 at hBRun ⊢
        generalize hbO2 : (bOpen (liftH G) tag Exec.R13.r13Prm 16 TBprev (cr.pending ++ R.acc.claims.inp) R.t7).2 = bO2 at hBRun ⊢
        rw [run_andThen_with _ _ G _ hBRun] at hres; dsimp only at hres
        rw [ite_eq_left trivial, PProg.run] at hres
        have hcoreEq : (⟨trA.getRoot, trH.getRoot, trM.getRoot, R.core.slots, R.core.maskOpen, R.core.aOpen, R.core.hOpen⟩ : Exec.Block.Core) = R.core := by
          refine (core_eq ?_ ?_ ?_).trans (core_eta R.core)
          · rw [hRaR, hTreeA.1, hDaR]
          · rw [hRhR, hTreeH.1, hDhR]
          · rw [hRmR, hTreeM.1, hDmR]
        rw [hcoreEq, hTreeBN.1] at hres
        exact ⟨congrArg Prod.fst hres.symm, congrArg (fun p => p.2.2) hres.symm⟩

private theorem coreDataAt_aRoot_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (TA : Table) (hTA : C.TA = TA) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).aRoot = rootOf H tag depth TA := by
  rw [← hTA]; rfl

private theorem coreDataAt_maskRoot_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (M : MTable) (hM : C.M = M) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).maskRoot = rootOf H tag 12 (mTab S (cosetPt (rootFp 12)) M) := by
  rw [← hM]; rfl

private theorem coreDataAt_hRoot_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (TH : Fp2 × Fp2 × Fp2 → Table)
    (hTH : ∀ b g a, C.TH b g a = TH (b, g, a)) (b g a : Fp2) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).hRoot b g a = rootOf H tag depth (TH (b, g, a)) := by
  rw [← hTH]; rfl

private theorem coreDataAt_slot_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (Dslot : SlotData P) (hS : C.slot = Dslot) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).slot = Dslot := hS

private theorem coreDataAt_mOpen_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (M : MTable) (hM : C.M = M) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).mOpen = bMask H tag shdP_U shdP_hbij M S := by
  rw [← hM]; rfl

private theorem coreDataAt_aOpen_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (TA : Table) (hTA : C.TA = TA) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).aOpen = bOpen H tag prm depth TA := by
  rw [← hTA]; rfl

private theorem coreDataAt_hOpen_eq (H : HIn → Dig) (tag : MTag) (prm : PcsPrm) (depth S : ℕ)
    (P : BlockParams) (C : CoreTables P) (t : Tr) (TH : Fp2 × Fp2 × Fp2 → Table)
    (hTH : ∀ b g a, C.TH b g a = TH (b, g, a)) :
    (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t).hOpen =
      bOpen H tag prm depth (TH
        ((coreB H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1,
         (coreG H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1,
         (coreA H P (coreDataAt H tag shdP_U shdP_hbij prm depth S P C t) t).1)) := by
  rw [← hTH]; rfl

private def blkWrapRes {α β₁ β₂ β₃ : Type} (b : Bool) (e1 : Except Unit α)
    (e2 : α → Except String Unit) (f1 : α → β₁) (f2 : α → β₂) (f3 : α → β₃) :
    Except Unit (β₁ × β₂ × β₃) :=
  if b = true then .error ()
  else match e1 with
    | .error _ => .error ()
    | .ok a => match e2 a with | .error _ => .error () | .ok _ => .ok (f1 a, f2 a, f3 a)

private theorem shdP_blkSegP_run_zk_eq {Hdr Coins : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (checkOpening : (HIn → Dig) → Cm → List Exec.Block.ZClaim → Tr → Except String Unit)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (hAct0 : ∀ b ∈ Rp.blks, b.pub.act 0 2048 = 0)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (incRndOf : Coins → IncRand) (blkRndOf : Coins → Fin 26 → BlkRand)
    (k : ℕ) (hk : k < 26) :
    shdP_blkSegP_run_zk tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 check0 digest incRndOf blkRndOf k
      = shdP_blkSegP_zkGuarded tag (shdP_Pk0 tag ioIn ioOut checkOpening Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut checkOpening Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38)
          (shdP_layer k hk) (shdP_blkPub Rp hR k hk)
          (shdP_blkTables_total tag ioIn ioOut checkOpening Rp hR hweights hinPub hAct0 incRndOf blkRndOf) k := by
  unfold shdP_blkSegP_run_zk; exact dite_eq_left hk

private theorem shdP_blkSegP_zkGuarded_run_local {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr) :
    (shdP_blkSegP_zkGuarded tag Pk sgeom check paths digest bRows bLogN bndOpen Ly Pb W k).run H s x c bnd start cr t
      = (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN
          (fun _ _ cl t0 => checkOpeningExec H shdP_bndOpenGeom 14 cl t0) bndOpen Ly Pb W k).run H s x c bnd start cr t := by
  dsimp only [shdP_blkSegP_zkGuarded]

private theorem shdP_blkSegP_guarded_run_eq {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndCheck : St → ℕ → List Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
    (wt : ShdBlkTables Pk k) (hW : W H s x c k = wt)
    (TBprev TBnext : Table) (CT : CoreTables (Pk k))
    (hBp : wt.TB_prev = TBprev) (hBn : wt.TB_next = TBnext) (hCT : wt.coreT = CT)
    (hOwn : cr.root = rootOf H tag 16 TBprev ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 TBprev.rows (toZClaim cl))
    (sg : SegGeom) (hsg : sgeom s k = sg) :
    let prof := d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen
    let tFrame := blockFrame prof H s k (rootOf H tag 16 TBnext) t
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) CT tFrame
    (shdP_blkSegP_guarded tag Pk sgeom check paths digest bRows bLogN bndCheck bndOpen Ly Pb W k).run H s x c bnd start cr t
      = blkWrapRes
          (blkAlphaBad Ly Pb ((coreB H (Pk k) D tFrame).1, (coreG H (Pk k) D tFrame).1, (coreA H (Pk k) D tFrame).1))
          (coreProve H (Pk k) D tFrame)
          (fun (R : CoreRun) => bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7)
          (fun (R : CoreRun) e =>
            Exec.Block.encSeg bnd sg.l sg.k start
              ⟨some (rootOf H tag 16 TBnext), R.core,
                (bOpen H tag Exec.R13.r13Prm 16 TBprev (cr.pending ++ R.acc.claims.inp) R.t7).1, none⟩ e)
          (fun (R : CoreRun) => ({ pending := R.acc.claims.out, root := rootOf H tag 16 TBnext } : Carry))
          (fun (R : CoreRun) => (bOpen H tag Exec.R13.r13Prm 16 TBprev (cr.pending ++ R.acc.claims.inp) R.t7).2) := by
  subst hBp; subst hBn; subst hCT
  dsimp only [shdP_blkSegP_guarded, shdP_blkSegP, blkWrapRes]
  rw [hW, bgaOf_core (K := shdP_K) H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23]
  cases blkAlphaBad Ly Pb _ with
  | true => rfl
  | false =>
    simp only [Bool.false_eq_true, ↓reduceIte]
    rw [ite_eq_left (decide_eq_true_any hOwn), hsg]
    cases coreProve H (Pk k) _ _ with
    | error _ => rfl
    | ok R => cases bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 <;> rfl

/-- **Exact `.run` equivalence for `blkSegFixedProg`**:
when `active = true` and `cr` is owned by `TB_k` (`treeBPrev`), agrees verbatim with
`shdP_blkSegP_run_zk ... k` AND returns cached `treeBNext` matching `TB_{k+1}`! -/
theorem blkSegFixedProg_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (blkDig : Fin 26 → Dig)
    (k : Fin 26) (st : ClsStmt Hdr) (hdig : digest st k.val = blkDig k)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (hBPrev : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeBPrev.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩)
      ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows (toZClaim cl)) :
    let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
    let res := (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k true cr treeBPrev bnd startTag t).run G
    (res.2.1.getRoot = rootOf (liftH G) tag 16 TBnext
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), res.2.1.path j hj = pathOf (liftH G) tag 16 TBnext j)
    ∧ match (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf k.val).run
          (liftH G) st x c bnd startTag cr t with
      | .ok (enc, cr', t') => res.1 = some (enc, cr') ∧ res.2.2 = t'
      | .error () => res.1 = none := by
  dsimp only
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
  let P := Pk k.val
  let Ly := shdP_layer k.val k.isLt
  let Pb := shdP_blkPub Rp hR k.val k.isLt
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
  let rnd := shdBlkRndOf c k
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TA := blkTA w rnd
  let M := blkTM rnd
  let sg := Exec.Block.R13.segGeom shdP_blkGeom50 0 28 (k.val + 1) 38 2
  let prof := d12aBlockProf Pk (shdP_sgeom Hdr Pk) (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
    (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0) (cbBndOpen tag 38)
  let tFrame := blockFrame prof (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t
  let CT := blkCoreTables P w TBprev TBnext rnd
  let D := coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 P CT tFrame
  have hP_geom : shdP_sgeom Hdr Pk st k.val = sg := by
    unfold shdP_sgeom sg; rw [shdP_Pk0_geom50 tag ioIn ioOut _ Rp hR k.val k.isLt]
  have htFr : tFrame = Exec.Block.absorbRoot (liftH G)
      ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat (k.val + 1)))).absorb (liftH G) labRunBlock (blkDig k).toList)
      labB (rootOf (liftH G) tag 16 TBnext) 38 14 := by
    unfold tFrame blockFrame prof d12aBlockProf Tr.absorbU64; dsimp only; rw [hdig]
  have hProg : blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k true cr treeBPrev bnd startTag t
      = blkSegFixedProg_abs Lq hL20 tag key P k (blkDig k) TBprev TBnext TA
          (fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)
          (fun j => by rw [blkTA_cols_len, blkTA_rows_len])
          M (fun bga => blkTH w rnd bga)
          (fun bga j => by rw [blkTH_cols_len, blkTH_rows_len])
          (blkSlotData P w TA TBprev TBnext rnd) (blkAlphaBad Ly Pb)
          sg cr treeBPrev bnd startTag t := rfl
  have hAbs := blkSegFixedProg_run_abs Lq hL20 tag key P k (blkDig k)
    TBprev TBnext TA
    (fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)
    (fun j => by rw [blkTA_cols_len, blkTA_rows_len])
    (blkTA_rows_len w rnd).symm
    (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩).rows_len.symm
    M (fun bga => blkTH w rnd bga)
    (fun bga j => by rw [blkTH_cols_len, blkTH_rows_len])
    (fun bga => (blkTH_rows_len w rnd bga).symm)
    (blkSlotData P w TA TBprev TBnext rnd) (blkAlphaBad Ly Pb)
    sg cr treeBPrev bnd startTag t htKey G D tFrame htFr
    (coreDataAt_aRoot_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame TA rfl)
    (coreDataAt_maskRoot_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame M rfl)
    (coreDataAt_hRoot_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame (fun bga => blkTH w rnd bga) (fun _ _ _ => rfl))
    (coreDataAt_slot_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame (blkSlotData P w TA TBprev TBnext rnd) rfl)
    (coreDataAt_mOpen_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame M rfl)
    (coreDataAt_aOpen_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame TA rfl)
    (coreDataAt_hOpen_eq (liftH G) tag Exec.R13.r13Prm 16 23 P CT tFrame (fun bga => blkTH w rnd bga) (fun _ _ _ => rfl))
    (shdP_Pk0_slots_length tag ioIn ioOut _ Rp hR k.val k.isLt)
    (fun cl t' => by unfold P Pk; rw [shdP_Pk0_eq_blkParams tag ioIn ioOut _ Rp hR k.val k.isLt]; rfl)
    (fun cl t' => by unfold P Pk; rw [shdP_Pk0_eq_blkParams tag ioIn ioOut _ Rp hR k.val k.isLt]; rfl)
    (shdP_blk_logupSumClaim_empty tag ioIn ioOut _ Rp hR k.val k.isLt)
    (fun s hist acc t' df _ => polySlotData_fitSc hL20 P _ _ _ (shdP_blk_slotD_le5 tag ioIn ioOut _ Rp hR k.val k.isLt) G s hist acc t' df)
    (shdP_blk_terms_fit hL20 tag ioIn ioOut _ Rp hR k.val k.isLt w TBprev TBnext rnd G)
    hBPrev
  rw [hProg]
  generalize (blkSegFixedProg_abs Lq hL20 tag key P k (blkDig k) TBprev TBnext TA
    (fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)
    (fun j => by rw [blkTA_cols_len, blkTA_rows_len])
    M (fun bga => blkTH w rnd bga)
    (fun bga j => by rw [blkTH_cols_len, blkTH_rows_len])
    (blkSlotData P w TA TBprev TBnext rnd) (blkAlphaBad Ly Pb)
    sg cr treeBPrev bnd startTag t).run G = res at hAbs ⊢
  refine ⟨hAbs.1, ?_⟩
  have hTabEq : shdP_blkTables_total tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) shdIncRndOf shdBlkRndOf (liftH G) st x c k.val
      = shdP_blkTables Pk k.val w TBprev TBnext rnd := by
    unfold shdP_blkTables_total; exact dite_eq_left ⟨hx, k.isLt⟩
  rw [shdP_blkSegP_run_zk_eq tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf k.val k.isLt,
      shdP_blkSegP_zkGuarded_run_local,
      shdP_blkSegP_guarded_run_eq tag (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
        (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
        (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
        (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
        (cbBndOpen tag 38) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
        (shdP_blkTables_total tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
          (fun b hb => (hweights b hb).act0) shdIncRndOf shdBlkRndOf) k.val (liftH G) st x c bnd startTag cr t
        (shdP_blkTables Pk k.val w TBprev TBnext rnd) hTabEq TBprev TBnext CT rfl rfl rfl hOwn sg hP_geom]
  generalize hBad : blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
    ((coreB (liftH G) (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
          (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) CT
          (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
            (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
            (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
            (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
            (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t))
        (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
          (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t)).1,
     (coreG (liftH G) (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
          (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) CT
          (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
            (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
            (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
            (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
            (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t))
        (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
          (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t)).1,
     (coreA (liftH G) (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
        (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
          (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) CT
          (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
            (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
            (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
            (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
            (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t))
        (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
          (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t)).1) = bBad
  cases bBad with
  | true => dsimp only [blkWrapRes]; rw [ite_eq_left rfl]; dsimp only; exact hAbs.2.1 hBad
  | false =>
    dsimp only [blkWrapRes]; rw [ite_eq_right Bool.false_ne_true]
    generalize hCp : coreProve (liftH G) (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val)
      (coreDataAt (liftH G) tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23
        (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val) CT
        (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
          (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
          (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
          (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
          (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t))
      (blockFrame (d12aBlockProf (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp)
        (shdP_sgeom Hdr (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp))
        (vdChk check0) shdP_segPaths digest (fun _ => 38) (fun _ => 14)
        (fun _ _ cl t0 => checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t0)
        (cbBndOpen tag 38)) (liftH G) st k.val (rootOf (liftH G) tag 16 TBnext) t) = eCp
    cases eCp with
    | error u => cases u; dsimp only; exact hAbs.2.2.1 hBad hCp
    | ok R =>
      dsimp only
      generalize hOc : checkOpeningExec (liftH G) shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp) R.t7 = eOc
      cases eOc with
      | error eB => dsimp only; exact (hAbs.2.2.2 R hBad hCp).1 eB hOc
      | ok uB => cases uB; dsimp only; exact (hAbs.2.2.2 R hBad hCp).2 hOc

theorem blkSegFixedSliceSpec {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) :
    let P := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp k.val
    SliceSpec Lq tag key domain shape c
      (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c k active cr treeBPrev bnd startTag t)
      base blkSegFixedLen blkSegFixedQ 10862 10862 200704 200700
      st (trChainTip base blkSegFixedLen (by unfold blkSegFixedLen; omega))
      (blkTreeSet k) (blkSegFixedSched P k base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.1 = levelsOfV v 16 base ∧ res.2.2.state = v (base + blkSegFixedLen - 1)) := by
  intro P
  let s : Fin 28 := ⟨k.val + 1, by omega⟩
  have hdA : shdTreeDepthOf (.a s) = 16 := by
    unfold shdTreeDepthOf shdAHDepth; dsimp only [s]; rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  have hdH : shdTreeDepthOf (.h s) = 16 := hdA
  let b0 := base + 131071
  let b1 := b0 + 1
  let b2 := b1 + 1
  let b5 := b2 + 3
  let bA := b5 + 131071
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bB := bM1 + 1
  let bG := bB + 1
  let bAl := bG + 1
  let bH := bAl + 131071
  let bH3 := bH + 3
  let bSl := bH3 + 1283
  let bMo := bSl + 115
  let bAo := bMo + 4824
  let bHo := bAo + 4518
  let bBo := bHo + 107
  let st0 : TrChainState b0 := ⟨st.hasTip, st.trTip, fun ht => by have := st.htip_lt ht; omega, st.afterPosTag, st.hpos⟩
  let st1 := trChainTip b0 1 Nat.zero_lt_one
  let st2 := trChainTip b1 1 Nat.zero_lt_one
  let st5 := trChainTip b2 3 (by norm_num)
  let stA : TrChainState bA := ⟨true, b5 - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stA3 := trChainTip bA 3 (by norm_num)
  let stM : TrChainState bM := ⟨true, bA3 - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stM1 := trChainTip bM 1 Nat.zero_lt_one
  let stB := trChainTip bM1 1 Nat.zero_lt_one
  let stG := trChainTip bB 1 Nat.zero_lt_one
  let stAl := trChainTip bG 1 Nat.zero_lt_one
  let stH : TrChainState bH := ⟨true, bAl - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stH3 := trChainTip bH 3 (by norm_num)
  let stSl := trChainTip bH3 1283 (by norm_num)
  let stMo := trChainTip bSl 115 (by norm_num)
  let stAo := trChainTip bMo 4824 (by norm_num)
  let stHo := trChainTip bAo 4518 (by norm_num)
  let stBo := trChainTip bHo 107 (by norm_num)
  let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  have hBNs : ∀ j : Fin (2 ^ 16), TBnext.salts j.val = shdLeafSalt c ⟨.bnd ⟨k.val + 1, by omega⟩, j⟩ := fun j => by
    dsimp only [TBnext, shdP_bndTableAt, shdP_blkBndTable, mkPcsTable, shdBlkRndOf, shdBndRndOf, shdLeafSalt]; exact extSalt_lt _ j.isLt
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
  have hABs := blkSalts_eq_shdLeafSalt c k
  have hAs : ∀ j : Fin (2 ^ 16), (blkTA w (shdBlkRndOf c k)).salts j.val = shdLeafSalt c ⟨.a s, Fin.cast (by rw [hdA]) j⟩ :=
    fun j => hABs.1 j
  have hHs : ∀ bga (j : Fin (2 ^ 16)), (blkTH w (shdBlkRndOf c k) bga).salts j.val = shdLeafSalt c ⟨.h s, Fin.cast (by rw [hdH]) j⟩ :=
    fun _ j => hABs.2 j
  have hMs : ∀ j : Fin (2 ^ 12), (mTab 23 (cosetPt (rootFp 12)) (blkTM (shdBlkRndOf c k))).salts j.val = shdLeafSalt c ⟨.m s, j⟩ :=
    fun j => by dsimp only [mTab, blkTM, mkMTable, shdBlkRndOf, shdLeafSalt]; exact extSalt_lt _ j.isLt
  unfold blkSegFixedProg blkSegFixedSched; dsimp only
  -- Step 1: B_{k+1} (depth 16)
  refine SliceSpec.seq (len₂ := 281195) (nQ₂ := 416363) (nTrK₂ := 10862) (nT₂ := 10862) (nL₂ := 135168) (nN₂ := 135165)
    (st₂ := trChainTip b0 281195 (by norm_num))
    (trees₂ := fun tid => tid = .a s ∨ tid = .m s ∨ tid = .h s)
    (merkleTableSliceSpec_tree (Lq := Lq) (by omega) hsep domain shape c (.bnd ⟨k.val + 1, by omega⟩) 16 rfl 38 (by omega)
      TBnext (fun j => (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).cols_len j.val)
      hBNs base 131071 196607 65536 65535 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      st st0 ⟨rfl, rfl, rfl⟩ (fun _ v => t.state = v st.trTip))
    (fun treeBNext => ?_) (fun _ hb h => by subst hb; rcases h with h | h | h <;> cases h)
    (by unfold blkSegFixedLen; omega) (by unfold blkSegFixedQ; omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by have : blkSegFixedLen = 412266 := rfl; omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 2: labRunStage
  refine SliceSpec.seq (len₂ := 281194) (nQ₂ := 416362) (nTrK₂ := 10861) (nT₂ := 10861) (nL₂ := 135168) (nN₂ := 135165)
    (st₂ := trChainTip b1 281194 (by norm_num))
    (trees₂ := fun tid => tid = .a s ∨ tid = .m s ∨ tid = .h s)
    ((trAbsorbSliceSpec hL20 hsep domain shape c t labRunStage (by decide) (by decide) (le64 (UInt64.ofNat (k.val + 1))) b0 st0 htip).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun tf1 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 3: labRunBlock
  refine SliceSpec.seq (len₂ := 281193) (nQ₂ := 416361) (nTrK₂ := 10860) (nT₂ := 10860) (nL₂ := 135168) (nN₂ := 135165)
    (st₂ := trChainTip b2 281193 (by norm_num))
    (trees₂ := fun tid => tid = .a s ∨ tid = .m s ∨ tid = .h s)
    ((trAbsorbSliceSpec hL20 hsep domain shape c tf1 labRunBlock (by decide) (by decide) (blkDig k).toList b1 st1 rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun tf2 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 4: labB
  refine SliceSpec.seq (len₂ := 281190) (nQ₂ := 416358) (nTrK₂ := 10857) (nT₂ := 10857) (nL₂ := 135168) (nN₂ := 135165)
    (st₂ := trChainTip b5 281190 (by norm_num))
    (trees₂ := fun tid => tid = .a s ∨ tid = .m s ∨ tid = .h s)
    ((absorbRootSliceSpec hL20 hsep domain shape c tf2 labB (by decide) (by decide) treeBNext.getRoot 38 14 b2 st2 rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun tFrame => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 5: A_{k+1} (depth 16)
  refine SliceSpec.seq (len₂ := 150119) (nQ₂ := 219751) (nTrK₂ := 10857) (nT₂ := 10857) (nL₂ := 69632) (nN₂ := 69630)
    (st₂ := trChainTip bA 150119 (by norm_num))
    (trees₂ := fun tid => tid = .m s ∨ tid = .h s)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.a s) 16 hdA 4577 (by omega)
      (blkTA w (shdBlkRndOf c k)) (fun j => by rw [blkTA_cols_len, blkTA_rows_len]) hAs
      b5 131071 196607 65536 65535 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      st5 stA ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => tFrame.state = v (b5 - 1) ∧ treeBNext = levelsOfV v 16 base))
    (fun treeA => ?_) (fun _ ha h => by subst ha; rcases h with h | h <;> cases h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => ⟨by rw [show b5 - 1 = b2 + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 6: labA
  refine SliceSpec.seq (len₂ := 150116) (nQ₂ := 219748) (nTrK₂ := 10854) (nT₂ := 10854) (nL₂ := 69632) (nN₂ := 69630)
    (st₂ := trChainTip bA3 150116 (by norm_num))
    (trees₂ := fun tid => tid = .m s ∨ tid = .h s)
    ((absorbRootSliceSpec hL20 hsep domain shape c tFrame labA (by decide) (by decide) treeA.getRoot P.aRows P.logCols bA stA rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun tA => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 7: M_{k+1} (depth 12)
  refine SliceSpec.seq (len₂ := 141925) (nQ₂ := 207461) (nTrK₂ := 10854) (nT₂ := 10854) (nL₂ := 65536) (nN₂ := 65535)
    (st₂ := trChainTip bM 141925 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.m s) 12 rfl (2 * 23 + 4) (by omega)
      (mTab 23 (cosetPt (rootFp 12)) (blkTM (shdBlkRndOf c k))) (fun j => mCol_length 23 _ _ j.val) hMs
      bA3 8191 12287 4096 4095 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stA3 stM ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => tA.state = v (bA3 - 1) ∧ treeBNext = levelsOfV v 16 base))
    (fun treeM => ?_) (fun _ hm hh => by subst hm; cases hh)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => ⟨by rw [show bA3 - 1 = bA + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 8: labM
  refine SliceSpec.seq (len₂ := 141924) (nQ₂ := 207460) (nTrK₂ := 10853) (nT₂ := 10853) (nL₂ := 65536) (nN₂ := 65535)
    (st₂ := trChainTip bM1 141924 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    ((trAbsorbSliceSpec hL20 hsep domain shape c tA labM (by decide) (by decide) treeM.getRoot.toList bM stM rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun tM => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 9: beta
  refine SliceSpec.seq (len₂ := 141923) (nQ₂ := 207459) (nTrK₂ := 10852) (nT₂ := 10852) (nL₂ := 65536) (nN₂ := 65535)
    (st₂ := trChainTip bB 141923 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    ((trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c tM bM1 stM1 rfl rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun bR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 10: gamma
  refine SliceSpec.seq (len₂ := 141922) (nQ₂ := 207458) (nTrK₂ := 10851) (nT₂ := 10851) (nL₂ := 65536) (nN₂ := 65535)
    (st₂ := trChainTip bG 141922 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    ((trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c bR.2 bB stB rfl rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun gR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 11: alpha
  refine SliceSpec.seq (len₂ := 141921) (nQ₂ := 207457) (nTrK₂ := 10850) (nT₂ := 10850) (nL₂ := 65536) (nN₂ := 65535)
    (st₂ := trChainTip bAl 141921 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    ((trChallengeFp2SliceSpec (Lq := Lq) (by omega) hsep domain shape c gR.2 bG stG rfl rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun aR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => ⟨hp.1.2.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 12: H_{k+1} (depth 16)
  refine SliceSpec.seq (len₂ := 10850) (nQ₂ := 10850) (nTrK₂ := 10850) (nT₂ := 10850) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH 10850 (by norm_num))
    (trees₂ := fun _ => False)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.h s) 16 hdH 4390 (by omega)
      (blkTH w (shdBlkRndOf c k) (bR.1, gR.1, aR.1)) (fun j => by rw [blkTH_cols_len, blkTH_rows_len])
      (hHs (bR.1, gR.1, aR.1)) bAl 131071 196607 65536 65535 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stAl stH ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => aR.2.state = v (bAl - 1) ∧ treeBNext = levelsOfV v 16 base))
    (fun treeH => ?_) (fun _ _ h => h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with rfl | hf; exact rfl; cases hf) (fun _ _ hp => ⟨hp.1.2.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 13: labH
  refine SliceSpec.seq (len₂ := 10847) (nQ₂ := 10847) (nTrK₂ := 10847) (nT₂ := 10847) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH3 10847 (by norm_num))
    (trees₂ := fun _ => False)
    ((absorbRootSliceSpec hL20 hsep domain shape c aR.2 labH (by decide) (by decide) treeH.getRoot P.hRows P.logCols bH stH rfl).andInv
      (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun t3 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 14: 23 slots (1283)
  have hslLen : slotsFixedLen P 0 23 = 1283 :=
    shdP_blk_slotsFixedLen tag ioIn ioOut _ Rp hR k.val k.isLt
  have hSl : SliceSpec Lq tag key domain shape c
      (slotsProveFixedProg Lq hL20 key P (blkSlotData P w (blkTA w (shdBlkRndOf c k)) TBprev TBnext (shdBlkRndOf c k))
        bR.1 gR.1 aR.1 23 (active && !blkAlphaBad (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt) (bR.1, gR.1, aR.1)) [] 0 {} t3)
      bH3 1283 1283 1283 1283 0 0 stH3 stSl (fun _ => False) (slotsFixedSched P 0 23 bH3 (bH3 - 1))
      (fun _ v => t3.state = v (bH3 - 1)) (fun _ v res => res.2.state = v (bH3 + 1283 - 1)) :=
    slotsProveFixedSliceSpec_n hL20 hsep domain shape c P _ bR.1 gR.1 aR.1 23 _ [] 0 {} t3
      bH3 1283 hslLen (by norm_num) stH3 rfl rfl (bH3 - 1) (sub1_eq_trChainTip (by norm_num) (by omega)).symm
  refine SliceSpec.seq (len₂ := 9564) (nQ₂ := 9564) (nTrK₂ := 9564) (nT₂ := 9564) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bSl 9564 (by norm_num))
    (trees₂ := fun _ => False)
    (hSl.andInv (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun slR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf)
    (fun _ _ hp => ⟨by rw [show bH3 - 1 = bH + 3 - 1 by omega]; exact hp.1.2, hp.2⟩) (fun _ _ _ _ hr => hr)
  -- Step 15: M_{k+1} opening (115)
  refine SliceSpec.seq (len₂ := 9449) (nQ₂ := 9449) (nTrK₂ := 9449) (nT₂ := 9449) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bMo 9449 (by norm_num))
    (trees₂ := fun _ => False)
    ((zkBMaskFixedSliceSpec_n hL20 hsep domain shape c shdP_U shdP_hbij _ (blkTM (shdBlkRndOf c k)) 23 treeM _ slR.2 bSl 115
      (by unfold zkBMaskFixedLen; norm_num) (by norm_num) stSl rfl rfl).andInv (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun mR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 16: A_{k+1} opening (4824)
  refine SliceSpec.seq (len₂ := 4625) (nQ₂ := 4625) (nTrK₂ := 4625) (nT₂ := 4625) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bAo 4625 (by norm_num))
    (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c Exec.R13.r13Prm 16 146 4577 36 shdP_blkOpenGeomA
      (blkTA w (shdBlkRndOf c k)) treeA _ _ _ mR.2 bMo 4824
      (by unfold openingAuditFixedLen Exec.R13.r13Prm; norm_num) (by norm_num) stMo rfl rfl).andInv (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun aOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 17: H_{k+1} opening (4518)
  refine SliceSpec.seq (len₂ := 107) (nQ₂ := 107) (nTrK₂ := 107) (nT₂ := 107) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bHo 107 (by norm_num))
    (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c Exec.R13.r13Prm 16 54 4390 9 shdP_blkOpenGeomH
      (blkTH w (shdBlkRndOf c k) (bR.1, gR.1, aR.1)) treeH _ _ _ aOR.2 bAo 4518
      (by unfold openingAuditFixedLen Exec.R13.r13Prm; norm_num) (by norm_num) stAo rfl rfl).andInv (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun hOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 18: B_k opening (107) + ret
  refine SliceSpec.seq (len₂ := 0) (nQ₂ := 0) (nTrK₂ := 0) (nT₂ := 0) (nL₂ := 0) (nN₂ := 0)
    (st₂ := stBo) (trees₂ := fun _ => False)
    ((openingAuditFixedSliceSpec_n hL20 hsep domain shape c Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom
      TBprev treeBPrev _ _ _ hOR.2 bHo 107
      (by unfold openingAuditFixedLen Exec.R13.r13Prm; norm_num) (by norm_num) stHo rfl rfl).andInv (fun _ v => treeBNext = levelsOfV v 16 base))
    (fun bOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, rfl, rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hBoEq : bHo + 107 - 1 = base + blkSegFixedLen - 1 := by
    have : blkSegFixedLen = 412266 := rfl; omega
  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;>
    exact retSliceSpec _ bBo stBo _ _ (fun _ _ hp => ⟨hp.2, by rw [← hBoEq]; exact hp.1⟩) (fun _ => .absorb 0)

end BlkSegFixed

/-! ## 5. Fixed-schedule Stage `OUT-C` (`outcSegFixedProg` + `.run` + `SliceSpec`) -/

section OutcSegFixed

private theorem shdP_outcTA_cols_len (Rp : ClassifyRunPublicP shieldS0) {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (rnd : OutcRand) (j : Fin (2 ^ 14)) :
    ((shdP_outcTA Rp w rnd).cols j.val).length = 76 := by
  rw [show (76 : ℕ) = (shdP_outcTA Rp w rnd).rows.length from (shdP_outcTA_rows_len Rp w rnd).symm]
  exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _ j.val

private theorem shdP_outcTH_cols_len (Rp : ClassifyRunPublicP shieldS0) {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (rnd : OutcRand) (g a : Fp2) (j : Fin (2 ^ 14)) :
    ((shdP_outcTH Rp w rnd g a).cols j.val).length = 38 := by
  rw [show (38 : ℕ) = (shdP_outcTH Rp w rnd g a).rows.length from (shdP_outcTH_rows_len Rp w rnd g a).symm]
  exact mkPcsTable_cols_length 12 2 256 (by norm_num) _ _ j.val

private theorem shdP_outc_slotD_le5 (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig)
    (bOutRow v s : ℕ) :
    slotD (shdVo tag Rp wDigest bOutRow v).bp s ≤ 5 := by
  obtain ⟨_, _, _, hsl⟩ := shdP_outcLay_nums Rp wDigest
  change ((outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).geomSlots.getD s (0, 0, 0)).2.2 ≤ 5
  rw [rc_outcLay_verdict, hsl]
  match s with
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 => decide
  | _ + 8 => simp

private theorem shdP_outc_terms_fit {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ)
    {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (TA TB : Table) (rnd : OutcRand) (G : QB Lq → Dig) :
    let V := shdVo tag Rp wDigest bOutRow v
    let D := shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB rnd
    ∀ s hist acc t df,
      V.bp.define s hist (t.challengeFp2Vec (liftH G) (V.bp.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks V.bp s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) V.bp D s hist acc t df).terms.length * 16 ≤ Lq := by
  intro V D s hist acc t df _ hchk
  have hlen : (slotSP (liftH G) V.bp D s hist acc t df).terms.length = (df.tabs.filter Exec.Block.Tab.isPriv).length := by
    unfold slotSP D shdP_outcSlotData polySlotData; dsimp only
    exact stgPrivVals_length shdP_U shdP_hbij _ _ _ _ df.tabs
  have hn := slotDefChecks_nPriv V.bp s acc df hchk
  have hst : Exec.Block.slotTerms V.bp s ≤ 32 := by
    change ([2, 1, 11, 1, 2, 19, 2, 1] : List ℕ).getD s 0 ≤ 32
    match s with | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 => decide | _ + 8 => simp
  have hlab : Exec.Block.labPbTerm.length = 7 := by decide
  rw [hlen, hn, hlab]; omega

/-- **Fixed-schedule Stage `OUT-C` (`74,522` `.pt`s, `111,386` total queries)**:
absorbs `OutcV.frame` (`2`), commits `A_27` (`2^14`), absorbs `A_27` (`3`), commits `M_27` (`2^12`),
absorbs `M_27` (`1`), draws `(γ, α)` (`2`), checks `outcAlphaBad`, commits `H_27` (`2^14`),
absorbs `H_27` (`3`), runs `8` fixed-schedule slots (`290`), `M_27` opening (`85`), `A_27` opening (`186`),
`H_27` opening (`118`), and cached `B_26` opening (`107`). -/
noncomputable def outcSegFixedProg (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (active : Bool) (cr : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option (Dig → List UInt8) × Tr) :=
  let v := (classifySpecP Rp x).getD 0
  let V := shdVo tag Rp wDigest bOutRow v
  let G := rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28
  let w := outcWitness_of_adm Rp houtPub x hx
  let rnd := shdOutcRndOf c
  let TA := shdP_outcTA Rp w rnd
  let M := shdP_outcM rnd
  let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩
  (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat V.stageIndex))).andThen fun tf1 =>
    (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) wDigest.toList).andThen fun tFrame =>
      (merkleTableProg Lq (by omega) tag 14 76 (by omega) TA (shdP_outcTA_cols_len Rp w rnd)).andThen fun treeA =>
        let aRoot := treeA.getRoot
        (absorbRootKeyed Lq hL20 key tFrame labA (by decide) aRoot V.bp.aRows V.bp.logCols).andThen fun tA =>
          (merkleTableProg Lq (by omega) tag 12 (2 * 8 + 4) (by omega) (mTab 8 (cosetPt (rootFp 12)) M)
              (fun j => mCol_length 8 _ M j.val)).andThen fun treeM =>
            let mRoot := treeM.getRoot
            (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
              (trChallengeFp2VecKeyed Lq (by omega) key 2 tM).andThen fun chR =>
                let ch := chR.1
                let TH := shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
                let active1 := active && !outcAlphaBad ch
                (merkleTableProg Lq (by omega) tag 14 38 (by omega) TH (shdP_outcTH_cols_len Rp w rnd _ _)).andThen fun treeH =>
                  let hRoot := treeH.getRoot
                  (absorbRootKeyed Lq hL20 key chR.2 labH (by decide) hRoot V.bp.hRows V.bp.logCols).andThen fun t3 =>
                    let Dslot := shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd
                    let bga := OutcV.bga ch
                    (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 active1 [] 0 {} t3).andThen fun slR =>
                      let active2 := match slR.1 with
                        | some (_, _, acc) =>
                          decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
                        | none => false
                      let fs := match slR.1 with
                        | some (_, _, acc) => acc.fs ++ acc.hostFs
                        | none => []
                      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 8 treeM fs slR.2).andThen fun mR =>
                        let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                        (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16
                            (shdP_outcOpenGeomA V) TA treeA active2
                            (openingHdrOk (shdP_outcOpenGeomA V) 12 clA) clA mR.2).andThen fun aOR =>
                          let active3 := active2 && aOR.1.isSome
                          let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
                          (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5
                              (shdP_outcOpenGeomH V) TH treeH active3
                              (openingHdrOk (shdP_outcOpenGeomH V) 12 clH) clH aOR.2).andThen fun hOR =>
                            let active4 := active3 && hOR.1.isSome
                            let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
                            (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                                shdP_bndOpenGeom TB26 treeB26 active4
                                (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                              match slR.1, aOR.1, hOR.1, bOR.1 with
                              | some (sps, _, _), some aO, some hO, some bO =>
                                if active4 then
                                  let seg : StageSeg := ⟨none, ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩, [bO]⟩
                                  .ret (some (fun e => encStage G bnd startTag seg e), bOR.2)
                                else .ret (none, bOR.2)
                              | _, _, _, _ => .ret (none, bOR.2)

/-- Static point schedule of `outcSegFixedProg` (`74,522` queries starting at `base`). -/
def outcSegFixedSched (P0out : BlockParams) (base tip : ℕ) : ℕ → RawPtSpec :=
  let s : Fin 28 := ⟨27, by decide⟩
  let b1 := base + 1
  let b2 := b1 + 1
  let bA := b2 + 32767
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bCh := bM1 + 2
  let bH := bCh + 32767
  let bH3 := bH + 3
  let bSl := bH3 + 290
  let bMo := bSl + 85
  let bAo := bMo + 186
  let bHo := bAo + 118
  let bBo := bHo + 107
  spliceSched b1 (fun _ => .absorb tip)
    (spliceSched b2 (fun _ => .absorb base)
      (spliceSched bA (merkleTreeSched (.a s) b2)
        (spliceSched bA3 (absorbRootSched bA b1)
          (spliceSched bM (merkleTreeSched (.m s) bA3)
            (spliceSched bM1 (fun _ => .absorb (bA3 - 1))
              (spliceSched bCh (squeezeVecSched bM1 bM)
                (spliceSched bH (merkleTreeSched (.h s) bCh)
                  (spliceSched bH3 (absorbRootSched bH (bCh - 1))
                    (spliceSched bSl (slotsFixedSched P0out 0 8 bH3 (bH3 - 1))
                      (spliceSched bMo (zkBMaskFixedSched 8 bSl (bSl - 1))
                        (spliceSched bAo (openingAuditFixedSched 29 76 16 256 bMo (bMo - 1))
                          (spliceSched bHo (openingAuditFixedSched 10 38 5 256 bAo (bAo - 1))
                            (spliceSched bBo (openingAuditFixedSched 2 38 2 256 bHo (bHo - 1))
                              (fun _ => .absorb 0))))))))))))))

/-- Trees touched by Stage `OUT-C`: `{A_27, M_27, H_27}`. -/
def outcTreeSet (tid : ShdTreeId) : Prop :=
  let s : Fin 28 := ⟨27, by decide⟩
  tid = .a s ∨ tid = .m s ∨ tid = .h s

theorem outcSegFixedProg_run_inactive (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (G : QB Lq → Dig) :
    ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c false cr treeB26 bnd startTag t).run G).1 = none := by
  unfold outcSegFixedProg
  repeat rw [PProg.run_andThen]
  simp only [Bool.false_and]
  rw [slotsProveFixedProg_run_inactive]
  dsimp only
  rfl

private theorem outcSeg_openA_run_gen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 76) (hgg : g.groups = 16)
    (hsite : g.siteRows = List.range' 16 58) (hsum : g.sumRows = none)
    (TA : Table) (hArows : 76 = TA.rows.length) (trA : MerkleLevels 14)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 14), trA.path j hj = pathOf (liftH G) tag 14 TA j) :
    let res := (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16
      g TA trA true (openingHdrOk g 12 cl) cl t5).run G
    match checkOpeningExec (liftH G) g 12 cl t5 with
    | .ok () => res = (some (bOpen (liftH G) tag shdP_stgPrm 14 TA cl t5).1,
                       (bOpen (liftH G) tag shdP_stgPrm 14 TA cl t5).2)
    | .error _ => res.1 = none := by
  have hStgLog : shdP_stgPrm.logCols = 12 := rfl
  have hStgNN : shdP_stgPrm.nn = 2 ^ 14 := by norm_num [shdP_stgPrm, PcsPrm.nn]
  have hStgNQ : 0 < shdP_stgPrm.nQ := by norm_num [shdP_stgPrm]
  have hStgFit := pcsCombVec_fit hL20 shdP_stgPrm (by norm_num [shdP_stgPrm, PcsPrm.n])
  have h := openingAuditFixedProg_run Lq hL20 tag key shdP_stgPrm 14 29 76 16
    hStgNN hStgNQ g TA hArows hgr hgg trA cl t5 ht5Key G
    hStgFit.1 hStgFit.2
    (fun og haud hog _ => by
      rw [hStgLog] at hog
      rw [openingGroupsAt_sum_eq_length cl 12 og hog]
      have haud' : auditClaims cl (2 ^ 12) 76 (List.range' 16 (2 * 29)) none g.prox = .ok () := by
        rw [hStgLog, hgr, hsite, hsum] at haud
        rw [show (2 : ℕ) * 29 = 58 by norm_num]; exact haud
      exact auditClaims_length_none cl (2 ^ 12) 76 16 29 g.prox (by norm_num) haud')
    hTreeA
  rw [hStgLog] at h; exact h

private theorem outcSeg_openH_run_gen (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 38) (hgg : g.groups = 5)
    (hsite : g.siteRows = List.range' 18 18) (u1 u2 : ℕ) (hsum : g.sumRows = some (u1, u2))
    (TH : Table) (hHrows : 38 = TH.rows.length) (trH : MerkleLevels 14)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 14), trH.path j hj = pathOf (liftH G) tag 14 TH j) :
    let clH := clH0 ++ [sumCl]
    let res := (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5
      g TH trH true (openingHdrOk g 12 clH) clH t6).run G
    match checkOpeningExec (liftH G) g 12 clH t6 with
    | .ok () => res = (some (bOpen (liftH G) tag shdP_stgPrm 14 TH clH t6).1,
                       (bOpen (liftH G) tag shdP_stgPrm 14 TH clH t6).2)
    | .error _ => res.1 = none := by
  have hStgLog : shdP_stgPrm.logCols = 12 := rfl
  have hStgNN : shdP_stgPrm.nn = 2 ^ 14 := by norm_num [shdP_stgPrm, PcsPrm.nn]
  have hStgNQ : 0 < shdP_stgPrm.nQ := by norm_num [shdP_stgPrm]
  have hStgFit := pcsCombVec_fit hL20 shdP_stgPrm (by norm_num [shdP_stgPrm, PcsPrm.n])
  have h := openingAuditFixedProg_run Lq hL20 tag key shdP_stgPrm 14 10 38 5
    hStgNN hStgNQ g TH hHrows hgr hgg trH (clH0 ++ [sumCl]) t6 ht6Key G
    hStgFit.1 hStgFit.2
    (fun og haud hog _ => by
      rw [hStgLog] at hog
      rw [openingGroupsAt_sum_eq_length _ 12 og hog]
      have haud' : auditClaims (clH0 ++ [sumCl]) (2 ^ 12) 38 (List.range' 18 (2 * 9)) (some (u1, u2)) g.prox = .ok () := by
        rw [hStgLog, hgr, hsite, hsum] at haud
        rw [show (2 : ℕ) * 9 = 18 by norm_num]; exact haud
      exact auditClaims_length_some_last clH0 sumCl hsumEmpty (2 ^ 12) 38 18 9 u1 u2 g.prox (by norm_num) haud')
    hTreeH
  rw [hStgLog] at h; exact h

private theorem outcSeg_openA_run_gen_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 76) (hgg : g.groups = 16)
    (hsite : g.siteRows = List.range' 16 58) (hsum : g.sumRows = none)
    (TA : Table) (hArows : 76 = TA.rows.length) (trA : MerkleLevels 14)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 14), trA.path j hj = pathOf (liftH G) tag 14 TA j)
    (hchk : checkOpeningExec (liftH G) g 12 cl t5 = .ok ()) :
    (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16
      g TA trA true (openingHdrOk g 12 cl) cl t5).run G =
      (some (bOpen (liftH G) tag shdP_stgPrm 14 TA cl t5).1,
       (bOpen (liftH G) tag shdP_stgPrm 14 TA cl t5).2) := by
  have h := outcSeg_openA_run_gen Lq hL20 tag key g hgr hgg hsite hsum TA hArows trA cl t5 ht5Key G hTreeA
  dsimp only at h; rw [hchk] at h; exact h

private theorem outcSeg_openA_run_gen_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 76) (hgg : g.groups = 16)
    (hsite : g.siteRows = List.range' 16 58) (hsum : g.sumRows = none)
    (TA : Table) (hArows : 76 = TA.rows.length) (trA : MerkleLevels 14)
    (cl : List Exec.Block.ZClaim) (t5 : Tr) (ht5Key : t5.key = key) (G : QB Lq → Dig)
    (hTreeA : ∀ (j : ℕ) (hj : j < 2 ^ 14), trA.path j hj = pathOf (liftH G) tag 14 TA j)
    (e : String) (hchk : checkOpeningExec (liftH G) g 12 cl t5 = .error e) :
    ((openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16
      g TA trA true (openingHdrOk g 12 cl) cl t5).run G).1 = none := by
  have h := outcSeg_openA_run_gen Lq hL20 tag key g hgr hgg hsite hsum TA hArows trA cl t5 ht5Key G hTreeA
  dsimp only at h; rw [hchk] at h; exact h

private theorem outcSeg_openH_run_gen_ok (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 38) (hgg : g.groups = 5)
    (hsite : g.siteRows = List.range' 18 18) (u1 u2 : ℕ) (hsum : g.sumRows = some (u1, u2))
    (TH : Table) (hHrows : 38 = TH.rows.length) (trH : MerkleLevels 14)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 14), trH.path j hj = pathOf (liftH G) tag 14 TH j)
    (hchk : checkOpeningExec (liftH G) g 12 (clH0 ++ [sumCl]) t6 = .ok ()) :
    (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5
      g TH trH true (openingHdrOk g 12 (clH0 ++ [sumCl])) (clH0 ++ [sumCl]) t6).run G =
      (some (bOpen (liftH G) tag shdP_stgPrm 14 TH (clH0 ++ [sumCl]) t6).1,
       (bOpen (liftH G) tag shdP_stgPrm 14 TH (clH0 ++ [sumCl]) t6).2) := by
  have h := outcSeg_openH_run_gen Lq hL20 tag key g hgr hgg hsite u1 u2 hsum TH hHrows trH clH0 sumCl hsumEmpty t6 ht6Key G hTreeH
  dsimp only at h; rw [hchk] at h; exact h

private theorem outcSeg_openH_run_gen_err (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (key : Option Dig)
    (g : OpenGeom) (hgr : g.rows = 38) (hgg : g.groups = 5)
    (hsite : g.siteRows = List.range' 18 18) (u1 u2 : ℕ) (hsum : g.sumRows = some (u1, u2))
    (TH : Table) (hHrows : 38 = TH.rows.length) (trH : MerkleLevels 14)
    (clH0 : List Exec.Block.ZClaim) (sumCl : Exec.Block.ZClaim)
    (hsumEmpty : sumCl.parts.all (fun p => p.point.isEmpty) = true)
    (t6 : Tr) (ht6Key : t6.key = key) (G : QB Lq → Dig)
    (hTreeH : ∀ (j : ℕ) (hj : j < 2 ^ 14), trH.path j hj = pathOf (liftH G) tag 14 TH j)
    (e : String) (hchk : checkOpeningExec (liftH G) g 12 (clH0 ++ [sumCl]) t6 = .error e) :
    ((openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5
      g TH trH true (openingHdrOk g 12 (clH0 ++ [sumCl])) (clH0 ++ [sumCl]) t6).run G).1 = none := by
  have h := outcSeg_openH_run_gen Lq hL20 tag key g hgr hgg hsite u1 u2 hsum TH hHrows trH clH0 sumCl hsumEmpty t6 ht6Key G hTreeH
  dsimp only at h; rw [hchk] at h; exact h

private noncomputable def outcSegFixedProg_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G0 : StageGeom) (wDigest : Dig)
    (TA TB26 : Table)
    (hTAc : ∀ j : Fin (2 ^ 14), (TA.cols j.val).length = 76)
    (M : MTable)
    (TH : List Fp2 → Table)
    (hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 38)
    (Dslot : SlotData V.bp) (cr : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) :
    PProg (QB Lq) Dig (Option (Dig → List UInt8) × Tr) :=
  (trAbsorbKeyed Lq hL20 key t labRunStage (by decide) (le64 (UInt64.ofNat V.stageIndex))).andThen fun tf1 =>
    (trAbsorbKeyed Lq hL20 key tf1 labRunBlock (by decide) wDigest.toList).andThen fun tFrame =>
      (merkleTableProg Lq (by omega) tag 14 76 (by omega) TA hTAc).andThen fun treeA =>
        let aRoot := treeA.getRoot
        (absorbRootKeyed Lq hL20 key tFrame labA (by decide) aRoot V.bp.aRows V.bp.logCols).andThen fun tA =>
          (merkleTableProg Lq (by omega) tag 12 (2 * 8 + 4) (by omega) (mTab 8 (cosetPt (rootFp 12)) M)
              (fun j => mCol_length 8 _ M j.val)).andThen fun treeM =>
            let mRoot := treeM.getRoot
            (trAbsorbKeyed Lq hL20 key tA labM (by decide) mRoot.toList).andThen fun tM =>
              (trChallengeFp2VecKeyed Lq (by omega) key 2 tM).andThen fun chR =>
                let ch := chR.1
                let TH0 := TH ch
                let active1 := true && !outcAlphaBad ch
                (merkleTableProg Lq (by omega) tag 14 38 (by omega) TH0 (hTHc ch)).andThen fun treeH =>
                  let hRoot := treeH.getRoot
                  (absorbRootKeyed Lq hL20 key chR.2 labH (by decide) hRoot V.bp.hRows V.bp.logCols).andThen fun t3 =>
                    let bga := OutcV.bga ch
                    (slotsProveFixedProg Lq hL20 key V.bp Dslot bga.1 bga.2.1 bga.2.2 8 active1 [] 0 {} t3).andThen fun slR =>
                      let active2 := match slR.1 with
                        | some (_, _, acc) =>
                          decide ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
                        | none => false
                      let fs := match slR.1 with
                        | some (_, _, acc) => acc.fs ++ acc.hostFs
                        | none => []
                      (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij active2 M 8 treeM fs slR.2).andThen fun mR =>
                        let clA := match slR.1 with | some (_, _, acc) => acc.claims.a | none => []
                        (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16
                            gA TA treeA active2
                            (openingHdrOk gA 12 clA) clA mR.2).andThen fun aOR =>
                          let active3 := active2 && aOR.1.isSome
                          let clH := match slR.1 with | some (_, _, acc) => acc.claims.h ++ [V.lay.logupSumClaim] | none => []
                          (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5
                              gH TH0 treeH active3
                              (openingHdrOk gH 12 clH) clH aOR.2).andThen fun hOR =>
                            let active4 := active3 && hOR.1.isSome
                            let clB := match slR.1 with | some (_, _, acc) => cr.pending ++ acc.claims.inp | none => []
                            (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2
                                shdP_bndOpenGeom TB26 treeB26 active4
                                (openingHdrOk shdP_bndOpenGeom 14 clB) clB hOR.2).andThen fun bOR =>
                              match slR.1, aOR.1, hOR.1, bOR.1 with
                              | some (sps, _, _), some aO, some hO, some bO =>
                                if active4 then
                                  let seg : StageSeg := ⟨none, ⟨aRoot, hRoot, mRoot, sps, mR.1, aO, hO⟩, [bO]⟩
                                  .ret (some (fun e => encStage G0 bnd startTag seg e), bOR.2)
                                else .ret (none, bOR.2)
                              | _, _, _, _ => .ret (none, bOR.2)

private theorem outcProve_err (H : HIn → Dig) (V : OutcV) (D : OutcData V) (cr : Carry) (t : Tr)
    (hown : D.own cr = true) (h : outcProve H V D cr t = .error ()) :
    let ch := (outcCh H V D t).1
    let t3 := Exec.Block.absorbRoot H (outcCh H V D t).2 labH (D.hRoot ch) V.bp.hRows V.bp.logCols
    outcAlphaBad ch = true
    ∨ (outcAlphaBad ch = false
        ∧ (slotsProve H V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 V.lay.ns [] 0 {} t3 = .error ()
          ∨ ∃ sps recs acc t4,
              slotsProve H V.bp D.slot (OutcV.bga ch).1 (OutcV.bga ch).2.1 (OutcV.bga ch).2.2 V.lay.ns [] 0 {} t3 = .ok (sps, recs, acc, t4)
              ∧ (¬ ((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
                ∨ (((acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = [])
                    ∧ ((∃ e, V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
                      ∨ (V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .ok ()
                          ∧ ((∃ e, V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
                            ∨ (V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .ok ()
                                ∧ ∃ e, V.bCheck H (cr.pending ++ acc.claims.inp)
                                    (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e)))))))) := by
  dsimp only
  unfold outcProve at h
  rw [hown] at h; simp only [Bool.true_eq_false, ↓reduceIte] at h
  cases hbad : outcAlphaBad (outcCh H V D t).1 with
  | true => exact Or.inl rfl
  | false =>
    right; refine ⟨rfl, ?_⟩
    simp only [hbad, Bool.false_eq_true, ↓reduceIte] at h
    cases hsl : slotsProve H V.bp D.slot (OutcV.bga (outcCh H V D t).1).1
        (OutcV.bga (outcCh H V D t).1).2.1 (OutcV.bga (outcCh H V D t).1).2.2 V.lay.ns [] 0 {}
        (Exec.Block.absorbRoot H (outcCh H V D t).2 labH (D.hRoot (outcCh H V D t).1) V.bp.hRows V.bp.logCols) with
    | error u => cases u; exact Or.inl rfl
    | ok vSl =>
      rcases vSl with ⟨sps, recs, acc, t4⟩
      right; refine ⟨sps, recs, acc, t4, rfl, ?_⟩
      rw [hsl] at h; dsimp only at h
      by_cases hcond : (acc.fs ++ acc.hostFs).length = V.lay.nFunctionals ∧ acc.claims.out = []
      · right; refine ⟨hcond, ?_⟩
        rw [ite_eq_right (not_not.mpr hcond.1), ite_eq_right (not_not.mpr hcond.2)] at h
        cases hcA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inl ⟨e, rfl⟩
        | ok u1 =>
          cases u1; right; refine ⟨rfl, ?_⟩
          rw [hcA] at h; dsimp only at h
          cases hcH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inl ⟨e, rfl⟩
          | ok u2 =>
            cases u2; right; refine ⟨rfl, ?_⟩
            rw [hcH] at h; dsimp only at h
            cases hcB : V.bCheck H (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact ⟨e, rfl⟩
            | ok u3 => rw [hcB] at h; cases h
      · exact Or.inl hcond

private theorem outcSegFixedProg_run_abs (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (V : OutcV) (gA gH : OpenGeom) (G0 : StageGeom) (wDigest : Dig)
    (TA TB26 : Table)
    (hTAc : ∀ j : Fin (2 ^ 14), (TA.cols j.val).length = 76)
    (hTAr : 76 = TA.rows.length) (hTB26r : 38 = TB26.rows.length)
    (M : MTable)
    (TH : List Fp2 → Table)
    (hTHc : ∀ ch, ∀ j : Fin (2 ^ 14), ((TH ch).cols j.val).length = 38)
    (hTHr : ∀ ch, 38 = (TH ch).rows.length)
    (Dslot : SlotData V.bp) (cr : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (htKey : t.key = key) (G : QB Lq → Dig)
    (D : OutcData V)
    (hOwn : D.own cr = true)
    (hDaR : D.aRoot = rootOf (liftH G) tag 14 TA)
    (hDmR : D.maskRoot = rootOf (liftH G) tag 12 (mTab 8 (cosetPt (rootFp 12)) M))
    (hDhR : ∀ ch, D.hRoot ch = rootOf (liftH G) tag 14 (TH ch))
    (hDslot : D.slot = Dslot)
    (hDmOpen : D.mOpen = bMask (liftH G) tag shdP_U shdP_hbij M 8)
    (hDaOpen : D.aOpen = bOpen (liftH G) tag shdP_stgPrm 14 TA)
    (hDhOpen : D.hOpen = bOpen (liftH G) tag shdP_stgPrm 14 (TH (outcCh (liftH G) V D t).1))
    (hDbOpen : D.bOpen = bOpen (liftH G) tag Exec.R13.r13Prm 16 TB26)
    (hV_ns : V.lay.ns = 8) (hV_wd : V.pub.wDigest = wDigest)
    (hgA_r : gA.rows = 76) (hgA_g : gA.groups = 16)
    (hgA_s : gA.siteRows = List.range' 16 58) (hgA_sum : gA.sumRows = none)
    (hgH_r : gH.rows = 38) (hgH_g : gH.groups = 5)
    (hgH_s : gH.siteRows = List.range' 18 18) (u1 u2 : ℕ) (hgH_sum : gH.sumRows = some (u1, u2))
    (hV_chkA : ∀ cl t', V.checkOpening (liftH G) .a cl t' = checkOpeningExec (liftH G) gA 12 cl t')
    (hV_chkH : ∀ cl t', V.checkOpening (liftH G) .h cl t' = checkOpeningExec (liftH G) gH 12 cl t')
    (hV_sumH : V.lay.logupSumClaim.parts.all (fun p => p.point.isEmpty) = true)
    (hV_bChk : ∀ cl t', V.bCheck (liftH G) cl t' = checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t')
    (hfitSc : ∀ s hist acc t' df, V.bp.define s hist (t'.challengeFp2Vec (liftH G) (V.bp.draws s)).1 = .ok df →
      ∀ r_list, r_list ∈ (scProve (liftH G) (slotN V.bp s)
        (Dslot.strat s hist acc df (slotC (liftH G) V.bp s t'))
        (slotT4 (liftH G) V.bp s t' (Dslot.scalar s hist acc df (slotC (liftH G) V.bp s t')))).1 →
        48 + scLabel.length + r_list.length * 16 ≤ Lq)
    (hfitTerms : ∀ s hist acc t' df, V.bp.define s hist (t'.challengeFp2Vec (liftH G) (V.bp.draws s)).1 = .ok df →
      Exec.Block.slotDefChecks V.bp s acc df = .ok () →
      48 + Exec.Block.labPbTerm.length + (slotSP (liftH G) V.bp Dslot s hist acc t' df).terms.length * 16 ≤ Lq)
    (hB26 : ∀ (j : ℕ) (hj : j < 2 ^ 16), treeB26.path j hj = pathOf (liftH G) tag 16 TB26 j) :
    let res := (outcSegFixedProg_abs Lq hL20 tag key V gA gH G0 wDigest TA TB26 hTAc M TH hTHc Dslot cr treeB26 bnd startTag t).run G
    (outcProve (liftH G) V D cr t = .error () → res.1 = none)
    ∧ (∀ R, outcProve (liftH G) V D cr t = .ok R →
        res = (some (fun e => encStage G0 bnd startTag R.seg e), R.t8)) := by
  dsimp only
  generalize hres : (outcSegFixedProg_abs Lq hL20 tag key V gA gH G0 wDigest TA TB26 hTAc M TH hTHc Dslot cr treeB26 bnd startTag t).run G = res
  unfold outcSegFixedProg_abs at hres
  dsimp only at hres
  rw [run_andThen_trAbsorb htKey (by rw [le64_length]; change 48 + 12 + 8 ≤ Lq; omega),
      run_andThen_trAbsorb (tr_absorb_key _ _ _ _ htKey) (by rw [List.Vector.toList_length]; change 48 + 12 + 32 ≤ Lq; omega)] at hres
  obtain ⟨trA, htrA, hTreeA⟩ := merkle_andThen_elim Lq (by omega) tag 14 76 (by omega) TA hTAc G
  rw [run_andThen_with _ _ G trA htrA] at hres; clear htrA
  rw [run_andThen_absorbRoot (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))] at hres
  obtain ⟨trM, htrM, hTreeM⟩ := merkle_andThen_elim Lq (by omega) tag 12 (2 * 8 + 4) (by omega)
      (mTab 8 (cosetPt (rootFp 12)) M) (fun j => mCol_length 8 _ M j.val) G
  rw [run_andThen_with _ _ G trM htrM] at hres; clear htrM
  have htMKey : ((Exec.Block.absorbRoot (liftH G)
      ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat V.stageIndex))).absorb (liftH G) labRunBlock wDigest.toList)
      labA trA.getRoot V.bp.aRows V.bp.logCols)).key = key :=
    absorbRoot_key _ _ _ _ _ _ (tr_absorb_key _ _ _ _ (tr_absorb_key _ _ _ _ htKey))
  rw [run_andThen_trAbsorb htMKey (by rw [List.Vector.toList_length]; change 48 + 1 + 32 ≤ Lq; omega),
      run_andThen_trChallengeFp2Vec (tr_absorb_key _ _ _ _ htMKey)] at hres
  have hChEq :
      ((Exec.Block.absorbRoot (liftH G)
          ((t.absorb (liftH G) labRunStage (le64 (UInt64.ofNat V.stageIndex))).absorb (liftH G) labRunBlock wDigest.toList)
          labA trA.getRoot V.bp.aRows V.bp.logCols).absorb (liftH G) labM trM.getRoot.toList).challengeFp2Vec (liftH G) 2
      = outcCh (liftH G) V D t := by
    dsimp only [outcCh, OutcV.frame, Tr.absorbU64]
    rw [hTreeA.1, hTreeM.1, hV_wd, hDaR, hDmR]
  have hChKey : (outcCh (liftH G) V D t).2.key = key := by
    rw [← hChEq, tr_challengeFp2Vec_key]; exact tr_absorb_key _ _ _ _ htMKey
  rw [hChEq] at hres
  obtain ⟨trH, htrH, hTreeH⟩ := merkle_andThen_elim Lq (by omega) tag 14 38 (by omega)
      (TH (outcCh (liftH G) V D t).1) (hTHc _) G
  rw [run_andThen_with _ _ G trH htrH] at hres; clear htrH
  rw [run_andThen_absorbRoot hChKey] at hres
  have ht3Eq : Exec.Block.absorbRoot (liftH G) (outcCh (liftH G) V D t).2 labH trH.getRoot V.bp.hRows V.bp.logCols
      = Exec.Block.absorbRoot (liftH G) (outcCh (liftH G) V D t).2 labH (D.hRoot (outcCh (liftH G) V D t).1) V.bp.hRows V.bp.logCols := by
    rw [hTreeH.1, hDhR]
  have ht3Key : (Exec.Block.absorbRoot (liftH G) (outcCh (liftH G) V D t).2 labH (D.hRoot (outcCh (liftH G) V D t).1) V.bp.hRows V.bp.logCols).key = key :=
    absorbRoot_key _ _ _ _ _ _ hChKey
  refine ⟨fun hOut => ?_, fun R hOut => ?_⟩
  · have herr := outcProve_err (liftH G) V D cr t hOwn hOut
    dsimp only at herr
    rcases herr with hbad | ⟨hbad, hrest⟩
    · rw [hbad] at hres; simp only [Bool.not_true, Bool.and_false] at hres
      rw [← hres]
      exact run_andThen_with_fst_none _ _ G (slotsProveFixedProg_run_inactive Lq hL20 key _ _ _ _ _ G _ _ _ _ _) fun _ =>
        run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
    · rw [hbad, ht3Eq] at hres; simp only [Bool.not_false, Bool.and_true] at hres
      rcases hrest with hsl | ⟨sps, recs, acc, t4, hsl, hrest2⟩
      · rw [hV_ns, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_err Lq hL20 key V.bp Dslot
          (OutcV.bga (outcCh (liftH G) V D t).1).1 (OutcV.bga (outcCh (liftH G) V D t).1).2.1
          (OutcV.bga (outcCh (liftH G) V D t).1).2.2 G hfitSc hfitTerms 8 [] 0 {} _ ht3Key hsl
        rw [← hres]
        exact run_andThen_with_fst_none _ _ G hSlRun fun _ =>
          run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ =>
            run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
      · rw [hV_ns, hDslot] at hsl
        have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key V.bp Dslot
          (OutcV.bga (outcCh (liftH G) V D t).1).1 (OutcV.bga (outcCh (liftH G) V D t).1).2.1
          (OutcV.bga (outcCh (liftH G) V D t).1).2.2 G hfitSc hfitTerms 8 [] 0 {} _ ht3Key sps recs acc t4 hsl
        rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
        rcases hrest2 with hcond | ⟨hcond, hrest3⟩
        · simp only [decide_eq_false hcond, Bool.false_and, Bool.false_eq_true, ↓reduceIte] at hres
          rw [← hres]
          refine run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun ⟨oA, _⟩ =>
            run_andThen_fst_none _ _ G fun ⟨oH, _⟩ => run_andThen_fst_none _ _ G fun ⟨oB, _⟩ => ?_
          dsimp only; cases oA <;> cases oH <;> cases oB <;> rfl
        · simp only [decide_eq_true hcond] at hres
          have ht4Key : t4.key = key := (slotsProve_key (liftH G) V.bp Dslot _ _ _ 8 [] 0 {} _ sps recs acc t4 hsl).trans ht3Key
          have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M 8 trM (acc.fs ++ acc.hostFs) t4 ht4Key G
            (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM.2
          rw [run_andThen_with _ _ G _ hMRun] at hres
          let t5 := (bMask (liftH G) tag shdP_U shdP_hbij M 8 (acc.fs ++ acc.hostFs) t4).2
          have ht5Key : t5.key = key := bMask_key (liftH G) tag shdP_U shdP_hbij M 8 (acc.fs ++ acc.hostFs) t4 key ht4Key
          rcases hrest3 with ⟨eA, hcA⟩ | ⟨hcA, hrest4⟩
          · rw [hV_chkA, hDmOpen] at hcA
            have hARun := outcSeg_openA_run_gen_err Lq hL20 tag key gA
              hgA_r hgA_g hgA_s hgA_sum TA hTAr trA acc.claims.a t5 ht5Key G hTreeA.2 eA hcA
            dsimp only [t5] at hARun; rw [← hres]
            exact run_andThen_with_fst_none _ _ G hARun fun _ =>
              run_andThen_fst_none _ _ G fun _ => run_andThen_fst_none _ _ G fun _ => rfl
          · rw [hV_chkA, hDmOpen] at hcA
            have hARun := outcSeg_openA_run_gen_ok Lq hL20 tag key gA
              hgA_r hgA_g hgA_s hgA_sum TA hTAr trA acc.claims.a t5 ht5Key G hTreeA.2 hcA
            dsimp only [t5] at hARun
            rw [run_andThen_with _ _ G _ hARun] at hres; dsimp only at hres
            simp only [Option.isSome_some, Bool.true_and] at hres
            let t6 := (bOpen (liftH G) tag shdP_stgPrm 14 TA acc.claims.a t5).2
            have ht6Key : t6.key = key := bOpen_key (liftH G) tag shdP_stgPrm 14 TA acc.claims.a t5 key ht5Key
            rcases hrest4 with ⟨eH, hcH⟩ | ⟨hcH, eB, hcB⟩
            · rw [hV_chkH, hDaOpen, hDmOpen] at hcH
              have hHRun := outcSeg_openH_run_gen_err Lq hL20 tag key gH
                hgH_r hgH_g hgH_s u1 u2 hgH_sum
                (TH (outcCh (liftH G) V D t).1) (hTHr _) trH acc.claims.h V.lay.logupSumClaim hV_sumH
                t6 ht6Key G hTreeH.2 eH hcH
              dsimp only [t6, t5] at hHRun; rw [← hres]
              exact run_andThen_with_fst_none _ _ G hHRun fun _ => run_andThen_fst_none _ _ G fun _ => rfl
            · rw [hV_chkH, hDaOpen, hDmOpen] at hcH
              have hHRun := outcSeg_openH_run_gen_ok Lq hL20 tag key gH
                hgH_r hgH_g hgH_s u1 u2 hgH_sum
                (TH (outcCh (liftH G) V D t).1) (hTHr _) trH acc.claims.h V.lay.logupSumClaim hV_sumH
                t6 ht6Key G hTreeH.2 hcH
              dsimp only [t6, t5] at hHRun
              rw [run_andThen_with _ _ G _ hHRun] at hres; dsimp only at hres
              simp only [Option.isSome_some] at hres
              let t7 := (bOpen (liftH G) tag shdP_stgPrm 14 (TH (outcCh (liftH G) V D t).1) (acc.claims.h ++ [V.lay.logupSumClaim]) t6).2
              have ht7Key : t7.key = key := bOpen_key (liftH G) tag shdP_stgPrm 14 (TH (outcCh (liftH G) V D t).1) (acc.claims.h ++ [V.lay.logupSumClaim]) t6 key ht6Key
              rw [hV_bChk, hDhOpen, hDaOpen, hDmOpen] at hcB
              have hBRun := blkSeg_openB_run_err Lq hL20 tag key TB26 hTB26r treeB26 (cr.pending ++ acc.claims.inp) t7 ht7Key G hB26 eB hcB
              dsimp only [t7, t6, t5] at hBRun; rw [← hres]
              exact run_andThen_with_fst_none _ _ G hBRun fun _ => rfl
  · obtain ⟨-, hbad, hRch, hRt3, hsl, hfs, hout, hcA, hcH, hcB, hRbR, hRaR, hRmR, hRhR, hRmO, hRaO, hRhO, hRbC, hRt8⟩ :=
      outcProve_ok (liftH G) V D cr t R hOut
    rw [hRch] at hbad hsl hRhR
    rw [hRt3] at hsl
    rw [hbad, ht3Eq] at hres; simp only [Bool.not_false, Bool.and_true] at hres
    rw [hV_ns, hDslot] at hsl
    have hSlRun := slotsProveFixedProg_run_ok Lq hL20 key V.bp Dslot
      (OutcV.bga (outcCh (liftH G) V D t).1).1 (OutcV.bga (outcCh (liftH G) V D t).1).2.1
      (OutcV.bga (outcCh (liftH G) V D t).1).2.2 G hfitSc hfitTerms 8 [] 0 {} _ ht3Key R.seg.core.slots R.recs R.acc R.t4 hsl
    rw [run_andThen_with _ _ G _ hSlRun] at hres; dsimp only at hres
    simp only [decide_eq_true (And.intro hfs hout)] at hres
    have ht4Key : R.t4.key = key := (slotsProve_key (liftH G) V.bp Dslot _ _ _ 8 [] 0 {} _ R.seg.core.slots R.recs R.acc R.t4 hsl).trans ht3Key
    have hMRun := zkBMaskFixedProg_run Lq hL20 tag key shdP_U shdP_hbij M 8 trM (R.acc.fs ++ R.acc.hostFs) R.t4 ht4Key G
      (polyWords_fit_maskQ hL20 _) (polyWords_fit_maskProx hL20 _) hTreeM.2
    rw [hDmOpen] at hRmO
    have hMRun' : (zkBMaskFixedProg Lq hL20 key shdP_U shdP_hbij true M 8 trM (R.acc.fs ++ R.acc.hostFs) R.t4).run G = (R.seg.core.maskOpen, R.t5) :=
      hMRun.trans hRmO.symm
    rw [run_andThen_with _ _ G _ hMRun'] at hres; dsimp only at hres
    have ht5Key : R.t5.key = key := (congrArg (fun p => p.2.key) hRmO).trans (bMask_key (liftH G) tag shdP_U shdP_hbij M 8 (R.acc.fs ++ R.acc.hostFs) R.t4 key ht4Key)
    rw [hV_chkA] at hcA
    have hARun := outcSeg_openA_run_gen_ok Lq hL20 tag key gA
      hgA_r hgA_g hgA_s hgA_sum TA hTAr trA R.acc.claims.a R.t5 ht5Key G hTreeA.2 hcA
    rw [hDaOpen] at hRaO
    have hARun' : (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 29 76 16 gA TA trA true
        (openingHdrOk gA 12 R.acc.claims.a) R.acc.claims.a R.t5).run G = (some R.seg.core.aOpen, R.t6) :=
      hARun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRaO.symm) : some _ = some R.seg.core.aOpen) (congrArg Prod.snd hRaO.symm : _ = R.t6))
    rw [run_andThen_with _ _ G _ hARun'] at hres; dsimp only at hres
    simp only [Option.isSome_some, Bool.true_and] at hres
    have ht6Key : R.t6.key = key := (congrArg (fun p => p.2.key) hRaO).trans (bOpen_key (liftH G) tag shdP_stgPrm 14 TA R.acc.claims.a R.t5 key ht5Key)
    rw [hV_chkH] at hcH
    have hHRun := outcSeg_openH_run_gen_ok Lq hL20 tag key gH
      hgH_r hgH_g hgH_s u1 u2 hgH_sum
      (TH (outcCh (liftH G) V D t).1) (hTHr _) trH R.acc.claims.h V.lay.logupSumClaim hV_sumH
      R.t6 ht6Key G hTreeH.2 hcH
    rw [hDhOpen] at hRhO
    have hHRun' : (openingAuditFixedProg Lq hL20 key shdP_stgPrm 14 10 38 5 gH (TH (outcCh (liftH G) V D t).1) trH true
        (openingHdrOk gH 12 (R.acc.claims.h ++ [V.lay.logupSumClaim])) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6).run G
        = (some R.seg.core.hOpen, R.t7) :=
      hHRun.trans (Prod.ext (congrArg some (congrArg Prod.fst hRhO.symm) : some _ = some R.seg.core.hOpen) (congrArg Prod.snd hRhO.symm : _ = R.t7))
    rw [run_andThen_with _ _ G _ hHRun'] at hres; dsimp only at hres
    simp only [Option.isSome_some] at hres
    have ht7Key : R.t7.key = key := (congrArg (fun p => p.2.key) hRhO).trans
      (bOpen_key (liftH G) tag shdP_stgPrm 14 (TH (outcCh (liftH G) V D t).1) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 key ht6Key)
    rw [hV_bChk] at hcB
    have hBRun := blkSeg_openB_run_ok Lq hL20 tag key TB26 hTB26r treeB26 (cr.pending ++ R.acc.claims.inp) R.t7 ht7Key G hB26 hcB
    rw [hDbOpen] at hRbC hRt8
    generalize hbO : (bOpen (liftH G) tag Exec.R13.r13Prm 16 TB26 (cr.pending ++ R.acc.claims.inp) R.t7).1 = bO at hBRun hRbC
    have hBRun' : (openingAuditFixedProg Lq hL20 key Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom TB26 treeB26 true
        (openingHdrOk shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp)) (cr.pending ++ R.acc.claims.inp) R.t7).run G = (some bO, R.t8) :=
      hBRun.trans (Prod.ext rfl hRt8.symm)
    rw [run_andThen_with _ _ G _ hBRun'] at hres; dsimp only at hres
    rw [ite_eq_left trivial, PProg.run] at hres
    have hsegEq : (⟨none, ⟨trA.getRoot, trH.getRoot, trM.getRoot, R.seg.core.slots, R.seg.core.maskOpen, R.seg.core.aOpen, R.seg.core.hOpen⟩,
        [bO]⟩ : StageSeg) = R.seg := by
      refine (stageSeg_eq ?_ ?_ ?_ ?_ ?_).trans (stageSeg_eta R.seg)
      · exact hRbR.symm
      · rw [hRaR, hTreeA.1, hDaR]
      · rw [hRhR, hTreeH.1, hDhR]
      · rw [hRmR, hTreeM.1, hDmR]
      · exact hRbC.symm
    rw [hsegEq] at hres
    exact hres.symm

private theorem outcLay_logN (O : OutcPub) (b : ℕ) : (outcLay O b).logN = O.lt := rfl
private theorem outcLay_ns (O : OutcPub) (b : ℕ) : (outcLay O b).ns = 8 := rfl

private theorem shdP_outcOpenGeomA_rows (V : OutcV) : (shdP_outcOpenGeomA V).rows = V.lay.aRows := by
  dsimp only [shdP_outcOpenGeomA]
private theorem shdP_outcOpenGeomA_siteRows (V : OutcV) : (shdP_outcOpenGeomA V).siteRows = V.lay.aSiteRows := by
  dsimp only [shdP_outcOpenGeomA]
private theorem shdP_outcOpenGeomH_rows (V : OutcV) : (shdP_outcOpenGeomH V).rows = V.lay.hRows := by
  dsimp only [shdP_outcOpenGeomH]
private theorem shdP_outcOpenGeomH_siteRows (V : OutcV) : (shdP_outcOpenGeomH V).siteRows = V.lay.hSiteRows := by
  dsimp only [shdP_outcOpenGeomH]
private theorem outcV_wDigest (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow v : ℕ) :
    (shdVo tag Rp wDigest bOutRow v).pub.wDigest = wDigest := rfl

private theorem outcV_checkOpening_a (H : HIn → Dig) (V : OutcV) (hlog : V.lay.logN = 12) (cl : List Exec.Block.ZClaim) (t : Tr) :
    V.checkOpening H .a cl t = checkOpeningExec H (shdP_outcOpenGeomA V) 12 cl t := by
  unfold OutcV.checkOpening shdP_outcOpenGeomA; rw [hlog]

private theorem outcV_checkOpening_h (H : HIn → Dig) (V : OutcV) (hlog : V.lay.logN = 12) (cl : List Exec.Block.ZClaim) (t : Tr) :
    V.checkOpening H .h cl t = checkOpeningExec H (shdP_outcOpenGeomH V) 12 cl t := by
  unfold OutcV.checkOpening shdP_outcOpenGeomH; rw [hlog]

private theorem outcDataAt_abs_own_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr) (cr : Carry)
    (TB : Table) (hTB : C.TB = TB)
    (hOwn : cr.root = rootOf H tag 16 TB ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14 TB.rows (toZClaim cl)) :
    (outcDataAt_abs tag H V C t).own cr = true := by
  subst hTB; exact decide_eq_true_any hOwn

private theorem outcDataAt_abs_aRoot_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (TA : Table) (hTA : C.TA = TA) :
    (outcDataAt_abs tag H V C t).aRoot = rootOf H tag 14 TA := by
  rw [← hTA]; rfl

private theorem outcDataAt_abs_maskRoot_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (M : MTable) (hM : C.M = M) :
    (outcDataAt_abs tag H V C t).maskRoot = rootOf H tag 12 (mTab 8 (cosetPt (rootFp 12)) M) := by
  rw [← hM]; rfl

private theorem outcDataAt_abs_hRoot_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (TH : List Fp2 → Table) (hTH : ∀ ch, C.TH ch = TH ch) (ch : List Fp2) :
    (outcDataAt_abs tag H V C t).hRoot ch = rootOf H tag 14 (TH ch) := by
  rw [← hTH]; rfl

private theorem outcDataAt_abs_slot_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (Dslot : SlotData V.bp) (hS : C.slot = Dslot) :
    (outcDataAt_abs tag H V C t).slot = Dslot := hS

private theorem outcDataAt_abs_mOpen_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (M : MTable) (hM : C.M = M) :
    (outcDataAt_abs tag H V C t).mOpen = bMask H tag shdP_U shdP_hbij M 8 := by
  rw [← hM]; rfl

private theorem outcDataAt_abs_aOpen_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (TA : Table) (hTA : C.TA = TA) :
    (outcDataAt_abs tag H V C t).aOpen = bOpen H tag shdP_stgPrm 14 TA := by
  rw [← hTA]; rfl

private theorem outcDataAt_abs_hOpen_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (TH : List Fp2 → Table) (hTH : ∀ ch, C.TH ch = TH ch) :
    (outcDataAt_abs tag H V C t).hOpen =
      bOpen H tag shdP_stgPrm 14 (TH (outcCh H V (outcDataAt_abs tag H V C t) t).1) := by
  rw [← hTH]; rfl

private theorem outcDataAt_abs_bOpen_eq (tag : MTag) (H : HIn → Dig) (V : OutcV) (C : OutcTables V) (t : Tr)
    (TB : Table) (hTB : C.TB = TB) :
    (outcDataAt_abs tag H V C t).bOpen = bOpen H tag Exec.R13.r13Prm 16 TB := by
  rw [← hTB]; rfl

private theorem outSegP_outcP_abs_run {Hdr Coins : Type} (tag : MTag) (V : ℕ → OutcV)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins → OutcTables (V s.verdict))
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins)
    (bnd startTag : Dig) (cr : Carry) (t : Tr)
    (V0 : OutcV) (hV0 : V0 = V st.verdict)
    (CT : OutcTables V0) (hC : C H st x c = hV0 ▸ CT)
    (D : OutcData V0) (hD : D = outcDataAt_abs tag H V0 CT t) :
    (outSegP _ (outcP_abs tag V C)).run H st x c bnd startTag cr t
      = exceptMapRes (fun (R : OutcRun) e => encStage (rcOutcGeom (V 0) 28) bnd startTag R.seg e)
          (fun (_ : OutcRun) => cr) (fun (R : OutcRun) => R.t8) (outcProve H V0 D cr t) := by
  subst hV0; subst hD
  dsimp only [outSegP, outcP_abs, Bind.bind, Except.bind, exceptMapRes]
  rw [hC]
  cases outcProve H (V st.verdict) (outcDataAt_abs tag H (V st.verdict) CT t) cr t <;> rfl

private theorem outSegP_shdP_outcP_eq {Hdr Coins : Type} (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ)
    (C : (HIn → Dig) → (s : ClsStmt Hdr) → (shieldS0.Tok → ℕ) → Coins →
      OutcTables (shdVo tag Rp wDigest bOutRow s.verdict)) :
    outSegP (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => shdGo tag Rp wDigest bOutRow))
        (shdP_outcP tag Rp wDigest bOutRow C)
      = outSegP (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28))
          (outcP_abs tag (shdVo tag Rp wDigest bOutRow) C) := rfl

/-- **Exact `.run` equivalence for `outcSegFixedProg`**:
when `active = true`, `st.verdict = (classifySpecP Rp x).getD 0`, and `cr` is owned by `TB_26`,
agrees verbatim with `(outSegP _ (shdP_outcP ...)).run (liftH G)`! -/
theorem outcSegFixedProg_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (hver : st.verdict = (classifySpecP Rp x).getD 0) (c : ShdCoins)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig)
    (hB26 : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeB26.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩)
      ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩).rows (toZClaim cl)) :
    ((outSegP _ (shdP_outcP tag Rp wDigest bOutRow
        (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
          (liftH G) st x c bnd startTag cr t = .error () →
      ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x hx c true cr treeB26 bnd startTag t).run G).1 = none)
    ∧ (∀ enc crEnd t',
      (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
        (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
          (liftH G) st x c bnd startTag cr t = .ok (enc, crEnd, t') →
      (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x hx c true cr treeB26 bnd startTag t).run G = (some enc, t')) := by
  cases st with
  | mk hdr inRoot verd =>
  dsimp only at hver
  subst hver
  let v := (classifySpecP Rp x).getD 0
  let V := shdVo tag Rp wDigest bOutRow v
  let w := outcWitness_of_adm Rp houtPub x hx
  let rnd := shdOutcRndOf c
  let TA := shdP_outcTA Rp w rnd
  let M := shdP_outcM rnd
  let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩
  let CT := shdP_outcTables tag Rp wDigest bOutRow v w TB26 rnd
  let D := outcDataAt_abs tag (liftH G) V CT t
  have hnums := shdP_outcLay_nums Rp wDigest
  have hV_aR : V.lay.aRows = 76 := by change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aRows = 76; rw [rc_outcLay_verdict]; exact hnums.1
  have hV_hR : V.lay.hRows = 38 := by change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hRows = 38; rw [rc_outcLay_verdict]; exact hnums.2.1
  have hV_siteA : V.lay.aSiteRows = List.range' 16 58 := by
    have haM : V.lay.aMaskBase = 16 := by
      change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aMaskBase = 16; rw [rc_outcLay_verdict]
      obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
      have hlt : (shdP_outcPub Rp wDigest).lt = 12 := rfl
      simp only [outcLay, outcSched, OutcPub.toLog, Lay.aMaskBase, Lay.aDataRows, Lay.aRowsL, rowsOf,
        hllo, hldo, hltab, hdb, hlt, List.replicate]; norm_num
    have haP : V.lay.aProx = 74 := by change V.lay.aRows - 2 = 74; omega
    unfold Lay.aSiteRows; rw [haM, haP]
  have hV_siteH : V.lay.hSiteRows = List.range' 18 18 := by
    have hhM : V.lay.hMaskBase = 18 := by
      change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hMaskBase = 18; rw [rc_outcLay_verdict]
      obtain ⟨hllo, hldo, hltab, hdb⟩ := shdP_outcPub_logs Rp wDigest
      have hlt : (shdP_outcPub Rp wDigest).lt = 12 := rfl
      simp only [outcLay, outcSched, OutcPub.toLog, Lay.hMaskBase, Lay.hDataRows, Lay.hRowsL, rowsOf,
        hllo, hldo, hltab, hdb, hlt, List.replicate]; norm_num
    have hhP : V.lay.hProx = 36 := by change V.lay.hRows - 2 = 36; omega
    unfold Lay.hSiteRows; rw [hhM, hhP]
  have hV_sumH : V.lay.logupSumClaim.parts.all (fun p => p.point.isEmpty) = true := by
    rw [List.all_eq_true]; intro p hp
    unfold Lay.logupSumClaim at hp
    obtain ⟨i, _, hi⟩ := List.mem_flatMap.mp hp
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hi
    rcases hi with rfl | rfl <;> rfl
  have hV_logN : V.lay.logN = 12 := by
    change (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).logN = 12
    rw [outcLay_logN]; rfl
  have hV_ns : V.lay.ns = 8 := outcLay_ns (rcVerdict (shdP_outcPub Rp wDigest) v) 14
  have hV_bGeo : (⟨V.geo.bRows, List.range' V.geo.bDataRows (2 * V.geo.bSites), none,
      V.geo.bDataRows + 2 * V.geo.bSites, V.geo.bSites⟩ : OpenGeom) = shdP_bndOpenGeom := by
    change (⟨38, List.range' 32 (2 * 2), none, 32 + 2 * 2, 2⟩ : OpenGeom) = shdP_bndOpenGeom
    unfold shdP_bndOpenGeom; rfl
  have hV_bLog : V.geo.bLogN = 14 := rfl
  have hV_bChk : ∀ cl t', V.bCheck (liftH G) cl t' = checkOpeningExec (liftH G) shdP_bndOpenGeom 14 cl t' := fun cl t' => by
    unfold OutcV.bCheck; rw [hV_bGeo, hV_bLog]
  have hProg : outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c true cr treeB26 bnd startTag t
      = outcSegFixedProg_abs Lq hL20 tag key V (shdP_outcOpenGeomA V) (shdP_outcOpenGeomH V)
          (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) wDigest
          TA TB26 (shdP_outcTA_cols_len Rp w rnd)
          M (fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
          (fun ch => shdP_outcTH_cols_len Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
          (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd) cr treeB26 bnd startTag t := rfl
  have hAbs := outcSegFixedProg_run_abs Lq hL20 tag key V (shdP_outcOpenGeomA V) (shdP_outcOpenGeomH V)
    (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) wDigest
    TA TB26 (shdP_outcTA_cols_len Rp w rnd) (shdP_outcTA_rows_len Rp w rnd).symm
    (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩).rows_len.symm
    M (fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
    (fun ch => shdP_outcTH_cols_len Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
    (fun ch => (shdP_outcTH_rows_len Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)).symm)
    (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd) cr treeB26 bnd startTag t htKey G D
    (outcDataAt_abs_own_eq tag (liftH G) V CT t cr TB26 rfl hOwn)
    (outcDataAt_abs_aRoot_eq tag (liftH G) V CT t TA rfl)
    (outcDataAt_abs_maskRoot_eq tag (liftH G) V CT t M rfl)
    (outcDataAt_abs_hRoot_eq tag (liftH G) V CT t (fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)) (fun _ => rfl))
    (outcDataAt_abs_slot_eq tag (liftH G) V CT t (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd) rfl)
    (outcDataAt_abs_mOpen_eq tag (liftH G) V CT t M rfl)
    (outcDataAt_abs_aOpen_eq tag (liftH G) V CT t TA rfl)
    (outcDataAt_abs_hOpen_eq tag (liftH G) V CT t (fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)) (fun _ => rfl))
    (outcDataAt_abs_bOpen_eq tag (liftH G) V CT t TB26 rfl)
    hV_ns (outcV_wDigest tag Rp wDigest bOutRow v)
    ((shdP_outcOpenGeomA_rows V).trans hV_aR) rfl ((shdP_outcOpenGeomA_siteRows V).trans hV_siteA) rfl
    ((shdP_outcOpenGeomH_rows V).trans hV_hR) rfl ((shdP_outcOpenGeomH_siteRows V).trans hV_siteH) V.lay.hURows.1 V.lay.hURows.2 rfl
    (outcV_checkOpening_a (liftH G) V hV_logN)
    (outcV_checkOpening_h (liftH G) V hV_logN)
    hV_sumH hV_bChk
    (fun s hist acc t' df _ => polySlotData_fitSc hL20 V.bp _ _ _ (shdP_outc_slotD_le5 tag Rp wDigest bOutRow v) G s hist acc t' df)
    (shdP_outc_terms_fit hL20 tag Rp wDigest bOutRow v w TA TB26 rnd G)
    hB26
  rw [hProg]
  generalize (outcSegFixedProg_abs Lq hL20 tag key V (shdP_outcOpenGeomA V) (shdP_outcOpenGeomH V)
    (rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28) wDigest
    TA TB26 (shdP_outcTA_cols_len Rp w rnd)
    M (fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
    (fun ch => shdP_outcTH_cols_len Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero))
    (shdP_outcSlotData tag Rp wDigest bOutRow v w TA TB26 rnd) cr treeB26 bnd startTag t).run G = res at hAbs ⊢
  have hTabEq : shdP_outcTables_total tag Rp houtPub wDigest bOutRow
      (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf
      (liftH G) ⟨hdr, inRoot, v⟩ x c
      = shdP_outcTables tag Rp wDigest bOutRow v w TB26 rnd := by
    have h1 : shdP_outcTables_total tag Rp houtPub wDigest bOutRow
        (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf
        (liftH G) ⟨hdr, inRoot, v⟩ x c
        = shdP_outcTables tag Rp wDigest bOutRow v w
            (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf (liftH G) ⟨hdr, inRoot, v⟩ x c) rnd := by
      unfold shdP_outcTables_total; exact dite_eq_left hx
    have h2 : shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf (liftH G) ⟨hdr, inRoot, v⟩ x c = TB26 := by
      unfold shdP_bndTableLast_total; exact dite_eq_left hx
    rw [h1, h2]
  have hOutSeg :
      outSegP (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => shdGo tag Rp wDigest bOutRow))
          (shdP_outcP tag Rp wDigest bOutRow
            (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
              (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))
      = outSegP (outcStageV (fun (_ : Hdr) v => shdVo tag Rp wDigest bOutRow v) (fun _ => rcOutcGeom (shdVo tag Rp wDigest bOutRow 0) 28))
          (outcP_abs tag (shdVo tag Rp wDigest bOutRow)
            (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
              (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf)) :=
    outSegP_shdP_outcP_eq (Hdr := Hdr) tag Rp wDigest bOutRow
      (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
        (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf)
  rw [hOutSeg, outSegP_outcP_abs_run tag (shdVo tag Rp wDigest bOutRow)
    (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
      (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf)
    (liftH G) ⟨hdr, inRoot, v⟩ x c bnd startTag cr t V rfl CT hTabEq D rfl]
  generalize hOut : outcProve (liftH G) V D cr t = eOut
  cases eOut with
  | error u =>
    cases u; dsimp only [exceptMapRes]
    exact ⟨fun _ => hAbs.1 hOut, fun _ _ _ h => by cases h⟩
  | ok R =>
    dsimp only [exceptMapRes]
    refine ⟨(fun h => by cases h), fun enc crEnd t' h => ?_⟩
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    rcases h with ⟨rfl, _, rfl⟩
    exact hAbs.2 R hOut

theorem outcSegFixedSliceSpec {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (active : Bool) (cr : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr)
    (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true) :
    SliceSpec Lq tag key domain shape c
      (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x hx c active cr treeB26 bnd startTag t)
      base outcSegFixedLen outcSegFixedQ 797 797 36864 36861
      st (trChainTip base outcSegFixedLen (by unfold outcSegFixedLen; omega))
      outcTreeSet (outcSegFixedSched (shdP_P0out tag Rp wDigest bOutRow) base st.trTip)
      (fun _ v => t.state = v st.trTip)
      (fun _ v res => res.2.state = v (base + outcSegFixedLen - 1)) := by
  let s : Fin 28 := ⟨27, by decide⟩
  let v := (classifySpecP Rp x).getD 0
  let V := shdVo tag Rp wDigest bOutRow v
  let P0out := shdP_P0out tag Rp wDigest bOutRow
  let b1 := base + 1
  let b2 := b1 + 1
  let bA := b2 + 32767
  let bA3 := bA + 3
  let bM := bA3 + 8191
  let bM1 := bM + 1
  let bCh := bM1 + 2
  let bH := bCh + 32767
  let bH3 := bH + 3
  let bSl := bH3 + 290
  let bMo := bSl + 85
  let bAo := bMo + 186
  let bHo := bAo + 118
  let bBo := bHo + 107
  let st1 := trChainTip base 1 Nat.zero_lt_one
  let st2 := trChainTip b1 1 Nat.zero_lt_one
  let stA : TrChainState bA := ⟨true, b1, fun _ => by omega, false, fun h => by cases h⟩
  let stA3 := trChainTip bA 3 (by norm_num)
  let stM : TrChainState bM := ⟨true, bA3 - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stM1 := trChainTip bM 1 Nat.zero_lt_one
  let stCh := trChainTip bM1 2 (by norm_num)
  let stH : TrChainState bH := ⟨true, bCh - 1, fun _ => by omega, false, fun h => by cases h⟩
  let stH3 := trChainTip bH 3 (by norm_num)
  let stSl := trChainTip bH3 290 (by norm_num)
  let stMo := trChainTip bSl 85 (by norm_num)
  let stAo := trChainTip bMo 186 (by norm_num)
  let stHo := trChainTip bAo 118 (by norm_num)
  let stBo := trChainTip bHo 107 (by norm_num)
  let w := outcWitness_of_adm Rp houtPub x hx
  let TB26 := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨26, by omega⟩
  have hOHs := outcSalts_eq_shdLeafSalt c
  have hAs : ∀ j : Fin (2 ^ 14), (shdP_outcTA Rp w (shdOutcRndOf c)).salts j.val = shdLeafSalt c ⟨.a s, j⟩ := fun j => hOHs.1 j
  have hHs : ∀ g a (j : Fin (2 ^ 14)), (shdP_outcTH Rp w (shdOutcRndOf c) g a).salts j.val = shdLeafSalt c ⟨.h s, j⟩ := fun _ _ j => hOHs.2 j
  have hMs : ∀ j : Fin (2 ^ 12), (mTab 8 (cosetPt (rootFp 12)) (shdP_outcM (shdOutcRndOf c))).salts j.val = shdLeafSalt c ⟨.m s, j⟩ :=
    fun j => by dsimp only [mTab, shdP_outcM, mkMTable, shdOutcRndOf, shdLeafSalt]; exact extSalt_lt _ j.isLt
  unfold outcSegFixedProg outcSegFixedSched; dsimp only
  -- Step 1: labRunStage
  refine SliceSpec.seq (len₂ := 74521) (nQ₂ := 111385) (nTrK₂ := 796) (nT₂ := 796) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b1 74521 (by norm_num))
    (trees₂ := outcTreeSet)
    (trAbsorbSliceSpec hL20 hsep domain shape c t labRunStage (by decide) (by decide) (le64 (UInt64.ofNat V.stageIndex)) base st htip)
    (fun tf1 => ?_) (fun _ hf => False.elim hf)
    (by unfold outcSegFixedLen; omega) (by unfold outcSegFixedQ; omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by have : outcSegFixedLen = 74522 := rfl; omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 2: labRunBlock
  refine SliceSpec.seq (len₂ := 74520) (nQ₂ := 111384) (nTrK₂ := 795) (nT₂ := 795) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := trChainTip b2 74520 (by norm_num))
    (trees₂ := outcTreeSet)
    (trAbsorbSliceSpec hL20 hsep domain shape c tf1 labRunBlock (by decide) (by decide) wDigest.toList b1 st1 rfl)
    (fun tFrame => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
  -- Step 3: A_27 (depth 14)
  refine SliceSpec.seq (len₂ := 41753) (nQ₂ := 62233) (nTrK₂ := 795) (nT₂ := 795) (nL₂ := 20480) (nN₂ := 20478)
    (st₂ := trChainTip bA 41753 (by norm_num))
    (trees₂ := fun tid => tid = .m s ∨ tid = .h s)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.a s) 14 rfl 76 (by omega)
      (shdP_outcTA Rp w (shdOutcRndOf c)) (shdP_outcTA_cols_len Rp w (shdOutcRndOf c)) hAs
      b2 32767 49151 16384 16383 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      st2 stA ⟨rfl, rfl, rfl⟩
      (fun _ v => tFrame.state = v b1))
    (fun treeA => ?_) (fun _ ha h => by subst ha; rcases h with h | h <;> cases h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
  -- Step 4: labA
  refine SliceSpec.seq (len₂ := 41750) (nQ₂ := 62230) (nTrK₂ := 792) (nT₂ := 792) (nL₂ := 20480) (nN₂ := 20478)
    (st₂ := trChainTip bA3 41750 (by norm_num))
    (trees₂ := fun tid => tid = .m s ∨ tid = .h s)
    (absorbRootSliceSpec hL20 hsep domain shape c tFrame labA (by decide) (by decide) treeA.getRoot V.bp.aRows V.bp.logCols bA stA rfl)
    (fun tA => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 5: M_27 (depth 12)
  refine SliceSpec.seq (len₂ := 33559) (nQ₂ := 49943) (nTrK₂ := 792) (nT₂ := 792) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bM 33559 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.m s) 12 rfl (2 * 8 + 4) (by omega)
      (mTab 8 (cosetPt (rootFp 12)) (shdP_outcM (shdOutcRndOf c))) (fun j => mCol_length 8 _ _ j.val) hMs
      bA3 8191 12287 4096 4095 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stA3 stM ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => tA.state = v (bA3 - 1)))
    (fun treeM => ?_) (fun _ hm hh => by subst hm; cases hh)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => h) (fun _ _ hp => by rw [show bA3 - 1 = bA + 3 - 1 by omega]; exact hp.2) (fun _ _ _ _ hr => hr)
  -- Step 6: labM
  refine SliceSpec.seq (len₂ := 33558) (nQ₂ := 49942) (nTrK₂ := 791) (nT₂ := 791) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bM1 33558 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    (trAbsorbSliceSpec hL20 hsep domain shape c tA labM (by decide) (by decide) treeM.getRoot.toList bM stM rfl)
    (fun tM => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 7: 2 challenges
  refine SliceSpec.seq (len₂ := 33556) (nQ₂ := 49940) (nTrK₂ := 789) (nT₂ := 789) (nL₂ := 16384) (nN₂ := 16383)
    (st₂ := trChainTip bCh 33556 (by norm_num))
    (trees₂ := fun tid => tid = .h s)
    (trChallengeFp2VecSliceSpec_n (Lq := Lq) (by omega) hsep domain shape c 2 (by norm_num) tM bM1 stM1 rfl rfl)
    (fun chR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
  -- Step 8: H_27 (depth 14)
  refine SliceSpec.seq (len₂ := 789) (nQ₂ := 789) (nTrK₂ := 789) (nT₂ := 789) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH 789 (by norm_num))
    (trees₂ := fun _ => False)
    (merkleTableSliceSpec_keep (Lq := Lq) (by omega) hsep domain shape c (.h s) 14 rfl 38 (by omega)
      (shdP_outcTH Rp w (shdOutcRndOf c) (chR.1.getD 0 Fp2.zero) (chR.1.getD 1 Fp2.zero))
      (shdP_outcTH_cols_len Rp w (shdOutcRndOf c) _ _)
      (hHs _ _) bCh 32767 49151 16384 16383 (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      stCh stH ⟨rfl, sub1_eq_trChainTip _ (by omega), rfl⟩
      (fun _ v => chR.2.state = v (bCh - 1)))
    (fun treeH => ?_) (fun _ _ h => h)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with rfl | hf; exact rfl; cases hf) (fun _ _ hp => hp.2) (fun _ _ _ _ hr => hr)
  -- Step 9: labH
  refine SliceSpec.seq (len₂ := 786) (nQ₂ := 786) (nTrK₂ := 786) (nT₂ := 786) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bH3 786 (by norm_num))
    (trees₂ := fun _ => False)
    (absorbRootSliceSpec hL20 hsep domain shape c chR.2 labH (by decide) (by decide) treeH.getRoot V.bp.hRows V.bp.logCols bH stH rfl)
    (fun t3 => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 10: 8 slots (290)
  have hslLen : slotsFixedLen V.bp 0 8 = 290 := shdP_outc_slotsFixedLen tag Rp wDigest bOutRow v
  have hslSched : slotsFixedSched V.bp 0 8 bH3 (bH3 - 1) = slotsFixedSched P0out 0 8 bH3 (bH3 - 1) :=
    (slotsFixedSched_of_stgSame (shdP_hPout (Hdr := Unit) tag Rp wDigest bOutRow () v) 0 8 bH3 (bH3 - 1)).symm
  have hSl : SliceSpec Lq tag key domain shape c
      (slotsProveFixedProg Lq hL20 key V.bp (shdP_outcSlotData tag Rp wDigest bOutRow v w (shdP_outcTA Rp w (shdOutcRndOf c)) TB26 (shdOutcRndOf c))
        (OutcV.bga chR.1).1 (OutcV.bga chR.1).2.1 (OutcV.bga chR.1).2.2 8 (active && !outcAlphaBad chR.1) [] 0 {} t3)
      bH3 290 290 290 290 0 0 stH3 stSl (fun _ => False) (slotsFixedSched P0out 0 8 bH3 (bH3 - 1))
      (fun _ v => t3.state = v (bH3 - 1)) (fun _ v res => res.2.state = v (bH3 + 290 - 1)) := by
    rw [← hslSched]
    exact slotsProveFixedSliceSpec_n hL20 hsep domain shape c V.bp _ _ _ _ 8 _ [] 0 {} t3
      bH3 290 hslLen (by norm_num) stH3 rfl rfl (bH3 - 1) (sub1_eq_trChainTip (by norm_num) (by omega)).symm
  refine SliceSpec.seq (len₂ := 496) (nQ₂ := 496) (nTrK₂ := 496) (nT₂ := 496) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bSl 496 (by norm_num))
    (trees₂ := fun _ => False)
    hSl (fun slR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf)
    (fun _ _ hp => by rw [show bH3 - 1 = bH + 3 - 1 by omega]; exact hp.2) (fun _ _ _ _ hr => hr)
  -- Step 11: M_27 opening (85)
  refine SliceSpec.seq (len₂ := 411) (nQ₂ := 411) (nTrK₂ := 411) (nT₂ := 411) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bMo 411 (by norm_num))
    (trees₂ := fun _ => False)
    (zkBMaskFixedSliceSpec_n hL20 hsep domain shape c shdP_U shdP_hbij _ (shdP_outcM (shdOutcRndOf c)) 8 treeM _ slR.2 bSl 85
      (by unfold zkBMaskFixedLen; norm_num) (by norm_num) stSl rfl rfl)
    (fun mR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 12: A_27 opening (186)
  refine SliceSpec.seq (len₂ := 225) (nQ₂ := 225) (nTrK₂ := 225) (nT₂ := 225) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bAo 225 (by norm_num))
    (trees₂ := fun _ => False)
    (openingAuditFixedSliceSpec_n hL20 hsep domain shape c shdP_stgPrm 14 29 76 16 (shdP_outcOpenGeomA V)
      (shdP_outcTA Rp w (shdOutcRndOf c)) treeA _ _ _ mR.2 bMo 186
      (by unfold openingAuditFixedLen shdP_stgPrm; norm_num) (by norm_num) stMo rfl rfl)
    (fun aOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 13: H_27 opening (118)
  refine SliceSpec.seq (len₂ := 107) (nQ₂ := 107) (nTrK₂ := 107) (nT₂ := 107) (nL₂ := 0) (nN₂ := 0)
    (st₂ := trChainTip bHo 107 (by norm_num))
    (trees₂ := fun _ => False)
    (openingAuditFixedSliceSpec_n hL20 hsep domain shape c shdP_stgPrm 14 10 38 5 (shdP_outcOpenGeomH V)
      (shdP_outcTH Rp w (shdOutcRndOf c) (chR.1.getD 0 Fp2.zero) (chR.1.getD 1 Fp2.zero)) treeH _ _ _ aOR.2 bAo 118
      (by unfold openingAuditFixedLen shdP_stgPrm; norm_num) (by norm_num) stAo rfl rfl)
    (fun hOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, trChainTip_eq _ _ (by omega), rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  -- Step 14: B_26 opening (107) + ret
  refine SliceSpec.seq (len₂ := 0) (nQ₂ := 0) (nTrK₂ := 0) (nT₂ := 0) (nL₂ := 0) (nN₂ := 0)
    (st₂ := stBo) (trees₂ := fun _ => False)
    (openingAuditFixedSliceSpec_n hL20 hsep domain shape c Exec.R13.r13Prm 16 2 38 2 shdP_bndOpenGeom
      TB26 treeB26 _ _ _ hOR.2 bHo 107
      (by unfold openingAuditFixedLen Exec.R13.r13Prm; norm_num) (by norm_num) stHo rfl rfl)
    (fun bOR => ?_) (fun _ hf => False.elim hf)
    (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
    ⟨rfl, rfl, rfl⟩
    (fun _ h => by rcases h with hf | hf <;> exact hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  have hBoEq : bHo + 107 - 1 = base + outcSegFixedLen - 1 := by
    have : outcSegFixedLen = 74522 := rfl; omega
  cases slR.1 <;> cases aOR.1 <;> cases hOR.1 <;> cases bOR.1 <;> (try split_ifs) <;>
    exact retSliceSpec _ bBo stBo _ _ (fun _ _ hp => by rw [← hBoEq]; exact hp) (fun _ => .absorb 0)

end OutcSegFixed

end ZK60.HonestShield
