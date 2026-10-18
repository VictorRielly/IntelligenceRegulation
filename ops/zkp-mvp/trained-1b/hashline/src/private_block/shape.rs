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
/// LANE C SCRATCH (not registered in the main tree): the TinyLlama-1.1B block
/// geometry under a DEVELOPMENT calibration (`tn = 11`, window overridden to
/// 32). NATIVE LANE: superseded by [`TINYLLAMA_T32_TRAINED_PROFILE`] and kept
/// only as an UNREGISTERED structural twin (same plane list) for tests, so
/// its string is deliberately outside the `hashline-zk-mr1/` registry.
#[cfg(test)]
pub(crate) const TINYLLAMA_T32_DEV_PROFILE: &str = "unregistered-dev-twin/private-block-tinyllama-1.1b-t32-w32-dev/1";
/// **NATIVE LANE (2026-10-17): the TinyLlama-1.1B block geometry under a
/// TRAINED (per-profile) norm calibration** — `norm_tn`, two norm multipliers
/// `norm_cn_a` / `norm_cn_m`, `norm_ceps` and `sh_ao` are fields of the shape,
/// validated by [`NormCalibration::derive_at_width`] and bound into the
/// schedule's calibration line (and so into every transcript). The profile
/// STRING names the family; the constants are carried by the schedule digest
/// and by the trained-model statement. Proposed ruling D24 (norm_tn route).
pub(crate) const TINYLLAMA_T32_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-tinyllama-1.1b-t32-trained/1";
/// **NATIVE LANE: a SMALL development shape under the same trained-calibration
/// rule**, so the end-to-end norm-alias and coefficient tamper cases (D16 item
/// 6) run in the ordinary test filter in seconds. Development grade, never a
/// deliverable, its own profile (D17).
pub(crate) const TRAINED_CALIB_RUNG_PROFILE: &str = "hashline-zk-mr1/private-block-rung-tc-t32-dev/1";
/// **ROUND 3 (R3-2): the context ladder.** The same TinyLlama-1.1B block
/// geometry under the same trained-calibration rule at T = 64 and T = 128,
/// each its OWN profile string (D17: one profile per shape). Row width
/// `2^(log2 T + 7)` keeps 21 endpoint rows, as at T32, and gives the smallest
/// counted receipt of the admissible widths (T64: 15,445,848 B at 2^13;
/// T128: 23,049,192 B at 2^14, `the_trained_tinyllama_counted_layout_ladder`).
pub(crate) const TINYLLAMA_T64_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-tinyllama-1.1b-t64-trained/1";
/// The T128 string carries a `-block` suffix: at the T32/T64 length plus
/// one (60 bytes) its transcript constructor would be 71 bytes, the length of
/// the `pb-term` absorb with 16 bytes of data in the same keyed function
/// (`s25_tests`' census refuses that); at 66 bytes the constructor is 77,
/// where this profile hashes no other kind.
pub(crate) const TINYLLAMA_T128_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-tinyllama-1.1b-t128-trained-block/1";
/// the trained TinyLlama profiles: the pinned checkpoint's, at each
/// registered context length
pub(crate) const TINYLLAMA_TRAINED_PROFILES: [&str; 3] = [TINYLLAMA_T32_TRAINED_PROFILE, TINYLLAMA_T64_TRAINED_PROFILE, TINYLLAMA_T128_TRAINED_PROFILE];
/// **ROUND 4 (R4-1): the Llama-3-8B block geometry under a trained
/// calibration at T = 32** (NousResearch/Meta-Llama-3-8B at revision
/// 315b2009: width 4096, FFN 14336 padded to 16384, 32 query heads of 128
/// over 8 key-value heads, RoPE base 500000). The same trained door and the
/// same declared classes as TinyLlama; at width 4096 the validator derives
/// `tn <= 9`. Its own profile (D17).
pub(crate) const LLAMA3_8B_T32_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-llama-3-8b-t32-trained/1";
/// **NATIVE LANE, speed plan task 3 (2026-10-17 evening): the Llama-3-8B
/// geometry at T = 64 and T = 128**, each its OWN profile string (D17), the
/// same trained door, declared classes and pinned checkpoint as T32. Row
/// width: the smallest counted receipt of the admissible widths (T64 2^13,
/// 21,697,512 B; T128 2^14, 29,300,856 B; `ladder8b_tests`), 37 endpoint
/// rows. Both profiles ACCEPTED by the independent review, round 5
/// (`results/zk60_d24_review_20261017/R5_VERDICT.md`, verdict 2).
pub(crate) const LLAMA3_8B_T64_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-llama-3-8b-t64-trained/1";
pub(crate) const LLAMA3_8B_T128_TRAINED_PROFILE: &str = "hashline-zk-mr1/private-block-llama-3-8b-t128-trained/1";
/// the trained Llama-3-8B profiles: the pinned checkpoint's, at each
/// registered context length
pub(crate) const LLAMA3_8B_TRAINED_PROFILES: [&str; 3] = [LLAMA3_8B_T32_TRAINED_PROFILE, LLAMA3_8B_T64_TRAINED_PROFILE, LLAMA3_8B_T128_TRAINED_PROFILE];
/// the profiles [`Shape::with_trained_calibration`] may give a non-frozen
/// calibration to; every other profile's calibration is frozen
pub(crate) const TRAINED_CALIBRATION_PROFILES: [&str; 7] = [TINYLLAMA_T32_TRAINED_PROFILE, TRAINED_CALIB_RUNG_PROFILE, TINYLLAMA_T64_TRAINED_PROFILE, TINYLLAMA_T128_TRAINED_PROFILE, LLAMA3_8B_T32_TRAINED_PROFILE, LLAMA3_8B_T64_TRAINED_PROFILE, LLAMA3_8B_T128_TRAINED_PROFILE];
const INT16_MAX: i128 = 32_767;
/// the absolute endpoint of signed int16 (`-32768`), used by the TRAINED
/// calibration rule only; every frozen profile keeps the historical 32767
/// formula so its geometry and transcript do not move (contract review,
/// `results/zk60_trained_contract_review_20260930/HANDOFF.md`)
const INT16_ABS: i128 = 32_768;
/// the norm's fixed-point shift; the denominator is `2^(tn+1) * D`
const NORM_TN: u32 = 11;
const NORM_CEPS: i128 = 1;

