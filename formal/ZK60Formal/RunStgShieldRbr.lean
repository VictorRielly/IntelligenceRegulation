/-
D63 lane L63 (2026-11-16), part 5: **the round condition of a define draw whose `define` refuses a zero batching
challenge** (finding L63-4; step 1 of the plan for the stage degrees).

The stages' `define`s refuse a zero batching challenge (`nonzeroE` on `μ`, `ζ`), and the real define polynomial
`stgΦR` is `0` there. So `stgΦR` is a polynomial of individual degree `d` only OFF the zero set of those coordinates
(`OffZero`), and L57's `stgDefSqV_rbr` (which asks `IndDegLE` everywhere) does not apply. This file proves the round
condition with one more escape per round (`e = d + 1`: the polynomial's roots and the refusal point `0`).

* `OffZero`: `Φ` equals `P` wherever the coordinates `Z` are nonzero, and `0` where one of them is zero;
* **`szSt_escape_offZero`**: Schwartz–Zippel round by round for such a `Φ`, `d + 1` escapes;
* **`offZero_poly_zero`**: a polynomial of individual degree `d` vanishing wherever the coordinates `Z` are nonzero
  vanishes everywhere, when `d + 1 < |K|`;
* **`stgDefSqV_rbrZ`**: a stage define draw over the view (`stgDefSqV`) is round-by-round sound at `e = d + 1`;
* `ssh_rbrI`, `ssh_rbrO`: the same at the real `sshΦI`, `sshΦO`, with the non-refusing branch's degree a hypothesis;
* **`ssh_inc_count`**, **`ssh_outc_count`**: `hD`'s per-entry define conditions (`e ≤ 80`, `n·e ≤ 80·451`) at the
  code's draw counts (`incDraws`, `outcDraws`) with `e = d + 1`, IN-C at `d = 1`, OUT-C at every `d ≤ 11`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldInst

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Circuit (gP GF)

section OffZero

variable {K : Type} [Field K]

/-- **`Φ` is `P` off the zero set of the coordinates `Z`, and `0` on it.** -/
def OffZero {n : ℕ} (Z : Finset (Fin n)) (Φ P : (Fin n → K) → K) : Prop :=
  ∀ y, ((∀ i ∈ Z, y i ≠ 0) → Φ y = P y) ∧ ((∃ i ∈ Z, y i = 0) → Φ y = 0)

variable [Fintype K] [DecidableEq K]

/-- **Schwartz–Zippel round by round, off a zero set**: from a doomed reading, at most `d + 1` values of the next
challenge keep `Φ` vanishing on every extension (the next coordinate's polynomial's roots, and `0`). -/
theorem szSt_escape_offZero {M : Type} {n d : ℕ} (Z : Finset (Fin n)) (Φ P : (Fin n → K) → K) (hP : IndDegLE d P)
    (hΦ : OffZero Z Φ P) (τ : List (M × K)) (m : M) (hτ : τ.length < n) (hns : ¬ szSt Φ τ) :
    EscapesWithin (fun c => szSt Φ (τ ++ [(m, c)])) (d + 1) := by
  classical
  have hex : ∃ y0 : Fin n → K, (∀ (i : Fin n) (h : i.val < τ.length), y0 i = (τ[i.val]'h).2) ∧ Φ y0 ≠ 0 := by
    by_contra hc
    apply hns
    intro y hy
    by_contra hne
    exact hc ⟨y, hy, hne⟩
  obtain ⟨y0, hy0, hne⟩ := hex
  have hZ0 : ∀ i ∈ Z, y0 i ≠ 0 := by
    intro i hi h0
    exact hne ((hΦ y0).2 ⟨i, hi, h0⟩)
  have hPy0 : P y0 ≠ 0 := by rw [← (hΦ y0).1 hZ0]; exact hne
  obtain ⟨p, hpd, hp⟩ := hP ⟨τ.length, hτ⟩ y0
  have hp0 : p ≠ 0 := by
    intro h0
    apply hPy0
    have h1 := hp (y0 ⟨τ.length, hτ⟩)
    rw [Function.update_eq_self] at h1
    rw [h1, h0, Polynomial.eval_zero]
  refine ⟨insert 0 p.roots.toFinset, (Finset.card_insert_le _ _).trans
    (Nat.succ_le_succ ((Multiset.toFinset_card_le _).trans ((Polynomial.card_roots' p).trans hpd))), ?_⟩
  intro c hc
  by_contra hcB
  rw [Finset.mem_insert, not_or, Multiset.mem_toFinset, Polynomial.mem_roots hp0, Polynomial.IsRoot.def] at hcB
  obtain ⟨hc0, hpc⟩ := hcB
  apply hpc
  rw [← hp c]
  have hZ1 : ∀ i ∈ Z, Function.update y0 ⟨τ.length, hτ⟩ c i ≠ 0 := by
    intro i hi
    by_cases hii : i = ⟨τ.length, hτ⟩
    · subst hii
      rw [Function.update_self]
      exact hc0
    · rw [Function.update_of_ne hii]
      exact hZ0 i hi
  rw [← (hΦ _).1 hZ1]
  apply hc
  intro i hi
  rw [List.length_append, List.length_singleton] at hi
  by_cases hlt : i.val < τ.length
  · have hne' : i ≠ ⟨τ.length, hτ⟩ := fun h => by
      rw [h] at hlt
      exact lt_irrefl _ hlt
    rw [Function.update_of_ne hne', hy0 i hlt, List.getElem_append_left hlt]
  · have heq : i = ⟨τ.length, hτ⟩ := Fin.ext (by simp only; omega)
    subst heq
    rw [Function.update_self, List.getElem_append_right (by simp)]
    simp

/-- **A polynomial vanishing wherever the coordinates `Z` are nonzero vanishes everywhere** (individual degree `d`,
`d + 1 < |K|`): along a coordinate of `Z` it is a polynomial of degree `≤ d` with the `|K| − 1 > d` nonzero points
as roots. -/
theorem offZero_poly_zero {n d : ℕ} (Z : Finset (Fin n)) (P : (Fin n → K) → K) (hP : IndDegLE d P)
    (hK : d + 1 < Fintype.card K) (h : ∀ y, (∀ i ∈ Z, y i ≠ 0) → P y = 0) : ∀ y, P y = 0 := by
  classical
  have key : ∀ k (y : Fin n → K), (Z.filter (fun i => y i = 0)).card ≤ k → P y = 0 := by
    intro k
    induction k with
    | zero =>
      intro y hy
      refine h y (fun i hi h0 => ?_)
      have hmem : i ∈ Z.filter (fun i => y i = 0) := Finset.mem_filter.mpr ⟨hi, h0⟩
      have := Finset.card_pos.mpr ⟨i, hmem⟩
      omega
    | succ k ih =>
      intro y hy
      by_cases hk : (Z.filter (fun i => y i = 0)).card ≤ k
      · exact ih y hk
      · obtain ⟨i, hi⟩ : (Z.filter (fun i => y i = 0)).Nonempty := Finset.card_pos.mp (by omega)
        obtain ⟨p, hpd, hp⟩ := hP i y
        have hroot : ∀ t : K, t ≠ 0 → p.eval t = 0 := by
          intro t ht
          rw [← hp t]
          apply ih
          have hsub : Z.filter (fun j => Function.update y i t j = 0) ⊆ (Z.filter (fun j => y j = 0)).erase i := by
            intro j hj
            rw [Finset.mem_filter] at hj
            by_cases hji : j = i
            · subst hji
              rw [Function.update_self] at hj
              exact absurd hj.2 ht
            · rw [Function.update_of_ne hji] at hj
              exact Finset.mem_erase.mpr ⟨hji, Finset.mem_filter.mpr hj⟩
          have := Finset.card_le_card hsub
          rw [Finset.card_erase_of_mem hi] at this
          omega
        have hp0 : p = 0 := by
          by_contra hne
          have hsub : Finset.univ.erase (0 : K) ⊆ p.roots.toFinset := by
            intro t ht
            rw [Multiset.mem_toFinset, Polynomial.mem_roots hne, Polynomial.IsRoot.def]
            exact hroot t (Finset.ne_of_mem_erase ht)
          have h1 := Finset.card_le_card hsub
          rw [Finset.card_erase_of_mem (Finset.mem_univ _), Finset.card_univ] at h1
          have h2 := (Multiset.toFinset_card_le p.roots).trans ((Polynomial.card_roots' p).trans hpd)
          omega
        have := hp (y i)
        rw [Function.update_eq_self] at this
        rw [this, hp0, Polynomial.eval_zero]
  exact fun y => key _ y le_rfl

end OffZero

/-! ## The stage define draws -/

section Rbr

variable {K : Type} [Field K] [Fintype K] [DecidableEq K] [Algebra GF K] {L : ℕ}

omit [Algebra GF K] in
/-- **A STAGE DEFINE DRAW OVER THE VIEW IS ROUND-BY-ROUND SOUND AT `e = d + 1`** when its polynomial is, at every view
and history, a polynomial of individual degree `d` off the zero set of the coordinates `Z` and `0` on it (the form of
`stgΦR`, whose `define` refuses a zero batching challenge). -/
theorem stgDefSqV_rbrZ (P0 : Block.BlockParams) (m hdrLen : ℕ) (absOf : QB L → Option (List UInt8))
    (Φ : StgVw L → (k : ℕ) → List Fp2 × List (List Fp2) → (Fin (P0.draws k) → K) → K)
    (dg : ℕ → ℕ) (k d : ℕ) (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v h, ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp ∧ OffZero Z (Φ v k h) Pp) :
    (stgDefSqV P0 m hdrLen absOf Φ dg k).Rbr := by
  intro Lg hdr τ mg hτ hns
  simp only [stgDefSqV] at hns ⊢
  split at hns
  · obtain ⟨Pp, hP, ho⟩ := hoff _ _
    rw [hdg]
    exact szSt_escape_offZero Z _ Pp hP ho τ mg hτ hns
  · exact absurd trivial hns

variable (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U)) (tag : MTag) (h64 : 64 ≤ L)

/-- **The round condition at the real `ΦI`** (stage IN-C), the non-refusing branch's degree `d` a hypothesis. -/
theorem ssh_rbrI (P0 : Block.BlockParams) (Vi : StageV.IncV) (n0 hdrLen m lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8)) (dg : ℕ → ℕ) (k d : ℕ)
    (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp
      ∧ OffZero Z (sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO v k hh) Pp) :
    (stgDefSqV P0 m hdrLen absOf (sshΦI U hbij tag h64 P0 Vi n0 hdrLen m lc h Q e rA rH csIO) dg k).Rbr :=
  stgDefSqV_rbrZ P0 m hdrLen absOf _ dg k d Z hdg hoff

/-- **The round condition at the real `ΦO`** (stage OUT-C). -/
theorem ssh_rbrO (P0 : Block.BlockParams) (F : ℕ → StageV.OutcV) (n0 hdrLen lc h Q e rA rH : ℕ)
    (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (absOf : QB L → Option (List UInt8)) (dg : ℕ → ℕ) (k d : ℕ)
    (Z : Finset (Fin (P0.draws k))) (hdg : dg k = d + 1)
    (hoff : ∀ v hh, ∃ Pp : (Fin (P0.draws k) → K) → K, IndDegLE d Pp
      ∧ OffZero Z (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO v k hh) Pp) :
    (stgDefSqV P0 2 hdrLen absOf (sshΦO U hbij tag h64 P0 F n0 hdrLen lc h Q e rA rH csIO) dg k).Rbr :=
  stgDefSqV_rbrZ P0 2 hdrLen absOf _ dg k d Z hdg hoff

end Rbr

/-! ## The count: `hD`'s per-entry define conditions at the code's draw counts -/

section Count

open ZK60.Exec.StageV

/-- **Stage IN-C, `e = 1 + 1`**: every define draw meets `e ≤ 80` and `n·e ≤ 80·451` (the R13 gate's define form,
`eleven_bud_r13`), at the code's draw counts (`incDraws`: `clog2 words`, `ti_log + 5`, `voc_log + 3`), whenever the
logs fit `64` bits. -/
theorem ssh_inc_count (I : IncPub) (h0 : clog2 I.inEpWords ≤ 64) (h1 : I.tiLog ≤ 64) (h2 : I.vocLog ≤ 64) :
    ∀ k, 1 + 1 ≤ 80 ∧ incDraws I k * (1 + 1) ≤ 80 * 451 := by
  intro k
  rcases k with _ | _ | _ | k <;> simp only [incDraws] <;> omega

/-- **Stage OUT-C, `e = d + 1` for every `d ≤ 11`** (DZC's `11`, L57-3, the largest): `e ≤ 80` and `n·e ≤ 80·451` at the
code's draw counts (`outcDraws`: `d_bits`, `to_log + 6`, `lo_log + 3`, `do_log + 11`, `tab_log + 3`). -/
theorem ssh_outc_count (O : OutcPub) (h0 : O.dBits ≤ 64) (h1 : O.llo ≤ 64) (h2 : O.ldo ≤ 64) (h3 : O.ltab ≤ 64)
    (d : ℕ) (hd : d ≤ 11) : ∀ k, d + 1 ≤ 80 ∧ outcDraws O k * (d + 1) ≤ 80 * 451 := by
  intro k
  have hto : OutcPub.toLog = 1 := rfl
  refine ⟨by omega, ?_⟩
  have hn : outcDraws O k ≤ 75 := by
    rcases k with _ | _ | _ | _ | _ | _ | _ | k <;> simp only [outcDraws, hto] <;> omega
  calc outcDraws O k * (d + 1) ≤ 75 * 12 := Nat.mul_le_mul hn (by omega)
    _ ≤ 80 * 451 := by norm_num

/-- **At the app's profile** (R13 Shieldstral T128; `ti_log = 12`, `voc_log = 17` CHECKED by L57, `do_log = 12` at
`d_pad = 4096`): INC-01 `17·2 = 34`, INC-02 `20·2 = 40`, OUT-C DZC `23·12 = 276`, each `≤ 80·451 = 36,080`. -/
theorem ssh_profile_count : 17 * 2 ≤ 80 * 451 ∧ 20 * 2 ≤ 80 * 451 ∧ 23 * 12 ≤ 80 * 451 ∧ 80 * 451 = 36080 := by
  norm_num

end Count

end ZK60.ProtocolClassify
