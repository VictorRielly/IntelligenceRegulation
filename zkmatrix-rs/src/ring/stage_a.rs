// [UPERF3-GG] U-PERF3 round 5, lane GG — STAGE A INTEGRATION (skeleton).
//
// The descent replacement in the REAL pass: the ten per-table masked
// descent pairs of the BK full-statement path (bin: bk_pass_run) replaced
// by the validated Stage-A components behind an explicit selector —
// range/narrowing pairs by the aggregate zero-check of
// zc_range::[UPERF3-EE] (zc_agg_prove/verify + the O-4 mask), the SiLU
// pairs by the LogUp-as-one-sumcheck of zc_range::[UPERF3-S]
// (logup_sumcheck_prove/verify with the committed helper h). Spec:
// docs/zkmatrix-poc/U_PERF3_OPENING_LAYER_DESIGN.md §2.2-2.6; the frozen
// pass is the ORACLE and the default path stays byte-identical (nothing
// here is called by any shipped path).
//
// This module holds the shape-independent Stage-A logic (instance
// building from the pass's committed columns, plane extraction, the
// claim-serving forms); the pass driver itself lives in the bin's
// [UPERF3-GG] section (it needs the bin's statement/layer statics).
//
// Ownership (round-5 lane GG): this NEW file; ONE `pub mod` line in
// ring/mod.rs; the bin's [UPERF3-GG] section + the `uperf-a` dispatch
// line. zc_range / ec_kernel / eval_proof / the pass code are READ-ONLY
// reuse — any needed-but-private zc_range surface is wrapped here, never
// edited there.

// ---------------------------------------------------------------------------
// Rung 1: the object-map plan shapes (no proving).

/// ceil(log2 n) — the padded hypercube width of an n-element column.
pub fn clog2(n: usize) -> usize {
    assert!(n >= 1);
    (usize::BITS - (n - 1).leading_zeros()) as usize
}

/// The Stage-A replacement plan of one range/narrowing aggregate over m
/// same-shape columns of 2^n_log2 elements at width w (memo §2.2/§2.3,
/// the zc_agg shapes of [UPERF3-EE]): returns (instance-axis width a,
/// sumcheck rounds n_log2 + a, served claims m x (w + 1)).
pub fn zc_agg_plan(m: usize, n_log2: usize, w: usize) -> (usize, usize, usize) {
    let a = super::zc_range::zc_agg_axis(m);
    (a, n_log2 + a, m * (w + 1))
}

/// The claims ONE masked descent pair serves to the opening, counted from
/// the bk_pair_claims structure (bin, [UAGB1-BK]): per side (witness depth
/// `depth`, table depth `dt`) the mask-opening claims 2(D-1) + 2(D-2)
/// (g-hypersum + g-open per layer, Rp/Rq per interior layer), plus the
/// four endpoint claims wp/wq/tp/tq. Returns (wm_opens, tm_opens, total).
pub fn descent_pair_claims(depth: usize, dt: usize) -> (usize, usize, usize) {
    let side = |d: usize| 2 * (d - 1) + 2 * d.saturating_sub(2);
    let (w, t) = (side(depth), side(dt));
    (w, t, w + t + 4)
}

// ---------------------------------------------------------------------------
// Rung 2: the range-fact instance built from a REAL member column.

/// The w bit planes + canonical residues of a member column's coded values
/// (code = value + offset), zero-padded to 2^n_log2. HONEST instances only:
/// every code is asserted in [0, 2^w) — the bits are then a valid
/// sign-binary digit vector (memo §2.3 / the S1 spike form) and the coded
/// value recomposes as sum_k 2^k b_k, so (planes, rem) is a green
/// ZcRangeInstance at e0 = 1. Pads are zeros (0 is in the alphabet and
/// recomposes to 0).
pub fn range_planes(vals: &[i64], offset: i64, w: usize, n_log2: usize) -> (Vec<Vec<u32>>, Vec<u32>) {
    let size = 1usize << n_log2;
    assert!(vals.len() <= size, "column longer than the padded hypercube");
    let mut planes = vec![vec![0u32; size]; w];
    let mut rem = vec![0u32; size];
    for (i, &v) in vals.iter().enumerate() {
        let code = v + offset;
        assert!(code >= 0 && (code as u128) < (1u128 << w), "off-range code in an honest instance");
        for (k, plane) in planes.iter_mut().enumerate() {
            plane[i] = ((code >> k) & 1) as u32;
        }
        rem[i] = code as u32;
    }
    (planes, rem)
}

