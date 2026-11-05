//! The component transcript: header -> A root -> M root -> (beta, gamma,
//! alpha) -> H root -> the twenty-three slots -> ONE M opening -> ONE opening
//! per hiding commitment (A, H, input endpoint, output endpoint), in that order.
//!
//! Every private owner (the OS randomness stream, A, H, M, both endpoint
//! planes) is created or consumed inside ONE `prove_inner` call and dropped
//! before it returns, on success and on failure. There is no seed, no
//! prepared-commitment handle and no second opening of anything.

use super::argument::{argument, table_values_act, table_values_exp, table_values_u8, Ctx, ProverData, Side};
use super::layout::*;
use super::shape::Shape;
// STAGE 11: the phase clock. `ph` is WRITE-ONLY here — every call below pushes
// a duration, a row count and a memory reading and returns `()`, and no branch
// of this file reads the recorder back. With `HL_PB_TIMING` unset each call
// returns on its first line.
use super::timing::{self, Half};
use super::witness::Witness;
use super::{BlockPublic, Endpoints, ExpectedIo, ProveStats, Receipt};
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};
use crate::transcript::Transcript;
use crate::zk::{self, ZkRng};

/// **STAGE 9, THE 125M TABLE.** This was the constant `NTT_LOG = 12`, and 125M needs
/// `2^16` for its `A` / `H` encoding (`log_cols 14` at rate 1/4). It is a
/// FUNCTION OF THE SHAPE now, and never smaller than the mask commitment's
/// own fixed `2^12` domain (`zk::MASK_LOG_DOM`, which no shape moves).
///
/// Why this is safe for the frozen toy, by construction and not by argument:
/// at the toy the maximum is `max(8 + 3, 12) = 12`, so the table it is handed
/// is `NttTables::new(12)` exactly as before, and the same holds at both rung
/// profiles (`max(10 + 2, 12) = 12`). Only 125M gets a different table. (The
/// two endpoint commitments never see this table at all: `prepare_endpoints`
/// builds one per construction — `new(12)` for the frozen seam, which demands
/// that size exactly, and `new(enc_log)` for the generalised endpoint —
/// finding S11b-F3.)
pub(super) fn ntt_log_at(sh: &Shape) -> u32 {
    ((sh.log_cols + log2_exact(sh.inv_rate)) as u32).max(zk::MASK_LOG_DOM)
}

/// A bounded prototype ceiling, not a soundness bound. `2^20` is 16x the 125M
/// shape's `2^16` and well inside the field's two-adic range; it exists so
/// that a malformed shape cannot ask for an unbounded table.
const NTT_LOG_MAX: u32 = 20;

fn log2_exact(v: usize) -> usize {
    debug_assert!(v.is_power_of_two(), "a power of two");
    v.trailing_zeros() as usize
}

/// The shapes this module can prove at today. A refusal here is a capability
/// statement, not a soundness one. Since stage 9 the table follows the shape,
/// so what is left to refuse is a shape past the prototype ceiling — and the
/// ENDPOINT's own encoding domain, which is built by a different table and
/// whose two constructions have their own, different ceilings.
pub(crate) fn fits_the_ntt_tables(sh: &Shape) -> Result<(), String> {
    let need = [ntt_log_at(sh) as usize, sh.endpoint_log_n + log2_exact(sh.endpoint_inv_rate)];
    if need.iter().any(|k| *k > NTT_LOG_MAX as usize) {
        return Err(format!("private block: this shape's evaluation domain (2^{}) exceeds the module's ceiling (2^{NTT_LOG_MAX})", need.iter().max().expect("two entries")));
    }
    Ok(())
}

/// **STEP C part 2 / S10.** The PCS parameters of a shape: at the toy
/// `log_cols 8`, rate 1/8, `Q = 256`; at the development rung `log_cols 10`,
/// rate 1/4, `Q = 256`. The pad count and the number of opened columns move
/// together — both are `sh.opened_cols` — because `ZkOpts::standard` takes its
/// `q_pad` from `num_col_checks`.
pub(crate) fn pcs_params_at(sh: &Shape) -> PcsParams {
    PcsParams { log_cols: sh.log_cols as u32, inv_rate: sh.inv_rate, num_col_checks: sh.opened_cols }
}

/// the toy profile's PCS parameters (the signature `native_capture.rs` calls)
pub(crate) fn pcs_params() -> PcsParams {
    pcs_params_at(&Shape::toy())
}

/// The PCS parameters of this shape's ENDPOINT geometry — the two external
/// endpoints and (by construction, `run::RunStatement::boundary_spec`) every
/// internal boundary. The same three fields were written out at three call
/// sites; they are one function now so that the T-4 path-length check and the
/// verifiers it guards cannot be reading two different geometries.
pub(crate) fn endpoint_pcs_params(sh: &Shape) -> PcsParams {
    PcsParams { log_cols: sh.endpoint_log_n as u32, inv_rate: sh.endpoint_inv_rate, num_col_checks: sh.opened_cols }
}

/// **STAGE 17, ruling T-1.** A transcript constructed under this profile's
/// hash tag: `Transcript::new` for a legacy-rule profile (the byte-frozen toy
/// and the frozen-seam rung), `Transcript::new_tagged` under its Fiat–Shamir
/// key for every other. [`Shape::hash_tag`] is the one place that choice is
/// made, and every transcript on this path — a block's, a run's, and the run
/// capture's independent rebuild — is built here.
pub(crate) fn tagged_transcript(sh: &Shape, domain: &[u8]) -> Transcript {
    match sh.hash_tag().transcript_key() {
        None => Transcript::new(domain),
        Some(k) => Transcript::new_tagged(domain, *k),
    }
}

/// Header, public statement, endpoint policy and calibration first; no
/// challenge precedes them. The order is T1 section D steps 1-6: PROFILE,
/// `"expected-IO"`, `"public-statement"` (ONE digest over the attention AND
/// feed-forward words), `"parameters"`, `"calibration"`, `"schedule"`.
///
/// **STEP C part 2.** The profile string and the parameter line are the
/// LAYOUT'S OWN SHAPE's, not the toy's (D17: a new shape is a new profile, and
/// it separates its transcript). At `Shape::toy()` the formatted line is the
/// frozen literal byte for byte — `the_toy_parameter_line_is_the_frozen_literal`
/// pins it — so no toy byte moves.
pub(crate) fn transcript(public: &BlockPublic, expected: &ExpectedIo, lay: &Layout) -> Transcript {
    let sh = lay.shape();
    // R2-4 / review finding F-2, defence in depth: the single-block
    // transcript absorbs the synthetic calibration literal below, so it is
    // never built at a trained-calibration shape (both callers refuse first)
    assert!(single_block_profile_allowed(sh).is_ok(), "private block: the single-block transcript at a trained-calibration shape");
    let mut tr = tagged_transcript(sh, sh.profile.as_bytes());
    tr.absorb(b"expected-IO", &expected.to_bytes());
    tr.absorb(b"public-statement", &public.digest());
    tr.absorb(b"parameters", parameter_line(sh).as_bytes());
    // D12 item 5: a receipt cannot be replayed under another approved calibration
    tr.absorb(b"calibration", &super::calibration_identity());
    tr.absorb(b"schedule", &lay.schedule_digest());
    tr
}

/// The `"parameters"` word of the transcript, as a function of the shape. The
/// three feed-forward shifts are calibration constants of the profile family,
/// not shape fields, so they stay literal.
pub(crate) fn parameter_line(sh: &Shape) -> String {
    let base = format!(
        "T{}/d{}/f{}/H{}/KV{}/dh{}/log_cols{}/inv_rate{}/Q{}/P1/sh-g{}-u0-h{}-z{}/two-private-endpoints/one-proof-one-transcript",
        sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, sh.log_cols, sh.inv_rate, sh.opened_cols, sh.sh_g, sh.sh_h, sh.sh_z
    );
    if sh.is_frozen_toy() {
        // D17: the toy's line is a frozen literal and gains nothing, ever.
        return base;
    }
    // **THE SECURITY OWNER'S RULING ON STAGE 8's FINDING S11b-F4 (2026-09-20).**
    // The endpoint's commitment parameters reached the transcript only through
    // the endpoint DIGEST, which is a hash the reader of a receipt cannot
    // unfold. In every NEW profile they are stated outright as well, so that
    // the four numbers a verifier's endpoint geometry depends on — the
    // commitment's row width, its inverse rate, its pad count and its row
    // count — are bound to the transcript in a form a human can read. The
    // digest still binds them; this is a second, explicit binding and not a
    // replacement. The toy's bytes do not move; the two development rung
    // profiles' receipts change value (not length), which ruling P-7 allows.
    format!("{base}/endpoint-log_n{}-rate{}-pad{}-rows{}", sh.endpoint_log_n, sh.endpoint_inv_rate, sh.opened_cols, sh.endpoint_rows)
}

pub(super) fn absorb_root(tr: &mut Transcript, label: &[u8], root: &[u8; 32], rows: usize, log_cols: usize) {
    tr.absorb(label, root);
    tr.absorb_u64(b"rows", rows as u64);
    tr.absorb_u64(b"log-cols", log_cols as u64);
}

pub(super) fn commitment(root: [u8; 32], rows: usize, log_cols: usize) -> Commitment {
    Commitment { root, rows, log_cols: log_cols as u32 }
}

/// The value-0 LogUp identity: every witness helper minus the two table helpers plus the
/// zero-sum pair `u`, as ONE all-ones sum claim. No helper sum is ever published.
///
/// `pub(crate)` for ONE reason (step S4): the B-3 acceptance test rebuilds
/// this claim at the development rung's geometry, and it has to be able to
/// show that its reconstruction agrees with THIS function at the toy before
/// anything it says about the rung means anything.
pub(crate) fn logup_sum_claim(lay: &Layout) -> ZClaim {
    let (sh, hids) = (lay.shape(), lay.hids());
    let mut parts = Vec::with_capacity(2 * hids.n_h());
    // (test builds: the lapse of D30 condition 3 leaves the dictionary's two
    // LogUp columns out of the single sum claim)
    let out_of_sum = sh.dd_cap > 0 && super::argument::dd_lapse(super::argument::DD_LAPSE_OUT_OF_SUM);
    for p in lay.h_planes() {
        if out_of_sum && (p == hids.stuple() || p == hids.gdd()) {
            continue;
        }
        let sign = if hids.is_table(p) { Fp2::ONE.neg() } else { Fp2::ONE };
        let (re, im) = lay.h_off[p];
        let log_size = sh.log(hids.dom(p)) as u32;
        parts.push(ZPart { slice: Slice { offset: re, log_size }, coef: sign, point: vec![] });
        parts.push(ZPart { slice: Slice { offset: im, log_size }, coef: sign.mul(Fp2::U), point: vec![] });
    }
    ZClaim { parts, value: Fp2::ZERO }
}

// ---------------------------------------------------------------- opening refusals

pub(crate) type PartKey = (Vec<Fp2>, usize, usize);

/// the PCS column-weight key of a part (zkp_core::pcs::zpart_weights' rule) at
/// a row width of `1 << log_n`
pub(crate) fn part_key_at(p: &ZPart, log_n: usize) -> PartKey {
    let n = 1usize << log_n;
    let ls = p.slice.log_size as usize;
    let (c0, len) = if ls >= log_n { (0, n) } else { (p.slice.offset % n, 1usize << ls) };
    let tail = if p.point.is_empty() { vec![] } else { p.point[ls.saturating_sub(log_n)..].to_vec() };
    (tail, c0, len)
}

/// The column-weight groups a set of claims raises at a row width of
/// `1 << log_n`, in FIRST-OCCURRENCE order — the grouping the PCS itself
/// forms. A single claim whose own parts disagree on a key cannot be opened at
/// all (`zkp-core/src/pcs.rs` asserts), so it is refused here first. Taking
/// `log_n` as a parameter is what lets the row-width bug B-3 be reproduced as
/// a test at a geometry this module cannot yet be instantiated at.
pub(crate) fn opening_groups_at(claims: &[ZClaim], log_n: usize) -> Result<Vec<(PartKey, usize)>, String> {
    let mut groups: Vec<(PartKey, usize)> = Vec::new();
    for claim in claims {
        let key = part_key_at(&claim.parts[0], log_n);
        if claim.parts.iter().any(|p| part_key_at(p, log_n) != key) {
            return Err("private block: claim parts with different column weights".into());
        }
        match groups.iter_mut().find(|(k, _)| *k == key) {
            Some((_, count)) => *count += 1,
            None => groups.push((key, 1)),
        }
    }
    Ok(groups)
}

fn part_rows(p: &ZPart, n: usize) -> std::ops::Range<usize> {
    let r0 = p.slice.offset / n;
    r0..r0 + (1usize << p.slice.log_size).div_ceil(n)
}

