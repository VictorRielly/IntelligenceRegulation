/-
D63, step L2 (`CircuitIff`), families 4 to 6: ROPE, the SILU PRODUCT and the functional tables (the ACT/SiLU table and
the exp table), and the block's whole LogUp table.

The constraints, as the code builds them:
* RoPE (`qzc_w16`, argument_accuracy.rs:560-561, `SH_ROPE = 7`, layout.rs:67):
  `c·src + s·flip − 2^7·rot − R + 2^6 = 0`, where `flip` is the PARTNER of the source position (the top bit of the
  head-dimension coordinate flipped, `Coord::Flip`, :550-551) and the public tables are `c = cos[t][i]` and
  `s = −sin[t][i]` on the first half of the head, `+sin[t][i]` on the second (`rope_tables_at`, argument.rs:1897-1915).
  So position `i < half` hosts `cos·a − sin·b` and position `half + i` hosts `sin·a + cos·b` of the pair
  `(a, b) = (x[i], x[half + i])`, which is `rotate` (witness.rs:947-961) and `Model.rope`. `rot` is an int16 word
  (`word16`, accuracy_layout.rs:312, 318), `R` a 7-bit remainder (`Rqr`, `Rkr`). CS-4 bounds the tables:
  `|cos|, |sin| ≤ 2^F_RO = 2^7` (private_block.rs:635-639).
* the product (`fzc_w16`, argument_accuracy.rs:526): `a·u − 2^r·h − R + 2^(r−1) = 0`, `a` the ACT value, `u` the int16 up
  word, `h` the 24-bit product word (`word24`, accuracy_layout.rs:322), `R` its `r`-bit remainder (`Rh`, :324);
  `r = folds().product.shift`, 16 at LowH24 (accuracy_aligned.rs:25-28). The scaled ACT words are bounded,
  `|a| ≤ 32767·2^16 < 2^31` (accuracy_aligned.rs:44-45, `scaled_abs`, accuracy_tables.rs:16).
* the ACT tuple (`fzc_w16`, argument_accuracy.rs:527-528): the query `g + 2048 + β·a + β²·group + γ·TAG_ACT`, i.e. the
  tuple `(g + 2048, TAG_ACT, a, group)` folded by `fold β γ` (SoundLogUpBlock.lean); the table
  (`accuracy_act::table`, accuracy_act.rs:13-30) has the rows `(i, TAG_ACT, word_G[i], G)` for every registered group
  `G` and gate index `i ∈ [0, 4096)`, and pads with `(2048, TAG_ACT, 0, 0)`, which is group 0's row at `i = 2048`
  because `word_G[2048] = 0` (:22). The gate word has no range lookup of its own: the ACT tuple's index coordinate
  bounds it (`gateAct_iff`).
* the exp tuple (`szc_w16`, argument_accuracy.rs:631): `(δ, TAG_EXP, e, 0)`; the table rows `(i, TAG_EXP, exp[i], 0)`,
  `i ∈ [0, 256)` (`table_values_exp_at`, argument.rs:1947-1948).
* the tags (tables_attn.rs:49-77, range16.rs:25-46): `TAG_EXP = 129`, `TAG_U8 = 133`, `TAG_ACT = 134`, and the range
  family of width `w` at `200 + w` (the byte width keeps `TAG_U8`).

`codeTable_range_iff`, `codeTable_exp_iff` and `codeTable_act_iff` are the exact link to L3: `logup_block_bound`
(SoundLogUpBlock.lean) concludes that every looked-up tuple is a tuple of the block's table, `CodeTable`; these three
turn that membership into the facts the families use (`InRange w x`, the exp row, the ACT row).
-/
import ZK60Formal.CircuitMatmul

namespace ZK60.Circuit

open ZK60.Model
open ZK60.Sound (Tup)

/-! ## RoPE -/

/-- The RoPE clause at one position (argument_accuracy.rs:560-561). -/
def RopeRel (c s src flip rot R : GF) : Prop := c * src + s * flip - 2 ^ 7 * rot - R + 2 ^ 6 = 0

