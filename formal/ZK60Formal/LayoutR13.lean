/-
D63 Lean lane L17 (2026-11-07): **the R13 layout map** (ASSEMBLY §4.2 item f at R13): from the R13 slots' relations on
the COMMITTED cube and LogUp's conclusion over the BYTE table, to CircuitBlock's `BlockSat` at the LOGICAL positions —
the premise of the proved `block_circuitIff`. The R13 block and the W16R2 block arithmetize the SAME integer block
(`BlockShape`, `BlockSat`, `block_circuitIff` are shared); they differ in how the integer windows are range-checked.

What R13 does differently (read 2026-11-07, `private_block/`; nothing there is changed):
* every 16-bit word `w` (`X, Y, AO, X1, YM, Z, X2` on `Dom::D`; `Q, QR, O` on `Dom::Q`; `K, KR, V` on `Dom::Kv`; `U` on
  `Dom::F`) has TWO committed byte limbs and a gated decomposition clause `w + 32768 − Σ 256^k·limb_k`
  (argument_accuracy.rs:78-83, 117, 154); W16 looks the word up directly (`range16::word16`, the clause dropped);
* every remainder of `b` bits has `c` byte limbs with `8(c − 1) < b ≤ 8c`, each limb a byte lookup, the TOP limb also
  pinned by the byte lookup of `2^(8c − b)·top` (`bytes(g, Some(bits))`, accuracy_layout.rs:226-236); W16 has 16-bit
  limbs (`limbs16`, `rem_lookups`); the limb sum weighs `256^k` (`limbs`), not `2^16·k`;
* the 24-bit SiLU product word `H` has three byte limbs and the clause `H + 2^23 − Σ 256^k·HL_k` (`f2`, :117); W16
  writes it as `word24` (a 16-bit low expression and a top byte);
* the softmax quotient `P` has two byte limbs, pinned at `f_p + 1` bits, and the clause `P − Σ 256^k·PL_k` (`c4`,
  :326); W16 looks it up directly at `f_p + 1` bits;
* every lookup is into ONE byte table (`TAG_U8`, `Lk::u8`), besides the exp and ACT tuples: no range families.
* Everything else is the same code: the norm clauses, the RoPE clauses, the softmax clauses, the host relations, the
  layout map (`W16Layout`: the axes, the head-slot order C-1, the RoPE flip), the support gates, the pad rule
  (`W16Pub`), the isqrt bytes.

What is proved (only `propext`, `Classical.choice`, `Quot.sound`):
* `pin_inRange`, `lv_inRange`, `lv_inRange_pin`: byte limbs certify `InRange (8c)`; with the top pin, `InRange b` for
  any `8(c − 1) < b ≤ 8c` (the code's limb window). So the pin's coefficient is all that a shift changes, and the
  limb count (the plane list) is the window's;
* `remVal_split`, `remLk_split`: an R13 remainder `R` (`InRange b R`) read as W16's limb pair `(lo, hi)` (the 16-bit
  split of its canonical representative) has `remVal b lo hi = R` and passes W16's lookups of ANY family list that
  carries the widths;
* **`blockSat_of_slots_r13`**: for one R13 block at LowH24, `R13Rels` ∧ `R13Lookups` (∧ the layout facts, ∧ the shifts
  in their limb windows, `R13Windows`) ⇒ `BlockSat P (X ∘ dPos) (X2 ∘ dPos) (toWit L (E.toW16 S))`. The proof is a
  REDUCTION to L11's W16R2 theorem `blockSat_of_slots`: the R13 data read as W16 data (`R13Data.toW16`) satisfies
  `W16Rels` (every clause is R13's, with the limb sums in place of W16's limb pairs) and `W16Lookups` over a virtual
  family list (`allFams`, every width up to 32): a 16-bit word passes from its decomposition clause and its two bytes,
  a remainder from its bytes and pin, the product word from its three bytes, the quotient from its pinned bytes;
* `r13_block_output`, `hstart_block_r13`: with `block_circuitIff`, the slots' relations and the lookups give the
  integer block's output; contrapositively a false block statement dooms a relation or a byte/exp/ACT lookup.
-/
import ZK60Formal.LayoutW16

namespace ZK60.Layout.R13

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block ZK60.Layout
open ZK60.Sound (Tup)
open Finset

/-! ## Byte limbs -/

/-- `limbs(v, ix)` (argument_accuracy.rs): the value of `n` byte limbs, `Σ_k 256^k·limb_k`. -/
def lv {C : Type} {n : ℕ} (l : Fin n → C → GF) (x : C) : GF := ∑ k : Fin n, (256 : GF) ^ (k : ℕ) * l k x

theorem inRange_congr {w w' : ℕ} (h : w = w') {x : GF} (hx : InRange w x) : InRange w' x := h ▸ hx

theorem pow256 (n : ℕ) : (256 : GF) ^ n = 2 ^ (8 * n) := by
  rw [pow_mul]
  norm_num

theorem lv_zero {C : Type} (l : Fin 0 → C → GF) (x : C) : lv l x = 0 := by simp [lv]

theorem lv_succ {C : Type} {n : ℕ} (l : Fin (n + 1) → C → GF) (x : C) :
    lv l x = lv (fun k => l (Fin.castSucc k)) x + 2 ^ (8 * n) * l (Fin.last n) x := by
  unfold lv
  rw [Fin.sum_univ_castSucc]
  simp only [Fin.val_castSucc, Fin.val_last]
  rw [pow256]

theorem lv_three {C : Type} (l : Fin 3 → C → GF) (x : C) : lv l x = l 0 x + 2 ^ 8 * l 1 x + 2 ^ 16 * l 2 x := by
  unfold lv
  rw [Fin.sum_univ_three]
  norm_num

