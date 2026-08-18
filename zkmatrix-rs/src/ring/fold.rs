// U-AG-B1 lane BE (wave 2): INDEX-EXTENSION FOLDING (IXF) — the fold
// machinery that turns k layers of per-layer sumcheck instances into
// ONE folded instance family over a layer-index-extended MLE space,
// per the frozen F-IF1 interface (AGGREGATION_FOLDING_DESIGN.md
// Section 2) and its soundness verification (AGGREGATION_FOLDING_
// SOUNDNESS.md Section 8, AFS-L8; FD-L1/FD-L2 are the lemmas the two
// builders below instantiate).
//
// THE 12->16 RULING this module implements (report: UAGB1_FOLD_REPORT
// .md Section 1; freeze rows: freeze_check_uagb1_be in ring_matmul.rs;
// every delta DERIVED, none extrapolated — the BA rule):
//
// - lambda(k) = ceil(log2 k) MLE index variables; at the 125M pass
//   k = 12 -> lambda = 4 covering 16 slots with 4 PADDED slots.
//   F-IF1.0's "5" is the 32-layer 7B instantiation of the same
//   layer-count-generic interface (FD-L1's proof is explicit:
//   "variable-count-generic"; FD Section 10.3 commissions the 125M
//   rows at "12 layers, index pad to 16"). No frozen constant moves.
//
// - PADDED SLOTS are vacuous by the engine's EXISTING zero-extension
//   discipline (the D-1/D2 precedent for inner 768 -> 1024): the
//   prover's sumcheck tables extend the layer axis with ZEROS,
//   commitments carry ONLY the k real layers, and every verifier-side
//   functional (the pins) is position-determined over committed
//   indices only — the pad region contributes zero to every
//   functional by construction. I-3 slot-completeness (R-FC4) is
//   KEPT: the sumcheck runs over the full 2^lambda slot space —
//   nothing is sampled or skipped; pads are inside the enumeration,
//   provably-zero by the pin grounding (a prover who smuggles content
//   into a pad slot passes its own sumcheck but fails the committed
//   functional — the battery's padded-slot tamper leg).
//
// - NORM LAW: one-time, no per-step growth (F-IF1.5 verbatim);
//   N_limb(pass) = k * N_limb(layer) counts COMMITTED limb-rings, so
//   the 125M one-time cost is log2 sqrt(12) = 1.79 b on the real
//   inventory, bounded by the conservative index-space figure
//   log2 sqrt(16) = 2.00 b, both strictly under the FROZEN 7B row
//   FC2-law (log2 sqrt(32) = 2.5 b — unmoved).
//
// - ZERO FOLD MESSAGES: the only additions over a per-layer instance
//   are the lambda extra index coordinates in the outer draw (the
//   CRB-N1 class, drawn with rx/ry AFTER h0 binds statement +
//   segment map + every commitment) and lambda extra sumcheck rounds
//   per folded instance (CRB-N2 class, in-round). No accumulator, no
//   cross-terms, no witness-multiplying challenge (AFS V1/V2).
//
// The degree-SCHEDULED sumcheck below exists because FD-L2's joint
// matmul form is degree (3, 2): degree 3 in the lambda layer rounds
// (eq, A, B each multilinear in l) and 2 in the inner rounds (the eq
// factor is constant within an inner-variable pair). Variable order
// follows the house convention (variable 0 = lowest bit, bound
// first): inner/position bits LOW, layer bits HIGH (the IA-O1-1
// alignment CR-L5 slices by), so the schedule is [2; lk] ++ [3;
// lambda] for the joint matmul and [3; n + lambda] for the stacked
// zero-check (the eq kernel spans every variable there).

use super::kfield::{KElem, KField};
use super::sumcheck::{LkpTranscript, SumcheckProof, fold, lagrange_eval, round_poly};

// ---------------------------------------------------------------------------
// The index-extension layout.

/// The IXF index extension for a k-layer pass: lambda index variables
/// covering 2^lambda slots, slots >= layers, pads = slots - layers
/// vacuous slots (zero-extension discipline; see module header).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct IxfLayout {
    pub layers: usize,
    pub lambda: usize,
    pub slots: usize,
    pub pads: usize,
}

/// Derive the layout from the layer count (>= 1). lambda = ceil(log2
/// layers); the 125M point is layers = 12 -> lambda = 4, slots = 16,
/// pads = 4 (the ruling's pinned row); the 7B point is layers = 32 ->
/// lambda = 5, slots = 32, pads = 0 (F-IF1.0's frozen instantiation,
/// reproduced not moved).
pub fn ixf_layout(layers: usize) -> IxfLayout {
    assert!(layers >= 1, "a pass has at least one layer");
    let lambda = usize::BITS as usize - (layers - 1).leading_zeros() as usize;
    let slots = 1usize << lambda;
    IxfLayout { layers, lambda, slots, pads: slots - layers }
}

