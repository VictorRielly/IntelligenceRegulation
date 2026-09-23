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
        "T{}/d{}/f{}/H{}/KV{}/dh{}/log_cols{}/inv_rate{}/Q{}/P1/sh-g{SH_G}-u0-h{SH_H_PROD}-z{SH_Z}/two-private-endpoints/one-proof-one-transcript",
        sh.tokens, sh.width, sh.hidden, sh.q_heads, sh.kv_heads, sh.head_dim, sh.log_cols, sh.inv_rate, sh.opened_cols
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
    for p in lay.h_planes() {
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
pub(crate) fn audit_claims(claims: &[ZClaim], n: usize, rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize) -> Result<(), String> {
    let fail = |what: &str| Err(format!("private block: mask schedule audit: {what}"));
    if prox + 2 != rows || site_rows.len() % 2 != 0 {
        return fail("proximity pair placement");
    }
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
        match (is_sum, sum_rows) {
            (true, Some(u)) if ci + 1 == claims.len() => {
                let covered = |row: usize| claim.parts.iter().any(|p| part_rows(p, n).contains(&row) && !p.coef.is_zero());
                if !touched.is_empty() || !covered(u[0]) || !covered(u[1]) {
                    return fail("the sum claim is not masked by the zero-sum pair alone");
                }
            }
            (false, _) => {
                if touched.len() != 2 || touched[1] != touched[0] + 1 || (touched[0] - site_rows[0]) % 2 != 0 {
                    return fail("a claim does not carry exactly its own reserved pair");
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
///
/// **STAGE 36 — the read-only TEST OBSERVER** (the integrator's
/// authorisation of 2026-09-22 07:25, reversing what ruling GS-2 declined
/// in stage 23). The five `#[cfg(test)]` lines below are the whole of it:
/// one that shadows `draw` with a counting wrapper, and one beside each of
/// the three exits. They record HOW MANY challenges this call drew and
/// WHICH exit it took, into `super::draw_observer`'s thread-local, and
/// they record nothing else — no coefficient, no determinant, no state.
/// A build without `cfg(test)` compiles none of them, so the production
/// function is the one that was here before, statement for statement: not
/// one existing line is restructured.
pub(crate) fn check_opening_challenges(groups: &[usize], rows: usize, prox: usize, mut draw: impl FnMut() -> Fp2) -> Result<(), String> {
    #[cfg(test)]
    let mut draw = super::draw_observer::counting(&mut draw);
    for &count in groups {
        if (0..count).map(|_| draw()).any(|c| c.is_zero()) {
            #[cfg(test)]
            super::draw_observer::note_verdict(super::draw_observer::Verdict::ZeroGroupMember);
            return Err("zero group member coefficient; discard attempt".into());
        }
    }
    #[cfg(test)]
    super::draw_observer::note_groups_passed();
    let rho: Vec<Fp2> = (0..rows).map(|_| draw()).collect();
    if prox + 1 >= rows || determinant(rho[prox], rho[prox + 1]).is_zero() {
        #[cfg(test)]
        super::draw_observer::note_verdict(super::draw_observer::Verdict::DependentProximity);
        return Err("dependent proximity mask coefficients; discard attempt".into());
    }
    #[cfg(test)]
    super::draw_observer::note_verdict(super::draw_observer::Verdict::Accepted);
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
/// identity can catch it — and since ruling CS-3 the honest prover refuses
/// such a witness by name before its `A` commitment, see
/// [`refuse_lookup_misses`].) `lookup_words` is the PUBLIC word count of the
/// shape, which is what chooses the branch — never a witness value.
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

/// **RULING CS-3.** How many looked words are outside the byte table — the
/// words [`byte_histogram_at`] files in entry 0. A count of public-length
/// columns, parallel above the same public threshold as the histogram.
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

/// **RULING CS-3: the ONE refusal of a lookup miss.** Before this ruling a
/// looked value that is not a row of its table was filed in histogram entry
/// 0 on three silent paths, the proof went ahead, and only the verifier's
/// LogUp identity rejected the receipt. `prove_core` calls this after the
/// three histograms and before the first draw of the block's `A` mask rows.
///
/// A CHEATING prover does not run this check, and the soundness tests play
/// one: under `#[cfg(test)]` a thread-local switch ([`CheatingProver`]) makes
/// it return `Ok`, so a tampered witness still reaches the verifier. A
/// release build has no switch.
fn refuse_lookup_misses(u8: usize, exp: usize, act: usize) -> Result<(), String> {
    #[cfg(test)]
    if CHEATING_PROVER.with(|c| c.get()) {
        return Ok(());
    }
    if u8 + exp + act == 0 {
        return Ok(());
    }
    Err(format!(
        "{LOOKUP_MISS_REFUSAL} (refused before the A commitment; nothing of this block was drawn, absorbed or committed): {u8} U8 words outside the byte table, {exp} exp pairs and {act} activation pairs not rows of the statement's tables"
    ))
}

// **RULING CS-3's test-only switch: the soundness tests' CHEATING PROVER.**
// A soundness test hands the honest prover a TAMPERED witness to stand in for
// a cheating prover, which commits whatever it likes and never runs the
// prover's own consistency checks. While a [`CheatingProver`] guard lives on
// the calling thread, `refuse_lookup_misses` lets a miss through to bucket 0
// exactly as before ruling CS-3, so those tests keep reaching the verifier.
// `#[cfg(test)]` throughout: a release build has neither the state nor the
// guard.
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

/// **STAGE 42.** Whether a [`CheatingProver`] guard lives on this thread
/// (test only): the run prover's copy of ruling CS-6's check (`run.rs`)
/// honours it, so a soundness test can still make the receipt a cheating
/// RUN prover would make. A release build has neither this nor the switch.
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

fn inverses(mut den: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    batch_inverse2_checked(&mut den).map_err(|_| "zero LogUp denominator; discard attempt".to_string())?;
    Ok(den)
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

fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
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
pub(crate) fn prove_inner_at(sh: &Shape, blk: &BlockPublic, wit: Witness, expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
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
        m_rows: M_ROWS,
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
    // RULINGS CS-1 and CS-4, in the body every proving path shares (the
    // single block's entry and the run's entry have made the same check
    // already): nothing has been drawn, absorbed or committed for this block
    // yet
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
    for p in &committed {
        for (i, v) in wit.planes[*p].iter().enumerate() {
            a_data[lay.a_off[*p] + i] = Fp::from_i64(*v);
        }
    }
    ph.mark(Half::Commit, "A: allocate + witness planes -> committed rows", (lay.a_rows * n) as u64, "words");
    // The three histograms are indexed by a TABLE ENTRY, so they are `U8_LEN`
    // long and their in-class guards test `[0, U8_LEN)` — never the row width
    // `N` (trap T-1). The two guards that index `public.exp` (256 words) and
    // `ff.act` (`[i16; 256]`) are what stops a widened `N` from turning a
    // graceful bucket-0 fallback into an out-of-bounds panic (missed pin M-4).
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = lay.lookup_doms().iter().map(|d| (*d, lookup_values(&lay, &wit, *d))).collect();
    // a public count: how many lookup words the six lookup domains carry at
    // THIS shape. It is a function of the geometry and of nothing private.
    let lookup_words: u64 = looked.iter().map(|(d, cols)| (cols.len() * sh.size(*d)) as u64).sum();
    let mut m_u8 = byte_histogram_at(&looked, lookup_words, HISTOGRAM_PAR_MIN);
    ph.mark(Half::Commit, "A: lookup values + the byte histogram", lookup_words, "words");
    let deltas = exp_deltas(&lay, &wit);
    let mut m_exp = vec![0u64; U8_LEN];
    let mut exp_missed = 0usize;
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(d) && public.exp[*d as usize] == wit.planes[ids.at(A_E)][x];
        exp_missed += usize::from(!hit);
        m_exp[if hit { *d as usize } else { 0 }] += 1;
    }
    let act_idx = act_indices(&lay, &wit);
    let mut m_act = vec![0u64; U8_LEN];
    let mut act_missed = 0usize;
    for (x, i) in act_idx.iter().enumerate() {
        let hit = (0..U8_LEN as i64).contains(i) && i64::from(ff.act[*i as usize]) == wit.planes[ids.at(A_A16)][x];
        act_missed += usize::from(!hit);
        m_act[if hit { *i as usize } else { 0 }] += 1;
    }
    // RULING CS-3 (security owner, 2026-09-22): the three bucket-0 paths
    // above (a looked word outside the byte table, an exp pair or an
    // activation pair that is not a table row) are ONE named refusal HERE —
    // after the three histograms, from values this function already holds,
    // and BEFORE the first draw of the `A` mask rows, the `A` commitment and
    // any absorb or challenge of this block. For a witness the builder admits
    // it is unreachable (the census); it turns a future admissibility gap
    // into a refusal of the prover instead of a receipt the verifier rejects.
    refuse_lookup_misses(u8_misses_of(&looked, lookup_words), exp_missed, act_missed)?;
    for i in 0..U8_LEN {
        a_data[lay.a_off[ids.at(A_MU8)] + i] = Fp::new(m_u8[i]);
        a_data[lay.a_off[ids.at(A_MEXP)] + i] = Fp::new(m_exp[i]);
        a_data[lay.a_off[ids.at(A_MACT)] + i] = Fp::new(m_act[i]);
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
            _ => (ids.at(A_MACT), &mut m_act),
        };
        assert!(from < U8_LEN && to >= U8_LEN && to < sh.size(Dom::Tab) && to % U8_LEN == from, "the hook moves a count to the PADDED COPY of its own row");
        assert!(m[from] > 0, "the hook's true row carries no multiplicity to move");
        m[from] -= 1;
        a_data[lay.a_off[plane] + from] = Fp::new(m[from]);
        a_data[lay.a_off[plane] + to] = Fp::new(1);
    }
    for x in &mut a_data[lay.a_mask_base * n..] {
        *x = rng.fp();
    }
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
    ph.mark(Half::Commit, "A: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", lay.a_rows as u64, "rows");
    lap(phases, tick, "witness planes + commit A");

    // ---- M: all twenty-three CFS masks, committed before any challenge ----
    let mc = zk::mask_commit_tagged(&lay.mask_specs(), ntt, rng, &tag);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    // the same: `zk::mask_commit` is `hashline/src/zk.rs`, one enclosing call
    ph.mark(Half::Commit, "M: mask commit (zk::mask_commit, ONE call)", M_ROWS as u64, "rows");
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
    for (dom, cols) in &looked {
        let (first, count) = lay.helpers(*dom);
        // **STAGE 28.** A helper column is the sum of the inverses of at most
        // TWO looked columns, so it is built and written one helper at a time
        // instead of inverting every column of the domain into its own vector
        // first: the same words, in the same place, without the domain-wide
        // intermediate (789 MB of looked words at the 125M shape had a second
        // copy in `Fp2` beside them). Columns are still visited in index
        // order, so a refusal is still the lowest-indexed column's.
        for k in 0..count {
            let col = match cols.get(2 * k + 1) {
                Some(second) => helper_pair_inverses_u8(&cols[2 * k], second, alpha, g_u8, &u8_inv)?,
                None => helper_inverses_u8(&cols[2 * k], alpha, g_u8, &u8_inv)?,
            };
            write_h(&mut h_data, lay.h_off[first + k], &col);
        }
    }
    ph.mark(Half::Commit, "H: LogUp helper inverses (six lookup domains)", lookup_words, "words");
    let exp_den = deltas.iter().zip(wit.planes[ids.at(A_E)].iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h(&mut h_data, lay.h_off[hids.sexp()], &inverses(exp_den)?);
    let act_den = act_idx.iter().zip(wit.planes[ids.at(A_A16)].iter()).map(|(i, a)| alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*a))).add(g_act))).collect();
    write_h(&mut h_data, lay.h_off[hids.fact()], &inverses(act_den)?);
    ph.mark(Half::Commit, "H: exp + activation helper inverses", (sh.size(Dom::S) + sh.size(Dom::F)) as u64, "words");
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
    for (plane, tv, m) in [
        (gu8, table_values_u8(g_u8), &m_u8),
        (gexp, table_values_exp(public, beta, g_exp), &m_exp),
        (gact, table_values_act(ff, beta, g_act), &m_act),
    ] {
        let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;
        let col: Vec<Fp2> = inv.iter().zip(m.iter()).map(|(x, c)| x.mul_base(Fp::new(*c))).collect();
        write_h(&mut h_data, lay.h_off[plane], &col);
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
            _ => (gact, super::argument::table_values_act_at(tab_len, ff, beta, g_act)),
        };
        assert_eq!(tv[to], tv[from], "the padded row does not repeat its true row");
        let val = inverses(vec![alpha.sub(tv[to])])?[0];
        let off = lay.h_off[plane];
        write_h(&mut h_data, (off.0 + to, off.1 + to), &[val]);
    }
    for x in &mut h_data[lay.h_mask_base * n..] {
        *x = rng.fp();
    }
    for r in lay.h_u_rows() {
        let mut sum = Fp::ZERO;
        for j in 0..n - 1 {
            let v = rng.fp();
            h_data[r * n + j] = v;
            sum = sum.add(v);
        }
        h_data[r * n + n - 1] = sum.neg();
    }
    ph.mark(Half::Commit, "H: mask rows + the zero-sum rows", ((lay.h_rows - lay.h_mask_base) * n) as u64, "words");
    let mut h = pcs::commit_zk_owned_tagged(&params, h_data, ntt, &zko, rng, &tag);
    h.mask_rows = lay.h_site_rows().into_iter().chain(lay.h_u_rows()).collect();
    h.prox_mask_row = Some(lay.h_prox);
    let h_root = h.commitment().root;
    absorb_root(tr, b"H", &h_root, lay.h_rows, sh.log_cols);
    ph.mark(Half::Commit, "H: commit (pcs::commit_zk_owned: encode+Merkle, ONE call)", lay.h_rows as u64, "rows");
    lap(phases, tick, "LogUp helpers + commit H");

    // ---- the twenty-three slots ----
    let ctx = Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act };
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
    ph.mark(Half::Open, "open M (zk::mask_open, ONE call)", M_ROWS as u64, "rows");
    let order = acc.order;
    let [ac, hc, ic, oc] = finish_claims(acc.claims, lay);
    check_opening(&ac, sh.log_cols, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, sh.a_groups(), tr)?;
    let a_open = pcs::open_zk(&a, &ac, tr);
    drop(a);
    ph.mark(Half::Open, "open A (schedule audit + pcs::open_zk)", ac.len() as u64, "claims");
    check_opening(&hc, sh.log_cols, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, sh.h_groups(), tr)?;
    let h_open = pcs::open_zk(&h, &hc, tr);
    drop(h);
    ph.mark(Half::Open, "open H (schedule audit + pcs::open_zk)", hc.len() as u64, "claims");
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
        lookups: [m_u8.iter().sum::<u64>() as usize, m_exp.iter().sum::<u64>() as usize, m_act.iter().sum::<u64>() as usize],
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
    // RULINGS CS-1 and CS-4, in the body every verifying path shares (the
    // block's and the run's entries have made the same check already)
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
    let ctx = Ctx { lay, public, ff, alpha, beta, g_u8, g_exp, g_act };
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
    ph.mark(Half::Open, "verify M (zk::mask_verify, ONE call)", M_ROWS as u64, "rows");
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
    #[cfg(test)]
    super::capture::begin();
    let mut ph = timing::Phases::start();
    // RULING CS-8: the shape the caller trusts is one `Shape::new` builds,
    // before anything is derived from it
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
