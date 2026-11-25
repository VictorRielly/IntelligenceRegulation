//! Plain two-level code switch for B6a. Dimensions and keys come from the
//! trusted caller. The source opening binds W before its external draws.

use crate::field::{Fp, Fp2, P};
use crate::hashtag::{self, HashTag};
use crate::merkle::{Digest, MerkleTree};
use crate::mle::{eq_table_msb, interpolate_eval};
use crate::ntt::NttTables;
use crate::pcs::{hash_columns_keyed, salt_leaf_keyed};
use crate::rng::ZkRng;
use crate::transcript::Transcript;
use rayon::prelude::*;

/// [hostfix] Prover-side inputs shorter than this stay on the calling
/// thread; longer ones run on the rayon pool. Field arithmetic is exact and
/// canonical, so a parallel sum gives the same word as the serial one.
const PAR_MIN: usize = 1 << 12;
/// [hostfix] Smallest piece of work handed to one rayon task.
const PAR_CHUNK: usize = 1 << 10;
/// [hostfix] Switch-step generator rows built at once (bounds the memory).
const SWITCH_BATCH: usize = 32;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum TowerError {
    Geometry,
    NoncanonicalField,
    UntaggedTranscript,
    BaseClaim,
    FoldLength,
    FoldRecurrence,
    SampleCount,
    SampleIndex,
    SampleWidth,
    PathDepth,
    Authentication,
    BaseColumn,
}

/// A single public linear encoder and the rows of its generator matrix.
/// [hostfix] `Sync` so the prover can encode rows and build generator rows
/// on the rayon pool; `CoefficientRs` holds only a shared table reference.
pub(crate) trait LinearCode: Sync {
    fn width(&self) -> usize;
    fn positions(&self) -> usize;
    fn encode(&self, row: &[Fp2]) -> Result<Vec<Fp2>, TowerError>;
    fn generator(&self, position: usize) -> Result<Vec<Fp2>, TowerError>;
}

pub(crate) struct CoefficientRs<'a> {
    width: usize,
    positions: usize,
    ntt: &'a NttTables,
}

impl<'a> CoefficientRs<'a> {
    pub(crate) fn new(
        width: usize,
        positions: usize,
        ntt: &'a NttTables,
    ) -> Result<Self, TowerError> {
        if width == 0
            || width >= positions
            || !positions.is_power_of_two()
            || positions.trailing_zeros() > ntt.max_log
        {
            return Err(TowerError::Geometry);
        }
        Ok(Self {
            width,
            positions,
            ntt,
        })
    }
}

impl LinearCode for CoefficientRs<'_> {
    fn width(&self) -> usize {
        self.width
    }
    fn positions(&self) -> usize {
        self.positions
    }

    fn encode(&self, row: &[Fp2]) -> Result<Vec<Fp2>, TowerError> {
        if row.len() != self.width {
            return Err(TowerError::Geometry);
        }
        let mut re = vec![Fp::ZERO; self.positions];
        let mut im = vec![Fp::ZERO; self.positions];
        let mut power = Fp::ONE;
        let coset = Fp::new(7);
        for (i, entry) in row.iter().enumerate() {
            re[i] = entry.c0.mul(power);
            im[i] = entry.c1.mul(power);
            power = power.mul(coset);
        }
        self.ntt.forward(&mut re);
        self.ntt.forward(&mut im);
        Ok(re
            .into_iter()
            .zip(im)
            .map(|(lo, hi)| Fp2::new(lo, hi))
            .collect())
    }

    fn generator(&self, position: usize) -> Result<Vec<Fp2>, TowerError> {
        if position >= self.positions {
            return Err(TowerError::SampleIndex);
        }
        let group_root = self.ntt.roots[self.positions.trailing_zeros() as usize];
        let point = Fp::new(7).mul(group_root.pow(position as u64));
        let mut power = Fp::ONE;
        Ok((0..self.width)
            .map(|_| {
                let out = Fp2::from_base(power);
                power = power.mul(point);
                out
            })
            .collect())
    }
}

#[derive(Clone, Copy)]
pub(crate) struct TowerShape {
    pub rows: usize,
    pub switch_rows: usize,
    pub first_checks: usize,
    pub last_checks: usize,
}

impl TowerShape {
    fn check(self, first: &impl LinearCode, last: &impl LinearCode) -> Result<(), TowerError> {
        let packed = self
            .switch_rows
            .checked_mul(last.width())
            .ok_or(TowerError::Geometry)?;
        let width = first.width();
        if self.rows == 0
            || self.switch_rows == 0
            || self.rows.checked_next_power_of_two().is_none()
            || self.switch_rows.checked_next_power_of_two().is_none()
            || last.width() == 0
            || self.first_checks == 0
            || self.last_checks == 0
            || packed < width
            || packed - last.width() >= width
        {
            return Err(TowerError::Geometry);
        }
        for (message_width, positions) in
            [(width, first.positions()), (last.width(), last.positions())]
        {
            if message_width == 0 || message_width >= positions || !positions.is_power_of_two() {
                return Err(TowerError::Geometry);
            }
        }
        Ok(())
    }
}

#[derive(Clone, Debug)]
pub struct ColumnOpening {
    pub position: usize,
    pub values: Vec<Fp2>,
    pub salt: Digest,
    pub path: Vec<Digest>,
}

#[derive(Clone, Debug)]
pub struct TowerProof {
    pub first_fold: Vec<[Fp2; 3]>,
    pub switch_root: Digest,
    pub switch_openings: Vec<ColumnOpening>,
    pub last_fold: Vec<[Fp2; 3]>,
    pub base: Vec<Fp2>,
    pub last_openings: Vec<ColumnOpening>,
}

pub(crate) struct PreparedW {
    message: Vec<Fp2>,
    commitment: Commitment,
    tag: HashTag,
}

struct Commitment {
    encoded: Vec<Fp>,
    salts: Vec<Digest>,
    tree: MerkleTree,
    rows: usize,
}

fn canonical(field: Fp2) -> bool {
    field.c0.0 < P && field.c1.0 < P
}

fn check_transcript(tr: &Transcript, tag: &HashTag) -> Result<(), TowerError> {
    if tag.is_legacy() || tag.transcript_key().copied() != tr.fs_key() {
        return Err(TowerError::UntaggedTranscript);
    }
    Ok(())
}

