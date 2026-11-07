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
//! Soundness. The code is RS(K, N), N = n * inv_rate: K = n in the plain
//! mode above (delta = 1 - 1/inv_rate), K = n + q_pad in the ZK mode
//! below (`ZkOpts`, q_pad = Q by `ZkOpts::standard`; delta = 1 - K/N).
//! Which lemma prices the column test is a PROFILE fact of the caller
//! (hashline's `private_block::shape::ColumnRegime`), never a check here:
//! the verifier below is the same under both regimes.
//!  * D15, the general-code count (Brakedown / Ligero, the conservative
//!    delta/3 bound), every rate-1/4 profile and the masking commitment:
//!    a far matrix escapes the column test with probability
//!    (1 - delta/3)^Q; at n = 2^14, inv_rate 4, Q = 256 in ZK mode,
//!    ((2N + K)/(3N))^256 = 2^-105.61 (plain mode, delta = 3/4:
//!    (3/4)^256 = 2^-106.25). Field terms O(N / |F_p^2|).
//!  * D59, the unique-decoding count (BCIKS20 Thm 3.1 from Thm 1.7, with
//!    `rows` independent uniform F_p^2 proximity weights), ONLY for the
//!    rate-1/2 W16R2 profiles' regular openings through `verify_zk_tagged`:
//!    (1 - (e + 1)/N)^Q with e = floor((N - K)/2), plus N / |F_p^2|; at
//!    n = 2^14, inv_rate 2, Q = q_pad = 280: 2^-113.93 per opening. This
//!    bound is attained (W16R2 review F1), so Q, K = n + q_pad, e and the
//!    index sampling must be counted exactly. Powers of one challenge as
//!    the weights would cost a factor m - 1 (Thm 1.6).
//!
//! Moved from `hashline/src/pcs.rs` (CL20, round 12). The only change
//! besides the RNG import is the accelerator seam: the device arms became
//! calls through [`Backend`] / [`EncodedStore`] (`pcs/backend.rs`), the
//! `HL_TIMING` report of `open` became the returned [`OpenTimings`], and
//! the device-buffer commitment `commit_zk_device` stays in hashline's
//! adapter. Field operations, NTT order, hash labels, transcript
//! consumption, RNG draw order and serialization are unchanged.

use crate::field::{Fp, Fp2};
use crate::hashtag::HashTag;
use crate::merkle::{Digest, MerkleTree};
use crate::mle::eq_table_msb;
use crate::ntt::NttTables;
use crate::rng::ZkRng;
use crate::transcript::Transcript;
use rayon::prelude::*;

mod backend;
mod encode_buffer;
#[cfg(test)]
mod encode_conformance_tests;
pub use backend::{Backend, Cpu, EncodedStore, NoExternal};

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
/// unchanged) or an external store a [`Backend`] produced (hashline's
/// device-resident form under `HL_GPU=1`; the systematic data and the
/// encoding stay resident until the opening). `E` is the backend's store
/// type; the CPU default `NoExternal` has no values, so the second variant
/// cannot occur in a CPU commitment. The variant keeps its legacy name so
/// the consumers that match on it compile unchanged.
pub enum Store<E = NoExternal> {
    Host { encoded: Vec<Fp> }, // rows x enc_cols, row-major
    Device(E),
}

pub struct Committed<E = NoExternal> {
    pub params: PcsParams,
    pub rows: usize,
    pub store: Store<E>,
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

/// [ZK60 D19, ruling T-1] `hash_column` under a tagged profile's COLUMN key.
/// `hash_column` above keeps its own body.
fn hash_column_keyed(col: &[Fp], key: Option<&[u8; 32]>) -> Digest {
    let mut h = crate::hashtag::hasher(key);
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

/// [ZK60 D19, ruling T-1] `hash_columns` under a tagged profile's COLUMN
/// key. `hash_columns` above keeps its own body, so the legacy path is the
/// same text it always was — including its `blake3::hash` fast path, which
/// keyed mode has no equivalent of and which is why the keyed body builds a
/// hasher per column instead.
pub fn hash_columns_keyed(encoded: &[Fp], rows: usize, nn: usize, key: Option<&[u8; 32]>) -> Vec<Digest> {
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
            let mut h = crate::hashtag::hasher(key);
            h.update(b);
            *o = *h.finalize().as_bytes();
        }
    });
    leaves
}