/-- The RoPE clause IS a host relation at shift 7, of the hosted value `c·src + s·flip`. -/
theorem ropeRel_iff (c s src flip rot R : GF) : RopeRel c s src flip rot R ↔ HostRel 7 (c * src + s * flip) rot R := by
  unfold RopeRel HostRel
  rw [show (7 - 1 : ℕ) = 6 from rfl]
  constructor <;> intro h <;> linear_combination -h

/-- The sign of the sine table on each half of the head (`rope_tables_at`, argument.rs:1912): `−` on the first half,
`+` on the second. -/
def ropeSgn : Bool → ℤ
  | false => -1
  | true => 1

theorem abs_ropeSgn_mul (b : Bool) (s : ℤ) : |ropeSgn b * s| = |s| := by
  cases b <;> simp [ropeSgn]

/-- **`CircuitIff` for one RoPE position**: the clause, the rotated word's int16 lookup and the 7-bit remainder hold
exactly when the integer model admits the rotation `c·a + s·b` and `rot` is its word. -/
theorem rope_iff (c s a b : ℤ) (hc : |c| ≤ 2 ^ 7) (hs : |s| ≤ 2 ^ 7) (ha : |a| ≤ 2 ^ 15) (hb : |b| ≤ 2 ^ 15)
    (rot : GF) :
    (∃ R : GF, RopeRel (c : GF) (s : GF) (a : GF) (b : GF) rot R ∧ Word16 rot ∧ RemW16 7 R) ↔
      ∃ v r : ℤ, requantIn (-2 ^ 15) (2 ^ 15 - 1) (c * a + s * b) 1 7 = some (v, r) ∧ rot = (v : GF) := by
  have hcast : (c : GF) * (a : GF) + (s : GF) * (b : GF) = ((c * a + s * b : ℤ) : GF) := by push_cast; ring
  obtain ⟨h1a, h1b⟩ := mul_bounds hc ha
  obtain ⟨h2a, h2b⟩ := mul_bounds hs hb
  have hl : -2 ^ 62 ≤ c * a + s * b := by norm_num at h1a h1b h2a h2b ⊢; linarith
  have hu : c * a + s * b ≤ 2 ^ 62 := by norm_num at h1a h1b h2a h2b ⊢; linarith
  refine Iff.trans ?_ (requant_iff word16Class 7 (by norm_num) (c * a + s * b) hl hu rot)
  refine exists_congr fun R => and_congr ?_ Iff.rfl
  rw [ropeRel_iff, hcast]

/-- The two positions of a RoPE pair host `Model.rope`'s two outputs: at `(false, i)` the source is `a = x[i]`, the
partner `b = x[half + i]` and the table pair `(cos, −sin)`; at `(true, i)` the source is `b`, the partner `a` and the
pair `(cos, +sin)`. -/
theorem rope_pair (c s a b : ℤ) :
    c * a + ropeSgn false * s * b = c * a - s * b ∧ c * b + ropeSgn true * s * a = s * a + c * b := by
  simp only [ropeSgn]
  constructor <;> ring

/-! ## The SiLU product -/

/-- The product clause `f0` (argument_accuracy.rs:526). -/
def ProdRel (r : ℕ) (a u h R : GF) : Prop := a * u - 2 ^ r * h - R + 2 ^ (r - 1) = 0

theorem prodRel_iff (r : ℕ) (a u h R : GF) : ProdRel r a u h R ↔ HostRel r (a * u) h R := by
  unfold ProdRel HostRel
  constructor <;> intro h' <;> linear_combination -h'

/-- **`CircuitIff` for one product position**: the clause, the 24-bit word lookups and the `r`-bit remainder hold
exactly when the integer model admits the product `a·u` and `h` is its word. -/
theorem product_iff (r : ℕ) (hr : r ≤ 24) (a u : ℤ) (ha : |a| ≤ 2 ^ 31) (hu : |u| ≤ 2 ^ 15) (h : GF) :
    (∃ R : GF, ProdRel r (a : GF) (u : GF) h R ∧ Word24 h ∧ RemW16 r R) ↔
      ∃ v rr : ℤ, requantIn (-2 ^ 23) (2 ^ 23 - 1) (a * u) 1 r = some (v, rr) ∧ h = (v : GF) := by
  have hcast : (a : GF) * (u : GF) = ((a * u : ℤ) : GF) := by push_cast; ring
  obtain ⟨hma, hmb⟩ := mul_bounds ha hu
  have hl : -2 ^ 62 ≤ a * u := by norm_num at hma hmb ⊢; linarith
  have hh : a * u ≤ 2 ^ 62 := by norm_num at hma hmb ⊢; linarith
  refine Iff.trans ?_ (requant_iff word24Class r hr (a * u) hl hh h)
  refine exists_congr fun R => and_congr ?_ Iff.rfl
  rw [prodRel_iff, hcast]

