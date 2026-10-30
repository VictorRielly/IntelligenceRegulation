// Research-only exact doubling. Same output initialization, MSB wrapper,
// allocations, loads and stores as the serial native adapter. No reuse.
use crate::field::Fp2;

pub fn eq_table(r: &[Fp2]) -> Vec<Fp2> {
    let mut out = vec![Fp2::ONE; 1usize << r.len()];
    let mut len = 1usize;
    for &ri in r {
        let (lo, hi) = out.split_at_mut(len);
        for (a, b) in lo.iter_mut().zip(hi[..len].iter_mut()) {
            let e = *a;
            let product = e.mul(ri);
            *b = product;
            *a = e.sub(product);
        }
        len <<= 1;
    }
    out
}

pub fn eq_table_msb(r: &[Fp2]) -> Vec<Fp2> {
    let rev: Vec<Fp2> = r.iter().rev().copied().collect();
    eq_table(&rev)
}
