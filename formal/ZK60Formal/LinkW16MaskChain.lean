/-
D63 lane L22 (2026-11-07), part 4: **`M` alive at the end of the code's chain** (L20-3's `hexec` for `M`: (a) the
step parse, (b) the field link, (c) the challenge links).

`mask_knowledge_chain_pos`'s event is `M` entering its window with a false claim AND being alive at the end of the
chain (`subSt W (maskCSubX …)`). The block verifier's acceptance must give the second half whenever the claim is
false. Here, for a transcript whose items before `M`'s window are single steps and whose widths agree with `M`'s
runs (`θ`: one squeeze, the row coefficients: `2S + 2`, the indices: `64`):

* `cRd_mStps`: the scheduled reader reads `M`'s three rounds off the trace: `θ`'s digest, `"mask-q"`'s bytes with the
  row coefficients' digests, `"mask-prox"`'s bytes with the index digests, and is frozen after;
* `leNat_append`, `chunk_lo`, `chunk_hi`, **`idxCode_sqDs`**: the code's indices are `idxCode` of the index run's
  digests (`FSOpening.lean`'s derivation, exactly uniform);
* `chalTheta_sqDs`, `chalRows_sqDs`: `θ` and `r` are `chalTheta` / `chalRows` of the digests' halves (`fp2Field`, the
  reading `challengeFp2Of_toK`);
* **`mask_subSt_of_ok`**: if `M`'s check accepted at its window (`MaskOk`), `M`'s data at the window is `mDataOf` of
  the functionals `M` received and a table agreeing with the opened columns at the sampled indices, then `M`'s window
  is at a step's end and `M` is alive at the end of the chain (`subSt W (maskCSubX …)`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.LinkW16Mask

set_option autoImplicit false

namespace ZK60.Exec.Link

open ZK60.Sound
open ZK60.Exec
open ZK60.Circuit (gP GF)
open scoped ENNReal
open Polynomial

/-! ## The digests' chunks are the halves' -/

theorem leNat_append : ∀ (a b : List UInt8), leNat (a ++ b) = leNat a + 256 ^ a.length * leNat b
  | [], b => by simp [leNat]
  | x :: a, b => by
    rw [List.cons_append, leNat, leNat, leNat_append a b, List.length_cons, pow_succ]
    ring

theorem leNat_take8_lt (l : List UInt8) : leNat (l.take 8) < 2 ^ 64 := by
  have h := leNat_lt (l.take 8)
  have hl : (l.take 8).length ≤ 8 := List.length_take_le _ _
  calc leNat (l.take 8) < 256 ^ (l.take 8).length := h
    _ ≤ 256 ^ 8 := Nat.pow_le_pow_right (by norm_num) hl
    _ = 2 ^ 64 := by norm_num

theorem chunk_split (l : List UInt8) (hl : 8 ≤ l.length) :
    leNat (l.take 16) = leNat (l.take 8) + 2 ^ 64 * leNat ((l.drop 8).take 8) := by
  have e : l.take 16 = l.take 8 ++ (l.drop 8).take 8 := by
    rw [show (16 : ℕ) = 8 + 8 from rfl, List.take_add]
  rw [e, leNat_append, List.length_take, min_eq_left hl]
  norm_num

/-- The four chunks of a digest are its halves' low and high 64 bits (`chunkEquiv`), as the code reads them. -/
theorem chunks_halves (d : Dig) :
    leNat (d.toList.take 8) = (halves d).1.val % 2 ^ 64
      ∧ leNat ((d.toList.drop 8).take 8) = (halves d).1.val / 2 ^ 64
      ∧ leNat ((d.toList.drop 16).take 8) = (halves d).2.val % 2 ^ 64
      ∧ leNat (d.toList.drop 24) = (halves d).2.val / 2 ^ 64 := by
  have hd : d.toList.length = 32 := d.2
  have h1 := chunk_split d.toList (by omega)
  have h2 := chunk_split (d.toList.drop 16) (by rw [List.length_drop]; omega)
  have e2 : (d.toList.drop 16).take 16 = d.toList.drop 16 := List.take_of_length_le (by rw [List.length_drop]; omega)
  rw [e2, List.drop_drop] at h2
  have e3 : (d.toList.drop (8 + 16)).take 8 = d.toList.drop 24 :=
    List.take_of_length_le (by rw [List.length_drop]; omega)
  rw [e3] at h2
  have l1 := leNat_take8_lt d.toList
  have l2 := leNat_take8_lt (d.toList.drop 16)
  simp only [halves]
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [h1]; omega
  · rw [h1]; omega
  · rw [h2]; omega
  · rw [h2]; omega

