#![allow(dead_code)]
mod field;
use field::{Fp,Fp2,P};
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Mutex;
include!("native_host.rs");
type Digest=[u8;32];
include!("opening_trait.rs");

#[derive(Clone,Copy,Debug,PartialEq,Eq)]
enum Mode { Baseline, Serial, Full }
#[derive(Clone,Copy,Debug,PartialEq,Eq)]
struct Desc { start:usize,k:usize,rho_off:usize,out_off:usize }
fn plan(rows:usize,n:usize,k:usize,mode:Mode)->Result<Vec<Desc>,String>{
 if n==0{return Err("zero columns".into())}
 let mut ds=Vec::new();
 for start in (0..k).step_by(4){
  let w=(k-start).min(4);
  let off=if mode==Mode::Full{start}else{0};
  let rho_off=off.checked_mul(rows).and_then(|x|x.checked_mul(2)).ok_or("rho offset overflow")?;
  let out_off=off.checked_mul(n).and_then(|x|x.checked_mul(2)).ok_or("out offset overflow")?;
  ds.push(Desc{start,k:w,rho_off,out_off});
 }
 // Validate total scratch without allocating it.
 let cap=if mode==Mode::Full{k}else{k.min(4)};
 cap.checked_mul(rows).and_then(|x|x.checked_mul(2)).ok_or("rho length overflow")?;
 cap.checked_mul(n).and_then(|x|x.checked_mul(2)).ok_or("out length overflow")?;
 Ok(ds)
}
#[derive(Default,Debug)]
struct Stats { live:usize,peak:usize,allocs:usize,ops:Vec<&'static str>,h2d:usize,d2h:usize,kernels:usize,fail:Option<usize> }
type Shared=Rc<RefCell<Stats>>;
fn op(s:&Shared,name:&'static str)->Result<(),String>{let mut x=s.borrow_mut();let i=x.ops.len();x.ops.push(name);if x.fail==Some(i){Err(format!("injected {name}@{i}"))}else{Ok(())}}
struct Buffer { v:Vec<u64>,s:Shared }
impl Buffer {
 fn alloc(s:&Shared,len:usize,name:&'static str)->Result<Self,String>{
  op(s,name)?;let mut x=s.borrow_mut();x.live+=len*8;x.peak=x.peak.max(x.live);x.allocs+=1;
  Ok(Self{v:vec![u64::MAX;len],s:s.clone()})
 }
}
impl Drop for Buffer {fn drop(&mut self){self.s.borrow_mut().live-=self.v.len()*8;}}
fn upload(s:&Shared,dst:&mut Buffer,off:usize,rhos:&[Vec<Fp2>])->Result<(),String>{
 op(s,"h2d")?;s.borrow_mut().h2d+=rhos.iter().map(|r|r.len()*16).sum::<usize>();
 let mut p=off;for r in rhos{for z in r{dst.v[p]=z.c0.0;dst.v[p+1]=z.c1.0;p+=2;}}Ok(())
}
fn launch(s:&Shared,data:&[Fp],rows:usize,n:usize,d:Desc,r:&Buffer,o:&mut Buffer)->Result<(),String>{
 op(s,"kernel")?;s.borrow_mut().kernels+=1;
 let before=o.v.clone();
 // Same g-major interleaved limbs and max4 loop as k_fold_rows; scalar native field.
 for j in 0..n{for g in 0..d.k{let mut acc=Fp2::ZERO;
  for i in 0..rows{let p=d.rho_off+2*(g*rows+i);let z=Fp2::new(Fp(r.v[p]),Fp(r.v[p+1]));acc=acc.add(z.mul_base(data[i*n+j]));}
  let p=d.out_off+2*(g*n+j);o.v[p]=acc.c0.0;o.v[p+1]=acc.c1.0;
 }}
 assert_eq!(&before[..d.out_off],&o.v[..d.out_off]);
 assert_eq!(&before[d.out_off+2*d.k*n..],&o.v[d.out_off+2*d.k*n..]);Ok(())
}
fn download(s:&Shared,o:&Buffer,off:usize,k:usize,n:usize)->Result<Vec<Vec<Fp2>>,String>{
 op(s,"d2h")?;s.borrow_mut().d2h+=k*n*16;
 Ok((0..k).map(|g|(0..n).map(|j|{let p=off+2*(g*n+j);Fp2::new(Fp(o.v[p]),Fp(o.v[p+1]))}).collect()).collect())
}
fn run(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>],mode:Mode,s:&Shared)->Result<Vec<Vec<Fp2>>,String>{
 // Research hook validates all shapes. Existing default still validates per chunk.
 if data.len()!=rows.checked_mul(n).ok_or("shape overflow")?||rhos.iter().any(|r|r.len()!=rows){return Err("shape".into())}
 let ds=plan(rows,n,rhos.len(),mode)?;if ds.is_empty(){return Ok(Vec::new())}
 let mut out=Vec::new();
 if mode==Mode::Baseline{
  for d in ds{let mut r=Buffer::alloc(s,2*d.k*rows,"alloc_rho")?;
   upload(s,&mut r,0,&rhos[d.start..d.start+d.k])?;let mut o=Buffer::alloc(s,2*d.k*n,"alloc_out")?;
   launch(s,data,rows,n,d,&r,&mut o)?;out.extend(download(s,&o,0,d.k,n)?);
  }
 }else{
  let cap=if mode==Mode::Full{rhos.len()}else{rhos.len().min(4)};
  let mut r=Buffer::alloc(s,2*cap*rows,"alloc_rho")?;let mut o=Buffer::alloc(s,2*cap*n,"alloc_out")?;
  if mode==Mode::Full{upload(s,&mut r,0,rhos)?;}
  for d in ds{
   if mode==Mode::Serial{upload(s,&mut r,0,&rhos[d.start..d.start+d.k])?;}
   launch(s,data,rows,n,d,&r,&mut o)?;
   if mode==Mode::Serial{out.extend(download(s,&o,0,d.k,n)?);}
  }
  if mode==Mode::Full{out=download(s,&o,0,rhos.len(),n)?;}
 }Ok(out)
}
// Exact additive native trait, extracted from the review-only patch, including Sync.
struct DefaultStore { calls:Mutex<Vec<usize>>,fail_at:Option<usize> }
impl EncodedStore for DefaultStore {
 fn fold_rows(&self,rhos:&[Vec<Fp2>])->Result<Vec<Vec<Fp2>>,String>{assert!(!rhos.is_empty()&&rhos.len()<=4);let mut c=self.calls.lock().unwrap();let i=c.len();c.push(rhos.len());if self.fail_at==Some(i){return Err("store failure".into())}Ok(rhos.to_vec())}
 fn columns(&self,_idx:&[usize])->Result<Vec<Vec<Fp>>,String>{Err("unused columns".into())}
}
fn reference(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>])->Vec<Vec<Fp2>>{
 let p=P as u128;rhos.iter().map(|r|(0..n).map(|j|{let(mut a,mut b)=(0u128,0u128);for i in 0..rows{let v=data[i*n+j].0 as u128;a=(a+(r[i].c0.0 as u128*v)%p)%p;b=(b+(r[i].c1.0 as u128*v)%p)%p;}Fp2::new(Fp(a as u64),Fp(b as u64))}).collect()).collect()
}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fixture(rows:usize,n:usize,k:usize,mode:usize,s:&mut u64)->(Vec<Fp>,Vec<Vec<Fp2>>){
 let d=(0..rows*n).map(|i|Fp(if mode==1{P-1}else if mode==2&&i/n+3<rows{0}else{next(s)%P})).collect();
 let r=(0..k).map(|g|(0..rows).map(|i|if mode==2&&g+1<k&&i+3<rows{Fp2::ZERO}else{Fp2::new(Fp(if mode==3{0}else if mode==1{P-1}else{next(s)%P}),Fp(if mode==1{P-1}else{next(s)%P}))}).collect()).collect();(d,r)
}
fn main(){
 let mut seed=202610300156u64;let(mut cases,mut limbs,mut failures,mut controls)=(0,0,0,0);
 let mut dims=Vec::new();for rows in [0,1,3,33]{for n in [1,7,17]{for k in [0,1,4,5,9,12,13,57,59]{for m in 0..4{dims.push((rows,n,k,m));}}}}
 for (rows,k) in [(3517,57),(3272,12),(3395,59),(3116,13)]{dims.push((rows,3,k,2));}
 for(rows,n,k,m) in dims{
  let(d,r)=fixture(rows,n,k,m,&mut seed);let want=reference(&d,rows,n,&r);assert_eq!(fold_rows_host(&d,rows,n,n,1,&r),want);
  let(pads,_)=fixture(rows,3,k,0,&mut seed);let pw=reference(&pads,rows,3,&r);let ph=fold_rows_host(&pads,rows,3,3,1,&r);assert_eq!(ph,pw);
  for mode in [Mode::Baseline,Mode::Serial,Mode::Full]{let s=Rc::new(RefCell::new(Stats::default()));let got=run(&d,rows,n,&r,mode,&s).unwrap();assert_eq!(got,want);assert_eq!(s.borrow().live,0);
   let x=s.borrow();let b=(k+3)/4;assert_eq!(x.allocs,if mode==Mode::Baseline{2*b}else if k==0{0}else{2});assert_eq!(x.kernels,b);assert_eq!(x.h2d,k*rows*16);assert_eq!(x.d2h,k*n*16);assert_eq!(x.peak,16*(rows+n)*if mode==Mode::Full{k}else{k.min(4)});
   for g in 0..k{let mut z=got[g].clone();z.extend(&ph[g]);let mut w=want[g].clone();w.extend(&pw[g]);assert_eq!(z,w);}
  }
  cases+=1;limbs+=2*k*(n+3);
 }
 // Every synchronous simulated allocation/copy/launch failure must release scratch.
 let(d,r)=fixture(7,5,13,0,&mut seed);
 for mode in [Mode::Baseline,Mode::Serial,Mode::Full]{let s=Rc::new(RefCell::new(Stats::default()));run(&d,7,5,&r,mode,&s).unwrap();let cnt=s.borrow().ops.len();
  for fail in 0..cnt{let s=Rc::new(RefCell::new(Stats{fail:Some(fail),..Stats::default()}));assert!(run(&d,7,5,&r,mode,&s).is_err());assert_eq!(s.borrow().live,0);failures+=1;}
 }
 for k in 0..130{let st=DefaultStore{calls:Mutex::new(Vec::new()),fail_at:None};let r=vec![vec![Fp2::ONE;1];k];assert_eq!(st.fold_rows_opening(&r).unwrap(),r);assert_eq!(*st.calls.lock().unwrap(),r.chunks(4).map(|x|x.len()).collect::<Vec<_>>());controls+=1;}
 let st=DefaultStore{calls:Mutex::new(Vec::new()),fail_at:Some(1)};assert!(st.fold_rows_opening(&vec![vec![Fp2::ONE];13]).is_err());assert_eq!(*st.calls.lock().unwrap(),vec![4,4]);controls+=1;
 for mode in [Mode::Baseline,Mode::Serial,Mode::Full]{let s=Rc::new(RefCell::new(Stats::default()));assert!(run(&d,7,5,&[vec![Fp2::ONE;6]],mode,&s).is_err());assert!(s.borrow().ops.is_empty());assert!(plan(usize::MAX,5,5,mode).is_err());controls+=2;}
 // Value/order/proximity/protected rows and fresh-call negative controls.
 let a=reference(&d,7,5,&r);let mut rr=r.clone();rr.swap(0,12);assert_ne!(a,reference(&d,7,5,&rr));controls+=1;
 let mut rr=r.clone();rr.pop();assert_ne!(a,reference(&d,7,5,&rr));controls+=1;
 for row in [4,5,6]{let mut dd=d.clone();dd[row*5]=dd[row*5].add(Fp::ONE);assert_ne!(a,reference(&dd,7,5,&r));controls+=1;}
 let(d2,r2)=fixture(7,5,13,0,&mut seed);let s=Rc::new(RefCell::new(Stats::default()));let fresh=run(&d2,7,5,&r2,Mode::Serial,&s).unwrap();assert_ne!(a,fresh);assert_eq!(fresh,reference(&d2,7,5,&r2));assert_eq!(s.borrow().live,0);controls+=1;
 use std::io::Write;
 let mut f=std::fs::File::create("public-vectors.jsonl").unwrap();
 let mut vseed=202610300156u64;
 for k in [1,5,9,13]{for m in 0..4{
  let(d,r)=fixture(7,3,k,m,&mut vseed);let(pad,_)=fixture(7,3,k,0,&mut vseed);
  let s=Rc::new(RefCell::new(Stats::default()));let out=run(&d,7,3,&r,Mode::Full,&s).unwrap();let po=fold_rows_host(&pad,7,3,3,1,&r);
  let data=d.iter().map(|x|x.0).collect::<Vec<_>>();let pads=pad.iter().map(|x|x.0).collect::<Vec<_>>();
  let rho=r.iter().map(|v|v.iter().flat_map(|x|[x.c0.0,x.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();
  let result=out.iter().zip(po.iter()).map(|(a,b)|a.iter().chain(b.iter()).flat_map(|x|[x.c0.0,x.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();
  writeln!(f,"{{\"rows\":7,\"n\":3,\"q\":3,\"k\":{k},\"mode\":{m},\"data\":{data:?},\"pads\":{pads:?},\"rho\":{rho:?},\"out\":{result:?}}}").unwrap();
 }}
 println!("{{\"status\":\"PASS\",\"seed\":202610300156,\"fixtures\":{cases},\"modes_per_fixture\":3,\"scalar_limb_outputs_per_mode_including_synthetic_pads\":{limbs},\"injected_failures\":{failures},\"controls\":{controls},\"exported_public_vectors\":16,\"full_stack_proofs\":0,\"passes\":0,\"positions\":0,\"scope\":\"Synthetic synchronous CPU-buffer model plus native scalar fold; no CUDA/PCS/FS/receipts\"}}");
}