/-! ## The functional tables and the block's LogUp table -/

/-- `TAG_EXP` (tables_attn.rs:49). -/
abbrev tagExp : ℕ := 129
/-- `TAG_U8` (tables_attn.rs:70). -/
abbrev tagU8 : ℕ := 133
/-- `TAG_ACT` (tables_attn.rs:77). -/
abbrev tagAct : ℕ := 134
/-- The tag of a `w`-bit range lookup (`lk_tag`, `tag_value`, range16.rs:31-46): the byte width keeps `TAG_U8`. -/
def tagW (w : ℕ) : ℕ := if w = 8 then 133 else 200 + w

/-- Two tags below `p` with the same image in `GF` are equal. -/
theorem natCast_inj_lt {a b : ℕ} (ha : a < gP) (hb : b < gP) (h : (a : GF) = (b : GF)) : a = b := by
  have := (ZMod.natCast_eq_natCast_iff' a b gP).mp h
  rwa [Nat.mod_eq_of_lt ha, Nat.mod_eq_of_lt hb] at this

/-- The exp query `(δ, TAG_EXP, e, 0)` (argument_accuracy.rs:631). -/
def expQuery (δ e : GF) : Tup GF := ⟨δ, (tagExp : GF), e, 0⟩

/-- The exp table's rows `(i, TAG_EXP, exp[i], 0)`, `0 ≤ i < 256` (argument.rs:1947-1948). -/
def ExpTable (exp : ℤ → ℤ) (u : Tup GF) : Prop :=
  ∃ i : ℤ, 0 ≤ i ∧ i < 256 ∧ u = ⟨(i : GF), (tagExp : GF), (exp i : GF), 0⟩

/-- The ACT query `(g + 2048, TAG_ACT, a, group)` (argument_accuracy.rs:527). -/
def actQuery (g a : GF) (grp : ℕ) : Tup GF := ⟨g + 2048, (tagAct : GF), a, (grp : GF)⟩

/-- The ACT table's rows `(i, TAG_ACT, act G i, G)` for the registered groups `G < nG` and `0 ≤ i < 4096`
(accuracy_act.rs:21-27; the padding rows `(2048, TAG_ACT, 0, 0)` are group 0's row at `i = 2048`). -/
def ActTable (act : ℕ → ℤ → ℤ) (nG : ℕ) (u : Tup GF) : Prop :=
  ∃ G : ℕ, G < nG ∧ ∃ i : ℤ, 0 ≤ i ∧ i < 4096 ∧ u = ⟨(i : GF), (tagAct : GF), (act G i : GF), (G : GF)⟩

/-- **The exp tuple**: the query is a table row exactly when `δ` is an index `i ∈ [0, 256)` and `e = exp[i]`. -/
theorem expQuery_iff (exp : ℤ → ℤ) (δ e : GF) :
    ExpTable exp (expQuery δ e) ↔ ∃ i : ℤ, 0 ≤ i ∧ i < 256 ∧ δ = (i : GF) ∧ e = (exp i : GF) := by
  constructor
  · rintro ⟨i, h0, h1, he⟩
    exact ⟨i, h0, h1, congrArg Tup.x he, congrArg Tup.y he⟩
  · rintro ⟨i, h0, h1, rfl, rfl⟩
    exact ⟨i, h0, h1, rfl⟩

/-- **The ACT tuple**: for a registered group (`grp < nG ≤ p`), the query is a table row exactly when the gate word is
the image of an integer `g ∈ [−2048, 2047]` and `a` is the table's word at `g + 2048`. -/
theorem actQuery_iff (act : ℕ → ℤ → ℤ) (nG : ℕ) (hnG : nG ≤ gP) (g a : GF) (grp : ℕ) (hgrp : grp < nG) :
    ActTable act nG (actQuery g a grp) ↔
      ∃ gi : ℤ, -2048 ≤ gi ∧ gi ≤ 2047 ∧ g = (gi : GF) ∧ a = (act grp (gi + 2048) : GF) := by
  constructor
  · rintro ⟨G, hG, i, h0, h1, he⟩
    have hx : g + 2048 = (i : GF) := congrArg Tup.x he
    have hy : a = (act G i : GF) := congrArg Tup.y he
    have hz : ((grp : ℕ) : GF) = ((G : ℕ) : GF) := congrArg Tup.z he
    have hgG : grp = G := natCast_inj_lt (lt_of_lt_of_le hgrp hnG) (lt_of_lt_of_le hG hnG) hz
    subst hgG
    refine ⟨i - 2048, by linarith, by linarith, ?_, ?_⟩
    · push_cast
      linear_combination hx
    · rw [hy, sub_add_cancel]
  · rintro ⟨gi, h0, h1, rfl, rfl⟩
    refine ⟨grp, hgrp, gi + 2048, by linarith, by linarith, ?_⟩
    have hx : ((gi + 2048 : ℤ) : GF) = (gi : GF) + 2048 := by push_cast; ring
    rw [hx]
    rfl

/-- **The gate and its ACT tuple** (`fzc_w16`: the host `host_g`, argument_accuracy.rs:530, the remainder `Rg`,
accuracy_layout.rs:321, and the ACT tuple, :527-528): the gate's requantization needs NO word lookup of its own, the ACT
tuple's index coordinate supplies its class `[−2048, 2047]` (`gateClass`). -/
theorem gateAct_iff (act : ℕ → ℤ → ℤ) (nG : ℕ) (hnG : nG ≤ gP) (grp : ℕ) (hgrp : grp < nG) (s : ℕ) (hs : s ≤ 24)
    (A : ℤ) (hA1 : -2 ^ 62 ≤ A) (hA2 : A ≤ 2 ^ 62) (g a : GF) :
    (∃ R : GF, HostRel s (A : GF) g R ∧ RemW16 s R ∧ ActTable act nG (actQuery g a grp)) ↔
      ∃ v r : ℤ, requantIn (-2048) 2047 A 1 s = some (v, r) ∧ g = (v : GF) ∧ a = (act grp (v + 2048) : GF) := by
  rw [actQuery_iff act nG hnG g a grp hgrp]
  constructor
  · rintro ⟨R, hH, hR, gi, h0, h1, hg, ha⟩
    obtain ⟨v, r, hv, hgv⟩ : ∃ v r : ℤ, requantIn (-2048) 2047 A 1 s = some (v, r) ∧ g = (v : GF) :=
      (requant_iff gateClass s hs A hA1 hA2 g).mp ⟨R, hH, (gateWord_iff g).mpr ⟨gi, h0, h1, hg⟩, hR⟩
    obtain ⟨hlo, hhi, hw, -⟩ := requantIn_eq_some.mp hv
    rw [← hw] at hlo hhi
    have hgi : (gi : GF) = (v : GF) := by rw [← hg, hgv]
    have hvi : gi = v := int_eq_of_cast_eq hgi (by rw [gP_int]; linarith) (by rw [gP_int]; linarith)
    subst hvi
    exact ⟨gi, r, hv, hgv, ha⟩
  · rintro ⟨v, r, hv, hg, ha⟩
    obtain ⟨R, hH, -, hR⟩ := (requant_iff gateClass s hs A hA1 hA2 g).mpr ⟨v, r, hv, hg⟩
    obtain ⟨hlo, hhi, hw, -⟩ := requantIn_eq_some.mp hv
    rw [← hw] at hlo hhi
    exact ⟨R, hH, hR, v, hlo, hhi, hg, ha⟩

/-- **The block's LogUp table** (the `SC_TAB` relation, argument_accuracy.rs:416-444, and the range sub-planes of W16):
the range families `fams` (`(tag, width)`), the exp rows and the ACT rows. -/
def CodeTable (fams : List (ℕ × ℕ)) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ) (u : Tup GF) : Prop :=
  RangeTable fams u ∨ ExpTable exp u ∨ ActTable act nG u

/-- The premises on the family list: tags below `p`, distinct, and distinct from `TAG_EXP` and `TAG_ACT` (the code's
test `the_range_tags_are_distinct_from_every_other_family`, range16.rs:262-283). -/
structure FamsOK (fams : List (ℕ × ℕ)) : Prop where
  lt : ∀ f ∈ fams, f.1 < gP
  dist : ∀ f ∈ fams, ∀ g ∈ fams, f.1 = g.1 → f = g
  ne_exp : ∀ f ∈ fams, f.1 ≠ tagExp
  ne_act : ∀ f ∈ fams, f.1 ≠ tagAct

/-- **L3's conclusion, for a range lookup.** A range query of family `(tag, w)` is a tuple of the block's table exactly
when `InRange w x`. -/
theorem codeTable_range_iff {fams : List (ℕ × ℕ)} (hF : FamsOK fams) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    {tag w : ℕ} (hmem : (tag, w) ∈ fams) (x : GF) :
    CodeTable fams exp act nG (rangeQuery tag x) ↔ InRange w x := by
  rw [← rangeQuery_mem_iff fams hF.lt hF.dist hmem x]
  constructor
  · rintro (h | ⟨_, -, -, he⟩ | ⟨_, -, _, -, -, he⟩)
    · exact h
    · have ht : ((tag : ℕ) : GF) = ((tagExp : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (hF.lt _ hmem) (by norm_num) ht) (hF.ne_exp _ hmem)
    · have ht : ((tag : ℕ) : GF) = ((tagAct : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (hF.lt _ hmem) (by norm_num) ht) (hF.ne_act _ hmem)
  · exact Or.inl

/-- **L3's conclusion, for the exp lookup.** -/
theorem codeTable_exp_iff {fams : List (ℕ × ℕ)} (hF : FamsOK fams) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    (δ e : GF) : CodeTable fams exp act nG (expQuery δ e) ↔ ExpTable exp (expQuery δ e) := by
  constructor
  · rintro (⟨f, hf, _, -, -, he⟩ | h | ⟨_, -, _, -, -, he⟩)
    · have ht : ((tagExp : ℕ) : GF) = ((f.1 : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (by norm_num) (hF.lt _ hf) ht).symm (hF.ne_exp _ hf)
    · exact h
    · have ht : ((tagExp : ℕ) : GF) = ((tagAct : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (by norm_num) (by norm_num) ht) (by norm_num)
  · exact fun h => Or.inr (Or.inl h)

/-- **L3's conclusion, for the ACT lookup.** -/
theorem codeTable_act_iff {fams : List (ℕ × ℕ)} (hF : FamsOK fams) (exp : ℤ → ℤ) (act : ℕ → ℤ → ℤ) (nG : ℕ)
    (g a : GF) (grp : ℕ) : CodeTable fams exp act nG (actQuery g a grp) ↔ ActTable act nG (actQuery g a grp) := by
  constructor
  · rintro (⟨f, hf, _, -, -, he⟩ | ⟨_, -, -, he⟩ | h)
    · have ht : ((tagAct : ℕ) : GF) = ((f.1 : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (by norm_num) (hF.lt _ hf) ht).symm (hF.ne_act _ hf)
    · have ht : ((tagAct : ℕ) : GF) = ((tagExp : ℕ) : GF) := congrArg Tup.tag he
      exact absurd (natCast_inj_lt (by norm_num) (by norm_num) ht) (by norm_num)
    · exact h
  · exact fun h => Or.inr (Or.inr h)

/-- The W16R2 family list (`w16r2Fams`, CircuitField.lean) meets the premises. -/
theorem w16r2Fams_FamsOK : FamsOK w16r2Fams :=
  ⟨w16r2Fams_ok.1, w16r2Fams_ok.2, by decide, by decide⟩

end ZK60.Circuit
