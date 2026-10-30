use super::*;
use crate::sumcheck::{self, CfsMask, CfsMasker, SumcheckProof};
use crate::rng::ZkRng;
use std::sync::atomic::{AtomicUsize, Ordering};

fn value(seed: &mut u64) -> Fp2 {
    *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    let a = *seed;
    *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    Fp2::new(crate::field::Fp::new(a), crate::field::Fp::new(*seed))
}

fn tables(n: usize, seed: &mut u64) -> Vec<Vec<Fp2>> {
    (0..3).map(|_| (0..1usize << n).map(|_| value(seed)).collect()).collect()
}

fn poly(v: &[Fp2], degree: usize) -> Fp2 {
    let mut y = v[0];
    for _ in 1..degree { y = y.mul(v[1]); }
    y.add(v[2])
}

fn total(t: &[Vec<Fp2>], degree: usize) -> Fp2 {
    (0..t[0].len()).fold(Fp2::ZERO, |a, i| a.add(poly(&[t[0][i], t[1][i], t[2][i]], degree)))
}

fn transcript(tagged: bool) -> Transcript {
    if tagged { Transcript::new_tagged(b"round-evaluator-test", [29; 32]) }
    else { Transcript::new(b"round-evaluator-test") }
}

fn equal(a: &ProverOutput, b: &ProverOutput) {
    assert_eq!(a.proof.rounds, b.proof.rounds);
    let (mut x, mut y) = (Vec::new(), Vec::new());
    a.proof.write_bytes(&mut x); b.proof.write_bytes(&mut y);
    assert_eq!(x, y);
    assert_eq!(a.challenges, b.challenges);
    assert_eq!(a.finals, b.finals);
}

fn plain_case(n: usize, degree: usize, tagged: bool, seed: &mut u64) {
    let t = tables(n, seed);
    let initial = total(&t, degree);
    let mut reference_tables = t.clone();
    let mut reference_tr = transcript(tagged);
    let reference = sumcheck::prove(&mut reference_tables, degree, |v| poly(v, degree), &mut reference_tr);
    for mode in 0..3 {
        let mut candidate_tables = t.clone();
        let mut tr = transcript(tagged);
        let mut ev = ClosureRounds::new(&mut candidate_tables, degree, |v: &[Fp2]| poly(v, degree));
        if mode != 0 { ev = ev.recover_one(if mode == 1 { Some(initial) } else { None }); }
        let candidate = prove_rounds(&mut ev, &mut tr);
        equal(&reference, &candidate);
        assert_eq!(candidate_tables, reference_tables);
        assert_eq!(tr.state(), reference_tr.state());
        let mut ref_next = Transcript::clone_state(&reference_tr);
        assert_eq!(tr.challenge_fp2(), ref_next.challenge_fp2());
        let (fin, rho) = sumcheck::verify(initial, degree, n, &candidate.proof, &mut transcript(tagged)).unwrap();
        assert_eq!(rho, candidate.challenges);
        assert_eq!(fin, poly(&candidate.finals, degree));
    }
}

#[test]
fn all_points_seeded_and_unseeded_match_original_bytes() {
    let mut seed = 119;
    for tagged in [false, true] {
        for degree in 1..=6 {
            for n in [0, 1, 2, 5, 9] { plain_case(n, degree, tagged, &mut seed); }
        }
    }
}

#[test]
fn parallel_and_serial_folds_match_original() {
    let mut seed = 781;
    for threads in [1, 2] {
        rayon::ThreadPoolBuilder::new().num_threads(threads).build().unwrap().install(|| {
            // half * tables = 98,304 exceeds the 65,536 parallel cutoff.
            plain_case(16, 4, true, &mut seed);
        });
    }
}

fn masked_case(n: usize, degree: usize, ext: usize, tagged: bool, seed: &mut u64) {
    let t = tables(n, seed);
    let initial = total(&t, degree);
    let c = value(seed);
    assert!(!c.is_zero());
    let mut rng = ZkRng::new(*seed, b"round-evaluator-mask");
    let mask = CfsMask::random(&mut rng, n + ext, degree);
    let extensions: Vec<Vec<Fp2>> = (0..ext).map(|_| vec![Fp2::ZERO, value(seed), Fp2::ZERO]).collect();
    let mut results = Vec::new();
    for mode in 0..4 {
        let mut ts = t.clone();
        let mut tr = transcript(tagged);
        tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
        let out = if mode == 0 {
            sumcheck::prove(&mut ts, degree, |v| poly(v, degree), &mut tr)
        } else {
            let mut ev = ClosureRounds::new(&mut ts, degree, |v: &[Fp2]| poly(v, degree));
            if mode >= 2 { ev = ev.recover_one(if mode == 2 { Some(initial) } else { None }); }
            prove_rounds(&mut ev, &mut tr)
        };
        let (_, mut rounds) = tr.take_masker();
        let mut rho = out.challenges.clone();
        let mut cur = out.finals.clone();
        for values in &extensions {
            let mut sk = sumcheck::extension_round(&cur, values, degree, |v| poly(v, degree));
            let gk = mask.round(rho.len(), &rho);
            for (x, g) in sk.iter_mut().zip(gk) { *x = x.add(c.mul(g)); }
            tr.absorb_fp2(b"sc-round", &sk);
            rounds.push(sk);
            let r = tr.challenge_fp2();
            for (x, y) in cur.iter_mut().zip(values) { *x = sumcheck::masked_terminal(*x, *y, r); }
            rho.push(r);
        }
        let proof = SumcheckProof { rounds };
        let (fin, vrho) = sumcheck::verify(initial.add(c.mul(mask.total())), degree, n + ext, &proof, &mut transcript(tagged)).unwrap();
        assert_eq!(vrho, rho);
        assert_eq!(fin, poly(&cur, degree).add(c.mul(mask.eval(&rho))));
        let mut bytes = Vec::new(); proof.write_bytes(&mut bytes);
        results.push((out, bytes, rho, cur, tr.state(), tr.challenge_fp2()));
    }
    for r in &results[1..] {
        equal(&results[0].0, &r.0);
        assert_eq!((&results[0].1, &results[0].2, &results[0].3, results[0].4, results[0].5), (&r.1, &r.2, &r.3, r.4, r.5));
    }
}