/-- **The top pin** (`Lk::u8([(top, 2^s)], 0)`): a byte `t` whose multiple `2^s·t` is a byte has `8 − s` bits. -/
theorem pin_inRange {s : ℕ} (hs : s ≤ 8) {t : GF} (ht : InRange 8 t) (hp : InRange 8 (2 ^ s * t)) :
    InRange (8 - s) t := by
  obtain ⟨a, ha0, ha1, rfl⟩ := ht
  obtain ⟨u, hu0, hu1, hu⟩ := hp
  have hcast : ((2 ^ s * a : ℤ) : GF) = (u : GF) := by push_cast; exact hu
  have h2s : (2 : ℤ) ^ s ≤ 2 ^ 8 := pow_le_pow_right₀ (by norm_num) hs
  have hpos : (0 : ℤ) < 2 ^ s := by positivity
  have hA : 0 ≤ 2 ^ s * a := mul_nonneg (le_of_lt hpos) ha0
  have hB : 2 ^ s * a ≤ 2 ^ 8 * 2 ^ 8 := mul_le_mul h2s (le_of_lt ha1) ha0 (by positivity)
  have heq : 2 ^ s * a = u := int_eq_of_cast_eq hcast (by rw [gP_int]; norm_num at hB hu1 ⊢; linarith)
    (by rw [gP_int]; norm_num at hB hu0 ⊢; linarith)
  refine ⟨a, ha0, ?_, rfl⟩
  have h256 : (2 : ℤ) ^ s * 2 ^ (8 - s) = 2 ^ 8 := by rw [← pow_add, Nat.add_sub_cancel' hs]
  by_contra hc
  have hc' : (2 : ℤ) ^ (8 - s) ≤ a := not_lt.mp hc
  have : (2 : ℤ) ^ s * 2 ^ (8 - s) ≤ 2 ^ s * a := mul_le_mul_of_nonneg_left hc' (le_of_lt hpos)
  linarith

/-- **`n` byte limbs certify `InRange (8n)`** (`bytes(g, None)`). -/
theorem lv_inRange {C : Type} : ∀ {n : ℕ} (l : Fin n → C → GF) (x : C), (∀ k, InRange 8 (l k x)) →
    InRange (8 * n) (lv l x)
  | 0, l, x, _ => ⟨0, le_rfl, by norm_num, by rw [lv_zero]; simp⟩
  | n + 1, l, x, h => by
    rw [lv_succ]
    have ih := lv_inRange (fun k => l (Fin.castSucc k)) x (fun k => h _)
    exact inRange_congr (by ring) ((limbs_iff (8 * n) 8 _).mp ⟨_, _, rfl, ih, h (Fin.last n)⟩)

/-- **`n + 1` byte limbs with the top pin certify `InRange b`** for every `b` in the limb window
`8n < b ≤ 8(n + 1)` (`bytes(g, Some(b))`, accuracy_layout.rs:226-236: the window is the code's own refusal). -/
theorem lv_inRange_pin {C : Type} {n b : ℕ} (l : Fin (n + 1) → C → GF) (x : C) (hb1 : 8 * n < b)
    (hb2 : b ≤ 8 * (n + 1)) (h : ∀ k, InRange 8 (l k x))
    (hp : InRange 8 (2 ^ (8 * (n + 1) - b) * l (Fin.last n) x)) : InRange b (lv l x) := by
  rw [lv_succ]
  have ih := lv_inRange (fun k => l (Fin.castSucc k)) x (fun k => h _)
  have ht := pin_inRange (s := 8 * (n + 1) - b) (by omega) (h (Fin.last n)) hp
  exact inRange_congr (by omega) ((limbs_iff (8 * n) (8 - (8 * (n + 1) - b)) _).mp ⟨_, _, rfl, ih, ht⟩)

/-! ## The byte table and a virtual family list -/

/-- **The R13 block's range table**: the byte family alone, at `TAG_U8` (`Lk::u8`; tables_attn.rs:70). -/
def r13Fams : List (ℕ × ℕ) := [(tagW 8, 8)]

theorem r13Fams_ok : FamsOK r13Fams := ⟨by decide, by decide, by decide, by decide⟩

theorem mem_r13Fams : (tagW 8, 8) ∈ r13Fams := List.mem_singleton.mpr rfl

theorem inRange8_of {exp : ℤ → ℤ} {act : ℕ → ℤ → ℤ} {nG : ℕ} {x : GF}
    (h : CodeTable r13Fams exp act nG (rangeQuery (tagW 8) x)) : InRange 8 x :=
  (codeTable_range_iff r13Fams_ok exp act nG mem_r13Fams x).mp h

/-- Every range family of width `0 … 32` at its tag. The W16R2 theorem's lookups are stated against a family list; an
R13 range FACT turns into a table membership of this list (`codeTable_range_iff`), so the W16R2 theorem applies. It
names no table the R13 code builds; it is a device of the proof. -/
def allFams : List (ℕ × ℕ) := (List.range 33).map fun w => (tagW w, w)

theorem allFams_ok : FamsOK allFams := ⟨by decide, by decide, by decide, by decide⟩

theorem mem_allFams (w : ℕ) (hw : w ≤ 32) : (tagW w, w) ∈ allFams :=
  List.mem_map.mpr ⟨w, List.mem_range.mpr (by omega), rfl⟩

/-- A byte query of the R13 table is one of `allFams`. -/
theorem cvt8 {exp : ℤ → ℤ} {act : ℕ → ℤ → ℤ} {nG : ℕ} {x : GF}
    (h : CodeTable r13Fams exp act nG (rangeQuery (tagW 8) x)) : CodeTable allFams exp act nG (rangeQuery (tagW 8) x) :=
  (codeTable_range_iff allFams_ok exp act nG (mem_allFams 8 (by norm_num)) x).mpr (inRange8_of h)

/-! ## W16's limb pair of an R13 remainder -/

/-- The low 16-bit limb of a value's canonical representative (the value itself below 17 bits). -/
def splitLo (b : ℕ) (R : GF) : GF := if b ≤ 16 then R else ((R.val % 2 ^ 16 : ℕ) : GF)

/-- The top limb (zero below 17 bits). -/
def splitHi (b : ℕ) (R : GF) : GF := if b ≤ 16 then 0 else ((R.val / 2 ^ 16 : ℕ) : GF)

/-- An R13 remainder plane read as W16's limb pair. -/
def split {C : Type} (b : ℕ) (f : C → GF) : RemP C := ⟨fun x => splitLo b (f x), fun x => splitHi b (f x)⟩

/-- **The limb pair is the remainder**, at every position. -/
theorem remVal_split (b : ℕ) (R : GF) : remVal b (splitLo b R) (splitHi b R) = R := by
  unfold remVal splitLo splitHi
  by_cases h : b ≤ 16
  · simp only [h, ↓reduceIte]
  · simp only [h, ↓reduceIte]
    have e : R = ((R.val : ℕ) : GF) := (ZMod.natCast_zmod_val R).symm
    conv_rhs => rw [e, ← Nat.mod_add_div R.val (2 ^ 16)]
    push_cast
    ring

theorem remVal_split_apply {C : Type} (b : ℕ) (f : C → GF) (x : C) : remVal b ((split b f).lo x) ((split b f).hi x) = f x :=
  remVal_split b (f x)

theorem val_lt_of_inRange {b : ℕ} (hb : b ≤ 63) {R : GF} (h : InRange b R) : R.val < 2 ^ b := by
  have := (inRangeB_iff hb R).mpr h
  unfold inRangeB at this
  exact of_decide_eq_true this

theorem inRange_of_val_lt {b : ℕ} (hb : b ≤ 63) {R : GF} (h : R.val < 2 ^ b) : InRange b R := by
  refine (inRangeB_iff hb R).mp ?_
  unfold inRangeB
  exact decide_eq_true h

/-- **An R13 remainder passes W16's lookups** (`rem_lookups` of its limb pair) in any family list carrying its
widths. -/
theorem remLk_split {fams : List (ℕ × ℕ)} (hF : FamsOK fams) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (b : ℕ)
    (hb : b ≤ 32) (R : GF) (hR : InRange b R) (hlo : b ≤ 16 → (tagW b, b) ∈ fams)
    (hhi : 16 < b → (tagW 16, 16) ∈ fams ∧ (tagW (b - 16), b - 16) ∈ fams) :
    ∀ q ∈ remLk b (splitLo b R) (splitHi b R), CodeTable fams exp act nG q := by
  unfold remLk splitLo splitHi
  by_cases h : b ≤ 16
  · simp only [h, ↓reduceIte, List.mem_singleton]
    rintro q rfl
    exact (codeTable_range_iff hF exp act nG (hlo h) _).mpr hR
  · simp only [h, ↓reduceIte]
    have hv : R.val < 2 ^ b := val_lt_of_inRange (by omega) hR
    obtain ⟨h16, hb16⟩ := hhi (by omega)
    intro q hq
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hq
    rcases hq with rfl | rfl
    · refine (codeTable_range_iff hF exp act nG h16 _).mpr (inRange_of_val_lt (by norm_num) ?_)
      rw [ZMod.val_natCast]
      exact lt_of_le_of_lt (Nat.mod_le _ _) (Nat.mod_lt _ (by norm_num))
    · refine (codeTable_range_iff hF exp act nG hb16 _).mpr (inRange_of_val_lt (by omega) ?_)
      rw [ZMod.val_natCast]
      refine lt_of_le_of_lt (Nat.mod_le _ _) ?_
      rw [Nat.div_lt_iff_lt_mul (by positivity), ← pow_add, Nat.sub_add_cancel (by omega)]
      exact hv

/-- `remLk_split` at `allFams`. -/
theorem remLk_all (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) {b : ℕ} (hb : b ≤ 32) (R : GF) (hR : InRange b R) :
    ∀ q ∈ remLk b (splitLo b R) (splitHi b R), CodeTable allFams exp act nG q :=
  remLk_split allFams_ok exp act nG b hb R hR (fun _ => mem_allFams b hb)
    (fun _ => ⟨mem_allFams 16 (by norm_num), mem_allFams (b - 16) (by omega)⟩)

/-! ## The R13 block's data, relations and lookups -/

/-- The byte lookups of a limb role (`bytes(g, None)`, accuracy_layout.rs:226-236). -/
abbrev Bytes (T : Tup GF → Prop) {C : Type} {n : ℕ} (l : Fin n → C → GF) (x : C) : Prop :=
  ∀ k, T (rangeQuery (tagW 8) (l k x))

/-- The byte lookups of a limb role and its top pin `2^(8(n+1) − b)·top` (`bytes(g, Some(b))`). -/
abbrev BytesPin (T : Tup GF → Prop) {C : Type} {n : ℕ} (l : Fin (n + 1) → C → GF) (b : ℕ) (x : C) : Prop :=
  Bytes T l x ∧ T (rangeQuery (tagW 8) (2 ^ (8 * (n + 1) - b) * l (Fin.last n) x))

/-- **The extracted planes of one R13 block** at LowH24 (`AccuracyIds::new`, accuracy_layout.rs:51-104): the words
(as `W16Data`), and the byte limbs: two per 16-bit word, three per 24-bit norm remainder, the remainders' limbs at
the window of their shift (`RAL`, `RDL`, `RSL`, `RGL` three; `RQL`, `RO`, `RKL`, `RVL`, `RU` two; `RQRL`, `RKRL` one;
`SR`, `SG` `ls + 1`), the product word's three (`HL`) and its remainder's two (`RH`), the quotient's two (`PL`). -/
structure R13Data (Ct Cw Cg Cj Cd Cf : Type) (ls : ℕ) where
  dA : Ct → GF
  dsqA : Ct → GF
  dM : Ct → GF
  dsqM : Ct → GF
  la : Fin 3 → Fin 3 → Ct → GF
  lm : Fin 3 → Fin 3 → Ct → GF
  X : Ct × Cw → GF
  Y : Ct × Cw → GF
  AO : Ct × Cw → GF
  X1 : Ct × Cw → GF
  YM : Ct × Cw → GF
  Z : Ct × Cw → GF
  X2 : Ct × Cw → GF
  xl : Fin 2 → Ct × Cw → GF
  yl : Fin 2 → Ct × Cw → GF
  aol : Fin 2 → Ct × Cw → GF
  x1l : Fin 2 → Ct × Cw → GF
  yml : Fin 2 → Ct × Cw → GF
  zl : Fin 2 → Ct × Cw → GF
  x2l : Fin 2 → Ct × Cw → GF
  nr : Fin 3 → Ct × Cw → GF
  ns : Fin 3 → Ct × Cw → GF
  mr : Fin 3 → Ct × Cw → GF
  ms : Fin 3 → Ct × Cw → GF
  ral : Fin 3 → Ct × Cw → GF
  rdl : Fin 3 → Ct × Cw → GF
  Q : Ct × ((Cg × Cj) × Cd) → GF
  QR : Ct × ((Cg × Cj) × Cd) → GF
  O : Ct × ((Cg × Cj) × Cd) → GF
  ql : Fin 2 → Ct × ((Cg × Cj) × Cd) → GF
  qrl : Fin 2 → Ct × ((Cg × Cj) × Cd) → GF
  ol : Fin 2 → Ct × ((Cg × Cj) × Cd) → GF
  rql : Fin 2 → Ct × ((Cg × Cj) × Cd) → GF
  rqrl : Fin 1 → Ct × ((Cg × Cj) × Cd) → GF
  ro : Fin 2 → Ct × ((Cg × Cj) × Cd) → GF
  K : Ct × (Cg × Cd) → GF
  KR : Ct × (Cg × Cd) → GF
  V : Ct × (Cg × Cd) → GF
  kl : Fin 2 → Ct × (Cg × Cd) → GF
  krl : Fin 2 → Ct × (Cg × Cd) → GF
  vl : Fin 2 → Ct × (Cg × Cd) → GF
  rkl : Fin 2 → Ct × (Cg × Cd) → GF
  rkrl : Fin 1 → Ct × (Cg × Cd) → GF
  rvl : Fin 2 → Ct × (Cg × Cd) → GF
  S8 : (Cg × Cj) × Ct × Ct → GF
  ZSEL : (Cg × Cj) × Ct × Ct → GF
  E : (Cg × Cj) × Ct × Ct → GF
  PP : (Cg × Cj) × Ct × Ct → GF
  rsl : Fin 3 → (Cg × Cj) × Ct × Ct → GF
  pl : Fin 2 → (Cg × Cj) × Ct × Ct → GF
  sr : Fin (ls + 1) → (Cg × Cj) × Ct × Ct → GF
  sg : Fin (ls + 1) → (Cg × Cj) × Ct × Ct → GF
  MX : (Cg × Cj) × Ct → GF
  SUM : (Cg × Cj) × Ct → GF
  G : Ct × Cf → GF
  A : Ct × Cf → GF
  U : Ct × Cf → GF
  H : Ct × Cf → GF
  rgl : Fin 3 → Ct × Cf → GF
  ul : Fin 2 → Ct × Cf → GF
  ru : Fin 2 → Ct × Cf → GF
  hl : Fin 3 → Ct × Cf → GF
  rh : Fin 2 → Ct × Cf → GF

/-- **The R13 data read as W16 data**: the words unchanged; each remainder the W16 limb pair of its byte-limb value;
the product word's W16 top limb `HL_2 − 128`. -/
def R13Data.toW16 {Ct Cw Cg Cj Cd Cf : Type} {ls : ℕ} (E : R13Data Ct Cw Cg Cj Cd Cf ls) (S : BlockShape) :
    W16Data Ct Cw Cg Cj Cd Cf where
  dA := E.dA
  dsqA := E.dsqA
  dM := E.dM
  dsqM := E.dsqM
  la := E.la
  lm := E.lm
  X := E.X
  Y := E.Y
  AO := E.AO
  X1 := E.X1
  YM := E.YM
  Z := E.Z
  X2 := E.X2
  nr := split 24 (lv E.nr)
  ns := split 24 (lv E.ns)
  mr := split 24 (lv E.mr)
  ms := split 24 (lv E.ms)
  rao := split S.sao (lv E.ral)
  rd := split S.sdown (lv E.rdl)
  Q := E.Q
  QR := E.QR
  O := E.O
  rq := split S.sq (lv E.rql)
  rqr := split 7 (lv E.rqrl)
  ro := split S.spv (lv E.ro)
  K := E.K
  KR := E.KR
  V := E.V
  rk := split S.sk (lv E.rkl)
  rkr := split 7 (lv E.rkrl)
  rv := split S.sv (lv E.rvl)
  S8 := E.S8
  ZSEL := E.ZSEL
  E := E.E
  PP := E.PP
  rs := split S.ss (lv E.rsl)
  sr := split S.wrho (lv E.sr)
  sg := split S.wrho (lv E.sg)
  MX := E.MX
  SUM := E.SUM
  G := E.G
  A := E.A
  U := E.U
  H := E.H
  Htop := fun x => E.hl 2 x - 128
  rg := split S.sgate (lv E.rgl)
  ru := split S.sup (lv E.ru)
  rh := split S.sprod (lv E.rh)

/-- **The R13 slots' relations on the cube** (`dzc`, `fzc`, `qzc`, `szc`, argument_accuracy.rs:48-347, and the shared
slots of argument.rs): W16R2's relations (`W16Rels`) with the byte-limb sums `lv` in place of W16's limb pairs, and the
R13 decomposition clauses (each gated by its domain's support indicator): the eleven 16-bit words, the product word
`H + 2^23 − Σ HL`, the quotient `P − Σ PL`. -/
structure R13Rels (S : BlockShape) {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
    [Fintype Cd] [Fintype Cf] (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) {ls : ℕ}
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) : Prop where
  tzc_sq : ∀ t, E.dsqA t - E.dA t * E.dA t = 0
  tzc_d : ∀ t, E.dA t - (E.la 0 0 t + 2 ^ 8 * E.la 0 1 t + 2 ^ 16 * E.la 0 2 t) = 0
  tzc_a : ∀ t, 2 * E.dA t - (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t)
    - (E.la 2 0 t + 2 ^ 8 * E.la 2 1 t + 2 ^ 16 * E.la 2 2 t) = 0
  tzc_sqm : ∀ t, E.dsqM t - E.dM t * E.dM t = 0
  tzc_dm : ∀ t, E.dM t - (E.lm 0 0 t + 2 ^ 8 * E.lm 0 1 t + 2 ^ 16 * E.lm 0 2 t) = 0
  tzc_am : ∀ t, 2 * E.dM t - (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t)
    - (E.lm 2 0 t + 2 ^ 8 * E.lm 2 1 t + 2 ^ 16 * E.lm 2 2 t) = 0
  ss : ∀ t, B.gT t * (E.dsqA t + (E.la 1 0 t + 2 ^ 8 * E.la 1 1 t + 2 ^ 16 * E.la 1 2 t) - (S.ceps : GF))
    = ∑ c, B.gD (t, c) * E.X (t, c) * E.X (t, c)
  ssm : ∀ t, B.gT t * (E.dsqM t + (E.lm 1 0 t + 2 ^ 8 * E.lm 1 1 t + 2 ^ 16 * E.lm 1 2 t) - (S.ceps : GF))
    = ∑ c, B.gD (t, c) * E.X1 (t, c) * E.X1 (t, c)
  d0 : ∀ x, B.gD x * (B.gamA x * E.X x * (2 * (S.cnA : GF)) + E.dA x.1 * 2 ^ S.tn
    - 2 ^ (S.tn + 1) * E.dA x.1 * E.Y x - lv E.nr x) = 0
  d1 : ∀ x, B.gD x * (lv E.nr x + lv E.ns x + 1 - 2 ^ (S.tn + 1) * E.dA x.1) = 0
  d2 : ∀ x, B.gD x * (E.X1 x - E.X x - E.AO x) = 0
  d3 : ∀ x, B.gD x * (B.gamM x * E.X1 x * (2 * (S.cnM : GF)) + E.dM x.1 * 2 ^ S.tn
    - 2 ^ (S.tn + 1) * E.dM x.1 * E.YM x - lv E.mr x) = 0
  d4 : ∀ x, B.gD x * (lv E.mr x + lv E.ms x + 1 - 2 ^ (S.tn + 1) * E.dM x.1) = 0
  d5 : ∀ x, B.gD x * (E.X2 x - E.X1 x - E.Z x) = 0
  /-- the seven word decompositions of `dzc` (argument_accuracy.rs:79-83) -/
  wX : ∀ x, B.gD x * (E.X x + 32768 - lv E.xl x) = 0
  wY : ∀ x, B.gD x * (E.Y x + 32768 - lv E.yl x) = 0
  wAO : ∀ x, B.gD x * (E.AO x + 32768 - lv E.aol x) = 0
  wX1 : ∀ x, B.gD x * (E.X1 x + 32768 - lv E.x1l x) = 0
  wYM : ∀ x, B.gD x * (E.YM x + 32768 - lv E.yml x) = 0
  wZ : ∀ x, B.gD x * (E.Z x + 32768 - lv E.zl x) = 0
  wX2 : ∀ x, B.gD x * (E.X2 x + 32768 - lv E.x2l x) = 0
  wo : ∀ x, B.gD x * (2 ^ S.sao * E.AO x + lv E.ral x - 2 ^ (S.sao - 1)) = ∑ c, E.O (x.1, c) * B.Wo c x.2
  dmm : ∀ x, B.gD x * (2 ^ S.sdown * E.Z x + lv E.rdl x - 2 ^ (S.sdown - 1)) = ∑ c, E.H (x.1, c) * B.Wd c x.2
  qrope : ∀ x, B.gQ x * (B.cosT x * E.Q x + B.sinT x * E.Q (x.1, (x.2.1, L.flip x.2.2)) - 2 ^ 7 * E.QR x
    - lv E.rqrl x + 2 ^ 6) = 0
  /-- the three word decompositions of `qzc` on `Dom::Q` (:154) -/
  wQ : ∀ x, B.gQ x * (E.Q x + 32768 - lv E.ql x) = 0
  wQR : ∀ x, B.gQ x * (E.QR x + 32768 - lv E.qrl x) = 0
  wO : ∀ x, B.gQ x * (E.O x + 32768 - lv E.ol x) = 0
  qmm : ∀ x, B.gQ x * (2 ^ S.sq * E.Q x + lv E.rql x - 2 ^ (S.sq - 1)) = ∑ c, E.Y (x.1, c) * B.Wq c x.2
  pv : ∀ x, B.gQ x * (2 ^ S.spv * E.O x + lv E.ro x - 2 ^ (S.spv - 1)) = ∑ j, E.PP (x.2.1, x.1, j) * E.V (j, (x.2.1.1, x.2.2))
  krope : ∀ x, B.gK x * (B.cosK x * E.K x + B.sinK x * E.K (x.1, (x.2.1, L.flip x.2.2)) - 2 ^ 7 * E.KR x
    - lv E.rkrl x + 2 ^ 6) = 0
  /-- the three word decompositions of `qzc` on `Dom::Kv` -/
  wK : ∀ x, B.gK x * (E.K x + 32768 - lv E.kl x) = 0
  wKR : ∀ x, B.gK x * (E.KR x + 32768 - lv E.krl x) = 0
  wV : ∀ x, B.gK x * (E.V x + 32768 - lv E.vl x) = 0
  kmm : ∀ x, B.gK x * (2 ^ S.sk * E.K x + lv E.rkl x - 2 ^ (S.sk - 1)) = ∑ c, E.Y (x.1, c) * B.Wk c x.2
  vmm : ∀ x, B.gK x * (2 ^ S.sv * E.V x + lv E.rvl x - 2 ^ (S.sv - 1)) = ∑ c, E.Y (x.1, c) * B.Wv c x.2
  s0 : ∀ x, B.gS x * (E.ZSEL x * E.ZSEL x - E.ZSEL x) = 0
  s1 : ∀ x, B.gS x * (E.ZSEL x * (E.MX (x.1, x.2.1) - B.mask x * (E.S8 x + 127) + 127)) = 0
  s2 : ∀ x, B.gS x * (B.mask x * E.E x * 2 ^ S.fp - E.PP x * E.SUM (x.1, x.2.1) - lv E.sr x) = 0
  s3 : ∀ x, B.gS x * (lv E.sg x + lv E.sr x + 1 - E.SUM (x.1, x.2.1)) = 0
  /-- the quotient's decomposition `c4 = p − Σ PL` (:326) -/
  s4 : ∀ x, B.gS x * (E.PP x - lv E.pl x) = 0
  rsE : ∀ r, B.gHt r * E.SUM r = ∑ j, B.gS (r.1, r.2, j) * (B.mask (r.1, r.2, j) * E.E (r.1, r.2, j))
  rsZ : ∀ r, B.gHt r = ∑ j, B.gS (r.1, r.2, j) * E.ZSEL (r.1, r.2, j)
  score : ∀ x, B.gS x * (2 ^ S.ss * E.S8 x + lv E.rsl x - 2 ^ (S.ss - 1))
    = ∑ c, E.QR (x.2.1, (x.1, c)) * E.KR (x.2.2, (x.1.1, c))
  f0 : ∀ x, B.gF x * (E.A x * E.U x - 2 ^ S.sprod * E.H x - lv E.rh x + 2 ^ (S.sprod - 1)) = 0
  /-- `fzc`'s two decompositions (:117): the word `U`, the 24-bit product word `H` -/
  f1 : ∀ x, B.gF x * (E.U x + 32768 - lv E.ul x) = 0
  f2 : ∀ x, B.gF x * (E.H x + 2 ^ 23 - lv E.hl x) = 0
  gmm : ∀ x, B.gF x * (2 ^ S.sgate * E.G x + lv E.rgl x - 2 ^ (S.sgate - 1)) = ∑ c, E.YM (x.1, c) * B.Wg c x.2
  umm : ∀ x, B.gF x * (2 ^ S.sup * E.U x + lv E.ru x - 2 ^ (S.sup - 1)) = ∑ c, E.YM (x.1, c) * B.Wu c x.2
  pp_pad : ∀ s t j, (∀ i, L.tok.emb i ≠ j) → E.PP (s, t, j) = 0
  kr_pad : ∀ j g c, (∀ e, L.hd.emb e ≠ c) → E.KR (j, (g, c)) = 0

/-- **LogUp's conclusion at every logical position over the BYTE table** (the R13 lookup list, `AccuracyIds::lookups`,
accuracy_layout.rs:218-280; one table `CodeTable r13Fams`): every limb a byte, every remainder's top pinned at its
shift, the int8 score's two byte queries, the exp and ACT tuples. -/
structure R13Lookups (S : BlockShape) {Ct Cw Cg Cj Cd Cf : Type} (P : BlockPublic S)
    (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) {ls : ℕ} (E : R13Data Ct Cw Cg Cj Cd Cf ls) : Prop where
  la : ∀ t i k, CodeTable r13Fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.la i k (L.tok.emb t)))
  lm : ∀ t i k, CodeTable r13Fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.lm i k (L.tok.emb t)))
  xl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.xl (L.dPos p)
  yl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.yl (L.dPos p)
  aol : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.aol (L.dPos p)
  x1l : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.x1l (L.dPos p)
  yml : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.yml (L.dPos p)
  zl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.zl (L.dPos p)
  x2l : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.x2l (L.dPos p)
  nr : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.nr (L.dPos p)
  ns : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.ns (L.dPos p)
  mr : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.mr (L.dPos p)
  ms : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.ms (L.dPos p)
  ral : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.ral S.sao (L.dPos p)
  rdl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rdl S.sdown (L.dPos p)
  ql : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.ql (L.qPos p)
  qrl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.qrl (L.qPos p)
  ol : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.ol (L.qPos p)
  rql : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rql S.sq (L.qPos p)
  rqrl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rqrl 7 (L.qPos p)
  ro : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.ro S.spv (L.qPos p)
  kl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.kl (L.kPos p)
  krl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.krl (L.kPos p)
  vl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.vl (L.kPos p)
  rkl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rkl S.sk (L.kPos p)
  rkrl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rkrl 7 (L.kPos p)
  rvl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rvl S.sv (L.kPos p)
  sB : ∀ p, CodeTable r13Fams P.exp P.act S.nG (rangeQuery (tagW 8) (E.S8 (L.sPos p) + 127)) ∧
    CodeTable r13Fams P.exp P.act S.nG (rangeQuery (tagW 8) (-E.S8 (L.sPos p) + 127))
  rsl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rsl S.ss (L.sPos p)
  pl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.pl (S.fp + 1) (L.sPos p)
  sr : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.sr S.wrho (L.sPos p)
  sg : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.sg S.wrho (L.sPos p)
  sExp : ∀ p, CodeTable r13Fams P.exp P.act S.nG
    (expQuery (E.MX (L.slot p.1, L.tok.emb p.2.1) - B.mask (L.sPos p) * (E.S8 (L.sPos p) + 127) + 127) (E.E (L.sPos p)))
  rgl : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.rgl S.sgate (L.fPos p)
  ul : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.ul (L.fPos p)
  ru : ∀ p, BytesPin (CodeTable r13Fams P.exp P.act S.nG) E.ru S.sup (L.fPos p)
  hl : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.hl (L.fPos p)
  rh : ∀ p, Bytes (CodeTable r13Fams P.exp P.act S.nG) E.rh (L.fPos p)
  fAct : ∀ p, CodeTable r13Fams P.exp P.act S.nG (actQuery (E.G (L.fPos p)) (E.A (L.fPos p)) (P.grpF p.2))

