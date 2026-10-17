//! The fixed T32/d16/H2/KV1/dh8 layout and the DECLARED mask/CFS schedule of
//! the experimental private attention profile.
//!
//! Everything here is a function of the fixed geometry only: no proof value,
//! witness value or challenge moves a row, a site or a slot. The verifier and
//! the wire parser build every count from this file, never from a receipt.
//!
//! Schedule rules (ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md sections 1-4):
//! * every claim site has its OWN reserved mask pair (two fresh rows), used by
//!   exactly that one claim; a plane opened at k points has k pairs;
//! * every commitment has a dedicated proximity pair;
//! * the histograms are committed A rows, the LogUp identity is one value-0
//!   sum claim on H masked by a zero-sum pair `u` whose own terminal is masked
//!   by a fresh pair;
//! * eighteen CFS slots on one M (40 rows), 28 functionals in the fixed order
//!   `[Gamma_s if standalone] eval_s ... then one batched Gamma per host`.
//!
//! RECORDED DEVIATION from `zk60_private_attention_schedule.json`: that file
//! numbers rows of the legacy `AttnLayout` (both norm sites, residual 2, the
//! FFN seams, 65,536-entry range tables with block masks). This component is
//! the attention half only (x_in -> xres1) and ranges every value through the
//! single 256-entry `U8` table by byte limbs (the lever section 6 of the
//! construction records), so every table is ONE row and no block mask exists.
//! The slot list, host assignment, M shape and functional order are the
//! declared ones; the row numbering is this file's.

use crate::field::Fp2;

pub(crate) const T: usize = 32;
pub(crate) const D: usize = 16;
pub(crate) const H: usize = 2;
pub(crate) const DH: usize = 8;
pub(crate) const HALF: usize = DH / 2;
pub(crate) const KV: usize = 8;
pub(crate) const LOG_N: usize = 8;
pub(crate) const N: usize = 1 << LOG_N;

/// Fixed public calibration (private-block-kernel `calib`, attention half).
pub(crate) const NORM_TN: u32 = 11;
pub(crate) const NORM_CN: i64 = 1024;
pub(crate) const NORM_CEPS: i64 = 1;
pub(crate) const NORM_WRHO: u32 = 29;
pub(crate) const SH_QKV: u32 = 7;
pub(crate) const SH_ROPE: u32 = 7;
pub(crate) const SH_S: u32 = 6;
pub(crate) const SH_O: u32 = 9;
pub(crate) const SH_AO: u32 = 7;
pub(crate) const F_E: u32 = 9;
pub(crate) const F_P: u32 = 9;
pub(crate) const F_RO: u32 = 7;
pub(crate) const WRHO_S: u32 = 14;
pub(crate) const MASK_SCORE: i64 = -127;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Dom {
    /// rows: t (5 vars)
    T,
    /// (h, t) (6 vars)
    Ht,
    /// sixteen packed 32-entry limb sub-planes (9 vars)
    L,
    /// (t, i) (9 vars)
    D,
    /// (t, h, i') (9 vars) - same flat index as `D`
    Q,
    /// (t, i') (8 vars)
    Kv,
    /// (h, t, j) (11 vars)
    S,
    /// one 256-entry table row (8 vars)
    Tab,
}

impl Dom {
    pub(crate) fn log(self) -> usize {
        match self {
            Dom::T => 5,
            Dom::Ht => 6,
            Dom::L | Dom::D | Dom::Q => 9,
            Dom::Kv | Dom::Tab => 8,
            Dom::S => 11,
        }
    }
    pub(crate) fn len(self) -> usize {
        1usize << self.log()
    }
}

