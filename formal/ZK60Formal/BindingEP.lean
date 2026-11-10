/-
D63 lane L48 (2026-11-10), part 3: **the classifier's input commitment at its REAL geometry** (finding L45-2, decision
D77a), and lane L26's binding at the unique-decoding radius there.

Lane L26 built the input-commitment instance of Victor's ruling D77 (1) ("the input commitment opens at the
unique-decoding radius at its largest value") on `r13TokenCommit`, the BLOCK geometry: `2^14` message columns, `2^16`
codeword symbols, radius `24,448`. The code commits the classifier's input with the token-I/O tier's ENDPOINT geometry
(`classify.rs:869`, `input_endpoint_spec`: `EndpointSpecG::new_with_tag(context, 1, in_ep_words, 0, …, t.ep_log_n,
t.ep_inv_rate, t.opened_cols, …)` at `R1_MVP`: `2^8` columns, rate `1/8`, `256` columns checked, `256` pads by
`ZkOpts::standard`; the data rows, then `MASK_ROWS = 5` random rows; interpolation on `G_{2^8}` and evaluation on the
coset `7·G_{2^11}`, as every commitment of the hiding PCS). Here:

* `epForm` (the interpolant on `G_{2^8}`), `epPts` (the coset `7·G_{2^11}`), `ep_pts_injective`, `ep_hNQ`;
* **`epPlaneCommit`**, **`epTokenCommit`**: the plane commitment and the token-words commitment at the endpoint
  geometry (`n = 2^8`, `Q = 256`, `N = 2^11 = 2,048`, tree depth `11`); `epTokenCommit_plane`;
* the radius at its largest value: **`ep_radiusU`** (`2·768 + 2^8 + 256 = 2,048` exactly), **`ep_radiusU_max`**
  (`769` breaks it), `epPlaneCommit_radiusU` (`N ≤ 2^20`, depth `≤ 64`), `epPlaneCommit_largest`;
* the code facts of the column test at the radius: **`ep_open_code_factsU`** (minimum distance `1,537`,
  `2·768 < 1,537`, correlated agreement with `A = N`, BCIKS20 at the δ/2 radius, tight);