impl Commitment {
    fn new(
        message: &[Fp2],
        rows: usize,
        code: &impl LinearCode,
        rng: &mut ZkRng,
        tag: &HashTag,
    ) -> Result<Self, TowerError> {
        let n = code.positions();
        let size = rows.checked_mul(code.width()).ok_or(TowerError::Geometry)?;
        let extent = rows
            .checked_mul(2)
            .and_then(|r| r.checked_mul(n))
            .ok_or(TowerError::Geometry)?;
        if message.len() != size {
            return Err(TowerError::Geometry);
        }
        let all_canonical = if message.len() < PAR_MIN {
            message.iter().copied().all(canonical)
        } else {
            message
                .par_iter()
                .with_min_len(PAR_CHUNK)
                .all(|word| canonical(*word))
        };
        if !all_canonical {
            return Err(TowerError::NoncanonicalField);
        }
        let mut encoded = vec![Fp::ZERO; extent];
        if extent < PAR_MIN || rows < 2 {
            for (r, msg) in message.chunks_exact(code.width()).enumerate() {
                let row = code.encode(msg)?;
                if row.len() != n {
                    return Err(TowerError::Geometry);
                }
                for (i, word) in row.into_iter().enumerate() {
                    encoded[2 * r * n + i] = word.c0;
                    encoded[(2 * r + 1) * n + i] = word.c1;
                }
            }
        } else {
            // [hostfix] One task per row: row r owns words [2rn, 2(r+1)n).
            // Results are kept in row order, so the first failing row's
            // error is the one returned, as in the serial loop.
            let outcomes: Vec<Result<(), TowerError>> = encoded
                .par_chunks_mut(2 * n)
                .zip(message.par_chunks_exact(code.width()))
                .map(|(out, msg)| {
                    let row = code.encode(msg)?;
                    if row.len() != n {
                        return Err(TowerError::Geometry);
                    }
                    let (lo, hi) = out.split_at_mut(n);
                    for (i, word) in row.into_iter().enumerate() {
                        lo[i] = word.c0;
                        hi[i] = word.c1;
                    }
                    Ok(())
                })
                .collect();
            for outcome in outcomes {
                outcome?;
            }
        }
        // Salts are drawn serially, in position order, after encoding.
        let salts: Vec<Digest> = (0..n).map(|_| rng.bytes32()).collect();
        let leaves = hash_columns_keyed(&encoded, 2 * rows, n, tag.column_key());
        let salted: Vec<Digest> = if n < PAR_MIN {
            leaves
                .iter()
                .zip(&salts)
                .map(|(leaf, salt)| salt_leaf_keyed(leaf, salt, tag.leaf_key()))
                .collect()
        } else {
            leaves
                .par_iter()
                .zip(salts.par_iter())
                .with_min_len(PAR_CHUNK)
                .map(|(leaf, salt)| salt_leaf_keyed(leaf, salt, tag.leaf_key()))
                .collect()
        };
        Ok(Self {
            encoded,
            salts,
            rows,
            tree: MerkleTree::build_keyed(salted, tag.node_key()),
        })
    }

    fn open(&self, samples: &[usize]) -> Vec<ColumnOpening> {
        let n = self.salts.len();
        samples
            .iter()
            .map(|&position| ColumnOpening {
                position,
                values: (0..self.rows)
                    .map(|row| {
                        Fp2::new(
                            self.encoded[2 * row * n + position],
                            self.encoded[(2 * row + 1) * n + position],
                        )
                    })
                    .collect(),
                salt: self.salts[position],
                path: self.tree.path(position),
            })
            .collect()
    }
}

fn verify_openings(
    root: &Digest,
    openings: &[ColumnOpening],
    samples: &[usize],
    rows: usize,
    positions: usize,
    tag: &HashTag,
) -> Result<(), TowerError> {
    if openings.len() != samples.len() {
        return Err(TowerError::SampleCount);
    }
    let depth = positions.trailing_zeros() as usize;
    for (opening, &position) in openings.iter().zip(samples) {
        if opening.position != position {
            return Err(TowerError::SampleIndex);
        }
        if opening.values.len() != rows {
            return Err(TowerError::SampleWidth);
        }
        if opening.path.len() != depth {
            return Err(TowerError::PathDepth);
        }
        if !opening.values.iter().copied().all(canonical) {
            return Err(TowerError::NoncanonicalField);
        }
        let mut hash = hashtag::hasher(tag.column_key());
        for value in &opening.values {
            hash.update(&value.to_bytes());
        }
        let leaf = salt_leaf_keyed(hash.finalize().as_bytes(), &opening.salt, tag.leaf_key());
        if !MerkleTree::verify_path_keyed(root, position, &leaf, &opening.path, tag.node_key()) {
            return Err(TowerError::Authentication);
        }
    }
    Ok(())
}

fn absorb_root(
    tr: &mut Transcript,
    label: &[u8],
    root: &Digest,
    rows: usize,
    code: &impl LinearCode,
) {
    tr.absorb_u64(b"b6a-rows", rows as u64);
    tr.absorb_u64(b"b6a-width", code.width() as u64);
    tr.absorb_u64(b"b6a-positions", code.positions() as u64);
    tr.absorb(label, root);
}

/// The caller absorbs this root before sampling the old A/H columns and
/// drawing the coefficients that determine the claim on W.
pub(crate) fn prepare_w(
    message: Vec<Fp2>,
    rows: usize,
    code: &impl LinearCode,
    rng: &mut ZkRng,
    tag: &HashTag,
) -> Result<PreparedW, TowerError> {
    if rows == 0
        || code.width() == 0
        || !code.positions().is_power_of_two()
        || code.width() >= code.positions()
    {
        return Err(TowerError::Geometry);
    }
    if tag.is_legacy() {
        return Err(TowerError::UntaggedTranscript);
    }
    let commitment = Commitment::new(&message, rows, code, rng, tag)?;
    Ok(PreparedW {
        message,
        commitment,
        tag: *tag,
    })
}

impl PreparedW {
    pub(crate) fn root(&self) -> Digest {
        self.commitment.tree.root()
    }
}

pub(crate) fn bind_w(
    tr: &mut Transcript,
    tag: &HashTag,
    root: &Digest,
    rows: usize,
    code: &impl LinearCode,
) -> Result<(), TowerError> {
    check_transcript(tr, tag)?;
    absorb_root(tr, b"b6a-w", root, rows, code);
    Ok(())
}

fn dot(left: &[Fp2], right: &[Fp2]) -> Fp2 {
    left.iter()
        .zip(right)
        .fold(Fp2::ZERO, |acc, (x, y)| acc.add(x.mul(*y)))
}

fn fold_in_place(data: &mut Vec<Fp2>, r: Fp2) {
    let half = data.len() / 2;
    let (left, right) = data.split_at_mut(half);
    for (a, b) in left.iter_mut().zip(right) {
        *a = a.add(r.mul(b.sub(*a)));
    }
    data.truncate(half);
}

