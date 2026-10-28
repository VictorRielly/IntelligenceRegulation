//! **TOKEN I/O ROUND 12: THE CLASSIFIER VARIANT** (`results/zk60_token_io_r1_20261017/classifier/
//! DESIGN_CLASSIFIER.md` v2, rung R-C1). ONE private run under ONE transcript:
//!
//! ```text
//! [stage IN-C] -> B_in -> block 0 -> ... -> block L-1 -> B_out -> [stage OUT-C]
//! ```
//!
//! * stage IN-C ([`super::stage_in_c`]): stage IN plus the PUBLIC TEMPLATE
//!   clause (every template position pinned to its public id, its own fresh
//!   coefficient) and the CONTROL-ID column (`beta^2 ctl` in the lookup tuple:
//!   a content position never carries a control id; B-2);
//! * the blocks: unchanged;
//! * stage OUT-C ([`super::stage_out_c`]): the final norm on `B_out` row
//!   `T - 1`, the margin `Delta = y . w_Delta` through ONE public int16
//!   difference row (B-3 / C-11), five byte limbs of `delta = sigma (Delta - c)
//!   - b`, and the **PUBLIC verdict bit** `b` (absorbed by the statement's
//!   transcript). No output endpoint.
//!
//! The parts that wait for Victor's rulings are the [`RULING_B4_FAIL_CLOSED`],
//! [`RULING_B5_N_PUBLIC`], [`RULING_B6_FIXED_POLICY_LIST`] and
//! [`RULING_B8_BINDING`] switches, set to the design's recommended defaults and
//! written into the profile's canonical text. Not a privacy claim; not a
//! registered production profile beyond the development rung; the frozen
//! next-token run (D36) is untouched: everything here is new code under new
//! profile strings.

use super::super::boundary::BoundarySpec;
use super::super::endpoint_g::{self, EndpointRole, EndpointSpecG};
use super::super::layout::Layout;
use super::super::protocol;
use super::super::run::{RunShape, CLASSIFY_RUN_PROFILES};
use super::super::shape::NormCalibration;
use super::super::trained_statement::{apply_own, cal_field, has_own, TrainedModelStatement, OWN_FIELDS};
use super::super::wire::{self, SegGeom};
use super::run::{block_logup_size, WholeRun, PCS_FIELD_PER_OPENING_LOG2, SUMCHECK_PER_STAGE_LOG2};
use super::*;
use crate::ntt::NttTables;
use crate::pcs::CommittedZk;

// ---------------------------------------------------------------- the ruling switches

/// **B-5 (Victor, pending): the exact content length `n` is public** (the
/// public-row variant: `T = P0 + n + S` is in the statement). The
/// hidden-length variant (in-circuit length binding, design §3.4 option H) is
/// not built; `false` is refused by name.
pub(crate) const RULING_B5_N_PUBLIC: bool = true;
/// **B-6 (Victor, pending): policies come only from the fixed, pre-registered
/// list** ([`registered_policies`]), one threshold `c` each (a profile
/// constant, never a per-run choice).
pub(crate) const RULING_B6_FIXED_POLICY_LIST: bool = true;
/// **B-8 (Victor, pending; the D23 amendment): the proof is bound to its item
/// through the input endpoint root** and the input owner's decommitment check
/// (design §6.1); option S (seeded endpoint randomness) is not built.
pub(crate) const RULING_B8_BINDING: &str = "input-endpoint-root";
/// **B-4 (Victor, pending): fail-closed** — an item without an accepted proof
/// is handled exactly as flagged; the CLI says so on every refusal.
pub(crate) const RULING_B4_FAIL_CLOSED: bool = true;

/// the switches' canonical text (bound through the profile text)
pub(crate) fn rulings_text() -> String {
    format!(
        "rulings: B-5 n-public={} B-6 fixed-policy-list={} B-8 binding={} B-4 fail-closed={} (recommended defaults, pending Victor)",
        RULING_B5_N_PUBLIC, RULING_B6_FIXED_POLICY_LIST, RULING_B8_BINDING, RULING_B4_FAIL_CLOSED
    )
}

/// only the recommended defaults are built; any other setting is refused by name
pub(crate) fn rulings_are_built() -> Result<(), String> {
    if !RULING_B5_N_PUBLIC {
        return Err("classifier: the hidden-length variant (B-5 = hidden) is not built (design §3.4 option H)".into());
    }
    if !RULING_B6_FIXED_POLICY_LIST {
        return Err("classifier: free-text policies (B-6 off) are not built: one fixed, pre-registered list".into());
    }
    if RULING_B8_BINDING != "input-endpoint-root" {
        return Err(format!("classifier: binding {RULING_B8_BINDING:?} is not built (only the input endpoint root)"));
    }
    if !RULING_B4_FAIL_CLOSED {
        return Err("classifier: only the fail-closed app rule is built (B-4)".into());
    }
    Ok(())
}

// ---------------------------------------------------------------- the policy list (B-6)

/// One pre-registered policy: the public template around the content, the
/// control-id class of its tokenizer, the verdict tokens and the threshold.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct Policy {
    pub id: String,
    /// positions `0 .. P0` (BOS first)
    pub prefix: Vec<u64>,
    /// the last `S` positions
    pub suffix: Vec<u64>,
    /// `ctl(v) = 1` exactly for `v < num_special` (tekken: 1000)
    pub num_special: u64,
    pub yes: u64,
    pub no: u64,
    /// the threshold (flagged iff `Delta > c`), a profile constant
    pub c: i64,
    /// the canonical tokenizer, named (B-2: plain-text encoding, by digest)
    pub tokenizer: String,
    /// the vocabulary the policy's ids are of
    pub v: usize,
}

