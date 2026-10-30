#![allow(dead_code)]
#[path="native/zkp-core__src__field.rs"] mod field;
use field::{Fp,Fp2};
include!("serial_eq.rs");
mod candidate;
use candidate::{Pair,Weights};
use std::{hint::black_box,time::Instant};
#[derive(Clone,Copy)] enum Cm {A,H,In,Out}
struct Shape {log_cols:usize,endpoint_log_n:usize}
struct Priv {cm:Cm,log:usize,slices:Vec<(usize,Fp2)>,mask_row:usize}
fn row_log(sh:&Shape,cm:Cm)->usize {match cm {Cm::A|Cm::H=>sh.log_cols,_=>sh.endpoint_log_n}}
include!("baseline_mask.rs");
type R=(u64,u64);
const P:u128=0xffffffff00000001;
fn add(a:R,b:R)->R {(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn sub(a:R,b:R)->R {(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn prod(a:u64,b:u64)->u64 {((a as u128*b as u128)%P)as u64}
fn mul(a:R,b:R)->R {add((prod(a.0,b.0),prod(a.0,b.1)),(prod(7,prod(a.1,b.1)),prod(a.1,b.0)))}
fn rr(x:Fp2)->R {(x.c0.0,x.c1.0)}
fn reference(xs:&[Fp],ys:&[Fp],point:&[Fp2])->R {
 let mut v:Vec<R>=xs.iter().zip(ys).map(|(x,y)|(x.0,y.0)).collect();
 for &r in point {let n=v.len()/2;for i in 0..n {v[i]=add(mul(v[i],sub((1,0),rr(r))),mul(v[i+n],rr(r)));}v.truncate(n);}
 assert_eq!(v.len(),1);v[0]
}
fn cube(xs:&[Fp],ys:&[Fp],point:&[Fp2])->R {
 let mut out=(0,0);
 for i in 0..xs.len() {let mut e=(1,0);for (j,&r) in point.iter().enumerate(){e=mul(e,if (i>>(point.len()-1-j))&1==1{rr(r)}else{sub((1,0),rr(r))});}out=add(out,mul(e,(xs[i].0,ys[i].0)));}out
}
fn next(s:&mut u64)->u64 {*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fp(s:&mut u64)->Fp {Fp::new(next(s))}
fn point(log:usize,mode:usize,s:&mut u64)->Vec<Fp2> {(0..log).map(|j|match mode {0=>Fp2::new(fp(s),fp(s)),1=>Fp2::from_base(fp(s)),2=>Fp2::from_u64((j%2)as u64),3=>Fp2::ZERO,4=>Fp2::new(Fp(field::P-1),Fp(field::P-2)),_=>if j==0{Fp2::ZERO}else{Fp2::new(fp(s),fp(s))}}).collect()}
fn main(){
 let start=Instant::now();let mut seed=202610290143u64;
 let (mut fixtures,mut comparisons,mut cube_checks,mut extension_checks,mut controls)=(0usize,0usize,0usize,0usize,0usize);let mut digest=0u64;
 for row in (0usize..=7).chain([13,14]) {for delta in 0..3 {for mode in 0..6 {for cm in [Cm::A,Cm::H,Cm::In,Cm::Out] {
  let sh=Shape{log_cols:row,endpoint_log_n:row.saturating_sub(1)};let logr=row_log(&sh,cm);let n=1<<logr;
  let log=match delta {0=>logr.saturating_sub(2),1=>logr,_=>logr+2};let m=log.min(logr);let size=1<<m;
  let pt=point(log,mode,&mut seed);let tail=&pt[log-m..];let offset=if log<logr{n-size}else{0};
  // Ragged groups exercise tiles of one, two, three, four and one final pair.
  let pairs=5;let mut data:Vec<Fp>=(0..(2*pairs+1)*n).map(|_|fp(&mut seed)).collect();
  let w=Weights::new(tail);
  for fresh in 0..2 {
   if fresh==1 {for j in 0..pairs {data[(2*j+1)*n+offset]=fp(&mut seed);data[(2*j+2)*n+offset]=fp(&mut seed);}}
   let views:Vec<Pair>= (0..pairs).map(|j|Pair{xs:&data[(2*j+1)*n+offset..(2*j+1)*n+offset+size],ys:&data[(2*j+2)*n+offset..(2*j+2)*n+offset+size]}).collect();
   let arms=[w.serial(tail,&views),w.tiled::<1>(tail,&views),w.tiled::<2>(tail,&views),w.tiled::<4>(tail,&views)];
   for j in 0..pairs {
    let p=Priv{cm,log,slices:vec![(offset,Fp2::ONE)],mask_row:2*j+1};let expected=reference(views[j].xs,views[j].ys,tail);
    assert_eq!(rr(baseline_mask_eval(&sh,&p,&data,&pt)),expected);comparisons+=1;
    for arm in &arms {assert_eq!(rr(arm[j]),expected);comparisons+=1;}
    if m<=5 {assert_eq!(cube(views[j].xs,views[j].ys,tail),expected);cube_checks+=1;}
    // Current scalar's same ordered later-zero extension recurrence.
    let e0=rr(Fp2::new(fp(&mut seed),fp(&mut seed)));let e1=rr(Fp2::new(fp(&mut seed),fp(&mut seed)));let old=rr(Fp2::new(fp(&mut seed),fp(&mut seed)));
    let terminal=add(mul(mul(sub((1,0),e0),sub((1,0),e1)),old),mul(mul(e0,sub((1,0),e1)),expected));
    for arm in &arms {let a=Fp2::new(Fp(old.0),Fp(old.1));let b=Fp2::new(Fp(e0.0),Fp(e0.1));let c=Fp2::new(Fp(e1.0),Fp(e1.1));let got=Fp2::ONE.sub(c).mul(Fp2::ONE.sub(b).mul(a).add(b.mul(arm[j])));assert_eq!(rr(got),terminal);extension_checks+=1;}
    digest=digest.rotate_left(9)^expected.0^expected.1;
   }
  }
  fixtures+=1;
 }}}}
 let pt=point(4,0,&mut seed);let w=Weights::new(&pt);let xs:Vec<Fp>=(0..16).map(|_|fp(&mut seed)).collect();let ys:Vec<Fp>=(0..16).map(|_|fp(&mut seed)).collect();let z=vec![Fp::ZERO;16];
 let good=w.tiled::<4>(&pt,&[Pair{xs:&xs,ys:&ys}])[0];
 assert_ne!(good,w.tiled::<4>(&pt,&[Pair{xs:&ys,ys:&xs}])[0]);controls+=1;
 assert_ne!(good,w.tiled::<4>(&pt,&[Pair{xs:&xs,ys:&z}])[0]);controls+=1;
 let mut changed=xs.clone();changed[3]=changed[3].add(Fp::ONE);assert_ne!(good,w.tiled::<4>(&pt,&[Pair{xs:&changed,ys:&ys}])[0]);controls+=1;
 let mut altered=pt.clone();altered[2]=altered[2].add(Fp2::ONE);let mut reversed=pt.clone();reversed.reverse();
 std::panic::set_hook(Box::new(|_|{}));
 for p in [&altered,&reversed] {assert!(std::panic::catch_unwind(||w.tiled::<4>(p,&[Pair{xs:&xs,ys:&ys}])).is_err());controls+=1;}
 for (x,y) in [(&xs[..15],&ys[..]),(&xs[..],&ys[..15])] {assert!(std::panic::catch_unwind(||w.tiled::<4>(&pt,&[Pair{xs:x,ys:y}])).is_err());controls+=1;}
 assert!(w.tiled::<4>(&pt,&[]).is_empty()); // Positive empty-input edge, not a negative control.
 let other=w.tiled::<4>(&pt,&[Pair{xs:&changed,ys:&ys},Pair{xs:&xs,ys:&ys}]);assert_eq!(other[1],good);assert_ne!(other[0],good);controls+=1;
 let eq=eq_table_msb(&pt);let(mut a,mut b,mut c)=(Fp::ZERO,Fp::ZERO,Fp::ZERO);for ((e,x),y) in eq.iter().zip(&xs).zip(&ys) {a=a.add(e.c0.mul(*x));b=b.add(e.c1.mul(*y));c=c.add(Fp::new(e.c0.0.wrapping_add(e.c1.0)).mul(x.add(*y)));}assert_ne!(good,Fp2::new(a.add(b.mul(Fp(7))),c.sub(a).sub(b)));controls+=1;
 let e=Fp2::new(fp(&mut seed),fp(&mut seed));assert_ne!(good,Fp2::ONE.sub(e).mul(good));controls+=1;
 let mut bench=Vec::new();
 for log in [8usize,13,14] {for count in [1usize,2,3,4,6,17,56] {
  let pt=point(log,0,&mut seed);let n=1<<log;let data:Vec<Fp>=(0..2*n*count).map(|_|fp(&mut seed)).collect();
  let views:Vec<Pair>=(0..count).map(|j|Pair{xs:&data[2*j*n..(2*j+1)*n],ys:&data[(2*j+1)*n..(2*j+2)*n]}).collect();
  let mut times:[Vec<u128>;3]=[Vec::new(),Vec::new(),Vec::new()];
  for rep in 0..5 {for step in 0..3 {let arm=(rep+step)%3;let begin=Instant::now();let w=Weights::new(black_box(&pt));let out=match arm{0=>w.serial(black_box(&pt),black_box(&views)),1=>w.tiled::<2>(black_box(&pt),black_box(&views)),_=>w.tiled::<4>(black_box(&pt),black_box(&views))};black_box(out);drop(w);times[arm].push(begin.elapsed().as_nanos());}}
  bench.push(format!("{{\"log\":{},\"pairs\":{},\"serial_ns\":{:?},\"k2_ns\":{:?},\"k4_ns\":{:?}}}",log,count,times[0],times[1],times[2]));
 }}
 println!("{{\"status\":\"PASS\",\"seed\":202610290143,\"fixtures\":{},\"terminal_comparisons\":{},\"direct_cube_checks\":{},\"extension_checks\":{},\"negative_controls\":{},\"digest\":\"{:016x}\",\"elapsed_s\":{},\"bench_scope\":\"one CPU opt1 shared box synthetic components; full public Eq preparation/drop included; no native performance claim\",\"bench\":[{}],\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",fixtures,comparisons,cube_checks,extension_checks,controls,digest,start.elapsed().as_secs_f64(),bench.join(","));
}
