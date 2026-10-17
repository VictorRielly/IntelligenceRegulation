// Research-only private scratch; no transcript, GKR, PCS or masking protocol.
use field::{Fp,Fp2};
fn weights(r: &[Fp2]) -> Vec<Fp2> {
    let mut a=vec![Fp2::ONE];
    for &x in r {
        let n=a.len(); a.resize(2*n,Fp2::ZERO);
        for j in (0..n).rev() { let v=a[j]; a[j]=v.mul(Fp2::ONE.sub(x)); a[j+n]=v.mul(x); }
    }
    a
}
// Every real column is zero-lifted into the common row cube. Public support
// selects active rows; dummy columns are omitted, not assigned a table index.
pub fn batch(index:&[usize], lengths:&[usize], active:&[usize], r:&[Fp2], s:&[Fp2], m:usize) -> Result<Vec<Fp2>,u32> {
    let c=lengths.len();
    if c==0 || c!=active.len() || m==0 || r.len()>20 || s.len()>10 || c>(1usize<<s.len()) { return Err(1); }
    let n=1usize<<r.len();
    if lengths.iter().zip(active).any(|(&l,&a)| l==0 || !l.is_power_of_two() || l>n || a>l) {return Err(1);}
    if lengths.iter().sum::<usize>()!=index.len() {return Err(1);}
    let wr=weights(r); let wc=weights(s); let mut out=vec![Fp2::ZERO;m]; let mut start=0;
    for col in 0..c {
        for i in 0..active[col] {
            let j=index[start+i]; if j>=m {return Err(2);}
            out[j]=out[j].add(wr[i].mul(wc[col]));
        }
        start+=lengths[col];
    }
    Ok(out)
}
#[no_mangle]
pub unsafe extern "C" fn candidate(index:*const usize, size:usize, lengths:*const usize, active:*const usize,c:usize,
    r:*const u64,k:usize,s:*const u64,h:usize,m:usize,out:*mut u64)->u32 {
    let cv=|p:*const u64,n:usize|std::slice::from_raw_parts(p,2*n).chunks_exact(2).map(|v|Fp2{c0:Fp(v[0]),c1:Fp(v[1])}).collect::<Vec<_>>();
    match batch(std::slice::from_raw_parts(index,size),std::slice::from_raw_parts(lengths,c),std::slice::from_raw_parts(active,c),&cv(r,k),&cv(s,h),m) {
        Ok(y)=>{for (j,v) in y.iter().enumerate(){*out.add(2*j)=v.c0.0;*out.add(2*j+1)=v.c1.0;}0},Err(e)=>e
    }
}
