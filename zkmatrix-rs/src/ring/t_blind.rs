// [UAGB1-BL] U-AG-B1 wave 4, lane BL: T_blind — masking the
// weight-touching ROUND POLYNOMIALS (and terminals) of the composed
// P2 path, I-6-compliantly.
//
// The gap BG held honestly (UAGB1_PASS_AGG_REPORT.md Section 7.3 item
// 6): under P2 the weight-group eval-proof FLOOR is Tier-Z masked
// once per pass, but the matmul instances' ROUND POLYNOMIALS and
// weight-side TERMINALS ride the transcript unmasked — each a
// challenge-keyed functional of the private weight tables that
// accumulates across proofs (the R1 principle). This module is the
// O-4 T_blind + masked-sumcheck construction (AGGREGATION_ZK_DESIGN
// Sections 2-3) transcribed to the engine:
//
//   * Surface 1 (round polynomials): an ADDITIVE round mask M with
//     n_g = 1 + sum_t d_t fresh uniform K coefficients (AZ-L1a's
//     count). The prover pins G = sum_cube M, draws rho, and runs the
//     sumcheck on (product) + rho*M; the exposed round polynomials
//     carry rho*M_t and are uniform on the check variety (AZ-L1a).
//     One mask opening g_open = M(point) closes it.
//   * Surface 2 (terminals): a selector-extension bit (AZ-L2a). The
//     private (weight) side gets a fresh committed pad on the ext=1
//     block; the public (activation) side is zeroed there, so the
//     extended cube sum is the original claim EXACTLY and the exposed
//     terminal b* is one-time-padded.
//   * Surface 3 (batch value): a unit-weight claim segment (AZ-L2b) —
//     one fresh committed uniform K-value added to the opened batch
//     value, decoupling it from the tensor MLEs.
//
// I-6 stays HARD: G, g_open, the pad, and the segment are ALL
// committed T_blind material grounded through the ONE weight-group
// batched opening (they ride the Tier-Z-masked descent — never a bare
// floor, so the AZB-11 activation-floor invariant is untouched). No
// new Gaussian-masked opening exists; the only Gaussian object in the
// pass remains BG's priced Tier-Z floor response.
//
// The module is arithmetic-only (no I/O, no statement plumbing) so it
// is unit-testable at real K arithmetic and real matmul schedules;
// the composed-path wiring lives behind the [UAGB1-BL] hooks in
// ring_matmul.rs's [UAGB1-BG] section. Certificates E-1/E-2/E-5/
// E-7(ii,iii)/E-8/E-9 (rank + recovery + simulator) and the FS-order
// pairs E-3/E-4 run in `t-blind battery`.

use super::kfield::{KElem, KField, K_DEG};
use super::sumcheck::{fold, lagrange_eval, round_poly, LkpTranscript, SumcheckProof};
use super::{rng_below, RngSource};

// ---------------------------------------------------------------------------
// The additive round mask (Surface 1).

/// M(x_0..x_{n-1}) = a0 + sum_{t} sum_{j=1..d_t} a_{t,j} x_t^j.
/// The per-round degree d_t matches the instance's round degree, so
/// M_t(X) has degree d_t and the masked round polynomial keeps the
/// public schedule (AZ-L1a: n_g exposures net of ell+1 forced
/// relations, full rank onto the coefficients).
#[derive(Clone, Debug)]
pub struct RoundMask {
    pub a0: KElem,
    /// coeffs[t] = [a_{t,1}, .., a_{t,d_t}] (no constant term per round).
    pub coeffs: Vec<Vec<KElem>>,
    pub degrees: Vec<usize>,
}

impl RoundMask {
    /// n_g = 1 + sum_t d_t.
    pub fn n_g(&self) -> usize {
        1 + self.degrees.iter().sum::<usize>()
    }

