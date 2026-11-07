/-
D63 lane L10 (2026-11-07): **`M`'s test, executable** (`hashline/src/zk.rs` `mask_verify_tagged` and
`combined_weights`, read 2026-11-07; nothing there is changed), on L5's transcript and Merkle check and this lane's
column evaluation (`ExecOpening.lean`).

**What is mirrored** (`maskVerify`, in the code's order). `M` commits `2·S + 4` base rows (per mask `s` its re and im
rows, then `b_re, b_im, u_re, u_im`), each the evaluations on the coset `7·G_4096` of a polynomial of `< 1024`
coefficients:
* `θ = challenge_fp2()`; `combined_weights` (`combinedWeights`): functional `i` weighted by `θ^(i+1)` (the powers START
  AT `θ^1`: D65(1), the fix of finding F12), per mask the weights over the 512 message positions and the combined
  value `V`; the code's assertion on the weights' length (the verifier's own functionals) is not mirrored;
* `q'` has `1024` entries; the sum check `(q'_0 + q'_512)·512 = V` on the words; `absorb_fp2("mask-q", q')`;
  `r = challenge_fp2_vec(2·S + 2)`; the proximity vector has `1024` entries; `absorb_fp2("mask-prox", prox)`;
  `challenge_indices(256, 4096)`; the column count;
* per column, in order: the index, the length `2·S + 4`, the path length `12` (F9), the salted leaf and the path
  (keyed), the product check `b(η) + Σ_s a_s(η)·p_{W_s}(η) = q'(η)` and the proximity check
  `u(η) + Σ_row r_row·row(η) = prox(η)`, on the words (`a_s = col[2s] + U·col[2s+1]`, `b`, `u` likewise).
The encodings at the column: `p_{W_s}(η)` by the barycentric form on `G_512` (`weight_polys` is the interpolant;
`ExecOpeningCode.lean`'s `bary_eval`), `q'(η)` and `prox(η)` against the powers of `η` (`encode_coeffs_coset`).

**What is proved** (only `propext`, `Classical.choice`, `Quot.sound`):
* **`maskVerify_ok_iff`**: `maskVerify` returns `ok t'` EXACTLY WHEN every listed check holds (`MaskOk`);
* **`toK_combinedWeights`**: the combined weights and value are `SoundMProduct.lean`'s `mW 1` and `mV 1` of the
  functionals read in `K` (offset `o = 1`: the fixed code);
* `sum_iff_K`: the sum check is the field equation `512·(q'_0 + q'_512) = V(θ)`;
* **`mcol_iff_K`**: a column's two word checks are the field equations of `SoundMProduct.lean`'s `MAccept` at the
  column's point: `b(η) + Σ_s a_s(η)·(mInterp ω (W_s))(η) = q'(η)` and `u(η) + Σ_row r_row·row(η) = prox(η)`, with
  `q'`, `prox` the polynomials of the sent coefficients (`coefPoly`), for canonical column entries (the decoder's,
  L5-2).
-/
import ZK60Formal.ExecOpening

set_option autoImplicit false

namespace ZK60.Exec

open Polynomial Finset
open ZK60.Circuit (gP GF)
open ZK60.Sound (mPts mInterp mW mV)

/-! ## The data -/

/-- `MaskFunctional`: `Σ_{(s, w) ∈ terms} ⟨a_s, w⟩ = value`. -/
structure MaskFunctional where
  terms : List (ℕ × List Fp2)
  value : Fp2

/-- `MaskOpening`: `q'` (1024 coefficients), the proximity vector (1024), the opened columns. -/
structure MaskOpening where
  q : List Fp2
  prox : List Fp2
  columns : List OCol

/-- The refusals of `mask_verify_tagged`, in the code's order. -/
inductive MErr
  | qLen
  | sum
  | proxLen
  | indices
  | nCols
  | colIndex (j : ℕ)
  | colLen (j : ℕ)
  | pathLen (j : ℕ)
  | merkle (j : ℕ)
  | product (j : ℕ)
  | prox (j : ℕ)
  deriving DecidableEq, Repr

/-- `M`'s constants (`zk.rs`): `2^9` message positions, `2^12` evaluation points, `256` opened columns. -/
def mMsg : ℕ := 512
def mDom : ℕ := 4096
def mQ : ℕ := 256

/-- `"mask-q"`, `"mask-prox"`. -/
def maskQLabel : List UInt8 := [109, 97, 115, 107, 45, 113]
def maskProxLabel : List UInt8 := [109, 97, 115, 107, 45, 112, 114, 111, 120]

/-! ## `combined_weights` -/

section Combined

/-- `ws[row][j] += th·w[j]` for the `w.len()` first positions. -/
def addPrefix (th : Fp2) : List Fp2 → List Fp2 → List Fp2
  | a :: r, x :: w => a.add (th.mul x) :: addPrefix th r w
  | r, [] => r
  | [], _ :: _ => []

/-- Row `row` of the weights, updated. -/
def addRow (th : Fp2) (w : List Fp2) : List (List Fp2) → ℕ → List (List Fp2)
  | [], _ => []
  | r :: rs, 0 => addPrefix th r w :: rs
  | r :: rs, i + 1 => r :: addRow th w rs i

/-- One functional's step: its terms added with weight `th`, its value to `V`, then `th ← th·θ`. -/
def cwStep (θ : Fp2) (st : List (List Fp2) × Fp2 × Fp2) (f : MaskFunctional) : List (List Fp2) × Fp2 × Fp2 :=
  (f.terms.foldl (fun ws t => addRow st.2.2 t.2 ws t.1) st.1, st.2.1.add (st.2.2.mul f.value), st.2.2.mul θ)

/-- **`combined_weights`** (`th` starts at `θ`: D65(1)): per mask the 512 combined weights, and the combined value. -/
def combinedWeights (S : ℕ) (fs : List MaskFunctional) (θ : Fp2) : List (List Fp2) × Fp2 :=
  let r := fs.foldl (cwStep θ) (List.replicate S (List.replicate mMsg Fp2.zero), Fp2.zero, θ)
  (r.1, r.2.1)

end Combined

/-! ## The verifier -/

section Verify

variable (H : HIn → Dig) (tag : MTag)

/-- `Fp2::new(col[a], col[b])`. -/
def fp2Of (col : List Fp) (a b : ℕ) : Fp2 := ⟨col.getD a Fp.zero, col.getD b Fp.zero⟩

/-- The product check's left side: `b(η) + Σ_s a_s(η)·w_s(η)` (`acc`, in the code's order). -/
def mProdAcc (S : ℕ) (col : List Fp) (wv : List Fp2) : Fp2 :=
  (List.range S).foldl (fun acc s => acc.add ((fp2Of col (2 * s) (2 * s + 1)).mul (wv.getD s Fp2.zero)))
    (fp2Of col (2 * S) (2 * S + 1))

