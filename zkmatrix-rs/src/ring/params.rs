// Route R parameter derivation (U2): the C0'-C4 iteration over the ring,
// ported from scripts/route_r_params.py (the reference implementation —
// keep the two in lockstep; the self-test pins this port to the script's
// published table values). Two chains:
//
//   derive_plain   — the design Section 3 chain (undecomposed openings)
//   derive_digits  — the Q2 chain: combination witnesses decomposed into
//                    balanced base-2^e digits, per-digit Sigma rounds
//                    sharing one challenge, jointly rejection-sampled; the
//                    C2/C3 norms collapse to the digit scale
//
// plus the P0 line: every A1 kernel regime of a candidate point must fit a
// helper-prime path (single-prime or limb-split x3) or the point is
// rejected LOUDLY at derive time (a1_enforce), never silently at prove
// time. The constraint solve order and constants mirror the script:
//   C0' LS18 invertibility (ls18_margin > 1; trivial at k = 2, 1.30x at
//       the recommended k = 8, q8_31 point)
//   C1' |C| = 5^128 = 2^297.2 >= 2^257 (static, quinary challenges)
//   C2  q > 8 beta, >= 1 bit headroom
//   C3  k_Z >= (log2 beta / 2)^2 / (log2 q * log2 delta0)
//   C4  N_Z >= k_Z + msg_Z + 768 log2 q / 11.7
//
// Concentration-norm discipline (conc = true, the recommended point):
// operator norms via E||c x||^2 = d E[c_i^2] ||x||^2 with a 1.3 tail
// factor; legitimate for rejection-CENTER sizing under a restart-if-
// exceeded rule (center_sq), 2^-64-class soundness surcharge documented in
// the design (Q4).

use super::{D, LOG2_DELTA0, ls18_margin};
use super::aux::a1_regime_path;

pub const TAIL: f64 = 1.3;
pub const E_C2: f64 = 2.0; // E[c_i^2] for quinary coefficients {-2..2}
pub const E_RHO2: f64 = 2.0 / 3.0; // E[rho_i^2] for ternary randomness

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Proto {
    Pi1,
    Pi2,
}

/// One derived parameter point. Float fields carry the chain values (for
/// table/report parity with the script); integer fields are the runtime
/// contracts the prover/verifier actually enforce.
#[derive(Clone, Debug)]
pub struct ProtoParams {
    pub proto: Proto,
    pub rows: usize,
    pub inner: usize,
    pub cols: usize,
    pub q: u64,
    pub log2_q: f64,
    pub conc: bool,
    /// Digit decomposition: e = 0 marks the plain (undecomposed) chain.
    pub e: u32,
    pub l_dig: usize,
    /// Per-coefficient combination-witness bound (digit chain only).
    pub w_u: f64,
    pub msg_r: usize,
    pub n_r: usize,
    pub kappa: usize,
    pub d_lwe: usize,
    pub sigma_f: f64,
    pub bound_f: f64,
    pub beta_f: f64,
    // Runtime contracts.
    pub sigma: u64,
    pub bound_sq: u128,
    /// Concentration restart rule on the rejection center bundle (digit
    /// chain; 0 disables the restart check for worst-case chains).
    pub center_sq: u128,
}

impl ProtoParams {
    pub fn n_z(&self) -> usize {
        self.n_r * D
    }
    pub fn msg_z(&self) -> usize {
        self.msg_r * D
    }
    /// C2 headroom in bits: log2 q - log2(8 beta).
    pub fn c2_headroom_bits(&self) -> f64 {
        self.log2_q - (8.0 * self.beta_f).log2()
    }
    /// Commitment bytes per column at this point.
    pub fn commit_col_kb(&self) -> f64 {
        (self.kappa + self.msg_r) as f64 * D as f64 * self.log2_q / 8.0 / 1024.0
    }
}

pub fn op_norm(conc: bool) -> f64 {
    if conc { TAIL * (E_C2 * D as f64).sqrt() } else { 2.0 * D as f64 }
}

/// Norm of a t-fold challenge combination of columns with base norm b0.
pub fn combine(t: usize, b0: f64, conc: bool) -> f64 {
    if conc {
        TAIL * (E_C2 * D as f64 * t as f64).sqrt() * b0
    } else {
        t as f64 * 2.0 * D as f64 * b0
    }
}

/// Per-coefficient magnitude of a t-fold challenge combination of ternary
/// vectors: worst t * 2D; concentration 1.3 sqrt(t * D * E[c^2] * E[rho^2]).
pub fn witness_coeff_bound(t: usize, conc: bool) -> f64 {
    if conc {
        TAIL * (t as f64 * D as f64 * E_C2 * E_RHO2).sqrt()
    } else {
        t as f64 * 2.0 * D as f64
    }
}