theorem idxVals_getD (b : ℕ) (d : Dig) (r : ℕ) (hr : r < 4) :
    (idxVals b d).getD r 0 = leNat ((chunks8 d).getD r []) &&& (b - 1) := by
  interval_cases r <;> rfl

theorem flatMap_idxVals_getD (b : ℕ) : ∀ (ds : List Dig) (k : ℕ), k < 4 * ds.length →
    (ds.flatMap (idxVals b)).getD k 0 = (idxVals b (ds.getD (k / 4) zeroDig)).getD (k % 4) 0
  | [], k, hk => absurd hk (by simp)
  | d :: ds, k, hk => by
    rw [List.flatMap_cons]
    by_cases h4 : k < 4
    · rw [getD_append' _ _ _ _ (by rw [idxVals_length]; exact h4), Nat.div_eq_of_lt h4, Nat.mod_eq_of_lt h4]
      rfl
    · rw [getD_append_right' _ _ _ _ (by rw [idxVals_length]; omega), idxVals_length,
        flatMap_idxVals_getD b ds (k - 4) (by simp at hk; omega)]
      have e1 : k / 4 = (k - 4) / 4 + 1 := by omega
      have e2 : k % 4 = (k - 4) % 4 := by omega
      rw [e1, e2]
      rfl

/-- One chunk of a digest, as `chunkEquiv` and as the code read it. -/
theorem chunk_eq (d : Dig) (h : ℕ) : ∀ (r : ℕ) (hr : r < 4),
    ((chunkEquiv (halves d) ⟨r, hr⟩ : Fin (2 ^ 64)) : ℕ) % 2 ^ h = leNat ((chunks8 d).getD r []) % 2 ^ h
  | 0, _ => by
    show ((chunkEquiv (halves d) 0 : Fin (2 ^ 64)) : ℕ) % 2 ^ h = leNat (d.toList.take 8) % 2 ^ h
    rw [(chunkEquiv_spec _).1, (chunks_halves d).1]
  | 1, _ => by
    show ((chunkEquiv (halves d) 1 : Fin (2 ^ 64)) : ℕ) % 2 ^ h = leNat ((d.toList.drop 8).take 8) % 2 ^ h
    rw [(chunkEquiv_spec _).2.1, (chunks_halves d).2.1]
  | 2, _ => by
    show ((chunkEquiv (halves d) 2 : Fin (2 ^ 64)) : ℕ) % 2 ^ h = leNat ((d.toList.drop 16).take 8) % 2 ^ h
    rw [(chunkEquiv_spec _).2.2.1, (chunks_halves d).2.2.1]
  | 3, _ => by
    show ((chunkEquiv (halves d) 3 : Fin (2 ^ 64)) : ℕ) % 2 ^ h = leNat (d.toList.drop 24) % 2 ^ h
    rw [(chunkEquiv_spec _).2.2.2, (chunks_halves d).2.2.2]
  | n + 4, hr => absurd hr (by omega)

/-- **The code's indices are `idxCode` of the index run's digests** (for a bound `2^h` and `n ≤ 4m` indices). -/
theorem idxCode_sqDs (h : ℕ) {m n : ℕ} (hnm : n ≤ m * 4) (ds : List Dig) (hds : ds.length = m) (k : Fin n) :
    ((idxCode h hnm (vecOf dg0 m (ds.map halves)) k : Fin (2 ^ h)) : ℕ) = (idxOf (2 ^ h) n ds).getD k 0 := by
  have hk : (k : ℕ) < 4 * ds.length := by rw [hds]; have := k.isLt; omega
  have hk4 : (k : ℕ) / 4 < ds.length := by omega
  rw [idxCode_spec, idxOf, List.getD_eq_getElem?_getD, List.getElem?_take_of_lt k.isLt, ← List.getD_eq_getElem?_getD,
    flatMap_idxVals_getD _ _ _ hk, idxVals_getD _ _ _ (Nat.mod_lt _ (by norm_num)), Nat.and_two_pow_sub_one_eq_mod]
  have hv : vecOf dg0 m (ds.map halves) ⟨(k : ℕ) / 4, by have := k.isLt; omega⟩
      = halves (ds.getD (k / 4) zeroDig) := by
    simp [vecOf, List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hk4]
  rw [hv]
  exact chunk_eq _ h _ _

/-! ## `M`'s rounds read off the trace -/

section Reader

variable (H : HIn → Dig)

theorem stpsOps_mStps_cons (S : ℕ) (mo : Block.MaskOpening) :
    stpsOps (mStps S mo) = Op.squeeze :: Op.absorb Block.labMaskQ (mo.q.flatMap Fp2.toBytes)
      :: (List.replicate (2 * S + 2) Op.squeeze ++ Op.absorb Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)
        :: List.replicate 64 Op.squeeze) := by
  simp [mStps, mPre, stpsOps, Stp.ops]

