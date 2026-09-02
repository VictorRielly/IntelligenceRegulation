// [UPERF3-SS] U-PERF3 round 10, lane SS — THE COMMITTED-h ENCODING
// (spec: docs/zkmatrix-poc/U_PERF3_COMMITTED_H.md §3, rungs V1-V4).
//
// FULL-mode routing of the Stage-A pass (bin: uperf_a_gg_pass, the
// [UPERF3-GG] selector driver; `uperf-a pass [layers] [t] full`). Range
// mode is lane RR's and stays byte-identical; everything here is reached
// from the driver's Full-mode branches only, through the ONE dispatch line
// in ring/stage_a.rs (`pub use super::stage_a_full as full;`).
//
// WHAT THE act-h GROUP IS (read from the code, not from the memo): the
// third commitment group of lane GG's full mode holds the LogUp HELPER
// h_i = 1/(alpha - key_i) of the two SiLU pair families — a K-field
// element per looked-up element (16 coordinates x l0_q = 16 base-4
// digits = 256 digit values = 2 digit rings PER ELEMENT), committed at
// the blinder class after alpha is drawn (the F2 ordering). It is NOT a
// range-fact commitment of the activation h; nothing in the v3 entry
// list (Hlo/Hhi/H/Rh) stands in for it. The memo's candidate C2 ("route
// h's range facts as 256-row lookups over the existing limbs") therefore
// does not make the act-h group vanish — a lookup instance NEEDS a helper
// column of its own, and the S2 helper costs 2 rings/element against
// w/128 rings/element for the width planes it would replace (32x MORE
// for an 8-bit fact). Rung V1 measures exactly that on the real pass;
// rung V2 counts it at 12x512 and 8B; rung V3 then makes full mode fit
// the 15 GiB box by shrinking the helper of the lookups that are
// unavoidable (the SiLU tables) — the kappa-level PARTIAL-FRACTION
// helper: commit h at node granularity (one K element per 2^kappa
// consecutive keys, h_node = sum_{i in node} 1/(alpha - key_i)) and
// prove h_node * prod_i (alpha - key_i) = sum_i prod_{i' != i} (alpha -
// key_i') by ONE degree-(2^kappa + 2) zero-check whose final claims are
// the 2^kappa key MLEs at (b || x*) over the EXISTING member commitments
// plus h(x*) / h_sum over the (2^kappa-times smaller) act-h block. The
// LogUp sum identity sum_nodes h_node = sum_j m_j / (alpha - t_j) is
// unchanged. kappa = 0 is exactly the S2 form.
//
// Ownership (round-10 lane SS): this NEW file + its `pub mod` line; ONE
// dispatch line in ring/stage_a.rs; the driver's Full-mode branches and
// ADDITIVE `uperf-a` subcommands in the bin. zc_range / fold / eval_proof
// / kfield / sumcheck / gkr / the v3 statement are READ-ONLY reuse —
// anything needed-but-private is reimplemented here, never edited there.

use super::gkr::eq_table;
use super::kfield::{KElem, KField, K_DEG};
use super::sumcheck::{lagrange_eval, mle_eval, LkpTranscript, SumcheckProof};
use super::D;

// ---------------------------------------------------------------------------
// Rung 0/V2: the ring arithmetic of the committed objects (no proving).

/// Digit rings of a committed K-valued helper column over `n_el` elements
/// at `coords` K coordinates (16 = the full K element; 4 = an E_4
/// element) and `l0` digits per coordinate (the blinder class l0_q = 16 at
/// e0 = 2). One value ring holds D = 128 coordinates.
pub fn helper_rings(n_el: usize, coords: usize, l0: usize) -> usize {
    (n_el * coords).div_ceil(D) * l0
}

/// Digit rings of `w` committed width planes (e0 = 1, l0 = 1) over `n_el`
/// elements padded to `n_pad` per plane — the range-mode planes tensor.
pub fn planes_rings(n_pad: usize, w: usize) -> usize {
    (w * n_pad).div_ceil(D)
}

/// Digit rings of the kappa-level partial-fraction helper: one K element
/// per 2^kappa elements.
pub fn pf_helper_rings(n_el: usize, kappa: usize, l0: usize) -> usize {
    helper_rings(n_el >> kappa, K_DEG, l0)
}

/// The round-polynomial degree of the kappa-level relation eq * (h * Q -
/// P): 1 (eq) + 1 (h) + 2^kappa (Q, the product of the node's keys).
pub fn pf_degree(kappa: usize) -> usize {
    2 + (1usize << kappa)
}

