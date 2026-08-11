// [UAGB1-BK] U-AG-B1 wave 4, lane BK: the FOLDED MASKED DESCENT layout
// layer — per-table fold groups for the pass's table-membership facts
// (SiLU LookupAt + RangeLookup), realized in the shape M4_LOOKUP_DESIGN
// Section 5 DECIDED (per-instance trees at a shared depth, eq-batched
// into ONE masked descent per side) and AGGREGATION_FOLDING_DESIGN's
// IXF index extension applied at the descent (the instance axis is the
// extension: e_bits = ceil(log2 trees), pads = neutral trees — the
// 12->16-class ruling).
//
// WHY NOT the monolithic concatenated tree (the [MODEL] kel-fit form at
// dw 25/26): the engine's own frozen gates forbid it at 125M scale —
// (1) LKP-2 `gkr::ceiling_gate_ok` (N * 64 < q) caps any one LogUp
// instance at depth <= 24 at q31; (2) the AUDITED packed-table cap
// `kfield::K9_MAX_LEAVES = 2^25` (raisable only with a new
// integer-bound proof — explicitly not this lane). Both gates are
// consumed here as-is; the eq-batched form keeps every per-tree
// multiset far under the ceiling and every tree far under the cap,
// and keeps PER-TREE root cross-checks (isolation: a bad value
// rejects at its own pair, the M4 Section 5 point).
//
// ALIGNED LEAF LAYOUT (the load-bearing convention): member columns
// are placed at power-of-2-ALIGNED leaf blocks, one block per member,
// rows padded to a power-of-2 column stride (768 -> 1024). Under the
// engine's joint index convention (instance HIGH bits, position LOW
// bits, child bit 0 — masked_rounds_scalar `(e, b) = (i >> j, ...)`),
// every leaf-pin weight then FACTORS as
//     inst_eq(z*_high)[tree] * block_prefix(z*_mid) * eq_rows * eq_cols
// — exactly the product-form `pass_agg::ClaimContrib` shape, so the
// descent-end P/Q pins land in the composed batched opening with NO
// new claim machinery and NO materialized 2^22-entry eq tables.
// Blinder positions (`gkr_masked::blinder_positions`: n/2-4, n-4,
// n/2-2, n-3) never collide with data: block placement is capped at
// half - 4 per half and blocks are >= 16 leaves, so an aligned block
// boundary can never enter the last 4 slots of a half.

use super::gkr::FracTree;
use super::gkr_masked::{blinder_positions, BlinderSet};
use super::kfield::{KElem, KField};

// ---------------------------------------------------------------------------
// Pair planning: aligned block packing over blinded trees.

/// One member column of a fold pair: a (rows x cols) committed tensor
/// slice looked up against the pair's table.
#[derive(Clone, Copy, Debug)]
pub struct MemberShape {
    pub rows: usize,
    pub cols: usize,
}

impl MemberShape {
    pub fn cols_pad(&self) -> usize {
        self.cols.next_power_of_two()
    }
    pub fn n_el(&self) -> usize {
        self.rows * self.cols
    }
    /// log2 of the aligned leaf footprint (rows and cols_pad are
    /// powers of two by the pass shapes; asserted).
    pub fn block_pow(&self) -> u32 {
        let fp = self.rows * self.cols_pad();
        assert!(self.rows.is_power_of_two(), "row count must be a power of two");
        assert!(fp.is_power_of_two());
        fp.trailing_zeros()
    }
}

/// One placed member block: member index, tree index, aligned base.
#[derive(Clone, Copy, Debug)]
pub struct MemberBlock {
    pub member: usize,
    pub tree: usize,
    pub base: usize,
}

/// The per-pair tree plan: `n_real` real trees of the given depth,
/// padded to `l` (power of two) with neutral (0,1) trees; e_bits =
/// log2(l) instance-extension variables (the IXF axis).
#[derive(Clone, Debug)]
pub struct PairTreePlan {
    pub depth: usize,
    pub l: usize,
    pub n_real: usize,
    pub e_bits: usize,
    pub blocks: Vec<MemberBlock>,
}

