/-
D63 lane L40 (2026-11-10), part 1: **the run model with ONE SHAPE PER BLOCK** (the gap audit's finding GB-2).

`ClassifyRunPublic S` (CircuitTokenRun.lean) gives every block of the run ONE `BlockShape S`, and `BlockShape` carries
every requantization shift and the two norm constants. The real Shieldstral-1.0-3B export has 17 distinct shift sets
over its 26 layers (`shield_shift_sets`, ShapeR13.lean) and per-layer norm constants as well, so the media app's model
is not `classifyModel S R` for any `S`. This file gives the run a shape per block.

What must agree between the blocks, and why. Exactly the token count `T` and the width `d`:
* block `k + 1`'s input plane IS block `k`'s output plane (the boundary commitment `B_{k+1}`, `run_inputs_bounded`'s
  `hlink`): both are one plane of `T × d` int16 words, so the two blocks must index it by the same `Fin T × Fin d`;
* stage IN-C writes `B_0` at `T` token positions of width `d`, and stage OUT-C reads row `row` of `B_L` at width `d`.
Every other field of `BlockShape` is internal to one block (its heads, head dimension, query groups, hidden width, norm
constants, every shift, `f_p`, `f_e`, the softmax window, the ACT group count and the product word's stack), so each
block carries its own. The run is indexed by a CARRIER shape `S0` of which only `S0.T` and `S0.d` are read (every
definition below reads `S0` through `S0.Tok`, `S0.Wid`, `S0.Pos` or `S0.d` alone, ARGUED by reading them); a block's
shape is its calibration on the carrier's `T` and `d` (`BlockCal.over`), so every block's planes are the carrier's planes
DEFINITIONALLY and no cast appears.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `BlockCal`, `BlockCal.shapeAt`, `BlockCal.over`, `BlockCal.ofShape`, **`BlockCal.ofShape_over`** (`rfl`: a shape is its
  own calibration on itself);
* `RunBlock` (a calibration and its block's public data), `RunBlock.Valid`;
* `runSpecP`, `RunSatP`, `runSpecP_class`, **`run_iffP`** (the run iff, block by block at each block's own shape, from
  the proved `blockSat_iff`), `runBlock_circuitIff` (each block at its own shape is L2's `block_circuitIff`),
  `runModelP`, `runArithP`, **`run_circuitIffP`**;
* `ClassifyRunPublicP`, its `Valid`, `classifySpecP`, `ClassifyRunSatP`, **`classifyRunP_iff`**, `classifyModelP`,
  `classifyArithP`, **`classifyRunP_circuitIff`**: the approved `CircuitIff` for the per-block-shape classifier run;
* the old model is the special case of equal shapes: `RunBlock.ofPub`, `toRunP`, **`runSpecP_ofPub`**,
  **`runSatP_ofPub`**, **`classifySpecP_toRunP`**, **`classifyModelP_toRunP`** (the two `IntModel`s are EQUAL),
  **`classifyRunSatP_toRunP`**, **`toRunP_valid`**, and `classifyRun_circuitIff_viaP` / `run_iff_viaP` (L2's theorems
  re-derived from this file's), so nothing proved about the old model is lost;
* `carrier`: a neutral carrier of a given `T` and `d` (every other field zero).
-/
import ZK60Formal.CircuitTokenRun

set_option autoImplicit false

namespace ZK60.RunShape

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Out ZK60.TokenRun

/-! ## A block's calibration, and its shape on the run's `T` and `d` -/

/-- **A block's calibration**: every field of `BlockShape` except the token count `T` and the width `d` (the heads,
the head dimension, the query groups, the hidden width, the norm constants, every shift, `f_p`, `f_e`, the softmax
window, the ACT group count, the product word's stack). -/
structure BlockCal where
  H : ℕ
  G : ℕ
  half : ℕ
  f : ℕ
  grp : Fin H → Fin G
  ceps : ℤ
  cnA : ℤ
  cnM : ℤ
  tn : ℕ
  sq : ℕ
  sk : ℕ
  sv : ℕ
  ss : ℕ
  spv : ℕ
  sao : ℕ
  sgate : ℕ
  sup : ℕ
  sprod : ℕ
  sdown : ℕ
  fp : ℕ
  fe : ℕ
  wrho : ℕ
  nG : ℕ
  h24 : Bool

/-- The block shape of calibration `c` at token count `T` and width `d`. -/
abbrev BlockCal.shapeAt (c : BlockCal) (T d : ℕ) : BlockShape where
  T := T
  d := d
  H := c.H
  G := c.G
  half := c.half
  f := c.f
  grp := c.grp
  ceps := c.ceps
  cnA := c.cnA
  cnM := c.cnM
  tn := c.tn
  sq := c.sq
  sk := c.sk
  sv := c.sv
  ss := c.ss
  spv := c.spv
  sao := c.sao
  sgate := c.sgate
  sup := c.sup
  sprod := c.sprod
  sdown := c.sdown
  fp := c.fp
  fe := c.fe
  wrho := c.wrho
  nG := c.nG
  h24 := c.h24

/-- **The block shape of calibration `c` in a run whose carrier is `S0`**: `S0`'s `T` and `d`, `c`'s every other
field. Its planes are `S0`'s planes definitionally. -/
abbrev BlockCal.over (c : BlockCal) (S0 : BlockShape) : BlockShape := c.shapeAt S0.T S0.d

/-- The calibration of a shape: every field but `T` and `d`. -/
def BlockCal.ofShape (S : BlockShape) : BlockCal :=
  ⟨S.H, S.G, S.half, S.f, S.grp, S.ceps, S.cnA, S.cnM, S.tn, S.sq, S.sk, S.sv, S.ss, S.spv, S.sao, S.sgate, S.sup,
    S.sprod, S.sdown, S.fp, S.fe, S.wrho, S.nG, S.h24⟩

/-- **A shape is its own calibration on itself** (definitionally: the structure's eta). -/
theorem BlockCal.ofShape_over (S : BlockShape) : (BlockCal.ofShape S).over S = S := rfl

/-- The calibration of a shape on another carrier keeps the carrier's `T` and `d` and the shape's every other field. -/
theorem BlockCal.ofShape_over_eq {S S0 : BlockShape} (hT : S.T = S0.T) (hd : S.d = S0.d) :
    (BlockCal.ofShape S).over S0 = S := by
  obtain ⟨T, d, H, G, half, f, grp, ceps, cnA, cnM, tn, sq, sk, sv, ss, spv, sao, sgate, sup, sprod, sdown, fp, fe,
    wrho, nG, h24⟩ := S
  dsimp only at hT hd
  subst hT hd
  rfl

/-- **A neutral carrier** of token count `T` and width `d`: every other field zero (it is never read). -/
def carrier (T d : ℕ) : BlockShape :=
  ⟨T, d, 0, 0, 0, 0, id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false⟩

/-! ## A run of blocks, each with its own shape -/

variable {S0 : BlockShape}

/-- **One block of the run**: its calibration and its public data at its own shape. -/
structure RunBlock (S0 : BlockShape) where
  cal : BlockCal
  pub : BlockPublic (cal.over S0)

/-- A block in the code's classes: its own shape in `BlockShape.Valid`, its public data in `BlockPublic.Valid`. -/
structure RunBlock.Valid (b : RunBlock S0) : Prop where
  shape : (b.cal.over S0).Valid
  pub : b.pub.Valid

/-- **The integer run**: the blocks in order, each AT ITS OWN SHAPE on the previous block's output words. -/
noncomputable def runSpecP : List (RunBlock S0) → (S0.Pos → ℤ) → Option (S0.Pos → ℤ)
  | [], x => some x
  | b :: bs, x => (blockSpec b.pub x).bind fun y => runSpecP bs y

/-- **The run's constraint system**: block `k`'s `BlockSat` at its own shape, block `k + 1`'s input plane IS block `k`'s
output plane (the image of one plane of int16 words). -/
def RunSatP : List (RunBlock S0) → (S0.Pos → ℤ) → (S0.Pos → ℤ) → Prop
  | [], x, y => y = x
  | b :: bs, x, y => ∃ x' : S0.Pos → ℤ, (∀ p, i16 (x' p)) ∧
      (∃ w, BlockSat b.pub (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSatP bs x' y

theorem runSpecP_class : ∀ (bs : List (RunBlock S0)) (x y : S0.Pos → ℤ), (∀ p, i16 (x p)) →
    runSpecP bs x = some y → ∀ p, i16 (y p)
  | [], x, y, hx, hy => by
    have hxy : x = y := Option.some.inj hy
    rw [← hxy]
    exact hx
  | b :: bs, x, y, _, hy => by
    have hy' : (blockSpec b.pub x).bind (runSpecP (S0 := S0) bs) = some y := hy
    obtain ⟨x', hx', hr⟩ := obind_eq_some.mp hy'
    exact runSpecP_class bs x' y (blockSpec_class b.pub x x' hx') hr

/-- **The run iff, one shape per block**: the run's constraint system holds exactly when every block of the integer
run, at its own shape, accepts its input, and the run's output is the last block's output. From L2's `blockSat_iff` at
each block's shape. -/
theorem run_iffP : ∀ (bs : List (RunBlock S0)), (∀ b ∈ bs, b.Valid) → ∀ (x y : S0.Pos → ℤ), (∀ p, i16 (x p)) →
    (RunSatP bs x y ↔ runSpecP bs x = some y)
  | [], _, x, y, _ => by
    show y = x ↔ some x = some y
    exact ⟨fun h => by rw [h], fun h => (Option.some.inj h).symm⟩
  | b :: bs, hbs, x, y, hx => by
    have hb : b.Valid := hbs b (List.mem_cons.mpr (Or.inl rfl))
    have hbs' : ∀ c ∈ bs, c.Valid := fun c hc => hbs c (List.mem_cons.mpr (Or.inr hc))
    show (∃ x' : S0.Pos → ℤ, (∀ p, i16 (x' p)) ∧
        (∃ w, BlockSat b.pub (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSatP bs x' y) ↔
      (blockSpec b.pub x).bind (runSpecP (S0 := S0) bs) = some y
    constructor
    · rintro ⟨x', hx', hbk, hr⟩
      obtain ⟨y', hy', hy'c, hc⟩ := (blockSat_iff hb.shape b.pub hb.pub x hx _).mp hbk
      have hxy : x' = y' := funext fun p => i16_eq_of_cast (hx' p) (hy'c p) (hc p)
      rw [hy', obind_some, ← hxy]
      exact (run_iffP bs hbs' x' y hx').mp hr
    · intro h
      obtain ⟨x', hx', hr⟩ := obind_eq_some.mp h
      have hx'c := blockSpec_class b.pub x x' hx'
      exact ⟨x', hx'c, (blockSat_iff hb.shape b.pub hb.pub x hx _).mpr ⟨x', hx', hx'c, fun p => rfl⟩,
        (run_iffP bs hbs' x' y hx'c).mpr hr⟩

/-- **Each block of the run, at its own shape, is an instance of L2's `block_circuitIff`** (the approved `CircuitIff`
for one block). -/
theorem runBlock_circuitIff (b : RunBlock S0) (hb : b.Valid) :
    CircuitIff (blockModel (b.cal.over S0) b.pub) (blockArith (b.cal.over S0) b.pub) :=
  block_circuitIff hb.shape b.pub hb.pub

/-- The run of blocks as an `IntModel` (each block at its own shape). -/
noncomputable def runModelP (bs : List (RunBlock S0)) : IntModel where
  Weights := Unit
  Input := S0.Pos → ℤ
  Output := S0.Pos → ℤ
  PubOut := Unit
  HidOut := S0.Pos → ℤ
  admissible x := (∀ p, i16 (x p)) ∧ ∃ y, runSpecP bs x = some y
  forward _ x := (runSpecP bs x).getD fun _ => 0
  publicPart _ := ()
  hiddenPart y := y

/-- The run's constraint system as an `Arith`. -/
def runArithP (bs : List (RunBlock S0)) : Arith (runModelP bs) where
  Witness := Unit
  Satisfies _ (x : S0.Pos → ℤ) (y : S0.Pos → ℤ) _ := (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ RunSatP bs x y

/-- **`CircuitIff` for a run of blocks, each at its own shape**, composed through their boundary planes. -/
theorem run_circuitIffP (bs : List (RunBlock S0)) (hbs : ∀ b ∈ bs, b.Valid) :
    CircuitIff (runModelP bs) (runArithP bs) := by
  intro _ x y
  show (∃ _w : Unit, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ RunSatP bs x y) ↔
    ((∀ p, i16 (x p)) ∧ ∃ y', runSpecP bs x = some y') ∧ y = (runSpecP bs x).getD fun _ => 0
  constructor
  · rintro ⟨-, hx, -, hr⟩
    have hspec := (run_iffP bs hbs x y hx).mp hr
    refine ⟨⟨hx, y, hspec⟩, ?_⟩
    rw [hspec]
    rfl
  · rintro ⟨⟨hx, y', hy'⟩, hyd⟩
    have hyy : y = y' := by rw [hyd, hy', Option.getD_some]
    subst hyy
    exact ⟨(), hx, runSpecP_class bs x y hx hy', (run_iffP bs hbs x y hx).mpr hy'⟩

/-! ## The classifier run with a shape per block -/

/-- **The classifier run's public data, one shape per block**: stage IN-C's data, the blocks (each its calibration and
its public data), stage OUT-C's data at the width `d`, the public verdict row. -/
structure ClassifyRunPublicP (S0 : BlockShape) where
  inp : InPublic S0
  blks : List (RunBlock S0)
  out : OutCPublic S0.d
  row : S0.Tok

/-- The run data the code accepts: the width in the geometry's no-wrap class (`d ≤ 4096`, which every block's own
`BlockShape.Valid` repeats; stage OUT-C needs it even of a run with no block), stage IN-C's, every block's (its shape
and its public data) and stage OUT-C's classes. -/
structure ClassifyRunPublicP.Valid (R : ClassifyRunPublicP S0) : Prop where
  d_le : S0.d ≤ 4096
  inp : R.inp.Valid
  blks : ∀ b ∈ R.blks, b.Valid
  out : R.out.Valid

/-- **The classifier's integer model, one shape per block**: stage IN-C, the blocks at their own shapes, stage OUT-C. -/
noncomputable def classifySpecP (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) : Option ℕ :=
  (inSpec R.inp toks).bind fun x => (runSpecP R.blks x).bind fun y => outCSpec R.out fun i => y (R.row, i)

/-- The classifier run's constraint system, for the published verdict bit `b`. -/
def ClassifyRunSatP (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) (b : ℕ) : Prop :=
  ∃ x y : S0.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧
    InSat R.inp (fun t => (toks t : GF)) (fun p => (x p : GF)) ∧
    RunSatP R.blks x y ∧ OutCSat R.out (fun i => (y (R.row, i) : GF)) b

/-- **The classifier run's iff, one shape per block.** -/
theorem classifyRunP_iff (R : ClassifyRunPublicP S0) (hR : R.Valid) (toks : S0.Tok → ℕ)
    (htoks : ∀ t, toks t < gP) (b : ℕ) (hb : b ≤ 1) : ClassifyRunSatP R toks b ↔ classifySpecP R toks = some b := by
  constructor
  · rintro ⟨x, y, hx, hy, hin, hr, ho⟩
    obtain ⟨x', hx', hX⟩ := (in_iff R.inp hR.inp toks htoks _).mp hin
    have hxx : x = x' := funext fun p => i16_eq_of_cast (hx p) (inSpec_class hR.inp hx' p) (hX p)
    rw [← hxx] at hx'
    have hrun := (run_iffP R.blks hR.blks x y hx).mp hr
    have hout := (outC_iff hR.d_le R.out hR.out (fun i => y (R.row, i)) (fun i => hy _) b hb).mp ho
    unfold classifySpecP
    rw [hx', obind_some, hrun, obind_some]
    exact hout
  · intro h
    unfold classifySpecP at h
    obtain ⟨x, hx, h⟩ := obind_eq_some.mp h
    obtain ⟨y, hy, h⟩ := obind_eq_some.mp h
    have hxc := inSpec_class hR.inp hx
    have hyc := runSpecP_class R.blks x y hxc hy
    exact ⟨x, y, hxc, hyc, (in_iff R.inp hR.inp toks htoks _).mpr ⟨x, hx, fun p => rfl⟩,
      (run_iffP R.blks hR.blks x y hxc).mpr hy,
      (outC_iff hR.d_le R.out hR.out (fun i => y (R.row, i)) (fun i => hyc _) b hb).mpr h⟩

/-- **The classifier run as an `IntModel`, one shape per block**: the item's ids in, the verdict out, PUBLISHED. -/
noncomputable def classifyModelP (R : ClassifyRunPublicP S0) : IntModel where
  Weights := Unit
  Input := S0.Tok → ℕ
  Output := ℕ
  PubOut := ℕ
  HidOut := Unit
  admissible toks := ∃ b, classifySpecP R toks = some b
  forward _ toks := (classifySpecP R toks).getD 0
  publicPart b := b
  hiddenPart _ := ()

/-- What `classifyArithP` asks: canonical endpoint words, the verdict one bit, and the run's constraint system. -/
abbrev classifySatP (R : ClassifyRunPublicP S0) (toks : S0.Tok → ℕ) (b : ℕ) : Prop :=
  (∀ t, toks t < gP) ∧ b ≤ 1 ∧ ClassifyRunSatP R toks b

/-- The classifier run's constraint system as an `Arith`, one shape per block. -/
def classifyArithP (R : ClassifyRunPublicP S0) : Arith (classifyModelP R) where
  Witness := Unit
  Satisfies _ toks b _ := classifySatP R toks b

theorem classifySpecP_lt (R : ClassifyRunPublicP S0) (hR : R.Valid) {toks : S0.Tok → ℕ} {b : ℕ}
    (h : classifySpecP R toks = some b) : (∀ t, toks t < gP) ∧ b ≤ 1 := by
  unfold classifySpecP at h
  obtain ⟨x, hx, h⟩ := obind_eq_some.mp h
  obtain ⟨y, -, h⟩ := obind_eq_some.mp h
  refine ⟨fun t => lt_gP_of_V hR.inp ((inSpec_some hx).1 t), ?_⟩
  unfold outCSpec at h
  obtain ⟨_, -, hv⟩ := Option.map_eq_some_iff.mp h
  rw [← hv]
  exact verdictOf_le _ _

/-- **D63 statement 1's deterministic lemma for the classifier run with a shape per block** (`CircuitIff` for the
approved `IntModel` form): the item's ids in, the published verdict out, through stage IN-C, every block AT ITS OWN
SHAPE and stage OUT-C. -/
theorem classifyRunP_circuitIff (R : ClassifyRunPublicP S0) (hR : R.Valid) :
    CircuitIff (classifyModelP R) (classifyArithP R) := by
  intro _ toks b
  show (∃ _w : Unit, classifySatP R toks b) ↔
    (∃ b', classifySpecP R toks = some b') ∧ b = (classifySpecP R toks).getD 0
  constructor
  · rintro ⟨-, ht, hb, h⟩
    have hs := (classifyRunP_iff R hR toks ht b hb).mp h
    refine ⟨⟨b, hs⟩, ?_⟩
    rw [hs]
    rfl
  · rintro ⟨⟨b', hb'⟩, hbd⟩
    have hbb : b = b' := by rw [hbd, hb']; rfl
    rw [hbb]
    obtain ⟨ht, hb1⟩ := classifySpecP_lt R hR hb'
    exact ⟨(), ht, hb1, (classifyRunP_iff R hR toks ht b' hb1).mpr hb'⟩

/-! ## The old model is the special case of equal shapes -/

variable {S : BlockShape}

/-- An old block (at the run's one shape `S`) as a block of the per-block model: its calibration is `S`'s own. -/
def RunBlock.ofPub (P : BlockPublic S) : RunBlock S := ⟨BlockCal.ofShape S, P⟩

/-- **The old run data as per-block run data** (every block at `S`, the carrier `S`). -/
def toRunP (R : ClassifyRunPublic S) : ClassifyRunPublicP S := ⟨R.inp, R.Ps.map RunBlock.ofPub, R.out, R.row⟩

/-- The per-block integer run at equal shapes IS L2's `runSpec`. -/
theorem runSpecP_ofPub (Ps : List (BlockPublic S)) : ∀ x, runSpecP (Ps.map RunBlock.ofPub) x = runSpec Ps x := by
  induction Ps with
  | nil => intro x; rfl
  | cons P Ps ih =>
    intro x
    show (blockSpec P x).bind (runSpecP (S0 := S) (Ps.map RunBlock.ofPub)) = (blockSpec P x).bind (runSpec Ps)
    rw [funext ih]

/-- The per-block run's constraint system at equal shapes IS L2's `RunSat`. -/
theorem runSatP_ofPub (Ps : List (BlockPublic S)) : ∀ x y, RunSatP (Ps.map RunBlock.ofPub) x y ↔ RunSat Ps x y := by
  induction Ps with
  | nil => intro x y; exact Iff.rfl
  | cons P Ps ih =>
    intro x y
    show (∃ x' : S.Pos → ℤ, (∀ p, i16 (x' p)) ∧
        (∃ w, BlockSat P (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSatP (Ps.map RunBlock.ofPub) x' y) ↔
      (∃ x' : S.Pos → ℤ, (∀ p, i16 (x' p)) ∧
        (∃ w, BlockSat P (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSat Ps x' y)
    exact exists_congr fun x' => and_congr Iff.rfl (and_congr Iff.rfl (ih x' y))

/-- **The per-block classifier model at equal shapes IS L2's `classifySpec`.** -/
theorem classifySpecP_toRunP (R : ClassifyRunPublic S) : classifySpecP (toRunP R) = classifySpec R := by
  funext toks
  show ((inSpec R.inp toks).bind fun x => (runSpecP (R.Ps.map RunBlock.ofPub) x).bind fun y =>
      outCSpec R.out fun i => y (R.row, i)) = classifySpec R toks
  simp only [runSpecP_ofPub]
  rfl

/-- **The two `IntModel`s are equal** at equal shapes: `classifyModelP (toRunP R) = classifyModel S R`. -/
theorem classifyModelP_toRunP (R : ClassifyRunPublic S) : classifyModelP (toRunP R) = classifyModel S R := by
  unfold classifyModelP classifyModel
  rw [classifySpecP_toRunP]

/-- The per-block classifier's constraint system at equal shapes IS L2's `ClassifyRunSat`. -/
theorem classifyRunSatP_toRunP (R : ClassifyRunPublic S) (toks : S.Tok → ℕ) (b : ℕ) :
    ClassifyRunSatP (toRunP R) toks b ↔ ClassifyRunSat R toks b := by
  show (∃ x y : S.Pos → ℤ, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧
      InSat R.inp (fun t => (toks t : GF)) (fun p => (x p : GF)) ∧
      RunSatP (R.Ps.map RunBlock.ofPub) x y ∧ OutCSat R.out (fun i => (y (R.row, i) : GF)) b) ↔ _
  exact exists_congr fun x => exists_congr fun y => and_congr Iff.rfl (and_congr Iff.rfl (and_congr Iff.rfl
    (and_congr (runSatP_ofPub R.Ps x y) Iff.rfl)))

/-- **The old validity premises give the new ones** at equal shapes. -/
theorem toRunP_valid (hS : S.Valid) (R : ClassifyRunPublic S) (hR : R.Valid) : (toRunP R).Valid where
  d_le := hS.d_le
  inp := hR.inp
  blks := by
    intro b hb
    obtain ⟨P, hP, rfl⟩ := List.mem_map.mp hb
    exact ⟨hS, hR.Ps P hP⟩
  out := hR.out

/-- **L2's `classifyRun_circuitIff`, re-derived from this file's `classifyRunP_circuitIff`** at equal shapes: nothing
proved about the one-shape model is lost. -/
theorem classifyRun_circuitIff_viaP (hS : S.Valid) (R : ClassifyRunPublic S) (hR : R.Valid) :
    CircuitIff (classifyModel S R) (classifyArith S R) := by
  intro W toks (b : ℕ)
  have h := classifyRunP_circuitIff (toRunP R) (toRunP_valid hS R hR) W toks b
  have e1 : (∃ w, (classifyArithP (toRunP R)).Satisfies W toks b w) ↔
      ∃ w, (classifyArith S R).Satisfies W toks b w := by
    show (∃ _w : Unit, (∀ t, toks t < gP) ∧ b ≤ 1 ∧ ClassifyRunSatP (toRunP R) toks b) ↔
      (∃ _w : Unit, (∀ t, toks t < gP) ∧ b ≤ 1 ∧ ClassifyRunSat R toks b)
    exact exists_congr fun _ => and_congr Iff.rfl (and_congr Iff.rfl (classifyRunSatP_toRunP R toks b))
  have e2 : ((classifyModelP (toRunP R)).admissible toks ∧ b = (classifyModelP (toRunP R)).forward W toks) ↔
      ((classifyModel S R).admissible toks ∧ b = (classifyModel S R).forward W toks) := by
    show ((∃ b', classifySpecP (toRunP R) toks = some b') ∧ b = (classifySpecP (toRunP R) toks).getD 0) ↔
      ((∃ b', classifySpec R toks = some b') ∧ b = (classifySpec R toks).getD 0)
    rw [classifySpecP_toRunP]
  exact e1.symm.trans (h.trans e2)

/-- **L2's `run_iff`, re-derived from this file's `run_iffP`** at equal shapes. -/
theorem run_iff_viaP (hS : S.Valid) (Ps : List (BlockPublic S)) (hPs : ∀ P ∈ Ps, P.Valid) (x y : S.Pos → ℤ)
    (hx : ∀ p, i16 (x p)) : RunSat Ps x y ↔ runSpec Ps x = some y := by
  have h := run_iffP (Ps.map RunBlock.ofPub) (fun b hb => by
    obtain ⟨P, hP, rfl⟩ := List.mem_map.mp hb
    exact ⟨hS, hPs P hP⟩) x y hx
  rw [runSatP_ofPub, runSpecP_ofPub] at h
  exact h

end ZK60.RunShape
