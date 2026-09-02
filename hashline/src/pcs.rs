//! A Ligero/Brakedown-class multilinear polynomial commitment.
//!
//! The committed vector (length m * n, n = 2^log_cols) is an m x n
//! matrix; each row is Reed-Solomon encoded (systematic: the row's n
//! values are interpreted as evaluations on the size-n subgroup,
//! interpolated, and re-evaluated on the size-(n * inv_rate) group, so
//! encoded[i][inv_rate * j] == data[i][j]); a blake3 Merkle tree is
//! built over the n * inv_rate columns. A "functional" (row weights
//! rho in Fp2^m, column weights c in Fp2^n) is opened by sending
//! v = rho^T M in the clear; the verifier checks <v, c> == value and,
//! at Q random columns j, that Enc(v)[j] == sum_i rho_i encoded[i][j].
//! Functionals sharing column weights are batched into one v with a
//! random linear combination of their row weights. A proximity test
//! (random rho) rides on the same columns.
//!
//! Soundness (Brakedown Thm. with the conservative delta/3 bound): with
//! RS relative distance delta = 1 - 1/inv_rate the column test fails
//! to catch a far matrix with probability (1 - delta/3)^Q; at inv_rate
//! 4, Q = 256: (3/4)^256 = 2^-106. Field terms are O(n / 2^128).

use crate::field::{Fp, Fp2};
use crate::merkle::{Digest, MerkleTree};
use crate::mle::eq_table_msb;
use crate::ntt::NttTables;
use crate::transcript::Transcript;
use rayon::prelude::*;

#[derive(Clone, Copy, Debug)]
pub struct PcsParams {
    pub log_cols: u32,
    pub inv_rate: usize,
    pub num_col_checks: usize,
}

impl PcsParams {
    pub fn cols(&self) -> usize {
        1 << self.log_cols
    }
    pub fn enc_cols(&self) -> usize {
        self.cols() * self.inv_rate
    }
}

/// A slice of the committed vector: rows [row0, row0 + 2^log_size / n).
#[derive(Clone, Copy, Debug)]
pub struct Slice {
    pub offset: usize,
    pub log_size: u32,
}

/// One linear functional's claim: value = sum_parts coef * MLE_of_slice(point)
/// (or, if `sum` is true, the plain sum of every entry of each part).
#[derive(Clone, Debug)]
pub struct Claim {
    pub parts: Vec<(Slice, Fp2)>,
    pub point: Vec<Fp2>,
    pub sum: bool,
    pub value: Fp2,
}

/// [UPERF3-XX] Where the encoded matrix lives: the host (the CPU path,
/// unchanged) or the device (`HL_GPU=1`; the systematic data and the
/// encoding stay resident until the opening).
pub enum Store {
    Host { encoded: Vec<Fp> }, // rows x enc_cols, row-major
    #[cfg(feature = "gpu-cuda")]
    Device(crate::gpu::DevCommit),
}

pub struct Committed {
    pub params: PcsParams,
    pub rows: usize,
    pub store: Store,
    pub tree: MerkleTree,
}

#[derive(Clone, Debug)]
pub struct Commitment {
    pub root: Digest,
    pub rows: usize,
    pub log_cols: u32,
}

#[derive(Clone, Debug, Default)]
pub struct Opening {
    /// One clear row-combination per column-weight group, in group order.
    pub group_vecs: Vec<Vec<Fp2>>,
    pub prox_vec: Vec<Fp2>,
    /// (column index, the column's `rows` entries, Merkle path)
    pub columns: Vec<(usize, Vec<Fp>, Vec<Digest>)>,
}

impl Opening {
    pub fn size_bytes(&self) -> usize {
        let g: usize = self.group_vecs.iter().map(|v| v.len() * 16).sum();
        let p = self.prox_vec.len() * 16;
        let c: usize = self.columns.iter().map(|(_, col, path)| 8 + col.len() * 8 + path.len() * 32).sum();
        g + p + c
    }
    /// [UPERF3-XX] The flat little-endian encoding `size_bytes` counts.
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        for v in &self.group_vecs {
            for x in v {
                out.extend_from_slice(&x.to_bytes());
            }
        }
        for x in &self.prox_vec {
            out.extend_from_slice(&x.to_bytes());
        }
        for (j, col, path) in &self.columns {
            out.extend_from_slice(&(*j as u64).to_le_bytes());
            for x in col {
                out.extend_from_slice(&x.to_bytes());
            }
            for d in path {
                out.extend_from_slice(d);
            }
        }
    }
}

