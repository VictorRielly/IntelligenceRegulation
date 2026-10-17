//! Uncompiled, unapplied serial sketch for zkp-core/src/sumcheck/grouped.rs.
//! Per-proof public state only. No change to masks, transcript or verifier.
use crate::field::Fp2;

struct SuffixLevels {
    // Index k is the table of point[k..]. A level is freed after last use.
    levels: Vec<Option<Vec<Fp2>>>,
    released: usize,
}

impl SuffixLevels {
    fn new(point: &[Fp2]) -> Self {
        let mut levels: Vec<Option<Vec<Fp2>>> = vec![None; point.len() + 1];
        levels[point.len()] = Some(vec![Fp2::ONE]);
        for k in (0..point.len()).rev() {
            let tail = levels[k + 1].as_ref().unwrap();
            let w = point[k];
            let other = Fp2::ONE.sub(w);
            let mut out = Vec::with_capacity(2 * tail.len());
            out.extend(tail.iter().map(|v| other.mul(*v)));
            out.extend(tail.iter().map(|v| w.mul(*v)));
            levels[k] = Some(out);
        }
        Self { levels, released: 0 }
    }

    fn get(&self, k: usize) -> &[Fp2] {
        self.levels[k].as_deref().expect("suffix level already released")
    }

    fn release_before(&mut self, k: usize) {
        assert!(k >= self.released && k < self.levels.len());
        for i in self.released..k { drop(self.levels[i].take()); }
        self.released = k;
    }
}

pub(crate) struct SplitEqSuffixCache {
    left: SuffixLevels,
    right: SuffixLevels,
    start: usize,
    end: usize,
    point_len: usize,
    base: usize,
    boundary: usize,
    n_vars: usize,
    next: usize,
}

impl SplitEqSuffixCache {
    pub(crate) fn new(point: &[Fp2], start: usize, n_vars: usize) -> Self {
        assert!(start <= n_vars && point.len() <= n_vars - start);
        // Skip coordinate zero only when it is the current round coordinate.
        let base = if start == 0 && n_vars != 0 { point.len().min(1) } else { 0 };
        let boundary = base + (point.len() - base) / 2;
        Self {
            left: SuffixLevels::new(&point[base..boundary]),
            right: SuffixLevels::new(&point[boundary..]),
            start, end: start + point.len(), point_len: point.len(),
            base, boundary, n_vars, next: 0,
        }
    }

    pub(crate) fn view(&self, j: usize) -> (&[Fp2], &[Fp2], usize, usize) {
        // The enclosing evaluator enforces pending-round and immutable group
        // descriptors. Its groups remain owned privately after construction.
        assert!(j == self.next && j < self.n_vars);
        let consumed = (j + 1).saturating_sub(self.start).min(self.point_len);
        let li = consumed.saturating_sub(self.base).min(self.boundary - self.base);
        let ri = consumed.saturating_sub(self.boundary);
        let suffix_len = self.point_len - consumed;
        let trailing = if suffix_len == 0 { 0 } else { self.n_vars - self.end };
        (self.left.get(li), self.right.get(ri), suffix_len, trailing)
    }

    pub(crate) fn after_fold(&mut self, j: usize) {
        assert!(j == self.next && j < self.n_vars);
        self.next += 1;
        let consumed = (self.next + 1).saturating_sub(self.start).min(self.point_len);
        let li = consumed.saturating_sub(self.base).min(self.boundary - self.base);
        let ri = consumed.saturating_sub(self.boundary);
        self.left.release_before(li);
        self.right.release_before(ri);
    }
}

// Owner wiring (not applied): construct one cache per EqualityGroup in
// GroupedEqRounds::new; RoundGroup<'a> borrows left/right slices from view(j)
// rather than owning eq_table_msb outputs. Use the existing pos quotient and
// remainder unchanged. After every part/reduction has dropped its borrows,
// call after_fold(j). Preserve all prefix, actual claims, inversions, explicit
// zero-factor fallback, tables/final order, degrees, samples and parallel
// thresholds. Instrument construction/read/free and enclosing clocks first.
