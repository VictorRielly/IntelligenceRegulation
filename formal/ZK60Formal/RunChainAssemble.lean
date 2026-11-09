/-
D63 lane L27 (2026-11-07), part 6: **the classify gate through the run's chain** (deliverable 4):
`classify_productionReady_joint_target`'s chain premises discharged from the run's chain, the kinds part by part, the
extraction failure at the run's queries and the per-part covers, at W16R2 and at R13 (the app).

* **`classify_productionReady_runChain`**: the gate `ProductionReady … εcTarget εsTarget εsTarget εzkTarget` from
  `ClassifyOpen` (every field but O11), the run's ONE transcript `tr`, a list of kinds on it part by part
  (`KindRun`: each with its own parse of `tr`, chains of `≤ 2^21` items, `np = L + 2`) with their constants, an extra
  event with its bound, the per-part covers (`jointCover_of_runParts`'s `halive`, `hdin`, `hdblk`, `hdout`, `hdep`), the
  constants totalling `≤ 2^26`. Every
  `FirstKind` field of L24's theorem (windows in order, no releases, the rbr lemmas, the header, the WEAK stability at
  the escaping step) is now PROVED from the parts (`KindRun.toFirstKind`); `hcover` from the parts
  (`jointCover_of_runParts`);
* `kindsFK_ℓ`, `kindsFK_lin`, `kindsFK_mem`: the kinds' chain bounds, linear parts and membership carried to their
  `FirstKind`s, for any protocol's gate (with `cover3_of_runParts`, what a gate whose endpoint is discharged separately
  takes from this lane: lane L26's `classifyProtocolU`);
* `εxRun`, `hEx_w16r2`, `hEx_r13`: the extra event is the extraction failure at the run's queries (`EvXR`), its bound
  `(q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102` (`extract_fail_run_w16r2`, `_r13`) and `1` beyond;
* **`classify_productionReady_run_w16r2`**, **`classify_productionReady_run_r13`**: the nine kinds of L24 (the slots,
  `M`, the openings' `opA` and `opB`, four define schedules, LogUp) at W16R2's and R13's per-kind constants
  (`SqForm`, `PowForm`: `lin_of_sqForm`, `lin_of_powForm`, `lin_lk_w16r2`, `lin_lk_r13`), the run's extraction failure
  at the 26 blocks' geometry, and L24's budgets (`joint_budget_w16r2 ≤ 2^25`, `joint_budget_r13 ≤ 2^26`).

What remains is exactly the premises of these two theorems (the lane doc lists them). Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainCover
import ZK60Formal.RunChainExtract

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-! ## The gate from the run's chain, generic -/

section Generic

/-- The kinds with their constants as L24's `FirstKind`s. -/
noncomputable def kindsFK {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}
    (Ks : List (KindRun tr × ℕ)) :
    List (FirstKind Lq α × ℕ) :=
  Ks.map (fun p => (p.1.toFirstKind, p.2))

theorem kindsFK_fst {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}
    (Ks : List (KindRun tr × ℕ)) :
    (kindsFK Ks).map Prod.fst = (Ks.map Prod.fst).map KindRun.toFirstKind := by
  simp [kindsFK, List.map_map, Function.comp_def]

/-- The kinds' chain bounds carried to their `FirstKind`s. -/
theorem kindsFK_ℓ {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}
    (Ks : List (KindRun tr × ℕ)) (hℓ : ∀ p ∈ Ks, p.1.RC.ℓ ≤ 2 ^ 21) : ∀ p ∈ kindsFK Ks, p.1.ℓ ≤ 2 ^ 21 := by
  intro p hp
  unfold kindsFK at hp
  obtain ⟨p', hp', rfl⟩ := List.mem_map.mp hp
  exact hℓ p' hp'

/-- The kinds' linear parts carried to their `FirstKind`s. -/
theorem kindsFK_lin {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}
    (Ks : List (KindRun tr × ℕ)) (hlin : ∀ q : ℕ, ∀ p ∈ Ks, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2) :
    ∀ q : ℕ, ∀ p ∈ kindsFK Ks, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2 := by
  intro q p hp
  unfold kindsFK at hp
  obtain ⟨p', hp', rfl⟩ := List.mem_map.mp hp
  exact hlin q p' hp'

/-- The run's kinds, as `FirstKind`s, are among the kinds of any list that extends theirs (`cover3_of_runParts`'s
`hsub` when the run's kinds sit beside others, such as the endpoint's own). -/
theorem kindsFK_mem {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}
    (Ks : List (KindRun tr × ℕ)) (X : List (FirstKind Lq α × ℕ)) :
    ∀ K ∈ Ks.map Prod.fst, K.toFirstKind ∈ (kindsFK Ks ++ X).map Prod.fst := by
  intro K hK
  rw [List.map_append, kindsFK_fst]
  exact List.mem_append_left _ (List.mem_map_of_mem hK)

