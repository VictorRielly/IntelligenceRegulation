#![allow(dead_code,unused_variables)]
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
struct LkT { terms: Vec<(usize,Fp)>, cst: Fp2 }
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
fn k(x:i64)->Fp2 { Fp2::from_i64(x) }
#[inline(never)]
fn factory_0(v: &[Fp2], hh:u32, gg:u32, pad:bool, nlk:usize) -> Box<dyn Fn(&[Fp2])->Fp2> {
 let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let b1=Fp::from_i64(256);
 let (k_h,k_g,b_h,b_g)=(k(1i64<<hh),k(1i64<<gg),Fp::from_i64(1i64<<hh),Fp::from_i64(1i64<<gg));
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
#[inline(never)]
fn factory_1(v: &[Fp2], hh:u32, gg:u32, pad:bool, nlk:usize) -> Box<dyn Fn(&[Fp2])->Fp2> {
 let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let b1=Fp::from_i64(256);
 let (k_h,k_g,b_h,b_g)=(k(1i64<<hh),k(1i64<<gg),Fp::from_i64(1i64<<hh),Fp::from_i64(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {0} else {1i64<<(hh-1)}),k(if gg==0 {0} else {1i64<<(gg-1)}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}).collect();
 let gf=Gate(if pad {Some(20)} else {None}); let mut pz=PadTerm::none();
 if pad { pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }
 let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l2 = |o: usize| at(o).add(at(o + 1).mul_base(b1));
                let (g8, a16, u16, h16) = (at(A_G8), at(A_A16), at(A_U16), at(A_H16));
                let f0 = a16.mul(u16).sub(h16.mul_base(b_h)).sub(l2(A_RH0)).add(k_h_half);
                let f1 = u16.add(k(32768)).sub(l2(A_UL0));
                let f2 = h16.add(k(32768)).sub(l2(A_HL0));
                let f_act = v[i_fact].mul(alpha.sub(g8.add(k(128)).add(beta.mul(a16)).add(g_act))).sub(Fp2::ONE);
                let g = gf.at(v);
                let mut zc = helper_sum(v, &lks, h0, alpha, &mu[4..]).add(mu[3].mul(f_act)).add(pz.eval(v));
                for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    zc = zc.add(m.mul(g).mul(c));
                }
                let host_g = g8.mul_base(b_g).add(at(A_RGL)).sub(k_g_half);
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                let host_u = u16;
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_g)).add(nu[1].mul(v[2]).mul(g).mul(host_u))
            }; Box::new(poly)
}
#[inline(never)]
fn factory_2(v: &[Fp2], hh:u32, gg:u32, pad:bool, nlk:usize) -> Box<dyn Fn(&[Fp2])->Fp2> {
 let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let b1=Fp::from_i64(256);
 let (k_h,k_g,b_h,b_g)=(k(1i64<<hh),k(1i64<<gg),Fp::from_i64(1i64<<hh),Fp::from_i64(1i64<<gg));
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
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    clauses = clauses.add(m.mul(c));
                }
                zc = zc.add(g.mul(clauses));
                let host_g = k_g.mul(g8).add(at(A_RGL)).sub(k_g_half);
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                let host_u = u16;
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_g)).add(nu[1].mul(v[2]).mul(g).mul(host_u))
            }; Box::new(poly)
}
#[inline(never)]
fn factory_3(v: &[Fp2], hh:u32, gg:u32, pad:bool, nlk:usize) -> Box<dyn Fn(&[Fp2])->Fp2> {
 let mut idx=vec![usize::MAX;78]; for i in 67..=77 { idx[i]=i-64; }
 let (h0,i_fact)=(14,19); let mu=v[25..35].to_vec(); let nu=v[35..37].to_vec();
 let (alpha,beta,g_act,g_u8)=(v[21],v[22],v[23],v[24]);
 let p1=k(256); let b1=Fp::from_i64(256);
 let (k_h,k_g,b_h,b_g)=(k(1i64<<hh),k(1i64<<gg),Fp::from_i64(1i64<<hh),Fp::from_i64(1i64<<gg));
 let (k_h_half,k_g_half)=(k(if hh==0 {0} else {1i64<<(hh-1)}),k(if gg==0 {0} else {1i64<<(gg-1)}));
 let cols=[(A_RGL,1),(A_RGL,1i64<<(8-gg)),(A_UL0,1),(A_UL1,1),(A_HL0,1),(A_HL1,1),(A_RH0,1),(A_RH1,1),(A_RH1,1i64<<(16-hh))];
 let lks:Vec<LkT>=cols[..nlk].iter().map(|(p,c)| LkT{terms:vec![(idx[*p],Fp::from_i64(*c))],cst:g_u8}).collect();
 let gf=Gate(if pad {Some(20)} else {None}); let mut pz=PadTerm::none();
 if pad { pz.mu=mu[4+nlk.div_ceil(2)]; pz.add(Some(20),&(3..14).collect::<Vec<_>>(),v[37]); }
 let poly = move |v: &[Fp2]| {
                let at = |p: usize| v[idx[p]];
                let l2 = |o: usize| at(o).add(at(o + 1).mul_base(b1));
                let (g8, a16, u16, h16) = (at(A_G8), at(A_A16), at(A_U16), at(A_H16));
                let f0 = a16.mul(u16).sub(h16.mul_base(b_h)).sub(l2(A_RH0)).add(k_h_half);
                let f1 = u16.add(k(32768)).sub(l2(A_UL0));
                let f2 = h16.add(k(32768)).sub(l2(A_HL0));
                let f_act = v[i_fact].mul(alpha.sub(g8.add(k(128)).add(beta.mul(a16)).add(g_act))).sub(Fp2::ONE);
                let g = gf.at(v);
                let mut zc = helper_sum(v, &lks, h0, alpha, &mu[4..]).add(mu[3].mul(f_act)).add(pz.eval(v));
                let mut clauses = Fp2::ZERO;
                for (m, c) in mu.iter().zip([f0, f1, f2]) {
                    clauses = clauses.add(m.mul(c));
                }
                zc = zc.add(g.mul(clauses));
                let host_g = g8.mul_base(b_g).add(at(A_RGL)).sub(k_g_half);
                // SH_U = 0: no coefficient, no constant, no remainder (T2 A.4)
                let host_u = u16;
                v[0].mul(zc).add(nu[0].mul(v[1]).mul(g).mul(host_g)).add(nu[1].mul(v[2]).mul(g).mul(host_u))
            }; Box::new(poly)
}
#[no_mangle]
pub unsafe extern "C" fn fzc(out:*mut u64, words:*const u64, hh:u32,gg:u32,pad:u32,nlk:usize,mode:u32) {
 let w=std::slice::from_raw_parts(words,76); let v:Vec<Fp2>=w.chunks_exact(2).map(|x|Fp2::new(Fp(x[0]),Fp(x[1]))).collect();
 let f=match mode {0=>factory_0(&v,hh,gg,pad!=0,nlk),1=>factory_1(&v,hh,gg,pad!=0,nlk),2=>factory_2(&v,hh,gg,pad!=0,nlk),_=>factory_3(&v,hh,gg,pad!=0,nlk)};
 let z=f(&v[..21]); *out=z.c0.0; *out.add(1)=z.c1.0;
}

#[no_mangle]
pub unsafe extern "C" fn bench(out:*mut u64, words:*const u64, pad:u32, mode:u32, reps:usize) {
 let w=std::slice::from_raw_parts(words,76); let mut v:Vec<Fp2>=w.chunks_exact(2).map(|x|Fp2::new(Fp(x[0]),Fp(x[1]))).collect();
 let f=match mode {0=>factory_0(&v,14,8,pad!=0,9),1=>factory_1(&v,14,8,pad!=0,9),2=>factory_2(&v,14,8,pad!=0,9),_=>factory_3(&v,14,8,pad!=0,9)};
 let mut acc=Fp2::ZERO;
 let t=std::time::Instant::now();
 for i in 0..reps { v[3].c0=Fp::new(i as u64); acc=acc.add(f(std::hint::black_box(&v[..21]))); }
 let ns=t.elapsed().as_nanos() as u64;
 *out=acc.c0.0;*out.add(1)=acc.c1.0;*out.add(2)=ns;
}
