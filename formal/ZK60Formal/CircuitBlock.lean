/-
D63, step L2: **`CircuitIff` for one W16R2 block**, and for a run of blocks, as INSTANCES of the approved statement
(`Statements.lean`, `CircuitIff`).

The families are proved one position at a time (CircuitRequant, CircuitNorm, CircuitSoftmax, CircuitMatmul,
CircuitRopeAct) and lifted to stages (CircuitStage). This file composes the stages IN THE BLOCK'S ORDER
(`witness_accuracy::build_with`, witness_accuracy.rs:589-930; the slots of `argument_accuracy.rs` and `argument.rs`):

  norm_a → Q, K, V → RoPE(Q), RoPE(K) → scores → softmax → PV → output projection → residual 1 → norm_m → gate (+ACT),
  up → SiLU product → down → residual 2.

The model: `blockSpec P x`, the integer block on the input words `x`, `none` exactly when the honest builder refuses.
The constraint system: `BlockSat P X X2 w`, every clause of the code at every LOGICAL position, on the field planes of the
witness `w`, with
* the matmul hand-offs as the per-position hosted identities (the conclusion of each matmul's sumcheck and its host's
  zero-check, `CircuitMatmul.lean`): `HostRel s (Σ_i X_i·(W_i·m)) q R`;
* the lookups as LogUp's conclusion read by `codeTable_range_iff` / `codeTable_exp_iff` / `codeTable_act_iff`
  (CircuitRopeAct.lean): `InRange w x` for a range query of family `(tag, w)`, `ExpTable` for the exp tuple,
  `ActTable` for the ACT tuple. **The premise that connects to the IOP layer is exactly L3's `logup_block_bound`
  conclusion: every looked-up tuple of the block is a tuple of `CodeTable fams exp act nG`** (FamsOK for the W16R2
  families: `w16r2Fams_FamsOK`);
* the row sums of `SC_RS` and the hosted sums of squares of `SC_SS` / `SC_SSM` as identities per row.

`block_circuitIff` is the approved `CircuitIff` for `blockModel S P` and `blockArith S P`, for every shape in the
code's class (`BlockShape.Valid`) and every public data the code admits (`BlockPublic.Valid`). `run_circuitIff` composes
blocks: block `k + 1`'s input plane IS block `k`'s output plane (the boundary commitment, `hlink` of
`run_inputs_bounded`), and the run's model is the blocks' composition.

What this is NOT yet (each is stated in the findings document):
* the LOGICAL block: positions are the true positions (tokens, width, heads, head dimension, hidden). The committed
  layout pads `Dom::F` (14336 → 16384 at W16R2), permutes the head slots (C-1) and gates every clause by the domain's
  support indicator; the LAYOUT MAP (a bijection of the support with the logical positions and the pad rule: padded
  planes are zero and contribute nothing to a hosted sum) is the next instance step. W16R3's B3 changes exactly that map
  for `Dom::F` (112 rows of 128, no pad) and nothing here;
* the public-data premises (`BlockPublic.Valid`) are the code's construction checks, cited field by field, not
  re-derived from the export.

Instance choice (a finding, written up rather than changed): the approved `IntModel.admissible : Input → Prop` does
not see the weights, while the integer model refuses on weight-dependent range violations. The instance therefore fixes
the public data per model (`Weights := Unit`), which is sound under P1 (public weights). Under P3 (hidden weights)
`admissible` would need the weights (a statement change for Victor).
-/
import ZK60Formal.CircuitStage
import ZK60Formal.Statements

namespace ZK60.Block

open ZK60 ZK60.Model ZK60.Circuit

/-! ## The shape and the public data -/

/-- One block's logical shape and its public calibration (the trained shape's constants). -/
structure BlockShape where
  T : ℕ
  d : ℕ
  H : ℕ
  G : ℕ
  half : ℕ
  f : ℕ
  /-- the key-value group of each query head (C-1: the top `lkv` bits of the head slot) -/
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

namespace BlockShape

abbrev Tok (S : BlockShape) := Fin S.T
abbrev Wid (S : BlockShape) := Fin S.d
/-- the head dimension as (top bit, index in the half): the RoPE partner flips the top bit (`Coord::Flip`) -/
abbrev HD (S : BlockShape) := Bool × Fin S.half
abbrev QC (S : BlockShape) := Fin S.H × S.HD
abbrev KC (S : BlockShape) := Fin S.G × S.HD
abbrev Hid (S : BlockShape) := Fin S.f
abbrev Pos (S : BlockShape) := S.Tok × S.Wid

end BlockShape

/-- The shape class the code admits (each a check of the code):
* the geometry's no-wrap class: width, query width, head dimension `≤ 4096`, hidden `≤ 16384`
  (accuracy_public.rs:16-28);
* the softmax window: `T·2^f_e ≤ 2^wrho_s`, `wrho_s ≤ 24` (`check_f_e_class`, shape.rs:1968-1976, with
  `wrho_s = clog2(T) + f_e`), and `T ≤ 2^24`;
* `f_p = 12` at LowH24 (accuracy_precision.rs:102), so `f_p ≤ 12`;
* the norm constants: `ceps = 1` at every registered shape (argument.rs:2087-2089), `tn ≤ 16`, `|cn| ≤ 2^24`;
* every requantization window at most 24 bits (`limbs_of`, range16.rs:114-121; accuracy_precision.rs:93-99);
* one to four ACT groups (accuracy_act.rs:15). -/
structure BlockShape.Valid (S : BlockShape) : Prop where
  d_le : S.d ≤ 4096
  qw_le : S.H * (2 * S.half) ≤ 4096
  hd_le : 2 * S.half ≤ 4096
  f_le : S.f ≤ 16384
  T_le : S.T ≤ 2 ^ 24
  window : (S.T : ℤ) * 2 ^ S.fe ≤ 2 ^ S.wrho
  wrho_le : S.wrho ≤ 24
  fp_le : S.fp ≤ 12
  ceps1 : 1 ≤ S.ceps
  ceps2 : S.ceps ≤ 2 ^ 24
  cnA : |S.cnA| ≤ 2 ^ 24
  cnM : |S.cnM| ≤ 2 ^ 24
  tn_le : S.tn ≤ 16
  sq_le : S.sq ≤ 24
  sk_le : S.sk ≤ 24
  sv_le : S.sv ≤ 24
  ss_le : S.ss ≤ 24
  spv_le : S.spv ≤ 24
  sao_le : S.sao ≤ 24
  sgate_le : S.sgate ≤ 24
  sup_le : S.sup ≤ 24
  sprod_le : S.sprod ≤ 24
  sdown_le : S.sdown ≤ 24
  nG_le : S.nG ≤ 4

/-- The public data of one block (P1: public): weights, gains, multipliers, the RoPE, exp and scaled ACT tables, and the
ACT group of each hidden channel. -/
structure BlockPublic (S : BlockShape) where
  gA : S.Wid → ℤ
  gM : S.Wid → ℤ
  wq : S.Wid → S.QC → ℤ
  mq : S.QC → ℕ
  wk : S.Wid → S.KC → ℤ
  mk : S.KC → ℕ
  wv : S.Wid → S.KC → ℤ
  mv : S.KC → ℕ
  wo : S.QC → S.Wid → ℤ
  mo : S.Wid → ℕ
  wg : S.Wid → S.Hid → ℤ
  mg : S.Hid → ℕ
  wu : S.Wid → S.Hid → ℤ
  mu : S.Hid → ℕ
  wd : S.Hid → S.Wid → ℤ
  md : S.Wid → ℕ
  cos : S.Tok → Fin S.half → ℤ
  sin : S.Tok → Fin S.half → ℤ
  exp : ℤ → ℤ
  act : ℕ → ℤ → ℤ
  grpF : S.Hid → ℕ

/-- The public data the code admits:
* weights and gains symmetric int8 (private_block.rs:863-869, witness_accuracy.rs:498-517);
* folded multipliers `≤ 2^14` (accuracy_fold.rs:51-55);
* CS-4 (private_block.rs:631-643): `|cos|, |sin| ≤ 2^7`, `0 ≤ exp ≤ 2^f_e`;
* the scaled ACT words `|act| ≤ 32767·2^16 < 2^31` (accuracy_aligned.rs:44-45);
* every hidden channel's group registered (accuracy_public.rs:142-144, `group_column`, accuracy_act.rs:33-41). -/
structure BlockPublic.Valid {S : BlockShape} (P : BlockPublic S) : Prop where
  gA : ∀ i, |P.gA i| ≤ 127
  gM : ∀ i, |P.gM i| ≤ 127
  wq : ∀ i j, |P.wq i j| ≤ 127
  wk : ∀ i j, |P.wk i j| ≤ 127
  wv : ∀ i j, |P.wv i j| ≤ 127
  wo : ∀ i j, |P.wo i j| ≤ 127
  wg : ∀ i j, |P.wg i j| ≤ 127
  wu : ∀ i j, |P.wu i j| ≤ 127
  wd : ∀ i j, |P.wd i j| ≤ 127
  mq : ∀ j, P.mq j ≤ 2 ^ 14
  mk : ∀ j, P.mk j ≤ 2 ^ 14
  mv : ∀ j, P.mv j ≤ 2 ^ 14
  mo : ∀ j, P.mo j ≤ 2 ^ 14
  mg : ∀ j, P.mg j ≤ 2 ^ 14
  mu : ∀ j, P.mu j ≤ 2 ^ 14
  md : ∀ j, P.md j ≤ 2 ^ 14
  cos : ∀ t i, |P.cos t i| ≤ 2 ^ 7
  sin : ∀ t i, |P.sin t i| ≤ 2 ^ 7
  exp0 : ∀ i, 0 ≤ P.exp i
  exp1 : ∀ i, P.exp i ≤ 2 ^ S.fe
  act : ∀ g i, |P.act g i| ≤ 2 ^ 31
  grpF : ∀ k, P.grpF k < S.nG