/// the development rung's synthetic policy (its ids are the CLI fixture's
/// prompt layout: positions 0..8 template, 8..31 content, 31 suffix)
pub(crate) fn policy_rung_dev() -> Policy {
    Policy { id: "rung-tc-synthetic-policy-dev/1".into(), prefix: (1..=8).collect(), suffix: vec![32], num_special: 5, yes: 40, no: 41, c: 0, tokenizer: "synthetic (ids only, no text)".into(), v: 300 }
}

/// Shieldstral-1.0-3B with the card's 7-category template (R-C0's pinned ids,
/// `classifier/rc0/template_ids.json`: P0 = 84 ending at `>:`, suffix
/// `[/INST]`; tekken plain-text encoding, `num_special_tokens` 1000; yes 13059,
/// no 2649; tau 0.5 so c = 0). Its block shape lands with the native lane's
/// F1-F3; until then no run profile admits it.
pub(crate) fn policy_shieldstral_card() -> Policy {
    Policy {
        id: "shieldstral-1.0-3b-card-unsafe/1".into(),
        prefix: vec![
            1, 17, 1074, 45463, 5627, 1278, 23762, 37005, 1278, 13795, 4057, 1408, 1278, 27356, 1321, 1278, 83779, 5662, 1046, 13708, 1455, 1278, 4832, 1710, 2342, 1402, 1429, 13059, 1034, 1505, 1429, 2649, 3871, 18, 3, 1060, 1785, 8166, 72067, 3213, 1584, 1261, 15851, 12216, 11673, 2412,
            70468, 18191, 51049, 4701, 1046, 63882, 1261, 4253, 27710, 13472, 5669, 16988, 1044, 31483, 16181, 1044, 11649, 4701, 1044, 2585, 5352, 3802, 1044, 1321, 18886, 5177, 1338, 1060, 7087, 72067, 3316, 1593, 4701, 58624, 2634, 1060, 16060, 72067,
        ],
        suffix: vec![4],
        num_special: 1000,
        yes: 13059,
        no: 2649,
        c: 0,
        tokenizer: "tekken.json sha256 ceb11e85e44d7c91 (plain-text encoding, no special-token parsing)".into(),
        v: 131_072,
    }
}

#[cfg(test)]
thread_local! {
    /// test-only extra policies (the tie and threshold controls)
    static TEST_POLICIES: std::cell::RefCell<Vec<Policy>> = const { std::cell::RefCell::new(Vec::new()) };
}

/// test-only: register an extra policy on this thread
#[cfg(test)]
pub(crate) fn register_test_policy(p: Policy) {
    TEST_POLICIES.with(|t| t.borrow_mut().push(p));
}

/// **THE PRE-REGISTERED POLICY LIST (B-6).**
pub(crate) fn registered_policies() -> Vec<Policy> {
    #[allow(unused_mut)]
    let mut v = vec![policy_rung_dev(), policy_shieldstral_card()];
    #[cfg(test)]
    TEST_POLICIES.with(|t| v.extend(t.borrow().iter().cloned()));
    v
}

pub(crate) fn policy_by_id(id: &str) -> Result<Policy, String> {
    registered_policies().into_iter().find(|p| p.id == id).ok_or_else(|| format!("classifier: {id:?} is not a pre-registered policy (B-6)"))
}

// ---------------------------------------------------------------- D41: chunks

/// **D41 (DESIGN v2.2 §13): each classifier run profile's chunk overlap.**
/// A policy's chunk size is `T - P0 - S` (every chunk proof at the profile's
/// T); the overlap is ONE public constant per deployment profile, never
/// chosen per item (the spirit of O-1).
pub(crate) const CHUNK_OVERLAPS: [(&str, usize); 1] = [(super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC, 4)];

pub(crate) fn chunk_overlap_of(run_profile: &str) -> Result<usize, String> {
    CHUNK_OVERLAPS.iter().find(|(p, _)| *p == run_profile).map(|(_, o)| *o).ok_or_else(|| format!("classifier: no chunk overlap is registered for the run profile {run_profile} (D41)"))
}

/// a deployment profile's chunk plan (public)
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ChunkPlan {
    pub size: usize,
    pub overlap: usize,
}

/// **THE SPLIT (§13.1):** `total` content ids into chunks of exactly
/// `plan.size` ids at stride `size - overlap`, the last chunk END-ALIGNED
/// (`[total - size, total)`, its overlap with the previous one >= overlap).
/// Short content (`total < size`) is refused by name: not built in R-C1.
pub(crate) fn chunk_ranges(total: usize, plan: ChunkPlan) -> Result<Vec<(usize, usize)>, String> {
    if plan.size == 0 || plan.overlap >= plan.size {
        return Err(format!("classifier chunks: the plan (size {}, overlap {}) needs 0 <= overlap < size", plan.size, plan.overlap));
    }
    if total < plan.size {
        return Err(format!("classifier chunks: a content of {total} ids is shorter than one chunk of {} ids; short content is not built (DESIGN v2.2 §13.1: T < T_pad or the trailing-pad route)", plan.size));
    }
    let stride = plan.size - plan.overlap;
    let k = 1 + (total - plan.size).div_ceil(stride);
    Ok((0..k).map(|j| if j + 1 < k { (j * stride, j * stride + plan.size) } else { (total - plan.size, total) }).collect())
}

/// **A chunk proof's public place in its item** (§13.3): absorbed into the
/// transcript (`classify-chunk`) and rendered in the statement; DERIVED from
/// (total, index, plan), never taken as given
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ChunkRef {
    pub index: usize,
    pub count: usize,
    pub a: usize,
    pub b: usize,
    pub total: usize,
    pub size: usize,
    pub overlap: usize,
}

