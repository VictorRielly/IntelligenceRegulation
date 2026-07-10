// U-K3 (M4_LOOKUP_DESIGN.md Sections 3.4/5/8): the fractional GKR —
// the projective (p, q) binary tree over the LogUp leaves and the
// layered sumcheck descent that reduces its per-instance roots to MLE
// claims on the leaf columns, with NO committed intermediates and NO
// prover inversions (Papini-Habock's projective accumulation).
//
//   leaves:  witness (1, alpha - w_i), table (m_j, alpha - t_j)
//   parent:  p' = pL qR + pR qL,   q' = qL qR
//   root:    P/Q = the fractional sum sum leaf_p / leaf_q
//
// INSTANCE BATCHING (build note, deviates in mechanism — not in
// soundness or cost class — from the design's Section 5 narrative):
// the L per-instance trees are batched by treating the instance index
// as e = log2(L) EXTRA sumcheck variables rather than by rho-weighted
// claim combination. Layer k's descent runs one degree-3 sumcheck over
// (k + e) variables of
//
//   p_k(zeta) + lambda_k q_k(zeta)
//     = sum_{(b,e)} eq(zeta,(b,e)) [ p_{k+1}(0,b,e) q_{k+1}(1,b,e)
//         + p_{k+1}(1,b,e) q_{k+1}(0,b,e)
//         + lambda_k q_{k+1}(0,b,e) q_{k+1}(1,b,e) ],
//
// with the child bit little-endian-first (the U-K2 convention), the
// b-variables next and the instance variables e LAST. The eq-weights
// of the bound instance coordinates play exactly the role the design
// assigned to rho (the E3-N3 hash edge is those challenges' ordering);
// each layer sends ONE 4-value boundary (p at child 0/1, q at child
// 0/1) — the accounting Section 7 of the design priced — and the
// witness descent at the frozen FFN point runs sum_{k=0}^{22}(k + 5)
// = 368 rounds (the design's 253 counted the b-variables only; the
// round-poly volume grows ~45%, ~30 KB/pass — noise at the 120 KB
// scale, recorded in the LKP-3 freeze row).
//
// After the last layer the caller holds (point, p-claim, q-claim)
// over the CONCATENATED leaf table (index e * 2^depth + i): for the
// witness side p-claim must equal 1 (all-ones MLE) and q-claim =
// alpha - MLE(fused leaves)(point) — the E4 landing; for the table
// side p-claim = MLE(multiplicities) and q-claim is verifier-
// computable from the public fused table.

use super::kfield::{KElem, KField};
use super::sumcheck::{LkpTranscript, SumcheckProof, mle_eval, sumcheck_prove, sumcheck_verify};

// ---------------------------------------------------------------------------
// Trees.

/// One instance's projective tree: layers[k] has 2^k (p, q) pairs,
/// layers[depth] = the leaves.
pub struct FracTree {
    pub layers_p: Vec<Vec<KElem>>,
    pub layers_q: Vec<Vec<KElem>>,
}

impl FracTree {
    pub fn depth(&self) -> usize {
        self.layers_p.len() - 1
    }
    pub fn root(&self) -> [KElem; 2] {
        [self.layers_p[0][0].clone(), self.layers_q[0][0].clone()]
    }
}

/// Build the tree bottom-up. leaf_p/leaf_q length must be a power of 2
/// (the caller pads with the neutral fraction (0, 1) — zero numerator,
/// unit denominator — which adds nothing to the sum).
pub fn build_tree(kf: &KField, leaf_p: Vec<KElem>, leaf_q: Vec<KElem>) -> FracTree {
    let n = leaf_p.len();
    assert!(n.is_power_of_two() && leaf_q.len() == n);
    let mut layers_p = vec![leaf_p];
    let mut layers_q = vec![leaf_q];
    while layers_p.last().unwrap().len() > 1 {
        let (cp, cq) = (layers_p.last().unwrap(), layers_q.last().unwrap());
        let half = cp.len() / 2;
        let mut np = Vec::with_capacity(half);
        let mut nq = Vec::with_capacity(half);
        for i in 0..half {
            let (pl, pr) = (&cp[2 * i], &cp[2 * i + 1]);
            let (ql, qr) = (&cq[2 * i], &cq[2 * i + 1]);
            np.push(kf.add(&kf.mul(pl, qr), &kf.mul(pr, ql)));
            nq.push(kf.mul(ql, qr));
        }
        layers_p.push(np);
        layers_q.push(nq);
    }
    layers_p.reverse();
    layers_q.reverse();
    FracTree { layers_p, layers_q }
}

/// The neutral padding fraction (0, 1).
pub fn neutral_leaf(kf: &KField) -> (KElem, KElem) {
    (kf.zero(), kf.one())
}

// ---------------------------------------------------------------------------
// eq helpers (shared with the verifier's final checks and E4).

