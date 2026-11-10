/-
D63 lane L51 (2026-11-10), part 1: **the classify run's header as the code builds it, and where the run's transcript
absorbs the input root** (finding L48-3).

Lane L48's `og_hopX0` (RunOpenGeoStageX.lean) discharges the top theorem's `hopX` at part `0` (the input token endpoint)
given `hInAbs`: the run's transcript absorbs the statement's input root `s.inRoot`, as a 32-byte message, at a position
`xPos`. The run header was a free parameter of L34's schedule (`RtRun.hdr`, `rtRunClassify`'s `hdr`, `hstart`, `hhdr`).
Here it is the code's (`ClassifyRunStatement::transcript`, classify.rs:1275-1291): eight absorbs, `run-shape`,
`expected-IO`, `public-statement`, `parameters`, `calibration`, `schedule`, `classify-verdict`, `classify-chunk`, on the
tagged transcript of the run profile. The input root is absorbed ONCE, inside `expected-IO`, whose data is
`"classify-expected/v1" ‖ in_spec.digest() ‖ in_root` (classify.rs:1147-1153; 84 bytes). Stage IN-C never absorbs it
(stage_in_c.rs:399-464: its root is handed to the endpoint opening's verifier, which absorbs no root).

* `ClsHdrW`, **`clsHdrOps`**, `clsHdrOf`, **`clsStart`**: the header's public words, its eight operations at the
  statement's input root and verdict, and `st.transcript()` (CHECKED against the code by `RunAbsCheck.lean` on a real
  classifier receipt: lane L51's export, `results/zk60_lean_l51_20261110/`);
* `ab_hstart`, **`ab_hhdr`**: `rtRunClassify`'s / `rcRunClassifyAt`'s header premises `hstart` and `hhdr` at the code's
  header (8 operations, no squeeze, each within `Lq`);
* **`ab_tr_hdr`**, **`ab_inAbs`**: on an accepted run whose header is the code's, the run's transcript at position `1`
  absorbs `abExpMsg (hw s.hdr).inDig s.inRoot` (the corrected form of `hInAbs`: PROVED); `ab_verdictAbs`: at position
  `6` the public verdict's byte;
* **`ab_hInAbs_false`**, `ab_rootAt_none`, `ab_colX_none`, **`ab_rhOpW_none`**, **`ab_hopX0_at1_empty`**: L48's
  `hInAbs` is FALSE there (an 84-byte message is no 32-byte root), the run's extraction `colX` reads no root there, and
  so no `RhOpW` exists for an opening whose geometry reads its root there: L48's route to part `0`'s `hopX` cannot be
  met at the code's header (finding L51-1);
* the repair the code can make (finding L51-1): `clsHdrOpsFix` (one more absorb, `input-root`, the 32-byte root, right
  after `expected-IO`), **`ab_inAbs_fix`** (L48's `hInAbs` at position `2`, PROVED from it), **`ab_hopX0_fix`**
  (`og_hopX0` with `hInAbs` discharged).

Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunOpenGeoStageX

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open scoped ENNReal
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound ZK60.Exec.StageV ZK60.TokenRun ZK60.Assembly ZK60.StageX
open ZK60.Circuit (gP GF)

/-! ## The labels (ASCII bytes; `RunAbsCheck.lean` compares them with `ascii` of the source's strings) -/

/-- `"run-shape"` -/
def abLabShape : List UInt8 := [114, 117, 110, 45, 115, 104, 97, 112, 101]
/-- `"expected-IO"` -/
def abLabExp : List UInt8 := [101, 120, 112, 101, 99, 116, 101, 100, 45, 73, 79]
/-- `"public-statement"` -/
def abLabPub : List UInt8 := [112, 117, 98, 108, 105, 99, 45, 115, 116, 97, 116, 101, 109, 101, 110, 116]
/-- `"parameters"` -/
def abLabPar : List UInt8 := [112, 97, 114, 97, 109, 101, 116, 101, 114, 115]
/-- `"calibration"` -/
def abLabCal : List UInt8 := [99, 97, 108, 105, 98, 114, 97, 116, 105, 111, 110]
/-- `"schedule"` -/
def abLabSch : List UInt8 := [115, 99, 104, 101, 100, 117, 108, 101]
/-- `"classify-verdict"` -/
def abLabVer : List UInt8 := [99, 108, 97, 115, 115, 105, 102, 121, 45, 118, 101, 114, 100, 105, 99, 116]
/-- `"classify-chunk"` -/
def abLabChk : List UInt8 := [99, 108, 97, 115, 115, 105, 102, 121, 45, 99, 104, 117, 110, 107]
/-- `"classify-expected/v1"`, the tag `expected_bytes` starts with. -/
def abExpTag : List UInt8 := [99, 108, 97, 115, 115, 105, 102, 121, 45, 101, 120, 112, 101, 99, 116, 101, 100, 47, 118, 49]
/-- `"input-root"`: the label of the one absorb the repair adds (finding L51-1; not in the code). -/
def abLabInRoot : List UInt8 := [105, 110, 112, 117, 116, 45, 114, 111, 111, 116]

/-! ## The header -/

/-- **The run header's public words other than the input root and the verdict**, as the code computes them from the
statement: the eleven `u64` of `run-shape` (88 bytes), the input endpoint spec's digest, the public-statement digest,
the parameter line, the calibration digest, the schedule digest, D41's chunk (seven `u64`, 56 bytes). -/
structure ClsHdrW where
  shape : List UInt8
  inDig : Dig
  pubSt : Dig
  params : List UInt8
  calib : Dig
  sched : Dig
  chunk : List UInt8

/-- **`expected_bytes`** (classify.rs:1147-1153): the tag, the input endpoint spec's digest, the input root. -/
def abExpMsg (d r : Dig) : List UInt8 := abExpTag ++ (d.toList ++ r.toList)

theorem abExpMsg_length (d r : Dig) : (abExpMsg d r).length = 84 := by
  have hd : d.toList.length = 32 := d.2
  have hr : r.toList.length = 32 := r.2
  simp only [abExpMsg, List.length_append, hd, hr]
  rfl

/-- **THE CODE'S RUN HEADER** (`ClassifyRunStatement::transcript`, classify.rs:1275-1291): eight absorbs, the input
root `r` inside `expected-IO`, the public verdict `v` as one byte, last but one. -/
def clsHdrOps (w : ClsHdrW) (r : Dig) (v : ℕ) : List Op :=
  [Op.absorb abLabShape w.shape, Op.absorb abLabExp (abExpMsg w.inDig r), Op.absorb abLabPub w.pubSt.toList,
    Op.absorb abLabPar w.params, Op.absorb abLabCal w.calib.toList, Op.absorb abLabSch w.sched.toList,
    Op.absorb abLabVer [UInt8.ofNat v], Op.absorb abLabChk w.chunk]

/-- The header of a statement: its public words `hw s.hdr`, its input root, its verdict. -/
def clsHdrOf {Hdr : Type} (hw : Hdr → ClsHdrW) (s : ClsStmt Hdr) : List Op := clsHdrOps (hw s.hdr) s.inRoot s.verdict

/-- **`st.transcript()`**: the header's operations on the tagged transcript of the run profile `domain`. -/
def clsStart {Hdr : Type} (domain : List UInt8) (key : Option Dig) (hw : Hdr → ClsHdrW) :
    (HIn → Dig) → ClsStmt Hdr → Tr :=
  fun H s => runOps H (Tr.newKeyed H domain key) (clsHdrOf hw s)

theorem clsHdrOps_length (w : ClsHdrW) (r : Dig) (v : ℕ) : (clsHdrOps w r v).length = 8 := rfl

theorem clsHdrOps_sqN (w : ClsHdrW) (r : Dig) (v : ℕ) : sqN (clsHdrOps w r v) = 0 := rfl

/-- Every header operation fits `Lq` bytes when the variable-length words do. -/
theorem clsHdrOps_fit (w : ClsHdrW) (r : Dig) (v : ℕ) (Lq : ℕ)
    (h : 64 + (w.shape.length + w.params.length + w.chunk.length + 84) ≤ Lq) :
    ∀ op ∈ clsHdrOps w r v, op.len ≤ Lq := by
  have e32 : ∀ d : Dig, d.toList.length = 32 := fun d => d.2
  have hx := abExpMsg_length w.inDig r
  intro op hop
  simp only [clsHdrOps, List.mem_cons, List.not_mem_nil, or_false] at hop
  rcases hop with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    simp only [Op.len, e32, hx, List.length_singleton] <;>
    simp only [abLabShape, abLabExp, abLabPub, abLabPar, abLabCal, abLabSch, abLabVer, abLabChk,
      List.length_cons, List.length_nil] <;> omega

/-- **`hstart` at the code's header** (the premise of `rtRunClassify`, `rcRunClassifyAt`): by definition. -/
theorem ab_hstart {Hdr : Type} (domain : List UInt8) (key : Option Dig) (hw : Hdr → ClsHdrW) :
    ∀ (H : HIn → Dig) (s : ClsStmt Hdr),
      clsStart domain key hw H s = runOps H (Tr.newKeyed H domain key) (clsHdrOf hw s) :=
  fun _ _ => rfl

/-- **`hhdr` at the code's header** (the premise of `rtRunClassify`, `rcRunClassifyAt`): `8` operations, no squeeze,
each within `Lq` bytes, whatever the pre-header checks. -/
theorem ab_hhdr {Hdr : Type} (preA preB : Hdr → Except String Unit) (hw : Hdr → ClsHdrW) (Lq : ℕ)
    (hfit : ∀ h : Hdr, 64 + ((hw h).shape.length + (hw h).params.length + (hw h).chunk.length + 84) ≤ Lq) :
    ∀ s : ClsStmt Hdr, preA s.hdr = .ok () → preB s.hdr = .ok () →
      (clsHdrOf hw s).length = 8 ∧ sqN (clsHdrOf hw s) = 0 ∧ ∀ op ∈ clsHdrOf hw s, op.len ≤ Lq :=
  fun s _ _ => ⟨rfl, rfl, clsHdrOps_fit (hw s.hdr) s.inRoot s.verdict Lq (hfit s.hdr)⟩

/-! ## Where the run's transcript absorbs the input root -/

section Abs

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **On an accepted run the run's transcript starts with the header's trace**: it is the trace of the header's
operations followed by the parts', and the header has the profile's length. -/
theorem ab_tr_hdr (R : RtRun V key domain Lq) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE V (liftH G) s segs = .ok ()) :
    R.tr G (s, segs) = opTrace (liftH G) (Tr.newKeyed (liftH G) domain key)
        (R.hdr s ++ stpsOps (rtPartsStps R.pf.parts (R.rd (s, segs)).2))
      ∧ (R.hdr s).length = R.pf.hdrLen := by
  obtain ⟨hgood, -⟩ := R.accept (liftH G) s segs hE
  refine ⟨?_, hgood.1⟩
  show opTrace (liftH G) (Tr.newKeyed (liftH G) domain key) (stpsOps (rtS Lq R.pf R.rd (s, segs))) = _
  rw [rtS_good Lq R.pf R.rd (s, segs) hgood]
  unfold rtStps
  rw [stpsOps_append, stpsOps_opsStps]
  rfl

/-- **An entry of the header**: on an accepted run, at any cut past header position `j`, the run's transcript absorbs
what the header's operation `j` absorbs. -/
theorem ab_absAt_hdr (R : RtRun V key domain Lq) (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt)
    (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (j n : ℕ) (hjn : j < n) (l x : List UInt8)
    (hj : (R.hdr s)[j]? = some (Op.absorb l x)) :
    Block.absAt ((R.tr G (s, segs)).take n) j = some x := by
  obtain ⟨htr, -⟩ := ab_tr_hdr R G s segs hE
  have hjl : j < (R.hdr s).length := by
    rcases Nat.lt_or_ge j (R.hdr s).length with h | h
    · exact h
    · rw [List.getElem?_eq_none h] at hj
      cases hj
  rw [Exec.Link.absAt_take _ _ _ hjn, htr, Block.opTrace_append,
    Exec.Link.absAt_append_left _ _ _ (by rw [Block.opTrace_length]; exact hjl)]
  exact rs_absAt_opTrace (liftH G) _ _ j l x hj

/-- **THE RUN'S TRANSCRIPT ABSORBS THE INPUT ROOT AT POSITION `1`, INSIDE `expected-IO`** (the corrected form of L48's
`hInAbs`): on an accepted run whose header is the code's, at any cut past position `1`, the entry at position `1`
absorbs `"classify-expected/v1" ‖ in_spec.digest() ‖ s.inRoot`. -/
theorem ab_inAbs (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 1 < n) :
    Block.absAt ((R.tr G (s, segs)).take n) 1 = some (abExpMsg (hw s.hdr).inDig s.inRoot) :=
  ab_absAt_hdr R G s segs hE 1 n hn abLabExp _ (by rw [hR]; rfl)

/-- **The header absorbs the public verdict at position `6`** (one byte; L45-1: what stage OUT-C's verifier reader
`Wout` can read the verdict from). -/
theorem ab_verdictAbs (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 6 < n) :
    Block.absAt ((R.tr G (s, segs)).take n) 6 = some [UInt8.ofNat s.verdict] :=
  ab_absAt_hdr R G s segs hE 6 n hn abLabVer _ (by rw [hR]; rfl)

/-- The header has the code's eight operations, so part `0` starts at `8`. -/
theorem ab_off0 (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) :
    R.pf.off 0 = 8 := by
  rw [RtProf.off_zero, ← (ab_tr_hdr R G s segs hE).2, hR]
  rfl

/-! ## L48's `hInAbs` is not met at the code's header -/

/-- **An `expected-IO` message is no root**: `84` bytes, not `32`. -/
theorem abExpMsg_ne (d r r' : Dig) : abExpMsg d r ≠ r'.toList := by
  intro h
  have h1 := abExpMsg_length d r
  rw [h] at h1
  have h2 : r'.toList.length = 32 := r'.2
  omega

/-- **L48's `hInAbs` is FALSE at position `1`** (where the code's header absorbs the input root). -/
theorem ab_hInAbs_false (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 1 < n) :
    Block.absAt ((R.tr G (s, segs)).take n) 1 ≠ some s.inRoot.toList := by
  rw [ab_inAbs hw R hR G s segs hE n hn]
  intro h
  exact abExpMsg_ne _ _ _ (Option.some.inj h)

/-- **The run's extraction reads no root at position `1`** (`rootAt` asks a 32-byte message). -/
theorem ab_rootAt_none (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 1 < n) :
    rootAt ((R.tr G (s, segs)).take n) 1 = none := by
  rw [rootAt, ab_inAbs hw R hR G s segs hE n hn, Option.bind_some]
  simp [digOf?, abExpMsg_length]

/-- **A position that shows no root extracts no column.** -/
theorem ab_colX_of_none (tag : MTag) (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (d i : ℕ) (P : List (QB Lq × Dig)) (hdr : List (TItem × Dig))
    (hr : rootAt hdr i = none) (j : ℕ) :
    colX tag Lq h64 key domain hs hL d i P hdr j = none := by
  unfold colX
  rw [hr]

/-- **The run's extraction `colX` extracts nothing at position `1`** of the code's header. -/
theorem ab_colX_none (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 1 < n) (tag : MTag) (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none)
    (hL : (startMsg domain).length ≤ Lq) (d : ℕ) (P : List (QB Lq × Dig)) (j : ℕ) :
    colX tag Lq h64 key domain hs hL d 1 P ((R.tr G (s, segs)).take n) j = none :=
  ab_colX_of_none tag h64 hs hL d 1 P _ (ab_rootAt_none hw R hR G s segs hE n hn) j

end Abs

section NoW

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag) (Lq : ℕ) (h64 : 64 ≤ Lq) (key : Option Dig)
  (domain : List UInt8) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **NO `RhOpW` FOR AN OPENING WHOSE GEOMETRY READS ITS ROOT WHERE NO ROOT IS SHOWN.** The verifier's `PcsOk` opens
`Q > 0` columns, each of depth `h`, each verifying against the root with `rows` entries; `RhOpW`'s `hcolX` asks each to
be the column `colX` extracts at `g.ipos`; where the transcript shows no 32-byte root, `colX` extracts none. -/
theorem ab_rhOpW_none (W : UInt64 → ℕ) (g : RkGeo) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (P : List (QB Lq × Dig)) (G : QB Lq → Dig) (τ : List (TItem × Dig))
    (hroot : rootAt (τ.take aO) g.ipos = none)
    (w : RhOpW U tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G τ) : False := by
  have hok := w.hok
  unfold PcsOk at hok
  obtain ⟨-, -, hpaths, -, -, -, idx, hidx, hlen, hcols⟩ := hok
  have hQ : 0 < w.prm.nQ := by rw [w.hnQ]; exact w.hQ0
  rw [challengeIndices_sqDs (liftH G) w.prm.nQ w.prm.nn _ w.hpow hQ] at hidx
  simp only [Option.some.injEq, Prod.mk.injEq] at hidx
  obtain ⟨rfl, -⟩ := hidx
  have hl0 : 0 < (toOZ w.zo).columns.length := by
    rw [hlen, idxOf_length, sqDs_length]
    omega
  have hlz : (toOZ w.zo).columns.length = w.zo.columns.length := List.length_map _
  have hc0 := hcols 0 hl0
  unfold ColOk at hc0
  obtain ⟨-, hrows, hver, -⟩ := hc0
  have hmem : (toOZ w.zo).columns.getD 0 (0, [], zeroDig, []) ∈ (toOZ w.zo).columns := by
    rw [List.getD_eq_getElem?_getD, List.getElem?_eq_getElem hl0, Option.getD_some]
    exact List.getElem_mem hl0
  have hp := hpaths _ hmem
  rw [w.hnn, Nat.log2_two_pow] at hp
  have hx := w.hcolX 0 w.hQ0 (by rw [← hlz]; exact hl0) hp hver hrows
  rw [ab_colX_of_none tag h64 hs hL g.h g.ipos P (τ.take aO) hroot] at hx
  simp at hx

end NoW

section NoX

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **L48'S ROUTE TO PART `0`'S CLOSING OPENING IS CLOSED AT THE CODE'S HEADER** (finding L51-1): on an accepted run
whose header is the code's, no opening whose geometry reads its root at position `1` (where the header absorbs the
input root) has an `RhOpW` at any window past the header; in particular `og_hopX0`'s conclusion at `xPos = 1`
(`rkAt g rows 1`, the window `off 0 + oX`) is empty, whatever `hInAbs` would say. -/
theorem ab_hopX0_at1_empty (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (W : UInt64 → ℕ) (g : RkGeo) (hg1 : g.ipos = 1) (nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim)
    (aO aB vpos : ℕ) (haO : 1 < aO) (P : List (QB Lq × Dig)) :
    ¬ Nonempty (RhOpW U tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G (R.tr G (s, segs))) := by
  rintro ⟨w⟩
  refine ab_rhOpW_none U tag Lq h64 key domain hs hL W g nC clr aO aB vpos P G _ ?_ w
  rw [hg1]
  exact ab_rootAt_none hw R hR G s segs hE aO haO

/-- The same at `og_hopX0`'s window: part `0`'s closing opening at `rkAt g rows 1`. -/
theorem ab_hopX0_at1_empty' (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (g : OGeo) (rows nC : ℕ) (clr : List (TItem × Dig) → List Block.ZClaim) (P : List (QB Lq × Dig)) :
    ¬ Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) (rkAt g rows 1) nC clr
      (R.pf.off 0 + (R.pf.part 0).oX) (R.pf.off 0 + (R.pf.part 0).oBX)
      (R.pf.off 0 + (R.pf.part 0).oX + (nC + rows)) P G (R.tr G (s, segs))) :=
  ab_hopX0_at1_empty U tag h64 hs hL hw R hR G s segs hE _ (rkAt g rows 1) rfl nC clr _ _ _
    (by rw [ab_off0 hw R hR G s segs hE]; omega) P