/// [hostfix] Prover-only `dot`: the same zip-truncated sum, on the pool for
/// long inputs. Exact field addition makes the summation order irrelevant.
fn dot_par(left: &[Fp2], right: &[Fp2]) -> Fp2 {
    let len = left.len().min(right.len());
    if len < PAR_MIN {
        return dot(left, right);
    }
    left[..len]
        .par_iter()
        .zip(&right[..len])
        .with_min_len(PAR_CHUNK)
        .map(|(x, y)| x.mul(*y))
        .reduce(|| Fp2::ZERO, |a, b| a.add(b))
}

/// [hostfix] Prover-only `fold_in_place`: the same update of each entry of
/// the low half, in parallel for long inputs. The verifier keeps the serial
/// `fold_in_place`.
fn fold_in_place_par(data: &mut Vec<Fp2>, r: Fp2) {
    let half = data.len() / 2;
    if half < PAR_MIN {
        fold_in_place(data, r);
        return;
    }
    let (left, right) = data.split_at_mut(half);
    left.par_iter_mut()
        .zip(right.par_iter())
        .with_min_len(PAR_CHUNK)
        .for_each(|(a, b)| *a = a.add(r.mul(b.sub(*a))));
    data.truncate(half);
}

fn add3(x: [Fp2; 3], y: [Fp2; 3]) -> [Fp2; 3] {
    [x[0].add(y[0]), x[1].add(y[1]), x[2].add(y[2])]
}

/// [hostfix] One fused pass over a fold round: `[dot(m0, c0), dot(m1, c1),
/// s2]`, the middle entry only when `high` (otherwise zero). Every entry is
/// the same exact field sum the old code formed term by term.
fn round_sums(m0: &[Fp2], m1: &[Fp2], c0: &[Fp2], c1: &[Fp2], high: bool) -> [Fp2; 3] {
    let len = m0.len().min(m1.len()).min(c0.len()).min(c1.len());
    let term = |i: usize| -> [Fp2; 3] {
        let (a, b, u, v) = (m0[i], m1[i], c0[i], c1[i]);
        [
            a.mul(u),
            if high { b.mul(v) } else { Fp2::ZERO },
            b.double().sub(a).mul(v.double().sub(u)),
        ]
    };
    if len < PAR_MIN {
        (0..len).fold([Fp2::ZERO; 3], |acc, i| add3(acc, term(i)))
    } else {
        (0..len)
            .into_par_iter()
            .with_min_len(PAR_CHUNK)
            .map(term)
            .reduce(|| [Fp2::ZERO; 3], add3)
    }
}

fn padded_extent(rows: usize, width: usize) -> Result<usize, TowerError> {
    rows.checked_next_power_of_two()
        .and_then(|r| r.checked_mul(width))
        .ok_or(TowerError::Geometry)
}

struct ProvedFold {
    rounds: Vec<[Fp2; 3]>,
    message: Vec<Fp2>,
    coefficients: Vec<Fp2>,
    target: Fp2,
    point: Vec<Fp2>,
}

fn prove_fold(
    mut message: Vec<Fp2>,
    mut coefficients: Vec<Fp2>,
    rows: usize,
    width: usize,
    target: Fp2,
    tr: &mut Transcript,
) -> Result<ProvedFold, TowerError> {
    // [hostfix] The entry check `dot(message, coefficients) == target` is
    // done by the first round whenever that round sees every product (the
    // padded words are zero). It still runs here, before anything else, when
    // no round will run, when padding would truncate the message, or when the
    // geometry is refused (the old code checked the claim first).
    if message.len() != coefficients.len() {
        return Err(TowerError::BaseClaim);
    }
    let size = match padded_extent(rows, width) {
        Ok(size) => size,
        Err(error) => {
            if dot_par(&message, &coefficients) != target {
                return Err(TowerError::BaseClaim);
            }
            return Err(error);
        }
    };
    let checked_on_entry = message.len() > size || size <= width;
    if checked_on_entry && dot_par(&message, &coefficients) != target {
        return Err(TowerError::BaseClaim);
    }
    message.resize(size, Fp2::ZERO);
    coefficients.resize(size, Fp2::ZERO);
    let mut rounds: Vec<[Fp2; 3]> = Vec::new();
    let mut point = Vec::new();
    // The claimed sum of the next round: p(r) of the previous round's
    // quadratic, the verifier's own `interpolate_eval(round, r)`.
    let mut running = target;
    while message.len() > width {
        let half = message.len() / 2;
        let (m0, m1) = message.split_at(half);
        let (c0, c1) = coefficients.split_at(half);
        let first_round = rounds.is_empty();
        let [low, high, s2] = round_sums(m0, m1, c0, c1, first_round);
        let high = if first_round {
            if !checked_on_entry && low.add(high) != target {
                return Err(TowerError::BaseClaim);
            }
            high
        } else {
            running.sub(low)
        };
        let round = [low, high, s2];
        tr.absorb_fp2(b"b6a-fold-round", &round);
        let r = tr.challenge_fp2();
        running = interpolate_eval(&round, r);
        fold_in_place_par(&mut message, r);
        fold_in_place_par(&mut coefficients, r);
        rounds.push(round);
        point.push(r);
    }
    let target = dot_par(&message, &coefficients);
    Ok(ProvedFold {
        rounds,
        message,
        coefficients,
        target,
        point,
    })
}

fn replay_fold(
    proof: &[[Fp2; 3]],
    mut coefficients: Vec<Fp2>,
    rows: usize,
    width: usize,
    mut target: Fp2,
    tr: &mut Transcript,
) -> Result<(Fp2, Vec<Fp2>, Vec<Fp2>), TowerError> {
    let extent = padded_extent(rows, width)?;
    if proof.len() != (extent / width).trailing_zeros() as usize {
        return Err(TowerError::FoldLength);
    }
    coefficients.resize(extent, Fp2::ZERO);
    let mut challenges = Vec::with_capacity(proof.len());
    for round in proof {
        if !round.iter().copied().all(canonical) {
            return Err(TowerError::NoncanonicalField);
        }
        if round[0].add(round[1]) != target {
            return Err(TowerError::FoldRecurrence);
        }
        tr.absorb_fp2(b"b6a-fold-round", round);
        let r = tr.challenge_fp2();
        target = interpolate_eval(round, r);
        fold_in_place(&mut coefficients, r);
        challenges.push(r);
    }
    Ok((target, coefficients, challenges))
}

