/-
D63 lane L68c, part 1c-i (`HonestShieldStageOutTables.lean`):
concrete Shieldstral T128 R13 Stage OUT-C honest witness (`OutcWitness`), byte-lookup multiplicities
(`loLook`, `doLook`, `outcMult` + fiberwise partition identity), shared boundary table contract (`BndTableSpec`
+ canonical `shdP_outcBndTable`), honest Stage OUT-C tables (`TA_out`, `TH_out`, `M_out`, `SlotData`, `OutcTables`),
`outcAlpha_ne_u8K`, data-plane Boolean-cube evaluation lemmas, and `shdP_outc_logupSumClaim_true`.

Split from `HonestShieldStageOutArith.lean` so each file builds cleanly in ~5-10 s under `--cap-gib 6`,
and so Block 25 can directly satisfy `BndTableSpec` and share `TB_25` with `cr.root = rootOf ... TB_25` by `rfl`.
Only at most `propext`, `Classical.choice`, `Quot.sound`; zero `sorry`s.
-/
import ZK60Formal.HonestShieldStageInTables
import ZK60Formal.RunStgShieldOutSat

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.HonestShield

open Polynomial
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Exec.StageV ZK60.Exec.StageCheck ZK60.Sound ZK60.TokenRun ZK60.StageX
open ZK60.HonestClassify ZK60.HonestOpen ZK60.HonestRun
open ZK60.ProtocolClassify ZK60.ProtocolClassify.RunShapeP
open ZK60.RunShape
open ZK60.RunShape.Shield (shieldS0)
open ZK60.Circuit (gP GF)
open ZK60.Model (isqrtWitness inIsqrtWindow fnormElem verdictOf)
open ZK60.Out (OutCPublic margin marginMax margin_abs_le fnormTok fnormElem_eq_some fnormTok_class
  ssOf NormOK ss_bounds40 sigOf)
open ZK60.Exec.Block (BlockParams SlotDef Hist Acc Claims4 Cm Tab)

/-! ## 1. Blinding randomness, shared boundary table contract, and `OutcWitness` extraction -/

section StageOutBase

/-- Prover blinding randomness for Stage OUT-C (`TA_out`, `TH_out`, `M_out`). -/
structure OutcRand where
  aMask : Fin 58 → Fin 4096 → GF
  aProx : Fin 2 → Fin 4096 → GF
  aPads : Fin 76 → Fin 256 → Fp
  aSalts : ℕ → Dig
  hMask : Fin 18 → Fin 4096 → GF
  hProx : Fin 2 → Fin 4096 → GF
  hURaw : Fin 4096 → GF × GF
  hPads : Fin 38 → Fin 256 → Fp
  hSalts : ℕ → Dig
  mA : Fin 8 → Fin 512 → Fp2
  mBRe : Fin 1024 → GF
  mBIm : Fin 1024 → GF
  mURe : Fin 1024 → GF
  mUIm : Fin 1024 → GF
  mSalts : ℕ → Dig

/-- Prover blinding randomness for a 38-row, `logN = 14` boundary table (`TB_25`). -/
structure BndRand where
  bMask : Fin 4 → Fin 16384 → GF
  bProx : Fin 2 → Fin 16384 → GF
  bPads : Fin 38 → Fin 256 → Fp
  bSalts : ℕ → Dig

/-- Abstract specification for Block 25's output boundary table `TB_25` handed into Stage OUT-C.
Keeping `TB` abstract in `shdP_outcTables` lets the full-run composition wire Block 25's exact committed
table directly into Stage OUT-C with `cr.root = rootOf H tag 16 ct.TB` by `rfl`. -/
structure BndTableSpec (y25 : shieldS0.Pos → ℤ) (row : shieldS0.Tok) (TB : Table) : Prop where
  rows_len : TB.rows.length = 38
  cols_len : ∀ j, (TB.cols j).length = 38
  cols_canon : ∀ j, ∀ w ∈ TB.cols j, w.Canon
  cols_honest : ColsHonest shdP_U (lagK 14 (by norm_num)) 256 (cosetPt (rootFp 16)) (2 ^ 14 * 2 ^ 2) TB
  row_eq : ∀ (r : Fin 32) (col : Fin 16384),
    (r.val * 16384 + col.val) / 4096 = row.val →
    (TB.rows.getD r.val []).getD col.val Fp.zero =
      if hc : (r.val * 16384 + col.val) % 4096 < 3072 then
        Fp.fromI64 (y25 (row, ⟨(r.val * 16384 + col.val) % 4096, hc⟩))
      else Fp.zero

/-- `Fp.zero` maps to `0 : GF`. -/
theorem fp_zero_toGF : Fp.zero.toGF = 0 := by simp [Fp.toGF, Fp.zero]

/-- Canonical 38-row × 16384-col boundary table data for `y25 : shieldS0.Pos → ℤ`. -/
noncomputable def shdP_outcBndData (y25 : shieldS0.Pos → ℤ) (rnd : BndRand) : Fin 38 → Fin 16384 → Fp :=
  fun r col =>
    if hr : r.val < 32 then
      let idx := r.val * 16384 + col.val
      let t := idx / 4096
      let ch := idx % 4096
      if hc : ch < 3072 then
        Fp.fromI64 (y25 (⟨t, show t < 128 by have := col.isLt; omega⟩, ⟨ch, hc⟩))
      else Fp.zero
    else if hm : r.val < 36 then
      Fp.ofGF (rnd.bMask ⟨r.val - 32, by omega⟩ col)
    else
      Fp.ofGF (rnd.bProx ⟨r.val - 36, by omega⟩ col)

/-- Canonical standalone boundary table `TB_25` (`38` rows, `logN = 14`, `lr = 2`, `q = 256`). -/
noncomputable def shdP_outcBndTable (y25 : shieldS0.Pos → ℤ) (rnd : BndRand) : Table :=
  mkPcsTable 14 2 256 (by norm_num) (mkRows 38 16384 256 (shdP_outcBndData y25 rnd) rnd.bPads) rnd.bSalts

theorem shdP_outcBndTable_spec (y25 : shieldS0.Pos → ℤ) (row : shieldS0.Tok) (rnd : BndRand) :
    BndTableSpec y25 row (shdP_outcBndTable y25 rnd) where
  rows_len := mkRows_length 38 16384 256 _ _
  cols_len := fun j => (mkPcsTable_cols_length 14 2 256 (by norm_num) _ _ j).trans (mkRows_length 38 16384 256 _ _)
  cols_canon := mkPcsTable_cols_canon 14 2 256 (by norm_num) _ _
  cols_honest := mkPcsTable_colsHonest shdP_U 14 2 256 (by norm_num) _ _
  row_eq := fun r col ht => by
    change ((mkRows 38 16384 256 (shdP_outcBndData y25 rnd) rnd.bPads).getD r.val []).getD col.val Fp.zero = _
    rw [mkRows_data_getD 38 16384 256 _ _ ⟨r.val, by omega⟩ col]
    unfold shdP_outcBndData
    dsimp only
    rw [dite_eq_left r.isLt]
    by_cases hc : (r.val * 16384 + col.val) % 4096 < 3072
    · rw [dite_eq_left hc, dite_eq_left hc]
      congr 2; exact Prod.ext (Fin.ext ht) rfl
    · rw [dite_eq_right hc, dite_eq_right hc]

/-- Complete integer witness extracted from `(classifyModelP Rp).admissible x` and `Rp.out.Valid`. -/
structure OutcWitness (Rp : ClassifyRunPublicP shieldS0) (x : shieldS0.Tok → ℕ) where
  x0 : shieldS0.Pos → ℤ
  y25 : shieldS0.Pos → ℤ
  hin : inSpec Rp.inp x = some x0
  hrun : runSpecP Rp.blks x0 = some y25
  d : ℤ
  a1 : ℤ
  a2 : ℤ
  q : Fin 3072 → ℤ
  r : Fin 3072 → ℤ
  s : Fin 3072 → ℤ
  v : ℕ
  Δ : ℤ
  δ : ℤ
  hxRow : ∀ i : Fin 3072, ZK60.i16 (y25 (Rp.row, i))
  hd_lo : 1 ≤ d
  hd_hi : d < 2 ^ 24
  ha1_lo : 0 ≤ a1
  ha1_hi : a1 < 2 ^ 24
  ha2_lo : 0 ≤ a2
  ha2_hi : a2 < 2 ^ 24
  hdsq_eq : d * d + a1 = Rp.out.ceps + ∑ i : Fin 3072, y25 (Rp.row, i) * y25 (Rp.row, i)
  ha12_eq : a1 + a2 = 2 * d
  hq_lo : ∀ i : Fin 3072, -127 ≤ q i
  hq_hi : ∀ i : Fin 3072, q i ≤ 127
  hr_lo : ∀ i : Fin 3072, 0 ≤ r i
  hr_hi : ∀ i : Fin 3072, r i < 2 ^ 32
  hs_lo : ∀ i : Fin 3072, 0 ≤ s i
  hs_hi : ∀ i : Fin 3072, s i < 2 ^ 32
  hc0 : ∀ i : Fin 3072,
    y25 (Rp.row, i) * (2 * Rp.out.g0 * Rp.out.cn) + d * 2 ^ Rp.out.tn
      - (d * 2 ^ (Rp.out.tn + 1)) * q i - r i = 0
  hc1 : ∀ i : Fin 3072, s i + r i + 1 - d * 2 ^ (Rp.out.tn + 1) = 0
  hΔ : Δ = margin Rp.out q
  hv_spec : classifySpecP Rp x = some v
  hv_def : v = verdictOf Δ Rp.out.c
  hv_le : v ≤ 1
  hδ_lo : 0 ≤ δ
  hδ_hi : δ < 2 ^ (8 * Rp.out.limbs)
  hδ_rel : (if v = 1 then (1 : ℤ) else -1) * δ + ((v : ℤ) + Rp.out.c) = Δ

