//! [UPERF3-AE] The attention half of a transformer layer in the hash-line
//! statement: the exact integer chain (rung 3) and, after it, the prover
//! and verifier of one FULL layer (rung 4: attention + norms + residual
//! stream + the v3 FFN + the seam to the next layer's input).
//!
//! THE STATEMENT (one layer; shapes (T, d, H, H_kv, d_h, f); the design
//! of record docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_DESIGN.md and
//! ATTENTION_INTEGER_SPEC.md sections 2.1-2.7, instantiated on the
//! hash line's primitives — the full per-tensor table is the ledger's
//! Agent AE rung-0 record):
//!
//!   x_in  (T x d, int16 at e_r; layer 0: the int8 embedding rows at eX0)
//!   attn_norm (norm.rs) ............................. xn8 (int8, e_xn)
//!   Qacc = xn8 . Wq^T, Kacc, Vacc (matmul sumchecks, inner d)
//!   q8/k8/v8 = round-requant (balanced windows), int8 at e_q/e_k/e_v
//!   RoPE (public rope-cs tables at fRo 7, the rotate-half rows):
//!     QRacc = c q_lo - s q_hi | s q_lo + c q_hi ; qr8 = round-requant by 2^7
//!     (scale-preserving; the same on k) — a zero-check reading q8 at the
//!     coordinate-flipped point (PW-1)
//!   Sacc(h, t, j) = sum_i qr8(t, h, i) kr8(j, g(h), i)   (per-head matmul
//!     sumcheck over (h, i); the GQA map g(h) = h / (H / H_kv) is the
//!     kv-head index = the high bits of h: public structure, PW-2)
//!   s8 = round-requant(Sacc, sh_s), int8 at eS_raw = e_q + e_k + sh_s
//!   softmax per (h, t): sM = s8 on the causal support, -127 off it (the
//!     public mask, PW-3); m = row max (committed, H x T); d = m - sM;
//!     zsel binary with row sum 1 and zsel . d = 0 (attainment);
//!     (d, E) in the exp member (eS_raw, d_h, fE) (dominance + the table);
//!     Sum = masked row sum of E (a sumcheck); P Sum + rho = 2^fP E on the
//!     support, P = rho = 0 off it; P in [0, 2^fP]; rho, sigma = Sum - 1 - rho
//!     in [0, 2^wrho), wrho = fE + log2 T
//!   Oacc(t, h, i) = sum_j P(h, t, j) v8(j, g(h), i)  (matmul sumcheck over (h, j))
//!   o8 = round-requant(Oacc, sh_o) int8 at e_o (sh_o = e_o - (e_v - fP))
//!   AOacc = o8 . Wo^T (inner H d_h); ao8 = round-requant, int8 at e_ao
//!   xres1 = round-requant(x_in 2^(e_r - e_c) + ao8 2^(e_ao - e_c), sh_r1), int16 at e_r1
//!   mlp_norm (norm.rs) on xres1 ...................... xm8 (int8, e_xm) = the FFN's X
//!   the v3 FFN (layer.rs, ZB): g8/rg/a16/u16/ru/h16/rh/z16/rd from xm8
//!   xres2 = round-requant(xres1 2^(e_r1 - e_c') + z16 2^(e_z16 - e_c'), sh_r2), int16 at e_r2
//!   THE SEAM: xres2 of layer l IS x_in of layer l + 1 — one MLE equality
//!     at a point drawn after BOTH commitments (layer l's A opening is
//!     deferred until layer l + 1's input is committed).
//!
//! Deferred and stated: the KV cache / decode regime (prefill only), the
//! embedding (X0 committed, its gather not proven), the final norm and
//! the LM head, sliding windows (T <= window: plain causal).
//!
//! Rung 0 (2026-09-03): this module doc + the shape record. Rung 3 fills
//! the chain, rung 4 the prover/verifier.

/// The public shape of one attention layer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AttnShape {
    pub t: usize,
    pub d: usize,
    pub heads: usize,
    pub kv_heads: usize,
    pub head_dim: usize,
    pub f: usize,
}

impl AttnShape {
    pub fn m125() -> AttnShape {
        AttnShape { t: 512, d: 768, heads: 12, kv_heads: 4, head_dim: 64, f: 2048 }
    }
    pub fn mistral7b() -> AttnShape {
        AttnShape { t: 512, d: 4096, heads: 32, kv_heads: 8, head_dim: 128, f: 14336 }
    }
    pub fn gqa_group(&self) -> usize {
        assert_eq!(self.heads % self.kv_heads, 0);
        self.heads / self.kv_heads
    }
    /// The kv head of query head h (the high bits of h).
    pub fn kv_of(&self, h: usize) -> usize {
        h / self.gqa_group()
    }
}

// ==========================================================================
// [UPERF3-AE] RUNG 3 — THE CHAIN (unproven): the exact integer value chain
// of one attention half-layer, reproducing scripts/attention_hash_ref.py's
// per-tensor sha256 digests byte for byte. The oracle IS the semantics
// (the ledger's rung-2 note); this is the Rust that must agree with it.
// ==========================================================================

use rayon::prelude::*;
use sha2::{Digest, Sha256};
use std::collections::HashMap;

/// The flat "key value" manifest the oracle's --export writes.
pub struct Manifest {
    pub kv: HashMap<String, String>,
    pub entries: Vec<(String, String)>,
    pub chain: String,
}

impl Manifest {
    pub fn load(dir: &str) -> Manifest {
        let txt = std::fs::read_to_string(format!("{dir}/manifest.txt"))
            .unwrap_or_else(|e| panic!("manifest.txt in {dir}: {e}"));
        let mut kv = HashMap::new();
        let mut entries = Vec::new();
        let mut chain = String::new();
        for line in txt.lines() {
            let mut it = line.split_whitespace();
            match (it.next(), it.next(), it.next()) {
                (Some("entry"), Some(n), Some(h)) => entries.push((n.to_string(), h.to_string())),
                (Some("chain"), Some(h), None) => chain = h.to_string(),
                (Some(k), Some(v), None) => {
                    kv.insert(k.to_string(), v.to_string());
                }
                _ => {}
            }
        }
        Manifest { kv, entries, chain }
    }
    pub fn i(&self, k: &str) -> i64 {
        self.kv.get(k).unwrap_or_else(|| panic!("manifest key {k}")).parse().unwrap()
    }
    pub fn u(&self, k: &str) -> usize {
        self.i(k) as usize
    }
    pub fn f(&self, k: &str) -> f64 {
        self.kv.get(k).unwrap_or_else(|| panic!("manifest key {k}")).parse().unwrap()
    }
    pub fn s(&self, k: &str) -> &str {
        self.kv.get(k).map(|s| s.as_str()).unwrap_or("")
    }
}

fn load_i32(dir: &str, name: &str) -> Vec<i64> {
    let b = std::fs::read(format!("{dir}/{name}.i32"))
        .unwrap_or_else(|e| panic!("plane {name}: {e}"));
    assert_eq!(b.len() % 4, 0, "plane {name}: not i32");
    b.chunks_exact(4)
        .map(|c| i32::from_le_bytes([c[0], c[1], c[2], c[3]]) as i64)
        .collect()
}

/// sha256 over the little-endian i64 bytes (the oracle's convention).
fn dig_i64(v: &[i64]) -> String {
    let mut h = Sha256::new();
    let mut buf = Vec::with_capacity(v.len() * 8);
    for &x in v {
        buf.extend_from_slice(&x.to_le_bytes());
    }
    h.update(&buf);
    crate::silu::hex(&h.finalize())
}

/// The v3 requant: round to nearest, balanced remainder (export_v3's rule).
fn requant_round(acc: &[i64], sh: i64) -> (Vec<i64>, Vec<i64>) {
    if sh <= 0 {
        let k = (-sh) as u32;
        return (acc.iter().map(|&a| a << k).collect(), vec![0i64; acc.len()]);
    }
    let half = 1i64 << (sh - 1);
    let y: Vec<i64> = acc.par_iter().map(|&a| (a + half) >> sh).collect();
    let r: Vec<i64> = acc.par_iter().zip(y.par_iter()).map(|(&a, &yy)| a - (yy << sh)).collect();
    (y, r)
}

/// acc[t][o] = sum_i x[t][i] * w[o][i]  (w row-major (out, in) — the
/// checkpoint layout the oracle multiplies as x @ W^T).
fn matmul_wt(x: &[i64], w: &[i64], t_rows: usize, d_in: usize, d_out: usize) -> Vec<i64> {
    let mut acc = vec![0i64; t_rows * d_out];
    acc.par_chunks_mut(d_out).enumerate().for_each(|(t, row)| {
        let xr = &x[t * d_in..(t + 1) * d_in];
        for (o, slot) in row.iter_mut().enumerate() {
            let wr = &w[o * d_in..(o + 1) * d_in];
            let mut s = 0i64;
            for i in 0..d_in {
                s += xr[i] * wr[i];
            }
            *slot = s;
        }
    });
    acc
}

fn limbs(v: &[i64], wrho: u32) -> Vec<Vec<i64>> {
    let n = std::cmp::max(1, wrho.div_ceil(16)) as usize;
    (0..n)
        .map(|i| v.iter().map(|&x| (x >> (16 * i as u32)) & 0xffff).collect())
        .collect()
}

// ==========================================================================
// [UPERF3-AG] THE WITNESS. The chain above is now `build_attn_witness` +
// `witness_digests`: ONE implementation, so the rung-3 digest gate (the
// oracle's 64 tensors) covers the plane the rung-4 prover commits, plane
// for plane. `chain_from_export` is the pair composed.
// ==========================================================================

/// The integer class of a committed activation plane.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cls {
    Int8,
    Int16,
    Int24,
}

impl Cls {
    pub fn limit(self) -> i64 {
        match self {
            Cls::Int8 => 127,
            Cls::Int16 => 32767,
            Cls::Int24 => 8388607,
        }
    }
    pub fn of_limit(l: i64) -> Cls {
        match l {
            127 => Cls::Int8,
            32767 => Cls::Int16,
            8388607 => Cls::Int24,
            _ => panic!("class limit {l}"),
        }
    }
    /// Number of 16-bit limbs the class is proven with (int24 only).
    pub fn limbs(self) -> usize {
        match self {
            Cls::Int24 => 2,
            _ => 1,
        }
    }
}

/// The public constants of one norm site.
#[derive(Clone, Copy, Debug)]
pub struct NormConsts {
    pub tn: u32,
    pub cn: i64,
    pub ceps: i64,
    pub wrho: u32,
    pub n_limbs: usize,
}

/// The public constants of one attention layer's statement (everything the
/// verifier absorbs; the exponents are documentation, the shifts and
/// classes are load-bearing).
#[derive(Clone, Debug)]
pub struct AttnConsts {
    pub shape: AttnShape,
    pub layer: usize,
    pub f_e: u32,
    pub f_p: u32,
    pub f_ro: u32,
    pub rope_base: f64,
    pub norm_round: bool,
    pub x_cls: Cls,
    pub e_r: i32,
    pub e_xn: i32,
    pub e_r1: i32,
    pub e_ao: i32,
    pub e_xm: i32,
    pub sh_q: i32,
    pub sh_k: i32,
    pub sh_v: i32,
    pub sh_qr: i32,
    pub sh_kr: i32,
    pub sh_s: i32,
    pub e_s_raw: i32,
    pub sh_o: i32,
    pub sh_ao: i32,
    pub ao_cls: Cls,
    /// xres1 = requant(x_in << sh_x1 + ao << sh_a1, sh_r1)
    pub sh_x1: u32,
    pub sh_a1: u32,
    pub sh_r1: i32,
    pub r1_cls: Cls,
    pub anorm: NormConsts,
    pub mnorm: NormConsts,
    pub exp_digest: String,
    pub rope_digest: String,
    /// the softmax remainder width (fE + log2 T)
    pub wrho_s: u32,
}

/// Every plane of one attention half-layer's chain.
pub struct AttnWitness {
    pub c: AttnConsts,
    pub x_in: Vec<i64>,
    pub wq: Vec<i64>,
    pub wk: Vec<i64>,
    pub wv: Vec<i64>,
    pub wo: Vec<i64>,
    pub g_a: Vec<i64>,
    pub g_m: Vec<i64>,
    pub na: crate::norm::NormChain,
    pub nm: crate::norm::NormChain,
    pub qacc: Vec<i64>,
    pub q8: Vec<i64>,
    pub rq: Vec<i64>,
    pub kacc: Vec<i64>,
    pub k8: Vec<i64>,
    pub rk: Vec<i64>,
    pub vacc: Vec<i64>,
    pub v8: Vec<i64>,
    pub rv: Vec<i64>,
    pub qracc: Vec<i64>,
    pub qr8: Vec<i64>,
    pub rqr: Vec<i64>,
    pub kracc: Vec<i64>,
    pub kr8: Vec<i64>,
    pub rkr: Vec<i64>,
    /// head-major (h, t, j)
    pub sacc: Vec<i64>,
    pub s8: Vec<i64>,
    pub rs: Vec<i64>,
    pub dmat: Vec<i64>,
    pub zsel: Vec<i64>,
    pub e_t: Vec<i64>,
    pub p: Vec<i64>,
    pub rho_s: Vec<i64>,
    pub sig_s: Vec<i64>,
    /// (h, t)
    pub m_row: Vec<i64>,
    pub sum: Vec<i64>,
    /// head-major (h, t, i)
    pub oacc: Vec<i64>,
    /// (t, h * d_h)
    pub o8: Vec<i64>,
    pub r_o: Vec<i64>,
    pub aoacc: Vec<i64>,
    pub ao8: Vec<i64>,
    pub r_ao: Vec<i64>,
    pub xw1: Vec<i64>,
    pub xres1: Vec<i64>,
    pub rr1: Vec<i64>,
    pub exp_tab: [i64; 256],
    pub ctab: Vec<i64>,
    pub stab: Vec<i64>,
}

/// The layer index an export directory names.
pub fn layer_of(dir: &str) -> usize {
    Manifest::load(dir).u("layer")
}

/// Run the chain from an export directory, keeping every plane.
pub fn build_attn_witness(dir: &str) -> AttnWitness {
    build_attn_witness_t(dir, None)
}

/// The chain over the FIRST `t_rows` tokens (the statement is causal, so a
/// row prefix of the export IS the chain of that prefix; the digest gate
/// applies at the export's own T).
pub fn build_attn_witness_t(dir: &str, t_rows: Option<usize>) -> AttnWitness {
    build_attn_witness_full(dir, t_rows, None, None)
}

/// [UPERF3-AG] The layer's input when it comes from the PREVIOUS layer's
/// proven output (the multi-layer seam) rather than from the export.
pub struct SeamIn {
    pub x: Vec<i64>,
    pub e_r: i32,
    pub cls: Cls,
}

/// Requant at the declared shift, RAISING it while the narrowing would
/// saturate (the shift is a public statement constant; the oracle's
/// `fit_requant`). Returns (y, r, shift).
fn fit_requant(acc: &[i64], sh0: i64, lim: i64) -> (Vec<i64>, Vec<i64>, i64) {
    let mut sh = sh0;
    loop {
        let (y, r) = requant_round(acc, sh);
        if y.iter().all(|&v| v.abs() <= lim) {
            return (y, r, sh);
        }
        sh += 1;
        assert!(sh - sh0 < 24, "runaway requant fit");
    }
}

fn bits_u(v: i64) -> u32 {
    if v <= 0 { 0 } else { 64 - (v as u64).leading_zeros() }
}

/// One norm site, with the output exponent SEARCHED the way the oracle
/// searches it (the window rule fixes (tn, Cn) from e_y; e_y rises until
/// the int8 narrowing holds).
fn fit_norm(x: &[i64], gv: &[i64], d: usize, eps: f64, e_x: i32, e_g: i32, e_y_hint: i32,
            mode: crate::norm::DivMode) -> (crate::norm::NormChain, NormConsts, i32) {
    let ceps = crate::norm::ceps_of(eps, d, e_x);
    for k in 0..48 {
        let e_y = e_y_hint + k;
        let (tn, cn) = crate::norm::window_rule(e_g, e_y, d);
        let t_rows = x.len() / d;
        // a cheap pre-check on the first rows, then the full chain
        let ok = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            crate::norm::rmsnorm_chain(x, gv, d, ceps, tn, cn, mode)
        }));
        if let Ok(ch) = ok {
            let dvp: i64 = (0..t_rows).map(|r| (ch.dd[r] << tn) * if mode == crate::norm::DivMode::Round { 2 } else { 1 }).max().unwrap_or(1);
            let wrho = bits_u(dvp - 1);
            let n_limbs = std::cmp::max(1, wrho.div_ceil(16)) as usize;
            return (ch, NormConsts { tn, cn, ceps, wrho, n_limbs }, e_y);
        }
    }
    panic!("norm: no admissible e_y");
}

/// A one-line summary of the fitted statement constants.
pub fn consts_line(c: &AttnConsts) -> String {
    format!("shifts q/k/v {}/{}/{} qr/kr {}/{} s {} o {} ao {} r1 {} | exps xn {} q {} k {} v {} s_raw {} xm {} ao {} r1 {} | anorm(tn {} cn {} ceps {} wrho {}) mnorm(tn {} cn {} ceps {} wrho {})",
        c.sh_q, c.sh_k, c.sh_v, c.sh_qr, c.sh_kr, c.sh_s, c.sh_o, c.sh_ao, c.sh_r1,
        c.e_xn, c.e_xn + c.sh_q, 0, 0, c.e_s_raw, c.e_xm, c.e_ao, c.e_r1,
        c.anorm.tn, c.anorm.cn, c.anorm.ceps, c.anorm.wrho,
        c.mnorm.tn, c.mnorm.cn, c.mnorm.ceps, c.mnorm.wrho)
}