/// FD-L2's per-round degree schedule for the joint matmul fold:
/// [2; lk] (inner rounds — eq constant in the bound pair) then
/// [3; lambda] (layer rounds — eq, A, B all multilinear in l).
pub fn matmul_degree_schedule(lk: usize, lambda: usize) -> Vec<usize> {
    let mut d = vec![2usize; lk];
    d.extend(std::iter::repeat_n(3usize, lambda));
    d
}

/// FD-L1's schedule for the stacked zero-check: the eq kernel spans
/// (position, layer), so every round is degree 3 (eq * (Y*U - Z)).
pub fn zerocheck_degree_schedule(n_pos_vars: usize, lambda: usize) -> Vec<usize> {
    vec![3usize; n_pos_vars + lambda]
}

/// Expand a layer-space table over the joint (position-low, layer-
/// high) index space: out[l * nb + b] = layer_tab[l]. The joint
/// matmul's eq(r_l, l) factor rides the sumcheck in exactly this form
/// (FD-L2: the eq factor MUST be inside — the naive outside-fold is
/// incomplete AND unsound; the battery exhibits both directions).
pub fn expand_layer_table(kf: &KField, layer_tab: &[KElem], nb: usize) -> Vec<KElem> {
    let mut out = Vec::with_capacity(layer_tab.len() * nb);
    for v in layer_tab {
        for _ in 0..nb {
            out.push(v.clone());
        }
    }
    let _ = kf;
    out
}

// ---------------------------------------------------------------------------
// The degree-scheduled sumcheck (house core with a per-round degree).
//
// Identical transcript discipline to sumcheck.rs (absorb the round
// polynomial, THEN draw the round challenge — the E3-N4 edge), with
// the round polynomial degree taken from a public schedule instead of
// one uniform degree. The schedule is a pure function of the public
// layout (never prover-chosen); the verifier enforces it row by row.

/// Prove sum over the hypercube of combine(tables...) = claimed under
/// the public per-round `degrees` schedule (degrees.len() = variable
/// count; round t sends degrees[t] + 1 evaluations).
pub fn ixf_sumcheck_prove(
    kf: &KField,
    mut tables: Vec<Vec<KElem>>,
    degrees: &[usize],
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    let n = tables[0].len().trailing_zeros() as usize;
    assert_eq!(degrees.len(), n, "degree schedule covers every variable");
    assert!(tables.iter().all(|t| t.len() == 1 << n));
    let mut rounds = Vec::with_capacity(n);
    let mut point = Vec::with_capacity(n);
    for &deg in degrees {
        let g = round_poly(kf, &tables, deg, combine);
        tr.absorb_k(kf, "ixf-round-poly", &g);
        let r = tr.challenge_k(kf);
        tables = tables.iter().map(|t| fold(kf, t, &r)).collect();
        rounds.push(g);
        point.push(r);
    }
    let final_evals: Vec<KElem> = tables.into_iter().map(|mut t| t.remove(0)).collect();
    (SumcheckProof { rounds, final_evals }, point)
}

// ---------------------------------------------------------------------------
// [UPERF2-D] The claim layer's fixed combine shapes + the packed prover.
//
// The pass claim layer (bg_pass_run / bk_pass_run) drives every ixf
// instance with one of three combine closures; naming the shape lets the
// prover run the rounds on kfield.rs's lane-packed bulk kernel
// (`kt_ixf_round_poly`, deterministic ZK_THREADS chunks) and fold the
// packed tables in place (`kt_fold_par`), instead of the boxed scalar
// `round_poly` + `fold` loop (which allocates ~80 KElems per pair per
// round). Same field values by exact K arithmetic (the shape's `eval`
// IS the closure the callers used; the [UPERF2-D] battery pins the
// three shapes oracle vs fast at ZK_THREADS 1/2/7); the transcript
// sees identical bytes. `ixf_sumcheck_prove` (the scalar path) stays
// the oracle: `ZK_UPERF_ORACLE=1`, a non-kernel modulus, or a table
// below two pair-blocks route there.

/// The claim layer's combine shapes (v0 is always the eq factor).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum IxfCombine {
    /// v0 * v1 * v2 — the joint matmul (eq * A * B).
    Prod3,
    /// v0 * (v1 * v2 - v3) — the Hadamard zero-check.
    Had,
    /// v0 * ((v1 - v4 * v2) - v3) — the requant zero-check.
    Rq,
}

