// Route R commitment layer (U2): BDLOP-style module commitment over R_q,
//   com(x; rho) = (A1 rho, A2 rho + x),
// A1 in R^{kappa x N_r}, A2 in R^{msg_r x N_r}, rho ternary in R^{N_r},
// with per-CRS cached A1 aux-NTT kernel paths (regime-dispatched; every A1
// path is bit-identical mod q to the schoolbook oracle — asserted by the
// self-test battery) and the derived-key combination helper the Pi2/gadget
// statements use.
//
// CRS expansion keeps the per-element XOF discipline of Route Z; the CRS
// hash binds (q, kappa, N_r, msg_r, seed) and enters every statement hash.

use super::aux::{self, A1CommitKernel, A1GemmKernel, NttTables, build_tables};
use super::{D, Poly, RingCtx, XofReader, crt_split, poly_add, ring_matvec_small_g};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CommitShape {
    pub kappa: usize,
    pub n_r: usize,
    pub msg_r: usize,
}

pub struct RingCrs {
    pub shape: CommitShape,
    pub q: u64,
    pub a1: Vec<Poly>, // kappa x n_r, row-major
    pub a2: Vec<Poly>, // msg_r x n_r, row-major
    pub crs_hash: [u8; 32],
}

pub fn expand_crs(shape: CommitShape, q: u64, seed: u64) -> RingCrs {
    let mut reader = XofReader::new(
        "crs-A1A2",
        &[
            &seed.to_le_bytes(),
            &q.to_le_bytes(),
            &(shape.kappa as u64).to_le_bytes(),
            &(shape.n_r as u64).to_le_bytes(),
            &(shape.msg_r as u64).to_le_bytes(),
        ],
    );
    let mut sample = |count: usize| -> Vec<Poly> {
        (0..count).map(|_| (0..D).map(|_| reader.next_field(q)).collect()).collect()
    };
    let a1 = sample(shape.kappa * shape.n_r);
    let a2 = sample(shape.msg_r * shape.n_r);
    let mut hasher = sha2::Sha256::new();
    use sha2::Digest;
    hasher.update(b"route-r-crs");
    hasher.update(seed.to_le_bytes());
    hasher.update(q.to_le_bytes());
    hasher.update((shape.kappa as u64).to_le_bytes());
    hasher.update((shape.n_r as u64).to_le_bytes());
    hasher.update((shape.msg_r as u64).to_le_bytes());
    RingCrs { shape, q, a1, a2, crs_hash: hasher.finalize().into() }
}

// ---------------------------------------------------------------------------
// A1 kernel paths, cached per CRS (the integration pattern proven in
// ring_lattice.rs). Regime contracts:
//   commit — stacked [A1; A2] x ternary rho (b = 1), the golden case;
//   mask   — A1 x Gaussian y (b = 12 sigma_max; also covers digit
//            witnesses, |u_j| <= 2^(e-1) << 12 sigma);
//   verify — A1 x response z (b = the verifier's post-norm-check inf
//            bound; the norm check runs BEFORE this kernel, so the
//            contract holds for adversarial responses).

pub struct A1Paths {
    pub nt: NttTables,
    pub commit: A1CommitKernel,
    pub mask: A1GemmKernel,
    pub verify: A1GemmKernel,
    /// A2-row kernels (the ct-engine's message-side combinations need
    /// A2 y and A2 z matvecs with the same contracts).
    pub mask2: A1GemmKernel,
    pub verify2: A1GemmKernel,
}

impl A1Paths {
    pub fn cached_bytes(&self) -> usize {
        self.commit.cached_bytes()
            + self.mask.cached_bytes()
            + self.verify.cached_bytes()
            + self.mask2.cached_bytes()
            + self.verify2.cached_bytes()
    }
}

