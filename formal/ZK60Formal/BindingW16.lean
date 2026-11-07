/-
D63 lane L10 (2026-11-07): **`Binding` (§4.4 of `ZK60_LEAN_ASSEMBLY_20261106.md`) for the W16R2 hiding commitments**,
with the definitions `opensIn` / `opensOut` that L12 (the token stages' endpoints) and the later `Protocol` instance use.

**The commitment** (`PlaneCommit`). A value `v` (an input `x`, or a hidden output part `hiddenPart y`) is laid out as
the DATA ROWS of a plane (`plane v`, the layout's encoding, injective on the admissible values `ok`: for token words
the canonical ones, `x t < p`); the opening data `r : Salt` supplies the other rows' messages (the mask rows: the
terminal pair, the proximity rows), every row's pad, every column's salt and Merkle path. Row `i`'s word is
`encWord pts form (msg v r i) (pad r i)` (`ExecOpeningCode.lean`: `rowPoly d + (X^n − 1)·g` at the coset points);
column `j` is the `R` row words at `j`, as the code's `Fp` words. The commitment OPENS to `v` with `r` when `v` is
admissible and every one of the `N` columns passes the executable column check of `ExecMerkle.lean` against the
statement's root (`verifyColumn`: the depth, the length, the salted leaf, the climb): `PlaneCommit.Opens`,
`opens_iff_exec`.

**`col_inj`** (`column_inj`). The `N` columns give every row's whole word; at `N ≥ n + Q` distinct points the word
gives the row's message and pad (`encWord_inj`: the code is injective on messages, with `N` above the degree); the
data rows' messages are the plane; the plane gives an admissible `v`. Parametrized over the row form (W16R2:
`lagForm`, W16R3: `coefForm`), the points and the geometry, so W16R3 is an instance swap.

**What is proved** (only `propext`, `Classical.choice`, `Quot.sound`):
* `PlaneCommit.column_inj`; `opens_iff_exec`: opening is the executable verifier on every column;
* **`PlaneCommit.binding`**: opening one statement's commitment to two different values costs a `q`-query adversary at
  most `collBound (q + 2(h + 2)) Dig` (`merkle_binding` at a differing column, as `Assembly.lean`'s `ColCommit.binding`,
  here with the injectivity on admissible values);
* **`binding_planes`**: if a `Protocol`'s `opensIn` / `opensOut` are these openings, `Binding M P` holds with
  `collBound (q + 2(h_in + 2)) + collBound (q + 2(h_out + 2))`;
* `collBound_le_target`, **`binding_planes_target`**: for tree depths `≤ 64` this is AT the proposed target:
  `Binding M P εsTarget` (`εb q = q·2^-100 + 2^-100`), for EVERY `q`; **`binding_classifier_target`**: the same for the
  classifier, whose hidden output is `Unit` (`opensUnit`, finding L12-5: the output half is vacuous);