/-- The proximity check's left side: `u(η) + Σ_row r_row·row(η)` (`pacc`). -/
def mProxAcc (S : ℕ) (col : List Fp) (rs : List Fp2) : Fp2 :=
  (rs.zip col).foldl (fun acc p => acc.add (p.1.mulBase p.2)) (fp2Of col (2 * S + 2) (2 * S + 3))

/-- **The encodings at a column** (`w_enc`, `q_enc`, `p_enc` at `j`): per mask `p_{W_s}(η)` (the barycentric form on
`G_512`, shared weights), `q'(η)`, `prox(η)`. -/
def mEnc (ω512 : Fp) (ws : List (List Fp2)) (q prox : List Fp2) (x : Fp) : List Fp2 × Fp2 × Fp2 :=
  let bw := baryW (powList ω512 mMsg) x
  let sc := baryScale mMsg x
  let px := powList x (2 * mMsg)
  (ws.map (fun w => (dotB w bw).mulBase sc), dotB q px, dotB prox px)

/-- Each opened column, in order; the first failure. -/
def mColsCheck (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (ws : List (List Fp2)) (q prox rs : List Fp2) :
    List OCol → List ℕ → Option MErr
  | (j, col, salt, path) :: cs, wj :: wjs =>
    if j ≠ wj then some (.colIndex j)
    else if col.length ≠ 2 * S + 4 then some (.colLen j)
    else if path.length ≠ 12 then some (.pathLen j)
    else if verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = false then some (.merkle j)
    else
      let e := mEnc ω512 ws q prox (cosetPt ω4096 j)
      if mProdAcc S col e.1 ≠ e.2.1 then some (.product j)
      else if mProxAcc S col rs ≠ e.2.2 then some (.prox j)
      else mColsCheck ω512 ω4096 root S ws q prox rs cs wjs
  | _, _ => none

/-- **`zk::mask_verify_tagged`**, executable. `ω512`, `ω4096` are the NTT's roots of orders `512` and `4096`;
`specs` the masks (only their count `S` is read by the verifier); on acceptance, the transcript after the call. -/
def maskVerify (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (fs : List MaskFunctional) (op : MaskOpening) (t : Tr) :
    Except MErr Tr :=
  let r0 := t.challengeFp2 H
  let cw := combinedWeights S fs r0.1
  if op.q.length ≠ 2 * mMsg then .error .qLen
  else if ((op.q.getD 0 Fp2.zero).add (op.q.getD mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat mMsg)) ≠ cw.2
    then .error .sum
  else
    let r1 := (r0.2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)
    if op.prox.length ≠ 2 * mMsg then .error .proxLen
    else
      match (r1.2.absorbFp2 H maskProxLabel op.prox).challengeIndices H mQ mDom with
      | none => .error .indices
      | some (idx, t5) =>
        if op.columns.length ≠ idx.length then .error .nCols
        else match mColsCheck H tag ω512 ω4096 root S cw.1 op.q op.prox r1.1 op.columns idx with
          | some e => .error e
          | none => .ok t5

/-- **One column's checks**, as the code runs them. -/
def MColOk (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (ws : List (List Fp2)) (q prox rs : List Fp2) (c : OCol)
    (wj : ℕ) : Prop :=
  c.1 = wj ∧ c.2.1.length = 2 * S + 4 ∧ c.2.2.2.length = 12
    ∧ verifyPath H tag root c.1 (saltLeaf H tag (colDigest H tag c.2.1) c.2.2.1) c.2.2.2 = true
    ∧ mProdAcc S c.2.1 (mEnc ω512 ws q prox (cosetPt ω4096 c.1)).1 = (mEnc ω512 ws q prox (cosetPt ω4096 c.1)).2.1
    ∧ mProxAcc S c.2.1 rs = (mEnc ω512 ws q prox (cosetPt ω4096 c.1)).2.2

theorem mColsCheck_cons (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (ws : List (List Fp2)) (q prox rs : List Fp2)
    (j : ℕ) (col : List Fp) (salt : Dig) (path : List Dig) (cs : List OCol) (wj : ℕ) (wjs : List ℕ) :
    mColsCheck H tag ω512 ω4096 root S ws q prox rs ((j, col, salt, path) :: cs) (wj :: wjs)
      = if j ≠ wj then some (.colIndex j)
        else if col.length ≠ 2 * S + 4 then some (.colLen j)
        else if path.length ≠ 12 then some (.pathLen j)
        else if verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = false then some (.merkle j)
        else
          let e := mEnc ω512 ws q prox (cosetPt ω4096 j)
          if mProdAcc S col e.1 ≠ e.2.1 then some (.product j)
          else if mProxAcc S col rs ≠ e.2.2 then some (.prox j)
          else mColsCheck H tag ω512 ω4096 root S ws q prox rs cs wjs := rfl

theorem mColsCheck_none_iff (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (ws : List (List Fp2)) (q prox rs : List Fp2) :
    ∀ (cs : List OCol) (wjs : List ℕ), cs.length = wjs.length →
      (mColsCheck H tag ω512 ω4096 root S ws q prox rs cs wjs = none
        ↔ ∀ k, k < cs.length →
            MColOk H tag ω512 ω4096 root S ws q prox rs (cs.getD k (0, [], zeroDig, [])) (wjs.getD k 0))
  | [], [], _ => ⟨fun _ k hk => absurd hk (Nat.not_lt_zero _), fun _ => rfl⟩
  | (j, col, salt, path) :: cs, wj :: wjs, h => by
    have ih := mColsCheck_none_iff ω512 ω4096 root S ws q prox rs cs wjs (by simpa using h)
    rw [mColsCheck_cons]
    by_cases ha : j = wj
    swap
    · rw [if_pos ha]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => ha (by simpa [MColOk] using h0.1)⟩
    rw [if_neg (not_not.mpr ha)]
    by_cases hb : col.length = 2 * S + 4
    swap
    · rw [if_pos hb]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => hb (by simpa [MColOk] using h0.2.1)⟩
    rw [if_neg (not_not.mpr hb)]
    by_cases hc : path.length = 12
    swap
    · rw [if_pos hc]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => hc (by simpa [MColOk] using h0.2.2.1)⟩
    rw [if_neg (not_not.mpr hc)]
    by_cases hd : verifyPath H tag root j (saltLeaf H tag (colDigest H tag col) salt) path = true
    swap
    · rw [if_pos (by simpa using hd)]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => hd (by simpa [MColOk] using h0.2.2.2.1)⟩
    rw [if_neg (by simp [hd])]
    simp only
    by_cases he : mProdAcc S col (mEnc ω512 ws q prox (cosetPt ω4096 j)).1 = (mEnc ω512 ws q prox (cosetPt ω4096 j)).2.1
    swap
    · rw [if_pos he]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => he (by simpa [MColOk] using h0.2.2.2.2.1)⟩
    rw [if_neg (not_not.mpr he)]
    by_cases hf : mProxAcc S col rs = (mEnc ω512 ws q prox (cosetPt ω4096 j)).2.2
    swap
    · rw [if_pos hf]
      simp only [reduceCtorEq, false_iff, not_forall]
      exact ⟨0, by simp, fun h0 => hf (by simpa [MColOk] using h0.2.2.2.2.2)⟩
    rw [if_neg (not_not.mpr hf), ih]
    constructor
    · intro hall k hk
      rcases k with _ | k
      · simpa [MColOk] using ⟨ha, hb, hc, hd, he, hf⟩
      · simpa using hall k (by simpa using hk)
    · intro hall k hk
      simpa using hall (k + 1) (by simpa using hk)
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h

/-- **Everything `mask_verify_tagged` checks**, given the transcript `t` before the call; `t'` the one after. -/
def MaskOk (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (fs : List MaskFunctional) (op : MaskOpening) (t t' : Tr) :
    Prop :=
  op.q.length = 2 * mMsg
    ∧ ((op.q.getD 0 Fp2.zero).add (op.q.getD mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat mMsg))
      = (combinedWeights S fs (t.challengeFp2 H).1).2
    ∧ op.prox.length = 2 * mMsg
    ∧ ∃ idx, ((((t.challengeFp2 H).2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
          maskProxLabel op.prox).challengeIndices H mQ mDom = some (idx, t')
      ∧ op.columns.length = idx.length
      ∧ ∀ k, k < op.columns.length →
          MColOk H tag ω512 ω4096 root S (combinedWeights S fs (t.challengeFp2 H).1).1 op.q op.prox
            (((t.challengeFp2 H).2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)).1
            (op.columns.getD k (0, [], zeroDig, [])) (idx.getD k 0)

/-- **The executable `M` verifier accepts EXACTLY when every check holds**, for every hash function. -/
theorem maskVerify_ok_iff (ω512 ω4096 : Fp) (root : Dig) (S : ℕ) (fs : List MaskFunctional) (op : MaskOpening)
    (t t' : Tr) :
    maskVerify H tag ω512 ω4096 root S fs op t = .ok t' ↔ MaskOk H tag ω512 ω4096 root S fs op t t' := by
  unfold maskVerify MaskOk
  simp only
  by_cases h1 : op.q.length = 2 * mMsg
  swap
  · rw [if_pos h1]
    exact ⟨fun h => absurd h (by simp), fun h => absurd h.1 h1⟩
  rw [if_neg (not_not.mpr h1)]
  by_cases h2 : ((op.q.getD 0 Fp2.zero).add (op.q.getD mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat mMsg))
      = (combinedWeights S fs (t.challengeFp2 H).1).2
  swap
  · rw [if_pos h2]
    exact ⟨fun h => absurd h (by simp), fun h => absurd h.2.1 h2⟩
  rw [if_neg (not_not.mpr h2)]
  by_cases h3 : op.prox.length = 2 * mMsg
  swap
  · rw [if_pos h3]
    exact ⟨fun h => absurd h (by simp), fun h => absurd h.2.2.1 h3⟩
  rw [if_neg (not_not.mpr h3)]
  cases hi : ((((t.challengeFp2 H).2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
      maskProxLabel op.prox).challengeIndices H mQ mDom with
  | none => simp [h1, h2, h3]
  | some it =>
    obtain ⟨idx, t5⟩ := it
    simp only [Option.some.injEq, Prod.mk.injEq]
    by_cases h5 : op.columns.length = idx.length
    swap
    · rw [if_pos h5]
      simp only [reduceCtorEq, false_iff, not_and, not_exists]
      intro _ _ _ idx' hidx h5'
      obtain ⟨rfl, -⟩ := hidx
      exact absurd h5' h5
    rw [if_neg (not_not.mpr h5)]
    have hcc := mColsCheck_none_iff H tag ω512 ω4096 root S (combinedWeights S fs (t.challengeFp2 H).1).1 op.q
      op.prox (((t.challengeFp2 H).2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)).1 op.columns idx h5
    cases hc : mColsCheck H tag ω512 ω4096 root S (combinedWeights S fs (t.challengeFp2 H).1).1 op.q op.prox
        (((t.challengeFp2 H).2.absorbFp2 H maskQLabel op.q).challengeFp2Vec H (2 * S + 2)).1 op.columns idx with
    | some e =>
      simp only [reduceCtorEq, false_iff, not_and, not_exists]
      intro _ _ _ idx' hidx _ hall'
      obtain ⟨rfl, -⟩ := hidx
      have := hcc.mpr hall'
      rw [hc] at this
      exact absurd this (by simp)
    | none =>
      simp only [Except.ok.injEq]
      constructor
      · rintro rfl
        exact ⟨h1, h2, h3, idx, ⟨rfl, rfl⟩, h5, hcc.mp hc⟩
      · rintro ⟨-, -, -, idx', ⟨rfl, rfl⟩, -, -⟩
        rfl

end Verify

/-! ## In the field -/

section K

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The sum check is the field equation** `512·(q'_0 + q'_512) = V` (both words canonical). -/
theorem sum_iff_K (hU : U ^ 2 = algebraMap GF K 7) (q : List Fp2) (hq : ∀ a ∈ q, a.Canon) (v : Fp2) (hv : v.Canon) :
    ((q.getD 0 Fp2.zero).add (q.getD mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat mMsg)) = v
      ↔ (mMsg : K) * ((q.getD 0 Fp2.zero).toK U + (q.getD mMsg Fp2.zero).toK U) = v.toK U := by
  have hval : (((q.getD 0 Fp2.zero).add (q.getD mMsg Fp2.zero)).mulBase (Fp.new (UInt64.ofNat mMsg))).toK U
      = (mMsg : K) * ((q.getD 0 Fp2.zero).toK U + (q.getD mMsg Fp2.zero).toK U) := by
    rw [Fp2.toK_mulBase, Fp2.toK_add U _ _ (Fp2.canon_getD hq 0) (Fp2.canon_getD hq mMsg),
      Fp.new_toGF_ofNat mMsg (by norm_num [mMsg]), map_natCast, mul_comm]
  rw [← hval]
  exact ⟨fun h => by rw [h], fun h => Fp2.toK_injective U hU (Fp2.canon_mulBase _ _) hv h⟩

/-- The value of `Fp2::new(col[a], col[b])` in `K`. -/
theorem toK_fp2Of (col : List Fp) (a b : ℕ) :
    (fp2Of col a b).toK U = algebraMap GF K (col.getD a Fp.zero).toGF + U * algebraMap GF K (col.getD b Fp.zero).toGF := by
  simp [fp2Of, Fp2.toK, ZK60.Hiding.fp2]

theorem canon_fp2Of {col : List Fp} (hc : ∀ x ∈ col, x.Canon) (a b : ℕ) : (fp2Of col a b).Canon := by
  have h : ∀ i, (col.getD i Fp.zero).Canon := by
    intro i
    rw [List.getD_eq_getElem?_getD]
    cases h' : col[i]? with
    | none => exact (by decide : Fp.zero.Canon)
    | some x =>
      obtain ⟨hi, rfl⟩ := List.getElem?_eq_some_iff.mp h'
      exact hc _ (List.getElem_mem hi)
  exact ⟨h a, h b⟩

theorem foldl_prodAcc (hU : U ^ 2 = algebraMap GF K 7) (col : List Fp) (wv : List Fp2) :
    ∀ (l : List ℕ) (acc : Fp2), acc.Canon →
      (l.foldl (fun acc s => acc.add ((fp2Of col (2 * s) (2 * s + 1)).mul (wv.getD s Fp2.zero))) acc).toK U
        = acc.toK U + (l.map (fun s => (fp2Of col (2 * s) (2 * s + 1)).toK U * (wv.getD s Fp2.zero).toK U)).sum := by
  intro l
  induction l with
  | nil => intro acc _; simp
  | cons s l ih =>
    intro acc hacc
    rw [List.foldl_cons, ih _ (Fp2.canon_add _ _), Fp2.toK_add U _ _ hacc (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
      List.map_cons, List.sum_cons]
    ring

/-- **The product check's left side in `K`**: `b(η) + Σ_s a_s(η)·w_s`. -/
theorem toK_mProdAcc (hU : U ^ 2 = algebraMap GF K 7) (S : ℕ) (col : List Fp) (hc : ∀ x ∈ col, x.Canon)
    (wv : List Fp2) :
    (mProdAcc S col wv).toK U
      = (fp2Of col (2 * S) (2 * S + 1)).toK U
        + ∑ s : Fin S, (fp2Of col (2 * s) (2 * s + 1)).toK U * (wv.getD s Fp2.zero).toK U := by
  rw [mProdAcc, foldl_prodAcc U hU col wv _ _ (canon_fp2Of hc _ _)]
  congr 1
  rw [Finset.sum_fin_eq_sum_range, ← List.sum_toFinset _ (List.nodup_range), List.toFinset_range]
  refine Finset.sum_congr rfl fun s hs => ?_
  rw [dif_pos (Finset.mem_range.mp hs)]

theorem foldl_proxAcc (rs : List Fp2) (col : List Fp) :
    ∀ (l : List (Fp2 × Fp)) (acc : Fp2), acc.Canon →
      (l.foldl (fun acc p => acc.add (p.1.mulBase p.2)) acc).toK U
        = acc.toK U + (l.map (fun p => p.1.toK U * algebraMap GF K p.2.toGF)).sum :=
  fun l acc hacc => foldl_dotB U l acc hacc

theorem zip_take_len {α β : Type} : ∀ (l : List α) (l' : List β) (m : ℕ), l.length = m → l.zip (l'.take m) = l.zip l'
  | [], _, _, _ => by simp
  | _ :: _, _, 0, h => by simp at h
  | _ :: _, [], _ + 1, _ => by simp
  | a :: l, b :: l', m + 1, h => by
    rw [List.take_succ_cons, List.zip_cons_cons, List.zip_cons_cons, zip_take_len l l' m (by simpa using h)]

/-- **The proximity check's left side in `K`**: `u(η) + Σ_row r_row·row(η)`. -/
theorem toK_mProxAcc (S : ℕ) (col : List Fp) (hc : ∀ x ∈ col, x.Canon) (rs : List Fp2) (m : ℕ)
    (hr : rs.length = m) (hcl : m ≤ col.length) :
    (mProxAcc S col rs).toK U
      = (fp2Of col (2 * S + 2) (2 * S + 3)).toK U
        + ∑ i : Fin m, (rs.getD i Fp2.zero).toK U * algebraMap GF K (col.getD i Fp.zero).toGF := by
  have h := toK_dotB U rs (col.take m) m hr (by rw [List.length_take]; omega)
  unfold dotB at h
  rw [foldl_dotB U _ _ Fp2.canon_zero, Fp2.toK_zero, zero_add] at h
  rw [mProxAcc, foldl_dotB U _ _ (canon_fp2Of hc _ _)]
  congr 1
  rw [← zip_take_len rs col m hr, h]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [getD_take_lt _ _ _ i.isLt]

/-- **The barycentric evaluation is the interpolant**: `(Σ_i w_i·bw_i)·sc = p_W(x)` in `K`, for `n` weights, `ω` of
order `n`, `x` canonical off `G_n`. -/
theorem toK_baryEval {n : ℕ} (hn : 0 < n) (hn64 : n < 2 ^ 64) (ωF : Fp) (hω : IsPrimitiveRoot ωF.toGF n) (x : Fp)
    (hx : x.Canon) (hxn : x.toGF ^ n ≠ 1) (w : List Fp2) (hw : w.length = n) :
    ((dotB w (baryW (powList ωF n) x)).mulBase (baryScale n x)).toK U
      = (mInterp (algebraMap GF K ωF.toGF) (vecK U n w)).eval (algebraMap GF K x.toGF) := by
  obtain ⟨hbl, hbi⟩ := baryW_spec ωF x hx hω hxn
  have hx' : (algebraMap GF K x.toGF) ^ n ≠ 1 := by rw [← map_pow]; exact algebraMap_ne_one hxn
  rw [bary_eval hn (hω.map_of_injective (algebraMap GF K).injective) _ _ hx', Fp2.toK_mulBase,
    toK_dotB U _ _ n hw hbl, toGF_baryScale n hn64]
  have hs : ∑ i : Fin n, (w.getD i Fp2.zero).toK U * algebraMap GF K ((baryW (powList ωF n) x).getD i Fp.zero).toGF
      = ∑ i : Fin n, vecK U n w i * ((algebraMap GF K ωF.toGF) ^ (i : ℕ)
          * (algebraMap GF K x.toGF - (algebraMap GF K ωF.toGF) ^ (i : ℕ))⁻¹) := by
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hbi i i.isLt, map_mul, map_inv₀, map_sub, map_pow]
    rfl
  rw [hs]
  simp only [map_mul, map_sub, map_pow, map_one, map_inv₀, map_natCast]
  ring

/-- **A Horner-free polynomial evaluation**: `Σ_i q_i·x^i = (Σ_i q_i X^i)(x)`. -/
theorem toK_dotB_pow (len : ℕ) (q : List Fp2) (hq : q.length = len) (x : Fp) :
    (dotB q (powList x len)).toK U = (coefPoly (vecK U len q)).eval (algebraMap GF K x.toGF) := by
  rw [toK_dotB U _ _ len hq (powList_length x len), eval_coefPoly]
  refine Finset.sum_congr rfl fun i _ => ?_
  rw [powList_getD x len i i.isLt, map_pow]
  rfl

theorem canon_mProdAcc {S : ℕ} {col : List Fp} (hc : ∀ x ∈ col, x.Canon) (wv : List Fp2) :
    (mProdAcc S col wv).Canon := by
  unfold mProdAcc
  suffices h : ∀ (l : List ℕ) (acc : Fp2), acc.Canon →
      (l.foldl (fun acc s => acc.add ((fp2Of col (2 * s) (2 * s + 1)).mul (wv.getD s Fp2.zero))) acc).Canon from
    h _ _ (canon_fp2Of hc _ _)
  intro l
  induction l with
  | nil => intro acc h; exact h
  | cons s l ih => intro acc _; exact ih _ (Fp2.canon_add _ _)

theorem canon_mProxAcc {S : ℕ} {col : List Fp} (hc : ∀ x ∈ col, x.Canon) (rs : List Fp2) :
    (mProxAcc S col rs).Canon := by
  unfold mProxAcc
  suffices h : ∀ (l : List (Fp2 × Fp)) (acc : Fp2), acc.Canon →
      (l.foldl (fun acc p => acc.add (p.1.mulBase p.2)) acc).Canon from h _ _ (canon_fp2Of hc _ _)
  intro l
  induction l with
  | nil => intro acc h; exact h
  | cons p l ih => intro acc _; exact ih _ (Fp2.canon_add _ _)

/-- **`M`'s column checks are the field equations of `MAccept`** at the column's point `η = 7·ω_4096^j`: the product
check `b(η) + Σ_s a_s(η)·p_{W_s}(η) = q'(η)` and the proximity check `u(η) + Σ_row r_row·row(η) = prox(η)`, with
`a_s = col[2s] + U·col[2s+1]` (and `b`, `u` likewise), `p_{W_s}` the interpolant of the combined weights on `G_512`,
`q'`, `prox` the polynomials of the sent coefficients; for canonical column entries and the wire lengths. -/
theorem mcol_iff_K (hU : U ^ 2 = algebraMap GF K 7) (ω512 ω4096 : Fp) (h512 : IsPrimitiveRoot ω512.toGF 512)
    (h4096 : IsPrimitiveRoot ω4096.toGF 4096) (S : ℕ) (ws : List (List Fp2)) (hws : ws.length = S)
    (hwl : ∀ w ∈ ws, w.length = mMsg) (q prox rs : List Fp2) (hq : q.length = 2 * mMsg) (hp : prox.length = 2 * mMsg)
    (hrs : rs.length = 2 * S + 2) (col : List Fp) (hc : ∀ x ∈ col, x.Canon) (hcl : col.length = 2 * S + 4) (j : ℕ) :
    let x := cosetPt ω4096 j
    let ω' := algebraMap GF K ω512.toGF
    let x' := algebraMap GF K x.toGF
    (mProdAcc S col (mEnc ω512 ws q prox x).1 = (mEnc ω512 ws q prox x).2.1
      ↔ (fp2Of col (2 * S) (2 * S + 1)).toK U
          + ∑ s : Fin S, (fp2Of col (2 * s) (2 * s + 1)).toK U * (mInterp ω' (vecK U mMsg (ws.getD s []))).eval x'
        = (coefPoly (vecK U (2 * mMsg) q)).eval x')
    ∧ (mProxAcc S col rs = (mEnc ω512 ws q prox x).2.2
      ↔ (fp2Of col (2 * S + 2) (2 * S + 3)).toK U
          + ∑ i : Fin (2 * S + 2), (rs.getD i Fp2.zero).toK U * algebraMap GF K (col.getD i Fp.zero).toGF
        = (coefPoly (vecK U (2 * mMsg) prox)).eval x') := by
  intro x ω' x'
  have hxc : x.Canon := Fp.mul_canon _ _
  have hxn : x.toGF ^ mMsg ≠ 1 := by
    show (cosetPt ω4096 j).toGF ^ 512 ≠ 1
    rw [cosetPt, Fp.toGF_mul, Fp.toGF_pow, seven_toGF]
    exact coset_pow_ne_one (show 512 ∣ 4096 by norm_num) (show 4096 = 2 ^ 12 by norm_num) (by norm_num) h4096 _
  have hwv : ∀ s : Fin S, (((mEnc ω512 ws q prox x).1).getD s Fp2.zero).toK U
      = (mInterp ω' (vecK U mMsg (ws.getD s []))).eval x' := by
    intro s
    have hs : (s : ℕ) < ws.length := by rw [hws]; exact s.isLt
    simp only [mEnc]
    rw [getD_map_lt' _ ws s hs []]
    exact toK_baryEval U (by norm_num [mMsg]) (by norm_num [mMsg]) ω512 h512 x hxc hxn _
      (hwl _ (mem_of_getD_lt ws s hs []))
  have key : ∀ (a b : Fp2), a.Canon → b.Canon → (a = b ↔ a.toK U = b.toK U) :=
    fun a b ha hb => ⟨fun h => by rw [h], Fp2.toK_injective U hU ha hb⟩
  constructor
  · rw [show (mEnc ω512 ws q prox x).2.1 = dotB q (powList x (2 * mMsg)) from rfl,
      key _ _ (canon_mProdAcc hc _) (canon_dotB _ _), toK_mProdAcc U hU S col hc, toK_dotB_pow U _ q hq x]
    simp only [hwv]
    exact Iff.rfl
  · rw [show (mEnc ω512 ws q prox x).2.2 = dotB prox (powList x (2 * mMsg)) from rfl,
      key _ _ (canon_mProxAcc hc _) (canon_dotB _ _), toK_mProxAcc U S col hc rs (2 * S + 2) hrs (by omega),
      toK_dotB_pow U _ prox hp x]

end K

/-! ## `combined_weights` in the field: `mW 1` and `mV 1` -/

section CombinedK

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)

instance : Inhabited MaskFunctional := ⟨⟨[], Fp2.zero⟩⟩

/-- A functional's weight on mask `s`, position `j`, read in `K`: the sum of its terms' weights on row `s`. -/
def fwt (f : MaskFunctional) (s j : ℕ) : K :=
  (f.terms.map (fun t => if t.1 = s then (t.2.getD j Fp2.zero).toK U else 0)).sum

theorem addPrefix_cons (th a x : Fp2) (r w : List Fp2) :
    addPrefix th (a :: r) (x :: w) = a.add (th.mul x) :: addPrefix th r w := rfl

theorem addPrefix_nil_right (th : Fp2) : ∀ r : List Fp2, addPrefix th r [] = r
  | [] => rfl
  | _ :: _ => rfl

include hU in
theorem addPrefix_spec (th : Fp2) : ∀ (r w : List Fp2), (∀ a ∈ r, a.Canon) →
    (addPrefix th r w).length = r.length ∧ (∀ a ∈ addPrefix th r w, a.Canon)
      ∧ ∀ j, j < r.length → ((addPrefix th r w).getD j Fp2.zero).toK U
          = (r.getD j Fp2.zero).toK U + th.toK U * (w.getD j Fp2.zero).toK U
  | [], w, _ => by
    cases w <;> exact ⟨rfl, fun a ha => absurd ha (List.not_mem_nil), fun j hj => absurd hj (Nat.not_lt_zero _)⟩
  | a :: r, [], hr => by
    rw [addPrefix_nil_right]
    refine ⟨rfl, hr, fun j _ => ?_⟩
    rw [List.getD_nil, Fp2.toK_zero, mul_zero, add_zero]
  | a :: r, x :: w, hr => by
    have ih := addPrefix_spec th r w (fun b hb => hr b (List.mem_cons_of_mem _ hb))
    rw [addPrefix_cons]
    refine ⟨by rw [List.length_cons, List.length_cons, ih.1], fun b hb => ?_, fun j hj => ?_⟩
    · rcases List.mem_cons.mp hb with rfl | hb
      · exact Fp2.canon_add _ _
      · exact ih.2.1 b hb
    · rcases j with _ | j
      · rw [List.getD_cons_zero, List.getD_cons_zero, List.getD_cons_zero,
          Fp2.toK_add U _ _ (hr a List.mem_cons_self) (Fp2.canon_mul _ _), Fp2.toK_mul U hU]
      · rw [List.getD_cons_succ, List.getD_cons_succ, List.getD_cons_succ]
        exact ih.2.2 j (by rw [List.length_cons] at hj; omega)

/-- The weights' shape: `S` rows of `m` canonical entries. -/
def WShape (S m : ℕ) (ws : List (List Fp2)) : Prop :=
  ws.length = S ∧ ∀ r ∈ ws, r.length = m ∧ ∀ a ∈ r, a.Canon

theorem getD_mem_of_shape {S m : ℕ} {ws : List (List Fp2)} (h : WShape S m ws) (s : ℕ) (hs : s < S) :
    ws.getD s [] ∈ ws := by
  rw [getD_eq_get _ _ _ (by rw [h.1]; exact hs)]
  exact List.getElem_mem _

theorem addRow_getD (th : Fp2) (w : List Fp2) : ∀ (ws : List (List Fp2)) (row s : ℕ),
    (addRow th w ws row).length = ws.length
      ∧ (addRow th w ws row).getD s [] = if s = row then addPrefix th (ws.getD s []) w else ws.getD s []
  | [], row, s => by
    refine ⟨rfl, ?_⟩
    split_ifs
    · cases w <;> rfl
    · rfl
  | r :: rs, 0, s => by
    refine ⟨rfl, ?_⟩
    rcases s with _ | s
    · simp only [addRow, List.getD_cons_zero, ↓reduceIte]
    · simp only [addRow, List.getD_cons_succ, Nat.add_one_ne_zero, ↓reduceIte]
  | r :: rs, row + 1, s => by
    have ih := addRow_getD th w rs row
    refine ⟨by simp only [addRow, List.length_cons, (ih 0).1], ?_⟩
    rcases s with _ | s
    · simp only [addRow, List.getD_cons_zero, Nat.zero_ne_add_one, ↓reduceIte]
    · simp only [addRow, List.getD_cons_succ, (ih s).2, Nat.add_right_cancel_iff]

include hU in
theorem addRow_shape (th : Fp2) (w : List Fp2) {S m : ℕ} {ws : List (List Fp2)} (h : WShape S m ws) (row : ℕ) :
    WShape S m (addRow th w ws row) := by
  refine ⟨by rw [(addRow_getD th w ws row 0).1, h.1], fun r hr => ?_⟩
  obtain ⟨s, hs, rfl⟩ := List.getElem_of_mem hr
  have hs' : s < ws.length := by rw [(addRow_getD th w ws row 0).1] at hs; exact hs
  have hg := (addRow_getD th w ws row s).2
  rw [← getD_eq_get _ _ [] hs, hg]
  have hmem : ws.getD s [] ∈ ws := by rw [getD_eq_get _ _ _ hs']; exact List.getElem_mem _
  obtain ⟨hl, hc⟩ := h.2 _ hmem
  split_ifs
  · obtain ⟨h1, h2, -⟩ := addPrefix_spec U hU th _ w hc
    exact ⟨h1.trans hl, h2⟩
  · exact ⟨hl, hc⟩

include hU in
/-- **One functional's terms**, added with weight `th`: entry `(s, j)` gains `th·fwt f s j`. -/
theorem terms_fold_spec (th : Fp2) (f : MaskFunctional) {S m : ℕ} :
    ∀ (ts : List (ℕ × List Fp2)) (ws : List (List Fp2)), WShape S m ws →
      WShape S m (ts.foldl (fun ws t => addRow th t.2 ws t.1) ws)
        ∧ ∀ s j, s < S → j < m →
          (((ts.foldl (fun ws t => addRow th t.2 ws t.1) ws).getD s []).getD j Fp2.zero).toK U
            = ((ws.getD s []).getD j Fp2.zero).toK U
              + th.toK U * (ts.map (fun t => if t.1 = s then (t.2.getD j Fp2.zero).toK U else 0)).sum
  | [], ws, h => ⟨h, fun s j _ _ => by simp⟩
  | t :: ts, ws, h => by
    have h1 := addRow_shape U hU th t.2 h t.1
    have ih := terms_fold_spec th f ts _ h1
    refine ⟨ih.1, fun s j hs hj => ?_⟩
    rw [List.foldl_cons, ih.2 s j hs hj, (addRow_getD th t.2 ws t.1 s).2, List.map_cons, List.sum_cons]
    obtain ⟨hl, hc⟩ := h.2 _ (getD_mem_of_shape h s hs)
    by_cases hst : s = t.1
    · rw [if_pos hst, if_pos hst.symm, (addPrefix_spec U hU th _ t.2 hc).2.2 j (by rw [hl]; exact hj)]
      ring
    · rw [if_neg hst, if_neg (fun h' => hst h'.symm)]
      ring

include hU in
/-- **The fold of `combined_weights`**, from any state: the weight `th0·θ^i` on functional `i`. -/
theorem cw_fold_spec (θ : Fp2) {S m : ℕ} : ∀ (fs : List MaskFunctional) (ws0 : List (List Fp2)) (v0 th0 : Fp2),
    WShape S m ws0 → v0.Canon →
      let res := fs.foldl (cwStep θ) (ws0, v0, th0)
      WShape S m res.1 ∧ res.2.1.Canon
        ∧ res.2.2.toK U = th0.toK U * θ.toK U ^ fs.length
        ∧ res.2.1.toK U = v0.toK U + ∑ i ∈ Finset.range fs.length,
            th0.toK U * θ.toK U ^ i * (fs.getD i default).value.toK U
        ∧ ∀ s j, s < S → j < m → ((res.1.getD s []).getD j Fp2.zero).toK U
            = ((ws0.getD s []).getD j Fp2.zero).toK U
              + ∑ i ∈ Finset.range fs.length, th0.toK U * θ.toK U ^ i * fwt U (fs.getD i default) s j
  | [], ws0, v0, th0, h, hv => by
    simp only [List.foldl_nil, List.length_nil, pow_zero, mul_one, Finset.range_zero, Finset.sum_empty, add_zero]
    exact ⟨h, hv, trivial, trivial, fun _ _ _ _ => trivial⟩
  | f :: fs, ws0, v0, th0, h, hv => by
    have hstep := terms_fold_spec U hU th0 f f.terms ws0 h
    have ih := cw_fold_spec θ fs (f.terms.foldl (fun ws t => addRow th0 t.2 ws t.1) ws0)
      (v0.add (th0.mul f.value)) (th0.mul θ) hstep.1 (Fp2.canon_add _ _)
    simp only [List.foldl_cons, cwStep] at ih ⊢
    obtain ⟨i1, i2, i3, i4, i5⟩ := ih
    refine ⟨i1, i2, ?_, ?_, fun s j hs hj => ?_⟩
    · rw [i3, Fp2.toK_mul U hU, List.length_cons, pow_succ]
      ring
    · rw [i4, Fp2.toK_add U _ _ hv (Fp2.canon_mul _ _), Fp2.toK_mul U hU, Fp2.toK_mul U hU, List.length_cons,
        Finset.sum_range_succ']
      simp only [List.getD_cons_succ, List.getD_cons_zero, pow_zero, mul_one, pow_succ]
      have : ∀ i, th0.toK U * θ.toK U * θ.toK U ^ i * (fs.getD i default).value.toK U
          = th0.toK U * (θ.toK U ^ i * θ.toK U) * (fs.getD i default).value.toK U := fun i => by ring
      simp only [this]
      ring
    · rw [i5 s j hs hj, hstep.2 s j hs hj, Fp2.toK_mul U hU, List.length_cons, Finset.sum_range_succ']
      simp only [List.getD_cons_succ, List.getD_cons_zero, pow_zero, mul_one, pow_succ]
      have : ∀ i, th0.toK U * θ.toK U * θ.toK U ^ i * fwt U (fs.getD i default) s j
          = th0.toK U * (θ.toK U ^ i * θ.toK U) * fwt U (fs.getD i default) s j := fun i => by ring
      simp only [this, fwt]
      ring

theorem zeros_shape (S m : ℕ) : WShape S m (List.replicate S (List.replicate m Fp2.zero)) := by
  refine ⟨List.length_replicate, fun r hr => ?_⟩
  rw [List.eq_of_mem_replicate hr]
  exact ⟨List.length_replicate, fun a ha => by rw [List.eq_of_mem_replicate ha]; exact Fp2.canon_zero⟩

include hU in
/-- **`combined_weights` is `SoundMProduct.lean`'s `mW 1` and `mV 1`** (the powers from `θ^1`, D65(1)): for `s < S`,
`j < 512`, entry `(s, j)` of the combined weights is `Σ_i θ^(i+1)·wt_i(s, j)`, and the combined value is
`Σ_i θ^(i+1)·value_i`, read in `K`. -/
theorem toK_combinedWeights (S : ℕ) (fs : List MaskFunctional) (θ : Fp2) :
    (combinedWeights S fs θ).2.toK U
        = mV 1 (fun i : Fin fs.length => (fs.get i).value.toK U) (θ.toK U)
      ∧ ∀ s j (hs : s < S) (hj : j < mMsg),
        (((combinedWeights S fs θ).1.getD s []).getD j Fp2.zero).toK U
          = mW 1 (fun (i : Fin fs.length) (s' : Fin S) (j' : Fin mMsg) => fwt U (fs.get i) s' j') (θ.toK U)
              ⟨s, hs⟩ ⟨j, hj⟩ := by
  have h := cw_fold_spec U hU θ fs _ Fp2.zero θ (zeros_shape S mMsg) Fp2.canon_zero
  obtain ⟨-, -, -, h4, h5⟩ := h
  have hget : ∀ i : Fin fs.length, fs.getD i default = fs.get i := fun i => by
    rw [getD_eq_get _ _ _ i.isLt]
    rfl
  refine ⟨?_, fun s j hs hj => ?_⟩
  · show (fs.foldl (cwStep θ) (_, Fp2.zero, θ)).2.1.toK U = _
    rw [h4, Fp2.toK_zero, zero_add, Finset.sum_range (fun i => θ.toK U * θ.toK U ^ i * (fs.getD i default).value.toK U),
      mV]
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hget i, pow_add, pow_one]
    ring
  · show (((fs.foldl (cwStep θ) (_, Fp2.zero, θ)).1.getD s []).getD j Fp2.zero).toK U = _
    rw [h5 s j hs hj]
    have h1 : (List.replicate S (List.replicate mMsg Fp2.zero)).getD s [] = List.replicate mMsg Fp2.zero := by
      rw [getD_eq_get _ _ _ (by rw [List.length_replicate]; exact hs), List.getElem_replicate]
    have hz : ((List.replicate S (List.replicate mMsg Fp2.zero)).getD s []).getD j Fp2.zero = Fp2.zero := by
      rw [h1, getD_eq_get _ _ _ (by rw [List.length_replicate]; exact hj), List.getElem_replicate]
    rw [hz, Fp2.toK_zero, zero_add,
      Finset.sum_range (fun i => θ.toK U * θ.toK U ^ i * fwt U (fs.getD i default) s j), mW]
    refine Finset.sum_congr rfl fun i _ => ?_
    rw [hget i, pow_add, pow_one]
    ring

end CombinedK

/-- **`M`'s check at every W16R2 profile** (`M` keeps its encoder, rate and `Q` under W16R3 too: B1 changes only the
regular commitments): `maskVerify` with the code's roots of orders `512` and `4096`. Type: `(HIn → Dig) → MTag → Dig →
ℕ → List MaskFunctional → MaskOpening → Tr → Except MErr Tr` (hash, tag keys, `M`'s root, the mask count `S`, the
functionals, the opening, the transcript). -/
def w16r2MCheck (H : HIn → Dig) (tag : MTag) : Dig → ℕ → List MaskFunctional → MaskOpening → Tr → Except MErr Tr :=
  maskVerify H tag (rootFp 9) (rootFp 12)

theorem w16r2MCheck_ok_iff (H : HIn → Dig) (tag : MTag) (root : Dig) (S : ℕ) (fs : List MaskFunctional)
    (op : MaskOpening) (t t' : Tr) :
    w16r2MCheck H tag root S fs op t = .ok t' ↔ MaskOk H tag (rootFp 9) (rootFp 12) root S fs op t t' :=
  maskVerify_ok_iff H tag (rootFp 9) (rootFp 12) root S fs op t t'

end ZK60.Exec