#[test]
fn masked_transcripts_and_one_or_two_extension_rounds_match() {
    let mut seed = 987;
    for tagged in [false, true] {
        for degree in 1..=6 {
            for ext in [1, 2] {
                for n in [0, 1, 3, 7] { masked_case(n, degree, ext, tagged, &mut seed); }
            }
        }
    }
}

#[test]
fn release_recovery_actually_skips_one_evaluation_per_pair() {
    let n = 6;
    let degree = 4;
    let mut seed = 121;
    let ts = tables(n, &mut seed);
    let initial = total(&ts, degree);
    for mode in 0..3 {
        let calls = AtomicUsize::new(0);
        let mut t = ts.clone();
        let mut ev = ClosureRounds::new(&mut t, degree, |v: &[Fp2]| {
            calls.fetch_add(1, Ordering::Relaxed);
            poly(v, degree)
        });
        if mode != 0 { ev = ev.recover_one(if mode == 1 { Some(initial) } else { None }); }
        prove_rounds(&mut ev, &mut transcript(false));
        let pairs = (1usize << n) - 1;
        let skipped = if cfg!(debug_assertions) || mode == 0 { 0 }
            else if mode == 1 { pairs } else { pairs - (1usize << (n - 1)) };
        assert_eq!(calls.load(Ordering::Relaxed), (degree + 1) * pairs - skipped);
    }
}

#[test]
fn wrong_claim_cannot_pass_the_terminal_check() {
    let degree = 3;
    let mut seed = 521;
    let mut ts = tables(4, &mut seed);
    let wrong = total(&ts, degree).add(Fp2::ONE);
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let mut ev = ClosureRounds::new(&mut ts, degree, |v: &[Fp2]| poly(v, degree)).recover_one(Some(wrong));
        prove_rounds(&mut ev, &mut transcript(false))
    }));
    if cfg!(debug_assertions) { assert!(result.is_err()); }
    else {
        let out = result.unwrap();
        let (fin, _) = sumcheck::verify(wrong, degree, 4, &out.proof, &mut transcript(false)).unwrap();
        assert_ne!(fin, poly(&out.finals, degree));
    }
}

#[test]
fn evaluator_need_not_be_sync_and_supports_trait_objects() {
    struct NonSync { round: std::cell::Cell<usize> }
    impl SumcheckRounds for NonSync {
        fn n_vars(&self) -> usize { 1 }
        fn degree(&self) -> usize { 1 }
        fn round(&mut self, j: usize) -> Vec<Fp2> {
            assert_eq!(j, self.round.get());
            vec![Fp2::ZERO; 2]
        }
        fn fold(&mut self, _: Fp2) { self.round.set(1); }
        fn finals(&self) -> Vec<Fp2> { vec![Fp2::ZERO] }
    }
    let mut ev: Box<dyn SumcheckRounds> = Box::new(NonSync { round: std::cell::Cell::new(0) });
    let out = prove_rounds(ev.as_mut(), &mut transcript(false));
    assert_eq!(out.proof.rounds, vec![vec![Fp2::ZERO; 2]]);
}

#[test]
fn wrong_round_length_is_rejected() {
    struct Bad;
    impl SumcheckRounds for Bad {
        fn n_vars(&self) -> usize { 1 }
        fn degree(&self) -> usize { 2 }
        fn round(&mut self, _: usize) -> Vec<Fp2> { vec![Fp2::ZERO; 2] }
        fn fold(&mut self, _: Fp2) { panic!("must not fold malformed output") }
        fn finals(&self) -> Vec<Fp2> { unreachable!() }
    }
    assert!(std::panic::catch_unwind(|| prove_rounds(&mut Bad, &mut transcript(false))).is_err());
}
