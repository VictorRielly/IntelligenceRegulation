// Local synthetic C ABI. No transcript, mask, proof or private data.
use sumcheck::{ClosureRounds, SumcheckRounds, grouped::{EqualityGroup,GroupedEqRounds}};
use std::cell::Cell;
thread_local! {static TRACK:Cell<bool>=const{Cell::new(false)};static COUNTS:Cell<[u64;6]>=const{Cell::new([0;6])};}
fn metric(i:usize) {TRACK.with(|t|if t.get(){COUNTS.with(|c|{let mut a=c.get();a[i]+=1;c.set(a);})});}
unsafe fn read(p:*const u64,n:usize)->Vec<Fp2> {std::slice::from_raw_parts(p,2*n).chunks_exact(2).map(|w|Fp2::new(Fp(w[0]),Fp(w[1]))).collect()}
unsafe fn write(out:*mut u64,v:&[Fp2]) {for (i,z) in v.iter().enumerate(){*out.add(2*i)=z.c0.0;*out.add(2*i+1)=z.c1.0;}}

#[no_mangle]
pub unsafe extern "C" fn drive(out:*mut u64,counts:*mut u64,ns:*mut u64,tabs:*const u64,conf:*const u64,points:*const u64,challenges:*const u64,n:usize,hh:u32,gg:u32,pad:u32,nlk:usize,mode:u32,track:u32) {
 let p=read(points,3*n);let rho=read(challenges,n);let v=read(conf,38);
 let flat=read(tabs,21*(1<<n));let mut tables:Vec<Vec<Fp2>>=flat.chunks_exact(1<<n).map(|x|x.to_vec()).collect();
 let f=full(&v,hh,gg,pad!=0,nlk);let b=brackets(&v,hh,gg,pad!=0,nlk);
 TRACK.with(|c|c.set(track!=0));COUNTS.with(|c|c.set([0;6]));
 let t=std::time::Instant::now();let mut result=Vec::new();
 if mode<2 {
  let poly=|r:&[Fp2]|{metric(3);f(r)};
  let mut ev=ClosureRounds::new(&mut tables,4,poly);if mode==1 {ev=ev.recover_one(None);}
  for j in 0..n {result.extend(ev.round(j));ev.fold(rho[j]);}result.extend(ev.finals());
 } else {
  let groups=(0..3).map(|g|EqualityGroup{point:p[g*n..(g+1)*n].to_vec(),start:0,
   bracket_degree:if g==0 {if mode==3 {2}else{3}}else if pad!=0 && mode!=4 {2}else{1}}).collect();
  let bracket=|g:usize,r:&[Fp2]|{metric(g);b(g,r)};
  let mut ev=GroupedEqRounds::new(&mut tables,4,groups,bracket);if mode==5 {ev.seed_bad();}
  for j in 0..n {result.extend(ev.round(j));ev.fold(rho[j]);}result.extend(ev.finals());
 }
 *ns=t.elapsed().as_nanos() as u64;write(out,&result);COUNTS.with(|c|for (i,z) in c.get().iter().enumerate(){*counts.add(i)=*z});TRACK.with(|c|c.set(false));
}

#[no_mangle]
pub unsafe extern "C" fn evals(out:*mut u64,row:*const u64,conf:*const u64,hh:u32,gg:u32,pad:u32,nlk:usize) {
 let r=read(row,21);let v=read(conf,38);let f=full(&v,hh,gg,pad!=0,nlk);let b=brackets(&v,hh,gg,pad!=0,nlk);
 write(out,&[f(&r),b(0,&r),b(1,&r),b(2,&r)]);
}