/// The pair's tree depth rule: max member footprint + 2 (each half of
/// a tree holds one max-footprint block below the blinder area; the
/// derivation side of freeze row UAGB1-BK-2).
pub fn pair_depth(members: &[MemberShape]) -> usize {
    let maxp = members.iter().map(|m| m.block_pow()).max().expect("pair has members") as usize;
    maxp + 2
}

/// Greedy aligned packer: members in descending footprint order, each
/// tree offering two half-regions ([0, half-4) and [half, n-4)); a
/// member goes at the current aligned cursor of the first half with
/// room. Alignment invariant: cursors only ever advance by footprints
/// >= every remaining member's footprint, so every base is aligned to
/// its own block.
pub fn plan_pair_trees(members: &[MemberShape], depth: usize) -> PairTreePlan {
    let n = 1usize << depth;
    let half = n / 2;
    let mut order: Vec<usize> = (0..members.len()).collect();
    order.sort_by_key(|&i| std::cmp::Reverse(members[i].block_pow()));
    // Per tree: (lower cursor, upper cursor).
    let mut cursors: Vec<(usize, usize)> = Vec::new();
    let mut blocks = Vec::with_capacity(members.len());
    for &mi in &order {
        let fp = 1usize << members[mi].block_pow();
        let mut placed = false;
        for (ti, cur) in cursors.iter_mut().enumerate() {
            if cur.0 + fp <= half - 4 {
                blocks.push(MemberBlock { member: mi, tree: ti, base: cur.0 });
                cur.0 += fp;
                placed = true;
                break;
            }
            if half + cur.1 + fp <= n - 4 {
                blocks.push(MemberBlock { member: mi, tree: ti, base: half + cur.1 });
                cur.1 += fp;
                placed = true;
                break;
            }
        }
        if !placed {
            let ti = cursors.len();
            cursors.push((fp, 0));
            blocks.push(MemberBlock { member: mi, tree: ti, base: 0 });
            assert!(fp <= half - 4, "member footprint exceeds tree half at depth {depth}");
        }
    }
    let n_real = cursors.len();
    let l = n_real.next_power_of_two();
    blocks.sort_by_key(|b| b.member);
    // Blinder-collision paranoia (the cap rule already excludes it).
    let bp = blinder_positions(n);
    for b in &blocks {
        let fp = 1usize << members[b.member].block_pow();
        for &p in &bp {
            assert!(p < b.base || p >= b.base + fp, "block/blinder collision");
        }
    }
    PairTreePlan { depth, l, n_real, e_bits: l.trailing_zeros() as usize, blocks }
}

// ---------------------------------------------------------------------------
// Blinded aligned trees.

/// The aligned witness leaf offset of element f of a member placed at
/// `base`: row-padded placement base + (f / cols) * cols_pad +
/// (f % cols). Public layout — pin builders and tree builder share it.
pub fn aligned_leaf(base: usize, cols: usize, cols_pad: usize, f: usize) -> usize {
    base + (f / cols) * cols_pad + (f % cols)
}

/// Build one blinded ALIGNED witness tree: fused member columns at
/// their aligned blocks, dummies (0, 1) elsewhere, the pair's blinder
/// set at the frozen positions. `slots` = (shape, base, fused column).
pub fn aligned_witness_tree(
    kf: &KField,
    alpha: &KElem,
    slots: &[(MemberShape, usize, &[KElem])],
    depth: usize,
    bl: &BlinderSet,
) -> FracTree {
    let n = 1usize << depth;
    let mut p = vec![kf.zero(); n];
    let mut q = vec![kf.one(); n];
    for (shape, base, col) in slots {
        assert_eq!(col.len(), shape.n_el());
        let cp = shape.cols_pad();
        for (f, w) in col.iter().enumerate() {
            let i = aligned_leaf(*base, shape.cols, cp, f);
            p[i] = kf.one();
            q[i] = kf.sub(alpha, w);
        }
    }
    super::gkr_masked::install_blinders(kf, &mut p, &mut q, bl);
    super::gkr::build_tree(kf, p, q)
}

