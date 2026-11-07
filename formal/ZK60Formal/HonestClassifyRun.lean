/-
D63 Lean lane L25 (2026-11-07), part 3: **the classify run's parts' honest provers as `SegP`s, their completeness
contracts (`SegComplete`, obligation O8 of `ClassifyOpen`) and the refusal structure (O9)**.

The code (hashline `src/private_block/token_io/classify_run.rs` `prove_classify_run_with` :185-236, stage_in_c.rs,
stage_out_c.rs, wire.rs `encode_segment` :407-444; read 2026-11-07; nothing there is changed): ONE transcript; per
part the start tag (`position_tag`), the part's honest prover, the end tag, and the frame (`encode(…, &binding, &start,
&end)`). For a block: the framing absorbs (`pb-run-stage`, `pb-run-block`, `absorb_root("B", B_{k+1})`), the block's core
(`prove_core_after_with`), the boundary audit (`boundary::check_opening`, refused by the prover as by the verifier) and
the opening of the PREVIOUS boundary with the pending claims; the carry becomes `(io_out, B_{k+1})`.

What is proved (every premise a hypothesis):
* `StageInP`, `inSegP`, `StageInOK`, **`inSeg_complete`**: stage IN-C's honest part (its prover and its frame
  encoder, as parameters: the executable stage verifier is a parameter of L18's instance), and `SegComplete` from its
  two contracts (the frame decodes back, the stage verifier accepts the honest segment);
* `StageOutP`, `outSegP`, `StageOutOK`, **`outSeg_complete`**: the same for stage OUT-C;
* `D12aBlockP`, **`d12aBlockSegP`**: the honest block part of the D12a run for ANY block profile `Pk` (R13: the media
  app's, A25; W16R2 the same definition): the prover's check that the carry it is handed is its own (finding L25-1),
  `HonestClassifyBlock.lean`'s `coreProve` on the run's frame, the boundary audit, the D12a segment `encSeg` (L17), the
  carry;
* `D12aBlockOK`, **`d12a_block_complete`**: its `SegComplete` against L18's `d12aBlockProf` (L17's `decodeSegment`,
  L9's `blockVerify`), from the codec (`decodeSegment_enc` discharges it from the canonical words and the segment's
  shape: `d12a_codec_of_enc`), the block core's contracts (`blockVerify_of_prove`), the paths and statement checks,
  and the boundary opening's completeness;
* `honestRunP`, **`parts_complete`**: the run's honest parts `inC :: blocks ++ [outC]` meet ClassifyOpen's field O8
  (`List.Forall₂ (SegComplete …) (P.parts V.L) V.parts`) once each part's contract holds; **`classify_parts`**: in
  EXACTLY the form `AssembleClassify.lean` names, at the classify protocol's `adm`, `liftH` and `clsStmtOf`;
* **`proveSegs_refuses`**, **`honestSegs_refuses`**, **`d12aBlockSegP_refuses`**: the honest run refuses only where
  stage IN-C, a block or stage OUT-C refuses at its own state, and a D12a block part refuses only where the carry is not
  its own, its core refuses (`coreProve_refuses`: a slot's `define`, `c = 0`, a degenerate `e`, a schedule failure,
  `check_opening` of `A` / `H`) or the boundary audit refuses;
* **`classify_refuse_of_cover`**: ClassifyOpen's field O9 in its exact form, from the cover of the run's refusals by
  the listed sites.
-/
import ZK60Formal.HonestClassifyBlock
import ZK60Formal.ProtocolClassifyR13

set_option autoImplicit false

namespace ZK60.HonestClassify

open ZK60 ZK60.Exec ZK60.TokenRun ZK60.ProtocolClassify
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (posTag BlockParams Core Segment SegGeom encSeg decodeSegment)

/-! ## Stage IN-C -/

section Stages

variable {St X Coins : Type}

/-- **Stage IN-C's honest part**: its prover (the segment, the claims it leaves pending on `B_in` and `B_in`'s root,
the transcript after it; `.error ()` a refusal) and its frame encoder (binding, start tag, segment, end tag). -/
structure StageInP (St X Coins : Type) (I : StageInV St) where
  prove : (HIn → Dig) → St → X → Coins → Tr → Except Unit (I.Seg × (List Block.ZClaim × Dig) × Tr)
  encode : St → Dig → Dig → I.Seg → Dig → List UInt8

/-- Stage IN-C's honest segment, framed (the run's prover: the bytes as a function of the end tag). -/
def inSegP (I : StageInV St) (p : StageInP St X Coins I) : SegP St X Coins where
  run H s x c bnd start _ t :=
    p.prove H s x c t >>= fun r => .ok (fun e => p.encode s bnd start r.1 e, ⟨r.2.1.1, r.2.1.2⟩, r.2.2)

/-- **Stage IN-C's two contracts**: on every honest run, the frame decodes back (at the verifier's binding and start
tag) and the stage verifier accepts the honest segment, with the prover's pending claims, root and transcript. -/
def StageInOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St) (I : StageInV St)
    (p : StageInP St X Coins I) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (t : Tr) (seg : I.Seg) (pr : List Block.ZClaim × Dig) (t' : Tr), adm x →
    p.prove (hOf g) (stOf g x c) x c t = .ok (seg, pr, t') →
      I.decode (stOf g x c) (p.encode (stOf g x c) bnd (posTag (hOf g) t) seg (posTag (hOf g) t')) bnd
          (posTag (hOf g) t) = .ok (seg, posTag (hOf g) t')
        ∧ I.verify (hOf g) (stOf g x c) seg t = .ok (pr, t')

/-- **Stage IN-C's `SegComplete`** from its two contracts. -/
theorem inSeg_complete {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (I : StageInV St) (p : StageInP St X Coins I) (hp : StageInOK adm hOf stOf I p) :
    SegComplete adm hOf stOf (inSegP I p) (inSeg I) := by
  intro g x c bnd cr t enc cr' t' hx hrun
  obtain ⟨⟨seg, pr, t₁⟩, hpr, hk⟩ := (ex_bind_ok_iff _ _ _).mp hrun
  simp only [Except.ok.injEq, Prod.mk.injEq] at hk
  obtain ⟨rfl, rfl, rfl⟩ := hk
  obtain ⟨hdec, hver⟩ := hp g x c bnd t seg pr t₁ hx hpr
  dsimp only [inSeg]
  refine bind_ok_of hdec ?_
  refine bind_ok_of hver ?_
  rfl

/-! ## Stage OUT-C -/

/-- **Stage OUT-C's honest part**: its prover (from the carry: the last boundary's root and the pending claims) and
its frame encoder. -/
structure StageOutP (St X Coins : Type) (O : StageOutV St) where
  prove : (HIn → Dig) → St → X → Coins → Carry → Tr → Except Unit (O.Seg × Tr)
  encode : St → Dig → Dig → O.Seg → Dig → List UInt8

def outSegP (O : StageOutV St) (p : StageOutP St X Coins O) : SegP St X Coins where
  run H s x c bnd start cr t := p.prove H s x c cr t >>= fun r => .ok (fun e => p.encode s bnd start r.1 e, cr, r.2)

/-- **Stage OUT-C's two contracts**: the frame decodes back, and `stage_out_c::verify` accepts the honest segment on
the carry (the last boundary's root, the pending claims) with the prover's transcript. -/
def StageOutOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St) (O : StageOutV St)
    (p : StageOutP St X Coins O) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (cr : Carry) (t : Tr) (seg : O.Seg) (t' : Tr), adm x →
    p.prove (hOf g) (stOf g x c) x c cr t = .ok (seg, t') →
      O.decode (stOf g x c) (p.encode (stOf g x c) bnd (posTag (hOf g) t) seg (posTag (hOf g) t')) bnd
          (posTag (hOf g) t) = .ok (seg, posTag (hOf g) t')
        ∧ O.verify (hOf g) (stOf g x c) seg cr.root cr.pending t = .ok t'

/-- **Stage OUT-C's `SegComplete`** from its two contracts. -/
theorem outSeg_complete {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (O : StageOutV St) (p : StageOutP St X Coins O) (hp : StageOutOK adm hOf stOf O p) :
    SegComplete adm hOf stOf (outSegP O p) (outSeg O) := by
  intro g x c bnd cr t enc cr' t' hx hrun
  obtain ⟨⟨seg, t₁⟩, hpr, hk⟩ := (ex_bind_ok_iff _ _ _).mp hrun
  simp only [Except.ok.injEq, Prod.mk.injEq] at hk
  obtain ⟨rfl, rfl, rfl⟩ := hk
  obtain ⟨hdec, hver⟩ := hp g x c bnd cr t seg t₁ hx hpr
  dsimp only [outSeg]
  refine bind_ok_of hdec ?_
  refine bind_ok_of hver ?_
  rfl

end Stages

/-! ## A block of the D12a run -/

section Block

variable {St X Coins : Type} (Pk : ℕ → BlockParams) (sgeom : St → ℕ → SegGeom)
  (check : St → ℕ → Except String Unit) (paths : St → Segment → Except String Unit)
  (digest : St → ℕ → Dig) (bRows bLogN : ℕ → ℕ) (bndCheck : St → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **The honest data of the run's blocks**: block `k`'s boundary root `B_{k+1}` (the Merkle root of its honest output
plane under the coins), its core's honest data (`CoreData`, at block `k`'s own `BlockParams`), the honest opening of
the PREVIOUS boundary (the code's `powner.into_opening`: the prover's OWN previous boundary, recomputed from the input
and the coins, on the claims `pending ++ io_in` and the transcript after the core), and the prover's check that the
carry it is handed is its own (`own`: the previous boundary's root is its own and the pending claims are true of its
own plane; finding L25-1: without it no prover meets L18's `SegComplete`, which quantifies over every carry). -/
structure D12aBlockP (St X Coins : Type) (Pk : ℕ → BlockParams) where
  root : (HIn → Dig) → St → X → Coins → ℕ → Dig
  core : (HIn → Dig) → St → X → Coins → (k : ℕ) → CoreData (Pk k)
  inOpen : (HIn → Dig) → St → X → Coins → ℕ → Dig → List Block.ZClaim → Tr → Block.OpeningZk × Tr
  own : (HIn → Dig) → St → X → Coins → ℕ → Carry → Bool

/-- The frame the run's block `k` is proved on (L18's `blockFrame` of the D12a profile at the honest root). -/
def d12aFrame (p : D12aBlockP St X Coins Pk) (H : HIn → Dig) (s : St) (x : X) (c : Coins) (k : ℕ) (t : Tr) : Tr :=
  blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k (p.root H s x c k) t

/-- **The honest block part of the D12a run** (`prove_classify_run_with`'s block arm): the framing, the core's honest
prover, the boundary audit (refused as the verifier refuses), the opening of the previous boundary, the segment
`HLPRUNS1` (`encSeg`: `B_{k+1}`'s root, the core, the incoming opening, no output opening), the carry
`(io_out, B_{k+1})`. -/
def d12aBlockSegP (p : D12aBlockP St X Coins Pk) (k : ℕ) : SegP St X Coins where
  run H s x c bnd start cr t :=
    if p.own H s x c k cr then
      match coreProve H (Pk k) (p.core H s x c k)
          (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p H s x c k t) with
      | .error _ => .error ()
      | .ok R =>
        match bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 with
        | .error _ => .error ()
        | .ok _ =>
          .ok (fun e => encSeg bnd (sgeom s k).l (sgeom s k).k start
                ⟨some (p.root H s x c k), R.core, (p.inOpen H s x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).1,
                  none⟩ e,
            ⟨R.acc.claims.out, p.root H s x c k⟩, (p.inOpen H s x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).2)
    else .error ()

variable {K : Type} [Field K] [Algebra GF K] (U : K)

/-- **The D12a block part's contracts** on every honest run of block `k` (the core run `R` the prover computed and the
boundary audit it passed): the statement check, the codec (the honest segment decodes back at every start and end
tag: `d12a_codec_of_enc` from L17's `decodeSegment_enc`), the paths' depth, the core's contracts of
`blockVerify_of_prove` (the degrees, the pre-checks, the openings' depths, `SlotsSum`, `M`, `A`, `H`), and the boundary
opening's completeness. -/
def D12aBlockOK {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (p : D12aBlockP St X Coins Pk) (k : ℕ) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (cr : Carry) (t : Tr) (R : CoreRun), adm x →
    p.own (hOf g) (stOf g x c) x c k cr = true →
    coreProve (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
        (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t) = .ok R →
    bndCheck (stOf g x c) k (cr.pending ++ R.acc.claims.inp) R.t7 = .ok () →
      check (stOf g x c) k = .ok ()
      ∧ (∀ start e, decodeSegment (sgeom (stOf g x c) k) bnd start
          (encSeg bnd (sgeom (stOf g x c) k).l (sgeom (stOf g x c) k).k start
            ⟨some (p.root (hOf g) (stOf g x c) x c k), R.core,
              (p.inOpen (hOf g) (stOf g x c) x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).1, none⟩ e)
          = .ok (⟨some (p.root (hOf g) (stOf g x c) x c k), R.core,
              (p.inOpen (hOf g) (stOf g x c) x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).1, none⟩, e))
      ∧ paths (stOf g x c) ⟨some (p.root (hOf g) (stOf g x c) x c k), R.core,
          (p.inOpen (hOf g) (stOf g x c) x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).1, none⟩ = .ok ()
      ∧ (∀ s, 1 ≤ slotD (Pk k) s ∧ slotD (Pk k) s < gP) ∧ (Pk k).preChecks = .ok ()
      ∧ Block.pathsDepth "A" (Pk k).aPath 0 R.core.aOpen.columns = .ok ()
      ∧ Block.pathsDepth "H" (Pk k).hPath 0 R.core.hOpen.columns = .ok ()
      ∧ Block.pathsDepth "M" (Pk k).maskPath 0 R.core.maskOpen.columns = .ok ()
      ∧ SlotsSum (hOf g) (Pk k) U (p.core (hOf g) (stOf g x c) x c k).slot
          (coreB (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
            (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t)).1
          (coreG (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
            (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t)).1
          (coreA (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
            (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t)).1
          (Pk k).geom.slots.length [] 0 {}
          (coreT3 (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
            (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t))
      ∧ (Pk k).maskVerify (hOf g) (p.core (hOf g) (stOf g x c) x c k).maskRoot (R.acc.fs ++ R.acc.hostFs)
          R.core.maskOpen R.t4 = .ok R.t5
      ∧ (Pk k).pcsVerify (hOf g) .a (p.core (hOf g) (stOf g x c) x c k).aRoot R.acc.claims.a R.core.aOpen R.t5
          = .ok R.t6
      ∧ (Pk k).pcsVerify (hOf g) .h R.core.hRoot (R.acc.claims.h ++ [(Pk k).logupSumClaim]) R.core.hOpen R.t6
          = .ok R.t7
      ∧ bndOpen (hOf g) (stOf g x c) k cr.root (cr.pending ++ R.acc.claims.inp)
          (p.inOpen (hOf g) (stOf g x c) x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).1 R.t7
        = .ok (p.inOpen (hOf g) (stOf g x c) x c k cr.root (cr.pending ++ R.acc.claims.inp) R.t7).2

/-- **The codec contract from L17's `decodeSegment_enc`**: a canonical honest segment of the verifier's geometry,
committing a boundary and closing no output (a block of the run), of the counted length at every start and end tag,
decodes back. -/
theorem d12a_codec_of_enc (s : SegGeom) (hgt : s.g.slots.length = s.g.terms.length) (hdom : s.g.maskDom ≤ 2 ^ 64)
    (henc : s.g.blk.encCols ≤ 2 ^ 64) (hee : s.ed.encCols ≤ 2 ^ 64) (bnd : Dig) (root : Dig) (core : Core)
    (io : Block.OpeningZk) (hcan : Block.CoreCanon core) (hsh : Block.CoreShape s.g core) (hcm : s.commits = true)
    (hic : Block.HidingCanon io) (his : Block.HidingShape s.ed s.incoming.1 s.incoming.2 io) (hcl : s.closes = false)
    (hlen : ∀ start e, (encSeg bnd s.l s.k start ⟨some root, core, io, none⟩ e).length = s.len)
    (hceil : s.len ≤ s.g.ceiling) (start e : Dig) :
    decodeSegment s bnd start (encSeg bnd s.l s.k start ⟨some root, core, io, none⟩ e)
      = .ok (⟨some root, core, io, none⟩, e) :=
  Block.decodeSegment_enc s hgt hdom henc hee bnd start ⟨some root, core, io, none⟩ e hcan hsh (by simp [hcm]) hic his
    (by simp [hcl]) (fun o ho => by simp at ho) (hlen start e) hceil

variable (hU : U ^ 2 = algebraMap GF K 7)
include hU

/-- **The D12a block part's `SegComplete`** (O8 for a block of the run, at ANY block profile `Pk`: R13 the media
app's): from its contracts, the verifier's block step (L18's `blockSeg` of `d12aBlockProf`: the statement check,
L17's `decodeSegment`, the paths, `B_{k+1}`, the framing, L9's `blockVerify`, the boundary audit and opening) accepts
the honest segment with the prover's carry and transcript. -/
theorem d12a_block_complete {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (p : D12aBlockP St X Coins Pk) (k : ℕ)
    (hp : D12aBlockOK Pk sgeom check paths digest bRows bLogN bndCheck bndOpen U adm hOf stOf p k) :
    SegComplete adm hOf stOf (d12aBlockSegP Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p k)
      (blockSeg (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) k) := by
  intro g x c bnd cr t enc cr' t' hx hrun
  have hrun' := hrun
  simp only [d12aBlockSegP] at hrun'
  cases hown : p.own (hOf g) (stOf g x c) x c k cr with
  | false => simp [hown] at hrun'
  | true =>
    cases hR : coreProve (hOf g) (Pk k) (p.core (hOf g) (stOf g x c) x c k)
        (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p (hOf g) (stOf g x c) x c k t) with
    | error e => simp [hown, hR] at hrun'
    | ok R =>
      cases hbc : bndCheck (stOf g x c) k (cr.pending ++ R.acc.claims.inp) R.t7 with
      | error e => simp [hown, hR, hbc] at hrun'
      | ok u =>
        simp only [hown, hR, hbc, ↓reduceIte] at hrun'
        simp only [Except.ok.injEq, Prod.mk.injEq] at hrun'
        obtain ⟨rfl, rfl, rfl⟩ := hrun'
        cases u
        obtain ⟨hchk, hdec, hpath, hdeg, hpre, hpA, hpH, hpM, hsl, hM, hA, hH, hbo⟩ :=
          hp g x c bnd cr t R hx hown hR hbc
        have hcore := blockVerify_of_prove (hOf g) (Pk k) U hU _ _ R hR hdeg hpre hpA hpH hpM hsl hM hA hH
        dsimp only [blockSeg, d12aBlockProf]
        refine bind_ok_of hchk ?_
        refine bind_ok_of (hdec _ _) ?_
        refine bind_ok_of hpath ?_
        refine bind_ok_of (a := p.root (hOf g) (stOf g x c) x c k) rfl ?_
        refine bind_ok_of hcore ?_
        refine bind_ok_of hbc ?_
        refine bind_ok_of hbo ?_
        rfl

omit [Algebra GF K] hU in
/-- **A D12a block part refuses only where its core refuses** (`coreProve_refuses`: a slot's `define`, `c = 0`, a
degenerate `e`, a schedule failure, the functional count, `check_opening` of `A` / `H`) **or the boundary audit
refuses** (`boundary::check_opening`: the audit and its challenge refusals). -/
theorem d12aBlockSegP_refuses (p : D12aBlockP St X Coins Pk) (k : ℕ) (H : HIn → Dig) (s : St) (x : X) (c : Coins)
    (bnd start : Dig) (cr : Carry) (t : Tr)
    (h : (d12aBlockSegP Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p k).run H s x c bnd start cr t
      = .error ()) :
    p.own H s x c k cr = false
      ∨ coreProve H (Pk k) (p.core H s x c k)
          (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p H s x c k t) = .error ()
      ∨ ∃ R, coreProve H (Pk k) (p.core H s x c k)
          (d12aFrame Pk sgeom check paths digest bRows bLogN bndCheck bndOpen p H s x c k t) = .ok R
        ∧ ∃ e, bndCheck s k (cr.pending ++ R.acc.claims.inp) R.t7 = .error e := by
  simp only [d12aBlockSegP] at h
  split at h
  · split at h
    · rename_i e he
      cases e
      exact Or.inr (Or.inl he)
    · rename_i R hR
      split at h
      · rename_i e he
        exact Or.inr (Or.inr ⟨R, hR, e, he⟩)
      · cases h
  · rename_i hown
    exact Or.inl (ff_of_not hown)

end Block

/-! ## The run's honest parts, and O8 -/

section Run

variable {Hdr X Coins : Type}

/-- **The run's honest prover's parts** (`RunP`): the registered header, stage IN-C's, the blocks', stage OUT-C's
honest parts, and the ONE refusal output (D65(2)). -/
def honestRunP (hdr : Hdr) (refused : ClsStmt Hdr) (inC : SegP (ClsStmt Hdr) X Coins)
    (blk : ℕ → SegP (ClsStmt Hdr) X Coins) (outC : SegP (ClsStmt Hdr) X Coins) : RunP Hdr X Coins :=
  ⟨hdr, inC, blk, outC, refused⟩

/-- `List.Forall₂` keeps one more related pair at the end. -/
theorem forall₂_append_single {α β : Type} {R : α → β → Prop} {a : α} {b : β} (hab : R a b) :
    ∀ {l₁ : List α} {l₂ : List β}, List.Forall₂ R l₁ l₂ → List.Forall₂ R (l₁ ++ [a]) (l₂ ++ [b])
  | _, _, .nil => List.Forall₂.cons hab List.Forall₂.nil
  | _, _, .cons h1 h2 => List.Forall₂.cons h1 (forall₂_append_single hab h2)

/-- `List.Forall₂` over a mapped list of indices. -/
theorem forall₂_map_range {α β : Type} (R : α → β → Prop) (f : ℕ → α) (g : ℕ → β) (L : ℕ) :
    ∀ (l : List ℕ), (∀ k ∈ l, k < L) → (∀ k, k < L → R (f k) (g k)) → List.Forall₂ R (l.map f) (l.map g)
  | [], _, _ => List.Forall₂.nil
  | k :: l, hl, h2 => List.Forall₂.cons (h2 k (hl k List.mem_cons_self))
      (forall₂_map_range R f g L l (fun j hj => hl j (List.mem_cons_of_mem _ hj)) h2)

/-- `List.Forall₂` over the run's parts from the parts' own relations. -/
theorem forall₂_parts {α β : Type} (R : α → β → Prop) (a : α) (b : β) (f : ℕ → α) (g : ℕ → β) (a' : α) (b' : β)
    (L : ℕ) (h1 : R a b) (h2 : ∀ k, k < L → R (f k) (g k)) (h3 : R a' b') :
    List.Forall₂ R (a :: ((List.range L).map f ++ [a'])) (b :: ((List.range L).map g ++ [b'])) :=
  List.Forall₂.cons h1 (forall₂_append_single h3
    (forall₂_map_range R f g L (List.range L) (fun _ hk => List.mem_range.mp hk) h2))

/-- **ClassifyOpen's field O8 from the parts' contracts** (generic): the honest run's parts in the verifier's order
(`P.parts V.L`) and the verifier's parts (`V.parts`) are related part by part by `SegComplete`. -/
theorem parts_complete {Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → ClsStmt Hdr)
    (V : RunV Hdr) (P : RunP Hdr X Coins)
    (hin : SegComplete adm hOf stOf P.inC (inSeg V.inC))
    (hblk : ∀ k, k < V.L → SegComplete adm hOf stOf (P.blk k) (blockSeg V.blk k))
    (hout : SegComplete adm hOf stOf P.outC (outSeg V.outC)) :
    List.Forall₂ (SegComplete adm hOf stOf) (P.parts V.L) V.parts :=
  forall₂_parts _ _ _ P.blk (blockSeg V.blk) _ _ V.L hin hblk hout

/-- **O8 in EXACTLY the form `AssembleClassify.lean`'s `ClassifyOpen.parts` names**, at the classify protocol's
admissibility, oracle lift `liftH` and honest statement `clsStmtOf`. -/
theorem classify_parts {S : Block.BlockShape} {Salt : Type} (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (hin : SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) P.inC (inSeg V.inC))
    (hblk : ∀ k, k < V.L →
      SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) (P.blk k) (blockSeg V.blk k))
    (hout : SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) P.outC
      (outSeg V.outC)) :
    List.Forall₂ (SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base))
      (P.parts V.L) V.parts :=
  parts_complete _ _ _ V P hin hblk hout

/-- **O8 for the D12a classify run** (the media app's: R13 blocks through `d12aBlockProf`; W16R2 the same), in EXACTLY
`ClassifyOpen.parts`' form: the honest run's parts are stage IN-C's honest part, the D12a honest block parts and stage
OUT-C's honest part; then O8 holds from stage IN-C's two contracts, each block's `D12aBlockOK` and stage OUT-C's two
contracts. -/
theorem classify_parts_d12a {S : Block.BlockShape} {Salt K : Type} [Field K] [Algebra GF K] (U : K)
    (hU : U ^ 2 = algebraMap GF K 7) (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (Pk : ℕ → BlockParams) (sgeom : ClsStmt Hdr → ℕ → SegGeom)
    (check : ClsStmt Hdr → ℕ → Except String Unit) (paths : ClsStmt Hdr → Segment → Except String Unit)
    (digest : ClsStmt Hdr → ℕ → Dig) (bRows bLogN : ℕ → ℕ)
    (bndCheck : ClsStmt Hdr → ℕ → List Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → ClsStmt Hdr → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)
    (hV : V.blk = d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen)
    (pin : StageInP (ClsStmt Hdr) (S.Tok → ℕ) Coins V.inC) (pblk : D12aBlockP (ClsStmt Hdr) (S.Tok → ℕ) Coins Pk)
    (pout : StageOutP (ClsStmt Hdr) (S.Tok → ℕ) Coins V.outC)
    (hPin : P.inC = inSegP V.inC pin)
    (hPblk : P.blk = d12aBlockSegP Pk sgeom check paths digest bRows bLogN bndCheck bndOpen pblk)
    (hPout : P.outC = outSegP V.outC pout)
    (hin : StageInOK (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) V.inC pin)
    (hblk : ∀ k, k < V.L → D12aBlockOK Pk sgeom check paths digest bRows bLogN bndCheck bndOpen U
      (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) pblk k)
    (hout : StageOutOK (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base) V.outC pout) :
    List.Forall₂ (SegComplete (classifyModel S R).admissible liftH (clsStmtOf R Lq P Cin h64 hr base))
      (P.parts V.L) V.parts := by
  refine classify_parts R Lq V P Cin h64 hr base ?_ (fun k hk => ?_) ?_
  · rw [hPin]
    exact inSeg_complete _ _ _ V.inC pin hin
  · rw [hPblk, hV]
    exact d12a_block_complete Pk sgeom check paths digest bRows bLogN bndCheck bndOpen U hU _ _ _ pblk k (hblk k hk)
  · rw [hPout]
    exact outSeg_complete _ _ _ V.outC pout hout

/-! ## O9: the honest run refuses only where a part refuses -/

/-- **The honest run of segments refuses only where one of its parts refuses**, at the carry and transcript the
earlier honest parts left. -/
theorem proveSegs_refuses {St : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps : List (SegP St X Coins)) (cr : Carry) (t : Tr), proveSegs H s x c bnd ps cr t = .error () →
      ∃ (j : ℕ) (cr₁ : Carry) (t₁ : Tr) (p : SegP St X Coins), ps[j]? = some p
        ∧ p.run H s x c bnd (posTag H t₁) cr₁ t₁ = .error ()
  | [], _, _, h => by cases h
  | p :: ps, cr, t, h => by
    have h' : (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' => .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2))
        = .error () := h
    cases hp : p.run H s x c bnd (posTag H t) cr t with
    | error e =>
      cases e
      exact ⟨0, cr, t, p, rfl, hp⟩
    | ok r =>
      rw [hp] at h'
      cases hq : proveSegs H s x c bnd ps r.2.1 r.2.2 with
      | error e =>
        cases e
        obtain ⟨j, cr₁, t₁, p₁, hj, hr⟩ := proveSegs_refuses H s x c bnd ps r.2.1 r.2.2 hq
        exact ⟨j + 1, cr₁, t₁, p₁, by simpa using hj, hr⟩
      | ok r' =>
        have e : (proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' =>
            (.ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) : Except Unit _))
            = .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) := by
          rw [hq]
          rfl
        have h'' : (Except.ok r >>= fun r => proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' =>
            (.ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) : Except Unit _)) = .error () := h'
        rw [show (Except.ok r >>= fun r => proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' =>
            (.ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) : Except Unit _))
            = .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2) from e] at h''
        cases h''

/-- **The honest run refuses only where stage IN-C, a block or stage OUT-C refuses**, at the carry and transcript the
earlier honest parts left (`proveSegs_refuses` on the run's parts; a block's refusal is `d12aBlockSegP_refuses`'s). -/
theorem honestSegs_refuses (V : RunV Hdr) (P : RunP Hdr X Coins) (H : HIn → Dig) (root : Dig) (verdict : ℕ) (x : X)
    (c : Coins) (h : honestSegs V P H root verdict x c = .error ()) :
    ∃ (cr₁ : Carry) (t₁ : Tr),
      P.inC.run H (honestStmt P.hdr root verdict) x c (V.start H (honestStmt P.hdr root verdict)).state (posTag H t₁)
          cr₁ t₁ = .error ()
      ∨ (∃ k, k < V.L ∧ (P.blk k).run H (honestStmt P.hdr root verdict) x c
          (V.start H (honestStmt P.hdr root verdict)).state (posTag H t₁) cr₁ t₁ = .error ())
      ∨ P.outC.run H (honestStmt P.hdr root verdict) x c (V.start H (honestStmt P.hdr root verdict)).state
          (posTag H t₁) cr₁ t₁ = .error () := by
  obtain ⟨j, cr₁, t₁, p, hj, hp⟩ := proveSegs_refuses H (honestStmt P.hdr root verdict) x c
    (V.start H (honestStmt P.hdr root verdict)).state (P.parts V.L) carry0 (V.start H (honestStmt P.hdr root verdict)) h
  have hmem := List.mem_of_getElem? hj
  simp only [RunP.parts, List.mem_cons, List.mem_append, List.mem_map, List.mem_range, List.not_mem_nil, or_false] at hmem
  refine ⟨cr₁, t₁, ?_⟩
  rcases hmem with rfl | ⟨k, hk, rfl⟩ | rfl
  · exact Or.inl hp
  · exact Or.inr (Or.inl ⟨k, hk, hp⟩)
  · exact Or.inr (Or.inr hp)

/-- **ClassifyOpen's field O9 in its exact form**, from the cover of the honest run's refusals by the listed sites: if
whenever the honest run refuses some site fires, then whenever no site fires the honest run produces its segments. -/
theorem classify_refuse_of_cover {S : Block.BlockShape} {Salt : Type} [Fintype Coins] [Nonempty Coins]
    (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (hon : HonestIn Coins Cin) {K : Type} [Field K] [DecidableEq K] [Algebra GF K] (U : K)
    {ι : Type} (site : (S.Tok → ℕ) → ι → ProtocolClassify.Site (QB Lq) Coins K)
    (hcover : ∀ x, (classifyModel S R).admissible x → ∀ G c,
      honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c = .error ()
        → ∃ i, (site x i).fires U G c) :
    ∀ x, (classifyModel S R).admissible x → ∀ G c, (∀ i, ¬ (site x i).fires U G c) →
      ∃ r, honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c
        = .ok r := by
  intro x hx G c hno
  cases hs : honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (hon.base c)) ((classifySpec R x).getD 0) x c with
  | ok r => exact ⟨r, rfl⟩
  | error e =>
    cases e
    obtain ⟨i, hi⟩ := hcover x hx G c hs
    exact absurd hi (hno i)

end Run

end ZK60.HonestClassify
