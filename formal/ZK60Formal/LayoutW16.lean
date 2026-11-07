/-
D63 step L11, part 4: **the W16R2 layout map** (ASSEMBLY §4.2 item f): from the slots' relations on the COMMITTED cube
(what an accepting block's slots establish about the extracted planes, `SlotW16Sound.lean`) and LogUp's conclusion
(every looked-up tuple is a table tuple, `logup_block_bound`), to CircuitBlock's `BlockSat` at the LOGICAL positions —
the premise of the proved `block_circuitIff`.

The committed layout (read 2026-11-07, `private_block/`; nothing changed):
* every domain is a product of AXES, most-significant first (`shape.rs::natural_log`, `argument.rs:2005-2006`):
  `Dom::T = t`, `Dom::D = (t, i)`, `Dom::Q = (t, head slot, c)`, `Dom::Kv = (t, group, c)`, `Dom::S = (head slot, t, j)`,
  `Dom::Ht = (head slot, t)`, `Dom::F = (t, f)`; each axis is padded to a power of two (`t_pad`, `d_pad`, `f_pad`, …),
  the logical indices EMBEDDED in it (`Ax`);
* **the head-slot order (C-1)**: a query head's slot is (its key-value group's bits, its index within the group), the
  group bits on top (argument.rs:2192-2230), so the bilinear slots read `KR` / `V` at the slot's own group coordinate;
* **the RoPE partner** flips the top bit of the head dimension (`Coord::Flip`, argument_accuracy.rs:550-551);
* **support gating**: every inhomogeneous clause and host term of a padded domain is multiplied by the domain's
  support indicator (`Gate`, argument.rs:1825-1840; `pad::indicator_table`), which is `1` on the logical positions and
  `0` on the pad; the LogUp arm is never gated;
* **the pad rule**: padded entries of the public weights are zero (the verifier's padded copies), and the zero-rule
  planes vanish on the pad (the pad-zero term of each zero-check, `SlotW16Sound.dens_batchPad`).

W16R3's B3 (compact F: 112 rows, no pad) is a different `Ax` for `Dom::F`'s flattened `(t, f)` index and no gate on F;
every statement here is for an arbitrary embedding, so B3 is an instance swap. B2 (zero-check batching) changes how the
relations are established (the slots), not the relations below.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `sum_emb`: a cube sum of a function vanishing off the embedded indices is the logical sum (the pad rule);
* `gated_at`: a gated clause `g·c = 0` with `g = 1` at a logical position gives `c = 0` there (support gating);
* the LogUp bridges (`word16_of_lk`, `remW16_of_lk`, `word24_of_lk`, `wordS8_of_lk`, `bytes24_of_lk`): the tuple
  memberships the W16R2 lookup list makes at a position (`lookups_w16`, accuracy_layout.rs:289-344; `range16.rs`
  `word16`, `rem_lookups`, `word24`, `direct`) give exactly the word, remainder and isqrt facts `BlockSat` uses;
* **`blockSat_of_slots`**: for one W16R2 block, the slots' relations on the cube (`W16Rels`), LogUp's conclusion at
  every logical position (`W16Lookups`) and the layout facts (`W16Pub`) give `BlockSat P X X2 (toWit L E)` for the
  extracted planes read through the layout map; so, by `block_circuitIff`, the block's output is the integer block's.
-/
import ZK60Formal.CircuitBlock

namespace ZK60.Layout

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block
open ZK60.Sound (Tup)
open Finset

/-! ## Axes and the pad rule -/

/-- **One axis of the committed cube**: the logical indices `L` embedded in the padded axis `C`. -/
structure Ax (L C : Type) where
  emb : L → C
  inj : Function.Injective emb

/-- **The pad rule for a sum**: a cube sum of a function that vanishes off the embedded indices is the logical sum. -/
theorem sum_emb {L C M : Type} [Fintype L] [Fintype C] [DecidableEq C] [AddCommMonoid M] (a : Ax L C) (f : C → M)
    (hf : ∀ c, (∀ l, a.emb l ≠ c) → f c = 0) : ∑ c, f c = ∑ l, f (a.emb l) := by
  classical
  rw [← sum_image (fun x _ y _ h => a.inj h)]
  refine (sum_subset (subset_univ _) fun c _ hc => hf c fun l hl => hc ?_).symm
  exact mem_image.mpr ⟨l, mem_univ _, hl⟩

/-- **Support gating**: a gated clause with the gate `1` at a position vanishes there. -/
theorem gated_at {C : Type} (g c : C → GF) (h : ∀ x, g x * c x = 0) (x : C) (hx : g x = 1) : c x = 0 := by
  have := h x
  rwa [hx, one_mul] at this

/-! ## LogUp's conclusion at a position, read as the facts `BlockSat` uses -/

section Lookups

variable {fams : List (ℕ × ℕ)} (hF : FamsOK fams) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
include hF

/-- `range16::word16(plane, 32768)`: `word + 32768` in family 16. -/
theorem word16_of_lk (h16 : (tagW 16, 16) ∈ fams) (x : GF) (h : CodeTable fams exp act nG (rangeQuery (tagW 16) (x + 32768))) :
    Word16 x := (codeTable_range_iff hF exp act nG h16 _).mp h

/-- A remainder's limbs (`rem_lookups`): one query of `bits` bits, or a 16-bit low limb and a `bits − 16`-bit top. -/
def remVal (bits : ℕ) (lo hi : GF) : GF := if bits ≤ 16 then lo else lo + 2 ^ 16 * hi

/-- The tuples of a remainder's lookups. -/
def remLk (bits : ℕ) (lo hi : GF) : List (Tup GF) :=
  if bits ≤ 16 then [rangeQuery (tagW bits) lo] else [rangeQuery (tagW 16) lo, rangeQuery (tagW (bits - 16)) hi]

theorem remW16_of_lk (bits : ℕ) (hw : (tagW bits, bits) ∈ fams ∨ 16 < bits) (h16 : (tagW 16, 16) ∈ fams)
    (hhi : 16 < bits → (tagW (bits - 16), bits - 16) ∈ fams) (lo hi : GF)
    (h : ∀ q ∈ remLk bits lo hi, CodeTable fams exp act nG q) : RemW16 bits (remVal bits lo hi) := by
  unfold RemW16 remVal
  unfold remLk at h
  by_cases hb : bits ≤ 16
  · rw [ite_eq_left hb, ite_eq_left hb]
    rw [ite_eq_left hb] at h
    have hm : (tagW bits, bits) ∈ fams := hw.resolve_right (by omega)
    exact (codeTable_range_iff hF exp act nG hm _).mp (h _ (by simp))
  · rw [ite_eq_right hb, ite_eq_right hb]
    rw [ite_eq_right hb] at h
    exact ⟨lo, hi, rfl, (codeTable_range_iff hF exp act nG h16 _).mp (h _ (by simp)),
      (codeTable_range_iff hF exp act nG (hhi (by omega)) _).mp (h _ (by simp))⟩

/-- `range16::word24(word, top, 2^23)`: `word − 2^16·top` in family 16 and `top + 128` a byte. -/
theorem word24_of_lk (h16 : (tagW 16, 16) ∈ fams) (h8 : (tagW 8, 8) ∈ fams) (x top : GF)
    (h1 : CodeTable fams exp act nG (rangeQuery (tagW 16) (x - 2 ^ 16 * top)))
    (h2 : CodeTable fams exp act nG (rangeQuery (tagW 8) (top + 128))) : Word24 x :=
  ⟨top, (codeTable_range_iff hF exp act nG h16 _).mp h1, (codeTable_range_iff hF exp act nG h8 _).mp h2⟩

/-- The int8 score's two byte queries (accuracy_layout.rs:328-329). -/
theorem wordS8_of_lk (h8 : (tagW 8, 8) ∈ fams) (x : GF)
    (h1 : CodeTable fams exp act nG (rangeQuery (tagW 8) (x + 127)))
    (h2 : CodeTable fams exp act nG (rangeQuery (tagW 8) (-x + 127))) : WordS8 x :=
  ⟨(codeTable_range_iff hF exp act nG h8 _).mp h1, (codeTable_range_iff hF exp act nG h8 _).mp h2⟩

/-- A direct `bits`-bit lookup (`range16::direct`, the softmax quotient). -/
theorem direct_of_lk (bits : ℕ) (hm : (tagW bits, bits) ∈ fams) (x : GF)
    (h : CodeTable fams exp act nG (rangeQuery (tagW bits) x)) : InRange bits x :=
  (codeTable_range_iff hF exp act nG hm _).mp h

/-- The isqrt's three byte limbs (`SC_LZC`'s byte lookups of `A_LIMB`) and the clause `d − Σ 256^k·limb_k = 0`
(`SC_TZC`, argument.rs:2094) give `InRange 24` (`threeBytes_iff`). -/
theorem bytes24_of_lk (h8 : (tagW 8, 8) ∈ fams) (d : GF) (b : Fin 3 → GF)
    (hcl : d - (b 0 + 2 ^ 8 * b 1 + 2 ^ 16 * b 2) = 0)
    (h : ∀ k, CodeTable fams exp act nG (rangeQuery (tagW 8) (b k))) : InRange 24 d :=
  (threeBytes_iff d).mp ⟨b 0, b 1, b 2, sub_eq_zero.mp hcl, (codeTable_range_iff hF exp act nG h8 _).mp (h 0),
    (codeTable_range_iff hF exp act nG h8 _).mp (h 1), (codeTable_range_iff hF exp act nG h8 _).mp (h 2)⟩

