/-
D63 lane L69, Milestone A Part 2d (`HonestShieldZKFixedProg.lean`):
full 28-segment fixed-schedule Shieldstral T128 R13 honest-prover `PProg` (`shdP_runFixedProg`):
1. **Recursive 26-block chain (`blkChainFixedProg`, `blkChainFixedSched`, `blkChainTreeSet`)**:
   chains interior R13 blocks `startIdx .. startIdx + count - 1` (`count ≤ 26`) together with their
   deduplicated inter-segment `posTagKeyed` draws (`412,268` `.pt`s / `612,972` queries per block,
   never unrolling 26 copies in Lean's elaborator), proving exact `.run` equivalence with
   `proveSegs` and inductive `SliceSpec`.
2. **Whole-run `PProg` (`shdP_runFixedProg`, `shdP_runFixedSched`)**:
   composes `TE` (`4,095`), `shdP_hdrPProgF` (`7`), `s_IN` (`2`), `incSegFixedProg` (`205,401`),
   `e_IN` (`2`), `blkChainFixedProg 0 26` (`10,718,968`), `outcSegFixedProg` (`74,522`), and
   `e_OUT` (`2`) into the exact `11,002,999`-`.pt` / `16,362,617`-query schedule (`shdP_zkProg_counts`),
   proving:
   - `shdP_runFixedProg_run`: exact `.run G` agreement with `(classifyProtocolP ... shdP_honestRunP_zk ...).prove`,
   - `shdP_runFixedSliceSpec`: full `[0, shdP_zkPts)` `SliceSpec`,
   - `shdP_runScheduleMatch`: full `ShdScheduleMatch` (via `SliceSpec.finish`).
3. **Static 112-tree bases, opening-squeeze bases, and pure `v`-only `shdOpenedCols`**:
   explicit static index map for every one of the `112` Merkle trees (`shdTreeBase`, `shdTreeSqBase`,
   `shdOpenedCols`), proving that `shdRunFixedSched` locates every `.leaf ⟨tid, j⟩` at `shdTreeBase tid + j`
   and that every `openingAuditFixedProg` / `zkBMaskFixedProg` opens exact columns `shdOpenedCols v tid`.

Only standard Lean foundations (`propext`, `Classical.choice`, `Quot.sound`); zero `sorry`.
-/
import ZK60Formal.HonestShieldZKFixedSegs

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Finset ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Sound
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun ZK60.ZKHonest
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape (ClassifyRunPublicP classifyModelP classifySpecP)
open ZK60.RunShape.Shield (ShieldLayer shieldShape ShieldRun shieldS0)
open ZK60.Block (BlockPublic)
open ZK60.Exec.Block (BlockParams Cm Hist Acc SlotDef SlotProof SlotRec Segment SegGeom)
open ZK60.Circuit (gP GF)

/-! ## 1. `proveSegs` helpers & key-preservation utilities -/

section Helpers

theorem proveSegs_append {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps₁ ps₂ : List (SegP St X Coins)) (cr : Carry) (t : Tr),
      proveSegs H s x c bnd (ps₁ ++ ps₂) cr t =
        (proveSegs H s x c bnd ps₁ cr t >>= fun r1 =>
          proveSegs H s x c bnd ps₂ r1.2.1 r1.2.2 >>= fun r2 =>
            .ok (r1.1 ++ r2.1, r2.2.1, r2.2.2))
  | [], ps₂, cr, t => by
    simp only [List.nil_append, proveSegs, Bind.bind, Except.bind]
    cases proveSegs H s x c bnd ps₂ cr t <;> rfl
  | p :: ps₁, ps₂, cr, t => by
    simp only [List.cons_append, proveSegs, Bind.bind, Except.bind]
    cases p.run H s x c bnd (Exec.Block.posTag H t) cr t with
    | error e => rfl
    | ok r =>
      dsimp only
      rw [proveSegs_append H s x c bnd ps₁ ps₂ r.2.1 r.2.2]
      cases proveSegs H s x c bnd ps₁ r.2.1 r.2.2 with
      | error e => rfl
      | ok r1 =>
        simp only [Bind.bind, Except.bind]
        cases proveSegs H s x c bnd ps₂ r1.2.1 r1.2.2 <;> rfl

theorem proveSegs_three_stage {St X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig)
    (inC : SegP St X Coins) (blks : List (SegP St X Coins)) (outC : SegP St X Coins) (cr : Carry) (t : Tr) :
    proveSegs H s x c bnd (inC :: (blks ++ [outC])) cr t =
      (inC.run H s x c bnd (Exec.Block.posTag H t) cr t >>= fun rIn =>
        proveSegs H s x c bnd blks rIn.2.1 rIn.2.2 >>= fun rBlk =>
          outC.run H s x c bnd (Exec.Block.posTag H rBlk.2.2) rBlk.2.1 rBlk.2.2 >>= fun rOut =>
            .ok (rIn.1 (Exec.Block.posTag H rIn.2.2) :: (rBlk.1 ++ [rOut.1 (Exec.Block.posTag H rOut.2.2)]),
              rOut.2.1, rOut.2.2)) := by
  simp only [proveSegs, Bind.bind, Except.bind]
  cases inC.run H s x c bnd (Exec.Block.posTag H t) cr t with
  | error e => rfl
  | ok rIn =>
    dsimp only
    rw [proveSegs_append]
    cases proveSegs H s x c bnd blks rIn.2.1 rIn.2.2 with
    | error e => rfl
    | ok rBlk =>
      simp only [Bind.bind, Except.bind, proveSegs]
      cases outC.run H s x c bnd (Exec.Block.posTag H rBlk.2.2) rBlk.2.1 rBlk.2.2 with
      | error e => rfl
      | ok rOut => rfl

theorem trSqueezeVecKeyed_run_key (Lq : ℕ) (h47 : 47 ≤ Lq) (key : Option Dig) (G : QB Lq → Dig) :
    ∀ (n : ℕ) (t : Tr), 0 < n → ((trSqueezeVecKeyed Lq h47 key n t).run G).2.key = key
  | 0, _, h => by omega
  | 1, t, _ => by
    simp only [trSqueezeVecKeyed, trSqueezeKeyed, PProg.run_andThen, PProg.run]
  | n + 2, t, _ => by
    unfold trSqueezeVecKeyed
    rw [PProg.run_andThen, PProg.run_andThen]
    exact trSqueezeVecKeyed_run_key Lq h47 key G (n + 1) _ (Nat.succ_pos n)

theorem openingAuditFixedProg_run_key (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (prm : PcsPrm) (hnQ : 0 < prm.nQ) (depth nClaims rows nGroups : ℕ)
    (g : OpenGeom) (T : Table) (tree : MerkleLevels depth)
    (active hdrOk : Bool) (cl : List Exec.Block.ZClaim) (t : Tr) (G : QB Lq → Dig) :
    ((openingAuditFixedProg Lq hL20 key prm depth nClaims rows nGroups g T tree active hdrOk cl t).run G).2.key = key := by
  unfold openingAuditFixedProg
  repeat rw [PProg.run_andThen]
  exact trSqueezeVecKeyed_run_key Lq (by omega) key G ((prm.nQ + 3) / 4) _ (by omega)

private theorem run_andThen_key3 {Q R α β γ : Type} (p : PProg Q R α)
    (f : α → PProg Q R (β × γ × Tr)) (G : Q → R) (key : Option Dig)
    (h : ∀ a, ((f a).run G).2.2.key = key) : ((p.andThen f).run G).2.2.key = key := by
  rw [PProg.run_andThen]; exact h (p.run G)

private theorem run_andThen_key3_end {Q R α β γ : Type} (p : PProg Q R (α × Tr))
    (f : α × Tr → PProg Q R (β × γ × Tr)) (G : Q → R) (key : Option Dig)
    (hf : ∀ x, ((f x).run G).2.2 = x.2) (hp : (p.run G).2.key = key) :
    ((p.andThen f).run G).2.2.key = key := by
  rw [PProg.run_andThen, hf]; exact hp

private theorem run_andThen_key2 {Q R α β : Type} (p : PProg Q R α)
    (f : α → PProg Q R (β × Tr)) (G : Q → R) (key : Option Dig)
    (h : ∀ a, ((f a).run G).2.key = key) : ((p.andThen f).run G).2.key = key := by
  rw [PProg.run_andThen]; exact h (p.run G)

private theorem run_andThen_key2_end {Q R α β : Type} (p : PProg Q R (α × Tr))
    (f : α × Tr → PProg Q R (β × Tr)) (G : Q → R) (key : Option Dig)
    (hf : ∀ x, ((f x).run G).2 = x.2) (hp : (p.run G).2.key = key) :
    ((p.andThen f).run G).2.key = key := by
  rw [PProg.run_andThen, hf]; exact hp

private theorem run_andThen_posTag {Lq : ℕ} {h47 : 47 ≤ Lq} {key : Option Dig} {t : Tr}
    (htKey : t.key = key) {β : Type} (f : Dig → PProg (QB Lq) Dig β) (G : QB Lq → Dig) :
    ((posTagKeyed Lq h47 key t).andThen f).run G = (f (Exec.Block.posTag (liftH G) t)).run G := by
  rw [PProg.run_andThen, posTagKeyed_run Lq h47 key t htKey G]

private theorem run_andThen_hdr {Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq} {key : Option Dig}
    {hw : Hdr → ClsHdrW} {hdr : Hdr}
    {hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq}
    {inRoot : Dig} {verdict : ℕ} {β : Type} (f : Tr → PProg (QB Lq) Dig β) (G : QB Lq → Dig) :
    ((shdP_hdrPProgF Lq hL20 key (hw hdr) hfit inRoot verdict).andThen f).run G =
      (f (clsStart shdP_runDomain key hw (liftH G) (honestStmt hdr inRoot verdict))).run G := by
  rw [PProg.run_andThen, shdP_hdrPProgF_run Lq hL20 key hw hdr hfit inRoot verdict G]

theorem incSegFixedProg_run_key {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0)
    (embDigest : Dig) (bInRow : ℕ)
    (x : shieldS0.Tok → ℕ) (c : ShdCoins) (treeTE : MerkleLevels 11)
    (bnd startTag : Dig) (t : Tr) (G : QB Lq → Dig) :
    ((incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x c treeTE bnd startTag t).run G).2.2.key = key := by
  unfold incSegFixedProg
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro slR
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro aR
  apply run_andThen_key3; intro hR
  apply run_andThen_key3_end
  · rintro ⟨oE, tE⟩; dsimp only
    cases slR.1 with
    | none => rfl
    | some v1 =>
      rcases v1 with ⟨_, _, _⟩
      cases aR.1 with
      | none => rfl
      | some _ =>
        cases hR.1 with
        | none => rfl
        | some _ =>
          cases oE with
          | none => rfl
          | some _ => split_ifs <;> rfl
  · exact openingAuditFixedProg_run_key Lq hL20 key shdP_epPrm (by show 0 < 256; omega) 11 1 6 1
      shdP_epOpenGeom _ treeTE _ _ _ _ G

theorem blkSegFixedProg_run_key {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (k : Fin 26) (active : Bool) (cr : Carry) (treeBPrev : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (G : QB Lq → Dig) :
    ((blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c k active cr treeBPrev bnd startTag t).run G).2.2.key = key := by
  unfold blkSegFixedProg
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro slR
  apply run_andThen_key3; intro _
  apply run_andThen_key3; intro aR
  apply run_andThen_key3; intro hR
  apply run_andThen_key3_end
  · rintro ⟨oB, tB⟩; dsimp only
    cases slR.1 with
    | none => rfl
    | some v1 =>
      rcases v1 with ⟨_, _, _⟩
      cases aR.1 with
      | none => rfl
      | some _ =>
        cases hR.1 with
        | none => rfl
        | some _ =>
          cases oB with
          | none => rfl
          | some _ => split_ifs <;> rfl
  · exact openingAuditFixedProg_run_key Lq hL20 key Exec.R13.r13Prm (by show 0 < 256; omega) 16 2 38 2
      shdP_bndOpenGeom _ treeBPrev _ _ _ _ G

theorem outcSegFixedProg_run_key (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins)
    (active : Bool) (cr : Carry) (treeB26 : MerkleLevels 16)
    (bnd startTag : Dig) (t : Tr) (G : QB Lq → Dig) :
    ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c active cr treeB26 bnd startTag t).run G).2.key = key := by
  unfold outcSegFixedProg
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro slR
  apply run_andThen_key2; intro _
  apply run_andThen_key2; intro aR
  apply run_andThen_key2; intro hR
  apply run_andThen_key2_end
  · rintro ⟨oB, tB⟩; dsimp only
    cases slR.1 with
    | none => rfl
    | some v1 =>
      rcases v1 with ⟨_, _, _⟩
      cases aR.1 with
      | none => rfl
      | some _ =>
        cases hR.1 with
        | none => rfl
        | some _ =>
          cases oB with
          | none => rfl
          | some _ => split_ifs <;> rfl
  · exact openingAuditFixedProg_run_key Lq hL20 key Exec.R13.r13Prm (by show 0 < 256; omega) 16 2 38 2
      shdP_bndOpenGeom _ treeB26 _ _ _ _ G

theorem shdP_hdrPProgF_run_key (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (key : Option Dig)
    (w : ClsHdrW) (hfit : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq)
    (inRoot : Dig) (verdict : ℕ) (G : QB Lq → Dig) :
    ((shdP_hdrPProgF Lq hL20 key w hfit inRoot verdict).run G).key = key := by
  unfold shdP_hdrPProgF
  dsimp only [PProg.run]
  repeat rw [PProg.run_andThen]
  rfl

/-- Pure `v`-driven `posTag` value produced by `posTagKeyed` at `base`. -/
def posTagOfV (v : ℕ → Dig) (base : ℕ) : Dig :=
  ⟨(challengeFp2Of (v base)).toBytes ++ (challengeFp2Of (v (base + 1))).toBytes,
    by simp [Exec.Block.fp2_toBytes_length]⟩

private theorem shdP_blkSegP_zkGuarded_ok_core {St X Coins : Type} (tag : MTag) (Pk : ℕ → BlockParams)
    (sgeom : St → ℕ → SegGeom) (check : St → ℕ → Except String Unit)
    (paths : St → Segment → Except String Unit) (digest : St → ℕ → Dig)
    (bRows bLogN : ℕ → ℕ)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Exec.Block.ZClaim → Exec.Block.OpeningZk → Tr → Except String Tr)
    (Ly : ShieldLayer) (Pb : BlockPublic (shieldShape Ly))
    (W : (HIn → Dig) → St → X → Coins → (k : ℕ) → ShdBlkTables Pk k)
    (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd start : Dig) (cr : Carry) (t : Tr)
    (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr)
    (wt : ShdBlkTables Pk k) (hW : W H s x c k = wt)
    (TBnext : Table) (CT : CoreTables (Pk k))
    (hBn : wt.TB_next = TBnext) (hCT : wt.coreT = CT)
    (hrun : (shdP_blkSegP_zkGuarded tag Pk sgeom check paths digest bRows bLogN bndOpen Ly Pb W k).run
      H s x c bnd start cr t = .ok (enc, cr', t')) :
    let prof := d12aBlockProf Pk sgeom check paths digest bRows bLogN
      (fun _ _ cl t0 => checkOpeningExec H shdP_bndOpenGeom 14 cl t0) bndOpen
    let tFrame := blockFrame prof H s k (rootOf H tag 16 TBnext) t
    let D := coreDataAt H tag shdP_U shdP_hbij Exec.R13.r13Prm 16 23 (Pk k) CT tFrame
    ∃ R : CoreRun, coreProve H (Pk k) D tFrame = .ok R
      ∧ cr' = ⟨R.acc.claims.out, rootOf H tag 16 TBnext⟩ := by
  subst hBn; subst hCT
  dsimp only [shdP_blkSegP_zkGuarded, shdP_blkSegP_guarded, shdP_blkSegP] at hrun
  rw [hW] at hrun
  split_ifs at hrun
  cases hcp : coreProve H (Pk k) _ _ with
  | error _ => rw [hcp] at hrun; cases hrun
  | ok R =>
    rw [hcp] at hrun; dsimp only at hrun
    cases hbc : checkOpeningExec H shdP_bndOpenGeom 14 (cr.pending ++ R.acc.claims.inp) R.t7 with
    | error _ => rw [hbc] at hrun; cases hrun
    | ok u =>
      cases u; rw [hbc] at hrun
      simp only [Except.ok.injEq, Prod.mk.injEq] at hrun
      exact ⟨R, hcp, hrun.2.1.symm⟩

/-- Helper extracting `blk_outClaims` ownership from a successful `shdP_blkSegP_run_zk` step. -/
theorem shdP_blkSegP_run_zk_out_own {Hdr : Type} (tag : MTag) (ioIn ioOut : ℕ)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig)
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (k : Fin 26) (bnd startTag : Dig) (cr : Carry) (t : Tr)
    (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr)
    (hrun : (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf k.val).run
        H st x c bnd startTag cr t = .ok (enc, cr', t')) :
    let TBnext := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩
    cr'.root = rootOf H tag 16 TBnext
      ∧ ∀ cl ∈ cr'.pending, ClaimTrue shdP_U (2 ^ 14) 14 TBnext.rows (toZClaim cl) := by
  intro TBnext
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
  let w := shdP_blkWitnessAt Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) x hx k.val k.isLt
  let TBprev := shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val, Nat.lt_succ_of_lt k.isLt⟩
  let CT := blkCoreTables (Pk k.val) w TBprev TBnext (shdBlkRndOf c k)
  have hTabEq : shdP_blkTables_total tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) shdIncRndOf shdBlkRndOf H st x c k.val
      = shdP_blkTables Pk k.val w TBprev TBnext (shdBlkRndOf c k) := by
    unfold shdP_blkTables_total; exact dite_eq_left (And.intro hx k.isLt)
  have hRunEq : shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf k.val
      = shdP_blkSegP_zkGuarded tag Pk (shdP_sgeom Hdr Pk) (vdChk check0) shdP_segPaths digest
          (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
          (shdP_blkTables_total tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
            (fun b hb => (hweights b hb).act0) shdIncRndOf shdBlkRndOf) k.val := by
    unfold shdP_blkSegP_run_zk; exact dite_eq_left k.isLt
  rw [hRunEq] at hrun
  obtain ⟨R, hcp, hcr⟩ := shdP_blkSegP_zkGuarded_ok_core tag Pk (shdP_sgeom Hdr Pk) (vdChk check0) shdP_segPaths
    digest (fun _ => 38) (fun _ => 14) (cbBndOpen tag 38) (shdP_layer k.val k.isLt) (shdP_blkPub Rp hR k.val k.isLt)
    _ k.val H st x c bnd startTag cr t enc cr' t'
    (shdP_blkTables Pk k.val w TBprev TBnext (shdBlkRndOf c k)) hTabEq TBnext CT rfl rfl hrun
  rw [hcr]
  refine ⟨rfl, ?_⟩
  exact shdP_blk_outClaims_true_uncond H tag (Pk k.val) w TBprev TBnext
    (shdP_bndTableAt_spec Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩).rows_len
    (shdBlkRndOf c k) _ R hcp

private theorem inSegP_shdP_incP_eq_local {Hdr Coins : Type} (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (embDigest : Dig) (bInRow : ℕ)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables (shdVi tag Rp embDigest bInRow)) :
    inSegP (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => shdGi tag Rp embDigest bInRow))
        (shdP_incP tag Rp embDigest bInRow C)
      = inSegP (incStageV (fun _ : Hdr => shdVi tag Rp embDigest bInRow) (fun _ => rcIncGeom (shdVi tag Rp embDigest bInRow) 28))
          (incP_abs tag (shdVi tag Rp embDigest bInRow) C) := rfl

