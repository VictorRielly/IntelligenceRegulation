/-
D63, Lean lane L15 (2026-11-07): **stage OUT-C's verifier arithmetic, executable**, on the code's words (`Fp2`), line
for line as hashline's `stage_out_c.rs` writes it (`define`, :283-429) and `token_io.rs`'s slot runner reads it
(`run_stage_slot`'s verify arm, :1064-1090; `helper_sum`, :1230; `zeta_fold`, :1249): the eight slots' closures on the
terminal values `vals` (`ioPoly` … `zsPoly`), the slots' public tables as functions of the profile (`supp`, `liveTab`,
`gTab`, `wTab`, `tvTab`), the terminal values (`sel·eq(τ, ρ)`, `sel·mle(pub)(ρ)`, the masked terminals: `stageVals`),
the claimed sum with the hosted scalars (`claimedOf`) and the sumcheck's arithmetic on the recorded challenges
(`scArith`, L6's `interpolateEval` and `scFinalExec`).

`StageCheckOutC.lean` (not imported by the root: it defines `main`) runs them on a real classifier receipt's stage
OUT-C (`results/zk60_lean_l15_20261107/corpus.txt`) and compares every value with the Rust verifier's. The closures
are the executable counterparts of `StageOutCWhole.lean`'s model polynomials (`tzcCW`/`tzcCPz`/`tzcCHost`, `dzcW`/
`dzcPz`, `lzcW`/`lzcHost`, `tzcW`/`tzcPz`, `ioR`, `ssF`): the same tables in the same order with the same constants.
-/
import ZK60Formal.ExecSumcheck

namespace ZK60.Exec.StageCheck

open ZK60.Exec

/-! ## Words -/

/-- `k(v)` = `Fp2::from_i64(v)` (token_io.rs:931). -/
def kI (v : ℤ) : Fp2 := Fp2.fromBase (Fp.fromI64 v)

/-- `v[i]`. -/
def vg (v : List Fp2) (i : ℕ) : Fp2 := v.getD i Fp2.zero

/-- `a.mul_base(Fp::new(r))`. -/
def mb (a : Fp2) (r : ℕ) : Fp2 := a.mulBase (Fp.new (UInt64.ofNat r))

/-- `(1 − e)` products (`sel`, `cd`). -/
def oneMinusProd (es : List Fp2) : Fp2 := es.foldl (fun a e => a.mul (Fp2.one.sub e)) Fp2.one

/-! ## The slots' closures (stage_out_c.rs `define`) -/

/-- OUTC-00 IO-in: `eq·(x − B_out)`, tables `[eq τ, A X, In B_out]`. -/
def ioPoly (v : List Fp2) : Fp2 := (vg v 0).mul ((vg v 1).sub (vg v 2))

/-- OUTC-01 SS: `supp·x·x`, tables `[supp, A X]`. -/
def ssPoly (v : List Fp2) : Fp2 := ((vg v 0).mul (vg v 1)).mul (vg v 1)

/-- `l3(o) = v[o] + 256·v[o + 1] + 65536·v[o + 2]` (stage_out_c.rs:328). -/
def l3W (v : List Fp2) (o : ℕ) : Fp2 := ((vg v o).add (mb (vg v (o + 1)) 256)).add (mb (vg v (o + 2)) 65536)

/-- OUTC-02 TZC: tables `[eq τ, u0, D, Dsq, nine limb slices]` (stage_out_c.rs:312-335). -/
def tzcPoly (mu : List Fp2) (nu zeta kceps : Fp2) (v : List Fp2) : Fp2 :=
  let d := vg v 2
  let dsq := vg v 3
  let dl := l3W v 4
  let a1 := l3W v 7
  let a2 := l3W v 10
  let pad := (Fp2.one.sub (vg v 1)).mul (d.add (zeta.mul dsq))
  let zc := ((((vg mu 0).mul (dsq.sub (d.mul d))).add ((vg mu 1).mul (d.sub dl))).add
    ((vg mu 2).mul (((d.add d).sub a1).sub a2))).add ((vg mu 3).mul pad)
  ((vg v 0).mul zc).add ((nu.mul (vg v 1)).mul ((dsq.add a1).sub kceps))

/-- OUTC-03 PD: `y·w_Δ`, tables `[A Y, w]`. -/
def pdPoly (v : List Fp2) : Fp2 := (vg v 0).mul (vg v 1)