pub fn build_attn_witness_full(dir: &str, t_rows: Option<usize>, seam: Option<SeamIn>,
                               e_xm_target: Option<i32>) -> AttnWitness {
    let m = Manifest::load(dir);
    let (t, d) = (t_rows.unwrap_or(m.u("T")), m.u("d"));
    assert!(t <= m.u("T") && t.is_power_of_two(), "t_rows {t}");
    let (h_q, h_kv, hd) = (m.u("heads"), m.u("kv_heads"), m.u("head_dim"));
    let rep = h_q / h_kv;
    let f_e = m.i("fE") as u32;
    let f_p = m.i("fP") as u32;
    let f_ro = m.i("fRo") as u32;
    let round = m.s("norm_div") == "round";
    let wq = load_i32(dir, "wq");
    let wk = load_i32(dir, "wk");
    let wv = load_i32(dir, "wv");
    let wo = load_i32(dir, "wo");
    let g_a = load_i32(dir, "gA");
    let g_m = load_i32(dir, "gM");
    let (x_in, e_r, x_cls) = match seam {
        Some(sm) => {
            assert_eq!(sm.x.len(), t * d, "seam input size");
            (sm.x, sm.e_r, sm.cls)
        }
        None => {
            let mut x = load_i32(dir, "x_in");
            x.truncate(t * d);
            let cls = if m.u("layer") == 0 { Cls::Int8 } else { Cls::of_limit(m.i("r1_lim")) };
            (x, m.i("e_r") as i32, cls)
        }
    };
    let eps = m.f("eps");
    let dmode = if round { crate::norm::DivMode::Round } else { crate::norm::DivMode::Floor };

    // --- attn_norm (the site's constants derived from THIS input's exponent) ---
    let (na, anorm, e_xn) = fit_norm(&x_in, &g_a, d, eps, e_r, m.i("e_gA") as i32,
                                     m.i("e_xn") as i32, dmode);

    // --- QKV (each shift fitted to the record's target exponent) ---------
    let mm = |w: &[i64], d_out: usize, e_w: i32, e_y: i32, lim: i64|
        -> (Vec<i64>, Vec<i64>, Vec<i64>, i32, i32) {
        let acc = matmul_wt(&na.y, w, t, d, d_out);
        let (y, r, sh) = fit_requant(&acc, (e_y - e_xn - e_w) as i64, lim);
        (acc, y, r, sh as i32, e_xn + e_w + sh as i32)
    };
    let (qacc, q8, rq, sh_q, e_q) = mm(&wq, h_q * hd, m.i("e_wq") as i32, m.i("e_q") as i32, 127);
    let (kacc, k8, rk, sh_k, e_k) = mm(&wk, h_kv * hd, m.i("e_wk") as i32, m.i("e_k") as i32, 127);
    let (vacc, v8, rv, sh_v, e_v) = mm(&wv, h_kv * hd, m.i("e_wv") as i32, m.i("e_v") as i32, 127);

    // --- RoPE ------------------------------------------------------------
    let (ctab, stab) = crate::tables_attn::rope_tables_generate(t, hd, m.f("rope_base"), f_ro);
    let rope_dig = crate::tables_attn::rope_digest(t, hd, m.f("rope_base"), f_ro, &ctab, &stab);
    // the rope member is keyed by t_max: at the export's own T it must be the
    // oracle's; on a truncated prefix it is that prefix's member.
    if t == m.u("T") {
        assert_eq!(rope_dig, m.s("rope_digest"), "rope table digest");
    }
    let half = hd / 2;
    let rope = |src: &[i64], heads: usize, sh0: i64| -> (Vec<i64>, Vec<i64>, Vec<i64>, i32) {
        let width = heads * hd;
        let mut acc = vec![0i64; t * width];
        acc.par_chunks_mut(width).enumerate().for_each(|(ti, row)| {
            for h in 0..heads {
                for i in 0..half {
                    let c = ctab[ti * half + i];
                    let s = stab[ti * half + i];
                    let lo = src[ti * width + h * hd + i];
                    let hi = src[ti * width + h * hd + half + i];
                    row[h * hd + i] = c * lo - s * hi;
                    row[h * hd + half + i] = s * lo + c * hi;
                }
            }
        });
        let (y, r, sh) = fit_requant(&acc, sh0, 127);
        (acc, y, r, sh as i32)
    };
    let (qracc, qr8, rqr, sh_qr) = rope(&q8, h_q, (f_ro as i32 + (m.i("e_qr") as i32 - e_q)) as i64);
    let e_qr = e_q - f_ro as i32 + sh_qr;
    let (kracc, kr8, rkr, sh_kr) = rope(&k8, h_kv, (f_ro as i32 + (m.i("e_kr") as i32 - e_k)) as i64);
    let e_kr = e_k - f_ro as i32 + sh_kr;

    // --- the scores (one shift over all heads, fitted) -------------------
    let qw = h_q * hd;
    let kw = h_kv * hd;
    let ht = h_q * t;
    let htt = h_q * t * t;
    let mut sacc = vec![0i64; htt];
    for h in 0..h_q {
        let g = h / rep;
        let sa = &mut sacc[h * t * t..(h + 1) * t * t];
        sa.par_chunks_mut(t).enumerate().for_each(|(ti, row)| {
            let qrow = &qr8[ti * qw + h * hd..ti * qw + h * hd + hd];
            for (j, slot) in row.iter_mut().enumerate() {
                let krow = &kr8[j * kw + g * hd..j * kw + g * hd + hd];
                let mut acc = 0i64;
                for i in 0..hd {
                    acc += qrow[i] * krow[i];
                }
                *slot = acc;
            }
        });
    }
    let (s8, rs, sh_s) = fit_requant(&sacc, (m.i("e_s_raw") as i32 - e_qr - e_kr) as i64, 127);
    let sh_s = sh_s as i32;
    let e_s_raw = e_qr + e_kr + sh_s;

    // --- the softmax and PV (per head) -----------------------------------
    let (exp_tab, exp_dig) = crate::tables_attn::exp_member(e_s_raw, hd, f_e);
    let mut dmat = vec![0i64; htt];
    let mut zsel = vec![0i64; htt];
    let mut e_t = vec![0i64; htt];
    let mut p = vec![0i64; htt];
    let mut rho_s = vec![0i64; htt];
    let mut sig_s = vec![0i64; htt];
    let mut m_row = vec![0i64; ht];
    let mut sum = vec![0i64; ht];
    let mut oacc = vec![0i64; h_q * t * hd];
    for h in 0..h_q {
        let g = h / rep;
        let base = h * t * t;
        for ti in 0..t {
            let mut best = i64::MIN;
            let mut arg = 0usize;
            for j in 0..t {
                let sm = if j <= ti { s8[base + ti * t + j] } else { -127 };
                if sm > best {
                    best = sm;
                    arg = j;
                }
            }
            m_row[h * t + ti] = best;
            zsel[base + ti * t + arg] = 1;
            let mut acc = 0i64;
            for j in 0..t {
                let sm = if j <= ti { s8[base + ti * t + j] } else { -127 };
                let dv = best - sm;
                assert!((0..256).contains(&dv), "dominance {dv}");
                dmat[base + ti * t + j] = dv;
                let e = exp_tab[dv as usize];
                e_t[base + ti * t + j] = e;
                if j <= ti {
                    acc += e;
                }
            }
            assert!(acc >= 1i64 << f_e, "attainment");
            sum[h * t + ti] = acc;
            for j in 0..=ti {
                let num = e_t[base + ti * t + j] << f_p;
                let q = num.div_euclid(acc);
                p[base + ti * t + j] = q;
                rho_s[base + ti * t + j] = num - q * acc;
            }
        }
        for ti in 0..t {
            for j in 0..=ti {
                sig_s[base + ti * t + j] = sum[h * t + ti] - 1 - rho_s[base + ti * t + j];
            }
        }
        let oa = &mut oacc[h * t * hd..(h + 1) * t * hd];
        oa.par_chunks_mut(hd).enumerate().for_each(|(ti, row)| {
            for j in 0..=ti {
                let pv = p[base + ti * t + j];
                if pv == 0 {
                    continue;
                }
                let vrow = &v8[j * kw + g * hd..j * kw + g * hd + hd];
                for i in 0..hd {
                    row[i] += pv * vrow[i];
                }
            }
        });
    }
    // o8: one shift over all heads (the accumulators are head-major)
    let (oy, orr, sh_o) = fit_requant(&oacc, (m.i("e_o") as i32 - (e_v - f_p as i32)) as i64, 127);
    let sh_o = sh_o as i32;
    let e_o = e_v - f_p as i32 + sh_o;
    let mut o8 = vec![0i64; t * qw];
    let mut r_o = vec![0i64; t * qw];
    for h in 0..h_q {
        for ti in 0..t {
            for i in 0..hd {
                o8[ti * qw + h * hd + i] = oy[(h * t + ti) * hd + i];
                r_o[ti * qw + h * hd + i] = orr[(h * t + ti) * hd + i];
            }
        }
    }

    // --- Wo + ao ----------------------------------------------------------
    let aoacc = matmul_wt(&o8, &wo, t, qw, d);
    let ao_lim = m.i("ao_lim");
    let (ao8, r_ao, sh_ao) = fit_requant(&aoacc, (m.i("e_ao") as i32 - e_o - m.i("e_wo") as i32) as i64, ao_lim);
    let sh_ao = sh_ao as i32;
    let e_ao = e_o + m.i("e_wo") as i32 + sh_ao;

    // --- residual add 1 ----------------------------------------------------
    let e_c1 = std::cmp::min(e_r, e_ao);
    let (sh_x, sh_a) = ((e_r - e_c1) as u32, (e_ao - e_c1) as u32);
    let xw1: Vec<i64> = x_in
        .par_iter()
        .zip(ao8.par_iter())
        .map(|(&x, &a)| (x << sh_x) + (a << sh_a))
        .collect();
    let r1_lim = m.i("r1_lim");
    let (xres1, rr1, sh_r1) = fit_requant(&xw1, (m.i("e_r1") as i32 - e_c1) as i64, r1_lim);
    let sh_r1 = sh_r1 as i32;
    let e_r1 = e_c1 + sh_r1;

    // --- mlp_norm (the FFN's X plane) --------------------------------------
    // the mlp norm's OUTPUT exponent is the FFN half's X exponent when the
    // caller supplies it (the two halves must meet on one grid); otherwise
    // the attention record's own hint.
    let (nm, mnorm, e_xm) = fit_norm(&xres1, &g_m, d, eps, e_r1, m.i("e_gM") as i32,
                                     e_xm_target.unwrap_or(m.i("e_xm") as i32), dmode);

    let c = AttnConsts {
        shape: AttnShape { t, d, heads: h_q, kv_heads: h_kv, head_dim: hd, f: 0 },
        layer: m.u("layer"),
        f_e, f_p, f_ro,
        rope_base: m.f("rope_base"),
        norm_round: round,
        x_cls,
        e_r,
        e_xn,
        e_r1,
        e_ao,
        e_xm,
        sh_q, sh_k, sh_v, sh_qr, sh_kr, sh_s,
        e_s_raw,
        sh_o,
        sh_ao,
        ao_cls: Cls::of_limit(ao_lim),
        sh_x1: sh_x,
        sh_a1: sh_a,
        sh_r1,
        r1_cls: Cls::of_limit(r1_lim),
        anorm,
        mnorm,
        exp_digest: exp_dig,
        rope_digest: rope_dig,
        wrho_s: f_e + t.trailing_zeros(),
    };
    AttnWitness {
        c, x_in, wq, wk, wv, wo, g_a, g_m, na, nm,
        qacc, q8, rq, kacc, k8, rk, vacc, v8, rv,
        qracc, qr8, rqr, kracc, kr8, rkr,
        sacc, s8, rs, dmat, zsel, e_t, p, rho_s, sig_s, m_row, sum,
        oacc, o8, r_o, aoacc, ao8, r_ao, xw1, xres1, rr1,
        exp_tab, ctab, stab,
    }
}

/// The ordered (name, digest) list of the oracle's 64 tensors + the CHAIN
/// digest, computed from the witness.
pub fn witness_digests(w: &AttnWitness) -> (Vec<(String, String)>, String) {
    let mut out: Vec<(String, String)> = Vec::new();
    let na = &w.na;
    out.push(("xsqA".to_string(), dig_i64(&na.xsq)));
    out.push(("SSA".to_string(), dig_i64(&na.sse)));
    out.push(("DA".to_string(), dig_i64(&na.dd)));
    out.push(("DsqA".to_string(), dig_i64(&na.dsq)));
    out.push(("a1A".to_string(), dig_i64(&na.a1)));
    out.push(("a2A".to_string(), dig_i64(&na.a2)));
    out.push(("xn8".to_string(), dig_i64(&na.y)));
    for (i, l) in limbs(&na.rho, w.c.anorm.wrho).iter().enumerate() {
        out.push((format!("rhoA_l{i}"), dig_i64(l)));
    }
    for (i, l) in limbs(&na.sig, w.c.anorm.wrho).iter().enumerate() {
        out.push((format!("sigA_l{i}"), dig_i64(l)));
    }
    for (nm_, acc, y, r) in [("Q", &w.qacc, &w.q8, &w.rq), ("K", &w.kacc, &w.k8, &w.rk),
                             ("V", &w.vacc, &w.v8, &w.rv)] {
        out.push((format!("{nm_}acc"), dig_i64(acc)));
        out.push((nm_.to_lowercase() + "8", dig_i64(y)));
        out.push((format!("r{nm_}"), dig_i64(r)));
    }
    out.push(("QRacc".to_string(), dig_i64(&w.qracc)));
    out.push(("qr8".to_string(), dig_i64(&w.qr8)));
    out.push(("rQR".to_string(), dig_i64(&w.rqr)));
    out.push(("KRacc".to_string(), dig_i64(&w.kracc)));
    out.push(("kr8".to_string(), dig_i64(&w.kr8)));
    out.push(("rKR".to_string(), dig_i64(&w.rkr)));
    for (nm_, v) in [("Sacc", &w.sacc), ("s8", &w.s8), ("rS", &w.rs), ("m", &w.m_row),
                     ("dmat", &w.dmat), ("zsel", &w.zsel), ("E", &w.e_t), ("Sum", &w.sum),
                     ("P", &w.p), ("rho", &w.rho_s), ("sig", &w.sig_s), ("Oacc", &w.oacc)] {
        out.push((nm_.to_string(), dig_i64(v)));
    }
    out.push(("o8".to_string(), dig_i64(&w.o8)));
    out.push(("rO".to_string(), dig_i64(&w.r_o)));
    out.push(("AOacc".to_string(), dig_i64(&w.aoacc)));
    out.push(("ao8".to_string(), dig_i64(&w.ao8)));
    out.push(("rAO".to_string(), dig_i64(&w.r_ao)));
    out.push(("xw1".to_string(), dig_i64(&w.xw1)));
    out.push(("xres1".to_string(), dig_i64(&w.xres1)));
    out.push(("rr1".to_string(), dig_i64(&w.rr1)));
    let nm = &w.nm;
    out.push(("xsqM".to_string(), dig_i64(&nm.xsq)));
    out.push(("SSM".to_string(), dig_i64(&nm.sse)));
    out.push(("DM".to_string(), dig_i64(&nm.dd)));
    out.push(("DsqM".to_string(), dig_i64(&nm.dsq)));
    out.push(("a1M".to_string(), dig_i64(&nm.a1)));
    out.push(("a2M".to_string(), dig_i64(&nm.a2)));
    out.push(("xm8".to_string(), dig_i64(&nm.y)));
    for (i, l) in limbs(&nm.rho, w.c.mnorm.wrho).iter().enumerate() {
        out.push((format!("rhoM_l{i}"), dig_i64(l)));
    }
    for (i, l) in limbs(&nm.sig, w.c.mnorm.wrho).iter().enumerate() {
        out.push((format!("sigM_l{i}"), dig_i64(l)));
    }
    for (n, v) in [("x_in", &w.x_in), ("Wq", &w.wq), ("Wk", &w.wk), ("Wv", &w.wv), ("Wo", &w.wo),
                   ("gA", &w.g_a), ("gM", &w.g_m)] {
        out.push((n.to_string(), dig_i64(v)));
    }
    let mut comb = Sha256::new();
    for (_, dg) in out.iter() {
        let mut b = [0u8; 32];
        for (i, byte) in b.iter_mut().enumerate() {
            *byte = u8::from_str_radix(&dg[2 * i..2 * i + 2], 16).unwrap();
        }
        comb.update(b);
    }
    let chain = crate::silu::hex(&comb.finalize());
    (out, chain)
}

/// Run the whole chain from an export directory; returns the ordered
/// (name, digest) list and the CHAIN digest.
pub fn chain_from_export(dir: &str) -> (Vec<(String, String)>, String) {
    witness_digests(&build_attn_witness(dir))
}

/// The rung-3 gate: run the chain and diff every digest against the
/// oracle's manifest. Returns (matched, total).
pub fn verify_export(dir: &str, verbose: bool) -> (usize, usize) {
    let m = Manifest::load(dir);
    let (got, chain) = chain_from_export(dir);
    let want: HashMap<&str, &str> =
        m.entries.iter().map(|(n, h)| (n.as_str(), h.as_str())).collect();
    let mut ok = 0usize;
    assert_eq!(got.len(), m.entries.len(), "entry count: got {} want {}", got.len(),
               m.entries.len());
    for (i, (n, h)) in got.iter().enumerate() {
        let w = want.get(n.as_str()).copied().unwrap_or("(missing)");
        let good = w == h;
        ok += good as usize;
        assert_eq!(&m.entries[i].0, n, "entry ORDER differs at {i}");
        if verbose || !good {
            let tag = if good { "OK".to_string() } else { format!("MISMATCH want {w}") };
            println!("  {n:<9} {h} {tag}");
        }
    }
    println!("  CHAIN {} {}", chain, if chain == m.chain { "OK" } else { "MISMATCH" });
    assert_eq!(chain, m.chain, "CHAIN digest differs from the oracle");
    (ok, got.len())
}


// ==========================================================================
// [UPERF3-AG] RUNG 4 — THE FULL-LAYER PROOF: the layout.
//
// Every committed plane is padded up to a power of two on each axis so that
// one plane is ONE Ligero slice (no block structure, unlike the v3 FFN's
// nb_d / nb_f): d -> dp, the query heads H -> hp with the GQA slots
// re-indexed h' = (h / rep) * rep_p + h % rep so that the kv head g(h') is
// the HIGH bits of h' (the map is then free in every sumcheck). The padding
// is INERT, not zero-filled by fiat: the pad columns/heads carry the values
// the chain itself produces on zero inputs (a zero gamma column, a zero
// query head), so every constraint holds on them unchanged.
//
// Index conventions (row-major, MSB first):
//   D  domain (t, i)      T x dp    x_in, xn8, rho/sig limbs, ao, xres1/2, xm8, z16c
//   Q  domain (t, h', i)  T x qp    q8, rQ, qr8, rQR, o8, rO
//   KV domain (t, g, i)   T x vp    k8, rK, v8, rV, kr8, rKR
//   S  domain (h', t, j)  hp x T x T  s8, rS, zsel, E, P, rho
//   SM packed small       m, Sum (hp x T), then D, Dsq, a1, a2 per norm site (T)
//   LM packed limbs       a1/a2 16-bit limb pairs per norm site (T each)
// ==========================================================================

use crate::field::{batch_inverse2, Fp, Fp2};
use crate::layer::LayerParams;
use crate::mle::{eq_point, eq_table_msb, eval_mle_ext};
use crate::ntt::NttTables;
use crate::pcs::{self, Claim, Commitment, Opening, PcsParams, Slice};
use crate::sumcheck::{self, SumcheckProof};
use crate::transcript::Transcript;

/// The padded shape of one attention layer.
#[derive(Clone, Copy, Debug)]
pub struct PadShape {
    pub t: usize,
    pub d: usize,
    pub dp: usize,
    pub heads: usize,
    pub hp: usize,
    pub kv: usize,
    pub kp: usize,
    pub hd: usize,
    pub qp: usize,
    pub vp: usize,
    pub rep: usize,
    pub rep_p: usize,
}

impl PadShape {
    pub fn new(s: &AttnShape) -> PadShape {
        let dp = s.d.next_power_of_two();
        let hp = s.heads.next_power_of_two();
        let kp = s.kv_heads.next_power_of_two();
        assert_eq!(kp, s.kv_heads, "kv heads must be a power of two");
        assert!(s.head_dim.is_power_of_two() && s.t.is_power_of_two(), "T and d_h must be powers of two");
        let rep = s.heads / s.kv_heads;
        let rep_p = hp / kp;
        assert!(rep_p >= rep, "GQA: hp/kp {rep_p} < rep {rep}");
        PadShape { t: s.t, d: s.d, dp, heads: s.heads, hp, kv: s.kv_heads, kp, hd: s.head_dim,
                   qp: hp * s.head_dim, vp: kp * s.head_dim, rep, rep_p }
    }
    /// natural query head -> padded head slot
    pub fn hpad(&self, h: usize) -> usize {
        (h / self.rep) * self.rep_p + h % self.rep
    }
    /// padded head slot -> natural query head (None: a pad slot)
    pub fn hnat(&self, hs: usize) -> Option<usize> {
        let (g, l) = (hs / self.rep_p, hs % self.rep_p);
        if l < self.rep { Some(g * self.rep + l) } else { None }
    }
}

/// The LogUp tables of the attention statement.
#[derive(Clone, Copy, PartialEq, Eq, Debug, PartialOrd, Ord)]
pub enum Tbl {
    Int8,
    Int16,
    U16,
    U8,
    /// the fused (d, E[d]) exp member
    Exp,
    /// the softmax weight class [0, 2^fP]
    Prob,
    /// the softmax remainder class [0, 2^w)
    Srem(u32),
    /// the balanced round-requant window of a signed shift
    Win(i32),
}

