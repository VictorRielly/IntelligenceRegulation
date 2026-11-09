/-
D63 lane L26 (2026-11-07), part 5: **O11d, the input endpoint's extraction, at `classifyProtocolU`**, in the two forms
the gate takes (`ClassifyOpen`'s separate bound, L24's joint cover), and **the gate re-assembled** with O11d
discharged from the endpoint's column test (`BindingUTest.lean`) and the decoding link (`BindingUDecode.lean`).

* `ChainU`, `StabU`, **`FirstKind.singleU`**, `FirstKind.singleU_ev`: a kind with ONE sub-protocol on the run's chain
  (L24's `FirstKind` with its soundness fields discharged from the sub-protocol's own round-by-round bound);
* `XTest`, `XTest.εA`, `XTest.εB`, **`xKindA`**, **`xKindB`**, **`xKinds_cover`**: the endpoint's column test as two
  kinds (its halves at `opA`'s and `opB`'s windows) and its split: the test's chain event lies in one of them;
* `exX`, `exU` (`BindingUDecode.lean`): the columns that open and the extracted matrix, read off the extractor's
  openings;
* **`epCoverU`**: accepted while the endpoint's conclusion (`EpOk` at `classifyProtocolU`: the input commitment opens
  at radius `e` to the extracted words) fails ⇒ the Merkle extraction failure, or the column test's event (the matrix
  not close inside the columns that open), or the decoded endpoint plane not vanishing off the token positions;
* **`classifyU_O11d`**: O11d in `ClassifyOpen`'s form for `classifyProtocolU`: at most `εKinds Ks εx q`;
* **`classifyU_productionReady_ep_target`**: the gate at the approved targets at `classifyProtocolU`, through the joint
  extraction, with the endpoint's part of the cover DISCHARGED (`jointCover_of_parts`, `epCoverU`);
* the numbers: `partConst_eleven`, `jointU_budget_w16r2` (`31,480,689 ≤ 2^25`), `jointU_budget_r13`
  (`57,589,594 ≤ 2^26`), **`jointU_w16r2_target`**, **`jointU_r13_target`**: L24's nine kinds and the test's two;
