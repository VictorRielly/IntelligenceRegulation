//! **TOKEN I/O, RUNG R1 (token-I/O R1 lane, 2026-10-17).** The first native
//! rung of proving the next token, built to
//! `results/zk60_token_io_design_20261017/DESIGN.md` v3, section 6.1: the
//! PUBLIC-ROW variant (the prompt fills the public bucket `T`; D26's two-site
//! endpoint is a later rung), the tiny-vocabulary rung (`V = 300`, padded to
//! 512), the trained-calibration development block geometry (`rung_tc`).
//!
//! ONE private run under ONE transcript:
//!
//! ```text
//! [stage IN] -> B_in -> block 0 -> B_1 -> ... -> block L-1 -> B_out -> [stage OUT]
//! ```
//!
//! * stage IN: hidden token ids (sealed in the input token endpoint, row width
//!   2^8 rate 1/8, one site) -> hidden `x_in` (the boundary `B_in`) through
//!   the public int16 embedding table, by the indexed LogUp of the compressed
//!   row (option (b)), BOS forced at position 0 by a clause with its OWN fresh
//!   coefficient (v3, CHECK2 N-1);
//! * the blocks: unchanged; every block stage is an interior stage (its two
//!   IO roles are two-site boundaries, D12a);
//! * stage OUT: `x` = `B_out` row `T - 1` (fixed public row bits), the final
//!   RMSNorm with a uniform gain (D24 window exactly 32 bits), the raw-integer
//!   logits through the public int8 head (virtual, never committed), the
//!   keyed argmax (numpy's first maximum), the hidden next token sealed in the
//!   output token endpoint.
//!
//! Every batched clause of every new slot carries its own fresh challenge
//! (DESIGN v3 3.1, CHECK2 N-3). Every new commitment is opened exactly once.
//!
//! **What this is NOT.** Not a privacy claim (no lane makes one; the G-1..G-7
//! gates of DESIGN 4.2 are owed), not a registered production profile beyond
//! the development rung, not the hidden-length variant. The profile string is
//! new (D17); no existing profile, relation, slot or byte moves.

pub(crate) mod run;
pub(crate) mod stage_in;
pub(crate) mod stage_out;
#[cfg(test)]
mod r0_words;
#[cfg(test)]
mod tests;

use super::argument::{build_tables_at, Acc, Cm, Coord, Poly, Priv, Side, SlotProof, Tab, TABLES_PAR_MIN};
use super::layout::SlotKind;
use super::shape::Shape;
use crate::field::{Fp, Fp2, P};
use crate::merkle::Digest;
use crate::mle::{eq_point, eq_table_msb, eval_mle_ext};
use crate::pcs::{OpeningZk, PcsParams, Slice, ZClaim, ZPart};
use crate::sumcheck::{self, masked_terminal, CfsMask, SumcheckProof};
use crate::transcript::Transcript;
use crate::zk::{extension, MaskFunctional, MaskOpening};

// ---------------------------------------------------------------- constants

/// **THE SECURITY TIER'S LEVERS (D27, Victor 2026-10-17 20:22 UTC).** Proofs
/// must eventually be selectable at different security tiers, so every
/// soundness lever of the new stages is a PROFILE PARAMETER carried by the
/// run statement, never a literal of the stage code: the column checks `Q`
/// (= the ZK pads per row), the row width (the B-1 floor) and inverse rate of
/// the stage commitments, the token endpoints' row width and inverse rate,
/// and the extension degree of the field the LogUp challenges live in. The
/// registered R1 profile carries [`Tier::R1_MVP`], today's values. Not a
/// lever here: the mask commitment `M`'s `Q`, which is `zk.rs`'s `MASK_Q` for
/// every stage and block alike (a shared file this lane does not edit).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Tier {
    pub name: &'static str,
    /// column checks of every new-stage and token-endpoint opening, and the
    /// ZK pad count of each committed row (`ZkOpts::standard`)
    pub opened_cols: usize,
    /// the row width of `A_in`, `H_in`, `A_out`, `H_out` (DESIGN B-1's floor)
    pub stage_log_n: usize,
    pub stage_inv_rate: usize,
    /// the token endpoints' row width and inverse rate (DESIGN B-1)
    pub ep_log_n: usize,
    pub ep_inv_rate: usize,
    /// the LogUp challenges (alpha, beta, gamma, r_emb) live in F_p^k; k = 2
    /// (`Fp2`) is the only field built
    pub lookup_ext_degree: usize,
}

impl Tier {
    /// The R1 profile's tier: the D27 MVP tier's values as the design fixed
    /// them (stages at 2^12 rate 1/4, 2^-103.69 per opening; token endpoints
    /// at 2^8 rate 1/8, 2^-106.25; Q = 256; F_p^2 challenges).
    pub(crate) const R1_MVP: Tier = Tier { name: "mvp-95-whole-run (D27)", opened_cols: 256, stage_log_n: 12, stage_inv_rate: 4, ep_log_n: 8, ep_inv_rate: 8, lookup_ext_degree: 2 };

    /// what this build can prove at; refused by name otherwise
    pub(crate) fn check(&self) -> Result<(), String> {
        if self.lookup_ext_degree != 2 {
            return Err(format!("token I/O tier {}: LogUp challenges in F_p^{} are not built (only F_p^2)", self.name, self.lookup_ext_degree));
        }
        for (what, log_n, rate) in [("stage", self.stage_log_n, self.stage_inv_rate), ("token endpoint", self.ep_log_n, self.ep_inv_rate)] {
            if !(2..=20).contains(&log_n) || !rate.is_power_of_two() || rate < 2 || log_n + rate.trailing_zeros() as usize > 24 {
                return Err(format!("token I/O tier {}: the {what} row geometry 2^{log_n} rate 1/{rate} is out of range", self.name));
            }
            if self.opened_cols == 0 || self.opened_cols > 1usize << log_n {
                return Err(format!("token I/O tier {}: Q = {} pads exceed the {what} row width 2^{log_n}", self.name, self.opened_cols));
            }
        }
        // the stage-23 invariant: the byte table lifts UP to the row width
        if self.stage_log_n < 8 {
            return Err(format!("token I/O tier {}: the stage row width is below the byte table's natural size", self.name));
        }
        Ok(())
    }
    pub(crate) fn stage_n(&self) -> usize {
        1 << self.stage_log_n
    }
    pub(crate) fn ep_n(&self) -> usize {
        1 << self.ep_log_n
    }
    pub(crate) fn stage_params(&self) -> PcsParams {
        PcsParams { log_cols: self.stage_log_n as u32, inv_rate: self.stage_inv_rate, num_col_checks: self.opened_cols }
    }
    /// the per-opening miss probability of a commitment at this tier
    /// (column test `(1 - delta/3)^Q`, ZK code `RS(n + Q, n inv_rate)`), log2
    pub(crate) fn per_opening_log2(&self, log_n: usize, inv_rate: usize) -> f64 {
        let n = (1usize << log_n) as f64;
        let delta = 1.0 - (n + self.opened_cols as f64) / (n * inv_rate as f64);
        self.opened_cols as f64 * (1.0 - delta / 3.0).log2()
    }
    /// the transcript-bound text (integers only: no float formatting reaches
    /// a transcript)
    pub(crate) fn describe(&self) -> String {
        format!(
            "tier {}: Q={} stage-row 2^{} rate 1/{} token-endpoint-row 2^{} rate 1/{} lookup-field F_p^{}",
            self.name, self.opened_cols, self.stage_log_n, self.stage_inv_rate, self.ep_log_n, self.ep_inv_rate, self.lookup_ext_degree
        )
    }
}

