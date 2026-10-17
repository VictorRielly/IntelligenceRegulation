// Research-only arithmetic seam. No proof, transcript, masking or PCS is supplied.
// Index values and every returned value are PRIVATE scratch, never receipt data.
use field::{Fp, Fp2};

pub fn pushforward(index: &[usize], active: usize, r: &[Fp2], m: usize) -> Result<Vec<Fp2>, u32> {
    let n = 1usize.checked_shl(r.len() as u32).ok_or(1u32)?;
    if index.len() != n || active > n || m == 0 { return Err(1); }
    if index[..active].iter().any(|&j| j >= m) { return Err(2); }
    // Adjacent-pair/LSB-first cube convention. Descending updates preserve inputs.
    let mut eq = vec![Fp2::ZERO; n];
    eq[0] = Fp2::ONE;
    let mut len = 1;
    for &x in r {
        for i in (0..len).rev() {
            let e = eq[i];
            eq[i + len] = e.mul(x);
            eq[i] = e.mul(Fp2::ONE.sub(x));
        }
        len *= 2;
    }
    let mut y = vec![Fp2::ZERO; m];
    for i in 0..active { y[index[i]] = y[index[i]].add(eq[i]); }
    Ok(y)
}

#[no_mangle]
pub unsafe extern "C" fn candidate(
    indices: *const usize, n: usize, active: usize, point: *const u64,
    k: usize, table: *const u64, m: usize, out: *mut u64,
) -> u32 {
    let rr = std::slice::from_raw_parts(point, 2*k);
    let r: Vec<Fp2> = rr.chunks_exact(2).map(|v| Fp2 {c0: Fp(v[0]), c1: Fp(v[1])}).collect();
    let y = match pushforward(std::slice::from_raw_parts(indices,n),active,&r,m) {
        Ok(v) => v, Err(e) => return e,
    };
    let tt = std::slice::from_raw_parts(table, 2*m);
    let mut claim = Fp2::ZERO;
    for (j, v) in y.iter().enumerate() {
        *out.add(2*j) = v.c0.0; *out.add(2*j+1) = v.c1.0;
        claim = claim.add(v.mul(Fp2 {c0: Fp(tt[2*j]), c1: Fp(tt[2*j+1])}));
    }
    *out.add(2*m) = claim.c0.0; *out.add(2*m+1) = claim.c1.0;
    0
}
