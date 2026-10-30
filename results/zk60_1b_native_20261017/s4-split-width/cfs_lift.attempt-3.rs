//! S4 construction microproof, linked to the pinned normal-release R13 library.
//! Public deterministic fixtures only. This is not the private-block wire/profile.
use hashline::field::{Fp, Fp2};
use hashline::mle::eval_mle_ext;
use hashline::ntt::NttTables;
use hashline::pcs::{self, Commitment, OpeningZk, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use hashline::sumcheck::{self, CfsMask, CfsMasker, SumcheckProof};
use hashline::transcript::Transcript;
use hashline::zk::{self, MaskFunctional, MaskOpening, ZkRng};

fn lg(n: usize) -> usize { assert!(n.is_power_of_two()); n.trailing_zeros() as usize }
fn base(x: Fp) -> Fp2 { Fp2::new(x, Fp::ZERO) }
fn eval(a: &[Fp], p: &[Fp2]) -> Fp2 { eval_mle_ext(&a.iter().copied().map(base).collect::<Vec<_>>(), p) }

#[derive(Clone, Copy, Debug)]
struct Geo { t: usize, big: usize, small: usize }
impl Geo {
    fn n(self) -> usize { lg(self.t * self.big) }
    fn dropped(self) -> std::ops::Range<usize> { lg(self.t)..lg(self.t) + lg(self.big / self.small) }
    fn project(self, rho: &[Fp2]) -> (Fp2, Vec<Fp2>) {
        assert_eq!(rho.len(), self.n());
        let mut s = Fp2::ONE; let mut p = Vec::new();
        for (i, &r) in rho.iter().enumerate() {
            if self.dropped().contains(&i) { s = s.mul(Fp2::ONE.sub(r)); }
            else { p.push(r); }
        }
        (s, p)
    }
    fn lift(self, a: &[Fp2]) -> Vec<Fp2> {
        assert_eq!(a.len(), self.t * self.small);
        let mut v = vec![Fp2::ZERO; self.t * self.big];
        for t in 0..self.t { v[t*self.big..t*self.big+self.small].copy_from_slice(&a[t*self.small..(t+1)*self.small]); }
        v
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
enum Kind { Matmul, Norm }
#[derive(Clone, Copy, Debug, PartialEq)]
enum MaskStyle { WholeLift, IndependentExperimental }
#[derive(Clone, Copy, Debug, PartialEq)]
enum Attack { Honest, RepeatSmall, DropSmall, DuplicateSmall, WrongAxis, OtherMaskStyle, WrongPoint, WrongMaskRow, SwapPieces }
const ATTACKS: [Attack; 8] = [Attack::RepeatSmall, Attack::DropSmall, Attack::DuplicateSmall,
    Attack::WrongAxis, Attack::OtherMaskStyle, Attack::WrongPoint, Attack::WrongMaskRow, Attack::SwapPieces];

fn normalize(claims:Vec<ZClaim>)->Result<Vec<ZClaim>,String> {
    let mut out=Vec::new();
    for c in claims {
        if c.parts.iter().all(|p|p.coef==Fp2::ZERO) {
            if c.value!=Fp2::ZERO{return Err("zero functional claims a nonzero value".into());}
        } else {out.push(c);}
    }
    Ok(out)
}

#[derive(Clone)]
struct Fixture {
    g: Geo, kind: Kind, style:MaskStyle, params: PcsParams, zk: ZkOpts, data: Vec<Fp>,
    offsets: [usize; 2], mask_rows: [usize; 2], prox: usize,
    publics: Vec<Vec<Fp2>>, expected_sum: Fp2,
}
impl Fixture {
    fn new(g: Geo, kind: Kind, style:MaskStyle, rng: &mut ZkRng) -> Self {
        let params = PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 8 };
        let n = params.cols(); let big_len = g.t*g.big; let small_len = g.t*g.small;
        // Include a real nonzero column offset for sub-row source/mask slices.
        let small_off = big_len.div_ceil(n)*n + if small_len < n { n-small_len } else { 0 };
        let rows = (small_off+small_len).div_ceil(n);
        let mask_rows = [rows, rows+2]; let prox = rows+4;
        let data = (0..(rows+5)*n).map(|_| rng.fp()).collect::<Vec<_>>();
        let publics = match kind {
            Kind::Matmul => vec![rng.fp2_vec(big_len), g.lift(&rng.fp2_vec(small_len))],
            Kind::Norm => {
                // Eq on token bits, broadcast over feature bits, as in the row-norm sum.
                let eq = hashline::mle::eq_table_msb(&rng.fp2_vec(lg(g.t)));
                vec![(0..big_len).map(|i| eq[i/g.big]).collect()]
            }
        };
        let zk = ZkOpts::standard(&params);
        let mut f = Self { g, kind, style, params, zk, data, offsets: [0, small_off], mask_rows, prox, publics, expected_sum: Fp2::ZERO };
        let tabs = f.tables(Attack::Honest);
        f.expected_sum = (0..big_len).fold(Fp2::ZERO, |s,i| s.add(f.poly(&tabs.iter().map(|t|t[i]).collect::<Vec<_>>())));
        // Independently sum true pieces without using the larger-cube lift.
        let a = f.source(0); let b = f.source(1);
        let mut reference = Fp2::ZERO;
        for t in 0..g.t {
            for j in 0..g.big {
                let y = base(a[t*g.big+j]);
                reference = reference.add(match kind { Kind::Matmul => f.publics[0][t*g.big+j].mul(y), Kind::Norm => f.publics[0][t*g.big+j].mul(y.mul(y)) });
            }
            for j in 0..g.small {
                let y = base(b[t*g.small+j]);
                reference = reference.add(match kind { Kind::Matmul => f.publics[1][t*g.big+j].mul(y), Kind::Norm => f.publics[0][t*g.big+j].mul(y.mul(y)) });
            }
        }
        assert_eq!(f.expected_sum, reference); f
    }
    fn source(&self, i: usize) -> &[Fp] {
        let len = self.g.t * if i == 0 { self.g.big } else { self.g.small };
        &self.data[self.offsets[i]..self.offsets[i]+len]
    }
    fn degree(&self) -> usize { if self.kind == Kind::Matmul { 2 } else { 3 } }
    fn fresh_masks(&self,rng:&mut ZkRng)->Self {
        let mut out=self.clone();let n=self.params.cols();
        for x in &mut out.data[self.mask_rows[0]*n..(self.prox+1)*n] {*x=rng.fp();}
        out
    }
    fn poly(&self, v: &[Fp2]) -> Fp2 {
        let p = self.publics.len(); let (a,b)=(v[p],v[p+1]);
        match self.kind { Kind::Matmul => v[0].mul(a).add(v[1].mul(b)), Kind::Norm => v[0].mul(a.mul(a).add(b.mul(b))) }
    }
    fn tables(&self, attack: Attack) -> Vec<Vec<Fp2>> {
        let mut a = self.source(0).iter().copied().map(base).collect::<Vec<_>>();
        let mut b = self.source(1).iter().copied().map(base).collect::<Vec<_>>();
        if attack==Attack::SwapPieces {
            for t in 0..self.g.t {for j in 0..self.g.small {std::mem::swap(&mut a[t*self.g.big+j],&mut b[t*self.g.small+j]);}}
        }
        let mut lifted = self.g.lift(&b);
        match attack {
            Attack::RepeatSmall => for t in 0..self.g.t { for j in 0..self.g.big { lifted[t*self.g.big+j]=b[t*self.g.small+j%self.g.small]; } },
            Attack::DropSmall => lifted.fill(Fp2::ZERO),
            Attack::DuplicateSmall => for x in &mut lifted { *x=x.add(*x); },
            Attack::WrongAxis => {
                // Delete leading token bits rather than leading feature bits.
                for (i,x) in lifted.iter_mut().enumerate() { *x=if i < b.len() {b[i]} else {Fp2::ZERO}; }
            },
            _ => {}
        }
        let mut out=self.publics.clone(); out.push(a); out.push(lifted); out
    }
    fn source_point(&self, i: usize, rho: &[Fp2]) -> (Fp2,Vec<Fp2>) {
        if i==0 { (Fp2::ONE,rho.to_vec()) } else { self.g.project(rho) }
    }
    fn mask_value(&self, i: usize, p: &[Fp2]) -> Fp2 {
        let n=self.params.cols(); let logm=p.len().min(self.params.log_cols as usize);
        let c0=if p.len()<self.params.log_cols as usize { self.offsets[i]%n } else {0};
        let tail=&p[p.len()-logm..]; let len=1<<logm;
        let row=|r|eval(&self.data[r*n+c0..r*n+c0+len],tail);
        row(self.mask_rows[i]).add(Fp2::U.mul(row(self.mask_rows[i]+1)))
    }
    fn claims(&self,rho:&[Fp2],e:Fp2,terms:&[Fp2])->Vec<ZClaim> {
        let n=self.params.cols();
        (0..2).map(|i| {
            let(sigma,p)=self.source_point(i,rho);let logm=p.len().min(self.params.log_cols as usize);
            let c0=if p.len()<self.params.log_cols as usize {self.offsets[i]%n} else {0};
            let tail=p[p.len()-logm..].to_vec();
            let mask_c=if self.style==MaskStyle::WholeLift {e.mul(sigma)}else{e};
            ZClaim{parts:vec![
                ZPart{slice:Slice{offset:self.offsets[i],log_size:p.len() as u32},coef:Fp2::ONE.sub(e).mul(sigma),point:p},
                ZPart{slice:Slice{offset:self.mask_rows[i]*n+c0,log_size:logm as u32},coef:mask_c,point:tail.clone()},
                ZPart{slice:Slice{offset:(self.mask_rows[i]+1)*n+c0,log_size:logm as u32},coef:mask_c.mul(Fp2::U),point:tail}],value:terms[i]}
        }).collect()
    }
    fn transcript(&self,root:&Commitment,mroot:&[u8;32])->Transcript {
        let mut tr=Transcript::new(b"s4-cfs-lift-public-fixture-v2");
        tr.absorb(b"A",&root.root);tr.absorb(b"M",mroot);
        tr.absorb_u64(b"mask-style",if self.style==MaskStyle::WholeLift {0}else{1});
        for x in [self.g.t,self.g.big,self.g.small,self.degree()] {tr.absorb_u64(b"geometry",x as u64);}
        for p in &self.publics {tr.absorb_fp2(b"public",p);}
        tr.absorb_fp2(b"expected-sum",&[self.expected_sum]); tr
    }
    fn functionals(&self,scalar:Fp2,c:Fp2,rho:&[Fp2],g_value:Fp2)->Vec<MaskFunctional> {
        vec![MaskFunctional{terms:vec![(0,CfsMask::sum_weights(self.g.n()+1,self.degree()).into_iter().map(|w|w.mul(c)).collect())],value:scalar.sub(self.expected_sum)},
            MaskFunctional{terms:vec![(0,CfsMask::eval_weights(rho,self.degree()))],value:g_value}]
    }
}

struct Proof { root:Commitment,mroot:[u8;32],scalar:Fp2,sc:SumcheckProof,terms:Vec<Fp2>,a:OpeningZk,m:MaskOpening }
fn prove(f:&Fixture,attack:Attack,ntt:&NttTables,rng:&mut ZkRng)->Proof {
    // Every attempt has fresh site/proximity masks, pads/salts and CFS coefficients.
    let owned=f.fresh_masks(rng);let f=&owned;
    let mut cm=pcs::commit_zk_owned(&f.params,f.data.clone(),ntt,&f.zk,rng);
    cm.mask_rows=(f.mask_rows[0]..f.prox).collect(); cm.prox_mask_row=Some(f.prox);
    let root=cm.commitment(); let specs=[(f.g.n()+1,f.degree())];
    let mc=zk::mask_commit(&specs,ntt,rng);let mroot=mc.tree.root();let mask=&mc.masks[0];
    let mut tr=f.transcript(&root,&mroot);let c=tr.challenge_fp2();assert!(!c.is_zero());
    let mut tables=f.tables(attack);let actual=(0..tables[0].len()).fold(Fp2::ZERO,|s,i|s.add(f.poly(&tables.iter().map(|t|t[i]).collect::<Vec<_>>())));
    let scalar=actual.add(c.mul(mask.total()));tr.absorb_fp2(b"scalar",&[scalar]);
    tr.set_masker(Box::new(CfsMasker{mask:mask.clone(),c,challenges:Vec::new()}));
    let out=sumcheck::prove(&mut tables,f.degree(),|v|f.poly(v),&mut tr);let(_,mut rounds)=tr.take_masker();
    let mut exts=vec![Fp2::ZERO;out.finals.len()];
    for i in 0..2 {
        let(sigma,p)=f.source_point(i,&out.challenges);
        let mut m=f.mask_value(i,&p);
        let whole=f.style==MaskStyle::WholeLift;
        if whole ^ (attack==Attack::OtherMaskStyle&&i==1) {m=m.mul(sigma);}
        exts[f.publics.len()+i]=m;
    }
    // Each monomial contains a public factor; at extension=1 all those factors are zero.
    assert_eq!(f.poly(&exts),Fp2::ZERO);
    let sk=sumcheck::extension_round(&out.finals,&exts,f.degree(),|v|f.poly(v));
    let gk=mask.round(f.g.n(),&out.challenges);
    let sk=sk.iter().zip(gk).map(|(x,g)|x.add(c.mul(g))).collect::<Vec<_>>();
    tr.absorb_fp2(b"sc-round",&sk);rounds.push(sk);let e=tr.challenge_fp2();assert!(e!=Fp2::ZERO&&e!=Fp2::ONE);
    let mut terms=(0..2).map(|i|sumcheck::masked_terminal(out.finals[f.publics.len()+i],exts[f.publics.len()+i],e)).collect::<Vec<_>>();
    if attack==Attack::WrongPoint {
        let mut wrong=out.challenges.clone();wrong[0]=wrong[0].add(Fp2::ONE);
        let(s,p)=f.source_point(1,&wrong);let mc=if f.style==MaskStyle::WholeLift {e.mul(s)}else{e};
        terms[1]=Fp2::ONE.sub(e).mul(s).mul(eval(f.source(1),&p)).add(mc.mul(f.mask_value(1,&p)));
    }
    tr.absorb_fp2(b"terms",&terms);
    let mut claims=f.claims(&out.challenges,e,&terms);
    // These two attacks emit an opening against an intentionally wrong mapping.
    if attack==Attack::WrongPoint {
        let mut wrong=out.challenges.clone();wrong[0]=wrong[0].add(Fp2::ONE);
        claims[1]=f.claims(&wrong,e,&terms).remove(1);
    }
    if attack==Attack::WrongMaskRow { claims[1].parts[1].slice.offset=f.mask_rows[0]*f.params.cols()+claims[1].parts[1].slice.offset%f.params.cols(); }
    let a=pcs::open_zk(&cm,&normalize(claims).unwrap(),&mut tr);
    let mut full=out.challenges;full.push(e);
    let fs=f.functionals(scalar,c,&full,mask.eval(&full));let m=zk::mask_open(&mc,&fs,ntt,&mut tr);
    Proof{root,mroot,scalar,sc:SumcheckProof{rounds},terms,a,m}
}
fn verify(f:&Fixture,p:&Proof,ntt:&NttTables)->Result<(),String> {
    let mut tr=f.transcript(&p.root,&p.mroot);let c=tr.challenge_fp2();if c.is_zero(){return Err("zero c".into());}
    tr.absorb_fp2(b"scalar",&[p.scalar]);let(fin,full)=sumcheck::verify(p.scalar,f.degree(),f.g.n()+1,&p.sc,&mut tr)?;
    let rho=&full[..f.g.n()];let e=full[f.g.n()];if e==Fp2::ZERO||e==Fp2::ONE{return Err("zero/one extension".into());}
    if p.terms.len()!=2{return Err("terms".into());}
    let mut vals=f.publics.iter().map(|v|Fp2::ONE.sub(e).mul(eval_mle_ext(v,rho))).collect::<Vec<_>>();vals.extend_from_slice(&p.terms);
    let g_value=fin.sub(f.poly(&vals)).mul(c.inv());tr.absorb_fp2(b"terms",&p.terms);
    pcs::verify_zk(&f.params,&f.zk,&p.root,&normalize(f.claims(rho,e,&p.terms))?,&p.a,ntt,&mut tr)?;
    zk::mask_verify(&p.mroot,&[(f.g.n()+1,f.degree())],&f.functionals(p.scalar,c,&full,g_value),&p.m,ntt,&mut tr)
}

fn zero_edge(f:&Fixture,ntt:&NttTables,rng:&mut ZkRng)->usize {
    let owned=f.fresh_masks(rng);let f=&owned;
    let mut cm=pcs::commit_zk_owned(&f.params,f.data.clone(),ntt,&f.zk,rng);
    cm.mask_rows=(f.mask_rows[0]..f.prox).collect();cm.prox_mask_row=Some(f.prox);
    let root=cm.commitment();let mut rho=(0..f.g.n()).map(|i|Fp2::new(Fp::new(3+i as u64),Fp::new(11+i as u64))).collect::<Vec<_>>();
    rho[f.g.dropped().start]=Fp2::ONE;let(sigma,p)=f.g.project(&rho);assert_eq!(sigma,Fp2::ZERO);
    let e=Fp2::new(Fp::new(13),Fp::new(17));let terms=(0..2).map(|i| {
        let(s,p)=f.source_point(i,&rho);let mc=if f.style==MaskStyle::WholeLift {e.mul(s)}else{e};
        Fp2::ONE.sub(e).mul(s).mul(eval(f.source(i),&p)).add(mc.mul(f.mask_value(i,&p)))
    }).collect::<Vec<_>>();
    let claims=f.claims(&rho,e,&terms);assert_eq!(claims[1].parts[0].coef,Fp2::ZERO);
    // A direct functional edge test, not a forced Fiat-Shamir transcript.
    let tr=||{let mut t=Transcript::new(b"s4-zero-lift-direct-functional-only");t.absorb(b"root",&root.root);t};
    let normalized=normalize(claims.clone()).unwrap();
    let a=pcs::open_zk(&cm,&normalized,&mut tr());pcs::verify_zk(&f.params,&f.zk,&root,&normalized,&a,ntt,&mut tr()).unwrap();
    let mut bad=claims.clone();bad[1].value=bad[1].value.add(Fp2::ONE);
    if f.style==MaskStyle::WholeLift {
        assert_eq!(normalized.len(),1);assert!(normalize(bad).is_err());
        let mut wrong=claims;wrong[1].parts[1].coef=e;wrong[1].parts[2].coef=e.mul(Fp2::U);
        assert!(pcs::verify_zk(&f.params,&f.zk,&root,&normalize(wrong).unwrap(),&a,ntt,&mut tr()).is_err());
    } else {
        assert_eq!(normalized.len(),2);assert_ne!(claims[1].parts[1].coef,Fp2::ZERO);
        assert!(pcs::verify_zk(&f.params,&f.zk,&root,&bad,&a,ntt,&mut tr()).is_err());
        // Scaling this independent extension mask by sigma would detach the claim.
        let mut wrong=claims;wrong[1].parts[1].coef=Fp2::ZERO;wrong[1].parts[2].coef=Fp2::ZERO;
        assert!(normalize(wrong).is_err());
    }
    assert_eq!(p.len(),lg(f.g.t*f.g.small));2
}

fn main() {
    let ntt=NttTables::new(13);let mut rng=ZkRng::new(91,b"s4-cfs-public-fixtures-only");
    let mut accepted=0;let mut rejected=0;let mut zero=0;
    for g in [Geo{t:2,big:8,small:4},Geo{t:2,big:32,small:4},Geo{t:16,big:8,small:4},Geo{t:16,big:32,small:4}] {
        for kind in [Kind::Matmul,Kind::Norm] { for style in [MaskStyle::WholeLift,MaskStyle::IndependentExperimental] {
            let f=Fixture::new(g,kind,style,&mut rng);let p=prove(&f,Attack::Honest,&ntt,&mut rng);verify(&f,&p,&ntt).unwrap();accepted+=1;
            for attack in ATTACKS {
                let p=prove(&f,attack,&ntt,&mut rng);
                let err=verify(&f,&p,&ntt).expect_err("forged microproof accepted");
                println!("rejected {g:?} {kind:?} {style:?} {attack:?}: {err}");rejected+=1;
            }
            zero+=zero_edge(&f,&ntt,&mut rng);
        }}
    }
    println!("{{\"honest_cfs_pcs_microproofs\":{accepted},\"emitted_bad_microproofs_rejected\":{rejected},\"zero_lift_honest_functionals\":{accepted},\"zero_lift_bad_functionals_rejected\":{zero},\"mask_styles\":[\"whole-lift: primary coordinated design, checked zero normalization\",\"independent: experimental alternative requiring separate design review\"],\"scope\":\"native CFS/sumcheck/PCS/M components with experimental adapter; no private-block wire/profile or privacy acceptance\"}}");
}
