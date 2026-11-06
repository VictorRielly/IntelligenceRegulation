/-
D63, step L2, the run's last stage: **stage OUT** (the next token) and **stage OUT-C** (the classifier's verdict),
per row, at their logical positions (`ops/zkp-mvp/gpu-metal/hashline/src/private_block/token_io/stage_out.rs`,
`stage_out_c.rs`).

Stage OUT reads `x = B_out` row `T − 1`, applies the final RMSNorm with a uniform gain, forms the raw-integer logits
through the public int8 head (VIRTUAL: never committed; the head sumcheck `SO_HEAD` is hosted by `SO_VZC`), and proves
the KEYED greedy argmax: with `tok = j`, `M = l_j`, `e` the indicator of `j` and the keyed difference
`δ_z = 2^v·(M − l_z) + (z − j)` in `limbs` bytes, the clauses are (stage_out.rs:456-508, 532-538)
* `SO_VZC`: `e_z·(1 − e_z) = 0`, the byte lookups of `δ_z`'s limbs, and the host term
  `l*_z = M + 2^{−v}·(z − tok − δ_z)` on `SO_HEAD`'s sum `Σ_i y_i·W'(r_j, i)`, i.e. `l*_z = l_z` at every live `z`;
* `SO_RSEL`: `Σ_z e_z = 1`, `Σ_z e_z·z = tok`, `Σ_z e_z·δ_z = 0` (three identities, each with its own coefficient);
* `SO_IOOUT`: the output token endpoint's word 0 is `tok`.

`δ_z ≥ 0` at every `z` says `l_z ≤ M` with equality only for `z ≥ j`: `j` is the FIRST maximum. `argmax_iff` is the
iff with numpy's tie rule (`first_argmax`, stage_out.rs:193-201); `argmaxN` is that loop (ModelOut.lean).

Stage OUT-C reads its public verdict row, applies the same final norm, and proves the margin identity
`Δ = σ·δ + (b + c)` (the PD sum `Σ_i y_i·w_Δ(i)` hosted by LZC's term `σ·g(z)·limb(z) + u0(z)·(b + c)`,
stage_out_c.rs:349-370), `σ = 1` when the public verdict `b` is 1 and `−1` otherwise, `δ` in `limbs` bytes:
`verdict_iff`, the verdict is `1` exactly when `Δ > c`.

The final norm (`SO_SS`/`SO_TZC`/`SO_DZC`, stage_out.rs:366-394, 421-455) is the block's norm relation with three
differences, each proved here: a uniform gain `g0`, the word a symmetric int8 (`WordS8`: the byte lookups `y + 127`
and `127 − y`), and 32-bit remainders in four byte limbs (`NORM_LIMBS = 4`); the input word is checked by two byte
limbs (`x + 32768 = xl0 + 256·xl1`, the DZC clause `c2`). `byteLimbs_iff`: `k` byte limbs certify exactly
`InRange (8k)`.

The hosted identities and the lookups are L3's conclusions (premises, as in `BlockSat`): every clause is stated at
the logical positions `i < d`, `z < V`; the pad clauses of the committed layout (the `zeta_fold` of every plane beyond
the support) are the layout map's part.
-/
import ZK60Formal.CircuitBlock
import ZK60Formal.ModelOut

namespace ZK60.Out

open ZK60 ZK60.Model ZK60.Circuit ZK60.Block

/-! ## Byte limbs -/

/-- `k` byte limbs recomposed as `R = Σ_j 2^(8j)·b_j`, each looked up in the byte table (`bytes_of`, `lb` in the
code: stage_out.rs:236-238, 442; the lookups `byte(p)` of `lookups_do` / `lookups_vo`, :145-153). -/
def ByteLimbs (k : ℕ) (R : GF) : Prop :=
  ∃ b : Fin k → GF, R = ∑ j : Fin k, (2 : GF) ^ (8 * (j : ℕ)) * b j ∧ ∀ j, InRange 8 (b j)

/-- **`k` byte limbs certify exactly one `8k`-bit range fact.** -/
theorem byteLimbs_iff (k : ℕ) (R : GF) : ByteLimbs k R ↔ InRange (8 * k) R := by
  induction k generalizing R with
  | zero =>
    constructor
    · rintro ⟨b, hR, -⟩
      exact ⟨0, le_refl _, by norm_num, by rw [hR]; simp⟩
    · rintro ⟨t, h0, h1, rfl⟩
      have ht : t = 0 := by norm_num at h1; omega
      exact ⟨Fin.elim0, by simp [ht], fun j => j.elim0⟩
  | succ k ih =>
    rw [show 8 * (k + 1) = 8 * k + 8 by ring, ← limbs_iff (8 * k) 8 R]
    constructor
    · rintro ⟨b, hR, hb⟩
      refine ⟨∑ j : Fin k, (2 : GF) ^ (8 * (j : ℕ)) * b (Fin.castSucc j), b (Fin.last k), ?_,
        (ih _).mp ⟨fun j => b (Fin.castSucc j), rfl, fun j => hb _⟩, hb _⟩
      rw [hR, Fin.sum_univ_castSucc]
      simp only [Fin.val_castSucc, Fin.val_last]
    · rintro ⟨lo, hi, hR, hlo, hhi⟩
      obtain ⟨b, hb, hbr⟩ := (ih lo).mpr hlo
      refine ⟨Fin.snoc (α := fun _ => GF) b hi, ?_, ?_⟩
      · rw [hR, Fin.sum_univ_castSucc, hb]
        simp only [Fin.snoc_castSucc, Fin.snoc_last, Fin.val_castSucc, Fin.val_last]
      · intro j
        refine Fin.lastCases ?_ (fun j => ?_) j
        · simp only [Fin.snoc_last]; exact hhi
        · simp only [Fin.snoc_castSucc]; exact hbr j

/-- The input word check of the final norm (the DZC clause `c2`, stage_out.rs:448, with the byte lookups of `xl0`,
`xl1`): two byte limbs of `x + 32768` certify exactly that `x` is an int16 word. -/
theorem xBytes_iff (x : GF) : ByteLimbs 2 (x + 32768) ↔ Word16 x := by
  rw [byteLimbs_iff]
  rfl

/-! ## The first argmax -/

theorem argmaxN_succ (f : ℕ → ℤ) (n : ℕ) :
    argmaxN f (n + 1) = if f (argmaxN f n) < f n then n else argmaxN f n := by
  unfold argmaxN
  rw [List.range_succ, List.foldl_append]
  rfl

/-- What `first_argmax` returns: an index below `n`, a maximum, and strictly above every earlier value. -/
theorem argmaxN_spec (f : ℕ → ℤ) (n : ℕ) (hn : 1 ≤ n) :
    argmaxN f n < n ∧ (∀ i < n, f i ≤ f (argmaxN f n)) ∧ (∀ i < argmaxN f n, f i < f (argmaxN f n)) := by
  induction n with
  | zero => omega
  | succ n ih =>
    rcases Nat.eq_zero_or_pos n with h0 | hpos
    · subst h0
      have h1 : argmaxN f 1 = 0 := by
        rw [argmaxN_succ]
        simp [argmaxN]
      rw [h1]
      refine ⟨by omega, fun i hi => ?_, fun i hi => absurd hi (Nat.not_lt_zero _)⟩
      rw [show i = 0 by omega]
    · obtain ⟨h1, h2, h3⟩ := ih hpos
      rw [argmaxN_succ]
      split_ifs with hc
      · refine ⟨by omega, fun i hi => ?_, fun i hi => lt_of_le_of_lt (h2 i hi) hc⟩
        rcases Nat.lt_succ_iff_lt_or_eq.mp hi with hi | hi
        · exact le_of_lt (lt_of_le_of_lt (h2 i hi) hc)
        · rw [hi]
      · push Not at hc
        refine ⟨by omega, fun i hi => ?_, h3⟩
        rcases Nat.lt_succ_iff_lt_or_eq.mp hi with hi | hi
        · exact h2 i hi
        · rw [hi]; exact hc

/-- The first maximum is unique: any index that is a maximum and strictly above every earlier value is
`first_argmax`'s. -/
theorem argmaxN_unique (f : ℕ → ℤ) (n j : ℕ) (hj : j < n) (hmax : ∀ i < n, f i ≤ f j)
    (hfirst : ∀ i < j, f i < f j) : j = argmaxN f n := by
  obtain ⟨hb, h2, h3⟩ := argmaxN_spec f n (by omega)
  have e1 := h2 j hj
  have e2 := hmax _ hb
  rcases lt_trichotomy j (argmaxN f n) with h | h | h
  · exact absurd (h3 j h) (not_lt.mpr e2)
  · exact h
  · exact absurd (hfirst _ h) (not_lt.mpr e1)

/-- The logits as a function on `ℕ` (`0` beyond `V`), the form `argmaxN` reads. -/
def lfun {V : ℕ} (l : Fin V → ℤ) (i : ℕ) : ℤ := if h : i < V then l ⟨i, h⟩ else 0

theorem lfun_fin {V : ℕ} (l : Fin V → ℤ) (z : Fin V) : lfun l z = l z := by
  unfold lfun
  simp [z.isLt]

/-! ## The keyed argmax relation -/

theorem two_ne_zero_gf : (2 : GF) ≠ 0 := by decide

theorem two_pow_ne_zero_gf (v : ℕ) : (2 : GF) ^ v ≠ 0 := pow_ne_zero v two_ne_zero_gf

/-- **The keyed argmax clauses at the logical positions `z < V`** (stage_out.rs:456-508): `lg z` is the hosted head
value at `z` (the `SO_HEAD` sum `Σ_i y_i·(m_z·W'[z][i])`), `tok` and `M` the two fixed-point words of `To`, `e` the
selector and `δ` the keyed difference. -/
structure ArgRel {V : ℕ} (vlog k : ℕ) (lg : Fin V → GF) (tok M : GF) (e δ : Fin V → GF) : Prop where
  /-- `SO_VZC`'s `e(1 − e)` (stage_out.rs:485) -/
  bool : ∀ z, e z * (1 - e z) = 0
  /-- the keyed difference's byte limbs (`lookups_vo`, :151; `SO_VZC`'s helpers) -/
  limbs : ∀ z, ByteLimbs k (δ z)
  /-- `SO_VZC`'s host term on `SO_HEAD`: `l* = M + 2^{−v}(ι − tok − δ)` is the logit (:483) -/
  host : ∀ z : Fin V, M + ((2 : GF) ^ vlog)⁻¹ * (((z : ℕ) : GF) - tok - δ z) = lg z
  /-- `SO_RSEL`'s three identities A2, A3, A6 (:493-508) -/
  sum1 : ∑ z, e z = 1
  sumz : ∑ z : Fin V, e z * ((z : ℕ) : GF) = tok
  sumd : ∑ z, e z * δ z = 0

