//! The evaluation and LogUp helpers the v2 and v3 layer provers share.
//!
//! CL20 round 16 (the Codex re-scope of 2026-09-08) moves exactly ONE pure
//! helper ahead of the prover: [`eval_many`]. `MIGRATION.md`, "The next step
//! in detail", lists it under blocker (i) of piece 2c — "the helper-column
//! builders, `HostTabsV3`, the zero-check table construction and `eval_many`
//! that the v2 and v3 provers share inside `layer.rs`" — and it is the only
//! member of that list that is a pure function of its arguments: no
//! transcript, no randomness, no environment, no filesystem and no backend
//! dispatch (the GPU arm lives in hashline's `eval_many_dev`, which calls
//! this function as its host path). Its move is byte-neutral by construction:
//! the body is the pre-move body verbatim, and `Fp2` addition is associative
//! and commutative, so the rayon reduction order cannot change a value.
//!
//! The module is named `logup` because that is where the parked step-2c
//! extraction (`results/zk60_cl20_step2c_wip.diff`) puts the rest of the
//! shared helpers — `to_fp_i32`, `to_fp2_i32`, `sum_fp2`, `helper_column`,
//! `helper_constraint`, `fold_block_i8`, `multiplicities` — and where the
//! parked `Backend::try_eval_many` hook already points ("==
//! `ffn_v3::logup::eval_many`"). `eval_many` itself is a general multilinear
//! evaluation, not a LogUp-specific one; it earns its place here by being the
//! first tenant of that shared-helper module.
//!
//! Not moved this round, and still in `hashline/src/layer.rs`: the helper
//! column builder and its zero-check constraint, the multiplicity tables,
//! `HostTabsV3`, and the conversion/fold helpers. `hashline/src/zk.rs` keeps
//! its own private copy of `eval_many` (zk.rs:934, semantically identical,
//! formatted differently); it is on the round's do-not-touch list and is
//! deduplicated with the masking extraction, not here.

use crate::field::{Fp, Fp2};
use crate::mle::eq_table_msb;
use rayon::prelude::*;

/// Evaluate several base-field slices at one point (one eq table).
///
/// Each `(off, len)` slice of `data` is read as the values of a multilinear
/// polynomial over `point.len()` variables in the MSB convention (`point[0]`
/// is the most significant index bit), so `eval_many(data, &[(off, len)], r)`
/// is `mle::eval_mle_base(&data[off..off + len], r)` — the point of the
/// function is that one `eq` table serves every slice. `len` must equal
/// `2^point.len()` for every slice; it panics otherwise.
pub fn eval_many(data: &[Fp], slices: &[(usize, usize)], point: &[Fp2]) -> Vec<Fp2> {
    let eq = eq_table_msb(point);
    slices
        .iter()
        .map(|&(off, len)| {
            assert_eq!(len, eq.len());
            data[off..off + len].par_iter().zip(eq.par_iter()).map(|(a, e)| e.mul_base(*a)).reduce(|| Fp2::ZERO, |a, b| a.add(b))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::mle::eval_mle_base;

    /// The deterministic sample: an LCG over the base field, and points whose
    /// coordinates are full extension elements (both components non-zero, as
    /// the transcript's challenges are).
    struct Lcg(u64);
    impl Lcg {
        fn next(&mut self) -> u64 {
            self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
            self.0 >> 11
        }
        fn fp(&mut self) -> Fp {
            Fp::new(self.next())
        }
        fn fp2(&mut self) -> Fp2 {
            Fp2::new(self.fp(), self.fp())
        }
    }

    /// `eval_many` is `eval_mle_base` on each slice, sharing one eq table:
    /// the independent oracle for the value it returns.
    #[test]
    fn eval_many_is_eval_mle_base_on_every_slice() {
        let mut g = Lcg(20260916);
        // 4096 base elements is room for a 12-variable slice at offset 0 and
        // several shorter ones at offsets before and after it.
        let data: Vec<Fp> = (0..4096).map(|_| g.fp()).collect();
        let mut cases = 0usize;
        for nvars in 0..=12usize {
            let len = 1usize << nvars;
            let point: Vec<Fp2> = (0..nvars).map(|_| g.fp2()).collect();
            // every offset that keeps the slice inside `data`, at a stride
            // that stays cheap while covering the head, an odd interior
            // offset and the tail.
            let offs: Vec<usize> = [0usize, len / 3, (data.len() - len) / 2 + 1, data.len() - len]
                .into_iter()
                .filter(|&o| o + len <= data.len())
                .collect();
            let slices: Vec<(usize, usize)> = offs.iter().map(|&o| (o, len)).collect();
            let got = eval_many(&data, &slices, &point);
            assert_eq!(got.len(), slices.len());
            for (i, &(off, l)) in slices.iter().enumerate() {
                assert_eq!(got[i], eval_mle_base(&data[off..off + l], &point), "nvars {nvars}, slice {i} at {off}");
                cases += 1;
            }
        }
        assert!(cases >= 40, "the sample must cover every variable count");
    }

    /// One eq table, several slices: the results follow the caller's slice
    /// order, repeats included, and no slice influences another.
    #[test]
    fn eval_many_follows_the_slice_order_and_allows_repeats() {
        let mut g = Lcg(7);
        let data: Vec<Fp> = (0..64).map(|_| g.fp()).collect();
        let point: Vec<Fp2> = (0..4).map(|_| g.fp2()).collect();
        let a = eval_many(&data, &[(0, 16)], &point)[0];
        let b = eval_many(&data, &[(16, 16)], &point)[0];
        let c = eval_many(&data, &[(48, 16)], &point)[0];
        assert_eq!(eval_many(&data, &[(0, 16), (16, 16), (48, 16)], &point), vec![a, b, c]);
        assert_eq!(eval_many(&data, &[(48, 16), (0, 16), (16, 16)], &point), vec![c, a, b]);
        assert_eq!(eval_many(&data, &[(0, 16), (0, 16)], &point), vec![a, a]);
        assert!(eval_many(&data, &[], &point).is_empty());
    }

    /// The zero-variable case the layout uses for a single committed value:
    /// the empty point evaluates a one-element slice to itself.
    #[test]
    fn the_empty_point_reads_one_element() {
        let data: Vec<Fp> = (0..4).map(|i| Fp::from_i64(i + 1)).collect();
        assert_eq!(eval_many(&data, &[(0, 1), (3, 1)], &[]), vec![Fp2::from_i64(1), Fp2::from_i64(4)]);
    }

    /// A slice length that is not `2^point.len()` is a caller bug, not a
    /// silently wrong claim.
    #[test]
    #[should_panic]
    fn a_slice_length_that_does_not_match_the_point_panics() {
        let data: Vec<Fp> = (0..8).map(|i| Fp::from_i64(i)).collect();
        let point = vec![Fp2::from_i64(3), Fp2::from_i64(5)];
        let _ = eval_many(&data, &[(0, 8)], &point);
    }
}