theorem stpsOps_mPre_split (S : ℕ) (mo : Block.MaskOpening) :
    stpsOps (mPre S mo) = [Op.squeeze, Op.absorb Block.labMaskQ (mo.q.flatMap Fp2.toBytes)]
      ++ (List.replicate (2 * S + 2) Op.squeeze ++ [Op.absorb Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)]) := by
  simp [mPre, stpsOps, Stp.ops]

/-- **The scheduled reader reads `M`'s three rounds** off the trace of `M`'s steps (then is frozen): `θ`'s digest, the
`"mask-q"` bytes with the row coefficients' digests, the `"mask-prox"` bytes with the index digests. -/
theorem cRd_mStps (S : ℕ) (mo : Block.MaskOpening) (W : UInt64 → ℕ) (t : Tr) (rest : List (TItem × Dig))
    (h1 : W t.counter = 1) (h2 : W (t.squeeze H).2.counter = 2 * S + 2)
    (h3 : W (runOps H ((t.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
      (List.replicate (2 * S + 2) Op.squeeze)).counter = 64) :
    cRd (maskRounds S) W (opTrace H t (stpsOps (mStps S mo)) ++ rest)
      = some ([([], [(t.squeeze H).1]),
          (mo.q.flatMap Fp2.toBytes,
            sqDs H ((t.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes)) (2 * S + 2)),
          (mo.prox.flatMap Fp2.toBytes,
            sqDs H ((runOps H ((t.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
              (List.replicate (2 * S + 2) Op.squeeze)).absorb H Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)) 64)],
          none, []) := by
  set qb := mo.q.flatMap Fp2.toBytes with hqb
  set pb := mo.prox.flatMap Fp2.toBytes with hpb
  set t2 := (t.squeeze H).2.absorb H Block.labMaskQ qb with ht2
  set t3 := runOps H t2 (List.replicate (2 * S + 2) Op.squeeze) with ht3
  set t4 := t3.absorb H Block.labMaskProx pb with ht4
  rw [stpsOps_mStps_cons]
  have htr : opTrace H t (Op.squeeze :: Op.absorb Block.labMaskQ qb
      :: (List.replicate (2 * S + 2) Op.squeeze ++ Op.absorb Block.labMaskProx pb :: List.replicate 64 Op.squeeze))
      = (TItem.squeeze t.counter, (t.squeeze H).1) :: (TItem.absorb Block.labMaskQ qb, t2.state)
        :: (opTrace H t2 (List.replicate (2 * S + 2) Op.squeeze)
          ++ (TItem.absorb Block.labMaskProx pb, t4.state) :: opTrace H t4 (List.replicate 64 Op.squeeze)) := by
    rw [opTrace, opTrace, Block.opTrace_append, opTrace]
  rw [htr]
  unfold cRd
  simp only [List.cons_append, List.foldl_cons, List.append_assoc, List.foldl_append]
  have s0 : cRdStep (maskRounds S) W (some ([], none, [])) (TItem.squeeze t.counter, (t.squeeze H).1)
      = some ([([], [(t.squeeze H).1])], none, []) := by
    simp [cRdStep, maskRounds, mW3, h1]
  have s1 : cRdStep (maskRounds S) W (some ([([], [(t.squeeze H).1])], none, [])) (TItem.absorb Block.labMaskQ qb, t2.state)
      = some ([([], [(t.squeeze H).1])], some qb, []) :=
    cRdStep_absorb_msg (maskRounds S) W [([], [(t.squeeze H).1])] Block.labMaskQ qb t2.state
      (by simp [maskRounds]) (by simp [maskRounds]) (by simp [maskRounds]; rfl)
  have h2' : W t2.counter = 2 * S + 2 := h2
  have s2 : (opTrace H t2 (List.replicate (2 * S + 2) Op.squeeze)).foldl (cRdStep (maskRounds S) W)
      (some ([([], [(t.squeeze H).1])], some qb, []))
      = some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2))], none, []) :=
    cRd_run_sq H (maskRounds S) W t2 (2 * S + 2) [([], [(t.squeeze H).1])] (some qb) (by simp [maskRounds])
      (by simp [maskRounds]) (by simp [maskRounds, mW3]) (by omega) h2'
  have s3 : cRdStep (maskRounds S) W (some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2))], none, []))
      (TItem.absorb Block.labMaskProx pb, t4.state)
      = some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2))], some pb, []) :=
    cRdStep_absorb_msg (maskRounds S) W _ Block.labMaskProx pb t4.state (by simp [maskRounds])
      (by simp [maskRounds]) (by simp [maskRounds]; rfl)
  have h3' : W t4.counter = 64 := h3
  have s4 : (opTrace H t4 (List.replicate 64 Op.squeeze)).foldl (cRdStep (maskRounds S) W)
      (some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2))], some pb, []))
      = some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2)), (pb, sqDs H t4 64)], none, []) :=
    cRd_run_sq H (maskRounds S) W t4 64 [([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2))] (some pb)
      (by simp [maskRounds]) (by simp [maskRounds]) (by simp [maskRounds, mW3]) (by omega) h3'
  have s5 : rest.foldl (cRdStep (maskRounds S) W)
      (some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2)), (pb, sqDs H t4 64)], none, []))
      = some ([([], [(t.squeeze H).1]), (qb, sqDs H t2 (2 * S + 2)), (pb, sqDs H t4 64)], none, []) :=
    foldl_cRdStep_frozen (maskRounds S) W (by simp [maskRounds]) rest
  rw [s0, s1, s2, s3, s4, s5]

