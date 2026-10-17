//! UNCOMPILED, UNAPPLIED serial mixed-table GroupedEqRounds adapter.
//! Include alongside driver.rs in ONE owner-selected module; Python is tested.
//! No native compilation or masked/receipt validation has occurred.
use crate::mle::eq_table_msb;

/// A term eq(point, x[start..]) * bracket(tables). The bracket must have
/// the declared degree after linear interpolation of every table. The caller
/// retains the original equality tables and their positions for final openings.
#[derive(Clone, Debug)]
pub struct EqualityGroup {
    pub point: Vec<Fp2>,
    pub start: usize,
    pub bracket_degree: usize,
}

/// Group claims are obtained only from actual preceding UNMASKED group rounds.
/// In particular, an asserted host sum is never used to seed recovery.
/// Every table (including equality tables) is folded in the original order.
pub struct GroupedEqRounds<'a, F> {
    tables: &'a mut Tables,
    groups: Vec<EqualityGroup>,
    bracket: F,
    degree: usize,
    n_vars: usize,
    next: usize,
    prefix: Vec<Fp2>,
    claims: Vec<Option<Fp2>>,
    pending: Option<Vec<Vec<Fp2>>>,
}

impl<'a, F: Fn(usize, &[Fp2]) -> Fp2 + Sync> GroupedEqRounds<'a, F> {
    pub fn new(tables: &'a mut Tables, degree: usize,
               groups: Vec<EqualityGroup>, bracket: F) -> Self {
        assert!(!tables.entries.is_empty() && !groups.is_empty() && degree >= 1);
        assert_eq!(tables.next, 0);
        let n_vars = tables.n;
        for g in &groups {
            assert!(g.start <= n_vars && g.point.len() <= n_vars - g.start);
            assert!(g.bracket_degree >= 1);
            assert!(g.bracket_degree <= degree - usize::from(!g.point.is_empty()));
        }
        let count = groups.len();
        Self { tables, groups, bracket, degree, n_vars, next: 0,
            prefix: vec![Fp2::ONE; count], claims: vec![None; count], pending: None }
    }
}

struct RoundGroup {
    factor: Vec<Fp2>,
    left: Vec<Fp2>,
    right: Vec<Fp2>,
    suffix_len: usize,
    trailing: usize,
    inverse_one: Option<Fp2>,
}

impl<F: Fn(usize, &[Fp2]) -> Fp2 + Sync> SumcheckRounds for GroupedEqRounds<'_, F> {
    fn n_vars(&self) -> usize { self.n_vars }
    fn degree(&self) -> usize { self.degree }

    fn round(&mut self, j: usize) -> Vec<Fp2> {
        assert_eq!(j, self.next);
        assert!(j < self.n_vars && self.pending.is_none());
        let round_groups: Vec<_> = self.groups.iter().enumerate().map(|(g, desc)| {
            let end = desc.start + desc.point.len();
            let active = j >= desc.start && j < end;
            let factor: Vec<_> = (0..=self.degree).map(|t| {
                if active {
                    let w = desc.point[j - desc.start];
                    self.prefix[g].mul(Fp2::ONE.sub(w).add(w.double().sub(Fp2::ONE).mul(Fp2::from_u64(t as u64))))
                } else { self.prefix[g] }
            }).collect();
            let consumed = (j + 1).saturating_sub(desc.start).min(desc.point.len());
            let suffix = &desc.point[consumed..];
            let split = suffix.len() / 2;
            // Explicit evaluation when the factor is zero; never refuse or
            // resample a challenge to make this arithmetic shortcut available.
            let inverse_one = self.claims[g].and_then(|_| {
                if factor[1].is_zero() { None } else { Some(factor[1].inv()) }
            });
            RoundGroup { factor, left: eq_table_msb(&suffix[..split]),
                right: eq_table_msb(&suffix[split..]), suffix_len: suffix.len(),
                trailing: if suffix.is_empty() { 0 } else { self.n_vars - end }, inverse_one }
        }).collect();
        let k = self.tables.entries.len();
        let half = 1usize << (self.n_vars - j - 1);
        let chunk = half.min(1024).max(1);
        let max_degree = self.groups.iter().map(|g| g.bracket_degree).max().unwrap();
        let zero = || self.groups.iter().map(|g| vec![Fp2::ZERO; g.bracket_degree + 1]).collect::<Vec<_>>();
        let part = |ci: usize| {
            let mut sums = zero();
            let mut cur = vec![Fp2::ZERO; k];
            let mut dif = vec![Fp2::ZERO; k];
            let mut high = vec![Fp2::ZERO; k];
            let mut weights = vec![Fp2::ZERO; self.groups.len()];
            for i in ci * chunk..((ci + 1) * chunk).min(half) {
                self.tables.row(i, &mut cur).expect("admitted low row");
                self.tables.row(i + half, &mut high).expect("admitted high row");
                for t in 0..k { dif[t] = high[t].sub(cur[t]); }
                for (g, rg) in round_groups.iter().enumerate() {
                    let pos = (i >> rg.trailing) & ((1usize << rg.suffix_len) - 1);
                    weights[g] = rg.left[pos / rg.right.len()].mul(rg.right[pos % rg.right.len()]);
                }
                for t in 0..=max_degree {
                    for g in 0..self.groups.len() {
                        if t <= self.groups[g].bracket_degree &&
                            (t != 1 || round_groups[g].inverse_one.is_none() || cfg!(debug_assertions)) {
                            sums[g][t] = sums[g][t].add(weights[g].mul((self.bracket)(g, &cur)));
                        }
                    }
                    if t != max_degree {
                        for (v, d) in cur.iter_mut().zip(&dif) { *v = v.add(*d); }
                    }
                }
            }
            sums
        };
        let mut hs = zero();
        for ci in 0..half.div_ceil(chunk) {
            for (a, b) in hs.iter_mut().zip(part(ci)) {
                for (v, w) in a.iter_mut().zip(b) { *v = v.add(w); }
            }
        }
        let mut result = vec![Fp2::ZERO; self.degree + 1];
        let mut pending = Vec::with_capacity(self.groups.len());
        for (g, rg) in round_groups.iter().enumerate() {
            if let Some(inv) = rg.inverse_one {
                let recovered = self.claims[g].unwrap().sub(rg.factor[0].mul(hs[g][0])).mul(inv);
                debug_assert_eq!(recovered, hs[g][1], "group running-claim identity");
                hs[g][1] = recovered;
            }
            let values: Vec<_> = (0..=self.degree).map(|t| {
                let h = if t < hs[g].len() { hs[g][t] }
                    else { interpolate_eval(&hs[g], Fp2::from_u64(t as u64)) };
                rg.factor[t].mul(h)
            }).collect();
            for (v, w) in result.iter_mut().zip(&values) { *v = v.add(*w); }
            pending.push(values);
        }
        self.pending = Some(pending);
        result
    }

    fn fold(&mut self, r: Fp2) {
        let pending = self.pending.take().expect("fold needs a round");
        for (g, desc) in self.groups.iter().enumerate() {
            self.claims[g] = Some(interpolate_eval(&pending[g], r));
            if self.next >= desc.start && self.next < desc.start + desc.point.len() {
                let w = desc.point[self.next - desc.start];
                self.prefix[g] = self.prefix[g].mul(Fp2::ONE.sub(w).mul(Fp2::ONE.sub(r)).add(w.mul(r)));
            }
        }
        // One bind per table after all immutable round reads/reductions.
        self.tables.bind(r);
        self.next += 1;
    }

    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n_vars);
        assert!(self.pending.is_none());
        self.tables.finals()
    }
}

