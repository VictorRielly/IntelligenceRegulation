// Research-only arithmetic adapter, never a transcript/prover implementation.
// Supports are PUBLIC shape descriptors, not witness-derived zero tests.
use field::{Fp,Fp2};
use std::collections::BTreeMap;
include!("captured-mask.rs");

fn product(v:[Fp2;3])->Fp2 {v[0].mul(v[1]).mul(v[2])}
pub fn rounds(positions:&[usize], values:&[[Fp2;3]], cube:usize, challenges:&[Fp2])
    -> Result<(Vec<[Fp2;4]>,[Fp2;3],Vec<usize>),u32> {
    if cube==0 || !cube.is_power_of_two() || cube>1<<20 || positions.len()!=values.len()
        || challenges.len()!=cube.trailing_zeros() as usize { return Err(1); }
    if positions.iter().any(|&i|i>=cube) || positions.windows(2).any(|w|w[0]>=w[1]) {return Err(2);}
    let mut entries:Vec<_>=positions.iter().copied().zip(values.iter().copied()).collect();
    let mut width=cube; let mut output=Vec::new(); let mut visits=Vec::new();
    for &r in challenges {
        let half=width/2;
        let mut pairs:BTreeMap<usize,[[Fp2;3];2]>=BTreeMap::new();
        for (i,v) in entries { pairs.entry(i%half).or_insert([[Fp2::ZERO;3];2])[i/half]=v; }
        visits.push(pairs.len());
        let mut sums=[Fp2::ZERO;4]; entries=Vec::with_capacity(pairs.len());
        for (i,p) in pairs {
            let dif=std::array::from_fn::<_,3,_>(|t|p[1][t].sub(p[0][t]));
            let mut cur=p[0];
            for x in 0..4 {sums[x]=sums[x].add(product(cur));for t in 0..3{cur[t]=cur[t].add(dif[t]);}}
            entries.push((i,std::array::from_fn(|t|p[0][t].add(r.mul(dif[t])))));
        }
        output.push(sums); width=half;
    }
    let finals=entries.first().map(|e|e.1).unwrap_or([Fp2::ZERO;3]);
    Ok((output,finals,visits))
}
unsafe fn read_fp(p:*const u64,n:usize)->Vec<Fp2>{
    std::slice::from_raw_parts(p,2*n).chunks_exact(2).map(|v|Fp2{c0:Fp(v[0]),c1:Fp(v[1])}).collect()
}
unsafe fn write_fp(p:*mut u64,v:&[Fp2]){for (j,x) in v.iter().enumerate(){*p.add(2*j)=x.c0.0;*p.add(2*j+1)=x.c1.0;}}
#[no_mangle]
pub unsafe extern "C" fn candidate(pos:*const usize,m:usize,vals:*const u64,cube:usize,
    rs:*const u64,k:usize,out:*mut u64,counts:*mut usize)->u32 {
    let v=read_fp(vals,3*m).chunks_exact(3).map(|x|[x[0],x[1],x[2]]).collect::<Vec<_>>();
    match rounds(std::slice::from_raw_parts(pos,m),&v,cube,&read_fp(rs,k)){
        Ok((s,f,c))=>{let mut flat=s.into_iter().flatten().collect::<Vec<_>>();flat.extend(f);
            write_fp(out,&flat);for(j,n)in c.iter().enumerate(){*counts.add(j)=*n;}0},Err(e)=>e
    }
}
#[no_mangle]
pub unsafe extern "C" fn captured_mask(coeff:*const u64,k:usize,rs:*const u64,c:*const u64,out:*mut u64)->u32{
    if k==0 || k>20{return 1;}
    let mask=CfsMask{n_vars:k,degree:3,coeffs:read_fp(coeff,3*k+2)};
    let r=read_fp(rs,k); let scale=read_fp(c,1)[0]; let mut data=Vec::new();
    for j in 0..k {data.extend(mask.round(j,&r[..j]).iter().map(|x|scale.mul(*x)));}
    data.extend([scale.mul(mask.total()),scale.mul(mask.eval(&r))]);write_fp(out,&data);0
}
