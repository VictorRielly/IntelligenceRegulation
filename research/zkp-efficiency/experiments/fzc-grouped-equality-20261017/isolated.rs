#![allow(dead_code,unused_variables,unused_doc_comments)]
mod field {
// Goldilocks base field F_p, p = 2^64 - 2^32 + 1, and the quadratic
// extension F_{p^2} = F_p[u] / (u^2 - 7) used for every challenge.
//
// Hand-rolled (rung 0 decision): crates.io is reachable and the
// plonky3 crates exist (p3-goldilocks 0.7.0-rc.1 at the time of
// writing), but the arithmetic below is ~100 lines, has no API
// churn, and keeps the measurement self-contained. Canonical
// representation everywhere (values always < p).

pub const P: u64 = 0xFFFF_FFFF_0000_0001;
const EPSILON: u64 = 0xFFFF_FFFF; // 2^64 mod p = 2^32 - 1
/// Multiplicative generator of F_p^*.
pub const GENERATOR: u64 = 7;
/// Non-residue defining the extension: u^2 = 7.
pub const NONRESIDUE: u64 = 7;
pub const TWO_ADICITY: u32 = 32;

#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Hash)]
#[repr(transparent)]
pub struct Fp(pub u64);

impl Fp {
    pub const ZERO: Fp = Fp(0);
    pub const ONE: Fp = Fp(1);

    #[inline(always)]
    pub fn new(v: u64) -> Fp {
        if v >= P { Fp(v - P) } else { Fp(v) }
    }
    /// From a signed integer (two's complement reduction).
    #[inline(always)]
    pub fn from_i64(v: i64) -> Fp {
        if v >= 0 { Fp::new(v as u64) } else { Fp::new(P - ((-(v as i128)) as u64 % P)) }
    }
    #[inline(always)]
    pub fn from_u128(v: u128) -> Fp {
        Fp((v % (P as u128)) as u64)
    }
    #[inline(always)]
    pub fn add(self, rhs: Fp) -> Fp {
        let (r, c) = self.0.overflowing_add(rhs.0);
        let r = if c { r.wrapping_add(EPSILON) } else { r };
        Fp::new(r)
    }
    #[inline(always)]
    pub fn sub(self, rhs: Fp) -> Fp {
        let (r, b) = self.0.overflowing_sub(rhs.0);
        Fp(if b { r.wrapping_sub(EPSILON) } else { r })
    }
    #[inline(always)]
    pub fn neg(self) -> Fp {
        if self.0 == 0 { self } else { Fp(P - self.0) }
    }
    #[inline(always)]
    pub fn mul(self, rhs: Fp) -> Fp {
        reduce128((self.0 as u128) * (rhs.0 as u128))
    }
    #[inline(always)]
    pub fn square(self) -> Fp {
        self.mul(self)
    }
    #[inline(always)]
    pub fn double(self) -> Fp {
        self.add(self)
    }
    pub fn pow(self, mut e: u64) -> Fp {
        let mut base = self;
        let mut acc = Fp::ONE;
        while e > 0 {
            if e & 1 == 1 { acc = acc.mul(base); }
            base = base.square();
            e >>= 1;
        }
        acc
    }
    pub fn inv(self) -> Fp {
        assert!(self.0 != 0, "inverse of zero");
        self.pow(P - 2)
    }
    /// 2^k-th primitive root of unity.
    pub fn two_adic_root(k: u32) -> Fp {
        assert!(k <= TWO_ADICITY);
        // g^((p-1)/2^32) has exact order 2^32.
        let r32 = Fp(GENERATOR).pow((P - 1) >> TWO_ADICITY);
        r32.pow(1u64 << (TWO_ADICITY - k))
    }
    #[inline(always)]
    pub fn to_bytes(self) -> [u8; 8] {
        self.0.to_le_bytes()
    }
    #[inline(always)]
    pub fn is_zero(self) -> bool {
        self.0 == 0
    }
}

#[inline(always)]
fn reduce128(x: u128) -> Fp {
    let x_lo = x as u64;
    let x_hi = (x >> 64) as u64;
    let x_hi_hi = x_hi >> 32;
    let x_hi_lo = x_hi & EPSILON;
    let (mut t0, borrow) = x_lo.overflowing_sub(x_hi_hi);
    if borrow {
        t0 = t0.wrapping_sub(EPSILON);
    }
    let t1 = x_hi_lo * EPSILON;
    let (res, carry) = t0.overflowing_add(t1);
    let res = if carry { res.wrapping_add(EPSILON) } else { res };
    Fp::new(res)
}

/// Batch inversion (Montgomery's trick); zeros are NOT allowed.
pub fn batch_inverse(vals: &mut [Fp]) {
    let n = vals.len();
    if n == 0 { return; }
    let mut prefix = Vec::with_capacity(n);
    let mut acc = Fp::ONE;
    for v in vals.iter() {
        prefix.push(acc);
        acc = acc.mul(*v);
    }
    let mut inv = acc.inv();
    for i in (0..n).rev() {
        let v = vals[i];
        vals[i] = inv.mul(prefix[i]);
        inv = inv.mul(v);
    }
}

/// F_{p^2} = F_p[u] / (u^2 - 7).
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default, Hash)]
pub struct Fp2 {
    pub c0: Fp,
    pub c1: Fp,
}

