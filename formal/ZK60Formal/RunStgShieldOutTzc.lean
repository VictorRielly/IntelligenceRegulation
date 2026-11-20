/-
D63 lane L63 (2026-11-20), L63 leg 15, part 96: **OUTC-02 TZC's clauses and its hosted sum of squares in the base
field** (item 3 of HANDOFF_20261119_3.md section 6, `OutCFacts`' four TZC conjuncts, `htzc` of `shd_outC_of_parts`).

TZC hosts SS (`hosted = [(1, ν)]`, `outcDefTZC_ok`): its define polynomial at a draw is its table side's cube sum minus
`ν` times SS's cube sum (`stgΦB_host_eval`). At the Boolean `eq` point `(z0, 0)` (`z0 = To`'s entry `0`) the table
side is `μ0·A + μ1·B + μ2·C + μ3·pad + ν·Hs` with `A, B, C` the three clauses at `z0`, the pad `(1 − u0)·(d + ζ·dsq)`
and `Hs` the host term's cube sum, all free of the draws; it vanishes for all nonzero `μ0..μ3, ν` (and `ζ = 1`), hence
`A = B = C = 0` and `Hs = Css` (`tzc_combo5`).

* `outcTzcRest`, `tzcR`, `tzc_combo5`, **`outc_tzc_combo`** (the clauses and the hosted equality in `K`);
* `outc_identA1`: a one-bit `A_out` table at `(z, 0)` is the plane at `z`;
* **`stgPlB_slice1`**: a one-bit slice of a twelve-bit `A_out` plane at the row-aligned offset `off + 2s` reads the
  plane's entry `2s + z` (`planeZ_one`, `ogStage.lc = 12`);
* `outc_tzc_vals` (TZC's tables at `(z, 0)`), `outc_tzc_hs` (the host term's cube sum is its value at `z0`),
  `outc_ss_cube` (SS's cube sum on the twelve-bit cube), `outc_ss_live` (the same at the live channels);
* **`outc_tzc`**: `Dsq − D² = 0`, `D − l3(dl) = 0`, `2D − l3(a1) − l3(a2) = 0` and `Dsq + l3(a1) − ceps = Σ_i x_i²` in
  `GF`, with `D`, `Dsq` the `A_out` planes at `To`'s entry `0`, the isqrt limbs the limb plane at `Lo`'s entries
  `2·(3k + j)` and `x_i` the plane `X` at `msbBits 12 i`; `ceps` in `[1, 2^40]` (`OutCPublic.Valid`).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldOutLay
import ZK60Formal.BlockLookEntry

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.StageX
open ZK60.Exec.StageV ZK60.Exec.StageCheck
open ZK60.Circuit (gP GF)
open ZK60.Out (OutCPublic)

/-- OUTC-02 TZC's tables after its `eq` table (`outcDefTZC_ok`): `u0`, `A D`, `A Dsq`, the nine limb slices. -/
def outcTzcRest (O : OutcPub) (G : OutcGeo) : List Block.Tab :=
  [.pub (supp 1 (2 ^ OutcPub.toLog)),
   .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_D, Fp2.one)], (outcLay O G.bLogN).aLog.getD ocC_D 0,
     rhoC 0 ((outcLay O G.bLogN).aLog.getD ocC_D 0), (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 2 + 0),
     0⟩,
   .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_DSQ, Fp2.one)], (outcLay O G.bLogN).aLog.getD ocC_DSQ 0,
     rhoC 0 ((outcLay O G.bLogN).aLog.getD ocC_DSQ 0),
     (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 2 + 1), 0⟩]
  ++ ((List.range (3 * OutcPub.limbsIsqrt)).zipIdx 2).map (fun p =>
    Block.Tab.priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_LIMB + 2 * p.1, Fp2.one)], OutcPub.toLog,
      rhoC 0 OutcPub.toLog, (outcLay O G.bLogN).aMaskBase + 2 * ((outcLay O G.bLogN).prefixA 2 + p.2), 0⟩)

theorem outcTzcRest_length (O : OutcPub) (G : OutcGeo) : (outcTzcRest O G).length = 12 := by
  simp [outcTzcRest, OutcPub.limbsIsqrt]

theorem outcTzcRest_D (O : OutcPub) (G : OutcGeo) : ∃ mr, (outcTzcRest O G).getD 1 (.pub [])
    = .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_D, Fp2.one)], OutcPub.toLog, rhoC 0 OutcPub.toLog, mr, 0⟩ :=
  ⟨_, rfl⟩

theorem outcTzcRest_Dsq (O : OutcPub) (G : OutcGeo) : ∃ mr, (outcTzcRest O G).getD 2 (.pub [])
    = .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_DSQ, Fp2.one)], OutcPub.toLog, rhoC 0 OutcPub.toLog, mr, 0⟩ :=
  ⟨_, rfl⟩

theorem outcTzcRest_sl (O : OutcPub) (G : OutcGeo) (p : ℕ) (hp : p < 9) : ∃ mr, (outcTzcRest O G).getD (3 + p) (.pub [])
    = .priv ⟨.a, [((outcLay O G.bLogN).aOff ocC_LIMB + 2 * p, Fp2.one)], OutcPub.toLog, rhoC 0 OutcPub.toLog, mr, 0⟩ := by
  interval_cases p <;> exact ⟨_, rfl⟩

theorem msbBits_toLog_zero : msbBits OutcPub.toLog 0 = fun _ => false := by
  funext j
  simp [msbBits]

theorem msbIndex_toLog_false : msbIndex OutcPub.toLog (fun _ => false) = 0 := by
  rw [← msbBits_toLog_zero]
  exact msbIndex_msbBits _ 0 (by show 0 < 2 ^ 1; norm_num)

