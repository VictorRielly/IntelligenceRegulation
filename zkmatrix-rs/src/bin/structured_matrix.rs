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

#[path = "../manifest.rs"]
mod manifest;
use manifest::{ClaimManifest, Operation, Orientation};

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

/// SRS window layout for one matmul claim `C = A B` with `A: rows x inner`,
/// `B: inner x cols`, `C: rows x cols` (all dimensions powers of two).
/// `off_*` are absolute SRS exponent offsets; a chain of claims stacks
/// layouts at disjoint offsets via `layout_at` so no two base families in a
/// claim DAG share an SRS window (required by the equality-gadget soundness
/// argument, see docs/zkmatrix-poc/CLAIM_MANIFEST.md).
#[derive(Clone)]
struct Layout {
    rows: usize,
    inner: usize,
    cols: usize,
    a_len: usize,
    b_len: usize,
    c_len: usize,
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
    /// SHA-256 over the protocol version, parameters and the SRS-defining
    /// elements (`tau*G`, `tau*H`, `u`, `blind`). Absorbed into every
    /// Fiat-Shamir challenge so proofs are bound to one specific setup.
    digest: [u8; 32],
    /// Prepared pairing inputs, computed once per SRS: `H` and `tau*H`.
    /// Every KZG check uses the same two G2 points once rewritten to the
    /// fixed-G2 form (see `KzgBatch`), so preparation is hoisted here.
    h_prepared: G2Prepared,
    tau_g2_prepared: G2Prepared,
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
    ay_commit: G1Projective,
    by_commit: G1Projective,
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
        /// Fresh decoupling challenge scaling the projected (output) family.
        sep: Scalar,
    },
    BProjection {
        y: Scalar,
        sep: Scalar,
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
        sep: Scalar,
    },
    BatchBProjection {
        y: Scalar,
        rho: Scalar,
        batch: usize,
        sep: Scalar,
    },
    BatchProduct {
        rho: Scalar,
        batch: usize,
    },
    /// Commitment-equality gadget: knowledge of an opening of
    /// `C_left - C_right` over the difference family
    /// `{P(off_left + i) - P(off_right + i)}`.
    Equality {
        off_left: usize,
        off_right: usize,
        len: usize,
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

fn layout_at(base: usize, rows: usize, inner: usize, cols: usize) -> Layout {
    assert!(rows.is_power_of_two());
    assert!(inner.is_power_of_two());
    assert!(cols.is_power_of_two());
    let a_len = rows * inner;
    let b_len = inner * cols;
    let c_len = rows * cols;
    let off_ay = base;
    let off_by = off_ay + inner;
    let off_a = off_by + inner;
    let off_b = off_a + a_len;
    let off_c = off_b + b_len;
    let srs_len = off_c + c_len;
    Layout {
        rows,
        inner,
        cols,
        a_len,
        b_len,
        c_len,
        off_a,
        off_b,
        off_c,
        off_ay,
        off_by,
        srs_len,
    }
}

fn layout(n: usize) -> Layout {
    layout_at(0, n, n, n)
}

fn make_srs(srs_len: usize, tau: Scalar) -> StructuredSrs {
    let generator = G1Projective::generator();
    // Powers of tau in parallel chunks: each chunk seeds itself with
    // tau^start and walks sequentially inside. Output is identical to the
    // serial loop; only the schedule changes.
    const SRS_CHUNK: usize = 4096;
    let mut powers = vec![G1Projective::identity(); srs_len];
    powers
        .par_chunks_mut(SRS_CHUNK)
        .enumerate()
        .for_each(|(chunk_index, chunk)| {
            let mut cur = scalar_pow_usize(tau, chunk_index * SRS_CHUNK);
            for slot in chunk.iter_mut() {
                *slot = generator * cur;
                cur *= tau;
            }
        });
    let tau_g2 = G2Projective::generator() * tau;
    let u = hash_to_basis(b"matrix-u", 0);
    let blind = hash_to_basis(b"matrix-blind", 0);
    let mut hasher = Sha256::new();
    hasher.update(b"zkmatrix-structured-srs-digest-v3");
    hasher.update((srs_len as u64).to_le_bytes());
    hasher.update(powers[1].to_affine().to_compressed());
    hasher.update(tau_g2.to_affine().to_compressed());
    hasher.update(u.to_affine().to_compressed());
    hasher.update(blind.to_affine().to_compressed());
    let digest: [u8; 32] = hasher.finalize().into();
    let h_prepared = G2Prepared::from(G2Projective::generator().to_affine());
    let tau_g2_prepared = G2Prepared::from(tau_g2.to_affine());
    StructuredSrs {
        powers,
        tau_g2,
        u,
        blind,
        digest,
        h_prepared,
        tau_g2_prepared,
    }
}

/// Deferred batch verification of KZG openings.
///
/// Each opening check `e(C - v*G, H) = e(W, tau*H - zeta*H)` is equivalent
/// to the fixed-G2 form `e(C - v*G + zeta*W, H) = e(W, tau*H)`. Checks are
/// accumulated with fresh verifier-local random weights r_i:
///
///   e(sum r_i (C_i - v_i G + zeta_i W_i), H) = e(sum r_i W_i, tau*H)
///
/// which is one 2-Miller-loop pairing check for the whole proof (or batch),
/// sound up to the negligible probability that a random combination of
/// nonzero errors cancels.
struct KzgBatch {
    acc_lhs: G1Projective,
    acc_witness: G1Projective,
    rng: ProofRng,
    any: bool,
}

impl KzgBatch {
    fn new() -> Self {
        KzgBatch {
            acc_lhs: G1Projective::identity(),
            acc_witness: G1Projective::identity(),
            rng: proof_rng(),
            any: false,
        }
    }

    fn push(
        &mut self,
        commitment: G1Projective,
        value: Scalar,
        witness: G1Projective,
        zeta: Scalar,
    ) {
        let weight = scalar_from_proof_rng(&mut self.rng);
        let lhs = commitment - G1Projective::generator() * value + witness * zeta;
        self.acc_lhs += lhs * weight;
        self.acc_witness += witness * weight;
        self.any = true;
    }

    fn finish(&self, srs: &StructuredSrs) -> bool {
        if !self.any {
            return false;
        }
        let lhs_affine = self.acc_lhs.to_affine();
        let neg_witness_affine = (-self.acc_witness).to_affine();
        Bls12::multi_miller_loop(&[
            (&lhs_affine, &srs.h_prepared),
            (&neg_witness_affine, &srs.tau_g2_prepared),
        ])
        .final_exponentiation()
            == Gt::identity()
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

/// Combined projection spec with the output family scaled by the fresh
/// decoupling challenge `sep` (paper Algorithms 2-3: `x * C_out (+) C_in`).
fn a_projection_spec(
    layout: &Layout,
    idx: usize,
    yl: &[Scalar],
    scale: Scalar,
    sep: Scalar,
) -> BasisSpec {
    // A is rows x inner: idx = i * inner + j.
    let i = idx / layout.inner;
    let j = idx % layout.inner;
    vec![
        Term {
            offset: layout.off_a + idx,
            coeff: scale,
        },
        Term {
            offset: layout.off_ay + j,
            coeff: scale * sep * yl[i],
        },
    ]
}

fn b_projection_spec(
    layout: &Layout,
    idx: usize,
    yr: &[Scalar],
    scale: Scalar,
    sep: Scalar,
) -> BasisSpec {
    // B is inner x cols: idx = i * cols + j.
    let i = idx / layout.cols;
    let j = idx % layout.cols;
    vec![
        Term {
            offset: layout.off_b + idx,
            coeff: scale,
        },
        Term {
            offset: layout.off_by + i,
            coeff: scale * sep * yr[j],
        },
    ]
}

/// Combined difference specs for the commitment-equality gadget: entry `i`
/// is `P(off_left + i) - P(off_right + i)`. A vector `X` opens the
/// difference of two commitments to `X` under the two (disjoint) windows.
fn equality_spec(off_left: usize, off_right: usize, len: usize) -> Vec<BasisSpec> {
    (0..len)
        .map(|i| {
            vec![
                Term {
                    offset: off_left + i,
                    coeff: Scalar::ONE,
                },
                Term {
                    offset: off_right + i,
                    coeff: -Scalar::ONE,
                },
            ]
        })
        .collect()
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

/// C = A B with A rows x inner, B inner x cols, both row-major flat.
fn matmul(a: &[Scalar], b: &[Scalar], rows: usize, inner: usize, cols: usize) -> Vec<Scalar> {
    let mut c = vec![Scalar::ZERO; rows * cols];
    c.par_chunks_mut(cols).enumerate().for_each(|(i, row)| {
        for k in 0..inner {
            let aik = a[i * inner + k];
            for j in 0..cols {
                row[j] += aik * b[k * cols + j];
            }
        }
    });
    c
}

fn random_values(len: usize, rng: &mut u64) -> Vec<Scalar> {
    (0..len)
        .map(|_| Scalar::from(splitmix64(rng) % 64))
        .collect()
}

fn make_witness(layout: &Layout, seed: u64) -> Witness {
    let mut rng = seed;
    let a = random_values(layout.a_len, &mut rng);
    let b = random_values(layout.b_len, &mut rng);
    let c = matmul(&a, &b, layout.rows, layout.inner, layout.cols);
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

fn shape_bytes(layout: &Layout) -> [u8; 24] {
    let mut out = [0u8; 24];
    out[..8].copy_from_slice(&(layout.rows as u64).to_le_bytes());
    out[8..16].copy_from_slice(&(layout.inner as u64).to_le_bytes());
    out[16..].copy_from_slice(&(layout.cols as u64).to_le_bytes());
    out
}

fn challenge_statement(digest: &[u8; 32], layout: &Layout, statement: &Statement) -> Scalar {
    let dims = shape_bytes(layout);
    let a = statement.a_commit.to_affine().to_compressed();
    let b = statement.b_commit.to_affine().to_compressed();
    let c = statement.c_commit.to_affine().to_compressed();
    hash_to_scalar(&[digest, &dims, &a, &b, &c])
}

fn challenge_commitments(
    digest: &[u8; 32],
    domain: u64,
    layout: &Layout,
    statement: &Statement,
    commitments: &[G1Projective],
) -> Scalar {
    let mut owned = Vec::with_capacity(6 + commitments.len());
    owned.push(digest.to_vec());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push(shape_bytes(layout).to_vec());
    owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

/// Fresh decoupling challenge separating the combined sub-proof commitments
/// (paper Algorithms 2-3). Sampled after every commitment and response blind
/// entering the combined commitment is fixed in the transcript.
fn challenge_decouple(
    digest: &[u8; 32],
    domain: u64,
    layout: &Layout,
    statement: &Statement,
    commitments: &[G1Projective],
    scalars: &[Scalar],
) -> Scalar {
    let mut owned = Vec::with_capacity(6 + commitments.len() + scalars.len());
    owned.push(digest.to_vec());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push(shape_bytes(layout).to_vec());
    owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
    owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    for scalar in scalars {
        owned.push(scalar.to_bytes_le().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn challenge_batch_commitments(
    digest: &[u8; 32],
    domain: u64,
    layout: &Layout,
    statements: &[Statement],
    commitments: &[G1Projective],
) -> Scalar {
    let mut owned = Vec::with_capacity(4 + 3 * statements.len() + commitments.len());
    owned.push(digest.to_vec());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push(shape_bytes(layout).to_vec());
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

fn challenge_batch_decouple(
    digest: &[u8; 32],
    domain: u64,
    layout: &Layout,
    statements: &[Statement],
    commitments: &[G1Projective],
    scalars: &[Scalar],
) -> Scalar {
    let mut owned =
        Vec::with_capacity(4 + 3 * statements.len() + commitments.len() + scalars.len());
    owned.push(digest.to_vec());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push(shape_bytes(layout).to_vec());
    owned.push((statements.len() as u64).to_le_bytes().to_vec());
    for statement in statements {
        owned.push(statement.a_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.b_commit.to_affine().to_compressed().to_vec());
        owned.push(statement.c_commit.to_affine().to_compressed().to_vec());
    }
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    for scalar in scalars {
        owned.push(scalar.to_bytes_le().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

fn challenge_ip(
    digest: &[u8; 32],
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
        digest,
        &domain_bytes,
        &round_bytes,
        &current_bytes,
        &scalar_bytes,
        &left_bytes,
        &right_bytes,
    ])
}

fn ipa_challenges(
    digest: &[u8; 32],
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
        let x = challenge_ip(digest, domain, round, current, scalar_base, left, right);
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

/// Closed-form evaluation of the folded coefficient polynomial for a
/// row-major matrix window of shape `2^row_bits x 2^col_bits`: for index
/// `idx = i * 2^col_bits + j`, the first `row_bits` IPA rounds select the
/// bits of `i` (contribution `row_base^i`) and the remaining `col_bits`
/// rounds select the bits of `j` (contribution `col_base^j`).
fn split_matrix_eval(
    challenges: &[Scalar],
    row_bits: usize,
    col_bits: usize,
    row_base: Scalar,
    col_base: Scalar,
    inverse: bool,
) -> Scalar {
    debug_assert_eq!(challenges.len(), row_bits + col_bits);
    let mut acc = Scalar::ONE;
    for r in 0..row_bits {
        let x = if inverse {
            challenges[r].invert().unwrap()
        } else {
            challenges[r]
        };
        let stride = 1usize << (row_bits - 1 - r);
        acc *= Scalar::ONE + x * scalar_pow_usize(row_base, stride);
    }
    for r in 0..col_bits {
        let idx = row_bits + r;
        let x = if inverse {
            challenges[idx].invert().unwrap()
        } else {
            challenges[idx]
        };
        let stride = 1usize << (col_bits - 1 - r);
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

fn kzg_challenge(
    digest: &[u8; 32],
    commitment: G1Projective,
    proof: &IpProof,
    domain: u64,
) -> Scalar {
    let mut owned = Vec::with_capacity(5 + 2 * proof.left.len());
    owned.push(digest.to_vec());
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

fn active_polynomial_len(coeffs: &[Scalar]) -> usize {
    coeffs
        .iter()
        .rposition(|coeff| !bool::from(coeff.is_zero()))
        .map(|idx| (idx + 1).max(2))
        .unwrap_or(2)
}

fn formula_value(
    layout: &Layout,
    kind: FormulaKind,
    proof: &IpProof,
    challenges: &[Scalar],
    zeta: Scalar,
) -> Scalar {
    // A is rows x inner (yl entries are (y^cols)^i), B is inner x cols
    // (yr entries are y^j); the ay/by windows have length inner.
    let row_bits = layout.rows.trailing_zeros() as usize;
    let inner_bits = layout.inner.trailing_zeros() as usize;
    let col_bits = layout.cols.trailing_zeros() as usize;
    match kind {
        FormulaKind::CProjection { .. } => {
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_c)
                * fold_eval(challenges, zeta, layout.c_len, false)
        }
        FormulaKind::AProjection { y, sep } => {
            let base = scalar_pow_usize(zeta, layout.off_a)
                * fold_eval(challenges, zeta, layout.a_len, false);
            let projected = sep
                * scalar_pow_usize(zeta, layout.off_ay)
                * split_matrix_eval(
                    challenges,
                    row_bits,
                    inner_bits,
                    scalar_pow_usize(y, layout.cols),
                    zeta,
                    false,
                );
            proof.a_final * (base + projected)
        }
        FormulaKind::BProjection { y, sep } => {
            let base = scalar_pow_usize(zeta, layout.off_b)
                * fold_eval(challenges, zeta, layout.b_len, false);
            let projected = sep
                * scalar_pow_usize(zeta, layout.off_by)
                * split_matrix_eval(challenges, inner_bits, col_bits, zeta, y, false);
            proof.a_final * (base + projected)
        }
        FormulaKind::Product => {
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_ay)
                * fold_eval(challenges, zeta, layout.inner, false)
                + proof.b_final
                    * scalar_pow_usize(zeta, layout.off_by)
                    * fold_eval(challenges, zeta, layout.inner, true)
        }
        FormulaKind::BatchCProjection { rho, batch, .. } => {
            let batch_bits = batch.trailing_zeros() as usize;
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_c)
                * batch_eval(&challenges[..batch_bits], batch, rho, false)
                * fold_eval(&challenges[batch_bits..], zeta, layout.c_len, false)
        }
        FormulaKind::BatchAProjection { y, rho, batch, sep } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let batch_part = batch_eval(&challenges[..batch_bits], batch, rho, false);
            let matrix_challenges = &challenges[batch_bits..];
            let base = scalar_pow_usize(zeta, layout.off_a)
                * fold_eval(matrix_challenges, zeta, layout.a_len, false);
            let projected = sep
                * scalar_pow_usize(zeta, layout.off_ay)
                * split_matrix_eval(
                    matrix_challenges,
                    row_bits,
                    inner_bits,
                    scalar_pow_usize(y, layout.cols),
                    zeta,
                    false,
                );
            proof.a_final * batch_part * (base + projected)
        }
        FormulaKind::BatchBProjection { y, rho, batch, sep } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let batch_part = batch_eval(&challenges[..batch_bits], batch, rho, false);
            let matrix_challenges = &challenges[batch_bits..];
            let base = scalar_pow_usize(zeta, layout.off_b)
                * fold_eval(matrix_challenges, zeta, layout.b_len, false);
            let projected = sep
                * scalar_pow_usize(zeta, layout.off_by)
                * split_matrix_eval(matrix_challenges, inner_bits, col_bits, zeta, y, false);
            proof.a_final * batch_part * (base + projected)
        }
        FormulaKind::BatchProduct { rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            let vector_challenges = &challenges[batch_bits..];
            proof.a_final
                * scalar_pow_usize(zeta, layout.off_ay)
                * batch_eval(&challenges[..batch_bits], batch, rho, false)
                * fold_eval(vector_challenges, zeta, layout.inner, false)
                + proof.b_final
                    * scalar_pow_usize(zeta, layout.off_by)
                    * batch_eval(&challenges[..batch_bits], batch, Scalar::ONE, true)
                    * fold_eval(vector_challenges, zeta, layout.inner, true)
        }
        FormulaKind::Equality {
            off_left,
            off_right,
            len,
        } => {
            proof.a_final
                * (scalar_pow_usize(zeta, off_left) - scalar_pow_usize(zeta, off_right))
                * fold_eval(challenges, zeta, len, false)
        }
    }
}

fn expected_public_b_final(
    layout: &Layout,
    kind: FormulaKind,
    challenges: &[Scalar],
) -> Option<Scalar> {
    match kind {
        FormulaKind::CProjection { y } => Some(fold_eval(challenges, y, layout.c_len, false)),
        FormulaKind::BatchCProjection { y, rho, batch } => {
            let batch_bits = batch.trailing_zeros() as usize;
            Some(
                batch_eval(&challenges[..batch_bits], batch, rho, false)
                    * fold_eval(&challenges[batch_bits..], y, layout.c_len, false),
            )
        }
        _ => None,
    }
}

fn expected_proof_len(layout: &Layout, kind: FormulaKind) -> usize {
    match kind {
        FormulaKind::CProjection { .. } => layout.c_len,
        FormulaKind::AProjection { .. } => layout.a_len,
        FormulaKind::BProjection { .. } => layout.b_len,
        FormulaKind::Product => layout.inner,
        FormulaKind::BatchCProjection { batch, .. } => batch * layout.c_len,
        FormulaKind::BatchAProjection { batch, .. } => batch * layout.a_len,
        FormulaKind::BatchBProjection { batch, .. } => batch * layout.b_len,
        FormulaKind::BatchProduct { batch, .. } => batch * layout.inner,
        FormulaKind::Equality { len, .. } => len,
    }
}

fn prove_ip_structured(
    srs: &StructuredSrs,
    digest: &[u8; 32],
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
        let x = challenge_ip(digest, domain, round, current, scalar_base, left, right);
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
    let (challenges, _) = ipa_challenges(digest, commitment, scalar_base, &proof, domain);
    let mut poly = vec![Scalar::ZERO; srs.powers.len()];
    let g_fold = fold_coefficients(&challenges, proof_n, false);
    add_terms_to_poly(&mut poly, g_specs, &g_fold, proof.a_final);
    if let Some(specs) = h_specs {
        let h_fold = fold_coefficients(&challenges, proof_n, true);
        add_terms_to_poly(&mut poly, specs, &h_fold, proof.b_final);
    }
    let zeta = kzg_challenge(digest, commitment, &proof, domain ^ 0x5EC7_0001);
    let active_len = active_polynomial_len(&poly);
    let quotient = quotient_coefficients(&poly[..active_len], zeta);
    proof.kzg_witness = msm(&srs.powers[..quotient.len()], &quotient);
    proof
}

fn verify_ip_fast(
    _srs: &StructuredSrs,
    digest: &[u8; 32],
    layout: &Layout,
    commitment: G1Projective,
    scalar_base: G1Projective,
    proof: &IpProof,
    domain: u64,
    formula: FormulaKind,
    kzg: &mut KzgBatch,
) -> bool {
    if proof.n != expected_proof_len(layout, formula) || !proof.n.is_power_of_two() {
        return false;
    }
    if proof.left.len() != proof.n.trailing_zeros() as usize
        || proof.right.len() != proof.left.len()
    {
        return false;
    }
    let (challenges, current) = ipa_challenges(digest, commitment, scalar_base, proof, domain);
    if let Some(expected_b_final) = expected_public_b_final(layout, formula, &challenges) {
        if proof.b_final != expected_b_final {
            return false;
        }
    }
    let folded_commitment = current - scalar_base * (proof.a_final * proof.b_final);
    let zeta = kzg_challenge(digest, commitment, proof, domain ^ 0x5EC7_0001);
    let value = formula_value(layout, formula, proof, &challenges, zeta);
    // The pairing check is deferred: all openings of one verification call
    // aggregate into a single 2-Miller-loop check (KzgBatch::finish).
    kzg.push(folded_commitment, value, proof.kzg_witness, zeta);
    true
}

fn projections(
    layout: &Layout,
    digest: &[u8; 32],
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
    let y = challenge_statement(digest, layout, statement);
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
    let yvec = powers(y, layout.c_len);
    let yr = powers(y, layout.cols);
    let yl: Vec<_> = (0..layout.rows).map(|i| yvec[i * layout.cols]).collect();
    let ay = project_a(layout, &witness.a, &yl);
    let by = project_b(layout, &witness.b, &yr);
    let d = dot(&witness.c, &yvec);
    (yvec, yl, yr, ay, by, d)
}

/// ay = y_L^T A: A is rows x inner, output length inner.
fn project_a(layout: &Layout, values: &[Scalar], yl: &[Scalar]) -> Vec<Scalar> {
    (0..layout.inner)
        .into_par_iter()
        .map(|j| {
            let mut acc = Scalar::ZERO;
            for i in 0..layout.rows {
                acc += yl[i] * values[i * layout.inner + j];
            }
            acc
        })
        .collect()
}

/// by = B y_R: B is inner x cols, output length inner.
fn project_b(layout: &Layout, values: &[Scalar], yr: &[Scalar]) -> Vec<Scalar> {
    values
        .par_chunks(layout.cols)
        .map(|row| dot(row, yr))
        .collect()
}

fn core_decoupling_challenges(
    layout: &Layout,
    digest: &[u8; 32],
    statement: &Statement,
    d: Scalar,
    ay_commit: G1Projective,
    by_commit: G1Projective,
) -> (Scalar, Scalar, Scalar, Scalar) {
    let commits = [ay_commit, by_commit];
    let scalars = [d];
    let xc = challenge_decouple(digest, 0x5EC1, layout, statement, &commits, &scalars);
    let xa = challenge_decouple(digest, 0x5EC2, layout, statement, &commits, &scalars);
    let xb = challenge_decouple(digest, 0x5EC3, layout, statement, &commits, &scalars);
    let xp = challenge_decouple(digest, 0x5EC4, layout, statement, &commits, &scalars);
    (xc, xa, xb, xp)
}

fn prove_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
    statement: &Statement,
    witness: &Witness,
) -> MatrixProof {
    let (_y, yvec, yl, yr, ay, by, d) = projections(layout, digest, statement, witness);
    let ay_specs: Vec<_> = (0..layout.inner).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.inner).map(|i| by_spec(layout, i)).collect();
    let ay_commit = commit_specs(srs, &ay_specs, &ay);
    let by_commit = commit_specs(srs, &by_specs, &by);
    // Fresh decoupling challenges, sampled after d/ay/by are determined.
    let (xc, xa, xb, xp) =
        core_decoupling_challenges(layout, digest, statement, d, ay_commit, by_commit);
    let c_specs: Vec<_> = (0..layout.c_len).map(|idx| c_spec(layout, idx)).collect();
    let a_proj_specs: Vec<_> = (0..layout.a_len)
        .map(|idx| a_projection_spec(layout, idx, &yl, Scalar::ONE, xa))
        .collect();
    let b_proj_specs: Vec<_> = (0..layout.b_len)
        .map(|idx| b_projection_spec(layout, idx, &yr, Scalar::ONE, xb))
        .collect();
    let c_proj = prove_ip_structured(
        srs,
        digest,
        statement.c_commit + srs.u * (xc * d),
        srs.u * xc,
        &c_specs,
        None,
        &witness.c,
        Some(&yvec),
        0xC001,
    );
    let a_proj = prove_ip_structured(
        srs,
        digest,
        statement.a_commit + ay_commit * xa,
        G1Projective::identity(),
        &a_proj_specs,
        None,
        &witness.a,
        None,
        0xA002,
    );
    let b_proj = prove_ip_structured(
        srs,
        digest,
        statement.b_commit + by_commit * xb,
        G1Projective::identity(),
        &b_proj_specs,
        None,
        &witness.b,
        None,
        0xB003,
    );
    let product = prove_ip_structured(
        srs,
        digest,
        srs.u * (xp * d) + ay_commit + by_commit,
        srs.u * xp,
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
    digest: &[u8; 32],
    statement: &Statement,
    proof: &MatrixProof,
) -> bool {
    let y = challenge_statement(digest, layout, statement);
    let (xc, xa, xb, xp) = core_decoupling_challenges(
        layout,
        digest,
        statement,
        proof.d,
        proof.ay_commit,
        proof.by_commit,
    );
    let mut kzg = KzgBatch::new();
    let ok = verify_ip_fast(
        srs,
        digest,
        layout,
        statement.c_commit + srs.u * (xc * proof.d),
        srs.u * xc,
        &proof.c_proj,
        0xC001,
        FormulaKind::CProjection { y },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        digest,
        layout,
        statement.a_commit + proof.ay_commit * xa,
        G1Projective::identity(),
        &proof.a_proj,
        0xA002,
        FormulaKind::AProjection { y, sep: xa },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        digest,
        layout,
        statement.b_commit + proof.by_commit * xb,
        G1Projective::identity(),
        &proof.b_proj,
        0xB003,
        FormulaKind::BProjection { y, sep: xb },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        digest,
        layout,
        srs.u * (xp * proof.d) + proof.ay_commit + proof.by_commit,
        srs.u * xp,
        &proof.product,
        0xD004,
        FormulaKind::Product,
        &mut kzg,
    );
    ok && kzg.finish(srs)
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
    digest: &[u8; 32],
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
        digest,
        domain,
        layout,
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
    let xs = challenge_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statement,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
        &[response_blind, projected_response_blind],
    );
    let proof = prove_ip_structured(
        srs,
        digest,
        masked_input + masked_output * xs,
        output_base * xs,
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
    digest: &[u8; 32],
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    public_y: Scalar,
    public_values: &[Scalar],
    input_specs: &[BasisSpec],
    output_base: G1Projective,
    proof: &ZkProjectionProof,
    domain: u64,
    kzg: &mut KzgBatch,
) -> bool {
    let x = challenge_commitments(
        digest,
        domain,
        layout,
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
    let xs = challenge_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statement,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
        &[proof.response_blind, proof.projected_response_blind],
    );
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked_input + masked_output * xs,
        output_base * xs,
        &proof.proof,
        domain ^ 0x9999,
        FormulaKind::CProjection { y: public_y },
        kzg,
    ) && proof.proof.n == public_values.len()
        && proof.proof.n == input_specs.len()
}

fn projection_specs_with_sep(
    layout: &Layout,
    coeffs: &[Scalar],
    axis_rows: bool,
    sep: Scalar,
) -> Vec<BasisSpec> {
    let len = if axis_rows { layout.a_len } else { layout.b_len };
    (0..len)
        .map(|idx| {
            if axis_rows {
                a_projection_spec(layout, idx, coeffs, Scalar::ONE, sep)
            } else {
                b_projection_spec(layout, idx, coeffs, Scalar::ONE, sep)
            }
        })
        .collect()
}

fn prove_zk_projection(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    coeffs: &[Scalar],
    input_specs: &[BasisSpec],
    output_specs: &[BasisSpec],
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
        digest,
        domain,
        layout,
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
    let xs = challenge_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statement,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
        &[response_blind, projected_response_blind],
    );
    let projected_specs = projection_specs_with_sep(layout, coeffs, axis_rows, xs);
    let proof = prove_ip_structured(
        srs,
        digest,
        masked_input + masked_output * xs,
        G1Projective::identity(),
        &projected_specs,
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
    digest: &[u8; 32],
    statement: &Statement,
    input_commit: G1Projective,
    output_commit: G1Projective,
    y: Scalar,
    axis_rows: bool,
    proof: &ZkProjectionProof,
    domain: u64,
    kzg: &mut KzgBatch,
) -> bool {
    let x = challenge_commitments(
        digest,
        domain,
        layout,
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
    let xs = challenge_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statement,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
        &[proof.response_blind, proof.projected_response_blind],
    );
    let formula = if axis_rows {
        FormulaKind::AProjection { y, sep: xs }
    } else {
        FormulaKind::BProjection { y, sep: xs }
    };
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked_input + masked_output * xs,
        G1Projective::identity(),
        &proof.proof,
        domain ^ 0x8888,
        formula,
        kzg,
    ) && proof.proof.n == if axis_rows { layout.a_len } else { layout.b_len }
}

fn prove_zk_product(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
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
    let mut alpha = random_scalars(layout.inner, rng);
    let mut beta = random_scalars(layout.inner, rng);
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
        digest,
        0xD0D0,
        layout,
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
    let xs = challenge_decouple(
        digest,
        0xD0D0 ^ 0x5EC0,
        layout,
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
        &[
            left_response_blind,
            right_response_blind,
            output_response_blind,
        ],
    );
    let proof = prove_ip_structured(
        srs,
        digest,
        masked_output * xs + masked_left + masked_right,
        srs.u * xs,
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
    digest: &[u8; 32],
    statement: &Statement,
    output_commit: G1Projective,
    left_commit: G1Projective,
    right_commit: G1Projective,
    proof: &ZkProductProof,
    kzg: &mut KzgBatch,
) -> bool {
    let x = challenge_commitments(
        digest,
        0xD0D0,
        layout,
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
    let xs = challenge_decouple(
        digest,
        0xD0D0 ^ 0x5EC0,
        layout,
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
        &[
            proof.left_response_blind,
            proof.right_response_blind,
            proof.output_response_blind,
        ],
    );
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked_output * xs + masked_left + masked_right,
        srs.u * xs,
        &proof.proof,
        0xD0D1,
        FormulaKind::Product,
        kzg,
    )
}

fn prove_zk_public_ip_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
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
        digest,
        domain,
        layout,
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
    let xs = challenge_batch_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statements,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
        &[response_blind, projected_response_blind],
    );
    let proof = prove_ip_structured(
        srs,
        digest,
        masked_input + masked_output * xs,
        output_base * xs,
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
    digest: &[u8; 32],
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    output_base: G1Projective,
    proof: &ZkProjectionProof,
    domain: u64,
    formula: FormulaKind,
    kzg: &mut KzgBatch,
) -> bool {
    let x = challenge_batch_commitments(
        digest,
        domain,
        layout,
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
    let xs = challenge_batch_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statements,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
        &[proof.response_blind, proof.projected_response_blind],
    );
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked_input + masked_output * xs,
        output_base * xs,
        &proof.proof,
        domain ^ 0x9999,
        formula,
        kzg,
    )
}

fn prove_zk_projection_batch(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    input_values: &[Scalar],
    coeffs: &[Scalar],
    input_specs: &[BasisSpec],
    output_specs: &[BasisSpec],
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
        digest,
        domain,
        layout,
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
    let xs = challenge_batch_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statements,
        &[
            input_commit,
            output_commit,
            mask_commit,
            projected_mask_commit,
        ],
        &[response_blind, projected_response_blind],
    );
    let projected_specs = projection_specs_with_sep(layout, coeffs, axis_rows, xs);
    let proof = prove_ip_structured(
        srs,
        digest,
        masked_input + masked_output * xs,
        G1Projective::identity(),
        &projected_specs,
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
    digest: &[u8; 32],
    statements: &[Statement],
    input_commit: G1Projective,
    output_commit: G1Projective,
    y: Scalar,
    axis_rows: bool,
    proof: &ZkProjectionProof,
    domain: u64,
    kzg: &mut KzgBatch,
) -> bool {
    let x = challenge_batch_commitments(
        digest,
        domain,
        layout,
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
    let xs = challenge_batch_decouple(
        digest,
        domain ^ 0x5EC0,
        layout,
        statements,
        &[
            input_commit,
            output_commit,
            proof.mask_commit,
            proof.projected_mask_commit,
        ],
        &[proof.response_blind, proof.projected_response_blind],
    );
    let formula = if axis_rows {
        FormulaKind::AProjection { y, sep: xs }
    } else {
        FormulaKind::BProjection { y, sep: xs }
    };
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked_input + masked_output * xs,
        G1Projective::identity(),
        &proof.proof,
        domain ^ 0x8888,
        formula,
        kzg,
    )
}

fn prove_zk_matrix(
    layout: &Layout,
    srs: &StructuredSrs,
    digest: &[u8; 32],
    statement: &Statement,
    witness: &Witness,
    rng: &mut ProofRng,
) -> ZkMatrixProof {
    let (_y, yvec, yl, yr, ay, by, d) = projections(layout, digest, statement, witness);
    let c_specs: Vec<_> = (0..layout.c_len).map(|idx| c_spec(layout, idx)).collect();
    let a_specs: Vec<_> = (0..layout.a_len).map(|idx| a_spec(layout, idx)).collect();
    let b_specs: Vec<_> = (0..layout.b_len).map(|idx| b_spec(layout, idx)).collect();
    let ay_specs: Vec<_> = (0..layout.inner).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.inner).map(|i| by_spec(layout, i)).collect();
    let d_blind = scalar_from_proof_rng(rng);
    let ay_blind = scalar_from_proof_rng(rng);
    let by_blind = scalar_from_proof_rng(rng);
    let d_commit = srs.u * d + srs.blind * d_blind;
    let ay_commit = commit_window(srs, layout.off_ay, &ay, ay_blind);
    let by_commit = commit_window(srs, layout.off_by, &by, by_blind);
    let c_proj = prove_zk_public_ip(
        layout,
        srs,
        digest,
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
        digest,
        statement,
        statement.a_commit,
        ay_commit,
        &witness.a,
        &yl,
        &a_specs,
        &ay_specs,
        witness.a_blind,
        ay_blind,
        true,
        0xA102,
        rng,
    );
    let b_proj = prove_zk_projection(
        layout,
        srs,
        digest,
        statement,
        statement.b_commit,
        by_commit,
        &witness.b,
        &yr,
        &b_specs,
        &by_specs,
        witness.b_blind,
        by_blind,
        false,
        0xB103,
        rng,
    );
    let product = prove_zk_product(
        layout, srs, digest, statement, d_commit, ay_commit, by_commit, &ay, &by, d_blind,
        ay_blind, by_blind, &ay_specs, &by_specs, rng,
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
    digest: &[u8; 32],
    statement: &Statement,
    proof: &ZkMatrixProof,
) -> bool {
    let y = challenge_statement(digest, layout, statement);
    let yvec = powers(y, layout.c_len);
    let c_specs: Vec<_> = (0..layout.c_len).map(|idx| c_spec(layout, idx)).collect();
    let mut kzg = KzgBatch::new();
    let ok = verify_zk_public_ip(
        layout,
        srs,
        digest,
        statement,
        statement.c_commit,
        proof.d_commit,
        y,
        &yvec,
        &c_specs,
        srs.u,
        &proof.c_proj,
        0xC101,
        &mut kzg,
    ) && verify_zk_projection(
        layout,
        srs,
        digest,
        statement,
        statement.a_commit,
        proof.ay_commit,
        y,
        true,
        &proof.a_proj,
        0xA102,
        &mut kzg,
    ) && verify_zk_projection(
        layout,
        srs,
        digest,
        statement,
        statement.b_commit,
        proof.by_commit,
        y,
        false,
        &proof.b_proj,
        0xB103,
        &mut kzg,
    ) && verify_zk_product(
        layout,
        srs,
        digest,
        statement,
        proof.d_commit,
        proof.ay_commit,
        proof.by_commit,
        &proof.product,
        &mut kzg,
    );
    ok && kzg.finish(srs)
}

fn self_test() {
    // Square regression shapes plus rectangular (rows, inner, cols) shapes.
    let shapes = [(2usize, 2usize, 2usize), (4, 4, 4), (8, 8, 8), (16, 32, 8), (8, 16, 64)];
    for (rows, inner, cols) in shapes {
        let n = rows + 3 * inner + 7 * cols; // seed diversifier
        let layout = layout_at(0, rows, inner, cols);
        let mut rng = 0x5775_1000 + n as u64;
        let tau = scalar_from_rng(&mut rng);
        let srs = make_srs(layout.srs_len, tau);
        let witness = make_witness(&layout, 0xA11CE + n as u64);
        let core_statement = statement(&layout, &srs, &witness);
        let mut proof = prove_matrix(&layout, &srs, &srs.digest, &core_statement, &witness);
        assert!(verify_matrix(&layout, &srs, &srs.digest, &core_statement, &proof));
        proof.c_proj.b_final += Scalar::ONE;
        assert!(!verify_matrix(&layout, &srs, &srs.digest, &core_statement, &proof));

        let mut bad_witness = make_witness(&layout, 0xBAD0 + n as u64);
        bad_witness.c[0] += Scalar::ONE;
        let bad_statement = statement(&layout, &srs, &bad_witness);
        let bad_proof = prove_matrix(&layout, &srs, &srs.digest, &bad_statement, &bad_witness);
        assert!(!verify_matrix(&layout, &srs, &srs.digest, &bad_statement, &bad_proof));

        let mut zk_witness = make_witness(&layout, 0xC0FFEE + n as u64);
        let mut zk_rng = proof_rng();
        let zk_stmt = zk_statement(&layout, &srs, &mut zk_witness, &mut zk_rng);
        let mut zk_proof = prove_zk_matrix(
            &layout,
            &srs,
            &srs.digest,
            &zk_stmt,
            &zk_witness,
            &mut zk_rng,
        );
        assert!(verify_zk_matrix(&layout, &srs, &srs.digest, &zk_stmt, &zk_proof));
        zk_proof.c_proj.proof.b_final += Scalar::ONE;
        assert!(!verify_zk_matrix(&layout, &srs, &srs.digest, &zk_stmt, &zk_proof));

        let mut bad_zk_witness = make_witness(&layout, 0xDEAD + n as u64);
        bad_zk_witness.c[0] += Scalar::ONE;
        let bad_zk_statement = zk_statement(&layout, &srs, &mut bad_zk_witness, &mut zk_rng);
        let bad_zk_proof = prove_zk_matrix(
            &layout,
            &srs,
            &srs.digest,
            &bad_zk_statement,
            &bad_zk_witness,
            &mut zk_rng,
        );
        assert!(!verify_zk_matrix(
            &layout,
            &srs,
            &srs.digest,
            &bad_zk_statement,
            &bad_zk_proof
        ));

        let mut batch_witnesses: Vec<_> = (0..2)
            .map(|i| make_witness(&layout, 0xB47C0 + n as u64 + i as u64))
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
            .map(|i| make_witness(&layout, 0xAB47C0 + n as u64 + i as u64))
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

        // Cross-instance swap attack: exchanging per-instance commitments
        // between instances i and j after rho was derived must fail, even if
        // the prover updates the claimed rho to match the swapped ordering.
        let mut swap_witnesses: Vec<_> = (0..2)
            .map(|i| make_witness(&layout, 0x5A4B_C0 + n as u64 + i as u64))
            .collect();
        let swap_statements: Vec<_> = swap_witnesses
            .iter_mut()
            .map(|w| zk_statement(&layout, &srs, w, &mut zk_rng))
            .collect();
        let mut swap_proof = prove_zk_batch(
            &layout,
            &srs,
            &swap_statements,
            &swap_witnesses,
            &mut zk_rng,
        );
        assert!(verify_zk_batch(&layout, &srs, &swap_statements, &swap_proof));
        swap_proof.ay_commits.swap(0, 1);
        assert!(!verify_zk_batch(
            &layout,
            &srs,
            &swap_statements,
            &swap_proof
        ));
        swap_proof.rho = challenge_batch_rho(
            &srs.digest,
            &swap_statements,
            &layout,
            &swap_proof.d_commits,
            &swap_proof.ay_commits,
            &swap_proof.by_commits,
        );
        assert!(!verify_zk_batch(
            &layout,
            &srs,
            &swap_statements,
            &swap_proof
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
    equality_self_test();
    println!("structured-matrix self-test ok");
}

fn bench(mode: &str, n: usize) {
    let layout = layout(n);
    let mut rng = 0x5775_2000 + n as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(layout.srs_len, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witness = make_witness(&layout, 0xBEEF + n as u64);
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
        let proof = prove_zk_matrix(&layout, &srs, &srs.digest, &statement, &witness, &mut zk_rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk_matrix(&layout, &srs, &srs.digest, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    } else {
        let proof = prove_matrix(&layout, &srs, &srs.digest, &statement, &witness);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_matrix(&layout, &srs, &srs.digest, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    };
    println!("{mode},{n},{setup_s:.9},{commit_s:.9},{prove_s:.9},{verify_s:.9},{verified}");
}

fn batch_challenges(digest: &[u8; 32], statements: &[Statement], layout: &Layout) -> (Scalar, Scalar) {
    let n_bytes = shape_bytes(layout);
    let mut owned = vec![
        digest.to_vec(),
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

fn challenge_batch_y(digest: &[u8; 32], statements: &[Statement], layout: &Layout) -> Scalar {
    let n_bytes = shape_bytes(layout);
    let mut owned = vec![
        b"batch-y-alg6".to_vec(),
        digest.to_vec(),
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
    digest: &[u8; 32],
    statements: &[Statement],
    layout: &Layout,
    d_commits: &[G1Projective],
    ay_commits: &[G1Projective],
    by_commits: &[G1Projective],
) -> Scalar {
    assert_eq!(statements.len(), d_commits.len());
    assert_eq!(statements.len(), ay_commits.len());
    assert_eq!(statements.len(), by_commits.len());
    let n_bytes = shape_bytes(layout);
    let mut owned = Vec::with_capacity(4 + 6 * statements.len());
    owned.push(b"batch-rho-alg6".to_vec());
    owned.push(digest.to_vec());
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

fn batch_decoupling_challenges(
    layout: &Layout,
    digest: &[u8; 32],
    statements: &[Statement],
    d: Scalar,
    ay_commit: G1Projective,
    by_commit: G1Projective,
) -> (Scalar, Scalar, Scalar, Scalar) {
    let commits = [ay_commit, by_commit];
    let scalars = [d];
    let xc = challenge_batch_decouple(digest, 0x5EC1, layout, statements, &commits, &scalars);
    let xa = challenge_batch_decouple(digest, 0x5EC2, layout, statements, &commits, &scalars);
    let xb = challenge_batch_decouple(digest, 0x5EC3, layout, statements, &commits, &scalars);
    let xp = challenge_batch_decouple(digest, 0x5EC4, layout, statements, &commits, &scalars);
    (xc, xa, xb, xp)
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
    let (y, rho) = batch_challenges(&srs.digest, statements, layout);
    let rho_powers = powers(rho, batch);
    let (yvec, yl, yr, _, _, _) = projections_with_y(layout, &witnesses[0], y);
    let ay_specs: Vec<_> = (0..layout.inner).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.inner).map(|i| by_spec(layout, i)).collect();

    // Pass 1: per-instance projections and the rho-weighted aggregates that
    // the decoupling challenges must bind.
    let mut ay_all = Vec::with_capacity(batch);
    let mut by_all = Vec::with_capacity(batch);
    let mut d_weighted = Scalar::ZERO;
    let mut ay_commit_weighted = G1Projective::identity();
    let mut by_commit_weighted = G1Projective::identity();
    for (witness, &rho_i) in witnesses.iter().zip(rho_powers.iter()) {
        let (_, _, _, ay, by, d) = projections_with_y(layout, witness, y);
        let ay_commit = commit_specs(srs, &ay_specs, &ay);
        let by_commit = commit_specs(srs, &by_specs, &by);
        d_weighted += rho_i * d;
        ay_commit_weighted += ay_commit * rho_i;
        by_commit_weighted += by_commit * rho_i;
        ay_all.push(ay);
        by_all.push(by);
    }
    let (xc, xa, xb, xp) = batch_decoupling_challenges(
        layout,
        &srs.digest,
        statements,
        d_weighted,
        ay_commit_weighted,
        by_commit_weighted,
    );

    // Pass 2: concatenated batched vectors; the decoupling challenges are
    // baked into the projection specs. The three matrix windows have
    // independent lengths for rectangular shapes.
    let mut c_values = Vec::with_capacity(batch * layout.c_len);
    let mut c_public = Vec::with_capacity(batch * layout.c_len);
    let mut c_specs = Vec::with_capacity(batch * layout.c_len);
    let mut a_values = Vec::with_capacity(batch * layout.a_len);
    let mut a_specs = Vec::with_capacity(batch * layout.a_len);
    let mut b_values = Vec::with_capacity(batch * layout.b_len);
    let mut b_specs = Vec::with_capacity(batch * layout.b_len);
    let mut product_a = Vec::with_capacity(batch * layout.inner);
    let mut product_b = Vec::with_capacity(batch * layout.inner);
    let mut product_g_specs = Vec::with_capacity(batch * layout.inner);
    let mut product_h_specs = Vec::with_capacity(batch * layout.inner);
    for ((witness, &rho_i), (ay, by)) in witnesses
        .iter()
        .zip(rho_powers.iter())
        .zip(ay_all.iter().zip(by_all.iter()))
    {
        for idx in 0..layout.c_len {
            c_values.push(witness.c[idx]);
            c_public.push(rho_i * yvec[idx]);
            c_specs.push(vec![Term {
                offset: layout.off_c + idx,
                coeff: rho_i,
            }]);
        }
        for idx in 0..layout.a_len {
            a_values.push(witness.a[idx]);
            a_specs.push(a_projection_spec(layout, idx, &yl, rho_i, xa));
        }
        for idx in 0..layout.b_len {
            b_values.push(witness.b[idx]);
            b_specs.push(b_projection_spec(layout, idx, &yr, rho_i, xb));
        }
        for j in 0..layout.inner {
            product_a.push(ay[j]);
            product_b.push(rho_i * by[j]);
            product_g_specs.push(vec![Term {
                offset: layout.off_ay + j,
                coeff: rho_i,
            }]);
            product_h_specs.push(by_spec(layout, j));
        }
    }
    let (a_input_commit, b_input_commit, c_input_commit) =
        batch_input_commitments(statements, &rho_powers);
    let c_lhs = c_input_commit + srs.u * (xc * d_weighted);
    let a_lhs = a_input_commit + ay_commit_weighted * xa;
    let b_lhs = b_input_commit + by_commit_weighted * xb;
    let product_lhs = srs.u * (xp * d_weighted) + ay_commit_weighted + by_commit_weighted;
    let c_proj = prove_ip_structured(
        srs,
        &srs.digest,
        c_lhs,
        srs.u * xc,
        &c_specs,
        None,
        &c_values,
        Some(&c_public),
        0xC101,
    );
    let a_proj = prove_ip_structured(
        srs,
        &srs.digest,
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
        &srs.digest,
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
        &srs.digest,
        product_lhs,
        srs.u * xp,
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
        ay_commit: ay_commit_weighted,
        by_commit: by_commit_weighted,
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
    let y = challenge_batch_y(&srs.digest, statements, layout);
    let (yvec, yl, yr, _, _, _) = projections_with_y(layout, &witnesses[0], y);

    let c_specs: Vec<_> = (0..layout.c_len).map(|idx| c_spec(layout, idx)).collect();
    let a_specs: Vec<_> = (0..layout.a_len).map(|idx| a_spec(layout, idx)).collect();
    let b_specs: Vec<_> = (0..layout.b_len).map(|idx| b_spec(layout, idx)).collect();
    let ay_specs: Vec<_> = (0..layout.inner).map(|j| ay_spec(layout, j)).collect();
    let by_specs: Vec<_> = (0..layout.inner).map(|i| by_spec(layout, i)).collect();

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

    let rho = challenge_batch_rho(
        &srs.digest,
        statements,
        layout,
        &d_commits,
        &ay_commits,
        &by_commits,
    );
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

    let mut a_values = vec![Scalar::ZERO; layout.a_len];
    let mut b_values = vec![Scalar::ZERO; layout.b_len];
    let mut c_values = vec![Scalar::ZERO; layout.c_len];
    for (witness, &rho_i) in witnesses.iter().zip(rho_powers.iter()) {
        for idx in 0..layout.a_len {
            a_values[idx] += rho_i * witness.a[idx];
        }
        for idx in 0..layout.b_len {
            b_values[idx] += rho_i * witness.b[idx];
        }
        for idx in 0..layout.c_len {
            c_values[idx] += rho_i * witness.c[idx];
        }
    }

    let c_proj = prove_zk_public_ip_batch(
        layout,
        srs,
        &srs.digest,
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
        &srs.digest,
        statements,
        a_input_commit,
        ay_commit,
        &a_values,
        &yl,
        &a_specs,
        &ay_specs,
        a_input_blind,
        ay_blind,
        true,
        0xA202,
        rng,
    );
    let b_proj = prove_zk_projection_batch(
        layout,
        srs,
        &srs.digest,
        statements,
        b_input_commit,
        by_commit,
        &b_values,
        &yr,
        &b_specs,
        &by_specs,
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
                &srs.digest,
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
    let (y, rho) = batch_challenges(&srs.digest, statements, layout);
    if proof.y != y || proof.rho != rho {
        return false;
    }
    let rho_powers = powers(rho, batch);
    let (a_input_commit, b_input_commit, c_input_commit) =
        batch_input_commitments(statements, &rho_powers);
    let (xc, xa, xb, xp) = batch_decoupling_challenges(
        layout,
        &srs.digest,
        statements,
        proof.d,
        proof.ay_commit,
        proof.by_commit,
    );
    let c_lhs = c_input_commit + srs.u * (xc * proof.d);
    let a_lhs = a_input_commit + proof.ay_commit * xa;
    let b_lhs = b_input_commit + proof.by_commit * xb;
    let product_lhs = srs.u * (xp * proof.d) + proof.ay_commit + proof.by_commit;
    let mut kzg = KzgBatch::new();
    let ok = verify_ip_fast(
        srs,
        &srs.digest,
        layout,
        c_lhs,
        srs.u * xc,
        &proof.c_proj,
        0xC101,
        FormulaKind::BatchCProjection {
            y: proof.y,
            rho: proof.rho,
            batch,
        },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        &srs.digest,
        layout,
        a_lhs,
        G1Projective::identity(),
        &proof.a_proj,
        0xA102,
        FormulaKind::BatchAProjection {
            y: proof.y,
            rho: proof.rho,
            batch,
            sep: xa,
        },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        &srs.digest,
        layout,
        b_lhs,
        G1Projective::identity(),
        &proof.b_proj,
        0xB103,
        FormulaKind::BatchBProjection {
            y: proof.y,
            rho: proof.rho,
            batch,
            sep: xb,
        },
        &mut kzg,
    ) && verify_ip_fast(
        srs,
        &srs.digest,
        layout,
        product_lhs,
        srs.u * xp,
        &proof.product,
        0xD104,
        FormulaKind::BatchProduct {
            rho: proof.rho,
            batch,
        },
        &mut kzg,
    );
    ok && kzg.finish(srs)
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
    let y = challenge_batch_y(&srs.digest, statements, layout);
    let rho = challenge_batch_rho(
        &srs.digest,
        statements,
        layout,
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
    let mut kzg = KzgBatch::new();
    let ok = verify_zk_public_ip_batch(
        layout,
        srs,
        &srs.digest,
        statements,
        c_input_commit,
        d_commit,
        srs.u,
        &proof.c_proj,
        0xC201,
        FormulaKind::CProjection { y },
        &mut kzg,
    ) && verify_zk_projection_batch(
        layout,
        srs,
        &srs.digest,
        statements,
        a_input_commit,
        ay_commit,
        y,
        true,
        &proof.a_proj,
        0xA202,
        &mut kzg,
    ) && verify_zk_projection_batch(
        layout,
        srs,
        &srs.digest,
        statements,
        b_input_commit,
        by_commit,
        y,
        false,
        &proof.b_proj,
        0xB203,
        &mut kzg,
    ) && (0..batch).all(|idx| {
        verify_zk_product(
            layout,
            srs,
            &srs.digest,
            &statements[idx],
            proof.d_commits[idx],
            proof.ay_commits[idx],
            proof.by_commits[idx],
            &proof.products[idx],
            &mut kzg,
        )
    });
    ok && kzg.finish(srs)
}

fn bench_batch(mode: &str, n: usize, batch: usize) {
    assert!(batch.is_power_of_two());
    let layout = layout(n);
    let mut rng = 0x5775_3000 + n as u64 + batch as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(layout.srs_len, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witnesses: Vec<_> = (0..batch)
        .map(|i| make_witness(&layout, 0xCAFE + n as u64 + 17 * i as u64))
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

fn bench_batch_with_data(
    mode: &str,
    layout: &Layout,
    srs: &StructuredSrs,
    witnesses: &mut [Witness],
    batch: usize,
    setup_s: f64,
) {
    let mut zk_rng = proof_rng();
    let start = Instant::now();
    let statements: Vec<_> = if mode == "zk" {
        witnesses[..batch]
            .iter_mut()
            .map(|w| zk_statement(layout, srs, w, &mut zk_rng))
            .collect()
    } else {
        witnesses[..batch]
            .iter()
            .map(|w| statement(layout, srs, w))
            .collect()
    };
    let commit_s = start.elapsed().as_secs_f64();
    let start = Instant::now();
    let (batch_prove_s, batch_verify_s, verified) = if mode == "zk" {
        let proof = prove_zk_batch(layout, srs, &statements, &witnesses[..batch], &mut zk_rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk_batch(layout, srs, &statements, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    } else {
        let proof = prove_batch(layout, srs, &statements, &witnesses[..batch]);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_batch(layout, srs, &statements, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    };
    println!(
        "{mode},{},{batch},{setup_s:.9},{commit_s:.9},{batch_prove_s:.9},{:.9},{batch_verify_s:.9},{:.9},{verified}",
        layout.rows,
        batch_prove_s / batch as f64,
        batch_verify_s / batch as f64,
    );
}

fn bench_batch_series(mode: &str, n: usize, batches: &[usize]) {
    assert!(!batches.is_empty());
    for &batch in batches {
        assert!(batch.is_power_of_two());
    }
    let max_batch = *batches.iter().max().unwrap();
    let layout = layout(n);
    let mut rng = 0x5775_3000 + n as u64 + max_batch as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(layout.srs_len, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witnesses: Vec<_> = (0..max_batch)
        .map(|i| make_witness(&layout, 0xCAFE + n as u64 + 17 * i as u64))
        .collect();
    for &batch in batches {
        bench_batch_with_data(mode, &layout, &srs, &mut witnesses, batch, setup_s);
    }
}

// ---------------------------------------------------------------------------
// Commitment-equality gadget (M1 layer chaining).
//
// Statement: `left_commit` (a blinded commitment to X over the SRS window
// starting at `off_left`) and `right_commit` (a blinded commitment to X
// over the disjoint window starting at `off_right`) open to the same
// vector. The prover shows knowledge of an opening of the difference
// `D = C_left - C_right` over the difference family
// `{P(off_left + i) - P(off_right + i)}` plus the blind base, using the
// same masked-IPA machinery as the projection sub-proofs: a random mask
// vector alpha is committed, the challenge `x` (derived after both linked
// commitments and the mask commitment are in the transcript) folds the
// witness as `X + x * alpha`, the response blind strips the Pedersen
// blinds, and the IPA plus Section 3 KZG opening prove the masked
// commitment opens over the difference family. Soundness: extractors for
// the neighbouring sub-proofs yield openings X_left (over window off_left)
// and X_right (over window off_right); combined with the difference
// opening X~, the exponent identity
//   sum_i (X_left[i] - X~[i]) tau^{off_left+i}
//     - sum_i (X_right[i] - X~[i]) tau^{off_right+i} + (b_l - b_r - b~) s
// must vanish. With the two windows disjoint and the blind base
// independent (hash-to-curve), a nonzero coefficient is a nontrivial
// discrete-log relation over the SRS (AGM / q-SDH), so X_left = X~ =
// X_right. There is no combination of two independently-opened
// commitments here (D is a single derived commitment), so no additional
// decoupling scalar beyond the mask challenge `x` is required.

struct ZkEqualityProof {
    mask_commit: G1Projective,
    response_blind: Scalar,
    proof: IpProof,
}

const EQUALITY_DOMAIN: u64 = 0xE901;

fn challenge_equality(
    digest: &[u8; 32],
    domain: u64,
    off_left: usize,
    off_right: usize,
    len: usize,
    commitments: &[G1Projective],
) -> Scalar {
    let mut owned = Vec::with_capacity(6 + commitments.len());
    owned.push(b"equality-gadget-v1".to_vec());
    owned.push(digest.to_vec());
    owned.push(domain.to_le_bytes().to_vec());
    owned.push((off_left as u64).to_le_bytes().to_vec());
    owned.push((off_right as u64).to_le_bytes().to_vec());
    owned.push((len as u64).to_le_bytes().to_vec());
    for commitment in commitments {
        owned.push(commitment.to_affine().to_compressed().to_vec());
    }
    let refs: Vec<&[u8]> = owned.iter().map(Vec::as_slice).collect();
    hash_to_scalar(&refs)
}

#[allow(clippy::too_many_arguments)]
fn prove_zk_equality(
    srs: &StructuredSrs,
    digest: &[u8; 32],
    left_commit: G1Projective,
    right_commit: G1Projective,
    values: &[Scalar],
    left_blind: Scalar,
    right_blind: Scalar,
    off_left: usize,
    off_right: usize,
    rng: &mut ProofRng,
) -> ZkEqualityProof {
    let len = values.len();
    assert!(len.is_power_of_two());
    let specs = equality_spec(off_left, off_right, len);
    let mut alpha = random_scalars(len, rng);
    let alpha_blind = scalar_from_proof_rng(rng);
    let mask_commit = commit_specs_blinded(srs, &specs, &alpha, alpha_blind);
    // The mask challenge binds the setup digest (through `digest`), the
    // window offsets and both linked commitments before it is drawn.
    let x = challenge_equality(
        digest,
        EQUALITY_DOMAIN,
        off_left,
        off_right,
        len,
        &[left_commit, right_commit, mask_commit],
    );
    let response_blind = left_blind - right_blind + x * alpha_blind;
    mask_values(values, &mut alpha, x);
    let masked = left_commit - right_commit + mask_commit * x - srs.blind * response_blind;
    let proof = prove_ip_structured(
        srs,
        digest,
        masked,
        G1Projective::identity(),
        &specs,
        None,
        &alpha,
        None,
        EQUALITY_DOMAIN ^ 0x7777,
    );
    ZkEqualityProof {
        mask_commit,
        response_blind,
        proof,
    }
}

#[allow(clippy::too_many_arguments)]
fn verify_zk_equality(
    srs: &StructuredSrs,
    digest: &[u8; 32],
    layout: &Layout,
    left_commit: G1Projective,
    right_commit: G1Projective,
    off_left: usize,
    off_right: usize,
    len: usize,
    proof: &ZkEqualityProof,
    kzg: &mut KzgBatch,
) -> bool {
    if !len.is_power_of_two() {
        return false;
    }
    let x = challenge_equality(
        digest,
        EQUALITY_DOMAIN,
        off_left,
        off_right,
        len,
        &[left_commit, right_commit, proof.mask_commit],
    );
    let masked =
        left_commit - right_commit + proof.mask_commit * x - srs.blind * proof.response_blind;
    verify_ip_fast(
        srs,
        digest,
        layout,
        masked,
        G1Projective::identity(),
        &proof.proof,
        EQUALITY_DOMAIN ^ 0x7777,
        FormulaKind::Equality {
            off_left,
            off_right,
            len,
        },
        kzg,
    )
}

/// Stand-alone equality gadget checks: valid case, mismatched vector,
/// tampered scalar/blind, swapped commitment.
fn equality_self_test() {
    let rows = 4usize;
    let inner = 8usize;
    let cols = 16usize;
    let layout1 = layout_at(0, rows, inner, cols);
    let layout2 = layout_at(layout1.srs_len, rows, cols, 2);
    let mut rng = 0xE0_1000u64;
    let tau = scalar_from_rng(&mut rng);
    let srs = make_srs(layout2.srs_len, tau);
    let mut zk_rng = proof_rng();
    let y = random_values(rows * cols, &mut rng);
    let left_blind = scalar_from_proof_rng(&mut zk_rng);
    let right_blind = scalar_from_proof_rng(&mut zk_rng);
    let left = commit_window(&srs, layout1.off_c, &y, left_blind);
    let right = commit_window(&srs, layout2.off_a, &y, right_blind);
    let proof = prove_zk_equality(
        &srs,
        &srs.digest,
        left,
        right,
        &y,
        left_blind,
        right_blind,
        layout1.off_c,
        layout2.off_a,
        &mut zk_rng,
    );
    let run = |proof: &ZkEqualityProof, left: G1Projective, right: G1Projective| -> bool {
        let mut kzg = KzgBatch::new();
        verify_zk_equality(
            &srs,
            &srs.digest,
            &layout1,
            left,
            right,
            layout1.off_c,
            layout2.off_a,
            y.len(),
            proof,
            &mut kzg,
        ) && kzg.finish(&srs)
    };
    assert!(run(&proof, left, right), "equality valid");
    // A different committed vector on the right must fail.
    let mut y2 = y.clone();
    y2[0] += Scalar::ONE;
    let right_bad = commit_window(&srs, layout2.off_a, &y2, right_blind);
    let bad_proof = prove_zk_equality(
        &srs,
        &srs.digest,
        left,
        right_bad,
        &y,
        left_blind,
        right_blind,
        layout1.off_c,
        layout2.off_a,
        &mut zk_rng,
    );
    assert!(!run(&bad_proof, left, right_bad), "equality mismatch fails");
    // Tampered final scalar.
    let tampered = ZkEqualityProof {
        mask_commit: proof.mask_commit,
        response_blind: proof.response_blind,
        proof: IpProof {
            a_final: proof.proof.a_final + Scalar::ONE,
            ..proof.proof.clone()
        },
    };
    assert!(!run(&tampered, left, right), "equality tampered a_final fails");
    // Tampered response blind.
    let tampered_blind = ZkEqualityProof {
        mask_commit: proof.mask_commit,
        response_blind: proof.response_blind + Scalar::ONE,
        proof: proof.proof.clone(),
    };
    assert!(!run(&tampered_blind, left, right), "equality tampered blind fails");
    // Swapped/wrong commitment.
    assert!(!run(&proof, right, left), "equality swapped commitments fail");
}

fn bench_rect(mode: &str, rows: usize, inner: usize, cols: usize) {
    let layout = layout_at(0, rows, inner, cols);
    let mut rng = 0x5775_4000 + (rows + 3 * inner + 7 * cols) as u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(layout.srs_len, tau);
    let setup_s = start.elapsed().as_secs_f64();
    let mut witness = make_witness(&layout, 0xBEEF);
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
        let proof = prove_zk_matrix(&layout, &srs, &srs.digest, &statement, &witness, &mut zk_rng);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_zk_matrix(&layout, &srs, &srs.digest, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    } else {
        let proof = prove_matrix(&layout, &srs, &srs.digest, &statement, &witness);
        let prove_s = start.elapsed().as_secs_f64();
        let start = Instant::now();
        let verified = verify_matrix(&layout, &srs, &srs.digest, &statement, &proof);
        (prove_s, start.elapsed().as_secs_f64(), verified)
    };
    println!(
        "{mode},{rows}x{inner}x{cols},{setup_s:.9},{commit_s:.9},{prove_s:.9},{verify_s:.9},{verified}"
    );
}

// ---------------------------------------------------------------------------
// Chained-inference demo (M1): Z = (X W1) W2 over one shared SRS with two
// disjoint claim layouts. Y = X W1 is committed once under claim 1's C
// window and once under claim 2's A window; the commitment-equality gadget
// links the two. All Fiat-Shamir challenges bind the claim-manifest digest,
// which covers every commitment in the DAG (the transcript-ordering rule of
// docs/zkmatrix-poc/CLAIM_MANIFEST.md).

fn chain_demo(rows: usize, k: usize, m1: usize, m2: usize) {
    println!(
        "structured chain-demo: X {rows}x{k}, W1 {k}x{m1}, W2 {m1}x{m2} (BLS12-381 zk track)"
    );
    let layout1 = layout_at(0, rows, k, m1);
    let layout2 = layout_at(layout1.srs_len, rows, m1, m2);
    let mut rng = 0x5775_5000u64;
    let tau = scalar_from_rng(&mut rng);
    let start = Instant::now();
    let srs = make_srs(layout2.srs_len, tau);
    println!(
        "  srs: {} powers, {:.3}s",
        layout2.srs_len,
        start.elapsed().as_secs_f64()
    );

    // Witnesses: Z = (X W1) W2.
    let x = random_values(layout1.a_len, &mut rng);
    let w1 = random_values(layout1.b_len, &mut rng);
    let y = matmul(&x, &w1, rows, k, m1);
    let w2 = random_values(layout2.b_len, &mut rng);
    let z = matmul(&y, &w2, rows, m1, m2);

    // Commitments; Y is committed under both windows with independent
    // blinds.
    let mut zk_rng = proof_rng();
    let start = Instant::now();
    let x_blind = scalar_from_proof_rng(&mut zk_rng);
    let w1_blind = scalar_from_proof_rng(&mut zk_rng);
    let y_c_blind = scalar_from_proof_rng(&mut zk_rng);
    let y_a_blind = scalar_from_proof_rng(&mut zk_rng);
    let w2_blind = scalar_from_proof_rng(&mut zk_rng);
    let z_blind = scalar_from_proof_rng(&mut zk_rng);
    let x_commit = commit_window(&srs, layout1.off_a, &x, x_blind);
    let w1_commit = commit_window(&srs, layout1.off_b, &w1, w1_blind);
    let y_commit_c = commit_window(&srs, layout1.off_c, &y, y_c_blind);
    let y_commit_a = commit_window(&srs, layout2.off_a, &y, y_a_blind);
    let w2_commit = commit_window(&srs, layout2.off_b, &w2, w2_blind);
    let z_commit = commit_window(&srs, layout2.off_c, &z, z_blind);
    println!("  commit: {:.3}s", start.elapsed().as_secs_f64());

    // Claim manifest: every commitment enters the statement hash before
    // any challenge is derived; the digest seeds every transcript.
    let build_manifest = |y_a: G1Projective, z_c: G1Projective| -> ClaimManifest {
        let mut m = ClaimManifest::new("structured-bls12381", &srs.digest);
        let entries = [
            ("X", rows, k, layout1.off_a, x_commit),
            ("W1", k, m1, layout1.off_b, w1_commit),
            ("Y", rows, m1, layout1.off_c, y_commit_c),
            ("Y", rows, m1, layout2.off_a, y_a),
            ("W2", m1, m2, layout2.off_b, w2_commit),
            ("Z", rows, m2, layout2.off_c, z_c),
        ];
        let mut ids = Vec::new();
        for (label, r, c, offset, commitment) in entries {
            ids.push(m.add_commitment(
                label,
                r,
                c,
                Orientation::RowMajor,
                (offset as u64).to_le_bytes().to_vec(),
                commitment.to_affine().to_compressed().to_vec(),
            ));
        }
        m.add_operation(Operation::Matmul {
            a: ids[0],
            b: ids[1],
            c: ids[2],
        });
        m.add_operation(Operation::LinkEqual {
            left: ids[2],
            right: ids[3],
        });
        m.add_operation(Operation::Matmul {
            a: ids[3],
            b: ids[4],
            c: ids[5],
        });
        m
    };
    let manifest = build_manifest(y_commit_a, z_commit);
    let ctx = manifest.digest();

    let stmt1 = Statement {
        a_commit: x_commit,
        b_commit: w1_commit,
        c_commit: y_commit_c,
    };
    let wit1 = Witness {
        a: x.clone(),
        b: w1.clone(),
        c: y.clone(),
        a_blind: x_blind,
        b_blind: w1_blind,
        c_blind: y_c_blind,
    };
    let stmt2 = Statement {
        a_commit: y_commit_a,
        b_commit: w2_commit,
        c_commit: z_commit,
    };
    let wit2 = Witness {
        a: y.clone(),
        b: w2.clone(),
        c: z.clone(),
        a_blind: y_a_blind,
        b_blind: w2_blind,
        c_blind: z_blind,
    };

    let start = Instant::now();
    let proof1 = prove_zk_matrix(&layout1, &srs, &ctx, &stmt1, &wit1, &mut zk_rng);
    let proof2 = prove_zk_matrix(&layout2, &srs, &ctx, &stmt2, &wit2, &mut zk_rng);
    let link = prove_zk_equality(
        &srs,
        &ctx,
        y_commit_c,
        y_commit_a,
        &y,
        y_c_blind,
        y_a_blind,
        layout1.off_c,
        layout2.off_a,
        &mut zk_rng,
    );
    println!(
        "  prove (2 claims + link): {:.3}s",
        start.elapsed().as_secs_f64()
    );

    // Verify: the verifier only handles commitments; Y's commitment is
    // shared between the claims and never re-committed.
    let verify_link = |ctx: &[u8; 32],
                       left: G1Projective,
                       right: G1Projective,
                       proof: &ZkEqualityProof|
     -> bool {
        let mut kzg = KzgBatch::new();
        verify_zk_equality(
            &srs,
            ctx,
            &layout1,
            left,
            right,
            layout1.off_c,
            layout2.off_a,
            y.len(),
            proof,
            &mut kzg,
        ) && kzg.finish(&srs)
    };
    let start = Instant::now();
    let ok1 = verify_zk_matrix(&layout1, &srs, &ctx, &stmt1, &proof1);
    let ok2 = verify_zk_matrix(&layout2, &srs, &ctx, &stmt2, &proof2);
    let okl = verify_link(&ctx, y_commit_c, y_commit_a, &link);
    println!(
        "  verify: {:.3}s (claim1={ok1} claim2={ok2} link={okl})",
        start.elapsed().as_secs_f64()
    );
    assert!(ok1 && ok2 && okl, "honest chain must verify");

    // Negative case 1: substitute a different Y in the second claim. Both
    // matmul claims verify against their own statements; the equality link
    // must reject the chain.
    let mut y2 = y.clone();
    y2[0] += Scalar::ONE;
    let z2 = matmul(&y2, &w2, rows, m1, m2);
    let y2_commit_a = commit_window(&srs, layout2.off_a, &y2, y_a_blind);
    let z2_commit = commit_window(&srs, layout2.off_c, &z2, z_blind);
    let manifest2 = build_manifest(y2_commit_a, z2_commit);
    let ctx2 = manifest2.digest();
    let stmt2b = Statement {
        a_commit: y2_commit_a,
        b_commit: w2_commit,
        c_commit: z2_commit,
    };
    let wit2b = Witness {
        a: y2.clone(),
        b: w2.clone(),
        c: z2,
        a_blind: y_a_blind,
        b_blind: w2_blind,
        c_blind: z_blind,
    };
    let proof1b = prove_zk_matrix(&layout1, &srs, &ctx2, &stmt1, &wit1, &mut zk_rng);
    let proof2b = prove_zk_matrix(&layout2, &srs, &ctx2, &stmt2b, &wit2b, &mut zk_rng);
    // The cheating prover does not know an opening of the difference; it
    // proves with the honest Y anyway.
    let link_bad = prove_zk_equality(
        &srs,
        &ctx2,
        y_commit_c,
        y2_commit_a,
        &y,
        y_c_blind,
        y_a_blind,
        layout1.off_c,
        layout2.off_a,
        &mut zk_rng,
    );
    assert!(
        verify_zk_matrix(&layout1, &srs, &ctx2, &stmt1, &proof1b),
        "substituted-Y chain: claim 1 verifies standalone"
    );
    assert!(
        verify_zk_matrix(&layout2, &srs, &ctx2, &stmt2b, &proof2b),
        "substituted-Y chain: claim 2 verifies standalone"
    );
    assert!(
        !verify_link(&ctx2, y_commit_c, y2_commit_a, &link_bad),
        "substituted-Y chain: equality link must fail"
    );
    println!("  negative wrong-Y: claims pass standalone, link fails as required");

    // Negative case 2: tampered link responses.
    let tampered = ZkEqualityProof {
        mask_commit: link.mask_commit,
        response_blind: link.response_blind,
        proof: IpProof {
            a_final: link.proof.a_final + Scalar::ONE,
            ..link.proof.clone()
        },
    };
    assert!(
        !verify_link(&ctx, y_commit_c, y_commit_a, &tampered),
        "tampered link a_final must fail"
    );
    let tampered_blind = ZkEqualityProof {
        mask_commit: link.mask_commit,
        response_blind: link.response_blind + Scalar::ONE,
        proof: link.proof.clone(),
    };
    assert!(
        !verify_link(&ctx, y_commit_c, y_commit_a, &tampered_blind),
        "tampered link blind must fail"
    );

    // Negative case 3: swapped commitments handed to the link verifier.
    assert!(
        !verify_link(&ctx, w1_commit, y_commit_a, &link),
        "wrong left commitment in link must fail"
    );

    // Negative case 4: manifest reordering. Same commitments, different
    // order => different context digest => every proof fails against it.
    let mut reordered = manifest.clone();
    reordered.commitments.swap(0, 1);
    let ctx_reordered = reordered.digest();
    assert_ne!(ctx, ctx_reordered, "reordered manifest digest must differ");
    assert!(
        !verify_zk_matrix(&layout1, &srs, &ctx_reordered, &stmt1, &proof1),
        "claim proof must not verify under a reordered manifest"
    );
    assert!(
        !verify_link(&ctx_reordered, y_commit_c, y_commit_a, &link),
        "link proof must not verify under a reordered manifest"
    );
    println!("structured chain-demo ok");
}

fn usage() {
    eprintln!("usage:");
    eprintln!("  structured_matrix self-test");
    eprintln!("  structured_matrix bench <core|zk|both> <n> [n...]");
    eprintln!("  structured_matrix bench-batch <core|zk> <n> <batch_power_of_two>");
    eprintln!("  structured_matrix bench-batch-series <core|zk> <n> <batch_power_of_two>...");
    eprintln!("  structured_matrix bench-rect <core|zk> <rows> <inner> <cols>");
    eprintln!("  structured_matrix chain-demo [rows k m1 m2]   (default 16 32 64 8)");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        usage();
        std::process::exit(1);
    }
    match args[1].as_str() {
        "self-test" => self_test(),
        "chain-demo" => {
            let dims: Vec<usize> = args[2..].iter().map(|a| a.parse().unwrap()).collect();
            match dims.len() {
                0 => chain_demo(16, 32, 64, 8),
                4 => chain_demo(dims[0], dims[1], dims[2], dims[3]),
                _ => {
                    usage();
                    std::process::exit(1);
                }
            }
        }
        "bench-rect" => {
            if args.len() != 6 {
                usage();
                std::process::exit(1);
            }
            let mode = args[2].as_str();
            if mode != "core" && mode != "zk" {
                usage();
                std::process::exit(1);
            }
            let rows: usize = args[3].parse().unwrap();
            let inner: usize = args[4].parse().unwrap();
            let cols: usize = args[5].parse().unwrap();
            println!("mode,shape,setup_s,commit_s,prove_s,verify_s,verified");
            bench_rect(mode, rows, inner, cols);
        }
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
        "bench-batch-series" => {
            if args.len() < 5 {
                usage();
                std::process::exit(1);
            }
            let mode = args[2].as_str();
            if mode != "core" && mode != "zk" {
                usage();
                std::process::exit(1);
            }
            let n: usize = args[3].parse().unwrap();
            let batches: Vec<usize> = args[4..].iter().map(|arg| arg.parse().unwrap()).collect();
            println!(
                "mode,n,batch,setup_s,commit_s,batch_prove_s,prove_per_claim_s,batch_verify_s,verify_per_claim_s,verified"
            );
            bench_batch_series(mode, n, &batches);
        }
        _ => {
            usage();
            std::process::exit(1);
        }
    }
}