end NoX

/-! ## The repair the code can make: absorb the input root as its own message -/

/-- **The header with the repair** (finding L51-1; NOT the code today): the code's eight absorbs with one more,
`input-root` (the 32-byte root), right after `expected-IO`. In Rust, one line after classify.rs:1283:
`tr.absorb(b"input-root", &self.in_root);`. -/
def clsHdrOpsFix (w : ClsHdrW) (r : Dig) (v : ℕ) : List Op :=
  [Op.absorb abLabShape w.shape, Op.absorb abLabExp (abExpMsg w.inDig r), Op.absorb abLabInRoot r.toList,
    Op.absorb abLabPub w.pubSt.toList, Op.absorb abLabPar w.params, Op.absorb abLabCal w.calib.toList,
    Op.absorb abLabSch w.sched.toList, Op.absorb abLabVer [UInt8.ofNat v], Op.absorb abLabChk w.chunk]

def clsHdrFixOf {Hdr : Type} (hw : Hdr → ClsHdrW) (s : ClsStmt Hdr) : List Op :=
  clsHdrOpsFix (hw s.hdr) s.inRoot s.verdict

theorem clsHdrOpsFix_length (w : ClsHdrW) (r : Dig) (v : ℕ) : (clsHdrOpsFix w r v).length = 9 := rfl