section Small

variable {K : Type} [Field K]

/-- **A host's batching with four clause challenges**: the three clauses and the hosted difference vanish when every
batched value vanishes. -/
theorem tzc_combo5 (h2 : (2 : K) ≠ 0) (A B C E H : K)
    (h : ∀ μ0 μ1 μ2 μ3 ν : K, μ0 ≠ 0 → μ1 ≠ 0 → μ2 ≠ 0 → μ3 ≠ 0 → ν ≠ 0 →
      μ0 * A + μ1 * B + μ2 * C + μ3 * E + ν * H = 0) :
    A = 0 ∧ B = 0 ∧ C = 0 ∧ H = 0 := by
  have e1 := h 1 1 1 1 1 one_ne_zero one_ne_zero one_ne_zero one_ne_zero one_ne_zero
  have e2 := h 2 1 1 1 1 h2 one_ne_zero one_ne_zero one_ne_zero one_ne_zero
  have e3 := h 1 2 1 1 1 one_ne_zero h2 one_ne_zero one_ne_zero one_ne_zero
  have e4 := h 1 1 2 1 1 one_ne_zero one_ne_zero h2 one_ne_zero one_ne_zero
  have e5 := h 1 1 1 2 1 one_ne_zero one_ne_zero one_ne_zero h2 one_ne_zero
  have hA : A = 0 := by linear_combination e2 - e1
  have hB : B = 0 := by linear_combination e3 - e1
  have hC : C = 0 := by linear_combination e4 - e1
  have hE : E = 0 := by linear_combination e5 - e1
  exact ⟨hA, hB, hC, by linear_combination e1 - hA - hB - hC - hE⟩

end Small

section Combo

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))