end Reader

/-! ## `M` alive at the end -/

section Alive

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
  (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

omit [Fintype K] [DecidableEq K] in
include hbij in
theorem chal_toK (d : Dig) : fp2Field gP (2 ^ 128) (Equiv.ofBijective _ hbij) (halves d) = (challengeFp2Of d).toK U :=
  (challengeFp2Of_toK U hbij d).symm

omit [DecidableEq K] in
include hU in
/-- **`M` is alive at the end of the chain when its check accepted** (L20-3's `hexec` for `M`, deterministic). The
chain is any whole-step prefix `pre` (`M`'s window at `pre.length`), then `M`'s steps on the transcript `tM`, then
anything. If `M`'s check accepted at `tM` (`MaskOk`), the widths agree with `M`'s runs, `M`'s data at the window is
`mDataOf` of the functionals `M` received and a table whose columns at the sampled indices are the opened ones, then
`M`'s window is at a step's end and `M` is alive at the end (`subSt W (maskCSubX …)`). -/
theorem mask_subSt_of_ok (H : HIn → Dig) (tag : MTag) (root : Dig) (S : ℕ) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (hcan : Block.MaskCanon mo) (tM tA : Tr)
    (hok : MaskOk H tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) tM tA) (W : UInt64 → ℕ)
    (h1 : W tM.counter = 1) (h2 : W (tM.squeeze H).2.counter = 2 * S + 2)
    (h3 : W (runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
      (List.replicate (2 * S + 2) Op.squeeze)).counter = 64)
    (pre rest : List (TItem × Dig)) (hpre : tRem W pre = some 0)
    (Dm : List (TItem × Dig) → MData K (Fin (2 ^ 12)) (Fin S) (Fin (2 * S + 2)) fs.length 512)
    (cols : Fin (2 ^ 12) → List Fp) (hDm : Dm pre = mDataOf U S fs.length fs cols)
    (hcols : ∀ (k : Fin mQ) (hk : (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD k 0 < 2 ^ 12),
      cols ⟨(idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD k 0, hk⟩
        = (mo.columns.getD k ⟨0, [], zeroDig, []⟩).col) :
    pre.length ≤ (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).length
      ∧ tRem W ((pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).take pre.length) = some 0
      ∧ subSt W (maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega S pre.length Dm (Equiv.refl _) (fun _ => False))
        (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest) := by
  have htake : (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).take pre.length = pre := by
    rw [List.append_assoc, List.take_left' rfl]
  have hdrop : (pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).drop pre.length
      = opTrace H tM (stpsOps (mStps S mo)) ++ rest := by
    rw [List.append_assoc, List.drop_left' rfl]
  refine ⟨by simp, by rw [htake]; exact hpre, Or.inr (Or.inl ⟨?_, ?_⟩)⟩
  · show tRem W ((pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).take pre.length) = some 0
    rw [htake]
    exact hpre
  show liftC ((maskCSubX U (Equiv.ofBijective _ hbij) mEtaE mOmega S pre.length Dm (Equiv.refl _)
      (fun _ => False)).St ((pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).take pre.length))
    (cRd (maskRounds S) W ((pre ++ opTrace H tM (stpsOps (mStps S mo)) ++ rest).drop pre.length))
  rw [hdrop, htake, cRd_mStps H S mo W tM rest h1 h2 h3]
  have hJ : ∀ k : Fin mQ, (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD k 0 < 2 ^ 12 := by
    intro k
    rw [List.getD_eq_getElem?_getD]
    rcases hk : (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64))[(k : ℕ)]? with _ | v
    · simp
    · exact idxOf_lt mDom mQ (by decide) _ v (List.mem_of_getElem? hk)
  have hT4 : runOps H tM (stpsOps (mPre S mo))
      = (((tM.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
          maskProxLabel mo.prox := by
    rw [stpsOps_mPre_split, runOps_append, runOps_append, challengeFp2Vec_sqDs]
    rfl
  have hidx : ((((tM.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
      maskProxLabel mo.prox).challengeIndices H mQ mDom
      = some (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64), tA) := by
    obtain ⟨-, -, -, idx', hidx', -, -⟩ := hok
    have hc := challengeIndices_sqDs H mQ mDom (runOps H tM (stpsOps (mPre S mo))) (by decide) (by decide)
    rw [show (mQ + 3) / 4 = 64 from rfl] at hc
    have e2 : some (idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64),
        runOps H (runOps H tM (stpsOps (mPre S mo))) (List.replicate 64 Op.squeeze)) = some (idx', tA) := by
      rw [← hc, hT4]
      exact hidx'
    simp only [Option.some.injEq, Prod.mk.injEq] at e2
    rw [← e2.2, ← hT4]
    exact hc
  have hfin := maskOk_mFinal U hU H tag root S fs mo hcan tM tA hok _ hidx hJ cols (fun k => hcols k (hJ k))
  have hq : decPoly U 1024 (mo.q.flatMap Fp2.toBytes) = some (coefPoly (vecK U 1024 mo.q)) :=
    decPoly_enc U 1024 mo.q hcan.1 hok.1
  have hp : decPoly U 1024 (mo.prox.flatMap Fp2.toBytes) = some (coefPoly (vecK U 1024 mo.prox)) :=
    decPoly_enc U 1024 mo.prox hcan.2.1 hok.2.2.1
  have eθ : chalTheta gP (Equiv.ofBijective _ hbij) (vecOf dg0 1 [halves (tM.squeeze H).1])
      = (tM.challengeFp2 H).1.toK U := chal_toK U hbij _
  have er : chalRows gP (Equiv.ofBijective _ hbij) (Equiv.refl (Fin (2 * S + 2))) (vecOf dg0 (2 * S + 2)
      ((sqDs H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes)) (2 * S + 2)).map halves))
      = fun i : Fin (2 * S + 2) => (((((tM.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q).challengeFp2Vec H
          (2 * S + 2)).1).getD i Fp2.zero).toK U := by
    funext i
    have hil : (i : ℕ) < (sqDs H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
        (2 * S + 2)).length := by rw [sqDs_length]; exact i.isLt
    rw [challengeFp2Vec_sqDs]
    have e : (tM.challengeFp2 H).2.absorbFp2 H maskQLabel mo.q
        = (tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes) := rfl
    rw [e]
    simp only [chalRows, vecOf, Equiv.refl_apply]
    rw [List.getD_eq_getElem?_getD, List.getElem?_map, List.getElem?_eq_getElem hil, List.getD_eq_getElem?_getD,
      List.getElem?_map, List.getElem?_eq_getElem hil]
    simp only [Option.map_some, Option.getD_some]
    exact chal_toK U hbij _
  have e4 : (runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes))
      (List.replicate (2 * S + 2) Op.squeeze)).absorb H Block.labMaskProx (mo.prox.flatMap Fp2.toBytes)
      = runOps H tM (stpsOps (mPre S mo)) := by
    rw [stpsOps_mPre_split, runOps_append, runOps_append]
    rfl
  have eJ : idxCode 12 (show 256 ≤ 64 * 4 by norm_num) (vecOf dg0 64
      ((sqDs H ((runOps H ((tM.squeeze H).2.absorb H Block.labMaskQ
        (mo.q.flatMap Fp2.toBytes)) (List.replicate (2 * S + 2) Op.squeeze)).absorb H Block.labMaskProx
        (mo.prox.flatMap Fp2.toBytes)) 64).map halves))
      = fun k : Fin mQ => (⟨(idxOf mDom mQ (sqDs H (runOps H tM (stpsOps (mPre S mo))) 64)).getD k 0, hJ k⟩
          : Fin (2 ^ 12)) := by
    funext k
    apply Fin.ext
    rw [idxCode_sqDs 12 _ _ (sqDs_length _ _ _), e4]
    rfl
  show MFinal mEtaE mOmega 1023 (Dm pre)
    (chalTheta gP (Equiv.ofBijective _ hbij) (vecOf dg0 1 [halves (tM.squeeze H).1]))
    (decPoly U 1024 (mo.q.flatMap Fp2.toBytes))
    (chalRows gP (Equiv.ofBijective _ hbij) (Equiv.refl (Fin (2 * S + 2))) (vecOf dg0 (2 * S + 2)
      ((sqDs H ((tM.squeeze H).2.absorb H Block.labMaskQ (mo.q.flatMap Fp2.toBytes)) (2 * S + 2)).map halves)))
    (decPoly U 1024 (mo.prox.flatMap Fp2.toBytes))
    (idxCode 12 (show 256 ≤ 64 * 4 by norm_num) (vecOf dg0 64 ((sqDs H ((runOps H ((tM.squeeze H).2.absorb H
      Block.labMaskQ (mo.q.flatMap Fp2.toBytes)) (List.replicate (2 * S + 2) Op.squeeze)).absorb H Block.labMaskProx
      (mo.prox.flatMap Fp2.toBytes)) 64).map halves)))
  rw [hq, hp, hDm, eθ, er, eJ]
  exact hfin

end Alive

/-! ## The block verifier's `M` check, accepted -/

/-- **An accepting block verifier with L10's `M` field** (`P.maskVerify = maskField tag S`, W16R2's and R13's) accepted
`M` at the slots' end: `MaskOk` holds there, on the functionals `acc.fs ++ acc.hostFs`, and the transcript after `M` is
`runOps` of `M`'s steps. -/
theorem blockVerify_mask (tag : MTag) (S : ℕ) (H : HIn → Dig) (P : Block.BlockParams)
    (hPm : P.maskVerify = maskField tag S) (core : Block.Core) (t : Tr)
    (io : List Block.ZClaim × List Block.ZClaim) (t' : Tr) (h : Block.blockVerify H P core t = .ok (io, t'))
    (hd : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape P i).2.2) :
    ∃ bga rs acc tA, Block.blockSlots H P core t
        = .ok (bga, rs, acc, runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots))
      ∧ (acc.fs ++ acc.hostFs).length = P.nFunctionals
      ∧ MaskOk H tag (rootFp 9) (rootFp 12) core.maskRoot S ((acc.fs ++ acc.hostFs).map toMF) (toMO core.maskOpen)
          (runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots)) tA
      ∧ tA = runOps H (runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots))
          (stpsOps (mStps S core.maskOpen)) := by
  obtain ⟨bga, rs, acc, tM, tA, tH, hbs, hnf, hmv, -, -⟩ := blockVerify_ok H P core t io t' h
  have htM := blockSlots_tr H P core t bga rs acc tM hbs hd
  subst htM
  rw [hPm] at hmv
  have hmo : MaskOk H tag (rootFp 9) (rootFp 12) core.maskRoot S ((acc.fs ++ acc.hostFs).map toMF)
      (toMO core.maskOpen) (runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots)) tA := by
    have h1 := hmv
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h1
    exact h1
  obtain ⟨th, rs', idx, hmt⟩ := maskField_transcript tag S H _ _ _ _ _ hmv
  have hrun := (maskTranscript_runOps H S core.maskOpen _ th rs' idx tA hmt).2.2.2.1
  exact ⟨bga, rs, acc, tA, hbs, hnf, hmo, hrun⟩

/-- The regular opening's `(λ, ρ)` vector has one entry per claim and one per row (`group_zclaims` holds each claim
once). -/
theorem groupCounts_sum (cl : List Block.ZClaim) (rows logCols : ℕ) :
    ((groupZclaims (cl.map toZClaim) rows logCols).map (·.2.length)).sum = cl.length := by
  rw [groupZclaims_count, List.length_map]

/-- **The accepting block verifier's whole run, as steps** (L20-3 (a), at the fields of W16R2: `maskField`,
`pcsField`): the transcript after `verify_core` is `runOps` of the roots', the slots', `M`'s, `A`'s and `H`'s steps, `A`'s
`(λ, ρ)` vector `#claims + rows` wide, `H`'s with its LogUp sum claim, each index run `⌈280/4⌉ = 70` squeezes. -/
theorem blockVerify_run_w16r2 (tag : MTag) (S : ℕ) (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (P : Block.BlockParams)
    (hPm : P.maskVerify = maskField tag S) (hPp : P.pcsVerify = pcsField tag rowsOf) (core : Block.Core) (t : Tr)
    (io : List Block.ZClaim × List Block.ZClaim) (t' : Tr) (h : Block.blockVerify H P core t = .ok (io, t'))
    (hd : ∀ i, i < core.slots.length → 1 ≤ (Block.slotShape P i).2.2) :
    ∃ bga rs acc, Block.blockSlots H P core t
        = .ok (bga, rs, acc, runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots))
      ∧ t' = runOps H t (Block.rootOps P core ++ Block.fullOps P 0 core.slots ++ stpsOps (mStps S core.maskOpen)
          ++ stpsOps (pcsStps (acc.claims.a.length + rowsOf .a) 70 core.aOpen)
          ++ stpsOps (pcsStps ((acc.claims.h ++ [P.logupSumClaim]).length + rowsOf .h) 70 core.hOpen)) := by
  obtain ⟨bga, rs, acc, tM, tA, tH, hbs, -, hmv, hpa, hph⟩ := blockVerify_ok H P core t io t' h
  have htM := blockSlots_tr H P core t bga rs acc tM hbs hd
  subst htM
  rw [hPm] at hmv
  rw [hPp] at hpa hph
  obtain ⟨th, rs', idx, hmt⟩ := maskField_transcript tag S H _ _ _ _ _ hmv
  have hA := (maskTranscript_runOps H S core.maskOpen _ th rs' idx tA hmt).2.2.2.1
  obtain ⟨la, ra, ia, hta⟩ := pcsField_transcript tag rowsOf H _ _ _ _ _ _ hpa
  have hH := (pcsTranscript_runOps H _ _ _ _ (by decide) (by decide) _ _ la ra ia tH hta).2.2.2.1
  obtain ⟨lh, rh, ih, hth⟩ := pcsField_transcript tag rowsOf H _ _ _ _ _ _ hph
  have hF := (pcsTranscript_runOps H _ _ _ _ (by decide) (by decide) _ _ lh rh ih t' hth).2.2.2.1
  rw [groupCounts_sum] at hH hF
  have e70 : (w16r2Prm.nQ + 3) / 4 = 70 := rfl
  rw [e70] at hH hF
  refine ⟨bga, rs, acc, hbs, ?_⟩
  rw [hF, hH, hA]
  simp only [runOps_append]

end ZK60.Exec.Link
