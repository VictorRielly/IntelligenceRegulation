//! Research-only SERIAL sketch, uncompiled and unapplied. Not a speed patch.
//! Proposed location: zkp-core/src/sumcheck/rounds.rs, behind a new evaluator.
//! Native parallel/GPU ownership and compatibility gates are still owed.
use crate::field::Fp2;

/// Fold original MSB coordinate and return next round's UNMASKED samples.
/// `next_claim` is actual interpolation of the PRECEDING unmasked round at r,
/// never an asserted host/standalone claim or masked scalar. None disables
/// sample-1 recovery. The caller retains its ordinary pending/ready state.
/// Returns None after the final two-row fold; no next round exists there.
/// No transcript, RNG or mask access; preserves every table and table order.
pub fn fused_fold_measure<F: Fn(&[Fp2]) -> Fp2>(
    tables: &mut [Vec<Fp2>], r: Fp2, degree: usize,
    next_claim: Option<Fp2>, poly: &F,
) -> Option<Vec<Fp2>> {
    assert!(!tables.is_empty() && degree >= 1);
    let n = tables[0].len();
    assert!(n >= 2 && n.is_power_of_two());
    assert!(tables.iter().all(|tb| tb.len() == n));
    if n == 2 {
        for tb in tables {
            tb[0] = tb[0].add(r.mul(tb[1].sub(tb[0])));
            tb.truncate(1);
        }
        return None;
    }
    let q = n / 4;
    let k = tables.len();
    let mut acc = vec![Fp2::ZERO; degree + 1];
    let mut cur = vec![Fp2::ZERO; k];
    let mut dif = vec![Fp2::ZERO; k];
    for i in 0..q {
        for (t, tb) in tables.iter_mut().enumerate() {
            let (a, b, c, d) = (tb[i], tb[i+q], tb[i+2*q], tb[i+3*q]);
            let left = a.add(r.mul(c.sub(a)));
            let right = b.add(r.mul(d.sub(b)));
            tb[i] = left;
            tb[i+q] = right;
            cur[t] = left;
            dif[t] = right.sub(left);
        }
        for t in 0..=degree {
            if t != 1 || next_claim.is_none() || cfg!(debug_assertions) {
                acc[t] = acc[t].add(poly(&cur));
            }
            if t < degree {
                for (v, delta) in cur.iter_mut().zip(&dif) { *v = v.add(*delta); }
            }
        }
    }
    if let Some(claim) = next_claim {
        debug_assert_eq!(acc[0].add(acc[1]), claim);
        acc[1] = claim.sub(acc[0]);
    }
    for tb in tables { tb.truncate(2*q); }
    Some(acc)
}