impl Fp2 {
    pub const ZERO: Fp2 = Fp2 { c0: Fp::ZERO, c1: Fp::ZERO };
    pub const ONE: Fp2 = Fp2 { c0: Fp::ONE, c1: Fp::ZERO };
    pub const U: Fp2 = Fp2 { c0: Fp::ZERO, c1: Fp::ONE };

    #[inline(always)]
    pub fn new(c0: Fp, c1: Fp) -> Fp2 { Fp2 { c0, c1 } }
    #[inline(always)]
    pub fn from_base(a: Fp) -> Fp2 { Fp2 { c0: a, c1: Fp::ZERO } }
    #[inline(always)]
    pub fn from_i64(v: i64) -> Fp2 { Fp2::from_base(Fp::from_i64(v)) }
    #[inline(always)]
    pub fn from_u64(v: u64) -> Fp2 { Fp2::from_base(Fp::new(v)) }
    #[inline(always)]
    pub fn add(self, r: Fp2) -> Fp2 { Fp2 { c0: self.c0.add(r.c0), c1: self.c1.add(r.c1) } }
    #[inline(always)]
    pub fn sub(self, r: Fp2) -> Fp2 { Fp2 { c0: self.c0.sub(r.c0), c1: self.c1.sub(r.c1) } }
    #[inline(always)]
    pub fn neg(self) -> Fp2 { Fp2 { c0: self.c0.neg(), c1: self.c1.neg() } }
    #[inline(always)]
    pub fn mul(self, r: Fp2) -> Fp2 {
        let ac = self.c0.mul(r.c0);
        let bd = self.c1.mul(r.c1);
        let ad = self.c0.mul(r.c1);
        let bc = self.c1.mul(r.c0);
        Fp2 { c0: ac.add(bd.mul(Fp(NONRESIDUE))), c1: ad.add(bc) }
    }
    #[inline(always)]
    pub fn mul_base(self, r: Fp) -> Fp2 { Fp2 { c0: self.c0.mul(r), c1: self.c1.mul(r) } }
    #[inline(always)]
    pub fn add_base(self, r: Fp) -> Fp2 { Fp2 { c0: self.c0.add(r), c1: self.c1 } }
    #[inline(always)]
    pub fn sub_base(self, r: Fp) -> Fp2 { Fp2 { c0: self.c0.sub(r), c1: self.c1 } }
    #[inline(always)]
    pub fn square(self) -> Fp2 { self.mul(self) }
    #[inline(always)]
    pub fn double(self) -> Fp2 { self.add(self) }
    pub fn inv(self) -> Fp2 {
        // (a - b u) / (a^2 - 7 b^2)
        let norm = self.c0.square().sub(self.c1.square().mul(Fp(NONRESIDUE)));
        let ninv = norm.inv();
        Fp2 { c0: self.c0.mul(ninv), c1: self.c1.neg().mul(ninv) }
    }
    pub fn pow(self, mut e: u128) -> Fp2 {
        let mut base = self;
        let mut acc = Fp2::ONE;
        while e > 0 {
            if e & 1 == 1 { acc = acc.mul(base); }
            base = base.square();
            e >>= 1;
        }
        acc
    }
    #[inline(always)]
    pub fn is_zero(self) -> bool { self.c0.is_zero() && self.c1.is_zero() }
    pub fn to_bytes(self) -> [u8; 16] {
        let mut b = [0u8; 16];
        b[..8].copy_from_slice(&self.c0.to_bytes());
        b[8..].copy_from_slice(&self.c1.to_bytes());
        b
    }
    pub fn from_bytes(b: &[u8]) -> Fp2 {
        let c0 = u64::from_le_bytes(b[..8].try_into().unwrap());
        let c1 = u64::from_le_bytes(b[8..16].try_into().unwrap());
        Fp2 { c0: Fp::new(c0), c1: Fp::new(c1) }
    }
}

