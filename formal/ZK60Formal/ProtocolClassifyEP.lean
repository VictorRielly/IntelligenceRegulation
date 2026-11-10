/-
D63 lane L48 (2026-11-10), part 4: **Victor's D77 (1) instance at the input commitment's REAL geometry** (finding
L45-2, decision D77a).

D77 (1) ruled that the classify run's input commitment opens at the code's unique-decoding radius at its LARGEST value.
Lane L26 built that instance (`classifyProtocolU`) and its extraction (`classifyU_O11d`) for any plane commitment, and
instantiated them at `r13TokenCommit` (the block geometry, radius `24,448`); lane L30 put the executable stages under it
(`classifyProtocolUExec`). The code's input commitment is at the token-I/O tier's endpoint geometry
(`BindingEP.lean`'s `epTokenCommit`: `2^8` columns, rate `1/8`, `N = 2,048`, depth `11`). Here the instance is rebuilt
there, at the largest radius `e = 768`:

* **`classifyU_binding_ep`**: `Binding` at the approved target for EVERY `q`, at the real input commitment (L26's
  `bindingU`: `N · collBound`, `N = 2^11 ≤ 2^20`, depth `11 ≤ 64`);
* `XTest.εA_ep`, **`XTest.εB_ep`**: the endpoint column test's two rounds (`≤ 2^-115`; `≤ 2^-173`, so `≤ 2^-126`);
* **`classifyU_O11d_ep`**: L26's O11d (the endpoint's extraction fails on an accepted receipt with probability at most
  `εKinds Ks εx q`) at the real input commitment, with the commitment's facts PROVED (`hokC`: the canonical words are
  admissible; `hplane`: the plane is the token-words plane; the radius) and the column test's premise `hX` DISCHARGED
  through the test's two kinds and L30's code fact at the endpoint code (`xlink_of_read` at `epPts`, `epForm`,
  `rowFormK8`): what remains is the test's reading of the run (`hwin`, `hread`, `hBal`), as at L30's R13 gate;
