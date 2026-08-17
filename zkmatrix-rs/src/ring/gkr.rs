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

use super::ct_engine::prof;
use super::kfield::{KElem, KField, KL, KTab, k9_tree_step};
use super::sumcheck::{
    LkpTranscript, SumcheckProof, lagrange_eval, mle_eval, round_poly, sumcheck_prove,
    sumcheck_verify,
};

// ---------------------------------------------------------------------------
// Trees.

/// One instance's projective tree: layer k holds 2^k (p, q) pairs, layer
/// depth = the leaves.
///
/// U-K9 (H-03): the representation is internal. When the field's bulk
/// kernel is live (KField::new at the frozen q31 point) layers are packed
/// lane-blocked u32 tables — 64 B per element instead of a boxed Vec<u64>
/// KElem (~170 B with allocator overhead) — and the builders/descents run
/// the kernel-grade bulk paths. The scalar-oracle field
/// (KField::harness_scalar) and non-qualifying moduli keep the original
/// boxed layout and scalar arithmetic, bit-identically.
pub struct FracTree {
    repr: TreeRepr,
}

enum TreeRepr {
    Packed { lp: Vec<KTab>, lq: Vec<KTab> },
    Boxed { lp: Vec<Vec<KElem>>, lq: Vec<Vec<KElem>> },
    /// [UPERF2-A] The all-neutral tree (every leaf (0, 1) — the
    /// `neutral_tree` pads): every layer is (0, 1) too, so nothing is
    /// stored. Produced by build_tree/build_tree_sparse on the fast
    /// packed path; every accessor answers as the materialized tree
    /// would, and the bulk descents skip its slices analytically
    /// (gkr_masked). ~1 GB of packed layers per depth-22 pad saved.
    Neutral { depth: usize },
}

impl FracTree {
    pub fn depth(&self) -> usize {
        match &self.repr {
            TreeRepr::Packed { lp, .. } => lp.len() - 1,
            TreeRepr::Boxed { lp, .. } => lp.len() - 1,
            TreeRepr::Neutral { depth } => *depth,
        }
    }

    pub fn root(&self) -> [KElem; 2] {
        [self.p_elem(0, 0), self.q_elem(0, 0)]
    }

    /// Scalar element access (any representation).
    pub(crate) fn p_elem(&self, layer: usize, i: usize) -> KElem {
        match &self.repr {
            TreeRepr::Packed { lp, .. } => lp[layer].get(i),
            TreeRepr::Boxed { lp, .. } => lp[layer][i].clone(),
            TreeRepr::Neutral { depth } => {
                debug_assert!(layer <= *depth && i < (1usize << layer));
                vec![0u64; super::kfield::K_DEG]
            }
        }
    }

    pub(crate) fn q_elem(&self, layer: usize, i: usize) -> KElem {
        match &self.repr {
            TreeRepr::Packed { lq, .. } => lq[layer].get(i),
            TreeRepr::Boxed { lq, .. } => lq[layer][i].clone(),
            TreeRepr::Neutral { depth } => {
                debug_assert!(layer <= *depth && i < (1usize << layer));
                let mut e = vec![0u64; super::kfield::K_DEG];
                e[0] = 1;
                e
            }
        }
    }

    /// Packed layer views (bulk descent paths; panics on boxed trees —
    /// the dispatchers never mix modes — and on neutral trees, whose
    /// callers test `is_neutral` first).
    pub(crate) fn p_layer(&self, layer: usize) -> &KTab {
        match &self.repr {
            TreeRepr::Packed { lp, .. } => &lp[layer],
            TreeRepr::Boxed { .. } => panic!("packed layer view on a boxed tree"),
            TreeRepr::Neutral { .. } => panic!("packed layer view on a neutral tree"),
        }
    }

    pub(crate) fn q_layer(&self, layer: usize) -> &KTab {
        match &self.repr {
            TreeRepr::Packed { lq, .. } => &lq[layer],
            TreeRepr::Boxed { .. } => panic!("packed layer view on a boxed tree"),
            TreeRepr::Neutral { .. } => panic!("packed layer view on a neutral tree"),
        }
    }

