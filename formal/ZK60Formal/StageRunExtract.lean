/-
D63, Lean lane L12 (2026-11-07): **the run's boundary links and its endpoints** for the token stages (ASSEMBLY §4.2
item f, its run part, and item g): from the stage conclusions on the EXTRACTED planes to `classifyArith`'s /
`tokenArith`'s `Satisfies` on the extractor's input, and to the inner predicate of `IOPExtract`.

The framing (classify_run.rs:283-382, `verify_classify_run_with`; the token run frames its stages the same way):
* stage IN-C commits `B_in` (its segment's `b_root`, absorbed as `"B"`, stage_in_c.rs:421-424) and leaves its claims
  on it pending (SIC_QZC reads `B_in` at `(ρ_t, r_emb)`); block 0 opens THAT root (`prev = (b0, b_root)`) with the
  pending claims and its own IO-in claims as ONE opening (classify_run.rs:329-338). So the plane stage IN-C's lookup
  is about and block 0's input plane are one extracted plane: **`B_in` is block 0's input plane**;
* the last block's output root (`prev` after the loop) is opened by stage OUT-C (stage_out_c.rs:717-725) with the last
  block's IO-out claims and OUTC-00's claims as ONE opening; OUTC-00 equates the stage's `x` with that plane at the
  fixed bits of the public verdict row (`fixed_bits(cp.verdict_row(), t_bits)`, :302): **stage OUT-C reads row
  `T − 1` (the verdict row) of `B_out`**.

`RunFrame` records this as one extraction map `ext` from boundary roots to planes and the two root equalities.

What is proved:
* **`classify_run_link`**: stage IN-C's `InSat` on `ext rootIn`, the blocks' `RunSat` on the extracted boundary
  planes (`RunOn`, the block lanes' conclusion, a HYPOTHESIS here), stage OUT-C's `OutCSat` on its `x` with OUTC-00's
  identity, and SIC_IO's endpoint identity give `classifySat` on the CANONICAL endpoint words;
* **`token_run_link`**: the same for the next-token run, with SO_IOOUT's output endpoint word;
* **`classify_inner_of_stages`**, **`token_inner_of_stages`**: with the endpoint OPENINGS as hypotheses (lane L10's
  `opensIn` / `opensOut`, not yet defined in the tree), the inner predicate of `IOPExtract` (Assembly.lean) holds for
  the extractor's output `(x, y, (), r, r')`, `x` the input endpoint's extracted words read canonically.
-/
import ZK60Formal.StageInExtract
import ZK60Formal.StageOutExtract
import ZK60Formal.Assembly

namespace ZK60.StageX

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun

variable {S : BlockShape}

/-- **The blocks' part on the extracted boundary planes** (the block lanes' conclusion; a hypothesis in this file):
`Bin` and `Bout` are the images of int16 planes on which the blocks' constraint system `RunSat` holds. -/
def RunOn (Ps : List (BlockPublic S)) (Bin Bout : S.Pos → GF) : Prop :=
  ∃ x y : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ (∀ p, Bin p = (x p : GF)) ∧
    (∀ p, Bout p = (y p : GF)) ∧ RunSat Ps x y

/-- **The run's framing of its boundary commitments**: one extracted plane per root (the opening extractor's, lane
L10), the root stage IN / IN-C commits, the root block 0 opens as its input, the last block's output root and the root
stage OUT / OUT-C opens, with the two equalities the run's schedule makes (classify_run.rs:300, :333; :379). -/
structure RunFrame (Dg : Type) (S : BlockShape) where
  ext : Dg → S.Pos → GF
  rootIn : Dg
  rootBlock0In : Dg
  rootLastOut : Dg
  rootOut : Dg
  link_in : rootBlock0In = rootIn
  link_out : rootOut = rootLastOut

/-- **The classifier run's links.** Stage IN-C's relation on `B_in`'s extracted plane (with the token words `tokW`,
`A_TOK`), the blocks' relation on the extracted boundary planes, stage OUT-C's relation on its `x` with OUTC-00's
identity `x_i = B_out(row, i)`, and SIC_IO's identity `epW = tokW` (the input endpoint's extracted words at the
support): the classifier's constraint system holds on the CANONICAL endpoint words. -/
theorem classify_run_link {Dg : Type} (R : ClassifyRunPublic S) (F : RunFrame Dg S) (tokW epW : S.Tok → GF)
    (xC : Fin S.d → GF) (b : ℕ) (hb : b ≤ 1) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOn R.Ps (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutCSat R.out xC b)
    (hio : ∀ i, xC i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t) :
    classifySat R (fun t => canonWord (epW t)) b := by
  obtain ⟨x, y, hx, hy, hX, hY, hr⟩ := hrun
  have e1 : (fun t => ((canonWord (epW t) : ℕ) : GF)) = tokW := funext fun t => by rw [canonWord_cast, hep]
  have e2 : (fun p => ((x p : ℤ) : GF)) = F.ext F.rootIn := funext fun p => by rw [← hX, F.link_in]
  have e3 : (fun i => ((y (R.row, i) : ℤ) : GF)) = xC := funext fun i => by rw [hio, F.link_out, hY]
  exact ⟨fun t => canonWord_lt _, hb, x, y, hx, hy, (congrArg₂ (InSat R.inp) e1 e2).mpr hin, hr,
    (congrArg (fun f => OutCSat R.out f b) e3).mpr hout⟩

/-- **The next-token run's links**, as `classify_run_link`, with stage OUT's relation on its `x` for its token word
`tokO` (`A_TOK`) and SO_IOOUT's identity: the output endpoint's word 0 `epO` is `tokO`. The output is the canonical
reading of `epO`. -/
theorem token_run_link {Dg : Type} (R : TokenRunPublic S) (F : RunFrame Dg S) (tokW epW : S.Tok → GF)
    (xO : Fin S.d → GF) (tokO epO : GF) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOn R.Ps (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutSat R.out xO tokO)
    (hio : ∀ i, xO i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t) (hepo : epO = tokO) :
    tokenSat R (fun t => canonWord (epW t)) (canonWord epO) := by
  obtain ⟨x, y, hx, hy, hX, hY, hr⟩ := hrun
  have e1 : (fun t => ((canonWord (epW t) : ℕ) : GF)) = tokW := funext fun t => by rw [canonWord_cast, hep]
  have e2 : (fun p => ((x p : ℤ) : GF)) = F.ext F.rootIn := funext fun p => by rw [← hX, F.link_in]
  have e3 : (fun i => ((y (R.row, i) : ℤ) : GF)) = xO := funext fun i => by rw [hio, F.link_out, hY]
  have e4 : ((canonWord epO : ℕ) : GF) = tokO := by rw [canonWord_cast, hepo]
  exact ⟨fun t => canonWord_lt _, canonWord_lt _, x, y, hx, hy, (congrArg₂ (InSat R.inp) e1 e2).mpr hin, hr,
    (congrArg₂ (OutSat R.out) e3 e4).mpr hout⟩

variable {Q D Coins : Type}

/-- **The endpoints (§4.2 item g), the classifier.** With the run's links and lane L10's endpoint openings as
hypotheses — the input endpoint commitment opens to the extractor's `x` (the extracted words read canonically) with
the extracted opening data `r`; the statement's public verdict is the verdict stage OUT-C was run with
(`st.verdict()`, classify_run.rs:382); the hidden-output commitment opens to `()` (the classifier has no output
endpoint) — the inner predicate of `IOPExtract` holds for `(x, b, (), r, r')`. -/
theorem classify_inner_of_stages {Dg : Type} (R : ClassifyRunPublic S) (P : Protocol Q D Coins (classifyModel S R))
    (H : Q → D) (s : P.Stmt) (F : RunFrame Dg S) (tokW epW : S.Tok → GF) (xC : Fin S.d → GF) (b : ℕ)
    (hb : b ≤ 1) (r r' : P.Salt) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOn R.Ps (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutCSat R.out xC b)
    (hio : ∀ i, xC i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t)
    (hopen : P.opensIn H s (fun t => canonWord (epW t)) r) (hpub : P.ypub s = b)
    (hopenOut : P.opensOut H s () r') :
    (classifyArith S R).Satisfies () (fun t => canonWord (epW t)) b ()
      ∧ P.opensIn H s (fun t => canonWord (epW t)) r
      ∧ P.ypub s = (classifyModel S R).publicPart b
      ∧ P.opensOut H s ((classifyModel S R).hiddenPart b) r' :=
  ⟨classify_run_link R F tokW epW xC b hb hin hrun hout hio hep, hopen, hpub, hopenOut⟩

/-- **The endpoints (§4.2 item g), the next-token run.** As `classify_inner_of_stages`: the input endpoint opens to
the canonical extracted words, the output token endpoint opens to the canonical reading of its extracted word 0, and
the public output part is `()`. -/
theorem token_inner_of_stages {Dg : Type} (R : TokenRunPublic S) (P : Protocol Q D Coins (tokenModel S R))
    (H : Q → D) (s : P.Stmt) (F : RunFrame Dg S) (tokW epW : S.Tok → GF) (xO : Fin S.d → GF) (tokO epO : GF)
    (r r' : P.Salt) (hin : InSat R.inp tokW (F.ext F.rootIn))
    (hrun : RunOn R.Ps (F.ext F.rootBlock0In) (F.ext F.rootLastOut)) (hout : OutSat R.out xO tokO)
    (hio : ∀ i, xO i = F.ext F.rootOut (R.row, i)) (hep : ∀ t, epW t = tokW t) (hepo : epO = tokO)
    (hopen : P.opensIn H s (fun t => canonWord (epW t)) r) (hopenOut : P.opensOut H s (canonWord epO) r') :
    (tokenArith S R).Satisfies () (fun t => canonWord (epW t)) (canonWord epO) ()
      ∧ P.opensIn H s (fun t => canonWord (epW t)) r
      ∧ P.ypub s = (tokenModel S R).publicPart (canonWord epO)
      ∧ P.opensOut H s ((tokenModel S R).hiddenPart (canonWord epO)) r' :=
  ⟨token_run_link R F tokW epW xO tokO epO hin hrun hout hio hep hepo, hopen, rfl, hopenOut⟩

end ZK60.StageX