/-- **THE GATE through the run's chain** (D63 lane L27): `ClassifyOpen`'s fields but O11, one run chain, the kinds part
by part (each its parse of the run's ONE transcript `tr`) with their constants, the extra event (the extraction failure)
with its bound, and the per-part covers:
`ProductionReady … εcTarget εsTarget εsTarget εzkTarget` when the constants total `≤ 2^26`. -/
theorem classify_productionReady_runChain (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ks : List (KindRun tr × ℕ)) (hℓ : ∀ p ∈ Ks, p.1.RC.ℓ ≤ 2 ^ 21) (hnp : ∀ p ∈ Ks, p.1.np = R.Ps.length + 2)
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → ∀ K ∈ Ks.map Prod.fst, ∀ i, i < R.Ps.length + 2 →
        allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks.map Prod.fst, ∃ c ∈ K.cs 0 (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ Ks.map Prod.fst, ∃ c ∈ K.cs (k + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ OutOk R ((classifyProtocol S R Lq V P Cin h64 hr hon.base).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks.map Prod.fst, ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdep : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ EpOk (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks.map Prod.fst, ∃ i, i < R.Ps.length + 2 ∧ ∃ c ∈ K.cs i (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (cx : ℕ) (hlin : ∀ q : ℕ, ∀ p ∈ Ks, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst (kindsFK Ks) cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget := by
  have hcov := jointCover_of_runParts R (classifyProtocol S R Lq V P Cin h64 hr hon.base) E tr (Ks.map Prod.fst)
    (fun K hK => by
      obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hK
      exact hnp p hp) Ex halive hdin hdblk hdout hdep
  refine classify_productionReady_joint_target R Lq V P Cin h64 hr hon U hbij site kOf δOf E O (kindsFK Ks) Ex εx hEx
    (fun A G hv hbad => ?_) cx (fun p hp => ?_) (fun q p hp => ?_) hx hbud hzk
  · rw [kindsFK_fst]
    exact hcov A G hv hbad
  · unfold kindsFK at hp
    obtain ⟨p', hp', rfl⟩ := List.mem_map.mp hp
    exact hℓ p' hp'
  · unfold kindsFK at hp
    obtain ⟨p', hp', rfl⟩ := List.mem_map.mp hp
    exact hlin q p' hp'

end Generic

/-! ## The extra event: the extraction failure at the run's queries -/

section Extra

/-- The extraction failure's bound for every `q`: `(q + 1)·(2^16 + 2^18)/2^126` for `q + 1 ≤ 2^102`, `1` beyond. -/
noncomputable def εxRun (q : ℕ) : ℝ≥0∞ := if q + 1 ≤ 2 ^ 102 then u126 q (2 ^ 16 + 2 ^ 18) else 1

theorem εxRun_le (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) : εxRun q ≤ u126 q (2 ^ 16 + 2 ^ 18) := by
  unfold εxRun
  exact (ite_eq_left hq).le

/-- The run's extraction failure at W16R2's geometry within `εxRun`, every `q`. -/
theorem hEx_w16r2 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) {α : Type} (C : ChainEnc (ItB L) (QB L) Dig)
    (coreOf : α → ℕ → List Op × Exec.Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ)
    (hVx : ∀ o, (Vx o).Bounded nx) (hnx : nx ≤ 3800000) (rx : α → List Dig) (nrx : ℕ)
    (hrx : ∀ o, (rx o).length ≤ nrx) (hnrx : nrx ≤ 2 ^ 99) (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXR tag L h64 C 280 280 256 15 15 12 26 coreOf Vx rx A) ≤ εxRun q := by
  unfold εxRun
  by_cases hq : q + 1 ≤ 2 ^ 102
  · rw [ite_eq_left hq]
    exact extract_fail_run_w16r2 tag L h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q hq A hA
  · rw [ite_eq_right hq]
    exact prH_le_one _

/-- The same at R13's geometry. -/
theorem hEx_r13 (tag : MTag) (L : ℕ) (h64 : 64 ≤ L) {α : Type} (C : ChainEnc (ItB L) (QB L) Dig)
    (coreOf : α → ℕ → List Op × Exec.Block.Core) (Vx : α → OC (QB L) Dig Unit) (nx : ℕ)
    (hVx : ∀ o, (Vx o).Bounded nx) (hnx : nx ≤ 3800000) (rx : α → List Dig) (nrx : ℕ)
    (hrx : ∀ o, (rx o).length ≤ nrx) (hnrx : nrx ≤ 2 ^ 99) (q : ℕ) (A : OC (QB L) Dig α) (hA : A.Bounded q) :
    prH (EvXR tag L h64 C 256 256 256 16 16 12 26 coreOf Vx rx A) ≤ εxRun q := by
  unfold εxRun
  by_cases hq : q + 1 ≤ 2 ^ 102
  · rw [ite_eq_left hq]
    exact extract_fail_run_r13 tag L h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q hq A hA
  · rw [ite_eq_right hq]
    exact prH_le_one _

end Extra

/-! ## The nine kinds at W16R2 and at R13 -/

section Nine

variable {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **The nine kinds' linear parts at W16R2** (L20/L21's 8B T128 figures): the slots `SqForm 5 924`, `M` `PowForm 3 106`,
`opA` `PowForm 1 111`, `opB` `PowForm 1 113`, the four define schedules `SqForm 80 (80·351)`, LogUp `SqForm e (3e)` with
`e ≤ 35,153,256`: every `q·εmax + B` within its `joint_w16r2_target` constant. -/
theorem nine_lin_w16r2 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) (hsl : Ksl.SqForm 5 924)
    (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 113) (hR₀ : KR₀.SqForm 80 (80 * 351))
    (hR₁ : KR₁.SqForm 80 (80 * 351)) (hH₀ : KH₀.SqForm 80 (80 * 351)) (hH₁ : KH₁.SqForm 80 (80 * 351)) (e : ℕ)
    (he : e ≤ 35153256) (hLU : KLU.SqForm e (3 * e)) :
    ∀ q : ℕ, ∀ p ∈ [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351),
      (KR₁, 80 + 80 * 351), (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)],
      (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2 := by
  intro q p hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact lin_of_sqForm Ksl 5 924 hsl q
  · exact (lin_of_powForm KM 3 106 (by norm_num) (by norm_num) hM q).trans_eq (by norm_num)
  · exact (lin_of_powForm KA 1 111 (by norm_num) (by norm_num) hA q).trans_eq (by norm_num)
  · exact (lin_of_powForm KB 1 113 (by norm_num) (by norm_num) hB q).trans_eq (by norm_num)
  · exact lin_of_sqForm KR₀ 80 (80 * 351) hR₀ q
  · exact lin_of_sqForm KR₁ 80 (80 * 351) hR₁ q
  · exact lin_of_sqForm KH₀ 80 (80 * 351) hH₀ q
  · exact lin_of_sqForm KH₁ 80 (80 * 351) hH₁ q
  · exact lin_lk_w16r2 KLU e he hLU q

/-- **The nine kinds' linear parts at R13** (the app's profile): the slots `SqForm 7 (7·370)`, `M` `PowForm 3 106`,
`opA` `PowForm 1 111`, `opB` `PowForm 1 105` (the δ/3 count), the four define schedules `SqForm 80 (80·451)`, LogUp
`SqForm e (3e)` with `e ≤ 2^26`: every `q·εmax + B` within its `joint_r13_target` constant. -/
theorem nine_lin_r13 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) (hsl : Ksl.SqForm 7 (7 * 370))
    (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 105) (hR₀ : KR₀.SqForm 80 (80 * 451))
    (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451)) (hH₁ : KH₁.SqForm 80 (80 * 451)) (e : ℕ)
    (he : e ≤ 2 ^ 26) (hLU : KLU.SqForm e (3 * e)) :
    ∀ q : ℕ, ∀ p ∈ [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 21), (KR₀, 80 + 80 * 451),
      (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)],
      (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2 := by
  intro q p hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact lin_of_sqForm Ksl 7 (7 * 370) hsl q
  · exact (lin_of_powForm KM 3 106 (by norm_num) (by norm_num) hM q).trans_eq (by norm_num)
  · exact (lin_of_powForm KA 1 111 (by norm_num) (by norm_num) hA q).trans_eq (by norm_num)
  · exact (lin_of_powForm KB 1 105 (by norm_num) (by norm_num) hB q).trans_eq (by norm_num)
  · exact lin_of_sqForm KR₀ 80 (80 * 451) hR₀ q
  · exact lin_of_sqForm KR₁ 80 (80 * 451) hR₁ q
  · exact lin_of_sqForm KH₀ 80 (80 * 451) hH₀ q
  · exact lin_of_sqForm KH₁ 80 (80 * 451) hH₁ q
  · exact lin_lk_r13 KLU e he hLU q

/-- W16R2's nine constants with the run's extraction failure: L24's `joint_budget_w16r2`, `31,177,585 ≤ 2^26`. -/
theorem nine_bud_w16r2 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) :
    partConst (kindsFK [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351),
      (KR₁, 80 + 80 * 351), (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)]) (2 ^ 16 + 2 ^ 18)
      ≤ 2 ^ 26 := by
  simp only [kindsFK, List.map_cons, List.map_nil]
  rw [partConst_nine]
  norm_num