/// D25 T4 as amended (2026-10-17 20:21 UTC, option (b)): the head's per-row
/// integer multipliers `m_j` lie in `[1, 2^MULT_BITS]`
/// (`m_j = max(1, round(2^12 s_j / max s))`, fidelity REPORT section 2)
pub(crate) const MULT_BITS: u32 = 12;
/// the fourth LogUp table tag (DESIGN 2.2 (b)): `g_emb = gamma * TAG_EMB`. The
/// three existing tags are 133 (U8), 129 (exp), 134 (act); 135 is unused.
pub(crate) const TAG_EMB: u64 = 135;
/// the byte table's length
pub(crate) const U8_LEN: usize = 256;
/// isqrt limbs of the final norm (`D`, `a1`, `a2`, three bytes each)
pub(crate) const LIMBS_ISQRT: usize = 3;
/// the final norm's remainder limbs (window exactly 32 bits: C-6, no scaled top)
pub(crate) const NORM_LIMBS: usize = 4;
/// the declared classes of the token-I/O constants (DESIGN 4.1, D24 F-1 rule)
pub(crate) const V_MAX: usize = 1 << 17;
pub(crate) const CN_F_MAX: i64 = 1 << 20;
pub(crate) const CEPS_F_MAX: i64 = 1 << 40;
pub(crate) const TN_F_RANGE: std::ops::RangeInclusive<u32> = 1..=16;

fn clog2(v: usize) -> usize {
    assert!(v > 0, "clog2 of zero");
    v.next_power_of_two().trailing_zeros() as usize
}

fn isqrt_i128(v: i128) -> i128 {
    if v < 2 {
        return v;
    }
    let mut x = 1i128 << (128 - v.leading_zeros()).div_ceil(2);
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

pub(crate) fn hex(d: &[u8]) -> String {
    d.iter().map(|b| format!("{b:02x}")).collect()
}

// ---------------------------------------------------------------- the token profile

/// The selector variant (DESIGN 8, D26 C-a): bound into the run statement so
/// a receipt cannot be re-read under another variant. Only the public row is
/// built at R1; the other two exist so that a verifier configured for them is
/// a DIFFERENT statement (control 22).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum SelectorVariant {
    PublicRow,
    SealedInInput,
    SealedInOutput,
}

impl SelectorVariant {
    pub(crate) fn tag(self) -> &'static str {
        match self {
            SelectorVariant::PublicRow => "public-row",
            SelectorVariant::SealedInInput => "P-selector-sealed-in-input",
            SelectorVariant::SealedInOutput => "F-selector-sealed-in-output",
        }
    }
}

/// The final norm's constants (DESIGN 3.1 item 2): the block's norm relation
/// with a UNIFORM gain `g0`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct FinalNorm {
    pub g0: i64,
    pub cn: i64,
    pub tn: u32,
    pub ceps: i64,
}

/// Every public constant the two new stages read, validated at ONE door
/// ([`TokenProfile::new`]) on both sides (D24 F-1 rule: each exportable
/// constant has a declared class; the limb count is DERIVED, never exported).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TokenProfile {
    pub v: usize,
    pub v_pad: usize,
    /// `log2(V_pad)`: the key's shift `2^v`
    pub log_v: usize,
    pub d: usize,
    pub d_pad: usize,
    pub tokens: usize,
    pub t_pad: usize,
    pub bos: u64,
    pub norm: FinalNorm,
    pub wrho: u32,
    pub d_max: i128,
    /// the keyed difference's byte limbs, `ceil(window / 8)` (finding TF-1)
    pub limbs: usize,
    pub window_bits: u32,
    pub emb_digest: Digest,
    pub head_digest: Digest,
    pub variant: SelectorVariant,
    /// the head's per-row multiplier class `[1, 2^mult_bits]` (D25 T4 amended)
    pub mult_bits: u32,
    /// the security tier's levers (D27)
    pub tier: Tier,
}

impl TokenProfile {
    /// **THE TOKEN-I/O DOOR.** Refuses by name every constant outside its
    /// declared class (DESIGN 4.1, D24 F-1; CHECK2 N-2 for BOS; D25 T4 as
    /// amended for the head multipliers; D27 for the tier), on the prover's
    /// AND the verifier's side: both build their statement through here.
    pub(crate) fn new(sh: &Shape, tables: &TokenTables, bos: u64, norm: FinalNorm, variant: SelectorVariant, tier: Tier) -> Result<TokenProfile, String> {
        tier.check()?;
        let v = tables.v;
        if tables.d != sh.width {
            return Err(format!("token I/O: the tables are {} wide, the block width is {}", tables.d, sh.width));
        }
        if let Some((j, m)) = tables.mult.iter().enumerate().find(|(_, m)| !(1..=1i64 << MULT_BITS).contains(*m)) {
            return Err(format!("token I/O: head row {j}'s multiplier {m} is outside its declared class [1, 2^{MULT_BITS}] (D25 T4 as amended)"));
        }
        let (emb_digest, head_digest) = (tables.emb_digest(), tables.head_digest());
        if !(2..=V_MAX).contains(&v) {
            return Err(format!("token I/O: V = {v} is outside its declared class 2..=2^17"));
        }
        if bos >= v as u64 {
            return Err(format!("token I/O: the BOS constant {bos} is outside its class [0, V) with V = {v} (CHECK2 N-2)"));
        }
        if !(1..=127).contains(&norm.g0) {
            return Err(format!("token I/O: the final norm's uniform gain g0 = {} is outside its class [1, 127]", norm.g0));
        }
        if !(1..=CN_F_MAX).contains(&norm.cn) {
            return Err(format!("token I/O: the final norm's Cn = {} is outside its class [1, 2^20]", norm.cn));
        }
        if !(1..=CEPS_F_MAX).contains(&norm.ceps) {
            return Err(format!("token I/O: the final norm's Ceps = {} is outside its class [1, 2^40]", norm.ceps));
        }
        if !TN_F_RANGE.contains(&norm.tn) {
            return Err(format!("token I/O: the final norm's tn = {} is outside its class 1..=16", norm.tn));
        }
        let (d, d_pad) = (sh.width, sh.d_pad);
        let d_max = isqrt_i128(i128::from(norm.ceps) + d as i128 * 32768 * 32768);
        if 2 * d_max >= 1i128 << (8 * LIMBS_ISQRT) {
            return Err(format!("token I/O: the final norm's D_max {d_max} (or a1 = 2 D_max) leaves the three isqrt byte limbs"));
        }
        let wrho = norm.tn + 1 + bit_length(d_max);
        if wrho != 8 * NORM_LIMBS as u32 {
            return Err(format!(
                "token I/O: the final norm's remainder window tn + 1 + bits(D_max) = {wrho} bits; this rung's plane list is pinned at exactly 32 (D24: tn is per profile, here {} at width {d})",
                31u32.saturating_sub(bit_length(d_max))
            ));
        }
        let v_pad = v.next_power_of_two();
        let log_v = clog2(v_pad);
        // the honest keyed difference over the WHOLE multiplier class:
        // 2^v (2 d 127^2 2^mult_bits) + (V - 1) (DESIGN 3.1, N-3; D25 T4 amended)
        let top = ((2 * d as i128 * 127 * 127 * (1i128 << MULT_BITS)) << log_v) + (v as i128 - 1);
        let window_bits = bit_length(top);
        let limbs = (window_bits as usize).div_ceil(8);
        // no-wrap (DESIGN 4.4 N-2 / N-3): delta in [0, 2^(8 limbs)) and the
        // identity's right side below 2^window, both with p's margin
        if (1u128 << (8 * limbs)) + (1u128 << window_bits) >= u128::from(P) {
            return Err("token I/O: the keyed difference's limbs and window wrap the field".into());
        }
        // R1 LAYOUT: every stage domain fits one stage row (DESIGN 6.1); a
        // wider rung changes the plane rows and is a different layout
        let sn = tier.stage_n();
        if v_pad > sn || d_pad > sn || sh.t_pad > sn || sh.t_pad.max(tier.ep_n()) > sn {
            return Err(format!("token I/O: the R1 layout needs V_pad ({v_pad}), d_pad ({d_pad}) and T_pad ({}) within one stage row of {sn}", sh.t_pad));
        }
        Ok(TokenProfile { v, v_pad, log_v, d, d_pad, tokens: sh.tokens, t_pad: sh.t_pad, bos, norm, wrho, d_max, limbs, window_bits, emb_digest, head_digest, variant, mult_bits: MULT_BITS, tier })
    }

