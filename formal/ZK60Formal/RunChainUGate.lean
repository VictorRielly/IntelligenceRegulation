/-
D63 lane L30 (2026-11-09), part 4: **THE GATE at `classifyProtocolU` through the run's chain**: L26's
`classifyU_productionReady_ep_target` (the instance whose input commitment opens at the unique-decoding radius, the
endpoint's extraction discharged from its column test) fed by L27's run chain (the kinds part by part, the Merkle
extraction failure at the run's queries, the per-part covers) and the column test's two kinds on the run's transcript
(`RunChainUStab.lean`).

* `cover3_fits_h3`: L27's `cover3_of_runParts` IS a proof of the premise `h3` of L26's gate (the fit the two lanes
  claimed, compiled). Its premise `halive` is the flat one, which acceptance does not give (finding L30-1), so the
  gates below use `cover3_of_runParts_ord` instead;
* **`classifyU_productionReady_runChain`**: the gate, generic: any list of kinds on the run's transcript with their
  constants (L27's `KindRun`s), any further kinds (the endpoint's), an extra event with its bound, the kinds alive IN
  ORDER (`AliveOrd` on a list `Ko` of the run's kinds), the per-part dooms, L26's endpoint premises, the constants
  totalling `≤ 2^26`: `ProductionReady … (classifyProtocolU …) εcTarget εsTarget εsTarget εzkTarget`;
* `eleven_bud_w16r2` (`31,480,689 ≤ 2^26`, L26's total), `eleven_bud_r13` (`55,525,211 ≤ 2^26`: R13 with L28's proved
  opening figures at the radius `24,448`, `opA ≤ 2^-110` and `opB ≤ 2^-126`), `eleven_totals`;
* **`classifyU_productionReady_run_w16r2`**, **`classifyU_productionReady_run_r13`**: the gate at W16R2 and at R13
  (the media app's profile): L24's nine kinds in their forms, the column test's two kinds (`xRunA`, `xRunB`) at the
  test's parameters, the run's Merkle extraction failure at the 26 blocks' geometry, the nine kinds alive in order,
  the per-part dooms, and the endpoint's links (the test's chain event on the run's transcript, the decoded plane's
  zeros as a doom of the run's kinds).

Nothing is switched: L18's `classifyProtocol`, L26's and L27's theorems and `Statements.lean` are unchanged. Every
premise is an explicit hypothesis; the lane doc lists them with the lane that should discharge each. Only `propext`,
`Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunChainAssemble
import ZK60Formal.RunChainUOrd
import ZK60Formal.RunChainUStab

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX ZK60.Exec.Link Code
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat)

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## L27's cover is a proof of L26's premise `h3` -/

section Fit

/-- **L27's `cover3_of_runParts` fits L26's `h3`** (D63 lane L30): at `classifyProtocolU`, with the run's kinds read
in any list `L` of kinds with constants that holds them, its conclusion is the premise `h3` of
`classifyU_productionReady_ep_target`, term for term. Its premise `halive` (every kind alive on every accepted run
outside the extraction failure) is NOT implied by acceptance (finding L30-1); `cover3_of_runParts_ord` asks the
ordered form. -/
theorem cover3_fits_h3 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ) (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ks : List (KindRun tr)) (hnp : ∀ K ∈ Ks, K.np = R.Ps.length + 2)
    (L : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ)) (hsub : ∀ K ∈ Ks, K.toFirstKind ∈ L.map Prod.fst)
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → ∀ K ∈ Ks, ∀ i, i < R.Ps.length + 2 →
        allSt K.RC.W (K.cs i (A.runLog G).2) (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs 0 (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (k + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K ∈ Ks, ∃ c ∈ K.cs (R.Ps.length + 1) (A.runLog G).2, EntD K.RC.W c (tr G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr base e).ypub (A.runLog G).1.1)
            (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) →
        Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G :=
  cover3_of_runParts R (classifyProtocolU S R Lq V P Cin h64 hr base e) E tr Ks hnp (L.map Prod.fst) hsub Ex
    halive hdin hdblk hdout

end Fit

/-! ## The gate, generic -/

section Generic

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at `classifyProtocolU` through the run's chain** (D63 lane L30): every `ClassifyOpen` field but O11,
the radius, the run's ONE transcript `tr`, a list `Ks` of kinds on it part by part with their constants (chains of
`≤ 2^21` items, `np = L + 2`), further kinds `X` with their constants (the endpoint's column test), an extra event
with its bound (the Merkle extraction failure), and:
* the cover of stage IN-C, the blocks and stage OUT-C on a list `Ko` of the run's kinds IN ORDER: `halive` (the kinds
  of `Ko` alive in order, `AliveOrd`) and the per-part dooms `hdin`, `hdblk`, `hdout`;
* L26's endpoint premises: the extractor's openings (`hops`, `hcan`), the endpoint read by decoding (`hE`, `mk`), the
  token-words plane (`pos`, `hplane`), the column test's cover (`hX`) and the decoded plane's zeros (`hzero`), their
  events among the kinds of `Ks` and `X`;
* the constants of `Ks` and `X` and the extra event totalling `≤ 2^26`.
Then `ProductionReady … (classifyProtocolU …) εcTarget εsTarget εsTarget εzkTarget`. -/
theorem classifyU_productionReady_runChain (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ks : List (KindRun tr × ℕ)) (hℓ : ∀ p ∈ Ks, p.1.RC.ℓ ≤ 2 ^ 21) (hnp : ∀ p ∈ Ks, p.1.np = R.Ps.length + 2)
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ Ks.map Prod.fst)
    (X : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ)) (hℓX : ∀ p ∈ X, p.1.ℓ ≤ 2 ^ 21)
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G → ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr hon.base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hX : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) → ∃ K' ∈ (kindsFK Ks ++ X).map Prod.fst, K'.Ev A G)
    (hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ (kindsFK Ks ++ X).map Prod.fst, K'.Ev A G)
    (cx : ℕ) (hlin : ∀ q : ℕ, ∀ p ∈ Ks, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hlinX : ∀ q : ℕ, ∀ p ∈ X, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst (kindsFK Ks ++ X) cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget := by
  have hnpo : ∀ K' ∈ Ko, K'.np = R.Ps.length + 2 := by
    intro K' hK'
    obtain ⟨p, hp, rfl⟩ := List.mem_map.mp (hKo K' hK')
    exact hnp p hp
  have h3 := cover3_of_runParts_ord R (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) E tr Ko hnpo
    ((kindsFK Ks ++ X).map Prod.fst) (fun K' hK' => kindsFK_mem Ks X K' (hKo K' hK')) Ex halive hdin hdblk hdout
  exact classifyU_productionReady_ep_target R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20
    (kindsFK Ks ++ X) Ex εx hEx h3 pos hplane mk ops hE hops hcan hX hzero cx
    (fun p hp => (List.mem_append.mp hp).elim (kindsFK_ℓ Ks hℓ p) (hℓX p))
    (fun q p hp => (List.mem_append.mp hp).elim (kindsFK_lin Ks hlin q p) (hlinX q p)) hx hbud hzk

end Generic

/-! ## The numbers: nine kinds and the column test's two -/

section Numbers

variable {Lq : ℕ} {α : Type} {tr : (QB Lq → Dig) → α → List (TItem × Dig)}

/-- **W16R2's eleven constants with the run's extraction failure**: L26's `jointU_budget_w16r2`,
`31,480,689 ≤ 2^26` (and `≤ 2^25`). -/
theorem eleven_bud_w16r2 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) (KxA KxB : FirstKind Lq α) :
    partConst (kindsFK [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351),
        (KR₁, 80 + 80 * 351), (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)]
      ++ [(KxA, 2 ^ 15), (KxB, 2 ^ 13)]) (2 ^ 16 + 2 ^ 18) ≤ 2 ^ 26 := by
  simp only [kindsFK, List.map_cons, List.map_nil, List.cons_append, List.nil_append]
  rw [partConst_eleven]
  norm_num

/-- **R13's eleven constants with the run's extraction failure, at L28's proved opening figures** (the regular
openings at the unique-decoding radius `e = 24,448`, as the endpoint: `opA ≤ 2^-110`, constant `2^16`;
`opB ≤ 2^-126`, constant `1`; L28's `opA_eps_r13`, `opB_eps_r13u`): `55,525,211 ≤ 2^26`. (L24 and L26 priced R13's
`opA` and `opB` at `2^15` and `2^21`, the δ/3 figures: `57,589,594`.) -/
theorem eleven_bud_r13 (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) (KxA KxB : FirstKind Lq α) :
    partConst (kindsFK [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 16), (KB, 1), (KR₀, 80 + 80 * 451),
        (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)]
      ++ [(KxA, 2 ^ 16), (KxB, 1)]) (2 ^ 16 + 2 ^ 18) ≤ 2 ^ 26 := by
  simp only [kindsFK, List.map_cons, List.map_nil, List.cons_append, List.nil_append]
  rw [partConst_eleven]
  norm_num

/-- The exact totals (the doc's figures): W16R2 `31,480,689`; R13 at L28's figures `55,525,211`. -/
theorem eleven_totals :
    (2 ^ 16 + 2 ^ 18) + ((5 + 924 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)
      + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17)
      + (26370000 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)) = 31480689
    ∧ (2 ^ 16 + 2 ^ 18) + ((7 + 7 * 370 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 16 + 2 ^ 17) + (1 + 2 ^ 17)
      + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17)
      + (50331700 + 2 ^ 17) + (2 ^ 16 + 2 ^ 17) + (1 + 2 ^ 17)) = 55525211 := by
  norm_num

/-- **The nine kinds' linear parts at R13, at L28's proved opening figures**: the slots `SqForm 7 (7·370)`, `M`
`PowForm 3 106`, `opA` `PowForm 1 110`, `opB` `PowForm 1 126`, the four define schedules `SqForm 80 (80·451)`, LogUp
`SqForm e (3e)` with `e ≤ 2^26`: every `q·εmax + B` within its constant. -/
theorem nine_lin_r13u (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr) (hsl : Ksl.SqForm 7 (7 * 370))
    (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 110) (hB : KB.PowForm 1 126) (hR₀ : KR₀.SqForm 80 (80 * 451))
    (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451)) (hH₁ : KH₁.SqForm 80 (80 * 451)) (eL : ℕ)
    (heL : eL ≤ 2 ^ 26) (hLU : KLU.SqForm eL (3 * eL)) :
    ∀ q : ℕ, ∀ p ∈ [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 16), (KB, 1), (KR₀, 80 + 80 * 451),
      (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)],
      (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2 := by
  intro q p hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact lin_of_sqForm Ksl 7 (7 * 370) hsl q
  · exact (lin_of_powForm KM 3 106 (by norm_num) (by norm_num) hM q).trans_eq (by norm_num)
  · exact (lin_of_powForm KA 1 110 (by norm_num) (by norm_num) hA q).trans_eq (by norm_num)
  · exact (lin_of_powForm KB 1 126 (by norm_num) (by norm_num) hB q).trans_eq (by norm_num)
  · exact lin_of_sqForm KR₀ 80 (80 * 451) hR₀ q
  · exact lin_of_sqForm KR₁ 80 (80 * 451) hR₁ q
  · exact lin_of_sqForm KH₀ 80 (80 * 451) hH₀ q
  · exact lin_of_sqForm KH₁ 80 (80 * 451) hH₁ q
  · exact lin_lk_r13 KLU eL heL hLU q

end Numbers

/-! ## The gate at W16R2 and at R13 -/

section Gates

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at W16R2 at `classifyProtocolU`, through the run's chain** (D63 lane L30): `ClassifyOpen` (every field
but O11), the radius, the run's ONE transcript `tr`, L24's nine kinds part by part in W16R2's forms, the endpoint's
column test on a parse `RCx` of `tr` at W16R2's parameters (`N = 2^15`, `|F| = p²`, `e = 8052`, `Q = 280`; its
extraction a cut reader), the run's Merkle extraction failure at the 26 blocks' geometry, the nine kinds alive in the
order `Ko`, the per-part dooms, and the endpoint's links: `hlink` (the test's chain event on `tr` when the base-field
extracted matrix is not close inside the columns that open) and `hdzero` (the decoded plane's zeros, as a doom of the
run's kinds). Eleven kinds, `31,480,689 ≤ 2^26` units. -/
theorem classifyU_productionReady_run_w16r2 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 5 924) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 111) (hB : KB.PowForm 1 113)
    (hR₀ : KR₀.SqForm 80 (80 * 351)) (hR₁ : KR₁.SqForm 80 (80 * 351)) (hH₀ : KH₀.SqForm 80 (80 * 351))
    (hH₁ : KH₁.SqForm 80 (80 * 351)) (eL : ℕ) (heL : eL ≤ 35153256) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F κ μ Cl 15) (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ 15) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 15)))
    (hUc : CutReads (Exec.Block.absOfC RCx.C) Ux) (hXc : CutReads (Exec.Block.absOfC RCx.C) Xx)
    (pr : ℕ) (hp1 : pr ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ pr) (hF : Fintype.card F = pr ^ 2)
    (hw0 : T.w0 ≤ 2 ^ 61) (hβLR : T.βLR = (1 + (pr : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0))
    (hTe : T.e = 8052) (hTQ : T.nQ = 280) (hβJ : T.βJ = 1)
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr hon.base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hlink : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0
        ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA))
            (Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA))
        ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0
        ∧ subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_runChain R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 tr
    [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351), (KR₁, 80 + 80 * 351),
      (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)]
    (fun p hp => hℓ p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (fun p hp => hnp p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    Ko hKo
    [(xRunA RCx T Ux Xx hwA hUc hXc, 2 ^ 15), (xRunB RCx T Ux Xx hwB hUc hXc, 2 ^ 13)]
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl
      · exact hℓx
      · exact hℓx)
    (EvXR tag Lq h64 C 280 280 256 15 15 12 26 coreOf Vx rx) εxRun
    (fun q A hA => hEx_w16r2 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA)
    halive hdin hdblk hdout pos hplane mk ops hE hops hcan
    (fun A G hv hx hnc => by
      rcases xRun_cover RCx tr htrx T Ux Xx hwA hwB hUc hXc A G (hlink A G hv hx hnc) with hev | hev
      · exact ⟨xRunA RCx T Ux Xx hwA hUc hXc, List.mem_map.mpr ⟨(xRunA RCx T Ux Xx hwA hUc hXc, 2 ^ 15),
          List.mem_append_right _ List.mem_cons_self, rfl⟩, hev⟩
      · exact ⟨xRunB RCx T Ux Xx hwB hUc hXc, List.mem_map.mpr ⟨(xRunB RCx T Ux Xx hwB hUc hXc, 2 ^ 13),
          List.mem_append_right _ (List.mem_cons_of_mem _ List.mem_cons_self), rfl⟩, hev⟩)
    (fun A G hv hx hz => kindEv_of_dm_ord Ko (R.Ps.length + 2)
      (fun K' hK' => hnp K' (hKo K' hK')) _
      (fun K' hK' => kindsFK_mem _ _ K' (hKo K' hK')) A G (halive A G hv hx) (hdzero A G hv hx hz))
    (2 ^ 16 + 2 ^ 18)
    (nine_lin_w16r2 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU)
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl
      · exact (xRunA_lin RCx T Ux Xx hwA hUc hXc q 111 (by norm_num)
          (T.εA_w16r2 pr hp1 hp2 hF hw0 hβLR)).trans_eq (by norm_num)
      · exact (xRunB_lin RCx T Ux Xx hwB hUc hXc q 113 (by norm_num)
          (T.εB_w16r2 hTe hTQ hβJ)).trans_eq (by norm_num))
    εxRun_le
    (eleven_bud_w16r2 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU _ _) hzk

/-- **THE GATE at R13, the media app's profile, at `classifyProtocolU`, through the run's chain** (D63 lane L30): as at
W16R2, with R13's forms (slots `SqForm 7 (7·370)`, define schedules `SqForm 80 (80·451)`, LogUp `e ≤ 2^26`, and the
regular openings at L28's proved figures for the radius `24,448`: `opA` `PowForm 1 110`, `opB` `PowForm 1 126`), the
column test at R13's parameters (`N = 2^16`, `e = 24,448`, `Q = 256`) and the extraction failure at R13's opening
geometry. Eleven kinds, `55,525,211 ≤ 2^26` units. -/
theorem classifyU_productionReady_run_r13 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (tr : (QB Lq → Dig) → ClsStmt Hdr × ClsReceipt → List (TItem × Dig))
    (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : KindRun tr)
    (hℓ : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.RC.ℓ ≤ 2 ^ 21)
    (hnp : ∀ K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K'.np = R.Ps.length + 2)
    (hsl : Ksl.SqForm 7 (7 * 370)) (hM : KM.PowForm 3 106) (hA : KA.PowForm 1 110) (hB : KB.PowForm 1 126)
    (hR₀ : KR₀.SqForm 80 (80 * 451)) (hR₁ : KR₁.SqForm 80 (80 * 451)) (hH₀ : KH₀.SqForm 80 (80 * 451))
    (hH₁ : KH₁.SqForm 80 (80 * 451)) (eL : ℕ) (heL : eL ≤ 2 ^ 26) (hLU : KLU.SqForm eL (3 * eL))
    (Ko : List (KindRun tr)) (hKo : ∀ K' ∈ Ko, K' ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU])
    {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
    [DecidableEq Cl] (RCx : RunChain Lq (ClsStmt Hdr × ClsReceipt)) (htrx : ∀ G o, RCx.chain G o = tr G o)
    (hℓx : RCx.ℓ ≤ 2 ^ 21) (T : XTest F κ μ Cl 16) (hwA : RCx.s < T.aA) (hwB : RCx.s < T.aB)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ 16) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 16)))
    (hUc : CutReads (Exec.Block.absOfC RCx.C) Ux) (hXc : CutReads (Exec.Block.absOfC RCx.C) Xx)
    (pr : ℕ) (hp1 : pr ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ pr) (hF : Fintype.card F = pr ^ 2)
    (hw0 : T.w0 ≤ 2 ^ 61) (hβLR : T.βLR = (1 + (pr : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0))
    (hTe : T.e = 24448) (hTQ : T.nQ = 256) (hβJ : T.βJ = 1)
    (tag : MTag) (C : ChainEnc (ItB Lq) (QB Lq) Dig) (coreOf : ClsStmt Hdr × ClsReceipt → ℕ → List Op × Exec.Block.Core)
    (Vx : ClsStmt Hdr × ClsReceipt → OC (QB Lq) Dig Unit) (nx : ℕ) (hVx : ∀ o, (Vx o).Bounded nx)
    (hnx : nx ≤ 3800000) (rx : ClsStmt Hdr × ClsReceipt → List Dig) (nrx : ℕ) (hrx : ∀ o, (rx o).length ≤ nrx)
    (hnrx : nrx ≤ 2 ^ 99)
    (halive : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      AliveOrd Ko (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hdin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs 0 (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) (k : ℕ) (hk : k < R.Ps.length),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ BlockOn R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (k + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (hdout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr hon.base e).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
      ∃ K' ∈ Ko, ∃ c ∈ K'.cs (R.Ps.length + 1) (A.runLog G).2, EntD K'.RC.W c (tr G (A.run G)))
    (pos : S.Tok → Fin Cin.dR × Fin Cin.n) (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hlink : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) →
      tRem RCx.W ((tr G (A.run G)).take T.aA) = some 0
        ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((tr G (A.run G)).take T.aA))
            (Ux (A.runLog G).2 ((tr G (A.run G)).take T.aA))
        ∧ T.aB ≤ (tr G (A.run G)).length
        ∧ tRem RCx.W ((tr G (A.run G)).take T.aB) = some 0
        ∧ subSt RCx.W (T.cB RCx.W Ux Xx (A.runLog G).2) (tr G (A.run G)))
    (hdzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K' ∈ Ko, K'.Dm (R.Ps.length + 2) (A.runLog G).2 (tr G (A.run G)))
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_runChain R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 tr
    [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 16), (KB, 1), (KR₀, 80 + 80 * 451), (KR₁, 80 + 80 * 451),
      (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)]
    (fun p hp => hℓ p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    (fun p hp => hnp p.1 (List.mem_map_of_mem (f := Prod.fst) hp))
    Ko hKo
    [(xRunA RCx T Ux Xx hwA hUc hXc, 2 ^ 16), (xRunB RCx T Ux Xx hwB hUc hXc, 1)]
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl
      · exact hℓx
      · exact hℓx)
    (EvXR tag Lq h64 C 256 256 256 16 16 12 26 coreOf Vx rx) εxRun
    (fun q A hA => hEx_r13 tag Lq h64 C coreOf Vx nx hVx hnx rx nrx hrx hnrx q A hA)
    halive hdin hdblk hdout pos hplane mk ops hE hops hcan
    (fun A G hv hx hnc => by
      rcases xRun_cover RCx tr htrx T Ux Xx hwA hwB hUc hXc A G (hlink A G hv hx hnc) with hev | hev
      · exact ⟨xRunA RCx T Ux Xx hwA hUc hXc, List.mem_map.mpr ⟨(xRunA RCx T Ux Xx hwA hUc hXc, 2 ^ 16),
          List.mem_append_right _ List.mem_cons_self, rfl⟩, hev⟩
      · exact ⟨xRunB RCx T Ux Xx hwB hUc hXc, List.mem_map.mpr ⟨(xRunB RCx T Ux Xx hwB hUc hXc, 1),
          List.mem_append_right _ (List.mem_cons_of_mem _ List.mem_cons_self), rfl⟩, hev⟩)
    (fun A G hv hx hz => kindEv_of_dm_ord Ko (R.Ps.length + 2)
      (fun K' hK' => hnp K' (hKo K' hK')) _
      (fun K' hK' => kindsFK_mem _ _ K' (hKo K' hK')) A G (halive A G hv hx) (hdzero A G hv hx hz))
    (2 ^ 16 + 2 ^ 18)
    (nine_lin_r13u Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU hsl hM hA hB hR₀ hR₁ hH₀ hH₁ eL heL hLU)
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl
      · exact (xRunA_lin RCx T Ux Xx hwA hUc hXc q 110 (by norm_num)
          (T.εA_r13 pr hp1 hp2 hF hw0 hβLR)).trans_eq (by norm_num)
      · exact (xRunB_lin RCx T Ux Xx hwB hUc hXc q 126 (by norm_num)
          (T.εB_r13 hTe hTQ hβJ).2).trans_eq (by norm_num))
    εxRun_le
    (eleven_bud_r13 Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU _ _) hzk

end Gates

end ZK60.ProtocolClassify