/-- R13's nine constants with the run's extraction failure: L24's `joint_budget_r13`, `57,261,913 ≤ 2^26`. -/
theorem nine_bud_r13 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) :
    partConst (kindsFK [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 21), (KR₀, 80 + 80 * 451),
      (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)]) (2 ^ 16 + 2 ^ 18)
      ≤ 2 ^ 26 := by
  simp only [kindsFK, List.map_cons, List.map_nil]
  rw [partConst_nine]
  norm_num

end Nine

/-! ## The gate at W16R2 and at R13 -/

section Gates

/-- **THE GATE at W16R2 through the run's chain** (D63 lane L27): `ClassifyOpen` (every field but O11), the run's ONE
transcript `tr`, the nine kinds of L24 part by part (each its parse of `tr`, chains of `≤ 2^21` items, `np = L + 2`)
in W16R2's forms, the extraction failure at the run's queries at the 26 blocks' geometry (`EvXR`, the boundaries' and stages' Merkle work within `3,800,000` queries,
at most `2^99` extra roots), and the per-part covers with that event: `ProductionReady … εcTarget εsTarget εsTarget
εzkTarget`. -/
theorem classify_productionReady_run_w16r2 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 5 924) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 113)
    (hR₀ : KR₀.SqForm 80 (80 * 351)) (hR₁ : KR₁.SqForm 80 (80 * 351)) (hH₀ : KH₀.SqForm 80 (80 * 351))
    (hH₁ : KH₁.SqForm 80 (80 * 351)) (e : ℕ) (he : e ≤ 35153256) (hLU : KLU.SqForm e (3 * e))
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∀ i, i < R.Ps.length + 2 →
        allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs 0 (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs (k + 1) (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocol S R Lq V P Cin h64 hr hon.base).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdep : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ EpOk (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ i, i < R.Ps.length + 2 ∧ ∃ c ∈ K.cs i (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget :=
  classify_productionReady_runChain R Lq V P Cin h64 hr hon U hbij site kOf δOf E O tr
    [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351), (KR₁, 80 + 80 * 351),
      (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)]
    (fun p hp => hℓ p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (fun p hp => hnp p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx) εxRun
    (fun q A hA => hEx_w16r2 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA)
    halive hdin hdblk hdout hdep (2 ^ 16 + 2 ^ 18)
    (nine_lin_w16r2 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hsl hM hA hB hR₀ hR₁ hH₀ hH₁ e he hLU)
    εxRun_le (nine_bud_w16r2 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU) hzk

/-- **THE GATE at R13, the media app's profile, through the run's chain** (D63 lane L27): as at W16R2, with R13's
forms (slots `SqForm 7 (7·370)`, `opB` `PowForm 1 105`, define schedules `SqForm 80 (80·451)`, LogUp `e ≤ 2^26`) and the
extraction failure at R13's opening geometry. Only the joint form meets the target at R13 (L24-4). -/
theorem classify_productionReady_run_r13 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 7 (7 * 370)) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 105)
    (hR₀ : KR₀.SqForm 80 (80 * 451)) (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451))
    (hH₁ : KH₁.SqForm 80 (80 * 451)) (e : ℕ) (he : e ≤ 2 ^ 26) (hLU : KLU.SqForm e (3 * e))
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∀ i, i < R.Ps.length + 2 →
        allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs 0 (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs (k + 1) (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocol S R Lq V P Cin h64 hr hon.base).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hdep : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ EpOk (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], ∃ i, i < R.Ps.length + 2 ∧ ∃ c ∈ K.cs i (A.runLog G).2,
        EntD K.RC.W c (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget :=
  classify_productionReady_runChain R Lq V P Cin h64 hr hon U hbij site kOf δOf E O tr
    [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 21), (KR₀, 80 + 80 * 451), (KR₁, 80 + 80 * 451),
      (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)]
    (fun p hp => hℓ p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (fun p hp => hnp p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx) εxRun
    (fun q A hA => hEx_r13 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA)
    halive hdin hdblk hdout hdep (2 ^ 16 + 2 ^ 18)
    (nine_lin_r13 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hsl hM hA hB hR₀ hR₁ hH₀ hH₁ e he hLU)
    εxRun_le (nine_bud_r13 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU) hzk

end Gates

end ZK60.ProtocolClassify