* `xKindA_lin`, `xKindB_lin`, `XTest.εA_w16r2`, `XTest.εA_r13`, `XTest.εB_w16r2`, `XTest.εB_r13`: the test's two kinds
  at their constants (the premises `hxA`, `hxB` of the two targets, from the test's parameters).

Every premise is an explicit hypothesis.
-/
import ZK60Formal.ProtocolClassifyU
import ZK60Formal.BindingUDecode

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX Code
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-! ## A kind with one sub-protocol -/

section Single

variable {Lq : ℕ} {α : Type}

/-- **The run's chain**: the fields of L24's `FirstKind` that describe the chain (its encoding, step parse, heads and
bounds), shared by every kind. -/
structure ChainU (Lq : ℕ) (α : Type) : Type 1 where
  It : Type
  W : UInt64 → ℕ
  hW : ∀ k, 0 < W k
  C : ChainEnc It (QB Lq) Dig
  toT : It → TItem
  S : Steps It
  hS : StepsOK W toT S
  heads : α → List It
  ℓ : ℕ
  hℓ : ∀ o, ((heads o).flatMap S.items).length ≤ ℓ
  s : ℕ
  hhd : ∀ o, (((heads o).take s).flatMap S.items).length ≤ s

/-- The run's chain at an oracle, for a prover's output. -/
noncomputable def ChainU.chain (D : ChainU Lq α) (G : QB Lq → Dig) (o : α) : List (TItem × Dig) :=
  cChain D.C D.toT D.S G (D.heads o)

/-- **The first-doom state's stability at the escaping step** for a one-sub-protocol schedule (L24's `hstab` field,
L24-2's weak form). -/
def StabU (D : ChainU Lq α) (c : List (QB Lq × Dig) → CSub Dig) : Prop :=
  ∀ (A : OC (QB Lq) Dig α) (H : QB Lq → Dig) (L : List (QB Lq × Dig)) (t : ℕ) (τ : List (D.It × Dig))
    (qs : List (QB Lq)) (it : D.It) (e2 : Dig),
    D.C.Chain H τ qs → D.s ≤ τ.length → (∃ hs : List D.It, τ.map Prod.fst = hs.flatMap D.S.items) →
    (∀ z ∈ qs, z ∈ (L.take t).map Prod.fst) → (∀ e ∈ L, e.2 = H e.1) →
    L[t]? = some (D.C.link (D.C.lastD H τ) it, e2) → D.C.link (D.C.lastD H τ) it ∉ (L.take t).map Prod.fst →
    ∀ ext : List (D.It × Dig), (ext = [] ∨ ∃ ds, ext = D.S.ents it ds) →
      ∀ τ' : List (TItem × Dig), τ' <+: (τ ++ ext).map (toTE D.toT) →
        (firstSt D.W [c (proverLog A (L.take t))] τ' ↔ firstSt D.W [c (proverLog A L)] τ')

/-- **A kind with ONE sub-protocol** (D63 lane L26): L24's `FirstKind` whose schedule is the single sub-protocol `c`
read at the prover's log; windows in order trivially, the soundness fields from `c`'s own round-by-round bound. -/
noncomputable def FirstKind.singleU (D : ChainU Lq α) (c : List (QB Lq × Dig) → CSub Dig) (εmax : ℝ≥0∞)
    (hR : ∀ P, RbrWide (c P).R.n (c P).R.w (c P).St (c P).ε) (hε : ∀ P, (c P).ε ≤ εmax)
    (hnorel : ∀ P τ, ¬ (c P).rel τ) (B : ℝ≥0∞) (hB : ∀ P, ((c P).R.n : ℝ≥0∞) * (c P).ε ≤ B)
    (hwin : ∀ P, D.s < (c P).a) (hstab : StabU D c) : FirstKind Lq α where
  It := D.It
  W := D.W
  hW := D.hW
  C := D.C
  toT := D.toT
  S := D.S
  hS := D.hS
  heads := D.heads
  ℓ := D.ℓ
  hℓ := D.hℓ
  s := D.s
  hhd := D.hhd
  cs P := [c P]
  hsort P := by
    intro i j ci cj hij _ hj
    match j, hj with
    | 0, _ => exact absurd hij (Nat.not_lt_zero _)
    | k + 1, hj => simp at hj
  εmax := εmax
  hR P c' hc' := by
    rw [List.mem_singleton.mp hc']
    exact hR P
  hε P c' hc' := by
    rw [List.mem_singleton.mp hc']
    exact hε P
  hnorel P c' hc' τ := by
    rw [List.mem_singleton.mp hc']
    exact hnorel P τ
  B := B
  hB P c' hc' := by
    rw [List.mem_singleton.mp hc']
    exact hB P
  hwin P c' hc' := by
    rw [List.mem_singleton.mp hc']
    exact hwin P
  hstab := hstab

/-- **The one-sub-protocol kind's event**: its sub-protocol entered its window doomed and is alive at the end. -/
theorem FirstKind.singleU_ev (D : ChainU Lq α) (c : List (QB Lq × Dig) → CSub Dig) (εmax : ℝ≥0∞)
    (hR : ∀ P, RbrWide (c P).R.n (c P).R.w (c P).St (c P).ε) (hε : ∀ P, (c P).ε ≤ εmax)
    (hnorel : ∀ P τ, ¬ (c P).rel τ) (B : ℝ≥0∞) (hB : ∀ P, ((c P).R.n : ℝ≥0∞) * (c P).ε ≤ B)
    (hwin : ∀ P, D.s < (c P).a) (hstab : StabU D c) (A : OC (QB Lq) Dig α) (G : QB Lq → Dig)
    (h : EntD D.W (c (A.runLog G).2) (D.chain G (A.run G)) ∧ subSt D.W (c (A.runLog G).2) (D.chain G (A.run G))) :
    (FirstKind.singleU D c εmax hR hε hnorel B hB hwin hstab).Ev A G :=
  ⟨⟨0, c (A.runLog G).2, rfl, h.1⟩, (allSt_singleton _ _ _).mpr h.2⟩

end Single

/-! ## The endpoint's column test as two kinds -/

section XKinds

variable {Lq : ℕ} {α : Type}

/-- **The endpoint's column test, its parameters** (the opening's encoder and code facts at the radius `e`, the
`(λ, ρ)` and index derivations with their biases, the labels, the two windows). -/
structure XTest (F κ μ Cl : Type) [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
    [DecidableEq Cl] (h : ℕ) where
  enc : (μ → F) →ₗ[F] (Fin (2 ^ h) → F)
  d : ℕ
  e : ℕ
  A : ℕ
  hd : MinDist (LinearMap.range enc) d
  h2 : 2 * e < d
  hA : e + 1 ≤ A
  hAN : A ≤ 2 ^ h
  hca : CAOn Unit (LinearMap.range enc) e A
  d₀ : Dg
  w0 : ℕ
  chalLR : (Fin w0 → Dg) → (Cl → F) × (κ → F)
  βLR : ℝ≥0∞
  hLR : ∀ Ev : (Cl → F) × (κ → F) → Prop, (PMF.uniformOfFintype (Fin w0 → Dg)).toOuterMeasure {b | Ev (chalLR b)}
    ≤ (PMF.uniformOfFintype ((Cl → F) × (κ → F))).toOuterMeasure {y | Ev y} * βLR
  m : ℕ
  nQ : ℕ
  chalJ : (Fin m → Dg) → (Fin nQ → Fin (2 ^ h))
  βJ : ℝ≥0∞
  hJ : ∀ Ev : (Fin nQ → Fin (2 ^ h)) → Prop, (PMF.uniformOfFintype (Fin m → Dg)).toOuterMeasure {b | Ev (chalJ b)}
    ≤ (PMF.uniformOfFintype (Fin nQ → Fin (2 ^ h))).toOuterMeasure {J | Ev J} * βJ
  labB : List UInt8
  decB : List UInt8 → Option (μ → F)
  aA : ℕ
  aB : ℕ
  hab : aA ≤ aB

variable {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
  [DecidableEq Cl] {h : ℕ}

/-- The first half's error `N/|F|·βLR`. -/
noncomputable def XTest.εA (T : XTest F κ μ Cl h) : ℝ≥0∞ := ((2 ^ h : ℕ) : ℝ≥0∞) / Fintype.card F * T.βLR

/-- The second half's error `((N − (e + 1))/N)^Q·βJ`. -/
noncomputable def XTest.εB (T : XTest F κ μ Cl h) : ℝ≥0∞ :=
  (((Fintype.card (Fin (2 ^ h)) - (T.e + 1) : ℕ) : ℝ≥0∞) / Fintype.card (Fin (2 ^ h))) ^ T.nQ * T.βJ

/-- The first half on the code's chain, for the extraction `Ux`, `Xx` at the prover's log `P`. -/
noncomputable def XTest.cA (T : XTest F κ μ Cl h) (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (P : List (QB Lq × Dig)) : CSub Dig :=
  xACSub T.enc T.e (Ux P) (Xx P) T.d₀ T.w0 T.chalLR T.aA T.εA

/-- The second half on the code's chain. -/
noncomputable def XTest.cB (T : XTest F κ μ Cl h) (W : UInt64 → ℕ)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (P : List (QB Lq × Dig)) : CSub Dig :=
  xBCSub W T.aA T.w0 T.enc T.e (Ux P) (Xx P) T.d₀ T.chalLR T.m T.chalJ T.labB T.decB T.aB T.εB

/-- **The column test's first half as a kind** (one sub-protocol; error `N/|F|·βLR`, one round). -/
noncomputable def xKindA (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : D.s < T.aA)
    (hstab : StabU D (T.cA Ux Xx)) : FirstKind Lq α :=
  FirstKind.singleU D (T.cA Ux Xx) T.εA
    (fun P => xACSub_rbr T.enc T.hd T.h2 T.hA T.hAN T.hca (Ux P) (Xx P) T.d₀ T.w0 T.chalLR T.βLR T.hLR T.aA)
    (fun _ => le_rfl) (fun _ _ hf => hf) T.εA
    (fun _ => by simp [XTest.cA, xACSub, toCSub, opARounds]) (fun _ => hwin) hstab

/-- **The column test's second half as a kind** (one sub-protocol; error `((N − (e + 1))/N)^Q·βJ`, one round). -/
noncomputable def xKindB (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : D.s < T.aB)
    (hstab : StabU D (T.cB D.W Ux Xx)) : FirstKind Lq α :=
  FirstKind.singleU D (T.cB D.W Ux Xx) T.εB
    (fun P => xBCSub_rbr D.W T.aA T.w0 T.enc T.e (Ux P) (Xx P) T.d₀ T.chalLR T.m T.chalJ T.βJ T.hJ T.labB T.decB T.aB)
    (fun _ => le_rfl) (fun _ _ hf => hf) T.εB
    (fun _ => by simp [XTest.cB, xBCSub, toCSub, opBRounds]) (fun _ => hwin) hstab

/-- **The column test's chain event lies in one of its two kinds** (D63 lane L26; `x_split`): the first half's window
at a step's end with the matrix NOT close inside the openable set, the second half's window in the chain at a step's
end and the second half alive at the end ⇒ the first kind's event or the second's. -/
theorem xKinds_cover (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwA : D.s < T.aA) (hwB : D.s < T.aB)
    (hsA : StabU D (T.cA Ux Xx)) (hsB : StabU D (T.cB D.W Ux Xx)) (A : OC (QB Lq) Dig α) (G : QB Lq → Dig)
    (hX : tRem D.W ((D.chain G (A.run G)).take T.aA) = some 0
      ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((D.chain G (A.run G)).take T.aA))
          (Ux (A.runLog G).2 ((D.chain G (A.run G)).take T.aA))
      ∧ T.aB ≤ (D.chain G (A.run G)).length
      ∧ tRem D.W ((D.chain G (A.run G)).take T.aB) = some 0
      ∧ subSt D.W (T.cB D.W Ux Xx (A.runLog G).2) (D.chain G (A.run G))) :
    (xKindA D T Ux Xx hwA hsA).Ev A G ∨ (xKindB D T Ux Xx hwB hsB).Ev A G := by
  obtain ⟨hA1, hng, hB0, hB1, hBal⟩ := hX
  rcases x_split D.W T.aA T.aB T.hab T.enc T.e (Ux (A.runLog G).2) (Xx (A.runLog G).2) T.d₀ T.w0 T.chalLR T.m T.chalJ
      T.labB T.decB T.εA T.εB (D.chain G (A.run G)) hA1 hB0 with hAal | hBd
  · left
    exact FirstKind.singleU_ev D _ _ _ _ _ _ _ _ _ A G ⟨⟨le_trans T.hab hB0, hA1, hng⟩, hAal⟩
  · right
    exact FirstKind.singleU_ev D _ _ _ _ _ _ _ _ _ A G ⟨⟨hB0, hB1, hBd⟩, hBal⟩

/-- **The column test's premise from its two kinds** (D63 lane L26): if, under a condition `Pre` (in use: accepted,
no extraction failure, the extracted matrix not close inside the columns that open), the test's chain event holds
(`hlink`: the run's chain link of the endpoint opening, its windows at steps' ends, its second half alive at the end,
and the reading of the extraction at its windows), then under `Pre` some kind of any list holding the test's two kinds
has its event. -/
theorem cover_of_xKinds (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwA : D.s < T.aA) (hwB : D.s < T.aB)
    (hsA : StabU D (T.cA Ux Xx)) (hsB : StabU D (T.cB D.W Ux Xx)) (Ks : List (FirstKind Lq α))
    (hKA : xKindA D T Ux Xx hwA hsA ∈ Ks) (hKB : xKindB D T Ux Xx hwB hsB ∈ Ks)
    (Pre : OC (QB Lq) Dig α → (QB Lq → Dig) → Prop)
    (hlink : ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Pre A G →
      tRem D.W ((D.chain G (A.run G)).take T.aA) = some 0
      ∧ ¬ CloseIn (LinearMap.range T.enc) T.e (Xx (A.runLog G).2 ((D.chain G (A.run G)).take T.aA))
          (Ux (A.runLog G).2 ((D.chain G (A.run G)).take T.aA))
      ∧ T.aB ≤ (D.chain G (A.run G)).length
      ∧ tRem D.W ((D.chain G (A.run G)).take T.aB) = some 0
      ∧ subSt D.W (T.cB D.W Ux Xx (A.runLog G).2) (D.chain G (A.run G))) :
    ∀ (A : OC (QB Lq) Dig α) (G : QB Lq → Dig), Pre A G → ∃ K ∈ Ks, K.Ev A G := by
  intro A G hP
  rcases xKinds_cover D T Ux Xx hwA hwB hsA hsB A G (hlink A G hP) with hA | hB
  · exact ⟨_, hKA, hA⟩
  · exact ⟨_, hKB, hB⟩

end XKinds

/-! ## The endpoint's cover at `classifyProtocolU` -/

section Endpoint

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-- **The endpoint's cover at `classifyProtocolU`** (D63 lane L26; O11d's deterministic core). Let the input
commitment be a token-words plane (`plane = posPlane pos`, canonical words admissible), let the run's extractor read
the endpoint off the extractor's openings `ops` (its words: the decoded data rows at the token positions, read
canonically; its opening data: built from the decoded rows and the extracted salts and paths, `SaltMk`), and let the
extracted openings verify with canonical columns. Then, accepted while the endpoint's conclusion fails (the commitment
does not open at radius `e` to the extracted words), either the extra event `Ex` holds, or the extracted matrix is not
close inside the columns that open (`hX`'s event: the column test's), or the decoded endpoint plane does not vanish
off the token positions (`hzero`'s event: SIC_IO's identity on the decoded data). -/
theorem epCoverU (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ) (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (pos : S.Tok → Fin Cin.dR × Fin Cin.n)
    (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (Ex Z : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop)
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hX : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) → Z A G)
    (hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → Z A G) :
    ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ EpOk (classifyProtocolU S R Lq V P Cin h64 hr base e) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2) → Ex A G ∨ Z A G := by
  intro A G hv hep
  by_cases hx : Ex A G
  · exact Or.inl hx
  right
  by_cases hcl : CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e
      (exX (ops (A.runLog G).2 (A.runLog G).1.1)) (exU (ops (A.runLog G).2 (A.runLog G).1.1))
  · by_cases hz : ∀ k i, (¬ ∃ t, pos t = (k, i)) →
        (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0
    · exfalso
      apply hep
      obtain ⟨hw, hrr⟩ := hE (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2
      show Cin.OpensU Lq h64 hr e G (A.runLog G).1.1
        (fun t => canonWord ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).epW t))
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).r
      rw [hw, hrr]
      refine Cin.opensU_of_closeIn mk Lq h64 hr e G (A.runLog G).1.1 (ops (A.runLog G).2 (A.runLog G).1.1)
        (hops A G) (hcan _ _) _ (exX_spec _) _ (exU_spec _) hcl _ (hokC _ (fun t => canonWord_lt _)) ?_
      intro k
      rw [hplane]
      exact congrFun (posPlane_eq_of_zero
        (fun k i => (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i) hz) k
    · exact hzero A G hv hx hz
  · exact hX A G hv hx hcl

/-- **O11d at `classifyProtocolU` in `ClassifyOpen`'s form** (D63 lane L26): from `epCoverU`'s premises with the
column test's and the plane's events covered by a list of kinds `Ks` (the test's two kinds, `xKinds_cover`; SIC_IO's
and the endpoint opening's claims), the endpoint's extraction fails, accepted, with probability at most
`min 1 (εx q + Σ_K (q·εmax_K + B_K + coll))`, every `q`, every prover. -/
theorem classifyU_O11d (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ) (hokC : ∀ x, (∀ t, x t < gP) → Cin.ok x) (pos : S.Tok → Fin Cin.dR × Fin Cin.n)
    (hplane : ∀ x, Cin.plane x = posPlane pos x) (mk : Cin.SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin Cin.N → Option (MerkleOpening Dig Dig (ColR Cin.R)))
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => (Cin.decodeIn (ops lg s) e).1 (Cin.place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld (Cin.decodeIn (ops lg s) e).1 (Cin.decodeIn (ops lg s) e).2 (Cin.exSalt (ops lg s))
          (Cin.exPath (ops lg s)))
    (Ks : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt)))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB Cin.tag Lq Cin.R h64 hr).Opens G Cin.depth (Cin.root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    (hX : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ CloseIn (LinearMap.range (encLin (Q := Cin.Q) Cin.pts Cin.form)) e (exX (ops (A.runLog G).2 (A.runLog G).1.1))
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) → ∃ K ∈ Ks, K.Ev A G)
    (hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K ∈ Ks, K.Ev A G) :
    ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
      prH (fun G => (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2
          = true ∧ ¬ EpOk (classifyProtocolU S R Lq V P Cin h64 hr base e) G (A.runLog G).1.1
            (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εKinds Ks εx q :=
  fun q A hA => ext_of_kinds_min Ks
    (fun A G => (classifyProtocolU S R Lq V P Cin h64 hr base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ EpOk (classifyProtocolU S R Lq V P Cin h64 hr base e) G (A.runLog G).1.1
        (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
    Ex εx hEx (fun A G hG => epCoverU R Lq V P Cin h64 hr base e hokC pos hplane mk ops E hE Ex
      (fun A G => ∃ K ∈ Ks, K.Ev A G) hops hcan hX hzero A G hG.1 hG.2) q A hA

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]
variable {K : Type} [Field K] [DecidableEq K] [Algebra GF K]

/-- **THE GATE at `classifyProtocolU` at the approved targets, with O11d DISCHARGED from the endpoint's column test**
(D63 lane L26; L24's joint gate). Every `ClassifyOpen` field but O11, the radius, ONE list of kinds `L` (its constants
`≤ 2^26`), the cover of stage IN-C, the blocks and stage OUT-C (`h3`), and for the endpoint only `epCoverU`'s premises
with their events among `L`'s kinds: `ProductionReady … (classifyProtocolU …) εcTarget εsTarget εsTarget εzkTarget`. -/
theorem classifyU_productionReady_ep_target (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    {ι : Type} [Fintype ι] (site : (S.Tok → ℕ) → ι → Site (QB Lq) Coins K) (kOf : ι → ℕ) (δOf : ι → ℝ≥0∞)
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    {εin εblk εout εep : ℕ → ℝ≥0∞} {εzk : ℕ → ℕ → ℝ≥0∞}
    (O : ClassifyOpen R Lq V P Cin h64 hr hon U site kOf δOf E εin εblk εout εep εzk) (e : ℕ)
    (he : 2 * e + (Cin.n + Cin.Q) ≤ Cin.N) (hN20 : Cin.N ≤ 2 ^ 20)
    (L : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt) × ℕ))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (h3 : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ (InOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)
          ∧ OutOk R ((classifyProtocolU S R Lq V P Cin h64 hr hon.base e).ypub (A.runLog G).1.1)
            (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) →
        Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G)
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
          (exU (ops (A.runLog G).2 (A.runLog G).1.1)) → ∃ K ∈ L.map Prod.fst, K.Ev A G)
    (hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P Cin h64 hr hon.base e).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → (Cin.decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) e).1 (Cin.place k) i = 0)
        → ∃ K ∈ L.map Prod.fst, K.Ev A G)
    (cx : ℕ) (hℓ : ∀ p ∈ L, p.1.ℓ ≤ 2 ^ 21) (hlin : ∀ q : ℕ, ∀ p ∈ L, (q : ℝ≥0∞) * p.1.εmax + p.1.B ≤ u126 q p.2)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q cx) (hbud : partConst L cx ≤ 2 ^ 26)
    (hzk : ∀ q R', εzk q R' ≤ εzkTarget q R') :
    ProductionReady (classifyModel S R) (classifyArith S R) (classifyProtocolU S R Lq V P Cin h64 hr hon.base e)
      εcTarget εsTarget εsTarget εzkTarget :=
  classifyU_productionReady_joint_target R Lq V P Cin h64 hr hon U hbij site kOf δOf E O e he hN20 L Ex εx hEx
    (jointCover_of_parts R (classifyProtocolU S R Lq V P Cin h64 hr hon.base e) E
      (fun A G => Ex A G ∨ ∃ K ∈ L.map Prod.fst, K.Ev A G) h3
      (fun A G hv _ hep => epCoverU R Lq V P Cin h64 hr hon.base e O.commit.1 pos hplane mk ops E hE Ex
        (fun A G => ∃ K ∈ L.map Prod.fst, K.Ev A G) hops hcan hX hzero A G hv hep))
    cx hℓ hlin hx hbud hzk

end Endpoint

/-! ## The numbers: L24's nine kinds and the column test's two -/

section Numbers

variable {Lq : ℕ} {α : Type}

/-- The constant of eleven kinds. -/
theorem partConst_eleven (K₁ K₂ K₃ K₄ K₅ K₆ K₇ K₈ K₉ K₁₀ K₁₁ : FirstKind Lq α)
    (c₁ c₂ c₃ c₄ c₅ c₆ c₇ c₈ c₉ c₁₀ c₁₁ cx : ℕ) :
    partConst [(K₁, c₁), (K₂, c₂), (K₃, c₃), (K₄, c₄), (K₅, c₅), (K₆, c₆), (K₇, c₇), (K₈, c₈), (K₉, c₉),
        (K₁₀, c₁₀), (K₁₁, c₁₁)] cx
      = cx + ((c₁ + 2 ^ 17) + (c₂ + 2 ^ 17) + (c₃ + 2 ^ 17) + (c₄ + 2 ^ 17) + (c₅ + 2 ^ 17) + (c₆ + 2 ^ 17)
        + (c₇ + 2 ^ 17) + (c₈ + 2 ^ 17) + (c₉ + 2 ^ 17) + (c₁₀ + 2 ^ 17) + (c₁₁ + 2 ^ 17)) := by
  simp only [partConst, List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, add_zero]
  ring

/-- **W16R2's joint budget with the endpoint's column test** (D63 lane L26): L24's nine kinds (`joint_budget_w16r2`)
and the test's two halves at `e = 8052`: the first `2^15` (`≤ 2^-111`, `xA_eps_w16r2`), the second `2^13`
(`≤ 2^-113`, `xB_eps_w16r2`), each with its two collision terms. Total `31,480,689 ≤ 2^25`. -/
theorem jointU_budget_w16r2 :
    (2 ^ 16 + 2 ^ 18) + ((5 + 924 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)
      + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17)
      + (26370000 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)) ≤ 2 ^ 25 := by norm_num

