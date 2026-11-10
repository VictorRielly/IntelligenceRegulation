/-
D63 lane L34 (2026-11-09), part 4: **the parts' schedule contracts** (`RunTrVerify.lean`'s `RtSeg.Holds`): the common
tail of every part (`M`, then three regular openings), the reading of a segment without the oracle, the contract of a
D12a BLOCK with its boundary opening, and the run's schedule assembled from the three kinds of parts.

* `RtPcs`: a regular opening's verifier that accepts only when L10's `PcsOk` holds at its parameters (L28's premise
  `hPp`, for any opening: a block's `A` and `H`, the boundary opening, the stages' openings); **`RtPcs.tr`**: an
  accepted opening moves the transcript by its steps `pcsStps (claims + rows) m`, and its vectors fit;
* `rt_mask_tr`: the same for `M` (`maskField`); **`rt_tail`**: `M`, `A`, `H` and the closing opening accepted in
  sequence move the transcript by the part's tail of steps, every operation within `Lq` bytes;
* `rtBnd`, `rtStart`, `rt_hdr_read`: the binding and the start tag a segment's own header carries (bytes 8–40 and
  56–88); `rtSegOf`, **`rtSegOf_decode`**: so a D12a segment is read off its bytes alone, and the reading is the
  verifier's decoding whenever the verifier's `decode_segment` accepts (at the transcript's position tag);
  `rt_decodeSegment_in`: the closed commitment's opening has the geometry's group count;
* `rt_blockVerify_io`: L22's `blockVerify_ok` with the IO claims it returns;
* `rtBlockFrame`, `rt_blockFrame`: the run's framing of block `k` as five absorbs; `rtBlockData`, `rtBlockRd`,
  `rtBlockPart`, `rtBlockSeg`: a block's operations, reading, counts and scheduled part;
* `RtBlk`: what the schedule needs of block `k`'s verifier, in L28's form (the fields `maskField` and `PcsOk`, the
  slots' geometry, the claims' counts `hcnt`);
* **`rtBlock_holds`**: THE BLOCK'S CONTRACT. If block `k`'s framed step accepts from a carry with `pend` pending claims,
  the transcript moved by the frame, the roots, the slots, `M`, `A`, `H` and the boundary opening's steps, at the
  profile's counts, and the carry it hands on holds the block's outgoing claims;
* **`rtRunOf`**: the run's schedule (`RtRun`) from stage IN-C's contract, the blocks' contracts and stage OUT-C's.

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunTrVerify

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound

/-! ## A regular opening's verifier, and the part's tail -/

/-- **A regular opening's verifier with its parameters** (indexed by `ι`: the statement, for the boundary opening): it
accepts only when L10's `PcsOk` holds, at parameters with `Q` queries and pads, codeword length `N` (a power of two),
`m` index squeezes, and vectors of at most `2^15` words. -/
structure RtPcs {ι : Type}
    (V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr) where
  tag : MTag
  prm : PcsPrm
  pt : ℕ → Fp
  ev : Fp → List (List Fp2) → List Fp2
  rows : ℕ
  lc : ℕ
  Q : ℕ
  N : ℕ
  m : ℕ
  hok : ∀ (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr),
    V i H root cl o t = .ok t' → PcsOk H tag prm pt ev root rows lc (cl.map toZClaim) (toOZ o) t t'
  hqp : prm.qPad = Q
  hnQ : prm.nQ = Q
  hnn : prm.nn = N
  hpow : isPow2 N = true
  hQ0 : 0 < Q
  hm : (Q + 3) / 4 = m
  hv15 : 2 ^ lc + Q ≤ 2 ^ 15

/-- **An accepted opening moves the transcript by its steps**: the batching run of `claims + rows` squeezes, the group
vectors, the proximity vector, the `m` index squeezes; its vectors have at most `2^15` words. -/
theorem RtPcs.tr {ι : Type} {V : ι → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr}
    (p : RtPcs V) (i : ι) (H : HIn → Dig) (root : Dig) (cl : List Block.ZClaim) (o : Block.OpeningZk) (t t' : Tr)
    (h : V i H root cl o t = .ok t') (nC : ℕ) (hnC : cl.length = nC) :
    t' = runOps H t (stpsOps (pcsStps (nC + p.rows) p.m o))
      ∧ (∀ v ∈ o.groupVecs, v.length ≤ 2 ^ 15) ∧ o.proxVec.length ≤ 2 ^ 15 := by
  have hok := p.hok i H root cl o t t' h
  have hn : nMem (groupZclaims (cl.map toZClaim) p.rows p.lc) = nC := by
    unfold nMem
    rw [groupZclaims_count, List.length_map, hnC]
  obtain ⟨-, -, hgv, hpv, htr, -, -⟩ := pcsOk_named H p.tag p.prm p.pt p.ev root p.rows p.lc _ _ t t' hok p.Q p.N p.m
    p.hqp p.hnQ p.hnn p.hpow p.hQ0 p.hm
  rw [pcs_tr_after H p.rows nC p.m _ hn] at htr
  have h15 := p.hv15
  refine ⟨htr, fun v hv => ?_, ?_⟩
  · obtain ⟨g, hg, rfl⟩ := List.getElem_of_mem hv
    have e : (o.groupVecs.getD g []).length = 2 ^ p.lc + p.Q := hgv g hg
    rw [getD_eq_get _ _ _ hg] at e
    rw [e]
    exact h15
  · have e : o.proxVec.length = 2 ^ p.lc + p.Q := hpv
    rw [e]
    exact h15

/-- **An accepted `M` check moves the transcript by `M`'s steps** (L10's field `maskField`), and its two vectors have
at most `2^15` words. -/
theorem rt_mask_tr (tag : MTag) (S : ℕ) (H : HIn → Dig) (root : Dig) (fs : List Block.MaskFunctional)
    (mo : Block.MaskOpening) (t t' : Tr) (h : maskField tag S H root fs mo t = .ok t') :
    t' = runOps H t (stpsOps (mStps S mo)) ∧ mo.q.length ≤ 2 ^ 15 ∧ mo.prox.length ≤ 2 ^ 15 := by
  obtain ⟨th, rs, idx, hmt⟩ := maskField_transcript tag S H root fs mo t t' h
  have hrun := (maskTranscript_runOps H S mo t th rs idx t' hmt).2.2.2.1
  have hok : MaskOk H tag (rootFp 9) (rootFp 12) root S (fs.map toMF) (toMO mo) t t' := by
    have h1 := h
    rw [maskField, mapErr_ok, w16r2MCheck_ok_iff] at h1
    exact h1
  refine ⟨hrun, ?_, ?_⟩
  · have e : mo.q.length = 2 * mMsg := hok.1
    rw [e]
    norm_num [mMsg]
  · have e : mo.prox.length = 2 * mMsg := hok.2.2.1
    rw [e]
    norm_num [mMsg]

/-- **A part's tail**: `M`, then the openings of `A`, of `H` and of the commitment the part closes, each accepted on
the transcript the previous left, with `nA`, `nH`, `nX` claims. The transcript after them is `runOps` of the tail's
steps at those widths, and every operation of the tail fits `Lq ≥ 2^20` bytes. -/
theorem rt_tail (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (H : HIn → Dig) (tag : MTag) (S : ℕ) (mroot : Dig)
    (fs : List Block.MaskFunctional) (mo : Block.MaskOpening) {ιA ιH ιX : Type}
    {VA : ιA → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr}
    {VH : ιH → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr}
    {VX : ιX → (HIn → Dig) → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr}
    (pA : RtPcs VA) (pH : RtPcs VH) (pX : RtPcs VX) (iA : ιA) (iH : ιH) (iX : ιX) (rA rH rX : Dig)
    (cA cH cX : List Block.ZClaim) (aO hO xO : Block.OpeningZk) (nA nH nX : ℕ) (hcA : cA.length = nA)
    (hcH : cH.length = nH) (hcX : cX.length = nX) (tM tA tH tX t' : Tr)
    (hm : maskField tag S H mroot fs mo tM = .ok tA) (ha : VA iA H rA cA aO tA = .ok tH)
    (hh : VH iH H rH cH hO tH = .ok tX) (hx : VX iX H rX cX xO tX = .ok t') :
    t' = runOps H tM (stpsOps (mStps S mo ++ (pcsStps (nA + pA.rows) pA.m aO
        ++ (pcsStps (nH + pH.rows) pH.m hO ++ pcsStps (nX + pX.rows) pX.m xO))))
      ∧ ∀ op ∈ stpsOps (mStps S mo ++ (pcsStps (nA + pA.rows) pA.m aO
        ++ (pcsStps (nH + pH.rows) pH.m hO ++ pcsStps (nX + pX.rows) pX.m xO))), op.len ≤ Lq := by
  obtain ⟨e1, hq, hp⟩ := rt_mask_tr tag S H mroot fs mo tM tA hm
  obtain ⟨e2, hvA, hpA⟩ := pA.tr iA H rA cA aO tA tH ha nA hcA
  obtain ⟨e3, hvH, hpH⟩ := pH.tr iH H rH cH hO tH tX hh nH hcH
  obtain ⟨e4, hvX, hpX⟩ := pX.tr iX H rX cX xO tX t' hx nX hcX
  refine ⟨?_, fun op hop => ?_⟩
  · rw [stpsOps_append, stpsOps_append, stpsOps_append, runOps_append, runOps_append, runOps_append, ← e1, ← e2, ← e3]
    exact e4
  · rw [stpsOps_append, stpsOps_append, stpsOps_append] at hop
    rcases List.mem_append.mp hop with h1 | h1
    · exact mStps_fit S mo hq hp Lq hL20 op h1
    · rcases List.mem_append.mp h1 with h2 | h2
      · exact pcsStps_fit _ _ aO hvA hpA Lq hL20 op h2
      · rcases List.mem_append.mp h2 with h3 | h3
        · exact pcsStps_fit _ _ hO hvH hpH Lq hL20 op h3
        · exact pcsStps_fit _ _ xO hvX hpX Lq hL20 op h3

/-! ## Reading a segment without the oracle -/

/-- The binding a segment's header carries (bytes 8–40). -/
def rtBnd (bytes : List UInt8) : Dig := (digOf? ((bytes.drop 8).take 32)).getD zeroDig

/-- The start tag a segment's header carries (bytes 56–88). -/
def rtStart (bytes : List UInt8) : Dig :=
  (digOf? (((((bytes.drop 8).drop 32).drop 8).drop 8).take 32)).getD zeroDig

/-- On a header `magic ‖ binding ‖ u64 ‖ u64 ‖ start ‖ …` the two readers return the binding and the start tag. -/
theorem rt_hdr_read (mg a b rest : List UInt8) (bnd st : Dig) (hmg : mg.length = 8) (ha : a.length = 8)
    (hb : b.length = 8) :
    rtBnd (mg ++ (bnd.toList ++ (a ++ (b ++ (st.toList ++ rest))))) = bnd
      ∧ rtStart (mg ++ (bnd.toList ++ (a ++ (b ++ (st.toList ++ rest))))) = st := by
  have h32b : bnd.toList.length = 32 := bnd.2
  have h32s : st.toList.length = 32 := st.2
  constructor
  · unfold rtBnd
    rw [List.drop_left' hmg, List.take_left' h32b]
    exact congrArg (fun o : Option Dig => o.getD zeroDig) (digOf?_toList bnd)
  · unfold rtStart
    rw [List.drop_left' hmg, List.drop_left' h32b, List.drop_left' ha, List.drop_left' hb, List.take_left' h32s]
    exact congrArg (fun o : Option Dig => o.getD zeroDig) (digOf?_toList st)

/-- **A D12a segment read off its bytes alone**: decoded against the binding and start tag its own header carries. -/
def rtSegOf (g : Block.SegGeom) (bytes : List UInt8) : Option Block.Segment :=
  match Block.decodeSegment g (rtBnd bytes) (rtStart bytes) bytes with
  | .ok r => some r.1
  | .error _ => none

/-- **The reading is the verifier's decoding**: whenever `decode_segment` accepts the bytes (against the verifier's
binding and the transcript's position tag), the segment read off the bytes alone is the one it decoded. -/
theorem rtSegOf_decode {g : Block.SegGeom} (hgt : g.g.slots.length = g.g.terms.length) {bnd st : Dig}
    {bytes : List UInt8} {sg : Block.Segment} {e : Dig} (h : Block.decodeSegment g bnd st bytes = .ok (sg, e)) :
    rtSegOf g bytes = some sg := by
  have hb := (Block.decodeSegment_spec hgt h).1
  have hr : rtBnd bytes = bnd ∧ rtStart bytes = st := by
    rw [hb]
    exact rt_hdr_read Block.runMagic _ _ _ bnd st Block.runMagic_length (length_le64 _) (length_le64 _)
  simp only [rtSegOf, hr.1, hr.2, h]

/-- The opening of the commitment a decoded segment closes has the geometry's group count. -/
theorem rt_decodeSegment_in {s : Block.SegGeom} {bnd st : Dig} {bytes : List UInt8} {sg : Block.Segment} {e : Dig}
    (h : Block.decodeSegment s bnd st bytes = .ok (sg, e)) : sg.inOpen.groupVecs.length = s.incoming.1 := by
  unfold Block.decodeSegment at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i r rest hr
      split at h
      · cases h
      · cases h
        unfold Block.rdSegBody at hr
        obtain ⟨u, m1, e1, e2⟩ := Block.Rd.bnd_ok hr
        obtain ⟨br, m2, e3, e4⟩ := Block.Rd.bnd_ok e2
        obtain ⟨c, m3, e5, e6⟩ := Block.Rd.bnd_ok e4
        obtain ⟨io, m4, e7, e8⟩ := Block.Rd.bnd_ok e6
        obtain ⟨oo, m5, e9, e10⟩ := Block.Rd.bnd_ok e8
        obtain ⟨e', m6, e11, e12⟩ := Block.Rd.bnd_ok e10
        obtain ⟨hce, -⟩ := Block.Rd.ret_ok e12
        cases hce
        exact (Block.rdHiding_ok e7).2.2.1

/-! ## A block's verifier, with the IO claims it returns -/

/-- **An accepting block verifier, decomposed** (L22's `blockVerify_ok`), with the IO claims it returns: the incoming
and outgoing claims are the accumulator's. -/
theorem rt_blockVerify_io (H : HIn → Dig) (P : Block.BlockParams) (core : Block.Core) (t : Tr)
    (io : List Block.ZClaim × List Block.ZClaim) (t' : Tr) (h : Block.blockVerify H P core t = .ok (io, t')) :
    ∃ bga rs acc tM tA tH, Block.blockSlots H P core t = .ok (bga, rs, acc, tM)
      ∧ (acc.fs ++ acc.hostFs).length = P.nFunctionals
      ∧ P.maskVerify H core.maskRoot (acc.fs ++ acc.hostFs) core.maskOpen tM = .ok tA
      ∧ P.pcsVerify H .a core.aRoot acc.claims.a core.aOpen tA = .ok tH
      ∧ P.pcsVerify H .h core.hRoot (acc.claims.h ++ [P.logupSumClaim]) core.hOpen tH = .ok t'
      ∧ (acc.claims.inp, acc.claims.out) = io := by
  unfold Block.blockVerify at h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
  obtain ⟨⟨bga, rs, acc, tM⟩, hbs, h⟩ := Block.ex_bind_ok h
  simp only [] at h
  split at h
  · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
    cases he
  rename_i hnf
  split at h
  · rename_i tA hmv
    obtain ⟨tA', htA, h⟩ := Block.ex_bind_ok h
    cases htA
    obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
    split at h
    · rename_i tH hpa
      obtain ⟨tH', htH, h⟩ := Block.ex_bind_ok h
      cases htH
      obtain ⟨_, -, h⟩ := Block.ex_bind_ok h
      split at h
      · rename_i tF hph
        obtain ⟨tF', htF, h⟩ := Block.ex_bind_ok h
        cases htF
        simp only [pure, Except.pure, Except.ok.injEq, Prod.mk.injEq] at h
        obtain ⟨hio, rfl⟩ := h
        exact ⟨bga, rs, acc, tM, tA, tH, hbs, by simpa using hnf, hmv, hpa, hph, hio⟩
      · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
        cases he
    · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
      cases he
  · obtain ⟨_, he, -⟩ := Block.ex_bind_ok h
    cases he

/-! ## A block as a scheduled part -/

/-- **The run's framing of block `k`** as operations: `pb-run-stage` (`k + 1`), `pb-run-block` (the block's digest),
and `absorb_root("B")` of the boundary root it commits (the root, its rows, its row width). -/
def rtBlockFrame (k : ℕ) (dg root : Dig) (rows logN : ℕ) : List Op :=
  [.absorb labRunStage (le64 (UInt64.ofNat (k + 1))), .absorb labRunBlock dg.toList, .absorb labB root.toList,
    .absorb Block.labRows (le64 (UInt64.ofNat rows)), .absorb Block.labLogCols (le64 (UInt64.ofNat logN))]

/-- L18's `blockFrame` is `runOps` of the frame's operations. -/
theorem rt_blockFrame {St : Type} (B : BlockProfV St) (H : HIn → Dig) (s : St) (k : ℕ) (root : Dig) (t : Tr) :
    blockFrame B H s k root t = runOps H t (rtBlockFrame k (B.digest s k) root (B.bRows (k + 1)) (B.bLogN (k + 1))) :=
  rfl

theorem rtBlockFrame_fit (k : ℕ) (dg root : Dig) (rows logN Lq : ℕ) (hL : 2 ^ 20 ≤ Lq) :
    ∀ op ∈ rtBlockFrame k dg root rows logN, op.len ≤ Lq := by
  intro op hop
  simp only [rtBlockFrame, List.mem_cons, List.mem_nil_iff, or_false] at hop
  rcases hop with rfl | rfl | rfl | rfl | rfl <;>
    simp only [Op.len, labRunStage, labRunBlock, labB, Block.labRows, Block.labLogCols, length_le64, List.length_cons,
      List.length_nil, List.Vector.toList_length] <;> omega

/-- The data of an unreadable segment. -/
def RtData.nil : RtData := ⟨[], ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩, ⟨[], [], []⟩⟩

/-- **What the verifier absorbs in block `k`**, from its decoded segment: the frame, the roots, the slots; `M`'s
opening; `A`'s, `H`'s; the opening of the commitment the block closes. -/
def rtBlockData (P : Block.BlockParams) (k : ℕ) (dg : Dig) (rows logN : ℕ) (sg : Block.Segment) : RtData :=
  ⟨rtBlockFrame k dg (sg.bRoot.getD zeroDig) rows logN ++ (Block.rootOps P sg.core ++ Block.fullOps P 0 sg.core.slots),
    sg.core.maskOpen, sg.core.aOpen, sg.core.hOpen, sg.inOpen⟩

/-- **A block's counts**: the frame's five absorbs, the roots' ten operations (three squeezes) and the slots' (from
the shape), then `M` and the three openings. -/
def rtBlockPart (P : Block.BlockParams) (S wA mA wH mH wX gX mX : ℕ) : RtPart :=
  ⟨15 + shapeLen P 0 P.geom.slots, 3 + shapeSq P 0 P.geom.slots, S, wA, P.geom.aGroups, mA, wH, P.geom.hGroups, mH, wX,
    gX, mX⟩

section Block

variable {St : Type} (Pk : ℕ → Block.BlockParams) (sgeom : St → ℕ → Block.SegGeom)
  (check : St → ℕ → Except String Unit) (paths : St → Block.Segment → Except String Unit) (digest : St → ℕ → Dig)
  (bRows bLogN : ℕ → ℕ) (bndCheck : St → ℕ → List Block.ZClaim → Tr → Except String Unit)
  (bndOpen : (HIn → Dig) → St → ℕ → Dig → List Block.ZClaim → Block.OpeningZk → Tr → Except String Tr)

/-- **Block `k`'s data read off the statement and the segment's bytes** (no oracle). -/
def rtBlockRd (k : ℕ) (s : St) (bytes : List UInt8) : RtData :=
  match rtSegOf (sgeom s k) bytes with
  | some sg => rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg
  | none => RtData.nil

/-- **Block `k` as a scheduled part** of a D12a run (L18's `d12aBlockProf`). -/
def rtBlockSeg (k : ℕ) (p : RtPart) : RtSeg St :=
  ⟨blockSeg (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) k, p,
    rtBlockRd Pk sgeom digest bRows bLogN k⟩

/-- **What the schedule needs of a block's verifier**, in L28's form: the field `maskVerify = maskField tag S`; the
openings of `A` and `H` accepting only when `PcsOk` holds (`pA`, `pH`); the slots' geometry (`hgt`, `hgeomL`); and the
claims' counts on an accepted slot phase (`hcnt`: L28-3; lane L31's `blockSlots_claims` gives them from the commitment
schedule of `define`). -/
structure RtBlk (Lq : ℕ) (P : Block.BlockParams) where
  tag : MTag
  S : ℕ
  nA : ℕ
  nH : ℕ
  nIn : ℕ
  nOut : ℕ
  pA : RtPcs (fun (_ : Unit) H root cl o t => P.pcsVerify H .a root cl o t)
  pH : RtPcs (fun (_ : Unit) H root cl o t => P.pcsVerify H .h root cl o t)
  hgt : P.geom.slots.length = P.geom.terms.length
  hgeomL : ∀ j, j < P.geom.slots.length → 1 ≤ (Block.slotShape P j).2.2
    ∧ 56 + 16 * ((Block.slotShape P j).2.2 + 1) ≤ Lq ∧ 55 + 16 * Block.slotTerms P j ≤ Lq
  hPm : P.maskVerify = maskField tag S
  hcnt : ∀ (H : HIn → Dig) (core : Block.Core) (t : Tr) (bga : Fp2 × Fp2 × Fp2) (rs : List Block.SlotRec)
    (acc : Block.Acc) (t' : Tr), Block.blockSlots H P core t = .ok (bga, rs, acc, t') →
    core.slots.length = P.geom.slots.length →
      acc.claims.a.length = nA ∧ (acc.claims.h ++ [P.logupSumClaim]).length = nH ∧ acc.claims.inp.length = nIn
        ∧ acc.claims.out.length = nOut

/-- **THE BLOCK'S CONTRACT.** Block `k` of a D12a run, with L28's fields (`bp`), a boundary opening that accepts only
when `PcsOk` holds (`pX`), the segment's core geometry the block verifier's (`hgeo`) and `gX` groups in the closed
commitment's opening (`hgX`): whenever the block's framed step accepts from a carry with `pend` pending claims, the
transcript moved by exactly the block's steps (the frame's five absorbs, the roots, the slots, `M`, `A`, `H`, the
boundary opening of `pend + nIn` claims) on the data read off the bytes; that data has the profile's counts and fits
`Lq ≥ 2^20`; and the carry handed on holds the block's `nOut` outgoing claims. -/
theorem rtBlock_holds (k Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq) (bp : RtBlk Lq (Pk k))
    (pX : RtPcs (fun (s : St) H root cl o t => bndOpen H s k root cl o t)) (gX pend : ℕ)
    (hgeo : ∀ s, (sgeom s k).g = (Pk k).geom) (hgX : ∀ s, (sgeom s k).incoming.1 = gX) :
    (rtBlockSeg Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k
      (rtBlockPart (Pk k) bp.S (bp.nA + bp.pA.rows) bp.pA.m (bp.nH + bp.pH.rows) bp.pH.m (pend + bp.nIn + pX.rows) gX
        pX.m)).Holds Lq (fun cr => cr.pending.length = pend) (fun cr => cr.pending.length = bp.nOut) := by
  intro H s bnd bytes cr t cr' t' hinv hstep
  obtain ⟨-, sg, e, root, ic, oc, t₂, hdec, -, hroot, hbv, -, hbo, -, hcr⟩ :=
    (d12a_blockSeg_step_ok_iff Pk sgeom check paths digest bRows bLogN bndCheck bndOpen k H s bnd bytes cr t cr'
      t').mp hstep
  have hgt' : (sgeom s k).g.slots.length = (sgeom s k).g.terms.length := by
    rw [hgeo s]
    exact bp.hgt
  have hshape : Block.CoreShape (Pk k).geom sg.core := by
    have h0 := (Block.decodeSegment_spec hgt' hdec).2.2.1
    rw [hgeo s] at h0
    exact h0
  have hrd : rtBlockRd Pk sgeom digest bRows bLogN k s bytes
      = rtBlockData (Pk k) k (digest s k) (bRows (k + 1)) (bLogN (k + 1)) sg := by
    simp only [rtBlockRd, rtSegOf_decode hgt' hdec]
  have hgin : sg.inOpen.groupVecs.length = gX := by
    rw [← hgX s]
    exact rt_decodeSegment_in hdec
  -- the core, decomposed
  obtain ⟨bga, rs, acc, tM, tA, tH, hbs, -, hmv, hpa, hph, hio⟩ :=
    rt_blockVerify_io H (Pk k) sg.core _ (ic, oc) t₂ hbv
  have hd1 : ∀ i, i < sg.core.slots.length → 1 ≤ (Block.slotShape (Pk k) i).2.2 :=
    fun i hi => (bp.hgeomL i (by rw [← hshape.1]; exact hi)).1
  have htM := blockSlots_tr H (Pk k) sg.core _ bga rs acc tM hbs hd1
  obtain ⟨hcA, hcH, hcI, hcO⟩ := bp.hcnt H sg.core _ bga rs acc tM hbs hshape.1
  simp only [Prod.mk.injEq] at hio
  obtain ⟨hic, hoc⟩ := hio
  rw [bp.hPm] at hmv
  have hinv' : cr.pending.length = pend := hinv
  have hcX : (cr.pending ++ ic).length = pend + bp.nIn := by
    rw [List.length_append, hinv', ← hic, hcI]
  obtain ⟨etail, hfit⟩ := rt_tail Lq hL20 H bp.tag bp.S sg.core.maskRoot _ sg.core.maskOpen bp.pA bp.pH pX () () s
    sg.core.aRoot sg.core.hRoot cr.root acc.claims.a (acc.claims.h ++ [(Pk k).logupSumClaim]) (cr.pending ++ ic)
    sg.core.aOpen sg.core.hOpen sg.inOpen bp.nA bp.nH (pend + bp.nIn) hcA hcH hcX tM tA tH t₂ t' hmv hpa hph hbo
  obtain ⟨hfl0, hfs0⟩ := slots_shape (Pk k) ([], sg.core) hshape bp.hgt
  have hfl : fullLen (Pk k) 0 sg.core.slots = shapeLen (Pk k) 0 (Pk k).geom.slots := hfl0
  have hfs : fullSq (Pk k) 0 sg.core.slots = shapeSq (Pk k) 0 (Pk k).geom.slots := hfs0
  have hfr : runOps H t (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)))
      = blockFrame (d12aBlockProf Pk sgeom check paths digest bRows bLogN bndCheck bndOpen) H s k root t := by
    rw [hroot]
    rfl
  have hframe := rtBlockFrame_fit k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)) Lq hL20
  show t' = runOps H t (stpsOps (rtPartStps _ (rtBlockRd Pk sgeom digest bRows bLogN k s bytes)))
    ∧ RtPartOk Lq _ (rtBlockRd Pk sgeom digest bRows bLogN k s bytes) ∧ cr'.pending.length = bp.nOut
  rw [hrd]
  refine ⟨?_, ⟨?_, ?_, hshape.2.2.2.2.2.2.2.1, hshape.2.2.2.2.2.2.2.2.1, hgin, ?_⟩, ?_⟩
  · rw [rtPartStps_ops]
    show t' = runOps H t ((rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots))
      ++ stpsOps (mStps bp.S sg.core.maskOpen ++ (pcsStps (bp.nA + bp.pA.rows) bp.pA.m sg.core.aOpen
        ++ (pcsStps (bp.nH + bp.pH.rows) bp.pH.m sg.core.hOpen
          ++ pcsStps (pend + bp.nIn + pX.rows) pX.m sg.inOpen))))
    rw [runOps_append, runOps_append, hfr, ← htM]
    exact etail
  · show (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots)).length
        = 15 + shapeLen (Pk k) 0 (Pk k).geom.slots
    simp only [List.length_append, rootOps_length, fullOps_length, hfl, rtBlockFrame, List.length_cons,
      List.length_nil]
    omega
  · show sqN (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
      ++ (Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots))
        = 3 + shapeSq (Pk k) 0 (Pk k).geom.slots
    simp only [sqN_append, rootOps_sq, fullOps_sq, hfs, rtBlockFrame, sqN]
    omega
  · intro op hop
    rw [rtPartStps_ops] at hop
    rcases List.mem_append.mp hop with h1 | h1
    · have h1' : op ∈ rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1))
          ++ Block.rootOps (Pk k) sg.core ++ Block.fullOps (Pk k) 0 sg.core.slots := by
        rw [List.append_assoc]
        exact h1
      exact slots_fit (Pk k) (rtBlockFrame k (digest s k) (sg.bRoot.getD zeroDig) (bRows (k + 1)) (bLogN (k + 1)),
        sg.core) Lq (by omega) hframe hshape bp.hgt (fun j hj => (bp.hgeomL j hj).2) op h1'
    · exact hfit op h1
  · rw [hcr]
    show oc.length = bp.nOut
    rw [← hoc]
    exact hcO

