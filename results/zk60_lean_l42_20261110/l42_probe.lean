import Mathlib
open scoped ENNReal
#check @ENNReal.pow_lt_pow_right_of_lt_one
#check @pow_lt_pow_right_of_lt_one₀
#check @ENNReal.mul_lt_mul_left
#check @ENNReal.div_le_of_le_mul'
#check @ENNReal.add_le_add_iff_left
#check @Set.indicator_union_of_disjoint
#check @ENNReal.inv_lt_one
#check @Option.isSome_iff_exists
#check @Set.indicator_of_notMem
example : (2⁻¹ : ℝ≥0∞) ^ 120 < 2⁻¹ := by
  calc (2⁻¹ : ℝ≥0∞) ^ 120 < (2⁻¹ : ℝ≥0∞) ^ 1 :=
        ENNReal.pow_lt_pow_right_of_lt_one (by norm_num) (by norm_num)
    _ = 2⁻¹ := pow_one _
