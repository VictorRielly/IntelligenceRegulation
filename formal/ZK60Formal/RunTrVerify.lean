/-
D63 lane L34 (2026-11-09), part 3: **the run verifier's transcript states are the states of its prefixes** (L30 §5.7
item 1), for L18's `verify_classify_run_with` (`classifyVerifyE`) at any run verifier `V`.

The run's transcript `rtTr` (`RunTrSched.lean`) is the trace of a list of operations read off the statement and the
receipt ALONE. The verifier itself decodes each segment against the transcript's position tag, which depends on the
oracle. The link between the two is one contract per part:

* `RtSeg`: a part of the run with its schedule: its segment verifier (L18's `SegV`), its profile counts (`RtPart`), and
  a reading `rd` of its data off the statement and the segment's bytes (no oracle);
* `RtSeg.Holds`: the part's CONTRACT. Whenever the part's framed step accepts (from a carry meeting the part's
  invariant), the transcript moves by exactly the part's steps on the data read, that data has the profile's shape and
  fits, and the carry it hands on meets the next part's invariant (the carry holds the pending claims, whose count
  fixes the next opening's batching width);
* `rtRead`, **`rt_segsOk`**: a run of parts, each meeting its contract, moves the transcript by the parts' steps;
* `RtRun`: the run's schedule: the run header's operations (`st.transcript()`), the parts with their contracts chained
  by the invariants, in the order of `V.parts`; `RtRun.pf` its profile, `RtRun.rd` its reading, `RtRun.tr` THE RUN'S
  TRANSCRIPT;
* **`RtRun.accept`**: if `verify_classify_run_with` accepts, the output has the profile's shape (so `RtRun.tr` is the
  trace of the run's real operations, and every window is at its fixed position: findings L27-2, L28-1), and the
  verifier's final transcript is `runOps` of the run's steps from the fresh keyed transcript;
* **`RtRun.accept_part`**: and for every part `i`, the verifier ran part `i`'s framed step on the transcript
  `runOps` of the run's steps before part `i`, from a carry meeting part `i`'s invariant, on segment `i`, and the
  step accepted; the data read for part `i` is that segment's;
* `RtRun.acceptU`, `RtRun.acceptU_part`: the same from the acceptance of the protocol object `classifyProtocolU`.

The contracts themselves (stage IN-C, a D12a block with its boundary opening, stage OUT-C) are in `RunTrParts.lean`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrSched
import ZK60Formal.RunChainUExec

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Block (BlockShape)

/-! ## A part with its schedule, and its contract -/

/-- **A part of the run with its schedule**: its segment verifier, the profile's counts, and the reading of its data
off the statement and the segment's bytes (no oracle, no transcript). -/
structure RtSeg (St : Type) where
  v : SegV St
  p : RtPart
  rd : St → List UInt8 → RtData

/-- **A part's schedule contract.** Whenever the part's framed step accepts from a carry meeting `Inv`: the transcript
after it is `runOps` of the part's steps on the data read off the statement and the bytes; that data has the profile's
shape (and every operation fits `Lq`); the carry handed on meets `Inv'`. -/
def RtSeg.Holds {St : Type} (σ : RtSeg St) (Lq : ℕ) (Inv Inv' : Carry → Prop) : Prop :=
  ∀ (H : HIn → Dig) (s : St) (bnd : Dig) (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr),
    Inv cr → segStep σ.v H s bnd bytes cr t = .ok (cr', t') →
      t' = runOps H t (stpsOps (rtPartStps σ.p (σ.rd s bytes))) ∧ RtPartOk Lq σ.p (σ.rd s bytes) ∧ Inv' cr'

/-- The parts' data read off the statement and the segments. -/
def rtRead {St : Type} (σs : List (RtSeg St)) (s : St) (segs : List (List UInt8)) : List RtData :=
  List.zipWith (fun σ b => σ.rd s b) σs segs

theorem rt_take_zipWith {β γ δ : Type} (f : β → γ → δ) : ∀ (i : ℕ) (l : List β) (m : List γ),
    (List.zipWith f l m).take i = List.zipWith f (l.take i) (m.take i)
  | 0, _, _ => rfl
  | _ + 1, [], _ => by simp
  | _ + 1, _ :: _, [] => by simp
  | i + 1, x :: l, y :: m => by
    simp only [List.zipWith_cons_cons, List.take_succ_cons]
    rw [rt_take_zipWith f i l m]

theorem rt_zipWith_getElem? {β γ δ : Type} (f : β → γ → δ) : ∀ (l : List β) (m : List γ) (i : ℕ) (a : β) (b : γ),
    l[i]? = some a → m[i]? = some b → (List.zipWith f l m)[i]? = some (f a b)
  | [], _, _, _, _, h, _ => by simp at h
  | _ :: _, [], _, _, _, _, h => by simp at h
  | x :: l, y :: m, 0, a, b, h1, h2 => by
    simp only [List.getElem?_cons_zero, Option.some.injEq] at h1 h2
    simp [h1, h2]
  | x :: l, y :: m, i + 1, a, b, h1, h2 => by
    simp only [List.getElem?_cons_succ] at h1 h2
    simp only [List.zipWith_cons_cons, List.getElem?_cons_succ]
    exact rt_zipWith_getElem? f l m i a b h1 h2

theorem rt_drop_cons_getElem? {β : Type} : ∀ (l : List β) (i : ℕ) (b : β) (bs : List β),
    l.drop i = b :: bs → l[i]? = some b
  | [], _, _, _, h => by simp at h
  | x :: l, 0, b, bs, h => by
    simp only [List.drop_zero, List.cons.injEq] at h
    simp [h.1]
  | x :: l, i + 1, b, bs, h => by
    rw [List.getElem?_cons_succ]
    exact rt_drop_cons_getElem? l i b bs (by simpa using h)

section Segs

variable {St : Type} (Lq : ℕ) (H : HIn → Dig) (s : St) (bnd : Dig) (Inv : ℕ → Carry → Prop)

/-- **A run of parts meeting their contracts moves the transcript by the parts' steps**: from a carry meeting the
first part's invariant, if every part's framed step accepts in order, the transcript after them is `runOps` of the
parts' steps on the data read; every part's data has the profile's shape; the last carry meets the invariant after
the last part. -/
theorem rt_segsOk : ∀ (σs : List (RtSeg St)) (i0 : ℕ) (bs : List (List UInt8)) (cr : Carry) (t : Tr) (cr' : Carry)
    (t' : Tr), (∀ (j : ℕ) (σ : RtSeg St), σs[j]? = some σ → σ.Holds Lq (Inv (i0 + j)) (Inv (i0 + j + 1))) →
    Inv i0 cr → SegsOk H s bnd (σs.map (fun σ => σ.v)) bs cr t cr' t' →
      t' = runOps H t (stpsOps (rtPartsStps (σs.map (fun σ => σ.p)) (rtRead σs s bs)))
        ∧ List.Forall₂ (RtPartOk Lq) (σs.map (fun σ => σ.p)) (rtRead σs s bs) ∧ Inv (i0 + σs.length) cr'
  | [], i0, [], cr, t, cr', t', _, hi, h => by
    obtain ⟨e1, e2⟩ := (show cr' = cr ∧ t' = t from h)
    subst e1
    subst e2
    exact ⟨rfl, List.Forall₂.nil, hi⟩
  | [], _, _ :: _, _, _, _, _, _, _, h => False.elim h
  | _ :: _, _, [], _, _, _, _, _, _, h => False.elim h
  | σ :: σs, i0, b :: bs, cr, t, cr', t', hc, hi, h => by
    obtain ⟨cr₁, t₁, h1, h2⟩ := (show ∃ cr₁ t₁, segStep σ.v H s bnd b cr t = .ok (cr₁, t₁)
      ∧ SegsOk H s bnd (σs.map (fun σ => σ.v)) bs cr₁ t₁ cr' t' from h)
    obtain ⟨e1, ok1, inv1⟩ := hc 0 σ List.getElem?_cons_zero H s bnd b cr t cr₁ t₁ hi h1
    obtain ⟨e2, ok2, inv2⟩ := rt_segsOk σs (i0 + 1) bs cr₁ t₁ cr' t'
      (fun j σ' hj => by
        have hh := hc (j + 1) σ' (by simpa using hj)
        rwa [show i0 + (j + 1) = i0 + 1 + j by omega] at hh) inv1 h2
    refine ⟨?_, List.Forall₂.cons ok1 ok2, ?_⟩
    · show t' = runOps H t (stpsOps (rtPartStps σ.p (σ.rd s b) ++ rtPartsStps (σs.map (fun σ => σ.p)) (rtRead σs s bs)))
      rw [stpsOps_append, runOps_append, ← e1]
      exact e2
    · rw [List.length_cons, show i0 + (σs.length + 1) = i0 + 1 + σs.length by omega]
      exact inv2

end Segs

/-! ## The run's schedule -/

/-- **The classify run's schedule**, for a run verifier `V` on the keyed transcript of `domain`: the run header's
operations `hdr` (`st.transcript()` is `runOps` of them from the fresh transcript: `hstart`; on a statement the
pre-header policy accepts they have the profile's counts and fit: `hhdr`), the parts with their schedules in the order
of `V.parts` (`hv`), and the carry's invariants before each part, with every part's contract (`hσ`). -/
structure RtRun {Hdr : Type} (V : RunV Hdr) (key : Option Dig) (domain : List UInt8) (Lq : ℕ) where
  hdr : ClsStmt Hdr → List Op
  hdrLen : ℕ
  hdrSq : ℕ
  σs : List (RtSeg (ClsStmt Hdr))
  Inv : ℕ → Carry → Prop
  hstart : ∀ (H : HIn → Dig) (s : ClsStmt Hdr), V.start H s = runOps H (Tr.newKeyed H domain key) (hdr s)
  hhdr : ∀ s : ClsStmt Hdr, V.preA s.hdr = .ok () → V.preB s.hdr = .ok () →
    (hdr s).length = hdrLen ∧ sqN (hdr s) = hdrSq ∧ ∀ op ∈ hdr s, op.len ≤ Lq
  hv : σs.map (fun σ => σ.v) = V.parts
  hInv0 : Inv 0 carry0
  hσ : ∀ (j : ℕ) (σ : RtSeg (ClsStmt Hdr)), σs[j]? = some σ → σ.Holds Lq (Inv j) (Inv (j + 1))

section RunSched

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- The run's profile. -/
def RtRun.pf (R : RtRun V key domain Lq) : RtProf := ⟨R.hdrLen, R.hdrSq, R.σs.map (fun σ => σ.p)⟩

/-- The run's reading of an output (statement, receipt): the header's operations and the parts' data. -/
def RtRun.rd (R : RtRun V key domain Lq) (o : ClsStmt Hdr × ClsReceipt) : List Op × List RtData :=
  (R.hdr o.1, rtRead R.σs o.1 o.2)

/-- **THE CLASSIFY RUN'S ONE TRANSCRIPT**: `rtTr` at the run's profile and reading. -/
noncomputable def RtRun.tr (R : RtRun V key domain Lq) :
    (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig) :=
  rtTr key domain Lq R.pf R.rd

theorem RtRun.parts_length (R : RtRun V key domain Lq) : R.pf.parts.length = V.L + 2 := by
  have h := congrArg List.length R.hv
  rw [List.length_map, RunV.parts_length] at h
  show (R.σs.map (fun σ => σ.p)).length = V.L + 2
  rw [List.length_map]
  exact h

/-- **On acceptance the output has the profile's shape and the verifier's final transcript is the run's steps'**
(L30 §5.7 item 1). If `verify_classify_run_with` accepts `(s, segs)` under the hash `H`: the output has the profile's
shape (`RtGood`: so the run's transcript is the trace of the run's real operations and its windows are at the
profile's positions); the run of segments ended on a transcript that is `runOps` of the run's steps from the fresh
keyed transcript; and the last carry meets the last invariant. -/
theorem RtRun.accept (R : RtRun V key domain Lq) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8))
    (hacc : classifyVerifyE V H s segs = .ok ()) :
    RtGood Lq R.pf (R.rd (s, segs))
      ∧ ∃ (cr : Carry) (t : Tr), runSegs H s (V.start H s).state V.parts segs carry0 (V.start H s) = .ok (cr, t)
        ∧ t = runOps H (Tr.newKeyed H domain key) (stpsOps (rtStps R.pf (R.rd (s, segs))))
        ∧ R.Inv R.σs.length cr := by
  unfold classifyVerifyE at hacc
  simp only [ex_bind_ok_iff, countOk_eq_ok] at hacc
  obtain ⟨⟨⟩, hA, ⟨⟩, -, ⟨⟩, hB, ⟨cr, t⟩, hr, -⟩ := hacc
  have hr' := hr
  rw [runSegs_ok_iff, ← R.hv] at hr'
  obtain ⟨e, ok, inv⟩ := rt_segsOk Lq H s (V.start H s).state R.Inv R.σs 0 segs carry0 (V.start H s) cr t
    (fun j σ hj => by simpa using R.hσ j σ hj) R.hInv0 hr'
  obtain ⟨h1, h2, h3⟩ := R.hhdr s hA hB
  have e' : runOps H (Tr.newKeyed H domain key) (stpsOps (rtStps R.pf (R.rd (s, segs))))
      = runOps H (runOps H (Tr.newKeyed H domain key) (R.rd (s, segs)).1)
          (stpsOps (rtPartsStps R.pf.parts (R.rd (s, segs)).2)) := by
    unfold rtStps
    rw [stpsOps_append, stpsOps_opsStps, runOps_append]
  refine ⟨⟨h1, h2, h3, ok⟩, cr, t, hr, ?_, by simpa using inv⟩
  rw [e']
  show t = runOps H (runOps H (Tr.newKeyed H domain key) (R.hdr s)) _
  rw [← R.hstart]
  exact e

/-- **On acceptance the verifier's transcript before each part is the transcript of the run's steps before it**
(L30 §5.7 item 1). If `verify_classify_run_with` accepts `(s, segs)` under `H`, then for every part `i` of the
schedule: the verifier ran part `i`'s framed step on segment `i`, from a carry meeting part `i`'s invariant and the
transcript `runOps` of the run's steps before part `i`, and the step accepted; and the data the run's reading gives
for part `i` is that segment's. -/
theorem RtRun.accept_part (R : RtRun V key domain Lq) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8))
    (hacc : classifyVerifyE V H s segs = .ok ()) (i : ℕ) (σ : RtSeg (ClsStmt Hdr)) (hσi : R.σs[i]? = some σ) :
    ∃ (cr cr' : Carry) (t t' : Tr), R.Inv i cr
      ∧ t = runOps H (Tr.newKeyed H domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i))
      ∧ segStep σ.v H s (V.start H s).state (segs.getD i []) cr t = .ok (cr', t')
      ∧ (R.rd (s, segs)).2[i]? = some (σ.rd s (segs.getD i [])) := by
  unfold classifyVerifyE at hacc
  simp only [ex_bind_ok_iff, countOk_eq_ok] at hacc
  obtain ⟨⟨⟩, -, ⟨⟩, -, ⟨⟩, -, ⟨crF, tF⟩, hr, -⟩ := hacc
  rw [runSegs_ok_iff, ← R.hv] at hr
  obtain ⟨hi, hσe⟩ := List.getElem?_eq_some_iff.mp hσi
  have hsplit : R.σs.map (fun σ => σ.v)
      = (R.σs.take i).map (fun σ => σ.v) ++ (σ.v :: (R.σs.drop (i + 1)).map (fun σ => σ.v)) := by
    conv_lhs => rw [← List.take_append_drop i R.σs]
    rw [List.map_append, List.drop_eq_getElem_cons hi, hσe, List.map_cons]
  rw [hsplit, segsOk_append] at hr
  obtain ⟨cr, t, hpre, hpost⟩ := hr
  have hlen : ((R.σs.take i).map (fun σ => σ.v)).length = i := by
    rw [List.length_map, List.length_take]
    omega
  rw [hlen] at hpre hpost
  rcases hd : segs.drop i with _ | ⟨b, bs⟩
  · rw [hd] at hpost
    exact False.elim hpost
  · rw [hd] at hpost
    obtain ⟨cr', t', hstep, -⟩ := hpost
    have hb : segs[i]? = some b := rt_drop_cons_getElem? segs i b bs hd
    have hgd : segs.getD i [] = b := by
      rw [List.getD_eq_getElem?_getD, hb]
      rfl
    obtain ⟨e, -, inv⟩ := rt_segsOk Lq H s (V.start H s).state R.Inv (R.σs.take i) 0 (segs.take i) carry0
      (V.start H s) cr t
      (fun j σ' hj => by
        have hj' : R.σs[j]? = some σ' := by
          rw [List.getElem?_take] at hj
          split_ifs at hj with hji
          exact hj
        simpa using R.hσ j σ' hj') R.hInv0 hpre
    have hli : (R.σs.take i).length = i := by
      rw [List.length_take]
      omega
    refine ⟨cr, cr', t, t', ?_, ?_, ?_, ?_⟩
    · rw [hli] at inv
      simpa using inv
    · have e' : stpsOps (rtPre R.pf (R.rd (s, segs)) i)
          = R.hdr s ++ stpsOps (rtPartsStps ((R.σs.take i).map (fun σ => σ.p))
              (List.zipWith (fun σ b => σ.rd s b) (R.σs.take i) (segs.take i))) := by
        show stpsOps (opsStps (R.hdr s) ++ rtPartsStps ((R.σs.map (fun σ => σ.p)).take i)
          ((List.zipWith (fun σ b => σ.rd s b) R.σs segs).take i)) = _
        rw [stpsOps_append, stpsOps_opsStps, ← List.map_take, rt_take_zipWith]
      rw [e', runOps_append, ← R.hstart]
      exact e
    · rw [hgd]
      exact hstep
    · rw [hgd]
      exact rt_zipWith_getElem? (fun (σ : RtSeg (ClsStmt Hdr)) (b : List UInt8) => σ.rd s b) R.σs segs i σ b hσi hb

/-! ## From the protocol object's acceptance -/

variable {S : BlockShape} {Salt Coins : Type}

/-- `RtRun.accept` from the acceptance of the protocol object `classifyProtocolU` (L26's instance at any run verifier;
`classifyProtocolUExec` is it at `V := classifyRunV …`). -/
theorem RtRun.acceptU (R : RtRun V key domain Lq) (Rp : ClassifyRunPublic S) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hacc : (classifyProtocolU S Rp Lq V P Cin h64 hr base e).verify G () s segs = true) :
    RtGood Lq R.pf (R.rd (s, segs))
      ∧ ∃ (cr : Carry) (t : Tr),
        runSegs (liftH G) s (V.start (liftH G) s).state V.parts segs carry0 (V.start (liftH G) s) = .ok (cr, t)
        ∧ t = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtStps R.pf (R.rd (s, segs))))
        ∧ R.Inv R.σs.length cr :=
  R.accept (liftH G) s segs ((verifyU_iff Rp Lq V P Cin h64 hr base e G s segs).mp hacc)

/-- `RtRun.accept_part` from the acceptance of the protocol object `classifyProtocolU`. -/
theorem RtRun.acceptU_part (R : RtRun V key domain Lq) (Rp : ClassifyRunPublic S) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hacc : (classifyProtocolU S Rp Lq V P Cin h64 hr base e).verify G () s segs = true) (i : ℕ)
    (σ : RtSeg (ClsStmt Hdr)) (hσi : R.σs[i]? = some σ) :
    ∃ (cr cr' : Carry) (t t' : Tr), R.Inv i cr
      ∧ t = runOps (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtPre R.pf (R.rd (s, segs)) i))
      ∧ segStep σ.v (liftH G) s (V.start (liftH G) s).state (segs.getD i []) cr t = .ok (cr', t')
      ∧ (R.rd (s, segs)).2[i]? = some (σ.rd s (segs.getD i [])) :=
  R.accept_part (liftH G) s segs ((verifyU_iff Rp Lq V P Cin h64 hr base e G s segs).mp hacc) i σ hσi

end RunSched

end ZK60.ProtocolClassify