/// THE SCHEDULE AUDIT (whole commitment, not one site): every reserved pair row is
/// touched by exactly ONE claim with a nonzero coefficient; every evaluation claim
/// touches exactly one pair (its own, two adjacent rows); only the sum claim may be
/// pairless, and it must cover the zero-sum rows; nothing but the proximity
/// combination touches the proximity pair. With that, the map from (one pair per
/// group, the proximity pair) to (group vectors, proximity vector) is block
/// triangular with invertible diagonal, so the opened vectors are jointly uniform
/// whatever the data is. PREMISE, not proven here: independence from the sampled
/// columns, the salted paths and the CFS channel (the joint-view gate of the
/// construction section 7 is still owed on captured receipts).
///
/// **D63 L4 finding 3.** "Invertible diagonal" needs each pair's two row weights to
/// be linearly independent over the BASE field (the mask rows are base-field rows),
/// which a nonzero coefficient alone does not give. The audit therefore computes the
/// weights the claim actually induces on its pair (`pcs::zpart_row_weight`, its point
/// included) and refuses a zero determinant, for every evaluation claim and for the
/// sum claim's zero-sum pair. A nonzero member coefficient `c` of the opening's group
/// keeps the pair independent (`det(c a, c b) = N(c) det(a, b)`, and `N(c) != 0` since
/// 7 is a non-residue), so the per-claim check suffices.
pub(crate) fn audit_claims(claims: &[ZClaim], n: usize, rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize) -> Result<(), String> {
    let fail = |what: &str| Err(format!("private block: mask schedule audit: {what}"));
    if prox + 2 != rows || site_rows.len() % 2 != 0 {
        return fail("proximity pair placement");
    }
    if !n.is_power_of_two() {
        return fail("the row width is not a power of two");
    }
    let log_n = n.trailing_zeros() as usize;
    let mut uses = vec![0usize; rows];
    let is_site = |r: usize| site_rows.binary_search(&r).is_ok();
    for (ci, claim) in claims.iter().enumerate() {
        let mut touched: Vec<usize> = Vec::new();
        for part in &claim.parts {
            let pr = part_rows(part, n);
            if pr.end > prox {
                return fail("a claim reaches the proximity pair or leaves the commitment");
            }
            for r in pr.filter(|r| is_site(*r)) {
                if part.coef.is_zero() {
                    return fail("zero terminal mask coefficient; discard attempt");
                }
                touched.push(r);
            }
        }
        let is_sum = claim.parts.iter().all(|p| p.point.is_empty());
        let weight = |row: usize| claim.parts.iter().fold(Fp2::ZERO, |acc, p| acc.add(pcs::zpart_row_weight(p, log_n, row)));
        match (is_sum, sum_rows) {
            (true, Some(u)) if ci + 1 == claims.len() => {
                let covered = |row: usize| claim.parts.iter().any(|p| part_rows(p, n).contains(&row) && !p.coef.is_zero());
                if !touched.is_empty() || !covered(u[0]) || !covered(u[1]) {
                    return fail("the sum claim is not masked by the zero-sum pair alone");
                }
                if determinant(weight(u[0]), weight(u[1])).is_zero() {
                    return fail("the zero-sum pair's weights are dependent over the base field");
                }
            }
            (false, _) => {
                if touched.len() != 2 || touched[1] != touched[0] + 1 || (touched[0] - site_rows[0]) % 2 != 0 {
                    return fail("a claim does not carry exactly its own reserved pair");
                }
                if determinant(weight(touched[0]), weight(touched[1])).is_zero() {
                    return fail("a claim's reserved pair weights are dependent over the base field");
                }
            }
            _ => return fail("unexpected sum claim"),
        }
        for r in touched {
            uses[r] += 1;
        }
    }
    if site_rows.iter().any(|r| uses[*r] != 1) {
        return fail("a reserved pair is unused or shared between claims");
    }
    Ok(())
}

fn determinant(a: Fp2, b: Fp2) -> Fp {
    a.c0.mul(b.c1).sub(a.c1.mul(b.c0))
}

/// Refusal logic with an injectable draw (deterministic negative controls); the live
/// caller draws once from a CLONED PCS challenge prefix and never resamples.
pub(crate) fn check_opening_challenges(groups: &[usize], rows: usize, prox: usize, mut draw: impl FnMut() -> Fp2) -> Result<(), String> {
    for &count in groups {
        if (0..count).map(|_| draw()).any(|c| c.is_zero()) {
            return Err("zero group member coefficient; discard attempt".into());
        }
    }
    let rho: Vec<Fp2> = (0..rows).map(|_| draw()).collect();
    if prox + 1 >= rows || determinant(rho[prox], rho[prox + 1]).is_zero() {
        return Err("dependent proximity mask coefficients; discard attempt".into());
    }
    Ok(())
}

/// Audit, exact group count, and the challenge refusals of ONE opening. Public inputs only.
#[allow(clippy::too_many_arguments)]
pub(crate) fn check_opening(claims: &[ZClaim], log_n: usize, rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize, want_groups: usize, tr: &Transcript) -> Result<(), String> {
    audit_claims(claims, 1usize << log_n, rows, site_rows, sum_rows, prox)?;
    // first-occurrence grouping, as the PCS forms it
    let groups = opening_groups_at(claims, log_n)?;
    if groups.len() != want_groups {
        return Err(format!("private block: {} opening groups, the schedule declares {want_groups}", groups.len()));
    }
    let counts: Vec<usize> = groups.iter().map(|(_, c)| *c).collect();
    let mut replay = Transcript::clone_state(tr);
    check_opening_challenges(&counts, rows, prox, || replay.challenge_fp2())
}

/// (claims of A, H, input endpoint, output endpoint), H closed by the LogUp sum claim
fn finish_claims(claims: [Vec<ZClaim>; 4], lay: &Layout) -> [Vec<ZClaim>; 4] {
    let [a, mut h, i, o] = claims;
    h.push(logup_sum_claim(lay));
    [a, h, i, o]
}

pub(crate) const ENDPOINT_ROWS: usize = 7;
const ENDPOINT_PROX: usize = 4;
/// `private_seam::MASK_ROWS`: the terminal pair and three proximity rows that
/// sit above a seam commitment's data rows, at every shape the seam accepts.
const ENDPOINT_MASK_ROWS: usize = 5;

/// The endpoint geometry of a shape: `(rows, data rows, proximity row)`. The
/// toy's is the frozen `(7, 2, 4)`.
///
/// **S11a.** A `private_seam` commitment is `data` rows, the terminal pair at
/// `(data, data + 1)` and three proximity rows from `data + 2`, so
/// `rows = data + MASK_ROWS` with `MASK_ROWS = 5` and the geometry is
/// `(rows, rows - 5, rows - 3)` at every shape the frozen seam accepts. At
/// the rung that is 21 rows: the PADDED `(32, 128)` endpoint is 4,096 words,
/// exactly the seam's ceiling, and `4096 / 256 = 16` data rows. **S11b is
/// still owed**: 125M's endpoint plane is 393,216 words (`log_len` 19 against
/// `MAX_LOG_LEN` 12) and the frozen seam cannot carry it at all, so a
/// generalised endpoint must be built BESIDE `private_seam.rs` and the rung
/// re-run with it before anything runs at 125M.
pub(super) fn endpoint_geometry(sh: &Shape) -> Result<(usize, usize, usize), String> {
    let rows = sh.endpoint_rows;
    if rows <= ENDPOINT_MASK_ROWS {
        return Err(format!("private block: endpoint geometry of {rows} rows has no data rows"));
    }
    let g = (rows, rows - ENDPOINT_MASK_ROWS, rows - ENDPOINT_MASK_ROWS + 2);
    // **FINDING F-1's sweep.** This was a `debug_assert!`, which the release
    // profile — the only one anything is proved in — compiles out. It costs
    // two comparisons to make it a refusal, and what it pins is the FROZEN
    // toy's endpoint geometry, so it is a real check now.
    if rows == ENDPOINT_ROWS && g != (ENDPOINT_ROWS, 2, ENDPOINT_PROX) {
        return Err("private block: the toy's frozen endpoint geometry moved".into());
    }
    Ok(g)
}

// The endpoint planes are `private_seam` commitments: 2 data rows, the terminal pair
// (2, 3) and three proximity rows from row 4. The seven-row geometry does not end in
// its proximity pair, so the one claim's shape is checked directly; the challenge
// refusals require rows (4, 5) independent, exactly as the repaired FFN IO profile.
pub(super) fn check_endpoint_opening(claims: &[ZClaim], sh: &Shape, tr: &Transcript) -> Result<(), String> {
    let (rows, data, prox) = endpoint_geometry(sh)?;
    let n = 1usize << sh.endpoint_log_n;
    let ok = claims.len() == 1
        && claims[0].parts.len() == 3
        && part_rows(&claims[0].parts[0], n) == (0..data)
        && part_rows(&claims[0].parts[1], n) == (data..data + 1)
        && part_rows(&claims[0].parts[2], n) == (data + 1..data + 2)
        && claims[0].parts.iter().all(|p| !p.coef.is_zero());
    if !ok {
        return Err("private block: endpoint claim differs from the declared schedule".into());
    }
    let mut replay = Transcript::clone_state(tr);
    check_opening_challenges(&[1], rows, prox, || replay.challenge_fp2())
}

// ---------------------------------------------------------------- prover

/// integer lookup values per lookup of a domain, over the domain's PADDED
/// extent at this layout's shape (`Dom::len()` is the toy's)
pub(super) fn lookup_values(lay: &Layout, wit: &Witness, dom: Dom) -> Vec<Vec<i64>> {
    lookup_values_at(lay, wit, dom, LOOKUP_PAR_MIN)
}

/// **STAGE 29 (finding S28-R1).** The word count above which the looked
/// columns of a domain are built in parallel, as stage 28 chose it: a constant
/// of the PRODUCTION call and an ARGUMENT of [`lookup_values_at`].
pub(super) const LOOKUP_PAR_MIN: usize = 1 << 17;

pub(super) fn lookup_values_at(lay: &Layout, wit: &Witness, dom: Dom, par_min: usize) -> Vec<Vec<i64>> {
    let len = lay.shape().size(dom);
    let lks = lay.lookups(dom);
    let col = |l: &Lk| -> Vec<i64> { (0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(wit.planes[*p][x])))).collect() };
    // **STAGE 28.** Each column is an independent per-index map of wrapping
    // integer arithmetic. The parallel iterator is INDEXED, so the columns
    // come back in their own order with their own words; small domains stay
    // on one thread.
    if lks.len() > 1 && lks.len() * len >= par_min {
        use rayon::prelude::*;
        return lks.par_iter().map(&col).collect();
    }
    lks.iter().map(col).collect()
}

/// **STAGE 29 (finding S28-R1).** The word count above which the byte
/// histogram is summed in chunks, as stage 28 chose it: a constant of the
/// PRODUCTION call and an ARGUMENT of [`byte_histogram_at`].
pub(super) const HISTOGRAM_PAR_MIN: u64 = 1 << 17;

/// **STAGE 28, extracted in STAGE 29.** The `U8_LEN` byte multiplicities of
/// every looked column of every lookup domain.
///
/// A histogram is a sum of integers: partitioning the words changes no bin,
/// and the bins are added back in a fixed order, so the chunked form is the
/// serial form's vector. The serial form stays for small shapes. (A value
/// outside the table counts into entry 0, exactly as before: only the LogUp
/// identity can catch it.) `lookup_words` is the PUBLIC word count of the
/// shape, which is what chooses the branch — never a witness value.
/// **RULING CS-3** (ported from the 125M lane, stage 40). How many looked
/// words are outside the byte table — the words [`byte_histogram_at`] files
/// in entry 0. A count of public-length columns, parallel above the same
/// public threshold as the histogram.
fn u8_misses_of(looked: &[(Dom, Vec<Vec<i64>>)], lookup_words: u64) -> usize {
    let miss = |c: &Vec<i64>| c.iter().filter(|v| !(0..U8_LEN as i64).contains(*v)).count();
    if lookup_words >= HISTOGRAM_PAR_MIN {
        use rayon::prelude::*;
        let cols: Vec<&Vec<i64>> = looked.iter().flat_map(|(_, cols)| cols.iter()).collect();
        return cols.par_iter().map(|c| miss(c)).sum();
    }
    looked.iter().flat_map(|(_, cols)| cols.iter()).map(miss).sum()
}

/// **RULING CS-3's name.**
pub(super) const LOOKUP_MISS_REFUSAL: &str = "private block: ruling CS-3 — the witness looks up a value that is not a row of its table";

/// **RULING CS-3: the ONE refusal of a lookup miss** (text per errata K-1
/// and K-2: what precedes the refusal, and the CLASS of the miss only, never
/// a count). A CHEATING prover does not run this check, and the soundness
/// tests play one: under `#[cfg(test)]` a thread-local switch
/// ([`CheatingProver`]) makes it return `Ok`. A release build has no switch.
fn refuse_lookup_misses(u8: usize, exp: usize, act: usize) -> Result<(), String> {
    #[cfg(test)]
    if CHEATING_PROVER.with(|c| c.get()) {
        return Ok(());
    }
    if u8 + exp + act == 0 {
        return Ok(());
    }
    let families: Vec<&str> = [(u8, "the byte table"), (exp, "the exp table"), (act, "the activation table")].iter().filter(|(n, _)| *n > 0).map(|(_, f)| *f).collect();
    Err(format!(
        "{LOOKUP_MISS_REFUSAL}; the table family that missed: {} (the class of the miss only, never a count — ruling K-2). It is refused before this block's A mask rows are drawn, its A commitment is made or any challenge of it is drawn. What precedes the refusal: in a single block, the transcript header's absorbs; inside a run, the run header, every earlier stage, this stage's header absorbs and, below the last block, the boundary B_k to the next block, drawn from the run's stream, committed and absorbed (ruling M-9).",
        families.join(", ")
    ))
}

/// The exp lookups' histogram over the table's `U8_LEN` entries and the
/// count of looked pairs that are not a row of the table (ruling CS-3;
/// a miss is filed in entry 0, exactly as before). Shared by `prove_core`
/// and [`check_lookup_misses`].
fn exp_histogram(deltas: &[i64], e_plane: &[i64], exp: &[i64]) -> (Vec<u64>, usize) {
    // [ZK60-METAL M15] long columns counted over 64 Ki chunks in parallel and
    // summed (integer counts: the sequential loop's totals)
    if deltas.len() >= 1 << 17 {
        use rayon::prelude::*;
        const CH: usize = 1 << 16;
        return deltas
            .par_chunks(CH)
            .enumerate()
            .map(|(ci, ds)| {
                let mut m = vec![0u64; U8_LEN];
                let mut missed = 0usize;
                for (k, d) in ds.iter().enumerate() {
                    let hit = (0..U8_LEN as i64).contains(d) && exp[*d as usize] == e_plane[ci * CH + k];
                    missed += usize::from(!hit);
                    m[if hit { *d as usize } else { 0 }] += 1;
                }
                (m, missed)
            })
            .reduce(
                || (vec![0u64; U8_LEN], 0usize),
                |(mut x, mx), (y, my)| {
                    for (a, b) in x.iter_mut().zip(y) {
                        *a += b;
                    }
                    (x, mx + my)
                },
            );
    }
    let mut m = vec![0u64; U8_LEN];
    let mut missed = 0usize;
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(d) && exp[*d as usize] == e_plane[x];
        missed += usize::from(!hit);
        m[if hit { *d as usize } else { 0 }] += 1;
    }
    (m, missed)
}

/// The activation lookups' histogram and miss count (ruling CS-3), as
/// [`exp_histogram`].
fn act_histogram(idx: &[i64], a16_plane: &[i64], act: &[i16]) -> (Vec<u64>, usize) {
    let mut m = vec![0u64; U8_LEN];
    let mut missed = 0usize;
    for (x, i) in idx.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(i) && i64::from(act[*i as usize]) == a16_plane[x];
        missed += usize::from(!hit);
        m[if hit { *i as usize } else { 0 }] += 1;
    }
    (m, missed)
}

