#![allow(dead_code)]
#[path="native/zkp-core__src__field.rs"] mod field;
#[path="native/zkp-core__src__ntt.rs"] mod ntt;
use field::{Fp, P};
use ntt::NttTables;
use std::mem::MaybeUninit;
use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};
static ALLOCS: AtomicUsize = AtomicUsize::new(0);
static BYTES: AtomicUsize = AtomicUsize::new(0);
struct Counter;
unsafe impl GlobalAlloc for Counter {
    unsafe fn alloc(&self, l: Layout) -> *mut u8 {
        ALLOCS.fetch_add(1, Ordering::Relaxed); BYTES.fetch_add(l.size(), Ordering::Relaxed);
        System.alloc(l)
    }
    unsafe fn dealloc(&self, p: *mut u8, l: Layout) { System.dealloc(p,l); }
}
#[global_allocator] static GLOBAL: Counter = Counter;
include!("baseline_row.rs");
include!("candidate_row.rs");
#[path="baseline_serial.rs"] mod baseline_serial;
#[path="candidate_serial.rs"] mod candidate_serial;
fn add(a:u64,b:u64)->u64 { ((a as u128+b as u128)%(P as u128)) as u64 }
fn mul(a:u64,b:u64)->u64 { ((a as u128*b as u128)%(P as u128)) as u64 }
fn sub(a:u64,b:u64)->u64 { ((a as u128+P as u128-b as u128)%(P as u128)) as u64 }
fn pow(mut a:u64,mut e:u64)->u64 { let mut r=1; while e>0 {if e&1!=0 {r=mul(r,a);}a=mul(a,a);e>>=1;}r }
// Independent O(n^2) inverse DFT plus direct polynomial evaluation, generic mod p.
fn reference(data:&[Fp], pads:&[Fp], nn:usize,h:u64)->Vec<Fp> {
    let n=data.len(); let wi=pow(pow(7,(P-1)/(n as u64)),P-2); let ni=pow(n as u64,P-2);
    let mut c=vec![0u64;nn];
    for k in 0..n { let mut s=0; for j in 0..n {s=add(s,mul(data[j].0,pow(wi,(j*k) as u64)));}c[k]=mul(s,ni); }
    for j in 0..pads.len() {c[j]=sub(c[j],pads[j].0); c[n+j]=add(c[n+j],pads[j].0);}
    let omega=pow(7,(P-1)/(nn as u64));
    (0..nn).map(|i| {let x=mul(h,pow(omega,i as u64)); let mut v=0; for a in c.iter().rev(){v=add(mul(v,x),*a);} Fp(v)}).collect()
}
fn next(s:&mut u64)->Fp { *s=s.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);Fp::new(*s) }
fn pows(h:u64,nn:usize)->Vec<Fp>{(0..nn).map(|i|Fp(pow(h,i as u64))).collect()}
fn extra_checks()->(usize,usize,usize) {
    let mut matrices=0;let mut refusals=0;let mut controls=0;
    for (n,q,nn,rows) in [(1usize,7usize,8usize,3usize),(4,12,16,7),(16,3,64,7),(256,256,1024,3),(16384,256,65536,3)] {
        let t=NttTables::new(nn.trailing_zeros());let ps=pows(7,nn);let d:Vec<Fp>=(0..n*rows).map(|i|Fp::new(i as u64*137+3)).collect();let pad:Vec<Fp>=(0..q*rows).map(|i|Fp::new(i as u64*19+5)).collect();
        let a0=ALLOCS.load(Ordering::Relaxed);let b0=BYTES.load(Ordering::Relaxed);
        let a=baseline_serial::encode_rows(&t,&d,n,&pad,q,&ps);
        assert_eq!(ALLOCS.load(Ordering::Relaxed)-a0,rows+1);
        assert_eq!(BYTES.load(Ordering::Relaxed)-b0,8*rows*(nn+n));
        let a0=ALLOCS.load(Ordering::Relaxed);let b0=BYTES.load(Ordering::Relaxed);
        let b=candidate_serial::encode_rows(&t,&d,n,&pad,q,&ps);
        assert_eq!(ALLOCS.load(Ordering::Relaxed)-a0,1);
        assert_eq!(BYTES.load(Ordering::Relaxed)-b0,8*rows*nn);assert_eq!(a,b);
        // Every logical column, duplicate and unsorted requests included.
        for j in (0..nn).rev().chain([nn-1,0,nn-1]) {for r in 0..rows {assert_eq!(a[r*nn+j].to_bytes(),b[r*nn+j].to_bytes());}}
        matrices+=1;
    }
    // Public outer checks are the original source with only Rayon traversal made serial.
    std::panic::set_hook(Box::new(|_|{}));
    let t=NttTables::new(6);let ps=pows(7,64);let data=vec![Fp::ONE;16];let pads=vec![Fp::ONE;8];
    for (n,q,d,p,w) in [(0,8,&data[..],&pads[..],&ps[..]),(3,8,&data[..],&pads[..],&ps[..]),(16,8,&data[..15],&pads[..],&ps[..]),(16,8,&data[..],&pads[..7],&ps[..]),(16,0,&data[..],&pads[..0],&ps[..]),(16,usize::MAX,&data[..],&pads[..],&ps[..]),(16,8,&data[..],&pads[..],&ps[..16]),(16,8,&data[..],&pads[..],&ps[..63]),(16,8,&data[..0],&pads[..0],&ps[..])] {
        assert!(std::panic::catch_unwind(||baseline_serial::encode_rows(&t,d,n,p,q,w)).is_err());
        assert!(std::panic::catch_unwind(||candidate_serial::encode_rows(&t,d,n,p,q,w)).is_err());refusals+=1;
    }
    let short=NttTables::new(4);
    assert!(std::panic::catch_unwind(||candidate_serial::encode_rows(&short,&data,16,&pads,8,&ps)).is_err());refusals+=1;
    let d=vec![Fp(3),Fp(11),Fp(7),Fp(P-1)];let pad:Vec<Fp>=(0..12).map(|i|Fp((i*17+1) as u64)).collect();let ps=pows(7,16);let t=NttTables::new(4);let expected=reference(&d,&pad,16,7);
    let mut buf=vec![MaybeUninit::new(Fp(919));16];let init=candidate_row(&t,&d,&pad,&ps,&mut buf).to_vec();
    for mode in 0..6 {
        let mut bad=init.clone();
        match mode {
          0=>{for i in 0..4{bad[i]=d[i].sub(pad[i]).mul(ps[i]);}}, // no inverse
          1=>{for i in 0..8{bad[4+i]=pad[i].mul(ps[4+i]);}}, // lost q>n overlap
          2=>{bad[0]=bad[0].add(Fp::ONE);}, // missing/corrupted prefix
          3=>{bad[4]=bad[4].neg();}, // wrong hiding sign
          4=>{bad.swap(0,1);}, // wrong coefficient order
          _=>{bad[15]=Fp(919);}, // stale/unwritten coefficient
        }
        t.forward(&mut bad);assert_ne!(bad,expected);controls+=1;
    }
    for bad in [reference(&d,&pad,16,11),reference(&d,&pad[..4],16,7),reference(&[Fp(5);4],&pad,16,7)] {assert_ne!(bad,expected);controls+=1;}
    // A zero-tail omission has a different boundary from the q>n fixture.
    let ps=pows(7,32);let t=NttTables::new(5);let mut buf=vec![MaybeUninit::new(Fp(919));32];let b=candidate_row(&t,&d,&pad[..1],&ps,&mut buf);b[31]=Fp(919);t.forward(b);assert_ne!(b,reference(&d,&pad[..1],32,7));controls+=1;
    (matrices,refusals,controls)
}
fn main(){
    let start=std::time::Instant::now(); let mut seed=202610290140u64;
    let mut fixtures=0;let mut rows_checked=0;let mut points=0;let mut oracle_points=0;let mut baseline_allocs=0;let mut baseline_bytes=0;let mut candidate_allocs=0;let mut candidate_bytes=0;
    let mut dimensions=Vec::new();
    for n in [1usize,2,4,8,16,32] {for rate in [2usize,4,8]{let nn=n*rate; let maxq=nn-n; for q in [1,n,maxq] {for rows in [1usize,3,7]{dimensions.push((n,q,nn,rows,true));}}}}
    for n in [256usize,4096,16384]{ for rows in [1usize,3] {dimensions.push((n,256,4*n,rows,false));}}
    let mut checksum=0u64;
    for (n,q,nn,rows,direct) in dimensions {
        let t=NttTables::new(nn.trailing_zeros());let h=if fixtures%2==0 {7}else{11};let ps=pows(h,nn);
        let data:Vec<Fp>=(0..n*rows).map(|i|if i%11==0{Fp(P-1)}else if i%13==0{Fp::ZERO}else{next(&mut seed)}).collect();
        let pads:Vec<Fp>=(0..q*rows).map(|_|next(&mut seed)).collect();
        for r in 0..rows {
            // Guard values live outside the row; two unrelated poisons test total initialization.
            let d=&data[r*n..(r+1)*n];let pad=&pads[r*q..(r+1)*q];
            let mut left=vec![MaybeUninit::new(Fp(0x1234));nn+2];let mut right=vec![MaybeUninit::new(Fp(0x9876));nn+2];
            let a0=ALLOCS.load(Ordering::Relaxed);let b0=BYTES.load(Ordering::Relaxed);
            let a=baseline_row(&t,d,pad,&ps,&mut left[1..nn+1]);
            let ac=ALLOCS.load(Ordering::Relaxed)-a0;let bc=BYTES.load(Ordering::Relaxed)-b0;assert_eq!(ac,1);assert_eq!(bc,8*n);baseline_allocs+=ac;baseline_bytes+=bc;
            let a0=ALLOCS.load(Ordering::Relaxed);let b0=BYTES.load(Ordering::Relaxed);
            let b=candidate_row(&t,d,pad,&ps,&mut right[1..nn+1]);
            let ac=ALLOCS.load(Ordering::Relaxed)-a0;let bc=BYTES.load(Ordering::Relaxed)-b0;assert_eq!(ac,0);assert_eq!(bc,0);candidate_allocs+=ac;candidate_bytes+=bc;
            assert_eq!(a,b);assert!(b[n+q..].iter().all(|x|*x==Fp::ZERO));
            t.forward(a);t.forward(b);assert_eq!(a,b);points+=nn;
            if direct {let expected=reference(d,pad,nn,h);assert_eq!(b,expected);oracle_points+=nn;}
            checksum=checksum.wrapping_add(b[(r*17)%nn].0);
            assert_eq!(unsafe{left[0].assume_init()},Fp(0x1234));assert_eq!(unsafe{left[nn+1].assume_init()},Fp(0x1234));
            assert_eq!(unsafe{right[0].assume_init()},Fp(0x9876));assert_eq!(unsafe{right[nn+1].assume_init()},Fp(0x9876));rows_checked+=1;
        }
        // Same output arena, new witness AND fresh pads: cannot retain previous contents.
        let d2:Vec<Fp>=(0..n).map(|_|next(&mut seed)).collect();let pad2:Vec<Fp>=(0..q).map(|_|next(&mut seed)).collect();let mut arena=vec![MaybeUninit::new(Fp(P-1));nn];
        {let b=candidate_row(&t,&data[..n],&pads[..q],&ps,&mut arena);t.forward(b);}
        let b=candidate_row(&t,&d2,&pad2,&ps,&mut arena);t.forward(b);
        let mut want=vec![MaybeUninit::uninit();nn];let a=baseline_row(&t,&d2,&pad2,&ps,&mut want);t.forward(a);assert_eq!(a,b);
        fixtures+=1;
    }
    let (matrices,refusals,controls)=extra_checks();
    println!("{{\"status\":\"PASS_COMPILED_LOCAL_COMPONENT_ONLY\",\"seed\":202610290140,\"fixtures\":{},\"rows_checked\":{},\"encoded_points\":{},\"independent_dft_points\":{},\"baseline_allocations\":{},\"baseline_allocated_bytes\":{},\"candidate_allocations\":{},\"candidate_allocated_bytes\":{},\"matrix_cases\":{},\"refusal_cases\":{},\"negative_controls\":{},\"diagnostic_checksum\":{},\"elapsed_s\":{},\"threads\":1,\"full_stack_proofs\":0,\"passes\":0,\"proved_positions\":0}}",fixtures,rows_checked,points,oracle_points,baseline_allocs,baseline_bytes,candidate_allocs,candidate_bytes,matrices,refusals,controls,checksum,start.elapsed().as_secs_f64());
}