* `posPlane`, `posPlane_inj`: token words placed at injective positions of a plane determine the words when they are
  canonical (L12's `x t = canonWord (epW t)`);
* the W16R2 instance: `w16r2Form` (the interpolant on `G_{2^14}`, `rootGF 14`), `w16r2Pts` (the coset `7·G_{2^15}`),
  `w16r2PlaneCommit` (the endpoint geometry's free parameters left to the caller), its proofs `w16r2_pts_injective`,
  `w16r2_hNQ`.

**What this does not do.** The plane map (which positions of the endpoint plane hold the token words, the hidden
output) is the layout's (L12 for the endpoints); it is a field here (`posPlane` builds it from a position map). The
`Protocol` instance itself does not exist yet.
-/
import ZK60Formal.ExecOpeningCode
import ZK60Formal.ExecMerkle
import ZK60Formal.ExecSumcheckFS
import ZK60Formal.Assembly
import ZK60Formal.FSComposeBlock

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound ZK60.Assembly
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## A plane committed in the hiding PCS -/

/-- **A plane committed in the hiding PCS, opened column by column.** `n` message symbols per row, `Q` pad symbols,
`N` columns (the points `pts`), `R` rows of which `dR` are the plane's data rows (at `place`); the row form `form`.
The value `v` gives the plane (`plane`, injective on the admissible values `ok`); the opening data `r` gives the other
rows' messages (`msg` agrees with `plane` on the data rows), the pads, the salts and the paths. `tag` and `depth` are
the Merkle tree's keys and depth; `root` reads the commitment's root off the statement. -/
structure PlaneCommit (V St Salt : Type) where
  n : ℕ
  Q : ℕ
  N : ℕ
  R : ℕ
  dR : ℕ
  hn : 0 < n
  hNQ : n + Q ≤ N
  form : RowForm GF n
  pts : Fin N → GF
  hpts : Function.Injective pts
  ok : V → Prop
  plane : V → Fin dR → Fin n → GF
  plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v'
  place : Fin dR → Fin R
  msg : V → Salt → Fin R → Fin n → GF
  msg_place : ∀ v r k, msg v r (place k) = plane v k
  pad : Salt → Fin R → Fin Q → GF
  salt : Salt → Fin N → Dig
  path : Salt → Fin N → List Dig
  root : St → Dig
  tag : MTag
  depth : ℕ

namespace PlaneCommit

variable {V St Salt : Type} (C : PlaneCommit V St Salt)

/-- Row `i`'s word. -/
noncomputable def word (v : V) (r : Salt) (i : Fin C.R) : Fin C.N → GF :=
  encWord C.pts C.form (C.msg v r i) (C.pad r i)

/-- Column `j`: the `R` row words at `j`, as the code's canonical `Fp` words. -/
noncomputable def column (v : V) (r : Salt) (j : Fin C.N) : ColR C.R :=
  ⟨List.ofFn (fun i => Fp.ofGF (C.word v r i j)), List.length_ofFn⟩

/-- **`col_inj` for the plane commitment**: the columns determine an admissible value. -/
theorem column_inj {v v' : V} {r r' : Salt} (hv : C.ok v) (hv' : C.ok v')
    (h : ∀ j, C.column v r j = C.column v' r' j) : v = v' := by
  have hw : ∀ i, C.word v r i = C.word v' r' i := by
    intro i
    funext j
    have h1 := congrArg Subtype.val (h j)
    have h2 := congrFun (List.ofFn_injective h1) i
    have h3 := congrArg Fp.toGF h2
    simp only [Fp.toGF_ofGF] at h3
    exact h3
  apply C.plane_inj v v' hv hv'
  funext k
  have := (encWord_inj C.hpts C.form C.hn C.hNQ (hw (C.place k))).1
  rwa [C.msg_place, C.msg_place] at this

/-- **The statement's commitment opens to `v` with `r`**: `v` is admissible and every one of the `N` columns verifies
at its position against the statement's root (`MerkleEnc.Opens` of the code's encodings on `QB L`). This is the
definition `opensIn` (with `V = M.Input`) and `opensOut` (with `V = M.HidOut`) take. -/
def Opens (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (G : QB L → Dig) (s : St) (v : V) (r : Salt) : Prop :=
  C.ok v ∧ ∀ j : Fin C.N, (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root s) j.val
    ⟨C.column v r j, C.salt r j, C.path r j⟩

/-- **Opening is the executable verifier on every column** (`verifyColumn` of `ExecMerkle.lean`, under the verifier's
hash `liftH G`). -/
theorem opens_iff_exec (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (G : QB L → Dig) (s : St) (v : V) (r : Salt) :
    C.Opens L h64 hr G s v r
      ↔ C.ok v ∧ ∀ j : Fin C.N, verifyColumn (liftH G) C.tag C.depth C.R (C.root s) j (C.column v r j).1
          (C.salt r j) (C.path r j) = true :=
  and_congr Iff.rfl (forall_congr' fun j =>
    opensB_iff C.tag L C.R h64 hr G C.depth (C.root s) j ⟨C.column v r j, C.salt r j, C.path r j⟩)

/-- A column of zeros (the reduction's default). -/
def zeroCol : ColR C.R := ⟨List.replicate C.R Fp.zero, List.length_replicate⟩

open Classical in
/-- The reduction's choice: a position where the two values' columns differ, and the two openings there. -/
noncomputable def diffCol (v : V) (r : Salt) (v' : V) (r' : Salt) :
    ℕ × MerkleOpening Dig Dig (ColR C.R) × MerkleOpening Dig Dig (ColR C.R) :=
  if hj : ∃ j, C.column v r j ≠ C.column v' r' j then
    (hj.choose.val, ⟨C.column v r hj.choose, C.salt r hj.choose, C.path r hj.choose⟩,
      ⟨C.column v' r' hj.choose, C.salt r' hj.choose, C.path r' hj.choose⟩)
  else (0, ⟨C.zeroCol, zeroDig, []⟩, ⟨C.zeroCol, zeroDig, []⟩)

/-- **Binding of the plane commitment.** An adversary making at most `q` hash queries opens one statement's
commitment to two different values with probability at most `collBound (q + 2(h + 2)) Dig` (`merkle_binding` at a
position where the columns differ; one exists by `column_inj`; the reduction makes no further query). -/
theorem binding (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (q : ℕ) (A : OC (QB L) Dig (St × V × Salt × V × Salt))
    (hA : A.Bounded q) :
    prH (fun G => let o := A.run G
      o.2.1 ≠ o.2.2.2.1 ∧ C.Opens L h64 hr G o.1 o.2.1 o.2.2.1 ∧ C.Opens L h64 hr G o.1 o.2.2.2.1 o.2.2.2.2)
      ≤ collBound (q + 2 * (C.depth + 2)) Dig := by
  classical
  let B : OC (QB L) Dig (Dig × ℕ × MerkleOpening Dig Dig (ColR C.R) × MerkleOpening Dig Dig (ColR C.R)) :=
    A.bind (fun o => .ret (C.root o.1, C.diffCol o.2.1 o.2.2.1 o.2.2.2.1 o.2.2.2.2))
  have hB : B.Bounded q :=
    OC.Bounded.bind (q := 0) hA (fun o =>
      (trivial : (OC.ret (C.root o.1, C.diffCol o.2.1 o.2.2.1 o.2.2.2.1 o.2.2.2.2) : OC (QB L) Dig _).Bounded 0))
  refine le_trans (MeasureTheory.measure_mono ?_) ((merkleEncB C.tag L C.R h64 hr).merkle_binding C.depth q B hB)
  intro G hG
  obtain ⟨hne, ⟨hv1, h1⟩, ⟨hv2, h2⟩⟩ := hG
  have hj : ∃ j, C.column (A.run G).2.1 (A.run G).2.2.1 j ≠ C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 j := by
    by_contra hall
    exact hne (C.column_inj hv1 hv2 fun j => Classical.byContradiction fun h => hall ⟨j, h⟩)
  have hBrun : B.run G
      = (C.root (A.run G).1, C.diffCol (A.run G).2.1 (A.run G).2.2.1 (A.run G).2.2.2.1 (A.run G).2.2.2.2) := by
    simp only [B, OC.run_bind]
    rfl
  have hd : C.diffCol (A.run G).2.1 (A.run G).2.2.1 (A.run G).2.2.2.1 (A.run G).2.2.2.2
      = (hj.choose.val, ⟨C.column (A.run G).2.1 (A.run G).2.2.1 hj.choose, C.salt (A.run G).2.2.1 hj.choose,
          C.path (A.run G).2.2.1 hj.choose⟩,
        ⟨C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 hj.choose, C.salt (A.run G).2.2.2.2 hj.choose,
          C.path (A.run G).2.2.2.2 hj.choose⟩) := by
    unfold diffCol
    rw [dite_eq_left hj]
  show (B.run G).2.2.1.col ≠ (B.run G).2.2.2.col
    ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (B.run G).1 (B.run G).2.1 (B.run G).2.2.1
    ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (B.run G).1 (B.run G).2.1 (B.run G).2.2.2
  rw [hBrun, hd]
  exact ⟨hj.choose_spec, h1 hj.choose, h2 hj.choose⟩

end PlaneCommit

/-! ## Token words in a plane, and the classifier's `Unit` output -/

section Planes

open Classical in
/-- **Token words placed in a plane** at the positions `pos t` (the layout's), zero elsewhere. -/
noncomputable def posPlane {T : Type} {dR n : ℕ} (pos : T → Fin dR × Fin n) (x : T → ℕ) : Fin dR → Fin n → GF :=
  fun k i => if h : ∃ t, pos t = (k, i) then ((x h.choose : ℕ) : GF) else 0

/-- **The plane of canonical words determines the words** (`pos` injective; `x t < p`). -/
theorem posPlane_inj {T : Type} {dR n : ℕ} {pos : T → Fin dR × Fin n} (hpos : Function.Injective pos)
    (x x' : T → ℕ) (hx : ∀ t, x t < gP) (hx' : ∀ t, x' t < gP) (h : posPlane pos x = posPlane pos x') : x = x' := by
  classical
  funext t
  have h1 := congrFun (congrFun h (pos t).1) (pos t).2
  have hex : ∃ t', pos t' = ((pos t).1, (pos t).2) := ⟨t, rfl⟩
  have hc : hex.choose = t := hpos hex.choose_spec
  simp only [posPlane, dif_pos hex, hc] at h1
  have h2 := congrArg ZMod.val h1
  rwa [ZMod.val_natCast, ZMod.val_natCast, Nat.mod_eq_of_lt (hx t), Nat.mod_eq_of_lt (hx' t)] at h2

/-- **The classifier's hidden output is `Unit`** (finding L12-5): there is no output endpoint, and the opening is
trivially true. Binding's output half is then vacuous (`binding_classifier_target`). -/
def opensUnit {Q D St Salt : Type} (_G : Q → D) (_s : St) (_y : Unit) (_r : Salt) : Prop := True

end Planes

/-! ## `opensIn`, `opensOut` and `Binding` -/

section Bind

variable {M : IntModel} {Coins : Type} {L : ℕ}

/-- **`opensIn`**: the statement's input endpoint commitment opens to `x` with `r` (the input plane commitment). -/
def opensIn {St Salt : Type} (Cin : PlaneCommit M.Input St Salt) (h64 : 64 ≤ L) (hr : 8 * Cin.R ≤ L)
    (G : QB L → Dig) (s : St) (x : M.Input) (r : Salt) : Prop :=
  Cin.Opens L h64 hr G s x r

/-- **`opensOut`**: the statement's hidden-output endpoint commitment opens to `y` (the hidden output part) with `r`. -/
def opensOut {St Salt : Type} (Cout : PlaneCommit M.HidOut St Salt) (h64 : 64 ≤ L) (hr : 8 * Cout.R ≤ L)
    (G : QB L → Dig) (s : St) (y : M.HidOut) (r : Salt) : Prop :=
  Cout.Opens L h64 hr G s y r

/-- The approved target as one fraction: `q·2^-100 + 2^-100 = (q + 1)/2^100`. -/
theorem εsTarget_eq (q : ℕ) : εsTarget q = ((q + 1 : ℕ) : ℝ≥0∞) / ((2 ^ 100 : ℕ) : ℝ≥0∞) := by
  rw [εsTarget, inv_two_pow_eq, Nat.cast_one, ← mul_div_assoc, mul_one, ENNReal.div_add_div_same, Nat.cast_add,
    Nat.cast_one]

/-- **One commitment's collision bound is below the proposed target**: for a tree of depth `≤ 64` and `q ≤ 2^120`
queries, `collBound (q + 2(h + 2)) ≤ q·2^-100 + 2^-100` (over the `2^256` digests). -/
theorem collBound_le_target {q d : ℕ} (hq : q ≤ 2 ^ 120) (hd : d ≤ 64) :
    collBound (q + 2 * (d + 2)) Dig ≤ εsTarget q := by
  unfold collBound
  rw [εsTarget_eq, card_dig, Fintype.card_prod, Fintype.card_fin]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  have h120 : (2 : ℕ) ^ 120 = 1329227995784915872903807060280344576 := by norm_num
  have hT : q + 2 * (d + 2) ≤ 133 * (q + 1) := by omega
  have hT2 : q + 2 * (d + 2) ≤ 2 ^ 121 := by
    rw [show (2 : ℕ) ^ 121 = 2 * 2 ^ 120 by norm_num, h120]
    rw [h120] at hq
    omega
  calc (q + 2 * (d + 2)) * (q + 2 * (d + 2) - 1) / 2 * 2 ^ 100
      ≤ (q + 2 * (d + 2)) * (q + 2 * (d + 2)) * 2 ^ 100 :=
        Nat.mul_le_mul_right _ ((Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _)))
    _ ≤ (133 * (q + 1)) * 2 ^ 121 * 2 ^ 100 := Nat.mul_le_mul_right _ (Nat.mul_le_mul hT hT2)
    _ = (q + 1) * (133 * 2 ^ 221) := by ring
    _ ≤ (q + 1) * (2 ^ 128 * 2 ^ 128) := Nat.mul_le_mul_left _ (by norm_num)

/-- A probability is at most `1`. -/
theorem prH_le_one {Q D : Type} [Fintype Q] [DecidableEq Q] [Fintype D] [Nonempty D] (E : (Q → D) → Prop) :
    prH E ≤ 1 := by
  unfold prH
  exact le_trans (MeasureTheory.measure_mono (Set.subset_univ _))
    (le_of_eq ((PMF.toOuterMeasure_apply_eq_one_iff _ _).mpr (Set.subset_univ _)))

/-- The target exceeds `1` beyond `2^100` queries. -/
theorem one_le_εsTarget {q : ℕ} (hq : 2 ^ 100 ≤ q) : 1 ≤ εsTarget q := by
  rw [εsTarget_eq]
  rw [ENNReal.le_div_iff_mul_le (Or.inl (by positivity)) (Or.inl (ENNReal.natCast_ne_top _)), one_mul]
  exact_mod_cast (show 2 ^ 100 ≤ q + 1 by omega)

/-- **One commitment's half of `Binding` at the target**, for any `q` (depth `≤ 64`). -/
theorem plane_binding_target {V St Salt : Type} (C : PlaneCommit V St Salt) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L)
    (hd : C.depth ≤ 64) (q : ℕ) (A : OC (QB L) Dig (St × V × Salt × V × Salt)) (hA : A.Bounded q) :
    prH (fun G => let o := A.run G
      o.2.1 ≠ o.2.2.2.1 ∧ C.Opens L h64 hr G o.1 o.2.1 o.2.2.1 ∧ C.Opens L h64 hr G o.1 o.2.2.2.1 o.2.2.2.2)
      ≤ εsTarget q := by
  by_cases hq : q ≤ 2 ^ 120
  · exact le_trans (C.binding L h64 hr q A hA) (collBound_le_target hq hd)
  · exact le_trans (prH_le_one _) (one_le_εsTarget (by
      have : (2 : ℕ) ^ 100 ≤ 2 ^ 120 := Nat.pow_le_pow_right (by norm_num) (by norm_num)
      omega))

/-- **`Binding` for a protocol whose endpoints are plane commitments**, with `collBound (q + 2(h + 2))` per
commitment (`h` its tree depth). -/
theorem binding_planes (P : Protocol (QB L) Dig Coins M) (Cin : PlaneCommit M.Input P.Stmt P.Salt)
    (Cout : PlaneCommit M.HidOut P.Stmt P.Salt) (h64 : 64 ≤ L) (hri : 8 * Cin.R ≤ L) (hro : 8 * Cout.R ≤ L)
    (hin : ∀ G s x r, P.opensIn G s x r ↔ opensIn Cin h64 hri G s x r)
    (hout : ∀ G s y r, P.opensOut G s y r ↔ opensOut Cout h64 hro G s y r) :
    Binding M P (fun q => collBound (q + 2 * (Cin.depth + 2)) Dig + collBound (q + 2 * (Cout.depth + 2)) Dig) := by
  refine ⟨fun q A hA => ?_, fun q A hA => ?_⟩
  · refine le_trans (le_trans (MeasureTheory.measure_mono ?_) (Cin.binding L h64 hri q A hA)) le_self_add
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hin _ _ _ _).1 h1, (hin _ _ _ _).1 h2⟩
  · refine le_trans (le_trans (MeasureTheory.measure_mono ?_) (Cout.binding L h64 hro q A hA)) le_add_self
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hout _ _ _ _).1 h1, (hout _ _ _ _).1 h2⟩

/-- **`Binding` at the proposed target** (`εb q = q·2^-100 + 2^-100`, `Statements.lean`'s `ProductionReady`
comment), for EVERY `q`, when both trees have depth `≤ 64` (W16R2: depth 15). Each part is bounded by its own
commitment's collision term (below the target for `q ≤ 2^120`), and above `2^120` queries the target exceeds `1`. -/
theorem binding_planes_target (P : Protocol (QB L) Dig Coins M) (Cin : PlaneCommit M.Input P.Stmt P.Salt)
    (Cout : PlaneCommit M.HidOut P.Stmt P.Salt) (h64 : 64 ≤ L) (hri : 8 * Cin.R ≤ L) (hro : 8 * Cout.R ≤ L)
    (hin : ∀ G s x r, P.opensIn G s x r ↔ opensIn Cin h64 hri G s x r)
    (hout : ∀ G s y r, P.opensOut G s y r ↔ opensOut Cout h64 hro G s y r)
    (hdi : Cin.depth ≤ 64) (hdo : Cout.depth ≤ 64) : Binding M P εsTarget := by
  refine ⟨fun q A hA => ?_, fun q A hA => ?_⟩
  · refine le_trans (MeasureTheory.measure_mono ?_) (plane_binding_target Cin h64 hri hdi q A hA)
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hin _ _ _ _).1 h1, (hin _ _ _ _).1 h2⟩
  · refine le_trans (MeasureTheory.measure_mono ?_) (plane_binding_target Cout h64 hro hdo q A hA)
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hout _ _ _ _).1 h1, (hout _ _ _ _).1 h2⟩

/-- **`Binding` at the target for the CLASSIFIER** (hidden output `Unit`, finding L12-5): the input endpoint is a
plane commitment, the output opening anything (`opensUnit`); the output half is vacuous (two values of `Unit` are
equal). -/
theorem binding_classifier_target (P : Protocol (QB L) Dig Coins M) [Subsingleton M.HidOut]
    (Cin : PlaneCommit M.Input P.Stmt P.Salt) (h64 : 64 ≤ L) (hri : 8 * Cin.R ≤ L)
    (hin : ∀ G s x r, P.opensIn G s x r ↔ opensIn Cin h64 hri G s x r) (hdi : Cin.depth ≤ 64) :
    Binding M P εsTarget := by
  refine ⟨fun q A hA => ?_, fun q A hA => ?_⟩
  · refine le_trans (MeasureTheory.measure_mono ?_) (plane_binding_target Cin h64 hri hdi q A hA)
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hin _ _ _ _).1 h1, (hin _ _ _ _).1 h2⟩
  · refine le_trans (le_of_eq ?_) zero_le
    refine MeasureTheory.measure_mono_null (fun G hG => ?_) MeasureTheory.measure_empty
    exact hG.1 (Subsingleton.elim _ _)

end Bind

/-! ## The W16R2 instance -/

section W16R2

/-- W16R2's regular commitments (D59): `log_cols = 14` (`W16R2_LOG_COLS`), code rate `1/2` (`W16R2_INV_RATE`),
`Q = 280` opened columns and pad symbols (`W16R2_OPENED_COLS`; `ZkOpts::standard`). -/
def w16r2LogCols : ℕ := 14
def w16r2InvRate : ℕ := 2
def w16r2Q : ℕ := 280

/-- W16R2's row form: the interpolant on `G_{2^14}` (the code's inverse NTT on the row). -/
noncomputable def w16r2Form : RowForm GF (2 ^ 14) :=
  lagForm (by norm_num) (rootGF_isPrimitiveRoot (k := 14) (by norm_num))

