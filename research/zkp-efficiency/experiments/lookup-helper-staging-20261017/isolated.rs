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


}
use field::{Fp,Fp2};
const U8_LEN:usize=256;
const ZERO_DENOMINATOR:&str="zero LogUp denominator; discard attempt";
struct Lk {terms:Vec<(usize,i64)>,cst:i64}
fn helper_one(v: i64, alpha: Fp2, g_u8: Fp2, tbl: &[Option<Fp2>]) -> Result<Fp2, String> {
    match usize::try_from(v) {
        Ok(k) if k < U8_LEN => tbl[k].ok_or_else(|| ZERO_DENOMINATOR.to_string()),
        _ => {
            let d = alpha.sub(Fp2::from_i64(v).add(g_u8));
            if d.is_zero() {
                Err(ZERO_DENOMINATOR.to_string())
            } else {
                Ok(d.inv())
            }
        }
    }
}
fn u8_denominator_inverses(alpha: Fp2, g_u8: Fp2) -> Vec<Option<Fp2>> {
    let den: Vec<Fp2> = (0..U8_LEN).map(|v| alpha.sub(Fp2::from_i64(v as i64).add(g_u8))).collect();
    let mut nonzero: Vec<Fp2> = den.iter().copied().filter(|d| !d.is_zero()).collect();
    field::batch_inverse2(&mut nonzero);
    let mut k = 0usize;
    den.iter()
        .map(|d| {
            if d.is_zero() {
                None
            } else {
                k += 1;
                Some(nonzero[k - 1])
            }
        })
        .collect()
}
fn write_h(h: &mut [Fp], off: (usize, usize), col: &[Fp2]) {
    for (i, v) in col.iter().enumerate() {
        h[off.0 + i] = v.c0;
        h[off.1 + i] = v.c1;
    }
}
// Research interface, not applied to a native or CUDA caller.
// A residue has two i64 preimages only on [P-2^63, 2^63).
const SIGN: u64 = 1u64 << 63;
const AMBIGUOUS_LO: u64 = field::P - SIGN;
fn ambiguity_bit(v:i64, residue:u64) -> bool {
    v < 0 && residue >= AMBIGUOUS_LO && residue < SIGN
}
fn recover_word(residue:u64, negative_ambiguity:bool) -> u64 {
    // Unsigned word operations deliberately implement Z/(2^64).
    if residue >= SIGN || (residue >= AMBIGUOUS_LO && negative_ambiguity) {
        residue.wrapping_sub(field::P)
    } else { residue }
}
fn resident_lookup(raw:&[i64], a:&[u64], signs:&[u64], len:usize, l:&Lk, mode:u32) -> Vec<Fp> {
    (0..len).map(|x| {
        if mode == 2 {
            // Tempting, incorrect replacement: evaluate affine terms in Fp.
            l.terms.iter().fold(Fp::from_i64(l.cst), |s,(p,c)| s.add(Fp(a[*p*len+x]).mul(Fp::from_i64(*c))))
        } else {
            let mut word=l.cst as u64;
            for (p,c) in &l.terms {
                let j=*p*len+x;
                let bit=(signs[j/64] >> (j%64)) & 1 != 0;
                let v=recover_word(a[j],mode != 3 && bit);
                word=word.wrapping_add((*c as u64).wrapping_mul(v));
            }
            Fp::from_i64(word as i64)
        }
    }).collect()
}

#[no_mangle]
pub unsafe extern "C" fn codec(v:*const i64,n:usize,a:*mut u64,bits:*mut u64,out:*mut i64) {
 let raw=std::slice::from_raw_parts(v,n);
 let aa=std::slice::from_raw_parts_mut(a,n);
 let bb=std::slice::from_raw_parts_mut(bits,n.div_ceil(64)); bb.fill(0);
 for (j,&w) in raw.iter().enumerate() {aa[j]=Fp::from_i64(w).0; if ambiguity_bit(w,aa[j]) {bb[j/64] |= 1u64 << (j%64);}}
 for j in 0..n {*out.add(j)=recover_word(aa[j],(bb[j/64]>>(j%64))&1!=0) as i64;}
}
#[no_mangle]
pub unsafe extern "C" fn lookup(v:*const i64,a:*const u64,b:*const u64,n:usize,np:usize,pp:*const usize,cc:*const i64,nt:usize,cst:i64,out:*mut u64,mode:u32) {
 let raw=std::slice::from_raw_parts(v,n*np); let aa=std::slice::from_raw_parts(a,n*np); let bb=std::slice::from_raw_parts(b,(n*np).div_ceil(64));
 let terms=std::slice::from_raw_parts(pp,nt).iter().copied().zip(std::slice::from_raw_parts(cc,nt).iter().copied()).collect();
 let l=Lk{terms,cst}; let len=n;
 let col = |l: &Lk| -> Vec<i64> { (0..len).map(|x| l.terms.iter().fold(l.cst, |a, (p, c)| a.wrapping_add(c.wrapping_mul(raw[*p * len + x])))).collect() };
 let vals:Vec<Fp>=if mode==0 {col(&l).into_iter().map(Fp::from_i64).collect()} else {resident_lookup(raw,aa,bb,len,&l,mode)};
 for (j,v) in vals.iter().enumerate() {*out.add(j)=v.0;}
}
// Literal helper_one and write_h; serial pairing/caller orchestration only.
// Return 1 for a per-helper zero, 2 for a later whole-public-byte-table zero.
#[no_mangle]
pub unsafe extern "C" fn make_h(cols:*const i64,n:usize,nc:usize,prm:*const u64,h:*mut u64,hlen:usize) -> u32 {
 let w=std::slice::from_raw_parts(prm,4); let alpha=Fp2::new(Fp(w[0]),Fp(w[1]));let tag=Fp2::new(Fp(w[2]),Fp(w[3]));
 let cache=u8_denominator_inverses(alpha,tag);let raw=std::slice::from_raw_parts(cols,n*nc);
 let hwords=std::slice::from_raw_parts_mut(h,hlen);let nh=nc.div_ceil(2);
 // Private buffer snapshot. No commitment, transcript, RNG, or publication.
 let mut planar:Vec<Fp>=hwords.iter().map(|&v|Fp(v)).collect();
 for k in 0..nh {
   let mut col=Vec::with_capacity(n);
   for x in 0..n {
     let first=match helper_one(raw[(2*k)*n+x],alpha,tag,&cache) {Ok(v)=>v,Err(_)=>return 1};
     let z=if 2*k+1<nc {match helper_one(raw[(2*k+1)*n+x],alpha,tag,&cache) {Ok(v)=>first.add(v),Err(_)=>return 1}} else {first}; col.push(z);
   }
   write_h(&mut planar,(3+k*(2*n+2),3+k*(2*n+2)+n+1),&col);
 }
 // Preserve the mandatory whole-table refusal, even for unused zero entries.
 let mut all:Vec<Fp2>=(0..U8_LEN).map(|v|alpha.sub(Fp2::from_i64(v as i64).add(tag))).collect();
 if field::batch_inverse2_checked(&mut all).is_err() {return 2;}
 for (j,v) in planar.iter().enumerate() {hwords[j]=v.0;} 0
}