    /// Draw fresh uniform K coefficients from `rng` (per proof — the
    /// freshness rule; reuse is an E-5 leak).
    pub fn draw(kf: &KField, degrees: &[usize], rng: &mut dyn RngSource) -> RoundMask {
        let q = kf.zq.q;
        let draw_k = |rng: &mut dyn RngSource| -> KElem {
            (0..K_DEG).map(|_| rng_below(rng, q)).collect()
        };
        let a0 = draw_k(rng);
        let coeffs = degrees
            .iter()
            .map(|&d| (0..d).map(|_| draw_k(rng)).collect())
            .collect();
        RoundMask { a0, coeffs, degrees: degrees.to_vec() }
    }

    /// The flat coefficient vector in canonical order
    /// [a0, a_{0,1..d_0}, a_{1,1..d_1}, ..] — the committed layout and
    /// the order the grounding kernels (`*_weights`) index.
    pub fn flat_coeffs(&self) -> Vec<KElem> {
        let mut v = Vec::with_capacity(self.n_g());
        v.push(self.a0.clone());
        for c in &self.coeffs {
            v.extend(c.iter().cloned());
        }
        v
    }

    /// G = sum_{b in {0,1}^n} M(b) = 2^n a0 + 2^{n-1} sum_{t,j} a_{t,j}.
    pub fn hypercube_sum(&self, kf: &KField) -> KElem {
        let n = self.degrees.len() as u32;
        let mut acc = kf.scale(pow2_modq(kf, n), &self.a0);
        let half = pow2_modq(kf, n - 1);
        for c in &self.coeffs {
            for a in c {
                acc = kf.add(&acc, &kf.scale(half, a));
            }
        }
        acc
    }

    /// Public weights of `flat_coeffs` reproducing G (base-field, as K):
    /// [2^n, 2^{n-1}, 2^{n-1}, ..]. Used to ground G against the
    /// committed mask tensor.
    pub fn hypercube_weights(kf: &KField, degrees: &[usize], n_g: usize) -> Vec<KElem> {
        let n = degrees.len() as u32;
        let mut w = Vec::with_capacity(n_g);
        w.push(kf.embed(pow2_modq(kf, n)));
        let half = kf.embed(pow2_modq(kf, n - 1));
        for &d in degrees {
            for _ in 0..d {
                w.push(half.clone());
            }
        }
        w
    }

    /// M_t(X) evaluations at X = 0..=d_t, given r_prev = [r_0..r_{t-1}]:
    /// M_t(X) = 2^{h}(base + Q_t(X)) + 2^{h-1} tail, h = n-1-t,
    /// base = a0 + sum_{s<t} P_s(r_s), tail = sum_{s>t} P_s(1),
    /// P_s(x) = sum_j a_{s,j} x^j, Q_t(X) = P_t(X).
    pub fn round_contrib(&self, kf: &KField, t: usize, r_prev: &[KElem]) -> Vec<KElem> {
        let n = self.degrees.len();
        let h = (n - 1 - t) as u32;
        let mut base = self.a0.clone();
        for (s, r) in r_prev.iter().enumerate() {
            base = kf.add(&base, &poly_at(kf, &self.coeffs[s], r));
        }
        let mut tail = kf.zero();
        for s in (t + 1)..n {
            tail = kf.add(&tail, &poly_at_one(kf, &self.coeffs[s]));
        }
        let pw_h = pow2_modq(kf, h);
        let d_t = self.degrees[t];
        (0..=d_t)
            .map(|x| {
                let qx = poly_at(kf, &self.coeffs[t], &kf.embed(x as u64));
                let mut v = kf.scale(pw_h, &kf.add(&base, &qx));
                if h >= 1 {
                    v = kf.add(&v, &kf.scale(pow2_modq(kf, h - 1), &tail));
                }
                v
            })
            .collect()
    }