impl IxfCombine {
    /// The scalar closure of the shape (verbatim the pass callers').
    pub fn eval(&self, kf: &KField, v: &[KElem]) -> KElem {
        match self {
            IxfCombine::Prod3 => kf.mul(&kf.mul(&v[0], &v[1]), &v[2]),
            IxfCombine::Had => kf.mul(&v[0], &kf.sub(&kf.mul(&v[1], &v[2]), &v[3])),
            IxfCombine::Rq => kf.mul(&v[0], &kf.sub(&kf.sub(&v[1], &kf.mul(&v[4], &v[2])), &v[3])),
        }
    }

    pub fn n_tables(&self) -> usize {
        match self {
            IxfCombine::Prod3 => 3,
            IxfCombine::Had => 4,
            IxfCombine::Rq => 5,
        }
    }

    fn kernel_id(&self) -> u8 {
        match self {
            IxfCombine::Prod3 => super::kfield::IXF_KIND_PROD3,
            IxfCombine::Had => super::kfield::IXF_KIND_HAD,
            IxfCombine::Rq => super::kfield::IXF_KIND_RQ,
        }
    }
}

/// Smallest table (elements) the packed prover takes; below it (or under
/// the oracle) the scalar path runs.
const IXF_PACKED_MIN: usize = 64;

// ---------------------------------------------------------------------------
// [UPERF2-O] The claim layer's TABLE POOL.
//
// Lane L's finding at 12x512 (U_PERF2_GPU2_REPORT.md Section 5.3): with the
// folds' arithmetic at 0.04 s on the device, `d.cl-folds` was still ~5 s and
// `d.cl-tables` ~5 s — the packed factor tables (4-5 x 1 GB per zero-check
// instance, 5 instances) are freshly calloc'd (first-touch faults inside the
// builders) and given back (the shrink's mremap + the drop's munmap inside
// the fold loop) every instance: ~25 GB of pages faulted in and freed. The
// pool below keeps the FULL-SIZE buffers of one instance for the next: the
// builders (`IxfTable::eq / scalar_table / layer_expand`) and the packed
// prover's fold scratch take from it, and the prover returns its buffers
// (never shrunk while the pool is open) at the end. Allocation plumbing
// only: every stored value and every proof byte is unchanged; the pass
// drivers open a scope around the claim layer (`IxfPoolScope::open`) and
// the held pages are released when it closes (before the descent phase,
// whose peak the box's RAM is sized to). Peak held = (nt + 1) x the biggest
// table (the prover keeps ONE rotating scratch for all its tables) — at
// 12x512 6 x 1 GB, against today's 5.5 x 1 GB peak inside the biggest
// instance. Outside a scope the pool is off (buffers are freed as before).

struct IxfPool {
    on: bool,
    bufs: Vec<Vec<u32>>,
}

static IXF_POOL: std::sync::Mutex<IxfPool> = std::sync::Mutex::new(IxfPool { on: false, bufs: Vec::new() });
static IXF_POOL_HITS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static IXF_POOL_MISSES: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
static IXF_POOL_HELD_PEAK: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
/// Buffers below this are never pooled (1 MiB of u32).
const IXF_POOL_MIN_WORDS: usize = 1 << 18;

/// The scope guard: the pool is ON while a scope is open; closing the LAST
/// scope releases every held buffer. `ZK_IXF_POOL=0` keeps it off (the
/// one-binary A/B — memory plumbing, no value changes).
pub struct IxfPoolScope {
    was_on: bool,
}

impl IxfPoolScope {
    pub fn open() -> IxfPoolScope {
        let enabled = std::env::var("ZK_IXF_POOL").map(|v| v != "0").unwrap_or(true);
        let mut p = IXF_POOL.lock().expect("ixf pool lock");
        let was_on = p.on;
        if enabled {
            p.on = true;
        }
        IxfPoolScope { was_on }
    }
}

impl Drop for IxfPoolScope {
    fn drop(&mut self) {
        if !self.was_on {
            ixf_pool_clear();
            IXF_POOL.lock().expect("ixf pool lock").on = false;
        }
    }
}

/// True while a scope is open (the builders write EVERY word of a pooled
/// buffer they hand out — a pooled buffer is dirty).
pub fn ixf_pool_on() -> bool {
    IXF_POOL.lock().expect("ixf pool lock").on
}