/// The eq table over 2^n points for a point z, little-endian (variable
/// v is bit v of the index): each new variable doubles the table with
/// itself as the new HIGHEST bit, so variable 0 stays bit 0.
pub fn eq_table(kf: &KField, z: &[KElem]) -> Vec<KElem> {
    let mut t = vec![kf.one()];
    for zv in z {
        let zbar = kf.sub(&kf.one(), zv);
        let mut nt = Vec::with_capacity(t.len() * 2);
        for e in &t {
            nt.push(kf.mul(e, &zbar));
        }
        for e in &t {
            nt.push(kf.mul(e, zv));
        }
        t = nt;
    }
    t
}

/// eq(a, b) for two K points.
pub fn eq_eval(kf: &KField, a: &[KElem], b: &[KElem]) -> KElem {
    assert_eq!(a.len(), b.len());
    let mut acc = kf.one();
    for (x, y) in a.iter().zip(b.iter()) {
        let both1 = kf.mul(x, y);
        let both0 = kf.mul(&kf.sub(&kf.one(), x), &kf.sub(&kf.one(), y));
        acc = kf.mul(&acc, &kf.add(&both1, &both0));
    }
    acc
}

// ---------------------------------------------------------------------------
// The descent.

pub struct GkrDescentProof {
    /// Per layer: the sumcheck (its final_evals = [eq, p0, p1, q0, q1]
    /// — the last four are the layer's boundary values).
    pub layers: Vec<SumcheckProof>,
}

fn layer_combine(kf: &KField, v: &[KElem], lambda: &KElem) -> KElem {
    // v = [eq, p0, p1, q0, q1]
    let t = kf.add(
        &kf.add(&kf.mul(&v[1], &v[4]), &kf.mul(&v[2], &v[3])),
        &kf.mul(lambda, &kf.mul(&v[3], &v[4])),
    );
    kf.mul(&v[0], &t)
}

/// Absorb the exposed roots — the CALLER runs this on both sides
/// before the descent. The instance coordinates z_e (the rho role)
/// are drawn from the transcript immediately after, so the E3-N3 edge
/// ("z_e must follow every instance's roots/commitments") is exactly
/// this call's placement; the [U-K3] battery demonstrates the
/// malleability that skipping it admits.
pub fn absorb_roots(kf: &KField, roots: &[[KElem; 2]], tr: &mut LkpTranscript) {
    for r in roots {
        tr.absorb_k(kf, "gkr-root", r);
    }
}

/// Descend L same-shape trees (L a power of two; e = log2 L instance
/// variables). The transcript must ALREADY bind every instance's
/// roots (absorb_roots) and, upstream, the commitments alpha was
/// drawn from. Returns (proof, final point with b-variables first and
/// instance variables last, p-claim, q-claim) over the concatenated
/// leaf table (index e << depth | i).
pub fn gkr_prove(
    kf: &KField,
    trees: &[FracTree],
    tr: &mut LkpTranscript,
) -> (GkrDescentProof, Vec<KElem>, KElem, KElem) {
    let l = trees.len();
    assert!(l.is_power_of_two());
    let e_bits = l.trailing_zeros() as usize;
    let depth = trees[0].depth();
    assert!(trees.iter().all(|t| t.depth() == depth));
    // Instance coordinates (the rho role); roots already bound by the
    // caller's absorb_roots.
    let z_e: Vec<KElem> = (0..e_bits).map(|_| tr.challenge_k(kf)).collect();
    let root_p: Vec<KElem> = trees.iter().map(|t| t.layers_p[0][0].clone()).collect();
    let root_q: Vec<KElem> = trees.iter().map(|t| t.layers_q[0][0].clone()).collect();
    let mut p_claim = mle_eval(kf, &root_p, &z_e);
    let mut q_claim = mle_eval(kf, &root_q, &z_e);
    let mut zeta = z_e; // b-part empty at the root
    let mut layers = Vec::with_capacity(depth);
    for k in 0..depth {
        let lambda = tr.challenge_k(kf);
        let size = l << k;
        let eq = eq_table(kf, &zeta);
        assert_eq!(eq.len(), size);
        let mut p0 = Vec::with_capacity(size);
        let mut p1 = Vec::with_capacity(size);
        let mut q0 = Vec::with_capacity(size);
        let mut q1 = Vec::with_capacity(size);
        for i in 0..size {
            let (e, b) = (i >> k, i & ((1 << k) - 1));
            p0.push(trees[e].layers_p[k + 1][2 * b].clone());
            p1.push(trees[e].layers_p[k + 1][2 * b + 1].clone());
            q0.push(trees[e].layers_q[k + 1][2 * b].clone());
            q1.push(trees[e].layers_q[k + 1][2 * b + 1].clone());
        }
        let lam = lambda.clone();
        let combine =
            move |kfi: &KField, v: &[KElem]| -> KElem { layer_combine(kfi, v, &lam) };
        let (sc, r) = sumcheck_prove(kf, vec![eq, p0, p1, q0, q1], 3, &combine, tr);
        // Boundary into the transcript BEFORE mu (the E3-N5 edge).
        tr.absorb_k(kf, "gkr-boundary", &sc.final_evals[1..5]);
        let mu = tr.challenge_k(kf);
        let (bp0, bp1, bq0, bq1) =
            (&sc.final_evals[1], &sc.final_evals[2], &sc.final_evals[3], &sc.final_evals[4]);
        p_claim = kf.add(bp0, &kf.mul(&mu, &kf.sub(bp1, bp0)));
        q_claim = kf.add(bq0, &kf.mul(&mu, &kf.sub(bq1, bq0)));
        let mut nz = vec![mu];
        nz.extend(r);
        zeta = nz;
        layers.push(sc);
    }
    (GkrDescentProof { layers }, zeta, p_claim, q_claim)
}