impl ChunkRef {
    pub(crate) fn derive(total: usize, index: usize, plan: ChunkPlan) -> Result<ChunkRef, String> {
        let r = chunk_ranges(total, plan)?;
        let (a, b) = *r.get(index).ok_or_else(|| format!("classifier chunks: chunk {index} of a {total}-id content (the plan gives {} chunks)", r.len()))?;
        Ok(ChunkRef { index, count: r.len(), a, b, total, size: plan.size, overlap: plan.overlap })
    }
    pub(crate) fn bytes(&self) -> Vec<u8> {
        [self.index, self.count, self.a, self.b, self.total, self.size, self.overlap].iter().flat_map(|v| (*v as u64).to_le_bytes()).collect()
    }
}

/// **ROUND 12 (the registry gates s24 / s25 / s33): every registered
/// classifier run profile with its block shape** (test only; the classifier
/// run profiles are not token runs, so they have their own list beside
/// `registered_token_runs`)
#[cfg(test)]
pub(crate) fn registered_classify_runs() -> Vec<(&'static str, Shape)> {
    vec![(super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC, Shape::rung_tc(&super::super::trained_calib_tests::rung_tc_calibration()).expect("the trained-calibration rung"))]
}

/// **s25's census statement of a classifier run profile at `l` blocks**: one
/// synthetic block standing for all `L` (only its digest and record enter the
/// statement), a generic embedding and margin vector, the profile's policy
/// (test only)
#[cfg(test)]
pub(crate) fn census_classify_statement(profile: &'static str, l: usize) -> (ClassifyRunStatement, TrainedModelStatement, ClassifierTables) {
    use super::tests::{blocks, ctx, generic_tables, model_of_one, norm};
    let (sh, policy) = match profile {
        super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC => (registered_classify_runs().remove(0).1, policy_rung_dev()),
        _ => panic!("census_classify_statement: {profile} is not a registered classifier run profile"),
    };
    let tt = generic_tables(sh.width, 0x636c_6173);
    let w: Vec<i16> = (0..sh.width).map(|i| (i as i16 % 2000) - 1000).collect();
    let tables = ClassifierTables::new(tt.v, tt.d, tt.emb, w).expect("the census classifier tables");
    let blk = blocks(&sh, 1).remove(0);
    let model = model_of_one(&sh, &blk, l, profile);
    let digest = blk.digest();
    drop(blk);
    let n = sh.tokens - policy.prefix.len() - policy.suffix.len();
    let st = ClassifyRunStatement::new(RunShape::new(sh, l, profile).expect("the classifier run shape"), ctx(), vec![digest; l], &model, &tables, 1, norm(), &policy, n, Tier::R1_MVP, [7u8; 32], 1).expect("the census classifier statement");
    (st, model, tables)
}

// ---------------------------------------------------------------- the public tables

/// The classifier's public tables: the int16 embedding (`V x d`, as the token
/// run's) and the int16 MARGIN VECTOR `w_Delta` (`d` words): the quantised
/// difference of the yes and no head rows, one scale (design §4.1 item 3).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct ClassifierTables {
    pub v: usize,
    pub d: usize,
    pub emb: Vec<i16>,
    pub w_delta: Vec<i16>,
}

impl ClassifierTables {
    pub(crate) fn new(v: usize, d: usize, emb: Vec<i16>, w_delta: Vec<i16>) -> Result<ClassifierTables, String> {
        if emb.len() != v * d || w_delta.len() != d {
            return Err(format!("classifier tables: the embedding has {} words (V x d = {}) and the margin vector {} (d = {d})", emb.len(), v * d, w_delta.len()));
        }
        Ok(ClassifierTables { v, d, emb, w_delta })
    }
    pub(crate) fn emb_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/embedding-int16/v1");
        h.update(&(self.v as u64).to_le_bytes());
        h.update(&(self.d as u64).to_le_bytes());
        for w in &self.emb {
            h.update(&w.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }
    pub(crate) fn w_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/margin-vector-int16/v1");
        h.update(&(self.d as u64).to_le_bytes());
        for w in &self.w_delta {
            h.update(&w.to_le_bytes());
        }
        *h.finalize().as_bytes()
    }
    pub(crate) fn emb_row(&self, tok: usize) -> &[i16] {
        &self.emb[tok * self.d..(tok + 1) * self.d]
    }
    /// `E~(v, r)` for every true row (the verifier's O(V d) fold; parallel,
    /// exact field addition, as `TokenTables::emb_fold`)
    pub(crate) fn emb_fold(&self, r: &[Fp2]) -> Vec<Fp2> {
        use rayon::prelude::*;
        let e = eq_table_msb(r);
        (0..self.v)
            .into_par_iter()
            .map(|v| self.emb_row(v).iter().zip(e.iter()).fold(Fp2::ZERO, |a, (w, c)| if *w == 0 { a } else { a.add(c.mul_base(Fp::from_i64(i64::from(*w)))) }))
            .collect()
    }
    /// the integer margin `Delta = sum_i y_i w_i`
    pub(crate) fn margin(&self, y: &[i64]) -> i64 {
        self.w_delta.iter().zip(y.iter()).map(|(w, a)| i64::from(*w) * a).sum()
    }
}

// ---------------------------------------------------------------- the profile (the door)

/// the threshold's declared class `|c| <= 2^33` (design §4.1 item 4)
pub(crate) const C_MAX: i64 = 1 << 33;
/// where the margin limbs live inside the isqrt-limb plane `Lo` (its live
/// isqrt sub-planes end at entry 17)
pub(crate) const LAM_BASE: usize = 32;

/// Every public constant the classifier stages read, validated at ONE door on
/// both sides (the D24 F-1 rule: each exportable constant has a declared
/// class; the limb count is DERIVED).
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct ClassifierProfile {
    pub v: usize,
    pub v_pad: usize,
    pub log_v: usize,
    pub d: usize,
    pub d_pad: usize,
    pub tokens: usize,
    pub t_pad: usize,
    pub bos: u64,
    pub norm: FinalNorm,
    pub wrho: u32,
    pub d_max: i128,
    /// the margin's byte limbs `ceil(window / 8)` (TF-1)
    pub limbs: usize,
    pub window_bits: u32,
    pub emb_digest: Digest,
    pub w_digest: Digest,
    pub policy: Policy,
    /// the content length (public: B-5)
    pub n: usize,
    pub tier: Tier,
}