/-- A boolean selector summing to one over fewer than `p` positions is the indicator of one position. -/
theorem selector_one {V : ℕ} (hV : V < gP) (e : Fin V → GF) (hb : ∀ z, e z * (1 - e z) = 0)
    (hs : ∑ z, e z = 1) : ∃ z0, ∀ z, e z = if z = z0 then 1 else 0 := by
  have h01 : ∀ z, e z = 0 ∨ e z = 1 := fun z => by
    rcases mul_eq_zero.mp (hb z) with h | h
    · exact Or.inl h
    · exact Or.inr (sub_eq_zero.mp h).symm
  have hsum : ∑ z, e z = ∑ z, (if e z = 1 then (1 : GF) else 0) :=
    Finset.sum_congr rfl fun z _ => by rcases h01 z with h | h <;> simp [h]
  rw [hsum, Finset.sum_boole] at hs
  have hc : (Finset.univ.filter fun z => e z = 1).card = 1 := by
    have hle : (Finset.univ.filter fun z => e z = 1).card ≤ V := by
      simpa using Finset.card_filter_le (Finset.univ : Finset (Fin V)) (fun z => e z = 1)
    have h1 : ((Finset.univ.filter fun z => e z = 1).card : GF) = ((1 : ℕ) : GF) := by
      rw [Nat.cast_one]; exact hs
    exact natCast_inj_lt (lt_of_le_of_lt hle hV) (show 1 < gP by norm_num) h1
  obtain ⟨z0, hz0⟩ := Finset.card_eq_one.mp hc
  refine ⟨z0, fun z => ?_⟩
  by_cases hz : z = z0
  · rw [ite_eq_left hz]
    have : z ∈ Finset.univ.filter fun z => e z = 1 := by rw [hz0, hz]; exact Finset.mem_singleton_self _
    exact (Finset.mem_filter.mp this).2
  · rw [ite_eq_right hz]
    have : z ∉ Finset.univ.filter fun z => e z = 1 := by rw [hz0]; simpa using hz
    rcases h01 z with h | h
    · exact h
    · exact (this (Finset.mem_filter.mpr ⟨Finset.mem_univ z, h⟩)).elim

theorem sum_indicator {V : ℕ} (z0 : Fin V) (g : Fin V → GF) :
    ∑ z, (if z = z0 then (1 : GF) else 0) * g z = g z0 := by
  simp [ite_mul]