pub fn build_a1_paths(crs: &RingCrs, sigma_max: u64, resp_inf_max: u128) -> A1Paths {
    let nt = build_tables();
    let CommitShape { kappa, n_r, msg_r } = crs.shape;
    let mut stacked = crs.a1.clone();
    stacked.extend(crs.a2.iter().cloned());
    let commit = A1CommitKernel::new(&stacked, kappa + msg_r, n_r, crs.q, 1, &nt);
    let mask = A1GemmKernel::new(&crs.a1, kappa, n_r, crs.q, 12 * sigma_max as u128, &nt);
    let verify = A1GemmKernel::new(&crs.a1, kappa, n_r, crs.q, resp_inf_max, &nt);
    let mask2 = A1GemmKernel::new(&crs.a2, msg_r, n_r, crs.q, 12 * sigma_max as u128, &nt);
    let verify2 = A1GemmKernel::new(&crs.a2, msg_r, n_r, crs.q, resp_inf_max, &nt);
    A1Paths { nt, commit, mask, verify, mask2, verify2 }
}

/// Kernel selector: schoolbook oracle (differential path) or the cached A1
/// NTT paths. Proofs and commitments are bit-identical either way.
pub enum KernelPath<'a> {
    School,
    A1(&'a A1Paths),
}

/// com(x; rho) = (A1 rho, A2 rho + x). x has msg_r elements, rho n_r
/// ternary columns.
pub fn commit(path: &KernelPath, crs: &RingCrs, x: &[Poly], rho: &[Vec<i64>]) -> (Vec<Poly>, Vec<Poly>) {
    let CommitShape { kappa, n_r, msg_r } = crs.shape;
    assert_eq!(x.len(), msg_r);
    assert_eq!(rho.len(), n_r);
    let zq = super::Zq::new(crs.q);
    let (t1, mut t2) = match path {
        KernelPath::School => (
            ring_matvec_small_g(&zq, &crs.a1, kappa, n_r, rho),
            ring_matvec_small_g(&zq, &crs.a2, msg_r, n_r, rho),
        ),
        KernelPath::A1(p) => {
            // Stacked [A1; A2] kernel: column transforms shared by both
            // output blocks (regime a, single-prime).
            let mut out = p.commit.commit_column(rho, &p.nt);
            let t2 = out.split_off(kappa);
            (out, t2)
        }
    };
    for (t, xi) in t2.iter_mut().zip(x.iter()) {
        *t = poly_add(&zq, t, xi);
    }
    (t1, t2)
}

/// A1-row matvec against a bounded integer column through the chosen path:
/// mask commitments (Gaussian y, digit witnesses) and the verifier's
/// response matvec. The caller guarantees the path's contract bound.
pub fn a1_matvec(path: &KernelPath, crs: &RingCrs, which: MatvecKind, v: &[Vec<i64>]) -> Vec<Poly> {
    let CommitShape { kappa, n_r, .. } = crs.shape;
    let zq = super::Zq::new(crs.q);
    match path {
        KernelPath::School => ring_matvec_small_g(&zq, &crs.a1, kappa, n_r, v),
        KernelPath::A1(p) => match which {
            MatvecKind::Mask => p.mask.commit_column(v, &p.nt),
            MatvecKind::Verify => p.verify.commit_column(v, &p.nt),
        },
    }
}

/// A2-row matvec (message-side images A2 y / A2 z for the ct-engine).
pub fn a2_matvec(path: &KernelPath, crs: &RingCrs, which: MatvecKind, v: &[Vec<i64>]) -> Vec<Poly> {
    let CommitShape { n_r, msg_r, .. } = crs.shape;
    let zq = super::Zq::new(crs.q);
    match path {
        KernelPath::School => ring_matvec_small_g(&zq, &crs.a2, msg_r, n_r, v),
        KernelPath::A1(p) => match which {
            MatvecKind::Mask => p.mask2.commit_column(v, &p.nt),
            MatvecKind::Verify => p.verify2.commit_column(v, &p.nt),
        },
    }
}

#[derive(Clone, Copy)]
pub enum MatvecKind {
    Mask,
    Verify,
}