/-- **The shifts in their limb windows** (`ls + 1` softmax remainder limbs): what `AccuracyIds::lookups` checks before
it emits a pin ("shift does not fit its counted limb window", accuracy_layout.rs:230) and what
`accuracy_precision::derive` guarantees at LowH24 (`ShapeR13.lean`'s `derive_windows`); the SiLU product's remainder is
the two full bytes of `RH` (`Rh`, no pin), so the product shift must be `16` (the R13 face of finding L11-1). -/
structure R13Windows (S : BlockShape) (ls : ℕ) : Prop where
  ao : 16 < S.sao ∧ S.sao ≤ 24
  down : 16 < S.sdown ∧ S.sdown ≤ 24
  q : 8 < S.sq ∧ S.sq ≤ 16
  pv : 8 < S.spv ∧ S.spv ≤ 16
  k : 8 < S.sk ∧ S.sk ≤ 16
  v : 8 < S.sv ∧ S.sv ≤ 16
  ss : 16 < S.ss ∧ S.ss ≤ 24
  gate : 16 < S.sgate ∧ S.sgate ≤ 24
  up : 8 < S.sup ∧ S.sup ≤ 16
  fp : 8 < S.fp + 1 ∧ S.fp + 1 ≤ 16
  wrho : 8 * ls < S.wrho ∧ S.wrho ≤ 8 * (ls + 1)
  wrho24 : S.wrho ≤ 24
  prod : S.sprod = 16

/-! ## The reduction to the W16R2 layout theorem -/

section Reduce

variable {S : BlockShape} {Ct Cw Cg Cj Cd Cf : Type} [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj]
  [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd]
  [DecidableEq Cf]

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- A word with its gated decomposition and its two byte limbs at a logical position passes W16's word query. -/
theorem word_lk {C : Type} {exp : ℤ → ℤ} {act : ℕ → ℤ → ℤ} {nG : ℕ} (g w : C → GF) (wl : Fin 2 → C → GF) (x : C)
    (hg : g x = 1) (hcl : ∀ y, g y * (w y + 32768 - lv wl y) = 0) (hb : Bytes (CodeTable r13Fams exp act nG) wl x) :
    CodeTable allFams exp act nG (rangeQuery (tagW 16) (w x + 32768)) := by
  have h := gated_at g _ hcl x hg
  have hw : w x + 32768 = lv wl x := sub_eq_zero.mp h
  rw [hw]
  exact (codeTable_range_iff allFams_ok exp act nG (mem_allFams 16 (by norm_num)) _).mpr
    (inRange_congr (by norm_num) (lv_inRange wl x fun k => inRange8_of (hb k)))

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- A pinned remainder at a logical position, in its window. -/
theorem pin_rem {C : Type} {exp : ℤ → ℤ} {act : ℕ → ℤ → ℤ} {nG : ℕ} {n b : ℕ} (l : Fin (n + 1) → C → GF) (x : C)
    (hb1 : 8 * n < b) (hb2 : b ≤ 8 * (n + 1)) (h : BytesPin (CodeTable r13Fams exp act nG) l b x) :
    InRange b (lv l x) :=
  lv_inRange_pin l x hb1 hb2 (fun k => inRange8_of (h.1 k)) (inRange8_of h.2)

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- An unpinned remainder of `n` bytes. -/
theorem bytes_rem {C : Type} {exp : ℤ → ℤ} {act : ℕ → ℤ → ℤ} {nG : ℕ} {n : ℕ} (l : Fin n → C → GF) (x : C)
    (h : Bytes (CodeTable r13Fams exp act nG) l x) : InRange (8 * n) (lv l x) :=
  lv_inRange l x fun k => inRange8_of (h k)

omit [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- **The R13 relations are W16R2's relations of the R13 data read as W16 data.** -/
theorem w16Rels_of_r13 (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) {ls : ℕ}
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) (R : R13Rels S P L B E) : W16Rels S P L B (E.toW16 S) where
  tzc_sq := R.tzc_sq
  tzc_d := R.tzc_d
  tzc_a := R.tzc_a
  tzc_sqm := R.tzc_sqm
  tzc_dm := R.tzc_dm
  tzc_am := R.tzc_am
  ss := R.ss
  ssm := R.ssm
  d0 := fun x => by
    have h := R.d0 x
    rw [← remVal_split 24 (lv E.nr x)] at h
    exact h
  d1 := fun x => by
    have h := R.d1 x
    rw [← remVal_split 24 (lv E.nr x), ← remVal_split 24 (lv E.ns x)] at h
    exact h
  d2 := R.d2
  d3 := fun x => by
    have h := R.d3 x
    rw [← remVal_split 24 (lv E.mr x)] at h
    exact h
  d4 := fun x => by
    have h := R.d4 x
    rw [← remVal_split 24 (lv E.mr x), ← remVal_split 24 (lv E.ms x)] at h
    exact h
  d5 := R.d5
  wo := fun x => by
    have h := R.wo x
    rw [← remVal_split S.sao (lv E.ral x)] at h
    exact h
  dmm := fun x => by
    have h := R.dmm x
    rw [← remVal_split S.sdown (lv E.rdl x)] at h
    exact h
  qrope := fun x => by
    have h := R.qrope x
    rw [← remVal_split 7 (lv E.rqrl x)] at h
    exact h
  qmm := fun x => by
    have h := R.qmm x
    rw [← remVal_split S.sq (lv E.rql x)] at h
    exact h
  pv := fun x => by
    have h := R.pv x
    rw [← remVal_split S.spv (lv E.ro x)] at h
    exact h
  krope := fun x => by
    have h := R.krope x
    rw [← remVal_split 7 (lv E.rkrl x)] at h
    exact h
  kmm := fun x => by
    have h := R.kmm x
    rw [← remVal_split S.sk (lv E.rkl x)] at h
    exact h
  vmm := fun x => by
    have h := R.vmm x
    rw [← remVal_split S.sv (lv E.rvl x)] at h
    exact h
  s0 := R.s0
  s1 := R.s1
  s2 := fun x => by
    have h := R.s2 x
    rw [← remVal_split S.wrho (lv E.sr x)] at h
    exact h
  s3 := fun x => by
    have h := R.s3 x
    rw [← remVal_split S.wrho (lv E.sg x), ← remVal_split S.wrho (lv E.sr x)] at h
    exact h
  rsE := R.rsE
  rsZ := R.rsZ
  score := fun x => by
    have h := R.score x
    rw [← remVal_split S.ss (lv E.rsl x)] at h
    exact h
  f0 := fun x => by
    have h := R.f0 x
    rw [← remVal_split S.sprod (lv E.rh x)] at h
    exact h
  gmm := fun x => by
    have h := R.gmm x
    rw [← remVal_split S.sgate (lv E.rgl x)] at h
    exact h
  umm := fun x => by
    have h := R.umm x
    rw [← remVal_split S.sup (lv E.ru x)] at h
    exact h
  pp_pad := R.pp_pad
  kr_pad := R.kr_pad

omit [DecidableEq Ct] [DecidableEq Cw] [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- **The R13 lookups, with the R13 decompositions, are W16R2's lookups** of the R13 data read as W16 data, over
`allFams`. -/
theorem w16Lookups_of_r13 (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) {ls : ℕ}
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) (hW : R13Windows S ls) (R : R13Rels S P L B E) (Lk : R13Lookups S P L B E) :
    W16Lookups S P L B (E.toW16 S) allFams := by
  obtain ⟨⟨ao1, ao2⟩, ⟨dn1, dn2⟩, ⟨q1, q2⟩, ⟨pv1, pv2⟩, ⟨k1, k2⟩, ⟨v1, v2⟩, ⟨ss1, ss2⟩, ⟨g1, g2⟩, ⟨up1, up2⟩,
    ⟨fp1, fp2⟩, ⟨wr1, wr2⟩, wr24, hprod⟩ := hW
  have rem := fun (b : ℕ) (hb : b ≤ 32) (R : GF) (hR : InRange b R) => remLk_all P.exp P.act S.nG hb R hR
  refine ⟨fun t i k => cvt8 (Lk.la t i k), fun t i k => cvt8 (Lk.lm t i k), fun p w hw => ?_, fun p => ?_,
    fun p w hw => ?_, fun p => ?_, fun p w hw => ?_, fun p => ?_, fun p => ⟨cvt8 (Lk.sB p).1, cvt8 (Lk.sB p).2⟩,
    fun p => ?_, fun p => ?_, fun p => ?_, fun p => ?_⟩
  · -- `Dom::D`'s seven words
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl | rfl | rfl | rfl | rfl
    · exact word_lk B.gD E.X E.xl _ (B.gD_one p) R.wX (Lk.xl p)
    · exact word_lk B.gD E.Y E.yl _ (B.gD_one p) R.wY (Lk.yl p)
    · exact word_lk B.gD E.AO E.aol _ (B.gD_one p) R.wAO (Lk.aol p)
    · exact word_lk B.gD E.X1 E.x1l _ (B.gD_one p) R.wX1 (Lk.x1l p)
    · exact word_lk B.gD E.YM E.yml _ (B.gD_one p) R.wYM (Lk.yml p)
    · exact word_lk B.gD E.Z E.zl _ (B.gD_one p) R.wZ (Lk.zl p)
    · exact word_lk B.gD E.X2 E.x2l _ (B.gD_one p) R.wX2 (Lk.x2l p)
  · -- `Dom::D`'s six remainders
    refine ⟨rem 24 (by norm_num) _ (inRange_congr (by norm_num) (bytes_rem _ _ (Lk.nr p))), rem 24 (by norm_num) _ (inRange_congr (by norm_num) (bytes_rem _ _ (Lk.ns p))),
      rem 24 (by norm_num) _ (inRange_congr (by norm_num) (bytes_rem _ _ (Lk.mr p))), rem 24 (by norm_num) _ (inRange_congr (by norm_num) (bytes_rem _ _ (Lk.ms p))),
      rem S.sao (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.ral p)),
      rem S.sdown (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rdl p))⟩
  · -- `Dom::Q`'s three words
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl
    · exact word_lk B.gQ E.Q E.ql _ (B.gQ_one p) R.wQ (Lk.ql p)
    · exact word_lk B.gQ E.QR E.qrl _ (B.gQ_one p) R.wQR (Lk.qrl p)
    · exact word_lk B.gQ E.O E.ol _ (B.gQ_one p) R.wO (Lk.ol p)
  · refine ⟨rem S.sq (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rql p)),
      rem 7 (by norm_num) _ (pin_rem _ _ (by norm_num) (by norm_num) (Lk.rqrl p)),
      rem S.spv (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.ro p))⟩
  · -- `Dom::Kv`'s three words
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hw
    rcases hw with rfl | rfl | rfl
    · exact word_lk B.gK E.K E.kl _ (B.gK_one p) R.wK (Lk.kl p)
    · exact word_lk B.gK E.V E.vl _ (B.gK_one p) R.wV (Lk.vl p)
    · exact word_lk B.gK E.KR E.krl _ (B.gK_one p) R.wKR (Lk.krl p)
  · refine ⟨rem S.sk (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rkl p)),
      rem S.sv (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rvl p)),
      rem 7 (by norm_num) _ (pin_rem _ _ (by norm_num) (by norm_num) (Lk.rkrl p))⟩
  · -- `Dom::S`: the score's remainder, the quotient, the two slacks
    have hP : E.PP (L.sPos p) = lv E.pl (L.sPos p) := sub_eq_zero.mp (gated_at _ _ R.s4 _ (B.gS_one p))
    refine ⟨rem S.ss (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rsl p)), ?_,
      rem S.wrho (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.sr p)),
      rem S.wrho (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.sg p))⟩
    show CodeTable allFams P.exp P.act S.nG (rangeQuery (tagW (S.fp + 1)) (E.PP (L.sPos p)))
    rw [hP]
    exact (codeTable_range_iff allFams_ok _ _ _ (mem_allFams _ (by omega)) _).mpr
      (pin_rem _ _ (by omega) (by omega) (Lk.pl p))
  · exact (codeTable_exp_iff allFams_ok _ _ _ _ _).mpr ((codeTable_exp_iff r13Fams_ok _ _ _ _ _).mp (Lk.sExp p))
  · -- `Dom::F`: the gate's remainder, `U`, the product word (its W16 split from its three bytes), its remainder
    have hU := word_lk B.gF E.U E.ul _ (B.gF_one p) R.f1 (Lk.ul p)
    have hH : E.H (L.fPos p) + 2 ^ 23 = lv E.hl (L.fPos p) := sub_eq_zero.mp (gated_at _ _ R.f2 _ (B.gF_one p))
    rw [lv_three] at hH
    have hb0 := inRange8_of (Lk.hl p 0)
    have hb1 := inRange8_of (Lk.hl p 1)
    have hb2 := inRange8_of (Lk.hl p 2)
    have hlo : InRange 16 (E.hl 0 (L.fPos p) + 2 ^ 8 * E.hl 1 (L.fPos p)) :=
      (limbs_iff 8 8 _).mp ⟨_, _, rfl, hb0, hb1⟩
    refine ⟨rem S.sgate (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.rgl p)), hU,
      rem S.sup (by omega) _ (pin_rem _ _ (by omega) (by omega) (Lk.ru p)), ?_, ?_, ?_⟩
    · show CodeTable allFams P.exp P.act S.nG
        (rangeQuery (tagW 16) (E.H (L.fPos p) - 2 ^ 16 * (E.hl 2 (L.fPos p) - 128)))
      have e : E.H (L.fPos p) - 2 ^ 16 * (E.hl 2 (L.fPos p) - 128)
          = E.hl 0 (L.fPos p) + 2 ^ 8 * E.hl 1 (L.fPos p) := by linear_combination hH
      rw [e]
      exact (codeTable_range_iff allFams_ok _ _ _ (mem_allFams 16 (by norm_num)) _).mpr hlo
    · show CodeTable allFams P.exp P.act S.nG (rangeQuery (tagW 8) ((E.hl 2 (L.fPos p) - 128) + 128))
      rw [sub_add_cancel]
      exact (codeTable_range_iff allFams_ok _ _ _ (mem_allFams 8 (by norm_num)) _).mpr hb2
    · have h16 : InRange S.sprod (lv E.rh (L.fPos p)) := by
        rw [hprod]
        exact inRange_congr (by norm_num) (bytes_rem _ _ (Lk.rh p))
      exact rem S.sprod (by rw [hprod]; norm_num) _ h16
  · exact (codeTable_act_iff allFams_ok _ _ _ _ _ _).mpr ((codeTable_act_iff r13Fams_ok _ _ _ _ _ _).mp (Lk.fAct p))

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- The widths the W16R2 theorem asks for are in `allFams` whenever the shifts are in their R13 windows. -/
theorem w16Widths_of_r13 {ls : ℕ} (hW : R13Windows S ls) : W16Widths S allFams := by
  obtain ⟨⟨ao1, ao2⟩, ⟨dn1, dn2⟩, ⟨q1, q2⟩, ⟨pv1, pv2⟩, ⟨k1, k2⟩, ⟨v1, v2⟩, ⟨ss1, ss2⟩, ⟨g1, g2⟩, ⟨up1, up2⟩,
    ⟨fp1, fp2⟩, ⟨wr1, wr2⟩, wr24, hprod⟩ := hW
  refine ⟨mem_allFams 8 (by norm_num), mem_allFams 16 (by norm_num), mem_allFams 7 (by norm_num),
    mem_allFams _ (by omega), fun b hb => ?_⟩
  have h24 : b ≤ 24 := by
    simp only [List.mem_cons, List.not_mem_nil, or_false] at hb
    rcases hb with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;> omega
  exact ⟨Or.inl (mem_allFams b (by omega)), fun _ => mem_allFams (b - 16) (by omega)⟩