* **`classifyProtocolUExecEp`**: L30's `classifyProtocolUExec` (the executable stages) at `epTokenCommit` and `e = 768`:
  D77 (1)'s instance as it should have been. `classifyUExecEp_verify` (its verifier IS `classifyProtocolExec`'s),
  `classifyUExecEp_opensIn` (its opening is `OpensU` at `768`), **`classifyUExecEp_binding`**,
  `classifyUExecEp_complete`, `classifyUExecEp_zk` (carried from L18's instance at the same commitment),
  **`classifyUExecEp_O11d`**.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.BindingEP
import ZK60Formal.ProtocolClassifyUEp
import ZK60Formal.RunChainUExec

set_option autoImplicit false
set_option linter.constructorNameAsVariable false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.Assembly ZK60.StageX Code
open ZK60.Exec.StageV (IncV OutcV StageGeom classifyRunV classifyProtocolExec)
open ZK60.Circuit (gP GF)
open ZK60.Block (BlockShape)

/-! ## The endpoint column test's numbers -/

section XNumbers

variable {F κ μ Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Fintype κ] [DecidableEq κ] [Fintype Cl]
  [DecidableEq Cl]

/-- **The endpoint test's first round at its parameters** (`N = 2^11`, `|F| = p²`): `≤ 2^-115`. Stated for a variable
`p` (L7-4). -/
theorem XTest.εA_ep (T : XTest F κ μ Cl 11) (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) (hw0 : T.w0 ≤ 2 ^ 61)
    (hβ : T.βLR = (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0)) : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ 115 := by
  unfold XTest.εA
  rw [hβ]
  exact xA_eps_ep p hp1 hp2 hF hw0

/-- The endpoint test's first round within `2^-110` (the R13 gate's form for its kind's constant `2^16`). -/
theorem XTest.εA_ep110 (T : XTest F κ μ Cl 11) (p : ℕ) (hp1 : p ≤ 2 ^ 64) (hp2 : 2 ^ 64 - 2 ^ 32 ≤ p)
    (hF : Fintype.card F = p ^ 2) (hw0 : T.w0 ≤ 2 ^ 61)
    (hβ : T.βLR = (1 + (p : ℝ≥0∞) / ((2 ^ 128 : ℕ) : ℝ≥0∞)) ^ (2 * T.w0)) : T.εA ≤ (2⁻¹ : ℝ≥0∞) ^ 110 :=
  (T.εA_ep p hp1 hp2 hF hw0 hβ).trans (Link.og_inv_two_pow_le (by norm_num))

/-- **The endpoint test's second round at its parameters** (`N = 2^11`, `e = 768`, `Q = 256`): `≤ 2^-173`, so
`≤ 2^-126` (one unit of the count). -/
theorem XTest.εB_ep (T : XTest F κ μ Cl 11) (he : T.e = 768) (hQ : T.nQ = 256) (hβ : T.βJ = 1) :
    T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 173 ∧ T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 126 := by
  have h173 : T.εB ≤ (2⁻¹ : ℝ≥0∞) ^ 173 := by
    unfold XTest.εB
    rw [he, hQ, hβ]
    exact xB_eps_ep
  exact ⟨h173, h173.trans (Link.og_inv_two_pow_le (by norm_num))⟩

end XNumbers

variable {S : BlockShape} {Hdr Salt Coins : Type}

/-! ## Binding at the real input commitment -/

section Bind

variable (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
  (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 8) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
  (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (tagc : MTag)

/-- **`Binding` at the target at the classifier's REAL input commitment** (`epTokenCommit`, radius `e = 768`, the
largest), for every `q` and every run verifier. -/
theorem classifyU_binding_ep (h64 : 64 ≤ Lq)
    (hr : 8 * (epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
      tagc).R ≤ Lq) (base : Coins → Salt) :
    Binding (classifyModel S R) (classifyProtocolU S R Lq V P
      (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc) h64 hr base 768)
      εsTarget :=
  classifyU_binding_target R Lq V P _ h64 hr base 768 (by show 2 * 768 + (2 ^ 8 + 256) ≤ 2 ^ 11; norm_num)
    (by show 2 ^ 11 ≤ 2 ^ 20; norm_num) (by show 11 ≤ 64; norm_num)

end Bind

/-! ## O11d at the real input commitment -/

section O11d

variable (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 8) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
  (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (tagc : MTag)

-- The classifier's input commitment at its real geometry.
local notation "CinE" =>
  epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc

/-- **O11D AT THE CLASSIFIER'S REAL INPUT COMMITMENT** (L26's `classifyU_O11d` at `epTokenCommit`, `e = 768`): the
commitment's facts (admissible words, the token-words plane) are PROVED; the column test's premise `hX` is
DISCHARGED through the test's two kinds (`xKinds_cover`) and L30's code fact at the endpoint's code (`xlink_of_read`
at `epPts`, `epForm`, `rowFormK8`): the test `T` is at the endpoint geometry (`2^11` symbols, its code the endpoint
code over the test's field, radius `768`), and what remains of the column test is its reading of the run: its windows
at steps' ends (`hwin`), its matrix and openable set the extractor's (`hread`), its second half alive at the end
(`hBal`). With the extractor's openings verifying with canonical columns (`hops`, `hcan`), the extractor reading the
endpoint by decoding (`hE`) and SIC_IO's zero half (`hzero`), the endpoint's extraction fails on an accepted receipt with
probability at most `εKinds Ks εx q`, every `q`, every prover. -/
theorem classifyU_O11d_ep (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (h64 : 64 ≤ Lq) (hr : 8 * (CinE).R ≤ Lq) (base : Coins → Salt) (mk : (CinE).SaltMk)
    (ops : List (QB Lq × Dig) → ClsStmt Hdr → Fin (2 ^ 11) → Option (MerkleOpening Dig Dig (ColR Rr)))
    (E : List (QB Lq × Dig) → ClsStmt Hdr → ClsReceipt → RunExt S Salt)
    (hE : ∀ lg s pf, (E lg s pf).epW = (fun t => ((CinE).decodeIn (ops lg s) 768).1 ((CinE).place (pos t).1) (pos t).2)
      ∧ (E lg s pf).r = mk.bld ((CinE).decodeIn (ops lg s) 768).1 ((CinE).decodeIn (ops lg s) 768).2
          ((CinE).exSalt (ops lg s)) ((CinE).exPath (ops lg s)))
    (Ks : List (FirstKind Lq (ClsStmt Hdr × ClsReceipt)))
    (Ex : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt) → (QB Lq → Dig) → Prop) (εx : ℕ → ℝ≥0∞)
    (hEx : ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q → prH (Ex A) ≤ εx q)
    (hops : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig) j o,
      ops (A.runLog G).2 (A.runLog G).1.1 j = some o →
        (merkleEncB (CinE).tag Lq (CinE).R h64 hr).Opens G (CinE).depth ((CinE).root (A.runLog G).1.1) j.val o)
    (hcan : ∀ lg s j o, ops lg s j = some o → ∀ a ∈ o.col.1, a.Canon)
    {F Cl : Type} [Field F] [Fintype F] [DecidableEq F] [Algebra GF F] [Fintype Cl] [DecidableEq Cl]
    (D : ChainU Lq (ClsStmt Hdr × ClsReceipt)) (T : XTest F (Fin Rr) (Fin (2 ^ 8 + 256)) Cl 11)
    (hTenc : T.enc = encLin (Q := 256) (fun j => algebraMap GF F (epPts j)) (rowFormK8 F)) (hTe : T.e = 768)
    (Ux : List (QB Lq × Dig) → List (TItem × Dig) → Fin Rr → Fin (2 ^ 11) → F)
    (Xx : List (QB Lq × Dig) → List (TItem × Dig) → Finset (Fin (2 ^ 11)))
    (hwA : D.s < T.aA) (hwB : D.s < T.aB) (hsA : StabU D (T.cA Ux Xx)) (hsB : StabU D (T.cB D.W Ux Xx))
    (hKA : xKindA D T Ux Xx hwA hsA ∈ Ks) (hKB : xKindB D T Ux Xx hwB hsB ∈ Ks)
    (hwin : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinE) h64 hr base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      tRem D.W ((D.chain G (A.run G)).take T.aA) = some 0 ∧ T.aB ≤ (D.chain G (A.run G)).length
        ∧ tRem D.W ((D.chain G (A.run G)).take T.aB) = some 0)
    (hread : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinE) h64 hr base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      Xx (A.runLog G).2 ((D.chain G (A.run G)).take T.aA) = exX (ops (A.runLog G).2 (A.runLog G).1.1)
        ∧ Ux (A.runLog G).2 ((D.chain G (A.run G)).take T.aA)
          = fun i j => algebraMap GF F (exU (ops (A.runLog G).2 (A.runLog G).1.1) i j))
    (hBal : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinE) h64 hr base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      subSt D.W (T.cB D.W Ux Xx (A.runLog G).2) (D.chain G (A.run G)))
    (hzero : ∀ (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (G : QB Lq → Dig),
      (classifyProtocolU S R Lq V P (CinE) h64 hr base 768).verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true →
      ¬ Ex A G →
      ¬ (∀ k i, (¬ ∃ t, pos t = (k, i)) → ((CinE).decodeIn (ops (A.runLog G).2 (A.runLog G).1.1) 768).1
          ((CinE).place k) i = 0)
        → ∃ K ∈ Ks, K.Ev A G) :
    ∀ (q : ℕ) (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)), A.Bounded q →
      prH (fun G => (classifyProtocolU S R Lq V P (CinE) h64 hr base 768).verify G () (A.runLog G).1.1
          (A.runLog G).1.2 = true ∧ ¬ EpOk (classifyProtocolU S R Lq V P (CinE) h64 hr base 768) G (A.runLog G).1.1
            (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2)) ≤ εKinds Ks εx q :=
  classifyU_O11d R Lq V P (CinE) h64 hr base 768 (fun _ hx => hx) pos (fun _ => rfl) mk ops E hE Ks Ex εx hEx hops
    hcan
    (fun A G hv hx hnc => by
      rcases xKinds_cover D T Ux Xx hwA hwB hsA hsB A G
          (xlink_of_read epPts epForm (rowFormK8 F) (rowFormK8_ext_ep F) T hTenc 768 hTe D.W Ux Xx (A.runLog G).2
            (D.chain G (A.run G)) (ops (A.runLog G).2 (A.runLog G).1.1) (hread A G hv hx).1 (hread A G hv hx).2
            (hwin A G hv hx).1 (hwin A G hv hx).2.1 (hwin A G hv hx).2.2 (hBal A G hv hx) hnc) with h | h
      · exact ⟨_, hKA, h⟩
      · exact ⟨_, hKB, h⟩)
    hzero

