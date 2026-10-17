//! Research SERIAL helper sketch; uncompiled/unapplied, not a speed patch.
//! Proposed seam: zkp-core/src/sumcheck/grouped.rs, behind GroupedEqRounds.
//! Native parallel ownership, masked/RNG/receipt gates remain owner work.
use crate::field::Fp2;
use crate::mle::interpolate_eval;

/// Metadata for the NEXT round after the caller updates each actual claim
/// and equality prefix using the current driver's unchanged challenge.
pub struct NextGroup {
    pub bracket_degree: usize,
    pub factors: Vec<Fp2>,
    pub left: Vec<Fp2>,
    pub right: Vec<Fp2>,
    pub suffix_len: usize,
    pub trailing: usize,
    pub actual_claim: Fp2,
}

/// All tables, including equality tables, retain their original order.
/// Returns complete next-round UNMASKED group polynomials for a separate
/// `ready` cache; it must NOT set `pending` until round(next) is requested.
/// The initial round still uses ordinary grouped evaluation. No next round
/// exists at length 2. For length 2 the caller can pass an empty groups slice.
/// Not a replacement for the native parallel path: this sketch is serial.
pub fn fold_measure_groups<F: Fn(usize, &[Fp2]) -> Fp2>(
    tables: &mut [Vec<Fp2>],
    r: Fp2,
    degree: usize,
    groups: &[NextGroup],
    bracket: &F,
) -> Option<Vec<Vec<Fp2>>> {
    assert!(!tables.is_empty());
    let n = tables[0].len();
    assert!(n >= 2 && n.is_power_of_two());
    assert!(tables.iter().all(|t| t.len() == n));
    if n == 2 {
        for tb in tables {
            tb[0] = tb[0].add(r.mul(tb[1].sub(tb[0])));
            tb.truncate(1);
        }
        return None;
    }
    assert!(!groups.is_empty());
    for g in groups {
        assert!(g.bracket_degree >= 1 && g.bracket_degree <= degree);
        assert_eq!(g.factors.len(), degree + 1);
        assert!(!g.left.is_empty() && !g.right.is_empty());
        assert_eq!(g.left.len() * g.right.len(), 1usize << g.suffix_len);
    }
    let inverses: Vec<_> = groups.iter().map(|g| {
        if g.factors[1].is_zero() { None } else { Some(g.factors[1].inv()) }
    }).collect();
    let q = n / 4;
    let k = tables.len();
    let max_degree = groups.iter().map(|g| g.bracket_degree).max().unwrap();
    let mut hs: Vec<_> = groups.iter().map(|g| vec![Fp2::ZERO; g.bracket_degree+1]).collect();
    let mut cur = vec![Fp2::ZERO; k];
    let mut dif = vec![Fp2::ZERO; k];
    let mut weights = vec![Fp2::ZERO; groups.len()];
    // Serial accumulator is shared across row ranges. No per-tile zero-plus-
    // partial reduction: the Python negative arm prices that needless work.
    for i in 0..q {
        for (t, tb) in tables.iter_mut().enumerate() {
            let (a, b, c, d) = (tb[i], tb[i+q], tb[i+2*q], tb[i+3*q]);
            let lo = a.add(r.mul(c.sub(a)));
            let hi = b.add(r.mul(d.sub(b)));
            tb[i] = lo;
            tb[i+q] = hi;
            cur[t] = lo;
            dif[t] = hi.sub(lo);
        }
        for (g, desc) in groups.iter().enumerate() {
            let pos = (i >> desc.trailing) & ((1usize << desc.suffix_len)-1);
            weights[g] = desc.left[pos / desc.right.len()].mul(desc.right[pos % desc.right.len()]);
        }
        for t in 0..=max_degree {
            for (g, desc) in groups.iter().enumerate() {
                if t <= desc.bracket_degree &&
                    (t != 1 || inverses[g].is_none() || cfg!(debug_assertions)) {
                    hs[g][t] = hs[g][t].add(weights[g].mul(bracket(g, &cur)));
                }
            }
            if t < max_degree {
                for (a, d) in cur.iter_mut().zip(&dif) { *a = a.add(*d); }
            }
        }
    }
    for tb in tables { tb.truncate(2*q); }
    let mut output = Vec::with_capacity(groups.len());
    for (g, desc) in groups.iter().enumerate() {
        if let Some(inv) = inverses[g] {
            let one = desc.actual_claim.sub(desc.factors[0].mul(hs[g][0])).mul(inv);
            debug_assert_eq!(one, hs[g][1], "group running-claim identity");
            hs[g][1] = one;
        }
        output.push((0..=degree).map(|t| {
            let h = if t < hs[g].len() { hs[g][t] }
                else { interpolate_eval(&hs[g], Fp2::from_u64(t as u64)) };
            desc.factors[t].mul(h)
        }).collect());
    }
    Some(output)
}