    /// g_open = M(point) = a0 + sum_t P_t(r_t).
    pub fn open(&self, kf: &KField, point: &[KElem]) -> KElem {
        let mut acc = self.a0.clone();
        for (t, r) in point.iter().enumerate() {
            acc = kf.add(&acc, &poly_at(kf, &self.coeffs[t], r));
        }
        acc
    }

    /// Public weights of `flat_coeffs` reproducing g_open at `point`:
    /// [1, r_0^1..r_0^{d_0}, r_1^1..r_1^{d_1}, ..] (K-valued).
    pub fn open_weights(kf: &KField, degrees: &[usize], point: &[KElem]) -> Vec<KElem> {
        let mut w = vec![kf.one()];
        for (t, &d) in degrees.iter().enumerate() {
            let mut p = point[t].clone();
            for _ in 0..d {
                w.push(p.clone());
                p = kf.mul(&p, &point[t]);
            }
        }
        w
    }
}

/// P(r) = sum_{j=1..len} c[j-1] r^j (no constant term).
fn poly_at(kf: &KField, c: &[KElem], r: &KElem) -> KElem {
    let mut acc = kf.zero();
    let mut p = r.clone();
    for cj in c {
        acc = kf.add(&acc, &kf.mul(cj, &p));
        p = kf.mul(&p, r);
    }
    acc
}
fn poly_at_one(kf: &KField, c: &[KElem]) -> KElem {
    let mut acc = kf.zero();
    for cj in c {
        acc = kf.add(&acc, cj);
    }
    acc
}
/// 2^e mod q as a base-field scalar.
fn pow2_modq(kf: &KField, e: u32) -> u64 {
    let q = kf.zq.q;
    let mut v = 1u128;
    for _ in 0..e {
        v = (v * 2) % q as u128;
    }
    v as u64
}

// ---------------------------------------------------------------------------
// The masked scheduled sumcheck.

/// Prove sum over the hypercube of combine(tables) = `claimed` with the
/// round polynomials blinded by rho*M. Ships round polynomials
/// (product + rho*mask) on the public `degrees` schedule; the caller
/// pins G before drawing rho and grounds G/g_open/finals through the
/// batched opening. Identical transcript discipline to
/// fold::ixf_sumcheck_prove (absorb round poly, THEN draw challenge).
pub fn masked_sumcheck_prove(
    kf: &KField,
    mut tables: Vec<Vec<KElem>>,
    degrees: &[usize],
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    mask: &RoundMask,
    rho: &KElem,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    let n = tables[0].len().trailing_zeros() as usize;
    assert_eq!(degrees.len(), n, "degree schedule covers every variable");
    assert_eq!(mask.degrees, degrees, "mask degrees match the schedule");
    assert!(tables.iter().all(|t| t.len() == 1 << n));
    let mut rounds = Vec::with_capacity(n);
    let mut point = Vec::with_capacity(n);
    for (t, &deg) in degrees.iter().enumerate() {
        let mut g = round_poly(kf, &tables, deg, combine);
        let m_t = mask.round_contrib(kf, t, &point);
        for (gx, mx) in g.iter_mut().zip(m_t.iter()) {
            *gx = kf.add(gx, &kf.mul(rho, mx));
        }
        tr.absorb_k(kf, "bl-mask-round-poly", &g);
        let r = tr.challenge_k(kf);
        tables = tables.iter().map(|tb| fold(kf, tb, &r)).collect();
        rounds.push(g);
        point.push(r);
    }
    let final_evals: Vec<KElem> = tables.into_iter().map(|mut t| t.remove(0)).collect();
    (SumcheckProof { rounds, final_evals }, point)
}