// ---- the A planes -----------------------------------------------------------
pub(crate) const A_D: usize = 0;
pub(crate) const A_DSQ: usize = 1;
// A_MX has no standalone range lookup; the exp deltas and an attainer of
// a bounded masked score fix its range through the lookup/selector relations.
pub(crate) const A_MX: usize = 2;
pub(crate) const A_SUM: usize = 3;
/// sub-plane k occupies entries [32k, 32k + 32): 0..3 d, 3..6 a1, 6..9 a2, rest zero
pub(crate) const A_LIMB: usize = 4;
pub(crate) const A_X: usize = 5;
pub(crate) const A_XL0: usize = 6;
pub(crate) const A_XL1: usize = 7;
pub(crate) const A_Y: usize = 8;
pub(crate) const A_NR0: usize = 9; // ..=12
pub(crate) const A_NS0: usize = 13; // ..=16
pub(crate) const A_AO: usize = 17;
pub(crate) const A_AL0: usize = 18;
pub(crate) const A_AL1: usize = 19;
pub(crate) const A_RAL: usize = 20;
pub(crate) const A_X1: usize = 21;
pub(crate) const A_X1L0: usize = 22;
pub(crate) const A_X1L1: usize = 23;
pub(crate) const A_Q8: usize = 24;
pub(crate) const A_RQL: usize = 25;
pub(crate) const A_QR8: usize = 26;
pub(crate) const A_RQRL: usize = 27;
pub(crate) const A_O8: usize = 28;
pub(crate) const A_RO0: usize = 29;
pub(crate) const A_RO1: usize = 30;
pub(crate) const A_K8: usize = 31;
pub(crate) const A_RKL: usize = 32;
pub(crate) const A_V8: usize = 33;
pub(crate) const A_RVL: usize = 34;
pub(crate) const A_KR8: usize = 35;
pub(crate) const A_RKRL: usize = 36;
pub(crate) const A_S8: usize = 37;
pub(crate) const A_RSL: usize = 38;
pub(crate) const A_ZSEL: usize = 39;
pub(crate) const A_E: usize = 40;
pub(crate) const A_P: usize = 41;
pub(crate) const A_PL0: usize = 42;
pub(crate) const A_PL1: usize = 43;
pub(crate) const A_SR0: usize = 44;
pub(crate) const A_SR1: usize = 45;
pub(crate) const A_SG0: usize = 46;
pub(crate) const A_SG1: usize = 47;
/// committed multiplicities of the two tables
pub(crate) const A_MU8: usize = 48;
pub(crate) const A_MEXP: usize = 49;
pub(crate) const N_A: usize = 50;
/// the planes the integer witness fills (the histograms are derived)
pub(crate) const N_WITNESS: usize = 48;
pub(crate) const N_LIMBS: usize = 9;

pub(crate) fn a_dom(plane: usize) -> Dom {
    match plane {
        A_D | A_DSQ => Dom::T,
        A_MX | A_SUM => Dom::Ht,
        A_LIMB => Dom::L,
        A_X..=A_X1L1 => Dom::D,
        A_Q8..=A_RO1 => Dom::Q,
        A_K8..=A_RKRL => Dom::Kv,
        A_S8..=A_SG1 => Dom::S,
        _ => Dom::Tab,
    }
}

// ---- the H planes (every one Fp2-valued: a `re` slice then an `im` slice) ----
pub(crate) const H_L: usize = 0;
pub(crate) const H_D0: usize = 1; // 10 helpers
pub(crate) const H_D_LAST: usize = 10;
pub(crate) const H_Q0: usize = 11; // 7
pub(crate) const H_Q_LAST: usize = 17;
pub(crate) const H_KV0: usize = 18; // 6
pub(crate) const H_KV_LAST: usize = 23;
pub(crate) const H_S0: usize = 24; // 7
pub(crate) const H_SEXP: usize = 31;
pub(crate) const H_GU8: usize = 32;
pub(crate) const H_GEXP: usize = 33;
/// the zero-sum pair `u`; its claim site's reserved pair is the fresh `u'`
pub(crate) const H_U: usize = 34;
pub(crate) const N_H: usize = 35;

pub(crate) fn h_dom(plane: usize) -> Dom {
    match plane {
        H_L => Dom::L,
        H_D0..=H_D_LAST => Dom::D,
        H_Q0..=H_Q_LAST => Dom::Q,
        H_KV0..=H_KV_LAST => Dom::Kv,
        H_S0..=H_SEXP => Dom::S,
        _ => Dom::Tab,
    }
}

// ---- lookups (all into the 256-entry U8 table; value = cst + sum coef * plane) ----
#[derive(Clone, Debug)]
pub(crate) struct Lk {
    pub terms: Vec<(usize, i64)>,
    pub cst: i64,
}

fn byte(p: usize) -> Lk {
    Lk { terms: vec![(p, 1)], cst: 0 }
}
/// `k * plane` in U8: with `byte(plane)` this bounds the plane below `256 / k`
fn scaled(p: usize, k: i64) -> Lk {
    Lk { terms: vec![(p, k)], cst: 0 }
}
/// the attention int8 subset [-127, 127]
fn sym(p: usize) -> [Lk; 2] {
    [Lk { terms: vec![(p, 1)], cst: 127 }, Lk { terms: vec![(p, -1)], cst: 127 }]
}

