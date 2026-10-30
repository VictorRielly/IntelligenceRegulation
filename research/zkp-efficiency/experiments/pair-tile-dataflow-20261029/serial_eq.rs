pub fn eq_table(r: &[Fp2]) -> Vec<Fp2> {
    let n = r.len();
    let mut out = vec![Fp2::ONE; 1 << n];
    let mut len = 1usize;
    for &ri in r.iter() {
        // split each existing entry e into (e*(1-ri), e*ri) for the next bit (more significant first)
        let (lo, hi) = out.split_at_mut(len);
        let hi = &mut hi[..len];
        let one_minus = Fp2::ONE.sub(ri);
        // [UPERF3-XX] small steps run sequentially: a rayon region per
        // doubling step cost ~0.3 ms of pool wake-up each and dominated
        // pcs::group_claims (37 claims x 2 tables x up to 14 steps per
        // layer); same values.
        if len < 4096 {
            for (a, b) in lo.iter_mut().zip(hi.iter_mut()) {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            }
        } else {
            lo.iter_mut().zip(hi.iter_mut()).for_each(|(a, b)| {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            });
        }
        len <<= 1;
    }
    // out[idx] where idx bit (n-1-i) = variable i -> but the loop above makes
    // the FIRST r the least significant split. Fix by building in the
    // opposite order: iterate r in reverse so r[0] ends up most significant.
    out
}

/// eq table with r[0] the MOST significant index bit (row-major convention).
pub fn eq_table_msb(r: &[Fp2]) -> Vec<Fp2> {
    let rev: Vec<Fp2> = r.iter().rev().copied().collect();
    eq_table(&rev)
}