/// The rung plan, printed by `uperf-a full-plan` (rung 0).
pub fn plan_lines() -> Vec<&'static str> {
    vec![
        "V1  one 8-bit range fact (nrw-88, the h8 narrowing of layer 0) as a 256-row identity LogUp over the EXISTING h8 commitment in the full-mode path; differential vs the planes (zc) form and the descent (table) form; rings counted",
        "V2  the helper/multiplicity commit bill counted at 12x512 and 32x512 8B: S2 K-helper, E_4 helper, kappa-level partial-fraction helper, width planes, descent",
        "V3  full mode's SiLU helper routed through the kappa-level partial-fraction form; `uperf-a pass 12 128 full` peak RSS vs range mode",
        "V4  the 8B full-mode counted row on lane OO's baseline (commit ~61 GB, pass peak lvl-0 ~72 GB)",
    ]
}

/// Sanity: the helper arithmetic reproduces lane GG's measured act-h
/// n_0 rows (3x16: 196,608; 12x128: 6,291,456 at the m125 shape f = 2048).
pub fn gg_act_h_rings(layers: usize, t: usize, f_pad: usize, l0_q: usize) -> usize {
    helper_rings(layers * t * f_pad, K_DEG, l0_q)
}

// ---------------------------------------------------------------------------
// V2: the counted commit bill of the full-mode helper forms at a shape.

/// One counted row of the V2 table.
pub struct CountRow {
    pub label: &'static str,
    pub rings: usize,
    /// Commitment groups the act-h side needs under the level-0
    /// exact-digit gate (e0 = 2: 94.2M digit rings per group, the
    /// MVP8B memo §1.2 row).
    pub groups: usize,
    /// [MODEL] flat i8 store, n x 128 B (GB).
    pub store_gb: f64,
    /// [MODEL] the pass peak at 32x512 on lane OO's baseline: max(the
    /// weight group's lvl-0 phase 72 GB + this store, the act-h group's
    /// own lvl-0 phase = 63.7 GB flat stores + store + A_0 at 209 B/ring
    /// + lvl-1 at 76 B/ring — the act-group rates of MVP8B §1.2).
    pub peak_8b_gb: f64,
}

/// The act-side exact-digit cap at e0 = 2 (digit rings per group):
/// gamma_z = OP_CONC * 2 * sqrt(n * D) <= gamma_max_exact(q).
pub fn act_group_cap(q: u64) -> usize {
    let g = super::digits::gamma_max_exact(q) / (super::digits::OP_CONC * 2.0);
    ((g * g) / D as f64) as usize
}

/// The helper forms over `n_el` looked-up elements (the SiLU pairs at
/// a shape: layers x t x f_pad), each as a counted row. The planes row
/// is the width-plane cost of the SAME elements at w = 8 (what a range
/// fact of that size costs in range mode), for scale.
pub fn count_rows(n_el: usize, l0_q: usize, q: u64, baseline_8b: bool) -> Vec<CountRow> {
    let cap = act_group_cap(q);
    let row = |label: &'static str, rings: usize| {
        let store = rings as f64 * 128.0 / 1e9;
        let peak = if baseline_8b {
            let own = 63.7 + store + rings as f64 * 209.0 / 1e9 + rings as f64 * 76.0 / 1e9;
            (72.0 + store).max(own)
        } else {
            0.0
        };
        CountRow { label, rings, groups: rings.div_ceil(cap).max(1), store_gb: store, peak_8b_gb: peak }
    };
    vec![
        row("S2 K-helper (kappa 0, as built)", helper_rings(n_el, K_DEG, l0_q)),
        row("E_4 helper (4 coords)", helper_rings(n_el, 4, l0_q)),
        row("pf helper kappa 3 (degree 10)", pf_helper_rings(n_el, 3, l0_q)),
        row("pf helper kappa 4 (degree 18)", pf_helper_rings(n_el, 4, l0_q)),
        row("pf helper kappa 5 (degree 34)", pf_helper_rings(n_el, 5, l0_q)),
        row("pf helper kappa 6 (degree 66)", pf_helper_rings(n_el, 6, l0_q)),
        row("width planes, w = 8, same elements", planes_rings(n_el, 8)),
        row("descent (GKR tree): committed rings", 0),
    ]
}

// ---------------------------------------------------------------------------
// V1/V3: the lookup column and its helper at kappa levels.

