/-
D63 lane L10 (2026-11-07): **the adapter to L9's `BlockParams`** (`ExecBlockVerify.lean`) and to L12's hypothesis
shapes (`StageRunExtract.lean`).

L9's block verifier takes three of this lane's checks as fields:
* `maskVerify : (HIn → Dig) → Dig → List MaskFunctional → MaskOpening → Tr → Except String Tr`: here `maskField`, the
  executable `zk::mask_verify_tagged` (`ExecOpeningM.lean`) with the code's roots; it moves the transcript EXACTLY as
  L9's `maskTranscript` does (`maskField_transcript`);
* `checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit`: here `checkField`, the executable
  `protocol::check_opening` (the schedule audit `audit_claims` with `zpart_row_weight`'s base-field determinants, the
  first-occurrence grouping `opening_groups_at`, the group count, and L9's own `openingChallenges` on the transcript,
  which it returns nothing of: it cannot move the transcript);
* `pcsVerify : (HIn → Dig) → Cm → Dig → List ZClaim → OpeningZk → Tr → Except String Tr`: here `pcsField`, the
  executable `pcs::verify_zk_tagged` at W16R2 (`ExecOpening.lean`'s `w16r2OpenCheck`); it moves the transcript EXACTLY
  as L9's `pcsTranscript` does with the member counts of the claims' groups (`pcsField_transcript`).
L9's data types (`Block.ZClaim`, `Block.MaskFunctional`, `Block.OpeningZk` with its `Column`s, `Block.MaskOpening`)
are read into this lane's (`toZClaim`, `toMF`, `toOZ`, `toMO`): the same fields. The refusals are rendered as the
code's messages, character for character (`pcsErrMsg`, `mErrMsg`: the counts the code prints are read off the opening);
the agreement corpus compares them whole.

L12's shapes: `opensIn H s (fun t => canonWord (epW t)) r` and `opensOut H s (canonWord epO) r'` are `BindingW16.lean`'s
`opensIn` / `opensOut` of a `w16r2TokenCommit` (whose admissible values, the canonical words, the extracted words
always are: `token_ok_canon`), and the classifier's `opensOut H s () r'` is `opensUnit` (finding L12-5).
-/
import ZK60Formal.ExecOpeningFS
import ZK60Formal.BindingW16
import ZK60Formal.ExecBlockVerify
import ZK60Formal.StageInExtract

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Circuit (gP GF)

/-! ## L9's data in this lane's types -/

def toZPart (p : Block.ZPart) : ZPart := ⟨p.offset, p.logSize, p.coef, p.point⟩
def toZClaim (c : Block.ZClaim) : ZClaim := ⟨c.parts.map toZPart, c.value⟩
def toMF (f : Block.MaskFunctional) : MaskFunctional := ⟨f.terms, f.value⟩
def toOCol (c : Block.Column) : OCol := (c.j, c.col, c.salt, c.path)
def toOZ (o : Block.OpeningZk) : OpeningZk := ⟨o.groupVecs, o.proxVec, o.columns.map toOCol⟩
def toMO (o : Block.MaskOpening) : MaskOpening := ⟨o.q, o.prox, o.columns.map toOCol⟩

/-- **The code's messages** (`zkp-core/src/pcs.rs` `verify_zk_tagged`), with the counts it prints (read off the
opening, `nGroups` the claims' group count, the tree depth `log2 nn`). -/
def pcsErrMsg (o : Block.OpeningZk) (nGroups depth : ℕ) : PcsErr → String
  | .logCols => "pcs zk: log_cols mismatch"
  | .fewPads => "pcs zk: fewer pads than column checks"
  | .pathLen at_ => s!"pcs zk: opened column {at_} carries a Merkle path of {(o.columns.getD at_ ⟨0, [], zeroDig, []⟩).path.length} entries; this commitment's tree is {depth} deep"
  | .nGroups => s!"pcs zk: {o.groupVecs.length} group vectors for {nGroups} groups"
  | .vecLen g => s!"pcs zk: group vector {g} has length {(o.groupVecs.getD g []).length}"
  | .claim g => s!"pcs zk: group {g}: <v, c> != combined claim"
  | .proxLen => "pcs zk: prox vector length"
  | .indices => "panic: challenge_indices of a bound that is not a power of two"
  | .nCols => "pcs zk: wrong number of columns"
  | .colIndex j w => s!"pcs zk: column index {j} != sampled {w}"
  | .colLen => "pcs zk: column length"
  | .merkle j => s!"pcs zk: Merkle path for column {j} fails"
  | .colVec j g => s!"pcs zk: column {j} disagrees with clear vector {g}"

/-- **The code's messages** (`hashline/src/zk.rs` `mask_verify_tagged`); a path-length refusal prints the refused
column's path length (the first column with that index and a path of the wrong length: the columns are checked in
order, and an earlier column with that index passed this check). -/
def mErrMsg (mo : Block.MaskOpening) : MErr → String
  | .qLen => "mask: q length"
  | .sum => "mask: the product polynomial's sum != the combined functional"
  | .proxLen => "mask: prox length"
  | .indices => "panic: challenge_indices of a bound that is not a power of two"
  | .nCols => "mask: column count"
  | .colIndex _ => "mask: column index"
  | .colLen _ => "mask: column length"
  | .pathLen j => s!"mask: Merkle path for column {j} has {((mo.columns.find? (fun c => c.j == j && c.path.length != 12)).map (·.path.length)).getD 0} entries; the tree is 12 deep"
  | .merkle j => s!"mask: Merkle path for column {j} fails"
  | .product j => s!"mask: column {j} disagrees with the product polynomial"
  | .prox j => s!"mask: column {j} disagrees with the proximity vector"

