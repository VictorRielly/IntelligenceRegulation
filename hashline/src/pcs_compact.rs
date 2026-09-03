//! [UPERF3-AF] A compact multilinear polynomial commitment behind `--pcs compact`.
//!
//! THE CONSTRUCTION (BaseFold-class: a batched-evaluation sumcheck whose
//! challenges drive a FRI fold of the Reed-Solomon codeword; Zeilberger-
//! Chen-Fisch, ePrint 2023/1705 [EXTERNAL]; the RS instantiation is the
//! FRI of Ben-Sasson-Bentov-Horesh-Riabzev 2018 with the fold-by-2^a /
//! commit-every-a-rounds structure of the STARK/Plonky FRI provers, and
//! the batching of different-degree codewords by adding a fresh codeword
//! at the round where the domains match [EXTERNAL, ethSTARK / Plonky3]):
//!
//! * A committed vector of N base-field values is the Lagrange table of a
//!   multilinear f in k = ceil(log2 N) variables, variable j <-> bit j of
//!   the index (LSB first; this module folds the LEAST significant bit
//!   first, so every fold pairs adjacent entries). N is cut into at most
//!   `max_pieces` power-of-two PIECES (the top set bits of N, rounded up
//!   so the cut has few pieces; a piece may extend past N with zeros — no
//!   claim ever weights the pad). Each piece is Mobius-transformed to its
//!   coefficient form c (f(X) = sum_i c_i prod_j X_j^{bit_j(i)}), read as
//!   the univariate P(Y) = sum_i c_i Y^i, and RS-encoded at rate
//!   1/inv_rate on the 2-adic subgroup of size L = inv_rate * 2^k (one
//!   parallel decimation-in-frequency NTT, whose natural output order is
//!   BIT-REVERSED: the 16 positions {t + j L/16} that fold together over
//!   four rounds are then one contiguous block). A blake3 Merkle tree is
//!   built over those 16-symbol blocks (pieces of one size share a tree:
//!   the leaf is the concatenation of their blocks). The commitment root
//!   is the blake3 of the per-size tree roots.
//! * OPENING (one per LAYER: the W, A, H commitments and all their claims
//!   at once). Every claim is a linear functional <f, w_c> whose weight
//!   w_c is eq(point) on an aligned slice (or a constant on a slice, for
//!   the LogUp helper sums). With random lambda_c the batched claim is
//!   sum_pieces sum_b f_p(b) g_p(b) with g_p = sum_c lambda_c w_c|_p, a
//!   degree-2 sumcheck; g_p is never materialised at full size: it is a
//!   sum over the distinct eq tables E_t (one per point suffix) of
//!   sel_t[b >> s_t] * E_t[b mod 2^s_t] with small selector tables, and
//!   the LSB-first folding folds the E_t first, collapsing each into an
//!   explicit table over the slice-index bits only when its arity is
//!   exhausted. A piece with k_p < k_max joins the sumcheck at round
//!   k_max - k_p as the k_max-variate polynomial
//!   prod_{i < join} (1 - X_i) * f_p g_p (the standard batched sumcheck
//!   of unequal sizes: its round messages before the join are the affine
//!   terms (1 - X) beta S_p, beta = prod (1 - r_i)); the same challenges
//!   fold its codeword into the running FRI codeword R = sum_p mu_p Enc(f_p)
//!   (mu_p random) at the round where the domains coincide. Every 4th
//!   round the prover commits Enc(the folded R) as a fold tree (the
//!   folded codeword is the encoding of the folded polynomial, so it is
//!   recomputed from the folded tables rather than folded symbol-wise);
//!   when 2^k_end coefficients remain (k_end <= log_final) they are sent
//!   in the clear. After the last round the prover sends f_p(r) per piece;
//!   the verifier checks the sumcheck terminal sum_p beta_p f_p(r) g_p(r)
//!   (g_p(r) is a product of O(k) eq factors), checks that the final
//!   polynomial's coefficient-form evaluation at the last k_end
//!   challenges equals sum_p mu_p f_p(r), and runs Q query walks: from a
//!   random 16-coset of the largest domain, fold four times per stretch
//!   (adding mu_p times the joining pieces' opened values), compare with
//!   the next fold tree's leaf, and at the end with the final polynomial.
//!
//! SOUNDNESS (parameters as stated in the ledger; error terms per proof):
//!   query term (1 - delta)^Q with delta = (1 - 1/inv_rate)/2, the
//!   unique-decoding radius (the regime in which BaseFold's Theorem 3 and
//!   the FRI soundness theorem are proven with the affine-line error
//!   L/|F| per fold [BCIKS20 Thm 1.2, EXTERNAL]); at inv_rate 4 and Q = 157:
//!   (5/8)^157 = 2^-106.4 (>= the Ligero form's 2^-106); fold/batching
//!   field terms ~ (rounds + pieces) L_0 / |F_{p^2}| = 2^-101 at L_0 = 2^25
//!   (12x512) and 2^-97 at 2^29 (the 8B W); the sumcheck 2 k / 2^128.
//!   The list-decoding (Johnson) regime would halve Q but its field term
//!   is ~L^2/|F| (2^-64 at 2^24 over F_{p^2}) — not usable at this field.
//!   NOT zero-knowledge (see the ledger's ZK-interaction statement).

use crate::field::{Fp, Fp2};
use crate::merkle::{hash_pair, Digest, MerkleTree};
use crate::mle::{eq_table_msb, interpolate_eval};
use crate::ntt::NttTables;
use crate::pcs::{self, Claim, Commitment, PcsParams};
use crate::transcript::Transcript;
use rayon::prelude::*;
use std::sync::{Mutex, OnceLock};

/// Leaves hold 2^COSET_LOG codeword symbols; a fold stretch is COSET_LOG rounds.
pub const COSET_LOG: u32 = 4;
pub const COSET: usize = 1 << COSET_LOG;

// ---------------------------------------------------------------------------
// configuration (chosen once by the driver; prover and verifier read it)
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug)]
pub struct CompactCfg {
    pub enabled: bool,
    /// RS inverse rate of the compact code (independent of the Ligero flag).
    pub inv_rate: usize,
    /// query count; 0 = derive from `target_bits` under the unique-decoding bound.
    pub queries: usize,
    pub target_bits: u32,
    /// the final polynomial is sent in the clear once <= 2^log_final coefficients remain
    pub log_final: u32,
    /// at most this many power-of-two pieces per commitment (N rounded up)
    pub max_pieces: u32,
    /// drop the layer-0 codewords after the trees and re-encode at query time (memory for time)
    pub reencode: bool,
}

impl CompactCfg {
    pub const DEFAULT: CompactCfg = CompactCfg { enabled: false, inv_rate: 4, queries: 0, target_bits: 106, log_final: 7, max_pieces: 3, reencode: false };
    pub fn effective_queries(&self) -> usize {
        if self.queries > 0 { self.queries } else { queries_for(self.inv_rate, self.target_bits) }
    }
}

static CFG: Mutex<CompactCfg> = Mutex::new(CompactCfg::DEFAULT);

pub fn configure(c: CompactCfg) {
    *CFG.lock().unwrap() = c;
}
pub fn cfg() -> CompactCfg {
    *CFG.lock().unwrap()
}
pub fn selected() -> bool {
    cfg().enabled
}

/// Smallest Q with (1 - delta)^Q <= 2^-bits, delta = (1 - 1/inv_rate)/2 (unique decoding).
pub fn queries_for(inv_rate: usize, bits: u32) -> usize {
    let delta = (1.0 - 1.0 / inv_rate as f64) / 2.0;
    (bits as f64 / -((1.0 - delta).log2())).ceil() as usize
}

// ---------------------------------------------------------------------------
// bit tricks, roots, the parallel DIF NTT, the Mobius transform
// ---------------------------------------------------------------------------

#[inline]
pub fn bitrev(x: usize, bits: u32) -> usize {
    if bits == 0 { 0 } else { x.reverse_bits() >> (usize::BITS - bits) }
}

const SMALL_LOG: u32 = 12;

struct Roots {
    fwd: Vec<Fp>,
    inv: Vec<Fp>,
    /// tw_small[lg] = omega_{2^lg}^k for k < 2^(lg-1)
    tw_small: Vec<Vec<Fp>>,
}

static ROOTS: OnceLock<Roots> = OnceLock::new();