/// One lookup column of the full-mode path: 2^n_log2 keys (K elements),
/// the table row each key sits on (None = off-table, the tamper legs),
/// and the per-row multiplicities.
pub struct LookupCol {
    pub n_log2: usize,
    pub keys: Vec<KElem>,
    pub row_of: Vec<Option<usize>>,
    pub mult: Vec<u64>,
}

/// The identity-table range fact of a member column (code = value +
/// offset against the table [0, t_rows)) as a lookup column over the
/// STRIDED grid x = r * cols_pad + c (the descent tree's / the zc planes'
/// own alignment, so the key claim lands on the member tensor with the
/// same eq_hi x eq_lo kernels the planes form uses). Pads carry key 0 =
/// table row 0 and are counted in mult[0], so the LogUp identity holds
/// over the padded hypercube exactly.
pub fn identity_lookup_col(
    kf: &KField,
    vals: &[i64],
    offset: i64,
    rows: usize,
    cols: usize,
    cols_pad: usize,
    t_rows: usize,
) -> LookupCol {
    assert_eq!(vals.len(), rows * cols);
    let size = rows * cols_pad;
    assert!(size.is_power_of_two(), "strided member grid must be a hypercube");
    let n_log2 = size.trailing_zeros() as usize;
    let zq = &kf.zq;
    let mut keys = vec![kf.zero(); size];
    let mut row_of = vec![Some(0usize); size];
    let mut mult = vec![0u64; t_rows];
    mult[0] = (size - rows * cols) as u64;
    for r in 0..rows {
        for c in 0..cols {
            let code = vals[r * cols + c] + offset;
            let x = r * cols_pad + c;
            keys[x] = kf.embed(zq.to_mod(code));
            if code >= 0 && (code as u64) < t_rows as u64 {
                row_of[x] = Some(code as usize);
                mult[code as usize] += 1;
            } else {
                row_of[x] = None;
            }
        }
    }
    LookupCol { n_log2, keys, row_of, mult }
}

/// The fused-pair table lookup of a SiLU member ((prim, img) against the
/// frozen 256-row member table) as a lookup column over the STRIDED grid
/// x = r * cols_pad + c — shape-general: at f = 14336 the member pads to
/// 16384 columns (MVP8B §1.1) and the as-built silu phase's `prim.len()
/// == n_el` assert cannot hold. Pads carry the table's ROW-0 key and are
/// counted in mult[0] (the pad convention every claim builder subtracts
/// back out with the pad kernel sum). `row_idx` maps a fused (x, y)
/// residue pair to its table row.
#[allow(clippy::too_many_arguments)]
pub fn fused_lookup_col(
    kf: &KField,
    prim: &[i64],
    img: &[i64],
    rows: usize,
    cols: usize,
    cols_pad: usize,
    table: &[KElem],
    row_idx: &std::collections::HashMap<(u64, u64), usize>,
) -> LookupCol {
    assert_eq!(prim.len(), rows * cols);
    assert_eq!(img.len(), rows * cols);
    let size = rows * cols_pad;
    assert!(size.is_power_of_two(), "strided member grid must be a hypercube");
    let n_log2 = size.trailing_zeros() as usize;
    let zq = &kf.zq;
    let mut keys = vec![table[0].clone(); size];
    let mut row_of = vec![Some(0usize); size];
    let mut mult = vec![0u64; table.len()];
    mult[0] = (size - rows * cols) as u64;
    for r in 0..rows {
        for c in 0..cols {
            let i = r * cols + c;
            let (xm, ym) = (zq.to_mod(prim[i]), zq.to_mod(img[i]));
            let x = r * cols_pad + c;
            keys[x] = super::lookup::fuse_pair(kf, xm, ym);
            match row_idx.get(&(xm, ym)) {
                Some(&j) => {
                    row_of[x] = Some(j);
                    mult[j] += 1;
                }
                None => row_of[x] = None,
            }
        }
    }
    LookupCol { n_log2, keys, row_of, mult }
}

