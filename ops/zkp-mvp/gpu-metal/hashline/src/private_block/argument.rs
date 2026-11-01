//! The twenty-three masked sumchecks of the private block profile, written
//! ONCE and driven from both sides (`Side::Prove` / `Side::Verify`): the slot
//! order, every challenge, every table, every polynomial, every PCS claim and
//! every M functional come from the same code, so the two sides cannot build
//! different claim lists.
//!
//! One slot, both sides:
//!   absorb slot index -> draw c (zero: refuse) -> absorb the ONE published
//!   scalar (`s + c G` for a private sum, `c G` for a public-zero slot, the
//!   batched `Gamma_host` for a host) -> masked rounds -> one extension round
//!   per private factor family (two for the bilinear score / PV slots) ->
//!   absorb the masked terminals.
//! The verifier never sees a plane evaluation, a claimed scalar sum, a helper
//! sum or a histogram: terminals are `(1 - e) T(p) + e (R_re + u R_im)(tail p)`
//! with a pair reserved for that one site, and the mask evaluation g(rho) it
//! derives is closed by the single M opening.
//!
//! CONSTRUCTION PREMISE (not re-derived here): every slot polynomial has a
//! public factor (an eq, a public table, or the other side's zero extension)
//! in every monomial, so `poly(extensions) = 0` and the extension round is
//! consistent. `define` is written to keep that true; a new term without a
//! public factor would make honest proofs fail, not leak.

use super::layout::*;
use super::shape::Shape;
use super::{AttentionPublic, FeedForwardPublic};
#[path = "argument_accuracy.rs"]
mod accuracy;
use crate::field::{Fp, Fp2};
// `fold_cols_i8` folds an (input, output) matrix over its SECOND index, which
// is what the three feed-forward matrices need: the kernel stores them
// (input, output) row-major and the statement digest covers the same words the
// caller authenticates (T2 section C.1 and decision 10).
use crate::mle::{eq_point, eq_table_msb, eval_mle_ext, fold_cols_i8, fold_rows_i8};
use crate::pcs::{Slice, ZClaim, ZPart};
use crate::sumcheck::{self, masked_terminal, CfsMask, SumcheckProof};
use crate::transcript::Transcript;
use crate::zk::{extension, MaskFunctional};

/// which hiding commitment a private table lives in
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Cm {
    A = 0,
    H = 1,
    In = 2,
    Out = 3,
}

/// one coordinate of a plane's claim point, as a function of the slot's challenges
#[derive(Clone, Debug)]
pub(crate) enum Coord {
    Rho(usize),
    /// `1 - rho_k` (the RoPE partner half)
    Flip(usize),
    Fixed(Fp2),
}

pub(crate) struct Priv {
    pub cm: Cm,
    /// (element offset, coefficient): one slice for A, (re, 1) and (im, u) for H
    pub slices: Vec<(usize, Fp2)>,
    pub log: usize,
    pub coords: Vec<Coord>,
    /// the site's reserved pair is rows (mask_row, mask_row + 1)
    pub mask_row: usize,
    /// the extension round that masks this table (the bilinear slots have two)
    pub ext_round: usize,
}

pub(crate) enum Tab {
    /// eq(point, x[start .. start + |point|]), constant in the other variables
    Eq { point: Vec<Fp2>, start: usize },
    Pub(Vec<Fp2>),
    Priv(Priv),
}

pub(crate) type Poly = Box<dyn Fn(&[Fp2]) -> Fp2 + Send + Sync>;

// **NATIVE R9, TEST BUILDS ONLY: the LAPSED constructions D30 forbids**,
// switched on both sides of a test (the prover and the verifier in one
// thread) so that a mutation test can show its cheat PASSES against the
// lapse and is CAUGHT by the construction as built. A release build has no
// switch: `dd_lapse` is the constant `false` there.
#[cfg(test)]
thread_local! {
    static DD_LAPSE: std::cell::Cell<u8> = const { std::cell::Cell::new(0) };
}
/// CHECK.md D-3: the division clauses gated off the LAST dictionary slot of
/// every row (an unconstrained position)
pub(crate) const DD_LAPSE_GATE_LAST_SLOT: u8 = 1;
/// CHECK.md D-4: the row key dropped from the tuple
pub(crate) const DD_LAPSE_DROP_KEY: u8 = 2;
/// D30 condition 3: the dictionary's two LogUp columns left out of the single
/// value-0 sum claim
pub(crate) const DD_LAPSE_OUT_OF_SUM: u8 = 4;

/// TEST ONLY: set the lapse bits (0 = the construction as built)
#[cfg(test)]
pub(crate) fn set_dd_lapse(v: u8) {
    DD_LAPSE.with(|c| c.set(v));
}

/// whether a lapse bit is set (always `false` in a release build)
pub(crate) fn dd_lapse(bit: u8) -> bool {
    #[cfg(test)]
    {
        DD_LAPSE.with(|c| c.get()) & bit != 0
    }
    #[cfg(not(test))]
    {
        let _ = bit;
        false
    }
}
type GroupPoly = std::sync::Arc<dyn Fn(usize, &[Fp2]) -> Fp2 + Send + Sync>;

pub(crate) struct SlotDef {
    pub slot: usize,
    pub tabs: Vec<Tab>,
    pub poly: Poly,
    /// Experimental prover arithmetic only; the original polynomial remains
    /// the verifier/extension oracle. No extra transcript or blinding draws.
    groups: Option<(Vec<sumcheck::EqualityGroup>, GroupPoly)>,
    /// (hosted private slot, nu * kappa)
    pub hosted: Vec<(usize, Fp2)>,
    /// [ZK60-METAL M3] the slot's polynomial as generated MSL plus its coefficient
    /// buffer, built from the slot's expression IR on a TWIN transcript (so no
    /// challenge or absorb of the real transcript moves). Only set on the prove
    /// side with HL_GPU=1; `None` keeps the CPU evaluator.
    #[cfg(feature = "gpu-metal")]
    pub(crate) metal: Option<(String, Vec<Fp2>, Vec<bool>)>,
    /// **STEP C.** The slot schedule this definition was built against, so
    /// that `run_slot` reads the SHAPE's `(main, ext, degree)` and terminal
    /// counts instead of the toy constants. At the toy it is `Shape::toy()`
    /// and `sh.slots() == SLOTS` is asserted by `Layout::new`.
    pub sh: Shape,
}

#[derive(Clone, Debug, Default)]
pub(crate) struct SlotProof {
    /// the ONE published scalar of the slot (always mask-bearing)
    pub scalar: Fp2,
    pub sc: SumcheckProof,
    /// the masked terminals of the private tables, in table order
    pub terms: Vec<Fp2>,
}

pub(crate) struct ProverData<'a> {
    /// committed data of A, H, the input endpoint, the output endpoint
    pub data: [&'a [Fp]; 4],
    pub masks: &'a [CfsMask],
}

pub(crate) enum Side<'a> {
    Prove { pd: ProverData<'a>, out: Vec<SlotProof> },
    Verify { slots: &'a [SlotProof] },
}

#[derive(Default)]
pub(crate) struct Acc {
    pub cs: Vec<Fp2>,
    pub scalars: Vec<Fp2>,
    /// claims per commitment, indexed by `Cm`
    pub claims: [Vec<ZClaim>; 4],
    pub fs: Vec<MaskFunctional>,
    pub host_fs: Vec<MaskFunctional>,
    /// the absorb sequence, label by label (prover and verifier must agree)
    pub order: Vec<String>,
}

pub(crate) struct Ctx<'a> {
    pub accuracy:Option<&'a crate::private_block::accuracy_public::AccuracyPublic>,
    pub lay: &'a Layout,
    pub public: &'a AttentionPublic,
    pub ff: &'a FeedForwardPublic,
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_u8: Fp2,
    pub g_exp: Fp2,
    /// `gamma * TAG_ACT`, the third table tag (T2 decision 4)
    pub g_act: Fp2,
    /// NATIVE R9 (D30, B-5): `gamma * TAG_DD`, the dictionary's tag (read by
    /// a DD profile's two dictionary relations only; no new challenge)
    pub g_dd: Fp2,
}

#[derive(Default)]
pub(crate) struct Points {
    r_t: Vec<Fp2>,
    /// norm_m's row point (SC_SSM), read again by SC_TZC's second host term
    r_t2: Vec<Fp2>,
    p_ht: Vec<Fp2>,
    lam_z: Fp2,
    r_q: Vec<Fp2>,
    pq: Vec<Fp2>,
    pk: Vec<Fp2>,
    pv: Vec<Fp2>,
    p_s: Vec<Fp2>,
    p_o: Vec<Fp2>,
    p_a: Vec<Fp2>,
    /// the row point shared by the gate and up matmuls (T2 decision 9)
    r_tf: Vec<Fp2>,
    p_g: Vec<Fp2>,
    p_u: Vec<Fp2>,
    p_z: Vec<Fp2>,
}

/// **TEST HOOK (stage 20).** The two bilinear slots' published claim points.
/// The repair of S19-F1 makes the key-value group bits SUMCHECK variables
/// under a public `eq`, and the statement a definition test has to be able to
/// make is that the `eq` carries the HEAD CHALLENGE's own group bits and not
/// a point of its own — which is what the claim point exposes: `p_s` is
/// `(r_h, r_t, r_j)` and `p_o` is `(r_t, r_h, r_i)`.
#[cfg(test)]
impl Points {
    pub(super) fn p_s(&self) -> &[Fp2] {
        &self.p_s
    }
    pub(super) fn p_o(&self) -> &[Fp2] {
        &self.p_o
    }
}

// ---------------------------------------------------------------- tables

fn claim_point(p: &Priv, rho: &[Fp2]) -> Vec<Fp2> {
    p.coords
        .iter()
        .map(|c| match c {
            Coord::Rho(k) => rho[*k],
            Coord::Flip(k) => Fp2::ONE.sub(rho[*k]),
            Coord::Fixed(f) => *f,
        })
        .collect()
}

/// T(x) = plane~(point(x)) over the slot's boolean domain: multilinear in x
/// because every challenge index occurs at most once among the coordinates.
///
/// **STAGE 28 (performance, no byte moves).** Three things changed and none of
/// them is arithmetic:
///
/// * the `(x, z)` a plane index maps to is a BIT PERMUTATION of `idx` with the
///   fixed coordinates split off, so it is precomputed for the low half and
///   the high half of `idx` and read with two lookups instead of walked
///   coordinate by coordinate (`p.log` iterations) per entry. `z` is still the
///   fixed bits in coordinate order, which is why the high part is shifted by
///   the NUMBER OF FIXED COORDINATES IN THE LOW PART and not by anything else;
/// * with no fixed coordinate `eqf` is the one-element table `[1]`, and each
///   `idx` then reaches its own `x`, so the write is the value itself — the
///   same element `ZERO + 1 * v` was;
/// * the broadcast pass is skipped when the plane depends on every variable
///   (`used` is the full mask), where it copied each entry onto itself.
///
/// Every word this returns is the word the walked form returned; the equality
/// is a test (`s28_tests`), not a claim.
pub(super) fn priv_table(p: &Priv, data: &[Fp], n_vars: usize) -> Vec<Fp2> {
    priv_table_at(p, data, n_vars, TABLE_PAR_MIN)
}

/// [ZK60-METAL M4j] the cube length from which one table is built in parallel
/// over its OUTPUT (the plain-store private table, the eq cube)
pub(super) const TABLE_PAR_MIN: usize = 1 << 16;

/// [M4j] [`priv_table`] with the parallel threshold as an argument, so a test
/// can drive both forms on the same descriptor
pub(super) fn priv_table_at(p: &Priv, data: &[Fp], n_vars: usize, par_min: usize) -> Vec<Fp2> {
    let mut out = vec![Fp2::ZERO; 1usize << n_vars];
    priv_table_fill(p, data, n_vars, &mut out, true, par_min);
    out
}

/// **[ZK60-METAL M4i]** [`priv_table`] written into `out` (`2^n_vars`
/// elements, whatever they held): the slot's device tables are built in place
/// in a pooled device buffer. The same words: a plain-store table writes every
/// element (its `idx -> x` map is a bijection onto the subsets of `used`, and
/// the broadcast fills the rest from them), and an accumulating one starts from
/// zeros, as the vector did.
pub(super) fn priv_table_into(p: &Priv, data: &[Fp], n_vars: usize, out: &mut [Fp2]) {
    assert_eq!(out.len(), 1usize << n_vars, "private block: table length");
    priv_table_fill(p, data, n_vars, out, false, TABLE_PAR_MIN);
}

/// [M4j] [`priv_table_into`] with the parallel threshold as an argument
pub(super) fn priv_table_into_at(p: &Priv, data: &[Fp], n_vars: usize, out: &mut [Fp2], par_min: usize) {
    assert_eq!(out.len(), 1usize << n_vars, "private block: table length");
    priv_table_fill(p, data, n_vars, out, false, par_min);
}

fn priv_table_fill(p: &Priv, data: &[Fp], n_vars: usize, out: &mut [Fp2], zeroed: bool, par_min: usize) {
    let fixed: Vec<Fp2> = p.coords.iter().filter_map(|c| if let Coord::Fixed(f) = c { Some(*f) } else { None }).collect();
    let eqf = eq_table_msb(&fixed);
    let mut used = 0usize;
    for c in &p.coords {
        if let Coord::Rho(k) | Coord::Flip(k) = c {
            used |= 1usize << (n_vars - 1 - *k);
        }
    }
    // the index maps, one per half of `idx`. Coordinate `j` reads bit
    // `p.log - 1 - j` of `idx`, so coordinates `0 .. hi` are the high half.
    let lo_len = p.log / 2;
    let hi_len = p.log - lo_len;
    let fixed_lo = p.coords[hi_len..].iter().filter(|c| matches!(c, Coord::Fixed(_))).count();
    let map = |coords: &[Coord], bits: usize| -> Vec<(usize, usize)> {
        (0..1usize << bits)
            .map(|v| {
                let (mut x, mut z) = (0usize, 0usize);
                for (j, c) in coords.iter().enumerate() {
                    let b = (v >> (bits - 1 - j)) & 1;
                    match c {
                        Coord::Rho(k) => x |= b << (n_vars - 1 - *k),
                        Coord::Flip(k) => x |= (1 - b) << (n_vars - 1 - *k),
                        Coord::Fixed(_) => z = (z << 1) | b,
                    }
                }
                (x, z)
            })
            .collect()
    };
    let hi_map = map(&p.coords[..hi_len], hi_len);
    let lo_map = map(&p.coords[hi_len..], lo_len);
    let lo_mask = (1usize << lo_len) - 1;
    // The write is a plain store only when NOTHING can land on the same `x`
    // twice: no fixed coordinate (so `eqf` is the one-element table `[1]`)
    // AND no challenge index used twice (which the construction promises and
    // this counts rather than assumes — a duplicate index would make two
    // `idx` share an `x`, where the old form ADDED them).
    let moving = p.coords.iter().filter(|c| !matches!(c, Coord::Fixed(_))).count();
    let simple = eqf.len() == 1 && eqf[0] == Fp2::ONE && used.count_ones() as usize == moving;
    let one_slice = if p.slices.len() == 1 && p.slices[0].1 == Fp2::ONE { Some(p.slices[0].0) } else { None };
    // [M4j] a large PLAIN-STORE table in parallel over its output. Its map
    // `idx -> x` sends idx bit `log - 1 - j` to x bit `n_vars - 1 - k` (flipped
    // for `Flip`), one coordinate per bit, so it is a bijection onto the subsets
    // of `used` and its inverse is the same bit table read the other way:
    // `out[x] = value(inverse(x & used))` is the loop's store for x within
    // `used` and the broadcast's copy for every other x. Each entry is the same
    // word, computed independently, so the order does not matter.
    if simple && out.len() >= par_min {
        use rayon::prelude::*;
        let mut bit_of: Vec<Option<(usize, usize)>> = vec![None; n_vars];
        for (j, c) in p.coords.iter().enumerate() {
            match c {
                Coord::Rho(k) => bit_of[n_vars - 1 - *k] = Some((p.log - 1 - j, 0)),
                Coord::Flip(k) => bit_of[n_vars - 1 - *k] = Some((p.log - 1 - j, 1)),
                Coord::Fixed(_) => unreachable!("a plain-store table has no fixed coordinate"),
            }
        }
        let (xlo, xhi) = (n_vars / 2, n_vars - n_vars / 2);
        let inverse_half = |shift: usize, bits: usize| -> Vec<usize> {
            (0..1usize << bits)
                .map(|v| {
                    let mut idx = 0usize;
                    for b in 0..bits {
                        if let Some((ib, flip)) = bit_of[shift + b] {
                            idx |= (((v >> b) & 1) ^ flip) << ib;
                        }
                    }
                    idx
                })
                .collect()
        };
        let (inv_lo, inv_hi) = (inverse_half(0, xlo), inverse_half(xlo, xhi));
        let lo_m = (1usize << xlo) - 1;
        const CH: usize = 1 << 14;
        out.par_chunks_mut(CH).enumerate().for_each(|(ci, ch)| {
            for (i, o) in ch.iter_mut().enumerate() {
                let xu = ((ci * CH) + i) & used;
                let idx = inv_hi[xu >> xlo] | inv_lo[xu & lo_m];
                *o = match one_slice {
                    Some(off) => Fp2::from_base(data[off + idx]),
                    None => p.slices.iter().fold(Fp2::ZERO, |a, (off, coef)| a.add(coef.mul_base(data[*off + idx]))),
                };
            }
        });
        return;
    }
    // [M4i] an accumulating table starts from zeros; a plain-store one writes
    // every element below, so a reused buffer needs no clearing
    if !zeroed && !simple {
        out.fill(Fp2::ZERO);
    }
    for idx in 0..1usize << p.log {
        let (x_hi, z_hi) = hi_map[idx >> lo_len];
        let (x_lo, z_lo) = lo_map[idx & lo_mask];
        let (x, z) = (x_hi | x_lo, (z_hi << fixed_lo) | z_lo);
        let v = match one_slice {
            Some(off) => Fp2::from_base(data[off + idx]),
            None => p.slices.iter().fold(Fp2::ZERO, |a, (off, coef)| a.add(coef.mul_base(data[*off + idx]))),
        };
        if simple {
            out[x] = v;
        } else {
            out[x] = out[x].add(eqf[z].mul(v));
        }
    }
    // broadcast over the variables the plane does not depend on
    if used != (1usize << n_vars) - 1 {
        for x in 0..out.len() {
            if x & !used != 0 {
                out[x] = out[x & used];
            }
        }
    }
}

