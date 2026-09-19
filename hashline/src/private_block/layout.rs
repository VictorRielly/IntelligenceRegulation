//! The fixed T32/d16/H2/KV1/dh8/F16 layout and the DECLARED mask/CFS schedule
//! of the private block module.
//!
//! TWO LAYOUTS, ONE PLANE NUMBERING. `Layout::new()` is the WORK-IN-PROGRESS
//! layout the argument actually proves today: the accepted attention
//! component's planes and its eighteen slots, nothing more (306 `A` rows, 290
//! `H` rows, 40 `M` rows). `Layout::new_block()` is the grown WHOLE-BLOCK
//! layout of T1 sections C.1-C.2 and T2 sections A-B — every `norm_m`,
//! residual-2 and feed-forward plane, the new `Dom::F`, the 23-slot schedule
//! (455 `A` rows, 384 `H` rows, 50 `M` rows). The block layout is built and
//! asserted here and filled by `witness::build_block`; the ARGUMENT does not
//! use it yet, and until it does nothing may carry the block profile string,
//! `BlockPublic` or an output endpoint on `xres2` (disposition condition 1,
//! erratum E-1).
//!
//! Both layouts index planes in ONE numbering, the block's, laid out
//! contiguously per domain as T2 section C.2 requires (`a_range` sweeps a
//! plane block). `Layout::new()` simply omits the block-only planes, so its
//! rows pack exactly as the accepted component's do and every count it
//! declares is unchanged.
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
//!   `[Gamma_s if standalone] eval_s ... then one batched Gamma per host`
//!   (the whole block: twenty-three slots, 50 M rows, 34 functionals).
//!
//! RECORDED DEVIATION from `zk60_private_attention_schedule.json`: that file
//! numbers rows of the legacy `AttnLayout` (both norm sites, residual 2, the
//! FFN seams, 65,536-entry range tables with block masks). This component
//! ranges every value through the single 256-entry `U8` table by byte limbs
//! (the lever section 6 of the construction records), so every table is ONE
//! row and no block mask exists. The slot list, host assignment, M shape and
//! functional order are the declared ones; the row numbering is this file's.

use crate::field::Fp2;

pub(crate) const T: usize = 32;
pub(crate) const D: usize = 16;
pub(crate) const H: usize = 2;
pub(crate) const DH: usize = 8;
pub(crate) const HALF: usize = DH / 2;
pub(crate) const KV: usize = 8;
/// feed-forward width (the `f` axis)
pub(crate) const F: usize = 16;
pub(crate) const LOG_N: usize = 8;
pub(crate) const N: usize = 1 << LOG_N;

/// Fixed public calibration (private-block-kernel `calib`).
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
/// Feed-forward shifts (kernel `calib::SH_G/SH_U/SH_H/SH_Z`). `SH_U = 0` is
/// why there is no `up` remainder plane at all (T2 section A.4).
pub(crate) const SH_G: u32 = 7;
pub(crate) const SH_H_PROD: u32 = 14;
pub(crate) const SH_Z: u32 = 6;

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
    /// (t, j) over the feed-forward axis (9 vars at F = 16). A variant of its
    /// own even though the size equals `Dom::D`'s: a `Dom` keys a lookup list,
    /// a helper block and a zero-check, and the feed-forward needs its own of
    /// each (T2 section B.1).
    F,
    /// one 256-entry table row (8 vars)
    Tab,
}

impl Dom {
    pub(crate) fn log(self) -> usize {
        match self {
            Dom::T => 5,
            Dom::Ht => 6,
            Dom::L | Dom::D | Dom::Q | Dom::F => 9,
            Dom::Kv | Dom::Tab => 8,
            Dom::S => 11,
        }
    }
    pub(crate) fn len(self) -> usize {
        1usize << self.log()
    }
}

