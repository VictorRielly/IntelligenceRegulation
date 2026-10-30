//! R13 scalar arithmetic, not yet imported into the prover. Exact expected values come from independent
//! rational Python reference vectors beside this module.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct Rounded {
    pub word: i64,
    /// Biased remainder: numerator + half = denominator * word + remainder.
    pub remainder: u64,
    pub shift: u32,
}

pub(crate) fn requant(accumulator: i128, multiplier: u64, shift: u32) -> Result<Rounded, String> {
    if multiplier == 0 || !(1..=63).contains(&shift) {
        return Err("R13 requantization: nonzero multiplier and shift in 1..=63 required".into());
    }
    let denominator = 1i128 << shift;
    let numerator = accumulator.checked_mul(multiplier as i128)
        .and_then(|value| value.checked_add(denominator / 2))
        .ok_or("R13 requantization: numerator overflow")?;
    let word = i64::try_from(numerator.div_euclid(denominator))
        .map_err(|_| "R13 requantization: output exceeds int64")?;
    Ok(Rounded { word, remainder: numerator.rem_euclid(denominator) as u64, shift })
}

pub(crate) fn product(a: i64, up: i64, shift_h: u32, output_exponent_delta: i32) -> Result<Rounded, String> {
    if !(5..=8).contains(&shift_h) || !(-4..=4).contains(&output_exponent_delta) {
        return Err("R13 product: h shift or group exponent outside the declared class".into());
    }
    // Apply the group scale before the single product rounding. Keeping the
    // effective denominator also exposes when the remainder needs >1 byte.
    let shift = (shift_h as i64 - output_exponent_delta as i64) as u32;
    requant((a as i128) * (up as i128), 1, shift)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn requantization_matches_independent_rational_vectors() {
        for row in include_str!("r13_vectors/r13_requant_vectors.tsv").lines() {
            let v: Vec<i128> = row.split('\t').map(|s| s.parse().unwrap()).collect();
            let result = requant(v[0], v[1] as u64, v[2] as u32).unwrap();
            assert_eq!(result.word as i128, v[3], "{row}");
            assert!(result.remainder < 1u64 << result.shift);
            assert_eq!(v[0] * v[1] + (1i128 << (result.shift - 1)),
                (result.word as i128) * (1i128 << result.shift) + result.remainder as i128);
        }
    }

    #[test]
    fn grouped_products_match_independent_rational_vectors() {
        for row in include_str!("r13_vectors/r13_product_vectors.tsv").lines() {
            let v: Vec<i64> = row.split('\t').map(|s| s.parse().unwrap()).collect();
            let result = product(v[0], v[1], v[2] as u32, v[3] as i32).unwrap();
            assert_eq!(result.word, v[4], "{row}");
        }
    }

    #[test]
    fn group_scale_precedes_product_rounding() {
        assert_eq!(product(1, 16, 5, -1).unwrap().word, 0);
        assert_eq!(requant(16, 1, 5).unwrap().word, 1);
    }

    #[test]
    fn negative_half_ties_round_toward_positive_infinity() {
        assert_eq!(requant(-1, 1, 1).unwrap().word, 0);
        assert_eq!(requant(-3, 1, 1).unwrap().word, -1);
        assert_eq!(requant(1, 1, 1).unwrap().word, 1);
    }

    #[test]
    fn invalid_shifts_multipliers_and_overflow_are_refused() {
        for shift in [0, 64, u32::MAX] {
            assert!(requant(1, 1, shift).is_err());
        }
        assert!(requant(1, 0, 8).is_err());
        assert!(requant(i128::MAX, 2, 8).is_err());
        assert!(requant(i128::MAX, 1, 8).is_err());
        assert!(product(1, 1, 5, i32::MIN).is_err());
        assert!(product(1, 1, 5, i32::MAX).is_err());
    }
}
