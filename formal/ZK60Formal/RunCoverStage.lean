/-
D63 lane L39 (2026-11-10), part 1: **the repaired stage contracts at L29's REAL stage verifiers** (the non-vacuity half
of the repair of the gap audit's finding GA-1).

The gap audit (`ZK60_LEAN_GAP_AUDIT_PREMISES_20261110.md`, GA-1) proved that lane L34's `RtInc` could be met only by a
stage IN-C that never accepts: its claim counts `hcnt` held for EVERY core whose slot phase the stage accepts, the core
with no slots included, so every count was `0`, while stage IN-C accepts only with one claim on the input endpoint.
Lane L39 guards `RtInc.hcnt` and `RtOutc.hcnt` by the core's slot count, in place (`RunTrStages.lean`). This file shows
that the repaired contracts are MET BY THE REAL VERIFIERS, with no premise beyond the tier's numeric facts, and that the
honest segments the real verifiers accept lie inside the guard:

* (`RunCoverDefine.lean`) `rc_incDefine`, `rc_outcDefine`: every slot definition of L29's `incDefine` / `outcDefine`
  that succeeds has the schedule's claim counts per commitment `(A, H, In, Out)` (`rcIncCnt`, `rcOutcCnt`);
* `rc_stSlotsLoop_claims`: the stage slot loop's claim counts (L31's `slotsLoop_claims` at the per-slot IO widths);
* **`rc_incSlots_counts`**, **`rc_outcSlots_counts`**: an accepted slot phase of a core with the geometry's slot count
  leaves `A` 3 claims, `H` 4 (with the LogUp sum claim), `In` 1, `Out` 1 (stage IN-C); `A` 29, `H` 10, `In` 1
  (stage OUT-C). These hold for EVERY `IncV` / `OutcV`: the definitions are L29's, whatever the public data;
* `rcPcsAt`: L29's `pcsAt` (`pcs::verify_zk_tagged` at a commitment's parameters) is an `RtPcs`;
* `rcIncGeom`, `rcOutcGeom`: the stage segments' geometries, as L29's corpus checker builds them (`gIn`, `gOut`);
  `rcIncPart`, `rcOutcPart`: the stages' profile counts;
* **`rcIncOf`**, **`rcOutcOf`**: the repaired `RtInc` / `RtOutc` BUILT at any stage verifier whose `M` and openings are
  L10's `maskField` and L29's `pcsAt` (L32's hypotheses `hVm`, `hVa`, `hVh`, `hVe`); **`rcIncAt`**, **`rcOutcAt`**: at
  L29's `incVAt` / `outcVAt` themselves (OUT-C with the statement's verdict); **`rcIncAt_holds`**, **`rcOutcAt_holds`**:
  the stage contracts at the stages of `classifyRunV`; **`rcRunClassifyAt`**: L34's run schedule `rtRunClassify` at
  those stages, its premises `I : RtInc` and `O : RtOutc` gone;
* **`rcInc_honest`**, **`rcInc_honest_tables`**, **`rcOutc_honest`**, **`rcOutc_honest_tables`**: L32's honest
  segments (`incVerify_of_tables`, `outcVerify_of_tables`) are accepted by the same verifiers, their cores have the
  geometry's slot count (so they meet the guard), and stage IN-C's leaves exactly the contract's `nOut = 1` claim on
  `B_in` and its `nIn = 1` claim on the endpoint; stage OUT-C's slot phase has exactly the contract's counts.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrStages
import ZK60Formal.RunCoverDefine
import ZK60Formal.HonestRunStageIn
import ZK60Formal.HonestRunStageOut

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV

/-! ## The slot phases' claim counts -/