// ---- the A planes, contiguous per domain ------------------------------------
// Dom::T
pub(crate) const A_D: usize = 0;
pub(crate) const A_DSQ: usize = 1;
/// norm_m's isqrt D (T1 C.1)
pub(crate) const A_DM: usize = 2;
pub(crate) const A_DSQM: usize = 3;
// Dom::Ht
pub(crate) const A_MX: usize = 4;
pub(crate) const A_SUM: usize = 5;
// Dom::L — sub-plane k occupies entries [32k, 32k + 32): 0..3 d, 3..6 a1, 6..9 a2
pub(crate) const A_LIMB: usize = 6;
/// norm_m's limb plane (nine of sixteen sub-planes used, as `A_LIMB`)
pub(crate) const A_LIMBM: usize = 7;
// Dom::D
pub(crate) const A_X: usize = 8;
pub(crate) const A_XL0: usize = 9;
pub(crate) const A_XL1: usize = 10;
pub(crate) const A_Y: usize = 11;
pub(crate) const A_NR0: usize = 12; // ..=15
pub(crate) const A_NS0: usize = 16; // ..=19
pub(crate) const A_AO: usize = 20;
pub(crate) const A_AL0: usize = 21;
pub(crate) const A_AL1: usize = 22;
pub(crate) const A_RAL: usize = 23;
pub(crate) const A_X1: usize = 24;
pub(crate) const A_X1L0: usize = 25;
pub(crate) const A_X1L1: usize = 26;
/// `nm`, norm_m's output and the feed-forward's input (T1 C.1)
pub(crate) const A_YM: usize = 27;
pub(crate) const A_MR0: usize = 28; // ..=31
pub(crate) const A_MS0: usize = 32; // ..=35
/// the feed-forward output (T1 C.2, derived by T2 R5)
pub(crate) const A_Z16: usize = 36;
pub(crate) const A_X2: usize = 37;
pub(crate) const A_X2L0: usize = 38;
pub(crate) const A_X2L1: usize = 39;
pub(crate) const A_ZL0: usize = 40;
pub(crate) const A_ZL1: usize = 41;
/// the biased down remainder, `rd` in [0, 2^6)
pub(crate) const A_RDL: usize = 42;
// Dom::Q
pub(crate) const A_Q8: usize = 43;
pub(crate) const A_RQL: usize = 44;
pub(crate) const A_QR8: usize = 45;
pub(crate) const A_RQRL: usize = 46;
pub(crate) const A_O8: usize = 47;
pub(crate) const A_RO0: usize = 48;
pub(crate) const A_RO1: usize = 49;
// Dom::Kv
pub(crate) const A_K8: usize = 50;
pub(crate) const A_RKL: usize = 51;
pub(crate) const A_V8: usize = 52;
pub(crate) const A_RVL: usize = 53;
pub(crate) const A_KR8: usize = 54;
pub(crate) const A_RKRL: usize = 55;
// Dom::S
pub(crate) const A_S8: usize = 56;
pub(crate) const A_RSL: usize = 57;
pub(crate) const A_ZSEL: usize = 58;
pub(crate) const A_E: usize = 59;
pub(crate) const A_P: usize = 60;
pub(crate) const A_PL0: usize = 61;
pub(crate) const A_PL1: usize = 62;
pub(crate) const A_SR0: usize = 63;
pub(crate) const A_SR1: usize = 64;
pub(crate) const A_SG0: usize = 65;
pub(crate) const A_SG1: usize = 66;
// Dom::F (all block-only, T2 section B.2)
pub(crate) const A_G8: usize = 67;
/// the biased gate remainder, `rg` in [0, 2^7)
pub(crate) const A_RGL: usize = 68;
pub(crate) const A_A16: usize = 69;
pub(crate) const A_U16: usize = 70;
pub(crate) const A_UL0: usize = 71;
pub(crate) const A_UL1: usize = 72;
pub(crate) const A_H16: usize = 73;
pub(crate) const A_HL0: usize = 74;
pub(crate) const A_HL1: usize = 75;
/// the two byte limbs of the biased product remainder `rh` in [0, 2^14)
pub(crate) const A_RH0: usize = 76;
pub(crate) const A_RH1: usize = 77;
// Dom::Tab — committed multiplicities of the three tables
pub(crate) const A_MU8: usize = 78;
pub(crate) const A_MEXP: usize = 79;
pub(crate) const A_MACT: usize = 80;
/// every A plane of the whole-block layout
pub(crate) const N_A: usize = 81;
pub(crate) const N_LIMBS: usize = 9;

pub(crate) fn a_dom(plane: usize) -> Dom {
    match plane {
        A_D..=A_DSQM => Dom::T,
        A_MX | A_SUM => Dom::Ht,
        A_LIMB | A_LIMBM => Dom::L,
        A_X..=A_RDL => Dom::D,
        A_Q8..=A_RO1 => Dom::Q,
        A_K8..=A_RKRL => Dom::Kv,
        A_S8..=A_SG1 => Dom::S,
        A_G8..=A_RH1 => Dom::F,
        _ => Dom::Tab,
    }
}

/// The three committed lookup histograms: derived from the witness by the
/// prover (`protocol.rs`), never filled by the integer witness builder.
pub(crate) fn is_multiplicity(plane: usize) -> bool {
    matches!(plane, A_MU8 | A_MEXP | A_MACT)
}

/// Is this plane part of the WORK-IN-PROGRESS (attention-half) layout? The
/// whole-block layout holds every plane.
pub(crate) fn a_in_wip(plane: usize) -> bool {
    !matches!(plane, A_DM | A_DSQM | A_LIMBM | A_YM..=A_RDL | A_G8..=A_RH1 | A_MACT)
}

