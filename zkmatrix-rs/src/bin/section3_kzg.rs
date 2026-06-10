use blstrs::{Bls12, G1Projective, G2Prepared, G2Projective, Gt, Scalar};
use ff::Field;
use group::{Curve, Group};
use pairing::{MillerLoopResult, MultiMillerLoop};
use std::env;
use std::time::Instant;

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e3779b97f4a7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
    z ^ (z >> 31)
}

fn scalar_from_rng(rng: &mut u64) -> Scalar {
    let x = splitmix64(rng);
    let scalar = Scalar::from(x);
    if bool::from(scalar.is_zero()) {
        Scalar::ONE
    } else {
        scalar
    }
}

fn random_coefficients(len: usize, seed: u64) -> Vec<Scalar> {
    let mut rng = seed;
    (0..len).map(|_| scalar_from_rng(&mut rng)).collect()
}

fn powers_of_tau_g1(len: usize, tau: Scalar) -> Vec<G1Projective> {
    let generator = G1Projective::generator();
    let mut cur = Scalar::ONE;
    let mut powers = Vec::with_capacity(len);
    for _ in 0..len {
        powers.push(generator * cur);
        cur *= tau;
    }
    powers
}

fn msm_g1(points: &[G1Projective], scalars: &[Scalar]) -> G1Projective {
    assert_eq!(points.len(), scalars.len());
    if scalars.len() < 128 {
        let mut acc = G1Projective::identity();
        for (&point, &scalar) in points.iter().zip(scalars.iter()) {
            acc += point * scalar;
        }
        acc
    } else {
        G1Projective::multi_exp(points, scalars)
    }
}

fn eval_poly(coeffs: &[Scalar], x: Scalar) -> Scalar {
    let mut acc = Scalar::ZERO;
    for &coeff in coeffs.iter().rev() {
        acc *= x;
        acc += coeff;
    }
    acc
}

fn quotient_coefficients(coeffs: &[Scalar], zeta: Scalar) -> Vec<Scalar> {
    assert!(coeffs.len() >= 2);
    let degree = coeffs.len() - 1;
    let mut quotient = vec![Scalar::ZERO; degree];
    quotient[degree - 1] = coeffs[degree];
    for i in (1..degree).rev() {
        quotient[i - 1] = coeffs[i] + zeta * quotient[i];
    }
    quotient
}

fn verify_kzg(
    commitment: G1Projective,
    value: Scalar,
    witness: G1Projective,
    tau_g2: G2Projective,
    zeta: Scalar,
) -> bool {
    let value_g1 = G1Projective::generator() * value;
    let lhs_g1 = commitment - value_g1;
    let rhs_g2 = tau_g2 - G2Projective::generator() * zeta;
    let g2 = G2Projective::generator().to_affine();
    let lhs_g1_affine = lhs_g1.to_affine();
    let neg_witness_affine = (-witness).to_affine();
    let g2_prepared = G2Prepared::from(g2);
    let rhs_g2_prepared = G2Prepared::from(rhs_g2.to_affine());
    Bls12::multi_miller_loop(&[
        (&lhs_g1_affine, &g2_prepared),
        (&neg_witness_affine, &rhs_g2_prepared),
    ])
    .final_exponentiation()
        == Gt::identity()
}

fn self_test() {
    let degree = 64;
    let mut rng = 0x5173_ec71_0033_0001;
    let tau = scalar_from_rng(&mut rng);
    let zeta = scalar_from_rng(&mut rng);
    let coeffs = random_coefficients(degree + 1, 0xABCD_1234);
    let powers = powers_of_tau_g1(coeffs.len(), tau);
    let quotient = quotient_coefficients(&coeffs, zeta);
    let commitment = msm_g1(&powers, &coeffs);
    let value = eval_poly(&coeffs, zeta);
    let witness = msm_g1(&powers[..quotient.len()], &quotient);
    let tau_g2 = G2Projective::generator() * tau;

    assert!(verify_kzg(commitment, value, witness, tau_g2, zeta));
    assert!(!verify_kzg(
        commitment,
        value + Scalar::ONE,
        witness,
        tau_g2,
        zeta
    ));
    println!("section3-kzg self-test ok");
}

fn bench(degree: usize, seed: u64) {
    let coeff_count = degree + 1;
    let mut rng = seed ^ 0xA5A5_5A5A_DEAD_BEEF;
    let tau = scalar_from_rng(&mut rng);
    let zeta = scalar_from_rng(&mut rng);
    let coeffs = random_coefficients(coeff_count, seed);

    let start = Instant::now();
    let powers = powers_of_tau_g1(coeff_count, tau);
    let tau_g2 = G2Projective::generator() * tau;
    let setup_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let commitment = msm_g1(&powers, &coeffs);
    let direct_verifier_msm_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let value = eval_poly(&coeffs, zeta);
    let quotient = quotient_coefficients(&coeffs, zeta);
    let witness = msm_g1(&powers[..quotient.len()], &quotient);
    let open_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let verified = verify_kzg(commitment, value, witness, tau_g2, zeta);
    let verify_s = start.elapsed().as_secs_f64();

    println!(
        "{degree},{coeff_count},{setup_s:.9},{direct_verifier_msm_s:.9},{open_s:.9},{verify_s:.9},{:.3},{verified}",
        verify_s / direct_verifier_msm_s
    );
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  section3_kzg self-test");
    eprintln!("  section3_kzg bench <degree> [degree...]");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        usage();
        std::process::exit(1);
    }
    match args[1].as_str() {
        "self-test" => self_test(),
        "bench" => {
            if args.len() < 3 {
                usage();
                std::process::exit(1);
            }
            println!(
                "degree,coefficients,setup_s,direct_verifier_msm_s,open_s,accelerated_verify_s,verify_over_direct_msm,verified"
            );
            for degree_arg in &args[2..] {
                let degree: usize = degree_arg.parse().unwrap();
                bench(degree, 0x5151_0000 + degree as u64);
            }
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
