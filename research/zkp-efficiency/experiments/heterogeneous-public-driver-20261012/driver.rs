//! UNCOMPILED, UNAPPLIED serial integration sketch, Python is tested evidence.
//! Intended additive SumcheckRounds seam; the owner supplies module placement.
//! No transcript/RNG/mask/PCS access. Parallel thresholds remain owner work.
use crate::field::Fp2;
use crate::mle::interpolate_eval;
use crate::sumcheck::SumcheckRounds;
use super::{support::Support, causal_mask::CausalMask};

pub enum Table {
    Dense(Vec<Fp2>),
    Support(Support),
    Causal(CausalMask),
}

pub struct Tables {
    n: usize,
    next: usize,
    // ORIGINAL table order, including dense equality tables and private tables.
    entries: Vec<Table>,
}
impl Tables {
    pub fn new(n: usize, entries: Vec<Table>) -> Result<Self, &'static str> {
        if n >= usize::BITS as usize || entries.is_empty() { return Err("table cube"); }
        let len = 1usize << n;
        for entry in &entries {
            let ok = match entry {
                Table::Dense(v) => v.len() == len,
                Table::Support(s) => s.n_vars() == n && s.bound() == 0,
                Table::Causal(s) => s.n_vars() == n && s.bound() == 0,
            };
            if !ok { return Err("table cube or initial state"); }
        }
        Ok(Self { n, next: 0, entries })
    }
    fn row(&self, index: usize, out: &mut [Fp2]) -> Result<(), &'static str> {
        if out.len() != self.entries.len() || index >= 1usize << (self.n-self.next) {
            return Err("table row");
        }
        for (value, entry) in out.iter_mut().zip(&self.entries) {
            *value = match entry {
                Table::Dense(v) => v[index],
                Table::Support(s) => s.at(index)?,
                Table::Causal(s) => s.at(index)?,
            };
        }
        Ok(())
    }
    pub fn total<F: Fn(&[Fp2]) -> Fp2>(&self, poly: &F) -> Result<Fp2, &'static str> {
        if self.next != 0 { return Err("total requires original cube"); }
        let mut row = vec![Fp2::ZERO; self.entries.len()];
        let mut out = Fp2::ZERO;
        for index in 0..1usize << self.n {
            self.row(index, &mut row)?;
            out = out.add(poly(&row));
        }
        Ok(out)
    }
    fn bind(&mut self, r: Fp2) {
        assert!(self.next < self.n);
        let half = 1usize << (self.n-self.next-1);
        for entry in &mut self.entries {
            match entry {
                Table::Dense(v) => {
                    for i in 0..half { v[i] = v[i].add(r.mul(v[i+half].sub(v[i]))); }
                    v.truncate(half);
                }
                Table::Support(s) => s.bind(r).expect("validated support bind"),
                Table::Causal(s) => s.bind(r).expect("validated causal bind"),
            }
        }
        self.next += 1;
    }
    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n);
        self.entries.iter().map(|entry| match entry {
            Table::Dense(v) => v[0],
            Table::Support(s) => s.terminal().expect("validated support final"),
            Table::Causal(s) => s.terminal().expect("validated causal final"),
        }).collect()
    }
}

pub struct Rounds<'a, F> {
    tables: &'a mut Tables,
    poly: F,
    degree: usize,
    pending: Option<Vec<Fp2>>,
    recover: bool,
    claim: Option<Fp2>,
}
impl<'a, F: Fn(&[Fp2]) -> Fp2> Rounds<'a, F> {
    pub fn new(tables: &'a mut Tables, degree: usize, poly: F) -> Self {
        Self { tables, poly, degree, pending: None, recover: false, claim: None }
    }
    // HOST slots pass None. Some requires exact generic unmasked cube total.
    pub fn recover_one(mut self, claim: Option<Fp2>) -> Self {
        assert!(self.degree >= 1);
        self.recover = true;
        self.claim = claim;
        self
    }
}
impl<F: Fn(&[Fp2]) -> Fp2> SumcheckRounds for Rounds<'_, F> {
    fn n_vars(&self) -> usize { self.tables.n }
    fn degree(&self) -> usize { self.degree }
    fn round(&mut self, j: usize) -> Vec<Fp2> {
        assert_eq!(j, self.tables.next);
        assert!(j < self.tables.n && self.pending.is_none());
        let half = 1usize << (self.tables.n-j-1);
        let k = self.tables.entries.len();
        let mut cur = vec![Fp2::ZERO; k];
        let mut high = vec![Fp2::ZERO; k];
        let mut diff = vec![Fp2::ZERO; k];
        let mut sums = vec![Fp2::ZERO; self.degree+1];
        let claim = if self.recover { self.claim } else { None };
        for i in 0..half {
            self.tables.row(i, &mut cur).expect("validated low row");
            self.tables.row(i+half, &mut high).expect("validated high row");
            for t in 0..k { diff[t] = high[t].sub(cur[t]); }
            for x in 0..=self.degree {
                if x != 1 || claim.is_none() || cfg!(debug_assertions) {
                    sums[x] = sums[x].add((self.poly)(&cur));
                }
                if x != self.degree {
                    for t in 0..k { cur[t] = cur[t].add(diff[t]); }
                }
            }
        }
        if let Some(claim) = claim {
            debug_assert_eq!(sums[0].add(sums[1]), claim);
            sums[1] = claim.sub(sums[0]);
        }
        self.pending = Some(sums.clone());
        sums
    }
    fn fold(&mut self, r: Fp2) {
        let values = self.pending.take().expect("fold needs round");
        if self.recover { self.claim = Some(interpolate_eval(&values, r)); }
        self.tables.bind(r);
    }
    fn finals(&self) -> Vec<Fp2> {
        assert!(self.pending.is_none());
        self.tables.finals()
    }
}