/-- **R13's joint budget with the endpoint's column test** (D63 lane L26): L24's nine kinds (`joint_budget_r13`) and the
test's two halves at `e = 24,448`: the first `2^16` (`≤ 2^-110`, `xA_eps_r13`), the second `1` (`≤ 2^-172 ≤ 2^-126`,
`xB_eps_r13`), each with its two collision terms. Total `57,589,594 ≤ 2^26`. -/
theorem jointU_budget_r13 :
    (2 ^ 16 + 2 ^ 18) + ((7 + 7 * 370 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 21 + 2 ^ 17)
      + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17)
      + (50331700 + 2 ^ 17) + (2 ^ 16 + 2 ^ 17) + (1 + 2 ^ 17)) ≤ 2 ^ 26 := by norm_num

/-- The exact totals (the doc's figures). -/
theorem jointU_totals :
    (2 ^ 16 + 2 ^ 18) + ((5 + 924 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)
      + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17) + (80 + 80 * 351 + 2 ^ 17)
      + (26370000 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 13 + 2 ^ 17)) = 31480689
    ∧ (2 ^ 16 + 2 ^ 18) + ((7 + 7 * 370 + 2 ^ 17) + (3 * 2 ^ 20 + 2 ^ 17) + (2 ^ 15 + 2 ^ 17) + (2 ^ 21 + 2 ^ 17)
      + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17) + (80 + 80 * 451 + 2 ^ 17)
      + (50331700 + 2 ^ 17) + (2 ^ 16 + 2 ^ 17) + (1 + 2 ^ 17)) = 57589594 := by norm_num