    /// Bulk-path eligible: packed layers or the (implicitly packed)
    /// neutral tree.
    pub(crate) fn is_packed(&self) -> bool {
        matches!(self.repr, TreeRepr::Packed { .. } | TreeRepr::Neutral { .. })
    }

    pub(crate) fn is_neutral(&self) -> bool {
        matches!(self.repr, TreeRepr::Neutral { .. })
    }
}

/// [UPERF2-A] Is (p, q) the neutral leaf (0, 1)?
fn leaf_is_neutral(p: &KElem, q: &KElem) -> bool {
    p.iter().all(|&x| x == 0) && q[0] == 1 && q[1..].iter().all(|&x| x == 0)
}

/// Build the tree bottom-up. leaf_p/leaf_q length must be a power of 2
/// (the caller pads with the neutral fraction (0, 1) — zero numerator,
/// unit denominator — which adds nothing to the sum).
pub fn build_tree(kf: &KField, leaf_p: Vec<KElem>, leaf_q: Vec<KElem>) -> FracTree {
    let n = leaf_p.len();
    assert!(n.is_power_of_two() && leaf_q.len() == n);
    if kf.kern.is_some() {
        assert!(
            super::kfield::k9_capacity_ok(n),
            "K9 projective tree exceeds the audited packed-table cap"
        );
    }
    if kf.kern.is_none() {
        return build_tree_boxed(kf, leaf_p, leaf_q);
    }
    let oracle = super::eval_proof::oracle_mode();
    // [UPERF2-A] the all-neutral tree (a `neutral_tree` pad) is not
    // materialized on the fast path: every layer would be (0, 1).
    if !oracle && leaf_p.iter().zip(leaf_q.iter()).all(|(p, q)| leaf_is_neutral(p, q)) {
        return FracTree { repr: TreeRepr::Neutral { depth: n.trailing_zeros() as usize } };
    }
    // Pack and DROP the boxed leaves one side at a time (H-03: the boxed
    // form is ~2.7x the packed size; never hold both sides twice).
    // [UPERF2-A] the pack is threaded (positional) on the fast path, and
    // with ZK_THREADS > 1 the 2^depth small frees of each boxed side run
    // on a detached thread, off the build's critical path (values are
    // untouched; at 1 thread the drop stays inline).
    let pack = |v: &[KElem]| -> KTab {
        let _t = prof::timer(prof::A_TREE_PACK);
        if oracle { KTab::from_kelems(v) } else { super::kfield::k9_pack_par(v) }
    };
    let leaf_p_t = pack(&leaf_p);
    drop_boxed_leaves(leaf_p, oracle);
    let leaf_q_t = pack(&leaf_q);
    drop_boxed_leaves(leaf_q, oracle);
    build_tree_packed(kf, leaf_p_t, leaf_q_t)
}

/// [UPERF2-A] Drop a boxed leaf vector: inline (the pre-change
/// behavior) at ZK_THREADS 1 or under the oracle routing, on a detached
/// thread otherwise (2^22 frees are ~0.3 s at rig depth, per side).
fn drop_boxed_leaves(v: Vec<KElem>, oracle: bool) {
    if oracle || super::kfield::k9_threads() <= 1 {
        drop(v);
    } else {
        std::thread::spawn(move || drop(v));
    }
}

/// [UPERF2-A] The compact all-neutral tree of `depth` (every leaf (0, 1)):
/// no layer is materialized on the packed path — the fast descents skip
/// its instance slices analytically — and the scalar-oracle field gets
/// the boxed tree, so this is a drop-in for `descent_fold::neutral_tree`
/// (which allocates 2 x 2^depth boxed leaves before build_tree detects
/// the same thing). Bit-identical trees either way.
pub fn build_neutral_tree(kf: &KField, depth: usize) -> FracTree {
    let n = 1usize << depth;
    if kf.kern.is_none() || super::eval_proof::oracle_mode() {
        let one = {
            let mut e = vec![0u64; super::kfield::K_DEG];
            e[0] = 1;
            e
        };
        return build_tree(kf, vec![vec![0u64; super::kfield::K_DEG]; n], vec![one; n]);
    }
    assert!(super::kfield::k9_capacity_ok(n), "K9 projective tree exceeds the audited packed-table cap");
    FracTree { repr: TreeRepr::Neutral { depth } }
}