impl ClassifierProfile {
    /// **THE CLASSIFIER DOOR.** Refuses by name every constant outside its
    /// class, on the prover's AND the verifier's side.
    pub(crate) fn new(sh: &Shape, tables: &ClassifierTables, bos: u64, norm: FinalNorm, policy: &Policy, n: usize, tier: Tier) -> Result<ClassifierProfile, String> {
        rulings_are_built()?;
        tier.check()?;
        if !registered_policies().contains(policy) {
            return Err(format!("classifier: the policy {:?} is not the pre-registered one of that name (B-6)", policy.id));
        }
        let v = tables.v;
        if tables.d != sh.width {
            return Err(format!("classifier: the tables are {} wide, the block width is {}", tables.d, sh.width));
        }
        if v != policy.v {
            return Err(format!("classifier: the policy {:?} is for V = {}, the tables have V = {v}", policy.id, policy.v));
        }
        if !(2..=V_MAX).contains(&v) {
            return Err(format!("classifier: V = {v} is outside its declared class 2..=2^17"));
        }
        // the margin vector's class: int16 without -32768 (|w| <= 32767)
        if tables.w_delta.contains(&i16::MIN) {
            return Err("classifier: a margin-vector word is -32768, outside its declared class [-32767, 32767]".into());
        }
        if bos >= v as u64 || policy.prefix.first() != Some(&bos) {
            return Err("classifier: the policy's first template id must be the profile's BOS, an id below V".into());
        }
        if policy.suffix.is_empty() {
            return Err("classifier: the template has no suffix (the verdict row T - 1 is the suffix's last position)".into());
        }
        let verdict_ids = [policy.yes, policy.no];
        let mut ids = policy.prefix.iter().chain(policy.suffix.iter()).chain(verdict_ids.iter());
        if ids.any(|x| *x >= v as u64) || policy.yes == policy.no {
            return Err("classifier: a template or verdict id outside the vocabulary, or yes = no".into());
        }
        if policy.num_special == 0 || policy.num_special >= v as u64 {
            return Err("classifier: the control-id class [0, num_special) must be nonempty and below V".into());
        }
        if !(-C_MAX..=C_MAX).contains(&policy.c) {
            return Err(format!("classifier: the threshold c = {} is outside its declared class [-2^33, 2^33]", policy.c));
        }
        if n == 0 || policy.prefix.len() + n + policy.suffix.len() != sh.tokens {
            return Err(format!("classifier: P0 + n + S = {} + {n} + {} must equal the block's T = {} (public-row variant, n >= 1)", policy.prefix.len(), policy.suffix.len(), sh.tokens));
        }
        // the final norm: exactly the token profile's classes and window
        if !(1..=127).contains(&norm.g0) || !(1..=CN_F_MAX).contains(&norm.cn) || !(1..=CEPS_F_MAX).contains(&norm.ceps) || !TN_F_RANGE.contains(&norm.tn) {
            return Err("classifier: a final-norm constant is outside its class (g0 [1,127], Cn [1,2^20], Ceps [1,2^40], tn 1..=16)".into());
        }
        let (d, d_pad) = (sh.width, sh.d_pad);
        let d_max = isqrt_i128(i128::from(norm.ceps) + d as i128 * 32768 * 32768);
        if 2 * d_max >= 1i128 << (8 * LIMBS_ISQRT) {
            return Err("classifier: the final norm's D_max leaves the three isqrt byte limbs".into());
        }
        let wrho = norm.tn + 1 + bit_length(d_max);
        if wrho != 8 * NORM_LIMBS as u32 {
            return Err(format!("classifier: the final norm's remainder window is {wrho} bits; the plane list is pinned at exactly 32 (D24; Ceps < 2^40)"));
        }
        // the margin window over the WHOLE classes: d 127 32767 + c_max + 1
        let top = d as i128 * 127 * 32767 + i128::from(C_MAX) + 1;
        let window_bits = bit_length(top);
        let limbs = (window_bits as usize).div_ceil(8);
        if (1u128 << (8 * limbs)) + (1u128 << window_bits) + C_MAX as u128 >= u128::from(P) / 2 {
            return Err("classifier: the margin limbs and window wrap the field".into());
        }
        let v_pad = v.next_power_of_two();
        let log_v = clog2(v_pad);
        let lt = tier.stage_log_n;
        let ti_log = clog2(sh.t_pad).max(lt);
        if clog2(sh.t_pad.max(tier.ep_n())) > ti_log {
            return Err("classifier: the input token endpoint is wider than the position domain".into());
        }
        if clog2(d_pad).max(lt) > MAX_DOM_LOG || log_v.max(lt) > MAX_DOM_LOG {
            return Err(format!("classifier: a stage domain exceeds 2^{MAX_DOM_LOG} words"));
        }
        if LAM_BASE + limbs > 1usize << clog2(2 * 3 * LIMBS_ISQRT).max(lt) {
            return Err("classifier: the margin limbs do not fit the isqrt-limb domain".into());
        }
        Ok(ClassifierProfile {
            v,
            v_pad,
            log_v,
            d,
            d_pad,
            tokens: sh.tokens,
            t_pad: sh.t_pad,
            bos,
            norm,
            wrho,
            d_max,
            limbs,
            window_bits,
            emb_digest: tables.emb_digest(),
            w_digest: tables.w_digest(),
            policy: policy.clone(),
            n,
            tier,
        })
    }