    /// the input token endpoint's plane: `tok` over `max(row width, T_pad)`
    /// words (public-row variant)
    pub(crate) fn in_ep_words(&self) -> usize {
        self.t_pad.max(self.tier.ep_n())
    }
    /// the output token endpoint's plane: one id in one row (mode i)
    pub(crate) fn out_ep_words(&self) -> usize {
        self.tier.ep_n()
    }

    /// the canonical text, absorbed through the run's parameter line and
    /// calibration identity
    pub(crate) fn describe(&self) -> String {
        format!(
            "token-io R1: V={} V_pad={} d={} d_pad={} T={} BOS={} final-norm g0={} cn={} tn={} ceps={} wrho={} dmax={} head-multipliers=[1,2^{}] keyed-window={} byte-limbs={} no-pin embedding={} head={} variant={} mode=next-token {}",
            self.v,
            self.v_pad,
            self.d,
            self.d_pad,
            self.tokens,
            self.bos,
            self.norm.g0,
            self.norm.cn,
            self.norm.tn,
            self.norm.ceps,
            self.wrho,
            self.d_max,
            self.mult_bits,
            self.window_bits,
            self.limbs,
            hex(&self.emb_digest),
            hex(&self.head_digest),
            self.variant.tag(),
            self.tier.describe()
        )
    }

    pub(crate) fn digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io/profile/v1");
        let s = self.describe();
        h.update(&(s.len() as u64).to_le_bytes());
        h.update(s.as_bytes());
        *h.finalize().as_bytes()
    }
}

// ---------------------------------------------------------------- the public tables

/// The public tables of the run: the int16 embedding (`V x d`, rotation and
/// `s_in` already applied, TOKEN_IO_SPEC), the int8 head `W'` (`V x d`) and
/// its per-row integer multipliers `m_j` (D25 T4 as amended): the logits are
/// `l_j = m_j (y . W'_j)`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct TokenTables {
    pub v: usize,
    pub d: usize,
    pub emb: Vec<i16>,
    pub head: Vec<i8>,
    pub mult: Vec<i64>,
}

impl TokenTables {
    pub(crate) fn new(v: usize, d: usize, emb: Vec<i16>, head: Vec<i8>, mult: Vec<i64>) -> Result<TokenTables, String> {
        if emb.len() != v * d || head.len() != v * d || mult.len() != v {
            return Err(format!("token I/O tables: the embedding has {} and the head {} words, the multipliers {}; V x d is {}", emb.len(), head.len(), mult.len(), v * d));
        }
        Ok(TokenTables { v, d, emb, head, mult })
    }