fn switch_claim(
    target: Fp2,
    coefficients: Vec<Fp2>,
    old_point: &[Fp2],
    columns: &[ColumnOpening],
    first: &impl LinearCode,
    new_extent: usize,
    mut draw: impl FnMut() -> Fp2,
) -> Result<(Fp2, Vec<Fp2>), TowerError> {
    let weights = eq_table_msb(old_point);
    // Reserve the first independent BAT coefficient for the carried claim.
    let carry = draw();
    let mut total = carry.mul(target);
    let mut coeffs: Vec<Fp2> = coefficients
        .into_iter()
        .map(|coefficient| carry.mul(coefficient))
        .collect();
    coeffs.resize(new_extent, Fp2::ZERO);
    for column in columns {
        let weight = draw();
        let generator = first.generator(column.position)?;
        if generator.len() != first.width() {
            return Err(TowerError::Geometry);
        }
        total = total.add(weight.mul(dot(&weights, &column.values)));
        for (out, g) in coeffs.iter_mut().zip(generator) {
            *out = out.add(weight.mul(g));
        }
    }
    Ok((total, coeffs))
}

/// [hostfix] Prover-only form of `switch_claim` (the verifier keeps that
/// one): the same draws in the same order, the same errors after the same
/// number of draws, the same total and coefficient vector. Generator rows
/// are pure functions of the public position, so a batch of them is built
/// on the pool before the batch's weights are drawn; the accumulation runs
/// over coefficient chunks on the pool. A row whose entries are all
/// base-field words is accumulated with `mul_base`, which gives the same
/// word as the general product when the second limb is zero.
fn switch_claim_prover(
    target: Fp2,
    coefficients: Vec<Fp2>,
    old_point: &[Fp2],
    columns: &[ColumnOpening],
    first: &impl LinearCode,
    new_extent: usize,
    mut draw: impl FnMut() -> Fp2,
) -> Result<(Fp2, Vec<Fp2>), TowerError> {
    if first.width() < PAR_MIN || columns.len() < 2 {
        return switch_claim(
            target,
            coefficients,
            old_point,
            columns,
            first,
            new_extent,
            draw,
        );
    }
    let weights = eq_table_msb(old_point);
    // Reserve the first independent BAT coefficient for the carried claim.
    let carry = draw();
    let mut total = carry.mul(target);
    let mut coeffs: Vec<Fp2> = coefficients
        .into_par_iter()
        .with_min_len(PAR_CHUNK)
        .map(|coefficient| carry.mul(coefficient))
        .collect();
    coeffs.resize(new_extent, Fp2::ZERO);
    let span = new_extent.min(first.width());
    for batch in columns.chunks(SWITCH_BATCH) {
        let rows: Vec<Result<(bool, Vec<Fp2>), TowerError>> = batch
            .par_iter()
            .map(|column| {
                let generator = first.generator(column.position)?;
                let base = generator.iter().all(|g| g.c1.is_zero());
                Ok((base, generator))
            })
            .collect();
        let mut accepted = Vec::with_capacity(batch.len());
        for (column, row) in batch.iter().zip(rows) {
            let weight = draw();
            let (base, generator) = row?;
            if generator.len() != first.width() {
                return Err(TowerError::Geometry);
            }
            total = total.add(weight.mul(dot(&weights, &column.values)));
            accepted.push((weight, base, generator));
        }
        coeffs[..span]
            .par_chunks_mut(PAR_CHUNK)
            .enumerate()
            .for_each(|(chunk, out)| {
                let start = chunk * PAR_CHUNK;
                for (weight, base, generator) in &accepted {
                    let g = &generator[start..start + out.len()];
                    if *base {
                        for (o, x) in out.iter_mut().zip(g) {
                            *o = o.add(weight.mul_base(x.c0));
                        }
                    } else {
                        for (o, x) in out.iter_mut().zip(g) {
                            *o = o.add(weight.mul(*x));
                        }
                    }
                }
            });
    }
    Ok((total, coeffs))
}

fn check_claim_input(
    coefficients: &[Fp2],
    target: Fp2,
    rows: usize,
    width: usize,
) -> Result<(), TowerError> {
    if rows.checked_mul(width) != Some(coefficients.len()) {
        return Err(TowerError::Geometry);
    }
    if !canonical(target) || !coefficients.iter().copied().all(canonical) {
        return Err(TowerError::NoncanonicalField);
    }
    Ok(())
}

/// Prove the claim after BAT on the already bound W. The old-position
/// indices are drawn after committing W2, and BASE precedes its indices.
pub(crate) fn prove_after_bind(
    w: PreparedW,
    coefficients: Vec<Fp2>,
    target: Fp2,
    shape: TowerShape,
    first: &impl LinearCode,
    last: &impl LinearCode,
    tag: &HashTag,
    rng: &mut ZkRng,
    tr: &mut Transcript,
) -> Result<TowerProof, TowerError> {
    check_transcript(tr, tag)?;
    shape.check(first, last)?;
    check_claim_input(&coefficients, target, shape.rows, first.width())?;
    if w.tag != *tag {
        return Err(TowerError::UntaggedTranscript);
    }
    if w.commitment.rows != shape.rows
        || w.commitment.salts.len() != first.positions()
        || w.message.len() != coefficients.len()
    {
        return Err(TowerError::Geometry);
    }
    let folded = prove_fold(
        w.message,
        coefficients,
        shape.rows,
        first.width(),
        target,
        tr,
    )?;
    let mut next = folded.message;
    let extent = shape.switch_rows * last.width();
    next.resize(extent, Fp2::ZERO);
    let last_commitment = Commitment::new(&next, shape.switch_rows, last, rng, tag)?;
    let switch_root = last_commitment.tree.root();
    absorb_root(tr, b"b6a-w2", &switch_root, shape.switch_rows, last);
    let samples = tr.challenge_indices(shape.first_checks, first.positions());
    let switch_openings = w.commitment.open(&samples);
    let (next_target, next_coefficients) = switch_claim_prover(
        folded.target,
        folded.coefficients,
        &folded.point,
        &switch_openings,
        first,
        extent,
        || tr.challenge_fp2(),
    )?;
    let last_fold = prove_fold(
        next,
        next_coefficients,
        shape.switch_rows,
        last.width(),
        next_target,
        tr,
    )?;
    let base = last_fold.message;
    tr.absorb_fp2(b"b6a-base", &base);
    let last_indices = tr.challenge_indices(shape.last_checks, last.positions());
    let last_openings = last_commitment.open(&last_indices);
    Ok(TowerProof {
        first_fold: folded.rounds,
        switch_root,
        switch_openings,
        last_fold: last_fold.rounds,
        base,
        last_openings,
    })
}

