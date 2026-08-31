// [UPERF3-NN] U-PERF3 round 8, lane NN — X1: the attention ENTRY
// CLASSES + the toy-shape full-layer VALUE derivation
// (U_PERF3_ATTENTION_STATEMENT_DESIGN.md §5.1 X1; semantics
// ATTENTION_INTEGER_SPEC.md §2.1-2.9 adopted verbatim; the softmax
// block reuses ring/attn_softmax.rs = the X-S1 spike's oracle-exact
// chain). ADDITIVE, NO ENGINE CHANGE: nothing here is called by any
// shipped path; frozen registries (lookup.rs / manifest.rs) untouched
// — the rope/exp members below are LANE-LOCAL pending the AT-O5/O6
// freezes (open ruling recorded in the ledger).
//
// This module is the VALUE SIDE: the 66-entry table (AT-O2 ruled
// UNFUSED, spec §4.1 verbatim: witness 60 + weights 6), the seeded
// toy model (T = 16 value level / T = 32 proven level, d = 128,
// H = 2, H_kv = 1, d_h = 64), the rope-cs-table-v1 member
// (generation + digest, silu-v2 drift-loud discipline), and the full
// integer layer derivation that must bit-equal the Python reference
// (scripts/attention_x1_layer_ref.py driving the validated oracle
// scripts/attention_spec_spike.py primitives verbatim at patched toy
// constants). Claim-side wirings (PW builders, head-indexed
// instances, the per-head proofs) live in the bin's [UPERF3-NN]
// section.

use super::attn_softmax::{derive_chain, exp_table_digest, exp_table_generate, F_E, F_P};
pub use super::attn_softmax::HEAD_DIM;
use sha2::{Digest, Sha256};

/// Spec parameters beyond the X-S1 set (ATTENTION_INTEGER_SPEC.md §2).
pub const F_RO: i64 = 7; // RoPE cos/sin frac bits (public tables)
pub const ROPE_BASE: f64 = 10000.0;
pub const RMS_EPS: f64 = 1e-5;
pub const W_LIMB: u32 = 11; // RMSNorm remainder limb width (split rule W <= 14)

/// Toy shape (the X1 brief: T = 16, d_h = 64, 2 heads, GQA group 2).
pub const TOY_D: usize = 128; // = H * d_h so the concat closes the chain
pub const TOY_H: usize = 2;
pub const TOY_HKV: usize = 1;
pub const TOY_GQA_GROUP: usize = TOY_H / TOY_HKV;

/// Declared synthetic exponents (statement metadata; the calibrated
/// per-tensor exponents are DERIVED per draw by integer
/// max-calibration — the study's rule on the integer grid).
pub const E_X: i32 = -4; // input residual stream
pub const E_W: i32 = -9; // weight class (the study's measured class)
pub const E_GAMMA: i32 = -6; // gamma class (the oracle's convention)

fn round_half_up(x: f64) -> i64 {
    (x + 0.5).floor() as i64
}

pub fn bits_unsigned(v: i64) -> u32 {
    let mut w = 1u32;
    while ((1i64 << w) - 1) < v {
        w += 1;
    }
    w
}

pub fn bits_signed(v: i64) -> u32 {
    let mut w = 1u32;
    while ((1i64 << (w - 1)) - 1) < v {
        w += 1;
    }
    w
}

pub fn isqrt_i64(v: i64) -> i64 {
    assert!(v >= 0);
    let mut r = (v as f64).sqrt() as i64;
    while r > 0 && r * r > v {
        r -= 1;
    }
    while (r + 1) * (r + 1) <= v {
        r += 1;
    }
    r
}

/// Tagged SHA-256 counter stream (the X-S1 convention with a domain
/// tag): block i = SHA256(tag || le64(seed) || le64(i)). Mirrored
/// byte-for-byte by the Python reference driver.
pub fn seeded_bytes(tag: &str, seed: u64, n: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(n);
    let mut ctr = 0u64;
    while out.len() < n {
        let mut h = Sha256::new();
        h.update(tag.as_bytes());
        h.update(seed.to_le_bytes());
        h.update(ctr.to_le_bytes());
        let block: [u8; 32] = h.finalize().into();
        for &b in block.iter() {
            if out.len() == n {
                break;
            }
            out.push(b);
        }
        ctr += 1;
    }
    out
}