    pub(crate) fn emb_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io/embedding-int16/v1");
        h.update(&(self.v as u64).to_le_bytes());
        h.update(&(self.d as u64).to_le_bytes());
        for w in &self.emb {
            h.update(&w.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }

    pub(crate) fn head_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/token-io/head-int8-per-row-multipliers/v1");
        h.update(&(self.v as u64).to_le_bytes());
        h.update(&(self.d as u64).to_le_bytes());
        for w in &self.head {
            h.update(&[*w as u8]);
        }
        for m in &self.mult {
            h.update(&m.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }

    /// `l_j = m_j sum_i y_i W'[j][i]` over the true vocabulary: the RAW
    /// integer accumulators times the row multiplier (no requantization)
    pub(crate) fn logits(&self, y: &[i64]) -> Vec<i64> {
        (0..self.v).map(|j| self.mult[j] * self.head_row(j).iter().zip(y.iter()).map(|(w, a)| i64::from(*w) * a).sum::<i64>()).collect()
    }

    pub(crate) fn emb_row(&self, tok: usize) -> &[i16] {
        &self.emb[tok * self.d..(tok + 1) * self.d]
    }

    pub(crate) fn head_row(&self, j: usize) -> &[i8] {
        &self.head[j * self.d..(j + 1) * self.d]
    }

    /// `E~(v, r)` for every true row: `sum_{i < d} eq(r)[i] E[v][i]` over the
    /// `d_pad` columns (pad columns zero). The verifier's `O(V d)` fold.
    pub(crate) fn emb_fold(&self, r: &[Fp2]) -> Vec<Fp2> {
        let e = eq_table_msb(r);
        (0..self.v)
            .map(|v| self.emb_row(v).iter().zip(e.iter()).fold(Fp2::ZERO, |a, (w, c)| if *w == 0 { a } else { a.add(c.mul_base(Fp::from_i64(i64::from(*w)))) }))
            .collect()
    }

    /// `Wf[i] = sum_{j < V} w[j] m_j W'[j][i]` over `d_pad` entries (pad
    /// columns zero): the public fold of the per-row-scaled head
    pub(crate) fn head_fold(&self, w: &[Fp2], d_pad: usize) -> Vec<Fp2> {
        let mut out = vec![Fp2::ZERO; d_pad];
        for j in 0..self.v {
            let wj = w[j].mul_base(Fp::from_i64(self.mult[j]));
            for (i, x) in self.head_row(j).iter().enumerate() {
                if *x != 0 {
                    out[i] = out[i].add(wj.mul_base(Fp::from_i64(i64::from(*x))));
                }
            }
        }
        out
    }
}

// ---------------------------------------------------------------- the stage schedule

#[derive(Clone, Debug)]
pub(crate) struct SlotSpec {
    pub name: &'static str,
    pub main: usize,
    pub ext: usize,
    pub degree: usize,
    pub kind: SlotKind,
    pub a_sites: usize,
    pub h_sites: usize,
    /// claims on the two IO commitments of the stage (`Cm::In` / `Cm::Out`)
    pub io_sites: usize,
}

impl SlotSpec {
    pub(crate) fn terms(&self) -> usize {
        self.a_sites + self.h_sites + self.io_sites
    }
}

/// The declared schedule of one stage: its slots in transcript order, its
/// host groups, and the row width of each of its four commitment roles
/// (`[A, H, In, Out]`, the `Cm` order).
#[derive(Clone, Debug)]
pub(crate) struct StageSched {
    pub label: &'static str,
    pub slots: Vec<SlotSpec>,
    pub hosts: Vec<(usize, Vec<usize>)>,
    pub row_log: [usize; 4],
}

/// One stage's commitment layout: planes contiguous and row aligned, one
/// reserved pair per claim site in slot order, then the proximity pair
/// (exactly the block's rule, `layout.rs`).
#[derive(Clone, Debug)]
pub(crate) struct StageLayout {
    /// the stage commitments' PCS parameters (the tier's, D27)
    pub params: PcsParams,
    pub log_n: usize,
    pub n: usize,
    pub a_log: Vec<usize>,
    pub a_off: Vec<usize>,
    pub a_data_rows: usize,
    pub a_mask_base: usize,
    pub a_prox: usize,
    pub a_rows: usize,
    pub h_log: Vec<usize>,
    pub h_off: Vec<(usize, usize)>,
    pub h_data_rows: usize,
    pub h_mask_base: usize,
    pub h_prox: usize,
    pub h_rows: usize,
    /// the sign each H plane enters the value-0 LogUp sum with (table helpers -1)
    pub h_sign: Vec<i64>,
    /// the zero-sum pair `u`
    pub h_u: usize,
    a_prefix: Vec<usize>,
    h_prefix: Vec<usize>,
    pub sched: StageSched,
}

fn rows_of(log: usize, log_n: usize) -> usize {
    std::cmp::max(1, (1usize << log) >> log_n)
}

impl StageLayout {
    pub(crate) fn new(params: PcsParams, a_log: Vec<usize>, h_log: Vec<usize>, h_sign: Vec<i64>, h_u: usize, sched: StageSched) -> StageLayout {
        let log_n = params.log_cols as usize;
        let n = 1usize << log_n;
        let mut row = 0usize;
        let mut a_off = Vec::with_capacity(a_log.len());
        for l in &a_log {
            a_off.push(row * n);
            row += rows_of(*l, log_n);
        }
        let a_data_rows = row;
        let ns = sched.slots.len();
        let (mut a_prefix, mut h_prefix) = (vec![0usize; ns + 1], vec![0usize; ns + 1]);
        for (s, sp) in sched.slots.iter().enumerate() {
            a_prefix[s + 1] = a_prefix[s] + sp.a_sites;
            h_prefix[s + 1] = h_prefix[s] + sp.h_sites;
        }
        let a_mask_base = a_data_rows;
        let a_prox = a_mask_base + 2 * a_prefix[ns];
        let a_rows = a_prox + 2;
        let mut row = 0usize;
        let mut h_off = Vec::with_capacity(h_log.len());
        for l in &h_log {
            let r = rows_of(*l, log_n);
            h_off.push((row * n, (row + r) * n));
            row += 2 * r;
        }
        let h_data_rows = row;
        let h_mask_base = h_data_rows;
        let h_prox = h_mask_base + 2 * h_prefix[ns];
        let h_rows = h_prox + 2;
        StageLayout { params, log_n, n, a_log, a_off, a_data_rows, a_mask_base, a_prox, a_rows, h_log, h_off, h_data_rows, h_mask_base, h_prox, h_rows, h_sign, h_u, a_prefix, h_prefix, sched }
    }

    pub(crate) fn a_sites_total(&self) -> usize {
        self.a_prefix[self.sched.slots.len()]
    }
    pub(crate) fn h_sites_total(&self) -> usize {
        self.h_prefix[self.sched.slots.len()]
    }
    pub(crate) fn a_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.sched.slots[slot].a_sites {
            return Err(format!("token I/O {}: undeclared A site {k} in slot {slot}", self.sched.label));
        }
        Ok(self.a_mask_base + 2 * (self.a_prefix[slot] + k))
    }
    pub(crate) fn h_site(&self, slot: usize, k: usize) -> Result<usize, String> {
        if k >= self.sched.slots[slot].h_sites {
            return Err(format!("token I/O {}: undeclared H site {k} in slot {slot}", self.sched.label));
        }
        Ok(self.h_mask_base + 2 * (self.h_prefix[slot] + k))
    }
    pub(crate) fn a_site_rows(&self) -> Vec<usize> {
        (self.a_mask_base..self.a_prox).collect()
    }
    pub(crate) fn h_site_rows(&self) -> Vec<usize> {
        (self.h_mask_base..self.h_prox).collect()
    }
    pub(crate) fn h_u_rows(&self) -> [usize; 2] {
        let (re, im) = self.h_off[self.h_u];
        [re / self.n, im / self.n]
    }
    pub(crate) fn m_rows(&self) -> usize {
        2 * self.sched.slots.len() + 4
    }
    pub(crate) fn mask_specs(&self) -> Vec<(usize, usize)> {
        self.sched.slots.iter().map(|s| (s.main + s.ext, s.degree)).collect()
    }
    /// committed elements `(A + H rows) * n` — the counter's "elements"
    pub(crate) fn elems(&self) -> usize {
        (self.a_rows + self.h_rows) * self.n
    }
    pub(crate) fn n_functionals(&self) -> usize {
        self.sched.slots.iter().map(|s| 1 + usize::from(s.kind == SlotKind::Standalone)).sum::<usize>() + self.sched.hosts.len()
    }

    /// The value-0 LogUp identity on `H`: every helper with its sign plus the
    /// zero-sum pair, as ONE pairless all-ones sum claim (`protocol::logup_sum_claim`).
    pub(crate) fn logup_sum_claim(&self) -> ZClaim {
        let mut parts = Vec::with_capacity(2 * self.h_log.len());
        for (p, (re, im)) in self.h_off.iter().enumerate() {
            let sign = Fp2::from_i64(self.h_sign[p]);
            let log_size = self.h_log[p] as u32;
            parts.push(ZPart { slice: Slice { offset: *re, log_size }, coef: sign, point: vec![] });
            parts.push(ZPart { slice: Slice { offset: *im, log_size }, coef: sign.mul(Fp2::U), point: vec![] });
        }
        ZClaim { parts, value: Fp2::ZERO }
    }

    pub(crate) fn describe(&self) -> Vec<String> {
        let mut out = vec![
            format!("{}: n={} inv_rate={} Q={}", self.sched.label, self.n, self.params.inv_rate, self.params.num_col_checks),
            format!("A rows={} data={} site-pairs={} prox-pair=({},{}) planes={:?}", self.a_rows, self.a_data_rows, self.a_sites_total(), self.a_prox, self.a_prox + 1, self.a_log),
            format!("H rows={} data={} site-pairs={} zero-sum-pair={:?} prox-pair=({},{}) planes={:?} signs={:?}", self.h_rows, self.h_data_rows, self.h_sites_total(), self.h_u_rows(), self.h_prox, self.h_prox + 1, self.h_log, self.h_sign),
            format!("M rows={} functionals={} row-logs={:?}", self.m_rows(), self.n_functionals(), self.sched.row_log),
        ];
        for (s, sp) in self.sched.slots.iter().enumerate() {
            out.push(format!("slot {s:02} [{}] main={} ext={} degree={} kind={:?} A-sites={} H-sites={} IO-sites={}", sp.name, sp.main, sp.ext, sp.degree, sp.kind, sp.a_sites, sp.h_sites, sp.io_sites));
        }
        for (host, hosted) in &self.sched.hosts {
            out.push(format!("host {host:02} <- {hosted:?}"));
        }
        out
    }
}

// ---------------------------------------------------------------- the slot runner

/// One slot's definition (as `argument::SlotDef`, schedule-driven).
pub(crate) struct StageSlotDef {
    pub slot: usize,
    pub tabs: Vec<Tab>,
    pub poly: Poly,
    pub hosted: Vec<(usize, Fp2)>,
}

pub(crate) fn rho(r: std::ops::Range<usize>) -> Vec<Coord> {
    r.map(Coord::Rho).collect()
}
pub(crate) fn fixed(p: &[Fp2]) -> Vec<Coord> {
    p.iter().map(|f| Coord::Fixed(*f)).collect()
}
pub(crate) fn k(v: i64) -> Fp2 {
    Fp2::from_i64(v)
}
pub(crate) fn nonzero(v: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    if v.iter().any(|x| x.is_zero()) {
        return Err("zero batching challenge; discard attempt".into());
    }
    Ok(v)
}
/// the MSB-first bits of `value` as `bits` fixed coordinates
pub(crate) fn fixed_bits(value: usize, bits: usize) -> Vec<Coord> {
    (0..bits).map(|b| Coord::Fixed(if (value >> (bits - 1 - b)) & 1 == 1 { Fp2::ONE } else { Fp2::ZERO })).collect()
}

fn claim_point(p: &Priv, rho: &[Fp2]) -> Vec<Fp2> {
    p.coords
        .iter()
        .map(|c| match c {
            Coord::Rho(k) => rho[*k],
            Coord::Flip(k) => Fp2::ONE.sub(rho[*k]),
            Coord::Fixed(f) => *f,
        })
        .collect()
}

/// the reserved pair's value at the claim's column tail (`argument::mask_eval`)
fn mask_eval(log_n: usize, p: &Priv, data: &[Fp], point: &[Fp2]) -> Fp2 {
    let n = 1usize << log_n;
    let logm = p.log.min(log_n);
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let eq = eq_table_msb(&point[p.log - logm..]);
    let row = |r: usize| data[r * n + c0..r * n + c0 + eq.len()].iter().zip(eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(e.mul_base(*x)));
    row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))
}