/// Verify a descent against the exposed per-instance roots. The
/// transcript must already bind the roots (absorb_roots — the same
/// edge as the prover side). Returns (final point, p-claim, q-claim)
/// for the CALLER to ground against the leaf data (E4 / public tables
/// / direct MLE in batteries). None = reject.
pub fn gkr_verify(
    kf: &KField,
    roots: &[[KElem; 2]],
    depth: usize,
    proof: &GkrDescentProof,
    tr: &mut LkpTranscript,
) -> Option<(Vec<KElem>, KElem, KElem)> {
    let l = roots.len();
    if !l.is_power_of_two() || proof.layers.len() != depth {
        return None;
    }
    let e_bits = l.trailing_zeros() as usize;
    let z_e: Vec<KElem> = (0..e_bits).map(|_| tr.challenge_k(kf)).collect();
    let root_p: Vec<KElem> = roots.iter().map(|r| r[0].clone()).collect();
    let root_q: Vec<KElem> = roots.iter().map(|r| r[1].clone()).collect();
    let mut p_claim = mle_eval(kf, &root_p, &z_e);
    let mut q_claim = mle_eval(kf, &root_q, &z_e);
    let mut zeta = z_e;
    for (k, sc) in proof.layers.iter().enumerate() {
        let lambda = tr.challenge_k(kf);
        let claimed = kf.add(&p_claim, &kf.mul(&lambda, &q_claim));
        let lam = lambda.clone();
        let combine =
            move |kfi: &KField, v: &[KElem]| -> KElem { layer_combine(kfi, v, &lam) };
        if sc.final_evals.len() != 5 {
            return None;
        }
        let (r, _c) = sumcheck_verify(kf, k + e_bits, 3, &claimed, sc, &combine, tr)?;
        // The eq factor is verifier-computable — the prover's value is
        // pinned, not trusted.
        if sc.final_evals[0] != eq_eval(kf, &zeta, &r) {
            return None;
        }
        tr.absorb_k(kf, "gkr-boundary", &sc.final_evals[1..5]);
        let mu = tr.challenge_k(kf);
        let (bp0, bp1, bq0, bq1) =
            (&sc.final_evals[1], &sc.final_evals[2], &sc.final_evals[3], &sc.final_evals[4]);
        p_claim = kf.add(bp0, &kf.mul(&mu, &kf.sub(bp1, bp0)));
        q_claim = kf.add(bq0, &kf.mul(&mu, &kf.sub(bq1, bq0)));
        let mut nz = vec![mu];
        nz.extend(r);
        zeta = nz;
    }
    Some((zeta, p_claim, q_claim))
}

/// Per-instance root cross-check: P_w Q_t == P_t Q_w with both
/// denominators nonzero — the LogUp identity itself, checked without
/// any inversion.
pub fn root_cross_check(kf: &KField, w_root: &[KElem; 2], t_root: &[KElem; 2]) -> bool {
    !kf.is_zero(&w_root[1])
        && !kf.is_zero(&t_root[1])
        && kf.mul(&w_root[0], &t_root[1]) == kf.mul(&t_root[0], &w_root[1])
}

// ---------------------------------------------------------------------------
// Derive-time gates and freeze-row arithmetic.

/// LKP-2: the LogUp characteristic ceiling with the design's >= 64x
/// margin — total lookups per table INSTANCE must stay far below
/// char(K) = q.
pub fn ceiling_gate_ok(n_inst: u64, q: u64) -> bool {
    n_inst.checked_mul(64).is_some_and(|v| v < q)
}

/// LKP-3: transcript-shape arithmetic at a frozen point — rounds and
/// K-element counts of one descent over 2^e_bits instances of the
/// given depth (round polys are 4 K-elements each at degree 3;
/// boundaries 4 per layer).
pub fn transcript_shape(depth: usize, e_bits: usize) -> (usize, usize, usize) {
    let rounds: usize = (0..depth).map(|k| k + e_bits).sum();
    (rounds, 4 * rounds, 4 * depth)
}