/// **STAGE 28.** The `eq` table over the slot's cube: entry `x` is
/// `e[(x >> shift) & (|e| - 1)]`, which is each entry of the small `eq` table
/// repeated `2^shift` times and that block repeated `2^start` times. It is
/// built by filling one block and doubling it, so the cube is memory traffic
/// and not one index computation per entry. The words are the same words.
pub(super) fn eq_cube(e: &[Fp2], n_vars: usize, start: usize) -> Vec<Fp2> {
    eq_cube_at(e, n_vars, start, TABLE_PAR_MIN)
}

/// [M4j] [`eq_cube`] with the parallel threshold as an argument (a test drives
/// both forms; production passes [`TABLE_PAR_MIN`])
pub(super) fn eq_cube_at(e: &[Fp2], n_vars: usize, start: usize, par_min: usize) -> Vec<Fp2> {
    // **STAGE 29 (finding S28-R7).** The precondition, asserted rather than
    // assumed. The triple `(|point|, start, n_vars)` is SCHEDULE-DRIVEN and
    // PUBLIC — no frame and no witness can choose it — and every triple the
    // schedule builds satisfies this. On a violated one the old gather
    // produced a wrong but in-bounds cube and this build computes a wrapped
    // shift, so the two forms DIVERGE there; a panic on a public-shape
    // invariant is acceptable and a silent divergence is not.
    let bits = e.len().trailing_zeros() as usize;
    assert!(
        start + bits <= n_vars,
        "private block: eq_cube precondition start + |point| <= n_vars violated (start {start}, |point| {bits}, n_vars {n_vars})"
    );
    let len = 1usize << n_vars;
    let shift = n_vars - start - bits;
    // [ZK60-METAL M4j] a large cube in parallel over its output: entry `x` is
    // `e[(x >> shift) & (|e| - 1)]` (this function's own description), the
    // same word the block-and-double build puts there
    if len >= par_min {
        use rayon::prelude::*;
        let m = e.len() - 1;
        let mut out: Vec<Fp2> = Vec::with_capacity(len);
        out.par_extend((0..len).into_par_iter().map(|x| e[(x >> shift) & m]));
        return out;
    }
    let mut out: Vec<Fp2> = Vec::with_capacity(len);
    for v in e {
        out.resize(out.len() + (1usize << shift), *v);
    }
    while out.len() < len {
        out.extend_from_within(..);
    }
    out
}

/// **[ZK60-METAL M4i]** [`eq_cube`] written into `out` (`2^n_vars` elements,
/// whatever they held): the same block of `2^shift` copies per entry, doubled
/// to the cube, so every element is written and the words are the same.
pub(super) fn eq_cube_into(e: &[Fp2], n_vars: usize, start: usize, out: &mut [Fp2]) {
    eq_cube_into_at(e, n_vars, start, out, TABLE_PAR_MIN)
}

/// **[M5c] `eq_cube_into(&eq_table_msb(point), ..)` without the full eq table.**
/// Entry `x` is `e[y]` with `y = (x >> shift) & (2^p - 1)`, and `e[y]` is the
/// product over the point's coordinates of `r_i` or `1 - r_i`, so it splits
/// over the top and bottom halves of `y`: `e[y] = hi[y >> p_lo] * lo[y & ..]`
/// with `hi`, `lo` the eq tables of the two halves of `point` (msb first).
/// Field multiplication is exact and associative, so every entry is the same
/// element as the full table's; there is no 2^p table to allocate (macOS zeroes
/// a recycled one), fill step by step and copy, only two of about 2^(p/2)
/// entries and one multiplication per output word (`m5c_` test).
pub(super) fn eq_cube_split_into(point: &[Fp2], n_vars: usize, start: usize, out: &mut [Fp2]) {
    use rayon::prelude::*;
    let p = point.len();
    assert!(start + p <= n_vars, "private block: eq_cube precondition start + |point| <= n_vars violated (start {start}, |point| {p}, n_vars {n_vars})");
    assert_eq!(out.len(), 1usize << n_vars, "private block: table length");
    let shift = n_vars - start - p;
    let p_lo = p / 2;
    let (hi, lo) = (eq_table_msb(&point[..p - p_lo]), eq_table_msb(&point[p - p_lo..]));
    let (mask, lo_mask) = ((1usize << p) - 1, (1usize << p_lo) - 1);
    const CH: usize = 1 << 14;
    out.par_chunks_mut(CH).enumerate().for_each(|(ci, ch)| {
        for (i, o) in ch.iter_mut().enumerate() {
            let y = ((ci * CH + i) >> shift) & mask;
            *o = hi[y >> p_lo].mul(lo[y & lo_mask]);
        }
    });
}

/// [M5c] the cube size from which an eq table is split (below it the full
/// table is cheap and kept)
pub(super) const EQ_SPLIT_MIN: usize = 1 << 16;

/// [M4j] [`eq_cube_into`] with the parallel threshold as an argument
pub(super) fn eq_cube_into_at(e: &[Fp2], n_vars: usize, start: usize, out: &mut [Fp2], par_min: usize) {
    let bits = e.len().trailing_zeros() as usize;
    assert!(
        start + bits <= n_vars,
        "private block: eq_cube precondition start + |point| <= n_vars violated (start {start}, |point| {bits}, n_vars {n_vars})"
    );
    let len = 1usize << n_vars;
    assert_eq!(out.len(), len, "private block: table length");
    let shift = n_vars - start - bits;
    // [M4j] large cubes in parallel over the output, as `eq_cube_at`
    if len >= par_min {
        use rayon::prelude::*;
        let m = e.len() - 1;
        const CH: usize = 1 << 14;
        out.par_chunks_mut(CH).enumerate().for_each(|(ci, ch)| {
            for (i, o) in ch.iter_mut().enumerate() {
                *o = e[((ci * CH + i) >> shift) & m];
            }
        });
        return;
    }
    for (i, v) in e.iter().enumerate() {
        out[i << shift..(i + 1) << shift].fill(*v);
    }
    let mut have = e.len() << shift;
    while have < len {
        out.copy_within(..have, have);
        have *= 2;
    }
}

/// **STAGE 28.** `take` is `Some` on the proving path, where the slot
/// definition is owned and dead after the tables are built: a PUBLIC table is
/// then MOVED into the table set instead of copied, which at the 125M shape
/// saves a 134 MB copy per public table of the two big slots. Nothing reads a
/// `Tab::Pub` payload again on that path (the length check above happens
/// first, and every later use matches `Tab::Priv`).
fn table_of(tab: &Tab, n_vars: usize, pd: &ProverData) -> Vec<Fp2> {
    match tab {
        Tab::Eq { point, start } => eq_cube(&eq_table_msb(point), n_vars, *start),
        Tab::Pub(v) => v.clone(),
        Tab::Priv(p) => priv_table(p, pd.data[p.cm as usize], n_vars),
    }
}

fn table_of_taking(tab: &mut Tab, n_vars: usize, pd: &ProverData) -> Vec<Fp2> {
    match tab {
        Tab::Pub(v) => std::mem::take(v),
        other => table_of(other, n_vars, pd),
    }
}

/// **STAGE 29 (finding S28-R1).** The word count above which a slot's tables
/// are built in parallel, as stage 28 chose it. It is a constant of the
/// PRODUCTION call and an ARGUMENT of [`build_tables_at`], so that a test can
/// drive both branches on the same input without changing which branch any
/// other test takes.
pub(super) const TABLES_PAR_MIN: usize = 1 << 17;

/// **STAGE 29 (finding S28-R1).** The slot's table set, built once per table
/// in table order. The parallel iterator is INDEXED, so the set is the same
/// set in the same order whatever the thread count is; `par_min` is the only
/// thing that differs between the two branches and the production call passes
/// [`TABLES_PAR_MIN`].
pub(super) fn build_tables_at(tabs: &mut [Tab], n_vars: usize, pd: &ProverData, par_min: usize) -> Vec<Vec<Fp2>> {
    if tabs.len() > 1 && (tabs.len() << n_vars) >= par_min {
        use rayon::prelude::*;
        return tabs.par_iter_mut().map(|t| table_of_taking(t, n_vars, pd)).collect();
    }
    tabs.iter_mut().map(|t| table_of_taking(t, n_vars, pd)).collect()
}

/// **[ZK60-METAL M4i]** one table of the slot written into `out` (its
/// `2^n_vars` elements in the device buffer): the words [`table_of`] returns.
/// A public table is copied (its length was checked on entry to `run_slot`).
fn table_into(tab: &Tab, n_vars: usize, pd: &ProverData, out: &mut [Fp2]) {
    match tab {
        // [M5c] a large cube split over its point's halves (the same words)
        Tab::Eq { point, start } if out.len() >= EQ_SPLIT_MIN && point.len() >= 2 => eq_cube_split_into(point, n_vars, *start, out),
        Tab::Eq { point, start } => eq_cube_into(&eq_table_msb(point), n_vars, *start, out),
        Tab::Pub(v) => out.copy_from_slice(v),
        Tab::Priv(p) => priv_table_into(p, pd.data[p.cm as usize], n_vars, out),
    }
}

/// **[ZK60-METAL M4i]** [`build_tables_at`] into the slot's device tables, one
/// rayon task per table (the tables are independent; each slice is its own).
pub(super) fn build_tables_into(tabs: &[Tab], n_vars: usize, pd: &ProverData, out: Vec<&mut [Fp2]>) {
    use rayon::prelude::*;
    assert_eq!(tabs.len(), out.len(), "private block: device table count");
    if table_kind_timing() {
        // DIAGNOSTIC ONLY (HL_TABLE_KIND_TIMING=1): CPU seconds per table kind,
        // summed over the threads that built them; the words are unchanged
        tabs.par_iter().zip(out.into_par_iter()).for_each(|(t, o)| {
            let s = std::time::Instant::now();
            table_into(t, n_vars, pd, o);
            let kind = match t { Tab::Eq { .. } => 0, Tab::Pub(_) => 1, Tab::Priv(p) if p.coords.iter().any(|c| matches!(c, Coord::Fixed(_))) => 3, Tab::Priv(_) => 2 };
            TABLE_KIND_NS[kind].fetch_add(s.elapsed().as_nanos() as u64, std::sync::atomic::Ordering::Relaxed);
            TABLE_KIND_N[kind].fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        });
        return;
    }
    tabs.par_iter().zip(out.into_par_iter()).for_each(|(t, o)| table_into(t, n_vars, pd, o));
}

/// DIAGNOSTIC ONLY: per-kind table build counters (eq, public, plane, folded plane)
pub(super) static TABLE_KIND_NS: [std::sync::atomic::AtomicU64; 4] = [const { std::sync::atomic::AtomicU64::new(0) }; 4];
pub(super) static TABLE_KIND_N: [std::sync::atomic::AtomicU64; 4] = [const { std::sync::atomic::AtomicU64::new(0) }; 4];

pub(super) fn table_kind_timing() -> bool {
    static ON: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *ON.get_or_init(|| std::env::var("HL_TABLE_KIND_TIMING").map(|v| v == "1").unwrap_or(false))
}

/// DIAGNOSTIC ONLY: print and reset the per-kind counters (one line per call)
pub(crate) fn table_kind_report(label: &str) {
    if !table_kind_timing() {
        return;
    }
    let take = |a: &std::sync::atomic::AtomicU64| a.swap(0, std::sync::atomic::Ordering::Relaxed);
    let ns: Vec<u64> = TABLE_KIND_NS.iter().map(take).collect();
    let n: Vec<u64> = TABLE_KIND_N.iter().map(take).collect();
    eprintln!(
        "TABLE-KINDS {label}: cpu-seconds eq {:.4} ({} tables) | public {:.4} ({}) | plane {:.4} ({}) | folded plane {:.4} ({})",
        ns[0] as f64 * 1e-9, n[0], ns[1] as f64 * 1e-9, n[1], ns[2] as f64 * 1e-9, n[2], ns[3] as f64 * 1e-9, n[3]
    );
}

/// **FINDING S12-F2 (S12a), fixed here.** The ROW WIDTH a claim's reserved
/// pair is addressed in is the row width of the COMMITMENT the plane lives
/// in, and the two commitments do not share one: `A` and `H` are the block's
/// PCS (`log_cols`), the two endpoints are the frozen seam's (`LOG_COLS` 8,
/// carried as `endpoint_log_n`). Both are 8 at the toy, which is why the
/// module's `LOG_N` / `N` literals worked there and why no test could see the
/// difference. At the rung `log_cols` is 10 and the literals put every `A` /
/// `H` reserved pair four rows too low, which `audit_claims` refuses by name
/// ("a claim does not carry exactly its own reserved pair") — correctly:
/// that check is the whole defence against a shared pair and is never
/// relaxed.
fn row_log(sh: &Shape, cm: Cm) -> usize {
    match cm {
        Cm::A | Cm::H => sh.log_cols,
        _ => sh.endpoint_log_n,
    }
}

/// the mask pair's value at the claim's column tail
/// the coordinates of a claim point the reserved mask pair is read on (its
/// last `min(log, row_log)` entries)
fn mask_tail(sh: &Shape, p: &Priv, point: &[Fp2]) -> Vec<Fp2> {
    let logm = p.log.min(row_log(sh, p.cm));
    point[p.log - logm..].to_vec()
}

/// `(R_re + u R_im)~(tail)`, given `eq = eq_table_msb(tail)` — `mask_eval`
/// with the eq table built by the caller, so tables sharing a tail share it
fn mask_eval_eq(sh: &Shape, p: &Priv, data: &[Fp], eq: &[Fp2]) -> Fp2 {
    let (log_n, n) = (row_log(sh, p.cm), 1usize << row_log(sh, p.cm));
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let row = |r: usize| {
        data[r * n + c0..r * n + c0 + eq.len()].iter().zip(eq.iter()).fold(Fp2::ZERO, |a, (x, e)| a.add(e.mul_base(*x)))
    };
    row(p.mask_row).add(Fp2::U.mul(row(p.mask_row + 1)))
}

/// `cd * plane~(point) + cm * (R_re + u R_im)(tail point)`: data parts then the reserved pair
fn build_claim(sh: &Shape, p: &Priv, point: &[Fp2], cd: Fp2, cm: Fp2, value: Fp2) -> ZClaim {
    let (log_n, n) = (row_log(sh, p.cm), 1usize << row_log(sh, p.cm));
    let logm = p.log.min(log_n);
    let c0 = if p.log < log_n { p.slices[0].0 % n } else { 0 };
    let tail = point[p.log - logm..].to_vec();
    let mut parts: Vec<ZPart> = p
        .slices
        .iter()
        .map(|(off, coef)| ZPart { slice: Slice { offset: *off, log_size: p.log as u32 }, coef: coef.mul(cd), point: point.to_vec() })
        .collect();
    for (k, u) in [Fp2::ONE, Fp2::U].into_iter().enumerate() {
        parts.push(ZPart { slice: Slice { offset: (p.mask_row + k) * n + c0, log_size: logm as u32 }, coef: cm.mul(u), point: tail.clone() });
    }
    ZClaim { parts, value }
}

/// **STAGE 29 (finding S28-R1).** The cube size above which the claimed sum is
/// chunked and reduced on rayon, as stage 28 chose it: a constant of the
/// PRODUCTION call and an ARGUMENT of [`total_at`].
pub(super) const TOTAL_PAR_MIN: usize = 1 << 14;

/// The claimed sum over the slot's whole cube.
///
/// **STAGE 28 (performance, no byte moves).** The sum is over a FIELD: it is
/// exact and has no rounding, so grouping the terms differently cannot change
/// the element this returns — the same argument `zkp-core/src/sumcheck.rs`
/// already makes for its own parallel round ("the field sums are
/// order-independent: the values are identical"). Small cubes stay on one
/// thread, where a rayon region costs more than the work, and that threshold
/// is the only thing the parallel form decides.
fn total(tables: &[Vec<Fp2>], poly: &Poly) -> Fp2 {
    total_at(tables, poly, TOTAL_PAR_MIN)
}

/// [`total`] with the threshold as an argument, so a test can drive both
/// branches on the same cube.
pub(super) fn total_at(tables: &[Vec<Fp2>], poly: &Poly, par_min: usize) -> Fp2 {
    let len = tables[0].len();
    let part = |lo: usize, hi: usize| -> Fp2 {
        let mut row = vec![Fp2::ZERO; tables.len()];
        let mut acc = Fp2::ZERO;
        for x in lo..hi {
            for (r, t) in row.iter_mut().zip(tables.iter()) {
                *r = t[x];
            }
            acc = acc.add(poly(&row));
        }
        acc
    };
    if len <= par_min {
        return part(0, len);
    }
    use rayon::prelude::*;
    let chunk = 1024usize;
    (0..len.div_ceil(chunk))
        .into_par_iter()
        .map(|ci| part(ci * chunk, ((ci + 1) * chunk).min(len)))
        .reduce(|| Fp2::ZERO, |a, b| a.add(b))
}

fn sum_weights(sh: &Shape, slot: usize) -> Vec<Fp2> {
    let (n, e, d) = sh.slots()[slot];
    CfsMask::sum_weights(n + e, d)
}

