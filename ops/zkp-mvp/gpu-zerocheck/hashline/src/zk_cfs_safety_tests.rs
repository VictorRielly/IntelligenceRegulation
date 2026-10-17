use super::*;
use std::panic::{catch_unwind, AssertUnwindSafe};

#[test]
fn zero_mask_challenge_aborts_without_resampling() {
    let mut draws = 0;
    let result = catch_unwind(AssertUnwindSafe(|| {
        mask_challenge(|| {
            draws += 1;
            if draws == 1 {
                Fp2::ZERO
            } else {
                Fp2::ONE
            }
        })
    }));
    assert!(result.is_err());
    assert_eq!(draws, 1);

    let mut tr = Transcript::new(b"cfs-challenge-parity");
    let mut original = Transcript::clone_state(&tr);
    assert_eq!(
        mask_challenge(|| tr.challenge_fp2()),
        original.challenge_fp2()
    );
    assert_eq!(tr.state(), original.state());
    assert_eq!(tr.challenge_fp2(), original.challenge_fp2());
}

#[test]
fn malformed_extension_refuses_before_changing_transcript_or_output() {
    let mask = CfsMask::random(&mut ZkRng::new(7, b"public-cfs-fixture"), 2, 2);
    for (degree, c) in [(1, Fp2::ONE), (3, Fp2::ONE), (2, Fp2::ZERO)] {
        let mut tr = Transcript::new(b"cfs-refusal");
        let mut expected = Transcript::clone_state(&tr);
        let mut rounds = vec![vec![Fp2::ONE; 3]];
        let original_rounds = rounds.clone();
        let result = catch_unwind(AssertUnwindSafe(|| {
            extension(
                &[Fp2::ONE],
                &[Fp2::ONE],
                degree,
                |v| v[0],
                &mask,
                c,
                &[Fp2::from_u64(3)],
                &mut rounds,
                &mut tr,
            )
        }));
        assert!(result.is_err(), "degree {degree}, coefficient {c:?}");
        assert_eq!(rounds, original_rounds);
        assert_eq!(tr.state(), expected.state());
        assert_eq!(tr.challenge_fp2(), expected.challenge_fp2());
    }
    let mut tr = Transcript::new(b"cfs-main-refusal");
    let mut expected = Transcript::clone_state(&tr);
    let mut tables = vec![vec![Fp2::ONE; 2]];
    assert!(catch_unwind(AssertUnwindSafe(|| masked_prove(
        &mut tables,
        2,
        |v| v[0],
        &mask,
        Fp2::ZERO,
        &mut tr,
    )))
    .is_err());
    assert_eq!(tables, vec![vec![Fp2::ONE; 2]]);
    assert!(tr.take_masker().0.is_none());
    assert_eq!(tr.challenge_fp2(), expected.challenge_fp2());
}

#[test]
fn complete_extension_matches_the_masked_round_and_terminal_identity() {
    let mask = CfsMask::random(&mut ZkRng::new(9, b"public-cfs-fixture"), 2, 2);
    let finals = [Fp2::from_u64(3), Fp2::from_u64(7)];
    let exts = [Fp2::from_u64(11), Fp2::ZERO];
    let prev = [Fp2::from_u64(5)];
    let c = Fp2::new(Fp::new(2), Fp::new(3));
    let poly = |v: &[Fp2]| v[0].mul(v[1]);
    let expected: Vec<_> = extension_round(&finals, &exts, 2, poly)
        .iter()
        .zip(mask.round(1, &prev))
        .map(|(s, g)| s.add(c.mul(g)))
        .collect();
    let mut tr = Transcript::new(b"cfs-extension-parity");
    let mut original = Transcript::clone_state(&tr);
    original.absorb_fp2(b"sc-round", &expected);
    let expected_rho = original.challenge_fp2();
    let mut rounds = Vec::new();
    let rho = extension(
        &finals,
        &exts,
        2,
        poly,
        &mask,
        c,
        &prev,
        &mut rounds,
        &mut tr,
    );
    assert_eq!(rounds, vec![expected.clone()]);
    assert_eq!(rho, expected_rho);
    assert_eq!(tr.state(), original.state());
    let terminals = [
        masked_terminal(finals[0], exts[0], rho),
        masked_terminal(finals[1], exts[1], rho),
    ];
    assert_eq!(
        crate::mle::interpolate_eval(&expected, rho),
        poly(&terminals).add(c.mul(mask.eval(&[prev[0], rho])))
    );
}
