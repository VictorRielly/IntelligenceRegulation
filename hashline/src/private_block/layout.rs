//! The fixed T32/d16/H2/KV1/dh8/F16 layout and the DECLARED mask/CFS schedule
//! of the private block module: the WHOLE BLOCK — attention, `norm_m`, the
//! SiLU feed-forward and residual 2 — on ONE `A`, ONE `H` and ONE `M`, under
//! one transcript, each commitment opened once (T1 sections C.1-C.2, T2
//! sections A-C, form S of T1 section B.1).
//!
//! 455 `A` rows, 384 `H` rows, 120 / 51 claim sites, 23 slots, six host
//! groups, 50 `M` rows, 34 functionals, opening groups `A` 35 / `H` 9, largest
//! slot length 50, 61,440 byte lookups. `Layout::new` ASSERTS the four row
//! totals itself, so a layout edit that breaks them cannot ship.
//!
//! Planes are laid out CONTIGUOUSLY PER DOMAIN, which T2 section C.2 makes an
//! obligation on the implementer rather than a choice: `SC_DZC`'s and
//! `SC_FZC`'s `a_range` each sweep one plane block.
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
//! * twenty-three CFS slots on one M (50 rows), 34 functionals in the fixed
//!   order `[Gamma_s if standalone] eval_s ... then one batched Gamma per host`.
//!
//! RECORDED DEVIATION from `zk60_private_attention_schedule.json`: that file
//! numbers rows of the legacy `AttnLayout` (65,536-entry range tables with
//! block masks). This component ranges every value through the single
//! 256-entry `U8` table by byte limbs (the lever section 6 of the construction
//! records), so every table is ONE row and no block mask exists. The slot
//! list, host assignment, M shape and functional order are the declared ones;
//! the row numbering is this file's.

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
/// THE WIDTH OF A COMMITTED ROW, and nothing else (trap T-1 of the 125M layout
/// memo). It moves with the row geometry: 16,384 at the 125M shape.
pub(crate) const N: usize = 1 << LOG_N;
/// THE NUMBER OF ENTRIES IN EACH OF THE THREE LOOKUP TABLES — the byte class
/// `[0, 256)`. It is `256` at EVERY shape and must never be conflated with the
/// row width `N` (trap T-1): the three table-value vectors, the three
/// multiplicity histograms and the two in-class guards that index
/// `AttentionPublic::exp` (256 words) and `FeedForwardPublic::act`
/// (`[i16; 256]`) are all sized by THIS constant. At the toy shape
/// `U8_LEN == N`, so the split moves no byte of a toy proof.
pub(crate) const U8_LEN: usize = 256;

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

/// THE P-3 LIFT (memo section 4.1, blocking item B-3), named here so it can be
/// tested at a geometry the module cannot yet be instantiated at.
///
/// The value-0 LogUp identity is ONE sum claim with one part per `H` plane
/// (`protocol::logup_sum_claim`), and the PCS keys a part by
/// `(point tail, column offset, slice length)`: at or above the row width that
/// is `(_, 0, N)`, below it `(_, offset % N, 1 << log)`. So every `H` plane
/// whose domain sits BELOW the row width raises a different column-weight key,
/// `check_opening` refuses with "claim parts with different column weights"
/// and `zkp-core`'s `pcs` asserts below it — **no receipt is produced at all**.
/// At the toy every `H` domain is already at or above `LOG_N = 8`, so the
/// question has never arisen.
///
/// **THE REPAIR (ruling P-3).** A domain that carries `H` planes and whose
/// natural log sits BELOW the row width is lifted TO the row width.
/// `rows_of` is 1 either way below the row width, so the lift costs no
/// committed row, no claim site and no slot.
///
/// Two conditions travel with it, and neither is discharged here:
///  * the padded TABLE positions must repeat an existing entry
///    (`argument::table_values_*` build entry `i` from `i % U8_LEN`), so the
///    proved set is still exactly the `U8_LEN` byte values. Get this wrong
///    and the byte range proof admits `1 << log_n` values — a soundness hole
///    created by the fix for a shape bug;
///  * the padded MULTIPLICITIES must be zero, which they are: `prove_inner`
///    writes only `0..U8_LEN` into a zero-initialised plane.
///
/// At the toy this function is the identity: every `H` domain is already at
/// or above `LOG_N = 8` (`Tab` is exactly 8), so no toy byte moves.
pub(crate) fn domain_log_at(natural: usize, carries_h_planes: bool, log_n: usize) -> usize {
    if carries_h_planes && natural < log_n {
        log_n
    } else {
        natural
    }
}