/// [UPERF2-A] Build a packed tree from a DEFAULT leaf pair plus sparse
/// overrides — no boxed leaf vector is ever allocated (the boxed pair of
/// a depth-22 tree is 2 x 4M heap Vecs, ~1.4 GB of transient churn and
/// ~1 s of malloc/free per tree). `entries` are (index, p, q) in any
/// order (last write wins); the leaf sequence is the same as build_tree
/// on the materialized vector, so the tree is bit-identical. The scalar
/// oracle field materializes and takes the boxed builder.
pub fn build_tree_sparse(
    kf: &KField,
    n: usize,
    default: (&KElem, &KElem),
    entries: impl IntoIterator<Item = (usize, KElem, KElem)>,
) -> FracTree {
    assert!(n.is_power_of_two());
    if kf.kern.is_none() {
        let mut lp = vec![default.0.clone(); n];
        let mut lq = vec![default.1.clone(); n];
        for (i, p, q) in entries {
            lp[i] = p;
            lq[i] = q;
        }
        return build_tree_boxed(kf, lp, lq);
    }
    assert!(
        super::kfield::k9_capacity_ok(n),
        "K9 projective tree exceeds the audited packed-table cap"
    );
    let mut entries = entries.into_iter().peekable();
    if entries.peek().is_none() && leaf_is_neutral(default.0, default.1) && !super::eval_proof::oracle_mode() {
        return FracTree { repr: TreeRepr::Neutral { depth: n.trailing_zeros() as usize } };
    }
    let _t = prof::timer(prof::A_TREE_PACK);
    // [UPERF2-E] zero defaults stay calloc-untouched, nonzero defaults are
    // filled blockwise in parallel (same bytes as KTab::filled).
    let mut leaf_p_t = KTab::zeroed(n);
    let mut leaf_q_t = KTab::zeroed(n);
    if !default.0.iter().all(|&x| x == 0) {
        ktab_fill_par(&mut leaf_p_t, default.0);
    }
    if !default.1.iter().all(|&x| x == 0) {
        ktab_fill_par(&mut leaf_q_t, default.1);
    }
    for (i, p, q) in entries {
        leaf_p_t.set(i, &p);
        leaf_q_t.set(i, &q);
    }
    drop(_t);
    build_tree_packed(kf, leaf_p_t, leaf_q_t)
}

/// [UPERF2-E] Fill a zeroed packed table with n copies of `e` — the
/// same bytes as `KTab::filled(n, e)` (blockwise pattern; the partial
/// last block by `set`), written in parallel chunks of whole blocks at
/// ZK_THREADS > 1 (positional, no reduction — identical for any thread
/// count).
fn ktab_fill_par(t: &mut KTab, e: &KElem) {
    let n = t.n;
    if n == 0 {
        return;
    }
    let nblk = n / KL;
    let mut blk = [0u32; super::kfield::KBLK];
    for j in 0..super::kfield::K_DEG {
        debug_assert!(e[j] < (1 << 31), "packed KTab expects canonical q31-class values");
        for l in 0..KL {
            blk[j * KL + l] = e[j] as u32;
        }
    }
    let full_words = nblk * super::kfield::KBLK;
    if super::kfield::k9_threads() <= 1 || nblk < 64 {
        for m in 0..nblk {
            t.d[m * super::kfield::KBLK..(m + 1) * super::kfield::KBLK].copy_from_slice(&blk);
        }
    } else {
        let d = &mut t.d[..full_words];
        super::kfield::k9_pooled_pub(|| {
            use rayon::prelude::*;
            d.par_chunks_mut(2048 * super::kfield::KBLK).for_each(|c| {
                for cb in c.chunks_exact_mut(super::kfield::KBLK) {
                    cb.copy_from_slice(&blk);
                }
            });
        });
    }
    for i in nblk * KL..n {
        t.set(i, e);
    }
}

