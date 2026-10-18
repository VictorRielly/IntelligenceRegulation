#![allow(dead_code)]
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
// Research-only arithmetic adapter, never a transcript/prover implementation.
// Supports are PUBLIC shape descriptors, not witness-derived zero tests.
use field::{Fp,Fp2};
use std::collections::BTreeMap;
include!("captured-mask.rs");

fn product(v:[Fp2;3])->Fp2 {v[0].mul(v[1]).mul(v[2])}
pub fn rounds(positions:&[usize], values:&[[Fp2;3]], cube:usize, challenges:&[Fp2])
    -> Result<(Vec<[Fp2;4]>,[Fp2;3],Vec<usize>),u32> {
    if cube==0 || !cube.is_power_of_two() || cube>1<<20 || positions.len()!=values.len()
        || challenges.len()!=cube.trailing_zeros() as usize { return Err(1); }
    if positions.iter().any(|&i|i>=cube) || positions.windows(2).any(|w|w[0]>=w[1]) {return Err(2);}
    let mut entries:Vec<_>=positions.iter().copied().zip(values.iter().copied()).collect();
    let mut width=cube; let mut output=Vec::new(); let mut visits=Vec::new();
    for &r in challenges {
        let half=width/2;
        let mut pairs:BTreeMap<usize,[[Fp2;3];2]>=BTreeMap::new();
        for (i,v) in entries { pairs.entry(i%half).or_insert([[Fp2::ZERO;3];2])[i/half]=v; }
        visits.push(pairs.len());
        let mut sums=[Fp2::ZERO;4]; entries=Vec::with_capacity(pairs.len());
        for (i,p) in pairs {
            let dif=std::array::from_fn::<_,3,_>(|t|p[1][t].sub(p[0][t]));
            let mut cur=p[0];
            for x in 0..4 {sums[x]=sums[x].add(product(cur));for t in 0..3{cur[t]=cur[t].add(dif[t]);}}
            entries.push((i,std::array::from_fn(|t|p[0][t].add(r.mul(dif[t])))));
        }
        output.push(sums); width=half;
    }
    let finals=entries.first().map(|e|e.1).unwrap_or([Fp2::ZERO;3]);
    Ok((output,finals,visits))
}
unsafe fn read_fp(p:*const u64,n:usize)->Vec<Fp2>{
    std::slice::from_raw_parts(p,2*n).chunks_exact(2).map(|v|Fp2{c0:Fp(v[0]),c1:Fp(v[1])}).collect()
}
unsafe fn write_fp(p:*mut u64,v:&[Fp2]){for (j,x) in v.iter().enumerate(){*p.add(2*j)=x.c0.0;*p.add(2*j+1)=x.c1.0;}}
#[no_mangle]
pub unsafe extern "C" fn candidate(pos:*const usize,m:usize,vals:*const u64,cube:usize,
    rs:*const u64,k:usize,out:*mut u64,counts:*mut usize)->u32 {
    let v=read_fp(vals,3*m).chunks_exact(3).map(|x|[x[0],x[1],x[2]]).collect::<Vec<_>>();
    match rounds(std::slice::from_raw_parts(pos,m),&v,cube,&read_fp(rs,k)){
        Ok((s,f,c))=>{let mut flat=s.into_iter().flatten().collect::<Vec<_>>();flat.extend(f);
            write_fp(out,&flat);for(j,n)in c.iter().enumerate(){*counts.add(j)=*n;}0},Err(e)=>e
    }
}
#[no_mangle]
pub unsafe extern "C" fn captured_mask(coeff:*const u64,k:usize,rs:*const u64,c:*const u64,out:*mut u64)->u32{
    if k==0 || k>20{return 1;}
    let mask=CfsMask{n_vars:k,degree:3,coeffs:read_fp(coeff,3*k+2)};
    let r=read_fp(rs,k); let scale=read_fp(c,1)[0]; let mut data=Vec::new();
    for j in 0..k {data.extend(mask.round(j,&r[..j]).iter().map(|x|scale.mul(*x)));}
    data.extend([scale.mul(mask.total()),scale.mul(mask.eval(&r))]);write_fp(out,&data);0
}
// Research arithmetic probe: row bits then column bits, both MSB first.
// Only rectangular PUBLIC shape padding is implicit. No private sparsity.
fn eq_bit(a:Fp2,b:Fp2)->Fp2 {
    Fp2::ONE.sub(a).mul(Fp2::ONE.sub(b)).add(a.mul(b))
}
fn bool_weight(i:usize, point:&[Fp2])->Fp2 {
    point.iter().enumerate().fold(Fp2::ONE,|w,(j,&r)|
        w.mul(if (i>>(point.len()-1-j))&1==1 {r}else{Fp2::ONE.sub(r)}))
}
// Generate suffix weights with a depth-first walk: O(log N) stack, no E table,
// no division (including when coordinates are 0, 1, or 1/2).
fn weighted_halves(v:&[Fp2],half:usize,point:&[Fp2])->(Fp2,Fp2,usize) {
    fn walk(v:&[Fp2],half:usize,p:&[Fp2],i:usize,w:Fp2,a:&mut[Fp2;2],nodes:&mut usize) {
        if p.is_empty() {a[0]=a[0].add(w.mul(v[i]));a[1]=a[1].add(w.mul(v[half+i]));return;}
        *nodes+=1;
        walk(v,half,&p[1..],i*2,w.mul(Fp2::ONE.sub(p[0])),a,nodes);
        walk(v,half,&p[1..],i*2+1,w.mul(p[0]),a,nodes);
    }
    let mut a=[Fp2::ZERO;2];let mut nodes=0;
    walk(v,half,point,0,Fp2::ONE,&mut a,&mut nodes);(a[0],a[1],nodes)
}
pub fn factorized_rounds(n:usize,c:usize,values:&mut[Fp2],points:&[Fp2],
    column_point:&[Fp2],challenges:&[Fp2])
    ->Result<(Vec<[Fp2;4]>,[Fp2;3],[usize;3]),u32> {
    if n==0||!n.is_power_of_two()||n>1<<15||c==0||c>128{return Err(11);}
    let k=n.trailing_zeros()as usize;let w=c.next_power_of_two();let l=w.trailing_zeros()as usize;
    if n*c>1<<20||values.len()!=n*c||points.len()!=c*k||column_point.len()!=l||challenges.len()!=k+l{return Err(12);}
    let mut prefix=(0..c).map(|col|bool_weight(col,column_point)).collect::<Vec<_>>();
    let mut width=n;let mut out=Vec::with_capacity(k+l);
    let mut row_pairs=0;let mut eq_nodes=0;let mut col_pairs=0;
    for j in 0..k {
        let half=width/2;let mut sums=[Fp2::ZERO;4];
        for col in 0..c {
            let v=&mut values[col*n..col*n+width];let p=&points[col*k..(col+1)*k];
            let(a,b,nodes)=weighted_halves(v,half,&p[j+1..]);eq_nodes+=nodes;row_pairs+=half;
            let d=b.sub(a);
            for t in 0..4 {let x=Fp2::from_u64(t as u64);
                sums[t]=sums[t].add(prefix[col].mul(eq_bit(p[j],x)).mul(a.add(x.mul(d))));}
            for i in 0..half {v[i]=v[i].add(challenges[j].mul(v[half+i].sub(v[i])));}
            prefix[col]=prefix[col].mul(eq_bit(p[j],challenges[j]));
        }
        out.push(sums);width=half;
    }
    // Once row bits are bound, E is a MIXTURE across column coordinates;
    // S is the non-Boolean MLE of the public active-column selector.
    let mut terms=vec![[Fp2::ZERO;3];w];
    for col in 0..c {terms[col]=[prefix[col],Fp2::ONE,values[col*n]];}
    width=w;
    for &r in &challenges[k..] {
        let half=width/2;let mut sums=[Fp2::ZERO;4];col_pairs+=half;
        for i in 0..half {
            let a=terms[i];let d=std::array::from_fn::<_,3,_>(|f|terms[half+i][f].sub(a[f]));
            for t in 0..4 {let x=Fp2::from_u64(t as u64);
                sums[t]=sums[t].add(product(std::array::from_fn(|f|a[f].add(x.mul(d[f])))));}
            terms[i]=std::array::from_fn(|f|a[f].add(r.mul(d[f])));
        }
        out.push(sums);width=half;
    }
    Ok((out,terms[0],[row_pairs,eq_nodes,col_pairs]))
}
#[no_mangle]
pub unsafe extern "C" fn factorized(n:usize,c:usize,vs:*const u64,nv:usize,
    ps:*const u64,np:usize,cp:*const u64,nc:usize,rs:*const u64,kr:usize,
    out:*mut u64,counts:*mut usize)->u32 {
    // Length caps before allocating; FFI buffers themselves are trusted test harness input.
    if nv>1<<20||np>4096||nc>20||kr>20{return 13;}
    let mut v=read_fp(vs,nv);let p=read_fp(ps,np);let cp=read_fp(cp,nc);let rs=read_fp(rs,kr);
    match factorized_rounds(n,c,&mut v,&p,&cp,&rs) {
        Ok((rounds,finals,ns))=>{let mut flat=rounds.into_iter().flatten().collect::<Vec<_>>();flat.extend(finals);
            write_fp(out,&flat);for(j,x)in ns.iter().enumerate(){*counts.add(j)=*x;}0},Err(e)=>e
    }
}