fn hash_column(col: &[Fp]) -> Digest {
    let mut h = blake3::Hasher::new();
    // one update over the little-endian bytes
    let bytes: Vec<u8> = col.iter().flat_map(|v| v.to_bytes()).collect();
    h.update(&bytes);
    *h.finalize().as_bytes()
}

/// The column leaves of an encoded matrix (rows x nn, row-major): blake3
/// of each column's little-endian bytes, hashed in tiles of 64 columns.
pub fn hash_columns(encoded: &[Fp], rows: usize, nn: usize) -> Vec<Digest> {
    let tile = 64usize;
    let mut leaves = vec![[0u8; 32]; nn];
    leaves.par_chunks_mut(tile).enumerate().for_each(|(ti, out)| {
        let c0 = ti * tile;
        let w = out.len();
        let mut bufs: Vec<Vec<u8>> = (0..w).map(|_| Vec::with_capacity(rows * 8)).collect();
        for i in 0..rows {
            let row = &encoded[i * nn + c0..i * nn + c0 + w];
            for (b, v) in bufs.iter_mut().zip(row.iter()) {
                b.extend_from_slice(&v.to_bytes());
            }
        }
        for (o, b) in out.iter_mut().zip(bufs.iter()) {
            *o = *blake3::hash(b).as_bytes();
        }
    });
    leaves
}

/// Commit to `data` (length must be a multiple of n).
pub fn commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Committed {
    let n = params.cols();
    let nn = params.enc_cols();
    assert!(data.len() % n == 0 && !data.is_empty(), "pcs: data length {} not a multiple of n = {n}", data.len());
    let rows = data.len() / n;
    // [UPERF3-XX] the device path (HL_GPU=1): the same encoding and the same leaves; Err -> the CPU body below.
    #[cfg(feature = "gpu-cuda")]
    if crate::gpu::enabled() {
        match crate::gpu::dev_commit(params, data, ntt) {
            Ok((dc, leaves)) => {
                let tree = MerkleTree::build(leaves);
                return Committed { params: *params, rows, store: Store::Device(dc), tree };
            }
            Err(e) => eprintln!("[UPERF3-XX] gpu commit declined ({e}); CPU path"),
        }
    }
    let mut encoded = vec![Fp::ZERO; rows * nn];
    encoded.par_chunks_mut(nn).zip(data.par_chunks(n)).for_each(|(erow, drow)| {
        // systematic: interpolate on the size-n subgroup, evaluate on the size-nn group
        let mut coeffs = drow.to_vec();
        ntt.inverse(&mut coeffs);
        ntt.rs_encode(&coeffs, erow);
    });
    let leaves = hash_columns(&encoded, rows, nn);
    let tree = MerkleTree::build(leaves);
    Committed { params: *params, rows, store: Store::Host { encoded }, tree }
}

impl Committed {
    pub fn commitment(&self) -> Commitment {
        Commitment { root: self.tree.root(), rows: self.rows, log_cols: self.params.log_cols }
    }
}

/// Row weights and column weights of a claim on an m x n matrix.
fn claim_weights(claim: &Claim, rows: usize, log_cols: u32) -> (Vec<Fp2>, Vec<Fp2>) {
    let n = 1usize << log_cols;
    let mut row_w = vec![Fp2::ZERO; rows];
    let col_w: Vec<Fp2>;
    if claim.sum {
        col_w = vec![Fp2::ONE; n];
        for (sl, coef) in &claim.parts {
            let srows = (1usize << sl.log_size) / n;
            let r0 = sl.offset / n;
            for i in 0..srows {
                row_w[r0 + i] = row_w[r0 + i].add(*coef);
            }
        }
    } else {
        let log_rows_part = claim.parts[0].0.log_size - log_cols;
        assert_eq!(claim.point.len() as u32, claim.parts[0].0.log_size, "claim point arity != slice size");
        let eq_r = eq_table_msb(&claim.point[..log_rows_part as usize]);
        col_w = eq_table_msb(&claim.point[log_rows_part as usize..]);
        for (sl, coef) in &claim.parts {
            assert_eq!(sl.log_size, claim.parts[0].0.log_size, "claim parts must have equal size");
            assert!(sl.offset % n == 0);
            let r0 = sl.offset / n;
            for (i, e) in eq_r.iter().enumerate() {
                row_w[r0 + i] = row_w[r0 + i].add(coef.mul(*e));
            }
        }
    }
    (row_w, col_w)
}