/-- TZC's table values at a point `x`. -/
noncomputable def tzcR (Vo : OutcV) (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (x : Fin N → K) (j : ℕ) : K :=
  ((outcTzcRest Vo.pub Vo.geo).map (stgTabK U hbij Vo.bp cs OutcPub.toLog 1 x)).getD j 0

/-- **OUTC-02 TZC'S CLAUSES AT `To`'S ENTRY `0` AND ITS HOSTED SUM, from its define polynomial vanishing at every
draw.** -/
theorem outc_tzc_combo {L : ℕ} (hU : U ^ 2 = algebraMap GF K 7) (tag : MTag) (h64 : 64 ≤ L)
    (P0 : Block.BlockParams) (Vo : OutcV) (hP : StgSame P0 Vo.bp)
    (lc h Q eC rA rH iA iH : ℕ) (csIO : StgVw L → Block.Cm → Block.ZClaim → K) (v : StgVw L)
    (hlc : Vo.pub.lt ≤ lc) (ch : List Fp2) (hd : List (List Fp2)) (hhd : hd.length = 2)
    (hzero : ∀ y : Fin (P0.draws 2) → K, stgΦB U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
      (OutcV.bga ch) hd 2 (stgWords U hbij y) = 0) :
    tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 2
      - tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      * tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1 = 0
    ∧ tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      - l3K (tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 3 = 0
    ∧ ((tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      + tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1)
      - l3K (tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 6)
      - l3K (tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 9 = 0
    ∧ cubeSum (fun x : Fin (stgN P0 2) → K =>
        tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) x 0
          * ((tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) x 2
            + l3K (tzcR U hbij Vo (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) x) 6) - (kI Vo.pub.ceps).toK U))
      = cubeSum (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v) (OutcV.bga ch) hd 1) := by
  set O := Vo.pub with hO
  set G := Vo.geo with hG
  set cs := stgCsv U tag h64 lc h Q eC rA rH iA iH csIO v with hcs
  have hdraws : P0.draws 2 = 7 := by rw [hP.1]; rfl
  have hN : stgN P0 2 = OutcPub.toLog + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  have hj1 : 1 < P0.draws 2 := by omega
  have hj2 : 2 < P0.draws 2 := by omega
  have hj3 : 3 < P0.draws 2 := by omega
  have hj4 : 4 < P0.draws 2 := by omega
  have hj5 : 5 < P0.draws 2 := by omega
  have hj6 : 6 < P0.draws 2 := by omega
  have hm : OutcPub.toLog ≤ P0.draws 2 := by show 1 ≤ P0.draws 2; omega
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have hfit : tabsFit OutcPub.toLog (outcTzcRest O G) := by
    intro t ht
    unfold outcTzcRest at ht
    rcases List.mem_append.mp ht with ht1 | ht2
    · simp only [List.mem_cons, List.not_mem_nil, or_false] at ht1
      rcases ht1 with rfl | rfl | rfl
      · show (supp 1 (2 ^ OutcPub.toLog)).length = 2 ^ OutcPub.toLog
        simp [supp]
      · trivial
      · trivial
    · obtain ⟨p, _, rfl⟩ := List.mem_map.mp ht2
      trivial
  have hok : ∀ t ∈ outcTzcRest O G, TabPrivOK (fun _ => False) t := by
    intro t ht
    unfold outcTzcRest at ht
    rcases List.mem_append.mp ht with ht1 | ht2
    · rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_a_rho _ _ _ _
      rcases List.mem_cons.mp ht1 with rfl | ht1; · exact tabPrivOK_a_rho _ _ _ _
      exact absurd ht1 List.not_mem_nil
    · obtain ⟨p, _, rfl⟩ := List.mem_map.mp ht2
      exact tabPrivOK_a_rho _ _ _ _
  have hcan : ∀ t ∈ outcTzcRest O G, ∀ pt s, t = .eq pt s → ∀ a ∈ pt, a.Canon := by
    intro t ht pt s he
    unfold outcTzcRest at ht
    rcases List.mem_append.mp ht with ht1 | ht2
    · rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
      rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
      rcases List.mem_cons.mp ht1 with rfl | ht1; · cases he
      exact absurd ht1 List.not_mem_nil
    · obtain ⟨_, _, rfl⟩ := List.mem_map.mp ht2; cases he
  set Css : K := cubeSum (stgSpT U hbij P0 Vo.bp cs (OutcV.bga ch) hd 1) with hCss
  set Hs : K := cubeSum (fun x : Fin (stgN P0 2) → K =>
    tzcR U hbij Vo cs x 0 * ((tzcR U hbij Vo cs x 2 + l3K (tzcR U hbij Vo cs x) 6) - (kI O.ceps).toK U)) with hHs
  have hcl := tzc_combo5 (ZK60.Exec.two_ne_zero_K (K := K))
    (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 2
      - tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      * tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1)
    (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      - l3K (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 3)
    (((tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
      + tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1)
      - l3K (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 6)
      - l3K (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 9)
    ((1 - tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 0)
      * (tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1
        + 1 * tzcR U hbij Vo cs (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 2))
    (Hs - Css) ?_
  · exact ⟨hcl.1, hcl.2.1, hcl.2.2.1, sub_eq_zero.mp hcl.2.2.2⟩
  intro μ0 μ1 μ2 μ3 ν h0 h1 h2 h3 h4
  let y : Fin (P0.draws 2) → K := fun i =>
    if i.val = 1 then μ0 else if i.val = 2 then μ1 else if i.val = 3 then μ2 else if i.val = 4 then μ3
    else if i.val = 5 then ν else if i.val = 6 then 1 else 0
  have hy1 : y ⟨1, hj1⟩ = μ0 := by simp [y]
  have hy2 : y ⟨2, hj2⟩ = μ1 := by simp [y]
  have hy3 : y ⟨3, hj3⟩ = μ2 := by simp [y]
  have hy4 : y ⟨4, hj4⟩ = μ3 := by simp [y]
  have hy5 : y ⟨5, hj5⟩ = ν := by simp [y]
  have hy6 : y ⟨6, hj6⟩ = 1 := by simp [y]
  have hyb : ∀ a (ha : a < OutcPub.toLog), y ⟨a, by omega⟩ = bit ((fun _ : Fin OutcPub.toLog => false) ⟨a, ha⟩) := by
    intro a ha
    have ha0 : a = 0 := by
      have e : OutcPub.toLog = 1 := rfl
      omega
    subst ha0
    simp [y, bit]
  have hZ : ∀ i ∈ Z_range (P0.draws 2) 1 6, y i ≠ 0 := by
    intro i hi
    simp only [Z_range, Finset.mem_filter, Finset.mem_univ, true_and] at hi
    have hv : i.val = 1 ∨ i.val = 2 ∨ i.val = 3 ∨ i.val = 4 ∨ i.val = 5 ∨ i.val = 6 := by omega
    rcases hv with hv | hv | hv | hv | hv | hv <;> simp [y, hv, h0, h1, h2, h3, h4]
  have hdef := outcDefTZC_ok U hbij hU O G hdraws y hZ
  have hev := stgΦB_host_eval U hbij hU tag h64 P0 Vo.bp hP lc h Q eC rA rH iA iH (fun _ => False) csIO v hlc hIO_vac
    (OutcV.bga ch) hd 2 1 5 OutcPub.toLog 1 3 OutcPub.toLog hhd (by norm_num) hj5 hm le_rfl rfl rfl
    (outc_ss_spT_deg U hbij tag h64 hU P0 Vo hP lc h Q eC rA rH iA iH csIO v hlc (OutcV.bga ch) hd)
    (outcTzcRest O G)
    (tzcPoly (((stgWords U hbij y).drop 1).take 4) ((stgWords U hbij y).getD 5 Fp2.zero)
      ((stgWords U hbij y).getD 6 Fp2.zero) (kI O.ceps)) y
    hdef hok hcan
    (fun g =>
      let dl := l3K g 4
      let a1 := l3K g 7
      let a2 := l3K g 10
      let pad := (1 - g 1) * (g 2 + y ⟨6, hj6⟩ * g 3)
      let zc := (((y ⟨1, hj1⟩ * (g 3 - g 2 * g 2)) + (y ⟨2, hj2⟩ * (g 2 - dl)))
        + (y ⟨3, hj3⟩ * (((g 2 + g 2) - a1) - a2))) + (y ⟨4, hj4⟩ * pad)
      (g 0 * zc) + ((y ⟨5, hj5⟩ * g 1) * ((g 3 + a1) - (kI O.ceps).toK U)))
    (fun vals hv => by
      unfold tzcPoly
      rw [Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU,
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_add _ _) (Fp2.canon_mul _ _),
          Fp2.toK_add U _ _ (Fp2.canon_mul _ _) (Fp2.canon_mul _ _),
          Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          vg_drop_take_toK U hbij y 1 4 0 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 1 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 2 (by norm_num) (by omega),
          vg_drop_take_toK U hbij y 1 4 3 (by norm_num) (by omega),
          Fp2.toK_sub U _ _ (vg_canon hv 3) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (vg_canon hv 2) (l3W_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_sub _ _ (Fp2.canon_add _ _) (l3W_canon _ _)) (l3W_canon _ _),
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (l3W_canon _ _),
          Fp2.toK_add U _ _ (vg_canon hv 2) (vg_canon hv 2),
          Fp2.toK_mul U hU, Fp2.toK_sub U _ _ Fp2.canon_one (vg_canon hv 1), Fp2.toK_one,
          Fp2.toK_add U _ _ (vg_canon hv 2) (Fp2.canon_mul _ _), Fp2.toK_mul U hU,
          Fp2.toK_mul U hU, Fp2.toK_mul U hU,
          Fp2.toK_sub U _ _ (Fp2.canon_add _ _) (kI_canon _),
          Fp2.toK_add U _ _ (vg_canon hv 3) (l3W_canon _ _),
          stgWords_getD_toK U hbij y 5 hj5, stgWords_getD_toK U hbij y 6 hj6,
          l3W_toK U vals hv 4, l3W_toK U vals hv 7, l3W_toK U vals hv 10]
      simp only [vg_toK_map])
    (fun g hg => by
      have hdl := indDegLE_l3K g hg 4
      have ha1 := indDegLE_l3K g hg 7
      have ha2 := indDegLE_l3K g hg 10
      have hc0 : IndDegLE 2 (fun x => g 3 x - g 2 x * g 2 x) :=
        IndDegLE.sub (IndDegLE.mono (hg 3) (by norm_num)) (IndDegLE.mul (hg 2) (hg 2))
      have hc1 : IndDegLE 2 (fun x => g 2 x - l3K (fun idx => g idx x) 4) :=
        IndDegLE.mono (IndDegLE.sub (hg 2) hdl) (by norm_num)
      have hc2 : IndDegLE 2 (fun x => ((g 2 x + g 2 x) - l3K (fun idx => g idx x) 7) - l3K (fun idx => g idx x) 10) :=
        IndDegLE.mono (IndDegLE.sub (IndDegLE.sub (IndDegLE.add (hg 2) (hg 2)) ha1) ha2) (by norm_num)
      have hpad : IndDegLE 2 (fun x => (1 - g 1 x) * (g 2 x + y ⟨6, hj6⟩ * g 3 x)) :=
        IndDegLE.mul (IndDegLE.sub (IndDegLE.const 1) (hg 1))
          (IndDegLE.add (hg 2) (IndDegLE.cmul _ (hg 3)))
      have hzc : IndDegLE 2 (fun x =>
          (((y ⟨1, hj1⟩ * (g 3 x - g 2 x * g 2 x)) + (y ⟨2, hj2⟩ * (g 2 x - l3K (fun idx => g idx x) 4)))
            + (y ⟨3, hj3⟩ * (((g 2 x + g 2 x) - l3K (fun idx => g idx x) 7) - l3K (fun idx => g idx x) 10)))
            + (y ⟨4, hj4⟩ * ((1 - g 1 x) * (g 2 x + y ⟨6, hj6⟩ * g 3 x)))) :=
        IndDegLE.add (IndDegLE.add (IndDegLE.add (IndDegLE.cmul _ hc0) (IndDegLE.cmul _ hc1)) (IndDegLE.cmul _ hc2))
          (IndDegLE.cmul _ hpad)
      have hhost : IndDegLE 2 (fun x => (y ⟨5, hj5⟩ * g 1 x) * ((g 3 x + l3K (fun idx => g idx x) 7) - (kI O.ceps).toK U)) :=
        IndDegLE.mul (IndDegLE.cmul _ (hg 1)) (IndDegLE.sub (IndDegLE.add (hg 3) ha1) (IndDegLE.const _))
      exact IndDegLE.add (IndDegLE.mul (hg 0) hzc) (IndDegLE.mono hhost (by norm_num)))
  rw [hzero y, ite_eq_left hfit] at hev
  -- the table side: `eq · zc` plus `ν · host`
  set Fz : (Fin (stgN P0 2) → K) → K := fun x =>
    (((y ⟨1, hj1⟩ * (tzcR U hbij Vo cs x 2 - tzcR U hbij Vo cs x 1 * tzcR U hbij Vo cs x 1))
      + (y ⟨2, hj2⟩ * (tzcR U hbij Vo cs x 1 - l3K (tzcR U hbij Vo cs x) 3)))
      + (y ⟨3, hj3⟩ * (((tzcR U hbij Vo cs x 1 + tzcR U hbij Vo cs x 1) - l3K (tzcR U hbij Vo cs x) 6)
        - l3K (tzcR U hbij Vo cs x) 9)))
      + (y ⟨4, hj4⟩ * ((1 - tzcR U hbij Vo cs x 0) * (tzcR U hbij Vo cs x 1 + y ⟨6, hj6⟩ * tzcR U hbij Vo cs x 2)))
    with hFz
  have hev' : (0 : K) = cubeSum (fun x : Fin (stgN P0 2) → K =>
      eqDrawK OutcPub.toLog OutcPub.toLog 1 hm y x * Fz x
        + (y ⟨5, hj5⟩ * tzcR U hbij Vo cs x 0)
          * ((tzcR U hbij Vo cs x 2 + l3K (tzcR U hbij Vo cs x) 6) - (kI O.ceps).toK U))
      - y ⟨5, hj5⟩ * Css := hev
  have hsplit : cubeSum (fun x : Fin (stgN P0 2) → K =>
      eqDrawK OutcPub.toLog OutcPub.toLog 1 hm y x * Fz x
        + (y ⟨5, hj5⟩ * tzcR U hbij Vo cs x 0)
          * ((tzcR U hbij Vo cs x 2 + l3K (tzcR U hbij Vo cs x) 6) - (kI O.ceps).toK U))
      = cubeSum (fun x : Fin (stgN P0 2) → K => eqDrawK OutcPub.toLog OutcPub.toLog 1 hm y x * Fz x)
        + y ⟨5, hj5⟩ * Hs := by
    rw [hHs]
    unfold cubeSum
    rw [Finset.sum_add_distrib, Finset.mul_sum]
    congr 1
    exact Finset.sum_congr rfl (fun _ _ => by ring)
  have hcube := cube_eqDraw_single (M := P0.draws 2) (N := stgN P0 2) OutcPub.toLog hm hN y (fun _ => false) hyb Fz
  rw [hsplit, hcube, hFz] at hev'
  dsimp only at hev'
  rw [hy1, hy2, hy3, hy4, hy5, hy6] at hev'
  linear_combination (-1 : K) * hev'

end Combo

/-! ## TZC's tables at `(z, 0)`, the slices, the host term's and SS's cube sums -/

section Vals

variable {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
  (tag : MTag) {Lq : ℕ} (h64 : 64 ≤ Lq)

/-- **A one-bit `A_out` table at `(z, 0)` is the plane at `z`.** -/
theorem outc_identA1 (hU : U ^ 2 = algebraMap GF K 7) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq) (hlc : 0 < Vo.bp.logCols)
    {N : ℕ} (hN : N = OutcPub.toLog + 1) (z : Fin OutcPub.toLog → Bool) (off mr : ℕ) :
    stgTabK U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) OutcPub.toLog 1
        (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K))
        (.priv ⟨.a, [(off, Fp2.one)], OutcPub.toLog, rhoC 0 OutcPub.toLog, mr, 0⟩)
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA off OutcPub.toLog w z) := by
  refine (stgTabK_priv_cptS U hbij hU Vo.bp _ rA ogStage.lc ogStage.Q
    (stgIOX tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA w) (by decide) OutcPub.toLog z hN _
    (by intro _; rfl) (List.cons_ne_nil _ _) (by show 0 < 1; omega) (by simp [rhoC]) (by exact hlc)
    (by intro c' hc w' hw; simp [rhoC] at hc; obtain ⟨_, _, rfl⟩ := hc; cases hw)).trans ?_
  rw [privZ_eq_planeZ U _ _ _ _ OutcPub.toLog z (by omega) _ [(off, Fp2.one)] .a rfl rfl rfl]
  exact stgPlK_eq_alg U tag h64 _ _ _ _ _ _ _ _ ogStage_lc_le ogStage_h_le ogStage_radius w z

