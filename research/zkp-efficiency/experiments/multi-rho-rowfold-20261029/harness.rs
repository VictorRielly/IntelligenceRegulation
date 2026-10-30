#![allow(dead_code)]
mod field;
use field::{Fp,Fp2,P};
use std::time::Instant;
include!("native_host.rs");

#[derive(Default,Clone,Copy,Debug)]
struct Count {data:u64,rho:u64,mac:u64,zero_rows:u64}
// Same thread/row/group arithmetic order as k_fold_rows, emulated on one CPU.
// A native wrapper chunks rhos at four; other B are counterfactual dispatches.
fn kernel<const SPARSE:bool>(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>],batch:usize)->(Vec<Vec<Fp2>>,Count){
 assert!(batch>0&&batch<=8);assert_eq!(data.len(),rows*n);
 let mut out=vec![vec![Fp2::ZERO;n];rhos.len()];let mut c=Count::default();
 for (bi,rs) in rhos.chunks(batch).enumerate(){
  let k=rs.len();assert!(k>=1&&k<=batch);for r in rs{assert_eq!(r.len(),rows);}
  for j in 0..n{let mut acc=[Fp2::ZERO;8];
   for i in 0..rows{
    if SPARSE{
     let mut rw=[Fp2::ZERO;8];let mut any=false;
     for g in 0..k{rw[g]=rs[g][i];c.rho+=1;any|=!rw[g].is_zero();}
     if !any{c.zero_rows+=1;continue;}
     let v=data[i*n+j];c.data+=1;
     for g in 0..k{if !rw[g].is_zero(){acc[g]=acc[g].add(rw[g].mul_base(v));c.mac+=1;}}
    }else{
     let v=data[i*n+j];c.data+=1;
     for g in 0..k{let r=rs[g][i];c.rho+=1;acc[g]=acc[g].add(r.mul_base(v));c.mac+=1;}
    }
   }
   for g in 0..k{out[bi*batch+g][j]=acc[g];}
  }
 }
 (out,c)
}
// Independent schoolbook modular reference, no native Fp arithmetic or skipping.
fn reference(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>])->Vec<Vec<Fp2>>{
 let p=P as u128;
 rhos.iter().map(|r|(0..n).map(|j|{
  let(mut a,mut b)=(0u128,0u128);
  for i in 0..rows{let v=data[i*n+j].0 as u128;a=(a+(r[i].c0.0 as u128*v)%p)%p;b=(b+(r[i].c1.0 as u128*v)%p)%p;}
  Fp2::new(Fp(a as u64),Fp(b as u64))
 }).collect()).collect()
}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn rand(s:&mut u64)->Fp2{Fp2::new(Fp::new(next(s)),Fp::new(next(s)))}
fn fixture(rows:usize,n:usize,k:usize,mode:usize,s:&mut u64)->(Vec<Fp>,Vec<Vec<Fp2>>){
 let data=(0..rows*n).map(|i|if i%11==0{Fp::ZERO}else if i%13==0{Fp(P-1)}else{Fp::new(next(s))}).collect();
 let mut rhos=vec![vec![Fp2::ZERO;rows];k];
 for g in 0..k{for i in 0..rows{
  let nonzero=match mode{0=>true,1=>false,2=>i%k.max(1)==g,3=>(i+g)%4==0,4=>g==k-1||i%k.max(1)==g,5=>i+1==rows,6=>i==0,_=>(next(s)%8)==0};
  if nonzero{rhos[g][i]=if (i+g)%7==0{Fp2::new(Fp(P-1),Fp(P-1))}else{rand(s)};}
 }}
 (data,rhos)
}
fn append(mut a:Vec<Vec<Fp2>>,b:Vec<Vec<Fp2>>)->Vec<Vec<Fp2>>{for (x,y)in a.iter_mut().zip(b){x.extend(y);}a}
fn main(){
 let t=Instant::now();let mut seed=202610290147u64;let(mut fixtures,mut values,mut padvalues,mut controls,mut refusals,mut digest)=(0u64,0u64,0u64,0u64,0u64,0u64);
 for rows in [0,1,3,9,33]{for n in [1,7,31,513]{for k in [0,1,2,4,5,8,11]{for mode in 0..8{
  let(data,rhos)=fixture(rows,n,k,mode,&mut seed);let want=reference(&data,rows,n,&rhos);let host=fold_rows_host(&data,rows,n,n,1,&rhos);assert_eq!(host,want);
  for batch in [1,2,4,8]{let(old,bc)=kernel::<false>(&data,rows,n,&rhos,batch);let(new,cc)=kernel::<true>(&data,rows,n,&rhos,batch);assert_eq!(old,want);assert_eq!(new,want);assert_eq!(bc.rho,cc.rho);assert!(cc.data<=bc.data&&cc.mac<=bc.mac);assert_eq!(bc.data,(k+batch-1)as u64/batch as u64*rows as u64*n as u64);values+=2*k as u64*n as u64;}
  let q=1+(mode%5);let(pads,_)=fixture(rows,q,k,0,&mut seed);
  let combined=append(fold_rows_host(&data,rows,n,n,1,&rhos),fold_rows_host(&pads,rows,q,q,1,&rhos));
  let mut refdata=Vec::new();for i in 0..rows{refdata.extend_from_slice(&data[i*n..(i+1)*n]);refdata.extend_from_slice(&pads[i*q..(i+1)*q]);}
  assert_eq!(combined,reference(&refdata,rows,n+q,&rhos));
  assert_eq!(combined,append(kernel::<true>(&data,rows,n,&rhos,4).0,fold_rows_host(&pads,rows,q,q,1,&rhos)));padvalues+=k as u64*(n+q)as u64;
  // Strided systematic-source addressing remains independently covered.
  let mut enc=vec![Fp(P-1);rows*n*2];for i in 0..rows{for j in 0..n{enc[i*n*2+j*2]=data[i*n+j];}}
  assert_eq!(fold_rows_host(&enc,rows,n,n*2,2,&rhos),want);
  for row in want{for v in row{digest=digest.rotate_left(5)^v.c0.0^v.c1.0;}}
  fixtures+=1;
 }}}}
 // Negative controls: explicit, non-degenerate values force differences.
 let rows=3;let n=2;let data=vec![Fp(2),Fp(3),Fp(5),Fp(7),Fp(11),Fp(13)];
 let r=vec![vec![Fp2::ONE,Fp2::U,Fp2::ONE.add(Fp2::U)],vec![Fp2::U,Fp2::ONE,Fp2::ZERO]];
 let want=reference(&data,rows,n,&r);
 let mut bad=r.clone();bad.reverse();assert_ne!(kernel::<true>(&data,rows,n,&bad,4).0,want);controls+=1;
 let mut bad=r.clone();bad[0][2]=Fp2::ZERO;assert_ne!(kernel::<true>(&data,rows,n,&bad,4).0,want);controls+=1;
 let mut bad=r.clone();bad[0][0]=Fp2::U;assert_ne!(kernel::<true>(&data,rows,n,&bad,4).0,want);controls+=1;
 let mut bad=data.clone();bad[0]=Fp(17);assert_ne!(kernel::<true>(&bad,rows,n,&r,4).0,want);controls+=1;
 let mut bad=r.clone();bad.pop();assert_ne!(kernel::<true>(&data,rows,n,&bad,4).0,want);controls+=1;
 let mut bad=r.clone();for v in &mut bad[0]{*v=Fp2::from_base(v.c0);}assert_ne!(kernel::<true>(&data,rows,n,&bad,4).0,want);controls+=1;
 let pads=vec![Fp(19),Fp(23),Fp(29)];assert_ne!(append(want.clone(),reference(&pads,rows,1,&r)),want);controls+=1;
 let mut bad=data.clone();bad[4]=Fp(31);assert_ne!(reference(&bad,rows,n,&r),want);controls+=1;
 std::panic::set_hook(Box::new(|_|{}));
 for longer in [false,true]{let mut bad=r.clone();if longer{bad[0].push(Fp2::ONE);}else{bad[0].pop();}
  assert!(std::panic::catch_unwind(||kernel::<false>(&data,rows,n,&bad,4)).is_err());assert!(std::panic::catch_unwind(||kernel::<true>(&data,rows,n,&bad,4)).is_err());refusals+=1;}
 for batch in [0,9]{assert!(std::panic::catch_unwind(||kernel::<false>(&data,rows,n,&r,batch)).is_err());assert!(std::panic::catch_unwind(||kernel::<true>(&data,rows,n,&r,batch)).is_err());refusals+=1;}
 let mut studies=Vec::new();
 for mode in 0..8{let(data,r)=fixture(257,17,37,mode,&mut seed);for batch in [1,2,4,8]{let(a,b)=kernel::<false>(&data,257,17,&r,batch);let(c,d)=kernel::<true>(&data,257,17,&r,batch);assert_eq!(a,c);studies.push(format!("{{\"mode\":{mode},\"batch\":{batch},\"baseline_data_loads\":{},\"candidate_data_loads\":{},\"rho_loads_each\":{},\"baseline_fp2_base_macs\":{},\"candidate_fp2_base_macs\":{},\"skipped_row_column_instances\":{}}}",b.data,d.data,b.rho,b.mac,d.mac,d.zero_rows));}}
 println!("{{\"status\":\"PASS\",\"seed\":202610290147,\"fixtures\":{fixtures},\"emulated_output_values_compared\":{values},\"message_pad_values\":{padvalues},\"negative_controls\":{controls},\"matched_emulator_panics\":{refusals},\"digest\":\"{digest:016x}\",\"elapsed_s\":{},\"studies\":[{}],\"scope\":\"Synthetic exact-field algebra/source-loop emulation, not CUDA compilation or native proofs. Actual GPU dispatch limit remains4.\",\"full_stack_proofs\":0,\"model_passes\":0,\"proved_positions\":0}}",t.elapsed().as_secs_f64(),studies.join(","));
}