private theorem inSegP_incP_abs_ok_core {Hdr Coins : Type} (tag : MTag) (V : IncV)
    (C : (HIn → Dig) → ClsStmt Hdr → (shieldS0.Tok → ℕ) → Coins → IncTables V)
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (c : Coins)
    (bnd startTag : Dig) (cr0 : Carry) (t : Tr)
    (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr)
    (hrun : (inSegP _ (incP_abs tag V C)).run H st x c bnd startTag cr0 t = .ok (enc, cr', t')) :
    ∃ R : IncRun,
      incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H st x c) t) t = .ok R
      ∧ cr' = ⟨R.acc.claims.out, (C H st x c).bRoot⟩ := by
  dsimp only [inSegP, incP_abs, Bind.bind, Except.bind] at hrun
  cases hinc : incProve H V (incDataAt H tag shdP_U shdP_hbij V 2 3 256 256 (C H st x c) t) t with
  | error _ => rw [hinc] at hrun; cases hrun
  | ok R =>
    rw [hinc] at hrun
    simp only [Except.ok.injEq, Prod.mk.injEq] at hrun
    exact ⟨R, rfl, hrun.2.1.symm⟩

/-- Helper extracting `inc_outClaims` ownership from a successful `inSegP (shdP_incP ...)` step. -/
theorem shdP_incSegP_out_own {Hdr : Type} (tag : MTag)
    (Rp : ClassifyRunPublicP shieldS0) (hinPub : Rp.inp.Valid) (hV131072 : Rp.inp.V = 131072)
    (embDigest : Dig) (bInRow : ℕ)
    (H : HIn → Dig) (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (c : ShdCoins) (bnd startTag : Dig) (t : Tr)
    (enc : Dig → List UInt8) (cr' : Carry) (t' : Tr)
    (hrun : (inSegP _ (shdP_incP tag Rp embDigest bInRow
      (fun H' _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H' x' (shdEpBase c') (shdIncRndOf c')))).run
        H st x c bnd startTag carry0 t = .ok (enc, cr', t')) :
    let TB0 := shdP_incTB Rp x (shdIncRndOf c)
    cr'.root = rootOf H tag 16 TB0
      ∧ ∀ cl ∈ cr'.pending, ClaimTrue shdP_U (2 ^ 14) 14 TB0.rows (toZClaim cl) := by
  intro TB0
  rw [inSegP_shdP_incP_eq_local (Hdr := Hdr) tag Rp embDigest bInRow
    (fun H' _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H' x' (shdEpBase c') (shdIncRndOf c'))] at hrun
  obtain ⟨R, hinc, hcr⟩ := inSegP_incP_abs_ok_core tag (shdVi tag Rp embDigest bInRow)
    (fun H' _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H' x' (shdEpBase c') (shdIncRndOf c'))
    H st x c bnd startTag carry0 t enc cr' t' hrun
  rw [hcr]
  refine ⟨by dsimp only [shdP_incTables], ?_⟩
  exact (shdP_inc_arith (Hdr := Hdr) H tag Rp hinPub hV131072 embDigest bInRow x hx
    (shdEpBase c) (shdIncRndOf c) t R hinc).2

end Helpers

/-! ## 2. Recursive 26-Block Chain (`blkChainFixedProg` + `.run` + `SliceSpec`) -/

section BlkChain

/-- Static `.pt` length (`412,268`) and total `QLE` (`612,972`) of one block + its trailing `posTag`. -/
def blkStepFixedLen : ℕ := blkSegFixedLen + 2
def blkStepFixedQ : ℕ := blkSegFixedQ + 2

/-- **Recursive fixed-schedule chain of `count` interior R13 blocks starting at `startIdx`**
(`startIdx + count ≤ 26`), each followed by its deduplicated `posTagKeyed` (`e_Bk = s_{B_{k+1}}`).
Returns `(Option (List (List UInt8) × Carry), treeB_{startIdx + count}, t_after, endTag)`. -/
noncomputable def blkChainFixedProg {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) :
    (startIdx count : ℕ) → startIdx + count ≤ 26 →
    Bool → Carry → MerkleLevels 16 → Dig → Dig → Tr →
    PProg (QB Lq) Dig (Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig)
  | _, 0, _, active, cr, treeB, _, startTag, t =>
    .ret (if active then some ([], cr) else none, treeB, t, startTag)
  | startIdx, count + 1, hEnd, active, cr, treeB, bnd, startTag, t =>
    (blkSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c ⟨startIdx, by omega⟩ active cr treeB bnd startTag t).andThen fun bR =>
      (posTagKeyed Lq (by omega) key bR.2.2).andThen fun endTag =>
        let active' := bR.1.isSome
        let cr' := match bR.1 with | some (_, c') => c' | none => carry0
        (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x hx c (startIdx + 1) count (by omega) active' cr' bR.2.1 bnd endTag bR.2.2).andThen fun rest =>
          match bR.1, rest.1 with
          | some (enc, _), some (bs, crOut) =>
            .ret (some (enc endTag :: bs, crOut), rest.2.1, rest.2.2.1, rest.2.2.2)
          | _, _ => .ret (none, rest.2.1, rest.2.2.1, rest.2.2.2)

/-- Static point schedule of `blkChainFixedProg` for `count` blocks starting at `startIdx`. -/
def blkChainFixedSched (Pk : ℕ → BlockParams) :
    (startIdx count : ℕ) → startIdx + count ≤ 26 → ℕ → ℕ → (ℕ → RawPtSpec)
  | _, 0, _, _, _ => fun _ => .absorb 0
  | startIdx, count + 1, hEnd, base, tip =>
    let bSeg := base + blkSegFixedLen
    let bStep := base + blkStepFixedLen
    spliceSched bSeg (blkSegFixedSched (Pk startIdx) ⟨startIdx, by omega⟩ base tip)
      (spliceSched bStep (fun j => if j = bSeg then .squeeze (bSeg - 1) else .squeeze bSeg)
        (spliceSched (bStep + blkStepFixedLen * count)
          (blkChainFixedSched Pk (startIdx + 1) count (by omega) bStep (bSeg - 1))
          (fun _ => .absorb 0)))

/-- Trees touched by blocks `startIdx .. startIdx + count - 1`. -/
def blkChainTreeSet (startIdx count : ℕ) (tid : ShdTreeId) : Prop :=
  ∃ k : Fin 26, startIdx ≤ k.val ∧ k.val < startIdx + count ∧ blkTreeSet k tid

private theorem run_andThen_fst_none3 {Q R α β γ δ ε : Type}
    (p : PProg Q R α) (f : α → PProg Q R (Option β × γ × δ × ε)) (G : Q → R)
    (hf : ∀ a, ((f a).run G).1 = none) : ((p.andThen f).run G).1 = none := by
  rw [PProg.run_andThen]; exact hf (p.run G)

private theorem run_andThen_fst_none_of {Q R α β γ δ ε : Type}
    (p : PProg Q R (Option α × β × γ))
    (f : Option α × β × γ → PProg Q R (Option δ × β × γ × ε)) (G : Q → R)
    (hp : (p.run G).1 = none)
    (hf : ∀ bR, bR.1 = none → ((f bR).run G).1 = none) :
    ((p.andThen f).run G).1 = none := by
  rw [PProg.run_andThen]; exact hf (p.run G) hp

private theorem run_andThen_fst_none_of_congr {Q R α β γ δ ε : Type}
    {p₁ p₂ : PProg Q R (Option α × β × γ)} (hpEq : p₁ = p₂)
    (f : Option α × β × γ → PProg Q R (Option δ × β × γ × ε)) (G : Q → R)
    (hp : (p₁.run G).1 = none)
    (hf : ∀ bR, bR.1 = none → ((f bR).run G).1 = none) :
    ((p₂.andThen f).run G).1 = none := by
  rw [← hpEq, PProg.run_andThen]; exact hf (p₁.run G) hp

private theorem run_andThen_eq_const {Q R α β : Type}
    (p : PProg Q R α) (f : α → PProg Q R β) (G : Q → R) (y : β)
    (hf : ∀ a, (f a).run G = y) : (p.andThen f).run G = y := by
  rw [PProg.run_andThen]; exact hf (p.run G)

private theorem run_andThen_eq_prop {Q R α β : Type}
    (p : PProg Q R α) (f : α → PProg Q R β) (G : Q → R) {A : α → Prop} {rhs : β}
    (hp : A (p.run G))
    (hf : ∀ a, A a → (f a).run G = rhs) : (p.andThen f).run G = rhs := by
  rw [PProg.run_andThen]; exact hf (p.run G) hp

private theorem run_andThen_eq_prop_congr {Q R α β : Type}
    {p₁ p₂ : PProg Q R α} (hpEq : p₁ = p₂) (f : α → PProg Q R β) (G : Q → R)
    {A : α → Prop} {rhs : β}
    (hp : A (p₁.run G))
    (hf : ∀ a, A a → (f a).run G = rhs) : (p₂.andThen f).run G = rhs := by
  rw [← hpEq, PProg.run_andThen]; exact hf (p₁.run G) hp

private theorem run_andThen_goal {Q R α β : Type}
    (p : PProg Q R α) (f : α → PProg Q R β) (G : Q → R) {A : α → Prop} (B : β → Prop)
    (hp : A (p.run G))
    (hf : ∀ a, A a → B ((f a).run G)) : B ((p.andThen f).run G) := by
  rw [PProg.run_andThen]; exact hf (p.run G) hp

private theorem run_andThen_goal_congr {Q R α β : Type}
    {p₁ p₂ : PProg Q R α} (hpEq : p₁ = p₂) (f : α → PProg Q R β) (G : Q → R)
    {A : α → Prop} (B : β → Prop)
    (hp : A (p₁.run G))
    (hf : ∀ a, A a → B ((f a).run G)) : B ((p₂.andThen f).run G) := by
  rw [← hpEq, PProg.run_andThen]; exact hf (p₁.run G) hp

theorem blkChainFixedProg_run_inactive {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (G : QB Lq → Dig) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (cr : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr),
      ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c startIdx count hEnd false cr treeB bnd startTag t).run G).1 = none
  | _, 0, _, _, _, _, _, _ => rfl
  | startIdx, count + 1, hEnd, cr, treeB, bnd, startTag, t => by
    unfold blkChainFixedProg
    refine run_andThen_fst_none_of _ _ G
      (blkSegFixedProg_run_inactive (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub
        ioIn ioOut blkDig x hx c ⟨startIdx, by omega⟩ cr treeB bnd startTag t G)
      fun bR hb => run_andThen_fst_none3 _ _ G fun _ => run_andThen_fst_none3 _ _ G fun rest => ?_
    rw [hb]; cases rest.1 <;> rfl

/-- **Exact `.run` equivalence for `blkChainFixedProg`**:
inductively matches `proveSegs` on `((List.range' startIdx count).map (shdP_blkSegP_run_zk ...))`
AND propagates `treeB_{startIdx + count}` ownership and `endTag = posTag H t_after`! -/
theorem blkChainFixedProg_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (blkDig : Fin 26 → Dig)
    (st : ClsStmt Hdr) (hdig : ∀ k : Fin 26, digest st k.val = blkDig k)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (bnd : Dig) (G : QB Lq → Dig) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (cr : Carry) (treeB : MerkleLevels 16) (t : Tr),
      t.key = key →
      (∀ (j : ℕ) (hj : j < 2 ^ 16),
        treeB.path j hj = pathOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩) j) →
      (cr.root = rootOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩)
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩).rows (toZClaim cl)) →
      let res := (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
        x hx c startIdx count hEnd true cr treeB bnd (Exec.Block.posTag (liftH G) t) t).run G
      match proveSegs (liftH G) st x c bnd
          ((List.range' startIdx count).map (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom)
            Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr t with
      | .ok (bs, crOut, tOut) =>
        res.1 = some (bs, crOut)
          ∧ res.2.2.1 = tOut
          ∧ res.2.2.2 = Exec.Block.posTag (liftH G) tOut
          ∧ tOut.key = key
          ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16),
              res.2.1.path j hj = pathOf (liftH G) tag 16
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + count, by omega⟩) j)
          ∧ (crOut.root = rootOf (liftH G) tag 16
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + count, by omega⟩)
              ∧ ∀ cl ∈ crOut.pending, ClaimTrue shdP_U (2 ^ 14) 14
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + count, by omega⟩).rows (toZClaim cl))
      | .error () => res.1 = none
  | startIdx, 0, hEnd, cr, treeB, t, htKey, htree, hOwn => by
    dsimp only [blkChainFixedProg, List.range'_zero, List.map_nil, proveSegs, PProg.run]
    simp only [↓reduceIte]
    exact ⟨rfl, rfl, rfl, htKey, htree, hOwn⟩
  | startIdx, count + 1, hEnd, cr, treeB, t, htKey, htree, hOwn => by
    dsimp only
    let k : Fin 26 := ⟨startIdx, by omega⟩
    simp only [List.range'_succ, List.map_cons, proveSegs, Bind.bind, Except.bind]
    have hbRun := blkSegFixedProg_run (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut
      check0 digest blkDig k st (hdig k) x hx c cr treeB bnd (Exec.Block.posTag (liftH G) t) t htKey G htree hOwn
    have hbKey := blkSegFixedProg_run_key (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut
      blkDig x hx c k true cr treeB bnd (Exec.Block.posTag (liftH G) t) t G
    rcases hbRun with ⟨hbTree, hbMatch⟩
    cases h1 : (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf startIdx).run
          (liftH G) st x c bnd (Exec.Block.posTag (liftH G) t) cr t with
    | error u =>
      cases u
      rw [h1] at hbMatch; dsimp only at hbMatch ⊢
      unfold blkChainFixedProg
      refine run_andThen_fst_none_of_congr (by congr) _ G hbMatch fun bR hb =>
        run_andThen_fst_none3 _ _ G fun _ => run_andThen_fst_none3 _ _ G fun rest => ?_
      rw [hb]; cases rest.1 <;> rfl
    | ok v1 =>
      rcases v1 with ⟨enc, cr1, t1⟩
      rw [h1] at hbMatch; dsimp only at hbMatch ⊢
      have hOwn1 := shdP_blkSegP_run_zk_out_own tag ioIn ioOut Rp hR hweights hinPub check0 digest
        (liftH G) st x hx c k bnd (Exec.Block.posTag (liftH G) t) cr t enc cr1 t1 h1
      cases hrest : proveSegs (liftH G) st x c bnd
          ((List.range' (startIdx + 1) count).map (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom)
            Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr1 t1 with
      | error u =>
        cases u; dsimp only
        unfold blkChainFixedProg
        refine run_andThen_goal_congr
          (A := fun bR : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr =>
            (bR.2.1.getRoot = rootOf (liftH G) tag 16
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
              ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), bR.2.1.path j hj = pathOf (liftH G) tag 16
                  (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩) j)
            ∧ (bR.1 = some (enc, cr1) ∧ bR.2.2 = t1)
            ∧ bR.2.2.key = key)
          (by congr) _ G
          (fun res : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig => res.1 = none)
          ⟨hbTree, hbMatch, hbKey⟩ fun bR ⟨hbTree', hbMatch', hbKey'⟩ => ?_
        rw [run_andThen_posTag hbKey', hbMatch'.1, hbMatch'.2]
        dsimp only [Option.isSome_some]
        have ht1Key : t1.key = key := hbMatch'.2 ▸ hbKey'
        have ih := blkChainFixedProg_run Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut check0 digest blkDig
          st hdig x hx c bnd G (startIdx + 1) count (by omega) cr1 bR.2.1 t1 ht1Key hbTree'.2 hOwn1
        rw [hrest] at ih; dsimp only at ih
        refine run_andThen_goal_congr
          (A := fun restR : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig => restR.1 = none)
          (by congr) _ G
          (fun res : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig => res.1 = none)
          ih fun restR hnone => ?_
        rw [hnone]; rfl
      | ok v2 =>
        rcases v2 with ⟨bs, crOut, tOut⟩
        dsimp only
        unfold blkChainFixedProg
        refine run_andThen_goal_congr
          (A := fun bR : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr =>
            (bR.2.1.getRoot = rootOf (liftH G) tag 16
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩)
              ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), bR.2.1.path j hj = pathOf (liftH G) tag 16
                  (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨k.val + 1, Nat.succ_lt_succ k.isLt⟩) j)
            ∧ (bR.1 = some (enc, cr1) ∧ bR.2.2 = t1)
            ∧ bR.2.2.key = key)
          (by congr) _ G
          (fun res : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig =>
            res.1 = some (enc (Exec.Block.posTag (liftH G) t1) :: bs, crOut)
              ∧ res.2.2.1 = tOut
              ∧ res.2.2.2 = Exec.Block.posTag (liftH G) tOut
              ∧ tOut.key = key
              ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16),
                  res.2.1.path j hj = pathOf (liftH G) tag 16
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩) j)
              ∧ (crOut.root = rootOf (liftH G) tag 16
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩)
                  ∧ ∀ cl ∈ crOut.pending, ClaimTrue shdP_U (2 ^ 14) 14
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩).rows (toZClaim cl)))
          ⟨hbTree, hbMatch, hbKey⟩ fun bR ⟨hbTree', hbMatch', hbKey'⟩ => ?_
        rw [run_andThen_posTag hbKey', hbMatch'.1, hbMatch'.2]
        dsimp only [Option.isSome_some]
        have ht1Key : t1.key = key := hbMatch'.2 ▸ hbKey'
        have ih := blkChainFixedProg_run Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut check0 digest blkDig
          st hdig x hx c bnd G (startIdx + 1) count (by omega) cr1 bR.2.1 t1 ht1Key hbTree'.2 hOwn1
        rw [hrest] at ih; dsimp only at ih
        refine run_andThen_goal_congr
          (A := fun restR : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig =>
            restR.1 = some (bs, crOut) ∧ restR.2.2.1 = tOut ∧ restR.2.2.2 = Exec.Block.posTag (liftH G) tOut
              ∧ tOut.key = key
              ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16), restR.2.1.path j hj = pathOf (liftH G) tag 16
                  (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + 1 + count, by omega⟩) j)
              ∧ (crOut.root = rootOf (liftH G) tag 16
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + 1 + count, by omega⟩)
                  ∧ ∀ cl ∈ crOut.pending, ClaimTrue shdP_U (2 ^ 14) 14
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + 1 + count, by omega⟩).rows (toZClaim cl)))
          (by congr) _ G
          (fun res : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig =>
            res.1 = some (enc (Exec.Block.posTag (liftH G) t1) :: bs, crOut)
              ∧ res.2.2.1 = tOut
              ∧ res.2.2.2 = Exec.Block.posTag (liftH G) tOut
              ∧ tOut.key = key
              ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16),
                  res.2.1.path j hj = pathOf (liftH G) tag 16
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩) j)
              ∧ (crOut.root = rootOf (liftH G) tag 16
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩)
                  ∧ ∀ cl ∈ crOut.pending, ClaimTrue shdP_U (2 ^ 14) 14
                    (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx + (count + 1), by omega⟩).rows (toZClaim cl)))
          ih fun restR ⟨h2o, h2t, h2e, h2k, h2tr, h2own⟩ => ?_
        rw [h2o]; dsimp only
        have hidx : (⟨startIdx + 1 + count, by omega⟩ : Fin 27) = ⟨startIdx + (count + 1), by omega⟩ :=
          Fin.ext (by dsimp; omega)
        exact ⟨rfl, h2t, h2e, h2k,
          fun j hj => (h2tr j hj).trans (congrArg (fun idx => pathOf (liftH G) tag 16
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx) j) hidx),
          h2own.1.trans (congrArg (fun idx => rootOf (liftH G) tag 16
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx)) hidx),
          fun cl hcl => (congrArg (fun idx => ClaimTrue shdP_U (2 ^ 14) 14
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).rows (toZClaim cl)) hidx).mp
            (h2own.2 cl hcl)⟩