pub(crate) fn verify_after_bind(
    root: &Digest,
    proof: &TowerProof,
    coefficients: Vec<Fp2>,
    target: Fp2,
    shape: TowerShape,
    first: &impl LinearCode,
    last: &impl LinearCode,
    tag: &HashTag,
    tr: &mut Transcript,
) -> Result<(), TowerError> {
    check_transcript(tr, tag)?;
    shape.check(first, last)?;
    check_claim_input(&coefficients, target, shape.rows, first.width())?;
    let (folded_target, folded_coefficients, first_point) = replay_fold(
        &proof.first_fold,
        coefficients,
        shape.rows,
        first.width(),
        target,
        tr,
    )?;
    absorb_root(tr, b"b6a-w2", &proof.switch_root, shape.switch_rows, last);
    let samples = tr.challenge_indices(shape.first_checks, first.positions());
    verify_openings(
        root,
        &proof.switch_openings,
        &samples,
        shape.rows,
        first.positions(),
        tag,
    )?;
    let (next_target, next_coefficients) = switch_claim(
        folded_target,
        folded_coefficients,
        &first_point,
        &proof.switch_openings,
        first,
        shape.switch_rows * last.width(),
        || tr.challenge_fp2(),
    )?;
    let (base_target, base_coefficients, last_point) = replay_fold(
        &proof.last_fold,
        next_coefficients,
        shape.switch_rows,
        last.width(),
        next_target,
        tr,
    )?;
    if proof.base.len() != last.width() {
        return Err(TowerError::Geometry);
    }
    if !proof.base.iter().copied().all(canonical) {
        return Err(TowerError::NoncanonicalField);
    }
    if dot(&base_coefficients, &proof.base) != base_target {
        return Err(TowerError::BaseClaim);
    }
    tr.absorb_fp2(b"b6a-base", &proof.base);
    let last_samples = tr.challenge_indices(shape.last_checks, last.positions());
    verify_openings(
        &proof.switch_root,
        &proof.last_openings,
        &last_samples,
        shape.switch_rows,
        last.positions(),
        tag,
    )?;
    let base = last.encode(&proof.base)?;
    if base.len() != last.positions() {
        return Err(TowerError::Geometry);
    }
    let weights = eq_table_msb(&last_point);
    for column in &proof.last_openings {
        if dot(&weights, &column.values) != base[column.position] {
            return Err(TowerError::BaseColumn);
        }
    }
    Ok(())
}

#[cfg(test)]
#[path = "tower_tests.rs"]
mod tests;

/// [hostfix] The base prover functions (profile-9fbc85292 `tower.rs`,
/// sha256 a165008774508ecce9534af4e399ba04dcccd478323e98b8e217b9c68cfee5d4),
/// kept verbatim as the reference the faster prover is checked against.
#[cfg(test)]
mod hostfix_reference {
    use super::*;

    pub(super) fn fold_in_place(data: &mut Vec<Fp2>, r: Fp2) {
        let half = data.len() / 2;
        let (left, right) = data.split_at_mut(half);
        for (a, b) in left.iter_mut().zip(right) {
            *a = a.add(r.mul(b.sub(*a)));
        }
        data.truncate(half);
    }

    pub(super) fn prove_fold(
        mut message: Vec<Fp2>,
        mut coefficients: Vec<Fp2>,
        rows: usize,
        width: usize,
        target: Fp2,
        tr: &mut Transcript,
    ) -> Result<ProvedFold, TowerError> {
        if message.len() != coefficients.len() || dot(&message, &coefficients) != target {
            return Err(TowerError::BaseClaim);
        }
        let size = padded_extent(rows, width)?;
        message.resize(size, Fp2::ZERO);
        coefficients.resize(size, Fp2::ZERO);
        let mut rounds = Vec::new();
        let mut point = Vec::new();
        while message.len() > width {
            let half = message.len() / 2;
            let (m0, m1) = message.split_at(half);
            let (c0, c1) = coefficients.split_at(half);
            let s2 = m0
                .iter()
                .zip(m1)
                .zip(c0.iter().zip(c1))
                .fold(Fp2::ZERO, |sum, ((a, b), (u, v))| {
                    sum.add(b.double().sub(*a).mul(v.double().sub(*u)))
                });
            let round = [dot(m0, c0), dot(m1, c1), s2];
            tr.absorb_fp2(b"b6a-fold-round", &round);
            let r = tr.challenge_fp2();
            fold_in_place(&mut message, r);
            fold_in_place(&mut coefficients, r);
            rounds.push(round);
            point.push(r);
        }
        let target = dot(&message, &coefficients);
        Ok(ProvedFold {
            rounds,
            message,
            coefficients,
            target,
            point,
        })
    }

    pub(super) fn commitment_new(
        message: &[Fp2],
        rows: usize,
        code: &impl LinearCode,
        rng: &mut ZkRng,
        tag: &HashTag,
    ) -> Result<Commitment, TowerError> {
        let n = code.positions();
        let size = rows.checked_mul(code.width()).ok_or(TowerError::Geometry)?;
        let extent = rows
            .checked_mul(2)
            .and_then(|r| r.checked_mul(n))
            .ok_or(TowerError::Geometry)?;
        if message.len() != size {
            return Err(TowerError::Geometry);
        }
        if !message.iter().copied().all(canonical) {
            return Err(TowerError::NoncanonicalField);
        }
        let mut encoded = vec![Fp::ZERO; extent];
        for (r, msg) in message.chunks_exact(code.width()).enumerate() {
            let row = code.encode(msg)?;
            if row.len() != n {
                return Err(TowerError::Geometry);
            }
            for (i, word) in row.into_iter().enumerate() {
                encoded[2 * r * n + i] = word.c0;
                encoded[(2 * r + 1) * n + i] = word.c1;
            }
        }
        let salts: Vec<Digest> = (0..n).map(|_| rng.bytes32()).collect();
        let leaves = hash_columns_keyed(&encoded, 2 * rows, n, tag.column_key());
        let salted = leaves
            .iter()
            .zip(&salts)
            .map(|(leaf, salt)| salt_leaf_keyed(leaf, salt, tag.leaf_key()))
            .collect();
        Ok(Commitment {
            encoded,
            salts,
            rows,
            tree: MerkleTree::build_keyed(salted, tag.node_key()),
        })
    }

    pub(super) fn prepare_w(
        message: Vec<Fp2>,
        rows: usize,
        code: &impl LinearCode,
        rng: &mut ZkRng,
        tag: &HashTag,
    ) -> Result<PreparedW, TowerError> {
        if rows == 0
            || code.width() == 0
            || !code.positions().is_power_of_two()
            || code.width() >= code.positions()
        {
            return Err(TowerError::Geometry);
        }
        if tag.is_legacy() {
            return Err(TowerError::UntaggedTranscript);
        }
        let commitment = commitment_new(&message, rows, code, rng, tag)?;
        Ok(PreparedW {
            message,
            commitment,
            tag: *tag,
        })
    }