// ---------------------------------------------------------------- one slot

// STAGE 28: `def` is `mut` because the proving path MOVES each public table
// into the table set instead of copying it (`table_of_taking`). The
// definition is owned, and nothing reads a `Tab::Pub` payload after the
// tables are built.
/// [ZK60-METAL M3] the smallest slot (tables x cube) handed to the device:
/// below it the per-round launch overhead outweighs the work.
#[cfg(feature = "gpu-metal")]
const METAL_MIN_TERMS: usize = 1 << 18;

/// **[ZK60-METAL M8]** a slot below [`METAL_MIN_TERMS`] still goes to the
/// device when its CPU rounds would cost more than this. Since M6 a batched
/// device round costs about 0.025 ms, so a small slot whose polynomial is
/// expensive pays: slot 03 at W16 8B (5 tables x 2^14) took 16 ms on the CPU
/// (`results/zk60_metal_20261031/logs/m8attr`). `HL_METAL_SMALL_SLOT_US`
/// overrides it (microseconds). Which side runs a slot changes no byte: the
/// device evaluator has the CPU's contract (M3), and the IR was checked
/// against this slot's closure before any kernel exists.
#[cfg(feature = "gpu-metal")]
const SMALL_SLOT_CPU_S: f64 = 2e-3;

/// [M8] the estimated single-thread CPU cost of a slot's rounds: `2^n
/// (degree + 1)` evaluations of `poly` (the rounds' geometric sum), each
/// timed here on eight fixed points (no proof randomness is read or drawn)
#[cfg(feature = "gpu-metal")]
fn small_slot_pays(poly: &(dyn Fn(&[Fp2]) -> Fp2 + Sync), k: usize, n: usize, degree: usize) -> bool {
    static BUDGET: std::sync::OnceLock<f64> = std::sync::OnceLock::new();
    let budget = *BUDGET.get_or_init(|| std::env::var("HL_METAL_SMALL_SLOT_US").ok().and_then(|v| v.parse::<f64>().ok()).filter(|v| v.is_finite() && *v >= 0.0).map(|us| us * 1e-6).unwrap_or(SMALL_SLOT_CPU_S));
    let pts: Vec<Vec<Fp2>> = (0..8u64).map(|s| (0..k as u64).map(|t| Fp2::new(Fp::new(s * 7919 + t * 104_729 + 1), Fp::new(t + 3 * s + 1))).collect()).collect();
    let t = std::time::Instant::now();
    let mut sink = Fp2::ZERO;
    for p in &pts {
        sink = sink.add(poly(p));
    }
    std::hint::black_box(sink);
    let per_eval = t.elapsed().as_secs_f64() / 8.0;
    ((1usize << n) * (degree + 1)) as f64 * per_eval > budget
}
/// [ZK60-METAL M4i] the slot size (tables x cube) ABOVE which a device slot's
/// tables are built in place in device memory: strictly above the test
/// oracle's `<= 2^18`, so a slot the oracle replays keeps its host tables
#[cfg(feature = "gpu-metal")]
const METAL_DIRECT_MIN: usize = 1 << 18;

pub(crate) fn run_slot(side: &mut Side, acc: &mut Acc, mut def: SlotDef, tr: &mut Transcript) -> Result<(), String> {
    let s = def.slot;
    let sh = def.sh.clone();
    let (n, ext, degree) = sh.slots()[s];
    let kind = SLOT_KINDS[s];
    let n_priv = def.tabs.iter().filter(|t| matches!(t, Tab::Priv(_))).count();
    if s != acc.cs.len() || n_priv != sh.slot_terms()[s] || (kind == SlotKind::Host) == def.hosted.is_empty() {
        return Err(format!("private block: slot {s} differs from the declared schedule"));
    }
    if def.tabs.iter().any(|t| matches!(t, Tab::Priv(p) if p.ext_round >= ext || p.coords.len() != p.log)) {
        return Err(format!("private block: slot {s} table shape"));
    }
    // **FINDING F-6.** The table-length check below lives in the `Prove` arm,
    // so on the VERIFY path a public table whose length is not the slot's cube
    // used to fall through to `eval_mle_ext`'s own `assert_eq!` — a panic
    // where a verifier owes a refusal. Public tables are shape-driven and no
    // frame can choose one, so this is robustness and not a reachable attack;
    // the refusal names a length, which is a function of the shape.
    if def.tabs.iter().any(|t| matches!(t, Tab::Pub(v) if v.len() != 1usize << n)) {
        return Err(format!("private block: slot {s} public table length"));
    }
    #[cfg(test)]
    let capture_before = if matches!(side, Side::Verify { .. }) { super::capture::checkpoint(tr) } else { None };
    // STAGE 14: the run capture's own checkpoint. `checkpoint` returns `None`
    // unless a recorder is attached, which makes the pair of lines below a
    // no-op in every other test and in every production build.
    #[cfg(test)]
    let run_capture_before = if matches!(side, Side::Verify { .. }) { super::run_capture::checkpoint(tr) } else { None };
    tr.absorb_u64(b"pb-slot", s as u64);
    acc.order.push(format!("slot {s:02} begin"));
    // A zero multiplier would publish the unmasked scalar and rounds. Refusals are
    // functions of challenges only and are never resampled on the same transcript.
    let c = tr.challenge_fp2();
    if c.is_zero() {
        return Err("zero CFS mask challenge; discard attempt".into());
    }
    let (scalar, rho, es, terms, g_val) = match side {
        Side::Prove { pd, out } => {
            // **STAGE 28.** The four sub-steps, timed only when the phase clock
            // is on (`timing::slot_step` is `f()` and nothing else otherwise).
            // Two of them are this lane's code and two are `zk.rs`'s; the split
            // is what says which.
            // **STAGE 28.** The tables of one slot are independent of each
            // other and are built in parallel above a threshold, in the
            // crate's own rayon style. The iterator is INDEXED, so the table
            // set is the same set in the same order whatever the thread count
            // is; no randomness is drawn here, so no draw order can move.
            // [ZK60-METAL M4i] a DEVICE slot's tables are built in place in a
            // pooled device buffer: no host vector per table (macOS zeroes a
            // recycled one first) and no copy. Only a host or standalone slot
            // (its claimed sum reads no table), above the test oracle's size,
            // with the base-field census off; anything else, or a buffer the
            // device cannot give, builds host vectors as before. Same words.
            #[cfg(feature = "gpu-metal")]
            let mut dev_tables: Option<crate::gpu::MetalTables> = None;
            #[cfg(feature = "gpu-metal")]
            let direct = def.metal.is_some() && kind != SlotKind::Private && (def.tabs.len() << n) > METAL_DIRECT_MIN && !super::timing::census_on(s);
            let mut tables: Vec<Vec<Fp2>> = super::timing::slot_step(s, "tables: build (argument.rs)", (def.tabs.len() << n) as u64, || {
                #[cfg(feature = "gpu-metal")]
                if direct {
                    if let Ok(mut mt) = crate::gpu::MetalTables::new(def.tabs.len(), 1usize << n) {
                        build_tables_into(&def.tabs, n, pd, mt.tables_mut());
                        dev_tables = Some(mt);
                        return Vec::new();
                    }
                }
                build_tables_at(&mut def.tabs, n, pd, TABLES_PAR_MIN)
            });
            if tables.iter().any(|t| t.len() != 1usize << n) {
                return Err(format!("private block: slot {s} table length"));
            }
            // **STAGE 29 (integrator request R1b).** A COUNT, off unless the
            // operator names this slot in `HL_PB_BASEFIELD`: how much of the
            // data round 1 starts from is base-field-valued. It reads the
            // tables and prints counts; it writes nothing, absorbs nothing and
            // draws nothing, and the labels are schedule facts (which
            // commitment, how many slices, how many fixed coordinates).
            if super::timing::census_on(s) {
                let labels: Vec<String> = def
                    .tabs
                    .iter()
                    .map(|t| match t {
                        Tab::Eq { point, start } => format!("Eq (challenge-weighted) |point|={} start={start}", point.len()),
                        Tab::Pub(_) => "Pub (public table)".to_string(),
                        Tab::Priv(p) => format!(
                            "Priv cm={:?} log={} slices={} fixed={} ext_round={}",
                            p.cm,
                            p.log,
                            p.slices.len(),
                            p.coords.iter().filter(|c| matches!(c, Coord::Fixed(_))).count(),
                            p.ext_round
                        ),
                    })
                    .collect();
                super::timing::base_field_census(s, &labels, &tables);
            }
            let mask = &pd.masks[s];
            let scalar = super::timing::slot_step(s, "claimed sum: total (argument.rs)", 1u64 << n, || match kind {
                SlotKind::Private => total(&tables, &def.poly).add(c.mul(mask.total())),
                SlotKind::Standalone => c.mul(mask.total()),
                SlotKind::Host => def.hosted.iter().fold(c.mul(mask.total()), |g, (hs, coef)| g.sub(coef.mul(acc.cs[*hs]).mul(pd.masks[*hs].total()))),
            });
            tr.absorb_fp2(b"pb-scalar", &[scalar]);
            let poly = |v: &[Fp2]| (def.poly)(v);
            let (mut rounds, rho, finals) = super::timing::slot_step(s, "masked sumcheck (zk.rs, shared)", 1u64 << n, || {
                // Private slots already measured their actual cube sum.
                // Host/standalone slots instead ASSERT a sum which need not
                // hold on an inconsistent witness. Evaluate their first round
                // fully so tampered witnesses retain the old prover's bytes
                // and verifier refusal, rather than a new debug panic. Later
                // rounds recover from their own actual unmasked round.
                let unmasked_claim = if kind == SlotKind::Private {
                    Some(scalar.sub(c.mul(mask.total())))
                } else { None };
                // Compare bounded actual slot fixtures with the old prover
                // at the same transcript/tables, including masked bytes.
                #[cfg(test)]
                // ([M4i] counted by the slot's table COUNT: a direct device
                // build leaves `tables` empty and is above this size)
                // ([M8] HL_PB_ORACLE=0 skips it in a TIMING run: the replay is
                // a CPU sumcheck inside this timed step that no production
                // prover runs; every gate keeps the default, on)
                let oracle = if def.tabs.len() * (1usize << n) <= 1 << 18 && std::env::var("HL_PB_ORACLE").map(|v| v != "0").unwrap_or(true) {
                    let mut old_tables = tables.clone();
                    let mut old_tr = Transcript::clone_state(tr);
                    let old = crate::zk::masked_prove(&mut old_tables, degree, &poly, mask, c, &mut old_tr);
                    Some((old, old_tr, old_tables))
                } else { None };
                // [ZK60-METAL M3] the device evaluator: the same unmasked rounds
                // (values), the same s(1) rule as the CPU evaluator this slot
                // would use (recovery for the closure path, full evaluation for
                // the grouped path), the same driver. A decline runs the CPU.
                #[cfg(feature = "gpu-metal")]
                let metal_result = if let Some(mt) = dev_tables.take() {
                    // [M4i] the tables already in device memory; a decline
                    // hands them back for the CPU evaluator
                    let (src, cf, base) = def.metal.as_ref().expect("a direct device build has the slot's kernels");
                    match crate::gpu::metal_rounds_owned(src, mt, degree, cf, base) {
                        Ok(ev) => {
                            let ev = if def.groups.is_some() { ev } else { ev.recover_one(unmasked_claim) };
                            // [M4k] the last, tiny rounds on the host (the same values)
                            let mut ev = ev.with_host_tail(&*def.poly);
                            // [M6] its device rounds in one submission, replayed on the host
                            let r = ev.masked_prove(mask, c, tr);
                            tables = ev.final_tables();
                            Some(r)
                        }
                        Err((mt, why)) => {
                            match why {
                                None => super::metal_slot::note_cpu_slot(s, std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false)),
                                Some(e) => crate::gpu::declined("[ZK60-METAL] slot sumcheck", &e),
                            }
                            tables = mt.to_vecs();
                            None
                        }
                    }
                } else {
                    match &def.metal {
                    Some((src, cf, base)) if tables.len() << n >= METAL_MIN_TERMS || small_slot_pays(&*def.poly, tables.len(), n, degree) => {
                        match crate::gpu::metal_rounds(src, &tables, degree, cf, base) {
                            Ok(None) => {
                                // a base-typed table is not base-field here:
                                // the typed kernel does not apply, CPU slot
                                super::metal_slot::note_cpu_slot(s, std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false));
                                None
                            }
                            Ok(Some(ev)) => {
                                let ev = if def.groups.is_some() { ev } else { ev.recover_one(unmasked_claim) };
                                // [M4k] the last, tiny rounds on the host (the same values)
                                let mut ev = ev.with_host_tail(&*def.poly);
                                // [M6] its device rounds in one submission, replayed on the host
                                let r = ev.masked_prove(mask, c, tr);
                                tables = ev.final_tables();
                                Some(r)
                            }
                            Err(e) => {
                                crate::gpu::declined("[ZK60-METAL] slot sumcheck", &e);
                                None
                            }
                        }
                    }
                    _ => None,
                    }
                };
                #[cfg(not(feature = "gpu-metal"))]
                let metal_result: Option<_> = None;
                let result = if let Some(r) = metal_result {
                    r
                } else if let Some((groups, bracket)) = &def.groups {
                    let mut evaluator = sumcheck::GroupedEqRounds::new(&mut tables, degree, groups.clone(), &**bracket);
                    crate::zk::masked_prove_rounds(&mut evaluator, mask, c, tr)
                } else {
                    let mut evaluator = sumcheck::ClosureRounds::new(&mut tables, degree, &poly)
                        .recover_one(unmasked_claim);
                    crate::zk::masked_prove_rounds(&mut evaluator, mask, c, tr)
                };
                #[cfg(test)]
                if let Some((old, mut old_tr, old_tables)) = oracle {
                    assert_eq!(result, old, "R1d actual slot {s}: masked rounds/challenges/finals");
                    assert_eq!(tables, old_tables, "R1d actual slot {s}: folded tables");
                    assert_eq!(tr.state(), old_tr.state(), "R1d actual slot {s}: transcript");
                    let mut next = Transcript::clone_state(tr);
                    assert_eq!(next.challenge_fp2(), old_tr.challenge_fp2());
                }
                result
            });
            let mut cur = finals;
            let mut prev = rho.clone();
            super::timing::slot_step(s, "extension rounds (mask_eval + zk.rs)", ext as u64, || {
                for m in 0..ext {
                    // [ZK60-METAL M4b] the reserved mask pair of every private
                    // table masked in this round, read at its claim point's
                    // tail: ONE eq table per distinct tail (most tables of a
                    // slot share it) and the tables in parallel. Each value is
                    // the same fold in the same order as before, and the
                    // indexed collect keeps table order, so no byte moves.
                    use rayon::prelude::*;
                    let tails: Vec<Option<Vec<Fp2>>> = def
                        .tabs
                        .iter()
                        .map(|t| match t {
                            Tab::Priv(p) if p.ext_round == m => Some(mask_tail(&sh, p, &claim_point(p, &rho))),
                            _ => None,
                        })
                        .collect();
                    let mut uniq: Vec<&Vec<Fp2>> = Vec::new();
                    let which: Vec<usize> = tails
                        .iter()
                        .map(|t| match t {
                            Some(tp) => uniq.iter().position(|u| *u == tp).unwrap_or_else(|| {
                                uniq.push(tp);
                                uniq.len() - 1
                            }),
                            None => usize::MAX,
                        })
                        .collect();
                    let eqs: Vec<Vec<Fp2>> = uniq.par_iter().map(|u| eq_table_msb(u)).collect();
                    let exts: Vec<Fp2> = def
                        .tabs
                        .par_iter()
                        .zip(which.par_iter())
                        .map(|(t, &k)| match t {
                            Tab::Priv(p) if k != usize::MAX => mask_eval_eq(&sh, p, pd.data[p.cm as usize], &eqs[k]),
                            _ => Fp2::ZERO,
                        })
                        .collect();
                    let e = extension(&cur, &exts, degree, &poly, mask, c, &prev, &mut rounds, tr);
                    for (v, x) in cur.iter_mut().zip(exts.iter()) {
                        *v = masked_terminal(*v, *x, e);
                    }
                    prev.push(e);
                }
            });
            let terms: Vec<Fp2> = def.tabs.iter().zip(cur.iter()).filter(|(t, _)| matches!(t, Tab::Priv(_))).map(|(_, v)| *v).collect();
            let g_val = mask.eval(&prev);
            let es = prev[n..].to_vec();
            out.push(SlotProof { scalar, sc: SumcheckProof { rounds }, terms: terms.clone() });
            (scalar, rho, es, terms, g_val)
        }
        Side::Verify { slots } => {
            let sp = slots.get(s).ok_or("private block: missing slot")?;
            if sp.terms.len() != n_priv {
                return Err(format!("private block: slot {s} terminal count"));
            }
            tr.absorb_fp2(b"pb-scalar", &[sp.scalar]);
            let claimed = def.hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(acc.scalars[*hs])));
            let (fin, rho_full) = sumcheck::verify(claimed, degree, n + ext, &sp.sc, tr).map_err(|e| format!("slot {s} [{}]: {e}", SLOT_NAMES[s]))?;
            let rho = rho_full[..n].to_vec();
            let es = rho_full[n..].to_vec();
            let sel = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
            let mut k = 0usize;
            let vals: Vec<Fp2> = def
                .tabs
                .iter()
                .map(|t| match t {
                    Tab::Eq { point, start } => sel.mul(eq_point(point, &rho[*start..*start + point.len()])),
                    Tab::Pub(v) => sel.mul(eval_mle_ext(v, &rho)),
                    Tab::Priv(_) => {
                        k += 1;
                        sp.terms[k - 1]
                    }
                })
                .collect();
            let g_val = fin.sub((def.poly)(&vals)).mul(c.inv());
            (sp.scalar, rho, es, sp.terms.clone(), g_val)
        }
    };
    acc.order.push(format!("slot {s:02} scalar+rounds"));
    // A zero terminal challenge would open an unmasked evaluation; (1 - e) = 0 would
    // detach the claim from the data. Both are refused, never redrawn.
    if es.iter().any(|e| e.is_zero() || *e == Fp2::ONE) {
        return Err("degenerate terminal mask challenge; discard attempt".into());
    }
    tr.absorb_fp2(b"pb-term", &terms);
    acc.order.push(format!("slot {s:02} terminals"));
    let cd = es.iter().fold(Fp2::ONE, |a, e| a.mul(Fp2::ONE.sub(*e)));
    let mut k = 0usize;
    for t in &def.tabs {
        if let Tab::Priv(p) = t {
            let cm = es[p.ext_round + 1..].iter().fold(es[p.ext_round], |a, e| a.mul(Fp2::ONE.sub(*e)));
            acc.claims[p.cm as usize].push(build_claim(&sh, p, &claim_point(p, &rho), cd, cm, terms[k]));
            k += 1;
        }
    }
    // M functionals, in the declared order: [Gamma_s if standalone] eval_s; host Gammas last
    let mut rho_full = rho;
    rho_full.extend_from_slice(&es);
    match kind {
        SlotKind::Standalone => acc.fs.push(MaskFunctional { terms: vec![(s, sum_weights(&sh, s).iter().map(|w| w.mul(c)).collect())], value: scalar }),
        SlotKind::Host => {
            let mut terms = vec![(s, sum_weights(&sh, s).iter().map(|w| w.mul(c)).collect::<Vec<Fp2>>())];
            for (hs, coef) in &def.hosted {
                let k = coef.mul(acc.cs[*hs]).neg();
                terms.push((*hs, sum_weights(&sh, *hs).iter().map(|w| w.mul(k)).collect()));
            }
            acc.host_fs.push(MaskFunctional { terms, value: scalar });
        }
        SlotKind::Private => {}
    }
    acc.fs.push(MaskFunctional { terms: vec![(s, CfsMask::eval_weights(&rho_full, degree))], value: g_val });
    acc.cs.push(c);
    acc.scalars.push(scalar);
    #[cfg(test)]
    if let Side::Verify { slots } = side {
        super::capture::slot(&def, acc, &slots[s], &rho_full, c, g_val, capture_before, tr);
        super::run_capture::slot(&def, acc, &slots[s], &rho_full, c, g_val, run_capture_before, tr);
    }
    Ok(())
}

