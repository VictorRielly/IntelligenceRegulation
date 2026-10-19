// Synthetic cache-resident coefficient rows, not SumcheckRounds/proving.
use std::hint::black_box;
use std::time::Instant;
extern "C" {
    fn baseline(raw:*const u64,params:*const u64,bases:*const u64,out:*mut u64);
    fn driven(raw:*const u64,params:*const u64,bases:*const u64,out:*mut u64);
}
type Kernel=unsafe extern "C" fn(*const u64,*const u64,*const u64,*mut u64);
const P:u64=0xffff_ffff_0000_0001;
fn next(s:&mut u64)->u64 {*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s%P}
#[inline(never)]
fn sample(f:Kernel,raw:&[u64],p:&[u64],b:&[u64],n:usize)->(u128,u64){
    let mut out=[0u64;10];let mut checksum=0;let start=Instant::now();
    for i in 0..n {
        unsafe {f(black_box(raw.as_ptr().add((i%32)*236)),black_box(p.as_ptr()),black_box(b.as_ptr()),out.as_mut_ptr());}
        checksum^=black_box(out[i%10]);
    }
    (start.elapsed().as_nanos(),black_box(checksum))
}
fn main(){
    let mut s=2026101981u64;
    let raw:Vec<_>=(0..32*236).map(|_|next(&mut s)).collect();
    let p:Vec<_>=(0..258).map(|_|next(&mut s)).collect();
    let b:Vec<_>=(0..36).map(|_|next(&mut s)).collect();
    let mut a=[0u64;10];let mut c=[0u64;10];
    for i in 0..32 {unsafe{baseline(raw.as_ptr().add(i*236),p.as_ptr(),b.as_ptr(),a.as_mut_ptr());driven(raw.as_ptr().add(i*236),p.as_ptr(),b.as_ptr(),c.as_mut_ptr());} assert_eq!(a,c);}
    // Warm only this isolated synthetic row path; no model setup amortization.
    black_box(sample(baseline,&raw,&p,&b,256));black_box(sample(driven,&raw,&p,&b,256));
    for rep in 0..8 {
        let order=if rep%2==0 {[("baseline",baseline as Kernel),("grouped",driven as Kernel)]}
                  else {[("grouped",driven as Kernel),("baseline",baseline as Kernel)]};
        let mut check=None;
        for (name,f) in order {
            let (ns,ck)=sample(f,&raw,&p,&b,8192);
            if let Some(w)=check {assert_eq!(ck,w);} else {check=Some(ck);}
            println!("{{\"rep\":{rep},\"arm\":\"{name}\",\"rows\":8192,\"nanoseconds\":{ns},\"checksum\":{ck}}}");
        }
    }
}