/// Batch inversion in the extension.
pub fn batch_inverse2(vals: &mut [Fp2]) {
    let n = vals.len();
    if n == 0 { return; }
    let mut prefix = Vec::with_capacity(n);
    let mut acc = Fp2::ONE;
    for v in vals.iter() {
        prefix.push(acc);
        acc = acc.mul(*v);
    }
    let mut inv = acc.inv();
    for i in (0..n).rev() {
        let v = vals[i];
        vals[i] = inv.mul(prefix[i]);
        inv = inv.mul(v);
    }
}

/// Checked batch inversion of canonical extension-field elements.
/// Rejects any zero before allocating, mutating the slice, or inverting;
/// otherwise uses exactly the existing batch inversion arithmetic. Empty is OK.
/// Like the rest of this field API, callers must supply canonical Fp limbs.
pub fn batch_inverse2_checked(vals: &mut [Fp2]) -> Result<(), &'static str> {
    if vals.iter().any(|v| v.is_zero()) {
        return Err("zero extension-field batch denominator");
    }
    batch_inverse2(vals);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rng(seed: &mut u64) -> u64 {
        // xorshift64*
        let mut x = *seed;
        x ^= x >> 12; x ^= x << 25; x ^= x >> 27;
        *seed = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }

    fn mulmod_ref(a: u64, b: u64) -> u64 {
        ((a as u128 * b as u128) % (P as u128)) as u64
    }

    #[test]
    fn mul_matches_u128_reference() {
        let mut s = 0x1234_5678_9abc_def1u64;
        for _ in 0..200_000 {
            let a = rng(&mut s) % P;
            let b = rng(&mut s) % P;
            assert_eq!(Fp(a).mul(Fp(b)).0, mulmod_ref(a, b));
        }
        // edge values
        for &a in &[0u64, 1, P - 1, P - 2, EPSILON, EPSILON + 1, 1u64 << 32, (1u64 << 63)] {
            for &b in &[0u64, 1, P - 1, P - 2, EPSILON, EPSILON + 1, 1u64 << 32, (1u64 << 63)] {
                assert_eq!(Fp(a).mul(Fp(b)).0, mulmod_ref(a, b), "{a} * {b}");
            }
        }
    }

    #[test]
    fn add_sub_match_reference() {
        let mut s = 42u64;
        for _ in 0..200_000 {
            let a = rng(&mut s) % P;
            let b = rng(&mut s) % P;
            assert_eq!(Fp(a).add(Fp(b)).0, ((a as u128 + b as u128) % P as u128) as u64);
            assert_eq!(Fp(a).sub(Fp(b)).0, ((a as u128 + P as u128 - b as u128) % P as u128) as u64);
        }
        assert_eq!(Fp(P - 1).add(Fp(P - 1)).0, P - 2);
        assert_eq!(Fp(0).sub(Fp(1)).0, P - 1);
        assert_eq!(Fp::from_i64(-1).0, P - 1);
        assert_eq!(Fp::from_i64(-(1i64 << 40)).add(Fp::new(1u64 << 40)).0, 0);
    }

    #[test]
    fn inverse_and_batch() {
        let mut s = 7u64;
        let mut v: Vec<Fp> = (0..1000).map(|_| Fp(rng(&mut s) % (P - 1) + 1)).collect();
        let w = v.clone();
        batch_inverse(&mut v);
        for (a, b) in v.iter().zip(w.iter()) {
            assert_eq!(a.mul(*b), Fp::ONE);
            assert_eq!(*a, b.inv());
        }
    }

    #[test]
    fn two_adic_roots() {
        let r = Fp::two_adic_root(32);
        assert_eq!(r.pow(1u64 << 32), Fp::ONE);
        assert_ne!(r.pow(1u64 << 31), Fp::ONE);
        let r8 = Fp::two_adic_root(3);
        assert_eq!(r8.pow(8), Fp::ONE);
        assert_ne!(r8.pow(4), Fp::ONE);
        assert_eq!(Fp::two_adic_root(1), Fp(P - 1));
        // plonky2's POWER_OF_TWO_GENERATOR (order 2^32) is 7^((p-1)/2^32).
        assert_eq!(r, Fp(1753635133440165772));
    }

    #[test]
    fn ext_arith() {
        let mut s = 99u64;
        for _ in 0..10_000 {
            let a = Fp2::new(Fp(rng(&mut s) % P), Fp(rng(&mut s) % P));
            let b = Fp2::new(Fp(rng(&mut s) % P), Fp(rng(&mut s) % P));
            let c = Fp2::new(Fp(rng(&mut s) % P), Fp(rng(&mut s) % P));
            assert_eq!(a.mul(b), b.mul(a));
            assert_eq!(a.mul(b).mul(c), a.mul(b.mul(c)));
            assert_eq!(a.mul(b.add(c)), a.mul(b).add(a.mul(c)));
            if !a.is_zero() {
                assert_eq!(a.mul(a.inv()), Fp2::ONE);
            }
        }
        // u^2 = 7
        assert_eq!(Fp2::U.square(), Fp2::from_u64(7));
        // 7 must be a non-residue: 7^((p-1)/2) == -1
        assert_eq!(Fp(7).pow((P - 1) / 2), Fp(P - 1));
        let mut v: Vec<Fp2> = (0..500).map(|_| Fp2::new(Fp(rng(&mut s) % P), Fp(rng(&mut s) % P + 1))).collect();
        let w = v.clone();
        batch_inverse2(&mut v);
        for (a, b) in v.iter().zip(w.iter()) {
            assert_eq!(a.mul(*b), Fp2::ONE);
        }
    }
}

}
use field::{Fp,Fp2};
mod mle { use crate::field::{Fp,Fp2};
pub fn eq_table(r: &[Fp2]) -> Vec<Fp2> {
    let n = r.len();
    let mut out = vec![Fp2::ONE; 1 << n];
    let mut len = 1usize;
    for &ri in r.iter() {
        // split each existing entry e into (e*(1-ri), e*ri) for the next bit (more significant first)
        let (lo, hi) = out.split_at_mut(len);
        let hi = &mut hi[..len];
        let one_minus = Fp2::ONE.sub(ri);
        // [UPERF3-XX] small steps run sequentially: a rayon region per
        // doubling step cost ~0.3 ms of pool wake-up each and dominated
        // pcs::group_claims (37 claims x 2 tables x up to 14 steps per
        // layer); same values.
        if len < 4096 {
            for (a, b) in lo.iter_mut().zip(hi.iter_mut()) {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            }
        } else {
            lo.iter_mut().zip(hi.iter_mut()).for_each(|(a, b)| {
                let e = *a;
                *b = e.mul(ri);
                *a = e.mul(one_minus);
            });
        }
        len <<= 1;
    }
    // out[idx] where idx bit (n-1-i) = variable i -> but the loop above makes
    // the FIRST r the least significant split. Fix by building in the
    // opposite order: iterate r in reverse so r[0] ends up most significant.
    out
}
pub fn eq_table_msb(r: &[Fp2]) -> Vec<Fp2> {
    let rev: Vec<Fp2> = r.iter().rev().copied().collect();
    eq_table(&rev)
}
pub fn interpolate_eval(vals: &[Fp2], x: Fp2) -> Fp2 {
    let d = vals.len();
    let mut acc = Fp2::ZERO;
    for i in 0..d {
        let mut num = Fp2::ONE;
        let mut den = Fp::ONE;
        for j in 0..d {
            if i == j { continue; }
            num = num.mul(x.sub_base(Fp::new(j as u64)));
            den = den.mul(Fp::from_i64(i as i64 - j as i64));
        }
        acc = acc.add(vals[i].mul(num).mul_base(den.inv()));
    }
    acc
}
}
mod sumcheck { use crate::{field::Fp2,mle::interpolate_eval};
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
            (0..n_chunks).into_iter().map(round_of).fold(
                vec![Fp2::ZERO; degree + 1],
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
                lo.iter_mut().zip(hi[..half].iter()).for_each(|(a, b)| { *a = a.add(r.mul(b.sub(*a))); });
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

pub mod grouped { use super::SumcheckRounds;use crate::{field::Fp2,mle::{eq_table_msb,interpolate_eval}};
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
    tables: &'a mut Vec<Vec<Fp2>>,
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
    pub fn new(tables: &'a mut Vec<Vec<Fp2>>, degree: usize,
               groups: Vec<EqualityGroup>, bracket: F) -> Self {
        assert!(!tables.is_empty() && !groups.is_empty() && degree >= 1);
        let len = tables[0].len();
        assert!(len.is_power_of_two() && tables.iter().all(|t| t.len() == len));
        let n_vars = len.trailing_zeros() as usize;
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
                if factor[1].is_zero() { crate::metric(5); } else { crate::metric(4); }
                if factor[1].is_zero() { None } else { Some(factor[1].inv()) }
            });
            RoundGroup { factor, left: eq_table_msb(&suffix[..split]),
                right: eq_table_msb(&suffix[split..]), suffix_len: suffix.len(),
                trailing: if suffix.is_empty() { 0 } else { self.n_vars - end }, inverse_one }
        }).collect();
        let k = self.tables.len();
        let half = self.tables[0].len() / 2;
        let small = half * k <= 1 << 16;
        let chunk = if small { half.max(1) } else { half.min(1024) };
        let max_degree = self.groups.iter().map(|g| g.bracket_degree).max().unwrap();
        let zero = || self.groups.iter().map(|g| vec![Fp2::ZERO; g.bracket_degree + 1]).collect::<Vec<_>>();
        let part = |ci: usize| {
            let mut sums = zero();
            let mut cur = vec![Fp2::ZERO; k];
            let mut dif = vec![Fp2::ZERO; k];
            let mut weights = vec![Fp2::ZERO; self.groups.len()];
            for i in ci * chunk..((ci + 1) * chunk).min(half) {
                for (t, tb) in self.tables.iter().enumerate() {
                    cur[t] = tb[i];
                    dif[t] = tb[i + half].sub(tb[i]);
                }
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
        let mut hs = if small { part(0) } else {
            (0..half.div_ceil(chunk)).into_iter().map(part).fold(zero(), |mut a, b| {
                for (x, y) in a.iter_mut().zip(b) {
                    for (v, w) in x.iter_mut().zip(y) { *v = v.add(w); }
                }
                a
            })
        };
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
        let half = self.tables[0].len() / 2;
        let small = half * self.tables.len() <= 1 << 16;
        for tb in self.tables.iter_mut() {
            let (lo, hi) = tb.split_at_mut(half);
            if small {
                for (a, b) in lo.iter_mut().zip(&hi[..half]) { *a = a.add(r.mul(b.sub(*a))); }
            } else {
                lo.iter_mut().zip(hi[..half].iter()).for_each(|(a, b)| { *a = a.add(r.mul(b.sub(*a))); });
            }
            tb.truncate(half);
        }
        self.next += 1;
    }

    fn finals(&self) -> Vec<Fp2> {
        assert_eq!(self.next, self.n_vars);
        assert!(self.pending.is_none());
        self.tables.iter().map(|t| t[0]).collect()
    }
}