fn roots() -> &'static Roots {
    ROOTS.get_or_init(|| {
        let fwd: Vec<Fp> = (0..=32).map(Fp::two_adic_root).collect();
        let inv: Vec<Fp> = fwd.iter().map(|r| r.inv()).collect();
        let mut tw_small = Vec::new();
        for lg in 0..=SMALL_LOG {
            let half = if lg == 0 { 0 } else { 1usize << (lg - 1) };
            let w = fwd[lg as usize];
            let mut v = Vec::with_capacity(half);
            let mut x = Fp::ONE;
            for _ in 0..half { v.push(x); x = x.mul(w); }
            tw_small.push(v);
        }
        Roots { fwd, inv, tw_small }
    })
}

/// omega_{2^lg}
pub fn root_of(lg: u32) -> Fp { roots().fwd[lg as usize] }
pub fn inv_root_of(lg: u32) -> Fp { roots().inv[lg as usize] }

/// In-place decimation-in-frequency NTT: natural-order coefficients in,
/// evaluations out in BIT-REVERSED order: a[bitrev(t)] = P(omega^t).
pub fn ntt_dif(a: &mut [Fp]) {
    let n = a.len();
    assert!(n.is_power_of_two());
    dif_rec(a, n.trailing_zeros());
}

fn dif_rec(a: &mut [Fp], log: u32) {
    if log <= SMALL_LOG { return dif_small(a, log); }
    let half = a.len() / 2;
    let w = roots().fwd[log as usize];
    let chunk = 1usize << 11;
    {
        let (lo, hi) = a.split_at_mut(half);
        lo.par_chunks_mut(chunk).zip(hi.par_chunks_mut(chunk)).enumerate().for_each(|(ci, (l, h))| {
            let mut wi = w.pow((ci * chunk) as u64);
            for (x, y) in l.iter_mut().zip(h.iter_mut()) {
                let u = *x;
                let v = *y;
                *x = u.add(v);
                *y = u.sub(v).mul(wi);
                wi = wi.mul(w);
            }
        });
    }
    let (lo, hi) = a.split_at_mut(half);
    rayon::join(|| dif_rec(lo, log - 1), || dif_rec(hi, log - 1));
}

fn dif_small(a: &mut [Fp], log: u32) {
    let r = roots();
    let mut lg = log;
    while lg >= 1 {
        let len = 1usize << lg;
        let half = len / 2;
        let tw = &r.tw_small[lg as usize];
        for blk in a.chunks_mut(len) {
            let (lo, hi) = blk.split_at_mut(half);
            for k in 0..half {
                let u = lo[k];
                let v = hi[k];
                lo[k] = u.add(v);
                hi[k] = u.sub(v).mul(tw[k]);
            }
        }
        lg -= 1;
    }
}

/// Lagrange table -> coefficient form of the multilinear (variable j = bit j).
pub fn mobius_fp(a: &mut [Fp]) {
    let n = a.len();
    let mut stride = 1usize;
    while stride < n {
        let big = stride >= (1 << 12);
        a.par_chunks_mut(2 * stride).for_each(|blk| {
            let (lo, hi) = blk.split_at_mut(stride);
            if big {
                hi.par_iter_mut().zip(lo.par_iter()).for_each(|(h, l)| *h = h.sub(*l));
            } else {
                for (h, l) in hi.iter_mut().zip(lo.iter()) { *h = h.sub(*l); }
            }
        });
        stride <<= 1;
    }
}

pub fn mobius_fp2(a: &mut [Fp2]) {
    let n = a.len();
    let mut stride = 1usize;
    while stride < n {
        let big = stride >= (1 << 12);
        a.par_chunks_mut(2 * stride).for_each(|blk| {
            let (lo, hi) = blk.split_at_mut(stride);
            if big {
                hi.par_iter_mut().zip(lo.par_iter()).for_each(|(h, l)| *h = h.sub(*l));
            } else {
                for (h, l) in hi.iter_mut().zip(lo.iter()) { *h = h.sub(*l); }
            }
        });
        stride <<= 1;
    }
}

/// Encode one piece: data[off .. off + 2^log_size) (zeros past the end) ->
/// the bit-reversed RS codeword of length inv_rate * 2^log_size.
pub fn encode_piece(data: &[Fp], off: usize, log_size: u32, inv_rate: usize) -> Vec<Fp> {
    let n = 1usize << log_size;
    let l = n * inv_rate;
    let mut buf = vec![Fp::ZERO; l];
    let avail = data.len().saturating_sub(off).min(n);
    if avail > 0 { buf[..avail].copy_from_slice(&data[off..off + avail]); }
    mobius_fp(&mut buf[..n]);
    ntt_dif(&mut buf);
    buf
}

/// Encode an extension-field Lagrange table (the running folded polynomial).
pub fn encode_ext(t: &[Fp2], inv_rate: usize) -> Vec<Fp2> {
    let n = t.len();
    let l = n * inv_rate;
    let mut re = vec![Fp::ZERO; l];
    let mut im = vec![Fp::ZERO; l];
    re[..n].par_iter_mut().zip(t.par_iter()).for_each(|(o, v)| *o = v.c0);
    im[..n].par_iter_mut().zip(t.par_iter()).for_each(|(o, v)| *o = v.c1);
    rayon::join(|| { mobius_fp(&mut re[..n]); ntt_dif(&mut re); }, || { mobius_fp(&mut im[..n]); ntt_dif(&mut im); });
    re.par_iter().zip(im.par_iter()).map(|(a, b)| Fp2::new(*a, *b)).collect()
}

/// Coefficient-form multilinear evaluation: sum_i c_i prod_j r_j^{bit_j(i)}.
pub fn coeff_eval(c: &[Fp2], r: &[Fp2]) -> Fp2 {
    assert_eq!(c.len(), 1usize << r.len());
    let mut cur = c.to_vec();
    for rj in r {
        let half = cur.len() / 2;
        for i in 0..half { cur[i] = cur[2 * i].add(rj.mul(cur[2 * i + 1])); }
        cur.truncate(half);
    }
    cur[0]
}

/// P(x) for natural-order coefficients (Horner).
fn horner(c: &[Fp2], x: Fp) -> Fp2 {
    let mut acc = Fp2::ZERO;
    for v in c.iter().rev() { acc = acc.mul_base(x).add(*v); }
    acc
}

// ---------------------------------------------------------------------------
// the coset Merkle tree (levels above the leaves stored; leaf hashes recomputed)
// ---------------------------------------------------------------------------

pub struct CosetTree {
    pub n_leaves: usize,
    /// levels[0] = hashes of leaf pairs, ..., last = [root]
    pub levels: Vec<Vec<Digest>>,
}

impl CosetTree {
    pub fn build<F: Fn(usize) -> Digest + Sync>(n_leaves: usize, leaf_hash: F) -> CosetTree {
        assert!(n_leaves.is_power_of_two() && n_leaves >= 2, "coset tree: {n_leaves} leaves");
        let l0: Vec<Digest> = (0..n_leaves / 2).into_par_iter().map(|p| hash_pair(&leaf_hash(2 * p), &leaf_hash(2 * p + 1))).collect();
        let mut levels = vec![l0];
        while levels.last().unwrap().len() > 1 {
            let next: Vec<Digest> = levels.last().unwrap().par_chunks(2).map(|p| hash_pair(&p[0], &p[1])).collect();
            levels.push(next);
        }
        CosetTree { n_leaves, levels }
    }
    pub fn root(&self) -> Digest { self.levels.last().unwrap()[0] }
    pub fn path<F: Fn(usize) -> Digest>(&self, idx: usize, leaf_hash: F) -> Vec<Digest> {
        let mut out = vec![leaf_hash(idx ^ 1)];
        let mut i = idx >> 1;
        for lvl in &self.levels[..self.levels.len() - 1] {
            out.push(lvl[i ^ 1]);
            i >>= 1;
        }
        out
    }
}

fn hash_fp_block(parts: &[&[Fp]]) -> Digest {
    let mut buf = Vec::with_capacity(parts.iter().map(|p| p.len() * 8).sum());
    for p in parts { for v in *p { buf.extend_from_slice(&v.to_bytes()); } }
    *blake3::hash(&buf).as_bytes()
}
fn hash_fp2_block(vals: &[Fp2]) -> Digest {
    let mut buf = Vec::with_capacity(vals.len() * 16);
    for v in vals { buf.extend_from_slice(&v.to_bytes()); }
    *blake3::hash(&buf).as_bytes()
}

