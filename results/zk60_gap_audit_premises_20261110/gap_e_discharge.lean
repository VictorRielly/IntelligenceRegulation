/-
Gap audit (premise register, 2026-11-10), scratch file E: premises of the top R13 theorems that the register marks
"dischargeable now", discharged here from existing library lemmas (no new mathematics), to show they are not gaps:

* `gap_o6_r13`: `ClassifyOpen`'s O6 (`commit`) at R13's token-words endpoint `r13TokenCommit`: by definition.
* `gap_xtest_code_r13`: the code facts the column test `T : XTest` carries (`hd`, `h2`, `hA`, `hAN`, `hca`) for the
  encoder `hTenc` fixes (R13's points, `rowFormK14`, `Q = 256`) at the radius `e = 24448` with `A = 2^16`: from
  `encLin_minDist` and `encLin_caOn` (BCIKS20 Thm 4.1 through FlashProve's `caOn_rsCode`).

Never imported by the root. No sorry, axiom or native_decide.
-/
import ZK60Formal

set_option autoImplicit false

namespace GapAudit

open ZK60 ZK60.Exec ZK60.ProtocolClassify

/-- **O6 at R13's token-words endpoint holds by definition.** -/
theorem gap_o6_r13 {T Salt : Type} (Rr dR : ℕ) {pos : T → Fin dR × Fin (2 ^ 14)} (hpos : Function.Injective pos)
    (place : Fin dR → Fin Rr) (msg : (T → ℕ) → Salt → Fin Rr → Fin (2 ^ 14) → ZK60.Circuit.GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → ZK60.Circuit.GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tagc : MTag) {Hdr : Type} :
    (∀ x : T → ℕ, (∀ t, x t < ZK60.Circuit.gP) →
        (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc).ok x)
      ∧ (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc).N
          ≤ 2 ^ (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
            tagc).depth
      ∧ (∀ s : ClsStmt Hdr,
          (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc).root s
            = s.inRoot)
      ∧ (R13.r13TokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
          tagc).depth ≤ 64 :=
  ⟨fun _ hx => hx, le_rfl, fun _ => rfl, by show 16 ≤ 64; norm_num⟩

/-- **The column test's code facts at R13** for the encoder `hTenc` fixes: minimum distance `48,897`, the radius
`24,448` below half of it, and correlated agreement with `A = 2^16` exceptions. -/
theorem gap_xtest_code_r13 {F : Type} [Field F] [Finite F] [Algebra ZK60.Circuit.GF F] :
    Code.MinDist (LinearMap.range (encLin (Q := 256)
        (fun j : Fin (2 ^ 16) => algebraMap ZK60.Circuit.GF F (R13.r13Pts j)) (rowFormK14 F))) 48897
      ∧ 2 * 24448 < 48897 ∧ 24448 + 1 ≤ 2 ^ 16
      ∧ Code.CAOn Unit (LinearMap.range (encLin (Q := 256)
          (fun j : Fin (2 ^ 16) => algebraMap ZK60.Circuit.GF F (R13.r13Pts j)) (rowFormK14 F))) 24448 (2 ^ 16) := by
  have hpts : Function.Injective (fun j : Fin (2 ^ 16) => algebraMap ZK60.Circuit.GF F (R13.r13Pts j)) :=
    (algebraMap ZK60.Circuit.GF F).injective.comp R13.r13_pts_injective
  have hd := encLin_minDist (Q := 256) _ hpts (rowFormK14 F) (by norm_num)
  have e1 : (2 : ℕ) ^ 16 - (2 ^ 14 + 256 - 1) = 48897 := by norm_num
  rw [e1] at hd
  exact ⟨hd, by norm_num, by norm_num, encLin_caOn (Q := 256) _ hpts (rowFormK14 F) (by norm_num) (by norm_num)⟩

end GapAudit

#print axioms GapAudit.gap_o6_r13
#print axioms GapAudit.gap_xtest_code_r13
