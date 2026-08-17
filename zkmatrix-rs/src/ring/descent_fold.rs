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
/// [UPERF2-E] rides `aligned_witness_tree_fn` (the streamed, threaded
/// packed builder) with the columns read in place; the scalar-oracle
/// field and `oracle_mode()` take the pre-change boxed body inside it.
pub fn aligned_witness_tree(
    kf: &KField,
    alpha: &KElem,
    slots: &[(MemberShape, usize, &[KElem])],
    depth: usize,
    bl: &BlinderSet,
) -> FracTree {
    for (shape, _, col) in slots {
        assert_eq!(col.len(), shape.n_el());
    }
    let fns: Vec<Box<dyn Fn(usize) -> KElem + Sync + '_>> =
        slots.iter().map(|(_, _, col)| Box::new(move |f: usize| col[f].clone()) as Box<dyn Fn(usize) -> KElem + Sync>).collect();
    let slot_fns: Vec<(MemberShape, usize, &(dyn Fn(usize) -> KElem + Sync))> =
        slots.iter().zip(fns.iter()).map(|((s, b, _), f)| (*s, *b, f.as_ref())).collect();
    aligned_witness_tree_fn(kf, alpha, &slot_fns, depth, bl)
}

/// [UPERF2-E] The STREAMED aligned witness tree: `slots` = (shape, base,
/// value(f)) with value(f) the fused K-value of member element f (row-
/// major) — generated on the fly by `gkr::build_aligned_witness_tree`'s
/// threaded positional fill, so neither a boxed leaf vector nor a boxed
/// member column is ever materialized (the callers pass closures over
/// their integer layer data). Same leaf sequence as the boxed body (member
/// blocks never overlap each other or a blinder position: plan_pair_trees
/// asserts both) — bit-identical trees; under the scalar field /
/// `oracle_mode()` the builder materializes the boxed leaves and runs
/// `build_tree`, the pre-change body.
pub fn aligned_witness_tree_fn(
    kf: &KField,
    alpha: &KElem,
    slots: &[(MemberShape, usize, &(dyn Fn(usize) -> KElem + Sync))],
    depth: usize,
    bl: &BlinderSet,
) -> FracTree {
    let n = 1usize << depth;
    let blocks: Vec<super::gkr::AlignedBlock> = slots
        .iter()
        .map(|(shape, base, value)| super::gkr::AlignedBlock {
            base: *base,
            rows: shape.rows,
            cols: shape.cols,
            cols_pad: shape.cols_pad(),
            value: *value,
        })
        .collect();
    let blp = blinder_positions(n);
    let blinders: Vec<(usize, KElem, KElem)> = [&bl.tl, &bl.tr, &bl.f0, &bl.f1]
        .into_iter()
        .enumerate()
        .map(|(k, b)| (blp[k], b.a.clone(), b.u.clone()))
        .collect();
    super::gkr::build_aligned_witness_tree(kf, alpha, depth, &blocks, &blinders)
}

/// A neutral pad tree: all-dummy (0, 1) leaves, no blinders (a pad
/// slot carries no witness and no randomizable layer-1 values — its
/// derived root is the public (0, 1)). [UPERF2-E] delegates to lane A's
/// `gkr::build_neutral_tree`: the compact `FracTree::Neutral` on the
/// fast packed path (no allocation), the materialized boxed leaves +
/// `build_tree` for the scalar-oracle field and under `oracle_mode()` —
/// bit-identical trees either way.
pub fn neutral_tree(kf: &KField, depth: usize) -> FracTree {
    super::gkr::build_neutral_tree(kf, depth)
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
