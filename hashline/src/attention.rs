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

/// A streaming digest (the per-head tensors are hashed head by head, which
/// is byte-identical to hashing the stacked head-major tensor).
struct Stream(Sha256);
impl Stream {
    fn new() -> Stream {
        Stream(Sha256::new())
    }
    fn push(&mut self, v: &[i64]) {
        let mut buf = Vec::with_capacity(v.len() * 8);
        for &x in v {
            buf.extend_from_slice(&x.to_le_bytes());
        }
        self.0.update(&buf);
    }
    fn finish(self) -> String {
        crate::silu::hex(&self.0.finalize())
    }
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

/// Run the whole chain from an export directory; returns the ordered
/// (name, digest) list and the CHAIN digest.
pub fn chain_from_export(dir: &str) -> (Vec<(String, String)>, String) {
    let m = Manifest::load(dir);
    let (t, d) = (m.u("T"), m.u("d"));
    let (h_q, h_kv, hd) = (m.u("heads"), m.u("kv_heads"), m.u("head_dim"));
    let rep = h_q / h_kv;
    let f_e = m.i("fE") as u32;
    let f_p = m.i("fP") as u32;
    let f_ro = m.i("fRo") as u32;
    let round = m.s("norm_div") == "round";
    let x_in = load_i32(dir, "x_in");
    let wq = load_i32(dir, "wq");
    let wk = load_i32(dir, "wk");
    let wv = load_i32(dir, "wv");
    let wo = load_i32(dir, "wo");
    let g_a = load_i32(dir, "gA");
    let g_m = load_i32(dir, "gM");
    let mut out: Vec<(String, String)> = Vec::new();

    // --- attn_norm ---------------------------------------------------
    let dmode = if round { crate::norm::DivMode::Round } else { crate::norm::DivMode::Floor };
    let na = crate::norm::rmsnorm_chain(&x_in, &g_a, d, m.i("anorm_ceps"),
                                        m.i("anorm_tn") as u32, m.i("anorm_cn"), dmode);
    out.push(("xsqA".to_string(), dig_i64(&na.xsq)));
    out.push(("SSA".to_string(), dig_i64(&na.sse)));
    out.push(("DA".to_string(), dig_i64(&na.dd)));
    out.push(("DsqA".to_string(), dig_i64(&na.dsq)));
    out.push(("a1A".to_string(), dig_i64(&na.a1)));
    out.push(("a2A".to_string(), dig_i64(&na.a2)));
    out.push(("xn8".to_string(), dig_i64(&na.y)));
    let wr_a = m.i("anorm_wrho") as u32;
    for (i, l) in limbs(&na.rho, wr_a).iter().enumerate() {
        out.push((format!("rhoA_l{i}"), dig_i64(l)));
    }
    for (i, l) in limbs(&na.sig, wr_a).iter().enumerate() {
        out.push((format!("sigA_l{i}"), dig_i64(l)));
    }

    // --- QKV -----------------------------------------------------------
    let mm = |w: &[i64], d_out: usize, sh: i64, name: &str, lim: i64,
                  out: &mut Vec<(String, String)>| -> Vec<i64> {
        let acc = matmul_wt(&na.y, w, t, d, d_out);
        let (y, r) = requant_round(&acc, sh);
        assert!(y.iter().all(|&v| v.abs() <= lim), "{name}: narrowing saturates");
        out.push((format!("{name}acc"), dig_i64(&acc)));
        out.push((name.to_lowercase() + "8", dig_i64(&y)));
        out.push((format!("r{}", name.to_uppercase()), dig_i64(&r)));
        y
    };
    let q8 = mm(&wq, h_q * hd, m.i("sh_q"), "Q", 127, &mut out);
    let k8 = mm(&wk, h_kv * hd, m.i("sh_k"), "K", 127, &mut out);
    let v8 = mm(&wv, h_kv * hd, m.i("sh_v"), "V", 127, &mut out);

    // --- RoPE ----------------------------------------------------------
    let (ctab, stab) = crate::tables_attn::rope_tables_generate(t, hd, m.f("rope_base"), f_ro);
    let rope_dig = crate::tables_attn::rope_digest(t, hd, m.f("rope_base"), f_ro, &ctab, &stab);
    assert_eq!(rope_dig, m.s("rope_digest"), "rope table digest");
    let half = hd / 2;
    let rope = |src: &[i64], heads: usize, sh: i64| -> (Vec<i64>, Vec<i64>, Vec<i64>) {
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
        let (y, r) = requant_round(&acc, sh);
        assert!(y.iter().all(|&v| v.abs() <= 127), "rope narrowing saturates");
        (acc, y, r)
    };
    let (qracc, qr8, rqr) = rope(&q8, h_q, m.i("sh_qr"));
    let (kracc, kr8, rkr) = rope(&k8, h_kv, m.i("sh_kr"));
    out.push(("QRacc".to_string(), dig_i64(&qracc)));
    out.push(("qr8".to_string(), dig_i64(&qr8)));
    out.push(("rQR".to_string(), dig_i64(&rqr)));
    out.push(("KRacc".to_string(), dig_i64(&kracc)));
    out.push(("kr8".to_string(), dig_i64(&kr8)));
    out.push(("rKR".to_string(), dig_i64(&rkr)));

    // --- scores, softmax, PV (streamed per head) -----------------------
    let (exp_tab, exp_dig) = crate::tables_attn::exp_member(m.i("e_s_raw") as i32, hd, f_e);
    assert_eq!(exp_dig, m.s("exp_digest"), "exp member digest");
    let sh_s = m.i("sh_s");
    let sh_o = m.i("sh_o");
    let mut st: HashMap<&str, Stream> = HashMap::new();
    for n in ["Sacc", "s8", "rS", "m", "dmat", "zsel", "E", "Sum", "P", "rho", "sig", "Oacc"] {
        st.insert(n, Stream::new());
    }
    let qw = h_q * hd;
    let kw = h_kv * hd;
    let mut o8 = vec![0i64; t * qw];
    let mut r_o = vec![0i64; t * qw];
    for h in 0..h_q {
        let g = h / rep;
        // Sacc(h) = qr8[:, h, :] . kr8[:, g, :]^T
        let mut sacc = vec![0i64; t * t];
        sacc.par_chunks_mut(t).enumerate().for_each(|(ti, row)| {
            let qrow = &qr8[ti * qw + h * hd..ti * qw + h * hd + hd];
            for (j, slot) in row.iter_mut().enumerate() {
                let krow = &kr8[j * kw + g * hd..j * kw + g * hd + hd];
                let mut s = 0i64;
                for i in 0..hd {
                    s += qrow[i] * krow[i];
                }
                *slot = s;
            }
        });
        let (s8, rs) = requant_round(&sacc, sh_s);
        assert!(s8.iter().all(|&v| v.abs() <= 127), "s8 narrowing saturates");
        // softmax
        let mut m_row = vec![i64::MIN; t];
        let mut zsel = vec![0i64; t * t];
        let mut dmat = vec![0i64; t * t];
        let mut e_t = vec![0i64; t * t];
        let mut sum = vec![0i64; t];
        let mut p = vec![0i64; t * t];
        let mut rho = vec![0i64; t * t];
        let mut sig = vec![0i64; t * t];
        for ti in 0..t {
            let mut best = i64::MIN;
            let mut arg = 0usize;
            for j in 0..t {
                let sm = if j <= ti { s8[ti * t + j] } else { -127 };
                if sm > best {
                    best = sm;
                    arg = j;
                }
            }
            m_row[ti] = best;
            zsel[ti * t + arg] = 1;
            let mut s = 0i64;
            for j in 0..t {
                let sm = if j <= ti { s8[ti * t + j] } else { -127 };
                let dv = best - sm;
                assert!((0..256).contains(&dv), "dominance {dv}");
                dmat[ti * t + j] = dv;
                let e = exp_tab[dv as usize];
                e_t[ti * t + j] = e;
                if j <= ti {
                    s += e;
                }
            }
            assert!(s >= 1i64 << f_e, "attainment");
            sum[ti] = s;
            for j in 0..t {
                if j <= ti {
                    let num = e_t[ti * t + j] << f_p;
                    let q = num.div_euclid(s);
                    p[ti * t + j] = q;
                    rho[ti * t + j] = num - q * s;
                    sig[ti * t + j] = s - 1 - rho[ti * t + j];
                }
            }
        }
        // Oacc(h) = P . v8[:, g, :]
        let mut oacc = vec![0i64; t * hd];
        oacc.par_chunks_mut(hd).enumerate().for_each(|(ti, row)| {
            for j in 0..=ti {
                let pv = p[ti * t + j];
                if pv == 0 {
                    continue;
                }
                let vrow = &v8[j * kw + g * hd..j * kw + g * hd + hd];
                for i in 0..hd {
                    row[i] += pv * vrow[i];
                }
            }
        });
        let (oy, orr) = requant_round(&oacc, sh_o);
        assert!(oy.iter().all(|&v| v.abs() <= 127), "o8 narrowing saturates");
        for ti in 0..t {
            for i in 0..hd {
                o8[ti * qw + h * hd + i] = oy[ti * hd + i];
                r_o[ti * qw + h * hd + i] = orr[ti * hd + i];
            }
        }
        st.get_mut("Sacc").unwrap().push(&sacc);
        st.get_mut("s8").unwrap().push(&s8);
        st.get_mut("rS").unwrap().push(&rs);
        st.get_mut("m").unwrap().push(&m_row);
        st.get_mut("dmat").unwrap().push(&dmat);
        st.get_mut("zsel").unwrap().push(&zsel);
        st.get_mut("E").unwrap().push(&e_t);
        st.get_mut("Sum").unwrap().push(&sum);
        st.get_mut("P").unwrap().push(&p);
        st.get_mut("rho").unwrap().push(&rho);
        st.get_mut("sig").unwrap().push(&sig);
        st.get_mut("Oacc").unwrap().push(&oacc);
    }
    for n in ["Sacc", "s8", "rS", "m", "dmat", "zsel", "E", "Sum", "P", "rho", "sig", "Oacc"] {
        let s = st.remove(n).unwrap();
        out.push((n.to_string(), s.finish()));
    }
    out.push(("o8".to_string(), dig_i64(&o8)));
    out.push(("rO".to_string(), dig_i64(&r_o)));

    // --- Wo + ao -------------------------------------------------------
    let aoacc = matmul_wt(&o8, &wo, t, qw, d);
    let (ao8, r_ao) = requant_round(&aoacc, m.i("sh_ao"));
    assert!(ao8.iter().all(|&v| v.abs() <= m.i("ao_lim")), "ao narrowing saturates");
    out.push(("AOacc".to_string(), dig_i64(&aoacc)));
    out.push(("ao8".to_string(), dig_i64(&ao8)));
    out.push(("rAO".to_string(), dig_i64(&r_ao)));

    // --- residual add 1 -------------------------------------------------
    let (sh_x, sh_a) = ((m.i("e_r") - m.i("e_c1")) as u32, (m.i("e_ao") - m.i("e_c1")) as u32);
    let xw1: Vec<i64> = x_in
        .par_iter()
        .zip(ao8.par_iter())
        .map(|(&x, &a)| (x << sh_x) + (a << sh_a))
        .collect();
    let (xres1, rr1) = requant_round(&xw1, m.i("sh_r1"));
    assert!(xres1.iter().all(|&v| v.abs() <= m.i("r1_lim")), "xres1 narrowing saturates");
    out.push(("xw1".to_string(), dig_i64(&xw1)));
    out.push(("xres1".to_string(), dig_i64(&xres1)));
    out.push(("rr1".to_string(), dig_i64(&rr1)));

    // --- mlp_norm (the FFN's X plane) -----------------------------------
    let nm = crate::norm::rmsnorm_chain(&xres1, &g_m, d, m.i("mnorm_ceps"),
                                        m.i("mnorm_tn") as u32, m.i("mnorm_cn"), dmode);
    out.push(("xsqM".to_string(), dig_i64(&nm.xsq)));
    out.push(("SSM".to_string(), dig_i64(&nm.sse)));
    out.push(("DM".to_string(), dig_i64(&nm.dd)));
    out.push(("DsqM".to_string(), dig_i64(&nm.dsq)));
    out.push(("a1M".to_string(), dig_i64(&nm.a1)));
    out.push(("a2M".to_string(), dig_i64(&nm.a2)));
    out.push(("xm8".to_string(), dig_i64(&nm.y)));
    let wr_m = m.i("mnorm_wrho") as u32;
    for (i, l) in limbs(&nm.rho, wr_m).iter().enumerate() {
        out.push((format!("rhoM_l{i}"), dig_i64(l)));
    }
    for (i, l) in limbs(&nm.sig, wr_m).iter().enumerate() {
        out.push((format!("sigM_l{i}"), dig_i64(l)));
    }

    // --- the committed inputs -------------------------------------------
    for (n, v) in [("x_in", &x_in), ("Wq", &wq), ("Wk", &wk), ("Wv", &wv), ("Wo", &wo),
                   ("gA", &g_a), ("gM", &g_m)] {
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