/// Verify the masked chain. `claimed` is the honest (unmasked) claim,
/// `g_hyper` = G (pinned, grounded separately), `g_open` = M(point)
/// (grounded separately). The verifier NEVER sees M. Returns the final
/// point and reduced claim; the caller grounds `proof.final_evals`.
#[allow(clippy::too_many_arguments)]
pub fn masked_sumcheck_verify(
    kf: &KField,
    degrees: &[usize],
    claimed: &KElem,
    g_hyper: &KElem,
    rho: &KElem,
    g_open: &KElem,
    proof: &SumcheckProof,
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    tr: &mut LkpTranscript,
) -> Option<(Vec<KElem>, KElem)> {
    if proof.rounds.len() != degrees.len() {
        return None;
    }
    // c_0 = claimed + rho * G.
    let mut c = kf.add(claimed, &kf.mul(rho, g_hyper));
    let mut point = Vec::with_capacity(degrees.len());
    for (g, &deg) in proof.rounds.iter().zip(degrees.iter()) {
        if g.len() != deg + 1 {
            return None;
        }
        if kf.add(&g[0], &g[1]) != c {
            return None;
        }
        tr.absorb_k(kf, "bl-mask-round-poly", g);
        let r = tr.challenge_k(kf);
        c = lagrange_eval(kf, g, &r);
        point.push(r);
    }
    // End check: combine(finals) + rho * g_open == c_n.
    let end = kf.add(&combine(kf, &proof.final_evals), &kf.mul(rho, g_open));
    if end != c {
        return None;
    }
    Some((point, c))
}

// ---------------------------------------------------------------------------
// Grounding-kernel helpers (the committed-mask layout: one coefficient
// per value ring, its 16 Y-basis coordinates in coords [0..16)).

/// The col kernel that extracts a coefficient KElem from a value ring's
/// first 16 coordinates: col[d] = Y^d (d < 16), zero elsewhere. With a
/// (1 x 128) tensor, <col, ring> = the coefficient stored in coords
/// [0..16).
pub fn coeff_extract_col(kf: &KField, cols: usize) -> Vec<KElem> {
    (0..cols)
        .map(|c| {
            if c < K_DEG {
                let mut e = vec![0u64; K_DEG];
                e[c] = 1;
                e
            } else {
                kf.zero()
            }
        })
        .collect()
}

/// Pack a flat list of coefficient KElems into value rings (one coeff
/// per ring, Y-basis coords in [0..16)). Rings padded to `n_rings` with
/// zero. Row-major i64 layout (mod-q residues centered to [-q/2, q/2)
/// is the caller's decomposition concern; here we return raw residues).
pub fn pack_coeffs_to_rings(coeffs: &[KElem], n_rings: usize) -> Vec<Vec<i64>> {
    let mut rings = vec![vec![0i64; super::D]; n_rings];
    for (i, c) in coeffs.iter().enumerate() {
        for (d, &v) in c.iter().enumerate() {
            rings[i][d] = v as i64;
        }
    }
    rings
}

// ---------------------------------------------------------------------------
// Freshness registry (E-5 / FP-L2 A7): the derive-time no-reuse gate.
// The engine's structural freshness is that masks are consumed by value
// from a non-Clone ProverRng; this registry is the auditable belt-and-
// suspenders the design's "statement hash records the T_blind segment
// id" asks for. A repeated (witness digest, T_blind digest) aborts.

use std::cell::RefCell;
use std::collections::HashSet;

thread_local! {
    static TBLIND_SEEN: RefCell<HashSet<[u8; 32]>> = RefCell::new(HashSet::new());
}

/// Register a (witness, T_blind) pair. Returns Err (deployment-blocking)
/// on reuse. `clear` resets the registry (battery hook only).
pub fn register_fresh(tag: [u8; 32]) -> Result<(), &'static str> {
    TBLIND_SEEN.with(|s| {
        let mut set = s.borrow_mut();
        if set.contains(&tag) {
            Err("T_blind reuse (E-5): the (witness, blind) pair repeats — deployment-blocking")
        } else {
            set.insert(tag);
            Ok(())
        }
    })
}
pub fn clear_registry() {
    TBLIND_SEEN.with(|s| s.borrow_mut().clear());
}