impl Tbl {
    pub fn tag(self) -> u64 {
        match self {
            Tbl::U16 => crate::tables_attn::TAG_U16,
            Tbl::Exp => crate::tables_attn::TAG_EXP,
            Tbl::Prob => crate::tables_attn::TAG_PROB,
            Tbl::Int8 => crate::tables_attn::TAG_INT8A,
            Tbl::Int16 => crate::tables_attn::TAG_INT16A,
            Tbl::U8 => crate::tables_attn::TAG_U8,
            Tbl::Srem(w) => crate::tables_attn::tag_srem_a(w),
            Tbl::Win(sh) => crate::tables_attn::tag_win_a(sh),
        }
    }
    pub fn rows(self, f_p: u32) -> usize {
        match self {
            Tbl::Int8 | Tbl::U8 | Tbl::Exp => 256,
            Tbl::Int16 | Tbl::U16 => 1 << 16,
            Tbl::Prob => (1usize << f_p) + 1,
            Tbl::Srem(w) => 1usize << w,
            Tbl::Win(sh) => crate::layer::rem_rows(sh),
        }
    }
    /// The row index of a value (None: outside the table — only a tampered
    /// witness gets there; the caller counts it into row 0 so the totals
    /// still match and only the LogUp identity catches it).
    pub fn index(self, v: i64, f_p: u32) -> Option<usize> {
        let ok = |c: bool, i: i64| if c { Some(i as usize) } else { None };
        match self {
            Tbl::Int8 => ok((-128..=127).contains(&v), v + 128),
            Tbl::Int16 => ok((-32768..=32767).contains(&v), v + 32768),
            Tbl::U16 => ok((0..1 << 16).contains(&v), v),
            Tbl::U8 => ok((0..256).contains(&v), v),
            Tbl::Exp => ok((0..256).contains(&v), v),
            Tbl::Prob => ok((0..=(1i64 << f_p)).contains(&v), v),
            Tbl::Srem(w) => ok(v >= 0 && v < (1i64 << w), v),
            Tbl::Win(sh) => crate::layer::rem_index(sh, v as i32),
        }
    }
    /// (value, aux) of row i; aux is the fused second component (E[d]).
    pub fn row(self, i: usize, exp: &[i64; 256]) -> (i64, i64) {
        match self {
            Tbl::Int8 => (i as i64 - 128, 0),
            Tbl::Int16 => (i as i64 - 32768, 0),
            Tbl::U16 | Tbl::U8 | Tbl::Prob | Tbl::Srem(_) => (i as i64, 0),
            Tbl::Exp => (i as i64, exp[i]),
            Tbl::Win(sh) => (crate::layer::rem_value(sh, i), 0),
        }
    }
}

/// A committed value in a class: one plane (int8/int16) or two 16-bit limbs
/// (int24: value = l0 + 2^16 l1 - 2^23, l0 in U16, l1 in U8).
#[derive(Clone, Debug)]
pub struct ClsPlane {
    pub offs: Vec<usize>,
    pub cls: Cls,
}

impl ClsPlane {
    pub fn tables(&self) -> Vec<Tbl> {
        match self.cls {
            Cls::Int8 => vec![Tbl::Int8],
            Cls::Int16 => vec![Tbl::Int16],
            Cls::Int24 => vec![Tbl::U16, Tbl::U8],
        }
    }
    /// The limb decomposition of a value in this class.
    pub fn limbs(&self, v: i64) -> Vec<i64> {
        match self.cls {
            Cls::Int24 => {
                let u = v + (1 << 23);
                vec![u & 0xffff, u >> 16]
            }
            _ => vec![v],
        }
    }
    /// value = sum coef_k * limb_k + offset
    pub fn recon(&self) -> (Vec<i64>, i64) {
        match self.cls {
            Cls::Int24 => (vec![1, 1 << 16], -(1 << 23)),
            _ => (vec![1], 0),
        }
    }
}

fn ceil_log2(n: usize) -> u32 {
    let mut l = 0u32;
    while (1usize << l) < n {
        l += 1;
    }
    l
}

struct Alloc {
    off: usize,
}

impl Alloc {
    fn take(&mut self, log: u32) -> usize {
        let sz = 1usize << log;
        let o = self.off.div_ceil(sz) * sz;
        self.off = o + sz;
        o
    }
}

/// Element offsets of every slice of the attention commitments.
#[derive(Clone, Debug)]
pub struct AttnLayout {
    pub p: PadShape,
    pub log_t: u32,
    pub log_dp: u32,
    pub log_hp: u32,
    pub log_qp: u32,
    pub log_vp: u32,
    pub log_hd: u32,
    pub log_kp: u32,
    pub log_rep: u32,
    pub log_d: u32,
    pub log_q: u32,
    pub log_kv: u32,
    pub log_s: u32,
    pub log_sm: u32,
    pub log_lm: u32,
    pub cols_log: u32,
    // ---- A ----
    pub x_in: ClsPlane,
    pub xn8: usize,
    pub rho_a: Vec<usize>,
    pub sig_a: Vec<usize>,
    pub q8: usize,
    pub rq: usize,
    pub qr8: usize,
    pub rqr: usize,
    pub o8: usize,
    pub ro: usize,
    pub k8: usize,
    pub rk: usize,
    pub v8: usize,
    pub rv: usize,
    pub kr8: usize,
    pub rkr: usize,
    pub s8: usize,
    pub rs: usize,
    pub zsel: usize,
    pub et: usize,
    pub pp: usize,
    pub rho_s: usize,
    pub ao: ClsPlane,
    pub rao: usize,
    pub xres1: ClsPlane,
    pub rr1: usize,
    pub xm8: usize,
    pub rho_m: Vec<usize>,
    pub sig_m: Vec<usize>,
    pub xres2: ClsPlane,
    pub rr2: usize,
    pub z16c: usize,
    pub sm: usize,
    pub lm: usize,
    pub a_len: usize,
    // ---- W ----
    pub wq: usize,
    pub wk: usize,
    pub wv: usize,
    pub wo: usize,
    pub gpack: usize,
    pub log_gp: u32,
    pub log_wq: u32,
    pub log_wkv: u32,
    pub w_len: usize,
    // ---- H (helper columns: (re, im) offsets per domain, in lookup-pair order) ----
    pub h_d: Vec<(usize, usize)>,
    pub h_q: Vec<(usize, usize)>,
    pub h_kv: Vec<(usize, usize)>,
    pub h_s: Vec<(usize, usize)>,
    pub h_lm: (usize, usize),
    pub h_len: usize,
}

impl AttnLayout {
    pub fn new(shape: &AttnShape, x_cls: Cls, ao_cls: Cls, r1_cls: Cls, r2_cls: Cls, n_limb_a: usize,
               n_limb_m: usize, target_cols: u32) -> AttnLayout {
        let p = PadShape::new(shape);
        let (log_t, log_dp, log_hp) = (p.t.trailing_zeros(), p.dp.trailing_zeros(), p.hp.trailing_zeros());
        let (log_qp, log_vp, log_hd, log_kp) = (p.qp.trailing_zeros(), p.vp.trailing_zeros(),
                                                p.hd.trailing_zeros(), p.kp.trailing_zeros());
        let log_rep = p.rep_p.trailing_zeros();
        let (log_d, log_q, log_kv, log_s) = (log_t + log_dp, log_t + log_qp, log_t + log_vp, log_hp + 2 * log_t);
        let min_dom = log_d.min(log_q).min(log_kv).min(log_s);
        let cols_log = target_cols.min(min_dom);
        let sm_need = ceil_log2(2 * p.hp * p.t + 8 * p.t);
        let log_sm = sm_need.max(cols_log);
        let log_lm = ceil_log2(8 * p.t).max(cols_log + 1);
        let mut al = Alloc { off: 0 };
        let mut cls_plane = |al: &mut Alloc, cls: Cls, log: u32| -> ClsPlane {
            let n = match cls { Cls::Int24 => 2, _ => 1 };
            ClsPlane { offs: (0..n).map(|_| al.take(log)).collect(), cls }
        };
        let x_in = cls_plane(&mut al, x_cls, log_d);
        let xn8 = al.take(log_d);
        let rho_a: Vec<usize> = (0..n_limb_a).map(|_| al.take(log_d)).collect();
        let sig_a: Vec<usize> = (0..n_limb_a).map(|_| al.take(log_d)).collect();
        let (q8, rq, qr8, rqr, o8, ro) = (al.take(log_q), al.take(log_q), al.take(log_q), al.take(log_q),
                                          al.take(log_q), al.take(log_q));
        let (k8, rk, v8, rv, kr8, rkr) = (al.take(log_kv), al.take(log_kv), al.take(log_kv), al.take(log_kv),
                                          al.take(log_kv), al.take(log_kv));
        let (s8, rs, zsel, et, pp, rho_s) = (al.take(log_s), al.take(log_s), al.take(log_s), al.take(log_s),
                                             al.take(log_s), al.take(log_s));
        let ao = cls_plane(&mut al, ao_cls, log_d);
        let rao = al.take(log_d);
        let xres1 = cls_plane(&mut al, r1_cls, log_d);
        let rr1 = al.take(log_d);
        let xm8 = al.take(log_d);
        let rho_m: Vec<usize> = (0..n_limb_m).map(|_| al.take(log_d)).collect();
        let sig_m: Vec<usize> = (0..n_limb_m).map(|_| al.take(log_d)).collect();
        let xres2 = cls_plane(&mut al, r2_cls, log_d);
        let rr2 = al.take(log_d);
        let z16c = al.take(log_d);
        let sm = al.take(log_sm);
        let lm = al.take(log_lm);
        let cols = 1usize << cols_log;
        let a_len = al.off.div_ceil(cols) * cols;
        // ---- W ----
        let (log_wq, log_wkv) = (log_dp + log_qp, log_dp + log_vp);
        let log_gp = ceil_log2(2 * p.dp).max(cols_log);
        let mut wl = Alloc { off: 0 };
        let wq = wl.take(log_wq);
        let wk = wl.take(log_wkv);
        let wv = wl.take(log_wkv);
        let wo = wl.take(log_wq);
        let gpack = wl.take(log_gp);
        let w_len = wl.off.div_ceil(cols) * cols;
        // ---- H ----
        let mut hl = Alloc { off: 0 };
        let mut pair = |hl: &mut Alloc, n: usize, log: u32| -> Vec<(usize, usize)> {
            (0..n).map(|_| (hl.take(log), hl.take(log))).collect()
        };
        // D-domain lookups, paired in order (see `d_lookups`)
        let n_d = (1 + x_in.offs.len() + 2 * n_limb_a + 2 * n_limb_m + ao.offs.len() + 1
                   + xres1.offs.len() + 1 + xres2.offs.len() + 1 + 1 + 1).div_ceil(2);
        let h_d = pair(&mut hl, n_d, log_d);
        let h_q = pair(&mut hl, 3, log_q);
        let h_kv = pair(&mut hl, 3, log_kv);
        let h_s = pair(&mut hl, 3, log_s);
        let h_lm = (hl.take(log_lm - 1), hl.take(log_lm - 1));
        let h_len = hl.off.div_ceil(cols) * cols;
        AttnLayout {
            p, log_t, log_dp, log_hp, log_qp, log_vp, log_hd, log_kp, log_rep,
            log_d, log_q, log_kv, log_s, log_sm, log_lm, cols_log,
            x_in, xn8, rho_a, sig_a, q8, rq, qr8, rqr, o8, ro, k8, rk, v8, rv, kr8, rkr,
            s8, rs, zsel, et, pp, rho_s, ao, rao, xres1, rr1, xm8, rho_m, sig_m, xres2, rr2, z16c,
            sm, lm, a_len, wq, wk, wv, wo, gpack, log_gp, log_wq, log_wkv, w_len,
            h_d, h_q, h_kv, h_s, h_lm, h_len,
        }
    }

    pub fn sl(&self, off: usize, log: u32) -> Slice {
        Slice { offset: off, log_size: log }
    }
    // sub-block offsets inside the packed small slices
    pub fn sm_m(&self) -> usize { self.sm }
    pub fn sm_sum(&self) -> usize { self.sm + self.p.hp * self.p.t }
    /// site 0 = attn norm, 1 = mlp norm; k: 0 D, 1 Dsq, 2 a1, 3 a2
    pub fn sm_row(&self, site: usize, k: usize) -> usize {
        self.sm + 2 * self.p.hp * self.p.t + (4 * site + k) * self.p.t
    }
    /// site, which: 0 a1_l0, 1 a1_l1, 2 a2_l0, 3 a2_l1
    pub fn lm_row(&self, site: usize, k: usize) -> usize {
        self.lm + (4 * site + k) * self.p.t
    }
}

/// The point of arity `base_log` selecting the sub-block at `off` (size
/// 2^sub_log) of a packed slice starting at `base`, followed by `r`.
pub fn sub_point(base: usize, base_log: u32, off: usize, sub_log: u32, r: &[Fp2]) -> Vec<Fp2> {
    assert_eq!(r.len() as u32, sub_log);
    let idx = (off - base) >> sub_log;
    let hi = (base_log - sub_log) as usize;
    let mut pt = Vec::with_capacity(base_log as usize);
    for b in (0..hi).rev() {
        pt.push(if (idx >> b) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO });
    }
    pt.extend_from_slice(r);
    pt
}


// ==========================================================================
// [UPERF3-AG] RUNG 4 — packing the witness into the three commitments.
// ==========================================================================

/// The residual-2 edge (xres2 = requant(xres1 2^a + z16 2^b, sh_r2)) and the
/// FFN's z16 plane: the part of the layer the attention oracle does not
/// cover (it needs the FFN's output).
#[derive(Clone, Debug)]
pub struct FullConsts {
    pub sh_x2: u32,
    pub sh_z2: u32,
    pub sh_r2: i32,
    pub r2_cls: Cls,
    pub e_r2: i32,
    pub e_z16: i32,
}

pub struct Resid2 {
    pub c: FullConsts,
    pub z16: Vec<i64>,
    pub xres2: Vec<i64>,
    pub rr2: Vec<i64>,
}

/// Close the layer: xres2 = round-requant(xres1 << a + z16 << b) in `cls`,
/// with the shift FITTED (raised while the narrowing would saturate — the
/// shift is a public statement constant, never a silent clamp).
pub fn residual2(w: &AttnWitness, z16: Vec<i64>, e_r1: i32, e_z16: i32, cls: Cls) -> Resid2 {
    let e_c = e_r1.min(e_z16);
    let (sh_x2, sh_z2) = ((e_r1 - e_c) as u32, (e_z16 - e_c) as u32);
    let xw2: Vec<i64> = w.xres1.par_iter().zip(z16.par_iter())
        .map(|(&x, &z)| (x << sh_x2) + (z << sh_z2)).collect();
    let mut sh = 0i32;
    let (xres2, rr2) = loop {
        let (y, r) = requant_round(&xw2, sh as i64);
        if y.iter().all(|&v| v.abs() <= cls.limit()) {
            break (y, r);
        }
        sh += 1;
        assert!(sh < 32, "residual2: runaway requant fit");
    };
    Resid2 { c: FullConsts { sh_x2, sh_z2, sh_r2: sh, r2_cls: cls, e_r2: e_c + sh, e_z16 }, z16, xres2, rr2 }
}

/// Multiplicity histograms, one per table.
pub struct MultSet {
    pub f_p: u32,
    pub m: std::collections::BTreeMap<Tbl, Vec<u32>>,
    /// values that fell OUTSIDE their table (only a tampered — or
    /// mis-calibrated — witness gets here; reported, never silent)
    pub bad: std::collections::BTreeMap<Tbl, (u64, i64)>,
}

impl MultSet {
    pub fn new(f_p: u32) -> MultSet {
        MultSet { f_p, m: std::collections::BTreeMap::new(), bad: std::collections::BTreeMap::new() }
    }
    pub fn ensure(&mut self, t: Tbl) {
        let f_p = self.f_p;
        self.m.entry(t).or_insert_with(|| vec![0u32; t.rows(f_p)]);
    }
    /// Count one witness value; a value outside its table lands in row 0 so
    /// the totals still match and only the LogUp identity catches it.
    pub fn count(&mut self, t: Tbl, v: i64) {
        self.count_all(t, &[v]);
    }
    pub fn count_all(&mut self, t: Tbl, vs: &[i64]) {
        let f_p = self.f_p;
        let h = self.m.entry(t).or_insert_with(|| vec![0u32; t.rows(f_p)]);
        let mut bad = 0u64;
        let mut worst = 0i64;
        for &v in vs {
            match t.index(v, f_p) {
                Some(i) => h[i] += 1,
                None => { h[0] += 1; bad += 1; if v.abs() > worst.abs() { worst = v; } }
            }
        }
        if bad > 0 {
            let e = self.bad.entry(t).or_insert((0, 0));
            e.0 += bad;
            if worst.abs() > e.1.abs() { e.1 = worst; }
        }
    }
    pub fn into_vec(self) -> Vec<(u64, Vec<u32>)> {
        let mut v: Vec<(u64, Vec<u32>)> = self.m.into_iter().map(|(t, h)| (t.tag(), h)).collect();
        v.sort_by_key(|(tag, _)| *tag);
        v
    }
}

/// The dummy (pad) head's softmax planes: what the chain produces for an
/// all-zero query head. Shapes (T x T) and (T).
struct DummyHead {
    s8: Vec<i64>,
    rs: Vec<i64>,
    zsel: Vec<i64>,
    et: Vec<i64>,
    p: Vec<i64>,
    rho: Vec<i64>,
    m_row: Vec<i64>,
    sum: Vec<i64>,
}

fn dummy_head(t: usize, exp: &[i64; 256], f_e: u32, f_p: u32) -> DummyHead {
    let mut dh = DummyHead {
        s8: vec![0; t * t], rs: vec![0; t * t], zsel: vec![0; t * t], et: vec![0; t * t],
        p: vec![0; t * t], rho: vec![0; t * t], m_row: vec![0; t], sum: vec![0; t],
    };
    for ti in 0..t {
        dh.zsel[ti * t] = 1;
        let mut s = 0i64;
        for j in 0..t {
            let dv = if j <= ti { 0 } else { 127 };
            let e = exp[dv as usize];
            dh.et[ti * t + j] = e;
            if j <= ti {
                s += e;
            }
        }
        assert!(s >= 1i64 << f_e);
        dh.sum[ti] = s;
        for j in 0..=ti {
            let num = dh.et[ti * t + j] << f_p;
            let q = num.div_euclid(s);
            dh.p[ti * t + j] = q;
            dh.rho[ti * t + j] = num - q * s;
        }
    }
    dh
}

/// Fill one padded plane from a value function, count its lookups, write Fp.
fn fill<F>(a: &mut [Fp], off: usize, rows: usize, cols: usize, f: F, ms: &mut MultSet, tbl: Option<Tbl>)
where
    F: Fn(usize, usize) -> i64 + Sync,
{
    let mut buf = vec![0i64; rows * cols];
    buf.par_chunks_mut(cols).enumerate().for_each(|(r, row)| {
        for (c, slot) in row.iter_mut().enumerate() {
            *slot = f(r, c);
        }
    });
    if let Some(t) = tbl {
        ms.count_all(t, &buf);
    }
    a[off..off + rows * cols].par_iter_mut().zip(buf.par_iter()).for_each(|(o, &v)| *o = Fp::from_i64(v));
}

/// Fill a class plane (one plane, or two 16-bit limbs for int24).
fn fill_cls<F>(a: &mut [Fp], cp: &ClsPlane, rows: usize, cols: usize, f: F, ms: &mut MultSet)
where
    F: Fn(usize, usize) -> i64 + Sync,
{
    let tabs = cp.tables();
    for (k, &off) in cp.offs.iter().enumerate() {
        let cls = cp.cls;
        fill(a, off, rows, cols, |r, c| {
            let v = f(r, c);
            match cls {
                Cls::Int24 => {
                    let u = v + (1 << 23);
                    if k == 0 { u & 0xffff } else { u >> 16 }
                }
                _ => v,
            }
        }, ms, Some(tabs[k]));
    }
}