/// Group claims by identical column weights (same point tail / sum kind).
fn group_claims(claims: &[Claim], rows: usize, log_cols: u32) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {
    let mut groups: Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> = Vec::new();
    for c in claims {
        let (rw, cw) = claim_weights(c, rows, log_cols);
        if let Some(g) = groups.iter_mut().find(|g| g.0 == cw) {
            g.1.push((rw, c.value));
        } else {
            groups.push((cw, vec![(rw, c.value)]));
        }
    }
    groups
}

/// rho^T M for several rho at once, reading the systematic positions of
/// the encoded matrix (encoded[i][inv_rate * j] == data[i][j]); for a
/// device store the combination runs on the device (`gpu::dev_fold_rows`).
fn fold_rows_multi(cm: &Committed, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let n = cm.params.cols();
    let (src, nn, ir): (&[Fp], usize, usize) = match &cm.store {
        Store::Host { encoded } => (encoded, cm.params.enc_cols(), cm.params.inv_rate),
        #[cfg(feature = "gpu-cuda")]
        Store::Device(dc) => return crate::gpu::dev_fold_rows(dc, rhos).expect("gpu row-combination"),
    };
    let k = rhos.len();
    let chunk = 512usize.min(n);
    let n_chunks = (n + chunk - 1) / chunk;
    let parts: Vec<Vec<Vec<Fp2>>> = (0..n_chunks)
        .into_par_iter()
        .map(|ci| {
            let c0 = ci * chunk;
            let w = chunk.min(n - c0);
            let mut out = vec![vec![Fp2::ZERO; w]; k];
            for i in 0..cm.rows {
                let row = &src[i * nn..(i + 1) * nn];
                for (g, rho) in rhos.iter().enumerate() {
                    let r = rho[i];
                    if r.is_zero() { continue; }
                    let o = &mut out[g];
                    for j in 0..w {
                        let v = row[(c0 + j) * ir];
                        if v.is_zero() { continue; }
                        o[j] = o[j].add(r.mul_base(v));
                    }
                }
            }
            out
        })
        .collect();
    let mut out = vec![vec![Fp2::ZERO; n]; k];
    for (ci, p) in parts.into_iter().enumerate() {
        let c0 = ci * chunk;
        for g in 0..k {
            for (j, v) in p[g].iter().enumerate() {
                out[g][c0 + j] = *v;
            }
        }
    }
    out
}

/// Prover: open `claims` on the commitment. Transcript order: (claims
/// are assumed already absorbed by the caller) -> lambdas per group ->
/// group vectors absorbed -> proximity rho -> prox vector absorbed ->
/// column indices.
pub fn open(cm: &Committed, claims: &[Claim], tr: &mut Transcript) -> Opening {
    use std::time::Instant;
    let vb = std::env::var("HL_TIMING").map(|v| v == "1").unwrap_or(false);
    let t0 = Instant::now();
    let rows = cm.rows;
    let n = cm.params.cols();
    let groups = group_claims(claims, rows, cm.params.log_cols);
    let t_groups = t0.elapsed().as_secs_f64();
    let mut rhos: Vec<Vec<Fp2>> = Vec::with_capacity(groups.len() + 1);
    for (_, members) in &groups {
        let lambdas = tr.challenge_fp2_vec(members.len());
        let mut rho = vec![Fp2::ZERO; rows];
        for ((rw, _), lam) in members.iter().zip(lambdas.iter()) {
            for i in 0..rows {
                if !rw[i].is_zero() {
                    rho[i] = rho[i].add(lam.mul(rw[i]));
                }
            }
        }
        rhos.push(rho);
    }
    let prox_rho = tr.challenge_fp2_vec(rows);
    rhos.push(prox_rho);
    let t_rho = t0.elapsed().as_secs_f64();
    let mut vecs = fold_rows_multi(cm, &rhos);
    let t_fold = t0.elapsed().as_secs_f64();
    let prox_vec = vecs.pop().unwrap();
    for v in &vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    tr.absorb_fp2(b"pcs-prox", &prox_vec);
    let idx = tr.challenge_indices(cm.params.num_col_checks, cm.params.enc_cols());
    let t_absorb = t0.elapsed().as_secs_f64();
    let nn = cm.params.enc_cols();
    let columns: Vec<(usize, Vec<Fp>, Vec<Digest>)> = match &cm.store {
        Store::Host { encoded } => idx
            .par_iter()
            .map(|&j| {
                let col: Vec<Fp> = (0..rows).map(|i| encoded[i * nn + j]).collect();
                (j, col, cm.tree.path(j))
            })
            .collect(),
        #[cfg(feature = "gpu-cuda")]
        Store::Device(dc) => {
            let cols = crate::gpu::dev_columns(dc, &idx).expect("gpu column gather");
            idx.iter().zip(cols.into_iter()).map(|(&j, col)| (j, col, cm.tree.path(j))).collect()
        }
    };
    let _ = n;
    if vb {
        eprintln!(
            "[pcs::open] rows {rows} n {n} claims {} groups {}: group_claims {:.4} | rhos {:.4} | fold {:.4} | absorb+idx {:.4} | columns {:.4} s",
            claims.len(), groups.len(), t_groups, t_rho - t_groups, t_fold - t_rho, t_absorb - t_fold, t0.elapsed().as_secs_f64() - t_absorb
        );
    }
    Opening { group_vecs: vecs, prox_vec, columns }
}