/// [UPERF2-E] One aligned member block of a witness tree (the
/// `descent_fold::aligned_leaf` placement): `rows` x `cols` fused values,
/// element f = r*cols + c at leaf `base + r*cols_pad + c`; the leaf is
/// (1, alpha - value(f)).
pub struct AlignedBlock<'a> {
    pub base: usize,
    pub rows: usize,
    pub cols: usize,
    pub cols_pad: usize,
    /// The fused witness value of element f (row-major). Called once per
    /// element, from several threads on the fast path.
    pub value: &'a (dyn Fn(usize) -> KElem + Sync),
}

/// [UPERF2-E] Build the aligned blinded witness tree of 2^depth leaves:
/// (1, alpha - value) at the member-block leaves, the blinders (a, u) at
/// their positions, the neutral (0, 1) everywhere else. Fast packed path:
/// the packed leaf tables are filled positionally and IN PARALLEL per
/// member block over row chunks (a row chunk is a contiguous range of
/// whole KL-lane blocks whenever `base` and `cols_pad` are multiples of
/// KL — the pair planner's aligned bases and power-of-two strides — else
/// that block is written serially), the values generated on the fly: no
/// boxed leaf vector and no boxed member column ever exists (the callers'
/// `bk_tree_slots` materialization and the sparse builder's serial entry
/// loop are both gone). Scalar-oracle field / `oracle_mode()`: the boxed
/// leaves are materialized in the same layout and `build_tree` runs — the
/// pre-change body. Bit-identical trees (same leaf values, same packed
/// encoding; asserted by `uperf-a descent-battery` three ways).
pub fn build_aligned_witness_tree(
    kf: &KField,
    alpha: &KElem,
    depth: usize,
    blocks: &[AlignedBlock],
    blinders: &[(usize, KElem, KElem)],
) -> FracTree {
    let n = 1usize << depth;
    for b in blocks {
        assert!(b.cols <= b.cols_pad && b.base + b.rows * b.cols_pad <= n, "aligned block outside the tree");
    }
    if kf.kern.is_none() || super::eval_proof::oracle_mode() {
        let mut p = vec![kf.zero(); n];
        let mut q = vec![kf.one(); n];
        for b in blocks {
            for r in 0..b.rows {
                for c in 0..b.cols {
                    let i = b.base + r * b.cols_pad + c;
                    p[i] = kf.one();
                    q[i] = kf.sub(alpha, &(b.value)(r * b.cols + c));
                }
            }
        }
        for (i, a, u) in blinders {
            p[*i] = a.clone();
            q[*i] = u.clone();
        }
        return build_tree(kf, p, q);
    }
    assert!(
        super::kfield::k9_capacity_ok(n),
        "K9 projective tree exceeds the audited packed-table cap"
    );
    let _t = prof::timer(prof::A_TREE_PACK);
    let one = kf.one();
    // p defaults to the zero element: the calloc'd zeroed table IS that
    // fill (no page is touched here; the tree step faults them in, in
    // parallel). q defaults to one: written blockwise in parallel (the
    // page-fault + memset of a 64 MB depth-20 table was ~35 ms serial —
    // the dominant "pack" cost once the leaf loop is streamed).
    let mut leaf_p_t = KTab::zeroed(n);
    let mut leaf_q_t = KTab::zeroed(n);
    ktab_fill_par(&mut leaf_q_t, &one);
    let one_u32: [u32; super::kfield::K_DEG] = {
        let mut o = [0u32; super::kfield::K_DEG];
        o[0] = 1;
        o
    };
    // Write element `li` (relative to a slice starting at a block
    // boundary) into a packed slice.
    #[inline(always)]
    fn put(d: &mut [u32], li: usize, e: &[u32; super::kfield::K_DEG]) {
        let base = (li / KL) * super::kfield::KBLK + (li % KL);
        for j in 0..super::kfield::K_DEG {
            d[base + j * KL] = e[j];
        }
    }
    let to_u32 = |e: &KElem| -> [u32; super::kfield::K_DEG] {
        let mut o = [0u32; super::kfield::K_DEG];
        for j in 0..super::kfield::K_DEG {
            debug_assert!(e[j] < (1 << 31));
            o[j] = e[j] as u32;
        }
        o
    };
    let threads = super::kfield::k9_threads();
    for b in blocks {
        let aligned = b.base % KL == 0 && b.cols_pad % KL == 0;
        if !aligned || threads <= 1 || b.rows == 1 {
            // Serial positional writes (identical values).
            for r in 0..b.rows {
                for c in 0..b.cols {
                    let i = b.base + r * b.cols_pad + c;
                    let qv = to_u32(&kf.sub(alpha, &(b.value)(r * b.cols + c)));
                    put(&mut leaf_p_t.d, i, &one_u32);
                    put(&mut leaf_q_t.d, i, &qv);
                }
            }
            continue;
        }
        // Row chunks of ~4096 leaves: whole KL-blocks each.
        let chunk_rows = (4096 / b.cols_pad).max(1);
        let words_per_row = b.cols_pad / KL * super::kfield::KBLK;
        let (w0, w1) = (b.base / KL * super::kfield::KBLK, (b.base + b.rows * b.cols_pad) / KL * super::kfield::KBLK);
        let (pd, qd) = (&mut leaf_p_t.d[w0..w1], &mut leaf_q_t.d[w0..w1]);
        let (rows, cols, cols_pad, value) = (b.rows, b.cols, b.cols_pad, b.value);
        super::kfield::k9_pooled_pub(|| {
            use rayon::prelude::*;
            pd.par_chunks_mut(chunk_rows * words_per_row)
                .zip(qd.par_chunks_mut(chunk_rows * words_per_row))
                .enumerate()
                .for_each(|(ci, (pc, qc))| {
                    let r0 = ci * chunk_rows;
                    let r1 = (r0 + chunk_rows).min(rows);
                    for r in r0..r1 {
                        for c in 0..cols {
                            let li = (r - r0) * cols_pad + c;
                            let qv = to_u32(&kf.sub(alpha, &value(r * cols + c)));
                            put(pc, li, &one_u32);
                            put(qc, li, &qv);
                        }
                    }
                });
        });
    }
    for (i, a, u) in blinders {
        leaf_p_t.set(*i, a);
        leaf_q_t.set(*i, u);
    }
    drop(_t);
    build_tree_packed(kf, leaf_p_t, leaf_q_t)
}

