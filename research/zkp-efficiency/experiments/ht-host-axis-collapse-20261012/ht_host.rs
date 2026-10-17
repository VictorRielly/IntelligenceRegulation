//! Uncompiled/unapplied owner sketch, not a production patch.
//! Run only after an immutable SC_SZC source plan certifies: group1 Eq start0
//! and len L, private A_SUM Tab.log=L, coords=Rho(0..L), ext_round=0,
//! support is builder-produced Dom::Ht leading lift (or Gate::None).
//! Unsupported public descriptors use the original grouped scan. Never accept
//! a witness assertion of invariance, scan private values for admission, or
//! install this helper as the verifier/extension polynomial.
use zkp_core::field::Fp2;

/// Initial DATA rounds only. Caller retains native full sample/degree metadata,
/// actual preceding group claims and explicit zero-factor fallback. It removes
/// group1 from the ordinary row loop and supplies these hs before unchanged
/// group recovery/interpolation/factor multiplication. Other groups/table
/// folds/finals, masks, RNG/transcript/PCS/extension schedule remain unchanged.
fn ht_samples(j: usize, n: usize, leading: usize, degree: usize,
              sum: &[Fp2], gate: Option<&[Fp2]>, left: &[Fp2], right: &[Fp2],
              skip_one: bool, nu: Fp2, lam: Fp2) -> Vec<Fp2> {
    assert!(j < n && leading <= n && (1..=2).contains(&degree));
    let half = 1usize << (n-j-1);
    assert_eq!(sum.len(), 2*half);
    if let Some(g) = gate { assert_eq!(g.len(), sum.len()); }
    let read_gate = |i| gate.map_or(Fp2::ONE, |g| g[i]);
    if j >= leading {
        let value = nu.mul(read_gate(0)).mul(sum[0].add(lam));
        return vec![value.mul_base(zkp_core::field::Fp::new(half as u64)); degree+1];
    }
    let rep = 1usize << (n-leading);
    let compact_half = 1usize << (leading-j-1);
    assert_eq!(left.len()*right.len(), compact_half);
    let mut hs = vec![Fp2::ZERO; degree+1];
    for u in 0..compact_half {
        let i = u*rep;
        let w = left[u/right.len()].mul(right[u%right.len()]);
        let (mut s, mut g) = (sum[i], read_gate(i));
        let (ds,dg) = (sum[i+half].sub(s),read_gate(i+half).sub(g));
        for t in 0..=degree {
            if t != 1 || !skip_one {
                hs[t] = hs[t].add(w.mul(nu.mul(g).mul(s.add(lam))));
            }
            if t != degree { s=s.add(ds);g=g.add(dg); }
        }
    }
    let multiplicity = zkp_core::field::Fp::new(rep as u64);
    for h in &mut hs { *h = h.mul_base(multiplicity); }
    hs
}