end Block

/-! ## The run's schedule from the three kinds of parts -/

section RunOf

variable {Hdr : Type} (V : RunV Hdr) (key : Option Dig) (domain : List UInt8) (Lq : ℕ)

/-- The parts of the run with their schedules: stage IN-C, the blocks, stage OUT-C. -/
def rtParts (σin : RtSeg (ClsStmt Hdr)) (σblk : ℕ → RtSeg (ClsStmt Hdr)) (σout : RtSeg (ClsStmt Hdr)) :
    List (RtSeg (ClsStmt Hdr)) :=
  σin :: ((List.range V.L).map σblk ++ [σout])

theorem rtParts_get (σin : RtSeg (ClsStmt Hdr)) (σblk : ℕ → RtSeg (ClsStmt Hdr)) (σout : RtSeg (ClsStmt Hdr))
    (j : ℕ) (σ : RtSeg (ClsStmt Hdr)) (h : (rtParts V σin σblk σout)[j]? = some σ) :
    (j = 0 ∧ σ = σin) ∨ (∃ k, j = k + 1 ∧ k < V.L ∧ σ = σblk k) ∨ (j = V.L + 1 ∧ σ = σout) := by
  cases j with
  | zero =>
    left
    simp only [rtParts, List.getElem?_cons_zero, Option.some.injEq] at h
    exact ⟨rfl, h.symm⟩
  | succ i =>
    right
    simp only [rtParts, List.getElem?_cons_succ] at h
    have hl : ((List.range V.L).map σblk).length = V.L := by simp
    by_cases hi : i < V.L
    · left
      rw [List.getElem?_append_left (by rw [hl]; exact hi), List.getElem?_map, List.getElem?_range hi] at h
      simp only [Option.map_some, Option.some.injEq] at h
      exact ⟨i, rfl, hi, h.symm⟩
    · right
      rw [List.getElem?_append_right (by rw [hl]; omega), hl] at h
      have hi0 : i - V.L = 0 := by
        by_contra hne
        obtain ⟨m, hm⟩ : ∃ m, i - V.L = m + 1 := ⟨i - V.L - 1, by omega⟩
        rw [hm] at h
        simp at h
      rw [hi0] at h
      simp only [List.getElem?_cons_zero, Option.some.injEq] at h
      exact ⟨by omega, h.symm⟩