/-- **A one-bit slice of a twelve-bit plane at a row-aligned offset reads the plane's entry `2s + z`.** -/
theorem stgPlB_slice1 (rows i off s : ℕ) (w : StgVw Lq) (z : Fin OutcPub.toLog → Bool) (hal : off % 4096 = 0)
    (hs : 2 * s + 2 ≤ 4096) :
    stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rows i (off + 2 * s) OutcPub.toLog w z
      = stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rows i off 12 w
          (msbBits 12 (2 * s + msbIndex OutcPub.toLog z)) := by
  have e4 : (2 : ℕ) ^ ogStage.lc = 4096 := by show 2 ^ 12 = 4096; norm_num
  have e2 : (2 : ℕ) ^ OutcPub.toLog = 2 := rfl
  have hz : msbIndex OutcPub.toLog z < 2 := lt_of_lt_of_eq (msbIndex_lt OutcPub.toLog z) e2
  have hm : msbIndex 12 (msbBits 12 (2 * s + msbIndex OutcPub.toLog z)) = 2 * s + msbIndex OutcPub.toLog z :=
    msbIndex_msbBits 12 _ (lt_of_lt_of_le (by omega : 2 * s + msbIndex OutcPub.toLog z < 4096) (by norm_num))
  unfold stgPlB
  rw [Exec.Block.Join.W16.Look.planeZ_one U ogStage.lc _ _ _ .a (off + 2 * s) OutcPub.toLog [] 0 0
      (by rw [e4, e2]; omega) z,
    Exec.Block.Join.W16.Look.planeZ_one U ogStage.lc _ _ _ .a off 12 [] 0 0
      (by rw [e4, show (2 : ℕ) ^ 12 = 4096 by norm_num]; omega) _, hm]
  have h1 : (off + 2 * s) / 2 ^ ogStage.lc = off / 2 ^ ogStage.lc := by rw [e4]; omega
  have h2 : (off + 2 * s) % 2 ^ ogStage.lc + msbIndex OutcPub.toLog z
      = off % 2 ^ ogStage.lc + (2 * s + msbIndex OutcPub.toLog z) := by rw [e4]; omega
  rw [h1, h2]