    pub(crate) fn p0(&self) -> usize {
        self.policy.prefix.len()
    }
    /// is position `t` a template position (prefix or suffix)?
    pub(crate) fn is_template(&self, t: usize) -> bool {
        t < self.p0() || (t >= self.p0() + self.n && t < self.tokens)
    }
    /// the public template id at `t` (0 at content and pad positions)
    pub(crate) fn kappa(&self, t: usize) -> u64 {
        if t < self.p0() {
            self.policy.prefix[t]
        } else if t >= self.p0() + self.n && t < self.tokens {
            self.policy.suffix[t - self.p0() - self.n]
        } else {
            0
        }
    }
    /// `ctl(v)`: a control id of the policy's tokenizer
    pub(crate) fn ctl(&self, v: u64) -> bool {
        v < self.policy.num_special
    }
    /// the query's public control column: `ctl(kappa(t))` at template
    /// positions, 0 at content and pad positions
    pub(crate) fn ctl_q(&self, t: usize) -> bool {
        self.is_template(t) && self.ctl(self.kappa(t))
    }

    // ---- the stage domains (the token run's, the P-3 lift)
    pub(crate) fn ti_log(&self) -> usize {
        clog2(self.t_pad).max(self.tier.stage_log_n)
    }
    pub(crate) fn voc_log(&self) -> usize {
        self.log_v.max(self.tier.stage_log_n)
    }
    pub(crate) fn lo_log(&self) -> usize {
        clog2(2 * 3 * LIMBS_ISQRT).max(self.tier.stage_log_n)
    }
    pub(crate) fn do_log(&self) -> usize {
        clog2(self.d_pad).max(self.tier.stage_log_n)
    }
    pub(crate) fn tab_log(&self) -> usize {
        clog2(U8_LEN).max(self.tier.stage_log_n)
    }
    pub(crate) fn in_ep_words(&self) -> usize {
        self.t_pad.max(self.tier.ep_n())
    }

    fn template_digest(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/template/v1");
        for part in [&self.policy.prefix, &self.policy.suffix] {
            h.update(&(part.len() as u64).to_le_bytes());
            for x in part {
                h.update(&x.to_le_bytes());
            }
        }
        *h.finalize().as_bytes()
    }

    /// the canonical text, absorbed through the run's parameter line and
    /// calibration identity (the ruling switches included)
    pub(crate) fn describe_under(&self, run_profile: &str) -> String {
        format!(
            "classify (DESIGN_CLASSIFIER v2) under {run_profile}: V={} V_pad={} d={} d_pad={} T={} P0={} n={} S={} BOS={} final-norm g0={} cn={} tn={} ceps={} wrho={} dmax={} margin-vector=int16[-32767,32767] {} threshold c={} c-class=[-2^33,2^33] margin-window={} byte-limbs={} limbs-at-Lo-entry={} no-pin yes={} no={} ctl=ids<{} template={} policy={} tokenizer={} embedding={} variant=public-row mode=verdict-public-bit no-output-endpoint chunk-size={} chunk-overlap={} chunk-split=end-aligned {} {}",
            self.v,
            self.v_pad,
            self.d,
            self.d_pad,
            self.tokens,
            self.p0(),
            self.n,
            self.policy.suffix.len(),
            self.bos,
            self.norm.g0,
            self.norm.cn,
            self.norm.tn,
            self.norm.ceps,
            self.wrho,
            self.d_max,
            hex(&self.w_digest),
            self.policy.c,
            self.window_bits,
            self.limbs,
            LAM_BASE,
            self.policy.yes,
            self.policy.no,
            self.policy.num_special,
            hex(&self.template_digest()),
            self.policy.id,
            self.policy.tokenizer,
            hex(&self.emb_digest),
            self.n,
            chunk_overlap_of(run_profile).map(|o| o.to_string()).unwrap_or_else(|_| "unregistered".into()),
            rulings_text(),
            self.tier.describe()
        )
    }

    pub(crate) fn digest_under(&self, run_profile: &str) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify/profile/v1");
        let s = self.describe_under(run_profile);
        h.update(&(s.len() as u64).to_le_bytes());
        h.update(s.as_bytes());
        *h.finalize().as_bytes()
    }
}

// ---------------------------------------------------------------- the input endpoint

/// the classifier's input token endpoint digest slots (distinct from the
/// token run's: its own spec digest)
const CLASSIFY_IN_EP_SLOTS: (u64, u64) = (0x636c_732d_696e, 0);
pub(crate) const STAGE_IN_C_MAGIC: &[u8; 8] = b"HLPCLIN1";
pub(crate) const STAGE_OUT_C_MAGIC: &[u8; 8] = b"HLPCLOT1";

/// the ONE external endpoint: the whole token plane (template + content), public-row geometry
pub(crate) fn input_endpoint_spec(sh: &Shape, context: Digest, cp: &ClassifierProfile) -> Result<EndpointSpecG, String> {
    let t = cp.tier;
    EndpointSpecG::new_with_tag(context, 1, cp.in_ep_words(), 0, CLASSIFY_IN_EP_SLOTS.0, CLASSIFY_IN_EP_SLOTS.1, t.ep_log_n, t.ep_inv_rate, t.opened_cols, &sh.hash_tag())
}

/// the input plane: the `T` ids (template and content) and zero pad words
pub(crate) fn input_plane(cp: &ClassifierProfile, tokens: &[u64]) -> Vec<Fp> {
    let mut ep = vec![Fp::ZERO; cp.in_ep_words()];
    for (t, id) in tokens.iter().enumerate() {
        ep[t] = Fp::new(*id);
    }
    ep
}

/// seal the input endpoint (D18: the prover, before the header)
pub(crate) fn seal_input(spec: &EndpointSpecG, plane: &[Fp], tag: &zkp_core::hashtag::HashTag) -> Result<(Digest, CommittedZk), String> {
    let ntt = NttTables::new(spec.enc_log());
    let i = endpoint_g::prepare(spec, plane, &ntt, tag, EndpointRole::Input)?.into_endpoint(spec)?;
    Ok((i.commitment().root, i))
}