// ---- plane accessors: (padded row, padded col) -> the chain's value ------
fn f_d(v: &[i64], d: usize) -> impl Fn(usize, usize) -> i64 + Sync + '_ {
    move |r, c| if c < d { v[r * d + c] } else { 0 }
}
fn f_kv(v: &[i64], kw: usize) -> impl Fn(usize, usize) -> i64 + Sync + '_ {
    move |r, c| if c < kw { v[r * kw + c] } else { 0 }
}
fn f_q<'a>(nat: &'a [i64], dummy: Option<&'a [Vec<i64>]>, p: PadShape)
    -> impl Fn(usize, usize) -> i64 + Sync + 'a {
    let (hd, qw) = (p.hd, p.heads * p.hd);
    move |r, c| {
        let (hs, i) = (c / hd, c % hd);
        match p.hnat(hs) {
            Some(h) => nat[r * qw + h * hd + i],
            None => match dummy { Some(dv) => dv[hs / p.rep_p][r * hd + i], None => 0 },
        }
    }
}
fn f_s<'a>(nat: &'a [i64], dum: &'a [i64], p: PadShape) -> impl Fn(usize, usize) -> i64 + Sync + 'a {
    let t = p.t;
    move |r, j| {
        let (hs, ti) = (r / t, r % t);
        match p.hnat(hs) { Some(h) => nat[(h * t + ti) * t + j], None => dum[ti * t + j] }
    }
}
fn f_ht<'a>(nat: &'a [i64], dum: &'a [i64], p: PadShape) -> impl Fn(usize, usize) -> i64 + Sync + 'a {
    let t = p.t;
    move |hs, ti| match p.hnat(hs) { Some(h) => nat[h * t + ti], None => dum[ti] }
}

pub struct Packed {
    pub a: Vec<Fp>,
    pub w: Vec<Fp>,
    pub mults: Vec<(u64, Vec<u32>)>,
}

/// Pack the witness (+ the residual-2 edge) into the A and W vectors and
/// build the multiplicity histograms.
pub fn pack(wit: &AttnWitness, r2: &Resid2, lay: &AttnLayout) -> Packed {
    let p = lay.p;
    let (t, d, dp, hd, qp, vp, hp) = (p.t, p.d, p.dp, p.hd, p.qp, p.vp, p.hp);
    let qw = p.heads * hd;
    let kw = p.kv * hd;
    let c = &wit.c;
    let mut a = vec![Fp::ZERO; lay.a_len];
    let mut ms = MultSet::new(c.f_p);
    let dh = dummy_head(t, &wit.exp_tab, c.f_e, c.f_p);

    // ---- D-domain planes (t, i) ----------------------------------------
    fill_cls(&mut a, &lay.x_in, t, dp, f_d(&wit.x_in, d), &mut ms);
    fill(&mut a, lay.xn8, t, dp, f_d(&wit.na.y, d), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.xm8, t, dp, f_d(&wit.nm.y, d), &mut ms, Some(Tbl::Int8));
    fill_cls(&mut a, &lay.ao, t, dp, f_d(&wit.ao8, d), &mut ms);
    fill(&mut a, lay.rao, t, dp, f_d(&wit.r_ao, d), &mut ms, Some(Tbl::Win(c.sh_ao)));
    fill_cls(&mut a, &lay.xres1, t, dp, f_d(&wit.xres1, d), &mut ms);
    fill(&mut a, lay.rr1, t, dp, f_d(&wit.rr1, d), &mut ms, Some(Tbl::Win(c.sh_r1)));
    fill_cls(&mut a, &lay.xres2, t, dp, f_d(&r2.xres2, d), &mut ms);
    fill(&mut a, lay.rr2, t, dp, f_d(&r2.rr2, d), &mut ms, Some(Tbl::Win(r2.c.sh_r2)));
    fill(&mut a, lay.z16c, t, dp, f_d(&r2.z16, d), &mut ms, Some(Tbl::Int16));
    // the norm remainders: the pad columns carry the values the gadget
    // itself produces on a zero input (rho = div, sigma = div - 1).
    for (nc, nch, rho_off, sig_off) in [
        (&c.anorm, &wit.na, &lay.rho_a, &lay.sig_a),
        (&c.mnorm, &wit.nm, &lay.rho_m, &lay.sig_m),
    ] {
        let dvp: Vec<i64> = (0..t).map(|r| (nch.dd[r] << nc.tn) * if c.norm_round { 2 } else { 1 }).collect();
        let pad_rho: Vec<i64> = dvp.iter().map(|&x| if c.norm_round { x / 2 } else { 0 }).collect();
        let pad_sig: Vec<i64> = dvp.iter().zip(pad_rho.iter()).map(|(&dv, &r)| dv - 1 - r).collect();
        for (k, &off) in rho_off.iter().enumerate() {
            fill(&mut a, off, t, dp, |r, cc| {
                let v = if cc < d { nch.rho[r * d + cc] } else { pad_rho[r] };
                (v >> (16 * k)) & 0xffff
            }, &mut ms, Some(Tbl::U16));
        }
        for (k, &off) in sig_off.iter().enumerate() {
            fill(&mut a, off, t, dp, |r, cc| {
                let v = if cc < d { nch.sig[r * d + cc] } else { pad_sig[r] };
                (v >> (16 * k)) & 0xffff
            }, &mut ms, Some(Tbl::U16));
        }
    }

    // ---- Q-domain planes (t, h', i) -------------------------------------
    let mut dummy_o8: Vec<Vec<i64>> = Vec::new();
    let mut dummy_ro: Vec<Vec<i64>> = Vec::new();
    if p.rep_p > p.rep {
        for g in 0..p.kv {
            let mut oacc = vec![0i64; t * hd];
            oacc.par_chunks_mut(hd).enumerate().for_each(|(ti, row)| {
                for j in 0..=ti {
                    let pv = dh.p[ti * t + j];
                    if pv == 0 { continue; }
                    let vrow = &wit.v8[j * kw + g * hd..j * kw + g * hd + hd];
                    for i in 0..hd { row[i] += pv * vrow[i]; }
                }
            });
            let (y, r) = requant_round(&oacc, c.sh_o as i64);
            assert!(y.iter().all(|&v| v.abs() <= 127), "pad head o8 saturates");
            dummy_o8.push(y);
            dummy_ro.push(r);
        }
    }
    fill(&mut a, lay.q8, t, qp, f_q(&wit.q8, None, p), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rq, t, qp, f_q(&wit.rq, None, p), &mut ms, Some(Tbl::Win(c.sh_q)));
    fill(&mut a, lay.qr8, t, qp, f_q(&wit.qr8, None, p), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rqr, t, qp, f_q(&wit.rqr, None, p), &mut ms, Some(Tbl::Win(c.sh_qr)));
    fill(&mut a, lay.o8, t, qp, f_q(&wit.o8, Some(&dummy_o8), p), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.ro, t, qp, f_q(&wit.r_o, Some(&dummy_ro), p), &mut ms, Some(Tbl::Win(c.sh_o)));

    // ---- KV-domain planes (t, g, i) (no padding: H_kv is a power of two) --
    fill(&mut a, lay.k8, t, vp, f_kv(&wit.k8, kw), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rk, t, vp, f_kv(&wit.rk, kw), &mut ms, Some(Tbl::Win(c.sh_k)));
    fill(&mut a, lay.v8, t, vp, f_kv(&wit.v8, kw), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rv, t, vp, f_kv(&wit.rv, kw), &mut ms, Some(Tbl::Win(c.sh_v)));
    fill(&mut a, lay.kr8, t, vp, f_kv(&wit.kr8, kw), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rkr, t, vp, f_kv(&wit.rkr, kw), &mut ms, Some(Tbl::Win(c.sh_kr)));

    // ---- S-domain planes (h', t, j) --------------------------------------
    fill(&mut a, lay.s8, hp * t, t, f_s(&wit.s8, &dh.s8, p), &mut ms, Some(Tbl::Int8));
    fill(&mut a, lay.rs, hp * t, t, f_s(&wit.rs, &dh.rs, p), &mut ms, Some(Tbl::Win(c.sh_s)));
    fill(&mut a, lay.zsel, hp * t, t, f_s(&wit.zsel, &dh.zsel, p), &mut ms, None);
    fill(&mut a, lay.et, hp * t, t, f_s(&wit.e_t, &dh.et, p), &mut ms, None);
    fill(&mut a, lay.pp, hp * t, t, f_s(&wit.p, &dh.p, p), &mut ms, Some(Tbl::Prob));
    fill(&mut a, lay.rho_s, hp * t, t, f_s(&wit.rho_s, &dh.rho, p), &mut ms, Some(Tbl::Srem(c.wrho_s)));
    // the fused (d, E) rows and the derived sigma are counted here (they are
    // never committed: the zero-check computes them from m, s8, Sum, rho).
    {
        let mut dvals = vec![0i64; hp * t * t];
        let mut svals = vec![0i64; hp * t * t];
        dvals.par_chunks_mut(t).enumerate().for_each(|(r, row)| {
            let (hs, ti) = (r / t, r % t);
            for (j, slot) in row.iter_mut().enumerate() {
                *slot = match p.hnat(hs) {
                    Some(h) => wit.dmat[(h * t + ti) * t + j],
                    None => if j <= ti { 0 } else { 127 },
                };
            }
        });
        svals.par_chunks_mut(t).enumerate().for_each(|(r, row)| {
            let (hs, ti) = (r / t, r % t);
            let (sum, rho): (i64, &[i64]) = match p.hnat(hs) {
                Some(h) => (wit.sum[h * t + ti], &wit.rho_s[(h * t + ti) * t..(h * t + ti + 1) * t]),
                None => (dh.sum[ti], &dh.rho[ti * t..(ti + 1) * t]),
            };
            for (j, slot) in row.iter_mut().enumerate() {
                *slot = sum - 1 - rho[j];
            }
        });
        ms.count_all(Tbl::Exp, &dvals);
        ms.count_all(Tbl::Srem(c.wrho_s), &svals);
    }

    // ---- the packed small slices ----------------------------------------
    fill(&mut a, lay.sm_m(), hp, t, f_ht(&wit.m_row, &dh.m_row, p), &mut ms, None);
    fill(&mut a, lay.sm_sum(), hp, t, f_ht(&wit.sum, &dh.sum, p), &mut ms, None);
    for (site, nch) in [(0usize, &wit.na), (1, &wit.nm)] {
        for (k, v) in [&nch.dd, &nch.dsq, &nch.a1, &nch.a2].iter().enumerate() {
            fill(&mut a, lay.sm_row(site, k), 1, t, |_, i| v[i], &mut ms, None);
        }
        for (k, v) in [&nch.a1, &nch.a2].iter().enumerate() {
            for l in 0..2 {
                fill(&mut a, lay.lm_row(site, 2 * k + l), 1, t, |_, i| (v[i] >> (16 * l)) & 0xffff,
                     &mut ms, Some(Tbl::U16));
            }
        }
    }
    // the LM slice's unused tail is zero and IS looked up (0 is in U16)
    {
        let used = 8 * t;
        let tail = (1usize << lay.log_lm) - used;
        ms.ensure(Tbl::U16);
        let f_p = ms.f_p;
        let h = ms.m.get_mut(&Tbl::U16).unwrap();
        let _ = f_p;
        h[0] += tail as u32;
    }

    // ---- W ---------------------------------------------------------------
    let mut wv_ = vec![Fp::ZERO; lay.w_len];
    let mut nul = MultSet::new(c.f_p);
    fill(&mut wv_, lay.wq, dp, qp, |i, j| {
        let (hs, ih) = (j / hd, j % hd);
        match (p.hnat(hs), i < d) { (Some(h), true) => wit.wq[(h * hd + ih) * d + i], _ => 0 }
    }, &mut nul, None);
    fill(&mut wv_, lay.wk, dp, vp, |i, j| if i < d { wit.wk[j * d + i] } else { 0 }, &mut nul, None);
    fill(&mut wv_, lay.wv, dp, vp, |i, j| if i < d { wit.wv[j * d + i] } else { 0 }, &mut nul, None);
    fill(&mut wv_, lay.wo, qp, dp, |j, n| {
        let (hs, ih) = (j / hd, j % hd);
        match (p.hnat(hs), n < d) { (Some(h), true) => wit.wo[n * qw + h * hd + ih], _ => 0 }
    }, &mut nul, None);
    fill(&mut wv_, lay.gpack, 2, dp, |s, i| {
        if i >= d { 0 } else if s == 0 { wit.g_a[i] } else { wit.g_m[i] }
    }, &mut nul, None);

    if !ms.bad.is_empty() && !tamper_mode() {
        let rep: Vec<String> = ms.bad.iter()
            .map(|(t, (n, w))| format!("{t:?}: {n} values outside, worst {w}")).collect();
        panic!("[UPERF3-AG] the witness does not fit its statement's tables — {}", rep.join("; "));
    }
    Packed { a, w: wv_, mults: ms.into_vec() }
}


// ==========================================================================
// [UPERF3-AG] RUNG 4 — the prover and verifier of the attention half-layer.
//
// Shape of the argument (all over the ONE A commitment + W + H):
//   * six zero-checks (D, Q, KV, S, the D = isqrt row facts, the packed
//     limb slice) carrying the LogUp helper identities and the three
//     genuinely non-linear relations (the two norm divisions, the softmax
//     division, D^2, the RoPE rotation, the fused exp row);
//   * six sumchecks (the two row sums, the batched QKV matmul, the per-head
//     score matmul, the PV matmul, the Wo matmul);
//   * every POINTWISE-LINEAR relation (the requant identities, the two
//     residual pins, sigma = 2 div - 1 - rho, the isqrt pair, the limb
//     reconstructions) is checked on the CLAIMED EVALUATIONS at a random
//     point instead of costing a constraint — sound by Schwartz-Zippel,
//     free in the prover.
// Unlike the v3 FFN prover this one does NOT fold its pending claims into
// the zero-checks: it opens A/W/H at ~20 points instead of two. That costs
// proof bytes (one group vector per distinct point) and buys a prover that
// fits in one lane; folding is the named next optimization.
// ==========================================================================

fn tab2(a: &[Fp], off: usize, len: usize) -> Vec<Fp2> {
    a[off..off + len].par_iter().map(|v| Fp2::from_base(*v)).collect()
}

/// Evaluate several equal-sized slices at one point (one eq table).
fn eval_slices(a: &[Fp], sl: &[(usize, usize)], pt: &[Fp2]) -> Vec<Fp2> {
    let eq = eq_table_msb(pt);
    sl.iter()
        .map(|&(o, l)| {
            assert_eq!(l, eq.len(), "eval_slices: arity");
            a[o..o + l].par_iter().zip(eq.par_iter())
                .map(|(x, e)| e.mul_base(*x))
                .reduce(|| Fp2::ZERO, |x, y| x.add(y))
        })
        .collect()
}

fn helper_col(l1: &[Fp2], l2: Option<&[Fp2]>, alpha: Fp2) -> Vec<Fp2> {
    let n = l1.len();
    let mut den: Vec<Fp2> = Vec::with_capacity(if l2.is_some() { 2 * n } else { n });
    den.extend(l1.iter().map(|v| alpha.sub(*v)));
    if let Some(l2) = l2 {
        den.extend(l2.iter().map(|v| alpha.sub(*v)));
    }
    den.par_chunks_mut(4096).for_each(|c| batch_inverse2(c));
    match l2 {
        Some(_) => (0..n).into_par_iter().map(|i| den[i].add(den[n + i])).collect(),
        None => den,
    }
}

#[inline(always)]
fn hcon(h: Fp2, l1: Fp2, l2: Option<Fp2>, alpha: Fp2) -> Fp2 {
    let d1 = alpha.sub(l1);
    match l2 {
        Some(l2) => {
            let d2 = alpha.sub(l2);
            h.mul(d1).mul(d2).sub(d1.add(d2))
        }
        None => h.mul(d1).sub(Fp2::ONE),
    }
}

/// A linear reconstruction of a class value from its committed limbs:
/// value = sum coef_k * table[idx_k] + offset.
#[derive(Clone, Debug)]
pub struct Recon {
    pub idx: Vec<usize>,
    pub coef: Vec<i64>,
    pub off: i64,
}

impl Recon {
    fn eval(&self, v: &[Fp2]) -> Fp2 {
        let mut s = Fp2::from_i64(self.off);
        for (i, c) in self.idx.iter().zip(self.coef.iter()) {
            s = s.add(v[*i].mul_base(Fp::from_i64(*c)));
        }
        s
    }
    fn of(cp: &ClsPlane, first_idx: usize) -> Recon {
        let (coef, off) = cp.recon();
        Recon { idx: (0..cp.offs.len()).map(|k| first_idx + k).collect(), coef, off }
    }
}

/// The non-helper constraints of a zero-check.
#[derive(Clone, Debug)]
pub enum Extra {
    /// y (D 2^(tn+1)) + rho - 2 Cn x g - D 2^tn = 0   (the ROUND division)
    NormDiv { y: usize, rho: Recon, x: Recon, g: usize, dd: usize, tn: u32, cn: i64 },
    /// 2^sh y + r - (C src + S srcflip) = 0   (the RoPE rotation)
    Rope { y: usize, r: usize, src: usize, srcf: usize, ct: usize, st: usize, sh: i32 },
    /// Dsq - D D = 0
    Square { sq: usize, v: usize },
}

impl Extra {
    fn eval(&self, v: &[Fp2]) -> Fp2 {
        match self {
            Extra::NormDiv { y, rho, x, g, dd, tn, cn } => {
                let two_div_y = v[*y].mul(v[*dd]).mul_base(Fp::new(1u64 << (tn + 1)));
                let div = v[*dd].mul_base(Fp::new(1u64 << tn));
                let num = x.eval(v).mul(v[*g]).mul_base(Fp::from_i64(2 * cn));
                two_div_y.add(rho.eval(v)).sub(num).sub(div)
            }
            Extra::Rope { y, r, src, srcf, ct, st, sh } => {
                let lhs = v[*y].mul_base(crate::layer::pow2_signed(*sh)).add(v[*r]);
                lhs.sub(v[*ct].mul(v[*src])).sub(v[*st].mul(v[*srcf]))
            }
            Extra::Square { sq, v: d } => v[*sq].sub(v[*d].mul(v[*d])),
        }
    }
}

/// One zero-check's constraint plan (shared by prover and verifier).
#[derive(Clone, Debug)]
pub struct ZcPlan {
    pub alpha: Fp2,
    /// (l1 table index, gamma tag1, optional (l2 index, gamma tag2), helper index)
    pub pairs: Vec<(usize, Fp2, Option<(usize, Fp2)>, usize)>,
    pub extras: Vec<Extra>,
    pub mu: Vec<Fp2>,
    pub eq_idx: usize,
}

impl ZcPlan {
    pub fn eval(&self, v: &[Fp2]) -> Fp2 {
        let mut acc = Fp2::ZERO;
        let mut k = 0usize;
        for (l1, g1, l2, hi) in &self.pairs {
            let a1 = v[*l1].add(*g1);
            let a2 = l2.map(|(i2, g2)| v[i2].add(g2));
            acc = acc.add(self.mu[k].mul(hcon(v[*hi], a1, a2, self.alpha)));
            k += 1;
        }
        for e in &self.extras {
            acc = acc.add(self.mu[k].mul(e.eval(v)));
            k += 1;
        }
        v[self.eq_idx].mul(acc)
    }
    pub fn degree(&self) -> usize {
        4
    }
}

/// The softmax zero-check's plan (bespoke: the fused exp row is degree 2).
#[derive(Clone, Debug)]
pub struct SPlan {
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_int8: Fp2,
    pub g_win: Fp2,
    pub g_exp: Fp2,
    pub g_prob: Fp2,
    pub g_srem: Fp2,
    pub mu: Vec<Fp2>,
    pub f_p: u32,
}

/// Table order of the softmax zero-check.
pub const S_EQ: usize = 0;
pub const S_S8: usize = 1;
pub const S_RS: usize = 2;
pub const S_ZSEL: usize = 3;
pub const S_E: usize = 4;
pub const S_P: usize = 5;
pub const S_RHO: usize = 6;
pub const S_M: usize = 7;
pub const S_SUM: usize = 8;
pub const S_MASK: usize = 9;
pub const S_H0: usize = 10;
pub const S_H1: usize = 11;
pub const S_H2: usize = 12;