/// A buffer of at least `words` u32 (len == words; CONTENTS UNSPECIFIED)
/// from the pool when it is open and has one (best fit: the smallest held
/// buffer of capacity >= words), else a fresh zeroed allocation (calloc:
/// zero pages faulted in on first touch — today's behavior).
pub(crate) fn ixf_pool_take(words: usize) -> Vec<u32> {
    use std::sync::atomic::Ordering::Relaxed;
    let taken: Option<Vec<u32>> = {
        let mut p = IXF_POOL.lock().expect("ixf pool lock");
        if !p.on || words < IXF_POOL_MIN_WORDS {
            None
        } else {
            let mut best: Option<usize> = None;
            for (i, b) in p.bufs.iter().enumerate() {
                if b.capacity() >= words && best.is_none_or(|j| b.capacity() < p.bufs[j].capacity()) {
                    best = Some(i);
                }
            }
            best.map(|i| p.bufs.swap_remove(i))
        }
    };
    match taken {
        Some(mut b) => {
            IXF_POOL_HITS.fetch_add(1, Relaxed);
            // No memset. INVARIANT: every buffer that enters the pool was
            // born as `vec![0u32; n]` (len == capacity, fully initialized:
            // this module's takes, kfield's `k9_fresh_words` / arena, the
            // fold's `resize` from empty, k9.rs's handover `vec![0u32; ..]`)
            // and has only been truncated / swapped / written / resized
            // WITHIN its capacity since (takes are served at capacity >=
            // words, so no caller's `resize` reallocates), so [0, capacity)
            // is initialized memory and `set_len` is sound. The callers
            // write every word they read anyway.
            if b.len() != words {
                // SAFETY: see the invariant above (u32 is Copy; the bytes in
                // [len, words) were initialized when the buffer was born and
                // are never de-initialized by truncate).
                unsafe { b.set_len(words) };
            }
            b
        }
        None => {
            if IXF_POOL.lock().expect("ixf pool lock").on && words >= IXF_POOL_MIN_WORDS {
                IXF_POOL_MISSES.fetch_add(1, Relaxed);
            }
            vec![0u32; words]
        }
    }
}

/// Return a buffer to the pool (kept at its capacity when the pool is open
/// and the buffer is large; dropped otherwise).
pub(crate) fn ixf_pool_give(v: Vec<u32>) {
    use std::sync::atomic::Ordering::Relaxed;
    if v.capacity() < IXF_POOL_MIN_WORDS {
        return;
    }
    let mut p = IXF_POOL.lock().expect("ixf pool lock");
    if !p.on {
        drop(p);
        drop(v);
        return;
    }
    p.bufs.push(v);
    let held: usize = p.bufs.iter().map(|b| b.capacity()).sum();
    IXF_POOL_HELD_PEAK.fetch_max(held as u64, Relaxed);
}

/// Release every held buffer (RSS drops to the live set).
pub fn ixf_pool_clear() {
    let bufs = std::mem::take(&mut IXF_POOL.lock().expect("ixf pool lock").bufs);
    drop(bufs);
}

/// (buffers held now, MiB held now, peak MiB held, takes served from the
/// pool, takes that allocated fresh while the pool was open) — observation
/// only.
pub fn ixf_pool_stats() -> (usize, usize, usize, u64, u64) {
    use std::sync::atomic::Ordering::Relaxed;
    let p = IXF_POOL.lock().expect("ixf pool lock");
    let held: usize = p.bufs.iter().map(|b| b.capacity()).sum();
    (p.bufs.len(), held >> 18, IXF_POOL_HELD_PEAK.load(Relaxed) as usize >> 18, IXF_POOL_HITS.load(Relaxed), IXF_POOL_MISSES.load(Relaxed))
}

/// A `KTab` of n elements over a pooled (dirty) or fresh (zero) buffer of
/// exactly the packed size. Callers write every element they will read;
/// when n is not a multiple of KL the last block is zeroed here so the
/// trailing-lane padding invariant holds either way.
pub(crate) fn ixf_ktab_take(n: usize) -> super::kfield::KTab {
    use super::kfield::{KBLK, KL};
    let words = n.div_ceil(KL) * KBLK;
    let mut d = ixf_pool_take(words);
    if n % KL != 0 && words >= KBLK {
        for w in &mut d[words - KBLK..] {
            *w = 0;
        }
    }
    super::kfield::KTab { n, d }
}

/// Hand a `KTab`'s buffer back to the pool (the KTab's own Drop would give
/// it to kfield's arena, which is off by default and drops it).
pub(crate) fn ixf_ktab_give(mut t: super::kfield::KTab) {
    ixf_pool_give(std::mem::take(&mut t.d));
}