/// **NATIVE R9 (D30): the dictionary's tuples as the prover sees them.**
/// `(queries, table)`: per `Dom::S` position the score entry's compressed
/// tuple `gamma TAG_DD + Sum + beta (mask E) + beta^2 P`, and per `Dom::Dd`
/// slot the dictionary's `gamma TAG_DD + Sum + beta e + beta^2 P_dict`, with
/// `Sum` read at the position's `(h, t)` row (B-4) and `mask` the public
/// causal support. Shared by the prover's helper columns and (through the
/// integer form [`dd_misses`]) by the CS-3 check.
pub(crate) fn dd_tuples(lay: &Layout, wit: &Witness, ecol: &[i64], beta: Fp2, g_dd: Fp2) -> (Vec<Fp2>, Vec<Fp2>) {
    let (sh, ids) = (lay.shape(), lay.ids());
    let (tp, cap) = (sh.t_pad, sh.dd_cap);
    let beta2 = beta.mul(beta);
    let sum = &wit.planes[ids.at(A_SUM)];
    let (e, p) = (&wit.planes[ids.at(A_E)], &wit.planes[ids.at(A_P)]);
    // (test builds: the D-4 lapse drops the key on both sides)
    let keyed = !super::argument::dd_lapse(super::argument::DD_LAPSE_DROP_KEY);
    let tup = |s: i64, e: i64, p: i64| g_dd.add(if keyed { Fp2::from_i64(s) } else { Fp2::ZERO }).add(beta.mul(Fp2::from_i64(e))).add(beta2.mul(Fp2::from_i64(p)));
    let q: Vec<Fp2> = (0..sh.size(Dom::S))
        .map(|x| {
            let (ht, j) = (x / tp, x % tp);
            let me = if j <= ht % tp { e[x] } else { 0 };
            tup(sum[ht], me, p[x])
        })
        .collect();
    let pd = &wit.planes[ids.pdict()];
    let t: Vec<Fp2> = (0..sh.size(Dom::Dd)).map(|x| tup(sum[x / cap], ecol[x % cap], pd[x])).collect();
    (q, t)
}

/// **NATIVE R9 (D30, CHECK.md B-8): the defensive dictionary-miss count** —
/// how many score entries' integer tuples `(Sum, mask E, P)` are no tuple of
/// their own row's dictionary. Zero for any witness the builder admits.
pub(crate) fn dd_misses(lay: &Layout, wit: &Witness, ecol: &[i64]) -> usize {
    let (sh, ids) = (lay.shape(), lay.ids());
    let (tp, cap) = (sh.t_pad, sh.dd_cap);
    let (e, p, pd) = (&wit.planes[ids.at(A_E)], &wit.planes[ids.at(A_P)], &wit.planes[ids.pdict()]);
    (0..sh.size(Dom::S))
        .filter(|&x| {
            let (ht, j) = (x / tp, x % tp);
            let me = if j <= ht % tp { e[x] } else { 0 };
            !(0..cap).any(|k| ecol[k] == me && pd[ht * cap + k] == p[x])
        })
        .count()
}

/// **NATIVE R9: ruling CS-3's refusal for the dictionary family** (the class
/// of the miss only, never a count — K-2; a cheating prover skips it in test
/// builds exactly as [`refuse_lookup_misses`])
fn refuse_dictionary_misses(missed: usize) -> Result<(), String> {
    #[cfg(test)]
    if CHEATING_PROVER.with(|c| c.get()) {
        return Ok(());
    }
    if missed == 0 {
        return Ok(());
    }
    Err(format!("{LOOKUP_MISS_REFUSAL}; the table family that missed: the division dictionary (the class of the miss only, never a count — ruling K-2). It is refused before this block's A mask rows are drawn, its A commitment is made or any challenge of it is drawn."))
}

// CHECK.md D-8, TEST BUILDS ONLY: the multiplicities a cheating prover uses
// in the dictionary's table helper after alpha, against the honest `A` plane
#[cfg(test)]
thread_local! {
    static DD_MOVED_MULTIPLICITY: std::cell::Cell<Option<(usize, usize)>> = const { std::cell::Cell::new(None) };
}

/// TEST ONLY: while set, the prover moves one dictionary count from slot
/// position `from` to `to` in the TABLE HELPER only (the committed `M_dd`
/// stays honest) — the CHECK.md D-8 attack on a construction that commits
/// the multiplicities in `A`
#[cfg(test)]
pub(crate) fn set_dd_moved_multiplicity(v: Option<(usize, usize)>) {
    DD_MOVED_MULTIPLICITY.with(|c| c.set(v));
}

#[cfg(test)]
fn dd_moved_multiplicity() -> Option<(usize, usize)> {
    DD_MOVED_MULTIPLICITY.with(|c| c.get())
}

/// **NATIVE R6 (review r5 note N-r5-a): ruling CS-3's lookup-miss refusal,
/// run on a witness BEFORE any proof exists.** The trained stack's sealing
/// pass calls it on every sealed witness, so "every refusal of an
/// inadmissible chain happens before the run header" (ruling H-1) is a
/// fact of the code rather than an argument about the witness builder's
/// range checks. The same counts `prove_core` computes (the looked byte
/// columns, the exp and activation pairs) and the same named refusal (the
/// class of the miss only, never a count; a cheating prover skips it in
/// test builds exactly as in `prove_core`).
pub(crate) fn check_lookup_misses(sh: &Shape, lay: &Layout, blk: &BlockPublic, wit: &Witness) -> Result<(), String> {
    lay.check_is_for_shape(sh)?;
    blk.check_for_shape(sh)?;
    let ids = lay.ids();
    if wit.planes.len() != ids.n_a() {
        return Err("private block: witness shape".into());
    }
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_values(lay, wit, *d))).collect();
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    let (_, exp_missed) = exp_histogram(&exp_deltas(lay, wit), &wit.planes[ids.at(A_E)], &blk.attention().exp);
    let (_, act_missed) = match blk.accuracy() {
        Some(data)=>super::accuracy_act::histogram(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)])?,
        None=>act_histogram(&act_indices(lay,wit),&wit.planes[ids.at(A_A16)],&blk.feed_forward().act),
    };
    let u8_or_range_missed = if sh.range16() { w16_histograms(lay, &looked).2 } else { u8_misses_of(&looked, lookup_words) };
    refuse_lookup_misses(u8_or_range_missed, exp_missed, act_missed)?;
    // NATIVE R9 (D30, CHECK.md B-8): the dictionary family, in the sealing
    // pass too, before `A` and before the header
    if sh.dd_cap > 0 {
        refuse_dictionary_misses(dd_misses(lay, wit, &blk.attention().dd_e_column(sh.dd_cap)?))?;
    }
    Ok(())
}

// **RULING CS-3's test-only switch: the soundness tests' CHEATING PROVER.**
#[cfg(test)]
thread_local! {
    static CHEATING_PROVER: std::cell::Cell<bool> = const { std::cell::Cell::new(false) };
}

/// While alive, this thread's prover skips ruling CS-3's refusal, and the run
/// prover ruling CS-6's comparison of the blocks it is handed with the ones
/// its statement names (test only).
#[cfg(test)]
pub(crate) struct CheatingProver {
    was: bool,
}

/// Whether a [`CheatingProver`] guard lives on this thread (test only).
#[cfg(test)]
pub(crate) fn cheating_prover_is_on() -> bool {
    CHEATING_PROVER.with(|c| c.get())
}

#[cfg(test)]
impl CheatingProver {
    pub(crate) fn on() -> CheatingProver {
        CheatingProver { was: CHEATING_PROVER.with(|c| c.replace(true)) }
    }
}

#[cfg(test)]
impl Drop for CheatingProver {
    fn drop(&mut self) {
        CHEATING_PROVER.with(|c| c.set(self.was));
    }
}

/// **D55 REVIEW F5 (2026-11-01), TEST BUILDS ONLY: every thread-local test
/// switch that `prove_core` / `verify_core` (and what they call) read, as one
/// value that can cross a thread boundary.** Each switch is a `thread_local`
/// so that tests running in parallel never see each other's; the price is
/// that a prover or verifier on a WORKER thread (the D55 fork pool) sees none
/// of the calling test's switches, so a ported tamper test would silently run
/// the honest fork body. A test path that spawns workers captures this on the
/// calling thread and installs it in each worker ([`ThreadHooks::install`]).
///
/// Carried: the CS-3 / CS-6 cheating-prover switch, the moved-multiplicity
/// hooks (D-8 and F-4), the W16 misfiled range, the D30 lapse bits
/// (`argument.rs`), the W16 collapsed range tags (`range16.rs`), the forced
/// legacy hash rule (`shape.rs`) and the timing override (`timing.rs`). Not
/// carried: the witness builder's hooks (`witness.rs`' dictionary cheat and
/// `review_d24_tests`' forged softmax), which act where a witness is BUILT,
/// and a run source builds every witness on the calling thread.
///
/// A release build has none of this: the struct, its methods, the guard and
/// every getter it reads are `#[cfg(test)]`.
#[cfg(test)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) struct ThreadHooks {
    pub cheating_prover: bool,
    pub dd_moved_multiplicity: Option<(usize, usize)>,
    pub moved_multiplicity: Option<(usize, usize, usize)>,
    pub misfiled_range: Option<(u32, u32)>,
    pub dd_lapse: u8,
    pub collapsed_range_tags: bool,
    pub force_legacy_hash_rule: bool,
    pub timing_force: Option<bool>,
}

#[cfg(test)]
impl ThreadHooks {
    /// this thread's switches, as they stand
    pub(crate) fn capture() -> ThreadHooks {
        ThreadHooks {
            cheating_prover: CHEATING_PROVER.with(|c| c.get()),
            dd_moved_multiplicity: DD_MOVED_MULTIPLICITY.with(|c| c.get()),
            moved_multiplicity: MOVED_MULTIPLICITY.with(|c| c.get()),
            misfiled_range: MISFILED_RANGE.with(|c| c.get()),
            dd_lapse: super::argument::dd_lapse_bits(),
            collapsed_range_tags: super::range16::collapsed_range_tags(),
            force_legacy_hash_rule: super::shape::forced_legacy_hash_rule(),
            timing_force: super::timing::forced(),
        }
    }

    /// Install these switches on THIS thread; the guard puts back what the
    /// thread held before, on every path.
    pub(crate) fn install(self) -> ThreadHooksGuard {
        let was = ThreadHooks::capture();
        self.set();
        ThreadHooksGuard { was }
    }

    fn set(&self) {
        CHEATING_PROVER.with(|c| c.set(self.cheating_prover));
        DD_MOVED_MULTIPLICITY.with(|c| c.set(self.dd_moved_multiplicity));
        MOVED_MULTIPLICITY.with(|c| c.set(self.moved_multiplicity));
        MISFILED_RANGE.with(|c| c.set(self.misfiled_range));
        super::argument::set_dd_lapse(self.dd_lapse);
        super::range16::set_collapsed_range_tags(self.collapsed_range_tags);
        super::shape::set_force_legacy_hash_rule(self.force_legacy_hash_rule);
        super::timing::force(self.timing_force);
    }
}

/// what [`ThreadHooks::install`] returns: dropping it restores the thread's
/// own switches (test only)
#[cfg(test)]
pub(crate) struct ThreadHooksGuard {
    was: ThreadHooks,
}

#[cfg(test)]
impl Drop for ThreadHooksGuard {
    fn drop(&mut self) {
        self.was.set();
    }
}

pub(super) fn byte_histogram_at(looked: &[(Dom, Vec<Vec<i64>>)], lookup_words: u64, par_min: u64) -> Vec<u64> {
    let bin = |v: &i64| -> usize {
        if (0..U8_LEN as i64).contains(v) {
            *v as usize
        } else {
            0
        }
    };
    if lookup_words >= par_min {
        use rayon::prelude::*;
        let cols: Vec<&Vec<i64>> = looked.iter().flat_map(|(_, cols)| cols.iter()).collect();
        return cols
            .par_iter()
            .flat_map(|c| c.par_chunks(1 << 16))
            .map(|chunk| {
                let mut b = vec![0u64; U8_LEN];
                for v in chunk {
                    b[bin(v)] += 1;
                }
                b
            })
            .reduce(
                || vec![0u64; U8_LEN],
                |mut a, b| {
                    for (x, y) in a.iter_mut().zip(b.iter()) {
                        *x += *y;
                    }
                    a
                },
            );
    }
    let mut m_u8 = vec![0u64; U8_LEN];
    for (_, cols) in looked {
        for v in cols.iter().flatten() {
            m_u8[bin(v)] += 1;
        }
    }
    m_u8
}

// ---------------------------------------------------------------- W16 (D54)

/// **W16: the byte histogram, one histogram per range family, and how many
/// looked words lie outside their OWN family's table** (the miss count ruling
/// CS-3 refuses on). Each column is binned by its lookup's tag. The bins are
/// integer sums, so the parallel reduction's order changes no bin. A byte miss
/// files in entry 0 as the byte histogram always has; a range miss files
/// nowhere. Either way the honest prover refuses before `A`'s masks.
pub(super) fn w16_histograms(lay: &Layout, looked: &[(Dom, Vec<Vec<i64>>)]) -> (Vec<u64>, Vec<Vec<u64>>, usize) {
    use rayon::prelude::*;
    let widths: Vec<u32> = lay.shape().range_families().iter().map(|f| f.width).collect();
    let mut chunks: Vec<(&[i64], LkTag)> = Vec::new();
    for (dom, cols) in looked {
        for (c, l) in cols.iter().zip(lay.lookups(*dom)) {
            chunks.extend(c.chunks(1 << 16).map(|ch| (ch, l.tag)));
        }
    }
    let fresh = || (vec![0u64; U8_LEN], widths.iter().map(|w| vec![0u64; 1usize << w]).collect::<Vec<_>>(), 0usize);
    chunks
        .par_iter()
        .fold(fresh, |mut acc, &(ch, tag)| {
            match tag {
                LkTag::U8 => {
                    for v in ch {
                        if (0..U8_LEN as i64).contains(v) {
                            acc.0[*v as usize] += 1;
                        } else {
                            acc.0[0] += 1;
                            acc.2 += 1;
                        }
                    }
                }
                LkTag::Range(w) => {
                    let f = widths.iter().position(|x| *x == w).expect("a W16 lookup's width is one of the shape's range families");
                    let n = 1i64 << w;
                    for v in ch {
                        if (0..n).contains(v) {
                            acc.1[f][*v as usize] += 1;
                        } else {
                            acc.2 += 1;
                        }
                    }
                }
            }
            acc
        })
        .reduce(fresh, |mut a, b| {
            for (x, y) in a.0.iter_mut().zip(&b.0) {
                *x += *y;
            }
            for (fa, fb) in a.1.iter_mut().zip(&b.1) {
                for (x, y) in fa.iter_mut().zip(fb) {
                    *x += *y;
                }
            }
            a.2 += b.2;
            a
        })
}

