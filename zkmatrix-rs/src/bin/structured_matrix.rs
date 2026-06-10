use blstrs::{Bls12, G1Projective, G2Prepared, G2Projective, Gt, Scalar};
use ff::{Field, PrimeField};
use group::{Curve, Group};
use pairing::{MillerLoopResult, MultiMillerLoop};
use sha2::{Digest, Sha256};
use std::env;
use std::time::Instant;

const DST: &[u8] = b"BLS12381G1_XMD:SHA-256_SSWU_RO_ZKMATRIX_MATRIX";

#[derive(Clone, Copy)]
struct Term {
    offset: usize,
    coeff: Scalar,
}

type BasisSpec = Vec<Term>;

#[derive(Clone)]
struct Layout {
    n: usize,
    nn: usize,
    off_a: usize,
    off_b: usize,
    off_c: usize,
    off_ay: usize,
    off_by: usize,
    srs_len: usize,
}

struct StructuredSrs {
    powers: Vec<G1Projective>,
    tau_g2: G2Projective,
    u: G1Projective,
}

#[derive(Clone)]
struct IpProof {
    n: usize,
    left: Vec<G1Projective>,
    right: Vec<G1Projective>,
    a_final: Scalar,
    b_final: Scalar,
    kzg_witness: G1Projective,
}

struct Statement {
    a_commit: G1Projective,
    b_commit: G1Projective,
    c_commit: G1Projective,
}

struct Witness {
    a: Vec<Scalar>,
    b: Vec<Scalar>,
    c: Vec<Scalar>,
}

struct MatrixProof {
    d: Scalar,
    ay_commit: G1Projective,
    by_commit: G1Projective,
    c_proj: IpProof,
    a_proj: IpProof,
    b_proj: IpProof,
    product: IpProof,
}

struct BatchProof {
    y: Scalar,
    rho: Scalar,
    d: Scalar,
    c_lhs: G1Projective,
    a_lhs: G1Projective,
    b_lhs: G1Projective,
    product_lhs: G1Projective,
    c_proj: IpProof,
    a_proj: IpProof,
    b_proj: IpProof,
    product: IpProof,
}

