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
//! Victor's four classifier rulings (D45, 2026-10-29 01:04 UTC) are the
//! [`RULING_B4_FAIL_CLOSED`], [`RULING_B5_N_PUBLIC`],
//! [`RULING_B6_FIXED_POLICY_LIST`] and [`RULING_B8_BINDING`] switches, at the
//! accepted settings and written into the profile's canonical text.
//!
//! **ROUND 14 (DESIGN v2.4 §15):** a SHORT item (fewer content ids than one
//! chunk) is one chunk of its TRUE length `n`: positions `P0 + n .. P0 + n +
//! S` hold the suffix, every later position up to `T` holds the policy's
//! PUBLIC pad id (pinned by the template clause, as the prefix and suffix
//! are), and stage OUT-C reads the public verdict row `P0 + n + S - 1`. The
//! blocks' attention is causal, so the pad rows never reach that row. `n` is
//! public (D45(1)); nothing else is revealed. And the tables every entry point
//! takes are [`super::classify_tied::BoundClassifierTables`] (REVIEW_R13
//! N-r13-1): derived from the pinned tensor for the trained statement the run
//! names, never caller-supplied. Not a privacy claim; not a
//! registered production profile beyond the development rung; the frozen
//! next-token run (D36) is untouched: everything here is new code under new
//! profile strings.

use super::super::boundary::BoundarySpec;
use super::super::endpoint_g::{self, EndpointRole, EndpointSpecG};
use super::super::layout::Layout;
use super::super::protocol;
use super::super::run::RunShape;
use super::super::shape::NormCalibration;
use super::super::trained_statement::{apply_own, cal_field, has_own, TrainedModelStatement, OWN_FIELDS};
use super::super::wire::{self, SegGeom};
use super::run::{block_logup_size, WholeRun};
use super::*;
use crate::ntt::NttTables;
use crate::pcs::CommittedZk;

// ---------------------------------------------------------------- the ruling switches

/// **B-5 = D45(1) (Victor, 2026-10-29): the exact content length `n` is
/// public** (the public-row variant: `n`, `T` and the template lengths are in
/// the statement; round 14: `P0 + n + S <= T`, the rest public pad). The
/// hidden-length variant (in-circuit length binding, design §3.4 option H) is
/// not built; `false` is refused by name.
pub(crate) const RULING_B5_N_PUBLIC: bool = true;
/// **B-6 = D45(2) (Victor, 2026-10-29): policies come only from the fixed, pre-registered
/// list** ([`registered_policies`]), one threshold `c` each (a profile
/// constant, never a per-run choice).
pub(crate) const RULING_B6_FIXED_POLICY_LIST: bool = true;
/// **B-8 = D45(3) (Victor, 2026-10-29; amends D23): the proof is bound to its item
/// through the input endpoint root** and the input owner's decommitment check
/// (design §6.1); option S (seeded endpoint randomness) is not built.
pub(crate) const RULING_B8_BINDING: &str = "input-endpoint-root";
/// **B-4 = D45(4) (Victor, 2026-10-29): fail-closed** — an item without an accepted proof
/// is handled exactly as flagged; the CLI says so on every refusal.
pub(crate) const RULING_B4_FAIL_CLOSED: bool = true;

/// the switches' canonical text (bound through the profile text)
pub(crate) fn rulings_text() -> String {
    format!(
        "rulings: B-5 n-public={} B-6 fixed-policy-list={} B-8 binding={} B-4 fail-closed={} (accepted by Victor: D45, 2026-10-29)",
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
    /// **ROUND 14 (DESIGN v2.4 §15): the PUBLIC pad id** every position after
    /// a short item's suffix holds (up to `T`), pinned by the template clause
    pub pad: u64,
    /// **R-C2: the margin row's PUBLIC quantization scale** (f64 bits), a
    /// registered policy constant: `w = floor((E[yes] - E[no]) * g / scale +
    /// 0.5)` from the pinned tied tensor (never from a file; coordinator
    /// 2026-10-28 21:35, condition 1)
    pub margin_scale_bits: u64,
}

impl Policy {
    /// the margin row's public scale
    pub(crate) fn margin_scale(&self) -> f64 {
        f64::from_bits(self.margin_scale_bits)
    }
}

/// the development rung's synthetic policy (its ids are the CLI fixture's
/// prompt layout: positions 0..8 template, 8..31 content, 31 suffix)
pub(crate) fn policy_rung_dev() -> Policy {
    Policy { id: "rung-tc-synthetic-policy-dev/1".into(), prefix: (1..=8).collect(), suffix: vec![32], num_special: 5, yes: 40, no: 41, c: 0, tokenizer: "synthetic (ids only, no text)".into(), v: 300, pad: 2, margin_scale_bits: (1.0f64 / 256.0).to_bits() }
}

/// Shieldstral-1.0-3B with the model card's 7-category template (round 12,
/// R-C0's pinned ids, `classifier/rc0/template_ids.json`: P0 = 84 ending at
/// `>:`, suffix `[/INST]`; tekken plain-text encoding, `num_special_tokens`
/// 1000; yes 13059, no 2649; tau 0.5 so c = 0).
/// **TEST BUILDS ONLY since token round 16b (REVIEW_R16 F-1, D45(2)): it is NOT
/// a pre-registered policy.** Its (yes, no, scale, c) are the R13 Shieldstral
/// exports' own, so while round 16 kept it in [`registered_policies`] both R13
/// Shieldstral run profiles admitted it beside the three category policies (a
/// fourth yes / no question about the hidden content, where D45(2) fixes
/// three). No build registers it now: `policy_by_id`, the classifier door and
/// the statement constructor refuse it by name. The tests keep it as the R-C2
/// derivation's reference policy (`classify_tied_tests`) and as the refused
/// fourth policy (`classify_r16_tests::r16b`).
#[cfg(test)]
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
        // tekken.json's `<pad>` (rank 11, a control id) = generation_config.json's
        // pad_token_id 11 (snapshot 003ec7e2); its pad rows' refusal behaviour is
        // owed with the Shieldstral classifier run profile's registration
        pad: 11,
        // native R12b's chosen scale for 13059 / 2649 (SOL_REPORT_20261028: the
        // 3,072 coordinates span -32767 .. 31800, zero refusals [COUNTED])
        margin_scale_bits: 4.08288030735373e-6f64.to_bits(),
    }
}