/// The U8 lookups of a domain, in helper order: helper k covers lookups
/// (2k, 2k + 1); an odd count leaves the last helper single.
///
/// CONSTRUCTION PREMISE (integer soundness; to be re-derived by the reviewer, not
/// checked by code). Every relation of `argument::define` is an identity between
/// integers only if no term wraps the 64-bit field. With every limb in [0, 256):
/// * x, ao, xres1 in int16 (two limbs, offset 32768); y, q8, k8, v8, qr8, kr8, s8,
///   o8 in [-127, 127] (`v + 127` and `127 - v` both bytes);
/// * D, a1, a2 < 2^24 (three limbs each), so D^2 + a1 < 2^49 equals sum x^2 + ceps
///   (< 2^35) over the integers, a2 = 2D - a1 >= 0 and a1 >= 0 give
///   D^2 <= ss <= D^2 + 2D, i.e. D = isqrt(ss), and ceps = 1 gives D >= 1;
/// * norm: |2 cn g x| < 2^34, y D 2^(tn+1) < 2^44, rho and sigma < 2^29 exactly
///   (top limb `8 * l3` a byte), so 0 <= rho <= den - 1 and y is the floor quotient;
/// * requant remainders are biased limbs: 7-bit (`2 l`), 6-bit (`4 l`), 9-bit
///   (l0 + 256 l1 with `128 l1` a byte), so r in [-2^(s-1), 2^(s-1)) exactly;
/// * softmax: p < 2^10 (`64 l1`); keep this bound because p = 512 is attained.
///   rho_s and sigma_s < 2^14 exactly (`4 l1`). The row-sum host and exp table
///   enforce Sum <= 2^14 (not a local limb bound), so p Sum + rho < 2^25 and
///   the quotient relation is over the
///   integers; off the causal support it forces p = rho = 0 because Sum >= 2^9 > 0
///   (some position ON the support has delta = 0, hence E[0] = 2^fE: the selected
///   one, or, if the selector sits on a masked position, the max is -127 and every
///   supported score equals it);
/// * delta in [0, 256) and E = exp[delta] come from the two-column exp lookup.
/// All bounds are far below p = 2^64 - 2^32 + 1; the matmul accumulators are
/// below 2^25. The LogUp multiplicities (at most 47,104) cannot wrap.
pub(crate) fn lookups(dom: Dom) -> Vec<Lk> {
    let mut v = Vec::new();
    match dom {
        Dom::L => v.push(byte(A_LIMB)),
        Dom::D => {
            v.extend([byte(A_XL0), byte(A_XL1)]);
            v.extend(sym(A_Y));
            v.extend((0..4).map(|k| byte(A_NR0 + k)));
            v.push(scaled(A_NR0 + 3, 1 << (32 - NORM_WRHO)));
            v.extend((0..4).map(|k| byte(A_NS0 + k)));
            v.push(scaled(A_NS0 + 3, 1 << (32 - NORM_WRHO)));
            v.extend([byte(A_AL0), byte(A_AL1), byte(A_RAL), scaled(A_RAL, 2), byte(A_X1L0), byte(A_X1L1)]);
        }
        Dom::Q => {
            v.extend(sym(A_Q8));
            v.extend([byte(A_RQL), scaled(A_RQL, 2)]);
            v.extend(sym(A_QR8));
            v.extend([byte(A_RQRL), scaled(A_RQRL, 2)]);
            v.extend(sym(A_O8));
            v.extend([byte(A_RO0), byte(A_RO1), scaled(A_RO1, 128)]);
        }
        Dom::Kv => {
            v.extend(sym(A_K8));
            v.extend([byte(A_RKL), scaled(A_RKL, 2)]);
            v.extend(sym(A_V8));
            v.extend([byte(A_RVL), scaled(A_RVL, 2)]);
            v.extend(sym(A_KR8));
            v.extend([byte(A_RKRL), scaled(A_RKRL, 2)]);
        }
        Dom::S => {
            v.extend(sym(A_S8));
            v.extend([byte(A_RSL), scaled(A_RSL, 4)]);
            v.extend([byte(A_PL0), byte(A_PL1), scaled(A_PL1, 64)]);
            v.extend([byte(A_SR0), byte(A_SR1), scaled(A_SR1, 4)]);
            v.extend([byte(A_SG0), byte(A_SG1), scaled(A_SG1, 4)]);
        }
        Dom::T | Dom::Ht | Dom::Tab => {}
    }
    v
}

