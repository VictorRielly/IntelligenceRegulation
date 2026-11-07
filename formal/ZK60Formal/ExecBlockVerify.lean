/-
D63 step L9 (the per-profile verifier, its top level), part 2: the BLOCK VERIFIER `verify_core`, executable, with the
sub-checks it does not own as FIELDS of a parameter structure.

What is mirrored (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/protocol.rs` `verify_core` (line 2802) and
`argument.rs` `argument_with` / `run_slot`'s verify arm / `build_claim` (lines 1143–1503, 1033), `run_fork.rs`
`verify_one_fork` (line 2730), read 2026-11-07; nothing there is changed), in EXACTLY the code's order of absorbs,
squeezes and checks:
1. the verifier's own shape checks (`P.preChecks`), then T-4: every opened column of `A`, `H`, `M` carries its tree's
   depth;
2. `absorb_root("A")` (the root, `"rows"`, `"log-cols"`), `absorb("M", root)`, the LogUp challenges `β`, `γ`, `α`, then
   `absorb_root("H")`;
3. per slot `s` (`run_slot`): `define`'s challenges (`P.draws s` squeezes; the definition from them is `P.define`, L11's),
   the schedule checks (slot index, private-table count, host-ness, table shapes, public-table lengths), `absorb_u64
   ("pb-slot", s)`, the CFS challenge `c` (refused when zero), the terminal count, `absorb_fp2("pb-scalar")`, the claimed
   sum `scalar + Σ_hosted κ·scalar_h`, L6's `scVerify` over `n + e` rounds of degree `d`, the terminal values `vals`
   (`eq` tables and public tables times `sel = Π(1 − e)`, the private terminals), `g(ρ) = (fin − poly(vals))·c⁻¹`, the
   degenerate-extension refusal, `absorb_fp2("pb-term")`, the claims (`build_claim`) and the `M` functionals;
4. the hosts' functionals after the slots, their count (`P.nFunctionals`);
5. `M`'s test (`P.maskVerify`, L10's), `finish_claims` (`H` closed by `P.logupSumClaim`), `check_opening` and the
   opening of `A` (`P.checkOpening`, `P.pcsVerify`, L10's), then the same for `H`.
`forkVerify` is `verify_one_fork`: the frame decoded against the start position tag of the transcript it is handed,
`blockVerify`, and the end tag compared.

The interface (`BlockParams`): see the field comments and docs/zkmatrix-poc/ZK60_LEAN_L9_BLOCK_VERIFIER_20261107.md §4.
Every field is a function of the verifier's public statement (its shape, its layout, its block statement) and of the
transcript's own values (the history `Hist`), never of anything the receipt carries outside what the code reads.

One modelling step, stated: `define` interleaves its draws with refusals (`nonzero(...)?`); here the draws come first
and `P.define` refuses afterwards. A refusal ends verification either way (the code returns the `Err`), so the verdict
and, on acceptance, the transcript are the code's.

W16R2's specifics are the named definitions of `ExecBlockCheck.lean` / `ExecBlockFS.lean` (`W16R2`); W16R3's B1–B3
change `define`, `draws`, the geometry and `pcsVerify`, i.e. an instance, not this file.
-/
import ZK60Formal.ExecBlockWire
import ZK60Formal.ExecCfs

namespace ZK60.Exec.Block

/-! ## The labels (`b"..."`; `ExecBlockCheck.lean` checks each is `ascii` of its text) -/

def labA : List UInt8 := [65]
def labH : List UInt8 := [72]
def labM : List UInt8 := [77]
def labRows : List UInt8 := [114, 111, 119, 115]
def labLogCols : List UInt8 := [108, 111, 103, 45, 99, 111, 108, 115]
def labPbSlot : List UInt8 := [112, 98, 45, 115, 108, 111, 116]
def labPbScalar : List UInt8 := [112, 98, 45, 115, 99, 97, 108, 97, 114]
def labPbTerm : List UInt8 := [112, 98, 45, 116, 101, 114, 109]
def labMaskQ : List UInt8 := [109, 97, 115, 107, 45, 113]
def labMaskProx : List UInt8 := [109, 97, 115, 107, 45, 112, 114, 111, 120]
def labPcsVec : List UInt8 := [112, 99, 115, 45, 118, 101, 99]
def labPcsProx : List UInt8 := [112, 99, 115, 45, 112, 114, 111, 120]

/-! ## A slot's definition (`argument::SlotDef`, the verifier's side) -/

/-- `argument::Cm`: the commitment a private table lives in. -/
inductive Cm
  | a
  | h
  | inp
  | out
  deriving DecidableEq, Repr

/-- `argument::Coord`: one coordinate of a claim point. -/
inductive Coord
  | rho (k : ℕ)
  | flip (k : ℕ)
  | fixed (v : Fp2)

/-- `argument::Priv`: a private table's slices, size, point, reserved mask pair and extension round. -/
structure Priv where
  cm : Cm
  slices : List (ℕ × Fp2)
  log : ℕ
  coords : List Coord
  maskRow : ℕ
  extRound : ℕ

/-- `argument::Tab`. -/
inductive Tab
  | eq (point : List Fp2) (start : ℕ)
  | pub (v : List Fp2)
  | priv (p : Priv)

def Tab.isPriv : Tab → Bool
  | .priv _ => true
  | _ => false

/-- **`argument::SlotDef`, what the verifier reads of it**: the tables, the round polynomial, the hosted slots with
their coefficients (`ν·κ`). Built by `P.define` (L11's slot arithmetization). -/
structure SlotDef where
  tabs : List Tab
  poly : List Fp2 → Fp2
  hosted : List (ℕ × Fp2)

/-- `layout::SlotKind`. -/
inductive SlotKind
  | priv
  | standalone
  | host
  deriving DecidableEq, Repr

/-! ## Claims and functionals (`pcs::ZClaim`, `zk::MaskFunctional`) -/

structure ZPart where
  offset : ℕ
  logSize : ℕ
  coef : Fp2
  point : List Fp2

structure ZClaim where
  parts : List ZPart
  value : Fp2

structure MaskFunctional where
  terms : List (ℕ × List Fp2)
  value : Fp2

/-- The claims per commitment (`[Vec<ZClaim>; 4]`, indexed by `Cm`). -/
structure Claims4 where
  a : List ZClaim := []
  h : List ZClaim := []
  inp : List ZClaim := []
  out : List ZClaim := []

def Claims4.push (c : Claims4) : Cm → ZClaim → Claims4
  | .a, z => { c with a := c.a ++ [z] }
  | .h, z => { c with h := c.h ++ [z] }
  | .inp, z => { c with inp := c.inp ++ [z] }
  | .out, z => { c with out := c.out ++ [z] }

/-! ## The history: the transcript's own values so far -/

/-- What a verified slot leaves: its `define` draws, `c`, its scalar, its claimed sum, its main and extension
challenges, its terminals, its final value. Every field but `claimed` and `fin` is a challenge of the transcript or a
value it absorbed; `claimed` is computed from them, `fin` from the rounds. -/
structure SlotRec where
  draws : List Fp2
  c : Fp2
  scalar : Fp2
  claimed : Fp2
  rho : List Fp2
  es : List Fp2
  terms : List Fp2
  fin : Fp2

/-- **What `define` may read**: the LogUp challenges and the challenges the earlier slots' `define` drew. CODE
(`argument.rs`, `argument_accuracy.rs`): `define` reads `ctx` (the public statement and `α`, `β`, `γ·TAG`) and `pts`,
and every point of `pts` is set by an earlier `define` from its own draws (`pts.r_t = tr.challenge_fp2_vec(lt)`,
`pts.p_s = cat(&[&r_h, &r_t, &r_j])`, …); nothing a slot verifies flows back into a later definition. -/
structure Hist where
  beta : Fp2
  gamma : Fp2
  alpha : Fp2
  draws : List (List Fp2)

/-- `argument::Acc` (the verifier's part). -/
structure Acc where
  cs : List Fp2 := []
  scalars : List Fp2 := []
  claims : Claims4 := {}
  fs : List MaskFunctional := []
  hostFs : List MaskFunctional := []

/-! ## The interface -/

/-- **The block verifier's parameters.** The geometry and every count are the verifier's own; the functions are the
sub-checks this file does not own:
* `define` (L11): `argument::define`'s definition of slot `s` from the history and the `draws s` challenges it drew;
* `maskVerify` (L10): `zk::mask_verify_tagged` on `M`'s root, the functionals and the opening, consuming the
  transcript;
* `checkOpening` (L10): `protocol::check_opening` (the schedule audit, the group count, the challenge refusals on a
  CLONE of the transcript), for `A` (`Cm.a`) and `H` (`Cm.h`);
* `pcsVerify` (L10): `pcs::verify_zk_tagged` of one commitment, consuming the transcript;
* `logupSumClaim` (L11): `protocol::logup_sum_claim`, the claim that closes `H`. -/
structure BlockParams where
  geom : Geom
  logCols : ℕ
  endpointLogN : ℕ
  aRows : ℕ
  hRows : ℕ
  aPath : ℕ
  hPath : ℕ
  maskPath : ℕ
  preChecks : Except String Unit
  kind : ℕ → SlotKind
  name : ℕ → String
  draws : ℕ → ℕ
  define : ℕ → Hist → List Fp2 → Except String SlotDef
  nFunctionals : ℕ
  logupSumClaim : ZClaim
  maskVerify : (HIn → Dig) → Dig → List MaskFunctional → MaskOpening → Tr → Except String Tr
  checkOpening : (HIn → Dig) → Cm → List ZClaim → Tr → Except String Unit
  pcsVerify : (HIn → Dig) → Cm → Dig → List ZClaim → OpeningZk → Tr → Except String Tr

section Verify

variable (H : HIn → Dig)

def slotShape (P : BlockParams) (s : ℕ) : ℕ × ℕ × ℕ := P.geom.slots.getD s (0, 0, 0)

def slotTerms (P : BlockParams) (s : ℕ) : ℕ := P.geom.terms.getD s 0

/-- `absorb_root`. -/
def absorbRoot (t : Tr) (label : List UInt8) (root : Dig) (rows logCols : ℕ) : Tr :=
  ((t.absorb H label root.toList).absorbU64 H labRows (UInt64.ofNat rows)).absorbU64 H labLogCols (UInt64.ofNat logCols)

/-- `Fp2::U`, the extension's generator `u` (`u² = 7`). -/
def fp2U : Fp2 := ⟨Fp.zero, Fp.one⟩

/-- `row_log`. -/
def rowLog (P : BlockParams) : Cm → ℕ
  | .a | .h => P.logCols
  | _ => P.endpointLogN

/-- `claim_point`. -/
def claimPoint (p : Priv) (rho : List Fp2) : List Fp2 :=
  p.coords.map fun
    | .rho k => rho.getD k Fp2.zero
    | .flip k => Fp2.one.sub (rho.getD k Fp2.zero)
    | .fixed v => v

/-- `build_claim`: `cd·plane~(point) + cm·(R_re + u R_im)(tail)`, the data parts then the reserved pair. -/
def buildClaim (P : BlockParams) (p : Priv) (point : List Fp2) (cd cm value : Fp2) : ZClaim :=
  let logN := rowLog P p.cm
  let n := 2 ^ logN
  let logm := min p.log logN
  let c0 := if p.log < logN then (p.slices.headD (0, Fp2.zero)).1 % n else 0
  let tail := point.drop (p.log - logm)
  let parts := p.slices.map (fun sc => (⟨sc.1, p.log, sc.2.mul cd, point⟩ : ZPart))
  ⟨parts ++ [⟨p.maskRow * n + c0, logm, cm.mul Fp2.one, tail⟩, ⟨(p.maskRow + 1) * n + c0, logm, cm.mul fp2U, tail⟩],
    value⟩

/-- A refusal when `b` holds (the code's `if b { return Err(msg) }`), as one action. -/
def exGuard (b : Bool) (msg : String) : Except String Unit := if b then .error msg else .ok ()

/-- `(1 − e)` products. -/
def oneMinusProd (es : List Fp2) : Fp2 := es.foldl (fun a e => a.mul (Fp2.one.sub e)) Fp2.one

/-- The terminal value of one table (`run_slot`'s `vals`); `k` counts the private tables so far. -/
def tabVal (sel : Fp2) (rho terms : List Fp2) : Tab → ℕ → Except String (Fp2 × ℕ)
  | .eq point start, k =>
    if start + point.length ≤ rho.length then
      match eqPoint point ((rho.drop start).take point.length) with
      | some v => .ok (sel.mul v, k)
      | none => .error "panic: eq_point lengths"
    else .error "panic: rho slice out of range"
  | .pub v, k =>
    match evalMleExt v rho with
    | some x => .ok (sel.mul x, k)
    | none => .error "panic: eval_mle_ext length"
  | .priv _, k => .ok (terms.getD k Fp2.zero, k + 1)

def tabVals (sel : Fp2) (rho terms : List Fp2) : List Tab → ℕ → Except String (List Fp2)
  | [], _ => .ok []
  | t :: ts, k =>
    match tabVal sel rho terms t k with
    | .error e => .error e
    | .ok (v, k') =>
      match tabVals sel rho terms ts k' with
      | .error e => .error e
      | .ok vs => .ok (v :: vs)

/-- `es[ext_round + 1..].fold(es[ext_round], |a, e| a·(1 − e))`, as the code folds it. -/
def maskCoef (es : List Fp2) (r : ℕ) : Fp2 := (es.drop (r + 1)).foldl (fun a e => a.mul (Fp2.one.sub e)) (es.getD r Fp2.zero)

/-- The claims of the slot's private tables, in table order. -/
def slotClaims (P : BlockParams) (rho es terms : List Fp2) : List Tab → ℕ → Claims4 → Claims4
  | [], _, cl => cl
  | .priv p :: ts, k, cl =>
    let cd := oneMinusProd es
    let cm := maskCoef es p.extRound
    slotClaims P rho es terms ts (k + 1) (cl.push p.cm (buildClaim P p (claimPoint p rho) cd cm (terms.getD k Fp2.zero)))
  | _ :: ts, k, cl => slotClaims P rho es terms ts k cl

/-- The hosted sum `scalar + Σ κ·scalar_h` (an index past the scalars so far is the code's panic). -/
def hostedSum (scalars : List Fp2) (scalar : Fp2) : List (ℕ × Fp2) → Except String Fp2
  | [] => .ok scalar
  | (hs, coef) :: rest =>
    if hs < scalars.length then hostedSum scalars (scalar.add (coef.mul (scalars.getD hs Fp2.zero))) rest
    else .error "panic: hosted slot index"

/-- `run_slot`'s schedule checks on a definition (slot index, private-table count, host-ness; table shapes; public
table lengths), with the code's refusals. -/
def slotDefChecks (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) : Except String Unit :=
  let nd := slotShape P s
  let nPriv := (df.tabs.filter Tab.isPriv).length
  if decide (s ≠ acc.cs.length) || decide (nPriv ≠ slotTerms P s)
      || (decide (P.kind s = SlotKind.host) == df.hosted.isEmpty) then
    .error s!"private block: slot {s} differs from the declared schedule"
  else if df.tabs.any (fun tb => match tb with
      | .priv p => decide (nd.2.1 ≤ p.extRound) || decide (p.coords.length ≠ p.log)
      | _ => false) then .error s!"private block: slot {s} table shape"
  else if df.tabs.any (fun tb => match tb with | .pub v => decide (v.length ≠ 2 ^ nd.1) | _ => false) then
    .error s!"private block: slot {s} public table length"
  else .ok ()

/-- The slot's accumulator after a verified slot: `c`, the scalar, the claims, the `M` functionals (`[Γ_s if
standalone] eval_s`, a host's `Γ` kept for after the slots). -/
def slotAcc (P : BlockParams) (s : ℕ) (acc : Acc) (df : SlotDef) (c scalar gVal : Fp2) (rhoFull terms : List Fp2) : Acc :=
  let nd := slotShape P s
  let n := nd.1
  let e := nd.2.1
  let d := nd.2.2
  let rho := rhoFull.take n
  let es := rhoFull.drop n
  let claims := slotClaims P rho es terms df.tabs 0 acc.claims
  let sw := (Cfs.sumWeights (n + e) d).map (fun w => w.mul c)
  let fs1 := match P.kind s with
    | .standalone => acc.fs ++ [⟨[(s, sw)], scalar⟩]
    | _ => acc.fs
  let hostFs := match P.kind s with
    | .host => acc.hostFs ++ [⟨(s, sw) :: df.hosted.map (fun hk =>
        (hk.1, (Cfs.sumWeights (n + e) d).map (fun w => w.mul (hk.2.mul (acc.cs.getD hk.1 Fp2.zero)).neg))), scalar⟩]
    | _ => acc.hostFs
  ⟨acc.cs ++ [c], acc.scalars ++ [scalar], claims, fs1 ++ [⟨[(s, Cfs.evalWeights rhoFull d)], gVal⟩], hostFs⟩

/-- `sumcheck::verify`'s verdict, its refusal named by the slot (`format!("slot {s} [{}]: {e}", SLOT_NAMES[s])`). -/
def scCheck (s : ℕ) (nm : String) : Except ScErr (Fp2 × List Fp2) → Except String (Fp2 × List Fp2)
  | .ok r => .ok r
  | .error err => .error s!"slot {s} [{nm}]: {err.msg}"

/-- **One slot** (`define`'s draws, then `run_slot`'s verify arm), on the transcript `t`. -/
def slotStep (P : BlockParams) (s : ℕ) (hist : Hist) (sp : SlotProof) (acc : Acc) (t : Tr) :
    Except String (SlotRec × Acc × Tr) := do
  let nd := slotShape P s
  let n := nd.1
  let e := nd.2.1
  let d := nd.2.2
  let dr := t.challengeFp2Vec H (P.draws s)
  let df ← P.define s hist dr.1
  slotDefChecks P s acc df
  let nPriv := (df.tabs.filter Tab.isPriv).length
  let t2 := dr.2.absorbU64 H labPbSlot (UInt64.ofNat s)
  let ct := t2.challengeFp2 H
  let c := ct.1
  exGuard c.isZero "zero CFS mask challenge; discard attempt"
  exGuard (decide (sp.terms.length ≠ nPriv)) s!"private block: slot {s} terminal count"
  let t4 := ct.2.absorbFp2 H labPbScalar [sp.scalar]
  let claimed ← hostedSum acc.scalars sp.scalar df.hosted
  let sv := scVerify H claimed d (n + e) sp.rounds t4
  let fr ← scCheck s (P.name s) sv.1
  let fin := fr.1
  let rhoFull := fr.2
  let rho := rhoFull.take n
  let es := rhoFull.drop n
  let vals ← tabVals (oneMinusProd es) rho sp.terms df.tabs 0
  let gVal := (fin.sub (df.poly vals)).mul c.inv
  exGuard (es.any (fun x => x.isZero || decide (x = Fp2.one))) "degenerate terminal mask challenge; discard attempt"
  let t6 := sv.2.absorbFp2 H labPbTerm sp.terms
  pure (⟨dr.1, c, sp.scalar, claimed, rho, es, sp.terms, fin⟩, slotAcc P s acc df c sp.scalar gVal rhoFull sp.terms, t6)

/-- The history `define` sees at the next slot. -/
def histOf (b g a : Fp2) (recs : List SlotRec) : Hist := ⟨b, g, a, recs.map SlotRec.draws⟩

/-- **`argument`'s slot loop**: the slots in order, the verified slots' records growing. -/
def slotsLoop (P : BlockParams) (b g a : Fp2) :
    List SlotRec → ℕ → List SlotProof → Acc → Tr → Except String (List SlotRec × Acc × Tr)
  | recs, _, [], acc, t => .ok (recs, acc, t)
  | recs, s, sp :: sps, acc, t =>
    match slotStep H P s (histOf b g a recs) sp acc t with
    | .error e => .error e
    | .ok (r, acc', t') => slotsLoop P b g a (recs ++ [r]) (s + 1) sps acc' t'

/-- T-4 for one opening (`paths_are_the_tree_depth`), from column `i`. -/
def pathsDepth (what : String) (depth : ℕ) : ℕ → List Column → Except String Unit
  | _, [] => .ok ()
  | i, c :: cs =>
    if c.path.length ≠ depth then
      .error s!"private block: opened column {i} of the {what} commitment carries a Merkle path of {c.path.length} entries; this commitment's tree is {depth} deep (T-4)"
    else pathsDepth what depth (i + 1) cs

/-- The part of `verify_core` up to the end of the slot loop: the header absorbs and squeezes, then every slot. The
Fiat–Shamir theorem of `ExecBlockFS.lean` is about this part (L8-6: what follows changes no slot's state). -/
def blockSlots (P : BlockParams) (core : Core) (t : Tr) : Except String ((Fp2 × Fp2 × Fp2) × List SlotRec × Acc × Tr) :=
  let t1 := absorbRoot H t labA core.aRoot P.aRows P.logCols
  let t2 := t1.absorb H labM core.maskRoot.toList
  let b := t2.challengeFp2 H
  let g := b.2.challengeFp2 H
  let a := g.2.challengeFp2 H
  let t3 := absorbRoot H a.2 labH core.hRoot P.hRows P.logCols
  match slotsLoop H P b.1 g.1 a.1 [] 0 core.slots {} t3 with
  | .ok r => .ok ((b.1, g.1, a.1), r)
  | .error e => .error e

/-- **`verify_core`**: the IO claims it computed and the transcript after it. -/
def blockVerify (P : BlockParams) (core : Core) (t : Tr) : Except String ((List ZClaim × List ZClaim) × Tr) := do
  P.preChecks
  pathsDepth "A" P.aPath 0 core.aOpen.columns
  pathsDepth "H" P.hPath 0 core.hOpen.columns
  pathsDepth "M" P.maskPath 0 core.maskOpen.columns
  let (_, _, acc, t) ← blockSlots H P core t
  let fs := acc.fs ++ acc.hostFs
  if fs.length ≠ P.nFunctionals then throw "private block: functional count differs from the declared schedule"
  let t ← match P.maskVerify H core.maskRoot fs core.maskOpen t with
    | .ok t => pure t
    | .error e => throw s!"M: {e}"
  let hc := acc.claims.h ++ [P.logupSumClaim]
  P.checkOpening H .a acc.claims.a t
  let t ← match P.pcsVerify H .a core.aRoot acc.claims.a core.aOpen t with
    | .ok t => pure t
    | .error e => throw s!"A: {e}"
  P.checkOpening H .h hc t
  let t ← match P.pcsVerify H .h core.hRoot hc core.hOpen t with
    | .ok t => pure t
    | .error e => throw s!"H: {e}"
  pure ((acc.claims.inp, acc.claims.out), t)

/-- `run::position_tag`: two `challenge_fp2` of a clone, as 32 bytes. -/
def posTag (t : Tr) : Dig :=
  let a := t.challengeFp2 H
  let b := a.2.challengeFp2 H
  ⟨a.1.toBytes ++ b.1.toBytes, by simp [fp2_toBytes_length]⟩

/-- **`verify_one_fork`**: fork `k`'s frame against the transcript `t` it starts from. -/
def forkVerify (P : BlockParams) (bindg : Dig) (l k : ℕ) (t : Tr) (bytes : List UInt8) :
    Except String ((List ZClaim × List ZClaim) × Tr) := do
  let (core, endTag) ← decodeFork P.geom bindg l k (posTag H t) bytes
  let (io, t') ← blockVerify H P core t
  if posTag H t' ≠ endTag then throw s!"fork {k}'s end tag is not the verifier's own fork-{k} position"
  pure (io, t')

/-! ## The openings' transcript schedules (the part of L10's checks that moves the transcript)

`maskTranscript` and `pcsTranscript` are the transcript operations of `zk::mask_verify_tagged` and
`pcs::verify_zk_tagged`, in their order, with their column-index checks; `openingChallenges` is `protocol.rs`'s
`check_opening_challenges` on a clone. L10's full checks must move the transcript exactly as these do (the agreement
check `ExecBlockCheck.lean` replays them against the code's challenges). The arithmetic (the combined functional, the
`⟨v, c⟩` claims, the Merkle paths, the coset-NTT column checks) is not here. -/

/-- `determinant` (`protocol.rs`): `a.c0·b.c1 − a.c1·b.c0`. -/
def det (a b : Fp2) : Fp := (a.c0.mul b.c1).sub (a.c1.mul b.c0)

/-- `count` member coefficients of one group, refused at the first zero (`any` stops there). -/
def groupDraws : ℕ → Tr → Except String Tr
  | 0, t => .ok t
  | n + 1, t =>
    let r := t.challengeFp2 H
    if r.1.isZero then .error "zero group member coefficient; discard attempt" else groupDraws n r.2

/-- **`check_opening_challenges`** on a CLONE of the transcript (the caller's transcript does not move). -/
def openingChallenges (counts : List ℕ) (rows prox : ℕ) (t : Tr) : Except String Unit := do
  let t1 ← counts.foldlM (fun t c => groupDraws H c t) t
  let rho := (t1.challengeFp2Vec H rows).1
  if prox + 1 ≥ rows ∨ (det (rho.getD prox Fp2.zero) (rho.getD (prox + 1) Fp2.zero)).v = 0 then
    throw "dependent proximity mask coefficients; discard attempt"

/-- `count` member coefficients of each group, then `rows` proximity coefficients (`zk_rhos`). -/
def zkRhos (counts : List ℕ) (rows : ℕ) (t : Tr) : List Fp2 × List Fp2 × Tr :=
  let r := counts.foldl (fun (acc : List Fp2 × Tr) c => let v := acc.2.challengeFp2Vec H c; (acc.1 ++ v.1, v.2)) ([], t)
  let p := r.2.challengeFp2Vec H rows
  (r.1, p.1, p.2)

/-- The opened columns' indices against the sampled ones (`column index j != sampled`). -/
def colIdxCheck (pre : String) (cols : List Column) (idx : List ℕ) : Except String Unit :=
  if cols.length ≠ idx.length then .error s!"{pre}wrong number of columns"
  else match (cols.zip idx).find? (fun ci => ci.1.j ≠ ci.2) with
    | some (c, i) => .error s!"{pre}column index {c.j} != sampled {i}"
    | none => .ok ()

/-- **The transcript of `pcs::verify_zk_tagged`**: `zk_rhos`, the group vectors' and the proximity vector's absorbs,
`challenge_indices(Q, nn)`; returns the `λ`s, the proximity coefficients, the indices and the transcript. -/
def pcsTranscript (counts : List ℕ) (rows q nn : ℕ) (o : OpeningZk) (t : Tr) :
    Except String (List Fp2 × List Fp2 × List ℕ × Tr) :=
  let z := zkRhos H counts rows t
  let t3 := o.groupVecs.foldl (fun t v => t.absorbFp2 H labPcsVec v) z.2.2
  let t4 := t3.absorbFp2 H labPcsProx o.proxVec
  match t4.challengeIndices H q nn with
  | none => .error "panic: challenge_indices of a bound that is not a power of two"
  | some (idx, t5) =>
    match colIdxCheck "pcs zk: " o.columns idx with
    | .error e => .error e
    | .ok () => .ok (z.1, z.2.1, idx, t5)

/-- **The transcript of `zk::mask_verify_tagged`**: `θ`, `q`'s absorb, `2·specs + 2` row coefficients, the proximity
absorb, `challenge_indices(MASK_Q, 2^MASK_LOG_DOM)`. -/
def maskTranscript (nSpecs maskQ dom : ℕ) (mo : MaskOpening) (t : Tr) : Except String (Fp2 × List Fp2 × List ℕ × Tr) :=
  let th := t.challengeFp2 H
  let t1 := th.2.absorbFp2 H labMaskQ mo.q
  let rs := t1.challengeFp2Vec H (2 * nSpecs + 2)
  let t2 := rs.2.absorbFp2 H labMaskProx mo.prox
  match t2.challengeIndices H maskQ dom with
  | none => .error "panic: challenge_indices of a bound that is not a power of two"
  | some (idx, t3) =>
    if mo.columns.length ≠ idx.length then .error "mask: column count"
    else if (mo.columns.zip idx).any (fun ci => ci.1.j ≠ ci.2) then .error "mask: column index"
    else .ok (th.1, rs.1, idx, t3)

end Verify

end ZK60.Exec.Block
