#![allow(dead_code)]
#[path="native/zkp-core/src/field.rs"]mod field;
use field::{Fp,Fp2};
#[derive(Clone,Copy,Debug,PartialEq,Eq)]enum Dom{T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
mod accuracy_precision{#[derive(Clone,Copy,PartialEq,Eq)]pub enum Stack{Legacy,Low,LowH24}}
mod layout{pub(crate) use super::Dom;include!("a_constants.rs");}
use layout::*;
mod accuracy_layout{include!("a_ids.rs");}
use accuracy_layout::AccuracyIds;
mod shape{
 use super::*;
 #[derive(Clone)]pub struct Shape{pub log_cols:usize,pub dd_cap:usize,pub logs:[usize;10],pub ls:usize,pub h24:bool}
 impl Shape{
 pub fn log(&self,d:Dom)->usize{self.logs[d as usize]}
 pub fn rows_of(&self,d:Dom)->usize{1usize<<self.log(d).saturating_sub(self.log_cols)}
 pub fn accuracy_stack(&self)->accuracy_precision::Stack{if self.h24{accuracy_precision::Stack::LowH24}else{accuracy_precision::Stack::Low}}
 pub fn limbs_sigma_s(&self)->usize{self.ls}pub fn limbs_norm(&self)->usize{3}pub fn limbs_p(&self)->usize{2}
 }
 include!("a_domains.rs");
}
use shape::Shape;
#[derive(Clone)]struct Case{sh:Shape,t:usize,d:usize,f:usize,h:usize,dh:usize,kv:usize,mode:usize,source:bool}
include!("cases.rs");include!("packing_plans.rs");include!("a_offsets.rs");
#[derive(Clone,Debug)]struct Slice{offset:usize,log_size:u32}
#[derive(Clone,Debug)]struct ZPart{slice:Slice,coef:Fp2,point:Vec<Fp2>}
#[derive(Clone,Debug)]struct ZClaim{parts:Vec<ZPart>,value:Fp2}
#[derive(Clone,Debug,PartialEq)]struct ZKey{tail:Vec<Fp2>,c0:usize,len:usize}
#[derive(Clone,Copy,Debug,PartialEq,Eq)]enum Cm{A,H,In,Out}
#[derive(Clone,Debug)]enum Coord{Rho(usize),Flip(usize),Fixed(Fp2)}
struct Priv{cm:Cm,slices:Vec<(usize,Fp2)>,log:usize,coords:Vec<Coord>,mask_row:usize,ext_round:usize}
enum Tab{Priv(Priv)}
struct Layout{sh:Shape,starts:Vec<usize>,mask:usize}
impl Layout{fn a_site(&self,s:usize,k:usize)->Result<usize,String>{Ok(self.mask+2*(self.starts[s]+k))}}
struct B<'a>{lay:&'a Layout,slot:usize,ak:usize,tabs:Vec<Tab>}
impl<'a>B<'a>{fn push(&mut self,t:Tab)->usize{self.tabs.push(t);self.tabs.len()-1}}
include!("a_builder.rs");include!("builder.rs");include!("claim_point.rs");include!("serial_eq.rs");include!("native_groups.rs");include!("native_audit.rs");
fn row_log(sh:&Shape,_:Cm)->usize{sh.log_cols}
fn rho(r:std::ops::Range<usize>)->Vec<Coord>{r.map(Coord::Rho).collect()}
fn lg(x:usize)->usize{(usize::BITS-(x-1).leading_zeros())as usize}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn random(s:&mut u64)->Fp2{Fp2::new(Fp::new(next(s)),Fp::new(next(s)))}
fn fixed(n:usize,s:&mut u64,mode:usize)->Vec<Coord>{(0..n).map(|_|Coord::Fixed(challenge(s,mode))).collect()}
fn challenge(s:&mut u64,mode:usize)->Fp2{let x=random(s);match mode{1=>Fp2::ZERO,2=>Fp2::ONE,_=>x}}
struct Transcript{state:u64,draws:usize}
impl Transcript{fn challenge_fp2_vec(&mut self,n:usize)->Vec<Fp2>{self.draws+=n;(0..n).map(|_|random(&mut self.state)).collect()}}
struct Spec{plane:usize,log:usize,coords:Vec<Coord>,extra:usize,ext:usize}
fn schedule(c:&Case,ids:&AccuracyIds,seed:&mut u64)->Vec<Vec<Spec>>{
 let sh=&c.sh;let mut out:Vec<Vec<Spec>>=(0..24).map(|_|vec![]).collect();
 let(lt,lh,ldh,ld,lf,lkv)=(lg(c.t),lg(c.h),lg(c.dh),lg(c.d),lg(c.f),lg(c.kv));
 let mut add=|slot:usize,old:usize,coords:Option<Vec<Coord>>,ls:Option<usize>,extra:usize,ext:usize|{
 let plane=ids.map[old];let log=ls.unwrap_or(sh.log(ids.doms[plane]));out[slot].push(Spec{plane,log,coords:coords.unwrap_or_else(||rho(0..log)),extra,ext});};
 add(0,A_X,None,None,0,0);add(1,A_X1,None,None,0,0);
 for (d,ds,limb) in [(A_D,A_DSQ,A_LIMB),(A_DM,A_DSQM,A_LIMBM)]{add(2,d,None,None,0,0);add(2,ds,None,None,0,0);for k in 0..9{add(2,limb,Some(rho(0..lt)),Some(lt),k*c.t,0);}}
 for p in [A_LIMB,A_LIMBM]{add(3,p,None,None,0,0);}for p in [A_E,A_ZSEL]{add(4,p,None,None,0,0);}
 let rq=fixed(lt,seed,c.mode);let rtf=fixed(lt,seed,c.mode);
 for s in [5,6,7,10,11,12,13]{let(old,inner)=match s{5|6|7=>(A_Y,ld),10=>(A_O8,lh+ldh),11|12=>(A_YM,ld),_=>(A_H16,lf)};let mut cs=if s==13{fixed(lt,seed,c.mode)}else if s==11||s==12{rtf.clone()}else{rq.clone()};cs.extend(rho(0..inner));add(s,old,Some(cs),None,0,0);}
 let mut cq=fixed(lt,seed,c.mode);cq.extend(rho(0..lkv));cq.extend(fixed(lh-lkv,seed,c.mode));cq.extend(rho(lkv..lkv+ldh));add(8,A_QR8,Some(cq),None,0,0);
 let mut ck=fixed(lt,seed,c.mode);ck.extend(rho(0..lkv+ldh));add(8,A_KR8,Some(ck),None,0,1);
 let mut cp=rho(0..lkv);cp.extend(fixed(lh-lkv+lt,seed,c.mode));cp.extend(rho(lkv..lkv+lt));add(9,A_P,Some(cp),None,0,0);
 let mut cv=rho(lkv..lkv+lt);cv.extend(rho(0..lkv));cv.extend(fixed(ldh,seed,c.mode));add(9,A_V8,Some(cv),None,0,1);
 for(s,p)in [(21,A_X),(22,A_X2)]{add(s,p,None,None,0,0);}
 drop(add);
 // R13 domain-range calls, followed by explicitly pushed cross-domain/flip claims.
 for(s,dom)in [(14,Dom::D),(15,Dom::Q),(16,Dom::Kv),(17,Dom::S),(18,Dom::F),(19,Dom::Tab),(23,Dom::Dd)]{
 if s==23&&sh.dd_cap==0{continue;}
 for(plane,d)in ids.doms.iter().enumerate(){if *d==dom{let log=sh.log(dom);out[s].push(Spec{plane,log,coords:rho(0..log),extra:0,ext:0});}}
 match s{
 14=>for old in [A_D,A_DM]{out[s].push(Spec{plane:ids.map[old],log:lt,coords:rho(0..lt),extra:0,ext:0});},
 15|16=>{let old=if s==15{A_Q8}else{A_K8};let log=sh.log(dom);let mut cs=rho(0..log);cs[log-ldh]=Coord::Flip(log-ldh);out[s].push(Spec{plane:ids.map[old],log,coords:cs,extra:0,ext:0});},
 17|23=>for old in if s==17{vec![A_MX,A_SUM]}else{vec![A_SUM]}{let log=sh.log(Dom::Ht);out[s].push(Spec{plane:ids.map[old],log,coords:rho(0..log),extra:0,ext:0});},_=>()
 }
 }
 out
}
fn key(c:&ZClaim,n:usize)->(Vec<Fp2>,usize,usize){let p=&c.parts[0];let size=1usize<<p.slice.log_size;let len=size.min(n);(p.point[p.point.len()-lg(len)..].to_vec(),if size<n{p.slice.offset%n}else{0},len)}
fn supports(cs:&[ZClaim],n:usize,rows:usize)->(Vec<Vec<bool>>,Vec<usize>){let(mut ks,mut sets,mut counts)=(vec![],vec![],vec![]);for c in cs{let k=key(c,n);let i=match ks.iter().position(|x|*x==k){Some(i)=>i,None=>{ks.push(k);sets.push(vec![false;rows]);counts.push(0);ks.len()-1}};counts[i]+=1;for p in &c.parts{for r in part_rows(p,n){sets[i][r]=true;}}}(sets,counts)}
fn union(ss:&[Vec<bool>],batch:&[usize])->usize{(0..ss[0].len()).filter(|r|batch.iter().any(|g|ss[*g][*r])).count()}
fn visits(ss:&[Vec<bool>],order:&[usize])->usize{order.chunks(4).map(|b|union(ss,b)).sum()}
include!("indexed.rs");include!("interval.rs");include!("gap.rs");
fn main(){let started=std::time::Instant::now();let mut seed=202610290153;let mut records=vec![];
 for(case,c)in cases().into_iter().enumerate(){let sh=&c.sh;let n=1<<sh.log_cols;let ids=AccuracyIds::new(sh.accuracy_stack(),sh.dd_cap>0,sh.ls).unwrap();assert_eq!(ids.doms,sh.a_plane_doms());let(off,data)=offsets(sh);let sp=schedule(&c,&ids,&mut seed);let mut starts=vec![0];for s in &sp{starts.push(starts.last().unwrap()+s.len());}let sites=starts[24];let prox=data+2*sites;let rows=prox+2;let lay=Layout{sh:sh.clone(),starts,mask:data};let mut cs=vec![];let mut descriptors=vec![];
 for slot in 0..24{let mut b=B{lay:&lay,slot,ak:0,tabs:vec![]};for spec in &sp[slot]{assert_eq!(spec.log,spec.coords.len());b.a_slice(off[spec.plane]+spec.extra,spec.log,spec.coords.clone(),spec.ext).unwrap();}
 let r:Vec<_>=(0..32).map(|_|challenge(&mut seed,c.mode)).collect();let e0=random(&mut seed);let e1=if slot==8||slot==9{random(&mut seed)}else{Fp2::ZERO};let cd=Fp2::ONE.sub(e0).mul(Fp2::ONE.sub(e1));let cms=[e0.mul(Fp2::ONE.sub(e1)),e1];assert_ne!(cd,Fp2::ZERO);for t in b.tabs{let Tab::Priv(p)=t;let point=claim_point(&p,&r);descriptors.push(vec![slot,p.log,p.slices[0].0,p.mask_row]);assert_ne!(cms[p.ext_round],Fp2::ZERO);cs.push(build_claim(sh,&p,&point,cd,cms[p.ext_round],Fp2::ZERO));}}
 let site_rows:Vec<_>=(data..prox).collect();audit_claims(&cs,n,rows,&site_rows,None,prox).unwrap();let groups=group_zclaims(&cs,rows,sh.log_cols as u32);let(mut sets,counts)=supports(&cs,n,rows);assert_eq!(sets.len(),groups.len());let mut tr=Transcript{state:202610290153,draws:0};let(rhos,_)=zk_rhos(&groups,rows,&mut tr);sets.push(vec![true;rows]);let numeric:Vec<_>=rhos.iter().enumerate().map(|(i,rho)|{for r in 0..rows{assert!(sets[i][r]||rho[r]==Fp2::ZERO);}rho.iter().filter(|x|**x!=Fp2::ZERO).count()}).collect();
 let order:Vec<_>=(0..sets.len()).collect();let v=visits(&sets,&order);let baseline=((sets.len()+3)/4)*rows;let overlaps=(0..data).filter(|r|sets[..sets.len()-1].iter().filter(|s|s[*r]).count()>1).count();assert!(overlaps>0);

records.push(run_gap(case,&c,&sets,&rhos,data,prox,&mut seed));
}
println!("{{\"status\":\"PASS\",\"seed\":202610290153,\"profiles\":[{}],\"elapsed_s\":{},\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",records.join(","),started.elapsed().as_secs_f64());}
type Ref=(u64,u64);const P:u128=0xffffffff00000001;
fn ra(a:Ref,b:Ref)->Ref{(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn rs(a:Ref,b:Ref)->Ref{(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn rm(a:Ref,b:Ref)->Ref{let f=|x:u64,y:u64|((x as u128*y as u128)%P)as u64;ra((f(a.0,b.0),f(a.0,b.1)),(f(7,f(a.1,b.1)),f(a.1,b.0)))}
fn rr(a:Fp2)->Ref{(a.c0.0,a.c1.0)}
fn weight(p:&[Fp2],i:usize)->Ref{p.iter().enumerate().fold((1,0),|a,(j,x)|rm(a,if (i>>(p.len()-1-j))&1==1{rr(*x)}else{rs((1,0),rr(*x))}))}
fn dense(c:&ZClaim,rows:usize,n:usize)->Vec<Ref>{let mut out=vec![(0,0);rows*n];for p in &c.parts{for i in 0..1<<p.slice.log_size{let w=if p.point.is_empty(){(1,0)}else{weight(&p.point,i)};out[p.slice.offset+i]=ra(out[p.slice.offset+i],rm(rr(p.coef),w));}}out}