/// The 2^kappa-way partial-fraction helper: h_node[x] = sum_{b <
/// 2^kappa} 1/(alpha - key[(x << kappa) | b]) (the LOW kappa bits of the
/// leaf index are the leaf position). On-table keys take the table row's
/// inverse (256 inversions in total); an off-table key gets its own.
/// Returns (h_nodes, h_sum).
pub fn lookup_helper(kf: &KField, col: &LookupCol, table: &[KElem], alpha: &KElem, kappa: usize) -> (Vec<KElem>, KElem) {
    assert!(kappa <= col.n_log2);
    let inv_rows: Vec<KElem> = table.iter().map(|t| kf.inv(&kf.sub(alpha, t))).collect();
    let size = 1usize << col.n_log2;
    let n_nodes = size >> kappa;
    let leaves = 1usize << kappa;
    let mut h = Vec::with_capacity(n_nodes);
    let mut h_sum = kf.zero();
    for x in 0..n_nodes {
        let mut acc = kf.zero();
        for b in 0..leaves {
            let i = (x << kappa) | b;
            let hi = match col.row_of[i] {
                Some(j) => inv_rows[j].clone(),
                None => kf.inv(&kf.sub(alpha, &col.keys[i])),
            };
            acc = kf.add(&acc, &hi);
        }
        h_sum = kf.add(&h_sum, &acc);
        h.push(acc);
    }
    (h, h_sum)
}

/// The committed form of a helper column: rows x 16 centered coordinates
/// (the K-coord tensor layout of the act-h group, ypow column kernel).
pub fn helper_vals_i64(kf: &KField, h: &[KElem]) -> Vec<i64> {
    let zq = &kf.zq;
    let mut out = vec![0i64; h.len() * K_DEG];
    for (i, e) in h.iter().enumerate() {
        for c in 0..K_DEG {
            out[i * K_DEG + c] = zq.center(e[c]);
        }
    }
    out
}

/// The table side of the LogUp identity: sum_j m_j / (alpha - t_j).
pub fn table_sum(kf: &KField, table: &[KElem], mult: &[u64], alpha: &KElem) -> KElem {
    let mut s = kf.zero();
    for (j, t) in table.iter().enumerate() {
        let inv = kf.inv(&kf.sub(alpha, t));
        s = kf.add(&s, &kf.scale(mult[j] % kf.zq.q, &inv));
    }
    s
}

/// The shipped objects of one routed lookup column (the wire face).
pub struct LookupOut {
    pub kappa: usize,
    /// kappa = 0: the S2 sumcheck (tables [eq, h, alpha - key, 1], Had
    /// combine, degree 3); kappa > 0: the partial-fraction zero-check
    /// (tables [eq, h, key_0 .. key_{2^kappa - 1}], degree 2^kappa + 2).
    pub proof: SumcheckProof,
    pub point: Vec<KElem>,
    pub h_sum: KElem,
    pub table_sum: KElem,
    /// h(x*) over the helper column (n_log2 - kappa variables).
    pub h_at_point: KElem,
    /// key_b(x*) for b < 2^kappa — the key MLE at (b || x*) over the
    /// 2^n_log2 keys (one claim per leaf position on the member tensor).
    pub keys_at_point: Vec<KElem>,
    pub secs_helper: f64,
    pub secs_sumcheck: f64,
}

/// The kappa-level combine on the final table values [eq, h, key_0 ..]:
/// eq * (h * Q - P), Q = prod_b (alpha - key_b), P = sum_b prod_{b' != b}
/// (alpha - key_b') — the (P, Q) recurrence (P, Q) <- (P * a + Q, Q * a).
pub fn pf_combine(kf: &KField, alpha: &KElem, v: &[KElem]) -> KElem {
    let mut p = kf.zero();
    let mut q = kf.one();
    for key in &v[2..] {
        let a = kf.sub(alpha, key);
        p = kf.add(&kf.mul(&p, &a), &q);
        q = kf.mul(&q, &a);
    }
    kf.mul(&v[0], &kf.sub(&kf.mul(&v[1], &q), &p))
}

/// The round-chain degrees of a kappa-level proof over n node variables.
pub fn pf_degrees(kappa: usize, n: usize) -> Vec<usize> {
    vec![pf_degree(kappa); n]
}