/// the full token sequence of an item: template prefix, content, suffix
pub(crate) fn item_tokens(policy: &Policy, content: &[u64]) -> Vec<u64> {
    policy.prefix.iter().chain(content.iter()).chain(policy.suffix.iter()).copied().collect()
}

// ---------------------------------------------------------------- the run statement

/// THE CLASSIFIER RUN STATEMENT. Everything a verifier needs, nothing a
/// prover chooses except the public verdict bit, which it publishes and the
/// transcript binds. Built only through [`ClassifyRunStatement::new`].
pub(crate) struct ClassifyRunStatement {
    rs: RunShape,
    context: Digest,
    pub(crate) block_digests: Vec<Digest>,
    model_identity: Digest,
    pub(crate) cp: ClassifierProfile,
    pub(crate) in_spec: EndpointSpecG,
    in_root: Digest,
    scale: i32,
    whole_run: WholeRun,
    stage_cal: Vec<NormCalibration>,
    /// **THE PUBLIC VERDICT** (1 = flagged: `Delta > c`)
    verdict: u8,
    /// D41: this proof's chunk of its item (one chunk: the whole content)
    chunk: ChunkRef,
}

/// the derived whole-run figure of a classifier run (the token run's union
/// bound, D27): stage IN-C and stage OUT-C (A, H, M), ONE token endpoint, the
/// `L` blocks, the `L + 1` boundaries; LogUp: stage OUT-C's byte lookups
/// (`Lo`, `Do`), the blocks, and stage IN-C's compressed-row lookup with ONE
/// more column (the control-id column raises the row-collision degree by 1)
pub(crate) fn whole_run_of_classifier(sh: &Shape, l: usize, cp: &ClassifierProfile) -> WholeRun {
    let t = cp.tier;
    let mut col: Vec<f64> = Vec::new();
    for _ in 0..2 {
        col.push(t.per_opening_log2(t.stage_log_n, t.stage_inv_rate));
        col.push(t.per_opening_log2(t.stage_log_n, t.stage_inv_rate));
        col.push(mask_opening_log2());
    }
    col.push(t.per_opening_log2(t.ep_log_n, t.ep_inv_rate));
    for _ in 0..l {
        col.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
        col.push(hiding_opening_log2(sh.log_cols, sh.inv_rate, sh.opened_cols));
        col.push(mask_opening_log2());
    }
    for _ in 0..=l {
        col.push(hiding_opening_log2(sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols));
    }
    let mut lk = vec![super::stage_out_c::logup_size(&super::stage_out_c::layout(sh, cp))];
    let blk = block_logup_size(sh);
    lk.extend(vec![blk; l]);
    let field_log2 = 2.0 * (P as f64).log2();
    let column: f64 = col.iter().map(|x| x.exp2()).sum();
    let mut num: f64 = lk.iter().map(|(n, r)| (*n + 3 * *r - 1) as f64).sum::<f64>();
    let (n_in, r_in) = super::stage_in_c::logup_size(&super::stage_in_c::layout(sh, cp), cp);
    let lg = clog2(cp.d_pad) as u128;
    num += (n_in + r_in * (3 + lg) + cp.tokens as u128 * lg) as f64;
    let logup = num * (-field_log2).exp2();
    let omitted = col.len() as f64 * PCS_FIELD_PER_OPENING_LOG2.exp2() + (l + 2) as f64 * SUMCHECK_PER_STAGE_LOG2.exp2();
    let total_log2 = (column + logup + omitted).log2();
    WholeRun { openings: col.len(), column_log2: column.log2(), logup_log2: logup.log2(), omitted_log2: omitted.log2(), total_log2, floor_bits: (-total_log2).floor() as u32 }
}