end O11d

/-! ## D77 (1)'s instance at the real input commitment, with the executable stages -/

section Instance

variable (R : ClassifyRunPublic S) (Lq : ℕ) (Lb : ℕ) (preA preB : Hdr → Except String Unit)
  (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
  (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
  (P : RunP Hdr (S.Tok → ℕ) Coins)
  (Rr dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 8)} (hpos : Function.Injective pos)
  (place : Fin dR → Fin Rr) (msg : (S.Tok → ℕ) → Salt → Fin Rr → Fin (2 ^ 8) → GF)
  (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin Rr → Fin 256 → GF)
  (salt : Salt → Fin (2 ^ 11) → Dig) (path : Salt → Fin (2 ^ 11) → List Dig) (tagc : MTag) (h64 : 64 ≤ Lq)
  (hr : 8 * (epTokenCommit (St := ClsStmt Hdr) Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot
    tagc).R ≤ Lq) (base : Coins → Salt)

/-- **D77 (1)'S INSTANCE AS IT SHOULD HAVE BEEN** (D63 lane L48): L30's `classifyProtocolUExec` (L26's opening at the
unique-decoding radius, L29's executable stages) at the classifier's REAL input commitment `epTokenCommit` (the
token-I/O tier's endpoint geometry: `2^8` columns, rate `1/8`, `2,048` columns, `256` checked) and the LARGEST radius
`e = 768`. -/
noncomputable def classifyProtocolUExecEp : Protocol (QB Lq) Dig Coins (classifyModel S R) :=
  classifyProtocolUExec R Lq Lb preA preB start inc incG blk outc outcG P
    (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc) h64 hr base 768

/-- **Its verifier IS `classifyProtocolExec`'s** (L29's, the same verifier the corpus checked). -/
theorem classifyUExecEp_verify (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocolUExecEp R Lq Lb preA preB start inc incG blk outc outcG P Rr dR hpos place msg msg_place pad salt
      path tagc h64 hr base).verify G () s rc
      = (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P
          (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc) h64 hr base).verify
          G () s rc :=
  rfl

/-- **Its input opening is `OpensU` at the real commitment and the largest radius `768`.** -/
theorem classifyUExecEp_opensIn (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocolUExecEp R Lq Lb preA preB start inc incG blk outc outcG P Rr dR hpos place msg msg_place pad salt
      path tagc h64 hr base).opensIn G s x r
      ↔ (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc).OpensU Lq h64 hr 768 G s x
          r :=
  Iff.rfl

/-- **`Binding` at the approved target, for every `q`.** -/
theorem classifyUExecEp_binding :
    Binding (classifyModel S R) (classifyProtocolUExecEp R Lq Lb preA preB start inc incG blk outc outcG P Rr dR hpos
      place msg msg_place pad salt path tagc h64 hr base) εsTarget :=
  classifyU_binding_ep R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P Rr dR hpos place msg msg_place
    pad salt path tagc h64 hr base

/-- **`Complete` carries over** from L18's instance (`classifyProtocolExec`) at the same commitment, with the same
error. -/
theorem classifyUExecEp_complete [Fintype Coins] [Nonempty Coins] {εc : ℝ≥0∞}
    (h : Complete (classifyModel S R) (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P
      (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc) h64 hr base) εc) :
    Complete (classifyModel S R) (classifyProtocolUExecEp R Lq Lb preA preB start inc incG blk outc outcG P Rr dR hpos
      place msg msg_place pad salt path tagc h64 hr base) εc :=
  completeU_of_complete R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P _ h64 hr base 768 h

/-- **`ZeroKnowledge` carries over** from L18's instance at the same commitment, with the same simulator. -/
theorem classifyUExecEp_zk [Fintype Coins] [Nonempty Coins] [Inhabited Coins] {εzk : ℕ → ℕ → ℝ≥0∞}
    (h : ZeroKnowledge (classifyModel S R) (classifyProtocolExec R Lq Lb preA preB start inc incG blk outc outcG P
      (epTokenCommit Rr dR hpos place msg msg_place pad salt path ClsStmt.inRoot tagc) h64 hr base) εzk) :
    ZeroKnowledge (classifyModel S R) (classifyProtocolUExecEp R Lq Lb preA preB start inc incG blk outc outcG P Rr dR
      hpos place msg msg_place pad salt path tagc h64 hr base) εzk :=
  zkU_of_zk R Lq (classifyRunV Lb preA preB start inc incG blk outc outcG) P _ h64 hr base 768 h

end Instance

end ZK60.ProtocolClassify