/// Full-range int8 draw: byte -> (b % 255) - 127 in [-127, 127].
pub fn seeded_i8(tag: &str, seed: u64, n: usize) -> Vec<i64> {
    seeded_bytes(tag, seed, n).into_iter().map(|b| (b % 255) as i64 - 127).collect()
}

/// Small-weight draw: byte -> (b % 33) - 16 in [-16, 16] (real
/// |W| <= 16 * 2^-9 = 0.031 — the study's weight RMS class, so the
/// derived score exponent lands in the measured eS range instead of
/// the degenerate one-hot regime).
pub fn seeded_w8(tag: &str, seed: u64, n: usize) -> Vec<i64> {
    seeded_bytes(tag, seed, n).into_iter().map(|b| (b % 33) as i64 - 16).collect()
}

/// Gamma draw: byte -> 49 + (b % 31) in [49, 79] (real ~[0.77, 1.23]
/// at eG = -6 — near-unity norm gains, the oracle's gamma class).
pub fn seeded_gamma(tag: &str, seed: u64, n: usize) -> Vec<i64> {
    seeded_bytes(tag, seed, n).into_iter().map(|b| 49 + (b % 31) as i64).collect()
}

// ---------------------------------------------------------------------------
// rope-cs-table-v1 (spec §2.3): PUBLIC integer cos/sin tables,
// generation + digest byte-compatible with the oracle's
// rope_tables_generate / rope_digest (drift-loud: the pinned digests
// below, generated on the PYTHON side, define the members).
// ---------------------------------------------------------------------------

pub fn rope_tables_generate(t_max: usize, head_dim: usize, base: f64, f_ro: i64) -> (Vec<i64>, Vec<i64>) {
    let half = head_dim / 2;
    let scale = (f_ro as f64).exp2();
    let mut c = vec![0i64; t_max * half];
    let mut s = vec![0i64; t_max * half];
    for i in 0..half {
        let theta = base.powf(-2.0 * (i as f64) / (head_dim as f64));
        for t in 0..t_max {
            let a = (t as f64) * theta;
            c[t * half + i] = round_half_up(a.cos() * scale);
            s[t * half + i] = round_half_up(a.sin() * scale);
        }
    }
    (c, s)
}

pub fn rope_digest(t_max: usize, head_dim: usize, base: f64, f_ro: i64, c: &[i64], s: &[i64]) -> [u8; 32] {
    let head = format!(
        "{{\"function\":\"rope-cs-table-v1\",\
         \"rope_base\":{base:?},\"head_dim\":{head_dim},\"t_max\":{t_max},\
         \"frac_bits\":{f_ro},\
         \"rounding\":\"c=round_half_up(cos(t*base^(-2i/head_dim))*2^frac_bits); s likewise\"}}"
    );
    let mut h = Sha256::new();
    h.update(head.as_bytes());
    for &v in c {
        h.update(v.to_le_bytes());
    }
    for &v in s {
        h.update(v.to_le_bytes());
    }
    h.finalize().into()
}

/// Lane-local PINNED rope members (t_max, d_h 64, base 10000.0,
/// fRo 7), digests generated by the Python reference driver
/// (`--pin-tables`) — the drift-loud freeze rows pending AT-O6.
pub const ROPE_T16_DIGEST_HEX: &str =
    "355be440fcc139858aee4451fa9874b8d2ef2eb9f8614993126a4ceecc10bcff";
pub const ROPE_T32_DIGEST_HEX: &str =
    "e0de1cf45aa38f101ad6d86fdccbf53b4a994afbb7f9dfd11f59f50dab03b2ef";

/// The CONTRACT-POINT exp member pin (eS -6, d_h 64, fE 9 — the toy
/// layer's calibrated eS at both T 16 and 32; generated by the Python
/// oracle's exp_table_digest, cross-confirmed by the byte-identical
/// layer-chain headers). Non-contract eS values run UNPINNED with a
/// loud stderr warning — the AM-2 (eS, d_h) member matrix is X2
/// output.
pub const X1_EXP_ESM6_DIGEST_HEX: &str =
    "062917d84faa9782970a7bf12ae35f331bc1d89c8a1c8a6820a7d5c9880aba42";

