//! **STEP S5: the layout as a function of a SHAPE.**
//!
//! Everything the whole-block layout counts — the nine domains' logs, the `A`
//! and `H` plane lists, the lookup lists, the helper planes, the claim sites,
//! the slot table, the row totals, the PCS opening groups and the receipt
//! size — is computed here from a [`Shape`], with the toy shape as one
//! instance. `layout::Layout::new` builds the toy's row geometry through this
//! module and asserts the result against the frozen toy constants, so the two
//! cannot drift apart.
//!
//! **WHAT THIS STEP DOES NOT DO.** It computes LAYOUTS. It does not prove
//! anything at any shape but the toy: the kernel, grouped-query attention, the
//! two integer windows, the pad rule and the hidden endpoints are steps
//! S6..S11, and until they land the only shape that can produce a receipt is
//! the toy. `Shape::RUNG` and `Shape::M125` exist here as counted layouts and
//! as new profile strings, nothing more.
//!
//! The independent oracle for every number below is the pure-Python model
//! `scripts/zk60_private_block_layout_model.py`, whose outputs are in
//! `results/zk60_block125m_lane/model_{toy,rung,m125}.json`. The Rust and the
//! Python were written from the same memo but not from each other; the tests
//! in `grow_tests.rs` assert they agree, shape by shape.

use super::layout::{domain_log_at, Dom, ALL_DOMS, LOOKUP_DOMS, N_FUNCTIONALS, N_SLOTS, U8_LEN};
use zkp_core::hashtag::HashTag;
use super::layout::{SC_DMM, SC_DZC, SC_FZC, SC_GMM, SC_IO_IN, SC_IO_OUT, SC_KMM, SC_KVZC, SC_LZC, SC_PV, SC_QMM, SC_QZC, SC_RS, SC_SCORE, SC_SS, SC_SSM, SC_SZC, SC_TAB, SC_TZC, SC_UMM, SC_VMM, SC_WO, SC_ZS};

/// byte limbs of the isqrt witness `D`, `a1`, `a2` (each below `2^24`)
pub(crate) const LIMBS_ISQRT: usize = 3;
/// The FROZEN toy profile string. It is the gate of the pad rule (ruling P-1,
/// finding S9-F1) and of every later shape-driven addition: a new shape is a
/// NEW profile beside the toy, never an edit of it (D17).
pub(crate) const TOY_PROFILE: &str = "hashline-zk-mr1/private-block-t32-poc/1";
/// **The FROZEN-SEAM development rung's profile string** (ruling T-2 as
/// amended, 2026-09-20). This rung commits its endpoint inside
/// `private_seam.rs`, a file this lane keeps byte-identical to `11c01b2`, so
/// its endpoint cannot be tagged. A profile is WHOLLY legacy or WHOLLY
/// tagged, never a mixture — so this whole profile stays on the legacy rule.
/// It is a stepping-stone development FIXTURE, never a deliverable, barred by
/// name from any privacy statement, and [`Shape::rung_g`] replaces it.
pub(crate) const FROZEN_SEAM_RUNG_PROFILE: &str = "hashline-zk-mr1/private-block-rung-t24-dev/1";
const INT16_MAX: i128 = 32_767;
/// the norm's fixed-point shift; the denominator is `2^(tn+1) * D`
const NORM_TN: u32 = 11;
const NORM_CEPS: i128 = 1;
/// the softmax quotient's scale: `p` reaches `2^F_P`, so it needs `F_P + 1` bits
const F_P: u32 = 9;
/// **Note C-6 (stage 40).** The largest exp-table scale `Shape::new` admits:
/// the shaped reference kernel's own bound (it refuses `f_e >= 32`).
const F_E_MAX: u32 = 31;
/// **Ruling CS-5 (stage 41).** The widest model width `Shape::new` admits:
/// up to it the norm window derived from the 32767 bound holds every int16
/// input (the 32768 bound); from 16,385 it can be one bit short (S40-N1).
const WIDTH_MAX: usize = 16_384;
/// **Ruling CS-8 (stage 43).** The prefix of [`Shape::check_constructed`]'s
/// refusals.
const CS8_SHAPE_REFUSAL: &str = "private block shape: ruling CS-8 — ";
/// **Ruling CS-9 (stage 44).** The prefix of the block profile registry's two
/// refusals ([`Shape::new`]).
const CS9_REFUSAL: &str = "private block shape: ruling CS-9 — ";

// the wire format's shape-independent counts (`wire.rs`)
const WIRE_HEADER: usize = 8 + 32;
const COL_CHECKS: usize = 256;
/// the mask message is `2 * 512` `Fp2` words whatever the shape is
const MASK_VEC: usize = 1024;
/// `log2(MASK_DOM = 4096)`
const MASK_PATH: usize = 12;
/// **RULING C-4's budget, from `zk.rs`'s own constants and not retyped.** One
/// slot's masked sumcheck message lives in ONE row of the masking commitment:
/// `2^MASK_LOG_MSG` positions, of which `MASK_Q` are the random pads that hide
/// it. A slot whose message plus the pads exceeds the row cannot be masked.
const MASK_MSG: usize = 1usize << crate::zk::MASK_LOG_MSG;
const MASK_PADS: usize = crate::zk::MASK_Q;

/// the structural degree of each slot, BEFORE any pad support indicator
const BASE_DEGREE: [usize; N_SLOTS] = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2];

/// The slots whose relation is switched off on the pad by a support indicator,
/// and which therefore gain ONE degree when their governing domain pads
/// (memo §3.7a). `SC_LZC` and `SC_TAB` are deliberately absent: they are
/// homogeneous, so they gain nothing. The indicator itself is step S9; only
/// its COST is counted here.
const INDICATOR_SLOT_DOMAIN: [(usize, Dom); 8] =
    [(SC_SS, Dom::D), (SC_SSM, Dom::D), (SC_RS, Dom::S), (SC_DZC, Dom::D), (SC_QZC, Dom::Q), (SC_KVZC, Dom::Kv), (SC_SZC, Dom::S), (SC_FZC, Dom::F)];

fn clog2(v: usize) -> usize {
    assert!(v > 0, "clog2 of zero");
    v.next_power_of_two().trailing_zeros() as usize
}

fn isqrt_i128(v: i128) -> i128 {
    if v < 2 {
        return v;
    }
    let mut x = 1i128 << ((128 - v.leading_zeros()).div_ceil(2));
    loop {
        let y = (x + v / x) / 2;
        if y >= x {
            return x;
        }
        x = y;
    }
}

fn bit_length(v: i128) -> u32 {
    128 - v.leading_zeros()
}

/// ONE block geometry, plus the PCS parameters its receipt is priced at.
///
/// Built only through [`Shape::new`], which refuses by name every geometry the
/// construction cannot express and (ruling CS-9) every profile string that
/// does not name exactly this shape — or by the registered constructors
/// below, which ARE the registry's entries.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Shape {
    pub name: &'static str,
    /// the profile id this shape's proofs would carry. It is part of the
    /// transcript, so two shapes may never share one (D17: a new shape is a
    /// NEW profile beside the toy, never an edit of it).
    pub profile: &'static str,
    pub tokens: usize,
    pub width: usize,
    pub hidden: usize,
    pub q_heads: usize,
    pub head_dim: usize,
    pub kv_heads: usize,
    pub log_cols: usize,
    pub inv_rate: usize,
    /// the PCS's opened columns `Q`
    pub opened_cols: usize,
    /// the exponential table's fractional bits
    pub f_e: u32,
    pub endpoint_rows: usize,
    pub endpoint_log_n: usize,
    pub endpoint_inv_rate: usize,
    /// **S11b.** Does this shape's endpoint ride the GENERALISED endpoint of
    /// `endpoint_g.rs` instead of the frozen `private_seam.rs`? Derived in
    /// [`Shape::new`] from the declared endpoint parameters; never set by
    /// hand.
    pub endpoint_general: bool,
    /// the two integer windows, overridable for a development-only calibration
    pub norm_wrho: u32,
    pub wrho_s: u32,
    // ---- derived
    pub t_pad: usize,
    pub d_pad: usize,
    pub h_pad: usize,
    pub f_pad: usize,
    pub d_max: i128,
}

/// **RULING CS-9: THE BLOCK PROFILE REGISTRY** — the constructor of every
/// block shape this build registers, one per block profile string (the nine
/// profiles of stage 24's registry test). Each constructor builds its shape
/// past CS-9's own check because it IS the entry for its profile.
const REGISTERED_BLOCK_SHAPES: [fn() -> Shape; 9] = [Shape::toy, Shape::rung, Shape::rung_g, Shape::rung_k4, Shape::rung_p2, Shape::rung_c6, Shape::rung_w14, Shape::rung_e32, Shape::m125];

/// The one shape a block profile string names, or `None` for a string this
/// build does not register. A TEST-ONLY shape's profile is registered only in
/// a test build, as ruling CS-7 registers its run profile: rung-K8 (stage 37)
/// is built in `k8_tests.rs`, so its arm exists under `#[cfg(test)]` and a
/// release build refuses its profile string as unregistered. No profile
/// string is written here, so the source registry of stages 24 and 33 is
/// unchanged.
fn registered_block_shape(profile: &str) -> Option<Shape> {
    if let Some(sh) = REGISTERED_BLOCK_SHAPES.iter().map(|ctor| ctor()).find(|s| s.profile == profile) {
        return Some(sh);
    }
    #[cfg(test)]
    if profile == super::k8_tests::K8_BLOCK_PROFILE {
        return Some(super::k8_tests::rung_k8_built_by(Shape::build));
    }
    None
}

