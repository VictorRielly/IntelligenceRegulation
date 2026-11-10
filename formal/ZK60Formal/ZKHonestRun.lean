/-
D63 lane L33 (2026-11-09), part 4: **zero knowledge of the classify run as ONE receipt** (`ClassifyOpen`'s field O12,
`AssembleClassify.lean`), from the honest prover as an oracle program and named premises, at the approved target up
to the proved receipt cap (L19-2); and its transfer to the corrected instance `classifyProtocolU` (L26).

* `PProg.andThen`, `run_andThen`: sequencing prover programs;
* `askP`, `ofT`, **`ofT_run`**, `ofStart`, `ofStart_run`: a transcript program of lanes L25 / L29 (`TProg`: absorbs,
  squeezes and outside questions on ONE transcript) as a prover program on the random oracle's domain `QB Lq`, its
  first `nd` transcript operations public (the header before the first fresh root), every other question a point; its
  run is the transcript program's semantics (`TProg.final`) under the oracle. So the slot loops and part heads L29
  wrote (`famProg`, `coreHeadProg`, `incHeadProg`, `outcHeadProg`, PROVED to end on L25's provers' transcripts) are
  prover programs in this lane's sense;
* **`zk_of_prog`**: `ZeroKnowledge` for any protocol whose prover on admissible inputs is the run of a family of
  prover programs: the receipt model and the oracle computation are BUILT here from the programs
  (`ZKHonestProg.model`, `PProg.oc`), so the premises that remain are about the programs' points and receipts only;
* `classify_adm_standin`: for the classify run, the stand-in of an input is admissible exactly when the input is (the
  served bit is in the declared leakage `ClsLeak`);
* **`classify_zk_of_model`**: `ZeroKnowledge (classifyModel S R) (classifyProtocol …)`, the stand-in simulator, error
  `Σ_{j<R} wStep δp ωp δh ωh εc q R j`. Class (B) refusals (an inadmissible input: the sealing pass) are DISCHARGED by
  L18's `prove_unserved`; the honest-verifier law is asked only between two admissible inputs with the SAME verdict and
  where no challenge refusal fires;