/-- Extract a full `OutcWitness` from `(classifyModelP Rp).admissible x` and `Rp.out.Valid`. -/
noncomputable def outcWitness_of_adm (Rp : ClassifyRunPublicP shieldS0) (hOut : Rp.out.Valid)
    (x : shieldS0.Tok → ℕ) (hx : (classifyModelP Rp).admissible x) : OutcWitness Rp x := by
  have hex : ∃ w : OutcWitness Rp x, True := by
    obtain ⟨v, hv⟩ := hx
    change classifySpecP Rp x = some v at hv
    have hv_spec : classifySpecP Rp x = some v := hv
    unfold classifySpecP at hv
    cases hin : inSpec Rp.inp x with
    | none => rw [hin] at hv; cases hv
    | some x0 =>
      rw [hin] at hv
      cases hrun : runSpecP Rp.blks x0 with
      | none => rw [hrun] at hv; cases hv
      | some y25 =>
        rw [hrun] at hv
        change outCSpec Rp.out (fun i => y25 (Rp.row, i)) = some v at hv
        unfold outCSpec at hv
        obtain ⟨⟨dd, yy⟩, hft, hveq⟩ := Option.map_eq_some_iff.mp hv
        have hft' := hft
        unfold fnormTok at hft
        by_cases hok : (∀ i : Fin 3072, ZK60.i16 (y25 (Rp.row, i))) ∧ NormOK (ssOf Rp.out.ceps (fun i => y25 (Rp.row, i)))
        · rw [ite_eq_left hok] at hft
          obtain ⟨hxRow, hss0, hdne0, hw0, hw1, hw2⟩ := hok
          obtain ⟨vfn, hvfn, hpair⟩ := Option.map_eq_some_iff.mp hft
          obtain ⟨hdd, hvyy⟩ := Prod.mk.inj hpair
          subst hdd
          rw [hvyy] at hvfn
          set ss := ssOf Rp.out.ceps (fun i => y25 (Rp.row, i)) with hss_def
          set iw := isqrtWitness ss with hiw_def
          have hd_win : 0 ≤ iw.1 ∧ iw.1 < 2 ^ 24 := of_decide_eq_true hw0
          have ha1_win : 0 ≤ iw.2.1 ∧ iw.2.1 < 2 ^ 24 := of_decide_eq_true hw1
          have ha2_win : 0 ≤ iw.2.2 ∧ iw.2.2 < 2 ^ 24 := of_decide_eq_true hw2
          have hd_lo : 1 ≤ iw.1 := by omega
          have hT0 : (0 : ℤ) < 2 ^ Rp.out.tn := by positivity
          have hden0 : (0 : ℤ) < 2 * (iw.1 * 2 ^ Rp.out.tn) := by nlinarith
          have helem : ∀ i : Fin 3072, ∃ r s : ℤ,
              fnormElem Rp.out.tn Rp.out.cn Rp.out.g0 32 iw.1 (y25 (Rp.row, i)) = some (yy i, r, s) := by
            intro i
            have he := liftO_eq_some.mp hvfn i
            cases hn : fnormElem Rp.out.tn Rp.out.cn Rp.out.g0 32 iw.1 (y25 (Rp.row, i)) with
            | none => rw [hn] at he; cases he
            | some e =>
              obtain ⟨q0, r0, s0⟩ := e
              rw [hn] at he
              have hq0 : q0 = yy i := Option.some.inj he
              subst hq0
              exact ⟨r0, s0, rfl⟩
          choose rFn sFn hrsFn using helem
          have hq_bounds : ∀ i : Fin 3072, -127 ≤ yy i ∧ yy i ≤ 127 := fun i =>
            fnormTok_class hft' i
          have hr_lo : ∀ i : Fin 3072, 0 ≤ rFn i := fun i => by
            obtain ⟨-, -, hr, -⟩ := fnormElem_eq_some.mp (hrsFn i)
            rw [hr]; exact Int.emod_nonneg _ (ne_of_gt hden0)
          have hr_hi : ∀ i : Fin 3072, rFn i < 2 ^ 32 := fun i => by
            obtain ⟨⟨-, -, hr1, -⟩, -, hr, -⟩ := fnormElem_eq_some.mp (hrsFn i)
            rw [hr]; exact hr1
          have hs_lo : ∀ i : Fin 3072, 0 ≤ sFn i := fun i => by
            obtain ⟨-, -, hr, hs⟩ := fnormElem_eq_some.mp (hrsFn i)
            have hlt : (2 * y25 (Rp.row, i) * Rp.out.g0 * Rp.out.cn + iw.1 * 2 ^ Rp.out.tn) %
                (2 * (iw.1 * 2 ^ Rp.out.tn)) < 2 * (iw.1 * 2 ^ Rp.out.tn) :=
              Int.emod_lt_of_pos _ hden0
            rw [hs]; linarith
          have hs_hi : ∀ i : Fin 3072, sFn i < 2 ^ 32 := fun i => by
            obtain ⟨⟨-, -, -, hs1⟩, -, -, hs⟩ := fnormElem_eq_some.mp (hrsFn i)
            rw [hs]; exact hs1
          have hc0 : ∀ i : Fin 3072,
              y25 (Rp.row, i) * (2 * Rp.out.g0 * Rp.out.cn) + iw.1 * 2 ^ Rp.out.tn
                - (iw.1 * 2 ^ (Rp.out.tn + 1)) * yy i - rFn i = 0 := fun i => by
            obtain ⟨-, hq, hr, -⟩ := fnormElem_eq_some.mp (hrsFn i)
            have hdiv := Int.mul_ediv_add_emod
              (2 * y25 (Rp.row, i) * Rp.out.g0 * Rp.out.cn + iw.1 * 2 ^ Rp.out.tn)
              (2 * (iw.1 * 2 ^ Rp.out.tn))
            have hpow : (2 : ℤ) ^ (Rp.out.tn + 1) = 2 * 2 ^ Rp.out.tn := by ring
            rw [hpow, hq, hr]
            linarith
          have hc1 : ∀ i : Fin 3072, sFn i + rFn i + 1 - iw.1 * 2 ^ (Rp.out.tn + 1) = 0 := fun i => by
            obtain ⟨-, -, hr, hs⟩ := fnormElem_eq_some.mp (hrsFn i)
            have hpow : (2 : ℤ) ^ (Rp.out.tn + 1) = 2 * 2 ^ Rp.out.tn := by ring
            rw [hpow, hr, hs]
            ring
          set Δ := margin Rp.out yy with hΔ_def
          have hv_def : v = verdictOf Δ Rp.out.c := hveq.symm
          have hv_le : v ≤ 1 := by
            rw [hv_def]; unfold verdictOf; split_ifs <;> norm_num
          have hΔ_abs : |Δ| ≤ marginMax 3072 := margin_abs_le Rp.out hOut yy hq_bounds
          have hΔ_bd := abs_le.mp hΔ_abs
          have hc_bd := abs_le.mp hOut.c
          have hwin := hOut.win
          let δ : ℤ := if v = 1 then Δ - Rp.out.c - 1 else Rp.out.c - Δ
          have hδ_lo : 0 ≤ δ := by
            dsimp only [δ]
            rw [hv_def]; unfold verdictOf
            by_cases hgt : Rp.out.c < Δ
            · rw [ite_eq_left hgt]; norm_num; linarith
            · rw [ite_eq_right hgt]; norm_num; linarith
          have hδ_hi : δ < 2 ^ (8 * Rp.out.limbs) := by
            dsimp only [δ]
            split_ifs <;> linarith
          have hδ_rel : (if v = 1 then (1 : ℤ) else -1) * δ + ((v : ℤ) + Rp.out.c) = Δ := by
            dsimp only [δ]
            rcases Nat.le_one_iff_eq_zero_or_eq_one.mp hv_le with h0 | h1
            · rw [h0]; norm_num; ring
            · rw [h1]; norm_num; ring
          refine ⟨⟨x0, y25, hin, hrun, iw.1, iw.2.1, iw.2.2, yy, rFn, sFn, v, Δ, δ,
            hxRow, hd_lo, hd_win.2, ha1_win.1, ha1_win.2, ha2_win.1, ha2_win.2,
            ?_, ?_, fun i => (hq_bounds i).1, fun i => (hq_bounds i).2,
            hr_lo, hr_hi, hs_lo, hs_hi, hc0, hc1, rfl, hv_spec, hv_def, hv_le, hδ_lo, hδ_hi, hδ_rel⟩, trivial⟩
          · change iw.1 * iw.1 + (ss - iw.1 * iw.1) = ss; ring
          · change (ss - iw.1 * iw.1) + (2 * iw.1 - (ss - iw.1 * iw.1)) = 2 * iw.1; ring
        · rw [ite_eq_right hok] at hft; cases hft
  exact Classical.choose hex

/-! ## 2. Byte decomposition, `loLook`, `doLook`, `outcMult`, and fiberwise partition -/

/-- `k`-th byte `(n / 2^(8*k)) % 256` as a `Fin 256`. -/
def byteOf (k n : ℕ) : Fin 256 :=
  ⟨(n / 2 ^ (8 * k)) % 256, Nat.mod_lt _ (by norm_num)⟩