def mapErr {ε ε' α : Type} (f : ε → ε') : Except ε α → Except ε' α
  | .ok a => .ok a
  | .error e => .error (f e)

theorem mapErr_ok {ε ε' α : Type} (f : ε → ε') (x : Except ε α) (a : α) : mapErr f x = .ok a ↔ x = .ok a := by
  cases x <;> simp [mapErr]

/-! ## `protocol::check_opening`, executable -/

section Check

/-- `pcs::zpart_row_weight`: the weight one claim part puts on row `r`. -/
def zpartRowWeight (p : Block.ZPart) (logCols r : ℕ) : Fp2 :=
  let n := 2 ^ logCols
  let r0 := p.offset / n
  if p.logSize < logCols then (if r = r0 then p.coef else Fp2.zero)
  else
    let lr := p.logSize - logCols
    if r < r0 ∨ r0 + 2 ^ lr ≤ r then Fp2.zero
    else if p.point.isEmpty then p.coef
    else p.coef.mul ((eqTableMsb (p.point.take lr)).getD (r - r0) Fp2.zero)

/-- `part_rows`: `[r0, r0 + ⌈2^ls / n⌉)`. -/
def partLo (p : Block.ZPart) (n : ℕ) : ℕ := p.offset / n
def partHi (p : Block.ZPart) (n : ℕ) : ℕ := p.offset / n + (2 ^ p.logSize + n - 1) / n

def auditFail (what : String) : Except String Unit := .error s!"private block: mask schedule audit: {what}"