* **`classify_zk_cap`**: with the receipt's counts by kind `Z` (L19's `ZKKinds`) and the refusal guard's
  after-request rates `2(δh + δp)`, `2(ωh + ωp)`, the error is within the approved `εzkTarget q R` for every `q` and
  every `R ≤ 2^r` (`ZKHonestCount.lean`'s `ref_cap_R`);
  **`classify_zk_cap110`**: at L19's counts of a whole Shieldstral classify run (`RunK.kinds`), for every
  `R ≤ 2^110` (`runK_ref_cap_110`: two bits below L19's `RunK.cap_112`, finding L33-3), and, the error capped at `1`,
  for every `R ≥ 2^120` (where the target is at least `1`);
* **`classifyU_zk_cap110`**: the same for `classifyProtocolU` (L26's `zkU_of_zk`).

The leakage is the instance's `ClsLeak`: the shapes `T`, `d`, `L` and the served bit; the public output is the verdict.
Every premise is an explicit hypothesis.
-/
import ZK60Formal.ZKHonestView
import ZK60Formal.ZKHonestCount
import ZK60Formal.HonestOracleParts
import ZK60Formal.ProtocolClassifyU

set_option autoImplicit false

namespace ZK60.ZKHonest

open scoped ENNReal
open Finset ZK60 ZK60.ZKW16 ZK60.ZKCount ZK60.ZKHybrid ZK60.Exec ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.HonestClassify (TProg)

/-! ## Sequencing prover programs -/

namespace PProg

variable {Q D α β : Type}

/-- **Sequencing**: the first program's result feeds the second. -/
def andThen : PProg Q D α → (α → PProg Q D β) → PProg Q D β
  | .ret a, f => f a
  | .dep z k, f => .dep z (fun d => andThen (k d) f)
  | .pt z k, f => .pt z (fun d => andThen (k d) f)

/-- A sequence runs the first program, then the second on its result. -/
theorem run_andThen (H : Q → D) : ∀ (p : PProg Q D α) (f : α → PProg Q D β),
    (andThen p f).run H = (f (p.run H)).run H
  | .ret _, _ => rfl
  | .dep z k, f => run_andThen H (k (H z)) f
  | .pt z k, f => run_andThen H (k (H z)) f

end PProg

/-! ## Transcript programs as prover programs -/

section Bridge

variable (Lq : ℕ)

/-- One hash question on `QB Lq`, tagged (an input longer than `Lq` is answered `0` without a question, as `liftH`
answers it). -/
def askP {γ : Type} (isDep : Bool) (q : HIn) (k : Dig → PProg (QB Lq) Dig γ) : PProg (QB Lq) Dig γ :=
  if h : q.msg.length ≤ Lq then
    (if isDep = true then .dep (q.key, ⟨q.msg, h⟩) k else .pt (q.key, ⟨q.msg, h⟩) k)
  else k zeroDig

theorem askP_run {γ : Type} (G : QB Lq → Dig) (isDep : Bool) (q : HIn) (k : Dig → PProg (QB Lq) Dig γ) :
    (askP Lq isDep q k).run G = (k (liftH G q)).run G := by
  unfold askP liftH
  split_ifs <;> rfl

variable {β : Type}

/-- **A transcript program as a prover program** from the transcript `t`: its first `nd` transcript operations are
public (`dep`: the header's absorbs before the first fresh root), every other absorb, squeeze and outside question is a
point. It returns the transcript it ends on and the program's data. -/
def ofT : TProg β → Tr → ℕ → PProg (QB Lq) Dig (Tr × β)
  | .done b, t, _ => .ret (t, b)
  | .absorb l d k, t, nd => askP Lq (decide (0 < nd)) ⟨t.key, absorbMsg t.state l d⟩
      (fun dg => ofT k { t with state := dg } (nd - 1))
  | .squeeze k, t, nd => askP Lq (decide (0 < nd)) ⟨t.key, squeezeMsg t.state t.counter⟩
      (fun dg => ofT (k dg) { t with state := dg, counter := t.counter + 1 } (nd - 1))
  | .ext q k, t, nd => askP Lq false q (fun dg => ofT (k dg) t nd)

/-- **The prover program runs the transcript program's semantics** under the oracle (`liftH`). -/
theorem ofT_run (G : QB Lq → Dig) : ∀ (p : TProg β) (t : Tr) (nd : ℕ),
    (ofT Lq p t nd).run G = TProg.final (liftH G) p t
  | .done _, _, _ => rfl
  | .absorb _ _ k, _, _ => by
    show (askP Lq _ _ _).run G = _
    rw [askP_run]
    exact ofT_run G k _ _
  | .squeeze k, _, _ => by
    show (askP Lq _ _ _).run G = _
    rw [askP_run]
    exact ofT_run G (k _) _ _
  | .ext _ k, t, nd => by
    show (askP Lq _ _ _).run G = _
    rw [askP_run]
    exact ofT_run G (k _) t nd

/-- **A prover program from the transcript's creation** (`Transcript::new_tagged`): the start question
`"hashline-v1/" ‖ domain` under the key (public), then the transcript program from the fresh transcript. -/
def ofStart (key : Option Dig) (domain : List UInt8) (p : TProg β) (nd : ℕ) : PProg (QB Lq) Dig (Tr × β) :=
  askP Lq true ⟨key, startMsg domain⟩ (fun dg => ofT Lq p ⟨dg, 0, key⟩ nd)

theorem ofStart_run (G : QB Lq → Dig) (key : Option Dig) (domain : List UInt8) (p : TProg β) (nd : ℕ) :
    (ofStart Lq key domain p nd).run G = TProg.final (liftH G) p ⟨liftH G ⟨key, startMsg domain⟩, 0, key⟩ := by
  unfold ofStart
  rw [askP_run]
  exact ofT_run Lq G p _ nd

end Bridge

/-! ## Zero knowledge from the prover as a program -/

open Classical in
/-- **Zero knowledge of a protocol whose prover is a family of oracle programs** (D63 Statement 2). Per weight set:
the prover answers `o₀` on an inadmissible input and admissibility is preserved by the stand-in; on admissible inputs
its receipt is the run of the program `prog W x c` (`hprog`), a program of at most `k W` points and `qp` questions
whose result does not read the public answers (`hres`). The receipt model (`ZKHonestProg.model`) and the oracle
computation are built from the programs; what remains is stated on the programs' points `ptsOf` and receipts `outOf`:
the visible points (`hvis`), the refusal guard (`hvisG`, `hrefG`), the honest-verifier law where the guard does not
fire (`hHV`), and the counts. -/
theorem zk_of_prog {Q D Coins : Type} [DecidableEq Q] [Inhabited D] [Fintype Q] [Fintype D] [Nonempty D]
    [Fintype Coins] [Nonempty Coins] [Inhabited Coins] {M : IntModel} {P : Protocol Q D Coins M} [Inhabited M.Input]
    (adm : M.Weights → M.Input → Prop) (o₀ : M.Weights → P.Stmt × P.Receipt)
    (hun : ∀ W H x c, ¬ adm W x → P.prove H W x c = o₀ W)
    (hstd : ∀ W x, adm W (standin P W (M.publicPart (M.forward W x), P.leak x)) ↔ adm W x)
    (prog : (W : M.Weights) → {x // adm W x} → Coins → PProg Q D (P.Stmt × P.Receipt))
    (hprog : ∀ W H (x : {x // adm W x}) c, (prog W x c).run H = P.prove H W x.1 c)
    (k : M.Weights → ℕ) (hk : ∀ W x c, (prog W x c).PtLE (k W))
    (hres : ∀ W x c (H' : Q → D) (v : ℕ → D), (prog W x c).res H' v 0 = (prog W x c).res (fun _ => default) v 0)
    (qp : ℕ) (hq : ∀ W x c, (prog W x c).QLE qp)
    (pad : M.Weights → ℕ → D → Q) (dep : (W : M.Weights) → {x // adm W x} → Coins → Set Q)
    (hdep : ∀ W x c, (prog W x c).DepIn (dep W x c))
    (vis : (W : M.Weights) → (Fin (k W) → D) → Fin (k W) → Prop)
    (vp : (W : M.Weights) → P.Stmt × P.Receipt → (Q → D) → (Fin (k W) → D) → Fin (k W) → Q)
    (hvis : ∀ W x c H v i, vis W v i →
      PProg.ptsOf (pad W) (prog W x c) H v i = vp W (PProg.outOf (prog W x c) v) H v i)
    (G : (W : M.Weights) → (Fin (k W) → D) → Prop) (hvisG : ∀ W v i, G W v → ¬ vis W v i)
    (hrefG : ∀ W x c v, G W v → PProg.outOf (prog W x c) v = o₀ W)
    (hHV : ∀ W (x x' : {x // adm W x}), x'.1 = standin P W (M.publicPart (M.forward W x.1), P.leak x.1) →
      ∀ v : Fin (k W) → D, ¬ G W v → (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog W x c) v)
        = (PMF.uniformOfFintype Coins).map (fun c => PProg.outOf (prog W x' c) v))
    (Kf KUf : M.Weights → Q → ℕ) (Km KUm Wp Wpa Kc : M.Weights → ℕ)
    (hKm : ∀ W z, Kf W z ≤ Km W) (hKUm : ∀ W z, KUf W z ≤ KUm W)
    (hwb : ∀ W x c, WB (Kf W) (prog W x c).oc (Wp W)) (hwba : ∀ W x c, WB (KUf W) (prog W x c).oc (Wpa W))
    (hKw : ∀ W x (H : Q → D) z, (univ.filter (fun s : Coins × (Fin (k W) → D) =>
      ∃ i, PProg.ptsOf (pad W) (prog W x s.1) H s.2 i = z)).card ≤ Kf W z)
    (hKc : ∀ W x (H : Q → D), (univ.filter (fun s : Coins × (Fin (k W) → D) =>
      ¬ Function.Injective (PProg.ptsOf (pad W) (prog W x s.1) H s.2)
        ∨ ∃ i, PProg.ptsOf (pad W) (prog W x s.1) H s.2 i ∈ dep W x s.1)).card ≤ Kc W)
    (hKG : ∀ W z, Kf W z ≤ Fintype.card (Fin (k W) → D) * KUf W z)
    (hUw : ∀ W x (H : Q → D) (v : Fin (k W) → D), ¬ G W v →
      ∀ (Z : (P.Stmt × P.Receipt) → Finset Q) (Wt : ℕ), (∀ o, ∑ z ∈ Z o, KUf W z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ vis W v i
        ∧ PProg.ptsOf (pad W) (prog W x c) H v i ∈ Z (PProg.outOf (prog W x c) v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : ∀ W, (Km W : ℝ≥0∞) / Fintype.card (Coins × (Fin (k W) → D)) ≤ δp)
    (hrωp : ∀ W, (Wp W : ℝ≥0∞) / Fintype.card (Coins × (Fin (k W) → D)) ≤ ωp)
    (hrεc : ∀ W, (Kc W : ℝ≥0∞) / Fintype.card (Coins × (Fin (k W) → D)) ≤ εc)
    (hrδh : ∀ W, ((2 * KUm W : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ∀ W, ((2 * Wpa W : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ ωh) :
    ZeroKnowledge M P (fun q R => ∑ j ∈ range R, wStep δp ωp δh ωh εc q R j) := by
  -- the prover as an oracle computation on every input
  obtain ⟨pOC, hpOC⟩ : ∃ pOC : M.Weights → M.Input → Coins → OC Q D (P.Stmt × P.Receipt),
      ∀ W x c, pOC W x c = if h : adm W x then (prog W ⟨x, h⟩ c).oc else OC.ret (o₀ W) :=
    ⟨_, fun _ _ _ => rfl⟩
  have hpos : ∀ W x c (h : adm W x), pOC W x c = (prog W ⟨x, h⟩ c).oc :=
    fun W x c h => (hpOC W x c).trans (dite_eq_left h)
  have hneg : ∀ W x c, ¬ adm W x → pOC W x c = OC.ret (o₀ W) :=
    fun W x c h => (hpOC W x c).trans (dite_eq_right h)
  have hrun : ∀ W H x c, (pOC W x c).run H = P.prove H W x c := by
    intro W H x c
    by_cases h : adm W x
    · exact (congrArg (fun A => OC.run H A) (hpos W x c h)).trans
        ((PProg.oc_run H _).trans (hprog W H ⟨x, h⟩ c))
    · exact (congrArg (fun A => OC.run H A) (hneg W x c h)).trans (hun W H x c h).symm
  have hbd : ∀ W x c, (pOC W x c).Bounded qp := by
    intro W x c
    by_cases h : adm W x
    · rw [hpos W x c h]
      exact PProg.oc_bounded _ qp (hq W ⟨x, h⟩ c)
    · rw [hneg W x c h]
      trivial
  have hwb' : ∀ W x c, WB (Kf W) (pOC W x c) (Wp W) := by
    intro W x c
    by_cases h : adm W x
    · rw [hpos W x c h]
      exact hwb W ⟨x, h⟩ c
    · rw [hneg W x c h]
      trivial
  have hwba' : ∀ W x c, WB (KUf W) (pOC W x c) (Wpa W) := by
    intro W x c
    by_cases h : adm W x
    · rw [hpos W x c h]
      exact hwba W ⟨x, h⟩ c
    · rw [hneg W x c h]
      trivial
  exact zk_of_refModel pOC qp hrun hbd adm o₀ hun hstd
    (fun W => PProg.model (k W) (pad W) (prog W) (dep W) (hdep W) (vis W) (vp W) (hvis W))
    (fun W H x c => ((PProg.model_prove (k W) (pad W) (prog W) (dep W) (hdep W) (vis W) (vp W) (hvis W) H x c
      (hk W x c) (hres W x c)).trans (hprog W H x c)).symm)
    G hvisG hrefG hHV Kf KUf Km KUm Wp Wpa Kc hKm hKUm hwb' hwba' hKw hKc hKG hUw δp ωp δh ωh εc
    hrδp hrωp hrεc hrδh hrωh

/-! ## The classify run -/

section Classify

variable {S : ZK60.Block.BlockShape} {Hdr Salt Coins : Type}

/-- The classify model's inputs are inhabited (the stand-in needs a default). -/
instance classifyInputInhabited (R : ClassifyRunPublic S) : Inhabited (classifyModel S R).Input :=
  ⟨fun _ => 0⟩

/-- **The stand-in of an input is admissible exactly when the input is**: the served bit is part of the declared
leakage (`ClsLeak`, L18's `leak_served`), and the stand-in has the input's leakage (L14's `standin_spec`). -/
theorem classify_adm_standin (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (x : (classifyModel S R).Input) :
    (classifyModel S R).admissible (standin (classifyProtocol S R Lq V P Cin h64 hr base) ()
        ((classifyModel S R).publicPart ((classifyModel S R).forward () x),
          (classifyProtocol S R Lq V P Cin h64 hr base).leak x))
      ↔ (classifyModel S R).admissible x := by
  have hspec := standin_spec (classifyProtocol S R Lq V P Cin h64 hr base) () x
  have hl := congrArg Prod.snd hspec
  have e1 := leak_served R Lq V P Cin h64 hr base
    (standin (classifyProtocol S R Lq V P Cin h64 hr base) ()
      ((classifyModel S R).publicPart ((classifyModel S R).forward () x),
        (classifyProtocol S R Lq V P Cin h64 hr base).leak x))
  have e2 := leak_served R Lq V P Cin h64 hr base x
  have hl' : ((classifyProtocol S R Lq V P Cin h64 hr base).leak
      (standin (classifyProtocol S R Lq V P Cin h64 hr base) ()
        ((classifyModel S R).publicPart ((classifyModel S R).forward () x),
          (classifyProtocol S R Lq V P Cin h64 hr base).leak x))).served
      = ((classifyProtocol S R Lq V P Cin h64 hr base).leak x).served := congrArg ClsLeak.served hl
  exact ⟨fun h1 => e2.mp (hl'.symm.trans (e1.mpr h1)), fun h2 => e1.mp (hl'.trans (e2.mpr h2))⟩

/-- **The stand-in of an admissible input has the input's verdict** (the public part of the classify model's output). -/
theorem classify_standin_verdict (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (x : (classifyModel S R).Input) :
    (classifySpec R (standin (classifyProtocol S R Lq V P Cin h64 hr base) ()
        ((classifyModel S R).publicPart ((classifyModel S R).forward () x),
          (classifyProtocol S R Lq V P Cin h64 hr base).leak x))).getD 0
      = (classifySpec R x).getD 0 :=
  congrArg Prod.fst (standin_spec (classifyProtocol S R Lq V P Cin h64 hr base) () x)

variable [Fintype Coins] [Nonempty Coins] [Inhabited Coins]

open Classical in
/-- **Zero knowledge of the classify run as ONE receipt** (`ClassifyOpen`'s field O12, with `base := hon.base`), from
the honest prover's receipt model on admissible inputs. The declared leakage is `ClsLeak` (`T`, `d`, `L`, the served
bit); the public output is the verdict. The class (B) refusal (an inadmissible input) is L18's `prove_unserved`. What
remains, each a named premise: the prover as a `qp`-question computation `pOC` (`hrun`, `hbd`) and as the honest
prover of a receipt model `FM` on admissible inputs (`hP`: `ZKHonestProg.model` builds both from an oracle program);
the refusal guard `G` (`hvisG`, `hrefG`: every other refusal is a function of the challenges and public data); the
honest-verifier law between two admissible inputs with the SAME verdict where the guard does not fire (`hHV`:
`hHV_rel_of_layers` and `honest_block_view_law_eq`); and the counts by kind with their rates. -/
theorem classify_zk_of_model (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (pOC : (S.Tok → ℕ) → Coins → OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (qp : ℕ)
    (hrun : ∀ G x c, (pOC x c).run G = (classifyProtocol S R Lq V P Cin h64 hr base).prove G () x c)
    (hbd : ∀ x c, (pOC x c).Bounded qp)
    (FM : FSModel (QB Lq) Dig {x // (classifyModel S R).admissible x} Coins (ClsStmt Hdr × ClsReceipt))
    (hP : ∀ G (x : {x // (classifyModel S R).admissible x}) c,
      (classifyProtocol S R Lq V P Cin h64 hr base).prove G () x.1 c = FM.prove G x c)
    (G : (Fin FM.k → Dig) → Prop) (hvisG : ∀ v i, G v → ¬ FM.vis v i)
    (hrefG : ∀ x c v, G v → FM.out x c v = (P.refused, []))
    (hHV : ∀ x x' : {x // (classifyModel S R).admissible x},
      (classifySpec R x.1).getD 0 = (classifySpec R x'.1).getD 0 → ∀ v : Fin FM.k → Dig, ¬ G v →
        (PMF.uniformOfFintype Coins).map (fun c => FM.out x c v)
          = (PMF.uniformOfFintype Coins).map (fun c => FM.out x' c v))
    (Kf KUf : QB Lq → ℕ) (Km KUm Wp Wpa Kc : ℕ) (hKm : ∀ z, Kf z ≤ Km) (hKUm : ∀ z, KUf z ≤ KUm)
    (hwb : ∀ x c, WB Kf (pOC x c) Wp) (hwba : ∀ x c, WB KUf (pOC x c) Wpa)
    (hKw : ∀ x (H : QB Lq → Dig) z, (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ∃ i, FM.pts x s.1 H s.2 i = z)).card ≤ Kf z)
    (hKc : ∀ x (H : QB Lq → Dig), (univ.filter (fun s : Coins × (Fin FM.k → Dig) =>
      ¬ Function.Injective (FM.pts x s.1 H s.2) ∨ ∃ i, FM.pts x s.1 H s.2 i ∈ FM.dep x s.1)).card ≤ Kc)
    (hKG : ∀ z, Kf z ≤ Fintype.card (Fin FM.k → Dig) * KUf z)
    (hUw : ∀ x (H : QB Lq → Dig) (v : Fin FM.k → Dig), ¬ G v →
      ∀ (Z : (ClsStmt Hdr × ClsReceipt) → Finset (QB Lq)) (Wt : ℕ), (∀ o, ∑ z ∈ Z o, KUf z ≤ Wt) →
      (univ.filter (fun c => ∃ i, ¬ FM.vis v i ∧ FM.pts x c H v i ∈ Z (FM.out x c v))).card ≤ Wt)
    (δp ωp δh ωh εc : ℝ≥0∞)
    (hrδp : (Km : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ δp)
    (hrωp : (Wp : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ ωp)
    (hrεc : (Kc : ℝ≥0∞) / Fintype.card (Coins × (Fin FM.k → Dig)) ≤ εc)
    (hrδh : ((2 * KUm : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ δh)
    (hrωh : ((2 * Wpa : ℕ) : ℝ≥0∞) / Fintype.card Coins ≤ ωh) :
    ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base)
      (fun q R' => ∑ j ∈ range R', wStep δp ωp δh ωh εc q R' j) :=
  zk_of_refModel (P := classifyProtocol S R Lq V P Cin h64 hr base) (fun _ => pOC) qp (fun _ => hrun) (fun _ => hbd)
    (fun _ => (classifyModel S R).admissible) (fun _ => (P.refused, []))
    (fun _ H x c hx => prove_unserved R Lq V P Cin h64 hr base H x c hx)
    (fun _ x => classify_adm_standin R Lq V P Cin h64 hr base x)
    (fun _ => FM) (fun _ => hP) (fun _ => G) (fun _ => hvisG) (fun _ => hrefG)
    (fun _ x x' hx' v hg => hHV x x'
      ((classify_standin_verdict R Lq V P Cin h64 hr base x.1).symm.trans
        (congrArg (fun y => (classifySpec R y).getD 0) hx'.symm)) v hg)
    (fun _ => Kf) (fun _ => KUf) (fun _ => Km) (fun _ => KUm) (fun _ => Wp) (fun _ => Wpa) (fun _ => Kc)
    (fun _ => hKm) (fun _ => hKUm) (fun _ => hwb) (fun _ => hwba) (fun _ => hKw) (fun _ => hKc) (fun _ => hKG)
    (fun _ => hUw) δp ωp δh ωh εc (fun _ => hrδp) (fun _ => hrωp) (fun _ => hrεc) (fun _ => hrδh) (fun _ => hrωh)

/-- **Within the approved target up to a receipt cap**: if the classify run is zero knowledge with the error of a
refusing prover at a receipt's counts by kind `Z` (`refErr Z`: `classify_zk_of_model` at `δp := Z.δp`, `ωp := Z.ωp`,
`εc := Z.εc` and the guard's after-request rates `δh := 2(Z.δh + Z.δp)`, `ωh := 2(Z.ωh + Z.ωp)`), and `Z` meets
`ref_cap_R`'s criterion at `r`, the error is within `εzkTarget q R` for every `q` and every `R ≤ 2^r`. -/
theorem classify_zk_cap (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (Z : ZKKinds)
    (hzk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) (refErr Z))
    (c p a b r : ℕ) (hm : Z.mT ≤ 2 ^ a) (hb : Z.qpT * Z.mT ≤ 2 ^ b) (hb13 : 13 ≤ b)
    (hC : Z.cols ≤ 2 ^ c) (hLN : Z.leaves + Z.nodes ≤ 2 ^ c)
    (hqC : Z.qpC ≤ 2 ^ c) (hqL : Z.qpL ≤ 2 ^ c) (hqN : Z.qpN ≤ 2 ^ c)
    (hcol : 2 * c + 252 ≤ Z.hcol) (hcond : 2 * c + 252 ≤ Z.hcond) (h512 : 2 * c + 252 ≤ 512)
    (hp : Z.pts ≤ 2 ^ p) (hp' : 2 * p + 124 ≤ 256) (hrb : r + b ≤ 131) (har : a + r + 134 ≤ 256) (hr' : r ≤ 118) :
    ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) (refErr Z)
      ∧ ∀ q R', R' ≤ 2 ^ r → refErr Z q R' ≤ εzkTarget q R' :=
  ⟨hzk, fun q R' hR =>
    ref_cap_R Z c p a b r hm hb hb13 hC hLN hqC hqL hqN hcol hcond h512 hp hp' hrb har hr' q R' hR⟩

/-- **O12 for the classify run at the approved target, up to the proved cap** (finding L19-2 stands: a cap for a
multi-block receipt is Victor's to rule on; finding L33-3: with the refusals accounted for, this proof's cap at L19's
counts is `2^110`, two bits below L19's `2^112`). If the classify run is zero knowledge with the error of a refusing
prover at L19's counts of a whole Shieldstral classify run as one receipt (`refErr RunK.kinds`), then with the error
capped at `1` it is zero knowledge, and that error is within the approved `εzkTarget q R` for every `q` and every
`R ≤ 2^110` (`runK_ref_cap_110`) and every `R ≥ 2^120` (where the target is at least `1`). -/
theorem classify_zk_cap110 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (hzk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) (refErr RunK.kinds)) :
    ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base)
        (fun q R' => min (refErr RunK.kinds q R') 1)
      ∧ ∀ q R', (R' ≤ 2 ^ 110 ∨ 2 ^ 120 ≤ R') → min (refErr RunK.kinds q R') 1 ≤ εzkTarget q R' := by
  refine ⟨zeroKnowledge_min_one hzk, fun q R' hR => ?_⟩
  rcases hR with hR | hR
  · exact (min_le_left _ _).trans (runK_ref_cap_110 q R' hR)
  · exact (min_le_right _ _).trans (one_le_target_of_large q R' hR)

/-- **The same for the corrected instance `classifyProtocolU`** (L26: the input opening at the unique-decoding radius
`e`): zero knowledge transfers with the same simulator and error (`zkU_of_zk`). -/
theorem classifyU_zk_cap110 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (e : ℕ)
    (hzk : ZeroKnowledge (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) (refErr RunK.kinds)) :
    ZeroKnowledge (classifyModel S R) (classifyProtocolU S R Lq V P Cin h64 hr base e)
        (fun q R' => min (refErr RunK.kinds q R') 1)
      ∧ ∀ q R', (R' ≤ 2 ^ 110 ∨ 2 ^ 120 ≤ R') → min (refErr RunK.kinds q R') 1 ≤ εzkTarget q R' :=
  ⟨zkU_of_zk R Lq V P Cin h64 hr base e (classify_zk_cap110 R Lq V P Cin h64 hr base hzk).1,
    (classify_zk_cap110 R Lq V P Cin h64 hr base hzk).2⟩

end Classify

end ZK60.ZKHonest