theorem clsHdrOpsFix_sqN (w : ClsHdrW) (r : Dig) (v : ℕ) : sqN (clsHdrOpsFix w r v) = 0 := rfl

section Fix

variable {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}

/-- **L48'S `hInAbs` HOLDS AT THE REPAIRED HEADER, AT POSITION `2`**: on an accepted run whose header is the repaired
one, at any cut past position `2`, the transcript absorbs exactly the 32 bytes of `s.inRoot`. -/
theorem ab_inAbs_fix (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrFixOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ())
    (n : ℕ) (hn : 2 < n) :
    Block.absAt ((R.tr G (s, segs)).take n) 2 = some s.inRoot.toList :=
  ab_absAt_hdr R G s segs hE 2 n hn abLabInRoot _ (by rw [hR]; rfl)

/-- At the repaired header part `0` starts at `9`. -/
theorem ab_off0_fix (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrFixOf hw s)
    (G : QB Lq → Dig) (s : ClsStmt Hdr) (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) :
    R.pf.off 0 = 9 := by
  rw [RtProf.off_zero, ← (ab_tr_hdr R G s segs hE).2, hR]
  rfl

end Fix

section FixX

variable {K : Type} [Field K] [Algebra GF K] (U : K) (tag : MTag)
  {Hdr : Type} {V : RunV Hdr} {key : Option Dig} {domain : List UInt8} {Lq : ℕ}
  (h64 : 64 ≤ Lq) (hs : decodeLink (startMsg domain) = none) (hL : (startMsg domain).length ≤ Lq)