/// [U-PERF-PA] B-D2 streamed builder: leaves are generated per index by
/// the closure and packed DIRECTLY into the leaf tables — no boxed leaf
/// vector ever exists (the boxed pair is ~2 x 170 B/element of transient
/// build-time heap; the packed pair is 2 x 64 B and IS the tree's own
/// leaf storage). Bit-identical to build_tree on the same leaf sequence;
/// the scalar-oracle field (and any non-qualifying modulus) falls back
/// to the boxed builder, identically.
pub fn build_tree_stream(
    kf: &KField,
    n: usize,
    mut leaf: impl FnMut(usize) -> (KElem, KElem),
) -> FracTree {
    assert!(n.is_power_of_two());
    if kf.kern.is_none() {
        let mut lp = Vec::with_capacity(n);
        let mut lq = Vec::with_capacity(n);
        for i in 0..n {
            let (p, q) = leaf(i);
            lp.push(p);
            lq.push(q);
        }
        return build_tree_boxed(kf, lp, lq);
    }
    assert!(
        super::kfield::k9_capacity_ok(n),
        "K9 projective tree exceeds the audited packed-table cap"
    );
    let mut leaf_p_t = KTab::zeroed(n);
    let mut leaf_q_t = KTab::zeroed(n);
    for i in 0..n {
        let (p, q) = leaf(i);
        leaf_p_t.set(i, &p);
        leaf_q_t.set(i, &q);
    }
    build_tree_packed(kf, leaf_p_t, leaf_q_t)
}