impl SPlan {
    pub fn eval(&self, v: &[Fp2]) -> Fp2 {
        let (eqt, s8, rs, zsel, e, p, rho, mb, sumb, mask) =
            (v[S_EQ], v[S_S8], v[S_RS], v[S_ZSEL], v[S_E], v[S_P], v[S_RHO], v[S_M], v[S_SUM], v[S_MASK]);
        // sM = mask s8 - 127 (1 - mask); dd = m - sM
        let sm = mask.mul(s8).add(mask.mul_base(Fp::from_i64(127))).sub(Fp2::from_i64(127));
        let dd = mb.sub(sm);
        let c0 = hcon(v[S_H0], s8.add(self.g_int8), Some(rs.add(self.g_win)), self.alpha);
        let c1 = hcon(v[S_H1], dd.add(self.beta.mul(e)).add(self.g_exp), Some(p.add(self.g_prob)), self.alpha);
        let sig = sumb.sub(Fp2::ONE).sub(rho);
        let c2 = hcon(v[S_H2], rho.add(self.g_srem), Some(sig.add(self.g_srem)), self.alpha);
        // the softmax division: on the mask P Sum + rho = 2^fP E, off it P = rho = 0
        let on = p.mul(sumb).add(rho).sub(e.mul_base(Fp::new(1u64 << self.f_p)));
        let off = p.add(rho);
        let c3 = mask.mul(on).add(off).sub(mask.mul(off));
        let c4 = zsel.mul(Fp2::ONE.sub(zsel));
        let c5 = zsel.mul(dd);
        let acc = self.mu[0].mul(c0).add(self.mu[1].mul(c1)).add(self.mu[2].mul(c2))
            .add(self.mu[3].mul(c3)).add(self.mu[4].mul(c4)).add(self.mu[5].mul(c5));
        eqt.mul(acc)
    }
}

/// The attention half-layer proof.
#[derive(Clone, Debug, Default)]
pub struct AttnProof {
    pub w_com: Option<Commitment>,
    pub a_com: Option<Commitment>,
    pub h_com: Option<Commitment>,
    pub mults: Vec<(u64, Vec<u32>)>,
    /// every claimed evaluation, in collector order
    pub vals: Vec<Fp2>,
    pub sc: Vec<SumcheckProof>,
    pub helper_sums: Vec<Fp2>,
    pub w_open: Opening,
    pub a_open: Opening,
    pub h_open: Opening,
}

impl AttnProof {
    pub fn size_bytes(&self) -> usize {
        let coms = 3 * (32 + 8 + 4);
        let mults: usize = self.mults.iter().map(|(_, m)| 8 + 4 + m.len() * 4).sum();
        coms + mults + self.vals.len() * 16 + self.sc.iter().map(|s| s.size_bytes()).sum::<usize>()
            + self.helper_sums.len() * 16
            + self.w_open.size_bytes() + self.a_open.size_bytes() + self.h_open.size_bytes()
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.size_bytes());
        for c in [&self.w_com, &self.a_com, &self.h_com] {
            let c = c.as_ref().expect("commitment");
            out.extend_from_slice(&c.root);
            out.extend_from_slice(&(c.rows as u64).to_le_bytes());
            out.extend_from_slice(&c.log_cols.to_le_bytes());
        }
        for (tag, m) in &self.mults {
            out.extend_from_slice(&tag.to_le_bytes());
            out.extend_from_slice(&(m.len() as u32).to_le_bytes());
            for v in m {
                out.extend_from_slice(&v.to_le_bytes());
            }
        }
        for v in &self.vals {
            out.extend_from_slice(&v.to_bytes());
        }
        for s in &self.sc {
            s.write_bytes(&mut out);
        }
        for v in &self.helper_sums {
            out.extend_from_slice(&v.to_bytes());
        }
        self.w_open.write_bytes(&mut out);
        self.a_open.write_bytes(&mut out);
        self.h_open.write_bytes(&mut out);
        debug_assert_eq!(out.len(), self.size_bytes());
        out
    }
}

/// The claim collector: the prover pushes values, the verifier reads them,
/// and BOTH build the identical PCS claim lists in the identical order.
pub struct Cc {
    pub aw: Vec<Claim>,
    pub ww: Vec<Claim>,
    pub hh: Vec<Claim>,
    pub vals: Vec<Fp2>,
    pub idx: usize,
    pub proving: bool,
}

impl Cc {
    pub fn new(proving: bool, vals: Vec<Fp2>) -> Cc {
        Cc { aw: Vec::new(), ww: Vec::new(), hh: Vec::new(), vals, idx: 0, proving }
    }
    fn take(&mut self, tr: &mut Transcript, v: Fp2) -> Fp2 {
        let out = if self.proving {
            self.vals.push(v);
            v
        } else {
            let x = *self.vals.get(self.idx).unwrap_or(&Fp2::ZERO);
            self.idx += 1;
            x
        };
        tr.absorb_fp2(b"claim", &[out]);
        out
    }
    fn a1(&mut self, tr: &mut Transcript, sl: Slice, pt: &[Fp2], v: Fp2) -> Fp2 {
        let val = self.take(tr, v);
        self.aw.push(Claim { parts: vec![(sl, Fp2::ONE)], point: pt.to_vec(), sum: false, value: val });
        val
    }
    fn w1(&mut self, tr: &mut Transcript, sl: Slice, pt: &[Fp2], v: Fp2) -> Fp2 {
        let val = self.take(tr, v);
        self.ww.push(Claim { parts: vec![(sl, Fp2::ONE)], point: pt.to_vec(), sum: false, value: val });
        val
    }
    fn h1(&mut self, tr: &mut Transcript, re: Slice, im: Slice, pt: &[Fp2], v: Fp2) -> Fp2 {
        let val = self.take(tr, v);
        self.hh.push(Claim { parts: vec![(re, Fp2::ONE), (im, Fp2::U)], point: pt.to_vec(), sum: false, value: val });
        val
    }
    fn hsum(&mut self, tr: &mut Transcript, re: Slice, im: Slice, v: Fp2) -> Fp2 {
        let val = self.take(tr, v);
        self.hh.push(Claim { parts: vec![(re, Fp2::ONE), (im, Fp2::U)], point: vec![], sum: true, value: val });
        val
    }
}


/// What a sumcheck table is, so that prover and verifier register the SAME
/// terminal claims in the SAME order.
pub enum TabDesc {
    /// a public table: the verifier computes its value at the final point
    Pub(Fp2),
    A { off: usize, log: u32, pt: Vec<Fp2> },
    W { off: usize, log: u32, pt: Vec<Fp2> },
    H { re: usize, im: usize, log: u32, pt: Vec<Fp2> },
    /// a class value reconstructed from committed limbs
    ACls { offs: Vec<usize>, log: u32, pt: Vec<Fp2>, coef: Vec<i64>, cst: i64 },
}

/// Register the terminal claims of one sumcheck and return the terminal
/// values in table order (prover: its own finals; verifier: the proof's).
fn terms(cc: &mut Cc, tr: &mut Transcript, descs: &[TabDesc], finals: &[Fp2], a: Option<&[Fp]>) -> Vec<Fp2> {
    let mut out = Vec::with_capacity(descs.len());
    for (i, d) in descs.iter().enumerate() {
        let fin = finals.get(i).copied().unwrap_or(Fp2::ZERO);
        let v = match d {
            TabDesc::Pub(v) => *v,
            TabDesc::A { off, log, pt } => cc.a1(tr, Slice { offset: *off, log_size: *log }, pt, fin),
            TabDesc::W { off, log, pt } => cc.w1(tr, Slice { offset: *off, log_size: *log }, pt, fin),
            TabDesc::H { re, im, log, pt } => cc.h1(tr, Slice { offset: *re, log_size: *log },
                                                    Slice { offset: *im, log_size: *log }, pt, fin),
            TabDesc::ACls { offs, log, pt, coef, cst } => {
                let vals = match a {
                    Some(a) => eval_slices(a, &offs.iter().map(|&o| (o, 1usize << log)).collect::<Vec<_>>(), pt),
                    None => vec![Fp2::ZERO; offs.len()],
                };
                let mut s = Fp2::from_i64(*cst);
                for (k, &o) in offs.iter().enumerate() {
                    let c = cc.a1(tr, Slice { offset: o, log_size: *log }, pt, vals[k]);
                    s = s.add(c.mul_base(Fp::from_i64(coef[k])));
                }
                s
            }
        };
        out.push(v);
    }
    out
}

/// The MLE of the causal mask [j <= t] at (rt, rj) (O(T) by prefix sums).
pub fn mask_mle(rt: &[Fp2], rj: &[Fp2]) -> Fp2 {
    let et = eq_table_msb(rt);
    let ej = eq_table_msb(rj);
    let mut acc = Fp2::ZERO;
    let mut pre = Fp2::ZERO;
    for t in 0..et.len() {
        pre = pre.add(ej[t]);
        acc = acc.add(et[t].mul(pre));
    }
    acc
}

/// The MLEs of the public RoPE coefficient tables C(t, i) = c[t][i % half]
/// and S'(t, i) = -s[t][i] (i < half) | s[t][i - half], at (rt, ri).
pub fn rope_mle(ctab: &[i64], stab: &[i64], hd: usize, rt: &[Fp2], ri: &[Fp2]) -> (Fp2, Fp2) {
    let half = hd / 2;
    let et = eq_table_msb(rt);
    let ei = eq_table_msb(ri);
    let (mut cs, mut ss) = (Fp2::ZERO, Fp2::ZERO);
    for t in 0..et.len() {
        let mut c_acc = Fp2::ZERO;
        let mut s_acc = Fp2::ZERO;
        for i in 0..hd {
            let k = t * half + i % half;
            c_acc = c_acc.add(ei[i].mul_base(Fp::from_i64(ctab[k])));
            s_acc = s_acc.add(ei[i].mul_base(Fp::from_i64(if i < half { -stab[k] } else { stab[k] })));
        }
        cs = cs.add(et[t].mul(c_acc));
        ss = ss.add(et[t].mul(s_acc));
    }
    (cs, ss)
}

/// The prover's data (the verifier runs the same argument with none of it).
pub struct ProvData<'a> {
    pub a: &'a [Fp],
    pub h: &'a [Fp],
    pub w: &'a [Fp],
    pub wit: &'a AttnWitness,
}

pub enum Side<'a> {
    Prove(ProvData<'a>),
    Verify,
}

impl<'a> Side<'a> {
    fn pd(&self) -> Option<&ProvData<'a>> {
        match self { Side::Prove(p) => Some(p), Side::Verify => None }
    }
    fn proving(&self) -> bool {
        matches!(self, Side::Prove(_))
    }
}

struct Ctx<'a> {
    side: Side<'a>,
    sc_i: usize,
}

impl<'a> Ctx<'a> {
    /// One sumcheck: the prover builds the tables and proves; the verifier
    /// replays the rounds. Returns (challenges, finals, final claim).
    fn sc<B, F>(&mut self, proof: &mut AttnProof, tr: &mut Transcript, claim: Fp2, degree: usize,
                nvars: usize, build: B, poly: F, name: &str) -> Result<(Vec<Fp2>, Vec<Fp2>, Fp2), String>
    where
        B: FnOnce() -> Vec<Vec<Fp2>>,
        F: Fn(&[Fp2]) -> Fp2 + Sync,
    {
        match self.side {
            Side::Prove(_) => {
                let mut tables = build();
                assert_eq!(tables[0].len(), 1usize << nvars, "{name}: table size");
                let out = sumcheck::prove(&mut tables, degree, poly, tr);
                let s0 = out.proof.rounds[0][0].add(out.proof.rounds[0][1]);
                assert!(s0 == claim || tamper_mode(), "[UPERF3-AG] {name}: the prover's own sum != the claim it made");
                proof.sc.push(out.proof);
                Ok((out.challenges, out.finals, Fp2::ZERO))
            }
            Side::Verify => {
                let pr = proof.sc.get(self.sc_i).ok_or_else(|| format!("{name}: missing sumcheck"))?;
                self.sc_i += 1;
                let (fin, rho) = sumcheck::verify(claim, degree, nvars, pr, tr)
                    .map_err(|e| format!("{name}: {e}"))?;
                Ok((rho, vec![], fin))
            }
        }
    }
    fn check(&self, got: Fp2, want: Fp2, what: &str) -> Result<(), String> {
        if self.side.proving() {
            assert!(got == want || tamper_mode(), "[UPERF3-AG] prover-side {what} fails");
            Ok(())
        } else if got == want {
            Ok(())
        } else {
            Err(format!("{what} fails"))
        }
    }
}


fn htab(h: &[Fp], re: usize, im: usize, len: usize) -> Vec<Fp2> {
    (0..len).into_par_iter().map(|i| Fp2::new(h[re + i], h[im + i])).collect()
}
/// B[r * cols + c] = a[off + c]
fn bcast_col(a: &[Fp], off: usize, rows: usize, cols: usize) -> Vec<Fp2> {
    let mut v = vec![Fp2::ZERO; rows * cols];
    v.par_chunks_mut(cols).for_each(|row| {
        for (c, s) in row.iter_mut().enumerate() { *s = Fp2::from_base(a[off + c]); }
    });
    v
}
/// B[r * cols + c] = a[off + r]
fn bcast_row(a: &[Fp], off: usize, rows: usize, cols: usize) -> Vec<Fp2> {
    let mut v = vec![Fp2::ZERO; rows * cols];
    v.par_chunks_mut(cols).enumerate().for_each(|(r, row)| {
        let x = Fp2::from_base(a[off + r]);
        for s in row.iter_mut() { *s = x; }
    });
    v
}
fn lookup_col(a: &[Fp], off: usize, len: usize, g: Fp2) -> Vec<Fp2> {
    a[off..off + len].par_iter().map(|v| Fp2::from_base(*v).add(g)).collect()
}
/// the causal mask table over the S domain (h, t, j)
fn mask_table(hp: usize, t: usize) -> Vec<Fp2> {
    let mut v = vec![Fp2::ZERO; hp * t * t];
    v.par_chunks_mut(t).enumerate().for_each(|(r, row)| {
        let ti = r % t;
        for (j, s) in row.iter_mut().enumerate() { *s = if j <= ti { Fp2::ONE } else { Fp2::ZERO }; }
    });
    v
}

/// The D-domain lookup list, in the order the helper columns pair it.
pub fn d_lookups(lay: &AttnLayout, c: &AttnConsts, fc: &FullConsts) -> (Vec<usize>, Vec<Tbl>) {
    let mut o = Vec::new();
    let mut t = Vec::new();
    let mut push_cls = |o: &mut Vec<usize>, t: &mut Vec<Tbl>, cp: &ClsPlane| {
        for (k, &off) in cp.offs.iter().enumerate() { o.push(off); t.push(cp.tables()[k]); }
    };
    push_cls(&mut o, &mut t, &lay.x_in);
    o.push(lay.xn8); t.push(Tbl::Int8);
    for &x in &lay.rho_a { o.push(x); t.push(Tbl::U16); }
    for &x in &lay.sig_a { o.push(x); t.push(Tbl::U16); }
    o.push(lay.xm8); t.push(Tbl::Int8);
    for &x in &lay.rho_m { o.push(x); t.push(Tbl::U16); }
    for &x in &lay.sig_m { o.push(x); t.push(Tbl::U16); }
    push_cls(&mut o, &mut t, &lay.ao);
    o.push(lay.rao); t.push(Tbl::Win(c.sh_ao));
    push_cls(&mut o, &mut t, &lay.xres1);
    o.push(lay.rr1); t.push(Tbl::Win(c.sh_r1));
    push_cls(&mut o, &mut t, &lay.xres2);
    o.push(lay.rr2); t.push(Tbl::Win(fc.sh_r2));
    o.push(lay.z16c); t.push(Tbl::Int16);
    (o, t)
}

pub fn q_lookups(lay: &AttnLayout, c: &AttnConsts) -> (Vec<usize>, Vec<Tbl>) {
    (vec![lay.q8, lay.rq, lay.qr8, lay.rqr, lay.o8, lay.ro],
     vec![Tbl::Int8, Tbl::Win(c.sh_q), Tbl::Int8, Tbl::Win(c.sh_qr), Tbl::Int8, Tbl::Win(c.sh_o)])
}
pub fn kv_lookups(lay: &AttnLayout, c: &AttnConsts) -> (Vec<usize>, Vec<Tbl>) {
    (vec![lay.k8, lay.rk, lay.v8, lay.rv, lay.kr8, lay.rkr],
     vec![Tbl::Int8, Tbl::Win(c.sh_k), Tbl::Int8, Tbl::Win(c.sh_v), Tbl::Int8, Tbl::Win(c.sh_kr)])
}

/// The number of witness rows that look into each table (the verifier's
/// shape check on the multiplicity totals).
pub fn lookup_totals(lay: &AttnLayout, c: &AttnConsts, fc: &FullConsts) -> std::collections::BTreeMap<u64, u64> {
    let mut m = std::collections::BTreeMap::new();
    let mut add = |t: Tbl, n: usize| { *m.entry(t.tag()).or_insert(0u64) += n as u64; };
    let (ld, lq, lkv, ls) = (1usize << lay.log_d, 1usize << lay.log_q, 1usize << lay.log_kv, 1usize << lay.log_s);
    for t in d_lookups(lay, c, fc).1 { add(t, ld); }
    for t in q_lookups(lay, c).1 { add(t, lq); }
    for t in kv_lookups(lay, c).1 { add(t, lkv); }
    add(Tbl::Int8, ls);            // s8
    add(Tbl::Win(c.sh_s), ls);
    add(Tbl::Exp, ls);
    add(Tbl::Prob, ls);
    add(Tbl::Srem(c.wrho_s), 2 * ls);   // rho and sigma
    add(Tbl::U16, 1usize << lay.log_lm); // the packed a1/a2 limb slice (its zero tail included)
    m
}