impl<F: Fn(usize, &[Fp2])->Fp2 + Sync> GroupedEqRounds<'_, F> { pub fn seed_bad(&mut self) { self.claims.fill(Some(Fp2::ONE)); } }

}
}
const A_G8: usize = 67;
const A_RGL: usize = 68;
const A_A16: usize = 69;
const A_U16: usize = 70;
const A_UL0: usize = 71;
const A_UL1: usize = 72;
const A_H16: usize = 73;
const A_HL0: usize = 74;
const A_HL1: usize = 75;
const A_RH0: usize = 76;
const A_RH1: usize = 77;
struct LkT {terms:Vec<(usize,Fp)>,cst:Fp2}
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
#[derive(Clone,Copy)]
struct Gate(Option<usize>);
impl Gate {
    fn at(self, v: &[Fp2]) -> Fp2 {
        match self.0 {
            Some(i) => v[i],
            None => Fp2::ONE,
        }
    }
}
fn k(x:i64)->Fp2 {Fp2::from_i64(x)}
fn full(v:&[Fp2],hh:u32,gg:u32,pad:bool,nlk:usize)->Box<dyn Fn(&[Fp2])->Fp2+Sync> {
let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let (k_h,k_g)=(k(1i64<<hh),k(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {0} else {1i64<<(hh-1)}),k(if gg==0 {0} else {1i64<<(gg-1)}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}).collect();
 let gf=Gate(if pad {Some(20)} else {None}); let mut pz=PadTerm::none();
 if pad { pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }
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
            }; Box::new(poly)
}
fn brackets(v:&[Fp2],hh:u32,gg:u32,pad:bool,nlk:usize)->Box<dyn Fn(usize,&[Fp2])->Fp2+Sync> {
let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let (k_h,k_g)=(k(1i64<<hh),k(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {0} else {1i64<<(hh-1)}),k(if gg==0 {0} else {1i64<<(gg-1)}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}).collect();
 let gf=Gate(if pad {Some(20)} else {None}); let mut pz=PadTerm::none();
 if pad { pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }
let bracket = move |group: usize, v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let g = gf.at(v);
                if group == 1 { return nu[0].mul(g).mul(k_g.mul(at(A_G8)).add(at(A_RGL)).sub(k_g_half)); }
                if group == 2 { return nu[1].mul(g).mul(at(A_U16)); }
                assert_eq!(group, 0);
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
                zc
            }; Box::new(bracket)
}
// Local synthetic C ABI. No transcript, mask, proof or private data.
use sumcheck::{ClosureRounds, SumcheckRounds, grouped::{EqualityGroup,GroupedEqRounds}};
use std::cell::Cell;
thread_local! {static TRACK:Cell<bool>=const{Cell::new(false)};static COUNTS:Cell<[u64;6]>=const{Cell::new([0;6])};}
fn metric(i:usize) {TRACK.with(|t|if t.get(){COUNTS.with(|c|{let mut a=c.get();a[i]+=1;c.set(a);})});}
unsafe fn read(p:*const u64,n:usize)->Vec<Fp2> {std::slice::from_raw_parts(p,2*n).chunks_exact(2).map(|w|Fp2::new(Fp(w[0]),Fp(w[1]))).collect()}
unsafe fn write(out:*mut u64,v:&[Fp2]) {for (i,z) in v.iter().enumerate(){*out.add(2*i)=z.c0.0;*out.add(2*i+1)=z.c1.0;}}

