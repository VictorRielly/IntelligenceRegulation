#![allow(dead_code,non_upper_case_globals,unused_variables)]
// Exact u128 modular substitute, no native PTX/field implementation claimed.
const P:u128=18446744069414584321;
type Fp=u64;
static mut COUNTS:[u64;4]=[0;4];
#[repr(C)] #[derive(Clone,Copy)] struct Fp2{a:u64,b:u64}
fn plus(a:u64,b:u64)->u64{((a as u128+b as u128)%P) as u64}
fn minus(a:u64,b:u64)->u64{((a as u128+P-b as u128)%P) as u64}
fn times(a:u64,b:u64)->u64{((a as u128*b as u128)%P) as u64}
impl Fp2{
 const ZERO:Self=Self{a:0,b:0}; const ONE:Self=Self{a:1,b:0};
 fn add(self,o:Self)->Self{unsafe{COUNTS[0]+=1;} Self{a:plus(self.a,o.a),b:plus(self.b,o.b)}}
 fn sub(self,o:Self)->Self{unsafe{COUNTS[1]+=1;} Self{a:minus(self.a,o.a),b:minus(self.b,o.b)}}
 fn mul(self,o:Self)->Self{unsafe{COUNTS[2]+=1;} Self{a:plus(times(self.a,o.a),times(7,times(self.b,o.b))),b:plus(times(self.a,o.b),times(self.b,o.a))}}
 fn mul_base(self,o:u64)->Self{unsafe{COUNTS[3]+=1;} Self{a:times(self.a,o),b:times(self.b,o)}}
}
fn k(i:i64)->Fp2{Fp2{a:((i as i128).rem_euclid(P as i128)) as u64,b:0}}

