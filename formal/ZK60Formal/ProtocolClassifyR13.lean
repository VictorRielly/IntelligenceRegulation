/-
D63 lane L18 (2026-11-07), part 5: **the classify run at R13, the media app's real profile** — the generic
construction of `ProtocolClassify.lean` / `AssembleClassify.lean` instantiated with lane L17's R13 results (merged at
perf `0940de9a`) and lane L16's per-block knowledge form, rather than restating them.

* **The block profile** (`d12aBlockProf`): the run's block part, from L17's executable D12a segment decoder
  (`Block.decodeSegment`, the `HLPRUNS1` frame the classify run carries, `wire::decode_segment`) and L9's executable
  `verify_core` (`blockVerify`) at block `k`'s own `BlockParams` (at R13 each layer's stage shape, with L10/L17's
  opening fields, `r13Fields`). The same definition is W16R2's with W16R2's parameters (cheap: the frame is the
  profile-independent D12a segment).
  PROVED: `d12a_blockSeg_step_ok_iff` (the R13 block step unfolded: the decoder, the core, the boundary opening of
  the segment's `in_open`), `d12a_block_segment_canonical` (an accepted block segment is EXACTLY L17's `encSeg` of
  what it decoded: one receipt, one encoding, per block, `decodeSegment_spec`).
* **The input endpoint** (`r13TokenCommit_facts`): L17's `r13TokenCommit` (rate 1/4, `N = 2^16`, depth 16) with the
  statement's root meets `ClassifyOpen`'s field O6; **`classify_binding_r13`**: `Binding` at the target from L17's
  `binding_classifier_target_r13`.
* **The run's sumcheck slots at the Shieldstral run** (`shield_run_sumchecks_le`): 26 blocks and two stages, every
  part within `2^14` slot items (L17's `shield_len`: a Shieldstral R13 block's slot phase is its header plus 1,292),
  degrees `≤ 7`, `q ≤ 2^64`: a false claim in ANY slot of the run passes with probability at most `2^-61` (L17's
  `shield_block_fs_sound` is the same bound for ONE block).
* **The blocks' extraction premise from per-block bounds** (`blockOn_of_blockSat`, `blocksOk_of_blockSat`,
  `blocks_extract_union`): a block's `BlockSat` on the boundary planes (the form of L16's `block_knowledge`
  conclusion, with L17's `blockSat_of_slots_r13` as its `hRel` route at R13) gives `BlockOn` (`BlockSat` carries the
  `Word16` class of both planes), and per-block failure bounds give the blocks' part of O11 with their sum (L16's
  `run_blocks_union`). The sum of per-block floors misses `εsTarget`'s constant (L16-1, L18-2): the joint path-wise
  bound remains the target form.

Every premise is an explicit hypothesis; no `sorry`, axiom or `native_decide`.
-/
import ZK60Formal.AssembleClassify
import ZK60Formal.ExecBlockR13
import ZK60Formal.OpeningR13
import ZK60Formal.ExtractW16Block

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.TokenRun ZK60.Sound ZK60.StageX
open ZK60.Circuit (gP GF word16_iff)
open ZK60.Block (BlockShape BlockPublic BlockSat BlockWit i16)
open ZK60.Exec.Block (posTag blockVerify BlockParams)

/-! ## The D12a block profile -/