// ---------------------------------------------------------------------------
// pieces and the commitment
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Piece {
    pub offset: usize,
    pub log_size: u32,
}

/// The power-of-two pieces of a length-n vector: the set bits of n rounded
/// up so that at most `max_pieces` remain, largest first, contiguous.
pub fn pieces_of(n: usize, max_pieces: u32) -> Vec<Piece> {
    assert!(n > 0 && max_pieces >= 1);
    let mut m = n;
    if m.count_ones() > max_pieces {
        let mut cnt = 0;
        let mut e = 0;
        for b in (0..usize::BITS).rev() {
            if (m >> b) & 1 == 1 {
                cnt += 1;
                if cnt == max_pieces { e = b; break; }
            }
        }
        let unit = 1usize << e;
        m = (m + unit - 1) / unit * unit;
    }
    let mut out = Vec::new();
    let mut off = 0usize;
    for b in (0..usize::BITS).rev() {
        if (m >> b) & 1 == 1 {
            out.push(Piece { offset: off, log_size: b });
            off += 1usize << b;
        }
    }
    out
}

pub struct Group {
    pub log_size: u32,
    pub piece_ids: Vec<usize>,
    /// bit-reversed codewords, one per piece of the group (empty when dropped)
    pub codewords: Vec<Vec<Fp>>,
    pub tree: CosetTree,
}

pub struct CompactCommitted<'a> {
    pub params: PcsParams,
    pub inv_rate: usize,
    pub rows: usize,
    pub data: &'a [Fp],
    pub pieces: Vec<Piece>,
    pub groups: Vec<Group>,
    pub root: Digest,
}

fn group_leaf_hash(codewords: &[Vec<Fp>], i: usize) -> Digest {
    let parts: Vec<&[Fp]> = codewords.iter().map(|cw| &cw[i * COSET..(i + 1) * COSET]).collect();
    hash_fp_block(&parts)
}

/// The commitment root over the per-group tree roots.
pub fn roots_digest(group_roots: &[Digest]) -> Digest {
    let mut h = blake3::Hasher::new();
    h.update(b"cpcs-roots");
    h.update(&(group_roots.len() as u64).to_le_bytes());
    for r in group_roots { h.update(r); }
    *h.finalize().as_bytes()
}

/// The group structure of a committed length (shared by prover and verifier).
pub fn group_sizes(pieces: &[Piece]) -> Vec<(u32, Vec<usize>)> {
    let mut out: Vec<(u32, Vec<usize>)> = Vec::new();
    for (pid, p) in pieces.iter().enumerate() {
        match out.last_mut() {
            Some((ls, ids)) if *ls == p.log_size => ids.push(pid),
            _ => out.push((p.log_size, vec![pid])),
        }
    }
    out
}

pub fn commit_compact<'a>(params: &PcsParams, data: &'a [Fp]) -> CompactCommitted<'a> {
    let c = cfg();
    let n = params.cols();
    assert!(data.len() % n == 0 && !data.is_empty(), "cpcs: data length {} not a multiple of n = {n}", data.len());
    let inv_rate = c.inv_rate;
    let pieces = pieces_of(data.len(), c.max_pieces);
    let mut groups = Vec::new();
    for (log_size, piece_ids) in group_sizes(&pieces) {
        let codewords: Vec<Vec<Fp>> = piece_ids.iter().map(|&pid| encode_piece(data, pieces[pid].offset, log_size, inv_rate)).collect();
        let l = (1usize << log_size) * inv_rate;
        let tree = CosetTree::build(l / COSET, |i| group_leaf_hash(&codewords, i));
        let codewords = if c.reencode { Vec::new() } else { codewords };
        groups.push(Group { log_size, piece_ids, codewords, tree });
    }
    let root = roots_digest(&groups.iter().map(|g| g.tree.root()).collect::<Vec<_>>());
    CompactCommitted { params: *params, inv_rate, rows: data.len() / n, data, pieces, groups, root }
}

impl<'a> CompactCommitted<'a> {
    pub fn commitment(&self) -> Commitment {
        Commitment { root: self.root, rows: self.rows, log_cols: self.params.log_cols }
    }
    /// The codewords of a group, re-encoded ONLY when they were dropped
    /// (`reencode`). Never a clone: at the 8B shapes one group's codeword is
    /// gigabytes, and cloning it at query time doubled the peak.
    fn group_codewords(&self, g: &Group) -> Vec<Vec<Fp>> {
        if !g.codewords.is_empty() { return Vec::new(); }
        g.piece_ids.iter().map(|&pid| encode_piece(self.data, self.pieces[pid].offset, g.log_size, self.inv_rate)).collect()
    }
}

/// The PCS-selection seam: the Ligero form (byte-identical, the default) or the compact form.
pub enum AnyCm<'a> {
    Ligero(pcs::Committed),
    Compact(CompactCommitted<'a>),
}

impl<'a> AnyCm<'a> {
    pub fn commitment(&self) -> Commitment {
        match self {
            AnyCm::Ligero(c) => c.commitment(),
            AnyCm::Compact(c) => c.commitment(),
        }
    }
    pub fn lig(&self) -> &pcs::Committed {
        match self { AnyCm::Ligero(c) => c, AnyCm::Compact(_) => panic!("cpcs: a Ligero opening was requested on a compact commitment") }
    }
    pub fn compact(&self) -> &CompactCommitted<'a> {
        match self { AnyCm::Compact(c) => c, AnyCm::Ligero(_) => panic!("cpcs: a compact opening was requested on a Ligero commitment") }
    }
    pub fn ligero_ref(&self) -> Option<&pcs::Committed> {
        match self { AnyCm::Ligero(c) => Some(c), AnyCm::Compact(_) => None }
    }
}

/// Commit under the selected PCS.
pub fn commit<'a>(params: &PcsParams, data: &'a [Fp], ntt: &NttTables) -> AnyCm<'a> {
    if selected() { AnyCm::Compact(commit_compact(params, data)) } else { AnyCm::Ligero(pcs::commit(params, data, ntt)) }
}

// ---------------------------------------------------------------------------
// claims -> slice terms
// ---------------------------------------------------------------------------

/// One aligned sub-slice of a claim part inside one piece: weight
/// coef * E(b mod 2^log_size) on block `block` of the piece (E = eq of the
/// point suffix `table`, or the constant 1 for a sum).
#[derive(Clone, Debug)]
struct Term {
    piece: usize,
    block: usize,
    log_size: u32,
    coef: Fp2,
    table: Option<usize>,
}

#[derive(Default)]
struct TableKeys {
    keys: Vec<Vec<Fp2>>,
}
impl TableKeys {
    fn id(&mut self, point: &[Fp2]) -> usize {
        if let Some(i) = self.keys.iter().position(|k| k.as_slice() == point) { return i; }
        self.keys.push(point.to_vec());
        self.keys.len() - 1
    }
}

fn split_terms(off: usize, ls: u32, point: &[Fp2], coef: Fp2, pieces: &[Piece], pbase: usize, keys: &mut TableKeys, out: &mut Vec<Term>) {
    let (pi, p) = pieces.iter().enumerate().find(|(_, p)| off >= p.offset && off < p.offset + (1usize << p.log_size)).expect("cpcs: slice outside the committed vector");
    let size = 1usize << ls;
    if off % size == 0 && off + size <= p.offset + (1usize << p.log_size) {
        let table = if point.is_empty() { None } else { Some(keys.id(point)) };
        out.push(Term { piece: pbase + pi, block: (off - p.offset) >> ls, log_size: ls, coef, table });
    } else {
        assert!(ls > 0, "cpcs: a one-element slice that is neither aligned nor inside a piece");
        let half = size / 2;
        if point.is_empty() {
            split_terms(off, ls - 1, point, coef, pieces, pbase, keys, out);
            split_terms(off + half, ls - 1, point, coef, pieces, pbase, keys, out);
        } else {
            let p0 = point[0];
            split_terms(off, ls - 1, &point[1..], coef.mul(Fp2::ONE.sub(p0)), pieces, pbase, keys, out);
            split_terms(off + half, ls - 1, &point[1..], coef.mul(p0), pieces, pbase, keys, out);
        }
    }
}

/// The batch's piece table: (commitment index, piece) in batch order.
struct BatchPlan {
    /// per commitment: its pieces
    pieces: Vec<Vec<Piece>>,
    /// global piece list: (commitment, local piece index, log_size)
    all: Vec<(usize, usize, u32)>,
    /// global piece index of (commitment, local)
    #[allow(dead_code)]
    base: Vec<usize>,
    k_max: u32,
    k_end: u32,
    inv_rate: usize,
    terms: Vec<Term>,
    keys: TableKeys,
    /// sum_c lambda_c value_c
    claim0: Fp2,
    n_claims: usize,
}