/// W16: one looked column with its family's fold constant and inverse table
pub(super) struct TaggedColumn<'a> {
    pub(super) vals: &'a [i64],
    pub(super) g: Fp2,
    pub(super) tbl: &'a [Option<Fp2>],
}

/// W16: one helper column to write, at `H`'s (real, imaginary) offsets
pub(super) struct HelperJobW16<'a> {
    pub(super) off: (usize, usize),
    pub(super) a: TaggedColumn<'a>,
    pub(super) b: Option<TaggedColumn<'a>>,
}

/// W16: a looked column with its tag's fold constant and inverse table (the
/// byte table's, or its range family's from `tabs`: `(width, g, inverses)`)
fn tagged_column<'c>(vals: &'c [i64], tag: LkTag, g_u8: Fp2, u8_inv: &'c [Option<Fp2>], tabs: &'c [(u32, Fp2, Vec<Option<Fp2>>)]) -> Result<TaggedColumn<'c>, String> {
    match tag {
        LkTag::U8 => Ok(TaggedColumn { vals, g: g_u8, tbl: u8_inv }),
        LkTag::Range(w) => {
            let t = tabs.iter().find(|t| t.0 == w).ok_or("W16: a lookup width outside the shape's range families")?;
            Ok(TaggedColumn { vals, g: t.1, tbl: &t.2 })
        }
    }
}

/// `1 / (alpha - (v + g))`: the table entry for a value inside the table, the
/// arithmetic otherwise (the same refusal as [`helper_one`])
fn helper_one_any(v: i64, alpha: Fp2, g: Fp2, tbl: &[Option<Fp2>]) -> Result<Fp2, String> {
    match usize::try_from(v) {
        Ok(k) if k < tbl.len() => tbl[k].ok_or_else(|| ZERO_DENOMINATOR.to_string()),
        _ => {
            let d = alpha.sub(Fp2::from_i64(v).add(g));
            if d.is_zero() {
                Err(ZERO_DENOMINATOR.to_string())
            } else {
                Ok(d.inv())
            }
        }
    }
}