/// The packed bottom-up build over already-packed leaf tables (shared by
/// build_tree and build_tree_stream). [UPERF2-A] the layer steps are
/// threaded over independent output block ranges on the fast path
/// (`k9_tree_step_par`; positional, no reduction — bit-identical);
/// `oracle_mode()` routes to the serial step.
fn build_tree_packed(kf: &KField, leaf_p_t: KTab, leaf_q_t: KTab) -> FracTree {
    let kern = kf.kern.as_ref().expect("packed tree build requires the bulk kernel");
    let _t = prof::timer(prof::A_TREE_STEP);
    let oracle = super::eval_proof::oracle_mode();
    let mut lp = vec![leaf_p_t];
    let mut lq = vec![leaf_q_t];
    while lp.last().unwrap().n > 1 {
        let (cp, cq) = (lp.last().unwrap(), lq.last().unwrap());
        let half = cp.n / 2;
        let mut np = KTab::zeroed(half);
        let mut nq = KTab::zeroed(half);
        if half >= KL {
            if oracle {
                k9_tree_step(kern, &cp.d, &cq.d, &mut np.d, &mut nq.d, half / KL);
            } else {
                super::kfield::k9_tree_step_par(kern, &cp.d, &cq.d, &mut np.d, &mut nq.d, half / KL);
            }
        } else {
            for i in 0..half {
                let (pl, pr) = (cp.get(2 * i), cp.get(2 * i + 1));
                let (ql, qr) = (cq.get(2 * i), cq.get(2 * i + 1));
                np.set(i, &kf.add(&kf.mul(&pl, &qr), &kf.mul(&pr, &ql)));
                nq.set(i, &kf.mul(&ql, &qr));
            }
        }
        lp.push(np);
        lq.push(nq);
    }
    lp.reverse();
    lq.reverse();
    FracTree { repr: TreeRepr::Packed { lp, lq } }
}