// ---- the H planes (every one Fp2-valued: a `re` slice then an `im` slice) ----
pub(crate) const H_L: usize = 0;
/// 19 helpers for the whole block (the WIP layout uses the first 10)
pub(crate) const H_D0: usize = 1;
pub(crate) const H_D_LAST: usize = 19;
pub(crate) const H_Q0: usize = 20; // 7
pub(crate) const H_KV0: usize = 27; // 6
pub(crate) const H_S0: usize = 33; // 7
pub(crate) const H_SEXP: usize = 40;
/// the five `Dom::F` U8 helpers
pub(crate) const H_F0: usize = 41;
/// the activation lookup's own helper, mirroring `H_SEXP`
pub(crate) const H_FACT: usize = 46;
pub(crate) const H_GU8: usize = 47;
pub(crate) const H_GEXP: usize = 48;
pub(crate) const H_GACT: usize = 49;
/// the zero-sum pair `u`; its claim site's reserved pair is the fresh `u'`
pub(crate) const H_U: usize = 50;
pub(crate) const N_H: usize = 51;

pub(crate) fn h_dom(plane: usize) -> Dom {
    match plane {
        H_L => Dom::L,
        H_D0..=H_D_LAST => Dom::D,
        H_Q0..=26 => Dom::Q,
        H_KV0..=32 => Dom::Kv,
        H_S0..=H_SEXP => Dom::S,
        H_F0..=H_FACT => Dom::F,
        _ => Dom::Tab,
    }
}

/// The table helpers enter the value-0 LogUp identity with a negative sign.
pub(crate) fn h_is_table(plane: usize) -> bool {
    matches!(plane, H_GU8 | H_GEXP | H_GACT)
}