impl ClassifyRunStatement {
    /// The classifier door and the trained-model binding, in one constructor
    /// (both sides; the verifier passes the PUBLISHED verdict): an item of
    /// ONE chunk (its whole content, `n` ids).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        rs: RunShape,
        context: Digest,
        block_digests: Vec<Digest>,
        model: &TrainedModelStatement,
        tables: &ClassifierTables,
        bos: u64,
        norm: FinalNorm,
        policy: &Policy,
        n: usize,
        tier: Tier,
        in_root: Digest,
        verdict: u8,
    ) -> Result<ClassifyRunStatement, String> {
        ClassifyRunStatement::new_chunk(rs, context, block_digests, model, tables, bos, norm, policy, n, tier, in_root, verdict, n, 0)
    }

    /// **D41: chunk `chunk_index` of an item of `total` content ids.** The
    /// chunk's range is DERIVED from (total, index, the profile's plan: size
    /// `n = T - P0 - S`, the registered overlap), never taken as given.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_chunk(
        rs: RunShape,
        context: Digest,
        block_digests: Vec<Digest>,
        model: &TrainedModelStatement,
        tables: &ClassifierTables,
        bos: u64,
        norm: FinalNorm,
        policy: &Policy,
        n: usize,
        tier: Tier,
        in_root: Digest,
        verdict: u8,
        total: usize,
        chunk_index: usize,
    ) -> Result<ClassifyRunStatement, String> {
        if !CLASSIFY_RUN_PROFILES.contains(&rs.profile()) {
            return Err(format!("classifier run: {} is not a classifier run profile", rs.profile()));
        }
        if context == [0; 32] {
            return Err("classifier run: a nonempty context is required".into());
        }
        if verdict > 1 {
            return Err("classifier run: the verdict is one bit".into());
        }
        let sh = rs.sh();
        if !sh.trained_calibration {
            return Err("classifier run: the blocks must be a trained-calibration shape bound to its trained-model statement".into());
        }
        let l = rs.l();
        let scales = model.calibration.block_scales;
        if scales.0 != scales.1 {
            return Err("classifier run: a boundary has ONE scale (M-4)".into());
        }
        model.check_against(sh, rs.profile(), &block_digests, &vec![scales; l])?;
        let cp = ClassifierProfile::new(sh, tables, bos, norm, policy, n, tier)?;
        let chunk = ChunkRef::derive(total, chunk_index, ChunkPlan { size: n, overlap: chunk_overlap_of(rs.profile())? })?;
        let in_spec = input_endpoint_spec(sh, context, &cp)?;
        let whole_run = whole_run_of_classifier(sh, l, &cp);
        let base = sh.norm_calibration();
        let mut stage_cal = vec![base; l];
        for (k, r) in model.layers.iter().enumerate() {
            if block_digests.get(k) != Some(&r.block_digest) {
                return Err(format!("classifier run: layer record {k} (layer {}) is not block {k}'s digest (review TR3-3)", r.index));
            }
            if has_own(&r.own) {
                let cal = apply_own(&base, &r.own).map_err(|e| format!("classifier run: layer {}: {e}", r.index))?;
                sh.with_layer_calibration(&cal).map_err(|e| format!("classifier run: layer {}'s own calibration: {e}", r.index))?;
                stage_cal[k] = cal;
            }
        }
        Ok(ClassifyRunStatement { rs, context, block_digests, model_identity: model.identity(), cp, in_spec, in_root, scale: scales.0, whole_run, stage_cal, verdict, chunk })
    }

    pub(crate) fn sh(&self) -> &Shape {
        self.rs.sh()
    }
    pub(crate) fn profile(&self) -> &'static str {
        self.rs.profile()
    }
    pub(crate) fn l(&self) -> usize {
        self.rs.l()
    }
    pub(crate) fn context(&self) -> Digest {
        self.context
    }
    pub(crate) fn in_root(&self) -> Digest {
        self.in_root
    }
    /// D41: this proof's chunk of its item
    pub(crate) fn chunk(&self) -> ChunkRef {
        self.chunk
    }

    pub(crate) fn verdict(&self) -> u8 {
        self.verdict
    }
    pub(crate) fn whole_run(&self) -> &WholeRun {
        &self.whole_run
    }
    pub(crate) fn rs(&self) -> &RunShape {
        &self.rs
    }
    pub(crate) fn model_identity(&self) -> Digest {
        self.model_identity
    }
    /// the shape block stage `k` is proved and verified at (NATIVE R8, as the token run)
    pub(crate) fn stage_shape(&self, k: usize) -> Result<Shape, String> {
        let cal = *self.stage_cal.get(k).ok_or_else(|| format!("classifier run: no block stage {k}"))?;
        if cal == self.sh().norm_calibration() {
            Ok(self.sh().clone())
        } else {
            self.sh().with_layer_calibration(&cal)
        }
    }
    pub(crate) fn boundary_spec(&self, j: usize) -> Result<BoundarySpec, String> {
        let sh = self.sh();
        if j > self.l() {
            return Err(format!("classifier run: boundary {j} is not one of this run's {}", self.l() + 1));
        }
        BoundarySpec::new_with_tag(self.context, sh.t_pad, sh.d_pad, self.scale, (j + 1) as u64, 2, sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows + 1, &sh.hash_tag())
    }

    fn expected_bytes(&self) -> Vec<u8> {
        let mut v = Vec::with_capacity(16 + 2 * 32);
        v.extend_from_slice(b"classify-expected/v1");
        v.extend_from_slice(&self.in_spec.digest());
        v.extend_from_slice(&self.in_root);
        v
    }

    fn public_statement(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify-run-blocks/v1");
        for d in &self.block_digests {
            h.update(d);
        }
        h.update(&self.cp.emb_digest);
        h.update(&self.cp.w_digest);
        *h.finalize().as_bytes()
    }

    fn calibration(&self) -> Digest {
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify-calibration/v1");
        h.update(&self.model_identity);
        h.update(&self.cp.digest_under(self.profile()));
        *h.finalize().as_bytes()
    }

    pub(crate) fn parameter_line(&self) -> Result<String, String> {
        let sh = self.sh();
        let b = self.boundary_spec(0)?;
        let t = self.cp.tier;
        Ok(format!(
            "{}/L{}/boundaries-B_in-B_out-and-interior-log_n{}-rate{}-pad{}-rows{}-sites2/token-endpoint-in-log_n{}-rate{}-pad{}-words{}-rows{}-sites1/no-output-endpoint/stages-log_n{}-rate{}-pad{}/{}/whole-run-floor-{}-bits-{}-openings-column-plus-logup-derived-plus-pcs-field-and-sumcheck-bound/one-run-one-transcript",
            protocol::parameter_line(sh).replace("/two-private-endpoints/", "/two-internal-boundaries/"),
            self.l(),
            sh.endpoint_log_n,
            sh.endpoint_inv_rate,
            sh.opened_cols,
            b.commitment_rows(),
            t.ep_log_n,
            t.ep_inv_rate,
            t.opened_cols,
            self.cp.in_ep_words(),
            self.in_spec.commitment_rows(),
            t.stage_log_n,
            t.stage_inv_rate,
            t.opened_cols,
            self.cp.describe_under(self.profile()),
            self.whole_run.floor_bits,
            self.whole_run.openings
        ))
    }

    pub(crate) fn stage_lines(&self) -> Result<Vec<String>, String> {
        let l = self.l();
        let mut out = Vec::with_capacity(l + 2);
        let b0 = self.boundary_spec(0)?;
        out.push(format!(
            "stage 00 (IN-C): commits boundary 1 = B_in; INC-01 claims B_in at pair row {}; INC-00 claims the input token endpoint at pair row {}; opens M A H then the input token endpoint",
            b0.mask_row(0)?,
            self.in_spec.data_rows()
        ));
        for k in 0..l {
            let (p, q) = (self.boundary_spec(k)?, self.boundary_spec(k + 1)?);
            let base = self.sh().norm_calibration();
            let mut own = String::new();
            for (i, (_, _, label)) in OWN_FIELDS.iter().enumerate() {
                let (v, b) = (cal_field(&self.stage_cal[k], i), cal_field(&base, i));
                if v != b {
                    own.push_str(&format!("; {label} {v} (the layer's own; the run's is {b})"));
                }
            }
            out.push(format!(
                "stage {:02} (block {k}): commits boundary {}{}; slot 21 claims boundary {} at pair row {}; slot 22 claims boundary {} at pair row {}; opens M A H then boundary {}; data rows {}{own}",
                k + 1,
                k + 2,
                if k + 1 == l { " = B_out" } else { "" },
                k + 1,
                p.mask_row(1)?,
                k + 2,
                q.mask_row(0)?,
                k + 1,
                p.data_rows()
            ));
        }
        let bl = self.boundary_spec(l)?;
        out.push(format!(
            "stage {:02} (OUT-C): OUTC-00 claims boundary {} = B_out at the fixed public row {} at pair row {}; the verdict bit is public; opens M A H then B_out",
            l + 1,
            l + 1,
            self.cp.tokens - 1,
            bl.mask_row(1)?
        ));
        Ok(out)
    }

    fn schedule_digest(&self) -> Result<Digest, String> {
        let sh = self.sh();
        let mut h = blake3::Hasher::new();
        h.update(b"hashline/classify-run-schedule/v1");
        let mut line = |s: &str| {
            h.update(&(s.len() as u64).to_le_bytes());
            h.update(s.as_bytes());
        };
        line(&self.parameter_line()?);
        for s in Layout::for_shape(sh)?.describe() {
            line(&s);
        }
        for s in super::stage_in_c::layout(sh, &self.cp).describe() {
            line(&s);
        }
        for s in super::stage_out_c::layout(sh, &self.cp).describe() {
            line(&s);
        }
        for s in self.stage_lines()? {
            line(&s);
        }
        Ok(*h.finalize().as_bytes())
    }

    /// **the run header, absorbed before any commitment exists** — the
    /// public verdict last, so a receipt read under the other verdict derives
    /// another transcript (strong Fiat-Shamir: the public output before any
    /// challenge)
    pub(crate) fn transcript(&self) -> Result<Transcript, String> {
        let sh = self.sh();
        let mut tr = protocol::tagged_transcript(sh, self.rs.profile().as_bytes());
        let mut shape_bytes = Vec::with_capacity(11 * 8);
        for v in [self.l(), sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, self.cp.v, self.cp.p0(), self.cp.n, self.cp.policy.suffix.len()] {
            shape_bytes.extend_from_slice(&(v as u64).to_le_bytes());
        }
        tr.absorb(b"run-shape", &shape_bytes);
        tr.absorb(b"expected-IO", &self.expected_bytes());
        tr.absorb(b"public-statement", &self.public_statement());
        tr.absorb(b"parameters", self.parameter_line()?.as_bytes());
        tr.absorb(b"calibration", &self.calibration());
        tr.absorb(b"schedule", &self.schedule_digest()?);
        tr.absorb(b"classify-verdict", &[self.verdict]);
        tr.absorb(b"classify-chunk", &self.chunk.bytes());
        Ok(tr)
    }

    pub(crate) fn ntt_log(&self) -> u32 {
        let sh = self.sh();
        let t = self.cp.tier;
        [
            protocol::ntt_log_at(sh),
            (sh.endpoint_log_n + sh.endpoint_inv_rate.trailing_zeros() as usize) as u32,
            (t.stage_log_n + t.stage_inv_rate.trailing_zeros() as usize) as u32,
            (t.ep_log_n + t.ep_inv_rate.trailing_zeros() as usize) as u32,
            crate::zk::MASK_LOG_DOM,
        ]
        .into_iter()
        .max()
        .unwrap_or(crate::zk::MASK_LOG_DOM)
    }

    pub(crate) fn in_geom<'a>(&self, lay: &'a StageLayout) -> StageSegGeom<'a> {
        let ed = Dim::of(&self.in_spec.params());
        StageSegGeom { magic: STAGE_IN_C_MAGIC, lay, has_b_root: true, a_groups: super::stage_in_c::A_GROUPS, h_groups: super::stage_in_c::H_GROUPS, closes: vec![(ed, 1, self.in_spec.commitment_rows())], total: self.l() + 2, index: 0 }
    }

    pub(crate) fn out_geom<'a>(&self, lay: &'a StageLayout) -> Result<StageSegGeom<'a>, String> {
        let b = self.boundary_spec(self.l())?;
        let bd = Dim::of(&b.params());
        Ok(StageSegGeom { magic: STAGE_OUT_C_MAGIC, lay, has_b_root: false, a_groups: super::stage_out_c::A_GROUPS, h_groups: super::stage_out_c::H_GROUPS, closes: vec![(bd, 2, b.commitment_rows())], total: self.l() + 2, index: self.l() + 1 })
    }

    pub(crate) fn block_geom(&self, k: usize) -> Result<SegGeom, String> {
        Ok(SegGeom { l: self.l() + 2, k: k + 1, boundary_rows: self.boundary_spec(0)?.commitment_rows(), sites: 2 })
    }

    pub(crate) fn block_layout(&self, k: usize) -> Result<Layout, String> {
        Ok(Layout::for_shape(&self.stage_shape(k)?)?.with_io_mask_rows([self.boundary_spec(k)?.mask_row(1)?, self.boundary_spec(k + 1)?.mask_row(0)?]))
    }

    pub(crate) fn segment_lens(&self) -> Result<Vec<usize>, String> {
        let sh = self.sh();
        let mut v = vec![self.in_geom(&super::stage_in_c::layout(sh, &self.cp)).len()];
        for k in 0..self.l() {
            v.push(wire::segment_len(&self.block_layout(k)?, self.block_geom(k)?));
        }
        v.push(self.out_geom(&super::stage_out_c::layout(sh, &self.cp))?.len());
        Ok(v)
    }
}
