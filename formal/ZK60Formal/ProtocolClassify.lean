/-
D63 lane L18 (2026-11-07), part 1: **the `Protocol` instance of the media app's classify run** (ASSEMBLY §4.0):
Shieldstral T128, stage IN-C, the `L` blocks, stage OUT-C, on the sequential D12a run.

The code (hashline `src/private_block/token_io/classify_run.rs`, read 2026-11-07; nothing there is changed):
`verify_classify_run_with` (:246-396) and `prove_classify_run_with` (:103-236). The run is ONE transcript and `L + 2`
segments:
* the pre-header checks (`rulings_are_built`, `cp.tier.check`, the D27 whole-run floor, then the counts `L` blocks and
  `L + 2` segments, then `fits_the_ntt_tables`, `check_tables`, and at an R13 profile every block's own stage shape);
* `tr = st.transcript()`, `binding = tr.state()`;
* stage IN-C: `start = position_tag(tr)`, decode segment 0 against the binding and `start` (it carries its end tag),
  `stage_in_c::verify` (the claims it leaves pending on `B_in` and `B_in`'s root), the end tag compared;
* block `k`: the block loaded and checked (`stage_block_is_the_statements`), `start`, decode segment `k + 1` (D12a's
  `wire::decode_segment`), the paths' depth, `absorb_u64("pb-run-stage", k + 1)`, `absorb("pb-run-block", digest_k)`,
  the segment's boundary root `B_{k+1}` (`absorb_root("B")`), `verify_core` (the block profile), the claims
  `pending ++ io_in`, `boundary::check_opening` and `pcs::verify_zk_tagged` of the PREVIOUS boundary's root, `pending
  = io_out`, the end tag compared;
* stage OUT-C: `start`, decode segment `L + 1`, `stage_out_c::verify` (the statement's verdict, the last boundary's
  root, the pending claims), the end tag compared.

Here every part the run CALLS is a parameter (`StageInV`, `BlockProfV`, `StageOutV`): the BLOCK PROFILE is a parameter
so that W16R2 (lanes L9–L11) and R13 (lane L17, the media app's real profile, A25) both instantiate it. What the run
itself does is written out: the position tags (L9's `posTag`), the binding, the segment count, the framing absorbs,
the carry of pending claims and of the previous boundary root, the end-tag comparisons, in the code's order.

* `ClsStmt` (the statement: its public header, the input endpoint's root `st.in_root()`, the PUBLIC verdict),
  `ClsReceipt` (the `L + 2` segments' bytes), `Carry`, `SegV` / `segStep` / `runSegs` (one framed segment; the run of
  them), `inSeg`, `blockSeg`, `outSeg`, `RunV` (the verifier's parts), **`classifyVerifyE`** (`verify_classify_run_with`).
* the honest prover as a SPECIFICATION: `SegP` / `proveSegs` (the parts' honest provers on one transcript),
  `RunP`, **`runProve`** (`prove_classify_run_with`: the sealing pass refuses an inadmissible input before any
  header; D65(2): every refusal is ONE constant output).
* **`classifyProtocol`**: the `Protocol (QB Lq) Dig Coins (classifyModel S R)` instance: `Leak` = the shapes, `T`, `L`
  and the served bit (`ClsLeak`), `ypub` = the statement's verdict, `opensIn` = lane L10's plane-commitment opening
  (`BindingW16.lean`), `opensOut` = L10's `opensUnit` (the classifier's hidden output is `Unit`, L12-5).

Proved:
* **`runSegs_ok_iff`**, `segsOk_append`, `segsOk_length`: the run of segments accepts exactly when every segment, in
  order, accepts from the carry and the transcript the previous one left;
* **`classifyVerifyE_ok_iff`**: the verifier accepts EXACTLY when the pre-header checks pass, there are `L + 2`
  segments, stage IN-C accepts segment 0 from the run header's transcript, the `L` blocks accept segments `1 … L` in
  order, and stage OUT-C accepts segment `L + 1` (the structure of `verify_classify_run_with`);
* **`blockSeg_step_ok_iff`**, `inSeg_step_ok_iff`, `outSeg_step_ok_iff`, `segStep_ok_iff`: each part's step unfolded,
  in the code's order (for a block: the statement check, the decode at the transcript's position tag, the paths, the
  boundary root, the framing absorbs and `B_{k+1}`'s root, the block profile's core, the boundary audit and opening
  of `B_k`, the end tag);
* **`runSegs_of_proveSegs`**, `proveSegs_length`: if every part's honest segment is accepted by the part's verifier
  (`SegComplete`), the honest run of segments is accepted (completeness's composition, used in
  `ProtocolClassifyComplete.lean`);
* **`planeCommit_opens_honest`**, **`honestIn_opens`**: the honest input commitment (the Merkle root of the honest
  columns, `CompleteSub.lean`'s `treeRoot`) opens to the input with the honest paths (`opens_honest`);
* `admissible_canon`, `prove_unserved` (D65(2)), `verify_true_iff`, `leak_served`, `opensIn_iff`.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.CircuitTokenRun
import ZK60Formal.BindingW16
import ZK60Formal.ExecBlockVerify
import ZK60Formal.CompleteSub

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun
open ZK60.Circuit (gP GF)
open ZK60.Exec.Block (ZClaim posTag absorbRoot)

/-! ## `Except` steps -/

/-- A bind accepts exactly when its first step does and the continuation accepts its value. -/
theorem ex_bind_ok_iff {ε α β : Type} (e : Except ε α) (f : α → Except ε β) (b : β) :
    (e >>= f) = .ok b ↔ ∃ a, e = .ok a ∧ f a = .ok b := by
  cases e with
  | error err => exact ⟨fun h => (by cases h), fun ⟨_, h, _⟩ => by cases h⟩
  | ok a => exact ⟨fun h => ⟨a, rfl, h⟩, fun ⟨a', h, h'⟩ => by cases h; exact h'⟩

/-- A guarded value. -/
theorem ite_ok_iff {ε α : Type} (c : Prop) [Decidable c] (a b : α) (m : ε) :
    (if c then (Except.ok a : Except ε α) else .error m) = .ok b ↔ c ∧ a = b := by
  by_cases hc : c
  · rw [ite_eq_left hc]
    exact ⟨fun h => ⟨hc, (by cases h; rfl)⟩, fun ⟨_, h⟩ => by rw [h]⟩
  · rw [ite_eq_right hc]
    exact ⟨fun h => (by cases h), fun ⟨h, _⟩ => absurd h hc⟩

/-- An optional value, refused when absent (`ok_or_else(…)?`). -/
def optOk {ε α : Type} (o : Option α) (m : ε) : Except ε α :=
  match o with
  | some a => .ok a
  | none => .error m

theorem optOk_eq_ok {ε α : Type} (o : Option α) (m : ε) (a : α) : optOk o m = .ok a ↔ o = some a := by
  cases o with
  | none => exact ⟨fun h => (by cases h), fun h => by cases h⟩
  | some a' => exact ⟨fun h => (by cases h; rfl), fun h => by cases h; rfl⟩

/-! ## The run's labels (`b"..."`, ASCII) -/

/-- `b"pb-run-stage"` (classify_run.rs:182, :320). -/
def labRunStage : List UInt8 := [112, 98, 45, 114, 117, 110, 45, 115, 116, 97, 103, 101]
/-- `b"pb-run-block"` (classify_run.rs:183, :321). -/
def labRunBlock : List UInt8 := [112, 98, 45, 114, 117, 110, 45, 98, 108, 111, 99, 107]
/-- `b"B"` (`absorb_root(&mut tr, b"B", …)`, classify_run.rs:196, :324). -/
def labB : List UInt8 := [66]

/-! ## The statement, the receipt, the carry -/

/-- **The classify run's statement** (`ClassifyRunStatement`): its public header `hdr` (the profile string, the shapes,
`L`, the block digests, the policy, the tables' binding, the trained statement: what the verifier checks against its
own registered data), the input endpoint commitment's root (`st.in_root()`), and the PUBLIC verdict (`st.verdict()`,
absorbed by the statement, stage_out_c.rs:20-21). -/
structure ClsStmt (Hdr : Type) where
  hdr : Hdr
  inRoot : Dig
  verdict : ℕ

/-- **The receipt**: the `L + 2` segments' bytes, as `verify_classify_run_with` takes them (`segments: &[Vec<u8>]`). -/
abbrev ClsReceipt : Type := List (List UInt8)

/-- What one segment hands to the next (`pending`, and `prev`'s root, in `verify_classify_run_with`): the claims left
pending on the last boundary commitment, and that boundary's root. -/
structure Carry where
  pending : List ZClaim
  root : Dig

/-- Before stage IN-C nothing is pending (stage IN-C ignores the carry it is handed). -/
def carry0 : Carry := ⟨[], zeroDig⟩

/-! ## One framed segment, and the run of segments -/

/-- **One segment of the run, as the verifier reads it**: from the hash, the statement, the segment's bytes, the
binding and the START tag (the position tag of the transcript it is handed), the carry and the transcript, it decodes
and checks the segment and returns the carry, the transcript after it and the END tag the segment carries. `trailer`
is the refusal when the end tag is not the verifier's own position. -/
structure SegV (St : Type) where
  run : (HIn → Dig) → St → List UInt8 → Dig → Dig → Carry → Tr → Except String (Carry × Tr × Dig)
  trailer : String

/-- **One framed segment** (`let start = position_tag(&tr); let (seg, end) = …decode(…, &binding, &start)?; …verify…;
if position_tag(&tr) != end { return Err(…) }`). -/
def segStep {St : Type} (v : SegV St) (H : HIn → Dig) (s : St) (bnd : Dig) (bytes : List UInt8) (cr : Carry) (t : Tr) :
    Except String (Carry × Tr) :=
  v.run H s bytes bnd (posTag H t) cr t >>= fun r =>
    if posTag H r.2.1 = r.2.2 then .ok (r.1, r.2.1) else .error v.trailer

/-- **The run of segments**: each segment in order, on the carry and the transcript the previous one left. -/
def runSegs {St : Type} (H : HIn → Dig) (s : St) (bnd : Dig) :
    List (SegV St) → List (List UInt8) → Carry → Tr → Except String (Carry × Tr)
  | [], [], cr, t => .ok (cr, t)
  | v :: vs, b :: bs, cr, t => segStep v H s bnd b cr t >>= fun r => runSegs H s bnd vs bs r.1 r.2
  | [], _ :: _, _, _ => .error "classifier run: more segments than parts"
  | _ :: _, [], _, _ => .error "classifier run: fewer segments than parts"

/-- **Every segment accepts, in order**: the relational form of `runSegs`. -/
def SegsOk {St : Type} (H : HIn → Dig) (s : St) (bnd : Dig) :
    List (SegV St) → List (List UInt8) → Carry → Tr → Carry → Tr → Prop
  | [], [], cr, t, cr', t' => cr' = cr ∧ t' = t
  | v :: vs, b :: bs, cr, t, cr', t' =>
    ∃ cr₁ t₁, segStep v H s bnd b cr t = .ok (cr₁, t₁) ∧ SegsOk H s bnd vs bs cr₁ t₁ cr' t'
  | [], _ :: _, _, _, _, _ => False
  | _ :: _, [], _, _, _, _ => False

section Segs

variable {St : Type} (H : HIn → Dig) (s : St) (bnd : Dig)

/-- One framed segment accepts exactly when its part accepts and its end tag is the verifier's own position. -/
theorem segStep_ok_iff (v : SegV St) (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr) :
    segStep v H s bnd bytes cr t = .ok (cr', t') ↔
      ∃ e, v.run H s bytes bnd (posTag H t) cr t = .ok (cr', t', e) ∧ posTag H t' = e := by
  unfold segStep
  rw [ex_bind_ok_iff]
  constructor
  · rintro ⟨⟨c, τ, e⟩, h1, h2⟩
    obtain ⟨he, h⟩ := (ite_ok_iff _ _ _ _).mp h2
    simp only [Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨e, h1, he⟩
  · rintro ⟨e, h1, he⟩
    exact ⟨(cr', t', e), h1, (ite_ok_iff _ _ _ _).mpr ⟨he, rfl⟩⟩

/-- **The run of segments accepts exactly when every segment accepts in order.** -/
theorem runSegs_ok_iff : ∀ (vs : List (SegV St)) (bs : List (List UInt8)) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr),
    runSegs H s bnd vs bs cr t = .ok (cr', t') ↔ SegsOk H s bnd vs bs cr t cr' t'
  | [], [], cr, t, cr', t' => by
    show Except.ok (cr, t) = .ok (cr', t') ↔ cr' = cr ∧ t' = t
    exact ⟨fun h => (by cases h; exact ⟨rfl, rfl⟩), fun ⟨h1, h2⟩ => by rw [h1, h2]⟩
  | [], _ :: _, cr, t, cr', t' => ⟨fun h => (by cases h), fun h => False.elim h⟩
  | _ :: _, [], cr, t, cr', t' => ⟨fun h => (by cases h), fun h => False.elim h⟩
  | v :: vs, b :: bs, cr, t, cr', t' => by
    show (segStep v H s bnd b cr t >>= fun r => runSegs H s bnd vs bs r.1 r.2) = .ok (cr', t')
      ↔ ∃ cr₁ t₁, segStep v H s bnd b cr t = .ok (cr₁, t₁) ∧ SegsOk H s bnd vs bs cr₁ t₁ cr' t'
    rw [ex_bind_ok_iff]
    constructor
    · rintro ⟨⟨c, τ⟩, h1, h2⟩
      exact ⟨c, τ, h1, (runSegs_ok_iff vs bs c τ cr' t').mp h2⟩
    · rintro ⟨c, τ, h1, h2⟩
      exact ⟨(c, τ), h1, (runSegs_ok_iff vs bs c τ cr' t').mpr h2⟩

/-- Accepted segments are as many as the parts. -/
theorem segsOk_length : ∀ (vs : List (SegV St)) (bs : List (List UInt8)) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr),
    SegsOk H s bnd vs bs cr t cr' t' → bs.length = vs.length
  | [], [], _, _, _, _, _ => rfl
  | [], _ :: _, _, _, _, _, h => False.elim h
  | _ :: _, [], _, _, _, _, h => False.elim h
  | _ :: vs, _ :: bs, _, _, _, _, h => by
    obtain ⟨c, τ, -, h⟩ := h
    simp only [List.length_cons, segsOk_length vs bs c τ _ _ h]

/-- **Splitting the run** after its first parts: the segments up to there, then the rest. -/
theorem segsOk_append : ∀ (vs₁ vs₂ : List (SegV St)) (bs : List (List UInt8)) (cr : Carry) (t : Tr) (cr' : Carry)
    (t' : Tr), SegsOk H s bnd (vs₁ ++ vs₂) bs cr t cr' t' ↔
      ∃ cr₁ t₁, SegsOk H s bnd vs₁ (bs.take vs₁.length) cr t cr₁ t₁
        ∧ SegsOk H s bnd vs₂ (bs.drop vs₁.length) cr₁ t₁ cr' t'
  | [], vs₂, bs, cr, t, cr', t' => by
    simp only [List.nil_append, List.length_nil, List.take_zero, List.drop_zero]
    constructor
    · intro h
      exact ⟨cr, t, (show cr = cr ∧ t = t from ⟨rfl, rfl⟩), h⟩
    · rintro ⟨c, τ, h1, h2⟩
      obtain ⟨e1, e2⟩ := (show c = cr ∧ τ = t from h1)
      rw [e1, e2] at h2
      exact h2
  | v :: vs₁, vs₂, [], cr, t, cr', t' =>
    ⟨fun h => False.elim h, fun ⟨_, _, h, _⟩ => by simp [SegsOk] at h⟩
  | v :: vs₁, vs₂, b :: bs, cr, t, cr', t' => by
    show (∃ c τ, segStep v H s bnd b cr t = .ok (c, τ) ∧ SegsOk H s bnd (vs₁ ++ vs₂) bs c τ cr' t') ↔
      ∃ cr₁ t₁, (∃ c τ, segStep v H s bnd b cr t = .ok (c, τ) ∧ SegsOk H s bnd vs₁ (bs.take vs₁.length) c τ cr₁ t₁)
        ∧ SegsOk H s bnd vs₂ (bs.drop vs₁.length) cr₁ t₁ cr' t'
    constructor
    · rintro ⟨c, τ, h1, h2⟩
      obtain ⟨c', τ', h3, h4⟩ := (segsOk_append vs₁ vs₂ bs c τ cr' t').mp h2
      exact ⟨c', τ', ⟨c, τ, h1, h3⟩, h4⟩
    · rintro ⟨c', τ', ⟨c, τ, h1, h3⟩, h4⟩
      exact ⟨c, τ, h1, (segsOk_append vs₁ vs₂ bs c τ cr' t').mpr ⟨c', τ', h3, h4⟩⟩

/-- One part, one segment. -/
theorem segsOk_single (v : SegV St) (b : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr) :
    SegsOk H s bnd [v] [b] cr t cr' t' ↔ segStep v H s bnd b cr t = .ok (cr', t') := by
  show (∃ c τ, segStep v H s bnd b cr t = .ok (c, τ) ∧ (cr' = c ∧ t' = τ)) ↔ _
  constructor
  · rintro ⟨c, τ, h1, h2, h3⟩
    rw [h2, h3]
    exact h1
  · intro h
    exact ⟨cr', t', h, rfl, rfl⟩

end Segs

/-! ## The parts the run calls -/

/-- **Stage IN-C, as the run calls it**: its segment's decoder (`st.in_geom(&in_lay).decode(bytes, &binding, &start)`:
the segment and its end tag) and `stage_in_c::verify` (on the statement's `in_spec` and `in_root()`: the claims it leaves
pending on `B_in`, and `B_in`'s root). -/
structure StageInV (St : Type) where
  Seg : Type
  decode : St → List UInt8 → Dig → Dig → Except String (Seg × Dig)
  verify : (HIn → Dig) → St → Seg → Tr → Except String ((List ZClaim × Dig) × Tr)

/-- **A block profile, as the run calls it** (W16R2: L9's `blockVerify` with L10's and L11's fields; R13: lane L17).
`check` is `stage_block_is_the_statements` (the block's `check_for_shape` and CS-6, the digest); `decode` is D12a's
`wire::decode_segment` (the segment and its end tag); `paths` is `segment_paths_are_the_tree_depth`; `bRoot` the
segment's boundary root (`seg.b_root`); `digest k` is `st.block_digests[k]`; `bRows`, `bLogN` are boundary `k`'s
`commitment_rows()` and `log_n()`; `core` is `verify_core` at block `k`'s stage shape (its IO claims: incoming,
outgoing); `bndCheck` and `bndOpen` are `boundary::check_opening` and `pcs::verify_zk_tagged` of boundary `k` (the
previous boundary's root, the claims, the segment's `in_open`). -/
structure BlockProfV (St : Type) where
  Seg : Type
  check : St → ℕ → Except String Unit
  decode : St → ℕ → List UInt8 → Dig → Dig → Except String (Seg × Dig)
  paths : St → Seg → Except String Unit
  bRoot : Seg → Option Dig
  digest : St → ℕ → Dig
  bRows : ℕ → ℕ
  bLogN : ℕ → ℕ
  core : (HIn → Dig) → St → ℕ → Seg → Tr → Except String ((List ZClaim × List ZClaim) × Tr)
  bndCheck : St → ℕ → List ZClaim → Tr → Except String Unit
  bndOpen : (HIn → Dig) → St → ℕ → Dig → List ZClaim → Seg → Tr → Except String Tr

/-- **Stage OUT-C, as the run calls it**: its segment's decoder and `stage_out_c::verify` (the statement's verdict, the
last boundary's root, the pending claims, at stage `L + 1`). -/
structure StageOutV (St : Type) where
  Seg : Type
  decode : St → List UInt8 → Dig → Dig → Except String (Seg × Dig)
  verify : (HIn → Dig) → St → Seg → Dig → List ZClaim → Tr → Except String Tr

variable {St : Type}

/-- Stage IN-C's segment (classify_run.rs:285-297). -/
def inSeg (I : StageInV St) : SegV St where
  trailer := "classifier run: stage IN-C's trailer is not the verifier's own transcript position"
  run H s bytes bnd start _ t :=
    I.decode s bytes bnd start >>= fun d =>
    I.verify H s d.1 t >>= fun r => .ok (⟨r.1.1, r.1.2⟩, r.2, d.2)

/-- The run's framing of block `k` before its core: `absorb_u64("pb-run-stage", k + 1)`, `absorb("pb-run-block",
digest_k)`, `absorb_root("B", B_{k+1}, rows, log_n)` (classify_run.rs:320-324). -/
def blockFrame (B : BlockProfV St) (H : HIn → Dig) (s : St) (k : ℕ) (root : Dig) (t : Tr) : Tr :=
  absorbRoot H ((t.absorbU64 H labRunStage (UInt64.ofNat (k + 1))).absorb H labRunBlock (B.digest s k).toList) labB root
    (B.bRows (k + 1)) (B.bLogN (k + 1))

/-- Block `k`'s segment (classify_run.rs:307-371). -/
def blockSeg (B : BlockProfV St) (k : ℕ) : SegV St where
  trailer := "classifier run: a block segment's trailer is not the verifier's own transcript position"
  run H s bytes bnd start cr t :=
    B.check s k >>= fun _ =>
    B.decode s k bytes bnd start >>= fun d =>
    B.paths s d.1 >>= fun _ =>
    optOk (B.bRoot d.1) "classifier run: a block segment carries no boundary root" >>= fun root =>
    B.core H s k d.1 (blockFrame B H s k root t) >>= fun c =>
    B.bndCheck s k (cr.pending ++ c.1.1) c.2 >>= fun _ =>
    B.bndOpen H s k cr.root (cr.pending ++ c.1.1) d.1 c.2 >>= fun t₃ =>
    .ok (⟨c.1.2, root⟩, t₃, d.2)

/-- Stage OUT-C's segment (classify_run.rs:375-385). -/
def outSeg (O : StageOutV St) : SegV St where
  trailer := "classifier run: stage OUT-C's trailer is not the verifier's own transcript position"
  run H s bytes bnd start cr t :=
    O.decode s bytes bnd start >>= fun d =>
    O.verify H s d.1 cr.root cr.pending t >>= fun t' => .ok (cr, t', d.2)

/-! ## Each part's step, unfolded in the code's order -/

section Steps

variable (H : HIn → Dig) (s : St) (bnd : Dig) (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr)

/-- **Stage IN-C's step**: decode at the transcript's position tag, `stage_in_c::verify`, the end tag. -/
theorem inSeg_step_ok_iff (I : StageInV St) :
    segStep (inSeg I) H s bnd bytes cr t = .ok (cr', t') ↔
      ∃ (seg : I.Seg) (e broot : Dig) (pending : List ZClaim), I.decode s bytes bnd (posTag H t) = .ok (seg, e)
        ∧ I.verify H s seg t = .ok ((pending, broot), t') ∧ posTag H t' = e ∧ cr' = ⟨pending, broot⟩ := by
  rw [segStep_ok_iff]
  show (∃ e, (I.decode s bytes bnd (posTag H t) >>= fun d =>
      I.verify H s d.1 t >>= fun r => .ok (⟨r.1.1, r.1.2⟩, r.2, d.2)) = .ok (cr', t', e) ∧ posTag H t' = e) ↔ _
  simp only [ex_bind_ok_iff]
  constructor
  · rintro ⟨e, ⟨⟨seg, e'⟩, h1, ⟨⟨pending, broot⟩, τ⟩, h2, h3⟩, he⟩
    simp only [Except.ok.injEq, Prod.mk.injEq] at h3
    obtain ⟨rfl, rfl, rfl⟩ := h3
    exact ⟨seg, e', broot, pending, h1, h2, he, rfl⟩
  · rintro ⟨seg, e, broot, pending, h1, h2, he, rfl⟩
    exact ⟨e, ⟨(seg, e), h1, ((pending, broot), t'), h2, rfl⟩, he⟩

/-- **Block `k`'s step**, in the code's order: the statement check (`stage_block_is_the_statements`), the decode at the
transcript's position tag, the paths' depth, the boundary root `B_{k+1}`, the framing absorbs and `B_{k+1}`'s root
(`blockFrame`), the block profile's core, the claims `pending ++ io_in` audited and opened against the PREVIOUS
boundary's root, the end tag; the carry becomes `(io_out, B_{k+1})`. -/
theorem blockSeg_step_ok_iff (B : BlockProfV St) (k : ℕ) :
    segStep (blockSeg B k) H s bnd bytes cr t = .ok (cr', t') ↔
      B.check s k = .ok () ∧ ∃ (seg : B.Seg) (e root : Dig) (ic oc : List ZClaim) (t₂ : Tr),
        B.decode s k bytes bnd (posTag H t) = .ok (seg, e) ∧ B.paths s seg = .ok () ∧ B.bRoot seg = some root
        ∧ B.core H s k seg (blockFrame B H s k root t) = .ok ((ic, oc), t₂)
        ∧ B.bndCheck s k (cr.pending ++ ic) t₂ = .ok ()
        ∧ B.bndOpen H s k cr.root (cr.pending ++ ic) seg t₂ = .ok t'
        ∧ posTag H t' = e ∧ cr' = ⟨oc, root⟩ := by
  rw [segStep_ok_iff]
  show (∃ e, (B.check s k >>= fun _ =>
    B.decode s k bytes bnd (posTag H t) >>= fun d =>
    B.paths s d.1 >>= fun _ =>
    optOk (B.bRoot d.1) "classifier run: a block segment carries no boundary root" >>= fun root =>
    B.core H s k d.1 (blockFrame B H s k root t) >>= fun c =>
    B.bndCheck s k (cr.pending ++ c.1.1) c.2 >>= fun _ =>
    B.bndOpen H s k cr.root (cr.pending ++ c.1.1) d.1 c.2 >>= fun t₃ =>
    .ok (⟨c.1.2, root⟩, t₃, d.2)) = .ok (cr', t', e) ∧ posTag H t' = e) ↔ _
  simp only [ex_bind_ok_iff, optOk_eq_ok]
  constructor
  · rintro ⟨e, ⟨⟨⟩, h1, ⟨seg, e'⟩, h2, ⟨⟩, h3, root, h4, ⟨⟨ic, oc⟩, t₂⟩, h5, ⟨⟩, h6, t₃, h7, h8⟩, he⟩
    simp only [Except.ok.injEq, Prod.mk.injEq] at h8
    obtain ⟨rfl, rfl, rfl⟩ := h8
    exact ⟨h1, seg, e', root, ic, oc, t₂, h2, h3, h4, h5, h6, h7, he, rfl⟩
  · rintro ⟨h1, seg, e, root, ic, oc, t₂, h2, h3, h4, h5, h6, h7, he, rfl⟩
    exact ⟨e, ⟨(), h1, (seg, e), h2, (), h3, root, h4, ((ic, oc), t₂), h5, (), h6, t', h7, rfl⟩, he⟩

/-- **Stage OUT-C's step**: decode at the transcript's position tag, `stage_out_c::verify` on the carry (the last
boundary's root, the pending claims), the end tag. -/
theorem outSeg_step_ok_iff (O : StageOutV St) :
    segStep (outSeg O) H s bnd bytes cr t = .ok (cr', t') ↔
      ∃ (seg : O.Seg) (e : Dig), O.decode s bytes bnd (posTag H t) = .ok (seg, e)
        ∧ O.verify H s seg cr.root cr.pending t = .ok t' ∧ posTag H t' = e ∧ cr' = cr := by
  rw [segStep_ok_iff]
  show (∃ e, (O.decode s bytes bnd (posTag H t) >>= fun d =>
      O.verify H s d.1 cr.root cr.pending t >>= fun t' => .ok (cr, t', d.2)) = .ok (cr', t', e) ∧ posTag H t' = e) ↔ _
  simp only [ex_bind_ok_iff]
  constructor
  · rintro ⟨e, ⟨⟨seg, e'⟩, h1, τ, h2, h3⟩, he⟩
    simp only [Except.ok.injEq, Prod.mk.injEq] at h3
    obtain ⟨rfl, rfl, rfl⟩ := h3
    exact ⟨seg, e', h1, h2, he, rfl⟩
  · rintro ⟨seg, e, h1, h2, he, rfl⟩
    exact ⟨e, ⟨(seg, e), h1, t', h2, rfl⟩, he⟩

end Steps

/-! ## The run's verifier -/

/-- **The classify run's verifier, its parts**: `L` (the statement's block count), the pre-header checks before the
segment count (`preA`: `rulings_are_built`, `cp.tier.check`, the D27 whole-run floor) and after it (`preB`:
`fits_the_ntt_tables`, `check_tables`, at R13 every block's own stage shape), the run header (`st.transcript()`), and
the three parts the run calls. -/
structure RunV (Hdr : Type) where
  L : ℕ
  preA : Hdr → Except String Unit
  preB : Hdr → Except String Unit
  start : (HIn → Dig) → ClsStmt Hdr → Tr
  inC : StageInV (ClsStmt Hdr)
  blk : BlockProfV (ClsStmt Hdr)
  outC : StageOutV (ClsStmt Hdr)

variable {Hdr : Type}

/-- The run's parts in order: stage IN-C, block `0`, …, block `L − 1`, stage OUT-C. -/
def RunV.parts (V : RunV Hdr) : List (SegV (ClsStmt Hdr)) :=
  inSeg V.inC :: ((List.range V.L).map (blockSeg V.blk) ++ [outSeg V.outC])

theorem RunV.parts_length (V : RunV Hdr) : V.parts.length = V.L + 2 := by
  simp [RunV.parts]

/-- The segment count check. -/
def countOk (n L : ℕ) : Except String Unit :=
  if n = L + 2 then .ok () else .error "classifier run: the segments offered are not the run's L + 2"

theorem countOk_eq_ok (n L : ℕ) (u : Unit) : countOk n L = .ok u ↔ n = L + 2 := by
  unfold countOk
  rw [ite_ok_iff]
  exact ⟨fun h => h.1, fun h => ⟨h, rfl⟩⟩

/-- **`verify_classify_run_with`**: the pre-header checks, the segment count, then the run of the `L + 2` segments on
ONE transcript from the run header, the binding its state. -/
def classifyVerifyE (V : RunV Hdr) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8)) : Except String Unit :=
  V.preA s.hdr >>= fun _ =>
  countOk segs.length V.L >>= fun _ =>
  V.preB s.hdr >>= fun _ =>
  runSegs H s (V.start H s).state V.parts segs carry0 (V.start H s) >>= fun _ => .ok ()

/-- An `Except` as a verdict. -/
def okB {ε α : Type} : Except ε α → Bool
  | .ok _ => true
  | .error _ => false

theorem okB_eq_true {ε α : Type} (e : Except ε α) : okB e = true ↔ ∃ a, e = .ok a := by
  cases e with
  | error x => exact ⟨fun h => (by cases h), fun ⟨_, h⟩ => by cases h⟩
  | ok a => exact ⟨fun _ => ⟨a, rfl⟩, fun _ => rfl⟩

/-- **The structure of `verify_classify_run_with`.** The verifier accepts EXACTLY when the pre-header checks pass,
there are `L + 2` segments, and on the run header's transcript (its state the binding): stage IN-C accepts segment `0`
from nothing pending; the blocks accept segments `1, …, L` IN ORDER, each from the carry and transcript the previous
left (`SegsOk` over `blockSeg 0, …, blockSeg (L − 1)`); and stage OUT-C accepts segment `L + 1` from the last
block's carry. -/
theorem classifyVerifyE_ok_iff (V : RunV Hdr) (H : HIn → Dig) (s : ClsStmt Hdr) (segs : List (List UInt8)) :
    classifyVerifyE V H s segs = .ok () ↔
      V.preA s.hdr = .ok () ∧ segs.length = V.L + 2 ∧ V.preB s.hdr = .ok () ∧
      ∃ (cr₁ cr₂ cr₃ : Carry) (t₁ t₂ t₃ : Tr),
        segStep (inSeg V.inC) H s (V.start H s).state (segs.headD []) carry0 (V.start H s) = .ok (cr₁, t₁)
        ∧ SegsOk H s (V.start H s).state ((List.range V.L).map (blockSeg V.blk)) ((segs.drop 1).take V.L) cr₁ t₁ cr₂ t₂
        ∧ segStep (outSeg V.outC) H s (V.start H s).state (segs.getD (V.L + 1) []) cr₂ t₂ = .ok (cr₃, t₃) := by
  unfold classifyVerifyE
  simp only [ex_bind_ok_iff, countOk_eq_ok]
  have hmid : (List.map (blockSeg V.blk) (List.range V.L)).length = V.L := by simp
  constructor
  · rintro ⟨⟨⟩, hA, ⟨⟩, hl, ⟨⟩, hB, ⟨cr, t⟩, hr, -⟩
    refine ⟨hA, hl, hB, ?_⟩
    obtain ⟨b0, rest, rfl⟩ : ∃ b0 rest, segs = b0 :: rest := by
      cases segs with
      | nil => simp at hl
      | cons b0 rest => exact ⟨b0, rest, rfl⟩
    have hrl : rest.length = V.L + 1 := by simpa using hl
    have hdrop : rest.drop V.L = [rest.getD V.L []] := by
      have hlt : V.L < rest.length := by omega
      rw [List.drop_eq_getElem_cons hlt, List.drop_eq_nil_of_le (by omega)]
      simp [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hlt]
    rw [runSegs_ok_iff] at hr
    obtain ⟨cr₁, t₁, h1, h2⟩ := (show ∃ cr₁ t₁, segStep (inSeg V.inC) H s (V.start H s).state b0 carry0 (V.start H s)
        = .ok (cr₁, t₁) ∧ SegsOk H s (V.start H s).state ((List.range V.L).map (blockSeg V.blk) ++ [outSeg V.outC]) rest
          cr₁ t₁ cr t from hr)
    rw [segsOk_append, hmid, hdrop] at h2
    obtain ⟨cr₂, t₂, h2, h3⟩ := h2
    rw [segsOk_single] at h3
    refine ⟨cr₁, cr₂, cr, t₁, t₂, t, h1, ?_, ?_⟩
    · simpa using h2
    · simpa [List.getD_eq_getElem?_getD] using h3
  · rintro ⟨hA, hl, hB, cr₁, cr₂, cr₃, t₁, t₂, t₃, h1, h2, h3⟩
    refine ⟨(), hA, (), hl, (), hB, (cr₃, t₃), ?_, trivial⟩
    obtain ⟨b0, rest, rfl⟩ : ∃ b0 rest, segs = b0 :: rest := by
      cases segs with
      | nil => simp at hl
      | cons b0 rest => exact ⟨b0, rest, rfl⟩
    have hrl : rest.length = V.L + 1 := by simpa using hl
    have hdrop : rest.drop V.L = [rest.getD V.L []] := by
      have hlt : V.L < rest.length := by omega
      rw [List.drop_eq_getElem_cons hlt, List.drop_eq_nil_of_le (by omega)]
      simp [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hlt]
    rw [runSegs_ok_iff]
    show ∃ c τ, segStep (inSeg V.inC) H s (V.start H s).state b0 carry0 (V.start H s) = .ok (c, τ)
      ∧ SegsOk H s (V.start H s).state ((List.range V.L).map (blockSeg V.blk) ++ [outSeg V.outC]) rest c τ cr₃ t₃
    refine ⟨cr₁, t₁, by simpa using h1, ?_⟩
    rw [segsOk_append, hmid, hdrop]
    refine ⟨cr₂, t₂, by simpa using h2, ?_⟩
    rw [segsOk_single]
    simpa [List.getD_eq_getElem?_getD] using h3

/-! ## The honest prover, as a specification -/

/-- **One segment of the honest run, as the prover produces it**: from the hash, the statement, the input, the coins,
the binding and the start tag, the carry and the transcript, the segment's bytes AS A FUNCTION OF ITS END TAG (the
frame carries `end = position_tag(&tr)` after the part), the carry it hands on and the transcript after it.
`.error ()` is a refusal: D65(2), every refusal that leaves the prover reads the same. -/
structure SegP (St X Coins : Type) where
  run : (HIn → Dig) → St → X → Coins → Dig → Dig → Carry → Tr → Except Unit ((Dig → List UInt8) × Carry × Tr)

/-- **The honest run of segments** on one transcript: each part's bytes framed with the end tag of the transcript it
leaves (`let end = position_tag(&tr); … encode(…, &binding, &start, &end)`). -/
def proveSegs {X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    List (SegP St X Coins) → Carry → Tr → Except Unit (List (List UInt8) × Carry × Tr)
  | [], cr, t => .ok ([], cr, t)
  | p :: ps, cr, t =>
    p.run H s x c bnd (posTag H t) cr t >>= fun r =>
    proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' => .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2)

/-- **The per-part completeness contract**: for every oracle `g` (the hash `hOf g`), whenever the part's honest prover
(for an admissible input `x`, on the honest statement `stOf g x c`) produces bytes, a carry and a transcript from the
transcript `t` and the carry `cr`, the part's verifier, handed the same transcript and carry and the bytes framed with
the end tag `posTag t'`, accepts and returns that carry, that transcript and that end tag. This is a DETERMINISTIC
statement (every oracle, every coin): the prover's refusals are its only completeness losses. -/
def SegComplete {X Coins Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (p : SegP St X Coins) (v : SegV St) : Prop :=
  ∀ (g : Γ) (x : X) (c : Coins) (bnd : Dig) (cr : Carry) (t : Tr) (enc : Dig → List UInt8) (cr' : Carry)
    (t' : Tr), adm x → p.run (hOf g) (stOf g x c) x c bnd (posTag (hOf g) t) cr t = .ok (enc, cr', t') →
      v.run (hOf g) (stOf g x c) (enc (posTag (hOf g) t')) bnd (posTag (hOf g) t) cr t
        = .ok (cr', t', posTag (hOf g) t')

/-- **The honest run is accepted, part by part** (completeness's composition): if every part's honest segment is
accepted (`SegComplete`, part by part), the honest run of segments is accepted and lands on the prover's carry and
transcript. -/
theorem runSegs_of_proveSegs {X Coins Γ : Type} (adm : X → Prop) (hOf : Γ → HIn → Dig) (stOf : Γ → X → Coins → St)
    (g : Γ) (x : X) (c : Coins) (bnd : Dig) (hx : adm x) :
    ∀ (ps : List (SegP St X Coins)) (vs : List (SegV St)), List.Forall₂ (SegComplete adm hOf stOf) ps vs →
      ∀ (cr : Carry) (t : Tr) (bs : List (List UInt8)) (cr' : Carry) (t' : Tr),
        proveSegs (hOf g) (stOf g x c) x c bnd ps cr t = .ok (bs, cr', t') →
          runSegs (hOf g) (stOf g x c) bnd vs bs cr t = .ok (cr', t')
  | [], [], _, cr, t, bs, cr', t', h => by
    have h' : Except.ok ([], cr, t) = (Except.ok (bs, cr', t') : Except Unit _) := h
    cases h'
    rfl
  | [], _ :: _, hpv, _, _, _, _, _, _ => absurd hpv (by simp)
  | _ :: _, [], hpv, _, _, _, _, _, _ => absurd hpv (by simp)
  | p :: ps, v :: vs, hpv, cr, t, bs, cr', t', h => by
    obtain ⟨hpv1, hpv2⟩ := List.forall₂_cons.mp hpv
    have h' : (p.run (hOf g) (stOf g x c) x c bnd (posTag (hOf g) t) cr t >>= fun r =>
        proveSegs (hOf g) (stOf g x c) x c bnd ps r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag (hOf g) r.2.2) :: r'.1, r'.2.1, r'.2.2)) = .ok (bs, cr', t') := h
    simp only [ex_bind_ok_iff] at h'
    obtain ⟨⟨enc, cr₁, t₁⟩, hp, ⟨bs', cr₂, t₂⟩, hps, h3⟩ := h'
    simp only [Except.ok.injEq, Prod.mk.injEq] at h3
    obtain ⟨rfl, rfl, rfl⟩ := h3
    have hv := hpv1 g x c bnd cr t enc cr₁ t₁ hx hp
    have hs : segStep v (hOf g) (stOf g x c) bnd (enc (posTag (hOf g) t₁)) cr t = .ok (cr₁, t₁) :=
      (segStep_ok_iff (hOf g) (stOf g x c) bnd v _ cr t cr₁ t₁).mpr ⟨_, hv, rfl⟩
    show (segStep v (hOf g) (stOf g x c) bnd (enc (posTag (hOf g) t₁)) cr t >>= fun r =>
      runSegs (hOf g) (stOf g x c) bnd vs bs' r.1 r.2) = .ok (cr₂, t₂)
    rw [hs]
    exact runSegs_of_proveSegs adm hOf stOf g x c bnd hx ps vs hpv2 cr₁ t₁ bs' cr₂ t₂ hps

/-- The honest run has one segment per part. -/
theorem proveSegs_length {X Coins : Type} (H : HIn → Dig) (s : St) (x : X) (c : Coins) (bnd : Dig) :
    ∀ (ps : List (SegP St X Coins)) (cr : Carry) (t : Tr) (bs : List (List UInt8)) (cr' : Carry) (t' : Tr),
      proveSegs H s x c bnd ps cr t = .ok (bs, cr', t') → bs.length = ps.length
  | [], cr, t, bs, cr', t', h => by
    have h' : Except.ok ([], cr, t) = (Except.ok (bs, cr', t') : Except Unit _) := h
    cases h'
    rfl
  | p :: ps, cr, t, bs, cr', t', h => by
    have h' : (p.run H s x c bnd (posTag H t) cr t >>= fun r =>
        proveSegs H s x c bnd ps r.2.1 r.2.2 >>= fun r' =>
          .ok (r.1 (posTag H r.2.2) :: r'.1, r'.2.1, r'.2.2)) = .ok (bs, cr', t') := h
    simp only [ex_bind_ok_iff] at h'
    obtain ⟨⟨enc, cr₁, t₁⟩, -, ⟨bs', cr₂, t₂⟩, hps, h3⟩ := h'
    simp only [Except.ok.injEq, Prod.mk.injEq] at h3
    obtain ⟨rfl, rfl, rfl⟩ := h3
    rw [List.length_cons, List.length_cons, proveSegs_length H s x c bnd ps cr₁ t₁ bs' cr₂ t₂ hps]

/-- **The honest run's parts** (the provers of the run's parts, in the verifier's order), the registered header, and
the ONE refusal output (D65(2)). -/
structure RunP (Hdr X Coins : Type) where
  hdr : Hdr
  inC : SegP (ClsStmt Hdr) X Coins
  blk : ℕ → SegP (ClsStmt Hdr) X Coins
  outC : SegP (ClsStmt Hdr) X Coins
  refused : ClsStmt Hdr

/-- The provers' parts in the verifier's order. -/
def RunP.parts {X Coins : Type} (P : RunP Hdr X Coins) (L : ℕ) : List (SegP (ClsStmt Hdr) X Coins) :=
  P.inC :: ((List.range L).map P.blk ++ [P.outC])

theorem RunP.parts_length {X Coins : Type} (P : RunP Hdr X Coins) (L : ℕ) : (P.parts L).length = L + 2 := by
  simp [RunP.parts]

/-- **The honest statement**: the registered header, the input endpoint's root, the verdict. -/
def honestStmt (hdr : Hdr) (root : Dig) (verdict : ℕ) : ClsStmt Hdr := ⟨hdr, root, verdict⟩

/-- The honest run's segments from the run header (the binding its state). -/
def honestSegs {X Coins : Type} (V : RunV Hdr) (P : RunP Hdr X Coins) (H : HIn → Dig) (root : Dig) (verdict : ℕ)
    (x : X) (c : Coins) : Except Unit (List (List UInt8) × Carry × Tr) :=
  proveSegs H (honestStmt P.hdr root verdict) x c (V.start H (honestStmt P.hdr root verdict)).state (P.parts V.L)
    carry0 (V.start H (honestStmt P.hdr root verdict))

open Classical in
/-- **`prove_classify_run_with`, as a specification.** The sealing pass (ruling H-1) refuses an inadmissible input
before any header exists; otherwise the statement is the registered header, the input endpoint's root and the verdict,
and the receipt the parts' honest segments on ONE transcript from the run header. Every refusal (the sealing pass, or a
part's challenge-dependent `discard attempt`) is the ONE constant output `(refused, [])` (D65(2)). -/
noncomputable def runProve {X Coins : Type} (V : RunV Hdr) (P : RunP Hdr X Coins) (adm : X → Prop) (H : HIn → Dig)
    (root : Dig) (verdict : ℕ) (x : X) (c : Coins) : ClsStmt Hdr × ClsReceipt :=
  if adm x then
    match honestSegs V P H root verdict x c with
    | .ok r => (honestStmt P.hdr root verdict, r.1)
    | .error _ => (P.refused, [])
  else (P.refused, [])

/-! ## The input endpoint commitment, honestly built -/

/-- The honest tree's leaves of a plane commitment: each column's salted leaf (`MerkleEnc.leafDigest` of the code's
encodings), `0` beyond the `N` columns. -/
noncomputable def planeLeaves {V' St' Salt : Type} (C : PlaneCommit V' St' Salt) (L : ℕ) (h64 : 64 ≤ L)
    (hr : 8 * C.R ≤ L) (G : QB L → Dig) (v : V') (r : Salt) : ℕ → Dig :=
  fun i => if hi : i < C.N then (merkleEncB C.tag L C.R h64 hr).leafDigest G (C.column v r ⟨i, hi⟩) (C.salt r ⟨i, hi⟩)
    else zeroDig

/-- **The honest root** of a plane commitment: `MerkleTree::build` over the salted leaves. -/
noncomputable def honestRoot {V' St' Salt : Type} (C : PlaneCommit V' St' Salt) (L : ℕ) (h64 : 64 ≤ L)
    (hr : 8 * C.R ≤ L) (G : QB L → Dig) (v : V') (r : Salt) : Dig :=
  Complete.treeRoot (merkleEncB C.tag L C.R h64 hr) G C.depth (planeLeaves C L h64 hr G v r)

/-- **The honest opening of a plane commitment opens** (L10's `PlaneCommit.Opens`): when the statement's root is the
honest tree's root and every path is the honest path (`CompleteSub.lean`'s `opens_honest`). -/
theorem planeCommit_opens_honest {V' St' Salt : Type} (C : PlaneCommit V' St' Salt) (L : ℕ) (h64 : 64 ≤ L)
    (hr : 8 * C.R ≤ L) (G : QB L → Dig) (s : St') (v : V') (r : Salt) (hok : C.ok v) (hN : C.N ≤ 2 ^ C.depth)
    (hroot : C.root s = honestRoot C L h64 hr G v r)
    (hpath : ∀ j : Fin C.N, C.path r j
      = Complete.treePath (merkleEncB C.tag L C.R h64 hr) G C.depth (planeLeaves C L h64 hr G v r) j) :
    C.Opens L h64 hr G s v r := by
  refine ⟨hok, fun j => ?_⟩
  rw [hroot, hpath j]
  refine Complete.opens_honest (merkleEncB C.tag L C.R h64 hr) G C.depth (planeLeaves C L h64 hr G v r) j.val
    (lt_of_lt_of_le j.isLt hN) _ _ ?_
  simp [planeLeaves, j.isLt]

/-- **The owner's opening data, honestly built**: the masks, pads and salts from the prover's coins (`base`), then the
paths, which the opening data carries but which do not change the columns or the salts (`withPaths`). -/
structure HonestIn {V' St' Salt : Type} (Coins : Type) (C : PlaneCommit V' St' Salt) where
  base : Coins → Salt
  withPaths : Salt → (Fin C.N → List Dig) → Salt
  column_wp : ∀ v r ps j, C.column v (withPaths r ps) j = C.column v r j
  salt_wp : ∀ r ps j, C.salt (withPaths r ps) j = C.salt r j
  path_wp : ∀ r ps j, C.path (withPaths r ps) j = ps j

/-- **The honest input commitment opens to the input** (the `∃ r, opensIn …` part of `Complete`): with the statement's
root the honest root of `v` under the coins' opening data, the opening data with the honest paths opens. -/
theorem honestIn_opens {V' St' Salt Coins : Type} (C : PlaneCommit V' St' Salt) (hon : HonestIn Coins C)
    (L : ℕ) (h64 : 64 ≤ L) (hr : 8 * C.R ≤ L) (G : QB L → Dig) (s : St') (v : V') (c : Coins) (hok : C.ok v)
    (hN : C.N ≤ 2 ^ C.depth) (hroot : C.root s = honestRoot C L h64 hr G v (hon.base c)) :
    ∃ r, C.Opens L h64 hr G s v r := by
  have hleaves : planeLeaves C L h64 hr G v (hon.withPaths (hon.base c)
      (fun j => Complete.treePath (merkleEncB C.tag L C.R h64 hr) G C.depth (planeLeaves C L h64 hr G v (hon.base c)) j))
      = planeLeaves C L h64 hr G v (hon.base c) := by
    funext i
    unfold planeLeaves
    split_ifs with hi
    · rw [hon.column_wp, hon.salt_wp]
    · rfl
  refine ⟨hon.withPaths (hon.base c) (fun j => Complete.treePath (merkleEncB C.tag L C.R h64 hr) G C.depth
    (planeLeaves C L h64 hr G v (hon.base c)) j), planeCommit_opens_honest C L h64 hr G s v _ hok hN ?_ ?_⟩
  · rw [hroot]
    unfold honestRoot
    rw [hleaves]
  · intro j
    rw [hon.path_wp, hleaves]

/-! ## The declared leakage and the `Protocol` instance -/

/-- **The declared leakage** (Statements.lean's `Leak`): the shapes (`T`, `d`, `L`, the profile's constants, the same
for every input) and whether the input is SERVED. D65(2)'s constant refusal makes the refusal output a function of the
served bit alone (`prove_unserved`), as `refusal_output_must_be_leaked` requires. -/
structure ClsLeak where
  T : ℕ
  d : ℕ
  L : ℕ
  served : Bool

open Classical in
/-- The classify run's leakage of an input. -/
noncomputable def clsLeak (S : Block.BlockShape) (R : ClassifyRunPublic S) (x : S.Tok → ℕ) : ClsLeak :=
  ⟨S.T, S.d, R.Ps.length, decide ((classifyModel S R).admissible x)⟩

variable {S : Block.BlockShape}

/-- **An admissible item's ids are canonical words** (`< p`): the integer model reads ids below `V ≤ 2^17`. -/
theorem admissible_canon (R : ClassifyRunPublic S) (hR : R.Valid) (x : S.Tok → ℕ)
    (hx : (classifyModel S R).admissible x) : ∀ t, x t < gP := by
  obtain ⟨b, hb⟩ := hx
  unfold classifySpec at hb
  obtain ⟨y, hy, -⟩ := Circuit.obind_eq_some.mp hb
  exact fun t => lt_gP_of_V hR.inp ((inSpec_some hy).1 t)

variable {Salt Coins : Type}

/-- **THE `Protocol` INSTANCE of the classify run** (ASSEMBLY §4.0), on the random oracle over the hash inputs of at most
`Lq` bytes (`QB Lq`, L5's framing) with 32-byte digests:
* `Stmt` = `ClsStmt Hdr`, `Receipt` = the `L + 2` segments' bytes, `Salt` = the input endpoint's opening data;
* `leak` = `clsLeak` (shapes, `T`, `L`, the served bit); `ypub` = the statement's verdict;
* `opensIn` = lane L10's plane-commitment opening of the statement's input root (`BindingW16.lean`'s `opensIn`);
  `opensOut` = L10's `opensUnit` (no output endpoint: the classifier's hidden output is `Unit`);
* `prove` = `runProve`: the honest statement's root is the honest Merkle root of the input plane under the coins'
  opening data, its verdict the integer model's (`classifySpec`), its segments the parts' honest provers';
* `verify` = `classifyVerifyE` under the oracle (`liftH`): `verify_classify_run_with`. -/
noncomputable def classifyProtocol (S : Block.BlockShape) (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr)
    (P : RunP Hdr (S.Tok → ℕ) Coins) (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq)
    (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt) : Protocol (QB Lq) Dig Coins (classifyModel S R) where
  Stmt := ClsStmt Hdr
  Receipt := ClsReceipt
  Salt := Salt
  Leak := ClsLeak
  leak := clsLeak S R
  ypub s := s.verdict
  opensIn G s x r := ZK60.Exec.opensIn (M := classifyModel S R) Cin h64 hr G s x r
  opensOut G s y r := ZK60.Exec.opensUnit G s y r
  prove G _ x c := runProve V P (classifyModel S R).admissible (liftH G) (honestRoot Cin Lq h64 hr G x (base c))
    ((classifySpec R x).getD 0) x c
  verify G _ s rc := okB (classifyVerifyE V (liftH G) s rc)

section Instance

variable (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
  (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)

/-- **The instance's verdict is `verify_classify_run_with`'s.** -/
theorem verify_true_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (rc : ClsReceipt) :
    (classifyProtocol S R Lq V P Cin h64 hr base).verify G () s rc = true
      ↔ classifyVerifyE V (liftH G) s rc = .ok () := by
  show okB (classifyVerifyE V (liftH G) s rc) = true ↔ _
  rw [okB_eq_true]
  exact ⟨fun ⟨u, h⟩ => by cases u; exact h, fun h => ⟨(), h⟩⟩

/-- **D65(2): an unserved input's output is the ONE constant refusal**, whatever the oracle and the coins. -/
theorem prove_unserved (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) (hx : ¬ (classifyModel S R).admissible x) :
    (classifyProtocol S R Lq V P Cin h64 hr base).prove G () x c = (P.refused, []) := by
  show runProve V P (classifyModel S R).admissible (liftH G) _ _ x c = _
  unfold runProve
  rw [ite_eq_right hx]

/-- The leakage carries the served bit. -/
theorem leak_served (x : S.Tok → ℕ) :
    ((classifyProtocol S R Lq V P Cin h64 hr base).leak x).served = true ↔ (classifyModel S R).admissible x := by
  show (clsLeak S R x).served = true ↔ _
  classical
  simp [clsLeak]

/-- `opensIn` is L10's opening, by definition (the premise `binding_classifier_target` asks for). -/
theorem opensIn_iff (G : QB Lq → Dig) (s : ClsStmt Hdr) (x : S.Tok → ℕ) (r : Salt) :
    (classifyProtocol S R Lq V P Cin h64 hr base).opensIn G s x r
      ↔ opensIn (M := classifyModel S R) Cin h64 hr G s x r :=
  Iff.rfl

/-- **The instance's honest statement** on the oracle `G`: the registered header, the honest root of the input plane
under the coins' opening data, the integer model's verdict. -/
noncomputable def clsStmtOf (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) : ClsStmt Hdr :=
  honestStmt P.hdr (honestRoot Cin Lq h64 hr G x (base c)) ((classifySpec R x).getD 0)

/-- **A served input's output** is the honest statement and the parts' honest segments, whenever no part refuses. -/
theorem prove_served (G : QB Lq → Dig) (x : S.Tok → ℕ) (c : Coins) (hx : (classifyModel S R).admissible x)
    (r : List (List UInt8) × Carry × Tr)
    (hr' : honestSegs V P (liftH G) (honestRoot Cin Lq h64 hr G x (base c)) ((classifySpec R x).getD 0) x c = .ok r) :
    (classifyProtocol S R Lq V P Cin h64 hr base).prove G () x c = (clsStmtOf R Lq P Cin h64 hr base G x c, r.1) := by
  show runProve V P (classifyModel S R).admissible (liftH G) _ _ x c = _
  unfold runProve
  rw [ite_eq_left hx, hr']
  rfl

end Instance

end ZK60.ProtocolClassify
