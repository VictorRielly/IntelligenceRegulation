#![allow(dead_code)]
mod field;
use field::{Fp,Fp2,P};
use std::alloc::{GlobalAlloc,Layout,System};
use std::sync::atomic::{AtomicBool,AtomicUsize,Ordering::SeqCst};
use std::io::Write;
use std::hint::black_box;
include!("native_pack.rs");
include!("native_host.rs");

struct Counted;
static ENABLED:AtomicBool=AtomicBool::new(false);
static ALLOCS:AtomicUsize=AtomicUsize::new(0);
static REALLOCS:AtomicUsize=AtomicUsize::new(0);
static TOTAL:AtomicUsize=AtomicUsize::new(0);
static LIVE:AtomicUsize=AtomicUsize::new(0);
static PEAK:AtomicUsize=AtomicUsize::new(0);
fn add(n:usize){TOTAL.fetch_add(n,SeqCst);let x=LIVE.fetch_add(n,SeqCst)+n;PEAK.fetch_max(x,SeqCst);}
// Research allocator instrumentation only. No field-layout casts or custom allocator in proposed patch.
unsafe impl GlobalAlloc for Counted {
    unsafe fn alloc(&self,l:Layout)->*mut u8 {let p=System.alloc(l);if !p.is_null()&&ENABLED.load(SeqCst){ALLOCS.fetch_add(1,SeqCst);add(l.size());}p}
    unsafe fn dealloc(&self,p:*mut u8,l:Layout){if ENABLED.load(SeqCst){LIVE.fetch_sub(l.size(),SeqCst);}System.dealloc(p,l)}
    unsafe fn realloc(&self,p:*mut u8,l:Layout,n:usize)->*mut u8{let q=System.realloc(p,l,n);if !q.is_null()&&ENABLED.load(SeqCst){REALLOCS.fetch_add(1,SeqCst);LIVE.fetch_sub(l.size(),SeqCst);add(n);}q}
}
#[global_allocator] static A:Counted=Counted;
#[derive(Debug,Clone,Copy)] struct Stats{allocs:usize,reallocs:usize,requested:usize,peak:usize,live:usize}
fn measure(f:impl FnOnce()->Vec<u64>)->(Vec<u64>,Stats){
    for x in [&ALLOCS,&REALLOCS,&TOTAL,&LIVE,&PEAK]{x.store(0,SeqCst);}
    ENABLED.store(true,SeqCst);let v=black_box(f());ENABLED.store(false,SeqCst);
    let s=Stats{allocs:ALLOCS.load(SeqCst),reallocs:REALLOCS.load(SeqCst),requested:TOTAL.load(SeqCst),peak:PEAK.load(SeqCst),live:LIVE.load(SeqCst)};(v,s)
}
fn checked_limb_len(k:usize,rows:usize)->Option<usize>{let n=k.checked_mul(rows)?.checked_mul(2)?;if n>isize::MAX as usize/8{None}else{Some(n)}}
fn serial_reference(r:&[Vec<Fp2>])->Vec<u64>{
    let mut bytes=Vec::new();for v in r{for x in v{bytes.extend_from_slice(&x.c0.to_bytes());bytes.extend_from_slice(&x.c1.to_bytes());}}
    bytes.chunks_exact(8).map(|b|u64::from_le_bytes(b.try_into().unwrap())).collect()
}
fn decode(p:&[u64],rows:usize,k:usize)->Vec<Vec<Fp2>>{(0..k).map(|g|(0..rows).map(|i|{let t=2*(g*rows+i);Fp2::new(Fp(p[t]),Fp(p[t+1]))}).collect()).collect()}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fixture(rows:usize,k:usize,mode:usize,s:&mut u64)->Vec<Vec<Fp2>>{
    (0..k).map(|g|(0..rows).map(|i|{
        let a=next(s);let b=next(s);
        let(c,d)=match mode{
            0=>(a%P,b%P),1=>(P-1,P-1),2=>(0,b%P),
            3=>{let x=[0,1,(1u64<<32)-1,1u64<<32,P-2,P-1];(x[(g+i)%6],x[(2*g+i+1)%6])},
            4=>if i+3<rows{(0,0)}else{((g as u64+1)*17+i as u64,(g as u64+1)*31+i as u64)},
            _=>{let x=[P,P+1,u64::MAX];(x[(g+i)%3],x[(g+2*i+1)%3])},
        };Fp2::new(Fp(c),Fp(d))
    }).collect()).collect()
}
fn folded_reference(data:&[Fp],rows:usize,n:usize,r:&[Vec<Fp2>])->Vec<Vec<Fp2>>{
    r.iter().map(|v|(0..n).map(|j|{let(mut a,mut b)=(0u128,0u128);for i in 0..rows{a=(a+(v[i].c0.0 as u128*data[i*n+j].0 as u128)%(P as u128))%(P as u128);b=(b+(v[i].c1.0 as u128*data[i*n+j].0 as u128)%(P as u128))%(P as u128);}Fp2::new(Fp(a as u64),Fp(b as u64))}).collect()).collect()
}
fn main(){
    std::panic::set_hook(Box::new(|_|{}));
    let mut seed=202610300641u64;
    let(mut fixtures,mut limbs,mut folds,mut controls,mut exported)=(0,0,0,0,0);
    let mut vectors=std::fs::File::create("public-vectors.jsonl").unwrap();
    let mut counts=std::fs::File::create("allocation-counts.jsonl").unwrap();
    for rows in [0,1,3,7,33,257,3517]{for k in 1..=4{for mode in 0..6{
        let r=fixture(rows,k,mode,&mut seed);
        let want=serial_reference(&r);
        let(b,bs)=measure(||pack_native(black_box(&r),black_box(rows)));
        let(c,cs)=measure(||pack_direct(black_box(&r),black_box(rows)));
        assert_eq!(b,want);assert_eq!(c,want);assert_eq!(decode(&c,rows,k),r);
        let nonzero=usize::from(rows>0);
        assert_eq!(bs.allocs,nonzero*(k+1));assert_eq!(cs.allocs,nonzero);
        assert_eq!(bs.reallocs,0);assert_eq!(cs.reallocs,0);
        assert_eq!(bs.requested,32*k*rows);assert_eq!(cs.requested,16*k*rows);
        assert_eq!(bs.peak,16*rows*(k+1));assert_eq!(cs.peak,16*k*rows);
        assert_eq!(bs.live,16*k*rows);assert_eq!(cs.live,16*k*rows);
        assert!(c.capacity()>=2*k*rows);
        writeln!(counts,"{{\"rows\":{rows},\"k\":{k},\"mode\":{mode},\"baseline_allocs\":{},\"direct_allocs\":{},\"baseline_requested_B\":{},\"direct_requested_B\":{},\"baseline_peak_B\":{},\"direct_peak_B\":{},\"direct_capacity_limbs\":{}}}",bs.allocs,cs.allocs,bs.requested,cs.requested,bs.peak,cs.peak,c.capacity()).unwrap();
        if mode<5 && rows<=257 {
            // Last three columns are synthetic protected-tail stand-ins, not PCS-generated pads.
            let n=8;let data=(0..rows*n).map(|_|Fp(next(&mut seed)%P)).collect::<Vec<_>>();
            let rr=decode(&c,rows,k);let out=fold_rows_host(&data,rows,n,n,1,&rr);
            let reference=folded_reference(&data,rows,n,&r);assert_eq!(out,reference);folds+=1;
            if rows==7||rows==33 {
                let data=data.iter().map(|x|x.0).collect::<Vec<_>>();
                let rho=r.iter().map(|v|v.iter().flat_map(|x|[x.c0.0,x.c1.0]).collect::<Vec<_>>()).collect::<Vec<_>>();
                let out=out.iter().flat_map(|v|v.iter().flat_map(|x|[x.c0.0,x.c1.0])).collect::<Vec<_>>();
                writeln!(vectors,"{{\"rows\":{rows},\"n\":{n},\"k\":{k},\"mode\":{mode},\"rho\":{rho:?},\"packed\":{c:?},\"data\":{data:?},\"out\":{out:?}}}").unwrap();exported+=1;
            }
        }
        fixtures+=1;limbs+=c.len();
    }}}
    // Refusal controls for pack-stage vector counts and malformed lengths; no CUDA/init check here.
    for k in [0,5]{let r=fixture(7,k,0,&mut seed);assert!(std::panic::catch_unwind(||pack_native(&r,7)).is_err());assert!(std::panic::catch_unwind(||pack_direct(&r,7)).is_err());controls+=1;}
    for bad in 0..4{let mut r=fixture(7,4,0,&mut seed);r[bad].pop();assert!(std::panic::catch_unwind(||pack_native(&r,7)).is_err());assert!(std::panic::catch_unwind(||pack_direct(&r,7)).is_err());controls+=1;}
    let r=fixture(7,4,0,&mut seed);let want=pack_direct(&r,7);
    let mut swapped=r.clone();for v in &mut swapped{for x in v{std::mem::swap(&mut x.c0,&mut x.c1);}}assert_ne!(want,pack_direct(&swapped,7));controls+=1;
    let mut reordered=r.clone();reordered.swap(0,3);assert_ne!(want,pack_direct(&reordered,7));controls+=1;
    let mut missing=r.clone();missing.pop();assert_ne!(want,pack_direct(&missing,7));controls+=1;
    let mut fresh=r.clone();fresh[3][6].c1=Fp::new(fresh[3][6].c1.0.wrapping_add(1));assert_ne!(want,pack_direct(&fresh,7));assert_eq!(want,pack_direct(&r,7));controls+=1;
    let mut split=want.clone();for g in 0..4{for i in 0..7{split[g*14+i]=r[g][i].c0.0;split[g*14+7+i]=r[g][i].c1.0;}}assert_ne!(want,split);controls+=1;
    let mut plans=std::fs::File::create("public-length-plans.jsonl").unwrap();
    for k in [0,1,4,5,57,usize::MAX/16,usize::MAX]{for rows in [0,1,7,3517,usize::MAX/16,usize::MAX/2,usize::MAX]{let v=checked_limb_len(k,rows);writeln!(plans,"{{\"k\":{k},\"rows\":{rows},\"limbs\":{}}}",v.map(|x|x.to_string()).unwrap_or("null".into())).unwrap();}}
    let summary=format!("{{\"status\":\"PASS\",\"seed\":202610300641,\"fixtures\":{fixtures},\"compared_limbs\":{limbs},\"native_host_fold_cases\":{folds},\"negative_controls\":{controls},\"exported_vectors\":{exported},\"length_plans\":49,\"full_stack_proofs\":0,\"passes\":0,\"positions\":0}}");
    std::fs::write("rust-result.json",format!("{summary}\n")).unwrap();println!("{summary}");
}