/// The kernel thread pool for the claim layer's own splits (the bin's
/// table builders): `ZK_THREADS` from `eval_proof::threads()`, inline at 1.
pub fn ixf_pooled<R: Send>(f: impl FnOnce() -> R + Send) -> R {
    super::kfield::k9_pooled_pub(f)
}

pub fn ixf_threads() -> usize {
    super::eval_proof::threads()
}

/// The oracle body of `ixf_sumcheck_prove_kind` — verbatim the pre-change
/// scalar prover with the shape's closure.
pub fn ixf_sumcheck_prove_kind_ref(
    kf: &KField,
    tables: Vec<Vec<KElem>>,
    degrees: &[usize],
    kind: IxfCombine,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    ixf_sumcheck_prove(kf, tables, degrees, &|kf: &KField, v: &[KElem]| kind.eval(kf, v), tr)
}

/// `ixf_sumcheck_prove` for a named combine shape: the packed bulk prover
/// when the kernel is live (identical transcript bytes), the scalar
/// oracle otherwise or under `ZK_UPERF_ORACLE=1`.
pub fn ixf_sumcheck_prove_kind(
    kf: &KField,
    tables: Vec<Vec<KElem>>,
    degrees: &[usize],
    kind: IxfCombine,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    assert_eq!(tables.len(), kind.n_tables(), "ixf: table count vs combine shape");
    if super::eval_proof::oracle_mode() || kf.kern.is_none() || tables[0].len() < IXF_PACKED_MIN {
        return ixf_sumcheck_prove_kind_ref(kf, tables, degrees, kind, tr);
    }
    let n = tables[0].len().trailing_zeros() as usize;
    assert_eq!(degrees.len(), n, "degree schedule covers every variable");
    assert!(tables.iter().all(|t| t.len() == 1 << n));
    let packed: Vec<super::kfield::KTab> = {
        let _t = super::ct_engine::prof::timer(super::ct_engine::prof::D_CL_PACK); // observation only
        let mut p = Vec::with_capacity(tables.len());
        for t in tables {
            p.push(kf.kt_pack(&t));
            // the boxed table is dropped here, one at a time (peak = boxed + one packed)
        }
        p
    };
    ixf_sumcheck_prove_packed(kf, packed, degrees, kind, tr)
}

/// [UPERF2-D] A factor table in the bulk layout, built DIRECTLY packed by
/// the claim layer's table builders (64 B per element, one allocation)
/// instead of as a boxed `Vec<KElem>` (~170 B per element, one heap
/// object each) that the prover would then pack. Available only when the
/// bulk kernel is live (`IxfTable::available(kf)`); the callers keep the
/// boxed builders as the oracle path.
pub struct IxfTable(pub(crate) super::kfield::KTab);

impl IxfTable {
    /// True iff packed tables can be built for this field (the kernel gate
    /// AND not the oracle routing).
    pub fn available(kf: &KField) -> bool {
        kf.kern.is_some() && !super::eval_proof::oracle_mode()
    }

    pub fn len(&self) -> usize {
        self.0.n
    }

    pub fn is_empty(&self) -> bool {
        self.0.n == 0
    }

    /// n zero elements.
    pub fn zeros(n: usize) -> IxfTable {
        IxfTable(super::kfield::KTab::zeroed(n))
    }

    pub fn from_kelems(kf: &KField, v: &[KElem]) -> IxfTable {
        IxfTable(kf.kt_pack(v))
    }

    pub fn get(&self, i: usize) -> KElem {
        self.0.get(i)
    }

    pub fn to_kelems(&self) -> Vec<KElem> {
        self.0.to_kelems()
    }

    /// The packed eq table over a point (threaded doubling; the same
    /// values as `gkr::eq_table`). [UPERF2-O] Built into a pooled buffer
    /// when the claim layer's pool is open (every entry is written by the
    /// doubling; kfield's `kt_eq_table_par` body, verbatim, over that
    /// buffer); the kfield builder otherwise.
    pub fn eq(kf: &KField, point: &[KElem]) -> IxfTable {
        use super::kfield::{kop, k9_eq_double_par, KL, K9_MAX_LEAVES};
        if !ixf_pool_on() {
            return IxfTable(kf.kt_eq_table_par(point));
        }
        let kern = kf.kern.as_ref().expect("IxfTable::eq requires the bulk kernel");
        assert!(point.len() <= K9_MAX_LEAVES.trailing_zeros() as usize, "K9 eq table cap exceeded");
        let mut t = ixf_ktab_take(1usize << point.len());
        t.set(0, &kf.one());
        let mut half = 1usize;
        for zv in point {
            let zbar = kf.sub(&kf.one(), zv);
            if half >= KL {
                k9_eq_double_par(kern, &mut t.d, half / KL, &kop(&zbar), &kop(zv));
            } else {
                for i in 0..half {
                    let a = t.get(i);
                    t.set(i + half, &kf.mul(&a, zv));
                    t.set(i, &kf.mul(&a, &zbar));
                }
            }
            half *= 2;
        }
        IxfTable(t)
    }