/// Build every helper column into a fresh H vector.
pub fn build_helpers(a: &[Fp], lay: &AttnLayout, c: &AttnConsts, fc: &FullConsts,
                     alpha: Fp2, beta: Fp2, gamma: Fp2) -> Vec<Fp> {
    let mut h = vec![Fp::ZERO; lay.h_len];
    let g = |t: Tbl| gamma.mul_base(Fp::new(t.tag()));
    let mut put = |h: &mut Vec<Fp>, (re, im): (usize, usize), col: Vec<Fp2>| {
        let n = col.len();
        h[re..re + n].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c0);
        h[im..im + n].par_iter_mut().zip(col.par_iter()).for_each(|(o, v)| *o = v.c1);
    };
    for (offs, tbls, hs, len) in [
        (d_lookups(lay, c, fc), lay.h_d.clone(), 1usize << lay.log_d),
        (q_lookups(lay, c), lay.h_q.clone(), 1usize << lay.log_q),
        (kv_lookups(lay, c), lay.h_kv.clone(), 1usize << lay.log_kv),
    ].map(|((o, t), hs, len)| (o, t, hs, len)) {
        for (j, pair) in hs.iter().enumerate() {
            let l1 = lookup_col(a, offs[2 * j], len, g(tbls[2 * j]));
            let col = if 2 * j + 1 < offs.len() {
                let l2 = lookup_col(a, offs[2 * j + 1], len, g(tbls[2 * j + 1]));
                helper_col(&l1, Some(&l2), alpha)
            } else {
                helper_col(&l1, None, alpha)
            };
            put(&mut h, *pair, col);
        }
    }
    // ---- the softmax domain: the fused exp row and the derived sigma ----
    let (hp, t) = (lay.p.hp, lay.p.t);
    let ls = hp * t * t;
    let (g_i8, g_win, g_exp, g_prob, g_srem) =
        (g(Tbl::Int8), g(Tbl::Win(c.sh_s)), g(Tbl::Exp), g(Tbl::Prob), g(Tbl::Srem(c.wrho_s)));
    {
        let l1 = lookup_col(a, lay.s8, ls, g_i8);
        let l2 = lookup_col(a, lay.rs, ls, g_win);
        put(&mut h, lay.h_s[0], helper_col(&l1, Some(&l2), alpha));
    }
    {
        let m127 = Fp::from_i64(-127);
        let mut l1 = vec![Fp2::ZERO; ls];
        l1.par_chunks_mut(t).enumerate().for_each(|(r, row)| {
            let ti = r % t;
            let mv = Fp2::from_base(a[lay.sm_m() + r]);
            for (j, s) in row.iter_mut().enumerate() {
                let sm = if j <= ti { a[lay.s8 + r * t + j] } else { m127 };
                let dd = mv.sub(Fp2::from_base(sm));
                *s = dd.add(beta.mul_base(a[lay.et + r * t + j])).add(g_exp);
            }
        });
        let l2 = lookup_col(a, lay.pp, ls, g_prob);
        put(&mut h, lay.h_s[1], helper_col(&l1, Some(&l2), alpha));
    }
    {
        let l1 = lookup_col(a, lay.rho_s, ls, g_srem);
        let mut l2 = vec![Fp2::ZERO; ls];
        l2.par_chunks_mut(t).enumerate().for_each(|(r, row)| {
            let sv = Fp2::from_base(a[lay.sm_sum() + r]).sub(Fp2::ONE);
            for (j, s) in row.iter_mut().enumerate() {
                *s = sv.sub(Fp2::from_base(a[lay.rho_s + r * t + j])).add(g_srem);
            }
        });
        put(&mut h, lay.h_s[2], helper_col(&l1, Some(&l2), alpha));
    }
    // ---- the packed limb slice: its two halves pair into one column ----
    {
        let half = 1usize << (lay.log_lm - 1);
        let l1 = lookup_col(a, lay.lm, half, g(Tbl::U16));
        let l2 = lookup_col(a, lay.lm + half, half, g(Tbl::U16));
        put(&mut h, lay.h_lm, helper_col(&l1, Some(&l2), alpha));
    }
    h
}



fn claim_at(cc: &mut Cc, tr: &mut Transcript, a: Option<&[Fp]>, off: usize, log: u32, pt: &[Fp2]) -> Fp2 {
    let v = a.map(|a| eval_slices(a, &[(off, 1usize << log)], pt)[0]).unwrap_or(Fp2::ZERO);
    cc.a1(tr, Slice { offset: off, log_size: log }, pt, v)
}

/// C(t, i) = c[t][i % half] broadcast over the head axis of a (t, h, i) domain.
fn rope_c_table(ctab: &[i64], len: usize, width: usize, hd: usize) -> Vec<Fp2> {
    let half = hd / 2;
    let mut v = vec![Fp2::ZERO; len];
    v.par_chunks_mut(width).enumerate().for_each(|(ti, row)| {
        for (cidx, s) in row.iter_mut().enumerate() {
            *s = Fp2::from_i64(ctab[ti * half + (cidx % hd) % half]);
        }
    });
    v
}
/// S'(t, i) = -s[t][i] for i < half, +s[t][i - half] otherwise.
fn rope_s_table(stab: &[i64], len: usize, width: usize, hd: usize) -> Vec<Fp2> {
    let half = hd / 2;
    let mut v = vec![Fp2::ZERO; len];
    v.par_chunks_mut(width).enumerate().for_each(|(ti, row)| {
        for (cidx, s) in row.iter_mut().enumerate() {
            let i = cidx % hd;
            let x = stab[ti * half + i % half];
            *s = Fp2::from_i64(if i < half { -x } else { x });
        }
    });
    v
}

/// The table a tag names (the statement's table set).
pub fn tbl_of_tag(tag: u64, c: &AttnConsts, fc: &FullConsts, lay: &AttnLayout) -> Option<Tbl> {
    let mut all: Vec<Tbl> = d_lookups(lay, c, fc).1;
    all.extend(q_lookups(lay, c).1);
    all.extend(kv_lookups(lay, c).1);
    all.extend([Tbl::Int8, Tbl::Win(c.sh_s), Tbl::Exp, Tbl::Prob, Tbl::Srem(c.wrho_s), Tbl::U16]);
    all.into_iter().find(|t| t.tag() == tag)
}

fn recon_table(a: &[Fp], cp: &ClsPlane, len: usize) -> Vec<Fp2> {
    match cp.cls {
        Cls::Int24 => {
            let (o0, o1) = (cp.offs[0], cp.offs[1]);
            let c1 = Fp::new(1 << 16);
            let k = Fp2::from_i64(-(1 << 23));
            (0..len).into_par_iter()
                .map(|i| Fp2::from_base(a[o0 + i]).add(Fp2::from_base(a[o1 + i]).mul_base(c1)).add(k))
                .collect()
        }
        _ => tab2(a, cp.offs[0], len),
    }
}

fn claim_sub(cc: &mut Cc, tr: &mut Transcript, a: Option<&[Fp]>, base: usize, base_log: u32,
             off: usize, sub_log: u32, r: &[Fp2]) -> Fp2 {
    let v = a.map(|a| eval_slices(a, &[(off, 1usize << sub_log)], r)[0]).unwrap_or(Fp2::ZERO);
    let pt = sub_point(base, base_log, off, sub_log, r);
    cc.a1(tr, Slice { offset: base, log_size: base_log }, &pt, v)
}

