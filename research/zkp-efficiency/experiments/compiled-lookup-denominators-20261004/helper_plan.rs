// REVIEW-ONLY insertion sketch for private_block/argument.rs.
// Not compiled, applied, or integrated. Uses existing Fp/Fp2/LkT imports.
// lk_tables has already shifted each cst by g_u8. Rebuild after EVERY proof
// definition's alpha/tag draws; do not cache this plan across definitions.
#[derive(Clone, Copy)]
enum CoeffOp { Unit, Neg, Scale(Fp) }

struct PreparedLk { offset: Fp2, terms: Vec<(usize, CoeffOp)> }

fn prepare_lks(lks: &[LkT], alpha: Fp2) -> Vec<PreparedLk> {
    let neg_one = Fp::ONE.neg();
    lks.iter().map(|l| PreparedLk {
        offset: alpha.sub(l.cst),
        terms: l.terms.iter().map(|&(i, c)| {
            let op = if c == Fp::ONE { CoeffOp::Unit }
                else if c == neg_one { CoeffOp::Neg }
                else { CoeffOp::Scale(c) };
            (i, op)
        }).collect(),
    }).collect()
}

impl PreparedLk {
    fn den(&self, v: &[Fp2]) -> Fp2 {
        self.terms.iter().fold(self.offset, |a, &(i, op)| match op {
            CoeffOp::Unit => a.sub(v[i]),
            CoeffOp::Neg => a.add(v[i]),
            CoeffOp::Scale(c) => a.sub(v[i].mul_base(c)),
        })
    }
}

fn helper_sum_prepared(v: &[Fp2], lks: &[PreparedLk], h0: usize, mu: &[Fp2]) -> Fp2 {
    let mut acc = Fp2::ZERO;
    for k in 0..lks.len().div_ceil(2) {
        let h = v[h0 + k];
        let d1 = lks[2 * k].den(v);
        let rel = match lks.get(2 * k + 1) {
            Some(l2) => {
                let d2 = l2.den(v);
                h.mul(d1).mul(d2).sub(d1.add(d2))
            }
            None => h.mul(d1).sub(Fp2::ONE),
        };
        acc = acc.add(mu[k].mul(rel));
    }
    acc
}

// SC_SZC only for initial owner gate:
// let lks = lk_tables(...);
// let prepared_lks = prepare_lks(&lks, alpha);
// Keep lks for cfg(test) s35 captures, then capture prepared_lks in GroupPoly.
// helper_sum_prepared(v, &prepared_lks, h0, &mu[5..5 + n_help])
// Other helper_sum call sites are OUTSIDE the tested full-clause fixture.