// ---------------------------------------------------------------- slot definitions

struct B<'a> {
    lay: &'a Layout,
    slot: usize,
    tabs: Vec<Tab>,
    ak: usize,
    hk: usize,
    /// **STEP C.** SHAPED plane id -> table index, filled by [`B::a_range`].
    /// The growing limb groups (the third `sigma_s` limb at the rung) have no
    /// toy id, so they are reached through this map and `Ids::sr` / `sg` /
    /// `pl` / `nr` / `ns` / `mr` / `ms`, never by arithmetic on a toy const.
    shaped: Vec<usize>,
}

fn rho(r: std::ops::Range<usize>) -> Vec<Coord> {
    r.map(Coord::Rho).collect()
}
fn fixed(p: &[Fp2]) -> Vec<Coord> {
    p.iter().map(|f| Coord::Fixed(*f)).collect()
}
fn cat(parts: &[&Vec<Fp2>]) -> Vec<Fp2> {
    parts.iter().flat_map(|p| p.iter().copied()).collect()
}

impl<'a> B<'a> {
    fn new(lay: &'a Layout, slot: usize) -> Self {
        B { lay, slot, tabs: Vec::new(), ak: 0, hk: 0, shaped: Vec::new() }
    }
    fn push(&mut self, t: Tab) -> usize {
        self.tabs.push(t);
        self.tabs.len() - 1
    }
    fn eq(&mut self, point: &[Fp2], start: usize) -> usize {
        self.push(Tab::Eq { point: point.to_vec(), start })
    }
    /// **STAGE 20's public factor (the repair of finding S19-F1).** The two
    /// bilinear attention slots sum over the key-value GROUP, so they carry
    /// `eq(r_g, .)` over their LEADING `|r_g|` variables. A shape with ONE
    /// key-value head has an empty `r_g` and gets `None`: no table, no degree
    /// and no transcript byte, exactly as [`B::supp`] gives the frozen toy
    /// nothing. The caller wraps the result in a [`Gate`], whose `None` arm
    /// is the constant ONE, so the toy's slot polynomial is the product of
    /// its two private factors and nothing else.
    fn group_eq(&mut self, r_g: &[Fp2]) -> Option<usize> {
        if r_g.is_empty() {
            return None;
        }
        Some(self.eq(r_g, 0))
    }
    fn public(&mut self, v: Vec<Fp2>) -> usize {
        self.push(Tab::Pub(v))
    }
    fn a_slice(&mut self, off: usize, log: usize, coords: Vec<Coord>, ext_round: usize) -> Result<usize, String> {
        let mask_row = self.lay.a_site(self.slot, self.ak)?;
        self.ak += 1;
        Ok(self.push(Tab::Priv(Priv { cm: Cm::A, slices: vec![(off, Fp2::ONE)], log, coords, mask_row, ext_round })))
    }
    /// the log of a SHAPED A plane's own domain
    fn a_log(&self, plane: usize) -> usize {
        self.lay.shape().log(self.lay.ids().dom(plane))
    }
    fn a_at(&mut self, plane: usize, coords: Vec<Coord>, ext_round: usize) -> Result<usize, String> {
        let (off, log) = (self.lay.a_off[plane], self.a_log(plane));
        self.a_slice(off, log, coords, ext_round)
    }
    /// an A plane on its own domain (the slot's domain)
    fn a(&mut self, plane: usize) -> Result<usize, String> {
        let log = self.a_log(plane);
        self.a_at(plane, rho(0..log), 0)
    }
    /// The SHAPED planes `first ..= last`, in plane order, returning a map
    /// TOY plane id -> table index (`usize::MAX` where the toy has no name
    /// for the plane, or where the plane is outside the range). The shaped
    /// map is kept in `self.shaped` for [`B::tab`].
    fn a_range(&mut self, first: usize, last: usize) -> Result<Vec<usize>, String> {
        let lay: &'a Layout = self.lay;
        let ids = lay.ids();
        let mut shaped = vec![usize::MAX; ids.n_a()];
        for p in first..=last {
            shaped[p] = self.a(p)?;
        }
        let mut idx = vec![usize::MAX; N_A];
        for (p, slot) in idx.iter_mut().enumerate() {
            let q = ids.at(p);
            if (first..=last).contains(&q) {
                *slot = shaped[q];
            }
        }
        self.shaped = shaped;
        Ok(idx)
    }
    /// the table index of a SHAPED plane pushed by [`B::a_range`]
    fn tab(&self, plane: usize) -> usize {
        self.shaped[plane]
    }
    fn h(&mut self, plane: usize) -> Result<usize, String> {
        let mask_row = self.lay.h_site(self.slot, self.hk)?;
        self.hk += 1;
        let (re, im) = self.lay.h_off[plane];
        let log = self.lay.shape().log(self.lay.hids().dom(plane));
        Ok(self.push(Tab::Priv(Priv { cm: Cm::H, slices: vec![(re, Fp2::ONE), (im, Fp2::U)], log, coords: rho(0..log), mask_row, ext_round: 0 })))
    }
    /// A caller-fixed endpoint plane. **S11a.** The seam commits the PADDED
    /// `(t_pad, d_pad)` cube, which is exactly the `Dom::D` slice this slot
    /// already claims, so the only shape-dependent numbers are the log and
    /// the terminal pair's row: a seam commitment has `endpoint_rows - 5`
    /// data rows and its pair sits immediately above them (the toy's frozen
    /// 2). **S11b is still owed**: 125M's endpoint is 393,216 words, far past
    /// the frozen seam's 4,096-word ceiling, and needs a generalised endpoint
    /// built beside `private_seam.rs`.
    ///
    /// **STAGE 12.** The terminal pair's row is no longer the literal
    /// `endpoint_rows - 5`: it comes from the LAYOUT
    /// (`Layout::io_mask_row`), which is `endpoint_rows - 5` for every
    /// single-block profile — byte for byte what it was — and, for a stage of
    /// a RUN, the DERIVED pair of the boundary commitment this side claims
    /// (site 0 at `data` for the outgoing claim, site 1 at `data + 2` for the
    /// incoming one). The row WIDTH is unchanged: a boundary and an endpoint
    /// share `sh.endpoint_log_n`, so `row_log` needs no case.
    fn endpoint(&mut self, cm: Cm) -> usize {
        let sh = self.lay.shape();
        let (log, mask_row) = (sh.log(Dom::D), self.lay.io_mask_row(cm == Cm::Out));
        self.push(Tab::Priv(Priv { cm, slices: vec![(0, Fp2::ONE)], log, coords: rho(0..log), mask_row, ext_round: 0 }))
    }
    /// **RULING P-1's public factor (S9 part 4).** `supp(dom)` laid out over
    /// THIS slot's cube: the domain's own indicator when the cube is the
    /// domain, and the same table repeated over the trailing coordinates when
    /// a COARSER domain is being gated inside a finer cube (`Dom::Ht` inside
    /// the `Dom::S` cube, `Dom::T` inside nothing today). Coordinates are
    /// most-significant-first, so a coarser domain occupies the LEADING
    /// variables and its index is `x / rep`.
    ///
    /// `Ok(None)` when this profile carries no pad rule or the domain does not
    /// pad — which is how the frozen toy's transcript gains neither a table
    /// nor a challenge (finding S9-F1's profile gate).
    ///
    /// **FINDING F-1 of the independent review.** The tiling was a
    /// `debug_assert_eq!`, and the release profile — the only one the rung and
    /// the 125M shape are ever built in — compiles debug assertions out. A
    /// non-tiling indicator would then give the PROVER AND THE VERIFIER the
    /// same wrong `(1 − supp)` and the proof would verify while meaning
    /// something else. It is a real refusal now, taken on both sides by
    /// [`tile_rep`], and the caller is in a `Result` context already.
    fn supp(&mut self, dom: Dom, cube_len: usize) -> Result<Option<usize>, String> {
        let sh = self.lay.shape();
        if !sh.carries_pad_rule() || !sh.pads(dom) {
            return Ok(None);
        }
        let t = super::pad::indicator_table(sh, dom);
        let rep = tile_rep(t.len(), cube_len)?;
        Ok(Some(self.public((0..cube_len).map(|x| k(t[x / rep])).collect())))
    }
    fn finish(self, poly: Poly, hosted: Vec<(usize, Fp2)>) -> Result<SlotDef, String> {
        if self.ak != self.lay.a_sites()[self.slot] || self.hk != self.lay.h_sites()[self.slot] {
            return Err(format!("private block: slot {} uses {} A / {} H sites, schedule declares {} / {}", self.slot, self.ak, self.hk, self.lay.a_sites()[self.slot], self.lay.h_sites()[self.slot]));
        }
        Ok(SlotDef {
            slot: self.slot,
            tabs: self.tabs,
            poly,
            groups: None,
            hosted,
            sh: self.lay.shape().clone(),
            #[cfg(feature = "gpu-metal")]
            metal: None,
        })
    }
}

/// **FINDING F-1.** How many times an indicator of `t_len` entries repeats to
/// fill a cube of `cube_len` — a RELEASE-BUILD refusal, not an assumption.
/// Both sides of the protocol build the public factor through [`B::supp`], so
/// a non-tiling indicator would give them the SAME wrong `(1 − supp)` and the
/// proof would verify while meaning something else; `t_len > cube_len` used to
/// give `rep = 0` and a divide-by-zero panic instead. The refusal names no
/// witness-dependent quantity: `t_len` and `cube_len` are both functions of
/// the shape.
pub(crate) fn tile_rep(t_len: usize, cube_len: usize) -> Result<usize, String> {
    if t_len == 0 || cube_len == 0 || cube_len % t_len != 0 {
        return Err(format!("private block: an indicator that does not tile its slot's cube ({t_len} entries in {cube_len})"));
    }
    Ok(cube_len / t_len)
}

/// **FINDING F-2.** `SC_TAB`'s pad-zero group, checked against what
/// `pad.rs` DECLARES instead of assumed. Both lists are compared, in plane
/// order; the caller passes the planes its own hard-coded table indices
/// `[1, 4, 7]` and `[2, 5, 8]` stand for. A refusal here names a plane list,
/// which is a function of the shape and of nothing private.
pub(crate) fn tab_group_is_declared(sh: &Shape, ids: &Ids, a_declared: &[usize], h_declared: &[usize]) -> Result<(), String> {
    if super::pad::zero_rule_h_planes(sh, Dom::Tab) != h_declared {
        return Err("private block: a Dom::Tab helper is outside SC_TAB's pad-zero group".into());
    }
    if super::pad::zero_rule_a_planes(sh, ids, Dom::Tab) != a_declared {
        return Err("private block: a Dom::Tab multiplicity is outside SC_TAB's pad-zero group".into());
    }
    Ok(())
}

/// `log2` of a power of two (every axis this profile addresses is one, by
/// [`Shape::new`]'s refusals)
fn lg(v: usize) -> usize {
    debug_assert!(v.is_power_of_two(), "an axis that is not a power of two reached a coordinate list");
    v.trailing_zeros() as usize
}

/// `sum_k v[ix[k]] * 256^k` — a byte-limb decomposition of `ix.len()` limbs
fn limbs(v: &[Fp2], ix: &[usize]) -> Fp2 {
    ix.iter().enumerate().fold(Fp2::ZERO, |a, (k, i)| a.add(v[*i].mul(pow256(k))))
}

/// a U8 lookup in table-index space: value = cst + sum coef * v[idx] (the tag folded into cst)
#[derive(Clone)]
struct LkT {
    terms: Vec<(usize, Fp)>,
    cst: Fp2,
}

/// **FINDING S12-F1 (S12a), fixed here.** `Layout::lookups` names its planes
/// by SHAPED id (`lookups_at(&self.sh, &self.ids, dom)`), so the map it is
/// resolved through must be the SHAPED one — [`B::shaped`] — and never
/// `a_range`'s toy-indexed `idx`. The two coincide at the toy and at every
/// plane below the first growing limb group, which is why no earlier test
/// could see the difference: the slot-definition sweep BUILDS the polynomial
/// but never EVALUATES it, and `lk_tables` is the only place a plane id is
/// read at definition time. At the rung the third `sigma_s` limb shifts every
/// `Dom::F` and `Dom::Tab` plane by one and the wrong map indexes past the
/// end, which is the panic the first honest rung proof produced.
fn lk_tables(lay: &Layout, dom: Dom, shaped: &[usize], g_u8: Fp2) -> Vec<LkT> {
    // W16 (D54): each lookup folds ITS family's tag; a U8 lookup's is `g_u8`
    // itself, so every legacy and R13 constant is the element it always was
    lay.lookups(dom)
        .into_iter()
        .map(|l| LkT { terms: l.terms.iter().map(|(p, c)| (shaped[*p], Fp::from_i64(*c))).collect(), cst: Fp2::from_i64(l.cst).add(super::range16::g_of(l.tag, g_u8)) })
        .collect()
}

/// W16: `sum_k v[ix[k]] * 2^(16 k)` — a 16-bit limb decomposition
fn limbs16(v: &[Fp2], ix: &[usize]) -> Fp2 {
    ix.iter().enumerate().fold(Fp2::ZERO, |a, (k, i)| a.add(v[*i].mul_base(Fp::new(1u64 << (16 * k)))))
}

/// sum_k mu_k * (the LogUp helper relation of helper k), helpers at tables h0, h0 + 1, ...
fn helper_sum(v: &[Fp2], lks: &[LkT], h0: usize, alpha: Fp2, mu: &[Fp2]) -> Fp2 {
    let den = |l: &LkT| alpha.sub(l.terms.iter().fold(l.cst, |a, (i, c)| a.add(v[*i].mul_base(*c))));
    let mut acc = Fp2::ZERO;
    for k in 0..lks.len().div_ceil(2) {
        let h = v[h0 + k];
        let d1 = den(&lks[2 * k]);
        let rel = match lks.get(2 * k + 1) {
            Some(l2) => {
                let d2 = den(l2);
                h.mul(d1).mul(d2).sub(d1.add(d2))
            }
            None => h.mul(d1).sub(Fp2::ONE),
        };
        acc = acc.add(mu[k].mul(rel));
    }
    acc
}

/// **THE BATCHED PAD-ZERO TERM of ruling P-1 (memo §3.7a, S9 part 4).**
///
/// One group per padded domain hosted in this slot: the table index of that
/// domain's support indicator, and the ZERO-rule planes it governs paired with
/// their power of the slot's single batching challenge `zeta`. The value is
///
/// ```text
/// mu_pad * sum_groups (1 - supp(x)) * sum_j zeta^j * plane_j(x)
/// ```
///
/// added INSIDE the slot's `eq(tau) * (..)` bracket, so the zero-check decides
/// it at every point of the cube. EXEMPT planes never enter a group, which is
/// the "excluded from every summation by the indicator" of the memo's table.
///
/// A slot that carries no pad rule builds [`PadTerm::none`]: no group, no
/// `zeta`, no `mu` entry and no public table, so the frozen toy's transcript
/// and its 2,816,472 bytes are untouched.
struct PadTerm {
    groups: Vec<(usize, Vec<(usize, Fp2)>)>,
    mu: Fp2,
}