/-- A resolved lookup's denominator `α − ((cst + g) + Σ v[i]·c)` (`resolve`, `helper_sum`). -/
def denW (v : List Fp2) (alpha g : Fp2) (i : ℕ) (c cst : ℤ) : Fp2 :=
  alpha.sub (((kI cst).add g).add ((vg v i).mulBase (Fp.fromI64 c)))

/-- OUTC-04 LZC: tables `[eq τ, live, G, u0, A LIMB, H_LO]` (stage_out_c.rs:349-370); `helper_sum` with the one
single and `mu = [1]`. -/
def lzcPoly (mu : List Fp2) (nu alpha g kc : Fp2) (v : List Fp2) : Fp2 :=
  let helper := Fp2.zero.add (Fp2.one.mul (((vg v 5).mul (denW v alpha g 4 1 0)).sub Fp2.one))
  let pad := (Fp2.one.sub (vg v 1)).mul (vg v 4)
  let host := ((vg v 2).mul (vg v 4)).add ((vg v 3).mul kc)
  ((vg v 0).mul (((vg mu 0).mul helper).add ((vg mu 1).mul pad))).add (nu.mul host)

/-- DZC's twelve lookups `lookups_do` as `(plane, coef, cst)`, the plane counted from `C_X`. -/
def dzcLks : List (ℕ × ℤ × ℤ) :=
  [(1, 1, 0), (2, 1, 0), (3, 1, 127), (3, -1, 127), (4, 1, 0), (5, 1, 0), (6, 1, 0), (7, 1, 0), (8, 1, 0), (9, 1, 0),
    (10, 1, 0), (11, 1, 0)]

/-- `lb(p0)` over DZC's tables (the planes at `2 + p`). -/
def lbW (v : List Fp2) (p0 : ℕ) : Fp2 :=
  (List.range 4).foldl (fun a kk => a.add (mb (vg v (2 + (p0 + kk))) (2 ^ (8 * kk)))) Fp2.zero

/-- `zeta_fold` of DZC's twelve planes. -/
def zfoldW (v : List Fp2) (zeta : Fp2) : Fp2 :=
  ((List.range 12).foldl (fun (st : Fp2 × Fp2) j => (st.1.add (st.2.mul (vg v (2 + j))), st.2.mul zeta))
    (Fp2.zero, Fp2.one)).1

/-- OUTC-05 DZC: tables `[eq τ, supp, the twelve Do planes, D (fixed), H_D0 .. H_D5]` (stage_out_c.rs:371-405). -/
def dzcPoly (mu : List Fp2) (zeta alpha g kNum kDv kDen : Fp2) (v : List Fp2) : Fp2 :=
  let x := vg v 2
  let y := vg v 5
  let d := vg v 14
  let rh := lbW v 4
  let sg := lbW v 8
  let kd := d.mul kDen
  let c0 := (((x.mul kNum).add (d.mul kDv)).sub (kd.mul y)).sub rh
  let c1 := ((sg.add rh).add Fp2.one).sub kd
  let c2 := ((x.add (kI 32768)).sub (vg v 3)).sub (mb (vg v 4) 256)
  let gg := vg v 1
  let clauses := (((vg mu 0).mul c0).add ((vg mu 1).mul c1)).add ((vg mu 2).mul c2)
  let den := fun (l : ℕ × ℤ × ℤ) => denW v alpha g (2 + l.1) l.2.1 l.2.2
  let hs := (List.range 6).foldl (fun acc kk =>
    let d1 := den (dzcLks.getD (2 * kk) (0, 0, 0))
    let d2 := den (dzcLks.getD (2 * kk + 1) (0, 0, 0))
    acc.add ((vg mu (3 + kk)).mul ((((vg v (15 + kk)).mul d1).mul d2).sub (d1.add d2)))) Fp2.zero
  let pad := (Fp2.one.sub gg).mul (zfoldW v zeta)
  (vg v 0).mul (((gg.mul clauses).add hs).add ((vg mu 9).mul pad))

/-- OUTC-06 TAB: tables `[eq τ, supp, tv, A MULT, H_GU8]` (stage_out_c.rs:406-421). -/
def tabPoly (mu : List Fp2) (zeta alpha : Fp2) (v : List Fp2) : Fp2 :=
  let rel := ((vg v 4).mul (alpha.sub (vg v 2))).sub (vg v 3)
  let pad := (Fp2.one.sub (vg v 1)).mul ((vg v 3).add (zeta.mul (vg v 4)))
  (vg v 0).mul (((vg mu 0).mul rel).add ((vg mu 1).mul pad))

