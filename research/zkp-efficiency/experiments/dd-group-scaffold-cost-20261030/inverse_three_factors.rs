// Locally authored integration sketch. UNCOMPILED, UNAPPLIED, NOT REVIEWED.
// Matches scaffold.py's literal 3*m base-batch product schedule.
// At GroupedEqRounds::round, prepare factors before calling this, then retain
// the original per-group explicit-evaluation fallback for every None result.
use crate::field::{Fp, Fp2};

fn inverse_three_factors(
    factors: [Fp2; 3],
    has_unmasked_claim: [bool; 3],
) -> [Option<Fp2>; 3] {
    let mut indices = [0usize; 3];
    let mut count = 0;
    for i in 0..3 {
        if has_unmasked_claim[i] && !factors[i].is_zero() {
            indices[count] = i;
            count += 1;
        }
    }
    let mut result = [None; 3];
    if count == 0 { return result; }
    if count == 1 {
        let i = indices[0];
        result[i] = Some(factors[i].inv());
        return result;
    }
    let mut norms = [Fp::ONE; 3];
    let mut prefixes = [Fp::ONE; 3];
    let mut acc = Fp::ONE;
    for k in 0..count {
        let f = factors[indices[k]];
        norms[k] = f.c0.square().sub(f.c1.square().mul(Fp(7)));
        prefixes[k] = acc;
        acc = acc.mul(norms[k]);
    }
    let mut inverse = acc.inv();
    for k in (0..count).rev() {
        let ni = inverse.mul(prefixes[k]);
        inverse = inverse.mul(norms[k]);
        let i = indices[k];
        let f = factors[i];
        result[i] = Some(Fp2::new(f.c0.mul(ni), f.c1.neg().mul(ni)));
    }
    result
}