/// `cd * plane~(point) + cm * (R_re + u R_im)(tail point)` (`argument::build_claim`)
fn build_claim(log_n: usize, p: &Priv, point: &[Fp2], cd: Fp2, cm: Fp2, value: Fp2) -> ZClaim {
    let n = 1usize << log_n;
    let logm = p.log.min(log_n);
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let tail = point[p.log - logm..].to_vec();
    let mut parts: Vec<ZPart> = p.slices.iter().map(|(off, coef)| ZPart { slice: Slice { offset: *off, log_size: p.log as u32 }, coef: coef.mul(cd), point: point.to_vec() }).collect();
    for (kk, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (p.mask_row + kk) * n + c0, log_size: logm as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    ZClaim { parts, value }
}

fn total(tables: &[Vec<Fp2>], poly: &Poly) -> Fp2 {
    let len = tables[0].len();
    let mut row = vec![Fp2::ZERO; tables.len()];
    let mut acc = Fp2::ZERO;
    for x in 0..len {
        for (r, t) in row.iter_mut().zip(tables.iter()) {
            *r = t[x];
        }
        acc = acc.add(poly(&row));
    }
    acc
}

/// **ONE SLOT OF A NEW STAGE, BOTH SIDES.** `argument::run_slot` line for
/// line, reading the stage's own schedule instead of the block's: absorb the
/// slot index -> draw `c` (zero: refuse) -> absorb the ONE published scalar ->
/// masked rounds -> one extension round per private factor family -> absorb
/// the masked terminals -> the claims and the M functionals.
pub(crate) fn run_stage_slot(side: &mut Side, acc: &mut Acc, mut def: StageSlotDef, sched: &StageSched, tr: &mut Transcript) -> Result<(), String> {
    let s = def.slot;
    let sp = sched.slots.get(s).ok_or("token I/O: slot outside the schedule")?.clone();
    let (n, ext, degree, kind) = (sp.main, sp.ext, sp.degree, sp.kind);
    let n_priv = def.tabs.iter().filter(|t| matches!(t, Tab::Priv(_))).count();
    if s != acc.cs.len() || n_priv != sp.terms() || (kind == SlotKind::Host) == def.hosted.is_empty() {
        return Err(format!("token I/O {}: slot {s} differs from the declared schedule", sched.label));
    }
    if def.tabs.iter().any(|t| matches!(t, Tab::Priv(p) if p.ext_round >= ext || p.coords.len() != p.log)) {
        return Err(format!("token I/O {}: slot {s} table shape", sched.label));
    }
    if def.tabs.iter().any(|t| matches!(t, Tab::Pub(v) if v.len() != 1usize << n)) {
        return Err(format!("token I/O {}: slot {s} public table length", sched.label));
    }
    tr.absorb_u64(b"tk-slot", s as u64);
    acc.order.push(format!("{} slot {s:02} begin", sched.label));
    let c = tr.challenge_fp2();
    if c.is_zero() {
        return Err("zero CFS mask challenge; discard attempt".into());
    }
    let (scalar, rho, es, terms, g_val) = match side {
        Side::Prove { pd, out } => {
            let mut tables: Vec<Vec<Fp2>> = build_tables_at(&mut def.tabs, n, pd, TABLES_PAR_MIN);
            if tables.iter().any(|t| t.len() != 1usize << n) {
                return Err(format!("token I/O {}: slot {s} table length", sched.label));
            }
            let mask = &pd.masks[s];
            let scalar = match kind {
                SlotKind::Private => total(&tables, &def.poly).add(c.mul(mask.total())),
                SlotKind::Standalone => c.mul(mask.total()),
                SlotKind::Host => def.hosted.iter().fold(c.mul(mask.total()), |g, (hs, coef)| g.sub(coef.mul(acc.cs[*hs]).mul(pd.masks[*hs].total()))),
            };
            tr.absorb_fp2(b"tk-scalar", &[scalar]);
            let poly = |v: &[Fp2]| (def.poly)(v);
            let unmasked_claim = if kind == SlotKind::Private { Some(scalar.sub(c.mul(mask.total()))) } else { None };
            let (mut rounds, rho, finals) = {
                let mut evaluator = sumcheck::ClosureRounds::new(&mut tables, degree, &poly).recover_one(unmasked_claim);
                crate::zk::masked_prove_rounds(&mut evaluator, mask, c, tr)
            };
            let mut cur = finals;
            let mut prev = rho.clone();
            for m in 0..ext {
                let exts: Vec<Fp2> = def
                    .tabs
                    .iter()
                    .map(|t| match t {
                        Tab::Priv(p) if p.ext_round == m => mask_eval(sched.row_log[p.cm as usize], p, pd.data[p.cm as usize], &claim_point(p, &rho)),
                        _ => Fp2::ZERO,
                    })
                    .collect();
                let e = extension(&cur, &exts, degree, &poly, mask, c, &prev, &mut rounds, tr);
                for (v, x) in cur.iter_mut().zip(exts.iter()) {
                    *v = masked_terminal(*v, *x, e);
                }
                prev.push(e);
            }
            let terms: Vec<Fp2> = def.tabs.iter().zip(cur.iter()).filter(|(t, _)| matches!(t, Tab::Priv(_))).map(|(_, v)| *v).collect();
            let g_val = mask.eval(&prev);
            let es = prev[n..].to_vec();
            out.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms: terms.clone() });
            (scalar, rho, es, terms, g_val)
        }
        Side::Verify { slots } => {
            let sp_ = slots.get(s).ok_or("token I/O: missing slot")?;
            if sp_.terms.len() != n_priv {
                return Err(format!("token I/O {}: slot {s} terminal count", sched.label));
            }
            tr.absorb_fp2(b"tk-scalar", &[sp_.scalar]);
            let claimed = def.hosted.iter().fold(sp_.scalar, |a, (hs, coef)| a.add(coef.mul(acc.scalars[*hs])));
            let (fin, rho_full) = sumcheck::verify(claimed, degree, n + ext, &sp_.sc, tr).map_err(|e| format!("{} slot {s:02} [{}]: {e}", sched.label, sp.name))?;
            let rho = rho_full[..n].to_vec();
            let es = rho_full[n..].to_vec();
            let sel = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
            let mut kk = 0usize;
            let vals: Vec<Fp2> = def
                .tabs
                .iter()
                .map(|t| match t {
                    Tab::Eq { point, start } => sel.mul(eq_point(point, &rho[*start..*start + point.len()])),
                    Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho)),
                    Tab::Priv(_) => {
                        kk += 1;
                        sp_.terms[kk - 1]
                    }
                })
                .collect();
            let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());
            (sp_.scalar, rho, es, sp_.terms.clone(), g_val)
        }
    };
    acc.order.push(format!("{} slot {s:02} scalar+rounds", sched.label));
    if es.iter().any(|e| e.is_zero() || *e == Fp2::ONE) {
        return Err("degenerate terminal mask challenge; discard attempt".into());
    }
    tr.absorb_fp2(b"tk-term", &terms);
    acc.order.push(format!("{} slot {s:02} terminals", sched.label));
    let cd = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
    let mut kk = 0usize;
    for t in &def.tabs {
        if let Tab::Priv(p) = t {
            let cm = es[p.ext_round + 1..].iter().fold(es[p.ext_round], |a, e| a.mul(Fp2::ONE.sub(*e)));
            acc.claims[p.cm as usize].push(build_claim(sched.row_log[p.cm as usize], p, &claim_point(p, &rho), cd, cm, terms[kk]));
            kk += 1;
        }
    }
    let mut rho_full = rho;
    rho_full.extend_from_slice(&es);
    let sum_w = |slot: usize| {
        let x = &sched.slots[slot];
        CfsMask::sum_weights(x.main + x.ext, x.degree)
    };
    match kind {
        SlotKind::Standalone => acc.fs.push(MaskFunctional { terms: vec![(s, sum_w(s).iter().map(|w| w.mul(c)).collect())], value: scalar }),
        SlotKind::Host => {
            let mut fterms = vec![(s, sum_w(s).iter().map(|w| w.mul(c)).collect::<Vec<Fp2>>())];
            for (hs, coef) in &def.hosted {
                let kc = coef.mul(acc.cs[*hs]).neg();
                fterms.push((*hs, sum_w(*hs).iter().map(|w| w.mul(kc)).collect()));
            }
            acc.host_fs.push(MaskFunctional { terms: fterms, value: scalar });
        }
        SlotKind::Private => {}
    }
    acc.fs.push(MaskFunctional { terms: vec![(s, CfsMask::eval_weights(&rho_full, degree))], value: g_val });
    acc.cs.push(c);
    acc.scalars.push(scalar);
    Ok(())
}