#[derive(Clone, Copy)]
enum FormulaKind {
    CProjection,
    AProjection {
        y: Scalar,
    },
    BProjection {
        y: Scalar,
    },
    Product,
    BatchCProjection {
        rho: Scalar,
        batch: usize,
    },
    BatchAProjection {
        y: Scalar,
        rho: Scalar,
        batch: usize,
    },
    BatchBProjection {
        y: Scalar,
        rho: Scalar,
        batch: usize,
    },
    BatchProduct {
        rho: Scalar,
        batch: usize,
    },
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

fn hash_to_scalar(chunks: &[&[u8]]) -> Scalar {
    for counter in 0u64.. {
        let mut hasher = Sha256::new();
        hasher.update(b"zkmatrix-structured-matrix-scalar");
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

fn layout(n: usize) -> Layout {
    assert!(n.is_power_of_two());
    let nn = n * n;
    let off_a = 0;
    let off_b = off_a + nn;
    let off_c = off_b + nn;
    let off_ay = off_c + nn;
    let off_by = off_ay + n;
    let srs_len = off_by + n;
    Layout {
        n,
        nn,
        off_a,
        off_b,
        off_c,
        off_ay,
        off_by,
        srs_len,
    }
}

fn make_srs(layout: &Layout, tau: Scalar) -> StructuredSrs {
    let generator = G1Projective::generator();
    let mut powers = Vec::with_capacity(layout.srs_len);
    let mut cur = Scalar::ONE;
    for _ in 0..layout.srs_len {
        powers.push(generator * cur);
        cur *= tau;
    }
    StructuredSrs {
        powers,
        tau_g2: G2Projective::generator() * tau,
        u: hash_to_basis(b"matrix-u", 0),
    }
}

fn a_spec(layout: &Layout, idx: usize) -> BasisSpec {
    vec![Term {
        offset: layout.off_a + idx,
        coeff: Scalar::ONE,
    }]
}

fn b_spec(layout: &Layout, idx: usize) -> BasisSpec {
    vec![Term {
        offset: layout.off_b + idx,
        coeff: Scalar::ONE,
    }]
}

fn c_spec(layout: &Layout, idx: usize) -> BasisSpec {
    vec![Term {
        offset: layout.off_c + idx,
        coeff: Scalar::ONE,
    }]
}

fn ay_spec(layout: &Layout, j: usize) -> BasisSpec {
    vec![Term {
        offset: layout.off_ay + j,
        coeff: Scalar::ONE,
    }]
}

fn by_spec(layout: &Layout, i: usize) -> BasisSpec {
    vec![Term {
        offset: layout.off_by + i,
        coeff: Scalar::ONE,
    }]
}

fn a_projection_spec(layout: &Layout, idx: usize, yl: &[Scalar], scale: Scalar) -> BasisSpec {
    let i = idx / layout.n;
    let j = idx % layout.n;
    vec![
        Term {
            offset: layout.off_a + idx,
            coeff: scale,
        },
        Term {
            offset: layout.off_ay + j,
            coeff: scale * yl[i],
        },
    ]
}

fn b_projection_spec(layout: &Layout, idx: usize, yr: &[Scalar], scale: Scalar) -> BasisSpec {
    let i = idx / layout.n;
    let j = idx % layout.n;
    vec![
        Term {
            offset: layout.off_b + idx,
            coeff: scale,
        },
        Term {
            offset: layout.off_by + i,
            coeff: scale * yr[j],
        },
    ]
}

fn basis_point(srs: &StructuredSrs, spec: &[Term]) -> G1Projective {
    let mut out = G1Projective::identity();
    for term in spec {
        out += srs.powers[term.offset] * term.coeff;
    }
    out
}

fn materialize(srs: &StructuredSrs, specs: &[BasisSpec]) -> Vec<G1Projective> {
    specs.iter().map(|spec| basis_point(srs, spec)).collect()
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

fn dot(a: &[Scalar], b: &[Scalar]) -> Scalar {
    let mut acc = Scalar::ZERO;
    for (&x, &y) in a.iter().zip(b.iter()) {
        acc += x * y;
    }
    acc
}

fn commit_specs(srs: &StructuredSrs, specs: &[BasisSpec], values: &[Scalar]) -> G1Projective {
    msm(&materialize(srs, specs), values)
}

fn powers(base: Scalar, len: usize) -> Vec<Scalar> {
    let mut out = vec![Scalar::ZERO; len];
    let mut cur = Scalar::ONE;
    for x in &mut out {
        *x = cur;
        cur *= base;
    }
    out
}

fn matmul(a: &[Scalar], b: &[Scalar], n: usize) -> Vec<Scalar> {
    let mut c = vec![Scalar::ZERO; n * n];
    for i in 0..n {
        for k in 0..n {
            let aik = a[i * n + k];
            for j in 0..n {
                c[i * n + j] += aik * b[k * n + j];
            }
        }
    }
    c
}

fn random_matrix(n: usize, rng: &mut u64) -> Vec<Scalar> {
    (0..n * n)
        .map(|_| Scalar::from(splitmix64(rng) % 64))
        .collect()
}

fn make_witness(n: usize, seed: u64) -> Witness {
    let mut rng = seed;
    let a = random_matrix(n, &mut rng);
    let b = random_matrix(n, &mut rng);
    let c = matmul(&a, &b, n);
    Witness { a, b, c }
}

fn statement(layout: &Layout, srs: &StructuredSrs, witness: &Witness) -> Statement {
    let a_specs: Vec<_> = (0..layout.nn).map(|idx| a_spec(layout, idx)).collect();
    let b_specs: Vec<_> = (0..layout.nn).map(|idx| b_spec(layout, idx)).collect();
    let c_specs: Vec<_> = (0..layout.nn).map(|idx| c_spec(layout, idx)).collect();
    Statement {
        a_commit: commit_specs(srs, &a_specs, &witness.a),
        b_commit: commit_specs(srs, &b_specs, &witness.b),
        c_commit: commit_specs(srs, &c_specs, &witness.c),
    }
}

fn challenge_statement(n: usize, statement: &Statement) -> Scalar {
    let n_bytes = (n as u64).to_le_bytes();
    let a = statement.a_commit.to_affine().to_compressed();
    let b = statement.b_commit.to_affine().to_compressed();
    let c = statement.c_commit.to_affine().to_compressed();
    hash_to_scalar(&[&n_bytes, &a, &b, &c])
}

fn challenge_ip(
    domain: u64,
    round: usize,
    current: G1Projective,
    scalar_base: G1Projective,
    left: G1Projective,
    right: G1Projective,
) -> Scalar {
    let domain_bytes = domain.to_le_bytes();
    let round_bytes = (round as u64).to_le_bytes();
    let current_bytes = current.to_affine().to_compressed();
    let scalar_bytes = scalar_base.to_affine().to_compressed();
    let left_bytes = left.to_affine().to_compressed();
    let right_bytes = right.to_affine().to_compressed();
    hash_to_scalar(&[
        &domain_bytes,
        &round_bytes,
        &current_bytes,
        &scalar_bytes,
        &left_bytes,
        &right_bytes,
    ])
}

fn ipa_challenges(
    commitment: G1Projective,
    scalar_base: G1Projective,
    proof: &IpProof,
    domain: u64,
) -> (Vec<Scalar>, G1Projective) {
    let mut current = commitment;
    let mut challenges = Vec::with_capacity(proof.left.len());
    for round in 0..proof.left.len() {
        let left = proof.left[round];
        let right = proof.right[round];
        let x = challenge_ip(domain, round, current, scalar_base, left, right);
        let xi = x.invert().unwrap();
        current = left * x + current + right * xi;
        challenges.push(x);
    }
    (challenges, current)
}

fn fold_coefficients(challenges: &[Scalar], len: usize, inverse: bool) -> Vec<Scalar> {
    let mut coeffs = vec![Scalar::ONE; len];
    for (round, &x) in challenges.iter().enumerate() {
        let factor = if inverse { x.invert().unwrap() } else { x };
        let stride = len >> (round + 1);
        for (i, coeff) in coeffs.iter_mut().enumerate() {
            if (i & stride) != 0 {
                *coeff *= factor;
            }
        }
    }
    coeffs
}

fn add_terms_to_poly(poly: &mut [Scalar], specs: &[BasisSpec], coeffs: &[Scalar], scale: Scalar) {
    for (spec, &fold_coeff) in specs.iter().zip(coeffs.iter()) {
        for term in spec {
            poly[term.offset] += scale * fold_coeff * term.coeff;
        }
    }
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

fn fold_eval(challenges: &[Scalar], zeta: Scalar, len: usize, inverse: bool) -> Scalar {
    let mut acc = Scalar::ONE;
    for (round, &x) in challenges.iter().enumerate() {
        let factor = if inverse { x.invert().unwrap() } else { x };
        let stride = len >> (round + 1);
        acc *= Scalar::ONE + factor * scalar_pow_usize(zeta, stride);
    }
    acc
}

fn split_matrix_eval(
    challenges: &[Scalar],
    n: usize,
    row_base: Scalar,
    col_base: Scalar,
    inverse: bool,
) -> Scalar {
    let bits = n.trailing_zeros() as usize;
    let mut acc = Scalar::ONE;
    for r in 0..bits {
        let x = if inverse {
            challenges[r].invert().unwrap()
        } else {
            challenges[r]
        };
        let stride = 1usize << (bits - 1 - r);
        acc *= Scalar::ONE + x * scalar_pow_usize(row_base, stride);
    }
    for r in 0..bits {
        let idx = bits + r;
        let x = if inverse {
            challenges[idx].invert().unwrap()
        } else {
            challenges[idx]
        };
        let stride = 1usize << (bits - 1 - r);
        acc *= Scalar::ONE + x * scalar_pow_usize(col_base, stride);
    }
    acc
}

fn batch_eval(challenges: &[Scalar], batch: usize, rho: Scalar, inverse: bool) -> Scalar {
    let bits = batch.trailing_zeros() as usize;
    let mut acc = Scalar::ONE;
    for r in 0..bits {
        let x = if inverse {
            challenges[r].invert().unwrap()
        } else {
            challenges[r]
        };
        let stride = 1usize << (bits - 1 - r);
        acc *= Scalar::ONE + x * scalar_pow_usize(rho, stride);
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

fn formula_value(
    layout: &Layout,
    kind: FormulaKind,
    proof: &IpProof,
    challenges: &[Scalar],
    zeta: Scalar,
) -> Scalar {
    let n = layout.n;
    let nn = layout.nn;
    match kind {
        FormulaKind::CProjection => {
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_c)
                * fold_eval(challenges, zeta, nn, false)
        }
        FormulaKind::AProjection { y } => {
            let base =
                scalar_pow_usize(zeta, layout.off_a) * fold_eval(challenges, zeta, nn, false);
            let projected = scalar_pow_usize(zeta, layout.off_ay)
                * split_matrix_eval(challenges, n, scalar_pow_usize(y, n), zeta, false);
            proof.a_final * (base + projected)
        }
        FormulaKind::BProjection { y } => {
            let base =
                scalar_pow_usize(zeta, layout.off_b) * fold_eval(challenges, zeta, nn, false);
            let projected = scalar_pow_usize(zeta, layout.off_by)
                * split_matrix_eval(challenges, n, zeta, y, false);
            proof.a_final * (base + projected)
        }
        FormulaKind::Product => {
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_ay)
                * fold_eval(challenges, zeta, n, false)
                + proof.b_final
                    * scalar_pow_usize(zeta, layout.off_by)
                    * fold_eval(challenges, zeta, n, true)
        }
        FormulaKind::BatchCProjection { rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_c)
                * batch_eval(&challenges[..batch_bits], batch, rho, false)
                * fold_eval(&challenges[batch_bits..], zeta, nn, false)
        }
        FormulaKind::BatchAProjection { y, rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let batch_part = batch_eval(&challenges[..batch_bits], batch, rho, false);
            let matrix_challenges = &challenges[batch_bits..];
            let base = scalar_pow_usize(zeta, layout.off_a)
                * fold_eval(matrix_challenges, zeta, nn, false);
            let projected = scalar_pow_usize(zeta, layout.off_ay)
                * split_matrix_eval(matrix_challenges, n, scalar_pow_usize(y, n), zeta, false);
            proof.a_final * batch_part * (base + projected)
        }
        FormulaKind::BatchBProjection { y, rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let batch_part = batch_eval(&challenges[..batch_bits], batch, rho, false);
            let matrix_challenges = &challenges[batch_bits..];
            let base = scalar_pow_usize(zeta, layout.off_b)
                * fold_eval(matrix_challenges, zeta, nn, false);
            let projected = scalar_pow_usize(zeta, layout.off_by)
                * split_matrix_eval(matrix_challenges, n, zeta, y, false);
            proof.a_final * batch_part * (base + projected)
        }
        FormulaKind::BatchProduct { rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let vector_challenges = &challenges[batch_bits..];
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_ay)
                * batch_eval(&challenges[..batch_bits], batch, rho, false)
                * fold_eval(vector_challenges, zeta, n, false)
                + proof.b_final
                    * scalar_pow_usize(zeta, layout.off_by)
                    * batch_eval(&challenges[..batch_bits], batch, Scalar::ONE, true)
                    * fold_eval(vector_challenges, zeta, n, true)
        }
    }
}

fn prove_ip_structured(
    srs: &StructuredSrs,
    layout: &Layout,
    commitment: G1Projective,
    scalar_base: G1Projective,
    g_specs: &[BasisSpec],
    h_specs: Option<&[BasisSpec]>,
    a_in: &[Scalar],
    b_in: Option<&[Scalar]>,
    domain: u64,
) -> IpProof {
    let proof_n = a_in.len();
    assert!(proof_n.is_power_of_two());
    let rounds = proof_n.trailing_zeros() as usize;
    let mut a = a_in.to_vec();
    let mut b = vec![Scalar::ZERO; proof_n];
    if let Some(values) = b_in {
        b.copy_from_slice(values);
    }
    let mut g = materialize(srs, g_specs);
    let mut h = match h_specs {
        Some(specs) => materialize(srs, specs),
        None => vec![G1Projective::identity(); proof_n],
    };
    let mut current = commitment;
    let mut left_messages = Vec::with_capacity(rounds);
    let mut right_messages = Vec::with_capacity(rounds);
    let mut len = proof_n;
    for round in 0..rounds {
        let half = len / 2;
        let left_cross = dot(&a[..half], &b[half..len]);
        let right_cross = dot(&a[half..len], &b[..half]);
        let left = msm(&g[half..len], &a[..half])
            + msm(&h[..half], &b[half..len])
            + scalar_base * left_cross;
        let right = msm(&g[..half], &a[half..len])
            + msm(&h[half..len], &b[..half])
            + scalar_base * right_cross;
        let x = challenge_ip(domain, round, current, scalar_base, left, right);
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
    let mut proof = IpProof {
        n: proof_n,
        left: left_messages,
        right: right_messages,
        a_final: a[0],
        b_final: b[0],
        kzg_witness: G1Projective::identity(),
    };
    let (challenges, _) = ipa_challenges(commitment, scalar_base, &proof, domain);
    let mut poly = vec![Scalar::ZERO; layout.srs_len];
    let g_fold = fold_coefficients(&challenges, proof_n, false);
    add_terms_to_poly(&mut poly, g_specs, &g_fold, proof.a_final);
    if let Some(specs) = h_specs {
        let h_fold = fold_coefficients(&challenges, proof_n, true);
        add_terms_to_poly(&mut poly, specs, &h_fold, proof.b_final);
    }
    let zeta = kzg_challenge(commitment, &proof, domain ^ 0x5EC7_0001);
    let quotient = quotient_coefficients(&poly, zeta);
    proof.kzg_witness = msm(&srs.powers[..quotient.len()], &quotient);
    proof
}

fn verify_ip_fast(
    srs: &StructuredSrs,
    layout: &Layout,
    commitment: G1Projective,
    scalar_base: G1Projective,
    proof: &IpProof,
    domain: u64,
    formula: FormulaKind,
) -> bool {
    if proof.left.len() != proof.n.trailing_zeros() as usize {
        return false;
    }
    let (challenges, current) = ipa_challenges(commitment, scalar_base, proof, domain);
    let folded_commitment = current - scalar_base * (proof.a_final * proof.b_final);
    let zeta = kzg_challenge(commitment, proof, domain ^ 0x5EC7_0001);
    let value = formula_value(layout, formula, proof, &challenges, zeta);
    verify_kzg(
        folded_commitment,
        value,
        proof.kzg_witness,
        srs.tau_g2,
        zeta,
    )
}

fn projections(
    layout: &Layout,
    statement: &Statement,
    witness: &Witness,
) -> (
    Scalar,
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Scalar,
) {
    let y = challenge_statement(layout.n, statement);
    let (yvec, yl, yr, ay, by, d) = projections_with_y(layout, witness, y);
    (y, yvec, yl, yr, ay, by, d)
}

fn projections_with_y(
    layout: &Layout,
    witness: &Witness,
    y: Scalar,
) -> (
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Vec<Scalar>,
    Scalar,
) {
    let yvec = powers(y, layout.nn);
    let yr = powers(y, layout.n);
    let yl: Vec<_> = (0..layout.n).map(|i| yvec[i * layout.n]).collect();
    let mut ay = vec![Scalar::ZERO; layout.n];
    for j in 0..layout.n {
        for i in 0..layout.n {
            ay[j] += yl[i] * witness.a[i * layout.n + j];
        }
    }
    let mut by = vec![Scalar::ZERO; layout.n];
    for i in 0..layout.n {
        for j in 0..layout.n {
            by[i] += witness.b[i * layout.n + j] * yr[j];
        }
    }
    let d = dot(&witness.c, &yvec);
    (yvec, yl, yr, ay, by, d)
}

fn prove_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    witness: &Witness,
) -> MatrixProof {
    let (_y, yvec, yl, yr, ay, by, d) = projections(layout, statement, witness);
    let ay_specs: Vec<_> = (0..layout.n).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.n).map(|i| by_spec(layout, i)).collect();
    let ay_commit = commit_specs(srs, &ay_specs, &ay);
    let by_commit = commit_specs(srs, &by_specs, &by);
    let c_specs: Vec<_> = (0..layout.nn).map(|idx| c_spec(layout, idx)).collect();
    let a_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| a_projection_spec(layout, idx, &yl, Scalar::ONE))
        .collect();
    let b_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| b_projection_spec(layout, idx, &yr, Scalar::ONE))
        .collect();
    let c_proj = prove_ip_structured(
        srs,
        layout,
        statement.c_commit + srs.u * d,
        srs.u,
        &c_specs,
        None,
        &witness.c,
        Some(&yvec),
        0xC001,
    );
    let a_proj = prove_ip_structured(
        srs,
        layout,
        statement.a_commit + ay_commit,
        G1Projective::identity(),
        &a_proj_specs,
        None,
        &witness.a,
        None,
        0xA002,
    );
    let b_proj = prove_ip_structured(
        srs,
        layout,
        statement.b_commit + by_commit,
        G1Projective::identity(),
        &b_proj_specs,
        None,
        &witness.b,
        None,
        0xB003,
    );
    let product = prove_ip_structured(
        srs,
        layout,
        srs.u * d + ay_commit + by_commit,
        srs.u,
        &ay_specs,
        Some(&by_specs),
        &ay,
        Some(&by),
        0xD004,
    );
    MatrixProof {
        d,
        ay_commit,
        by_commit,
        c_proj,
        a_proj,
        b_proj,
        product,
    }
}