/-- **The joint form at W16R2 with the endpoint's column test, within the HALF target for every `q`** (D63 lane L26):
L24's nine kinds at L20/L21's W16R2 figures and the test's two kinds at theirs. -/
theorem jointU_w16r2_target (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU KxA KxB : FirstKind Lq α) (εx : ℕ → ℝ≥0∞)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU, KxA, KxB], K.ℓ ≤ 2 ^ 21)
    (hsl : ∀ q : ℕ, (q : ℝ≥0∞) * Ksl.εmax + Ksl.B ≤ u126 q (5 + 924))
    (hM : ∀ q : ℕ, (q : ℝ≥0∞) * KM.εmax + KM.B ≤ u126 q (3 * 2 ^ 20))
    (hA : ∀ q : ℕ, (q : ℝ≥0∞) * KA.εmax + KA.B ≤ u126 q (2 ^ 15))
    (hB : ∀ q : ℕ, (q : ℝ≥0∞) * KB.εmax + KB.B ≤ u126 q (2 ^ 13))
    (hR₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₀.εmax + KR₀.B ≤ u126 q (80 + 80 * 351))
    (hR₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₁.εmax + KR₁.B ≤ u126 q (80 + 80 * 351))
    (hH₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₀.εmax + KH₀.B ≤ u126 q (80 + 80 * 351))
    (hH₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₁.εmax + KH₁.B ≤ u126 q (80 + 80 * 351))
    (hLU : ∀ q : ℕ, (q : ℝ≥0∞) * KLU.εmax + KLU.B ≤ u126 q 26370000)
    (hxA : ∀ q : ℕ, (q : ℝ≥0∞) * KxA.εmax + KxA.B ≤ u126 q (2 ^ 15))
    (hxB : ∀ q : ℕ, (q : ℝ≥0∞) * KxB.εmax + KxB.B ≤ u126 q (2 ^ 13))
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q (2 ^ 16 + 2 ^ 18)) (q : ℕ) :
    εKinds [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU, KxA, KxB] εx q
      ≤ (q : ℝ≥0∞) * (2⁻¹ : ℝ≥0∞) ^ 101 + (2⁻¹ : ℝ≥0∞) ^ 101 := by
  have h := joint_le_half [(Ksl, 5 + 924), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 13), (KR₀, 80 + 80 * 351),
    (KR₁, 80 + 80 * 351), (KH₀, 80 + 80 * 351), (KH₁, 80 + 80 * 351), (KLU, 26370000), (KxA, 2 ^ 15),
    (KxB, 2 ^ 13)] εx (2 ^ 16 + 2 ^ 18)
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact hℓ _ (by simp))
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · exact hsl q
      · exact hM q
      · exact hA q
      · exact hB q
      · exact hR₀ q
      · exact hR₁ q
      · exact hH₀ q
      · exact hH₁ q
      · exact hLU q
      · exact hxA q
      · exact hxB q)
    hx (by rw [partConst_eleven]; exact jointU_budget_w16r2) q
  simpa only [List.map_cons, List.map_nil] using h