/// Commit to `data` (length must be a multiple of n) on the CPU.
pub fn commit(params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Committed {
    commit_with(&Cpu, params, data, ntt)
}

/// `commit` offering the encode-and-hash to `backend` first; a decline
/// runs the CPU body (the same encoding and the same leaves).
pub fn commit_with<B: Backend>(backend: &B, params: &PcsParams, data: &[Fp], ntt: &NttTables) -> Committed<B::Store> {
    let n = params.cols();
    let nn = params.enc_cols();
    assert!(data.len() % n == 0 && !data.is_empty(), "pcs: data length {} not a multiple of n = {n}", data.len());
    let rows = data.len() / n;
    // [UPERF3-XX] the external path (hashline: HL_GPU=1): the same encoding and the same leaves; None -> the CPU body below.
    if let Some((dc, leaves)) = backend.try_commit(params, data, ntt) {
        let tree = MerkleTree::build(leaves);
        return Committed { params: *params, rows, store: Store::Device(dc), tree };
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

impl<E> Committed<E> {
    pub fn commitment(&self) -> Commitment {
        Commitment { root: self.tree.root(), rows: self.rows, log_cols: self.params.log_cols }
    }
}

/// Row weights of a claim on an m x n matrix (the column weights are per
/// group: `col_weights` of the claim's `col_key`).
fn row_weights(claim: &Claim, rows: usize, log_cols: u32) -> Vec<Fp2> {
    let n = 1usize << log_cols;
    let mut row_w = vec![Fp2::ZERO; rows];
    if claim.sum {
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
        for (sl, coef) in &claim.parts {
            assert_eq!(sl.log_size, claim.parts[0].0.log_size, "claim parts must have equal size");
            assert!(sl.offset % n == 0);
            let r0 = sl.offset / n;
            for (i, e) in eq_r.iter().enumerate() {
                row_w[r0 + i] = row_w[r0 + i].add(coef.mul(*e));
            }
        }
    }
    row_w
}

/// The column-weight key of a claim: None for the all-ones sum, else the
/// point's column tail (log_cols entries).
fn col_key(claim: &Claim, log_cols: u32) -> Option<Vec<Fp2>> {
    if claim.sum {
        None
    } else {
        let log_rows_part = claim.parts[0].0.log_size - log_cols;
        Some(claim.point[log_rows_part as usize..].to_vec())
    }
}

fn col_weights(key: &Option<Vec<Fp2>>, log_cols: u32) -> Vec<Fp2> {
    match key {
        None => vec![Fp2::ONE; 1usize << log_cols],
        Some(tail) => eq_table_msb(tail),
    }
}

/// Group claims by identical column weights (same point tail / sum kind).
/// [UPERF3-XX] The 2^log_cols column table is built once per group (it
/// was built per claim and compared: 37 claims x 2^14 entries per layer).
fn group_claims(claims: &[Claim], rows: usize, log_cols: u32) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {
    let mut keys: Vec<Option<Vec<Fp2>>> = Vec::new();
    let mut groups: Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> = Vec::new();
    for c in claims {
        let key = col_key(c, log_cols);
        let rw = row_weights(c, rows, log_cols);
        if let Some(gi) = keys.iter().position(|k| *k == key) {
            groups[gi].1.push((rw, c.value));
        } else {
            let cw = col_weights(&key, log_cols);
            keys.push(key);
            groups.push((cw, vec![(rw, c.value)]));
        }
    }
    groups
}

/// rho^T M for several rho at once, reading the systematic positions of
/// the encoded matrix (encoded[i][inv_rate * j] == data[i][j]); for an
/// external store the combination runs there (`EncodedStore::fold_rows`).
fn fold_rows_multi<E: EncodedStore>(cm: &Committed<E>, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let n = cm.params.cols();
    let (src, nn, ir): (&[Fp], usize, usize) = match &cm.store {
        Store::Host { encoded } => (encoded, cm.params.enc_cols(), cm.params.inv_rate),
        Store::Device(dc) => return dc.fold_rows(rhos).expect("pcs: external store row-combination"),
    };
    fold_rows_host(src, cm.rows, n, nn, ir, rhos)
}

/// rho^T M over a row-major source (rows x nn) whose message symbol j
/// of row i sits at src[i * nn + j * ir] (the systematic positions of an
/// encoded matrix, or a plain data matrix with nn = n, ir = 1).
/// [UPERF3-ZA] factored out of `fold_rows_multi` (same arithmetic) so
/// the ZK commitment, whose encoding is not systematic, folds its data.
fn fold_rows_host(src: &[Fp], rows: usize, n: usize, nn: usize, ir: usize, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let k = rhos.len();
    let chunk = 512usize.min(n);
    let n_chunks = (n + chunk - 1) / chunk;
    let parts: Vec<Vec<Vec<Fp2>>> = (0..n_chunks)
        .into_par_iter()
        .map(|ci| {
            let c0 = ci * chunk;
            let w = chunk.min(n - c0);
            let mut out = vec![vec![Fp2::ZERO; w]; k];
            for i in 0..rows {
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

/// The phase clocks of one `open`, in seconds (what the legacy `HL_TIMING`
/// report printed); returned, never printed, by `open_timed`.
#[derive(Clone, Copy, Debug, Default)]
pub struct OpenTimings {
    pub claims: usize,
    pub groups: usize,
    pub group_claims: f64,
    pub rhos: f64,
    pub fold: f64,
    pub absorb_idx: f64,
    pub columns: f64,
}

/// Prover: open `claims` on the commitment. Transcript order: (claims
/// are assumed already absorbed by the caller) -> lambdas per group ->
/// group vectors absorbed -> proximity rho -> prox vector absorbed ->
/// column indices.
pub fn open<E: EncodedStore>(cm: &Committed<E>, claims: &[Claim], tr: &mut Transcript) -> Opening {
    open_timed(cm, claims, tr).0
}

/// `open` returning its phase clocks as well.
pub fn open_timed<E: EncodedStore>(cm: &Committed<E>, claims: &[Claim], tr: &mut Transcript) -> (Opening, OpenTimings) {
    use std::time::Instant;
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
        Store::Device(dc) => {
            let cols = dc.columns(&idx).expect("pcs: external store column gather");
            idx.iter().zip(cols.into_iter()).map(|(&j, col)| (j, col, cm.tree.path(j))).collect()
        }
    };
    let _ = n;
    let timings = OpenTimings {
        claims: claims.len(),
        groups: groups.len(),
        group_claims: t_groups,
        rhos: t_rho - t_groups,
        fold: t_fold - t_rho,
        absorb_idx: t_absorb - t_fold,
        columns: t0.elapsed().as_secs_f64() - t_absorb,
    };
    (Opening { group_vecs: vecs, prox_vec, columns }, timings)
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


// ===========================================================================
// [UPERF3-ZA] The zero-knowledge form of the commitment (behind `--zk`;
// nothing above this line changes). See src/zk.rs for the plan.
//
// Encoding of a row in ZK mode: the message polynomial f_data (degree
// < n, the interpolant of the row's n symbols on the size-n subgroup)
// becomes f = f_data + Z_n * g_pad, Z_n(x) = x^n - 1, g_pad a fresh
// uniformly random polynomial of degree < Q; the codeword is f on the
// COSET h * G_nn (nn = n * inv_rate), which is disjoint from G_n, so no
// evaluation position is systematic and any Q of them are jointly
// uniform given the data (Z_n(eta) != 0 on the coset; the map g_pad ->
// (f(eta_1..eta_Q)) has a Vandermonde-times-diagonal matrix). The code
// is RS(n + Q, nn) on the coset: distance 1 - (n + Q)/nn; the NTT sizes
// are unchanged (coefficients c_i h^i, zero-padded to nn). The clear
// vectors carry n + Q entries (message + pad combination). Merkle
// leaves are salted: leaf = blake3(blake3(column) || salt).
// ===========================================================================

/// The ZK parameters of a commitment: Q random pad symbols per row (>=
/// the number of opened columns) and the coset generator.
#[derive(Clone, Copy, Debug)]
pub struct ZkOpts {
    pub q_pad: usize,
    pub coset: Fp,
}

impl ZkOpts {
    /// Q = the number of column checks; coset generator 7 (a generator
    /// of F_p^*, so 7^nn != 1 for every nn < p - 1 and 7 G_nn is disjoint from G_n).
    pub fn standard(params: &PcsParams) -> ZkOpts {
        ZkOpts { q_pad: params.num_col_checks, coset: Fp::new(7) }
    }
}

/// A committed matrix in ZK mode: the plain `Committed` (its store holds
/// the coset-encoded rows; its tree the SALTED leaves) plus the data
/// itself (the encoding is not systematic), the pads, the salts and the
/// row indices that are masks (asserted at every opening site).
pub struct CommittedZk<E = NoExternal> {
    pub cm: Committed<E>,
    pub zk: ZkOpts,
    /// rows x n (host copy; the device path folds from its own resident copy)
    pub data: Vec<Fp>,
    /// rows x Q
    pub pads: Vec<Fp>,
    /// one per encoded column
    pub salts: Vec<[u8; 32]>,
    /// the row indices that hold uniformly random mask rows (set by the caller)
    pub mask_rows: Vec<usize>,
    /// the one mask row reserved for the proximity combination
    pub prox_mask_row: Option<usize>,
}

#[derive(Clone, Debug, Default)]
pub struct OpeningZk {
    /// One clear row-combination per group: n message entries then Q pad entries.
    pub group_vecs: Vec<Vec<Fp2>>,
    pub prox_vec: Vec<Fp2>,
    /// (column index, the column's `rows` entries, the leaf salt, the Merkle path)
    pub columns: Vec<(usize, Vec<Fp>, [u8; 32], Vec<Digest>)>,
}

impl OpeningZk {
    pub fn size_bytes(&self) -> usize {
        let g: usize = self.group_vecs.iter().map(|v| v.len() * 16).sum();
        let p = self.prox_vec.len() * 16;
        let c: usize = self.columns.iter().map(|(_, col, _, path)| 8 + col.len() * 8 + 32 + path.len() * 32).sum();
        g + p + c
    }
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        for v in &self.group_vecs {
            for x in v {
                out.extend_from_slice(&x.to_bytes());
            }
        }
        for x in &self.prox_vec {
            out.extend_from_slice(&x.to_bytes());
        }
        for (j, col, salt, path) in &self.columns {
            out.extend_from_slice(&(*j as u64).to_le_bytes());
            for x in col {
                out.extend_from_slice(&x.to_bytes());
            }
            out.extend_from_slice(salt);
            for d in path {
                out.extend_from_slice(d);
            }
        }
    }
}

/// h^i for i < nn.
pub fn coset_powers(h: Fp, nn: usize) -> Vec<Fp> {
    let mut out = Vec::with_capacity(nn);
    let mut x = Fp::ONE;
    for _ in 0..nn {
        out.push(x);
        x = x.mul(h);
    }
    assert!(x != Fp::ONE, "pcs zk: the coset generator has order dividing nn (the coset would meet the subgroup)");
    out
}

/// One ZK row encoding: `msg` (n symbols on the size-n subgroup) and `pad`
/// (Q symbols) -> the nn evaluations of f_data + Z_n g_pad on the coset.
pub fn encode_row_zk(ntt: &NttTables, msg: &[Fp], pad: &[Fp], pows: &[Fp], out: &mut [Fp]) {
    let n = msg.len();
    let nn = out.len();
    let q = pad.len();
    assert!(n + q <= nn && nn % n == 0);
    let mut coeffs = msg.to_vec();
    ntt.inverse(&mut coeffs);
    out[..n].copy_from_slice(&coeffs);
    for v in out[n..].iter_mut() {
        *v = Fp::ZERO;
    }
    for i in 0..q {
        out[i] = out[i].sub(pad[i]);
        out[n + i] = pad[i];
    }
    for i in 0..n + q {
        out[i] = out[i].mul(pows[i]);
    }
    ntt.forward(out);
}

/// leaf = blake3(unsalted leaf || salt)
pub fn salt_leaf(leaf: &Digest, salt: &[u8; 32]) -> Digest {
    let mut h = blake3::Hasher::new();
    h.update(leaf);
    h.update(salt);
    *h.finalize().as_bytes()
}

/// [ZK60 D19, ruling T-1] `salt_leaf` under a tagged profile's LEAF key.
/// `salt_leaf` above keeps its own body.
///
/// **This is the function that ends the leaf/node ambiguity.** Under the
/// legacy rule a salted leaf and a Merkle inner node are the same BLAKE3 call
/// on the same 64 bytes; under a tag they are two members of the family, with
/// the leaf key and the node key, and the tests in this file pin both facts.
pub fn salt_leaf_keyed(leaf: &Digest, salt: &[u8; 32], key: Option<&[u8; 32]>) -> Digest {
    let mut h = crate::hashtag::hasher(key);
    h.update(leaf);
    h.update(salt);
    *h.finalize().as_bytes()
}

/// Commit in ZK mode on the CPU. `rng` supplies the pads and the salts.
pub fn commit_zk(params: &PcsParams, data: &[Fp], ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk {
    commit_zk_owned(params, data.to_vec(), ntt, zk, rng)
}

/// `commit_zk` taking the data by value (no host copy: the commitment keeps it).
pub fn commit_zk_owned(params: &PcsParams, data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk {
    commit_zk_owned_with(&Cpu, params, data, ntt, zk, rng)
}

/// `commit_zk` offering the coset encode-and-hash to `backend` first.
pub fn commit_zk_with<B: Backend>(backend: &B, params: &PcsParams, data: &[Fp], ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk<B::Store> {
    commit_zk_owned_with(backend, params, data.to_vec(), ntt, zk, rng)
}

/// `commit_zk_owned` offering the coset encode-and-hash to `backend` first.
/// The pads and the salts are drawn from `rng` BEFORE the offer, in this
/// order, on every path, so the bytes do not depend on who encoded.
pub fn commit_zk_owned_with<B: Backend>(backend: &B, params: &PcsParams, data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng) -> CommittedZk<B::Store> {
    let data_ref: &[Fp] = &data;
    let n = params.cols();
    let nn = params.enc_cols();
    assert!(data_ref.len() % n == 0 && !data_ref.is_empty(), "pcs zk: data length {} not a multiple of n = {n}", data_ref.len());
    assert!(zk.q_pad >= params.num_col_checks, "pcs zk: fewer pad symbols ({}) than opened columns ({})", zk.q_pad, params.num_col_checks);
    let rows = data_ref.len() / n;
    let q = zk.q_pad;
    let pads = rng.fp_vec(rows * q);
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();
    let pows = coset_powers(zk.coset, nn);
    // [UPERF3-ZA] the external path (rung 4): the same coset encoding elsewhere, leaves back, salted here.
    let dev: Option<(B::Store, Vec<Digest>)> = backend.try_commit_zk(params, data_ref, &pads, &pows, ntt);
    let (store, leaves) = match dev {
        Some((dc, leaves)) => (Store::Device(dc), leaves),
        None => {
            let mut encoded = vec![Fp::ZERO; rows * nn];
            encoded.par_chunks_mut(nn).zip(data_ref.par_chunks(n)).zip(pads.par_chunks(q)).for_each(|((erow, drow), prow)| {
                encode_row_zk(ntt, drow, prow, &pows, erow);
            });
            let leaves = hash_columns(&encoded, rows, nn);
            (Store::Host { encoded }, leaves)
        }
    };
    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| salt_leaf(l, s)).collect();
    let tree = MerkleTree::build(salted);
    CommittedZk {
        cm: Committed { params: *params, rows, store, tree },
        zk: *zk,
        data,
        pads,
        salts,
        mask_rows: Vec::new(),
        prox_mask_row: None,
    }
}

/// [ZK60 D19, rulings T-1 and T-8] `commit_zk_owned_with` under a
/// [`HashTag`]. `commit_zk_owned_with` above keeps its own body.
///
/// The pads and the salts are drawn from `rng` FIRST and in exactly the
/// legacy order, before any branch, so the generator's byte order is the same
/// under both rules and a tag never moves a random draw.
///
/// A keyed tag uses only the explicit keyed backend hook. A backend that does
/// not implement it declines to the CPU oracle; the unkeyed hook is never
/// allowed to produce tagged leaves. Pads and salts retain their draw order.
pub fn commit_zk_owned_with_tag<B: Backend>(backend: &B, params: &PcsParams, data: Vec<Fp>, ntt: &NttTables, zk: &ZkOpts, rng: &mut ZkRng, tag: &HashTag) -> CommittedZk<B::Store> {
    let data_ref: &[Fp] = &data;
    let n = params.cols();
    let nn = params.enc_cols();
    assert!(data_ref.len() % n == 0 && !data_ref.is_empty(), "pcs zk: data length {} not a multiple of n = {n}", data_ref.len());
    assert!(zk.q_pad >= params.num_col_checks, "pcs zk: fewer pad symbols ({}) than opened columns ({})", zk.q_pad, params.num_col_checks);
    let rows = data_ref.len() / n;
    let q = zk.q_pad;
    let pads = rng.fp_vec(rows * q);
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();
    let pows = coset_powers(zk.coset, nn);
    // Only a backend that explicitly implements keyed hashing sees this offer.
    let dev: Option<(B::Store, Vec<Digest>)> = match tag.column_key() {
        None => backend.try_commit_zk(params, data_ref, &pads, &pows, ntt),
        Some(key) => backend.try_commit_zk_keyed(params, data_ref, &pads, &pows, ntt, key),
    };
    let (store, leaves) = match dev {
        Some((dc, leaves)) => (Store::Device(dc), leaves),
        None => {
            let encoded = encode_buffer::encode_rows(ntt, data_ref, n, &pads, q, &pows);
            let leaves = hash_columns_keyed(&encoded, rows, nn, tag.column_key());
            (Store::Host { encoded }, leaves)
        }
    };
    let salted: Vec<Digest> = leaves.par_iter().zip(salts.par_iter()).map(|(l, s)| salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    let tree = MerkleTree::build_keyed(salted, tag.node_key());
    CommittedZk {
        cm: Committed { params: *params, rows, store, tree },
        zk: *zk,
        data,
        pads,
        salts,
        mask_rows: Vec::new(),
        prox_mask_row: None,
    }
}

// (`commit_zk_device`, the ZK commitment of a buffer the device already
// holds, is hashline's: it takes a `gpu::Pooled` and lives in the adapter,
// drawing the pads and salts in this same order.)

impl<E> CommittedZk<E> {
    pub fn commitment(&self) -> Commitment {
        self.cm.commitment()
    }
    pub fn rows(&self) -> usize {
        self.cm.rows
    }
}

/// One part of a general linear claim: coef * MLE(slice)(point), or, with
/// an empty point, coef * (the plain sum of the slice). A slice may be
/// smaller than a row (log_size < log_cols): it then occupies columns
/// [offset % n, offset % n + 2^log_size) of one row.
#[derive(Clone, Debug)]
pub struct ZPart {
    pub slice: Slice,
    pub coef: Fp2,
    pub point: Vec<Fp2>,
}

/// value = sum over parts; every part must have the same column-weight
/// vector (the same point tail on the same column range, or all-ones).
#[derive(Clone, Debug)]
pub struct ZClaim {
    pub parts: Vec<ZPart>,
    pub value: Fp2,
}

impl ZClaim {
    pub fn eval(slice: Slice, point: &[Fp2], value: Fp2) -> ZClaim {
        ZClaim { parts: vec![ZPart { slice, coef: Fp2::ONE, point: point.to_vec() }], value }
    }
}

/// The column-weight key of a part: the point tail (empty for a sum) on
/// the column range [c0, c0 + len) of the row (the whole row for slices of
/// a row or more). Groups are formed by key equality; the 2^log_cols
/// column table is built once per group (as in `group_claims`).
#[derive(Clone, Debug, PartialEq)]
struct ZKey {
    tail: Vec<Fp2>,
    c0: usize,
    len: usize,
}

/// (row weights over `rows`, the column key) of one part.
fn zpart_weights(p: &ZPart, rows: usize, log_cols: u32) -> (Vec<Fp2>, ZKey) {
    let n = 1usize << log_cols;
    let mut row_w = vec![Fp2::ZERO; rows];
    let ls = p.slice.log_size;
    let key;
    if p.point.is_empty() {
        if ls >= log_cols {
            assert!(p.slice.offset % n == 0);
            let r0 = p.slice.offset / n;
            for i in 0..(1usize << (ls - log_cols)) {
                row_w[r0 + i] = row_w[r0 + i].add(p.coef);
            }
            key = ZKey { tail: vec![], c0: 0, len: n };
        } else {
            let r0 = p.slice.offset / n;
            let c0 = p.slice.offset % n;
            assert!(c0 + (1usize << ls) <= n);
            row_w[r0] = row_w[r0].add(p.coef);
            key = ZKey { tail: vec![], c0, len: 1usize << ls };
        }
    } else {
        assert_eq!(p.point.len() as u32, ls, "zk claim: point arity != slice size");
        if ls >= log_cols {
            assert!(p.slice.offset % n == 0);
            let lr = (ls - log_cols) as usize;
            let r0 = p.slice.offset / n;
            let eq_r = eq_table_msb(&p.point[..lr]);
            for (i, e) in eq_r.iter().enumerate() {
                row_w[r0 + i] = row_w[r0 + i].add(p.coef.mul(*e));
            }
            key = ZKey { tail: p.point[lr..].to_vec(), c0: 0, len: n };
        } else {
            let r0 = p.slice.offset / n;
            let c0 = p.slice.offset % n;
            assert!(c0 + (1usize << ls) <= n);
            row_w[r0] = row_w[r0].add(p.coef);
            key = ZKey { tail: p.point.clone(), c0, len: 1usize << ls };
        }
    }
    (row_w, key)
}

fn zkey_weights(k: &ZKey, log_cols: u32) -> Vec<Fp2> {
    let n = 1usize << log_cols;
    let mut col_w = vec![Fp2::ZERO; n];
    if k.tail.is_empty() {
        for c in col_w[k.c0..k.c0 + k.len].iter_mut() {
            *c = Fp2::ONE;
        }
    } else {
        let eq_c = eq_table_msb(&k.tail);
        col_w[k.c0..k.c0 + k.len].copy_from_slice(&eq_c);
    }
    col_w
}

/// Group ZK claims by identical column weights: (column weights, [(row weights, value)]).
fn group_zclaims(claims: &[ZClaim], rows: usize, log_cols: u32) -> Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> {
    let mut keys: Vec<ZKey> = Vec::new();
    let mut groups: Vec<(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)> = Vec::new();
    for c in claims {
        assert!(!c.parts.is_empty());
        let (mut rw, key) = zpart_weights(&c.parts[0], rows, log_cols);
        for p in &c.parts[1..] {
            let (rw2, key2) = zpart_weights(p, rows, log_cols);
            assert!(key2 == key, "zk claim: parts with different column weights");
            for (a, b) in rw.iter_mut().zip(rw2.iter()) {
                *a = a.add(*b);
            }
        }
        if let Some(gi) = keys.iter().position(|k| *k == key) {
            groups[gi].1.push((rw, c.value));
        } else {
            let cw = zkey_weights(&key, log_cols);
            keys.push(key);
            groups.push((cw, vec![(rw, c.value)]));
        }
    }
    groups
}

/// The combined row weights of every group plus the proximity rho, in
/// transcript order (lambdas per group, then the prox rho).
fn zk_rhos(groups: &[(Vec<Fp2>, Vec<(Vec<Fp2>, Fp2)>)], rows: usize, tr: &mut Transcript) -> (Vec<Vec<Fp2>>, Vec<Fp2>) {
    let mut rhos: Vec<Vec<Fp2>> = Vec::with_capacity(groups.len() + 1);
    let mut wants = Vec::with_capacity(groups.len());
    for (_, members) in groups {
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
        wants.push(want);
    }
    let prox_rho = tr.challenge_fp2_vec(rows);
    rhos.push(prox_rho);
    (rhos, wants)
}

/// rho^T [M | pads] for several rho: n message entries then Q pad entries each.
fn fold_rows_multi_zk<E: EncodedStore>(cmz: &CommittedZk<E>, rhos: &[Vec<Fp2>]) -> Vec<Vec<Fp2>> {
    let n = cmz.cm.params.cols();
    let q = cmz.zk.q_pad;
    let rows = cmz.cm.rows;
    // [A8] a store may form the message and pad folds together (equal values)
    if let Store::Device(dc) = &cmz.cm.store {
        if let Some(r) = dc.fold_rows_with_pads(rhos, &cmz.pads, q) {
            let v = r.expect("pcs: external store row-combination (with pads)");
            assert!(v.len() == rhos.len() && v.iter().all(|x| x.len() == n + q), "pcs: external store returned vectors of the wrong shape");
            return v;
        }
    }
    let msg: Vec<Vec<Fp2>> = match &cmz.cm.store {
        Store::Host { .. } => fold_rows_host(&cmz.data, rows, n, n, 1, rhos),
        Store::Device(dc) => {
            let mut m = Vec::with_capacity(rhos.len());
            for chunk in rhos.chunks(dc.fold_batch().max(1)) {
                m.extend(dc.fold_rows(chunk).expect("pcs: external store row-combination"));
            }
            m
        }
    };
    let padf = fold_rows_host(&cmz.pads, rows, q, q, 1, rhos);
    msg.into_iter().zip(padf.into_iter()).map(|(mut m, p)| { m.extend(p); m }).collect()
}

/// THE MASK-SITE ASSERTION: every opening site carries a mask —
/// every group's combined row weights touch at least one mask row with a
/// nonzero coefficient, the proximity rho touches the reserved prox mask
/// row, and the pads cover the opened columns. Returns the sites.
pub fn assert_mask_sites<E>(cmz: &CommittedZk<E>, rhos: &[Vec<Fp2>]) -> Vec<String> {
    let mut sites = Vec::new();
    let g = rhos.len() - 1;
    for (gi, rho) in rhos[..g].iter().enumerate() {
        let masked: Vec<usize> = cmz.mask_rows.iter().copied().filter(|&r| !rho[r].is_zero()).collect();
        assert!(!masked.is_empty(), "zk pcs: group {gi}'s clear vector has no mask row (unmasked opening site)");
        sites.push(format!("group vector {gi}: mask rows {:?}", masked));
    }
    let pm = cmz.prox_mask_row.expect("zk pcs: no proximity mask row reserved");
    assert!(!rhos[g][pm].is_zero(), "zk pcs: the proximity vector does not touch the prox mask row");
    sites.push(format!("proximity vector: prox mask row {pm} (+ every mask row with its random rho)"));
    assert!(cmz.zk.q_pad >= cmz.cm.params.num_col_checks);
    sites.push(format!("{} opened columns: {} pad symbols per row on the coset (no systematic position)", cmz.cm.params.num_col_checks, cmz.zk.q_pad));
    sites.push(format!("{} Merkle leaves salted", cmz.salts.len()));
    sites
}

thread_local! {
    static LAST_SITES: std::cell::RefCell<Vec<String>> = const { std::cell::RefCell::new(Vec::new()) };
}

/// The mask sites recorded by the last `open_zk` on this thread (for the driver's report).
pub fn last_mask_sites() -> Vec<String> {
    LAST_SITES.with(|s| s.borrow().clone())
}

/// The number of column-weight groups the claims form (for the record).
pub fn zk_groups_for_record<E>(cmz: &CommittedZk<E>, claims: &[ZClaim]) -> usize {
    group_zclaims(claims, cmz.cm.rows, cmz.cm.params.log_cols).len()
}

/// Prover: open ZK claims. Transcript order as `open`: lambdas per group
/// -> group vectors absorbed -> prox rho -> prox vector absorbed ->
/// column indices.
pub fn open_zk<E: EncodedStore>(cmz: &CommittedZk<E>, claims: &[ZClaim], tr: &mut Transcript) -> OpeningZk {
    let cm = &cmz.cm;
    let rows = cm.rows;
    let groups = group_zclaims(claims, rows, cm.params.log_cols);
    let (rhos, _wants) = zk_rhos(&groups, rows, tr);
    let sites = assert_mask_sites(cmz, &rhos);
    LAST_SITES.with(|s| *s.borrow_mut() = sites);
    let mut vecs = fold_rows_multi_zk(cmz, &rhos);
    let prox_vec = vecs.pop().unwrap();
    for v in &vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    tr.absorb_fp2(b"pcs-prox", &prox_vec);
    let idx = tr.challenge_indices(cm.params.num_col_checks, cm.params.enc_cols());
    let nn = cm.params.enc_cols();
    let columns: Vec<(usize, Vec<Fp>, [u8; 32], Vec<Digest>)> = match &cm.store {
        Store::Host { encoded } => idx
            .par_iter()
            .map(|&j| {
                let col: Vec<Fp> = (0..rows).map(|i| encoded[i * nn + j]).collect();
                (j, col, cmz.salts[j], cm.tree.path(j))
            })
            .collect(),
        Store::Device(dc) => {
            let cols = dc.columns(&idx).expect("pcs: external store column gather");
            idx.iter().zip(cols.into_iter()).map(|(&j, col)| (j, col, cmz.salts[j], cm.tree.path(j))).collect()
        }
    };
    OpeningZk { group_vecs: vecs, prox_vec, columns }
}

/// Verifier of a ZK opening.
pub fn verify_zk(
    params: &PcsParams,
    zk: &ZkOpts,
    cm: &Commitment,
    claims: &[ZClaim],
    opening: &OpeningZk,
    ntt: &NttTables,
    tr: &mut Transcript,
) -> Result<(), String> {
    let rows = cm.rows;
    let n = params.cols();
    let nn = params.enc_cols();
    let q = zk.q_pad;
    if cm.log_cols != params.log_cols {
        return Err("pcs zk: log_cols mismatch".into());
    }
    if q < params.num_col_checks {
        return Err("pcs zk: fewer pads than column checks".into());
    }
    let groups = group_zclaims(claims, rows, params.log_cols);
    if opening.group_vecs.len() != groups.len() {
        return Err(format!("pcs zk: {} group vectors for {} groups", opening.group_vecs.len(), groups.len()));
    }
    let (rhos, wants) = zk_rhos(&groups, rows, tr);
    for (g, (cw, _)) in groups.iter().enumerate() {
        let v = &opening.group_vecs[g];
        if v.len() != n + q {
            return Err(format!("pcs zk: group vector {g} has length {}", v.len()));
        }
        let got = v[..n].iter().zip(cw.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
        if got != wants[g] {
            return Err(format!("pcs zk: group {g}: <v, c> != combined claim"));
        }
    }
    for v in &opening.group_vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if opening.prox_vec.len() != n + q {
        return Err("pcs zk: prox vector length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    let idx = tr.challenge_indices(params.num_col_checks, nn);
    if opening.columns.len() != idx.len() {
        return Err("pcs zk: wrong number of columns".into());
    }
    let pows = coset_powers(zk.coset, nn);
    let mut all_vecs: Vec<&Vec<Fp2>> = opening.group_vecs.iter().collect();
    all_vecs.push(&opening.prox_vec);
    let encoded_vecs: Vec<(Vec<Fp>, Vec<Fp>)> = all_vecs
        .par_iter()
        .map(|v| {
            let re: Vec<Fp> = v.iter().map(|x| x.c0).collect();
            let im: Vec<Fp> = v.iter().map(|x| x.c1).collect();
            let mut ere = vec![Fp::ZERO; nn];
            let mut eim = vec![Fp::ZERO; nn];
            encode_row_zk(ntt, &re[..n], &re[n..], &pows, &mut ere);
            encode_row_zk(ntt, &im[..n], &im[n..], &pows, &mut eim);
            (ere, eim)
        })
        .collect();
    let results: Vec<Result<(), String>> = opening
        .columns
        .par_iter()
        .zip(idx.par_iter())
        .map(|((j, col, salt, path), &want_j)| {
            if *j != want_j {
                return Err(format!("pcs zk: column index {j} != sampled {want_j}"));
            }
            if col.len() != rows {
                return Err("pcs zk: column length".into());
            }
            let leaf = salt_leaf(&hash_column(col), salt);
            if !MerkleTree::verify_path(&cm.root, *j, &leaf, path) {
                return Err(format!("pcs zk: Merkle path for column {j} fails"));
            }
            for (g, rho) in rhos.iter().enumerate() {
                let mut acc = Fp2::ZERO;
                for i in 0..rows {
                    acc = acc.add(rho[i].mul_base(col[i]));
                }
                let (ere, eim) = &encoded_vecs[g];
                let want = Fp2::new(ere[*j], eim[*j]);
                if acc != want {
                    return Err(format!("pcs zk: column {j} disagrees with clear vector {g}"));
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

/// **[A26] `HL_A26_PCS_SPARSE`** (default on; `0`: every row, the column loop before A26).
/// `verify_zk_tagged`'s column test combines each opened column with every group's row
/// weights `rho_g` (and the proximity weights). A group's weights are zero outside the rows
/// of its claims' slices (`zpart_weights`), so most of them are zero. With the switch on,
/// each `rho_g`'s nonzero rows are listed once for all the opened columns and a column's
/// combination sums over them only. A zero weight adds nothing (`0 * x = 0`) and field
/// addition is exact, so every combination is the same field element as the full loop's:
/// the same comparisons, the same verdict, the same refusal and message.
fn a26_pcs_sparse() -> bool {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *ON.get_or_init(|| std::env::var("HL_A26_PCS_SPARSE").map(|v| v != "0").unwrap_or(true))
}

/// [A26] for each row weight, its nonzero rows when they are at most half of its rows (a
/// denser weight, such as the proximity one, keeps the full loop: `None`)
fn a26_supports(rhos: &[Vec<Fp2>]) -> Vec<Option<Vec<u32>>> {
    if !a26_pcs_sparse() {
        return vec![None; rhos.len()];
    }
    rhos.par_iter()
        .map(|rho| {
            let nz: Vec<u32> = rho.iter().enumerate().filter(|(_, x)| !x.is_zero()).map(|(i, _)| i as u32).collect();
            (2 * nz.len() <= rho.len()).then_some(nz)
        })
        .collect()
}

/// [A26] `sum_{i < rows} rho[i] * col[i]`: over every row (`support` `None`, the loop before
/// A26), or over `support`, exactly the rows where `rho` is nonzero (the same field element)
#[inline]
fn a26_combine(rho: &[Fp2], col: &[Fp], rows: usize, support: Option<&[u32]>) -> Fp2 {
    let mut acc = Fp2::ZERO;
    match support {
        Some(ix) => {
            for &i in ix {
                acc = acc.add(rho[i as usize].mul_base(col[i as usize]));
            }
        }
        None => {
            for i in 0..rows {
                acc = acc.add(rho[i].mul_base(col[i]));
            }
        }
    }
    acc
}

/// [ZK60 D19, ruling T-1] `verify_zk` under a [`HashTag`]. `verify_zk` above
/// keeps its own body.
///
/// **The tag is the CALLER's, from the profile it trusts.** Nothing read out
/// of a receipt or a capture selects or carries a key (ruling T-7): the
/// `opening` argument is untrusted bytes and is never consulted about the
/// rule.
///
/// **It also checks the Merkle path LENGTH**, which `verify_zk` does not
/// (`merkle.rs`'s `verify_path` folds however many siblings it is handed).
/// This is new code with no legacy byte at stake, so the check the
/// disposition asks the integrator for is simply in it from the start: a
/// path must have exactly `log2(enc_cols)` entries. It rejects no honest
/// proof — an honest path is `tree.path(j)`, whose length is the tree's depth
/// — and it is what stops an inner node being presented as a salted leaf
/// under a short path. **It is the FIRST line, under a tag too** (D63 L3
/// finding F9): separate leaf and node keys stop a node posing as a salted
/// leaf, but not genuine salted leaves sitting at two depths of one tree,
/// which opens one position to two columns with no collision
/// (`formal/ZK60Formal/SoundMerkle.lean`, `mixed_depth_opens`). Without the
/// length check this function would not be binding.
pub fn verify_zk_tagged(
    params: &PcsParams,
    zk: &ZkOpts,
    cm: &Commitment,
    claims: &[ZClaim],
    opening: &OpeningZk,
    ntt: &NttTables,
    tr: &mut Transcript,
    tag: &HashTag,
) -> Result<(), String> {
    let rows = cm.rows;
    let n = params.cols();
    let nn = params.enc_cols();
    let q = zk.q_pad;
    if cm.log_cols != params.log_cols {
        return Err("pcs zk: log_cols mismatch".into());
    }
    if q < params.num_col_checks {
        return Err("pcs zk: fewer pads than column checks".into());
    }
    // the tree over `nn` salted leaves is `log2(nn)` deep, and `nn` is a
    // power of two by `enc_cols`'s construction
    let depth = nn.trailing_zeros() as usize;
    for (at, (_, _, _, path)) in opening.columns.iter().enumerate() {
        if path.len() != depth {
            return Err(format!("pcs zk: opened column {at} carries a Merkle path of {} entries; this commitment's tree is {depth} deep", path.len()));
        }
    }
    let groups = group_zclaims(claims, rows, params.log_cols);
    if opening.group_vecs.len() != groups.len() {
        return Err(format!("pcs zk: {} group vectors for {} groups", opening.group_vecs.len(), groups.len()));
    }
    let (rhos, wants) = zk_rhos(&groups, rows, tr);
    for (g, (cw, _)) in groups.iter().enumerate() {
        let v = &opening.group_vecs[g];
        if v.len() != n + q {
            return Err(format!("pcs zk: group vector {g} has length {}", v.len()));
        }
        let got = v[..n].iter().zip(cw.iter()).fold(Fp2::ZERO, |a, (x, y)| a.add(x.mul(*y)));
        if got != wants[g] {
            return Err(format!("pcs zk: group {g}: <v, c> != combined claim"));
        }
    }
    for v in &opening.group_vecs {
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if opening.prox_vec.len() != n + q {
        return Err("pcs zk: prox vector length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &opening.prox_vec);
    let idx = tr.challenge_indices(params.num_col_checks, nn);
    if opening.columns.len() != idx.len() {
        return Err("pcs zk: wrong number of columns".into());
    }
    let pows = coset_powers(zk.coset, nn);
    let mut all_vecs: Vec<&Vec<Fp2>> = opening.group_vecs.iter().collect();
    all_vecs.push(&opening.prox_vec);
    let encoded_vecs: Vec<(Vec<Fp>, Vec<Fp>)> = all_vecs
        .par_iter()
        .map(|v| {
            let re: Vec<Fp> = v.iter().map(|x| x.c0).collect();
            let im: Vec<Fp> = v.iter().map(|x| x.c1).collect();
            let mut ere = vec![Fp::ZERO; nn];
            let mut eim = vec![Fp::ZERO; nn];
            encode_row_zk(ntt, &re[..n], &re[n..], &pows, &mut ere);
            encode_row_zk(ntt, &im[..n], &im[n..], &pows, &mut eim);
            (ere, eim)
        })
        .collect();
    // [A26] each combined row weight's nonzero rows, found once for all the opened columns
    let supports = a26_supports(&rhos);
    let results: Vec<Result<(), String>> = opening
        .columns
        .par_iter()
        .zip(idx.par_iter())
        .map(|((j, col, salt, path), &want_j)| {
            if *j != want_j {
                return Err(format!("pcs zk: column index {j} != sampled {want_j}"));
            }
            if col.len() != rows {
                return Err("pcs zk: column length".into());
            }
            let leaf = salt_leaf_keyed(&hash_column_keyed(col, tag.column_key()), salt, tag.leaf_key());
            if !MerkleTree::verify_path_keyed(&cm.root, *j, &leaf, path, tag.node_key()) {
                return Err(format!("pcs zk: Merkle path for column {j} fails"));
            }
            for (g, rho) in rhos.iter().enumerate() {
                let acc = a26_combine(rho, col, rows, supports[g].as_deref());
                let (ere, eim) = &encoded_vecs[g];
                let want = Fp2::new(ere[*j], eim[*j]);
                if acc != want {
                    return Err(format!("pcs zk: column {j} disagrees with clear vector {g}"));
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
mod zk_tests {
    use super::*;
    use crate::mle::eval_mle_base;

    fn params() -> PcsParams {
        PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 12 }
    }

    /// Low-entropy "activation-like" data: int8 values from a seeded LCG.
    fn data(seed: u64, len: usize) -> Vec<Fp> {
        let mut s = seed;
        (0..len).map(|_| { s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407); Fp::from_i64(((s >> 33) % 256) as i64 - 128) }).collect()
    }

    fn pt(seed: u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|i| Fp2::new(Fp::new(seed * 1000 + i as u64 * 7 + 3), Fp::new(seed + i as u64 * 11 + 5))).collect()
    }

    /// The test rig: a private slice P (2^8 = 16 rows) opened at a point
    /// through the masked combined claim (1-e) P~(r) + e <R, eq(r_col)>,
    /// a private sub-row slice S (2^3 entries of one row) opened with its
    /// own mask, a zero-sum mask row for a sum claim, a prox mask row.
    fn rig(seed: u64, zk_seed: u64) -> (CommittedZk, Vec<ZClaim>, OpeningZk, Vec<Fp2>) {
        let p = params();
        let n = p.cols();
        let ntt = NttTables::new(10);
        let mut rng = ZkRng::new(zk_seed, b"pcs-test");
        // layout: P at 0 (256), S at 256 (8 entries of row 16), mask R_P row 17, mask R_S row 18, zero-sum u row 19, prox mask row 20
        let mut d = data(seed, 21 * n);
        for i in 0..8 { d[256 + i] = Fp::from_i64((i as i64 * 37 + seed as i64) % 100); }
        for i in 8..n { d[256 + i] = Fp::ZERO; }
        for r in [17usize, 18, 20] { for j in 0..n { d[r * n + j] = rng.fp(); } }
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 { let v = rng.fp(); d[19 * n + j] = v; sum = sum.add(v); }
        d[19 * n + n - 1] = sum.neg();
        let zk = ZkOpts::standard(&p);
        let mut cmz = commit_zk(&p, &d, &ntt, &zk, &mut rng);
        cmz.mask_rows = vec![17, 18, 19];
        cmz.prox_mask_row = Some(20);
        let r = pt(3, 8);
        let e = Fp2::new(Fp::new(99991), Fp::new(7));
        let s_pt = pt(5, 3);
        let e2 = Fp2::new(Fp::new(4242), Fp::new(17));
        let vp = eval_mle_base(&d[0..256], &r);
        let vr = eval_mle_base(&d[17 * n..18 * n], &r[4..]);
        let vs = eval_mle_base(&d[256..264], &s_pt);
        let vrs = eval_mle_base(&d[18 * n..18 * n + 8], &s_pt);
        let claims = vec![
            ZClaim { parts: vec![
                ZPart { slice: Slice { offset: 0, log_size: 8 }, coef: Fp2::ONE.sub(e), point: r.clone() },
                ZPart { slice: Slice { offset: 17 * n, log_size: 4 }, coef: e, point: r[4..].to_vec() },
            ], value: Fp2::ONE.sub(e).mul(vp).add(e.mul(vr)) },
            ZClaim { parts: vec![
                ZPart { slice: Slice { offset: 256, log_size: 3 }, coef: Fp2::ONE.sub(e2), point: s_pt.clone() },
                ZPart { slice: Slice { offset: 18 * n, log_size: 3 }, coef: e2, point: s_pt.clone() },
            ], value: Fp2::ONE.sub(e2).mul(vs).add(e2.mul(vrs)) },
            // the sum of the zero-sum row plus the sum of P minus P's sum = 0: a value-0 sum claim over P, -P (as a constant) and u
            ZClaim { parts: vec![
                ZPart { slice: Slice { offset: 19 * n, log_size: 4 }, coef: Fp2::ONE, point: vec![] },
            ], value: Fp2::ZERO },
        ];
        let mut tp = Transcript::new(b"pcs-zk");
        let op = open_zk(&cmz, &claims, &mut tp);
        (cmz, claims, op, r)
    }

    #[test]
    fn zk_commit_open_verify_and_tampers() {
        let p = params();
        let ntt = NttTables::new(10);
        let zk = ZkOpts::standard(&p);
        let (cmz, claims, op, _) = rig(1, 11);
        let com = cmz.commitment();
        let mut tv = Transcript::new(b"pcs-zk");
        verify_zk(&p, &zk, &com, &claims, &op, &ntt, &mut tv).unwrap();
        // wrong claimed value
        let mut bad = claims.clone();
        bad[0].value = bad[0].value.add(Fp2::ONE);
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &com, &bad, &op, &ntt, &mut tv).is_err());
        // a zero-sum row that does not sum to zero is caught by the sum claim
        let mut bad = claims.clone();
        bad[2].value = Fp2::ONE;
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &com, &bad, &op, &ntt, &mut tv).is_err());
        // tampered clear vector (message part) and (pad part)
        for k in [3usize, 16 + 5] {
            let mut op3 = op.clone();
            op3.group_vecs[0][k] = op3.group_vecs[0][k].add(Fp2::ONE);
            let mut tv = Transcript::new(b"pcs-zk");
            assert!(verify_zk(&p, &zk, &com, &claims, &op3, &ntt, &mut tv).is_err());
        }
        // tampered salt / column entry
        let mut op4 = op.clone();
        op4.columns[0].2[0] ^= 1;
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &com, &claims, &op4, &ntt, &mut tv).is_err());
        let mut op5 = op.clone();
        op5.columns[1].1[2] = op5.columns[1].1[2].add(Fp::ONE);
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &com, &claims, &op5, &ntt, &mut tv).is_err());
        // a different witness with the same claims: root mismatch
        let (cmz2, _, op2, _) = rig(2, 11);
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &com, &claims, &op2, &ntt, &mut tv).is_err());
        let mut tv = Transcript::new(b"pcs-zk");
        assert!(verify_zk(&p, &zk, &cmz2.commitment(), &claims, &op2, &ntt, &mut tv).is_err());
    }

    /// Chi-square of the top byte of every value against uniform (256 bins).
    fn chi2_top_byte(vals: &[u64]) -> f64 {
        let mut bins = [0f64; 256];
        for v in vals { bins[(v >> 56) as usize] += 1.0; }
        let e = vals.len() as f64 / 256.0;
        bins.iter().map(|b| (b - e) * (b - e) / e).sum()
    }

    /// THE UNIFORMITY TEST: two runs with different (low-entropy, int8)
    /// witnesses and the same claim structure; every opened column entry
    /// and every clear-vector entry is a fresh field element: (1) all
    /// values distinct across the two runs (no repeat of a witness
    /// value, no repeat between runs); (2) the top byte of the opened
    /// symbols and of the clear vectors passes a chi-square against
    /// uniform at 256 bins (critical value 310.5 at p = 0.01, df 255);
    /// (3) the two runs' opened distributions are not distinguishable
    /// by the same statistic (two-sample chi-square); (4) the mask-site
    /// assertion ran at every site (enumerated in the output). Also the
    /// contrast: the NON-zk commitment of the same data opens raw int8
    /// values (its columns fail (2) decisively).
    #[test]
    fn zk_openings_are_uniform_and_every_site_is_masked() {
        let p = params();
        let n = p.cols();
        let mut cols_a: Vec<u64> = Vec::new();
        let mut cols_b: Vec<u64> = Vec::new();
        let mut vecs_a: Vec<u64> = Vec::new();
        let mut vecs_b: Vec<u64> = Vec::new();
        // many independent openings (fresh pads/masks/salts per zk seed) so the statistic has power
        for t in 0..40u64 {
            let (cmz_a, ca, op_a, _) = rig(1, 100 + t);
            let (_, _, op_b, _) = rig(2, 200 + t);
            if t == 0 {
                let groups = group_zclaims(&ca, cmz_a.cm.rows, p.log_cols);
                let mut tr = Transcript::new(b"pcs-zk");
                let (rhos, _) = zk_rhos(&groups, cmz_a.cm.rows, &mut tr);
                let sites = assert_mask_sites(&cmz_a, &rhos);
                println!("mask sites:");
                for s in &sites { println!("  {s}"); }
                assert_eq!(sites.len(), groups.len() + 3);
            }
            // (a column index sampled twice in one opening repeats by construction: count each column once)
            let mut seen = std::collections::HashSet::new();
            for (j, col, _, _) in &op_a.columns { if seen.insert(*j) { cols_a.extend(col.iter().map(|x| x.0)); } }
            seen.clear();
            for (j, col, _, _) in &op_b.columns { if seen.insert(*j) { cols_b.extend(col.iter().map(|x| x.0)); } }
            for v in op_a.group_vecs.iter().chain(std::iter::once(&op_a.prox_vec)) { vecs_a.extend(v.iter().flat_map(|x| [x.c0.0, x.c1.0])); }
            for v in op_b.group_vecs.iter().chain(std::iter::once(&op_b.prox_vec)) { vecs_b.extend(v.iter().flat_map(|x| [x.c0.0, x.c1.0])); }
        }
        // (1) distinct, and no small (witness-range) values
        let mut all: Vec<u64> = cols_a.iter().chain(cols_b.iter()).chain(vecs_a.iter()).chain(vecs_b.iter()).copied().collect();
        let total = all.len();
        all.sort_unstable();
        all.dedup();
        assert_eq!(all.len(), total, "repeated opened values");
        assert!(all.iter().all(|&v| v > 1u64 << 40 && v < crate::field::P - (1u64 << 40)), "an opened value in the witness range");
        // (2) chi-square vs uniform, top byte, 256 bins
        for (name, v) in [("columns A", &cols_a), ("columns B", &cols_b), ("clear vectors A", &vecs_a), ("clear vectors B", &vecs_b)] {
            let c = chi2_top_byte(v);
            println!("chi2 {name}: {c:.1} over {} values (df 255; 310.5 at p = 0.01)", v.len());
            assert!(c < 310.5, "{name}: chi2 {c} vs uniform");
        }
        // (3) two-sample: the union's bins vs each run (the runs are not distinguishable by the statistic)
        let mut bins_a = [0f64; 256];
        let mut bins_b = [0f64; 256];
        for v in &cols_a { bins_a[(v >> 56) as usize] += 1.0; }
        for v in &cols_b { bins_b[(v >> 56) as usize] += 1.0; }
        let (na, nb) = (cols_a.len() as f64, cols_b.len() as f64);
        let mut c2 = 0.0;
        for i in 0..256 {
            let e = (bins_a[i] + bins_b[i]) / (na + nb);
            let (ea, eb) = (e * na, e * nb);
            if ea > 0.0 { c2 += (bins_a[i] - ea).powi(2) / ea + (bins_b[i] - eb).powi(2) / eb; }
        }
        println!("two-sample chi2 columns A vs B: {c2:.1} (df 255)");
        assert!(c2 < 310.5);
        // the contrast: the non-zk commitment of the same data opens raw witness values at its systematic columns
        let ntt = NttTables::new(10);
        let d = data(1, 21 * n);
        let cm = commit(&p, &d, &ntt);
        let sa = Slice { offset: 0, log_size: 8 };
        let r = pt(3, 8);
        let cl = vec![Claim { parts: vec![(sa, Fp2::ONE)], point: r.clone(), sum: false, value: eval_mle_base(&d[0..256], &r) }];
        let mut tp = Transcript::new(b"pcs");
        let op = open(&cm, &cl, &mut tp);
        let raw: usize = op.columns.iter().flat_map(|(_, col, _)| col.iter()).filter(|x| x.0 < 256 || x.0 > crate::field::P - 256).count();
        println!("non-zk contrast: {raw} of {} opened entries are raw int8 values", op.columns.len() * cm.rows);
        assert!(raw > 0);
    }
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

/// [ZK60 D19, ruling T-6] **The isolated layer controls of the tag.** Each
/// test below pins ONE hash layer on its own, so that a cross-rule rejection
/// somewhere higher up cannot be mistaken for evidence that a particular
/// layer is keyed.
#[cfg(test)]
mod tag_tests {
    use super::*;
    use crate::hashtag::HashTag;
    use crate::mle::eval_mle_base;

    const RUNG_G: &str = "hashline-zk-mr1/private-block-rung-g-t24-dev/1";

    fn tparams() -> PcsParams {
        PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 12 }
    }

    fn vals(seed: u64, len: usize) -> Vec<Fp> {
        let mut s = seed;
        (0..len)
            .map(|_| {
                s = s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
                Fp::from_i64(((s >> 33) % 256) as i64 - 128)
            })
            .collect()
    }

    fn point(seed: u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|i| Fp2::new(Fp::new(seed * 1000 + i as u64 * 7 + 3), Fp::new(seed + i as u64 * 11 + 5))).collect()
    }

    /// Three rows: the private row 0, its mask row 1, the proximity mask row
    /// 2. One claim, opened through the masked combination, which is the
    /// smallest structure `open_zk`'s mask-site assertion accepts.
    fn rig(tag: &HashTag, zk_seed: u64) -> (CommittedZk, Vec<ZClaim>, OpeningZk) {
        let p = tparams();
        let n = p.cols();
        let ntt = NttTables::new(8);
        let mut rng = ZkRng::new(zk_seed, b"pcs-tag-test");
        let mut d = vals(7, 3 * n);
        for r in [1usize, 2] {
            for j in 0..n {
                d[r * n + j] = rng.fp();
            }
        }
        let zk = ZkOpts::standard(&p);
        let mut cmz = commit_zk_owned_with_tag(&Cpu, &p, d.clone(), &ntt, &zk, &mut rng, tag);
        cmz.mask_rows = vec![1];
        cmz.prox_mask_row = Some(2);
        let r = point(3, 4);
        let e = Fp2::new(Fp::new(99991), Fp::new(7));
        let vp = eval_mle_base(&d[0..n], &r);
        let vr = eval_mle_base(&d[n..2 * n], &r);
        let claims = vec![ZClaim {
            parts: vec![
                ZPart { slice: Slice { offset: 0, log_size: 4 }, coef: Fp2::ONE.sub(e), point: r.clone() },
                ZPart { slice: Slice { offset: n, log_size: 4 }, coef: e, point: r.clone() },
            ],
            value: Fp2::ONE.sub(e).mul(vp).add(e.mul(vr)),
        }];
        let mut tp = Transcript::new(b"pcs-tag");
        let op = open_zk(&cmz, &claims, &mut tp);
        (cmz, claims, op)
    }

    /// **The leaf/node ambiguity, written down.** Under the LEGACY rule a
    /// salted leaf and a Merkle inner node are literally the same function on
    /// the same 64 bytes; under a tag they are not.
    #[test]
    fn a_salted_leaf_is_a_merkle_node_under_the_legacy_rule_and_is_not_under_a_tag() {
        let (a, b) = ([11u8; 32], [22u8; 32]);
        assert_eq!(salt_leaf(&a, &b), crate::merkle::hash_pair(&a, &b), "the legacy leaf/node ambiguity has changed");
        let t = HashTag::for_profile(RUNG_G);
        assert_ne!(salt_leaf_keyed(&a, &b, t.leaf_key()), crate::merkle::hash_pair_keyed(&a, &b, t.node_key()), "the leaf and node keys did not separate the two");
        // and each keyed form differs from the legacy one
        assert_ne!(salt_leaf_keyed(&a, &b, t.leaf_key()), salt_leaf(&a, &b));
        assert_ne!(crate::merkle::hash_pair_keyed(&a, &b, t.node_key()), crate::merkle::hash_pair(&a, &b));
    }

    /// **The column digest's isolated control**: right key, another role's
    /// key, no key — pairwise different, both singly and through
    /// `hash_columns_keyed`.
    #[test]
    fn a_column_digest_under_three_rules_is_three_digests() {
        let t = HashTag::for_profile(RUNG_G);
        let col = vals(5, 9);
        let right = hash_column_keyed(&col, t.column_key());
        let wrong = hash_column_keyed(&col, t.node_key());
        let none = hash_column_keyed(&col, None);
        assert_eq!(none, hash_column(&col), "the unkeyed keyed-variant is not the legacy column digest");
        assert_ne!(right, wrong);
        assert_ne!(right, none);
        assert_ne!(wrong, none);
        // the tiled commit path agrees with the single-column one, under a key
        let (rows, nn) = (3usize, 8usize);
        let enc = vals(9, rows * nn);
        let keyed = hash_columns_keyed(&enc, rows, nn, t.column_key());
        let plain = hash_columns(&enc, rows, nn);
        for j in 0..nn {
            let c: Vec<Fp> = (0..rows).map(|i| enc[i * nn + j]).collect();
            assert_eq!(keyed[j], hash_column_keyed(&c, t.column_key()), "tiled != single, keyed");
            assert_eq!(plain[j], hash_column(&c), "tiled != single, legacy");
            assert_ne!(keyed[j], plain[j], "the key did not change column {j}");
        }
        assert_eq!(hash_columns_keyed(&enc, rows, nn, None), plain, "hash_columns_keyed(None) is not hash_columns");
    }

    /// **[A26] the sparse column combination is the full loop's field element.** Row weights
    /// with zeros (a group's rho off its claims' rows), with `p - 1` entries and with every
    /// row nonzero; columns with zeros, `p - 1` and random words. `a26_supports` lists exactly
    /// the nonzero rows of a weight at most half nonzero, and `None` (the full loop) above that.
    #[test]
    fn a26_sparse_column_combination_equals_the_full_loop() {
        let pm1 = Fp::ZERO.sub(Fp::ONE);
        for rows in [1usize, 2, 7, 64, 333] {
            let col: Vec<Fp> = (0..rows).map(|i| match i % 5 { 0 => Fp::ZERO, 1 => pm1, _ => Fp::new((i as u64).wrapping_mul(0x9e37_79b9_7f4a_7c15)) }).collect();
            for density in [0usize, 1, 3, 10] {
                // nonzero on rows i with i % 10 < density (density 10: every row)
                let rho: Vec<Fp2> = (0..rows)
                    .map(|i| if i % 10 < density { if i % 3 == 0 { Fp2::new(pm1, pm1) } else { point(i as u64 + 9, 1)[0] } } else { Fp2::ZERO })
                    .collect();
                let sup = a26_supports(std::slice::from_ref(&rho)).pop().unwrap();
                let nz: Vec<u32> = (0..rows as u32).filter(|&i| !rho[i as usize].is_zero()).collect();
                if 2 * nz.len() <= rows {
                    assert_eq!(sup.as_deref(), Some(nz.as_slice()), "rows {rows} density {density}: the support");
                } else {
                    assert!(sup.is_none(), "rows {rows} density {density}: a dense weight keeps the full loop");
                }
                let full = a26_combine(&rho, &col, rows, None);
                assert_eq!(a26_combine(&rho, &col, rows, Some(&nz)), full, "rows {rows} density {density}");
                assert_eq!(a26_combine(&rho, &col, rows, sup.as_deref()), full, "rows {rows} density {density}: as used");
            }
        }
    }

    /// The tagged round trip: commit, open, verify under the SAME tag.
    #[test]
    fn a_tagged_commitment_opens_and_verifies_under_its_own_tag() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let tag = HashTag::for_profile(RUNG_G);
        let (cmz, claims, op) = rig(&tag, 31);
        let mut tv = Transcript::new(b"pcs-tag");
        verify_zk_tagged(&p, &zk, &cmz.commitment(), &claims, &op, &ntt, &mut tv, &tag).expect("the tagged opening verifies under its own tag");
    }

    /// **Cross-rule rejection at the PCS layer, both directions.** The
    /// transcript here is the same in both runs, so what is isolated is the
    /// commitment's own hashing: the refusal must be the Merkle one.
    #[test]
    fn a_tagged_commitment_is_refused_under_the_legacy_rule_and_the_reverse() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let tag = HashTag::for_profile(RUNG_G);
        let (cmz, claims, op) = rig(&tag, 41);
        let mut tv = Transcript::new(b"pcs-tag");
        let e = verify_zk(&p, &zk, &cmz.commitment(), &claims, &op, &ntt, &mut tv).expect_err("a tagged opening verified under the legacy rule");
        assert!(e.contains("Merkle path"), "the legacy verifier's refusal of a tagged opening: {e}");
        let (cmz2, claims2, op2) = rig(&HashTag::legacy(), 41);
        let mut tv = Transcript::new(b"pcs-tag");
        let e = verify_zk_tagged(&p, &zk, &cmz2.commitment(), &claims2, &op2, &ntt, &mut tv, &tag).expect_err("a legacy opening verified under a tag");
        assert!(e.contains("Merkle path"), "the tagged verifier's refusal of a legacy opening: {e}");
        // and the legacy round trip still works, unchanged
        let mut tv = Transcript::new(b"pcs-tag");
        verify_zk(&p, &zk, &cmz2.commitment(), &claims2, &op2, &ntt, &mut tv).expect("the legacy round trip moved");
    }

    /// **`verify_zk_tagged` refuses a path of the wrong length, by name** —
    /// shorter and longer. `verify_zk` does not; that is the disposition's
    /// finding and the reason the check is in the NEW function only.
    #[test]
    fn the_tagged_verifier_refuses_a_path_of_the_wrong_length() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let tag = HashTag::for_profile(RUNG_G);
        let (cmz, claims, op) = rig(&tag, 51);
        let depth = p.enc_cols().trailing_zeros() as usize;
        assert_eq!(op.columns[0].3.len(), depth, "an honest path is not the tree depth");
        for (what, mutate) in [
            ("short", Box::new(|v: &mut Vec<Digest>| { v.pop(); }) as Box<dyn Fn(&mut Vec<Digest>)>),
            ("long", Box::new(|v: &mut Vec<Digest>| v.push([0u8; 32]))),
        ] {
            let mut bad = op.clone();
            mutate(&mut bad.columns[0].3);
            let mut tv = Transcript::new(b"pcs-tag");
            let e = verify_zk_tagged(&p, &zk, &cmz.commitment(), &claims, &bad, &ntt, &mut tv, &tag).expect_err("a path of the wrong length verified");
            assert!(e.contains("Merkle path of") && e.contains(&format!("tree is {depth} deep")), "the {what} path's refusal: {e}");
        }
    }

    /// The unkeyed backend hook is reserved for legacy commitments. A
    /// tagged commitment can only call the explicit keyed hook.
    struct Counting(std::cell::Cell<usize>);

    impl Backend for Counting {
        type Store = NoExternal;
        fn try_commit_zk(&self, _params: &PcsParams, _data: &[Fp], _pads: &[Fp], _pows: &[Fp], _ntt: &NttTables) -> Option<(Self::Store, Vec<Digest>)> {
            self.0.set(self.0.get() + 1);
            None
        }
    }

    #[test]
    fn a_tagged_commitment_never_calls_the_unkeyed_backend_hook() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let n = p.cols();
        let d = vals(7, 3 * n);
        let b = Counting(std::cell::Cell::new(0));
        let mut rng = ZkRng::new(61, b"pcs-tag-test");
        let _ = commit_zk_owned_with_tag(&b, &p, d.clone(), &ntt, &zk, &mut rng, &HashTag::legacy());
        assert_eq!(b.0.get(), 1, "a LEGACY tagged commitment did not offer its columns to the backend");
        let mut rng = ZkRng::new(61, b"pcs-tag-test");
        let _ = commit_zk_owned_with_tag(&b, &p, d.clone(), &ntt, &zk, &mut rng, &HashTag::for_profile(RUNG_G));
        assert_eq!(b.0.get(), 1, "a TAGGED commitment called the unkeyed backend hook");
        // the legacy entry point is unchanged and still offers
        let mut rng = ZkRng::new(61, b"pcs-tag-test");
        let _ = commit_zk_owned_with(&b, &p, d, &ntt, &zk, &mut rng);
        assert_eq!(b.0.get(), 2, "commit_zk_owned_with stopped offering its columns");
    }

    struct KeyCounting(std::cell::Cell<usize>, std::cell::Cell<[u8; 32]>);
    impl Backend for KeyCounting {
        type Store = NoExternal;
        fn try_commit_zk_keyed(&self, _p: &PcsParams, _d: &[Fp], _pads: &[Fp], _pows: &[Fp], _ntt: &NttTables, key: &[u8; 32]) -> Option<(Self::Store, Vec<Digest>)> {
            self.0.set(self.0.get() + 1);
            self.1.set(*key);
            None
        }
    }

    #[test]
    fn tagged_offer_passes_exact_key_and_decline_keeps_cpu_bytes() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let d = vals(7, 3 * p.cols());
        let tag = HashTag::for_profile(RUNG_G);
        let b = KeyCounting(std::cell::Cell::new(0), std::cell::Cell::new([0; 32]));
        let mut r1 = ZkRng::new(61, b"pcs-tag-test");
        let offered = commit_zk_owned_with_tag(&b, &p, d.clone(), &ntt, &zk, &mut r1, &tag);
        let mut r2 = ZkRng::new(61, b"pcs-tag-test");
        let cpu = commit_zk_owned_with_tag(&Cpu, &p, d, &ntt, &zk, &mut r2, &tag);
        assert_eq!(b.0.get(), 1);
        assert_eq!(&b.1.get(), tag.column_key().unwrap());
        assert_eq!(offered.cm.tree.root(), cpu.cm.tree.root());
        assert_eq!(offered.pads, cpu.pads);
        assert_eq!(offered.salts, cpu.salts);
        assert_eq!(r1.fp(), r2.fp());
    }

    /// The pads and the salts are drawn in the LEGACY order on both paths, so
    /// a tag never moves a generator byte: the same seed gives the same pads
    /// and the same salts under both rules.
    #[test]
    fn the_tag_does_not_move_one_byte_of_the_generator() {
        let (p, ntt, zk) = (tparams(), NttTables::new(8), ZkOpts::standard(&tparams()));
        let n = p.cols();
        let d = vals(7, 3 * n);
        let mut r1 = ZkRng::new(71, b"pcs-tag-test");
        let a = commit_zk_owned_with_tag(&Cpu, &p, d.clone(), &ntt, &zk, &mut r1, &HashTag::legacy());
        let mut r2 = ZkRng::new(71, b"pcs-tag-test");
        let b = commit_zk_owned_with_tag(&Cpu, &p, d.clone(), &ntt, &zk, &mut r2, &HashTag::for_profile(RUNG_G));
        assert_eq!(a.pads, b.pads, "the pads moved under the tag");
        assert_eq!(a.salts, b.salts, "the salts moved under the tag");
        assert_ne!(a.cm.tree.root(), b.cm.tree.root(), "the tag did not change the root");
        // and the legacy entry point produces exactly the legacy tagged one
        let mut r3 = ZkRng::new(71, b"pcs-tag-test");
        let c = commit_zk_owned_with(&Cpu, &p, d, &ntt, &zk, &mut r3);
        assert_eq!(a.cm.tree.root(), c.cm.tree.root(), "commit_zk_owned_with_tag(LEGACY) is not commit_zk_owned_with");
        assert_eq!(a.salts, c.salts);
    }
}