/-- OUTC-07 ZS: `1·u`, tables `[ones, H_U]`. -/
def zsPoly (v : List Fp2) : Fp2 := (vg v 0).mul (vg v 1)

/-! ## The public tables as functions of the profile -/

/-- `supp(len, size)` (stage_out_c.rs:269). -/
def supp (len size : ℕ) : List Fp2 := (List.range size).map (fun z => if z < len then Fp2.one else Fp2.zero)

/-- LZC's live selector `live_limb` (stage_out_c.rs:279): the nine isqrt sub-planes at `To`'s entry 0 and the margin
limbs. -/
def liveTab (size lam l : ℕ) : List Fp2 :=
  (List.range size).map (fun z => if (z % 2 = 0 ∧ z / 2 < 9) ∨ (lam ≤ z ∧ z < lam + l) then Fp2.one else Fp2.zero)

/-- LZC's `G`: `σ·256^(z − 32)` on the margin limbs, `σ = ±1` by the verdict (stage_out_c.rs:355-356). -/
def gTab (size lam l verdict : ℕ) : List Fp2 :=
  let sig := if verdict = 1 then Fp2.one else Fp2.one.neg
  (List.range size).map (fun z => if lam ≤ z ∧ z < lam + l then sig.mul (kI (2 ^ (8 * (z - lam)))) else Fp2.zero)

/-- PD's margin vector, zero on the pad channels (stage_out_c.rs:342). -/
def wTab (dpad : ℕ) (w : List ℤ) : List Fp2 :=
  (List.range dpad).map (fun i => if i < w.length then kI (w.getD i 0) else Fp2.zero)

/-- TAB's values `(z mod 256) + g` (stage_out_c.rs:412). -/
def tvTab (size : ℕ) (g : Fp2) : List Fp2 := (List.range size).map (fun z => (kI ((z % 256 : ℕ) : ℤ)).add g)

/-! ## The verify arm's values -/

/-- A table of a slot record: an `eq` table at `start`, a public table (its Lean values), a private table. -/
inductive TabR
  | eq (start : ℕ)
  | pub (vals : List Fp2)
  | priv

/-- **The terminal values** (`run_stage_slot`'s verify arm, token_io.rs:1074-1087): `sel·eq_point(τ, ρ[start..])`
(with the slot's own `τ`), `sel·eval_mle_ext(pub, ρ)`, the masked terminals in order. -/
def stageVals (tau rho es terms : List Fp2) : List TabR → ℕ → Option (List Fp2)
  | [], _ => some []
  | .eq start :: ts, k => do
    let e ← eqPoint tau ((rho.drop start).take tau.length)
    let rest ← stageVals tau rho es terms ts k
    pure ((oneMinusProd es).mul e :: rest)
  | .pub v :: ts, k => do
    let m ← evalMleExt v rho
    let rest ← stageVals tau rho es terms ts k
    pure ((oneMinusProd es).mul m :: rest)
  | .priv :: ts, k => do
    let rest ← stageVals tau rho es terms ts (k + 1)
    pure (terms.getD k Fp2.zero :: rest)

/-- The claimed sum `scalar + Σ coef·scalar_hs` (token_io.rs:1070). -/
def claimedOf (scalar : Fp2) (hosted : List (ℕ × Fp2)) (scalars : List Fp2) : Fp2 :=
  hosted.foldl (fun a h => a.add (h.2.mul (scalars.getD h.1 Fp2.zero))) scalar

/-- **The sumcheck's arithmetic on the recorded challenges** (`sumcheck::verify` without the transcript): every
round has `degree + 1` values and `s(0) + s(1)` is the running claim. -/
def scArith (deg : ℕ) : List (List Fp2) → List Fp2 → Fp2 → Bool
  | [], [], _ => true
  | s :: ss, r :: rs, C =>
    s.length == deg + 1 && (s.getD 0 Fp2.zero).add (s.getD 1 Fp2.zero) == C && scArith deg ss rs (interpolateEval s r)
  | _, _, _ => false

end ZK60.Exec.StageCheck