/-- W16R2's evaluation points: the coset `7·G_{2^15}`, `η_j = 7·ω_{2^15}^j`. -/
noncomputable def w16r2Pts : Fin (2 ^ 15) → GF := cosetPts 7 (rootGF 15)

theorem w16r2_pts_injective : Function.Injective w16r2Pts :=
  cosetPts_injective seven_ne_zero_GF (rootGF_isPrimitiveRoot (k := 15) (by norm_num))

theorem w16r2_hNQ : 2 ^ 14 + 280 ≤ 2 ^ 15 := by norm_num

/-- **A W16R2 plane commitment** (an endpoint, or any regular commitment of a W16R2 profile): the code fixed at
W16R2's (`n = 2^14`, `Q = 280`, `N = 2^15`, the interpolant rows, the coset `7·G_{2^15}`, the tree depth `15`); the
geometry (rows, data rows, their placement), the admissible values, the plane map and the opening data are the
caller's. -/
noncomputable def w16r2PlaneCommit {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit V St Salt where
  n := 2 ^ 14
  Q := 280
  N := 2 ^ 15
  R := R
  dR := dR
  hn := by norm_num
  hNQ := w16r2_hNQ
  form := w16r2Form
  pts := w16r2Pts
  hpts := w16r2_pts_injective
  ok := ok
  plane := plane
  plane_inj := plane_inj
  place := place
  msg := msg
  msg_place := msg_place
  pad := pad
  salt := salt
  path := path
  root := root
  tag := tag
  depth := 15

theorem w16r2PlaneCommit_depth {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (root : St → Dig) (tag : MTag) :
    (w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).depth ≤ 64 := by
  show 15 ≤ 64
  norm_num

/-- **The token-words endpoint at W16R2** (for L12): the input endpoint's admissible values are the canonical token
words (`x t < p`: L12's `x t = canonWord (epW t)`), placed at the layout's injective positions `pos`. -/
noncomputable def w16r2TokenCommit {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 14)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit (T → ℕ) St Salt :=
  w16r2PlaneCommit R dR (fun x => ∀ t, x t < gP) (posPlane pos) (fun x x' hx hx' h => posPlane_inj hpos x x' hx hx' h)
    place msg msg_place pad salt path root tag

end W16R2

end ZK60.Exec