    /// `expand_layer_table` packed: out[l * nb + b] = layer_tab[l].
    /// [UPERF2-O] Every element written (pooled buffer safe).
    pub fn layer_expand(layer_tab: &[KElem], nb: usize) -> IxfTable {
        use super::kfield::{KBLK, KL, K_DEG};
        let n = layer_tab.len() * nb;
        let mut t = ixf_ktab_take(n);
        if nb % KL == 0 {
            for (l, v) in layer_tab.iter().enumerate() {
                let mut blk = [0u32; KBLK];
                for j in 0..K_DEG {
                    debug_assert!(v[j] < (1 << 31), "packed KTab expects canonical q31-class values");
                    for la in 0..KL {
                        blk[j * KL + la] = v[j] as u32;
                    }
                }
                let (b0, b1) = ((l * nb / KL) * KBLK, ((l + 1) * nb / KL) * KBLK);
                for m in (b0..b1).step_by(KBLK) {
                    t.d[m..m + KBLK].copy_from_slice(&blk);
                }
            }
        } else {
            for (l, v) in layer_tab.iter().enumerate() {
                for b in 0..nb {
                    t.set(l * nb + b, v);
                }
            }
        }
        IxfTable(t)
    }

    /// A table of BASE-FIELD scalars (K-elements with only coordinate 0
    /// set — the stacked witness tables `kf.scale(v, one)` = embed(v)):
    /// element i = embed(f(i)) with f returning a CANONICAL residue in
    /// [0, q). Filled per whole-block chunk on the ZK_THREADS pool
    /// (positional; identical for any thread count). [UPERF2-O] Every
    /// word of a block is written (coefficients 1..15 zero) so a pooled
    /// (dirty) buffer is safe.
    pub fn scalar_table(kf: &KField, n: usize, f: impl Fn(usize) -> u64 + Sync) -> IxfTable {
        use super::kfield::{KBLK, KL};
        let q = kf.zq.q;
        let mut t = ixf_ktab_take(n);
        let nblk = n / KL;
        let full = nblk * KBLK;
        {
            let d = &mut t.d[..full];
            let chunk_blk = 512usize;
            let fill = |c: usize, dc: &mut [u32]| {
                let i0 = c * chunk_blk * KL;
                let nb = dc.len() / KBLK;
                for b in 0..nb {
                    let blk = &mut dc[b * KBLK..(b + 1) * KBLK];
                    for l in 0..KL {
                        let v = f(i0 + b * KL + l);
                        debug_assert!(v < q, "scalar_table expects canonical residues");
                        blk[l] = v as u32; // coefficient 0 of lane l
                    }
                    for w in &mut blk[KL..] {
                        *w = 0; // coefficients 1..15 of every lane
                    }
                }
            };
            if super::kfield::k9_threads() > 1 && nblk > chunk_blk {
                super::kfield::k9_pooled_pub(|| {
                    use rayon::prelude::*;
                    d.par_chunks_mut(chunk_blk * KBLK).enumerate().for_each(|(c, dc)| fill(c, dc));
                });
            } else {
                for (c, dc) in d.chunks_mut(chunk_blk * KBLK).enumerate() {
                    fill(c, dc);
                }
            }
        }
        for i in nblk * KL..n {
            let mut e = kf.zero();
            e[0] = f(i);
            t.set(i, &e);
        }
        IxfTable(t)
    }
}

/// `ixf_sumcheck_prove_kind` on tables built directly packed (`IxfTable`).
pub fn ixf_sumcheck_prove_tables(
    kf: &KField,
    tables: Vec<IxfTable>,
    degrees: &[usize],
    kind: IxfCombine,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    assert_eq!(tables.len(), kind.n_tables(), "ixf: table count vs combine shape");
    if super::eval_proof::oracle_mode() || tables[0].len() < IXF_PACKED_MIN {
        // The scalar path (a caller that built packed tables under the
        // oracle routing, or a tiny instance): unpack and run the oracle.
        let boxed: Vec<Vec<KElem>> = tables.iter().map(|t| t.to_kelems()).collect();
        return ixf_sumcheck_prove_kind_ref(kf, boxed, degrees, kind, tr);
    }
    ixf_sumcheck_prove_packed(kf, tables.into_iter().map(|t| t.0).collect(), degrees, kind, tr)
}