fn finalize(
    proto: Proto,
    rows: usize,
    inner: usize,
    cols: usize,
    q: u64,
    conc: bool,
    e: u32,
    l_dig: usize,
    w_u: f64,
    msg_r: usize,
    n_r: usize,
    kappa: usize,
    d_lwe: usize,
    sigma_f: f64,
    bound_f: f64,
    beta_f: f64,
    center_sq: u128,
) -> Option<ProtoParams> {
    let log2_q = (q as f64).log2();
    // C2 with >= 1 bit headroom; C0' (LS18) is asserted by the caller at
    // context construction; C1' is static for quinary d = 128.
    if (q as f64) <= 16.0 * beta_f {
        return None;
    }
    Some(ProtoParams {
        proto,
        rows,
        inner,
        cols,
        q,
        log2_q,
        conc,
        e,
        l_dig,
        w_u,
        msg_r,
        n_r,
        kappa,
        d_lwe,
        sigma_f,
        bound_f,
        beta_f,
        sigma: sigma_f.ceil() as u64,
        bound_sq: (bound_f * bound_f).ceil() as u128,
        center_sq,
    })
}

/// The design Section 3 chain (plain openings), port of derive().
pub fn derive_plain(
    proto: Proto,
    rows: usize,
    inner: usize,
    cols: usize,
    msg_min: usize,
    q: u64,
    conc: bool,
) -> Option<ProtoParams> {
    let log2_q = (q as f64).log2();
    let msg_r = rows.max(inner).max(msg_min).div_ceil(D).max(1);
    let msg_z = msg_r * D;
    let d_lwe = (768.0 * log2_q / 11.7).ceil() as usize;
    let mut k_z = 12 * D;
    let (mut n_r, mut sigma, mut bound, mut beta) = (0usize, 0.0f64, 0.0f64, 0.0f64);
    for _ in 0..6 {
        n_r = (k_z + msg_z + d_lwe).div_ceil(D);
        let n_z = (n_r * D) as f64;
        let b0 = n_z.sqrt();
        let op = op_norm(conc);
        let (t_sq, dim) = match proto {
            Proto::Pi1 => {
                let b_rho = combine(cols, b0, conc);
                (2.0 * (op * b_rho) * (op * b_rho), 2.0 * n_z)
            }
            Proto::Pi2 => {
                let b_rho_s = combine(rows, b0, conc);
                let b_rho_v = combine(cols, b0, conc);
                let last = op * b0 + op * op * b_rho_v;
                (op * op * (b_rho_s * b_rho_s + b_rho_v * b_rho_v) + last * last, 3.0 * n_z)
            }
        };
        sigma = 12.0 * t_sq.sqrt();
        bound = 1.2 * sigma * dim.sqrt();
        beta = match proto {
            Proto::Pi1 => {
                let b_rho = combine(cols, b0, conc);
                2.0 * bound + op_norm(conc) * b_rho
            }
            Proto::Pi2 => {
                let op = op_norm(conc);
                let b_rho_s = combine(rows, b0, conc);
                let b_rho_v = combine(cols, b0, conc);
                (2.0 * bound + op * b_rho_s).max(3.0 * op * bound + op * op * op * b_rho_v)
            }
        };
        k_z = (((beta.log2() / 2.0) * (beta.log2() / 2.0)) / (log2_q * LOG2_DELTA0)).ceil() as usize;
    }
    let kappa = k_z.div_ceil(D);
    finalize(proto, rows, inner, cols, q, conc, 0, 1, 0.0, msg_r, n_r, kappa, d_lwe, sigma, bound, beta, 0)
}