#[no_mangle]
pub unsafe extern "C" fn drive(out:*mut u64,counts:*mut u64,ns:*mut u64,tabs:*const u64,conf:*const u64,points:*const u64,challenges:*const u64,n:usize,hh:u32,gg:u32,pad:u32,nlk:usize,mode:u32,track:u32) {
 let p=read(points,3*n);let rho=read(challenges,n);let v=read(conf,38);
 let flat=read(tabs,21*(1<<n));let mut tables:Vec<Vec<Fp2>>=flat.chunks_exact(1<<n).map(|x|x.to_vec()).collect();
 let f=full(&v,hh,gg,pad!=0,nlk);let b=brackets(&v,hh,gg,pad!=0,nlk);
 TRACK.with(|c|c.set(track!=0));COUNTS.with(|c|c.set([0;6]));
 let t=std::time::Instant::now();let mut result=Vec::new();
 if mode<2 {
  let poly=|r:&[Fp2]|{metric(3);f(r)};
  let mut ev=ClosureRounds::new(&mut tables,4,poly);if mode==1 {ev=ev.recover_one(None);}
  for j in 0..n {result.extend(ev.round(j));ev.fold(rho[j]);}result.extend(ev.finals());
 } else {
  let groups=(0..3).map(|g|EqualityGroup{point:p[g*n..(g+1)*n].to_vec(),start:0,
   bracket_degree:if g==0 {if mode==3 {2}else{3}}else if pad!=0 && mode!=4 {2}else{1}}).collect();
  let bracket=|g:usize,r:&[Fp2]|{metric(g);b(g,r)};
  let mut ev=GroupedEqRounds::new(&mut tables,4,groups,bracket);if mode==5 {ev.seed_bad();}
  for j in 0..n {result.extend(ev.round(j));ev.fold(rho[j]);}result.extend(ev.finals());
 }
 *ns=t.elapsed().as_nanos() as u64;write(out,&result);COUNTS.with(|c|for (i,z) in c.get().iter().enumerate(){*counts.add(i)=*z});TRACK.with(|c|c.set(false));
}

#[no_mangle]
pub unsafe extern "C" fn evals(out:*mut u64,row:*const u64,conf:*const u64,hh:u32,gg:u32,pad:u32,nlk:usize) {
 let r=read(row,21);let v=read(conf,38);let f=full(&v,hh,gg,pad!=0,nlk);let b=brackets(&v,hh,gg,pad!=0,nlk);
 write(out,&[f(&r),b(0,&r),b(1,&r),b(2,&r)]);
}