/// (first H helper plane, helper count) of a lookup domain.
pub(crate) fn helpers(dom: Dom) -> (usize, usize) {
    match dom {
        Dom::L => (H_L, 1),
        Dom::D => (H_D0, 10),
        Dom::Q => (H_Q0, 7),
        Dom::Kv => (H_KV0, 6),
        Dom::S => (H_S0, 7),
        _ => (0, 0),
    }
}

pub(crate) const LOOKUP_DOMS: [Dom; 5] = [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S];

// ---- the CFS slots, in transcript order ---------------------------------------
pub(crate) const N_SLOTS: usize = 18;
pub(crate) const SC_SS: usize = 0;
pub(crate) const SC_TZC: usize = 1;
pub(crate) const SC_LZC: usize = 2;
pub(crate) const SC_RS: usize = 3;
pub(crate) const SC_QMM: usize = 4;
pub(crate) const SC_KMM: usize = 5;
pub(crate) const SC_VMM: usize = 6;
pub(crate) const SC_SCORE: usize = 7;
pub(crate) const SC_PV: usize = 8;
pub(crate) const SC_WO: usize = 9;
pub(crate) const SC_DZC: usize = 10;
pub(crate) const SC_QZC: usize = 11;
pub(crate) const SC_KVZC: usize = 12;
pub(crate) const SC_SZC: usize = 13;
pub(crate) const SC_TAB: usize = 14;
pub(crate) const SC_ZS: usize = 15;
pub(crate) const SC_IO_IN: usize = 16;
pub(crate) const SC_IO_OUT: usize = 17;

pub(crate) const SLOT_NAMES: [&str; N_SLOTS] = [
    "01 SS row sums (private)",
    "02 norm squares zero-check (hosts 01)",
    "08 limb zero-check",
    "07 masked row sums + selector (private)",
    "09Q matmul (private)",
    "09K matmul (private)",
    "09V matmul (private)",
    "10 score matmul (private, bilinear)",
    "11 PV matmul (private, bilinear)",
    "12 Wo matmul (private)",
    "03 D zero-check (hosts 12)",
    "04 Q zero-check (hosts 09Q, 11)",
    "05 KV zero-check (hosts 09K, 09V)",
    "06 softmax zero-check (hosts 07, 10)",
    "TAB table helper zero-check",
    "ZS zero-sum row",
    "IO-in endpoint equality",
    "IO-out endpoint equality",
];