/// **W16: every helper column in ONE parallel region** ([`write_helpers_u8`]'s
/// carving, with each looked column's own family). The layout builds only
/// well-formed, disjoint jobs; anything else is refused rather than written.
pub(super) fn write_helpers_w16(h: &mut [Fp], jobs: &[HelperJobW16<'_>], alpha: Fp2) -> Result<(), String> {
    let mut ranges: Vec<(usize, usize, usize, bool)> = Vec::with_capacity(2 * jobs.len());
    for (i, j) in jobs.iter().enumerate() {
        let len = j.a.vals.len();
        if j.b.as_ref().is_some_and(|b| b.vals.len() != len) || (j.off.0 + len > j.off.1 && j.off.1 + len > j.off.0) {
            return Err("private block: a W16 helper job is malformed".into());
        }
        if len > 0 {
            ranges.push((j.off.0, len, i, false));
            ranges.push((j.off.1, len, i, true));
        }
    }
    ranges.sort_unstable();
    if !(ranges.windows(2).all(|w| w[0].0 + w[0].1 <= w[1].0) && ranges.last().is_none_or(|r| r.0 + r.1 <= h.len())) {
        return Err("private block: W16 helper columns overlap or leave H".into());
    }
    let mut parts: Vec<[Option<&mut [Fp]>; 2]> = (0..jobs.len()).map(|_| [None, None]).collect();
    let mut rest: &mut [Fp] = h;
    let mut at = 0usize;
    for &(start, len, i, im) in &ranges {
        let tail = std::mem::take(&mut rest).split_at_mut(start - at).1;
        let (mine, tail) = tail.split_at_mut(len);
        parts[i][im as usize] = Some(mine);
        rest = tail;
        at = start + len;
    }
    type Item<'s, 'c> = (&'s mut [Fp], &'s mut [Fp], usize, &'c HelperJobW16<'c>);
    let mut items: Vec<Item<'_, '_>> = Vec::new();
    for (j, [re, im]) in jobs.iter().zip(parts.iter_mut()) {
        let (Some(re), Some(im)) = (re.take(), im.take()) else { continue };
        for (c, (r, m)) in re.chunks_mut(HELPER_CHUNK).zip(im.chunks_mut(HELPER_CHUNK)).enumerate() {
            items.push((r, m, c * HELPER_CHUNK, j));
        }
    }
    let fill = |(r, m, s, j): Item<'_, '_>| -> bool {
        for i in 0..r.len() {
            let Ok(mut v) = helper_one_any(j.a.vals[s + i], alpha, j.a.g, j.a.tbl) else { return false };
            if let Some(b) = &j.b {
                let Ok(y) = helper_one_any(b.vals[s + i], alpha, b.g, b.tbl) else { return false };
                v = v.add(y);
            }
            r[i] = v.c0;
            m[i] = v.c1;
        }
        true
    };
    use rayon::prelude::*;
    if items.into_par_iter().map(fill).reduce(|| true, |x, y| x && y) {
        Ok(())
    } else {
        Err(ZERO_DENOMINATOR.to_string())
    }
}

/// the activation lookup's index column `g8 + 128` over the `Dom::F` cube
pub(super) fn act_indices(lay: &Layout, wit: &Witness) -> Vec<i64> {
    wit.planes[lay.ids().at(A_G8)].iter().map(|g| g + 128).collect()
}

/// max - masked score per `(h, t, j)`, over `Dom::S`'s cube
/// `(h * t_pad + t) * t_pad + j` (`witness.rs:193`)
pub(super) fn exp_deltas(lay: &Layout, wit: &Witness) -> Vec<i64> {
    let (sh, ids) = (lay.shape(), lay.ids());
    let (tp, s8, mx) = (sh.t_pad, ids.at(A_S8), ids.at(A_MX));
    (0..sh.h_pad * tp * tp)
        .map(|x| {
            let (ht, j) = (x / tp, x % tp);
            let masked = if j <= ht % tp { wit.planes[s8][x] } else { MASK_SCORE };
            wit.planes[mx][ht].wrapping_sub(masked)
        })
        .collect()
}

pub(super) fn inverses(mut den: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    // [ZK60-METAL M4h] a long column is inverted in rayon chunks, one batch
    // inversion (and one field inversion) per chunk. An inverse is the unique
    // field element, so every word is the same; a zero anywhere refuses with
    // the same string (each chunk checks before it inverts, and a refused
    // vector is dropped). The exp and activation helpers alone are 2.6 M
    // extension elements at the T128 rungs, inverted on one thread before.
    if den.len() >= 2 * INV_CHUNK {
        use rayon::prelude::*;
        den.par_chunks_mut(INV_CHUNK).try_for_each(batch_inverse2_checked).map_err(|_| ZERO_DENOMINATOR.to_string())?;
        return Ok(den);
    }
    batch_inverse2_checked(&mut den).map_err(|_| "zero LogUp denominator; discard attempt".to_string())?;
    Ok(den)
}

/// [M4h] the chunk of [`inverses`]' parallel form, and the column length from
/// which [`write_h`] writes in parallel
pub(super) const INV_CHUNK: usize = 1 << 14;
pub(super) const WRITE_H_PAR_MIN: usize = 1 << 16;

/// [M4i] the word count from which [`write_planes`] runs in parallel
pub(super) const PLANES_PAR_MIN: usize = 1 << 16;

/// **[ZK60-METAL M4i]** `A`'s witness planes into their rows: `dst[off + i] =
/// Fp::from_i64(plane[i])` for every `(off, plane)` job. When every range is in
/// bounds and the ranges are pairwise disjoint (the layout's planes always are),
/// the ranges are carved in address order and written in one rayon region of
/// fixed chunks; the words and their places are the loop's. Anything else runs
/// the jobs in order exactly as the loop did (a later job overwrites an earlier
/// one where they overlap; an out-of-range write panics where it did).
pub(super) fn write_planes(dst: &mut [Fp], jobs: &[(usize, &[i64])]) {
    let total: usize = jobs.iter().map(|j| j.1.len()).sum();
    let mut order: Vec<usize> = (0..jobs.len()).collect();
    order.sort_by_key(|&k| jobs[k].0);
    let in_bounds = jobs.iter().all(|(o, p)| o.checked_add(p.len()).is_some_and(|e| e <= dst.len()));
    let disjoint = in_bounds && order.windows(2).all(|w| jobs[w[0]].0 + jobs[w[0]].1.len() <= jobs[w[1]].0);
    if total < PLANES_PAR_MIN || !in_bounds || !disjoint {
        for (off, plane) in jobs {
            for (i, v) in plane.iter().enumerate() {
                dst[off + i] = Fp::from_i64(*v);
            }
        }
        return;
    }
    use rayon::prelude::*;
    let mut items: Vec<(&mut [Fp], &[i64])> = Vec::with_capacity(total / HELPER_CHUNK + jobs.len());
    let (mut rest, mut base) = (dst, 0usize);
    for &k in &order {
        let (off, plane) = jobs[k];
        let (_, tail) = std::mem::take(&mut rest).split_at_mut(off - base);
        let (mine, after) = tail.split_at_mut(plane.len());
        items.extend(mine.chunks_mut(HELPER_CHUNK).zip(plane.chunks(HELPER_CHUNK)));
        rest = after;
        base = off + plane.len();
    }
    items.into_par_iter().for_each(|(d, p)| {
        for (x, v) in d.iter_mut().zip(p.iter()) {
            *x = Fp::from_i64(*v);
        }
    });
}

/// The one refusal string every LogUp denominator shares. It was written out
/// twice before stage 28 and is written out once now, so the table path below
/// cannot drift from [`inverses`].
const ZERO_DENOMINATOR: &str = "zero LogUp denominator; discard attempt";

/// **STAGE 28 (performance, no byte moves).** The `U8_LEN` denominators
/// `alpha - (v + g_u8)` of the BYTE TABLE, inverted once per proof.
///
/// Every value a looked column carries is looked up in the same 256-entry
/// byte table, so at most 256 distinct denominators exist over the whole of
/// `H`'s helper half — at the 125M shape 98,598,912 entries share them. Entry
/// `v` is `None` exactly when its denominator is zero, which at most one `v`
/// can be (`v -> Fp2::from_i64(v) + g_u8` is injective on `0..U8_LEN`).
///
/// The batch inversion is over the NONZERO denominators alone, so this
/// function never refuses: whether a zero denominator refuses THIS attempt is
/// decided by [`helper_inverses_u8`], value by value, exactly as the
/// element-wise batch inversion decided it before.
pub(super) fn u8_denominator_inverses(alpha: Fp2, g_u8: Fp2) -> Vec<Option<Fp2>> {
    let den: Vec<Fp2> = (0..U8_LEN).map(|v| alpha.sub(Fp2::from_i64(v as i64).add(g_u8))).collect();
    let mut nonzero: Vec<Fp2> = den.iter().copied().filter(|d| !d.is_zero()).collect();
    crate::field::batch_inverse2(&mut nonzero);
    let mut k = 0usize;
    den.iter()
        .map(|d| {
            if d.is_zero() {
                None
            } else {
                k += 1;
                Some(nonzero[k - 1])
            }
        })
        .collect()
}

/// **STAGE 28.** One looked column's LogUp helper values,
/// `1 / (alpha - (v + g_u8))` entry by entry.
///
/// **What it must not change, and does not.** The old line built the whole
/// column of denominators and handed it to `batch_inverse2_checked`, which
/// refuses iff SOME ENTRY OF THAT COLUMN is zero — that is, iff a zero
/// denominator sits at a value the witness ACTUALLY CARRIES. This keeps that
/// rule exactly: a byte value whose table entry is `None` refuses here, and a
/// value the column does not carry cannot. (Whether a zero denominator at an
/// ABSENT table value refuses anyway, later, through the three table helpers,
/// is finding S28-F1 — it does, and this function is deliberately not the
/// place where that changes.)
///
/// A value outside `0..U8_LEN` is only ever a dishonest or tampered witness
/// (the soundness tests build them). It takes the old arithmetic, one
/// inversion at a time: the field inverse is unique and every representation
/// is canonical, so the word written is the batch inversion's word.
///
/// The parallel form is the crate's (`rayon`, as `pcs.rs` and `zk.rs` use it)
/// and is INDEXED, so the output vector is the same whatever the thread count
/// is; no randomness is drawn here, so no draw order can move.
#[cfg_attr(not(test), allow(dead_code))] // the reference form; production writes through `write_helper_u8`
pub(super) fn helper_inverses_u8(col: &[i64], alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<Vec<Fp2>, String> {
    helper_inverses_u8_at(col, alpha, g_u8, tbl, HELPER_PAR_MIN)
}

/// **STAGE 29 (finding S28-R1).** The column length above which a helper
/// column is built in parallel, as stage 28 chose it: a constant of the
/// PRODUCTION calls and an ARGUMENT of the two `_at` forms below. Small
/// columns stay on one thread, where a rayon region costs more than the work
/// (the house style of `sumcheck::prove`'s own `small` branch).
pub(super) const HELPER_PAR_MIN: usize = 1 << 14;

/// one word of a helper column: the table entry when the value is a byte, the
/// old arithmetic otherwise. Written once and called by both forms, which is
/// why the single and the paired helper cannot drift apart.
fn helper_one(v: i64, alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<Fp2, String> {
    match usize::try_from(v) {
        Ok(k) if k < U8_LEN => tbl[k].ok_or_else(|| ZERO_DENOMINATOR.to_string()),
        _ => {
            let d = alpha.sub(Fp2::from_i64(v).add(g_u8));
            if d.is_zero() {
                Err(ZERO_DENOMINATOR.to_string())
            } else {
                Ok(d.inv())
            }
        }
    }
}

/// **STAGE 29.** [`helper_inverses_u8`] with the threshold as an argument, so
/// a test can drive BOTH branches on the same column. The production wrapper
/// passes [`HELPER_PAR_MIN`], so the production call path is the one stage 28
/// measured.
pub(super) fn helper_inverses_u8_at(col: &[i64], alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>], par_min: usize) -> Result<Vec<Fp2>, String> {
    let one = |v: &i64| helper_one(*v, alpha, g_u8, tbl);
    if col.len() < par_min {
        return col.iter().map(one).collect();
    }
    use rayon::prelude::*;
    col.par_iter().map(one).collect()
}

/// **STAGE 28.** The helper column of a PAIR of looked columns:
/// `1/(alpha - (a + g_u8)) + 1/(alpha - (b + g_u8))`, in one indexed pass.
///
/// It is exactly what the two separate columns plus the element-wise `add`
/// produced — the inverses are the same words and the sum of two field
/// elements does not depend on where they were stored. The refusal is
/// [`helper_inverses_u8`]'s, unchanged: the first column is asked before the
/// second at every index, and both must answer.
#[cfg_attr(not(test), allow(dead_code))] // the reference form; production writes through `write_helper_u8`
pub(super) fn helper_pair_inverses_u8(a: &[i64], b: &[i64], alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<Vec<Fp2>, String> {
    helper_pair_inverses_u8_at(a, b, alpha, g_u8, tbl, HELPER_PAR_MIN)
}

/// **STAGE 29.** The paired form with the threshold as an argument; the
/// production wrapper passes [`HELPER_PAR_MIN`].
pub(super) fn helper_pair_inverses_u8_at(a: &[i64], b: &[i64], alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>], par_min: usize) -> Result<Vec<Fp2>, String> {
    if a.len() != b.len() {
        return Err("private block: paired lookup columns of different lengths".into());
    }
    let pair = |(x, y): (&i64, &i64)| -> Result<Fp2, String> { Ok(helper_one(*x, alpha, g_u8, tbl)?.add(helper_one(*y, alpha, g_u8, tbl)?)) };
    if a.len() < par_min {
        return a.iter().zip(b.iter()).map(pair).collect();
    }
    use rayon::prelude::*;
    a.par_iter().zip(b.par_iter()).map(pair).collect()
}

// **FINDING F-4 OF THE INDEPENDENT REVIEW: THE ONE TEST-ONLY PROVER HOOK.**
//
// `Dom::Tab`'s pad-zero term is the single arm of ruling P-1 that NO witness
// edit can reach, because its six planes — three histograms and three table
// helpers — are DERIVED here from the witness rather than carried by it. It
// is also the arm the P-3 lift's safety rests on. The hook moves ONE count
// of one histogram from a true table row to the PADDED COPY of that same row
// (the lift builds padded entry `i` from `i % 256`, so the two rows carry the
// same value), and writes the table helper that position now needs. Every
// other relation of `SC_TAB` and the whole value-0 LogUp identity still hold
// — same total multiplicity, same value, consistent helper — so the pad-zero
// term is the ONLY thing left that can catch it. It closes the
// moved-multiplicity family at the same time.
//
// It is `#[cfg(test)]` throughout: the state, the setter and both injection
// points vanish from a release build, and no public API of this crate names
// them. `(which histogram 0/1/2, true row < 256, padded position >= 256)`.
// W16 review F3 (c) extends `which`: `3 + j` is range sub-plane `j` (in
// `AccuracyIds::range_planes` order) of a NARROW family, the true row below
// its support `2^w` and the padded position a copy `>= 2^w` of that row.
#[cfg(test)]
thread_local! {
    static MOVED_MULTIPLICITY: std::cell::Cell<Option<(usize, usize, usize)>> = const { std::cell::Cell::new(None) };
}

/// set or clear the hook above; a test MUST clear it before it returns
#[cfg(test)]
pub(crate) fn set_moved_multiplicity(v: Option<(usize, usize, usize)>) {
    MOVED_MULTIPLICITY.with(|c| c.set(v));
}

#[cfg(test)]
fn moved_multiplicity() -> Option<(usize, usize, usize)> {
    MOVED_MULTIPLICITY.with(|c| c.get())
}

// W16 review F3 (a), TEST BUILDS ONLY: a cheating prover that files each
// width-`from` query MISSING its own table in the histogram of the width-`to`
// range family, whose table holds the value. The query keeps its own tag and
// the count sits under the other family's, so with every relation true the
// tag fold `gamma tag(w)` is the only term left that can tell the two apart.
// `(from, to)`; read on the proving thread, never inside a rayon region.
#[cfg(test)]
thread_local! {
    static MISFILED_RANGE: std::cell::Cell<Option<(u32, u32)>> = const { std::cell::Cell::new(None) };
}

/// set or clear the hook above; a test MUST clear it before it returns
#[cfg(test)]
pub(crate) fn set_misfiled_range(v: Option<(u32, u32)>) {
    MISFILED_RANGE.with(|c| c.set(v));
}

/// the range histograms with the hook above applied (returned unchanged
/// while it is clear)
#[cfg(test)]
fn misfile_range_misses(lay: &Layout, looked: &[(Dom, Vec<Vec<i64>>)], mut m_rng: Vec<Vec<u64>>) -> Vec<Vec<u64>> {
    let Some((from, to)) = MISFILED_RANGE.with(|c| c.get()) else { return m_rng };
    let widths: Vec<u32> = lay.shape().range_families().iter().map(|f| f.width).collect();
    let t = widths.iter().position(|w| *w == to).expect("the hook files into one of the shape's range families");
    for (dom, cols) in looked {
        for (c, l) in cols.iter().zip(lay.lookups(*dom)) {
            if matches!(l.tag, LkTag::Range(w) if w == from) {
                for v in c.iter().filter(|v| !(0..1i64 << from).contains(*v) && (0..1i64 << to).contains(*v)) {
                    m_rng[t][*v as usize] += 1;
                }
            }
        }
    }
    m_rng
}

/// [ZK60-METAL M4c] one LogUp helper column written straight into `h`: word `i`
/// is `helper_one(a[i]) (+ helper_one(b[i]))`, its real part at `off.0 + i` and
/// its imaginary part at `off.1 + i` — exactly what `write_h` of
/// `helper_pair_inverses_u8` / `helper_inverses_u8` stores. Parallel above
/// [`HELPER_PAR_MIN`] like those two; a zero denominator is the same refusal.
pub(super) fn write_helper_u8(h: &mut [Fp], off: (usize, usize), a: &[i64], b: Option<&[i64]>, alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<(), String> {
    let len = a.len();
    if b.is_some_and(|b| b.len() != len) {
        return Err("private block: paired lookup columns of different lengths".into());
    }
    if off.0 + len > off.1 && off.1 + len > off.0 {
        return Err("private block: a helper's real and imaginary rows overlap".into());
    }
    let (re, im): (&mut [Fp], &mut [Fp]) = if off.0 < off.1 {
        let (lo, hi) = h.split_at_mut(off.1);
        (&mut lo[off.0..off.0 + len], &mut hi[..len])
    } else {
        let (lo, hi) = h.split_at_mut(off.0);
        (&mut hi[..len], &mut lo[off.1..off.1 + len])
    };
    let word = |i: usize| -> Result<Fp2, String> {
        let x = helper_one(a[i], alpha, g_u8, tbl)?;
        match b {
            Some(b) => Ok(x.add(helper_one(b[i], alpha, g_u8, tbl)?)),
            None => Ok(x),
        }
    };
    if len < HELPER_PAR_MIN {
        for (i, (r, m)) in re.iter_mut().zip(im.iter_mut()).enumerate() {
            let v = word(i)?;
            *r = v.c0;
            *m = v.c1;
        }
        return Ok(());
    }
    use rayon::prelude::*;
    re.par_iter_mut().zip(im.par_iter_mut()).enumerate().try_for_each(|(i, (r, m))| {
        let v = word(i)?;
        *r = v.c0;
        *m = v.c1;
        Ok(())
    })
}

/// [ZK60-METAL M4d] one LogUp helper column to write: `H`'s (real, imaginary)
/// offsets and its one or two looked columns (see [`write_helper_u8`])
pub(super) struct HelperJob<'a> {
    pub(super) off: (usize, usize),
    pub(super) a: &'a [i64],
    pub(super) b: Option<&'a [i64]>,
}

/// [ZK60-METAL M4d] words per task of [`write_helpers_u8`]
const HELPER_CHUNK: usize = 1 << 14;

/// [ZK60-METAL M4d] Every job's [`write_helper_u8`] in ONE parallel region:
/// the same words in the same places and the same result. On this Mac a rayon
/// region costs about half a millisecond to start, and the Shieldstral block's
/// 47 helper columns of 2^14..2^21 words each paid it once per column (and a
/// per-word `try_for_each`), 0.13 s in all; chunks of all of them in one region
/// take a few milliseconds.
///
/// **The same result.** The fast path runs only when every job is well formed
/// (paired columns of equal length, real and imaginary rows apart) and all the
/// target ranges are disjoint and inside `h`, so each word has one writer; the
/// only error left is a zero denominator, which the job-by-job loop also
/// returns (as the same string) exactly when some job meets one. Anything else
/// takes that loop itself, so its refusal and its order are unchanged.
pub(super) fn write_helpers_u8(h: &mut [Fp], jobs: &[HelperJob<'_>], alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<(), String> {
    let well_formed = jobs.iter().all(|j| {
        let len = j.a.len();
        j.b.is_none_or(|b| b.len() == len) && !(j.off.0 + len > j.off.1 && j.off.1 + len > j.off.0)
    });
    // (start, length, job, imaginary?) of every nonempty target range
    let mut ranges: Vec<(usize, usize, usize, bool)> = Vec::with_capacity(2 * jobs.len());
    for (i, j) in jobs.iter().enumerate() {
        if !j.a.is_empty() {
            ranges.push((j.off.0, j.a.len(), i, false));
            ranges.push((j.off.1, j.a.len(), i, true));
        }
    }
    ranges.sort_unstable();
    let disjoint = ranges.windows(2).all(|w| w[0].0 + w[0].1 <= w[1].0) && ranges.last().is_none_or(|r| r.0 + r.1 <= h.len());
    if !(well_formed && disjoint) {
        for j in jobs {
            write_helper_u8(h, j.off, j.a, j.b, alpha, g_u8, tbl)?;
        }
        return Ok(());
    }
    // carve the disjoint ranges out of `h`, in address order
    let mut parts: Vec<[Option<&mut [Fp]>; 2]> = (0..jobs.len()).map(|_| [None, None]).collect();
    let mut rest: &mut [Fp] = h;
    let mut at = 0usize;
    for &(start, len, i, im) in &ranges {
        let tail = std::mem::take(&mut rest).split_at_mut(start - at).1;
        let (mine, tail) = tail.split_at_mut(len);
        parts[i][im as usize] = Some(mine);
        rest = tail;
        at = start + len;
    }
    type Item<'s> = (&'s mut [Fp], &'s mut [Fp], &'s [i64], Option<&'s [i64]>);
    let mut items: Vec<Item<'_>> = Vec::new();
    let mut words = 0usize;
    for (j, [re, im]) in jobs.iter().zip(parts.iter_mut()) {
        let (Some(re), Some(im)) = (re.take(), im.take()) else { continue };
        words += re.len();
        for (c, (r, m)) in re.chunks_mut(HELPER_CHUNK).zip(im.chunks_mut(HELPER_CHUNK)).enumerate() {
            let (s, e) = (c * HELPER_CHUNK, c * HELPER_CHUNK + r.len());
            items.push((r, m, &j.a[s..e], j.b.map(|b| &b[s..e])));
        }
    }
    // one chunk; false at a zero denominator
    let fill = |(r, m, a, b): Item<'_>| -> bool {
        match b {
            Some(b) => {
                for i in 0..r.len() {
                    let (Ok(x), Ok(y)) = (helper_one(a[i], alpha, g_u8, tbl), helper_one(b[i], alpha, g_u8, tbl)) else { return false };
                    let v = x.add(y);
                    r[i] = v.c0;
                    m[i] = v.c1;
                }
            }
            None => {
                for i in 0..r.len() {
                    let Ok(v) = helper_one(a[i], alpha, g_u8, tbl) else { return false };
                    r[i] = v.c0;
                    m[i] = v.c1;
                }
            }
        }
        true
    };
    let ok = if words < HELPER_PAR_MIN {
        items.into_iter().map(fill).fold(true, |x, y| x && y)
    } else {
        use rayon::prelude::*;
        items.into_par_iter().map(fill).reduce(|| true, |x, y| x && y)
    };
    if ok {
        Ok(())
    } else {
        Err(ZERO_DENOMINATOR.to_string())
    }
}

pub(super) fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    // [M4h] a long column in parallel when its re and im ranges are disjoint
    // and in bounds (they always are); the same words in the same places.
    // Anything else takes the loop below, which panics where it did.
    let n = col.len();
    if n >= WRITE_H_PAR_MIN {
        let (lo, hi) = (off.0.min(off.1), off.0.max(off.1));
        if lo + n <= hi && hi + n <= h.len() {
            use rayon::prelude::*;
            let (head, tail) = h.split_at_mut(hi);
            let (first, second) = (&mut head[lo..lo + n], &mut tail[..n]);
            let (re, im) = if off.0 <= off.1 { (first, second) } else { (second, first) };
            re.par_chunks_mut(HELPER_CHUNK).zip(im.par_chunks_mut(HELPER_CHUNK)).zip(col.par_chunks(HELPER_CHUNK)).for_each(|((r, i), c)| {
                for ((r, i), v) in r.iter_mut().zip(i.iter_mut()).zip(c.iter()) {
                    *r = v.c0;
                    *i = v.c1;
                }
            });
            return;
        }
    }
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

pub(super) fn check_endpoints(sh: &Shape, expected: &ExpectedIo, endpoints: Endpoints) -> Result<[pcs::CommittedZk; 2], String> {
    let (rows, _, _) = endpoint_geometry(sh)?;
    // S11b: whichever construction this profile's endpoints ride
    let [input, output] = expected.spec.into_committed(endpoints)?;
    if input.commitment().root != expected.input || output.commitment().root != expected.output {
        return Err("private block: expected endpoint root mismatch".into());
    }
    if input.cm.rows != rows || output.cm.rows != rows {
        return Err("private block: endpoint geometry".into());
    }
    Ok([input, output])
}

/// Consumes the endpoint owners on success AND on failure. No equality precheck: an
/// endpoint committed to other values must fail the verifier's polynomial identity.
///
/// `wit` is taken BY VALUE (step S2 / C-11): the witness planes are the
/// prover's largest long-lived buffer (711 MB at the 125M shape) and are dead
/// once the LogUp helper columns are written, so the prover must be able to
/// release them before the `H` commitment and the twenty-three slots. Taking a
/// reference would leave that memory alive in the caller's frame for the whole
/// proof. Nothing here keeps a copy.
pub(crate) fn prove_inner(blk: &BlockPublic, wit: Witness, expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    prove_inner_at(&Shape::toy(), blk, wit, expected, endpoints)
}

/// **STEP C part 2.** The same prover at any [`Shape`]. `prove_inner` is this
/// at `Shape::toy()`, exactly as `AttentionPublic::new` is `new_shaped` at the
/// toy — the toy's code path, its transcript and every one of its bytes are
/// unchanged, and a new shape is a NEW profile beside it (D17).
/// **ROUND 2, R2-4: no single-block receipt at a trained-calibration profile.**
/// A single block's transcript (`transcript` above) absorbs the SYNTHETIC
/// calibration literal `calibration_identity()`; a trained-calibration
/// profile must instead absorb its trained-model statement, which only a run
/// does (`run::RunStatement::new_bound`, whose header absorbs the statement
/// identity in the same `"calibration"` slot). So every single-block entry
/// point — prove, verify, encode, decode — refuses such a shape by name, and
/// a trained block is proved as a one-block (or longer) BOUND run.
pub(crate) fn single_block_profile_allowed(sh: &Shape) -> Result<(), String> {
    // re-review R2-a: the profile STRING decides too, not only the door's flag
    // (W16 review F1: the W16 profile strings too)
    if sh.trained_calibration || super::shape::is_trained_profile_string(sh.profile) {
        return Err(format!(
            "private block: {} has a trained calibration; it proves only inside a run bound to its trained-model statement (a single-block receipt would carry the synthetic calibration literal, R2-4)",
            sh.profile
        ));
    }
    Ok(())
}

pub(crate) fn prove_inner_at(sh: &Shape, blk: &BlockPublic, wit: Witness, expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    single_block_profile_allowed(sh)?;
    use std::time::Instant;
    let mut tick = Instant::now();
    let mut ph = timing::Phases::start();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    // RULING CS-8: the shape is one `Shape::new` builds, before anything is
    // derived from it
    sh.check_constructed()?;
    fits_the_ntt_tables(sh)?;
    let lay = Layout::for_shape(sh)?;
    // RULINGS CS-1 and CS-4: the block statement and the endpoint policy,
    // before the endpoint owners are opened, the randomness is seeded or the
    // transcript header is absorbed
    blk.check_for_shape(sh)?;
    expected.spec.check_for_shape(sh)?;
    let [ein, eout] = check_endpoints(sh, expected, endpoints)?;
    // ONE OS stream per attempt; entropy failure aborts before anything public exists.
    //
    // **STAGE 26 (the ruling on finding B-1).** The domain is
    // `hash_domain::single_block_seed_domain(sh)`: at a TAGGED profile a
    // versioned use literal, the single-block prover's role byte and this
    // profile's string, so that the stream is separated from the two
    // endpoint generators' by its bytes and not only by its entropy read; at
    // the two FROZEN legacy-rule profiles (the byte-frozen toy and the
    // frozen-seam rung) it is the bare profile string this line has always
    // passed, unchanged. Every field of it is PUBLIC.
    let mut rng = ZkRng::from_os(&super::hash_domain::single_block_seed_domain(sh)).map_err(|e| format!("private block randomness: {e}"))?;
    ph.mark(Half::Setup, "setup: layout, endpoint owners, OS randomness", (lay.a_rows + lay.h_rows) as u64, "A+H rows");
    let ntt = NttTables::new(ntt_log_at(sh));
    ph.mark(Half::Setup, "setup: NTT tables", 1u64 << ntt_log_at(sh), "domain");
    let mut tr = transcript(blk, expected, &lay);
    let core = prove_core(sh, &lay, blk, wit, [ein.data.as_slice(), eout.data.as_slice()], &ntt, &mut rng, &mut tr, &mut ph, &mut phases, &mut tick)?;
    let [ic, oc] = core.io_claims;
    check_endpoint_opening(&ic, sh, &tr)?;
    let in_open = pcs::open_zk(&ein, &ic, &mut tr);
    drop(ein);
    ph.mark(Half::Open, "open endpoint IN (pcs::open_zk)", sh.endpoint_rows as u64, "rows");
    check_endpoint_opening(&oc, sh, &tr)?;
    let out_open = pcs::open_zk(&eout, &oc, &mut tr);
    drop(eout);
    ph.mark(Half::Open, "open endpoint OUT (pcs::open_zk)", sh.endpoint_rows as u64, "rows");
    lap(&mut phases, &mut tick, "M + A + H + endpoint openings");
    ph.report("prove", sh.name);

    let receipt = Receipt {
        a_root: core.a_root,
        h_root: core.h_root,
        mask_root: core.mask_root,
        slots: core.slots,
        mask_open: core.mask_open,
        a_open: core.a_open,
        h_open: core.h_open,
        io_open: [in_open, out_open],
    };
    let stats = ProveStats {
        phases: phases.iter().map(|(n, s)| (n.to_string(), *s)).collect(),
        a_rows: lay.a_rows,
        h_rows: lay.h_rows,
        m_rows: lay.m_rows(),
        u8_lookups: core.lookups[0],
        exp_lookups: core.lookups[1],
        act_lookups: core.lookups[2],
        transcript_order: core.order,
    };
    Ok((receipt, stats))
}

fn lap(phases: &mut Vec<(&'static str, f64)>, tick: &mut std::time::Instant, name: &'static str) {
    phases.push((name, tick.elapsed().as_secs_f64()));
    *tick = std::time::Instant::now();
}

/// **STAGE 12.** What ONE stage of a run and ONE single block have in common,
/// produced by [`prove_core`]: the `A` commitment, `M`, the LogUp challenges,
/// `H`, the twenty-three slots and the openings of `M`, `A` and `H`, in
/// exactly that order and with exactly the bytes they had before this split.
///
/// What is deliberately NOT here is (a) the transcript header — a block's is
/// [`transcript`], a run's is the run's — and (b) the openings of the two IO
/// commitments, which a block performs at once and a run performs one stage
/// apart, because a boundary's second claim does not exist until the next
/// block's slot 21 has raised it. `io_claims` hands those two claim lists back
/// to the caller unopened.
pub(crate) struct CoreProof {
    pub a_root: crate::merkle::Digest,
    pub h_root: crate::merkle::Digest,
    pub mask_root: crate::merkle::Digest,
    pub slots: Vec<super::argument::SlotProof>,
    pub mask_open: zk::MaskOpening,
    pub a_open: pcs::OpeningZk,
    pub h_open: pcs::OpeningZk,
    /// the claims slot 21 (incoming) and slot 22 (outgoing) raised on the two
    /// IO commitments; the CALLER opens them, and a run opens the incoming one
    /// only once the previous stage's outgoing claim is beside it
    pub io_claims: [Vec<ZClaim>; 2],
    /// the absorb sequence, label by label
    pub order: Vec<String>,
    /// `(U8, exp, activation)` lookup totals, a function of the geometry
    pub lookups: [usize; 3],
}

/// **STAGE 12.** The body every proving stage shares. `io_data` is the
/// committed matrix of the incoming and of the outgoing IO commitment — two
/// endpoint planes for a single block, and a boundary plane in one or both
/// places for a stage of a run. Nothing here knows which: the slot loop reads
/// `pd.data[2]` and `pd.data[3]` exactly as it always did, and the reserved
/// pair each IO tab uses comes from the LAYOUT (`Layout::with_io_mask_rows`),
/// which is where a run's two-site geometry enters.
///
/// The caller owns the transcript, the OS randomness stream, the NTT tables
/// and the phase recorder, because a run has ONE of each for `L` stages.
#[allow(clippy::too_many_arguments)]
pub(crate) fn prove_core(
    sh: &Shape,
    lay: &Layout,
    blk: &BlockPublic,
    wit: Witness,
    io_data: [&[Fp]; 2],
    ntt: &NttTables,
    rng: &mut ZkRng,
    tr: &mut Transcript,
    ph: &mut timing::Phases,
    phases: &mut Vec<(&'static str, f64)>,
    tick: &mut std::time::Instant,
) -> Result<CoreProof, String> {
    let (public, ff) = (blk.attention(), blk.feed_forward());
    // RULING CS-8, in the body every proving path shares: the shape is one
    // `Shape::new` builds and the layout the CALLER hands is the one
    // `Layout::for_shape` derives for it — nothing drawn, absorbed or
    // committed for this block yet
    sh.check_constructed()?;
    lay.check_is_for_shape(sh)?;
    // RULINGS CS-1 and CS-4, in the body every proving path shares
    blk.check_for_shape(sh)?;
    let (ids, hids, n) = (lay.ids(), lay.hids(), lay.n());
    // every plane but the three derived histograms
    let committed: Vec<usize> = lay.a_planes().into_iter().filter(|p| !ids.is_multiplicity(*p)).collect();
    if wit.planes.len() != ids.n_a() || committed.iter().any(|p| wit.planes[*p].len() != sh.size(ids.dom(*p))) {
        return Err("private block: witness shape".into());
    }
    let params = pcs_params_at(sh);
    let zko = ZkOpts::standard(&params);

    // ---- A: planes, the three committed histograms, every mask row drawn BEFORE the commitment ----
    let mut a_data = vec![Fp::ZERO; lay.a_rows * n];
    // [ZK60-METAL M4i] the same words in the same places, in one parallel pass
    let plane_jobs: Vec<(usize, &[i64])> = committed.iter().map(|p| (lay.a_off[*p], wit.planes[*p].as_slice())).collect();
    write_planes(&mut a_data, &plane_jobs);
    drop(plane_jobs);
    ph.mark_bytes(Half::Commit, "A: allocate + witness planes -> committed rows", (lay.a_rows * n) as u64, "words", 8 * (lay.a_rows * n) as u64);
    // Histograms are indexed by registered table entries, never row width:
    // byte/exp and legacy ACT have 256 entries; ACT3 has groups*4096.
    // Invalid queries retain the bucket-0/miss refusal before A masks.
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_values(&lay, &wit, *d))).collect();
    // a public count: how many lookup words the six lookup domains carry at
    // THIS shape. It is a function of the geometry and of nothing private.
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    // W16 (D54): the byte histogram plus one histogram per range family, and
    // the looked words outside their own table; every other profile keeps the
    // byte histogram alone, unchanged
    #[allow(unused_mut)]
    let (mut m_u8, m_rng, w16_missed) = if sh.range16() { w16_histograms(lay, &looked) } else { (byte_histogram_at(&looked, lookup_words, HISTOGRAM_PAR_MIN), Vec::new(), 0) };
    // W16 review F3 (test builds only): the cheating prover's misfiled range
    // counts, and a binding the moved-multiplicity hook below may edit
    #[cfg(test)]
    let mut m_rng = misfile_range_misses(lay, &looked, m_rng);
    ph.mark(Half::Commit, "A: lookup values + the byte histogram", lookup_words, "words");
    let deltas = exp_deltas(lay, &wit);
    let (mut m_exp, exp_missed) = exp_histogram(&deltas, &wit.planes[ids.at(A_E)], &public.exp);
    let act_idx = if blk.accuracy().is_some() {Vec::new()} else {act_indices(lay,&wit)};
    let (mut m_act, act_missed) = match blk.accuracy() {
        Some(data)=>super::accuracy_act::histogram(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)])?,
        None=>act_histogram(&act_idx,&wit.planes[ids.at(A_A16)],&ff.act),
    };
    // RULING CS-3 (ported from the 125M lane's stage 40, text per errata
    // K-1 / K-2 of its stage 44): the three bucket-0 paths above are ONE
    // named refusal HERE — after the three histograms, from values this
    // function already holds, and BEFORE the first draw of the `A` mask rows,
    // the `A` commitment and any absorb or challenge of this block's body.
    refuse_lookup_misses(if sh.range16() { w16_missed } else { u8_misses_of(&looked, lookup_words) }, exp_missed, act_missed)?;
    // NATIVE R9 (D30, CHECK.md B-8): at a DD profile, the score entries'
    // tuples against their rows' dictionaries — the same named refusal, its
    // own family (an admitted witness never misses: the builder writes the
    // dictionary from the public e column, B-7)
    if sh.dd_cap > 0 {
        refuse_dictionary_misses(dd_misses(lay, &wit, &public.dd_e_column(sh.dd_cap)?))?;
    }
    for i in 0..U8_LEN {
        a_data[lay.a_off[ids.at(A_MU8)] + i] = Fp::new(m_u8[i]);
        a_data[lay.a_off[ids.at(A_MEXP)] + i] = Fp::new(m_exp[i]);
    }
    // ACT3 has one registered 4096-row table per public group; its support
    // is independent of the 256-entry byte/exp families. The remaining
    // committed multiplicity entries stay zero.
    for (i,&count) in m_act.iter().enumerate() {
        a_data[lay.a_off[ids.at(A_MACT)] + i]=Fp::new(count);
    }
    // W16: each range sub-plane's true rows; its padded copies stay zero
    if sh.range16() {
        let fams = sh.range_families();
        for (f, s, plane) in ids.accuracy()?.range_planes() {
            let m = &m_rng[fams.iter().position(|x| *x == f).ok_or("W16: a range sub-plane outside the shape's families")?];
            let (base, sup) = (s << sh.log_cols, super::range16::support(f, sh.log_cols));
            for i in 0..sup {
                a_data[lay.a_off[plane] + i] = Fp::new(m[base + i]);
            }
        }
    }
    ph.mark(Half::Commit, "A: exp/act indices + their two histograms", (sh.size(Dom::S) + sh.size(Dom::F)) as u64, "words");
    // FINDING F-4, injection point 1 of 2 (test builds only): one count moves
    // from a true row to the padded copy of the same row. `m` is decremented
    // as well, so the TABLE HELPER derived from it below stays consistent at
    // the true row; the padded row's helper is written at injection point 2.
    #[cfg(test)]
    if let Some((which, from, to)) = moved_multiplicity() {
        let (plane, m) = match which {
            0 => (ids.at(A_MU8), &mut m_u8),
            1 => (ids.at(A_MEXP), &mut m_exp),
            2 => (ids.at(A_MACT), &mut m_act),
            // W16 review F3 (c): `3 + j` is range sub-plane `j`, of a NARROW
            // family (one sub-plane whose histogram is its support)
            _ => {
                let (f, s, plane) = ids.accuracy()?.range_planes()[which - 3];
                assert!(s == 0 && !super::range16::full(f, sh.log_cols), "the hook moves a count of a NARROW range family only");
                let fi = sh.range_families().iter().position(|x| *x == f).ok_or("W16: a range sub-plane outside the shape's families")?;
                (plane, &mut m_rng[fi])
            }
        };
        assert!(from < m.len() && to >= m.len() && to < sh.size(Dom::Tab), "the hook moves a count outside its family's registered support");
        assert!(m[from] > 0, "the hook's true row carries no multiplicity to move");
        m[from] -= 1;
        a_data[lay.a_off[plane] + from] = Fp::new(m[from]);
        a_data[lay.a_off[plane] + to] = Fp::new(1);
    }
    // [ZK60-METAL M4d] the same draws in the same order, filled in parallel
    // (`ZkRng::fill_fp` leaves the stream where the `fp()` loop left it)
    rng.fill_fp(&mut a_data[lay.a_mask_base * n..]);
    ph.mark(Half::Commit, "A: mask + proximity rows (fresh randomness)", ((lay.a_rows - lay.a_mask_base) * n) as u64, "words");
    // STAGE 17 (ruling T-1): this profile's hash tag. At a legacy-rule
    // profile `HashTag::legacy()` makes this the identical unkeyed call.
    let tag = sh.hash_tag();
    let mut a = pcs::commit_zk_owned_tagged(&params, a_data, ntt, &zko, rng, &tag);
    a.mask_rows = lay.a_site_rows();
    a.prox_mask_row = Some(lay.a_prox);
    let a_root = a.commitment().root;
    absorb_root(tr, b"A", &a_root, lay.a_rows, sh.log_cols);
    // STAGE 11: row encoding and column hashing are NOT separable here. Both
    // live inside `pcs::commit_zk_owned`, which is `hashline/src/pcs.rs` — a
    // file this lane does not edit — so the enclosing call is one phase.
    // ROUND 5: counted in committed WORDS (rows x row width), and the bytes
    // of the encoded matrix the Merkle tree hashes (x the code rate)
    ph.mark_bytes(Half::Commit, "A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", (lay.a_rows * n) as u64, "words", 8 * (lay.a_rows * n * sh.inv_rate) as u64);
    lap(phases, tick, "witness planes + commit A");

    // ---- M: all twenty-three CFS masks, committed before any challenge ----
    let mc = zk::mask_commit_tagged(&lay.mask_specs(), ntt, rng, &tag);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    // the same: `zk::mask_commit` is `hashline/src/zk.rs`, one enclosing call
    ph.mark(Half::Commit, "M: mask commit (zk::mask_commit, ONE call)", lay.m_rows() as u64, "rows");
    lap(phases, tick, "commit M");

    // ---- LogUp challenges, helpers, table helpers, the zero-sum pair, commit H ----
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(TAG_ACT));
    let mut h_data = vec![Fp::ZERO; lay.h_rows * n];
    // **STAGE 28.** The 256 byte-table denominators, inverted once for the
    // whole of `H`: what was an element-wise batch inversion over every looked
    // word is a table build plus one indexed lookup per word. Same words, same
    // refusal (see [`helper_inverses_u8`]).
    let u8_inv = u8_denominator_inverses(alpha, g_u8);
    // W16 (D54): each looked column folds its own family's tag, with that
    // family's inverse table (2^w denominators, inverted once per proof)
    if sh.range16() {
        let tabs: Vec<(u32, Fp2, Vec<Option<Fp2>>)> = sh
            .range_families()
            .iter()
            .map(|f| {
                let g = super::range16::g_range(g_u8, f.width);
                (f.width, g, super::range16::denominator_inverses(f.width, alpha, g))
            })
            .collect();
        let mut wjobs: Vec<HelperJobW16<'_>> = Vec::new();
        for (dom, cols) in &looked {
            let tags: Vec<LkTag> = lay.lookups(*dom).iter().map(|l| l.tag).collect();
            let (first, count) = lay.helpers(*dom);
            for k in 0..count {
                let b = match cols.get(2 * k + 1) {
                    Some(c) => Some(tagged_column(c, tags[2 * k + 1], g_u8, &u8_inv, &tabs)?),
                    None => None,
                };
                wjobs.push(HelperJobW16 { off: lay.h_off[first + k], a: tagged_column(&cols[2 * k], tags[2 * k], g_u8, &u8_inv, &tabs)?, b });
            }
        }
        write_helpers_w16(&mut h_data, &wjobs, alpha)?;
    }
    let mut jobs: Vec<HelperJob<'_>> = Vec::new();
    for (dom, cols) in looked.iter().filter(|_| !sh.range16()) {
        let (first, count) = lay.helpers(*dom);
        // **STAGE 28.** A helper column is the sum of the inverses of at most
        // TWO looked columns, so it is built and written one helper at a time
        // instead of inverting every column of the domain into its own vector
        // first: the same words, in the same place, without the domain-wide
        // intermediate (789 MB of looked words at the 125M shape had a second
        // copy in `Fp2` beside them). Columns are still visited in index
        // order, so a refusal is still the lowest-indexed column's.
        for k in 0..count {
            // [ZK60-METAL M4c] straight into `H`'s re/im rows: the words
            // `helper_pair_inverses_u8` / `helper_inverses_u8` build, in the
            // places `write_h` puts them, without the column-sized temporary
            // and its single-threaded copy (same words, same refusal).
            // [M4d] collected here and written in ONE parallel region below
            jobs.push(HelperJob { off: lay.h_off[first + k], a: &cols[2 * k], b: cols.get(2 * k + 1).map(|c| c.as_slice()) });
        }
    }
    if !sh.range16() {
        write_helpers_u8(&mut h_data, &jobs, alpha, g_u8, &u8_inv)?;
    }
    drop(jobs);
    ph.mark_bytes(Half::Commit, "H: LogUp helper inverses (six lookup domains)", lookup_words, "words", 16 * lookup_words);
    // [M4h] the denominators element by element on rayon: indexed iterators,
    // so the same elements in the same order (zip stops at the shorter side,
    // as the sequential zip did)
    use rayon::prelude::*;
    let exp_den = deltas.par_iter().zip(wit.planes[ids.at(A_E)].par_iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h(&mut h_data, lay.h_off[hids.sexp()], &inverses(exp_den)?);
    let act_den = match blk.accuracy() {
        // [ZK60-METAL M15] fused: one pass over the rows, no per-element
        // divisions, no intermediate vector (`accuracy_act::denominators`)
        Some(data)=>super::accuracy_act::denominators(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)],alpha,beta,g_act)?,
        None=>act_idx.par_iter().zip(wit.planes[ids.at(A_A16)].par_iter()).map(|(i,a)|alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*a))).add(g_act))).collect(),
    };
    write_h(&mut h_data, lay.h_off[hids.fact()], &inverses(act_den)?);
    ph.mark_bytes(Half::Commit, "H: exp + activation helper inverses", (sh.size(Dom::S) + sh.size(Dom::F)) as u64, "words", 16 * (sh.size(Dom::S) + sh.size(Dom::F)) as u64);
    // **NATIVE R9 (D30): the dictionary's two LogUp columns.** The score
    // entry's single tuple helper `1 / (alpha - (gamma TAG_DD + Sum + beta
    // mask E + beta^2 P))`, and the TABLE helper `M_dd / (alpha - (gamma
    // TAG_DD + Sum + beta e + beta^2 P_dict))` at every dictionary slot. D30
    // condition 4 / CHECK.md P-4: the prover inverts EVERY slot's denominator
    // on every attempt — unused and padding slots included, before any
    // multiplicity enters — so whether a zero denominator refuses the attempt
    // depends on the hidden data only through the set of table values.
    if sh.dd_cap > 0 {
        let g_dd = gamma.mul_base(Fp::new(TAG_DD));
        let (tq, tt) = dd_tuples(lay, &wit, &public.dd_e_column(sh.dd_cap)?, beta, g_dd);
        write_h(&mut h_data, lay.h_off[hids.stuple()], &inverses(tq.iter().map(|q| alpha.sub(*q)).collect())?);
        let inv = inverses(tt.iter().map(|q| alpha.sub(*q)).collect())?;
        #[allow(unused_mut)]
        let mut m: Vec<i64> = wit.planes[ids.mdd()].clone();
        // CHECK.md D-8, TEST BUILDS ONLY: a prover whose multiplicities are
        // chosen AFTER alpha (one count moved) while `A` holds the honest ones
        #[cfg(test)]
        if let Some((from, to)) = dd_moved_multiplicity() {
            m[from] -= 1;
            m[to] += 1;
        }
        let col: Vec<Fp2> = inv.iter().zip(m.iter()).map(|(x, c)| x.mul_base(Fp::from_i64(*c))).collect();
        write_h(&mut h_data, lay.h_off[hids.gdd()], &col);
        ph.mark_bytes(Half::Commit, "H: dictionary tuple + table helpers (every slot inverted)", (sh.size(Dom::S) + sh.size(Dom::Dd)) as u64, "words", 16 * (sh.size(Dom::S) + sh.size(Dom::Dd)) as u64);
    }
    // ---- STEP S2 (C-11): the prover's four transient buffers die HERE ----
    // The two lines above are the LAST reads of the witness planes and of
    // `looked`; the memo's earlier proposal to drop them at the histogram loop
    // is wrong, because `lookup_values`, `exp_deltas`, `act_indices` and the
    // two `A_E` / `A_A16` denominators all read the planes after it, and the
    // helper columns above read `looked`. Releasing them before the three
    // table helpers, the `H` commitment and the twenty-three slots is the
    // difference between an 11.0 GiB and a 9.6 GiB modelled peak at the 125M
    // shape (memo section 7.1), where the planes are 711 MB, `looked` 789 MB,
    // `deltas` 33.6 MB and `act_idx` 8.4 MB. At the toy the four are about
    // 2 MB, which is why nobody has had a reason to do it before.
    //
    // A drop that is too EARLY is a compile error here, not a silent bug: the
    // buffers are moved, so any later read fails to build. That is a stronger
    // guarantee than the acceptance test the memo asks for, and it is why this
    // step takes the witness by value rather than by reference.
    drop(looked);
    drop(wit);
    drop(deltas);
    drop(act_idx);
    // what the S2 drops cost in time (at 125M they release about 1.5 GB)
    ph.mark(Half::Commit, "H: release the four witness buffers (S2 drops)", 0, "-");
    let [gu8, gexp, gact] = hids.table_helpers();
    let act_table=match blk.accuracy() {
        Some(data)=>{
            let table=super::accuracy_act::table(data,sh.size(Dom::Tab),beta,g_act)?;
            table.compressed[..table.entries].to_vec()
        },
        None=>table_values_act(ff,beta,g_act),
    };
    for (plane, tv, m) in [
        (gu8, table_values_u8(g_u8), &m_u8),
        (gexp, table_values_exp(public, beta, g_exp), &m_exp),
        (gact, act_table, &m_act),
    ] {
        let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;
        let col: Vec<Fp2> = inv.iter().zip(m.iter()).map(|(x, c)| x.mul_base(Fp::new(*c))).collect();
        write_h(&mut h_data, lay.h_off[plane], &col);
    }
    // W16 (D54): one table helper per range sub-plane, `m / (alpha - t)` on
    // its true rows and zero on its padded copies (whose multiplicity is zero);
    // every entry's denominator is inverted, padded copies included, as the
    // three tables' are
    if sh.range16() {
        let fams = sh.range_families();
        let rh: Vec<usize> = hids.range_helpers().collect();
        for (j, (f, s, _)) in ids.accuracy()?.range_planes().into_iter().enumerate() {
            let m = &m_rng[fams.iter().position(|x| *x == f).ok_or("W16: a range sub-plane outside the shape's families")?];
            let tv = super::range16::table_column(f, s, sh.log_cols, super::range16::g_range(g_u8, f.width));
            let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;
            let (base, sup) = (s << sh.log_cols, super::range16::support(f, sh.log_cols));
            let col: Vec<Fp2> = inv.iter().enumerate().map(|(i, x)| if i < sup { x.mul_base(Fp::new(m[base + i])) } else { Fp2::ZERO }).collect();
            write_h(&mut h_data, lay.h_off[rh[j]], &col);
        }
    }
    ph.mark(Half::Commit, "H: the three table helpers", 3 * sh.size(Dom::Tab) as u64, "words");
    // FINDING F-4, injection point 2 of 2 (test builds only): the padded row
    // the count moved to now needs its own helper `1 / (alpha - value)`, and
    // the padded value is the true row's by the P-3 lift's own construction.
    // With it written, the value-0 LogUp identity and all three `SC_TAB`
    // product relations hold, and only the pad-zero term can object.
    #[cfg(test)]
    if let Some((which, from, to)) = moved_multiplicity() {
        let tab_len = sh.size(Dom::Tab);
        let (plane, tv) = match which {
            0 => (gu8, super::argument::table_values_u8_at(tab_len, g_u8)),
            1 => (gexp, super::argument::table_values_exp_at(tab_len, public, beta, g_exp)),
            2 => (gact,match blk.accuracy() {
                Some(data)=>super::accuracy_act::table(data,tab_len,beta,g_act)?.compressed,
                None=>super::argument::table_values_act_at(tab_len,ff,beta,g_act),
            }),
            // W16 review F3 (c): the range sub-plane's own table helper and column
            _ => {
                let (f, s, _) = ids.accuracy()?.range_planes()[which - 3];
                let helper = hids.range_helpers().nth(which - 3).ok_or("W16: a range sub-plane without its table helper")?;
                (helper, super::range16::table_column(f, s, sh.log_cols, super::range16::g_range(g_u8, f.width)))
            }
        };
        assert_eq!(tv[to], tv[from], "the padded row does not repeat its true row");
        let val = inverses(vec![alpha.sub(tv[to])])?[0];
        let off = lay.h_off[plane];
        write_h(&mut h_data, (off.0 + to, off.1 + to), &[val]);
    }
    // [ZK60-METAL M4d] the same draws in the same order as the `fp()` loops:
    // every mask row first, then each zero-sum row's first `n - 1` words
    rng.fill_fp(&mut h_data[lay.h_mask_base * n..]);
    for r in lay.h_u_rows() {
        let row = &mut h_data[r * n..(r + 1) * n];
        rng.fill_fp(&mut row[..n - 1]);
        let sum = row[..n - 1].iter().fold(Fp::ZERO, |s, v| s.add(*v));
        row[n - 1] = sum.neg();
    }
    ph.mark(Half::Commit, "H: mask rows + the zero-sum rows", ((lay.h_rows - lay.h_mask_base) * n) as u64, "words");
    let mut h = pcs::commit_zk_owned_tagged(&params, h_data, ntt, &zko, rng, &tag);
    h.mask_rows = lay.h_site_rows().into_iter().chain(lay.h_u_rows()).collect();
    h.prox_mask_row = Some(lay.h_prox);
    let h_root = h.commitment().root;
    absorb_root(tr, b"H", &h_root, lay.h_rows, sh.log_cols);
    ph.mark_bytes(Half::Commit, "H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", (lay.h_rows * n) as u64, "words", 8 * (lay.h_rows * n * sh.inv_rate) as u64);
    lap(phases, tick, "LogUp helpers + commit H");

    // ---- the twenty-three slots ----
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    let ctx = Ctx { accuracy:blk.accuracy(), lay, public, ff, alpha, beta, g_u8, g_exp, g_act, g_dd };
    let pd = ProverData { data: [a.data.as_slice(), h.data.as_slice(), io_data[0], io_data[1]], masks: &mc.masks };
    let mut side = Side::Prove { pd, out: Vec::new() };
    let acc = argument(&mut side, &ctx, tr, ph)?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        Side::Verify { .. } => unreachable!(),
    };
    lap(phases, tick, "23 masked sumchecks");

    // ---- ONE M opening, then ONE opening per commitment; each owner dropped after its opening ----
    let mask_open = zk::mask_open(&mc, &acc.fs, ntt, tr);
    drop(mc);
    ph.mark(Half::Open, "open M (zk::mask_open, ONE call)", lay.m_rows() as u64, "rows");
    let order = acc.order;
    let [ac, hc, ic, oc] = finish_claims(acc.claims, lay);
    check_opening(&ac, sh.log_cols, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, sh.a_groups(), tr)?;
    let a_open = pcs::open_zk(&a, &ac, tr);
    drop(a);
    // ROUND 5: counted as the committed words the opening combines
    ph.mark_bytes(Half::Open, "open A (schedule audit + pcs::open_zk)", (lay.a_rows * lay.n()) as u64, "words", 8 * (lay.a_rows * lay.n()) as u64);
    let _ = ac.len();
    check_opening(&hc, sh.log_cols, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups(), tr)?;
    let h_open = pcs::open_zk(&h, &hc, tr);
    drop(h);
    ph.mark_bytes(Half::Open, "open H (schedule audit + pcs::open_zk)", (lay.h_rows * lay.n()) as u64, "words", 8 * (lay.h_rows * lay.n()) as u64);
    let _ = hc.len();
    Ok(CoreProof {
        a_root,
        h_root,
        mask_root,
        slots,
        mask_open,
        a_open,
        h_open,
        io_claims: [ic, oc],
        order,
        // W16: the first total counts the byte and range lookups together
        lookups: [(m_u8.iter().sum::<u64>() + m_rng.iter().flatten().sum::<u64>()) as usize, m_exp.iter().sum::<u64>() as usize, m_act.iter().sum::<u64>() as usize],
    })
}

