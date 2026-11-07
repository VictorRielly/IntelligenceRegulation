/-
D63 Lean lane L17 (2026-11-07): **L10's opening checks, `M` and `Binding` at R13's geometry.**

R13's regular commitments (`A`, `H`, the boundaries and both endpoints; shape.rs:698, `COL_CHECKS`) are encoded at code
rate `1/4`: `n = 2^14` message symbols, `Q = 256` opened columns AND pad symbols (`ZkOpts::standard`), `N = 2^16`
columns on the coset `7·G_{2^16}`, a Merkle tree of depth `16`. W16R2 (D59) is the same code at rate `1/2`, `Q = 280`,
`N = 2^15`. The row encoder (`encode_row_zk`: the interpolant on `G_n`, the pads on `X^n − 1`), the verifier
(`pcs::verify_zk_tagged`), the transcript operations and the refusals are the SAME code at every rate; L10's executable
verifier `pcsVerify` is generic in its parameters, its points and its column evaluator, so R13 is an instance:
* `r13Prm`, `r13OpenCheck`: `pcsVerify` at `⟨log_cols 14, rate 1/4, Q 256, q_pad 256⟩` with the coset `7·G_{2^16}`
  (`cosetPt (rootFp 16)`) and the barycentric evaluator of the interpolant rows (`colEncLag (rootFp 14) (2^14) 256`);
  `r13_colEnc_spec` (the evaluator IS the encoder at every coset point, from L10's `colEncLag_spec` at `N = 2^16`) and
  `r13OpenCheck_ok_iff` (it accepts EXACTLY when every check holds);
* `pcsFieldR13`, `pcsFieldR13_transcript`: L9's `BlockParams.pcsVerify` at R13, moving the transcript exactly as L9's
  `pcsTranscript` with `Q = 256`, `nn = 2^16`;
* `M` is NOT a regular commitment: its constants are `zk.rs`'s own (`MASK_LOG_MSG`, `MASK_Q = 256`, `MASK_LOG_DOM`,
  wire.rs:23-32), never a shape's. So L10's `maskField`, `maskVerify_ok_iff`, `mask_rbrWide_code`, `mask_eps_W16R2_le`
  (`M`'s three rounds under Fiat–Shamir at `≤ 2^-106`) and `maskSP_kind8B` hold at R13 as stated; `checkField` reads only
  the row width `2^14`, the same at R13. Nothing to re-prove; `r13Fields` lists the three fields.
* **the regular opening's soundness at R13** (`opening_sound_r13`): L3's unique-decoding lemma (`opening_sound_rs_half`,
  BCIKS20 Thm 3.1 / 4.1, which holds at ANY rate) at `N = 2^16`, `K' = n + Q = 16,640`, `e = ⌊(N − K')/2⌋ = 24,448`: a
  far matrix or a false claim passes one opening with probability at most `N/|F| + ((N − e − 1)/N)^Q
  ≤ 2^-111 + 2^-172`. The code prices R13's opening by D15's `δ/3` count (`column_regime` = `GeneralCode`:
  `((2N + K')/(3N))^256 ≈ 2^-105.61`, shape.rs:353-364); the PROVED figure is about 64 bits smaller in the column term
  (finding L17-4). Both are below the target.
* `Binding` at R13 (`r13PlaneCommit`, `r13TokenCommit`, `binding_planes_target_r13`, `binding_classifier_target_r13`):
  L10's `PlaneCommit` with R13's code (`n = 2^14`, `Q = 256`, `N = 2^16`, the coset `7·G_{2^16}`, depth 16): `Binding M P
  εsTarget` for every `q`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.ExecOpeningBlock

set_option autoImplicit false

namespace ZK60.Exec

open Polynomial Finset
open ZK60.Sound Prob Code
open ZK60.Circuit (gP GF)
open scoped ENNReal

namespace R13

/-! ## The R13 regular opening, executable -/

/-- **R13's regular-opening parameters** (`log_cols 14`, rate `1/4`, `Q = q_pad = 256`; the endpoints' are the same:
`endpoint_inv_rate` follows the core rate, shape.rs:699). -/
def r13Prm : PcsPrm := ⟨14, 4, 256, 256⟩