/// **The declared parameter class of a trained norm calibration** (the
/// validator's bounds; the no-wrap derivation in
/// `results/zk60_1b_native_20261017/NOWRAP_DERIVATION.md` is written for
/// exactly these ranges and no wider).
pub(crate) const TRAINED_TN_RANGE: std::ops::RangeInclusive<u32> = 1..=16;
pub(crate) const TRAINED_CN_MAX: i64 = 1 << 20;
pub(crate) const TRAINED_CEPS_MAX: i64 = 1 << 40;
pub(crate) const TRAINED_WIDTH_MAX: usize = 4096;
pub(crate) const TRAINED_SH_AO_MAX: u32 = 8;
/// **ROUND 2: the STRUCTURE-PRESERVING windows of the requantization shifts.**
/// A shift's biased remainder `r + 2^(sh-1)` lives in byte limbs whose COUNT
/// is fixed by the plane list (`layout.rs` `Ids` / `lookups_at`): ONE limb at
/// the Q/K/V, score, AO, gate and down sites (`byte(r)` plus
/// `scaled(r, 2^(8 - sh))`), TWO limbs at the O and product sites
/// (`byte(l0)`, `byte(l1)`, `scaled(l1, 2^(16 - sh))`). A shift inside its
/// window moves only the `scaled` coefficient and the host relation's
/// `2^sh` / `2^(sh-1)` constants — no plane, no lookup count, no slot degree.
/// The RoPE shift (`SH_ROPE`, coupled to `F_RO`), `F_P`, `F_E`'s logic, the up
/// shift (0: no remainder plane) and the residual shifts (0) stay fixed.
pub(crate) const ONE_LIMB_SHIFT: std::ops::RangeInclusive<u32> = 1..=8;
pub(crate) const TWO_LIMB_SHIFT: std::ops::RangeInclusive<u32> = 9..=16;
/// **ROUND 2, review finding F-1 (D24 review, 2026-10-17): the declared class
/// of the softmax table's fractional bits at a trained profile.** `f_e` was
/// an unvalidated export constant: the softmax quotient clause
/// `mask e 2^F_P - p Sum - rho_s` (SC_SZC `c2`) reaches `p` at `f_e = 49`
/// (T = 32), and the reviewer forged a quotient at `f_e = 50` that the CLI
/// verified. The class is `9..=16` (9 is the approved calibration value; the
/// calibration lane is testing finer exp precision up to 16) TOGETHER with
/// the three-limb `sigma_s` window rule `wrho_s = clog2(T) + f_e <= 24`. Over
/// that class `|c2| < 2^(f_e + 9) + 2^10 T 2^f_e + 2^wrho_s <= 2^35`, far
/// below `p` (`results/zk60_1b_native_20261017/nowrap_check.py`, section
/// "softmax"). `F_P` stays fixed at 9 (coupled to the `p` limbs).
pub(crate) const TRAINED_F_E_RANGE: std::ops::RangeInclusive<u32> = 9..=16;
/// the softmax remainder window at a trained profile: at most THREE byte
/// limbs (`wrho_s = clog2(T) + f_e <= 24`)
pub(crate) const TRAINED_WRHO_S_MAX: u32 = 24;
/// **The declared class of an exp table's score exponent `e_s`** (a
/// per-block table key). Every finite `e_s` gives a table inside
/// `[0, 2^f_e]` with `E[0] = 2^f_e` (asserted by `exp_member`), so the
/// softmax premise does not depend on it; the class keeps the generator away
/// from overflow (`2^e_s` infinite makes `E[0]` NaN) and names what an export
/// may choose. The calibration exports use 1 and 2.
pub(crate) const TRAINED_EXP_E_S_RANGE: std::ops::RangeInclusive<i32> = -8..=8;
/// **The RoPE base of both registered trained geometries** (TinyLlama-1.1B's
/// `rope_theta`; the development rung uses the same). A model fact, not a
/// calibration choice: an export naming another base is refused. (The RoPE
/// table VALUES are `round(2^F_RO cos/sin)` in `[-128, 128]` for any base, so
/// no field premise depends on it.)
pub(crate) const TRAINED_ROPE_THETA: f64 = 10_000.0;
/// ROUND 4 (R4-1): Llama-3-8B's `rope_theta`
pub(crate) const LLAMA3_8B_ROPE_THETA: f64 = 500_000.0;
/// ROUND 4 (R4-1): the 8B T32 row width, `2^13` (21 endpoint rows, as every
/// TinyLlama rung); the counted alternatives are in
/// `r4_tests::the_llama3_8b_counted_layouts`
pub(crate) const LLAMA3_8B_LOG_COLS: usize = 13;
/// the 8B row width at each registered context length (task 3: the
/// smallest counted receipt; T32 is [`LLAMA3_8B_LOG_COLS`])
pub(crate) fn llama3_8b_log_cols(tokens: usize) -> Option<usize> {
    match tokens {
        32 => Some(LLAMA3_8B_LOG_COLS),
        64 => Some(13),
        128 => Some(14),
        _ => None,
    }
}

/// **The RoPE base pinned PER PROFILE** (round 4): 10000 for the TinyLlama
/// profiles and the development rung, 500000 for Llama-3-8B; `None` for a
/// profile with no trained calibration. An export or statement naming any
/// other base is refused.
pub(crate) fn trained_rope_theta(profile: &str) -> Option<f64> {
    if LLAMA3_8B_TRAINED_PROFILES.contains(&profile) {
        Some(LLAMA3_8B_ROPE_THETA)
    } else if TRAINED_CALIBRATION_PROFILES.contains(&profile) {
        Some(TRAINED_ROPE_THETA)
    } else {
        None
    }
}

/// **A trained calibration, as declared**: the norm constants (`tn`, the two
/// multipliers, `Ceps`) and the requantization shifts the relations read
/// (`sh_qkv` for Q, K and V; `sh_s` score; `sh_o` the PV output; `sh_ao` the
/// attention output; `sh_g` gate; `sh_h` the product; `sh_z` down). The
/// frozen calibration every registered shape proves with is
/// [`NormCalibration::FROZEN`]. (The name predates round 2, when only the
/// norm and `sh_ao` were per profile.)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct NormCalibration {
    pub tn: u32,
    pub cn_a: i64,
    pub cn_m: i64,
    pub ceps: i64,
    pub sh_ao: u32,
    pub sh_qkv: u32,
    pub sh_s: u32,
    pub sh_o: u32,
    pub sh_g: u32,
    pub sh_h: u32,
    pub sh_z: u32,
}

