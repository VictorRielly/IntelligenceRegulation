use blstrs::{Bls12, G1Projective, G2Prepared, G2Projective, Gt, Scalar};
use ff::{Field, PrimeField};
use group::{Curve, Group};
use pairing::{MillerLoopResult, MultiMillerLoop};
use sha2::{Digest, Sha256};
use std::env;
use std::time::Instant;

const DST: &[u8] = b"BLS12381G1_XMD:SHA-256_SSWU_RO_ZKMATRIX";

#[derive(Clone)]
struct Bases {
    g: Vec<G1Projective>,
    h: Vec<G1Projective>,
    u: G1Projective,
}

#[derive(Clone)]
struct IpProof {
    n: usize,
    left: Vec<G1Projective>,
    right: Vec<G1Projective>,
    a_final: Scalar,
    b_final: Scalar,
}

struct StructuredBases {
    ipa: Bases,
    srs_g1: Vec<G1Projective>,
    tau_g2: G2Projective,
}

struct StructuredIpProof {
    ipa: IpProof,
    kzg_witness: G1Projective,
}

fn splitmix64(state: &mut u64) -> u64 {
    *state = state.wrapping_add(0x9e3779b97f4a7c15);
    let mut z = *state;
    z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
    z ^ (z >> 31)
}

fn scalar_from_rng(rng: &mut u64) -> Scalar {
    let scalar = Scalar::from(splitmix64(rng));
    if bool::from(scalar.is_zero()) {
        Scalar::ONE
    } else {
        scalar
    }
}

fn random_scalars(len: usize, seed: u64) -> Vec<Scalar> {
    let mut rng = seed;
    (0..len).map(|_| scalar_from_rng(&mut rng)).collect()
}

fn hash_to_scalar(chunks: &[&[u8]]) -> Scalar {
    for counter in 0u64.. {
        let mut hasher = Sha256::new();
        hasher.update(b"zkmatrix-curve-ipa-scalar");
        hasher.update(counter.to_le_bytes());
        for chunk in chunks {
            hasher.update(chunk);
        }
        let digest = hasher.finalize();
        let mut repr = [0u8; 32];
        repr.copy_from_slice(&digest);
        if let Some(scalar) = Scalar::from_repr_vartime(repr) {
            if !bool::from(scalar.is_zero()) {
                return scalar;
            }
        }
    }
    unreachable!()
}

fn hash_to_basis(label: &[u8], index: usize) -> G1Projective {
    let mut msg = Vec::with_capacity(label.len() + 16);
    msg.extend_from_slice(label);
    msg.extend_from_slice(&(index as u64).to_le_bytes());
    G1Projective::hash_to_curve(&msg, DST, &[])
}

fn make_bases(len: usize) -> Bases {
    Bases {
        g: (0..len).map(|i| hash_to_basis(b"g", i)).collect(),
        h: (0..len).map(|i| hash_to_basis(b"h", i)).collect(),
        u: hash_to_basis(b"u", 0),
    }
}

fn make_structured_bases(len: usize, tau: Scalar) -> StructuredBases {
    let generator = G1Projective::generator();
    let mut powers = Vec::with_capacity(2 * len);
    let mut cur = Scalar::ONE;
    for _ in 0..(2 * len) {
        powers.push(generator * cur);
        cur *= tau;
    }
    StructuredBases {
        ipa: Bases {
            g: powers[..len].to_vec(),
            h: powers[len..].to_vec(),
            u: hash_to_basis(b"u", 0),
        },
        srs_g1: powers,
        tau_g2: G2Projective::generator() * tau,
    }
}

fn dot(a: &[Scalar], b: &[Scalar]) -> Scalar {
    let mut acc = Scalar::ZERO;
    for (&x, &y) in a.iter().zip(b.iter()) {
        acc += x * y;
    }
    acc
}