/// The slot builder (as `argument::B`): counts the claim sites each slot
/// pushes against the declared schedule.
pub(crate) struct SB<'a> {
    lay: &'a StageLayout,
    slot: usize,
    tabs: Vec<Tab>,
    ak: usize,
    hk: usize,
    iok: usize,
}

impl<'a> SB<'a> {
    pub(crate) fn new(lay: &'a StageLayout, slot: usize) -> Self {
        SB { lay, slot, tabs: Vec::new(), ak: 0, hk: 0, iok: 0 }
    }
    pub(crate) fn push(&mut self, t: Tab) -> usize {
        self.tabs.push(t);
        self.tabs.len() - 1
    }
    pub(crate) fn eq(&mut self, point: &[Fp2], start: usize) -> usize {
        self.push(Tab::Eq { point: point.to_vec(), start })
    }
    pub(crate) fn tabs_len(&self) -> usize {
        self.tabs.len()
    }
    pub(crate) fn public(&mut self, v: Vec<Fp2>) -> usize {
        self.push(Tab::Pub(v))
    }
    /// an A slice at `off` of `2^log` words read at `coords`
    pub(crate) fn a_slice(&mut self, off: usize, log: usize, coords: Vec<Coord>) -> Result<usize, String> {
        let mask_row = self.lay.a_site(self.slot, self.ak)?;
        self.ak += 1;
        Ok(self.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(off, Fp2::ONE)], log, coords, mask_row, ext_round: 0 })))
    }
    /// A plane `plane` read at `coords`
    pub(crate) fn a_at(&mut self, plane: usize, coords: Vec<Coord>) -> Result<usize, String> {
        let (off, log) = (self.lay.a_off[plane], self.lay.a_log[plane]);
        self.a_slice(off, log, coords)
    }
    /// A plane on its own domain (the slot's cube)
    pub(crate) fn a(&mut self, plane: usize) -> Result<usize, String> {
        let log = self.lay.a_log[plane];
        self.a_at(plane, rho(0..log))
    }
    pub(crate) fn h(&mut self, plane: usize) -> Result<usize, String> {
        let mask_row = self.lay.h_site(self.slot, self.hk)?;
        self.hk += 1;
        let (re, im) = self.lay.h_off[plane];
        let log = self.lay.h_log[plane];
        Ok(self.push(Tab::Priv(Priv { cm: Cm::H, slices: vec![(re, Fp2::ONE), (im, Fp2::U)], log, coords: rho(0..log), mask_row, ext_round: 0 })))
    }
    /// a claim on one of the stage's two IO commitments, at the reserved pair
    /// `mask_row` the RUN schedule gives it
    pub(crate) fn io(&mut self, cm: Cm, log: usize, coords: Vec<Coord>, mask_row: usize) -> usize {
        self.iok += 1;
        self.push(Tab::Priv(Priv { cm, slices: vec![(0, Fp2::ONE)], log, coords, mask_row, ext_round: 0 }))
    }
    pub(crate) fn finish(self, poly: Poly, hosted: Vec<(usize, Fp2)>) -> Result<StageSlotDef, String> {
        let sp = &self.lay.sched.slots[self.slot];
        if self.ak != sp.a_sites || self.hk != sp.h_sites || self.iok != sp.io_sites {
            return Err(format!(
                "token I/O {}: slot {} uses {} A / {} H / {} IO sites, the schedule declares {} / {} / {}",
                self.lay.sched.label, self.slot, self.ak, self.hk, self.iok, sp.a_sites, sp.h_sites, sp.io_sites
            ));
        }
        Ok(StageSlotDef { slot: self.slot, tabs: self.tabs, poly, hosted })
    }
}

/// `sum_k mu_k * (helper relation k)` over lookups given as `(table index
/// terms, constant)`: helper k covers lookups (2k, 2k + 1), an odd count
/// leaves the last single (`argument::helper_sum`)
pub(crate) fn helper_sum(v: &[Fp2], lks: &[(Vec<(usize, Fp)>, Fp2)], h0: usize, alpha: Fp2, mu: &[Fp2]) -> Fp2 {
    let den = |l: &(Vec<(usize, Fp)>, Fp2)| alpha.sub(l.0.iter().fold(l.1, |a, (i, c)| a.add(v[*i].mul_base(*c))));
    let mut accum = Fp2::ZERO;
    for kk in 0..lks.len().div_ceil(2) {
        let h = v[h0 + kk];
        let d1 = den(&lks[2 * kk]);
        let rel = match lks.get(2 * kk + 1) {
            Some(l2) => {
                let d2 = den(l2);
                h.mul(d1).mul(d2).sub(d1.add(d2))
            }
            None => h.mul(d1).sub(Fp2::ONE),
        };
        accum = accum.add(mu[kk].mul(rel));
    }
    accum
}

/// `sum_j zeta^j plane_j`
pub(crate) fn zeta_fold(v: &[Fp2], planes: &[usize], zeta: Fp2) -> Fp2 {
    let mut p = Fp2::ONE;
    let mut accum = Fp2::ZERO;
    for t in planes {
        accum = accum.add(p.mul(v[*t]));
        p = p.mul(zeta);
    }
    accum
}

/// the stage's slots, then the functional list in the declared order
/// (`[Gamma_s if standalone] eval_s ...`, host Gammas last)
pub(crate) fn finish_functionals(mut acc: Acc, lay: &StageLayout) -> Result<Acc, String> {
    let hosts = std::mem::take(&mut acc.host_fs);
    acc.fs.extend(hosts);
    if acc.fs.len() != lay.n_functionals() {
        return Err(format!("token I/O {}: functional count differs from the declared schedule", lay.sched.label));
    }
    Ok(acc)
}

// ---------------------------------------------------------------- openings