// ---------------------------------------------------------------------------
// Rung 4: the O-4 masked aggregate at PASS level.

/// VERIFY the MASKED aggregate with the two mask openings SERVED (the pass
/// form). zc_range::zc_agg_verify_masked pins the served hypersum and
/// final evaluation against a verifier-held mask copy — the EE harness
/// stand-in for the commitment opening. At pass level the verifier does
/// NOT hold the (private) mask: the two served values are instead ground
/// by OPENING CLAIMS over the committed mask-coefficient tensor (the
/// bk_pair_claims mask_claims idiom), so this verifier runs the identical
/// round chain and final identity but takes proof.mask_hyper /
/// proof.mask_final at face value — the caller MUST push the two claims.
/// Reimplemented here (zc_range is read-only for lane GG; noted in the
/// ledger). Returns the point.
#[allow(clippy::too_many_arguments)]
pub fn zc_agg_verify_masked_served(
    kf: &super::kfield::KField,
    ext: &super::zc_range::SubExt,
    n_log2: usize,
    e0: u32,
    w: usize,
    m: usize,
    rho: &[super::zc_range::EElem],
    betas: &[super::zc_range::EElem],
    proof: &super::zc_range::ZcAggProof,
    tr: &mut super::sumcheck::LkpTranscript,
) -> Option<Vec<super::zc_range::EElem>> {
    use super::zc_range::{zc_agg_axis, zc_agg_eq_bool, zc_range_g_of};
    let a = zc_agg_axis(m);
    let n_tot = n_log2 + a;
    let (Some(g_hyper), Some(mask_final)) = (&proof.mask_hyper, &proof.mask_final) else {
        return None;
    };
    if proof.rounds.len() != n_tot
        || proof.c != ext.c
        || proof.m != m
        || proof.a != a
        || proof.col_claims.len() != m
        || proof.col_claims.iter().any(|cl| cl.len() != w + 1)
        || rho.len() != n_tot
        || betas.len() != w + 1
    {
        return None;
    }
    let deg_f = super::digits::alphabet_rows(e0);
    let deg = deg_f + 1;
    ext.absorb(kf, tr, "agg-mask-hsum", std::slice::from_ref(g_hyper));
    let nu = ext.challenge(kf, tr);
    let mut c_run = ext.mul(&nu, g_hyper);
    let mut point = Vec::with_capacity(n_tot);
    for g in &proof.rounds {
        if g.len() != deg + 1 {
            return None;
        }
        if ext.add(&g[0], &g[1]) != c_run {
            return None;
        }
        ext.absorb(kf, tr, "ixf-round-poly", g);
        let r = ext.challenge(kf, tr);
        c_run = ext.lagrange_eval(kf, g, &r);
        point.push(r);
    }
    let r_inst = &point[n_log2..];
    let mut finals = vec![ext.zero(); w + 1];
    for (i, cl) in proof.col_claims.iter().enumerate() {
        let wi = zc_agg_eq_bool(ext, r_inst, i);
        for (k, f) in finals.iter_mut().enumerate() {
            *f = ext.add(f, &ext.mul(&wi, &cl[k]));
        }
    }
    let (lo, hi) = super::digits::alphabet(e0);
    let alphabet: Vec<u32> =
        (lo..=hi).map(|a| (if a < 0 { (a + ext.q as i64) as u64 } else { a as u64 }) as u32).collect();
    let gval = zc_range_g_of(ext, e0, &alphabet, betas, &finals);
    let expect = ext.add(&ext.mul(&ext.eq_point(rho, &point), &gval), &ext.mul(&nu, mask_final));
    if expect != c_run {
        return None;
    }
    Some(point)
}
