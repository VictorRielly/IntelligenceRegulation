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
}

impl A1Paths {
    pub fn cached_bytes(&self) -> usize {
        self.commit.cached_bytes() + self.mask.cached_bytes() + self.verify.cached_bytes()
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
    A1Paths { nt, commit, mask, verify }
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