/// The Q2 chain (digit-decomposed combination openings), port of
/// derive_q2(). The combination count t = max(rows, cols); the bundle is
/// the L digit responses jointly rejection-sampled.
pub fn derive_digits(
    proto: Proto,
    rows: usize,
    inner: usize,
    cols: usize,
    msg_min: usize,
    q: u64,
    conc: bool,
    e: u32,
) -> Option<ProtoParams> {
    let log2_q = (q as f64).log2();
    let t = rows.max(cols);
    let w_u = witness_coeff_bound(t, conc);
    let l_dig = ((w_u.log2() + 1.0) / e as f64).ceil() as usize;
    let msg_r = rows.max(inner).max(msg_min).div_ceil(D).max(1);
    let msg_z = msg_r * D;
    let d_lwe = (768.0 * log2_q / 11.7).ceil() as usize;
    let mut k_z = 8 * D;
    let (mut n_r, mut sigma, mut bound, mut beta, mut center_sq) = (0usize, 0.0f64, 0.0f64, 0.0f64, 0u128);
    for _ in 0..6 {
        n_r = (k_z + msg_z + d_lwe).div_ceil(D);
        let n_z = (n_r * D) as f64;
        let op = op_norm(conc);
        let half = 2.0f64.powi(e as i32 - 1);
        // Joint (bundled) rejection over the L digit responses.
        let bundle_dim = l_dig as f64 * n_z;
        let t_bundle = op * half * bundle_dim.sqrt();
        sigma = 12.0 * t_bundle;
        bound = 1.2 * sigma * bundle_dim.sqrt();
        let beta_dig = 2.0 * bound + op * half * n_z.sqrt();
        // Recombined range-proved witness after one challenge clearing —
        // honest magnitude W_u, not the Gaussian-response magnitude.
        let beta_rec = op * w_u * n_z.sqrt();
        beta = beta_dig.max(beta_rec);
        center_sq = (t_bundle * t_bundle).ceil() as u128;
        k_z = (((beta.log2() / 2.0) * (beta.log2() / 2.0)) / (log2_q * LOG2_DELTA0)).ceil() as usize;
    }
    let kappa = k_z.div_ceil(D);
    finalize(proto, rows, inner, cols, q, conc, e, l_dig, w_u, msg_r, n_r, kappa, d_lwe, sigma, bound, beta, center_sq)
}

// ---------------------------------------------------------------------------
// P0: the A1 kernel-regime line. Mirrors a1_capacity_report /
// print_a1_regime_table. A point whose regimes fit NOTHING panics here — at
// derive time, never at prove time (the kernels re-assert their contracts
// at construction).

pub struct A1RegimeLine {
    pub name: String,
    pub path: &'static str,
}

/// Check every kernel regime of a parameter point against the helper-prime
/// capacity: commit (b = 1), mask (b = 12 sigma), verify (b = response inf
/// bound), gate (general x general, n_acc = 1). Panics on a regime that
/// fits neither path.
pub fn a1_enforce(q: u64, n_r: usize, sigma: u64, resp_inf: u128) -> Vec<A1RegimeLine> {
    let regimes: [(String, usize, u128); 4] = [
        ("commit: key x ternary rho (b = 1)".to_string(), n_r, 1),
        (format!("mask:   key x Gaussian y (b = 12 sigma = {})", 12 * sigma as u128), n_r, 12 * sigma as u128),
        (format!("verify: key x response z (b = |z|_inf <= {resp_inf})"), n_r, resp_inf),
        (format!("gate:   general x general (b = (q-1)/2 = {})", (q - 1) / 2), 1, ((q - 1) / 2) as u128),
    ];
    regimes
        .into_iter()
        .map(|(name, n_acc, b)| match a1_regime_path(n_acc, q, b) {
            Some(path) => A1RegimeLine { name, path },
            None => panic!(
                "A1 regime '{name}' fits neither single-prime nor limb-split at q = {q} — parameter set rejected at derive time"
            ),
        })
        .collect()
}

/// C0' at context level: LS18 coverage of quinary challenge differences.
pub fn assert_ls18(q: u64, k: usize) {
    let m = ls18_margin(q, k);
    assert!(m > 1.0, "LS18 margin {m:.2}x <= 1 at (k = {k}, q = {q}) — C0' rejected");
}

// ---------------------------------------------------------------------------
// Proof-size models (report parity with the script; KB).

pub fn proof_kb(p: &ProtoParams) -> f64 {
    let sigma_bits = p.sigma_f.log2() + 4.0;
    let (msg_z, n_z, lq) = (p.msg_z() as f64, p.n_z() as f64, p.log2_q);
    let bits = match (p.proto, p.e) {
        (Proto::Pi1, 0) => msg_z * lq + 2.0 * n_z * sigma_bits,
        (Proto::Pi2, 0) => {
            2.0 * msg_z * lq + 3.0 * n_z * sigma_bits + (p.kappa as f64 * D as f64 + D as f64) * lq
        }
        // Digit chains: responses go per digit (L smaller vectors per side)
        // and the digit statements (kappa ring rows per digit, both
        // combination sides) are carried in the proof.
        (Proto::Pi1, _) => {
            let resp = 2.0 * p.l_dig as f64 * n_z * sigma_bits;
            let stmts = p.l_dig as f64 * p.kappa as f64 * D as f64 * lq;
            msg_z * lq + resp + stmts
        }
        (Proto::Pi2, _) => {
            let resp = 3.0 * p.l_dig as f64 * n_z * sigma_bits;
            let stmts = 2.0 * p.l_dig as f64 * p.kappa as f64 * D as f64 * lq;
            2.0 * msg_z * lq + resp + (p.kappa as f64 * D as f64 + D as f64) * lq + stmts
        }
    };
    bits / 8.0 / 1024.0
}
