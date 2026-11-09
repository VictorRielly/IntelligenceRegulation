/-
D63 Lean lane L29 (2026-11-07), part 4: **the executable stage IN-C and stage OUT-C verifiers, and the classify run's
`Protocol` instance with them** (lane L18's `StageInV` / `StageOutV` parameters instantiated).

The code (hashline, read 2026-11-07; nothing there is changed):
* `token_io.rs` `StageSegGeom::decode` / `encode` (:1363-1497): the stage segment (`HLPCLIN1` / `HLPCLOT1`): the header
  (magic, binding, `L + 2`, the index, the start tag, each COMPARED), `B_in`'s root (IN-C only), the three roots, the
  slots, `M`'s, `A`'s and `H`'s openings, the closed commitment's opening, the end tag; the counted length first;
* `stage_in_c.rs` `verify` (:399-464): the closes count, T-4 for `A`, `H`, `M` and the input token endpoint, `B_in`'s
  root, `pb-run-stage 0`, `pb-run-block` (the embedding digest), `absorb_root("B")`, `absorb_root("A")`, `absorb("M")`,
  `β, γ, α, r_emb`, `absorb_root("H")`, the four slots (`run_stage_slot`), the functional count
  (`finish_functionals`), `M`, `check_opening` and the opening of `A`, of `H` (closed by `logup_sum_claim`),
  `check_token_endpoint_opening` and the opening of the input endpoint; returns the claims left pending on `B_in` and
  `B_in`'s root;
* `stage_out_c.rs` `verify` (:658-749): the closes count and no `B` root, T-4 for `A`, `H`, `M`, `B_out`,
  `pb-run-stage L + 1`, `pb-run-block` (the margin vector's digest), `A`, `M`, `γ, α`, `H`, the eight slots, the
  functional count, `M`, no claim on an output endpoint, `A`, `H`, then `boundary::check_opening` and the opening of
  `B_out` on the pending claims followed by OUTC-00's.

The sub-checks: `check_opening` is lane L10's executable `checkOpeningExec` at the stage's geometry (and at `B_out`'s
for `boundary::check_opening`); `check_token_endpoint_opening` is written here (L9's `openingChallenges` on a clone);
`M`'s `mask_verify_tagged` and each `pcs::verify_zk_tagged` are parameters of the verifier (`IncV`, `OutcV`), with an
instance from L10's executable functions at the tier's parameters (`pcsAt`, L10's `maskField`).

Proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `decodeStage_enc`: the honest segment decodes (the stage segment codec, from L9's and L17's reader lemmas);
* **`incVerify_ok_iff`**, **`outcVerify_ok_iff`**: each verifier accepts EXACTLY when every check, in the code's order,
  passes (the slot phase as L9's slot loop at each slot's IO row width);
* **`outcSlots_model`**: stage OUT-C's slot phase IS lane L15's `stageSlots` (the Fiat–Shamir model of a stage);
  **`incSlots_model`**: stage IN-C's slot phase is `stageSlots` at the `BlockParams` of its drawn `r_emb` on everything
  but the claims (finding L29-1, the IO row widths; L29-2, `define` reads `r_emb`);
* `incStageV`, `outcStageV`: L18's `StageInV` / `StageOutV` from them; **`classifyRunV`**, **`classifyProtocolExec`**:
  the classify run's verifier and `Protocol` with the executable stages; **`inSegExec_step_ok_iff`**,
  **`outSegExec_step_ok_iff`**: L18's segment steps with the executable stages, in the code's order.
-/
import ZK60Formal.StageVerifyExecInC
import ZK60Formal.StageVerifyExecOutC
import ZK60Formal.ExecOpeningBlock
import ZK60Formal.ProtocolClassifyR13

set_option autoImplicit false

namespace ZK60.Exec.StageV

open ZK60 ZK60.ProtocolClassify ZK60.TokenRun
open ZK60.Exec.Block (Core SlotProof Column Geom Dim Rd Rd.ret Rd.bnd Rd.guard rdBytes rdDig rdU64 rdHiding rdCore
  rdOpt encOpt encCore encHiding CoreCanon CoreShape HidingCanon HidingShape absorbRoot pathsDepth labA labH labM
  BlockParams Hist SlotRec Acc slotsLoop histOf openingChallenges SlotKind Cm Tab SlotDef Claims4 posTag)
open ZK60.Exec.StageCheck (kI)

/-! ## The stage segment -/

/-- **`StageSegment`** (token_io.rs:1334-1344): `B_in`'s root (IN-C), the three roots, the slots and the three openings
(L9's `Core`, the same fields in the same order), the openings of the commitments the stage closes. -/
structure StageSeg where
  bRoot : Option Dig
  core : Core
  closes : List Block.OpeningZk
  deriving DecidableEq

/-- **`StageSegGeom`** (token_io.rs:1348-1358): every count from the verifier's own statement: the magic, L9's core
geometry (the slots, `M`, the stage `Dim`, `A`'s and `H`'s groups and rows), whether a `B` root is carried, the closed
commitments' `(Dim, groups, rows)`, `L + 2` and the segment's index. -/
structure StageGeom where
  magic : List UInt8
  g : Geom
  hasB : Bool
  closes : List (Dim × ℕ × ℕ)
  total : ℕ
  index : ℕ

/-- `StageSegGeom::len` (token_io.rs:1376-1389). -/
def StageGeom.len (s : StageGeom) : ℕ :=
  (8 + 32 + 8 + 8 + 32) + (if s.hasB then 32 else 0) + 3 * 32 + s.g.slotsLen + s.g.maskLen
    + s.g.blk.openingLen s.g.aGroups s.g.aRows + s.g.blk.openingLen s.g.hGroups s.g.hRows
    + (s.closes.map (fun c => c.1.openingLen c.2.1 c.2.2)).sum + 32

/-- `b"HLPCLIN1"`, `b"HLPCLOT1"` (classify.rs:863-864). -/
def magicIn : List UInt8 := [72, 76, 80, 67, 76, 73, 78, 49]
def magicOut : List UInt8 := [72, 76, 80, 67, 76, 79, 84, 49]

/-- The segment header (token_io.rs:1462-1473): each field COMPARED with the verifier's own. -/
def rdStageHeader (s : StageGeom) (bindg startTag : Dig) : Rd Unit :=
  Rd.bnd (rdBytes 8) fun mg => Rd.bnd (Rd.guard (mg ≠ s.magic) s!"token I/O wire: segment {s.index} is not a stage segment") fun _ =>
  Rd.bnd rdDig fun b => Rd.bnd (Rd.guard (b ≠ bindg) "token I/O wire: this segment belongs to another run") fun _ =>
  Rd.bnd rdU64 fun t' => Rd.bnd rdU64 fun k' =>
  Rd.bnd (Rd.guard (t'.toNat ≠ s.total % 2 ^ 64 ∨ k'.toNat ≠ s.index % 2 ^ 64)
    s!"token I/O wire: segment {s.index} is not this run's segment {s.index} of {s.total}") fun _ =>
  Rd.bnd rdDig fun st =>
  Rd.guard (st ≠ startTag) s!"token I/O wire: segment {s.index}'s header is not the verifier's own transcript position"

/-- The closed commitments' openings, in order. -/
def rdCloses : List (Dim × ℕ × ℕ) → Rd (List Block.OpeningZk)
  | [] => Rd.ret []
  | c :: cs => Rd.bnd (rdHiding c.1 c.2.1 c.2.2) fun o => Rd.bnd (rdCloses cs) fun os => Rd.ret (o :: os)

/-- The segment after its length check. -/
def rdStageBody (s : StageGeom) (bindg startTag : Dig) : Rd (StageSeg × Dig) :=
  Rd.bnd (rdStageHeader s bindg startTag) fun _ =>
  Rd.bnd (rdOpt s.hasB rdDig) fun br =>
  Rd.bnd (rdCore s.g) fun c =>
  Rd.bnd (rdCloses s.closes) fun cl =>
  Rd.bnd rdDig fun e => Rd.ret (⟨br, c, cl⟩, e)

/-- **`StageSegGeom::decode`**: the segment and its end tag (compared after the stage is replayed). -/
def decodeStage (s : StageGeom) (bindg startTag : Dig) (bytes : List UInt8) : Except String (StageSeg × Dig) :=
  if bytes.length ≠ s.len then
    .error s!"token I/O wire: segment {s.index} is {bytes.length} B, the counted length is {s.len}"
  else
    match rdStageBody s bindg startTag bytes with
    | .error e => .error e
    | .ok (r, rest) => if rest ≠ [] then .error "token I/O wire: trailing bytes" else .ok r

/-- **`StageSegGeom::encode`** (token_io.rs:1420-1453). -/
def encStage (s : StageGeom) (bindg startTag : Dig) (sg : StageSeg) (endTag : Dig) : List UInt8 :=
  s.magic ++ (bindg.toList ++ (le64 (UInt64.ofNat s.total) ++ (le64 (UInt64.ofNat s.index) ++ (startTag.toList
    ++ (encOpt (fun d : Dig => d.toList) sg.bRoot ++ (encCore sg.core ++ (sg.closes.flatMap encHiding
    ++ endTag.toList)))))))

/-! ### The codec -/

theorem rdStageHeader_enc (s : StageGeom) (hmag : s.magic.length = 8) (bindg startTag : Dig) (rest : List UInt8) :
    rdStageHeader s bindg startTag
      (s.magic ++ (bindg.toList ++ (le64 (UInt64.ofNat s.total) ++ (le64 (UInt64.ofNat s.index)
        ++ (startTag.toList ++ rest))))) = .ok ((), rest) := by
  unfold rdStageHeader
  rw [Block.Rd.bnd_of_ok (Block.rdBytes_enc s.magic _ 8 hmag),
    Block.Rd.bnd_of_ok (Block.Rd.guard_enc (c := s.magic ≠ s.magic) _ (by simp)),
    Block.Rd.bnd_of_ok (Block.rdDig_enc _ _), Block.Rd.bnd_of_ok (Block.Rd.guard_enc (c := bindg ≠ bindg) _ (by simp)),
    Block.Rd.bnd_of_ok (Block.rdU64_enc _ _), Block.Rd.bnd_of_ok (Block.rdU64_enc _ _),
    Block.Rd.bnd_of_ok (Block.Rd.guard_enc (c := (UInt64.ofNat s.total).toNat ≠ s.total % 2 ^ 64
      ∨ (UInt64.ofNat s.index).toNat ≠ s.index % 2 ^ 64) _ (by simp [UInt64.toNat_ofNat'])),
    Block.Rd.bnd_of_ok (Block.rdDig_enc _ _), Block.Rd.guard_enc (c := startTag ≠ startTag) _ (by simp)]

/-- An opening of a declared closed commitment: canonical, of its counted shape, with indices below `2^64`. -/
def CloseOk (c : Dim × ℕ × ℕ) (o : Block.OpeningZk) : Prop :=
  HidingCanon o ∧ HidingShape c.1 c.2.1 c.2.2 o ∧ c.1.encCols ≤ 2 ^ 64

theorem rdCloses_enc : ∀ (cs : List (Dim × ℕ × ℕ)) (os : List Block.OpeningZk) (rest : List UInt8),
    List.Forall₂ CloseOk cs os → rdCloses cs (os.flatMap encHiding ++ rest) = .ok (os, rest)
  | [], [], rest, _ => rfl
  | c :: cs, o :: os, rest, h => by
    obtain ⟨⟨hc, hs, he⟩, h2⟩ := List.forall₂_cons.mp h
    unfold rdCloses
    rw [List.flatMap_cons, List.append_assoc, Block.Rd.bnd_of_ok (Block.rdHiding_enc c.1 c.2.1 c.2.2 o hc hs.1 hs.2.1 hs.2.2.1
      hs.2.2.2.1 hs.2.2.2.2 he _), Block.Rd.bnd_of_ok (rdCloses_enc cs os rest h2)]
    rfl
  | [], _ :: _, _, h => absurd h (by simp)
  | _ :: _, [], _, h => absurd h (by simp)

/-- **The honest stage segment decodes**: the encoding of a canonical segment of the verifier's geometry (the core's
counts, `B`'s root present exactly as declared, each closed commitment's opening of its counted shape), of the counted
length, under the verifier's own binding and start tag, decodes back to it with its end tag. -/
theorem decodeStage_enc (s : StageGeom) (hgt : s.g.slots.length = s.g.terms.length) (hdom : s.g.maskDom ≤ 2 ^ 64)
    (henc : s.g.blk.encCols ≤ 2 ^ 64) (hmag : s.magic.length = 8) (bindg startTag : Dig) (sg : StageSeg) (e : Dig)
    (hcan : CoreCanon sg.core) (hsh : CoreShape s.g sg.core) (hbr : sg.bRoot.isSome = s.hasB)
    (hcl : List.Forall₂ CloseOk s.closes sg.closes) (hlen : (encStage s bindg startTag sg e).length = s.len) :
    decodeStage s bindg startTag (encStage s bindg startTag sg e) = .ok (sg, e) := by
  have hr : rdStageBody s bindg startTag (encStage s bindg startTag sg e) = .ok ((sg, e), []) := by
    unfold rdStageBody
    rw [encStage, Block.Rd.bnd_of_ok (rdStageHeader_enc s hmag _ _ _),
      Block.Rd.bnd_of_ok (Block.rdOpt_enc (P := fun _ => True) (fun a rest _ => Block.rdDig_enc a rest) sg.bRoot hbr
        (fun _ _ => trivial) _),
      Block.Rd.bnd_of_ok (Block.rdCore_enc s.g hgt hdom henc sg.core hcan hsh _),
      Block.Rd.bnd_of_ok (rdCloses_enc s.closes sg.closes _ hcl),
      ← List.append_nil e.toList, Block.Rd.bnd_of_ok (Block.rdDig_enc _ _)]
    rfl
  have hc : ¬ ((encStage s bindg startTag sg e).length ≠ s.len) := by omega
  unfold decodeStage
  simp only [hc, ↓reduceIte, hr, ne_eq, not_true_eq_false]

/-! ## The sub-checks the stages call -/

section Sub

variable (H : HIn → Dig)

/-- **`pcs::verify_zk_tagged` at a commitment's parameters**: lane L10's executable `pcsVerify` (the interpolant row
form at the coset `7·G_{nn}`, `nn = 2^logN·2^lr`), row width `2^logN`, `Q` opened columns and pads, with the code's
messages. -/
def pcsAt (tag : MTag) (logN lr q : ℕ) (H : HIn → Dig) (root : Dig) (rows : ℕ) (cl : List Block.ZClaim)
    (o : Block.OpeningZk) (t : Tr) : Except String Tr :=
  mapErr (pcsErrMsg o (groupZclaims (cl.map toZClaim) rows logN).length (logN + lr))
    (ZK60.Exec.pcsVerify H tag ⟨logN, 2 ^ lr, q, q⟩ (cosetPt (rootFp (logN + lr))) (colEncLag (rootFp logN) (2 ^ logN) q)
      root rows logN (cl.map toZClaim) (toOZ o) t)

/-- The claim parts' rows `part_rows(p, n)` (token_io.rs:1272). -/
def partRows (p : Block.ZPart) (n : ℕ) : ℕ × ℕ := (ZK60.Exec.partLo p n, ZK60.Exec.partHi p n)

/-- `endpoint_g::MASK_ROWS` (endpoint_g.rs:92): a token endpoint's rows past its data. -/
def epMaskRows : ℕ := 5

/-- **`check_token_endpoint_opening`** (token_io.rs:1280-1293): ONE claim of three parts, the data rows, then its own
terminal pair, every coefficient nonzero; then the opening's challenge refusals on a CLONE (L9's
`openingChallenges` with one group of one member over `data + MASK_ROWS` rows, the proximity pair at `data + 2`). -/
def checkTokenEp (cl : List Block.ZClaim) (data n : ℕ) (t : Tr) : Except String Unit :=
  match cl with
  | [c] =>
    match c.parts with
    | [p0, p1, p2] =>
      if partRows p0 n = (0, data) ∧ partRows p1 n = (data, data + 1) ∧ partRows p2 n = (data + 1, data + 2)
          ∧ c.parts.all (fun p => !p.coef.isZero) = true then
        openingChallenges H [1] (data + epMaskRows) (data + 2) t
      else .error "token I/O: a token endpoint claim differs from the declared schedule (one claim, its own terminal pair)"
    | _ => .error "token I/O: a token endpoint claim differs from the declared schedule (one claim, its own terminal pair)"
  | _ => .error "token I/O: a token endpoint claim differs from the declared schedule (one claim, its own terminal pair)"

/-- A sub-check's refusal re-thrown under a prefix (`.map_err(|e| format!("…: {e}"))`). -/
def withPre {α : Type} (pre : String) (x : Except String α) : Except String α :=
  match x with
  | .ok a => .ok a
  | .error e => .error (pre ++ e)

theorem withPre_ok {α : Type} (pre : String) (x : Except String α) (a : α) : withPre pre x = .ok a ↔ x = .ok a := by
  cases x with
  | ok b => exact ⟨fun h => (by cases h; rfl), fun h => by cases h; rfl⟩
  | error e => exact ⟨fun h => (by cases h), fun h => by cases h⟩

/-- A check of the code (`if c { return Err(m) }`): refused with `m` when `c` holds. -/
def refuseIf (c : Prop) [Decidable c] (m : String) : Except String Unit := if c then .error m else .ok ()

theorem refuseIf_ok_iff (c : Prop) [Decidable c] (m : String) (u : Unit) : refuseIf c m = .ok u ↔ ¬ c := by
  unfold refuseIf
  by_cases hc : c
  · simp only [hc, ↓reduceIte, not_true_eq_false, iff_false]
    intro h
    cases h
  · simp only [hc, ↓reduceIte, not_false_eq_true, iff_true]

end Sub

/-! ## Stage IN-C -/

/-- `zk.rs`'s `M` constants, the same for every stage and block (L9's `W16R2.mask*`). -/
def mGeom (L : Lay) (blk : Dim) (aGroups hGroups : ℕ) : Geom :=
  ⟨L.geomSlots, L.geomTerms, Block.W16R2.maskVec, Block.W16R2.maskQ, Block.W16R2.maskDom, Block.W16R2.maskPath, L.mRows,
    blk, aGroups, L.aRows, hGroups, L.hRows, 2 ^ 64⟩

/-- **Stage IN-C's verifier data**: the public data, the run's geometry, the stage's and the endpoint's `Dim`, the
endpoint's row width as the commitment carries it, and `M`'s test and the openings (`pcs::verify_zk_tagged` of `A` / `H`
and of the input token endpoint): L10's components. -/
structure IncV where
  pub : IncPub
  geo : IncGeo
  blk : Dim
  ed : Dim
  maskVerify : (HIn → Dig) → Dig → List Block.MaskFunctional → Block.MaskOpening → Tr → Except String Tr
  pcsVerify : (HIn → Dig) → Cm → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr
  epVerify : (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr

namespace IncV

variable (V : IncV) (H : HIn → Dig)

def lay : Lay := incLay V.pub V.geo.bLogN
def geom : Geom := mGeom V.lay V.blk incAGroups incHGroups

/-- `protocol::check_opening` of `A` and `H` (L10's `checkOpeningExec` at the stage's geometry). -/
def checkOpening : Cm → List Block.ZClaim → Tr → Except String Unit
  | .a, cl, t => checkOpeningExec H ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, incAGroups⟩ V.lay.logN cl t
  | _, cl, t => checkOpeningExec H ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, incHGroups⟩ V.lay.logN cl t

/-- **Stage IN-C's slot schedule as L9's parameters**, at the head's context `cx`. -/
def bp (cx : IncCtx) : BlockParams :=
  stageBP V.lay V.geom V.geo.bLogN V.blk.path V.blk.path Block.W16R2.maskPath (incDraws V.pub)
    (incDefine V.pub V.geo cx) V.maskVerify V.checkOpening V.pcsVerify

/-- The stage's frame: `absorb_u64("pb-run-stage", 0)`, `absorb("pb-run-block", emb_digest)`, `absorb_root("B")`. -/
def frame (bRoot : Dig) (t : Tr) : Tr :=
  absorbRoot H ((t.absorbU64 H labRunStage 0).absorb H labRunBlock V.pub.embDigest.toList) labB bRoot V.geo.bRows
    V.geo.bLogN

/-- The transcript after `absorb_root("A")` and `absorb("M")`. -/
def headT (core : Core) (t : Tr) : Tr :=
  (absorbRoot H t labA core.aRoot V.lay.aRows V.lay.logN).absorb H labM core.maskRoot.toList

/-- The head's challenges `β, γ, α, r_emb` and the transcript after them. -/
def headCh (core : Core) (t : Tr) : List Fp2 × Tr := (V.headT H core t).challengeFp2Vec H (incHeadDraws V.pub)

/-- The transcript the slots start from (after `absorb_root("H")`). -/
def slotT (core : Core) (t : Tr) : Tr := absorbRoot H (V.headCh H core t).2 labH core.hRoot V.lay.hRows V.lay.logN

/-- **Stage IN-C's slot phase**: `A`, `M`, the challenges, `H`, then the four slots at their IO row widths. -/
def slots (core : Core) (t : Tr) : Except String (List SlotRec × Acc × Tr) :=
  stSlotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero Fp2.zero [] 0
    core.slots {} (V.slotT H core t)

/-- A dummy opening (the code indexes `closes[0]` after checking there is exactly one). -/
def ozk0 : Block.OpeningZk := ⟨[], [], []⟩

/-- **`stage_in_c::verify`**: the claims left pending on `B_in`, `B_in`'s root, and the transcript after the stage. -/
def verify (epRoot : Dig) (seg : StageSeg) (t : Tr) : Except String ((List Block.ZClaim × Dig) × Tr) :=
  refuseIf (seg.closes.length ≠ 1) "classifier: stage IN-C's segment parts are not the run schedule's" >>= fun _ =>
  pathsDepth "stage IN-C A" V.blk.path 0 seg.core.aOpen.columns >>= fun _ =>
  pathsDepth "stage IN-C H" V.blk.path 0 seg.core.hOpen.columns >>= fun _ =>
  pathsDepth "M" Block.W16R2.maskPath 0 seg.core.maskOpen.columns >>= fun _ =>
  pathsDepth "input token endpoint" V.ed.path 0 (seg.closes.headD ozk0).columns >>= fun _ =>
  optOk seg.bRoot "classifier: stage IN-C's segment carries no B_in root" >>= fun bRoot =>
  V.slots H seg.core (V.frame H bRoot t) >>= fun r =>
  refuseIf ((r.2.1.fs ++ r.2.1.hostFs).length ≠ V.lay.nFunctionals)
    "token I/O stage IN-C: functional count differs from the declared schedule" >>= fun _ =>
  withPre "stage IN-C M: " (V.maskVerify H seg.core.maskRoot (r.2.1.fs ++ r.2.1.hostFs) seg.core.maskOpen r.2.2)
    >>= fun t5 =>
  V.checkOpening H .a r.2.1.claims.a t5 >>= fun _ =>
  withPre "stage IN-C A: " (V.pcsVerify H .a seg.core.aRoot r.2.1.claims.a seg.core.aOpen t5) >>= fun t6 =>
  V.checkOpening H .h (r.2.1.claims.h ++ [V.lay.logupSumClaim]) t6 >>= fun _ =>
  withPre "stage IN-C H (the LogUp sum claim is part of this opening): "
    (V.pcsVerify H .h seg.core.hRoot (r.2.1.claims.h ++ [V.lay.logupSumClaim]) seg.core.hOpen t6) >>= fun t7 =>
  checkTokenEp H r.2.1.claims.inp V.geo.epDataRows V.pub.epN t7 >>= fun _ =>
  withPre "input token endpoint: " (V.epVerify H epRoot r.2.1.claims.inp (seg.closes.headD ozk0) t7) >>= fun t8 =>
  .ok ((r.2.1.claims.out, bRoot), t8)

end IncV

/-! ## Stage OUT-C -/

/-- **Stage OUT-C's verifier data**: the public data (with the statement's verdict), `B_out`'s geometry, the stage's
and `B_out`'s `Dim`, the stage index `L + 1`, and `M`'s test and the openings of `A` / `H` and of `B_out` (L10's). -/
structure OutcV where
  pub : OutcPub
  geo : OutcGeo
  blk : Dim
  bd : Dim
  stageIndex : ℕ
  maskVerify : (HIn → Dig) → Dig → List Block.MaskFunctional → Block.MaskOpening → Tr → Except String Tr
  pcsVerify : (HIn → Dig) → Cm → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr
  bVerify : (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr

namespace OutcV

variable (V : OutcV) (H : HIn → Dig)

def lay : Lay := outcLay V.pub V.geo.bLogN
def geom : Geom := mGeom V.lay V.blk outcAGroups outcHGroups

def checkOpening : Cm → List Block.ZClaim → Tr → Except String Unit
  | .a, cl, t => checkOpeningExec H ⟨V.lay.aRows, V.lay.aSiteRows, none, V.lay.aProx, outcAGroups⟩ V.lay.logN cl t
  | _, cl, t => checkOpeningExec H ⟨V.lay.hRows, V.lay.hSiteRows, some V.lay.hURows, V.lay.hProx, outcHGroups⟩ V.lay.logN cl t

/-- **`boundary::check_opening(b_spec, claims, tr)`** = `protocol::check_opening` at `B_out`'s geometry (boundary.rs:287):
its rows, its site rows (the data rows' end, one pair per site), no zero-sum pair, its proximity pair, its sites as the
group count. -/
def bCheck (cl : List Block.ZClaim) (t : Tr) : Except String Unit :=
  checkOpeningExec H ⟨V.geo.bRows, List.range' V.geo.bDataRows (2 * V.geo.bSites), none, V.geo.bDataRows + 2 * V.geo.bSites,
    V.geo.bSites⟩ V.geo.bLogN cl t

/-- **Stage OUT-C's slot schedule as L9's parameters** (ONE instance: `define` reads `γ, α` from the history). -/
def bp : BlockParams :=
  stageBP V.lay V.geom V.geo.bLogN V.blk.path V.blk.path Block.W16R2.maskPath (outcDraws V.pub) (outcDefine V.pub V.geo)
    V.maskVerify V.checkOpening V.pcsVerify

/-- `define`'s history from the head's `[γ, α]` (lane L15's `bgaOf` for OUT-C: `β` unused). -/
def bga (ch : List Fp2) : Fp2 × Fp2 × Fp2 := (Fp2.zero, ch.getD 0 Fp2.zero, ch.getD 1 Fp2.zero)

/-- The stage's frame: `absorb_u64("pb-run-stage", L + 1)`, `absorb("pb-run-block", w_digest)`. -/
def frame (t : Tr) : Tr :=
  (t.absorbU64 H labRunStage (UInt64.ofNat V.stageIndex)).absorb H labRunBlock V.pub.wDigest.toList

/-- **`stage_out_c::verify`** on the carry (`B_out`'s root, the claims pending on it): the transcript after it. -/
def verify (bRoot : Dig) (pending : List Block.ZClaim) (seg : StageSeg) (t : Tr) : Except String Tr :=
  refuseIf (seg.closes.length ≠ 1 ∨ seg.bRoot.isSome = true)
    "classifier: stage OUT-C's segment parts are not the run schedule's" >>= fun _ =>
  pathsDepth "stage OUT-C A" V.blk.path 0 seg.core.aOpen.columns >>= fun _ =>
  pathsDepth "stage OUT-C H" V.blk.path 0 seg.core.hOpen.columns >>= fun _ =>
  pathsDepth "M" Block.W16R2.maskPath 0 seg.core.maskOpen.columns >>= fun _ =>
  pathsDepth "B_out" V.bd.path 0 (seg.closes.headD IncV.ozk0).columns >>= fun _ =>
  StageFS.stageSlots H V.bp 2 bga seg.core (V.frame H t) >>= fun r =>
  refuseIf ((r.2.2.1.fs ++ r.2.2.1.hostFs).length ≠ V.lay.nFunctionals)
    "token I/O stage OUT-C: functional count differs from the declared schedule" >>= fun _ =>
  withPre "stage OUT-C M: " (V.maskVerify H seg.core.maskRoot (r.2.2.1.fs ++ r.2.2.1.hostFs) seg.core.maskOpen r.2.2.2)
    >>= fun t5 =>
  refuseIf (r.2.2.1.claims.out ≠ []) "classifier stage OUT-C: a claim on an output endpoint (there is none)" >>= fun _ =>
  V.checkOpening H .a r.2.2.1.claims.a t5 >>= fun _ =>
  withPre "stage OUT-C A: " (V.pcsVerify H .a seg.core.aRoot r.2.2.1.claims.a seg.core.aOpen t5) >>= fun t6 =>
  V.checkOpening H .h (r.2.2.1.claims.h ++ [V.lay.logupSumClaim]) t6 >>= fun _ =>
  withPre "stage OUT-C H (the LogUp sum claim is part of this opening): "
    (V.pcsVerify H .h seg.core.hRoot (r.2.2.1.claims.h ++ [V.lay.logupSumClaim]) seg.core.hOpen t6) >>= fun t7 =>
  V.bCheck H (pending ++ r.2.2.1.claims.inp) t7 >>= fun _ =>
  withPre "B_out: " (V.bVerify H bRoot (pending ++ r.2.2.1.claims.inp) (seg.closes.headD IncV.ozk0) t7)

end OutcV

/-! ## Each verifier accepts exactly when every check passes, in the code's order -/

section Iff

variable (H : HIn → Dig)

/-- **Stage IN-C's verifier accepts EXACTLY when**, in the code's order: one closed commitment; T-4 for `A`, `H`, `M`
and the endpoint; `B_in`'s root present; the slot phase (the frame, `A`, `M`, `β, γ, α, r_emb`, `H`, the four slots at
their IO widths) accepts; the functional count; `M`; `check_opening` and the opening of `A`, of `H` (with
`logup_sum_claim`); `check_token_endpoint_opening` and the endpoint's opening. It returns the claims on `B_in` and
`B_in`'s root. -/
theorem incVerify_ok_iff (V : IncV) (epRoot : Dig) (seg : StageSeg) (t : Tr) (pending : List Block.ZClaim) (root : Dig)
    (t' : Tr) :
    V.verify H epRoot seg t = .ok ((pending, root), t') ↔
      seg.closes.length = 1
      ∧ pathsDepth "stage IN-C A" V.blk.path 0 seg.core.aOpen.columns = .ok ()
      ∧ pathsDepth "stage IN-C H" V.blk.path 0 seg.core.hOpen.columns = .ok ()
      ∧ pathsDepth "M" Block.W16R2.maskPath 0 seg.core.maskOpen.columns = .ok ()
      ∧ pathsDepth "input token endpoint" V.ed.path 0 (seg.closes.headD IncV.ozk0).columns = .ok ()
      ∧ seg.bRoot = some root
      ∧ ∃ (recs : List SlotRec) (acc : Acc) (t4 t5 t6 t7 : Tr),
        V.slots H seg.core (V.frame H root t) = .ok (recs, acc, t4)
        ∧ (acc.fs ++ acc.hostFs).length = V.lay.nFunctionals
        ∧ V.maskVerify H seg.core.maskRoot (acc.fs ++ acc.hostFs) seg.core.maskOpen t4 = .ok t5
        ∧ V.checkOpening H .a acc.claims.a t5 = .ok ()
        ∧ V.pcsVerify H .a seg.core.aRoot acc.claims.a seg.core.aOpen t5 = .ok t6
        ∧ V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim]) t6 = .ok ()
        ∧ V.pcsVerify H .h seg.core.hRoot (acc.claims.h ++ [V.lay.logupSumClaim]) seg.core.hOpen t6 = .ok t7
        ∧ checkTokenEp H acc.claims.inp V.geo.epDataRows V.pub.epN t7 = .ok ()
        ∧ V.epVerify H epRoot acc.claims.inp (seg.closes.headD IncV.ozk0) t7 = .ok t'
        ∧ pending = acc.claims.out := by
  unfold IncV.verify
  simp only [ex_bind_ok_iff, refuseIf_ok_iff, optOk_eq_ok, withPre_ok, ne_eq, not_not]
  constructor
  · rintro ⟨⟨⟩, hcl, ⟨⟩, hA, ⟨⟩, hH, ⟨⟩, hM, ⟨⟩, hE, br, hbr, ⟨recs, acc, t4⟩, hs, ⟨⟩, hfs, t5, h5, ⟨⟩, hcA, t6, h6,
      ⟨⟩, hcH, t7, h7, ⟨⟩, hep, t8, h8, hfin⟩
    simp only [Except.ok.injEq, Prod.mk.injEq] at hfin
    obtain ⟨⟨rfl, rfl⟩, rfl⟩ := hfin
    exact ⟨hcl, hA, hH, hM, hE, hbr, recs, acc, t4, t5, t6, t7, hs, hfs, h5, hcA, h6, hcH, h7, hep, h8, rfl⟩
  · rintro ⟨hcl, hA, hH, hM, hE, hbr, recs, acc, t4, t5, t6, t7, hs, hfs, h5, hcA, h6, hcH, h7, hep, h8, rfl⟩
    exact ⟨(), hcl, (), hA, (), hH, (), hM, (), hE, root, hbr, (recs, acc, t4), hs, (), hfs, t5, h5, (), hcA, t6, h6, (),
      hcH, t7, h7, (), hep, t', h8, rfl⟩

/-- **Stage OUT-C's verifier accepts EXACTLY when**, in the code's order: one closed commitment and no `B` root; T-4 for
`A`, `H`, `M`, `B_out`; the slot phase (lane L15's `stageSlots`: `A`, `M`, `γ, α`, `H`, the eight slots) accepts; the
functional count; `M`; no claim on an output endpoint; `A`; `H`; `boundary::check_opening` and `B_out`'s opening on the
pending claims followed by OUTC-00's. -/
theorem outcVerify_ok_iff (V : OutcV) (bRoot : Dig) (pending : List Block.ZClaim) (seg : StageSeg) (t t' : Tr) :
    V.verify H bRoot pending seg t = .ok t' ↔
      seg.closes.length = 1 ∧ seg.bRoot = none
      ∧ pathsDepth "stage OUT-C A" V.blk.path 0 seg.core.aOpen.columns = .ok ()
      ∧ pathsDepth "stage OUT-C H" V.blk.path 0 seg.core.hOpen.columns = .ok ()
      ∧ pathsDepth "M" Block.W16R2.maskPath 0 seg.core.maskOpen.columns = .ok ()
      ∧ pathsDepth "B_out" V.bd.path 0 (seg.closes.headD IncV.ozk0).columns = .ok ()
      ∧ ∃ (ch : List Fp2) (recs : List SlotRec) (acc : Acc) (t4 t5 t6 t7 : Tr),
        StageFS.stageSlots H V.bp 2 OutcV.bga seg.core (V.frame H t) = .ok (ch, recs, acc, t4)
        ∧ (acc.fs ++ acc.hostFs).length = V.lay.nFunctionals
        ∧ V.maskVerify H seg.core.maskRoot (acc.fs ++ acc.hostFs) seg.core.maskOpen t4 = .ok t5
        ∧ acc.claims.out = []
        ∧ V.checkOpening H .a acc.claims.a t5 = .ok ()
        ∧ V.pcsVerify H .a seg.core.aRoot acc.claims.a seg.core.aOpen t5 = .ok t6
        ∧ V.checkOpening H .h (acc.claims.h ++ [V.lay.logupSumClaim]) t6 = .ok ()
        ∧ V.pcsVerify H .h seg.core.hRoot (acc.claims.h ++ [V.lay.logupSumClaim]) seg.core.hOpen t6 = .ok t7
        ∧ V.bCheck H (pending ++ acc.claims.inp) t7 = .ok ()
        ∧ V.bVerify H bRoot (pending ++ acc.claims.inp) (seg.closes.headD IncV.ozk0) t7 = .ok t' := by
  unfold OutcV.verify
  simp only [ex_bind_ok_iff, refuseIf_ok_iff, withPre_ok, ne_eq, not_not, not_or, Option.not_isSome_iff_eq_none]
  constructor
  · rintro ⟨⟨⟩, ⟨hcl, hbr⟩, ⟨⟩, hA, ⟨⟩, hH, ⟨⟩, hM, ⟨⟩, hE, ⟨ch, recs, acc, t4⟩, hs, ⟨⟩, hfs, t5, h5, ⟨⟩, hout, ⟨⟩,
      hcA, t6, h6, ⟨⟩, hcH, t7, h7, ⟨⟩, hbc, h8⟩
    exact ⟨hcl, hbr, hA, hH, hM, hE, ch, recs, acc, t4, t5, t6, t7, hs, hfs, h5, hout, hcA, h6, hcH, h7, hbc, h8⟩
  · rintro ⟨hcl, hbr, hA, hH, hM, hE, ch, recs, acc, t4, t5, t6, t7, hs, hfs, h5, hout, hcA, h6, hcH, h7, hbc, h8⟩
    exact ⟨(), ⟨hcl, hbr⟩, (), hA, (), hH, (), hM, (), hE, (ch, recs, acc, t4), hs, (), hfs, t5, h5, (), hout, (), hcA,
      t6, h6, (), hcH, t7, h7, (), hbc, h8⟩

/-! ## The slot phases are lane L15's stage model -/

/-- **Stage OUT-C's slot phase IS lane L15's `stageSlots`** (the stage's Fiat–Shamir model, `stage_sumchecks_fs_sound`):
by definition of the executable verifier, with its ONE `BlockParams`, `m = 2` and `(0, γ, α)`; and its slot loop is
L9's `slotsLoop` (one IO row width, `B_out`'s). -/
theorem outcSlots_model (V : OutcV) (core : Core) (t : Tr) :
    StageFS.stageSlots H V.bp 2 OutcV.bga core t =
      match slotsLoop H V.bp (OutcV.bga (((absorbRoot H t labA core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          core.maskRoot.toList).challengeFp2Vec H 2).1).1
        (OutcV.bga (((absorbRoot H t labA core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          core.maskRoot.toList).challengeFp2Vec H 2).1).2.1
        (OutcV.bga (((absorbRoot H t labA core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          core.maskRoot.toList).challengeFp2Vec H 2).1).2.2 [] 0 core.slots {}
        (absorbRoot H (((absorbRoot H t labA core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          core.maskRoot.toList).challengeFp2Vec H 2).2 labH core.hRoot V.bp.hRows V.bp.logCols) with
      | .ok r => .ok ((((absorbRoot H t labA core.aRoot V.bp.aRows V.bp.logCols).absorb H labM
          core.maskRoot.toList).challengeFp2Vec H 2).1, r)
      | .error e => .error e := rfl

/-- **Stage IN-C's slot phase is lane L15's `stageSlots` at the `BlockParams` of its drawn `r_emb`, on everything but
the claims** (findings L29-1, L29-2): the verdict, the head's challenges, the slot records, the transcript and the
claim-free accumulator (the `c`s, the scalars, `M`'s functionals) of the executable slot phase are `stageSlots`'s at
`V.bp (incCtx ch)`, `m = 3 + clog2(d_pad)`, for the challenges `ch` the head draws. -/
/-- The stripped results, one of them framed with the head's challenges (`stageSlots`' return). -/
theorem map_match_strip (ch : List Fp2) (x y : Except String (List SlotRec × Acc × Tr))
    (h : (fun z : List SlotRec × Acc × Tr => (z.1, accStrip z.2.1, z.2.2)) <$> x
      = (fun z : List SlotRec × Acc × Tr => (z.1, accStrip z.2.1, z.2.2)) <$> y) :
    (fun z : List SlotRec × Acc × Tr => ((ch, z.1), accStrip z.2.1, z.2.2)) <$> x
      = (fun z : List Fp2 × List SlotRec × Acc × Tr => ((z.1, z.2.1), accStrip z.2.2.1, z.2.2.2)) <$>
          (match y with
            | .ok r => (.ok (ch, r) : Except String (List Fp2 × List SlotRec × Acc × Tr))
            | .error e => .error e) := by
  cases x with
  | error e1 =>
    cases y with
    | error e2 =>
      have h' : (Except.error e1 : Except String _) = Except.error e2 := h
      cases h'
      rfl
    | ok b => cases h
  | ok a =>
    cases y with
    | error e2 => cases h
    | ok b =>
      have h' : (Except.ok (a.1, accStrip a.2.1, a.2.2) : Except String _) = Except.ok (b.1, accStrip b.2.1, b.2.2) := h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h'
      obtain ⟨h1, h2, h3⟩ := h'
      show (Except.ok ((ch, a.1), accStrip a.2.1, a.2.2) : Except String _) = Except.ok ((ch, b.1), accStrip b.2.1, b.2.2)
      rw [h1, h2, h3]

/-- **Stage IN-C's slot phase is lane L15's `stageSlots` at the `BlockParams` of its drawn `r_emb`, on everything but
the claims** (findings L29-1, L29-2): the verdict, the head's challenges, the slot records, the transcript and the
claim-free accumulator (the `c`s, the scalars, `M`'s functionals) of the executable slot phase are `stageSlots`'s at
`V.bp (incCtx ch)`, `m = 3 + clog2(d_pad)`, for the challenges `ch` the head draws. -/
theorem incSlots_model (V : IncV) (core : Core) (t : Tr) :
    (fun x : List SlotRec × Acc × Tr => (((V.headCh H core t).1, x.1), accStrip x.2.1, x.2.2)) <$> V.slots H core t
      = (fun x : List Fp2 × List SlotRec × Acc × Tr => ((x.1, x.2.1), accStrip x.2.2.1, x.2.2.2)) <$>
          StageFS.stageSlots H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incHeadDraws V.pub)
            (fun _ => (Fp2.zero, Fp2.zero, Fp2.zero)) core t :=
  map_match_strip (V.headCh H core t).1 _
    (slotsLoop H (V.bp (incCtx V.pub (V.headCh H core t).1)) Fp2.zero Fp2.zero Fp2.zero [] 0 core.slots {}
      (V.slotT H core t))
    (stSlotsLoop_strip H (V.bp (incCtx V.pub (V.headCh H core t).1)) (incElog V.pub V.geo.bLogN) Fp2.zero Fp2.zero
      Fp2.zero [] 0 core.slots {} ({} : Acc).claims (V.slotT H core t))

end Iff

/-! ## L18's stage parameters, instantiated -/

section Inst

variable {Hdr : Type}

/-- **Stage IN-C as the run calls it** (L18's `StageInV`): `st.in_geom(&in_lay).decode(bytes, &binding, &start)` and
`stage_in_c::verify` on the statement's input root. -/
def incStageV (V : Hdr → IncV) (G : Hdr → StageGeom) : StageInV (ClsStmt Hdr) where
  Seg := StageSeg
  decode s bytes bnd start := decodeStage (G s.hdr) bnd start bytes
  verify H s seg t := (V s.hdr).verify H s.inRoot seg t

/-- **Stage OUT-C as the run calls it** (L18's `StageOutV`): `st.out_geom(&out_lay).decode(…)` and
`stage_out_c::verify` with the statement's PUBLIC verdict, on the carry. -/
def outcStageV (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) : StageOutV (ClsStmt Hdr) where
  Seg := StageSeg
  decode s bytes bnd start := decodeStage (G s.hdr) bnd start bytes
  verify H s seg root pending t := (V s.hdr s.verdict).verify H root pending seg t

/-- **The classify run's verifier with the executable stages** (L18's `RunV`): the pre-header checks, the run header, the
executable stage IN-C, the block profile (R13: L18's `d12aBlockProf`), the executable stage OUT-C. -/
def classifyRunV (L : ℕ) (preA preB : Hdr → Except String Unit) (start : (HIn → Dig) → ClsStmt Hdr → Tr)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV)
    (outcG : Hdr → StageGeom) : RunV Hdr :=
  ⟨L, preA, preB, start, incStageV inc incG, blk, outcStageV outc outcG⟩

/-- **Stage IN-C's segment step with the executable stage** (L18's `inSeg_step_ok_iff` at `incStageV`): the decode at the
transcript's position tag, `stage_in_c::verify`, the end tag; the carry becomes the claims on `B_in` and its root. -/
theorem inSegExec_step_ok_iff (V : Hdr → IncV) (G : Hdr → StageGeom) (H : HIn → Dig) (s : ClsStmt Hdr) (bnd : Dig)
    (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr) :
    segStep (inSeg (incStageV V G)) H s bnd bytes cr t = .ok (cr', t') ↔
      ∃ (seg : StageSeg) (e broot : Dig) (pending : List Block.ZClaim),
        decodeStage (G s.hdr) bnd (posTag H t) bytes = .ok (seg, e)
        ∧ (V s.hdr).verify H s.inRoot seg t = .ok ((pending, broot), t') ∧ posTag H t' = e ∧ cr' = ⟨pending, broot⟩ :=
  inSeg_step_ok_iff H s bnd bytes cr t cr' t' (incStageV V G)

/-- **Stage OUT-C's segment step with the executable stage** (L18's `outSeg_step_ok_iff` at `outcStageV`). -/
theorem outSegExec_step_ok_iff (V : Hdr → ℕ → OutcV) (G : Hdr → StageGeom) (H : HIn → Dig) (s : ClsStmt Hdr)
    (bnd : Dig) (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr) :
    segStep (outSeg (outcStageV V G)) H s bnd bytes cr t = .ok (cr', t') ↔
      ∃ (seg : StageSeg) (e : Dig), decodeStage (G s.hdr) bnd (posTag H t) bytes = .ok (seg, e)
        ∧ (V s.hdr s.verdict).verify H cr.root cr.pending seg t = .ok t' ∧ posTag H t' = e ∧ cr' = cr :=
  outSeg_step_ok_iff H s bnd bytes cr t cr' t' (outcStageV V G)

variable {S : ZK60.Block.BlockShape} {Salt Coins : Type}

/-- **The classify run's `Protocol` with the executable stages** (L18's `classifyProtocol` at `classifyRunV`). -/
noncomputable def classifyProtocolExec (R : ClassifyRunPublic S) (Lq : ℕ) (L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) : Protocol (QB Lq) Dig Coins (classifyModel S R) :=
  classifyProtocol S R Lq (classifyRunV L preA preB start inc incG blk outc outcG) P Cin h64 hr base

/-- **The executable protocol's verdict**: L18's run structure (`classifyVerifyE_ok_iff`) with the executable stages: the
pre-header checks, `L + 2` segments, stage IN-C's step (decode, `stage_in_c::verify`, the end tag), the blocks in order,
stage OUT-C's step. -/
theorem classifyProtocolExec_verify_iff (R : ClassifyRunPublic S) (Lq L : ℕ) (preA preB : Hdr → Except String Unit)
    (start : (HIn → Dig) → ClsStmt Hdr → Tr) (inc : Hdr → IncV) (incG : Hdr → StageGeom)
    (blk : BlockProfV (ClsStmt Hdr)) (outc : Hdr → ℕ → OutcV) (outcG : Hdr → StageGeom)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8)) :
    (classifyProtocolExec R Lq L preA preB start inc incG blk outc outcG P Cin h64 hr base).verify G () s segs = true ↔
      preA s.hdr = .ok () ∧ segs.length = L + 2 ∧ preB s.hdr = .ok () ∧
      ∃ (cr₁ cr₂ : Carry) (t₁ t₂ t₃ : Tr) (seg₀ segL : StageSeg) (e₀ eL broot : Dig) (pending : List Block.ZClaim),
        decodeStage (incG s.hdr) (start (liftH G) s).state (posTag (liftH G) (start (liftH G) s)) (segs.headD [])
          = .ok (seg₀, e₀)
        ∧ (inc s.hdr).verify (liftH G) s.inRoot seg₀ (start (liftH G) s) = .ok ((pending, broot), t₁)
        ∧ posTag (liftH G) t₁ = e₀ ∧ cr₁ = ⟨pending, broot⟩
        ∧ SegsOk (liftH G) s (start (liftH G) s).state ((List.range L).map (blockSeg blk)) ((segs.drop 1).take L) cr₁ t₁
            cr₂ t₂
        ∧ decodeStage (outcG s.hdr) (start (liftH G) s).state (posTag (liftH G) t₂) (segs.getD (L + 1) []) = .ok (segL, eL)
        ∧ (outc s.hdr s.verdict).verify (liftH G) cr₂.root cr₂.pending segL t₂ = .ok t₃ ∧ posTag (liftH G) t₃ = eL := by
  rw [classifyProtocolExec, verify_true_iff, classifyVerifyE_ok_iff]
  show _ ∧ _ ∧ _ ∧ (∃ (cr₁ cr₂ cr₃ : Carry) (t₁ t₂ t₃ : Tr),
      segStep (inSeg (incStageV inc incG)) (liftH G) s (start (liftH G) s).state (segs.headD []) carry0
        (start (liftH G) s) = .ok (cr₁, t₁)
      ∧ SegsOk (liftH G) s (start (liftH G) s).state ((List.range L).map (blockSeg blk)) ((segs.drop 1).take L) cr₁ t₁
          cr₂ t₂
      ∧ segStep (outSeg (outcStageV outc outcG)) (liftH G) s (start (liftH G) s).state (segs.getD (L + 1) []) cr₂ t₂
        = .ok (cr₃, t₃)) ↔ _
  simp only [inSegExec_step_ok_iff, outSegExec_step_ok_iff]
  constructor
  · rintro ⟨hA, hl, hB, cr₁, cr₂, cr₃, t₁, t₂, t₃, ⟨seg₀, e₀, broot, pending, hd0, hv0, he0, hc0⟩, hmid,
      ⟨segL, eL, hdL, hvL, heL, -⟩⟩
    exact ⟨hA, hl, hB, cr₁, cr₂, t₁, t₂, t₃, seg₀, segL, e₀, eL, broot, pending, hd0, hv0, he0, hc0, hmid, hdL, hvL, heL⟩
  · rintro ⟨hA, hl, hB, cr₁, cr₂, t₁, t₂, t₃, seg₀, segL, e₀, eL, broot, pending, hd0, hv0, he0, hc0, hmid, hdL, hvL, heL⟩
    exact ⟨hA, hl, hB, cr₁, cr₂, cr₂, t₁, t₂, t₃, ⟨seg₀, e₀, broot, pending, hd0, hv0, he0, hc0⟩, hmid,
      ⟨segL, eL, hdL, hvL, heL, rfl⟩⟩

end Inst

/-! ## The tier's instance of the sub-checks (lane L10's executable functions) -/

/-- **Stage IN-C's verifier at the tier's parameters**: `M` by L10's `maskField` (the code's roots of orders `512` and
`4096`; four masks), `A` and `H` by `pcsAt` at the stage's `log_cols` and rate, the input endpoint by `pcsAt` at the
endpoint's. -/
def incVAt (tag : MTag) (pub : IncPub) (geo : IncGeo) (blk ed : Dim) (lr elr q eq : ℕ) : IncV where
  pub := pub
  geo := geo
  blk := blk
  ed := ed
  maskVerify := maskField tag 4
  pcsVerify H cm root cl o t :=
    pcsAt tag pub.lt lr q H root (match cm with | .a => (incLay pub geo.bLogN).aRows | _ => (incLay pub geo.bLogN).hRows)
      cl o t
  epVerify H root cl o t := pcsAt tag pub.epLogN elr eq H root geo.epRows cl o t

/-- **Stage OUT-C's verifier at the tier's parameters** (eight masks; `B_out` at the boundary's `log_n` and rate). -/
def outcVAt (tag : MTag) (pub : OutcPub) (geo : OutcGeo) (blk bd : Dim) (stageIndex lr blr q bq : ℕ) : OutcV where
  pub := pub
  geo := geo
  blk := blk
  bd := bd
  stageIndex := stageIndex
  maskVerify := maskField tag 8
  pcsVerify H cm root cl o t :=
    pcsAt tag pub.lt lr q H root (match cm with | .a => (outcLay pub geo.bLogN).aRows | _ => (outcLay pub geo.bLogN).hRows)
      cl o t
  bVerify H root cl o t := pcsAt tag geo.bLogN blr bq H root geo.bRows cl o t

end ZK60.Exec.StageV