impl PadTerm {
    fn none() -> PadTerm {
        PadTerm { groups: Vec::new(), mu: Fp2::ZERO }
    }
    /// the powers `zeta^0, zeta^1, ..` continue ACROSS the groups of one slot,
    /// so a plane is batched at one power and one only
    fn add(&mut self, supp: Option<usize>, planes: &[usize], zeta: Fp2) {
        let Some(supp) = supp else { return };
        if planes.is_empty() {
            return;
        }
        let mut p = Fp2::ONE;
        for _ in 0..self.groups.iter().map(|(_, g)| g.len()).sum::<usize>() {
            p = p.mul(zeta);
        }
        let mut g = Vec::with_capacity(planes.len());
        for t in planes {
            g.push((*t, p));
            p = p.mul(zeta);
        }
        self.groups.push((supp, g));
    }
    fn eval(&self, v: &[Fp2]) -> Fp2 {
        let mut acc = Fp2::ZERO;
        for (supp, planes) in &self.groups {
            let anti = Fp2::ONE.sub(v[*supp]);
            let mut inner = Fp2::ZERO;
            for (t, w) in planes {
                inner = inner.add(w.mul(v[*t]));
            }
            acc = acc.add(anti.mul(inner));
        }
        self.mu.mul(acc)
    }
}

/// `supp(x)` at the slot's cube point, or the constant ONE where this profile
/// carries no pad rule. This is the factor ruling P-1 puts on the
/// INHOMOGENEOUS constraint groups and on every host term of a gated slot; it
/// is never put on the LogUp arm (§3.7a), which must keep speaking on padded
/// positions or the value-0 identity loses its summands.
#[derive(Clone, Copy)]
struct Gate(Option<usize>);

impl Gate {
    fn at(self, v: &[Fp2]) -> Fp2 {
        match self.0 {
            Some(i) => v[i],
            None => Fp2::ONE,
        }
    }
}

fn nonzero(v: Vec<Fp2>) -> Result<Vec<Fp2>, String> {
    if v.iter().any(|x| x.is_zero()) {
        return Err("zero batching challenge; discard attempt".into());
    }
    Ok(v)
}

fn k(v: i64) -> Fp2 {
    Fp2::from_i64(v)
}