const T:usize=32;
const D:usize=16;
const H:usize=2;
const DH:usize=8;
const KV:usize=8;
const F:usize=16;
const LOG_N:usize=8;
const U8_LEN:usize=256;
const A_D:usize=0;
const A_DSQ:usize=1;
const A_DM:usize=2;
const A_DSQM:usize=3;
const A_MX:usize=4;
const A_SUM:usize=5;
const A_LIMB:usize=6;
const A_LIMBM:usize=7;
const A_X:usize=8;
const A_XL0:usize=9;
const A_XL1:usize=10;
const A_Y:usize=11;
const A_NR0:usize=12;
const A_NS0:usize=16;
const A_AO:usize=20;
const A_AL0:usize=21;
const A_AL1:usize=22;
const A_RAL:usize=23;
const A_X1:usize=24;
const A_X1L0:usize=25;
const A_X1L1:usize=26;
const A_YM:usize=27;
const A_MR0:usize=28;
const A_MS0:usize=32;
const A_Z16:usize=36;
const A_X2:usize=37;
const A_X2L0:usize=38;
const A_X2L1:usize=39;
const A_ZL0:usize=40;
const A_ZL1:usize=41;
const A_RDL:usize=42;
const A_Q8:usize=43;
const A_RQL:usize=44;
const A_QR8:usize=45;
const A_RQRL:usize=46;
const A_O8:usize=47;
const A_RO0:usize=48;
const A_RO1:usize=49;
const A_K8:usize=50;
const A_RKL:usize=51;
const A_V8:usize=52;
const A_RVL:usize=53;
const A_KR8:usize=54;
const A_RKRL:usize=55;
const A_S8:usize=56;
const A_RSL:usize=57;
const A_ZSEL:usize=58;
const A_E:usize=59;
const A_P:usize=60;
const A_PL0:usize=61;
const A_PL1:usize=62;
const A_SR0:usize=63;
const A_SR1:usize=64;
const A_SG0:usize=65;
const A_SG1:usize=66;
const A_G8:usize=67;
const A_RGL:usize=68;
const A_A16:usize=69;
const A_U16:usize=70;
const A_UL0:usize=71;
const A_UL1:usize=72;
const A_H16:usize=73;
const A_HL0:usize=74;
const A_HL1:usize=75;
const A_RH0:usize=76;
const A_RH1:usize=77;
const A_MU8:usize=78;
const A_MEXP:usize=79;
const A_MACT:usize=80;
const N_A:usize=81;
const N_LIMBS:usize=9;
const LN_TOY:usize=4;
const LS_TOY:usize=2;
const LP_TOY:usize=2;
const H_L:usize=0;
const H_D0:usize=1;
const H_D_LAST:usize=19;
const H_Q0:usize=20;
const H_KV0:usize=27;
const H_S0:usize=33;
const H_SEXP:usize=40;
const H_F0:usize=41;
const H_FACT:usize=46;
const H_GU8:usize=47;
const H_GEXP:usize=48;
const H_GACT:usize=49;
const H_U:usize=50;
const N_H:usize=51;
const N_SLOTS:usize=23;
const SC_SS:usize=0;
const SC_SSM:usize=1;
const SC_TZC:usize=2;
const SC_LZC:usize=3;
const SC_RS:usize=4;
const SC_QMM:usize=5;
const SC_KMM:usize=6;
const SC_VMM:usize=7;
const SC_SCORE:usize=8;
const SC_PV:usize=9;
const SC_WO:usize=10;
const SC_GMM:usize=11;
const SC_UMM:usize=12;
const SC_DMM:usize=13;
const SC_DZC:usize=14;
const SC_QZC:usize=15;
const SC_KVZC:usize=16;
const SC_SZC:usize=17;
const SC_FZC:usize=18;
const SC_TAB:usize=19;
const SC_ZS:usize=20;
const SC_IO_IN:usize=21;
const SC_IO_OUT:usize=22;
const A_GROUPS:usize=35;
const H_GROUPS:usize=9;
const N_FUNCTIONALS:usize=34;
const A_ROWS:usize=455;
const H_ROWS:usize=384;
const A_DATA_ROWS:usize=213;
const H_DATA_ROWS:usize=280;
const F_P:u32=9;
#[derive(Clone,Copy,Debug,PartialEq)]enum Dom{T,Ht,L,D,Q,Kv,S,F,Tab}
struct Shape {ln:usize,ls:usize,lp:usize,norm_wrho:u32,wrho_s:u32,sh_ao:u32,sh_z:u32,sh_g:u32,sh_h:u32,sh_qkv:u32,sh_o:u32,sh_s:u32}
impl Shape {
 fn limbs_norm(&self)->usize{self.ln} fn limbs_sigma_s(&self)->usize{self.ls} fn limbs_p(&self)->usize{self.lp}
 fn norm_top_is_full_byte(&self)->bool{self.norm_wrho==8*self.ln as u32}
pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {
        let ln = self.limbs_norm();
        let mut v = vec![Dom::T; 4];
        v.extend([Dom::Ht; 2]);
        v.extend([Dom::L; 2]);
        // Dom::D: x, its two limbs, y; norm_a's rho and sigma limbs; the
        // attention output and residual 1 with their limbs; norm_m's rho and
        // sigma limbs; z16, residual 2 and the down-projection remainder
        v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);
        v.extend([Dom::Q; 7]);
        v.extend([Dom::Kv; 6]);
        v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
        v.extend([Dom::F; 11]);
        v.extend([Dom::Tab; 3]);
        v
    }
}
pub(crate) struct Ids {
    /// `map[toy id]` = the same plane's id at this shape
    map: Vec<usize>,
    /// the domain of every plane at this shape, in plane order
    doms: Vec<Dom>,
    pub ln: usize,
    pub ls: usize,
    pub lp: usize,
}
impl Ids {
pub(crate) fn new(sh: &Shape) -> Result<Ids, String> {
        let (ln, ls, lp) = (sh.limbs_norm(), sh.limbs_sigma_s(), sh.limbs_p());
        if ln < LN_TOY || ls < LS_TOY || lp < LP_TOY {
            return Err("private block: this shape's A plane list is shorter than the pinned one".into());
        }
        // (first toy id, toy length, this shape's length, domain), in plane
        // order. Only the four norm limb groups, the `p` limbs and the two
        // `sigma_s` limb groups have a length that is not a literal.
        let segs: [(usize, usize, usize, Dom); 18] = [
            (A_D, 4, 4, Dom::T),
            (A_MX, 2, 2, Dom::Ht),
            (A_LIMB, 2, 2, Dom::L),
            (A_X, 4, 4, Dom::D),
            (A_NR0, LN_TOY, ln, Dom::D),
            (A_NS0, LN_TOY, ln, Dom::D),
            (A_AO, 8, 8, Dom::D),
            (A_MR0, LN_TOY, ln, Dom::D),
            (A_MS0, LN_TOY, ln, Dom::D),
            (A_Z16, 7, 7, Dom::D),
            (A_Q8, 7, 7, Dom::Q),
            (A_K8, 6, 6, Dom::Kv),
            (A_S8, 5, 5, Dom::S),
            (A_PL0, LP_TOY, lp, Dom::S),
            (A_SR0, LS_TOY, ls, Dom::S),
            (A_SG0, LS_TOY, ls, Dom::S),
            (A_G8, 11, 11, Dom::F),
            (A_MU8, 3, 3, Dom::Tab),
        ];
        let mut map = vec![usize::MAX; N_A];
        let mut doms: Vec<Dom> = Vec::new();
        for (start, toy_len, len, dom) in segs {
            let base = doms.len();
            for k in 0..toy_len {
                map[start + k] = base + k;
            }
            for _ in 0..len {
                doms.push(dom);
            }
        }
        if map.iter().any(|v| *v == usize::MAX) {
            return Err("private block: the A plane segment table does not cover every plane".into());
        }
        if doms != sh.a_plane_doms() {
            return Err("private block: this shape's A plane list differs from the pinned one".into());
        }
        Ok(Ids { map, doms, ln, ls, lp })
    }
pub(crate) fn at(&self, toy_id: usize) -> usize {
        self.map[toy_id]
    }
pub(crate) fn nr(&self, k: usize) -> usize {
        self.map[A_NR0] + k
    }
pub(crate) fn ns(&self, k: usize) -> usize {
        self.map[A_NS0] + k
    }
pub(crate) fn mr(&self, k: usize) -> usize {
        self.map[A_MR0] + k
    }
pub(crate) fn ms(&self, k: usize) -> usize {
        self.map[A_MS0] + k
    }
pub(crate) fn pl(&self, k: usize) -> usize {
        self.map[A_PL0] + k
    }
pub(crate) fn sr(&self, k: usize) -> usize {
        self.map[A_SR0] + k
    }
pub(crate) fn sg(&self, k: usize) -> usize {
        self.map[A_SR0] + self.ls + k
    }
pub(crate) fn n_a(&self) -> usize {
        self.doms.len()
    }
}
struct Layout { ids:Ids } impl Layout {fn ids(&self)->&Ids{&self.ids}}
struct B<'a>{lay:&'a Layout,tabs:Vec<usize>,shaped:Vec<usize>}
impl<'a> B<'a> {fn a(&mut self,p:usize)->Result<usize,String>{self.tabs.push(p);Ok(self.tabs.len()-1)}
fn a_range(&mut self, first: usize, last: usize) -> Result<Vec<usize>, String> {
        let lay: &'a Layout = self.lay;
        let ids = lay.ids();
        let mut shaped = vec![usize::MAX; ids.n_a()];
        for p in first..=last {
            shaped[p] = self.a(p)?;
        }
        let mut idx = vec![usize::MAX; N_A];
        for (p, slot) in idx.iter_mut().enumerate() {
            let q = ids.at(p);
            if (first..=last).contains(&q) {
                *slot = shaped[q];
            }
        }
        self.shaped = shaped;
        Ok(idx)
    }fn tab(&self, plane: usize) -> usize {
        self.shaped[plane]
    }
}
pub(crate) struct Lk {
    pub terms: Vec<(usize, i64)>,
    pub cst: i64,
}
fn byte(p: usize) -> Lk {
    Lk { terms: vec![(p, 1)], cst: 0 }
}
fn scaled(p: usize, k: i64) -> Lk {
    Lk { terms: vec![(p, k)], cst: 0 }
}
fn sym(p: usize) -> [Lk; 2] {
    [Lk { terms: vec![(p, 1)], cst: 127 }, Lk { terms: vec![(p, -1)], cst: 127 }]
}
pub(crate) fn lookups_at(sh: &Shape, ids: &Ids, dom: Dom) -> Vec<Lk> {
    let (ln, ls, lp) = (ids.ln, ids.ls, ids.lp);
    // C-6: when the window fills its top limb exactly the `scaled` lookup is
    // the identity and is not emitted at all.
    let norm_top = !sh.norm_top_is_full_byte();
    let norm_scale = 1i64 << (8 * ln as u32 - sh.norm_wrho);
    let sigma_scale = 1i64 << (8 * ls as u32 - sh.wrho_s);
    let p_scale = 1i64 << (8 * lp as u32 - (F_P + 1));
    // ROUND 2: the top-limb pin of every windowed requantization remainder is
    // the SHAPE's `2^(8 - sh)` (one limb) or `2^(16 - sh)` (two limbs); at the
    // frozen shifts these are the historical literals 2, 4, 128, 2, 4, 4
    let one = |sh: u32| -> i64 { 1i64 << (8 - sh) };
    let two = |sh: u32| -> i64 { 1i64 << (16 - sh) };
    let mut v = Vec::new();
    match dom {
        Dom::L => {
            v.push(byte(ids.at(A_LIMB)));
            v.push(byte(ids.at(A_LIMBM)));
        }
        Dom::D => {
            v.extend([byte(ids.at(A_XL0)), byte(ids.at(A_XL1))]);
            v.extend(sym(ids.at(A_Y)));
            v.extend((0..ln).map(|k| byte(ids.nr(k))));
            if norm_top {
                v.push(scaled(ids.nr(ln - 1), norm_scale));
            }
            v.extend((0..ln).map(|k| byte(ids.ns(k))));
            if norm_top {
                v.push(scaled(ids.ns(ln - 1), norm_scale));
            }
            // LANE C SCRATCH: the AO remainder's top-bit pin is `2^(8 - sh_ao)`
            // (the frozen 2 at SH_AO = 7; 256, i.e. remainder zero, at 0)
            v.extend([byte(ids.at(A_AL0)), byte(ids.at(A_AL1)), byte(ids.at(A_RAL)), scaled(ids.at(A_RAL), 1i64 << (8 - sh.sh_ao)), byte(ids.at(A_X1L0)), byte(ids.at(A_X1L1))]);
            // T1 section C.1: norm_m's class, its rho / sigma limbs, and
            // residual 2's int16 limbs. Fourteen lookups at four limbs.
            v.extend(sym(ids.at(A_YM)));
            v.extend((0..ln).map(|k| byte(ids.mr(k))));
            if norm_top {
                v.push(scaled(ids.mr(ln - 1), norm_scale));
            }
            v.extend((0..ln).map(|k| byte(ids.ms(k))));
            if norm_top {
                v.push(scaled(ids.ms(ln - 1), norm_scale));
            }
            v.extend([byte(ids.at(A_X2L0)), byte(ids.at(A_X2L1))]);
            // T2 section B.3: z16's int16 class and the down remainder.
            v.extend([byte(ids.at(A_ZL0)), byte(ids.at(A_ZL1)), byte(ids.at(A_RDL)), scaled(ids.at(A_RDL), one(sh.sh_z))]);
        }
        Dom::F => {
            v.extend([byte(ids.at(A_RGL)), scaled(ids.at(A_RGL), one(sh.sh_g))]);
            v.extend([byte(ids.at(A_UL0)), byte(ids.at(A_UL1))]);
            v.extend([byte(ids.at(A_HL0)), byte(ids.at(A_HL1))]);
            v.extend([byte(ids.at(A_RH0)), byte(ids.at(A_RH1)), scaled(ids.at(A_RH1), two(sh.sh_h))]);
        }
        Dom::Q => {
            v.extend(sym(ids.at(A_Q8)));
            v.extend([byte(ids.at(A_RQL)), scaled(ids.at(A_RQL), one(sh.sh_qkv))]);
            v.extend(sym(ids.at(A_QR8)));
            v.extend([byte(ids.at(A_RQRL)), scaled(ids.at(A_RQRL), 2)]);
            v.extend(sym(ids.at(A_O8)));
            v.extend([byte(ids.at(A_RO0)), byte(ids.at(A_RO1)), scaled(ids.at(A_RO1), two(sh.sh_o))]);
        }
        Dom::Kv => {
            v.extend(sym(ids.at(A_K8)));
            v.extend([byte(ids.at(A_RKL)), scaled(ids.at(A_RKL), one(sh.sh_qkv))]);
            v.extend(sym(ids.at(A_V8)));
            v.extend([byte(ids.at(A_RVL)), scaled(ids.at(A_RVL), one(sh.sh_qkv))]);
            v.extend(sym(ids.at(A_KR8)));
            v.extend([byte(ids.at(A_RKRL)), scaled(ids.at(A_RKRL), 2)]);
        }
        Dom::S => {
            v.extend(sym(ids.at(A_S8)));
            v.extend([byte(ids.at(A_RSL)), scaled(ids.at(A_RSL), one(sh.sh_s))]);
            v.extend((0..lp).map(|k| byte(ids.pl(k))));
            v.push(scaled(ids.pl(lp - 1), p_scale));
            v.extend((0..ls).map(|k| byte(ids.sr(k))));
            v.push(scaled(ids.sr(ls - 1), sigma_scale));
            v.extend((0..ls).map(|k| byte(ids.sg(k))));
            v.push(scaled(ids.sg(ls - 1), sigma_scale));
        }
        Dom::T | Dom::Ht | Dom::Tab => {}
    }
    v
}
#[no_mangle] pub unsafe extern "C" fn catalog(ln:usize,nw:u32,ls:usize,ao:u32,z:u32,out:*mut usize)->usize {
 let sh=Shape{ln,ls,lp:2,norm_wrho:nw,wrho_s:8*ls as u32-1,sh_ao:ao,sh_z:z,sh_g:8,sh_h:14,sh_qkv:8,sh_o:9,sh_s:6};
 let ids=Ids::new(&sh).unwrap();let lay=Layout{ids};let mut b=B{lay:&lay,tabs:vec![usize::MAX;5],shaped:vec![]};
 let idx=b.a_range(lay.ids.at(A_X),lay.ids.at(A_RDL)).unwrap();
 let mut v=vec![b.tabs.len()];v.extend(idx);v.push(b.shaped.len());v.extend(b.shaped);
 let lks=lookups_at(&sh,&lay.ids,Dom::D);v.push(lks.len());
 for q in lks {assert_eq!(q.terms.len(),1);v.extend([q.terms[0].0,q.terms[0].1 as usize,q.cst as usize]);}
 for (i,x) in v.iter().enumerate(){*out.add(i)=*x;}v.len()
}
struct Gate(Option<usize>);
impl Gate {
    fn at(self, v: &[Fp2]) -> Fp2 {
        match self.0 {
            Some(i) => v[i],
            None => Fp2::ONE,
        }
    }
}struct PadTerm {
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
}struct LkT {
    terms: Vec<(usize, Fp)>,
    cst: Fp2,
}
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
}#[no_mangle] pub unsafe extern "C" fn original(vp:*const u64,nt:usize,mp:*const u64,nm:usize,np:*const u64,cp:*const u64,ip:*const usize,sp:*const usize,wp:*const usize,lp:*const i64,nlk:usize,zp:*const u64,out:*mut u64){
 let v=std::slice::from_raw_parts(vp as *const Fp2,nt);let mu=std::slice::from_raw_parts(mp as *const Fp2,nm);let nu=std::slice::from_raw_parts(np as *const Fp2,2);
 let c=std::slice::from_raw_parts(cp,8);let idx=std::slice::from_raw_parts(ip,81);let sp=std::slice::from_raw_parts(sp,7);
 let (ig,igm,id,idm,h0,ln)=(sp[0],sp[1],sp[2],sp[3],sp[4],sp[5]);let gd=Gate(if sp[6]==usize::MAX{None}else{Some(sp[6])});
 let w=std::slice::from_raw_parts(wp,4*ln);let lw=|r:usize|->Vec<(usize,Fp)>{(0..ln).map(|j|(w[r*ln+j],(1u128<<(8*j)) as u64)).collect()};
 let (w_nr,w_ns,w_mr,w_ms)=(lw(0),lw(1),lw(2),lw(3));
 let ls=std::slice::from_raw_parts(lp,3*nlk);let lks:Vec<LkT>=(0..nlk).map(|j|LkT{terms:vec![(ls[3*j] as usize,k(ls[3*j+1]).a)],cst:k(ls[3*j+2]).add(k(19))}).collect();
 let alpha=Fp2{a:101,b:3};let zz=std::slice::from_raw_parts(zp as *const Fp2,1)[0];let mut pz=PadTerm::none();
 if gd.0.is_some(){pz.mu=mu[11+nlk.div_ceil(2)];pz.add(gd.0,&(5..sp[2]).collect::<Vec<usize>>(),zz);}
 let (b_num,b_num_m,b_dv,b_den,b_p1)=(c[0],c[1],c[2],c[3],256u64);let (b_ao,b_z)=(c[4],c[6]);let (k_ao_half,k_z_half)=(Fp2{a:c[5],b:0},Fp2{a:c[7],b:0});
 let poly=include!("native-full-closure.rs.inc");let r=poly(v);*out=r.a;*out.add(1)=r.b;
}
fn isqrt_i128(v: i128) -> i128 {
    if v < 2 {
        return v;
    }
    let mut x = 1i128 << ((128 - v.leading_zeros()).div_ceil(2));
    loop {
        let y = (x + v / x) / 2;
        if y >= x {
            return x;
        }
        x = y;
    }
}fn bit_length(v: i128) -> u32 {
    128 - v.leading_zeros()
}
const INT16_ABS:i128=32_768;
#[no_mangle] pub unsafe extern "C" fn norm_window(width:usize,ceps:i64,tn:u32)->u32 {
 struct Cal{ceps:i64,tn:u32}impl Cal{fn derive(&self,width:usize)->u32{let d_max = isqrt_i128(i128::from(self.ceps) + width as i128 * INT16_ABS * INT16_ABS);let wrho = self.tn + 1 + bit_length(d_max);wrho}}
 Cal{ceps,tn}.derive(width)}