/// The packed prover proper (tables already in the bulk layout — the
/// callers that build packed tables directly enter here). Rounds run
/// on the bulk kernel while every table holds >= 2 pair-blocks; the
/// remaining rounds finish on the boxed scalar path (identical values).
pub(crate) fn ixf_sumcheck_prove_packed(
    kf: &KField,
    mut packed: Vec<super::kfield::KTab>,
    degrees: &[usize],
    kind: IxfCombine,
    tr: &mut LkpTranscript,
) -> (SumcheckProof, Vec<KElem>) {
    use super::ct_engine::prof;
    let n = packed[0].n.trailing_zeros() as usize;
    assert_eq!(degrees.len(), n, "degree schedule covers every variable");
    assert!(packed.iter().all(|t| t.n == 1 << n));
    let kid = kind.kernel_id();
    let mut rounds = Vec::with_capacity(n);
    let mut point = Vec::with_capacity(n);
    // [UPERF2-O] ONE rotating fold scratch for every table (the out-of-place
    // fold swaps the old table buffer in as the next table's scratch), from
    // the claim layer's pool when it is open (a full-size buffer, kept at
    // full size — no shrink, no fault, no munmap per round; returned at the
    // end) — else a fresh buffer sized by the first fold and shrunk after
    // each round's folds to what the next round needs (lane D's discipline:
    // a table never holds > 1.5x its size; peak = nt tables + one half).
    let pooled = ixf_pool_on();
    let mut scratch: Vec<u32> = if pooled { ixf_pool_take(packed[0].d.len()) } else { Vec::new() };
    let mut t_idx = 0usize;
    while t_idx < n && packed[0].n >= 2 * super::kfield::KL {
        let deg = degrees[t_idx];
        let g = {
            let _t = prof::timer(prof::D_CL_ROUNDS); // observation only
            let views: Vec<&super::kfield::KTab> = packed.iter().collect();
            kf.kt_ixf_round_poly(&views, deg, kid)
        };
        tr.absorb_k(kf, "ixf-round-poly", &g);
        let r = tr.challenge_k(kf);
        {
            let _t = prof::timer(prof::D_CL_FOLDS); // observation only
            for p in packed.iter_mut() {
                kf.kt_fold_par(p, &mut scratch, &r);
            }
            if !pooled {
                // Memory: keep only what the next round's folds need (a
                // shrinking realloc — no copy for large chunks).
                let next_words = (packed[0].n / 2 / super::kfield::KL) * super::kfield::KBLK;
                scratch.truncate(next_words);
                scratch.shrink_to_fit();
                for p in packed.iter_mut() {
                    p.d.shrink_to_fit();
                }
            }
        }
        rounds.push(g);
        point.push(r);
        t_idx += 1;
    }
    // Scalar tail (tables below two pair-blocks): the boxed path, verbatim.
    let mut tables: Vec<Vec<KElem>> = packed.iter().map(|p| p.to_kelems()).collect();
    for p in packed {
        ixf_ktab_give(p); // [UPERF2-O] back to the pool (dropped when it is off)
    }
    ixf_pool_give(scratch);
    let combine = |kf: &KField, v: &[KElem]| kind.eval(kf, v);
    while t_idx < n {
        let deg = degrees[t_idx];
        let g = round_poly(kf, &tables, deg, &combine);
        tr.absorb_k(kf, "ixf-round-poly", &g);
        let r = tr.challenge_k(kf);
        tables = tables.iter().map(|t| fold(kf, t, &r)).collect();
        rounds.push(g);
        point.push(r);
        t_idx += 1;
    }
    let final_evals: Vec<KElem> = tables.into_iter().map(|mut t| t.remove(0)).collect();
    (SumcheckProof { rounds, final_evals }, point)
}