fn verify_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    proof: &MatrixProof,
) -> bool {
    let y = challenge_statement(layout.n, statement);
    verify_ip_fast(
        srs,
        layout,
        statement.c_commit + srs.u * proof.d,
        srs.u,
        &proof.c_proj,
        0xC001,
        FormulaKind::CProjection,
    ) && verify_ip_fast(
        srs,
        layout,
        statement.a_commit + proof.ay_commit,
        G1Projective::identity(),
        &proof.a_proj,
        0xA002,
        FormulaKind::AProjection { y },
    ) && verify_ip_fast(
        srs,
        layout,
        statement.b_commit + proof.by_commit,
        G1Projective::identity(),
        &proof.b_proj,
        0xB003,
        FormulaKind::BProjection { y },
    ) && verify_ip_fast(
        srs,
        layout,
        srs.u * proof.d + proof.ay_commit + proof.by_commit,
        srs.u,
        &proof.product,
        0xD004,
        FormulaKind::Product,
    )
}

fn self_test() {
    for n in [2usize, 4, 8] {
        let layout = layout(n);
        let mut rng = 0x5775_1000 + n as u64;
        let tau = scalar_from_rng(&mut rng);
        let srs = make_srs(&layout, tau);
        let witness = make_witness(n, 0xA11CE + n as u64);
        let statement = statement(&layout, &srs, &witness);
        let proof = prove_matrix(&layout, &srs, &statement, &witness);
        assert!(verify_matrix(&layout, &srs, &statement, &proof));
    }
    println!("structured-matrix self-test ok");
}