theorem r13Prm_nn : r13Prm.nn = 2 ^ 16 := by norm_num [PcsPrm.nn, r13Prm]

/-- **R13's opening check** (`pcs::verify_zk_tagged` at R13): L10's executable verifier with the interpolant row form
evaluated at the coset `7·G_{2^16}`. -/
def r13OpenCheck (H : HIn → Dig) (tag : MTag) : Dig → ℕ → ℕ → List ZClaim → OpeningZk → Tr → Except PcsErr Tr :=
  pcsVerify H tag r13Prm (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256)

section Spec

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **R13's column evaluator meets the specification** at the coset points `η_j = 7·ω_{2^16}^j`, with the code's
roots (L10's `colEncLag_spec` at `n = 2^14 ∣ N = 2^16`). -/
theorem r13_colEnc_spec :
    ColEncSpec U (lagForm (by norm_num) ((rootFp_isPrimitiveRoot (k := 14) (by norm_num)).map_of_injective
        (algebraMap GF K).injective)) 256 (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256) :=
  colEncLag_spec U (by norm_num) (by norm_num) (show 2 ^ 14 ∣ 2 ^ 16 from pow_dvd_pow 2 (by norm_num)) rfl
    (by norm_num) _ _ (rootFp_isPrimitiveRoot (by norm_num)) (rootFp_isPrimitiveRoot (by norm_num))

end Spec

theorem r13_colEnc_length (x : Fp) (vs : List (List Fp2)) :
    (colEncLag (rootFp 14) (2 ^ 14) 256 x vs).length = vs.length := by
  simp [colEncLag]

/-- **R13's opening check accepts EXACTLY when every check holds** (`pcsVerify_ok_iff` at R13). -/
theorem r13OpenCheck_ok_iff (H : HIn → Dig) (tag : MTag) (root : Dig) (rows cmLogCols : ℕ) (claims : List ZClaim)
    (op : OpeningZk) (t t' : Tr) :
    r13OpenCheck H tag root rows cmLogCols claims op t = .ok t'
      ↔ PcsOk H tag r13Prm (cosetPt (rootFp 16)) (colEncLag (rootFp 14) (2 ^ 14) 256) root rows cmLogCols claims op
          t t' :=
  pcsVerify_ok_iff H tag r13Prm _ _ r13_colEnc_length root rows cmLogCols claims op t t'

/-! ## L9's `BlockParams` fields at R13 -/

section Fields

variable (tag : MTag)

/-- **`BlockParams.pcsVerify` at R13** (`rowsOf` the commitment's rows): the twin of L10's `pcsField`. -/
def pcsFieldR13 (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (cm : Block.Cm) (root : Dig) (cl : List Block.ZClaim)
    (o : Block.OpeningZk) (t : Tr) : Except String Tr :=
  mapErr (pcsErrMsg o (groupZclaims (cl.map toZClaim) (rowsOf cm) 14).length (Nat.log2 r13Prm.nn))
    (r13OpenCheck H tag root (rowsOf cm) 14 (cl.map toZClaim) (toOZ o) t)

/-- **R13's three fields** (`M`'s and `check_opening`'s are L10's, unchanged: `M` reads no shape field, `check_opening`
only the row width `2^14`). -/
def r13Fields (S : ℕ) (rowsOf : Block.Cm → ℕ) (geomOf : Block.Cm → OpenGeom) :
    ((HIn → Dig) → Dig → List Block.MaskFunctional → Block.MaskOpening → Tr → Except String Tr)
      × ((HIn → Dig) → Block.Cm → List Block.ZClaim → Tr → Except String Unit)
      × ((HIn → Dig) → Block.Cm → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) :=
  (maskField tag S, checkField geomOf, pcsFieldR13 tag rowsOf)

/-- **`pcsFieldR13` moves the transcript exactly as L9's `pcsTranscript`** with the member counts of the claims'
groups, `Q = 256` and `nn = 2^16`. -/
theorem pcsFieldR13_transcript (rowsOf : Block.Cm → ℕ) (H : HIn → Dig) (cm : Block.Cm) (root : Dig)
    (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr) (h : pcsFieldR13 tag rowsOf H cm root cl o t = .ok t') :
    ∃ lams rho idx, Block.pcsTranscript H
        ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) r13Prm.nQ r13Prm.nn o t
      = .ok (lams, rho, idx, t') := by
  rw [pcsFieldR13, mapErr_ok, r13OpenCheck_ok_iff] at h
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
      H Block.labPcsProx o.proxVec).challengeIndices H r13Prm.nQ r13Prm.nn = some (idx, t') := by
    rw [e1]
    exact hidx
  refine ⟨(Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).1,
    (Block.zkRhos H ((groupZclaims (cl.map toZClaim) (rowsOf cm) 14).map (·.2.length)) (rowsOf cm) t).2.1, idx, ?_⟩
  unfold Block.pcsTranscript
  simp only [e2, hcol]

end Fields

/-! ## The regular opening's soundness at R13's parameters -/

section Sound

/-- `(41087/65536)^256 ≤ 2^-172` (`(N − (e + 1))/N` at `N = 2^16`, `e = 24,448`, `Q = 256`: `2^-172.4`). -/
theorem r13_col_far_nat : (2 ^ 16 - (24448 + 1)) ^ 256 * 2 ^ 172 ≤ 1 * (2 ^ 16) ^ 256 := by
  rw [show (256 : ℕ) = 128 * 2 from rfl, pow_mul, pow_mul]
  norm_num

/-- `2^16/p² ≤ 2^-111` (the proximity test's field term `N/|F|` at `N = 2^16`, `|F| = p²`). -/
theorem r13_field_nat : 2 ^ 16 * 2 ^ 111 ≤ 1 * goldP ^ 2 := by norm_num [goldP]

/-- **One regular R13 opening is sound** (L3's `opening_sound_rs_half` at R13's code: `N = 2^16` points, degree
`< K' = 2^14 + 256`, `e = 24,448`, so `2e + K' ≤ N`; `Q = 256` columns with replacement; weights over `|F| = p²`): a
far matrix, or a false claim, passes with probability at most `2^-111 + 2^-172`. -/
theorem opening_sound_r13 {E κ : Type} [Field E] [Fintype E] [DecidableEq E] [Fintype κ] [DecidableEq κ]
    (hE : Fintype.card E = goldP ^ 2) (dom : Fin (2 ^ 16) ↪ E)
    (U : κ → Fin (2 ^ 16) → E) (a : κ → E) (ok : (Fin (2 ^ 16) → E) → Prop)
    (g w : (κ → E) → Fin (2 ^ 16) → E) (hg : ∀ ρ, g ρ ∈ rsCode dom (2 ^ 14 + 256 - 1))
    (hw : ∀ ρ, w ρ ∈ rsCode dom (2 ^ 14 + 256 - 1)) :
    (PMF.uniformOfFintype ((κ → E) × (Fin 256 → Fin (2 ^ 16)))).toOuterMeasure
        {ω | OpeningAccepts U a ok g w ω.1 ω.2 ∧ ¬ OpeningGood (rsCode dom (2 ^ 14 + 256 - 1)) 24448 U a ok}
      ≤ (2⁻¹ : ℝ≥0∞) ^ 111 + (2⁻¹ : ℝ≥0∞) ^ 172 := by
  refine le_trans (opening_sound_rs_half dom (e := 24448) (by rw [Fintype.card_fin]; norm_num) U a ok g w hg hw 256) ?_
  rw [Fintype.card_fin, hE]
  refine add_le_add ?_ ?_
  · rw [inv_two_pow_eq]
    exact natCast_div_le_div (by norm_num [goldP]) (by norm_num) r13_field_nat
  · rw [inv_two_pow_eq, natCast_div_pow]
    exact natCast_div_le_div (by positivity) (by norm_num) r13_col_far_nat

end Sound

/-! ## `Binding` at R13 -/

section Bind

/-- R13's row form: the interpolant on `G_{2^14}` (the same encoder as W16R2's). -/
noncomputable def r13Form : RowForm GF (2 ^ 14) :=
  lagForm (by norm_num) (rootGF_isPrimitiveRoot (k := 14) (by norm_num))

/-- R13's evaluation points: the coset `7·G_{2^16}`. -/
noncomputable def r13Pts : Fin (2 ^ 16) → GF := cosetPts 7 (rootGF 16)

theorem r13_pts_injective : Function.Injective r13Pts :=
  cosetPts_injective seven_ne_zero_GF (rootGF_isPrimitiveRoot (k := 16) (by norm_num))

theorem r13_hNQ : 2 ^ 14 + 256 ≤ 2 ^ 16 := by norm_num

/-- **An R13 plane commitment** (an endpoint, or any regular commitment of an R13 profile): the code fixed at R13's
(`n = 2^14`, `Q = 256`, `N = 2^16`, the interpolant rows, the coset `7·G_{2^16}`, the tree depth `16`); the geometry,
the admissible values, the plane map and the opening data are the caller's. -/
noncomputable def r13PlaneCommit {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit V St Salt where
  n := 2 ^ 14
  Q := 256
  N := 2 ^ 16
  R := R
  dR := dR
  hn := by norm_num
  hNQ := r13_hNQ
  form := r13Form
  pts := r13Pts
  hpts := r13_pts_injective
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
  depth := 16

/-- **The token-words endpoint at R13** (the classifier's input endpoint): the canonical words at the layout's
injective positions. -/
noncomputable def r13TokenCommit {T St Salt : Type} (R dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 14)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (T → ℕ) → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (root : St → Dig) (tag : MTag) :
    PlaneCommit (T → ℕ) St Salt :=
  r13PlaneCommit R dR (fun x => ∀ t, x t < gP) (posPlane pos) (fun x x' hx hx' h => posPlane_inj hpos x x' hx hx' h)
    place msg msg_place pad salt path root tag

variable {M : IntModel} {Coins : Type} {L : ℕ}

/-- **`Binding` at the proposed target for an R13 protocol** whose `opensIn` / `opensOut` are R13 plane openings
(L10's `binding_planes_target` at depth 16). -/
theorem binding_planes_target_r13 (P : Protocol (QB L) Dig Coins M)
    (Cin : PlaneCommit M.Input P.Stmt P.Salt) (Cout : PlaneCommit M.HidOut P.Stmt P.Salt) (h64 : 64 ≤ L)
    (hri : 8 * Cin.R ≤ L) (hro : 8 * Cout.R ≤ L)
    (hin : ∀ G s x r, P.opensIn G s x r ↔ opensIn Cin h64 hri G s x r)
    (hout : ∀ G s y r, P.opensOut G s y r ↔ opensOut Cout h64 hro G s y r)
    (hdi : Cin.depth = 16) (hdo : Cout.depth = 16) : Binding M P εsTarget :=
  binding_planes_target P Cin Cout h64 hri hro hin hout (by rw [hdi]; norm_num) (by rw [hdo]; norm_num)

/-- **`Binding` at the target for the R13 CLASSIFIER** (hidden output `Unit`, finding L12-5): the input endpoint an
R13 token-words commitment (depth 16), the output half vacuous. -/
theorem binding_classifier_target_r13 (P : Protocol (QB L) Dig Coins M) [Subsingleton M.HidOut]
    (Cin : PlaneCommit M.Input P.Stmt P.Salt) (h64 : 64 ≤ L) (hri : 8 * Cin.R ≤ L)
    (hin : ∀ G s x r, P.opensIn G s x r ↔ opensIn Cin h64 hri G s x r) (hdi : Cin.depth = 16) :
    Binding M P εsTarget :=
  binding_classifier_target P Cin h64 hri hin (by rw [hdi]; norm_num)

theorem r13PlaneCommit_depth {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (root : St → Dig) (tag : MTag) :
    (r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).depth = 16 := rfl

end Bind

end R13

end ZK60.Exec