// ---------------------------------------------------------------- verifier

/// **STAGE 12.** The verifier's view of the bytes [`prove_core`] produced —
/// one stage of a run, or the whole of a single block. Every count the
/// verifier needs comes from its own [`Layout`], never from this view.
pub(crate) struct CoreView<'a> {
    pub a_root: crate::merkle::Digest,
    pub h_root: crate::merkle::Digest,
    pub mask_root: crate::merkle::Digest,
    pub slots: &'a [super::argument::SlotProof],
    pub mask_open: &'a zk::MaskOpening,
    pub a_open: &'a pcs::OpeningZk,
    pub h_open: &'a pcs::OpeningZk,
}

/// **STAGE 12.** The verifying body every stage shares: the `A` and `M`
/// roots, the LogUp challenges, the `H` root, the twenty-three slots and the
/// verification of `M`, `A` and `H`, in exactly that order.
///
/// It returns the two IO claim lists **it computed itself** from the slot
/// terminals (`argument.rs` pushes each claim outside the prove/verify match,
/// so the verify arm builds them identically). Nothing about a claim is ever
/// read from a frame — which is what lets a run's verifier carry block `k`'s
/// pending boundary claim into stage `k + 1` without trusting a segment.
pub(crate) fn verify_core(sh: &Shape, lay: &Layout, blk: &BlockPublic, v: CoreView, ntt: &NttTables, tr: &mut Transcript, ph: &mut timing::Phases) -> Result<([Vec<ZClaim>; 2], Vec<String>), String> {
    let (public, ff) = (blk.attention(), blk.feed_forward());
    // RULING CS-8, in the body every verifying path shares: the shape and
    // the layout the CALLER hands, before anything is absorbed or squeezed
    sh.check_constructed()?;
    lay.check_is_for_shape(sh)?;
    // RULINGS CS-1 and CS-4, in the body every verifying path shares
    blk.check_for_shape(sh)?;
    let params = pcs_params_at(sh);
    let zko = ZkOpts::standard(&params);
    // STAGE 17 (ruling T-7): the tag is the VERIFIER's, from the shape its
    // caller trusts. Nothing in `v` — a view over decoded bytes — is asked.
    let tag = sh.hash_tag();
    // **STAGE 16, ruling T-4.** Before anything of this stage is hashed:
    // every opened column of the three commitments this body verifies
    // carries exactly its commitment's tree depth. The core verifier folds
    // whatever path length it is handed (`zkp-core/src/merkle.rs:56-63`), and
    // an inner node is the same 64-byte hash as a salted leaf, so the length
    // is what stops a node being opened as a leaf. This was implicit in
    // `wire.rs` reading a fixed path count out of the layout; it is a named
    // check of the verifier now, and it holds for a structure that never
    // went through a wire.
    super::hash_domain::paths_are_the_tree_depth("A", &params, v.a_open)?;
    super::hash_domain::paths_are_the_tree_depth("H", &params, v.h_open)?;
    super::hash_domain::mask_paths_are_the_tree_depth(v.mask_open)?;
    absorb_root(tr, b"A", &v.a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &v.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(TAG_ACT));
    absorb_root(tr, b"H", &v.h_root, lay.h_rows, sh.log_cols);
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    let ctx = Ctx { accuracy:blk.accuracy(), lay, public, ff, alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: v.slots };
    ph.mark(Half::Setup, "transcript header + the A and H roots", 2, "roots");
    let acc = argument(&mut side, &ctx, tr, ph)?;
    #[cfg(test)]
    let capture_before = super::capture::checkpoint(tr);
    // STAGE 14: the run capture observes the same site. Its `checkpoint`
    // returns `None` unless a recorder is attached.
    #[cfg(test)]
    let run_capture_before = super::run_capture::checkpoint(tr);
    zk::mask_verify_tagged(&v.mask_root, &lay.mask_specs(), &acc.fs, v.mask_open, ntt, tr, &tag).map_err(|e| format!("M: {e}"))?;
    #[cfg(test)]
    super::capture::mask(&v.mask_root, &acc.fs, v.mask_open, capture_before, tr);
    #[cfg(test)]
    super::run_capture::mask(&lay.mask_specs(), &v.mask_root, &acc.fs, v.mask_open, ntt, run_capture_before, tr);
    ph.mark(Half::Open, "verify M (zk::mask_verify, ONE call)", lay.m_rows() as u64, "rows");
    let order = acc.order;
    let [ac, hc, ic, oc] = finish_claims(acc.claims, lay);
    check_opening(&ac, sh.log_cols, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, sh.a_groups(), tr)?;
    #[cfg(test)]
    let capture_before = super::capture::checkpoint(tr);
    #[cfg(test)]
    let run_capture_before = super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &commitment(v.a_root, lay.a_rows, sh.log_cols), &ac, v.a_open, ntt, tr, &tag).map_err(|e| format!("A: {e}"))?;
    #[cfg(test)]
    super::capture::pcs("A", v.a_root, lay.a_rows, &ac, v.a_open, capture_before, tr);
    #[cfg(test)]
    super::run_capture::pcs(
        super::run_capture::Geom {
            role: "A",
            commitment_kind: "block",
            params,
            root: v.a_root,
            rows: lay.a_rows,
            data_rows: lay.a_data_rows,
            site_rows: lay.a_site_rows(),
            sum_rows: None,
            prox_row: lay.a_prox,
            boundary: None,
            claim_sources: vec![],
        },
        &ac,
        v.a_open,
        ntt,
        run_capture_before,
        tr,
    );
    ph.mark(Half::Open, "verify A (schedule audit + pcs::verify_zk)", ac.len() as u64, "claims");
    check_opening(&hc, sh.log_cols, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups(), tr)?;
    #[cfg(test)]
    let capture_before = super::capture::checkpoint(tr);
    #[cfg(test)]
    let run_capture_before = super::run_capture::checkpoint(tr);
    pcs::verify_zk_tagged(&params, &zko, &commitment(v.h_root, lay.h_rows, sh.log_cols), &hc, v.h_open, ntt, tr, &tag).map_err(|e| format!("H: {e}"))?;
    #[cfg(test)]
    super::capture::pcs("H", v.h_root, lay.h_rows, &hc, v.h_open, capture_before, tr);
    #[cfg(test)]
    super::run_capture::pcs(
        super::run_capture::Geom {
            role: "H",
            commitment_kind: "block",
            params,
            root: v.h_root,
            rows: lay.h_rows,
            data_rows: lay.h_data_rows,
            site_rows: lay.h_site_rows(),
            sum_rows: Some(lay.h_u_rows()),
            prox_row: lay.h_prox,
            boundary: None,
            claim_sources: vec![],
        },
        &hc,
        v.h_open,
        ntt,
        run_capture_before,
        tr,
    );
    ph.mark(Half::Open, "verify H (schedule audit + pcs::verify_zk)", hc.len() as u64, "claims");
    Ok(([ic, oc], order))
}

