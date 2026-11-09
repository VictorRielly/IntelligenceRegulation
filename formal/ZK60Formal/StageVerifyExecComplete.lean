/-
D63 Lean lane L29 (2026-11-07), part 5: **the stages' honest provers and their completeness against the executable
stage verifiers** (lane L25's `StageInOK` / `StageOutOK`, obligation O8's stage part).

The code (hashline, read 2026-11-07; nothing there is changed): `stage_in_c::prove` (:282-395) and
`stage_out_c::prove` (:517-653). The prover and the verifier share the transcript and the slot routine
(`run_stage_slot`'s two sides): the prover makes EXACTLY the verifier's absorbs and squeezes:
* IN-C: `pb-run-stage 0`, `pb-run-block`, `absorb_root("B", B_in)`, `absorb_root("A")`, `absorb("M")`, `β, γ, α,
  r_emb`; D66(3)'s refusal ("zero LogUp denominator; discard attempt" when `α` is an entry of the table `τ`, which is a
  function of `r_emb`: finding L29-3); `absorb_root("H")`; the four slots; `M`'s opening; `check_opening` and the
  opening of `A`, of `H`; `check_token_endpoint_opening` and the endpoint's opening;
* OUT-C: `pb-run-stage L + 1`, `pb-run-block`, `A`, `M`, `γ, α`; D66(3)'s refusal (`α` an entry `z + g_u8` of the byte
  table); `H`; the eight slots; `M`; no claim on an output endpoint; `A`; `H`; `b_owner.into_opening` (the boundary
  audit `boundary::check_opening`, then the opening of `B_out` on the pending claims followed by OUTC-00's). The
  prover opens the boundary IT owns, so (finding L25-1) the Lean prover checks the carry is its own (`own`).
Every other refusal of the code's provers (the helpers' `inv_or_refuse`, `helper_col`'s zero denominators) cannot fire
once D66(3) has passed on an admissible witness (stage_in_c.rs:326-331, stage_out_c.rs:579-584, the code's own
argument); the witness shape and byte-class refusals are the sealing pass's (before any header).

Proved (every premise a hypothesis):
* `sdAt`, `stSlotsProve`, `StSlotsSum`, **`stSlotsLoop_of_prove`**: the stage's honest slot loop at each slot's IO row
  width, accepted by the stage's slot loop (lane L25's `slotStep_of_prove`, slot by slot);
* `IncData`, `IncRun`, **`incProve`**, `incProve_ok`, **`incVerify_of_prove`**: stage IN-C's honest prover and the
  executable verifier's acceptance of its segment, from the slots' arithmetic and the openings' completeness;
* `OutcData`, `OutcRun`, **`outcProve`**, `outcProve_ok`, **`outcVerify_of_prove`**: the same for stage OUT-C on its own
  carry;
* `incP`, `IncOK`, **`inc_stageInOK`**; `outcP`, `OutcOK`, **`outc_stageOutOK`**: lane L25's `StageInOK` /
  `StageOutOK` for the executable stages, from the codec (`decodeStage_enc`) and the verifier contracts;
* **`incProve_refuses`**, **`outcProve_refuses`**: the stage provers refuse ONLY at D66(3), a slot's refusal
  (`slotProve_refuses`), the functional count, a `check_opening` (and IN-C's endpoint audit, OUT-C's boundary audit),
  OUT-C's output-claim check, or OUT-C's carry not being its own.
-/
import ZK60Formal.StageVerifyExec
import ZK60Formal.HonestClassifyRun

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60 ZK60.ProtocolClassify ZK60.HonestClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (Core SlotProof Dim Geom BlockParams Hist SlotRec Acc slotsLoop slotStep histOf absorbRoot pathsDepth
  labA labH labM posTag CoreCanon CoreShape Cm)

/-! ## The stage's honest slot loop -/

