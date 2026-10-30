#![allow(dead_code)]
#[path="native/zkp-core__src__field.rs"] mod field;
use field::{Fp,Fp2};
include!("serial_eq.rs");
mod candidate;
use candidate::{PublicWeights,PreparedWeights};
use std::{hint::black_box, time::Instant};

#[derive(Clone,Copy)] enum Cm { A,H,In,Out }
struct Shape { log_cols:usize, endpoint_log_n:usize }
struct Priv { cm:Cm,log:usize,slices:Vec<(usize,Fp2)>,mask_row:usize }
fn row_log(sh:&Shape,cm:Cm)->usize { match cm { Cm::A|Cm::H=>sh.log_cols,_=>sh.endpoint_log_n } }
include!("baseline_mask.rs");

type R=(u64,u64);
const P:u128=0xffffffff00000001;
fn ra(a:R,b:R)->R { (((a.0 as u128+b.0 as u128)%P) as u64,((a.1 as u128+b.1 as u128)%P) as u64) }
fn rs(a:R,b:R)->R { (((P+a.0 as u128-b.0 as u128)%P) as u64,((P+a.1 as u128-b.1 as u128)%P) as u64) }
fn pm(a:u64,b:u64)->u64 { ((a as u128*b as u128)%P) as u64 }
fn rm(a:R,b:R)->R {
    ra((pm(a.0,b.0),pm(a.0,b.1)),(pm(7,pm(a.1,b.1)),pm(a.1,b.0)))
}
fn rr(a:Fp2)->R { (a.c0.0,a.c1.0) }
fn reference(xs:&[Fp],ys:&[Fp],point:&[Fp2])->R {
    // Independent MSB table folding, schoolbook extension arithmetic and % p.
    let mut v:Vec<R>=xs.iter().zip(ys).map(|(x,y)|(x.0,y.0)).collect();
    for &r in point {
        let half=v.len()/2;
        for j in 0..half { v[j]=ra(rm(v[j],rs((1,0),rr(r))),rm(v[j+half],rr(r))); }
        v.truncate(half);
    }
    assert_eq!(v.len(),1);v[0]
}
fn direct_eq(point:&[Fp2],index:usize)->R {
    let mut e=(1,0);
    for (j,&r) in point.iter().enumerate() {
        e=rm(e,if (index>>(point.len()-1-j))&1==1 {rr(r)} else {rs((1,0),rr(r))});
    } e
}
fn next(seed:&mut u64)->u64 { *seed^=*seed<<13;*seed^=*seed>>7;*seed^=*seed<<17;*seed }
fn fp(seed:&mut u64)->Fp { Fp::new(next(seed)) }
fn point(log:usize,mode:usize,seed:&mut u64)->Vec<Fp2> {
    (0..log).map(|j|match mode {
        0=>Fp2::new(fp(seed),fp(seed)),
        1=>Fp2::from_base(fp(seed)),
        2=>Fp2::from_u64((j%2) as u64),
        3=>Fp2::ZERO,
        4=>Fp2::new(Fp(field::P-1),Fp(field::P-2)),
        _=>if j==0 {Fp2::ZERO} else {Fp2::new(fp(seed),fp(seed))},
    }).collect()
}
fn window<'a>(sh:&Shape,p:&Priv,data:&'a[Fp])->(&'a[Fp],&'a[Fp]) {
    let logn=row_log(sh,p.cm); let n=1<<logn;let logm=p.log.min(logn);
    let offset=if p.log<logn {p.slices[0].0 % n} else {0};let size=1<<logm;
    (&data[p.mask_row*n+offset..p.mask_row*n+offset+size],&data[(p.mask_row+1)*n+offset..(p.mask_row+1)*n+offset+size])
}
fn main() {
    let start=Instant::now();let mut seed=202610290141u64;
    let (mut fixtures,mut comparisons,mut direct_values,mut negative)=(0usize,0usize,0usize,0usize);
    let mut digest=0u64;
    for row_log in (0usize..=8).chain([13,14]) {
        for private_log in [row_log.saturating_sub(2),row_log,row_log+2] {
            for mode in 0..6 {
                let sh=Shape{log_cols:row_log,endpoint_log_n:row_log.saturating_sub(1)};
                for cm in [Cm::A,Cm::H,Cm::In,Cm::Out] {
                    let n=1<<self::row_log(&sh,cm);let logm=private_log.min(self::row_log(&sh,cm));
                    let offset=if private_log<self::row_log(&sh,cm){n-(1<<logm)}else{0};
                    let p=Priv{cm,log:private_log,slices:vec![(offset,Fp2::ONE)],mask_row:1};
                    let pt=point(private_log,mode,&mut seed);let tail=&pt[private_log-logm..];
                    let mut data:Vec<Fp>=(0..4*n).map(|_|fp(&mut seed)).collect();
                    let (xs,ys)=window(&sh,&p,&data);
                    let expected=reference(xs,ys,tail);
                    let cached=PublicWeights::new(tail);let prepared=PreparedWeights::new(tail);
                    assert_eq!(prepared.sum_payload_bytes(),8*(1<<logm));
                    for got in [baseline_mask_eval(&sh,&p,&data,&pt),cached.dot(tail,xs,ys),prepared.dot(tail,xs,ys)] {
                        assert_eq!(rr(got),expected);comparisons+=1;
                    }
                    if logm<=6 {
                        let eq=eq_table_msb(tail);
                        for (j,&e) in eq.iter().enumerate() {assert_eq!(rr(e),direct_eq(tail,j));direct_values+=1;}
                    }
                    // Public preparation must not cache private rows or results.
                    data[p.mask_row*n+offset]=fp(&mut seed);
                    data[(p.mask_row+1)*n+offset]=fp(&mut seed);
                    let (xs2,ys2)=window(&sh,&p,&data);let expected2=reference(xs2,ys2,tail);
                    assert_eq!(rr(prepared.dot(tail,xs2,ys2)),expected2);comparisons+=1;
                    digest=digest.rotate_left(7)^expected2.0^expected2.1;fixtures+=1;
                }
            }
        }
    }
    // Deterministic controls selected away from degenerate Boolean cases.
    let pt=point(4,0,&mut seed);let prep=PreparedWeights::new(&pt);
    let xs:Vec<Fp>=(0..16).map(|_|fp(&mut seed)).collect();let ys:Vec<Fp>=(0..16).map(|_|fp(&mut seed)).collect();
    let correct=prep.dot(&pt,&xs,&ys);
    assert_ne!(correct,prep.dot(&pt,&ys,&xs));negative+=1;
    let mut changed=xs.clone();changed[3]=changed[3].add(Fp::ONE);
    assert_ne!(correct,prep.dot(&pt,&changed,&ys));negative+=1;
    let mut changed_pt=pt.clone();changed_pt[2]=changed_pt[2].add(Fp2::ONE);
    std::panic::set_hook(Box::new(|_|{}));
    assert!(std::panic::catch_unwind(||prep.dot(&changed_pt,&xs,&ys)).is_err());negative+=1;
    let mut rev=pt.clone();rev.reverse();
    assert!(std::panic::catch_unwind(||prep.dot(&rev,&xs,&ys)).is_err());negative+=1;
    assert!(std::panic::catch_unwind(||prep.dot(&pt,&xs[..15],&ys)).is_err());negative+=1;
    assert!(std::panic::catch_unwind(||prep.dot(&pt,&xs,&ys[..15])).is_err());negative+=1;
    let eq=eq_table_msb(&pt);let mut raw=(Fp::ZERO,Fp::ZERO,Fp::ZERO);
    for ((e,x),y) in eq.iter().zip(&xs).zip(&ys) {
        raw.0=raw.0.add(e.c0.mul(*x));raw.1=raw.1.add(e.c1.mul(*y));
        raw.2=raw.2.add(Fp::new(e.c0.0.wrapping_add(e.c1.0)).mul(x.add(*y)));
    }
    assert_ne!(correct,Fp2::new(raw.0.add(raw.1.mul(Fp(7))),raw.2.sub(raw.0).sub(raw.1)));negative+=1;
    assert_ne!(rr(correct),(pm(7,correct.c0.0),correct.c1.0));negative+=1;
    assert_ne!(correct,Fp2::new(correct.c0,correct.c1.add(Fp::ONE)));negative+=1;
    let zero=vec![Fp::ZERO;16];assert_ne!(correct,prep.dot(&pt,&xs,&zero));negative+=1;
    // Tight, synthetic component diagnostics. All per-group preparation included.
    let mut rows=Vec::new();
    for log in [8usize,13,14] {for pairs in [1usize,2,6,17] {
        let pt=point(log,0,&mut seed);let n=1<<log;
        let data:Vec<Fp>=(0..2*n*pairs).map(|_|fp(&mut seed)).collect();
        let mut ordinary=Vec::new();let mut prepared=Vec::new();
        for rep in 0..5 {for arm in if rep%2==0 {[0,1]} else {[1,0]} {
            let begin=Instant::now();let mut sum=Fp2::ZERO;
            if arm==0 {
                let w=PublicWeights::new(black_box(&pt));
                for i in 0..pairs {sum=sum.add(w.dot(black_box(&pt),black_box(&data[2*i*n..(2*i+1)*n]),black_box(&data[(2*i+1)*n..(2*i+2)*n])));}
            } else {
                let w=PreparedWeights::new(black_box(&pt));
                for i in 0..pairs {sum=sum.add(w.dot(black_box(&pt),black_box(&data[2*i*n..(2*i+1)*n]),black_box(&data[(2*i+1)*n..(2*i+2)*n])));}
            }
            black_box(sum);let elapsed=begin.elapsed().as_nanos();
            if arm==0 {ordinary.push(elapsed)} else {prepared.push(elapsed)};
        }}
        rows.push(format!("{{\"row_log\":{},\"pairs\":{},\"cached_paired3_group_ns\":{:?},\"prepared_group_ns\":{:?}}}",log,pairs,ordinary,prepared));
    }}
    println!("{{\"status\":\"PASS\",\"seed\":202610290141,\"fixtures\":{},\"terminal_comparisons\":{},\"direct_eq_values\":{},\"negative_controls\":{},\"diagnostic_digest\":\"{:016x}\",\"elapsed_s\":{},\"bench_scope\":\"synthetic component; fresh Eq preparation and drop included; shared box; not native timing\",\"bench\":[{}],\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",fixtures,comparisons,direct_values,negative,digest,start.elapsed().as_secs_f64(),rows.join(","));
}