fn msm(points: &[G1Projective], scalars: &[Scalar]) -> G1Projective {
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

fn commit_inner_product(bases: &Bases, a: &[Scalar], b: &[Scalar]) -> G1Projective {
    msm(&bases.g, a) + msm(&bases.h, b) + bases.u * dot(a, b)
}

fn challenge(
    domain: u64,
    round: usize,
    current: G1Projective,
    u: G1Projective,
    left: G1Projective,
    right: G1Projective,
) -> Scalar {
    let domain_bytes = domain.to_le_bytes();
    let round_bytes = (round as u64).to_le_bytes();
    let current_bytes = current.to_affine().to_compressed();
    let u_bytes = u.to_affine().to_compressed();
    let left_bytes = left.to_affine().to_compressed();
    let right_bytes = right.to_affine().to_compressed();
    hash_to_scalar(&[
        &domain_bytes,
        &round_bytes,
        &current_bytes,
        &u_bytes,
        &left_bytes,
        &right_bytes,
    ])
}

fn prove_ip(
    commitment: G1Projective,
    bases: &Bases,
    a_in: &[Scalar],
    b_in: &[Scalar],
    domain: u64,
) -> IpProof {
    assert_eq!(a_in.len(), b_in.len());
    assert!(a_in.len().is_power_of_two());
    let proof_n = a_in.len();
    let rounds = proof_n.trailing_zeros() as usize;
    let mut a = a_in.to_vec();
    let mut b = b_in.to_vec();
    let mut g = bases.g.clone();
    let mut h = bases.h.clone();
    let mut current = commitment;
    let mut left_messages = Vec::with_capacity(rounds);
    let mut right_messages = Vec::with_capacity(rounds);
    let mut len = proof_n;

    for round in 0..rounds {
        let half = len / 2;
        let left_cross = dot(&a[..half], &b[half..len]);
        let right_cross = dot(&a[half..len], &b[..half]);
        let left =
            msm(&g[half..len], &a[..half]) + msm(&h[..half], &b[half..len]) + bases.u * left_cross;
        let right =
            msm(&g[..half], &a[half..len]) + msm(&h[half..len], &b[..half]) + bases.u * right_cross;
        let x = challenge(domain, round, current, bases.u, left, right);
        let xi = x.invert().unwrap();
        let (a_left, a_right) = a[..len].split_at_mut(half);
        let (b_left, b_right) = b[..len].split_at_mut(half);
        let (g_left, g_right) = g[..len].split_at_mut(half);
        let (h_left, h_right) = h[..len].split_at_mut(half);
        for i in 0..half {
            a_left[i] += xi * a_right[i];
            b_left[i] += x * b_right[i];
            g_left[i] += g_right[i] * x;
            h_left[i] += h_right[i] * xi;
        }
        current = left * x + current + right * xi;
        left_messages.push(left);
        right_messages.push(right);
        len = half;
    }

    IpProof {
        n: proof_n,
        left: left_messages,
        right: right_messages,
        a_final: a[0],
        b_final: b[0],
    }
}

fn verify_ip(commitment: G1Projective, bases: &Bases, proof: &IpProof, domain: u64) -> bool {
    if proof.n != bases.g.len()
        || proof.n != bases.h.len()
        || proof.left.len() != proof.n.trailing_zeros() as usize
    {
        return false;
    }
    let mut g = bases.g.clone();
    let mut h = bases.h.clone();
    let mut current = commitment;
    let mut len = proof.n;
    for round in 0..proof.left.len() {
        let half = len / 2;
        let left = proof.left[round];
        let right = proof.right[round];
        let x = challenge(domain, round, current, bases.u, left, right);
        let xi = x.invert().unwrap();
        let (g_left, g_right) = g[..len].split_at_mut(half);
        let (h_left, h_right) = h[..len].split_at_mut(half);
        for i in 0..half {
            g_left[i] += g_right[i] * x;
            h_left[i] += h_right[i] * xi;
        }
        current = left * x + current + right * xi;
        len = half;
    }
    let expected =
        bases.u * (proof.a_final * proof.b_final) + g[0] * proof.a_final + h[0] * proof.b_final;
    current == expected
}

fn ipa_challenges(
    commitment: G1Projective,
    u: G1Projective,
    proof: &IpProof,
    domain: u64,
) -> Option<(Vec<Scalar>, G1Projective)> {
    if proof.left.len() != proof.n.trailing_zeros() as usize {
        return None;
    }
    let mut current = commitment;
    let mut challenges = Vec::with_capacity(proof.left.len());
    for round in 0..proof.left.len() {
        let left = proof.left[round];
        let right = proof.right[round];
        let x = challenge(domain, round, current, u, left, right);
        let xi = x.invert().unwrap();
        current = left * x + current + right * xi;
        challenges.push(x);
    }
    Some((challenges, current))
}

fn scalar_pow_usize(mut base: Scalar, mut exp: usize) -> Scalar {
    let mut acc = Scalar::ONE;
    while exp != 0 {
        if exp & 1 == 1 {
            acc *= base;
        }
        base *= base;
        exp >>= 1;
    }
    acc
}

fn fold_coefficients(challenges: &[Scalar], n: usize, inverse: bool) -> Vec<Scalar> {
    let mut coeffs = vec![Scalar::ONE; n];
    for (round, &x) in challenges.iter().enumerate() {
        let factor = if inverse { x.invert().unwrap() } else { x };
        let stride = n >> (round + 1);
        for (i, coeff) in coeffs.iter_mut().enumerate() {
            if (i & stride) != 0 {
                *coeff *= factor;
            }
        }
    }
    coeffs
}

fn structured_coefficients(proof: &IpProof, challenges: &[Scalar]) -> Vec<Scalar> {
    let n = proof.n;
    let g_coeffs = fold_coefficients(challenges, n, false);
    let h_coeffs = fold_coefficients(challenges, n, true);
    let mut coeffs = vec![Scalar::ZERO; 2 * n];
    for i in 0..n {
        coeffs[i] = proof.a_final * g_coeffs[i];
        coeffs[n + i] = proof.b_final * h_coeffs[i];
    }
    coeffs
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

fn fold_eval(challenges: &[Scalar], zeta: Scalar, n: usize, inverse: bool) -> Scalar {
    let mut acc = Scalar::ONE;
    for (round, &x) in challenges.iter().enumerate() {
        let factor = if inverse { x.invert().unwrap() } else { x };
        let stride = n >> (round + 1);
        acc *= Scalar::ONE + factor * scalar_pow_usize(zeta, stride);
    }
    acc
}

fn kzg_challenge(commitment: G1Projective, proof: &IpProof, domain: u64) -> Scalar {
    let mut owned = Vec::with_capacity(4 + 2 * proof.left.len());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push((proof.n as u64).to_le_bytes().to_vec());
    owned.push(commitment.to_affine().to_compressed().to_vec());
    owned.push(proof.a_final.to_bytes_le().to_vec());
    owned.push(proof.b_final.to_bytes_le().to_vec());
    for (&left, &right) in proof.left.iter().zip(proof.right.iter()) {
        owned.push(left.to_affine().to_compressed().to_vec());
        owned.push(right.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn prove_structured_ip(
    commitment: G1Projective,
    bases: &StructuredBases,
    a: &[Scalar],
    b: &[Scalar],
    domain: u64,
) -> StructuredIpProof {
    let ipa = prove_ip(commitment, &bases.ipa, a, b, domain);
    let (challenges, _current) =
        ipa_challenges(commitment, bases.ipa.u, &ipa, domain).expect("valid proof length");
    let zeta = kzg_challenge(commitment, &ipa, domain ^ 0x5EC7_0001);
    let coeffs = structured_coefficients(&ipa, &challenges);
    let quotient = quotient_coefficients(&coeffs, zeta);
    let kzg_witness = msm(&bases.srs_g1[..quotient.len()], &quotient);
    StructuredIpProof { ipa, kzg_witness }
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

fn verify_structured_ip_fast(
    commitment: G1Projective,
    bases: &StructuredBases,
    proof: &StructuredIpProof,
    domain: u64,
) -> bool {
    if proof.ipa.n != bases.ipa.g.len()
        || proof.ipa.n != bases.ipa.h.len()
        || proof.ipa.left.len() != proof.ipa.n.trailing_zeros() as usize
    {
        return false;
    }
    let (challenges, current) = match ipa_challenges(commitment, bases.ipa.u, &proof.ipa, domain) {
        Some(result) => result,
        None => return false,
    };
    let folded_commitment = current - bases.ipa.u * (proof.ipa.a_final * proof.ipa.b_final);
    let zeta = kzg_challenge(commitment, &proof.ipa, domain ^ 0x5EC7_0001);
    let g_eval = fold_eval(&challenges, zeta, proof.ipa.n, false);
    let h_eval =
        scalar_pow_usize(zeta, proof.ipa.n) * fold_eval(&challenges, zeta, proof.ipa.n, true);
    let value = proof.ipa.a_final * g_eval + proof.ipa.b_final * h_eval;
    verify_kzg(
        folded_commitment,
        value,
        proof.kzg_witness,
        bases.tau_g2,
        zeta,
    )
}

fn self_test() {
    let len = 64;
    let bases = make_bases(len);
    let a = random_scalars(len, 0xA11CE);
    let b = random_scalars(len, 0xB0B);
    let commitment = commit_inner_product(&bases, &a, &b);
    let proof = prove_ip(commitment, &bases, &a, &b, 0xC01D);
    assert!(verify_ip(commitment, &bases, &proof, 0xC01D));
    let mut bad = proof.clone();
    bad.a_final += Scalar::ONE;
    assert!(!verify_ip(commitment, &bases, &bad, 0xC01D));
    let mut rng = 0x5775_0001;
    let tau = scalar_from_rng(&mut rng);
    let structured = make_structured_bases(len, tau);
    let structured_commitment = commit_inner_product(&structured.ipa, &a, &b);
    let structured_proof = prove_structured_ip(structured_commitment, &structured, &a, &b, 0xC01D);
    assert!(verify_structured_ip_fast(
        structured_commitment,
        &structured,
        &structured_proof,
        0xC01D
    ));
    let mut bad_structured = StructuredIpProof {
        ipa: structured_proof.ipa.clone(),
        kzg_witness: structured_proof.kzg_witness,
    };
    bad_structured.ipa.a_final += Scalar::ONE;
    assert!(!verify_structured_ip_fast(
        structured_commitment,
        &structured,
        &bad_structured,
        0xC01D
    ));
    println!("curve-ipa self-test ok");
}

fn bench(len: usize, seed: u64) {
    if !len.is_power_of_two() {
        panic!("len must be a power of two");
    }
    let start = Instant::now();
    let bases = make_bases(len);
    let setup_s = start.elapsed().as_secs_f64();

    let a = random_scalars(len, seed ^ 0xA);
    let b = random_scalars(len, seed ^ 0xB);

    let start = Instant::now();
    let commitment = commit_inner_product(&bases, &a, &b);
    let commit_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let proof = prove_ip(commitment, &bases, &a, &b, 0xC01D);
    let prove_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let verified = verify_ip(commitment, &bases, &proof, 0xC01D);
    let verify_s = start.elapsed().as_secs_f64();

    println!("{len},{setup_s:.9},{commit_s:.9},{prove_s:.9},{verify_s:.9},{verified}");
}

fn bench_structured(len: usize, seed: u64) {
    if !len.is_power_of_two() {
        panic!("len must be a power of two");
    }
    let mut rng = seed ^ 0x5775_0002;
    let tau = scalar_from_rng(&mut rng);

    let start = Instant::now();
    let bases = make_structured_bases(len, tau);
    let setup_s = start.elapsed().as_secs_f64();

    let a = random_scalars(len, seed ^ 0xA);
    let b = random_scalars(len, seed ^ 0xB);

    let start = Instant::now();
    let commitment = commit_inner_product(&bases.ipa, &a, &b);
    let commit_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let proof = prove_structured_ip(commitment, &bases, &a, &b, 0xC01D);
    let prove_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let direct_verified = verify_ip(commitment, &bases.ipa, &proof.ipa, 0xC01D);
    let direct_verify_s = start.elapsed().as_secs_f64();

    let start = Instant::now();
    let fast_verified = verify_structured_ip_fast(commitment, &bases, &proof, 0xC01D);
    let fast_verify_s = start.elapsed().as_secs_f64();

    println!(
        "{len},{setup_s:.9},{commit_s:.9},{prove_s:.9},{direct_verify_s:.9},{fast_verify_s:.9},{direct_verified},{fast_verified}"
    );
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  curve_ipa self-test");
    eprintln!("  curve_ipa bench <power-of-two-len> [len...]");
    eprintln!("  curve_ipa bench-structured <power-of-two-len> [len...]");
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
            println!("len,hash_to_curve_setup_s,commit_s,prove_s,verify_s,verified");
            for len_arg in &args[2..] {
                let len: usize = len_arg.parse().unwrap();
                bench(len, 0xC0DE_0000 + len as u64);
            }
        }
        "bench-structured" => {
            if args.len() < 3 {
                usage();
                std::process::exit(1);
            }
            println!(
                "len,structured_setup_s,commit_s,prove_with_kzg_open_s,direct_verify_s,fast_verify_s,direct_verified,fast_verified"
            );
            for len_arg in &args[2..] {
                let len: usize = len_arg.parse().unwrap();
                bench_structured(len, 0xC0DE_0000 + len as u64);
            }
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