/-- **TZC'S TABLES AT `(z, 0)`**: `u0`, the planes `D` and `Dsq`, and the nine limb slices. -/
theorem outc_tzc_vals (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (Vo : OutcV) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hlc : 0 < Vo.bp.logCols)
    {N : ℕ} (hN : N = OutcPub.toLog + 1) (z : Fin OutcPub.toLog → Bool) :
    tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
        (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K)) 0
      = (if msbIndex OutcPub.toLog z < 1 then 1 else 0)
    ∧ tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
        (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K)) 1
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_D)
          OutcPub.toLog w z)
    ∧ tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
        (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K)) 2
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_DSQ)
          OutcPub.toLog w z)
    ∧ ∀ p, p < 9 → tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
        (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K)) (3 + p)
      = algebraMap GF K (stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA
          ((outcLay O 14).aOff ocC_LIMB + 2 * p) OutcPub.toLog w z) := by
  have hl := outcTzcRest_length Vo.pub Vo.geo
  have hs : outcLay Vo.pub Vo.geo.bLogN = outcLay O 14 := by rw [hGb, hOL]
  refine ⟨?_, ?_, ?_, fun p hp => ?_⟩
  · unfold tzcR
    rw [getD_map_lt _ _ 0 (by omega) (.pub [])]
    show stgTabK U hbij Vo.bp _ OutcPub.toLog 1 _ (.pub (supp 1 (2 ^ OutcPub.toLog))) = _
    rw [stgTabK_pub_cptS U hbij Vo.bp _ OutcPub.toLog z hN _ (by simp [supp]),
      supp_getD_toK U _ _ _ (msbIndex_lt OutcPub.toLog z)]
  · obtain ⟨mr, hmr⟩ := outcTzcRest_D Vo.pub Vo.geo
    unfold tzcR
    rw [getD_map_lt _ _ 1 (by omega) (.pub []), hmr,
      outc_identA1 U hbij tag h64 hU Vo rA rH iA iH csIO w hlc hN z _ mr, hs]
  · obtain ⟨mr, hmr⟩ := outcTzcRest_Dsq Vo.pub Vo.geo
    unfold tzcR
    rw [getD_map_lt _ _ 2 (by omega) (.pub []), hmr,
      outc_identA1 U hbij tag h64 hU Vo rA rH iA iH csIO w hlc hN z _ mr, hs]
  · obtain ⟨mr, hmr⟩ := outcTzcRest_sl Vo.pub Vo.geo p hp
    unfold tzcR
    rw [getD_map_lt _ _ (3 + p) (by omega) (.pub []), hmr,
      outc_identA1 U hbij tag h64 hU Vo rA rH iA iH csIO w hlc hN z _ mr, hs]

