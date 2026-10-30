use super::*;
use crate::field::Fp;
use crate::mle::eq_point;
use crate::rng::ZkRng;
use crate::sumcheck::{self, CfsMask, CfsMasker, ClosureRounds, SumcheckProof};
use crate::transcript::Transcript;
use std::sync::atomic::{AtomicUsize, Ordering};

fn value(s: &mut u64) -> Fp2 {
    *s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    let a = *s;
    *s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
    Fp2::new(Fp::new(a), Fp::new(*s))
}

fn fixture(n: usize, padded: bool, s: &mut u64) -> (Vec<Vec<Fp2>>, Vec<EqualityGroup>) {
    let groups: Vec<_> = [(0, n, if padded { 4 } else { 3 }),
        (0, n.saturating_sub(1), if padded { 2 } else { 1 }),
        (n.min(1), n.saturating_sub(2), 1)].iter().map(|&(start, len, degree)| EqualityGroup {
            point: (0..len).map(|_| value(s)).collect(), start, bracket_degree: degree,
        }).collect();
    let mut tables: Vec<Vec<Fp2>> = groups.iter().map(|g| (0..1usize << n).map(|i| {
        let point: Vec<_> = (g.start..g.start + g.point.len()).map(|j|
            Fp2::from_u64(((i >> (n - 1 - j)) & 1) as u64)).collect();
        eq_point(&g.point, &point)
    }).collect()).collect();
    tables.extend((0..5).map(|_| (0..1usize << n).map(|_| value(s)).collect()));
    (tables, groups)
}

fn bracket(g: usize, v: &[Fp2], padded: bool) -> Fp2 {
    let gate = if padded { v[7] } else { Fp2::ONE };
    match g {
        0 => gate.mul(v[3].mul(v[4]).mul(v[5]).add(v[6])),
        1 => gate.mul(v[4].add(Fp2::from_u64(17))),
        2 => v[5].sub(v[6]),
        _ => unreachable!(),
    }
}

fn case(n: usize, padded: bool, tagged: bool, ext: usize, seed: &mut u64) {
    let (tables, groups) = fixture(n, padded, seed);
    let degree = if padded { 5 } else { 4 };
    let poly = |v: &[Fp2]| (0..3).fold(Fp2::ZERO, |a, g| a.add(v[g].mul(bracket(g, v, padded))));
    let mut rng = ZkRng::new(*seed, b"grouped-native-oracle");
    let mask = CfsMask::random(&mut rng, n + ext, degree);
    let c = value(seed);
    let initial = (0..1usize << n).fold(Fp2::ZERO, |a, i| {
        a.add(poly(&tables.iter().map(|t| t[i]).collect::<Vec<_>>()))
    });
    let extensions: Vec<Vec<_>> = (0..ext).map(|_| (0..tables.len()).map(|_| value(seed)).collect()).collect();
    let mut outputs = Vec::new();
    for mode in 0..3 {
        let mut ts = tables.clone();
        let mut tr = if tagged { Transcript::new_tagged(b"grouped", [87; 32]) } else { Transcript::new(b"grouped") };
        let mut verifier = Transcript::clone_state(&tr);
        tr.set_masker(Box::new(CfsMasker { mask: mask.clone(), c, challenges: Vec::new() }));
        let out = match mode {
            0 => sumcheck::prove(&mut ts, degree, &poly, &mut tr),
            1 => sumcheck::prove_rounds(&mut ClosureRounds::new(&mut ts, degree, &poly).recover_one(None), &mut tr),
            _ => sumcheck::prove_rounds(&mut GroupedEqRounds::new(&mut ts, degree, groups.clone(),
                |g, v: &[Fp2]| bracket(g, v, padded)), &mut tr),
        };
        let (_, mut rounds) = tr.take_masker();
        let mut rho = out.challenges.clone();
        let mut finals = out.finals.clone();
        for e in &extensions {
            let mut sk = sumcheck::extension_round(&finals, e, degree, &poly);
            for (x, g) in sk.iter_mut().zip(mask.round(rho.len(), &rho)) { *x = x.add(c.mul(g)); }
            tr.absorb_fp2(b"sc-round", &sk);
            rounds.push(sk);
            let r = tr.challenge_fp2();
            for (v, e) in finals.iter_mut().zip(e) { *v = sumcheck::masked_terminal(*v, *e, r); }
            rho.push(r);
        }
        let proof = SumcheckProof { rounds };
        // Arbitrary extension vectors are used only to check exact parity:
        // they need not satisfy the profile's zero-extension identity.
        if ext == 0 {
            let (fin, vrho) = sumcheck::verify(initial.add(c.mul(mask.total())), degree, n, &proof, &mut verifier).unwrap();
            assert_eq!(vrho, rho);
            assert_eq!(fin, poly(&finals).add(c.mul(mask.eval(&rho))));
        }
        let mut bytes = Vec::new(); proof.write_bytes(&mut bytes);
        outputs.push((bytes, out.proof.rounds, rho, finals, ts, tr.state(), tr.challenge_fp2()));
    }
    assert_eq!(outputs[0], outputs[1]);
    assert_eq!(outputs[0], outputs[2]);
}

