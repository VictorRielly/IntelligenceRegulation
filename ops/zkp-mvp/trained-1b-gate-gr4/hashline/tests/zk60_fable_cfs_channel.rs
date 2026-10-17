//! FA6 cross-check: the ACTUAL `CfsMask` round messages, total and terminal
//! evaluation (zkp-core/src/sumcheck.rs, re-exported by hashline) against the
//! values Fable's Python model predicts for the same coefficients
//! (`scripts/zk60_fable_cfs_channel.py::rust_fixture`; the same constants are
//! embedded in `tests/test_zk60_fable_cfs_channel.py`). Reviewer: Claude
//! Fable 5.1, 2026-09-08 session; source pin cfa46f6. CPU only, tiny shape.
//!
//!   env CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2 HL_GPU=0 flock /tmp/zk-heavy.lock \
//!     cargo test --release --offline --manifest-path hashline/Cargo.toml \
//!     --test zk60_fable_cfs_channel -- --nocapture --test-threads=2
use hashline::field::{Fp, Fp2};
use hashline::mle::interpolate_eval;
use hashline::sumcheck::{extension_round, masked_terminal, CfsMask};

const P: u64 = 0xFFFF_FFFF_0000_0001;

fn f2(c0: u64, c1: u64) -> Fp2 {
    Fp2::new(Fp::new(c0), Fp::new(c1))
}

fn dot(w: &[Fp2], c: &[Fp2]) -> Fp2 {
    w.iter().zip(c.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)))
}

/// The fixture: n_vars 3, degree 2 (8 coefficients in the layout
/// [a_0, a', a_{0,1}, a_{0,2}, a_{1,1}, a_{1,2}, a_{2,1}, a_{2,2}]), real parts
/// as negative representatives so that every value is a full-width residue.
const COEFFS: [(u64, u64); 8] = [(P - 3, 1), (P - 5, 2), (P - 7, 3), (P - 11, 4), (P - 13, 5), (P - 17, 6), (P - 20, 7), (P - 23, 9)];
const RHO: [(u64, u64); 3] = [(2, 1), (5, P - 3), (7, 4)];
/// round j at X = 0, 1, 2 (round 2 is the extension-round position)
const ROUNDS: [[(u64, u64); 3]; 3] = [
    [(18446744069414584163, 58), (18446744069414584086, 88), (18446744069414583921, 150)],
    [(18446744069414584268, 16), (18446744069414584212, 37), (18446744069414584088, 82)],
    [(18446744069414581390, 1102), (18446744069414581388, 1101), (18446744069414581340, 1118)],
];
const TOTAL: (u64, u64) = (18446744069414583928, 146);
const EVAL: (u64, u64) = (18446744069414581082, 1277);

#[test]
fn cfs_mask_rounds_total_and_eval_match_the_python_model() {
    let coeffs: Vec<Fp2> = COEFFS.iter().map(|&(a, b)| f2(a, b)).collect();
    let mask = CfsMask { n_vars: 3, degree: 2, coeffs: coeffs.clone() };
    assert_eq!(CfsMask::len(3, 2), 8);
    let rho: Vec<Fp2> = RHO.iter().map(|&(a, b)| f2(a, b)).collect();
    for j in 0..3 {
        let got = mask.round(j, &rho[..j]);
        let want: Vec<Fp2> = ROUNDS[j].iter().map(|&(a, b)| f2(a, b)).collect();
        println!("[FA6] round {j}: {:?}", got.iter().map(|v| (v.c0.0, v.c1.0)).collect::<Vec<_>>());
        assert_eq!(got, want, "round {j} differs from the Python model");
    }
    println!("[FA6] total: {:?} eval: {:?}", (mask.total().c0.0, mask.total().c1.0), (mask.eval(&rho).c0.0, mask.eval(&rho).c1.0));
    assert_eq!(mask.total(), f2(TOTAL.0, TOTAL.1), "total differs from the Python model");
    assert_eq!(mask.eval(&rho), f2(EVAL.0, EVAL.1), "eval differs from the Python model");
    // the chain the verifier checks on the g-part: round sums and the terminal
    let r0 = mask.round(0, &[]);
    assert_eq!(r0[0].add(r0[1]), mask.total());
    for j in 1..3 {
        let prev = mask.round(j - 1, &rho[..j - 1]);
        let cur = mask.round(j, &rho[..j]);
        assert_eq!(cur[0].add(cur[1]), interpolate_eval(&prev, rho[j - 1]), "round {j} consistency");
    }
    assert_eq!(interpolate_eval(&mask.round(2, &rho[..2]), rho[2]), mask.eval(&rho), "terminal = g(rho)");
    // the two functionals mask_open proves are these weight vectors
    assert_eq!(dot(&CfsMask::sum_weights(3, 2), &coeffs), mask.total());
    assert_eq!(dot(&CfsMask::eval_weights(&rho, 2), &coeffs), mask.eval(&rho));
    let sw = CfsMask::sum_weights(3, 2);
    assert_eq!(sw[0], f2(8, 0));
    assert_eq!(sw[1], Fp2::ONE);
    assert!(sw[2..].iter().all(|w| *w == f2(4, 0)));
}

#[test]
fn extension_round_vanishes_at_one_only_with_a_public_factor() {
    // s_k(X) = poly((1 - X) fin + X ext): with a public factor (ext = 0) the value
    // at X = 1 is poly(exts) = 0 -- the identity the extension round relies on.
    let finals = [f2(11, 3), f2(P - 9, 17), f2(5, 5)];
    let exts = [Fp2::ZERO, f2(4, P - 2), f2(8, 1)];
    let poly = |v: &[Fp2]| v[0].mul(v[1].mul(v[2]));
    let s = extension_round(&finals, &exts, 3, poly);
    assert_eq!(s.len(), 4);
    assert_eq!(s[0], poly(&finals));
    assert_eq!(s[1], Fp2::ZERO);
    let e = f2(3, P - 1);
    assert_eq!(masked_terminal(finals[1], exts[1], e), finals[1].add(e.mul(exts[1].sub(finals[1]))));
    // a bilinear private x private round does NOT vanish at 1: the P3 matmul
    // sumchecks therefore take TWO extension rounds (mask_specs_v3's comment).
    let poly2 = |v: &[Fp2]| v[0].mul(v[1]);
    let s2 = extension_round(&finals[..2], &[f2(1, 0), f2(2, 0)], 2, poly2);
    assert_ne!(s2[1], Fp2::ZERO);
}