/-- **The R13 layout map's theorem: the R13 slots' relations and LogUp's byte-table conclusion give `BlockSat`.** For
one R13 block at the LowH24 stack, with the shifts in their limb windows, the extracted planes `E` read through the
layout map `L` satisfy CircuitBlock's constraint system at every logical position (the witness reads E's own words:
`toWit L (E.toW16 S)` holds the same planes, `toWit_toW16`), with input plane `X ∘ dPos` and output plane
`X2 ∘ dPos`: the premise of `block_circuitIff`. By reduction to L11's `blockSat_of_slots`. -/
theorem blockSat_of_slots_r13 (P : BlockPublic S) (L : W16Layout S Ct Cw Cg Cj Cd Cf) (B : W16Pub S P L) {ls : ℕ}
    (E : R13Data Ct Cw Cg Cj Cd Cf ls) (hW : R13Windows S ls) (h24 : S.h24 = true) (R : R13Rels S P L B E)
    (Lk : R13Lookups S P L B E) :
    BlockSat P (fun p => E.X (L.dPos p)) (fun p => E.X2 (L.dPos p)) (toWit L (E.toW16 S)) :=
  blockSat_of_slots P L B (E.toW16 S) allFams allFams_ok (w16Widths_of_r13 hW) h24 (w16Rels_of_r13 P L B E R)
    (w16Lookups_of_r13 P L B E hW R Lk)