variable {S : BlockShape}

/-- An int16 word. -/
abbrev i16 (v : ℤ) : Prop := -2 ^ 15 ≤ v ∧ v ≤ 2 ^ 15 - 1

theorem residual_class {a b v : ℤ} (h : residual a b = some v) : i16 v := by
  unfold residual int16Lo int16Hi at h
  by_cases hc : -32768 ≤ a + b ∧ a + b ≤ 32767
  · rw [if_pos hc] at h
    have hv : a + b = v := Option.some.inj h
    rw [← hv]
    exact ⟨by norm_num; linarith [hc.1], by norm_num; linarith [hc.2]⟩
  · rw [if_neg hc] at h
    cases h

/-! ## The integer block (the model) -/

/-- norm_a's rows. -/
noncomputable def normA (P : BlockPublic S) (x : S.Pos → ℤ) (t : S.Tok) : Option (ℤ × (S.Wid → ℤ)) :=
  normTok S.ceps S.cnA S.tn P.gA fun i => x (t, i)

/-- The words of a norm's rows. -/
def rowY (na : S.Tok → ℤ × (S.Wid → ℤ)) (p : S.Pos) : ℤ := (na p.1).2 p.2

/-- Q, K, V (`matmul` + `quantized`, witness_accuracy.rs: the Q/K/V sites; `SC_QMM`/`SC_KMM`/`SC_VMM`). -/
def qSpec (P : BlockPublic S) (y : S.Pos → ℤ) (p : S.Tok × S.QC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ i, y (p.1, i) * P.wq i p.2) (P.mq p.2) S.sq
def kSpec (P : BlockPublic S) (y : S.Pos → ℤ) (p : S.Tok × S.KC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ i, y (p.1, i) * P.wk i p.2) (P.mk p.2) S.sk
def vSpec (P : BlockPublic S) (y : S.Pos → ℤ) (p : S.Tok × S.KC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ i, y (p.1, i) * P.wv i p.2) (P.mv p.2) S.sv

/-- The RoPE partner of a channel: the top bit of the head dimension flipped. -/
def flipQ (p : S.Tok × S.QC) : S.Tok × S.QC := (p.1, (p.2.1, (!p.2.2.1, p.2.2.2)))
def flipK (p : S.Tok × S.KC) : S.Tok × S.KC := (p.1, (p.2.1, (!p.2.2.1, p.2.2.2)))

/-- The rotated value before its requantization (`rotate`, witness.rs:947-961; `rope_tables_at`). -/
def ropeQ (P : BlockPublic S) (q : S.Tok × S.QC → ℤ) (p : S.Tok × S.QC) : ℤ :=
  P.cos p.1 p.2.2.2 * q p + ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 * q (flipQ p)
def ropeK (P : BlockPublic S) (k : S.Tok × S.KC → ℤ) (p : S.Tok × S.KC) : ℤ :=
  P.cos p.1 p.2.2.2 * k p + ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 * k (flipK p)
