#![allow(dead_code)]
mod field;
use field::{Fp,Fp2,P};
use std::cell::RefCell;
use std::rc::Rc;
use std::io::Write;
include!("native_host.rs");

#[derive(Debug,Clone,Copy,PartialEq,Eq)]
enum Mode { Serial, Hybrid }
#[derive(Debug,Clone,Copy)]
struct Plan { mode:Mode, rho_limbs:usize, out_limbs:usize, scratch:usize }
fn length(v:usize,r:usize)->Option<usize>{v.checked_mul(r)?.checked_mul(2)}
fn bytes(a:usize,b:usize)->Option<usize>{a.checked_add(b)?.checked_mul(8)}
fn plan(rows:usize,n:usize,k:usize,budget:usize)->Result<Plan,&'static str>{
 if n==0{return Err("zero width")}
 let cap=k.min(4);
 let r=length(cap,rows).ok_or("serial rho overflow")?;
 let o=length(cap,n).ok_or("output overflow")?;
 let serial=bytes(r,o).ok_or("serial scratch overflow")?;
 if serial>budget{return Err("scratch budget")}
 if let Some(full)=length(k,rows){if let Some(scratch)=bytes(full,o){
  if scratch<=budget{return Ok(Plan{mode:Mode::Hybrid,rho_limbs:full,out_limbs:o,scratch})}
 }}
 Ok(Plan{mode:Mode::Serial,rho_limbs:r,out_limbs:o,scratch:serial})
}
#[derive(Default)]
struct Stats { live:usize,peak:usize,ops:Vec<&'static str>,fail:Option<usize>,allocs:usize,h2d:usize,d2h:usize,hbytes:usize,dbytes:usize,kernels:usize }
type Shared=Rc<RefCell<Stats>>;
fn op(s:&Shared,name:&'static str)->Result<(),String>{let mut s=s.borrow_mut();let i=s.ops.len();s.ops.push(name);if s.fail==Some(i){Err(format!("injected {name}@{i}"))}else{Ok(())}}
struct Buf { v:Vec<u64>,s:Shared }
impl Buf {
 fn new(s:&Shared,n:usize,name:&'static str)->Result<Self,String>{op(s,name)?;{let mut x=s.borrow_mut();x.allocs+=1;x.live+=n*8;x.peak=x.peak.max(x.live);}Ok(Self{v:vec![u64::MAX;n],s:s.clone()})}
}
impl Drop for Buf{fn drop(&mut self){self.s.borrow_mut().live-=self.v.len()*8;}}
fn upload(s:&Shared,b:&mut Buf,r:&[Vec<Fp2>])->Result<(),String>{
 op(s,"h2d")?;let flat=r.iter().flat_map(|v|v.iter().flat_map(|z|[z.c0.0,z.c1.0])).collect::<Vec<_>>();
 b.v[..flat.len()].copy_from_slice(&flat);let mut x=s.borrow_mut();x.h2d+=1;x.hbytes+=flat.len()*8;Ok(())
}
// Offset is supplied by a checked planner; the unchanged max-four kernel sees a slice.
fn launch(s:&Shared,data:&[Fp],rows:usize,n:usize,k:usize,rho:&[u64],out:&mut[u64])->Result<(),String>{
 op(s,"kernel")?;s.borrow_mut().kernels+=1;assert!(k>0&&k<=4);assert_eq!(rho.len(),2*k*rows);
 let before=out.to_vec();
 for j in 0..n{for g in 0..k{let mut a=Fp2::ZERO;for i in 0..rows{let t=2*(g*rows+i);a=a.add(Fp2::new(Fp(rho[t]),Fp(rho[t+1])).mul_base(data[i*n+j]));}out[2*(g*n+j)]=a.c0.0;out[2*(g*n+j)+1]=a.c1.0;}}
 assert_eq!(&out[2*k*n..],&before[2*k*n..]);Ok(())
}
fn run(data:&[Fp],rows:usize,n:usize,r:&[Vec<Fp2>],budget:usize,s:&Shared)->Result<Vec<Vec<Fp2>>,String>{
 if data.len()!=rows.checked_mul(n).ok_or("matrix overflow")?||r.iter().any(|v|v.len()!=rows){return Err("shape".into())}
 let p=plan(rows,n,r.len(),budget).map_err(str::to_string)?;
 if r.is_empty(){return Ok(Vec::new())}
 let mut rho=Buf::new(s,p.rho_limbs,"alloc_rho")?;let mut out=Buf::new(s,p.out_limbs,"alloc_out")?;
 if p.mode==Mode::Hybrid{upload(s,&mut rho,r)?;}
 let mut result=Vec::new();
 for start in (0..r.len()).step_by(4){
  let k=(r.len()-start).min(4);
  if p.mode==Mode::Serial{upload(s,&mut rho,&r[start..start+k])?;}
  let offset=if p.mode==Mode::Hybrid{length(start,rows).ok_or("offset overflow")?}else{0};
  let end=offset.checked_add(length(k,rows).ok_or("length overflow")?).ok_or("end overflow")?;
  launch(s,data,rows,n,k,&rho.v[offset..end],&mut out.v)?;
  op(s,"d2h")?;{let mut x=s.borrow_mut();x.d2h+=1;x.dbytes+=16*k*n;}
  // Synchronous completed download before scratch overwrite; no returned prefix on error.
  result.extend((0..k).map(|g|(0..n).map(|j|Fp2::new(Fp(out.v[2*(g*n+j)]),Fp(out.v[2*(g*n+j)+1]))).collect::<Vec<_>>()));
 }
 Ok(result)
}
fn reference(d:&[Fp],rows:usize,n:usize,r:&[Vec<Fp2>])->Vec<Vec<Fp2>>{
 // Independent u128 modular arithmetic, different iteration order from candidate.
 r.iter().map(|rho|(0..n).map(|j|{let mut a=0u128;let mut b=0u128;for i in 0..rows{a=(a+(rho[i].c0.0 as u128*d[i*n+j].0 as u128)%(P as u128))%(P as u128);b=(b+(rho[i].c1.0 as u128*d[i*n+j].0 as u128)%(P as u128))%(P as u128);}Fp2::new(Fp(a as u64),Fp(b as u64))}).collect()).collect()
}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fixture(rows:usize,n:usize,k:usize,m:usize,s:&mut u64)->(Vec<Fp>,Vec<Vec<Fp2>>){
 let d=(0..rows*n).map(|i|Fp(if m==1{P-1}else if m==2&&i/n+3<rows{0}else{next(s)%P})).collect();
 let r=(0..k).map(|g|(0..rows).map(|i|if m==2&&g+1<k&&i+3<rows{Fp2::ZERO}else{Fp2::new(Fp(if m==3{0}else if m==1{P-1}else{next(s)%P}),Fp(if m==1{P-1}else{next(s)%P}))}).collect()).collect();(d,r)
}
fn main(){
 let mut seed=202610300541u64;let(mut fixtures,mut checks,mut limbs,mut failures)=(0,0,0,0);
 let mut plans=std::fs::File::create("public-plans.jsonl").unwrap();
 for rows in [0,1,7,3517,usize::MAX/64,usize::MAX]{for n in [0,1,17,16384,usize::MAX/64,usize::MAX]{for k in [0,1,4,5,13,57,usize::MAX]{for budget in [0,1,1273663,1273664,4256079,4256080,usize::MAX]{
  match plan(rows,n,k,budget){Ok(p)=>writeln!(plans,"{{\"rows\":{rows},\"n\":{n},\"k\":{k},\"budget\":{budget},\"mode\":\"{:?}\",\"rho_limbs\":{},\"out_limbs\":{},\"scratch\":{}}}",p.mode,p.rho_limbs,p.out_limbs,p.scratch).unwrap(),Err(e)=>writeln!(plans,"{{\"rows\":{rows},\"n\":{n},\"k\":{k},\"budget\":{budget},\"error\":\"{e}\"}}").unwrap()}
 }}}}
 let mut vectors=std::fs::File::create("public-vectors.jsonl").unwrap();
 let mut dims=Vec::new();for rows in [0,1,7,33]{for n in [1,3,17]{for k in [0,1,4,5,12,13,57,59]{for m in 0..4{dims.push((rows,n,k,m));}}}}
 for(rows,k)in [(3517,57),(3272,12),(3395,59),(3116,13)]{dims.push((rows,3,k,2));}
 for(rows,n,k,m)in dims{
  let(d,r)=fixture(rows,n,k,m,&mut seed);let(pads,_)=fixture(rows,3,k,0,&mut seed);
  let want=reference(&d,rows,n,&r);assert_eq!(want,fold_rows_host(&d,rows,n,n,1,&r));
  let pw=reference(&pads,rows,3,&r);assert_eq!(pw,fold_rows_host(&pads,rows,3,3,1,&r));
  let full=plan(rows,n,k,usize::MAX).unwrap();let serial=16*k.min(4)*(rows+n);
  for budget in [serial,full.scratch,full.scratch.saturating_sub(1),usize::MAX]{
   let s=Rc::new(RefCell::new(Stats::default()));let result=run(&d,rows,n,&r,budget,&s);
   if budget<serial{assert!(result.is_err());assert!(s.borrow().ops.is_empty());checks+=1;continue}
   let p=plan(rows,n,k,budget).unwrap();let got=result.unwrap();assert_eq!(got,want);
   let x=s.borrow();let b=(k+3)/4;assert_eq!(x.live,0);assert_eq!(x.peak,p.scratch);assert!(x.peak<=budget);
   assert_eq!(x.allocs,if k==0{0}else{2});assert_eq!(x.h2d,if k==0{0}else if p.mode==Mode::Hybrid{1}else{b});assert_eq!(x.d2h,b);assert_eq!(x.kernels,b);assert_eq!(x.hbytes,16*k*rows);assert_eq!(x.dbytes,16*k*n);
   for g in 0..k{let mut combined=got[g].clone();combined.extend(&pw[g]);let mut expected=want[g].clone();expected.extend(&pw[g]);assert_eq!(combined,expected);}
   checks+=1;
  }
  if rows==7&&n==3&&[1,5,13,57].contains(&k){
   let s=Rc::new(RefCell::new(Stats::default()));let got=run(&d,rows,n,&r,usize::MAX,&s).unwrap();
   let data=d.iter().map(|v|v.0).collect::<Vec<_>>();let pads=pads.iter().map(|v|v.0).collect::<Vec<_>>();let rho=r.iter().map(|v|v.iter().flat_map(|z|[z.c0.0,z.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();let out=got.iter().zip(pw.iter()).map(|(a,b)|a.iter().chain(b.iter()).flat_map(|z|[z.c0.0,z.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();
   writeln!(vectors,"{{\"rows\":{rows},\"n\":{n},\"q\":3,\"k\":{k},\"m\":{m},\"data\":{data:?},\"pads\":{pads:?},\"rho\":{rho:?},\"out\":{out:?}}}").unwrap();
  }
  fixtures+=1;limbs+=2*k*(n+3);
 }
 let(d,r)=fixture(7,5,13,0,&mut seed);
 for budget in [16*4*(7+5),usize::MAX]{
  let s=Rc::new(RefCell::new(Stats::default()));run(&d,7,5,&r,budget,&s).unwrap();let count=s.borrow().ops.len();
  for f in 0..count{let s=Rc::new(RefCell::new(Stats{fail:Some(f),..Stats::default()}));assert!(run(&d,7,5,&r,budget,&s).is_err());assert_eq!(s.borrow().ops.len(),f+1);assert_eq!(s.borrow().live,0);failures+=1;}
 }
 // Fail closed before any op for malformed shape and insufficient budget.
 for bad in [0,767]{let s=Rc::new(RefCell::new(Stats::default()));assert!(run(&d,7,5,&r,bad,&s).is_err());assert!(s.borrow().ops.is_empty());checks+=1;}
 let s=Rc::new(RefCell::new(Stats::default()));assert!(run(&d,7,5,&[vec![Fp2::ONE;6]],usize::MAX,&s).is_err());assert!(s.borrow().ops.is_empty());checks+=1;
 for args in [(usize::MAX,1,5),(1,usize::MAX,5),(1,0,1)]{assert!(plan(args.0,args.1,args.2,usize::MAX).is_err());checks+=1;}
 // A full-rho overflow may safely fall back when the max4 request fits.
 let p=plan(1,1,usize::MAX,128).unwrap();assert_eq!(p.mode,Mode::Serial);assert_eq!(p.scratch,128);checks+=1;
 let want=reference(&d,7,5,&r);
 let mut reordered=r.clone();reordered.swap(0,12);assert_ne!(want,reference(&d,7,5,&reordered));checks+=1;
 let mut missing=r.clone();missing.pop();assert_ne!(want,reference(&d,7,5,&missing));checks+=1;
 let mut stale=r.clone();for g in 4..13{stale[g]=r[g%4].clone();}assert_ne!(want,reference(&d,7,5,&stale));checks+=1;
 let mut swapped=r.clone();for z in &mut swapped[0]{std::mem::swap(&mut z.c0,&mut z.c1);}assert_ne!(want,reference(&d,7,5,&swapped));checks+=1;
 for row in [4,5,6]{let mut changed=d.clone();changed[row*5]=changed[row*5].add(Fp::ONE);assert_ne!(want,reference(&changed,7,5,&r));checks+=1;}
 let(d2,r2)=fixture(7,5,13,0,&mut seed);let s=Rc::new(RefCell::new(Stats::default()));let got=run(&d2,7,5,&r2,usize::MAX,&s).unwrap();assert_ne!(want,got);assert_eq!(got,reference(&d2,7,5,&r2));assert_eq!(s.borrow().live,0);checks+=1;
 println!("{{\"status\":\"PASS\",\"seed\":202610300541,\"fixtures\":{fixtures},\"budget_checks_and_controls\":{checks},\"scalar_limbs_per_budget_including_synthetic_pads\":{limbs},\"injected_failures\":{failures},\"exported_public_vectors\":16,\"full_stack_proofs\":0,\"passes\":0,\"positions\":0}}");
}