/// PROVE one routed lookup column: kappa = 0 delegates to the S2 prover
/// verbatim (zc_range::logup_sumcheck_prove — the frozen packed Had
/// kernel); kappa > 0 runs the partial-fraction zero-check here (scalar
/// K arithmetic on the ZK_THREADS pool; the round chain uses the house
/// labels, so ixf_sumcheck_verify checks it unchanged). `h` is the
/// helper of `lookup_helper` at the same kappa (the committed column).
#[allow(clippy::too_many_arguments)]
pub fn lookup_prove(
    kf: &KField,
    col: &LookupCol,
    table: &[KElem],
    alpha: &KElem,
    rho: &[KElem],
    kappa: usize,
    h: &[KElem],
    tr: &mut LkpTranscript,
) -> LookupOut {
    let n = col.n_log2 - kappa;
    assert_eq!(rho.len(), n, "rho spans the node variables");
    assert_eq!(h.len(), 1usize << n);
    if kappa == 0 {
        let out = super::zc_range::logup_sumcheck_prove(kf, &col.keys, &col.row_of, table, &col.mult, alpha, rho, tr);
        return LookupOut {
            kappa: 0,
            proof: out.proof,
            point: out.point,
            h_sum: out.h_sum,
            table_sum: out.table_sum,
            h_at_point: out.h_at_point,
            keys_at_point: vec![out.key_at_point],
            secs_helper: out.secs_h,
            secs_sumcheck: out.secs_tables + out.secs_sumcheck + out.secs_open,
        };
    }
    let t0 = std::time::Instant::now();
    let leaves = 1usize << kappa;
    let size = 1usize << n;
    let h_sum = h.iter().fold(kf.zero(), |a, e| kf.add(&a, e));
    let tsum = table_sum(kf, table, &col.mult, alpha);
    // Tables over the node variables: eq(rho, x), h(x), key_b(x).
    let mut tabs: Vec<Vec<KElem>> = Vec::with_capacity(2 + leaves);
    tabs.push(eq_table(kf, rho));
    tabs.push(h.to_vec());
    for b in 0..leaves {
        tabs.push((0..size).map(|x| col.keys[(x << kappa) | b].clone()).collect());
    }
    let secs_helper = t0.elapsed().as_secs_f64();
    let t1 = std::time::Instant::now();
    let deg = pf_degree(kappa);
    let mut rounds = Vec::with_capacity(n);
    let mut point = Vec::with_capacity(n);
    for _ in 0..n {
        let g = pf_round_poly(kf, &tabs, alpha, deg);
        tr.absorb_k(kf, "ixf-round-poly", &g);
        let r = tr.challenge_k(kf);
        for t in tabs.iter_mut() {
            *t = super::sumcheck::fold(kf, t, &r);
        }
        rounds.push(g);
        point.push(r);
    }
    let final_evals: Vec<KElem> = tabs.iter().map(|t| t[0].clone()).collect();
    let h_at_point = final_evals[1].clone();
    let keys_at_point = final_evals[2..].to_vec();
    let secs_sumcheck = t1.elapsed().as_secs_f64();
    LookupOut {
        kappa,
        proof: SumcheckProof { rounds, final_evals },
        point,
        h_sum,
        table_sum: tsum,
        h_at_point,
        keys_at_point,
        secs_helper,
        secs_sumcheck,
    }
}

/// One round polynomial of the partial-fraction zero-check: g(X) =
/// sum_pairs eq_X * (h_X * Q_X - P_X) at X = 0..=deg, every table's line
/// T_X = T[2i] + X * (T[2i+1] - T[2i]) walked incrementally. Chunked on
/// the ZK_THREADS pool; K addition is exact, so the chunk order is
/// irrelevant to the result.
fn pf_round_poly(kf: &KField, tabs: &[Vec<KElem>], alpha: &KElem, deg: usize) -> Vec<KElem> {
    use rayon::prelude::*;
    let size = tabs[0].len();
    let pairs = size / 2;
    let nt = tabs.len();
    let eval_pair = |i: usize, acc: &mut Vec<KElem>| {
        let mut cur: Vec<KElem> = (0..nt).map(|t| tabs[t][2 * i].clone()).collect();
        let dlt: Vec<KElem> = (0..nt).map(|t| kf.sub(&tabs[t][2 * i + 1], &tabs[t][2 * i])).collect();
        for x in 0..=deg {
            if x > 0 {
                for t in 0..nt {
                    cur[t] = kf.add(&cur[t], &dlt[t]);
                }
            }
            let v = pf_combine(kf, alpha, &cur);
            acc[x] = kf.add(&acc[x], &v);
        }
    };
    let chunk = 256usize;
    let n_chunks = pairs.div_ceil(chunk);
    let partial: Vec<Vec<KElem>> = super::fold::ixf_pooled(|| {
        (0..n_chunks)
            .into_par_iter()
            .map(|ci| {
                let mut acc = vec![kf.zero(); deg + 1];
                for i in ci * chunk..((ci + 1) * chunk).min(pairs) {
                    eval_pair(i, &mut acc);
                }
                acc
            })
            .collect()
    });
    let mut g = vec![kf.zero(); deg + 1];
    for acc in &partial {
        for x in 0..=deg {
            g[x] = kf.add(&g[x], &acc[x]);
        }
    }
    g
}