    #[allow(clippy::too_many_arguments)]
    pub(super) fn prove_after_bind(
        w: PreparedW,
        coefficients: Vec<Fp2>,
        target: Fp2,
        shape: TowerShape,
        first: &impl LinearCode,
        last: &impl LinearCode,
        tag: &HashTag,
        rng: &mut ZkRng,
        tr: &mut Transcript,
    ) -> Result<TowerProof, TowerError> {
        check_transcript(tr, tag)?;
        shape.check(first, last)?;
        check_claim_input(&coefficients, target, shape.rows, first.width())?;
        if w.tag != *tag {
            return Err(TowerError::UntaggedTranscript);
        }
        if w.commitment.rows != shape.rows
            || w.commitment.salts.len() != first.positions()
            || w.message.len() != coefficients.len()
        {
            return Err(TowerError::Geometry);
        }
        let folded = prove_fold(
            w.message,
            coefficients,
            shape.rows,
            first.width(),
            target,
            tr,
        )?;
        let mut next = folded.message;
        let extent = shape.switch_rows * last.width();
        next.resize(extent, Fp2::ZERO);
        let last_commitment = commitment_new(&next, shape.switch_rows, last, rng, tag)?;
        let switch_root = last_commitment.tree.root();
        absorb_root(tr, b"b6a-w2", &switch_root, shape.switch_rows, last);
        let samples = tr.challenge_indices(shape.first_checks, first.positions());
        let switch_openings = w.commitment.open(&samples);
        let (next_target, next_coefficients) = switch_claim(
            folded.target,
            folded.coefficients,
            &folded.point,
            &switch_openings,
            first,
            extent,
            || tr.challenge_fp2(),
        )?;
        let last_fold = prove_fold(
            next,
            next_coefficients,
            shape.switch_rows,
            last.width(),
            next_target,
            tr,
        )?;
        let base = last_fold.message;
        tr.absorb_fp2(b"b6a-base", &base);
        let last_indices = tr.challenge_indices(shape.last_checks, last.positions());
        let last_openings = last_commitment.open(&last_indices);
        Ok(TowerProof {
            first_fold: folded.rounds,
            switch_root,
            switch_openings,
            last_fold: last_fold.rounds,
            base,
            last_openings,
        })
    }
}

/// [hostfix] Old and new prover functions, output for output.
#[cfg(test)]
mod hostfix_tests {
    use super::hostfix_reference as old;
    use super::*;

    fn tag() -> HashTag {
        HashTag::for_profile("test/b6a/hostfix/1")
    }

    fn transcript(tag: &HashTag, seed: u64) -> Transcript {
        let mut tr = Transcript::new_tagged(b"b6a-hostfix-test", *tag.transcript_key().unwrap());
        tr.absorb_u64(b"seed", seed);
        tr
    }

    /// Same state, same squeeze counter, same next challenge.
    fn assert_same_transcript(a: &mut Transcript, b: &mut Transcript) {
        assert_eq!(a.state(), b.state());
        assert_eq!(a.counter(), b.counter());
        assert_eq!(a.challenge_fp2(), b.challenge_fp2());
    }

    /// A non-base, deliberately irregular code: generator rows with a
    /// nonzero second limb, and encoder errors on marked rows.
    struct TestCode {
        width: usize,
        positions: usize,
        extension: bool,
    }

    impl LinearCode for TestCode {
        fn width(&self) -> usize {
            self.width
        }
        fn positions(&self) -> usize {
            self.positions
        }
        fn encode(&self, row: &[Fp2]) -> Result<Vec<Fp2>, TowerError> {
            if row.len() != self.width {
                return Err(TowerError::Geometry);
            }
            if row[0] == Fp2::ZERO {
                return Err(TowerError::SampleWidth);
            }
            if row[0] == Fp2::ONE {
                return Ok(vec![Fp2::ONE; self.positions - 1]);
            }
            Ok((0..self.positions)
                .map(|i| row[i % self.width].mul_base(Fp::new(i as u64 + 1)))
                .collect())
        }
        fn generator(&self, position: usize) -> Result<Vec<Fp2>, TowerError> {
            if position >= self.positions {
                return Err(TowerError::SampleIndex);
            }
            Ok((0..self.width)
                .map(|j| {
                    let c0 = Fp::new((position * 7919 + j) as u64 + 1);
                    let c1 = if self.extension {
                        Fp::new((j * 3 + position) as u64 + 1)
                    } else {
                        Fp::ZERO
                    };
                    Fp2::new(c0, c1)
                })
                .collect())
        }
    }

    fn check_fold(rows: usize, width: usize, extra: usize, seed: u64) {
        let mut rng = ZkRng::new(seed, b"hostfix fold");
        let len = rows * width + extra;
        let message = rng.fp2_vec(len);
        let coefficients = rng.fp2_vec(len);
        let target = dot(&message, &coefficients);
        let tag = tag();
        let mut tr_old = transcript(&tag, seed);
        let mut tr_new = transcript(&tag, seed);
        let a = old::prove_fold(
            message.clone(),
            coefficients.clone(),
            rows,
            width,
            target,
            &mut tr_old,
        )
        .unwrap();
        let b = prove_fold(
            message.clone(),
            coefficients.clone(),
            rows,
            width,
            target,
            &mut tr_new,
        )
        .unwrap();
        let what = format!("rows={rows} width={width} extra={extra}");
        assert_eq!(a.rounds, b.rounds, "{what}");
        assert_eq!(a.message, b.message, "{what}");
        assert_eq!(a.coefficients, b.coefficients, "{what}");
        assert_eq!(a.target, b.target, "{what}");
        assert_eq!(a.point, b.point, "{what}");
        assert_same_transcript(&mut tr_old, &mut tr_new);

        // A false target: BaseClaim before any absorb, in both.
        let wrong = target.add(Fp2::ONE);
        let mut tr_old = transcript(&tag, seed);
        let mut tr_new = transcript(&tag, seed);
        let before = tr_new.state();
        let a = old::prove_fold(
            message.clone(),
            coefficients.clone(),
            rows,
            width,
            wrong,
            &mut tr_old,
        );
        let b = prove_fold(message, coefficients, rows, width, wrong, &mut tr_new);
        assert!(matches!(a, Err(TowerError::BaseClaim)), "{what}");
        assert!(matches!(b, Err(TowerError::BaseClaim)), "{what}");
        assert_eq!(tr_new.state(), before, "{what}");
        assert_same_transcript(&mut tr_old, &mut tr_new);
    }