#[test]
fn native_masked_bytes_folds_finals_and_extensions_match() {
    let mut seed = 20260926;
    for padded in [false, true] {
        for tagged in [false, true] {
            for ext in [0, 1, 2] {
                // The existing CFS mask requires at least one main/extension round.
                for n in [0, 1, 2, 4, 8] {
                    if n + ext > 0 { case(n, padded, tagged, ext, &mut seed); }
                }
            }
        }
    }
}

#[test]
fn parallel_rounds_match_original_on_one_and_two_threads() {
    for threads in [1, 2] {
        rayon::ThreadPoolBuilder::new().num_threads(threads).build().unwrap().install(|| {
            case(15, true, true, 0, &mut 742);
        });
    }
}

#[test]
fn zero_factors_and_prefixes_use_explicit_rounds() {
    let (mut tables, mut groups) = fixture(4, true, &mut 197);
    groups[0].point[0] = Fp2::ONE;
    groups[1].point[1] = Fp2::ZERO;
    for (g, desc) in groups.iter().enumerate() {
        tables[g] = (0..16).map(|i| eq_point(&desc.point, &(desc.start..desc.start + desc.point.len())
            .map(|j| Fp2::from_u64(((i >> (3 - j)) & 1) as u64)).collect::<Vec<_>>())).collect();
    }
    let mut old = tables.clone();
    let poly = |v: &[Fp2]| (0..3).fold(Fp2::ZERO, |a, g| a.add(v[g].mul(bracket(g, v, true))));
    let mut ref_ev = ClosureRounds::new(&mut old, 5, poly).recover_one(None);
    let mut fast = GroupedEqRounds::new(&mut tables, 5, groups, |g, v: &[Fp2]| bracket(g, v, true));
    for (j, r) in [Fp2::ZERO, Fp2::ONE, Fp2::U, Fp2::from_u64(7)].iter().enumerate() {
        assert_eq!(fast.round(j), ref_ev.round(j));
        ref_ev.fold(*r); fast.fold(*r);
    }
    assert_eq!(fast.finals(), ref_ev.finals());
}

#[test]
fn expensive_group_calls_are_reduced_without_changing_bytes() {
    let (tables, groups) = fixture(8, true, &mut 123);
    let old_count = AtomicUsize::new(0);
    let new_count = AtomicUsize::new(0);
    let mut old = tables.clone();
    let mut new = tables;
    let mut old_tr = Transcript::new(b"count");
    let mut new_tr = Transcript::new(b"count");
    let a = sumcheck::prove_rounds(&mut ClosureRounds::new(&mut old, 5, |v: &[Fp2]| {
        old_count.fetch_add(1, Ordering::Relaxed);
        (0..3).fold(Fp2::ZERO, |a, g| a.add(v[g].mul(bracket(g, v, true))))
    }).recover_one(None), &mut old_tr);
    let b = sumcheck::prove_rounds(&mut GroupedEqRounds::new(&mut new, 5, groups, |g, v: &[Fp2]| {
        if g == 0 { new_count.fetch_add(1, Ordering::Relaxed); }
        bracket(g, v, true)
    }), &mut new_tr);
    assert_eq!(a.proof.rounds, b.proof.rounds);
    assert_eq!(a.challenges, b.challenges);
    assert_eq!(old_tr.state(), new_tr.state());
    assert!(new_count.load(Ordering::Relaxed) < old_count.load(Ordering::Relaxed));
    if !cfg!(debug_assertions) {
        assert_eq!(old_count.load(Ordering::Relaxed), 1403);
        assert_eq!(new_count.load(Ordering::Relaxed), 1148);
    }
}

#[test]
fn wrong_support_is_detected_by_original_round_oracle() {
    let (tables, mut groups) = fixture(4, true, &mut 918);
    groups[1].point.push(Fp2::from_u64(7));
    let mut old = tables.clone();
    let mut new = tables;
    let mut oracle = ClosureRounds::new(&mut old, 5, |v: &[Fp2]|
        (0..3).fold(Fp2::ZERO, |a, g| a.add(v[g].mul(bracket(g, v, true)))));
    let mut bad = GroupedEqRounds::new(&mut new, 5, groups, |g, v: &[Fp2]| bracket(g, v, true));
    assert_ne!(oracle.round(0), bad.round(0));
}