/-- **THE HOST TERM'S CUBE SUM IS ITS VALUE AT `To`'S ENTRY `0`** (`u0` is `1` there and `0` elsewhere). -/
theorem outc_tzc_hs (Vo : OutcV) (cs : Block.Cm → Block.ZClaim → K) {N : ℕ} (hN : N = OutcPub.toLog + 1) (kc : K)
    (h0 : ∀ z : Fin OutcPub.toLog → Bool,
      tzcR U hbij Vo cs (fun i : Fin N => (bit (cptS OutcPub.toLog z i) : K)) 0
        = if msbIndex OutcPub.toLog z < 1 then 1 else 0) :
    cubeSum (fun x : Fin N → K =>
        tzcR U hbij Vo cs x 0 * ((tzcR U hbij Vo cs x 2 + l3K (tzcR U hbij Vo cs x) 6) - kc))
      = (tzcR U hbij Vo cs (fun i : Fin N => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 2
          + l3K (tzcR U hbij Vo cs (fun i : Fin N => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) 6) - kc := by
  rw [cube_sel_split OutcPub.toLog hN _ (fun w hw => by
    have e : tzcR U hbij Vo cs (fun i => (bit (w i) : K)) 0 = 0 := by
      unfold tzcR
      rw [getD_map_lt _ _ 0 (by rw [outcTzcRest_length]; omega) (.pub [])]
      exact stgTabK_pub_ext1 U hbij Vo.bp cs OutcPub.toLog hN _ w hw
    rw [e, zero_mul])]
  rw [Finset.sum_eq_single (fun _ => false)]
  · rw [h0, ite_eq_left (by rw [msbIndex_toLog_false]; omega), one_mul]
  · intro b _ hb
    rw [h0, ite_eq_right ?_, zero_mul]
    intro hlt
    apply hb
    rw [← msbBits_msbIndex OutcPub.toLog b, show msbIndex OutcPub.toLog b = 0 by omega]
    exact msbBits_toLog_zero
  · intro h
    exact absurd (Finset.mem_univ _) h

/-- **SS'S CUBE SUM** over the twelve-bit cube (`ldo = 12`): `Σ_c supp_d(c)·x(c)·x(c)`. -/
theorem outc_ss_cube (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (rA rH iA iH : ℕ) (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc) (bga : Fp2 × Fp2 × Fp2) (hd : List (List Fp2))
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hlc : 0 < Vo.bp.logCols) :
    cubeSum (stgSpT U hbij P0 Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) bga hd 1)
      = ∑ c : Fin 12 → Bool, (if msbIndex 12 c < Vo.pub.d then (1 : K) else 0)
          * shdOutcA U tag h64 O rA iA ocC_X w c * shdOutcA U tag h64 O rA iA ocC_X w c := by
  have hIO_vac : StgCsIODeg U hbij Vo.bp.endpointLogN (fun _ => False) csIO :=
    fun _ _ _ _ _ _ _ _ _ hf => absurd hf id
  have heq := (stgSpT_eval_and_deg U hbij hU tag h64 P0 Vo.bp hP ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH
    (fun _ => False) csIO w hlt hIO_vac bga hd 1 Vo.pub.ldo 1 4 rfl
    [.pub (supp Vo.pub.d (2 ^ Vo.pub.ldo)),
     .priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_X, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0,
       rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0),
       (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 1 + 0), 0⟩]
    ssPoly [] (outcDefSS_ok Vo.pub Vo.geo)
    (fun t ht => by
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_pub _ _
      rcases List.mem_cons.mp ht with rfl | ht; · exact tabPrivOK_a_rho _ _ _ _
      exact absurd ht List.not_mem_nil)
    (fun t ht pt s he => by
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      rcases List.mem_cons.mp ht with rfl | ht; · cases he
      exact absurd ht List.not_mem_nil)
    (fun g => (g 0 * g 1) * g 1)
    (fun vals _ => by unfold ssPoly; rw [Fp2.toK_mul U hU, Fp2.toK_mul U hU, vg_toK_map, vg_toK_map])
    (fun g hg => IndDegLE.mono (IndDegLE.mul (IndDegLE.mul (hg 0) (hg 1)) (hg 1)) (by norm_num))).1
  rw [heq]
  have hN : stgN P0 1 = 13 := by unfold stgN; rw [stg_slotShape hP]; show Vo.pub.ldo + 1 = 13; omega
  have hfit : tabsFit Vo.pub.ldo
      [.pub (supp Vo.pub.d (2 ^ Vo.pub.ldo)),
       .priv ⟨.a, [((outcLay Vo.pub Vo.geo.bLogN).aOff ocC_X, Fp2.one)], (outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0,
         rhoC 0 ((outcLay Vo.pub Vo.geo.bLogN).aLog.getD ocC_X 0),
         (outcLay Vo.pub Vo.geo.bLogN).aMaskBase + 2 * ((outcLay Vo.pub Vo.geo.bLogN).prefixA 1 + 0), 0⟩] := by
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · show (supp Vo.pub.d (2 ^ Vo.pub.ldo)).length = 2 ^ Vo.pub.ldo
      simp [supp]
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    · exact absurd ht List.not_mem_nil
  simp only [hfit, ↓reduceIte]
  rw [hldo]
  have hsl : (supp Vo.pub.d (2 ^ 12)).length = 2 ^ 12 := by simp [supp]
  rw [cube_sel_split 12 hN _ (fun w' hw' => by
    simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
    rw [stgTabK_pub_ext1 U hbij Vo.bp (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w) 12
      hN _ w' hw', zero_mul, zero_mul])]
  refine Finset.sum_congr rfl (fun c _ => ?_)
  simp only [List.map_cons, List.map_nil, List.getD_cons_zero, List.getD_cons_succ]
  rw [stgTabK_pub_cptS U hbij Vo.bp _ 12 c hN _ hsl, supp_getD_toK U _ _ _ (msbIndex_lt 12 c),
    outc_identA U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN c ocC_X _ (by rw [← hldo]; rfl)]

/-- **SS's cube sum at the live channels**: `Σ_c supp_d(c)·x(c)² = Σ_i x_i²` (`x_i` the plane `X` at `msbBits 12 i`). -/
theorem outc_ss_live (O : OutcPub) (rA iA : ℕ) (w : StgVw Lq) {d : ℕ} (dd : ℕ) (hdd : dd = d) (hd4 : d ≤ 4096) :
    ∑ c : Fin 12 → Bool, (if msbIndex 12 c < dd then (1 : K) else 0)
        * shdOutcA U tag h64 O rA iA ocC_X w c * shdOutcA U tag h64 O rA iA ocC_X w c
      = algebraMap GF K (∑ i : Fin d,
          stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_X) 12 w
            (msbBits 12 i.val)
          * stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_X) 12 w
            (msbBits 12 i.val)) := by
  rw [hdd]
  have hinj : Function.Injective (fun i : Fin d => msbBits 12 i.val) := fun a a' h =>
    Fin.ext (msbBits12_eq_of a.val a'.val (by omega) (by omega) h)
  rw [cube_sum_of_pad (fun i : Fin d => msbBits 12 i.val) hinj
    (fun c => (if msbIndex 12 c < d then (1 : K) else 0)
      * shdOutcA U tag h64 O rA iA ocC_X w c * shdOutcA U tag h64 O rA iA ocC_X w c)
    (fun c hc => by
      rw [ite_eq_right (fun hlt => hc ⟨⟨msbIndex 12 c, hlt⟩, msbBits_msbIndex 12 c⟩), zero_mul, zero_mul]),
    map_sum]
  refine Finset.sum_congr rfl (fun i _ => ?_)
  have hi := i.isLt
  rw [msbIndex_msbBits 12 i.val (lt_of_lt_of_le (by omega : i.val < 4096) (by norm_num)), ite_eq_left hi, one_mul,
    shdOutcA_alg, map_mul]

/-- **OUTC-02 TZC'S FOUR FACTS IN THE BASE FIELD**, from its define polynomial vanishing at every draw. -/
theorem outc_tzc (hU : U ^ 2 = algebraMap GF K 7) (O : OutcPub) (P0 : Block.BlockParams) (Vo : OutcV)
    (hP : StgSame P0 Vo.bp) (ch : List Fp2) (rA rH iA iH : ℕ)
    (csIO : StgVw Lq → Block.Cm → Block.ZClaim → K) (w : StgVw Lq)
    (hlt : Vo.pub.lt ≤ ogStage.lc) (hd : List (List Fp2)) (hhd : hd.length = 2)
    (hzero : ∀ y : Fin (P0.draws 2) → K, stgΦB U hbij P0 Vo.bp
      (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (OutcV.bga ch) hd 2 (stgWords U hbij y) = 0)
    (hGb : Vo.geo.bLogN = 14) (hOL : outcLay Vo.pub 14 = outcLay O 14) (hldo : Vo.pub.ldo = 12)
    (hlc : 0 < Vo.bp.logCols) (hOlt : O.lt = 12)
    {d : ℕ} (P : OutCPublic d) (hceps : Vo.pub.ceps = P.ceps) (hca : 1 ≤ P.ceps) (hcb : P.ceps ≤ 2 ^ 40)
    (hdd : Vo.pub.d = d) (hd4 : d ≤ 4096) :
    let D := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_D) OutcPub.toLog w
      (fun _ => false)
    let Dsq := stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA ((outcLay O 14).aOff ocC_DSQ)
      OutcPub.toLog w (fun _ => false)
    let lb : ℕ → Fin 3 → GF := fun k j => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA
      ((outcLay O 14).aOff ocC_LIMB) 12 w
      (msbBits 12 (2 * (3 * k + j.val) + msbIndex OutcPub.toLog (fun _ => false)))
    let x : Fin d → GF := fun i => stgPlB U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA iA
      ((outcLay O 14).aOff ocC_X) 12 w (msbBits 12 i.val)
    Dsq - D * D = 0 ∧ D - l3 (lb 0) = 0 ∧ 2 * D - l3 (lb 1) - l3 (lb 2) = 0
      ∧ Dsq + l3 (lb 1) - (P.ceps : GF) = ∑ i, x i * x i := by
  intro D Dsq lb x
  obtain ⟨cA, cB, cC, cH⟩ := outc_tzc_combo U hbij hU tag h64 P0 Vo hP ogStage.lc ogStage.h ogStage.Q ogStage.e
    rA rH iA iH csIO w hlt ch hd hhd hzero
  have hN : stgN P0 2 = OutcPub.toLog + 1 := by unfold stgN; rw [stg_slotShape hP]; rfl
  obtain ⟨-, v1, v2, vs⟩ := outc_tzc_vals U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN (fun _ => false)
  have v1' : tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 1 = algebraMap GF K D := v1
  have v2' : tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) 2 = algebraMap GF K Dsq := v2
  have hlive : (∑ c : Fin 12 → Bool, (if msbIndex 12 c < Vo.pub.d then (1 : K) else 0)
      * shdOutcA U tag h64 O rA iA ocC_X w c * shdOutcA U tag h64 O rA iA ocC_X w c)
      = algebraMap GF K (∑ i, x i * x i) := outc_ss_live U tag h64 O rA iA w Vo.pub.d hdd hd4
  rw [outc_tzc_hs U hbij Vo _ hN _
      (fun z => (outc_tzc_vals U hbij tag h64 hU O Vo rA rH iA iH csIO w hGb hOL hlc hN z).1),
    outc_ss_cube U hbij tag h64 hU O P0 Vo hP rA rH iA iH csIO w hlt (OutcV.bga ch) hd hGb hOL hldo hlc,
    hlive] at cH
  -- the limb slices
  have hal : (outcLay O 14).aOff ocC_LIMB % 4096 = 0 := by
    show (((outcLay O 14).aRowsL.take ocC_LIMB).sum * 2 ^ O.lt) % 4096 = 0
    rw [hOlt, show (2 : ℕ) ^ 12 = 4096 by norm_num]
    exact Nat.mul_mod_left _ _
  have sl : ∀ (k : ℕ) (j : Fin 3), k < 3 →
      tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
        (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K)) (3 + (3 * k + j.val))
        = algebraMap GF K (lb k j) := by
    intro k j hk
    have hj := j.isLt
    rw [vs (3 * k + j.val) (by omega), stgPlB_slice1 U tag h64 rA iA _ (3 * k + j.val) w _ hal (by omega)]
  have s30 := sl 0 0 (by norm_num)
  have s31 := sl 0 1 (by norm_num)
  have s32 := sl 0 2 (by norm_num)
  have s60 := sl 1 0 (by norm_num)
  have s61 := sl 1 1 (by norm_num)
  have s62 := sl 1 2 (by norm_num)
  have s90 := sl 2 0 (by norm_num)
  have s91 := sl 2 1 (by norm_num)
  have s92 := sl 2 2 (by norm_num)
  have m256 : (mbC 256 : K) = algebraMap GF K ((2 : GF) ^ 8) := by
    rw [mbC_nat 256 (by norm_num)]; norm_num
  have m65536 : (mbC 65536 : K) = algebraMap GF K ((2 : GF) ^ 16) := by
    rw [mbC_nat 65536 (by norm_num)]; norm_num
  have l3e : ∀ k, k < 3 → l3K (tzcR U hbij Vo (stgCsv U tag h64 ogStage.lc ogStage.h ogStage.Q ogStage.e rA rH iA iH csIO w)
      (fun i : Fin (stgN P0 2) => (bit (cptS OutcPub.toLog (fun _ => false) i) : K))) (3 + 3 * k)
      = algebraMap GF K (l3 (lb k)) := by
    intro k hk
    have e0 := sl k 0 hk
    have e1 := sl k 1 hk
    have e2 := sl k 2 hk
    unfold l3K l3
    rw [show 3 + 3 * k = 3 + (3 * k + (0 : Fin 3).val) from rfl, e0,
      show 3 + (3 * k + (0 : Fin 3).val) + 1 = 3 + (3 * k + (1 : Fin 3).val) from rfl, e1,
      show 3 + (3 * k + (0 : Fin 3).val) + 2 = 3 + (3 * k + (2 : Fin 3).val) from rfl, e2, m256, m65536]
    simp only [map_add, map_mul]
    ring
  have L0 := l3e 0 (by norm_num)
  have L1 := l3e 1 (by norm_num)
  have L2 := l3e 2 (by norm_num)
  rw [show 3 + 3 * 0 = 3 from rfl] at L0
  rw [show 3 + 3 * 1 = 6 from rfl] at L1
  rw [show 3 + 3 * 2 = 9 from rfl] at L2
  rw [L0, v1'] at cB
  rw [L1, L2, v1'] at cC
  rw [v1', v2'] at cA
  rw [L1, v2', hceps, kI_int_toK U P.ceps (by linarith) (by linarith), ← map_intCast (algebraMap GF K)] at cH
  refine ⟨?_, ?_, ?_, ?_⟩
  · apply (algebraMap GF K).injective
    rw [map_zero, map_sub, map_mul]
    exact cA
  · apply (algebraMap GF K).injective
    rw [map_zero, map_sub]
    exact cB
  · apply (algebraMap GF K).injective
    rw [map_zero, map_sub, map_sub, map_mul, map_ofNat]
    linear_combination cC
  · apply (algebraMap GF K).injective
    rw [map_sub, map_add]
    exact cH

end Vals

end ZK60.ProtocolClassify