impl Shape {
    /// **THE one place a block profile string meets a geometry.** Every
    /// refusal of the construction ([`Shape::build`], below), and then
    /// **RULING CS-9** (security owner, 2026-09-23; the code review's note
    /// K-4): a privacy statement is per PROFILE (D22 names a profile string),
    /// so a profile string names exactly one shape. A REGISTERED block profile
    /// string is admitted only with the one shape it is registered for
    /// ([`registered_block_shape`]), compared field by field as ruling CS-7
    /// compares a run's block shape, and a profile string this build does not
    /// register is refused — outside `#[cfg(test)]`: a test build admits an
    /// unregistered string, which is how the probe and fixture shapes of the
    /// test files are built. Before this ruling the frozen toy's profile
    /// string at rung-G's geometry passed every check, carried no pad rule
    /// while its `Dom::F` and `Dom::D` pad, hashed under the legacy rule, and
    /// every honest proof at it was rejected by the verifier at slot 2
    /// (`s44-before-reproducer.log`). CS-9 comes AFTER every other refusal, so
    /// each of them keeps its own message first. A refusal and nothing else:
    /// every registered shape is built exactly as before, and
    /// [`Shape::check_constructed`], which runs this again at every entry,
    /// re-checks it on a value whose profile or parameters were written.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        name: &'static str,
        profile: &'static str,
        tokens: usize,
        width: usize,
        hidden: usize,
        q_heads: usize,
        head_dim: usize,
        kv_heads: usize,
        log_cols: usize,
        inv_rate: usize,
        f_e: u32,
        endpoint_rows: usize,
        endpoint_log_n: Option<usize>,
        endpoint_inv_rate: Option<usize>,
        norm_wrho: Option<u32>,
        wrho_s: Option<u32>,
    ) -> Result<Shape, String> {
        let sh = Shape::build(name, profile, tokens, width, hidden, q_heads, head_dim, kv_heads, log_cols, inv_rate, f_e, endpoint_rows, endpoint_log_n, endpoint_inv_rate, norm_wrho, wrho_s)?;
        sh.block_profile_names_this_shape(cfg!(test))?;
        Ok(sh)
    }

    /// **Ruling CS-9's check** (see [`Shape::new`]). `admit_unregistered` is
    /// `cfg!(test)` at its one production caller.
    fn block_profile_names_this_shape(&self, admit_unregistered: bool) -> Result<(), String> {
        match registered_block_shape(self.profile) {
            Some(reg) if reg == *self => Ok(()),
            Some(reg) => {
                // the parameters `Shape::new` is handed; every other field is
                // derived from them or pinned, so a difference shows here
                let differ: Vec<&str> = [
                    ("name", reg.name != self.name),
                    ("tokens", reg.tokens != self.tokens),
                    ("width", reg.width != self.width),
                    ("hidden", reg.hidden != self.hidden),
                    ("q_heads", reg.q_heads != self.q_heads),
                    ("head_dim", reg.head_dim != self.head_dim),
                    ("kv_heads", reg.kv_heads != self.kv_heads),
                    ("log_cols", reg.log_cols != self.log_cols),
                    ("inv_rate", reg.inv_rate != self.inv_rate),
                    ("f_e", reg.f_e != self.f_e),
                    ("endpoint_rows", reg.endpoint_rows != self.endpoint_rows),
                    ("endpoint_log_n", reg.endpoint_log_n != self.endpoint_log_n),
                    ("endpoint_inv_rate", reg.endpoint_inv_rate != self.endpoint_inv_rate),
                    ("norm_wrho", reg.norm_wrho != self.norm_wrho),
                    ("wrho_s", reg.wrho_s != self.wrho_s),
                ]
                .iter()
                .filter(|(_, d)| *d)
                .map(|(n, _)| *n)
                .collect();
                Err(format!(
                    "{CS9_REFUSAL}the block profile {:?} is registered for exactly one shape, {:?}; the shape handed, {:?}, differs from it in {}",
                    self.profile,
                    reg.name,
                    self.name,
                    differ.join(", ")
                ))
            }
            None if admit_unregistered => Ok(()),
            None => Err(format!("{CS9_REFUSAL}{:?} is not a block profile this build registers, so it names no shape ({:?} was handed)", self.profile, self.name)),
        }
    }

    /// **TEST ONLY (ruling CS-9).** The check as a build WITHOUT
    /// `#[cfg(test)]` makes it — an unregistered profile string refused — so
    /// a test can show what a release build does with the probe shapes a test
    /// build admits. A release build has no such method.
    #[cfg(test)]
    pub(crate) fn check_block_profile_as_a_release_build(&self) -> Result<(), String> {
        self.block_profile_names_this_shape(false)
    }

    /// Every refusal of the construction but ruling CS-9's. PRIVATE: it is
    /// called by [`Shape::new`] (which then runs CS-9) and by the registered
    /// constructors below, which are the registry's own entries (building
    /// them through `Shape::new` would consult the registry for the entry
    /// being built); rung-K8's `#[cfg(test)]` registry arm is handed it as a
    /// function pointer. `s44_tests` pins that there is no other caller.
    #[allow(clippy::too_many_arguments)]
    fn build(
        name: &'static str,
        profile: &'static str,
        tokens: usize,
        width: usize,
        hidden: usize,
        q_heads: usize,
        head_dim: usize,
        kv_heads: usize,
        log_cols: usize,
        inv_rate: usize,
        f_e: u32,
        endpoint_rows: usize,
        endpoint_log_n: Option<usize>,
        endpoint_inv_rate: Option<usize>,
        norm_wrho: Option<u32>,
        wrho_s: Option<u32>,
    ) -> Result<Shape, String> {
        if [tokens, width, hidden, q_heads, head_dim, kv_heads].iter().any(|v| *v == 0) {
            return Err("private block shape: an axis is zero".into());
        }
        let (t_pad, d_pad) = (tokens.next_power_of_two(), width.next_power_of_two());
        let (h_pad, f_pad) = (q_heads.next_power_of_two(), hidden.next_power_of_two());
        // T-8: the RoPE partner bit is addressed as `log - log2(head_dim)`, so
        // a head dimension that is not a power of two has no such bit.
        if !head_dim.is_power_of_two() || head_dim < 2 {
            return Err("private block shape: the head dimension is not an even power of two".into());
        }
        // T-2, as a NAMED construction refusal instead of `fold_rows_i8`'s
        // assertion deep inside a numeric helper: every matmul folds over a
        // padded width, and the padded widths are powers of two by
        // construction, so what has to be refused is a shape whose padded
        // widths do not line up.
        if !d_pad.is_power_of_two() || !f_pad.is_power_of_two() || !t_pad.is_power_of_two() {
            return Err("private block shape: a matmul width is not a power of two".into());
        }
        // The `Q` and `D` domains share one flat index, which is only correct
        // when the padded head slots tile the padded width exactly.
        if d_pad != h_pad * head_dim {
            return Err("private block shape: d_pad differs from h_pad * head_dim".into());
        }
        if q_heads % kv_heads != 0 {
            return Err("private block shape: the query heads do not divide into the key-value heads".into());
        }
        // C-1: the padded head axis is cut into one equal block of slots per
        // key-value group, so that the group is the HIGH bits of the slot
        // index and "query head h reads key-value head slot >> log(slots per
        // group)" is a fixed-coordinate relation. That needs `kv_heads` to
        // divide the PADDED head count, not only the true one.
        if h_pad % kv_heads != 0 {
            return Err("private block shape: the key-value heads do not divide the padded head count".into());
        }
        if !(2..=30).contains(&log_cols) || !inv_rate.is_power_of_two() || inv_rate < 2 {
            return Err("private block shape: the row geometry is out of range".into());
        }
        // **NOTE C-6 of the census check, STAGE 40: the exp table's
        // fractional bits, bounded by name.** Nothing bounded `f_e`. The
        // statement constructor computes `2^f_e` as `1i64 << f_e`, so from
        // `f_e = 64` on it wraps: a table scaled by the wrapped value is
        // admitted, the builder admits the input, and EVERY honest proof is
        // rejected by the verifier (slot 17, the softmax zero-check —
        // measured at rung-G's geometry, `s40-before-named.log`). Between, at
        // 54..=62 the builder's `E 2^F_P` and `Sum` overflow `i64` and it
        // refuses every input, and at 63 the constructor refuses every table.
        // The bound is the reference kernel's own (`private-block-kernel-
        // shaped` refuses `f_e >= 32`): above it the builder has no oracle,
        // and the soundness premise of `layout.rs` is written for the
        // registered calibrations (toy 9, the rungs 12, 125M 9), all far
        // below it. No registered shape moves.
        if f_e > F_E_MAX {
            return Err(format!(
                "private block shape: note C-6 — f_e = {f_e} fractional bits of the exp table is above {F_E_MAX}, the reference kernel's bound; from f_e = 64 the statement's 2^f_e wraps and every honest proof is rejected by the verifier"
            ));
        }
        // **RULING CS-5 (security owner, 2026-09-23; stage 40's finding
        // S40-N1): a width above 16,384, as a named construction refusal.**
        // The norm window below is `tn + 1 + bits(isqrt(1 + width 32767^2))`,
        // derived from the int16 MAXIMUM; `-32768` is a legal input, so the
        // bound the denominator must hold is 32768. The two windows agree at
        // every width up to 2^14 = 16,384 (checked width by width,
        // `s40_tests`); from 16,385 on the derived one is one bit short at 21
        // widths up to 2^20 (first 16,385: 34 derived, 35 needed), where the
        // norm remainder becomes reachable on inputs near `-32768` and the
        // builder refuses them by name — an input-dependent refusal. No
        // target is that wide (the widest registered shape is 768, the 8B
        // width 4,096). The ruling is the simplest one: refuse such a width
        // by name here; re-deriving the window from the 32768 bound is the
        // alternative, worth doing only when a wider model is a target. No
        // registered shape moves.
        if width > WIDTH_MAX {
            return Err(format!(
                "private block shape: ruling CS-5 — width {width} is above {WIDTH_MAX}; beyond it the norm window derived from the 32767 bound can be one bit short of the 32768 input bound (finding S40-N1), so the norm remainder would be reachable on some private inputs; a wider model needs the window re-derived first"
            ));
        }
        let d_max = isqrt_i128(NORM_CEPS + width as i128 * INT16_MAX * INT16_MAX);
        // **RULING CS-2 (security owner, 2026-09-22; check finding C-2): an
        // undersized window OVERRIDE, as a named construction refusal.**
        //
        // The softmax window: `sigma_s < Sum <= tokens 2^f_e`, so the window
        // this shape derives, `clog2(tokens) + f_e`, is exactly the smallest
        // that holds `tokens 2^f_e`. The builder and the kernel check
        // `sigma_s` only; on the LAST token row no causally masked position
        // exists, so `rho_s` there is guarded by this window alone, and under
        // a smaller override an input the builder admits made the honest proof
        // fail at the verifier — depending on the private input.
        //
        // The norm window: the denominator is `D 2^(tn + 1)` with `D <=
        // isqrt(1 + width 32768^2)` — `-32768` is a legal input, so the bound
        // is 32768 and not the 32767 of `d_max` — and the remainder is below
        // it. An override below the smallest window holding that bound makes
        // the norm remainder reachable, which the builder refuses by name on
        // some private inputs. At every width up to 2^14 = 16,384 (every
        // registered shape: the widest is 768) that smallest window IS the
        // derivation `tn + 1 + bits(d_max)`; from width 16,385 on, the
        // derivation itself can be one bit short, which this ruling (about
        // overrides) does not touch — see the stage-40 ledger (`s40_tests`);
        // ruling CS-5 above refuses those widths.
        //
        // Overrides at or above those windows are kept; no registered shape
        // passes either override, so no registered shape moves.
        if let Some(w) = wrho_s {
            let derived = clog2(tokens) as u64 + u64::from(f_e);
            if u64::from(w) < derived {
                return Err(format!(
                    "private block shape: ruling CS-2 — the softmax window override wrho_s = {w} is below the window this shape derives, clog2({tokens}) + f_e = {derived} bits (tokens 2^f_e must fit in 2^wrho_s); on the last token row a rho_s above the window would be admitted by the builder and the honest proof rejected, depending on the private input"
                ));
            }
        }
        if let Some(w) = norm_wrho {
            let den = isqrt_i128(NORM_CEPS + width as i128 * (INT16_MAX + 1) * (INT16_MAX + 1)) << (NORM_TN + 1);
            let needed = bit_length(den - 1);
            if w < needed {
                return Err(format!(
                    "private block shape: ruling CS-2 — the norm window override norm_wrho = {w} is below the window this shape derives, {needed} bits (the norm denominator reaches isqrt(1 + {width} x 32768^2) x 2^{} = {den}); the norm remainder would be reachable and refused by the builder on some private inputs",
                    NORM_TN + 1
                ));
            }
        }
        let (e_log_n, e_rate) = (endpoint_log_n.unwrap_or(log_cols), endpoint_inv_rate.unwrap_or(inv_rate));
        let sh = Shape {
            name,
            profile,
            tokens,
            width,
            hidden,
            q_heads,
            head_dim,
            kv_heads,
            log_cols,
            inv_rate,
            opened_cols: COL_CHECKS,
            f_e,
            endpoint_rows,
            endpoint_log_n: e_log_n,
            endpoint_inv_rate: e_rate,
            // **S11b.** The frozen `private_seam.rs` carries this shape's
            // endpoint only when all four of its module constants are what
            // the shape declares: a plane of at most `2^MAX_LOG_LEN = 4,096`
            // words (`private_seam.rs:69`), `LOG_COLS = 8` (`:28`) and
            // `INV_RATE = 8` (`:30`), the last two hashed into every
            // `SeamSpec::digest()` and so not editable. Otherwise the
            // endpoint is the generalised one of `endpoint_g.rs`. This is a
            // DERIVATION and not a flag so that a shape cannot declare
            // parameters the machinery it selects does not honour: the toy
            // and the frozen-seam rung satisfy all three conditions and do
            // not move, the rung-G profile and 125M fail them by their own
            // declared parameters.
            endpoint_general: !(t_pad * d_pad <= 4096 && e_log_n == 8 && e_rate == 8),
            // §3.3: the norm quotient's window is `tn + 1 + bits(D_max)`
            norm_wrho: norm_wrho.unwrap_or(NORM_TN + 1 + bit_length(d_max)),
            // §3.4: `Sum <= T * 2^F_E` and `sigma_s < Sum`
            wrho_s: wrho_s.unwrap_or(clog2(tokens) as u32 + f_e),
            t_pad,
            d_pad,
            h_pad,
            f_pad,
            d_max,
        };
        // **STAGE 21, finding F-2 of the stage-20 review: a NAMED refusal
        // where there was only a symptom.**
        //
        // The two BILINEAR slots (`argument.rs`'s `SC_SCORE` and `SC_PV`)
        // build their coordinate lists AXIS BY AXIS from the geometry —
        // `A_QR8` as `(t | group | head-in-group | c)`, `A_KR8` as
        // `(j | group | c)`, `A_P` as `(group | head-in-group | t | s)`,
        // `A_V8` as `(s | group | i)` — so each list is exactly as long as
        // its domain's NATURAL log. `B::a_at` measures a list against the
        // plane's `Shape::log`, which is the P-3 LIFTED log. At a shape whose
        // `Dom::Q`, `Dom::Kv` or `Dom::S` sits BELOW the row width, the lift
        // makes the plane's log larger than any list the bilinear arms can
        // write, and `run_slot` refuses "slot s table shape" — fail-closed,
        // but the message names a symptom and arrives deep inside the
        // argument rather than at construction. (The reviewer met exactly
        // this while choosing a synthetic four-key-value-head geometry; it
        // forced `head_dim = 8` rather than 2.)
        //
        // No shape this module builds is affected: the toy's `Dom::Kv` is at
        // the row width and everything else is above it. This refusal is a
        // construction-time statement of the same fact, by name.
        for dom in [Dom::Q, Dom::Kv, Dom::S] {
            if sh.log(dom) != sh.natural_log(dom) {
                return Err(format!(
                    "private block shape: the bilinear attention slots cannot serve a shape whose {dom:?} domain is lifted by P-3 (natural log {}, lifted to the row width {})",
                    sh.natural_log(dom),
                    sh.log(dom)
                ));
            }
        }
        // **STAGE 23, RULING S-1 (the shaped check's finding B-2): the P-3
        // lift's standing hypothesis, as a named refusal.**
        //
        // The privacy argument's "Fact 1" — a claim's evaluation point never
        // reaches a commitment's non-data rows — is FALSE on the helper
        // commitment `H`. The claim of slot `SC_ZS` on the hidden plane `H_U`
        // and the pairless LogUp sum claim both put data parts on the two
        // ZERO-SUM rows, which the argument's own accounting counts as
        // non-data, and `audit_claims` does not forbid it (its only
        // row-placement checks are the proximity pair and site-row
        // exclusivity).
        //
        // It is harmless today for exactly one reason: the lookup-table
        // domain sits at EXACTLY the row width, so for both claims the row
        // part of the eq-tensor is `eq_table_msb(&point[..0]) = [1]` and each
        // zero-sum row's weight is the point-INDEPENDENT coefficient. Move
        // the table domain above the row width and those rows would carry an
        // eq-tensor in the claim's point: the non-data block becomes
        // point-dependent and the argument's whole corollary about the
        // repaired bilinear slots stops being a theorem.
        //
        // `Dom::Tab`'s natural log is the fixed `clog2(U8_LEN)`, and
        // `layout::domain_log_at` only lifts UPWARD, so the condition is
        // equivalent to "the row width is at least the table's natural size".
        // No shape this module builds is affected — the toy sits exactly at
        // it and every other shape is lifted onto it. This is a
        // construction-time statement of the fact, by name, so that a future
        // shape cannot take it away silently.
        if sh.log(Dom::Tab) != sh.log_cols {
            return Err(format!(
                "private block shape: ruling S-1 — the lookup-table domain must sit at EXACTLY the row width (Dom::Tab natural log {}, at this shape {}, against a row width of 2^{}); below it the table spans several rows and the helper commitment's zero-sum rows would carry point-dependent data weights",
                sh.natural_log(Dom::Tab),
                sh.log(Dom::Tab),
                sh.log_cols
            ));
        }
        // **STAGE 23, RULING S-3 (the shaped check's finding B-3): a latent
        // liveness trap, as a named refusal.**
        //
        // `SC_SCORE`'s two private factors end their coordinate lists in two
        // copies of the SAME symbol segment, `rho(lkv .. lkv + log2(head_dim))`
        // (`argument.rs:1141-1158`), because a coordinate list owns its
        // entries. A column key is the LAST `log_cols` entries of a list, so
        // if `log2(head_dim)` reached `log_cols` the two keys would be the
        // last `log_cols` entries of that one shared segment — equal BY
        // CONSTRUCTION on every run. `opening_groups_at` would then return
        // one group fewer than the schedule declares and `check_opening`
        // would refuse EVERY proof at that shape.
        //
        // It is a liveness cliff, not a leak, and it is not near: head
        // dimensions of 8 to 64 against row widths of 2^8 to 2^14. The guard
        // above (ruling F-2) covers only the opposite direction, a bilinear
        // domain BELOW the row width. `SC_PV` cannot collide structurally at
        // any shape: its `A_V8` list always ends in the FIXED `r_i`, a
        // segment the existing T-8 refusal `head_dim >= 2` keeps non-empty,
        // while its `A_P` list ends in the shared source-token symbols.
        //
        // **STAGE 24, RULING C-2 (the slot-closure check's finding B-2): THIS
        // REFUSAL PROTECTS THREE SLOTS, NOT ONE.** Slots `SC_QZC` and
        // `SC_KVZC` raise TWO claims on the SAME plane — the RoPE partner
        // half, `cf[log - log2(head_dim)] = Coord::Flip(..)` in their own arm
        // (trap T-8) — at points differing in exactly that one coordinate. A
        // column key is the LAST `log_cols` entries of a claim's point
        // (`protocol::part_key_at`), so the flipped coordinate is inside the
        // key exactly when `log2(head_dim) <= log_cols`, and the two claims
        // fall into ONE opening group as soon as it is not. This refusal
        // enforces the strictly stronger `head_dim < 2^log_cols`, so both the
        // boundary case and everything above it are already refused, with two
        // bits to spare at every shape in scope. (What it does NOT cover, and
        // nothing does: a challenge at `rho_k = 1/2`, where the flipped and
        // unflipped coordinates are equal AS FIELD ELEMENTS — a 2^-128
        // liveness event on an honest run, not a structural collision.)
        // `s24_tests::the_s3_refusal_also_separates_the_two_rotary_claims_of_slots_15_and_16`.
        if sh.head_dim >= 1usize << sh.log_cols {
            return Err(format!(
                "private block shape: ruling S-3 — the head dimension {} reaches the row width 2^{}, so the two private factors of the score slot would share their whole tail and their column keys would collide on every run (and so would the two rotary claims of slots 15 and 16, ruling C-2); every proof at this shape would be refused for its opening-group count",
                sh.head_dim, sh.log_cols
            ));
        }
        // **STAGE 33, RULING S-6: the dead arm of `Shape::a_groups`, as a
        // named refusal.**
        //
        // `a_groups` fixes the `A` opening's column-weight GROUP STRUCTURE,
        // which is the structure the privacy argument's opening accounting
        // counts. Its `SC_TZC` term has two arms: the live one deduplicates
        // the limb sub-slices' column offsets `k * t_pad mod 2^log_cols`, and
        // the FIRST one returns the constant 1 when the padded token count
        // reaches the row width. Stages 31 and 32 established that **no
        // registered shape reaches the first arm** — 125M's `Dom::T` is 2^9
        // against a row width of 2^14, rung-W14's is 2^6 against 2^14 — and
        // the cheapest shape that would reach it prices at a 39 MB receipt,
        // because `Dom::S = h_pad * t_pad^2` grows quadratically in the
        // tokens. An arm no shape reaches is code nobody tests, inside the
        // one function that fixes the opening groups.
        //
        // The ruling is to REFUSE THE FAMILY rather than to grow a test for
        // it: a shape whose padded token count is at or above the row width
        // is refused here, by name, so after validation the arm is
        // unreachable rather than merely unreached, and every shape that
        // proves anything takes one branch.
        //
        // It is neither a privacy nor a soundness condition, and no value
        // moves: on the refused family the two arms AGREE. `t_pad` is a power
        // of two (T-2), so `t_pad >= 2^log_cols` makes every offset
        // `k * t_pad` a multiple of the row width and the live arm's
        // deduplicated set is `{0}` — the first arm's own 1
        // (`s33_tests::the_refused_arm_and_the_live_arm_agree_wherever_both_are_defined`).
        // The arm is a shortcut, not a second behaviour.
        //
        // **What the refused family IS, in plain words**: token counts at or
        // above the row width — at the toy's row width of 2^8, 129 tokens and
        // up. **Lifting the refusal later takes a shape of that family in the
        // ORDINARY filter**, proved, tampered and censused like any other, not
        // an edit here.
        if sh.natural_log(Dom::T) >= sh.log_cols {
            return Err(format!(
                "private block shape: ruling S-6 — the padded token count 2^{} ({} tokens) is at or above the row width 2^{}, which is the family that reaches `Shape::a_groups`'s unreached first arm; the A opening's group structure would then be decided by a branch no registered shape takes and no test covers",
                sh.natural_log(Dom::T),
                sh.tokens,
                sh.log_cols
            ));
        }
        // **STAGE 24, RULING C-4 (the slot-closure check's findings B-4 and
        // B-5): THE MASK BUDGET, AS A NAMED CONSTRUCTION REFUSAL.**
        //
        // Every slot's masked sumcheck message is `L_s = (main + ext)·degree
        // + 2` field elements, and it is carried in ONE row of the masking
        // commitment: a `2^MASK_LOG_MSG = 512`-position message of which
        // `MASK_Q = 256` are the random pads that hide it (`zk::mask_commit`,
        // `zk.rs:442`). So `L_s + 256 <= 512` — `L_s <= 256` — is a condition
        // on the SHAPE, and until this stage the only thing that enforced it
        // was that same line: a prover-side `assert!`, a PANIC, deep inside a
        // numeric helper, on a shape the caller had already been handed and
        // after the witness had been built. Shape validation had ten refusals
        // and none was this one.
        //
        // It is not a privacy or a soundness condition: a shape that broke it
        // would produce no proof at all. It is the same kind of liveness
        // cliff as ruling S-3's, and it is refused in the same place, by
        // name, with the slot and the length in the message.
        //
        // **No shape this module builds is near it**: the worst is 125M's
        // `SC_SZC` at 117 + 256 of 512. A violating shape was constructible
        // before this commit — 2^20 − 1 tokens over 2,048 query heads of 8
        // gives `Dom::S = 2^51`, a padding domain, so `SC_SZC` declares
        // degree 5 and a 262-element message — and
        // `s24_tests::a_shape_whose_mask_leaves_no_room_for_the_pads_is_refused_by_name`
        // records it, with the control one bit below at 252.
        {
            let lens = sh.slot_lengths();
            let sl = sh.slots();
            for s in 0..N_SLOTS {
                if lens[s] + MASK_PADS > MASK_MSG {
                    return Err(format!(
                        "private block shape: ruling C-4 — slot {s}'s masked sumcheck message is {} field elements ({} main + {} extension rounds at degree {}, plus 2), and the masking commitment gives each slot ONE {MASK_MSG}-position row of which {MASK_PADS} are its random pads; {} + {MASK_PADS} > {MASK_MSG}, so the mask would not fit",
                        lens[s], sl[s].0, sl[s].1, sl[s].2, lens[s]
                    ));
                }
            }
        }
        Ok(sh)
    }

    /// **RULING CS-8 (security owner, 2026-09-23; stage 42's note S42-N1 and
    /// the sweep it asked for): is this value one [`Shape::new`] builds?**
    /// `Shape`'s fields are readable everywhere in the crate — hundreds of
    /// reads across the lane — so they stay visible, and a field write can
    /// therefore skip every refusal above (stage 43 measured a rung-G shape
    /// with its norm window written below the one it derives, ruling CS-2's
    /// refusal, prove and VERIFY). So the invariant is re-checked instead of
    /// sealed: `Shape::new` is run again on this value's own parameters (the
    /// overridable windows and endpoint parameters passed as the overrides
    /// they already are, which `Shape::new` returns unchanged) and the result
    /// must equal this value, field for field. A value that passes is exactly
    /// a value `Shape::new` could have returned. Called first at every
    /// single-block entry and in the two shared bodies (`protocol.rs`,
    /// `verify_bytes_at`); a run's shape is sealed inside `RunShape` and
    /// compared with its registered shape by ruling CS-7. It computes no
    /// digest, absorbs nothing, draws nothing and moves no byte. Since
    /// stage 44 `Shape::new` includes ruling CS-9, so a value whose PROFILE
    /// was written (or whose parameters were, under a registered profile) is
    /// refused here with CS-9's refusal inside CS-8's.
    pub(crate) fn check_constructed(&self) -> Result<(), String> {
        let rebuilt = Shape::new(
            self.name,
            self.profile,
            self.tokens,
            self.width,
            self.hidden,
            self.q_heads,
            self.head_dim,
            self.kv_heads,
            self.log_cols,
            self.inv_rate,
            self.f_e,
            self.endpoint_rows,
            Some(self.endpoint_log_n),
            Some(self.endpoint_inv_rate),
            Some(self.norm_wrho),
            Some(self.wrho_s),
        )
        .map_err(|e| format!("{CS8_SHAPE_REFUSAL}{:?} is not a shape Shape::new builds: Shape::new refuses its own parameters ({e})", self.name))?;
        if rebuilt == *self {
            return Ok(());
        }
        // only the derived and pinned fields can differ: every other one was
        // handed to `Shape::new` as it stands
        let differ: Vec<&str> = [
            ("opened_cols", rebuilt.opened_cols != self.opened_cols),
            ("endpoint_general", rebuilt.endpoint_general != self.endpoint_general),
            ("t_pad", rebuilt.t_pad != self.t_pad),
            ("d_pad", rebuilt.d_pad != self.d_pad),
            ("h_pad", rebuilt.h_pad != self.h_pad),
            ("f_pad", rebuilt.f_pad != self.f_pad),
            ("d_max", rebuilt.d_max != self.d_max),
        ]
        .iter()
        .filter(|(_, d)| *d)
        .map(|(n, _)| *n)
        .collect();
        Err(format!("{CS8_SHAPE_REFUSAL}{:?} is not a shape Shape::new builds: its {} differ from what Shape::new derives from its parameters", self.name, differ.join(", ")))
    }

    /// THE TOY, the only shape that proves anything today.
    pub(crate) fn toy() -> Shape {
        Shape::build("toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)", TOY_PROFILE, 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None).expect("the toy shape is well formed")
    }

    /// THE DEVELOPMENT RUNG of ruling P-7 (memo §9a). `F_E = 12` is a
    /// rung-only calibration, chosen so that the softmax window breaks at
    /// `T = 24` and the third `sigma_s` limb is exercised as it is at 125M.
    /// Development grade, never a deliverable: no receipt from it is shown to
    /// anyone and no soundness or privacy statement is made from it.
    pub(crate) fn rung() -> Shape {
        Shape::build(
            "development rung (T24 / d96 / f192, 6 heads of 16 over 2 KV heads)",
            FROZEN_SEAM_RUNG_PROFILE,
            24,
            96,
            192,
            6,
            16,
            2,
            10,
            4,
            12,
            // **S11a: the endpoint numbers the frozen seam actually gives.**
            // `SeamSpec::new` refuses the TRUE `(24, 96)` endpoint (both axes
            // must be powers of two), and accepts the PADDED `(t_pad, d_pad)
            // = (32, 128)` at exactly its 4,096-word ceiling. That plane has
            // `4096 / 2^LOG_COLS = 16` data rows and `16 + MASK_ROWS = 21`
            // commitment rows, and the seam's `INV_RATE` is the frozen 8,
            // hashed into every `SeamSpec::digest()` and so not editable.
            // The declared 14 / 4 were the TRUE shape's and matched nothing.
            21,
            Some(8),
            Some(8),
            None,
            None,
        )
        .expect("the rung shape is well formed")
    }

    /// **THE RUNG-G PROFILE (S11b).** The development rung's geometry exactly
    /// — same tokens, width, hidden, heads, row width, rate and calibration,
    /// so every one of its counted layout numbers but the endpoint's is the
    /// rung's — carried on the GENERALISED endpoint instead of the frozen
    /// seam. It is a NEW profile beside the rung (D17), so it has its own
    /// transcript and its own digests, and the frozen-seam rung keeps
    /// working unchanged beside it.
    ///
    /// Its endpoint takes the DEFAULTS, `endpoint_log_n = log_cols = 10` and
    /// `endpoint_inv_rate = inv_rate = 4`, which is exactly the
    /// configuration 125M uses. The padded `(32, 128)` plane is 4,096 words,
    /// so `4096 / 2^10 = 4` data rows — MORE THAN ONE, as 125M's 32 will be,
    /// which the frozen seam's 16 also were but at a row width the 125M
    /// shape cannot use — and `4 + MASK_ROWS = 9` commitment rows.
    /// Development grade, never a deliverable.
    pub(crate) fn rung_g() -> Shape {
        Shape::build(
            "development rung, generalised endpoint (T24 / d96 / f192, 6 heads of 16 over 2 KV heads)",
            "hashline-zk-mr1/private-block-rung-g-t24-dev/1",
            24,
            96,
            192,
            6,
            16,
            2,
            10,
            4,
            12,
            9,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-G shape is well formed")
    }

    /// **THE FOUR-KEY-VALUE-HEAD DEVELOPMENT RUNG (stage 22, "rung-K4").**
    ///
    /// **Why it exists.** The S19-F1 repair makes the key-value GROUP a
    /// sumcheck variable, `lkv = log2(kv_heads)` of them under a public
    /// `eq(r_g, .)`. Every proof-level test and every capture bundle this
    /// lane has ever taken is at `lkv = 1` (the two rungs) or `lkv = 0` (the
    /// frozen toy); the only `lkv = 2` shape is 125M, whose runs are 484 MB
    /// and which the Python privacy gate cannot ingest. **More than one
    /// group bit had therefore never been exercised anywhere a tool can
    /// read.** This shape is the smallest honest place to do it.
    ///
    /// **The geometry, and why each number is what it is.** It is
    /// [`Shape::rung_g`]'s in every respect but the head axis — same tokens,
    /// width, hidden, row width, rate, `F_E` calibration, generalised
    /// endpoint and endpoint rows — with the heads recut as **12 query heads
    /// of 8 over 4 key-value heads**:
    ///
    /// * `q_heads = 12`, `kv_heads = 4`, so `lkv = 2` and each group owns a
    ///   group of THREE true query heads;
    /// * `h_pad = 16`, `slots_per_kv_group = 4`, so the padded head slots are
    ///   `{3, 7, 11, 15}` — one at the end of each group's own block, which
    ///   is 125M's head geometry exactly (§3.7a note 2) and the case a
    ///   contiguous padded tail could never produce;
    /// * `head_dim = 8` because `d_pad = h_pad * head_dim` must hold and
    ///   `width = q_heads * head_dim = 96` keeps the rung's width, and
    ///   because a smaller head dimension would put `Dom::Kv` BELOW the row
    ///   width, where ruling F-2's P-3 refusal (stage 21) forbids the
    ///   bilinear slots. At `head_dim = 8`, `Dom::Kv = 32 * 4 * 8 = 2^10` is
    ///   exactly the row width — the toy's case, not a lift — and `Dom::Q`
    ///   and `Dom::S` are above it.
    ///
    /// **What it costs.** `Dom::S = h_pad * t_pad * t_pad = 2^14`, twice
    /// rung-G's, because sixteen head slots replace eight. That is the only
    /// axis that grows, and it is what makes the receipt bigger than
    /// rung-G's.
    ///
    /// Development grade, never a deliverable (ruling P-7), its OWN profile
    /// (D17) and therefore its own hash-tag key set. No existing shape moves.
    pub(crate) fn rung_k4() -> Shape {
        Shape::build(
            "development rung, four key-value heads (T24 / d96 / f192, 12 heads of 8 over 4 KV heads)",
            "hashline-zk-mr1/private-block-rung-k4-t24-dev/1",
            24,
            96,
            192,
            12,
            8,
            4,
            10,
            4,
            12,
            9,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-K4 shape is well formed")
    }

    /// **THE BOTH-BRANCHES-OF-THE-PAD-RULE DEVELOPMENT SHAPE (stage 30,
    /// "rung-P2").**
    ///
    /// **Why it exists.** Ruling P-1's pad-zero term is per HOST SLOT and is
    /// drawn only when that slot's domain actually pads: `argument.rs` draws
    /// one extra `mu` (`n_pad`) and a `zeta` **iff `pad_on`**, and
    /// [`super::argument`]'s `B::supp` returns `None` — no public support
    /// table and no gate — when `!self.pads(dom)`. At `rung`, `rung_g` and
    /// `rung_k4` **all nine domains pad**, so those shapes exercise the
    /// `pad_on == true` arm only; the one shape that takes the FALSE arm
    /// while still carrying the rule is 125M, whose proofs are `#[ignore]`d
    /// heavy tests. This shape takes both arms at a size the ordinary test
    /// filter runs in seconds.
    ///
    /// **The geometry, and why each number is forced.** It is
    /// [`Shape::rung_k4`]'s PADDED layout exactly — `t_pad = 32`,
    /// `d_pad = 128`, `h_pad = 16`, `f_pad = 256`, the same nine domain logs,
    /// the same helper counts, the same generalised endpoint of 9 rows — with
    /// two true sizes moved onto their pads:
    ///
    /// * `tokens = 32` instead of 24, so `Dom::T = t_pad = 2^5` **does not
    ///   pad**, and with it `Dom::Kv = tokens * kv_heads * head_dim = 2^10`
    ///   (which also sits exactly at the row width, the toy's case and not a
    ///   P-3 lift);
    /// * `hidden = 256` instead of 192, so `Dom::F = tokens * hidden = 2^13`
    ///   **does not pad** either;
    /// * the head axis is rung-K4's — 12 query heads of 8 over 4 key-value
    ///   heads, `lkv = 2`, padded head slots `{3, 7, 11, 15}` — so
    ///   `Dom::Ht`, `Dom::D`, `Dom::Q` and `Dom::S` all still pad (12 true
    ///   heads in 16 slots, width 96 in 128), `Dom::L` still pads (9 limb
    ///   sub-planes of 16, then the P-3 lift) and `Dom::Tab` still pads
    ///   through the lift.
    ///
    /// **That is 125M's OWN padded-domain set**, `{Ht, L, D, Q, S, Tab}`
    /// padded and `{T, Kv, F}` unpadded, which is the whole point: the three
    /// host slots that take the false arm here — `SC_TZC` (02), `SC_KVZC`
    /// (16) and `SC_FZC` (18) — are exactly the three the independent Python
    /// gate names at 125M.
    ///
    /// Development grade, never a deliverable (ruling P-7), its OWN profile
    /// (D17) and therefore its own hash-tag key set. No existing shape moves.
    pub(crate) fn rung_p2() -> Shape {
        Shape::build(
            "development rung, both pad branches (T32 / d96 / f256, 12 heads of 8 over 4 KV heads)",
            "hashline-zk-mr1/private-block-rung-p2-t32-dev/1",
            32,
            96,
            256,
            12,
            8,
            4,
            10,
            4,
            12,
            9,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-P2 shape is well formed")
    }

    /// **THE FULL-TOP-BYTE DEVELOPMENT SHAPE (stage 31, "rung-C6").**
    ///
    /// **Why it exists.** [`Shape::norm_top_is_full_byte`] is correction
    /// **C-6**: when the norm window fills its top byte limb exactly, the
    /// `scaled(top, 1 << (8 ln - wrho))` lookup has coefficient `1 << 0 = 1`
    /// and is therefore the same `Lk` as the `byte(top)` lookup already in
    /// the list, so `layout::lookups_at` emits it for neither `rho` nor
    /// `sigma` of either norm — FOUR lookups dropped, `Dom::D` at 34 per
    /// position instead of 38, **17** helper planes instead of 19 and an `H`
    /// plane list two planes shorter. The flag is true exactly when
    /// `norm_wrho = NORM_TN + 1 + bit_length(D_max)` is a multiple of eight,
    /// and `D_max = isqrt(1 + width * 32767^2)`, so it needs `width > 256`:
    /// the toy (16) is at 29 bits, every development shape (96) at 31, and
    /// **the only shape in this module with the flag true is 125M**, whose
    /// proofs are `#[ignore]`d 10 GiB tests. This shape closes that gap at a
    /// size the ordinary filter proves in about a second.
    ///
    /// **The geometry, and why each number is forced.** It is
    /// [`Shape::rung_p2`]'s with ONE axis moved — the head dimension, from 8
    /// to 32 — and everything that must follow from it:
    ///
    /// * `head_dim = 32` is the smallest admissible value that crosses the
    ///   window. `width = q_heads * head_dim` is forced by the reference
    ///   kernel, and `d_pad = h_pad * head_dim` is a construction refusal, so
    ///   with the head axis of rung-P2 (12 query heads over 4 key-value
    ///   heads, `h_pad = 16`) the width is `12 * head_dim`: 8 gives 96 (31
    ///   bits), 16 gives 192 (31 bits, `D_max = 454,053`), and 32 gives
    ///   **384**, `D_max = 642,099`, 20 bits, `norm_wrho = 32`. `q_heads` is
    ///   the smallest non-power-of-two multiple of four, which is what keeps
    ///   `lkv = 2` with a padded slot inside every group's block;
    /// * `hidden = 512` is the smallest power of two above the width. A power
    ///   of two is what keeps `Dom::F = tokens * hidden` unpadded, and it
    ///   must exceed the width or the feed-forward fixture has no "upper
    ///   hidden half" to be dense on (the S19-F1 census);
    /// * `tokens = 32`, `log_cols = 10`, `inv_rate = 4` and `f_e = 12` are
    ///   rung-P2's. `f_e = 12` at 32 tokens keeps `wrho_s = 17` and so
    ///   `limbs_sigma_s = 3`, which is 125M's; **the only lookup family that
    ///   differs from rung-P2 anywhere in the layout is therefore `Dom::D`,
    ///   by exactly C-6's four.**
    ///
    /// **It keeps stage 30's three unpadded domains.** `Dom::T = 2^5`,
    /// `Dom::Kv = 32 * 4 * 32 = 2^12` and `Dom::F = 32 * 512 = 2^14` are
    /// exact powers of two and do not pad, while `Ht`, `L`, `D`, `Q`, `S`
    /// and `Tab` do — 125M's own padded-domain set, so this shape carries
    /// BOTH arms of ruling P-1 as well as the C-6 arm.
    ///
    /// Its endpoint is the generalised one at the defaults: the padded
    /// `Dom::D` cube is `32 * 512 = 2^14` words, which at
    /// `endpoint_log_n = log_cols = 10` is 16 data rows and
    /// `16 + MASK_ROWS = 21` commitment rows.
    ///
    /// Development grade, never a deliverable (ruling P-7), its OWN profile
    /// (D17) and therefore its own hash-tag key set. No existing shape moves.
    pub(crate) fn rung_c6() -> Shape {
        Shape::build(
            "development rung, full top norm byte (T32 / d384 / f512, 12 heads of 32 over 4 KV heads)",
            "hashline-zk-mr1/private-block-rung-c6-t32-dev/1",
            32,
            384,
            512,
            12,
            32,
            4,
            10,
            4,
            12,
            21,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-C6 shape is well formed")
    }

    /// **THE 125M-ROW-WIDTH DEVELOPMENT SHAPE (stage 32, "rung-W14").**
    ///
    /// **Why it exists.** Three of the four branches stage 31 left on the
    /// heavy-only list are properties of the ROW GEOMETRY and the HEAD SIZE,
    /// and one shape reaches all three: `log_cols = 14` (a 2^14-word message
    /// encoded to 2^16, with it the PCS column geometry, `rows_of` for every
    /// domain, the `Dom::Tab` P-3 lift distance, the NTT log and the tagged
    /// hash lengths), `head_dim = 64` (the S-3 / C-2 margin and the RoPE
    /// partner bit at `log − 6`) and `endpoint_log_n = 14`. Every other
    /// development shape is at `log_cols` 8 or 10 and at a head dimension of
    /// 8, 16 or 32; the only shape with 14 and 64 is 125M, whose proofs are
    /// `#[ignore]`d 10 GiB tests, and it is exactly the shape the integrator
    /// is about to optimise the shared commitment and sumcheck code at.
    ///
    /// **The geometry, and why every number is forced.**
    ///
    /// * `head_dim = 64` and `q_heads = 12` over `kv_heads = 4` are 125M's own
    ///   head axis, so `width = q_heads · head_dim = 768` is 125M's width
    ///   exactly — and with it `D_max = isqrt(1 + 768 · 32767²) = 908,065`,
    ///   `norm_wrho = 32` and correction C-6, all three 125M's own values.
    ///   `h_pad = 16` and `d_pad = h_pad · head_dim = 1,024` follow;
    /// * **`tokens = 64` is the SMALLEST admissible token count at this head
    ///   axis and row width, and the refusal that forces it is F-2**:
    ///   `Dom::Kv = tokens · kv_heads · head_dim = 256 · tokens` must reach the
    ///   row width 2^14 or the P-3 lift makes the bilinear slots unserveable,
    ///   so `tokens ≥ 64`. At 64 it sits EXACTLY at the row width — the toy's
    ///   case, not a lift — and `Dom::Q` (2^16), `Dom::S` (2^16) and `Dom::F`
    ///   (2^16) are above it;
    /// * `hidden = 1,024` is the smallest power of two above the width. A
    ///   power of two keeps `Dom::F = tokens · hidden` unpadded, and it must
    ///   EXCEED the width or the dense fixture has no upper hidden half to be
    ///   live on (the S19-F1 census);
    /// * `f_e = 12` is the rungs' calibration, and at 64 tokens it gives
    ///   `wrho_s = clog2(64) + 12 = 18`, which is **125M's own softmax
    ///   window** and so 125M's `limbs_sigma_s = 3`. (125M reaches 18 the
    ///   other way, `clog2(512) + 9`.) That is what keeps this shape's plane
    ///   lists 125M's: 83 `A` planes and 50 `H` planes, and the per-position
    ///   lookup counts `2 / 34 / 9 / 13 / 12 / 15` domain for domain;
    /// * `inv_rate = 4` and `opened_cols = 256` are 125M's, so the encoded row
    ///   is 2^16 words and the Merkle tree is 16 deep, as at 125M.
    ///
    /// **What it does NOT reach, and cannot.** The endpoint commits the padded
    /// `Dom::D` cube, `t_pad · d_pad = 2^16` words, which at
    /// `endpoint_log_n = 14` is **4 data rows and 9 commitment rows** against
    /// 125M's 32 and 37: 32 data rows at this endpoint log need a 2^19-word
    /// cube, and with the width capped at 1,024 by the four-norm-limb refusal
    /// that means 512 tokens — 125M itself. The endpoint LOG and the
    /// generalised endpoint's geometry at that log are reached here; the row
    /// COUNT is not, and it is reachable separately at `log_cols = 10`
    /// (stage 31's item 3).
    ///
    /// It keeps stage 30's unpadded arm on 125M's own set — `Dom::T` (2^6),
    /// `Dom::Kv` (2^14) and `Dom::F` (2^16) do not pad, `Ht`, `L`, `D`, `Q`,
    /// `S` and `Tab` do — and stage 31's C-6 arm, both for free.
    ///
    /// Development grade, never a deliverable (ruling P-7), its OWN profile
    /// (D17) and therefore its own hash-tag key set. No existing shape moves.
    pub(crate) fn rung_w14() -> Shape {
        Shape::build(
            "development rung, the 125M row width (T64 / d768 / f1024, 12 heads of 64 over 4 KV heads)",
            "hashline-zk-mr1/private-block-rung-w14-t64-dev/1",
            64,
            768,
            1024,
            12,
            64,
            4,
            14,
            4,
            12,
            9,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-W14 shape is well formed")
    }

    /// **THE 32-DATA-ROW ENDPOINT DEVELOPMENT SHAPE (stage 33, "rung-E32"),
    /// item 4b of stage 32's heavy-only list.**
    ///
    /// **Why it exists.** The external endpoint commits the PADDED `Dom::D`
    /// cube, `t_pad · d_pad` words, cut into rows of `2^endpoint_log_n`. At
    /// 125M that is `2^19 / 2^14 = 32` data rows and `32 + MASK_ROWS = 37`
    /// commitment rows. Every shape the ordinary filter proves at has 2, 4 or
    /// 16 data rows, so the endpoint row INDEX 16 and up, a 296-byte endpoint
    /// column digest and a 38-row internal boundary were reached only by an
    /// `#[ignore]`d 125M test. **A 32-row endpoint does not need 125M's
    /// endpoint LOG** — it needs the cube to be 32 times the endpoint row —
    /// and that is what this shape buys cheaply.
    ///
    /// **The geometry, and why each number is what it is.** It is
    /// [`Shape::rung_w14`]'s head axis, width and hidden size — 125M's — with
    /// the tokens halved to 32 and the row width at 2^10:
    ///
    /// * `t_pad · d_pad = 32 · 1,024 = 2^15`, so at `endpoint_log_n = 10`
    ///   (the default, `log_cols`) the endpoint has **32 data rows and 37
    ///   commitment rows**, 125M's own;
    /// * `width = 768` and `head_dim = 64` over four key-value groups are
    ///   125M's, so `D_max` is 908,065, `norm_wrho` is 32 and correction C-6
    ///   applies, exactly as at rung-C6, rung-W14 and 125M;
    /// * `hidden = 1,024` is the smallest power of two above the width, which
    ///   keeps `Dom::F` unpadded and keeps an upper hidden half for the dense
    ///   fixture;
    /// * `log_cols = 10` is the rungs' row width. It cannot be 14: the cube
    ///   would then be one row, not 32. It cannot be much smaller either —
    ///   ruling S-1 needs `log_cols >= 8` and ruling F-2 needs `Dom::Kv =
    ///   32 · 4 · 64 = 2^13` at or above the row width;
    /// * `f_e = 12` is the rungs' calibration; at 32 tokens it gives
    ///   `wrho_s = 17`, so `limbs_sigma_s` is 3 as at 125M.
    ///
    /// **What it does NOT reach**: the endpoint LOG (10 here, 14 at 125M) and
    /// therefore the endpoint's row WIDTH and Merkle depth. That is
    /// rung-W14's half of the same item, and the two together are the
    /// endpoint's two independent axes.
    ///
    /// Development grade, never a deliverable (ruling P-7), its OWN profile
    /// (D17) and therefore its own hash-tag key set. No existing shape moves.
    pub(crate) fn rung_e32() -> Shape {
        Shape::build(
            "development rung, the 125M endpoint row count (T32 / d768 / f1024, 12 heads of 64 over 4 KV heads)",
            "hashline-zk-mr1/private-block-rung-e32-t32-dev/1",
            32,
            768,
            1024,
            12,
            64,
            4,
            10,
            4,
            12,
            37,
            None,
            None,
            None,
            None,
        )
        .expect("the rung-E32 shape is well formed")
    }

    /// THE 125M-CLASS BLOCK (memo §2). A counted layout only, at this step.
    ///
    /// **S11b: 37 endpoint rows, not the 29 of memo §6.** The memo costed the
    /// endpoint at the TRUE `512 x 768 = 393,216`-word plane, which is three
    /// blocks of `2^17` and not a power of two, and therefore needs C6's
    /// `mu`-batched multi-block claim. What this module commits is the
    /// PADDED `Dom::D` cube — `t_pad * d_pad = 512 * 1024 = 2^19` words,
    /// which IS a power of two — because that is the slice `SC_IO_IN` /
    /// `SC_IO_OUT` already claim (finding S11-F3, and the same route S11a
    /// took at the rung). At `endpoint_log_n = 14` that is `2^19 / 2^14 = 32`
    /// data rows and `32 + MASK_ROWS = 37` commitment rows, against the
    /// memo's 24 and 29, and two endpoint openings of 749,568 B against its
    /// 733,184 B. **Padding is what removes the need for C6 here**: there is
    /// no non-power-of-two plane left to batch over (finding S11b-F1).
    pub(crate) fn m125() -> Shape {
        Shape::build("125M private block (T512 / d768 / f2048, 12 heads of 64 over 4 KV heads)", "hashline-zk-mr1/private-block-m125/1", 512, 768, 2048, 12, 64, 4, 14, 4, 9, 37, None, None, None, None)
            .expect("the 125M shape is well formed")
    }

    // ---- the head permutation (correction C-1, ruling P-2) -----------------
    /// how many slots of the PADDED head axis each key-value group owns
    pub(crate) fn slots_per_kv_group(&self) -> usize {
        self.h_pad / self.kv_heads
    }
    /// `log2` of the above — the shift that recovers a slot's key-value head
    pub(crate) fn log_slots_per_kv_group(&self) -> usize {
        self.slots_per_kv_group().trailing_zeros() as usize
    }
    /// **THE HEAD PERMUTATION.** The padded head slot that logical query head
    /// `h` occupies. The key-value group owns a contiguous block of slots, so
    /// the group index is the HIGH bits of the slot and each group's padding
    /// falls at the END of ITS OWN block: padded slots `{3, 7}` at the rung
    /// and `{3, 7, 11, 15}` at 125M (§3.7a note 2), never a contiguous tail.
    ///
    /// At the toy `q_heads == h_pad` and this is the identity, which is why
    /// no toy byte moves and why no toy test could ever have seen the
    /// difference (the same lesson as finding S6-F1).
    pub(crate) fn head_slot(&self, h: usize) -> usize {
        let group = self.q_heads / self.kv_heads;
        (h / group) * self.slots_per_kv_group() + (h % group)
    }
    /// Is padded head slot `sl` occupied by a true query head?
    pub(crate) fn slot_is_true_head(&self, sl: usize) -> bool {
        sl < self.h_pad && sl % self.slots_per_kv_group() < self.q_heads / self.kv_heads
    }
    /// the key-value head a padded head slot reads — the slot's high bits
    pub(crate) fn kv_of_slot(&self, sl: usize) -> usize {
        sl >> self.log_slots_per_kv_group()
    }

    // ---- the pad rule's PROFILE gate (ruling P-1, finding S9-F1) -----------
    /// **The pad rule is carried by a PROFILE, never by "does this domain
    /// pad" (finding S9-F1).** `Dom::L` pads at the toy — nine of sixteen
    /// limb sub-planes carry the isqrt witness and seven are empty — so a
    /// domain-driven rule would put a pad-zero term in the toy's `SC_LZC` and
    /// move every byte of the frozen 2,816,472-byte receipt. The frozen toy
    /// profile therefore carries NO pad-zero machinery and its `Dom::L` pad
    /// stays exactly as unconstrained as it always was (D17); every other
    /// profile carries the rule.
    pub(crate) fn carries_pad_rule(&self) -> bool {
        !self.is_frozen_toy()
    }

    /// The ONE profile whose receipt bytes are pinned (D17): the toy. Every
    /// bound, gate and freeze that must not move for an existing caller keys
    /// on this and never on a geometry.
    pub(crate) fn is_frozen_toy(&self) -> bool {
        self.profile == TOY_PROFILE
    }

    // ---- the D19 separating hash tag (stage 17, rulings T-1, T-2, T-7) ----
    /// **Does this profile hash under the LEGACY (unkeyed) rule?** Two
    /// profiles do, and they are named here and nowhere else:
    ///
    /// * the **byte-frozen toy** — D19 records its deviation, D22 rests on
    ///   its bytes, and it is never tagged;
    /// * the **frozen-seam development rung** — its endpoint is committed
    ///   inside `private_seam.rs`, which stays byte-identical to `11c01b2`,
    ///   so a tagged rung would be a MIXTURE of the two rules within one
    ///   profile. Ruling T-2 as amended forbids that, so the whole profile
    ///   stays legacy. It is a development fixture outside D19's obligation,
    ///   barred by name from any privacy statement, and [`Shape::rung_g`]
    ///   exists to replace it.
    ///
    /// Every other profile — `rung_g`, the 125M shape, and any run over one
    /// of them — is tagged.
    pub(crate) fn hashes_under_the_legacy_rule(&self) -> bool {
        self.is_frozen_toy() || self.profile == FROZEN_SEAM_RUNG_PROFILE
    }

    /// **THE ONE PLACE a profile's hash rule is chosen (ruling T-1, wired as
    /// the memo's option D).** The tag is keyed off the PROFILE STRING, and
    /// D17 already forces a new profile per shape, so a new shape cannot
    /// exist without a new key set: the obligation is discharged by a
    /// function of the shape rather than by a reviewer's memory.
    pub(crate) fn hash_tag(&self) -> HashTag {
        // TEST ONLY: the cross-rule hook (see `set_force_legacy_hash_rule`).
        // It can only ever return the LEGACY rule, which is what two profiles
        // already return, so it cannot make anything tagged that is not — and
        // in particular it cannot move a byte of the frozen toy.
        #[cfg(test)]
        if forced_legacy_hash_rule() {
            return HashTag::legacy();
        }
        if self.hashes_under_the_legacy_rule() {
            HashTag::legacy()
        } else {
            HashTag::for_profile(self.profile)
        }
    }

    // ---- the byte-limb counts the two integer windows force ----------------
    pub(crate) fn limbs_norm(&self) -> usize {
        self.norm_wrho.div_ceil(8) as usize
    }
    /// When the window fills its top limb exactly, the
    /// `scaled(top, 1 << (32 - wrho))` lookup is redundant and is dropped —
    /// FOUR of them, `rho` and `sigma` of each norm (C-6).
    pub(crate) fn norm_top_is_full_byte(&self) -> bool {
        self.norm_wrho == 8 * self.limbs_norm() as u32
    }
    pub(crate) fn limbs_sigma_s(&self) -> usize {
        self.wrho_s.div_ceil(8) as usize
    }
    pub(crate) fn limbs_p(&self) -> usize {
        (F_P + 1).div_ceil(8) as usize
    }

    // ---- the nine domains --------------------------------------------------
    /// the log the domain's PADDED extent asks for, before the P-3 lift
    pub(crate) fn natural_log(&self, dom: Dom) -> usize {
        match dom {
            Dom::T => clog2(self.t_pad),
            Dom::Ht => clog2(self.h_pad * self.t_pad),
            // sixteen packed limb sub-planes of `T`
            Dom::L => clog2(16 * self.t_pad),
            Dom::D => clog2(self.t_pad * self.d_pad),
            Dom::Q => clog2(self.t_pad * self.h_pad * self.head_dim),
            Dom::Kv => clog2(self.t_pad * self.kv_heads * self.head_dim),
            Dom::S => clog2(self.h_pad * self.t_pad * self.t_pad),
            Dom::F => clog2(self.t_pad * self.f_pad),
            Dom::Tab => clog2(U8_LEN),
        }
    }
    /// the positions a domain actually uses, before any padding
    pub(crate) fn true_size(&self, dom: Dom) -> usize {
        match dom {
            Dom::T => self.tokens,
            Dom::Ht => self.q_heads * self.tokens,
            Dom::L => 3 * LIMBS_ISQRT * self.tokens,
            Dom::D => self.tokens * self.width,
            Dom::Q => self.tokens * self.q_heads * self.head_dim,
            Dom::Kv => self.tokens * self.kv_heads * self.head_dim,
            Dom::S => self.q_heads * self.tokens * self.tokens,
            Dom::F => self.tokens * self.hidden,
            Dom::Tab => U8_LEN,
        }
    }
    /// the domain's log AFTER the P-3 lift (`layout::domain_log_at`)
    pub(crate) fn log(&self, dom: Dom) -> usize {
        domain_log_at(self.natural_log(dom), dom.carries_h_planes(), self.log_cols)
    }
    pub(crate) fn size(&self, dom: Dom) -> usize {
        1usize << self.log(dom)
    }
    pub(crate) fn rows_of(&self, dom: Dom) -> usize {
        std::cmp::max(1, self.size(dom) >> self.log_cols)
    }
    /// the domains whose padded size exceeds their true size — the ones the
    /// pad rule of §3.7a governs (a domain lifted by P-3 counts as padded)
    pub(crate) fn pads(&self, dom: Dom) -> bool {
        self.size(dom) != self.true_size(dom)
    }

    // ---- the plane lists ---------------------------------------------------
    /// the domain of every committed `A` plane, in plane order
    pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {
        let ln = self.limbs_norm();
        let mut v = vec![Dom::T; 4];
        v.extend([Dom::Ht; 2]);
        v.extend([Dom::L; 2]);
        // Dom::D: x, its two limbs, y; norm_a's rho and sigma limbs; the
        // attention output and residual 1 with their limbs; norm_m's rho and
        // sigma limbs; z16, residual 2 and the down-projection remainder
        v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);
        v.extend([Dom::Q; 7]);
        v.extend([Dom::Kv; 6]);
        v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
        v.extend([Dom::F; 11]);
        v.extend([Dom::Tab; 3]);
        v
    }

    /// how many `U8` lookups each POSITION of each lookup domain carries
    /// (`layout::lookups`), with the two shape-driven changes of §4
    pub(crate) fn lookups_per_position(&self, dom: Dom) -> usize {
        let ln = self.limbs_norm();
        let top = usize::from(!self.norm_top_is_full_byte());
        // sym(y) + rho limbs (+ the scaled top) + sigma limbs (+ the scaled top)
        let per_norm = 2 + 2 * (ln + top);
        match dom {
            Dom::L => 2,
            // the two `x` limbs; norm_a; ao/a-limbs/ral/scaled(ral)/x1 limbs;
            // norm_m; the two `x2` limbs; the down-projection's four
            Dom::D => 2 + per_norm + 6 + per_norm + 2 + 4,
            Dom::F => 9,
            Dom::Q => 13,
            Dom::Kv => 12,
            // sym(s8); rsl + scaled; p limbs + scaled top; rho_s and sigma_s
            // limbs, each with a scaled top
            Dom::S => 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            Dom::T | Dom::Ht | Dom::Tab => 0,
        }
    }

    /// helper planes per lookup domain: helper `k` covers lookups `2k, 2k+1`
    pub(crate) fn helpers(&self, dom: Dom) -> usize {
        self.lookups_per_position(dom).div_ceil(2)
    }

    /// the domain of every `Fp2`-valued `H` plane, in plane order
    pub(crate) fn h_plane_doms(&self) -> Vec<Dom> {
        let mut v = vec![Dom::L; self.helpers(Dom::L)];
        v.extend(vec![Dom::D; self.helpers(Dom::D)]);
        v.extend(vec![Dom::Q; self.helpers(Dom::Q)]);
        v.extend(vec![Dom::Kv; self.helpers(Dom::Kv)]);
        // the `Dom::S` helpers plus the exponential pair's own helper
        v.extend(vec![Dom::S; self.helpers(Dom::S) + 1]);
        // the `Dom::F` helpers plus the activation pair's own helper
        v.extend(vec![Dom::F; self.helpers(Dom::F) + 1]);
        // the three table helpers and the zero-sum pair `u`
        v.extend([Dom::Tab; 4]);
        v
    }

    fn a_planes_on(&self, dom: Dom) -> usize {
        self.a_plane_doms().iter().filter(|d| **d == dom).count()
    }

    // ---- claim sites -------------------------------------------------------
    /// one reserved mask pair per site; `(A sites, H sites)` per slot
    pub(crate) fn claim_sites(&self) -> ([usize; N_SLOTS], [usize; N_SLOTS]) {
        let mut a = [0usize; N_SLOTS];
        let mut h = [0usize; N_SLOTS];
        a[SC_SS] = 1;
        a[SC_SSM] = 1;
        // the four `Dom::T` planes, plus nine limb sub-slices per norm
        a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT);
        a[SC_LZC] = self.a_planes_on(Dom::L);
        h[SC_LZC] = self.helpers(Dom::L);
        a[SC_RS] = 2;
        for s in [SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM] {
            a[s] = 1;
        }
        a[SC_SCORE] = 2;
        a[SC_PV] = 2;
        // + the two `Dom::T` denominators
        a[SC_DZC] = self.a_planes_on(Dom::D) + 2;
        h[SC_DZC] = self.helpers(Dom::D);
        // + the flipped RoPE partner
        a[SC_QZC] = self.a_planes_on(Dom::Q) + 1;
        h[SC_QZC] = self.helpers(Dom::Q);
        a[SC_KVZC] = self.a_planes_on(Dom::Kv) + 1;
        h[SC_KVZC] = self.helpers(Dom::Kv);
        // + A_MX and A_SUM; + H_SEXP
        a[SC_SZC] = self.a_planes_on(Dom::S) + 2;
        h[SC_SZC] = self.helpers(Dom::S) + 1;
        // + H_FACT
        a[SC_FZC] = self.a_planes_on(Dom::F);
        h[SC_FZC] = self.helpers(Dom::F) + 1;
        a[SC_TAB] = 3;
        h[SC_TAB] = 3;
        h[SC_ZS] = 1;
        a[SC_IO_IN] = 1;
        a[SC_IO_OUT] = 1;
        (a, h)
    }

    /// private terminals a slot publishes
    pub(crate) fn slot_terms(&self) -> [usize; N_SLOTS] {
        let (a, h) = self.claim_sites();
        let mut out = [0usize; N_SLOTS];
        for s in 0..N_SLOTS {
            out[s] = a[s] + h[s] + usize::from(s >= SC_IO_IN);
        }
        out
    }

    // ---- the slot schedule -------------------------------------------------
    /// `(main rounds, extension rounds, degree)` per slot. Main rounds are the
    /// slot's cube: the domain log for a zero-check or a row sum, and the
    /// matmul's INNER index log for a matmul (M-2: the four matmul families do
    /// NOT share one width).
    pub(crate) fn slots(&self) -> [(usize, usize, usize); N_SLOTS] {
        let cube = |s: usize| -> Option<Dom> {
            Some(match s {
                SC_SS | SC_SSM | SC_DZC | SC_IO_IN | SC_IO_OUT => Dom::D,
                SC_TZC => Dom::T,
                SC_LZC => Dom::L,
                SC_RS | SC_SZC => Dom::S,
                SC_QZC => Dom::Q,
                SC_KVZC => Dom::Kv,
                SC_FZC => Dom::F,
                SC_TAB | SC_ZS => Dom::Tab,
                _ => return None,
            })
        };
        // **STAGE 20, the fix of finding S19-F1.** The two BILINEAR slots also
        // sum over the key-value GROUP bits. Those bits are a coordinate of
        // BOTH private factors, and the multilinear extension of a product
        // that shares a variable is not the product of the extensions, so they
        // cannot be fixed on both sides; they are sumcheck variables with a
        // public `eq(r_g, .)` over them. `kv_heads == 1` gives `lkv == 0` and
        // the toy's schedule is untouched, byte for byte.
        let lkv = clog2(self.kv_heads);
        let inner = |s: usize| -> usize {
            match s {
                SC_QMM | SC_KMM | SC_VMM | SC_WO | SC_GMM | SC_UMM => clog2(self.d_pad),
                SC_SCORE => lkv + clog2(self.head_dim),
                SC_PV => lkv + clog2(self.t_pad),
                SC_DMM => clog2(self.f_pad),
                _ => unreachable!(),
            }
        };
        let mut out = [(0usize, 0usize, 0usize); N_SLOTS];
        for s in 0..N_SLOTS {
            let main = match cube(s) {
                Some(dom) => self.log(dom),
                None => inner(s),
            };
            // the PROFILE gate of finding S9-F1: the frozen toy profile
            // carries no pad machinery, so no toy degree can move
            let indicator = self.carries_pad_rule() && INDICATOR_SLOT_DOMAIN.iter().any(|(slot, dom)| *slot == s && self.pads(*dom));
            // the two bilinear matmuls mask two private factors, in extension
            // rounds 0 and 1; every other slot has one extension round
            let ext = if s == SC_SCORE || s == SC_PV { 2 } else { 1 };
            // STAGE 20: the group `eq` is a THIRD factor of the bilinear
            // slots' monomial, so their degree is 3 — and only when there is
            // more than one key-value head, so the toy keeps its 2 and its
            // transcript.
            let group_eq = (s == SC_SCORE || s == SC_PV) && lkv > 0;
            out[s] = (main, ext, BASE_DEGREE[s] + usize::from(indicator) + usize::from(group_eq));
        }
        out
    }

    /// **T-3.** The smallest and largest sumcheck round degree ANY shape this
    /// module can build is able to declare: the base table's range, and one
    /// more because every profile but the frozen toy carries the support
    /// indicator ([`Shape::carries_pad_rule`]), which adds one degree to the
    /// eight slots of `INDICATOR_SLOT_DOMAIN` when their domain pads.
    ///
    /// A `sc-round` absorb hashes `56 + 16 (d + 1)` bytes, which is always a
    /// multiple of eight, so this range is exactly the part of the
    /// hash-length guard the degrees contribute. The guard takes the WHOLE
    /// range rather than the degrees one shape happens to use — see
    /// `hash_domain::fixed_labels`.
    ///
    /// **STAGE 20.** The group `eq` of the S19-F1 fix adds one degree to the
    /// two bilinear slots, whose base is the table's MINIMUM 2, so it reaches
    /// 3 and the range does not move. `the_declared_degrees_are_inside_the_
    /// declared_range` asserts that at every shape this module builds, so the
    /// hash-length table cannot silently go incomplete.
    pub(crate) fn degree_range() -> (usize, usize) {
        let lo = *BASE_DEGREE.iter().min().expect("the degree table is not empty");
        let hi = *BASE_DEGREE.iter().max().expect("the degree table is not empty") + 1;
        (lo, hi)
    }

    /// the masked sumcheck message length `L = (main + ext) * degree + 2` of
    /// each slot; `L + 256 <= 512` is the M-row budget
    pub(crate) fn slot_lengths(&self) -> [usize; N_SLOTS] {
        let sl = self.slots();
        let mut out = [0usize; N_SLOTS];
        for s in 0..N_SLOTS {
            out[s] = (sl[s].0 + sl[s].1) * sl[s].2 + 2;
        }
        out
    }

    // ---- rows, opening groups, receipt -------------------------------------
    pub(crate) fn totals(&self) -> Totals {
        let a_data_rows: usize = self.a_plane_doms().iter().map(|d| self.rows_of(*d)).sum();
        let h_data_rows: usize = self.h_plane_doms().iter().map(|d| 2 * self.rows_of(*d)).sum();
        let (a, h) = self.claim_sites();
        let (a_sites, h_sites) = (a.iter().sum::<usize>(), h.iter().sum::<usize>());
        let sl = self.slots();
        Totals {
            a_planes: self.a_plane_doms().len(),
            h_planes: self.h_plane_doms().len(),
            a_data_rows,
            h_data_rows,
            a_rows: a_data_rows + 2 * a_sites + 2,
            h_rows: h_data_rows + 2 * h_sites + 2,
            m_rows: 2 * N_SLOTS + 4,
            a_sites,
            h_sites,
            a_groups: self.a_groups(),
            h_groups: self.h_groups(),
            logup_sum_claim_keys: self.logup_sum_claim_keys(),
            functionals: N_FUNCTIONALS,
            largest_slot_length: *self.slot_lengths().iter().max().unwrap(),
            main_rounds: sl.iter().map(|s| s.0).sum(),
            extension_rounds: sl.iter().map(|s| s.1).sum(),
            u8_per_domain: LOOKUP_DOMS.iter().map(|d| self.lookups_per_position(*d) * self.size(*d)).collect(),
            u8_lookups: LOOKUP_DOMS.iter().map(|d| self.lookups_per_position(*d) * self.size(*d)).sum(),
            exp_pairs: self.size(Dom::S),
            act_pairs: self.size(Dom::F),
            receipt_bytes: self.receipt_bytes(),
        }
    }

    /// The `A` opening's PCS column-weight groups. A claim's key is (the tail
    /// of its evaluation point, the column offset, the slice length), so each
    /// slot contributes one group per DISTINCT key it raises — one for its own
    /// cube, plus one for each plane it reads off that cube.
    ///
    /// `SC_TZC` is the only slot whose count moves with the shape: its
    /// eighteen limb sub-slices sit at column offsets `k * T_pad mod n`, which
    /// wrap (and so collide) only when `T_pad * (3 * LIMBS_ISQRT)` exceeds the
    /// row width. Both limb planes are row aligned, so the two norms raise the
    /// same offsets.
    ///
    /// **THE FIRST ARM IS UNREACHABLE AFTER VALIDATION (stage 33, ruling
    /// S-6).** `natural_log(Dom::T) >= log_cols` is a REFUSED family: a shape
    /// with a padded token count at or above the row width does not leave
    /// `Shape::new`. The arm is kept, rather than removed or turned into a
    /// panic, for two reasons: it is a defensive, panic-free return on a
    /// function the prover calls, and it does not decide anything — on exactly
    /// that family `t_pad` is a multiple of the row width (`t_pad` is a power
    /// of two by T-2), so every offset `k * t_pad mod n` is zero and the arm
    /// below returns the same 1. Deleting it would change no value at any
    /// shape, reachable or refused; what it must never become is a second
    /// behaviour.
    pub(crate) fn a_groups(&self) -> usize {
        let tzc = if self.natural_log(Dom::T) >= self.log_cols {
            // unreachable after validation (ruling S-6); equal to the arm
            // below on the refused family, never a panic
            1
        } else {
            let n = 1usize << self.log_cols;
            let mut offs: Vec<usize> = (0..3 * LIMBS_ISQRT).map(|k| (k * self.t_pad) % n).collect();
            offs.push(0);
            offs.sort_unstable();
            offs.dedup();
            offs.len()
        };
        // 01 SS, 01m SS, 08 limb, 07 row sums, 09Q, 09K, 09V, 12 Wo, 13G, 13U,
        // 13D, 14 F, TAB, IO-in, IO-out: one each
        // 10 score, 11 PV: two private factors each
        // 03 D, 04 Q, 05 KV, 06 softmax: the cube plus one off-cube plane
        // ZS: none of its own
        tzc + 15 + 2 * 2 + 4 * 2
    }

    /// `H`: one group per slot that raises `H` claims — `SC_LZC`, the five
    /// domain zero-checks, `SC_TAB`, `SC_ZS` — plus the single value-0 LogUp
    /// sum claim.
    pub(crate) fn h_groups(&self) -> usize {
        8 + 1
    }

    /// How many distinct column-weight keys the single value-0 LogUp sum claim
    /// raises. More than one is a REFUSAL, not a cost (B-3); the P-3 lift in
    /// `domain_log_at` is what makes it 1 at every shape.
    pub(crate) fn logup_sum_claim_keys(&self) -> usize {
        let mut keys: Vec<(usize, usize)> = self
            .h_plane_doms()
            .iter()
            .map(|d| if self.log(*d) >= self.log_cols { (0, 1usize << self.log_cols) } else { (0, self.size(*d)) })
            .collect();
        keys.sort_unstable();
        keys.dedup();
        keys.len()
    }

    /// `wire::encoded_len`'s parts, with the row width, the pad count `Q` and
    /// the Merkle path length taken from this shape's PCS parameters.
    pub(crate) fn receipt_bytes(&self) -> ReceiptBytes {
        let n = 1usize << self.log_cols;
        let vec_len = n + self.opened_cols;
        let path = clog2(n * self.inv_rate);
        let t = (self.a_data_and_site_rows(), self.h_data_and_site_rows());
        let opening = |groups: usize, rows: usize, vc: usize, pth: usize| (groups + 1) * vc * 16 + COL_CHECKS * (8 + rows * 8 + 32 + pth * 32);
        let e_n = 1usize << self.endpoint_log_n;
        let e_vec = e_n + self.opened_cols;
        let e_path = clog2(e_n * self.endpoint_inv_rate);
        let sl = self.slots();
        let terms = self.slot_terms();
        let slot_words: usize = (0..N_SLOTS).map(|s| 1 + (sl[s].0 + sl[s].1) * (sl[s].2 + 1) + terms[s]).sum();
        let parts = ReceiptBytes {
            header_and_three_roots: WIRE_HEADER + 3 * 32,
            slots: slot_words * 16,
            mask_opening: 2 * MASK_VEC * 16 + COL_CHECKS * (8 + (2 * N_SLOTS + 4) * 8 + 32 + MASK_PATH * 32),
            a_opening: opening(self.a_groups(), t.0, vec_len, path),
            h_opening: opening(self.h_groups(), t.1, vec_len, path),
            endpoint_openings: 2 * opening(1, self.endpoint_rows, e_vec, e_path),
            total: 0,
        };
        ReceiptBytes { total: parts.header_and_three_roots + parts.slots + parts.mask_opening + parts.a_opening + parts.h_opening + parts.endpoint_openings, ..parts }
    }

    fn a_data_and_site_rows(&self) -> usize {
        let data: usize = self.a_plane_doms().iter().map(|d| self.rows_of(*d)).sum();
        data + 2 * self.claim_sites().0.iter().sum::<usize>() + 2
    }
    fn h_data_and_site_rows(&self) -> usize {
        let data: usize = self.h_plane_doms().iter().map(|d| 2 * self.rows_of(*d)).sum();
        data + 2 * self.claim_sites().1.iter().sum::<usize>() + 2
    }

    /// the domains that pad, in the fixed domain order
    pub(crate) fn padded_domains(&self) -> Vec<Dom> {
        ALL_DOMS.iter().copied().filter(|d| self.pads(*d)).collect()
    }
}

// ---- the cross-rule test hook (stage 17, ruling T-6 as amended) -----------
//
// **TEST ONLY, and it can only ever return the LEGACY rule.** Ruling T-6
// requires the cross-rule rejection to be shown in BOTH directions at a
// tagged profile: prove tagged and verify under the legacy rule, and prove
// under the legacy rule and verify tagged. Nothing in production may choose a
// profile's rule, so this is the only way to run one side of that pair.
//
// It is `#[cfg(test)]` throughout — the cell, the setter and the read in
// `hash_tag` all vanish from a release build, and no public API of this crate
// names them. It is deliberately one-directional: a forced value can only
// make a profile LEGACY, which two profiles already are, so it cannot tag the
// frozen toy and cannot move one of its bytes even if a test forgot to clear
// it. A test that sets it MUST clear it before it returns.
#[cfg(test)]
thread_local! {
    static FORCE_LEGACY_HASH_RULE: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

/// set or clear the hook above; a test MUST clear it before it returns
#[cfg(test)]
pub(crate) fn set_force_legacy_hash_rule(v: bool) {
    FORCE_LEGACY_HASH_RULE.with(|c| c.set(v));
}

#[cfg(test)]
fn forced_legacy_hash_rule() -> bool {
    FORCE_LEGACY_HASH_RULE.with(|c| c.get())
}

/// every counted total of one shape's layout
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Totals {
    pub a_planes: usize,
    pub h_planes: usize,
    pub a_data_rows: usize,
    pub h_data_rows: usize,
    pub a_rows: usize,
    pub h_rows: usize,
    pub m_rows: usize,
    pub a_sites: usize,
    pub h_sites: usize,
    pub a_groups: usize,
    pub h_groups: usize,
    pub logup_sum_claim_keys: usize,
    pub functionals: usize,
    pub largest_slot_length: usize,
    pub main_rounds: usize,
    pub extension_rounds: usize,
    pub u8_per_domain: Vec<usize>,
    pub u8_lookups: usize,
    pub exp_pairs: usize,
    pub act_pairs: usize,
    pub receipt_bytes: ReceiptBytes,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ReceiptBytes {
    pub header_and_three_roots: usize,
    pub slots: usize,
    pub mask_opening: usize,
    pub a_opening: usize,
    pub h_opening: usize,
    pub endpoint_openings: usize,
    pub total: usize,
}
