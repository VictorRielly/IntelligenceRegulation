//! The one-layer statement: prover and verifier.
//!
//! Public statement: layer index, T (rows, a power of two <= 512), the
//! four requant shifts, the frozen SiLU member (bytes + digest).
//! Committed (three Ligero commitments): W = {Wg, Wu, Wd blocks},
//! A = {g8, rg, a8, u8, ru, h8, rh, X blocks, z blocks, rd blocks},
//! H = {LogUp helper columns, re/im}.
//! Proven: gacc = X.Wg and uacc = X.Wu (one batched matmul sumcheck over
//! k' in 2^8 with the three d-blocks summed), dacc = h8.Wd (one matmul
//! sumcheck over k in 2^11 with the three output blocks batched),
//! hh = a8 u8 = 2^sh_h h8 + rh (zero-check), every lookup (g8,a8) in the
//! SiLU table, u8/h8/z in [-128,127], rg/ru/rh/rd in [0, 2^sh) (LogUp
//! with committed helpers h = 1/(alpha - v1) + 1/(alpha - v2), helper
//! identity as a zero-check, helper sums vs the multiplicity side), and
//! the requant identities gacc = 2^sh_g g8 + rg etc. folded LINEARLY
//! into the evaluation claims. Every pending evaluation claim is folded
//! into the two zero-check sumchecks (20-var and 17-var at T = 512) so
//! that A and H are opened at two points only.

use crate::chain::LayerWitness;
use crate::export::{D, F};
use crate::field::{batch_inverse2, Fp, Fp2};
use crate::mle::{eq_point, eq_table_msb, eval_mle_ext, fold_cols_base, fold_cols_i8, fold_rows_i32, fold_rows_i8};
use crate::ntt::NttTables;
use crate::pcs::{self, Claim, Commitment, Opening, PcsParams, Slice};
// [UPERF3-AF] the PCS-selection seam: `pcs_compact::commit` returns the Ligero form (the default,
// byte-identical) or the compact form; one batched compact opening per layer replaces the three.
use crate::pcs_compact::{self, AnyCm};
use crate::sumcheck::{self, SumcheckProof};
use crate::transcript::Transcript;
use rayon::prelude::*;

pub const TAG_SILU: u64 = 1;
pub const TAG_INT8: u64 = 2;
pub fn tag_range(sh: u32) -> u64 {
    16 + sh as u64
}

#[derive(Clone, Debug)]
pub struct Statement {
    pub l: usize,
    pub t_rows: usize,
    pub shifts: (u32, u32, u32, u32),
    pub table: [i8; 256],
    pub table_digest: String,
}

#[derive(Clone, Copy, Debug)]
pub struct LayerParams {
    pub log_cols: u32,
    pub inv_rate: usize,
    pub num_col_checks: usize,
}

impl LayerParams {
    fn pcs_for(&self, min_log_slice: u32) -> PcsParams {
        PcsParams { log_cols: self.log_cols.min(min_log_slice), inv_rate: self.inv_rate, num_col_checks: self.num_col_checks }
    }
}

/// Element offsets of every slice in the three committed vectors.
#[derive(Clone, Debug)]
pub struct Layout {
    pub log_t: u32,
    pub log_tf: u32,
    pub log_tb: u32,
    pub tf: usize,
    pub tb: usize,
    pub g8: usize, pub rg: usize, pub a8: usize, pub u8v: usize, pub ru: usize, pub h8: usize, pub rh: usize,
    pub x: [usize; 3], pub z: [usize; 3], pub rd: [usize; 3],
    pub a_len: usize,
    pub wg: [usize; 3], pub wu: [usize; 3], pub wd: [usize; 3],
    pub w_len: usize,
    pub hg: (usize, usize), pub hu: (usize, usize), pub hh: (usize, usize), pub hz: [(usize, usize); 3],
    pub h_len: usize,
}

pub const LOG_WBLOCK: u32 = 19; // 256 x 2048 or 2048 x 256

impl Layout {
    pub fn new(t_rows: usize) -> Layout {
        assert!(t_rows.is_power_of_two() && t_rows <= 512);
        let log_t = t_rows.trailing_zeros();
        let tf = t_rows * F;
        let tb = t_rows * 256;
        let x = [7 * tf, 7 * tf + tb, 7 * tf + 2 * tb];
        let z = [7 * tf + 3 * tb, 7 * tf + 4 * tb, 7 * tf + 5 * tb];
        let rd = [7 * tf + 6 * tb, 7 * tf + 7 * tb, 7 * tf + 8 * tb];
        let wb = 1usize << LOG_WBLOCK;
        let hz = [(6 * tf, 6 * tf + tb), (6 * tf + 2 * tb, 6 * tf + 3 * tb), (6 * tf + 4 * tb, 6 * tf + 5 * tb)];
        Layout {
            log_t, log_tf: log_t + 11, log_tb: log_t + 8, tf, tb,
            g8: 0, rg: tf, a8: 2 * tf, u8v: 3 * tf, ru: 4 * tf, h8: 5 * tf, rh: 6 * tf,
            x, z, rd, a_len: 7 * tf + 9 * tb,
            wg: [0, wb, 2 * wb], wu: [3 * wb, 4 * wb, 5 * wb], wd: [6 * wb, 7 * wb, 8 * wb], w_len: 9 * wb,
            hg: (0, tf), hu: (2 * tf, 3 * tf), hh: (4 * tf, 5 * tf), hz, h_len: 6 * tf + 6 * tb,
        }
    }
    fn s_tf(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_tf } }
    fn s_tb(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_tb } }
    fn s_w(&self, off: usize) -> Slice { Slice { offset: off, log_size: LOG_WBLOCK } }
}

#[derive(Clone, Debug, Default)]
pub struct LayerProof {
    pub w_com: Option<Commitment>,
    pub a_com: Option<Commitment>,
    pub h_com: Option<Commitment>,
    pub mults: Vec<(u64, Vec<u32>)>,
    pub gu_claims: Vec<Fp2>,
    pub gu_sc: SumcheckProof,
    pub gu_term: Vec<Fp2>,
    pub d_claims: Vec<Fp2>,
    pub d_sc: SumcheckProof,
    pub d_term: Vec<Fp2>,
    pub zc20_sc: SumcheckProof,
    pub zc20_term: Vec<Fp2>,
    pub zc17_sc: SumcheckProof,
    pub zc17_term: Vec<Fp2>,
    pub helper_sums: Vec<Fp2>,
    pub w_open: Opening,
    pub a_open: Opening,
    pub h_open: Opening,
    /// [UPERF3-AF] under `--pcs compact`: the ONE batched opening of W, A and H (the three above stay empty)
    pub cpcs_open: Option<pcs_compact::BatchOpening>,
}

impl LayerProof {
    /// Serialized size in bytes (a flat little-endian encoding of every field).
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4);
        let mults: usize = self.mults.iter().map(|(_, m)| 8 + 4 + m.len() * 4).sum();
        let f2 = |v: &Vec<Fp2>| v.len() * 16;
        coms + mults + f2(&self.gu_claims) + self.gu_sc.size_bytes() + f2(&self.gu_term)
            + f2(&self.d_claims) + self.d_sc.size_bytes() + f2(&self.d_term)
            + self.zc20_sc.size_bytes() + f2(&self.zc20_term) + self.zc17_sc.size_bytes() + f2(&self.zc17_term)
            + f2(&self.helper_sums) + self.w_open.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
            + self.cpcs_open.as_ref().map(|b| b.size_bytes()).unwrap_or(0)
    }

    /// [UPERF3-XX] The flat little-endian encoding `size_bytes` counts
    /// (the byte-identity gate between the CPU and GPU provers: the
    /// sha256 of the concatenated layer proofs).
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.size_bytes());
        let com = |out: &mut Vec<u8>, c: &Option<Commitment>| {
            let c = c.as_ref().expect("commitment");
            out.extend_from_slice(&c.root);
            out.extend_from_slice(&(c.rows as u64).to_le_bytes());
            out.extend_from_slice(&c.log_cols.to_le_bytes());
        };
        com(&mut out, &self.w_com);
        com(&mut out, &self.a_com);
        com(&mut out, &self.h_com);
        for (tag, m) in &self.mults {
            out.extend_from_slice(&tag.to_le_bytes());
            out.extend_from_slice(&(m.len() as u32).to_le_bytes());
            for v in m {
                out.extend_from_slice(&v.to_le_bytes());
            }
        }
        let f2 = |out: &mut Vec<u8>, v: &Vec<Fp2>| {
            for x in v {
                out.extend_from_slice(&x.to_bytes());
            }
        };
        f2(&mut out, &self.gu_claims);
        self.gu_sc.write_bytes(&mut out);
        f2(&mut out, &self.gu_term);
        f2(&mut out, &self.d_claims);
        self.d_sc.write_bytes(&mut out);
        f2(&mut out, &self.d_term);
        self.zc20_sc.write_bytes(&mut out);
        f2(&mut out, &self.zc20_term);
        self.zc17_sc.write_bytes(&mut out);
        f2(&mut out, &self.zc17_term);
        f2(&mut out, &self.helper_sums);
        self.w_open.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        if let Some(b) = &self.cpcs_open { b.write_bytes(&mut out); } // [UPERF3-AF]
        debug_assert_eq!(out.len(), self.size_bytes());
        out
    }
}

fn absorb_statement(tr: &mut Transcript, st: &Statement) {
    tr.absorb_u64(b"layer", st.l as u64);
    tr.absorb_u64(b"t_rows", st.t_rows as u64);
    tr.absorb(b"shifts", &[st.shifts.0 as u8, st.shifts.1 as u8, st.shifts.2 as u8, st.shifts.3 as u8]);
    tr.absorb(b"table", st.table_digest.as_bytes());
}

fn absorb_com(tr: &mut Transcript, label: &[u8], c: &Commitment) {
    tr.absorb(label, &c.root);
    tr.absorb_u64(label, c.rows as u64);
}

fn absorb_mults(tr: &mut Transcript, mults: &[(u64, Vec<u32>)]) {
    let mut bytes = Vec::new();
    for (tag, m) in mults {
        bytes.extend_from_slice(&tag.to_le_bytes());
        bytes.extend_from_slice(&(m.len() as u64).to_le_bytes());
        for v in m {
            bytes.extend_from_slice(&v.to_le_bytes());
        }
    }
    tr.absorb(b"mults", &bytes);
}

fn to_fp_i32(v: &[i32]) -> Vec<Fp> {
    v.par_iter().map(|&x| Fp::from_i64(x as i64)).collect()
}
fn to_fp2_i32(v: &[i32]) -> Vec<Fp2> {
    v.par_iter().map(|&x| Fp2::from_i64(x as i64)).collect()
}

/// Evaluate several base-field slices at one point (one eq table).
fn eval_many(data: &[Fp], slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    let eq = eq_table_msb(point);
    slices
        .iter()
        .map(|&(off, len)| {
            assert_eq!(len, eq.len());
            data[off..off + len].par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
        })
        .collect()
}

/// [UPERF3-XX] `eval_many` on the device when the commitment is device-resident (same values), else on the host.
fn eval_many_dev(cm: &AnyCm, data: &[Fp], slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    #[cfg(feature = "gpu-cuda")]
    if let (true, Some(dc)) = (crate::gpu::enabled(), dev_of(cm)) {
        let offs: Vec<usize> = slices.iter().map(|&(o, len)| { assert_eq!(len, 1usize << point.len()); o }).collect();
        match crate::gpu::dev_eval_many(dc, &offs, point) {
            Ok(v) => return v,
            Err(e) => eprintln!("[UPERF3-XX] gpu eval_many declined ({e}); CPU path"),
        }
    }
    let _ = cm;
    eval_many(data, slices, point)
}

fn sum_fp2(v: &[Fp2]) -> Fp2 {
    v.par_iter().copied().reduce(|| Fp2::ZERO, |a, b| a.add(b))
}

fn pow2(sh: u32) -> Fp {
    Fp::new(1u64 << sh)
}

/// Multiplicity tables from the (possibly tampered) witness columns.
fn multiplicities(w: &LayerWitness, lay: &Layout) -> Vec<(u64, Vec<u32>)> {
    let tf = lay.tf;
    let tb = lay.tb;
    // Values outside a table (only possible on a TAMPERED witness) are
    // counted into entry 0 so the totals still match: the cheating
    // prover passes the shape/total sanity checks and only the LogUp
    // identity can catch it (that is what the tamper legs test).
    let mut silu = vec![0u32; 256];
    for &g in &w.g8[..tf] {
        if (-128..=127).contains(&g) { silu[(g + 128) as usize] += 1; } else { silu[0] += 1; }
    }
    let mut int8 = vec![0u32; 256];
    for col in [&w.u8v[..tf], &w.h8[..tf]] {
        for &v in col {
            if (-128..=127).contains(&v) { int8[(v + 128) as usize] += 1; } else { int8[0] += 1; }
        }
    }
    for &v in &w.z[..tb * 3] {
        if (-128..=127).contains(&v) { int8[(v + 128) as usize] += 1; } else { int8[0] += 1; }
    }
    let (sg, su, sh, sz) = w.shifts;
    let mut out = vec![(TAG_SILU, silu), (TAG_INT8, int8)];
    let mut shifts: Vec<u32> = vec![sg, su, sh, sz];
    shifts.sort();
    shifts.dedup();
    for s in shifts {
        let mut m = vec![0u32; 1usize << s];
        let cols: Vec<&[i32]> = [(sg, &w.rg[..tf]), (su, &w.ru[..tf]), (sh, &w.rh[..tf]), (sz, &w.rd[..tb * 3])]
            .into_iter().filter(|(c, _)| *c == s).map(|(_, v)| v).collect();
        for col in cols {
            for &r in col {
                if r >= 0 && (r as usize) < m.len() { m[r as usize] += 1; } else { m[0] += 1; }
            }
        }
        out.push((tag_range(s), m));
    }
    out
}

/// Helper column h = 1/(alpha - l1) + 1/(alpha - l2) over two lookup value columns.
fn helper_column(l1: &[Fp2], l2: &[Fp2], alpha: Fp2) -> Vec<Fp2> {
    let n = l1.len();
    let mut den: Vec<Fp2> = Vec::with_capacity(2 * n);
    den.extend(l1.iter().map(|v| alpha.sub(*v)));
    den.extend(l2.iter().map(|v| alpha.sub(*v)));
    den.par_chunks_mut(4096).for_each(|c| batch_inverse2(c));
    (0..n).into_par_iter().map(|i| den[i].add(den[n + i])).collect()
}

/// The zero-check constraint for a helper: h (a - l1)(a - l2) - (2a - l1 - l2).
#[inline(always)]
fn helper_constraint(h: Fp2, l1: Fp2, l2: Fp2, alpha: Fp2) -> Fp2 {
    let d1 = alpha.sub(l1);
    let d2 = alpha.sub(l2);
    h.mul(d1).mul(d2).sub(d1.add(d2))
}

pub struct ProveOutput {
    pub proof: LayerProof,
    pub timings: Vec<(String, f64)>,
}

/// The host-side Fp2 tables of the zero-checks (the CPU path builds them
/// with the helper columns; the device path never materializes them).
struct HostTabs {
    g8f: Vec<Fp2>, rgf: Vec<Fp2>, a8f: Vec<Fp2>, u8f: Vec<Fp2>, ruf: Vec<Fp2>, h8f: Vec<Fp2>, rhf: Vec<Fp2>,
    hg: Vec<Fp2>, hu: Vec<Fp2>, hh: Vec<Fp2>,
    zf: Vec<Vec<Fp2>>, rdf: Vec<Vec<Fp2>>, hz: Vec<Vec<Fp2>>,
}