/-- **The joint form at R13 with the endpoint's column test, within `εsTarget q` for every `q`** (D63 lane L26):
L24's nine kinds at R13's figures and the test's two kinds at theirs (`e = 24,448`). -/
theorem jointU_r13_target (Ksl KM KA KB KR₀ KR₁ KH₀ KH₁ KLU KxA KxB : FirstKind Lq α) (εx : ℕ → ℝ≥0∞)
    (hℓ : ∀ K ∈ [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU, KxA, KxB], K.ℓ ≤ 2 ^ 21)
    (hsl : ∀ q : ℕ, (q : ℝ≥0∞) * Ksl.εmax + Ksl.B ≤ u126 q (7 + 7 * 370))
    (hM : ∀ q : ℕ, (q : ℝ≥0∞) * KM.εmax + KM.B ≤ u126 q (3 * 2 ^ 20))
    (hA : ∀ q : ℕ, (q : ℝ≥0∞) * KA.εmax + KA.B ≤ u126 q (2 ^ 15))
    (hB : ∀ q : ℕ, (q : ℝ≥0∞) * KB.εmax + KB.B ≤ u126 q (2 ^ 21))
    (hR₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₀.εmax + KR₀.B ≤ u126 q (80 + 80 * 451))
    (hR₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KR₁.εmax + KR₁.B ≤ u126 q (80 + 80 * 451))
    (hH₀ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₀.εmax + KH₀.B ≤ u126 q (80 + 80 * 451))
    (hH₁ : ∀ q : ℕ, (q : ℝ≥0∞) * KH₁.εmax + KH₁.B ≤ u126 q (80 + 80 * 451))
    (hLU : ∀ q : ℕ, (q : ℝ≥0∞) * KLU.εmax + KLU.B ≤ u126 q 50331700)
    (hxA : ∀ q : ℕ, (q : ℝ≥0∞) * KxA.εmax + KxA.B ≤ u126 q (2 ^ 16))
    (hxB : ∀ q : ℕ, (q : ℝ≥0∞) * KxB.εmax + KxB.B ≤ u126 q 1)
    (hx : ∀ q : ℕ, q + 1 ≤ 2 ^ 102 → εx q ≤ u126 q (2 ^ 16 + 2 ^ 18)) (q : ℕ) :
    εKinds [Ksl, KM, KA, KB, KR₀, KR₁, KH₀, KH₁, KLU, KxA, KxB] εx q ≤ εsTarget q := by
  have h := joint_le_target [(Ksl, 7 + 7 * 370), (KM, 3 * 2 ^ 20), (KA, 2 ^ 15), (KB, 2 ^ 21), (KR₀, 80 + 80 * 451),
    (KR₁, 80 + 80 * 451), (KH₀, 80 + 80 * 451), (KH₁, 80 + 80 * 451), (KLU, 50331700), (KxA, 2 ^ 16),
    (KxB, 1)] εx (2 ^ 16 + 2 ^ 18)
    (fun p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> exact hℓ _ (by simp))
    (fun q p hp => by
      simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
      rcases hp with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
      · exact hsl q
      · exact hM q
      · exact hA q
      · exact hB q
      · exact hR₀ q
      · exact hR₁ q
      · exact hH₀ q
      · exact hH₁ q
      · exact hLU q
      · exact hxA q
      · exact hxB q)
    hx (by rw [partConst_eleven]; exact jointU_budget_r13) q
  simpa only [List.map_cons, List.map_nil] using h