/// Verifier: check the opening against the commitment and the claims.
pub fn verify(
    params: &PcsParams,
    cm: &Commitment,
    claims: &[Claim],
    opening: &Opening,
    ntt: &NttTables,
    tr: &mut Transcript,
) -> Result<(), String> {
    let rows = cm.rows;
    let n = params.cols();
    let nn = params.enc_cols();
    if cm.log_cols != params.log_cols {
        return Err("pcs: log_cols mismatch".into());
    }
    let groups = group_claims(claims, rows, params.log_cols);
    if opening.group_vecs.len() != groups.len() {
        return Err(format!("pcs: {} group vectors for {} groups", opening.group_vecs.len(), groups.len()));
    }
    let mut rhos: Vec<Vec<Fp2>> = Vec::with_capacity(groups.len() + 1);
    for (g, (cw, members)) in groups.iter().enumerate() {
        let lambdas = tr.challenge_fp2_vec(members.len());
        let mut rho = vec![Fp2::ZERO; rows];
        let mut want = Fp2::ZERO;
        for ((rw, val), lam) in members.iter().zip(lambdas.iter()) {
            for i in 0..rows {
                if !rw[i].is_zero() {
                    rho[i] = rho[i].add(lam.mul(rw[i]));
                }
            }
            want = want.add(lam.mul(*val));
        }
        rhos.push(rho);
        let v = &opening.group_vecs[g];
        if v.len() != n {
            return Err(format!("pcs: group vector {g} has length {}", v.len()));
        }
        let got = v.iter().zip(cw.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
        if got != want {
            return Err(format!("pcs: group {g}: <v, c> != combined claim"));
        }
    }
    let prox_rho = tr.challenge_fp2_vec(rows);
    rhos.push(prox_rho);
    for v in &opening.group_vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if opening.prox_vec.len() != n {
        return Err("pcs: prox vector length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    let idx = tr.challenge_indices(params.num_col_checks, nn);
    if opening.columns.len() != idx.len() {
        return Err("pcs: wrong number of columns".into());
    }
    // encode every clear vector (re and im separately; the code is linear)
    let mut all_vecs: Vec<&Vec<Fp2>> = opening.group_vecs.iter().collect();
    all_vecs.push(&opening.prox_vec);
    let encoded_vecs: Vec<(Vec<Fp>, Vec<Fp>)> = all_vecs
        .par_iter()
        .map(|v| {
            let mut re: Vec<Fp> = v.iter().map(|x| x.c0).collect();
            let mut im: Vec<Fp> = v.iter().map(|x| x.c1).collect();
            ntt.inverse(&mut re);
            ntt.inverse(&mut im);
            let mut ere = vec![Fp::ZERO; nn];
            let mut eim = vec![Fp::ZERO; nn];
            ntt.rs_encode(&re, &mut ere);
            ntt.rs_encode(&im, &mut eim);
            (ere, eim)
        })
        .collect();
    let results: Vec<Result<(), String>> = opening
        .columns
        .par_iter()
        .zip(idx.par_iter())
        .map(|((j, col, path), &want_j)| {
            if *j != want_j {
                return Err(format!("pcs: column index {j} != sampled {want_j}"));
            }
            if col.len() != rows {
                return Err("pcs: column length".into());
            }
            let leaf = hash_column(col);
            if !MerkleTree::verify_path(&cm.root, *j, &leaf, path) {
                return Err(format!("pcs: Merkle path for column {j} fails"));
            }
            for (g, rho) in rhos.iter().enumerate() {
                let mut acc = Fp2::ZERO;
                for i in 0..rows {
                    acc = acc.add(rho[i].mul_base(col[i]));
                }
                let (ere, eim) = &encoded_vecs[g];
                let want = Fp2::new(ere[*j], eim[*j]);
                if acc != want {
                    return Err(format!("pcs: column {j} disagrees with clear vector {g}"));
                }
            }
            Ok(())
        })
        .collect();
    for r in results {
        r?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mle::eval_mle_base;

    fn params() -> PcsParams {
        PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 20 }
    }

    fn data(seed: u64, len: usize) -> Vec<Fp> {
        let mut s = seed;
        (0..len).map(|_| { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::new((s >> 1) % 1000) }).collect()
    }

    fn pt(seed: u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|i| Fp2::new(Fp::new(seed * 1000 + i as u64 * 7 + 3), Fp::new(seed + i as u64 * 11 + 5))).collect()
    }

    #[test]
    fn commit_open_verify_and_tampers() {
        let p = params();
        let ntt = NttTables::new(10);
        // two slices: A of 2^8 at 0, B of 2^6 at 256, plus two base columns of a Fp2 helper of 2^6 at 320/384
        let d = data(1, 256 + 64 + 64 + 64);
        let cm = commit(&p, &d, &ntt);
        let com = cm.commitment();
        let sa = Slice { offset: 0, log_size: 8 };
        let sb = Slice { offset: 256, log_size: 6 };
        let hre = Slice { offset: 320, log_size: 6 };
        let him = Slice { offset: 384, log_size: 6 };
        let ra = pt(3, 8);
        let rb = pt(4, 6);
        let va = eval_mle_base(&d[0..256], &ra);
        let vb = eval_mle_base(&d[256..320], &rb);
        let vh = eval_mle_base(&d[320..384], &rb).add(Fp2::U.mul(eval_mle_base(&d[384..448], &rb)));
        let sum_h = d[320..384].iter().fold(Fp2::ZERO, |a, x| a.add_base(*x)).add(Fp2::U.mul(d[384..448].iter().fold(Fp2::ZERO, |a, x| a.add_base(*x))));
        let claims = vec![
            Claim { parts: vec![(sa, Fp2::ONE)], point: ra.clone(), sum: false, value: va },
            Claim { parts: vec![(sb, Fp2::ONE)], point: rb.clone(), sum: false, value: vb },
            Claim { parts: vec![(hre, Fp2::ONE), (him, Fp2::U)], point: rb.clone(), sum: false, value: vh },
            Claim { parts: vec![(hre, Fp2::ONE), (him, Fp2::U)], point: vec![], sum: true, value: sum_h },
        ];
        let mut tp = Transcript::new(b"pcs");
        let op = open(&cm, &claims, &mut tp);
        let mut tv = Transcript::new(b"pcs");
        verify(&p, &com, &claims, &op, &ntt, &mut tv).unwrap();
        // wrong claimed value
        let mut bad = claims.clone();
        bad[1].value = bad[1].value.add(Fp2::ONE);
        let mut tv = Transcript::new(b"pcs");
        assert!(verify(&p, &com, &bad, &op, &ntt, &mut tv).is_err());
        // a flipped committed value with an honest opening attempt against the ORIGINAL claims
        let mut d2 = d.clone();
        d2[100] = d2[100].add(Fp::ONE);
        let cm2 = commit(&p, &d2, &ntt);
        let mut tp = Transcript::new(b"pcs");
        let op2 = open(&cm2, &claims, &mut tp);
        let mut tv = Transcript::new(b"pcs");
        assert!(verify(&p, &com, &claims, &op2, &ntt, &mut tv).is_err()); // root mismatch
        let mut tv = Transcript::new(b"pcs");
        assert!(verify(&p, &cm2.commitment(), &claims, &op2, &ntt, &mut tv).is_err()); // value mismatch
        // tampered clear vector
        let mut op3 = op.clone();
        op3.group_vecs[0][3] = op3.group_vecs[0][3].add(Fp2::ONE);
        let mut tv = Transcript::new(b"pcs");
        assert!(verify(&p, &com, &claims, &op3, &ntt, &mut tv).is_err());
    }
}