fn bench(n: usize) {
    let layout = layout(n);
    let mut rng = 0x5775_2000 + n as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(&layout, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let witness = make_witness(n, 0xBEEF + n as u64);
    let start = Instant::now();
    let statement = statement(&layout, &srs, &witness);
    let commit_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let proof = prove_matrix(&layout, &srs, &statement, &witness);
    let prove_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let verified = verify_matrix(&layout, &srs, &statement, &proof);
    let verify_s = start.elapsed().as_secs_f64();
    println!("{n},{setup_s:.9},{commit_s:.9},{prove_s:.9},{verify_s:.9},{verified}");
}

fn batch_challenges(statements: &[Statement], n: usize) -> (Scalar, Scalar) {
    let n_bytes = (n as u64).to_le_bytes();
    let mut owned = vec![
        n_bytes.to_vec(),
        (statements.len() as u64).to_le_bytes().to_vec(),
    ];
    for statement in statements {
        owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    }
    let mut y_owned = vec![b"batch-y".to_vec()];
    y_owned.extend(owned.clone());
    let y_refs: Vec<&[u8]> = y_owned.iter().map(Vec::as_slice).collect();
    let mut rho_owned = vec![b"batch-rho".to_vec()];
    rho_owned.extend(owned);
    let rho_refs: Vec<&[u8]> = rho_owned.iter().map(Vec::as_slice).collect();
    (hash_to_scalar(&y_refs), hash_to_scalar(&rho_refs))
}

fn prove_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    witnesses: &[Witness],
) -> BatchProof {
    assert_eq!(statements.len(), witnesses.len());
    assert!(statements.len().is_power_of_two());
    let batch = statements.len();
    let (y, rho) = batch_challenges(statements, layout.n);
    let rho_powers = powers(rho, batch);
    let (yvec_template, yl, yr, _, _, _) = projections_with_y(layout, &witnesses[0], y);
    let mut d_weighted = Scalar::ZERO;
    let mut ay_commit_weighted = G1Projective::identity();
    let mut by_commit_weighted = G1Projective::identity();
    let mut c_lhs = G1Projective::identity();
    let mut a_lhs = G1Projective::identity();
    let mut b_lhs = G1Projective::identity();
    let mut c_values = Vec::with_capacity(batch * layout.nn);
    let mut c_public = Vec::with_capacity(batch * layout.nn);
    let mut c_specs = Vec::with_capacity(batch * layout.nn);
    let mut a_values = Vec::with_capacity(batch * layout.nn);
    let mut a_specs = Vec::with_capacity(batch * layout.nn);
    let mut b_values = Vec::with_capacity(batch * layout.nn);
    let mut b_specs = Vec::with_capacity(batch * layout.nn);
    let mut product_a = Vec::with_capacity(batch * layout.n);
    let mut product_b = Vec::with_capacity(batch * layout.n);
    let mut product_g_specs = Vec::with_capacity(batch * layout.n);
    let mut product_h_specs = Vec::with_capacity(batch * layout.n);

    for (batch_idx, ((statement, witness), &rho_i)) in statements
        .iter()
        .zip(witnesses.iter())
        .zip(rho_powers.iter())
        .enumerate()
    {
        let (yvec, _, _, ay, by, d) = projections_with_y(layout, witness, y);
        debug_assert_eq!(yvec, yvec_template);
        let ay_specs: Vec<_> = (0..layout.n).map(|j| ay_spec(layout, j)).collect();
        let by_specs: Vec<_> = (0..layout.n).map(|i| by_spec(layout, i)).collect();
        let ay_commit = commit_specs(srs, &ay_specs, &ay);
        let by_commit = commit_specs(srs, &by_specs, &by);
        d_weighted += rho_i * d;
        ay_commit_weighted += ay_commit * rho_i;
        by_commit_weighted += by_commit * rho_i;
        c_lhs += statement.c_commit * rho_i;
        a_lhs += (statement.a_commit + ay_commit) * rho_i;
        b_lhs += (statement.b_commit + by_commit) * rho_i;

        for idx in 0..layout.nn {
            c_values.push(witness.c[idx]);
            c_public.push(rho_i * yvec[idx]);
            c_specs.push(vec![Term {
                offset: layout.off_c + idx,
                coeff: rho_i,
            }]);
            a_values.push(witness.a[idx]);
            a_specs.push(a_projection_spec(layout, idx, &yl, rho_i));
            b_values.push(witness.b[idx]);
            b_specs.push(b_projection_spec(layout, idx, &yr, rho_i));
        }
        for j in 0..layout.n {
            product_a.push(ay[j]);
            product_b.push(rho_i * by[j]);
            product_g_specs.push(vec![Term {
                offset: layout.off_ay + j,
                coeff: rho_i,
            }]);
            product_h_specs.push(by_spec(layout, j));
        }
        let _ = batch_idx;
    }
    c_lhs += srs.u * d_weighted;
    let product_lhs = srs.u * d_weighted + ay_commit_weighted + by_commit_weighted;
    let c_proj = prove_ip_structured(
        srs,
        layout,
        c_lhs,
        srs.u,
        &c_specs,
        None,
        &c_values,
        Some(&c_public),
        0xC101,
    );
    let a_proj = prove_ip_structured(
        srs,
        layout,
        a_lhs,
        G1Projective::identity(),
        &a_specs,
        None,
        &a_values,
        None,
        0xA102,
    );
    let b_proj = prove_ip_structured(
        srs,
        layout,
        b_lhs,
        G1Projective::identity(),
        &b_specs,
        None,
        &b_values,
        None,
        0xB103,
    );
    let product = prove_ip_structured(
        srs,
        layout,
        product_lhs,
        srs.u,
        &product_g_specs,
        Some(&product_h_specs),
        &product_a,
        Some(&product_b),
        0xD104,
    );
    BatchProof {
        y,
        rho,
        d: d_weighted,
        c_lhs,
        a_lhs,
        b_lhs,
        product_lhs,
        c_proj,
        a_proj,
        b_proj,
        product,
    }
}

