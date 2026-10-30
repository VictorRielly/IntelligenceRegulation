#![allow(dead_code)]
mod field;
use field::{Fp,Fp2,P};
include!("native_host.rs");
// Research-only public planner. Only the final 4+1 becomes 5; no permutation.
fn widths(k:usize,tail5:bool)->Vec<usize>{
 let mut v=vec![4;k/4];if k%4!=0{v.push(k%4);}
 if tail5&&k>=5&&k%4==1{v.pop();*v.last_mut().unwrap()=5;}v
}
fn kernel(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>],tail5:bool)->Vec<Vec<Fp2>>{
 assert!(n>0);assert_eq!(data.len(),rows*n);for r in rhos{assert_eq!(r.len(),rows);}
 let mut out=Vec::new();let mut off=0;
 for k in widths(rhos.len(),tail5){
  let rs=&rhos[off..off+k];assert!(k<=if tail5{5}else{4});
  let mut b=vec![vec![Fp2::ZERO;n];k];
  for j in 0..n{let mut acc=[Fp2::ZERO;5];
   for i in 0..rows{let v=data[i*n+j];for g in 0..k{acc[g]=acc[g].add(rs[g][i].mul_base(v));}}
   for g in 0..k{b[g][j]=acc[g];}
  }out.extend(b);off+=k;
 }assert_eq!(off,rhos.len());out
}
// Independent full-limb schoolbook modular dot products, no field helpers.
fn reference(data:&[Fp],rows:usize,n:usize,rhos:&[Vec<Fp2>])->Vec<Vec<Fp2>>{
 let p=P as u128;
 rhos.iter().map(|r|(0..n).map(|j|{
  let(mut a,mut b)=(0u128,0u128);
  for i in 0..rows{let v=data[i*n+j].0 as u128;a=(a+(r[i].c0.0 as u128*v)%p)%p;b=(b+(r[i].c1.0 as u128*v)%p)%p;}
  Fp2::new(Fp(a as u64),Fp(b as u64))
 }).collect()).collect()
}
fn next(s:&mut u64)->u64{*s^=*s<<13;*s^=*s>>7;*s^=*s<<17;*s}
fn fixture(rows:usize,n:usize,k:usize,mode:usize,s:&mut u64)->(Vec<Fp>,Vec<Vec<Fp2>>){
 let d=(0..rows*n).map(|i|Fp(if mode==3{P-1}else if mode==4&&i/n+3<rows{0}else{next(s)%P})).collect();
 let mut r=vec![vec![Fp2::ZERO;rows];k];
 for g in 0..k{for i in 0..rows{
  if mode==0||mode==2||mode==3||g+1==k||(i+g)%7==0||i+3>=rows{
   let a=if mode==2{0}else if mode==3{P-1}else{next(s)%P};
   let b=if mode==3{P-1}else{next(s)%P};r[g][i]=Fp2::new(Fp(a),Fp(b));
  }
 }}(d,r)
}
fn main(){
 std::panic::set_hook(Box::new(|_|{}));
 let mut seed=202610300155u64;let(mut cases,mut limbs,mut controls)=(0usize,0usize,0usize);let mut digest=0u64;
 let mut dims=Vec::new();
 for rows in [0,1,3,33]{for n in [1,7,17]{for k in [0,1,2,4,5,9,12,13,57,59]{for m in 0..5{dims.push((rows,n,k,m));}}}}
 for (rows,k) in [(3517,57),(3272,12),(3395,59),(3116,13)]{for m in 0..3{dims.push((rows,7,k,m));}}
 for (rows,n,k,mode) in dims{
  let(d,r)=fixture(rows,n,k,mode,&mut seed);let want=reference(&d,rows,n,&r);
  let a=kernel(&d,rows,n,&r,false);let b=kernel(&d,rows,n,&r,true);let h=fold_rows_host(&d,rows,n,n,1,&r);
  assert_eq!(a,want);assert_eq!(b,want);assert_eq!(h,want);
  // Same wrapper ordering: message first, independently folded synthetic pad columns last.
  let q=3;let(pad,_)=fixture(rows,q,k,0,&mut seed);let ph=fold_rows_host(&pad,rows,q,q,1,&r);let pw=reference(&pad,rows,q,&r);assert_eq!(ph,pw);
  for g in 0..k{let mut got=b[g].clone();got.extend(&ph[g]);let mut exp=want[g].clone();exp.extend(&pw[g]);assert_eq!(got,exp);}
  for v in b.iter().flatten(){digest=digest.rotate_left(5)^v.c0.0;digest=digest.rotate_left(5)^v.c1.0;}
  cases+=1;limbs+=2*k*(n+q);
 }
 for k in 0..130{let a=widths(k,false);let b=widths(k,true);assert_eq!(a.iter().sum::<usize>(),k);assert_eq!(b.iter().sum::<usize>(),k);assert_eq!(a.len()-b.len(),usize::from(k>=5&&k%4==1));controls+=1;}
 for which in 0..3{let bad=std::panic::catch_unwind(||{let d=vec![Fp(1);3];let r=vec![vec![Fp2::ONE;if which==1{2}else{3}];5];kernel(&d,3,if which==2{0}else if which==0{2}else{1},&r,true)});assert!(bad.is_err());controls+=1;}
 // Detect imaginary-limb loss, omitted prox, changed protected rows, reorder and stale repeated-call output.
 let(d,r)=fixture(7,3,5,2,&mut seed);let a=kernel(&d,7,3,&r,true);
 let mut changed=r.clone();changed[4].fill(Fp2::ZERO);assert_ne!(a,kernel(&d,7,3,&changed,true));controls+=1;
 let mut changed=r.clone();for v in changed.iter_mut().flatten(){v.c1=Fp::ZERO;}assert_ne!(a,kernel(&d,7,3,&changed,true));controls+=1;
 for i in [4,5,6]{let mut v=d.clone();v[i*3]=v[i*3].add(Fp::ONE);assert_ne!(a,kernel(&v,7,3,&r,true));controls+=1;}
 let mut changed=r.clone();changed.swap(0,4);assert_ne!(a,kernel(&d,7,3,&changed,true));controls+=1;
 let(d2,r2)=fixture(7,3,5,2,&mut seed);assert_ne!(a,kernel(&d2,7,3,&r2,true));controls+=1;
 // A real-only shortcut must fail on this all-imaginary fixture.
 assert!(a.iter().flatten().any(|v|v.c1!=Fp::ZERO));controls+=1;
 println!("{{\"status\":\"PASS\",\"seed\":202610300155,\"fixtures\":{cases},\"scalar_limb_outputs_including_synthetic_pad\":{limbs},\"controls\":{controls},\"digest\":\"{digest:016x}\",\"scope\":\"Synthetic native-field/source-loop differential; not CUDA or full PCS/proofs\",\"full_stack_proofs\":0,\"passes\":0,\"positions\":0}}");
}
