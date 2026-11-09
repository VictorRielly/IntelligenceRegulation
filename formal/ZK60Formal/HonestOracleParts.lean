/-
D63 Lean lane L29 (2026-11-09), part 9: **the three kinds of part of the classify run, each with its head as a
transcript program and its refusals covered** (obligation O9's cover, part by part).

A part (a block's core, stage IN-C, stage OUT-C) starts from the transcript the run's earlier parts left. Given that
PREFIX as a transcript program `pre c` (the coins' data inside it), this file writes the part's HEAD as a program (its
frame, each root by its Merkle program, the head's challenges, `H`'s root as a function of them), and proves, from
`HonestOracleSlots.lean`'s `fam_refuse_cover`: **whenever the part's honest prover refuses, one of the listed events
holds**, the challenge events being `tprogSite`s (`δ = 0`):
* **`core_refuse_cover`** (a block's core, lane L25's `coreProve`, any `BlockParams`): a slot's refusal covered by the
  slot's sites (`SlotCover`), or after the slots: the functional count, `check_opening` of `A` or of `H`;
* **`outc_refuse_cover`** (stage OUT-C, `outcProve`): a carry that is not the prover's own (finding L25-1), the D66(3)
  site `outcAlphaSite` (256 bad values), a slot's refusal covered by its sites, or after the slots: the functional
  count, a claim on an output endpoint, `check_opening` of `A` or `H`, the boundary audit;
* **`inc_refuse_cover`** (stage IN-C, `incProve`): D66(3)'s guard `incAlphaBad` (NOT one site: finding L29-3), a slot's
  refusal covered by its sites (the slots' parameters read `r_emb` and each slot's IO row width: the family form), or
  after the slots: the functional count, `check_opening` of `A` or `H`, the endpoint audit.

`SlotCover` is `fam_refuse_cover`'s conclusion: at the slot the honest loop reached, `define` refused, or the slot's
CFS site fires, or one of its extension-round sites fires, or a deterministic schedule check failed.

The slots' honest data may depend on the coins: the head returns the coins' tag with its challenges (`(c, ch)`), and
the slot family reads it. Every premise is an explicit hypothesis: the roots as Merkle programs (`RootProg`) that
compute the honest data's roots, the honest slot data not reading the oracle except through the transcript, and no
wrap of the squeeze counter (`TProg.NoWrap`, fewer than `2^64` squeezes).
-/
import ZK60Formal.HonestOracleSlots

set_option autoImplicit false

namespace ZK60.HonestOracle

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.HonestClassify ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (BlockParams Hist Acc SlotDef SlotProof SlotRec histOf slotShape slotDefChecks hostedSum tabVals
  oneMinusProd labA labH labM absorbRoot Cm)
open ZK60.Exec.StageV

/-! ## A transcript program's absorb -/

theorem final_absorb {β : Type} (H : HIn → Dig) (l d : List UInt8) (k : TProg β) (t : Tr) :
    (TProg.absorb l d k).final H t = k.final H (t.absorb H l d) := rfl

/-! ## The cover of a part's slot refusals, named -/

section Cover

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {α : Type} (Pf : α → ℕ → BlockParams)
  (Df : (x : α) → (s : ℕ) → SlotData (Pf x s)) (bga : α → Fp2 × Fp2 × Fp2)
  {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **A part's slot refusal is covered by its sites** (`fam_refuse_cover`'s conclusion): there is a slot `i < n` the
earlier honest slots reached (the prefix `famPre … i` ends on the loop's own state there), and at that state `define`
refused, or slot `i`'s CFS site fires, or the site of one of its rounds fires, or a deterministic schedule check
failed. -/
def SlotCover (U : K) (hd : Coins → TProg α) (t0 : Coins → Tr) (hs : ∀ c, TProg.Sep (t0 c).key (hd c))
    (hnC : ∀ i c, TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (n : ℕ) (x : α) : Prop :=
  ∃ (i : ℕ) (ti : Tr) (recs : List SlotRec) (acc : Acc), i < n
    ∧ (famPre Pf Df bga (hd c) i).final (liftH G) (t0 c) = (ti, (x, recs, acc))
    ∧ ((∃ e, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
          (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .error e)
      ∨ (depCSite Lq hLq Pf (fun c => famPre Pf Df bga (hd c) i) i t0
          (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i) (hnC i) (K := K)).fires U G c
      ∨ (∃ m, m < slotN (Pf x i) i ∧ (depESite Lq hLq Pf Df bga (fun c => famPre Pf Df bga (hd c) i) i m t0
          (fun c => sep_famPre Pf Df bga _ (hd c) (hs c) i) (hnE i m) (K := K)).fires U G c)
      ∨ ∃ df, (Pf x i).define i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs)
            (ti.challengeFp2Vec (liftH G) ((Pf x i).draws i)).1 = .ok df
          ∧ ((∃ e, slotDefChecks (Pf x i) i acc df = .error e)
            ∨ (∃ e, hostedSum acc.scalars
                (slotSP (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).scalar
                df.hosted = .error e)
            ∨ ∃ e, tabVals
                (oneMinusProd ((slotRho (liftH G) (Pf x i) (Df x i) i
                  (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).drop (slotShape (Pf x i) i).1))
                ((slotRho (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti
                  df).take (slotShape (Pf x i) i).1)
                (slotSP (liftH G) (Pf x i) (Df x i) i (histOf (bga x).1 (bga x).2.1 (bga x).2.2 recs) acc ti df).terms
                df.tabs 0 = .error e))

/-- `fam_refuse_cover`, with its conclusion named. -/
theorem slotCover_of_refuse (U : K) (hU : U ^ 2 = algebraMap GF K 7) (hd : Coins → TProg α) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (hd c))
    (hnC : ∀ i c, TProg.NoWrap (depCProg Pf (famPre Pf Df bga (hd c) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg Pf Df bga (famPre Pf Df bga (hd c) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (n : ℕ) (x : α) (t3 : Tr) (hF : (hd c).final (liftH G) (t0 c) = (t3, x))
    (h : famProve (liftH G) (Pf x) (Df x) (bga x).1 (bga x).2.1 (bga x).2.2 n [] 0 {} t3 = .error ()) :
    SlotCover Lq hLq Pf Df bga U hd t0 hs hnC hnE G c n x :=
  fam_refuse_cover Lq hLq Pf Df bga U hU hd t0 hs hnC hnE G c n x t3 hF h

end Cover

/-! ## A block's core -/

section CorePart

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {β : Type} (H : HIn → Dig) (P : BlockParams)

/-- **A core's head as a program**, after a prefix `pre` ending at the core's start (the block's frame included):
`A`'s root (its Merkle program) and `absorb_root("A")`, `M`'s root and `absorb("M")`, `β, γ, α`, `H`'s root (a
function of them) and `absorb_root("H")`. Its data: the tag `a` (the coins) and `[β, γ, α]`. -/
def coreHeadProg {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β)
    (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) : TProg (A × List Fp2) :=
  bindP pre (fun _ => absorbRootP RA labA P.aRows P.logCols (fun _ => bindP RM.p (fun m => .absorb labM m.toList
    (drawsP 3 (fun ch => absorbRootP (RH ch) labH P.hRows P.logCols (fun _ => .done (a, ch)))))))

theorem final_coreHeadProg {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig}
    (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t : Tr) :
    (coreHeadProg P a pre RA RM RH).final H t
      = (absorbRoot H (((absorbRoot H (pre.final H t).1 labA (rA H) P.aRows P.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 3).2 labH
          (rH (((absorbRoot H (pre.final H t).1 labA (rA H) P.aRows P.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 3).1 H) P.hRows P.logCols,
        (a, (((absorbRoot H (pre.final H t).1 labA (rA H) P.aRows P.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 3).1)) := by
  unfold coreHeadProg
  rw [final_bindP, final_absorbRootP, final_bindP, RM.final_eq, final_absorb, final_drawsP, final_absorbRootP]
  rfl

theorem sep_coreHeadProg (key : Option Dig) {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM)
    (RH : ∀ ch, RootProg (rH ch)) (hp : TProg.Sep key pre) : TProg.Sep key (coreHeadProg P a pre RA RM RH) :=
  sep_bindP key pre _ hp (fun _ => sep_bindP key RA.p _ (RA.sep key) (fun _ =>
    sep_bindP key RM.p _ (RM.sep key) (fun _ => sep_drawsP key 3 _ (fun ch =>
      sep_bindP key (RH ch).p _ ((RH ch).sep key) (fun _ => trivial)))))

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- A core's slot family: one `BlockParams`; the slots' data the coins'; `(β, γ, α)` the head's three challenges. -/
abbrev corePf : Coins × List Fp2 → ℕ → BlockParams := fun _ _ => P
abbrev coreDf (Dc : Coins → SlotData P) : (x : Coins × List Fp2) → (s : ℕ) → SlotData (corePf (Coins := Coins) P x s) :=
  fun x _ => Dc x.1
abbrev coreBga : Coins × List Fp2 → Fp2 × Fp2 × Fp2 :=
  fun x => (x.2.getD 0 Fp2.zero, x.2.getD 1 Fp2.zero, x.2.getD 2 Fp2.zero)

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **A block core's refusals are covered** (lane L25's `coreProve`, any `BlockParams`): if the honest core prover
refuses on the transcript the prefix leaves, then a slot's refusal is covered by that slot's `δ = 0` sites
(`SlotCover`), or the slots returned and the functional count, `check_opening` of `A` or `check_opening` of `H`
refused. -/
theorem core_refuse_cover {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : Coins → TProg β)
    (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (Dc : Coins → SlotData P)
    (hnC : ∀ i c, TProg.NoWrap (depCProg (corePf P) (famPre (corePf P) (coreDf P Dc) coreBga
      (coreHeadProg P c (pre c) RA RM RH) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg (corePf P) (coreDf P Dc) coreBga (famPre (corePf P) (coreDf P Dc) coreBga
      (coreHeadProg P c (pre c) RA RM RH) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (D : CoreData P) (hA : D.aRoot = rA (liftH G)) (hM : D.maskRoot = rM (liftH G))
    (hH : ∀ ch, D.hRoot (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero) (ch.getD 2 Fp2.zero) = rH ch (liftH G))
    (hD : D.slot = Dc c) (h : coreProve (liftH G) P D ((pre c).final (liftH G) (t0 c)).1 = .error ()) :
    SlotCover Lq hLq (corePf P) (coreDf P Dc) coreBga U (fun c => coreHeadProg P c (pre c) RA RM RH) t0
        (fun c => sep_coreHeadProg P _ c (pre c) RA RM RH (hs c)) hnC hnE G c P.geom.slots.length
        (c, [(coreB (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1,
          (coreG (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1,
          (coreA (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1])
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
        slotsProve (liftH G) P D.slot (coreB (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1
          (coreG (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1
          (coreA (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1 P.geom.slots.length [] 0 {}
          (coreT3 (liftH G) P D ((pre c).final (liftH G) (t0 c)).1) = .ok (sps, recs, acc, t4)
        ∧ ((acc.fs ++ acc.hostFs).length ≠ P.nFunctionals
          ∨ (∃ e, P.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
          ∨ ∃ e, P.checkOpening (liftH G) .h (acc.claims.h ++ [P.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e) := by
  have hX : coreT2 (liftH G) P D ((pre c).final (liftH G) (t0 c)).1
      = (absorbRoot (liftH G) ((pre c).final (liftH G) (t0 c)).1 labA (rA (liftH G)) P.aRows P.logCols).absorb (liftH G)
          labM (rM (liftH G)).toList := by
    unfold coreT2
    rw [hA, hM]
  have hF : (coreHeadProg P c (pre c) RA RM RH).final (liftH G) (t0 c)
      = (coreT3 (liftH G) P D ((pre c).final (liftH G) (t0 c)).1,
        (c, [(coreB (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1,
          (coreG (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1,
          (coreA (liftH G) P D ((pre c).final (liftH G) (t0 c)).1).1])) := by
    rw [final_coreHeadProg, ← hX, ← hH]
    rfl
  unfold coreProve at h
  split at h
  · rename_i e he
    cases e
    rw [slotsProve_eq_fam, hD] at he
    exact Or.inl (slotCover_of_refuse Lq hLq (corePf P) (coreDf P Dc) coreBga U hU
      (fun c => coreHeadProg P c (pre c) RA RM RH) t0 (fun c => sep_coreHeadProg P _ c (pre c) RA RM RH (hs c)) hnC hnE
      G c P.geom.slots.length _ _ hF he)
  · rename_i sps recs acc t4 hsl
    refine Or.inr ⟨sps, recs, acc, t4, hsl, ?_⟩
    split_ifs at h with hfs
    · exact Or.inl hfs
    · cases hcA : P.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
      | error e => exact Or.inr (Or.inl ⟨e, rfl⟩)
      | ok u1 =>
        cases hcH : P.checkOpening (liftH G) .h (acc.claims.h ++ [P.logupSumClaim])
            (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
        | error e => exact Or.inr (Or.inr ⟨e, rfl⟩)
        | ok u2 => simp [hcA, hcH] at h

end CorePart

/-! ## Stage OUT-C -/

section OutCPart

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {β : Type} (H : HIn → Dig) (V : OutcV)

/-- **Stage OUT-C's head as a program**, after a prefix `pre` ending at OUT-C's start: the frame (`pb-run-stage`,
`pb-run-block`), `A`'s root and `absorb_root("A")`, `M`'s root and `absorb("M")`, `γ, α`, `H`'s root (a function of
them) and `absorb_root("H")`. Its data: the tag `a` (the coins) and `[γ, α]`. -/
def outcHeadProg {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β)
    (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) : TProg (A × List Fp2) :=
  bindP pre (fun _ => .absorb labRunStage (le64 (UInt64.ofNat V.stageIndex)) (.absorb labRunBlock V.pub.wDigest.toList
    (absorbRootP RA labA V.bp.aRows V.bp.logCols (fun _ => bindP RM.p (fun m => .absorb labM m.toList
      (drawsP 2 (fun ch => absorbRootP (RH ch) labH V.bp.hRows V.bp.logCols (fun _ => .done (a, ch)))))))))

theorem final_outcHeadProg {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig}
    (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t : Tr) :
    (outcHeadProg V a pre RA RM RH).final H t
      = (absorbRoot H (((absorbRoot H (V.frame H (pre.final H t).1) labA (rA H) V.bp.aRows V.bp.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 2).2 labH
          (rH (((absorbRoot H (V.frame H (pre.final H t).1) labA (rA H) V.bp.aRows V.bp.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 2).1 H) V.bp.hRows V.bp.logCols,
        (a, (((absorbRoot H (V.frame H (pre.final H t).1) labA (rA H) V.bp.aRows V.bp.logCols).absorb H labM
            (rM H).toList).challengeFp2Vec H 2).1)) := by
  unfold outcHeadProg
  rw [final_bindP, final_absorb, final_absorb, final_absorbRootP, final_bindP, RM.final_eq, final_absorb, final_drawsP,
    final_absorbRootP]
  rfl

theorem sep_outcHeadProg (key : Option Dig) {A : Type} (a : A) {rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RA : RootProg rA) (RM : RootProg rM)
    (RH : ∀ ch, RootProg (rH ch)) (hp : TProg.Sep key pre) : TProg.Sep key (outcHeadProg V a pre RA RM RH) :=
  sep_bindP key pre _ hp (fun _ => sep_bindP key RA.p _ (RA.sep key) (fun _ =>
    sep_bindP key RM.p _ (RM.sep key) (fun _ => sep_drawsP key 2 _ (fun ch =>
      sep_bindP key (RH ch).p _ ((RH ch).sep key) (fun _ => trivial)))))

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- Stage OUT-C's slot family: its ONE `BlockParams`; the slots' data the coins'; `(0, γ, α)`. -/
abbrev outcPf : Coins × List Fp2 → ℕ → BlockParams := fun _ _ => V.bp
abbrev outcDf (Dc : Coins → SlotData V.bp) :
    (x : Coins × List Fp2) → (s : ℕ) → SlotData (outcPf (Coins := Coins) V x s) := fun x _ => Dc x.1
abbrev outcBga : Coins × List Fp2 → Fp2 × Fp2 × Fp2 := fun x => OutcV.bga x.2

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **Stage OUT-C's refusals are covered** (`outcProve`): if the honest OUT-C prover refuses on the transcript the
prefix leaves, then its carry is not its own (finding L25-1), or the D66(3) site fires (`outcAlphaSite`, 256 bad
values, `δ = 0`), or a slot's refusal is covered by that slot's `δ = 0` sites, or the slots returned and one of the
deterministic or audit refusals holds (the functional count, a claim on an output endpoint, `check_opening` of `A` or
`H`, the boundary audit). -/
theorem outc_refuse_cover {rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : Coins → TProg β)
    (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (Dc : Coins → SlotData V.bp)
    (hnA : ∀ c, TProg.NoWrap (outcAlphaProg V (pre c) RA RM) (t0 c))
    (hnC : ∀ i c, TProg.NoWrap (depCProg (outcPf V) (famPre (outcPf V) (outcDf V Dc) outcBga
      (outcHeadProg V c (pre c) RA RM RH) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg (outcPf V) (outcDf V Dc) outcBga (famPre (outcPf V) (outcDf V Dc) outcBga
      (outcHeadProg V c (pre c) RA RM RH) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (D : OutcData V) (cr : Carry) (hA : D.aRoot = rA (liftH G))
    (hM : D.maskRoot = rM (liftH G)) (hH : ∀ ch, D.hRoot ch = rH ch (liftH G)) (hD : D.slot = Dc c)
    (h : outcProve (liftH G) V D cr ((pre c).final (liftH G) (t0 c)).1 = .error ()) :
    D.own cr = false
      ∨ (outcAlphaSite Lq hLq V U pre RA RM t0 hs hnA).fires U G c
      ∨ SlotCover Lq hLq (outcPf V) (outcDf V Dc) outcBga U (fun c => outcHeadProg V c (pre c) RA RM RH) t0
          (fun c => sep_outcHeadProg V _ c (pre c) RA RM RH (hs c)) hnC hnE G c V.lay.ns
          (c, (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1)
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
          slotsProve (liftH G) V.bp D.slot
            (OutcV.bga (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1).1
            (OutcV.bga (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1).2.1
            (OutcV.bga (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1).2.2 V.lay.ns [] 0 {}
            (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).2 labH
              (D.hRoot (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1) V.bp.hRows V.bp.logCols)
              = .ok (sps, recs, acc, t4)
          ∧ ((acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals ∨ acc.claims.out ≠ []
            ∨ (∃ e, V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
            ∨ (∃ e, V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
            ∨ ∃ e, V.bCheck (liftH G) (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e) := by
  have hF : (outcHeadProg V c (pre c) RA RM RH).final (liftH G) (t0 c)
      = (absorbRoot (liftH G) (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).2 labH
          (D.hRoot (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1) V.bp.hRows V.bp.logCols,
        (c, (outcCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1)) := by
    rw [final_outcHeadProg]
    unfold outcCh
    rw [hA, hM, hH]
  unfold outcProve at h
  split_ifs at h with hown hbad
  · exact Or.inl hown
  · exact Or.inr (Or.inl ((outcAlphaSite_fires Lq hLq V U hU pre RA RM t0 hs hnA G c D hA hM).mpr hbad))
  · split at h
    · rename_i e he
      cases e
      rw [slotsProve_eq_fam, hD] at he
      exact Or.inr (Or.inr (Or.inl (slotCover_of_refuse Lq hLq (outcPf V) (outcDf V Dc) outcBga U hU
        (fun c => outcHeadProg V c (pre c) RA RM RH) t0 (fun c => sep_outcHeadProg V _ c (pre c) RA RM RH (hs c)) hnC
        hnE G c V.lay.ns _ _ hF he)))
    · rename_i sps recs acc t4 hsl
      refine Or.inr (Or.inr (Or.inr ⟨sps, recs, acc, t4, hsl, ?_⟩))
      split_ifs at h with hfs hout
      · exact Or.inl hfs
      · exact Or.inr (Or.inl hout)
      · cases hcA : V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inr (Or.inr (Or.inl ⟨e, rfl⟩))
        | ok u1 =>
          cases hcH : V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inr (Or.inr (Or.inr (Or.inl ⟨e, rfl⟩)))
          | ok u2 =>
            cases hcB : V.bCheck (liftH G) (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact Or.inr (Or.inr (Or.inr (Or.inr ⟨e, rfl⟩)))
            | ok u3 => simp [hcA, hcH, hcB] at h

end OutCPart

/-! ## Stage IN-C -/

section InCPart

variable (Lq : ℕ) (hLq : 47 ≤ Lq) {β : Type} (H : HIn → Dig) (V : IncV)

/-- **Stage IN-C's head as a program**, after a prefix `pre` ending at the run header: the frame (`pb-run-stage 0`,
`pb-run-block`), `B_in`'s root and `absorb_root("B")`, `A`'s root and `absorb_root("A")`, `M`'s root and
`absorb("M")`, `β, γ, α, r_emb`, `H`'s root (a function of them) and `absorb_root("H")`. Its data: the tag `a` (the
coins) and the head's challenges. -/
def incHeadProg {A : Type} (a : A) {rB rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β)
    (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) : TProg (A × List Fp2) :=
  bindP pre (fun _ => .absorb labRunStage (le64 0) (.absorb labRunBlock V.pub.embDigest.toList
    (absorbRootP RB labB V.geo.bRows V.geo.bLogN (fun _ =>
      absorbRootP RA labA V.lay.aRows V.lay.logN (fun _ => bindP RM.p (fun m => .absorb labM m.toList
        (drawsP (incHeadDraws V.pub) (fun ch =>
          absorbRootP (RH ch) labH V.lay.hRows V.lay.logN (fun _ => .done (a, ch))))))))))

theorem final_incHeadProg {A : Type} (a : A) {rB rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig}
    (pre : TProg β) (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t : Tr) :
    (incHeadProg V a pre RB RA RM RH).final H t
      = (absorbRoot H (((absorbRoot H (V.frame H (rB H) (pre.final H t).1) labA (rA H) V.lay.aRows V.lay.logN).absorb H
            labM (rM H).toList).challengeFp2Vec H (incHeadDraws V.pub)).2 labH
          (rH (((absorbRoot H (V.frame H (rB H) (pre.final H t).1) labA (rA H) V.lay.aRows V.lay.logN).absorb H labM
            (rM H).toList).challengeFp2Vec H (incHeadDraws V.pub)).1 H) V.lay.hRows V.lay.logN,
        (a, (((absorbRoot H (V.frame H (rB H) (pre.final H t).1) labA (rA H) V.lay.aRows V.lay.logN).absorb H labM
            (rM H).toList).challengeFp2Vec H (incHeadDraws V.pub)).1)) := by
  unfold incHeadProg
  rw [final_bindP, final_absorb, final_absorb, final_absorbRootP, final_absorbRootP, final_bindP, RM.final_eq,
    final_absorb, final_drawsP, final_absorbRootP]
  rfl

theorem sep_incHeadProg (key : Option Dig) {A : Type} (a : A) {rB rA rM : (HIn → Dig) → Dig}
    {rH : List Fp2 → (HIn → Dig) → Dig} (pre : TProg β) (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM)
    (RH : ∀ ch, RootProg (rH ch)) (hp : TProg.Sep key pre) : TProg.Sep key (incHeadProg V a pre RB RA RM RH) :=
  sep_bindP key pre _ hp (fun _ => sep_bindP key RB.p _ (RB.sep key) (fun _ =>
    sep_bindP key RA.p _ (RA.sep key) (fun _ => sep_bindP key RM.p _ (RM.sep key) (fun _ =>
      sep_drawsP key _ _ (fun ch => sep_bindP key (RH ch).p _ ((RH ch).sep key) (fun _ => trivial))))))

variable {Coins : Type} [Fintype Coins] [Nonempty Coins] {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- Stage IN-C's slot family: the `BlockParams` of the head's challenges (`define` reads `r_emb`, finding L29-2) at
each slot's IO row width (finding L29-1); the slots' data the coins', at those challenges; `(β, γ, α)` unused. -/
abbrev incPf : Coins × List Fp2 → ℕ → BlockParams :=
  fun x s => atLog (V.bp (incCtx V.pub x.2)) (incElog V.pub V.geo.bLogN s)
abbrev incDf (Dc : Coins → (ch : List Fp2) → SlotData (V.bp (incCtx V.pub ch))) :
    (x : Coins × List Fp2) → (s : ℕ) → SlotData (incPf (Coins := Coins) V x s) :=
  fun x s => sdAt (Dc x.1 x.2) (incElog V.pub V.geo.bLogN s)
abbrev incBga : Coins × List Fp2 → Fp2 × Fp2 × Fp2 := fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)

variable (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **Stage IN-C's refusals are covered, except D66(3)** (`incProve`): if the honest IN-C prover refuses on the
transcript the prefix leaves, then D66(3)'s guard holds (`α` an entry of the table `τ`, a function of `r_emb`: NOT one
site, finding L29-3), or a slot's refusal is covered by that slot's `δ = 0` sites, or the slots returned and the
functional count, `check_opening` of `A` or `H`, or the endpoint audit refused. -/
theorem inc_refuse_cover {rB rA rM : (HIn → Dig) → Dig} {rH : List Fp2 → (HIn → Dig) → Dig} (pre : Coins → TProg β)
    (RB : RootProg rB) (RA : RootProg rA) (RM : RootProg rM) (RH : ∀ ch, RootProg (rH ch)) (t0 : Coins → Tr)
    (hs : ∀ c, TProg.Sep (t0 c).key (pre c)) (Dc : Coins → (ch : List Fp2) → SlotData (V.bp (incCtx V.pub ch)))
    (hnC : ∀ i c, TProg.NoWrap (depCProg (incPf V) (famPre (incPf V) (incDf V Dc) incBga
      (incHeadProg V c (pre c) RB RA RM RH) i) i) (t0 c))
    (hnE : ∀ i m c, TProg.NoWrap (depEProg (incPf V) (incDf V Dc) incBga (famPre (incPf V) (incDf V Dc) incBga
      (incHeadProg V c (pre c) RB RA RM RH) i) i m) (t0 c))
    (G : QB Lq → Dig) (c : Coins) (D : IncData V) (hB : D.bRoot = rB (liftH G)) (hA : D.aRoot = rA (liftH G))
    (hM : D.maskRoot = rM (liftH G)) (hH : ∀ ch, D.hRoot ch = rH ch (liftH G)) (hD : D.slot = Dc c)
    (h : incProve (liftH G) V D ((pre c).final (liftH G) (t0 c)).1 = .error ()) :
    incAlphaBad (incCtx V.pub (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1) = true
      ∨ SlotCover Lq hLq (incPf V) (incDf V Dc) incBga U (fun c => incHeadProg V c (pre c) RB RA RM RH) t0
          (fun c => sep_incHeadProg V _ c (pre c) RB RA RM RH (hs c)) hnC hnE G c V.lay.ns
          (c, (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1)
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
          stSlotsProve (liftH G) (V.bp (incCtx V.pub (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1))
            (incElog V.pub V.geo.bLogN) (D.slot (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1)
            Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {}
            (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).2 labH
              (D.hRoot (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1) V.lay.hRows V.lay.logN)
              = .ok (sps, recs, acc, t4)
          ∧ ((acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals
            ∨ (∃ e, V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
            ∨ (∃ e, V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
            ∨ ∃ e, checkTokenEp (liftH G) acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e) := by
  have hF : (incHeadProg V c (pre c) RB RA RM RH).final (liftH G) (t0 c)
      = (absorbRoot (liftH G) (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).2 labH
          (D.hRoot (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1) V.lay.hRows V.lay.logN,
        (c, (incCh (liftH G) V D ((pre c).final (liftH G) (t0 c)).1).1)) := by
    rw [final_incHeadProg]
    unfold incCh
    rw [hB, hA, hM, hH]
  unfold incProve at h
  split_ifs at h with hbad
  · exact Or.inl hbad
  · split at h
    · rename_i e he
      cases e
      rw [stSlotsProve_eq_fam, hD] at he
      exact Or.inr (Or.inl (slotCover_of_refuse Lq hLq (incPf V) (incDf V Dc) incBga U hU
        (fun c => incHeadProg V c (pre c) RB RA RM RH) t0 (fun c => sep_incHeadProg V _ c (pre c) RB RA RM RH (hs c))
        hnC hnE G c V.lay.ns _ _ hF he))
    · rename_i sps recs acc t4 hsl
      refine Or.inr (Or.inr ⟨sps, recs, acc, t4, hsl, ?_⟩)
      split_ifs at h with hfs
      · exact Or.inl hfs
      · cases hcA : V.checkOpening (liftH G) .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inr (Or.inl ⟨e, rfl⟩)
        | ok u1 =>
          cases hcH : V.checkOpening (liftH G) .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inr (Or.inr (Or.inl ⟨e, rfl⟩))
          | ok u2 =>
            cases hcE : checkTokenEp (liftH G) acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact Or.inr (Or.inr (Or.inr ⟨e, rfl⟩))
            | ok u3 => simp [hcA, hcH, hcE] at h

end InCPart

end ZK60.HonestOracle
