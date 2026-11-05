//! Goldilocks base field F_p, p = 2^64 - 2^32 + 1, and the quadratic
//! extension F_{p^2} = F_p[u] / (u^2 - 7) used for every challenge.
//!
//! Hand-rolled (rung 0 decision): crates.io is reachable and the
//! plonky3 crates exist (p3-goldilocks 0.7.0-rc.1 at the time of
//! writing), but the arithmetic below is ~100 lines, has no API
//! churn, and keeps the measurement self-contained. Canonical
//! representation everywhere (values always < p).

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
    /// `v mod p`, canonical. [A11] By the Goldilocks reduction `mul` already
    /// uses ([`reduce128`]), which is exact for EVERY 128-bit input (2^64 = 2^32 - 1
    /// and 2^96 = -1 mod p): the same word the generic 128-bit `v % p` gave, without
    /// the software division (`__umodti3`), which was a top leaf of the D55 fork
    /// run's pool workers through the randomness stream's draws.
    #[inline(always)]
    pub fn from_u128(v: u128) -> Fp {
        reduce128(v)
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

    /// [A11] `from_u128` (now the Goldilocks reduction) is the canonical residue
    /// the generic 128-bit division gave, on random words of every size and on
    /// the edges of each limb and of p's multiples
    #[test]
    fn from_u128_is_the_canonical_residue_of_the_division() {
        let reference = |v: u128| (v % (P as u128)) as u64;
        let mut s = 0x0a11_5eed_0a11_5eedu64;
        for i in 0..400_000u32 {
            let (hi, lo) = (rng(&mut s), rng(&mut s));
            // every width from 0 to 128 bits, uniformly cycled
            let v = (((hi as u128) << 64) | lo as u128) >> (i % 129).min(127);
            let v = if i % 129 == 128 { 0 } else { v };
            assert_eq!(Fp::from_u128(v).0, reference(v), "{v:#x}");
        }
        let p = P as u128;
        let mut edges: Vec<u128> = vec![0, 1, p - 1, p, p + 1, 2 * p - 1, 2 * p, u64::MAX as u128, 1u128 << 64, (1u128 << 64) + 1, (1u128 << 96) - 1, 1u128 << 96, (1u128 << 96) + 1, u128::MAX, u128::MAX - 1, u128::MAX / p * p, u128::MAX / p * p - 1];
        for k in [1u128, 2, 3, 0xFFFF_FFFF, 1 << 32, (1 << 63) + 7, u64::MAX as u128] {
            edges.extend([k * p, k * p - 1, k * p + 1]);
        }
        for hi in [0u64, 1, EPSILON, 1 << 32, P - 1, P, u64::MAX] {
            for lo in [0u64, 1, EPSILON, 1 << 32, P - 1, P, u64::MAX] {
                edges.push(((hi as u128) << 64) | lo as u128);
            }
        }
        for v in edges {
            assert_eq!(Fp::from_u128(v).0, reference(v), "{v:#x}");
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