theorem blkChainFixedProg_run_err {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (blkDig : Fin 26 → Dig)
    (st : ClsStmt Hdr) (hdig : ∀ k : Fin 26, digest st k.val = blkDig k)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (bnd : Dig) (G : QB Lq → Dig)
    (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
    (cr : Carry) (treeB : MerkleLevels 16) (t : Tr) (htKey : t.key = key)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeB.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩)
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩).rows (toZClaim cl))
    (herr : proveSegs (liftH G) st x c bnd
        ((List.range' startIdx count).map (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom)
          Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr t = .error ()) :
    ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c startIdx count hEnd true cr treeB bnd (Exec.Block.posTag (liftH G) t) t).run G).1 = none := by
  have h := blkChainFixedProg_run (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut check0 digest blkDig
    st hdig x hx c bnd G startIdx count hEnd cr treeB t htKey htree hOwn
  rw [herr] at h
  exact h

theorem blkChainFixedProg_run_ok {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (check0 : ClsStmt Hdr → ℕ → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (blkDig : Fin 26 → Dig)
    (st : ClsStmt Hdr) (hdig : ∀ k : Fin 26, digest st k.val = blkDig k)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) (bnd : Dig) (G : QB Lq → Dig)
    (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
    (cr : Carry) (treeB : MerkleLevels 16) (t : Tr) (htKey : t.key = key)
    (htree : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeB.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩)
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx ⟨startIdx, by omega⟩).rows (toZClaim cl))
    (bs : List (List UInt8)) (crOut : Carry) (tOut : Tr)
    (idxEnd : Fin 27) (hidxEnd : idxEnd.val = startIdx + count)
    (hok : proveSegs (liftH G) st x c bnd
        ((List.range' startIdx count).map (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom)
          Rp hR hweights hinPub (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr t = .ok (bs, crOut, tOut)) :
    let res := (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c startIdx count hEnd true cr treeB bnd (Exec.Block.posTag (liftH G) t) t).run G
    res.1 = some (bs, crOut)
      ∧ res.2.2.1 = tOut
      ∧ res.2.2.2 = Exec.Block.posTag (liftH G) tOut
      ∧ tOut.key = key
      ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16),
          res.2.1.path j hj = pathOf (liftH G) tag 16
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idxEnd) j)
      ∧ (crOut.root = rootOf (liftH G) tag 16
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idxEnd)
          ∧ ∀ cl ∈ crOut.pending, ClaimTrue shdP_U (2 ^ 14) 14
            (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idxEnd).rows (toZClaim cl)) := by
  have h := blkChainFixedProg_run (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut check0 digest blkDig
    st hdig x hx c bnd G startIdx count hEnd cr treeB t htKey htree hOwn
  rw [hok] at h
  have hEq : ∀ (hLt : startIdx + count < 27), idxEnd = ⟨startIdx + count, hLt⟩ := fun _ => Fin.ext hidxEnd
  rcases h with ⟨h1, h2, h3, h4, h5, h6⟩
  exact ⟨h1, h2, h3, h4,
    fun j hj => by rw [hEq]; exact h5 j hj,
    by rw [hEq]; exact h6⟩

/-- **Inductive `SliceSpec` for `blkChainFixedProg`**:
handles any `count` blocks starting at `startIdx` (`startIdx + count ≤ 26`) in O(1) proof size! -/
theorem blkChainFixedSliceSpec {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key) (domain shape : List UInt8)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid)
    (ioIn ioOut : ℕ) (blkDig : Fin 26 → Dig)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) (c : ShdCoins) :
    ∀ (startIdx count : ℕ) (hEnd : startIdx + count ≤ 26)
      (active : Bool) (cr : Carry) (treeB : MerkleLevels 16) (bnd startTag : Dig) (t : Tr)
      (base : ℕ) (st : TrChainState base) (htip : st.hasTip = true),
      let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
      let stOut : TrChainState (base + blkStepFixedLen * count) :=
        if hc : count = 0 then
          ⟨st.hasTip, st.trTip, fun h => by have := st.htip_lt h; omega, st.afterPosTag, st.hpos⟩
        else
          ⟨true, base + blkStepFixedLen * count - 3, fun _ => by unfold blkStepFixedLen blkSegFixedLen; omega,
            true, fun _ => rfl⟩
      SliceSpec Lq tag key domain shape c
        (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
          x hx c startIdx count hEnd active cr treeB bnd startTag t)
        base (blkStepFixedLen * count) (blkStepFixedQ * count)
        (10864 * count) (10864 * count) (200704 * count) (200700 * count)
        st stOut (blkChainTreeSet startIdx count)
        (blkChainFixedSched Pk startIdx count hEnd base st.trTip)
        (fun _ v => t.state = v st.trTip ∧ (count = 0 → treeB = levelsOfV v 16 (base - 2 - blkSegFixedLen)))
        (fun _ v res =>
          res.2.2.1.state = v stOut.trTip
            ∧ (0 < count → res.2.1 = levelsOfV v 16 (base + blkStepFixedLen * (count - 1)))
            ∧ (count = 0 → res.2.1 = treeB))
  | startIdx, 0, hEnd, active, cr, treeB, bnd, startTag, t, base, st, htip => by
    dsimp only
    unfold blkChainFixedProg blkChainFixedSched
    rw [dite_eq_left rfl]
    exact (retSliceSpec (if active then some ([], cr) else none, treeB, t, startTag) base st
      (fun _ v => t.state = v st.trTip ∧ (0 = 0 → treeB = levelsOfV v 16 (base - 2 - blkSegFixedLen)))
      (fun _ v res => res.2.2.1.state = v st.trTip
        ∧ (0 < 0 → res.2.1 = levelsOfV v 16 (base + blkStepFixedLen * (0 - 1)))
        ∧ (0 = 0 → res.2.1 = treeB))
      (fun _ _ hp => ⟨hp.1, fun h => by omega, fun _ => rfl⟩)).congr
      (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
      (by apply trChainState_heq (by omega) rfl rfl rfl)
      (fun _ hf => by cases hf) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  | startIdx, count + 1, hEnd, active, cr, treeB, bnd, startTag, t, base, st, htip => by
    dsimp only
    unfold blkChainFixedProg blkChainFixedSched
    let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
    let k : Fin 26 := ⟨startIdx, by omega⟩
    let bSeg := base + blkSegFixedLen
    let bStep := base + blkStepFixedLen
    let stSeg := trChainTip base blkSegFixedLen (by unfold blkSegFixedLen; omega)
    let stStep : TrChainState bStep :=
      ⟨true, bSeg - 1, fun _ => by unfold bStep bSeg blkStepFixedLen blkSegFixedLen; omega, true, fun _ => rfl⟩
    let stOut : TrChainState (base + blkStepFixedLen * (count + 1)) :=
      ⟨true, base + blkStepFixedLen * (count + 1) - 3, fun _ => by unfold blkStepFixedLen blkSegFixedLen; omega,
        true, fun _ => rfl⟩
    rw [dite_eq_right (Nat.succ_ne_zero count)]
    have hBlk := blkSegFixedSliceSpec (Hdr := Hdr) hL20 hsep domain shape Rp hR hweights hinPub
      ioIn ioOut blkDig x hx c k active cr treeB bnd startTag t base st htip
    have hAfterBlk : ∀ bR : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr,
        SliceSpec Lq tag key domain shape c
          ((posTagKeyed Lq (by omega) key bR.2.2).andThen fun endTag =>
            (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
              x hx c (startIdx + 1) count (by omega) bR.1.isSome
              (match bR.1 with | some (_, c') => c' | none => carry0) bR.2.1 bnd endTag bR.2.2).andThen fun rest =>
              match bR.1, rest.1 with
              | some (enc, _), some (bs, crOut) =>
                .ret (some (enc endTag :: bs, crOut), rest.2.1, rest.2.2.1, rest.2.2.2)
              | _, _ => .ret (none, rest.2.1, rest.2.2.1, rest.2.2.2))
          bSeg (2 + blkStepFixedLen * count) (2 + blkStepFixedQ * count)
          (2 + 10864 * count) (2 + 10864 * count) (0 + 200704 * count) (0 + 200700 * count)
          stSeg (stOut.cast (show base + blkStepFixedLen * (count + 1) = bSeg + (2 + blkStepFixedLen * count) by unfold bSeg blkStepFixedLen; ring))
          (blkChainTreeSet (startIdx + 1) count)
          (spliceSched bStep (fun j => if j = bSeg then .squeeze (bSeg - 1) else .squeeze bSeg)
            (spliceSched (bStep + blkStepFixedLen * count)
              (blkChainFixedSched Pk (startIdx + 1) count (by omega) bStep (bSeg - 1))
              (fun _ => .absorb 0)))
          (fun _ v => bR.2.1 = levelsOfV v 16 base ∧ bR.2.2.state = v (bSeg - 1))
          (fun _ v res =>
            res.2.2.1.state = v stOut.trTip
              ∧ res.2.1 = levelsOfV v 16 (base + blkStepFixedLen * count)) := by
      intro bR
      have hPos := posTagSliceSpec (Lq := Lq) (by omega) hsep domain shape c bR.2.2 bSeg stSeg rfl rfl
      have hAfterPos : ∀ endTag : Dig,
          SliceSpec Lq tag key domain shape c
            ((blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
              x hx c (startIdx + 1) count (by omega) bR.1.isSome
              (match bR.1 with | some (_, c') => c' | none => carry0) bR.2.1 bnd endTag bR.2.2).andThen fun rest =>
                match bR.1, rest.1 with
                | some (enc, _), some (bs, crOut) =>
                  .ret (some (enc endTag :: bs, crOut), rest.2.1, rest.2.2.1, rest.2.2.2)
                | _, _ => .ret (none, rest.2.1, rest.2.2.1, rest.2.2.2))
            bStep (blkStepFixedLen * count) (blkStepFixedQ * count)
            (10864 * count) (10864 * count) (200704 * count) (200700 * count)
            stStep (stOut.cast (show base + blkStepFixedLen * (count + 1) = bStep + blkStepFixedLen * count by unfold bStep blkStepFixedLen; ring))
            (blkChainTreeSet (startIdx + 1) count)
            (spliceSched (bStep + blkStepFixedLen * count)
              (blkChainFixedSched Pk (startIdx + 1) count (by omega) bStep (bSeg - 1))
              (fun _ => .absorb 0))
            (fun _ v => bR.2.1 = levelsOfV v 16 base ∧ bR.2.2.state = v (bSeg - 1))
            (fun _ v res =>
              res.2.2.1.state = v stOut.trTip
                ∧ res.2.1 = levelsOfV v 16 (base + blkStepFixedLen * count)) := by
        intro endTag
        have ih := blkChainFixedSliceSpec (Hdr := Hdr) hL20 hsep domain shape Rp hR hweights hinPub ioIn ioOut blkDig
          x hx c (startIdx + 1) count (by omega) bR.1.isSome
          (match bR.1 with | some (_, c') => c' | none => carry0) bR.2.1 bnd endTag bR.2.2
          bStep stStep rfl
        dsimp only at ih
        let stIH : TrChainState (bStep + blkStepFixedLen * count) :=
          if hc : count = 0 then
            ⟨stStep.hasTip, stStep.trTip, fun h => by have := stStep.htip_lt h; omega, stStep.afterPosTag, stStep.hpos⟩
          else
            ⟨true, bStep + blkStepFixedLen * count - 3, fun _ => by unfold blkStepFixedLen blkSegFixedLen; omega,
              true, fun _ => rfl⟩
        have hstIH : stOut.cast (show base + blkStepFixedLen * (count + 1) = bStep + blkStepFixedLen * count by unfold bStep blkStepFixedLen; ring) = stIH := by
          apply TrChainState.ext
          · unfold TrChainState.cast stIH; split_ifs <;> rfl
          · unfold TrChainState.cast stIH stOut stStep bStep bSeg blkStepFixedLen blkSegFixedLen
            split_ifs with hc
            · subst hc; dsimp only; omega
            · dsimp only; omega
          · unfold TrChainState.cast stIH; split_ifs <;> rfl
        have htrTipEq : stIH.trTip = stOut.trTip := congrArg TrChainState.trTip hstIH.symm
        have hRet : ∀ rest : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig,
            SliceSpec Lq tag key domain shape c
              (match bR.1, rest.1 with
              | some (enc, _), some (bs, crOut) =>
                .ret (some (enc endTag :: bs, crOut), rest.2.1, rest.2.2.1, rest.2.2.2)
              | _, _ => .ret (none, rest.2.1, rest.2.2.1, rest.2.2.2))
              (bStep + blkStepFixedLen * count) 0 0 0 0 0 0 stIH stIH (fun _ => False) (fun _ => .absorb 0)
              (fun _ v => (rest.2.2.1.state = v stIH.trTip
                  ∧ (0 < count → rest.2.1 = levelsOfV v 16 (bStep + blkStepFixedLen * (count - 1))))
                ∧ (count = 0 → rest.2.1 = bR.2.1)
                ∧ bR.2.1 = levelsOfV v 16 base)
              (fun _ v res =>
                res.2.2.1.state = v stOut.trTip
                  ∧ res.2.1 = levelsOfV v 16 (base + blkStepFixedLen * count)) := by
          intro rest
          have hpostEq : ∀ (H : QB Lq → Dig) (v : ℕ → Dig),
              ((rest.2.2.1.state = v stIH.trTip
                  ∧ (0 < count → rest.2.1 = levelsOfV v 16 (bStep + blkStepFixedLen * (count - 1))))
                ∧ (count = 0 → rest.2.1 = bR.2.1)
                ∧ bR.2.1 = levelsOfV v 16 base) →
              rest.2.2.1.state = v stOut.trTip ∧ rest.2.1 = levelsOfV v 16 (base + blkStepFixedLen * count) := by
            intro _ v ⟨⟨h1, h2⟩, h3, h4⟩
            refine ⟨by rwa [htrTipEq] at h1, ?_⟩
            cases count with
            | zero => rw [h3 rfl, h4, Nat.mul_zero, Nat.add_zero]
            | succ c' =>
              have := h2 (Nat.succ_pos c')
              rw [this]; congr 1; simp only [Nat.add_sub_cancel]; unfold bStep blkStepFixedLen; ring
          cases bR.1 <;> cases rest.1 <;>
            exact retSliceSpec _ _ stIH _ _ hpostEq
        have ih'' : SliceSpec Lq tag key domain shape c
            (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
              x hx c (startIdx + 1) count (by omega) bR.1.isSome
              (match bR.1 with | some (_, c') => c' | none => carry0) bR.2.1 bnd endTag bR.2.2)
            bStep (blkStepFixedLen * count) (blkStepFixedQ * count)
            (10864 * count) (10864 * count) (200704 * count) (200700 * count)
            stStep stIH (blkChainTreeSet (startIdx + 1) count)
            (blkChainFixedSched Pk (startIdx + 1) count (by omega) bStep (bSeg - 1))
            (fun _ v => bR.2.1 = levelsOfV v 16 base ∧ bR.2.2.state = v (bSeg - 1))
            (fun _ v rest =>
              (rest.2.2.1.state = v stIH.trTip
                ∧ (0 < count → rest.2.1 = levelsOfV v 16 (bStep + blkStepFixedLen * (count - 1))))
              ∧ (count = 0 → rest.2.1 = bR.2.1)
              ∧ bR.2.1 = levelsOfV v 16 base) :=
          { ih with
            hpt_match := fun H v j hp h1 h2 =>
              ih.hpt_match H v j
                ⟨hp.2, fun _ => hp.1.trans (congrArg (levelsOfV v 16) (by unfold bStep blkStepFixedLen; omega))⟩ h1 h2
            hpost := fun H v hp =>
              let hp' := ih.hpost H v
                ⟨hp.2, fun _ => hp.1.trans (congrArg (levelsOfV v 16) (by unfold bStep blkStepFixedLen; omega))⟩
              ⟨⟨hp'.1, hp'.2.1⟩, hp'.2.2, hp.1⟩ }
        exact (ih''.andThen hRet (fun _ _ hf => hf)).congr (by omega) (by omega) (by omega) (by omega) (by omega) (by omega)
          (by apply trChainState_heq (by omega) (congrArg TrChainState.hasTip hstIH.symm)
                (congrArg TrChainState.trTip hstIH.symm) (congrArg TrChainState.afterPosTag hstIH.symm))
          (fun _ h => by rcases h with h | h; exact h; cases h)
          (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
      have hPos' : SliceSpec Lq tag key domain shape c (posTagKeyed Lq (by omega) key bR.2.2)
          bSeg 2 2 2 2 0 0 stSeg stStep (fun _ => False)
          (fun j => if j = bSeg then .squeeze (bSeg - 1) else .squeeze bSeg)
          (fun _ v => bR.2.1 = levelsOfV v 16 base ∧ bR.2.2.state = v (bSeg - 1))
          (fun _ v _ => bR.2.1 = levelsOfV v 16 base ∧ bR.2.2.state = v (bSeg - 1)) :=
        hPos.congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
          (TrChainState.ext rfl rfl rfl)
          (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ hp _ => hp)
      have hPos'' := hPos'.andThen hAfterPos (fun _ hf => by cases hf)
      exact hPos''.congr rfl le_rfl le_rfl le_rfl le_rfl le_rfl
        (TrChainState.ext rfl rfl rfl)
        (fun _ h => by rcases h with hf | h; cases hf; exact h)
        (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
    have hdisj : ∀ tid, blkTreeSet k tid → ¬ blkChainTreeSet (startIdx + 1) count tid := by
      rintro tid ht ⟨k', hk1, _, ht'⟩
      rcases ht with rfl | rfl | rfl | rfl <;> rcases ht' with h | h | h | h <;> cases h <;>
        exact Nat.not_succ_le_self k'.val hk1
    have hcomb := hBlk.andThen hAfterBlk hdisj
    exact hcomb.congr
      (by unfold blkStepFixedLen; ring) (le_of_eq (by unfold blkStepFixedQ; ring))
      (by omega) (by omega) (by omega) (by omega)
      (TrChainState.ext rfl rfl rfl)
      (fun tid h => by
        rcases h with ht | ⟨k', hk1, hk2, ht'⟩
        · exact ⟨k, le_rfl, by dsimp only [k]; omega, ht⟩
        · exact ⟨k', by omega, by omega, ht'⟩)
      (fun _ _ hp => hp.1)
      (fun _ _ res _ hr => ⟨hr.1, fun _ => by simpa [Nat.add_sub_cancel] using hr.2, fun h => by cases h⟩)

end BlkChain

/-! ## 3. Full 28-Segment Run `PProg` (`shdP_runFixedProg` + `.run` + `SliceSpec` + `ShdScheduleMatch`) -/

section FullRunProg

/-- **Full 28-segment fixed-schedule Shieldstral T128 R13 honest-prover `PProg`**
(`11,002,999` `.pt`s, `16,362,617` total queries, `112` Merkle trees, `0` duplicate `posTag` / opening draws). -/
noncomputable def shdP_runFixedProg {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) :
    PProg (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) :=
  let verdict := (classifySpecP Rp x.1).getD 0
  let TE := shdP_epTable (Hdr := Hdr) tag x.1 (shdEpBase c)
  (merkleTableProg Lq (by omega) tag 11 6 (by omega) TE
      (fun j => (shdP_epTable_cols_length (Hdr := Hdr) tag x.1 (shdEpBase c) j.val).trans
        (shdP_epTable_rows_length (Hdr := Hdr) tag x.1 (shdEpBase c)))).andThen fun treeTE =>
    let inRoot := treeTE.getRoot
    (shdP_hdrPProgF Lq hL20 key (hw hdr) hfit inRoot verdict).andThen fun t0 =>
      let bnd := t0.state
      (posTagKeyed Lq (by omega) key t0).andThen fun sIn =>
        (incSegFixedProg (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c treeTE bnd sIn t0).andThen fun incR =>
          (posTagKeyed Lq (by omega) key incR.2.2).andThen fun eIn =>
            let active0 := incR.1.isSome
            let cr0 := match incR.1 with | some (_, cr) => cr | none => carry0
            (blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
              x.1 x.2 c 0 26 (by omega) active0 cr0 incR.2.1 bnd eIn incR.2.2).andThen fun blkR =>
              let active26 := blkR.1.isSome
              let cr26 := match blkR.1 with | some (_, cr) => cr | none => carry0
              (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
                x.1 x.2 c active26 cr26 blkR.2.1 bnd blkR.2.2.2 blkR.2.2.1).andThen fun outR =>
                (posTagKeyed Lq (by omega) key outR.2).andThen fun eOut =>
                  match incR.1, blkR.1, outR.1 with
                  | some (incEnc, _), some (blkBytes, _), some outEnc =>
                    .ret (honestStmt hdr inRoot verdict, incEnc eIn :: (blkBytes ++ [outEnc eOut]))
                  | _, _, _ => .ret (refused, [])

/-- Exact static point schedule of `shdP_runFixedProg` across `[0, shdP_zkPts)` (`11,002,999` `.pt`s). -/
noncomputable def shdP_runFixedSched (tag : MTag) (Rp : ClassifyRunPublicP shieldS0)
    (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ) (wDigest : Dig) (bOutRow : ℕ) : ℕ → RawPtSpec :=
  let P0in := shdP_P0in tag Rp embDigest (embFoldL Rp.inp) bInRow
  let P0out := shdP_P0out tag Rp wDigest bOutRow
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
  let bTE := 4095
  let bHdr := 4102
  let bPosIn := 4104
  let bInc := 4104 + incSegFixedLen
  let bPosB0 := bInc + 2
  let bBlks := bPosB0 + blkStepFixedLen * 26
  let bOutc := bBlks + outcSegFixedLen
  let bEnd := bOutc + 2
  spliceSched bTE (merkleTreeSched .te 0)
    (spliceSched bHdr (hdrSched bTE 4094)
      (spliceSched bPosIn (fun j => if j = bHdr then .squeeze 4101 else .squeeze bHdr)
        (spliceSched bInc (incSegFixedSched P0in bPosIn 4101)
          (spliceSched bPosB0 (fun j => if j = bInc then .squeeze (bInc - 1) else .squeeze bInc)
            (spliceSched bBlks (blkChainFixedSched Pk 0 26 (by omega) bPosB0 (bInc - 1))
              (spliceSched bOutc (outcSegFixedSched P0out bBlks (bBlks - 3))
                (spliceSched bEnd (fun j => if j = bOutc then .squeeze (bOutc - 1) else .squeeze bOutc)
                  (fun _ => .absorb 0))))))))

private theorem three_stage_bind_in_err
    (rIn : Except Unit ((Dig → List UInt8) × Carry × Tr))
    (fBlk : Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr))
    (fOut : Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr))
    (posTag : Tr → Dig) (hIn : rIn = .error ()) :
    (rIn >>= fun r => fBlk r.2.1 r.2.2 >>= fun rb => fOut rb.2.1 rb.2.2 >>= fun ro =>
        .ok (r.1 (posTag r.2.2) :: (rb.1 ++ [ro.1 (posTag ro.2.2)]), ro.2.1, ro.2.2))
    = .error () := by
  rw [hIn]; rfl

private theorem three_stage_bind_blk_err
    (rIn : Except Unit ((Dig → List UInt8) × Carry × Tr))
    (fBlk : Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr))
    (fOut : Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr))
    (posTag : Tr → Dig) (incEnc : Dig → List UInt8) (cr0 : Carry) (t1 : Tr)
    (hIn : rIn = .ok (incEnc, cr0, t1)) (hBlk : fBlk cr0 t1 = .error ()) :
    (rIn >>= fun r => fBlk r.2.1 r.2.2 >>= fun rb => fOut rb.2.1 rb.2.2 >>= fun ro =>
        .ok (r.1 (posTag r.2.2) :: (rb.1 ++ [ro.1 (posTag ro.2.2)]), ro.2.1, ro.2.2))
    = .error () := by
  rw [hIn]; change fBlk cr0 t1 >>= _ = .error (); rw [hBlk]; rfl

private theorem three_stage_bind_out_err
    (rIn : Except Unit ((Dig → List UInt8) × Carry × Tr))
    (fBlk : Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr))
    (fOut : Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr))
    (posTag : Tr → Dig) (incEnc : Dig → List UInt8) (cr0 : Carry) (t1 : Tr)
    (blkBytes : List (List UInt8)) (cr26 : Carry) (t27 : Tr)
    (hIn : rIn = .ok (incEnc, cr0, t1)) (hBlk : fBlk cr0 t1 = .ok (blkBytes, cr26, t27))
    (hOut : fOut cr26 t27 = .error ()) :
    (rIn >>= fun r => fBlk r.2.1 r.2.2 >>= fun rb => fOut rb.2.1 rb.2.2 >>= fun ro =>
        .ok (r.1 (posTag r.2.2) :: (rb.1 ++ [ro.1 (posTag ro.2.2)]), ro.2.1, ro.2.2))
    = .error () := by
  rw [hIn]; change fBlk cr0 t1 >>= _ = .error (); rw [hBlk]
  change fOut cr26 t27 >>= _ = .error (); rw [hOut]; rfl

private theorem three_stage_bind_all_ok
    (rIn : Except Unit ((Dig → List UInt8) × Carry × Tr))
    (fBlk : Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr))
    (fOut : Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr))
    (posTag : Tr → Dig) (incEnc : Dig → List UInt8) (cr0 : Carry) (t1 : Tr)
    (blkBytes : List (List UInt8)) (cr26 : Carry) (t27 : Tr)
    (outEnc : Dig → List UInt8) (crEnd : Carry) (t28 : Tr)
    (hIn : rIn = .ok (incEnc, cr0, t1)) (hBlk : fBlk cr0 t1 = .ok (blkBytes, cr26, t27))
    (hOut : fOut cr26 t27 = .ok (outEnc, crEnd, t28)) :
    (rIn >>= fun r => fBlk r.2.1 r.2.2 >>= fun rb => fOut rb.2.1 rb.2.2 >>= fun ro =>
        .ok (r.1 (posTag r.2.2) :: (rb.1 ++ [ro.1 (posTag ro.2.2)]), ro.2.1, ro.2.2))
    = .ok (incEnc (posTag t1) :: (blkBytes ++ [outEnc (posTag t28)]), crEnd, t28) := by
  rw [hIn]; change fBlk cr0 t1 >>= _ = _; rw [hBlk]
  change fOut cr26 t27 >>= _ = _; rw [hOut]; rfl

private theorem merkleTableProg_pi {Lq : ℕ} {h1 h1' : 64 ≤ Lq} {tag : MTag} {d r : ℕ}
    {h2 h2' : 8 * r ≤ Lq} {T : Table} {hc hc' : ∀ j : Fin (2 ^ d), (T.cols j.val).length = r} :
    merkleTableProg Lq h1 tag d r h2 T hc = merkleTableProg Lq h1' tag d r h2' T hc' := by
  cases Subsingleton.elim h1 h1'; cases Subsingleton.elim h2 h2'; cases Subsingleton.elim hc hc'; rfl

private theorem blkChainFixedProg_pi {Hdr : Type} {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {tag : MTag} {key : Option Dig} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid}
    {ioIn ioOut : ℕ} {blkDig : Fin 26 → Dig}
    {x : shieldS0.Tok → ℕ} {hx hx' : (classifyModelP Rp).admissible x} {c : ShdCoins}
    {startIdx count : ℕ} {hEnd hEnd' : startIdx + count ≤ 26}
    {active active' : Bool} {cr cr' : Carry} {treeB : MerkleLevels 16} {bnd startTag : Dig} {t : Tr}
    (ha : active = active') (hcr : cr = cr') :
    blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx c startIdx count hEnd active cr treeB bnd startTag t
    = blkChainFixedProg (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut blkDig
      x hx' c startIdx count hEnd' active' cr' treeB bnd startTag t := by
  cases Subsingleton.elim hx hx'; cases Subsingleton.elim hEnd hEnd'; cases ha; cases hcr; rfl

private theorem outcSegFixedProg_pi {Lq : ℕ} {hL20 : 2 ^ 20 ≤ Lq}
    {tag : MTag} {key : Option Dig} {Rp : ClassifyRunPublicP shieldS0} {hR : ShieldRun Rp}
    {hweights : ∀ b ∈ Rp.blks, b.pub.Valid} {hinPub : Rp.inp.Valid} {houtPub : Rp.out.Valid}
    {wDigest : Dig} {bOutRow : ℕ}
    {x : shieldS0.Tok → ℕ} {hx hx' : (classifyModelP Rp).admissible x} {c : ShdCoins}
    {active active' : Bool} {cr cr' : Carry} {treeB26 : MerkleLevels 16} {bnd startTag : Dig} {t : Tr}
    (ha : active = active') (hcr : cr = cr') :
    outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c active cr treeB26 bnd startTag t
    = outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx' c active' cr' treeB26 bnd startTag t := by
  cases Subsingleton.elim hx hx'; cases ha; cases hcr; rfl

private theorem outcSegFixedProg_run_err_via {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (hver : st.verdict = (classifySpecP Rp x).getD 0) (c : ShdCoins)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig) (idx : Fin 27) (hidx : idx.val = 26)
    (hB26 : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeB26.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx)
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).rows (toZClaim cl))
    (herr : (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
        (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
          (liftH G) st x c bnd startTag cr t = .error ()) :
    ((outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c true cr treeB26 bnd startTag t).run G).1 = none := by
  have hEq : ∀ (h26 : 26 < 27), idx = ⟨26, h26⟩ := fun _ => Fin.ext hidx
  exact (outcSegFixedProg_run Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
    st x hx hver c cr treeB26 bnd startTag t htKey G
    (by intro j hj; rw [← hEq]; exact hB26 j hj)
    (by rw [← hEq]; exact hOwn)).1 herr

private theorem outcSegFixedProg_run_ok_via {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (wDigest : Dig) (bOutRow : ℕ)
    (st : ClsStmt Hdr) (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x)
    (hver : st.verdict = (classifySpecP Rp x).getD 0) (c : ShdCoins)
    (cr : Carry) (treeB26 : MerkleLevels 16) (bnd startTag : Dig) (t : Tr) (htKey : t.key = key)
    (G : QB Lq → Dig) (idx : Fin 27) (hidx : idx.val = 26)
    (hB26 : ∀ (j : ℕ) (hj : j < 2 ^ 16),
      treeB26.path j hj = pathOf (liftH G) tag 16
        (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx) j)
    (hOwn : cr.root = rootOf (liftH G) tag 16
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx)
        ∧ ∀ cl ∈ cr.pending, ClaimTrue shdP_U (2 ^ 14) 14
          (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x hx idx).rows (toZClaim cl))
    (outEnc : Dig → List UInt8) (crEnd : Carry) (t28 : Tr)
    (hok : (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
        (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
          (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
          (liftH G) st x c bnd startTag cr t = .ok (outEnc, crEnd, t28)) :
    (outcSegFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
      x hx c true cr treeB26 bnd startTag t).run G = (some outEnc, t28) := by
  have hEq : ∀ (h26 : 26 < 27), idx = ⟨26, h26⟩ := fun _ => Fin.ext hidx
  exact (outcSegFixedProg_run Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
    st x hx hver c cr treeB26 bnd startTag t htKey G
    (by intro j hj; rw [← hEq]; exact hB26 j hj)
    (by rw [← hEq]; exact hOwn)).2 outEnc crEnd t28 hok

/-- **Exact whole-run `.run G` equivalence (`hprog` of `ShdZKCountWitness`)**:
`(shdP_runFixedProg ... x c).run G` equals `(classifyProtocolP ... shdP_honestRunP_zk ...).prove G () x.1 c`! -/
theorem shdP_runFixedProg_run {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (tag : MTag) (key : Option Dig) (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
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
    (hdig : ∀ r v (k : Fin 26), digest (honestStmt hdr r v) k.val = blkDig k)
    (G : QB Lq → Dig) (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) :
    (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c).run G
    = (classifyProtocolP Rp Lq
        (shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
          (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp) check0 paths digest bndCheckV)
        (shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
          (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow check0 digest
          shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf)
        (shdP_cin Hdr tag) (le64_of_le20 hL20) (shdP_hr tag hL20)
        (shdP_honestIn (Hdr := Hdr) tag shdEpBase).base).prove G () x.1 c := by
  let V := shdP_runV tag key shdP_runDomain hw preA preB Rp embDigest (embFoldL Rp.inp) bInRow wDigest bOutRow
    (shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp) check0 paths digest bndCheckV
  let P := shdP_honestRunP_zk tag Rp hR hweights hinPub houtPub hdr refused ioIn ioOut
    (checkField shdP_blkOpenGeom) embDigest bInRow wDigest bOutRow check0 digest
    shdEpBase shdIncRndOf shdBlkRndOf shdOutcRndOf
  let verdict := (classifySpecP Rp x.1).getD 0
  let TE := shdP_epTable (Hdr := Hdr) tag x.1 (shdEpBase c)
  change (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
    ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c).run G
    = runProve V P (classifyModelP Rp).admissible (liftH G)
        (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x.1 (shdEpBase c))
        verdict x.1 c
  unfold runProve
  rw [ite_eq_left x.2]
  unfold shdP_runFixedProg
  dsimp only
  have hTEcols : ∀ j : Fin (2 ^ 11), (TE.cols j.val).length = 6 :=
    fun j => (shdP_epTable_cols_length (Hdr := Hdr) tag x.1 (shdEpBase c) j.val).trans
      (shdP_epTable_rows_length (Hdr := Hdr) tag x.1 (shdEpBase c))
  refine run_andThen_eq_prop_congr
    (A := fun trTE : MerkleLevels 11 => trTE.getRoot = rootOf (liftH G) tag 11 TE
      ∧ ∀ (j : ℕ) (hj : j < 2 ^ 11), trTE.path j hj = pathOf (liftH G) tag 11 TE j)
    merkleTableProg_pi _ G (merkleTableProg_run Lq (by omega) tag 11 6 (by omega) TE hTEcols G)
    fun trTE hTreeTE => ?_
  have hInRoot : trTE.getRoot = honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x.1 (shdEpBase c) :=
    hTreeTE.1.trans (shdP_epTable_root (Hdr := Hdr) tag Lq hL20 G x.1 (shdEpBase c))
  rw [run_andThen_hdr]
  have ht0Key : (clsStart shdP_runDomain key hw (liftH G) (honestStmt hdr trTE.getRoot verdict)).key = key := by
    rw [← shdP_hdrPProgF_run Lq hL20 key hw hdr hfit trTE.getRoot verdict G]
    exact shdP_hdrPProgF_run_key Lq hL20 key (hw hdr) hfit trTE.getRoot verdict G
  set t0 := clsStart shdP_runDomain key hw (liftH G) (honestStmt hdr trTE.getRoot verdict)
  set st := honestStmt hdr trTE.getRoot verdict
  rw [run_andThen_posTag ht0Key]
  -- Unfold `honestSegs V P` into `inC :: ((range 26).map blk ++ [outC])` (kept out of goal!)
  have hPhdr : P.hdr = hdr := rfl
  have hPref : P.refused = refused := rfl
  have hVstart : V.start (liftH G) st = t0 := rfl
  have hVL : V.L = 26 := rfl
  have hPinC : P.inC = inSegP _ (shdP_incP tag Rp embDigest bInRow
      (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c'))) := rfl
  have hPblk : P.blk = shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
      (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf := rfl
  have hPoutC : P.outC = outSegP _ (shdP_outcP tag Rp wDigest bOutRow
      (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
        (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf)) := rfl
  let rInE := (inSegP _ (shdP_incP tag Rp embDigest bInRow
      (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c')))).run
        (liftH G) st x.1 c t0.state (Exec.Block.posTag (liftH G) t0) carry0 t0
  let fBlkE : Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr) := fun cr t =>
    proveSegs (liftH G) st x.1 c t0.state ((List.range' 0 26).map
      (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
        (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr t
  let fOutE : Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr) := fun cr t =>
    (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
      (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
        (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
        (liftH G) st x.1 c t0.state (Exec.Block.posTag (liftH G) t) cr t
  have hHonest : honestSegs V P (liftH G)
      (honestRoot (shdP_cin Hdr tag) Lq (le64_of_le20 hL20) (shdP_hr tag hL20) G x.1 (shdEpBase c)) verdict x.1 c
      = (rInE >>= fun r => fBlkE r.2.1 r.2.2 >>= fun rb => fOutE rb.2.1 rb.2.2 >>= fun ro =>
          .ok (r.1 (Exec.Block.posTag (liftH G) r.2.2) :: (rb.1 ++ [ro.1 (Exec.Block.posTag (liftH G) ro.2.2)]),
            ro.2.1, ro.2.2)) := by
    have hr26 : List.range 26 = List.range' 0 26 := by decide
    unfold honestSegs RunP.parts
    rw [hPhdr, ← hInRoot, hVstart, hVL, hr26, hPinC, hPblk, hPoutC]
    exact proveSegs_three_stage (liftH G) st x.1 c t0.state _ _ _ carry0 t0
  -- Stage IN-C
  have hIncRun := incSegFixedProg_run (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c trTE st
    t0.state (Exec.Block.posTag (liftH G) t0) t0 ht0Key G hTreeTE.2
  have hIncKey := incSegFixedProg_run_key (Hdr := Hdr) Lq hL20 tag key Rp embDigest bInRow x.1 c trTE
    t0.state (Exec.Block.posTag (liftH G) t0) t0 G
  rcases hIncRun with ⟨hIncTree, hIncMatch⟩
  cases hInc : (inSegP _ (shdP_incP tag Rp embDigest bInRow
      (fun H _ x' c' => shdP_incTables (Hdr := Hdr) tag Rp embDigest bInRow H x' (shdEpBase c') (shdIncRndOf c')))).run
        (liftH G) st x.1 c t0.state (Exec.Block.posTag (liftH G) t0) carry0 t0 with
  | error u =>
    cases u
    rw [hInc] at hIncMatch; dsimp only at hIncMatch
    have hSegs := hHonest.trans (three_stage_bind_in_err rInE fBlkE fOutE (Exec.Block.posTag (liftH G)) hInc)
    rw [hSegs, hPref]
    refine run_andThen_eq_prop
      (A := fun incR : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr => incR.1 = none)
      _ _ G hIncMatch fun incR hnone => ?_
    rw [hnone]
    refine run_andThen_eq_const _ _ G _ fun _ =>
      run_andThen_eq_const _ _ G _ fun blkR =>
        run_andThen_eq_const _ _ G _ fun outR =>
          run_andThen_eq_const _ _ G _ fun _ => ?_
    cases blkR.1 <;> cases outR.1 <;> rfl
  | ok vInc =>
    rcases vInc with ⟨incEnc, cr0, t1⟩
    rw [hInc] at hIncMatch; dsimp only at hIncMatch
    refine run_andThen_eq_prop
      (A := fun incR : Option ((Dig → List UInt8) × Carry) × MerkleLevels 16 × Tr =>
        (incR.2.1.getRoot = rootOf (liftH G) tag 16 (shdP_incTB Rp x.1 (shdIncRndOf c))
          ∧ ∀ (j : ℕ) (hj : j < 2 ^ 16), incR.2.1.path j hj = pathOf (liftH G) tag 16 (shdP_incTB Rp x.1 (shdIncRndOf c)) j)
        ∧ (incR.1 = some (incEnc, cr0) ∧ incR.2.2 = t1)
        ∧ incR.2.2.key = key)
      _ _ G ⟨hIncTree, hIncMatch, hIncKey⟩ fun incR ⟨hIncTree', hIncMatch', hIncKey'⟩ => ?_
    rw [run_andThen_posTag hIncKey', hIncMatch'.1, hIncMatch'.2]
    have ht1Key : t1.key = key := hIncMatch'.2 ▸ hIncKey'
    have hBnd0 : ∀ (h0 : 0 < 27),
        shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 ⟨0, h0⟩
        = shdP_incTB Rp x.1 (shdIncRndOf c) := fun _ => rfl
    have hOwn0' := shdP_incSegP_out_own tag Rp hinPub hV131072 embDigest bInRow (liftH G) st x.1 x.2 c
      t0.state (Exec.Block.posTag (liftH G) t0) t0 incEnc cr0 t1 hInc
    -- 26-block chain + OUT-C
    cases hBlks : proveSegs (liftH G) st x.1 c t0.state ((List.range' 0 26).map
        (shdP_blkSegP_run_zk tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp hR hweights hinPub
          (fun b hb => (hweights b hb).act0) check0 digest shdIncRndOf shdBlkRndOf)) cr0 t1 with
    | error u =>
      cases u
      have hSegs := hHonest.trans
        (three_stage_bind_blk_err rInE fBlkE fOutE (Exec.Block.posTag (liftH G)) incEnc cr0 t1 hInc hBlks)
      rw [hSegs, hPref]
      have hBlkErr := blkChainFixedProg_run_err (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut
        check0 digest blkDig st (hdig trTE.getRoot verdict) x.1 x.2 c t0.state G 0 26 (Nat.le_refl 26)
        cr0 incR.2.1 t1 ht1Key
        (fun j hj => (hIncTree'.2 j hj).trans (congrArg (fun T => pathOf (liftH G) tag 16 T j) (hBnd0 _).symm))
        ⟨hOwn0'.1.trans (congrArg (fun T => rootOf (liftH G) tag 16 T) (hBnd0 _).symm),
         fun cl hcl => (congrArg (fun T : Table => ClaimTrue shdP_U (2 ^ 14) 14 T.rows (toZClaim cl)) (hBnd0 _).symm).mp
           (hOwn0'.2 cl hcl)⟩ hBlks
      refine run_andThen_eq_prop_congr
        (A := fun blkR : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig => blkR.1 = none)
        (blkChainFixedProg_pi (hEnd' := Nat.le_refl 26) (active' := true) (cr' := cr0) rfl rfl) _ G hBlkErr fun blkR hnone => ?_
      rw [hnone]
      refine run_andThen_eq_const _ _ G _ fun outR =>
        run_andThen_eq_const _ _ G _ fun _ => ?_
      cases outR.1 <;> rfl
    | ok vBlks =>
      rcases vBlks with ⟨blkBytes, cr26, t27⟩
      let idx26 : Fin 27 := ⟨26, by decide⟩
      have hBlkOk := blkChainFixedProg_run_ok (Hdr := Hdr) Lq hL20 tag key Rp hR hweights hinPub ioIn ioOut
        check0 digest blkDig st (hdig trTE.getRoot verdict) x.1 x.2 c t0.state G 0 26 (Nat.le_refl 26)
        cr0 incR.2.1 t1 ht1Key
        (fun j hj => (hIncTree'.2 j hj).trans (congrArg (fun T => pathOf (liftH G) tag 16 T j) (hBnd0 _).symm))
        ⟨hOwn0'.1.trans (congrArg (fun T => rootOf (liftH G) tag 16 T) (hBnd0 _).symm),
         fun cl hcl => (congrArg (fun T : Table => ClaimTrue shdP_U (2 ^ 14) 14 T.rows (toZClaim cl)) (hBnd0 _).symm).mp
           (hOwn0'.2 cl hcl)⟩ blkBytes cr26 t27 idx26 rfl hBlks
      refine run_andThen_eq_prop_congr
        (A := fun blkR : Option (List (List UInt8) × Carry) × MerkleLevels 16 × Tr × Dig =>
          blkR.1 = some (blkBytes, cr26) ∧ blkR.2.2.1 = t27 ∧ blkR.2.2.2 = Exec.Block.posTag (liftH G) t27
            ∧ t27.key = key
            ∧ (∀ (j : ℕ) (hj : j < 2 ^ 16), blkR.2.1.path j hj = pathOf (liftH G) tag 16
                (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 idx26) j)
            ∧ (cr26.root = rootOf (liftH G) tag 16
                  (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 idx26)
                ∧ ∀ cl ∈ cr26.pending, ClaimTrue shdP_U (2 ^ 14) 14
                  (shdP_bndTableAt Rp hR hweights hinPub (shdIncRndOf c) (shdBlkRndOf c) x.1 x.2 idx26).rows (toZClaim cl)))
        (blkChainFixedProg_pi (hEnd' := Nat.le_refl 26) (active' := true) (cr' := cr0) rfl rfl) _ G hBlkOk fun blkR ⟨hBo, hBt, hBe, hBk, hBtr, hBown⟩ => ?_
      rw [hBo, hBt, hBe]
      have hOutK := outcSegFixedProg_run_key Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
        x.1 x.2 c true cr26 blkR.2.1 t0.state (Exec.Block.posTag (liftH G) t27) t27 G
      cases hOut : (outSegP _ (shdP_outcP tag Rp wDigest bOutRow
          (shdP_outcTables_total tag Rp houtPub wDigest bOutRow
            (shdP_bndTableLast_total Rp hR hweights hinPub shdIncRndOf shdBlkRndOf) shdOutcRndOf))).run
            (liftH G) st x.1 c t0.state (Exec.Block.posTag (liftH G) t27) cr26 t27 with
      | error u =>
        cases u
        have hSegs := hHonest.trans
          (three_stage_bind_out_err rInE fBlkE fOutE (Exec.Block.posTag (liftH G)) incEnc cr0 t1 blkBytes cr26 t27 hInc hBlks hOut)
        rw [hSegs, hPref]
        have hOutRun := outcSegFixedProg_run_err_via Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          st x.1 x.2 rfl c cr26 blkR.2.1 t0.state (Exec.Block.posTag (liftH G) t27) t27 hBk G
          idx26 rfl hBtr hBown hOut
        refine run_andThen_eq_prop_congr (A := fun outR : Option (Dig → List UInt8) × Tr => outR.1 = none)
          (outcSegFixedProg_pi (active' := true) (cr' := cr26) rfl rfl) _ G hOutRun fun outR hnone => ?_
        rw [hnone]
        exact run_andThen_eq_const _ _ G _ fun _ => rfl
      | ok vOut =>
        rcases vOut with ⟨outEnc, crEnd, t28⟩
        have hSegs := hHonest.trans
          (three_stage_bind_all_ok rInE fBlkE fOutE (Exec.Block.posTag (liftH G)) incEnc cr0 t1 blkBytes cr26 t27 outEnc crEnd t28 hInc hBlks hOut)
        rw [hSegs, hPhdr, ← hInRoot]
        have hOutRun := outcSegFixedProg_run_ok_via Lq hL20 tag key Rp hR hweights hinPub houtPub wDigest bOutRow
          st x.1 x.2 rfl c cr26 blkR.2.1 t0.state (Exec.Block.posTag (liftH G) t27) t27 hBk G
          idx26 rfl hBtr hBown outEnc crEnd t28 hOut
        refine run_andThen_eq_prop_congr
          (A := fun outR : Option (Dig → List UInt8) × Tr => outR = (some outEnc, t28) ∧ outR.2.key = key)
          (outcSegFixedProg_pi (active' := true) (cr' := cr26) rfl rfl) _ G ⟨hOutRun, hOutK⟩ fun outR ⟨hOutEq, hOutK'⟩ => ?_
        rw [hOutEq] at hOutK' ⊢
        rw [run_andThen_posTag hOutK']
        rfl

private theorem trChainState_cast3 {a b c d : ℕ} (h1 : a = b) (h2 : b = c) (h3 : c = d) (h4 : a = d)
    (s : TrChainState a) : ((s.cast h1).cast h2).cast h3 = s.cast h4 := by
  cases h1; cases h2; cases h3; rfl

private theorem trChainState_cast2 {a b c : ℕ} (h1 : a = b) (h2 : b = c) (h3 : a = c)
    (s : TrChainState a) : (s.cast h1).cast h2 = s.cast h3 := by
  cases h1; cases h2; rfl

private theorem trChainState_cast2_self {a b : ℕ} (h1 : a = b) (h2 : b = a)
    (s : TrChainState a) : (s.cast h1).cast h2 = s := by
  cases h1; rfl

/-- **Full `[0, shdP_zkPts)` `SliceSpec` for `shdP_runFixedProg`**, discharging ALL budget counts
(`11,002,999` `.pt`s, `16,362,617` queries, `283,881 ≤ 2^20` `nTrK`, `283,879` `.tr`, `5,359,616` leaves,
`5,359,504` nodes), `DepStrict`, `DepIn`, `KCount`, and all static schedule invariants! -/
theorem shdP_runFixedSliceSpec {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x : {x // (classifyModelP Rp).admissible x}) (c : ShdCoins) :
    let st0 : TrChainState 0 := ⟨false, 0, (fun h => by cases h), false, (fun h => by cases h)⟩
    let stEnd : TrChainState (0 + shdP_zkPts) :=
      ⟨true, 11002996, fun _ => by rw [shdP_zkProg_counts.2.2.2.2.2.2.1]; omega, true, fun _ => rfl⟩
    SliceSpec Lq tag key shdP_runDomain (hw hdr).shape c
      (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c)
      0 shdP_zkPts shdP_zkQueries shdP_zkResT shdP_zkTrPts shdP_zkLeaves shdP_zkNodes
      st0 stEnd (fun _ => True)
      (shdP_runFixedSched tag Rp ioIn ioOut embDigest bInRow wDigest bOutRow)
      (fun _ _ => True) (fun _ _ _ => True) := by
  intro st0 stEnd
  unfold shdP_runFixedProg shdP_runFixedSched
  dsimp only
  let P0in := shdP_P0in tag Rp embDigest (embFoldL Rp.inp) bInRow
  let P0out := shdP_P0out tag Rp wDigest bOutRow
  let Pk := shdP_Pk0 tag ioIn ioOut (checkField shdP_blkOpenGeom) Rp
  let bTE := 4095
  let bHdr := 4102
  let bPosIn := 4104
  let bInc := 4104 + incSegFixedLen
  let bPosB0 := bInc + 2
  let bBlks := bPosB0 + blkStepFixedLen * 26
  let bOutc := bBlks + outcSegFixedLen
  let bEnd := bOutc + 2
  let stTE : TrChainState bTE := ⟨false, 0, (fun h => by cases h), false, (fun h => by cases h)⟩
  let stHdr := trChainTip bTE 7 (by norm_num)
  let stPosIn : TrChainState bPosIn := ⟨true, 4101, fun _ => by omega, true, fun _ => rfl⟩
  let stInc := trChainTip bPosIn incSegFixedLen (by unfold incSegFixedLen; omega)
  let stPosB0 : TrChainState bPosB0 := ⟨true, bInc - 1, fun _ => by unfold bPosB0 bInc incSegFixedLen; omega, true, fun _ => rfl⟩
  let stBlks : TrChainState bBlks := ⟨true, bBlks - 3, fun _ => by unfold bBlks bPosB0 bInc blkStepFixedLen blkSegFixedLen incSegFixedLen; omega, true, fun _ => rfl⟩
  let stOutc := trChainTip bBlks outcSegFixedLen (by unfold outcSegFixedLen; omega)
  let stEnd' : TrChainState bEnd := ⟨true, bOutc - 1, fun _ => by unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen; omega, true, fun _ => rfl⟩
  have hTEs : ∀ j : Fin (2 ^ 11), (shdP_epTable (Hdr := Hdr) tag x.1 (shdEpBase c)).salts j.val = shdLeafSalt c ⟨.te, j⟩ := fun j => by
    dsimp only [shdP_epTable, shdEpBase, shdLeafSalt]
    rw [dite_eq_left j.isLt]
  have hTE : SliceSpec Lq tag key shdP_runDomain (hw hdr).shape c
      (merkleTableProg Lq (by omega) tag 11 6 (by omega) (shdP_epTable (Hdr := Hdr) tag x.1 (shdEpBase c))
        (fun j => (shdP_epTable_cols_length (Hdr := Hdr) tag x.1 (shdEpBase c) j.val).trans
          (shdP_epTable_rows_length (Hdr := Hdr) tag x.1 (shdEpBase c))))
      0 bTE 6143 0 0 2048 2047 st0 stTE (fun tid => tid = .te) (merkleTreeSched .te 0)
      (fun _ _ => True) (fun _ v tr => tr.getRoot = v 4094) :=
    (merkleTableSliceSpec (Lq := Lq) (by omega) hsep shdP_runDomain (hw hdr).shape c .te 11 rfl 6 (by omega)
      (shdP_epTable (Hdr := Hdr) tag x.1 (shdEpBase c))
      (fun j => (shdP_epTable_cols_length (Hdr := Hdr) tag x.1 (shdEpBase c) j.val).trans
        (shdP_epTable_rows_length (Hdr := Hdr) tag x.1 (shdEpBase c))) hTEs 0 st0 (fun _ _ => True)).congr
      (by norm_num) (by norm_num) (by norm_num) (by norm_num) (by norm_num) (by norm_num)
      (by apply trChainState_heq (by norm_num) rfl rfl rfl) (fun _ h => h) (fun _ _ hp => hp) (fun _ _ tr _ hr => hr.2)
  have hdisjTE : ∀ tid, tid = .te → ¬ (incTreeSet tid ∨ blkChainTreeSet 0 26 tid ∨ outcTreeSet tid) := by
    rintro tid rfl (hi | ⟨k, _, _, hb⟩ | ho)
    · rcases hi with h | h | h | h <;> cases h
    · rcases hb with h | h | h | h <;> cases h
    · rcases ho with h | h | h <;> cases h
  have hdisjIB : ∀ tid, incTreeSet tid → ¬ (blkChainTreeSet 0 26 tid ∨ outcTreeSet tid) := by
    rintro tid ht (⟨k, _, _, hb⟩ | ho)
    · rcases ht with rfl | rfl | rfl | rfl <;> rcases hb with h | h | h | h <;>
        (first | (cases h; done) | (injection h with h'; have := congrArg Fin.val h'; dsimp at this; omega))
    · rcases ht with rfl | rfl | rfl | rfl <;> rcases ho with h | h | h <;>
        (first | (cases h; done) | (injection h with h'; have := congrArg Fin.val h'; dsimp at this; omega))
  have hdisjBO : ∀ tid, blkChainTreeSet 0 26 tid → ¬ outcTreeSet tid := by
    rintro tid ⟨k, _, _, ht⟩ ho
    have hk := k.isLt
    rcases ht with rfl | rfl | rfl | rfl <;> rcases ho with h | h | h <;>
      (first | (cases h; done) | (injection h with h'; have := congrArg Fin.val h'; dsimp at this; omega))
  -- Step 1: TE (`0 .. bTE`)
  refine SliceSpec.congr (post := fun _ _ _ => True) (hTE.andThen
    (len₂ := shdP_zkPts - bTE) (nQ₂ := shdP_zkQueries - 6143)
    (nTrK₂ := 283881) (nT₂ := 283879) (nL₂ := 5357568) (nN₂ := 5357457)
    (st₂ := stEnd'.cast (show bEnd = 0 + bTE + (shdP_zkPts - bTE) by
      rw [shdP_zkProg_counts.2.2.2.2.2.2.1]; unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bTE; norm_num))
    (trees₂ := fun tid => incTreeSet tid ∨ blkChainTreeSet 0 26 tid ∨ outcTreeSet tid)
    (fun treeTE => ?_) hdisjTE)
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ _ => trivial) (fun _ _ _ => trivial) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.1]; unfold bTE; rfl
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]
  · unfold shdP_zkResT; norm_num
  · rw [shdP_zkProg_counts.2.2.2.2.2.1]
  · rw [shdP_zkProg_counts.2.1]
  · rw [shdP_zkProg_counts.2.2.1]
  · exact TrChainState.ext rfl
      (by dsimp only [TrChainState.cast, stEnd, stEnd', bOutc, bBlks, bPosB0, bInc, outcSegFixedLen, blkStepFixedLen, blkSegFixedLen, incSegFixedLen]) rfl
  -- Step 2: Header (`bTE .. bHdr`)
  have hHdr := hdrSliceSpec hL20 hsep c (hw hdr) hfit treeTE.getRoot ((classifySpecP Rp x.1).getD 0) bTE 4094 (by omega) stTE rfl
  refine SliceSpec.congr (post := fun _ _ _ => True) (hHdr.andThen
    (len₂ := bEnd - bHdr) (nQ₂ := shdP_zkQueries - 6152)
    (nTrK₂ := 283872) (nT₂ := 283872) (nL₂ := 5357568) (nN₂ := 5357457)
    (st₂ := stEnd'.cast (show bEnd = bTE + 7 + (bEnd - bHdr) by
      unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bHdr bTE; omega))
    (trees₂ := fun tid => incTreeSet tid ∨ blkChainTreeSet 0 26 tid ∨ outcTreeSet tid)
    (fun t0 => ?_) (fun _ hf => by cases hf))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.1]; unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bHdr bTE; norm_num
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]
  · norm_num
  · norm_num
  · norm_num
  · norm_num
  · exact trChainState_cast3 _ _ _ _ stEnd'
  -- Step 3: sIn posTag (`bHdr .. bPosIn`)
  have hPosIn := (posTagSliceSpec (Lq := Lq) (by omega) hsep shdP_runDomain (hw hdr).shape c t0 bHdr stHdr rfl rfl).congr
    (stOut' := stPosIn)
    (pre' := fun _ v => t0.key = key ∧ t0.state = v (bTE + 6))
    (post' := fun _ v _ => t0.state = v 4101)
    rfl le_rfl le_rfl le_rfl le_rfl le_rfl
    (TrChainState.ext rfl rfl rfl)
    (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ hp _ => hp.2)
  refine SliceSpec.congr (post := fun _ _ _ => True) (hPosIn.andThen
    (len₂ := bEnd - bPosIn) (nQ₂ := shdP_zkQueries - 6154)
    (nTrK₂ := 283870) (nT₂ := 283870) (nL₂ := 5357568) (nN₂ := 5357457)
    (st₂ := stEnd'.cast (show bEnd = bHdr + 2 + (bEnd - bPosIn) by
      unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bPosIn bHdr; omega))
    (trees₂ := fun tid => incTreeSet tid ∨ blkChainTreeSet 0 26 tid ∨ outcTreeSet tid)
    (fun sIn => ?_) (fun _ hf => by cases hf))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bPosIn bHdr; omega
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]
  · norm_num
  · norm_num
  · norm_num
  · norm_num
  · exact trChainState_cast3 _ _ _ _ stEnd'
  -- Step 4: IN-C (`bPosIn .. bInc`)
  have hInc := incSegFixedSliceSpec (Hdr := Hdr) hL20 hsep shdP_runDomain (hw hdr).shape Rp embDigest bInRow
    x.1 c treeTE t0.state sIn t0 bPosIn stPosIn rfl
  refine SliceSpec.congr (post := fun _ _ _ => True) (hInc.andThen
    (len₂ := bEnd - bInc) (nQ₂ := shdP_zkQueries - 6154 - incSegFixedQ)
    (nTrK₂ := 283265) (nT₂ := 283265) (nL₂ := 5255168) (nN₂ := 5255061)
    (st₂ := stEnd'.cast (show bEnd = bPosIn + incSegFixedLen + (bEnd - bInc) by
      unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bPosIn; omega))
    (trees₂ := fun tid => blkChainTreeSet 0 26 tid ∨ outcTreeSet tid)
    (fun incR => ?_) hdisjIB)
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen bPosIn; omega
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]; unfold incSegFixedQ; norm_num
  · norm_num
  · norm_num
  · norm_num
  · norm_num
  · exact trChainState_cast3 _ _ _ _ stEnd'
  -- Step 5: eIn posTag (`bInc .. bPosB0`)
  have hPosB0 := (posTagSliceSpec (Lq := Lq) (by omega) hsep shdP_runDomain (hw hdr).shape c incR.2.2 bInc stInc rfl rfl).congr
    (stOut' := stPosB0)
    (pre' := fun _ v => incR.2.1 = levelsOfV v 16 bPosIn ∧ incR.2.2.state = v (bPosIn + incSegFixedLen - 1))
    (post' := fun _ v _ => incR.2.2.state = v (bInc - 1))
    rfl le_rfl le_rfl le_rfl le_rfl le_rfl
    (TrChainState.ext rfl rfl rfl)
    (fun _ h => h) (fun _ _ hp => hp.2) (fun _ _ _ hp _ => hp.2)
  refine SliceSpec.congr (post := fun _ _ _ => True) (hPosB0.andThen
    (len₂ := bEnd - bPosB0) (nQ₂ := shdP_zkQueries - 6156 - incSegFixedQ)
    (nTrK₂ := 283263) (nT₂ := 283263) (nL₂ := 5255168) (nN₂ := 5255061)
    (st₂ := stEnd'.cast (show bEnd = bInc + 2 + (bEnd - bPosB0) by
      unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen; omega))
    (trees₂ := fun tid => blkChainTreeSet 0 26 tid ∨ outcTreeSet tid)
    (fun eIn => ?_) (fun _ hf => by cases hf))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => by rcases h with hf | h; cases hf; exact h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen; omega
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]; unfold incSegFixedQ; norm_num
  · norm_num
  · norm_num
  · norm_num
  · norm_num
  · exact trChainState_cast3 _ _ _ _ stEnd'
  -- Step 6: 26-block chain (`bPosB0 .. bBlks`)
  have hBlks := blkChainFixedSliceSpec (Hdr := Hdr) hL20 hsep shdP_runDomain (hw hdr).shape Rp hR hweights hinPub
    ioIn ioOut blkDig x.1 x.2 c 0 26 (by omega) incR.1.isSome
    (match incR.1 with | some (_, cr) => cr | none => carry0) incR.2.1 t0.state eIn incR.2.2 bPosB0 stPosB0 rfl
  dsimp only at hBlks
  rw [dite_eq_right (by omega : (26 : ℕ) ≠ 0)] at hBlks
  have hBlks' := hBlks.congr
    (stOut' := stBlks)
    (pre' := fun _ v => incR.2.2.state = v (bInc - 1))
    (post' := fun _ v blkR => blkR.2.2.1.state = v (bBlks - 3))
    rfl le_rfl le_rfl le_rfl le_rfl le_rfl
    (TrChainState.ext rfl rfl rfl) (fun _ h => h)
    (fun _ _ hp => ⟨hp, fun h => by omega⟩) (fun _ _ _ _ hr => hr.1)
  refine SliceSpec.congr (post := fun _ _ _ => True) (hBlks'.andThen
    (len₂ := outcSegFixedLen + 2) (nQ₂ := outcSegFixedQ + 2)
    (nTrK₂ := 799) (nT₂ := 799) (nL₂ := 36864) (nN₂ := 36861)
    (st₂ := stEnd'.cast (show bEnd = bPosB0 + blkStepFixedLen * 26 + (outcSegFixedLen + 2) by
      unfold bEnd bOutc bBlks; omega))
    (trees₂ := outcTreeSet)
    (fun blkR => ?_) hdisjBO)
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · unfold bEnd bOutc bBlks bPosB0 bInc outcSegFixedLen blkStepFixedLen blkSegFixedLen incSegFixedLen; omega
  · rw [shdP_zkProg_counts.2.2.2.2.2.2.2.2.1]; unfold outcSegFixedQ blkStepFixedQ blkSegFixedQ incSegFixedQ; norm_num
  · norm_num
  · norm_num
  · norm_num
  · norm_num
  · exact trChainState_cast3 _ _ _ _ stEnd'
  -- Step 7: OUT-C (`bBlks .. bOutc`)
  have hOut := outcSegFixedSliceSpec hL20 hsep shdP_runDomain (hw hdr).shape Rp hR hweights hinPub houtPub
    wDigest bOutRow x.1 x.2 c blkR.1.isSome
    (match blkR.1 with | some (_, cr) => cr | none => carry0) blkR.2.1 t0.state blkR.2.2.2 blkR.2.2.1
    bBlks stBlks rfl
  refine SliceSpec.congr (post := fun _ _ _ => True) (hOut.andThen
    (len₂ := 2) (nQ₂ := 2) (nTrK₂ := 2) (nT₂ := 2) (nL₂ := 0) (nN₂ := 0)
    (st₂ := stEnd') (trees₂ := fun _ => False)
    (fun outR => ?_) (fun _ _ hf => hf))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => by rcases h with h | hf; exact h; cases hf) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · omega
  · omega
  · omega
  · omega
  · omega
  · omega
  · exact trChainState_cast2 _ _ _ stEnd'
  -- Step 8: eOut posTag + final ret (`bOutc .. bEnd`)
  have hPosOut := (posTagSliceSpec (Lq := Lq) (by omega) hsep shdP_runDomain (hw hdr).shape c outR.2 bOutc stOutc rfl rfl).congr
    (stOut' := stEnd')
    rfl le_rfl le_rfl le_rfl le_rfl le_rfl
    (TrChainState.ext rfl rfl rfl) (fun _ h => h) (fun _ _ hp => hp) (fun _ _ _ _ hr => hr)
  refine SliceSpec.congr (post := fun _ _ _ => True) (hPosOut.andThen
    (len₂ := 0) (nQ₂ := 0) (nTrK₂ := 0) (nT₂ := 0) (nL₂ := 0) (nN₂ := 0)
    (st₂ := stEnd') (trees₂ := fun _ => False)
    (fun eOut => ?_) (fun _ hf => False.elim hf))
    ?_ ?_ ?_ ?_ ?_ ?_ ?_ (fun _ h => by rcases h with h | h <;> exact h) (fun _ _ hp => hp) (fun _ _ _ _ _ => trivial)
  rotate_left 1
  · omega
  · omega
  · omega
  · omega
  · omega
  · omega
  · exact trChainState_cast2_self _ _ stEnd'
  cases incR.1 <;> cases blkR.1 <;> cases outR.1 <;>
    exact retSliceSpec _ (bOutc + 2) stEnd' _ _ (fun _ _ _ => trivial)

/-- **Master `ShdScheduleMatch` for `shdP_runFixedProg`**: discharges all 11 static schedule obligations
(point counts, leaf/node injectivity, transcript causality, and pointwise query contracts) via `SliceSpec.finish`! -/
theorem shdP_runScheduleMatch {Hdr : Type} {Lq : ℕ} (hL20 : 2 ^ 20 ≤ Lq)
    {tag : MTag} {key : Option Dig} (hsep : KeySep tag key)
    (Rp : ClassifyRunPublicP shieldS0) (hR : ShieldRun Rp)
    (hweights : ∀ b ∈ Rp.blks, b.pub.Valid) (hinPub : Rp.inp.Valid) (houtPub : Rp.out.Valid)
    (hw : Hdr → ClsHdrW) (hdr : Hdr)
    (hfit : 64 + ((hw hdr).shape.length + (hw hdr).params.length + (hw hdr).chunk.length + 84) ≤ Lq)
    (refused : ClsStmt Hdr) (ioIn ioOut : ℕ) (embDigest : Dig) (bInRow : ℕ)
    (wDigest : Dig) (bOutRow : ℕ) (blkDig : Fin 26 → Dig)
    (x₀ : {x // (classifyModelP Rp).admissible x}) (c₀ : ShdCoins) :
    let hSlice := fun x c => shdP_runFixedSliceSpec hL20 hsep Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c
    let sched := shdP_runFixedSched tag Rp ioIn ioOut embDigest bInRow wDigest bOutRow
    ShdScheduleMatch Lq hL20 tag key shdP_runDomain (hw hdr).shape
      (shdP_runFixedProg Lq hL20 tag key Rp hR hweights hinPub houtPub hw hdr hfit refused
        ioIn ioOut embDigest bInRow wDigest bOutRow blkDig)
      (finishSched Lq sched
        (fun j L R hj hs => let hb := (hSlice x₀ c₀).hnode_bounds j L R (Nat.zero_le _) (by omega) hs; ⟨hb.2.1, hb.2.2⟩)
        (fun j hj htr => (hSlice x₀ c₀).htr_lt j (Nat.zero_le _) (by omega) htr)) :=
  SliceSpec.finish x₀ c₀
    (fun x c => shdP_runFixedSliceSpec hL20 hsep Rp hR hweights hinPub houtPub hw hdr hfit refused
      ioIn ioOut embDigest bInRow wDigest bOutRow blkDig x c)

end FullRunProg

/-! ## 4. Exact 112-Tree Start Offsets & Pure `v`-Only Opened Column Indices (`shdOpenedCols`) -/

section TreeIndexMap

/-- Start point index in `[0, shdP_zkPts)` of each of the `112` Merkle trees in `shdP_runFixedProg`. -/
def shdTreeBase : ShdTreeId → ℕ
  | .te => 0
  | .bnd k =>
    if k.val = 0 then 4104
    else 209507 + blkStepFixedLen * (k.val - 1)
  | .a s =>
    if s.val = 0 then 4104 + 131071 + 5
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + 2
    else 209507 + blkStepFixedLen * (s.val - 1) + 131071 + 5
  | .m s =>
    if s.val = 0 then 4104 + 131071 + 5 + 32767 + 3
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + 2 + 32767 + 3
    else 209507 + blkStepFixedLen * (s.val - 1) + 131071 + 5 + 131071 + 3
  | .h s =>
    if s.val = 0 then 4104 + 131071 + 5 + 32767 + 3 + 8191 + 16
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + 2 + 32767 + 3 + 8191 + 3
    else 209507 + blkStepFixedLen * (s.val - 1) + 131071 + 5 + 131071 + 3 + 8191 + 4

/-- Start point index in `[0, shdP_zkPts)` of the 64 column-sampling squeezes (`idxOf`) for each of the `112` trees. -/
def shdTreeSqBase : ShdTreeId → ℕ
  | .te => 4104 + 205401 - 64
  | .bnd k =>
    if k.val < 26 then 209507 + blkStepFixedLen * k.val + blkSegFixedLen - 64
    else 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 64
  | .m s =>
    if s.val = 0 then 4104 + 205401 - 73 - 149 - 112 - 64
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 186 - 64
    else 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 4824 - 64
  | .a s =>
    if s.val = 0 then 4104 + 205401 - 73 - 149 - 64
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 118 - 64
    else 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 4518 - 64
  | .h s =>
    if s.val = 0 then 4104 + 205401 - 73 - 64
    else if s.val = 27 then 209507 + blkStepFixedLen * 26 + outcSegFixedLen - 107 - 64
    else 209507 + blkStepFixedLen * (s.val - 1) + blkSegFixedLen - 107 - 64

/-- Extend a finite oracle vector `v : Fin shdP_zkResPts → Dig` to `ℕ → Dig` (matching `PProg.outOf`/`ptsOf`). -/
def shdExtV (v : Fin shdP_zkResPts → Dig) (i : ℕ) : Dig :=
  if h : i < shdP_zkResPts then v ⟨i, h⟩ else default

/-- **Pure `v`-only list of `256` opened column indices** for tree `tid : ShdTreeId` across all `112` trees. -/
def shdOpenedCols (v : Fin shdP_zkResPts → Dig) (tid : ShdTreeId) : List ℕ :=
  idxOf (2 ^ shdTreeDepthOf tid) 256
    ((List.range 64).map (fun k => shdExtV v (shdTreeSqBase tid + k)))

theorem shdOpenedCols_length (v : Fin shdP_zkResPts → Dig) (tid : ShdTreeId) :
    (shdOpenedCols v tid).length = 256 := by
  unfold shdOpenedCols
  rw [idxOf_length, List.length_map, List.length_range]; decide

theorem shdOpenedCols_lt (v : Fin shdP_zkResPts → Dig) (tid : ShdTreeId) :
    ∀ j ∈ shdOpenedCols v tid, j < 2 ^ shdTreeDepthOf tid := fun j hj =>
  idxOf_lt (2 ^ shdTreeDepthOf tid) 256 (Nat.two_pow_pos _) _ j hj

end TreeIndexMap

end ZK60.HonestShield