/// The causal support: 1 on j <= t, (h, t, j) order. This is the TOY's table
/// written out with the toy's literals; `causal_mask_at` is the shape-driven
/// one, and `grow_tests` asserts the two agree entry for entry at the toy, so
/// the literal stays an independent oracle for the frozen profile.
pub(crate) fn causal_mask() -> Vec<Fp2> {
    (0..H * T * T).map(|x| if x % T <= (x / T) % T { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// **STEP C: the same mask over the PADDED `Dom::S` cube (M-3).** The cube is
/// `(head slot, t, j)` with the token axes at their PADDED extent, and the
/// mask keys on `(t, j)` only, so it is 1 on every padded head slot exactly
/// as it is on a true one. What a padded POSITION's planes may contain is
/// ruling P-1's pad-zero term (S9 part 4), not this table; the mask is the
/// causal predicate and nothing else. At the toy nothing pads and this is
/// the frozen table, value for value.
pub(crate) fn causal_mask_at(sh: &Shape) -> Vec<Fp2> {
    let t = sh.t_pad;
    (0..sh.size(Dom::S)).map(|x| if x % t <= (x / t) % t { Fp2::ONE } else { Fp2::ZERO }).collect()
}

/// (C, S') with out = C * x + S' * x_partner, over `heads` heads per row.
///
/// **STEP S7 (M-1).** `heads` is the number of heads the table is laid out
/// for, and on the KEY-VALUE side that is `kv_heads`, not the literal `1`
/// the toy could get away with: at the rung `SC_KVZC`'s table must hold
/// `tokens * kv_heads * head_dim` entries or the slot's own table-length
/// check refuses. Tokens, head dimension and the half split all come from
/// the shape. The table is still laid out DENSELY
/// (`tokens * heads * head_dim`); putting it on the padded domain stride is
/// the pad rule of memo section 3.7a, step S9.
/// **STEP C: the RoPE tables on the PADDED domain stride.** `rope_tables`
/// lays the two tables out densely over `tokens * heads * head_dim`, which is
/// what the kernel-facing parity tests want and what the toy's cube happens
/// to be. A slot's public table must be as long as the slot's CUBE, so at any
/// shape that pads, the values have to sit at their padded coordinates and
/// the pad has to hold something: it holds ZERO, the same rule ruling P-2
/// puts on the public weights.
///
/// The RoPE value depends on `(t, i)` only, never on the head, so a padded
/// HEAD SLOT is zero-filled for the same reason a padded token is: nothing
/// true lives there. The relation those tables enter (`SC_QZC` / `SC_KVZC`'s
/// rope clause) is INHOMOGENEOUS — it carries `+ 2^(SH_ROPE - 1)` — so a
/// zeroed pad does not make it vanish there; switching the clause off on the
/// pad is the support indicator of S9 part 4, and it is owed.
pub(super) fn rope_tables_at(sh: &Shape, public: &AttentionPublic, dom: Dom) -> (Vec<Fp2>, Vec<Fp2>) {
    let (dh, half) = (sh.head_dim, sh.head_dim / 2);
    // `Dom::Q` is indexed by the PADDED head slot, `Dom::Kv` by the key-value
    // head, which is not padded (`kv_heads` divides the padded head count)
    let heads = if dom == Dom::Q { sh.h_pad } else { sh.kv_heads };
    let n = sh.size(dom);
    let (mut c, mut s) = (vec![Fp2::ZERO; n], vec![Fp2::ZERO; n]);
    for x in 0..n {
        let (i, slot, t) = (x % dh, (x / dh) % heads, x / (dh * heads));
        let live = t < sh.tokens && (dom != Dom::Q || sh.slot_is_true_head(slot)) && x < sh.t_pad * heads * dh;
        if !live {
            continue;
        }
        let at = t * half + i % half;
        c[x] = k(public.rope_cos[at]);
        s[x] = k(if i < half { -public.rope_sin[at] } else { public.rope_sin[at] });
    }
    (c, s)
}

pub(super) fn rope_tables(sh: &Shape, public: &AttentionPublic, heads: usize) -> (Vec<Fp2>, Vec<Fp2>) {
    let (dh, half) = (sh.head_dim, sh.head_dim / 2);
    let width = heads * dh;
    let mut c = Vec::with_capacity(sh.tokens * width);
    let mut s = Vec::with_capacity(sh.tokens * width);
    for x in 0..sh.tokens * width {
        let (t, i) = (x / width, x % dh);
        let at = t * half + i % half;
        c.push(k(public.rope_cos[at]));
        s.push(k(if i < half { -public.rope_sin[at] } else { public.rope_sin[at] }));
    }
    (c, s)
}

pub(crate) fn table_values_u8(g_u8: Fp2) -> Vec<Fp2> {
    table_values_u8_at(Dom::Tab.len(), g_u8)
}
/// THE P-3 LIFT'S FIRST CONDITION, in one place for all three tables: at a
/// lifted `Dom::Tab` the table plane is longer than the byte class, and every
/// padded position must REPEAT an existing entry — entry `i` is built from
/// `i % U8_LEN`. The set of proved values is then still exactly the `U8_LEN`
/// byte rows, whatever the row width is. Building the pad from `i` itself
/// would let the range proof admit `1 << LOG_N` values, which is a soundness
/// hole created by the fix for a shape bug (§4.1 condition 1).
pub(crate) fn table_values_u8_at(len: usize, g_u8: Fp2) -> Vec<Fp2> {
    (0..len).map(|i| k((i % U8_LEN) as i64).add(g_u8)).collect()
}
pub(crate) fn table_values_exp(public: &AttentionPublic, beta: Fp2, g_exp: Fp2) -> Vec<Fp2> {
    table_values_exp_at(Dom::Tab.len(), public, beta, g_exp)
}
pub(crate) fn table_values_exp_at(len: usize, public: &AttentionPublic, beta: Fp2, g_exp: Fp2) -> Vec<Fp2> {
    (0..len).map(|x| x % U8_LEN).map(|i| k(i as i64).add(beta.mul(k(public.exp[i]))).add(g_exp)).collect()
}
/// The activation table's public rows `i + beta * act[i] + g_act`, the exp
/// table's construction verbatim under a third tag. Binding the PAIR is a
/// soundness requirement, not a preference (T2 erratum E-22): wherever
/// `u16 = 0` the product relation pins nothing about `a16`, and this is the
/// only other relation `a16` appears in.
pub(crate) fn table_values_act(ff: &FeedForwardPublic, beta: Fp2, g_act: Fp2) -> Vec<Fp2> {
    table_values_act_at(Dom::Tab.len(), ff, beta, g_act)
}
pub(crate) fn table_values_act_at(len: usize, ff: &FeedForwardPublic, beta: Fp2, g_act: Fp2) -> Vec<Fp2> {
    (0..len).map(|x| x % U8_LEN).map(|i| k(i as i64).add(beta.mul(k(i64::from(ff.act[i])))).add(g_act)).collect()
}

/// Draw the slot's challenges and build its tables and polynomial. Identical
/// on both sides.
///
/// **STEP C: the slot definitions over a SHAPE.**
///
/// Every literal that used to name the toy's geometry — the challenge vector
/// lengths, the matmul widths, the coordinate lists, the plane ids, the
/// helper ids, the public table lengths — now comes from `ctx.lay`'s shape
/// and its two plane-id maps. The toy is `Shape::toy()` of this same code and
/// every one of its bytes is unmoved (the schedule digest and the 2,816,472
/// byte receipt are the gate).
///
/// Three slots change MEANING at a shape with grouped query heads or a third
/// softmax limb, and they are the ones to read first:
///
/// * `SC_SCORE` and `SC_PV` — the key-value factor's claim point takes its
///   group coordinates from the QUERY head's challenge (`r_h`'s top
///   `log2(kv_heads)` entries), because correction C-1 puts the group in the
///   HIGH bits of the padded head slot. Trap T-3: reading the key-value side
///   at its own free coordinate would prove a different statement.
/// * `SC_SZC` — the `rho_s` / `sigma_s` limb groups are `limbs_sigma_s` long,
///   not two, and the third limb has no toy id, so the group is addressed
///   through `Ids::sr` / `Ids::sg`.
/// * `SC_QZC` / `SC_KVZC` — the RoPE partner bit sits at `log - log2(dh)`
///   (T-8) and the two public tables are laid out on the PADDED stride.
///
/// **WHAT THIS STEP DOES NOT DO.** The pad rule (ruling P-1, S9 part 4) is
/// NOT here: at a shape that pads, the inhomogeneous clauses of `SC_DZC`,
/// `SC_QZC`, `SC_KVZC`, `SC_SZC`, `SC_FZC`, `SC_SS`, `SC_SSM` and `SC_RS`
/// still speak on padded positions. Until the support indicator lands, a
/// definition built at the rung is a DEFINITION, not a sound argument.
pub(crate) fn define(slot: usize, ctx: &Ctx, pts: &mut Points, tr: &mut Transcript) -> Result<SlotDef, String> {
    if ctx.lay.shape().accuracy_stack()!=crate::private_block::accuracy_precision::Stack::Legacy {
        if let Some(def)=accuracy::define_changed(slot,ctx,pts,tr)? {return Ok(def)}
    }

    let lay = ctx.lay;
    let (sh, ids, hids) = (lay.shape(), lay.ids(), lay.hids());
    let (alpha, beta, g_u8, g_exp, g_act) = (ctx.alpha, ctx.beta, ctx.g_u8, ctx.g_exp, ctx.g_act);
    let mut b = B::new(lay, slot);
    let (p1, p2) = (pow256(1), pow256(2));
    // the axis logs, once: tokens, head slots, head dimension, width, hidden,
    // and the key-value group bits that sit at the TOP of the head slot (C-1)
    let (lt, lh, ldh) = (lg(sh.t_pad), lg(sh.h_pad), lg(sh.head_dim));
    let (ld, lf, lkv) = (lg(sh.d_pad), lg(sh.f_pad), lg(sh.kv_heads));
    let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());
    // **RULING P-1 (S9 part 4), per slot.** `pad_doms` are the padded domains
    // whose batched pad-zero term THIS slot hosts, in `ALL_DOMS` order — the
    // declared order the `zeta` powers follow. `n_pad` is the one extra `mu`
    // entry the term costs, and `cube` is the slot's own main cube, which is
    // the length every public table of the slot must have. All three are
    // empty / zero on the frozen toy profile (`Shape::carries_pad_rule`).
    let pad_doms: Vec<Dom> = ALL_DOMS.into_iter().filter(|d| super::pad::pad_zero_host(*d) == slot && !super::pad::zero_rule_a_planes(sh, ids, *d).is_empty()).collect();
    let (pad_on, cube) = (!pad_doms.is_empty(), 1usize << sh.slots()[slot].0);
    let n_pad = usize::from(pad_on);
    match slot {
        // P-1: the claimed row sum runs over the FULL PADDED `Dom::D` cube
        // (blocking item B-1), so its SUMMAND takes the support factor and the
        // sum is over the true columns alone. `SC_TZC`'s matching host term
        // takes `supp_T` (finding S9-F8).
        SC_SS => {
            pts.r_t = tr.challenge_fp2_vec(lt);
            b.eq(&pts.r_t, 0);
            b.a(ids.at(A_X))?;
            let g = Gate(b.supp(Dom::D, cube)?);
            b.finish(Box::new(move |v: &[Fp2]| g.at(v).mul(v[0]).mul(v[1]).mul(v[1])), vec![])
        }
        // norm_m's row sums: the identical private claimed sum, over xres1
        // instead of x_in, at its own row point (T1 section C.1)
        SC_SSM => {
            pts.r_t2 = tr.challenge_fp2_vec(lt);
            b.eq(&pts.r_t2, 0);
            b.a(ids.at(A_X1))?;
            let g = Gate(b.supp(Dom::D, cube)?);
            b.finish(Box::new(move |v: &[Fp2]| g.at(v).mul(v[0]).mul(v[1]).mul(v[1])), vec![])
        }
        SC_TZC => {
            let tau = tr.challenge_fp2_vec(lt);
            let mu = tr.challenge_fp2_vec(6 + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            // Table indices are CAPTURED from the builder, never written as
            // literals (defect D-1 of the code review: a hand-written list had
            // drifted from the code it documented). The nine sub-slices of each
            // limb plane are pushed by the loop that follows their `+ 1`, in
            // sub-plane order: D's three, a1's three, a2's three.
            let i_tau = b.eq(&tau, 0);
            let i_rt = b.eq(&pts.r_t, 0);
            let i_rt2 = b.eq(&pts.r_t2, 0);
            let i_d = b.a(ids.at(A_D))?;
            let i_dsq = b.a(ids.at(A_DSQ))?;
            let i_limb = i_dsq + 1;
            for kk in 0..N_LIMBS {
                b.a_slice(lay.limb_off(kk), lt, rho(0..lt), 0)?;
            }
            let i_dm = b.a(ids.at(A_DM))?;
            let i_dsqm = b.a(ids.at(A_DSQM))?;
            let i_limbm = i_dsqm + 1;
            for kk in 0..N_LIMBS {
                b.a_slice(lay.limb_off_m(kk), lt, rho(0..lt), 0)?;
            }
            let hosted = vec![(SC_SS, nu[0]), (SC_SSM, nu[1])];
            // **S9 part 4.** `Dom::T`'s four ZERO-rule planes are exactly the
            // four pushed above; the term is batched on `zeta` and weighted by
            // the slot's extra `mu`. The two HOST terms take `supp_T`, because
            // `SC_SS` / `SC_SSM`'s summands now run over the true columns only
            // and a padded row's claimed sum is zero, not `NORM_CEPS`
            // (finding S9-F8). Neither raises the slot's degree, so `SC_TZC`
            // is NOT one of the eight `INDICATOR_SLOT_DOMAIN` slots.
            let gt = Gate(b.supp(Dom::T, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                let planes: Result<Vec<usize>, String> = super::pad::zero_rule_a_planes(sh, ids, Dom::T)
                    .iter()
                    .map(|p| match *p {
                        q if q == ids.at(A_D) => Ok(i_d),
                        q if q == ids.at(A_DSQ) => Ok(i_dsq),
                        q if q == ids.at(A_DM) => Ok(i_dm),
                        q if q == ids.at(A_DSQM) => Ok(i_dsqm),
                        q => Err(format!("private block: Dom::T plane {q} is outside SC_TZC's pad-zero group")),
                    })
                    .collect();
                pz.mu = mu[6];
                pz.add(gt.0, &planes?, zeta);
            }
            // LANE C SCRATCH: the norm epsilon is the SHAPE's (the frozen 1
            // at every registered shape)
            let k_ceps = k(sh.norm_ceps);
            let poly = move |v: &[Fp2]| {
                let l3 = |o: usize| v[o].add(v[o + 1].mul(p1)).add(v[o + 2].mul(p2));
                let (d, dsq, dl, a1, a2) = (v[i_d], v[i_dsq], l3(i_limb), l3(i_limb + 3), l3(i_limb + 6));
                let (dm, dsqm, dlm, a1m, a2m) = (v[i_dm], v[i_dsqm], l3(i_limbm), l3(i_limbm + 3), l3(i_limbm + 6));
                let zc = mu[0].mul(dsq.sub(d.mul(d))).add(mu[1].mul(d.sub(dl))).add(mu[2].mul(d.double().sub(a1).sub(a2)));
                let zc = zc.add(mu[3].mul(dsqm.sub(dm.mul(dm)))).add(mu[4].mul(dm.sub(dlm))).add(mu[5].mul(dm.double().sub(a1m).sub(a2m)));
                let g = gt.at(v);
                v[i_tau]
                    .mul(zc.add(pz.eval(v)))
                    .add(nu[0].mul(v[i_rt]).mul(g).mul(dsq.add(a1).sub(k_ceps)))
                    .add(nu[1].mul(v[i_rt2]).mul(g).mul(dsqm.add(a1m).sub(k_ceps)))
            };
            b.finish(Box::new(poly), hosted)
        }
        // two lookups now (A_LIMB and norm_m's A_LIMBM), so the single helper
        // moves into the two-lookup branch and the slot's degree is 4 (T1 C.1)
        SC_LZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::L));
            // S9 part 4: this slot batches its helpers with the all-ones
            // vector and draws no `mu`, so the pad term's weight is drawn
            // here. The LogUp arm itself is never gated (§3.7a).
            let mu_pad = if pad_on { tr.challenge_fp2() } else { Fp2::ZERO };
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            b.eq(&tau, 0);
            b.a_range(ids.at(A_LIMB), ids.at(A_LIMBM))?;
            let h0 = b.h(hids.first_helper(Dom::L))?;
            let lks = lk_tables(lay, Dom::L, &b.shaped, g_u8);
            let mu = vec![Fp2::ONE; sh.helpers(Dom::L)];
            let mut pz = PadTerm::none();
            if pad_on {
                let si = b.supp(Dom::L, cube)?;
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::L).iter().map(|p| b.tab(*p)).collect();
                pz.mu = mu_pad;
                pz.add(si, &planes, zeta);
            }
            b.finish(Box::new(move |v: &[Fp2]| v[0].mul(helper_sum(v, &lks, h0, alpha, &mu).add(pz.eval(v)))), vec![])
        }
        SC_RS => {
            pts.p_ht = tr.challenge_fp2_vec(sh.log(Dom::Ht));
            pts.lam_z = tr.challenge_fp2();
            let lam = pts.lam_z;
            b.eq(&pts.p_ht, 0);
            b.public(causal_mask_at(sh));
            b.a(ids.at(A_E))?;
            b.a(ids.at(A_ZSEL))?;
            // P-1: the row sums run over the padded `Dom::S` cube, so the
            // SUMMAND takes `supp_S`; `SC_SZC`'s matching host term takes
            // `supp_Ht`, which is constant in `j` and so leaves `per_row`
            // alone.
            let g = Gate(b.supp(Dom::S, cube)?);
            b.finish(Box::new(move |v: &[Fp2]| g.at(v).mul(v[0]).mul(v[1].mul(v[2]).add(lam.mul(v[3])))), vec![])
        }
        SC_QMM | SC_KMM | SC_VMM | SC_WO => {
            if slot == SC_QMM || slot == SC_WO {
                pts.r_q = tr.challenge_fp2_vec(lt);
            }
            // M-2: the four matmuls do NOT share one output width. The Q and
            // the output projection write the full width; the key and value
            // projections write `kv_heads * head_dim`.
            let kvw = sh.kv_heads * sh.head_dim;
            // NATIVE R12 (F2): `Wq` writes the QUERY axis (`q_pad`) and reads
            // the model axis; `Wo` reads the query axis and writes the model
            // axis. At every profile before R12 `q_pad == d_pad`, so no
            // challenge length, coordinate or fold moves.
            let (plane, w, outer, inner): (usize, &[i8], usize, usize) = match slot {
                SC_QMM => (ids.at(A_Y), ctx.public.wq.as_slice(), sh.q_pad(), sh.d_pad),
                SC_KMM => (ids.at(A_Y), ctx.public.wk.as_slice(), kvw, sh.d_pad),
                SC_VMM => (ids.at(A_Y), ctx.public.wv.as_slice(), kvw, sh.d_pad),
                _ => (ids.at(A_O8), ctx.public.wo.as_slice(), sh.d_pad, sh.q_pad()),
            };
            let r_j = tr.challenge_fp2_vec(lg(outer));
            let point = cat(&[&pts.r_q, &r_j]);
            let mut coords = fixed(&pts.r_q);
            coords.extend(rho(0..lg(inner)));
            b.a_at(plane, coords, 0)?;
            // w is (output j, input i): sum_j eq(r_j, j) w[j, i]
            let weights=eq_table_msb(&r_j);
            let folded=if sh.accuracy_stack()==crate::private_block::accuracy_precision::Stack::Legacy {
                fold_rows_i8(w,outer,inner,&weights)
            } else {
                use crate::private_block::accuracy_fold::{Site,Axis,coefficients,fold};
                let data=ctx.accuracy.ok_or("R13 matmul requires bound accuracy data")?;
                let site=match slot {SC_QMM=>Site::Q,SC_KMM=>Site::K,SC_VMM=>Site::V,_=>Site::O};
                fold(w,outer,inner,Axis::Rows,&coefficients(sh,data,site)?,&weights)?
            };
            b.public(folded);
            match slot {
                SC_QMM => pts.pq = point,
                SC_KMM => pts.pk = point,
                SC_VMM => pts.pv = point,
                _ => pts.p_a = point,
            }
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        // **THE TWO BILINEAR SLOTS, AS REPAIRED BY STAGE 20 (finding
        // S19-F1).** Both raise a claim of the form
        //
        // ```text
        //     target~(r_h, ...) = sum_h eq(r_h, h) * X~(.., h, ..) * Y~(.., g(h), ..)
        // ```
        //
        // where `g(h)` — the key-value GROUP of query head slot `h` — is the
        // TOP `lkv` bits of `h` (C-1, the head permutation). Until stage 20
        // both factors took the group as a FIXED coordinate `r_h[..lkv]` and
        // the slot summed only over the inner axis. That is WRONG whenever
        // `lkv > 0`: the extension of a product that shares a variable is not
        // the product of the extensions (the product is quadratic in the
        // shared bits), and the honest prover and the honest verifier then
        // disagree the moment the key-value groups carry different
        // activations — a COMPLETENESS failure, reproduced by the security
        // owner.
        //
        // The repair splits `r_h = (r_g, r_hj)` — `r_g` the `lkv` group bits,
        // `r_hj` the query head WITHIN its group — and sums over the group:
        //
        // ```text
        //     = sum_{g in {0,1}^lkv} eq(r_g, g) * sum_{inner} X~(.., (g, r_hj), ..) * Y~(.., g, ..)
        // ```
        //
        // which is an identity, because `Y` does not depend on `hj` and `X` is
        // multilinear in those bits, so `sum_hj eq(r_hj, hj) X~(.., (g,hj), ..)
        // = X~(.., (g, r_hj), ..)`. So the slot gains `lkv` main rounds, a
        // PUBLIC `eq(r_g, .)` over the leading `lkv` variables and one degree.
        //
        // **`lkv = 0` (the frozen toy, `kv_heads = 1`) reduces to the old path
        // BYTE FOR BYTE**: no variable, no public table, no degree, the same
        // closure `v[0] * v[1]`, the same transcript.
        //
        // The variable order is the same on both sides and in both slots:
        // variables `0 .. lkv` are the group `g`, variables `lkv ..` are the
        // slot's own inner axis. `Tab::Eq { start: 0 }` reads the LEADING
        // `lkv` variables, which is where the group sits, because coordinates
        // are most-significant-first everywhere in this module.
        SC_SCORE => {
            let r_h = tr.challenge_fp2_vec(lh);
            let r_t = tr.challenge_fp2_vec(lt);
            let r_j = tr.challenge_fp2_vec(lt);
            pts.p_s = cat(&[&r_h, &r_t, &r_j]);
            // `r_h` splits into the key-value GROUP bits `r_g` — the top `lkv`
            // entries, C-1's high bits of the head slot — and `r_hj`, the
            // query head WITHIN its group. `r_hj` is the tail, so it is built
            // as a copy of `r_h` with the group split off.
            let r_g = &r_h[..lkv];
            let mut r_hj = cat(&[&r_h]);
            r_hj = r_hj.split_off(lkv);
            let ig = Gate(b.group_eq(r_g));
            // the head-dimension segment of the slot's variables, one copy per
            // factor, because a coordinate list owns its entries
            let mut tq = rho(0..lkv + ldh);
            tq = tq.split_off(lkv);
            let mut tk = rho(0..lkv + ldh);
            tk = tk.split_off(lkv);
            // two private factors: qr is masked in extension round 0, kr in round 1
            // `A_QR8` lives on `Dom::Q = (t, head slot, c)`; the head slot is
            // `(g, r_hj)` — the group SUMMED, the within-group head fixed.
            let mut cq = fixed(&r_t);
            cq.extend(rho(0..lkv));
            cq.extend(fixed(&r_hj));
            cq.extend(tq);
            let iq = b.a_at(ids.at(A_QR8), cq, 0)?;
            // `A_KR8` lives on `Dom::Kv = (j, group, c)`: the group is the
            // SAME summed variable, which is the whole point of the repair
            // (C-1 / trap T-3).
            let mut ck = fixed(&r_j);
            ck.extend(rho(0..lkv));
            ck.extend(tk);
            let ik = b.a_at(ids.at(A_KR8), ck, 1)?;
            b.finish(Box::new(move |v: &[Fp2]| ig.at(v).mul(v[iq]).mul(v[ik])), vec![])
        }
        SC_PV => {
            let r_h = tr.challenge_fp2_vec(lh);
            let r_t = tr.challenge_fp2_vec(lt);
            let r_i = tr.challenge_fp2_vec(ldh);
            pts.p_o = cat(&[&r_t, &r_h, &r_i]);
            let r_g = &r_h[..lkv];
            let mut r_hj = cat(&[&r_h]);
            r_hj = r_hj.split_off(lkv);
            let ig = Gate(b.group_eq(r_g));
            // the source-token segment of the slot's variables, one copy per factor
            let mut tp = rho(0..lkv + lt);
            tp = tp.split_off(lkv);
            // `A_P` lives on `Dom::S = (head slot, t, s)`
            let mut cp = rho(0..lkv);
            cp.extend(fixed(&r_hj));
            cp.extend(fixed(&r_t));
            cp.extend(tp);
            let ip = b.a_at(ids.at(A_P), cp, 0)?;
            // `A_V8` lives on `Dom::Kv = (s, group, i)`
            let mut cv = rho(0..lkv + lt);
            cv = cv.split_off(lkv);
            cv.extend(rho(0..lkv));
            cv.extend(fixed(&r_i));
            let iv = b.a_at(ids.at(A_V8), cv, 1)?;
            b.finish(Box::new(move |v: &[Fp2]| ig.at(v).mul(v[ip]).mul(v[iv])), vec![])
        }
        // The three feed-forward matmuls (T2 section C.1). The two weight
        // matrices of the gate and up share one row point `r_tf`, mirroring
        // SC_KMM / SC_VMM reusing SC_QMM's `r_q`; the two claim points on
        // A_YM still differ through each slot's own rho, so each keeps its own
        // reserved pair. SC_DMM is the one slot that reads an f-cube plane
        // (A_H16) and publishes a d-cube point (p_z).
        SC_GMM | SC_UMM | SC_DMM => {
            if slot == SC_GMM {
                pts.r_tf = tr.challenge_fp2_vec(lt);
            }
            // SC_DMM draws its own row point `r_td`; the other two reuse `r_tf`
            let r_row = if slot == SC_DMM { tr.challenge_fp2_vec(lt) } else { pts.r_tf.clone() };
            let r_j = tr.challenge_fp2_vec(if slot == SC_DMM { ld } else { lf });
            let (plane, w, rows, cols): (usize, &[i8], usize, usize) = match slot {
                SC_GMM => (ids.at(A_YM), ctx.ff.wg_t.as_slice(), sh.d_pad, sh.f_pad),
                SC_UMM => (ids.at(A_YM), ctx.ff.wu_t.as_slice(), sh.d_pad, sh.f_pad),
                _ => (ids.at(A_H16), ctx.ff.wd_t.as_slice(), sh.f_pad, sh.d_pad),
            };
            let mut coords = fixed(&r_row);
            coords.extend(rho(0..if slot == SC_DMM { lf } else { ld }));
            b.a_at(plane, coords, 0)?;
            // w is (input i, output j): sum_j eq(r_j, j) w[i, j]
            let weights=eq_table_msb(&r_j);
            let folded=if sh.accuracy_stack()==crate::private_block::accuracy_precision::Stack::Legacy {
                fold_cols_i8(w,rows,cols,&weights)
            } else {
                use crate::private_block::accuracy_fold::{Site,Axis,coefficients,fold};
                let data=ctx.accuracy.ok_or("R13 FFN matmul requires bound accuracy data")?;
                let site=match slot {SC_GMM=>Site::Gate,SC_UMM=>Site::Up,_=>Site::Down};
                fold(w,rows,cols,Axis::Columns,&coefficients(sh,data,site)?,&weights)?
            };
            b.public(folded);
            let point = cat(&[&r_row, &r_j]);
            match slot {
                SC_GMM => pts.p_g = point,
                SC_UMM => pts.p_u = point,
                _ => pts.p_z = point,
            }
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_DZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::D));
            let n_help = sh.helpers(Dom::D);
            let mu = tr.challenge_fp2_vec(11 + n_help + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            b.eq(&tau, 0);
            b.eq(&pts.p_a, 0);
            b.eq(&pts.p_z, 0);
            // The two norm gains are the PADDED vectors of ruling P-2: zero
            // off the width's support, so a padded column contributes nothing
            // to the gain factor of the norm relation.
            let (dp, nd) = (sh.d_pad, sh.size(Dom::D));
            let ig = b.public((0..nd).map(|x| k(i64::from(ctx.public.gamma_a[x % dp]))).collect());
            let igm = b.public((0..nd).map(|x| k(i64::from(ctx.ff.gamma_m[x % dp]))).collect());
            let idx = b.a_range(ids.at(A_X), ids.at(A_RDL))?;
            let (i_nr, i_ns): (Vec<usize>, Vec<usize>) = ((0..ln).map(|kk| b.tab(ids.nr(kk))).collect(), (0..ln).map(|kk| b.tab(ids.ns(kk))).collect());
            let (i_mr, i_ms): (Vec<usize>, Vec<usize>) = ((0..ln).map(|kk| b.tab(ids.mr(kk))).collect(), (0..ln).map(|kk| b.tab(ids.ms(kk))).collect());
            let id = b.a_slice(lay.a_off[ids.at(A_D)], lt, rho(0..lt), 0)?;
            let idm = b.a_slice(lay.a_off[ids.at(A_DM)], lt, rho(0..lt), 0)?;
            let h0 = b.h(hids.first_helper(Dom::D))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::D, j))?;
            }
            let lks = lk_tables(lay, Dom::D, &b.shaped, g_u8);
            // NATIVE LANE: `tn`, the two norms' `Cn` and the attention-output
            // shift are the SHAPE's (the frozen values at every registered
            // shape, so no frozen coefficient moves)
            let (k_num, k_num_m) = (k(2 * sh.norm_cn_a), k(2 * sh.norm_cn_m));
            let (k_dv, k_den) = (k(1i64 << sh.norm_tn), k(1i64 << (sh.norm_tn + 1)));
            let k_ao_half = k(super::witness::half(sh.sh_ao));
            // **STAGE 35, LEVER (b)(iii): the public constants as BASE field
            // elements.** Every one of these is `Fp2::from_i64` of a public
            // integer of the profile, so its imaginary part is zero, and for
            // such a constant `x.mul(c)` IS `x.mul_base(c.c0)`: `Fp2::mul`
            // computes `(a c0 + b c1 * 7, a c1 + b c0)` and `c1 = 0`
            // collapses it to `mul_base`'s two products instead of five.
            // That is an identity of the implementation, not a ring law, and
            // `s35_tests::multiplying_by_a_constant_with_no_imaginary_part_is_exactly_mul_base`
            // asserts it on all thirteen constants of the two arms. `lw`
            // builds `limbs`'s weight vector out of the SAME `pow256(kk)`
            // the fold used, so the byte-limb decomposition is unchanged
            // term for term — except that the `256^0` weight is dropped in
            // the closure instead of being paid as a multiply by one, which
            // is what the hand-written `l2` and `l3` already do.
            let (b_num, b_num_m, b_dv, b_den, b_p1) = (k_num.c0, k_num_m.c0, k_dv.c0, k_den.c0, p1.c0);
            let (b_ao, b_z) = (k(1i64 << sh.sh_ao).c0, k(1i64 << sh.sh_z).c0);
            let k_z_half = k(super::witness::half(sh.sh_z));
            let lw = |ix: &[usize]| -> Vec<(usize, Fp)> { ix.iter().enumerate().map(|(kk, i)| (*i, pow256(kk).c0)).collect() };
            let (w_nr, w_ns, w_mr, w_ms) = (lw(&i_nr), lw(&i_ns), lw(&i_mr), lw(&i_ms));
            let hosted = vec![(SC_WO, nu[0]), (SC_DMM, nu[1])];
            // **S9 part 4 on `Dom::D`.** Every one of the domain's planes is
            // ZERO-rule, and all of them are already pushed by `a_range`, so
            // the term costs no new claim site. `gd` gates the eleven
            // inhomogeneous clauses and BOTH host terms: `SC_WO` / `SC_DMM`
            // publish a matmul output whose weight matrix vanishes off the
            // support (ruling P-2), so their claimed value is already zero on
            // a padded position and the gated host matches it.
            let gd = Gate(b.supp(Dom::D, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::D).iter().map(|p| b.tab(*p)).collect();
                pz.mu = mu[11 + n_help];
                pz.add(gd.0, &planes, zeta);
            }
            // **STAGE 35, the differential gate.** The closure's captures are
            // handed to `s35_tests`, which holds the body of this arm as it
            // stood at `89e393f` verbatim and compares the two on random
            // table vectors at every definition. `cfg(test)` only: nothing
            // below is compiled into a production build.
            #[cfg(test)]
            let s35 = super::s35_tests::Dzc {
                idx: idx.clone(),
                ig,
                igm,
                id,
                idm,
                h0,
                i_nr: i_nr.clone(),
                i_ns: i_ns.clone(),
                i_mr: i_mr.clone(),
                i_ms: i_ms.clone(),
                lks: lks.iter().map(|l| super::s35_tests::LkT { terms: l.terms.clone(), cst: l.cst }).collect(),
                mu: mu.clone(),
                nu: nu.clone(),
                alpha,
                gd: super::s35_tests::Gate(gd.0),
                pz: super::s35_tests::PadTerm { groups: pz.groups.clone(), mu: pz.mu },
                norm_cn_a: sh.norm_cn_a,
                norm_cn_m: sh.norm_cn_m,
                norm_tn: sh.norm_tn,
                sh_ao: sh.sh_ao,
                sh_z: sh.sh_z,
            };
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l2 = |o: usize| at(o).add(at(o + 1).mul_base(b_p1));
                // `limbs` with the weights as base constants and the `256^0`
                // multiply by one dropped: the first limb IS the running sum
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (x, y, ao, x1, d) = (at(A_X), at(A_Y), at(A_AO), at(A_X1), v[id]);
                let (nm, x2, z16, dm) = (at(A_YM), at(A_X2), at(A_Z16), v[idm]);
                let (nr, ns) = (lb(&w_nr), lb(&w_ns));
                let (mr, ms) = (lb(&w_mr), lb(&w_ms));
                // **STAGE 35, LEVER (b)(ii): the two sub-products this arm
                // recomputes.** `k_den * d` is formed twice — once inside
                // c0's `k_den.mul(y).mul(d)`, which is `(k_den * d) * y`
                // reassociated, and once outright in c1 — and `k_den * dm`
                // twice in the same way in c6 and c7. Each is formed once
                // here. They are the ONLY pair the check's §5 found and the
                // only pair reading this arm turns up: `at(p)`, the two norm
                // gains, `delta`-like intermediates and the four limb folds
                // are already shared by a `let`.
                let (kd, kdm) = (d.mul_base(b_den), dm.mul_base(b_den));
                let c0 = v[ig].mul(x).mul_base(b_num).add(d.mul_base(b_dv)).sub(kd.mul(y)).sub(nr);
                let c1 = ns.add(nr).add(Fp2::ONE).sub(kd);
                let c2 = x.add(k(32768)).sub(l2(A_XL0));
                let c3 = ao.add(k(32768)).sub(l2(A_AL0));
                let c4 = x1.add(k(32768)).sub(l2(A_X1L0));
                let c5 = x1.sub(x).sub(ao);
                // norm_m: the identical relation with gamma_m and xres1 (T1 C.1)
                let c6 = v[igm].mul(x1).mul_base(b_num_m).add(dm.mul_base(b_dv)).sub(kdm.mul(nm)).sub(mr);
                let c7 = ms.add(mr).add(Fp2::ONE).sub(kdm);
                // residual 2 and z16's int16 class (T1 C.2, T2 C.2)
                let c8 = x2.add(k(32768)).sub(l2(A_X2L0));
                let c9 = x2.sub(x1).sub(z16);
                let c10 = z16.add(k(32768)).sub(l2(A_ZL0));
                let g = gd.at(v);
                // **STAGE 35, LEVER (b)(i): the support gate hoisted out of
                // the clause batch.** `sum_i mu_i g c_i = g sum_i mu_i c_i`
                // is distributivity in a commutative ring, and this one is
                // exact — `Fp` keeps canonical representatives everywhere
                // (`zkp-core/src/field.rs:1-9`), so the reassociation is not
                // an approximation and the field element out is the same
                // word. ELEVEN multiplications by `g` become ONE. The
                // stage-34 IR already encodes THIS grouping, so its equality
                // oracle covers the rewrite at every registered shape and
                // both pad branches, and `s35_tests` compares it against the
                // `89e393f` body on every definition.
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]) {
                    clauses = clauses.add(m.mul(c));
                }
                let zc = helper_sum(v, &lks, h0, alpha, &mu[11..]).add(pz.eval(v)).add(g.mul(clauses));
                let host_wo = ao.mul_base(b_ao).add(at(A_RAL)).sub(k_ao_half);
                let host_dmm = z16.mul_base(b_z).add(at(A_RDL)).sub(k_z_half);
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_wo)).add(nu[1].mul(v[2]).mul(g).mul(host_dmm))
            };
            #[cfg(test)]
            s35.check(b.tabs.len(), &poly);
            b.finish(Box::new(poly), hosted)
        }
        // The f-cube zero-check (T2 section C.1): the product, the two int16
        // decompositions, the activation pair lookup and the Dom::F LogUp
        // helpers, hosting the gate and up matmuls.
        SC_FZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::F));
            let n_help = sh.helpers(Dom::F);
            let mu = tr.challenge_fp2_vec(4 + n_help + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            b.eq(&tau, 0);
            b.eq(&pts.p_g, 0);
            b.eq(&pts.p_u, 0);
            let idx = b.a_range(ids.at(A_G8), ids.at(A_RH1))?;
            let h0 = b.h(hids.first_helper(Dom::F))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::F, j))?;
            }
            // E-17: the activation helper is addressed by the TABLE INDEX the
            // builder returns, never by the plane constant H_FACT
            let i_fact = b.h(hids.fact())?;
            let lks = lk_tables(lay, Dom::F, &b.shaped, g_u8);
            let hosted = vec![(SC_GMM, nu[0]), (SC_UMM, nu[1])];
            // S9 part 4 on `Dom::F`. `f_act` is the activation PAIR LOOKUP's
            // helper relation — the LogUp arm — and is NOT gated: gating it
            // would drop the padded positions out of the value-0 identity
            // while their multiplicities still count them (§3.7a).
            let gf = Gate(b.supp(Dom::F, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::F).iter().map(|p| b.tab(*p)).collect();
                pz.mu = mu[4 + n_help];
                pz.add(gf.0, &planes, zeta);
            }
            // ROUND 2: the product and gate shifts are the SHAPE's (the frozen
            // SH_H_PROD / SH_G at every registered shape)
            let (k_h, k_h_half, k_g, k_g_half) = (k(1i64 << sh.sh_h), k(super::witness::half(sh.sh_h)), k(1i64 << sh.sh_g), k(super::witness::half(sh.sh_g)));
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l2 = |o: usize| at(o).add(at(o + 1).mul(p1));
                let (g8, a16, u16, h16) = (at(A_G8), at(A_A16), at(A_U16), at(A_H16));
                let f0 = a16.mul(u16).sub(k_h.mul(h16)).sub(l2(A_RH0)).add(k_h_half);
                let f1 = u16.add(k(32768)).sub(l2(A_UL0));
                let f2 = h16.add(k(32768)).sub(l2(A_HL0));
                let f_act = v[i_fact].mul(alpha.sub(g8.add(k(128)).add(beta.mul(a16)).add(g_act))).sub(Fp2::ONE);
                let g = gf.at(v);
                let mut zc = helper_sum(v, &lks, h0, alpha, &mu[4..]).add(mu[3].mul(f_act)).add(pz.eval(v));
                for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    zc = zc.add(m.mul(g).mul(c));
                }
                let host_g = k_g.mul(g8).add(at(A_RGL)).sub(k_g_half);
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                let host_u = u16;
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_g)).add(nu[1].mul(v[2]).mul(g).mul(host_u))
            };
            b.finish(Box::new(poly), hosted)
        }
        SC_QZC | SC_KVZC => {
            let q = slot == SC_QZC;
            let (dom, first, last, src) = if q { (Dom::Q, A_Q8, A_RO1, A_Q8) } else { (Dom::Kv, A_K8, A_RKRL, A_K8) };
            let log = sh.log(dom);
            let tau = tr.challenge_fp2_vec(log);
            let n_help = sh.helpers(dom);
            let mu = tr.challenge_fp2_vec(1 + n_help + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            b.eq(&tau, 0);
            b.eq(if q { &pts.pq } else { &pts.pk }, 0);
            b.eq(if q { &pts.p_o } else { &pts.pv }, 0);
            // S7 / M-1: the key-value side is laid out over `kv_heads` heads,
            // and step C puts both tables on the PADDED domain stride.
            let (ct, st) = rope_tables_at(sh, ctx.public, dom);
            let ic = b.public(ct);
            let is = b.public(st);
            let idx = b.a_range(ids.at(first), ids.at(last))?;
            let i_src = idx[src];
            let (i_rot, i_rot_rem) = if q { (idx[A_QR8], idx[A_RQRL]) } else { (idx[A_KR8], idx[A_RKRL]) };
            // the partner half: the most significant bit of i' flipped, which
            // sits at `log - log2(head_dim)` (trap T-8); its own site, its own pair
            let mut cf = rho(0..log);
            cf[log - ldh] = Coord::Flip(log - ldh);
            let iflip = b.a_at(ids.at(src), cf, 0)?;
            let h0 = b.h(hids.first_helper(dom))?;
            for j in 1..n_help {
                b.h(hids.helper(dom, j))?;
            }
            let lks = lk_tables(lay, dom, &b.shaped, g_u8);
            // ROUND 2: the Q/K/V and PV-output shifts are the SHAPE's (the
            // frozen SH_QKV / SH_O at every registered shape)
            let (k_qkv, half) = (k(1i64 << sh.sh_qkv), k(super::witness::half(sh.sh_qkv)));
            let (k_o, k_o_half) = (k(1i64 << sh.sh_o), k(super::witness::half(sh.sh_o)));
            let hosted = if q { vec![(SC_QMM, nu[0]), (SC_PV, nu[1])] } else { vec![(SC_KMM, nu[0]), (SC_VMM, nu[1])] };
            // S9 part 4 on `Dom::Q` / `Dom::Kv`. The RoPE clause is
            // inhomogeneous (the `2^(SH_ROPE-1)` bias) and takes the gate; so
            // do both host terms. The PARTNER slice `iflip` reads the same
            // plane at a flipped coordinate and needs no group of its own.
            let gq = Gate(b.supp(dom, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, dom).iter().map(|p| b.tab(*p)).collect();
                pz.mu = mu[1 + n_help];
                pz.add(gq.0, &planes, zeta);
            }
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let (rot, rot_rem) = (v[i_rot], v[i_rot_rem]);
                let rope = v[ic].mul(v[i_src]).add(v[is].mul(v[iflip])).sub(k(1 << SH_ROPE).mul(rot)).sub(rot_rem).add(k(1 << (SH_ROPE - 1)));
                let g = gq.at(v);
                let zc = mu[0].mul(g).mul(rope).add(helper_sum(v, &lks, h0, alpha, &mu[1..])).add(pz.eval(v));
                let (host1, host2) = if q {
                    (
                        k_qkv.mul(at(A_Q8)).add(at(A_RQL)).sub(half),
                        k_o.mul(at(A_O8)).add(at(A_RO0)).add(at(A_RO1).mul(p1)).sub(k_o_half),
                    )
                } else {
                    (k_qkv.mul(at(A_K8)).add(at(A_RKL)).sub(half), k_qkv.mul(at(A_V8)).add(at(A_RVL)).sub(half))
                };
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host1)).add(nu[1].mul(v[2]).mul(g).mul(host2))
            };
            b.finish(Box::new(poly), hosted)
        }
        // **NATIVE R9 (D30): the softmax zero-check on a DD profile.** Each
        // score entry keeps S8, RSL, ZSEL, E and P and the argmax clauses c0,
        // c1, its byte lookups (sym(s8), rsl) and the exp pair; it carries NO
        // division clause and no quotient / remainder limbs. Instead ONE
        // tuple lookup puts (key = the row's Sum, mask * E, P) into its row's
        // dictionary: `h_t * (alpha - (gamma TAG_DD + Sum + beta mask E +
        // beta^2 P)) = 1`. Membership forces P = floor(mask E 2^F_P / Sum),
        // because every dictionary slot proves exactly that quotient (`SC_DD`)
        // and every value mask * E takes is in the public e column (B-7).
        // Hosts 07 and 10 as before. A DD profile has no padded score
        // position (`Shape::check_dd_geometry`).
        SC_SZC if sh.dd_cap > 0 => {
            if pad_on {
                return Err("private block: a DD profile's softmax zero-check would host a pad term; D30 here needs an unpadded score domain".into());
            }
            let tau = tr.challenge_fp2_vec(sh.log(Dom::S));
            let n_help = sh.helpers(Dom::S);
            let mu = tr.challenge_fp2_vec(2 + n_help + 2);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let lam = pts.lam_z;
            b.eq(&tau, 0);
            b.eq(&pts.p_ht, 0);
            b.eq(&pts.p_s, 0);
            let im = b.public(causal_mask_at(sh));
            let idx = b.a_range(ids.at(A_S8), ids.at(A_P))?;
            let lht = sh.log(Dom::Ht);
            let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)?;
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            let h0 = b.h(hids.first_helper(Dom::S))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::S, j))?;
            }
            let ihx = b.h(hids.sexp())?;
            let iht = b.h(hids.stuple())?;
            let lks = lk_tables(lay, Dom::S, &b.shaped, g_u8);
            let b_shs = k(1i64 << sh.sh_s).c0;
            let k_s_half = k(super::witness::half(sh.sh_s));
            let per_row = (sh.size(Dom::S) / sh.size(Dom::Ht)) as i64;
            let hosted = vec![(SC_RS, nu[0].mul(k(per_row))), (SC_SCORE, nu[1])];
            let ght = Gate(b.supp(Dom::Ht, cube)?);
            let gs = Gate(b.supp(Dom::S, cube)?);
            let (g_dd, beta2) = (ctx.g_dd, beta.mul(beta));
            let keyed = !dd_lapse(DD_LAPSE_DROP_KEY);
            let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let host_rs = nu[0].mul(ght.at(v)).mul(v[isum].add(lam));
                let host_s = nu[1].mul(gs.at(v)).mul(at(A_S8).mul_base(b_shs).add(at(A_RSL)).sub(k_s_half));
                let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
                let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
                let c0 = zsel.mul(zsel).sub(zsel);
                let c1 = zsel.mul(delta);
                let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
                // the tuple lookup into this row's dictionary (D30)
                let key = if keyed { sum } else { Fp2::ZERO };
                let ct = v[iht].mul(alpha.sub(g_dd.add(key).add(beta.mul(mask.mul(e))).add(beta2.mul(p)))).sub(Fp2::ONE);
                let clauses = mu[0].mul(c0).add(mu[1].mul(c1));
                let zc = helper_sum(v, &lks, h0, alpha, &mu[2..2 + n_help]).add(mu[2 + n_help].mul(cx)).add(mu[3 + n_help].mul(ct)).add(gs.at(v).mul(clauses));
                v[0].mul(zc).add(v[1].mul(host_rs)).add(v[2].mul(host_s))
            };
            b.finish(Box::new(poly), hosted)
        }
        SC_SZC => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::S));
            let n_help = sh.helpers(Dom::S);
            let mu = tr.challenge_fp2_vec(5 + n_help + 1 + n_pad);
            let nu = nonzero(tr.challenge_fp2_vec(2))?;
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            let lam = pts.lam_z;
            b.eq(&tau, 0);
            b.eq(&pts.p_ht, 0);
            b.eq(&pts.p_s, 0);
            let im = b.public(causal_mask_at(sh));
            // the `Dom::S` block runs to the LAST `sigma_s` limb, which the toy
            // has no name for when `limbs_sigma_s` is three (S8)
            let idx = b.a_range(ids.at(A_S8), ids.sg(ls - 1))?;
            let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
            let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
            let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
            let lht = sh.log(Dom::Ht);
            let imx = b.a_slice(lay.a_off[ids.at(A_MX)], lht, rho(0..lht), 0)?;
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            let h0 = b.h(hids.first_helper(Dom::S))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::S, j))?;
            }
            let ihx = b.h(hids.sexp())?;
            let lks = lk_tables(lay, Dom::S, &b.shaped, g_u8);
            // **STAGE 35, LEVER (b)(iii)** — see the note in `SC_DZC` above:
            // a constant with no imaginary part makes `x.mul(c)` exactly
            // `x.mul_base(c.c0)`, two base multiplications instead of five,
            // and `lw` is `limbs`'s own `pow256(kk)` weight vector.
            // ROUND 2: the score shift is the SHAPE's (the frozen SH_S at every
            // registered shape)
            let (b_fp, b_shs) = (k(1 << F_P).c0, k(1i64 << sh.sh_s).c0);
            let k_s_half = k(super::witness::half(sh.sh_s));
            let lw = |ix: &[usize]| -> Vec<(usize, Fp)> { ix.iter().enumerate().map(|(kk, i)| (*i, pow256(kk).c0)).collect() };
            let (w_sr, w_sg, w_pl) = (lw(&i_sr), lw(&i_sg), lw(&i_pl));
            // the row-sum host term is constant in j: it sums to (the number of
            // j positions of the S cube per Ht position) * (Sum(p_ht) + lam_z)
            let per_row = (sh.size(Dom::S) / sh.size(Dom::Ht)) as i64;
            let hosted = vec![(SC_RS, nu[0].mul(k(per_row))), (SC_SCORE, nu[1])];
            // **S9 part 4 on `Dom::S` AND `Dom::Ht` (finding S9-F7).** This
            // slot is the only host of two domains: `Dom::Ht` has no
            // zero-check of its own and its two planes (`A_MX`, `A_SUM`) are
            // read here on the LEADING coordinates, so its indicator is
            // lifted over the trailing `j` axis and carries its own group.
            // `supp_S` would be WRONG for them: it is 0 wherever `j` pads,
            // which would force a TRUE row's maximum to zero. `host_rs` takes
            // the LIFTED `supp_Ht` and not `supp_S`, because it is constant
            // in `j` and `per_row` must stay the full `t_pad`.
            let ght = Gate(b.supp(Dom::Ht, cube)?);
            let gs = Gate(b.supp(Dom::S, cube)?);
            let mut pz = PadTerm::none();
            if pad_on {
                pz.mu = mu[5 + n_help + 1];
                if super::pad::zero_rule_a_planes(sh, ids, Dom::Ht) != vec![ids.at(A_MX), ids.at(A_SUM)] {
                    return Err("private block: a Dom::Ht plane is outside SC_SZC's pad-zero group".into());
                }
                pz.add(ght.0, &[imx, isum], zeta);
                let planes: Vec<usize> = super::pad::zero_rule_a_planes(sh, ids, Dom::S).iter().map(|p| b.tab(*p)).collect();
                pz.add(gs.0, &planes, zeta);
            }
            // **STAGE 35, the differential gate.** See the same block in
            // `SC_DZC` above: `cfg(test)` only, and it hands this arm's
            // captures to the verbatim `89e393f` body in `s35_tests`.
            #[cfg(test)]
            let s35 = super::s35_tests::Szc {
                idx: idx.clone(),
                im,
                imx,
                isum,
                ihx,
                h0,
                i_sr: i_sr.clone(),
                i_sg: i_sg.clone(),
                i_pl: i_pl.clone(),
                lks: lks.iter().map(|l| super::s35_tests::LkT { terms: l.terms.clone(), cst: l.cst }).collect(),
                mu: mu.clone(),
                nu: nu.clone(),
                n_help,
                lam,
                alpha,
                beta,
                g_exp,
                gs: super::s35_tests::Gate(gs.0),
                ght: super::s35_tests::Gate(ght.0),
                pz: super::s35_tests::PadTerm { groups: pz.groups.clone(), mu: pz.mu },
                sh_s: sh.sh_s,
            };
            let groups = vec![
                sumcheck::EqualityGroup { point: tau, start: 0, bracket_degree: if pad_on { 4 } else { 3 } },
                sumcheck::EqualityGroup { point: pts.p_ht.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
                sumcheck::EqualityGroup { point: pts.p_s.clone(), start: 0, bracket_degree: if pad_on { 2 } else { 1 } },
            ];
            let bracket: GroupPoly = std::sync::Arc::new(move |group: usize, v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                if group == 1 {
                    return nu[0].mul(ght.at(v)).mul(v[isum].add(lam));
                }
                if group == 2 {
                    let host_s = at(A_S8).mul_base(b_shs).add(at(A_RSL)).sub(k_s_half);
                    return nu[1].mul(gs.at(v)).mul(host_s);
                }
                assert_eq!(group, 0);
                // `limbs` with base weights and the `256^0` multiply by one
                // dropped — the same `lb` as in `SC_DZC`
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (mask, s8, zsel, e, p, sum) = (v[im], at(A_S8), at(A_ZSEL), at(A_E), at(A_P), v[isum]);
                let sr = lb(&w_sr);
                // delta = max - masked score, the masked score being mask * (s8 + 127) - 127
                let delta = v[imx].sub(mask.mul(s8.add(k(-MASK_SCORE)))).add(k(-MASK_SCORE));
                let c0 = zsel.mul(zsel).sub(zsel);
                let c1 = zsel.mul(delta);
                let c2 = mask.mul(e).mul_base(b_fp).sub(p.mul(sum)).sub(sr);
                let c3 = lb(&w_sg).add(sr).add(Fp2::ONE).sub(sum);
                let c4 = p.sub(lb(&w_pl));
                let cx = v[ihx].mul(alpha.sub(delta.add(beta.mul(e)).add(g_exp))).sub(Fp2::ONE);
                let g = gs.at(v);
                // **STAGE 35, LEVER (b)(i)** — the same rewrite as in
                // `SC_DZC` above, and the same argument: FIVE multiplications
                // by the support gate become ONE. `ght` gates the row-sum
                // host term and `gs` the rest; only `gs` is hoisted, because
                // the two are different tables (finding S9-F7).
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([c0, c1, c2, c3, c4]) {
                    clauses = clauses.add(m.mul(c));
                }
                let zc = helper_sum(v, &lks, h0, alpha, &mu[5..5 + n_help]).add(mu[5 + n_help].mul(cx)).add(pz.eval(v)).add(g.mul(clauses));
                zc
            });
            let poly_bracket = bracket.clone();
            let poly = move |v: &[Fp2]| (0..3).fold(Fp2::ZERO,
                |a, group| a.add(v[group].mul(poly_bracket(group, v))));
            #[cfg(test)]
            s35.check(b.tabs.len(), &poly);
            let mut def = b.finish(Box::new(poly), hosted)?;
            def.groups = Some((groups, bracket));
            Ok(def)
        }
        // three (multiplicity, helper, public values) triples now: U8, exp and
        // the activation table under TAG_ACT (T2 section C.1)
        SC_TAB => {
            let tab_len = sh.size(Dom::Tab);
            let tau = tr.challenge_fp2_vec(sh.log(Dom::Tab));
            let mu = tr.challenge_fp2_vec(3 + n_pad);
            let zeta = if pad_on { nonzero(tr.challenge_fp2_vec(1))?[0] } else { Fp2::ZERO };
            let th = hids.table_helpers();
            b.eq(&tau, 0);
            b.a(ids.at(A_MU8))?;
            b.h(th[0])?;
            b.public(table_values_u8_at(tab_len, g_u8));
            b.a(ids.at(A_MEXP))?;
            b.h(th[1])?;
            b.public(table_values_exp_at(tab_len, ctx.public, beta, g_exp));
            b.a(ids.at(A_MACT))?;
            b.h(th[2])?;
            b.public(table_values_act_at(tab_len, ctx.ff, beta, g_act));
            // **S9 part 4 on `Dom::Tab`.** After the P-3 lift the table row
            // sits in a cube `1 << log_cols` wide, and the three histograms
            // AND the three table helpers are ZERO above index 255 — the fact
            // the lift rests on. The three helpers are already implied by
            // `r0` / `r1` / `r2` (a zero multiplicity forces a zero helper as
            // long as the padded table value is not `alpha`); the term states
            // the memo's table outright rather than relying on that.
            let mut pz = PadTerm::none();
            if pad_on {
                let si = b.supp(Dom::Tab, cube)?;
                // **FINDING F-2.** The `A` list was hard-coded and, alone
                // among the pad-zero groups, never checked against the
                // declared one, so a fourth `Dom::Tab` `A` plane would have
                // sat silently outside the term — the class of hole ruling
                // P-1 exists to close. The three table indices stay literal
                // because they are THIS slot's own push order (`eq` 0, then
                // multiplicity / helper / values three times), but the PLANES
                // they stand for are now checked against the declared lists,
                // both of them, by one function a test can also call.
                tab_group_is_declared(sh, ids, &[ids.at(A_MU8), ids.at(A_MEXP), ids.at(A_MACT)], &th)?;
                pz.mu = mu[3];
                pz.add(si, &[1, 4, 7], zeta);
                pz.add(si, &[2, 5, 8], zeta);
            }
            let poly = move |v: &[Fp2]| {
                let r0 = v[2].mul(alpha.sub(v[3])).sub(v[1]);
                let r1 = v[5].mul(alpha.sub(v[6])).sub(v[4]);
                let r2 = v[8].mul(alpha.sub(v[9])).sub(v[7]);
                v[0].mul(mu[0].mul(r0).add(mu[1].mul(r1)).add(mu[2].mul(r2)).add(pz.eval(v)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SC_ZS => {
            // The zero-sum row `u` lives on `h_dom(H_U) = Dom::Tab`, so the
            // all-ones vector is as long as THAT DOMAIN — not the row width
            // `N` and not the table size `U8_LEN`. The three coincide at the
            // toy; after the P-3 lift (S4) `Dom::Tab` sits at the row width and
            // this slot's cube grows with it, which is what §4.1 means by
            // "`SC_ZS`'s rounds 8 -> 14".
            b.public(vec![Fp2::ONE; sh.size(Dom::Tab)]);
            b.h(hids.u())?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        // **NATIVE R9 (D30; CHECK.md B-1..B-5): the dictionary zero-check.**
        // On the cube (h, t | k) of `dd_cap` slots per row, at EVERY slot — no
        // usage gate, no `k < n_E` indicator (B-1) — today's exact-division
        // relation, verbatim, with the public e column for `mask * E`:
        //   c2: e 2^F_P - P_dict Sum - rho_s = 0
        //   c3: rho_s + sigma_s + 1 - Sum = 0
        //   c4: P_dict = limbs(P_dict)
        // and the limbs' byte lookups with their top pins (the dictionary's own
        // helper planes), so 0 <= rho_s < Sum and P_dict is the floor quotient;
        // `Sum` is `A_SUM` read on the leading (h, t) variables, a claim site
        // of this slot (B-4). Then the TABLE helper of the committed table
        // side: `g (alpha - (gamma TAG_DD + Sum + beta e + beta^2 P_dict)) =
        // M_dd` (B-5), whose plane enters the single value-0 sum claim with
        // sign -1 (`HIds::is_table`, D30 condition 3). Every plane is
        // committed (`A`: P_dict, its limbs, M_dd before every LogUp challenge,
        // B-2; `H`: the helpers) and opened only at its own reserved site.
        SC_DD => {
            if sh.dd_cap == 0 {
                return Err("private block: the dictionary slot at a profile without a dictionary".into());
            }
            if pad_on {
                return Err("private block: a DD profile's dictionary would host a pad term; D30 here needs an unpadded dictionary".into());
            }
            let ldd = sh.log(Dom::Dd);
            let tau = tr.challenge_fp2_vec(ldd);
            let n_help = sh.helpers(Dom::Dd);
            let mu = tr.challenge_fp2_vec(3 + n_help + 1);
            b.eq(&tau, 0);
            let _ = b.a_range(ids.pdict(), ids.mdd())?;
            let (ipd, imd) = (b.tab(ids.pdict()), b.tab(ids.mdd()));
            let i_pl: Vec<usize> = (0..lp).map(|kk| b.tab(ids.pl(kk))).collect();
            let i_sr: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sr(kk))).collect();
            let i_sg: Vec<usize> = (0..ls).map(|kk| b.tab(ids.sg(kk))).collect();
            let lht = sh.log(Dom::Ht);
            let isum = b.a_slice(lay.a_off[ids.at(A_SUM)], lht, rho(0..lht), 0)?;
            // the public e column, constant in (h, t): slot k's value
            let ecol = ctx.public.dd_e_column(sh.dd_cap)?;
            let cap = sh.dd_cap;
            let ie = b.public((0..(1usize << ldd)).map(|x| k(ecol[x % cap])).collect());
            let h0 = b.h(hids.first_helper(Dom::Dd))?;
            for j in 1..n_help {
                b.h(hids.helper(Dom::Dd, j))?;
            }
            let ig = b.h(hids.gdd())?;
            let lks = lk_tables(lay, Dom::Dd, &b.shaped, g_u8);
            let b_fp = k(1 << F_P).c0;
            let lw = |ix: &[usize]| -> Vec<(usize, Fp)> { ix.iter().enumerate().map(|(kk, i)| (*i, pow256(kk).c0)).collect() };
            let (w_sr, w_sg, w_pl) = (lw(&i_sr), lw(&i_sg), lw(&i_pl));
            let (g_dd, beta2) = (ctx.g_dd, beta.mul(beta));
            let keyed = !dd_lapse(DD_LAPSE_DROP_KEY);
            // the D-3 lapse's public "used slot" gate: 0 on every row's last
            // slot (test builds, lapsed only)
            let gate = if dd_lapse(DD_LAPSE_GATE_LAST_SLOT) { Some(b.public((0..(1usize << ldd)).map(|x| if x % cap == cap - 1 { Fp2::ZERO } else { Fp2::ONE }).collect())) } else { None };
            let poly = move |v: &[Fp2]| {
                let lb = |w: &[(usize, Fp)]| match w.split_first() {
                    None => Fp2::ZERO,
                    Some(((i0, _), rest)) => rest.iter().fold(v[*i0], |a, (i, c)| a.add(v[*i].mul_base(*c))),
                };
                let (pd, md, sum, e) = (v[ipd], v[imd], v[isum], v[ie]);
                let sr = lb(&w_sr);
                let c2 = e.mul_base(b_fp).sub(pd.mul(sum)).sub(sr);
                let c3 = lb(&w_sg).add(sr).add(Fp2::ONE).sub(sum);
                let c4 = pd.sub(lb(&w_pl));
                let key = if keyed { sum } else { Fp2::ZERO };
                let ctab = v[ig].mul(alpha.sub(g_dd.add(key).add(beta.mul(e)).add(beta2.mul(pd)))).sub(md);
                let division = mu[0].mul(c2).add(mu[1].mul(c3)).add(mu[2].mul(c4));
                let division = match gate {
                    Some(gi) => v[gi].mul(division),
                    None => division,
                };
                v[0].mul(division.add(helper_sum(v, &lks, h0, alpha, &mu[3..3 + n_help])).add(mu[3 + n_help].mul(ctab)))
            };
            b.finish(Box::new(poly), vec![])
        }
        SC_IO_IN | SC_IO_OUT => {
            let tau = tr.challenge_fp2_vec(sh.log(Dom::D));
            b.eq(&tau, 0);
            // the block's two external endpoints: x_in and xres2 (D12 item 2)
            b.a(ids.at(if slot == SC_IO_IN { A_X } else { A_X2 }))?;
            b.endpoint(if slot == SC_IO_IN { Cm::In } else { Cm::Out });
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1].sub(v[2]))), vec![])
        }
        _ => Err("private block: unknown slot".into()),
    }
}