omit [Fintype Ct] [Fintype Cw] [Fintype Cg] [Fintype Cj] [Fintype Cd] [Fintype Cf] [DecidableEq Ct] [DecidableEq Cw]
  [DecidableEq Cg] [DecidableEq Cj] [DecidableEq Cd] [DecidableEq Cf] in
/-- The witness reads the R13 data's own words (nothing of the virtual limb pairs). -/
theorem toWit_toW16 (L : W16Layout S Ct Cw Cg Cj Cd Cf) {ls : ℕ} (E : R13Data Ct Cw Cg Cj Cd Cf ls) :
    (toWit L (E.toW16 S)).Y = (fun p => E.Y (L.dPos p)) ∧ (toWit L (E.toW16 S)).Hh = (fun p => E.H (L.fPos p))
      ∧ (toWit L (E.toW16 S)).PP = (fun p => E.PP (L.sPos p)) ∧ (toWit L (E.toW16 S)).Z = (fun p => E.Z (L.dPos p)) :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- **The R13 block computes the integer block** (`block_circuitIff`): if the committed input and output planes are
the images of int16 words `x`, `y`, the R13 relations and lookups give: `x` is admissible and `y` is the integer block's
output on `x`. -/
theorem r13_block_output (hS : S.Valid) (P : BlockPublic S) (hP : P.Valid) (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : W16Pub S P L) {ls : ℕ} (E : R13Data Ct Cw Cg Cj Cd Cf ls) (hW : R13Windows S ls) (h24 : S.h24 = true)
    (x y : S.Pos → ℤ) (hx : ∀ p, i16 (x p)) (hy : ∀ p, i16 (y p))
    (hX : ∀ p, E.X (L.dPos p) = (x p : GF)) (hY : ∀ p, E.X2 (L.dPos p) = (y p : GF))
    (R : R13Rels S P L B E) (Lk : R13Lookups S P L B E) :
    (blockModel S P).admissible x ∧ y = (blockModel S P).forward () x := by
  have hsat := blockSat_of_slots_r13 P L B E hW h24 R Lk
  have hX' : (fun p => E.X (L.dPos p)) = fun p => (x p : GF) := funext hX
  have hY' : (fun p => E.X2 (L.dPos p)) = fun p => (y p : GF) := funext hY
  rw [hX', hY'] at hsat
  exact (block_circuitIff hS P hP () x y).mp ⟨toWit L (E.toW16 S), hx, hy, hsat⟩

/-- **`hstart` at an R13 block's zone**: a false block statement dooms an R13 slot relation or a byte/exp/ACT
lookup. -/
theorem hstart_block_r13 (hS : S.Valid) (P : BlockPublic S) (hP : P.Valid) (L : W16Layout S Ct Cw Cg Cj Cd Cf)
    (B : W16Pub S P L) {ls : ℕ} (E : R13Data Ct Cw Cg Cj Cd Cf ls) (hW : R13Windows S ls) (h24 : S.h24 = true)
    (x y : S.Pos → ℤ) (hx : ∀ p, i16 (x p)) (hy : ∀ p, i16 (y p))
    (hX : ∀ p, E.X (L.dPos p) = (x p : GF)) (hY : ∀ p, E.X2 (L.dPos p) = (y p : GF))
    (hbad : ¬ ((blockModel S P).admissible x ∧ y = (blockModel S P).forward () x)) :
    ¬ R13Rels S P L B E ∨ ¬ R13Lookups S P L B E := by
  by_contra h
  push Not at h
  exact hbad (r13_block_output hS P hP L B E hW h24 x y hx hy hX hY h.1 h.2)

end Reduce

end ZK60.Layout.R13