/// Verify the scheduled round chain. Returns (final point, reduced
/// claim) — the CALLER must still ground proof.final_evals (publicly
/// recomputable factors checked directly; committed factors through
/// the pin machinery). None = reject.
pub fn ixf_sumcheck_verify(
    kf: &KField,
    degrees: &[usize],
    claimed: &KElem,
    proof: &SumcheckProof,
    combine: &dyn Fn(&KField, &[KElem]) -> KElem,
    tr: &mut LkpTranscript,
) -> Option<(Vec<KElem>, KElem)> {
    if proof.rounds.len() != degrees.len() {
        return None;
    }
    let mut c = claimed.clone();
    let mut point = Vec::with_capacity(degrees.len());
    for (g, &deg) in proof.rounds.iter().zip(degrees.iter()) {
        if g.len() != deg + 1 {
            return None;
        }
        if kf.add(&g[0], &g[1]) != c {
            return None;
        }
        tr.absorb_k(kf, "ixf-round-poly", g);
        let r = tr.challenge_k(kf);
        c = lagrange_eval(kf, g, &r);
        point.push(r);
    }
    if combine(kf, &proof.final_evals) != c {
        return None;
    }
    Some((point, c))
}

// ---------------------------------------------------------------------------
// The norm-law arithmetic (the derived 125M-shape rows' derivation
// side; the pins live in freeze_check_uagb1_be, both directions).
//
// Chain exactly as frozen (aggregation_freeze_rows.py Section 5 /
// FD Section 10.1; engine constants from ring::digits):
//   N_limb(e0) = sum_c n_c * max(1, ceil(bits_c / e0))
//   gamma_z    = OP_CONC * 2^(e0-1) * sqrt(N_limb * D)
//   headroom   = log2(gamma_max_exact) - log2(gamma_z)

/// One committed value class of a fold group: ring count at 128
/// coefficients per ring, value bit width.
#[derive(Clone, Copy, Debug)]
pub struct FoldClass {
    pub rings: usize,
    pub bits: u32,
}

/// The frozen limb chain (FD 10.1 form).
pub fn n_limb_rings(classes: &[FoldClass], e0: u32) -> usize {
    classes
        .iter()
        .map(|c| c.rings * std::cmp::max(1, c.bits.div_ceil(e0) as usize))
        .sum()
}

/// log2 gamma_z of a fold group at base e0 (level-0 pass fold norm,
/// F-IF1.5 / PARAMS 3.2; OP_CONC and the formula from ring::digits so
/// the engine has exactly one copy of the law).
pub fn gamma_z_log2(classes: &[FoldClass], e0: u32) -> f64 {
    super::digits::fold_norm_gamma(e0, n_limb_rings(classes, e0)).log2()
}

/// Headroom (bits) of a fold group at base e0 against the exact-digit
/// gate at q31 (gamma_max = (q/8)/58.8 ~ 2^22.12 — ring::digits'
/// frozen form, freeze row UAGB1-1b / H-gate-ed).
pub fn headroom_bits(classes: &[FoldClass], e0: u32, q: u64) -> f64 {
    super::digits::gamma_max_exact(q).log2() - gamma_z_log2(classes, e0)
}

/// The one-time pass law: folding x layer-classes costs log2 sqrt(x)
/// bits, once, with NO per-step growth (F-IF1.5; FS V3; the frozen 7B
/// row FC2-law pins x = 32 -> 2.5 b). The 125M rows pin x = 12 (real
/// inventory, 1.792 b) and x = 16 (conservative index-space bound,
/// 2.0 b).
pub fn one_time_law_bits(x: usize) -> f64 {
    0.5 * (x as f64).log2()
}

/// The law as an identity on the chain itself: gamma_z(k copies of the
/// classes) - gamma_z(classes) == log2 sqrt(k) EXACTLY (the sqrt(N)
/// factor is the only k-dependence at fixed e0). Used by the freeze
/// row's derivation side.
pub fn law_delta_bits(classes: &[FoldClass], e0: u32, k: usize) -> f64 {
    let scaled: Vec<FoldClass> =
        classes.iter().map(|c| FoldClass { rings: c.rings * k, bits: c.bits }).collect();
    gamma_z_log2(&scaled, e0) - gamma_z_log2(classes, e0)
}

/// The descent-depth ruling (FD-L3 / F-IF1.8 at the 125M shape):
/// dw_pass = dw_layer + lambda. At the 125M lookup witness (2048 x 512
/// = 2^20 elements per layer -> the RECORDED dw 21 rig point;
/// PROOF_BYTE_LEDGER 0.1) and lambda = 4: dw_pass = 25 — ONE step past
/// the last recorded kel point (dw 24), which is why F-O2 is
/// 7B-freeze-blocking, not PoC-blocking (AZB_BATTERY_PLAN Section 7).
/// kel is the [MODEL] fit, carried verbatim; this lane does NOT build
/// the folded descent (the rig needs the multi-wave C2 lift — see the
/// ledger WILL-NOT-DO fence).
pub fn kel_fit_dw(dw: usize) -> usize {
    2 * dw * dw + 11 * dw + 235
}