/// The original boxed builder — the scalar oracle path, unchanged math.
fn build_tree_boxed(kf: &KField, leaf_p: Vec<KElem>, leaf_q: Vec<KElem>) -> FracTree {
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
    FracTree { repr: TreeRepr::Boxed { lp: layers_p, lq: layers_q } }
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
/// (U-K9: bulk-built on the packed kernel when live; identical values.)
pub fn eq_table(kf: &KField, z: &[KElem]) -> Vec<KElem> {
    if kf.kern.is_some() && z.len() >= 4 {
        return kf.kt_eq_table(z).to_kelems();
    }
    eq_table_scalar(kf, z)
}

fn eq_table_scalar(kf: &KField, z: &[KElem]) -> Vec<KElem> {
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
    let root_p: Vec<KElem> = trees.iter().map(|t| t.p_elem(0, 0)).collect();
    let root_q: Vec<KElem> = trees.iter().map(|t| t.q_elem(0, 0)).collect();
    let mut p_claim = mle_eval(kf, &root_p, &z_e);
    let mut q_claim = mle_eval(kf, &root_q, &z_e);
    let mut zeta = z_e; // b-part empty at the root
    let mut layers = Vec::with_capacity(depth);
    let bulk_ok = kf.kern.is_some() && trees.iter().all(|t| t.is_packed());
    for k in 0..depth {
        let lambda = tr.challenge_k(kf);
        let size = l << k;
        let claimed = kf.add(&p_claim, &kf.mul(&lambda, &q_claim));
        let (sc, r) = if bulk_ok && size >= 2 * KL {
            layer_sumcheck_bulk(kf, trees, k, &zeta, &lambda, &claimed, tr)
        } else {
            let eq = eq_table(kf, &zeta);
            assert_eq!(eq.len(), size);
            let mut p0 = Vec::with_capacity(size);
            let mut p1 = Vec::with_capacity(size);
            let mut q0 = Vec::with_capacity(size);
            let mut q1 = Vec::with_capacity(size);
            for i in 0..size {
                let (e, b) = (i >> k, i & ((1 << k) - 1));
                p0.push(trees[e].p_elem(k + 1, 2 * b));
                p1.push(trees[e].p_elem(k + 1, 2 * b + 1));
                q0.push(trees[e].q_elem(k + 1, 2 * b));
                q1.push(trees[e].q_elem(k + 1, 2 * b + 1));
            }
            let lam = lambda.clone();
            let combine =
                move |kfi: &KField, v: &[KElem]| -> KElem { layer_combine(kfi, v, &lam) };
            sumcheck_prove(kf, vec![eq, p0, p1, q0, q1], 3, &combine, tr)
        };
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

/// U-K9: extract the split child tables of layer k (over l trees, element
/// idx = e << k | b) into packed work tables, without KElem churn.
pub(crate) fn extract_children(trees: &[FracTree], k: usize) -> (KTab, KTab, KTab, KTab) {
    let l = trees.len();
    let size = l << k;
    let mask = (1usize << k) - 1;
    let mut p0 = KTab::zeroed(size);
    let mut p1 = KTab::zeroed(size);
    let mut q0 = KTab::zeroed(size);
    let mut q1 = KTab::zeroed(size);
    let one = {
        let mut e = vec![0u64; super::kfield::K_DEG];
        e[0] = 1;
        e
    };
    for idx in 0..size {
        let (e, b) = (idx >> k, idx & mask);
        if trees[e].is_neutral() {
            // (p, q) = (0, 1) at every child: p0/p1 stay zero.
            q0.set(idx, &one);
            q1.set(idx, &one);
            continue;
        }
        let (sp, sq) = (trees[e].p_layer(k + 1), trees[e].q_layer(k + 1));
        p0.copy_elem(idx, sp, 2 * b);
        p1.copy_elem(idx, sp, 2 * b + 1);
        q0.copy_elem(idx, sq, 2 * b);
        q1.copy_elem(idx, sq, 2 * b + 1);
    }
    (p0, p1, q0, q1)
}

/// [UPERF2-A] extract_children with block-granular deinterleave (each
/// tree's child layer maps to a contiguous, block-aligned output range
/// once 2^k >= KL: output block m of tree e is the deinterleave of source
/// blocks 2m, 2m+1 of the tree's layer k+1) and a deterministic thread
/// split over (tree, block-chunk). Identical tables to extract_children;
/// the sub-block sizes take the element path.
pub(crate) fn extract_children_par(
    trees: &[FracTree],
    k: usize,
    fill_neutral: bool,
) -> (KTab, KTab, KTab, KTab) {
    if (1usize << k) < KL {
        return extract_children(trees, k);
    }
    let l = trees.len();
    let size = l << k;
    let per_tree_blk = (1usize << k) / KL;
    let mut p0 = KTab::zeroed(size);
    let mut p1 = KTab::zeroed(size);
    let mut q0 = KTab::zeroed(size);
    let mut q1 = KTab::zeroed(size);
    // Neutral instances: p0/p1 are already zero; q0/q1 = 1 over the
    // slice when the caller wants them materialized (the pad-skipping
    // descent leaves them untouched — never read — so the zero pages of
    // the fresh tables stay unmapped).
    let one_blk: [u32; super::kfield::KBLK] = {
        let mut b = [0u32; super::kfield::KBLK];
        for l in 0..KL {
            b[l] = 1;
        }
        b
    };
    let job = |e: usize, m0: usize, p0c: &mut [u32], p1c: &mut [u32], q0c: &mut [u32], q1c: &mut [u32]| {
        let n = p0c.len() / super::kfield::KBLK;
        if trees[e].is_neutral() {
            if fill_neutral {
                for i in 0..n {
                    q0c[i * super::kfield::KBLK..(i + 1) * super::kfield::KBLK].copy_from_slice(&one_blk);
                    q1c[i * super::kfield::KBLK..(i + 1) * super::kfield::KBLK].copy_from_slice(&one_blk);
                }
            }
            return;
        }
        let (sp, sq) = (trees[e].p_layer(k + 1), trees[e].q_layer(k + 1));
        super::kfield::k9_deint_blocks(&sp.d, m0, n, p0c, p1c);
        super::kfield::k9_deint_blocks(&sq.d, m0, n, q0c, q1c);
    };
    let ch = super::kfield::k9_extract_chunk_blk().min(per_tree_blk).max(1);
    let words = ch * super::kfield::KBLK;
    if super::kfield::k9_threads() <= 1 {
        for e in 0..l {
            let base = e * per_tree_blk * super::kfield::KBLK;
            for m0 in (0..per_tree_blk).step_by(ch) {
                let n = ch.min(per_tree_blk - m0);
                let (w0, w1) = (base + m0 * super::kfield::KBLK, base + (m0 + n) * super::kfield::KBLK);
                job(e, m0, &mut p0.d[w0..w1], &mut p1.d[w0..w1], &mut q0.d[w0..w1], &mut q1.d[w0..w1]);
            }
        }
        return (p0, p1, q0, q1);
    }
    super::kfield::k9_pooled_pub(|| {
        use rayon::prelude::*;
        p0.d.par_chunks_mut(words)
            .zip(p1.d.par_chunks_mut(words))
            .zip(q0.d.par_chunks_mut(words))
            .zip(q1.d.par_chunks_mut(words))
            .enumerate()
            .for_each(|(c, (((p0c, p1c), q0c), q1c))| {
                // chunk c covers global blocks [c*ch, c*ch + n): tree e = block / per_tree_blk
                let g0 = c * ch;
                let e = g0 / per_tree_blk;
                let m0 = g0 % per_tree_blk;
                job(e, m0, p0c, p1c, q0c, q1c);
            });
    });
    (p0, p1, q0, q1)
}

/// U-K9: one layer's sumcheck on the bulk kernels — bit-identical
/// transcript to the sumcheck_prove path (same round-poly values, same
/// absorb ordering; g(1) is produced through the round identity
/// g(0) + g(1) = C, which the honest evaluation satisfies exactly).
/// QL := lambda*q0 is carried as a sixth table so each node's wire is
/// three products (see kfield.rs round_g_body).
fn layer_sumcheck_bulk(
    kf: &KField,
    trees: &[FracTree],
    k: usize,
    zeta: &[KElem],
    lambda: &KElem,
    claimed: &KElem,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    let kern = kf.kern.as_ref().expect("bulk layer requires the kernel");
    let n_rounds = zeta.len();
    let mut eq = kf.kt_eq_table(zeta);
    let (mut p0, mut p1, mut q0, mut q1) = extract_children(trees, k);
    debug_assert_eq!(eq.n, p0.n);
    let mut ql = kf.kt_mul_fixed(&q0, lambda);
    let mut c_run = claimed.clone();
    let mut rounds = Vec::with_capacity(n_rounds);
    let mut point = Vec::with_capacity(n_rounds);
    for _t in 0..n_rounds {
        let n_cur = eq.n;
        let g: Vec<KElem> = if n_cur >= 2 * KL {
            let nodes = [0u64, 2, 3];
            let mut acc_lo = vec![0u64; nodes.len() * 31 * KL];
            let mut acc_hi = vec![0u64; nodes.len() * 31 * KL];
            super::kfield::k9_round_g_blocks(
                kern, &eq.d, &p0.d, &p1.d, &q0.d, &q1.d, &ql.d, n_cur / 2 / KL, &nodes, None,
                &mut acc_lo, &mut acc_hi,
            );
            let gs: Vec<KElem> = (0..nodes.len())
                .map(|ni| {
                    kf.kt_round_g_finalize(
                        &acc_lo[ni * 31 * KL..(ni + 1) * 31 * KL],
                        &acc_hi[ni * 31 * KL..(ni + 1) * 31 * KL],
                    )
                })
                .collect();
            let g1 = kf.sub(&c_run, &gs[0]);
            vec![gs[0].clone(), g1, gs[1].clone(), gs[2].clone()]
        } else {
            let tabs = vec![
                eq.to_kelems(),
                p0.to_kelems(),
                p1.to_kelems(),
                q0.to_kelems(),
                q1.to_kelems(),
            ];
            let lam = lambda.clone();
            round_poly(kf, &tabs, 3, &move |kfi: &KField, v: &[KElem]| {
                layer_combine(kfi, v, &lam)
            })
        };
        debug_assert_eq!(kf.add(&g[0], &g[1]), c_run, "bulk round identity broke");
        tr.absorb_k(kf, "round-poly", &g);
        let r = tr.challenge_k(kf);
        c_run = lagrange_eval(kf, &g, &r);
        kf.kt_fold_inplace(&mut eq, &r);
        kf.kt_fold_inplace(&mut p0, &r);
        kf.kt_fold_inplace(&mut p1, &r);
        kf.kt_fold_inplace(&mut q0, &r);
        kf.kt_fold_inplace(&mut q1, &r);
        kf.kt_fold_inplace(&mut ql, &r);
        rounds.push(g);
        point.push(r);
    }
    let final_evals = vec![eq.get(0), p0.get(0), p1.get(0), q0.get(0), q1.get(0)];
    (SumcheckProof { rounds, final_evals }, point)
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