end Lookups

/-! ## The W16R2 layout map -/

/-- **The layout map of one W16R2 block**: an axis per logical index set, the head-slot order (C-1: a query head's
slot is its key-value group's bits on top of its index within the group), the RoPE flip of the head dimension. -/
structure W16Layout (S : BlockShape) (Ct Cw Cg Cj Cd Cf : Type) where
  tok : Ax S.Tok Ct
  wid : Ax S.Wid Cw
  grp : Ax (Fin S.G) Cg
  /-- a query head's index within its key-value group (the low bits of its slot) -/
  within : Fin S.H → Cj
  hd : Ax S.HD Cd
  hid : Ax S.Hid Cf
  /-- distinct query heads have distinct slots (C-1 is a permutation) -/
  slot_inj : Function.Injective (fun h : Fin S.H => (grp.emb (S.grp h), within h))
  /-- the head dimension's top-bit flip on the cube (`Coord::Flip`) -/
  flip : Cd → Cd
  hd_flip : ∀ (b : Bool) (k : Fin S.half), hd.emb (!b, k) = flip (hd.emb (b, k))

namespace W16Layout

variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} (L : W16Layout S Ct Cw Cg Cj Cd Cf)

/-- A query head's slot (C-1). -/
def slot (h : Fin S.H) : Cg × Cj := (L.grp.emb (S.grp h), L.within h)
/-- `Dom::D`'s position of `(t, i)`. -/
def dPos (p : S.Pos) : Ct × Cw := (L.tok.emb p.1, L.wid.emb p.2)
/-- `Dom::Q`'s position of `(t, (h, c))`: the head's slot, then the head dimension. -/
def qPos (p : S.Tok × S.QC) : Ct × ((Cg × Cj) × Cd) := (L.tok.emb p.1, (L.slot p.2.1, L.hd.emb p.2.2))
/-- `Dom::Kv`'s position of `(t, (g, c))`. -/
def kPos (p : S.Tok × S.KC) : Ct × (Cg × Cd) := (L.tok.emb p.1, (L.grp.emb p.2.1, L.hd.emb p.2.2))
/-- `Dom::S`'s position of `(h, t, j)`. -/
def sPos (p : Fin S.H × S.Tok × S.Tok) : (Cg × Cj) × Ct × Ct := (L.slot p.1, L.tok.emb p.2.1, L.tok.emb p.2.2)
/-- `Dom::Ht`'s position of `(h, t)`. -/
def htPos (r : Fin S.H × S.Tok) : (Cg × Cj) × Ct := (L.slot r.1, L.tok.emb r.2)
/-- `Dom::F`'s position of `(t, f)`. -/
def fPos (p : S.Tok × S.Hid) : Ct × Cf := (L.tok.emb p.1, L.hid.emb p.2)

end W16Layout

/-- A committed remainder: its 16-bit limb planes (the top limb unused below 17 bits). -/
structure RemP (C : Type) where
  lo : C → GF
  hi : C → GF

