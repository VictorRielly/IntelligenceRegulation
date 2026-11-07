/-
D63 lane L24 (2026-11-07), part 4: **O11, the classify run's extraction, in the form `ClassifyOpen` names, and the
run's joint form**, from kinds of sub-protocols each counted jointly over the run (`RunExtractKinds.lean`,
`ZoneCodeFirst.lean`), with the deterministic links of the parts as named premises.

What is proved:
* **`classify_O11_of_kinds`**: the four O11 fields of `ClassifyOpen` (O11a stage IN-C, O11b the blocks JOINTLY, O11c
  stage OUT-C for the statement's verdict, O11d the input endpoint), for ANY protocol of the classify model, from four
  lists of kinds and four deterministic covers (accepted and the part's conclusion failing on the extracted data ⇒ the
  Merkle extraction failure or some kind's event). Each bound is `min 1 (εx q + Σ_K (q·εmax_K + B_K + coll))`;
* `ClassifyOpen.withO11`: any `ClassifyOpen` with its O11 fields replaced by these;
* `εKinds_le_u126`, **`four_way_le_target`**, **`classify_productionReady_O11_target`**: the gate at the approved targets
  through `ClassifyOpen` (the four parts summed), when the parts' constants total `≤ 2^26` units of `(q + 1)/2^126`
  (L18's `extract_split_le_target` asks `≤ 2^25` for the blocks and for the rest separately; this asks only the total);
* `JointOk`, `JointExtract`, **`iopExtract_of_joint`**, **`jointExtract_of_kinds`**: the run's extraction as ONE event
  (any part's conclusion failing), covered by ONE list of kinds shared by all parts: each kind pays its prover term and
  its one-sub-protocol constant ONCE for the whole run, not once per part;
* **`classify_productionReady_joint`**, **`classify_productionReady_joint_target`**, `joint_le_target`: the gate through
  the joint extraction, with every `ClassifyOpen` field but O11;
* `joint_budget_w16r2`, `joint_budget_r13`, **`joint_w16r2_target`**, **`joint_r13_target`**: the numbers. W16R2
  (8B T128 per-kind figures of L20/L21): `31,177,585 ≤ 2^25`, within the HALF target for every `q`. R13 (the app's
  profile; LogUp `e ≤ 2^26`, `opB ≤ 2^-105`): `57,261,913 ≤ 2^26`, within `εsTarget q` for every `q`, but above the
  half target (finding L24-4).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.RunExtractKinds

set_option autoImplicit false
-- As in L18's `ProtocolClassifyComplete.lean`: this linter unfolds `Finset.univ` over the `2^256` digests.
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape BlockPublic BlockSat RunSat i16 i16_eq_of_cast)
open ZK60.Out (OutCSat)

variable {S : BlockShape}

/-! ## O11 in `ClassifyOpen`'s form, from kinds -/

section O11

variable {Lq : ℕ} {Coins : Type}

/-- **O11 for the classify run, in the form `ClassifyOpen` names it** (D63 lane L24). For any protocol `P` of the
classify model and the run's extractor `E`: given, for each part (stage IN-C, the blocks JOINTLY, stage OUT-C for the
statement's verdict, the input endpoint), a list of kinds of sub-protocols on the run's chain and a deterministic cover
(accepted while the part's conclusion fails on `E`'s data ⇒ the extra event `Ex`, the Merkle extraction failure, or
some kind's event), each part's failure is at most `min 1 (εx q + Σ_K (q·εmax_K + B_K + coll))`, every `q`, every
prover. -/
theorem classify_O11_of_kinds (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (Kin Kblk Kout Kep : List (FirstKind Lq (P.Stmt × P.Receipt)))
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hin : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Kin, K.Ev A G)
    (hblk : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Kblk, K.Ev A G)
    (hout : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
        Ex A G ∨ ∃ K ∈ Kout, K.Ev A G)
    (hep : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
        Ex A G ∨ ∃ K ∈ Kep, K.Ev A G) :
    (∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εKinds Kin εx q)
    ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εKinds Kblk εx q)
    ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
        ≤ εKinds Kout εx q)
    ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εKinds Kep εx q) :=
  ⟨fun q A hA => ext_of_kinds_min Kin
      (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
      Ex εx hEx (fun A G hG => hin A G hG.1 hG.2) q A hA,
    fun q A hA => ext_of_kinds_min Kblk
      (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
      Ex εx hEx (fun A G hG => hblk A G hG.1 hG.2) q A hA,
    fun q A hA => ext_of_kinds_min Kout
      (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ OutOk R (P.ypub (A.runLog G).1.1) (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
      Ex εx hEx (fun A G hG => hout A G hG.1 hG.2) q A hA,
    fun q A hA => ext_of_kinds_min Kep
      (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ EpOk P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
      Ex εx hEx (fun A G hG => hep A G hG.1 hG.2) q A hA⟩

end O11

/-! ## `ClassifyOpen` with its O11 fields from kinds, and the gate at the targets -/

section Open

variable {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

omit [DecidableEq K] in
/-- **`ClassifyOpen` with its O11 fields replaced**: every other field of `O` kept, the four extraction bounds those of
`classify_O11_of_kinds` (or any others proved in the fields' form). -/
theorem ClassifyOpen.withO11 {R : ClassifyRunPublic S} {Lq : ℕ} {V : RunV Hdr} {P : RunP Hdr (S.Tok → ℕ) Coins}
    {Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt} {h64 : 64 ≤ Lq} {hr : 8 * Cin.R ≤ Lq} {hon : HonestIn Coins Cin}
    {U : K} {ι : Type} [Fintype ι] {site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K} {kOf : ι → ℕ} {δOf : ι → ℝ≥0∞}
    {E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt}
    {εin εblk εout εep εin' εblk' εout' εep' : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (h : (∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
        prH (fun G => (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2
            = true ∧ ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εin' q)
      ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
        prH (fun G => (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2
            = true ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εblk' q)
      ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
        prH (fun G => (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2
            = true ∧ ¬ OutOk R ((classifyProtocol S R Lq V P Cin h64 hr hon.base).ypub (A.runLog G).1.1)
              (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εout' q)
      ∧ (∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
        prH (fun G => (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2
            = true ∧ ¬ EpOk (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
              (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εep' q)) :
    ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin' εblk' εout' εep' εzk :=
  { O with extIn := h.1, extBlocks := h.2.1, extOut := h.2.2.1, extEp := h.2.2.2 }

end Open

section Budget

variable {Lq : ℕ} {α : Type}

/-- **A part's constant**: the extra event's `cx` and, for every kind with its linear constant `c`, `c + 2^17` (its two
collision terms). -/
def partConst (L : List (FirstKind Lq α × ℕ)) (cx : ℕ) : ℕ :=
  cx + (L.map (fun p => p.2 + 2 ^ 17)).sum

/-- **A list of kinds with their constants**: the sum of their bounds within `(q + 1)·Σ (c + 2^17)/2^126`. -/
theorem kindsP_le_u126 (q : ℕ) (hq : q + 1 ≤ 2 ^ 102) :
    ∀ L : List (FirstKind Lq α × ℕ), (∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) →
      (∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2) →
      ((L.map Prod.fst).map (fun K => K.bnd q)).sum ≤ u126 q (L.map (fun p => p.2 + 2 ^ 17)).sum
  | [], _, _ => by simp
  | p :: L, hℓ, hlin => by
    rw [List.map_cons, List.map_cons, List.sum_cons, List.map_cons, List.sum_cons, ← u126_add]
    exact add_le_add (p.1.bnd_le_u126 q p.2 hq (hℓ p List.mem_cons_self) (hlin p List.mem_cons_self))
      (kindsP_le_u126 q hq L (fun p' h => hℓ p' (List.mem_cons_of_mem _ h))
        (fun p' h => hlin p' (List.mem_cons_of_mem _ h)))

/-- **A part within `(q + 1)·partConst/2^126`** for `q + 1 ≤ 2^102`, kinds of chains of at most `2^21` items with linear
parts `≤ (q + 1)·c/2^126` and the extra event within `(q + 1)·cx/2^126`. -/
theorem εKinds_le_u126 (L : List (FirstKind Lq α × ℕ)) (εx : ℕ → ℝ≥0∞) (cx q : ℕ) (hq : q + 1 ≤ 2 ^ 102)
    (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) (hlin : ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : εx q ≤ u126 q cx) : εKinds (L.map Prod.fst) εx q ≤ u126 q (partConst L cx) := by
  refine (min_le_right _ _).trans ?_
  unfold partConst
  rw [← u126_add]
  exact add_le_add hx (kindsP_le_u126 q hq L hℓ hlin)

/-- **The joint form within the target**: one list of kinds with its extra event, constants totalling `≤ 2^26`: at most
`εsTarget q` for EVERY `q`. -/
theorem joint_le_target (L : List (FirstKind Lq α × ℕ)) (εx : ℕ → ℝ≥0∞) (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21)
    (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 26) (q : ℕ) :
    εKinds (L.map Prod.fst) εx q ≤ εsTarget q := by
  by_cases hq : q + 1 ≤ 2 ^ 102
  · exact (εKinds_le_u126 L εx cx q hq hℓ (hlin q) (hx q hq)).trans (u126_le_target q _ hbud)
  · exact (min_le_left _ _).trans (one_le_εsTarget (by
      have : (2 : ℕ) ^ 100 ≤ 2 ^ 102 := Nat.pow_le_pow_right (by norm_num) (by norm_num)
      omega))

/-- **The same within the half target** `q·2^-101 + 2^-101` when the constants total `≤ 2^25` (L18's
`extract_split_le_target` asks this of the blocks and of the rest). -/
theorem joint_le_half (L : List (FirstKind Lq α × ℕ)) (εx : ℕ → ℝ≥0∞) (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21)
    (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 25) (q : ℕ) :
    εKinds (L.map Prod.fst) εx q ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 := by
  by_cases hq : q + 1 ≤ 2 ^ 102
  · exact (εKinds_le_u126 L εx cx q hq hℓ (hlin q) (hx q hq)).trans (u126_le_half q _ hbud)
  · exact (min_le_left _ _).trans (one_le_half (by
      have : (2 : ℕ) ^ 101 ≤ 2 ^ 102 := Nat.pow_le_pow_right (by norm_num) (by norm_num)
      omega))

/-- **The four parts of `ClassifyOpen` within the target**: each part its own kinds and the extra event counted in each,
the parts' constants totalling `≤ 2^26`: `εin + εblk + εout + εep ≤ εsTarget q` for EVERY `q`. -/
theorem four_way_le_target (Lin Lblk Lout Lep : List (FirstKind Lq α × ℕ)) (εx : ℕ → ℝ≥0∞) (cx : ℕ)
    (hℓ : ∀ p ∈ Lin ++ Lblk ++ Lout ++ Lep, p.1.ℓ ≤ 2 ^ 21)
    (hlin : ∀ q : ℕ, ∀ p ∈ Lin ++ Lblk ++ Lout ++ Lep, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx)
    (hbud : partConst Lin cx + partConst Lblk cx + partConst Lout cx + partConst Lep cx ≤ 2 ^ 26) (q : ℕ) :
    εKinds (Lin.map Prod.fst) εx q + εKinds (Lblk.map Prod.fst) εx q + εKinds (Lout.map Prod.fst) εx q
      + εKinds (Lep.map Prod.fst) εx q ≤ εsTarget q := by
  by_cases hq : q + 1 ≤ 2 ^ 102
  · have h1 := εKinds_le_u126 Lin εx cx q hq (fun p hp => hℓ p (by simp [hp]))
      (fun p hp => hlin q p (by simp [hp])) (hx q hq)
    have h2 := εKinds_le_u126 Lblk εx cx q hq (fun p hp => hℓ p (by simp [hp]))
      (fun p hp => hlin q p (by simp [hp])) (hx q hq)
    have h3 := εKinds_le_u126 Lout εx cx q hq (fun p hp => hℓ p (by simp [hp]))
      (fun p hp => hlin q p (by simp [hp])) (hx q hq)
    have h4 := εKinds_le_u126 Lep εx cx q hq (fun p hp => hℓ p (by simp [hp]))
      (fun p hp => hlin q p (by simp [hp])) (hx q hq)
    calc _ ≤ u126 q (partConst Lin cx) + u126 q (partConst Lblk cx) + u126 q (partConst Lout cx)
          + u126 q (partConst Lep cx) := add_le_add (add_le_add (add_le_add h1 h2) h3) h4
      _ = u126 q (partConst Lin cx + partConst Lblk cx + partConst Lout cx + partConst Lep cx) := by
          rw [u126_add, u126_add, u126_add]
      _ ≤ εsTarget q := u126_le_target q _ hbud
  · refine le_trans ?_ (four_le_target (q := q) (by omega))
    calc _ ≤ (1 : ℝ≥0∞) + 1 + 1 + 1 :=
          add_le_add (add_le_add (add_le_add (min_le_left _ _) (min_le_left _ _)) (min_le_left _ _))
            (min_le_left _ _)
      _ = 4 := by norm_num

end Budget

section Gate

variable {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at the approved targets through `ClassifyOpen`, O11 from kinds** (D63 lane L24): every field of
`ClassifyOpen` but O11 (from `O`, whatever its extraction bounds), the four parts' kinds with their constants and
covers (`classify_O11_of_kinds`), the zero-knowledge bound within `εzkTarget`, and the parts' constants totalling
`≤ 2^26`: `ProductionReady … εcTarget εsTarget εsTarget εzkTarget`. -/
theorem classify_productionReady_O11_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (Lin Lblk Lout Lep : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Lin.map Prod.fst, K.Ev A G)
    (hblk : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Lblk.map Prod.fst, K.Ev A G)
    (hout : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ OutOk R ((classifyProtocol S R Lq V P Cin h64 hr hon.base).ypub (A.runLog G).1.1)
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Lout.map Prod.fst, K.Ev A G)
    (hep : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EpOk (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ Lep.map Prod.fst, K.Ev A G)
    (cx : ℕ) (hℓ : ∀ p ∈ Lin ++ Lblk ++ Lout ++ Lep, p.1.ℓ ≤ 2 ^ 21)
    (hlin : ∀ q : ℕ, ∀ p ∈ Lin ++ Lblk ++ Lout ++ Lep, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx)
    (hbud : partConst Lin cx + partConst Lblk cx + partConst Lout cx + partConst Lep cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget :=
  productionReady_mono
    (classify_productionReady R Lq V P Cin h64 hr hon U hbij site kOf δOf E
      (O.withO11 (classify_O11_of_kinds R (classifyProtocol S R Lq V P Cin h64 hr hon.base) E (Lin.map Prod.fst)
        (Lblk.map Prod.fst) (Lout.map Prod.fst) (Lep.map Prod.fst) Ex εx hEx hin hblk hout hep)))
    le_rfl (four_way_le_target Lin Lblk Lout Lep εx cx hℓ hlin hx hbud) (fun _ => le_rfl) hzk

end Gate

/-! ## The run's extraction as ONE event: the joint form -/

section Joint

variable {Lq : ℕ} {Coins : Type}

/-- **Every part's conclusion on the extracted data** (stage IN-C, the blocks, stage OUT-C for the statement's verdict,
the input endpoint). -/
def JointOk (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R)) (G : QB Lq → Dig)
    (s : P.Stmt) (e : RunExt S P.Salt) : Prop :=
  InOk R e ∧ BlocksOk R e ∧ OutOk R (P.ypub s) e ∧ EpOk P G s e

/-- **The run's extraction premise as ONE event**: one extractor; accepted while ANY part's conclusion fails, at most
`εs q`. (`RunExtract` asks four bounds and `iopExtract_of_runExtract` adds them.) -/
def JointExtract (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (εs : ℕ → ℝ≥0∞) : Prop :=
  ∃ E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt,
    ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q →
      prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
          ∧ ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εs q

/-- **`IOPExtract` from the joint extraction premise**: as `iopExtract_of_runExtract`, with the four parts in one event,
so the bound is the joint one (not a sum of four). -/
theorem iopExtract_of_joint (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (hopenOut : ∀ G s y r, P.opensOut G s y r) (hpos : 0 < R.Ps.length) {εs : ℕ → ℝ≥0∞}
    (hX : JointExtract R P εs) : IOPExtract (classifyModel S R) (classifyArith S R) P εs := by
  obtain ⟨E, hE⟩ := hX
  refine ⟨fun lg s pf => ((fun t => canonWord ((E lg s pf).epW t)), P.ypub s, (), (E lg s pf).r, (E lg s pf).r'),
    fun W q A hA => ?_⟩
  have hW : W = () := rfl
  subst hW
  refine le_trans (prH_mono (B := fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ?_) (hE q A hA)
  intro G hG
  obtain ⟨hver, hbad⟩ := hG
  refine ⟨hver, fun hall => ?_⟩
  obtain ⟨hin, hblk, hout, hep⟩ := hall
  obtain ⟨hInSat, hepw⟩ := hin
  obtain ⟨hb1, hOut, hio⟩ := hout
  exact hbad (classify_inner_of_stages R P G (A.runLog G).1.1
    (boundaryFrame (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes R.Ps.length)
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).tokW (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).epW
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).xC (P.ypub (A.runLog G).1.1) hb1
    (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r'
    hInSat (runOn_of_blocks R.Ps (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes hpos hblk)
    hOut hio hepw hep rfl (hopenOut _ _ _ _))

/-- **The joint extraction from ONE list of kinds shared by all parts** (D63 lane L24): accepted while any part's
conclusion fails ⇒ the extra event or some kind's event; at most `min 1 (εx q + Σ_K (q·εmax_K + B_K + coll))`. Each
kind holds its sub-protocols of EVERY part, so it pays its prover term and its one-sub-protocol constant once. -/
theorem jointExtract_of_kinds (R : ClassifyRunPublic S) (P : Protocol (QB Lq) Dig Coins (classifyModel S R))
    (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (Ks : List (FirstKind Lq (P.Stmt × P.Receipt)))
    (Ex : OC (QB Lq) Dig (P.Stmt × P.Receipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig (P.Stmt × P.Receipt)) (G : QB Lq → Dig),
      P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) →
        Ex A G ∨ ∃ K ∈ Ks, K.Ev A G) :
    JointExtract R P (εKinds Ks εx) :=
  ⟨E, fun q A hA => ext_of_kinds_min Ks
    (fun A G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ JointOk R P G (A.runLog G).1.1 (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
    Ex εx hEx (fun A G hG => hcover A G hG.1 hG.2) q A hA⟩

end Joint

section JointGate

variable {Hdr Salt Coins : Type} [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE through the joint extraction** (D63 lane L24): every `ClassifyOpen` field but O11 (taken from `O`,
whatever its extraction bounds), and the joint extraction premise at `εs`:
`ProductionReady … εcTarget εs εsTarget εzk`. -/
theorem classify_productionReady_joint (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) {εs : ℕ → ℝ≥0∞}
    (hJ : JointExtract R (classifyProtocol S R Lq V P Cin h64 hr hon.base) εs) :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εs εsTarget εzk := by
  have hR : R.Valid := ⟨O.inPub, O.weights, O.outPub⟩
  obtain ⟨hokC, hN, hroot, hdep⟩ := O.commit
  have : Subsingleton (classifyModel S R).HidOut := inferInstanceAs (Subsingleton Unit)
  exact productionReady_of (classifyRun_circuitIff O.shape R hR)
    (iopExtract_of_joint R _ (fun _ _ _ _ => trivial) O.blocks.1 hJ)
    (classify_complete_target R hR Lq V P Cin h64 hr hon hokC hN hroot O.policy.1 O.policy.2 O.parts U hbij site kOf
      O.counts.1 δOf O.counts.2.1 O.counts.2.2.1 O.counts.2.2.2 O.refuse)
    (binding_classifier_target (classifyProtocol S R Lq V P Cin h64 hr hon.base) Cin h64 hr
      (fun G s x r => opensIn_iff R Lq V P Cin h64 hr hon.base G s x r) hdep)
    O.zk

/-- **THE GATE at the approved targets through the joint extraction, from ONE list of kinds** (D63 lane L24): every
`ClassifyOpen` field but O11, the shared kinds with their constants and the one cover, the constants totalling
`≤ 2^26` and the zero-knowledge bound within `εzkTarget`: `ProductionReady … εcTarget εsTarget εsTarget εzkTarget`. -/
theorem classify_productionReady_joint_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk)
    (L : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hcover : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocol S R Lq V P Cin h64 hr hon.base).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ JointOk R (classifyProtocol S R Lq V P Cin h64 hr hon.base) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G)
    (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocol S R Lq V P Cin h64 hr hon.base)
      εcTarget εsTarget εsTarget εzkTarget :=
  productionReady_mono
    (classify_productionReady_joint R Lq V P Cin h64 hr hon U hbij site kOf δOf E O
      (jointExtract_of_kinds R (classifyProtocol S R Lq V P Cin h64 hr hon.base) E (L.map Prod.fst) Ex εx hEx hcover))
    le_rfl (joint_le_target L εx cx hℓ hlin hx hbud) (fun _ => le_rfl) hzk

end JointGate

/-! ## The numbers: W16R2 and R13 -/

section Numbers

variable {Lq : ℕ} {α : Type}

/-- The constant of nine kinds. -/
theorem partConst_nine (K₁ K₂ K₃ K₄ K₅ K₆ K₇ K₈ K₉ : FirstKind Lq α) (c₁ c₂ c₃ c₄ c₅ c₆ c₇ c₈ c₉ cx : ℕ) :
    partConst [(K₁, c₁), (K₂, c₂), (K₃, c₃), (K₄, c₄), (K₅, c₅), (K₆, c₆), (K₇, c₇), (K₈, c₈), (K₉, c₉)] cx
      = cx + ((c₁ + 2 ^ 17) + (c₂ + 2 ^ 17) + (c₃ + 2 ^ 17) + (c₄ + 2 ^ 17) + (c₅ + 2 ^ 17) + (c₆ + 2 ^ 17)
        + (c₇ + 2 ^ 17) + (c₈ + 2 ^ 17) + (c₉ + 2 ^ 17)) := by
  simp only [partConst, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
  ring

/-- **W16R2's joint budget** (8B T128 per-kind figures of L20/L21, in units of `(q + 1)/2^126`), nine kinds and the
Merkle extraction failure: the slots `5 + 924`; `M` `3·2^20` (`≤ 2^-106` per round, three rounds); the openings' `opA`
`2^15` (`≤ 2^-111`) and `opB` `2^13` (`≤ 2^-113`); four define schedules `80 + 80·351` each; LogUp `26,370,000`
(`e ≤ 35,153,256`, three squeezes); each kind's two collision terms `2^17`; the extraction failure `2^16 + 2^18`.
Total `31,177,585 ≤ 2^25`. -/
theorem joint_budget_w16r2 :
    (2 ^ 16 + 2 ^ 18) + ((5 + 924 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)
      + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17)
      + (26370000 + 2 ^ 17)) ≤ 2 ^ 25 := by norm_num

/-- **R13's joint budget** (the app's profile, Shieldstral T128), the same nine kinds: the slots `7 + 7·370`; `M`
`3·2^20`; `opA` `2^15`; `opB` `2^21` (`≤ 2^-105`, the δ/3 count, L20's `opB_eps_r13`); four define schedules
`80 + 80·451` each (451 draws, L17); LogUp `50,331,700` (`e ≤ 2^26`); collision terms; the extraction failure.
Total `57,261,913 ≤ 2^26`. -/
theorem joint_budget_r13 :
    (2 ^ 16 + 2 ^ 18) + ((7 + 7 * 370 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 21 + 2 ^ 17)
      + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17)
      + (50331700 + 2 ^ 17)) ≤ 2 ^ 26 := by norm_num

/-- **R13's joint constant is above the half target's `2^25`** (finding L24-4): with L21's LogUp count the blocks alone
miss L18's `extract_split_le_target` split at R13. -/
theorem joint_budget_r13_over_half :
    2 ^ 25 < (2 ^ 16 + 2 ^ 18) + ((7 + 7 * 370 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17)
      + (2 ^ 21 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17)
      + (80 + 80 * 451 + 2 ^ 17) + (50331700 + 2 ^ 17)) := by norm_num

/-- **The joint form at W16R2, within the HALF target for every `q`** (D63 lane L24): nine kinds (the slots, `M`, the
openings' `opA` and `opB`, four define schedules, LogUp), each holding its sub-protocols of every part of the run, with
their linear parts at L20/L21's W16R2 figures, chains of at most `2^21` items, and the Merkle extraction failure within
`(q + 1)·(2^16 + 2^18)/2^126`: `εKinds ≤ q·2^-101 + 2^-101` (so also `≤ εsTarget q`). -/
theorem joint_w16r2_target (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : FirstKind Lq α) (εx : ℕ → ℝ≥0∞)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.ℓ ≤ 2 ^ 21)
    (hsl : ∀ q : ℕ, (q : ℝ≥0∞) * Ksl.εmax + Ksl.B ≤ u126 q (5 + 924))
    (hM : ∀ q : ℕ, (q : ℝ≥0∞) * KM.εmax + KM.B ≤ u126 q (3 * 2 ^ 20))
    (hA : ∀ q : ℕ, (q : ℝ≥0∞) * KA.εmax + KA.B ≤ u126 q (2 ^ 15))
    (hB : ∀ q : ℕ, (q : ℝ≥0∞) * KB.εmax + KB.B ≤ u126 q (2 ^ 13))
    (hR₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₀.εmax + KR₀.B ≤ u126 q (80 + 80 * 351))
    (hR₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₁.εmax + KR₁.B ≤ u126 q (80 + 80 * 351))
    (hH₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₀.εmax + KH₀.B ≤ u126 q (80 + 80 * 351))
    (hH₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₁.εmax + KH₁.B ≤ u126 q (80 + 80 * 351))
    (hLU : ∀ q : ℕ, (q : ℝ≥0∞) * KLU.εmax + KLU.B ≤ u126 q 26370000)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q (2 ^ 16 + 2 ^ 18)) (q : ℕ) :
    εKinds [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU] εx q
      ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 := by
  have h := joint_le_half [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351),
    (KR₁, 80 + 80 * 351), (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000)] εx (2 ^ 16 + 2 ^ 18)
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact hℓ _ (by simp))
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · exact hsl q
      · exact hM q
      · exact hA q
      · exact hB q
      · exact hR₀ q
      · exact hR₁ q
      · exact hH₀ q
      · exact hH₁ q
      · exact hLU q)
    hx (by rw [partConst_nine]; exact joint_budget_w16r2) q
  simpa only [List.map_cons, List.map_nil] using h

/-- **The joint form at R13 (the app's profile), within `εsTarget q` for every `q`** (D63 lane L24): the same nine kinds
at R13's figures (`opB ≤ 2^-105`, the δ/3 count; LogUp `e ≤ 2^26`; 451 define draws, 370 slot rounds of degree
`≤ 7`). -/
theorem joint_r13_target (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU : FirstKind Lq α) (εx : ℕ → ℝ≥0∞)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU], K.ℓ ≤ 2 ^ 21)
    (hsl : ∀ q : ℕ, (q : ℝ≥0∞) * Ksl.εmax + Ksl.B ≤ u126 q (7 + 7 * 370))
    (hM : ∀ q : ℕ, (q : ℝ≥0∞) * KM.εmax + KM.B ≤ u126 q (3 * 2 ^ 20))
    (hA : ∀ q : ℕ, (q : ℝ≥0∞) * KA.εmax + KA.B ≤ u126 q (2 ^ 15))
    (hB : ∀ q : ℕ, (q : ℝ≥0∞) * KB.εmax + KB.B ≤ u126 q (2 ^ 21))
    (hR₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₀.εmax + KR₀.B ≤ u126 q (80 + 80 * 451))
    (hR₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₁.εmax + KR₁.B ≤ u126 q (80 + 80 * 451))
    (hH₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₀.εmax + KH₀.B ≤ u126 q (80 + 80 * 451))
    (hH₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₁.εmax + KH₁.B ≤ u126 q (80 + 80 * 451))
    (hLU : ∀ q : ℕ, (q : ℝ≥0∞) * KLU.εmax + KLU.B ≤ u126 q 50331700)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q (2 ^ 16 + 2 ^ 18)) (q : ℕ) :
    εKinds [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU] εx q ≤ εsTarget q := by
  have h := joint_le_target [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 21), (KR₀, 80 + 80 * 451),
    (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700)] εx (2 ^ 16 + 2 ^ 18)
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact hℓ _ (by simp))
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · exact hsl q
      · exact hM q
      · exact hA q
      · exact hB q
      · exact hR₀ q
      · exact hR₁ q
      · exact hH₀ q
      · exact hH₁ q
      · exact hLU q)
    hx (by rw [partConst_nine]; exact joint_budget_r13) q
  simpa only [List.map_cons, List.map_nil] using h

end Numbers

end ZK60.ProtocolClassify