/// A neutral pad tree: all-dummy (0, 1) leaves, no blinders (a pad
/// slot carries no witness and no randomizable layer-1 values — its
/// derived root is the public (0, 1)).
pub fn neutral_tree(kf: &KField, depth: usize) -> FracTree {
    let n = 1usize << depth;
    super::gkr::build_tree(kf, vec![kf.zero(); n], vec![kf.one(); n])
}

// ---------------------------------------------------------------------------
// Factored leaf-pin weights (never a materialized joint eq table).

/// eq weight of the single index `idx` under point bits `z` (little-
/// endian: bit t of idx pairs with z[t]).
pub fn point_weight(kf: &KField, z: &[KElem], idx: usize) -> KElem {
    let mut acc = kf.one();
    for (t, zt) in z.iter().enumerate() {
        let f = if (idx >> t) & 1 == 1 { zt.clone() } else { kf.sub(&kf.one(), zt) };
        acc = kf.mul(&acc, &f);
    }
    acc
}

/// The block prefix: product over tree bits >= block_pow of the
/// base's bit pattern — the scalar factor multiplying the in-block
/// eq_rows x eq_cols product for a member at `base`.
pub fn block_prefix(kf: &KField, z_tree: &[KElem], base: usize, block_pow: u32) -> KElem {
    let mut acc = kf.one();
    for t in (block_pow as usize)..z_tree.len() {
        let f = if (base >> t) & 1 == 1 { z_tree[t].clone() } else { kf.sub(&kf.one(), &z_tree[t]) };
        acc = kf.mul(&acc, &f);
    }
    acc
}

/// Sum of the first `k` entries of the eq table over `z` (streamed —
/// the partial-hypercube indicator used by H at truncated columns).
pub fn eq_prefix_sum(kf: &KField, z: &[KElem], k: usize) -> KElem {
    let tab = super::gkr::eq_table(kf, z);
    let mut acc = kf.zero();
    for e in tab.iter().take(k) {
        acc = kf.add(&acc, e);
    }
    acc
}

/// The witness-side public leaf constants of one pair at the descent
/// endpoint z* (length depth + e_bits): per REAL tree i —
/// (inst weight, per-block (prefix, eq_rows table, eq_cols table)),
/// the honest-indicator H, the blinder eq weights, and the all-dummy
/// complement D = 1 - H - sum(blinder weights). Pad trees contribute
/// to D automatically (their whole slot space is dummy).
pub struct WitnessPinPublics {
    /// Per real tree: eq weight of the instance coordinate.
    pub inst_w: Vec<KElem>,
    /// Per block (member order): the scalar prefix (inst_w folded in).
    pub block_scale: Vec<KElem>,
    /// H(z*): sum of L over every honest position.
    pub h: KElem,
    /// Per real tree: [tL, tR, f0, f1] leaf weights (inst_w folded in).
    pub blinder_w: Vec<[KElem; 4]>,
}

pub fn witness_pin_publics(
    kf: &KField,
    zstar: &[KElem],
    members: &[MemberShape],
    plan: &PairTreePlan,
    eq_rows_sum: &dyn Fn(usize) -> KElem,
    eq_cols_sum: &dyn Fn(usize) -> KElem,
) -> WitnessPinPublics {
    let (z_tree, z_inst) = zstar.split_at(plan.depth);
    let inst_w: Vec<KElem> = {
        let tab = super::gkr::eq_table(kf, z_inst);
        (0..plan.n_real).map(|i| tab[i].clone()).collect()
    };
    let mut block_scale = vec![kf.zero(); members.len()];
    let mut h = kf.zero();
    for b in &plan.blocks {
        let m = &members[b.member];
        let pre = block_prefix(kf, z_tree, b.base, m.block_pow());
        let scale = kf.mul(&inst_w[b.tree], &pre);
        // H contribution: scale * (sum eq_rows) * (sum eq_cols over
        // the REAL columns).
        let hc = kf.mul(&kf.mul(&scale, &eq_rows_sum(b.member)), &eq_cols_sum(b.member));
        h = kf.add(&h, &hc);
        block_scale[b.member] = scale;
    }
    let bp = blinder_positions(1usize << plan.depth);
    let blinder_w: Vec<[KElem; 4]> = (0..plan.n_real)
        .map(|i| {
            let mut out = [kf.zero(), kf.zero(), kf.zero(), kf.zero()];
            for (k, &pos) in bp.iter().enumerate() {
                out[k] = kf.mul(&inst_w[i], &point_weight(kf, z_tree, pos));
            }
            out
        })
        .collect();
    WitnessPinPublics { inst_w, block_scale, h, blinder_w }
}

