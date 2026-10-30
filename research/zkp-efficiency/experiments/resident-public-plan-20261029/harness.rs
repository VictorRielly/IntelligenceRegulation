#![allow(dead_code)]
#[path="native/zkp-core__src__field.rs"] mod field;
use field::{Fp,Fp2};
include!("serial_eq.rs");
mod candidate;
use candidate::Plan;
use std::{hint::black_box,time::Instant};
#[derive(Clone,Copy)] enum Cm{A,H,In,Out}
#[derive(Clone,Debug)] enum Coord{Rho(usize),Flip(usize),Fixed(Fp2)}
#[derive(Clone)] struct Priv{cm:Cm,slices:Vec<(usize,Fp2)>,log:usize,coords:Vec<Coord>,mask_row:usize,ext_round:usize}
struct Shape{log_cols:usize,endpoint_log_n:usize}
fn row_log(sh:&Shape,cm:Cm)->usize{match cm{Cm::A|Cm::H=>sh.log_cols,_=>sh.endpoint_log_n}}
include!("native_priv_table.rs");
include!("native_claim_point.rs");
include!("native_mask_eval.rs");
type R=(u64,u64);const P:u128=0xffffffff00000001;
fn add(a:R,b:R)->R{(((a.0 as u128+b.0 as u128)%P)as u64,((a.1 as u128+b.1 as u128)%P)as u64)}
fn sub(a:R,b:R)->R{(((P+a.0 as u128-b.0 as u128)%P)as u64,((P+a.1 as u128-b.1 as u128)%P)as u64)}
fn prod(a:u64,b:u64)->u64{((a as u128*b as u128)%P)as u64}
fn mul(a:R,b:R)->R{add((prod(a.0,b.0),prod(a.0,b.1)),(prod(7,prod(a.1,b.1)),prod(a.1,b.0)))}
fn rr(x:Fp2)->R{(x.c0.0,x.c1.0)}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fp(s:&mut u64)->Fp{Fp::new(next(s))}
fn fp2(s:&mut u64)->Fp2{Fp2::new(fp(s),fp(s))}
// Independent literal coordinate walk, schoolbook u128 modular arithmetic.
// No native Eq implementation or candidate half-map used here.
fn reference(p:&Priv,data:&[Fp],nv:usize)->Vec<R>{
 let mut out=vec![(0,0);1<<nv];let mut used=0;
 for c in &p.coords{if let Coord::Rho(k)|Coord::Flip(k)=c{used|=1<<(nv-1-*k)}}
 for idx in 0..1<<p.log{
  let(mut dest,mut w)=(0,(1,0));
  for(j,c)in p.coords.iter().enumerate(){let bit=(idx>>(p.log-1-j))&1;match c{
   Coord::Rho(k)=>dest|=bit<<(nv-1-*k),Coord::Flip(k)=>dest|=(1-bit)<<(nv-1-*k),
   Coord::Fixed(f)=>w=mul(w,if bit==1{rr(*f)}else{sub((1,0),rr(*f))}),
  }}
  let mut v=(0,0);for(off,c)in &p.slices{v=add(v,mul(rr(*c),(data[*off+idx].0,0)));}out[dest]=add(out[dest],mul(w,v));
 }
 for x in 0..out.len(){if x&!used!=0{out[x]=out[x&used];}}out
}
fn mask_reference(p:&Priv,data:&[Fp],point:&[Fp2],row_log:usize)->R{
 let m=p.log.min(row_log);let n=1<<row_log;let c0=if p.log<row_log{p.slices[0].0%n}else{0};
 let mut v:Vec<R>=(0..1<<m).map(|i|(data[p.mask_row*n+c0+i].0,data[(p.mask_row+1)*n+c0+i].0)).collect();
 for &r in &point[p.log-m..]{let half=v.len()/2;for i in 0..half{v[i]=add(mul(sub((1,0),rr(r)),v[i]),mul(rr(r),v[i+half]));}v.truncate(half);}v[0]
}
fn fixture(log:usize,pattern:usize,kind:usize,s:&mut u64)->(Priv,usize){
 let mut coords=Vec::new();let mut moving=0;
 for j in 0..log{let c=match pattern{
  0=>Coord::Rho(j),1=>Coord::Rho(log-1-j),2=>if j%2==0{Coord::Flip(j)}else{Coord::Rho(j)},
  3=>if j%2==0{Coord::Fixed(fp2(s))}else{let k=moving;moving+=1;Coord::Rho(k)},
  4=>Coord::Fixed(fp2(s)),5=>if j%2==0{Coord::Rho(0)}else{Coord::Flip(0)},
  _=>if j<log/2{Coord::Fixed(fp2(s))}else{let k=moving;moving+=1;Coord::Flip(k)},
 };coords.push(c);}
 let nv=match pattern{0|1|2=>log,3|6=>moving+1,_=>2};
 let size=1<<log;let slices=match kind{0=>vec![(0,Fp2::ONE)],1=>vec![(3,Fp2::ONE),(size+3,Fp2::U)],_=>vec![(1,fp2(s)),(size+1,fp2(s))]};
 (Priv{cm:Cm::A,slices,log,coords,mask_row:1,ext_round:0},nv)
}
fn refresh(p:&mut Priv,s:&mut u64){for c in &mut p.coords{if let Coord::Fixed(f)=c{*f=fp2(s);}}}
fn main(){
 let begin=Instant::now();let mut seed=202610290144u64;
 let(mut fixtures,mut passes,mut comparisons,mut words,mut masks,mut controls,mut digest)=(0,0,0,0,0,0,0u64);
 for log in (0..=7usize).chain([13,14]){for pattern in 0..7{for kind in 0..3{
  let(p0,nv)=fixture(log,pattern,kind,&mut seed);let plan=Plan::new(13,&p0,nv);
  for count in [1,2,4,8]{let mut p=p0.clone();for pass in 0..count{
   refresh(&mut p,&mut seed);
   for c in &mut p.coords{if let Coord::Fixed(f)=c{*f=match pass%6{0=>Fp2::ZERO,1=>Fp2::ONE,2=>Fp2::from_base(fp(&mut seed)),3=>Fp2::new(Fp(field::P-1),Fp(field::P-2)),_=>*f};}}
   if kind==2{for(_,coef)in &mut p.slices{*coef=fp2(&mut seed);}}
   if kind==1{let off=if pass%2==0{3}else{1};p.slices[0].0=off;p.slices[1].0=(1<<log)+off;}
   let data:Vec<Fp>=(0..2*(1<<log)+4).map(|_|fp(&mut seed)).collect();
   let expected=reference(&p,&data,nv);let native=native_priv_table(&p,&data,nv);let got=plan.execute(13,&p,&data,nv).unwrap();
   assert_eq!(native,got);assert_eq!(got.iter().copied().map(rr).collect::<Vec<_>>(),expected);comparisons+=2;words+=got.len();passes+=1;
   let row=log.min(7);let sh=Shape{log_cols:row,endpoint_log_n:row};
   let maskdata:Vec<Fp>=(0..4*(1<<row)).map(|_|fp(&mut seed)).collect();
   let mut pm=p.clone();pm.slices=vec![(0,Fp2::ONE)];let rho:Vec<Fp2>=(0..nv).map(|_|fp2(&mut seed)).collect();let point=native_claim_point(&pm,&rho);
   let mask=native_mask_eval(&sh,&pm,&maskdata,&point);assert_eq!(rr(mask),mask_reference(&pm,&maskdata,&point,row));masks+=1;
   // Compare the ordered two-extension recurrence with an independent oracle.
   let a=fp2(&mut seed);let e=fp2(&mut seed);let later=fp2(&mut seed);
   let v=Fp2::ONE.sub(later).mul(Fp2::ONE.sub(e).mul(a).add(e.mul(mask)));
   assert_eq!(rr(v),mul(sub((1,0),rr(later)),add(mul(sub((1,0),rr(e)),rr(a)),mul(rr(e),rr(mask)))));comparisons+=1;
   for x in got{digest=digest.rotate_left(7)^x.c0.0^x.c1.0;}
  }}fixtures+=1;
 }}}
 // Mutated geometry is refused; fresh Fixed values and slice coefficients are accepted.
 let(mut p,nv)=fixture(6,3,1,&mut seed);let plan=Plan::new(13,&p,nv);let data:Vec<Fp>=(0..132).map(|_|fp(&mut seed)).collect();
 assert!(plan.execute(14,&p,&data,nv).is_err());controls+=1;
 assert!(plan.execute(13,&p,&data,nv+1).is_err());controls+=1;
 let mut changed=p.clone();changed.coords.reverse();assert!(plan.execute(13,&changed,&data,nv).is_err());controls+=1;
 changed=p.clone();changed.coords[1]=Coord::Flip(0);assert!(plan.execute(13,&changed,&data,nv).is_err());controls+=1;
 changed=p.clone();changed.log+=1;assert!(plan.execute(13,&changed,&data,nv).is_err());controls+=1;
 let old=plan.execute(13,&p,&data,nv).unwrap();refresh(&mut p,&mut seed);let fresh=plan.execute(13,&p,&data,nv).unwrap();assert_ne!(old,fresh);controls+=1;
 let mut data2=data.clone();let read_off=p.slices[0].0;data2[read_off]=data2[read_off].add(Fp::ONE);assert_ne!(fresh,plan.execute(13,&p,&data2,nv).unwrap());controls+=1;
 p.slices[1].1=Fp2::ONE;assert_ne!(fresh,plan.execute(13,&p,&data,nv).unwrap());controls+=1;
 p.slices.swap(0,1);assert_eq!(plan.execute(13,&p,&data,nv).unwrap(),native_priv_table(&p,&data,nv));
 // Reusing a prior pass's mask terminal is detectably wrong with fresh point/data.
 let row=6;let sh=Shape{log_cols:row,endpoint_log_n:row};let rho:Vec<Fp2>=(0..nv).map(|_|fp2(&mut seed)).collect();let pt=native_claim_point(&p,&rho);
 let md:Vec<Fp>=(0..4*(1<<row)).map(|_|fp(&mut seed)).collect();let oldm=native_mask_eval(&sh,&p,&md,&pt);let mut newp=pt.clone();newp[0]=newp[0].add(Fp2::ONE);
 assert_ne!(oldm,native_mask_eval(&sh,&p,&md,&newp));controls+=1;
 let mut md2=md.clone();md2[1<<row]=md2[1<<row].add(Fp::ONE);assert_ne!(oldm,native_mask_eval(&sh,&p,&md2,&pt));controls+=1;
 let mut bench=Vec::new();
 for log in [8usize,14,17]{for pattern in [0,2,3]{for count in [1,2,4,8]{
  let(p0,nv)=fixture(log,pattern,0,&mut seed);let mut ps=Vec::new();let mut ds=Vec::new();
  for _ in 0..count{let mut p=p0.clone();refresh(&mut p,&mut seed);ps.push(p);ds.push((0..(1<<log)).map(|_|fp(&mut seed)).collect::<Vec<_>>());}
  let(mut nt,mut ct,mut setup)=(Vec::new(),Vec::new(),Vec::new());
  for rep in 0..3{for step in 0..2{let arm=(rep+step)%2;let t=Instant::now();
   if arm==0{for(p,d)in ps.iter().zip(&ds){black_box(native_priv_table(black_box(p),black_box(d),nv));}nt.push(t.elapsed().as_nanos());}
   else{let plan=Plan::new(13,black_box(&ps[0]),nv);setup.push(t.elapsed().as_nanos());for(p,d)in ps.iter().zip(&ds){black_box(plan.execute(13,black_box(p),black_box(d),nv).unwrap());}drop(plan);ct.push(t.elapsed().as_nanos());}
  }}
  let plan=Plan::new(13,&ps[0],nv);bench.push(format!("{{\"log\":{},\"pattern\":{},\"passes\":{},\"plan_payload_bytes\":{},\"native_ns\":{:?},\"planned_total_ns\":{:?},\"plan_startup_ns\":{:?}}}",log,pattern,count,plan.payload_bytes(),nt,ct,setup));
 }}}
 println!("{{\"status\":\"PASS\",\"seed\":202610290144,\"fixtures\":{},\"synthetic_pass_replays\":{},\"comparisons\":{},\"output_words_compared\":{},\"fresh_mask_checks\":{},\"negative_controls\":{},\"digest\":\"{:016x}\",\"elapsed_s\":{},\"bench_scope\":\"CPU opt1 shared-machine helper diagnostic only; setup,lookup validation,execution and drop included; inputs/challenges synthetic and prepared outside timed region; not model/proof time\",\"bench\":[{}],\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",fixtures,passes,comparisons,words,masks,controls,digest,begin.elapsed().as_secs_f64(),bench.join(","));
}
