/-
D63 lane L43 (2026-11-10), part 4: **`hal_M` at the run's parse** (L39 §5 item 3).

The second ordered cover premise: on an accepted run outside the extraction failure (and with no `opB` doomed), `M`'s
check of every part is alive at the end of the run's transcript. L22's `mask_subSt_of_ok` (`M` alive at the end of a
chain whose window starts `M`'s steps on a transcript where `MaskOk` holds) is used directly at the run's wide parse
`rtW pf.sqs`, for `M` of every part (stage IN-C, the blocks, stage OUT-C):

* **`rh_stpOK_mask`**, `rh_ctr_mask`: `M`'s three widths read off the parse's `StpOK` at its window, and the counters
  at its runs;
* **`rh_M_alive`**: `M` of `rkData` (`rkMask`: functionals read off the header, table extracted for `M`'s root) is
  alive at the end of ANY transcript that, from its window, runs `M`'s steps on a transcript `tM` where the verifier's
  `MaskOk` holds on the functionals the reader returns (with the code's functional count) and the table extracted at
  every sampled index is the opened column;
* `RhMW`, `rh_M_of`: those facts with their witnesses;
* **`rh_hal_M`**: `hal_M`'s conclusion in the top theorem's form (`(rtKM … D hD).Al n lg τ`) at `D := rkData …`, from
  `RhMW` in every part. (`hal_M` may also assume no `opB` is doomed; this proof does not need it.)

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunHalOpB

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

/-! ## `M`'s widths and counters -/

/-- **`M`'s three widths** read off the parse at its window: `θ` one squeeze, the row coefficients `2S + 2`, the
indices `64`. -/
theorem rh_stpOK_mask (W : UInt64 → ℕ) (c : UInt64) (S : ℕ) (mo : Block.MaskOpening) (rs : List Stp)
    (h : StpOK W c (mStps S mo ++ rs)) :
    W c = 1 ∧ W (c + UInt64.ofNat 1) = 2 * S + 2 ∧ W (c + UInt64.ofNat 1 + UInt64.ofNat (2 * S + 2)) = 64 := by
  have e : mStps S mo ++ rs = .sq 1 :: .ab Block.labMaskQ (mo.q.flatMap Fp2.toBytes) :: .sq (2 * S + 2)
      :: .ab Block.labMaskProx (mo.prox.flatMap Fp2.toBytes) :: .sq 64 :: rs := by
    simp [mStps, mPre]
  rw [e] at h
  exact ⟨h.1, h.2.2.1, h.2.2.2.2.1⟩

/-- The counters at `M`'s runs: `c + 1` after `θ`, `c + 1 + (2S + 2)` after the row coefficients. -/
theorem rh_ctr_mask (H : HIn → Dig) (tM : Tr) (c S : ℕ) (mo : Block.MaskOpening) (hc : tM.counter = UInt64.ofNat c) :
    (tM.squeeze H).2.counter = UInt64.ofNat c + UInt64.ofNat 1
      ∧ (runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
          (List.replicate (2 * S + 2) Op.squeeze)).counter
        = UInt64.ofNat c + UInt64.ofNat 1 + UInt64.ofNat (2 * S + 2) := by
  have h1 := ctr_squeeze H tM c hc
  refine ⟨by rw [h1, u64_ofNat_add], ?_⟩
  have h2 := ctr_runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
    (List.replicate (2 * S + 2) Op.squeeze) (c + 1) h1
  rw [sqN_replicate] at h2
  rw [h2, u64_ofNat_add, u64_ofNat_add]

/-! ## `M` alive at the run's parse -/

section M

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig) (domain : List UInt8)
  (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

omit [DecidableEq K] in
include hU in
/-- **`M` IS ALIVE AT THE RUN'S PARSE** (L22's `mask_subSt_of_ok` at the run). The transcript `τ` from `M`'s window `aM`
on is the trace of `M`'s steps on `tM`, then anything; the parse is a step's end at the window and agrees with `M`'s
steps from the window's counter; the verifier's `MaskOk` holds on `tM` at the functionals `fs` the reader returns at
the window (`k` of them) and `M`'s root; the opening is canonical; and the table extracted for the root the header
absorbs at `mpos` is the opened column at every sampled index. Then `M` (at its window `aM`) is alive at the end. -/
theorem rh_M_alive (W : UInt64 → ℕ) (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional) (aM : ℕ)
    (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig)) (tM tA : Tr) (mo : Block.MaskOpening)
    (c : ℕ) (rs : List Stp) (hpl : (τ.take aM).length = aM)
    (hdrop : τ.drop aM = opTrace (liftH G) tM (stpsOps (mStps S mo ++ rs)))
    (hpre : tRem W (τ.take aM) = some 0) (hctr : tM.counter = UInt64.ofNat c)
    (hst : StpOK W (UInt64.ofNat c) (mStps S mo ++ rs)) (root : Dig) (fs : List Block.MaskFunctional)
    (hcan : Block.MaskCanon mo)
    (hok : MaskOk (liftH G) tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) tM tA)
    (hk : fs.length = k) (hrd : fsr (τ.take aM) = fs)
    (hcols : ∀ (j : Fin mQ)
      (hj : (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0 < 2 ^ 12),
      rkColsM tag Lq h64 key domain hs hL mpos P (τ.take aM)
          ⟨(idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0, hj⟩
        = (mo.columns.getD j ⟨0, [], zeroDig, []⟩).col) :
    subSt W ((rkMask U tag Lq h64 key domain hs hL S k mpos fsr).sub U hbij aM P) τ := by
  set pre := τ.take aM with hpreDef
  obtain ⟨hw1, hw2, hw3⟩ := rh_stpOK_mask W _ S mo rs hst
  obtain ⟨hc1, hc2⟩ := rh_ctr_mask (liftH G) tM c S mo hctr
  set rest := opTrace (liftH G) (runOps (liftH G) tM (stpsOps (mStps S mo))) (stpsOps rs) with hrest
  have hch : τ = pre ++ opTrace (liftH G) tM (stpsOps (mStps S mo)) ++ rest := by
    have e := List.take_append_drop aM τ
    rw [hdrop, stpsOps_append, Block.opTrace_append] at e
    rw [List.append_assoc]
    exact e.symm
  have hDm : (rkMask U tag Lq h64 key domain hs hL S k mpos fsr).Dm P pre
      = mDataOf U S k fs (rkColsM tag Lq h64 key domain hs hL mpos P pre) := by
    show mDataOf U S k (fsr pre) (rkColsM tag Lq h64 key domain hs hL mpos P pre) = _
    rw [hrd]
  obtain ⟨-, -, s3⟩ := mask_subSt_of_ok' U hU hbij (liftH G) tag root S fs mo hcan tM tA hok W
    (by rw [hctr]; exact hw1) (by rw [hc1]; exact hw2) (by rw [hc2]; exact hw3) pre rest hpre k hk
    ((rkMask U tag Lq h64 key domain hs hL S k mpos fsr).Dm P) (rkColsM tag Lq h64 key domain hs hL mpos P pre) hDm
    hcols
  rw [hpl, ← hch] at s3
  exact s3

/-- **`M`'s acceptance facts on the run's transcript**, with their witnesses (the premises of `rh_M_alive`). -/
structure RhMW (W : UInt64 → ℕ) (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional) (aM : ℕ)
    (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig)) where
  tM : Tr
  tA : Tr
  mo : Block.MaskOpening
  c : ℕ
  rs : List Stp
  root : Dig
  fs : List Block.MaskFunctional
  hpl : (τ.take aM).length = aM
  hdrop : τ.drop aM = opTrace (liftH G) tM (stpsOps (mStps S mo ++ rs))
  hpre : tRem W (τ.take aM) = some 0
  hctr : tM.counter = UInt64.ofNat c
  hst : StpOK W (UInt64.ofNat c) (mStps S mo ++ rs)
  hcan : Block.MaskCanon mo
  hok : MaskOk (liftH G) tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) tM tA
  hk : fs.length = k
  hrd : fsr (τ.take aM) = fs
  hcols : ∀ (j : Fin mQ)
    (hj : (idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0 < 2 ^ 12),
    rkColsM tag Lq h64 key domain hs hL mpos P (τ.take aM)
        ⟨(idxOf mDom mQ (sqDs (liftH G) (runOps (liftH G) tM (stpsOps (mPre S mo))) 64)).getD j 0, hj⟩
      = (mo.columns.getD j ⟨0, [], zeroDig, []⟩).col

omit [DecidableEq K] in
include hU in
/-- `rh_M_alive` from the witnesses. -/
theorem rh_M_of (W : UInt64 → ℕ) (S k mpos : ℕ) (fsr : List (TItem × Dig) → List Block.MaskFunctional) (aM : ℕ)
    (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (w : RhMW tag Lq h64 key domain hs hL W S k mpos fsr aM P G τ) :
    subSt W ((rkMask U tag Lq h64 key domain hs hL S k mpos fsr).sub U hbij aM P) τ :=
  rh_M_alive U hU hbij tag Lq h64 key domain hs hL W S k mpos fsr aM P G τ w.tM w.tA w.mo w.c w.rs w.hpl w.hdrop
    w.hpre w.hctr w.hst w.root w.fs w.hcan w.hok w.hk w.hrd w.hcols

end M

/-! ## `hal_M` -/

section Hal

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K]
  (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (Lq : ℕ)
  (hL : (startMsg domain).length ≤ Lq) {α : Type} (pf : RtProf) (rd : α → List Op × List RtData)
  (hL64 : Lq < 2 ^ 64) (hv : pf.Valid) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- **`M`'s kind is alive** when, in every part of the run, `M` at the part's `M` window is alive. -/
theorem rh_KM_al (D : RtKData K Lq) (hD : D.Valid (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf) (n : ℕ)
    (lg : List (QB Lq × Dig)) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length →
      subSt (rtW pf.sqs) ((D.msk i).sub U hbij (pf.off i + (pf.part i).pre) lg) τ) :
    (rtKM key domain hs Lq hL pf rd hL64 hv U hbij D hD).Al n lg τ := by
  intro i _ k c hc
  by_cases hi : i < pf.parts.length
  · have hc' : [(D.msk i).sub U hbij (pf.off i + (pf.part i).pre) lg][k]? = some c := by
      simpa [rtKM, rtKind2, hi, RtKPart.ofMask, RtKPart.ofMap] using hc
    have hmem := List.mem_of_getElem? hc'
    rw [List.mem_singleton] at hmem
    rw [hmem]
    exact h i hi
  · simp [rtKM, rtKind2, hi, RtKPart.nil] at hc

variable (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ Lq)

include hU in
/-- **`hal_M` AT THE KINDS DATA BUILT FROM THE VERIFIER'S READERS** (the second ordered cover premise's conclusion,
`(rtKM … D hD).Al n lg τ`): if in every part `M` meets its acceptance facts at its window (`RhMW`: `MaskOk` on the
functionals the reader returns, the extraction at `M`'s root), `M` of every part is alive at the end. -/
theorem rh_hal_M (ps : ℕ → RkPart K Lq) (acc : ℕ → List (TItem × Dig) → Block.Acc) (lsc : ℕ → Block.ZClaim)
    (eL : ℕ)
    (hD : (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL).Valid
      (Exec.Block.absOfC (chainEncB key domain hs Lq hL)) pf)
    (n : ℕ) (lg : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (h : ∀ i, i < pf.parts.length →
      Nonempty (RhMW tag Lq h64 key domain hs hL (rtW pf.sqs) (ps i).S (ps i).k (ps i).mpos
        (fun hdr => (acc i hdr).fs ++ (acc i hdr).hostFs) (pf.off i + (pf.part i).pre) lg G τ)) :
    (rtKM key domain hs Lq hL pf rd hL64 hv U hbij (rkData U tag Lq h64 key domain hs hL pf ps acc lsc eL) hD).Al
      n lg τ := by
  refine rh_KM_al key domain hs Lq hL pf rd hL64 hv U hbij _ hD n lg τ (fun i hi => ?_)
  obtain ⟨w⟩ := h i hi
  exact rh_M_of U hU hbij tag Lq h64 key domain hs hL _ _ _ _ _ _ lg G τ w

end Hal

end ZK60.ProtocolClassify