/-- **`og_hopX0` WITH `hInAbs` DISCHARGED AT THE REPAIRED HEADER** (`xPos = 2`): the `i = 0` instance of the top
theorem's `hopX`, from the run's acceptance outside `EvXR`, when part `0`'s closing geometry is the input endpoint's
at position `2`. -/
theorem ab_hopX0_fix (hw : Hdr → ClsHdrW) (R : RtRun V key domain Lq) (hR : ∀ s, R.hdr s = clsHdrFixOf hw s)
    (hv : R.pf.Valid) (G : QB Lq → Dig) (s : ClsStmt Hdr)
    (segs : ClsReceipt) (hE : classifyVerifyE V (liftH G) s segs = .ok ()) (pin : RtPart)
    (inc : Hdr → IncV) (incG : Hdr → StageGeom) (cx0 : IncCtx) (I : RtInc Lq inc incG pin)
    (hσ0 : R.σs[0]? = some (rtIncSeg inc incG cx0 pin))
    (Win : List (TItem × Dig) → IncV) (Wout : List (TItem × Dig) → OutcV) (Pk : ℕ → Block.BlockParams) (Lb : ℕ)
    (base : ℕ → RkPart K Lq) (din : RxMAH) (dblk : ℕ → RxMAH) (dout : RxMAH)
    (hWin : Win ((R.tr G (s, segs)).take (R.pf.off 0 + pin.pre)) = inc s.hdr)
    (g : OGeo) (hg : g.Ok) (hgQ : g.Q ≤ 256) (hX : RkPcsAt U tag g I.pX)
    (hgX : (base 0).gX = rkAt g I.pX.rows 2) (hnX : (base 0).nX = I.nIn)
    (outcG : Hdr → StageGeom) (sgeom : ClsStmt Hdr → ℕ → Block.SegGeom)
    (A : OC (QB Lq) Dig (ClsStmt Hdr × ClsReceipt)) (hrun : A.run G = (s, segs))
    (hXev : ¬ EvXR tag Lq h64 (chainEncB key domain hs Lq hL) 256 256 256 16 16 12 26 (rxCoreOf sgeom)
      (rxVx tag Lq h64 incG outcG sgeom Lb) (rxRoots incG outcG sgeom Lb) A G)
    (hfit : 8 * I.pX.rows ≤ Lq) :
    Nonempty (RhOpW U tag Lq h64 key domain hs hL (rtW R.pf.sqs) ((rxPs base Lb din dblk dout) 0).gX
      ((rxPs base Lb din dblk dout) 0).nX
      (fun hdr => rkPend (rxAcc Win Wout Pk R.pf Lb) 0 hdr ++ ((rxAcc Win Wout Pk R.pf Lb) 0 hdr).claims.inp)
      (R.pf.off 0 + (R.pf.part 0).oX) (R.pf.off 0 + (R.pf.part 0).oBX)
      (R.pf.off 0 + (R.pf.part 0).oX + (((rxPs base Lb din dblk dout) 0).nX
        + ((rxPs base Lb din dblk dout) 0).gX.rows)) (A.runLog G).2 G (R.tr G (s, segs))) :=
  og_hopX0 U tag h64 hs hL R hv G s segs hE pin inc incG cx0 I hσ0 Win Wout Pk Lb base din dblk dout hWin g hg hgQ hX
    2 hgX hnX outcG sgeom A hrun hXev hfit
    (ab_inAbs_fix hw R hR G s segs hE _ (by rw [ab_off0_fix hw R hR G s segs hE]; omega))

end FixX

end ZK60.ProtocolClassify