* the column test's numbers: **`xA_eps_ep`** (`≤ 2^-115`), **`xB_eps_ep`** (`≤ 2^-173`);
* the extension field: `rowFormK8`, `rowFormK8_ext_ep`, **`closeIn_ep_iff`** (L30's code fact `closeIn_enc_iff` at
  the endpoint's code: the embedded matrix is close inside a column set over `K` iff the base matrix is);
  `rowFormK8_eq_RWL` (it is L48's run-model row form `RWL 8`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BindingU
import ZK60Formal.BindingUCode
import ZK60Formal.BindingUTest
import ZK60Formal.RunOpenGeoTier

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound ZK60.Assembly Code
open ZK60.Circuit (gP GF)
open scoped ENNReal

/-! ## The endpoint code -/

section EPCode

/-- **The input endpoint's row form**: the interpolant on `G_{2^8}` (the code's inverse NTT on a `2^8`-wide row). -/
noncomputable def epForm : RowForm GF (2 ^ 8) :=
  lagForm (by norm_num) (rootGF_isPrimitiveRoot (k := 8) (by norm_num))

/-- **The input endpoint's evaluation points**: the coset `7·G_{2^11}`, `η_j = 7·ω_{2^11}^j` (`ZkOpts::standard`'s coset
`7`, the forward NTT's natural order). -/
noncomputable def epPts : Fin (2 ^ 11) → GF := cosetPts 7 (rootGF 11)

theorem ep_pts_injective : Function.Injective epPts :=
  cosetPts_injective seven_ne_zero_GF (rootGF_isPrimitiveRoot (k := 11) (by norm_num))

theorem ep_hNQ : 2 ^ 8 + 256 ≤ 2 ^ 11 := by norm_num

/-- **A plane commitment at the token-I/O tier's endpoint geometry** (`R1_MVP`): `n = 2^8` message columns, `Q = 256`
pads, `N = 2^11` columns (the coset `7·G_{2^11}`), the interpolant rows, tree depth `11`; the geometry (rows, data
rows, their placement), the admissible values, the plane map and the opening data are the caller's. -/
noncomputable def epPlaneCommit {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 8) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit V St Salt where
  n := 2 ^ 8
  Q := 256
  N := 2 ^ 11
  R := R
  dR := dR
  hn := by norm_num
  hNQ := ep_hNQ
  form := epForm
  pts := epPts
  hpts := ep_pts_injective
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
  depth := 11

/-- **THE CLASSIFIER'S INPUT TOKEN COMMITMENT AT ITS REAL GEOMETRY**: the canonical token words (`x t < p`) at the
layout's injective positions `pos` of a `2^8`-wide plane (`input_plane`: the `T` ids, zero pad words), committed at
the endpoint geometry. -/
noncomputable def epTokenCommit {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit (T → ℕ) St Salt :=
  epPlaneCommit R dR (fun x => ∀ t, x t < gP) (posPlane pos) (fun x x' hx hx' h => posPlane_inj hpos x x' hx hx' h)
    place msg msg_place pad salt path root tag

/-- **The endpoint token commitment has the token-words plane** (the premise `hplane` of L26's `classifyU_O11d`), by
definition. -/
theorem epTokenCommit_plane {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag)
    (x : T → ℕ) :
    (epTokenCommit R dR hpos place msg msg_place pad salt path root tag).plane x = posPlane pos x :=
  rfl

/-- **Its admissible values are the canonical token words** (the premise `hokC` of `classifyU_O11d`), by definition. -/
theorem epTokenCommit_ok {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 8)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag)
    (x : T → ℕ) (hx : ∀ t, x t < gP) :
    (epTokenCommit R dR hpos place msg msg_place pad salt path root tag).ok x :=
  hx

end EPCode

/-! ## The radius at its largest value -/

section EPRadius

/-- **The input commitment's unique-decoding radius** (`N = 2^11`, `n = 2^8`, `Q = 256`): `e = 768`,
`2e + n + Q = 2^11` exactly. -/
theorem ep_radiusU : 2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11 := by norm_num

/-- **`768` is the largest radius** at the input commitment (`769` breaks the unique-decoding bound). -/
theorem ep_radiusU_max : 2 ^ 11 < 2 * 769 + (2 ^ 8 + 256) := by norm_num

/-- **Any endpoint plane commitment** (`epTokenCommit` included) has the radius `768`, at most `2^20` columns, depth
`11 ≤ 64`. -/
theorem epPlaneCommit_radiusU {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 8) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag) :
    2 * 768 + ((epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).n
        + (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).Q)
        ≤ (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N
      ∧ (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N ≤ 2 ^ 20
      ∧ (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).depth ≤ 64 := by
  refine ⟨?_, ?_, ?_⟩
  · show 2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11
    exact ep_radiusU
  · show 2 ^ 11 ≤ 2 ^ 20
    norm_num
  · show 11 ≤ 64
    norm_num

/-- **At an endpoint plane commitment the unique-decoding bound holds exactly up to `768`**: `2e + n + Q ≤ N` iff
`e ≤ 768`. -/
theorem epPlaneCommit_largest {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 8) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 8) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (root : St → Dig) (tag : MTag)
    (e : ℕ) :
    2 * e + ((epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).n
        + (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).Q)
        ≤ (epPlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N ↔ e ≤ 768 := by
  show 2 * e + (2 ^ 8 + 256) ≤ 2 ^ 11 ↔ e ≤ 768
  rw [show (2 : ℕ) ^ 8 + 256 = 512 by norm_num, show (2 : ℕ) ^ 11 = 2048 by norm_num]
  omega

end EPRadius

/-! ## The column test's code facts and numbers at the endpoint -/

section EPNumbers

/-- **The endpoint code's facts for the column test** (`N = 2^11`, `n = 2^8`, `Q = 256`, `e = 768`, `A = N`): minimum
distance `1,537`, `2·768 < 1,537`, correlated agreement with `A = N` (BCIKS20 at the δ/2 radius,
`2e + K + 1 = 2^11 + 1`: tight). -/
theorem ep_open_code_factsU {F : Type} [Field F] [Finite F] (pts : Fin (2 ^ 11) → F)
    (hpts : Function.Injective pts) (R : RowForm F (2 ^ 8)) :
    MinDist (LinearMap.range (encLin (Q := 256) pts R)) 1537 ∧ 2 * 768 < 1537 ∧ 768 + 1 ≤ 2 ^ 11
      ∧ (2 ^ 11 : ℕ) ≤ 2 ^ 11 ∧ CAOn Unit (LinearMap.range (encLin (Q := 256) pts R)) 768 (2 ^ 11) := by
  have hd := encLin_minDist (Q := 256) pts hpts R (by norm_num)
  have e1 : (2 : ℕ) ^ 11 - (2 ^ 8 + 256 - 1) = 1537 := by norm_num
  rw [e1] at hd
  exact ⟨hd, by norm_num, by norm_num, le_rfl, encLin_caOn pts hpts R (by norm_num) (by norm_num)⟩

/-- **The column test's round-0 error at the endpoint** (`N = 2^11`, `|F| = p²`, the `(λ, ρ)` bias over at most `2^61`
squeezes at most `2`): at most `2^-115`. Stated for a variable `p` (L7-4). -/
theorem xA_eps_ep {F : Type} [Fintype F] (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) {w0 : ℕ} (hw0 : w0 ≤ 2 ^ 61) :
    ((2 ^ 11 : ℕ) : ℝ≥0∞) / Fintype.card F * (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * w0)
      ≤ (2⁻¹ : ℝ≥0∞) ^ 115 :=
  Link.opA_eps_ep p hp1 hp2 hF hw0

/-- **The column test's column error at the endpoint** (`N = 2^11`, `e = 768`, `Q = 256`): at most `2^-173` (in fact
`2^-173.88`; D77a's estimate `2^-174` was the rounded figure). -/
theorem xB_eps_ep :
    (((Fintype.card (Fin (2 ^ 11)) - (768 + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ 11))) ^ 256 * 1
      ≤ (2⁻¹ : ℝ≥0∞) ^ 173 :=
  Link.opB_eps_ep

end EPNumbers

/-! ## The extension field: L30's code fact at the endpoint -/

section EPExt

variable (K : Type) [Field K] [Algebra GF K]

/-- **The endpoint's row form over an extension field**: the interpolant on the embedded `G_{2^8}`. -/
noncomputable def rowFormK8 : RowForm K (2 ^ 8) :=
  lagForm (by norm_num) ((rootGF_isPrimitiveRoot (k := 8) (by norm_num)).map_of_injective (algebraMap GF K).injective)

/-- It extends the endpoint's row form (L30's `lagForm_ext`). -/
theorem rowFormK8_ext_ep : RowFormExt epForm (rowFormK8 K) :=
  lagForm_ext (by norm_num) (rootGF_isPrimitiveRoot (k := 8) (by norm_num))

/-- **The endpoint's code** (`N = 2^11`, `Q = 256`): the embedded matrix is close inside `X` over `K` exactly when the
base-field matrix is close inside `X` (L30's `closeIn_enc_iff`, which holds for ANY column set). -/
theorem closeIn_ep_iff {κ' : Type} (e : ℕ) (X : Finset (Fin (2 ^ 11))) (U : κ' → Fin (2 ^ 11) → GF) :
    CloseIn (LinearMap.range (encLin (Q := 256) (fun j => algebraMap GF K (epPts j)) (rowFormK8 K))) e X
        (fun i j => algebraMap GF K (U i j))
      ↔ CloseIn (LinearMap.range (encLin (Q := 256) epPts epForm)) e X U :=
  closeIn_enc_iff epPts epForm (rowFormK8 K) (rowFormK8_ext_ep K) e X U

omit [Algebra GF K] in
/-- Two interpolant forms at equal roots are equal. -/
theorem og_lagForm_congr {n : ℕ} (hn : 0 < n) {ω ω' : K} (h : ω = ω') (hω : IsPrimitiveRoot ω n)
    (hω' : IsPrimitiveRoot ω' n) : lagForm hn hω = lagForm hn hω' := by
  subst h
  rfl

/-- **`rowFormK8` is the run model's row form at width `2^8`** (`RWL 8`, L48 part 1): the same interpolant, at
`rootFp 8 = rootGF 8`. -/
theorem rowFormK8_eq_RWL : rowFormK8 K = Link.RWL (K := K) 8 := by
  rw [Link.RWL_of_le 8 (by norm_num)]
  exact og_lagForm_congr K _ (congrArg (algebraMap GF K) (rootFp_toGF (by norm_num)).symm) _ _

end EPExt

end ZK60.Exec