/// (main rounds, extension rounds, degree)
pub(crate) const SLOTS: [(usize, usize, usize); N_SLOTS] = [
    (9, 1, 3),
    (5, 1, 3),
    (9, 1, 3),
    (11, 1, 3),
    (4, 1, 2),
    (4, 1, 2),
    (4, 1, 2),
    (3, 2, 2),
    (5, 2, 2),
    (4, 1, 2),
    (9, 1, 4),
    (9, 1, 4),
    (8, 1, 4),
    (11, 1, 4),
    (8, 1, 3),
    (8, 1, 2),
    (9, 1, 2),
    (9, 1, 2),
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum SlotKind {
    /// publishes ONE masked scalar `s + c G`; its total appears only inside its host's Gamma
    Private,
    /// public zero claimed sum; publishes `Gamma = c G`
    Standalone,
    /// claimed sum `sum nu kappa claim_s + Gamma_host`
    Host,
}

pub(crate) const SLOT_KINDS: [SlotKind; N_SLOTS] = [
    SlotKind::Private,
    SlotKind::Host,
    SlotKind::Standalone,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Standalone,
    SlotKind::Standalone,
    SlotKind::Standalone,
    SlotKind::Standalone,
];

/// host slot -> the private slots it hosts (every private slot exactly once)
pub(crate) const HOSTS: [(usize, &[usize]); 5] = [
    (SC_TZC, &[SC_SS]),
    (SC_DZC, &[SC_WO]),
    (SC_QZC, &[SC_QMM, SC_PV]),
    (SC_KVZC, &[SC_KMM, SC_VMM]),
    (SC_SZC, &[SC_RS, SC_SCORE]),
];

/// claim sites per slot on A and on H (each one reserved mask pair)
pub(crate) const A_SITES: [usize; N_SLOTS] = [1, 11, 1, 2, 1, 1, 1, 2, 2, 1, 20, 8, 7, 13, 2, 0, 1, 1];
pub(crate) const H_SITES: [usize; N_SLOTS] = [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 10, 7, 6, 8, 2, 1, 0, 0];
/// column-weight groups of the single A / H openings (checked by the prover
/// against the PCS's own grouping; the wire shape uses them)
pub(crate) const A_GROUPS: usize = 30;
pub(crate) const H_GROUPS: usize = 8;
pub(crate) const N_FUNCTIONALS: usize = 28;
pub(crate) const M_ROWS: usize = 2 * N_SLOTS + 4;

/// private terminals a slot publishes (A sites, H sites, one endpoint terminal for IO)
pub(crate) fn slot_terms(slot: usize) -> usize {
    A_SITES[slot] + H_SITES[slot] + usize::from(slot >= SC_IO_IN)
}

pub(crate) fn mask_specs() -> Vec<(usize, usize)> {
    SLOTS.iter().map(|&(n, e, d)| (n + e, d)).collect()
}

fn rows_of(log: usize) -> usize {
    (1usize << log).div_ceil(N)
}

pub(crate) struct Layout {
    /// element offset of every A plane (row aligned)
    pub a_off: Vec<usize>,
    pub a_data_rows: usize,
    pub a_mask_base: usize,
    pub a_prox: usize,
    pub a_rows: usize,
    /// (re, im) element offsets of every H plane
    pub h_off: Vec<(usize, usize)>,
    pub h_data_rows: usize,
    pub h_mask_base: usize,
    pub h_prox: usize,
    pub h_rows: usize,
    a_prefix: [usize; N_SLOTS + 1],
    h_prefix: [usize; N_SLOTS + 1],
}

impl Layout {
    pub(crate) fn new() -> Layout {
        let mut row = 0usize;
        let mut a_off = Vec::with_capacity(N_A);
        for p in 0..N_A {
            a_off.push(row * N);
            row += rows_of(a_dom(p).log());
        }
        let a_data_rows = row;
        let mut a_prefix = [0usize; N_SLOTS + 1];
        let mut h_prefix = [0usize; N_SLOTS + 1];
        for s in 0..N_SLOTS {
            a_prefix[s + 1] = a_prefix[s] + A_SITES[s];
            h_prefix[s + 1] = h_prefix[s] + H_SITES[s];
        }
        let a_mask_base = a_data_rows;
        let a_prox = a_mask_base + 2 * a_prefix[N_SLOTS];
        let a_rows = a_prox + 2;
        let mut row = 0usize;
        let mut h_off = Vec::with_capacity(N_H);
        for p in 0..N_H {
            let r = rows_of(h_dom(p).log());
            h_off.push((row * N, (row + r) * N));
            row += 2 * r;
        }
        let h_data_rows = row;
        let h_mask_base = h_data_rows;
        let h_prox = h_mask_base + 2 * h_prefix[N_SLOTS];
        let h_rows = h_prox + 2;
        Layout { a_off, a_data_rows, a_mask_base, a_prox, a_rows, h_off, h_data_rows, h_mask_base, h_prox, h_rows, a_prefix, h_prefix }
    }

    /// first row of the reserved pair of A site `k` of `slot`
    pub(crate) fn a_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= A_SITES[slot] {
            return Err(format!("private attention: undeclared A site {k} in slot {slot}"));
        }
        Ok(self.a_mask_base + 2 * (self.a_prefix[slot] + k))
    }
    pub(crate) fn h_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= H_SITES[slot] {
            return Err(format!("private attention: undeclared H site {k} in slot {slot}"));
        }
        Ok(self.h_mask_base + 2 * (self.h_prefix[slot] + k))
    }
    /// every reserved claim-pair row of A / of H (the proximity pairs excluded)
    pub(crate) fn a_site_rows(&self) -> Vec<usize> {
        (self.a_mask_base..self.a_prox).collect()
    }
    pub(crate) fn h_site_rows(&self) -> Vec<usize> {
        (self.h_mask_base..self.h_prox).collect()
    }
    /// the two zero-sum rows `u`
    pub(crate) fn h_u_rows(&self) -> [usize; 2] {
        let (re, im) = self.h_off[H_U];
        [re / N, im / N]
    }
    pub(crate) fn limb_off(&self, k: usize) -> usize {
        self.a_off[A_LIMB] + k * T
    }

    /// The declared schedule, line by line; its digest is transcript-bound.
    pub(crate) fn describe(&self) -> Vec<String> {
        let mut out = vec![
            format!("private-attention-t32/1: T{T} d{D} H{H} KV1 dh{DH}; n={N} inv_rate=8 Q=256; P1 (weights public, no W commitment)"),
            format!("A rows={} data={} site-pairs={} prox-pair=({},{})", self.a_rows, self.a_data_rows, self.a_prefix[N_SLOTS], self.a_prox, self.a_prox + 1),
            format!("H rows={} data={} site-pairs={} zero-sum-pair={:?} prox-pair=({},{})", self.h_rows, self.h_data_rows, self.h_prefix[N_SLOTS], self.h_u_rows(), self.h_prox, self.h_prox + 1),
            format!("M rows={M_ROWS} functionals={N_FUNCTIONALS} A-groups={A_GROUPS} H-groups={H_GROUPS} collapse=0"),
            format!(
                "calibration: norm tn={NORM_TN} cn={NORM_CN} ceps={NORM_CEPS} wrho={NORM_WRHO}; shifts qkv={SH_QKV} rope={SH_ROPE} score={SH_S} o={SH_O} ao={SH_AO} residual=0; fE={F_E} fP={F_P} fRo={F_RO} wrhoS={WRHO_S} mask={MASK_SCORE}; classes int8=[-127,127] int16; tables U8 + exp"
            ),
        ];
        for s in 0..N_SLOTS {
            let (n, e, d) = SLOTS[s];
            out.push(format!("slot {s:02} [{}] main={n} ext={e} degree={d} kind={:?} A-sites={} H-sites={}", SLOT_NAMES[s], SLOT_KINDS[s], A_SITES[s], H_SITES[s]));
        }
        for (host, hosted) in HOSTS {
            out.push(format!("host {host:02} <- {hosted:?}"));
        }
        out
    }

    pub(crate) fn schedule_digest(&self) -> [u8; 32] {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-attention-schedule/1");
        for line in self.describe() {
            h.update(&(line.len() as u64).to_le_bytes());
            h.update(line.as_bytes());
        }
        *h.finalize().as_bytes()
    }
}