/-- **The classify run's schedule from its parts' contracts** (`RtRun`). The run header's operations with their
counts; stage IN-C's scheduled part, block `k`'s for every `k < L`, stage OUT-C's, each for the run verifier's own
segment verifier; the invariants of the carry (`Inv 0` before stage IN-C, `Inv (k + 1)` before block `k`, `Inv (L + 1)`
before stage OUT-C); and each part's contract. -/
def rtRunOf (hdr : ClsStmt Hdr → List Op) (hdrLen hdrSq : ℕ)
    (hstart : ∀ (H : HIn → Dig) (s : ClsStmt Hdr), V.start H s = runOps H (Tr.newKeyed H domain key) (hdr s))
    (hhdr : ∀ s : ClsStmt Hdr, V.preA s.hdr = .ok () → V.preB s.hdr = .ok () →
      (hdr s).length = hdrLen ∧ sqN (hdr s) = hdrSq ∧ ∀ op ∈ hdr s, op.len ≤ Lq)
    (σin : RtSeg (ClsStmt Hdr)) (σblk : ℕ → RtSeg (ClsStmt Hdr)) (σout : RtSeg (ClsStmt Hdr))
    (hvin : σin.v = inSeg V.inC) (hvblk : ∀ k, (σblk k).v = blockSeg V.blk k) (hvout : σout.v = outSeg V.outC)
    (Inv : ℕ → Carry → Prop) (hInv0 : Inv 0 carry0) (hin : σin.Holds Lq (Inv 0) (Inv 1))
    (hblk : ∀ k, k < V.L → (σblk k).Holds Lq (Inv (k + 1)) (Inv (k + 2)))
    (hout : σout.Holds Lq (Inv (V.L + 1)) (Inv (V.L + 2))) : RtRun V key domain Lq where
  hdr := hdr
  hdrLen := hdrLen
  hdrSq := hdrSq
  σs := rtParts V σin σblk σout
  Inv := Inv
  hstart := hstart
  hhdr := hhdr
  hv := by
    have e : ((List.range V.L).map σblk).map (fun σ => σ.v) = (List.range V.L).map (blockSeg V.blk) := by
      rw [List.map_map]
      exact List.map_congr_left (fun k _ => hvblk k)
    show σin.v :: (((List.range V.L).map σblk ++ [σout]).map (fun σ => σ.v))
      = inSeg V.inC :: ((List.range V.L).map (blockSeg V.blk) ++ [outSeg V.outC])
    rw [List.map_append, e, hvin]
    show inSeg V.inC :: ((List.range V.L).map (blockSeg V.blk) ++ [σout.v]) = _
    rw [hvout]
  hInv0 := hInv0
  hσ := fun j σ h => by
    rcases rtParts_get V σin σblk σout j σ h with ⟨rfl, rfl⟩ | ⟨k, rfl, hk, rfl⟩ | ⟨rfl, rfl⟩
    · exact hin
    · exact hblk k hk
    · exact hout

end RunOf

end ZK60.ProtocolClassify