/// **TOKEN I/O ROUND 16: the three D37 category policies at Shieldstral-1.0-3B**
/// (sexual / explicit, graphic violence, hate / harassment; Victor
/// 2026-10-21 03:25), in the MODERATE wording of Astra's candidates
/// (`results/zk60_shieldstral_export_20261026/category_policy_candidates.json`,
/// sha256 b1cfcda9…: `mod_sexual`, `mod_violence`, `mod_hate`; ids cross-checked
/// there against the 4,872 A1 inputs). **The strict-versus-moderate choice is
/// Victor's (open item 1 of `ZK60_RULINGS_FOR_VICTOR_20261017.md`, 2026-10-28
/// 23:15; the coordinator recommends moderate):** this build registers ONE
/// fixed list (D45(2)) and it is the moderate one, pending that ruling;
/// switching to strict replaces these three entries (new policy ids, new
/// templates), and an item proved under one is never re-proved under the
/// other (D45(2)). Every entry: tekken plain-text encoding (B-1: the content
/// carries its own leading space; B-2: control ids < 1000 refused at content
/// positions), yes 13059 / no 2649, c = 0 (tau 0.5), pad 11, the margin scale
/// of native R12b's card policy (the export profile's
/// `classifier_margin_parameters` must name the same four values).
const CATEGORY_TEMPLATE_HEAD: [u64; 58] = [
    1, 17, 1074, 45463, 5627, 1278, 23762, 37005, 1278, 13795, 4057, 1408, 1278, 27356, 1321, 1278, 83779, 5662, 1046, 13708, 1455, 1278, 4832, 1710, 2342, 1402, 1429, 13059, 1034, 1505, 1429, 2649, 3871, 18, 3, 1060, 1785, 8166, 72067, 3213, 1584,
    1261, 12216, 11673, 2412, 1046, 63882, 1261, 21680, 27710, 13472, 1338, 1060, 7087, 72067, 20525, 1593, 4701,
];
/// `"\n\n<Document>: [User]"` (the end of every category template)
const CATEGORY_TEMPLATE_TAIL: [u64; 7] = [2634, 1060, 16060, 72067, 1766, 4019, 1093];
/// the query of each category, between the head and the tail
const QUERY_SEXUAL: [u64; 7] = [4231, 10703, 70351, 1505, 61522, 14960, 4318];
const QUERY_VIOLENCE: [u64; 7] = [17767, 47223, 16988, 1505, 17438, 8137, 16988];
const QUERY_HATE: [u64; 13] = [4231, 31483, 16181, 27491, 1261, 8949, 3204, 1044, 1505, 84083, 1505, 7357, 19447];

fn policy_shieldstral_category(id: &str, query: &[u64]) -> Policy {
    let prefix: Vec<u64> = CATEGORY_TEMPLATE_HEAD.iter().chain(query.iter()).chain(CATEGORY_TEMPLATE_TAIL.iter()).copied().collect();
    Policy {
        id: id.into(),
        prefix,
        suffix: vec![4],
        num_special: 1000,
        yes: 13059,
        no: 2649,
        c: 0,
        tokenizer: "tekken.json sha256 ceb11e85e44d7c91 (plain-text encoding, no special-token parsing; template ids as Astra's candidates b1cfcda9)".into(),
        v: 131_072,
        pad: 11,
        margin_scale_bits: 4.08288030735373e-6f64.to_bits(),
    }
}