    #[test]
    fn hostfix_prove_fold_matches_base_below_threshold() {
        for (seed, (rows, width, extra)) in [
            (5, 17, 0),
            (3, 4, 0),
            (1, 4, 0),
            (4, 8, 5),
            (2, 1, 0),
            (7, 100, 0),
        ]
        .into_iter()
        .enumerate()
        {
            check_fold(rows, width, extra, seed as u64);
        }
    }

    #[test]
    fn hostfix_prove_fold_matches_base_above_threshold() {
        check_fold(37, 300, 0, 11);
        check_fold(1, 5000, 0, 12);
        check_fold(9, 1500, 7000, 13);
        // Full shape: the second fold, 16 rows of 1,024.
        check_fold(16, 1024, 0, 14);
    }

    #[test]
    fn hostfix_prove_fold_matches_base_full_shape() {
        // Full shape: the first fold, 48 rows of 16,384 padded to 64.
        check_fold(48, 16384, 0, 15);
    }

    #[test]
    fn hostfix_prove_fold_error_paths_match_base() {
        let tag = tag();
        let mut rng = ZkRng::new(21, b"hostfix fold errors");
        let message = rng.fp2_vec(4);
        let coefficients = rng.fp2_vec(4);
        let target = dot(&message, &coefficients);
        // Unequal lengths.
        for (m, c) in [(message.clone(), rng.fp2_vec(5)), (rng.fp2_vec(6000), rng.fp2_vec(5999))] {
            let mut tr_old = transcript(&tag, 1);
            let mut tr_new = transcript(&tag, 1);
            let a = old::prove_fold(m.clone(), c.clone(), 2, 2, target, &mut tr_old);
            let b = prove_fold(m, c, 2, 2, target, &mut tr_new);
            assert!(matches!(a, Err(TowerError::BaseClaim)));
            assert!(matches!(b, Err(TowerError::BaseClaim)));
            assert_same_transcript(&mut tr_old, &mut tr_new);
        }
        // A refused geometry: the claim is still checked first.
        for (claim, want) in [
            (target, TowerError::Geometry),
            (target.add(Fp2::ONE), TowerError::BaseClaim),
        ] {
            let mut tr_old = transcript(&tag, 2);
            let mut tr_new = transcript(&tag, 2);
            let a = old::prove_fold(
                message.clone(),
                coefficients.clone(),
                usize::MAX,
                2,
                claim,
                &mut tr_old,
            );
            let b = prove_fold(
                message.clone(),
                coefficients.clone(),
                usize::MAX,
                2,
                claim,
                &mut tr_new,
            );
            assert!(matches!(a, Err(e) if e == want));
            assert!(matches!(b, Err(e) if e == want));
            assert_same_transcript(&mut tr_old, &mut tr_new);
        }
    }

    #[test]
    fn hostfix_fold_in_place_and_dot_match_base() {
        let mut rng = ZkRng::new(31, b"hostfix fold in place");
        for len in [0, 1, 2, 9, 2 * PAR_MIN - 1, 2 * PAR_MIN, 2 * PAR_MIN + 1, 3 * PAR_MIN + 5, 1 << 15] {
            let data = rng.fp2_vec(len);
            let r = rng.fp2();
            let mut a = data.clone();
            let mut b = data.clone();
            old::fold_in_place(&mut a, r);
            fold_in_place_par(&mut b, r);
            assert_eq!(a, b, "len={len}");
            let other = rng.fp2_vec(len + 3);
            assert_eq!(dot(&data, &other), dot_par(&data, &other), "len={len}");
            assert_eq!(dot(&other, &data), dot_par(&other, &data), "len={len}");
        }
    }

    fn check_commitment(code: &impl LinearCode, rows: usize, message: &[Fp2], seed: u64) {
        let tag = tag();
        let mut rng_old = ZkRng::new(seed, b"hostfix salts");
        let mut rng_new = ZkRng::new(seed, b"hostfix salts");
        let a = old::commitment_new(message, rows, code, &mut rng_old, &tag);
        let b = Commitment::new(message, rows, code, &mut rng_new, &tag);
        match (a, b) {
            (Ok(a), Ok(b)) => {
                assert_eq!(a.encoded, b.encoded);
                assert_eq!(a.salts, b.salts);
                assert_eq!(a.rows, b.rows);
                assert_eq!(a.tree.root(), b.tree.root());
                let n = code.positions();
                for position in [0, 1, n / 2, n - 1] {
                    assert_eq!(a.tree.path(position), b.tree.path(position));
                }
            }
            (Err(a), Err(b)) => assert_eq!(a, b),
            (a, b) => panic!("old ok={} new ok={}", a.is_ok(), b.is_ok()),
        }
        assert_eq!(rng_old.bytes32(), rng_new.bytes32());
    }

    #[test]
    fn hostfix_commitment_matches_base() {
        for (rows, width, positions) in [
            (5usize, 17usize, 32usize),
            (3, 100, 256),
            (1, 3000, 8192),
            (7, 600, 1024),
            (6, 2048, 4096),
            // Full shape: W2, 16 rows of 1,024 on 32,768 positions.
            (16, 1024, 32768),
        ] {
            let ntt = NttTables::new(positions.trailing_zeros());
            let code = CoefficientRs::new(width, positions, &ntt).unwrap();
            let mut rng = ZkRng::new(rows as u64, b"hostfix commit");
            let message = rng.fp2_vec(rows * width);
            check_commitment(&code, rows, &message, 40 + rows as u64);
        }
    }

    #[test]
    fn hostfix_commitment_matches_base_full_shape() {
        // Full shape: W, 48 rows of 16,384 at rate 1/4.
        let ntt = NttTables::new(16);
        let code = CoefficientRs::new(16384, 65536, &ntt).unwrap();
        let mut rng = ZkRng::new(48, b"hostfix commit");
        let message = rng.fp2_vec(48 * 16384);
        check_commitment(&code, 48, &message, 99);
    }

    #[test]
    fn hostfix_commitment_errors_match_base() {
        let code = TestCode {
            width: 64,
            positions: 512,
            extension: false,
        };
        let mut rng = ZkRng::new(51, b"hostfix commit errors");
        let good = rng.fp2_vec(8 * 64);
        check_commitment(&code, 8, &good, 1);
        // Row 3 fails in the encoder, row 5 returns a short row: the first
        // failing row's error is returned, and no salt is drawn.
        let mut bad = good.clone();
        bad[3 * 64] = Fp2::ZERO;
        bad[5 * 64] = Fp2::ONE;
        check_commitment(&code, 8, &bad, 2);
        let mut short = good.clone();
        short[5 * 64] = Fp2::ONE;
        check_commitment(&code, 8, &short, 3);
        let mut noncanonical = good.clone();
        noncanonical[7] = Fp2::from_base(Fp(P));
        check_commitment(&code, 8, &noncanonical, 4);
        check_commitment(&code, 8, &good[1..], 5);
    }