/-- **The column test's kinds' linear parts at their forms** (one round, `B = εmax`): `εmax ≤ 2^-j` gives
`q·εmax + B ≤ (q + 1)·2^(126 − j)/2^126` (`lin_kind_le` with one round): at W16R2 `j = 111` (`2^15`) and `j = 113`
(`2^13`), at R13 `j = 110` (`2^16`) and `j = 126` (`1`, from `2^-172`). -/
theorem xKind_lin_le (q j : ℕ) (hj : j ≤ 126) (εmax B : ℝ≥0∞) (hε : εmax ≤ (2⁻¹ : ℝ≥0∞) ^ j) (hB : B ≤ εmax) :
    (q : ℝ≥0∞) * εmax + B ≤ u126 q (1 * 2 ^ (126 - j)) :=
  lin_kind_le q 1 j hj le_rfl εmax B hε (by rw [Nat.cast_one, one_mul]; exact hB)

end Numbers

/-! ## The column test's two kinds at their constants -/

section XKindNumbers

variable {Lq : ℕ} {α : Type}
variable {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
  [DecidableEq Cl] {h : ℕ}

/-- **The first half's kind at its constant**: its `εmax` and its `B` are the half's error `εA` (one round), so
`εA ≤ 2^-j` gives the kind's linear part `≤ (q + 1)·2^(126 − j)/2^126`: the premise `hxA` of `jointU_w16r2_target`
(`j = 111`) and of `jointU_r13_target` (`j = 110`). -/
theorem xKindA_lin (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : D.s < T.aA)
    (hstab : StabU D (T.cA Ux Xx)) (q j : ℕ) (hj : j ≤ 126) (hε : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * (xKindA D T Ux Xx hwin hstab).εmax + (xKindA D T Ux Xx hwin hstab).B
      ≤ u126 q (1 * 2 ^ (126 - j)) :=
  xKind_lin_le q j hj T.εA T.εA hε le_rfl

/-- **The second half's kind at its constant**: `εB ≤ 2^-j` gives the kind's linear part
`≤ (q + 1)·2^(126 − j)/2^126`: the premise `hxB` of `jointU_w16r2_target` (`j = 113`) and of `jointU_r13_target`
(`j = 126`). -/
theorem xKindB_lin (D : ChainU Lq α) (T : XTest F κ μ Cl h)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → κ → Fin (2 ^ h) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ h))) (hwin : D.s < T.aB)
    (hstab : StabU D (T.cB D.W Ux Xx)) (q j : ℕ) (hj : j ≤ 126) (hε : T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ j) :
    (q : ℝ≥0∞) * (xKindB D T Ux Xx hwin hstab).εmax + (xKindB D T Ux Xx hwin hstab).B
      ≤ u126 q (1 * 2 ^ (126 - j)) :=
  xKind_lin_le q j hj T.εB T.εB hε le_rfl