fn plan_batch(lens: &[usize], claims: &[&[Claim]], lambdas: &[Fp2]) -> BatchPlan {
    let c = cfg();
    let mut pieces = Vec::new();
    let mut all = Vec::new();
    let mut base = Vec::new();
    for &n in lens {
        let ps = pieces_of(n, c.max_pieces);
        base.push(all.len());
        for (li, p) in ps.iter().enumerate() { all.push((pieces.len(), li, p.log_size)); }
        pieces.push(ps);
    }
    let k_max = all.iter().map(|x| x.2).max().unwrap();
    let k_min = all.iter().map(|x| x.2).min().unwrap();
    // k_end: the largest value <= min(log_final, k_min) congruent to k_max mod COSET_LOG
    let cap = c.log_final.min(k_min);
    let mut k_end = k_max;
    while k_end > cap { k_end -= COSET_LOG.min(k_end); }
    assert!((k_max - k_end) % COSET_LOG == 0, "cpcs: k_max {k_max} k_end {k_end} not a whole number of stretches (min piece 2^{k_min})");
    let mut terms = Vec::new();
    let mut keys = TableKeys::default();
    let mut claim0 = Fp2::ZERO;
    let mut li = 0usize;
    for (ci, cl) in claims.iter().enumerate() {
        for cm in cl.iter() {
            let lam = lambdas[li];
            li += 1;
            claim0 = claim0.add(lam.mul(cm.value));
            for (sl, coef) in &cm.parts {
                let point: &[Fp2] = if cm.sum { &[] } else { &cm.point };
                if !cm.sum { assert_eq!(point.len() as u32, sl.log_size, "cpcs: claim point arity != slice size"); }
                split_terms(sl.offset, sl.log_size, point, lam.mul(*coef), &pieces[ci], base[ci], &mut keys, &mut terms);
            }
        }
    }
    BatchPlan { pieces, all, base, k_max, k_end, inv_rate: c.inv_rate, terms, keys, claim0, n_claims: li }
}

// ---------------------------------------------------------------------------
// the proof
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, Default)]
pub struct QueryOpen {
    /// per (commitment, group) in batch order: the leaf's values (all pieces' 16-blocks) and its path
    pub groups: Vec<(Vec<Fp>, Vec<Digest>)>,
    /// per fold tree: the 16 folded values and the path
    pub folds: Vec<(Vec<Fp2>, Vec<Digest>)>,
}

#[derive(Clone, Debug, Default)]
pub struct BatchOpening {
    /// per commitment: its group tree roots (hash to the commitment root)
    pub group_roots: Vec<Vec<Digest>>,
    pub rounds: Vec<[Fp2; 3]>,
    pub fold_roots: Vec<Digest>,
    pub final_coeffs: Vec<Fp2>,
    /// f_p(r) per piece, batch order
    pub terminals: Vec<Fp2>,
    pub queries: Vec<QueryOpen>,
}

