use blstrs::{Bls12, G1Projective, G2Prepared, G2Projective, Gt, Scalar};
use ff::{Field, PrimeField};
use group::{Curve, Group};
use pairing::{MillerLoopResult, MultiMillerLoop};
use rayon::prelude::*;
use sha2::{Digest, Sha256};
use std::env;
use std::fs::File;
use std::io::Read;
use std::time::Instant;

const DST: &[u8] = b"BLS12381G1_XMD:SHA-256_SSWU_RO_ZKMATRIX_MATRIX";

struct ProofRng {
    entropy: File,
}

impl ProofRng {
    fn new() -> Self {
        Self {
            entropy: File::open("/dev/urandom").expect("open /dev/urandom"),
        }
    }

    fn fill(&mut self, bytes: &mut [u8]) {
        self.entropy.read_exact(bytes).expect("read /dev/urandom");
    }
}

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
    blind: G1Projective,
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
    a_blind: Scalar,
    b_blind: Scalar,
    c_blind: Scalar,
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

struct ZkProjectionProof {
    mask_commit: G1Projective,
    projected_mask_commit: G1Projective,
    response_blind: Scalar,
    projected_response_blind: Scalar,
    proof: IpProof,
}

struct ZkProductProof {
    alpha_commit: G1Projective,
    beta_commit: G1Projective,
    cross_commit: G1Projective,
    alpha_beta_commit: G1Projective,
    left_response_blind: Scalar,
    right_response_blind: Scalar,
    output_response_blind: Scalar,
    proof: IpProof,
}