    fn check_switch(
        code: &impl LinearCode,
        rows: usize,
        columns: usize,
        new_extent: usize,
        bad_column: Option<usize>,
        seed: u64,
    ) {
        let mut rng = ZkRng::new(seed, b"hostfix switch");
        let target = rng.fp2();
        let coefficients = rng.fp2_vec(code.width());
        let point = rng.fp2_vec(rows.next_power_of_two().trailing_zeros() as usize);
        let mut openings: Vec<ColumnOpening> = (0..columns)
            .map(|_| ColumnOpening {
                position: (rng.next_u64() as usize) % code.positions(),
                values: rng.fp2_vec(rows),
                salt: [0; 32],
                path: vec![],
            })
            .collect();
        if let Some(k) = bad_column {
            openings[k].position = code.positions();
        }
        let tag = tag();
        let mut tr_old = transcript(&tag, seed);
        let mut tr_new = transcript(&tag, seed);
        let a = switch_claim(
            target,
            coefficients.clone(),
            &point,
            &openings,
            code,
            new_extent,
            || tr_old.challenge_fp2(),
        );
        let b = switch_claim_prover(
            target,
            coefficients,
            &point,
            &openings,
            code,
            new_extent,
            || tr_new.challenge_fp2(),
        );
        assert_eq!(a, b, "columns={columns} extent={new_extent} bad={bad_column:?}");
        assert_eq!(a.is_err(), bad_column.is_some());
        assert_same_transcript(&mut tr_old, &mut tr_new);
    }

    #[test]
    fn hostfix_switch_claim_matches_base() {
        let ntt = NttTables::new(5);
        let small = CoefficientRs::new(17, 32, &ntt).unwrap();
        check_switch(&small, 5, 12, 18, None, 1);
        for extension in [false, true] {
            let code = TestCode {
                width: 5000,
                positions: 8192,
                extension,
            };
            for (columns, extent, bad) in [
                (1, 5000, None),
                (40, 5000, None),
                (70, 6000, None),
                (33, 4096, None),
                (50, 5000, Some(37)),
                (50, 5000, Some(0)),
            ] {
                check_switch(&code, 37, columns, extent, bad, 2 + columns as u64);
            }
        }
    }

    #[test]
    fn hostfix_switch_claim_matches_base_full_shape() {
        // Full shape: W of 16,384 on 65,536 positions, 48 rows, switch
        // rows 16 of 1,024, at the three sample counts of the record.
        let ntt = NttTables::new(16);
        let code = CoefficientRs::new(16384, 65536, &ntt).unwrap();
        for columns in [138, 169, 280] {
            check_switch(&code, 48, columns, 16 * 1024, None, columns as u64);
        }
        check_switch(&code, 48, 169, 16 * 1024, Some(100), 7);
    }

    fn check_tower(
        shape: TowerShape,
        first: &CoefficientRs<'_>,
        last: &CoefficientRs<'_>,
        seed: u64,
    ) {
        let tag = tag();
        let mut rng = ZkRng::new(seed, b"hostfix tower rows");
        let message = rng.fp2_vec(shape.rows * first.width());
        let coefficients = rng.fp2_vec(message.len());
        let target = dot(&message, &coefficients);
        let mut rng_old = ZkRng::new(seed, b"hostfix tower salts");
        let mut rng_new = ZkRng::new(seed, b"hostfix tower salts");
        let w_old = old::prepare_w(message.clone(), shape.rows, first, &mut rng_old, &tag).unwrap();
        let w_new = prepare_w(message, shape.rows, first, &mut rng_new, &tag).unwrap();
        let root = w_new.root();
        assert_eq!(w_old.root(), root);
        let mut tr_old = transcript(&tag, seed);
        let mut tr_new = transcript(&tag, seed);
        bind_w(&mut tr_old, &tag, &root, shape.rows, first).unwrap();
        bind_w(&mut tr_new, &tag, &root, shape.rows, first).unwrap();
        let a = old::prove_after_bind(
            w_old,
            coefficients.clone(),
            target,
            shape,
            first,
            last,
            &tag,
            &mut rng_old,
            &mut tr_old,
        )
        .unwrap();
        let b = prove_after_bind(
            w_new,
            coefficients.clone(),
            target,
            shape,
            first,
            last,
            &tag,
            &mut rng_new,
            &mut tr_new,
        )
        .unwrap();
        assert_eq!(format!("{a:?}"), format!("{b:?}"));
        assert_eq!(a.first_fold, b.first_fold);
        assert_eq!(a.switch_root, b.switch_root);
        assert_eq!(a.last_fold, b.last_fold);
        assert_eq!(a.base, b.base);
        let mut tr_verify = transcript(&tag, seed);
        bind_w(&mut tr_verify, &tag, &root, shape.rows, first).unwrap();
        verify_after_bind(
            &root,
            &b,
            coefficients,
            target,
            shape,
            first,
            last,
            &tag,
            &mut tr_verify,
        )
        .unwrap();
        assert_eq!(tr_verify.state(), tr_new.state());
        assert_same_transcript(&mut tr_old, &mut tr_new);
        assert_eq!(rng_old.bytes32(), rng_new.bytes32());
    }

    #[test]
    fn hostfix_tower_proof_matches_base() {
        let ntt = NttTables::new(10);
        let first = CoefficientRs::new(17, 32, &ntt).unwrap();
        let last = CoefficientRs::new(6, 16, &ntt).unwrap();
        let shape = TowerShape {
            rows: 5,
            switch_rows: 3,
            first_checks: 12,
            last_checks: 9,
        };
        for seed in 0..4 {
            check_tower(shape, &first, &last, seed);
        }
        let first = CoefficientRs::new(300, 1024, &ntt).unwrap();
        let last = CoefficientRs::new(20, 32, &ntt).unwrap();
        let shape = TowerShape {
            rows: 37,
            switch_rows: 15,
            first_checks: 20,
            last_checks: 9,
        };
        check_tower(shape, &first, &last, 10);
    }

    #[test]
    fn hostfix_tower_proof_matches_base_full_shape() {
        // 48 rows of 16,384 (padded to 64) on 65,536 positions; switch rows
        // 16 of 1,024 on 32,768 positions; 169 and 120 checks.
        let ntt = NttTables::new(16);
        let first = CoefficientRs::new(16384, 65536, &ntt).unwrap();
        let last = CoefficientRs::new(1024, 32768, &ntt).unwrap();
        let shape = TowerShape {
            rows: 48,
            switch_rows: 16,
            first_checks: 169,
            last_checks: 120,
        };
        check_tower(shape, &first, &last, 77);
    }
}
