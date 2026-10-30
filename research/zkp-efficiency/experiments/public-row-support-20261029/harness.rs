#![allow(dead_code)]
#[path="native/zkp-core/src/field.rs"] mod field;
use field::{Fp,Fp2};
use std::time::Instant;
#[derive(Clone,Debug)] struct Slice{offset:usize,log_size:u32}
#[derive(Clone,Debug)] struct ZPart{slice:Slice,coef:Fp2,point:Vec<Fp2>}
#[derive(Clone,Debug)] struct ZClaim{parts:Vec<ZPart>,value:Fp2}
#[derive(Clone,Debug,PartialEq)] struct ZKey{tail:Vec<Fp2>,c0:usize,len:usize}
#[derive(Clone)] struct Transcript{state:u64,draws:usize}
impl Transcript{fn challenge_fp2_vec(&mut self,n:usize)->Vec<Fp2>{self.draws+=n;(0..n).map(|_|random(&mut self.state)).collect()}}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn random(s:&mut u64)->Fp2{Fp2::new(Fp::new(next(s)),Fp::new(next(s)))}
include!("serial_eq.rs");include!("native_groups.rs");include!("native_audit.rs");
type Ref=(u64,u64); const P:u128=0xffffffff00000001;
fn rr(x:Fp2)->Ref{(x.c0.0,x.c1.0)}
fn ra(a:Ref,b:Ref)->Ref{(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn rs(a:Ref,b:Ref)->Ref{(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn rm(a:Ref,b:Ref)->Ref{let m=|a:u64,b:u64|((a as u128*b as u128)%P)as u64;ra((m(a.0,b.0),m(a.0,b.1)),(m(7,m(a.1,b.1)),m(a.1,b.0)))}
fn weight(p:&[Fp2],i:usize)->Ref{p.iter().enumerate().fold((1,0),|a,(j,x)|rm(a,if (i>>(p.len()-1-j))&1==1{rr(*x)}else{rs((1,0),rr(*x))}))}
fn fixture(sites:usize,g:usize,log:u32,mode:usize,s:&mut u64)->(Vec<ZClaim>,usize){
 let n=1<<log;let data=8;let rows=data+2*sites+2;let mut c=Vec::new();
 for site in 0..sites{
  let group=site%g;let mut tail:Vec<_>=(0..log).map(|j|Fp2::new(Fp::new(2+(group*7+j as usize)as u64),Fp::new(3+j as u64))).collect();
  if mode==1{tail=tail.iter().map(|x|Fp2::from_base(x.c0)).collect();}
  let head:Vec<_>=(0..3).map(|j|if mode==2{if j%2==0{Fp2::ZERO}else{Fp2::ONE}}else{random(s)}).collect();
  let mut point=head;point.extend(tail.clone());let cd=random(s);let cm=random(s);
  let mut parts=vec![ZPart{slice:Slice{offset:0,log_size:log+3},coef:cd,point}];
  for k in 0..2{parts.push(ZPart{slice:Slice{offset:(data+2*site+k)*n,log_size:log},coef:if k==0{cm}else{cm.mul(Fp2::U)},point:tail.clone()});}
  c.push(ZClaim{parts,value:random(s)});
 }(c,rows)
}
fn main(){
 let begin=Instant::now();let mut seed=202610290148u64;
 let(mut cases,mut rowchecks,mut coeffchecks,mut foldchecks,mut reorderchecks,mut refusals,mut controls,mut dense_floor)=(0,0,0,0,0,0,0,0);
 for sites in [4,9,17]{for groups in [1,3,4]{for log in [1,3,5]{for mode in 0..3{
  let(c,rows)=fixture(sites,groups,log,mode,&mut seed);let n=1usize<<log;let mask:Vec<_>=(8..rows-2).collect();
  audit_claims(&c,n,rows,&mask,None,rows-2).unwrap();let gs=group_zclaims(&c,rows,log);assert_eq!(gs.len(),groups);
  // Independent enumeration of each complete part's Boolean cube, then
  // factorization against native row and column weights. Both limbs checked.
  for (site,claim) in c.iter().enumerate(){let gi=site%groups;let mi=site/groups;let rw=&gs[gi].1[mi].0;let cw=&gs[gi].0;
   let mut dense=vec![(0,0);rows*n];
   for part in &claim.parts{for i in 0..1usize<<part.slice.log_size{dense[part.slice.offset+i]=ra(dense[part.slice.offset+i],rm(rr(part.coef),weight(&part.point,i)));}}
   for r in 0..rows{for col in 0..n{assert_eq!(rm(rr(rw[r]),rr(cw[col])),dense[r*n+col]);coeffchecks+=1;}}
  }
  let mut tr=Transcript{state:seed,draws:0};let(rhos,_)=zk_rhos(&gs,rows,&mut tr);
  for (gi,rho) in rhos[..groups].iter().enumerate(){
   for site in 0..sites{for k in 0..2{assert_eq!(!rho[8+2*site+k].is_zero(),site%groups==gi);rowchecks+=1;}}
   assert!(rho[rows-2].is_zero()&&rho[rows-1].is_zero());rowchecks+=2;
  }
  assert!(rhos.last().unwrap().iter().all(|x|!x.is_zero()));dense_floor+=1;
  // Fully synthetic message+pad columns: native Fp2 dense reference and an
  // independently expressed u128 modular sparse consumer.
  let width=n+3;let m:Vec<_>=(0..rows*width).map(|_|Fp::new(next(&mut seed))).collect();
  let mut expected=Vec::new();for rho in &rhos{let mut out=Vec::new();for col in 0..width{out.push((0..rows).fold(Fp2::ZERO,|a,r|a.add(rho[r].mul_base(m[r*width+col]))));}expected.push(out);}
  let mut got=vec![vec![(0,0);width];rhos.len()];
  for gi in (0..rhos.len()).rev(){for r in 0..rows{let w=rr(rhos[gi][r]);if w==(0,0){continue;}for col in 0..width{got[gi][col]=ra(got[gi][col],rm(w,(m[r*width+col].0,0)));}}}
  for(gi,out)in expected.iter().enumerate(){for col in 0..width{assert_eq!(got[gi][col],rr(out[col]));foldchecks+=1;}}
  let order:Vec<_>=(0..rhos.len()).rev().collect();let physical:Vec<_>=order.iter().map(|&i|got[i].clone()).collect();let mut restored=vec![vec![];got.len()];for (i,&logical) in order.iter().enumerate(){restored[logical]=physical[i].clone();}assert_eq!(got,restored);reorderchecks+=got.len()*width;
  assert_ne!(got,physical);controls+=1; // omitted inverse permutation
  assert_ne!(got.len()-1,expected.len());controls+=1; // omitted proximity
  cases+=1;
 }}}}
 // The H all-ones sum is a separate group and uses only the zero-sum
 // pair. It must not acquire any terminal-site or proximity support.
 let mut sumcases=0;
 for sites in [4,9,17]{let(mut c,rows)=fixture(sites,3,3,0,&mut seed);let n=8;let mask:Vec<_>=(8..rows-2).collect();
  let sum=ZClaim{parts:vec![ZPart{slice:Slice{offset:6*n,log_size:3},coef:Fp2::ONE,point:vec![]},ZPart{slice:Slice{offset:7*n,log_size:3},coef:Fp2::U,point:vec![]}],value:Fp2::ZERO};
  c.push(sum);audit_claims(&c,n,rows,&mask,Some([6,7]),rows-2).unwrap();let gs=group_zclaims(&c,rows,3);assert_eq!(gs.len(),4);let mut tr=Transcript{state:seed,draws:0};let(rhos,_)=zk_rhos(&gs,rows,&mut tr);assert!(rhos[3][8..].iter().all(|x|x.is_zero()));assert!(!rhos[3][6].is_zero()&&!rhos[3][7].is_zero());sumcases+=1;
 }
 let(c,rows)=fixture(9,3,3,0,&mut seed);let n=8;let mask:Vec<_>=(8..rows-2).collect();
 for kind in 0..7{let mut x=c.clone();let mut prox=rows-2;match kind{
  0=>x[0].parts[1].coef=Fp2::ZERO,
  1=>x[1].parts[1].slice.offset=x[0].parts[1].slice.offset,
  2=>x[0].parts.pop().map(|_|()).unwrap(),
  3=>x[0].parts[0].slice.offset=(rows-2)*n,
  4=>x.pop().map(|_|()).unwrap(),
  5=>prox-=1,
  _=>x[0].parts[1].slice.offset+=n,
 }assert!(audit_claims(&x,n,rows,&mask,None,prox).is_err());refusals+=1;}
 // Audit accepts valid geometry with algebraic cancellation on data rows;
 // cancellation may REMOVE support, never create foreign mask support.
 let mut x=c.clone();let p=x[0].parts[0].clone();let mut neg=p.clone();neg.coef=neg.coef.neg();x[0].parts.push(neg);audit_claims(&x,n,rows,&mask,None,rows-2).unwrap();
 let(rw,_)=zpart_weights(&p,rows,3);assert!(rw[..8].iter().any(|x|!x.is_zero()));let gs=group_zclaims(&x,rows,3);assert!(gs[0].1[0].0[..8].iter().all(|x|x.is_zero()));controls+=1;
 // A one-limb zero test would discard this live imaginary coefficient.
 assert!(!Fp2::U.is_zero());assert_eq!(rm((0,1),(11,0)),(0,11));controls+=1;
 println!("{{\"status\":\"PASS\",\"seed\":202610290148,\"fixtures\":{cases},\"h_sum_fixtures\":{sumcases},\"reserved_row_checks\":{rowchecks},\"independent_dense_coefficients\":{coeffchecks},\"independent_message_plus_pad_fold_values\":{foldchecks},\"restored_order_values\":{reorderchecks},\"dense_proximity_fixtures\":{dense_floor},\"audit_refusals\":{refusals},\"negative_controls\":{controls},\"elapsed_s\":{},\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",begin.elapsed().as_secs_f64());
}