/-- **`CircuitIff` for the keyed greedy argmax.** For integer logits `|l_z| ≤ L` over `1 ≤ V ≤ 2^v` entries, with the
door's two conditions on the limbs (token_io.rs:510-518: the honest keyed difference fits its `k` bytes, and the bytes
with the identity's right side do not wrap `p`): the clauses hold for the committed `tok` exactly when `tok` is the
FIRST maximum of the logits (`first_argmax`, numpy's tie rule). -/
theorem argmax_iff {V : ℕ} (vlog k : ℕ) (hV : 1 ≤ V) (hVv : V ≤ 2 ^ vlog) (L : ℤ) (l : Fin V → ℤ)
    (hl : ∀ z, |l z| ≤ L) (hwin : (2 : ℤ) ^ vlog * (2 * L) + V ≤ 2 ^ (8 * k))
    (hnw : (2 : ℤ) ^ (8 * k) + 2 ^ vlog * (2 * L) + V < gP) (tok : GF) :
    (∃ M : GF, ∃ e δ : Fin V → GF, ArgRel vlog k (fun z => (l z : GF)) tok M e δ) ↔
      tok = ((argmaxN (lfun l) V : ℕ) : GF) := by
  have hP : (0 : ℤ) < 2 ^ vlog := by positivity
  have hVv' : (V : ℤ) ≤ 2 ^ vlog := by exact_mod_cast hVv
  have hL0 : 0 ≤ L := le_trans (abs_nonneg _) (hl ⟨0, by omega⟩)
  have h2L : (0 : ℤ) ≤ 2 ^ vlog * (2 * L) := by positivity
  have hVp : V < gP := by
    have : (V : ℤ) < gP := by linarith [pow_pos (show (0 : ℤ) < 2 by norm_num) (8 * k)]
    exact_mod_cast this
  have h2v := two_pow_ne_zero_gf vlog
  -- the difference of two logits, scaled
  have hdl : ∀ a b : Fin V, -(2 ^ vlog * (2 * L)) ≤ 2 ^ vlog * (l a - l b) ∧
      2 ^ vlog * (l a - l b) ≤ 2 ^ vlog * (2 * L) := fun a b => by
    have ha := abs_le.mp (hl a)
    have hb := abs_le.mp (hl b)
    constructor
    · have : -(2 * L) ≤ l a - l b := by linarith
      nlinarith
    · have : l a - l b ≤ 2 * L := by linarith
      nlinarith
  constructor
  · rintro ⟨M, e, δ, hr⟩
    obtain ⟨z0, he⟩ := selector_one hVp e hr.bool hr.sum1
    have hsel : ∀ g : Fin V → GF, ∑ z, e z * g z = g z0 := fun g => by
      rw [show (∑ z, e z * g z) = ∑ z, (if z = z0 then (1 : GF) else 0) * g z from
        Finset.sum_congr rfl fun z _ => by rw [he z]]
      exact sum_indicator z0 g
    have htok : tok = (((z0 : ℕ)) : GF) := by rw [← hr.sumz, hsel]
    have hδ0 : δ z0 = 0 := by rw [← hr.sumd, hsel]
    -- the integer keyed differences
    have hd := fun z => (byteLimbs_iff k (δ z)).mp (hr.limbs z)
    choose dd hdd0 hdd1 hddδ using hd
    have hdd0z : dd z0 = 0 := by
      have h : ((dd z0 : ℤ) : GF) = ((0 : ℤ) : GF) := by rw [← hddδ, hδ0]; simp
      exact int_eq_of_cast_eq h (by linarith [hdd0 z0]) (by linarith [hdd1 z0])
    -- `M` is the chosen logit
    have hM : M = (l z0 : GF) := by
      have h := hr.host z0
      rw [htok, hδ0, sub_self, sub_zero, mul_zero, add_zero] at h
      exact h
    -- every keyed difference is the integer `2^v (l_{z0} − l_z) + z − z0`
    have hE : ∀ z, dd z = 2 ^ vlog * (l z0 - l z) + (z : ℕ) - (z0 : ℕ) := fun z => by
      have h := hr.host z
      rw [hM, htok, hddδ z] at h
      have h' : (((2 ^ vlog * (l z0 - l z) + (z : ℕ) - (z0 : ℕ) - dd z : ℤ)) : GF) = 0 := by
        have h1 : (2 : GF) ^ vlog * ((l z0 : GF) + ((2 : GF) ^ vlog)⁻¹ * (((z : ℕ) : GF) - ((z0 : ℕ) : GF) -
            (dd z : GF))) = (2 : GF) ^ vlog * (l z : GF) := by rw [h]
        rw [mul_add, ← mul_assoc, mul_inv_cancel₀ h2v, one_mul] at h1
        push_cast
        linear_combination h1
      have hz := z.isLt
      have hz0 := z0.isLt
      have hzi : ((z : ℕ) : ℤ) < V := by exact_mod_cast hz
      have hz0i : ((z0 : ℕ) : ℤ) < V := by exact_mod_cast hz0
      have hzn : (0 : ℤ) ≤ (z : ℕ) := Int.natCast_nonneg _
      have hz0n : (0 : ℤ) ≤ (z0 : ℕ) := Int.natCast_nonneg _
      have hb := hdl z0 z
      have e0 := int_eq_of_cast_eq (a := 2 ^ vlog * (l z0 - l z) + (z : ℕ) - (z0 : ℕ) - dd z) (b := 0)
        (by rw [h']; simp) (by linarith [hdd1 z]) (by linarith [hdd0 z])
      linarith
    -- so `z0` is a maximum, strictly above every earlier logit
    have hmax : ∀ z, l z ≤ l z0 := fun z => by
      by_contra hc
      push Not at hc
      have h1 : l z0 - l z ≤ -1 := by linarith
      have h2 : 2 ^ vlog * (l z0 - l z) ≤ 2 ^ vlog * (-1) := mul_le_mul_of_nonneg_left h1 (le_of_lt hP)
      have hzi : ((z : ℕ) : ℤ) < V := by exact_mod_cast z.isLt
      have hz0n : (0 : ℤ) ≤ (z0 : ℕ) := Int.natCast_nonneg _
      linarith [hE z, hdd0 z]
    have hfirst : ∀ z : Fin V, (z : ℕ) < z0 → l z < l z0 := fun z hz => by
      rcases lt_or_eq_of_le (hmax z) with h | h
      · exact h
      · have hz' : ((z : ℕ) : ℤ) < (z0 : ℕ) := by exact_mod_cast hz
        have := hE z
        rw [h, sub_self, mul_zero] at this
        linarith [hdd0 z]
    have hj : (z0 : ℕ) = argmaxN (lfun l) V :=
      argmaxN_unique (lfun l) V z0 z0.isLt
        (fun i hi => by rw [show lfun l i = l ⟨i, hi⟩ by simp [lfun, hi], lfun_fin]; exact hmax _)
        (fun i hi => by
          rw [show lfun l i = l ⟨i, lt_trans hi z0.isLt⟩ by simp [lfun, lt_trans hi z0.isLt], lfun_fin]
          exact hfirst ⟨i, lt_trans hi z0.isLt⟩ hi)
    rw [htok, hj]
  · intro htok
    obtain ⟨hb, h2, h3⟩ := argmaxN_spec (lfun l) V hV
    set j := argmaxN (lfun l) V with hjdef
    let z0 : Fin V := ⟨j, hb⟩
    have hlz0 : lfun l j = l z0 := by simp [lfun, hb, z0]
    have hmax : ∀ z : Fin V, l z ≤ l z0 := fun z => by
      have := h2 z z.isLt
      rwa [lfun_fin, hlz0] at this
    have hfirst : ∀ z : Fin V, (z : ℕ) < j → l z < l z0 := fun z hz => by
      have := h3 z hz
      rwa [lfun_fin, hlz0] at this
    let dz : Fin V → ℤ := fun z => 2 ^ vlog * (l z0 - l z) + (z : ℕ) - j
    have hdz0 : ∀ z, 0 ≤ dz z := fun z => by
      have hzn : (0 : ℤ) ≤ (z : ℕ) := Int.natCast_nonneg _
      have hjV : (j : ℤ) < V := by exact_mod_cast hb
      rcases lt_or_eq_of_le (hmax z) with h | h
      · have h1 : 1 ≤ l z0 - l z := by linarith
        have h4 : 2 ^ vlog * 1 ≤ 2 ^ vlog * (l z0 - l z) := mul_le_mul_of_nonneg_left h1 (le_of_lt hP)
        show 0 ≤ 2 ^ vlog * (l z0 - l z) + (z : ℕ) - j
        linarith
      · have hzj : ¬ (z : ℕ) < j := fun hz => absurd (hfirst z hz) (by rw [h]; exact lt_irrefl _)
        have hzj' : (j : ℤ) ≤ (z : ℕ) := by exact_mod_cast not_lt.mp hzj
        show 0 ≤ 2 ^ vlog * (l z0 - l z) + (z : ℕ) - j
        rw [h, sub_self, mul_zero]
        linarith
    have hdz1 : ∀ z, dz z < 2 ^ (8 * k) := fun z => by
      have hzi : ((z : ℕ) : ℤ) < V := by exact_mod_cast z.isLt
      have hjn : (0 : ℤ) ≤ j := Int.natCast_nonneg _
      show 2 ^ vlog * (l z0 - l z) + (z : ℕ) - j < 2 ^ (8 * k)
      linarith [(hdl z0 z).2]
    refine ⟨(l z0 : GF), fun z => if z = z0 then 1 else 0, fun z => (dz z : GF), ⟨?_, ?_, ?_, ?_, ?_, ?_⟩⟩
    · intro z
      by_cases hz : z = z0 <;> simp [hz]
    · exact fun z => (byteLimbs_iff k _).mpr ⟨dz z, hdz0 z, hdz1 z, rfl⟩
    · intro z
      rw [htok]
      have h1 : ((z : ℕ) : GF) - ((j : ℕ) : GF) - ((dz z : ℤ) : GF) =
          (2 : GF) ^ vlog * (-((l z0 : GF) - (l z : GF))) := by
        show ((z : ℕ) : GF) - ((j : ℕ) : GF) - (((2 ^ vlog * (l z0 - l z) + (z : ℕ) - j : ℤ)) : GF) = _
        push_cast
        ring
      rw [h1, ← mul_assoc, inv_mul_cancel₀ h2v, one_mul]
      ring
    · simp
    · rw [htok, sum_indicator]
    · rw [sum_indicator]
      show (((2 ^ vlog * (l z0 - l z0) + ((z0 : ℕ) : ℤ) - j : ℤ)) : GF) = 0
      simp [z0]

/-! ## The final norm -/

/-- The sum of squares of an int16 row with `1 ≤ ceps ≤ 2^40` over at most `4096` positions is in `[1, 2^60)`. -/
theorem ss_bounds40 {n : ℕ} (hn : n ≤ 4096) (x : Fin n → ℤ) (ceps : ℤ) (hx : ∀ i, i16 (x i)) (hc0 : 1 ≤ ceps)
    (hc1 : ceps ≤ 2 ^ 40) : 1 ≤ ssOf ceps x ∧ ssOf ceps x < 2 ^ 60 := by
  have h0 : 0 ≤ ∑ i, x i * x i := Finset.sum_nonneg fun i _ => mul_self_nonneg (x i)
  have h := dot_abs_le x x (X := 2 ^ 15) (Wb := 2 ^ 15) (fun i => abs_le_of_int16 (hx i))
    (fun i => abs_le_of_int16 (hx i))
  have hN' : (Fintype.card (Fin n) : ℤ) ≤ 4096 := by rw [Fintype.card_fin]; exact_mod_cast hn
  have h2 : (Fintype.card (Fin n) : ℤ) * (2 ^ 15 * 2 ^ 15) ≤ 4096 * (2 ^ 15 * 2 ^ 15) :=
    mul_le_mul_of_nonneg_right hN' (by norm_num)
  have h3 : ∑ i, x i * x i ≤ |∑ i, x i * x i| := le_abs_self _
  unfold ssOf
  constructor <;> linarith

theorem fnormElem_eq_some {tn : ℕ} {cn g0 : ℤ} {wrho : ℕ} {d x q r s : ℤ} :
    fnormElem tn cn g0 wrho d x = some (q, r, s) ↔
      (-127 ≤ (2 * x * g0 * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ∧
        (2 * x * g0 * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ≤ 127 ∧
        (2 * x * g0 * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) < 2 ^ wrho ∧
        2 * (d * 2 ^ tn) - 1 - (2 * x * g0 * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) < 2 ^ wrho) ∧
      q = (2 * x * g0 * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) ∧
      r = (2 * x * g0 * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) ∧
      s = 2 * (d * 2 ^ tn) - 1 - (2 * x * g0 * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) := by
  simp only [fnormElem]
  split_ifs with h
  · constructor
    · intro he
      simp only [Option.some.injEq, Prod.mk.injEq] at he
      exact ⟨h, he.1.symm, he.2.1.symm, he.2.2.symm⟩
    · rintro ⟨_, rfl, rfl, rfl⟩
      rfl
  · constructor
    · intro he
      exact absurd he (by simp)
    · rintro ⟨h', _⟩
      exact absurd h' h

/-- **`CircuitIff` for one element of the final norm** (the DZC clauses `c0`, `c1`, stage_out.rs:446-447; the four
byte limbs of each remainder; `y`'s symmetric int8 lookups): given the row's `1 ≤ d < 2^24`, an int16 `x`, `|g0| ≤ 127`,
`|cn| ≤ 2^20` and `tn ≤ 16`. -/
theorem fnormDiv_iff (tn : ℕ) (htn : tn ≤ 16) (cn g0 x d : ℤ) (hcn : |cn| ≤ 2 ^ 20) (hg : |g0| ≤ 127)
    (hx : |x| ≤ 2 ^ 15) (hd1 : 1 ≤ d) (hd2 : d < 2 ^ 24) (y : GF) :
    ((∃ nr ns : GF, NormDivRel tn (cn : GF) (g0 : GF) (x : GF) (d : GF) y nr ns ∧ ByteLimbs 4 nr ∧
        ByteLimbs 4 ns) ∧ WordS8 y) ↔
      ∃ q r s, fnormElem tn cn g0 32 d x = some (q, r, s) ∧ y = (q : GF) := by
  have hT0 : (0 : ℤ) < 2 ^ tn := by positivity
  have hT : (2 : ℤ) ^ tn ≤ 2 ^ 16 := pow_le_pow_right₀ (by norm_num) htn
  have hden : (2 : ℤ) ^ (tn + 1) * d = 2 * (d * 2 ^ tn) := by ring
  have hdT1 : 0 < d * 2 ^ tn := mul_pos (by linarith) hT0
  have hdT2 : d * 2 ^ tn ≤ 2 ^ 40 := by
    have h1 : d * 2 ^ tn ≤ 2 ^ 24 * 2 ^ tn := mul_le_mul_of_nonneg_right (le_of_lt hd2) (le_of_lt hT0)
    have h2 : (2 : ℤ) ^ 24 * 2 ^ tn ≤ 2 ^ 24 * 2 ^ 16 := mul_le_mul_of_nonneg_left hT (by norm_num)
    linarith
  have hden0 : (0 : ℤ) < 2 * (d * 2 ^ tn) := by linarith
  have hgx := mul_bounds hg hx
  have hc2 : |2 * cn| ≤ 2 ^ 21 := by
    rw [abs_mul, abs_two]; linarith
  have hgxc := mul_bounds (abs_le.mpr ⟨by linarith [hgx.1], by linarith [hgx.2]⟩ : |g0 * x| ≤ 127 * 2 ^ 15) hc2
  have hb4 : ∀ R : GF, ByteLimbs 4 R ↔ InRange 32 R := fun R => by rw [byteLimbs_iff]
  constructor
  · rintro ⟨⟨nr, ns, ⟨h1, h2⟩, hnr, hns⟩, hy⟩
    obtain ⟨yi, hy0, hy1, rfl⟩ := (wordS8_iff y).mp hy
    obtain ⟨a, ha0, ha1, rfl⟩ := (hb4 nr).mp hnr
    obtain ⟨b, hb0, hb1, rfl⟩ := (hb4 ns).mp hns
    have hyb : |yi| ≤ 127 := abs_le.mpr ⟨by linarith, by linarith⟩
    have hKb : |2 * (d * 2 ^ tn)| ≤ 2 ^ 41 := by
      rw [abs_of_pos hden0]; linarith
    have hKy := mul_bounds hKb hyb
    have e1 : ((g0 * x * (2 * cn) + d * 2 ^ tn - 2 * (d * 2 ^ tn) * yi - a : ℤ) : GF) = 0 := by
      push_cast; linear_combination h1
    have e2 : ((a + b + 1 - 2 * (d * 2 ^ tn) : ℤ) : GF) = 0 := by
      push_cast; linear_combination h2
    have E1 := int_eq_zero_of_cast e1 (by nlinarith [hgxc.1, hKy.2]) (by nlinarith [hgxc.2, hKy.1])
    have E2 := int_eq_zero_of_cast e2 (by linarith) (by linarith)
    have hdiv : (2 * x * g0 * cn + d * 2 ^ tn) / (2 * (d * 2 ^ tn)) = yi ∧
        (2 * x * g0 * cn + d * 2 ^ tn) % (2 * (d * 2 ^ tn)) = a :=
      (Int.ediv_emod_unique hden0).mpr ⟨by linarith, ha0, by linarith⟩
    refine ⟨yi, a, b, fnormElem_eq_some.mpr ⟨⟨?_, ?_, ?_, ?_⟩, hdiv.1.symm, hdiv.2.symm, ?_⟩, rfl⟩
    · rw [hdiv.1]; exact hy0
    · rw [hdiv.1]; exact hy1
    · rw [hdiv.2]; exact ha1
    · rw [hdiv.2]; linarith
    · rw [hdiv.2]; linarith
  · rintro ⟨q, r, s, hspec, rfl⟩
    obtain ⟨⟨hq0, hq1, hr1, hs1⟩, hq, hr, hs⟩ := fnormElem_eq_some.mp hspec
    have hr0 : 0 ≤ r := by rw [hr]; exact Int.emod_nonneg _ (ne_of_gt hden0)
    have hrl : r < 2 * (d * 2 ^ tn) := by rw [hr]; exact Int.emod_lt_of_pos _ hden0
    have hsr : 0 ≤ s := by rw [hs, ← hr]; linarith
    have hm := Int.mul_ediv_add_emod (2 * x * g0 * cn + d * 2 ^ tn) (2 * (d * 2 ^ tn))
    refine ⟨⟨(r : GF), (s : GF), ⟨?_, ?_⟩, (hb4 _).mpr ⟨r, hr0, by rw [hr]; exact hr1, rfl⟩,
      (hb4 _).mpr ⟨s, hsr, by rw [hs]; exact hs1, rfl⟩⟩,
      (wordS8_iff _).mpr ⟨q, by rw [hq]; exact hq0, by rw [hq]; exact hq1, rfl⟩⟩
    · have hint : g0 * x * (2 * cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * q - r = 0 := by
        rw [hden, hq, hr]; linarith
      have : ((g0 * x * (2 * cn) + d * 2 ^ tn - 2 ^ (tn + 1) * d * q - r : ℤ) : GF) = 0 := by
        rw [hint]; simp
      push_cast at this
      exact this
    · have hint : r + s + 1 - 2 ^ (tn + 1) * d = 0 := by rw [hden, hs, hr]; ring
      have : ((r + s + 1 - 2 ^ (tn + 1) * d : ℤ) : GF) = 0 := by rw [hint]; simp
      push_cast at this
      exact this

open Classical in
/-- **The final norm on one row** (`out_values`, stage_out.rs:209-229, the functional form of `fnormRowL`): the isqrt
`d` and every element's int8 word, or the refusal (an input word outside int16, the isqrt window, an element's class
or window). The remainder window is the door's `wrho = 32`. -/
noncomputable def fnormTok {n : ℕ} (ceps cn g0 : ℤ) (tn : ℕ) (x : Fin n → ℤ) : Option (ℤ × (Fin n → ℤ)) :=
  if (∀ i, i16 (x i)) ∧ NormOK (ssOf ceps x) then
    (liftO fun i => (fnormElem tn cn g0 32 (isqrtWitness (ssOf ceps x)).1 (x i)).map Prod.fst).map
      fun y => ((isqrtWitness (ssOf ceps x)).1, y)
  else none

/-- **The final norm's clauses on one row** (stage_out.rs:366-394, 421-455, at the live positions `i < d`): the isqrt
clauses on the hosted sum of squares (`SO_SS` hosted by `SO_TZC`, whose `d`, `a1`, `a2` are three byte limbs each,
`threeBytes_iff`), and per element the input's two byte limbs (`c2`), the division clauses `c0`, `c1` with the four
byte limbs of each remainder, and the word's symmetric int8 lookups. -/
def FNormRel {n : ℕ} (ceps cn g0 : ℤ) (tn : ℕ) (x : Fin n → GF) (D : GF) (y : Fin n → GF) : Prop :=
  (∃ dsq a1 a2 : GF, IsqrtRel ((ceps : GF) + ∑ i, x i * x i) D dsq a1 a2 ∧ InRange 24 D ∧ InRange 24 a1 ∧
    InRange 24 a2) ∧
  ∀ i, ByteLimbs 2 (x i + 32768) ∧
    (∃ nr ns : GF, NormDivRel tn (cn : GF) (g0 : GF) (x i) D (y i) nr ns ∧ ByteLimbs 4 nr ∧ ByteLimbs 4 ns) ∧
    WordS8 (y i)

/-- **`CircuitIff` for the final norm on one row**, for int16 inputs over at most `4096` positions and the token door's
classes (`g0 ∈ [1, 127]`, `cn ∈ [1, 2^20]`, `ceps ∈ [1, 2^40]`, `tn ≤ 16`; token_io.rs:485-497). -/
theorem fnormTok_iff {n : ℕ} (hn : n ≤ 4096) (ceps cn g0 : ℤ) (tn : ℕ) (hc1 : 1 ≤ ceps) (hc2 : ceps ≤ 2 ^ 40)
    (hcn : |cn| ≤ 2 ^ 20) (hg : |g0| ≤ 127) (htn : tn ≤ 16) (x : Fin n → ℤ) (hx : ∀ i, i16 (x i)) (D : GF)
    (y : Fin n → GF) :
    FNormRel ceps cn g0 tn (fun i => (x i : GF)) D y ↔
      ∃ dd : ℤ, ∃ yy : Fin n → ℤ, fnormTok ceps cn g0 tn x = some (dd, yy) ∧ D = (dd : GF) ∧
        ∀ i, y i = (yy i : GF) := by
  obtain ⟨hss1, hss2⟩ := ss_bounds40 hn x ceps hx hc1 hc2
  have hss0 : 0 ≤ ssOf ceps x := by linarith
  have hcast : (ceps : GF) + ∑ i, (x i : GF) * (x i : GF) = ((ssOf ceps x : ℤ) : GF) := ss_cast x ceps
  have hpos : 1 ≤ (isqrtWitness (ssOf ceps x)).1 := isqrt_pos _ hss1
  have hxb : ∀ i, ByteLimbs 2 ((x i : GF) + 32768) := fun i =>
    (xBytes_iff _).mpr ((word16_iff _).mpr ⟨x i, (hx i).1, (hx i).2, rfl⟩)
  have helem : ∀ (dd : ℤ), 1 ≤ dd → dd < 2 ^ 24 → ∀ i,
      ((ByteLimbs 2 ((x i : GF) + 32768) ∧ (∃ nr ns : GF, NormDivRel tn (cn : GF) (g0 : GF) (x i : GF) (dd : GF) (y i)
          nr ns ∧ ByteLimbs 4 nr ∧ ByteLimbs 4 ns) ∧ WordS8 (y i)) ↔
        ∃ a, (fnormElem tn cn g0 32 dd (x i)).map Prod.fst = some a ∧ y i = (a : GF)) := by
    intro dd h1 h2 i
    rw [and_iff_right (hxb i), fnormDiv_iff tn htn cn g0 (x i) dd hcn hg (abs_le_of_int16 (hx i)) h1 h2 (y i)]
    constructor
    · rintro ⟨q, _, _, hq, hy⟩
      exact ⟨q, by simp [hq], hy⟩
    · rintro ⟨a, ha, hy⟩
      cases he : fnormElem tn cn g0 32 dd (x i) with
      | none => rw [he] at ha; cases ha
      | some e =>
        obtain ⟨q, r, s⟩ := e
        rw [he] at ha
        have hqa : q = a := Option.some.inj ha
        exact ⟨q, r, s, rfl, by rw [hqa]; exact hy⟩
  show (∃ dsq a1 a2 : GF, IsqrtRel ((ceps : GF) + ∑ i, (x i : GF) * (x i : GF)) D dsq a1 a2 ∧ InRange 24 D ∧
      InRange 24 a1 ∧ InRange 24 a2) ∧
    (∀ i, ByteLimbs 2 ((x i : GF) + 32768) ∧ (∃ nr ns : GF, NormDivRel tn (cn : GF) (g0 : GF) (x i : GF) D (y i) nr ns ∧
      ByteLimbs 4 nr ∧ ByteLimbs 4 ns) ∧ WordS8 (y i)) ↔ _
  rw [hcast, isqrt_iff _ hss0 hss2 D]
  constructor
  · rintro ⟨⟨w0, w1, w2, hD⟩, hdiv⟩
    have hd2 : (isqrtWitness (ssOf ceps x)).1 < 2 ^ 24 := by
      have h := w0
      unfold inIsqrtWindow at h
      exact (of_decide_eq_true h).2
    rw [hD] at hdiv
    obtain ⟨v, hv, hyv⟩ := (liftO_exists (fun i => (fnormElem tn cn g0 32 (isqrtWitness (ssOf ceps x)).1 (x i)).map
      Prod.fst) fun i a => y i = (a : GF)).mp (fun i => (helem _ hpos hd2 i).mp (hdiv i))
    refine ⟨(isqrtWitness (ssOf ceps x)).1, v, ?_, hD, hyv⟩
    unfold fnormTok
    rw [ite_eq_left (show (∀ i, i16 (x i)) ∧ NormOK (ssOf ceps x) from
      ⟨hx, hss0, fun h0 => by rw [h0] at hpos; norm_num at hpos, w0, w1, w2⟩)]
    simp only [hv, Option.map_some]
  · rintro ⟨dd, yy, hnt, hD, hy⟩
    unfold fnormTok at hnt
    by_cases hok : (∀ i, i16 (x i)) ∧ NormOK (ssOf ceps x)
    · rw [ite_eq_left hok] at hnt
      obtain ⟨-, -, -, w0, w1, w2⟩ := hok
      obtain ⟨v, hv, hvy⟩ := Option.map_eq_some_iff.mp hnt
      have hvy2 : ((isqrtWitness (ssOf ceps x)).1, v) = (dd, yy) := hvy
      obtain ⟨hdd, hvyy⟩ := Prod.mk.inj hvy2
      rw [hvyy] at hv
      have hd2 : (isqrtWitness (ssOf ceps x)).1 < 2 ^ 24 := by
        have h := w0
        unfold inIsqrtWindow at h
        exact (of_decide_eq_true h).2
      subst hdd
      refine ⟨⟨w0, w1, w2, hD⟩, fun i => ?_⟩
      rw [hD]
      exact (helem _ hpos hd2 i).mpr ⟨yy i, liftO_eq_some.mp hv i, hy i⟩
    · rw [ite_eq_right hok] at hnt
      cases hnt

/-- The words of an admitted final-norm row are symmetric int8. -/
theorem fnormTok_class {n : ℕ} {ceps cn g0 : ℤ} {tn : ℕ} {x : Fin n → ℤ} {a : ℤ × (Fin n → ℤ)}
    (h : fnormTok ceps cn g0 tn x = some a) (i : Fin n) : -127 ≤ a.2 i ∧ a.2 i ≤ 127 := by
  obtain ⟨dd, yy⟩ := a
  show -127 ≤ yy i ∧ yy i ≤ 127
  unfold fnormTok at h
  by_cases hok : (∀ i, i16 (x i)) ∧ NormOK (ssOf ceps x)
  · rw [ite_eq_left hok] at h
    obtain ⟨v, hv, hvy⟩ := Option.map_eq_some_iff.mp h
    have hvy2 : ((isqrtWitness (ssOf ceps x)).1, v) = (dd, yy) := hvy
    obtain ⟨-, hvyy⟩ := Prod.mk.inj hvy2
    rw [hvyy] at hv
    have he : (fnormElem tn cn g0 32 (isqrtWitness (ssOf ceps x)).1 (x i)).map Prod.fst = some (yy i) :=
      liftO_eq_some.mp hv i
    cases hn : fnormElem tn cn g0 32 (isqrtWitness (ssOf ceps x)).1 (x i) with
    | none => rw [hn] at he; cases he
    | some e =>
      obtain ⟨q, r, s⟩ := e
      rw [hn] at he
      have hq : q = yy i := Option.some.inj he
      obtain ⟨⟨h0, h1, -, -⟩, hq', -, -⟩ := fnormElem_eq_some.mp hn
      rw [← hq', hq] at h0 h1
      exact ⟨h0, h1⟩
  · rw [ite_eq_right hok] at h
    cases h

/-! ## Stage OUT: the head and the greedy token -/

/-- The public data of stage OUT (P1: public; `TokenTables` and `TokenProfile`, token_io.rs:434-457, 625-631): the
vocabulary `V`, the int8 head `W'` and its per-row multipliers, the final norm's constants, the key's shift `v`
(`log2 V_pad`) and the keyed difference's byte count. -/
structure OutPublic (n : ℕ) where
  V : ℕ
  head : ℕ → Fin n → ℤ
  mult : ℕ → ℕ
  g0 : ℤ
  cn : ℤ
  ceps : ℤ
  tn : ℕ
  vlog : ℕ
  limbs : ℕ

/-- The largest logit the classes admit: `n·127·127·2^12` (the door's `top`, token_io.rs:513). -/
def logitMax (n : ℕ) : ℤ := (n : ℤ) * 127 * 127 * 2 ^ 12

/-- The classes the token door admits (`TokenProfile::new` and `TokenTables::new`, token_io.rs:470-533):
* `2 ≤ V ≤ 2^17` and `V ≤ 2^v = V_pad` (:489, :509-510; `log_v = clog2(V_pad)`);
* head words in `[−127, 127]` (:481-484, review TR-5) and multipliers in `[1, 2^12]` (:477-479, D25 T4);
* `g0 ∈ [1, 127]`, `cn ∈ [1, 2^20]`, `ceps ∈ [1, 2^40]`, `tn ∈ 1..=16` (:485-497);
* the keyed window: the honest difference `2^v·(2·top) + (V − 1)` below `2^(8·limbs)`, and the limbs with the window
  below `p` (:513-518: `window_bits = bit_length(top)`, `limbs = ⌈window_bits / 8⌉`). -/
structure OutPublic.Valid {n : ℕ} (P : OutPublic n) : Prop where
  V1 : 2 ≤ P.V
  V2 : P.V ≤ 2 ^ 17
  Vpad : P.V ≤ 2 ^ P.vlog
  head : ∀ z i, |P.head z i| ≤ 127
  mult0 : ∀ z, 1 ≤ P.mult z
  mult1 : ∀ z, P.mult z ≤ 2 ^ 12
  g0a : 1 ≤ P.g0
  g0b : P.g0 ≤ 127
  cna : 1 ≤ P.cn
  cnb : P.cn ≤ 2 ^ 20
  cepsa : 1 ≤ P.ceps
  cepsb : P.ceps ≤ 2 ^ 40
  tn : P.tn ≤ 16
  win : (2 : ℤ) ^ P.vlog * (2 * logitMax n) + P.V ≤ 2 ^ (8 * P.limbs)
  nowrap : (2 : ℤ) ^ (8 * P.limbs) + 2 ^ P.vlog * (2 * logitMax n) + P.V < gP

/-- The raw-integer logit of entry `z` (`TokenTables::logits`, token_io.rs:668-671). -/
def logit {n : ℕ} (P : OutPublic n) (y : Fin n → ℤ) (z : ℕ) : ℤ := (P.mult z : ℤ) * ∑ i, P.head z i * y i

/-- **Stage OUT's integer semantics on one row** (`out_values`, stage_out.rs:207-235): the final norm, the logits, the
first argmax; `none` exactly when the final norm refuses. -/
noncomputable def outSpec {n : ℕ} (P : OutPublic n) (x : Fin n → ℤ) : Option ℕ :=
  (fnormTok P.ceps P.cn P.g0 P.tn x).map fun dy =>
    argmaxN (lfun fun z : Fin P.V => logit P dy.2 z) P.V

/-- **Stage OUT's clauses on one row** at the logical positions: the final norm, and the keyed argmax on the hosted head
values (`SO_HEAD`'s fold `Σ_i y_i·(m_z·W'[z][i])`, token_io.rs:708-727, hosted by `SO_VZC`). `tok` is the fixed-point
word `A_TOK`, which `SO_IOOUT` writes to the output token endpoint's word 0 (stage_out.rs:532-538). -/
def OutSat {n : ℕ} (P : OutPublic n) (x : Fin n → GF) (tok : GF) : Prop :=
  ∃ D : GF, ∃ y : Fin n → GF, FNormRel P.ceps P.cn P.g0 P.tn x D y ∧
    ∃ M : GF, ∃ e δ : Fin P.V → GF,
      ArgRel P.vlog P.limbs (fun z => ∑ i, y i * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)) tok M e δ

theorem logit_cast {n : ℕ} (P : OutPublic n) (yy : Fin n → ℤ) (z : ℕ) :
    (∑ i, ((yy i : ℤ) : GF) * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)) = ((logit P yy z : ℤ) : GF) := by
  unfold logit
  push_cast
  rw [Finset.mul_sum]
  refine Finset.sum_congr rfl fun i _ => ?_
  ring

theorem logit_abs_le {n : ℕ} (P : OutPublic n) (hP : P.Valid) (yy : Fin n → ℤ) (hy : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127)
    (z : ℕ) : |logit P yy z| ≤ logitMax n := by
  have h1 := dot_abs_le (fun i => P.head z i) yy (X := 127) (Wb := 127) (fun i => hP.head z i)
    (fun i => abs_le.mpr ⟨by linarith [(hy i).1], (hy i).2⟩)
  rw [Fintype.card_fin] at h1
  have hm0 : (0 : ℤ) ≤ (P.mult z : ℤ) := Int.natCast_nonneg _
  have hm1 : (P.mult z : ℤ) ≤ 2 ^ 12 := by exact_mod_cast hP.mult1 z
  unfold logit logitMax
  rw [abs_mul, abs_of_nonneg hm0]
  have hn0 : (0 : ℤ) ≤ (n : ℤ) * (127 * 127) := by positivity
  calc (P.mult z : ℤ) * |∑ i, P.head z i * yy i| ≤ 2 ^ 12 * ((n : ℤ) * (127 * 127)) :=
        mul_le_mul hm1 h1 (abs_nonneg _) (by norm_num)
    _ = (n : ℤ) * 127 * 127 * 2 ^ 12 := by ring

/-- **`CircuitIff` for stage OUT on one row**: for an int16 row `x` (the last block's output words) over at most
`4096` channels and public data in the door's classes, the clauses hold for the committed token word `tok` exactly
when the integer stage admits the row and `tok` is the image of its greedy token. -/
theorem out_iff {n : ℕ} (hn : n ≤ 4096) (P : OutPublic n) (hP : P.Valid) (x : Fin n → ℤ) (hx : ∀ i, i16 (x i))
    (tok : GF) : OutSat P (fun i => (x i : GF)) tok ↔ ∃ z, outSpec P x = some z ∧ tok = (z : GF) := by
  have hcn : |P.cn| ≤ 2 ^ 20 := abs_le.mpr ⟨by linarith [hP.cna], hP.cnb⟩
  have hg : |P.g0| ≤ 127 := abs_le.mpr ⟨by linarith [hP.g0a], hP.g0b⟩
  have hV1 : 1 ≤ P.V := le_trans (by norm_num) hP.V1
  constructor
  · rintro ⟨D, y, hN, M, e, δ, hA⟩
    obtain ⟨dd, yy, hnt, -, hy⟩ := (fnormTok_iff hn P.ceps P.cn P.g0 P.tn hP.cepsa hP.cepsb hcn hg hP.tn x hx D
      y).mp hN
    have hyc : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127 := fun i => fnormTok_class hnt i
    have hlg : (fun z : Fin P.V => ∑ i, y i * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)) =
        fun z : Fin P.V => ((logit P yy z : ℤ) : GF) := funext fun z => by
      rw [← logit_cast]
      exact Finset.sum_congr rfl fun i _ => by rw [hy i]
    rw [hlg] at hA
    have h := (argmax_iff P.vlog P.limbs hV1 hP.Vpad (logitMax n) (fun z : Fin P.V => logit P yy z)
      (fun z => logit_abs_le P hP yy hyc z) hP.win hP.nowrap tok).mp ⟨M, e, δ, hA⟩
    refine ⟨argmaxN (lfun fun z : Fin P.V => logit P yy z) P.V, ?_, h⟩
    unfold outSpec
    rw [hnt]
    rfl
  · rintro ⟨z, hz, htok⟩
    unfold outSpec at hz
    obtain ⟨⟨dd, yy⟩, hnt, hzz⟩ := Option.map_eq_some_iff.mp hz
    have hyc : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127 := fun i => fnormTok_class hnt i
    have hN := (fnormTok_iff hn P.ceps P.cn P.g0 P.tn hP.cepsa hP.cepsb hcn hg hP.tn x hx (dd : GF)
      (fun i => (yy i : GF))).mpr ⟨dd, yy, hnt, rfl, fun i => rfl⟩
    have htok' : tok = ((argmaxN (lfun fun z : Fin P.V => logit P yy z) P.V : ℕ) : GF) := by
      rw [htok, ← hzz]
    obtain ⟨M, e, δ, hA⟩ := (argmax_iff P.vlog P.limbs hV1 hP.Vpad (logitMax n) (fun z : Fin P.V => logit P yy z)
      (fun z => logit_abs_le P hP yy hyc z) hP.win hP.nowrap tok).mpr htok'
    refine ⟨(dd : GF), fun i => (yy i : GF), hN, M, e, δ, ?_⟩
    have hlg : (fun z : Fin P.V => ∑ i, ((yy i : ℤ) : GF) * (((P.mult z : ℤ) * P.head z i : ℤ) : GF)) =
        fun z : Fin P.V => ((logit P yy z : ℤ) : GF) := funext fun z => logit_cast P yy z
    rw [hlg]
    exact hA

/-! ## Stage OUT-C: the margin and the verdict -/

/-- `σ`: `1` when the public verdict is 1, else `−1` (stage_out_c.rs:355). -/
def sigOf (b : ℕ) : GF := if b = 1 then 1 else -1

/-- **The verdict identity** (OUT-C's LZC host term hosting PD, stage_out_c.rs:349-370): the margin `Δ` is
`σ·δ + (b + c)`, `δ` in `k` byte limbs (the limb plane's entries `32 .. 32 + k`, LZC's byte lookup and pad clause). -/
def VerdictRel (k b : ℕ) (c : ℤ) (Δ : GF) : Prop :=
  ∃ δ : GF, ByteLimbs k δ ∧ Δ = sigOf b * δ + ((b : GF) + (c : GF))

/-- **`CircuitIff` for the verdict**: for a public verdict bit `b ≤ 1` (classify.rs:957-958), an integer margin
`|Δ| ≤ Dm`, a threshold `|c| ≤ 2^33` (classify.rs:589-591) and the door's limb conditions (classify.rs:610-616): the
identity holds exactly when `b` is the model's verdict, `1` exactly when `Δ > c`. -/
theorem verdict_iff (k b : ℕ) (hb : b ≤ 1) (c Δ Dm : ℤ) (hc : |c| ≤ 2 ^ 33) (hΔ : |Δ| ≤ Dm)
    (hwin : Dm + 2 ^ 33 + 1 ≤ 2 ^ (8 * k)) (hnw : (2 : ℤ) ^ (8 * k) + Dm + 2 ^ 33 + 1 < gP) :
    VerdictRel k b c (Δ : GF) ↔ b = verdictOf Δ c := by
  have hc' := abs_le.mp hc
  have hΔ' := abs_le.mp hΔ
  have hgP : (gP : ℤ) = 18446744069414584321 := gP_int
  rcases Nat.le_one_iff_eq_zero_or_eq_one.mp hb with rfl | rfl
  · -- `b = 0`: `Δ = c − δ`
    have hs : sigOf 0 = -1 := by simp [sigOf]
    constructor
    · rintro ⟨δ, hδ, hΔe⟩
      obtain ⟨t, ht0, ht1, rfl⟩ := (byteLimbs_iff k δ).mp hδ
      rw [hs] at hΔe
      have h' : ((Δ + t - c : ℤ) : GF) = ((0 : ℤ) : GF) := by push_cast; rw [hΔe]; ring
      have := int_eq_of_cast_eq h' (by linarith) (by linarith)
      unfold verdictOf
      rw [ite_eq_right (by linarith)]
    · intro hv
      unfold verdictOf at hv
      have hle : Δ ≤ c := by
        by_contra hlt
        push Not at hlt
        rw [ite_eq_left hlt] at hv
        exact absurd hv (by norm_num)
      refine ⟨((c - Δ : ℤ) : GF), (byteLimbs_iff k _).mpr ⟨c - Δ, by linarith, by linarith, rfl⟩, ?_⟩
      rw [hs]
      push_cast
      ring
  · -- `b = 1`: `Δ = δ + 1 + c`
    have hs : sigOf 1 = 1 := by simp [sigOf]
    constructor
    · rintro ⟨δ, hδ, hΔe⟩
      obtain ⟨t, ht0, ht1, rfl⟩ := (byteLimbs_iff k δ).mp hδ
      rw [hs] at hΔe
      have h' : ((Δ - t - 1 - c : ℤ) : GF) = ((0 : ℤ) : GF) := by push_cast; rw [hΔe]; ring
      have := int_eq_of_cast_eq h' (by linarith) (by linarith)
      unfold verdictOf
      rw [ite_eq_left (by linarith)]
    · intro hv
      unfold verdictOf at hv
      have hlt : c < Δ := by
        by_contra hle
        rw [ite_eq_right hle] at hv
        exact absurd hv (by norm_num)
      refine ⟨((Δ - c - 1 : ℤ) : GF), (byteLimbs_iff k _).mpr ⟨Δ - c - 1, by linarith, by linarith, rfl⟩, ?_⟩
      rw [hs]
      push_cast
      ring

/-- The public data of stage OUT-C (`ClassifierTables`, `ClassifierProfile`, classify.rs:466, 526-547): the final norm's
constants, the int16 margin vector `w_Δ`, the threshold `c` and the margin's byte count. -/
structure OutCPublic (n : ℕ) where
  wΔ : Fin n → ℤ
  c : ℤ
  g0 : ℤ
  cn : ℤ
  ceps : ℤ
  tn : ℕ
  limbs : ℕ

/-- The largest margin the classes admit, `n·127·32767` (classify.rs:609). -/
def marginMax (n : ℕ) : ℤ := (n : ℤ) * 127 * 32767

/-- The classes the classifier door admits (`ClassifierProfile::new`, classify.rs:552-647): the margin vector in
`[−32767, 32767]` (:568-571), `|c| ≤ 2^33` (:589-591), the final norm's classes (:597-599), and the margin window
(:609-616: the honest difference `n·127·32767 + 2^33 + 1` below `2^(8·limbs)`, the limbs and window below `p/2`). -/
structure OutCPublic.Valid {n : ℕ} (P : OutCPublic n) : Prop where
  w : ∀ i, |P.wΔ i| ≤ 32767
  c : |P.c| ≤ 2 ^ 33
  g0a : 1 ≤ P.g0
  g0b : P.g0 ≤ 127
  cna : 1 ≤ P.cn
  cnb : P.cn ≤ 2 ^ 20
  cepsa : 1 ≤ P.ceps
  cepsb : P.ceps ≤ 2 ^ 40
  tn : P.tn ≤ 16
  win : marginMax n + 2 ^ 33 + 1 ≤ 2 ^ (8 * P.limbs)
  nowrap : (2 : ℤ) ^ (8 * P.limbs) + marginMax n + 2 ^ 33 + 1 < gP

/-- The integer margin `Δ = Σ_i w_Δ[i]·y_i` (classify.rs:509-511). -/
def margin {n : ℕ} (P : OutCPublic n) (y : Fin n → ℤ) : ℤ := ∑ i, P.wΔ i * y i

/-- **Stage OUT-C's integer semantics on one row** (`out_values`, stage_out_c.rs:170-198): the final norm, the margin,
the verdict. -/
noncomputable def outCSpec {n : ℕ} (P : OutCPublic n) (x : Fin n → ℤ) : Option ℕ :=
  (fnormTok P.ceps P.cn P.g0 P.tn x).map fun dy => verdictOf (margin P dy.2) P.c

/-- **Stage OUT-C's clauses on one row**: the final norm (stage OUT's relation, unchanged) and the verdict identity on
the hosted margin (`SOC_PD`'s sum `Σ_i y_i·w_Δ(i)`). -/
def OutCSat {n : ℕ} (P : OutCPublic n) (x : Fin n → GF) (b : ℕ) : Prop :=
  ∃ D : GF, ∃ y : Fin n → GF, FNormRel P.ceps P.cn P.g0 P.tn x D y ∧
    VerdictRel P.limbs b P.c (∑ i, y i * (P.wΔ i : GF))

theorem margin_abs_le {n : ℕ} (P : OutCPublic n) (hP : P.Valid) (yy : Fin n → ℤ)
    (hy : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127) : |margin P yy| ≤ marginMax n := by
  have h1 := dot_abs_le P.wΔ yy (X := 32767) (Wb := 127) (fun i => hP.w i)
    (fun i => abs_le.mpr ⟨by linarith [(hy i).1], (hy i).2⟩)
  rw [Fintype.card_fin] at h1
  unfold margin marginMax
  calc |∑ i, P.wΔ i * yy i| ≤ (n : ℤ) * (32767 * 127) := h1
    _ = (n : ℤ) * 127 * 32767 := by ring

/-- **`CircuitIff` for stage OUT-C on one row**: for an int16 row and public data in the door's classes, the clauses
hold for the published verdict bit `b ≤ 1` exactly when the integer stage admits the row and `b` is its verdict. -/
theorem outC_iff {n : ℕ} (hn : n ≤ 4096) (P : OutCPublic n) (hP : P.Valid) (x : Fin n → ℤ) (hx : ∀ i, i16 (x i))
    (b : ℕ) (hb : b ≤ 1) : OutCSat P (fun i => (x i : GF)) b ↔ outCSpec P x = some b := by
  have hcn : |P.cn| ≤ 2 ^ 20 := abs_le.mpr ⟨by linarith [hP.cna], hP.cnb⟩
  have hg : |P.g0| ≤ 127 := abs_le.mpr ⟨by linarith [hP.g0a], hP.g0b⟩
  have hm : ∀ yy : Fin n → ℤ, (∑ i, ((yy i : ℤ) : GF) * (P.wΔ i : GF)) = ((margin P yy : ℤ) : GF) := fun yy => by
    unfold margin
    push_cast
    exact Finset.sum_congr rfl fun i _ => by ring
  constructor
  · rintro ⟨D, y, hN, hV⟩
    obtain ⟨dd, yy, hnt, -, hy⟩ := (fnormTok_iff hn P.ceps P.cn P.g0 P.tn hP.cepsa hP.cepsb hcn hg hP.tn x hx D
      y).mp hN
    have hyc : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127 := fun i => fnormTok_class hnt i
    have hsum : (∑ i, y i * (P.wΔ i : GF)) = ((margin P yy : ℤ) : GF) := by
      rw [← hm]; exact Finset.sum_congr rfl fun i _ => by rw [hy i]
    rw [hsum] at hV
    have h := (verdict_iff P.limbs b hb P.c (margin P yy) (marginMax n) hP.c (margin_abs_le P hP yy hyc) hP.win
      hP.nowrap).mp hV
    unfold outCSpec
    rw [hnt, h]
    rfl
  · intro hz
    unfold outCSpec at hz
    obtain ⟨⟨dd, yy⟩, hnt, hzz⟩ := Option.map_eq_some_iff.mp hz
    have hyc : ∀ i, -127 ≤ yy i ∧ yy i ≤ 127 := fun i => fnormTok_class hnt i
    have hN := (fnormTok_iff hn P.ceps P.cn P.g0 P.tn hP.cepsa hP.cepsb hcn hg hP.tn x hx (dd : GF)
      (fun i => (yy i : GF))).mpr ⟨dd, yy, hnt, rfl, fun i => rfl⟩
    refine ⟨(dd : GF), fun i => (yy i : GF), hN, ?_⟩
    rw [hm]
    exact (verdict_iff P.limbs b hb P.c (margin P yy) (marginMax n) hP.c (margin_abs_le P hP yy hyc) hP.win
      hP.nowrap).mpr hzz.symm

end ZK60.Out