/// VERIFY one routed lookup column: the round chain against the claimed
/// sum 0 (the house ixf_sumcheck_verify at the shape's combine), the eq
/// final recomputed, h(x*) / key_b(x*) taken as the opened claims (ground
/// by the act-h / act openings), and the sum equality h_sum == table_sum.
/// Returns (chain_ok, sum_ok).
pub fn lookup_verify(
    kf: &KField,
    n_log2: usize,
    alpha: &KElem,
    rho: &[KElem],
    out: &LookupOut,
    tr: &mut LkpTranscript,
) -> (bool, bool) {
    if out.kappa == 0 {
        let s2 = super::zc_range::LogupSumcheckOut {
            proof: SumcheckProof { rounds: out.proof.rounds.clone(), final_evals: out.proof.final_evals.clone() },
            point: out.point.clone(),
            h_sum: out.h_sum.clone(),
            table_sum: out.table_sum.clone(),
            h_at_point: out.h_at_point.clone(),
            key_at_point: out.keys_at_point.first().cloned().unwrap_or_else(|| kf.zero()),
            secs_h: 0.0,
            secs_tables: 0.0,
            secs_sumcheck: 0.0,
            secs_open: 0.0,
            kmuls_counted: 0,
            wire_bytes: 0,
            h_values: 0,
            h_raw_bytes: 0,
        };
        return super::zc_range::logup_sumcheck_verify(kf, n_log2, alpha, rho, &s2, tr);
    }
    let kappa = out.kappa;
    let n = n_log2 - kappa;
    let leaves = 1usize << kappa;
    let degrees = pf_degrees(kappa, n);
    let combine = |kf: &KField, v: &[KElem]| pf_combine(kf, alpha, v);
    let zero = kf.zero();
    let chain_ok = match super::fold::ixf_sumcheck_verify(kf, &degrees, &zero, &out.proof, &combine, tr) {
        Some((point, _c)) => {
            let f = &out.proof.final_evals;
            point == out.point
                && rho.len() == n
                && f.len() == 2 + leaves
                && f[0] == super::gkr::eq_eval(kf, rho, &point)
                && f[1] == out.h_at_point
                && out.keys_at_point.len() == leaves
                && f[2..].iter().zip(out.keys_at_point.iter()).all(|(a, b)| a == b)
        }
        None => false,
    };
    let sum_ok = out.h_sum == out.table_sum;
    (chain_ok, sum_ok)
}

/// The eq kernel over the FULL 2^n_log2 key hypercube for the claim
/// key_b(x*): eq((b || x*), i) = [low kappa bits of i == b] * eq(x*, i >>
/// kappa) — the row kernel a key claim lands with on the member tensor.
pub fn key_claim_eq(kf: &KField, point: &[KElem], kappa: usize, b: usize) -> Vec<KElem> {
    let eq_hi = eq_table(kf, point);
    let size = eq_hi.len() << kappa;
    let mut out = vec![kf.zero(); size];
    for (x, e) in eq_hi.iter().enumerate() {
        out[(x << kappa) | b] = e.clone();
    }
    out
}

/// Wire bytes of a routed column's shipped objects (64 B per K element:
/// rounds + finals + the four served sums/evaluations + key claims).
pub fn lookup_wire_bytes(out: &LookupOut) -> usize {
    (out.proof.rounds.iter().map(|r| r.len()).sum::<usize>() + out.proof.final_evals.len() + 3 + out.keys_at_point.len())
        * 64
}

/// Direct grounding of a served key claim (the differential's contract):
/// key_b(x*) recomputed as the MLE of the raw key column at (b || x*).
pub fn key_at_point_direct(kf: &KField, col: &LookupCol, point: &[KElem], kappa: usize, b: usize) -> KElem {
    let eq = key_claim_eq(kf, point, kappa, b);
    let mut s = kf.zero();
    for (i, e) in eq.iter().enumerate() {
        if !kf.is_zero(e) {
            s = kf.add(&s, &kf.mul(e, &col.keys[i]));
        }
    }
    s
}

/// Direct grounding of h(x*): the MLE of the helper column at x*.
pub fn h_at_point_direct(kf: &KField, h: &[KElem], point: &[KElem]) -> KElem {
    mle_eval(kf, h, point)
}

/// The house round-chain reduction at one point (exposed for the
/// differential legs; verbatim sumcheck::lagrange_eval).
pub fn round_reduce(kf: &KField, g: &[KElem], r: &KElem) -> KElem {
    lagrange_eval(kf, g, r)
}