impl BatchOpening {
    pub fn size_bytes(&self) -> usize {
        let roots: usize = self.group_roots.iter().map(|g| g.len() * 32).sum::<usize>() + self.fold_roots.len() * 32;
        let sc = self.rounds.len() * 48 + self.final_coeffs.len() * 16 + self.terminals.len() * 16;
        let q: usize = self.queries.iter().map(|q| {
            q.groups.iter().map(|(v, p)| v.len() * 8 + p.len() * 32).sum::<usize>() + q.folds.iter().map(|(v, p)| v.len() * 16 + p.len() * 32).sum::<usize>()
        }).sum();
        roots + sc + q
    }
    pub fn write_bytes(&self, out: &mut Vec<u8>) {
        for g in &self.group_roots { for r in g { out.extend_from_slice(r); } }
        for s in &self.rounds { for v in s { out.extend_from_slice(&v.to_bytes()); } }
        for r in &self.fold_roots { out.extend_from_slice(r); }
        for v in &self.final_coeffs { out.extend_from_slice(&v.to_bytes()); }
        for v in &self.terminals { out.extend_from_slice(&v.to_bytes()); }
        for q in &self.queries {
            for (v, p) in &q.groups {
                for x in v { out.extend_from_slice(&x.to_bytes()); }
                for d in p { out.extend_from_slice(d); }
            }
            for (v, p) in &q.folds {
                for x in v { out.extend_from_slice(&x.to_bytes()); }
                for d in p { out.extend_from_slice(d); }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// the prover
// ---------------------------------------------------------------------------

enum FTab<'a> {
    Base(&'a [Fp]),
    Ext(Vec<Fp2>),
}
impl<'a> FTab<'a> {
    fn len(&self) -> usize { match self { FTab::Base(b) => b.len(), FTab::Ext(e) => e.len() } }
    #[inline(always)]
    fn get(&self, i: usize) -> Fp2 { match self { FTab::Base(b) => Fp2::from_base(b[i]), FTab::Ext(e) => e[i] } }
    fn fold(&mut self, r: Fp2) {
        let half = self.len() / 2;
        let out: Vec<Fp2> = match self {
            FTab::Base(b) => (0..half).into_par_iter().map(|i| { let f0 = b[2 * i]; let f1 = b[2 * i + 1]; r.mul_base(f1.sub(f0)).add_base(f0) }).collect(),
            FTab::Ext(e) => (0..half).into_par_iter().map(|i| { let f0 = e[2 * i]; let f1 = e[2 * i + 1]; f0.add(r.mul(f1.sub(f0))) }).collect(),
        };
        *self = FTab::Ext(out);
    }
    fn final_value(&self) -> Fp2 { assert_eq!(self.len(), 1); self.get(0) }
}

fn fold_ext(e: &[Fp2], r: Fp2) -> Vec<Fp2> {
    let half = e.len() / 2;
    if half >= 1 << 12 {
        (0..half).into_par_iter().map(|i| { let f0 = e[2 * i]; let f1 = e[2 * i + 1]; f0.add(r.mul(f1.sub(f0))) }).collect()
    } else {
        (0..half).map(|i| { let f0 = e[2 * i]; let f1 = e[2 * i + 1]; f0.add(r.mul(f1.sub(f0))) }).collect()
    }
}

/// One eq-table family of a piece's weight: sel[b >> s] * e[b mod 2^s].
struct GTab {
    e: Option<Vec<Fp2>>,
    s: u32,
    sel: Vec<Fp2>,
}

struct PieceState<'a> {
    k: u32,
    join: usize,
    joined: bool,
    mu: Fp2,
    f: FTab<'a>,
    gtabs: Vec<GTab>,
    hi: Option<Vec<Fp2>>,
    /// the unscaled sum f.g (for the affine terms before the join)
    s_total: Fp2,
    /// zero-extended copy of a piece that runs past the data
    _pad: Option<Vec<Fp>>,
}

impl<'a> PieceState<'a> {
    #[inline(always)]
    fn g_at(&self, b: usize) -> Fp2 {
        let mut acc = match &self.hi { Some(h) => h[b], None => Fp2::ZERO };
        for t in &self.gtabs {
            let blk = b >> t.s;
            let w = t.sel[blk];
            if w.is_zero() { continue; }
            acc = acc.add(match &t.e { Some(e) => w.mul(e[b & ((1usize << t.s) - 1)]), None => w });
        }
        acc
    }
    /// (s(0), s(1), s(2)) of this piece's pairs.
    fn round_sums(&self) -> [Fp2; 3] {
        let half = self.f.len() / 2;
        let chunk = 1usize << 12;
        let n_chunks = (half + chunk - 1) / chunk;
        let one = |ci: usize| {
            let lo = ci * chunk;
            let hi = (lo + chunk).min(half);
            let mut acc = [Fp2::ZERO; 3];
            for i in lo..hi {
                let f0 = self.f.get(2 * i);
                let f1 = self.f.get(2 * i + 1);
                let g0 = self.g_at(2 * i);
                let g1 = self.g_at(2 * i + 1);
                acc[0] = acc[0].add(f0.mul(g0));
                acc[1] = acc[1].add(f1.mul(g1));
                let f2 = f1.double().sub(f0);
                let g2 = g1.double().sub(g0);
                acc[2] = acc[2].add(f2.mul(g2));
            }
            acc
        };
        if n_chunks <= 1 {
            one(0)
        } else {
            (0..n_chunks).into_par_iter().map(one).reduce(|| [Fp2::ZERO; 3], |a, b| [a[0].add(b[0]), a[1].add(b[1]), a[2].add(b[2])])
        }
    }
    fn total(&self) -> Fp2 {
        let n = self.f.len();
        let chunk = 1usize << 13;
        (0..(n + chunk - 1) / chunk).into_par_iter().map(|ci| {
            let lo = ci * chunk;
            let hi = (lo + chunk).min(n);
            let mut acc = Fp2::ZERO;
            for b in lo..hi { acc = acc.add(self.f.get(b).mul(self.g_at(b))); }
            acc
        }).reduce(|| Fp2::ZERO, |a, b| a.add(b))
    }
    fn scale_g(&mut self, beta: Fp2) {
        for t in &mut self.gtabs { for v in t.sel.iter_mut() { *v = v.mul(beta); } }
        if let Some(h) = &mut self.hi { for v in h.iter_mut() { *v = v.mul(beta); } }
    }
    fn fold(&mut self, r: Fp2) {
        self.f.fold(r);
        if let Some(h) = &self.hi { self.hi = Some(fold_ext(h, r)); }
        let mut collapsed: Vec<Vec<Fp2>> = Vec::new();
        for t in &mut self.gtabs {
            if let Some(e) = &t.e { t.e = Some(fold_ext(e, r)); }
            t.s -= 1;
            if t.s == 0 {
                let e0 = match &t.e { Some(e) => e[0], None => Fp2::ONE };
                collapsed.push(t.sel.iter().map(|w| w.mul(e0)).collect());
            }
        }
        self.gtabs.retain(|t| t.s > 0);
        for c in collapsed {
            match &mut self.hi {
                Some(h) => { assert_eq!(h.len(), c.len()); for (a, b) in h.iter_mut().zip(c.iter()) { *a = a.add(*b); } }
                None => self.hi = Some(c),
            }
        }
    }
}

/// The stretch structure: after `rounds` rounds, is a fold tree due, the final polynomial due?
fn stretch_end(rounds: usize, k_max: u32, k_end: u32) -> (bool, bool) {
    let boundary = rounds % (COSET_LOG as usize) == 0;
    let remaining = k_max as usize - rounds;
    (boundary && remaining > k_end as usize, boundary && remaining == k_end as usize)
}

/// Prover: ONE batched opening of every claim on every commitment of the batch.
pub fn open_batch(batch: &[(&CompactCommitted<'_>, &[Claim])], tr: &mut Transcript) -> BatchOpening {
    use std::time::Instant;
    let vb = std::env::var("HL_TIMING").map(|v| v == "1").unwrap_or(false);
    let t0 = Instant::now();
    let c = cfg();
    let n_claims: usize = batch.iter().map(|(_, cl)| cl.len()).sum();
    let lambdas = tr.challenge_fp2_vec(n_claims);
    let lens: Vec<usize> = batch.iter().map(|(cm, _)| cm.data.len()).collect();
    let claims: Vec<&[Claim]> = batch.iter().map(|(_, cl)| *cl).collect();
    let plan = plan_batch(&lens, &claims, &lambdas);
    let mus = tr.challenge_fp2_vec(plan.all.len());
    let k_max = plan.k_max;
    let k_end = plan.k_end;
    let inv_rate = plan.inv_rate;
    for (ci, (cm, _)) in batch.iter().enumerate() {
        assert_eq!(cm.pieces, plan.pieces[ci], "cpcs: piece plan mismatch");
        assert_eq!(cm.inv_rate, inv_rate);
    }
    // eq tables per point suffix
    let tables: Vec<Vec<Fp2>> = plan.keys.keys.par_iter().map(|k| eq_table_msb(k)).collect();
    // piece states
    let mut states: Vec<PieceState> = Vec::with_capacity(plan.all.len());
    for (q, &(ci, li, k)) in plan.all.iter().enumerate() {
        let cm = batch[ci].0;
        let p = cm.pieces[li];
        let n = 1usize << k;
        let (f, pad) = if p.offset + n <= cm.data.len() {
            (FTab::Base(&cm.data[p.offset..p.offset + n]), None)
        } else {
            let mut v = vec![Fp::ZERO; n];
            let avail = cm.data.len().saturating_sub(p.offset);
            v[..avail].copy_from_slice(&cm.data[p.offset..p.offset + avail]);
            (FTab::Base(&[] as &[Fp]), Some(v))
        };
        states.push(PieceState { k, join: (k_max - k) as usize, joined: false, mu: mus[q], f, gtabs: Vec::new(), hi: None, s_total: Fp2::ZERO, _pad: pad });
    }
    // the padded pieces borrow their own copies (the Vec's heap buffer never moves while the
    // state lives; the state is dropped before `proof` is returned)
    for st in states.iter_mut() {
        if let Some(v) = &st._pad {
            let slice: &[Fp] = unsafe { std::slice::from_raw_parts(v.as_ptr(), v.len()) };
            st.f = FTab::Base(slice);
        }
    }
    // weight tables from the terms
    for (q, st) in states.iter_mut().enumerate() {
        let mut fams: Vec<(Option<usize>, u32)> = Vec::new();
        for t in plan.terms.iter().filter(|t| t.piece == q) {
            if !fams.contains(&(t.table, t.log_size)) { fams.push((t.table, t.log_size)); }
        }
        for (table, s) in fams {
            let mut sel = vec![Fp2::ZERO; 1usize << (st.k - s)];
            for t in plan.terms.iter().filter(|t| t.piece == q && t.table == table && t.log_size == s) {
                sel[t.block] = sel[t.block].add(t.coef);
            }
            let e = table.map(|tid| tables[tid].clone());
            st.gtabs.push(GTab { e, s, sel });
        }
        if st.join > 0 { st.s_total = st.total(); }
    }
    let t_plan = t0.elapsed().as_secs_f64();
    let mut proof = BatchOpening::default();
    proof.group_roots = batch.iter().map(|(cm, _)| cm.groups.iter().map(|g| g.tree.root()).collect()).collect();
    let mut fold_layers: Vec<(Vec<Fp2>, CosetTree)> = Vec::new();
    let combined = |states: &[PieceState]| -> Vec<Fp2> {
        let len = states.iter().find(|s| s.joined).map(|s| s.f.len()).unwrap();
        let mut t = vec![Fp2::ZERO; len];
        for s in states.iter().filter(|s| s.joined) {
            assert_eq!(s.f.len(), len);
            let mu = s.mu;
            match &s.f {
                FTab::Ext(e) => t.par_iter_mut().zip(e.par_iter()).for_each(|(o, v)| *o = o.add(mu.mul(*v))),
                FTab::Base(b) => t.par_iter_mut().zip(b.par_iter()).for_each(|(o, v)| *o = o.add(mu.mul_base(*v))),
            }
        }
        t
    };
    let mut challenges: Vec<Fp2> = Vec::with_capacity(k_max as usize);
    let mut beta = Fp2::ONE; // prod (1 - r_i) so far
    let mut t_rounds = 0.0;
    let mut t_folds = 0.0;
    // the degenerate case: no fold at all (k_end == k_max): the final polynomial before round 0
    if k_end == k_max {
        for st in states.iter_mut() { if st.join == 0 { st.joined = true; } }
        let mut t = combined(&states);
        mobius_fp2(&mut t);
        tr.absorb_fp2(b"cpcs-final", &t);
        proof.final_coeffs = t;
    }
    for j in 0..k_max as usize {
        let tj = Instant::now();
        for st in states.iter_mut() {
            if st.join == j && !st.joined {
                st.scale_g(beta);
                st.joined = true;
            }
        }
        let mut sums = [Fp2::ZERO; 3];
        for st in states.iter() {
            if st.joined {
                let s = st.round_sums();
                for d in 0..3 { sums[d] = sums[d].add(s[d]); }
            } else {
                let a = beta.mul(st.s_total);
                sums[0] = sums[0].add(a);
                sums[2] = sums[2].sub(a);
            }
        }
        tr.absorb_fp2(b"cpcs-round", &sums);
        let r = tr.challenge_fp2();
        challenges.push(r);
        proof.rounds.push(sums);
        for st in states.iter_mut() { if st.joined { st.fold(r); } }
        beta = beta.mul(Fp2::ONE.sub(r));
        t_rounds += tj.elapsed().as_secs_f64();
        let tf = Instant::now();
        let (fold_due, final_due) = stretch_end(j + 1, k_max, k_end);
        if fold_due {
            let t = combined(&states);
            let cw = encode_ext(&t, inv_rate);
            let tree = CosetTree::build(cw.len() / COSET, |i| hash_fp2_block(&cw[i * COSET..(i + 1) * COSET]));
            let root = tree.root();
            tr.absorb(b"cpcs-fold", &root);
            proof.fold_roots.push(root);
            fold_layers.push((cw, tree));
        } else if final_due {
            let mut t = combined(&states);
            mobius_fp2(&mut t);
            tr.absorb_fp2(b"cpcs-final", &t);
            proof.final_coeffs = t;
        }
        t_folds += tf.elapsed().as_secs_f64();
    }
    proof.terminals = states.iter().map(|s| s.f.final_value()).collect();
    tr.absorb_fp2(b"cpcs-term", &proof.terminals);
    drop(states);
    // queries
    let tq = Instant::now();
    let l0 = (1usize << k_max) * inv_rate;
    let q_count = c.effective_queries();
    let idx = tr.challenge_indices(q_count, l0 / COSET);
    // Re-encoded groups (only under `reencode`); resident groups are BORROWED, never cloned.
    let reenc: Vec<Vec<Vec<Vec<Fp>>>> = batch.iter().map(|(cm, _)| cm.groups.iter().map(|g| cm.group_codewords(g)).collect()).collect();
    let group_cws: Vec<Vec<&[Vec<Fp>]>> = batch.iter().enumerate()
        .map(|(ci, (cm, _))| cm.groups.iter().enumerate()
            .map(|(gi, g)| if g.codewords.is_empty() { reenc[ci][gi].as_slice() } else { g.codewords.as_slice() })
            .collect())
        .collect();
    proof.queries = idx.par_iter().map(|&t0q| {
        let mut qo = QueryOpen::default();
        for (ci, (cm, _)) in batch.iter().enumerate() {
            for (gi, g) in cm.groups.iter().enumerate() {
                let lg = (1usize << g.log_size) * inv_rate;
                let leaves = lg / COSET;
                let u = t0q % leaves;
                let ls = bitrev(u, leaves.trailing_zeros());
                let cws = group_cws[ci][gi];
                let mut vals = Vec::with_capacity(cws.len() * COSET);
                for cw in cws { vals.extend_from_slice(&cw[ls * COSET..(ls + 1) * COSET]); }
                let path = g.tree.path(ls, |i| group_leaf_hash(cws, i));
                qo.groups.push((vals, path));
            }
        }
        for (cw, tree) in &fold_layers {
            let leaves = cw.len() / COSET;
            let u = t0q % leaves;
            let ls = bitrev(u, leaves.trailing_zeros());
            let vals = cw[ls * COSET..(ls + 1) * COSET].to_vec();
            let path = tree.path(ls, |i| hash_fp2_block(&cw[i * COSET..(i + 1) * COSET]));
            qo.folds.push((vals, path));
        }
        qo
    }).collect();
    if vb {
        eprintln!("[cpcs::open] pieces {} claims {} k_max {k_max} k_end {k_end} Q {q_count}: plan {:.3} | rounds {:.3} | folds {:.3} | queries {:.3} s | {} B",
            plan.all.len(), plan.n_claims, t_plan, t_rounds, t_folds, tq.elapsed().as_secs_f64(), proof.size_bytes());
    }
    proof
}

// ---------------------------------------------------------------------------
// the verifier
// ---------------------------------------------------------------------------

fn eq_bits(block: usize, rs: &[Fp2]) -> Fp2 {
    let mut acc = Fp2::ONE;
    for (j, r) in rs.iter().enumerate() {
        acc = acc.mul(if (block >> j) & 1 == 1 { *r } else { Fp2::ONE.sub(*r) });
    }
    acc
}

/// eq(point, local index) with point[0] <-> the local MSB <-> rs[s-1].
fn eq_point_lsb(point: &[Fp2], rs: &[Fp2]) -> Fp2 {
    let s = point.len();
    assert_eq!(rs.len(), s);
    let mut acc = Fp2::ONE;
    for m in 0..s {
        let a = point[m];
        let b = rs[s - 1 - m];
        acc = acc.mul(a.mul(b).add(Fp2::ONE.sub(a).mul(Fp2::ONE.sub(b))));
    }
    acc
}

/// Verifier: the batched opening against the commitments and the claims.
pub fn verify_batch(batch: &[(&PcsParams, &Commitment, &[Claim])], proof: &BatchOpening, tr: &mut Transcript) -> Result<(), String> {
    let c = cfg();
    let n_claims: usize = batch.iter().map(|(_, _, cl)| cl.len()).sum();
    let lambdas = tr.challenge_fp2_vec(n_claims);
    let lens: Vec<usize> = batch.iter().map(|(p, cm, _)| cm.rows * p.cols()).collect();
    let claims: Vec<&[Claim]> = batch.iter().map(|(_, _, cl)| *cl).collect();
    let plan = plan_batch(&lens, &claims, &lambdas);
    let mus = tr.challenge_fp2_vec(plan.all.len());
    let k_max = plan.k_max;
    let k_end = plan.k_end;
    let inv_rate = plan.inv_rate;
    // commitment roots
    if proof.group_roots.len() != batch.len() { return Err("group root count".into()); }
    let mut groups: Vec<Vec<(u32, Vec<usize>)>> = Vec::new();
    for (ci, (_, cm, _)) in batch.iter().enumerate() {
        let gs = group_sizes(&plan.pieces[ci]);
        if proof.group_roots[ci].len() != gs.len() { return Err(format!("commitment {ci}: group count")); }
        if roots_digest(&proof.group_roots[ci]) != cm.root { return Err(format!("commitment {ci}: the group roots do not hash to the commitment root")); }
        groups.push(gs);
    }
    // the sumcheck
    let n_folds = ((k_max - k_end) / COSET_LOG) as usize;
    let n_fold_trees = n_folds.saturating_sub(1);
    if proof.rounds.len() != k_max as usize { return Err(format!("{} sumcheck rounds for k_max {k_max}", proof.rounds.len())); }
    if proof.fold_roots.len() != n_fold_trees { return Err("fold tree count".into()); }
    if proof.final_coeffs.len() != 1usize << k_end { return Err("final polynomial size".into()); }
    if proof.terminals.len() != plan.all.len() { return Err("terminal count".into()); }
    let mut claim = plan.claim0;
    let mut challenges = Vec::with_capacity(k_max as usize);
    let mut fold_i = 0usize;
    if k_end == k_max { tr.absorb_fp2(b"cpcs-final", &proof.final_coeffs); }
    for j in 0..k_max as usize {
        let s = &proof.rounds[j];
        if s[0].add(s[1]) != claim { return Err(format!("sumcheck round {j}: s(0) + s(1) != claim")); }
        tr.absorb_fp2(b"cpcs-round", s);
        let r = tr.challenge_fp2();
        challenges.push(r);
        claim = interpolate_eval(s, r);
        let (fold_due, final_due) = stretch_end(j + 1, k_max, k_end);
        if fold_due {
            tr.absorb(b"cpcs-fold", &proof.fold_roots[fold_i]);
            fold_i += 1;
        } else if final_due {
            tr.absorb_fp2(b"cpcs-final", &proof.final_coeffs);
        }
    }
    tr.absorb_fp2(b"cpcs-term", &proof.terminals);
    // terminal: sum_p beta_p f_p(r) g_p(r)
    let mut want = Fp2::ZERO;
    let mut mu_sum = Fp2::ZERO;
    for (q, &(_, _, k)) in plan.all.iter().enumerate() {
        let join = (k_max - k) as usize;
        let mut beta = Fp2::ONE;
        for i in 0..join { beta = beta.mul(Fp2::ONE.sub(challenges[i])); }
        let rq = &challenges[join..];
        let mut g = Fp2::ZERO;
        for t in plan.terms.iter().filter(|t| t.piece == q) {
            let s = t.log_size as usize;
            let mut w = t.coef.mul(eq_bits(t.block, &rq[s..]));
            if let Some(tid) = t.table { w = w.mul(eq_point_lsb(&plan.keys.keys[tid], &rq[..s])); }
            g = g.add(w);
        }
        want = want.add(beta.mul(proof.terminals[q]).mul(g));
        mu_sum = mu_sum.add(mus[q].mul(proof.terminals[q]));
    }
    if want != claim { return Err("sumcheck terminal check fails".into()); }
    let fe = coeff_eval(&proof.final_coeffs, &challenges[(k_max - k_end) as usize..]);
    if fe != mu_sum { return Err("final polynomial != mu-combination of the terminals".into()); }
    // queries
    let l0 = (1usize << k_max) * inv_rate;
    let q_count = c.effective_queries();
    let idx = tr.challenge_indices(q_count, l0 / COSET);
    if proof.queries.len() != q_count { return Err("query count".into()); }
    let l_end = (1usize << k_end) * inv_rate;
    let half_inv = Fp::new(2).inv();
    let results: Vec<Result<(), String>> = proof.queries.par_iter().zip(idx.par_iter()).map(|(qo, &t0q)| {
        // open + check every leaf first
        let mut gi_flat = 0usize;
        let mut group_vals: Vec<Vec<Vec<Fp>>> = Vec::new(); // [ci][gi] -> the leaf's values
        for ci in 0..batch.len() {
            let mut per = Vec::new();
            for (gidx, (log_size, ids)) in groups[ci].iter().enumerate() {
                let (vals, path) = qo.groups.get(gi_flat).ok_or("missing group leaf")?;
                gi_flat += 1;
                if vals.len() != ids.len() * COSET { return Err(format!("commitment {ci} group {gidx}: leaf size")); }
                let lg = (1usize << log_size) * inv_rate;
                let leaves = lg / COSET;
                let ls = bitrev(t0q % leaves, leaves.trailing_zeros());
                if path.len() != leaves.trailing_zeros() as usize { return Err("group path length".into()); }
                let parts: Vec<&[Fp]> = vals.chunks(COSET).collect();
                let leaf = hash_fp_block(&parts);
                if !MerkleTree::verify_path(&proof.group_roots[ci][gidx], ls, &leaf, path) { return Err(format!("commitment {ci} group {gidx}: Merkle path fails")); }
                per.push(vals.clone());
            }
            group_vals.push(per);
        }
        if qo.groups.len() != gi_flat { return Err("extra group leaves".into()); }
        if qo.folds.len() != n_fold_trees { return Err("fold leaf count".into()); }
        let mut fold_vals: Vec<Vec<Fp2>> = Vec::new();
        for (fi, (vals, path)) in qo.folds.iter().enumerate() {
            let kf = k_max - COSET_LOG * (fi as u32 + 1);
            let lf = (1usize << kf) * inv_rate;
            let leaves = lf / COSET;
            let ls = bitrev(t0q % leaves, leaves.trailing_zeros());
            if vals.len() != COSET || path.len() != leaves.trailing_zeros() as usize { return Err("fold leaf shape".into()); }
            if !MerkleTree::verify_path(&proof.fold_roots[fi], ls, &hash_fp2_block(vals), path) { return Err(format!("fold tree {fi}: Merkle path fails")); }
            fold_vals.push(vals.clone());
        }
        // the walk
        let mut base = t0q; // t_0 < l0 / 16
        let mut l_stretch = l0;
        let mut l_cur = l0;
        let mut a_rem = COSET_LOG;
        let mut vals = vec![Fp2::ZERO; COSET];
        let mut stretch = 0usize;
        for j in 0..(k_max - k_end) as usize {
            // joins at round j
            for (q, &(ci, li, k)) in plan.all.iter().enumerate() {
                if (k_max - k) as usize != j { continue; }
                let (gidx, slot) = {
                    let mut found = None;
                    for (gidx, (_, ids)) in groups[ci].iter().enumerate() {
                        if let Some(slot) = ids.iter().position(|&x| x == li) { found = Some((gidx, slot)); }
                    }
                    found.unwrap()
                };
                let lp = (1usize << k) * inv_rate;
                let leaf = &group_vals[ci][gidx][slot * COSET..(slot + 1) * COSET];
                let j0 = base / (lp / COSET);
                let step = 1usize << (COSET_LOG - a_rem);
                for m in 0..(1usize << a_rem) {
                    let jp = j0 + m * step;
                    vals[m] = vals[m].add(mus[q].mul_base(leaf[bitrev(jp, COSET_LOG)]));
                }
            }
            // fold with r_j
            let r = challenges[j];
            let h = 1usize << (a_rem - 1);
            let lg_cur = l_cur.trailing_zeros();
            let winv = inv_root_of(lg_cur);
            for m in 0..h {
                let pos = base + m * (l_stretch / COSET);
                let yinv = winv.pow(pos as u64);
                let v0 = vals[m];
                let v1 = vals[m + h];
                let a = v0.add(v1).mul_base(half_inv);
                let b = v0.sub(v1).mul_base(half_inv).mul_base(yinv);
                vals[m] = a.add(r.mul(b));
            }
            a_rem -= 1;
            l_cur /= 2;
            if a_rem == 0 {
                let v = vals[0];
                if l_cur == l_end {
                    let x = root_of(l_end.trailing_zeros()).pow(base as u64);
                    if horner(&proof.final_coeffs, x) != v { return Err("final polynomial disagrees with the folded query".into()); }
                } else {
                    let leaves = l_cur / COSET;
                    let u = base % leaves;
                    let jp = base / leaves;
                    let leaf = &fold_vals[stretch];
                    if leaf[bitrev(jp, COSET_LOG)] != v { return Err(format!("fold tree {stretch} disagrees with the folded query")); }
                    for m in 0..COSET { vals[m] = leaf[bitrev(m, COSET_LOG)]; }
                    base = u;
                    l_stretch = l_cur;
                    a_rem = COSET_LOG;
                    stretch += 1;
                }
            }
        }
        if k_end == k_max {
            // no folds: every coset member against the final polynomial (all pieces join at round 0)
            for (q, &(ci, li, _)) in plan.all.iter().enumerate() {
                let (gidx, slot) = {
                    let mut found = None;
                    for (gidx, (_, ids)) in groups[ci].iter().enumerate() {
                        if let Some(slot) = ids.iter().position(|&x| x == li) { found = Some((gidx, slot)); }
                    }
                    found.unwrap()
                };
                let leaf = &group_vals[ci][gidx][slot * COSET..(slot + 1) * COSET];
                for m in 0..COSET { vals[m] = vals[m].add(mus[q].mul_base(leaf[bitrev(m, COSET_LOG)])); }
            }
            let w = root_of(l0.trailing_zeros());
            for m in 0..COSET {
                let pos = base + m * (l0 / COSET);
                if horner(&proof.final_coeffs, w.pow(pos as u64)) != vals[m] { return Err("final polynomial disagrees with the query (no-fold case)".into()); }
            }
        }
        Ok(())
    }).collect();
    for r in results { r?; }
    Ok(())
}

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pcs::Slice;

    /// the configuration is process-global: the compact tests run one at a time
    static TEST_LOCK: Mutex<()> = Mutex::new(());

    fn rng(seed: &mut u64) -> u64 {
        let mut x = *seed;
        x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
        *seed = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
    fn pt(seed: &mut u64, n: usize) -> Vec<Fp2> {
        (0..n).map(|_| Fp2::new(Fp::new(rng(seed) % crate::field::P), Fp::new(rng(seed) % crate::field::P))).collect()
    }

    #[test]
    fn ntt_dif_is_bitreversed_evaluation() {
        for log in [1u32, 3, 8, 13, 15] {
            let n = 1usize << log;
            let mut s = 77u64 + log as u64;
            let coeffs: Vec<Fp> = (0..n).map(|_| Fp::new(rng(&mut s) % crate::field::P)).collect();
            let mut a = coeffs.clone();
            ntt_dif(&mut a);
            let w = root_of(log);
            for t in [0usize, 1, 2, 5, n - 1, n / 3] {
                let x = w.pow(t as u64);
                let mut acc = Fp::ZERO;
                for c in coeffs.iter().rev() { acc = acc.mul(x).add(*c); }
                assert_eq!(a[bitrev(t, log)], acc, "log {log} t {t}");
            }
        }
    }

    #[test]
    fn mobius_matches_multilinear_evaluation() {
        let k = 6;
        let mut s = 5u64;
        let data: Vec<Fp> = (0..1 << k).map(|_| Fp::new(rng(&mut s) % 1000)).collect();
        let r = pt(&mut s, k);
        // Lagrange evaluation with variable j = bit j: eq_table_msb expects r[0] as the MSB
        let rr: Vec<Fp2> = r.iter().rev().copied().collect();
        let lag = crate::mle::eval_mle_base(&data, &rr);
        let mut c = data.clone();
        mobius_fp(&mut c);
        let cf: Vec<Fp2> = c.iter().map(|v| Fp2::from_base(*v)).collect();
        assert_eq!(coeff_eval(&cf, &r), lag);
    }

    #[test]
    fn pieces_and_queries() {
        assert_eq!(pieces_of(9 << 19, 3), vec![Piece { offset: 0, log_size: 22 }, Piece { offset: 1 << 22, log_size: 19 }]);
        assert_eq!(pieces_of(55 << 20, 3).iter().map(|p| p.log_size).collect::<Vec<_>>(), vec![25, 24, 23]);
        assert_eq!(pieces_of(1 << 14, 3), vec![Piece { offset: 0, log_size: 14 }]);
        assert_eq!(queries_for(4, 106), 157);
        assert_eq!(queries_for(2, 106), 256);
        assert_eq!(queries_for(8, 106), 128);
    }

    fn setup(seed: u64) -> (Vec<Fp>, Vec<Claim>, PcsParams) {
        // a 3 x 2^10 + 2^9 vector (two pieces after rounding: 2^11 + 2^10 -> 3.5 x 2^10 = 2^11 + 2^10 + 2^9 exact, 3 pieces)
        let n = 7usize << 9;
        let mut s = seed;
        let data: Vec<Fp> = (0..n).map(|_| Fp::from_i64((rng(&mut s) % 256) as i64 - 128)).collect();
        let p10 = pt(&mut s, 10);
        let p9 = pt(&mut s, 9);
        let rr = |p: &[Fp2]| p.to_vec();
        let ev = |off: usize, log: u32, p: &[Fp2]| crate::mle::eval_mle_base(&data[off..off + (1 << log)], p);
        let mut claims = vec![
            Claim { parts: vec![(Slice { offset: 0, log_size: 10 }, Fp2::ONE)], point: rr(&p10), sum: false, value: ev(0, 10, &p10) },
            Claim { parts: vec![(Slice { offset: 1 << 10, log_size: 10 }, Fp2::ONE)], point: rr(&p10), sum: false, value: ev(1 << 10, 10, &p10) },
            // an unaligned slice of 2^10 at offset 2^11 + 2^9 (crosses the 2^11 piece boundary and is not size-aligned)
            Claim { parts: vec![(Slice { offset: (1 << 11) + (1 << 9), log_size: 10 }, Fp2::ONE)], point: rr(&p10), sum: false, value: ev((1 << 11) + (1 << 9), 10, &p10) },
            Claim { parts: vec![(Slice { offset: 1 << 11, log_size: 9 }, Fp2::ONE), (Slice { offset: 3 << 10, log_size: 9 }, Fp2::U)], point: rr(&p9), sum: false, value: ev(1 << 11, 9, &p9).add(Fp2::U.mul(ev(3 << 10, 9, &p9))) },
        ];
        let sum: Fp2 = data[1 << 10..1 << 11].iter().fold(Fp2::ZERO, |a, v| a.add_base(*v));
        claims.push(Claim { parts: vec![(Slice { offset: 1 << 10, log_size: 10 }, Fp2::ONE)], point: vec![], sum: true, value: sum });
        (data, claims, PcsParams { log_cols: 9, inv_rate: 4, num_col_checks: 256 })
    }

    #[test]
    fn compact_commit_open_verify_and_tampers() {
        let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        configure(CompactCfg { enabled: true, inv_rate: 4, queries: 40, target_bits: 106, log_final: 5, max_pieces: 3, reencode: false });
        let (data, claims, params) = setup(11);
        let cm = commit_compact(&params, &data);
        assert_eq!(cm.pieces.len(), 3);
        let com = cm.commitment();
        let mut tr = Transcript::new(b"t");
        let proof = open_batch(&[(&cm, &claims)], &mut tr);
        let mut tv = Transcript::new(b"t");
        verify_batch(&[(&params, &com, &claims)], &proof, &mut tv).expect("honest accept");
        // reencode mode gives the same bytes
        configure(CompactCfg { enabled: true, inv_rate: 4, queries: 40, target_bits: 106, log_final: 5, max_pieces: 3, reencode: true });
        let cm2 = commit_compact(&params, &data);
        assert_eq!(cm2.root, cm.root);
        let mut tr2 = Transcript::new(b"t");
        let proof2 = open_batch(&[(&cm2, &claims)], &mut tr2);
        let (mut b1, mut b2) = (Vec::new(), Vec::new());
        proof.write_bytes(&mut b1);
        proof2.write_bytes(&mut b2);
        assert_eq!(b1, b2);
        assert_eq!(b1.len(), proof.size_bytes());
        configure(CompactCfg { enabled: true, inv_rate: 4, queries: 40, target_bits: 106, log_final: 5, max_pieces: 3, reencode: false });
        // wrong claimed value
        let mut bad = claims.clone();
        bad[2].value = bad[2].value.add(Fp2::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &bad)], &proof, &mut tv).is_err());
        // a corrupted opening leaf value
        let mut p = proof.clone();
        p.queries[3].groups[0].0[5] = p.queries[3].groups[0].0[5].add(Fp::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).unwrap_err().contains("Merkle"));
        // a wrong Merkle path
        let mut p = proof.clone();
        p.queries[0].groups[1].1.swap(0, 1);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).unwrap_err().contains("Merkle"));
        // a corrupted fold leaf
        let mut p = proof.clone();
        p.queries[1].folds[0].0[2] = p.queries[1].folds[0].0[2].add(Fp2::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).is_err());
        // a corrupted round message
        let mut p = proof.clone();
        p.rounds[4][1] = p.rounds[4][1].add(Fp2::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).is_err());
        // a corrupted terminal
        let mut p = proof.clone();
        p.terminals[0] = p.terminals[0].add(Fp2::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).is_err());
        // a corrupted final polynomial
        let mut p = proof.clone();
        p.final_coeffs[1] = p.final_coeffs[1].add(Fp2::ONE);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &p, &mut tv).is_err());
        // a different witness under the same claims (honest opening of the changed vector)
        let mut d2 = data.clone();
        d2[777] = d2[777].add(Fp::ONE);
        let cm3 = commit_compact(&params, &d2);
        let mut tr3 = Transcript::new(b"t");
        let proof3 = open_batch(&[(&cm3, &claims)], &mut tr3);
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &cm3.commitment(), &claims)], &proof3, &mut tv).is_err());
        let mut tv = Transcript::new(b"t");
        assert!(verify_batch(&[(&params, &com, &claims)], &proof3, &mut tv).is_err());
    }

    #[test]
    fn compact_batch_of_three_commitments() {
        let _g = TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
        configure(CompactCfg { enabled: true, inv_rate: 2, queries: 30, target_bits: 106, log_final: 6, max_pieces: 2, reencode: false });
        let (d1, c1, params) = setup(1);
        let (d2, c2, _) = setup(2);
        let mut s = 99u64;
        // a third, smaller commitment (2^9 elements, one claim) whose piece joins late
        let d3: Vec<Fp> = (0..512).map(|_| Fp::from_i64((rng(&mut s) % 256) as i64 - 128)).collect();
        let p9 = pt(&mut s, 9);
        let c3 = vec![Claim { parts: vec![(Slice { offset: 0, log_size: 9 }, Fp2::ONE)], point: p9.clone(), sum: false, value: crate::mle::eval_mle_base(&d3, &p9) }];
        let cm1 = commit_compact(&params, &d1);
        let cm2 = commit_compact(&params, &d2);
        let cm3 = commit_compact(&params, &d3);
        let (k1, k2, k3) = (cm1.commitment(), cm2.commitment(), cm3.commitment());
        let mut tr = Transcript::new(b"b");
        let proof = open_batch(&[(&cm1, &c1), (&cm2, &c2), (&cm3, &c3)], &mut tr);
        let mut tv = Transcript::new(b"b");
        verify_batch(&[(&params, &k1, &c1), (&params, &k2, &c2), (&params, &k3, &c3)], &proof, &mut tv).expect("batch accept");
        let mut bad = c3.clone();
        bad[0].value = bad[0].value.add(Fp2::ONE);
        let mut tv = Transcript::new(b"b");
        assert!(verify_batch(&[(&params, &k1, &c1), (&params, &k2, &c2), (&params, &k3, &bad)], &proof, &mut tv).is_err());
        configure(CompactCfg::DEFAULT);
    }
}