/-- The slot data at the IO row width `e` (the same data; only the claims' row width moves). -/
def sdAt {P : BlockParams} (D : SlotData P) (e : ℕ) : SlotData (atLog P e) := ⟨D.scalar, D.strat, D.terms⟩

section Loop

variable (H : HIn → Dig) (P : BlockParams) (elog : ℕ → ℕ)

/-- **The stage's honest slot loop** (`run_slots`, the prover's side): each slot at its own IO row width. -/
def stSlotsProve (D : SlotData P) (b g a : Fp2) :
    ℕ → List SlotRec → ℕ → Acc → Tr → Except Unit (List SlotProof × List SlotRec × Acc × Tr)
  | 0, recs, _, acc, t => .ok ([], recs, acc, t)
  | m + 1, recs, s, acc, t =>
    match slotProve H (atLog P (elog s)) (sdAt D (elog s)) s (histOf b g a recs) acc t with
    | .error _ => .error ()
    | .ok (sp, r, acc', t') =>
      match stSlotsProve D b g a m (recs ++ [r]) (s + 1) acc' t' with
      | .error _ => .error ()
      | .ok (sps, recs', acc'', t'') => .ok (sp :: sps, recs', acc'', t'')

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The slots' arithmetic along the stage's honest run** (L25's `SlotSum`, slot by slot at the slot's width). -/
def StSlotsSum (D : SlotData P) (b g a : Fp2) : ℕ → List SlotRec → ℕ → Acc → Tr → Prop
  | 0, _, _, _, _ => True
  | m + 1, recs, s, acc, t =>
    (∀ df, P.define s (histOf b g a recs) (t.challengeFp2Vec H (P.draws s)).1 = .ok df →
        SlotSum (atLog P (elog s)) U (sdAt D (elog s)) s (histOf b g a recs) acc df (slotC H (atLog P (elog s)) s t))
      ∧ ∀ sp r acc' t', slotProve H (atLog P (elog s)) (sdAt D (elog s)) s (histOf b g a recs) acc t = .ok (sp, r, acc', t') →
        StSlotsSum D b g a m (recs ++ [r]) (s + 1) acc' t'

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The stage's slot loop accepts the honest slots** and lands on the prover's records, accumulator and transcript. -/
theorem stSlotsLoop_of_prove (D : SlotData P) (b g a : Fp2) (hdeg : ∀ s, 1 ≤ slotD P s ∧ slotD P s < gP) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr) (sps : List SlotProof) (recs' : List SlotRec)
      (acc' : Acc) (t' : Tr), StSlotsSum H P elog U D b g a m recs s acc t →
      stSlotsProve H P elog D b g a m recs s acc t = .ok (sps, recs', acc', t') →
      stSlotsLoop H P elog b g a recs s sps acc t = .ok (recs', acc', t')
  | 0, recs, s, acc, t, sps, recs', acc', t', _, h => by
    simp only [stSlotsProve, Except.ok.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl, rfl, rfl⟩ := h
    rfl
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
        have hstep := slotStep_of_prove H (atLog P (elog s)) U hU (sdAt D (elog s)) s (histOf b g a recs) acc t sp r
          acc₁ t₁ (hdeg s).1 (hdeg s).2 hs1 hsp
        simp only [stSlotsLoop, hstep]
        exact stSlotsLoop_of_prove D b g a hdeg m (recs ++ [r]) (s + 1) acc₁ t₁ sps₁ recs₁ acc₂ t₂
          (hs2 sp r acc₁ t₁ hsp) hrest

omit hU in
/-- **The stage's honest slot loop refuses only where one of its slots refuses**, at that slot's own state and width. -/
theorem stSlotsProve_refuses (D : SlotData P) (b g a : Fp2) :
    ∀ (m : ℕ) (recs : List SlotRec) (s : ℕ) (acc : Acc) (t : Tr),
      stSlotsProve H P elog D b g a m recs s acc t = .error () →
      ∃ (i : ℕ) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < m
        ∧ slotProve H (atLog P (elog (s + i))) (sdAt D (elog (s + i))) (s + i) (histOf b g a recs₁) acc₁ t₁ = .error ()
  | 0, _, _, _, _, h => by cases h
  | m + 1, recs, s, acc, t, h => by
    simp only [stSlotsProve] at h
    split at h
    · rename_i e he
      cases e
      exact ⟨0, recs, acc, t, by omega, by simpa using he⟩
    · rename_i sp r acc₁ t₁ hsp
      split at h
      · rename_i e he
        cases e
        obtain ⟨i, recs₂, acc₂, t₂, hi, hr⟩ := stSlotsProve_refuses D b g a m (recs ++ [r]) (s + 1) acc₁ t₁ he
        exact ⟨i + 1, recs₂, acc₂, t₂, by omega, by rw [show s + (i + 1) = s + 1 + i by omega]; exact hr⟩
      · cases h

end Loop

/-! ## Stage IN-C's honest prover -/

/-- **Stage IN-C's honest data** (`stage_in_c::prove`): `B_in`'s, `A`'s and `M`'s roots (committed before any
challenge), `H`'s root as a function of the head's challenges (the LogUp helpers), the slots' data at the head's
context, and the openings' honest provers (`zk::mask_open`, `pcs::open_zk` of `A`, `H` and the input endpoint: each
returns the opening and the transcript after it). -/
structure IncData (V : IncV) where
  bRoot : Dig
  aRoot : Dig
  maskRoot : Dig
  hRoot : List Fp2 → Dig
  slot : (ch : List Fp2) → SlotData (V.bp (incCtx V.pub ch))
  mOpen : List Block.MaskFunctional → Tr → Block.MaskOpening × Tr
  aOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr
  hOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr
  epOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr

/-- **What the honest IN-C prover computed**: the segment, the head's challenges, the slot records and accumulator, and
the transcript before the slots, after them, after `M`, `A`, `H` and the endpoint. -/
structure IncRun where
  seg : StageSeg
  ch : List Fp2
  recs : List SlotRec
  acc : Acc
  t3 : Tr
  t4 : Tr
  t5 : Tr
  t6 : Tr
  t7 : Tr
  t8 : Tr

section InC

variable (H : HIn → Dig) (V : IncV)

/-- The head's challenges of the honest prover (the verifier's, at the honest roots). -/
def incCh (D : IncData V) (t : Tr) : List Fp2 × Tr :=
  ((absorbRoot H (V.frame H D.bRoot t) labA D.aRoot V.lay.aRows V.lay.logN).absorb H labM D.maskRoot.toList).challengeFp2Vec
    H (incHeadDraws V.pub)

/-- D66(3)'s refusal: `α` is an entry of the table `τ` (stage_in_c.rs:329). -/
def incAlphaBad (cx : IncCtx) : Bool := cx.tauTab.any (fun x => (cx.alpha.sub x).isZero)

/-- **Stage IN-C's honest prover** (`stage_in_c::prove`, from its frame on). `.error ()` is a refusal. -/
def incProve (D : IncData V) (t : Tr) : Except Unit IncRun :=
  if incAlphaBad (incCtx V.pub (incCh H V D t).1) = true then .error ()
  else
    match stSlotsProve H (V.bp (incCtx V.pub (incCh H V D t).1)) (incElog V.pub V.geo.bLogN) (D.slot (incCh H V D t).1)
        Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {}
        (absorbRoot H (incCh H V D t).2 labH (D.hRoot (incCh H V D t).1) V.lay.hRows V.lay.logN) with
    | .error _ => .error ()
    | .ok (sps, recs, acc, t4) =>
      if (acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals then .error ()
      else
        match V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | .error _ => .error ()
        | .ok _ =>
          match V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | .error _ => .error ()
          | .ok _ =>
            match checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | .error _ => .error ()
            | .ok _ =>
              .ok ⟨⟨some D.bRoot, ⟨D.aRoot, D.hRoot (incCh H V D t).1, D.maskRoot, sps,
                    (D.mOpen (acc.fs ++ acc.hostFs) t4).1,
                    (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).1,
                    (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).1⟩,
                  [(D.epOpen acc.claims.inp (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2).1]⟩,
                (incCh H V D t).1, recs, acc,
                absorbRoot H (incCh H V D t).2 labH (D.hRoot (incCh H V D t).1) V.lay.hRows V.lay.logN, t4,
                (D.mOpen (acc.fs ++ acc.hostFs) t4).2, (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2,
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2,
                (D.epOpen acc.claims.inp (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2).2⟩

/-- **The honest IN-C run's facts.** -/
theorem incProve_ok (D : IncData V) (t : Tr) (R : IncRun) (h : incProve H V D t = .ok R) :
    incAlphaBad (incCtx V.pub R.ch) = false
      ∧ R.ch = (incCh H V D t).1
      ∧ R.t3 = absorbRoot H (incCh H V D t).2 labH (D.hRoot (incCh H V D t).1) V.lay.hRows V.lay.logN
      ∧ stSlotsProve H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) (D.slot R.ch) Fp2.zero Fp2.zero Fp2.zero
          V.lay.ns [] 0 {} R.t3 = .ok (R.seg.core.slots, R.recs, R.acc, R.t4)
      ∧ (R.acc.fs ++ R.acc.hostFs).length = V.lay.nFunctionals
      ∧ V.checkOpening H .a R.acc.claims.a R.t5 = .ok ()
      ∧ V.checkOpening H .h (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 = .ok ()
      ∧ checkTokenEp H R.acc.claims.inp V.geo.epDataRows V.pub.epN R.t7 = .ok ()
      ∧ R.seg.bRoot = some D.bRoot ∧ R.seg.core.aRoot = D.aRoot ∧ R.seg.core.maskRoot = D.maskRoot
      ∧ R.seg.core.hRoot = D.hRoot R.ch
      ∧ (R.seg.core.maskOpen, R.t5) = D.mOpen (R.acc.fs ++ R.acc.hostFs) R.t4
      ∧ (R.seg.core.aOpen, R.t6) = D.aOpen R.acc.claims.a R.t5
      ∧ (R.seg.core.hOpen, R.t7) = D.hOpen (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6
      ∧ R.seg.closes = [(D.epOpen R.acc.claims.inp R.t7).1] ∧ R.t8 = (D.epOpen R.acc.claims.inp R.t7).2 := by
  unfold incProve at h
  split_ifs at h with hbad
  split at h
  · cases h
  · rename_i sps recs acc t4 hs
    split_ifs at h with hfs
    cases hA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
    | error e => simp [hA] at h
    | ok u1 =>
      cases hH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
          (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
      | error e => simp [hA, hH] at h
      | ok u2 =>
        cases hE : checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
            (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
        | error e => simp [hA, hH, hE] at h
        | ok u3 =>
          simp only [hA, hH, hE, Except.ok.injEq] at h
          subst h
          cases u1
          cases u2
          cases u3
          exact ⟨ff_of_not hbad, rfl, rfl, hs, not_not.mp hfs, hA, hH, hE, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **`stage_in_c::verify` accepts the honest segment** (completeness of the executable IN-C verifier): given the
honest run `R` (the prover did not refuse), the honest openings' path depths (T-4), the slots' arithmetic along the
run (`StSlotsSum`), and the completeness of `M`'s test and of the three openings on the run's own functionals and
claims (L10's components), the verifier returns the claims left on `B_in`, `B_in`'s root and the prover's final
transcript. -/
theorem incVerify_of_prove (D : IncData V) (epRoot : Dig) (t : Tr) (R : IncRun) (h : incProve H V D t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD (V.bp (incCtx V.pub R.ch)) s ∧ slotD (V.bp (incCtx V.pub R.ch)) s < gP)
    (hpA : pathsDepth "stage IN-C A" V.blk.path 0 R.seg.core.aOpen.columns = .ok ())
    (hpH : pathsDepth "stage IN-C H" V.blk.path 0 R.seg.core.hOpen.columns = .ok ())
    (hpM : pathsDepth "M" Block.W16R2.maskPath 0 R.seg.core.maskOpen.columns = .ok ())
    (hpE : pathsDepth "input token endpoint" V.ed.path 0 (R.seg.closes.headD IncV.ozk0).columns = .ok ())
    (hslots : StSlotsSum H (V.bp (incCtx V.pub R.ch)) (incElog V.pub V.geo.bLogN) U (D.slot R.ch) Fp2.zero Fp2.zero
      Fp2.zero V.lay.ns [] 0 {} R.t3)
    (hM : V.maskVerify H D.maskRoot (R.acc.fs ++ R.acc.hostFs) R.seg.core.maskOpen R.t4 = .ok R.t5)
    (hA : V.pcsVerify H .a D.aRoot R.acc.claims.a R.seg.core.aOpen R.t5 = .ok R.t6)
    (hH : V.pcsVerify H .h (D.hRoot R.ch) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.seg.core.hOpen R.t6 = .ok R.t7)
    (hE : V.epVerify H epRoot R.acc.claims.inp (R.seg.closes.headD IncV.ozk0) R.t7 = .ok R.t8) :
    V.verify H epRoot R.seg t = .ok ((R.acc.claims.out, D.bRoot), R.t8) := by
  obtain ⟨-, hch, ht3, hs, hfs, hcA, hcH, hcE, hbr, haR, hmR, hhR, -, -, -, hcl, -⟩ := incProve_ok H V D t R h
  have hloop := stSlotsLoop_of_prove H _ _ U hU _ _ _ _ hdeg _ _ _ _ _ _ _ _ _ hslots hs
  refine (incVerify_ok_iff H V epRoot R.seg t _ _ _).mpr ⟨by rw [hcl]; rfl, hpA, hpH, hpM, hpE, hbr, R.recs, R.acc, R.t4,
    R.t5, R.t6, R.t7, ?_, hfs, ?_, hcA, ?_, hcH, ?_, hcE, hE, rfl⟩
  · -- the slot phase on the honest roots is the prover's
    have e1 : V.headCh H R.seg.core (V.frame H D.bRoot t) = incCh H V D t := by
      simp only [IncV.headCh, IncV.headT, incCh, haR, hmR]
    have e2 : V.slotT H R.seg.core (V.frame H D.bRoot t) = R.t3 := by
      simp only [IncV.slotT, e1, hhR, hch, ht3]
    show stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H R.seg.core (V.frame H D.bRoot t)).1)) (incElog V.pub V.geo.bLogN)
      Fp2.zero Fp2.zero Fp2.zero [] 0 R.seg.core.slots {} (V.slotT H R.seg.core (V.frame H D.bRoot t))
        = .ok (R.recs, R.acc, R.t4)
    rw [e1, e2, ← hch]
    exact hloop
  · rw [hmR]
    exact hM
  · rw [haR]
    exact hA
  · rw [hhR]
    exact hH

end InC

/-! ## Stage OUT-C's honest prover -/

/-- **Stage OUT-C's honest data** (`stage_out_c::prove`): `A`'s and `M`'s roots, `H`'s root as a function of `γ, α`, the
slots' data, the openings' honest provers, the honest opening of the boundary the prover OWNS (`b_owner.into_opening`
after its audit), and the prover's check that the carry is its own (finding L25-1). -/
structure OutcData (V : OutcV) where
  aRoot : Dig
  maskRoot : Dig
  hRoot : List Fp2 → Dig
  slot : SlotData V.bp
  mOpen : List Block.MaskFunctional → Tr → Block.MaskOpening × Tr
  aOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr
  hOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr
  bOpen : List Block.ZClaim → Tr → Block.OpeningZk × Tr
  own : Carry → Bool

/-- **What the honest OUT-C prover computed.** -/
structure OutcRun where
  seg : StageSeg
  ch : List Fp2
  recs : List SlotRec
  acc : Acc
  t3 : Tr
  t4 : Tr
  t5 : Tr
  t6 : Tr
  t7 : Tr
  t8 : Tr

section OutC

variable (H : HIn → Dig) (V : OutcV)

/-- The head's `γ, α` of the honest prover. -/
def outcCh (D : OutcData V) (t : Tr) : List Fp2 × Tr :=
  ((absorbRoot H (V.frame H t) labA D.aRoot V.bp.aRows V.bp.logCols).absorb H labM D.maskRoot.toList).challengeFp2Vec H 2

/-- D66(3)'s refusal: `α` is an entry `z + g_u8` of the byte table (stage_out_c.rs:582). -/
def outcAlphaBad (ch : List Fp2) : Bool :=
  (List.range 256).any (fun z => ((ch.getD 1 Fp2.zero).sub ((kI z).add ((ch.getD 0 Fp2.zero).mulBase
    (Fp.new (UInt64.ofNat tagU8))))).isZero)

/-- **Stage OUT-C's honest prover** (`stage_out_c::prove`, from its frame on), on the carry it is handed. -/
def outcProve (D : OutcData V) (cr : Carry) (t : Tr) : Except Unit OutcRun :=
  if D.own cr = false then .error ()
  else if outcAlphaBad (outcCh H V D t).1 = true then .error ()
  else
    match slotsProve H V.bp D.slot (OutcV.bga (outcCh H V D t).1).1 (OutcV.bga (outcCh H V D t).1).2.1
        (OutcV.bga (outcCh H V D t).1).2.2 V.lay.ns [] 0 {}
        (absorbRoot H (outcCh H V D t).2 labH (D.hRoot (outcCh H V D t).1) V.bp.hRows V.bp.logCols) with
    | .error _ => .error ()
    | .ok (sps, recs, acc, t4) =>
      if (acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals then .error ()
      else if acc.claims.out ≠ [] then .error ()
      else
        match V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | .error _ => .error ()
        | .ok _ =>
          match V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | .error _ => .error ()
          | .ok _ =>
            match V.bCheck H (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | .error _ => .error ()
            | .ok _ =>
              .ok ⟨⟨none, ⟨D.aRoot, D.hRoot (outcCh H V D t).1, D.maskRoot, sps,
                    (D.mOpen (acc.fs ++ acc.hostFs) t4).1,
                    (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).1,
                    (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).1⟩,
                  [(D.bOpen (cr.pending ++ acc.claims.inp) (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                      (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2).1]⟩,
                (outcCh H V D t).1, recs, acc,
                absorbRoot H (outcCh H V D t).2 labH (D.hRoot (outcCh H V D t).1) V.bp.hRows V.bp.logCols, t4,
                (D.mOpen (acc.fs ++ acc.hostFs) t4).2, (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2,
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2,
                (D.bOpen (cr.pending ++ acc.claims.inp) (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2).2⟩

/-- **The honest OUT-C run's facts.** -/
theorem outcProve_ok (D : OutcData V) (cr : Carry) (t : Tr) (R : OutcRun) (h : outcProve H V D cr t = .ok R) :
    D.own cr = true ∧ outcAlphaBad R.ch = false
      ∧ R.ch = (outcCh H V D t).1
      ∧ R.t3 = absorbRoot H (outcCh H V D t).2 labH (D.hRoot (outcCh H V D t).1) V.bp.hRows V.bp.logCols
      ∧ slotsProve H V.bp D.slot (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 V.lay.ns [] 0 {} R.t3
          = .ok (R.seg.core.slots, R.recs, R.acc, R.t4)
      ∧ (R.acc.fs ++ R.acc.hostFs).length = V.lay.nFunctionals ∧ R.acc.claims.out = []
      ∧ V.checkOpening H .a R.acc.claims.a R.t5 = .ok ()
      ∧ V.checkOpening H .h (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6 = .ok ()
      ∧ V.bCheck H (cr.pending ++ R.acc.claims.inp) R.t7 = .ok ()
      ∧ R.seg.bRoot = none ∧ R.seg.core.aRoot = D.aRoot ∧ R.seg.core.maskRoot = D.maskRoot
      ∧ R.seg.core.hRoot = D.hRoot R.ch
      ∧ (R.seg.core.maskOpen, R.t5) = D.mOpen (R.acc.fs ++ R.acc.hostFs) R.t4
      ∧ (R.seg.core.aOpen, R.t6) = D.aOpen R.acc.claims.a R.t5
      ∧ (R.seg.core.hOpen, R.t7) = D.hOpen (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.t6
      ∧ R.seg.closes = [(D.bOpen (cr.pending ++ R.acc.claims.inp) R.t7).1]
      ∧ R.t8 = (D.bOpen (cr.pending ++ R.acc.claims.inp) R.t7).2 := by
  unfold outcProve at h
  split_ifs at h with hown hbad
  split at h
  · cases h
  · rename_i sps recs acc t4 hs
    split_ifs at h with hfs hout
    cases hA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
    | error e => simp [hA] at h
    | ok u1 =>
      cases hH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
          (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
      | error e => simp [hA, hH] at h
      | ok u2 =>
        cases hB : V.bCheck H (cr.pending ++ acc.claims.inp)
            (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
        | error e => simp [hA, hH, hB] at h
        | ok u3 =>
          simp only [hA, hH, hB, Except.ok.injEq] at h
          subst h
          cases u1
          cases u2
          cases u3
          exact ⟨by simpa using hown, ff_of_not hbad, rfl, rfl, hs,
            not_not.mp hfs, not_not.mp hout, hA, hH, hB, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **`stage_out_c::verify` accepts the honest segment on its own carry** (completeness of the executable OUT-C
verifier): from the honest run, the openings' path depths, the slots' arithmetic (L25's `SlotsSum`, one row width), and
the completeness of `M` and of the openings of `A`, `H` and `B_out` (the latter on the pending claims followed by
OUTC-00's). -/
theorem outcVerify_of_prove (D : OutcData V) (cr : Carry) (t : Tr) (R : OutcRun) (h : outcProve H V D cr t = .ok R)
    (hdeg : ∀ s, 1 ≤ slotD V.bp s ∧ slotD V.bp s < gP)
    (hpA : pathsDepth "stage OUT-C A" V.blk.path 0 R.seg.core.aOpen.columns = .ok ())
    (hpH : pathsDepth "stage OUT-C H" V.blk.path 0 R.seg.core.hOpen.columns = .ok ())
    (hpM : pathsDepth "M" Block.W16R2.maskPath 0 R.seg.core.maskOpen.columns = .ok ())
    (hpB : pathsDepth "B_out" V.bd.path 0 (R.seg.closes.headD IncV.ozk0).columns = .ok ())
    (hslots : SlotsSum H V.bp U D.slot (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 V.lay.ns [] 0 {}
      R.t3)
    (hM : V.maskVerify H D.maskRoot (R.acc.fs ++ R.acc.hostFs) R.seg.core.maskOpen R.t4 = .ok R.t5)
    (hA : V.pcsVerify H .a D.aRoot R.acc.claims.a R.seg.core.aOpen R.t5 = .ok R.t6)
    (hH : V.pcsVerify H .h (D.hRoot R.ch) (R.acc.claims.h ++ [V.lay.logupSumClaim]) R.seg.core.hOpen R.t6 = .ok R.t7)
    (hB : V.bVerify H cr.root (cr.pending ++ R.acc.claims.inp) (R.seg.closes.headD IncV.ozk0) R.t7 = .ok R.t8) :
    V.verify H cr.root cr.pending R.seg t = .ok R.t8 := by
  obtain ⟨-, -, hch, ht3, hs, hfs, hout, hcA, hcH, hcB, hbr, haR, hmR, hhR, -, -, -, hcl, -⟩ := outcProve_ok H V D cr t R h
  have hloop := slotsLoop_of_prove H V.bp U hU D.slot _ _ _ hdeg _ _ _ _ _ _ _ _ _ hslots hs
  refine (outcVerify_ok_iff H V cr.root cr.pending R.seg t _).mpr ⟨by rw [hcl]; rfl, hbr, hpA, hpH, hpM, hpB, R.ch,
    R.recs, R.acc, R.t4, R.t5, R.t6, R.t7, ?_, hfs, ?_, hout, hcA, ?_, hcH, ?_, hcB, hB⟩
  · have e1 : ((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
        R.seg.core.maskRoot.toList).challengeFp2Vec H 2 = outcCh H V D t := by
      simp only [outcCh, haR, hmR]
    show (match slotsLoop H V.bp (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows
        V.bp.logCols).absorb H labM R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).1
        (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).2.1
        (OutcV.bga (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1).2.2 [] 0 R.seg.core.slots {}
        (absorbRoot H (((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).2 labH R.seg.core.hRoot V.bp.hRows V.bp.logCols) with
      | .ok r => (.ok ((((absorbRoot H (V.frame H t) labA R.seg.core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          R.seg.core.maskRoot.toList).challengeFp2Vec H 2).1, r) : Except String _)
      | .error e => .error e) = .ok (R.ch, R.recs, R.acc, R.t4)
    rw [e1, hhR, hch, ← ht3]
    rw [hch] at hloop
    rw [hloop]
  · rw [hmR]
    exact hM
  · rw [haR]
    exact hA
  · rw [hhR]
    exact hH

end OutC

/-! ## L25's `StageInOK` / `StageOutOK` for the executable stages -/

section Contracts

variable {Hdr X Coins : Type}

/-- **Stage IN-C's honest part** (L25's `StageInP` at the executable stage): `incProve` on the statement's data, the
claims left on `B_in` and `B_in`'s root, and the code's encoder `encStage`. -/
def incP (V : Hdr → IncV) (G : Hdr → StageGeom) (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → IncData (V s.hdr)) :
    StageInP (ClsStmt Hdr) X Coins (incStageV V G) where
  prove H s x c t :=
    match incProve H (V s.hdr) (D H s x c) t with
    | .error _ => .error ()
    | .ok R => .ok (R.seg, (R.acc.claims.out, (D H s x c).bRoot), R.t8)
  encode s bnd start seg e := encStage (G s.hdr) bnd start seg e

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **Stage IN-C's contracts on every honest run** (the components L25's `D12aBlockOK` names for a block, at the stage):
the codec (the geometry's facts, the honest segment's canonical words, its counted shape and length), the openings'
path depths, the slots' arithmetic along the run, and the completeness of `M` and the three openings. -/
def IncOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → ClsStmt Hdr) (V : Hdr → IncV)
    (G : Hdr → StageGeom) (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → IncData (V s.hdr)) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (t : Tr) (R : IncRun), adm x →
    incProve (hOf g) (V (stOf g x c).hdr) (D (hOf g) (stOf g x c) x c) t = .ok R →
      ((G (stOf g x c).hdr).g.slots.length = (G (stOf g x c).hdr).g.terms.length
        ∧ (G (stOf g x c).hdr).g.maskDom ≤ 2 ^ 64 ∧ (G (stOf g x c).hdr).g.blk.encCols ≤ 2 ^ 64
        ∧ (G (stOf g x c).hdr).magic.length = 8 ∧ (G (stOf g x c).hdr).hasB = true
        ∧ CoreCanon R.seg.core ∧ CoreShape (G (stOf g x c).hdr).g R.seg.core
        ∧ List.Forall₂ CloseOk (G (stOf g x c).hdr).closes R.seg.closes
        ∧ ∀ e, (encStage (G (stOf g x c).hdr) bnd (posTag (hOf g) t) R.seg e).length = (G (stOf g x c).hdr).len)
      ∧ (∀ s, 1 ≤ slotD ((V (stOf g x c).hdr).bp (incCtx (V (stOf g x c).hdr).pub R.ch)) s
          ∧ slotD ((V (stOf g x c).hdr).bp (incCtx (V (stOf g x c).hdr).pub R.ch)) s < gP)
      ∧ pathsDepth "stage IN-C A" (V (stOf g x c).hdr).blk.path 0 R.seg.core.aOpen.columns = .ok ()
      ∧ pathsDepth "stage IN-C H" (V (stOf g x c).hdr).blk.path 0 R.seg.core.hOpen.columns = .ok ()
      ∧ pathsDepth "M" Block.W16R2.maskPath 0 R.seg.core.maskOpen.columns = .ok ()
      ∧ pathsDepth "input token endpoint" (V (stOf g x c).hdr).ed.path 0 (R.seg.closes.headD IncV.ozk0).columns = .ok ()
      ∧ StSlotsSum (hOf g) ((V (stOf g x c).hdr).bp (incCtx (V (stOf g x c).hdr).pub R.ch))
          (incElog (V (stOf g x c).hdr).pub (V (stOf g x c).hdr).geo.bLogN) U (D (hOf g) (stOf g x c) x c |>.slot R.ch)
          Fp2.zero Fp2.zero Fp2.zero (V (stOf g x c).hdr).lay.ns [] 0 {} R.t3
      ∧ (V (stOf g x c).hdr).maskVerify (hOf g) (D (hOf g) (stOf g x c) x c).maskRoot (R.acc.fs ++ R.acc.hostFs)
          R.seg.core.maskOpen R.t4 = .ok R.t5
      ∧ (V (stOf g x c).hdr).pcsVerify (hOf g) .a (D (hOf g) (stOf g x c) x c).aRoot R.acc.claims.a R.seg.core.aOpen R.t5
          = .ok R.t6
      ∧ (V (stOf g x c).hdr).pcsVerify (hOf g) .h ((D (hOf g) (stOf g x c) x c).hRoot R.ch)
          (R.acc.claims.h ++ [(V (stOf g x c).hdr).lay.logupSumClaim]) R.seg.core.hOpen R.t6 = .ok R.t7
      ∧ (V (stOf g x c).hdr).epVerify (hOf g) (stOf g x c).inRoot R.acc.claims.inp (R.seg.closes.headD IncV.ozk0) R.t7
          = .ok R.t8

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **L25's `StageInOK` for the executable stage IN-C**, from its contracts: the honest segment decodes back at every
start and end tag (`decodeStage_enc`), and `stage_in_c::verify` accepts it with the prover's pending claims, root and
transcript (`incVerify_of_prove`). With L25's `inSeg_complete` this is O8's stage-IN-C part. -/
theorem inc_stageInOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → ClsStmt Hdr)
    (V : Hdr → IncV) (G : Hdr → StageGeom) (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → IncData (V s.hdr))
    (hok : IncOK U adm hOf stOf V G D) : StageInOK adm hOf stOf (incStageV V G) (incP V G D) := by
  intro g x c bnd t seg pr t' hx hrun
  have hrun' : (match incProve (hOf g) (V (stOf g x c).hdr) (D (hOf g) (stOf g x c) x c) t with
      | .error _ => (.error () : Except Unit (StageSeg × (List Block.ZClaim × Dig) × Tr))
      | .ok R => .ok (R.seg, (R.acc.claims.out, (D (hOf g) (stOf g x c) x c).bRoot), R.t8)) = .ok (seg, pr, t') := hrun
  cases hR : incProve (hOf g) (V (stOf g x c).hdr) (D (hOf g) (stOf g x c) x c) t with
  | error e => rw [hR] at hrun'; cases hrun'
  | ok R =>
    rw [hR] at hrun'
    simp only [Except.ok.injEq, Prod.mk.injEq] at hrun'
    obtain ⟨rfl, rfl, rfl⟩ := hrun'
    obtain ⟨⟨hgt, hdom, henc, hmag, hb, hcan, hsh, hcl, hlen⟩, hdeg, hpA, hpH, hpM, hpE, hsl, hM, hA, hH, hE⟩ :=
      hok g x c bnd t R hx hR
    have hbr : R.seg.bRoot.isSome = (G (stOf g x c).hdr).hasB := by
      rw [(incProve_ok _ _ _ _ R hR).2.2.2.2.2.2.2.2.1, hb]
      rfl
    refine ⟨?_, ?_⟩
    · exact decodeStage_enc (G (stOf g x c).hdr) hgt hdom henc hmag bnd (posTag (hOf g) t) R.seg _ hcan hsh hbr hcl
        (hlen _)
    · exact incVerify_of_prove (hOf g) (V (stOf g x c).hdr) U hU _ _ t R hR hdeg hpA hpH hpM hpE hsl hM hA hH hE

omit hU in
/-- **Stage OUT-C's honest part** (L25's `StageOutP` at the executable stage): `outcProve` on the carry, and `encStage`. -/
def outcP (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom)
    (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → OutcData (V s.hdr s.verdict)) :
    StageOutP (ClsStmt Hdr) X Coins (outcStageV V G) where
  prove H s x c cr t :=
    match outcProve H (V s.hdr s.verdict) (D H s x c) cr t with
    | .error _ => .error ()
    | .ok R => .ok (R.seg, R.t8)
  encode s bnd start seg e := encStage (G s.hdr) bnd start seg e

omit hU in
/-- **Stage OUT-C's contracts on every honest run** (on its own carry): the codec, the paths' depths, the slots'
arithmetic, and the completeness of `M` and of the openings of `A`, `H` and `B_out`. -/
def OutcOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → ClsStmt Hdr)
    (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom)
    (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → OutcData (V s.hdr s.verdict)) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (cr : Carry) (t : Tr) (R : OutcRun), adm x →
    outcProve (hOf g) (V (stOf g x c).hdr (stOf g x c).verdict) (D (hOf g) (stOf g x c) x c) cr t = .ok R →
      ((G (stOf g x c).hdr).g.slots.length = (G (stOf g x c).hdr).g.terms.length
        ∧ (G (stOf g x c).hdr).g.maskDom ≤ 2 ^ 64 ∧ (G (stOf g x c).hdr).g.blk.encCols ≤ 2 ^ 64
        ∧ (G (stOf g x c).hdr).magic.length = 8 ∧ (G (stOf g x c).hdr).hasB = false
        ∧ CoreCanon R.seg.core ∧ CoreShape (G (stOf g x c).hdr).g R.seg.core
        ∧ List.Forall₂ CloseOk (G (stOf g x c).hdr).closes R.seg.closes
        ∧ ∀ e, (encStage (G (stOf g x c).hdr) bnd (posTag (hOf g) t) R.seg e).length = (G (stOf g x c).hdr).len)
      ∧ (∀ s, 1 ≤ slotD (V (stOf g x c).hdr (stOf g x c).verdict).bp s
          ∧ slotD (V (stOf g x c).hdr (stOf g x c).verdict).bp s < gP)
      ∧ pathsDepth "stage OUT-C A" (V (stOf g x c).hdr (stOf g x c).verdict).blk.path 0 R.seg.core.aOpen.columns = .ok ()
      ∧ pathsDepth "stage OUT-C H" (V (stOf g x c).hdr (stOf g x c).verdict).blk.path 0 R.seg.core.hOpen.columns = .ok ()
      ∧ pathsDepth "M" Block.W16R2.maskPath 0 R.seg.core.maskOpen.columns = .ok ()
      ∧ pathsDepth "B_out" (V (stOf g x c).hdr (stOf g x c).verdict).bd.path 0 (R.seg.closes.headD IncV.ozk0).columns
          = .ok ()
      ∧ SlotsSum (hOf g) (V (stOf g x c).hdr (stOf g x c).verdict).bp U (D (hOf g) (stOf g x c) x c).slot
          (OutcV.bga R.ch).1 (OutcV.bga R.ch).2.1 (OutcV.bga R.ch).2.2 (V (stOf g x c).hdr (stOf g x c).verdict).lay.ns
          [] 0 {} R.t3
      ∧ (V (stOf g x c).hdr (stOf g x c).verdict).maskVerify (hOf g) (D (hOf g) (stOf g x c) x c).maskRoot
          (R.acc.fs ++ R.acc.hostFs) R.seg.core.maskOpen R.t4 = .ok R.t5
      ∧ (V (stOf g x c).hdr (stOf g x c).verdict).pcsVerify (hOf g) .a (D (hOf g) (stOf g x c) x c).aRoot R.acc.claims.a
          R.seg.core.aOpen R.t5 = .ok R.t6
      ∧ (V (stOf g x c).hdr (stOf g x c).verdict).pcsVerify (hOf g) .h ((D (hOf g) (stOf g x c) x c).hRoot R.ch)
          (R.acc.claims.h ++ [(V (stOf g x c).hdr (stOf g x c).verdict).lay.logupSumClaim]) R.seg.core.hOpen R.t6
          = .ok R.t7
      ∧ (V (stOf g x c).hdr (stOf g x c).verdict).bVerify (hOf g) cr.root (cr.pending ++ R.acc.claims.inp)
          (R.seg.closes.headD IncV.ozk0) R.t7 = .ok R.t8

/-- **L25's `StageOutOK` for the executable stage OUT-C**, from its contracts (`decodeStage_enc`, `outcVerify_of_prove`).
With L25's `outSeg_complete` this is O8's stage-OUT-C part. -/
theorem outc_stageOutOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → ClsStmt Hdr)
    (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom)
    (D : (HIn → Dig) → (s : ClsStmt Hdr) → X → Coins → OutcData (V s.hdr s.verdict))
    (hok : OutcOK U adm hOf stOf V G D) : StageOutOK adm hOf stOf (outcStageV V G) (outcP V G D) := by
  intro g x c bnd cr t seg t' hx hrun
  have hrun' : (match outcProve (hOf g) (V (stOf g x c).hdr (stOf g x c).verdict) (D (hOf g) (stOf g x c) x c) cr t with
      | .error _ => (.error () : Except Unit (StageSeg × Tr))
      | .ok R => .ok (R.seg, R.t8)) = .ok (seg, t') := hrun
  cases hR : outcProve (hOf g) (V (stOf g x c).hdr (stOf g x c).verdict) (D (hOf g) (stOf g x c) x c) cr t with
  | error e => rw [hR] at hrun'; cases hrun'
  | ok R =>
    rw [hR] at hrun'
    simp only [Except.ok.injEq, Prod.mk.injEq] at hrun'
    obtain ⟨rfl, rfl⟩ := hrun'
    obtain ⟨⟨hgt, hdom, henc, hmag, hb, hcan, hsh, hcl, hlen⟩, hdeg, hpA, hpH, hpM, hpB, hsl, hM, hA, hH, hB⟩ :=
      hok g x c bnd cr t R hx hR
    have hbr : R.seg.bRoot.isSome = (G (stOf g x c).hdr).hasB := by
      rw [(outcProve_ok _ _ _ _ _ R hR).2.2.2.2.2.2.2.2.2.2.1, hb]
      rfl
    refine ⟨?_, ?_⟩
    · exact decodeStage_enc (G (stOf g x c).hdr) hgt hdom henc hmag bnd (posTag (hOf g) t) R.seg _ hcan hsh hbr hcl
        (hlen _)
    · exact outcVerify_of_prove (hOf g) (V (stOf g x c).hdr (stOf g x c).verdict) U hU _ cr t R hR hdeg hpA hpH hpM
        hpB hsl hM hA hH hB

end Contracts

/-! ## O9 for the stages: the honest stage provers refuse only at the listed places -/

section Refuse

variable (H : HIn → Dig)

/-- **Stage IN-C's honest prover refuses only at**: D66(3) (`α` an entry of `τ`, a function of `r_emb`), a slot's
refusal (`slotProve_refuses`: `define`'s zero batching challenges, `c = 0`, a degenerate `e`, a schedule failure), the
functional count, `check_opening` of `A` or `H`, or `check_token_endpoint_opening` (its schedule or its challenge
refusals on a clone). -/
theorem incProve_refuses (V : IncV) (D : IncData V) (t : Tr) (h : incProve H V D t = .error ()) :
    incAlphaBad (incCtx V.pub (incCh H V D t).1) = true
      ∨ (∃ (i : ℕ) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < V.lay.ns
          ∧ slotProve H (atLog (V.bp (incCtx V.pub (incCh H V D t).1)) (incElog V.pub V.geo.bLogN i))
              (sdAt (D.slot (incCh H V D t).1) (incElog V.pub V.geo.bLogN i)) i (histOf Fp2.zero Fp2.zero Fp2.zero recs₁)
              acc₁ t₁ = .error ())
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
          stSlotsProve H (V.bp (incCtx V.pub (incCh H V D t).1)) (incElog V.pub V.geo.bLogN) (D.slot (incCh H V D t).1)
            Fp2.zero Fp2.zero Fp2.zero V.lay.ns [] 0 {}
            (absorbRoot H (incCh H V D t).2 labH (D.hRoot (incCh H V D t).1) V.lay.hRows V.lay.logN)
              = .ok (sps, recs, acc, t4)
          ∧ ((acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals
            ∨ (∃ e, V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
            ∨ (∃ e, V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
            ∨ ∃ e, checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e) := by
  unfold incProve at h
  split_ifs at h with hbad
  · exact Or.inl hbad
  · split at h
    · rename_i e he
      cases e
      obtain ⟨i, recs₁, acc₁, t₁, hi, hr⟩ := stSlotsProve_refuses H _ _ _ _ _ _ _ [] 0 {} _ he
      exact Or.inr (Or.inl ⟨i, recs₁, acc₁, t₁, hi, by simpa using hr⟩)
    · rename_i sps recs acc t4 hs
      refine Or.inr (Or.inr ⟨sps, recs, acc, t4, hs, ?_⟩)
      split_ifs at h with hfs
      · exact Or.inl hfs
      · cases hA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inr (Or.inl ⟨e, rfl⟩)
        | ok u1 =>
          cases hH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inr (Or.inr (Or.inl ⟨e, rfl⟩))
          | ok u2 =>
            cases hE : checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact Or.inr (Or.inr (Or.inr ⟨e, rfl⟩))
            | ok u3 => simp [hA, hH, hE] at h

/-- **Stage OUT-C's honest prover refuses only at**: a carry that is not its own (L25-1), D66(3) (`α` an entry of the
byte table), a slot's refusal, the functional count, a claim on an output endpoint (deterministic: never for the
schedule), `check_opening` of `A` or `H`, or the boundary audit. -/
theorem outcProve_refuses (V : OutcV) (D : OutcData V) (cr : Carry) (t : Tr) (h : outcProve H V D cr t = .error ()) :
    D.own cr = false ∨ outcAlphaBad (outcCh H V D t).1 = true
      ∨ (∃ (i : ℕ) (recs₁ : List SlotRec) (acc₁ : Acc) (t₁ : Tr), i < V.lay.ns
          ∧ slotProve H V.bp D.slot i (histOf (OutcV.bga (outcCh H V D t).1).1 (OutcV.bga (outcCh H V D t).1).2.1
              (OutcV.bga (outcCh H V D t).1).2.2 recs₁) acc₁ t₁ = .error ())
      ∨ ∃ (sps : List SlotProof) (recs : List SlotRec) (acc : Acc) (t4 : Tr),
          slotsProve H V.bp D.slot (OutcV.bga (outcCh H V D t).1).1 (OutcV.bga (outcCh H V D t).1).2.1
            (OutcV.bga (outcCh H V D t).1).2.2 V.lay.ns [] 0 {}
            (absorbRoot H (outcCh H V D t).2 labH (D.hRoot (outcCh H V D t).1) V.bp.hRows V.bp.logCols)
              = .ok (sps, recs, acc, t4)
          ∧ ((acc.fs ++ acc.hostFs).length ≠ V.lay.nFunctionals ∨ acc.claims.out ≠ []
            ∨ (∃ e, V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 = .error e)
            ∨ (∃ e, V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
                (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 = .error e)
            ∨ ∃ e, V.bCheck H (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 = .error e) := by
  unfold outcProve at h
  split_ifs at h with hown hbad
  · exact Or.inl hown
  · exact Or.inr (Or.inl hbad)
  · split at h
    · rename_i e he
      cases e
      obtain ⟨i, recs₁, acc₁, t₁, hi, hr⟩ := slotsProve_refuses H V.bp D.slot _ _ _ _ [] 0 {} _ he
      exact Or.inr (Or.inr (Or.inl ⟨i, recs₁, acc₁, t₁, hi, by simpa using hr⟩))
    · rename_i sps recs acc t4 hs
      refine Or.inr (Or.inr (Or.inr ⟨sps, recs, acc, t4, hs, ?_⟩))
      split_ifs at h with hfs hout
      · exact Or.inl hfs
      · exact Or.inr (Or.inl hout)
      · cases hA : V.checkOpening H .a acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2 with
        | error e => exact Or.inr (Or.inr (Or.inl ⟨e, rfl⟩))
        | ok u1 =>
          cases hH : V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim])
              (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2 with
          | error e => exact Or.inr (Or.inr (Or.inr (Or.inl ⟨e, rfl⟩)))
          | ok u2 =>
            cases hB : V.bCheck H (cr.pending ++ acc.claims.inp)
                (D.hOpen (acc.claims.h ++ [V.lay.logupSumClaim])
                  (D.aOpen acc.claims.a (D.mOpen (acc.fs ++ acc.hostFs) t4).2).2).2 with
            | error e => exact Or.inr (Or.inr (Or.inr (Or.inr ⟨e, rfl⟩)))
            | ok u3 => simp [hA, hH, hB] at h

end Refuse

end ZK60.Exec.StageV