/// D37 category (1), sexual / explicit content (moderate wording; see above)
pub(crate) fn policy_shieldstral_moderate_sexual() -> Policy {
    policy_shieldstral_category("shieldstral-1.0-3b-moderate-sexual/1", &QUERY_SEXUAL)
}
/// D37 category (2), graphic violence (moderate wording)
pub(crate) fn policy_shieldstral_moderate_violence() -> Policy {
    policy_shieldstral_category("shieldstral-1.0-3b-moderate-violence/1", &QUERY_VIOLENCE)
}
/// D37 category (3), hate / harassment (moderate wording)
pub(crate) fn policy_shieldstral_moderate_hate() -> Policy {
    policy_shieldstral_category("shieldstral-1.0-3b-moderate-hate/1", &QUERY_HATE)
}
/// the D37 category list of this build, in D37's order
pub(crate) fn shieldstral_category_policies() -> Vec<Policy> {
    vec![policy_shieldstral_moderate_sexual(), policy_shieldstral_moderate_violence(), policy_shieldstral_moderate_hate()]
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

/// **THE PRE-REGISTERED POLICY LIST (B-6 = D45(2)).** Production builds: the
/// synthetic development rung's dev policy (V = 300: refused at every
/// Shieldstral profile by its vocabulary and margin parameters) and the D37
/// category list, so each R13 Shieldstral run profile admits exactly the three
/// category policies (token round 16b, REVIEW_R16 F-1; round 12's card policy is
/// test-only). Test builds add only their thread's registered test policies.
pub(crate) fn registered_policies() -> Vec<Policy> {
    #[allow(unused_mut)]
    let mut v = vec![policy_rung_dev()];
    // TOKEN I/O ROUND 16: the D37 category list (moderate wording, pending Victor)
    v.extend(shieldstral_category_policies());
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
/// **ROUND 16:** the R13 Shieldstral profiles carry an overlap of 8 content
/// ids (a public, tunable deployment constant of D41, chosen by the token lane
/// for chunks of 49-55 ids at T128 and 177-183 at T256; not a ruling).
pub(crate) const CHUNK_OVERLAPS: [(&str, usize); 3] = [
    (super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC, 4),
    (super::super::run::RUN_PROFILE_CLASSIFY_R13_SHIELD_T128, 8),
    (super::super::run::RUN_PROFILE_CLASSIFY_R13_SHIELD_T256, 8),
];

pub(crate) fn chunk_overlap_of(run_profile: &str) -> Result<usize, String> {
    #[cfg(test)]
    if run_profile == super::super::run::RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST {
        return Ok(4);
    }
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
/// **ROUND 14 (§15): short content** (`1 <= total < size`) is ONE chunk of
/// its true length, `[0, total)`; its proof pins the trailing positions to
/// the policy's public pad id. An empty content is refused.
pub(crate) fn chunk_ranges(total: usize, plan: ChunkPlan) -> Result<Vec<(usize, usize)>, String> {
    if plan.size == 0 || plan.overlap >= plan.size {
        return Err(format!("classifier chunks: the plan (size {}, overlap {}) needs 0 <= overlap < size", plan.size, plan.overlap));
    }
    if total == 0 {
        return Err("classifier chunks: an empty content has no chunk (n >= 1)".into());
    }
    if total < plan.size {
        return Ok(vec![(0, total)]);
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
    let mut v = vec![(super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC, Shape::rung_tc(&super::super::trained_calib_tests::rung_tc_calibration()).expect("the trained-calibration rung"))];
    // ROUND 16: the R13 Shieldstral classifier run profiles, each at its R13
    // block shape (a generic class calibration; the census reads lengths)
    for (run, block) in super::super::run::ACCURACY_CLASSIFY_RUN_PROFILES {
        v.push((run, Shape::accuracy_trained(block, &r13_census_calibration(), 9, 20).expect("the R13 Shieldstral block shape")));
    }
    // and the test-only R13 rung profile (width 384: the rung's class calibration)
    let mut rung = r13_census_calibration();
    rung.tn = 10;
    v.push((super::super::run::RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST, Shape::accuracy_trained(super::super::shape::R13_RUNG_H24, &rung, 12, 20).expect("the R13 h24 rung shape")));
    v
}

/// ROUND 16 (test only): a calibration inside every R13 class at width 3072
/// (the R13 profile tests' generic one)
#[cfg(test)]
pub(crate) fn r13_census_calibration() -> NormCalibration {
    NormCalibration { tn: 9, cn_a: 100, cn_m: 100, ceps: 1, sh_ao: 7, sh_qkv: 8, sh_s: 6, sh_o: 9, sh_g: 8, sh_h: 14, sh_z: 6 }
}

/// ROUND 16 (test only): a synthetic trained statement of `l` R13 layer
/// records at `sh` under the classifier run profile `profile` (digests and
/// records only, as native R13's `hash_census_model`; layer k's gate shift is
/// `gates[k]`), with Shieldstral's RoPE transform in its provenance
#[cfg(test)]
pub(crate) fn r13_synthetic_model(sh: &Shape, profile: &str, gates: &[u32], export_profile_sha256: [u8; 32], residual_unit: f64) -> TrainedModelStatement {
    use super::super::trained_statement::{IntegerCalibration, LayerRecord, ModelSource, Provenance, SourceKind};
    let source = ModelSource { kind: SourceKind::PublicSyntheticRecipe, repo: "hashline/token-io-r16/synthetic-r13".into(), revision: "token-io-r16".into(), weights_sha256: [0; 32], config_sha256: [0; 32], checkpoint_parameters: 0, checkpoint_layers: gates.len() as u32 };
    let layers = gates
        .iter()
        .enumerate()
        .map(|(k, &g)| {
            let mut r = LayerRecord::unhashed(k as u32);
            r.accuracy_gate_shift = Some(g);
            r.block_digest = [k as u8 + 1; 32];
            r.silu_member = (-3, -11);
            r
        })
        .collect();
    let mut prov = Provenance::recipe("token-io-r16/synthetic-r13", residual_unit, [5; 32], [6; 32]);
    prov.export_profile_sha256 = export_profile_sha256;
    prov.rope_theta = super::super::shape::trained_rope_theta(sh.profile).expect("a trained profile");
    prov.rope_scaling = super::super::shape::trained_rope_scaling(sh.profile).expect("a trained profile");
    TrainedModelStatement::new_synthetic_at_trained_profile_for_tests(sh, profile, source, IntegerCalibration::as_the_code_proves(sh, &prov), layers).expect("the synthetic R13 trained statement")
}

/// **s25's census statement of a classifier run profile at `l` blocks**: one
/// synthetic block standing for all `L` (only its digest and record enter the
/// statement), a generic embedding and margin vector, the profile's policy
/// (test only)
#[cfg(test)]
pub(crate) fn census_classify_statement(profile: &'static str, l: usize) -> (ClassifyRunStatement, TrainedModelStatement, ClassifierTables) {
    use super::tests::{blocks, ctx, generic_tables, model_of_one, norm};
    // ROUND 16: an R13 Shieldstral classifier run profile's census statement:
    // synthetic records (each its gate shift), V = 131,072 tables, the real
    // classifier final norm's class, the hate policy (the longest template)
    if profile == super::super::run::RUN_PROFILE_CLASSIFY_R13_RUNG_H24_TEST {
        let sh = registered_classify_runs().into_iter().find(|(p, _)| *p == profile).map(|(_, s)| s).expect("the R13 rung test profile");
        let policy = policy_rung_dev();
        let gates: Vec<u32> = (0..l).map(|k| 17 + (k as u32 % 8)).collect();
        let model = r13_synthetic_model(&sh, profile, &gates, [9; 32], 1.0 / 512.0);
        let digests: Vec<Digest> = model.layers.iter().map(|r| r.block_digest).collect();
        let tt = generic_tables(sh.width, 0x636c_6173);
        let w: Vec<i16> = (0..sh.width).map(|i| (i as i16 % 2000) - 1000).collect();
        let tables = ClassifierTables::new(tt.v, tt.d, tt.emb, w).expect("the census classifier tables");
        let bound = super::classify_tied::BoundClassifierTables::synthetic_for_relation_tests(tables, 1, norm(), &sh, profile, &model, &policy).expect("the census tables");
        let n = sh.tokens - policy.prefix.len() - policy.suffix.len();
        let st = ClassifyRunStatement::new(RunShape::new(sh, l, profile).expect("the classifier run shape"), ctx(), digests, &model, &bound, &policy, n, Tier::R1_MVP, [7u8; 32], 1).expect("the census classifier statement");
        return (st, model, bound.tables().clone());
    }
    if let Some(sh) = registered_classify_runs().into_iter().find(|(p, _)| *p == profile && *p != super::super::run::RUN_PROFILE_CLASSIFY_RUNG_TC).map(|(_, s)| s) {
        let policy = policy_shieldstral_moderate_hate();
        let gates: Vec<u32> = (0..l).map(|k| 17 + (k as u32 % 8)).collect();
        let model = r13_synthetic_model(&sh, profile, &gates, [9; 32], 1.0 / 512.0);
        let digests: Vec<Digest> = model.layers.iter().map(|r| r.block_digest).collect();
        let (v, d) = (policy.v, sh.width);
        let emb: Vec<i16> = (0..v * d).map(|i| ((i * 7919) % 12_001) as i16 - 6_000).collect();
        let w: Vec<i16> = (0..d).map(|i| (i as i16 % 2000) - 1000).collect();
        let tables = ClassifierTables::new(v, d, emb, w).expect("the census classifier tables");
        let fnorm = FinalNorm { g0: 127, cn: 1024, tn: 10, ceps: 2439 };
        let bound = super::classify_tied::BoundClassifierTables::synthetic_for_relation_tests(tables, 1, fnorm, &sh, profile, &model, &policy).expect("the census tables");
        let n = sh.tokens - policy.prefix.len() - policy.suffix.len();
        let st = ClassifyRunStatement::new(RunShape::new(sh, l, profile).expect("the classifier run shape"), ctx(), digests, &model, &bound, &policy, n, Tier::R1_MVP, [7u8; 32], 1).expect("the census classifier statement");
        return (st, model, bound.tables().clone());
    }
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
    // the census reads lengths only: the relation-test binding (test builds only)
    let bound = super::classify_tied::BoundClassifierTables::synthetic_for_relation_tests(tables, 1, norm(), &sh, profile, &model, &policy).expect("the census tables");
    let st = ClassifyRunStatement::new(RunShape::new(sh, l, profile).expect("the classifier run shape"), ctx(), vec![digest; l], &model, &bound, &policy, n, Tier::R1_MVP, [7u8; 32], 1).expect("the census classifier statement");
    (st, model, bound.tables().clone())
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
        if policy.pad >= v as u64 {
            return Err("classifier: the policy's public pad id is outside the vocabulary".into());
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
        // ROUND 14 (§15): a short item fills the positions after its suffix with
        // the public pad id, so P0 + n + S is at most T (n public: D45(1))
        if n == 0 || policy.prefix.len() + n + policy.suffix.len() > sh.tokens {
            return Err(format!("classifier: P0 + n + S = {} + {n} + {} must be at most the block's T = {} (public-row variant, n >= 1; the positions after the suffix hold the public pad id)", policy.prefix.len(), policy.suffix.len(), sh.tokens));
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
    /// ROUND 14: the item's own length `P0 + n + S` (at most `T`)
    pub(crate) fn item_len(&self) -> usize {
        self.p0() + self.n + self.policy.suffix.len()
    }
    /// ROUND 14: the trailing positions `P0 + n + S .. T`, each holding the
    /// policy's public pad id (0 unless the item is short)
    pub(crate) fn pad_positions(&self) -> usize {
        self.tokens - self.item_len()
    }
    /// ROUND 14: **the public verdict row** stage OUT-C reads, the suffix's
    /// last position `P0 + n + S - 1` (`T - 1` when there is no pad)
    pub(crate) fn verdict_row(&self) -> usize {
        self.item_len() - 1
    }
    /// is position `t` a template position (prefix, suffix or, round 14, a
    /// trailing pad position)?
    pub(crate) fn is_template(&self, t: usize) -> bool {
        t < self.p0() || (t >= self.p0() + self.n && t < self.tokens)
    }
    /// the public template id at `t`: the prefix's, the suffix's, the pad id
    /// after the suffix (round 14); 0 at content positions and beyond `T`
    pub(crate) fn kappa(&self, t: usize) -> u64 {
        if t < self.p0() {
            self.policy.prefix[t]
        } else if t >= self.p0() + self.n && t < self.item_len() {
            self.policy.suffix[t - self.p0() - self.n]
        } else if t >= self.item_len() && t < self.tokens {
            self.policy.pad
        } else {
            0
        }
    }
    /// ROUND 14: the `T` ids of the item of `content` (`n` ids): the template
    /// prefix, the content, the suffix, then the public pad id up to `T`
    pub(crate) fn tokens_of(&self, content: &[u64]) -> Result<Vec<u64>, String> {
        if content.len() != self.n {
            return Err(format!("classifier: the content has {} ids; the profile's n is {}", content.len(), self.n));
        }
        let mut v = item_tokens(&self.policy, content);
        v.resize(self.tokens, self.policy.pad);
        Ok(v)
    }
    /// `ctl(v)`: a control id of the policy's tokenizer
    pub(crate) fn ctl(&self, v: u64) -> bool {
        v < self.policy.num_special
    }
    /// the query's public control column: `ctl(kappa(t))` at every template
    /// position (prefix, suffix and, since round 14, a short item's trailing
    /// pads, which carry `ctl(pad)`), 0 at content positions (ROUND 16:
    /// REVIEW_R14 N-r14-2's stale comment corrected; comment only)
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
            "classify (DESIGN_CLASSIFIER v2) under {run_profile}: V={} V_pad={} d={} d_pad={} T={} P0={} n={} S={} item-length={} pad-id={} pad-positions={} verdict-row={} BOS={} final-norm g0={} cn={} tn={} ceps={} wrho={} dmax={} margin-vector=int16[-32767,32767] {} threshold c={} c-class=[-2^33,2^33] margin-window={} byte-limbs={} limbs-at-Lo-entry={} no-pin yes={} no={} ctl=ids<{} template={} policy={} tokenizer={} embedding={} variant=public-row mode=verdict-public-bit no-output-endpoint chunk-size={} chunk-overlap={} chunk-split=end-aligned short-content=one-chunk-of-its-length-pad-pinned margin-scale={:e} margin-scale-bits={:#018x} {} {} {}",
            self.v,
            self.v_pad,
            self.d,
            self.d_pad,
            self.tokens,
            self.p0(),
            self.n,
            self.policy.suffix.len(),
            self.item_len(),
            self.policy.pad,
            self.pad_positions(),
            self.verdict_row(),
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
            self.tokens - self.p0() - self.policy.suffix.len(),
            chunk_overlap_of(run_profile).map(|o| o.to_string()).unwrap_or_else(|_| "unregistered".into()),
            self.policy.margin_scale(),
            self.policy.margin_scale_bits,
            super::classify_tied::TiedSource::of_run_profile(run_profile).map(|t| t.describe()).unwrap_or_else(|_| "tied-source=unregistered".into()),
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
    /// **ROUND 16 (REVIEW_R13 §10 item 3): each block stage's R13 common gate
    /// denominator**, read from the trained statement's bound layer record
    /// (`LayerRecord::accuracy_gate_shift`, encoded `accuracy-gate-layer` in
    /// the model identity the header absorbs); `None` at every legacy shape.
    /// Block stage `k` is proved and verified at [`ClassifyRunStatement::stage_shape`],
    /// as native R13's `LayerRecord::shape_at` / `RunStatement::stage_shape`.
    stage_gate: Vec<Option<u32>>,
    /// **THE PUBLIC VERDICT** (1 = flagged: `Delta > c`)
    verdict: u8,
    /// D41: this proof's chunk of its item (one chunk: the whole content)
    chunk: ChunkRef,
    /// ROUND 14 (N-r13-1): the bound tables' trained-statement profile digest
    /// (the prover's and the verifier's tables must be bound to the same)
    tables_profile_sha256: [u8; 32],
    /// test builds: whether the tables came from the tied derivation (the
    /// relation tests' synthetic binding does not; the capture replay refuses it)
    tables_derived: bool,
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
    // the L blocks (A, H, M) and the L + 1 boundaries, under the block
    // profile's regime (W16R2 review F6; the token run's helper, same order)
    let (special, special_field) = super::run::push_block_openings(sh, l, &mut col);
    let mut lk = vec![super::stage_out_c::logup_size(&super::stage_out_c::layout(sh, cp))];
    let field_log2 = 2.0 * (P as f64).log2();
    let column: f64 = col.iter().map(|x| x.exp2()).sum();
    let mut num: f64 = if let Some(blk_num) = super::run::r13_block_logup_numerator(sh) {
        // ROUND 16 (REVIEW_R13 §10 item 6): an R13 block's term is
        // (N + 4 T_d - 1) / p^2 (degree-2 ACT3 / DD tuples), stage OUT-C's the
        // legacy (N + 3 R - 1)
        let (n, r) = lk[0];
        (n + 3 * r - 1) as f64 + (l as u128 * blk_num) as f64
    } else {
        let blk = block_logup_size(sh);
        lk.extend(vec![blk; l]);
        lk.iter().map(|(n, r)| (*n + 3 * *r - 1) as f64).sum::<f64>()
    };
    let (n_in, r_in) = super::stage_in_c::logup_size(&super::stage_in_c::layout(sh, cp), cp);
    let lg = clog2(cp.d_pad) as u128;
    num += (n_in + r_in * (3 + lg) + cp.tokens as u128 * lg) as f64;
    let logup = num * (-field_log2).exp2();
    let omitted = super::run::omitted_bound(col.len(), special, special_field, l + 2);
    let total_log2 = (column + logup + omitted).log2();
    WholeRun { openings: col.len(), column_log2: column.log2(), logup_log2: logup.log2(), omitted_log2: omitted.log2(), total_log2, floor_bits: (-total_log2).floor() as u32, block_regime: sh.column_regime(), block_regime_openings: special }
}

impl ClassifyRunStatement {
    /// The classifier door and the trained-model binding, in one constructor
    /// (both sides; the verifier passes the PUBLISHED verdict): an item of
    /// ONE chunk (its whole content, `n` ids; round 14: `n` may be shorter
    /// than a chunk).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        rs: RunShape,
        context: Digest,
        block_digests: Vec<Digest>,
        model: &TrainedModelStatement,
        tables: &super::classify_tied::BoundClassifierTables,
        policy: &Policy,
        n: usize,
        tier: Tier,
        in_root: Digest,
        verdict: u8,
    ) -> Result<ClassifyRunStatement, String> {
        ClassifyRunStatement::new_chunk(rs, context, block_digests, model, tables, policy, n, tier, in_root, verdict, n, 0)
    }

    /// **D41: chunk `chunk_index` of an item of `total` content ids.** The
    /// chunk's range is DERIVED from (total, index, the profile's plan: size
    /// `T - P0 - S`, the registered overlap), never taken as given, and `n`
    /// must be its length (round 14: a short item's one chunk is `[0, total)`).
    /// **ROUND 14 (N-r13-1):** the tables are [`BoundClassifierTables`]
    /// (`super::classify_tied`), and they must be bound to THIS trained
    /// statement, this policy and this profile's tied source; BOS and the
    /// final norm are theirs (no separate argument).
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_chunk(
        rs: RunShape,
        context: Digest,
        block_digests: Vec<Digest>,
        model: &TrainedModelStatement,
        tables: &super::classify_tied::BoundClassifierTables,
        policy: &Policy,
        n: usize,
        tier: Tier,
        in_root: Digest,
        verdict: u8,
        total: usize,
        chunk_index: usize,
    ) -> Result<ClassifyRunStatement, String> {
        if !super::super::run::is_classify_run_profile(rs.profile()) {
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
        // N-r13-1: the tables are bound to this trained statement and policy
        tables.check_for(sh, rs.profile(), model, policy)?;
        let cp = ClassifierProfile::new(sh, tables.tables(), tables.bos(), tables.norm(), policy, n, tier)?;
        let size = sh.tokens.checked_sub(policy.prefix.len() + policy.suffix.len()).filter(|x| *x > 0).ok_or("classifier run: the policy's template leaves no content position")?;
        let chunk = ChunkRef::derive(total, chunk_index, ChunkPlan { size, overlap: chunk_overlap_of(rs.profile())? })?;
        if chunk.b - chunk.a != n {
            return Err(format!("classifier run: chunk {} of a {total}-id content holds {} ids; the statement's n is {n}", chunk.index, chunk.b - chunk.a));
        }
        let in_spec = input_endpoint_spec(sh, context, &cp)?;
        let whole_run = whole_run_of_classifier(sh, l, &cp);
        let base = sh.norm_calibration();
        let mut stage_cal = vec![base; l];
        let mut stage_gate: Vec<Option<u32>> = vec![None; l];
        for (k, r) in model.layers.iter().enumerate() {
            if block_digests.get(k) != Some(&r.block_digest) {
                return Err(format!("classifier run: layer record {k} (layer {}) is not block {k}'s digest (review TR3-3)", r.index));
            }
            // ROUND 16 (REVIEW_R13 §10 item 3): an R13 layer carries exactly one
            // class-checked gate denominator, a legacy layer none (native
            // `LayerRecord::check_accuracy_gate`)
            r.check_accuracy_gate(sh).map_err(|e| format!("classifier run: layer {}: {e}", r.index))?;
            stage_gate[k] = r.accuracy_gate_shift;
            if has_own(&r.own) {
                let cal = apply_own(&base, &r.own).map_err(|e| format!("classifier run: layer {}: {e}", r.index))?;
                sh.with_layer_calibration(&cal).map_err(|e| format!("classifier run: layer {}'s own calibration: {e}", r.index))?;
                stage_cal[k] = cal;
            }
        }
        let st = ClassifyRunStatement { rs, context, block_digests, model_identity: model.identity(), cp, in_spec, in_root, scale: scales.0, whole_run, stage_cal, stage_gate, verdict, chunk, tables_profile_sha256: tables.profile_sha256(), tables_derived: tables.is_derived() };
        // ROUND 16: every stage shape is buildable before anything else can use it
        for k in 0..l {
            st.stage_shape(k)?;
        }
        Ok(st)
    }

    /// **ROUND 14 (N-r13-1): the prover's and the verifier's tables are the
    /// statement's**: bound to its trained statement and profile digest, with
    /// its embedding and margin digests, BOS and final norm
    pub(crate) fn check_tables(&self, t: &super::classify_tied::BoundClassifierTables) -> Result<(), String> {
        if t.model_identity() != self.model_identity || t.profile_sha256() != self.tables_profile_sha256 || t.is_derived() != self.tables_derived {
            return Err("classifier run: the tables handed are bound to another trained statement than the statement's (N-r13-1)".into());
        }
        if t.tables().emb_digest() != self.cp.emb_digest || t.tables().w_digest() != self.cp.w_digest || t.bos() != self.cp.bos || t.norm() != self.cp.norm {
            return Err("classifier run: the tables handed are not the ones the statement names".into());
        }
        Ok(())
    }

    /// test builds: whether the statement's tables came from the tied derivation
    #[cfg(test)]
    pub(crate) fn tables_derived(&self) -> bool {
        self.tables_derived
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
    /// the shape block stage `k` is proved and verified at (NATIVE R8, as the
    /// token run; **ROUND 16, native R13's `RunStatement::stage_shape`**: at an
    /// R13 shape, then at the layer record's bound gate denominator — without
    /// it every R13 stage would be the run seed's G = 17 and fail closed)
    pub(crate) fn stage_shape(&self, k: usize) -> Result<Shape, String> {
        let cal = *self.stage_cal.get(k).ok_or_else(|| format!("classifier run: no block stage {k}"))?;
        let sh = if cal == self.sh().norm_calibration() { self.sh().clone() } else { self.sh().with_layer_calibration(&cal)? };
        if sh.accuracy_stack() == super::super::accuracy_precision::Stack::Legacy {
            if self.stage_gate.get(k).copied().flatten().is_some() {
                return Err(format!("classifier run: block stage {k} is legacy but carries an R13 gate denominator"));
            }
            Ok(sh)
        } else {
            let g = self.stage_gate.get(k).copied().flatten().ok_or_else(|| format!("classifier run: block stage {k} carries no R13 gate denominator"))?;
            sh.with_accuracy_gate_shift(g)
        }
    }
    /// ROUND 16: block stage `k`'s R13 gate denominator (`None` at a legacy shape)
    pub(crate) fn stage_gate(&self, k: usize) -> Option<u32> {
        self.stage_gate.get(k).copied().flatten()
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
            "{}/L{}/boundaries-B_in-B_out-and-interior-log_n{}-rate{}-pad{}-rows{}-sites2/token-endpoint-in-log_n{}-rate{}-pad{}-words{}-rows{}-sites1/no-output-endpoint/stages-log_n{}-rate{}-pad{}/{}/{}/one-run-one-transcript",
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
            super::run::whole_run_words(&self.whole_run, "column-plus-logup-derived-plus-pcs-field-and-sumcheck-bound")
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
            // ROUND 16: an R13 stage names its bound gate denominator (legacy
            // stage lines are byte for byte what they were)
            if let Some(g) = self.stage_gate[k] {
                own.push_str(&format!("; R13 gate denominator {g} (the layer record's accuracy-gate-layer)"));
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
            self.cp.verdict_row(),
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

    /// **ROUND 12 (gate round 16, capture request 2.3): the run capture's
    /// header** — the block part as for a token run (the same six header
    /// words, `run-shape` eleven u64 long), plus [`ClassifyFacts`] with the
    /// verdict and the chunk the header absorbs last. Test builds only.
    #[cfg(test)]
    pub(crate) fn capture_header(&self) -> Result<super::super::run_capture::RunHeader, String> {
        use super::super::run_capture::{BoundaryFacts, ClassifyFacts, RunHeader, TokenEndpointFacts};
        let sh = self.sh();
        let cp = &self.cp;
        let t = cp.tier;
        let mut boundaries = Vec::with_capacity(self.l() + 1);
        for j in 0..=self.l() {
            let spec = self.boundary_spec(j)?;
            boundaries.push(BoundaryFacts {
                index: j,
                scale: spec.scale(),
                sites: spec.sites(),
                data_rows: spec.data_rows(),
                rows: spec.commitment_rows(),
                site_rows: spec.site_rows(),
                prox_row: spec.prox_row(),
                log_n: spec.log_n(),
                inv_rate: sh.endpoint_inv_rate,
                checks: sh.opened_cols,
                digest: spec.digest(),
                plane: (sh.t_pad, sh.d_pad),
            });
        }
        let e = &self.in_spec;
        let d = e.data_rows();
        let input_endpoint = TokenEndpointFacts { rows: e.commitment_rows(), data_rows: d, sites: 1, site_rows: vec![d, d + 1], prox_row: d + 2, log_n: t.ep_log_n, inv_rate: t.ep_inv_rate, checks: t.opened_cols, plane: (1, e.len()), digest: e.digest(), scale: 0 };
        let ch = self.chunk;
        let classify = ClassifyFacts {
            run_profile: self.profile(),
            v: cp.v,
            v_pad: cp.v_pad,
            tokens: cp.tokens,
            t_pad: cp.t_pad,
            d: cp.d,
            d_pad: cp.d_pad,
            p0: cp.p0(),
            n: cp.n,
            s: cp.policy.suffix.len(),
            profile_text: cp.describe_under(self.profile()),
            profile_digest: cp.digest_under(self.profile()),
            policy_id: cp.policy.id.clone(),
            prefix: cp.policy.prefix.clone(),
            suffix: cp.policy.suffix.clone(),
            num_special: cp.policy.num_special,
            yes: cp.policy.yes,
            no: cp.policy.no,
            c: cp.policy.c,
            tokenizer: cp.policy.tokenizer.clone(),
            template_digest: cp.template_digest(),
            w_digest: cp.w_digest,
            emb_digest: cp.emb_digest,
            bos: cp.bos,
            final_norm: (cp.norm.g0, cp.norm.cn, cp.norm.tn, cp.norm.ceps),
            wrho: cp.wrho,
            d_max: cp.d_max,
            window_bits: cp.window_bits,
            limbs: cp.limbs,
            lam_base: LAM_BASE,
            tier: (t.name, t.opened_cols, t.stage_log_n, t.stage_inv_rate, t.ep_log_n, t.ep_inv_rate),
            scale: self.scale,
            input_endpoint,
            input_root: self.in_root,
            boundaries: boundaries.clone(),
            r_emb_len: clog2(cp.d_pad),
            stage_layouts: [super::stage_in_c::layout(sh, cp).describe(), super::stage_out_c::layout(sh, cp).describe()],
            verdict: self.verdict,
            chunk: [ch.index, ch.count, ch.a, ch.b, ch.total, ch.size, ch.overlap],
            tables_derived: self.tables_derived,
        };
        Ok(RunHeader {
            profile: self.profile(),
            l: self.l(),
            sh: sh.clone(),
            run_shape_words: [self.l(), sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, cp.v, cp.p0(), cp.n, cp.policy.suffix.len()].iter().map(|v| *v as u64).collect(),
            expected_bytes: self.expected_bytes(),
            public_statement: self.public_statement(),
            parameter_line: self.parameter_line()?,
            calibration: self.calibration(),
            schedule_digest: self.schedule_digest()?,
            context: self.context,
            block_digests: self.block_digests.clone(),
            boundary_scales: vec![self.scale; self.l() + 1],
            external_input_root: self.in_root,
            // a classifier run has NO output endpoint
            external_output_root: [0; 32],
            external_rows: self.in_spec.commitment_rows(),
            external_data_rows: self.in_spec.data_rows(),
            external_log_n: t.ep_log_n,
            external_inv_rate: t.ep_inv_rate,
            stage_lines: self.stage_lines()?,
            layout_description: Layout::for_shape(sh)?.describe(),
            boundaries,
            external_scales: (0, 0),
            token: None,
            classify: Some(classify),
        })
    }

    /// the run binding (the header transcript's state), for the capture
    #[cfg(test)]
    pub(crate) fn binding(&self) -> Result<Digest, String> {
        Ok(self.transcript()?.state())
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