/// [UPERF3-XX] The device-resident commitment behind a `Committed`, when the GPU path made it.
#[cfg(feature = "gpu-cuda")]
fn dev_of<'a>(cm: &'a AnyCm) -> Option<&'a crate::gpu::DevCommit> {
    // [UPERF3-AF] a compact commitment is never device-resident (the device path is Ligero-only)
    match cm.ligero_ref().map(|c| &c.store) {
        Some(pcs::Store::Device(dc)) => Some(dc),
        _ => None,
    }
}

/// Prove one layer over the first `t_rows` rows of the witness.
pub fn prove_layer(w: &LayerWitness, t_rows: usize, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript) -> ProveOutput {
    use std::time::Instant;
    let mut timings = Vec::new();
    let mut tick = Instant::now();
    let lap = |name: &str, timings: &mut Vec<(String, f64)>, tick: &mut Instant| {
        timings.push((name.to_string(), tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    let lay = Layout::new(t_rows);
    let tf = lay.tf;
    let tb = lay.tb;
    let (sh_g, sh_u, sh_h, sh_z) = w.shifts;
    let st = Statement { l: w.l, t_rows, shifts: w.shifts, table: w.table, table_digest: w.table_digest.clone() };
    absorb_statement(tr, &st);
    let mut proof = LayerProof::default();

    // ---- W data + commit ------------------------------------------------
    let mut w_data = vec![Fp::ZERO; lay.w_len];
    w_data[lay.wg[0]..lay.wg[0] + D * F].par_iter_mut().zip(w.wg_t.par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    w_data[lay.wu[0]..lay.wu[0] + D * F].par_iter_mut().zip(w.wu_t.par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    for b in 0..3 {
        let off = lay.wd[b];
        w_data[off..off + F * 256].par_chunks_mut(256).enumerate().for_each(|(k, row)| {
            for j in 0..256 {
                row[j] = Fp::from_i64(w.wd_t[k * D + b * 256 + j] as i64);
            }
        });
    }
    let w_pcs = params.pcs_for(LOG_WBLOCK);
    let w_cm = pcs_compact::commit(&w_pcs, &w_data, ntt); // [UPERF3-AF] Ligero unless --pcs compact
    proof.w_com = Some(w_cm.commitment());
    absorb_com(tr, b"W", proof.w_com.as_ref().unwrap());
    lap("commit W", &mut timings, &mut tick);

    // ---- A data + commit ------------------------------------------------
    let mut a_data = vec![Fp::ZERO; lay.a_len];
    for (off, col) in [(lay.g8, &w.g8), (lay.rg, &w.rg), (lay.a8, &w.a8), (lay.u8v, &w.u8v), (lay.ru, &w.ru), (lay.h8, &w.h8), (lay.rh, &w.rh)] {
        a_data[off..off + tf].par_iter_mut().zip(col[..tf].par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v as i64));
    }
    for b in 0..3 {
        let (xo, zo, ro) = (lay.x[b], lay.z[b], lay.rd[b]);
        a_data[xo..xo + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| {
            for k in 0..256 { row[k] = Fp::from_i64(w.x[t * D + b * 256 + k] as i64); }
        });
        a_data[zo..zo + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| {
            for k in 0..256 { row[k] = Fp::from_i64(w.z[t * D + b * 256 + k] as i64); }
        });
        a_data[ro..ro + tb].par_chunks_mut(256).enumerate().for_each(|(t, row)| {
            for k in 0..256 { row[k] = Fp::from_i64(w.rd[t * D + b * 256 + k] as i64); }
        });
    }
    let a_pcs = params.pcs_for(lay.log_tb);
    let a_cm = pcs_compact::commit(&a_pcs, &a_data, ntt); // [UPERF3-AF]
    proof.a_com = Some(a_cm.commitment());
    absorb_com(tr, b"A", proof.a_com.as_ref().unwrap());
    lap("commit A", &mut timings, &mut tick);

    // ---- multiplicities, challenges, helpers, commit H --------------------
    proof.mults = multiplicities(w, &lay);
    absorb_mults(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_silu = gamma.mul_base(Fp::new(TAG_SILU));
    let g_int8 = gamma.mul_base(Fp::new(TAG_INT8));
    let g_rg = gamma.mul_base(Fp::new(tag_range(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_range(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_range(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_range(sh_z)));
    let h_pcs = params.pcs_for(lay.log_tb);
    // [UPERF3-XX] the device path: helper columns computed on the device from the resident A data
    // straight into a device H buffer (no host tables, no upload), committed from there; the helper
    // sums come from a device reduction. Err -> the host body below.
    let mut host_tabs: Option<HostTabs> = None;
    let mut h_data: Vec<Fp> = Vec::new();
    let mut dev_helper_sums: Option<Vec<Fp2>> = None;
    #[cfg(feature = "gpu-cuda")]
    let h_cm_dev: Option<AnyCm> = if let (true, Some(a_dc)) = (crate::gpu::enabled(), dev_of(&a_cm)) {
        use crate::gpu::HelperSpec;
        let mut specs = vec![
            HelperSpec { off_v1: lay.g8, off_w: Some(lay.a8), off_v2: lay.rg, len: tf, c1: g_silu, c2: g_rg, off_re: lay.hg.0, off_im: lay.hg.1 },
            HelperSpec { off_v1: lay.u8v, off_w: None, off_v2: lay.ru, len: tf, c1: g_int8, c2: g_ru, off_re: lay.hu.0, off_im: lay.hu.1 },
            HelperSpec { off_v1: lay.h8, off_w: None, off_v2: lay.rh, len: tf, c1: g_int8, c2: g_rh, off_re: lay.hh.0, off_im: lay.hh.1 },
        ];
        for b in 0..3 {
            specs.push(HelperSpec { off_v1: lay.z[b], off_w: None, off_v2: lay.rd[b], len: tb, c1: g_int8, c2: g_rd, off_re: lay.hz[b].0, off_im: lay.hz[b].1 });
        }
        let rows = lay.h_len / h_pcs.cols();
        let r = crate::gpu::dev_helpers(a_dc, lay.h_len, &specs, alpha, beta)
            .and_then(|(d_h, sums)| crate::gpu::dev_commit_from(&h_pcs, d_h, rows, ntt).map(|(dc, leaves)| (dc, leaves, sums)));
        match r {
            Ok((dc, leaves, sums)) => {
                dev_helper_sums = Some(sums);
                Some(AnyCm::Ligero(pcs::Committed { params: h_pcs, rows, store: pcs::Store::Device(dc), tree: crate::merkle::MerkleTree::build(leaves) }))
            }
            Err(e) => { eprintln!("[UPERF3-XX] gpu helpers declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let h_cm_dev: Option<AnyCm> = None;
    let h_cm = match h_cm_dev {
        Some(cm) => cm,
        None => {
            // lookup value columns (Fp2)
            let g8f = to_fp2_i32(&w.g8[..tf]);
            let a8f = to_fp2_i32(&w.a8[..tf]);
            let rgf = to_fp2_i32(&w.rg[..tf]);
            let u8f = to_fp2_i32(&w.u8v[..tf]);
            let ruf = to_fp2_i32(&w.ru[..tf]);
            let h8f = to_fp2_i32(&w.h8[..tf]);
            let rhf = to_fp2_i32(&w.rh[..tf]);
            let lg: Vec<Fp2> = g8f.par_iter().zip(a8f.par_iter()).map(|(g, a)| g.add(beta.mul(*a)).add(g_silu)).collect();
            let lrg: Vec<Fp2> = rgf.par_iter().map(|r| r.add(g_rg)).collect();
            let lu: Vec<Fp2> = u8f.par_iter().map(|v| v.add(g_int8)).collect();
            let lru: Vec<Fp2> = ruf.par_iter().map(|r| r.add(g_ru)).collect();
            let lh: Vec<Fp2> = h8f.par_iter().map(|v| v.add(g_int8)).collect();
            let lrh: Vec<Fp2> = rhf.par_iter().map(|r| r.add(g_rh)).collect();
            let hg = helper_column(&lg, &lrg, alpha);
            let hu = helper_column(&lu, &lru, alpha);
            let hh = helper_column(&lh, &lrh, alpha);
            drop(lg); drop(lrg); drop(lu); drop(lru); drop(lh); drop(lrh);
            let mut zf: Vec<Vec<Fp2>> = Vec::new();
            let mut rdf: Vec<Vec<Fp2>> = Vec::new();
            let mut hz: Vec<Vec<Fp2>> = Vec::new();
            for b in 0..3 {
                let z_b: Vec<Fp2> = a_data[lay.z[b]..lay.z[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect();
                let rd_b: Vec<Fp2> = a_data[lay.rd[b]..lay.rd[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect();
                let lz: Vec<Fp2> = z_b.par_iter().map(|v| v.add(g_int8)).collect();
                let lrd: Vec<Fp2> = rd_b.par_iter().map(|r| r.add(g_rd)).collect();
                hz.push(helper_column(&lz, &lrd, alpha));
                zf.push(z_b);
                rdf.push(rd_b);
            }
            h_data = vec![Fp::ZERO; lay.h_len];
            for (col, (ore, oim)) in [(&hg, lay.hg), (&hu, lay.hu), (&hh, lay.hh)] {
                h_data[ore..ore + tf].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c0);
                h_data[oim..oim + tf].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c1);
            }
            for b in 0..3 {
                let (ore, oim) = lay.hz[b];
                h_data[ore..ore + tb].par_iter_mut().zip(hz[b].par_iter()).for_each(|(o, v)| *o = v.c0);
                h_data[oim..oim + tb].par_iter_mut().zip(hz[b].par_iter()).for_each(|(o, v)| *o = v.c1);
            }
            host_tabs = Some(HostTabs { g8f, rgf, a8f, u8f, ruf, h8f, rhf, hg, hu, hh, zf, rdf, hz });
            pcs_compact::commit(&h_pcs, &h_data, ntt) // [UPERF3-AF]
        }
    };
    proof.h_com = Some(h_cm.commitment());
    absorb_com(tr, b"H", proof.h_com.as_ref().unwrap());
    lap("helpers + commit H", &mut timings, &mut tick);

    // ---- g/u matmul sumcheck -------------------------------------------------
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(11);
    let lam_gu = tr.challenge_fp2();
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let ev = eval_many_dev(&a_cm, &a_data, &[(lay.g8, tf), (lay.rg, tf), (lay.u8v, tf), (lay.ru, tf)], &p1);
    let g_claim = ev[0].mul_base(pow2(sh_g)).add(ev[1]);
    let u_claim = ev[2].mul_base(pow2(sh_u)).add(ev[3]);
    proof.gu_claims = vec![g_claim, u_claim];
    tr.absorb_fp2(b"gu-claims", &proof.gu_claims);
    let eq_ri = eq_table_msb(&r_i);
    let eq_rj = eq_table_msb(&r_j);
    let xk = fold_rows_i8(&w.x[..t_rows * D], t_rows, D, &eq_ri); // 768
    let wgk = fold_cols_i8(&w.wg_t, D, F, &eq_rj); // 768
    let wuk = fold_cols_i8(&w.wu_t, D, F, &eq_rj); // 768
    let mut tables: Vec<Vec<Fp2>> = Vec::new();
    for b in 0..3 { tables.push(xk[b * 256..(b + 1) * 256].to_vec()); }
    for b in 0..3 {
        tables.push(wgk[b * 256..(b + 1) * 256].iter().zip(wuk[b * 256..(b + 1) * 256].iter()).map(|(g, u)| g.add(lam_gu.mul(*u))).collect());
    }
    let out = sumcheck::prove(&mut tables, 2, |v| v[0].mul(v[3]).add(v[1].mul(v[4])).add(v[2].mul(v[5])), tr);
    proof.gu_sc = out.proof;
    let r_kp = out.challenges; // 8
    let mut term = Vec::with_capacity(9);
    for b in 0..3 { term.push(out.finals[b]); }
    for b in 0..3 { term.push(eval_mle_ext(&wgk[b * 256..(b + 1) * 256], &r_kp)); }
    for b in 0..3 { term.push(eval_mle_ext(&wuk[b * 256..(b + 1) * 256], &r_kp)); }
    proof.gu_term = term;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp); // X_b point (log_t + 8)
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j); // W blocks point (19)
    lap("matmul g/u", &mut timings, &mut tick);

    // ---- d matmul sumcheck ------------------------------------------------------
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(8);
    let lam_d = tr.challenge_fp2_vec(3);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let ev = eval_many_dev(&a_cm, &a_data, &[(lay.z[0], tb), (lay.rd[0], tb), (lay.z[1], tb), (lay.rd[1], tb), (lay.z[2], tb), (lay.rd[2], tb)], &p4);
    proof.d_claims = (0..3).map(|b| ev[2 * b].mul_base(pow2(sh_z)).add(ev[2 * b + 1])).collect();
    tr.absorb_fp2(b"d-claims", &proof.d_claims);
    let eq_rip = eq_table_msb(&r_ip);
    let eq_rjp = eq_table_msb(&r_jp);
    let hk = fold_rows_i32(&w.h8[..tf], t_rows, F, &eq_rip); // 2048
    let mut cw = vec![Fp2::ZERO; D];
    for b in 0..3 { for j in 0..256 { cw[b * 256 + j] = lam_d[b].mul(eq_rjp[j]); } }
    let wdk = fold_cols_i8(&w.wd_t, F, D, &cw); // 2048
    let mut tables = vec![hk, wdk];
    let out = sumcheck::prove(&mut tables, 2, |v| v[0].mul(v[1]), tr);
    proof.d_sc = out.proof;
    let r_k = out.challenges; // 11
    let mut term = vec![out.finals[0]];
    for b in 0..3 {
        let wdb = fold_cols_base(&w_data[lay.wd[b]..lay.wd[b] + F * 256], F, 256, &eq_rjp);
        term.push(eval_mle_ext(&wdb, &r_k));
    }
    proof.d_term = term;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k); // h8 point (log_t + 11)
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp); // Wd blocks point (19)
    lap("matmul d", &mut timings, &mut tick);

    // ---- zero-check 20 ---------------------------------------------------------------
    let tau = tr.challenge_fp2_vec(lay.log_tf as usize);
    let mu = tr.challenge_fp2_vec(4); // had, hg, hu, hh
    let nu = tr.challenge_fp2_vec(3); // g, u, h
    let (p_g, p_u, p_h) = (pow2(sh_g), pow2(sh_u), pow2(sh_h));
    // [UPERF3-XX] the device zero-check: tables built on the device from the resident A / H data (no upload)
    #[cfg(feature = "gpu-cuda")]
    let dev_out = if let (true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_of(&a_cm), dev_of(&h_cm)) {
        use crate::gpu::TabSpec;
        let specs = vec![
            TabSpec::Eq(&tau), TabSpec::Eq(&p1), TabSpec::Eq(&p5),
            TabSpec::FromFp(a_dc, lay.g8, tf), TabSpec::FromFp(a_dc, lay.rg, tf), TabSpec::FromFp(a_dc, lay.a8, tf),
            TabSpec::FromFp(a_dc, lay.u8v, tf), TabSpec::FromFp(a_dc, lay.ru, tf), TabSpec::FromFp(a_dc, lay.h8, tf), TabSpec::FromFp(a_dc, lay.rh, tf),
            TabSpec::FromFp2(h_dc, lay.hg.0, lay.hg.1, tf), TabSpec::FromFp2(h_dc, lay.hu.0, lay.hu.1, tf), TabSpec::FromFp2(h_dc, lay.hh.0, lay.hh.1, tf),
        ];
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, beta, g_silu, g_rg, g_ru, g_rh, g_int8, mu[0], mu[1], mu[2], mu[3], nu[0], nu[1], nu[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.extend([p_g.0, p_u.0, p_h.0]);
        let mut tr_try = Transcript::clone_state(tr);
        match crate::gpu::dev_zerocheck(0, &specs, &prm, &mut tr_try) {
            Ok(out) => { *tr = tr_try; Some(out) }
            Err(e) => { eprintln!("[UPERF3-XX] gpu zero-check 20 declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_out: Option<sumcheck::ProverOutput> = None;
    let out = match dev_out {
        Some(out) => out,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check 20: the device path declined after the device helpers; no host tables (rerun with HL_GPU unset)");
            let (g8f, rgf, a8f, u8f, ruf, h8f, rhf) = (std::mem::take(&mut ht.g8f), std::mem::take(&mut ht.rgf), std::mem::take(&mut ht.a8f), std::mem::take(&mut ht.u8f), std::mem::take(&mut ht.ruf), std::mem::take(&mut ht.h8f), std::mem::take(&mut ht.rhf));
            let (hg, hu, hh) = (std::mem::take(&mut ht.hg), std::mem::take(&mut ht.hu), std::mem::take(&mut ht.hh));
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau), eq_table_msb(&p1), eq_table_msb(&p5), g8f, rgf, a8f, u8f, ruf, h8f, rhf, hg, hu, hh];
            let zc20_poly = move |v: &[Fp2]| -> Fp2 {
                let (eqt, eq1, eq5) = (v[0], v[1], v[2]);
                let (g8, rg, a8, u8, ru, h8, rh, hg, hu, hh) = (v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12]);
                let c_had = a8.mul(u8).sub(h8.mul_base(p_h)).sub(rh);
                let c_hg = helper_constraint(hg, g8.add(beta.mul(a8)).add(g_silu), rg.add(g_rg), alpha);
                let c_hu = helper_constraint(hu, u8.add(g_int8), ru.add(g_ru), alpha);
                let c_hh = helper_constraint(hh, h8.add(g_int8), rh.add(g_rh), alpha);
                let zc = mu[0].mul(c_had).add(mu[1].mul(c_hg)).add(mu[2].mul(c_hu)).add(mu[3].mul(c_hh));
                let fold1 = nu[0].mul(g8.mul_base(p_g).add(rg)).add(nu[1].mul(u8.mul_base(p_u).add(ru)));
                eqt.mul(zc).add(eq1.mul(fold1)).add(eq5.mul(nu[2].mul(h8)))
            };
            let out = sumcheck::prove(&mut tables, 4, zc20_poly, tr);
            drop(tables);
            out
        }
    };
    proof.zc20_sc = out.proof;
    let rho20 = out.challenges;
    proof.zc20_term = out.finals[3..13].to_vec();
    tr.absorb_fp2(b"zc20-term", &proof.zc20_term);
    lap("zero-check 20", &mut timings, &mut tick);

    // ---- zero-check 17 ---------------------------------------------------------------
    let tau2 = tr.challenge_fp2_vec(lay.log_tb as usize);
    let mu2 = tr.challenge_fp2_vec(3);
    let nu_x = tr.challenge_fp2_vec(3);
    let nu_z = tr.challenge_fp2_vec(3);
    let p_z = pow2(sh_z);
    #[cfg(feature = "gpu-cuda")]
    let dev_out = if let (true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_of(&a_cm), dev_of(&h_cm)) {
        use crate::gpu::TabSpec;
        let mut specs = vec![TabSpec::Eq(&tau2), TabSpec::Eq(&p2), TabSpec::Eq(&p4)];
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.x[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.z[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp(a_dc, lay.rd[b], tb)); }
        for b in 0..3 { specs.push(TabSpec::FromFp2(h_dc, lay.hz[b].0, lay.hz[b].1, tb)); }
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, g_int8, g_rd, mu2[0], mu2[1], mu2[2], nu_x[0], nu_x[1], nu_x[2], nu_z[0], nu_z[1], nu_z[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.push(p_z.0);
        let mut tr_try = Transcript::clone_state(tr);
        match crate::gpu::dev_zerocheck(1, &specs, &prm, &mut tr_try) {
            Ok(out) => { *tr = tr_try; Some(out) }
            Err(e) => { eprintln!("[UPERF3-XX] gpu zero-check 17 declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_out: Option<sumcheck::ProverOutput> = None;
    let out = match dev_out {
        Some(out) => out,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check 17: the device path declined after the device helpers; no host tables (rerun with HL_GPU unset)");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau2), eq_table_msb(&p2), eq_table_msb(&p4)];
            for b in 0..3 { tables.push(a_data[lay.x[b]..lay.x[b] + tb].par_iter().map(|v| Fp2::from_base(*v)).collect()); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.zf[b])); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.rdf[b])); }
            for b in 0..3 { tables.push(std::mem::take(&mut ht.hz[b])); }
            let zc17_poly = move |v: &[Fp2]| -> Fp2 {
                let (eqt, eq2, eq4) = (v[0], v[1], v[2]);
                let mut zc = Fp2::ZERO;
                let mut fx = Fp2::ZERO;
                let mut fz = Fp2::ZERO;
                for b in 0..3 {
                    let (x, z, rd, h) = (v[3 + b], v[6 + b], v[9 + b], v[12 + b]);
                    zc = zc.add(mu2[b].mul(helper_constraint(h, z.add(g_int8), rd.add(g_rd), alpha)));
                    fx = fx.add(nu_x[b].mul(x));
                    fz = fz.add(nu_z[b].mul(z.mul_base(p_z).add(rd)));
                }
                eqt.mul(zc).add(eq2.mul(fx)).add(eq4.mul(fz))
            };
            let out = sumcheck::prove(&mut tables, 4, zc17_poly, tr);
            drop(tables);
            out
        }
    };
    proof.zc17_sc = out.proof;
    let rho17 = out.challenges;
    proof.zc17_term = out.finals[3..15].to_vec();
    tr.absorb_fp2(b"zc17-term", &proof.zc17_term);
    lap("zero-check 17", &mut timings, &mut tick);

    // ---- helper sums ---------------------------------------------------------------
    proof.helper_sums = match dev_helper_sums.take() {
        Some(s) => s,
        None => {
            let sums = |re: usize, im: usize, len: usize| -> Fp2 {
                let sre = h_data[re..re + len].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                let sim = h_data[im..im + len].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                Fp2::new(sre, sim)
            };
            let mut v = vec![sums(lay.hg.0, lay.hg.1, tf), sums(lay.hu.0, lay.hu.1, tf), sums(lay.hh.0, lay.hh.1, tf)];
            for b in 0..3 { v.push(sums(lay.hz[b].0, lay.hz[b].1, tb)); }
            v
        }
    };
    drop(host_tabs);
    tr.absorb_fp2(b"helper-sums", &proof.helper_sums);

    // ---- PCS openings -------------------------------------------------------------
    let (w_claims, a_claims, h_claims) = build_claims(&lay, &proof, &p3, &p6, &rho20, &rho17);
    if pcs_compact::selected() {
        // [UPERF3-AF] ONE batched compact opening of the three commitments
        proof.cpcs_open = Some(pcs_compact::open_batch(&[(w_cm.compact(), &w_claims), (a_cm.compact(), &a_claims), (h_cm.compact(), &h_claims)], tr));
        drop(w_cm);
        drop(a_cm);
        drop(h_cm);
    } else {
        proof.w_open = pcs::open(w_cm.lig(), &w_claims, tr);
        drop(w_cm);
        proof.a_open = pcs::open(a_cm.lig(), &a_claims, tr);
        drop(a_cm);
        proof.h_open = pcs::open(h_cm.lig(), &h_claims, tr);
        drop(h_cm);
    }
    lap("pcs openings", &mut timings, &mut tick);
    let _ = sum_fp2;
    ProveOutput { proof, timings }
}

/// The PCS claims of a layer proof (shared by prover and verifier).
fn build_claims(lay: &Layout, proof: &LayerProof, p3: &[Fp2], p6: &[Fp2], rho20: &[Fp2], rho17: &[Fp2]) -> (Vec<Claim>, Vec<Claim>, Vec<Claim>) {
    let one = Fp2::ONE;
    let mut wc = Vec::new();
    for b in 0..3 { wc.push(Claim { parts: vec![(lay.s_w(lay.wg[b]), one)], point: p3.to_vec(), sum: false, value: proof.gu_term[3 + b] }); }
    for b in 0..3 { wc.push(Claim { parts: vec![(lay.s_w(lay.wu[b]), one)], point: p3.to_vec(), sum: false, value: proof.gu_term[6 + b] }); }
    for b in 0..3 { wc.push(Claim { parts: vec![(lay.s_w(lay.wd[b]), one)], point: p6.to_vec(), sum: false, value: proof.d_term[1 + b] }); }
    let mut ac = Vec::new();
    let a_cols = [lay.g8, lay.rg, lay.a8, lay.u8v, lay.ru, lay.h8, lay.rh];
    for (i, off) in a_cols.iter().enumerate() {
        ac.push(Claim { parts: vec![(lay.s_tf(*off), one)], point: rho20.to_vec(), sum: false, value: proof.zc20_term[i] });
    }
    for b in 0..3 { ac.push(Claim { parts: vec![(lay.s_tb(lay.x[b]), one)], point: rho17.to_vec(), sum: false, value: proof.zc17_term[b] }); }
    for b in 0..3 { ac.push(Claim { parts: vec![(lay.s_tb(lay.z[b]), one)], point: rho17.to_vec(), sum: false, value: proof.zc17_term[3 + b] }); }
    for b in 0..3 { ac.push(Claim { parts: vec![(lay.s_tb(lay.rd[b]), one)], point: rho17.to_vec(), sum: false, value: proof.zc17_term[6 + b] }); }
    let mut hc = Vec::new();
    let u = Fp2::U;
    for (i, (re, im)) in [lay.hg, lay.hu, lay.hh].iter().enumerate() {
        hc.push(Claim { parts: vec![(lay.s_tf(*re), one), (lay.s_tf(*im), u)], point: rho20.to_vec(), sum: false, value: proof.zc20_term[7 + i] });
    }
    for b in 0..3 {
        let (re, im) = lay.hz[b];
        hc.push(Claim { parts: vec![(lay.s_tb(re), one), (lay.s_tb(im), u)], point: rho17.to_vec(), sum: false, value: proof.zc17_term[9 + b] });
    }
    for (i, (re, im)) in [lay.hg, lay.hu, lay.hh].iter().enumerate() {
        hc.push(Claim { parts: vec![(lay.s_tf(*re), one), (lay.s_tf(*im), u)], point: vec![], sum: true, value: proof.helper_sums[i] });
    }
    for b in 0..3 {
        let (re, im) = lay.hz[b];
        hc.push(Claim { parts: vec![(lay.s_tb(re), one), (lay.s_tb(im), u)], point: vec![], sum: true, value: proof.helper_sums[3 + b] });
    }
    (wc, ac, hc)
}

/// Verify one layer proof against the public statement.
pub fn verify_layer(st: &Statement, proof: &LayerProof, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript) -> Result<(), String> {
    let lay = Layout::new(st.t_rows);
    let tf = lay.tf;
    let tb = lay.tb;
    let (sh_g, sh_u, sh_h, sh_z) = st.shifts;
    absorb_statement(tr, st);
    let w_com = proof.w_com.as_ref().ok_or("missing W commitment")?;
    let a_com = proof.a_com.as_ref().ok_or("missing A commitment")?;
    let h_com = proof.h_com.as_ref().ok_or("missing H commitment")?;
    let w_pcs = params.pcs_for(LOG_WBLOCK);
    let a_pcs = params.pcs_for(lay.log_tb);
    let h_pcs = params.pcs_for(lay.log_tb);
    if w_com.rows != lay.w_len / w_pcs.cols() { return Err("W commitment rows".into()); }
    if a_com.rows != lay.a_len / a_pcs.cols() { return Err("A commitment rows".into()); }
    if h_com.rows != lay.h_len / h_pcs.cols() { return Err("H commitment rows".into()); }
    absorb_com(tr, b"W", w_com);
    absorb_com(tr, b"A", a_com);
    // multiplicities: shape + totals
    let mut shifts: Vec<u32> = vec![sh_g, sh_u, sh_h, sh_z];
    shifts.sort();
    shifts.dedup();
    if proof.mults.len() != 2 + shifts.len() { return Err("multiplicity table count".into()); }
    if proof.mults[0].0 != TAG_SILU || proof.mults[0].1.len() != 256 { return Err("silu multiplicities".into()); }
    if proof.mults[1].0 != TAG_INT8 || proof.mults[1].1.len() != 256 { return Err("int8 multiplicities".into()); }
    for (i, s) in shifts.iter().enumerate() {
        let (tag, m) = &proof.mults[2 + i];
        if *tag != tag_range(*s) || m.len() != (1usize << s) { return Err(format!("range({s}) multiplicities")); }
        let want: usize = [(sh_g, tf), (sh_u, tf), (sh_h, tf), (sh_z, 3 * tb)].iter().filter(|(c, _)| c == s).map(|(_, n)| n).sum();
        let got: u64 = m.iter().map(|&x| x as u64).sum();
        if got != want as u64 { return Err(format!("range({s}) multiplicity total {got} != {want}")); }
    }
    let silu_total: u64 = proof.mults[0].1.iter().map(|&x| x as u64).sum();
    if silu_total != tf as u64 { return Err("silu multiplicity total".into()); }
    let int8_total: u64 = proof.mults[1].1.iter().map(|&x| x as u64).sum();
    if int8_total != (2 * tf + 3 * tb) as u64 { return Err("int8 multiplicity total".into()); }
    absorb_mults(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    absorb_com(tr, b"H", h_com);
    let g_silu = gamma.mul_base(Fp::new(TAG_SILU));
    let g_int8 = gamma.mul_base(Fp::new(TAG_INT8));
    let g_rg = gamma.mul_base(Fp::new(tag_range(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_range(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_range(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_range(sh_z)));

    // ---- g/u matmul ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(11);
    let lam_gu = tr.challenge_fp2();
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    if proof.gu_claims.len() != 2 { return Err("gu claims".into()); }
    tr.absorb_fp2(b"gu-claims", &proof.gu_claims);
    let (g_claim, u_claim) = (proof.gu_claims[0], proof.gu_claims[1]);
    let (fin, r_kp) = sumcheck::verify(g_claim.add(lam_gu.mul(u_claim)), 2, 8, &proof.gu_sc, tr)?;
    if proof.gu_term.len() != 9 { return Err("gu terminal".into()); }
    let mut want = Fp2::ZERO;
    for b in 0..3 {
        want = want.add(proof.gu_term[b].mul(proof.gu_term[3 + b].add(lam_gu.mul(proof.gu_term[6 + b]))));
    }
    if want != fin { return Err("g/u matmul sumcheck terminal check fails".into()); }
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);

    // ---- d matmul ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(8);
    let lam_d = tr.challenge_fp2_vec(3);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    if proof.d_claims.len() != 3 { return Err("d claims".into()); }
    tr.absorb_fp2(b"d-claims", &proof.d_claims);
    let d_sum = (0..3).fold(Fp2::ZERO, |a, b| a.add(lam_d[b].mul(proof.d_claims[b])));
    let (fin, r_k) = sumcheck::verify(d_sum, 2, 11, &proof.d_sc, tr)?;
    if proof.d_term.len() != 4 { return Err("d terminal".into()); }
    let wd_comb = (0..3).fold(Fp2::ZERO, |a, b| a.add(lam_d[b].mul(proof.d_term[1 + b])));
    if proof.d_term[0].mul(wd_comb) != fin { return Err("d matmul sumcheck terminal check fails".into()); }
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let h_claim = proof.d_term[0];
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);

    // ---- zero-check 20 ----
    let tau = tr.challenge_fp2_vec(lay.log_tf as usize);
    let mu = tr.challenge_fp2_vec(4);
    let nu = tr.challenge_fp2_vec(3);
    let claimed = nu[0].mul(g_claim).add(nu[1].mul(u_claim)).add(nu[2].mul(h_claim));
    let (fin, rho20) = sumcheck::verify(claimed, 4, lay.log_tf as usize, &proof.zc20_sc, tr)?;
    if proof.zc20_term.len() != 10 { return Err("zc20 terminal".into()); }
    {
        let v = &proof.zc20_term;
        let (g8, rg, a8, u8, ru, h8, rh, hg, hu, hh) = (v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9]);
        let c_had = a8.mul(u8).sub(h8.mul_base(pow2(sh_h))).sub(rh);
        let c_hg = helper_constraint(hg, g8.add(beta.mul(a8)).add(g_silu), rg.add(g_rg), alpha);
        let c_hu = helper_constraint(hu, u8.add(g_int8), ru.add(g_ru), alpha);
        let c_hh = helper_constraint(hh, h8.add(g_int8), rh.add(g_rh), alpha);
        let zc = mu[0].mul(c_had).add(mu[1].mul(c_hg)).add(mu[2].mul(c_hu)).add(mu[3].mul(c_hh));
        let fold1 = nu[0].mul(g8.mul_base(pow2(sh_g)).add(rg)).add(nu[1].mul(u8.mul_base(pow2(sh_u)).add(ru)));
        let want = eq_point(&tau, &rho20).mul(zc).add(eq_point(&p1, &rho20).mul(fold1)).add(eq_point(&p5, &rho20).mul(nu[2].mul(h8)));
        if want != fin { return Err("zero-check 20 terminal check fails".into()); }
    }
    tr.absorb_fp2(b"zc20-term", &proof.zc20_term);

    // ---- zero-check 17 ----
    let tau2 = tr.challenge_fp2_vec(lay.log_tb as usize);
    let mu2 = tr.challenge_fp2_vec(3);
    let nu_x = tr.challenge_fp2_vec(3);
    let nu_z = tr.challenge_fp2_vec(3);
    let claimed = (0..3).fold(Fp2::ZERO, |a, b| a.add(nu_x[b].mul(proof.gu_term[b])).add(nu_z[b].mul(proof.d_claims[b])));
    let (fin, rho17) = sumcheck::verify(claimed, 4, lay.log_tb as usize, &proof.zc17_sc, tr)?;
    if proof.zc17_term.len() != 12 { return Err("zc17 terminal".into()); }
    {
        let v = &proof.zc17_term;
        let mut zc = Fp2::ZERO;
        let mut fx = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for b in 0..3 {
            let (x, z, rd, h) = (v[b], v[3 + b], v[6 + b], v[9 + b]);
            zc = zc.add(mu2[b].mul(helper_constraint(h, z.add(g_int8), rd.add(g_rd), alpha)));
            fx = fx.add(nu_x[b].mul(x));
            fz = fz.add(nu_z[b].mul(z.mul_base(pow2(sh_z)).add(rd)));
        }
        let want = eq_point(&tau2, &rho17).mul(zc).add(eq_point(&p2, &rho17).mul(fx)).add(eq_point(&p4, &rho17).mul(fz));
        if want != fin { return Err("zero-check 17 terminal check fails".into()); }
    }
    tr.absorb_fp2(b"zc17-term", &proof.zc17_term);

    // ---- helper sums vs the multiplicity side (the LogUp identity) ----
    if proof.helper_sums.len() != 6 { return Err("helper sums".into()); }
    tr.absorb_fp2(b"helper-sums", &proof.helper_sums);
    let witness_side = proof.helper_sums.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
    let mut dens: Vec<Fp2> = Vec::new();
    let mut nums: Vec<Fp> = Vec::new();
    for (tag, m) in &proof.mults {
        for (i, &cnt) in m.iter().enumerate() {
            if cnt == 0 { continue; }
            let tval = if *tag == TAG_SILU {
                let v = i as i64 - 128;
                let s = st.table[i] as i64;
                Fp2::from_i64(v).add(beta.mul_base(Fp::from_i64(s))).add(g_silu)
            } else if *tag == TAG_INT8 {
                Fp2::from_i64(i as i64 - 128).add(g_int8)
            } else {
                Fp2::from_u64(i as u64).add(gamma.mul_base(Fp::new(*tag)))
            };
            dens.push(alpha.sub(tval));
            nums.push(Fp::new(cnt as u64));
        }
    }
    batch_inverse2(&mut dens);
    let table_side = dens.iter().zip(nums.iter()).fold(Fp2::ZERO, |a, (d, n)| a.add(d.mul_base(*n)));
    if witness_side != table_side { return Err("LogUp identity fails (a lookup is not in its table)".into()); }

    // ---- PCS openings ----
    let (w_claims, a_claims, h_claims) = build_claims(&lay, proof, &p3, &p6, &rho20, &rho17);
    // [UPERF3-AF] the selected PCS must match the proof's form
    if let Some(b) = &proof.cpcs_open {
        if !pcs_compact::selected() { return Err("cpcs: the proof carries a compact opening but --pcs compact is not selected".into()); }
        pcs_compact::verify_batch(&[(&w_pcs, w_com, &w_claims), (&a_pcs, a_com, &a_claims), (&h_pcs, h_com, &h_claims)], b, tr).map_err(|e| format!("cpcs: {e}"))?;
        return Ok(());
    } else if pcs_compact::selected() {
        return Err("cpcs: --pcs compact is selected but the proof carries the Ligero openings".into());
    }
    pcs::verify(&w_pcs, w_com, &w_claims, &proof.w_open, ntt, tr).map_err(|e| format!("W: {e}"))?;
    pcs::verify(&a_pcs, a_com, &a_claims, &proof.a_open, ntt, tr).map_err(|e| format!("A: {e}"))?;
    pcs::verify(&h_pcs, h_com, &h_claims, &proof.h_open, ntt, tr).map_err(|e| format!("H: {e}"))?;
    Ok(())
}

/// Tamper legs applied to a witness before proving.
#[derive(Clone, Copy, Debug)]
pub enum Tamper {
    None,
    /// X[idx] += 1 (the committed X no longer matches the chain)
    FlipX(usize),
    /// WgT[idx] += 1
    FlipW(usize),
    /// rg[idx] += 2^sh_g, g8[idx] -= 1 (gacc identity kept; the remainder leaves [0, 2^sh))
    RemainderOutOfRange(usize),
    /// a8[idx] += 1 with the downstream chain recomputed (only the table fact breaks)
    WrongTableEntry(usize),
    /// h8[idx] += 1 with rh unchanged (the Hadamard requant identity breaks)
    WrongRequant(usize),
    /// z[idx] += 1 (the d matmul identity breaks)
    WrongZ(usize),
}

pub fn apply_tamper(w: &mut LayerWitness, t: Tamper) {
    match t {
        Tamper::None => {}
        Tamper::FlipX(i) => { w.x[i] = w.x[i].wrapping_add(1); }
        Tamper::FlipW(i) => { w.wg_t[i] = w.wg_t[i].wrapping_add(1); }
        Tamper::RemainderOutOfRange(i) => { w.rg[i] += 1 << w.shifts.0; w.g8[i] -= 1; }
        Tamper::WrongTableEntry(i) => {
            w.a8[i] += 1;
            let sh_h = w.shifts.2;
            let hh = w.a8[i] * w.u8v[i];
            w.h8[i] = hh >> sh_h;
            w.rh[i] = hh & ((1 << sh_h) - 1);
            // recompute dacc/z/rd from h8
            let dacc = crate::chain::matmul_i32_i8_i32(&w.h8, &w.wd_t, crate::export::T, F, D);
            let sh_z = w.shifts.3;
            w.z = dacc.iter().map(|&a| a >> sh_z).collect();
            w.rd = dacc.iter().map(|&a| a & ((1 << sh_z) - 1)).collect();
        }
        Tamper::WrongRequant(i) => { w.h8[i] += 1; }
        Tamper::WrongZ(i) => { w.z[i] += 1; }
    }
}

/// Rung 2: the g/u matmul sumcheck ALONE (no PCS). The prover runs on
/// `prover_w`; the verifier holds `honest_w` and evaluates X~, Wg~, Wu~
/// and the gacc/uacc claims directly from its own plain matrices (a
/// differential against the plain chain). Returns Err on reject.
pub fn matmul_differential(honest_w: &LayerWitness, prover_w: &LayerWitness, t_rows: usize) -> Result<(), String> {
    let lay = Layout::new(t_rows);
    let tf = lay.tf;
    let tb = lay.tb;
    let (sh_g, sh_u, _, _) = honest_w.shifts;
    let mut tr = Transcript::new(b"matmul-differential");
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(11);
    let lam = tr.challenge_fp2();
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    // prover: claims from ITS chain, tables from ITS X / W
    let pg = to_fp_i32(&prover_w.g8[..tf]);
    let prg = to_fp_i32(&prover_w.rg[..tf]);
    let pu = to_fp_i32(&prover_w.u8v[..tf]);
    let pru = to_fp_i32(&prover_w.ru[..tf]);
    let eq1 = eq_table_msb(&p1);
    let dot = |v: &[Fp]| -> Fp2 { v.par_iter().zip(eq1.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b)) };
    let g_claim = dot(&pg).mul_base(pow2(sh_g)).add(dot(&prg));
    let u_claim = dot(&pu).mul_base(pow2(sh_u)).add(dot(&pru));
    tr.absorb_fp2(b"gu-claims", &[g_claim, u_claim]);
    let eq_ri = eq_table_msb(&r_i);
    let eq_rj = eq_table_msb(&r_j);
    let xk = fold_rows_i8(&prover_w.x[..t_rows * D], t_rows, D, &eq_ri);
    let wgk = fold_cols_i8(&prover_w.wg_t, D, F, &eq_rj);
    let wuk = fold_cols_i8(&prover_w.wu_t, D, F, &eq_rj);
    let mut tables: Vec<Vec<Fp2>> = Vec::new();
    for b in 0..3 { tables.push(xk[b * 256..(b + 1) * 256].to_vec()); }
    for b in 0..3 {
        tables.push(wgk[b * 256..(b + 1) * 256].iter().zip(wuk[b * 256..(b + 1) * 256].iter()).map(|(g, u)| g.add(lam.mul(*u))).collect());
    }
    let out = sumcheck::prove(&mut tables, 2, |v| v[0].mul(v[3]).add(v[1].mul(v[4])).add(v[2].mul(v[5])), &mut tr);
    let r_kp = out.challenges.clone();
    let mut term = Vec::new();
    for b in 0..3 { term.push(out.finals[b]); }
    for b in 0..3 { term.push(eval_mle_ext(&wgk[b * 256..(b + 1) * 256], &r_kp)); }
    for b in 0..3 { term.push(eval_mle_ext(&wuk[b * 256..(b + 1) * 256], &r_kp)); }
    // verifier: same transcript, checks the rounds, then evaluates its OWN matrices at the terminal point
    let mut tv = Transcript::new(b"matmul-differential");
    let v_ri = tv.challenge_fp2_vec(lay.log_t as usize);
    let v_rj = tv.challenge_fp2_vec(11);
    let v_lam = tv.challenge_fp2();
    let mut v_p1 = v_ri.clone();
    v_p1.extend_from_slice(&v_rj);
    // the verifier's own view of the claims (the differential): from the honest chain
    let hg = to_fp_i32(&honest_w.g8[..tf]);
    let hrg = to_fp_i32(&honest_w.rg[..tf]);
    let hu = to_fp_i32(&honest_w.u8v[..tf]);
    let hru = to_fp_i32(&honest_w.ru[..tf]);
    let veq1 = eq_table_msb(&v_p1);
    let vdot = |v: &[Fp]| -> Fp2 { v.par_iter().zip(veq1.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b)) };
    let vg = vdot(&hg).mul_base(pow2(sh_g)).add(vdot(&hrg));
    let vu = vdot(&hu).mul_base(pow2(sh_u)).add(vdot(&hru));
    if vg != g_claim || vu != u_claim {
        return Err("claimed gacc/uacc evaluation != the honest chain's".into());
    }
    tv.absorb_fp2(b"gu-claims", &[g_claim, u_claim]);
    let (fin, v_rkp) = sumcheck::verify(g_claim.add(v_lam.mul(u_claim)), 2, 8, &out.proof, &mut tv)?;
    let mut want = Fp2::ZERO;
    for b in 0..3 { want = want.add(term[b].mul(term[3 + b].add(v_lam.mul(term[6 + b])))); }
    if want != fin { return Err("matmul sumcheck terminal check fails".into()); }
    // direct evaluation of the honest X_b~(r_i, r_k') and W_b~(r_k', r_j)
    let mut v_p2 = v_ri.clone();
    v_p2.extend_from_slice(&v_rkp);
    let mut v_p3 = v_rkp.clone();
    v_p3.extend_from_slice(&v_rj);
    let eq2 = eq_table_msb(&v_p2);
    let eq3 = eq_table_msb(&v_p3);
    for b in 0..3 {
        let xb: Vec<Fp> = (0..tb).map(|i| Fp::from_i64(honest_w.x[(i / 256) * D + b * 256 + (i % 256)] as i64)).collect();
        let xv = xb.par_iter().zip(eq2.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b));
        if xv != term[b] { return Err(format!("X block {b}: the prover's terminal value != the honest X's MLE")); }
        let wg: Vec<Fp> = honest_w.wg_t[b * 256 * F..(b + 1) * 256 * F].iter().map(|&v| Fp::from_i64(v as i64)).collect();
        let wgv = wg.par_iter().zip(eq3.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b));
        if wgv != term[3 + b] { return Err(format!("Wg block {b}: the prover's terminal value != the honest Wg's MLE")); }
        let wu: Vec<Fp> = honest_w.wu_t[b * 256 * F..(b + 1) * 256 * F].iter().map(|&v| Fp::from_i64(v as i64)).collect();
        let wuv = wu.par_iter().zip(eq3.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b));
        if wuv != term[6 + b] { return Err(format!("Wu block {b}: the prover's terminal value != the honest Wu's MLE")); }
    }
    Ok(())
}

// ===========================================================================
// [UPERF3-ZB] THE WIDENED-STACK (v3) STATEMENT — prover and verifier.
//
// The same skeleton as the v2 statement above (three Ligero commitments W /
// A / H, the two matmul sumchecks, two zero-checks, LogUp with committed
// helper columns, every pending claim folded into the zero-checks so A and
// H open at two points), generalized to any (T, d, f) by BLOCK STRUCTURE:
// the d axis is nb_d blocks of 2^log_db (768 = 3 x 256; 4096 = 1 x 4096),
// the f axis nb_f blocks of 2^log_fb (2048 = 1 x 2048; 14336 = 7 x 2048).
// No zero padding anywhere. What changes against v2 is the SEMANTICS:
//   - the table is the layer's frozen int16-out member (256 rows over the
//     int8 gate domain, int16 outputs): lookup rows g + beta S[g] + gamma
//     TAG_ACT16, the member's spec digest absorbed into the statement;
//   - the u16 / h16 / z16 classes are ONE 2^16-row range table
//     [-32768, 32767] (TAG_INT16) — the class the engine's v3 statement
//     proves (rng-u16 / rng-z16 at 2^16 rows, the h16 limb split);
//   - round-to-nearest requant is the exact identity acc = 2^sh y + r
//     with the BALANCED remainder r in [-2^(sh-1), 2^(sh-1)) — equivalent
//     to the engine's floor on the pre-shifted operand acc + 2^(sh-1) —
//     so the identities stay linear with no constant term and fold into
//     the evaluation claims exactly as v2's, and lane XX's zero-check
//     kernels (whose polynomials have that form) apply unchanged at the
//     125M shape; the remainder's range fact is the window table
//     tag_rem_v3(sh) (2^sh rows; the one-row window {0} at sh <= 0);
//   - negative sh_u (the exact public up-scaling branch, present in both
//     real exports) is the identity uacc = 2^-k u16 + 0: the public
//     coefficient of u16 is the field inverse of 2^k, the remainder column
//     is committed all-zero over the window {0};
//   - the signed shifts, (d, f), the family name and the member digest are
//     absorbed into the statement (domain "hashline-pass-v3" in the pass).
// The GPU path (HL_GPU=1): commitments, evaluations, helpers, row
// combinations and column gathers are shape-generic and run on the device
// for any shape; the two zero-checks run on the device exactly when the
// block counts match the XX kernels (nb_f == 1, nb_d == 3 — the 125M
// shape) and on the host otherwise (helpers then also on the host so the
// host tables exist). CPU and GPU proofs are byte-identical by the same
// differential discipline as v2.
// ===========================================================================

use crate::export_v3::V3Witness;
use crate::tables_v3::Act16Fn;

pub const TAG_ACT16: u64 = 3;
pub const TAG_INT16: u64 = 4;
/// The balanced-remainder window table of a signed shift (sh in -8..=16).
pub fn tag_rem_v3(sh: i32) -> u64 {
    64 + (sh + 8) as u64
}
pub fn rem_rows(sh: i32) -> usize {
    if sh <= 0 { 1 } else { 1usize << sh }
}
/// Row i of the window table: the remainder value it stands for.
pub fn rem_value(sh: i32, i: usize) -> i64 {
    if sh <= 0 { 0 } else { i as i64 - (1i64 << (sh - 1)) }
}
fn rem_index(sh: i32, r: i32) -> Option<usize> {
    if sh <= 0 {
        if r == 0 { Some(0) } else { None }
    } else {
        let v = r as i64 + (1i64 << (sh - 1));
        if v >= 0 && v < (1i64 << sh) { Some(v as usize) } else { None }
    }
}
/// The public coefficient of y in acc = coef * y + r: 2^sh, or the inverse
/// of 2^-sh at a negative shift (the exact up-scaling branch).
pub fn pow2_signed(sh: i32) -> Fp {
    if sh >= 0 { Fp::new(1u64 << sh) } else { Fp::new(1u64 << (-sh)).inv() }
}

#[derive(Clone, Debug)]
pub struct StatementV3 {
    pub l: usize,
    pub t_rows: usize,
    pub d: usize,
    pub f: usize,
    pub shifts: (i32, i32, i32, i32),
    pub act: Act16Fn,
    pub table: [i16; 256],
    pub table_digest: String,
}

/// Element offsets of every slice in the three committed vectors (block-structured).
#[derive(Clone, Debug)]
pub struct LayoutV3 {
    pub t_rows: usize, pub d: usize, pub f: usize,
    pub log_t: u32, pub log_db: u32, pub nb_d: usize, pub log_fb: u32, pub nb_f: usize,
    pub tfb: usize, pub tdb: usize, pub wb: usize, pub log_wb: u32, pub log_a_min: u32,
    pub g8: Vec<usize>, pub rg: Vec<usize>, pub a16: Vec<usize>, pub u16: Vec<usize>, pub ru: Vec<usize>, pub h16: Vec<usize>, pub rh: Vec<usize>,
    pub x: Vec<usize>, pub z: Vec<usize>, pub rd: Vec<usize>,
    pub a_len: usize,
    pub wg: Vec<usize>, pub wu: Vec<usize>, pub wd: Vec<usize>,
    pub w_len: usize,
    pub hg: Vec<(usize, usize)>, pub hu: Vec<(usize, usize)>, pub hh: Vec<(usize, usize)>, pub hz: Vec<(usize, usize)>,
    pub h_len: usize,
}

impl LayoutV3 {
    pub fn new(t_rows: usize, d: usize, f: usize) -> LayoutV3 {
        assert!(t_rows.is_power_of_two(), "t_rows must be a power of two");
        let log_t = t_rows.trailing_zeros();
        let log_db = d.trailing_zeros().min(12);
        let log_fb = f.trailing_zeros().min(12);
        let (db, fb) = (1usize << log_db, 1usize << log_fb);
        assert!(d % db == 0 && f % fb == 0 && log_db >= 4 && log_fb >= 4, "d {d} / f {f}: need >= 16 | d, f");
        let (nb_d, nb_f) = (d / db, f / fb);
        let tfb = t_rows * fb;
        let tdb = t_rows * db;
        let mut off = 0usize;
        let mut vecn = |n: usize, sz: usize| -> Vec<usize> { (0..n).map(|_| { let o = off; off += sz; o }).collect() };
        let g8 = vecn(nb_f, tfb); let rg = vecn(nb_f, tfb); let a16 = vecn(nb_f, tfb); let u16 = vecn(nb_f, tfb);
        let ru = vecn(nb_f, tfb); let h16 = vecn(nb_f, tfb); let rh = vecn(nb_f, tfb);
        let x = vecn(nb_d, tdb); let z = vecn(nb_d, tdb); let rd = vecn(nb_d, tdb);
        let a_len = off;
        let wb = db * fb;
        let log_wb = log_db + log_fb;
        let mut woff = 0usize;
        let mut wvec = |n: usize| -> Vec<usize> { (0..n).map(|_| { let o = woff; woff += wb; o }).collect() };
        let wg = wvec(nb_d * nb_f); let wu = wvec(nb_d * nb_f); let wd = wvec(nb_f * nb_d);
        let w_len = woff;
        let mut hoff = 0usize;
        let mut hvec = |n: usize, sz: usize| -> Vec<(usize, usize)> { (0..n).map(|_| { let o = hoff; hoff += 2 * sz; (o, o + sz) }).collect() };
        let hg = hvec(nb_f, tfb); let hu = hvec(nb_f, tfb); let hh = hvec(nb_f, tfb); let hz = hvec(nb_d, tdb);
        let h_len = hoff;
        LayoutV3 {
            t_rows, d, f, log_t, log_db, nb_d, log_fb, nb_f, tfb, tdb, wb, log_wb, log_a_min: log_t + log_db.min(log_fb),
            g8, rg, a16, u16, ru, h16, rh, x, z, rd, a_len, wg, wu, wd, w_len, hg, hu, hh, hz, h_len,
        }
    }
    fn s_f(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_t + self.log_fb } }
    fn s_d(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_t + self.log_db } }
    fn s_w(&self, off: usize) -> Slice { Slice { offset: off, log_size: self.log_wb } }
}

#[derive(Clone, Debug, Default)]
pub struct LayerProofV3 {
    pub w_com: Option<Commitment>,
    pub a_com: Option<Commitment>,
    pub h_com: Option<Commitment>,
    pub mults: Vec<(u64, Vec<u32>)>,
    pub gu_claims: Vec<Fp2>,
    pub gu_sc: SumcheckProof,
    pub gu_term: Vec<Fp2>,
    pub d_claims: Vec<Fp2>,
    pub d_sc: SumcheckProof,
    pub d_term: Vec<Fp2>,
    pub zcf_sc: SumcheckProof,
    pub zcf_term: Vec<Fp2>,
    pub zcd_sc: SumcheckProof,
    pub zcd_term: Vec<Fp2>,
    pub helper_sums: Vec<Fp2>,
    pub w_open: Opening,
    pub a_open: Opening,
    pub h_open: Opening,
    /// [UPERF3-AF] under `--pcs compact`: the ONE batched opening of W, A and H (the three above stay empty)
    pub cpcs_open: Option<pcs_compact::BatchOpening>,
}

impl LayerProofV3 {
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4);
        let mults: usize = self.mults.iter().map(|(_, m)| 8 + 4 + m.len() * 4).sum();
        let f2 = |v: &Vec<Fp2>| v.len() * 16;
        coms + mults + f2(&self.gu_claims) + self.gu_sc.size_bytes() + f2(&self.gu_term)
            + f2(&self.d_claims) + self.d_sc.size_bytes() + f2(&self.d_term)
            + self.zcf_sc.size_bytes() + f2(&self.zcf_term) + self.zcd_sc.size_bytes() + f2(&self.zcd_term)
            + f2(&self.helper_sums) + self.w_open.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
            + self.cpcs_open.as_ref().map(|b| b.size_bytes()).unwrap_or(0)
    }
    /// The flat little-endian encoding `size_bytes` counts (the CPU/GPU byte-identity gate).
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.size_bytes());
        let com = |out: &mut Vec<u8>, c: &Option<Commitment>| {
            let c = c.as_ref().expect("commitment");
            out.extend_from_slice(&c.root);
            out.extend_from_slice(&(c.rows as u64).to_le_bytes());
            out.extend_from_slice(&c.log_cols.to_le_bytes());
        };
        com(&mut out, &self.w_com);
        com(&mut out, &self.a_com);
        com(&mut out, &self.h_com);
        for (tag, m) in &self.mults {
            out.extend_from_slice(&tag.to_le_bytes());
            out.extend_from_slice(&(m.len() as u32).to_le_bytes());
            for v in m { out.extend_from_slice(&v.to_le_bytes()); }
        }
        let f2 = |out: &mut Vec<u8>, v: &Vec<Fp2>| { for x in v { out.extend_from_slice(&x.to_bytes()); } };
        f2(&mut out, &self.gu_claims);
        self.gu_sc.write_bytes(&mut out);
        f2(&mut out, &self.gu_term);
        f2(&mut out, &self.d_claims);
        self.d_sc.write_bytes(&mut out);
        f2(&mut out, &self.d_term);
        self.zcf_sc.write_bytes(&mut out);
        f2(&mut out, &self.zcf_term);
        self.zcd_sc.write_bytes(&mut out);
        f2(&mut out, &self.zcd_term);
        f2(&mut out, &self.helper_sums);
        self.w_open.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        if let Some(b) = &self.cpcs_open { b.write_bytes(&mut out); } // [UPERF3-AF]
        debug_assert_eq!(out.len(), self.size_bytes());
        out
    }
}

fn absorb_statement_v3(tr: &mut Transcript, st: &StatementV3) {
    tr.absorb(b"profile", b"v3-widened/round");
    tr.absorb_u64(b"layer", st.l as u64);
    tr.absorb_u64(b"t_rows", st.t_rows as u64);
    tr.absorb_u64(b"d", st.d as u64);
    tr.absorb_u64(b"f", st.f as u64);
    let mut sb = Vec::with_capacity(32);
    for s in [st.shifts.0, st.shifts.1, st.shifts.2, st.shifts.3] { sb.extend_from_slice(&(s as i64).to_le_bytes()); }
    tr.absorb(b"shifts-signed", &sb);
    tr.absorb(b"act", st.act.spec_name().as_bytes());
    tr.absorb(b"table", st.table_digest.as_bytes());
}

/// Multiplicity tables from the (possibly tampered) witness columns: values
/// outside a table are counted into entry 0 so the totals still match and
/// only the LogUp identity can catch them (what the tamper legs test).
fn multiplicities_v3(w: &V3Witness, lay: &LayoutV3) -> Vec<(u64, Vec<u32>)> {
    let tf = lay.t_rows * lay.f;
    let td = lay.t_rows * lay.d;
    let mut act = vec![0u32; 256];
    for &g in &w.g8[..tf] {
        if (-128..=127).contains(&g) { act[(g + 128) as usize] += 1; } else { act[0] += 1; }
    }
    let mut i16t = vec![0u32; 1 << 16];
    for col in [&w.u16v[..tf], &w.h16[..tf], &w.z16[..td]] {
        for &v in col {
            if (-32768..=32767).contains(&v) { i16t[(v + 32768) as usize] += 1; } else { i16t[0] += 1; }
        }
    }
    let (sg, su, sh, sz) = w.shifts;
    let mut out = vec![(TAG_ACT16, act), (TAG_INT16, i16t)];
    let mut shifts: Vec<i32> = vec![sg, su, sh, sz];
    shifts.sort();
    shifts.dedup();
    for s in shifts {
        let mut m = vec![0u32; rem_rows(s)];
        let cols: Vec<&[i32]> = [(sg, &w.rg[..tf]), (su, &w.ru[..tf]), (sh, &w.rh[..tf]), (sz, &w.rd[..td])]
            .into_iter().filter(|(c, _)| *c == s).map(|(_, v)| v).collect();
        for col in cols {
            for &r in col {
                match rem_index(s, r) { Some(i) => m[i] += 1, None => m[0] += 1 }
            }
        }
        out.push((tag_rem_v3(s), m));
    }
    out
}

pub struct ProveOutputV3 {
    pub proof: LayerProofV3,
    pub timings: Vec<(String, f64)>,
}

struct HostTabsV3 {
    // per f-block: g8, rg, a16, u16, ru, h16, rh, hg, hu, hh
    fb: Vec<Vec<Vec<Fp2>>>,
    // per d-block: z, rd, hz
    db: Vec<Vec<Vec<Fp2>>>,
}

/// Prove one v3 layer over the first `t_rows` rows of the witness.
pub fn prove_layer_v3(w: &V3Witness, t_rows: usize, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript) -> ProveOutputV3 {
    use std::time::Instant;
    let mut timings = Vec::new();
    let mut tick = Instant::now();
    let lap = |name: &str, timings: &mut Vec<(String, f64)>, tick: &mut Instant| {
        timings.push((name.to_string(), tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    assert!(t_rows <= w.t_rows, "witness derived over {} rows < {t_rows}", w.t_rows);
    let lay = LayoutV3::new(t_rows, w.dims.d, w.dims.f);
    let (d, f) = (lay.d, lay.f);
    let (nb_d, nb_f, db, fb, tfb, tdb, wb) = (lay.nb_d, lay.nb_f, 1usize << lay.log_db, 1usize << lay.log_fb, lay.tfb, lay.tdb, lay.wb);
    let (sh_g, sh_u, sh_h, sh_z) = w.shifts;
    let st = StatementV3 { l: w.l, t_rows, d, f, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone() };
    absorb_statement_v3(tr, &st);
    let mut proof = LayerProofV3::default();

    // ---- W data + commit ------------------------------------------------
    let mut w_data = vec![Fp::ZERO; lay.w_len];
    for c in 0..nb_d {
        for b in 0..nb_f {
            for (offs, src) in [(&lay.wg, &w.wg_t), (&lay.wu, &w.wu_t)] {
                let off = offs[c * nb_f + b];
                w_data[off..off + wb].par_chunks_mut(fb).enumerate().for_each(|(kp, row)| {
                    let k = c * db + kp;
                    for jp in 0..fb { row[jp] = Fp::from_i64(src[k * f + b * fb + jp] as i64); }
                });
            }
            let off = lay.wd[b * nb_d + c];
            w_data[off..off + wb].par_chunks_mut(db).enumerate().for_each(|(jp, row)| {
                let j = b * fb + jp;
                for np in 0..db { row[np] = Fp::from_i64(w.wd_t[j * d + c * db + np] as i64); }
            });
        }
    }
    let w_pcs = params.pcs_for(lay.log_wb);
    let w_cm = pcs_compact::commit(&w_pcs, &w_data, ntt); // [UPERF3-AF] Ligero unless --pcs compact
    proof.w_com = Some(w_cm.commitment());
    absorb_com(tr, b"W", proof.w_com.as_ref().unwrap());
    lap("commit W", &mut timings, &mut tick);

    // ---- A data + commit ------------------------------------------------
    let mut a_data = vec![Fp::ZERO; lay.a_len];
    for b in 0..nb_f {
        for (offs, col) in [(&lay.g8, &w.g8), (&lay.rg, &w.rg), (&lay.a16, &w.a16), (&lay.u16, &w.u16v), (&lay.ru, &w.ru), (&lay.h16, &w.h16), (&lay.rh, &w.rh)] {
            let off = offs[b];
            a_data[off..off + tfb].par_chunks_mut(fb).enumerate().for_each(|(t, row)| {
                for jp in 0..fb { row[jp] = Fp::from_i64(col[t * f + b * fb + jp] as i64); }
            });
        }
    }
    for c in 0..nb_d {
        a_data[lay.x[c]..lay.x[c] + tdb].par_chunks_mut(db).enumerate().for_each(|(t, row)| {
            for kp in 0..db { row[kp] = Fp::from_i64(w.x[t * d + c * db + kp] as i64); }
        });
        for (offs, col) in [(&lay.z, &w.z16), (&lay.rd, &w.rd)] {
            let off = offs[c];
            a_data[off..off + tdb].par_chunks_mut(db).enumerate().for_each(|(t, row)| {
                for kp in 0..db { row[kp] = Fp::from_i64(col[t * d + c * db + kp] as i64); }
            });
        }
    }
    let a_pcs = params.pcs_for(lay.log_a_min);
    let a_cm = pcs_compact::commit(&a_pcs, &a_data, ntt); // [UPERF3-AF]
    proof.a_com = Some(a_cm.commitment());
    absorb_com(tr, b"A", proof.a_com.as_ref().unwrap());
    lap("commit A", &mut timings, &mut tick);

    // ---- multiplicities, challenges, helpers, commit H --------------------
    proof.mults = multiplicities_v3(w, &lay);
    absorb_mults(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_act = gamma.mul_base(Fp::new(TAG_ACT16));
    let g_i16 = gamma.mul_base(Fp::new(TAG_INT16));
    let g_rg = gamma.mul_base(Fp::new(tag_rem_v3(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_rem_v3(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_rem_v3(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_rem_v3(sh_z)));
    let h_pcs = params.pcs_for(lay.log_a_min);
    // the XX zero-check kernels are fixed at 13 / 15 tables: the 125M block shape
    let dev_shape = nb_f == 1 && nb_d == 3;
    #[cfg(not(feature = "gpu-cuda"))]
    let _ = dev_shape;
    let mut host_tabs: Option<HostTabsV3> = None;
    let mut h_data: Vec<Fp> = Vec::new();
    let mut dev_helper_sums: Option<Vec<Fp2>> = None;
    #[cfg(feature = "gpu-cuda")]
    let h_cm_dev: Option<AnyCm> = if let (true, true, Some(a_dc)) = (crate::gpu::enabled(), dev_shape, dev_of(&a_cm)) {
        use crate::gpu::HelperSpec;
        let mut specs = vec![
            HelperSpec { off_v1: lay.g8[0], off_w: Some(lay.a16[0]), off_v2: lay.rg[0], len: tfb, c1: g_act, c2: g_rg, off_re: lay.hg[0].0, off_im: lay.hg[0].1 },
            HelperSpec { off_v1: lay.u16[0], off_w: None, off_v2: lay.ru[0], len: tfb, c1: g_i16, c2: g_ru, off_re: lay.hu[0].0, off_im: lay.hu[0].1 },
            HelperSpec { off_v1: lay.h16[0], off_w: None, off_v2: lay.rh[0], len: tfb, c1: g_i16, c2: g_rh, off_re: lay.hh[0].0, off_im: lay.hh[0].1 },
        ];
        for c in 0..nb_d {
            specs.push(HelperSpec { off_v1: lay.z[c], off_w: None, off_v2: lay.rd[c], len: tdb, c1: g_i16, c2: g_rd, off_re: lay.hz[c].0, off_im: lay.hz[c].1 });
        }
        let rows = lay.h_len / h_pcs.cols();
        let r = crate::gpu::dev_helpers(a_dc, lay.h_len, &specs, alpha, beta)
            .and_then(|(d_h, sums)| crate::gpu::dev_commit_from(&h_pcs, d_h, rows, ntt).map(|(dc, leaves)| (dc, leaves, sums)));
        match r {
            Ok((dc, leaves, sums)) => {
                dev_helper_sums = Some(sums);
                Some(AnyCm::Ligero(pcs::Committed { params: h_pcs, rows, store: pcs::Store::Device(dc), tree: crate::merkle::MerkleTree::build(leaves) }))
            }
            Err(e) => { eprintln!("[UPERF3-ZB] gpu helpers declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let h_cm_dev: Option<AnyCm> = None;
    let h_cm = match h_cm_dev {
        Some(cm) => cm,
        None => {
            let to2 = |off: usize, len: usize| -> Vec<Fp2> { a_data[off..off + len].par_iter().map(|v| Fp2::from_base(*v)).collect() };
            h_data = vec![Fp::ZERO; lay.h_len];
            let mut fbt: Vec<Vec<Vec<Fp2>>> = Vec::with_capacity(nb_f);
            for b in 0..nb_f {
                let g8f = to2(lay.g8[b], tfb); let rgf = to2(lay.rg[b], tfb); let a16f = to2(lay.a16[b], tfb);
                let u16f = to2(lay.u16[b], tfb); let ruf = to2(lay.ru[b], tfb); let h16f = to2(lay.h16[b], tfb); let rhf = to2(lay.rh[b], tfb);
                let lg: Vec<Fp2> = g8f.par_iter().zip(a16f.par_iter()).map(|(g, a)| g.add(beta.mul(*a)).add(g_act)).collect();
                let lrg: Vec<Fp2> = rgf.par_iter().map(|r| r.add(g_rg)).collect();
                let lu: Vec<Fp2> = u16f.par_iter().map(|v| v.add(g_i16)).collect();
                let lru: Vec<Fp2> = ruf.par_iter().map(|r| r.add(g_ru)).collect();
                let lh: Vec<Fp2> = h16f.par_iter().map(|v| v.add(g_i16)).collect();
                let lrh: Vec<Fp2> = rhf.par_iter().map(|r| r.add(g_rh)).collect();
                let hg = helper_column(&lg, &lrg, alpha);
                let hu = helper_column(&lu, &lru, alpha);
                let hh = helper_column(&lh, &lrh, alpha);
                for (col, (ore, oim)) in [(&hg, lay.hg[b]), (&hu, lay.hu[b]), (&hh, lay.hh[b])] {
                    h_data[ore..ore + tfb].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c0);
                    h_data[oim..oim + tfb].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c1);
                }
                fbt.push(vec![g8f, rgf, a16f, u16f, ruf, h16f, rhf, hg, hu, hh]);
            }
            let mut dbt: Vec<Vec<Vec<Fp2>>> = Vec::with_capacity(nb_d);
            for c in 0..nb_d {
                let zf = to2(lay.z[c], tdb);
                let rdf = to2(lay.rd[c], tdb);
                let lz: Vec<Fp2> = zf.par_iter().map(|v| v.add(g_i16)).collect();
                let lrd: Vec<Fp2> = rdf.par_iter().map(|r| r.add(g_rd)).collect();
                let hz = helper_column(&lz, &lrd, alpha);
                let (ore, oim) = lay.hz[c];
                h_data[ore..ore + tdb].par_iter_mut().zip(hz.par_iter()).for_each(|(o, v)| *o = v.c0);
                h_data[oim..oim + tdb].par_iter_mut().zip(hz.par_iter()).for_each(|(o, v)| *o = v.c1);
                dbt.push(vec![zf, rdf, hz]);
            }
            host_tabs = Some(HostTabsV3 { fb: fbt, db: dbt });
            pcs_compact::commit(&h_pcs, &h_data, ntt) // [UPERF3-AF]
        }
    };
    proof.h_com = Some(h_cm.commitment());
    absorb_com(tr, b"H", proof.h_com.as_ref().unwrap());
    lap("helpers + commit H", &mut timings, &mut tick);

    // ---- g/u matmul sumcheck -------------------------------------------------
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(lay.log_fb as usize);
    let lam_gu = tr.challenge_fp2();
    let lam_f = tr.challenge_fp2_vec(nb_f);
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    let mut sl: Vec<(usize, usize)> = Vec::with_capacity(4 * nb_f);
    for b in 0..nb_f { sl.extend([(lay.g8[b], tfb), (lay.rg[b], tfb), (lay.u16[b], tfb), (lay.ru[b], tfb)]); }
    let ev = eval_many_dev(&a_cm, &a_data, &sl, &p1);
    let (p_g, p_u, p_h, p_z) = (pow2_signed(sh_g), pow2_signed(sh_u), pow2_signed(sh_h), pow2_signed(sh_z));
    for b in 0..nb_f {
        proof.gu_claims.push(ev[4 * b].mul_base(p_g).add(ev[4 * b + 1]));
        proof.gu_claims.push(ev[4 * b + 2].mul_base(p_u).add(ev[4 * b + 3]));
    }
    tr.absorb_fp2(b"gu-claims", &proof.gu_claims);
    let eq_ri = eq_table_msb(&r_i);
    let eq_rj = eq_table_msb(&r_j);
    let xk = fold_rows_i8(&w.x[..t_rows * d], t_rows, d, &eq_ri); // d
    let cw_gu: Vec<Fp2> = (0..f).into_par_iter().map(|j| lam_f[j / fb].mul(eq_rj[j % fb])).collect();
    let wgk = fold_cols_i8(&w.wg_t, d, f, &cw_gu); // d
    let wuk = fold_cols_i8(&w.wu_t, d, f, &cw_gu); // d
    let mut tables: Vec<Vec<Fp2>> = Vec::with_capacity(2 * nb_d);
    for c in 0..nb_d { tables.push(xk[c * db..(c + 1) * db].to_vec()); }
    for c in 0..nb_d {
        tables.push(wgk[c * db..(c + 1) * db].iter().zip(wuk[c * db..(c + 1) * db].iter()).map(|(g, u)| g.add(lam_gu.mul(*u))).collect());
    }
    let nbd = nb_d;
    let out = sumcheck::prove(&mut tables, 2, move |v| { let mut s = Fp2::ZERO; for c in 0..nbd { s = s.add(v[c].mul(v[nbd + c])); } s }, tr);
    proof.gu_sc = out.proof;
    let r_kp = out.challenges; // log_db
    let mut term = Vec::with_capacity(nb_d + 2 * nb_d * nb_f);
    for c in 0..nb_d { term.push(out.finals[c]); }
    for offs in [&lay.wg, &lay.wu] {
        for c in 0..nb_d {
            for b in 0..nb_f {
                let blk = &w_data[offs[c * nb_f + b]..offs[c * nb_f + b] + wb];
                let folded = fold_cols_base(blk, db, fb, &eq_rj);
                term.push(eval_mle_ext(&folded, &r_kp));
            }
        }
    }
    proof.gu_term = term;
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp); // X_c point (log_t + log_db)
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j); // Wg/Wu blocks point (log_wb)
    lap("matmul g/u", &mut timings, &mut tick);

    // ---- d matmul sumcheck ------------------------------------------------------
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(lay.log_db as usize);
    let lam_d = tr.challenge_fp2_vec(nb_d);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    let mut sl: Vec<(usize, usize)> = Vec::with_capacity(2 * nb_d);
    for c in 0..nb_d { sl.extend([(lay.z[c], tdb), (lay.rd[c], tdb)]); }
    let ev = eval_many_dev(&a_cm, &a_data, &sl, &p4);
    proof.d_claims = (0..nb_d).map(|c| ev[2 * c].mul_base(p_z).add(ev[2 * c + 1])).collect();
    tr.absorb_fp2(b"d-claims", &proof.d_claims);
    let eq_rip = eq_table_msb(&r_ip);
    let eq_rjp = eq_table_msb(&r_jp);
    let hk = fold_rows_i32(&w.h16[..t_rows * f], t_rows, f, &eq_rip); // f
    let cw_d: Vec<Fp2> = (0..d).into_par_iter().map(|n| lam_d[n / db].mul(eq_rjp[n % db])).collect();
    let wdk = fold_cols_i8(&w.wd_t, f, d, &cw_d); // f
    let mut tables: Vec<Vec<Fp2>> = Vec::with_capacity(2 * nb_f);
    for b in 0..nb_f { tables.push(hk[b * fb..(b + 1) * fb].to_vec()); }
    for b in 0..nb_f { tables.push(wdk[b * fb..(b + 1) * fb].to_vec()); }
    let nbf = nb_f;
    let out = sumcheck::prove(&mut tables, 2, move |v| { let mut s = Fp2::ZERO; for b in 0..nbf { s = s.add(v[b].mul(v[nbf + b])); } s }, tr);
    proof.d_sc = out.proof;
    let r_k = out.challenges; // log_fb
    let mut term = Vec::with_capacity(nb_f + nb_f * nb_d);
    for b in 0..nb_f { term.push(out.finals[b]); }
    for b in 0..nb_f {
        for c in 0..nb_d {
            let blk = &w_data[lay.wd[b * nb_d + c]..lay.wd[b * nb_d + c] + wb];
            let folded = fold_cols_base(blk, fb, db, &eq_rjp);
            term.push(eval_mle_ext(&folded, &r_k));
        }
    }
    proof.d_term = term;
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k); // h16_b point (log_t + log_fb)
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp); // Wd blocks point (log_wb)
    lap("matmul d", &mut timings, &mut tick);

    // ---- zero-check F (the f-side planes) ------------------------------------------
    let tau = tr.challenge_fp2_vec((lay.log_t + lay.log_fb) as usize);
    let mu = tr.challenge_fp2_vec(4 * nb_f);
    let nu = tr.challenge_fp2_vec(3 * nb_f);
    #[cfg(feature = "gpu-cuda")]
    let dev_out = if let (true, true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_shape, dev_of(&a_cm), dev_of(&h_cm)) {
        use crate::gpu::TabSpec;
        let specs = vec![
            TabSpec::Eq(&tau), TabSpec::Eq(&p1), TabSpec::Eq(&p5),
            TabSpec::FromFp(a_dc, lay.g8[0], tfb), TabSpec::FromFp(a_dc, lay.rg[0], tfb), TabSpec::FromFp(a_dc, lay.a16[0], tfb),
            TabSpec::FromFp(a_dc, lay.u16[0], tfb), TabSpec::FromFp(a_dc, lay.ru[0], tfb), TabSpec::FromFp(a_dc, lay.h16[0], tfb), TabSpec::FromFp(a_dc, lay.rh[0], tfb),
            TabSpec::FromFp2(h_dc, lay.hg[0].0, lay.hg[0].1, tfb), TabSpec::FromFp2(h_dc, lay.hu[0].0, lay.hu[0].1, tfb), TabSpec::FromFp2(h_dc, lay.hh[0].0, lay.hh[0].1, tfb),
        ];
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, beta, g_act, g_rg, g_ru, g_rh, g_i16, mu[0], mu[1], mu[2], mu[3], nu[0], nu[1], nu[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.extend([p_g.0, p_u.0, p_h.0]);
        let mut tr_try = Transcript::clone_state(tr);
        match crate::gpu::dev_zerocheck(0, &specs, &prm, &mut tr_try) {
            Ok(out) => { *tr = tr_try; Some(out) }
            Err(e) => { eprintln!("[UPERF3-ZB] gpu zero-check F declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_out: Option<sumcheck::ProverOutput> = None;
    let out = match dev_out {
        Some(out) => out,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check F: the device path declined after the device helpers; no host tables (rerun with HL_GPU unset)");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau), eq_table_msb(&p1), eq_table_msb(&p5)];
            for b in 0..nb_f { for t in std::mem::take(&mut ht.fb[b]) { tables.push(t); } }
            let (mu, nu) = (mu.clone(), nu.clone());
            let zcf_poly = move |v: &[Fp2]| -> Fp2 {
                let (eqt, eq1, eq5) = (v[0], v[1], v[2]);
                let mut zc = Fp2::ZERO;
                let mut f1 = Fp2::ZERO;
                let mut f5 = Fp2::ZERO;
                for b in 0..nbf {
                    let o = 3 + 10 * b;
                    let (g8, rg, a16, u16, ru, h16, rh, hg, hu, hh) = (v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6], v[o + 7], v[o + 8], v[o + 9]);
                    let c_had = a16.mul(u16).sub(h16.mul_base(p_h)).sub(rh);
                    let c_hg = helper_constraint(hg, g8.add(beta.mul(a16)).add(g_act), rg.add(g_rg), alpha);
                    let c_hu = helper_constraint(hu, u16.add(g_i16), ru.add(g_ru), alpha);
                    let c_hh = helper_constraint(hh, h16.add(g_i16), rh.add(g_rh), alpha);
                    zc = zc.add(mu[4 * b].mul(c_had)).add(mu[4 * b + 1].mul(c_hg)).add(mu[4 * b + 2].mul(c_hu)).add(mu[4 * b + 3].mul(c_hh));
                    f1 = f1.add(nu[3 * b].mul(g8.mul_base(p_g).add(rg))).add(nu[3 * b + 1].mul(u16.mul_base(p_u).add(ru)));
                    f5 = f5.add(nu[3 * b + 2].mul(h16));
                }
                eqt.mul(zc).add(eq1.mul(f1)).add(eq5.mul(f5))
            };
            let out = sumcheck::prove(&mut tables, 4, zcf_poly, tr);
            drop(tables);
            out
        }
    };
    proof.zcf_sc = out.proof;
    let rho_f = out.challenges;
    proof.zcf_term = out.finals[3..].to_vec();
    tr.absorb_fp2(b"zcf-term", &proof.zcf_term);
    lap("zero-check F", &mut timings, &mut tick);

    // ---- zero-check D (the d-side planes) ------------------------------------------
    let tau2 = tr.challenge_fp2_vec((lay.log_t + lay.log_db) as usize);
    let mu2 = tr.challenge_fp2_vec(nb_d);
    let nu_x = tr.challenge_fp2_vec(nb_d);
    let nu_z = tr.challenge_fp2_vec(nb_d);
    #[cfg(feature = "gpu-cuda")]
    let dev_out = if let (true, true, Some(a_dc), Some(h_dc)) = (crate::gpu::enabled(), dev_shape, dev_of(&a_cm), dev_of(&h_cm)) {
        use crate::gpu::TabSpec;
        let mut specs = vec![TabSpec::Eq(&tau2), TabSpec::Eq(&p2), TabSpec::Eq(&p4)];
        for c in 0..nb_d { specs.push(TabSpec::FromFp(a_dc, lay.x[c], tdb)); }
        for c in 0..nb_d { specs.push(TabSpec::FromFp(a_dc, lay.z[c], tdb)); }
        for c in 0..nb_d { specs.push(TabSpec::FromFp(a_dc, lay.rd[c], tdb)); }
        for c in 0..nb_d { specs.push(TabSpec::FromFp2(h_dc, lay.hz[c].0, lay.hz[c].1, tdb)); }
        let mut prm: Vec<u64> = Vec::new();
        for v in [alpha, g_i16, g_rd, mu2[0], mu2[1], mu2[2], nu_x[0], nu_x[1], nu_x[2], nu_z[0], nu_z[1], nu_z[2]] {
            prm.push(v.c0.0);
            prm.push(v.c1.0);
        }
        prm.push(p_z.0);
        let mut tr_try = Transcript::clone_state(tr);
        match crate::gpu::dev_zerocheck(1, &specs, &prm, &mut tr_try) {
            Ok(out) => { *tr = tr_try; Some(out) }
            Err(e) => { eprintln!("[UPERF3-ZB] gpu zero-check D declined ({e}); CPU path"); None }
        }
    } else { None };
    #[cfg(not(feature = "gpu-cuda"))]
    let dev_out: Option<sumcheck::ProverOutput> = None;
    let out = match dev_out {
        Some(out) => out,
        None => {
            let ht = host_tabs.as_mut().expect("zero-check D: the device path declined after the device helpers; no host tables (rerun with HL_GPU unset)");
            let mut tables: Vec<Vec<Fp2>> = vec![eq_table_msb(&tau2), eq_table_msb(&p2), eq_table_msb(&p4)];
            for c in 0..nb_d { tables.push(a_data[lay.x[c]..lay.x[c] + tdb].par_iter().map(|v| Fp2::from_base(*v)).collect()); }
            let mut dbt: Vec<Vec<Vec<Fp2>>> = (0..nb_d).map(|c| std::mem::take(&mut ht.db[c])).collect();
            for role in 0..3 { for c in 0..nb_d { tables.push(std::mem::take(&mut dbt[c][role])); } }
            let (mu2, nu_x, nu_z) = (mu2.clone(), nu_x.clone(), nu_z.clone());
            let zcd_poly = move |v: &[Fp2]| -> Fp2 {
                let (eqt, eq2, eq4) = (v[0], v[1], v[2]);
                let mut zc = Fp2::ZERO;
                let mut fx = Fp2::ZERO;
                let mut fz = Fp2::ZERO;
                for c in 0..nbd {
                    let (x, z, rd, h) = (v[3 + c], v[3 + nbd + c], v[3 + 2 * nbd + c], v[3 + 3 * nbd + c]);
                    zc = zc.add(mu2[c].mul(helper_constraint(h, z.add(g_i16), rd.add(g_rd), alpha)));
                    fx = fx.add(nu_x[c].mul(x));
                    fz = fz.add(nu_z[c].mul(z.mul_base(p_z).add(rd)));
                }
                eqt.mul(zc).add(eq2.mul(fx)).add(eq4.mul(fz))
            };
            let out = sumcheck::prove(&mut tables, 4, zcd_poly, tr);
            drop(tables);
            out
        }
    };
    proof.zcd_sc = out.proof;
    let rho_d = out.challenges;
    proof.zcd_term = out.finals[3..].to_vec();
    tr.absorb_fp2(b"zcd-term", &proof.zcd_term);
    lap("zero-check D", &mut timings, &mut tick);

    // ---- helper sums ---------------------------------------------------------------
    proof.helper_sums = match dev_helper_sums.take() {
        Some(s) => s,
        None => {
            let sums = |re: usize, im: usize, len: usize| -> Fp2 {
                let sre = h_data[re..re + len].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                let sim = h_data[im..im + len].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                Fp2::new(sre, sim)
            };
            let mut v = Vec::with_capacity(3 * nb_f + nb_d);
            for b in 0..nb_f { for (re, im) in [lay.hg[b], lay.hu[b], lay.hh[b]] { v.push(sums(re, im, tfb)); } }
            for c in 0..nb_d { v.push(sums(lay.hz[c].0, lay.hz[c].1, tdb)); }
            v
        }
    };
    drop(host_tabs);
    tr.absorb_fp2(b"helper-sums", &proof.helper_sums);

    // ---- PCS openings -------------------------------------------------------------
    let (w_claims, a_claims, h_claims) = build_claims_v3(&lay, &proof, &p3, &p6, &rho_f, &rho_d);
    if pcs_compact::selected() {
        // [UPERF3-AF] ONE batched compact opening of the three commitments
        proof.cpcs_open = Some(pcs_compact::open_batch(&[(w_cm.compact(), &w_claims), (a_cm.compact(), &a_claims), (h_cm.compact(), &h_claims)], tr));
        drop(w_cm);
        drop(w_data);
        drop(a_cm);
        drop(h_cm);
    } else {
        proof.w_open = pcs::open(w_cm.lig(), &w_claims, tr);
        drop(w_cm);
        drop(w_data);
        proof.a_open = pcs::open(a_cm.lig(), &a_claims, tr);
        drop(a_cm);
        proof.h_open = pcs::open(h_cm.lig(), &h_claims, tr);
        drop(h_cm);
    }
    lap("pcs openings", &mut timings, &mut tick);
    ProveOutputV3 { proof, timings }
}

/// The PCS claims of a v3 layer proof (shared by prover and verifier).
fn build_claims_v3(lay: &LayoutV3, proof: &LayerProofV3, p3: &[Fp2], p6: &[Fp2], rho_f: &[Fp2], rho_d: &[Fp2]) -> (Vec<Claim>, Vec<Claim>, Vec<Claim>) {
    let one = Fp2::ONE;
    let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
    let mut wc = Vec::new();
    for (ri, offs) in [(0usize, &lay.wg), (1, &lay.wu)] {
        for c in 0..nb_d {
            for b in 0..nb_f {
                wc.push(Claim { parts: vec![(lay.s_w(offs[c * nb_f + b]), one)], point: p3.to_vec(), sum: false, value: proof.gu_term[nb_d + ri * nb_d * nb_f + c * nb_f + b] });
            }
        }
    }
    for b in 0..nb_f {
        for c in 0..nb_d {
            wc.push(Claim { parts: vec![(lay.s_w(lay.wd[b * nb_d + c]), one)], point: p6.to_vec(), sum: false, value: proof.d_term[nb_f + b * nb_d + c] });
        }
    }
    let mut ac = Vec::new();
    for b in 0..nb_f {
        let cols = [lay.g8[b], lay.rg[b], lay.a16[b], lay.u16[b], lay.ru[b], lay.h16[b], lay.rh[b]];
        for (i, off) in cols.iter().enumerate() {
            ac.push(Claim { parts: vec![(lay.s_f(*off), one)], point: rho_f.to_vec(), sum: false, value: proof.zcf_term[10 * b + i] });
        }
    }
    for c in 0..nb_d { ac.push(Claim { parts: vec![(lay.s_d(lay.x[c]), one)], point: rho_d.to_vec(), sum: false, value: proof.zcd_term[c] }); }
    for c in 0..nb_d { ac.push(Claim { parts: vec![(lay.s_d(lay.z[c]), one)], point: rho_d.to_vec(), sum: false, value: proof.zcd_term[nb_d + c] }); }
    for c in 0..nb_d { ac.push(Claim { parts: vec![(lay.s_d(lay.rd[c]), one)], point: rho_d.to_vec(), sum: false, value: proof.zcd_term[2 * nb_d + c] }); }
    let mut hc = Vec::new();
    let u = Fp2::U;
    for b in 0..nb_f {
        for (i, (re, im)) in [lay.hg[b], lay.hu[b], lay.hh[b]].iter().enumerate() {
            hc.push(Claim { parts: vec![(lay.s_f(*re), one), (lay.s_f(*im), u)], point: rho_f.to_vec(), sum: false, value: proof.zcf_term[10 * b + 7 + i] });
        }
    }
    for c in 0..nb_d {
        let (re, im) = lay.hz[c];
        hc.push(Claim { parts: vec![(lay.s_d(re), one), (lay.s_d(im), u)], point: rho_d.to_vec(), sum: false, value: proof.zcd_term[3 * nb_d + c] });
    }
    for b in 0..nb_f {
        for (i, (re, im)) in [lay.hg[b], lay.hu[b], lay.hh[b]].iter().enumerate() {
            hc.push(Claim { parts: vec![(lay.s_f(*re), one), (lay.s_f(*im), u)], point: vec![], sum: true, value: proof.helper_sums[3 * b + i] });
        }
    }
    for c in 0..nb_d {
        let (re, im) = lay.hz[c];
        hc.push(Claim { parts: vec![(lay.s_d(re), one), (lay.s_d(im), u)], point: vec![], sum: true, value: proof.helper_sums[3 * nb_f + c] });
    }
    (wc, ac, hc)
}

/// Verify one v3 layer proof against the public statement.
pub fn verify_layer_v3(st: &StatementV3, proof: &LayerProofV3, params: &LayerParams, ntt: &NttTables, tr: &mut Transcript) -> Result<(), String> {
    let lay = LayoutV3::new(st.t_rows, st.d, st.f);
    let (nb_d, nb_f) = (lay.nb_d, lay.nb_f);
    let tf = st.t_rows * st.f;
    let td = st.t_rows * st.d;
    let (sh_g, sh_u, sh_h, sh_z) = st.shifts;
    absorb_statement_v3(tr, st);
    let w_com = proof.w_com.as_ref().ok_or("missing W commitment")?;
    let a_com = proof.a_com.as_ref().ok_or("missing A commitment")?;
    let h_com = proof.h_com.as_ref().ok_or("missing H commitment")?;
    let w_pcs = params.pcs_for(lay.log_wb);
    let a_pcs = params.pcs_for(lay.log_a_min);
    let h_pcs = params.pcs_for(lay.log_a_min);
    if w_com.rows != lay.w_len / w_pcs.cols() { return Err("W commitment rows".into()); }
    if a_com.rows != lay.a_len / a_pcs.cols() { return Err("A commitment rows".into()); }
    if h_com.rows != lay.h_len / h_pcs.cols() { return Err("H commitment rows".into()); }
    absorb_com(tr, b"W", w_com);
    absorb_com(tr, b"A", a_com);
    // multiplicities: shape + totals
    let mut shifts: Vec<i32> = vec![sh_g, sh_u, sh_h, sh_z];
    shifts.sort();
    shifts.dedup();
    if proof.mults.len() != 2 + shifts.len() { return Err("multiplicity table count".into()); }
    if proof.mults[0].0 != TAG_ACT16 || proof.mults[0].1.len() != 256 { return Err("act16 multiplicities".into()); }
    if proof.mults[1].0 != TAG_INT16 || proof.mults[1].1.len() != 1 << 16 { return Err("int16 multiplicities".into()); }
    for (i, s) in shifts.iter().enumerate() {
        let (tag, m) = &proof.mults[2 + i];
        if *tag != tag_rem_v3(*s) || m.len() != rem_rows(*s) { return Err(format!("rem({s}) multiplicities")); }
        let want: usize = [(sh_g, tf), (sh_u, tf), (sh_h, tf), (sh_z, td)].iter().filter(|(c, _)| c == s).map(|(_, n)| n).sum();
        let got: u64 = m.iter().map(|&x| x as u64).sum();
        if got != want as u64 { return Err(format!("rem({s}) multiplicity total {got} != {want}")); }
    }
    let act_total: u64 = proof.mults[0].1.iter().map(|&x| x as u64).sum();
    if act_total != tf as u64 { return Err("act16 multiplicity total".into()); }
    let i16_total: u64 = proof.mults[1].1.iter().map(|&x| x as u64).sum();
    if i16_total != (2 * tf + td) as u64 { return Err("int16 multiplicity total".into()); }
    absorb_mults(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    absorb_com(tr, b"H", h_com);
    let g_act = gamma.mul_base(Fp::new(TAG_ACT16));
    let g_i16 = gamma.mul_base(Fp::new(TAG_INT16));
    let g_rg = gamma.mul_base(Fp::new(tag_rem_v3(sh_g)));
    let g_ru = gamma.mul_base(Fp::new(tag_rem_v3(sh_u)));
    let g_rh = gamma.mul_base(Fp::new(tag_rem_v3(sh_h)));
    let g_rd = gamma.mul_base(Fp::new(tag_rem_v3(sh_z)));
    let (p_g, p_u, p_h, p_z) = (pow2_signed(sh_g), pow2_signed(sh_u), pow2_signed(sh_h), pow2_signed(sh_z));

    // ---- g/u matmul ----
    let r_i = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_j = tr.challenge_fp2_vec(lay.log_fb as usize);
    let lam_gu = tr.challenge_fp2();
    let lam_f = tr.challenge_fp2_vec(nb_f);
    let mut p1 = r_i.clone();
    p1.extend_from_slice(&r_j);
    if proof.gu_claims.len() != 2 * nb_f { return Err("gu claims".into()); }
    tr.absorb_fp2(b"gu-claims", &proof.gu_claims);
    let claim = (0..nb_f).fold(Fp2::ZERO, |a, b| a.add(lam_f[b].mul(proof.gu_claims[2 * b].add(lam_gu.mul(proof.gu_claims[2 * b + 1])))));
    let (fin, r_kp) = sumcheck::verify(claim, 2, lay.log_db as usize, &proof.gu_sc, tr)?;
    if proof.gu_term.len() != nb_d + 2 * nb_d * nb_f { return Err("gu terminal".into()); }
    let mut want = Fp2::ZERO;
    for c in 0..nb_d {
        let mut wsum = Fp2::ZERO;
        for b in 0..nb_f {
            let wg = proof.gu_term[nb_d + c * nb_f + b];
            let wu = proof.gu_term[nb_d + nb_d * nb_f + c * nb_f + b];
            wsum = wsum.add(lam_f[b].mul(wg.add(lam_gu.mul(wu))));
        }
        want = want.add(proof.gu_term[c].mul(wsum));
    }
    if want != fin { return Err("g/u matmul sumcheck terminal check fails".into()); }
    tr.absorb_fp2(b"gu-term", &proof.gu_term);
    let mut p2 = r_i.clone();
    p2.extend_from_slice(&r_kp);
    let mut p3 = r_kp.clone();
    p3.extend_from_slice(&r_j);

    // ---- d matmul ----
    let r_ip = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jp = tr.challenge_fp2_vec(lay.log_db as usize);
    let lam_d = tr.challenge_fp2_vec(nb_d);
    let mut p4 = r_ip.clone();
    p4.extend_from_slice(&r_jp);
    if proof.d_claims.len() != nb_d { return Err("d claims".into()); }
    tr.absorb_fp2(b"d-claims", &proof.d_claims);
    let d_sum = (0..nb_d).fold(Fp2::ZERO, |a, c| a.add(lam_d[c].mul(proof.d_claims[c])));
    let (fin, r_k) = sumcheck::verify(d_sum, 2, lay.log_fb as usize, &proof.d_sc, tr)?;
    if proof.d_term.len() != nb_f + nb_f * nb_d { return Err("d terminal".into()); }
    let mut want = Fp2::ZERO;
    for b in 0..nb_f {
        let wd_comb = (0..nb_d).fold(Fp2::ZERO, |a, c| a.add(lam_d[c].mul(proof.d_term[nb_f + b * nb_d + c])));
        want = want.add(proof.d_term[b].mul(wd_comb));
    }
    if want != fin { return Err("d matmul sumcheck terminal check fails".into()); }
    tr.absorb_fp2(b"d-term", &proof.d_term);
    let mut p5 = r_ip.clone();
    p5.extend_from_slice(&r_k);
    let mut p6 = r_k.clone();
    p6.extend_from_slice(&r_jp);

    // ---- zero-check F ----
    let tau = tr.challenge_fp2_vec((lay.log_t + lay.log_fb) as usize);
    let mu = tr.challenge_fp2_vec(4 * nb_f);
    let nu = tr.challenge_fp2_vec(3 * nb_f);
    let mut claimed = Fp2::ZERO;
    for b in 0..nb_f {
        claimed = claimed.add(nu[3 * b].mul(proof.gu_claims[2 * b])).add(nu[3 * b + 1].mul(proof.gu_claims[2 * b + 1])).add(nu[3 * b + 2].mul(proof.d_term[b]));
    }
    let (fin, rho_f) = sumcheck::verify(claimed, 4, (lay.log_t + lay.log_fb) as usize, &proof.zcf_sc, tr)?;
    if proof.zcf_term.len() != 10 * nb_f { return Err("zcF terminal".into()); }
    {
        let v = &proof.zcf_term;
        let mut zc = Fp2::ZERO;
        let mut f1 = Fp2::ZERO;
        let mut f5 = Fp2::ZERO;
        for b in 0..nb_f {
            let o = 10 * b;
            let (g8, rg, a16, u16, ru, h16, rh, hg, hu, hh) = (v[o], v[o + 1], v[o + 2], v[o + 3], v[o + 4], v[o + 5], v[o + 6], v[o + 7], v[o + 8], v[o + 9]);
            let c_had = a16.mul(u16).sub(h16.mul_base(p_h)).sub(rh);
            let c_hg = helper_constraint(hg, g8.add(beta.mul(a16)).add(g_act), rg.add(g_rg), alpha);
            let c_hu = helper_constraint(hu, u16.add(g_i16), ru.add(g_ru), alpha);
            let c_hh = helper_constraint(hh, h16.add(g_i16), rh.add(g_rh), alpha);
            zc = zc.add(mu[4 * b].mul(c_had)).add(mu[4 * b + 1].mul(c_hg)).add(mu[4 * b + 2].mul(c_hu)).add(mu[4 * b + 3].mul(c_hh));
            f1 = f1.add(nu[3 * b].mul(g8.mul_base(p_g).add(rg))).add(nu[3 * b + 1].mul(u16.mul_base(p_u).add(ru)));
            f5 = f5.add(nu[3 * b + 2].mul(h16));
        }
        let want = eq_point(&tau, &rho_f).mul(zc).add(eq_point(&p1, &rho_f).mul(f1)).add(eq_point(&p5, &rho_f).mul(f5));
        if want != fin { return Err("zero-check F terminal check fails".into()); }
    }
    tr.absorb_fp2(b"zcf-term", &proof.zcf_term);

    // ---- zero-check D ----
    let tau2 = tr.challenge_fp2_vec((lay.log_t + lay.log_db) as usize);
    let mu2 = tr.challenge_fp2_vec(nb_d);
    let nu_x = tr.challenge_fp2_vec(nb_d);
    let nu_z = tr.challenge_fp2_vec(nb_d);
    let claimed = (0..nb_d).fold(Fp2::ZERO, |a, c| a.add(nu_x[c].mul(proof.gu_term[c])).add(nu_z[c].mul(proof.d_claims[c])));
    let (fin, rho_d) = sumcheck::verify(claimed, 4, (lay.log_t + lay.log_db) as usize, &proof.zcd_sc, tr)?;
    if proof.zcd_term.len() != 4 * nb_d { return Err("zcD terminal".into()); }
    {
        let v = &proof.zcd_term;
        let mut zc = Fp2::ZERO;
        let mut fx = Fp2::ZERO;
        let mut fz = Fp2::ZERO;
        for c in 0..nb_d {
            let (x, z, rd, h) = (v[c], v[nb_d + c], v[2 * nb_d + c], v[3 * nb_d + c]);
            zc = zc.add(mu2[c].mul(helper_constraint(h, z.add(g_i16), rd.add(g_rd), alpha)));
            fx = fx.add(nu_x[c].mul(x));
            fz = fz.add(nu_z[c].mul(z.mul_base(p_z).add(rd)));
        }
        let want = eq_point(&tau2, &rho_d).mul(zc).add(eq_point(&p2, &rho_d).mul(fx)).add(eq_point(&p4, &rho_d).mul(fz));
        if want != fin { return Err("zero-check D terminal check fails".into()); }
    }
    tr.absorb_fp2(b"zcd-term", &proof.zcd_term);

    // ---- helper sums vs the multiplicity side (the LogUp identity) ----
    if proof.helper_sums.len() != 3 * nb_f + nb_d { return Err("helper sums".into()); }
    tr.absorb_fp2(b"helper-sums", &proof.helper_sums);
    let witness_side = proof.helper_sums.iter().fold(Fp2::ZERO, |a, b| a.add(*b));
    let mut dens: Vec<Fp2> = Vec::new();
    let mut nums: Vec<Fp> = Vec::new();
    for (tag, m) in &proof.mults {
        for (i, &cnt) in m.iter().enumerate() {
            if cnt == 0 { continue; }
            let tval = if *tag == TAG_ACT16 {
                Fp2::from_i64(i as i64 - 128).add(beta.mul_base(Fp::from_i64(st.table[i] as i64))).add(g_act)
            } else if *tag == TAG_INT16 {
                Fp2::from_i64(i as i64 - 32768).add(g_i16)
            } else {
                let sh = *tag as i32 - 64 - 8;
                Fp2::from_i64(rem_value(sh, i)).add(gamma.mul_base(Fp::new(*tag)))
            };
            dens.push(alpha.sub(tval));
            nums.push(Fp::new(cnt as u64));
        }
    }
    batch_inverse2(&mut dens);
    let table_side = dens.iter().zip(nums.iter()).fold(Fp2::ZERO, |a, (d, n)| a.add(d.mul_base(*n)));
    if witness_side != table_side { return Err("LogUp identity fails (a lookup is not in its table)".into()); }

    // ---- PCS openings ----
    let (w_claims, a_claims, h_claims) = build_claims_v3(&lay, proof, &p3, &p6, &rho_f, &rho_d);
    // [UPERF3-AF] the selected PCS must match the proof's form
    if let Some(b) = &proof.cpcs_open {
        if !pcs_compact::selected() { return Err("cpcs: the proof carries a compact opening but --pcs compact is not selected".into()); }
        pcs_compact::verify_batch(&[(&w_pcs, w_com, &w_claims), (&a_pcs, a_com, &a_claims), (&h_pcs, h_com, &h_claims)], b, tr).map_err(|e| format!("cpcs: {e}"))?;
        return Ok(());
    } else if pcs_compact::selected() {
        return Err("cpcs: --pcs compact is selected but the proof carries the Ligero openings".into());
    }
    pcs::verify(&w_pcs, w_com, &w_claims, &proof.w_open, ntt, tr).map_err(|e| format!("W: {e}"))?;
    pcs::verify(&a_pcs, a_com, &a_claims, &proof.a_open, ntt, tr).map_err(|e| format!("A: {e}"))?;
    pcs::verify(&h_pcs, h_com, &h_claims, &proof.h_open, ntt, tr).map_err(|e| format!("H: {e}"))?;
    Ok(())
}

/// Tamper legs applied to a v3 witness before proving (plane indices are
/// row-major over the first t_rows rows).
#[derive(Clone, Copy, Debug)]
pub enum TamperV3 {
    None,
    /// X[idx] += 1
    FlipX(usize),
    /// WgT[idx] += 1
    FlipW(usize),
    /// rg[idx] += 2^sh_g, g8[idx] -= 1 (identity kept; the remainder leaves its window)
    RemainderOutOfRange(usize),
    /// a16[idx] += 1 (a wrong int16 table entry) with the downstream chain recomputed consistently
    WrongTableEntry(usize),
    /// h16[idx] += 1 with rh unchanged (the Hadamard requant identity breaks)
    WrongRequant(usize),
    /// z16[idx] += 1 (the d matmul identity breaks)
    WrongZ(usize),
    /// FLOOR instead of round at the first gate element at/after idx where they differ, carried
    /// through the chain consistently: only the rounding rule (the remainder window) breaks
    WrongRounding(usize),
    /// z16[idx] += 65536 with rd compensated (identity kept; z16 leaves the int16 class)
    OutOfRangeInt16(usize),
}

/// Recompute h16/rh at one element and the down row that consumes it.
fn recompute_v3_from_a16(w: &mut V3Witness, i: usize) {
    let f = w.dims.f;
    let d = w.dims.d;
    let sh_h = w.shifts.2;
    let sh_z = w.shifts.3;
    let hh = w.a16[i] as i64 * w.u16v[i] as i64;
    let (h, rh) = crate::export_v3::requant_round(&[hh], sh_h);
    w.h16[i] = h[0] as i32;
    w.rh[i] = rh[0] as i32;
    let row = i / f;
    let dacc = crate::export_v3::matmul_i32_i8_i64(&w.h16[row * f..(row + 1) * f], &w.wd_t, 1, f, d);
    let (z, rd) = crate::export_v3::requant_round(&dacc, sh_z);
    for n in 0..d {
        w.z16[row * d + n] = z[n] as i32;
        w.rd[row * d + n] = rd[n] as i32;
    }
}

pub fn apply_tamper_v3(w: &mut V3Witness, t: TamperV3) {
    match t {
        TamperV3::None => {}
        TamperV3::FlipX(i) => { w.x[i] = w.x[i].wrapping_add(1); }
        TamperV3::FlipW(i) => { w.wg_t[i] = w.wg_t[i].wrapping_add(1); }
        TamperV3::RemainderOutOfRange(i) => { w.rg[i] += 1 << w.shifts.0; w.g8[i] -= 1; }
        TamperV3::WrongTableEntry(i) => { w.a16[i] += 1; recompute_v3_from_a16(w, i); }
        TamperV3::WrongRequant(i) => { w.h16[i] += 1; }
        TamperV3::WrongZ(i) => { w.z16[i] += 1; }
        TamperV3::WrongRounding(i) => {
            let n = w.t_rows * w.dims.f;
            let mut j = i % n;
            let mut found = false;
            for _ in 0..n {
                if w.rg[j] < 0 { found = true; break; }
                j = (j + 1) % n;
            }
            assert!(found, "no gate element rounds up — cannot build the wrong-rounding leg");
            w.g8[j] -= 1;
            w.rg[j] += 1 << w.shifts.0;
            w.a16[j] = w.table[((w.g8[j] + 128).clamp(0, 255)) as usize] as i32;
            recompute_v3_from_a16(w, j);
        }
        TamperV3::OutOfRangeInt16(i) => { w.z16[i] += 65536; w.rd[i] -= 65536i32 << w.shifts.3; }
    }
}
