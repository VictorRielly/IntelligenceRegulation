/-
D63 lane L26 (2026-11-07), part 1: **`Binding` for the input commitment's opening at the unique-decoding radius**
(finding L24-1's fix, `PlaneCommit.OpensU` of L24's `RunExtractOpenU.lean`), reduced to `merkle_binding`.

L24 proved the deterministic core (`opensU_diff`): two different admissible values that open one root at radius `e`,
`2e + n + Q ≤ N`, have a position where BOTH open and their columns differ. What was left is the reduction to a Merkle
collision. A reduction cannot see which position that is without hashing, so this file takes the union over the `N`
positions: for each fixed position `j`, the reduction that outputs the two openings at `j` (no further query) is an
adversary of `merkle_binding`. So

  `Pr[two different values open one root at radius e] ≤ N · collBound (q + 2(h + 2))`,

and for `N ≤ 2^20`, depth `≤ 64` this is within the approved target `q·2^-100 + 2^-100` for EVERY `q`.

* `atCol`, `binding_at`: one position;
* **`bindingU`**: the union over the positions;
* `bindingU_le_target`, **`bindingU_target`**: at the target;
* **`binding_classifierU_target`**: `Binding M P εsTarget` for a protocol whose `opensIn` is `OpensU` and whose hidden
  output is a subsingleton (the classifier's `Unit`, L12-5);
* `opensU_mono`: a larger radius is a weaker opening;
* the radii: `w16r2_radiusU` (`e = 8052`, `2e + n + Q = 2^15` exactly, `w16r2_radiusU_max`: one more breaks it) and
  `r13_radiusU` (`e = 24,448`, `2e + n + Q = 2^16` exactly, `r13_radiusU_max`); the plane commitments' facts
  `w16r2PlaneCommit_radiusU`, `r13PlaneCommit_radiusU`.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunExtractOpenU
import ZK60Formal.OpeningR13

set_option autoImplicit false

namespace ZK60.Exec

open ZK60.Sound ZK60.Assembly
open ZK60.Circuit (gP GF)
open scoped ENNReal

namespace PlaneCommit

variable {V St Salt : Type} (C : PlaneCommit V St Salt)

/-- **The reduction at one position `j`**: the statement's root, the position, and the two openings there. -/
noncomputable def atCol (j : Fin C.N) (o : St × V × Salt × V × Salt) :
    Dig × ℕ × MerkleOpening Dig Dig (ColR C.R) × MerkleOpening Dig Dig (ColR C.R) :=
  (C.root o.1, j.val, ⟨C.column o.2.1 o.2.2.1 j, C.salt o.2.2.1 j, C.path o.2.2.1 j⟩,
    ⟨C.column o.2.2.2.1 o.2.2.2.2 j, C.salt o.2.2.2.2 j, C.path o.2.2.2.2 j⟩)

/-- **One fixed position**: an adversary making at most `q` queries outputs two openings with different columns at
position `j` that both verify against the statement's root with probability at most `collBound (q + 2(h + 2))`
(`merkle_binding`; the reduction makes no further query). -/
theorem binding_at (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (q : ℕ) (A : OC (QB L) Dig (St × V × Salt × V × Salt))
    (hA : A.Bounded q) (j : Fin C.N) :
    prH (fun G => C.column (A.run G).2.1 (A.run G).2.2.1 j ≠ C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 j
      ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root (A.run G).1) j.val
          ⟨C.column (A.run G).2.1 (A.run G).2.2.1 j, C.salt (A.run G).2.2.1 j, C.path (A.run G).2.2.1 j⟩
      ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root (A.run G).1) j.val
          ⟨C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 j, C.salt (A.run G).2.2.2.2 j, C.path (A.run G).2.2.2.2 j⟩)
      ≤ collBound (q + 2 * (C.depth + 2)) Dig := by
  let B : OC (QB L) Dig (Dig × ℕ × MerkleOpening Dig Dig (ColR C.R) × MerkleOpening Dig Dig (ColR C.R)) :=
    A.bind (fun o => .ret (C.atCol j o))
  have hB : B.Bounded q :=
    OC.Bounded.bind (q := 0) hA (fun o => (trivial : (OC.ret (C.atCol j o) : OC (QB L) Dig _).Bounded 0))
  refine le_trans (MeasureTheory.measure_mono ?_) ((merkleEncB C.tag L C.R h64 hr).merkle_binding C.depth q B hB)
  intro G hG
  have hBrun : B.run G = C.atCol j (A.run G) := by
    simp only [B, OC.run_bind]
    rfl
  show (B.run G).2.2.1.col ≠ (B.run G).2.2.2.col
    ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (B.run G).1 (B.run G).2.1 (B.run G).2.2.1
    ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (B.run G).1 (B.run G).2.1 (B.run G).2.2.2
  rw [hBrun]
  exact hG