/-- **The extracted planes of one W16R2 block** on the committed cube (`A` planes, read as the extractor reads
them; the isqrt byte limbs on `Dom::L`'s sub-planes, indexed by row). -/
structure W16Data (Ct Cw Cg Cj Cd Cf : Type) where
  dA : Ct → GF
  dsqA : Ct → GF
  dM : Ct → GF
  dsqM : Ct → GF
  /-- the isqrt limbs of norm_a: `[d, a1, a2]` × three bytes; and of norm_m -/
  la : Fin 3 → Fin 3 → Ct → GF
  lm : Fin 3 → Fin 3 → Ct → GF
  X : Ct × Cw → GF
  Y : Ct × Cw → GF
  AO : Ct × Cw → GF
  X1 : Ct × Cw → GF
  YM : Ct × Cw → GF
  Z : Ct × Cw → GF
  X2 : Ct × Cw → GF
  nr : RemP (Ct × Cw)
  ns : RemP (Ct × Cw)
  mr : RemP (Ct × Cw)
  ms : RemP (Ct × Cw)
  rao : RemP (Ct × Cw)
  rd : RemP (Ct × Cw)
  Q : Ct × ((Cg × Cj) × Cd) → GF
  QR : Ct × ((Cg × Cj) × Cd) → GF
  O : Ct × ((Cg × Cj) × Cd) → GF
  rq : RemP (Ct × ((Cg × Cj) × Cd))
  rqr : RemP (Ct × ((Cg × Cj) × Cd))
  ro : RemP (Ct × ((Cg × Cj) × Cd))
  K : Ct × (Cg × Cd) → GF
  KR : Ct × (Cg × Cd) → GF
  V : Ct × (Cg × Cd) → GF
  rk : RemP (Ct × (Cg × Cd))
  rkr : RemP (Ct × (Cg × Cd))
  rv : RemP (Ct × (Cg × Cd))
  S8 : (Cg × Cj) × Ct × Ct → GF
  ZSEL : (Cg × Cj) × Ct × Ct → GF
  E : (Cg × Cj) × Ct × Ct → GF
  PP : (Cg × Cj) × Ct × Ct → GF
  rs : RemP ((Cg × Cj) × Ct × Ct)
  sr : RemP ((Cg × Cj) × Ct × Ct)
  sg : RemP ((Cg × Cj) × Ct × Ct)
  MX : (Cg × Cj) × Ct → GF
  SUM : (Cg × Cj) × Ct → GF
  G : Ct × Cf → GF
  A : Ct × Cf → GF
  U : Ct × Cf → GF
  H : Ct × Cf → GF
  Htop : Ct × Cf → GF
  rg : RemP (Ct × Cf)
  ru : RemP (Ct × Cf)
  rh : RemP (Ct × Cf)

/-- **The public tables and gates the verifier builds, read through the layout** (each a construction of the code,
cited): the support gates (`1` on the logical positions, `0` on the pad: `pad::indicator_table`; the constant `1` where
the domain does not pad), the norm gains on the padded width (`gamma_a`, `gamma_m`, argument_accuracy.rs:468-469), the
RoPE tables (`rope_tables_at`, :544), the causal mask (`causal_mask_at`), the activation group column
(`accuracy_act::group_column`), and the seven folded weight matrices with their multipliers (`accuracy_fold::fold`,
argument.rs:2173-2183, 2314-2324), the padded entries zero. -/
structure W16Pub (S : BlockShape) (P : BlockPublic S) {Ct Cw Cg Cj Cd Cf : Type} (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    where
  gT : Ct → GF
  gD : Ct × Cw → GF
  gQ : Ct × ((Cg × Cj) × Cd) → GF
  gK : Ct × (Cg × Cd) → GF
  gS : (Cg × Cj) × Ct × Ct → GF
  gHt : (Cg × Cj) × Ct → GF
  gF : Ct × Cf → GF
  gT_one : ∀ t, gT (L.tok.emb t) = 1
  gD_one : ∀ p, gD (L.dPos p) = 1
  gQ_one : ∀ p, gQ (L.qPos p) = 1
  gK_one : ∀ p, gK (L.kPos p) = 1
  gS_one : ∀ p, gS (L.sPos p) = 1
  gHt_one : ∀ r, gHt (L.htPos r) = 1
  gF_one : ∀ p, gF (L.fPos p) = 1
  /-- the norm's row sum runs over the true columns only (S9-F8: `SC_SS`'s summand takes `supp_D`) -/
  gD_pad : ∀ t c, (∀ i, L.wid.emb i ≠ c) → gD (t, c) = 0
  /-- the softmax row sums run over the true columns only (`SC_RS`'s summand takes `supp_S`) -/
  gS_pad : ∀ s t j, (∀ i, L.tok.emb i ≠ j) → gS (s, t, j) = 0
  gamA : Ct × Cw → GF
  gamM : Ct × Cw → GF
  gamA_emb : ∀ p, gamA (L.dPos p) = (P.gA p.2 : GF)
  gamM_emb : ∀ p, gamM (L.dPos p) = (P.gM p.2 : GF)
  cosT : Ct × ((Cg × Cj) × Cd) → GF
  sinT : Ct × ((Cg × Cj) × Cd) → GF
  cosT_emb : ∀ p, cosT (L.qPos p) = (P.cos p.1 p.2.2.2 : GF)
  sinT_emb : ∀ p, sinT (L.qPos p) = ((ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 : ℤ) : GF)
  cosK : Ct × (Cg × Cd) → GF
  sinK : Ct × (Cg × Cd) → GF
  cosK_emb : ∀ p, cosK (L.kPos p) = (P.cos p.1 p.2.2.2 : GF)
  sinK_emb : ∀ p, sinK (L.kPos p) = ((ropeSgn p.2.2.1 * P.sin p.1 p.2.2.2 : ℤ) : GF)
  mask : (Cg × Cj) × Ct × Ct → GF
  mask_emb : ∀ p, mask (L.sPos p) = maskF p.2.1 p.2.2
  grpCol : Ct × Cf → GF
  grpCol_emb : ∀ p, grpCol (L.fPos p) = (P.grpF p.2 : GF)
  /-- the folded weights with their multipliers, `(input, output)`; the padded entries zero -/
  Wq : Cw → (Cg × Cj) × Cd → GF
  Wk : Cw → Cg × Cd → GF
  Wv : Cw → Cg × Cd → GF
  Wo : (Cg × Cj) × Cd → Cw → GF
  Wg : Cw → Cf → GF
  Wu : Cw → Cf → GF
  Wd : Cf → Cw → GF
  Wq_emb : ∀ i (c : S.QC), Wq (L.wid.emb i) (L.slot c.1, L.hd.emb c.2) = ((P.wq i c * (P.mq c : ℤ) : ℤ) : GF)
  Wk_emb : ∀ i (c : S.KC), Wk (L.wid.emb i) (L.grp.emb c.1, L.hd.emb c.2) = ((P.wk i c * (P.mK c : ℤ) : ℤ) : GF)
  Wv_emb : ∀ i (c : S.KC), Wv (L.wid.emb i) (L.grp.emb c.1, L.hd.emb c.2) = ((P.wv i c * (P.mv c : ℤ) : ℤ) : GF)
  Wo_emb : ∀ (c : S.QC) j, Wo (L.slot c.1, L.hd.emb c.2) (L.wid.emb j) = ((P.wo c j * (P.mo j : ℤ) : ℤ) : GF)
  Wg_emb : ∀ i f, Wg (L.wid.emb i) (L.hid.emb f) = ((P.wg i f * (P.mg f : ℤ) : ℤ) : GF)
  Wu_emb : ∀ i f, Wu (L.wid.emb i) (L.hid.emb f) = ((P.wu i f * (P.mu f : ℤ) : ℤ) : GF)
  Wd_emb : ∀ f j, Wd (L.hid.emb f) (L.wid.emb j) = ((P.wd f j * (P.md j : ℤ) : ℤ) : GF)
  Wq_pad : ∀ c j, (∀ i, L.wid.emb i ≠ c) → Wq c j = 0
  Wk_pad : ∀ c j, (∀ i, L.wid.emb i ≠ c) → Wk c j = 0
  Wv_pad : ∀ c j, (∀ i, L.wid.emb i ≠ c) → Wv c j = 0
  Wo_pad : ∀ c j, (∀ q : S.QC, (L.slot q.1, L.hd.emb q.2) ≠ c) → Wo c j = 0
  Wg_pad : ∀ c j, (∀ i, L.wid.emb i ≠ c) → Wg c j = 0
  Wu_pad : ∀ c j, (∀ i, L.wid.emb i ≠ c) → Wu c j = 0
  Wd_pad : ∀ c j, (∀ f, L.hid.emb f ≠ c) → Wd c j = 0

/-- **The slots' relations on the cube** (what the 23 accepted slots establish about the extracted planes: the
gated clauses of each zero-check, its ungated LogUp arms are LogUp's, the hosted identities of the private slots,
the pad rule's zero planes). Each field cites its clause. -/
structure W16Rels (S : BlockShape) {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
    [Fintype Cd] [Fintype Cf] (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : Prop where
  /-- `SC_TZC`'s six clauses (argument.rs:2094-2095), ungated: `dsq = d²`, `d = Σ limbs`, `2d = a1 + a2` -/
  tzc_sq : ∀ t, E.dsqA t - E.dA t * E.dA t = 0
  tzc_d : ∀ t, E.dA t - (E.la 0 0 t + 2 ^ 8 * E.la 0 1 t + 2 ^ 16 * E.la 0 2 t) = 0
  tzc_a : ∀ t, 2 * E.dA t - (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t)
    - (E.la 2 0 t + 2 ^ 8 * E.la 2 1 t + 2 ^ 16 * E.la 2 2 t) = 0
  tzc_sqm : ∀ t, E.dsqM t - E.dM t * E.dM t = 0
  tzc_dm : ∀ t, E.dM t - (E.lm 0 0 t + 2 ^ 8 * E.lm 0 1 t + 2 ^ 16 * E.lm 0 2 t) = 0
  tzc_am : ∀ t, 2 * E.dM t - (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t)
    - (E.lm 2 0 t + 2 ^ 8 * E.lm 2 1 t + 2 ^ 16 * E.lm 2 2 t) = 0
  /-- `SC_TZC` hosting `SC_SS` / `SC_SSM` (2099-2100): `gT·(dsq + a1 − ceps)` is the gated row sum of squares -/
  ss : ∀ t, B.gT t * (E.dsqA t + (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t) - (S.ceps : GF))
    = ∑ c, B.gD (t, c) * E.X (t, c) * E.X (t, c)
  ssm : ∀ t, B.gT t * (E.dsqM t + (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t) - (S.ceps : GF))
    = ∑ c, B.gD (t, c) * E.X1 (t, c) * E.X1 (t, c)
  /-- `dzc_w16`'s six clauses (argument_accuracy.rs:490-493), gated by `supp_D` -/
  d0 : ∀ x, B.gD x * (B.gamA x * E.X x * (2 * (S.cnA : GF)) + E.dA x.1 * 2 ^ S.tn
    - 2 ^ (S.tn + 1) * E.dA x.1 * E.Y x - remVal 24 (E.nr.lo x) (E.nr.hi x)) = 0
  d1 : ∀ x, B.gD x * (remVal 24 (E.nr.lo x) (E.nr.hi x) + remVal 24 (E.ns.lo x) (E.ns.hi x) + 1
    - 2 ^ (S.tn + 1) * E.dA x.1) = 0
  d2 : ∀ x, B.gD x * (E.X1 x - E.X x - E.AO x) = 0
  d3 : ∀ x, B.gD x * (B.gamM x * E.X1 x * (2 * (S.cnM : GF)) + E.dM x.1 * 2 ^ S.tn
    - 2 ^ (S.tn + 1) * E.dM x.1 * E.YM x - remVal 24 (E.mr.lo x) (E.mr.hi x)) = 0
  d4 : ∀ x, B.gD x * (remVal 24 (E.mr.lo x) (E.mr.hi x) + remVal 24 (E.ms.lo x) (E.ms.hi x) + 1
    - 2 ^ (S.tn + 1) * E.dM x.1) = 0
  d5 : ∀ x, B.gD x * (E.X2 x - E.X1 x - E.Z x) = 0
  /-- `dzc_w16`'s hosts (496-497) = `SC_WO` and `SC_DMM`'s contractions -/
  wo : ∀ x, B.gD x * (2 ^ S.sao * E.AO x + remVal S.sao (E.rao.lo x) (E.rao.hi x) - 2 ^ (S.sao - 1))
    = ∑ c, E.O (x.1, c) * B.Wo c x.2
  dmm : ∀ x, B.gD x * (2 ^ S.sdown * E.Z x + remVal S.sdown (E.rd.lo x) (E.rd.hi x) - 2 ^ (S.sdown - 1))
    = ∑ c, E.H (x.1, c) * B.Wd c x.2
  /-- `qzc_w16` on `Dom::Q` (560-564): the RoPE clause, gated; hosts `SC_QMM` and `SC_PV` -/
  qrope : ∀ x, B.gQ x * (B.cosT x * E.Q x + B.sinT x * E.Q (x.1, (x.2.1, L.flip x.2.2)) - 2 ^ 7 * E.QR x
    - remVal 7 (E.rqr.lo x) (E.rqr.hi x) + 2 ^ 6) = 0
  qmm : ∀ x, B.gQ x * (2 ^ S.sq * E.Q x + remVal S.sq (E.rq.lo x) (E.rq.hi x) - 2 ^ (S.sq - 1))
    = ∑ c, E.Y (x.1, c) * B.Wq c x.2
  pv : ∀ x, B.gQ x * (2 ^ S.spv * E.O x + remVal S.spv (E.ro.lo x) (E.ro.hi x) - 2 ^ (S.spv - 1))
    = ∑ j, E.PP (x.2.1, x.1, j) * E.V (j, (x.2.1.1, x.2.2))
  /-- `qzc_w16` on `Dom::Kv`: the RoPE clause; hosts `SC_KMM` and `SC_VMM` -/
  krope : ∀ x, B.gK x * (B.cosK x * E.K x + B.sinK x * E.K (x.1, (x.2.1, L.flip x.2.2)) - 2 ^ 7 * E.KR x
    - remVal 7 (E.rkr.lo x) (E.rkr.hi x) + 2 ^ 6) = 0
  kmm : ∀ x, B.gK x * (2 ^ S.sk * E.K x + remVal S.sk (E.rk.lo x) (E.rk.hi x) - 2 ^ (S.sk - 1))
    = ∑ c, E.Y (x.1, c) * B.Wk c x.2
  vmm : ∀ x, B.gK x * (2 ^ S.sv * E.V x + remVal S.sv (E.rv.lo x) (E.rv.hi x) - 2 ^ (S.sv - 1))
    = ∑ c, E.Y (x.1, c) * B.Wv c x.2
  /-- `szc_w16` (624-631): the four softmax clauses, gated by `supp_S` (`δ = mx − mask·(s8 + 127) + 127`) -/
  s0 : ∀ x, B.gS x * (E.ZSEL x * E.ZSEL x - E.ZSEL x) = 0
  s1 : ∀ x, B.gS x * (E.ZSEL x * (E.MX (x.1, x.2.1) - B.mask x * (E.S8 x + 127) + 127)) = 0
  s2 : ∀ x, B.gS x * (B.mask x * E.E x * 2 ^ S.fp - E.PP x * E.SUM (x.1, x.2.1)
    - remVal S.wrho (E.sr.lo x) (E.sr.hi x)) = 0
  s3 : ∀ x, B.gS x * (remVal S.wrho (E.sg.lo x) (E.sg.hi x) + remVal S.wrho (E.sr.lo x) (E.sr.hi x) + 1
    - E.SUM (x.1, x.2.1)) = 0
  /-- `SC_RS`'s two row sums (argument.rs:2135-2148; `SlotW16Sound.dens_rowsum` splits the `λ`-batched claim),
  hosted by `szc_w16`'s `host_rs` with `supp_Ht` -/
  rsE : ∀ r, B.gHt r * E.SUM r = ∑ j, B.gS (r.1, r.2, j) * (B.mask (r.1, r.2, j) * E.E (r.1, r.2, j))
  rsZ : ∀ r, B.gHt r = ∑ j, B.gS (r.1, r.2, j) * E.ZSEL (r.1, r.2, j)
  /-- `szc_w16`'s `host_s` = `SC_SCORE`'s contraction (the group summed, argument.rs:2231-2266) -/
  score : ∀ x, B.gS x * (2 ^ S.ss * E.S8 x + remVal S.ss (E.rs.lo x) (E.rs.hi x) - 2 ^ (S.ss - 1))
    = ∑ c, E.QR (x.2.1, (x.1, c)) * E.KR (x.2.2, (x.1.1, c))
  /-- `fzc_w16` (526-531): the product clause, gated; hosts `SC_GMM` and `SC_UMM` -/
  f0 : ∀ x, B.gF x * (E.A x * E.U x - 2 ^ S.sprod * E.H x - remVal S.sprod (E.rh.lo x) (E.rh.hi x)
    + 2 ^ (S.sprod - 1)) = 0
  gmm : ∀ x, B.gF x * (2 ^ S.sgate * E.G x + remVal S.sgate (E.rg.lo x) (E.rg.hi x) - 2 ^ (S.sgate - 1))
    = ∑ c, E.YM (x.1, c) * B.Wg c x.2
  umm : ∀ x, B.gF x * (2 ^ S.sup * E.U x + remVal S.sup (E.ru.lo x) (E.ru.hi x) - 2 ^ (S.sup - 1))
    = ∑ c, E.YM (x.1, c) * B.Wu c x.2
  /-- the pad rule's zero planes used by the contractions over padded axes (PV over source tokens, SCORE over the
  head dimension): the quotient `P` and the rotated keys vanish on the pad -/
  pp_pad : ∀ s t j, (∀ i, L.tok.emb i ≠ j) → E.PP (s, t, j) = 0
  kr_pad : ∀ j g c, (∀ e, L.hd.emb e ≠ c) → E.KR (j, (g, c)) = 0

/-- **LogUp's conclusion at every logical position** (the W16R2 lookup list, `lookups_w16`): each looked-up tuple is a
tuple of the block's table `CodeTable fams exp act nG`. Domain by domain, in the code's order. -/
structure W16Lookups (S : BlockShape) {Ct Cw Cg Cj Cd Cf : Type} (P : BlockPublic S)
    (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) (E : W16Data Ct Cw Cg Cj Cd Cf) (fams : List (ℕ × ℕ)) :
    Prop where
  /-- `Dom::L`: the isqrt bytes (`Lk::u8` of `A_LIMB`, `A_LIMBM`) -/
  la : ∀ t i k, CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.la i k (L.tok.emb t)))
  lm : ∀ t i k, CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.lm i k (L.tok.emb t)))
  /-- `Dom::D`: the seven words and the six remainders -/
  dW : ∀ p, ∀ w ∈ [E.X, E.Y, E.AO, E.X1, E.YM, E.Z, E.X2],
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (w (L.dPos p) + 32768))
  dR : ∀ p, (∀ q ∈ remLk 24 (E.nr.lo (L.dPos p)) (E.nr.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk 24 (E.ns.lo (L.dPos p)) (E.ns.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk 24 (E.mr.lo (L.dPos p)) (E.mr.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk 24 (E.ms.lo (L.dPos p)) (E.ms.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk S.sao (E.rao.lo (L.dPos p)) (E.rao.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk S.sdown (E.rd.lo (L.dPos p)) (E.rd.hi (L.dPos p)), CodeTable fams P.exp P.act S.nG q)
  /-- `Dom::Q`: `Q`, `QR`, `O` and their remainders -/
  qW : ∀ p, ∀ w ∈ [E.Q, E.QR, E.O], CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (w (L.qPos p) + 32768))
  qR : ∀ p, (∀ q ∈ remLk S.sq (E.rq.lo (L.qPos p)) (E.rq.hi (L.qPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk 7 (E.rqr.lo (L.qPos p)) (E.rqr.hi (L.qPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk S.spv (E.ro.lo (L.qPos p)) (E.ro.hi (L.qPos p)), CodeTable fams P.exp P.act S.nG q)
  /-- `Dom::Kv`: `K`, `V`, `KR` and their remainders -/
  kW : ∀ p, ∀ w ∈ [E.K, E.V, E.KR], CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (w (L.kPos p) + 32768))
  kR : ∀ p, (∀ q ∈ remLk S.sk (E.rk.lo (L.kPos p)) (E.rk.hi (L.kPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk S.sv (E.rv.lo (L.kPos p)) (E.rv.hi (L.kPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk 7 (E.rkr.lo (L.kPos p)) (E.rkr.hi (L.kPos p)), CodeTable fams P.exp P.act S.nG q)
  /-- `Dom::S`: the score's two bytes, its remainder, `P` direct, the two slacks; and the exp tuple (the `ihx`
  helper's single lookup, `cx`, argument_accuracy.rs:631) -/
  sB : ∀ p, CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.S8 (L.sPos p) + 127)) ∧
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 8) (-E.S8 (L.sPos p) + 127))
  sR : ∀ p, (∀ q ∈ remLk S.ss (E.rs.lo (L.sPos p)) (E.rs.hi (L.sPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW (S.fp + 1)) (E.PP (L.sPos p))) ∧
    (∀ q ∈ remLk S.wrho (E.sr.lo (L.sPos p)) (E.sr.hi (L.sPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    (∀ q ∈ remLk S.wrho (E.sg.lo (L.sPos p)) (E.sg.hi (L.sPos p)), CodeTable fams P.exp P.act S.nG q)
  sExp : ∀ p, CodeTable fams P.exp P.act S.nG
    (expQuery (E.MX (L.slot p.1, L.tok.emb p.2.1) - B.mask (L.sPos p) * (E.S8 (L.sPos p) + 127) + 127) (E.E (L.sPos p)))
  /-- `Dom::F`: the gate's remainder, `U`, its remainder, the 24-bit product word (`word24`), its remainder; and the
  ACT tuple (the `fact` helper's single lookup, `fa`, :528) -/
  fR : ∀ p, (∀ q ∈ remLk S.sgate (E.rg.lo (L.fPos p)) (E.rg.hi (L.fPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (E.U (L.fPos p) + 32768)) ∧
    (∀ q ∈ remLk S.sup (E.ru.lo (L.fPos p)) (E.ru.hi (L.fPos p)), CodeTable fams P.exp P.act S.nG q) ∧
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (E.H (L.fPos p) - 2 ^ 16 * E.Htop (L.fPos p))) ∧
    CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.Htop (L.fPos p) + 128)) ∧
    (∀ q ∈ remLk S.sprod (E.rh.lo (L.fPos p)) (E.rh.hi (L.fPos p)), CodeTable fams P.exp P.act S.nG q)
  fAct : ∀ p, CodeTable fams P.exp P.act S.nG (actQuery (E.G (L.fPos p)) (E.A (L.fPos p)) (P.grpF p.2))

/-- The widths the W16R2 lookups use are families of `fams` (a decidable fact of the shape's shifts and `fams`; at 8B,
`range16::widths`). -/
structure W16Widths (S : BlockShape) (fams : List (ℕ × ℕ)) : Prop where
  w8 : (tagW 8, 8) ∈ fams
  w16 : (tagW 16, 16) ∈ fams
  w7 : (tagW 7, 7) ∈ fams
  wP : (tagW (S.fp + 1), S.fp + 1) ∈ fams
  /-- every remainder width: its own family below 17 bits, its top limb's family above -/
  rem : ∀ b ∈ [24, S.sao, S.sdown, S.sq, S.spv, S.sk, S.sv, S.ss, S.wrho, S.sgate, S.sup, S.sprod],
    ((tagW b, b) ∈ fams ∨ 16 < b) ∧ (16 < b → (tagW (b - 16), b - 16) ∈ fams)

/-! ## The witness through the layout map -/

/-- **The extracted planes read at the logical positions** (the layout map), as CircuitBlock's witness. -/
def toWit {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (E : W16Data Ct Cw Cg Cj Cd Cf) : BlockWit S where
  dA t := E.dA (L.tok.emb t)
  Y p := E.Y (L.dPos p)
  Q p := E.Q (L.qPos p)
  K p := E.K (L.kPos p)
  V p := E.V (L.kPos p)
  QR p := E.QR (L.qPos p)
  KR p := E.KR (L.kPos p)
  S8 p := E.S8 (L.sPos p)
  MX r := E.MX (L.htPos r)
  SUM r := E.SUM (L.htPos r)
  ZSEL p := E.ZSEL (L.sPos p)
  E p := E.E (L.sPos p)
  PP p := E.PP (L.sPos p)
  O p := E.O (L.qPos p)
  AO p := E.AO (L.dPos p)
  X1 p := E.X1 (L.dPos p)
  dM t := E.dM (L.tok.emb t)
  YM p := E.YM (L.dPos p)
  Gt p := E.G (L.fPos p)
  Ac p := E.A (L.fPos p)
  U p := E.U (L.fPos p)
  Hh p := E.H (L.fPos p)
  Z p := E.Z (L.dPos p)

/-! ## The block, assembled -/

variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
theorem flip_qPos (L : W16Layout S Ct Cw Cg Cj Cd Cf) (p : S.Tok × S.QC) :
    L.qPos (flipQ p) = ((L.qPos p).1, ((L.qPos p).2.1, L.flip (L.qPos p).2.2)) := by
  simp only [W16Layout.qPos, flipQ, L.hd_flip]

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
theorem flip_kPos (L : W16Layout S Ct Cw Cg Cj Cd Cf) (p : S.Tok × S.KC) :
    L.kPos (flipK p) = ((L.kPos p).1, ((L.kPos p).2.1, L.flip (L.kPos p).2.2)) := by
  simp only [W16Layout.kPos, flipK, L.hd_flip]

/-- `HostRel` from a host identity at a position whose gate is `1`. -/
theorem hostRel_of (s : ℕ) (g q R a : GF) (hg : g = 1) (h : g * (2 ^ s * q + R - 2 ^ (s - 1)) = a) :
    HostRel s a q R := by
  unfold HostRel
  rw [hg, one_mul] at h
  exact h

/-- **The layout map's theorem: the slots' relations and LogUp's conclusion give `BlockSat`.** For one W16R2 block at
the LowH24 stack (`S.h24`, the product word `Word24`), the extracted planes `E` read through the layout map `L`
satisfy CircuitBlock's constraint system at every logical position, with input plane `X ∘ dPos` and output plane
`X2 ∘ dPos`; the premise of `block_circuitIff`. -/
theorem blockSat_of_slots (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L)
    (E : W16Data Ct Cw Cg Cj Cd Cf) (fams : List (ℕ × ℕ)) (hF : FamsOK fams) (hW : W16Widths S fams)
    (h24 : S.h24 = true)
    (R : W16Rels S P L B E) (Lk : W16Lookups S P L B E fams) :
    BlockSat P (fun p => E.X (L.dPos p)) (fun p => E.X2 (L.dPos p)) (toWit L E) := by
  -- the remainder facts
  have rem : ∀ (b : ℕ), b ∈ [24, S.sao, S.sdown, S.sq, S.spv, S.sk, S.sv, S.ss, S.wrho, S.sgate, S.sup, S.sprod] →
      ∀ lo hi : GF, (∀ q ∈ remLk b lo hi, CodeTable fams P.exp P.act S.nG q) → RemW16 b (remVal b lo hi) :=
    fun b hb lo hi h => remW16_of_lk hF P.exp P.act S.nG b (hW.rem b hb).1 hW.w16 (hW.rem b hb).2 lo hi h
  have rem7 : ∀ lo hi : GF, (∀ q ∈ remLk 7 lo hi, CodeTable fams P.exp P.act S.nG q) → RemW16 7 (remVal 7 lo hi) :=
    fun lo hi h => remW16_of_lk hF P.exp P.act S.nG 7 (Or.inl hW.w7) hW.w16 (fun h => absurd h (by norm_num)) lo hi h
  have w16 : ∀ x : GF, CodeTable fams P.exp P.act S.nG (rangeQuery (tagW 16) (x + 32768)) → Word16 x :=
    fun x h => word16_of_lk hF P.exp P.act S.nG hW.w16 x h
  refine ⟨?inX, ?normA, ?q, ?k, ?v, ?qr, ?kr, ?score, ?softmax, ?pv, ?ao, ?res1, ?normM, ?gate, ?up, ?prod, ?down,
    ?res2⟩
  case inX => exact fun p => w16 _ (Lk.dW p _ (by simp))
  case normA =>
    intro t
    refine ⟨⟨E.dsqA (L.tok.emb t), E.la 1 0 (L.tok.emb t) + 2 ^ 8 * E.la 1 1 (L.tok.emb t) + 2 ^ 16 * E.la 1 2 (L.tok.emb t),
      E.la 2 0 (L.tok.emb t) + 2 ^ 8 * E.la 2 1 (L.tok.emb t) + 2 ^ 16 * E.la 2 2 (L.tok.emb t), ⟨?_, ?_, ?_⟩, ?_, ?_, ?_⟩,
      fun i => ⟨⟨remVal 24 (E.nr.lo (L.dPos (t, i))) (E.nr.hi (L.dPos (t, i))),
        remVal 24 (E.ns.lo (L.dPos (t, i))) (E.ns.hi (L.dPos (t, i))), ⟨?_, ?_⟩, ?_, ?_⟩, ?_⟩⟩
    · exact R.tzc_sq _
    · have := R.tzc_a (L.tok.emb t)
      show 2 * E.dA (L.tok.emb t) - _ - _ = 0
      linear_combination this
    · have h := R.ss (L.tok.emb t)
      rw [B.gT_one, one_mul, sum_emb L.wid _ (fun c hc => by rw [B.gD_pad _ c hc, zero_mul, zero_mul])] at h
      show _ = ((S.ceps : GF) + ∑ i, E.X (L.dPos (t, i)) * E.X (L.dPos (t, i)))
      have h' : ∑ i, B.gD (L.tok.emb t, L.wid.emb i) * E.X (L.tok.emb t, L.wid.emb i) * E.X (L.tok.emb t, L.wid.emb i)
          = ∑ i, E.X (L.dPos (t, i)) * E.X (L.dPos (t, i)) := by
        refine sum_congr rfl fun i _ => ?_
        have := B.gD_one (t, i)
        simp only [W16Layout.dPos] at this ⊢
        rw [this, one_mul]
      rw [h'] at h
      linear_combination h
    · exact bytes24_of_lk hF P.exp P.act S.nG hW.w8 _ (fun k => E.la 0 k (L.tok.emb t)) (R.tzc_d _)
        (fun k => Lk.la t 0 k)
    · exact (threeBytes_iff _).mp ⟨_, _, _, rfl, (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 1 0),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 1 1),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 1 2)⟩
    · exact (threeBytes_iff _).mp ⟨_, _, _, rfl, (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 2 0),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 2 1),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.la t 2 2)⟩
    · have := gated_at _ _ R.d0 _ (B.gD_one (t, i))
      rw [B.gamA_emb] at this
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · have := gated_at _ _ R.d1 _ (B.gD_one (t, i))
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · exact rem 24 (by simp) _ _ (Lk.dR (t, i)).1
    · exact rem 24 (by simp) _ _ (Lk.dR (t, i)).2.1
    · exact w16 _ (Lk.dW (t, i) _ (by simp))
  case q =>
    intro p
    refine ⟨remVal S.sq (E.rq.lo (L.qPos p)) (E.rq.hi (L.qPos p)), ?_, w16 _ (Lk.qW p _ (by simp)),
      rem S.sq (by simp) _ _ (Lk.qR p).1⟩
    refine hostRel_of _ _ _ _ _ (B.gQ_one p) ((R.qmm (L.qPos p)).trans ?_)
    rw [sum_emb L.wid _ (fun c hc => by rw [B.Wq_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun i _ => ?_
    simp only [W16Layout.qPos, toWit, W16Layout.dPos]
    rw [B.Wq_emb]
  case k =>
    intro p
    refine ⟨remVal S.sk (E.rk.lo (L.kPos p)) (E.rk.hi (L.kPos p)), ?_, w16 _ (Lk.kW p _ (by simp)),
      rem S.sk (by simp) _ _ (Lk.kR p).1⟩
    refine hostRel_of _ _ _ _ _ (B.gK_one p) ((R.kmm (L.kPos p)).trans ?_)
    rw [sum_emb L.wid _ (fun c hc => by rw [B.Wk_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun i _ => ?_
    simp only [W16Layout.kPos, toWit, W16Layout.dPos]
    rw [B.Wk_emb]
  case v =>
    intro p
    refine ⟨remVal S.sv (E.rv.lo (L.kPos p)) (E.rv.hi (L.kPos p)), ?_, w16 _ (Lk.kW p _ (by simp)),
      rem S.sv (by simp) _ _ (Lk.kR p).2.1⟩
    refine hostRel_of _ _ _ _ _ (B.gK_one p) ((R.vmm (L.kPos p)).trans ?_)
    rw [sum_emb L.wid _ (fun c hc => by rw [B.Wv_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun i _ => ?_
    simp only [W16Layout.kPos, toWit, W16Layout.dPos]
    rw [B.Wv_emb]
  case qr =>
    intro p
    refine ⟨remVal 7 (E.rqr.lo (L.qPos p)) (E.rqr.hi (L.qPos p)), ?_, w16 _ (Lk.qW p _ (by simp)),
      rem7 _ _ (Lk.qR p).2.1⟩
    have := gated_at _ _ R.qrope _ (B.gQ_one p)
    rw [B.cosT_emb, B.sinT_emb, ← flip_qPos] at this
    unfold RopeRel
    simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
    linear_combination this
  case kr =>
    intro p
    refine ⟨remVal 7 (E.rkr.lo (L.kPos p)) (E.rkr.hi (L.kPos p)), ?_, w16 _ (Lk.kW p _ (by simp)),
      rem7 _ _ (Lk.kR p).2.2⟩
    have := gated_at _ _ R.krope _ (B.gK_one p)
    rw [B.cosK_emb, B.sinK_emb, ← flip_kPos] at this
    unfold RopeRel
    simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
    linear_combination this
  case score =>
    intro p
    refine ⟨remVal S.ss (E.rs.lo (L.sPos p)) (E.rs.hi (L.sPos p)), ?_,
      wordS8_of_lk hF P.exp P.act S.nG hW.w8 _ (Lk.sB p).1 (Lk.sB p).2, rem S.ss (by simp) _ _ (Lk.sR p).1⟩
    refine hostRel_of _ _ _ _ _ (B.gS_one p) ((R.score (L.sPos p)).trans ?_)
    rw [sum_emb L.hd _ (fun c hc => by rw [R.kr_pad _ _ c hc, mul_zero])]
    refine sum_congr rfl fun c _ => ?_
    simp only [W16Layout.sPos, W16Layout.slot, toWit, W16Layout.qPos, W16Layout.kPos]
  case softmax =>
    intro r
    refine ⟨fun j => ?_, fun j => ?_, fun j => ?_, ?_, ?_, fun j => ⟨⟨remVal S.wrho (E.sr.lo (L.sPos (r.1, r.2, j)))
      (E.sr.hi (L.sPos (r.1, r.2, j))), remVal S.wrho (E.sg.lo (L.sPos (r.1, r.2, j))) (E.sg.hi (L.sPos (r.1, r.2, j))),
      ⟨?_, ?_⟩, rem S.wrho (by simp) _ _ (Lk.sR _).2.2.1, rem S.wrho (by simp) _ _ (Lk.sR _).2.2.2⟩,
      direct_of_lk hF P.exp P.act S.nG _ hW.wP _ (Lk.sR _).2.1⟩⟩
    · have := (codeTable_exp_iff hF P.exp P.act S.nG _ _).mp (Lk.sExp (r.1, r.2, j))
      rw [B.mask_emb] at this
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      exact this
    · have := gated_at _ _ R.s0 _ (B.gS_one (r.1, r.2, j))
      exact this
    · have := gated_at _ _ R.s1 _ (B.gS_one (r.1, r.2, j))
      rw [B.mask_emb] at this
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      exact this
    · have h := R.rsE (L.htPos r)
      rw [B.gHt_one, one_mul, sum_emb L.tok _ (fun c hc => by rw [B.gS_pad _ _ c hc, zero_mul])] at h
      refine Eq.trans ?_ h.symm
      refine sum_congr rfl fun j _ => ?_
      have hg := B.gS_one (r.1, r.2, j)
      have hm := B.mask_emb (r.1, r.2, j)
      simp only [W16Layout.sPos] at hg hm
      simp only [toWit, W16Layout.sPos, W16Layout.htPos]
      rw [hg, hm, one_mul]
    · have h := R.rsZ (L.htPos r)
      rw [B.gHt_one, sum_emb L.tok _ (fun c hc => by rw [B.gS_pad _ _ c hc, zero_mul])] at h
      refine Eq.trans ?_ h.symm
      refine sum_congr rfl fun j _ => ?_
      have hg := B.gS_one (r.1, r.2, j)
      simp only [W16Layout.sPos] at hg
      simp only [toWit, W16Layout.sPos, W16Layout.htPos]
      rw [hg, one_mul]
    · have := gated_at _ _ R.s2 _ (B.gS_one (r.1, r.2, j))
      rw [B.mask_emb] at this
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · have := gated_at _ _ R.s3 _ (B.gS_one (r.1, r.2, j))
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
  case pv =>
    intro p
    refine ⟨remVal S.spv (E.ro.lo (L.qPos p)) (E.ro.hi (L.qPos p)), ?_, w16 _ (Lk.qW p _ (by simp)),
      rem S.spv (by simp) _ _ (Lk.qR p).2.2⟩
    refine hostRel_of _ _ _ _ _ (B.gQ_one p) ((R.pv (L.qPos p)).trans ?_)
    rw [sum_emb L.tok _ (fun c hc => by rw [R.pp_pad _ _ c hc, zero_mul])]
    refine sum_congr rfl fun j _ => ?_
    simp only [W16Layout.qPos, W16Layout.slot, toWit, W16Layout.sPos, W16Layout.kPos]
  case ao =>
    intro p
    refine ⟨remVal S.sao (E.rao.lo (L.dPos p)) (E.rao.hi (L.dPos p)), ?_, w16 _ (Lk.dW p _ (by simp)),
      rem S.sao (by simp) _ _ (Lk.dR p).2.2.2.2.1⟩
    refine hostRel_of _ _ _ _ _ (B.gD_one p) ((R.wo (L.dPos p)).trans ?_)
    have hsum : ∑ c : (Cg × Cj) × Cd, E.O ((L.dPos p).1, c) * B.Wo c (L.dPos p).2
        = ∑ c : S.QC, E.O ((L.dPos p).1, (L.slot c.1, L.hd.emb c.2)) * B.Wo (L.slot c.1, L.hd.emb c.2) (L.dPos p).2 := by
      classical
      have hinj : Function.Injective (fun c : S.QC => (L.slot c.1, L.hd.emb c.2)) := by
        rintro ⟨h1, c1⟩ ⟨h2, c2⟩ he
        obtain ⟨hs, hc⟩ := Prod.ext_iff.mp he
        have hs' : L.slot h1 = L.slot h2 := hs
        exact Prod.ext (L.slot_inj hs') (L.hd.inj hc)
      exact sum_emb ⟨_, hinj⟩ _ (fun c hc => by rw [B.Wo_pad c _ hc, mul_zero])
    rw [hsum]
    refine sum_congr rfl fun c _ => ?_
    simp only [W16Layout.dPos, toWit, W16Layout.qPos]
    rw [B.Wo_emb]
  case res1 =>
    intro p
    refine ⟨?_, w16 _ (Lk.dW p _ (by simp))⟩
    have := gated_at _ _ R.d2 _ (B.gD_one p)
    exact this
  case normM =>
    intro t
    refine ⟨⟨E.dsqM (L.tok.emb t), E.lm 1 0 (L.tok.emb t) + 2 ^ 8 * E.lm 1 1 (L.tok.emb t) + 2 ^ 16 * E.lm 1 2 (L.tok.emb t),
      E.lm 2 0 (L.tok.emb t) + 2 ^ 8 * E.lm 2 1 (L.tok.emb t) + 2 ^ 16 * E.lm 2 2 (L.tok.emb t), ⟨?_, ?_, ?_⟩, ?_, ?_, ?_⟩,
      fun i => ⟨⟨remVal 24 (E.mr.lo (L.dPos (t, i))) (E.mr.hi (L.dPos (t, i))),
        remVal 24 (E.ms.lo (L.dPos (t, i))) (E.ms.hi (L.dPos (t, i))), ⟨?_, ?_⟩, ?_, ?_⟩, ?_⟩⟩
    · exact R.tzc_sqm _
    · have := R.tzc_am (L.tok.emb t)
      show 2 * E.dM (L.tok.emb t) - _ - _ = 0
      linear_combination this
    · have h := R.ssm (L.tok.emb t)
      rw [B.gT_one, one_mul, sum_emb L.wid _ (fun c hc => by rw [B.gD_pad _ c hc, zero_mul, zero_mul])] at h
      show _ = ((S.ceps : GF) + ∑ i, E.X1 (L.dPos (t, i)) * E.X1 (L.dPos (t, i)))
      have h' : ∑ i, B.gD (L.tok.emb t, L.wid.emb i) * E.X1 (L.tok.emb t, L.wid.emb i) * E.X1 (L.tok.emb t, L.wid.emb i)
          = ∑ i, E.X1 (L.dPos (t, i)) * E.X1 (L.dPos (t, i)) := by
        refine sum_congr rfl fun i _ => ?_
        have := B.gD_one (t, i)
        simp only [W16Layout.dPos] at this ⊢
        rw [this, one_mul]
      rw [h'] at h
      linear_combination h
    · exact bytes24_of_lk hF P.exp P.act S.nG hW.w8 _ (fun k => E.lm 0 k (L.tok.emb t)) (R.tzc_dm _)
        (fun k => Lk.lm t 0 k)
    · exact (threeBytes_iff _).mp ⟨_, _, _, rfl, (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 1 0),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 1 1),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 1 2)⟩
    · exact (threeBytes_iff _).mp ⟨_, _, _, rfl, (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 2 0),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 2 1),
        (codeTable_range_iff hF P.exp P.act S.nG hW.w8 _).mp (Lk.lm t 2 2)⟩
    · have := gated_at _ _ R.d3 _ (B.gD_one (t, i))
      rw [B.gamM_emb] at this
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · have := gated_at _ _ R.d4 _ (B.gD_one (t, i))
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · exact rem 24 (by simp) _ _ (Lk.dR (t, i)).2.2.1
    · exact rem 24 (by simp) _ _ (Lk.dR (t, i)).2.2.2.1
    · exact w16 _ (Lk.dW (t, i) _ (by simp))
  case gate =>
    intro p
    refine ⟨remVal S.sgate (E.rg.lo (L.fPos p)) (E.rg.hi (L.fPos p)), ?_, rem S.sgate (by simp) _ _ (Lk.fR p).1,
      (codeTable_act_iff hF P.exp P.act S.nG _ _ _).mp (Lk.fAct p)⟩
    refine hostRel_of _ _ _ _ _ (B.gF_one p) ((R.gmm (L.fPos p)).trans ?_)
    rw [sum_emb L.wid _ (fun c hc => by rw [B.Wg_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun i _ => ?_
    simp only [W16Layout.fPos, toWit, W16Layout.dPos]
    rw [B.Wg_emb]
  case up =>
    intro p
    refine ⟨remVal S.sup (E.ru.lo (L.fPos p)) (E.ru.hi (L.fPos p)), ?_, w16 _ (Lk.fR p).2.1,
      rem S.sup (by simp) _ _ (Lk.fR p).2.2.1⟩
    refine hostRel_of _ _ _ _ _ (B.gF_one p) ((R.umm (L.fPos p)).trans ?_)
    rw [sum_emb L.wid _ (fun c hc => by rw [B.Wu_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun i _ => ?_
    simp only [W16Layout.fPos, toWit, W16Layout.dPos]
    rw [B.Wu_emb]
  case prod =>
    intro p
    refine ⟨remVal S.sprod (E.rh.lo (L.fPos p)) (E.rh.hi (L.fPos p)), ?_, ?_, rem S.sprod (by simp) _ _ (Lk.fR p).2.2.2.2.2⟩
    · have := gated_at _ _ R.f0 _ (B.gF_one p)
      unfold ProdRel
      simp only [toWit, W16Layout.dPos, W16Layout.qPos, W16Layout.kPos, W16Layout.sPos, W16Layout.htPos, W16Layout.fPos] at this ⊢
      linear_combination this
    · unfold BlockShape.prodC
      rw [ite_eq_left h24]
      exact word24_of_lk hF P.exp P.act S.nG hW.w16 hW.w8 _ _ (Lk.fR p).2.2.2.1 (Lk.fR p).2.2.2.2.1
  case down =>
    intro p
    refine ⟨remVal S.sdown (E.rd.lo (L.dPos p)) (E.rd.hi (L.dPos p)), ?_, w16 _ (Lk.dW p _ (by simp)),
      rem S.sdown (by simp) _ _ (Lk.dR p).2.2.2.2.2⟩
    refine hostRel_of _ _ _ _ _ (B.gD_one p) ((R.dmm (L.dPos p)).trans ?_)
    rw [sum_emb L.hid _ (fun c hc => by rw [B.Wd_pad c _ hc, mul_zero])]
    refine sum_congr rfl fun k _ => ?_
    simp only [W16Layout.dPos, toWit, W16Layout.fPos]
    rw [B.Wd_emb]
  case res2 =>
    intro p
    refine ⟨?_, w16 _ (Lk.dW p _ (by simp))⟩
    have := gated_at _ _ R.d5 _ (B.gD_one p)
    exact this

end ZK60.Layout