/-- **The block profile of a D12a classify run** (R13: the media app's; W16R2 the same with its own parameters):
the segment decoder is L17's `decodeSegment` at block `k`'s segment geometry (`st.block_geom(k)`), the core is L9's
executable `blockVerify` (`verify_core`) at block `k`'s `BlockParams` (`st.stage_shape(k)`: at R13 each layer's own
calibration), the boundary root is the segment's `b_root`, and the boundary opening checks the segment's `in_open`
against the previous boundary's root. The statement check, the paths' depth, the digests, the boundary geometry and
the boundary PCS (`boundary::check_opening`, `pcs::verify_zk_tagged` at the boundary's parameters) are the profile's. -/
def d12aBlockProf {St : Type} (Pk : ℕ → BlockParams) (sgeom : St → ℕ → ZK60.Exec.Block.SegGeom)
    (check : St → ℕ → Except String Unit) (paths : St → ZK60.Exec.Block.Segment → Except String Unit)
    (digest : St → ℕ → Dig) (bRows bLogN : ℕ → ℕ) (bndCheck : St → ℕ → List ZK60.Exec.Block.ZClaim → Tr → Except String Unit)
    (bndOpen : (HIn → Dig) → St → ℕ → Dig → List ZK60.Exec.Block.ZClaim → ZK60.Exec.Block.OpeningZk → Tr → Except String Tr) :
    BlockProfV St where
  Seg := ZK60.Exec.Block.Segment
  check := check
  decode s k bytes bnd start := ZK60.Exec.Block.decodeSegment (sgeom s k) bnd start bytes
  paths := paths
  bRoot sg := sg.bRoot
  digest := digest
  bRows := bRows
  bLogN := bLogN
  core H _ k sg t := blockVerify H (Pk k) sg.core t
  bndCheck := bndCheck
  bndOpen H s k root cl sg t := bndOpen H s k root cl sg.inOpen t

section D12a

variable {St : Type} (Pk : ℕ → BlockParams) (sgeom : St → ℕ → ZK60.Exec.Block.SegGeom)
  (check : St → ℕ → Except String Unit) (paths : St → ZK60.Exec.Block.Segment → Except String Unit)
  (digest : St → ℕ → Dig) (bRows bLogN : ℕ → ℕ) (bndCheck : St → ℕ → List ZK60.Exec.Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → St → ℕ → Dig → List ZK60.Exec.Block.ZClaim → ZK60.Exec.Block.OpeningZk → Tr → Except String Tr)

/-- **The R13 block step**, in the code's order: the statement check, L17's `decodeSegment` at the transcript's
position tag, the paths, the segment's `b_root`, the framing, L9's `blockVerify` at block `k`'s parameters, the
boundary audit, the boundary opening of the segment's `in_open` against the previous boundary's root, the end tag. -/
theorem d12a_blockSeg_step_ok_iff (k : ℕ) (H : HIn → Dig) (s : St) (bnd : Dig) (bytes : List UInt8) (cr : Carry)
    (t : Tr) (cr' : Carry) (t' : Tr) :
    segStep (blockSeg (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) k) H s bnd bytes cr t
        = .ok (cr', t') ↔
      check s k = .ok () ∧ ∃ (sg : ZK60.Exec.Block.Segment) (e root : Dig) (ic oc : List ZK60.Exec.Block.ZClaim) (t₂ : Tr),
        ZK60.Exec.Block.decodeSegment (sgeom s k) bnd (posTag H t) bytes = .ok (sg, e) ∧ paths s sg = .ok ()
        ∧ sg.bRoot = some root
        ∧ blockVerify H (Pk k) sg.core
            (blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k root t)
          = .ok ((ic, oc), t₂)
        ∧ bndCheck s k (cr.pending ++ ic) t₂ = .ok ()
        ∧ bndOpen H s k cr.root (cr.pending ++ ic) sg.inOpen t₂ = .ok t'
        ∧ posTag H t' = e ∧ cr' = ⟨oc, root⟩ :=
  blockSeg_step_ok_iff H s bnd bytes cr t cr' t' _ k

/-- **One receipt, one encoding, per block segment**: an accepted block step's bytes are EXACTLY L17's `encSeg` of
the decoded segment and end tag, under the verifier's own binding, run length, index and start tag. -/
theorem d12a_block_segment_canonical
    (hgt : ∀ s k, (sgeom s k).g.slots.length = (sgeom s k).g.terms.length) (k : ℕ) (H : HIn → Dig) (s : St)
    (bnd : Dig) (bytes : List UInt8) (cr : Carry) (t : Tr) (cr' : Carry) (t' : Tr)
    (h : segStep (blockSeg (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) k) H s bnd bytes
      cr t = .ok (cr', t')) :
    ∃ (sg : ZK60.Exec.Block.Segment) (e : Dig),
      bytes = ZK60.Exec.Block.encSeg bnd (sgeom s k).l (sgeom s k).k (posTag H t) sg e := by
  obtain ⟨-, sg, e, _, _, _, _, hd, -⟩ :=
    (d12a_blockSeg_step_ok_iff Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k H s bnd bytes cr t cr' t').mp h
  exact ⟨sg, e, (ZK60.Exec.Block.decodeSegment_spec (hgt s k) hd).1⟩

end D12a

/-! ## The R13 input endpoint and `Binding` -/

section Endpoint

variable {Hdr : Type} {S : BlockShape}

/-- **The R13 input endpoint meets O6**: L17's `r13TokenCommit` with the statement's `inRoot` accepts exactly the
canonical words, has `N = 2^16 ≤ 2^16` columns, reads its root off the statement, and is 16 deep. -/
theorem r13TokenCommit_facts {Salt : Type} (R dR : ℕ) {pos : S.Tok → Fin dR × Fin (2 ^ 14)}
    (hpos : Function.Injective pos) (place : Fin dR → Fin R) (msg : (S.Tok → ℕ) → Salt → Fin R → Fin (2 ^ 14) → GF)
    (msg_place : ∀ v r k, msg v r (place k) = posPlane pos v k) (pad : Salt → Fin R → Fin 256 → GF)
    (salt : Salt → Fin (2 ^ 16) → Dig) (path : Salt → Fin (2 ^ 16) → List Dig) (tag : MTag) :
    (∀ x, (∀ t, x t < gP) →
        (R13.r13TokenCommit (St := ClsStmt Hdr) R dR hpos place msg msg_place pad salt path ClsStmt.inRoot tag).ok x)
      ∧ (R13.r13TokenCommit (St := ClsStmt Hdr) R dR hpos place msg msg_place pad salt path ClsStmt.inRoot tag).N
        ≤ 2 ^ (R13.r13TokenCommit (St := ClsStmt Hdr) R dR hpos place msg msg_place pad salt path ClsStmt.inRoot
          tag).depth
      ∧ (∀ s, (R13.r13TokenCommit (St := ClsStmt Hdr) R dR hpos place msg msg_place pad salt path ClsStmt.inRoot
          tag).root s = s.inRoot)
      ∧ (R13.r13TokenCommit (St := ClsStmt Hdr) R dR hpos place msg msg_place pad salt path ClsStmt.inRoot
          tag).depth ≤ 64 :=
  ⟨fun _ hx => hx, le_refl _, fun _ => rfl, by show 16 ≤ 64; norm_num⟩

variable {Salt Coins : Type}

/-- **`Binding` at the target for the classify run at R13**, from L17's `binding_classifier_target_r13` (the input
endpoint a 16-deep R13 plane commitment; the classifier's hidden output `Unit`). -/
theorem classify_binding_r13 (R : ClassifyRunPublic S) (Lq : ℕ) (V : RunV Hdr) (P : RunP Hdr (S.Tok → ℕ) Coins)
    (Cin : PlaneCommit (S.Tok → ℕ) (ClsStmt Hdr) Salt) (h64 : 64 ≤ Lq) (hr : 8 * Cin.R ≤ Lq) (base : Coins → Salt)
    (hdi : Cin.depth = 16) :
    Binding (classifyModel S R) (classifyProtocol S R Lq V P Cin h64 hr base) εsTarget := by
  have : Subsingleton (classifyModel S R).HidOut := inferInstanceAs (Subsingleton Unit)
  exact R13.binding_classifier_target_r13 (classifyProtocol S R Lq V P Cin h64 hr base) Cin h64 hr
    (fun G s x r => opensIn_iff R Lq V P Cin h64 hr base G s x r) hdi

end Endpoint

/-! ## The Shieldstral R13 run's sumcheck slots under Fiat–Shamir -/

section Shield

variable {K : Type} [Field K] [Algebra GF K]

/-- **The media app's classify run, its sumcheck slots under Fiat–Shamir, numerically**: 26 R13 blocks and the two
stages, every part within `2^14` slot items (a Shieldstral R13 block's slot phase is its header plus 1,292 items, L17's
`shield_len`), every degree `≤ 7` (Shieldstral R13's are `≤ 5`, L17's `shield_slot_facts`; OUT-C's `≤ 5`), and a
prover of at most `2^64` queries: a false claimed sum in ANY slot of the run passes every slot's executable
`sumcheck::verify` with probability at most `2^-61`. -/
theorem shield_run_sumchecks_le [Fintype K] [DecidableEq K] (U : K) (hU : U ^ 2 = algebraMap GF K 7)
    (hK2 : Module.finrank GF K = 2) (key : Option Dig) (domain : List UInt8) (hs : decodeLink (startMsg domain) = none)
    (Lq : ℕ) (hL : (startMsg domain).length ≤ Lq) (hL64 : Lq < 2 ^ 64)
    (sin : List (Slot K)) (sblk : ℕ → List (Slot K)) (sout : List (Slot K)) (dmax : ℕ)
    (hsl : ∀ sl ∈ runSlots sin sblk 26 sout, 1 ≤ sl.d ∧ sl.d < gP ∧ sl.d ≤ dmax ∧ 56 + 16 * (sl.d + 1) ≤ Lq)
    (hd7 : dmax ≤ 7) (hin : slotsLen sin ≤ 2 ^ 14) (hblk : ∀ k, slotsLen (sblk k) ≤ 2 ^ 14)
    (hout : slotsLen sout ≤ 2 ^ 14)
    (q : ℕ) (hq : q ≤ 2 ^ 64) (A : OC (QB Lq) Dig (List (List Op × List (List Fp2)))) (hA : A.Bounded q) :
    prH (fun G : QB Lq → Dig => SlotsWin U key domain Lq (runSlots sin sblk 26 sout) G (A.run G))
      ≤ (2⁻¹ : ℝ≥0∞) ^ 61 := by
  have hlen := slotsLen_runSlots_le sin sblk 26 sout _ _ _ hin hblk hout
  refine classify_run_sumchecks_fs_sound_le U hU hK2 key domain hs Lq hL hL64 sin sblk 26 sout dmax hsl q A hA hd7 ?_
  have h2 : 2 ^ 14 + 26 * 2 ^ 14 + 2 ^ 14 + 1 ≤ 2 ^ 20 := by norm_num
  calc q + slotsLen (runSlots sin sblk 26 sout) + 1 ≤ 2 ^ 64 + (2 ^ 14 + 26 * 2 ^ 14 + 2 ^ 14 + 1) := by omega
    _ ≤ 2 ^ 64 + 2 ^ 20 := Nat.add_le_add_left h2 _

end Shield

/-! ## The blocks' part of the extraction premise from per-block bounds -/

section Blocks

variable {S : BlockShape}

/-- **`BlockSat` on two planes gives `BlockOn`**: the block's constraint system carries the `Word16` class of its
input plane (`inX`) and of its output plane (`res2`), so both planes are images of int16 planes. (L16's
`block_knowledge` concludes `BlockSat` on the extracted planes; at R13 through L17's `blockSat_of_slots_r13`.) -/
theorem blockOn_of_blockSat (P : BlockPublic S) (X X2 : S.Pos → GF) (w : BlockWit S) (h : BlockSat P X X2 w) :
    BlockOn P X X2 := by
  have hx : ∀ p, ∃ q : ℤ, -2 ^ 15 ≤ q ∧ q ≤ 2 ^ 15 - 1 ∧ X p = (q : GF) := fun p => (word16_iff _).mp (h.inX p)
  have hy : ∀ p, ∃ q : ℤ, -2 ^ 15 ≤ q ∧ q ≤ 2 ^ 15 - 1 ∧ X2 p = (q : GF) := fun p => (word16_iff _).mp (h.res2 p).2
  choose x hx1 hx2 hx3 using hx
  choose y hy1 hy2 hy3 using hy
  have eX : X = fun p => (x p : GF) := funext hx3
  have eY : X2 = fun p => (y p : GF) := funext hy3
  refine ⟨x, y, fun p => ⟨hx1 p, hx2 p⟩, fun p => ⟨hy1 p, hy2 p⟩, hx3, hy3, w, ?_⟩
  subst eX
  subst eY
  exact h

/-- Every block's `BlockSat` on the boundary planes is the blocks' part of the run's extraction. -/
theorem blocksOk_of_blockSat (R : ClassifyRunPublic S) {Salt : Type} (e : RunExt S Salt)
    (h : ∀ (k : ℕ) (hk : k < R.Ps.length), ∃ w, BlockSat R.Ps[k] (e.planes k) (e.planes (k + 1)) w) :
    BlocksOk R e := by
  intro k hk
  obtain ⟨w, hw⟩ := h k hk
  exact blockOn_of_blockSat _ _ _ w hw

/-- **The blocks' part of O11 from per-block bounds** (L16's `run_blocks_union`): if, for one extractor, each block's
`BlockSat` on the extracted boundary planes fails on an accepted receipt with probability at most `ε q k` (the form
L16's `block_knowledge` delivers per block, each at its own shape), the blocks' part of `RunExtract` holds with the
sum. (The sum of 26 per-block constant floors misses `εsTarget`'s `2^-100`, L16-1 / L18-2; the joint path-wise bound
is the target form.) -/
theorem blocks_extract_union {Lq : ℕ} {Coins : Type} (R : ClassifyRunPublic S)
    (P : Protocol (QB Lq) Dig Coins (classifyModel S R)) (E : List (QB Lq × Dig) → P.Stmt → P.Receipt → RunExt S P.Salt)
    (ε : ℕ → ℕ → ℝ≥0∞) (q : ℕ) (A : OC (QB Lq) Dig (P.Stmt × P.Receipt))
    (h : ∀ (k : ℕ) (hk : k < R.Ps.length), prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
      ∧ ¬ ∃ w, BlockSat R.Ps[k] ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
          ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) w) ≤ ε q k) :
    prH (fun G => P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ¬ BlocksOk R (E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2))
      ≤ ∑ k ∈ Finset.range R.Ps.length, ε q k := by
  refine le_trans (prH_mono (B := fun G => ∃ k, k < R.Ps.length ∧
      (P.verify G () (A.runLog G).1.1 (A.runLog G).1.2 = true
        ∧ ∃ hk : k < R.Ps.length, ¬ ∃ w, BlockSat (R.Ps[k]'hk)
          ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
          ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) w)) ?_)
    (ZK60.Exec.Block.run_blocks_union R.Ps.length _ (ε q) (fun k hk => le_trans (prH_mono ?_) (h k hk)))
  · intro G hG
    obtain ⟨hv, hns⟩ := hG
    have hns' : ¬ ∀ (k : ℕ) (hk : k < R.Ps.length), ∃ w, BlockSat R.Ps[k]
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes k)
        ((E (A.runLog G).2 (A.runLog G).1.1 (A.runLog G).1.2).planes (k + 1)) w :=
      fun hall => hns (blocksOk_of_blockSat R _ hall)
    simp only [not_forall] at hns'
    obtain ⟨k, hk, hk'⟩ := hns'
    exact ⟨k, hk, hv, hk, hk'⟩
  · intro G ⟨hv, _, hns⟩
    exact ⟨hv, hns⟩

end Blocks

end ZK60.ProtocolClassify
