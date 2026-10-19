//! Additive round evaluator interface. The original `prove` remains the oracle.

use super::{ProverOutput, SumcheckProof};
use crate::field::Fp2;
use crate::mle::interpolate_eval;
use crate::transcript::Transcript;
use rayon::prelude::*;

/// One sumcheck's arithmetic, independent of host/device table storage.
///
/// Preservation contract: `round(j)` returns UNMASKED evaluations at
/// `0..=degree` in that order. It must not absorb messages, draw challenges or
/// consume blinding randomness. The driver absorbs exactly one `sc-round`,
/// lets the existing transcript masker act, draws one challenge, then calls
/// `fold`. That challenge folds the original tables, in most-significant-bit
/// variable order. `finals` preserves the caller's table order. Masked claims,
/// extension rounds, terminals, openings and refusal handling remain with the
/// caller. Implementations may change arithmetic, never the field values.
///
/// Deliberately no `Sync` supertrait: a device evaluator can own a non-Sync
/// handle. Only CPU closures that parallelize internally require `Sync`.
pub trait SumcheckRounds {
    fn n_vars(&self) -> usize;
    fn degree(&self) -> usize;
    fn round(&mut self, j: usize) -> Vec<Fp2>;
    fn fold(&mut self, r: Fp2);
    fn finals(&self) -> Vec<Fp2>;
}

/// Same transcript schedule and output convention as the original `prove`.
/// `proof.rounds` is unmasked even when a masker is installed; the masked
/// wrapper must obtain the published rounds through `Transcript::take_masker`.
pub fn prove_rounds<R: SumcheckRounds + ?Sized>(ev: &mut R, tr: &mut Transcript) -> ProverOutput {
    let n = ev.n_vars();
    let degree = ev.degree();
    let mut rounds = Vec::with_capacity(n);
    let mut challenges = Vec::with_capacity(n);
    for j in 0..n {
        let sums = ev.round(j);
        assert_eq!(sums.len(), degree + 1, "sumcheck evaluator round length");
        tr.absorb_fp2(b"sc-round", &sums);
        let r = tr.challenge_fp2();
        ev.fold(r);
        rounds.push(sums);
        challenges.push(r);
    }
    ProverOutput { proof: SumcheckProof { rounds }, challenges, finals: ev.finals() }
}

/// CPU evaluator using the existing closure/table layout and parallel cutoffs.
/// The closure must be a pure polynomial with the stated round degree.
pub struct ClosureRounds<'a, F> {
    tables: &'a mut Vec<Vec<Fp2>>,
    degree: usize,
    poly: F,
    n_vars: usize,
    next: usize,
    pending: Option<Vec<Fp2>>,
    recover_one: bool,
    unmasked_claim: Option<Fp2>,
}

impl<'a, F: Fn(&[Fp2]) -> Fp2 + Sync> ClosureRounds<'a, F> {
    pub fn new(tables: &'a mut Vec<Vec<Fp2>>, degree: usize, poly: F) -> Self {
        assert!(!tables.is_empty());
        let len = tables[0].len();
        assert!(len.is_power_of_two());
        assert!(tables.iter().all(|t| t.len() == len));
        Self { tables, degree, poly, n_vars: len.trailing_zeros() as usize,
            next: 0, pending: None, recover_one: false, unmasked_claim: None }
    }

    /// R1d: recover s(1) = unmasked_claim - s(0) instead of evaluating it.
    ///
    /// `Some` must be the exact UNMASKED sum of this polynomial on this cube,
    /// not the public scalar containing CFS masks or hosted-claim offsets.
    /// `None` evaluates the first round fully and starts recovery thereafter.
    /// Subsequent claims interpolate the UNMASKED round at the challenge drawn
    /// from the MASKED transcript. No extra transcript or RNG draw is made.
    /// Debug builds also evaluate s(1) and assert the claimed identity; release
    /// tests must compare the skipped-evaluation path against the old prover.
    pub fn recover_one(mut self, initial_unmasked_claim: Option<Fp2>) -> Self {
        assert!(self.degree >= 1, "claim recovery requires degree >= 1");
        self.recover_one = true;
        self.unmasked_claim = initial_unmasked_claim;
        self
    }
}

impl<F: Fn(&[Fp2]) -> Fp2 + Sync> SumcheckRounds for ClosureRounds<'_, F> {
    fn n_vars(&self) -> usize { self.n_vars }
    fn degree(&self) -> usize { self.degree }

    fn round(&mut self, j: usize) -> Vec<Fp2> {
        assert_eq!(j, self.next, "sumcheck evaluator round order");
        assert!(j < self.n_vars && self.pending.is_none(), "round needs the preceding fold");
        let k = self.tables.len();
        let half = self.tables[0].len() / 2;
        let small = half * k <= 1 << 16;
        let chunk = if small { half.max(1) } else { 1024usize.min(half).max(1) };
        let n_chunks = (half + chunk - 1) / chunk;
        let claim = if self.recover_one { self.unmasked_claim } else { None };
        let eval_one = claim.is_none() || cfg!(debug_assertions);
        let tables = &*self.tables;
        let poly = &self.poly;
        let degree = self.degree;
        let round_of = |ci: usize| {
            let lo = ci * chunk;
            let hi = (lo + chunk).min(half);
            let mut acc = vec![Fp2::ZERO; degree + 1];
            let mut cur = vec![Fp2::ZERO; k];
            let mut dif = vec![Fp2::ZERO; k];
            for i in lo..hi {
                for (t, tb) in tables.iter().enumerate() {
                    cur[t] = tb[i];
                    dif[t] = tb[i + half].sub(tb[i]);
                }
                acc[0] = acc[0].add(poly(&cur));
                for d in 1..=degree {
                    for t in 0..k { cur[t] = cur[t].add(dif[t]); }
                    if d != 1 || eval_one { acc[d] = acc[d].add(poly(&cur)); }
                }
            }
            acc
        };
        let mut sums = if small {
            round_of(0)
        } else {
            (0..n_chunks).into_par_iter().map(round_of).reduce(
                || vec![Fp2::ZERO; degree + 1],
                |mut a, b| {
                    for (x, y) in a.iter_mut().zip(b.iter()) { *x = x.add(*y); }
                    a
                },
            )
        };
        if let Some(claim) = claim {
            debug_assert_eq!(sums[0].add(sums[1]), claim, "R1d unmasked claim mismatch");
            sums[1] = claim.sub(sums[0]);
        }
        self.pending = Some(sums.clone());
        sums
    }

    fn fold(&mut self, r: Fp2) {
        let sums = self.pending.take().expect("fold needs a round");
        if self.recover_one { self.unmasked_claim = Some(interpolate_eval(&sums, r)); }
        let half = self.tables[0].len() / 2;
        let small = half * self.tables.len() <= 1 << 16;
        for tb in self.tables.iter_mut() {
            let (lo, hi) = tb.split_at_mut(half);
            if small {
                for (a, b) in lo.iter_mut().zip(hi[..half].iter()) { *a = a.add(r.mul(b.sub(*a))); }
            } else {
                lo.par_iter_mut().zip(hi[..half].par_iter()).for_each(|(a, b)| { *a = a.add(r.mul(b.sub(*a))); });
            }
            tb.truncate(half);
        }
        self.next += 1;
    }

    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n_vars, "finals need all folds");
        assert!(self.pending.is_none());
        self.tables.iter().map(|t| t[0]).collect()
    }
}

#[cfg(test)]
mod tests;