pub fn hex32(d: &[u8; 32]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

/// The lane-local rope member at t_max: generation checked against the
/// pinned digest where one exists (16/32); other t_max values print
/// nothing here — callers decide (the layer derivation refuses them).
pub fn rope_member(t_max: usize) -> (Vec<i64>, Vec<i64>, [u8; 32]) {
    let (c, s) = rope_tables_generate(t_max, HEAD_DIM, ROPE_BASE, F_RO);
    let d = rope_digest(t_max, HEAD_DIM, ROPE_BASE, F_RO, &c, &s);
    let pinned = match t_max {
        16 => Some(ROPE_T16_DIGEST_HEX),
        32 => Some(ROPE_T32_DIGEST_HEX),
        _ => None,
    };
    if let Some(p) = pinned {
        assert_eq!(hex32(&d), p, "rope-cs member (t_max {t_max}) drifted from the pinned digest");
    }
    (c, s, d)
}

// ---------------------------------------------------------------------------
// Requant / calibration primitives (contract C1 verbatim).
// ---------------------------------------------------------------------------

/// Floor requant: acc = 2^shift * y + r with r in [0, 2^shift).
pub fn floor_requant(acc: &[i64], shift: u32) -> (Vec<i64>, Vec<i64>) {
    let y: Vec<i64> = acc.iter().map(|&a| a >> shift).collect();
    let r: Vec<i64> = acc.iter().zip(y.iter()).map(|(&a, &q)| a - (q << shift)).collect();
    (y, r)
}

/// Integer max-calibration: the smallest shift whose floor-requant
/// output narrows to [-127, 127] (the study's smallest-e rule on the
/// integer grid; per-draw at toy shape, recorded in the ledger).
pub fn calib_shift(acc: &[i64]) -> u32 {
    let mx = acc.iter().copied().max().unwrap_or(0);
    let mn = acc.iter().copied().min().unwrap_or(0);
    let mut sh = 0u32;
    while (mx >> sh) > 127 || (mn >> sh) < -127 {
        sh += 1;
        assert!(sh < 48);
    }
    sh
}

pub fn assert_narrow_i8(v: &[i64], name: &str) {
    for &x in v {
        assert!((-127..=127).contains(&x), "{name}: narrowing fact fails ({x})");
    }
}

pub fn matmul_i64(a: &[i64], b: &[i64], rows: usize, inner: usize, cols: usize) -> Vec<i64> {
    let mut c = vec![0i64; rows * cols];
    for r in 0..rows {
        for k in 0..inner {
            let av = a[r * inner + k];
            if av == 0 {
                continue;
            }
            for j in 0..cols {
                c[r * cols + j] += av * b[k * cols + j];
            }
        }
    }
    c
}

// ---------------------------------------------------------------------------
// RMSNorm gadget (spec §2.1): isqrt fact pair + division relation +
// the (tn, Cn) window rule; e_y found by integer max-calibration
// (smallest e_y whose narrowing fact holds — monotone in e_y).
// ---------------------------------------------------------------------------

pub struct NormSite {
    pub xsq: Vec<i64>,
    pub ss: Vec<i64>, // SSe = SS + Ceps (committed as the SS entry, Ceps public)
    pub dd: Vec<i64>,
    pub dsq: Vec<i64>,
    pub a1: Vec<i64>,
    pub a2: Vec<i64>,
    pub y8: Vec<i64>,
    pub rho_lo: Vec<i64>,
    pub rho_hi: Vec<i64>,
    pub sig_lo: Vec<i64>,
    pub sig_hi: Vec<i64>,
    pub tn: u32,
    pub cn: i64,
    pub ceps: i64,
    pub e_y: i32,
    pub wrho: u32,
}

/// The window rule: tn = smallest integer >= 0 with
/// Cn = round_half_up(2^(tn+eG-eY) * sqrt(d)) >= 2^10; None if the
/// window [2^10, 2^11] cannot be met (base already too large at
/// tn = 0 — the e_y candidate is rejected).
pub fn rmsnorm_tn_cn(e_g: i32, e_y: i32, d: usize) -> Option<(u32, i64)> {
    let base = ((e_g - e_y) as f64).exp2() * (d as f64).sqrt();
    let mut tn = 0u32;
    while round_half_up((tn as f64).exp2() * base) < (1 << 10) {
        tn += 1;
        if tn > 40 {
            return None;
        }
    }
    let cn = round_half_up((tn as f64).exp2() * base);
    if !((1 << 10)..=(1 << 11)).contains(&cn) {
        return None;
    }
    Some((tn, cn))
}

pub fn rmsnorm_int(x8: &[i64], g8: &[i64], e_x: i32, e_g: i32, d: usize, name: &str) -> NormSite {
    let t = x8.len() / d;
    let xsq: Vec<i64> = x8.iter().map(|&v| v * v).collect();
    let ceps = std::cmp::max(1, round_half_up(RMS_EPS * (d as f64) * ((-2 * e_x) as f64).exp2()));
    let ss: Vec<i64> = (0..t)
        .map(|r| xsq[r * d..(r + 1) * d].iter().sum::<i64>() + ceps)
        .collect();
    let dd: Vec<i64> = ss.iter().map(|&v| isqrt_i64(v)).collect();
    let dsq: Vec<i64> = dd.iter().map(|&v| v * v).collect();
    let a1: Vec<i64> = ss.iter().zip(dsq.iter()).map(|(&s, &q)| s - q).collect();
    let a2: Vec<i64> = dd.iter().zip(a1.iter()).map(|(&v, &a)| 2 * v - a).collect();
    for (&v, nm) in a1.iter().zip(std::iter::repeat("a1")).chain(a2.iter().zip(std::iter::repeat("a2"))) {
        assert!((0..(1 << 14)).contains(&v), "{name}.isqrt.{nm}: w14 range fails ({v})");
    }
    let d_max = isqrt_i64((d as i64) * 127 * 127 + ceps);
    // e_y search: smallest e_y (window admissible) whose narrowing holds.
    let mut found: Option<(i32, u32, i64, Vec<i64>, Vec<i64>)> = None;
    for e_y in (e_g - 20)..=(e_g + 20) {
        let Some((tn, cn)) = rmsnorm_tn_cn(e_g, e_y, d) else { continue };
        assert!(127 * 127 * cn < (1i64 << 30) - 200, "{name}: num q31 non-wrap");
        assert!(127 * d_max * (1i64 << tn) < (1i64 << 30) - 200, "{name}: y*D*2^tn q31 non-wrap");
        let mut q = vec![0i64; t * d];
        let mut rho = vec![0i64; t * d];
        let mut ok = true;
        for r in 0..t {
            let div = dd[r] << tn;
            for j in 0..d {
                let num = x8[r * d + j] * g8[j] * cn;
                let qq = num.div_euclid(div);
                if !(-127..=127).contains(&qq) {
                    ok = false;
                    break;
                }
                q[r * d + j] = qq;
                rho[r * d + j] = num - qq * div;
            }
            if !ok {
                break;
            }
        }
        if ok {
            found = Some((e_y, tn, cn, q, rho));
            break;
        }
    }
    let (e_y, tn, cn, y8, rho) = found.unwrap_or_else(|| panic!("{name}: no admissible e_y"));
    let wrho = bits_unsigned(d_max * (1i64 << tn) - 1);
    let w_hi = wrho - W_LIMB;
    assert!(w_hi >= 1 && w_hi <= 14 && W_LIMB <= 14, "{name}: limb split {W_LIMB}+{w_hi}");
    let mut rho_lo = vec![0i64; t * d];
    let mut rho_hi = vec![0i64; t * d];
    let mut sig_lo = vec![0i64; t * d];
    let mut sig_hi = vec![0i64; t * d];
    for r in 0..t {
        let div = dd[r] << tn;
        for j in 0..d {
            let rr = rho[r * d + j];
            assert!((0..div).contains(&rr), "{name}.rho range");
            let sg = div - 1 - rr;
            rho_lo[r * d + j] = rr & ((1 << W_LIMB) - 1);
            rho_hi[r * d + j] = rr >> W_LIMB;
            sig_lo[r * d + j] = sg & ((1 << W_LIMB) - 1);
            sig_hi[r * d + j] = sg >> W_LIMB;
            assert!(rho_hi[r * d + j] < (1 << w_hi) && sig_hi[r * d + j] < (1 << w_hi));
        }
    }
    NormSite { xsq, ss, dd, dsq, a1, a2, y8, rho_lo, rho_hi, sig_lo, sig_hi, tn, cn, ceps, e_y, wrho }
}

// ---------------------------------------------------------------------------
// The 66-entry table (AT-O2: UNFUSED; spec §4.1 order, witness 60 +
// weights 6) and the full toy-layer derivation.
// ---------------------------------------------------------------------------

pub const X1_ENTRIES: [&str; 66] = [
    // attn_norm (11)
    "xsqA", "SSA", "DA", "DsqA", "a1A", "a2A", "xn8", "rhoA_lo", "rhoA_hi", "sigA_lo", "sigA_hi",
    // qkv (9)
    "Qacc", "q8", "rQ", "Kacc", "k8", "rK", "Vacc", "v8", "rV",
    // rope (6)
    "QRacc", "qr8", "rQR", "KRacc", "kr8", "rKR",
    // scores (3)
    "Sacc", "s8", "rS",
    // softmax (8)
    "m", "d", "zsel", "E", "Sum", "P", "rho", "sig",
    // pv (3)
    "Oacc", "o8", "rO",
    // wo (3)
    "AOacc", "ao8", "rAO",
    // resid1 (3)
    "xw1", "xres1", "rr1",
    // mlp_norm (11)
    "xsqM", "SSM", "DM", "DsqM", "a1M", "a2M", "xm8", "rhoM_lo", "rhoM_hi", "sigM_lo", "sigM_hi",
    // resid2 (3)
    "xw2", "xres2", "rr2",
    // weights (6)
    "Wq", "Wk", "Wv", "Wo", "gA", "gM",
];

/// Block names + per-block entry counts (the spec §4.1 census the
/// `entries` arm reconciles against).
pub const X1_BLOCKS: [(&str, usize); 11] = [
    ("attn_norm", 11),
    ("qkv", 9),
    ("rope", 6),
    ("scores", 3),
    ("softmax", 8),
    ("pv", 3),
    ("wo", 3),
    ("resid1", 3),
    ("mlp_norm", 11),
    ("resid2", 3),
    ("weights", 6),
];

/// (rows, cols) of entry `e` at sequence length t (toy dims).
pub fn x1_entry_shape(e: usize, t: usize) -> (usize, usize) {
    let d = TOY_D;
    let hq = TOY_H * HEAD_DIM;
    let hkv = TOY_HKV * HEAD_DIM;
    match X1_ENTRIES[e] {
        "SSA" | "DA" | "DsqA" | "a1A" | "a2A" | "SSM" | "DM" | "DsqM" | "a1M" | "a2M" => (t, 1),
        "xsqA" | "xn8" | "rhoA_lo" | "rhoA_hi" | "sigA_lo" | "sigA_hi" | "AOacc" | "ao8"
        | "rAO" | "xw1" | "xres1" | "rr1" | "xsqM" | "xm8" | "rhoM_lo" | "rhoM_hi" | "sigM_lo"
        | "sigM_hi" | "xw2" | "xres2" | "rr2" => (t, d),
        "Qacc" | "q8" | "rQ" | "QRacc" | "qr8" | "rQR" | "Oacc" | "o8" | "rO" => (t, hq),
        "Kacc" | "k8" | "rK" | "Vacc" | "v8" | "rV" | "KRacc" | "kr8" | "rKR" => (t, hkv),
        "Sacc" | "s8" | "rS" | "d" | "zsel" | "E" | "P" | "rho" | "sig" => (TOY_H * t, t),
        "m" | "Sum" => (TOY_H * t, 1),
        "Wq" => (d, hq),
        "Wk" | "Wv" => (d, hkv),
        "Wo" => (hq, d),
        "gA" | "gM" => (d, 1),
        _ => unreachable!(),
    }
}

/// Derived per-draw metadata (exponents/shifts/window constants) —
/// statement metadata exactly as the study's exponent table is.
pub struct X1Meta {
    pub e_xn: i32,
    pub tn_a: u32,
    pub cn_a: i64,
    pub ceps_a: i64,
    pub wrho_a: u32,
    pub sh_q: u32,
    pub e_q: i32,
    pub sh_k: u32,
    pub e_k: i32,
    pub sh_v: u32,
    pub e_v: i32,
    pub e_qr: i32,
    pub e_kr: i32,
    pub sh_s: u32,
    pub e_s: i32,
    pub exp_digest: [u8; 32],
    pub rope_dig: [u8; 32],
    pub sh_o: u32,
    pub e_o: i32,
    pub sh_ao: u32,
    pub e_ao: i32,
    pub sh_r1: u32,
    pub e_r1: i32,
    pub e_xm: i32,
    pub tn_m: u32,
    pub cn_m: i64,
    pub ceps_m: i64,
    pub wrho_m: u32,
    pub sh_r2: u32,
    pub e_r2: i32,
    pub wrho_sm: u32, // softmax remainder width fE + log2(T)
}

pub struct X1Layer {
    pub t: usize,
    pub x8: Vec<i64>, // the layer input (the FFN-17 "X" entry; context, not one of the 66)
    pub entries: Vec<Vec<i64>>,
    pub exp_tab: [i64; 256],
    pub meta: X1Meta,
}

impl X1Layer {
    pub fn entry(&self, name: &str) -> &[i64] {
        let i = X1_ENTRIES.iter().position(|&n| n == name).unwrap();
        &self.entries[i]
    }
    /// One head's TxT s8 block (row-major), for the per-head proven rung.
    pub fn s8_head(&self, h: usize) -> Vec<i64> {
        let t = self.t;
        self.entry("s8")[h * t * t..(h + 1) * t * t].to_vec()
    }
}

/// RoPE rotation accumulator per §2.3 (non-interleaved): tensor laid
/// out [t, heads*64] head-major; c/s tables [t, 32].
fn rope_acc(x8: &[i64], c: &[i64], s: &[i64], t: usize, heads: usize) -> Vec<i64> {
    let hd = HEAD_DIM;
    let half = hd / 2;
    let w = heads * hd;
    let mut acc = vec![0i64; t * w];
    for r in 0..t {
        for h in 0..heads {
            for i in 0..half {
                let lo = x8[r * w + h * hd + i];
                let hi = x8[r * w + h * hd + half + i];
                let cc = c[r * half + i];
                let ssn = s[r * half + i];
                acc[r * w + h * hd + i] = cc * lo - ssn * hi;
                acc[r * w + h * hd + half + i] = ssn * lo + cc * hi;
            }
        }
    }
    acc
}

/// The full toy attention-layer derivation under the exact integer
/// semantics (panics on any violated fact — fail-by-design). resid2
/// consumes a seeded synthetic FFN-out stand-in (recorded: the real
/// wiring is the X3 seam; the FFN block is MVP-1's statement).
pub fn derive_layer(seed: u64, t: usize) -> X1Layer {
    assert!(t == 16 || t == 32, "toy shapes: T in {{16, 32}} (pinned rope members)");
    let d = TOY_D;
    let hq = TOY_H * HEAD_DIM;
    let hkv = TOY_HKV * HEAD_DIM;
    let x8 = seeded_i8("x1-x", seed, t * d);
    let g_a = seeded_gamma("x1-gA", seed, d);
    let g_m = seeded_gamma("x1-gM", seed, d);
    let wq = seeded_w8("x1-wq", seed, d * hq);
    let wk = seeded_w8("x1-wk", seed, d * hkv);
    let wv = seeded_w8("x1-wv", seed, d * hkv);
    let wo = seeded_w8("x1-wo", seed, hq * d);

    // --- attn_norm --------------------------------------------------------
    let na = rmsnorm_int(&x8, &g_a, E_X, E_GAMMA, d, "anorm");
    let e_xn = na.e_y;

    // --- QKV + requant edges ---------------------------------------------
    let mm_cal = |a8: &[i64], w8: &[i64], inner: usize, cols: usize, e_a: i32, nm: &str| {
        let acc = matmul_i64(a8, w8, t, inner, cols);
        let sh = calib_shift(&acc);
        let (y, r) = floor_requant(&acc, sh);
        assert_narrow_i8(&y, nm);
        let e_y = e_a + E_W + sh as i32;
        (acc, y, r, sh, e_y)
    };
    let (qacc, q8, r_q, sh_q, e_q) = mm_cal(&na.y8, &wq, d, hq, e_xn, "q");
    let (kacc, k8, r_k, sh_k, e_k) = mm_cal(&na.y8, &wk, d, hkv, e_xn, "k");
    let (vacc, v8, r_v, sh_v, e_v) = mm_cal(&na.y8, &wv, d, hkv, e_xn, "v");

    // --- RoPE (scale-preserving requant by fRo) ---------------------------
    let (ctab, stab, rope_dig) = rope_member(t);
    let qracc = rope_acc(&q8, &ctab, &stab, t, TOY_H);
    let (qr8, r_qr) = floor_requant(&qracc, F_RO as u32);
    assert_narrow_i8(&qr8, "ropeq");
    let kracc = rope_acc(&k8, &ctab, &stab, t, TOY_HKV);
    let (kr8, r_kr) = floor_requant(&kracc, F_RO as u32);
    assert_narrow_i8(&kr8, "ropek");
    let (e_qr, e_kr) = (e_q, e_k);

    // --- scores (stacked over heads; public GQA map) + requant -----------
    let mut sacc = vec![0i64; TOY_H * t * t];
    for h in 0..TOY_H {
        let g = h / TOY_GQA_GROUP;
        for r in 0..t {
            for c in 0..t {
                let mut a = 0i64;
                for j in 0..HEAD_DIM {
                    a += qr8[r * hq + h * HEAD_DIM + j] * kr8[c * hkv + g * HEAD_DIM + j];
                }
                sacc[h * t * t + r * t + c] = a;
            }
        }
    }
    let sh_s = calib_shift(&sacc);
    let (s8, r_s) = floor_requant(&sacc, sh_s);
    assert_narrow_i8(&s8, "s");
    let e_s = e_qr + e_kr + sh_s as i32;

    // --- softmax per head (the X-S1 chain, spec §2.5 verbatim) -----------
    let exp_tab = exp_table_generate(e_s, HEAD_DIM, F_E);
    let exp_digest = exp_table_digest(e_s, HEAD_DIM, F_E, &exp_tab);
    if e_s == -6 {
        assert_eq!(
            hex32(&exp_digest),
            X1_EXP_ESM6_DIGEST_HEX,
            "exp member (eS -6) drifted from the pinned digest"
        );
    } else {
        eprintln!(
            "[UPERF3-NN] WARN: exp member eS {e_s} UNPINNED (lane-local pin exists only for the contract-point eS -6)"
        );
    }
    let n2 = t * t;
    let (mut m_v, mut d_v, mut z_v, mut e_v_t, mut sum_v, mut p_v, mut rho_v, mut sig_v) = (
        vec![0i64; TOY_H * t],
        vec![0i64; TOY_H * n2],
        vec![0i64; TOY_H * n2],
        vec![0i64; TOY_H * n2],
        vec![0i64; TOY_H * t],
        vec![0i64; TOY_H * n2],
        vec![0i64; TOY_H * n2],
        vec![0i64; TOY_H * n2],
    );
    for h in 0..TOY_H {
        let ch = derive_chain(t, &s8[h * n2..(h + 1) * n2], &exp_tab);
        m_v[h * t..(h + 1) * t].copy_from_slice(&ch.m);
        d_v[h * n2..(h + 1) * n2].copy_from_slice(&ch.d);
        z_v[h * n2..(h + 1) * n2].copy_from_slice(&ch.zsel);
        e_v_t[h * n2..(h + 1) * n2].copy_from_slice(&ch.e);
        sum_v[h * t..(h + 1) * t].copy_from_slice(&ch.sum);
        p_v[h * n2..(h + 1) * n2].copy_from_slice(&ch.p);
        rho_v[h * n2..(h + 1) * n2].copy_from_slice(&ch.rho);
        sig_v[h * n2..(h + 1) * n2].copy_from_slice(&ch.sigma);
    }
    let wrho_sm = (F_E as u32) + t.trailing_zeros();

    // --- PV (same GQA map on the V side) + requant ------------------------
    let mut oacc = vec![0i64; t * hq];
    for h in 0..TOY_H {
        let g = h / TOY_GQA_GROUP;
        for r in 0..t {
            for j in 0..HEAD_DIM {
                let mut a = 0i64;
                for c in 0..t {
                    a += p_v[h * n2 + r * t + c] * v8[c * hkv + g * HEAD_DIM + j];
                }
                oacc[r * hq + h * HEAD_DIM + j] = a;
            }
        }
    }
    let sh_o = calib_shift(&oacc);
    let (o8, r_o) = floor_requant(&oacc, sh_o);
    assert_narrow_i8(&o8, "o");
    let e_o = (e_v - F_P as i32) + sh_o as i32;

    // --- Wo + requant -----------------------------------------------------
    let aoacc = matmul_i64(&o8, &wo, t, hq, d);
    let sh_ao = calib_shift(&aoacc);
    let (ao8, r_ao) = floor_requant(&aoacc, sh_ao);
    assert_narrow_i8(&ao8, "ao");
    let e_ao = e_o + E_W + sh_ao as i32;

    // --- resid1 (scale-aligned exact add + requant) -----------------------
    let e_c1 = std::cmp::min(E_X, e_ao);
    let xw1: Vec<i64> = x8
        .iter()
        .zip(ao8.iter())
        .map(|(&a, &b)| (a << (E_X - e_c1)) + (b << (e_ao - e_c1)))
        .collect();
    let sh_r1 = calib_shift(&xw1);
    let (xres1, rr1) = floor_requant(&xw1, sh_r1);
    assert_narrow_i8(&xres1, "res1");
    let e_r1 = e_c1 + sh_r1 as i32;

    // --- mlp_norm ---------------------------------------------------------
    let nm = rmsnorm_int(&xres1, &g_m, e_r1, E_GAMMA, d, "mnorm");
    let e_xm = nm.e_y;

    // --- resid2 against the seeded FFN-out STAND-IN (X3 seam) -------------
    let ffn8 = seeded_i8("x1-ffn", seed, t * d); // declared at e_r1 (stand-in)
    let xw2: Vec<i64> = xres1.iter().zip(ffn8.iter()).map(|(&a, &b)| a + b).collect();
    let sh_r2 = calib_shift(&xw2);
    let (xres2, rr2) = floor_requant(&xw2, sh_r2);
    assert_narrow_i8(&xres2, "res2");
    let e_r2 = e_r1 + sh_r2 as i32;

    let entries: Vec<Vec<i64>> = vec![
        na.xsq, na.ss, na.dd, na.dsq, na.a1, na.a2, na.y8, na.rho_lo, na.rho_hi, na.sig_lo,
        na.sig_hi, qacc, q8, r_q, kacc, k8, r_k, vacc, v8, r_v, qracc, qr8, r_qr, kracc, kr8,
        r_kr, sacc, s8, r_s, m_v, d_v, z_v, e_v_t, sum_v, p_v, rho_v, sig_v, oacc, o8, r_o,
        aoacc, ao8, r_ao, xw1, xres1, rr1, nm.xsq, nm.ss, nm.dd, nm.dsq, nm.a1, nm.a2, nm.y8,
        nm.rho_lo, nm.rho_hi, nm.sig_lo, nm.sig_hi, xw2, xres2, rr2, wq, wk, wv, wo, g_a, g_m,
    ];
    assert_eq!(entries.len(), X1_ENTRIES.len());
    for (i, v) in entries.iter().enumerate() {
        let (r, c) = x1_entry_shape(i, t);
        assert_eq!(v.len(), r * c, "entry {} shape", X1_ENTRIES[i]);
    }
    X1Layer {
        t,
        x8,
        entries,
        exp_tab,
        meta: X1Meta {
            e_xn,
            tn_a: na.tn,
            cn_a: na.cn,
            ceps_a: na.ceps,
            wrho_a: na.wrho,
            sh_q,
            e_q,
            sh_k,
            e_k,
            sh_v,
            e_v,
            e_qr,
            e_kr,
            sh_s,
            e_s,
            exp_digest,
            rope_dig,
            sh_o,
            e_o,
            sh_ao,
            e_ao,
            sh_r1,
            e_r1,
            e_xm,
            tn_m: nm.tn,
            cn_m: nm.cn,
            ceps_m: nm.ceps,
            wrho_m: nm.wrho,
            sh_r2,
            e_r2,
            wrho_sm,
        },
    }
}

/// The layer-chain header lines shared BYTE-FOR-BYTE with the Python
/// reference driver (the diffable contract of acceptance (c)).
pub fn layer_header_lines(seed: u64, lay: &X1Layer) -> Vec<String> {
    let m = &lay.meta;
    vec![
        format!(
            "[UPERF3-NN] layer-chain seed {seed} t {} d {TOY_D} H {TOY_H} Hkv {TOY_HKV} dh {HEAD_DIM} fE {F_E} fP {F_P} fRo {F_RO}",
            lay.t
        ),
        format!(
            "  params eX {E_X} eW {E_W} eG {E_GAMMA} | anorm eXn {} tn {} cn {} ceps {} wrho {}",
            m.e_xn, m.tn_a, m.cn_a, m.ceps_a, m.wrho_a
        ),
        format!(
            "  qkv shQ {} eQ {} shK {} eK {} shV {} eV {}",
            m.sh_q, m.e_q, m.sh_k, m.e_k, m.sh_v, m.e_v
        ),
        format!("  rope eQr {} eKr {} ropedig {}", m.e_qr, m.e_kr, hex32(&m.rope_dig)),
        format!(
            "  scores shS {} eS {} wrhoSm {} expdig {}",
            m.sh_s, m.e_s, m.wrho_sm, hex32(&m.exp_digest)
        ),
        format!(
            "  pv shO {} eO {} | wo shAO {} eAo {} | res1 shR1 {} eR1 {}",
            m.sh_o, m.e_o, m.sh_ao, m.e_ao, m.sh_r1, m.e_r1
        ),
        format!(
            "  mnorm eXm {} tn {} cn {} ceps {} wrho {} | res2 shR2 {} eR2 {}",
            m.e_xm, m.tn_m, m.cn_m, m.ceps_m, m.wrho_m, m.sh_r2, m.e_r2
        ),
    ]
}