/// All twenty-three slots in the declared order, then the functional list in the declared order.
///
/// **STAGE 11.** `ph` is the phase clock, and it is WRITE-ONLY: `ph.slot`
/// pushes a duration, the slot's public cube size and a memory reading, and
/// returns `()`. Nothing in this loop reads it back, so no slot's definition,
/// challenge, table or terminal can depend on whether timing is on. With
/// `HL_PB_TIMING` unset it returns on its first line.
pub(crate) fn argument(side: &mut Side, ctx: &Ctx, tr: &mut Transcript, ph: &mut super::timing::Phases) -> Result<Acc, String> {
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let sh = ctx.lay.shape();
    // NATIVE R9: THIS profile's slots — the twenty-three, plus the
    // dictionary zero-check on a DD profile (appended last)
    // [ZK60-METAL M3] the IR's own point record, carried beside `pts`
    #[cfg(feature = "gpu-metal")]
    // Every profile is offered (legacy and the R13 accuracy stacks): whether a
    // slot may run on the device is decided per slot by the runtime guard
    // below (the IR must equal THIS definition's closure), so a slot whose
    // IR does not model its profile stays on the CPU.
    let metal_on = matches!(side, Side::Prove { .. }) && crate::gpu::enabled();
    #[cfg(feature = "gpu-metal")]
    let metal_diag = std::env::var("HL_METAL_TIMING").map(|v| v == "1").unwrap_or(false);
    #[cfg(feature = "gpu-metal")]
    if metal_diag {
        eprintln!(
            "[ZK60-METAL] argument: prove={} accuracy_none={} legacy_stack={} gpu_enabled={} -> metal_on={metal_on} ({})",
            matches!(side, Side::Prove { .. }),
            ctx.accuracy.is_none(),
            sh.accuracy_stack() == crate::private_block::accuracy_precision::Stack::Legacy,
            crate::gpu::enabled(),
            sh.name
        );
    }
    #[cfg(feature = "gpu-metal")]
    let mut ipts = super::slot_ir::IrPoints::default();
    for slot in 0..sh.n_slots() {
        #[cfg(test)]
        super::capture::start_slot(side, tr);
        #[cfg(test)]
        super::run_capture::start_slot(side, tr);
        // The IR builder draws the same challenges, in the same order, as
        // `define` (slot_ir.rs); it runs on a CLONE taken just before `define`,
        // so it reads the very values `define` is about to draw and the real
        // transcript is untouched. A slot without an IR keeps the CPU path.
        #[cfg(feature = "gpu-metal")]
        let metal_ir = if metal_on {
            let mut twin = Transcript::clone_state(tr);
            match super::slot_ir::build_slot_ir(slot, ctx, &mut ipts, &mut twin) {
                Ok(ir) => Some(ir),
                Err(e) => {
                    if metal_diag {
                        eprintln!("[ZK60-METAL] slot {slot}: no IR ({e})");
                    }
                    super::metal_slot::note_cpu_slot(slot, false);
                    None
                }
            }
        } else {
            None
        };
        #[allow(unused_mut)]
        let mut def = define(slot, ctx, &mut pts, tr)?;
        #[cfg(feature = "gpu-metal")]
        if let Some(ir) = metal_ir {
            // RUNTIME GUARD: the IR (CPU interpreter) must equal THIS
            // definition's closure at random points of the whole space before
            // the device may evaluate it (Schwartz-Zippel: a wrong coefficient
            // survives a point with probability <= deg/|F|). The points come
            // from a local generator, never from the proof's randomness.
            if ir.tables.len() == def.tabs.len() && super::metal_slot::ir_matches_closure(&ir, &*def.poly, slot) {
                let (k0, k1, cf, base) = super::metal_slot::msl_round_kernels(&ir);
                def.metal = Some((format!("{k0}\n{k1}"), cf, base));
            } else {
                // NOT a device decline: this slot has no device path at this
                // profile (the IR models the legacy slot set; a DD profile
                // redefines slot 17 and appends the dictionary slot). It stays
                // on the CPU, which is correct; the guard's job is that a wrong
                // IR never reaches the GPU. Counted for the run's report.
                super::metal_slot::note_cpu_slot(slot, metal_diag);
            }
        }
        // ROUND 5: the slot's counted ELEMENT-TERMS, its sumcheck cube
        // `2^(main + extension rounds)` times its table count — a function of
        // the shape and the declared schedule, nothing private
        let n_tabs = def.tabs.len() as u64;
        run_slot(side, &mut acc, def, tr)?;
        let (main, ext, _) = sh.slots()[slot];
        ph.slot_work(slot, (1u64 << (main + ext)) * n_tabs);
    }
    let hosts = std::mem::take(&mut acc.host_fs);
    acc.fs.extend(hosts);
    if acc.fs.len() != sh.n_functionals() {
        return Err("private block: functional count differs from the declared schedule".into());
    }
    Ok(acc)
}