impl Dom {
    /// the log the domain's PADDED true extent asks for, before the P-3 lift
    pub(crate) fn natural_log(self) -> usize {
        match self {
            Dom::T => 5,
            Dom::Ht => 6,
            Dom::L | Dom::D | Dom::Q | Dom::F => 9,
            Dom::Kv | Dom::Tab => 8,
            Dom::S => 11,
        }
    }
    /// `Dom::T` and `Dom::Ht` carry `A` planes only; every other domain owns
    /// LogUp helper planes and so contributes a part to the single sum claim.
    pub(crate) fn carries_h_planes(self) -> bool {
        !matches!(self, Dom::T | Dom::Ht)
    }
    pub(crate) fn log(self) -> usize {
        domain_log_at(self.natural_log(), self.carries_h_planes(), LOG_N)
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
// Dom::F (T2 section B.2)
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

// ---- STEP S8: the `A_*` ids as a function of a shape -----------------------

/// the toy's three variable group lengths, for the segment table below
pub(crate) const LN_TOY: usize = 4;
pub(crate) const LS_TOY: usize = 2;
pub(crate) const LP_TOY: usize = 2;

/// **The `A_*` ids at a shape (finding S6-F2, step S8).**
///
/// The constants above are the TOY's, and three plane groups have a length
/// that moves with a shape's calibration windows:
///
/// | group | length | toy | rung | 125M |
/// |---|---|---:|---:|---:|
/// | each norm's `rho` / `sigma` byte limbs | `limbs_norm` | 4 | 4 | 4 |
/// | the softmax quotient's limbs | `limbs_p` | 2 | 2 | 2 |
/// | `rho_s` / `sigma_s` byte limbs | `limbs_sigma_s` | **2** | **3** | **3** |
///
/// A longer group shifts every plane above it, so a plane id is a FUNCTION of
/// the shape. [`Ids::at`] maps a toy id to the same plane's id at this shape;
/// the growing groups get their own accessors, because the toy has no name
/// for a third `sigma_s` limb.
///
/// The segment table below and [`super::shape::Shape::a_plane_doms`] are two
/// independent statements of the same plane list, written from the memo's
/// §2.4 and not from each other; [`Ids::new`] refuses unless they agree.
pub(crate) struct Ids {
    /// `map[toy id]` = the same plane's id at this shape
    map: Vec<usize>,
    /// the domain of every plane at this shape, in plane order
    doms: Vec<Dom>,
    pub ln: usize,
    pub ls: usize,
    pub lp: usize,
}

impl Ids {
    pub(crate) fn new(sh: &super::shape::Shape) -> Result<Ids, String> {
        let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());
        if ln < LN_TOY || ls < LS_TOY || lp < LP_TOY {
            return Err("private block: this shape's A plane list is shorter than the pinned one".into());
        }
        // (first toy id, toy length, this shape's length, domain), in plane
        // order. Only the four norm limb groups, the `p` limbs and the two
        // `sigma_s` limb groups have a length that is not a literal.
        let segs: [(usize, usize, usize, Dom); 18] = [
            (A_D, 4, 4, Dom::T),
            (A_MX, 2, 2, Dom::Ht),
            (A_LIMB, 2, 2, Dom::L),
            (A_X, 4, 4, Dom::D),
            (A_NR0, LN_TOY, ln, Dom::D),
            (A_NS0, LN_TOY, ln, Dom::D),
            (A_AO, 8, 8, Dom::D),
            (A_MR0, LN_TOY, ln, Dom::D),
            (A_MS0, LN_TOY, ln, Dom::D),
            (A_Z16, 7, 7, Dom::D),
            (A_Q8, 7, 7, Dom::Q),
            (A_K8, 6, 6, Dom::Kv),
            (A_S8, 5, 5, Dom::S),
            (A_PL0, LP_TOY, lp, Dom::S),
            (A_SR0, LS_TOY, ls, Dom::S),
            (A_SG0, LS_TOY, ls, Dom::S),
            (A_G8, 11, 11, Dom::F),
            (A_MU8, 3, 3, Dom::Tab),
        ];
        let mut map = vec![usize::MAX; N_A];
        let mut doms: Vec<Dom> = Vec::new();
        for (start, toy_len, len, dom) in segs {
            let base = doms.len();
            for k in 0..toy_len {
                map[start + k] = base + k;
            }
            for _ in 0..len {
                doms.push(dom);
            }
        }
        if map.iter().any(|v| *v == usize::MAX) {
            return Err("private block: the A plane segment table does not cover every plane".into());
        }
        if doms != sh.a_plane_doms() {
            return Err("private block: this shape's A plane list differs from the pinned one".into());
        }
        Ok(Ids { map, doms, ln, ls, lp })
    }

    /// the toy's own map, which is the identity (asserted by `Layout::new`)
    pub(crate) fn toy() -> Ids {
        Ids::new(&super::shape::Shape::toy()).expect("the toy's plane list is the pinned one")
    }

    /// the same plane, at this shape
    pub(crate) fn at(&self, toy_id: usize) -> usize {
        self.map[toy_id]
    }
    pub(crate) fn nr(&self, k: usize) -> usize {
        self.map[A_NR0] + k
    }
    pub(crate) fn ns(&self, k: usize) -> usize {
        self.map[A_NS0] + k
    }
    pub(crate) fn mr(&self, k: usize) -> usize {
        self.map[A_MR0] + k
    }
    pub(crate) fn ms(&self, k: usize) -> usize {
        self.map[A_MS0] + k
    }
    pub(crate) fn pl(&self, k: usize) -> usize {
        self.map[A_PL0] + k
    }
    pub(crate) fn sr(&self, k: usize) -> usize {
        self.map[A_SR0] + k
    }
    pub(crate) fn sg(&self, k: usize) -> usize {
        self.map[A_SR0] + self.ls + k
    }
    pub(crate) fn n_a(&self) -> usize {
        self.doms.len()
    }
    pub(crate) fn dom(&self, plane: usize) -> Dom {
        self.doms[plane]
    }
    pub(crate) fn is_multiplicity(&self, plane: usize) -> bool {
        plane >= self.map[A_MU8]
    }
}

// ---- the H planes (every one Fp2-valued: a `re` slice then an `im` slice) ----
pub(crate) const H_L: usize = 0;
/// 19 helpers for the 38 `Dom::D` lookups
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

/// **The `H_*` ids at a shape (finding S9-F6, the analogue of [`Ids`]).**
///
/// The constants above are the TOY's, and the `H` plane LIST moves with the
/// shape in BOTH directions:
///
/// | block | toy | rung | 125M | why |
/// |---|---:|---:|---:|---|
/// | `Dom::D` helpers | 19 | 19 | **17** | C-6 drops four `Dom::D` lookups where the norm window fills its top limb exactly |
/// | `Dom::S` helpers | 7 | **8** | **8** | the third `sigma_s` limb adds two lookups |
/// | total `N_H` | 51 | **52** | **50** | |
///
/// So a toy id is not even a total function of the shape — the `Dom::D`
/// block SHRINKS at 125M, where `H_D_LAST` names a plane that does not
/// exist. The accessors below are therefore by ROLE (`helper(dom, k)`, and a
/// name for each singleton), which is how `argument.rs` already reads them
/// (`b.h(H_D0 + j)` for `j` in `0 .. helpers(Dom::D)`).
///
/// This table and [`super::shape::Shape::h_plane_doms`] are two independent
/// statements of the same plane list; [`HIds::new`] refuses unless they
/// agree, exactly as [`Ids::new`] does on the `A` side.
///
/// **NOT YET WIRED IN.** `argument.rs` and `protocol.rs` still read the
/// literals, which are correct at the toy and only at the toy; replacing
/// them is step C of the ledger's NEXT.
pub(crate) struct HIds {
    doms: Vec<Dom>,
    first_l: usize,
    first_d: usize,
    first_q: usize,
    first_kv: usize,
    first_s: usize,
    first_f: usize,
    sexp: usize,
    fact: usize,
    gu8: usize,
    u: usize,
}

impl HIds {
    pub(crate) fn new(sh: &super::shape::Shape) -> Result<HIds, String> {
        let mut doms: Vec<Dom> = Vec::new();
        let seg = |doms: &mut Vec<Dom>, dom: Dom, n: usize| -> usize {
            let first = doms.len();
            for _ in 0..n {
                doms.push(dom);
            }
            first
        };
        // the plane order of `Shape::h_plane_doms`: the five lookup-domain
        // helper blocks, the exponential pair's own helper inside `Dom::S`,
        // the feed-forward helpers, the activation pair's own helper, the
        // three table helpers and the zero-sum pair
        let first_l = seg(&mut doms, Dom::L, sh.helpers(Dom::L));
        let first_d = seg(&mut doms, Dom::D, sh.helpers(Dom::D));
        let first_q = seg(&mut doms, Dom::Q, sh.helpers(Dom::Q));
        let first_kv = seg(&mut doms, Dom::Kv, sh.helpers(Dom::Kv));
        let first_s = seg(&mut doms, Dom::S, sh.helpers(Dom::S));
        let sexp = seg(&mut doms, Dom::S, 1);
        let first_f = seg(&mut doms, Dom::F, sh.helpers(Dom::F));
        let fact = seg(&mut doms, Dom::F, 1);
        let gu8 = seg(&mut doms, Dom::Tab, 3);
        let u = seg(&mut doms, Dom::Tab, 1);
        if doms != sh.h_plane_doms() {
            return Err("private block: this shape's H plane list differs from the pinned one".into());
        }
        Ok(HIds { doms, first_l, first_d, first_q, first_kv, first_s, first_f, sexp, fact, gu8, u })
    }

