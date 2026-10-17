//! UNCOMPILED owner sketch for a round-local internal accumulator.
//! Requires the reviewed cycle47 factory. No transcript, RNG or wire access.
//! The grouped driver must distinguish coefficients from samples until after
//! reduction, then call original recovery/high-sample interpolation unchanged.
use crate::field::{Fp, Fp2};

pub struct WeightedCoefficients([Fp2; 5]);
impl WeightedCoefficients {
    pub fn zero() -> Self { Self([Fp2::ZERO; 5]) }
    pub fn add_row(&mut self, suffix_weight: Fp2, coefficients: &[Fp2; 5]) {
        for (acc, c) in self.0.iter_mut().zip(coefficients) {
            *acc = acc.add(suffix_weight.mul(*c));
        }
    }
    pub fn merge(&mut self, other: Self) {
        for (acc, c) in self.0.iter_mut().zip(other.0) { *acc = acc.add(c); }
    }
    // Coordinates and all five coefficients are fixed by the public profile.
    // A release recovered sample1 remains ZERO until original recovery fills it.
    pub fn original_samples(&self, recover_one: bool, debug: bool) -> [Fp2; 5] {
        let mut out = [Fp2::ZERO; 5];
        out[0] = self.0[0];
        for t in 1..5 {
            if t == 1 && recover_one && !debug { continue; }
            let mut value = self.0[4];
            for c in self.0[..4].iter().rev() {
                value = value.mul_base(Fp::new(t as u64)).add(*c);
            }
            out[t] = value;
        }
        out
    }
}
// Public driver dispatch: padded_zero_group && half >= 2.
// Unpadded and singleton rounds retain the cycle47 row/sample factory.
// Keep all original table folds/finals, masks, sample count and group factors.