fn part_rows(p: &ZPart, n: usize) -> std::ops::Range<usize> {
    let r0 = p.slice.offset / n;
    r0..r0 + (1usize << p.slice.log_size).div_ceil(n)
}

/// A one-site token endpoint's claim schedule (`protocol::check_endpoint_opening`
/// at the token endpoint's own geometry: `data` rows, the terminal pair at
/// `(data, data + 1)`, the proximity row at `data + 2`).
pub(crate) fn check_token_endpoint_opening(claims: &[ZClaim], data: usize, n: usize, tr: &Transcript) -> Result<(), String> {
    let rows = data + super::endpoint_g::MASK_ROWS;
    let ok = claims.len() == 1
        && claims[0].parts.len() == 3
        && part_rows(&claims[0].parts[0], n) == (0..data)
        && part_rows(&claims[0].parts[1], n) == (data..data + 1)
        && part_rows(&claims[0].parts[2], n) == (data + 1..data + 2)
        && claims[0].parts.iter().all(|p| !p.coef.is_zero());
    if !ok {
        return Err("token I/O: a token endpoint claim differs from the declared schedule (one claim, its own terminal pair)".into());
    }
    let mut replay = Transcript::clone_state(tr);
    super::protocol::check_opening_challenges(&[1], rows, data + 2, || replay.challenge_fp2())
}

// ---------------------------------------------------------------- wire

/// one hiding opening's transport dimensions (`wire::Dim`)
#[derive(Clone, Copy, Debug)]
pub(crate) struct Dim {
    pub checks: usize,
    pub vec: usize,
    pub enc_cols: usize,
    pub path: usize,
}

impl Dim {
    pub(crate) fn of(p: &PcsParams) -> Dim {
        let n = 1usize << p.log_cols;
        let enc_cols = n * p.inv_rate;
        Dim { checks: p.num_col_checks, vec: n + p.num_col_checks, enc_cols, path: enc_cols.next_power_of_two().trailing_zeros() as usize }
    }
    pub(crate) fn opening_len(&self, groups: usize, rows: usize) -> usize {
        (groups + 1) * self.vec * 16 + self.checks * (8 + rows * 8 + 32 + self.path * 32)
    }
    pub(crate) fn ok(&self, o: &OpeningZk, groups: usize, rows: usize) -> bool {
        o.group_vecs.len() == groups
            && o.group_vecs.iter().all(|v| v.len() == self.vec)
            && o.prox_vec.len() == self.vec
            && o.columns.len() == self.checks
            && o.columns.iter().all(|(j, c, _, p)| *j < self.enc_cols && c.len() == rows && p.len() == self.path)
    }
}

pub(crate) const MASK_VEC: usize = 1024;
pub(crate) const MASK_DOM: usize = 4096;
pub(crate) const MASK_PATH: usize = 12;

/// The bytes of one NEW stage (IN or OUT): what it commits, its slots, its M
/// opening, its A and H openings, and the openings of the external / boundary
/// commitments it closes, in transcript order.
pub(crate) struct StageSegment {
    pub b_root: Option<Digest>,
    pub a_root: Digest,
    pub h_root: Digest,
    pub mask_root: Digest,
    pub slots: Vec<SlotProof>,
    pub mask_open: MaskOpening,
    pub a_open: OpeningZk,
    pub h_open: OpeningZk,
    pub closes: Vec<OpeningZk>,
}

/// The geometry of a stage segment: every number from the verifier's own
/// statement, none from a frame.
pub(crate) struct StageSegGeom<'a> {
    pub magic: &'static [u8; 8],
    pub lay: &'a StageLayout,
    pub has_b_root: bool,
    pub a_groups: usize,
    pub h_groups: usize,
    /// `(dims, groups, rows)` of each closing opening, in order
    pub closes: Vec<(Dim, usize, usize)>,
    pub total: usize,
    pub index: usize,
}

pub(crate) const SEG_HEADER: usize = 8 + 32 + 8 + 8 + 32;
pub(crate) const SEG_TRAILER: usize = 32;