/// [UPERF3-AG] THE ARGUMENT: the same code drives the prover and the
/// verifier (`Side`), so the claim list, the sumcheck order and every
/// public value are shared by construction.
#[allow(clippy::too_many_arguments)]
pub fn attn_argument(side: Side, lay: &AttnLayout, c: &AttnConsts, fc: &FullConsts,
                     alpha: Fp2, beta: Fp2, gamma: Fp2, proof: &mut AttnProof,
                     tr: &mut Transcript) -> Result<Cc, String> {
    let proving = side.proving();
    let (adat, hdat, wdat) = match &side {
        Side::Prove(p) => (Some(p.a), Some(p.h), Some(p.w)),
        Side::Verify => (None, None, None),
    };
    let mut ctx = Ctx { side, sc_i: 0 };
    let mut cc = Cc::new(proving, if proving { Vec::new() } else { proof.vals.clone() });
    let p = lay.p;
    let (t, dp, hp, qp, vp, hdim) = (p.t, p.dp, p.hp, p.qp, p.vp, p.hd);
    let (ld, lq, lkv, ls) = (1usize << lay.log_d, 1usize << lay.log_q, 1usize << lay.log_kv, 1usize << lay.log_s);
    let g = |x: Tbl| gamma.mul_base(Fp::new(x.tag()));
    let pow2 = |k: u32| Fp::new(1u64 << k);
    // the PUBLIC members, regenerated from their keys and digest-checked
    let (exp, e_dig) = crate::tables_attn::exp_member(c.e_s_raw, hdim, c.f_e);
    if e_dig != c.exp_digest { return Err("exp member digest".into()); }
    let (ctab, stab) = crate::tables_attn::rope_tables_generate(t, hdim, c.rope_base, c.f_ro);
    if crate::tables_attn::rope_digest(t, hdim, c.rope_base, c.f_ro, &ctab, &stab) != c.rope_digest {
        return Err("rope table digest".into());
    }

    // ===== 1. the isqrt row facts at one point + the two SS row sums =====
    let r_t = tr.challenge_fp2_vec(lay.log_t as usize);
    let mut ss = Vec::new();
    for site in 0..2 {
        let dd = claim_sub(&mut cc, tr, adat, lay.sm, lay.log_sm, lay.sm_row(site, 0), lay.log_t, &r_t);
        let dsq = claim_sub(&mut cc, tr, adat, lay.sm, lay.log_sm, lay.sm_row(site, 1), lay.log_t, &r_t);
        let a1 = claim_sub(&mut cc, tr, adat, lay.sm, lay.log_sm, lay.sm_row(site, 2), lay.log_t, &r_t);
        let a2 = claim_sub(&mut cc, tr, adat, lay.sm, lay.log_sm, lay.sm_row(site, 3), lay.log_t, &r_t);
        let l: Vec<Fp2> = (0..4)
            .map(|k| claim_sub(&mut cc, tr, adat, lay.lm, lay.log_lm, lay.lm_row(site, k), lay.log_t, &r_t))
            .collect();
        ctx.check(a2, dd.mul_base(pow2(1)).sub(a1), "isqrt: a2 = 2D - a1")?;
        ctx.check(a1, l[0].add(l[1].mul_base(pow2(16))), "isqrt: a1 limbs")?;
        ctx.check(a2, l[2].add(l[3].mul_base(pow2(16))), "isqrt: a2 limbs")?;
        let ceps = if site == 0 { c.anorm.ceps } else { c.mnorm.ceps };
        ss.push(a1.add(dsq).sub(Fp2::from_i64(ceps)));
    }
    let lam_ss = tr.challenge_fp2();
    let poly_ss = |v: &[Fp2]| v[0].mul(v[1].mul(v[1]).add(lam_ss.mul(v[2].mul(v[2]))));
    let (rho, fin, cl) = ctx.sc(proof, tr, ss[0].add(lam_ss.mul(ss[1])), 3, lay.log_d as usize, || {
        let a = adat.unwrap();
        let eqt = eq_table_msb(&r_t);
        let mut b = vec![Fp2::ZERO; ld];
        b.par_chunks_mut(dp).enumerate().for_each(|(r, row)| { for s in row.iter_mut() { *s = eqt[r]; } });
        vec![b, recon_table(a, &lay.x_in, ld), recon_table(a, &lay.xres1, ld)]
    }, &poly_ss, "SS row sums")?;
    {
        let d = vec![
            TabDesc::Pub(eq_point(&r_t, &rho[..lay.log_t as usize])),
            TabDesc::ACls { offs: lay.x_in.offs.clone(), log: lay.log_d, pt: rho.clone(),
                            coef: lay.x_in.recon().0, cst: lay.x_in.recon().1 },
            TabDesc::ACls { offs: lay.xres1.offs.clone(), log: lay.log_d, pt: rho.clone(),
                            coef: lay.xres1.recon().0, cst: lay.xres1.recon().1 },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_ss(&v), cl, "SS row sums terminal")?; }
    }

    // ===== 2. Dsq = D D at both norm sites =====
    let tau1 = tr.challenge_fp2_vec(lay.log_t as usize);
    let mu1 = tr.challenge_fp2_vec(2);
    let poly_sq = |v: &[Fp2]| v[0].mul(mu1[0].mul(v[2].sub(v[1].mul(v[1]))).add(mu1[1].mul(v[4].sub(v[3].mul(v[3])))));
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 3, lay.log_t as usize, || {
        let a = adat.unwrap();
        vec![eq_table_msb(&tau1),
             tab2(a, lay.sm_row(0, 0), t), tab2(a, lay.sm_row(0, 1), t),
             tab2(a, lay.sm_row(1, 0), t), tab2(a, lay.sm_row(1, 1), t)]
    }, &poly_sq, "D^2")?;
    {
        let mut d = vec![TabDesc::Pub(eq_point(&tau1, &rho))];
        for site in 0..2 {
            for k in 0..2 {
                d.push(TabDesc::A { off: lay.sm, log: lay.log_sm,
                                    pt: sub_point(lay.sm, lay.log_sm, lay.sm_row(site, k), lay.log_t, &rho) });
            }
        }
        // the prover's finals are the SUB-BLOCK values; the claims are on the packed slice
        let fin2: Vec<Fp2> = fin.clone();
        let v = terms(&mut cc, tr, &d, &fin2, adat);
        if !proving { ctx.check(poly_sq(&v), cl, "D^2 terminal")?; }
    }

    // ===== 3. the D-domain zero-check =====
    let (d_offs, d_tbl) = d_lookups(lay, c, fc);
    let n_lk = d_offs.len();
    let pos = |off: usize| 1 + d_offs.iter().position(|&x| x == off).unwrap();
    let (i_ga, i_gm, i_da, i_dm) = (1 + n_lk, 2 + n_lk, 3 + n_lk, 4 + n_lk);
    let i_h0 = 5 + n_lk;
    let tau_d = tr.challenge_fp2_vec(lay.log_d as usize);
    let mu_d = tr.challenge_fp2_vec(lay.h_d.len() + 2);
    let rc = |cp: &ClsPlane| -> Recon {
        let (coef, off) = cp.recon();
        Recon { idx: cp.offs.iter().map(|&o| pos(o)).collect(), coef, off }
    };
    let rlimb = |offs: &[usize]| -> Recon {
        Recon { idx: offs.iter().map(|&o| pos(o)).collect(),
                coef: (0..offs.len()).map(|k| 1i64 << (16 * k)).collect(), off: 0 }
    };
    let plan_d = ZcPlan {
        alpha,
        pairs: (0..lay.h_d.len()).map(|j| {
            let l2 = if 2 * j + 1 < n_lk { Some((1 + 2 * j + 1, g(d_tbl[2 * j + 1]))) } else { None };
            (1 + 2 * j, g(d_tbl[2 * j]), l2, i_h0 + j)
        }).collect(),
        extras: vec![
            Extra::NormDiv { y: pos(lay.xn8), rho: rlimb(&lay.rho_a), x: rc(&lay.x_in), g: i_ga,
                             dd: i_da, tn: c.anorm.tn, cn: c.anorm.cn },
            Extra::NormDiv { y: pos(lay.xm8), rho: rlimb(&lay.rho_m), x: rc(&lay.xres1), g: i_gm,
                             dd: i_dm, tn: c.mnorm.tn, cn: c.mnorm.cn },
        ],
        mu: mu_d,
        eq_idx: 0,
    };
    let poly_d = |v: &[Fp2]| plan_d.eval(v);
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 4, lay.log_d as usize, || {
        let (a, h, w) = (adat.unwrap(), hdat.unwrap(), wdat.unwrap());
        let mut tb = vec![eq_table_msb(&tau_d)];
        for &o in &d_offs { tb.push(tab2(a, o, ld)); }
        tb.push(bcast_col(w, lay.gpack, t, dp));
        tb.push(bcast_col(w, lay.gpack + dp, t, dp));
        tb.push(bcast_row(a, lay.sm_row(0, 0), t, dp));
        tb.push(bcast_row(a, lay.sm_row(1, 0), t, dp));
        for (re, im) in &lay.h_d { tb.push(htab(h, *re, *im, ld)); }
        tb
    }, &poly_d, "zero-check D")?;
    let vd = {
        let (rt, ri) = (&rho[..lay.log_t as usize], &rho[lay.log_t as usize..]);
        let mut d = vec![TabDesc::Pub(eq_point(&tau_d, &rho))];
        for &o in &d_offs { d.push(TabDesc::A { off: o, log: lay.log_d, pt: rho.clone() }); }
        d.push(TabDesc::W { off: lay.gpack, log: lay.log_gp,
                            pt: sub_point(lay.gpack, lay.log_gp, lay.gpack, lay.log_dp, ri) });
        d.push(TabDesc::W { off: lay.gpack, log: lay.log_gp,
                            pt: sub_point(lay.gpack, lay.log_gp, lay.gpack + dp, lay.log_dp, ri) });
        d.push(TabDesc::A { off: lay.sm, log: lay.log_sm,
                            pt: sub_point(lay.sm, lay.log_sm, lay.sm_row(0, 0), lay.log_t, rt) });
        d.push(TabDesc::A { off: lay.sm, log: lay.log_sm,
                            pt: sub_point(lay.sm, lay.log_sm, lay.sm_row(1, 0), lay.log_t, rt) });
        for (re, im) in &lay.h_d { d.push(TabDesc::H { re: *re, im: *im, log: lay.log_d, pt: rho.clone() }); }
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(plan_d.eval(&v), cl, "zero-check D terminal")?; }
        v
    };
    // the POINTWISE-LINEAR relations of the D domain, on the claimed values
    {
        let val = |r: &Recon| r.eval(&vd);
        for (site, (rho_o, sig_o, tn, i_d)) in [
            (0usize, (&lay.rho_a, &lay.sig_a, c.anorm.tn, i_da)),
            (1, (&lay.rho_m, &lay.sig_m, c.mnorm.tn, i_dm)),
        ] {
            let _ = site;
            let two_div = vd[i_d].mul_base(pow2(tn + 1));
            let s = val(&rlimb(sig_o)).add(val(&rlimb(rho_o))).add(Fp2::ONE);
            ctx.check(s, two_div, "norm: sigma = 2 div - 1 - rho")?;
        }
        let x = val(&rc(&lay.x_in));
        let ao = val(&rc(&lay.ao));
        let r1 = val(&rc(&lay.xres1));
        let r2v = val(&rc(&lay.xres2));
        let lhs1 = r1.mul_base(crate::layer::pow2_signed(c.sh_r1)).add(vd[pos(lay.rr1)]);
        ctx.check(lhs1, x.mul_base(pow2(c.sh_x1)).add(ao.mul_base(pow2(c.sh_a1))), "residual pin 1")?;
        let lhs2 = r2v.mul_base(crate::layer::pow2_signed(fc.sh_r2)).add(vd[pos(lay.rr2)]);
        ctx.check(lhs2, r1.mul_base(pow2(fc.sh_x2)).add(vd[pos(lay.z16c)].mul_base(pow2(fc.sh_z2))),
                  "residual pin 2")?;
    }
    // ===== 4. the Q-domain zero-check (lookups + the RoPE rotation) =====
    let (q_offs, q_tbl) = q_lookups(lay, c);
    let tau_q = tr.challenge_fp2_vec(lay.log_q as usize);
    let mu_q = tr.challenge_fp2_vec(4);
    let plan_q = ZcPlan {
        alpha,
        pairs: (0..3).map(|j| (1 + 2 * j, g(q_tbl[2 * j]), Some((2 + 2 * j, g(q_tbl[2 * j + 1]))), 10 + j)).collect(),
        extras: vec![Extra::Rope { y: 3, r: 4, src: 1, srcf: 7, ct: 8, st: 9, sh: c.sh_qr }],
        mu: mu_q,
        eq_idx: 0,
    };
    let poly_q = |v: &[Fp2]| plan_q.eval(v);
    let flip_bit_q = (lay.log_t + lay.log_hp) as usize;
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 4, lay.log_q as usize, || {
        let (a, h) = (adat.unwrap(), hdat.unwrap());
        let mut tb = vec![eq_table_msb(&tau_q)];
        for &o in &q_offs { tb.push(tab2(a, o, lq)); }
        let half = hdim / 2;
        tb.push((0..lq).into_par_iter().map(|i| Fp2::from_base(a[lay.q8 + (i ^ half)])).collect());
        tb.push(rope_c_table(&ctab, lq, qp, hdim));
        tb.push(rope_s_table(&stab, lq, qp, hdim));
        for (re, im) in &lay.h_q { tb.push(htab(h, *re, *im, lq)); }
        tb
    }, &poly_q, "zero-check Q")?;
    {
        let (rt, ri) = (&rho[..lay.log_t as usize], &rho[flip_bit_q..]);
        let (cv, sv) = rope_mle(&ctab, &stab, hdim, rt, ri);
        let mut fl = rho.clone();
        fl[flip_bit_q] = Fp2::ONE.sub(fl[flip_bit_q]);
        let mut d = vec![TabDesc::Pub(eq_point(&tau_q, &rho))];
        for &o in &q_offs { d.push(TabDesc::A { off: o, log: lay.log_q, pt: rho.clone() }); }
        d.push(TabDesc::A { off: lay.q8, log: lay.log_q, pt: fl });
        d.push(TabDesc::Pub(cv));
        d.push(TabDesc::Pub(sv));
        for (re, im) in &lay.h_q { d.push(TabDesc::H { re: *re, im: *im, log: lay.log_q, pt: rho.clone() }); }
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(plan_q.eval(&v), cl, "zero-check Q terminal")?; }
    }

    // ===== 5. the KV-domain zero-check =====
    let (kv_offs, kv_tbl) = kv_lookups(lay, c);
    let tau_kv = tr.challenge_fp2_vec(lay.log_kv as usize);
    let mu_kv = tr.challenge_fp2_vec(4);
    let plan_kv = ZcPlan {
        alpha,
        pairs: (0..3).map(|j| (1 + 2 * j, g(kv_tbl[2 * j]), Some((2 + 2 * j, g(kv_tbl[2 * j + 1]))), 10 + j)).collect(),
        extras: vec![Extra::Rope { y: 5, r: 6, src: 1, srcf: 7, ct: 8, st: 9, sh: c.sh_kr }],
        mu: mu_kv,
        eq_idx: 0,
    };
    let poly_kv = |v: &[Fp2]| plan_kv.eval(v);
    let flip_bit_kv = (lay.log_t + lay.log_kp) as usize;
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 4, lay.log_kv as usize, || {
        let (a, h) = (adat.unwrap(), hdat.unwrap());
        let mut tb = vec![eq_table_msb(&tau_kv)];
        for &o in &kv_offs { tb.push(tab2(a, o, lkv)); }
        let half = hdim / 2;
        tb.push((0..lkv).into_par_iter().map(|i| Fp2::from_base(a[lay.k8 + (i ^ half)])).collect());
        tb.push(rope_c_table(&ctab, lkv, vp, hdim));
        tb.push(rope_s_table(&stab, lkv, vp, hdim));
        for (re, im) in &lay.h_kv { tb.push(htab(h, *re, *im, lkv)); }
        tb
    }, &poly_kv, "zero-check KV")?;
    {
        let (rt, ri) = (&rho[..lay.log_t as usize], &rho[flip_bit_kv..]);
        let (cv, sv) = rope_mle(&ctab, &stab, hdim, rt, ri);
        let mut fl = rho.clone();
        fl[flip_bit_kv] = Fp2::ONE.sub(fl[flip_bit_kv]);
        let mut d = vec![TabDesc::Pub(eq_point(&tau_kv, &rho))];
        for &o in &kv_offs { d.push(TabDesc::A { off: o, log: lay.log_kv, pt: rho.clone() }); }
        d.push(TabDesc::A { off: lay.k8, log: lay.log_kv, pt: fl });
        d.push(TabDesc::Pub(cv));
        d.push(TabDesc::Pub(sv));
        for (re, im) in &lay.h_kv { d.push(TabDesc::H { re: *re, im: *im, log: lay.log_kv, pt: rho.clone() }); }
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(plan_kv.eval(&v), cl, "zero-check KV terminal")?; }
    }

    // ===== 6. the softmax zero-check =====
    let tau_s = tr.challenge_fp2_vec(lay.log_s as usize);
    let mu_s = tr.challenge_fp2_vec(6);
    let splan = SPlan { alpha, beta, g_int8: g(Tbl::Int8), g_win: g(Tbl::Win(c.sh_s)), g_exp: g(Tbl::Exp),
                        g_prob: g(Tbl::Prob), g_srem: g(Tbl::Srem(c.wrho_s)), mu: mu_s, f_p: c.f_p };
    let poly_s = |v: &[Fp2]| splan.eval(v);
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 5, lay.log_s as usize, || {
        let (a, h) = (adat.unwrap(), hdat.unwrap());
        vec![eq_table_msb(&tau_s),
             tab2(a, lay.s8, ls), tab2(a, lay.rs, ls), tab2(a, lay.zsel, ls),
             tab2(a, lay.et, ls), tab2(a, lay.pp, ls), tab2(a, lay.rho_s, ls),
             bcast_row(a, lay.sm_m(), hp * t, t), bcast_row(a, lay.sm_sum(), hp * t, t),
             mask_table(hp, t),
             htab(h, lay.h_s[0].0, lay.h_s[0].1, ls),
             htab(h, lay.h_s[1].0, lay.h_s[1].1, ls),
             htab(h, lay.h_s[2].0, lay.h_s[2].1, ls)]
    }, &poly_s, "zero-check S")?;
    {
        let n_ht = (lay.log_hp + lay.log_t) as usize;
        let pt_ht = &rho[..n_ht];
        let d = vec![
            TabDesc::Pub(eq_point(&tau_s, &rho)),
            TabDesc::A { off: lay.s8, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.rs, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.zsel, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.et, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.pp, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.rho_s, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.sm, log: lay.log_sm,
                         pt: sub_point(lay.sm, lay.log_sm, lay.sm_m(), n_ht as u32, pt_ht) },
            TabDesc::A { off: lay.sm, log: lay.log_sm,
                         pt: sub_point(lay.sm, lay.log_sm, lay.sm_sum(), n_ht as u32, pt_ht) },
            TabDesc::Pub(mask_mle(&rho[lay.log_hp as usize..n_ht], &rho[n_ht..])),
            TabDesc::H { re: lay.h_s[0].0, im: lay.h_s[0].1, log: lay.log_s, pt: rho.clone() },
            TabDesc::H { re: lay.h_s[1].0, im: lay.h_s[1].1, log: lay.log_s, pt: rho.clone() },
            TabDesc::H { re: lay.h_s[2].0, im: lay.h_s[2].1, log: lay.log_s, pt: rho.clone() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(splan.eval(&v), cl, "zero-check S terminal")?; }
    }

    // ===== 7. the masked row sums (Sum) batched with sum_j zsel = 1 =====
    let p_ht = tr.challenge_fp2_vec((lay.log_hp + lay.log_t) as usize);
    let sum_cl = claim_sub(&mut cc, tr, adat, lay.sm, lay.log_sm, lay.sm_sum(),
                           lay.log_hp + lay.log_t, &p_ht);
    let lam_z = tr.challenge_fp2();
    let poly_r = |v: &[Fp2]| v[0].mul(v[1].mul(v[2]).add(lam_z.mul(v[3])));
    let (rho, fin, cl) = ctx.sc(proof, tr, sum_cl.add(lam_z), 3, lay.log_s as usize, || {
        let a = adat.unwrap();
        let eq = eq_table_msb(&p_ht);
        let mut b = vec![Fp2::ZERO; ls];
        b.par_chunks_mut(t).enumerate().for_each(|(r, row)| { for s in row.iter_mut() { *s = eq[r]; } });
        vec![b, mask_table(hp, t), tab2(a, lay.et, ls), tab2(a, lay.zsel, ls)]
    }, &poly_r, "row sums")?;
    {
        let n_ht = (lay.log_hp + lay.log_t) as usize;
        let d = vec![
            TabDesc::Pub(eq_point(&p_ht, &rho[..n_ht])),
            TabDesc::Pub(mask_mle(&rho[lay.log_hp as usize..n_ht], &rho[n_ht..])),
            TabDesc::A { off: lay.et, log: lay.log_s, pt: rho.clone() },
            TabDesc::A { off: lay.zsel, log: lay.log_s, pt: rho.clone() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_r(&v), cl, "row sums terminal")?; }
    }

    // ===== 8. the packed limb slice's helper zero-check =====
    let tau_l = tr.challenge_fp2_vec((lay.log_lm - 1) as usize);
    let mu_l = tr.challenge_fp2_vec(1);
    let plan_l = ZcPlan { alpha, pairs: vec![(1, g(Tbl::U16), Some((2, g(Tbl::U16))), 3)],
                          extras: vec![], mu: mu_l, eq_idx: 0 };
    let poly_l = |v: &[Fp2]| plan_l.eval(v);
    let half_lm = 1usize << (lay.log_lm - 1);
    let (rho, fin, cl) = ctx.sc(proof, tr, Fp2::ZERO, 4, (lay.log_lm - 1) as usize, || {
        let (a, h) = (adat.unwrap(), hdat.unwrap());
        vec![eq_table_msb(&tau_l), tab2(a, lay.lm, half_lm), tab2(a, lay.lm + half_lm, half_lm),
             htab(h, lay.h_lm.0, lay.h_lm.1, half_lm)]
    }, &poly_l, "zero-check LM")?;
    {
        let d = vec![
            TabDesc::Pub(eq_point(&tau_l, &rho)),
            TabDesc::A { off: lay.lm, log: lay.log_lm,
                         pt: sub_point(lay.lm, lay.log_lm, lay.lm, lay.log_lm - 1, &rho) },
            TabDesc::A { off: lay.lm, log: lay.log_lm,
                         pt: sub_point(lay.lm, lay.log_lm, lay.lm + half_lm, lay.log_lm - 1, &rho) },
            TabDesc::H { re: lay.h_lm.0, im: lay.h_lm.1, log: lay.log_lm - 1, pt: rho.clone() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(plan_l.eval(&v), cl, "zero-check LM terminal")?; }
    }

    // ===== 9. the QKV matmul (one sumcheck over the inner d) =====
    let rq_t = tr.challenge_fp2_vec(lay.log_t as usize);
    let r_jq = tr.challenge_fp2_vec(lay.log_qp as usize);
    let r_jk = tr.challenge_fp2_vec(lay.log_vp as usize);
    let r_jv = tr.challenge_fp2_vec(lay.log_vp as usize);
    let (lam_k, lam_v) = (tr.challenge_fp2(), tr.challenge_fp2());
    let pq: Vec<Fp2> = [rq_t.clone(), r_jq.clone()].concat();
    let pk: Vec<Fp2> = [rq_t.clone(), r_jk.clone()].concat();
    let pv2: Vec<Fp2> = [rq_t.clone(), r_jv.clone()].concat();
    let cq = claim_at(&mut cc, tr, adat, lay.q8, lay.log_q, &pq);
    let crq = claim_at(&mut cc, tr, adat, lay.rq, lay.log_q, &pq);
    let ck = claim_at(&mut cc, tr, adat, lay.k8, lay.log_kv, &pk);
    let crk = claim_at(&mut cc, tr, adat, lay.rk, lay.log_kv, &pk);
    let cv = claim_at(&mut cc, tr, adat, lay.v8, lay.log_kv, &pv2);
    let crv = claim_at(&mut cc, tr, adat, lay.rv, lay.log_kv, &pv2);
    let acc_q = cq.mul_base(crate::layer::pow2_signed(c.sh_q)).add(crq);
    let acc_k = ck.mul_base(crate::layer::pow2_signed(c.sh_k)).add(crk);
    let acc_v = cv.mul_base(crate::layer::pow2_signed(c.sh_v)).add(crv);
    let poly_m = |v: &[Fp2]| v[0].mul(v[1].add(lam_k.mul(v[2])).add(lam_v.mul(v[3])));
    let (rho, fin, cl) = ctx.sc(proof, tr, acc_q.add(lam_k.mul(acc_k)).add(lam_v.mul(acc_v)), 2,
                                lay.log_dp as usize, || {
        let (a, w) = (adat.unwrap(), wdat.unwrap());
        let eqt = eq_table_msb(&rq_t);
        vec![crate::mle::fold_rows_base(&a[lay.xn8..lay.xn8 + ld], t, dp, &eqt),
             crate::mle::fold_cols_base(&w[lay.wq..lay.wq + dp * qp], dp, qp, &eq_table_msb(&r_jq)),
             crate::mle::fold_cols_base(&w[lay.wk..lay.wk + dp * vp], dp, vp, &eq_table_msb(&r_jk)),
             crate::mle::fold_cols_base(&w[lay.wv..lay.wv + dp * vp], dp, vp, &eq_table_msb(&r_jv))]
    }, &poly_m, "QKV matmul")?;
    {
        let d = vec![
            TabDesc::A { off: lay.xn8, log: lay.log_d, pt: [rq_t.clone(), rho.clone()].concat() },
            TabDesc::W { off: lay.wq, log: lay.log_wq, pt: [rho.clone(), r_jq.clone()].concat() },
            TabDesc::W { off: lay.wk, log: lay.log_wkv, pt: [rho.clone(), r_jk.clone()].concat() },
            TabDesc::W { off: lay.wv, log: lay.log_wkv, pt: [rho.clone(), r_jv.clone()].concat() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_m(&v), cl, "QKV matmul terminal")?; }
    }

    // ===== 10. the per-head score matmul (the GQA map is free) =====
    let p_s = tr.challenge_fp2_vec(lay.log_s as usize);
    let cs8 = claim_at(&mut cc, tr, adat, lay.s8, lay.log_s, &p_s);
    let crs = claim_at(&mut cc, tr, adat, lay.rs, lay.log_s, &p_s);
    let (r_sh, r_st, r_sj) = (&p_s[..lay.log_hp as usize],
                              &p_s[lay.log_hp as usize..(lay.log_hp + lay.log_t) as usize],
                              &p_s[(lay.log_hp + lay.log_t) as usize..]);
    let (r_hi, r_lo) = (&r_sh[..lay.log_kp as usize], &r_sh[lay.log_kp as usize..]);
    let poly_3 = |v: &[Fp2]| v[0].mul(v[1]).mul(v[2]);
    let (rho, fin, cl) = ctx.sc(proof, tr, cs8.mul_base(crate::layer::pow2_signed(c.sh_s)).add(crs), 3,
                                (lay.log_kp + lay.log_hd) as usize, || {
        let a = adat.unwrap();
        let (eg, et, el, ej) = (eq_table_msb(r_hi), eq_table_msb(r_st), eq_table_msb(r_lo), eq_table_msb(r_sj));
        let kpn = p.kp;
        let mut eg_t = vec![Fp2::ZERO; kpn * hdim];
        eg_t.par_chunks_mut(hdim).enumerate().for_each(|(gi, row)| { for s in row.iter_mut() { *s = eg[gi]; } });
        let mut af = vec![Fp2::ZERO; kpn * hdim];
        af.par_chunks_mut(hdim).enumerate().for_each(|(gi, row)| {
            for (l, ev) in el.iter().enumerate() {
                let hs = gi * p.rep_p + l;
                for ti in 0..t {
                    let w = et[ti].mul(*ev);
                    if w.is_zero() { continue; }
                    let base = lay.qr8 + ti * qp + hs * hdim;
                    for (i, s) in row.iter_mut().enumerate() { *s = s.add(w.mul_base(a[base + i])); }
                }
            }
        });
        let mut kf = vec![Fp2::ZERO; kpn * hdim];
        kf.par_chunks_mut(hdim).enumerate().for_each(|(gi, row)| {
            for j in 0..t {
                let w = ej[j];
                if w.is_zero() { continue; }
                let base = lay.kr8 + j * vp + gi * hdim;
                for (i, s) in row.iter_mut().enumerate() { *s = s.add(w.mul_base(a[base + i])); }
            }
        });
        vec![eg_t, af, kf]
    }, &poly_3, "score matmul")?;
    {
        let (rg, ri) = (&rho[..lay.log_kp as usize], &rho[lay.log_kp as usize..]);
        let d = vec![
            TabDesc::Pub(eq_point(r_hi, rg)),
            TabDesc::A { off: lay.qr8, log: lay.log_q,
                         pt: [r_st.to_vec(), rg.to_vec(), r_lo.to_vec(), ri.to_vec()].concat() },
            TabDesc::A { off: lay.kr8, log: lay.log_kv,
                         pt: [r_sj.to_vec(), rg.to_vec(), ri.to_vec()].concat() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_3(&v), cl, "score matmul terminal")?; }
    }

    // ===== 11. the PV matmul =====
    let p_o = tr.challenge_fp2_vec(lay.log_q as usize);
    let co8 = claim_at(&mut cc, tr, adat, lay.o8, lay.log_q, &p_o);
    let cro = claim_at(&mut cc, tr, adat, lay.ro, lay.log_q, &p_o);
    let (r_ot, r_oh, r_oi) = (&p_o[..lay.log_t as usize],
                              &p_o[lay.log_t as usize..(lay.log_t + lay.log_hp) as usize],
                              &p_o[(lay.log_t + lay.log_hp) as usize..]);
    let (r_ohi, r_olo) = (&r_oh[..lay.log_kp as usize], &r_oh[lay.log_kp as usize..]);
    let (rho, fin, cl) = ctx.sc(proof, tr, co8.mul_base(crate::layer::pow2_signed(c.sh_o)).add(cro), 3,
                                (lay.log_kp + lay.log_t) as usize, || {
        let a = adat.unwrap();
        let (eg, et, el, ei) = (eq_table_msb(r_ohi), eq_table_msb(r_ot), eq_table_msb(r_olo), eq_table_msb(r_oi));
        let kpn = p.kp;
        let mut eg_t = vec![Fp2::ZERO; kpn * t];
        eg_t.par_chunks_mut(t).enumerate().for_each(|(gi, row)| { for s in row.iter_mut() { *s = eg[gi]; } });
        let mut pf = vec![Fp2::ZERO; kpn * t];
        pf.par_chunks_mut(t).enumerate().for_each(|(gi, row)| {
            for (l, ev) in el.iter().enumerate() {
                let hs = gi * p.rep_p + l;
                for ti in 0..t {
                    let w = et[ti].mul(*ev);
                    if w.is_zero() { continue; }
                    let base = lay.pp + (hs * t + ti) * t;
                    for (j, s) in row.iter_mut().enumerate() { *s = s.add(w.mul_base(a[base + j])); }
                }
            }
        });
        let mut vf = vec![Fp2::ZERO; kpn * t];
        vf.par_chunks_mut(t).enumerate().for_each(|(gi, row)| {
            for (j, s) in row.iter_mut().enumerate() {
                let base = lay.v8 + j * vp + gi * hdim;
                let mut acc = Fp2::ZERO;
                for (i, e) in ei.iter().enumerate() { acc = acc.add(e.mul_base(a[base + i])); }
                *s = acc;
            }
        });
        vec![eg_t, pf, vf]
    }, &poly_3, "PV matmul")?;
    {
        let (rg, rj) = (&rho[..lay.log_kp as usize], &rho[lay.log_kp as usize..]);
        let d = vec![
            TabDesc::Pub(eq_point(r_ohi, rg)),
            TabDesc::A { off: lay.pp, log: lay.log_s,
                         pt: [rg.to_vec(), r_olo.to_vec(), r_ot.to_vec(), rj.to_vec()].concat() },
            TabDesc::A { off: lay.v8, log: lay.log_kv,
                         pt: [rj.to_vec(), rg.to_vec(), r_oi.to_vec()].concat() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_3(&v), cl, "PV matmul terminal")?; }
    }

    // ===== 12. the Wo matmul =====
    let p_a = tr.challenge_fp2_vec(lay.log_d as usize);
    let mut ao_v = Fp2::from_i64(lay.ao.recon().1);
    for (k, &o) in lay.ao.offs.iter().enumerate() {
        let cv = claim_at(&mut cc, tr, adat, o, lay.log_d, &p_a);
        ao_v = ao_v.add(cv.mul_base(Fp::from_i64(lay.ao.recon().0[k])));
    }
    let crao = claim_at(&mut cc, tr, adat, lay.rao, lay.log_d, &p_a);
    let (r_at, r_an) = (&p_a[..lay.log_t as usize], &p_a[lay.log_t as usize..]);
    let poly_2 = |v: &[Fp2]| v[0].mul(v[1]);
    let (rho, fin, cl) = ctx.sc(proof, tr, ao_v.mul_base(crate::layer::pow2_signed(c.sh_ao)).add(crao), 2,
                                lay.log_qp as usize, || {
        let (a, w) = (adat.unwrap(), wdat.unwrap());
        vec![crate::mle::fold_rows_base(&a[lay.o8..lay.o8 + lq], t, qp, &eq_table_msb(r_at)),
             crate::mle::fold_cols_base(&w[lay.wo..lay.wo + qp * dp], qp, dp, &eq_table_msb(r_an))]
    }, &poly_2, "Wo matmul")?;
    {
        let d = vec![
            TabDesc::A { off: lay.o8, log: lay.log_q, pt: [r_at.to_vec(), rho.clone()].concat() },
            TabDesc::W { off: lay.wo, log: lay.log_wq, pt: [rho.clone(), r_an.to_vec()].concat() },
        ];
        let v = terms(&mut cc, tr, &d, &fin, adat);
        if !proving { ctx.check(poly_2(&v), cl, "Wo matmul terminal")?; }
    }

    // ===== 13. the LogUp identity: the helper sums vs the multiplicity side =====
    let mut hsum = Fp2::ZERO;
    let all_h: Vec<((usize, usize), u32)> = lay.h_d.iter().map(|x| (*x, lay.log_d))
        .chain(lay.h_q.iter().map(|x| (*x, lay.log_q)))
        .chain(lay.h_kv.iter().map(|x| (*x, lay.log_kv)))
        .chain(lay.h_s.iter().map(|x| (*x, lay.log_s)))
        .chain(std::iter::once((lay.h_lm, lay.log_lm - 1)))
        .collect();
    for ((re, im), log) in &all_h {
        let n = 1usize << log;
        let v = match hdat {
            Some(h) => {
                let sre = h[*re..*re + n].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                let sim = h[*im..*im + n].par_iter().copied().reduce(|| Fp::ZERO, |a, b| a.add(b));
                Fp2::new(sre, sim)
            }
            None => Fp2::ZERO,
        };
        let s = cc.hsum(tr, Slice { offset: *re, log_size: *log }, Slice { offset: *im, log_size: *log }, v);
        hsum = hsum.add(s);
    }
    {
        let mut dens: Vec<Fp2> = Vec::new();
        let mut nums: Vec<Fp> = Vec::new();
        for (tag, m) in &proof.mults {
            let tb = tbl_of_tag(*tag, c, fc, lay).ok_or_else(|| format!("unknown table tag {tag}"))?;
            let gt = gamma.mul_base(Fp::new(*tag));
            for (i, &cnt) in m.iter().enumerate() {
                if cnt == 0 { continue; }
                let (v, aux) = tb.row(i, &exp);
                let tv = Fp2::from_i64(v).add(beta.mul_base(Fp::from_i64(aux))).add(gt);
                dens.push(alpha.sub(tv));
                nums.push(Fp::new(cnt as u64));
            }
        }
        batch_inverse2(&mut dens);
        let table_side = dens.iter().zip(nums.iter()).fold(Fp2::ZERO, |a, (d, n)| a.add(d.mul_base(*n)));
        ctx.check(hsum, table_side, "LogUp identity (a lookup is not in its table)")?;
    }
    if proving {
        proof.vals = cc.vals.clone();
    } else if cc.idx > cc.vals.len() {
        return Err(format!("claim count {} > {} sent", cc.idx, cc.vals.len()));
    }
    Ok(cc)
}


/// Everything the attention prover keeps between the argument and the
/// DEFERRED opening (the seam claims land after the FFN half has
/// committed its own planes).
pub struct AttnPending {
    pub lay: AttnLayout,
    pub w_cm: pcs::Committed,
    pub a_cm: pcs::Committed,
    pub h_cm: pcs::Committed,
    pub a_data: Vec<Fp>,
    pub cc: Cc,
}

pub fn absorb_attn_statement(tr: &mut Transcript, c: &AttnConsts, fc: &FullConsts, lay: &AttnLayout) {
    tr.absorb(b"profile", b"attn-full-layer-v1");
    let s = &c.shape;
    for (k, v) in [(&b"layer"[..], c.layer), (b"T", s.t), (b"d", s.d), (b"H", s.heads),
                   (b"Hkv", s.kv_heads), (b"dh", s.head_dim), (b"dp", lay.p.dp), (b"hp", lay.p.hp)] {
        tr.absorb_u64(k, v as u64);
    }
    let mut sb = Vec::new();
    for x in [c.sh_q, c.sh_k, c.sh_v, c.sh_qr, c.sh_kr, c.sh_s, c.sh_o, c.sh_ao, c.sh_r1,
              fc.sh_r2, c.sh_x1 as i32, c.sh_a1 as i32, fc.sh_x2 as i32, fc.sh_z2 as i32,
              c.e_s_raw, c.f_e as i32, c.f_p as i32, c.f_ro as i32, c.wrho_s as i32,
              c.x_cls as i32, c.ao_cls as i32, c.r1_cls as i32, fc.r2_cls as i32] {
        sb.extend_from_slice(&(x as i64).to_le_bytes());
    }
    for n in [&c.anorm, &c.mnorm] {
        for x in [n.tn as i64, n.cn, n.ceps, n.wrho as i64] {
            sb.extend_from_slice(&x.to_le_bytes());
        }
    }
    tr.absorb(b"attn-consts", &sb);
    tr.absorb(b"exp", c.exp_digest.as_bytes());
    tr.absorb(b"rope", c.rope_digest.as_bytes());
}

fn absorb_com_a(tr: &mut Transcript, label: &[u8], c: &Commitment) {
    tr.absorb(label, &c.root);
    tr.absorb_u64(label, c.rows as u64);
}

fn absorb_mults_a(tr: &mut Transcript, mults: &[(u64, Vec<u32>)]) {
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

pub fn attn_layout_of(c: &AttnConsts, fc: &FullConsts, log_cols: u32) -> AttnLayout {
    AttnLayout::new(&c.shape, c.x_cls, c.ao_cls, c.r1_cls, fc.r2_cls,
                    c.anorm.n_limbs, c.mnorm.n_limbs, log_cols)
}

/// Prove the attention half-layer, stopping before the PCS opening (the
/// seam to the FFN half is added by the caller, then `attn_open`).
pub fn prove_attn(wit: &AttnWitness, r2: &Resid2, params: &LayerParams, ntt: &NttTables,
                  tr: &mut Transcript) -> (AttnProof, AttnPending, Vec<(String, f64)>) {
    use std::time::Instant;
    let mut timings = Vec::new();
    let mut tick = Instant::now();
    let mut lap = |n: &str, timings: &mut Vec<(String, f64)>, tick: &mut Instant| {
        timings.push((n.to_string(), tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    let c = &wit.c;
    let fc = &r2.c;
    let lay = attn_layout_of(c, fc, params.log_cols);
    let pk = pack(wit, r2, &lay);
    lap("attn pack", &mut timings, &mut tick);
    let mut proof = AttnProof::default();
    absorb_attn_statement(tr, c, fc, &lay);
    let pp = PcsParams { log_cols: lay.cols_log, inv_rate: params.inv_rate, num_col_checks: params.num_col_checks };
    let w_cm = pcs::commit(&pp, &pk.w, ntt);
    proof.w_com = Some(w_cm.commitment());
    absorb_com_a(tr, b"Wa", proof.w_com.as_ref().unwrap());
    let a_cm = pcs::commit(&pp, &pk.a, ntt);
    proof.a_com = Some(a_cm.commitment());
    absorb_com_a(tr, b"Aa", proof.a_com.as_ref().unwrap());
    lap("attn commit W+A", &mut timings, &mut tick);
    proof.mults = pk.mults;
    absorb_mults_a(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let h_data = build_helpers(&pk.a, &lay, c, fc, alpha, beta, gamma);
    let h_cm = pcs::commit(&pp, &h_data, ntt);
    proof.h_com = Some(h_cm.commitment());
    absorb_com_a(tr, b"Ha", proof.h_com.as_ref().unwrap());
    lap("attn helpers + commit H", &mut timings, &mut tick);
    let side = Side::Prove(ProvData { a: &pk.a, h: &h_data, w: &pk.w, wit });
    let cc = attn_argument(side, &lay, c, fc, alpha, beta, gamma, &mut proof, tr)
        .expect("the attention prover's own argument failed");
    lap("attn sumchecks", &mut timings, &mut tick);
    drop(h_data);
    (proof, AttnPending { lay, w_cm, a_cm, h_cm, a_data: pk.a, cc }, timings)
}

/// The SEAM claims: the FFN half's X plane IS this layer's xm8, and the
/// z16 copy the residual pin used IS the FFN's z16 — checked at the point
/// the FFN's own zero-check drew AFTER both A commitments.
#[allow(clippy::too_many_arguments)]
pub fn attn_seam(cc: &mut Cc, tr: &mut Transcript, lay: &AttnLayout, a: Option<&[Fp]>,
                 pts: &[Vec<Fp2>], want_x: &[Fp2], want_z: &[Fp2]) -> Result<(), String> {
    for (b, pt) in pts.iter().enumerate() {
        let gx = claim_at(cc, tr, a, lay.xm8, lay.log_d, pt);
        let gz = claim_at(cc, tr, a, lay.z16c, lay.log_d, pt);
        if cc.proving {
            assert!(gx == want_x[b] || tamper_mode(), "[UPERF3-AG] seam: xm8 != the FFN's X at block {b}");
            assert!(gz == want_z[b] || tamper_mode(), "[UPERF3-AG] seam: z16 copy != the FFN's z16 at block {b}");
        } else {
            if gx != want_x[b] { return Err(format!("seam: xm8 != the FFN's X at block {b}")); }
            if gz != want_z[b] { return Err(format!("seam: z16 copy != the FFN's z16 at block {b}")); }
        }
    }
    Ok(())
}

/// The deferred openings.
pub fn attn_open(pend: AttnPending, proof: &mut AttnProof, tr: &mut Transcript) {
    let AttnPending { w_cm, a_cm, h_cm, a_data, cc, .. } = pend;
    // the seam claims land AFTER the argument: re-take the value list
    proof.vals = cc.vals.clone();
    proof.w_open = pcs::open(&w_cm, &cc.ww, tr);
    drop(w_cm);
    proof.a_open = pcs::open(&a_cm, &cc.aw, tr);
    drop(a_cm);
    drop(a_data);
    proof.h_open = pcs::open(&h_cm, &cc.hh, tr);
}

/// Verify the attention half-layer up to (not including) the openings; the
/// caller adds the seam claims and calls `attn_verify_open`.
pub fn verify_attn(proof: &AttnProof, c: &AttnConsts, fc: &FullConsts, params: &LayerParams,
                   tr: &mut Transcript) -> Result<(AttnLayout, Cc), String> {
    let lay = attn_layout_of(c, fc, params.log_cols);
    absorb_attn_statement(tr, c, fc, &lay);
    let pp = PcsParams { log_cols: lay.cols_log, inv_rate: params.inv_rate, num_col_checks: params.num_col_checks };
    let cols = pp.cols();
    let w_com = proof.w_com.as_ref().ok_or("missing Wa commitment")?;
    let a_com = proof.a_com.as_ref().ok_or("missing Aa commitment")?;
    let h_com = proof.h_com.as_ref().ok_or("missing Ha commitment")?;
    if w_com.rows != lay.w_len / cols { return Err("Wa rows".into()); }
    if a_com.rows != lay.a_len / cols { return Err("Aa rows".into()); }
    if h_com.rows != lay.h_len / cols { return Err("Ha rows".into()); }
    absorb_com_a(tr, b"Wa", w_com);
    absorb_com_a(tr, b"Aa", a_com);
    // the multiplicity tables: the exact table set, row counts and totals
    let want = lookup_totals(&lay, c, fc);
    if proof.mults.len() != want.len() { return Err("multiplicity table count".into()); }
    for ((tag, m), (wtag, wtot)) in proof.mults.iter().zip(want.iter()) {
        if tag != wtag { return Err(format!("multiplicity tag {tag} != {wtag}")); }
        let tb = tbl_of_tag(*tag, c, fc, &lay).ok_or("unknown tag")?;
        if m.len() != tb.rows(c.f_p) { return Err(format!("table {tag}: {} rows", m.len())); }
        let got: u64 = m.iter().map(|&x| x as u64).sum();
        if got != *wtot { return Err(format!("table {tag}: total {got} != {wtot}")); }
    }
    absorb_mults_a(tr, &proof.mults);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    absorb_com_a(tr, b"Ha", h_com);
    let mut pf = proof.clone();
    let cc = attn_argument(Side::Verify, &lay, c, fc, alpha, beta, gamma, &mut pf, tr)?;
    Ok((lay, cc))
}

/// The verifier's PCS step (after the seam claims).
pub fn verify_attn_open(proof: &AttnProof, lay: &AttnLayout, cc: &Cc, params: &LayerParams,
                        ntt: &NttTables, tr: &mut Transcript) -> Result<(), String> {
    if cc.idx != cc.vals.len() {
        return Err(format!("claim count {} != {} sent", cc.idx, cc.vals.len()));
    }
    let pp = PcsParams { log_cols: lay.cols_log, inv_rate: params.inv_rate, num_col_checks: params.num_col_checks };
    pcs::verify(&pp, proof.w_com.as_ref().unwrap(), &cc.ww, &proof.w_open, ntt, tr).map_err(|e| format!("Wa: {e}"))?;
    pcs::verify(&pp, proof.a_com.as_ref().unwrap(), &cc.aw, &proof.a_open, ntt, tr).map_err(|e| format!("Aa: {e}"))?;
    pcs::verify(&pp, proof.h_com.as_ref().unwrap(), &cc.hh, &proof.h_open, ntt, tr).map_err(|e| format!("Ha: {e}"))?;
    Ok(())
}


// ---- tamper legs ---------------------------------------------------------
use std::sync::atomic::{AtomicBool, Ordering};
static TAMPER: AtomicBool = AtomicBool::new(false);
/// In tamper mode the prover's own consistency asserts are silenced: a
/// CHEATING prover would not run them, and the point of a leg is that the
/// VERIFIER rejects.
pub fn set_tamper_mode(b: bool) {
    TAMPER.store(b, Ordering::Relaxed);
}
pub fn tamper_mode() -> bool {
    TAMPER.load(Ordering::Relaxed)
}

#[derive(Clone, Copy, Debug)]
pub enum AttnTamper {
    None,
    /// x_in[i] += 1 (the layer's input)
    FlipX(usize),
    /// s8[i] += 1: a flipped score
    FlipScore(usize),
    /// E[i] += 1: a wrong exponential-table entry
    WrongExp(usize),
    /// P[i] += 1: a wrong softmax quotient
    WrongQuot(usize),
    /// xn8[i] += 1: a wrong norm output
    WrongNorm(usize),
    /// D[i] += 1: a wrong inverse-square-root
    WrongIsqrt(usize),
    /// qr8[i] += 1: a wrong RoPE rotation
    WrongRope(usize),
    /// m[i] += 1: a wrong row maximum
    WrongMax(usize),
    /// zsel: the attainment selector moved off the maximum
    WrongZsel(usize),
    /// z16[i] += 1 in the residual pin (the seam plane)
    BreakSeam(usize),
}

pub fn apply_attn_tamper(w: &mut AttnWitness, r2: &mut Resid2, t: AttnTamper) {
    let m = |v: &mut Vec<i64>, i: usize| { let n = v.len(); v[i % n] += 1; };
    match t {
        AttnTamper::None => {}
        AttnTamper::FlipX(i) => m(&mut w.x_in, i),
        AttnTamper::FlipScore(i) => m(&mut w.s8, i),
        AttnTamper::WrongExp(i) => m(&mut w.e_t, i),
        AttnTamper::WrongQuot(i) => m(&mut w.p, i),
        AttnTamper::WrongNorm(i) => m(&mut w.na.y, i),
        AttnTamper::WrongIsqrt(i) => m(&mut w.na.dd, i),
        AttnTamper::WrongRope(i) => m(&mut w.qr8, i),
        AttnTamper::WrongMax(i) => m(&mut w.m_row, i),
        AttnTamper::WrongZsel(i) => {
            let n = w.zsel.len();
            let t_ = w.c.shape.t;
            let row = (i % n) / t_ * t_;
            // move the selector one column along (still binary, still one per row)
            for j in 0..t_ { if w.zsel[row + j] == 1 { w.zsel[row + j] = 0; w.zsel[row + (j + 1) % t_] = 1; break; } }
        }
        AttnTamper::BreakSeam(i) => m(&mut r2.z16, i),
    }
}


/// A deep copy of the witness (the tamper legs prove a mutated copy).
pub fn clone_attn_witness(w: &AttnWitness) -> AttnWitness {
    AttnWitness {
        c: w.c.clone(), x_in: w.x_in.clone(), wq: w.wq.clone(), wk: w.wk.clone(), wv: w.wv.clone(),
        wo: w.wo.clone(), g_a: w.g_a.clone(), g_m: w.g_m.clone(),
        na: clone_norm(&w.na), nm: clone_norm(&w.nm),
        qacc: w.qacc.clone(), q8: w.q8.clone(), rq: w.rq.clone(), kacc: w.kacc.clone(), k8: w.k8.clone(),
        rk: w.rk.clone(), vacc: w.vacc.clone(), v8: w.v8.clone(), rv: w.rv.clone(),
        qracc: w.qracc.clone(), qr8: w.qr8.clone(), rqr: w.rqr.clone(), kracc: w.kracc.clone(),
        kr8: w.kr8.clone(), rkr: w.rkr.clone(), sacc: w.sacc.clone(), s8: w.s8.clone(), rs: w.rs.clone(),
        dmat: w.dmat.clone(), zsel: w.zsel.clone(), e_t: w.e_t.clone(), p: w.p.clone(),
        rho_s: w.rho_s.clone(), sig_s: w.sig_s.clone(), m_row: w.m_row.clone(), sum: w.sum.clone(),
        oacc: w.oacc.clone(), o8: w.o8.clone(), r_o: w.r_o.clone(), aoacc: w.aoacc.clone(),
        ao8: w.ao8.clone(), r_ao: w.r_ao.clone(), xw1: w.xw1.clone(), xres1: w.xres1.clone(),
        rr1: w.rr1.clone(), exp_tab: w.exp_tab, ctab: w.ctab.clone(), stab: w.stab.clone(),
    }
}
fn clone_norm(n: &crate::norm::NormChain) -> crate::norm::NormChain {
    crate::norm::NormChain {
        xsq: n.xsq.clone(), sse: n.sse.clone(), dd: n.dd.clone(), dsq: n.dsq.clone(),
        a1: n.a1.clone(), a2: n.a2.clone(), y: n.y.clone(), rho: n.rho.clone(), sig: n.sig.clone(),
    }
}
/// Break the SEAM alone: change the z16 copy the residual pin consumed and
/// recompute xres2/rr2 so that the PIN still holds — only the seam claim
/// (z16 copy == the FFN's z16) can catch it.
pub fn break_seam(r2: &mut Resid2, wit: &AttnWitness, i: usize) {
    let n = r2.z16.len();
    let i = i % n;
    r2.z16[i] += 1;
    let xw = (wit.xres1[i] << r2.c.sh_x2) + (r2.z16[i] << r2.c.sh_z2);
    let (y, r) = requant_round(&[xw], r2.c.sh_r2 as i64);
    r2.xres2[i] = y[0];
    r2.rr2[i] = r[0];
}

pub fn clone_resid2(r: &Resid2) -> Resid2 {
    Resid2 { c: r.c.clone(), z16: r.z16.clone(), xres2: r.xres2.clone(), rr2: r.rr2.clone() }
}

#[cfg(test)]
mod chain_tests {
    use super::*;

    #[test]
    fn norm_round_matches_the_relation() {
        let d = 32usize;
        let x: Vec<i64> = (0..4 * d).map(|i| ((i * 37) % 255) as i64 - 127).collect();
        let g: Vec<i64> = (0..d).map(|i| 49 + (i % 31) as i64).collect();
        let (tn, cn) = crate::norm::window_rule(-6, -2, d);
        let o = crate::norm::rmsnorm_chain(&x, &g, d, 1, tn, cn, crate::norm::DivMode::Round);
        for t in 0..4 {
            let dv = o.dd[t] << tn;
            for i in 0..d {
                let num = 2 * x[t * d + i] * g[i] * cn + dv;
                assert_eq!(o.y[t * d + i] * (2 * dv) + o.rho[t * d + i], num);
                assert_eq!(o.sig[t * d + i], 2 * dv - 1 - o.rho[t * d + i]);
            }
        }
    }

    #[test]
    fn requant_round_is_balanced() {
        let acc = vec![-9i64, -8, -7, 0, 7, 8, 9];
        let (y, r) = requant_round(&acc, 3);
        for i in 0..acc.len() {
            assert_eq!((y[i] << 3) + r[i], acc[i]);
            assert!((-4..4).contains(&r[i]));
        }
    }
}