def qrSpec (P : BlockPublic S) (q : S.Tok × S.QC → ℤ) (p : S.Tok × S.QC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (ropeQ P q p) 1 7
def krSpec (P : BlockPublic S) (k : S.Tok × S.KC → ℤ) (p : S.Tok × S.KC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (ropeK P k p) 1 7

/-- The scores, every `(head, t, j)` (the score plane is quantized over the whole `Dom::S`, masked columns included). -/
def sSpec (qr : S.Tok × S.QC → ℤ) (kr : S.Tok × S.KC → ℤ) (p : Fin S.H × S.Tok × S.Tok) : Option ℤ :=
  rq (-127) 127 (∑ c : S.HD, qr (p.2.1, (p.1, c)) * kr (p.2.2, (S.grp p.1, c))) 1 S.ss

/-- The softmax rows. -/
noncomputable def smSpec (P : BlockPublic S) (sc : Fin S.H × S.Tok × S.Tok → ℤ) (r : Fin S.H × S.Tok) :
    Option (S.Tok → ℤ) :=
  softmaxF S.fp S.wrho P.exp r.2 fun j => sc (r.1, r.2, j)

/-- `PV` over every source token (a masked column's quotient is zero, so this is the live sum). -/
def oSpec (pr : Fin S.H × S.Tok → S.Tok → ℤ) (v : S.Tok × S.KC → ℤ) (p : S.Tok × S.QC) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ j : S.Tok, pr (p.2.1, p.1) j * v (j, (S.grp p.2.1, p.2.2))) 1 S.spv

def aoSpec (P : BlockPublic S) (o : S.Tok × S.QC → ℤ) (p : S.Pos) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ c : S.QC, o (p.1, c) * P.wo c p.2) (P.mo p.2) S.sao

def x1Spec (x ao : S.Pos → ℤ) (p : S.Pos) : Option ℤ := residual (x p) (ao p)

noncomputable def normM (P : BlockPublic S) (x1 : S.Pos → ℤ) (t : S.Tok) : Option (ℤ × (S.Wid → ℤ)) :=
  normTok S.ceps S.cnM S.tn P.gM fun i => x1 (t, i)

def gSpec (P : BlockPublic S) (ym : S.Pos → ℤ) (p : S.Tok × S.Hid) : Option ℤ :=
  rq (-2048) 2047 (∑ i, ym (p.1, i) * P.wg i p.2) (P.mg p.2) S.sgate

/-- The scaled ACT word of each gate word (the public table, its group's row at `g + 2048`). -/
def actOf (P : BlockPublic S) (g : S.Tok × S.Hid → ℤ) (p : S.Tok × S.Hid) : ℤ := P.act (P.grpF p.2) (g p + 2048)

def uSpec (P : BlockPublic S) (ym : S.Pos → ℤ) (p : S.Tok × S.Hid) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ i, ym (p.1, i) * P.wu i p.2) (P.mu p.2) S.sup

def hSpec (P : BlockPublic S) (g u : S.Tok × S.Hid → ℤ) (p : S.Tok × S.Hid) : Option ℤ :=
  rq (-2 ^ 23) (2 ^ 23 - 1) (actOf P g p * u p) 1 S.sprod

def zSpec (P : BlockPublic S) (h : S.Tok × S.Hid → ℤ) (p : S.Pos) : Option ℤ :=
  rq (-2 ^ 15) (2 ^ 15 - 1) (∑ k, h (p.1, k) * P.wd k p.2) (P.md p.2) S.sdown

def x2Spec (x1 z : S.Pos → ℤ) (p : S.Pos) : Option ℤ := residual (x1 p) (z p)

/-- **The integer block** (`build_with`): every stage in order, refused when any stage refuses. -/
noncomputable def blockSpec (P : BlockPublic S) (x : S.Pos → ℤ) : Option (S.Pos → ℤ) :=
  (liftO (normA P x)).bind fun na =>
  (liftO (qSpec P (rowY na))).bind fun q =>
  (liftO (kSpec P (rowY na))).bind fun k =>
  (liftO (vSpec P (rowY na))).bind fun v =>
  (liftO (qrSpec P q)).bind fun qr =>
  (liftO (krSpec P k)).bind fun kr =>
  (liftO (sSpec qr kr)).bind fun sc =>
  (liftO (smSpec P sc)).bind fun pr =>
  (liftO (oSpec pr v)).bind fun o =>
  (liftO (aoSpec P o)).bind fun ao =>
  (liftO (x1Spec x ao)).bind fun x1 =>
  (liftO (normM P x1)).bind fun nm =>
  (liftO (gSpec P (rowY nm))).bind fun g =>
  (liftO (uSpec P (rowY nm))).bind fun u =>
  (liftO (hSpec P g u)).bind fun h =>
  (liftO (zSpec P h)).bind fun z =>
  liftO (x2Spec x1 z)

/-! ## The constraint system -/

/-- The committed planes of one block (the A planes of every domain; the remainders and limbs are per position). -/
structure BlockWit (S : BlockShape) where
  dA : S.Tok → GF
  Y : S.Pos → GF
  Q : S.Tok × S.QC → GF
  K : S.Tok × S.KC → GF
  V : S.Tok × S.KC → GF
  QR : S.Tok × S.QC → GF
  KR : S.Tok × S.KC → GF
  S8 : Fin S.H × S.Tok × S.Tok → GF
  MX : Fin S.H × S.Tok → GF
  SUM : Fin S.H × S.Tok → GF
  ZSEL : Fin S.H × S.Tok × S.Tok → GF
  E : Fin S.H × S.Tok × S.Tok → GF
  PP : Fin S.H × S.Tok × S.Tok → GF
  O : S.Tok × S.QC → GF
  AO : S.Pos → GF
  X1 : S.Pos → GF
  dM : S.Tok → GF
  YM : S.Pos → GF
  Gt : S.Tok × S.Hid → GF
  Ac : S.Tok × S.Hid → GF
  U : S.Tok × S.Hid → GF
  Hh : S.Tok × S.Hid → GF
  Z : S.Pos → GF

/-- **The block's constraint system** at the logical positions, clause by clause as the code builds it. `X` is the
block's input plane and `X2` its output plane. -/
structure BlockSat (P : BlockPublic S) (X X2 : S.Pos → GF) (w : BlockWit S) : Prop where
  /-- the input word check (accuracy_layout.rs:304) -/
  inX : ∀ p, Word16 (X p)
  /-- norm_a (`SC_SS`, `SC_TZC`, `dzc_w16` :490-491) -/
  normA : ∀ t, NormTokRel S.ceps S.cnA S.tn P.gA (fun i => X (t, i)) (w.dA t) (fun i => w.Y (t, i))
  /-- Q (`SC_QMM` hosted by `qzc_w16`'s `host1`, argument_accuracy.rs:563; accuracy_layout.rs:311) -/
  q : ∀ p : S.Tok × S.QC, ∃ R : GF,
    HostRel S.sq (∑ i, w.Y (p.1, i) * ((P.wq i p.2 * (P.mq p.2 : ℤ) : ℤ) : GF)) (w.Q p) R ∧ Word16 (w.Q p) ∧
      RemW16 S.sq R
  /-- K (`SC_KMM`, `host1` of the Kv slot; accuracy_layout.rs:316) -/
  k : ∀ p : S.Tok × S.KC, ∃ R : GF,
    HostRel S.sk (∑ i, w.Y (p.1, i) * ((P.wk i p.2 * (P.mk p.2 : ℤ) : ℤ) : GF)) (w.K p) R ∧ Word16 (w.K p) ∧
      RemW16 S.sk R
  /-- V (`SC_VMM`, `host2` of the Kv slot; accuracy_layout.rs:317) -/
  v : ∀ p : S.Tok × S.KC, ∃ R : GF,
    HostRel S.sv (∑ i, w.Y (p.1, i) * ((P.wv i p.2 * (P.mv p.2 : ℤ) : ℤ) : GF)) (w.V p) R ∧ Word16 (w.V p) ∧
      RemW16 S.sv R
  /-- RoPE of Q (argument_accuracy.rs:560-561; accuracy_layout.rs:312) -/
  qr : ∀ p : S.Tok × S.QC, ∃ R : GF,
    RopeRel (P.cos p.1 p.2.2.2 : GF) ((ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 : ℤ) : GF) (w.Q p) (w.Q (flipQ p))
      (w.QR p) R ∧ Word16 (w.QR p) ∧ RemW16 7 R
  /-- RoPE of K (accuracy_layout.rs:318) -/
  kr : ∀ p : S.Tok × S.KC, ∃ R : GF,
    RopeRel (P.cos p.1 p.2.2.2 : GF) ((ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 : ℤ) : GF) (w.K p) (w.K (flipK p))
      (w.KR p) R ∧ Word16 (w.KR p) ∧ RemW16 7 R
  /-- the scores (`SC_SCORE` hosted by `szc_w16`'s `host_s`, argument_accuracy.rs:620; accuracy_layout.rs:328-330) -/
  score : ∀ p : Fin S.H × S.Tok × S.Tok, ∃ R : GF,
    HostRel S.ss (∑ c : S.HD, w.QR (p.2.1, (p.1, c)) * w.KR (p.2.2, (S.grp p.1, c))) (w.S8 p) R ∧
      WordS8 (w.S8 p) ∧ RemW16 S.ss R
  /-- softmax (argument_accuracy.rs:624-631, `SC_RS`) -/
  softmax : ∀ r : Fin S.H × S.Tok, SoftmaxRowRel S.fp S.wrho P.exp r.2 (fun j => w.S8 (r.1, r.2, j)) (w.MX r)
    (w.SUM r) (fun j => w.ZSEL (r.1, r.2, j)) (fun j => w.E (r.1, r.2, j)) (fun j => w.PP (r.1, r.2, j))
  /-- `PV` (`SC_PV` hosted by `qzc_w16`'s `host2`, argument_accuracy.rs:564; accuracy_layout.rs:313) -/
  pv : ∀ p : S.Tok × S.QC, ∃ R : GF,
    HostRel S.spv (∑ j : S.Tok, w.PP (p.2.1, p.1, j) * w.V (j, (S.grp p.2.1, p.2.2))) (w.O p) R ∧
      Word16 (w.O p) ∧ RemW16 S.spv R
  /-- the output projection (`SC_WO` hosted by `host_o`, argument_accuracy.rs:496; accuracy_layout.rs:306) -/
  ao : ∀ p : S.Pos, ∃ R : GF,
    HostRel S.sao (∑ c : S.QC, w.O (p.1, c) * ((P.wo c p.2 * (P.mo p.2 : ℤ) : ℤ) : GF)) (w.AO p) R ∧
      Word16 (w.AO p) ∧ RemW16 S.sao R
  /-- residual 1 (argument_accuracy.rs:491; accuracy_layout.rs:306) -/
  res1 : ∀ p, ResidualRel (X p) (w.AO p) (w.X1 p) ∧ Word16 (w.X1 p)
  /-- norm_m (`SC_SSM`, `SC_TZC`, `dzc_w16` :492-493) -/
  normM : ∀ t, NormTokRel S.ceps S.cnM S.tn P.gM (fun i => w.X1 (t, i)) (w.dM t) (fun i => w.YM (t, i))
  /-- the gate and its ACT tuple (`SC_GMM` hosted by `host_g`, argument_accuracy.rs:527-530; accuracy_layout.rs:321) -/
  gate : ∀ p : S.Tok × S.Hid, ∃ R : GF,
    HostRel S.sgate (∑ i, w.YM (p.1, i) * ((P.wg i p.2 * (P.mg p.2 : ℤ) : ℤ) : GF)) (w.Gt p) R ∧
      RemW16 S.sgate R ∧ ActTable P.act S.nG (actQuery (w.Gt p) (w.Ac p) (P.grpF p.2))
  /-- up (`SC_UMM` hosted by `host_u`, argument_accuracy.rs:531; accuracy_layout.rs:321) -/
  up : ∀ p : S.Tok × S.Hid, ∃ R : GF,
    HostRel S.sup (∑ i, w.YM (p.1, i) * ((P.wu i p.2 * (P.mu p.2 : ℤ) : ℤ) : GF)) (w.U p) R ∧ Word16 (w.U p) ∧
      RemW16 S.sup R
  /-- the SiLU product (argument_accuracy.rs:526; accuracy_layout.rs:322-324) -/
  prod : ∀ p : S.Tok × S.Hid, ∃ R : GF, ProdRel S.sprod (w.Ac p) (w.U p) (w.Hh p) R ∧ Word24 (w.Hh p) ∧
    RemW16 S.sprod R
  /-- down (`SC_DMM` hosted by `host_d`, argument_accuracy.rs:497; accuracy_layout.rs:308) -/
  down : ∀ p : S.Pos, ∃ R : GF,
    HostRel S.sdown (∑ k : S.Hid, w.Hh (p.1, k) * ((P.wd k p.2 * (P.md p.2 : ℤ) : ℤ) : GF)) (w.Z p) R ∧
      Word16 (w.Z p) ∧ RemW16 S.sdown R
  /-- residual 2 (argument_accuracy.rs:493; accuracy_layout.rs:308) -/
  res2 : ∀ p, ResidualRel (w.X1 p) (w.Z p) (X2 p) ∧ Word16 (X2 p)

/-! ## Stage planes with field inputs -/

theorem resPlane_iff {P : Type} (x y : P → ℤ) (hx : ∀ p, i16 (x p)) (hy : ∀ p, i16 (y p)) (X Y : P → GF)
    (hX : ∀ p, X p = (x p : GF)) (hY : ∀ p, Y p = (y p : GF)) (X1 : P → GF) :
    (∀ p, ResidualRel (X p) (Y p) (X1 p) ∧ Word16 (X1 p)) ↔
      ∃ v, liftO (fun p => residual (x p) (y p)) = some v ∧ ∀ p, X1 p = (v p : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_) (liftO_exists _ fun p a => X1 p = (a : GF))
  rw [hX p, hY p]
  exact residual_iff (x p) (y p) (hx p).1 (hx p).2 (hy p).1 (hy p).2 (X1 p)

theorem ropePlane_iff {P : Type} (c s a b : P → ℤ) (hc : ∀ p, |c p| ≤ 2 ^ 7) (hs : ∀ p, |s p| ≤ 2 ^ 7)
    (ha : ∀ p, i16 (a p)) (hb : ∀ p, i16 (b p)) (A B : P → GF) (hA : ∀ p, A p = (a p : GF))
    (hB : ∀ p, B p = (b p : GF)) (ROT : P → GF) :
    (∀ p, ∃ R : GF, RopeRel (c p : GF) (s p : GF) (A p) (B p) (ROT p) R ∧ Word16 (ROT p) ∧ RemW16 7 R) ↔
      ∃ v, liftO (fun p => rq (-2 ^ 15) (2 ^ 15 - 1) (c p * a p + s p * b p) 1 7) = some v ∧
        ∀ p, ROT p = (v p : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_) (liftO_exists _ fun p a => ROT p = (a : GF))
  rw [hA p, hB p, rope_iff (c p) (s p) (a p) (b p) (hc p) (hs p) (abs_le_of_int16 (ha p))
    (abs_le_of_int16 (hb p)) (ROT p)]
  constructor
  · rintro ⟨v, r, hv, hq⟩
    exact ⟨v, rq_eq_some.mpr ⟨r, hv⟩, hq⟩
  · rintro ⟨v, hv, hq⟩
    obtain ⟨r, hr⟩ := rq_eq_some.mp hv
    exact ⟨v, r, hr, hq⟩

theorem prodPlane_iff {P : Type} (r : ℕ) (hr : r ≤ 24) (a u : P → ℤ) (ha : ∀ p, |a p| ≤ 2 ^ 31)
    (hu : ∀ p, i16 (u p)) (A U : P → GF) (hA : ∀ p, A p = (a p : GF)) (hU : ∀ p, U p = (u p : GF)) (Hh : P → GF) :
    (∀ p, ∃ R : GF, ProdRel r (A p) (U p) (Hh p) R ∧ Word24 (Hh p) ∧ RemW16 r R) ↔
      ∃ v, liftO (fun p => rq (-2 ^ 23) (2 ^ 23 - 1) (a p * u p) 1 r) = some v ∧ ∀ p, Hh p = (v p : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_) (liftO_exists _ fun p a => Hh p = (a : GF))
  rw [hA p, hU p, product_iff r hr (a p) (u p) (ha p) (abs_le_of_int16 (hu p)) (Hh p)]
  constructor
  · rintro ⟨v, rr, hv, hq⟩
    exact ⟨v, rq_eq_some.mpr ⟨rr, hv⟩, hq⟩
  · rintro ⟨v, hv, hq⟩
    obtain ⟨rr, hr'⟩ := rq_eq_some.mp hv
    exact ⟨v, rr, hr', hq⟩

theorem gatePlane_iff {P ι : Type} [Fintype ι] (act : ℕ → ℤ → ℤ) (nG : ℕ) (hnG : nG ≤ gP) (grp : P → ℕ)
    (hgrp : ∀ p, grp p < nG) (s : ℕ) (hs : s ≤ 24) (x w : P → ι → ℤ) (m : P → ℕ)
    (hb : ∀ p, |(∑ i, x p i * w p i) * (m p : ℤ)| ≤ 2 ^ 62) (X : P → ι → GF) (hX : ∀ p i, X p i = (x p i : GF))
    (G A : P → GF) :
    (∀ p, ∃ R : GF, HostRel s (∑ i, X p i * ((w p i * (m p : ℤ) : ℤ) : GF)) (G p) R ∧ RemW16 s R ∧
        ActTable act nG (actQuery (G p) (A p) (grp p))) ↔
      ∃ v, liftO (fun p => rq (-2048) 2047 (∑ i, x p i * w p i) (m p) s) = some v ∧
        ∀ p, G p = (v p : GF) ∧ A p = (act (grp p) (v p + 2048) : GF) := by
  refine Iff.trans (forall_congr' fun p => ?_)
    (liftO_exists _ fun p a => G p = (a : GF) ∧ A p = (act (grp p) (a + 2048) : GF))
  have hsum : (∑ i, X p i * ((w p i * (m p : ℤ) : ℤ) : GF)) =
      ((((∑ i, x p i * w p i) * (m p : ℤ)) : ℤ) : GF) := by
    rw [← hosted_cast (x p) (w p) (m p)]
    exact Finset.sum_congr rfl fun i _ => by rw [hX p i]
  rw [hsum, gateAct_iff act nG hnG (grp p) (hgrp p) s hs _ (abs_le.mp (hb p)).1 (abs_le.mp (hb p)).2 (G p) (A p)]
  constructor
  · rintro ⟨v, r, hv, hg, ha⟩
    refine ⟨v, rq_eq_some.mpr ⟨r, ?_⟩, hg, ha⟩
    rw [requantIn_mul]
    exact hv
  · rintro ⟨v, hv, hg, ha⟩
    obtain ⟨r, hr⟩ := rq_eq_some.mp hv
    rw [requantIn_mul] at hr
    exact ⟨v, r, hr, hg, ha⟩

theorem normPlane_iff {Tk : Type} {n : ℕ} (hn : n ≤ 4096) (ceps cn : ℤ) (tn : ℕ) (hc1 : 1 ≤ ceps)
    (hc2 : ceps ≤ 2 ^ 24) (hcn : |cn| ≤ 2 ^ 24) (htn : tn ≤ 16) (gam : Fin n → ℤ) (hg : ∀ i, |gam i| ≤ 127)
    (x : Tk → Fin n → ℤ) (hx : ∀ t i, i16 (x t i)) (X : Tk → Fin n → GF) (hX : ∀ t i, X t i = (x t i : GF))
    (D : Tk → GF) (Y : Tk → Fin n → GF) :
    (∀ t, NormTokRel ceps cn tn gam (X t) (D t) (Y t)) ↔
      ∃ v : Tk → ℤ × (Fin n → ℤ), liftO (fun t => normTok ceps cn tn gam (x t)) = some v ∧
        ∀ t, D t = ((v t).1 : GF) ∧ ∀ i, Y t i = ((v t).2 i : GF) := by
  refine Iff.trans (forall_congr' fun t => ?_)
    (liftO_exists _ fun t a => D t = (a.1 : GF) ∧ ∀ i, Y t i = (a.2 i : GF))
  have hXt : X t = fun i => (x t i : GF) := funext (hX t)
  rw [hXt, normTok_iff hn ceps cn tn hc1 hc2 hcn htn gam (x t) hg (hx t) (D t) (Y t)]
  constructor
  · rintro ⟨dd, yy, h1, h2, h3⟩
    exact ⟨(dd, yy), h1, h2, h3⟩
  · rintro ⟨⟨dd, yy⟩, h1, h2, h3⟩
    exact ⟨dd, yy, h1, h2, h3⟩

/-! ## The block -/

/-- **`CircuitIff` for one block, plane form**: the constraint system is satisfiable with input words `x` and output
plane `X2` exactly when the integer block admits `x` and `X2` is the image of its output words. -/
theorem blockSat_iff (hS : S.Valid) (P : BlockPublic S) (hP : P.Valid) (x : S.Pos → ℤ) (hx : ∀ p, i16 (x p))
    (X2 : S.Pos → GF) :
    (∃ w, BlockSat P (fun p => (x p : GF)) X2 w) ↔
      ∃ y, blockSpec P x = some y ∧ (∀ p, i16 (y p)) ∧ ∀ p, X2 p = (y p : GF) := by
  have cW : Fintype.card S.Wid ≤ 4096 := by simpa using hS.d_le
  have cQ : Fintype.card S.QC ≤ 4096 := by simpa using hS.qw_le
  have cHD : Fintype.card S.HD ≤ 4096 := by simpa using hS.hd_le
  have cT : Fintype.card S.Tok ≤ 2 ^ 24 := by simpa using hS.T_le
  have cF : Fintype.card S.Hid ≤ 16384 := by simpa using hS.f_le
  have hnG : S.nG ≤ gP := le_trans hS.nG_le (by norm_num)
  have hfp24 : S.fp ≤ 24 := le_trans hS.fp_le (by norm_num)
  have h2fp : (2 : ℤ) ^ S.fp ≤ 2 ^ 12 := pow_le_pow_right₀ (by norm_num) hS.fp_le
  constructor
  · rintro ⟨w, -, hNA, hQ, hK, hV, hQR, hKR, hSC, hSM, hPV, hAO, hR1, hNM, hG, hU, hH, hZ, hR2⟩
    -- norm_a
    obtain ⟨na, hna, hnaC⟩ := (normPlane_iff hS.d_le S.ceps S.cnA S.tn hS.ceps1 hS.ceps2 hS.cnA hS.tn_le P.gA
      hP.gA (fun t i => x (t, i)) (fun t i => hx (t, i)) (fun t i => (x (t, i) : GF)) (fun t i => rfl) w.dA
      (fun t i => w.Y (t, i))).mp hNA
    have hY : ∀ p, w.Y p = (rowY na p : GF) := fun p => (hnaC p.1).2 p.2
    have hyc : ∀ p, i16 (rowY na p) := fun p => normTok_class (liftO_eq_some.mp hna p.1) p.2
    -- Q, K, V
    obtain ⟨q, hq, hqC⟩ := (rqPlane_iff word16Class S.sq hS.sq_le (fun (p : S.Tok × S.QC) i => rowY na (p.1, i))
      (fun p i => P.wq i p.2) (fun p => P.mq p.2)
      (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wq _ _) (hP.mq _) cW)
      (fun p i => w.Y (p.1, i)) (fun p i => hY _) w.Q).mp hQ
    have hqc : ∀ p, i16 (q p) := fun p => liftO_rq_class hq p
    obtain ⟨k, hk, hkC⟩ := (rqPlane_iff word16Class S.sk hS.sk_le (fun (p : S.Tok × S.KC) i => rowY na (p.1, i))
      (fun p i => P.wk i p.2) (fun p => P.mk p.2)
      (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wk _ _) (hP.mk _) cW)
      (fun p i => w.Y (p.1, i)) (fun p i => hY _) w.K).mp hK
    have hkc : ∀ p, i16 (k p) := fun p => liftO_rq_class hk p
    obtain ⟨v, hv, hvC⟩ := (rqPlane_iff word16Class S.sv hS.sv_le (fun (p : S.Tok × S.KC) i => rowY na (p.1, i))
      (fun p i => P.wv i p.2) (fun p => P.mv p.2)
      (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wv _ _) (hP.mv _) cW)
      (fun p i => w.Y (p.1, i)) (fun p i => hY _) w.V).mp hV
    have hvc : ∀ p, i16 (v p) := fun p => liftO_rq_class hv p
    -- RoPE
    obtain ⟨qr, hqr, hqrC⟩ := (ropePlane_iff (fun p : S.Tok × S.QC => P.cos p.1 p.2.2.2)
      (fun p => ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2) q (fun p => q (flipQ p)) (fun p => hP.cos _ _)
      (fun p => (abs_ropeSgn_mul _ _).trans_le (hP.sin _ _)) hqc (fun p => hqc _) w.Q (fun p => w.Q (flipQ p))
      hqC (fun p => hqC _) w.QR).mp hQR
    have hqrc : ∀ p, i16 (qr p) := fun p => liftO_rq_class hqr p
    obtain ⟨kr, hkr, hkrC⟩ := (ropePlane_iff (fun p : S.Tok × S.KC => P.cos p.1 p.2.2.2)
      (fun p => ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2) k (fun p => k (flipK p)) (fun p => hP.cos _ _)
      (fun p => (abs_ropeSgn_mul _ _).trans_le (hP.sin _ _)) hkc (fun p => hkc _) w.K (fun p => w.K (flipK p))
      hkC (fun p => hkC _) w.KR).mp hKR
    have hkrc : ∀ p, i16 (kr p) := fun p => liftO_rq_class hkr p
    -- scores
    obtain ⟨sc, hsc, hscC⟩ := (rqPlaneBil_iff wordS8Class S.ss hS.ss_le
      (fun (p : Fin S.H × S.Tok × S.Tok) c => qr (p.2.1, (p.1, c))) (fun p c => kr (p.2.2, (S.grp p.1, c)))
      (fun p => hostedScore_le _ _ (fun c => hqrc _) (fun c => hkrc _) cHD)
      (fun p c => w.QR (p.2.1, (p.1, c))) (fun p c => w.KR (p.2.2, (S.grp p.1, c)))
      (fun p c => hqrC _) (fun p c => hkrC _) w.S8).mp hSC
    have hscc : ∀ p, -127 ≤ sc p ∧ sc p ≤ 127 := fun p => liftO_rq_class hsc p
    -- softmax
    have hSM' : ∀ r : Fin S.H × S.Tok, ∃ a, smSpec P sc r = some a ∧ ∀ j, w.PP (r.1, r.2, j) = (a j : GF) :=
      fun r => (softmaxRow_iff S.fp S.wrho S.fe hfp24 hS.wrho_le P.exp hP.exp0 hP.exp1 hS.window r.2
        (fun j => sc (r.1, r.2, j)) (fun j => hscc _) (fun j => w.S8 (r.1, r.2, j)) (fun j => hscC _)
        (fun j => w.PP (r.1, r.2, j))).mp ⟨w.MX r, w.SUM r, _, _, hSM r⟩
    obtain ⟨pr, hpr, hprC⟩ := (liftO_exists _ _).mp hSM'
    have hprc : ∀ r j, 0 ≤ pr r j ∧ pr r j ≤ 2 ^ 12 := fun r j => by
      obtain ⟨h0, h1⟩ := softmaxF_class S.fp S.wrho P.exp hP.exp0 r.2 _ (liftO_eq_some.mp hpr r) j
      exact ⟨h0, le_trans h1 h2fp⟩
    -- PV
    obtain ⟨o, ho, hoC⟩ := (rqPlaneBil_iff word16Class S.spv hS.spv_le
      (fun (p : S.Tok × S.QC) j => pr (p.2.1, p.1) j) (fun p j => v (j, (S.grp p.2.1, p.2.2)))
      (fun p => hostedPV_le _ _ (fun j => hprc _ _) (fun j => hvc _) cT)
      (fun p j => w.PP (p.2.1, p.1, j)) (fun p j => w.V (j, (S.grp p.2.1, p.2.2)))
      (fun p j => hprC (p.2.1, p.1) j) (fun p j => hvC _) w.O).mp hPV
    have hoc : ∀ p, i16 (o p) := fun p => liftO_rq_class ho p
    -- the output projection
    obtain ⟨ao, hao, haoC⟩ := (rqPlane_iff word16Class S.sao hS.sao_le (fun (p : S.Pos) c => o (p.1, c))
      (fun p c => P.wo c p.2) (fun p => P.mo p.2)
      (fun p => hosted16_le _ _ _ (fun c => hoc _) (fun c => hP.wo _ _) (hP.mo _) cQ)
      (fun p c => w.O (p.1, c)) (fun p c => hoC _) w.AO).mp hAO
    have haoc : ∀ p, i16 (ao p) := fun p => liftO_rq_class hao p
    -- residual 1
    obtain ⟨x1, hx1, hx1C⟩ := (resPlane_iff x ao hx haoc (fun p => (x p : GF)) w.AO (fun p => rfl) haoC
      w.X1).mp hR1
    have hx1c : ∀ p, i16 (x1 p) := fun p => residual_class (liftO_eq_some.mp hx1 p)
    -- norm_m
    obtain ⟨nm, hnm, hnmC⟩ := (normPlane_iff hS.d_le S.ceps S.cnM S.tn hS.ceps1 hS.ceps2 hS.cnM hS.tn_le P.gM
      hP.gM (fun t i => x1 (t, i)) (fun t i => hx1c _) (fun t i => w.X1 (t, i)) (fun t i => hx1C _) w.dM
      (fun t i => w.YM (t, i))).mp hNM
    have hYM : ∀ p, w.YM p = (rowY nm p : GF) := fun p => (hnmC p.1).2 p.2
    have hymc : ∀ p, i16 (rowY nm p) := fun p => normTok_class (liftO_eq_some.mp hnm p.1) p.2
    -- gate and ACT, up
    obtain ⟨g, hg, hgC⟩ := (gatePlane_iff P.act S.nG hnG (fun p : S.Tok × S.Hid => P.grpF p.2)
      (fun p => hP.grpF _) S.sgate hS.sgate_le (fun p i => rowY nm (p.1, i)) (fun p i => P.wg i p.2)
      (fun p => P.mg p.2) (fun p => hosted16_le _ _ _ (fun i => hymc _) (fun i => hP.wg _ _) (hP.mg _) cW)
      (fun p i => w.YM (p.1, i)) (fun p i => hYM _) w.Gt w.Ac).mp hG
    obtain ⟨u, hu, huC⟩ := (rqPlane_iff word16Class S.sup hS.sup_le (fun (p : S.Tok × S.Hid) i => rowY nm (p.1, i))
      (fun p i => P.wu i p.2) (fun p => P.mu p.2)
      (fun p => hosted16_le _ _ _ (fun i => hymc _) (fun i => hP.wu _ _) (hP.mu _) cW)
      (fun p i => w.YM (p.1, i)) (fun p i => hYM _) w.U).mp hU
    have huc : ∀ p, i16 (u p) := fun p => liftO_rq_class hu p
    -- the SiLU product
    obtain ⟨h, hh, hhC⟩ := (prodPlane_iff S.sprod hS.sprod_le (actOf P g) u (fun p => hP.act _ _) huc w.Ac w.U
      (fun p => (hgC p).2) huC w.Hh).mp hH
    have hhc : ∀ p, -2 ^ 23 ≤ h p ∧ h p ≤ 2 ^ 23 - 1 := fun p => liftO_rq_class hh p
    -- down
    obtain ⟨z, hz, hzC⟩ := (rqPlane_iff word16Class S.sdown hS.sdown_le (fun (p : S.Pos) k => h (p.1, k))
      (fun p k => P.wd k p.2) (fun p => P.md p.2)
      (fun p => hosted24_le _ _ _ (fun k => hhc _) (fun k => hP.wd _ _) (hP.md _) cF)
      (fun p k => w.Hh (p.1, k)) (fun p k => hhC _) w.Z).mp hZ
    have hzc : ∀ p, i16 (z p) := fun p => liftO_rq_class hz p
    -- residual 2
    obtain ⟨y, hy, hyC⟩ := (resPlane_iff x1 z hx1c hzc w.X1 w.Z hx1C hzC X2).mp hR2
    have hyc' : ∀ p, i16 (y p) := fun p => residual_class (liftO_eq_some.mp hy p)
    -- the spec, stage by stage
    have e1 : liftO (normA P x) = some na := hna
    have e2 : liftO (qSpec P (rowY na)) = some q := hq
    have e3 : liftO (kSpec P (rowY na)) = some k := hk
    have e4 : liftO (vSpec P (rowY na)) = some v := hv
    have e5 : liftO (qrSpec P q) = some qr := hqr
    have e6 : liftO (krSpec P k) = some kr := hkr
    have e7 : liftO (sSpec qr kr) = some sc := hsc
    have e8 : liftO (smSpec P sc) = some pr := hpr
    have e9 : liftO (oSpec pr v) = some o := ho
    have e10 : liftO (aoSpec P o) = some ao := hao
    have e11 : liftO (x1Spec x ao) = some x1 := hx1
    have e12 : liftO (normM P x1) = some nm := hnm
    have e13 : liftO (gSpec P (rowY nm)) = some g := hg
    have e14 : liftO (uSpec P (rowY nm)) = some u := hu
    have e15 : liftO (hSpec P g u) = some h := hh
    have e16 : liftO (zSpec P h) = some z := hz
    have e17 : liftO (x2Spec x1 z) = some y := hy
    refine ⟨y, ?_, hyc', hyC⟩
    unfold blockSpec
    rw [e1, obind_some, e2, obind_some, e3, obind_some, e4, obind_some, e5, obind_some, e6, obind_some, e7,
      obind_some, e8, obind_some, e9, obind_some, e10, obind_some, e11, obind_some, e12, obind_some, e13,
      obind_some, e14, obind_some, e15, obind_some, e16, obind_some, e17]
  · rintro ⟨y, hy, -, hyC⟩
    unfold blockSpec at hy
    obtain ⟨na, hna, hy⟩ := obind_eq_some.mp hy
    obtain ⟨q, hq, hy⟩ := obind_eq_some.mp hy
    obtain ⟨k, hk, hy⟩ := obind_eq_some.mp hy
    obtain ⟨v, hv, hy⟩ := obind_eq_some.mp hy
    obtain ⟨qr, hqr, hy⟩ := obind_eq_some.mp hy
    obtain ⟨kr, hkr, hy⟩ := obind_eq_some.mp hy
    obtain ⟨sc, hsc, hy⟩ := obind_eq_some.mp hy
    obtain ⟨pr, hpr, hy⟩ := obind_eq_some.mp hy
    obtain ⟨o, ho, hy⟩ := obind_eq_some.mp hy
    obtain ⟨ao, hao, hy⟩ := obind_eq_some.mp hy
    obtain ⟨x1, hx1, hy⟩ := obind_eq_some.mp hy
    obtain ⟨nm, hnm, hy⟩ := obind_eq_some.mp hy
    obtain ⟨g, hg, hy⟩ := obind_eq_some.mp hy
    obtain ⟨u, hu, hy⟩ := obind_eq_some.mp hy
    obtain ⟨h, hh, hy⟩ := obind_eq_some.mp hy
    obtain ⟨z, hz, hy⟩ := obind_eq_some.mp hy
    -- the classes of the integer planes
    have hyc : ∀ p, i16 (rowY na p) := fun p => normTok_class (liftO_eq_some.mp hna p.1) p.2
    have hqc : ∀ p, i16 (q p) := fun p => rq_class (liftO_eq_some.mp hq p)
    have hkc : ∀ p, i16 (k p) := fun p => rq_class (liftO_eq_some.mp hk p)
    have hvc : ∀ p, i16 (v p) := fun p => rq_class (liftO_eq_some.mp hv p)
    have hqrc : ∀ p, i16 (qr p) := fun p => rq_class (liftO_eq_some.mp hqr p)
    have hkrc : ∀ p, i16 (kr p) := fun p => rq_class (liftO_eq_some.mp hkr p)
    have hscc : ∀ p, -127 ≤ sc p ∧ sc p ≤ 127 := fun p => rq_class (liftO_eq_some.mp hsc p)
    have hprc : ∀ r j, 0 ≤ pr r j ∧ pr r j ≤ 2 ^ 12 := fun r j => by
      obtain ⟨h0, h1⟩ := softmaxF_class S.fp S.wrho P.exp hP.exp0 r.2 _ (liftO_eq_some.mp hpr r) j
      exact ⟨h0, le_trans h1 h2fp⟩
    have hoc : ∀ p, i16 (o p) := fun p => rq_class (liftO_eq_some.mp ho p)
    have haoc : ∀ p, i16 (ao p) := fun p => rq_class (liftO_eq_some.mp hao p)
    have hx1c : ∀ p, i16 (x1 p) := fun p => residual_class (liftO_eq_some.mp hx1 p)
    have hymc : ∀ p, i16 (rowY nm p) := fun p => normTok_class (liftO_eq_some.mp hnm p.1) p.2
    have huc : ∀ p, i16 (u p) := fun p => rq_class (liftO_eq_some.mp hu p)
    have hhc : ∀ p, -2 ^ 23 ≤ h p ∧ h p ≤ 2 ^ 23 - 1 := fun p => rq_class (liftO_eq_some.mp hh p)
    have hzc : ∀ p, i16 (z p) := fun p => rq_class (liftO_eq_some.mp hz p)
    -- the softmax rows' witnesses
    have hrow : ∀ r : Fin S.H × S.Tok, ∃ mx sum : GF, ∃ zsel e : S.Tok → GF,
        SoftmaxRowRel S.fp S.wrho P.exp r.2 (fun j => (sc (r.1, r.2, j) : GF)) mx sum zsel e
          (fun j => (pr r j : GF)) :=
      fun r => (softmaxRow_iff S.fp S.wrho S.fe hfp24 hS.wrho_le P.exp hP.exp0 hP.exp1 hS.window r.2
        (fun j => sc (r.1, r.2, j)) (fun j => hscc _) (fun j => (sc (r.1, r.2, j) : GF)) (fun j => rfl)
        (fun j => (pr r j : GF))).mpr ⟨pr r, liftO_eq_some.mp hpr r, fun j => rfl⟩
    choose MXf SUMf ZSELf Ef hrowR using hrow
    refine ⟨{ dA := fun t => ((na t).1 : GF), Y := fun p => (rowY na p : GF), Q := fun p => (q p : GF),
      K := fun p => (k p : GF), V := fun p => (v p : GF), QR := fun p => (qr p : GF), KR := fun p => (kr p : GF),
      S8 := fun p => (sc p : GF), MX := MXf, SUM := SUMf, ZSEL := fun p => ZSELf (p.1, p.2.1) p.2.2,
      E := fun p => Ef (p.1, p.2.1) p.2.2, PP := fun p => (pr (p.1, p.2.1) p.2.2 : GF), O := fun p => (o p : GF),
      AO := fun p => (ao p : GF), X1 := fun p => (x1 p : GF), dM := fun t => ((nm t).1 : GF),
      YM := fun p => (rowY nm p : GF), Gt := fun p => (g p : GF), Ac := fun p => (actOf P g p : GF),
      U := fun p => (u p : GF), Hh := fun p => (h p : GF), Z := fun p => (z p : GF) },
      ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩⟩
    · exact fun p => (word16_iff _).mpr ⟨x p, (hx p).1, (hx p).2, rfl⟩
    · exact (normPlane_iff hS.d_le S.ceps S.cnA S.tn hS.ceps1 hS.ceps2 hS.cnA hS.tn_le P.gA hP.gA
        (fun t i => x (t, i)) (fun t i => hx (t, i)) (fun t i => (x (t, i) : GF)) (fun t i => rfl)
        (fun t => ((na t).1 : GF)) (fun t i => (rowY na (t, i) : GF))).mpr ⟨na, hna, fun t => ⟨rfl, fun i => rfl⟩⟩
    · exact (rqPlane_iff word16Class S.sq hS.sq_le (fun (p : S.Tok × S.QC) i => rowY na (p.1, i)) (fun p i => P.wq i p.2)
        (fun p => P.mq p.2) (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wq _ _) (hP.mq _) cW)
        (fun p i => (rowY na (p.1, i) : GF)) (fun p i => rfl) (fun p => (q p : GF))).mpr ⟨q, hq, fun p => rfl⟩
    · exact (rqPlane_iff word16Class S.sk hS.sk_le (fun (p : S.Tok × S.KC) i => rowY na (p.1, i)) (fun p i => P.wk i p.2)
        (fun p => P.mk p.2) (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wk _ _) (hP.mk _) cW)
        (fun p i => (rowY na (p.1, i) : GF)) (fun p i => rfl) (fun p => (k p : GF))).mpr ⟨k, hk, fun p => rfl⟩
    · exact (rqPlane_iff word16Class S.sv hS.sv_le (fun (p : S.Tok × S.KC) i => rowY na (p.1, i)) (fun p i => P.wv i p.2)
        (fun p => P.mv p.2) (fun p => hosted16_le _ _ _ (fun i => hyc _) (fun i => hP.wv _ _) (hP.mv _) cW)
        (fun p i => (rowY na (p.1, i) : GF)) (fun p i => rfl) (fun p => (v p : GF))).mpr ⟨v, hv, fun p => rfl⟩
    · exact (ropePlane_iff (fun p : S.Tok × S.QC => P.cos p.1 p.2.2.2)
        (fun p => ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2) q (fun p => q (flipQ p)) (fun p => hP.cos _ _)
        (fun p => (abs_ropeSgn_mul _ _).trans_le (hP.sin _ _)) hqc (fun p => hqc _) (fun p => (q p : GF))
        (fun p => (q (flipQ p) : GF)) (fun p => rfl) (fun p => rfl) (fun p => (qr p : GF))).mpr
        ⟨qr, hqr, fun p => rfl⟩
    · exact (ropePlane_iff (fun p : S.Tok × S.KC => P.cos p.1 p.2.2.2)
        (fun p => ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2) k (fun p => k (flipK p)) (fun p => hP.cos _ _)
        (fun p => (abs_ropeSgn_mul _ _).trans_le (hP.sin _ _)) hkc (fun p => hkc _) (fun p => (k p : GF))
        (fun p => (k (flipK p) : GF)) (fun p => rfl) (fun p => rfl) (fun p => (kr p : GF))).mpr
        ⟨kr, hkr, fun p => rfl⟩
    · exact (rqPlaneBil_iff wordS8Class S.ss hS.ss_le (fun (p : Fin S.H × S.Tok × S.Tok) c => qr (p.2.1, (p.1, c)))
        (fun p c => kr (p.2.2, (S.grp p.1, c))) (fun p => hostedScore_le _ _ (fun c => hqrc _) (fun c => hkrc _) cHD)
        (fun p c => (qr (p.2.1, (p.1, c)) : GF)) (fun p c => (kr (p.2.2, (S.grp p.1, c)) : GF)) (fun p c => rfl)
        (fun p c => rfl) (fun p => (sc p : GF))).mpr ⟨sc, hsc, fun p => rfl⟩
    · exact fun r => hrowR r
    · exact (rqPlaneBil_iff word16Class S.spv hS.spv_le (fun (p : S.Tok × S.QC) j => pr (p.2.1, p.1) j)
        (fun p j => v (j, (S.grp p.2.1, p.2.2))) (fun p => hostedPV_le _ _ (fun j => hprc _ _) (fun j => hvc _) cT)
        (fun p j => (pr (p.2.1, p.1) j : GF)) (fun p j => (v (j, (S.grp p.2.1, p.2.2)) : GF)) (fun p j => rfl)
        (fun p j => rfl) (fun p => (o p : GF))).mpr ⟨o, ho, fun p => rfl⟩
    · exact (rqPlane_iff word16Class S.sao hS.sao_le (fun (p : S.Pos) c => o (p.1, c)) (fun p c => P.wo c p.2)
        (fun p => P.mo p.2) (fun p => hosted16_le _ _ _ (fun c => hoc _) (fun c => hP.wo _ _) (hP.mo _) cQ)
        (fun p c => (o (p.1, c) : GF)) (fun p c => rfl) (fun p => (ao p : GF))).mpr ⟨ao, hao, fun p => rfl⟩
    · exact (resPlane_iff x ao hx haoc (fun p => (x p : GF)) (fun p => (ao p : GF)) (fun p => rfl) (fun p => rfl)
        (fun p => (x1 p : GF))).mpr ⟨x1, hx1, fun p => rfl⟩
    · exact (normPlane_iff hS.d_le S.ceps S.cnM S.tn hS.ceps1 hS.ceps2 hS.cnM hS.tn_le P.gM hP.gM
        (fun t i => x1 (t, i)) (fun t i => hx1c _) (fun t i => (x1 (t, i) : GF)) (fun t i => rfl)
        (fun t => ((nm t).1 : GF)) (fun t i => (rowY nm (t, i) : GF))).mpr ⟨nm, hnm, fun t => ⟨rfl, fun i => rfl⟩⟩
    · exact (gatePlane_iff P.act S.nG hnG (fun p : S.Tok × S.Hid => P.grpF p.2) (fun p => hP.grpF _) S.sgate
        hS.sgate_le (fun p i => rowY nm (p.1, i)) (fun p i => P.wg i p.2) (fun p => P.mg p.2)
        (fun p => hosted16_le _ _ _ (fun i => hymc _) (fun i => hP.wg _ _) (hP.mg _) cW)
        (fun p i => (rowY nm (p.1, i) : GF)) (fun p i => rfl) (fun p => (g p : GF))
        (fun p => (actOf P g p : GF))).mpr ⟨g, hg, fun p => ⟨rfl, rfl⟩⟩
    · exact (rqPlane_iff word16Class S.sup hS.sup_le (fun (p : S.Tok × S.Hid) i => rowY nm (p.1, i)) (fun p i => P.wu i p.2)
        (fun p => P.mu p.2) (fun p => hosted16_le _ _ _ (fun i => hymc _) (fun i => hP.wu _ _) (hP.mu _) cW)
        (fun p i => (rowY nm (p.1, i) : GF)) (fun p i => rfl) (fun p => (u p : GF))).mpr ⟨u, hu, fun p => rfl⟩
    · exact (prodPlane_iff S.sprod hS.sprod_le (actOf P g) u (fun p => hP.act _ _) huc (fun p => (actOf P g p : GF))
        (fun p => (u p : GF)) (fun p => rfl) (fun p => rfl) (fun p => (h p : GF))).mpr ⟨h, hh, fun p => rfl⟩
    · exact (rqPlane_iff word16Class S.sdown hS.sdown_le (fun (p : S.Pos) k => h (p.1, k)) (fun p k => P.wd k p.2)
        (fun p => P.md p.2) (fun p => hosted24_le _ _ _ (fun k => hhc _) (fun k => hP.wd _ _) (hP.md _) cF)
        (fun p k => (h (p.1, k) : GF)) (fun p k => rfl) (fun p => (z p : GF))).mpr ⟨z, hz, fun p => rfl⟩
    · exact (resPlane_iff x1 z hx1c hzc (fun p => (x1 p : GF)) (fun p => (z p : GF)) (fun p => rfl) (fun p => rfl)
        X2).mpr ⟨y, hy, hyC⟩

/-- The output words of an admitted block are int16 (residual 2's class). -/
theorem blockSpec_class (P : BlockPublic S) (x y : S.Pos → ℤ) (hy : blockSpec P x = some y) (p : S.Pos) :
    i16 (y p) := by
  unfold blockSpec at hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  obtain ⟨_, -, hy⟩ := obind_eq_some.mp hy
  exact residual_class (liftO_eq_some.mp hy p)

/-! ## The instance of the approved statement -/

/-- The integer block as an `IntModel` (P1: the public data is fixed per model; the output is hidden). -/
noncomputable def blockModel (S : BlockShape) (P : BlockPublic S) : IntModel where
  Weights := Unit
  Input := S.Pos → ℤ
  Output := S.Pos → ℤ
  PubOut := Unit
  HidOut := S.Pos → ℤ
  admissible x := (∀ p, i16 (x p)) ∧ ∃ y, blockSpec P x = some y
  forward _ x := (blockSpec P x).getD fun _ => 0
  publicPart _ := ()
  hiddenPart y := y

/-- The block's constraint system as an `Arith`: the endpoints are the input and output WORDS (int16), and the
committed planes are their images. -/
def blockArith (S : BlockShape) (P : BlockPublic S) : Arith (blockModel S P) where
  Witness := BlockWit S
  Satisfies _ (x : S.Pos → ℤ) (y : S.Pos → ℤ) w :=
    (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ BlockSat P (fun p => (x p : GF)) (fun p => (y p : GF)) w

/-- Two int16 words with the same image in `GF` are equal. -/
theorem i16_eq_of_cast {a b : ℤ} (ha : i16 a) (hb : i16 b) (h : (a : GF) = (b : GF)) : a = b :=
  int_eq_of_cast_eq h (by rw [gP_int]; linarith [ha.1, hb.2]) (by rw [gP_int]; linarith [ha.2, hb.1])

/-- **D63 statement 1's deterministic lemma, `CircuitIff`, for one W16R2 block** (logical layout), for every shape and
public data in the code's class. -/
theorem block_circuitIff (hS : S.Valid) (P : BlockPublic S) (hP : P.Valid) :
    CircuitIff (blockModel S P) (blockArith S P) := by
  intro _ x y
  show (∃ w : BlockWit S, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧
      BlockSat P (fun p => (x p : GF)) (fun p => (y p : GF)) w) ↔
    ((∀ p, i16 (x p)) ∧ ∃ y', blockSpec P x = some y') ∧ y = (blockSpec P x).getD fun _ => 0
  constructor
  · rintro ⟨w, hx, hy, hsat⟩
    obtain ⟨y', hy', hy'c, hc⟩ := (blockSat_iff hS P hP x hx _).mp ⟨w, hsat⟩
    have hyy : y = y' := funext fun p => i16_eq_of_cast (hy p) (hy'c p) (hc p)
    refine ⟨⟨hx, y', hy'⟩, ?_⟩
    rw [hy', hyy, Option.getD_some]
  · rintro ⟨⟨hx, y', hy'⟩, hyd⟩
    have hyy : y = y' := by rw [hyd, hy', Option.getD_some]
    subst hyy
    have hyc := blockSpec_class P x y hy'
    obtain ⟨w, hw⟩ := (blockSat_iff hS P hP x hx _).mpr ⟨y, hy', hyc, fun p => rfl⟩
    exact ⟨w, hx, hyc, hw⟩

/-! ## A run of blocks: the boundary link between layers -/

/-- The integer run: the blocks in order, each on the previous block's output words. -/
noncomputable def runSpec : List (BlockPublic S) → (S.Pos → ℤ) → Option (S.Pos → ℤ)
  | [], x => some x
  | P :: Ps, x => (blockSpec P x).bind (runSpec Ps)

/-- The run's constraint system. Block `k + 1`'s input plane IS block `k`'s output plane, the image of one plane of
int16 words: the boundary commitment equates the two committed planes (`run_inputs_bounded`'s `hlink`; L3's opening
soundness for the boundary commitment supplies it). -/
def RunSat : List (BlockPublic S) → (S.Pos → ℤ) → (S.Pos → ℤ) → Prop
  | [], x, y => y = x
  | P :: Ps, x, y => ∃ x' : S.Pos → ℤ, (∀ p, i16 (x' p)) ∧
      (∃ w, BlockSat P (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSat Ps x' y

theorem runSpec_class (Ps : List (BlockPublic S)) :
    ∀ (x y : S.Pos → ℤ), (∀ p, i16 (x p)) → runSpec Ps x = some y → ∀ p, i16 (y p) := by
  induction Ps with
  | nil =>
    intro x y hx hy
    have hxy : x = y := Option.some.inj hy
    rw [← hxy]
    exact hx
  | cons P Ps ih =>
    intro x y hx hy
    obtain ⟨x', hx', hr⟩ := obind_eq_some.mp hy
    exact ih x' y (blockSpec_class P x x' hx') hr

/-- **The run iff**: the run's constraint system holds exactly when every block of the integer run admits its input
and the run's output is the last block's output. -/
theorem run_iff (hS : S.Valid) (Ps : List (BlockPublic S)) :
    (∀ P ∈ Ps, P.Valid) → ∀ (x y : S.Pos → ℤ), (∀ p, i16 (x p)) → (RunSat Ps x y ↔ runSpec Ps x = some y) := by
  induction Ps with
  | nil =>
    intro _ x y _
    show y = x ↔ some x = some y
    exact ⟨fun h => by rw [h], fun h => (Option.some.inj h).symm⟩
  | cons P Ps ih =>
    intro hPs x y hx
    have hP : P.Valid := hPs P (List.mem_cons.mpr (Or.inl rfl))
    have hPs' : ∀ Q ∈ Ps, Q.Valid := fun Q hQ => hPs Q (List.mem_cons.mpr (Or.inr hQ))
    show (∃ x' : S.Pos → ℤ, (∀ p, i16 (x' p)) ∧
        (∃ w, BlockSat P (fun p => (x p : GF)) (fun p => (x' p : GF)) w) ∧ RunSat Ps x' y) ↔
      (blockSpec P x).bind (runSpec Ps) = some y
    constructor
    · rintro ⟨x', hx', hb, hr⟩
      obtain ⟨y', hy', hy'c, hc⟩ := (blockSat_iff hS P hP x hx _).mp hb
      have hxy : x' = y' := funext fun p => i16_eq_of_cast (hx' p) (hy'c p) (hc p)
      rw [hy', obind_some, ← hxy]
      exact (ih hPs' x' y hx').mp hr
    · intro h
      obtain ⟨x', hx', hr⟩ := obind_eq_some.mp h
      have hx'c := blockSpec_class P x x' hx'
      exact ⟨x', hx'c, (blockSat_iff hS P hP x hx _).mpr ⟨x', hx', hx'c, fun p => rfl⟩,
        (ih hPs' x' y hx'c).mpr hr⟩

/-- The run as an `IntModel`. -/
noncomputable def runModel (S : BlockShape) (Ps : List (BlockPublic S)) : IntModel where
  Weights := Unit
  Input := S.Pos → ℤ
  Output := S.Pos → ℤ
  PubOut := Unit
  HidOut := S.Pos → ℤ
  admissible x := (∀ p, i16 (x p)) ∧ ∃ y, runSpec Ps x = some y
  forward _ x := (runSpec Ps x).getD fun _ => 0
  publicPart _ := ()
  hiddenPart y := y

/-- The run's constraint system as an `Arith` (the intermediate boundary planes and block witnesses are existential
inside `RunSat`). -/
def runArith (S : BlockShape) (Ps : List (BlockPublic S)) : Arith (runModel S Ps) where
  Witness := Unit
  Satisfies _ (x : S.Pos → ℤ) (y : S.Pos → ℤ) _ := (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ RunSat Ps x y

/-- **`CircuitIff` for a run of W16R2 blocks** composed through their boundary planes. -/
theorem run_circuitIff (hS : S.Valid) (Ps : List (BlockPublic S)) (hPs : ∀ P ∈ Ps, P.Valid) :
    CircuitIff (runModel S Ps) (runArith S Ps) := by
  intro _ x y
  show (∃ _w : Unit, (∀ p, i16 (x p)) ∧ (∀ p, i16 (y p)) ∧ RunSat Ps x y) ↔
    ((∀ p, i16 (x p)) ∧ ∃ y', runSpec Ps x = some y') ∧ y = (runSpec Ps x).getD fun _ => 0
  constructor
  · rintro ⟨-, hx, -, hr⟩
    have hspec := (run_iff hS Ps hPs x y hx).mp hr
    refine ⟨⟨hx, y, hspec⟩, ?_⟩
    rw [hspec, Option.getD_some]
  · rintro ⟨⟨hx, y', hy'⟩, hyd⟩
    have hyy : y = y' := by rw [hyd, hy', Option.getD_some]
    subst hyy
    exact ⟨(), hx, runSpec_class Ps x y hx hy', (run_iff hS Ps hPs x y hx).mpr hy'⟩

/-! ## The W16R2 8B geometry is in the class -/

/-- The W16R2 8B T128 geometry (shape.rs:302: width 4096, hidden 14336, 32 query heads of 128 over 8 KV heads,
`f_e = 9` so `wrho_s = clog2(128) + 9 = 16`) meets the geometric fields of `BlockShape.Valid`. -/
theorem w16r2_8B_geometry :
    4096 ≤ 4096 ∧ 32 * (2 * 64) ≤ 4096 ∧ 2 * 64 ≤ 4096 ∧ 14336 ≤ 16384 ∧ 128 ≤ 2 ^ 24 ∧
      (128 : ℤ) * 2 ^ 9 ≤ 2 ^ 16 ∧ 16 ≤ 24 := by
  norm_num

end ZK60.Block