/// Table-side publics at the table descent endpoint: per real tree the
/// instance weight, the position weights of the table rows (shared row
/// placement `gkr_masked::table_row_positions`), the table indicator
/// ht, the fused-row fold ft = sum_j w_j * table[j], and the blinder
/// weights. The TABLE VALUES are the statement's (the verifier folds
/// its own member table — the wrong-table reject face).
pub struct TablePinPublics {
    pub inst_w: Vec<KElem>,
    /// Per table row j: leaf weight of row j (tree bits only — shared
    /// by every instance; instance weight applied by the caller).
    pub row_w: Vec<KElem>,
    /// sum_j row_w[j] (tree part of ht).
    pub row_sum: KElem,
    /// sum_j row_w[j] * table_k[j] (tree part of ft).
    pub row_fold: KElem,
    pub blinder_w: Vec<[KElem; 4]>,
}

pub fn table_pin_publics(
    kf: &KField,
    zstar: &[KElem],
    table_k: &[KElem],
    dt: usize,
    n_real: usize,
) -> TablePinPublics {
    let (z_tree, z_inst) = zstar.split_at(dt);
    let inst_w: Vec<KElem> = {
        let tab = super::gkr::eq_table(kf, z_inst);
        (0..n_real).map(|i| tab[i].clone()).collect()
    };
    let n = 1usize << dt;
    let tpos = super::gkr_masked::table_row_positions(table_k.len(), n);
    let tree_tab = super::gkr::eq_table(kf, z_tree);
    let row_w: Vec<KElem> = tpos.iter().map(|&p| tree_tab[p].clone()).collect();
    let mut row_sum = kf.zero();
    let mut row_fold = kf.zero();
    for (w, t) in row_w.iter().zip(table_k.iter()) {
        row_sum = kf.add(&row_sum, w);
        row_fold = kf.add(&row_fold, &kf.mul(w, t));
    }
    let bp = blinder_positions(n);
    let blinder_w: Vec<[KElem; 4]> = (0..n_real)
        .map(|i| {
            let mut out = [kf.zero(), kf.zero(), kf.zero(), kf.zero()];
            for (k, &pos) in bp.iter().enumerate() {
                out[k] = kf.mul(&inst_w[i], &tree_tab[pos].clone());
            }
            out
        })
        .collect();
    TablePinPublics { inst_w, row_w, row_sum, row_fold, blinder_w }
}

// ---------------------------------------------------------------------------
// Derived transcript expectation (the BA rule: the engine's own
// structural counter, never the [MODEL] kel fit).

/// Counted descent-pair bytes at 64 B/K-element: witness side at
/// (depth, e_bits, l instances) + table side at (dt, e_bits, l).
pub fn pair_expected_bytes(depth: usize, dt: usize, e_bits: usize, l: usize) -> usize {
    let (_, kw) = super::gkr_masked::masked_transcript_totals(depth, e_bits, l);
    let (_, kt) = super::gkr_masked::masked_transcript_totals(dt, e_bits, l);
    64 * (kw + kt)
}

/// The LKP-2 ceiling assertion for one tree's multiset (per m column):
/// re-exported so derive-time gates cite one copy of the law.
pub fn tree_ceiling_ok(n_used: usize, q: u64) -> bool {
    super::gkr::ceiling_gate_ok(n_used as u64, q)
}