// ---------------------------------------------------------------------------
// Ring combinations (transcription lifts). Challenge combinations of
// commitments/messages: sum_i c_i * v_i with small ring challenges c_i.
// The A1 path chunks automatically at the capacity-derived term limit.

/// sum_i c_i * v_i over R_q, c small (|c|_inf <= c_max), v mod-q.
pub fn combine_polys(
    path: &KernelPath,
    ctx: &RingCtx,
    v: &[Poly],
    c: &[Vec<i64>],
    c_max: u128,
) -> Poly {
    assert_eq!(v.len(), c.len());
    match path {
        KernelPath::A1(p) => aux::a1_combination_sum(v, c, c_max, ctx.zq.q, &p.nt),
        KernelPath::School => {
            let mut acc = super::poly_zero();
            for (vi, ci) in v.iter().zip(c.iter()) {
                let prod = super::ring_mul_split_kara_fast(ctx, vi, &super::poly_from_small(&ctx.zq, ci));
                acc = poly_add(&ctx.zq, &acc, &prod);
            }
            acc
        }
    }
}

/// Column-wise combination of commitment groups: groups[i] is a vector of
/// ring elements (e.g. a commitment t1 of length kappa); returns
/// sum_i c_i * groups[i] element-wise.
pub fn combine_groups(
    path: &KernelPath,
    ctx: &RingCtx,
    groups: &[Vec<Poly>],
    c: &[Vec<i64>],
    c_max: u128,
) -> Vec<Poly> {
    assert!(!groups.is_empty());
    let len = groups[0].len();
    (0..len)
        .map(|j| {
            let col: Vec<Poly> = groups.iter().map(|g| g[j].clone()).collect();
            combine_polys(path, ctx, &col, c, c_max)
        })
        .collect()
}

/// Integer-side combination: sum_i c_i * rho_i over Z (exact i64; the
/// prover's combined-randomness witnesses). |result|_inf <=
/// t * D * c_max * |rho|_inf — the caller's digit chain carries the bound.
pub fn combine_small(rhos: &[Vec<Vec<i64>>], c: &[Vec<i64>]) -> Vec<Vec<i64>> {
    assert_eq!(rhos.len(), c.len());
    let n_r = rhos[0].len();
    let mut acc = vec![vec![0i64; D]; n_r];
    for (rho, ci) in rhos.iter().zip(c.iter()) {
        for (a, r) in acc.iter_mut().zip(rho.iter()) {
            let prod = super::poly_mul_small(ci, r);
            for (x, p) in a.iter_mut().zip(prod.iter()) {
                *x += p;
            }
        }
    }
    acc
}

/// Pre-split key rows for the A2 split-Karatsuba fallback GEMM (kept as a
/// second differential path in benches; the A1 path is the default).
pub fn split_rows(ctx: &RingCtx, rows: &[Poly]) -> Vec<Vec<u64>> {
    rows.iter().map(|p| crt_split(ctx, p)).collect()
}

// ---------------------------------------------------------------------------
// Wide-object chunking (M5-lite). A logical object wider than one
// commitment's msg_r message slots — e.g. the pi2-CE execution/mask vectors,
// which at the FFN shape need h * inner_r = 128 * 32 = 4096 ring-element
// slots (up to 11008 for the wider orientation) — is committed as a sequence
// of column CHUNKS under ONE bounded-size CRS at the frozen msg_r = 32
// class. The alternative, a monolithic wide CRS at msg_r = 4096..11008,
// costs (kappa + msg_r) * N_r ring elements ~ 17-121 GB before the A1
// kernel caches multiply it — the M5 memory blocker.
//
// Chunking is a LAYOUT convention only. Logical slot u of the wide object
// lives at (chunk u / msg_r, slot u % msg_r) — the same flat-index
// convention the ct-engine already uses for g-groups (g_slot_of) — and
// every protocol equation (claims, openings, reveals, combinations)
// addresses (commitment, slot) pairs exactly as before. No verification
// equation, challenge derivation, or norm budget changes; each chunk is an
// ordinary commitment with its own independent ternary randomness, opened
// by the ordinary opening machinery. The manifest/digest treats the chunk
// list as ONE logical tensor: a single CommitmentEntry carrying
// wide_digest() over the ordered chunk commitments (chunk count and shape
// in key_info), never one entry per chunk.

