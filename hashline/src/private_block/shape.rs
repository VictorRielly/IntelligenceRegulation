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
use super::layout::{SC_DMM, SC_DZC, SC_FZC, SC_GMM, SC_IO_IN, SC_IO_OUT, SC_KMM, SC_KVZC, SC_LZC, SC_PV, SC_QMM, SC_QZC, SC_RS, SC_SCORE, SC_SS, SC_SSM, SC_SZC, SC_TAB, SC_TZC, SC_UMM, SC_VMM, SC_WO, SC_ZS};

/// byte limbs of the isqrt witness `D`, `a1`, `a2` (each below `2^24`)
pub(crate) const LIMBS_ISQRT: usize = 3;
/// The FROZEN toy profile string. It is the gate of the pad rule (ruling P-1,
/// finding S9-F1) and of every later shape-driven addition: a new shape is a
/// NEW profile beside the toy, never an edit of it (D17).
pub(crate) const TOY_PROFILE: &str = "hashline-zk-mr1/private-block-t32-poc/1";
const INT16_MAX: i128 = 32_767;
/// the norm's fixed-point shift; the denominator is `2^(tn+1) * D`
const NORM_TN: u32 = 11;
const NORM_CEPS: i128 = 1;
/// the softmax quotient's scale: `p` reaches `2^F_P`, so it needs `F_P + 1` bits
const F_P: u32 = 9;

// the wire format's shape-independent counts (`wire.rs`)
const WIRE_HEADER: usize = 8 + 32;
const COL_CHECKS: usize = 256;
/// the mask message is `2 * 512` `Fp2` words whatever the shape is
const MASK_VEC: usize = 1024;
/// `log2(MASK_DOM = 4096)`
const MASK_PATH: usize = 12;

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

impl Shape {
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
        Ok(Shape {
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
            endpoint_log_n: endpoint_log_n.unwrap_or(log_cols),
            endpoint_inv_rate: endpoint_inv_rate.unwrap_or(inv_rate),
            // §3.3: the norm quotient's window is `tn + 1 + bits(D_max)`
            norm_wrho: norm_wrho.unwrap_or(NORM_TN + 1 + bit_length(d_max)),
            // §3.4: `Sum <= T * 2^F_E` and `sigma_s < Sum`
            wrho_s: wrho_s.unwrap_or(clog2(tokens) as u32 + f_e),
            t_pad,
            d_pad,
            h_pad,
            f_pad,
            d_max,
        })
    }

    /// THE TOY, the only shape that proves anything today.
    pub(crate) fn toy() -> Shape {
        Shape::new("toy block (T32 / d16 / f16, 2 heads of 8 over 1 KV head)", TOY_PROFILE, 32, 16, 16, 2, 8, 1, 8, 8, 9, 7, None, None, None, None).expect("the toy shape is well formed")
    }

    /// THE DEVELOPMENT RUNG of ruling P-7 (memo §9a). `F_E = 12` is a
    /// rung-only calibration, chosen so that the softmax window breaks at
    /// `T = 24` and the third `sigma_s` limb is exercised as it is at 125M.
    /// Development grade, never a deliverable: no receipt from it is shown to
    /// anyone and no soundness or privacy statement is made from it.
    pub(crate) fn rung() -> Shape {
        Shape::new(
            "development rung (T24 / d96 / f192, 6 heads of 16 over 2 KV heads)",
            "hashline-zk-mr1/private-block-rung-t24-dev/1",
            24,
            96,
            192,
            6,
            16,
            2,
            10,
            4,
            12,
            14,
            Some(8),
            Some(4),
            None,
            None,
        )
        .expect("the rung shape is well formed")
    }

    /// THE 125M-CLASS BLOCK (memo §2). A counted layout only, at this step.
    pub(crate) fn m125() -> Shape {
        Shape::new("125M private block (T512 / d768 / f2048, 12 heads of 64 over 4 KV heads)", "hashline-zk-mr1/private-block-m125/1", 512, 768, 2048, 12, 64, 4, 14, 4, 9, 29, None, None, None, None)
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
        self.profile != TOY_PROFILE
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
        let inner = |s: usize| -> usize {
            match s {
                SC_QMM | SC_KMM | SC_VMM | SC_WO | SC_GMM | SC_UMM => clog2(self.d_pad),
                SC_SCORE => clog2(self.head_dim),
                SC_PV => clog2(self.t_pad),
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
            out[s] = (main, ext, BASE_DEGREE[s] + usize::from(indicator));
        }
        out
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
    pub(crate) fn a_groups(&self) -> usize {
        let tzc = if self.natural_log(Dom::T) >= self.log_cols {
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
