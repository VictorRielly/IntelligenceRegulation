//! Caller-level checks of the additive masked round interface.
use super::*;
use crate::sumcheck::ClosureRounds;

fn run_pair(n: usize, ext: usize, tagged: bool) {
    let degree = 3;
    let mut rng = ZkRng::new(951 + n as u64, b"masked-round-interface");
    let tables = vec![rng.fp2_vec(1 << n), rng.fp2_vec(1 << n)];
    let poly = |v: &[Fp2]| v[0].mul(v[1]).mul(v[1]);
    let total = (0..1 << n).fold(Fp2::ZERO, |a, i| a.add(poly(&[tables[0][i], tables[1][i]])));
    let mask = CfsMask::random(&mut rng, n + ext, degree);
    let c = Fp2::from_u64(17);
    let transcript = || if tagged { Transcript::new_tagged(b"masked-round-interface", [23; 32]) }
        else { Transcript::new(b"masked-round-interface") };
    for initial in [None, Some(total)] {
        let (mut old_tables, mut new_tables) = (tables.clone(), tables.clone());
        let (mut old_tr, mut new_tr) = (transcript(), transcript());
        let old = masked_prove(&mut old_tables, degree, poly, &mask, c, &mut old_tr);
        let mut ev = ClosureRounds::new(&mut new_tables, degree, poly).recover_one(initial);
        let new = masked_prove_rounds(&mut ev, &mask, c, &mut new_tr);
        assert_eq!(old, new);
        assert_eq!(old_tables, new_tables);
        assert_eq!(old_tr.state(), new_tr.state());
        assert_eq!(old_tr.challenge_fp2(), new_tr.challenge_fp2());
        // Both wrappers removed the masker, so a fresh one may be installed.
        new_tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
        new_tr.take_masker();
    }
}

#[test]
fn additive_masked_wrapper_matches_legacy_at_each_extension_count() {
    for tagged in [false, true] {
        for n in [0, 1, 5, 9] {
            for ext in [1, 2] { run_pair(n, ext, tagged); }
        }
    }
}

#[test]
fn evaluator_wrapper_refuses_zero_mask_before_touching_transcript() {
    let mut tables = vec![vec![Fp2::ONE; 4]];
    let mut ev = ClosureRounds::new(&mut tables, 1, |v: &[Fp2]| v[0]);
    let mut rng = ZkRng::new(61, b"masked-round-zero");
    let mask = CfsMask::random(&mut rng, 3, 1);
    let mut tr = Transcript::new(b"masked-round-zero");
    let before = tr.state();
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        masked_prove_rounds(&mut ev, &mask, Fp2::ZERO, &mut tr)
    }));
    assert!(result.is_err());
    assert_eq!(tr.state(), before);
    assert!(tr.take_masker().0.is_none());
}

#[test]
fn evaluator_wrapper_rejects_mask_shape_before_touching_transcript() {
    for (n, degree) in [(3, 2), (1, 1)] {
        let mut tables = vec![vec![Fp2::ONE; 4]];
        let mut ev = ClosureRounds::new(&mut tables, 1, |v: &[Fp2]| v[0]);
        let mut rng = ZkRng::new(13, b"masked-round-shape");
        let mask = CfsMask::random(&mut rng, n, degree);
        let mut tr = Transcript::new(b"masked-round-shape");
        let before = tr.state();
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            masked_prove_rounds(&mut ev, &mask, Fp2::ONE, &mut tr)
        }));
        assert!(result.is_err());
        assert_eq!(tr.state(), before);
        assert!(tr.take_masker().0.is_none());
    }
}