/// Number of msg_r-slot chunks covering a wide object of `len` slots.
pub fn wide_chunk_count(len: usize, msg_r: usize) -> usize {
    len.div_ceil(msg_r).max(1)
}

/// Logical wide slot u -> (chunk index, slot inside the chunk).
pub fn wide_slot(u: usize, msg_r: usize) -> (usize, usize) {
    (u / msg_r, u % msg_r)
}

/// Split a wide object into chunk messages of msg_r ring elements each,
/// zero-padding the tail chunk (zero padding commits like any message
/// value; the commit cost is a function of the CRS shape, not of x).
pub fn wide_chunks(x_wide: &[Poly], msg_r: usize) -> Vec<Vec<Poly>> {
    (0..wide_chunk_count(x_wide.len(), msg_r))
        .map(|c| {
            (0..msg_r)
                .map(|s| {
                    x_wide.get(c * msg_r + s).cloned().unwrap_or_else(super::poly_zero)
                })
                .collect()
        })
        .collect()
}

/// Commit a wide object as its chunk sequence under the (bounded) CRS.
/// Returns per-chunk (message, randomness, commitment group) — the message
/// list is exactly wide_chunks(x_wide, msg_r).
pub fn commit_wide(
    path: &KernelPath,
    crs: &RingCrs,
    x_wide: &[Poly],
    rng: &mut dyn super::RngSource,
) -> (Vec<Vec<Poly>>, Vec<Vec<Vec<i64>>>, Vec<(Vec<Poly>, Vec<Poly>)>) {
    let msgs = wide_chunks(x_wide, crs.shape.msg_r);
    let mut rhos = Vec::with_capacity(msgs.len());
    let mut groups = Vec::with_capacity(msgs.len());
    for x in &msgs {
        let rho: Vec<Vec<i64>> =
            (0..crs.shape.n_r).map(|_| super::rng_ternary_poly(rng)).collect();
        groups.push(commit(path, crs, x, &rho));
        rhos.push(rho);
    }
    (msgs, rhos, groups)
}

/// ONE digest for the whole ordered chunk list — the wide object's identity
/// in the manifest and in every statement hash. Binds the chunk count and
/// each chunk's full (t1, t2) in order, so chunk reordering, truncation,
/// extension, or any single-element tamper changes the digest.
pub fn wide_digest(groups: &[(Vec<Poly>, Vec<Poly>)]) -> [u8; 32] {
    use sha2::Digest;
    let mut hasher = sha2::Sha256::new();
    hasher.update(b"route-r-wide-chunks-v1");
    hasher.update((groups.len() as u64).to_le_bytes());
    for (t1, t2) in groups {
        hasher.update(super::polys_bytes(t1));
        hasher.update(super::polys_bytes(t2));
    }
    hasher.finalize().into()
}

/// The monolithic-CRS cost that chunking avoids, in bytes: a wide CRS at
/// message dimension `msg_r_wide` stores (kappa + msg_r) * N_r ring
/// elements of D u64 coefficients (A1 kernel caches come on top). Kept as
/// a pure formula so benches/reports can print the avoided footprint.
pub fn monolithic_wide_crs_bytes(msg_r_wide: usize, kappa: usize, q: u64) -> u128 {
    let d_lwe = (768.0 * (q as f64).log2() / 11.7).ceil() as usize;
    let n_r = (kappa * super::D + msg_r_wide * super::D + d_lwe).div_ceil(super::D);
    (kappa as u128 + msg_r_wide as u128) * n_r as u128 * (super::D as u128) * 8
}