theorem sum_bytes_eq : ∀ (m n : ℕ), n < 2 ^ (8 * m) →
    ∑ k ∈ Finset.range m, 2 ^ (8 * k) * (byteOf k n).val = n
  | 0, n, hn => by
    simp only [Nat.mul_zero, pow_zero] at hn
    simp only [Finset.range_zero, Finset.sum_empty]
    omega
  | m + 1, n, hn => by
    rw [Finset.sum_range_succ']
    simp only [Nat.mul_zero, pow_zero, one_mul]
    have hq : n / 256 < 2 ^ (8 * m) := by
      have hpow : 2 ^ (8 * (m + 1)) = 2 ^ (8 * m) * 256 := by
        rw [show 8 * (m + 1) = 8 * m + 8 by omega, pow_add]; norm_num
      rw [hpow] at hn
      exact Nat.div_lt_of_lt_mul (by linarith)
    have ih := sum_bytes_eq m (n / 256) hq
    have hshift : ∑ k ∈ Finset.range m, 2 ^ (8 * (k + 1)) * (byteOf (k + 1) n).val
        = 256 * ∑ k ∈ Finset.range m, 2 ^ (8 * k) * (byteOf k (n / 256)).val := by
      rw [Finset.mul_sum]
      refine Finset.sum_congr rfl (fun k _ => ?_)
      have hpow : 2 ^ (8 * (k + 1)) = 256 * 2 ^ (8 * k) := by
        rw [show 8 * (k + 1) = 8 + 8 * k by omega, pow_add]; norm_num
      have hdiv : n / 2 ^ (8 * (k + 1)) = (n / 256) / 2 ^ (8 * k) := by
        rw [hpow, Nat.div_div_eq_div_mul]
      simp only [byteOf, hpow, hdiv]
      ring
    rw [hshift, ih]
    simp only [byteOf, Nat.mul_zero, pow_zero, Nat.div_one]
    have hmod := Nat.div_add_mod n 256
    omega

theorem sum_bytes_3 (n : ℕ) (hn : n < 2 ^ 24) :
    (byteOf 0 n).val + (byteOf 1 n).val * 256 + (byteOf 2 n).val * 65536 = n := by
  have h := sum_bytes_eq 3 n (by simpa using hn)
  simp only [Finset.sum_range_succ, Finset.range_zero, Finset.sum_empty, zero_add] at h
  linarith

theorem sum_bytes_4 (n : ℕ) (hn : n < 2 ^ 32) :
    ∑ k ∈ Finset.range 4, (byteOf k n).val * 2 ^ (8 * k) = n := by
  have h := sum_bytes_eq 4 n (by simpa using hn)
  simpa only [mul_comm] using h

/-- Byte lookup value at `col : Fin 4096` of `ocC_LIMB` (`0` on all pad columns). -/
def loLook {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (col : Fin 4096) : Fin 256 :=
  if col.val % 2 = 0 ∧ col.val / 2 < 3 then byteOf (col.val / 2) w.d.toNat
  else if col.val % 2 = 0 ∧ col.val / 2 < 6 then byteOf (col.val / 2 - 3) w.a1.toNat
  else if col.val % 2 = 0 ∧ col.val / 2 < 9 then byteOf (col.val / 2 - 6) w.a2.toNat
  else if 32 ≤ col.val ∧ col.val < 32 + Rp.out.limbs then byteOf (col.val - 32) w.δ.toNat
  else ⟨0, by norm_num⟩

/-- Byte lookup value at `(l, col) : Fin 12 × Fin 4096` of `DZC`'s 12 ungated `Do` lookups.
CRITICAL: on pad channels `col ≥ 3072`, lookups `2` (`Y + 127`) and `3` (`-Y + 127`) look up `127`! -/
def doLook {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (l : Fin 12) (col : Fin 4096) : Fin 256 :=
  if hc : col.val < 3072 then
    let i : Fin 3072 := ⟨col.val, hc⟩
    match l.val with
    | 0 => byteOf 0 (w.y25 (Rp.row, i) + 32768).toNat
    | 1 => byteOf 1 (w.y25 (Rp.row, i) + 32768).toNat
    | 2 => ⟨(w.q i + 127).toNat, by have h1 := w.hq_lo i; have h2 := w.hq_hi i; omega⟩
    | 3 => ⟨(-w.q i + 127).toNat, by have h1 := w.hq_lo i; have h2 := w.hq_hi i; omega⟩
    | 4 => byteOf 0 (w.r i).toNat
    | 5 => byteOf 1 (w.r i).toNat
    | 6 => byteOf 2 (w.r i).toNat
    | 7 => byteOf 3 (w.r i).toNat
    | 8 => byteOf 0 (w.s i).toNat
    | 9 => byteOf 1 (w.s i).toNat
    | 10 => byteOf 2 (w.s i).toNat
    | _ => byteOf 3 (w.s i).toNat
  else
    if l.val = 2 ∨ l.val = 3 then ⟨127, by norm_num⟩ else ⟨0, by norm_num⟩

/-- Exact byte multiplicity across all `4096 + 12 * 4096 = 53248` Stage OUT-C lookups. -/
def outcMult {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (z : Fin 256) : ℕ :=
  (Finset.univ.filter (fun col : Fin 4096 => loLook w col = z)).card
  + ∑ l : Fin 12, (Finset.univ.filter (fun col : Fin 4096 => doLook w l col = z)).card

theorem outcMult_le {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (z : Fin 256) : outcMult w z ≤ 53248 := by
  unfold outcMult
  have h1 : (Finset.univ.filter (fun col : Fin 4096 => loLook w col = z)).card ≤ 4096 :=
    (Finset.card_filter_le _ _).trans (by simp)
  have h2 : ∑ l : Fin 12, (Finset.univ.filter (fun col : Fin 4096 => doLook w l col = z)).card
      ≤ ∑ _l : Fin 12, 4096 :=
    Finset.sum_le_sum (fun l _ => (Finset.card_filter_le _ _).trans (by simp))
  simp only [Finset.sum_const, Finset.card_univ, Fintype.card_fin, smul_eq_mul] at h2
  omega

theorem outcMult_lt_gP {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (z : Fin 256) : outcMult w z < gP :=
  lt_of_le_of_lt (outcMult_le w z) (by norm_num [gP])

/-- Fiberwise LogUp partition identity for Stage OUT-C: for ANY `φ : Fin 256 → shdP_K`,
`∑ col, φ(loLook col) + ∑ l, ∑ col, φ(doLook l col) = ∑ z, outcMult z * φ z`. -/
theorem outcMult_sum_fiber {Rp : ClassifyRunPublicP shieldS0} {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (φ : Fin 256 → shdP_K) :
    (∑ col : Fin 4096, φ (loLook w col))
      + (∑ l : Fin 12, ∑ col : Fin 4096, φ (doLook w l col))
      = ∑ z : Fin 256, (outcMult w z : shdP_K) * φ z := by
  have hfib : ∀ (f : Fin 4096 → Fin 256),
      ∑ col : Fin 4096, φ (f col)
        = ∑ z : Fin 256, ((Finset.univ.filter (fun col : Fin 4096 => f col = z)).card : shdP_K) * φ z := by
    intro f
    rw [← Finset.sum_fiberwise_of_maps_to (fun _ _ => Finset.mem_univ (f _)) (fun col => φ (f col))]
    refine Finset.sum_congr rfl (fun z _ => ?_)
    have hconst : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => f col = z), φ (f col)
        = ∑ _col ∈ Finset.univ.filter (fun col : Fin 4096 => f col = z), φ z :=
      Finset.sum_congr rfl (fun col hcol => by rw [(Finset.mem_filter.mp hcol).2])
    rw [hconst, Finset.sum_const, nsmul_eq_mul]
  rw [hfib (loLook w)]
  simp_rw [hfib (doLook w _)]
  rw [Finset.sum_comm, ← Finset.sum_add_distrib]
  refine Finset.sum_congr rfl (fun z _ => ?_)
  unfold outcMult
  rw [Nat.cast_add, Nat.cast_sum, add_mul, Finset.sum_mul]

/-- When `outcAlphaBad ch = false`, `α ≠ z + γ·TAG_U8` in `shdP_K` for every `z < 256`. -/
theorem outcAlpha_ne_u8K (ch : List Fp2) (hch : ∀ a ∈ ch, a.Canon) (hbad : outcAlphaBad ch = false)
    (z : ℕ) (hz : z < 256) :
    let gamma := ch.getD 0 Fp2.zero
    let alpha := ch.getD 1 Fp2.zero
    let gU8 := gamma.mulBase (Fp.new (UInt64.ofNat tagU8))
    alpha.toK shdP_U ≠ (z : shdP_K) + gU8.toK shdP_U := by
  intro gamma alpha gU8 hEq
  have hcanA : alpha.Canon := Fp2.canon_getD hch 1
  have hcanG : gU8.Canon := Fp2.canon_mulBase _ _
  have hcanU : (u8Entry gamma z).Canon := Fp2.canon_add _ _
  have hu8K : (u8Entry gamma z).toK shdP_U = (z : shdP_K) + gU8.toK shdP_U := by
    unfold u8Entry
    rw [Fp2.toK_add shdP_U _ _ (kI_canon _) hcanG, kI_nat_toK shdP_U z (by omega)]
  have hsub0 : (alpha.sub (u8Entry gamma z)).toK shdP_U = 0 := by
    rw [Fp2.toK_sub shdP_U _ _ hcanA hcanU, hu8K, hEq, sub_self]
  have hsubZ : (alpha.sub (u8Entry gamma z)).isZero = true :=
    (isZero_iff_toK shdP_U shdP_hU _ (Fp2.canon_sub _ _ hcanA hcanU)).mpr hsub0
  have hany : (List.range 256).any (fun k => (alpha.sub (u8Entry gamma k)).isZero) = true :=
    List.any_eq_true.mpr ⟨z, List.mem_range.mpr hz, hsubZ⟩
  change (List.range 256).any (fun k => (alpha.sub (u8Entry gamma k)).isZero) = false at hbad
  rw [hany] at hbad
  cases hbad

end StageOutBase

/-! ## 3. Concrete Stage OUT-C honest tables (`TA_out`, `TH_out`, `M_out`, `SlotData`, `OutcTables`) -/

section StageOutTables

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ)

/-- Base-field data entries of `TA_out` (`76` rows × `4096` cols). -/
noncomputable def shdP_outcTAData {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) :
    Fin 76 → Fin 4096 → Fp :=
  fun r col =>
    if r.val = 0 then
      if col.val = 0 then Fp.fromI64 w.d else Fp.zero
    else if r.val = 1 then
      if col.val = 0 then Fp.fromI64 (w.d * w.d) else Fp.zero
    else if r.val = 2 then
      Fp.ofGF ((loLook w col).val : GF)
    else if r.val = 3 then
      if hc : col.val < 3072 then Fp.fromI64 (w.y25 (Rp.row, ⟨col.val, hc⟩)) else Fp.zero
    else if r.val = 4 then
      Fp.ofGF ((doLook w ⟨0, by norm_num⟩ col).val : GF)
    else if r.val = 5 then
      Fp.ofGF ((doLook w ⟨1, by norm_num⟩ col).val : GF)
    else if r.val = 6 then
      if hc : col.val < 3072 then Fp.fromI64 (w.q ⟨col.val, hc⟩) else Fp.zero
    else if hr : r.val < 15 then
      Fp.ofGF ((doLook w ⟨r.val - 3, by omega⟩ col).val : GF)
    else if r.val = 15 then
      if hc : col.val < 256 then Fp.ofGF (outcMult w ⟨col.val, hc⟩ : GF) else Fp.zero
    else if hm : r.val < 74 then
      Fp.ofGF (rnd.aMask ⟨r.val - 16, by omega⟩ col)
    else
      Fp.ofGF (rnd.aProx ⟨r.val - 74, by omega⟩ col)

/-- Per-row reduction lemmas for `shdP_outcTAData` (`rfl` on concrete row indices `0..15`). -/
theorem shdP_outcTAData_0 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨0, by norm_num⟩ col = if col.val = 0 then Fp.fromI64 w.d else Fp.zero := rfl

theorem shdP_outcTAData_1 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨1, by norm_num⟩ col = if col.val = 0 then Fp.fromI64 (w.d * w.d) else Fp.zero := rfl

theorem shdP_outcTAData_2 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨2, by norm_num⟩ col = Fp.ofGF ((loLook w col).val : GF) := rfl

theorem shdP_outcTAData_3 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨3, by norm_num⟩ col = if hc : col.val < 3072 then Fp.fromI64 (w.y25 (Rp.row, ⟨col.val, hc⟩)) else Fp.zero := rfl

theorem shdP_outcTAData_4 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨4, by norm_num⟩ col = Fp.ofGF ((doLook w ⟨0, by norm_num⟩ col).val : GF) := rfl

theorem shdP_outcTAData_5 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨5, by norm_num⟩ col = Fp.ofGF ((doLook w ⟨1, by norm_num⟩ col).val : GF) := rfl

theorem shdP_outcTAData_6 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨6, by norm_num⟩ col = if hc : col.val < 3072 then Fp.fromI64 (w.q ⟨col.val, hc⟩) else Fp.zero := rfl

theorem shdP_outcTAData_do {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (r : ℕ) (hr1 : 7 ≤ r) (hr2 : r < 15) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨r, by omega⟩ col = Fp.ofGF ((doLook w ⟨r - 3, by omega⟩ col).val : GF) := by
  unfold shdP_outcTAData
  dsimp only
  rw [ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), ite_eq_right (by omega), ite_eq_right (by omega),
    ite_eq_right (by omega), dite_eq_left hr2]

theorem shdP_outcTAData_15 {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) (col : Fin 4096) :
    shdP_outcTAData Rp w rnd ⟨15, by norm_num⟩ col = if hc : col.val < 256 then Fp.ofGF (outcMult w ⟨col.val, hc⟩ : GF) else Fp.zero := rfl

/-- Honest `TA_out` table (`76` rows, `logN = 12`, `lr = 2`, `q = 256`). -/
noncomputable def shdP_outcTA {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) : Table :=
  mkPcsTable 12 2 256 (by norm_num) (mkRows 76 4096 256 (shdP_outcTAData Rp w rnd) rnd.aPads) rnd.aSalts

/-- Zero-sum blinding helper `H_U` entry (`col = 0` set to `-∑_{j=1}^{4095} rnd.hURaw j`). -/
def shdP_outcHUVal (rnd : OutcRand) (col : Fin 4096) : GF × GF :=
  if col.val = 0 then
    (- ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).1,
     - ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).2)
  else
    rnd.hURaw col

theorem shdP_outcHUVal_sum_re (rnd : OutcRand) :
    ∑ col : Fin 4096, (shdP_outcHUVal rnd col).1 = 0 := by
  rw [Fin.sum_univ_succ]
  have h0 : (shdP_outcHUVal rnd 0).1 = - ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).1 := rfl
  have hs : ∀ j : Fin 4095, (shdP_outcHUVal rnd j.succ).1 = (rnd.hURaw ⟨j.val + 1, by omega⟩).1 := fun j => by
    unfold shdP_outcHUVal
    have hne : j.succ.val ≠ 0 := by simp [Fin.val_succ]
    rw [ite_eq_right hne]
    rfl
  simp_rw [hs]
  rw [h0, neg_add_cancel]

theorem shdP_outcHUVal_sum_im (rnd : OutcRand) :
    ∑ col : Fin 4096, (shdP_outcHUVal rnd col).2 = 0 := by
  rw [Fin.sum_univ_succ]
  have h0 : (shdP_outcHUVal rnd 0).2 = - ∑ j : Fin 4095, (rnd.hURaw ⟨j.val + 1, by omega⟩).2 := rfl
  have hs : ∀ j : Fin 4095, (shdP_outcHUVal rnd j.succ).2 = (rnd.hURaw ⟨j.val + 1, by omega⟩).2 := fun j => by
    unfold shdP_outcHUVal
    have hne : j.succ.val ≠ 0 := by simp [Fin.val_succ]
    rw [ite_eq_right hne]
    rfl
  simp_rw [hs]
  rw [h0, neg_add_cancel]

/-- Value in `shdP_K` of `H` plane `p ∈ 0..7` at `(gamma, alpha, col)`. -/
noncomputable def shdP_outcHValK {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (gamma alpha : Fp2) (p : Fin 8) (col : Fin 4096) : shdP_K :=
  let gU8K := (gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U
  let α := alpha.toK shdP_U
  if p.val = 0 then
    (α - ((loLook w col).val + gU8K))⁻¹
  else if hp : p.val < 7 then
    let k := p.val - 1
    (α - ((doLook w ⟨2 * k, by omega⟩ col).val + gU8K))⁻¹
      + (α - ((doLook w ⟨2 * k + 1, by omega⟩ col).val + gU8K))⁻¹
  else
    if hc : col.val < 256 then
      (outcMult w ⟨col.val, hc⟩ : shdP_K) * (α - ((col.val : shdP_K) + gU8K))⁻¹
    else 0

/-- Base-field data entries of `TH_out` (`38` rows × `4096` cols), parameterized directly by `(gamma, alpha)`. -/
noncomputable def shdP_outcTHData {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (gamma alpha : Fp2) : Fin 38 → Fin 4096 → Fp :=
  fun r col =>
    if hr : r.val < 16 then
      let p : Fin 8 := ⟨r.val / 2, by omega⟩
      let v := ofK shdP_U shdP_hbij (shdP_outcHValK Rp w gamma alpha p col)
      if r.val % 2 = 0 then v.c0 else v.c1
    else if r.val = 16 then
      Fp.ofGF (shdP_outcHUVal rnd col).1
    else if r.val = 17 then
      Fp.ofGF (shdP_outcHUVal rnd col).2
    else if hm : r.val < 36 then
      Fp.ofGF (rnd.hMask ⟨r.val - 18, by omega⟩ col)
    else
      Fp.ofGF (rnd.hProx ⟨r.val - 36, by omega⟩ col)

/-- Honest `TH_out` table at `(gamma, alpha)` (`38` rows, `logN = 12`, `lr = 2`, `q = 256`). -/
noncomputable def shdP_outcTH {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (gamma alpha : Fp2) : Table :=
  mkPcsTable 12 2 256 (by norm_num) (mkRows 38 4096 256 (shdP_outcTHData Rp w rnd gamma alpha) rnd.hPads) rnd.hSalts

/-- Honest `M_out` table (`S = 8`) via shared `mkMTable`. -/
noncomputable def shdP_outcM (rnd : OutcRand) : MTable :=
  mkMTable 8 rnd.mA rnd.mBRe rnd.mBIm rnd.mURe rnd.mUIm rnd.mSalts

/-- Private slot sum `S_s` for Stage OUT-C:
- slot 1 (`SS`): `∑_{i < 3072} (x_row i)^2`
- slot 3 (`PD`): `∑_{i < 3072} q_i · wΔ_i = Δ`
- all other slots: `0`. -/
noncomputable def outcPrivSum {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) : ℕ → shdP_K
  | 1 => ∑ i : Fin 3072, ((w.y25 (Rp.row, i) : shdP_K) * (w.y25 (Rp.row, i) : shdP_K))
  | 3 => ∑ i : Fin 3072, ((w.q i : shdP_K) * (Rp.out.wΔ i : shdP_K))
  | _ => 0

/-- Table-evaluation oracle `cs` for Stage OUT-C at `(TA, TH, TB)`. -/
noncomputable def outcCs (TA TH TB : Table) : Cm → Block.ZClaim → shdP_K
  | .a, z => Link.claimSem shdP_U 76 12 0 (tabMat 76 12 TA.rows) z
  | .h, z => Link.claimSem shdP_U 38 12 0 (tabMat 38 12 TH.rows) z
  | .inp, z => Link.claimSem shdP_U 38 14 0 (tabMat 38 14 TB.rows) z
  | .out, _ => 0

/-- Honest `SlotData` for Stage OUT-C (`shdVo tag Rp wDigest bOutRow v`), handling `.standalone`, `.priv`, and `.host`
uniformly via `polySlotData` + `mRowKOf 8 rnd.mA` + `shdP_outcTH Rp w rnd hist.gamma hist.alpha`. -/
noncomputable def shdP_outcSlotData (v : ℕ) {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (TA TB : Table) (rnd : OutcRand) :
    SlotData (shdVo tag Rp wDigest bOutRow v).bp :=
  let P := (shdVo tag Rp wDigest bOutRow v).bp
  let mRow := mRowKOf 8 rnd.mA
  let G : ℕ → shdP_K := fun s => cubeSum (Link.maskPoly mRow s (slotN P s) (slotD P s))
  polySlotData P shdP_U shdP_hbij
    (fun s hist acc df ch0 =>
      match P.kind s with
      | .standalone => ofK shdP_U shdP_hbij (ch0.toK shdP_U * G s)
      | .priv => ofK shdP_U shdP_hbij (outcPrivSum Rp w s + ch0.toK shdP_U * G s)
      | .host =>
        ofK shdP_U shdP_hbij (ch0.toK shdP_U * G s
          - (df.hosted.map fun hk =>
              hk.2.toK shdP_U * (acc.cs.getD hk.1 Fp2.zero).toK shdP_U * G hk.1).sum))
    (fun s hist _ df ch0 z =>
      let TH := shdP_outcTH Rp w rnd hist.gamma hist.alpha
      slotPolyK P (fun _ => 14) (outcCs TA TH TB) s df z
        + ch0.toK shdP_U * Link.maskPoly mRow s (slotN P s) (slotD P s) z)
    (fun s hist _ df _ rho =>
      let n := (Exec.Block.slotShape P s).1
      let TH := shdP_outcTH Rp w rnd hist.gamma hist.alpha
      stgPrivVals shdP_U shdP_hbij P (outcCs TA TH TB) (rho.take n) (rho.drop n) df.tabs)

/-- Concrete `OutcTables (shdVo tag Rp wDigest bOutRow v)` parameterized by abstract `TB : Table` (`TB_25`). -/
noncomputable def shdP_outcTables (v : ℕ) {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (TB : Table) (rnd : OutcRand) :
    OutcTables (shdVo tag Rp wDigest bOutRow v) where
  TA := shdP_outcTA Rp w rnd
  M := shdP_outcM rnd
  TH := fun ch => shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)
  TB := TB
  slot := shdP_outcSlotData tag Rp wDigest bOutRow v w (shdP_outcTA Rp w rnd) TB rnd

/-! ### Row-length & `ColsHonest` lemmas -/

theorem shdP_outcTA_rows_len {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) :
    (shdP_outcTA Rp w rnd).rows.length = 76 :=
  mkRows_length 76 4096 256 _ _

theorem shdP_outcTH_rows_len {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (gamma alpha : Fp2) :
    (shdP_outcTH Rp w rnd gamma alpha).rows.length = 38 :=
  mkRows_length 38 4096 256 _ _

theorem shdP_outcTA_colsHonest {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand) :
    ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2)
      (shdP_outcTA Rp w rnd) :=
  mkPcsTable_colsHonest shdP_U 12 2 256 (by norm_num) _ _

theorem shdP_outcTH_colsHonest {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (gamma alpha : Fp2) :
    ColsHonest shdP_U (lagK 12 (by norm_num)) 256 (cosetPt (rootFp 14)) (2 ^ 12 * 2 ^ 2)
      (shdP_outcTH Rp w rnd gamma alpha) :=
  mkPcsTable_colsHonest shdP_U 12 2 256 (by norm_num) _ _

end StageOutTables

/-! ## 4. Layout offsets, narrow-slice evaluation, and `shdP_outc_logupSumClaim_true` -/

section StageOutDataEval

variable (tag : MTag) (Rp : ClassifyRunPublicP shieldS0) (wDigest : Dig) (bOutRow : ℕ)

/-- Layout `aOff` for Stage OUT-C (`p * 4096` for `p < 16`). -/
theorem shdP_outcLay_aOff (v : ℕ) (p : ℕ) (hp : p < 16) :
    (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aOff p = p * 4096 := by
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hllo
  have hldo' : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hldo
  have hltab' : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hltab
  have hlt' : (rcVerdict (shdP_outcPub Rp wDigest) v).lt = 12 := rfl
  have haRowsL : (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).aRowsL = List.replicate 16 1 := by
    simp only [outcLay, Lay.aRowsL, OutcPub.toLog, hllo', hldo', hltab', hlt', rowsOf, List.replicate]
    decide
  unfold Lay.aOff Lay.n
  rw [haRowsL]
  change (List.take p (List.replicate 16 1)).sum * 2 ^ 12 = p * 4096
  rw [List.take_replicate, Nat.min_eq_left (by omega), List.sum_replicate, smul_eq_mul, mul_one]
  norm_num

/-- Layout `hOff` for Stage OUT-C (`(2 * p * 4096, (2 * p + 1) * 4096)` for `p < 9`). -/
theorem shdP_outcLay_hOff (v : ℕ) (p : ℕ) (hp : p < 9) :
    (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hOff p = (2 * p * 4096, (2 * p + 1) * 4096) := by
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hllo' : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hllo
  have hldo' : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hldo
  have hltab' : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hltab
  have hlt' : (rcVerdict (shdP_outcPub Rp wDigest) v).lt = 12 := rfl
  have hhRowsL : (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).hRowsL = List.replicate 9 1 := by
    simp only [outcLay, Lay.hRowsL, hllo', hldo', hltab', hlt', rowsOf, List.replicate]
    decide
  unfold Lay.hOff Lay.n
  rw [hhRowsL]
  have htake : ((List.replicate 9 1).take p).sum = p := by
    rw [List.take_replicate, Nat.min_eq_left (by omega), List.sum_replicate, smul_eq_mul, mul_one]
  have hget : (List.replicate 9 1).getD p 0 = 1 := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left hp, Option.getD_some]
  rw [htake, hget]
  change (2 * p * 2 ^ 12, (2 * p + 1) * 2 ^ 12) = _
  norm_num

/-- Helper: evaluate a narrow `log = 1` slice at `off = r0 * 4096 + c0` (`c0 + 2 ≤ 4096`, `r0 < R`)
at Boolean bit `b : Fin 1 → Bool`. -/
theorem data_slice_narrow1 (R r0 c0 : ℕ) (hr0 : r0 < R) (hc0 : c0 + 2 ≤ 4096)
    (X : Fin R → Fin (2 ^ 12 + 0) → shdP_K)
    (b : Fin 1 → Bool) (pt : ℕ → shdP_K) (hpt : pt 0 = (bit (b ⟨0, by norm_num⟩) : shdP_K)) :
    ∑ row : Fin R, dataRowK (r0 * 4096 + c0) 1 12 1 pt row
      * ∑ t : Fin (2 ^ 12 + 0), X row t * dataKeyColK (r0 * 4096 + c0) 1 12 1 pt t
    = X ⟨r0, hr0⟩ ⟨c0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ := by
  have hdiv : (r0 * 4096 + c0) / 2 ^ 12 = r0 := by
    rw [show (2 : ℕ) ^ 12 = 4096 by norm_num]; omega
  have hmod : (r0 * 4096 + c0) % 2 ^ 12 = c0 := by
    rw [show (2 : ℕ) ^ 12 = 4096 by norm_num]; omega
  have hrow : ∀ row : Fin R, dataRowK (r0 * 4096 + c0) 1 12 1 pt row = if row.val = r0 then 1 else 0 := by
    intro row
    unfold dataRowK
    rw [ite_eq_right (by norm_num), ite_eq_right (by norm_num), hdiv]
  have hcol : ∀ t : Fin (2 ^ 12 + 0), dataKeyColK (r0 * 4096 + c0) 1 12 1 pt t
      = if t.val = c0 + msbIndex 1 b then 1 else 0 := by
    intro t
    unfold dataKeyColK
    simp only [show ¬ ((1 : ℕ) ≥ 12) by norm_num, ↓reduceIte, hmod, show (2 : ℕ) ^ 1 = 2 by norm_num]
    by_cases hlt : c0 ≤ t.val ∧ t.val < c0 + 2
    · rw [ite_eq_left hlt]
      have hfn : (fun a : Fin 1 => pt a.val) = fun a : Fin 1 => (bit (b a) : shdP_K) := by
        funext a; fin_cases a; exact hpt
      rw [hfn, eqPoly_bit_bitsK 1 b (t.val - c0) (by omega)]
      by_cases heq : t.val = c0 + msbIndex 1 b
      · rw [ite_eq_left (by omega), ite_eq_left heq]
      · rw [ite_eq_right (by omega), ite_eq_right heq]
    · rw [ite_eq_right hlt]
      have hne : t.val ≠ c0 + msbIndex 1 b := by
        have := msbIndex_lt 1 b; omega
      rw [ite_eq_right hne]
  rw [Finset.sum_eq_single_of_mem (⟨r0, hr0⟩ : Fin R) (Finset.mem_univ _)]
  · rw [hrow ⟨r0, hr0⟩, ite_eq_left rfl, one_mul]
    rw [Finset.sum_eq_single_of_mem (⟨c0 + msbIndex 1 b, by have := msbIndex_lt 1 b; omega⟩ : Fin (2 ^ 12 + 0)) (Finset.mem_univ _)]
    · rw [hcol, ite_eq_left rfl, mul_one]
    · intro t _ hne
      rw [hcol, ite_eq_right (fun h => hne (Fin.ext h)), mul_zero]
  · intro row _ hne
    rw [hrow row, ite_eq_right (fun h => hne (Fin.ext h)), zero_mul]

/-- Helper: evaluate a single-row `H` plane (`hOff p = (2p*4096, (2p+1)*4096)`, `p < 8`, coefficients `1` and `fp2U`)
at Boolean point `b : Fin 12 → Bool`. -/
theorem outc_h_plane_at {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x) (rnd : OutcRand)
    (gamma alpha : Fp2) (p : Fin 8) (b : Fin 12 → Bool) (pt : ℕ → shdP_K)
    (hpt : ∀ a : Fin 12, pt a.val = (bit (b a) : shdP_K)) :
    let TH := shdP_outcTH Rp w rnd gamma alpha
    (∑ row : Fin 38,
        ((Fp2.one.toK shdP_U * dataRowK ((2 * p.val) * 4096) 12 12 12 pt row)
          + (Block.fp2U.toK shdP_U * dataRowK ((2 * p.val + 1) * 4096) 12 12 12 pt row))
        * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK ((2 * p.val) * 4096) 12 12 12 pt t)
    = shdP_outcHValK Rp w gamma alpha p ⟨msbIndex 12 b, msbIndex_lt 12 b⟩ := by
  intro TH
  have hcol_eq : ∀ t : Fin (2 ^ 12 + 0),
      dataKeyColK ((2 * p.val) * 4096) 12 12 12 pt t = dataKeyColK ((2 * p.val + 1) * 4096) 12 12 12 pt t := by
    intro t; rfl
  have hsplit : (∑ row : Fin 38,
        ((Fp2.one.toK shdP_U * dataRowK ((2 * p.val) * 4096) 12 12 12 pt row)
          + (Block.fp2U.toK shdP_U * dataRowK ((2 * p.val + 1) * 4096) 12 12 12 pt row))
        * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK ((2 * p.val) * 4096) 12 12 12 pt t)
      = (∑ row : Fin 38, dataRowK ((2 * p.val) * 4096) 12 12 12 pt row
          * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK ((2 * p.val) * 4096) 12 12 12 pt t)
        + shdP_U * (∑ row : Fin 38, dataRowK ((2 * p.val + 1) * 4096) 12 12 12 pt row
          * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK ((2 * p.val + 1) * 4096) 12 12 12 pt t) := by
    rw [Finset.mul_sum, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun row _ => ?_)
    simp_rw [← hcol_eq]
    rw [Fp2.toK_one, Block.toK_fp2U]
    ring
  rw [hsplit]
  have hp1 : 2 * p.val < 38 := by have := p.isLt; omega
  have hp2 : 2 * p.val + 1 < 38 := by have := p.isLt; omega
  have h1 := data_slice_single_row 38 12 (2 * p.val) hp1 (tabMat 38 12 TH.rows) b pt hpt
  have h2 := data_slice_single_row 38 12 (2 * p.val + 1) hp2 (tabMat 38 12 TH.rows) b pt hpt
  change (∑ row : Fin 38, dataRowK (2 * p.val * 2 ^ 12) 12 12 12 pt row * _)
    + shdP_U * (∑ row : Fin 38, dataRowK ((2 * p.val + 1) * 2 ^ 12) 12 12 12 pt row * _) = _
  rw [h1, h2]
  have hm1 : tabMat (K := shdP_K) 38 12 TH.rows ⟨2 * p.val, hp1⟩ ⟨msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
      = algebraMap GF shdP_K (ofK shdP_U shdP_hbij (shdP_outcHValK Rp w gamma alpha p ⟨msbIndex 12 b, msbIndex_lt 12 b⟩)).c0.toGF := by
    rw [tabMat_mkRows 38 12 256]
    unfold shdP_outcTHData
    dsimp only
    rw [dite_eq_left (by have := p.isLt; omega), ite_eq_left (by omega)]
    have hdiv : (⟨2 * p.val / 2, by have := p.isLt; omega⟩ : Fin 8) = p := Fin.ext (by omega)
    rw [hdiv]
  have hm2 : tabMat (K := shdP_K) 38 12 TH.rows ⟨2 * p.val + 1, hp2⟩ ⟨msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
      = algebraMap GF shdP_K (ofK shdP_U shdP_hbij (shdP_outcHValK Rp w gamma alpha p ⟨msbIndex 12 b, msbIndex_lt 12 b⟩)).c1.toGF := by
    rw [tabMat_mkRows 38 12 256]
    unfold shdP_outcTHData
    dsimp only
    rw [dite_eq_left (by have := p.isLt; omega), ite_eq_right (by omega)]
    have hdiv : (⟨(2 * p.val + 1) / 2, by have := p.isLt; omega⟩ : Fin 8) = p := Fin.ext (by omega)
    rw [hdiv]
  rw [hm1, hm2]
  exact toK_ofK shdP_U shdP_hbij _

/-- Helper: evaluate `H_U` (`ocH_U = 8`, rows `16, 17`) at Boolean point `b : Fin 12 → Bool`. -/
theorem outc_h_u_at (rnd : OutcRand) {x : shieldS0.Tok → ℕ} (w : OutcWitness Rp x)
    (gamma alpha : Fp2) (b : Fin 12 → Bool) (pt : ℕ → shdP_K)
    (hpt : ∀ a : Fin 12, pt a.val = (bit (b a) : shdP_K)) :
    let TH := shdP_outcTH Rp w rnd gamma alpha
    (∑ row : Fin 38,
        ((Fp2.one.toK shdP_U * dataRowK (16 * 4096) 12 12 12 pt row)
          + (Block.fp2U.toK shdP_U * dataRowK (17 * 4096) 12 12 12 pt row))
        * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK (16 * 4096) 12 12 12 pt t)
    = algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1
      + shdP_U * algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := by
  intro TH
  have hcol_eq : ∀ t : Fin (2 ^ 12 + 0),
      dataKeyColK (16 * 4096) 12 12 12 pt t = dataKeyColK (17 * 4096) 12 12 12 pt t := fun _ => rfl
  have hsplit : (∑ row : Fin 38,
        ((Fp2.one.toK shdP_U * dataRowK (16 * 4096) 12 12 12 pt row)
          + (Block.fp2U.toK shdP_U * dataRowK (17 * 4096) 12 12 12 pt row))
        * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK (16 * 4096) 12 12 12 pt t)
      = (∑ row : Fin 38, dataRowK (16 * 4096) 12 12 12 pt row
          * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK (16 * 4096) 12 12 12 pt t)
        + shdP_U * (∑ row : Fin 38, dataRowK (17 * 4096) 12 12 12 pt row
          * ∑ t : Fin (2 ^ 12 + 0), tabMat 38 12 TH.rows row t * dataKeyColK (17 * 4096) 12 12 12 pt t) := by
    rw [Finset.mul_sum, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun row _ => ?_)
    simp_rw [← hcol_eq]
    rw [Fp2.toK_one, Block.toK_fp2U]
    ring
  rw [hsplit]
  have h1 := data_slice_single_row 38 12 16 (by norm_num) (tabMat 38 12 TH.rows) b pt hpt
  have h2 := data_slice_single_row 38 12 17 (by norm_num) (tabMat 38 12 TH.rows) b pt hpt
  change (∑ row : Fin 38, dataRowK (16 * 2 ^ 12) 12 12 12 pt row * _)
    + shdP_U * (∑ row : Fin 38, dataRowK (17 * 2 ^ 12) 12 12 12 pt row * _) = _
  rw [h1, h2]
  have hm1 : tabMat (K := shdP_K) 38 12 TH.rows ⟨16, by norm_num⟩ ⟨msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
      = algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1 := by
    rw [tabMat_mkRows 38 12 256]
    have : shdP_outcTHData Rp w rnd gamma alpha ⟨16, by norm_num⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
        = Fp.ofGF (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).1 := rfl
    rw [this, Fp.toGF_ofGF]
  have hm2 : tabMat (K := shdP_K) 38 12 TH.rows ⟨17, by norm_num⟩ ⟨msbIndex 12 b, by have := msbIndex_lt 12 b; omega⟩
      = algebraMap GF shdP_K (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := by
    rw [tabMat_mkRows 38 12 256]
    have : shdP_outcTHData Rp w rnd gamma alpha ⟨17, by norm_num⟩ ⟨msbIndex 12 b, msbIndex_lt 12 b⟩
        = Fp.ofGF (shdP_outcHUVal rnd ⟨msbIndex 12 b, msbIndex_lt 12 b⟩).2 := rfl
    rw [this, Fp.toGF_ofGF]
  rw [hm1, hm2]

/-- Evaluate `TB_25` at `(fixedBits Rp.row.val 7 ++ rho)` (verdict row, channel `b : Fin 12 → Bool`). -/
theorem shdP_outcTB_verdictRow_at {y25 : shieldS0.Pos → ℤ} {TB : Table}
    (hTB : BndTableSpec y25 Rp.row TB) (b : Fin 12 → Bool)
    (pt : ℕ → shdP_K)
    (hptHi : ∀ a : Fin 7, pt a.val = (bit (msbBits 7 Rp.row.val a) : shdP_K))
    (hptLo : ∀ a : Fin 12, pt (7 + a.val) = (bit (b a) : shdP_K)) :
    ∑ row : Fin 38, dataRowK 0 19 14 19 pt row
      * ∑ t : Fin (2 ^ 14 + 0), tabMat 38 14 TB.rows row t * dataKeyColK 0 19 14 19 pt t
    = if hc : msbIndex 12 b < 3072 then
        algebraMap GF shdP_K (Fp.fromI64 (y25 (Rp.row, ⟨msbIndex 12 b, hc⟩))).toGF
      else 0 := by
  let cFull : Fin (5 + 14) → Bool := fun a =>
    if h7 : a.val < 7 then msbBits 7 Rp.row.val ⟨a.val, h7⟩
    else b ⟨a.val - 7, by have := a.isLt; omega⟩
  have hpt : ∀ a : Fin (5 + 14), pt a.val = (bit (cFull a) : shdP_K) := by
    intro a
    dsimp only [cFull]
    by_cases h7 : a.val < 7
    · rw [dite_eq_left h7]; exact hptHi ⟨a.val, h7⟩
    · rw [dite_eq_right h7]
      have hsub : 7 + (a.val - 7) = a.val := by omega
      have h := hptLo ⟨a.val - 7, by have := a.isLt; omega⟩
      rwa [hsub] at h
  have hmul := data_slice_multi_row 38 14 5 0 (by norm_num) (by norm_num) (by norm_num)
    (tabMat 38 14 TB.rows) cFull pt hpt
  dsimp only at hmul
  rw [Nat.zero_mul, Nat.zero_add] at hmul
  change (∑ row : Fin 38, dataRowK 0 (5 + 14) 14 (5 + 14) pt row * _) = _
  rw [hmul]
  -- Split the 19-bit index `r * 16384 + col = Rp.row * 4096 + msbIndex 12 b`!
  set cHi : Fin 5 → Bool := fun a => cFull ⟨a.val, by omega⟩
  set cLo : Fin 14 → Bool := fun a => cFull ⟨5 + a.val, by omega⟩
  have hflat : msbIndex 5 cHi * 16384 + msbIndex 14 cLo = Rp.row.val * 4096 + msbIndex 12 b := by
    have hsplit1 := msbIndex_split 5 14 cFull
    have hsplit2 := msbIndex_split 7 12 (fun a : Fin (7 + 12) => cFull ⟨a.val, by omega⟩)
    have h19 : msbIndex (5 + 14) cFull = msbIndex (7 + 12) (fun a : Fin (7 + 12) => cFull ⟨a.val, by omega⟩) := by
      unfold msbIndex
      refine Finset.sum_bij (fun (i : Fin (5 + 14)) _ => (⟨i.val, by omega⟩ : Fin (7 + 12)))
        (fun _ _ => Finset.mem_univ _)
        (fun a _ b _ h => Fin.ext (congrArg Fin.val h))
        (fun j _ => ⟨⟨j.val, by omega⟩, Finset.mem_univ _, Fin.ext rfl⟩)
        (fun i _ => rfl)
    have h7eq : msbIndex 7 (fun a : Fin 7 => cFull ⟨a.val, by omega⟩) = Rp.row.val := by
      have hf : (fun a : Fin 7 => cFull ⟨a.val, by omega⟩) = msbBits 7 Rp.row.val := by
        funext a; dsimp only [cFull]; rw [dite_eq_left a.isLt]
      rw [hf, msbIndex_msbBits 7 Rp.row.val (by have := Rp.row.isLt; exact lt_of_lt_of_eq this (by norm_num))]
    have h12eq : msbIndex 12 (fun a : Fin 12 => cFull ⟨7 + a.val, by omega⟩) = msbIndex 12 b := by
      have hf : (fun a : Fin 12 => cFull ⟨7 + a.val, by omega⟩) = b := by
        funext a; dsimp only [cFull]; rw [dite_eq_right (by omega)]
        congr 1; exact Fin.ext (by omega)
      rw [hf]
    rw [h19] at hsplit1
    have hpow14 : (2 : ℕ) ^ 14 = 16384 := by norm_num
    have hpow12 : (2 : ℕ) ^ 12 = 4096 := by norm_num
    rw [hpow14] at hsplit1
    rw [hpow12, h7eq, h12eq] at hsplit2
    omega
  have hrLt : msbIndex 5 cHi < 32 := msbIndex_lt 5 cHi
  have hcolLt : msbIndex 14 cLo < 16384 := msbIndex_lt 14 cLo
  have hbLt : msbIndex 12 b < 4096 := msbIndex_lt 12 b
  have hdiv : (msbIndex 5 cHi * 16384 + msbIndex 14 cLo) / 4096 = Rp.row.val := by
    rw [hflat]; omega
  have hmod : (msbIndex 5 cHi * 16384 + msbIndex 14 cLo) % 4096 = msbIndex 12 b := by
    rw [hflat]; omega
  unfold tabMat
  have hrow := hTB.row_eq ⟨msbIndex 5 cHi, hrLt⟩ ⟨msbIndex 14 cLo, hcolLt⟩ hdiv
  dsimp only at hrow ⊢
  rw [hrow, hmod]
  split_ifs with hc
  · rfl
  · simp [fp_zero_toGF]

/-- **Stage OUT-C `logupSumClaim` is `ClaimTrue` on `shdP_outcTH`**:
discharged by `BlockLookSum.claimSem_empty` + `outcMult_sum_fiber` + `shdP_outcHUVal_sum_re/im`! -/
theorem shdP_outc_logupSumClaim_true (v : ℕ) {x : shieldS0.Tok → ℕ}
    (w : OutcWitness Rp x) (rnd : OutcRand) (ch : List Fp2) :
    ClaimTrue shdP_U (2 ^ 12) 12 (shdP_outcTH Rp w rnd (ch.getD 0 Fp2.zero) (ch.getD 1 Fp2.zero)).rows
      (toZClaim (shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim) := by
  let gamma := ch.getD 0 Fp2.zero
  let alpha := ch.getD 1 Fp2.zero
  let TH := shdP_outcTH Rp w rnd gamma alpha
  let gU8K := (gamma.mulBase (Fp.new (UInt64.ofNat tagU8))).toK shdP_U
  let α := alpha.toK shdP_U
  rw [claimTrue_iff_claimSem shdP_U 38 12 TH.rows (shdP_outcTH_rows_len Rp w rnd gamma alpha)]
  have hcl : (shdVo tag Rp wDigest bOutRow v).lay.logupSumClaim
      = (outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14).logupSumClaim := rfl
  rw [hcl]
  set L := outcLay (rcVerdict (shdP_outcPub Rp wDigest) v) 14
  obtain ⟨hllo, hldo, hltab, _⟩ := shdP_outcPub_logs Rp wDigest
  have hlog : ∀ p, p < 9 → L.hLog.getD p 0 = 12 := by
    intro p hp
    have hllo' : (rcVerdict (shdP_outcPub Rp wDigest) v).llo = 12 := hllo
    have hldo' : (rcVerdict (shdP_outcPub Rp wDigest) v).ldo = 12 := hldo
    have hltab' : (rcVerdict (shdP_outcPub Rp wDigest) v).ltab = 12 := hltab
    have hlt' : (rcVerdict (shdP_outcPub Rp wDigest) v).lt = 12 := rfl
    have heq : L.hLog = List.replicate 9 12 := by
      simp only [L, outcLay, hllo', hldo', hltab', hlt', List.replicate]
    rw [heq, List.getD_eq_getElem?_getD, List.getElem?_replicate, ite_eq_left hp, Option.getD_some]
  let mkParts : ℕ → List Block.ZPart := fun p =>
    [⟨(L.hOff p).1, L.hLog.getD p 0, kI (L.hSign.getD p 0), []⟩,
     ⟨(L.hOff p).2, L.hLog.getD p 0, (kI (L.hSign.getD p 0)).mul Block.fp2U, []⟩]
  have hlsc : L.logupSumClaim = ⟨(List.range 9).flatMap mkParts, Fp2.zero⟩ := by
    unfold Lay.logupSumClaim
    have hlen : L.hLog.length = 9 := by
      simp only [L, outcLay, List.length_append, List.length_cons, List.length_replicate, List.length_nil]
    rw [hlen]
  rw [hlsc]
  have hparts_cons : (List.range 9).flatMap mkParts
      = ⟨(L.hOff 0).1, L.hLog.getD 0 0, kI (L.hSign.getD 0 0), []⟩
        :: ⟨(L.hOff 0).2, L.hLog.getD 0 0, (kI (L.hSign.getD 0 0)).mul Block.fp2U, []⟩
        :: (List.range' 1 8).flatMap mkParts := by
    have hr9 : List.range 9 = 0 :: List.range' 1 8 := by decide
    rw [hr9, List.flatMap_cons]; rfl
  have he : Block.Join.W16.Look.EmptyParts 12 ⟨(List.range 9).flatMap mkParts, Fp2.zero⟩ := by
    intro q hq
    obtain ⟨p, hpMem, hqp⟩ := List.mem_flatMap.mp hq
    have hpLt : p < 9 := List.mem_range.mp hpMem
    simp only [mkParts, List.mem_cons, List.not_mem_nil, or_false] at hqp
    rcases hqp with rfl | rfl
    · exact ⟨rfl, by rw [hlog p hpLt], kI_canon _⟩
    · exact ⟨rfl, by rw [hlog p hpLt], Fp2.canon_mul _ _⟩
  change Fp2.zero.toK shdP_U = Link.claimSem shdP_U 38 12 0 (tabMat 38 12 TH.rows) ⟨(List.range 9).flatMap mkParts, Fp2.zero⟩
  rw [Fp2.toK_zero, Block.Join.W16.Look.claimSem_empty shdP_U 38 12 0 (tabMat 38 12 TH.rows)
    ⟨(List.range 9).flatMap mkParts, Fp2.zero⟩ _ _ hparts_cons he]
  dsimp only
  have hsign : ∀ p, p < 9 → L.hSign.getD p 0 = if p = 7 then -1 else 1 := by
    intro p hp
    have heq : L.hSign = [1, 1, 1, 1, 1, 1, 1, -1, 1] := rfl
    rw [heq]
    interval_cases p <;> rfl
  have hk1 : (kI 1).toK shdP_U = 1 := kI_one_toK shdP_U
  have hkm1 : (kI (-1)).toK shdP_U = -1 := kI_negOne_toK shdP_U
  have hk1U : ((kI 1).mul Block.fp2U).toK shdP_U = shdP_U := by
    rw [Fp2.toK_mul shdP_U shdP_hU, hk1, Block.toK_fp2U, one_mul]
  have hkm1U : ((kI (-1)).mul Block.fp2U).toK shdP_U = -shdP_U := by
    rw [Fp2.toK_mul shdP_U shdP_hU, hkm1, Block.toK_fp2U]; ring
  have hrowS : ∀ i : Fin 38, Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) i
      = ∑ col : Fin 4096, algebraMap GF shdP_K (shdP_outcTHData Rp w rnd gamma alpha i col).toGF := by
    intro i
    unfold Block.Join.W16.Look.rowS
    refine Finset.sum_congr rfl (fun col _ => ?_)
    rw [ite_eq_left col.isLt, mul_one]
    exact tabMat_mkRows 38 12 256 _ _ i col
  have hin1 : ∀ (r0 : ℕ) (hr0 : r0 < 38) (f : Fin 38 → shdP_K),
      ∑ i : Fin 38, Block.Join.W16.Look.inRows (K := shdP_K) 12 (r0 * 4096) 12 i * f i = f ⟨r0, hr0⟩ := by
    intro r0 hr0 f
    rw [Finset.sum_eq_single_of_mem ⟨r0, hr0⟩ (Finset.mem_univ _)]
    · unfold Block.Join.W16.Look.inRows
      have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by norm_num
      rw [hdiv, Nat.sub_self, pow_zero, ite_eq_left (by omega), one_mul]
    · intro i _ hne
      unfold Block.Join.W16.Look.inRows
      have hdiv : r0 * 4096 / 2 ^ 12 = r0 := by norm_num
      rw [hdiv, Nat.sub_self, pow_zero, ite_eq_right (by intro h; exact hne (Fin.ext (by omega))), zero_mul]
  -- Rewrite the `flatMap` sum as a sum over `p : Fin 9`
  rw [List.map_flatMap, List.sum_flatten, List.map_map, list_range_sum, Finset.sum_range]
  -- Evaluate each plane pair `p : Fin 8`
  have hpair : ∀ p : Fin 8,
      Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val, by have := p.isLt; omega⟩
        + shdP_U * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val + 1, by have := p.isLt; omega⟩
      = ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha p col := by
    intro p
    rw [hrowS, hrowS, Finset.mul_sum, ← Finset.sum_add_distrib]
    refine Finset.sum_congr rfl (fun col _ => ?_)
    have hre : shdP_outcTHData Rp w rnd gamma alpha ⟨2 * p.val, by have := p.isLt; omega⟩ col
        = (ofK shdP_U shdP_hbij (shdP_outcHValK Rp w gamma alpha p col)).c0 := by
      unfold shdP_outcTHData; dsimp only
      rw [dite_eq_left (by have := p.isLt; omega), ite_eq_left (by omega)]
      have hdiv : (⟨2 * p.val / 2, by have := p.isLt; omega⟩ : Fin 8) = p := Fin.ext (by omega)
      rw [hdiv]
    have him : shdP_outcTHData Rp w rnd gamma alpha ⟨2 * p.val + 1, by have := p.isLt; omega⟩ col
        = (ofK shdP_U shdP_hbij (shdP_outcHValK Rp w gamma alpha p col)).c1 := by
      unfold shdP_outcTHData; dsimp only
      rw [dite_eq_left (by have := p.isLt; omega), ite_eq_right (by omega)]
      have hdiv : (⟨(2 * p.val + 1) / 2, by have := p.isLt; omega⟩ : Fin 8) = p := Fin.ext (by omega)
      rw [hdiv]
    rw [hre, him]
    exact toK_ofK shdP_U shdP_hbij _
  have hU0 : Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨16, by norm_num⟩
      + shdP_U * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨17, by norm_num⟩ = 0 := by
    rw [hrowS, hrowS]
    have h16 : (∑ col : Fin 4096, algebraMap GF shdP_K (shdP_outcTHData Rp w rnd gamma alpha ⟨16, by norm_num⟩ col).toGF) = 0 := by
      have heq : ∀ col : Fin 4096,
          algebraMap GF shdP_K (shdP_outcTHData Rp w rnd gamma alpha ⟨16, by norm_num⟩ col).toGF
            = algebraMap GF shdP_K (shdP_outcHUVal rnd col).1 := fun col => by
        have : shdP_outcTHData Rp w rnd gamma alpha ⟨16, by norm_num⟩ col = Fp.ofGF (shdP_outcHUVal rnd col).1 := rfl
        rw [this, Fp.toGF_ofGF]
      simp_rw [heq]; rw [← map_sum, shdP_outcHUVal_sum_re, map_zero]
    have h17 : (∑ col : Fin 4096, algebraMap GF shdP_K (shdP_outcTHData Rp w rnd gamma alpha ⟨17, by norm_num⟩ col).toGF) = 0 := by
      have heq : ∀ col : Fin 4096,
          algebraMap GF shdP_K (shdP_outcTHData Rp w rnd gamma alpha ⟨17, by norm_num⟩ col).toGF
            = algebraMap GF shdP_K (shdP_outcHUVal rnd col).2 := fun col => by
        have : shdP_outcTHData Rp w rnd gamma alpha ⟨17, by norm_num⟩ col = Fp.ofGF (shdP_outcHUVal rnd col).2 := rfl
        rw [this, Fp.toGF_ofGF]
      simp_rw [heq]; rw [← map_sum, shdP_outcHUVal_sum_im, map_zero]
    rw [h16, h17, mul_zero, add_zero]
  -- Simplify each summand `p : Fin 9`
  have hterm : ∀ p : Fin 9,
      ((List.map (fun q : Block.ZPart =>
          q.coef.toK shdP_U * ∑ i : Fin 38,
            Block.Join.W16.Look.inRows (K := shdP_K) 12 q.offset q.logSize i
              * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) i)
        (mkParts p.val)).sum)
      = if hp : p.val < 8 then
          (if p.val = 7 then (-1 : shdP_K) else 1) * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨p.val, hp⟩ col
        else 0 := by
    intro p
    simp only [mkParts, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero,
      shdP_outcLay_hOff Rp wDigest v p.val p.isLt, hlog p.val p.isLt, hsign p.val p.isLt]
    rw [hin1 (2 * p.val) (by have := p.isLt; omega), hin1 (2 * p.val + 1) (by have := p.isLt; omega)]
    by_cases hp : p.val < 8
    · rw [dite_eq_left hp]
      by_cases h7 : p.val = 7
      · rw [ite_eq_left h7, ite_eq_left h7, hkm1, hkm1U]
        have hp' := hpair ⟨p.val, hp⟩
        calc -1 * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val, by omega⟩
              + -shdP_U * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val + 1, by omega⟩
            = -1 * (Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val, by omega⟩
              + shdP_U * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) ⟨2 * p.val + 1, by omega⟩) := by ring
          _ = -1 * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨p.val, hp⟩ col := by rw [hp']
      · rw [ite_eq_right h7, ite_eq_right h7, hk1, hk1U, one_mul, one_mul]
        exact hpair ⟨p.val, hp⟩
    · have hp8 : p.val = 8 := by have := p.isLt; omega
      rw [dite_eq_right hp, ite_eq_right (by omega), hk1, hk1U, one_mul]
      have h16 : (⟨2 * p.val, by have := p.isLt; omega⟩ : Fin 38) = ⟨16, by norm_num⟩ := Fin.ext (by omega)
      have h17 : (⟨2 * p.val + 1, by have := p.isLt; omega⟩ : Fin 38) = ⟨17, by norm_num⟩ := Fin.ext (by omega)
      rw [h16, h17]
      exact hU0
  simp only [Function.comp_apply]
  have hsum9 : (∑ p : Fin 9,
      ((List.map (fun q : Block.ZPart =>
          q.coef.toK shdP_U * ∑ i : Fin 38,
            Block.Join.W16.Look.inRows (K := shdP_K) 12 q.offset q.logSize i
              * Block.Join.W16.Look.rowS 12 38 0 (tabMat 38 12 TH.rows) i)
        (mkParts p.val)).sum))
      = (∑ col : Fin 4096, (α - ((loLook w col).val + gU8K))⁻¹)
        + (∑ l : Fin 12, ∑ col : Fin 4096, (α - ((doLook w l col).val + gU8K))⁻¹)
        - (∑ z : Fin 256, (outcMult w z : shdP_K) * (α - ((z.val : shdP_K) + gU8K))⁻¹) := by
    simp_rw [hterm]
    rw [Fin.sum_univ_castSucc]
    have hlast : (if hp : (Fin.last 8).val < 8 then
        (if (Fin.last 8).val = 7 then (-1 : shdP_K) else 1)
          * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨(Fin.last 8).val, hp⟩ col
        else 0) = 0 := dite_eq_right (by simp)
    rw [hlast, add_zero]
    rw [Fin.sum_univ_castSucc]
    have h7 : (if hp : (Fin.castSucc (Fin.last 7)).val < 8 then
        (if (Fin.castSucc (Fin.last 7)).val = 7 then (-1 : shdP_K) else 1)
          * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨(Fin.castSucc (Fin.last 7)).val, hp⟩ col
        else 0)
        = - ∑ z : Fin 256, (outcMult w z : shdP_K) * (α - ((z.val : shdP_K) + gU8K))⁻¹ := by
      rw [dite_eq_left (by simp), ite_eq_left (by simp), neg_one_mul]
      congr 1
      have hval7 : ∀ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨7, by norm_num⟩ col
          = if hc : col.val < 256 then (outcMult w ⟨col.val, hc⟩ : shdP_K) * (α - ((col.val : shdP_K) + gU8K))⁻¹ else 0 := fun col => rfl
      simp_rw [hval7]
      rw [← Finset.sum_filter_add_sum_filter_not Finset.univ (fun col : Fin 4096 => col.val < 256)]
      have hzero : ∑ col ∈ Finset.univ.filter (fun col : Fin 4096 => ¬ col.val < 256),
          (if hc : col.val < 256 then (outcMult w ⟨col.val, hc⟩ : shdP_K) * (α - ((col.val : shdP_K) + gU8K))⁻¹ else 0) = 0 :=
        Finset.sum_eq_zero (fun col hcol => dite_eq_right (Finset.mem_filter.mp hcol).2)
      rw [hzero, add_zero]
      refine Finset.sum_bij (fun (col : Fin 4096) (hcol : col ∈ Finset.univ.filter _) =>
          (⟨col.val, (Finset.mem_filter.mp hcol).2⟩ : Fin 256))
        (fun _ _ => Finset.mem_univ _)
        (fun a _ b _ h => Fin.ext (congrArg Fin.val h))
        (fun z _ => ⟨⟨z.val, by have := z.isLt; omega⟩,
          Finset.mem_filter.mpr ⟨Finset.mem_univ _, z.isLt⟩, Fin.ext rfl⟩)
        (fun col hcol => dite_eq_left (Finset.mem_filter.mp hcol).2)
    rw [h7, Fin.sum_univ_succ]
    have h0 : (if hp : (Fin.castSucc (Fin.castSucc (0 : Fin 7))).val < 8 then
        (if (Fin.castSucc (Fin.castSucc (0 : Fin 7))).val = 7 then (-1 : shdP_K) else 1)
          * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨(Fin.castSucc (Fin.castSucc (0 : Fin 7))).val, hp⟩ col
        else 0)
        = ∑ col : Fin 4096, (α - ((loLook w col).val + gU8K))⁻¹ := by
      rw [dite_eq_left (by simp), ite_eq_right (by simp), one_mul]; rfl
    rw [h0]
    have hD : (∑ k : Fin 6,
        if hp : (Fin.castSucc (Fin.castSucc k.succ)).val < 8 then
          (if (Fin.castSucc (Fin.castSucc k.succ)).val = 7 then (-1 : shdP_K) else 1)
            * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨(Fin.castSucc (Fin.castSucc k.succ)).val, hp⟩ col
        else 0)
        = ∑ l : Fin 12, ∑ col : Fin 4096, (α - ((doLook w l col).val + gU8K))⁻¹ := by
      have hpair6 : ∀ k : Fin 6,
          (if hp : (Fin.castSucc (Fin.castSucc k.succ)).val < 8 then
            (if (Fin.castSucc (Fin.castSucc k.succ)).val = 7 then (-1 : shdP_K) else 1)
              * ∑ col : Fin 4096, shdP_outcHValK Rp w gamma alpha ⟨(Fin.castSucc (Fin.castSucc k.succ)).val, hp⟩ col
          else 0)
          = (∑ col : Fin 4096, (α - ((doLook w ⟨2 * k.val, by omega⟩ col).val + gU8K))⁻¹)
            + (∑ col : Fin 4096, (α - ((doLook w ⟨2 * k.val + 1, by omega⟩ col).val + gU8K))⁻¹) := by
        intro k
        have hk := k.isLt
        rw [dite_eq_left (by simp; omega), ite_eq_right (by simp; omega), one_mul, ← Finset.sum_add_distrib]
        refine Finset.sum_congr rfl (fun col _ => ?_)
        unfold shdP_outcHValK
        simp only [Fin.val_castSucc, Fin.val_succ]
        rw [ite_eq_right (by omega), dite_eq_left (by omega)]
        have hsub : k.val + 1 - 1 = k.val := by omega
        simp only [hsub]
      simp_rw [hpair6]
      -- Expand both sides explicitly over `Fin 6` and `Fin 12` (12 tiny terms)
      simp only [Fin.sum_univ_succ, Fin.sum_univ_zero, Fin.val_zero, Fin.val_succ, add_zero]
      ring
    rw [hD]
    ring
  rw [hsum9]
  have hfib := outcMult_sum_fiber w (fun z : Fin 256 => (α - ((z.val : shdP_K) + gU8K))⁻¹)
  rw [hfib, sub_self]

end StageOutDataEval

end ZK60.HonestShield