    /// the `k`-th LogUp helper of a lookup domain
    pub(crate) fn helper(&self, dom: Dom, k: usize) -> usize {
        self.first_helper(dom) + k
    }
    /// the first LogUp helper plane of a lookup domain (the replacement for
    /// the literal half of [`helpers`])
    pub(crate) fn first_helper(&self, dom: Dom) -> usize {
        match dom {
            Dom::L => self.first_l,
            Dom::D => self.first_d,
            Dom::Q => self.first_q,
            Dom::Kv => self.first_kv,
            Dom::S => self.first_s,
            Dom::F => self.first_f,
            _ => 0,
        }
    }
    /// the exponential pair's own helper (`H_SEXP` at the toy)
    pub(crate) fn sexp(&self) -> usize {
        self.sexp
    }
    /// the activation pair's own helper (`H_FACT` at the toy)
    pub(crate) fn fact(&self) -> usize {
        self.fact
    }
    /// the three table helpers, in the toy's order `(U8, exp, act)`
    pub(crate) fn table_helpers(&self) -> [usize; 3] {
        [self.gu8, self.gu8 + 1, self.gu8 + 2]
    }
    /// the zero-sum masking pair `u` (`H_U` at the toy)
    pub(crate) fn u(&self) -> usize {
        self.u
    }
    pub(crate) fn n_h(&self) -> usize {
        self.doms.len()
    }
    pub(crate) fn dom(&self, plane: usize) -> Dom {
        self.doms[plane]
    }
    /// the table helpers enter the value-0 LogUp identity with a negative sign
    pub(crate) fn is_table(&self, plane: usize) -> bool {
        (self.gu8..self.gu8 + 3).contains(&plane)
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
/// integers only if no term wraps the 64-bit field.
///
/// **STEP S8 rewrote this premise as a premise about a SHAPE** (memo §3.3,
/// §3.4, condition O-4, decision D16 items 1-5). The clauses below are stated
/// once, with each shape's numbers beside them; the three that used to be
/// literals — the norm window, the softmax window and the byte-limb counts
/// that hold them — now read off the shape, and `lookups_at` emits exactly
/// the lookups the clause names. The numbers for the three shapes that exist:
///
/// | quantity | toy | rung | 125M |
/// |---|---:|---:|---:|
/// | width `d`, tokens `T` | 16 / 32 | 96 / 24 | 768 / 512 |
/// | `D_max = isqrt(1 + d 32767^2)` | 131,068 | 321,049 | 908,065 |
/// | norm window `wrho = tn + 1 + bits(D_max)` | **29** | **31** | **32** |
/// | norm limbs `ln`, top-limb lookup `1 << (8 ln - wrho)` | 4, `8 l3` | 4, `2 l3` | 4, **dropped (C-6)** |
/// | `f_E`, `Sum <= T 2^fE` | 9, 2^14 | 12, 98,304 | 9, 2^18 |
/// | softmax window `wrho_s`, limbs `ls` | **14**, 2 | **17**, 3 | **18**, 3 |
/// | top `sigma_s` lookup `1 << (8 ls - wrho_s)` | `4 l1` | `128 l2` | `64 l2` |
///
/// With every limb in [0, 256):
/// * x, ao, xres1, xres2, u16, h16, z16 in int16 (two limbs, offset 32768);
///   y, nm, q8, k8, v8, qr8, kr8, s8, o8 in [-127, 127] (`v + 127` and
///   `127 - v` both bytes); g8 in [-128, 127] from the 256-row activation
///   table itself, never from `sym`;
/// * D, a1, a2 < 2^24 (three limbs each), so D^2 + a1 < 2^49 equals sum x^2 + ceps
///   over the integers (< 2^35 at the toy, 2^39.58 at 125M), a2 = 2D - a1 >= 0
///   and a1 >= 0 give D^2 <= ss <= D^2 + 2D, i.e. D = isqrt(ss), and ceps = 1
///   gives D >= 1. **Three limbs suffice at every shape here** (D16 item 3:
///   908,065 < 2^24), and a shape that needed a fourth would change the plane
///   list, which `Ids::new` refuses;
/// * norm: `|2 cn g x| < 2^34` and `y D 2^(tn+1) < 2^44` at the toy, `2^36.6`
///   and `2^45.3` at 125M; **rho and sigma < `2^wrho` exactly**, because the
///   `ln` limbs hold `8 ln` bits and the top limb's `1 << (8 ln - wrho)`
///   lookup forbids the slack — when `8 ln == wrho` (125M) the limbs are
///   exactly the window and that lookup is dropped, not forgotten. Hence
///   `0 <= rho <= den - 1` and y is the floor quotient. **The margin at 125M
///   is 0.21 bits** (memo §3.8 row 9): a wider input class needs decision 2's
///   pin, not another limb;
/// * requant remainders are biased limbs: 7-bit (`2 l`), 6-bit (`4 l`), 9-bit
///   (l0 + 256 l1 with `128 l1` a byte), 14-bit (l0 + 256 l1 with `4 l1` a
///   byte), so r in [-2^(s-1), 2^(s-1)) exactly. These are requantization
///   SHIFTS, which are one fixed calibration across shapes (memo §3.8), so
///   they are the same literals at every shape;
/// * softmax: `p < 2^(F_P + 1)` (`lp` limbs with `1 << (8 lp - F_P - 1)` on
///   the top one: `64 l1`), **rho_s and sigma_s < `2^wrho_s` exactly** by the
///   same top-limb argument at `ls` limbs, and `Sum <= T 2^fE <= 2^wrho_s`,
///   so `p Sum + rho_s < 2^25` at the toy and `2^28` at 125M and the quotient
///   relation is over the integers; off the causal support it forces
///   p = rho_s = 0 because Sum >= 2^fE > 0 (some position ON the support has
///   delta = 0, hence E[0] = 2^fE: the selected one, or, if the selector sits
///   on a masked position, the max is -127 and every supported score equals
///   it);
/// * delta in [0, 256) and E = exp[delta] come from the two-column exp lookup;
///   (g8 + 128, a16) comes from the two-column activation lookup, whose value
///   range is enforced by the public statement, not promised by the caller;
/// * feed-forward (T2 section E): gacc and uacc below 2^18 at the toy and
///   2^23.56 at 125M, the product a16 u16 at most 2^30, `f0` below 2^31 (the
///   worst new case) and zacc at most 2^26 at the toy, 2^32.99 at 125M.
/// All bounds are far below p = 2^64 - 2^32 + 1. The LogUp multiplicities (at
/// most 61,440 at the toy, 98,582,528 at 125M) cannot wrap.
///
/// **What this premise does NOT cover, and must not be read as covering:**
/// the PAD. At any shape where a domain pads, every clause above is a
/// statement about the true support only; what a padded position contains is
/// ruling P-1's pad-zero term (memo §3.7a), which is step S9.
pub(crate) fn lookups(dom: Dom) -> Vec<Lk> {
    lookups_at(&super::shape::Shape::toy(), &Ids::toy(), dom)
}

/// **STEP S8: the same list at any shape.** Three things move with the
/// calibration windows and nothing else does:
///
/// 1. the plane IDS, through [`Ids`];
/// 2. the byte-limb COUNTS — `ln` limbs per norm remainder, `ls` per softmax
///    remainder, `lp` per softmax quotient;
/// 3. the `scaled` coefficient that pins the TOP limb's high bits. A window
///    of `w` bits held in `l` byte limbs leaves `8l - w` slack bits in the
///    top limb, so `scaled(top, 1 << (8l - w))` is exactly the lookup that
///    forbids them: `1 << (32 - 29) = 8` at the toy, `1 << (32 - 31) = 2` at
///    the rung, and at 125M `8l == w` so the coefficient is 1 and the lookup
///    says nothing — **that is correction C-6, and the four norm lookups are
///    DROPPED there** (`Shape::norm_top_is_full_byte`). The softmax pair's
///    coefficient is `1 << (8 ls - wrho_s)`: 4 at the toy (two limbs, 14
///    bits), 64 at 125M (three limbs, 18 bits — the memo's `scaled(l2, 64)`)
///    and 128 at the rung (three limbs, 17 bits).
///
/// The counts this produces are asserted against
/// [`super::shape::Shape::lookups_per_position`], which counts the same list
/// from the memo's §4 without building it, at every named shape.
pub(crate) fn lookups_at(sh: &super::shape::Shape, ids: &Ids, dom: Dom) -> Vec<Lk> {
    let (ln, ls, lp) = (ids.ln, ids.ls, ids.lp);
    // C-6: when the window fills its top limb exactly the `scaled` lookup is
    // the identity and is not emitted at all.
    let norm_top = !sh.norm_top_is_full_byte();
    let norm_scale = 1i64 << (8 * ln as u32 - sh.norm_wrho);
    let sigma_scale = 1i64 << (8 * ls as u32 - sh.wrho_s);
    let p_scale = 1i64 << (8 * lp as u32 - (F_P + 1));
    let mut v = Vec::new();
    match dom {
        Dom::L => {
            v.push(byte(ids.at(A_LIMB)));
            v.push(byte(ids.at(A_LIMBM)));
        }
        Dom::D => {
            v.extend([byte(ids.at(A_XL0)), byte(ids.at(A_XL1))]);
            v.extend(sym(ids.at(A_Y)));
            v.extend((0..ln).map(|k| byte(ids.nr(k))));
            if norm_top {
                v.push(scaled(ids.nr(ln - 1), norm_scale));
            }
            v.extend((0..ln).map(|k| byte(ids.ns(k))));
            if norm_top {
                v.push(scaled(ids.ns(ln - 1), norm_scale));
            }
            v.extend([byte(ids.at(A_AL0)), byte(ids.at(A_AL1)), byte(ids.at(A_RAL)), scaled(ids.at(A_RAL), 2), byte(ids.at(A_X1L0)), byte(ids.at(A_X1L1))]);
            // T1 section C.1: norm_m's class, its rho / sigma limbs, and
            // residual 2's int16 limbs. Fourteen lookups at four limbs.
            v.extend(sym(ids.at(A_YM)));
            v.extend((0..ln).map(|k| byte(ids.mr(k))));
            if norm_top {
                v.push(scaled(ids.mr(ln - 1), norm_scale));
            }
            v.extend((0..ln).map(|k| byte(ids.ms(k))));
            if norm_top {
                v.push(scaled(ids.ms(ln - 1), norm_scale));
            }
            v.extend([byte(ids.at(A_X2L0)), byte(ids.at(A_X2L1))]);
            // T2 section B.3: z16's int16 class and the down remainder.
            v.extend([byte(ids.at(A_ZL0)), byte(ids.at(A_ZL1)), byte(ids.at(A_RDL)), scaled(ids.at(A_RDL), 4)]);
        }
        Dom::F => {
            v.extend([byte(ids.at(A_RGL)), scaled(ids.at(A_RGL), 2)]);
            v.extend([byte(ids.at(A_UL0)), byte(ids.at(A_UL1))]);
            v.extend([byte(ids.at(A_HL0)), byte(ids.at(A_HL1))]);
            v.extend([byte(ids.at(A_RH0)), byte(ids.at(A_RH1)), scaled(ids.at(A_RH1), 4)]);
        }
        Dom::Q => {
            v.extend(sym(ids.at(A_Q8)));
            v.extend([byte(ids.at(A_RQL)), scaled(ids.at(A_RQL), 2)]);
            v.extend(sym(ids.at(A_QR8)));
            v.extend([byte(ids.at(A_RQRL)), scaled(ids.at(A_RQRL), 2)]);
            v.extend(sym(ids.at(A_O8)));
            v.extend([byte(ids.at(A_RO0)), byte(ids.at(A_RO1)), scaled(ids.at(A_RO1), 128)]);
        }
        Dom::Kv => {
            v.extend(sym(ids.at(A_K8)));
            v.extend([byte(ids.at(A_RKL)), scaled(ids.at(A_RKL), 2)]);
            v.extend(sym(ids.at(A_V8)));
            v.extend([byte(ids.at(A_RVL)), scaled(ids.at(A_RVL), 2)]);
            v.extend(sym(ids.at(A_KR8)));
            v.extend([byte(ids.at(A_RKRL)), scaled(ids.at(A_RKRL), 2)]);
        }
        Dom::S => {
            v.extend(sym(ids.at(A_S8)));
            v.extend([byte(ids.at(A_RSL)), scaled(ids.at(A_RSL), 4)]);
            v.extend((0..lp).map(|k| byte(ids.pl(k))));
            v.push(scaled(ids.pl(lp - 1), p_scale));
            v.extend((0..ls).map(|k| byte(ids.sr(k))));
            v.push(scaled(ids.sr(ls - 1), sigma_scale));
            v.extend((0..ls).map(|k| byte(ids.sg(k))));
            v.push(scaled(ids.sg(ls - 1), sigma_scale));
        }
        Dom::T | Dom::Ht | Dom::Tab => {}
    }
    v
}

/// (first H helper plane, helper count) of a lookup domain.
pub(crate) fn helpers(dom: Dom) -> (usize, usize) {
    match dom {
        Dom::L => (H_L, 1),
        Dom::D => (H_D0, 19),
        Dom::F => (H_F0, 5),
        Dom::Q => (H_Q0, 7),
        Dom::Kv => (H_KV0, 6),
        Dom::S => (H_S0, 7),
        _ => (0, 0),
    }
}

pub(crate) const LOOKUP_DOMS: [Dom; 6] = [Dom::L, Dom::D, Dom::F, Dom::Q, Dom::Kv, Dom::S];
/// the nine domains, in the fixed order the layout lays planes out in
pub(crate) const ALL_DOMS: [Dom; 9] = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab];

// ---- the CFS slots, in transcript order (T2 section C.3) ---------------------
pub(crate) const N_SLOTS: usize = 23;
pub(crate) const SC_SS: usize = 0;
pub(crate) const SC_SSM: usize = 1;
pub(crate) const SC_TZC: usize = 2;
pub(crate) const SC_LZC: usize = 3;
pub(crate) const SC_RS: usize = 4;
pub(crate) const SC_QMM: usize = 5;
pub(crate) const SC_KMM: usize = 6;
pub(crate) const SC_VMM: usize = 7;
pub(crate) const SC_SCORE: usize = 8;
pub(crate) const SC_PV: usize = 9;
pub(crate) const SC_WO: usize = 10;
pub(crate) const SC_GMM: usize = 11;
pub(crate) const SC_UMM: usize = 12;
pub(crate) const SC_DMM: usize = 13;
pub(crate) const SC_DZC: usize = 14;
pub(crate) const SC_QZC: usize = 15;
pub(crate) const SC_KVZC: usize = 16;
pub(crate) const SC_SZC: usize = 17;
pub(crate) const SC_FZC: usize = 18;
pub(crate) const SC_TAB: usize = 19;
pub(crate) const SC_ZS: usize = 20;
pub(crate) const SC_IO_IN: usize = 21;
pub(crate) const SC_IO_OUT: usize = 22;

pub(crate) const SLOT_NAMES: [&str; N_SLOTS] = [
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

/// (main rounds, extension rounds, degree)
pub(crate) const SLOTS: [(usize, usize, usize); N_SLOTS] = [
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

/// host slot -> the private slots it hosts (every private slot exactly once)
pub(crate) const HOSTS: [(usize, &[usize]); 6] = [
    (SC_TZC, &[SC_SS, SC_SSM]),
    (SC_DZC, &[SC_WO, SC_DMM]),
    (SC_QZC, &[SC_QMM, SC_PV]),
    (SC_KVZC, &[SC_KMM, SC_VMM]),
    (SC_SZC, &[SC_RS, SC_SCORE]),
    (SC_FZC, &[SC_GMM, SC_UMM]),
];

/// claim sites per slot on A and on H (each one reserved mask pair);
/// T1 section C.3 and T2 section D.1, site by site: 120 on A, 51 on H
pub(crate) const A_SITES: [usize; N_SLOTS] = [1, 1, 22, 2, 2, 1, 1, 1, 2, 2, 1, 1, 1, 1, 37, 8, 7, 13, 11, 3, 0, 1, 1];
pub(crate) const H_SITES: [usize; N_SLOTS] = [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 19, 7, 6, 8, 6, 3, 1, 0, 0];
/// column-weight groups of the single A / H openings (checked by the prover
/// against the PCS's own grouping; the wire shape uses them)
pub(crate) const A_GROUPS: usize = 35;
pub(crate) const H_GROUPS: usize = 9;
pub(crate) const N_FUNCTIONALS: usize = 34;
pub(crate) const M_ROWS: usize = 2 * N_SLOTS + 4;

/// The derived whole-block row totals of the disposition section 1.2, asserted
/// by `Layout::new` itself so a layout edit that breaks them cannot ship.
pub(crate) const A_ROWS: usize = 455;
pub(crate) const H_ROWS: usize = 384;
pub(crate) const A_DATA_ROWS: usize = 213;
pub(crate) const H_DATA_ROWS: usize = 280;

/// private terminals a slot publishes (A sites, H sites, one endpoint terminal for IO)
pub(crate) fn slot_terms(slot: usize) -> usize {
    A_SITES[slot] + H_SITES[slot] + usize::from(slot >= SC_IO_IN)
}

pub(crate) fn mask_specs() -> Vec<(usize, usize)> {
    SLOTS.iter().map(|&(n, e, d)| (n + e, d)).collect()
}

/// rows a plane of `1 << log` elements occupies at THIS profile's row width.
/// Superseded for layout construction by `shape::Shape::rows_of` (S5); kept
/// as the toy profile's own statement of the rule, and asserted equal to the
/// shape's in `grow_tests`.
pub(crate) fn rows_of(log: usize) -> usize {
    (1usize << log).div_ceil(N)
}

/// **CODE CONDITION C-H4** of the hash-layer disposition, pinned here because
/// this is the one place every commitment of the block path declares its row
/// count. A committed column is hashed as `8 * rows` bytes, and no other hash
/// input on the path may have that length, or the two are ambiguous — every
/// hash in this system is an untagged blake3, so LENGTH is the whole of the
/// domain separation. The condition is checked at construction for EVERY
/// shape, before a byte is committed, and it changes no proof byte: the toy's
/// counts are 455, 384, 50 and 7, all clear.
///
/// **STAGE 16, ruling T-3.** This used to be the hard-coded pair `{5, 8}` —
/// the 40-byte randomness-refill block and the 64-byte internal Merkle node —
/// and that set was INCOMPLETE: with today's labels 11, 12, 13, 15, 17 and 19
/// rows are dangerous too. The whole set is computed from the shape now, in
/// [`super::hash_domain`], and this function is the SHAPE-FREE part of it,
/// which is what the two statement constructors that hold no profile string
/// ([`super::endpoint_g::EndpointSpecG::new`] and
/// [`super::boundary::BoundarySpec::new`]) can check for themselves.
/// [`Layout::for_shape`] uses the full, shape-driven set.
pub(crate) fn no_commitment_has_a_node_shaped_column(rows: &[(&str, usize)]) -> Result<(), String> {
    no_commitment_has_a_node_shaped_column_under(rows, &zkp_core::hashtag::HashTag::legacy())
}

/// **STAGE 18, T-3 AS AMENDED**: the same shape-free half of the set, under
/// the hash rule the CALLER knows — whole under the legacy rule, EMPTY under
/// a tag (see [`super::hash_domain::imposed_shape_free`] for why). The two
/// bare statement constructors take that rule from the shape, through
/// [`super::endpoint_g::EndpointSpecG::new_with_tag`] and
/// [`super::boundary::BoundarySpec::new_with_tag`].
/// [`no_commitment_has_a_node_shaped_column`] is this at
/// `HashTag::legacy()`, so a caller with no tag to offer still gets the whole
/// set, which is the fail-closed direction.
pub(crate) fn no_commitment_has_a_node_shaped_column_under(rows: &[(&str, usize)], tag: &zkp_core::hashtag::HashTag) -> Result<(), String> {
    super::hash_domain::imposed_shape_free(tag).refuse(rows)
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
    a_prefix: Vec<usize>,
    h_prefix: Vec<usize>,
    /// **STEP B.** The shape this layout was built from, and the two plane-id
    /// maps that go with it. Everything below that used to read a toy literal
    /// now reads one of these.
    sh: super::shape::Shape,
    ids: Ids,
    hids: HIds,
    /// the row width `1 << sh.log_cols`
    n: usize,
    a_sites: [usize; N_SLOTS],
    h_sites: [usize; N_SLOTS],
    slots: [(usize, usize, usize); N_SLOTS],
    /// **STAGE 12.** `[incoming, outgoing]`: the first row of the reserved
    /// pair each IO tab claims. See [`Layout::with_io_mask_rows`].
    io_mask_row: [usize; 2],
}

impl Layout {
    /// **S5.** The row geometry is now computed from a SHAPE
    /// (`shape::Shape::toy`), not read off the plane table: the plane list,
    /// the rows each plane takes, the claim-site counts, the slot table and
    /// the opening-group counts all come from there. The frozen toy constants
    /// stay exactly where they were and become the GATE — if the shape-driven
    /// layout ever differs from them by one plane, one site or one row, this
    /// panics before a byte is committed. That is what lets the same code
    /// serve the rung and the 125M shapes later (steps S6..S13) without the
    /// toy profile moving.
    pub(crate) fn new() -> Layout {
        let sh = super::shape::Shape::toy();
        let lay = Layout::for_shape(&sh).expect("the toy shape is the pinned one");
        // ---- THE TOY FREEZE GATE. Every literal of the accepted profile,
        // re-asserted against what the shape-driven constructor produced. If
        // one plane, one site or one row ever differs, this panics before a
        // byte is committed.
        assert_eq!(lay.ids.n_a(), N_A, "the shape-driven A plane list is not the declared one");
        assert_eq!(lay.hids.n_h(), N_H, "the shape-driven H plane list is not the declared one");
        assert!((0..N_A).all(|p| lay.ids.dom(p) == a_dom(p)), "a shape-driven A plane sits on another domain");
        assert!((0..N_H).all(|p| lay.hids.dom(p) == h_dom(p)), "a shape-driven H plane sits on another domain");
        assert!((0..N_A).all(|p| lay.ids.at(p) == p), "the toy's A plane id map is not the identity");
        assert_eq!(lay.a_sites, A_SITES, "the shape-driven A claim sites are not the declared ones");
        assert_eq!(lay.h_sites, H_SITES, "the shape-driven H claim sites are not the declared ones");
        assert_eq!(lay.slots, SLOTS, "the shape-driven slot table is not the declared one");
        assert_eq!((sh.a_groups(), sh.h_groups()), (A_GROUPS, H_GROUPS), "the shape-driven opening groups are not the declared ones");
        assert_eq!(lay.n, N, "the shape's row width is not this profile's");
        // the derived counts of the disposition section 1.2
        assert_eq!(lay.a_data_rows, A_DATA_ROWS, "block A data rows");
        assert_eq!(lay.h_data_rows, H_DATA_ROWS, "block H data rows");
        assert_eq!(lay.a_rows, A_ROWS, "block A rows");
        assert_eq!(lay.h_rows, H_ROWS, "block H rows");
        lay
    }

    /// **STEP B: the same row geometry at ANY shape.** The toy is one
    /// instance of it ([`Layout::new`], which adds the frozen assertions),
    /// and a new shape is a NEW profile beside it (D17) — nothing here edits
    /// the toy. Construction REFUSES BY NAME (through [`Ids::new`] and
    /// [`HIds::new`]) any shape whose plane list is not the one the segment
    /// tables describe.
    pub(crate) fn for_shape(sh: &super::shape::Shape) -> Result<Layout, String> {
        let ids = Ids::new(sh)?;
        let hids = HIds::new(sh)?;
        let n = 1usize << sh.log_cols;
        let a_doms = sh.a_plane_doms();
        let h_doms = sh.h_plane_doms();
        let (a_sites, h_sites) = sh.claim_sites();
        let slots = sh.slots();
        let mut row = 0usize;
        let mut a_off = Vec::with_capacity(a_doms.len());
        for d in &a_doms {
            a_off.push(row * n);
            row += sh.rows_of(*d);
        }
        let a_data_rows = row;
        let mut a_prefix = vec![0usize; N_SLOTS + 1];
        let mut h_prefix = vec![0usize; N_SLOTS + 1];
        for s in 0..N_SLOTS {
            a_prefix[s + 1] = a_prefix[s] + a_sites[s];
            h_prefix[s + 1] = h_prefix[s] + h_sites[s];
        }
        let a_mask_base = a_data_rows;
        let a_prox = a_mask_base + 2 * a_prefix[N_SLOTS];
        let a_rows = a_prox + 2;
        let mut row = 0usize;
        let mut h_off = Vec::with_capacity(h_doms.len());
        for d in &h_doms {
            let r = sh.rows_of(*d);
            h_off.push((row * n, (row + r) * n));
            row += 2 * r;
        }
        let h_data_rows = row;
        let h_mask_base = h_data_rows;
        let h_prox = h_mask_base + 2 * h_prefix[N_SLOTS];
        let h_rows = h_prox + 2;
        // **C-H4 / T-3, at the FULL shape-driven set.** The shape-free set
        // above is what a bare statement constructor can check; here the
        // profile string and the geometry are both in hand, so the profile's
        // transcript constructor length and its clear-vector lengths are in
        // the set too (6 rows is dangerous at 125M and 7 at the frozen-seam
        // rung, and neither is visible without the profile).
        //
        // **STAGE 17, T-3 AS AMENDED.** Imposed on LEGACY-RULE profiles only
        // (the toy, the frozen-seam rung). On a tagged profile the four hash
        // domains are four different functions and a coincidence of input
        // lengths between them means nothing — see
        // `hash_domain::imposed_at_shape_with` for why that is not a
        // weakening.
        super::hash_domain::imposed_at_shape(sh).refuse(&[("A", a_rows), ("H", h_rows), ("M", M_ROWS), ("endpoint", sh.endpoint_rows)])?;
        Ok(Layout {
            a_off,
            a_data_rows,
            a_mask_base,
            a_prox,
            a_rows,
            h_off,
            h_data_rows,
            h_mask_base,
            h_prox,
            h_rows,
            a_prefix,
            h_prefix,
            sh: sh.clone(),
            ids,
            hids,
            n,
            a_sites,
            h_sites,
            slots,
            // **STAGE 12.** A single block's two IO commitments are
            // `endpoint_g`/`private_seam` planes with ONE claim site, whose
            // terminal pair sits immediately above the data rows. That is
            // today's `argument.rs` constant `sh.endpoint_rows - 5`, moved
            // here unchanged: nothing of any existing profile moves, and a
            // RUN overrides it per stage through `with_io_mask_rows`.
            io_mask_row: [sh.endpoint_rows.saturating_sub(super::endpoint_g::MASK_ROWS); 2],
        })
    }

    /// **STAGE 12.** The reserved pair each IO tab of this stage uses, as
    /// `[incoming, outgoing]`. A single block leaves it alone. A stage of a
    /// run sets it from the DERIVED boundary geometry: the outgoing claim
    /// (slot 22, block `k`'s output) takes site 0 at `data`, and the incoming
    /// claim (slot 21, block `k + 1`'s input) takes site 1 at `data + 2`, so
    /// that the two claims a boundary carries land on DISJOINT pairs — the
    /// whole defence against the shared-pair counterexample. The assignment
    /// is the run's declared schedule and is covered by the run's schedule
    /// digest; it is not in `describe()` and so moves no existing byte.
    pub(crate) fn with_io_mask_rows(mut self, rows: [usize; 2]) -> Layout {
        self.io_mask_row = rows;
        self
    }

    /// the reserved pair of the incoming (`Cm::In`) or outgoing (`Cm::Out`)
    /// IO commitment of this stage
    pub(crate) fn io_mask_row(&self, outgoing: bool) -> usize {
        self.io_mask_row[usize::from(outgoing)]
    }

    // ---- what this layout was built from ----
    pub(crate) fn shape(&self) -> &super::shape::Shape {
        &self.sh
    }
    pub(crate) fn ids(&self) -> &Ids {
        &self.ids
    }
    pub(crate) fn hids(&self) -> &HIds {
        &self.hids
    }
    /// the row width `1 << log_cols`
    pub(crate) fn n(&self) -> usize {
        self.n
    }
    pub(crate) fn slots(&self) -> &[(usize, usize, usize); N_SLOTS] {
        &self.slots
    }
    /// **STEP C part 2.** The CFS mask specification of THIS layout's slot
    /// table — `(rounds, degree)` per slot — the shaped form of the free
    /// [`mask_specs`], which reads the toy's `SLOTS` literal. At the toy the
    /// two are equal (asserted in `grow_tests`), so no toy byte moves.
    pub(crate) fn mask_specs(&self) -> Vec<(usize, usize)> {
        self.slots.iter().map(|&(n, e, d)| (n + e, d)).collect()
    }
    /// private terminals slot `s` publishes at THIS shape (the shaped form of
    /// the free [`slot_terms`], which reads `A_SITES` / `H_SITES`)
    pub(crate) fn slot_terms(&self, slot: usize) -> usize {
        self.a_sites[slot] + self.h_sites[slot] + usize::from(slot >= SC_IO_IN)
    }

    // ---- the slot schedule ----
    pub(crate) fn a_sites(&self) -> &[usize] {
        &self.a_sites
    }
    pub(crate) fn h_sites(&self) -> &[usize] {
        &self.h_sites
    }
    pub(crate) fn lookup_doms(&self) -> &'static [Dom] {
        &LOOKUP_DOMS
    }
    pub(crate) fn lookups(&self, dom: Dom) -> Vec<Lk> {
        lookups_at(&self.sh, &self.ids, dom)
    }
    pub(crate) fn helpers(&self, dom: Dom) -> (usize, usize) {
        (self.hids.first_helper(dom), self.sh.helpers(dom))
    }
    /// every A / H plane, in plane order
    pub(crate) fn a_planes(&self) -> Vec<usize> {
        (0..self.ids.n_a()).collect()
    }
    pub(crate) fn h_planes(&self) -> Vec<usize> {
        (0..self.hids.n_h()).collect()
    }

    /// first row of the reserved pair of A site `k` of `slot`
    pub(crate) fn a_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.a_sites[slot] {
            return Err(format!("private block: undeclared A site {k} in slot {slot}"));
        }
        Ok(self.a_mask_base + 2 * (self.a_prefix[slot] + k))
    }
    pub(crate) fn h_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.h_sites[slot] {
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
        let (re, im) = self.h_off[self.hids.u()];
        [re / self.n, im / self.n]
    }
    pub(crate) fn limb_off(&self, k: usize) -> usize {
        self.a_off[self.ids.at(A_LIMB)] + k * self.sh.t_pad
    }
    pub(crate) fn limb_off_m(&self, k: usize) -> usize {
        self.a_off[self.ids.at(A_LIMBM)] + k * self.sh.t_pad
    }

    /// The declared schedule, line by line; its digest is transcript-bound.
    pub(crate) fn describe(&self) -> Vec<String> {
        let sh = &self.sh;
        // The toy's first line opens with a LEGACY label that is not its
        // profile id; it is transcript-bound through `schedule_digest`, so
        // normalising it would move every toy byte (D17). It is therefore
        // kept verbatim for the toy profile and only for it, and every NEW
        // profile puts its own profile id there — which is also what makes
        // this digest separate two shapes of identical geometry.
        let tag = if sh.profile == super::shape::TOY_PROFILE { "private-block-t32/1" } else { sh.profile };
        let mut out = vec![
            format!(
                "{tag}: T{} d{} H{} KV{} dh{} F{}; n={} inv_rate={} Q={}; P1 (weights public, no W commitment); whole block (attention, norm_m, feed-forward, residual 2)",
                sh.tokens, sh.width, sh.q_heads, sh.kv_heads, sh.head_dim, sh.hidden, self.n, sh.inv_rate, sh.opened_cols
            ),
            format!("A rows={} data={} site-pairs={} prox-pair=({},{})", self.a_rows, self.a_data_rows, self.a_prefix[N_SLOTS], self.a_prox, self.a_prox + 1),
            format!("H rows={} data={} site-pairs={} zero-sum-pair={:?} prox-pair=({},{})", self.h_rows, self.h_data_rows, self.h_prefix[N_SLOTS], self.h_u_rows(), self.h_prox, self.h_prox + 1),
            format!("M rows={M_ROWS} functionals={N_FUNCTIONALS} A-groups={} H-groups={} collapse=0", sh.a_groups(), sh.h_groups()),
            format!(
                "calibration: norm tn={NORM_TN} cn={NORM_CN} ceps={NORM_CEPS} wrho={}; shifts qkv={SH_QKV} rope={SH_ROPE} score={SH_S} o={SH_O} ao={SH_AO} residual=0; fE={} fP={F_P} fRo={F_RO} wrhoS={} mask={MASK_SCORE}; classes int8=[-127,127] int16; tables U8 + exp",
                sh.norm_wrho, sh.f_e, sh.wrho_s
            ),
            format!(
                "feed-forward: F={} shifts gate={SH_G} up=0 product={SH_H_PROD} down={SH_Z} residual2=0; gate class int8=[-128,127]; tables U8 + exp + act",
                sh.hidden
            ),
        ];
        for s in 0..N_SLOTS {
            let (n, e, d) = self.slots[s];
            out.push(format!(
                "slot {s:02} [{}] main={n} ext={e} degree={d} kind={:?} A-sites={} H-sites={}",
                SLOT_NAMES[s], SLOT_KINDS[s], self.a_sites[s], self.h_sites[s]
            ));
        }
        for (host, hosted) in HOSTS {
            out.push(format!("host {host:02} <- {hosted:?}"));
        }
        out
    }

    pub(crate) fn schedule_digest(&self) -> [u8; 32] {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/private-block-schedule/1");
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

    /// the whole-block layout against the derived counts of the disposition
    /// section 1.2 and T2 section D.2
    #[test]
    fn declared_counts_are_self_consistent() {
        let lay = Layout::new();
        assert_eq!((lay.a_data_rows, lay.a_rows), (213, 455));
        assert_eq!((lay.h_data_rows, lay.h_rows), (280, 384));
        assert_eq!(A_SITES.iter().sum::<usize>(), 120);
        assert_eq!(H_SITES.iter().sum::<usize>(), 51);
        // 23 slots -> 46 coefficient rows + b_re, b_im, u_re, u_im
        assert_eq!(M_ROWS, 50);
        assert_eq!((lay.a_planes().len(), lay.h_planes().len()), (N_A, N_H));
        // 23 slots: 12 private, 5 standalone, 6 hosts; 34 functionals
        let kinds = |k: SlotKind| SLOT_KINDS.iter().filter(|x| **x == k).count();
        assert_eq!((kinds(SlotKind::Private), kinds(SlotKind::Standalone), kinds(SlotKind::Host)), (12, 5, 6));
        // one eval per slot, one Gamma per standalone slot, one batched Gamma per host
        assert_eq!(N_SLOTS + kinds(SlotKind::Standalone) + HOSTS.len(), N_FUNCTIONALS);
        // every private slot is hosted exactly once, by a Host slot that runs after it
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
        // every mask row fits the M message: L + 256 pads <= 512; the largest is SC_SZC at 50
        let l = |s: usize| {
            let (n, e, d) = SLOTS[s];
            (n + e) * d + 2
        };
        assert_eq!((0..N_SLOTS).map(l).max(), Some(50));
        for (n, d) in mask_specs() {
            assert!(n * d + 2 + 256 <= 512);
        }
        assert_eq!((0..N_SLOTS).map(|s| SLOTS[s].0).sum::<usize>(), 159);
        assert_eq!((0..N_SLOTS).map(|s| SLOTS[s].1).sum::<usize>(), 25);
        // helper planes cover the lookups pairwise, on six domains
        for dom in LOOKUP_DOMS {
            assert_eq!(lookups(dom).len().div_ceil(2), helpers(dom).1);
        }
        // T2 section D.2's per-domain U8 totals, and their sum
        let per_dom: Vec<usize> = LOOKUP_DOMS.iter().map(|d| lookups(*d).len() * d.len()).collect();
        assert_eq!(per_dom, vec![1_024, 19_456, 4_608, 6_656, 3_072, 26_624]);
        assert_eq!(per_dom.iter().sum::<usize>(), 61_440);
        assert_eq!((0..N_A).filter(|p| a_dom(*p) == Dom::F).count(), 11);
        assert_eq!((0..N_H).filter(|p| h_dom(*p) == Dom::F).count(), 6);
    }

    /// planes are laid out contiguously per domain and row-aligned, which the
    /// two `a_range` sweeps and the PCS grouping both depend on (T2 C.2)
    #[test]
    fn planes_are_row_aligned_and_contiguous_per_domain() {
        let lay = Layout::new();
        let mut offs: Vec<usize> = (0..N_A).map(|p| lay.a_off[p]).collect();
        let sorted = {
            let mut o = offs.clone();
            o.sort_unstable();
            o
        };
        assert_eq!(offs, sorted, "A planes are not packed in plane order");
        offs.dedup();
        assert_eq!(offs.len(), N_A, "two A planes share an offset");
        assert!((0..N_A).all(|p| lay.a_off[p] % N == 0), "an A plane is not row aligned");
        // each domain occupies ONE run of plane indices
        for dom in [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab] {
            let ids: Vec<usize> = (0..N_A).filter(|p| a_dom(*p) == dom).collect();
            assert!(!ids.is_empty() && ids.last().unwrap() - ids[0] + 1 == ids.len(), "domain {dom:?} is not a contiguous plane run");
        }
        for dom in [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab] {
            let ids: Vec<usize> = (0..N_H).filter(|p| h_dom(*p) == dom).collect();
            assert!(!ids.is_empty() && ids.last().unwrap() - ids[0] + 1 == ids.len(), "H domain {dom:?} is not a contiguous plane run");
        }
        // the description carries the derived counts, line by line
        let lines = lay.describe();
        assert_eq!(lines.len(), 6 + N_SLOTS + HOSTS.len());
        assert!(lines.iter().any(|l| l.contains("A rows=455 data=213 site-pairs=120")));
        assert!(lines.iter().any(|l| l.contains("H rows=384 data=280 site-pairs=51")));
        assert!(lines.iter().any(|l| l.contains("M rows=50 functionals=34 A-groups=35 H-groups=9")));
    }
}