/-- **Binding at the unique-decoding radius** (D63 lane L26; L24-1's fix). An adversary making at most `q` hash queries
opens one statement's commitment at radius `e` (`2e + n + Q ≤ N`) to two different values with probability at most
`N · collBound (q + 2(h + 2))`: at some position both open with different columns (`opensU_diff`), and each position
costs one `merkle_binding`. -/
theorem bindingU (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (he : 2 * e + (C.n + C.Q) ≤ C.N) (q : ℕ)
    (A : OC (QB L) Dig (St × V × Salt × V × Salt)) (hA : A.Bounded q) :
    prH (fun G => let o := A.run G
      o.2.1 ≠ o.2.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.1 o.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.2.2.1 o.2.2.2.2)
      ≤ (C.N : ℝ≥0∞) * collBound (q + 2 * (C.depth + 2)) Dig := by
  classical
  have hsub : {G : QB L → Dig | let o := A.run G
        o.2.1 ≠ o.2.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.1 o.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.2.2.1 o.2.2.2.2}
      ⊆ ⋃ j : Fin C.N, {G : QB L → Dig |
          C.column (A.run G).2.1 (A.run G).2.2.1 j ≠ C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 j
          ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root (A.run G).1) j.val
              ⟨C.column (A.run G).2.1 (A.run G).2.2.1 j, C.salt (A.run G).2.2.1 j, C.path (A.run G).2.2.1 j⟩
          ∧ (merkleEncB C.tag L C.R h64 hr).Opens G C.depth (C.root (A.run G).1) j.val
              ⟨C.column (A.run G).2.2.2.1 (A.run G).2.2.2.2 j, C.salt (A.run G).2.2.2.2 j,
                C.path (A.run G).2.2.2.2 j⟩} := by
    intro G hG
    obtain ⟨hne, h1, h2⟩ := hG
    obtain ⟨j, hj⟩ := C.opensU_diff L h64 hr e he G (A.run G).1 hne h1 h2
    exact Set.mem_iUnion.mpr ⟨j, hj⟩
  unfold prH
  refine (MeasureTheory.measure_mono hsub).trans ((MeasureTheory.measure_iUnion_fintype_le _ _).trans ?_)
  refine (Finset.sum_le_sum (fun j _ => C.binding_at L h64 hr q A hA j)).trans (le_of_eq ?_)
  rw [Finset.sum_const, Finset.card_univ, Fintype.card_fin, nsmul_eq_mul]

/-- **A larger radius is a weaker opening.** -/
theorem opensU_mono (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) {e e' : ℕ} (hee : e ≤ e') (G : QB L → Dig) (s : St)
    (v : V) (r : Salt) (h : C.OpensU L h64 hr e G s v r) : C.OpensU L h64 hr e' G s v r := by
  obtain ⟨hv, J, hJ, hop⟩ := h
  exact ⟨hv, J, by omega, hop⟩

end PlaneCommit

/-! ## At the approved target -/

section Target

/-- **`N` collision terms within the target**: for `N ≤ 2^20` positions, a tree of depth `≤ 64` and `q ≤ 2^120`
queries, `N · collBound (q + 2(h + 2)) ≤ q·2^-100 + 2^-100` (over the `2^256` digests). -/
theorem bindingU_le_target {N d q : ℕ} (hN : N ≤ 2 ^ 20) (hd : d ≤ 64) (hq : q ≤ 2 ^ 120) :
    (N : ℝ≥0∞) * collBound (q + 2 * (d + 2)) Dig ≤ εsTarget q := by
  unfold collBound
  rw [εsTarget_eq, card_dig, Fintype.card_prod, Fintype.card_fin, ← mul_div_assoc, ← Nat.cast_mul]
  refine natCast_div_le_div (by positivity) (by positivity) ?_
  have h120 : (2 : ℕ) ^ 120 = 1329227995784915872903807060280344576 := by norm_num
  have hT : q + 2 * (d + 2) ≤ 133 * (q + 1) := by omega
  have hT2 : q + 2 * (d + 2) ≤ 2 ^ 121 := by
    rw [show (2 : ℕ) ^ 121 = 2 * 2 ^ 120 by norm_num, h120]
    rw [h120] at hq
    omega
  calc N * ((q + 2 * (d + 2)) * (q + 2 * (d + 2) - 1) / 2) * 2 ^ 100
      ≤ 2 ^ 20 * ((q + 2 * (d + 2)) * (q + 2 * (d + 2))) * 2 ^ 100 := by
        refine Nat.mul_le_mul_right _ (Nat.mul_le_mul hN ?_)
        exact (Nat.div_le_self _ _).trans (Nat.mul_le_mul_left _ (Nat.sub_le _ _))
    _ ≤ 2 ^ 20 * ((133 * (q + 1)) * 2 ^ 121) * 2 ^ 100 :=
        Nat.mul_le_mul_right _ (Nat.mul_le_mul_left _ (Nat.mul_le_mul hT hT2))
    _ = (q + 1) * (133 * 2 ^ 241) := by ring
    _ ≤ (q + 1) * (2 ^ 128 * 2 ^ 128) := Nat.mul_le_mul_left _ (by norm_num)

namespace PlaneCommit

variable {V St Salt : Type} (C : PlaneCommit V St Salt)

/-- **One commitment's half of `Binding` at the radius, at the target**, for EVERY `q` (`N ≤ 2^20`, depth `≤ 64`):
below `2^120` queries by `bindingU`, above it the target exceeds `1`. -/
theorem bindingU_target {L : ℕ} (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (e : ℕ) (he : 2 * e + (C.n + C.Q) ≤ C.N)
    (hN : C.N ≤ 2 ^ 20) (hd : C.depth ≤ 64) (q : ℕ) (A : OC (QB L) Dig (St × V × Salt × V × Salt)) (hA : A.Bounded q) :
    prH (fun G => let o := A.run G
      o.2.1 ≠ o.2.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.1 o.2.2.1 ∧ C.OpensU L h64 hr e G o.1 o.2.2.2.1 o.2.2.2.2)
      ≤ εsTarget q := by
  by_cases hq : q ≤ 2 ^ 120
  · exact (C.bindingU L h64 hr e he q A hA).trans (bindingU_le_target hN hd hq)
  · exact le_trans (prH_le_one _) (one_le_εsTarget (by
      have : (2 : ℕ) ^ 100 ≤ 2 ^ 120 := Nat.pow_le_pow_right (by norm_num) (by norm_num)
      omega))

end PlaneCommit

variable {M : IntModel} {Coins : Type} {L : ℕ}

/-- **`Binding` at the target for a CLASSIFIER whose input opening is at the unique-decoding radius** (D63 lane L26):
`opensIn` is `OpensU` of a plane commitment with `2e + n + Q ≤ N`, `N ≤ 2^20`, depth `≤ 64`; the hidden output is a
subsingleton (the classifier's `Unit`), so the output half is vacuous as in `binding_classifier_target`. -/
theorem binding_classifierU_target (P : Protocol (QB L) Dig Coins M) [Subsingleton M.HidOut]
    (Cin : PlaneCommit M.Input P.Stmt P.Salt) (h64 : 64 ≤ L) (hri : 8 * Cin.R ≤ L) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hin : ∀ G s x r, P.opensIn G s x r ↔ Cin.OpensU L h64 hri e G s x r)
    (hN : Cin.N ≤ 2 ^ 20) (hdi : Cin.depth ≤ 64) : Binding M P εsTarget := by
  refine ⟨fun q A hA => ?_, fun q A hA => ?_⟩
  · refine le_trans (MeasureTheory.measure_mono ?_) (Cin.bindingU_target h64 hri e he hN hdi q A hA)
    rintro G ⟨hne, h1, h2⟩
    exact ⟨hne, (hin _ _ _ _).1 h1, (hin _ _ _ _).1 h2⟩
  · refine le_trans (le_of_eq ?_) zero_le
    refine MeasureTheory.measure_mono_null (fun G hG => ?_) MeasureTheory.measure_empty
    exact hG.1 (Subsingleton.elim _ _)

end Target

/-! ## The radii of W16R2 and R13 -/

section Radii

/-- **W16R2's unique-decoding radius** (`N = 2^15`, `n = 2^14`, `Q = 280`): `e = 8052`, `2e + n + Q = 2^15` exactly
(the radius `w16r2_open_code_facts` uses). -/
theorem w16r2_radiusU : 2 * 8052 + (2 ^ 14 + 280) ≤ 2 ^ 15 := by norm_num

/-- `8052` is the largest radius at W16R2. -/
theorem w16r2_radiusU_max : 2 ^ 15 < 2 * 8053 + (2 ^ 14 + 280) := by norm_num

/-- **R13's unique-decoding radius** (`N = 2^16`, `n = 2^14`, `Q = 256`): `e = 24,448`, `2e + n + Q = 2^16` exactly (the
radius L17's `opening_sound_r13` uses). -/
theorem r13_radiusU : 2 * 24448 + (2 ^ 14 + 256) ≤ 2 ^ 16 := by norm_num

/-- `24,448` is the largest radius at R13. -/
theorem r13_radiusU_max : 2 ^ 16 < 2 * 24449 + (2 ^ 14 + 256) := by norm_num

/-- **Any W16R2 plane commitment** (an endpoint, `w16r2TokenCommit` included) has the radius `8052`, at most `2^20`
columns, depth `15`. -/
theorem w16r2PlaneCommit_radiusU {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 280 → GF)
    (salt : Salt → Fin (2 ^ 15) → Dig) (path : Salt → Fin (2 ^ 15) → List Dig) (root : St → Dig) (tag : MTag) :
    2 * 8052 + ((w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).n
        + (w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).Q)
        ≤ (w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N
      ∧ (w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N ≤ 2 ^ 20
      ∧ (w16r2PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).depth ≤ 64 := by
  refine ⟨?_, ?_, ?_⟩
  · show 2 * 8052 + (2 ^ 14 + 280) ≤ 2 ^ 15
    exact w16r2_radiusU
  · show 2 ^ 15 ≤ 2 ^ 20
    norm_num
  · show 15 ≤ 64
    norm_num

/-- **Any R13 plane commitment** (`r13TokenCommit` included) has the radius `24,448`, at most `2^20` columns, depth
`16`. -/
theorem r13PlaneCommit_radiusU {V St Salt : Type} (R dR : ℕ) (ok : V → Prop)
    (plane : V → Fin dR → Fin (2 ^ 14) → GF) (plane_inj : ∀ v v', ok v → ok v' → plane v = plane v' → v = v')
    (place : Fin dR → Fin R) (msg : V → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = plane v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (root : St → Dig) (tag : MTag) :
    2 * 24448 + ((R13.r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).n
        + (R13.r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).Q)
        ≤ (R13.r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N
      ∧ (R13.r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).N ≤ 2 ^ 20
      ∧ (R13.r13PlaneCommit R dR ok plane plane_inj place msg msg_place pad salt path root tag).depth ≤ 64 := by
  refine ⟨?_, ?_, ?_⟩
  · show 2 * 24448 + (2 ^ 14 + 256) ≤ 2 ^ 16
    exact r13_radiusU
  · show 2 ^ 16 ≤ 2 ^ 20
    norm_num
  · show 16 ≤ 64
    norm_num

end Radii

end ZK60.Exec