/// Accepts only against the caller's own public statement and endpoint policy.
/// Returns the absorb sequence (for the transcript-order gate).
pub(crate) fn verify_inner(blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<Vec<String>, String> {
    verify_inner_at(&Shape::toy(), blk, expected, receipt)
}

/// **STEP C part 2.** The same verifier at any [`Shape`]; `verify_inner` is
/// this at `Shape::toy()`. The verifier reads the shape from its CALLER, never
/// from the receipt: nothing in the frame chooses a geometry.
pub(crate) fn verify_inner_at(sh: &Shape, blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<Vec<String>, String> {
    single_block_profile_allowed(sh)?;
    #[cfg(test)]
    super::capture::begin();
    let mut ph = timing::Phases::start();
    // RULING CS-8: the shape the caller trusts is one `Shape::new` builds
    sh.check_constructed()?;
    fits_the_ntt_tables(sh)?;
    let lay = Layout::for_shape(sh)?;
    // RULINGS CS-1 and CS-4: the block statement and the endpoint policy,
    // before the receipt is looked at or the header absorbed
    blk.check_for_shape(sh)?;
    expected.spec.check_for_shape(sh)?;
    // **STAGE 16, ruling T-4**, before the frame shape check so that the
    // refusal a caller sees names the commitment and the two path lengths
    // rather than being the generic "opening shape". The five commitments of
    // a block receipt: `A`, `H`, `M` and the two external endpoints.
    super::hash_domain::receipt_paths_are_the_tree_depth(receipt, sh)?;
    super::wire::validate(receipt, &lay)?;
    // S11b: whichever endpoint construction this profile carries, its
    // statements must be well formed and their geometry the shape's
    expected.spec.validate()?;
    ph.mark(Half::Setup, "setup: layout + frame shape validation", (lay.a_rows + lay.h_rows) as u64, "A+H rows");
    let ntt = NttTables::new(ntt_log_at(sh));
    ph.mark(Half::Setup, "setup: NTT tables", 1u64 << ntt_log_at(sh), "domain");
    let mut tr = transcript(blk, expected, &lay);
    let view = CoreView {
        a_root: receipt.a_root,
        h_root: receipt.h_root,
        mask_root: receipt.mask_root,
        slots: &receipt.slots,
        mask_open: &receipt.mask_open,
        a_open: &receipt.a_open,
        h_open: &receipt.h_open,
    };
    let ([ic, oc], order) = verify_core(sh, &lay, blk, view, &ntt, &mut tr, &mut ph)?;
    let e_params = endpoint_pcs_params(sh);
    let e_zko = ZkOpts::standard(&e_params);
    let tag = sh.hash_tag();
    for (i, (claims, root)) in [(&ic, expected.input), (&oc, expected.output)].into_iter().enumerate() {
        check_endpoint_opening(claims, sh, &tr)?;
        #[cfg(test)]
        let capture_before = super::capture::checkpoint(&tr);
        pcs::verify_zk_tagged(&e_params, &e_zko, &commitment(root, sh.endpoint_rows, sh.endpoint_log_n), claims, &receipt.io_open[i], &ntt, &mut tr, &tag).map_err(|e| format!("endpoint {i}: {e}"))?;
        #[cfg(test)]
        super::capture::pcs(["Input", "Output"][i], root, sh.endpoint_rows, claims, &receipt.io_open[i], capture_before, &tr);
        ph.mark(Half::Open, ["verify endpoint IN (pcs::verify_zk)", "verify endpoint OUT (pcs::verify_zk)"][i], sh.endpoint_rows as u64, "rows");
    }
    ph.report("verify", sh.name);
    #[cfg(test)]
    super::capture::publish(blk, expected, receipt);
    Ok(order)
}