/-- One claim's reserved rows, part by part (a part reaching the proximity pair, or a zero coefficient on a reserved
row, refuses). -/
def claimTouched (n prox : ℕ) (siteRows : List ℕ) (c : Block.ZClaim) : Except String (List ℕ) :=
  c.parts.foldlM (fun acc p => do
    if partHi p n > prox then
      throw "private block: mask schedule audit: a claim reaches the proximity pair or leaves the commitment"
    let rs := (List.range' (partLo p n) (partHi p n - partLo p n)).filter (fun r => decide (r ∈ siteRows))
    if !rs.isEmpty && p.coef.isZero then
      throw "private block: mask schedule audit: zero terminal mask coefficient; discard attempt"
    pure (acc ++ rs)) []

def claimWeight (logN : ℕ) (c : Block.ZClaim) (row : ℕ) : Fp2 :=
  c.parts.foldl (fun acc p => acc.add (zpartRowWeight p logN row)) Fp2.zero

def incAt : List ℕ → ℕ → List ℕ
  | [], _ => []
  | x :: l, 0 => (x + 1) :: l
  | x :: l, i + 1 => x :: incAt l i

/-- One claim's audit (`audit_claims`'s loop body); the uses updated. -/
def auditOne (n _rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ)) (nClaims : ℕ) (ci : ℕ)
    (c : Block.ZClaim) (uses : List ℕ) : Except String (List ℕ) := do
  let logN := Nat.log2 n
  let touched ← claimTouched n prox siteRows c
  let isSum := c.parts.all (fun p => p.point.isEmpty)
  let weight := claimWeight logN c
  match isSum, sumRows with
  | true, some (u0, u1) =>
    if ci + 1 = nClaims then
      let covered := fun row => c.parts.any (fun p => decide (partLo p n ≤ row ∧ row < partHi p n) && !p.coef.isZero)
      if !touched.isEmpty || !covered u0 || !covered u1 then
        auditFail "the sum claim is not masked by the zero-sum pair alone"
      if (Block.det (weight u0) (weight u1)).v = 0 then
        auditFail "the zero-sum pair's weights are dependent over the base field"
    else auditFail "unexpected sum claim"
  | false, _ =>
    let t0 := touched.getD 0 0
    let t1 := touched.getD 1 0
    if touched.length ≠ 2 ∨ t1 ≠ t0 + 1 ∨ (t0 - siteRows.getD 0 0) % 2 ≠ 0 then
      auditFail "a claim does not carry exactly its own reserved pair"
    if (Block.det (weight t0) (weight t1)).v = 0 then
      auditFail "a claim's reserved pair weights are dependent over the base field"
  | true, none => auditFail "unexpected sum claim"
  pure (touched.foldl incAt uses)

def auditLoop (n rows prox : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ)) (nClaims : ℕ) :
    ℕ → List Block.ZClaim → List ℕ → Except String (List ℕ)
  | _, [], uses => .ok uses
  | ci, c :: cs, uses => do
    let u ← auditOne n rows prox siteRows sumRows nClaims ci c uses
    auditLoop n rows prox siteRows sumRows nClaims (ci + 1) cs u

/-- **`audit_claims`** (`protocol.rs`), the schedule audit of one commitment's claims. -/
def auditClaims (claims : List Block.ZClaim) (n rows : ℕ) (siteRows : List ℕ) (sumRows : Option (ℕ × ℕ))
    (prox : ℕ) : Except String Unit := do
  if prox + 2 ≠ rows ∨ siteRows.length % 2 ≠ 0 then auditFail "proximity pair placement"
  if !isPow2 n then auditFail "the row width is not a power of two"
  let uses ← auditLoop n rows prox siteRows sumRows claims.length 0 claims (List.replicate rows 0)
  if siteRows.any (fun r => uses.getD r 0 ≠ 1) then auditFail "a reserved pair is unused or shared between claims"

/-- `part_key_at`: a part's column-weight key at a row width of `2^logN`. -/
def partKeyAt (p : Block.ZPart) (logN : ℕ) : List Fp2 × ℕ × ℕ :=
  let n := 2 ^ logN
  let cl : ℕ × ℕ := if logN ≤ p.logSize then (0, n) else (p.offset % n, 2 ^ p.logSize)
  ((if p.point.isEmpty then [] else p.point.drop (p.logSize - logN)), cl.1, cl.2)

def bumpKey (key : List Fp2 × ℕ × ℕ) : List ((List Fp2 × ℕ × ℕ) × ℕ) → List ((List Fp2 × ℕ × ℕ) × ℕ)
  | [] => [(key, 1)]
  | (k, c) :: rest => if k = key then (k, c + 1) :: rest else (k, c) :: bumpKey key rest

/-- **`opening_groups_at`**: the groups in first-occurrence order with their member counts. -/
def openingGroupsAt (claims : List Block.ZClaim) (logN : ℕ) : Except String (List ((List Fp2 × ℕ × ℕ) × ℕ)) :=
  claims.foldlM (fun gs c =>
    let key := partKeyAt (c.parts.headD ⟨0, 0, Fp2.zero, []⟩) logN
    if c.parts.any (fun p => partKeyAt p logN ≠ key) then
      throw "private block: claim parts with different column weights"
    else pure (bumpKey key gs)) []