/// 256^k as a field constant (k < 4)
pub(crate) fn pow256(k: usize) -> Fp2 {
    Fp2::from_u64(1u64 << (8 * k))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn declared_counts_are_self_consistent() {
        let lay = Layout::new();
        assert_eq!(A_SITES.iter().sum::<usize>(), 75);
        assert_eq!(H_SITES.iter().sum::<usize>(), 35);
        assert_eq!((lay.a_data_rows, lay.a_rows), (154, 154 + 150 + 2));
        assert_eq!((lay.h_data_rows, lay.h_rows), (218, 218 + 70 + 2));
        // 18 slots -> 36 coefficient rows + b_re, b_im, u_re, u_im
        assert_eq!(M_ROWS, 40);
        // one eval per slot, one Gamma per standalone slot, one batched Gamma per host
        let standalone = SLOT_KINDS.iter().filter(|k| **k == SlotKind::Standalone).count();
        assert_eq!(N_SLOTS + standalone + HOSTS.len(), N_FUNCTIONALS);
        // every private slot is hosted exactly once, by a Host slot
        let mut hosted = vec![0usize; N_SLOTS];
        for (host, list) in HOSTS {
            assert_eq!(SLOT_KINDS[host], SlotKind::Host);
            for &s in list {
                assert_eq!(SLOT_KINDS[s], SlotKind::Private);
                assert!(s < host, "a host runs after the slots it hosts");
                hosted[s] += 1;
            }
        }
        for s in 0..N_SLOTS {
            assert_eq!(hosted[s], usize::from(SLOT_KINDS[s] == SlotKind::Private));
        }
        // every mask row fits the M message: L + 256 pads <= 512
        for (n, d) in mask_specs() {
            assert!(n * d + 2 + 256 <= 512);
        }
        // helper planes cover the lookups pairwise
        for dom in LOOKUP_DOMS {
            assert_eq!(lookups(dom).len().div_ceil(2), helpers(dom).1);
        }
    }
}