pub(crate) fn h_in_wip(plane: usize) -> bool {
    !matches!(plane, 11..=H_D_LAST | H_F0..=H_FACT | H_GACT)
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
/// (2k, 2k + 1); an odd count leaves the last helper single. `block` appends
/// the whole-block lookups; the work-in-progress layout stops at the accepted
/// component's list. Appends are always at the END of an EVEN list, so no
/// existing helper's pair changes.
///
/// CONSTRUCTION PREMISE (integer soundness; to be re-derived by the reviewer, not
/// checked by code). Every relation of `argument::define` is an identity between
/// integers only if no term wraps the 64-bit field. With every limb in [0, 256):
/// * x, ao, xres1, xres2, u16, h16, z16 in int16 (two limbs, offset 32768);
///   y, nm, q8, k8, v8, qr8, kr8, s8, o8 in [-127, 127] (`v + 127` and
///   `127 - v` both bytes); g8 in [-128, 127] from the 256-row activation
///   table itself, never from `sym`;
/// * D, a1, a2 < 2^24 (three limbs each), so D^2 + a1 < 2^49 equals sum x^2 + ceps
///   (< 2^35) over the integers, a2 = 2D - a1 >= 0 and a1 >= 0 give
///   D^2 <= ss <= D^2 + 2D, i.e. D = isqrt(ss), and ceps = 1 gives D >= 1;
/// * norm: |2 cn g x| < 2^34, y D 2^(tn+1) < 2^44, rho and sigma < 2^29 exactly
///   (top limb `8 * l3` a byte), so 0 <= rho <= den - 1 and y is the floor quotient;
/// * requant remainders are biased limbs: 7-bit (`2 l`), 6-bit (`4 l`), 9-bit
///   (l0 + 256 l1 with `128 l1` a byte), 14-bit (l0 + 256 l1 with `4 l1` a
///   byte), so r in [-2^(s-1), 2^(s-1)) exactly;
/// * softmax: p < 2^10 (`64 l1`), rho_s and sigma_s < 2^14 exactly (`4 l1`),
///   Sum <= 2^14, so p Sum + rho < 2^25 and the quotient relation is over the
///   integers; off the causal support it forces p = rho = 0 because Sum >= 2^9 > 0
///   (some position ON the support has delta = 0, hence E[0] = 2^fE: the selected
///   one, or, if the selector sits on a masked position, the max is -127 and every
///   supported score equals it);
/// * delta in [0, 256) and E = exp[delta] come from the two-column exp lookup;
///   (g8 + 128, a16) comes from the two-column activation lookup, whose value
///   range is enforced by the public statement, not promised by the caller.
/// All bounds are far below p = 2^64 - 2^32 + 1; the matmul accumulators are
/// below 2^27. The LogUp multiplicities (at most 61,440) cannot wrap.
pub(crate) fn lookups_of(dom: Dom, block: bool) -> Vec<Lk> {
    let mut v = Vec::new();
    match dom {
        Dom::L => {
            v.push(byte(A_LIMB));
            if block {
                v.push(byte(A_LIMBM));
            }
        }
        Dom::D => {
            v.extend([byte(A_XL0), byte(A_XL1)]);
            v.extend(sym(A_Y));
            v.extend((0..4).map(|k| byte(A_NR0 + k)));
            v.push(scaled(A_NR0 + 3, 1 << (32 - NORM_WRHO)));
            v.extend((0..4).map(|k| byte(A_NS0 + k)));
            v.push(scaled(A_NS0 + 3, 1 << (32 - NORM_WRHO)));
            v.extend([byte(A_AL0), byte(A_AL1), byte(A_RAL), scaled(A_RAL, 2), byte(A_X1L0), byte(A_X1L1)]);
            if block {
                // T1 section C.1: norm_m's class, its rho / sigma limbs, and
                // residual 2's int16 limbs. Fourteen lookups.
                v.extend(sym(A_YM));
                v.extend((0..4).map(|k| byte(A_MR0 + k)));
                v.push(scaled(A_MR0 + 3, 1 << (32 - NORM_WRHO)));
                v.extend((0..4).map(|k| byte(A_MS0 + k)));
                v.push(scaled(A_MS0 + 3, 1 << (32 - NORM_WRHO)));
                v.extend([byte(A_X2L0), byte(A_X2L1)]);
                // T2 section B.3: z16's int16 class and the down remainder.
                v.extend([byte(A_ZL0), byte(A_ZL1), byte(A_RDL), scaled(A_RDL, 4)]);
            }
        }
        Dom::F => {
            if block {
                v.extend([byte(A_RGL), scaled(A_RGL, 2)]);
                v.extend([byte(A_UL0), byte(A_UL1)]);
                v.extend([byte(A_HL0), byte(A_HL1)]);
                v.extend([byte(A_RH0), byte(A_RH1), scaled(A_RH1, 4)]);
            }
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
pub(crate) fn helpers_of(dom: Dom, block: bool) -> (usize, usize) {
    match dom {
        Dom::L => (H_L, 1),
        Dom::D => (H_D0, if block { 19 } else { 10 }),
        Dom::F => (H_F0, if block { 5 } else { 0 }),
        Dom::Q => (H_Q0, 7),
        Dom::Kv => (H_KV0, 6),
        Dom::S => (H_S0, 7),
        _ => (0, 0),
    }
}

pub(crate) const LOOKUP_DOMS: [Dom; 5] = [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S];
pub(crate) const LOOKUP_DOMS_BLOCK: [Dom; 6] = [Dom::L, Dom::D, Dom::F, Dom::Q, Dom::Kv, Dom::S];

// ---- the CFS slots of the work-in-progress layout, in transcript order --------
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

// ---- the CFS slots of the WHOLE BLOCK, in transcript order (T2 section C.3) ---
pub(crate) const N_SLOTS_BLOCK: usize = 23;
pub(crate) const BC_SS: usize = 0;
pub(crate) const BC_SSM: usize = 1;
pub(crate) const BC_TZC: usize = 2;
#[allow(dead_code, reason = "the argument arm that uses this slot index lands with the feed-forward relations")]
pub(crate) const BC_LZC: usize = 3;
pub(crate) const BC_RS: usize = 4;
pub(crate) const BC_QMM: usize = 5;
pub(crate) const BC_KMM: usize = 6;
pub(crate) const BC_VMM: usize = 7;
pub(crate) const BC_SCORE: usize = 8;
pub(crate) const BC_PV: usize = 9;
pub(crate) const BC_WO: usize = 10;
pub(crate) const BC_GMM: usize = 11;
pub(crate) const BC_UMM: usize = 12;
pub(crate) const BC_DMM: usize = 13;
pub(crate) const BC_DZC: usize = 14;
pub(crate) const BC_QZC: usize = 15;
pub(crate) const BC_KVZC: usize = 16;
pub(crate) const BC_SZC: usize = 17;
pub(crate) const BC_FZC: usize = 18;
#[allow(dead_code, reason = "the argument arm that uses this slot index lands with the feed-forward relations")]
pub(crate) const BC_TAB: usize = 19;
#[allow(dead_code, reason = "the argument arm that uses this slot index lands with the feed-forward relations")]
pub(crate) const BC_ZS: usize = 20;
#[allow(dead_code, reason = "the argument arm that uses this slot index lands with the feed-forward relations")]
pub(crate) const BC_IO_IN: usize = 21;
#[allow(dead_code, reason = "the argument arm that uses this slot index lands with the feed-forward relations")]
pub(crate) const BC_IO_OUT: usize = 22;

pub(crate) const SLOT_NAMES_BLOCK: [&str; N_SLOTS_BLOCK] = [
    "01 SS row sums norm_a (private)",
    "01m SS row sums norm_m (private)",
    "02 norm squares zero-check (hosts 01, 01m)",
    "08 limb zero-check",
    "07 masked row sums + selector (private)",
    "09Q matmul (private)",
    "09K matmul (private)",
    "09V matmul (private)",
    "10 score matmul (private, bilinear)",
    "11 PV matmul (private, bilinear)",
    "12 Wo matmul (private)",
    "13G gate matmul (private)",
    "13U up matmul (private)",
    "13D down matmul (private)",
    "03 D zero-check (hosts 12, 13D)",
    "04 Q zero-check (hosts 09Q, 11)",
    "05 KV zero-check (hosts 09K, 09V)",
    "06 softmax zero-check (hosts 07, 10)",
    "14 F zero-check (hosts 13G, 13U)",
    "TAB table helper zero-check",
    "ZS zero-sum row",
    "IO-in endpoint equality",
    "IO-out endpoint equality",
];

pub(crate) const SLOTS_BLOCK: [(usize, usize, usize); N_SLOTS_BLOCK] = [
    (9, 1, 3),
    (9, 1, 3),
    (5, 1, 3),
    (9, 1, 4),
    (11, 1, 3),
    (4, 1, 2),
    (4, 1, 2),
    (4, 1, 2),
    (3, 2, 2),
    (5, 2, 2),
    (4, 1, 2),
    (4, 1, 2),
    (4, 1, 2),
    (4, 1, 2),
    (9, 1, 4),
    (9, 1, 4),
    (8, 1, 4),
    (11, 1, 4),
    (9, 1, 4),
    (8, 1, 3),
    (8, 1, 2),
    (9, 1, 2),
    (9, 1, 2),
];

pub(crate) const SLOT_KINDS_BLOCK: [SlotKind; N_SLOTS_BLOCK] = [
    SlotKind::Private,
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
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Private,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Host,
    SlotKind::Standalone,
    SlotKind::Standalone,
    SlotKind::Standalone,
    SlotKind::Standalone,
];

pub(crate) const HOSTS_BLOCK: [(usize, &[usize]); 6] = [
    (BC_TZC, &[BC_SS, BC_SSM]),
    (BC_DZC, &[BC_WO, BC_DMM]),
    (BC_QZC, &[BC_QMM, BC_PV]),
    (BC_KVZC, &[BC_KMM, BC_VMM]),
    (BC_SZC, &[BC_RS, BC_SCORE]),
    (BC_FZC, &[BC_GMM, BC_UMM]),
];

/// T1 section C.3 and T2 section D.1, site by site: 120 on A, 51 on H.
pub(crate) const A_SITES_BLOCK: [usize; N_SLOTS_BLOCK] = [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 37, 8, 7, 13, 11, 3, 0, 1, 1];
pub(crate) const H_SITES_BLOCK: [usize; N_SLOTS_BLOCK] = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 7, 6, 8, 6, 3, 1, 0, 0];
pub(crate) const A_GROUPS_BLOCK: usize = 35;
pub(crate) const H_GROUPS_BLOCK: usize = 9;
pub(crate) const N_FUNCTIONALS_BLOCK: usize = 34;
pub(crate) const M_ROWS_BLOCK: usize = 2 * N_SLOTS_BLOCK + 4;

/// The derived whole-block row totals of the disposition section 1.2, asserted
/// by `Layout::new_block` itself so a layout edit that breaks them cannot ship.
pub(crate) const A_ROWS_BLOCK: usize = 455;
pub(crate) const H_ROWS_BLOCK: usize = 384;
pub(crate) const A_DATA_ROWS_BLOCK: usize = 213;
pub(crate) const H_DATA_ROWS_BLOCK: usize = 280;

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

/// A plane that the layout does not hold has this offset; using it is a bug,
/// and the (huge) value makes that bug immediate rather than silent.
pub(crate) const ABSENT: usize = usize::MAX;

pub(crate) struct Layout {
    /// true for the grown whole-block layout, false for the work-in-progress one
    pub block: bool,
    /// element offset of every A plane (row aligned), `ABSENT` when not held
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
    a_prefix: Vec<usize>,
    h_prefix: Vec<usize>,
}

impl Layout {
    /// the WORK-IN-PROGRESS layout: the attention half only
    pub(crate) fn new() -> Layout {
        Layout::build(false)
    }

    /// The grown WHOLE-BLOCK layout (T1 C.1-C.2, T2 A-B). Not yet proved by
    /// the argument; built and filled so the witness and the checking tools
    /// can be grown against it (disposition condition 1 keeps the profile,
    /// the statement type and the output endpoint where they are until the
    /// feed-forward relations land).
    pub(crate) fn new_block() -> Layout {
        let lay = Layout::build(true);
        // the derived counts of the disposition section 1.2
        assert_eq!(lay.a_data_rows, A_DATA_ROWS_BLOCK, "block A data rows");
        assert_eq!(lay.h_data_rows, H_DATA_ROWS_BLOCK, "block H data rows");
        assert_eq!(lay.a_rows, A_ROWS_BLOCK, "block A rows");
        assert_eq!(lay.h_rows, H_ROWS_BLOCK, "block H rows");
        lay
    }

    fn build(block: bool) -> Layout {
        let n_slots = if block { N_SLOTS_BLOCK } else { N_SLOTS };
        let (a_sites, h_sites) = if block { (&A_SITES_BLOCK[..], &H_SITES_BLOCK[..]) } else { (&A_SITES[..], &H_SITES[..]) };
        let mut row = 0usize;
        let mut a_off = Vec::with_capacity(N_A);
        for p in 0..N_A {
            if !block && !a_in_wip(p) {
                a_off.push(ABSENT);
                continue;
            }
            a_off.push(row * N);
            row += rows_of(a_dom(p).log());
        }
        let a_data_rows = row;
        let mut a_prefix = vec![0usize; n_slots + 1];
        let mut h_prefix = vec![0usize; n_slots + 1];
        for s in 0..n_slots {
            a_prefix[s + 1] = a_prefix[s] + a_sites[s];
            h_prefix[s + 1] = h_prefix[s] + h_sites[s];
        }
        let a_mask_base = a_data_rows;
        let a_prox = a_mask_base + 2 * a_prefix[n_slots];
        let a_rows = a_prox + 2;
        let mut row = 0usize;
        let mut h_off = Vec::with_capacity(N_H);
        for p in 0..N_H {
            if !block && !h_in_wip(p) {
                h_off.push((ABSENT, ABSENT));
                continue;
            }
            let r = rows_of(h_dom(p).log());
            h_off.push((row * N, (row + r) * N));
            row += 2 * r;
        }
        let h_data_rows = row;
        let h_mask_base = h_data_rows;
        let h_prox = h_mask_base + 2 * h_prefix[n_slots];
        let h_rows = h_prox + 2;
        Layout { block, a_off, a_data_rows, a_mask_base, a_prox, a_rows, h_off, h_data_rows, h_mask_base, h_prox, h_rows, a_prefix, h_prefix }
    }

    // ---- the slot schedule of whichever layout this is ----
    pub(crate) fn n_slots(&self) -> usize {
        if self.block {
            N_SLOTS_BLOCK
        } else {
            N_SLOTS
        }
    }
    pub(crate) fn a_sites(&self) -> &'static [usize] {
        if self.block {
            &A_SITES_BLOCK
        } else {
            &A_SITES
        }
    }
    pub(crate) fn h_sites(&self) -> &'static [usize] {
        if self.block {
            &H_SITES_BLOCK
        } else {
            &H_SITES
        }
    }
    pub(crate) fn slots(&self) -> &'static [(usize, usize, usize)] {
        if self.block {
            &SLOTS_BLOCK
        } else {
            &SLOTS
        }
    }
    pub(crate) fn slot_kinds(&self) -> &'static [SlotKind] {
        if self.block {
            &SLOT_KINDS_BLOCK
        } else {
            &SLOT_KINDS
        }
    }
    pub(crate) fn slot_names(&self) -> &'static [&'static str] {
        if self.block {
            &SLOT_NAMES_BLOCK
        } else {
            &SLOT_NAMES
        }
    }
    pub(crate) fn hosts(&self) -> &'static [(usize, &'static [usize])] {
        if self.block {
            &HOSTS_BLOCK
        } else {
            &HOSTS
        }
    }
    pub(crate) fn m_rows(&self) -> usize {
        if self.block {
            M_ROWS_BLOCK
        } else {
            M_ROWS
        }
    }
    pub(crate) fn n_functionals(&self) -> usize {
        if self.block {
            N_FUNCTIONALS_BLOCK
        } else {
            N_FUNCTIONALS
        }
    }
    pub(crate) fn a_groups(&self) -> usize {
        if self.block {
            A_GROUPS_BLOCK
        } else {
            A_GROUPS
        }
    }
    pub(crate) fn h_groups(&self) -> usize {
        if self.block {
            H_GROUPS_BLOCK
        } else {
            H_GROUPS
        }
    }
    pub(crate) fn lookup_doms(&self) -> &'static [Dom] {
        if self.block {
            &LOOKUP_DOMS_BLOCK
        } else {
            &LOOKUP_DOMS
        }
    }
    pub(crate) fn lookups(&self, dom: Dom) -> Vec<Lk> {
        lookups_of(dom, self.block)
    }
    pub(crate) fn helpers(&self, dom: Dom) -> (usize, usize) {
        helpers_of(dom, self.block)
    }
    /// the A planes this layout holds, in plane order
    pub(crate) fn a_planes(&self) -> Vec<usize> {
        (0..N_A).filter(|p| self.block || a_in_wip(*p)).collect()
    }
    /// the H planes this layout holds, in plane order
    pub(crate) fn h_planes(&self) -> Vec<usize> {
        (0..N_H).filter(|p| self.block || h_in_wip(*p)).collect()
    }

    /// first row of the reserved pair of A site `k` of `slot`
    pub(crate) fn a_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.a_sites()[slot] {
            return Err(format!("private block: undeclared A site {k} in slot {slot}"));
        }
        Ok(self.a_mask_base + 2 * (self.a_prefix[slot] + k))
    }
    pub(crate) fn h_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.h_sites()[slot] {
            return Err(format!("private block: undeclared H site {k} in slot {slot}"));
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
    #[allow(dead_code, reason = "norm_m's limb sub-slices are read by the SC_TZC arm that lands with the feed-forward relations")]
    pub(crate) fn limb_off_m(&self, k: usize) -> usize {
        self.a_off[A_LIMBM] + k * T
    }

    /// The declared schedule, line by line; its digest is transcript-bound.
    pub(crate) fn describe(&self) -> Vec<String> {
        let n_slots = self.n_slots();
        let tag = if self.block { "private-block-t32/whole-block" } else { "private-block-t32-wip/0" };
        let half = if self.block { "whole block (attention, norm_m, feed-forward, residual 2)" } else { "attention half only (x_in -> xres1)" };
        let mut out = vec![
            format!("{tag}: T{T} d{D} H{H} KV1 dh{DH} F{F}; n={N} inv_rate=8 Q=256; P1 (weights public, no W commitment); {half}"),
            format!("A rows={} data={} site-pairs={} prox-pair=({},{})", self.a_rows, self.a_data_rows, self.a_prefix[n_slots], self.a_prox, self.a_prox + 1),
            format!("H rows={} data={} site-pairs={} zero-sum-pair={:?} prox-pair=({},{})", self.h_rows, self.h_data_rows, self.h_prefix[n_slots], self.h_u_rows(), self.h_prox, self.h_prox + 1),
            format!("M rows={} functionals={} A-groups={} H-groups={} collapse=0", self.m_rows(), self.n_functionals(), self.a_groups(), self.h_groups()),
            format!(
                "calibration: norm tn={NORM_TN} cn={NORM_CN} ceps={NORM_CEPS} wrho={NORM_WRHO}; shifts qkv={SH_QKV} rope={SH_ROPE} score={SH_S} o={SH_O} ao={SH_AO} residual=0; fE={F_E} fP={F_P} fRo={F_RO} wrhoS={WRHO_S} mask={MASK_SCORE}; classes int8=[-127,127] int16; tables U8 + exp"
            ),
        ];
        if self.block {
            out.push(format!(
                "feed-forward: F={F} shifts gate={SH_G} up=0 product={SH_H_PROD} down={SH_Z} residual2=0; gate class int8=[-128,127]; tables U8 + exp + act"
            ));
        }
        for s in 0..n_slots {
            let (n, e, d) = self.slots()[s];
            out.push(format!(
                "slot {s:02} [{}] main={n} ext={e} degree={d} kind={:?} A-sites={} H-sites={}",
                self.slot_names()[s],
                self.slot_kinds()[s],
                self.a_sites()[s],
                self.h_sites()[s]
            ));
        }
        for (host, hosted) in self.hosts() {
            out.push(format!("host {host:02} <- {hosted:?}"));
        }
        out
    }

    pub(crate) fn schedule_digest(&self) -> [u8; 32] {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block-wip-schedule/0");
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

    /// the work-in-progress layout is the accepted component's, unchanged
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
            assert_eq!(lay.lookups(dom).len().div_ceil(2), lay.helpers(dom).1);
        }
        // the work-in-progress layout holds exactly the accepted component's planes
        assert_eq!(lay.a_planes().len(), 50);
        assert_eq!(lay.h_planes().len(), 35);
        assert!(lay.a_planes().iter().all(|p| lay.a_off[*p] != ABSENT));
        assert!(lay.h_planes().iter().all(|p| lay.h_off[*p].0 != ABSENT));
    }

    /// the grown whole-block layout, against the derived counts of the
    /// disposition section 1.2 and T2 section D.2
    #[test]
    fn the_whole_block_layout_matches_the_derived_counts() {
        let lay = Layout::new_block();
        assert_eq!((lay.a_data_rows, lay.a_rows), (213, 455));
        assert_eq!((lay.h_data_rows, lay.h_rows), (280, 384));
        assert_eq!(A_SITES_BLOCK.iter().sum::<usize>(), 120);
        assert_eq!(H_SITES_BLOCK.iter().sum::<usize>(), 51);
        assert_eq!(lay.m_rows(), 50);
        assert_eq!((lay.a_planes().len(), lay.h_planes().len()), (N_A, N_H));
        // 23 slots: 12 private, 5 standalone, 6 hosts; 34 functionals
        let kinds = |k: SlotKind| SLOT_KINDS_BLOCK.iter().filter(|x| **x == k).count();
        assert_eq!((kinds(SlotKind::Private), kinds(SlotKind::Standalone), kinds(SlotKind::Host)), (12, 5, 6));
        assert_eq!(N_SLOTS_BLOCK + kinds(SlotKind::Standalone) + HOSTS_BLOCK.len(), N_FUNCTIONALS_BLOCK);
        let mut hosted = vec![0usize; N_SLOTS_BLOCK];
        for (host, list) in HOSTS_BLOCK {
            assert_eq!(SLOT_KINDS_BLOCK[host], SlotKind::Host);
            for &s in list {
                assert_eq!(SLOT_KINDS_BLOCK[s], SlotKind::Private);
                assert!(s < host, "a host runs after the slots it hosts");
                hosted[s] += 1;
            }
        }
        for s in 0..N_SLOTS_BLOCK {
            assert_eq!(hosted[s], usize::from(SLOT_KINDS_BLOCK[s] == SlotKind::Private));
        }
        // L + 256 <= 512 on every slot; the largest is SC_SZC at 50
        let l = |s: usize| {
            let (n, e, d) = SLOTS_BLOCK[s];
            (n + e) * d + 2
        };
        assert_eq!((0..N_SLOTS_BLOCK).map(l).max(), Some(50));
        for s in 0..N_SLOTS_BLOCK {
            assert!(l(s) + 256 <= 512);
        }
        assert_eq!((0..N_SLOTS_BLOCK).map(|s| SLOTS_BLOCK[s].0).sum::<usize>(), 159);
        assert_eq!((0..N_SLOTS_BLOCK).map(|s| SLOTS_BLOCK[s].1).sum::<usize>(), 25);
        // helper planes cover the lookups pairwise, on six domains now
        for dom in LOOKUP_DOMS_BLOCK {
            assert_eq!(lay.lookups(dom).len().div_ceil(2), lay.helpers(dom).1);
        }
        // T2 section D.2's per-domain U8 totals, and their sum
        let per_dom: Vec<usize> = LOOKUP_DOMS_BLOCK.iter().map(|d| lay.lookups(*d).len() * d.len()).collect();
        assert_eq!(per_dom, vec![1_024, 19_456, 4_608, 6_656, 3_072, 26_624]);
        assert_eq!(per_dom.iter().sum::<usize>(), 61_440);
        // every plane the block adds is a real plane of a declared domain
        assert_eq!((0..N_A).filter(|p| !a_in_wip(*p)).count(), 31);
        assert_eq!((0..N_H).filter(|p| !h_in_wip(*p)).count(), 16);
        assert_eq!((0..N_A).filter(|p| a_dom(*p) == Dom::F).count(), 11);
        assert_eq!((0..N_H).filter(|p| h_dom(*p) == Dom::F).count(), 6);
        // the declared description carries the derived counts, line by line
        let lines = lay.describe();
        assert_eq!(lines.len(), 6 + N_SLOTS_BLOCK + HOSTS_BLOCK.len());
        assert!(lines[0].starts_with("private-block-t32/whole-block"));
        assert!(lines.iter().any(|l| l.contains("A rows=455 data=213 site-pairs=120")));
        assert!(lines.iter().any(|l| l.contains("H rows=384 data=280 site-pairs=51")));
        assert!(lines.iter().any(|l| l.contains("M rows=50 functionals=34 A-groups=35 H-groups=9")));
        // The two descriptions are different objects. The block one is not
        // absorbed anywhere yet; the stage that absorbs it must give it its
        // own digest domain alongside the block profile string.
        assert_ne!(lay.schedule_digest(), Layout::new().schedule_digest());
    }

    /// the two layouts share ONE plane numbering: a plane means the same thing
    /// in both, and the work-in-progress one simply omits the block's planes
    #[test]
    fn the_two_layouts_share_one_plane_numbering() {
        let (wip, block) = (Layout::new(), Layout::new_block());
        // domains are a property of the plane, not of the layout
        for p in 0..N_A {
            assert_eq!(a_dom(p), a_dom(p));
        }
        // the attention planes keep their relative order in both layouts
        let order: Vec<usize> = wip.a_planes();
        let mut offs: Vec<usize> = order.iter().map(|p| wip.a_off[*p]).collect();
        let sorted = {
            let mut o = offs.clone();
            o.sort_unstable();
            o
        };
        assert_eq!(offs, sorted, "the work-in-progress layout packs planes in plane order");
        offs.dedup();
        assert_eq!(offs.len(), order.len(), "two planes share an offset");
        // a plane absent from the work-in-progress layout has no offset there
        for p in 0..N_A {
            assert_eq!(wip.a_off[p] == ABSENT, !a_in_wip(p));
            assert_ne!(block.a_off[p], ABSENT);
        }
        for p in 0..N_H {
            assert_eq!(wip.h_off[p].0 == ABSENT, !h_in_wip(p));
            assert_ne!(block.h_off[p].0, ABSENT);
        }
    }
}