/-- **The first half's error at W16R2's parameters** (`N = 2^15`, `|F| = p²`, the `(λ, ρ)` bias
`(1 + p/2^128)^(2·w0)`): `≤ 2^-111`. Stated for a variable `p` (L7-4). -/
theorem XTest.εA_w16r2 (T : XTest F κ μ Cl 15) (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) (hw0 : T.w0 ≤ 2 ^ 61)
    (hβ : T.βLR = (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0)) : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ 111 := by
  unfold XTest.εA
  rw [hβ]
  exact xA_eps_w16r2 p hp1 hp2 hF hw0

/-- **The first half's error at R13's parameters** (`N = 2^16`): `≤ 2^-110`. -/
theorem XTest.εA_r13 (T : XTest F κ μ Cl 16) (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) (hw0 : T.w0 ≤ 2 ^ 61)
    (hβ : T.βLR = (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0)) : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ 110 := by
  unfold XTest.εA
  rw [hβ]
  exact xA_eps_r13 p hp1 hp2 hF hw0

/-- **The second half's error at W16R2's parameters** (`N = 2^15`, `e = 8052`, `Q = 280`, the indices exactly
uniform): `≤ 2^-113`. -/
theorem XTest.εB_w16r2 (T : XTest F κ μ Cl 15) (he : T.e = 8052) (hQ : T.nQ = 280) (hβ : T.βJ = 1) :
    T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 113 := by
  unfold XTest.εB
  rw [he, hQ, hβ]
  exact xB_eps_w16r2

/-- **The second half's error at R13's parameters** (`N = 2^16`, `e = 24,448`, `Q = 256`): `≤ 2^-172`, so `≤ 2^-126`
(one unit of the count). -/
theorem XTest.εB_r13 (T : XTest F κ μ Cl 16) (he : T.e = 24448) (hQ : T.nQ = 256) (hβ : T.βJ = 1) :
    T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 172 ∧ T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 126 := by
  have h172 : T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 172 := by
    unfold XTest.εB
    rw [he, hQ, hβ]
    exact xB_eps_r13
  refine ⟨h172, h172.trans ?_⟩
  rw [inv_two_pow_eq, inv_two_pow_eq]
  exact natCast_div_le_div (by positivity) (by positivity) (by norm_num)

end XKindNumbers

end ZK60.ProtocolClassify