impl NormCalibration {
    /// the single approved calibration of every registered profile
    pub(crate) const FROZEN: NormCalibration = NormCalibration { tn: NORM_TN, cn_a: 1024, cn_m: 1024, ceps: 1, sh_ao: 7, sh_qkv: 7, sh_s: 6, sh_o: 9, sh_g: 7, sh_h: 14, sh_z: 6 };

    /// the six windowed shifts with their names and windows, in a fixed order
    pub(crate) fn shifts(&self) -> [(&'static str, u32, std::ops::RangeInclusive<u32>); 6] {
        [("sh_qkv", self.sh_qkv, ONE_LIMB_SHIFT), ("sh_s", self.sh_s, ONE_LIMB_SHIFT), ("sh_o", self.sh_o, TWO_LIMB_SHIFT), ("sh_g", self.sh_g, ONE_LIMB_SHIFT), ("sh_h", self.sh_h, TWO_LIMB_SHIFT), ("sh_z", self.sh_z, ONE_LIMB_SHIFT)]
    }

    /// **THE VALIDATOR.** Computes, and refuses rather than hard-codes:
    ///
    /// * `D_max = isqrt(ceps + width * 32768^2)` — signed int16 INCLUDES
    ///   `-32768` (contract review correction 1);
    /// * `D_max` must hold in `LIMBS_ISQRT = 3` byte limbs, and so must
    ///   `a1, a2 <= 2 D_max` (D16 items 1-3);
    /// * the remainder window `wrho = tn + 1 + bit_length(D_max)` must be
    ///   EXACTLY four byte limbs, `25 <= wrho <= 32` (D16 item 4: never above
    ///   32, where `1 << (32 - wrho)` underflows and a fifth limb would move
    ///   the plane list);
    /// * every coefficient inside its declared class (`tn` in 1..=16,
    ///   `1 <= cn <= 2^20`, `1 <= ceps <= 2^40`, `sh_ao <= 8`, width at most
    ///   4096), which is what the no-wrap derivation assumes.
    ///
    /// At width 2048 this admits `tn <= 10`; at width 4096 (later 8B)
    /// `tn <= 9`; [`NormCalibration::max_tn_at_width`] computes the bound.
    /// Returns `(D_max, wrho)`.
    pub(crate) fn derive_at_width(&self, width: usize) -> Result<(i128, u32), String> {
        if width == 0 || width > TRAINED_WIDTH_MAX {
            return Err(format!("trained norm calibration: width {width} is outside the declared class 1..={TRAINED_WIDTH_MAX}"));
        }
        if !TRAINED_TN_RANGE.contains(&self.tn) {
            return Err(format!("trained norm calibration: tn {} is outside the declared class {:?}", self.tn, TRAINED_TN_RANGE));
        }
        for (name, cn) in [("cn_a", self.cn_a), ("cn_m", self.cn_m)] {
            if !(1..=TRAINED_CN_MAX).contains(&cn) {
                return Err(format!("trained norm calibration: {name} {cn} is outside the declared class 1..=2^20"));
            }
        }
        if !(1..=TRAINED_CEPS_MAX).contains(&self.ceps) {
            return Err(format!("trained norm calibration: ceps {} is outside the declared class 1..=2^40", self.ceps));
        }
        if self.sh_ao > TRAINED_SH_AO_MAX {
            return Err(format!("trained norm calibration: sh_ao {} is outside its one-limb remainder class 0..=8", self.sh_ao));
        }
        for (name, v, window) in self.shifts() {
            if !window.contains(&v) {
                return Err(format!("trained calibration: {name} {v} is outside its structure-preserving window {window:?} (the remainder's byte-limb count is fixed by the plane list)"));
            }
        }
        let d_max = isqrt_i128(i128::from(self.ceps) + width as i128 * INT16_ABS * INT16_ABS);
        if 2 * d_max >= 1i128 << (8 * LIMBS_ISQRT) {
            return Err(format!("trained norm calibration: D_max {d_max} (or a1 = 2 D_max) leaves the {LIMBS_ISQRT} isqrt byte limbs (D16 items 1-3)"));
        }
        let wrho = self.tn + 1 + bit_length(d_max);
        if wrho > 32 {
            return Err(format!(
                "trained norm calibration: the remainder window tn + 1 + bits(D_max) = {} + 1 + {} = {wrho} bits exceeds four byte limbs (D16 item 4); at width {width} tn must be at most {}",
                self.tn,
                bit_length(d_max),
                Self::max_tn_at_width(width, self.ceps)
            ));
        }
        if wrho <= 24 {
            return Err(format!("trained norm calibration: the remainder window {wrho} bits is three limbs; the plane list is pinned at four norm limbs"));
        }
        Ok((d_max, wrho))
    }

    /// the largest `tn` whose derived window is at most 32 bits at this width
    /// (10 at width 2048, 9 at width 4096, for any `ceps` in the class)
    pub(crate) fn max_tn_at_width(width: usize, ceps: i64) -> u32 {
        let d_max = isqrt_i128(i128::from(ceps) + width as i128 * INT16_ABS * INT16_ABS);
        31u32.saturating_sub(bit_length(d_max))
    }

    /// the canonical text of this calibration, as the schedule's calibration
    /// line prints it at a trained profile
    pub(crate) fn describe(&self) -> String {
        format!(
            "tn={} cn_a={} cn_m={} ceps={} ao={} qkv={} score={} o={} gate={} product={} down={}",
            self.tn, self.cn_a, self.cn_m, self.ceps, self.sh_ao, self.sh_qkv, self.sh_s, self.sh_o, self.sh_g, self.sh_h, self.sh_z
        )
    }
}
/// the softmax quotient's scale: `p` reaches `2^F_P`, so it needs `F_P + 1` bits
const F_P: u32 = 9;

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

/// **RULING CS-9: THE BLOCK PROFILE REGISTRY** (ported from the 125M lane's
/// stage 44): the nine frozen constructors, each its profile's entry (they
/// build past CS-9's own check because each IS the entry).
const REGISTERED_BLOCK_SHAPES: [fn() -> Shape; 9] = [Shape::toy, Shape::rung, Shape::rung_g, Shape::rung_k4, Shape::rung_p2, Shape::rung_c6, Shape::rung_w14, Shape::rung_e32, Shape::m125];

/// The one shape a block profile string names (a trained-calibration
/// profile: its geometry at `f_e`), or `None` for a string this build does
/// not register. No profile string is written here.
fn registered_block_shape(profile: &str, f_e: u32) -> Option<Result<Shape, String>> {
    if let Some(r) = trained_geometry(profile, f_e) {
        return Some(r);
    }
    REGISTERED_BLOCK_SHAPES.iter().map(|ctor| ctor()).find(|s| s.profile == profile).map(Ok)
}

/// **ROUND 5 (ruling CS-9 in this lane): the registered GEOMETRY of each
/// trained-calibration profile at `f_e`**, built past CS-9's check because it
/// IS the registry's entry; the calibration (and the trained windows) are
/// the trained door's. The one source of these parameters: the trained
/// constructors build through it.
fn trained_geometry(profile: &str, f_e: u32) -> Option<Result<Shape, String>> {
    let mask = super::endpoint_g::MASK_ROWS;
    let tl = |name: &'static str, p: &'static str, tokens: usize, lc: usize| Shape::build(name, p, tokens, 2048, 5632, 32, 64, 4, lc, 4, f_e, ((tokens * 2048) >> lc) + mask, None, None, None, None);
    let l8 = |name: &'static str, p: &'static str, tokens: usize| {
        let lc = llama3_8b_log_cols(tokens).expect("a registered 8B context length");
        Shape::build(name, p, tokens, 4096, 14336, 32, 128, 8, lc, 4, f_e, ((tokens * 4096) >> lc) + mask, None, None, None, None)
    };
    Some(match profile {
        TINYLLAMA_T32_TRAINED_PROFILE => tl("TinyLlama-1.1B block geometry, trained calibration (T32 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T32_TRAINED_PROFILE, 32, 12),
        TINYLLAMA_T64_TRAINED_PROFILE => tl("TinyLlama-1.1B block geometry, trained calibration (T64 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T64_TRAINED_PROFILE, 64, 13),
        TINYLLAMA_T128_TRAINED_PROFILE => tl("TinyLlama-1.1B block geometry, trained calibration (T128 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T128_TRAINED_PROFILE, 128, 14),
        LLAMA3_8B_T32_TRAINED_PROFILE => Shape::build(
            "Llama-3-8B block geometry, trained calibration (T32 / d4096 / f14336, 32 heads of 128 over 8 KV heads)",
            LLAMA3_8B_T32_TRAINED_PROFILE,
            32,
            4096,
            14336,
            32,
            128,
            8,
            LLAMA3_8B_LOG_COLS,
            4,
            f_e,
            ((32 * 4096) >> LLAMA3_8B_LOG_COLS) + mask,
            None,
            None,
            None,
            None,
        ),
        // task 3 (2026-10-17 evening): T64 and T128, PENDING REVIEW
        LLAMA3_8B_T64_TRAINED_PROFILE => l8("Llama-3-8B block geometry, trained calibration (T64 / d4096 / f14336, 32 heads of 128 over 8 KV heads)", LLAMA3_8B_T64_TRAINED_PROFILE, 64),
        LLAMA3_8B_T128_TRAINED_PROFILE => l8("Llama-3-8B block geometry, trained calibration (T128 / d4096 / f14336, 32 heads of 128 over 8 KV heads)", LLAMA3_8B_T128_TRAINED_PROFILE, 128),
        TRAINED_CALIB_RUNG_PROFILE => Shape::build("development rung, trained norm calibration (T32 / d384 / f512, 12 heads of 32 over 4 KV heads)", TRAINED_CALIB_RUNG_PROFILE, 32, 384, 512, 12, 32, 4, 10, 4, 12, 21, None, None, None, None),
        _ => return None,
    })
}

/// ONE block geometry, plus the PCS parameters its receipt is priced at.
///
/// Built only through [`Shape::new`], which refuses by name every geometry the
/// construction cannot express.
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
    /// **NATIVE LANE (from the lane-C prototype): the norm / attention-output
    /// calibration as per-profile fields.** Every registered shape keeps the
    /// frozen `layout.rs` values ([`NormCalibration::FROZEN`]), so no
    /// relation, describe line or byte moves; only
    /// [`Shape::with_trained_calibration`] may change them, and only on a
    /// profile of [`TRAINED_CALIBRATION_PROFILES`]. `norm_tn` moves the
    /// derived remainder window (and is validated so that it stays four
    /// limbs); `norm_cn_a` / `norm_cn_m` (norm_a and norm_m have SEPARATE
    /// multipliers) and `norm_ceps` are pure coefficients; `sh_ao` stays
    /// inside its one-limb remainder class (0..=8), so no plane list or lookup
    /// count moves either.
    pub norm_tn: u32,
    pub norm_cn_a: i64,
    pub norm_cn_m: i64,
    pub norm_ceps: i64,
    pub sh_ao: u32,
    /// ROUND 2: the windowed requantization shifts (frozen 7 / 6 / 9 / 7 /
    /// 14 / 6 everywhere but a trained-calibration profile)
    pub sh_qkv: u32,
    pub sh_s: u32,
    pub sh_o: u32,
    pub sh_g: u32,
    pub sh_h: u32,
    pub sh_z: u32,
    /// true exactly on a shape that went through
    /// [`Shape::with_trained_calibration`]: its `D_max` uses the signed-int16
    /// endpoint 32768 and the declared `ceps`, and its schedule's calibration
    /// line prints the trained form
    pub trained_calibration: bool,
    // ---- derived
    pub t_pad: usize,
    pub d_pad: usize,
    pub h_pad: usize,
    pub f_pad: usize,
    pub d_max: i128,
}

impl Shape {
    #[allow(clippy::too_many_arguments)]
    /// **THE one place a block profile string meets a geometry** (ruling
    /// CS-9, ported from the 125M lane's stage 44): every refusal of the
    /// construction ([`Shape::build`]), then the profile registry: a
    /// REGISTERED block profile string is admitted only with the one shape it
    /// is registered for (compared whole, as ruling CS-7 compares a run's
    /// block shape), and a string this build does not register is refused —
    /// outside `#[cfg(test)]` (a test build admits the probe and fixture
    /// shapes the test files build under their own unregistered strings).
    /// NATIVE LANE: a trained-calibration profile's registered entry is its
    /// GEOMETRY at the handed `f_e` (the calibration is the trained door's).
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
        const CS9: &str = "private block shape: ruling CS-9 — ";
        match registered_block_shape(self.profile, self.f_e) {
            Some(Ok(reg)) if reg == *self => Ok(()),
            Some(Ok(reg)) => {
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
                Err(format!("{CS9}the block profile {:?} is registered for exactly one shape, {:?}; the shape handed, {:?}, differs from it in {}", self.profile, reg.name, self.name, differ.join(", ")))
            }
            Some(Err(e)) => Err(format!("{CS9}the block profile {:?}'s registered geometry does not build at this f_e: {e}", self.profile)),
            None if admit_unregistered => Ok(()),
            None => Err(format!("{CS9}{:?} is not a block profile this build registers, so it names no shape ({:?} was handed)", self.profile, self.name)),
        }
    }

    /// **TEST ONLY (ruling CS-9).** The check as a release build makes it.
    #[cfg(test)]
    pub(crate) fn check_block_profile_as_a_release_build(&self) -> Result<(), String> {
        self.block_profile_names_this_shape(false)
    }

    /// Every refusal of the construction but ruling CS-9's. PRIVATE: called
    /// by [`Shape::new`] and by the registry's own entries (the nine frozen
    /// constructors and [`trained_geometry`]).
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
        let d_max = isqrt_i128(NORM_CEPS + width as i128 * INT16_MAX * INT16_MAX);
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
            norm_tn: NormCalibration::FROZEN.tn,
            norm_cn_a: NormCalibration::FROZEN.cn_a,
            norm_cn_m: NormCalibration::FROZEN.cn_m,
            norm_ceps: NormCalibration::FROZEN.ceps,
            sh_ao: NormCalibration::FROZEN.sh_ao,
            sh_qkv: NormCalibration::FROZEN.sh_qkv,
            sh_s: NormCalibration::FROZEN.sh_s,
            sh_o: NormCalibration::FROZEN.sh_o,
            sh_g: NormCalibration::FROZEN.sh_g,
            sh_h: NormCalibration::FROZEN.sh_h,
            sh_z: NormCalibration::FROZEN.sh_z,
            trained_calibration: false,
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

    // ---- LANE C SCRATCH PROTOTYPE (2026-09-30): the TinyLlama-1.1B geometry ----
    //
    // NOT REGISTERED IN THE MAIN TREE. A new geometry is a NEW profile (D17)
    // and therefore its own hash-tag key set (D19a); no existing shape moves.
    // TinyLlama-1.1B-Chat-v1.0 at revision fe8a4ea1: width 2048, FFN 5632,
    // 32 query heads of 64 over 4 key-value heads, 22 blocks, RoPE theta
    // 10000, RMSNorm eps 1e-5. T = 32 is the smallest context the layout
    // admits at a row width of 2^12 (ruling F-2 needs Dom::Kv = 32*4*64 =
    // 2^13 at or above the row width, so log_cols <= 13; S-6 needs 2^5 < 2^12).

    /// The TRUE geometry at the frozen calibration: the Sol probe's
    /// `tinyllama_t32_lc*` layout, with its `unregistered-layout-probe/1`
    /// string. It CONSTRUCTS, but its norm window is 33 bits
    /// (`NORM_TN + 1 + bits(D_max = 1,482,861)`), which is FIVE remainder
    /// limbs, and `witness::build_shaped` refuses any shape whose norm limb
    /// count is not the pinned four (`norm_limbs_are_the_pinned_count`). So
    /// this shape has a layout and cannot have a witness.
    /// (review finding F-6: test builds only)
    #[cfg(test)]
    pub(crate) fn tinyllama_t32_probe(log_cols: usize) -> Result<Shape, String> {
        let rows = (32 * 2048 >> log_cols) + super::endpoint_g::MASK_ROWS;
        Shape::new(
            "TinyLlama-1.1B block geometry, unregistered probe (T32 / d2048 / f5632, 32 heads of 64 over 4 KV heads)",
            "unregistered-layout-probe/1",
            32,
            2048,
            5632,
            32,
            64,
            4,
            log_cols,
            4,
            9,
            rows,
            None,
            None,
            None,
            None,
        )
    }

    /// **The scratch development profile of the TinyLlama geometry.** The
    /// true geometry with ONE development-calibration override: the norm
    /// remainder window is 32 bits (four limbs, C-6 applies exactly as at
    /// 125M), instead of the derived 33. Sound — `rho, sigma` are still
    /// byte-limb range proved and `rho + sigma + 1 = den` still pins the
    /// quotient — but an honest row whose denominator `D * 2^12` reaches
    /// `2^32` (an RMS above 23,170 integer units) is REFUSED by the witness
    /// builder instead of proved. The clean fix is a per-profile `NORM_TN =
    /// 10`, which makes the derived window exactly 32 at widths 2048 AND 4096
    /// (`2,097,088 * 2^11 < 2^32`); that is a calibration change, see PLAN.md.
    /// (review finding F-6: test builds only)
    #[cfg(test)]
    pub(crate) fn tinyllama_t32_dev() -> Shape {
        Shape::new(
            "TinyLlama-1.1B block geometry, scratch development calibration (T32 / d2048 / f5632, 32 heads of 64 over 4 KV heads)",
            TINYLLAMA_T32_DEV_PROFILE,
            32,
            2048,
            5632,
            32,
            64,
            4,
            12,
            4,
            9,
            21,
            None,
            None,
            Some(32),
            None,
        )
        .expect("the TinyLlama development shape is well formed")
    }

    /// **NATIVE LANE: the one door to a non-frozen calibration** (the
    /// lane-C prototype's door, extended with `tn` and the two multipliers).
    /// Refused on every profile outside [`TRAINED_CALIBRATION_PROFILES`], so
    /// the toy, the rungs, 125M and the lane-C dev shape cannot be handed a
    /// constant their receipts were not made with.
    ///
    /// * `tn`, `ceps` — validated by [`NormCalibration::derive_at_width`],
    ///   which recomputes `D_max` with the signed-int16 endpoint 32768 and the
    ///   declared `ceps`, and the window `wrho = tn + 1 + bits(D_max)`; a
    ///   shape needing a fifth remainder limb is refused, never widened. The
    ///   shape's `norm_wrho` and `d_max` are REPLACED by the derived values
    ///   (any override passed to [`Shape::new`] is refused here).
    /// * `cn_a`, `cn_m` — the two norms' multipliers: `y = round(g Cn x /
    ///   (2^tn D))`. Halving `tn` and halving `Cn` keep the same meaning.
    /// * `sh_ao` — the attention output requantization shift, inside the
    ///   one-limb class `0..=8` (the remainder's `scaled` coefficient is
    ///   `2^(8 - sh_ao)`); `sh_ao = 0` is exact, remainder pinned to zero.
    ///
    /// Every construction-time refusal of [`Shape::new`] that the window can
    /// touch is re-run by rebuilding the plane maps (`Ids` / `HIds` refuse a
    /// list they cannot express).
    pub(crate) fn with_trained_calibration(mut self, cal: &NormCalibration) -> Result<Shape, String> {
        if !TRAINED_CALIBRATION_PROFILES.contains(&self.profile) {
            return Err(format!("private block shape: the calibration of {} is frozen", self.profile));
        }
        if self.trained_calibration {
            return Err("private block shape: a trained calibration is given once, at construction".into());
        }
        let (d_max, wrho) = cal.derive_at_width(self.width)?;
        // the window must be the DERIVED one: a profile built with a
        // development override is not a trained-calibration profile
        let frozen_rule = NORM_TN + 1 + bit_length(isqrt_i128(NORM_CEPS + self.width as i128 * INT16_MAX * INT16_MAX));
        if self.norm_wrho != frozen_rule {
            return Err("private block shape: a trained calibration needs the derived norm window, not an override".into());
        }
        self.norm_tn = cal.tn;
        self.norm_cn_a = cal.cn_a;
        self.norm_cn_m = cal.cn_m;
        self.norm_ceps = cal.ceps;
        self.sh_ao = cal.sh_ao;
        self.sh_qkv = cal.sh_qkv;
        self.sh_s = cal.sh_s;
        self.sh_o = cal.sh_o;
        self.sh_g = cal.sh_g;
        self.sh_h = cal.sh_h;
        self.sh_z = cal.sh_z;
        self.norm_wrho = wrho;
        self.d_max = d_max;
        self.trained_calibration = true;
        self.check_trained_class()?;
        super::layout::Ids::new(&self)?;
        super::layout::HIds::new(&self)?;
        Ok(self)
    }

    /// **THE WHOLE DECLARED CLASS, RE-CHECKED FROM THE SHAPE'S OWN FIELDS**
    /// (review findings F-1 and F-5). Called by the trained door
    /// ([`Shape::with_trained_calibration`]) and again by
    /// `Layout::for_shape` for every trained shape, so a shape whose public
    /// fields were edited after the door, or built some other way, cannot
    /// reach a transcript:
    ///
    /// * the profile is one of [`TRAINED_CALIBRATION_PROFILES`];
    /// * the norm constants and the six windowed shifts pass
    ///   [`NormCalibration::derive_at_width`] at this width, and the shape's
    ///   `norm_wrho` and `d_max` ARE the derived values;
    /// * `f_e` is in [`TRAINED_F_E_RANGE`], and `wrho_s` is the derived
    ///   `clog2(T) + f_e` and at most [`TRAINED_WRHO_S_MAX`] (three limbs).
    pub(crate) fn check_trained_class(&self) -> Result<(), String> {
        if !TRAINED_CALIBRATION_PROFILES.contains(&self.profile) {
            return Err(format!("private block shape: {} is not a trained-calibration profile", self.profile));
        }
        let (d_max, wrho) = self.norm_calibration().derive_at_width(self.width)?;
        if (d_max, wrho) != (self.d_max, self.norm_wrho) {
            return Err(format!("private block shape: {}'s norm window {} / D_max {} are not the derived {wrho} / {d_max}", self.profile, self.norm_wrho, self.d_max));
        }
        Self::check_f_e_class(self.tokens, self.f_e)?;
        let want = clog2(self.tokens) as u32 + self.f_e;
        if self.wrho_s != want {
            return Err(format!("private block shape: {}'s softmax window {} is not the derived clog2(T) + f_e = {want}", self.profile, self.wrho_s));
        }
        Ok(())
    }

    /// **Every shape's softmax window** (re-review R2-a): `wrho_s` at most
    /// [`TRAINED_WRHO_S_MAX`] (three limbs) and `clog2(T) + f_e` too, so
    /// `e <= 2^f_e <= 2^24` and `Sum <= T 2^f_e <= 2^24` bound the quotient
    /// clause far below `p` whatever the profile. Every registered frozen
    /// shape has 14..=18 bits.
    pub(crate) fn check_softmax_window(sh: &Shape) -> Result<(), String> {
        if sh.wrho_s > TRAINED_WRHO_S_MAX || clog2(sh.tokens) as u32 + sh.f_e > TRAINED_WRHO_S_MAX {
            return Err(format!("private block shape: {}'s softmax window (wrho_s {}, clog2(T) + f_e = {}) exceeds {TRAINED_WRHO_S_MAX} bits", sh.profile, sh.wrho_s, clog2(sh.tokens) as u32 + sh.f_e));
        }
        Ok(())
    }

    /// `f_e` inside its declared class at `tokens` (review finding F-1): in
    /// [`TRAINED_F_E_RANGE`] and `clog2(T) + f_e <= 24`. The loader calls this
    /// before it builds a shape, the door and `Layout::for_shape` after.
    pub(crate) fn check_f_e_class(tokens: usize, f_e: u32) -> Result<(), String> {
        if !TRAINED_F_E_RANGE.contains(&f_e) {
            return Err(format!("trained calibration: f_e {f_e} is outside its declared class {TRAINED_F_E_RANGE:?} (the softmax quotient relation's no-wrap premise is derived for that class only; review finding F-1)"));
        }
        if tokens == 0 || clog2(tokens) as u32 + f_e > TRAINED_WRHO_S_MAX {
            return Err(format!("trained calibration: f_e {f_e} at T = {tokens} gives a softmax window above {TRAINED_WRHO_S_MAX} bits (three sigma_s limbs)"));
        }
        Ok(())
    }

    /// **NATIVE R6: the same trained shape with ANOTHER SCORE SHIFT** — the
    /// shape a run's stage is proved at when its layer declares its own
    /// `sh_s` (a per-layer export constant, like the exp `e_s` and the SiLU
    /// member). Only a trained-calibration shape; the value must lie in the
    /// one-limb window (the plane list and lookup counts do not move inside
    /// it: only the `scaled(rsl, 2^(8 - sh_s))` coefficient and the score
    /// host relation's `2^sh_s` / `2^(sh_s - 1)` constants); the result passes
    /// CS-8's rebuild through the door and the trained class check, so every
    /// derived window is the door's.
    pub(crate) fn with_score_shift(&self, sh_s: u32) -> Result<Shape, String> {
        if !self.trained_calibration {
            return Err(format!("private block shape: {} is not a trained-calibration shape; its score shift is frozen", self.profile));
        }
        if !ONE_LIMB_SHIFT.contains(&sh_s) {
            return Err(format!("trained calibration: a per-layer sh_s {sh_s} is outside its structure-preserving window {ONE_LIMB_SHIFT:?}"));
        }
        let mut s = self.clone();
        s.sh_s = sh_s;
        s.check_constructed()?;
        s.check_trained_class()?;
        Ok(s)
    }

    /// this shape's calibration, as the five constants
    pub(crate) fn norm_calibration(&self) -> NormCalibration {
        NormCalibration {
            tn: self.norm_tn,
            cn_a: self.norm_cn_a,
            cn_m: self.norm_cn_m,
            ceps: self.norm_ceps,
            sh_ao: self.sh_ao,
            sh_qkv: self.sh_qkv,
            sh_s: self.sh_s,
            sh_o: self.sh_o,
            sh_g: self.sh_g,
            sh_h: self.sh_h,
            sh_z: self.sh_z,
        }
    }

    /// **NATIVE LANE: THE TRAINED TinyLlama-1.1B BLOCK SHAPE at T = 32.** The
    /// true geometry (width 2048, FFN 5632 padded to 8192, 32 query heads of
    /// 64 over 4 KV heads, row width 2^12, rate 4, 21 endpoint rows) under a
    /// declared trained calibration. `f_e` is the softmax table's fractional
    /// bits from the calibration (9 keeps two `sigma_s` limbs at T32). With
    /// `tn = 10` the derived norm window is exactly 32 bits (four limbs, C-6),
    /// for every int16 input and every `ceps` in the class.
    pub(crate) fn tinyllama_t32_trained(cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        Shape::tinyllama_trained(32, cal, f_e)
    }

    /// **RULING CS-8 (ported from the 125M lane's stage 43): is this value one
    /// [`Shape::new`] builds?** `Shape`'s fields are readable (and writable)
    /// across the crate, so the invariant is re-checked instead of sealed:
    /// `Shape::new` is run again on this value's own parameters and the
    /// result must equal this value, field for field. NATIVE LANE: a TRAINED
    /// shape is rebuilt through the trained door at its own calibration (its
    /// windows are derived there, so they are not passed as overrides), so
    /// the declared classes, the derived windows and `D_max` are all re-run.
    /// Called first at every single-block entry and in the two shared bodies.
    /// It computes no digest, absorbs nothing, draws nothing.
    pub(crate) fn check_constructed(&self) -> Result<(), String> {
        const CS8: &str = "private block shape: ruling CS-8 — ";
        let (nw, ws) = if self.trained_calibration { (None, None) } else { (Some(self.norm_wrho), Some(self.wrho_s)) };
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
            nw,
            ws,
        )
        .and_then(|b| if self.trained_calibration { b.with_trained_calibration(&self.norm_calibration()) } else { Ok(b) })
        .map_err(|e| format!("{CS8}{:?} is not a shape Shape::new builds: Shape::new refuses its own parameters ({e})", self.name))?;
        if rebuilt == *self {
            return Ok(());
        }
        let differ: Vec<&str> = [
            ("opened_cols", rebuilt.opened_cols != self.opened_cols),
            ("endpoint_general", rebuilt.endpoint_general != self.endpoint_general),
            ("t_pad", rebuilt.t_pad != self.t_pad),
            ("d_pad", rebuilt.d_pad != self.d_pad),
            ("h_pad", rebuilt.h_pad != self.h_pad),
            ("f_pad", rebuilt.f_pad != self.f_pad),
            ("d_max", rebuilt.d_max != self.d_max),
            ("norm_wrho", rebuilt.norm_wrho != self.norm_wrho),
            ("wrho_s", rebuilt.wrho_s != self.wrho_s),
            ("the calibration", rebuilt.norm_calibration() != self.norm_calibration()),
            ("trained_calibration", rebuilt.trained_calibration != self.trained_calibration),
        ]
        .iter()
        .filter(|(_, d)| *d)
        .map(|(n, _)| *n)
        .collect();
        Err(format!("{CS8}{:?} is not a shape Shape::new builds: its {} differ from what Shape::new derives from its parameters", self.name, differ.join(", ")))
    }

    /// **ROUND 4 (R4-1): THE TRAINED Llama-3-8B BLOCK SHAPE at T = 32.** Row
    /// width [`LLAMA3_8B_LOG_COLS`], endpoint rows from the padded cube at that
    /// width plus the mask rows. The FFN pads 14336 to 16384 and the head
    /// axis is 32 slots of 128 (no padded head), the key-value groups of 4.
    pub(crate) fn llama3_8b_t32_trained(cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        Shape::check_f_e_class(32, f_e)?;
        trained_geometry(LLAMA3_8B_T32_TRAINED_PROFILE, f_e).ok_or("private block shape: an unregistered trained profile")??.with_trained_calibration(cal)
    }

    /// **Task 3 (2026-10-17 evening): the trained Llama-3-8B shape at a
    /// registered context length** (32, 64 or 128), each its own profile;
    /// T32 is exactly [`Shape::llama3_8b_t32_trained`]. Any other T is
    /// refused by name. T64 / T128 accepted by the independent review, round 5.
    pub(crate) fn llama3_8b_trained(tokens: usize, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        let profile = match tokens {
            32 => LLAMA3_8B_T32_TRAINED_PROFILE,
            64 => LLAMA3_8B_T64_TRAINED_PROFILE,
            128 => LLAMA3_8B_T128_TRAINED_PROFILE,
            _ => return Err(format!("private block shape: no trained Llama-3-8B profile is registered at T = {tokens} (32, 64 and 128 are)")),
        };
        Shape::check_f_e_class(tokens, f_e)?;
        trained_geometry(profile, f_e).ok_or("private block shape: an unregistered trained profile")??.with_trained_calibration(cal)
    }

    /// **TEST ONLY: the 8B geometry at another T and row width, for the
    /// counted layouts** (builds past ruling CS-9: COUNTED, never proved).
    #[cfg(test)]
    pub(crate) fn llama3_8b_at(tokens: usize, log_cols: usize, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        let profile = match tokens {
            32 => LLAMA3_8B_T32_TRAINED_PROFILE,
            64 => LLAMA3_8B_T64_TRAINED_PROFILE,
            128 => LLAMA3_8B_T128_TRAINED_PROFILE,
            _ => return Err(format!("no 8B profile at T = {tokens}")),
        };
        Shape::check_f_e_class(tokens, f_e)?;
        let rows = ((tokens.next_power_of_two() * 4096) >> log_cols) + super::endpoint_g::MASK_ROWS;
        Shape::build("Llama-3-8B block geometry, trained calibration, counted-layout ladder", profile, tokens, 4096, 14336, 32, 128, 8, log_cols, 4, f_e, rows, None, None, None, None)?.with_trained_calibration(cal)
    }

    /// **TEST ONLY: the same geometry at another row width, for the counted
    /// layouts.** It builds past ruling CS-9 (one profile string names one
    /// shape, and only [`LLAMA3_8B_LOG_COLS`] is registered), so it exists in
    /// test builds only and its shapes are COUNTED, never proved.
    #[cfg(test)]
    pub(crate) fn llama3_8b_t32_at(log_cols: usize, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        Shape::check_f_e_class(32, f_e)?;
        let rows = ((32 * 4096) >> log_cols) + super::endpoint_g::MASK_ROWS;
        Shape::build(
            "Llama-3-8B block geometry, trained calibration (T32 / d4096 / f14336, 32 heads of 128 over 8 KV heads)",
            LLAMA3_8B_T32_TRAINED_PROFILE,
            32,
            4096,
            14336,
            32,
            128,
            8,
            log_cols,
            4,
            f_e,
            rows,
            None,
            None,
            None,
            None,
        )?
        .with_trained_calibration(cal)
    }

    /// **ROUND 3 (R3-2): the trained TinyLlama shape at a registered context
    /// length** (32, 64 or 128), each with its own profile string. At T = 32
    /// this is exactly the round-2 shape (same name, profile, row width 2^12
    /// and 21 endpoint rows). The softmax rule `clog2(T) + f_e <= 24` and
    /// every declared class are checked by the door.
    pub(crate) fn tinyllama_trained(tokens: usize, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        let (name, profile, log_cols) = match tokens {
            32 => ("TinyLlama-1.1B block geometry, trained calibration (T32 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T32_TRAINED_PROFILE, 12),
            64 => ("TinyLlama-1.1B block geometry, trained calibration (T64 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T64_TRAINED_PROFILE, 13),
            128 => ("TinyLlama-1.1B block geometry, trained calibration (T128 / d2048 / f5632, 32 heads of 64 over 4 KV heads)", TINYLLAMA_T128_TRAINED_PROFILE, 14),
            _ => return Err(format!("private block shape: no trained TinyLlama profile is registered at T = {tokens} (32, 64 and 128 are)")),
        };
        let _ = (name, log_cols);
        Shape::check_f_e_class(tokens, f_e)?;
        trained_geometry(profile, f_e).ok_or("private block shape: an unregistered trained profile")??.with_trained_calibration(cal)
    }

    /// The same family at another token count, for the counted-layout ladder
    /// (T32..T512). Only the shapes [`Shape::new`] admits construct; the
    /// endpoint rows are the padded cube's at the row width plus the mask
    /// rows. COUNTED LAYOUTS ONLY: no profile is registered for T != 32.
    /// (review finding F-6: test builds only)
    #[cfg(test)]
    pub(crate) fn tinyllama_trained_ladder(tokens: usize, log_cols: usize, cal: &NormCalibration, f_e: u32) -> Result<Shape, String> {
        let rows = ((tokens.next_power_of_two() * 2048) >> log_cols) + super::endpoint_g::MASK_ROWS;
        // TEST ONLY and COUNTED, never proved: it builds past ruling CS-9
        // (the T32 profile string names one shape)
        Shape::build(
            "TinyLlama-1.1B block geometry, trained calibration, counted-layout ladder",
            TINYLLAMA_T32_TRAINED_PROFILE,
            tokens,
            2048,
            5632,
            32,
            64,
            4,
            log_cols,
            4,
            f_e,
            rows,
            None,
            None,
            None,
            None,
        )?
        .with_trained_calibration(cal)
    }

    /// **NATIVE LANE: the trained-calibration DEVELOPMENT rung.** Rung-C6's
    /// geometry (T32 / d384 / f512, 12 heads of 32 over 4 KV heads, row width
    /// 2^10) under a declared trained calibration, so that the end-to-end
    /// norm-alias cases (D16 item 6) and the coefficient tamper controls run
    /// in seconds. At width 384 the class admits `tn <= 11`.
    pub(crate) fn rung_tc(cal: &NormCalibration) -> Result<Shape, String> {
        trained_geometry(TRAINED_CALIB_RUNG_PROFILE, 12).ok_or("private block shape: an unregistered trained profile")??.with_trained_calibration(cal)
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