/-- **The stage slot loop's claim counts** (L31's `slotsLoop_claims` at the stage's per-slot IO widths): when every
definition of slot `k` has `cnt k` private tables in `cm`, the loop adds `cnt j + … + cnt (j + m − 1)` claims to `cm`. -/
theorem rc_stSlotsLoop_claims (H : HIn → Dig) (P : Block.BlockParams) (elog : ℕ → ℕ) (b g a : Fp2) (cm : Block.Cm)
    (cnt : ℕ → ℕ)
    (hdef : ∀ (k : ℕ) (hist : Block.Hist) (dr : List Fp2) (df : Block.SlotDef), P.define k hist dr = .ok df →
      Block.cmCount cm df.tabs = cnt k) :
    ∀ (sps : List Block.SlotProof) (recs : List Block.SlotRec) (j : ℕ) (acc : Block.Acc) (t : Tr)
      (recs' : List Block.SlotRec) (acc' : Block.Acc) (t' : Tr),
      stSlotsLoop H P elog b g a recs j sps acc t = .ok (recs', acc', t') →
      (acc'.claims.get cm).length = (acc.claims.get cm).length + Block.sumFrom cnt j sps.length
  | [], recs, j, acc, t, recs', acc', t', h => by
    simp only [stSlotsLoop, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, rfl, -⟩ := h
    rfl
  | sp0 :: sps, recs, j, acc, t, recs', acc', t', h => by
    simp only [stSlotsLoop] at h
    split at h
    · cases h
    · rename_i r0 acc0 t0 hstep
      obtain ⟨df, vals, rhoFull, hdf, -, -, -, -, -, -, hacc0⟩ :=
        Block.slotStep_ok_terminal H (atLog P (elog j)) j _ sp0 acc t r0 acc0 t0 hstep
      have ih := rc_stSlotsLoop_claims H P elog b g a cm cnt hdef sps (recs ++ [r0]) (j + 1) acc0 t0 recs' acc' t' h
      have h1 : (acc0.claims.get cm).length = (acc.claims.get cm).length + cnt j := by
        rw [hacc0, Block.slotAcc_claims, Block.slotClaims_length, hdef j _ _ df hdf]
      rw [ih, h1, List.length_cons]
      show _ = _ + (cnt j + Block.sumFrom cnt (j + 1) sps.length)
      omega

theorem rc_acc0_get (cm : Block.Cm) : (((({} : Block.Acc).claims).get cm)).length = 0 := by
  cases cm <;> rfl

/-- Stage IN-C's accepted slot phase: `cm`'s claims are the per-slot counts summed over the core's slots. -/
theorem rc_incSlots_get (H : HIn → Dig) (V : IncV) (core : Block.Core) (t : Tr) (recs : List Block.SlotRec)
    (acc : Block.Acc) (t4 : Tr) (h : V.slots H core t = .ok (recs, acc, t4)) (cm : Block.Cm)
    (f : ℕ × ℕ × ℕ × ℕ → ℕ) (hf : ∀ df : Block.SlotDef, Block.cmCount cm df.tabs = f (rcCnt df)) :
    (acc.claims.get cm).length = Block.sumFrom (fun k => f (rcIncCnt k)) 0 core.slots.length := by
  have h0 := rc_stSlotsLoop_claims H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN) Fp2.zero
    Fp2.zero Fp2.zero cm (fun k => f (rcIncCnt k))
    (fun k hist dr df hdf => by
      rw [hf, rc_incDefine V.pub V.geo (incCtx V.pub (V.headCh H core t).1) k hist dr df hdf])
    core.slots [] 0 {} (V.slotT H core t) recs acc t4 h
  rw [h0, rc_acc0_get, Nat.zero_add]

theorem rc_incGeom_len (V : IncV) : V.geom.slots.length = 4 := rfl

theorem rc_outcGeom_len (V : OutcV) : V.geom.slots.length = 8 := rfl

/-- **Stage IN-C's claim counts, PROVED for every stage IN-C verifier**: an accepted slot phase of a core with the
geometry's slot count leaves `A` 3 claims, `H` 4 with the LogUp sum claim, the input endpoint 1, `B_in` 1. -/
theorem rc_incSlots_counts (H : HIn → Dig) (V : IncV) (core : Block.Core) (t : Tr) (recs : List Block.SlotRec)
    (acc : Block.Acc) (t4 : Tr) (h : V.slots H core t = .ok (recs, acc, t4))
    (hsh : core.slots.length = V.geom.slots.length) :
    acc.claims.a.length = 3 ∧ (acc.claims.h ++ [V.lay.logupSumClaim]).length = 4 ∧ acc.claims.inp.length = 1
      ∧ acc.claims.out.length = 1 := by
  have h4 : core.slots.length = 4 := hsh.trans (rc_incGeom_len V)
  have eA := rc_incSlots_get H V core t recs acc t4 h .a (fun x => x.1) (fun _ => rfl)
  have eH := rc_incSlots_get H V core t recs acc t4 h .h (fun x => x.2.1) (fun _ => rfl)
  have eI := rc_incSlots_get H V core t recs acc t4 h .inp (fun x => x.2.2.1) (fun _ => rfl)
  have eO := rc_incSlots_get H V core t recs acc t4 h .out (fun x => x.2.2.2) (fun _ => rfl)
  rw [h4] at eA eH eI eO
  refine ⟨eA, ?_, eI, eO⟩
  rw [List.length_append, List.length_singleton]
  exact congrArg (· + 1) eH

/-- Stage OUT-C's accepted slot phase: `cm`'s claims are the per-slot counts summed over the core's slots. -/
theorem rc_outcSlots_get (H : HIn → Dig) (V : OutcV) (core : Block.Core) (t : Tr) (ch : List Fp2)
    (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr)
    (h : StageFS.stageSlots H V.bp 2 OutcV.bga core t = .ok (ch, recs, acc, t4)) (cm : Block.Cm)
    (f : ℕ × ℕ × ℕ × ℕ → ℕ) (hf : ∀ df : Block.SlotDef, Block.cmCount cm df.tabs = f (rcCnt df)) :
    (acc.claims.get cm).length = Block.sumFrom (fun k => f (rcOutcCnt k)) 0 core.slots.length := by
  rw [StageFS.stageSlots_eq] at h
  split at h
  · rename_i r hloop
    simp only [Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨-, hr⟩ := h
    rw [hr] at hloop
    have h0 := Block.slotsLoop_claims H V.bp _ _ _ cm (fun k => f (rcOutcCnt k))
      (fun k hist dr df hdf => by rw [hf, rc_outcDefine V.pub V.geo k hist dr df hdf]) core.slots [] 0 {} _ recs acc t4
      hloop
    rw [h0, rc_acc0_get, Nat.zero_add]
  · cases h

/-- **Stage OUT-C's claim counts, PROVED for every stage OUT-C verifier**: an accepted slot phase of a core with the
geometry's slot count leaves `A` 29 claims, `H` 10 with the LogUp sum claim, `B_out` 1 (OUTC-00's), no output claim. -/
theorem rc_outcSlots_counts (H : HIn → Dig) (V : OutcV) (core : Block.Core) (t : Tr) (ch : List Fp2)
    (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr)
    (h : StageFS.stageSlots H V.bp 2 OutcV.bga core t = .ok (ch, recs, acc, t4))
    (hsh : core.slots.length = V.geom.slots.length) :
    acc.claims.a.length = 29 ∧ (acc.claims.h ++ [V.lay.logupSumClaim]).length = 10 ∧ acc.claims.inp.length = 1
      ∧ acc.claims.out.length = 0 := by
  have h8 : core.slots.length = 8 := hsh.trans (rc_outcGeom_len V)
  have eA := rc_outcSlots_get H V core t ch recs acc t4 h .a (fun x => x.1) (fun _ => rfl)
  have eH := rc_outcSlots_get H V core t ch recs acc t4 h .h (fun x => x.2.1) (fun _ => rfl)
  have eI := rc_outcSlots_get H V core t ch recs acc t4 h .inp (fun x => x.2.2.1) (fun _ => rfl)
  have eO := rc_outcSlots_get H V core t ch recs acc t4 h .out (fun x => x.2.2.2) (fun _ => rfl)
  rw [h8] at eA eH eI eO
  refine ⟨eA, ?_, eI, eO⟩
  rw [List.length_append, List.length_singleton]
  exact congrArg (· + 1) eH

/-! ## The slots' geometry -/

theorem rc_shapeLen_congr (P P' : Block.BlockParams) (hd : P.draws = P'.draws) :
    ∀ (j : ℕ) (l : List (ℕ × ℕ × ℕ)), shapeLen P j l = shapeLen P' j l
  | _, [] => rfl
  | j, s :: ss => by
    show P.draws j + 4 + 2 * (s.1 + s.2.1) + shapeLen P (j + 1) ss
      = P'.draws j + 4 + 2 * (s.1 + s.2.1) + shapeLen P' (j + 1) ss
    rw [hd, rc_shapeLen_congr P P' hd (j + 1) ss]

theorem rc_shapeSq_congr (P P' : Block.BlockParams) (hd : P.draws = P'.draws) :
    ∀ (j : ℕ) (l : List (ℕ × ℕ × ℕ)), shapeSq P j l = shapeSq P' j l
  | _, [] => rfl
  | j, s :: ss => by
    show P.draws j + 1 + (s.1 + s.2.1) + shapeSq P (j + 1) ss = P'.draws j + 1 + (s.1 + s.2.1) + shapeSq P' (j + 1) ss
    rw [hd, rc_shapeSq_congr P P' hd (j + 1) ss]

/-- Stage IN-C's slots: degrees `3, 4, 4, 2`, terminal counts `2, 3, 2, 1`. -/
theorem rc_incBounds (V : IncV) (cx : IncCtx) (j : ℕ) (hj : j < V.geom.slots.length) :
    1 ≤ (Block.slotShape (V.bp cx) j).2.2 ∧ (Block.slotShape (V.bp cx) j).2.2 ≤ 4
      ∧ Block.slotTerms (V.bp cx) j ≤ 3 := by
  have hj4 : j < 4 := lt_of_lt_of_eq hj (rc_incGeom_len V)
  interval_cases j <;> exact ⟨Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl⟩

/-- Stage OUT-C's slots: degrees `2, 4, 3, 2, 4, 5, 3, 2`, terminal counts `2, 1, 11, 1, 2, 19, 2, 1`. -/
theorem rc_outcBounds (V : OutcV) (j : ℕ) (hj : j < V.geom.slots.length) :
    1 ≤ (Block.slotShape V.bp j).2.2 ∧ (Block.slotShape V.bp j).2.2 ≤ 5 ∧ Block.slotTerms V.bp j ≤ 19 := by
  have hj8 : j < 8 := lt_of_lt_of_eq hj (rc_outcGeom_len V)
  interval_cases j <;> exact ⟨Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl, Nat.le_of_ble_eq_true rfl⟩

theorem rc_incGeom_gt (V : IncV) : V.geom.slots.length = V.geom.terms.length := rfl

theorem rc_outcGeom_gt (V : OutcV) : V.geom.slots.length = V.geom.terms.length := rfl

/-! ## L29's `pcsAt` as a scheduled opening -/

/-- **L29's `pcsAt` is an `RtPcs`** (`pcs::verify_zk_tagged` at a commitment's row width `2^logN`, rate `2^-lr`, `q`
opened columns and pads, `rows` rows): it accepts only when L10's `PcsOk` holds (`pcsVerify_ok_iff`). -/
def rcPcsAt {ι : Type} (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (tag : MTag) (logN lr q rows : ℕ)
    (hV : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t : Tr),
      V i H root cl o t = pcsAt tag logN lr q H root rows cl o t)
    (hq : 0 < q) (h15 : 2 ^ logN + q ≤ 2 ^ 15) : RtPcs V where
  tag := tag
  prm := ⟨logN, 2 ^ lr, q, q⟩
  pt := cosetPt (rootFp (logN + lr))
  ev := colEncLag (rootFp logN) (2 ^ logN) q
  rows := rows
  lc := logN
  Q := q
  N := 2 ^ logN * 2 ^ lr
  m := (q + 3) / 4
  hok := fun i H root cl o t t' h => by
    rw [hV, pcsAt, mapErr_ok] at h
    exact (pcsVerify_ok_iff H tag _ _ _ (fun _ vs => by simp [colEncLag]) root rows logN _ _ t t').mp h
  hqp := rfl
  hnQ := rfl
  hnn := rfl
  hpow := by
    show isPow2 (2 ^ logN * 2 ^ lr) = true
    rw [← pow_add]
    exact HonestOpen.isPow2_two_pow _
  hQ0 := hq
  hm := rfl
  hv15 := h15

/-! ## Stage IN-C's contract at the real verifier -/

/-- **Stage IN-C's segment geometry**, as L29's corpus checker builds it (`StageVerifyExecCheck.lean`, `gIn`): the
magic, the verifier's core geometry, a `B_in` root, ONE closed commitment (the input token endpoint: its `Dim`, one
group, its rows), `total = L + 2` segments, index `0`. -/
def rcIncGeom (V : IncV) (total : ℕ) : StageGeom := ⟨magicIn, V.geom, true, [(V.ed, 1, V.geo.epRows)], total, 0⟩

/-- A head context for the counts (they do not read it). -/
def rcCx0 : IncCtx := ⟨Fp2.zero, Fp2.zero, Fp2.zero, [], []⟩

/-- **Stage IN-C's profile counts**: the single phase (5 frame absorbs, 7 root operations, the head's draws, the
slots), `M`'s four mask specs, `A` (3 claims and its rows), `H` (4 claims and its rows), the input endpoint (1 claim,
1 group, its rows), each opening's index squeezes. -/
def rcIncPart (V : IncV) (q eq : ℕ) : RtPart :=
  ⟨12 + incHeadDraws V.pub + shapeLen (V.bp rcCx0) 0 V.geom.slots,
    incHeadDraws V.pub + shapeSq (V.bp rcCx0) 0 V.geom.slots, 4, 3 + V.lay.aRows, incAGroups, (q + 3) / 4,
    4 + V.lay.hRows, incHGroups, (q + 3) / 4, 1 + V.geo.epRows, 1, (eq + 3) / 4⟩

/-- **THE REPAIRED `RtInc`, BUILT** for every stage IN-C verifier whose `M` and openings are L10's `maskField tag 4`
and L29's `pcsAt` (L32's hypotheses `hVm`, `hVa`, `hVh`, `hVe`; L29's `incVAt` has them by definition), at the tier's
numeric facts (`q, eq > 0`; group vectors of at most `2^15` words). Its claim counts are `3, 4, 1, 1`. -/
def rcIncOf {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (V : IncV) (tag : MTag) (lr elr q eq total : ℕ)
    (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t
      = pcsAt tag V.pub.epLogN elr eq H' root V.geo.epRows cl o t)
    (hq : 0 < q) (heq : 0 < eq) (h15 : 2 ^ V.pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ V.pub.epLogN + eq ≤ 2 ^ 15) :
    RtInc Lq (fun _ : Hdr => V) (fun _ => rcIncGeom V total) (rcIncPart V q eq) where
  tag := tag
  nA := 3
  nH := 4
  nIn := 1
  nOut := 1
  pA := rcPcsAt _ tag V.pub.lt lr q V.lay.aRows (fun _ H root cl o t => hVa H root cl o t) hq h15
  pH := rcPcsAt _ tag V.pub.lt lr q V.lay.hRows (fun _ H root cl o t => hVh H root cl o t) hq h15
  pX := rcPcsAt _ tag V.pub.epLogN elr eq V.geo.epRows (fun _ H root cl o t => hVe H root cl o t) heq he15
  hPm := fun _ => hVm
  hgeo := fun _ => rfl
  hgt := fun _ => rc_incGeom_gt V
  hgeomL := fun _ cx j hj => by
    obtain ⟨h1, h2, h3⟩ := rc_incBounds V cx j hj
    exact ⟨h1, by omega, by omega⟩
  hclose := fun _ => ⟨_, rfl, rfl⟩
  hcnt := fun _ H core t recs acc t4 h hsh => rc_incSlots_counts H V core t recs acc t4 h hsh
  hpre := fun _ cx =>
    congrArg (fun x => 12 + incHeadDraws V.pub + x) (rc_shapeLen_congr (V.bp cx) (V.bp rcCx0)
      ((rt_incBp_draws V cx).trans (rt_incBp_draws V rcCx0).symm) 0 V.geom.slots)
  hpsq := fun _ cx =>
    congrArg (fun x => incHeadDraws V.pub + x) (rc_shapeSq_congr (V.bp cx) (V.bp rcCx0)
      ((rt_incBp_draws V cx).trans (rt_incBp_draws V rcCx0).symm) 0 V.geom.slots)
  hgA := fun _ => rfl
  hgH := fun _ => rfl
  hwA := rfl
  hmA := rfl
  hwH := rfl
  hmH := rfl
  hwX := rfl
  hmX := rfl

/-- The built contract's claim counts. -/
theorem rcIncOf_counts {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (V : IncV) (tag : MTag) (lr elr q eq total : ℕ)
    (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t
      = pcsAt tag V.pub.epLogN elr eq H' root V.geo.epRows cl o t)
    (hq : 0 < q) (heq : 0 < eq) (h15 : 2 ^ V.pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ V.pub.epLogN + eq ≤ 2 ^ 15) :
    (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nA = 3
      ∧ (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nH = 4
      ∧ (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nIn = 1
      ∧ (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nOut = 1 :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- **The repaired `RtInc` at L29's `incVAt` itself** (the verifier L29 checked against the code's corpus). -/
def rcIncAt {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Block.Dim)
    (lr elr q eq total : ℕ) (hq : 0 < q) (heq : 0 < eq) (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15)
    (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) :
    RtInc Lq (fun _ : Hdr => incVAt tag pub geo blk ed lr elr q eq)
      (fun _ => rcIncGeom (incVAt tag pub geo blk ed lr elr q eq) total)
      (rcIncPart (incVAt tag pub geo blk ed lr elr q eq) q eq) :=
  rcIncOf Lq hL20 (incVAt tag pub geo blk ed lr elr q eq) tag lr elr q eq total rfl (fun _ _ _ _ _ => rfl)
    (fun _ _ _ _ _ => rfl) (fun _ _ _ _ _ => rfl) hq heq h15 he15

/-- **STAGE IN-C'S CONTRACT AT THE REAL STAGE** (`rtInc_holds` at `rcIncAt`): stage IN-C of
`classifyRunV … (fun _ => incVAt …) (fun _ => rcIncGeom …) …` moves the transcript by exactly its steps whenever its
framed step accepts, and leaves exactly one claim pending on `B_in`. No premise beyond the tier's numbers. -/
theorem rcIncAt_holds {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (pub : IncPub) (geo : IncGeo)
    (blk ed : Block.Dim) (lr elr q eq total : ℕ) (hq : 0 < q) (heq : 0 < eq) (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15)
    (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15) (cx0 : IncCtx) :
    (rtIncSeg (fun _ : Hdr => incVAt tag pub geo blk ed lr elr q eq)
      (fun _ => rcIncGeom (incVAt tag pub geo blk ed lr elr q eq) total) cx0
      (rcIncPart (incVAt tag pub geo blk ed lr elr q eq) q eq)).Holds Lq (fun _ => True)
      (fun cr => cr.pending.length = 1) :=
  rtInc_holds _ _ cx0 Lq hL20 _ (rcIncAt Lq hL20 tag pub geo blk ed lr elr q eq total hq heq h15 he15)

/-! ## Stage OUT-C's contract at the real verifier -/

/-- **Stage OUT-C's segment geometry**, as L29's corpus checker builds it (`gOut`): no `B` root, ONE closed commitment
(`B_out`: its `Dim`, one group per site, its rows), index `total − 1`. -/
def rcOutcGeom (V : OutcV) (total : ℕ) : StageGeom :=
  ⟨magicOut, V.geom, false, [(V.bd, V.geo.bSites, V.geo.bRows)], total, total - 1⟩

/-- **Stage OUT-C's profile counts** at `pend` claims pending on `B_out` before it. -/
def rcOutcPart (V : OutcV) (q bq pend : ℕ) : RtPart :=
  ⟨11 + shapeLen V.bp 0 V.geom.slots, 2 + shapeSq V.bp 0 V.geom.slots, 8, 29 + V.lay.aRows, outcAGroups, (q + 3) / 4,
    10 + V.lay.hRows, outcHGroups, (q + 3) / 4, pend + 1 + V.geo.bRows, V.geo.bSites, (bq + 3) / 4⟩

/-- The statement's verdict in OUT-C's public data. -/
def rcVerdict (O : OutcPub) (v : ℕ) : OutcPub := { O with verdict := v }

/-- The verdict changes neither the layout nor the draws. -/
theorem rc_outcLay_verdict (O : OutcPub) (b v : ℕ) : outcLay (rcVerdict O v) b = outcLay O b := rfl

theorem rc_outcDraws_verdict (O : OutcPub) (v : ℕ) : outcDraws (rcVerdict O v) = outcDraws O := rfl

theorem rc_outcBp_draws (V : OutcV) : V.bp.draws = outcDraws V.pub := rfl

theorem rc_outcV_geom (tag : MTag) (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx lr blr q bq v : ℕ) :
    (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).geom = (outcVAt tag O geo blk bd idx lr blr q bq).geom := by
  show mGeom (outcLay (rcVerdict O v) geo.bLogN) blk outcAGroups outcHGroups
    = mGeom (outcLay O geo.bLogN) blk outcAGroups outcHGroups
  rw [rc_outcLay_verdict]

theorem rc_outcV_draws (tag : MTag) (O : OutcPub) (geo : OutcGeo) (blk bd : Block.Dim) (idx lr blr q bq v : ℕ) :
    (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).bp.draws
      = (outcVAt tag O geo blk bd idx lr blr q bq).bp.draws :=
  (rc_outcBp_draws (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq)).trans
    ((rc_outcDraws_verdict O v).trans (rc_outcBp_draws (outcVAt tag O geo blk bd idx lr blr q bq)).symm)

/-- **THE REPAIRED `RtOutc`, BUILT** at L29's `outcVAt` with the statement's verdict (`rcVerdict O v`), for every
header and verdict: `M` is `maskField tag 8`, `A`, `H`, `B_out` are `pcsAt`; claim counts `29, 10, 1`. -/
def rcOutcAt {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (O : OutcPub) (geo : OutcGeo)
    (blk bd : Block.Dim) (idx lr blr q bq total pend : ℕ) (hq : 0 < q) (hbq : 0 < bq) (h15 : 2 ^ O.lt + q ≤ 2 ^ 15)
    (hb15 : 2 ^ geo.bLogN + bq ≤ 2 ^ 15) :
    RtOutc Lq (fun (_ : Hdr) v => outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq)
      (fun _ => rcOutcGeom (outcVAt tag O geo blk bd idx lr blr q bq) total)
      (rcOutcPart (outcVAt tag O geo blk bd idx lr blr q bq) q bq pend) where
  tag := tag
  nA := 29
  nH := 10
  nIn := 1
  pA := rcPcsAt _ tag O.lt lr q (outcLay O geo.bLogN).aRows (fun _ _ _ _ _ _ => rfl) hq h15
  pH := rcPcsAt _ tag O.lt lr q (outcLay O geo.bLogN).hRows (fun _ _ _ _ _ _ => rfl) hq h15
  pX := rcPcsAt _ tag geo.bLogN blr bq geo.bRows (fun _ _ _ _ _ _ => rfl) hbq hb15
  hPm := fun _ _ => rfl
  hgeo := fun _ v => (rc_outcV_geom tag O geo blk bd idx lr blr q bq v).symm
  hgt := fun _ v => rc_outcGeom_gt _
  hgeomL := fun _ v j hj => by
    obtain ⟨h1, h2, h3⟩ := rc_outcBounds (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq) j hj
    exact ⟨h1, by omega, by omega⟩
  hclose := fun _ => ⟨_, rfl, rfl⟩
  hcnt := fun _ v H core t ch recs acc t4 h hsh => by
    obtain ⟨hA, hH, hI, -⟩ := rc_outcSlots_counts H _ core t ch recs acc t4 h hsh
    exact ⟨hA, hH, hI⟩
  hpre := fun _ v => by
    show 11 + shapeLen (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).bp 0
        (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).geom.slots
      = 11 + shapeLen (outcVAt tag O geo blk bd idx lr blr q bq).bp 0 (outcVAt tag O geo blk bd idx lr blr q bq).geom.slots
    rw [rc_outcV_geom, rc_shapeLen_congr _ _ (rc_outcV_draws tag O geo blk bd idx lr blr q bq v)]
  hpsq := fun _ v => by
    show 2 + shapeSq (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).bp 0
        (outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq).geom.slots
      = 2 + shapeSq (outcVAt tag O geo blk bd idx lr blr q bq).bp 0 (outcVAt tag O geo blk bd idx lr blr q bq).geom.slots
    rw [rc_outcV_geom, rc_shapeSq_congr _ _ (rc_outcV_draws tag O geo blk bd idx lr blr q bq v)]
  hgA := fun _ _ => rfl
  hgH := fun _ _ => rfl
  hwA := rfl
  hmA := rfl
  hwH := rfl
  hmH := rfl
  hmX := rfl

/-- **STAGE OUT-C'S CONTRACT AT THE REAL STAGE** (`rtOutc_holds` at `rcOutcAt`): from a carry with `pend` claims
pending on `B_out`, stage OUT-C of `classifyRunV … (fun _ v => outcVAt … (rcVerdict O v) …) …` moves the transcript by
exactly its steps whenever its framed step accepts. No premise beyond the tier's numbers. -/
theorem rcOutcAt_holds {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (tag : MTag) (O : OutcPub) (geo : OutcGeo)
    (blk bd : Block.Dim) (idx lr blr q bq total pend : ℕ) (hq : 0 < q) (hbq : 0 < bq) (h15 : 2 ^ O.lt + q ≤ 2 ^ 15)
    (hb15 : 2 ^ geo.bLogN + bq ≤ 2 ^ 15) :
    (rtOutcSeg (fun (_ : Hdr) v => outcVAt tag (rcVerdict O v) geo blk bd idx lr blr q bq)
      (fun _ => rcOutcGeom (outcVAt tag O geo blk bd idx lr blr q bq) total)
      (rcOutcPart (outcVAt tag O geo blk bd idx lr blr q bq) q bq pend)).Holds Lq
      (fun cr => cr.pending.length = pend) (fun _ => True) :=
  rtOutc_holds _ _ Lq hL20 _ (rcOutcAt Lq hL20 tag O geo blk bd idx lr blr q bq total pend hq hbq h15 hb15) pend rfl

/-! ## The run's schedule at the real stages -/

/-- **THE CLASSIFY RUN'S SCHEDULE AT THE REAL STAGES** (L34's `rtRunClassify`, with stage IN-C's and stage OUT-C's
contracts BUILT at L29's `incVAt` and `outcVAt`, the segment geometries L29's checker uses, `L + 2` segments). The
premises `I : RtInc` and `O : RtOutc` of `rtRunClassify` are gone; what is left is the run header's operations
(`hstart`, `hhdr`), the tier's numbers, and the blocks' contracts (`bp`, `pX`, `gX`, `hgeo`, `hgX`, `hbp`) with the
pending claims' counts (`pend`, `hI`: stage IN-C leaves one claim on `B_in`). -/
noncomputable def rcRunClassifyAt {Hdr : Type} (L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (Pk : ℕ → Block.BlockParams) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Block.Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (key : Option Dig) (domain : List UInt8) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (hdr : ClsStmt Hdr → List Op) (hdrLen hdrSq : ℕ)
    (hstart : ∀ (H : HIn → Dig) (s : ClsStmt Hdr), start H s = runOps H (Tr.newKeyed H domain key) (hdr s))
    (hhdr : ∀ s : ClsStmt Hdr, preA s.hdr = .ok () → preB s.hdr = .ok () →
      (hdr s).length = hdrLen ∧ sqN (hdr s) = hdrSq ∧ ∀ op ∈ hdr s, op.len ≤ Lq)
    (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Block.Dim) (lr elr q eq : ℕ) (hq : 0 < q) (heq : 0 < eq)
    (h15 : 2 ^ pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ pub.epLogN + eq ≤ 2 ^ 15)
    (O : OutcPub) (ogeo : OutcGeo) (oblk bd : Block.Dim) (idx olr blr oq bq : ℕ) (hoq : 0 < oq) (hbq : 0 < bq)
    (ho15 : 2 ^ O.lt + oq ≤ 2 ^ 15) (hb15 : 2 ^ ogeo.bLogN + bq ≤ 2 ^ 15)
    (cx0 : IncCtx) (pend : ℕ → ℕ) (hI : pend 1 = 1) (bp : ∀ k, RtBlk Lq (Pk k))
    (pX : ∀ k, RtPcs (fun (s : ClsStmt Hdr) H root cl o t => bndOpen H s k root cl o t)) (gX : ℕ → ℕ)
    (hgeo : ∀ k s, (sgeom s k).g = (Pk k).geom) (hgX : ∀ k s, (sgeom s k).incoming.1 = gX k)
    (hbp : ∀ k, (bp k).nOut = pend (k + 2)) :
    RtRun (classifyRunV L preA preB start (fun _ => incVAt tag pub geo blk ed lr elr q eq)
      (fun _ => rcIncGeom (incVAt tag pub geo blk ed lr elr q eq) (L + 2))
      (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)
      (fun _ v => outcVAt tag (rcVerdict O v) ogeo oblk bd idx olr blr oq bq)
      (fun _ => rcOutcGeom (outcVAt tag O ogeo oblk bd idx olr blr oq bq) (L + 2))) key domain Lq :=
  rtRunClassify L preA preB start _ _ _ _ Pk sgeom check paths digest bRows bLogN bndCheck bndOpen key domain Lq hL20
    hdr hdrLen hdrSq hstart hhdr cx0 _ _ (rcIncAt Lq hL20 tag pub geo blk ed lr elr q eq (L + 2) hq heq h15 he15)
    (rcOutcAt Lq hL20 tag O ogeo oblk bd idx olr blr oq bq (L + 2) (pend (L + 1)) hoq hbq ho15 hb15) pend hI.symm bp
    pX gX hgeo hgX hbp rfl

/-! ## The honest segments are accepted, inside the guard -/

theorem rc_checkTokenEp_len (H : HIn → Dig) (cl : List Block.ZClaim) (data n : ℕ) (t : Tr) (u : Unit)
    (h : checkTokenEp H cl data n t = .ok u) : cl.length = 1 := by
  match cl, h with
  | [_], _ => rfl
  | [], h => exact absurd h (by simp [checkTokenEp])
  | _ :: _ :: _, h => exact absurd h (by simp [checkTokenEp])

theorem rc_stSlotsProve_length (H : HIn → Dig) (P : Block.BlockParams) (elog : ℕ → ℕ)
    (D : HonestClassify.SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List Block.SlotRec) (s : ℕ) (acc : Block.Acc) (t : Tr) (sps : List Block.SlotProof)
      (recs' : List Block.SlotRec) (acc' : Block.Acc) (t' : Tr),
      stSlotsProve H P elog D b g a m recs s acc t = .ok (sps, recs', acc', t') → sps.length = m
  | 0, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [stSlotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, -⟩ := h
        rw [List.length_cons, rc_stSlotsProve_length H P elog D b g a m _ _ _ _ sps₁ recs₁ acc₂ t₂ hrest]

theorem rc_slotsProve_length (H : HIn → Dig) (P : Block.BlockParams) (D : HonestClassify.SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List Block.SlotRec) (s : ℕ) (acc : Block.Acc) (t : Tr) (sps : List Block.SlotProof)
      (recs' : List Block.SlotRec) (acc' : Block.Acc) (t' : Tr),
      HonestClassify.slotsProve H P D b g a m recs s acc t = .ok (sps, recs', acc', t') → sps.length = m
  | 0, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [HonestClassify.slotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, -⟩ := h
    rfl
  | m + 1, recs, s, acc, t, sps, recs', acc', t', h => by
    simp only [HonestClassify.slotsProve] at h
    split at h
    · cases h
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · cases h
      · rename_i sps₁ recs₁ acc₂ t₂ hrest
        simp only [Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, -⟩ := h
        rw [List.length_cons, rc_slotsProve_length H P D b g a m _ _ _ _ sps₁ recs₁ acc₂ t₂ hrest]

/-- **Stage IN-C's honest segment, inside the guard**: whenever L29's honest IN-C prover returns a run and the stage
verifier accepts its segment, the segment's core has the geometry's slot count (so the repaired `hcnt` applies to it),
it leaves exactly ONE claim on `B_in` (the contract's `nOut`) and exactly ONE claim on the input endpoint (`nIn`). -/
theorem rcInc_honest (H : HIn → Dig) (V : IncV) (D : IncData V) (epRoot : Dig) (t : Tr) (R : IncRun)
    (h : incProve H V D t = .ok R) (hacc : V.verify H epRoot R.seg t = .ok ((R.acc.claims.out, D.bRoot), R.t8)) :
    R.seg.core.slots.length = V.geom.slots.length ∧ R.acc.claims.out.length = 1 ∧ R.acc.claims.inp.length = 1 := by
  obtain ⟨-, -, -, hs, -, -, -, hcE, -⟩ := incProve_ok H V D t R h
  have hlen : R.seg.core.slots.length = V.geom.slots.length :=
    (rc_stSlotsProve_length H _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ hs).trans rfl
  obtain ⟨-, -, -, -, -, -, recs, acc, t4, -, -, -, hsl, -, -, -, -, -, -, -, -, hpend⟩ :=
    (incVerify_ok_iff H V epRoot R.seg t _ _ _).mp hacc
  obtain ⟨-, -, -, hO⟩ := rc_incSlots_counts H V R.seg.core _ recs acc t4 hsl hlen
  refine ⟨hlen, ?_, rc_checkTokenEp_len H _ _ _ _ _ hcE⟩
  rw [hpend]
  exact hO

section Tables

open ZK60.HonestRun ZK60.HonestOpen ZK60.HonestClassify ZK60.Sound
open ZK60.Circuit (gP GF)

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **NON-VACUITY AT STAGE IN-C** (L32's `incVerify_of_tables` with the repaired contract): for a stage verifier whose
`M` and openings are `maskField` and `pcsAt` (as `incVAt`'s), the repaired `RtInc` is BUILT (`rcIncOf`, claim counts
`3, 4, 1, 1`), and, on L32's honest premises, the SAME verifier accepts the honest segment, whose core has the
geometry's slot count and which leaves exactly the contract's `nOut = 1` claim on `B_in` and `nIn = 1` on the
endpoint. So the repaired premise does not force a rejection (contrast the gap audit's `gap_rtInc_never_accepts`). -/
theorem rcInc_honest_tables {Hdr : Type} (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (total : ℕ) (V : IncV) (lr elr q eq : ℕ)
    (hVm : V.maskVerify = maskField tag 4)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.aRows cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root V.lay.hRows cl o t)
    (hVe : ∀ (H' : HIn → Dig) root cl o t, V.epVerify H' root cl o t
      = pcsAt tag V.pub.epLogN elr eq H' root V.geo.epRows cl o t)
    (hk : V.pub.lt + lr ≤ 31) (hq : 0 < q) (hke : V.pub.epLogN + elr ≤ 31) (heq : 0 < eq)
    (h15 : 2 ^ V.pub.lt + q ≤ 2 ^ 15) (he15 : 2 ^ V.pub.epLogN + eq ≤ 2 ^ 15)
    (hdB : V.blk.path = V.pub.lt + lr) (hdE : V.ed.path = V.pub.epLogN + elr) (C : IncTables V) (t : Tr)
    (R : IncRun) (h : incProve H V (incDataAt H tag U hbij V lr elr q eq C t) t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD (V.bp (incCtx V.pub R.ch)) s ∧ slotD (V.bp (incCtx V.pub R.ch)) s < gP)
    (hslots : StSlotsSum H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) U (C.slot R.ch) Fp2.zero Fp2.zero
      Fp2.zero V.lay.ns [] 0 {} R.t3)
    (hMh : MHonest U (algebraMap GF K (rootFp 9).toGF) C.M 4)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK U
        = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U ((R.acc.fs ++ R.acc.hostFs).map toMF) 4) (mA U C.M 4) i)
    (hrA : V.lay.aRows = C.TA.rows.length)
    (hcA : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue U (2 ^ V.pub.lt) V.pub.lt C.TA.rows (toZClaim c))
    (hrH : V.lay.hRows = (C.TH R.ch).rows.length)
    (hcH : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr)
      (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue U (2 ^ V.pub.lt) V.pub.lt (C.TH R.ch).rows (toZClaim c))
    (hrE : V.geo.epRows = C.TE.rows.length)
    (hcE : ColsHonest U (lagK V.pub.epLogN (by omega)) eq (cosetPt (rootFp (V.pub.epLogN + elr)))
      (2 ^ V.pub.epLogN * 2 ^ elr) C.TE)
    (htE : ∀ c ∈ R.acc.claims.inp, ClaimTrue U (2 ^ V.pub.epLogN) V.pub.epLogN C.TE.rows (toZClaim c)) :
    V.verify H (rootOf H tag (V.pub.epLogN + elr) C.TE) R.seg t = .ok ((R.acc.claims.out, C.bRoot), R.t8)
      ∧ R.seg.core.slots.length = V.geom.slots.length
      ∧ R.acc.claims.out.length
        = (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nOut
      ∧ R.acc.claims.inp.length
        = (rcIncOf (Hdr := Hdr) Lq hL20 V tag lr elr q eq total hVm hVa hVh hVe hq heq h15 he15).nIn := by
  have hacc := incVerify_of_tables H tag U hbij hU V lr elr q eq hVm hVa hVh hVe hk hq hke heq hdB hdE C t R h hdeg
    hslots hMh hMt hrA hcA htA hrH hcH htH hrE hcE htE
  obtain ⟨hl, hO, hI⟩ := rcInc_honest H V (incDataAt H tag U hbij V lr elr q eq C t) _ t R h hacc
  exact ⟨hacc, hl, hO, hI⟩

end Tables

/-- **Stage OUT-C's honest segment, inside the guard**: whenever L29's honest OUT-C prover returns a run and the stage
verifier accepts its segment, the segment's core has the geometry's slot count, and the accepted slot phase has the
contract's counts (29, 10, 1) with no output claim. -/
theorem rcOutc_honest (H : HIn → Dig) (V : OutcV) (D : OutcData V) (cr : Carry) (t t' : Tr) (R : OutcRun)
    (h : outcProve H V D cr t = .ok R) (hacc : V.verify H cr.root cr.pending R.seg t = .ok t') :
    R.seg.core.slots.length = V.geom.slots.length
      ∧ ∃ (ch : List Fp2) (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr),
        StageFS.stageSlots H V.bp 2 OutcV.bga R.seg.core (V.frame H t) = .ok (ch, recs, acc, t4)
        ∧ acc.claims.a.length = 29 ∧ (acc.claims.h ++ [V.lay.logupSumClaim]).length = 10
        ∧ acc.claims.inp.length = 1 ∧ acc.claims.out = [] := by
  obtain ⟨-, -, -, -, hs, -⟩ := outcProve_ok H V D cr t R h
  have hlen : R.seg.core.slots.length = V.geom.slots.length :=
    (rc_slotsProve_length H _ _ _ _ _ _ _ _ _ _ _ _ _ _ hs).trans rfl
  obtain ⟨-, -, -, -, -, -, ch, recs, acc, t4, -, -, -, hsl, -, -, hout, -⟩ :=
    (outcVerify_ok_iff H V cr.root cr.pending R.seg t t').mp hacc
  obtain ⟨hA, hH, hI, -⟩ := rc_outcSlots_counts H V R.seg.core _ ch recs acc t4 hsl hlen
  exact ⟨hlen, ch, recs, acc, t4, hsl, hA, hH, hI, hout⟩

section TablesOut

open ZK60.HonestRun ZK60.HonestOpen ZK60.HonestClassify ZK60.Sound
open ZK60.Circuit (gP GF)

variable (H : HIn → Dig) (tag : MTag) {K : Type} [Field K] [Algebra GF K] (U : K)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (hU : U ^ 2 = algebraMap GF K 7)

include hU in
/-- **NON-VACUITY AT STAGE OUT-C** (L32's `outcVerify_of_tables` with the repaired contract): on L32's honest
premises the stage verifier accepts the honest segment on the honest carry, the segment's core has the geometry's slot
count, and the accepted slot phase has exactly the repaired contract's counts (`A` 29, `H` 10, `B_out` 1). -/
theorem rcOutc_honest_tables (V : OutcV) (lr blr q bq rowsA rowsH : ℕ) (hVm : V.maskVerify = maskField tag 8)
    (hVa : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.a root cl o t
      = pcsAt tag V.pub.lt lr q H' root rowsA cl o t)
    (hVh : ∀ (H' : HIn → Dig) root cl o t, V.pcsVerify H' Block.Cm.h root cl o t
      = pcsAt tag V.pub.lt lr q H' root rowsH cl o t)
    (hVb : ∀ (H' : HIn → Dig) root cl o t, V.bVerify H' root cl o t
      = pcsAt tag V.geo.bLogN blr bq H' root V.geo.bRows cl o t)
    (hk : V.pub.lt + lr ≤ 31) (hq : 0 < q) (hkb : V.geo.bLogN + blr ≤ 31) (hbq : 0 < bq)
    (hdB : V.blk.path = V.pub.lt + lr) (hdD : V.bd.path = V.geo.bLogN + blr) (C : OutcTables V) (cr : Carry)
    (t : Tr) (R : OutcRun) (h : outcProve H V (outcDataAt H tag U hbij V lr blr q bq C t) cr t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD V.bp s ∧ slotD V.bp s < gP)
    (hslots : SlotsSum H V.bp U C.slot (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 V.lay.ns [] 0 {}
      R.t3)
    (hMh : MHonest U (algebraMap GF K (rootFp 9).toGF) C.M 8)
    (hMt : ∀ i : Fin ((R.acc.fs ++ R.acc.hostFs).map toMF).length,
      (((R.acc.fs ++ R.acc.hostFs).map toMF).get i).value.toK U
        = mTrue (algebraMap GF K (rootFp 9).toGF) (wtOf U ((R.acc.fs ++ R.acc.hostFs).map toMF) 8) (mA U C.M 8) i)
    (hrA : rowsA = C.TA.rows.length)
    (hcA : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr) C.TA)
    (htA : ∀ c ∈ R.acc.claims.a, ClaimTrue U (2 ^ V.pub.lt) V.pub.lt C.TA.rows (toZClaim c))
    (hrH : rowsH = (C.TH R.ch).rows.length)
    (hcH : ColsHonest U (lagK V.pub.lt (by omega)) q (cosetPt (rootFp (V.pub.lt + lr))) (2 ^ V.pub.lt * 2 ^ lr)
      (C.TH R.ch))
    (htH : ∀ c ∈ R.acc.claims.h ++ [V.lay.logupSumClaim],
      ClaimTrue U (2 ^ V.pub.lt) V.pub.lt (C.TH R.ch).rows (toZClaim c))
    (hrB : V.geo.bRows = C.TB.rows.length)
    (hcB : ColsHonest U (lagK V.geo.bLogN (by omega)) bq (cosetPt (rootFp (V.geo.bLogN + blr)))
      (2 ^ V.geo.bLogN * 2 ^ blr) C.TB)
    (htB : ∀ c ∈ cr.pending ++ R.acc.claims.inp, ClaimTrue U (2 ^ V.geo.bLogN) V.geo.bLogN C.TB.rows (toZClaim c)) :
    V.verify H cr.root cr.pending R.seg t = .ok R.t8
      ∧ R.seg.core.slots.length = V.geom.slots.length
      ∧ ∃ (ch : List Fp2) (recs : List Block.SlotRec) (acc : Block.Acc) (t4 : Tr),
        StageFS.stageSlots H V.bp 2 OutcV.bga R.seg.core (V.frame H t) = .ok (ch, recs, acc, t4)
        ∧ acc.claims.a.length = 29 ∧ (acc.claims.h ++ [V.lay.logupSumClaim]).length = 10
        ∧ acc.claims.inp.length = 1 ∧ acc.claims.out = [] := by
  have hacc := outcVerify_of_tables H tag U hbij hU V lr blr q bq rowsA rowsH hVm hVa hVh hVb hk hq hkb hbq hdB hdD C cr
    t R h hdeg hslots hMh hMt hrA hcA htA hrH hcH htH hrB hcB htB
  exact ⟨hacc, rcOutc_honest H V (outcDataAt H tag U hbij V lr blr q bq C t) cr t R.t8 R h hacc⟩

end TablesOut

end ZK60.ProtocolClassify