/-- One commitment's geometry for `check_opening` (`lay.*_rows`, `*_site_rows()`, the zero-sum pair, `*_prox`,
`sh.*_groups()`). -/
structure OpenGeom where
  rows : ℕ
  siteRows : List ℕ
  sumRows : Option (ℕ × ℕ)
  prox : ℕ
  groups : ℕ

variable (H : HIn → Dig)

/-- **`protocol::check_opening`**: the audit, the exact group count, and the challenge refusals on a CLONE of the
transcript (L9's `openingChallenges`). Returns nothing: it cannot move the transcript. -/
def checkOpeningExec (g : OpenGeom) (logN : ℕ) (claims : List Block.ZClaim) (t : Tr) : Except String Unit := do
  auditClaims claims (2 ^ logN) g.rows g.siteRows g.sumRows g.prox
  let groups ← openingGroupsAt claims logN
  if groups.length ≠ g.groups then
    throw s!"private block: {groups.length} opening groups, the schedule declares {g.groups}"
  Block.openingChallenges H (groups.map (·.2)) g.rows g.prox t

end Check

/-! ## The three fields at W16R2, and their transcript contracts -/

section Fields

variable (tag : MTag)

/-- **`BlockParams.maskVerify` at W16R2** (`S` masks): `maskField tag S`. -/
def maskField (S : ℕ) (H : HIn → Dig) (root : Dig) (fs : List Block.MaskFunctional) (mo : Block.MaskOpening)
    (t : Tr) : Except String Tr :=
  mapErr (mErrMsg mo) (w16r2MCheck H tag root S (fs.map toMF) (toMO mo) t)

/-- **`BlockParams.pcsVerify` at W16R2** (`rowsOf` the commitment's rows: `lay.a_rows`, `lay.h_rows`):
`pcsField tag rowsOf`. -/
def pcsField (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim)
    (o : Block.OpeningZk) (t : Tr) : Except String Tr :=
  mapErr (pcsErrMsg o (groupZclaims (cl.map toZClaim) (rowsOf cm) 14).length (Nat.log2 w16r2Prm.nn))
    (w16r2OpenCheck H tag root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t)

/-- **`BlockParams.checkOpening` at W16R2** (`geomOf` each commitment's geometry; row width `2^14`):
`checkField geomOf`. -/
def checkField (geomOf : Block.Cm → OpenGeom) (H : HIn → Dig) (cm : Block.Cm) (cl : List Block.ZClaim) (t : Tr) :
    Except String Unit :=
  checkOpeningExec H (geomOf cm) 14 cl t

/-- The three fields have `BlockParams`' types. -/
example (S : ℕ) (rowsOf : Block.Cm → ℕ) (geomOf : Block.Cm → OpenGeom) :
    ((HIn → Dig) → Dig → List Block.MaskFunctional → Block.MaskOpening → Tr → Except String Tr)
      × ((HIn → Dig) → Block.Cm → List Block.ZClaim → Tr → Except String Unit)
      × ((HIn → Dig) → Block.Cm → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) :=
  (maskField tag S, checkField geomOf, pcsField tag rowsOf)

/-- Opened columns whose indices are the sampled ones (`f (cs.getD k d) = idx.getD k 0` at every position) pass the
code's "any index differs" test. -/
theorem zip_any_of_getD {α : Type} (f : α → ℕ) (d : α) : ∀ (cs : List α) (idx : List ℕ), cs.length = idx.length →
    (∀ k, k < cs.length → f (cs.getD k d) = idx.getD k 0) → (cs.zip idx).any (fun ci => decide (f ci.1 ≠ ci.2)) = false
  | [], [], _, _ => rfl
  | [], _ :: _, h, _ => absurd h (by simp)
  | _ :: _, [], h, _ => absurd h (by simp)
  | c :: cs, i :: is, h, hall => by
    have h0 : f c = i := by simpa using hall 0 (by simp)
    have ih := zip_any_of_getD f d cs is (by simpa using h) (fun k hk => by
      simpa using hall (k + 1) (by simp only [List.length_cons]; omega))
    rw [List.zip_cons_cons, List.any_cons, ih]
    simp [h0]

/-- **`maskField` moves the transcript exactly as L9's `maskTranscript`**: on acceptance, `maskTranscript` (`θ`, `q`'s
absorb, the `2S + 2` row coefficients, the proximity absorb, the indices, the column-index checks) accepts with the
same transcript. -/
theorem maskField_transcript (S : ℕ) (H : HIn → Dig) (root : Dig) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (t t' : Tr) (h : maskField tag S H root fs mo t = .ok t') :
    ∃ th rs idx, Block.maskTranscript H S mQ mDom mo t = .ok (th, rs, idx, t') := by
  rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h
  obtain ⟨_h1, _h2, _h3, idx, hidx, hlen, hcols⟩ := h
  have hl : mo.columns.length = idx.length := by simpa [toMO] using hlen
  have hany0 := zip_any_of_getD (fun c : OCol => c.1) (0, [], zeroDig, []) ((toMO mo).columns) idx hlen
    (fun k hk => (hcols k hk).1)
  have hany : (mo.columns.zip idx).any (fun ci => decide (ci.1.j ≠ ci.2)) = false := by
    have e : (toMO mo).columns = mo.columns.map toOCol := rfl
    rw [e, List.zip_map_left, List.any_map] at hany0
    exact hany0
  have e2 : ((((t.challengeFp2 H).2.absorbFp2 H Block.labMaskQ mo.q).challengeFp2Vec H (2 * S + 2)).2.absorbFp2 H
      Block.labMaskProx mo.prox).challengeIndices H mQ mDom = some (idx, t') := hidx
  refine ⟨(t.challengeFp2 H).1, (((t.challengeFp2 H).2.absorbFp2 H Block.labMaskQ mo.q).challengeFp2Vec H
    (2 * S + 2)).1, idx, ?_⟩
  have hc1 : ¬ (mo.columns.length ≠ idx.length) := fun h => h hl
  have hc2 : ¬ ((mo.columns.zip idx).any (fun ci => decide (ci.1.j ≠ ci.2)) = true) := by
    rw [hany]
    exact Bool.false_ne_true
  unfold Block.maskTranscript
  simp only [e2]
  rw [ite_eq_right hc1, ite_eq_right hc2]

/-- The transcript after a sequence of vector challenges. -/
def seqTr (H : HIn → Dig) (counts : List ℕ) (t : Tr) : Tr := counts.foldl (fun t c => (t.challengeFp2Vec H c).2) t

theorem foldl_vec_tr (H : HIn → Dig) : ∀ (counts : List ℕ) (acc : List Fp2 × Tr),
    (counts.foldl (fun (acc : List Fp2 × Tr) c => let v := acc.2.challengeFp2Vec H c; (acc.1 ++ v.1, v.2)) acc).2
      = seqTr H counts acc.2
  | [], _ => rfl
  | c :: cs, acc => by
    rw [List.foldl_cons, foldl_vec_tr H cs]
    rfl

/-- L9's `zkRhos` leaves the transcript where the group challenges and the row challenge leave it. -/
theorem zkRhos_tr (H : HIn → Dig) (counts : List ℕ) (rows : ℕ) (t : Tr) :
    (Block.zkRhos H counts rows t).2.2 = ((seqTr H counts t).challengeFp2Vec H rows).2 :=
  congrArg (fun t => (t.challengeFp2Vec H rows).2) (foldl_vec_tr H counts ([], t))

/-- This lane's `zkRhosAux` likewise (with the groups' member counts). -/
theorem zkRhosAux_tr (H : HIn → Dig) (rows : ℕ) : ∀ (gs : List (List Fp2 × List (List Fp2 × Fp2))) (t : Tr),
    (zkRhosAux H rows gs t).2.2 = ((seqTr H (gs.map (·.2.length)) t).challengeFp2Vec H rows).2
  | [], _ => rfl
  | g :: gs, t => zkRhosAux_tr H rows gs (t.challengeFp2Vec H g.2.length).2

/-- **`pcsField` moves the transcript exactly as L9's `pcsTranscript`** with the member counts of the claims' groups
(`group_zclaims`), `Q = 280` and `nn = 2^15`: on acceptance, `pcsTranscript` (`zk_rhos`, the absorbs, the indices, the
column-index checks) accepts with the same transcript. -/
theorem pcsField_transcript (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (cm : Block.Cm) (root : Dig)
    (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr) (h : pcsField tag rowsOf H cm root cl o t = .ok t') :
    ∃ lams rho idx, Block.pcsTranscript H
        ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) w16r2Prm.nQ w16r2Prm.nn o t
      = .ok (lams, rho, idx, t') := by
  rw [pcsField, mapErr_ok, w16r2OpenCheck_ok_iff] at h
  obtain ⟨_h1, _h2, _h3, _h4, _h5, _h6, idx, hidx, hlen, hcols⟩ := h
  have hl : o.columns.length = idx.length := by simpa [toOZ] using hlen
  have hany0 := zip_any_of_getD (fun c : OCol => c.1) (0, [], zeroDig, []) ((toOZ o).columns) idx hlen
    (fun k hk => (hcols k hk).1)
  have hfind : (o.columns.zip idx).find? (fun ci => decide (ci.1.j ≠ ci.2)) = none := by
    rw [List.find?_eq_none]
    intro ci hci
    have e : (toOZ o).columns = o.columns.map toOCol := rfl
    rw [e, List.zip_map_left, List.any_map, List.any_eq_false] at hany0
    exact hany0 ci hci
  have hcol : Block.colIdxCheck "pcs zk: " o.columns idx = .ok () := by
    have hc1 : ¬ (o.columns.length ≠ idx.length) := fun h => h hl
    unfold Block.colIdxCheck
    rw [ite_eq_right hc1, hfind]
  have e1 : (Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).2.2
      = (zkRhosAux H (rowsOf cm) (groupZclaims (cl.map toZClaim) (rowsOf cm) 14) t).2.2 :=
    (zkRhos_tr H _ _ t).trans (zkRhosAux_tr H _ _ t).symm
  have e2 : ((o.groupVecs.foldl (fun t v => t.absorbFp2 H Block.labPcsVec v)
      (Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).2.2).absorbFp2
      H Block.labPcsProx o.proxVec).challengeIndices H w16r2Prm.nQ w16r2Prm.nn = some (idx, t') := by
    rw [e1]
    exact hidx
  refine ⟨(Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).1,
    (Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).2.1, idx, ?_⟩
  unfold Block.pcsTranscript
  simp only [e2, hcol]

end Fields

/-! ## L12's hypothesis shapes -/

section L12

/-- **The extracted input words are admissible**: L12's input `x t = canonWord (epW t)` is canonical, so a
`w16r2TokenCommit`'s `opensIn` asks only the columns of it. -/
theorem token_ok_canon {T : Type} (epW : T → GF) : ∀ t, (fun t => ZK60.StageX.canonWord (epW t)) t < gP :=
  fun _ => ZK60.StageX.canonWord_lt _

/-- **The canonical words of a plane's extracted values are the values** (`canonWord_cast`): the input plane
`posPlane pos (canonWord ∘ epW)` holds exactly the extracted words at the token positions. -/
theorem posPlane_canon {T : Type} {dR n : ℕ} {pos : T → Fin dR × Fin n} (hpos : Function.Injective pos)
    (epW : T → GF) (t : T) : posPlane pos (fun t => ZK60.StageX.canonWord (epW t)) (pos t).1 (pos t).2 = epW t := by
  classical
  have hex : ∃ t', pos t' = ((pos t).1, (pos t).2) := ⟨t, rfl⟩
  have hc : hex.choose = t := hpos hex.choose_spec
  simp only [posPlane, dite_eq_left hex, hc, ZK60.StageX.canonWord_cast]

end L12

end ZK60.Exec
