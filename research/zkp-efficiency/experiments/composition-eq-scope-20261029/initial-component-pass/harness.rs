#![allow(dead_code)]
#[path="native/zkp-core/src/field.rs"] mod field;
use field::{Fp,Fp2};
use std::{alloc::{GlobalAlloc,Layout,System},sync::atomic::{AtomicUsize,Ordering},time::Instant,hint::black_box};
struct Count;
static ALLOCS:AtomicUsize=AtomicUsize::new(0);static BYTES:AtomicUsize=AtomicUsize::new(0);
unsafe impl GlobalAlloc for Count {
 unsafe fn alloc(&self,l:Layout)->*mut u8{ALLOCS.fetch_add(1,Ordering::Relaxed);BYTES.fetch_add(l.size(),Ordering::Relaxed);System.alloc(l)}
 unsafe fn dealloc(&self,p:*mut u8,l:Layout){System.dealloc(p,l)}
 unsafe fn realloc(&self,p:*mut u8,l:Layout,n:usize)->*mut u8{ALLOCS.fetch_add(1,Ordering::Relaxed);BYTES.fetch_add(n,Ordering::Relaxed);System.realloc(p,l,n)}
}
#[global_allocator] static A:Count=Count;
#[derive(Clone,Debug)]struct Slice{offset:usize,log_size:u32}
#[derive(Clone,Debug)]struct ZPart{slice:Slice,coef:Fp2,point:Vec<Fp2>}
#[derive(Clone,Debug)]struct ZClaim{parts:Vec<ZPart>,value:Fp2}
#[derive(Clone,Debug,PartialEq)]struct ZKey{tail:Vec<Fp2>,c0:usize,len:usize}
#[derive(Clone)]struct Transcript{state:u64,draws:usize}
impl Transcript{fn challenge_fp2_vec(&mut self,n:usize)->Vec<Fp2>{self.draws+=n;(0..n).map(|_|random(&mut self.state)).collect()}}
include!("serial_eq.rs");include!("native_groups.rs");include!("candidate.rs");
type Ref=(u64,u64);const P:u128=0xffffffff00000001;
fn ra(a:Ref,b:Ref)->Ref{(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn rs(a:Ref,b:Ref)->Ref{(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn rm(a:Ref,b:Ref)->Ref{let f=|x:u64,y:u64|((x as u128*y as u128)%P)as u64;ra((f(a.0,b.0),f(a.0,b.1)),(f(7,f(a.1,b.1)),f(a.1,b.0)))}
fn rr(a:Fp2)->Ref{(a.c0.0,a.c1.0)}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn random(s:&mut u64)->Fp2{Fp2::new(Fp::new(next(s)),Fp::new(next(s)))}
fn weight(point:&[Fp2],i:usize)->Ref{point.iter().enumerate().fold((1,0),|v,(j,x)|rm(v,if(i>>(point.len()-1-j))&1==1{rr(*x)}else{rs((1,0),rr(*x))}))}
// Independent original-slice cube enumeration over the FULL matrix. No native Eq or key builder.
fn dense(claim:&ZClaim,rows:usize,n:usize)->Vec<Ref>{
 let mut m=vec![(0,0);rows*n];
 for p in &claim.parts{for i in 0..1<<p.slice.log_size{
  let w=if p.point.is_empty(){(1,0)}else{weight(&p.point,i)};
  m[p.slice.offset+i]=ra(m[p.slice.offset+i],rm(rr(p.coef),w));
 }}m
}
fn key_ref(p:&ZPart,n:usize)->(Vec<Ref>,usize,usize){
 let size=1<<p.slice.log_size;let used=size.min(n);let bits=used.trailing_zeros()as usize;
 (if p.point.is_empty(){vec![]}else{p.point[p.point.len()-bits..].iter().copied().map(rr).collect()},if size>=n{0}else{p.slice.offset%n},used)
}
fn fixture(log:u32,s:&mut u64)->(Vec<ZClaim>,usize){
 let n=1usize<<log;let rows=8;let point:Vec<Fp2>=(0..log+2).map(|_|random(s)).collect();let mut out=Vec::new();
 for (ls,off,eval) in [(log+2,0,true),(log+2,0,true),(log+1,2*n,true),(log,3*n,true),(log,0,false),(log+1,4*n,false),(log.saturating_sub(1),0,true),(log.saturating_sub(1),n/2,true),(log.saturating_sub(1),0,false)]{
  let p=if eval{point[point.len()-ls as usize..].to_vec()}else{vec![]};
  let mut parts=vec![ZPart{slice:Slice{offset:off,log_size:ls},coef:random(s),point:p.clone()}];
  if (1<<ls)<=n{parts.push(ZPart{slice:Slice{offset:(off+n)%(rows*n),log_size:ls},coef:random(s),point:p});}
  out.push(ZClaim{parts,value:random(s)});
 }(out,rows)
}
fn allocs<F,T>(f:F)->(T,usize,usize)where F:FnOnce()->T{
 let a=ALLOCS.load(Ordering::Relaxed);let b=BYTES.load(Ordering::Relaxed);let r=f();(r,ALLOCS.load(Ordering::Relaxed)-a,BYTES.load(Ordering::Relaxed)-b)
}
fn main(){
 let begin=Instant::now();let mut seed=202610290146;let(mut fixtures,mut rowchecks,mut densechecks,mut drawchecks,mut folds,mut refusals,mut controls,mut digest)=(0,0,0,0,0,0,0,0u64);
 for log in 0..=8{for pattern in 0..6{for pass in 0..3{
  let(mut claims,rows)=fixture(log,&mut seed);let n=1<<log;
  for c in &mut claims{for p in &mut c.parts{for(j,x)in p.point.iter_mut().enumerate(){*x=match pattern{0=>Fp2::ZERO,1=>Fp2::ONE,2=>if j%2==0{Fp2::ZERO}else{Fp2::ONE},3=>Fp2::from_base(x.c0),4=>Fp2::new(Fp(field::P-1),Fp(field::P-1)),_=>*x};}}}
  let old=group_zclaims(&claims,rows,log);let got=group_zclaims_with_columns(&claims,rows,log,false);let yes=group_zclaims_with_columns(&claims,rows,log,true);
  assert_eq!(old,yes);assert_eq!(old.len(),got.len());
  for((cw,a),(empty,b))in old.iter().zip(&got){assert_eq!(a,b);assert!(empty.is_empty());rowchecks+=a.len()*rows;assert_eq!(cw.len(),n);}
  // Membership/order by a separate integer-domain key, full matrix coefficients by direct cube.
  let mut keys=Vec::new();let mut member_counts=Vec::new();
  for c in &claims{let k=key_ref(&c.parts[0],n);let gi=match keys.iter().position(|a|*a==k){Some(i)=>i,None=>{keys.push(k);member_counts.push(0);keys.len()-1}};let mi=member_counts[gi];member_counts[gi]+=1;
   let m=dense(c,rows,n);let rw=&got[gi].1[mi].0;let cw=&old[gi].0;
   for r in 0..rows{for col in 0..n{assert_eq!(rm(rr(rw[r]),rr(cw[col])),m[r*n+col]);densechecks+=1;}}
  }
  let mut t=Transcript{state:20261029+pass,draws:0};let mut u=t.clone();let (ro,wo)=zk_rhos(&old,rows,&mut t);let(rg,wg)=zk_rhos(&got,rows,&mut u);assert_eq!((t.state,t.draws),(u.state,u.draws));assert_eq!(ro,rg);assert_eq!(wo,wg);drawchecks+=t.draws;
  // Synthetic fresh message+pad rows; consumer vector bytes compared after actual extracted rhos.
  let data:Vec<Fp2>=(0..rows*(n+3)).map(|_|random(&mut seed)).collect();
  for (r1,r2) in ro.iter().zip(&rg){for col in 0..n+3{
   let a=(0..rows).fold(Fp2::ZERO,|a,i|a.add(r1[i].mul(data[i*(n+3)+col])));
   let b=(0..rows).fold((0,0),|a,i|ra(a,rm(rr(r2[i]),rr(data[i*(n+3)+col]))));assert_eq!(rr(a),b);digest=digest.rotate_left(3)^a.c0.0^a.c1.0;folds+=1;
  }}fixtures+=1;
 }}}
 std::panic::set_hook(Box::new(|_|{}));
 let(base,rows)=fixture(3,&mut seed);
 for kind in 0..8{
  let mut c=base.clone();match kind{
   0=>c[0].parts.clear(),1=>c[0].parts[0].point.pop().map(|_|()).unwrap(),
   2=>c[0].parts[0].slice.offset=1,3=>c[6].parts[0].slice.offset=7,
   4=>c[0].parts[0].slice.offset=8*rows,5=>c[6].parts[1].point[0]=Fp2::U,
   6=>c[6].parts[1].slice.offset+=1,_=>c[4].parts[0].slice.offset=8*rows,
  }
  let old=std::panic::catch_unwind(||group_zclaims(&c,rows,3));let got=std::panic::catch_unwind(||group_zclaims_with_columns(&c,rows,3,false));assert!(old.is_err()&&got.is_err());refusals+=1;
 }
 let old=group_zclaims(&base,rows,3);let got=group_zclaims_with_columns(&base,rows,3,false);
 let mut bad=got.clone();bad.reverse();assert_ne!(old.iter().map(|x|&x.1).collect::<Vec<_>>(),bad.iter().map(|x|&x.1).collect::<Vec<_>>());controls+=1;
 let mut bad=got.clone();bad[0].1[0].0[0]=bad[0].1[0].0[0].add(Fp2::ONE);assert_ne!(bad[0].1,old[0].1);controls+=1;
 let mut t=Transcript{state:7,draws:0};let mut u=t.clone();let a=zk_rhos(&old,rows,&mut t);let _=u.challenge_fp2_vec(1);assert_ne!(a,zk_rhos(&got,rows,&mut u));controls+=1;
 let mut changed=base.clone();changed[0].value=changed[0].value.add(Fp2::ONE);let g=group_zclaims_with_columns(&changed,rows,3,false);let mut t=Transcript{state:7,draws:0};let mut u=t.clone();assert_ne!(zk_rhos(&old,rows,&mut t).1,zk_rhos(&g,rows,&mut u).1);controls+=1;
 // Verifier still requires columns: an empty-column substitution gives the wrong nonzero dot.
 let v=vec![Fp2::ONE;8];assert_ne!(v.iter().zip(&old[0].0).fold(Fp2::ZERO,|a,(x,y)|a.add(x.mul(*y))),Fp2::ZERO);controls+=1;
 let mut c=base.clone();c.swap(0,8);assert_ne!(group_zclaims(&c,rows,3),old);controls+=1;
 let mut c=base.clone();c[0].parts[0].coef=Fp2::ZERO;assert_ne!(group_zclaims_with_columns(&c,rows,3,false)[0].1,got[0].1);controls+=1;
 assert_eq!(group_zclaims(&[],0,3),group_zclaims_with_columns(&[],0,3,false));controls+=1;
 let mut benches=Vec::new();
 for log in [4,8,14]{let (c,rows)=fixture(log,&mut seed);let mut oldns=Vec::new();let mut newns=Vec::new();let mut ac=(0,0,0,0,0);
  for rep in 0..3{for arm in if rep%2==0{[false,true]}else{[true,false]}{
   let t=Instant::now();let(g,alloc,b)=allocs(||if arm{group_zclaims_with_columns(black_box(&c),rows,log,false)}else{group_zclaims(black_box(&c),rows,log)});black_box(&g);let dt=t.elapsed().as_nanos();
   if arm{newns.push(dt);ac.2=alloc;ac.3=b;}else{oldns.push(dt);ac.0=alloc;ac.1=b;ac.4=g.iter().map(|x|x.0.len()*16).sum();}drop(g);
  }}benches.push(format!("{{\"log_cols\":{log},\"groups\":{},\"baseline_ns\":{oldns:?},\"candidate_ns\":{newns:?},\"baseline_allocs\":{},\"baseline_requested_bytes\":{},\"candidate_allocs\":{},\"candidate_requested_bytes\":{},\"column_payload_bytes\":{}}}",group_zclaims_with_columns(&c,rows,log,false).len(),ac.0,ac.1,ac.2,ac.3,ac.4));
 }
 println!("{{\"status\":\"PASS\",\"seed\":202610290146,\"fixtures\":{fixtures},\"row_entries_compared\":{rowchecks},\"independent_dense_coefficients\":{densechecks},\"scripted_challenge_draws_compared\":{drawchecks},\"synthetic_fold_values\":{folds},\"matched_panic_cases\":{refusals},\"negative_controls\":{controls},\"digest\":\"{digest:016x}\",\"elapsed_s\":{},\"bench\":[{}],\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",begin.elapsed().as_secs_f64(),benches.join(","));
}