struct ZkMatrixProof {
    d_commit: G1Projective,
    ay_commit: G1Projective,
    by_commit: G1Projective,
    c_proj: ZkProjectionProof,
    a_proj: ZkProjectionProof,
    b_proj: ZkProjectionProof,
    product: ZkProductProof,
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

struct ZkBatchProof {
    y: Scalar,
    rho: Scalar,
    d_commits: Vec<G1Projective>,
    ay_commits: Vec<G1Projective>,
    by_commits: Vec<G1Projective>,
    c_proj: ZkProjectionProof,
    a_proj: ZkProjectionProof,
    b_proj: ZkProjectionProof,
    products: Vec<ZkProductProof>,
}

#[derive(Clone, Copy)]
enum FormulaKind {
    CProjection {
        y: Scalar,
    },
    AProjection {
        y: Scalar,
    },
    BProjection {
        y: Scalar,
    },
    Product,
    BatchCProjection {
        y: Scalar,
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

// Deterministic benchmark/setup helper. Do not use for ZK blinding or masks.
fn scalar_from_rng(rng: &mut u64) -> Scalar {
    let scalar = Scalar::from(splitmix64(rng));
    if bool::from(scalar.is_zero()) {
        Scalar::ONE
    } else {
        scalar
    }
}

fn proof_rng() -> ProofRng {
    ProofRng::new()
}

fn scalar_from_proof_rng(rng: &mut ProofRng) -> Scalar {
    loop {
        let mut repr = [0u8; 32];
        rng.fill(&mut repr);
        if let Some(scalar) = Scalar::from_repr_vartime(repr) {
            return scalar;
        }
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
        blind: hash_to_basis(b"matrix-blind", 0),
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
    if specs.len() < 512 {
        specs.iter().map(|spec| basis_point(srs, spec)).collect()
    } else {
        specs
            .par_iter()
            .map(|spec| basis_point(srs, spec))
            .collect()
    }
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
    assert_eq!(a.len(), b.len());
    if a.len() < 4096 {
        let mut acc = Scalar::ZERO;
        for (&x, &y) in a.iter().zip(b.iter()) {
            acc += x * y;
        }
        acc
    } else {
        a.par_iter()
            .zip(b.par_iter())
            .map(|(&x, &y)| x * y)
            .reduce(|| Scalar::ZERO, |x, y| x + y)
    }
}

fn commit_specs(srs: &StructuredSrs, specs: &[BasisSpec], values: &[Scalar]) -> G1Projective {
    if let Some(offset) = contiguous_unit_window(specs) {
        msm(&srs.powers[offset..offset + values.len()], values)
    } else {
        msm(&materialize(srs, specs), values)
    }
}

fn commit_specs_blinded(
    srs: &StructuredSrs,
    specs: &[BasisSpec],
    values: &[Scalar],
    blind: Scalar,
) -> G1Projective {
    commit_specs(srs, specs, values) + srs.blind * blind
}

fn commit_window(
    srs: &StructuredSrs,
    offset: usize,
    values: &[Scalar],
    blind: Scalar,
) -> G1Projective {
    msm(&srs.powers[offset..offset + values.len()], values) + srs.blind * blind
}

fn contiguous_unit_window(specs: &[BasisSpec]) -> Option<usize> {
    let first = specs.first()?.first()?;
    if specs[0].len() != 1 || first.coeff != Scalar::ONE {
        return None;
    }
    let start = first.offset;
    for (idx, spec) in specs.iter().enumerate() {
        if spec.len() != 1 {
            return None;
        }
        let term = spec[0];
        if term.coeff != Scalar::ONE || term.offset != start + idx {
            return None;
        }
    }
    Some(start)
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
    c.par_chunks_mut(n).enumerate().for_each(|(i, row)| {
        for k in 0..n {
            let aik = a[i * n + k];
            for j in 0..n {
                row[j] += aik * b[k * n + j];
            }
        }
    });
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
    Witness {
        a,
        b,
        c,
        a_blind: Scalar::ZERO,
        b_blind: Scalar::ZERO,
        c_blind: Scalar::ZERO,
    }
}

fn statement(layout: &Layout, srs: &StructuredSrs, witness: &Witness) -> Statement {
    Statement {
        a_commit: commit_window(srs, layout.off_a, &witness.a, witness.a_blind),
        b_commit: commit_window(srs, layout.off_b, &witness.b, witness.b_blind),
        c_commit: commit_window(srs, layout.off_c, &witness.c, witness.c_blind),
    }
}

fn zk_statement(
    layout: &Layout,
    srs: &StructuredSrs,
    witness: &mut Witness,
    rng: &mut ProofRng,
) -> Statement {
    witness.a_blind = scalar_from_proof_rng(rng);
    witness.b_blind = scalar_from_proof_rng(rng);
    witness.c_blind = scalar_from_proof_rng(rng);
    statement(layout, srs, witness)
}

fn challenge_statement(n: usize, statement: &Statement) -> Scalar {
    let n_bytes = (n as u64).to_le_bytes();
    let a = statement.a_commit.to_affine().to_compressed();
    let b = statement.b_commit.to_affine().to_compressed();
    let c = statement.c_commit.to_affine().to_compressed();
    hash_to_scalar(&[&n_bytes, &a, &b, &c])
}

fn challenge_commitments(
    domain: u64,
    n: usize,
    statement: &Statement,
    commitments: &[G1Projective],
) -> Scalar {
    let mut owned = Vec::with_capacity(5 + commitments.len());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push((n as u64).to_le_bytes().to_vec());
    owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn challenge_batch_commitments(
    domain: u64,
    n: usize,
    statements: &[Statement],
    commitments: &[G1Projective],
) -> Scalar {
    let mut owned = Vec::with_capacity(3 + 3 * statements.len() + commitments.len());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push((n as u64).to_le_bytes().to_vec());
    owned.push((statements.len() as u64).to_le_bytes().to_vec());
    for statement in statements {
        owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    }
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
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
        FormulaKind::CProjection { .. } => {
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
        FormulaKind::BatchCProjection { rho, batch, .. } => {
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

fn expected_public_b_final(
    layout: &Layout,
    kind: FormulaKind,
    challenges: &[Scalar],
) -> Option<Scalar> {
    match kind {
        FormulaKind::CProjection { y } => Some(fold_eval(challenges, y, layout.nn, false)),
        FormulaKind::BatchCProjection { y, rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            Some(
                batch_eval(&challenges[..batch_bits], batch, rho, false)
                    * fold_eval(&challenges[batch_bits..], y, layout.nn, false),
            )
        }
        _ => None,
    }
}

fn expected_proof_len(layout: &Layout, kind: FormulaKind) -> usize {
    match kind {
        FormulaKind::CProjection { .. }
        | FormulaKind::AProjection { .. }
        | FormulaKind::BProjection { .. } => layout.nn,
        FormulaKind::Product => layout.n,
        FormulaKind::BatchCProjection { batch, .. }
        | FormulaKind::BatchAProjection { batch, .. }
        | FormulaKind::BatchBProjection { batch, .. } => batch * layout.nn,
        FormulaKind::BatchProduct { batch, .. } => batch * layout.n,
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
    let mut h = h_specs.map(|specs| materialize(srs, specs));
    let mut current = commitment;
    let mut left_messages = Vec::with_capacity(rounds);
    let mut right_messages = Vec::with_capacity(rounds);
    let mut len = proof_n;
    for round in 0..rounds {
        let half = len / 2;
        let left_cross = dot(&a[..half], &b[half..len]);
        let right_cross = dot(&a[half..len], &b[..half]);
        let mut left = msm(&g[half..len], &a[..half]) + scalar_base * left_cross;
        let mut right = msm(&g[..half], &a[half..len]) + scalar_base * right_cross;
        if let Some(h_points) = h.as_ref() {
            left += msm(&h_points[..half], &b[half..len]);
            right += msm(&h_points[half..len], &b[..half]);
        }
        let x = challenge_ip(domain, round, current, scalar_base, left, right);
        let xi = x.invert().unwrap();
        let (a_left, a_right) = a[..len].split_at_mut(half);
        let (b_left, b_right) = b[..len].split_at_mut(half);
        let (g_left, g_right) = g[..len].split_at_mut(half);
        if half >= 1024 {
            rayon::join(
                || {
                    rayon::join(
                        || {
                            a_left
                                .par_iter_mut()
                                .zip(a_right.par_iter())
                                .for_each(|(left, &right)| *left += xi * right);
                        },
                        || {
                            b_left
                                .par_iter_mut()
                                .zip(b_right.par_iter())
                                .for_each(|(left, &right)| *left += x * right);
                        },
                    );
                },
                || {
                    g_left
                        .par_iter_mut()
                        .zip(g_right.par_iter())
                        .for_each(|(left, &right)| *left += right * x);
                    if let Some(h_points) = h.as_mut() {
                        let (h_left, h_right) = h_points[..len].split_at_mut(half);
                        h_left
                            .par_iter_mut()
                            .zip(h_right.par_iter())
                            .for_each(|(left, &right)| *left += right * xi);
                    }
                },
            );
        } else {
            if let Some(h_points) = h.as_mut() {
                let (h_left, h_right) = h_points[..len].split_at_mut(half);
                for i in 0..half {
                    a_left[i] += xi * a_right[i];
                    b_left[i] += x * b_right[i];
                    g_left[i] += g_right[i] * x;
                    h_left[i] += h_right[i] * xi;
                }
            } else {
                for i in 0..half {
                    a_left[i] += xi * a_right[i];
                    b_left[i] += x * b_right[i];
                    g_left[i] += g_right[i] * x;
                }
            }
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
    if proof.n != expected_proof_len(layout, formula) || !proof.n.is_power_of_two() {
        return false;
    }
    if proof.left.len() != proof.n.trailing_zeros() as usize
        || proof.right.len() != proof.left.len()
    {
        return false;
    }
    let (challenges, current) = ipa_challenges(commitment, scalar_base, proof, domain);
    if let Some(expected_b_final) = expected_public_b_final(layout, formula, &challenges) {
        if proof.b_final != expected_b_final {
            return false;
        }
    }
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
    let ay = project_a(layout, &witness.a, &yl);
    let by = project_b(layout, &witness.b, &yr);
    let d = dot(&witness.c, &yvec);
    (yvec, yl, yr, ay, by, d)
}

fn project_a(layout: &Layout, values: &[Scalar], yl: &[Scalar]) -> Vec<Scalar> {
    (0..layout.n)
        .into_par_iter()
        .map(|j| {
            let mut acc = Scalar::ZERO;
            for i in 0..layout.n {
                acc += yl[i] * values[i * layout.n + j];
            }
            acc
        })
        .collect()
}

fn project_b(layout: &Layout, values: &[Scalar], yr: &[Scalar]) -> Vec<Scalar> {
    values
        .par_chunks(layout.n)
        .map(|row| dot(row, yr))
        .collect()
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
        FormulaKind::CProjection { y },
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

fn random_scalars(len: usize, rng: &mut ProofRng) -> Vec<Scalar> {
    (0..len).map(|_| scalar_from_proof_rng(rng)).collect()
}

fn mask_values(values: &[Scalar], mask: &mut [Scalar], challenge: Scalar) {
    mask.par_iter_mut()
        .zip(values.par_iter())
        .for_each(|(masked, &value)| {
            *masked = value + challenge * *masked;
        });
}

fn prove_zk_public_ip(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    public_values: &[Scalar],
    input_specs: &[BasisSpec],
    output_base: G1Projective,
    input_blind: Scalar,
    output_blind: Scalar,
    domain: u64,
    rng: &mut ProofRng,
) -> ZkProjectionProof {
    let mut alpha = random_scalars(input_values.len(), rng);
    let projected_alpha = dot(&alpha, public_values);
    let alpha_blind = scalar_from_proof_rng(rng);
    let projected_alpha_blind = scalar_from_proof_rng(rng);
    let mask_commit = commit_specs_blinded(srs, input_specs, &alpha, alpha_blind);
    let projected_mask_commit = output_base * projected_alpha + srs.blind * projected_alpha_blind;
    let x = challenge_commitments(
        domain,
        layout.n,
        statement,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
    );
    let response_blind = input_blind + x * alpha_blind;
    let projected_response_blind = output_blind + x * projected_alpha_blind;
    mask_values(input_values, &mut alpha, x);
    let masked_input = input_commit + mask_commit * x - srs.blind * response_blind;
    let masked_output =
        output_commit + projected_mask_commit * x - srs.blind * projected_response_blind;
    let proof = prove_ip_structured(
        srs,
        layout,
        masked_input + masked_output,
        output_base,
        input_specs,
        None,
        &alpha,
        Some(public_values),
        domain ^ 0x9999,
    );
    ZkProjectionProof {
        mask_commit,
        projected_mask_commit,
        response_blind,
        projected_response_blind,
        proof,
    }
}

fn verify_zk_public_ip(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    public_y: Scalar,
    public_values: &[Scalar],
    input_specs: &[BasisSpec],
    output_base: G1Projective,
    proof: &ZkProjectionProof,
    domain: u64,
) -> bool {
    let x = challenge_commitments(
        domain,
        layout.n,
        statement,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
    );
    let masked_input = input_commit + proof.mask_commit * x - srs.blind * proof.response_blind;
    let masked_output = output_commit + proof.projected_mask_commit * x
        - srs.blind * proof.projected_response_blind;
    verify_ip_fast(
        srs,
        layout,
        masked_input + masked_output,
        output_base,
        &proof.proof,
        domain ^ 0x9999,
        FormulaKind::CProjection { y: public_y },
    ) && proof.proof.n == public_values.len()
        && proof.proof.n == input_specs.len()
}

fn prove_zk_projection(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    coeffs: &[Scalar],
    input_specs: &[BasisSpec],
    output_specs: &[BasisSpec],
    projected_specs: &[BasisSpec],
    input_blind: Scalar,
    output_blind: Scalar,
    axis_rows: bool,
    domain: u64,
    rng: &mut ProofRng,
) -> ZkProjectionProof {
    let mut alpha = random_scalars(input_values.len(), rng);
    let projected_alpha = if axis_rows {
        project_a(layout, &alpha, coeffs)
    } else {
        project_b(layout, &alpha, coeffs)
    };
    let alpha_blind = scalar_from_proof_rng(rng);
    let projected_alpha_blind = scalar_from_proof_rng(rng);
    let mask_commit = commit_specs_blinded(srs, input_specs, &alpha, alpha_blind);
    let projected_mask_commit =
        commit_specs_blinded(srs, output_specs, &projected_alpha, projected_alpha_blind);
    let x = challenge_commitments(
        domain,
        layout.n,
        statement,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
    );
    let response_blind = input_blind + x * alpha_blind;
    let projected_response_blind = output_blind + x * projected_alpha_blind;
    mask_values(input_values, &mut alpha, x);
    let masked_input = input_commit + mask_commit * x - srs.blind * response_blind;
    let masked_output =
        output_commit + projected_mask_commit * x - srs.blind * projected_response_blind;
    let proof = prove_ip_structured(
        srs,
        layout,
        masked_input + masked_output,
        G1Projective::identity(),
        projected_specs,
        None,
        &alpha,
        None,
        domain ^ 0x8888,
    );
    ZkProjectionProof {
        mask_commit,
        projected_mask_commit,
        response_blind,
        projected_response_blind,
        proof,
    }
}

fn verify_zk_projection(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    projected_specs: &[BasisSpec],
    proof: &ZkProjectionProof,
    domain: u64,
    formula: FormulaKind,
) -> bool {
    let x = challenge_commitments(
        domain,
        layout.n,
        statement,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
    );
    let masked_input = input_commit + proof.mask_commit * x - srs.blind * proof.response_blind;
    let masked_output = output_commit + proof.projected_mask_commit * x
        - srs.blind * proof.projected_response_blind;
    verify_ip_fast(
        srs,
        layout,
        masked_input + masked_output,
        G1Projective::identity(),
        &proof.proof,
        domain ^ 0x8888,
        formula,
    ) && proof.proof.n == projected_specs.len()
}

fn prove_zk_product(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    output_commit: G1Projective,
    left_commit: G1Projective,
    right_commit: G1Projective,
    left_values: &[Scalar],
    right_values: &[Scalar],
    output_blind: Scalar,
    left_blind: Scalar,
    right_blind: Scalar,
    left_specs: &[BasisSpec],
    right_specs: &[BasisSpec],
    rng: &mut ProofRng,
) -> ZkProductProof {
    let mut alpha = random_scalars(layout.n, rng);
    let mut beta = random_scalars(layout.n, rng);
    let alpha_beta = dot(&alpha, &beta);
    let cross = dot(&alpha, right_values) + dot(left_values, &beta);
    let alpha_blind = scalar_from_proof_rng(rng);
    let beta_blind = scalar_from_proof_rng(rng);
    let cross_blind = scalar_from_proof_rng(rng);
    let alpha_beta_blind = scalar_from_proof_rng(rng);
    let alpha_commit = commit_specs_blinded(srs, left_specs, &alpha, alpha_blind);
    let beta_commit = commit_specs_blinded(srs, right_specs, &beta, beta_blind);
    let cross_commit = srs.u * cross + srs.blind * cross_blind;
    let alpha_beta_commit = srs.u * alpha_beta + srs.blind * alpha_beta_blind;
    let x = challenge_commitments(
        0xD0D0,
        layout.n,
        statement,
        &[
            output_commit,
            left_commit,
            right_commit,
            alpha_commit,
            beta_commit,
            cross_commit,
            alpha_beta_commit,
        ],
    );
    let x2 = x * x;
    let left_response_blind = left_blind + x * alpha_blind;
    let right_response_blind = right_blind + x * beta_blind;
    let output_response_blind = output_blind + x * cross_blind + x2 * alpha_beta_blind;
    mask_values(left_values, &mut alpha, x);
    mask_values(right_values, &mut beta, x);
    let masked_left = left_commit + alpha_commit * x - srs.blind * left_response_blind;
    let masked_right = right_commit + beta_commit * x - srs.blind * right_response_blind;
    let masked_output = output_commit + cross_commit * x + alpha_beta_commit * x2
        - srs.blind * output_response_blind;
    let proof = prove_ip_structured(
        srs,
        layout,
        masked_output + masked_left + masked_right,
        srs.u,
        left_specs,
        Some(right_specs),
        &alpha,
        Some(&beta),
        0xD0D1,
    );
    ZkProductProof {
        alpha_commit,
        beta_commit,
        cross_commit,
        alpha_beta_commit,
        left_response_blind,
        right_response_blind,
        output_response_blind,
        proof,
    }
}

fn verify_zk_product(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    output_commit: G1Projective,
    left_commit: G1Projective,
    right_commit: G1Projective,
    proof: &ZkProductProof,
) -> bool {
    let x = challenge_commitments(
        0xD0D0,
        layout.n,
        statement,
        &[
            output_commit,
            left_commit,
            right_commit,
            proof.alpha_commit,
            proof.beta_commit,
            proof.cross_commit,
            proof.alpha_beta_commit,
        ],
    );
    let x2 = x * x;
    let masked_left = left_commit + proof.alpha_commit * x - srs.blind * proof.left_response_blind;
    let masked_right =
        right_commit + proof.beta_commit * x - srs.blind * proof.right_response_blind;
    let masked_output = output_commit + proof.cross_commit * x + proof.alpha_beta_commit * x2
        - srs.blind * proof.output_response_blind;
    verify_ip_fast(
        srs,
        layout,
        masked_output + masked_left + masked_right,
        srs.u,
        &proof.proof,
        0xD0D1,
        FormulaKind::Product,
    )
}

fn prove_zk_public_ip_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    public_values: &[Scalar],
    input_specs: &[BasisSpec],
    output_base: G1Projective,
    input_blind: Scalar,
    output_blind: Scalar,
    domain: u64,
    rng: &mut ProofRng,
) -> ZkProjectionProof {
    let mut alpha = random_scalars(input_values.len(), rng);
    let projected_alpha = dot(&alpha, public_values);
    let alpha_blind = scalar_from_proof_rng(rng);
    let projected_alpha_blind = scalar_from_proof_rng(rng);
    let mask_commit = commit_specs_blinded(srs, input_specs, &alpha, alpha_blind);
    let projected_mask_commit = output_base * projected_alpha + srs.blind * projected_alpha_blind;
    let x = challenge_batch_commitments(
        domain,
        layout.n,
        statements,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
    );
    let response_blind = input_blind + x * alpha_blind;
    let projected_response_blind = output_blind + x * projected_alpha_blind;
    mask_values(input_values, &mut alpha, x);
    let masked_input = input_commit + mask_commit * x - srs.blind * response_blind;
    let masked_output =
        output_commit + projected_mask_commit * x - srs.blind * projected_response_blind;
    let proof = prove_ip_structured(
        srs,
        layout,
        masked_input + masked_output,
        output_base,
        input_specs,
        None,
        &alpha,
        Some(public_values),
        domain ^ 0x9999,
    );
    ZkProjectionProof {
        mask_commit,
        projected_mask_commit,
        response_blind,
        projected_response_blind,
        proof,
    }
}

fn verify_zk_public_ip_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    output_base: G1Projective,
    proof: &ZkProjectionProof,
    domain: u64,
    formula: FormulaKind,
) -> bool {
    let x = challenge_batch_commitments(
        domain,
        layout.n,
        statements,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
    );
    let masked_input = input_commit + proof.mask_commit * x - srs.blind * proof.response_blind;
    let masked_output = output_commit + proof.projected_mask_commit * x
        - srs.blind * proof.projected_response_blind;
    verify_ip_fast(
        srs,
        layout,
        masked_input + masked_output,
        output_base,
        &proof.proof,
        domain ^ 0x9999,
        formula,
    )
}

fn prove_zk_projection_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    coeffs: &[Scalar],
    input_specs: &[BasisSpec],
    output_specs: &[BasisSpec],
    projected_specs: &[BasisSpec],
    input_blind: Scalar,
    output_blind: Scalar,
    axis_rows: bool,
    domain: u64,
    rng: &mut ProofRng,
) -> ZkProjectionProof {
    let mut alpha = random_scalars(input_values.len(), rng);
    let projected_alpha = if axis_rows {
        project_a(layout, &alpha, coeffs)
    } else {
        project_b(layout, &alpha, coeffs)
    };
    let alpha_blind = scalar_from_proof_rng(rng);
    let projected_alpha_blind = scalar_from_proof_rng(rng);
    let mask_commit = commit_specs_blinded(srs, input_specs, &alpha, alpha_blind);
    let projected_mask_commit =
        commit_specs_blinded(srs, output_specs, &projected_alpha, projected_alpha_blind);
    let x = challenge_batch_commitments(
        domain,
        layout.n,
        statements,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
    );
    let response_blind = input_blind + x * alpha_blind;
    let projected_response_blind = output_blind + x * projected_alpha_blind;
    mask_values(input_values, &mut alpha, x);
    let masked_input = input_commit + mask_commit * x - srs.blind * response_blind;
    let masked_output =
        output_commit + projected_mask_commit * x - srs.blind * projected_response_blind;
    let proof = prove_ip_structured(
        srs,
        layout,
        masked_input + masked_output,
        G1Projective::identity(),
        projected_specs,
        None,
        &alpha,
        None,
        domain ^ 0x8888,
    );
    ZkProjectionProof {
        mask_commit,
        projected_mask_commit,
        response_blind,
        projected_response_blind,
        proof,
    }
}

fn verify_zk_projection_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    proof: &ZkProjectionProof,
    domain: u64,
    formula: FormulaKind,
) -> bool {
    let x = challenge_batch_commitments(
        domain,
        layout.n,
        statements,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
    );
    let masked_input = input_commit + proof.mask_commit * x - srs.blind * proof.response_blind;
    let masked_output = output_commit + proof.projected_mask_commit * x
        - srs.blind * proof.projected_response_blind;
    verify_ip_fast(
        srs,
        layout,
        masked_input + masked_output,
        G1Projective::identity(),
        &proof.proof,
        domain ^ 0x8888,
        formula,
    )
}

fn prove_zk_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    witness: &Witness,
    rng: &mut ProofRng,
) -> ZkMatrixProof {
    let (_y, yvec, yl, yr, ay, by, d) = projections(layout, statement, witness);
    let c_specs: Vec<_> = (0..layout.nn).map(|idx| c_spec(layout, idx)).collect();
    let a_specs: Vec<_> = (0..layout.nn).map(|idx| a_spec(layout, idx)).collect();
    let b_specs: Vec<_> = (0..layout.nn).map(|idx| b_spec(layout, idx)).collect();
    let ay_specs: Vec<_> = (0..layout.n).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.n).map(|i| by_spec(layout, i)).collect();
    let a_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| a_projection_spec(layout, idx, &yl, Scalar::ONE))
        .collect();
    let b_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| b_projection_spec(layout, idx, &yr, Scalar::ONE))
        .collect();
    let d_blind = scalar_from_proof_rng(rng);
    let ay_blind = scalar_from_proof_rng(rng);
    let by_blind = scalar_from_proof_rng(rng);
    let d_commit = srs.u * d + srs.blind * d_blind;
    let ay_commit = commit_window(srs, layout.off_ay, &ay, ay_blind);
    let by_commit = commit_window(srs, layout.off_by, &by, by_blind);
    let c_proj = prove_zk_public_ip(
        layout,
        srs,
        statement,
        statement.c_commit,
        d_commit,
        &witness.c,
        &yvec,
        &c_specs,
        srs.u,
        witness.c_blind,
        d_blind,
        0xC101,
        rng,
    );
    let a_proj = prove_zk_projection(
        layout,
        srs,
        statement,
        statement.a_commit,
        ay_commit,
        &witness.a,
        &yl,
        &a_specs,
        &ay_specs,
        &a_proj_specs,
        witness.a_blind,
        ay_blind,
        true,
        0xA102,
        rng,
    );
    let b_proj = prove_zk_projection(
        layout,
        srs,
        statement,
        statement.b_commit,
        by_commit,
        &witness.b,
        &yr,
        &b_specs,
        &by_specs,
        &b_proj_specs,
        witness.b_blind,
        by_blind,
        false,
        0xB103,
        rng,
    );
    let product = prove_zk_product(
        layout, srs, statement, d_commit, ay_commit, by_commit, &ay, &by, d_blind, ay_blind,
        by_blind, &ay_specs, &by_specs, rng,
    );
    ZkMatrixProof {
        d_commit,
        ay_commit,
        by_commit,
        c_proj,
        a_proj,
        b_proj,
        product,
    }
}

fn verify_zk_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    statement: &Statement,
    proof: &ZkMatrixProof,
) -> bool {
    let y = challenge_statement(layout.n, statement);
    let yvec = powers(y, layout.nn);
    let yr = powers(y, layout.n);
    let yl: Vec<_> = (0..layout.n).map(|i| yvec[i * layout.n]).collect();
    let c_specs: Vec<_> = (0..layout.nn).map(|idx| c_spec(layout, idx)).collect();
    let a_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| a_projection_spec(layout, idx, &yl, Scalar::ONE))
        .collect();
    let b_proj_specs: Vec<_> = (0..layout.nn)
        .map(|idx| b_projection_spec(layout, idx, &yr, Scalar::ONE))
        .collect();
    verify_zk_public_ip(
        layout,
        srs,
        statement,
        statement.c_commit,
        proof.d_commit,
        y,
        &yvec,
        &c_specs,
        srs.u,
        &proof.c_proj,
        0xC101,
    ) && verify_zk_projection(
        layout,
        srs,
        statement,
        statement.a_commit,
        proof.ay_commit,
        &a_proj_specs,
        &proof.a_proj,
        0xA102,
        FormulaKind::AProjection { y },
    ) && verify_zk_projection(
        layout,
        srs,
        statement,
        statement.b_commit,
        proof.by_commit,
        &b_proj_specs,
        &proof.b_proj,
        0xB103,
        FormulaKind::BProjection { y },
    ) && verify_zk_product(
        layout,
        srs,
        statement,
        proof.d_commit,
        proof.ay_commit,
        proof.by_commit,
        &proof.product,
    )
}

fn self_test() {
    for n in [2usize, 4, 8] {
        let layout = layout(n);
        let mut rng = 0x5775_1000 + n as u64;
        let tau = scalar_from_rng(&mut rng);
        let srs = make_srs(&layout, tau);
        let witness = make_witness(n, 0xA11CE + n as u64);
        let core_statement = statement(&layout, &srs, &witness);
        let mut proof = prove_matrix(&layout, &srs, &core_statement, &witness);
        assert!(verify_matrix(&layout, &srs, &core_statement, &proof));
        proof.c_proj.b_final += Scalar::ONE;
        assert!(!verify_matrix(&layout, &srs, &core_statement, &proof));

        let mut bad_witness = make_witness(n, 0xBAD0 + n as u64);
        bad_witness.c[0] += Scalar::ONE;
        let bad_statement = statement(&layout, &srs, &bad_witness);
        let bad_proof = prove_matrix(&layout, &srs, &bad_statement, &bad_witness);
        assert!(!verify_matrix(&layout, &srs, &bad_statement, &bad_proof));

        let mut zk_witness = make_witness(n, 0xC0FFEE + n as u64);
        let mut zk_rng = proof_rng();
        let zk_stmt = zk_statement(&layout, &srs, &mut zk_witness, &mut zk_rng);
        let mut zk_proof = prove_zk_matrix(&layout, &srs, &zk_stmt, &zk_witness, &mut zk_rng);
        assert!(verify_zk_matrix(&layout, &srs, &zk_stmt, &zk_proof));
        zk_proof.c_proj.proof.b_final += Scalar::ONE;
        assert!(!verify_zk_matrix(&layout, &srs, &zk_stmt, &zk_proof));

        let mut bad_zk_witness = make_witness(n, 0xDEAD + n as u64);
        bad_zk_witness.c[0] += Scalar::ONE;
        let bad_zk_statement = zk_statement(&layout, &srs, &mut bad_zk_witness, &mut zk_rng);
        let bad_zk_proof = prove_zk_matrix(
            &layout,
            &srs,
            &bad_zk_statement,
            &bad_zk_witness,
            &mut zk_rng,
        );
        assert!(!verify_zk_matrix(
            &layout,
            &srs,
            &bad_zk_statement,
            &bad_zk_proof
        ));

        let mut batch_witnesses: Vec<_> = (0..2)
            .map(|i| make_witness(n, 0xB47C0 + n as u64 + i as u64))
            .collect();
        let batch_statements: Vec<_> = batch_witnesses
            .iter()
            .map(|w| statement(&layout, &srs, w))
            .collect();
        let mut batch_proof = prove_batch(&layout, &srs, &batch_statements, &batch_witnesses);
        assert!(verify_batch(&layout, &srs, &batch_statements, &batch_proof));
        batch_proof.c_proj.b_final += Scalar::ONE;
        assert!(!verify_batch(
            &layout,
            &srs,
            &batch_statements,
            &batch_proof
        ));

        batch_witnesses[1].c[0] += Scalar::ONE;
        let bad_batch_statements: Vec<_> = batch_witnesses
            .iter()
            .map(|w| statement(&layout, &srs, w))
            .collect();
        let bad_batch_proof = prove_batch(&layout, &srs, &bad_batch_statements, &batch_witnesses);
        assert!(!verify_batch(
            &layout,
            &srs,
            &bad_batch_statements,
            &bad_batch_proof
        ));

        let mut zk_batch_witnesses: Vec<_> = (0..2)
            .map(|i| make_witness(n, 0xAB47C0 + n as u64 + i as u64))
            .collect();
        let zk_batch_statements: Vec<_> = zk_batch_witnesses
            .iter_mut()
            .map(|w| zk_statement(&layout, &srs, w, &mut zk_rng))
            .collect();
        let mut zk_batch_proof = prove_zk_batch(
            &layout,
            &srs,
            &zk_batch_statements,
            &zk_batch_witnesses,
            &mut zk_rng,
        );
        assert!(verify_zk_batch(
            &layout,
            &srs,
            &zk_batch_statements,
            &zk_batch_proof
        ));
        zk_batch_proof.c_proj.proof.b_final += Scalar::ONE;
        assert!(!verify_zk_batch(
            &layout,
            &srs,
            &zk_batch_statements,
            &zk_batch_proof
        ));

        zk_batch_witnesses[1].c[0] += Scalar::ONE;
        let bad_zk_batch_statements: Vec<_> = zk_batch_witnesses
            .iter_mut()
            .map(|w| zk_statement(&layout, &srs, w, &mut zk_rng))
            .collect();
        let bad_zk_batch_proof = prove_zk_batch(
            &layout,
            &srs,
            &bad_zk_batch_statements,
            &zk_batch_witnesses,
            &mut zk_rng,
        );
        assert!(!verify_zk_batch(
            &layout,
            &srs,
            &bad_zk_batch_statements,
            &bad_zk_batch_proof
        ));
    }
    println!("structured-matrix self-test ok");
}

fn bench(mode: &str, n: usize) {
    let layout = layout(n);
    let mut rng = 0x5775_2000 + n as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(&layout, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witness = make_witness(n, 0xBEEF + n as u64);
    let start = Instant::now();
    let mut zk_rng = proof_rng();
    let statement = if mode == "zk" {
        zk_statement(&layout, &srs, &mut witness, &mut zk_rng)
    } else {
        statement(&layout, &srs, &witness)
    };
    let commit_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let (prove_s, verify_s, verified) = if mode == "zk" {
        let proof = prove_zk_matrix(&layout, &srs, &statement, &witness, &mut zk_rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk_matrix(&layout, &srs, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    } else {
        let proof = prove_matrix(&layout, &srs, &statement, &witness);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_matrix(&layout, &srs, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    };
    println!("{mode},{n},{setup_s:.9},{commit_s:.9},{prove_s:.9},{verify_s:.9},{verified}");
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

fn challenge_batch_y(statements: &[Statement], n: usize) -> Scalar {
    let n_bytes = (n as u64).to_le_bytes();
    let mut owned = vec![
        b"batch-y-alg6".to_vec(),
        n_bytes.to_vec(),
        (statements.len() as u64).to_le_bytes().to_vec(),
    ];
    for statement in statements {
        owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn challenge_batch_rho(
    statements: &[Statement],
    n: usize,
    d_commits: &[G1Projective],
    ay_commits: &[G1Projective],
    by_commits: &[G1Projective],
) -> Scalar {
    assert_eq!(statements.len(), d_commits.len());
    assert_eq!(statements.len(), ay_commits.len());
    assert_eq!(statements.len(), by_commits.len());
    let n_bytes = (n as u64).to_le_bytes();
    let mut owned = Vec::with_capacity(3 + 6 * statements.len());
    owned.push(b"batch-rho-alg6".to_vec());
    owned.push(n_bytes.to_vec());
    owned.push((statements.len() as u64).to_le_bytes().to_vec());
    for (((statement, d_commit), ay_commit), by_commit) in statements
        .iter()
        .zip(d_commits.iter())
        .zip(ay_commits.iter())
        .zip(by_commits.iter())
    {
        owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
        owned.push(d_commit.to_affine().to_compressed().to_vec());
        owned.push(ay_commit.to_affine().to_compressed().to_vec());
        owned.push(by_commit.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn batch_input_commitments(
    statements: &[Statement],
    rho_powers: &[Scalar],
) -> (G1Projective, G1Projective, G1Projective) {
    let mut a_commit = G1Projective::identity();
    let mut b_commit = G1Projective::identity();
    let mut c_commit = G1Projective::identity();
    for (statement, &rho_i) in statements.iter().zip(rho_powers.iter()) {
        a_commit += statement.a_commit * rho_i;
        b_commit += statement.b_commit * rho_i;
        c_commit += statement.c_commit * rho_i;
    }
    (a_commit, b_commit, c_commit)
}

fn batch_input_blinds(witnesses: &[Witness], rho_powers: &[Scalar]) -> (Scalar, Scalar, Scalar) {
    let mut a_blind = Scalar::ZERO;
    let mut b_blind = Scalar::ZERO;
    let mut c_blind = Scalar::ZERO;
    for (witness, &rho_i) in witnesses.iter().zip(rho_powers.iter()) {
        a_blind += rho_i * witness.a_blind;
        b_blind += rho_i * witness.b_blind;
        c_blind += rho_i * witness.c_blind;
    }
    (a_blind, b_blind, c_blind)
}

fn weighted_commitments(commits: &[G1Projective], rho_powers: &[Scalar]) -> G1Projective {
    commits
        .iter()
        .zip(rho_powers.iter())
        .fold(G1Projective::identity(), |acc, (&commit, &rho_i)| {
            acc + commit * rho_i
        })
}

fn weighted_scalars(values: &[Scalar], rho_powers: &[Scalar]) -> Scalar {
    values
        .iter()
        .zip(rho_powers.iter())
        .fold(Scalar::ZERO, |acc, (&value, &rho_i)| acc + value * rho_i)
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

fn prove_zk_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    witnesses: &[Witness],
    rng: &mut ProofRng,
) -> ZkBatchProof {
    assert_eq!(statements.len(), witnesses.len());
    assert!(statements.len().is_power_of_two());
    let batch = statements.len();
    let y = challenge_batch_y(statements, layout.n);
    let (yvec, yl, yr, _, _, _) = projections_with_y(layout, &witnesses[0], y);

    let c_specs: Vec<_> = (0..layout.nn).map(|idx| c_spec(layout, idx)).collect();
    let a_specs: Vec<_> = (0..layout.nn).map(|idx| a_spec(layout, idx)).collect();
    let b_specs: Vec<_> = (0..layout.nn).map(|idx| b_spec(layout, idx)).collect();
    let ay_specs: Vec<_> = (0..layout.n).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.n).map(|i| by_spec(layout, i)).collect();
    let a_projected_specs: Vec<_> = (0..layout.nn)
        .map(|idx| a_projection_spec(layout, idx, &yl, Scalar::ONE))
        .collect();
    let b_projected_specs: Vec<_> = (0..layout.nn)
        .map(|idx| b_projection_spec(layout, idx, &yr, Scalar::ONE))
        .collect();

    let mut d_values = Vec::with_capacity(batch);
    let mut d_blinds = Vec::with_capacity(batch);
    let mut d_commits = Vec::with_capacity(batch);
    let mut ay_values = Vec::with_capacity(batch);
    let mut ay_blinds = Vec::with_capacity(batch);
    let mut ay_commits = Vec::with_capacity(batch);
    let mut by_values = Vec::with_capacity(batch);
    let mut by_blinds = Vec::with_capacity(batch);
    let mut by_commits = Vec::with_capacity(batch);

    for witness in witnesses {
        let (_, _, _, ay, by, d) = projections_with_y(layout, witness, y);
        let d_blind = scalar_from_proof_rng(rng);
        let ay_blind = scalar_from_proof_rng(rng);
        let by_blind = scalar_from_proof_rng(rng);
        d_values.push(d);
        d_blinds.push(d_blind);
        d_commits.push(srs.u * d + srs.blind * d_blind);
        ay_commits.push(commit_window(srs, layout.off_ay, &ay, ay_blind));
        by_commits.push(commit_window(srs, layout.off_by, &by, by_blind));
        ay_values.push(ay);
        ay_blinds.push(ay_blind);
        by_values.push(by);
        by_blinds.push(by_blind);
    }

    let rho = challenge_batch_rho(statements, layout.n, &d_commits, &ay_commits, &by_commits);
    let rho_powers = powers(rho, batch);
    let (a_input_commit, b_input_commit, c_input_commit) =
        batch_input_commitments(statements, &rho_powers);
    let (a_input_blind, b_input_blind, c_input_blind) = batch_input_blinds(witnesses, &rho_powers);
    let d_commit = weighted_commitments(&d_commits, &rho_powers);
    let ay_commit = weighted_commitments(&ay_commits, &rho_powers);
    let by_commit = weighted_commitments(&by_commits, &rho_powers);
    let d_blind = weighted_scalars(&d_blinds, &rho_powers);
    let ay_blind = weighted_scalars(&ay_blinds, &rho_powers);
    let by_blind = weighted_scalars(&by_blinds, &rho_powers);

    let mut a_values = vec![Scalar::ZERO; layout.nn];
    let mut b_values = vec![Scalar::ZERO; layout.nn];
    let mut c_values = vec![Scalar::ZERO; layout.nn];
    for (witness, &rho_i) in witnesses.iter().zip(rho_powers.iter()) {
        for idx in 0..layout.nn {
            a_values[idx] += rho_i * witness.a[idx];
            b_values[idx] += rho_i * witness.b[idx];
            c_values[idx] += rho_i * witness.c[idx];
        }
    }

    let c_proj = prove_zk_public_ip_batch(
        layout,
        srs,
        statements,
        c_input_commit,
        d_commit,
        &c_values,
        &yvec,
        &c_specs,
        srs.u,
        c_input_blind,
        d_blind,
        0xC201,
        rng,
    );
    let a_proj = prove_zk_projection_batch(
        layout,
        srs,
        statements,
        a_input_commit,
        ay_commit,
        &a_values,
        &yl,
        &a_specs,
        &ay_specs,
        &a_projected_specs,
        a_input_blind,
        ay_blind,
        true,
        0xA202,
        rng,
    );
    let b_proj = prove_zk_projection_batch(
        layout,
        srs,
        statements,
        b_input_commit,
        by_commit,
        &b_values,
        &yr,
        &b_specs,
        &by_specs,
        &b_projected_specs,
        b_input_blind,
        by_blind,
        false,
        0xB203,
        rng,
    );
    let products: Vec<_> = (0..batch)
        .map(|idx| {
            prove_zk_product(
                layout,
                srs,
                &statements[idx],
                d_commits[idx],
                ay_commits[idx],
                by_commits[idx],
                &ay_values[idx],
                &by_values[idx],
                d_blinds[idx],
                ay_blinds[idx],
                by_blinds[idx],
                &ay_specs,
                &by_specs,
                rng,
            )
        })
        .collect();
    ZkBatchProof {
        y,
        rho,
        d_commits,
        ay_commits,
        by_commits,
        c_proj,
        a_proj,
        b_proj,
        products,
    }
}

fn verify_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    proof: &BatchProof,
) -> bool {
    if statements.is_empty() || !statements.len().is_power_of_two() {
        return false;
    }
    let batch = statements.len();
    let (y, rho) = batch_challenges(statements, layout.n);
    if proof.y != y || proof.rho != rho {
        return false;
    }
    let rho_powers = powers(rho, batch);
    let (a_input_commit, b_input_commit, c_input_commit) =
        batch_input_commitments(statements, &rho_powers);
    let c_lhs = c_input_commit + srs.u * proof.d;
    let ay_commit = proof.a_lhs - a_input_commit;
    let by_commit = proof.b_lhs - b_input_commit;
    let product_lhs = srs.u * proof.d + ay_commit + by_commit;
    if proof.c_lhs != c_lhs || proof.product_lhs != product_lhs {
        return false;
    }
    verify_ip_fast(
        srs,
        layout,
        c_lhs,
        srs.u,
        &proof.c_proj,
        0xC101,
        FormulaKind::BatchCProjection {
            y: proof.y,
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
        product_lhs,
        srs.u,
        &proof.product,
        0xD104,
        FormulaKind::BatchProduct {
            rho: proof.rho,
            batch,
        },
    )
}

fn verify_zk_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    statements: &[Statement],
    proof: &ZkBatchProof,
) -> bool {
    if statements.is_empty() || !statements.len().is_power_of_two() {
        return false;
    }
    let batch = statements.len();
    if proof.d_commits.len() != batch
        || proof.ay_commits.len() != batch
        || proof.by_commits.len() != batch
        || proof.products.len() != batch
    {
        return false;
    }
    let y = challenge_batch_y(statements, layout.n);
    let rho = challenge_batch_rho(
        statements,
        layout.n,
        &proof.d_commits,
        &proof.ay_commits,
        &proof.by_commits,
    );
    if proof.y != y || proof.rho != rho {
        return false;
    }
    let rho_powers = powers(rho, batch);
    let (a_input_commit, b_input_commit, c_input_commit) =
        batch_input_commitments(statements, &rho_powers);
    let d_commit = weighted_commitments(&proof.d_commits, &rho_powers);
    let ay_commit = weighted_commitments(&proof.ay_commits, &rho_powers);
    let by_commit = weighted_commitments(&proof.by_commits, &rho_powers);
    verify_zk_public_ip_batch(
        layout,
        srs,
        statements,
        c_input_commit,
        d_commit,
        srs.u,
        &proof.c_proj,
        0xC201,
        FormulaKind::CProjection { y },
    ) && verify_zk_projection_batch(
        layout,
        srs,
        statements,
        a_input_commit,
        ay_commit,
        &proof.a_proj,
        0xA202,
        FormulaKind::AProjection { y },
    ) && verify_zk_projection_batch(
        layout,
        srs,
        statements,
        b_input_commit,
        by_commit,
        &proof.b_proj,
        0xB203,
        FormulaKind::BProjection { y },
    ) && (0..batch).all(|idx| {
        verify_zk_product(
            layout,
            srs,
            &statements[idx],
            proof.d_commits[idx],
            proof.ay_commits[idx],
            proof.by_commits[idx],
            &proof.products[idx],
        )
    })
}

fn bench_batch(mode: &str, n: usize, batch: usize) {
    assert!(batch.is_power_of_two());
    let layout = layout(n);
    let mut rng = 0x5775_3000 + n as u64 + batch as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(&layout, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witnesses: Vec<_> = (0..batch)
        .map(|i| make_witness(n, 0xCAFE + n as u64 + 17 * i as u64))
        .collect();
    let mut zk_rng = proof_rng();
    let start = Instant::now();
    let statements: Vec<_> = if mode == "zk" {
        witnesses
            .iter_mut()
            .map(|w| zk_statement(&layout, &srs, w, &mut zk_rng))
            .collect()
    } else {
        witnesses
            .iter()
            .map(|w| statement(&layout, &srs, w))
            .collect()
    };
    let commit_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let (batch_prove_s, batch_verify_s, verified) = if mode == "zk" {
        let proof = prove_zk_batch(&layout, &srs, &statements, &witnesses, &mut zk_rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk_batch(&layout, &srs, &statements, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    } else {
        let proof = prove_batch(&layout, &srs, &statements, &witnesses);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_batch(&layout, &srs, &statements, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    };
    println!(
        "{mode},{n},{batch},{setup_s:.9},{commit_s:.9},{batch_prove_s:.9},{:.9},{batch_verify_s:.9},{:.9},{verified}",
        batch_prove_s / batch as f64,
        batch_verify_s / batch as f64,
    );
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  structured_matrix self-test");
    eprintln!("  structured_matrix bench <core|zk|both> <n> [n...]");
    eprintln!("  structured_matrix bench-batch <core|zk> <n> <batch_power_of_two>");
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
            if args.len() < 4 {
                usage();
                std::process::exit(1);
            }
            let mode = args[2].as_str();
            if mode != "core" && mode != "zk" && mode != "both" {
                usage();
                std::process::exit(1);
            }
            println!("mode,n,setup_s,commit_s,prove_s,verify_s,verified");
            for n_arg in &args[3..] {
                let n: usize = n_arg.parse().unwrap();
                if mode == "both" {
                    bench("core", n);
                    bench("zk", n);
                } else {
                    bench(mode, n);
                }
            }
        }
        "bench-batch" => {
            let (mode, n_arg, batch_arg) = if args.len() == 4 {
                ("core", args[2].as_str(), args[3].as_str())
            } else if args.len() == 5 {
                (args[2].as_str(), args[3].as_str(), args[4].as_str())
            } else {
                usage();
                std::process::exit(1);
            };
            if mode != "core" && mode != "zk" {
                usage();
                std::process::exit(1);
            }
            let n: usize = n_arg.parse().unwrap();
            let batch: usize = batch_arg.parse().unwrap();
            println!(
                "mode,n,batch,setup_s,commit_s,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s,verified"
            );
            bench_batch(mode, n, batch);
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
