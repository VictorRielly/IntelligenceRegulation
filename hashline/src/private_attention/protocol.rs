//! The component transcript: header -> A root -> M root -> (beta, gamma,
//! alpha) -> H root -> the eighteen slots -> ONE M opening -> ONE opening per
//! hiding commitment (A, H, input endpoint, output endpoint), in that order.
//!
//! Every private owner (the OS randomness stream, A, H, M, both endpoint
//! planes) is created or consumed inside ONE `prove_inner` call and dropped
//! before it returns, on success and on failure. There is no seed, no
//! prepared-commitment handle and no second opening of anything.

use super::argument::{argument, table_values_exp, table_values_u8, Ctx, ProverData, Side};
use super::layout::*;
use super::witness::Witness;
use super::{AttentionPublic, Endpoints, ExpectedIo, ProveStats, Receipt, PROFILE};
use crate::field::{batch_inverse2_checked, Fp, Fp2};
use crate::ntt::NttTables;
use crate::pcs::{self, Commitment, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use crate::tables_attn::{TAG_EXP, TAG_U8};
use crate::transcript::Transcript;
use crate::zk::{self, ZkRng};

pub(crate) fn pcs_params() -> PcsParams {
    PcsParams { log_cols: LOG_N as u32, inv_rate: 8, num_col_checks: 256 }
}

/// Header, public statement and endpoint policy first; no challenge precedes them.
pub(crate) fn transcript(public: &AttentionPublic, expected: &ExpectedIo, lay: &Layout) -> Transcript {
    let mut tr = Transcript::new(PROFILE);
    tr.absorb(b"expected-IO", &expected.to_bytes());
    tr.absorb(b"public-statement", &public.digest());
    tr.absorb(b"parameters", b"T32/d16/H2/KV1/dh8/log_cols8/inv_rate8/Q256/P1/two-private-endpoints");
    tr.absorb(b"schedule", &lay.schedule_digest());
    tr
}

fn absorb_root(tr: &mut Transcript, label: &[u8], root: &[u8; 32], rows: usize) {
    tr.absorb(label, root);
    tr.absorb_u64(b"rows", rows as u64);
    tr.absorb_u64(b"log-cols", LOG_N as u64);
}

fn commitment(root: [u8; 32], rows: usize) -> Commitment {
    Commitment { root, rows, log_cols: LOG_N as u32 }
}

/// The value-0 LogUp identity: every witness helper minus the two table helpers plus the
/// zero-sum pair `u`, as ONE all-ones sum claim. No helper sum is ever published.
fn logup_sum_claim(lay: &Layout) -> ZClaim {
    let mut parts = Vec::with_capacity(2 * N_H);
    for p in 0..N_H {
        let sign = if p == H_GU8 || p == H_GEXP { Fp2::ONE.neg() } else { Fp2::ONE };
        let (re, im) = lay.h_off[p];
        let log_size = h_dom(p).log() as u32;
        parts.push(ZPart { slice: Slice { offset: re, log_size }, coef: sign, point: vec![] });
        parts.push(ZPart { slice: Slice { offset: im, log_size }, coef: sign.mul(Fp2::U), point: vec![] });
    }
    ZClaim { parts, value: Fp2::ZERO }
}

// ---------------------------------------------------------------- opening refusals

/// the PCS column-weight key of a part (zkp_core::pcs::zpart_weights' rule)
fn part_key(p: &ZPart) -> (Vec<Fp2>, usize, usize) {
    let ls = p.slice.log_size as usize;
    let (c0, len) = if ls >= LOG_N { (0, N) } else { (p.slice.offset % N, 1usize << ls) };
    let tail = if p.point.is_empty() { vec![] } else { p.point[ls.saturating_sub(LOG_N)..].to_vec() };
    (tail, c0, len)
}

fn part_rows(p: &ZPart) -> std::ops::Range<usize> {
    let r0 = p.slice.offset / N;
    r0..r0 + (1usize << p.slice.log_size).div_ceil(N)
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
pub(crate) fn audit_claims(claims: &[ZClaim], rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize) -> Result<(), String> {
    let fail = |what: &str| Err(format!("private attention: mask schedule audit: {what}"));
    if prox + 2 != rows || site_rows.len() % 2 != 0 {
        return fail("proximity pair placement");
    }
    let mut uses = vec![0usize; rows];
    let is_site = |r: usize| site_rows.binary_search(&r).is_ok();
    for (ci, claim) in claims.iter().enumerate() {
        let mut touched: Vec<usize> = Vec::new();
        for part in &claim.parts {
            let pr = part_rows(part);
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
                let covered = |row: usize| claim.parts.iter().any(|p| part_rows(p).contains(&row) && !p.coef.is_zero());
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
pub(crate) fn check_opening(claims: &[ZClaim], rows: usize, site_rows: &[usize], sum_rows: Option<[usize; 2]>, prox: usize, want_groups: usize, tr: &Transcript) -> Result<(), String> {
    audit_claims(claims, rows, site_rows, sum_rows, prox)?;
    // first-occurrence grouping, as the PCS forms it
    let mut groups: Vec<((Vec<Fp2>, usize, usize), usize)> = Vec::new();
    for claim in claims {
        let key = part_key(&claim.parts[0]);
        if claim.parts.iter().any(|p| part_key(p) != key) {
            return Err("private attention: claim parts with different column weights".into());
        }
        match groups.iter_mut().find(|(k, _)| *k == key) {
            Some((_, count)) => *count += 1,
            None => groups.push((key, 1)),
        }
    }
    if groups.len() != want_groups {
        return Err(format!("private attention: {} opening groups, the schedule declares {want_groups}", groups.len()));
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

// The endpoint planes are `private_seam` commitments: 2 data rows, the terminal pair
// (2, 3) and three proximity rows from row 4. The seven-row geometry does not end in
// its proximity pair, so the one claim's shape is checked directly; the challenge
// refusals require rows (4, 5) independent, exactly as the repaired FFN IO profile.
fn check_endpoint_opening(claims: &[ZClaim], tr: &Transcript) -> Result<(), String> {
    let ok = claims.len() == 1
        && claims[0].parts.len() == 3
        && part_rows(&claims[0].parts[0]) == (0..2)
        && part_rows(&claims[0].parts[1]) == (2..3)
        && part_rows(&claims[0].parts[2]) == (3..4)
        && claims[0].parts.iter().all(|p| !p.coef.is_zero());
    if !ok {
        return Err("private attention: endpoint claim differs from the declared schedule".into());
    }
    let mut replay = Transcript::clone_state(tr);
    check_opening_challenges(&[1], ENDPOINT_ROWS, ENDPOINT_PROX, || replay.challenge_fp2())
}

// ---------------------------------------------------------------- prover

/// integer lookup values per lookup of a domain
fn lookup_values(wit: &Witness, dom: Dom) -> Vec<Vec<i64>> {
    lookups(dom)
        .iter()
        .map(|l| (0..dom.len()).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(wit.planes[*p][x])))).collect())
        .collect()
}

/// max - masked score per (h, t, j)
fn exp_deltas(wit: &Witness) -> Vec<i64> {
    (0..H * T * T)
        .map(|x| {
            let (ht, j) = (x / T, x % T);
            let masked = if j <= ht % T { wit.planes[A_S8][x] } else { MASK_SCORE };
            wit.planes[A_MX][ht].wrapping_sub(masked)
        })
        .collect()
}

fn inverses(mut den: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    batch_inverse2_checked(&mut den).map_err(|_| "zero LogUp denominator; discard attempt".to_string())?;
    Ok(den)
}

fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}

fn check_endpoints(expected: &ExpectedIo, endpoints: Endpoints) -> Result<[pcs::CommittedZk; 2], String> {
    let [si, so] = expected.spec.seams()?;
    let input = endpoints.input.into_ffn_endpoint(&si)?;
    let output = endpoints.output.into_ffn_endpoint(&so)?;
    if input.commitment().root != expected.input || output.commitment().root != expected.output {
        return Err("private attention: expected endpoint root mismatch".into());
    }
    if input.cm.rows != ENDPOINT_ROWS || output.cm.rows != ENDPOINT_ROWS {
        return Err("private attention: endpoint geometry".into());
    }
    Ok([input, output])
}

/// Consumes the endpoint owners on success AND on failure. No equality precheck: an
/// endpoint committed to other values must fail the verifier's polynomial identity.
pub(crate) fn prove_inner(public: &AttentionPublic, wit: &Witness, expected: &ExpectedIo, endpoints: Endpoints) -> Result<(Receipt, ProveStats), String> {
    use std::time::Instant;
    let mut tick = Instant::now();
    let mut phases: Vec<(&'static str, f64)> = Vec::new();
    let mut lap = |name: &'static str, tick: &mut Instant| {
        phases.push((name, tick.elapsed().as_secs_f64()));
        *tick = Instant::now();
    };
    let lay = Layout::new();
    let [ein, eout] = check_endpoints(expected, endpoints)?;
    if wit.planes.len() != N_WITNESS || (0..N_WITNESS).any(|p| wit.planes[p].len() != a_dom(p).len()) {
        return Err("private attention: witness shape".into());
    }
    // ONE OS stream per attempt; entropy failure aborts before anything public exists.
    let mut rng = ZkRng::from_os(PROFILE).map_err(|e| format!("private attention randomness: {e}"))?;
    let ntt = NttTables::new(12);
    let params = pcs_params();
    let zko = ZkOpts::standard(&params);
    let mut tr = transcript(public, expected, &lay);

    // ---- A: planes, the two committed histograms, every mask row drawn BEFORE the commitment ----
    let mut a_data = vec![Fp::ZERO; lay.a_rows * N];
    for p in 0..N_WITNESS {
        for (i, v) in wit.planes[p].iter().enumerate() {
            a_data[lay.a_off[p] + i] = Fp::from_i64(*v);
        }
    }
    let mut m_u8 = vec![0u64; N];
    let looked: Vec<(Dom, Vec<Vec<i64>>)> = LOOKUP_DOMS.iter().map(|d| (*d, lookup_values(wit, *d))).collect();
    for (_, cols) in &looked {
        for v in cols.iter().flatten() {
            // a value outside the table counts into entry 0: only the LogUp identity can catch it
            m_u8[if (0..N as i64).contains(v) { *v as usize } else { 0 }] += 1;
        }
    }
    let deltas = exp_deltas(wit);
    let mut m_exp = vec![0u64; N];
    for (x, d) in deltas.iter().enumerate() {
        let hit = (0..N as i64).contains(d) && public.exp[*d as usize] == wit.planes[A_E][x];
        m_exp[if hit { *d as usize } else { 0 }] += 1;
    }
    for i in 0..N {
        a_data[lay.a_off[A_MU8] + i] = Fp::new(m_u8[i]);
        a_data[lay.a_off[A_MEXP] + i] = Fp::new(m_exp[i]);
    }
    for x in &mut a_data[lay.a_mask_base * N..] {
        *x = rng.fp();
    }
    let mut a = pcs::commit_zk_owned(&params, a_data, &ntt, &zko, &mut rng);
    a.mask_rows = lay.a_site_rows();
    a.prox_mask_row = Some(lay.a_prox);
    let a_root = a.commitment().root;
    absorb_root(&mut tr, b"A", &a_root, lay.a_rows);
    lap("witness planes + commit A", &mut tick);

    // ---- M: all eighteen CFS masks, committed before any challenge ----
    let mc = zk::mask_commit(&mask_specs(), &ntt, &mut rng);
    let mask_root = mc.tree.root();
    tr.absorb(b"M", &mask_root);
    lap("commit M", &mut tick);

    // ---- LogUp challenges, helpers, table helpers, the zero-sum pair, commit H ----
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    let mut h_data = vec![Fp::ZERO; lay.h_rows * N];
    for (dom, cols) in &looked {
        let (first, count) = helpers(*dom);
        let inv: Vec<Vec<Fp2>> = cols.iter().map(|c| inverses(c.iter().map(|v| alpha.sub(Fp2::from_i64(*v).add(g_u8))).collect())).collect::<Result<_, _>>()?;
        for k in 0..count {
            let col: Vec<Fp2> = match inv.get(2 * k + 1) {
                Some(second) => inv[2 * k].iter().zip(second.iter()).map(|(x, y)| x.add(*y)).collect(),
                None => inv[2 * k].clone(),
            };
            write_h(&mut h_data, lay.h_off[first + k], &col);
        }
    }
    let exp_den = deltas.iter().zip(wit.planes[A_E].iter()).map(|(d, e)| alpha.sub(Fp2::from_i64(*d).add(beta.mul(Fp2::from_i64(*e))).add(g_exp))).collect();
    write_h(&mut h_data, lay.h_off[H_SEXP], &inverses(exp_den)?);
    for (plane, tv, m) in [(H_GU8, table_values_u8(g_u8), &m_u8), (H_GEXP, table_values_exp(public, beta, g_exp), &m_exp)] {
        let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;
        let col: Vec<Fp2> = inv.iter().zip(m.iter()).map(|(x, c)| x.mul_base(Fp::new(*c))).collect();
        write_h(&mut h_data, lay.h_off[plane], &col);
    }
    for x in &mut h_data[lay.h_mask_base * N..] {
        *x = rng.fp();
    }
    for r in lay.h_u_rows() {
        let mut sum = Fp::ZERO;
        for j in 0..N - 1 {
            let v = rng.fp();
            h_data[r * N + j] = v;
            sum = sum.add(v);
        }
        h_data[r * N + N - 1] = sum.neg();
    }
    let mut h = pcs::commit_zk_owned(&params, h_data, &ntt, &zko, &mut rng);
    h.mask_rows = lay.h_site_rows().into_iter().chain(lay.h_u_rows()).collect();
    h.prox_mask_row = Some(lay.h_prox);
    let h_root = h.commitment().root;
    absorb_root(&mut tr, b"H", &h_root, lay.h_rows);
    lap("LogUp helpers + commit H", &mut tick);

    // ---- the eighteen slots ----
    let ctx = Ctx { lay: &lay, public, alpha, beta, g_u8, g_exp };
    let pd = ProverData { data: [a.data.as_slice(), h.data.as_slice(), ein.data.as_slice(), eout.data.as_slice()], masks: &mc.masks };
    let mut side = Side::Prove { pd, out: Vec::new() };
    let acc = argument(&mut side, &ctx, &mut tr)?;
    let slots = match side {
        Side::Prove { out, .. } => out,
        Side::Verify { .. } => unreachable!(),
    };
    lap("18 masked sumchecks", &mut tick);

    // ---- ONE M opening, then ONE opening per commitment; each owner dropped after its opening ----
    let mask_open = zk::mask_open(&mc, &acc.fs, &ntt, &mut tr);
    drop(mc);
    let order = acc.order;
    let [ac, hc, ic, oc] = finish_claims(acc.claims, &lay);
    check_opening(&ac, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, &tr)?;
    let a_open = pcs::open_zk(&a, &ac, &mut tr);
    drop(a);
    check_opening(&hc, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, &tr)?;
    let h_open = pcs::open_zk(&h, &hc, &mut tr);
    drop(h);
    check_endpoint_opening(&ic, &tr)?;
    let in_open = pcs::open_zk(&ein, &ic, &mut tr);
    drop(ein);
    check_endpoint_opening(&oc, &tr)?;
    let out_open = pcs::open_zk(&eout, &oc, &mut tr);
    drop(eout);
    lap("M + A + H + endpoint openings", &mut tick);

    let receipt = Receipt { a_root, h_root, mask_root, slots, mask_open, a_open, h_open, io_open: [in_open, out_open] };
    let stats = ProveStats {
        phases: phases.iter().map(|(n, s)| (n.to_string(), *s)).collect(),
        a_rows: lay.a_rows,
        h_rows: lay.h_rows,
        m_rows: M_ROWS,
        u8_lookups: m_u8.iter().sum::<u64>() as usize,
        exp_lookups: m_exp.iter().sum::<u64>() as usize,
        transcript_order: order,
    };
    Ok((receipt, stats))
}

// ---------------------------------------------------------------- verifier

/// Accepts only against the caller's own public statement and endpoint policy.
/// Returns the absorb sequence (for the transcript-order gate).
pub(crate) fn verify_inner(public: &AttentionPublic, expected: &ExpectedIo, receipt: &Receipt) -> Result<Vec<String>, String> {
    let lay = Layout::new();
    super::wire::validate(receipt, &lay)?;
    expected.spec.seams()?;
    let ntt = NttTables::new(12);
    let params = pcs_params();
    let zko = ZkOpts::standard(&params);
    let mut tr = transcript(public, expected, &lay);
    absorb_root(&mut tr, b"A", &receipt.a_root, lay.a_rows);
    tr.absorb(b"M", &receipt.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(TAG_EXP));
    absorb_root(&mut tr, b"H", &receipt.h_root, lay.h_rows);
    let ctx = Ctx { lay: &lay, public, alpha, beta, g_u8, g_exp };
    let mut side = Side::Verify { slots: &receipt.slots };
    let acc = argument(&mut side, &ctx, &mut tr)?;
    zk::mask_verify(&receipt.mask_root, &mask_specs(), &acc.fs, &receipt.mask_open, &ntt, &mut tr).map_err(|e| format!("M: {e}"))?;
    let order = acc.order;
    let [ac, hc, ic, oc] = finish_claims(acc.claims, &lay);
    check_opening(&ac, lay.a_rows, &lay.a_site_rows(), None, lay.a_prox, A_GROUPS, &tr)?;
    pcs::verify_zk(&params, &zko, &commitment(receipt.a_root, lay.a_rows), &ac, &receipt.a_open, &ntt, &mut tr).map_err(|e| format!("A: {e}"))?;
    check_opening(&hc, lay.h_rows, &lay.h_site_rows(), Some(lay.h_u_rows()), lay.h_prox, H_GROUPS, &tr)?;
    pcs::verify_zk(&params, &zko, &commitment(receipt.h_root, lay.h_rows), &hc, &receipt.h_open, &ntt, &mut tr).map_err(|e| format!("H: {e}"))?;
    for (i, (claims, root)) in [(&ic, expected.input), (&oc, expected.output)].into_iter().enumerate() {
        check_endpoint_opening(claims, &tr)?;
        pcs::verify_zk(&params, &zko, &commitment(root, ENDPOINT_ROWS), claims, &receipt.io_open[i], &ntt, &mut tr).map_err(|e| format!("endpoint {i}: {e}"))?;
    }
    Ok(order)
}