impl StageSegGeom<'_> {
    pub(crate) fn len(&self) -> usize {
        let bd = Dim::of(&self.lay.params);
        let slots: usize = self.lay.sched.slots.iter().map(|s| (1 + (s.main + s.ext) * (s.degree + 1) + s.terms()) * 16).sum();
        let mask = 2 * MASK_VEC * 16 + bd.checks * (8 + self.lay.m_rows() * 8 + 32 + MASK_PATH * 32);
        SEG_HEADER
            + usize::from(self.has_b_root) * 32
            + 3 * 32
            + slots
            + mask
            + bd.opening_len(self.a_groups, self.lay.a_rows)
            + bd.opening_len(self.h_groups, self.lay.h_rows)
            + self.closes.iter().map(|(d, g, r)| d.opening_len(*g, *r)).sum::<usize>()
            + SEG_TRAILER
    }

    fn validate(&self, s: &StageSegment) -> Result<(), String> {
        let bd = Dim::of(&self.lay.params);
        let lay = self.lay;
        if s.slots.len() != lay.sched.slots.len() {
            return Err("token I/O wire: slot count".into());
        }
        for (i, sp) in s.slots.iter().enumerate() {
            let x = &lay.sched.slots[i];
            if sp.sc.rounds.len() != x.main + x.ext || sp.sc.rounds.iter().any(|r| r.len() != x.degree + 1) || sp.terms.len() != x.terms() {
                return Err("token I/O wire: argument shape".into());
            }
        }
        if s.b_root.is_some() != self.has_b_root || s.closes.len() != self.closes.len() {
            return Err("token I/O wire: this segment's parts are not the run schedule's".into());
        }
        let m = &s.mask_open;
        if m.q.len() != MASK_VEC
            || m.prox.len() != MASK_VEC
            || m.columns.len() != bd.checks
            || m.columns.iter().any(|(j, c, _, p)| *j >= MASK_DOM || c.len() != lay.m_rows() || p.len() != MASK_PATH)
            || !bd.ok(&s.a_open, self.a_groups, lay.a_rows)
            || !bd.ok(&s.h_open, self.h_groups, lay.h_rows)
            || s.closes.iter().zip(self.closes.iter()).any(|(o, (d, g, r))| !d.ok(o, *g, *r))
        {
            return Err("token I/O wire: opening shape".into());
        }
        Ok(())
    }

    pub(crate) fn encode(&self, s: &StageSegment, binding: &Digest, start_tag: &[u8; 32], end_tag: &[u8; 32]) -> Result<Vec<u8>, String> {
        self.validate(s)?;
        let len = self.len();
        let mut out = Vec::with_capacity(len);
        out.extend_from_slice(self.magic);
        out.extend_from_slice(binding);
        out.extend_from_slice(&(self.total as u64).to_le_bytes());
        out.extend_from_slice(&(self.index as u64).to_le_bytes());
        out.extend_from_slice(start_tag);
        if let Some(r) = &s.b_root {
            out.extend_from_slice(r);
        }
        for root in [&s.a_root, &s.h_root, &s.mask_root] {
            out.extend_from_slice(root);
        }
        for sp in &s.slots {
            out.extend_from_slice(&sp.scalar.to_bytes());
            sp.sc.write_bytes(&mut out);
            for t in &sp.terms {
                out.extend_from_slice(&t.to_bytes());
            }
        }
        s.mask_open.write_bytes(&mut out);
        s.a_open.write_bytes(&mut out);
        s.h_open.write_bytes(&mut out);
        for o in &s.closes {
            o.write_bytes(&mut out);
        }
        out.extend_from_slice(end_tag);
        if out.len() != len {
            return Err(format!("token I/O wire: segment {} is {} B, the counted length is {len}", self.index, out.len()));
        }
        Ok(out)
    }

    pub(crate) fn decode(&self, bytes: &[u8], binding: &Digest, start_tag: &[u8; 32]) -> Result<(StageSegment, [u8; 32]), String> {
        let len = self.len();
        if bytes.len() != len {
            return Err(format!("token I/O wire: segment {} is {} B, the counted length is {len}", self.index, bytes.len()));
        }
        let bd = Dim::of(&self.lay.params);
        let mut r = Reader { bytes, pos: 0 };
        if &r.take::<8>()? != self.magic {
            return Err(format!("token I/O wire: segment {} is not a {} segment", self.index, String::from_utf8_lossy(self.magic)));
        }
        if &r.take::<32>()? != binding {
            return Err("token I/O wire: this segment belongs to another run".into());
        }
        if u64::from_le_bytes(r.take::<8>()?) != self.total as u64 || u64::from_le_bytes(r.take::<8>()?) != self.index as u64 {
            return Err(format!("token I/O wire: segment {} is not this run's segment {} of {}", self.index, self.index, self.total));
        }
        if &r.take::<32>()? != start_tag {
            return Err(format!("token I/O wire: segment {}'s header is not the verifier's own transcript position", self.index));
        }
        let b_root = if self.has_b_root { Some(r.take::<32>()?) } else { None };
        let (a_root, h_root, mask_root) = (r.take::<32>()?, r.take::<32>()?, r.take::<32>()?);
        let mut slots = Vec::with_capacity(self.lay.sched.slots.len());
        for x in &self.lay.sched.slots {
            let scalar = r.fp2()?;
            let rounds = (0..x.main + x.ext).map(|_| r.fp2_vec(x.degree + 1)).collect::<Result<Vec<_>, String>>()?;
            let terms = r.fp2_vec(x.terms())?;
            slots.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms });
        }
        let q = r.fp2_vec(MASK_VEC)?;
        let prox = r.fp2_vec(MASK_VEC)?;
        let columns = (0..bd.checks).map(|_| r.column(self.lay.m_rows(), MASK_DOM, MASK_PATH)).collect::<Result<Vec<_>, String>>()?;
        let mask_open = MaskOpening { q, prox, columns };
        let a_open = r.hiding(bd, self.a_groups, self.lay.a_rows)?;
        let h_open = r.hiding(bd, self.h_groups, self.lay.h_rows)?;
        let closes = self.closes.iter().map(|(d, g, rw)| r.hiding(*d, *g, *rw)).collect::<Result<Vec<_>, String>>()?;
        let end_tag = r.take::<32>()?;
        if r.pos != bytes.len() {
            return Err("token I/O wire: trailing bytes".into());
        }
        let seg = StageSegment { b_root, a_root, h_root, mask_root, slots, mask_open, a_open, h_open, closes };
        self.validate(&seg)?;
        Ok((seg, end_tag))
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl Reader<'_> {
    fn take<const K: usize>(&mut self) -> Result<[u8; K], String> {
        let end = self.pos.checked_add(K).filter(|e| *e <= self.bytes.len()).ok_or("token I/O wire: truncated segment")?;
        let out: [u8; K] = self.bytes[self.pos..end].try_into().map_err(|_| "token I/O wire: truncated segment")?;
        self.pos = end;
        Ok(out)
    }
    fn fp(&mut self) -> Result<Fp, String> {
        let v = u64::from_le_bytes(self.take()?);
        if v >= P {
            return Err("token I/O wire: noncanonical field word".into());
        }
        Ok(Fp(v))
    }
    fn fp2(&mut self) -> Result<Fp2, String> {
        Ok(Fp2::new(self.fp()?, self.fp()?))
    }
    fn fp2_vec(&mut self, n: usize) -> Result<Vec<Fp2>, String> {
        (0..n).map(|_| self.fp2()).collect()
    }
    fn column(&mut self, rows: usize, bound: usize, path: usize) -> Result<(usize, Vec<Fp>, [u8; 32], Vec<Digest>), String> {
        let j = u64::from_le_bytes(self.take()?);
        if j >= bound as u64 {
            return Err("token I/O wire: column index".into());
        }
        let col = (0..rows).map(|_| self.fp()).collect::<Result<Vec<Fp>, String>>()?;
        let salt = self.take::<32>()?;
        let path = (0..path).map(|_| self.take::<32>()).collect::<Result<Vec<Digest>, String>>()?;
        Ok((j as usize, col, salt, path))
    }
    fn hiding(&mut self, d: Dim, groups: usize, rows: usize) -> Result<OpeningZk, String> {
        let group_vecs = (0..groups).map(|_| self.fp2_vec(d.vec)).collect::<Result<Vec<_>, String>>()?;
        let prox_vec = self.fp2_vec(d.vec)?;
        let columns = (0..d.checks).map(|_| self.column(rows, d.enc_cols, d.path)).collect::<Result<Vec<_>, String>>()?;
        Ok(OpeningZk { group_vecs, prox_vec, columns })
    }
}

// ---------------------------------------------------------------- the owner check

/// What the prover hands an endpoint's OWNER over a private channel (DESIGN
/// 3.4, D25 T5, C-5): every committed row, each row's 256 pad coefficients and
/// every Merkle leaf salt. A private artifact: never in a published bundle (D21).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Decommitment {
    pub data: Vec<Fp>,
    pub pads: Vec<Fp>,
    pub salts: Vec<[u8; 32]>,
}

/// **`owner_check` (DESIGN 3.4; R0's `owner_check_*` semantics on the real
/// commitment).** Re-encodes the decommitted rows at the token endpoint's
/// derived geometry (row width 2^8, rate 1/8, `data + 5` rows, 256 pads per
/// row), rebuilds the root under the profile's hash tag and compares it with
/// the root of the accepted receipt. Refuses any decommitment of another
/// shape. Returns the plane words on success. No proof work.
pub(crate) fn owner_rebuild_root(spec: &super::endpoint_g::EndpointSpecG, root: &Digest, dec: &Decommitment, tag: &zkp_core::hashtag::HashTag) -> Result<Vec<Fp>, String> {
    let params = spec.params();
    let n = 1usize << params.log_cols;
    let nn = n * params.inv_rate;
    let rows = spec.commitment_rows();
    let q = params.num_col_checks;
    if dec.data.len() != rows * n || dec.pads.len() != rows * q || dec.salts.len() != nn {
        return Err(format!("owner check: the decommitment is not of the endpoint's derived geometry ({rows} rows of {n} words, {q} pads per row, {nn} salts)"));
    }
    if dec.data.iter().chain(dec.pads.iter()).any(|x| x.0 >= P) {
        return Err("owner check: a noncanonical word in the decommitment".into());
    }
    let ntt = crate::ntt::NttTables::new(spec.enc_log());
    let pows = zkp_core::pcs::coset_powers(Fp::new(7), nn);
    let mut encoded = vec![Fp::ZERO; rows * nn];
    for r in 0..rows {
        zkp_core::pcs::encode_row_zk(&ntt, &dec.data[r * n..(r + 1) * n], &dec.pads[r * q..(r + 1) * q], &pows, &mut encoded[r * nn..(r + 1) * nn]);
    }
    let leaves = zkp_core::pcs::hash_columns_keyed(&encoded, rows, nn, tag.column_key());
    let salted: Vec<Digest> = leaves.iter().zip(dec.salts.iter()).map(|(l, s)| zkp_core::pcs::salt_leaf_keyed(l, s, tag.leaf_key())).collect();
    let tree = crate::merkle::MerkleTree::build_keyed(salted, tag.node_key());
    if tree.root() != *root {
        return Err("owner check: the decommitment does not rebuild the receipt's root".into());
    }
    Ok(dec.data[..spec.len()].to_vec())
}