fn verify_batch(layout: &Layout, srs: &StructuredSrs, proof: &BatchProof, batch: usize) -> bool {
    verify_ip_fast(
        srs,
        layout,
        proof.c_lhs,
        srs.u,
        &proof.c_proj,
        0xC101,
        FormulaKind::BatchCProjection {
            rho: proof.rho,
            batch,
        },
    ) && verify_ip_fast(
        srs,
        layout,
        proof.a_lhs,
        G1Projective::identity(),
        &proof.a_proj,
        0xA102,
        FormulaKind::BatchAProjection {
            y: proof.y,
            rho: proof.rho,
            batch,
        },
    ) && verify_ip_fast(
        srs,
        layout,
        proof.b_lhs,
        G1Projective::identity(),
        &proof.b_proj,
        0xB103,
        FormulaKind::BatchBProjection {
            y: proof.y,
            rho: proof.rho,
            batch,
        },
    ) && verify_ip_fast(
        srs,
        layout,
        proof.product_lhs,
        srs.u,
        &proof.product,
        0xD104,
        FormulaKind::BatchProduct {
            rho: proof.rho,
            batch,
        },
    )
}

fn bench_batch(n: usize, batch: usize) {
    assert!(batch.is_power_of_two());
    let layout = layout(n);
    let mut rng = 0x5775_3000 + n as u64 + batch as u64;
    let tau = scalar_from_rng(&mut rng);
    let srs = make_srs(&layout, tau);
    let witnesses: Vec<_> = (0..batch)
        .map(|i| make_witness(n, 0xCAFE + n as u64 + 17 * i as u64))
        .collect();
    let statements: Vec<_> = witnesses
        .iter()
        .map(|w| statement(&layout, &srs, w))
        .collect();
    let start = Instant::now();
    let proof = prove_batch(&layout, &srs, &statements, &witnesses);
    let batch_prove_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let verified = verify_batch(&layout, &srs, &proof, batch);
    let batch_verify_s = start.elapsed().as_secs_f64();
    println!(
        "{n},{batch},{batch_prove_s:.9},{:.9},{batch_verify_s:.9},{:.9},{:?},{verified}",
        batch_prove_s / batch as f64,
        batch_verify_s / batch as f64,
        proof.d
    );
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  structured_matrix self-test");
    eprintln!("  structured_matrix bench <n> [n...]");
    eprintln!("  structured_matrix bench-batch <n> <batch_power_of_two>");
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
            println!("n,setup_s,commit_s,prove_s,verify_s,verified");
            for n_arg in &args[2..] {
                let n: usize = n_arg.parse().unwrap();
                bench(n);
            }
        }
        "bench-batch" => {
            if args.len() != 4 {
                usage();
                std::process::exit(1);
            }
            let n: usize = args[2].parse().unwrap();
            let batch: usize = args[3].parse().unwrap();
            println!("n,batch,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s,weighted_d,verified");
            bench_batch(n, batch);
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
